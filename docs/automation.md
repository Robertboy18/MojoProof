# The block checker and its automation

The block checker proves facts about a compiled kernel's steps by kernel reflection. Untrusted code
computes a summary of a block (`sym_summary`); the Lean kernel evaluates a Boolean checker on it
(`decide +kernel`); and one theorem, proved once for every program, turns an accepted summary into
facts about the semantics' steps. `sym_summary` is not trusted: the kernel evaluates the checker
on its output, so a wrong summary is refused and nothing about it enters a proof. The checker
itself is proved sound.

| file | contents |
|---|---|
| `MojoProof/Sym/Term.lean` | symbolic values: the node table (`SVal`, `SNode`), their values (`vals`), memory effects (`SEff`), obligations (`Cond`) |
| `MojoProof/Sym/Checker.lean` | the checker: `summarize`, `Summary`, `covers`, `coversTo` |
| `MojoProof/Sym/Rel.lean` | the relation `Rel` of the checker's state to a frame and a memory, its lemmas, the terminator's step (`SState.exitAt_sound`) and the pointer facts' definitions |
| `MojoProof/Sym/Block.lean` | its soundness: `SState.stmt_sound`, `Block.sound`, `Block.soundC`, the pointer facts |
| `MojoProof/Sym/Exec.lean` | the statements `exec` runs (`exec_bin` to `exec_minmax`) and the shape of the memory the effects make (`SEff.run_shape`) |
| `MojoProof/Sym/Segment.lean` | segments that end at a barrier or a warp shuffle: `summarizeTo`, `SegSummary`, `Seg.sound`, `Seg.through`; or at a lifetime marker: `summarizeLife`, `Seg.lifetime`, `Seg.lifetime_ptr` |
| `MojoProof/Sym/Path.lean` | along a path: `coversPathWith`, `WalkWith`, edges into blocks with `phi`s, returns |
| `MojoProof/Sym/Loop.lean` | loops: `Block.sound_loop`, invariants, sequences of loops and nested loops |
| `MojoProof/Sym/PtrMem.lean` | the memory premises of a path from a labelling's memory hypothesis |
| `MojoProofTest/Sym.lean`, `SymRun.lean`, `SymPhi.lean`, `SymLoop.lean` | tests |
| `scripts/SymBench.lean` | the benchmark (not part of the build) |

The commands `sym_summary` and `#mojo_info` are described in `docs/tactics.md`. The kernel theorem
built on top of the checker, `Kernel.sound_of_paths`, and the command `mojo_kernel` are described
in `docs/kernel.md`. The informal proofs are in `docs/proofs/` (`edge.md`, `phi.md`, `back.md`,
`ptrs.md`, `loop.md`).

## What the checker checks

### Symbolic values

A block's symbolic values form a DAG stored as a node table. There is one node (`SNode`) per
statement that defines a value, in the statements' order. A node's operands (`SVal`) are atoms or
earlier nodes:

- `reg r` is register `r` at the block entry (a kernel argument or a value of an earlier block);
- `int w i` is an integer constant;
- `node j` is the `j`-th node of the table.

The nodes are:

- integer operators with their width;
- integer `icmp`;
- `trunc`, `zext` and `sext`;
- `extractvalue`, and `insertvalue` (`insert is a b`, the value `b` put into `a` at indices
  `is`);
- `extractelement` and `insertelement` at position `pc` of block `lbl` (`eltAt lbl pc a i` and
  `insEltAt lbl pc a e i`, whose vector type the statement gives);
- `getelementptr` with one index (`gep lbl pc base i`), and with any other number of indices on a
  base that is not a global (`gepN lbl pc base is`);
- `load` from the entry memory;
- float operators with their flags and the step whose oracle numbers they read
  (`fbin op fm ft n a b`, `n` steps after the block entry);
- `call lbl pc`, the call of a special register or of the lane number at position `pc` of block
  `lbl`;
- `castAt lbl pc n a`, the other casts `castV` evaluates (`bitcast`, `addrspacecast`, `fpext`,
  `fptrunc`, `sitofp`, `uitofp`, `ptrtoint`, each at the types `castOk` names) at position `pc` of
  block `lbl`, `n` steps after the block entry (whose oracle numbers a float cast reads). Not
  `fptoui`, `fptosi` or `inttoptr`, which `castV` does not evaluate: the checker refuses them;
- `globalAt lbl pc i`, the pointer of the global named at operand `i` of the statement at
  position `pc` of block `lbl`: the context's address of the global (`Ctx.globals`, which
  `Grid.start` sets per thread block; `SNode.eval_globalAt`), the base of a `getelementptr` on a
  global and the pointer of a `load` or `store` on a global.
- `loadAfter lbl pc p es`, the `load` at position `pc` of block `lbl` after a `store` of the
  block: from the memory the effects `es` before it make from the entry memory (`SEff.run`).
  MojoProof/Sym/LoadAfter.lean gives its value one effect at a time: a `load` effect leaves it
  (`SNode.eval_loadAfter_log`), a `store` at a pointer of the same value, type, space and
  alignment makes it the stored value's decoding (`SNode.eval_loadAfter_store`), a `store` apart
  from it leaves it (`SNode.eval_loadAfter_apart`, by `Mem.load_store_apart`), and with no
  effect it is the `load` from the entry memory (`SNode.eval_loadAfter_nil`).

A value used twice is one node referred to twice, so the table has as many nodes as the block has
value-defining statements (and one more per `getelementptr`, `load` or `store` on a global),
whatever the sharing. A
node whose instruction carries a type (`getelementptr`'s source type, `load`'s type, a cast's
types) or a name (a global's) names its statement by block label and position and reads the type
or the name there. As a result `SNode` holds no `Ty`, whose derived equality the kernel does not
reduce, and no `String`.

`SNode.eval V vs nd` is the value of node `nd` under a valuation `V`, given the values `vs` of the
nodes before it. The valuation holds the context, the function, the step count at the entry, the
entry memory, the entry registers and the `fmul contract` operands. The value is computed by the
semantics' own operations (`intBin`, `icmpV`, `intCast`, `castV`, `extractV`, `gep`, `Mem.load`,
`floatBin`, `withAttrs`), faults included. So `eval` agrees with the semantics' `exec` by
construction, not by a separate proof per operation. `vals V ns`, the values of table `ns`, is a
fold that evaluates each node once, on the values before it.

### One block: `summarize` and `covers`

`summarize P fn lbl p0` runs block `lbl` of function `fn` of program `P` symbolically from
position `p0`. Each statement that defines a value appends one node, sets its register to that
node, and adds the obligation `Cond.ok (node j)` that the node evaluates without a fault. A
`load` and a `store` add their memory effect (`SEff`). The terminator gives the exit:

- `Exit.br` or `Exit.cond`, the latter with the obligation `Cond.bool c` that the condition is a
  word;
- `Exit.phi` for a branch into blocks that start with `phi`s;
- `Exit.ret` for `ret void`.

The summary (`Summary`) holds the table, the registers' entries, the effects, the obligations,
the exit and the number of statements. Its obligations are the exit's, then `Cond.mem effs` (the
effects run without a fault), then the statements', latest first.

`covers P fn lbl p0 ds S` holds when `summarize P fn lbl p0` is a summary equal to `S` (by the
derived equality) and `S`'s obligations are the first conditions of `ds` (`List.isPrefixOf`, a
check by position). `sym_summary` writes `S` as a Lean term. The kernel then evaluates `covers`
again, so a wrong summary from `sym_summary` is refused rather than trusted.

The fragment the checker accepts:

- instructions: `bin`; scalar integer `icmp`; `trunc`, `zext`, `sext`; the other casts that `castV`
  evaluates (`castOk`, which is `castV`'s cases by `castOk_iff`; `SNode.castAt`, `exec_cast`), so
  not `fptoui`, `fptosi` or `inttoptr`; `extractvalue`; `insertvalue`, `extractelement` and
  `insertelement` (`SNode.insert`, `SNode.eltAt`, `SNode.insEltAt`; into a `zeroinitializer`,
  `undef` or `poison`, two nodes: `SNode.constAt` for the constant, then the insertion into it);
  `getelementptr` with one index (on a global, two nodes: the global's pointer, `SNode.globalAt`,
  then the `getelementptr` on it) and with any other number of indices on a base that is not a
  global (`SNode.gepN`); `load` and `store` (on a global, the global's pointer, `SNode.globalAt` at
  the pointer operand, then the `load` or `store` on that node); float operators except `fmul
  contract` (`fadd contract` may fuse with its product, which the frame records and the summary of
  `covers` does not model; the checker `coversC` admits it, below); `select` of integers
  (`SNode.select`); calls of a special register or of the lane number (a declaration that
  `P.intrinsics` names `sreg r d` or `laneid`, called with no arguments and no fast-math flags,
  whose attributes `Func.check` accepts; `exec_sreg`, `exec_laneid`); calls of an integer maximum or
  minimum (`llvm.smax`, `llvm.smin`, `llvm.umax`, `llvm.umin`: a declaration that `P.intrinsics`
  names `minmax signed max t`, called with two arguments, no fast-math flags and no parameter,
  return or call-site attributes, whose attributes `Func.check` accepts; `SNode.minmax`);
- operands: registers and integer constants, a global as a one-index `getelementptr`'s base or a
  `load`'s or `store`'s pointer, and a `zeroinitializer`, `undef` or `poison` as the aggregate
  or vector an `insertvalue` or `insertelement` inserts into, or as the value a `store` through
  a pointer that is not a global stores;
- order: `getelementptr`, `icmp`, `ptrtoint` and the calls of a special register or the lane
  number read only the entry memory's blocks' addresses and sizes, which a `store` keeps
  (`SEff.run_shape`), so they are taken after a store too; a `load` after a `store` is
  `SNode.loadAfter` (on a global, on the global's `SNode.globalAt` node), with the effects before
  it, whose operands are nodes before it (`SEff.before`, so they run on its table as on the final
  one, `SEff.run_before`);
- terminators: `br`, `br i1` and `ret void`. On an edge into blocks with `phi`s, each `phi`'s
  operand for the edge must be a register, an integer constant or a float constant, and its
  obligation is that the operand evaluates (`SState.phiConds`).
- float constants, as operands of statements and of the edges' `phi`s: `summarizeWith` starts
  from a table with one node `SNode.flit ft lit` per float constant (`SState.start`, `litNodes`),
  whose value is the semantics' `floatLit ft lit` (`vals_flit`); the checker never evaluates a
  literal. The obligation that such an operand evaluates is decided on a concrete valuation;
  for a decimal literal `floatLit` reads the digits (0-9 only) with `digits`, which the kernel
  reduces, so `decide +kernel` decides it.

Everything else makes `summarize` give `none`, so `covers` is `false`:

- other calls (barriers, other intrinsics, module functions); a barrier or a warp shuffle can
  end a segment instead (`summarizeTo`, below);
- `select` of floats, pointers or vectors, float compares, atomics, `alloca`;
- aggregates other than `extractvalue`, and vectors as `getelementptr` indices;
- `phi`s inside the range (a block with `phi`s is summarized from the position after them);
- `ret` of a value.

`coversTo P fn lbl p0 d₀` is `covers` with only the obligations of the edge into block `d₀`, for
a `br i1` into blocks with `phi`s. An operand of the untaken edge that is outside the fragment or
faults then does not refuse the block.

### Paths

A path is a list of entries `(l, ds, S)`: a block's label, its conditions and its summary.

- `coversPathWith contract P fn p0 ps` checks the first block from position `p0`, and each later
  one from the position its edge enters at (`Exit.pc`: after the `phi`s of a block with `phi`s,
  else 0), each block but the last by `covers` or by `coversTo` for the edge into the next block
  (their `coversWith` forms with the flag; `contract = false` without `fmul contract`).
- `WalkWith contract V ps` is a path's premise: each block's conditions hold under its entry
  valuation and table, and each block's exit goes to the next block (`Exit.dest`, where a `br i1`
  into blocks with `phi`s picks the target by its condition, and `Exit.target` on other exits).
  Each block after the first is entered at `Valuation.intoWith contract`, the valuation after the
  edge, with the `phi`s set.
- `WalkWith` is decidable (`WalkWith.dec`), so `decide +kernel` decides it on concrete
  valuations.

## What it proves

Every theorem below is proved once, for every program, function, block, position, conditions
and summary (or path) that the checker accepts. Those about a block or a path are about one
thread's steps, and their premises are that the conditions hold under the thread's entry
valuation (`hds`, `WalkWith`). The
checker's run is a per-kernel computation (`covers … = true` by `decide +kernel`). The premises
are per thread: a test that proves them by `decide +kernel` covers the contexts, memories and
frames it names. A proof for every thread needs them proved symbolically.

### `Block.sound` (`MojoProof/Sym/Block.lean`)

Take `covers P fn lbl p0 ds S = true`, a context `c` with `c.prog = P`, a thread `t` with frames
`f :: rest` (`f.fn = fn`, `f.label = lbl`, `f.pc = p0`) and a memory `m`. Let
`V := Valuation.entry c t.k m f` and `vs := vals V S.nodes`. If every condition of `ds` holds
under `V` and `vs`, then `Ends c t m f rest (V, lbl, S)` holds. That is, there are a frame `fe`
and a memory `me` such that, for `k' := t.k + S.len`:

- `Steps c t m ⟨fe :: rest, k'⟩ me`: one step per statement, none of which faults;
- `fe` runs `fn` at block `lbl` and keeps `f`'s `alloca` blocks and caller's register;
- `fe`'s registers and `fmul contract` operands are the summary's (`regVal`, `regProd`);
- `me` is the memory the summary's effects make (`SEff.run V vs S.effs = .ok me`);
- the terminator's step is `S.exit.next`, which succeeds.

The proof is in the module docstring of `MojoProof/Sym/Block.lean`. In short, the relation `Rel`
(`MojoProof/Sym/Rel.lean`) says a symbolic state describes a frame and a memory.
`SState.stmt_sound` shows each statement of the fragment keeps it, `SState.run_sound` extends
that to the statement list, and `SState.exitAt_sound` (`MojoProof/Sym/Rel.lean`) covers the
terminator.

`Block.sound_ptrs` concludes `Ends` and the pointer facts `Ptrs` as well: the thread's steps
reach the statement of each `load` node and each `store` effect, and there the statement's
pointer operand, evaluated in the thread's scope, is the summary term's pointer value
(`docs/proofs/ptrs.md`). `Block.sound_withAt` is `Block.sound` for any exit function whose exit
is the terminator's step when its obligations hold, and for either value of the flags `alloca`
and `contract` (concluding `EndsAt contract`, which is `EndsWith contract` with the flag `alloca`
off, by `EndsAt.ends`, and `Ends` without either flag). `Block.sound_to` is `Block.sound` for
`coversTo`, when the exit goes to `d₀`.

`coversC` is `covers` with `fmul contract` in the fragment: a float operator's node records the
`fmul contract` operand terms its operands carry (`SNode.fbinP`), and `Block.soundC` concludes
`EndsC`, which is `Ends` with the frame's products at the block's end given by the table
(`regProdIn`: for a register the block sets, the values of its node's operand terms).
`Ends.edgeC` is `Ends.edge` from `EndsC`, entering the next block at `Valuation.intoC`
(`Valuation.into` with the table's products). `Block.sound_pathC` takes a path that
`coversPathWith false` accepts, then one block that `coversC` accepts. The path and loop checkers
take the same flag (`coversPathWith`, `WalkWith`, `RoundWith`, `ChainWith`, `coversChainsWith`), and
the path and loop theorems are proved once for both values (`docs/proofs/contract.md`).

### Segments that end at a collective (`MojoProof/Sym/Segment.lean`)

A thread's step at a barrier or a warp shuffle is a `.wait`, which the grid completes, so
`summarize` (which ends at the terminator) does not pass one. `summarizeTo P fn lbl p0 p1` is
the summary (`SegSummary`) of the statements `p0` to `p1 - 1` by the same statement case, ending
at the collective call at `p1` (`SState.waitAt`: the barrier or a shuffle, `Coll`, with no
fast-math flags or attributes) with its argument terms; its obligations add that each argument
term evaluates. `Seg.sound`, for every program: from the entry valuation of a frame at `p0` that
meets the obligations, the thread's steps reach `p1` with the summary's registers and memory, and
the step there is the `.wait` of the collective on the arguments' values (`Waits`). The resumed
thread is at `p1 + 1` with the same function and block (`Thread.resume_at`; `Seg.resume`, from
the summary's collective and length, the steps to the `.wait` and the resumed frame), and has at
every register but the call's result the summary's value (`Thread.resume_regs`,
`Seg.resume_regs`), where the next segment starts (`summarizeTo` again, or `summarize` and
`Block.sound` for the last one).
`summarizeSegs P fn lbl p0 ps` gives the summaries of all of a block's segments, with the
collective calls at the positions `ps`, and the summary of the rest; `Seg.through`, for every
program, runs them in a row on one thread (`Seg.Through`), each wait followed by the resume with
the value and memory `w i` that the `i`-th collective delivers, a parameter. The schedule that
fires the collectives and supplies those values is not proved.

A segment also ends at a call of `llvm.lifetime.start` or `llvm.lifetime.end` (`SState.lifeAt`,
`summarizeLife P fn lbl p0 p1`, with the pointer's term), since the effects a summary replays are
its `load`s and `store`s and the marker's `Mem.setLive` is neither. `Seg.lifetime`, for every
program: from the entry valuation of a frame at `p0` that meets the obligations (the pointer's
term evaluates, the effects run, and the statements'), the thread's steps reach `p1` on the
memory the effects make, and when `intrinsic` gives memory `m'` on the pointer's value (the
block's `Mem.setLive`, `intrinsic_lifetime_ptr`, or the same memory on `poison`) the step there
moves on `m'` to `p1 + 1`, where the next segment starts; `Seg.lifetime_ptr` states it for a
pointer into a block the thread owns and for `poison`. The marker's parameter may carry
`captures(none)` (`withAttrs_args`).

### Along a path

- `Ends.edge`: from `Ends` at `(V, l, S)` with `Exit.dest = some d`, the exit's step takes the
  thread into a frame of `V.fn` at block `d`'s position `Exit.pc`, with entry valuation
  `V.into l S`.
- `Block.sound_pathWith_ptrs`: `coversPathWith contract` and `WalkWith contract` give
  `EndsWith contract` (`Ends` without the flag) of the path's last block from its entry valuation
  (`Valuation.lastWith contract`), and the pointer facts of every block of the path.
- `Block.sound_retWith`: for a last block that ends in `ret void`, under any list of caller
  frames, the thread's steps reach the `ret` on the memory the last block's effects make. The next
  step is `.done` without a caller, else a return to the caller at the position after its call;
  the frame's `alloca` blocks are dead either way. With one frame (`rest = []`) it is the `.done`
  case.
- `Block.sound_back`: with a caller frame `g`, if `covers` accepts `g`'s block from `g.pc + 1` and
  its conditions hold after the return, the caller's block ends (`Ends`) too
  (`docs/proofs/back.md`).
- `Block.sound_pathMem` (`MojoProof/Sym/PtrMem.lean`): along a path that `coversPathWith false`
  and `pathOk` accept, `Labels.MemNext` at every state the thread's steps reach gives the memory
  premises `Valuation.PathMem` of the two-run theorem. `Labels.MemOk.steps` gives `Labels.MemNext`
  at every state that a running thread's steps reach, in every grid reachable from a grid that
  meets `Labels.MemOk`.

### To the kernel theorem

`Runs.of_ret` (`MojoProof/Sym/Kernel.lean`) turns a path that `coversPathWith false` accepts and
that is a `Ret` to `Q` (its premises hold, its last block returns, its effects run to a memory of
`Q`) into the thread's run to its end (`Runs`). `Kernel.sound_of_paths` takes a list of paths that
`coversEntry` accepts (each from the kernel's first block) and an invariant on the memory, indexed
by the number of threads done. Each thread must take one of the paths as a `Ret` from the invariant
at `k` threads to the invariant at `k + 1`. From these and the premises it states, it concludes
`Kernel.Sound` for every launch, arguments, memory, admission and observation.
`Kernel.sound_of_chains` is the same with, for each thread, a path or a sequence of loops (`RetLs`,
through `Runs.of_chainsWith`), and `Kernel.sound_of_paths` is its case without loops. `mojo_kernel`
enumerates a kernel's paths, and with one `loop` clause per loop its sequence of loops, and
generates these theorems (`docs/kernel.md`).

## Loops: what is automated and what is not

A loop is a path `(h, ds, S) :: B` from its header `h`, entered at position `p` (after its
`phi`s), through the body to the latch, whose exit goes back to `h`. `Valuation.round` is the
header's valuation after one round. `Round` is the decidable premise of one round: the loop path's
`WalkWith false`, and its last exit goes to `h` at position `p`. The theorems
(`MojoProof/Sym/Loop.lean`) are proved once, for every program, function, path, list of loops,
nesting, trip count and invariant, and for blocks with and without `fmul contract`: each takes a
flag `contract`, and with `contract = true` reads `coversPathWith true`, `RoundWith true`,
`Valuation.roundWith true` and `ChainWith true` for the names below (`docs/proofs/contract.md`).

- `Block.sound_loop`: if `Round` holds at the `i`-th round's valuation for every `i < n`, the
  thread's steps reach `h`'s position `p` again, with the `n`-th round's valuation.
- `Round.of_inv` and `Block.sound_loop_inv`: the same from an invariant `I i` indexed by the round
  number, from `I 0` and the fact that `I i` gives `Round` and `I (i + 1)` after the round.
- `Runs.of_loop`: a thread with one frame through an entry path, a loop and an exit path to a
  `ret` runs to its end (`Runs`), from `RetL`. `RetL` says: the entry path goes to the header, an
  invariant holds at round 0 and is preserved, and at the trip count it gives `Ret` of the exit
  path.
- `Runs.of_chainWith`: the same through a list of loops in sequence, each of whose rounds may run
  nested loops (`LoopSeg`), from the inductive premise `ChainWith` (`ChainWith false` without the
  flag).
- `Runs.of_loops`, `Runs.of_chainsWith`: the same for the threads `Grid.start` makes, with the
  paths checked by the closed Booleans `coversLoops` and `coversChains`.

What is automated:

- the checks of every path of the loops (`coversChain`, `coversChains`, `coversLoops`): closed
  Booleans that the kernel evaluates;
- on a concrete valuation and trip count, the premises of the rounds: `ChainWith.of_rounds` (a
  loop with no nested loop) and `ChainWith.of_iter` (a loop given by a round function) turn them
  into closed propositions that `decide +kernel` decides;
- `backEdges fn` and `cutPoints fn` list a function's back edges and loop headers, which
  `#mojo_info` prints.

What is not automated:

- Finding an invariant, and proving that it is preserved for every trip count. That proof is
  written by hand for each loop. The counting loop's `cnt_retL` (`MojoProofTest/SymLoop.lean`) is
  one: it holds for every bound up to `2 ^ 60` and every memory with the cells, for that loop's
  summaries only.
- Termination. The trip count is a premise; nothing proves that a loop ends.
- The kernel theorem, in part. `Kernel.sound_of_chains` (`MojoProof/Sym/Kernel.lean`) takes,
  per thread, a loop-free path (`Ret`) or a sequence of loops (`RetLs`), and `mojo_kernel` builds
  it for loops in sequence from one `loop` clause per loop (its precondition, invariant, trip
  count and postcondition, all the user's; `docs/kernel.md`). It refuses a nested loop and a loop
  without a clause, naming the header. The kernel theorems through a loop are for test programs
  at one launch: the counting loop on one thread (`kernelK`, MojoProofTest/KernelLoop.lean, the
  generated `loopK.sound_loop` with no evaluation of the start) and six threads in two blocks that
  each run a counted loop and then store one cell, apart only on the storing threads (`kernelC`,
  MojoProofTest/KernelCells.lean, through `Kernel.sound_cells`); no kernel of the library is
  proved that way.
- Loops outside the fragment. The naive matmul kernel's latch `%52` is refused at the
  `fmul contract` (statement 12) whose product the `fadd contract` at statement 13 reads
  (`naive_latch_refusal`); its integer `select` (statement 2) is in the fragment. `coversC`
  accepts the latch as one block (`latch_covers`, MojoProofTest/SymContract.lean), and the path
  and loop theorems take it with the flag `contract` (the With forms; the loop `%46 → %50 → %52`
  is covered and runs two rounds at one thread, `naiveL_covers` and `loop_two`,
  MojoProofTest/SymNaive.lean), but the kernel theorems do not take the flag yet. Of the
  kernel's nine blocks, `covers` accepts all but the latch
  (`naive_refusals`, MojoProofTest/SymNaive.lean; the preheader `%45`'s float constant `0.0` for
  the `phi` `%48` is its node 0, `pre_covers`, MojoProofTest/SymPhi.lean); `coversC` accepts all
  nine.

## Running the checker on a new kernel

1. Compile the kernel to LLVM IR with the Mojo version that `tests/corpus/MANIFEST.tsv` records
   (its `mojo` column): `mojo build --emit llvm --target-accelerator sm_80 -o <file>.ll
   <file>.mojo` writes one `.nvptx.ll` file per kernel. Add the file to `tests/corpus/<family>/`
   with `scripts/corpus.py add <family> <src.mojo> <modular-path> <flags> <file.nvptx.ll>`, which
   records its digest, kernel, target, Mojo version, flags and source in the manifest (with
   another compiler than the recorded one, pass its version as `--mojo <version>`).
   `mojo_import` refuses a file that has no row in the manifest or whose digest differs from its
   row.
2. In a Lean module that imports `MojoProof.Sym.Command` (and `MojoProof.Sym.Info` for
   `#mojo_info`), import the program and look at it:

   ```lean
   mojo_import "<family>/<file>.nvptx.ll" as k
   #mojo_info k.prog
   ```

   `#mojo_info` prints, per function, its calls, back edges and float operators, and per block
   its size, `phi`s, successors and the checker's verdict (in the fragment, or the first
   statement it refuses). It is a report, not a proof. `k.fn_<i>` is function `i`, and
   `k.fn_<i>.b_<j>` is its block `j`.
3. Summarize a block and check it:

   ```lean
   sym_summary s := k.prog k.fn_0 k.fn_0.b_1.label 0
   theorem s_covers : covers k.prog k.fn_0 k.fn_0.b_1.label 0 s.obls s = true := by
     decide +kernel
   ```

   `sym_summary` reports a block outside the fragment as an error that names it. For a block with
   `phi`s, start from the position after them (`phiCount`).
4. Apply `Block.sound s_covers hP ht hfn hl hp hds`. `hds` says that the summary's obligations
   hold under the thread's entry valuation. On a concrete context, memory and frame,
   `decide +kernel` proves it (`vadd21_hds`, `MojoProofTest/SymRun.lean`). For every thread it
   needs a symbolic proof.
5. For a path, list its entries, check them with `coversPathWith false` by `decide +kernel`, and
   apply `Block.sound_pathWith_ptrs` or `Block.sound_retWith` with `WalkWith false` (`vadd_paths`
   and `vadd_ret` in `MojoProofTest/Sym.lean`).
6. For a loop-free kernel, `mojo_kernel` summarizes every block, enumerates and checks the paths
   from the entry, and adds `Kernel.sound_of_paths` at them with the premises that remain. With
   the clause `map2`, for a binary elementwise kernel, it also proves the kernel theorem for every
   valid one-dimensional launch and every caller's memory of the precondition `Map2.Pre`
   (`MojoProof/Kernels/Vadd.lean`, `docs/kernel.md`). For a kernel with loops in sequence, one
   `loop` clause per loop gives the thread's run and the kernel theorem through the loops; see
   the previous section.

## Tests

- `MojoProofTest/Sym.lean`: `vector_addition`'s blocks `%4`, `%21`, `%30` and `%31` accepted, and
  twins refused (a wrong register entry, a dropped obligation, the conditions reversed, a
  relabelled atom in the table, reordered effects, another exit, a moved call node, a fast-math
  flag on a special-register call). The paths `%4 → %21 → %31` and `%4 → %30 → %31` are accepted
  (`vadd_paths`), with two twin paths refused. `vadd_ret` takes either path to the `ret` for every
  context of the kernel and thread with one frame at `%4` whose path premises (`WalkWith false`)
  hold.
- `MojoProofTest/SymRun.lean`: the premises on concrete runs. These are a context, a memory with
  four-cell inputs and output, and a frame per thread `i < 4`. `vadd21_cell` and `vadd_cell` show
  that output cell `i` holds FloatLib's binary32 sum of the inputs' cells. The twins fail on an
  index out of range, a missing output buffer and a special register out of its declared range.
  `store_pathMem` runs `Labels.MemOk` through to `Valuation.PathMem` on every launch of a
  one-store kernel.
- `MojoProofTest/SymPhi.lean`: edges into `phi` blocks. One is the naive matmul kernel's path
  through its loop header when the loop runs no trip, which ends with the accumulator's value in
  the output cell (`trip0_cell`). Another is a hand-written `br i1` whose untaken edge has a float
  constant, accepted by `coversTo` (`edge_covers`, `edge_run`). There is also a return to a caller
  frame (`edge_back`, `Block.sound_back`).
- `MojoProofTest/SymLoop.lean`: three hand-written functions. `cnt` is one counting loop, proved
  for every bound up to `2 ^ 60` (`cnt_run`). `cnt2` is two loops in sequence and `nest` two nested
  loops, each run on one bound and one memory (`cnt2_run`, `nest_run`). Twins break a bound, an
  invariant and a header's position, and `naive_latch_refusal` shows a refused latch.

Each test covers the program, contexts, memories and frames it names. The theorems it
instantiates hold for every program, block and path the checkers accept.

## Cost

The summary is linear in the block's size. There is one node of constant size per
value-defining statement, and one obligation per node. `sym_summary`'s quotation, the comparison
`decide (S' = S)` and the prefix check of the obligations are linear too. With operands as trees
instead of node indices, a block whose statement `i` uses statement `i - 1`'s value twice (`twice
n` below) would have a last value with `2 ^ (n + 1) - 1` nodes. The table has `n`.

The kernel's evaluation of `covers` still grows about quadratically. `SState.def` appends each
node at the end of the table (`σ.nodes ++ [nd]`) and takes its length. An operand's lookup in the
registers' entries (`SState.get`, an association list) scans the list for an entry register. On
a concrete valuation, `vals` appends one value at a time and `SVal.eval` looks a node up by
position. A table built by `cons` with its length carried, and an indexed register table, would
make these linear. Neither is done.

## Benchmark

`scripts/SymBench.lean` runs the cases below, from the repository root after
`lake build MojoProof MojoProofKernels`:

    lake env lean scripts/SymBench.lean

The script's docstring describes each case. "Kernel ms" is the time of `addDecl` on the theorem
with the proof `decide +kernel` builds (`of_decide_eq_true (Eq.refl true)`): the kernel's
evaluation alone, with `Elab.async` off. The numbers are from one run on 8 cores of a machine
whose other cores ran other builds, with a peak RSS of 4.46 GB (3.14 GB after the imports); the
timed commands take 44 s in all. Times vary by up to about 2x with the machine's load, so compare
cases measured one after the other, and ratios rather than single times.

| case | statements | obligations in `ds` | kernel ms |
|---|---|---|---|
| `vadd` `%21` | 9 | 9 | 66 |
| `vadd` `%30`, `%31` | 0 | 1 | 8, 7 |
| `vadd` `%21`, one obligation dropped (`false`) | 9 | 8 | 68 |
| `wide 10` / `25` / `50` | 10 / 25 / 50 | n + 1 | 45 / 148 / 436 |
| `wide 100` / `200` | 100 / 200 | n + 1 | 1562 / 5995 |
| `chain 25` / `50` / `100` | 25 / 50 / 100 | n + 1 | 136 / 367 / 1107 |
| `twice 25` / `50` / `100` / `200` | 25 / 50 / 100 / 200 | n + 1 | 136 / 375 / 1090 / 3686 |
| `et 25` / `50` / `100` / `200` (obligations evaluated) | 25 / 50 / 100 / 200 | | 146 / 402 / 1587 / 5872 |
| `loads 50`, `!invariant.load` / none | 50 | 51 | 553 / 568 |
| `wide 50`, 100 / 1000 extra conditions after | 50 | 151 / 1051 | 533 / 554 |
| `mm67` | 191 | 192 | 10833 |
| `tiled_matmul` `%67` itself (`summarize` is `none`) | 208 | | 91 |
| `sels 50` (a chain of `select`s, later run) | 50 | 51 | 255 |
| naive matmul `%6` (`llvm.smax`, `select`; later run) | 37 | 39 | 469 |
| `mm67c`: `mm67` with its `fmul contract`s, by `coversC` (third run) | 191 | 192 | 8354 |
| naive matmul `%52` (`fmul contract`, `fadd contract`), by `coversC` (third run) | 14 | 17 | 73 |

`sym_summary` computes the summary of `%21` in 17 ms and that of `mm67` in 239 ms (elaboration
and kernel).

The rows marked "later run" are from a later run of the same script, on a less loaded machine:
there `chain 50` took 249 ms, `wide 50` 334 ms and `mm67` 7885 ms. The rows marked "third run"
are from a third run: there `chain 50` took 252 ms, `wide 50` 332 ms and `mm67` 8429 ms. Their
summaries are definitions the kernel unfolds (`summarizeC`), so their times include computing
the summary once more.

What the numbers show:

- Sharing keeps the size linear. `twice 200` is checked in 3.7 s, and the kernel evaluates its 201
  obligations on a concrete valuation (`et 200`) in 5.9 s.
- Kernel time grows faster than the block's size. Per doubling it grows ×3.8 on `wide` (100 to
  200), ×3.0 on `chain` (50 to 100), ×3.4 on `twice` and ×3.7 on `et` (100 to 200), about the
  square (see "Cost"). `chain` and `twice` find their operand at the head of the registers'
  entries, so their growth is the table's append and length alone. `wide 200` costs 1.6 times
  `twice 200`, which bounds what the lookups add there.
- A `select` node costs what an integer operator's does: `sels 50` takes 255 ms against
  `chain 50`'s 249 ms in the same run.
- `coversC` costs what `covers` does: `mm67c`, with its 16 `fmul contract` nodes, takes 8354 ms
  against `mm67`'s 8429 ms in the same run.
- The obligation check is by position: 900 more conditions after the summary's own add 21 ms to
  `wide 50` (100 and 1000 extra conditions).
- `mm67`, `tiled_matmul`'s largest block between its barriers (191 statements, 32 loads, 16
  `fadd contract` nodes), takes 10.8 s in the kernel. The run's peak RSS is reached there.
- The elaborator's tactics (`#etime`, elaboration and kernel together) take 3.2 to 3.8 times the
  kernel alone. `decide` takes 209 ms on `%21` and 169 / 537 / 1670 ms on `wide 10` / `25` /
  `50`; `rfl` takes 213 ms and 166 / 569 / 1649 ms. The elaborator evaluates the instance by
  `whnf`, then the kernel checks it again. `rfl` on `wide 100` stops at the maximum recursion
  depth after 159 ms, and on `mm67` it fails at once (9 ms); `decide +kernel` succeeds on both.
  `simp` with `decide := true` and the checker's definitions as lemmas (301 ms on `%21`, 174 /
  573 ms on `wide 10` / `25`) closes the goal by its `decide` step without the lemmas (the
  linter reports each lemma unused), so it costs what `decide` does.

## Names (`String` comparison in the kernel)

`covers` compares no function names, only metadata keys (`checkMd`, `"noundef"`,
`"invariant.load"`), and those cost nothing measurable (`loads 50` above). The semantics compares
names in three places:

- where `exec` reaches a call (`c.prog.module.funcs.find? (·.name == g)` and
  `c.prog.intrinsics.lookup g`);
- where `step` checks a `norecurse` callee against the frames;
- where an operand is a global (`Value.glob name`), and so where `SNode.globalAt`'s value reads
  the context's globals; the checker's `getelementptr` case matches `.glob` and compares no name.

Measured in the kernel with `#ktime` on `vector_addition`'s program (4 functions), in the run
above:

- 1000 comparisons of an equal 29-character intrinsic name take 166 ms (174 ms when the last
  character differs), against 112 ms for 1000 `Nat` comparisons;
- the two lookups of a call take 0.90 ms (100 calls: 90 ms), against 0.12 ms for a lookup by
  index (100: 12 ms).

So a name costs about 0.05 ms per comparison over a `Nat`, and a call about 0.8 ms over an index.
This does not matter for the block checker. A grid-level certificate that evaluated `exec` in the
kernel on every thread would pay 0.8 ms per evaluated call: about 0.6 s for 768 calls (256
threads, 3 calls each), small against the block checks above. Interning (resolving callee names
to indices once, when the program is built) is not done.
