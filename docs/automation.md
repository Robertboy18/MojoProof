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

## A warp's run through its shuffles: what is automated and what is not

A warp's run (`WarpRun`, MojoProof/Sym/Canon.lean) through `J` shuffles is `WarpRun.of_waits`
from four premises over the lanes `j ∈ warpLanes L k` and, but for the first, the phases
`i < J`: the lanes' runs through their waits (`hr`), the waits' shuffles (`hW`: the intrinsic and
mode, the position lane 0's, the four arguments with the value `X i j`, and the delivery under the
declaration's attributes), the waits' memories (`hm`) and each phase's start (`h0`). Four warps are
proved this way: `warp78` and `warp43` (MojoProofTest/GemvWarp.lean, seven and two phases),
`skipWarp` (no phase) and `shflWarp` (one phase, MojoProofTest/SymCanon.lean).

`warp_route` (MojoProof/Sym/WarpRoute.lean, `docs/tactics.md`) does all of it in the four:

- it takes the goal `∃ Es, WarpRun L c k t m Es m'`, the of_waits arguments by name (`J`, `fn`,
  `lbl`, `W`, `mo`, `X`, `M`), optional terms (`using`) and the hypotheses, found by their types:
  every `∀ j < N, P j` with `N` the lane count, directly or through a hypothesis
  `(warpLanes L k).length = N`;
- it emits the proof term of `WarpRun.of_waits` with each premise it closes and leaves the others
  as goals, in of_waits's order and form; the hypotheses `∀ j < N` become `∀ j ∈ warpLanes L k`
  under their names;
- the lanes' runs (`hr`): from a lane's run in `RunsVia.of_fires`'s form (a hypothesis, or a lane
  lemma after `using` whose premises the lane's facts fill), `Runs` with no wait or `RunsVia`
  through `ws.map (Piece.Wait.via fn l)` or `a.map (Piece.Wait.via fn l₁) ++
  b.map (Piece.Wait.via fn l₂)`, by `RunsVia.of_runs`, `RunsVia.of_block` or
  `RunsVia.of_blocks`, the lists' lengths found among the lane's facts and the labels decided;
- the shuffles (`hW`): by `WarpRun.shfl_of`, for every launch, contexts, warp, number of phases,
  program, modes, positions, lane operands, clamps, offers, memories, default wait and lanes'
  waits, from the lanes' one program and each lane's `Piece.Wait.shflOk` (a Boolean: each wait's
  shuffle mode, position, full mask, offer, lane operand, clamp and `Grid.fire`'s delivery), its
  keeping premise from a fact, a term or `Program.shfl_nil` with `Program.shflNil` (no shuffle
  declaration of the program puts an attribute on its result);
- the waits' memories (`hm`) and the phases' starts (`h0`): by a term or hypothesis whole, or lane
  by lane and phase by phase (a case per phase for a numeral `J`) by the facts at the lane, `rfl`
  or their conjuncts.

Each of the four is one call with no other proof line: `warp78` and `warp43` `using` gemv's lane
lemma (`lane` or `lane43`), `start_frame`, `out_covers` (`warp78` only), `mems_of` and `gemv_nil`
(`gemv.prog.shflNil`, by `decide +kernel`); `skipWarp` `using skipLane`; `shflWarp` `using`
SymCanon's `lane`, `prog_eq` (every thread's context runs `prog ra`) and `keep` (the shuffle's
declaration keeps a delivery the attributes `ra` keep). Gemv's own check, its no-attribute
lemma and its shuffle premise are deleted: `Piece.Wait.shflOk`, `Program.shflNil`,
`Program.shfl_nil` and `WarpRun.shfl_of` are their library forms, and gemv's `ok78` and `ok43`
decide `Piece.Wait.shflOk`. The two files' proofs have 278 proof lines (147 and 131) where they
had 365 (216 and 149).

Left to the user:

- the lane lemma (the run of one lane through its waits, in `RunsVia.of_fires`'s form) and the
  Boolean checks a kernel's proof decides (`ok78`, `ok43`, `gemv_nil`, `shflWarp`'s `Checks` and
  per-lane `Piece.Wait.shflOk`);
- a keeping lemma when the program's shuffle declarations put attributes on their results
  (SymCanon's `keep`, from `shfl_decl`), and lemmas for the waits' memories that no lane fact
  states (gemv's `mems_of`);
- a lane's run in another form (waits that are not a `List.map` of `Piece.Wait.via`, or more than
  two blocks) and shuffles that `Piece.Wait.shflOk` does not state: they stay goals, as
  `WarpRun.of_waits` states them. SymColl's and SymChain's `warp` (MojoProofTest/SymColl.lean,
  MojoProofTest/SymChain.lean, two butterfly shuffles, the second at 4 and 8 threads) are one
  `warp_route` call each, from a lane lemma (`lane`), the lanes' lengths and program (`waits`,
  `progs`), the lanes' `Piece.Wait.shflOk` (`shfls`), `SymColl.mems` and `Program.shfl_nil`:
  85 to 62 and 133 to 119 proof lines. SymChain's `shfl_wait`, the warp to the second shuffle's
  waits, is `WarpWait.of_waits` (MojoProof/Sym/WarpWaits.lean), the waiting warp's
  `WarpRun.of_waits`: from the same lane lemma, `shfls` and `Program.shfl_nil`, the first
  shuffle's premise in `WarpRun.of_waits`' form by `WarpRun.shfl_of`, not a `WarpShfl` on the
  lanes' statuses. `fires` is `WarpShfl.of_waits` from the same premises. The waits pin a lane's
  position, call and arguments, not its thread or callee, so `WarpWait.of_waits` also concludes
  each lane's status as `statusAt` (MojoProof/Sym/WarpWaits.lean), the status the lane's thread
  reaches after its first `J` deliveries; the statement on the statuses `stat k 2` is an `example`
  from `shfl_wait`, `statusAt` being `stat k 2` by the runs to the waits (`stops`, `nextWait_eq`).

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

## `mojo_kernel` on gemv_kernel and gevm_kernel

`mojo_kernel` proves neither kernel today. On each it stops at the first block outside the
checker's fragment, before it enumerates a path. This was measured on 2026-11-27 with a scratch
module that imports both programs (`MojoProofTest/SymLane.lean`) and states
`mojo_kernel … := gevm.prog gevm.fn_0 scalars x := a3, n := a4, k := a5 pointers out := a0,
a := a1, b := a2` (gemv's the same with `m`, `x`, `k`, `out`, `a`, `v`), with and without
`contract`. `#mojo_info` gave each block's verdict.

- **gevm_kernel** (the corpus file `gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae`).
  - Without flags, it stops with `mojo_kernel: block %45 (block 4 of gevm.fn_0) is outside the
    checker's fragment`. The block is the latch, and statement 11 is
    `%57 = fmul contract float %52, %56`.
  - With `contract`, it stops with `mojo_kernel: block %59 (block 5 of gevm.fn_0) is outside the
    checker's fragment with fmul contract`. Statement 6 is
    `call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)`.
  - The first missing capability is the barrier: a collective inside a block. The checker cuts
    such a block into segments that end at a collective (`summarizeTo`, `summarizeSegs`; the
    section on segments above), but `mojo_kernel` summarizes whole blocks only.
  - Next in line:
    - the five `shfl.sync.bfly` calls of the same block;
    - the shared array, a global in address space 3, which `mojo_kernel` refuses under `map2`
      and `mat`;
    - the loop `%39`-`%45`, one round `%39 → %43 → %45` of trip count `(K + 31) / 32`: the
      `loop` clause takes a trip count that is a function of the entry valuation, but its
      invariant and the tactic that proves a round at every round number are the user's (by
      hand today, `OblGevmRun.loop`), and its path out runs through `%59`; not measured, since
      the command stops at `%59` first;
    - the spec: the spec clauses of `mojo_kernel` are `map2` (elementwise) and `mat` (a matmul
      whose arguments are `byval` structs). Neither is `Spec.vecMat` on pointer arguments.
- **gemv_kernel** (the corpus file `gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b`).
  - Without the flag `alloca`, with or without `contract`, it stops with `mojo_kernel: block %6
    (block 0 of gemv.fn_0) is outside the checker's fragment`. Statement 0 is
    `%7 = alloca [2 x ptr], i64 1, align 8`.
  - With `alloca` (`… pointers y := a0, a := a1, x := a2 alloca`) it stops with
    `mojo_kernel: block %6 (block 0 of gemv.fn_0) is outside the checker's fragment with alloca
    at statement 17: %24 = call i32 @llvm.nvvm.shfl.sync.idx.i32(i32 -1, i32 %22, i32 0, i32
    31)`, and with `contract alloca` with `… with alloca and fmul contract at statement 17: …`.
    `%6` runs its three `alloca`s and the 14 statements after them; statement 17 is the first
    `shfl.sync.idx`, a collective. Under the flag the message names the first statement the
    checker refuses (`refusalAt`, MojoProof/Sym/Info.lean), as LLVM text; without it the
    message is as before. `gemvA`, `gemvAC` and `gemvA_twin` (MojoProofTest/SymAlloca.lean) pin
    the three messages under `#guard_msgs`; `gemv_allocas` and `gemv_allocas_twin` pin the
    checker's own stop (`summarizeAt`).
  - What the flag proves, for every program: `mojo_kernel n := P fn … alloca` summarizes every
    block with `summarizeAt true`, checks the paths from the entry by `coversEntryAt true
    contract` (`n.covers`) and adds `n.sound_of`, `Kernel.sound_of_chainsAt (alloca := true)` at
    them (MojoProof/Sym/Kernel.lean): the kernel theorem for that one program, for every
    launch, arguments, memory, admission, observation and rule, whose per-thread premise is each
    thread's predicate on the memory its run leaves with its `alloca` blocks dead (`Mem.Dead
    true`; a thread's run leaves them dead, `Runs.of_retAt` and `Runs.of_chainsAt`,
    MojoProof/Sym/Loop.lean). `Kernel.sound_of_chainsAt` is for both values of the flag; at
    `alloca := false` each thread's predicate is the invariant itself (`Mem.Dead false m Q` is
    `Q`). The `loop` clause, `map2` and `mat`
    refuse the flag, each with one message (their theorems are with the flag off). The test is
    `pathA` (MojoProofTest/SymAlloca.lean), on the two-block alloca path of `pathText`: its
    `covers`, its `sound_of`, and `pathA_sound`, the theorem's premises met at a launch of one
    thread from the empty memory, the two `alloca` blocks dead at the end.
  - Next in line:
    - `%6` statements 17 and 18, its two `shfl.sync.idx` calls. Then come the calls of
      `llvm.lifetime.start` and `llvm.lifetime.end` in statements 19 to 28. `summarizeAt`
      refuses these too. The checker's segments end at them (`summarizeLife`), but
      `mojo_kernel` summarizes whole blocks (the plan below);
    - `%78` stops at its first `shfl.sync.bfly` (statement 2), with or without the flag;
    - `%70` needs `contract`: statement 2 is `%73 = fmul contract float %71, %72`;
    - the loop `%54`-`%76`, of trip count `⌈K / 32⌉`, has two rounds (`%54 → %58 → %60`, then
      `%70` or `%75`, then `%76`), and the `loop` clause takes one round per loop (an error
      otherwise, MojoProof/Sym/KernelCmd.lean), and is not combined with `alloca`; not
      measured, since the command stops at `%6` first;
    - the spec, `Spec.matVec`, which has no clause either.

**The gaps that remain.** Of the four gaps between `mojo_kernel` and these two kernels, the flag
closes the first: the command now passes the checker's `alloca` flag, with its kernel theorem.
Three remain: segments split at collectives (barriers and shuffles inside a block; gevm's `%59`,
gemv's `%6` and `%78`; the plan below), a spec clause for `Spec.vecMat` and `Spec.matVec` on
pointer arguments, and a `loop` clause with more than one round per loop or a symbolic trip
count with the user's invariant (gemv's `%54`-`%76`, gevm's `%39`-`%45`).

**What a generator would have to produce.** Both kernel theorems are assembled by hand from the
library. Four steps are now one library theorem each, for every program
(`MojoProof/Sym/SigKernel.lean`):

| Step | Library theorem | What each kernel writes |
|---|---|---|
| The start | `Grid.start_of_check` | `starts`, 1 line by `kernel_rfl` for gemv and 3 for gevm, whose launch check is `Func.checkLaunch_maxntid` (were 8 and 14) |
| The assembly | `kernel_sound_sig`, through Theorem 0 at `sig` (`sound_sig`) | `kernel_sound`, 10 lines for gemv and 8 for gevm (were 17 and 11) |
| Not bad | `Grid.not_bad` and `Grid.not_bad_cells` | gevm's `grid_bad`, 71 lines (was 106); gemv's `racy_ev` and `kept_ev` are its own argument by owners, 40 lines |
| A store's write in the trace | `Ext.store` | gemv's `ext_out`, 7 lines (was 12); gevm's `Warp.mout_ext`, 4 lines (was 15) |

The rest is per kernel. Hand-written proof lines (prooflines.py):

- gemv_kernel: 2352 lines in 12 files (was 2378);
- gevm_kernel: 1148 lines in 9 files (1145 before `GevmSound.starts`' launch check; 1301 in 10, with
  OblGevmWhole.lean, before that).

A generator would have to produce the following:
- each block's or segment's summary and its `covers` check (by `decide +kernel` today);
- the thread's run through its loop: the loop's invariant and its rounds (`GemvLoop`,
  `OblGevmRun`);
- the warp's run through its shuffles (`GemvWarpRun`, 770 lines; `GevmWarp1.warp` and `resume`,
  85 lines);
- for gevm, the block's run to the barrier and after it (`GevmWarp0.block`, `GevmWarp1.block`,
  130 lines);
- the grid's run (`GemvSound.grid_end`, 44 lines; `GevmWarp1.blocks` and `grid`, 110 lines);
- the cells and owners of each access (gevm's `grid_bad`);
- the spec's relation (`rows_holds` and `cols_holds`).

### The plan: blocks cut at their collectives

`mojo_kernel` summarizes whole blocks, so it stops at the first collective inside a block:
gevm's barrier in `%59`, gemv's `shfl.sync.idx` in `%6` (with `alloca`) and its first
`shfl.sync.bfly` in `%78`. This is the plan for a clause that cuts blocks at their collectives,
and for the kernel theorem it needs. Step 1 is built (below).

**What the checker already has.** Each of these is for every program, function, block and
thread its statement names:

| Declaration | Where | What it gives |
|---|---|---|
| `summarizeTo` | MojoProof/Sym/Segment.lean:158 | the summary (`SegSummary`, :131) of positions `p0` to `p1 - 1`, ending at the collective call at `p1` with its argument terms |
| `Seg.sound` | Segment.lean:333 | from a frame at `p0` that meets the obligations, the steps reach `p1` and the step there is the collective's `.wait` |
| `summarizeLife` | Segment.lean:668 | a segment that ends at a lifetime marker; `Seg.lifetime` (:805) runs it past the marker |
| `summarizePieces` | Segment.lean:883 | a block's segments at the positions `ps` (`Piece`, :862, a collective's or a marker's, by `summarizePiece`, :872), and the summary of the rest |
| `Piece.through` | Segment.lean:1042 | one thread runs the segments and the rest of the block (`Piece.Through`, :952), the deliveries a parameter |
| `RunsVia` | MojoProof/Sym/OblSeg.lean:78 | a thread's run through a list of waits to its end; a block's waits are `Piece.Wait` (:246) at `Piece.Wait.via` (:265) |
| `RunsVia.of_fires` | OblSeg.lean:358 | `RunsVia` through `Piece.waits` (:317) from `Piece.Through` and the Boolean `Piece.fires` (:340) at the entry valuation |
| `RunsVia.of_ends`, `RunsVia.of_chain` | OblSeg.lean:221, :474 | after the last collective, a path to the `ret`; a chain of loops into a block |
| `RunsVia.of_runs`, `.of_block`, `.of_blocks` | MojoProof/Sym/WarpRoute.lean:56, :65, :84 | `RunsVia` for a run with no wait, and restated at one block or two |
| `Piece.Wait.shflOk` | WarpRoute.lean:101 | the Boolean check of one lane's waits against the shuffles (mode, position, full mask, offer, lane operand, clamp, `Grid.fire`'s delivery) |
| `WarpRun.shfl_of` | WarpRoute.lean:139 | `WarpRun.of_waits`' shuffle premise from every lane's `Piece.Wait.shflOk` and the declarations' keeping (`Program.shfl_nil`, :120) |
| `warp_route` | WarpRoute.lean:751 | the tactic: one warp's `WarpRun` from a lane lemma and these checks |
| `WarpRun.of_waits`, `WarpWait.of_waits` | MojoProof/Sym/Canon.lean:531, MojoProof/Sym/WarpWaits.lean:270 | one warp's run through its shuffles to its end (`WarpRun`), or to its `J`-th waits (`WarpWait`), from its lanes' `RunsVia` |
| `WarpWait.of_upto`, `RunsVia.cut` | WarpWaits.lean:155, :113 | one warp's run to its `J`-th waits from its lanes' runs to them and no further (`RunsUpto`, :58), and a lane's `RunsVia` cut at its `J`-th wait (`RunsVia.upto`, :68; `RunsVia.drop_statusAt`, :87) |
| `CanonRun.of_inv` | Canon.lean:598 | the warps in turn (`CanonRun`) by a memory invariant |
| `BlockBar.of_waits`, `CanonWait.of_merge`, `BlockRun.of_inv`, `PhaseRun.of_inv` | MojoProof/Sym/CanonBar.lean:142, :626, :665, :696 | a block's barrier from its threads' waits, the warps to their waits, a block's phases, the blocks in turn |
| `CanonRun.start_sound`, `PhaseRun.start_sound` | CanonBar.lean:808, :546 | Theorem 0 at a canonical run, or at a run at the phase level, with `EndChecks` (:532) |
| `WarpSegs.run`, `WarpSegsTo.wait`, `WarpSegsBar.wait` | MojoProof/Sym/KernelWarps.lean:103, :225, :272 | one warp's run to its end (`WarpRun`), or to a barrier (`WarpWait`), from its premises in the checker's form (`WarpSegs`, :79; `WarpSegsTo`, :189, its lanes' runs stopping at the barrier; `WarpSegsBar`, :138, its lanes' runs to their ends, cut by `WarpSegsBar.to`, :251) |
| `Kernel.run_of_prefixes`, `Kernel.run_of_phases` | KernelWarps.lean:328, :410 | a start's run through each block's phases (`Kernel.Prefixes`, :297; or each phase to a barrier a `WarpSegsBar`) to a done grid whose memory is of the last memory predicate, with no end checks: the run and done conjuncts of `kernel_sound_sig`'s run premise (MojoProof/Sym/SigKernel.lean:156) |
| `Kernel.sound_of_prefixes`, `Kernel.sound_of_phases`, `Kernel.sound_of_warps` | KernelWarps.lean:446, :485, :532 | the kernel theorem from each block's phases between its barriers (`Kernel.Prefixes`, or `WarpSegsBar`), or with no barrier |

The command uses none of these: it calls `summarizeAt` (MojoProof/Sym/Checker.lean:526)
on whole blocks, `coversEntryAt` (MojoProof/Sym/Kernel.lean:280) on paths of whole blocks, and
`Kernel.sound_of_chainsAt` (Kernel.lean:332), whose threads run in turn, one after another
(`Seq.start_sound_inv`, MojoProof/Sym/Sched.lean:374), with no collective between them.

**The kernel theorem.** It is in two parts, warps first and then blocks with barriers.

1. Built: `Kernel.sound_of_warps` (MojoProof/Sym/KernelWarps.lean:532), for kernels whose
   collectives are shuffles. `WarpSegs` is one warp's premises in the checker's form: its lanes'
   `RunsVia` through their waits (`RunsVia.of_fires`), each lane's `Piece.Wait.shflOk`, the
   declarations' keeping, the waits' memories and each phase's start, that is,
   `WarpRun.of_waits`' premises with `WarpRun.shfl_of`'s in place of its shuffle premise:

   ```lean
   theorem Kernel.sound_of_warps {prog : Program} {fn : Func} {L : Launch} {args : List Val}
       {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
       {obs : Mem → Option β} {R : β → Prop} (hm : m.BytesIn m.Known)
       (hb : 0 < volume L.block)
       (hs : ∀ ch oracle, adm ch oracle →
         ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
       (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
       (H : ∀ ch oracle g c, adm ch oracle →
         Grid.start prog fn L args m ch oracle = .ok (g, c) →
         ∃ P : Nat → Mem → Prop, P 0 g.mem ∧
           (∀ i (hi : i < (warps L g.threads.size).length), ∀ m₀, P i m₀ →
             WarpSegs prog fn L c (warps L g.threads.size)[i] (Grid.thread g) m₀
               (P (i + 1))) ∧
           ∀ m', P (warps L g.threads.size).length m' → EndChecks L obs R m') :
       Kernel.Sound prog fn L args m adm obs R
   ```

   Its proof was `WarpSegs.run` (`WarpRun.of_waits` with `WarpRun.shfl_of`) at each warp, the
   warps in turn by `CanonRun.of_inv`, then `CanonRun.start_sound`: 8 proof lines, and 7 for
   `WarpSegs.run`. It is now the case `J b = 0` of `Kernel.sound_of_phases` (below), its
   statement unchanged: 45 proof lines, of which 20 are the index arithmetic that makes block
   `b`'s `w`-th warp the grid's `b * nw + w`-th (`nw` the number of a block's warps; the grid's
   warps are the blocks' in turn, `warps_blocks`, and `Grid.start_size`), and 7 the warp's
   `WarpSegs` at the grid's index with its lanes' threads the start's. Its memory invariant is
   indexed by warps where `Kernel.sound_of_chainsAt`'s is indexed by threads.
2. Built: `Kernel.sound_of_phases` (KernelWarps.lean:485), with barriers. `WarpSegsBar … bar l p
   V Q` (:126) is one warp's phase that ends at a barrier: `WarpSegs`' premises for the phase's
   `J` shuffles out of `N > J` waits, each lane's `J`-th wait the barrier call on the word `bar`
   at block `l`, position `p`, delivering no value, `Q` of the memory after the last lane, and
   each lane resumed there of `V` (from its run through the waits after the `J`-th, as
   `WarpWait.of_waits` concludes it). The theorem's statement is this one:

   ```lean
   theorem Kernel.sound_of_phases {prog : Program} {fn : Func} {L : Launch} {args : List Val}
       {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
       {obs : Mem → Option β} {R : β → Prop} (hm : m.BytesIn m.Known)
       (hb : 0 < volume L.block)
       (hs : ∀ ch oracle, adm ch oracle →
         ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
       (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
       (H : ∀ ch oracle g c, adm ch oracle →
         Grid.start prog fn L args m ch oracle = .ok (g, c) →
         -- block `b` has `J b` barriers; `T b i n`: thread `n` in phase `i`;
         -- `P b i w`: the memory after the first `w` warps of phase `i`
         ∃ (J : Nat → Nat) (T : Nat → Nat → Nat → Thread → Prop)
           (P : Nat → Nat → Nat → Mem → Prop),
           (∀ n, T (n / volume L.block) 0 n (Grid.thread g n)) ∧ P 0 0 0 g.mem ∧
           (∀ b < volume L.grid, ∀ i < J b, ∃ bar < 16, ∃ l p,
             ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
               (∀ j ∈ warpLanes L (blockWarps L b)[w],
                 T b i ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
               P b i w m₀ →
               WarpSegsBar prog fn L c (blockWarps L b)[w] t m₀ bar l p (T b (i + 1))
                 (P b i (w + 1))) ∧
           (∀ b < volume L.grid, ∀ i < J b, ∀ m₁, P b i (blockWarps L b).length m₁ →
             P b (i + 1) 0 (m₁.log (.barrier b))) ∧
           (∀ b < volume L.grid, ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
             (∀ j ∈ warpLanes L (blockWarps L b)[w],
               T b (J b) ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
             P b (J b) w m₀ →
             WarpSegs prog fn L c (blockWarps L b)[w] t m₀ (P b (J b) (w + 1))) ∧
           (∀ b < volume L.grid, ∀ m₁, P b (J b) (blockWarps L b).length m₁ →
             P (b + 1) 0 0 m₁) ∧
           ∀ m', P (volume L.grid) 0 0 m' → EndChecks L obs R m') :
       Kernel.Sound prog fn L args m adm obs R
   ```

   Its proof, as planned: in phase `i < J b`, each warp to its barrier waits by
   `WarpSegsBar.wait` (:272; then `WarpWait.of_waits`, its shuffles by `WarpRun.shfl_of`, now
   `WarpSegsTo.wait`, :225, at `WarpSegsBar.to`, below), the
   block's warps by `CanonWait.of_merge` with each thread's status the barrier wait
   (`blockWarps_nodup`, CanonBar.lean:113), the barrier by `BlockBar.of_waits` (the waits'
   threads are the resumed ones, `Status.wait.inj`); in phase `J b`, `WarpSegs.run` and
   `CanonRun.of_inv`; the phases by `BlockRun.of_inv` (its thread predicate: every thread of
   the block of `T b i`; its memory predicate `P b i 0` up to `J b`, then `P (b + 1) 0 0`), the
   blocks by `PhaseRun.of_inv`, then `PhaseRun.start_sound`: 57 proof lines, and 15 for
   `WarpSegsBar.wait`. No lemma was missing. Since then the run part is its own theorem,
   `Kernel.run_of_phases` (KernelWarps.lean:410): the same proof up to the blocks, then
   `PhaseRun.start_done` in place of `PhaseRun.start_sound`, concluding the run to a done grid
   whose memory is of `P (volume L.grid) 0 0`, with no `EndChecks`; `Kernel.sound_of_phases` is
   that theorem, then `Grid.start_done_sound` with `EndChecks` at the end memory.

   What the definition of `WarpSegsBar` adds to the plan's words, and why: the number `N` of each
   lane's waits and the lanes' final predicates `F` are its witnesses (`WarpWait.of_waits` takes
   them); the barrier wait's facts are fields (its call `.barrier`, its position `p`, its one
   argument whose word is `bar`, no value delivered, its memory `M J (j + 1)`), since
   `BlockBar.of_waits` needs the word and the position and `WarpWait.of_waits` the memory; and the
   clause for `V` is an implication from what `WarpWait.of_waits` concludes about the lane (its
   status there, `statusAt` of its first `J` deliveries, is the wait by thread `u`; `u` is at
   `(fn.name, l, p)`; the lane runs from `u.resume none` through the waits after the `J`-th),
   so that a test proves `V` from the thread `statusAt` computes.

   It generalizes `Kernel.sound_of_warps`, the case `J b = 0` for every block (proved, above),
   and through it `Kernel.sound_of_chainsAt`, the case with no collective, where each warp's
   `WarpSegs` at no shuffle is its lanes' runs (`RunsVia.of_runs`). The second reduction is not
   proved: Kernel.lean is not changed here. Its statement is `Kernel.sound_of_chainsAt`'s
   (Kernel.lean:332) unchanged, and its proof plan:

   1. Kernel.lean cannot import KernelWarps.lean: KernelWarps reaches Kernel.lean through
      WarpWaits, WaitAt, WaitVia, SegTrace and OblLemmas. So `Kernel.sound_of_chainsAt` (name
      and statement unchanged) moves from Kernel.lean to KernelWarps.lean, or to a module that
      imports it, and KernelCmd.lean, its one user in the library, imports that module (it is
      not in KernelWarps' imports, so there is no cycle); the tests that name it import it too.
   2. The per-thread part of the present proof (from `Grid.start_thread` to `Runs.of_chainsAt`,
      Kernel.lean:359-382) becomes a lemma: for every thread `k < g.threads.size` and memory `m'`
      of `P k`, `∃ me, Runs (c k) (Grid.thread g k) m' me ∧ P (k + 1) me`.
   3. The statement has no premise `0 < volume L.block`, which `Kernel.sound_of_warps` takes: at
      `volume L.block = 0` the grid has no thread (`Grid.start_size`) and the present proof
      (`Seq.start_sound_inv` with no thread to run) stays; otherwise `Kernel.sound_of_warps`.
   4. Its memory predicate after `i` warps is `P` at the warp's first thread,
      `P (if h : i < ws.length then ws[i] else g.threads.size)`, `ws` the grid's warps
      (`warps L g.threads.size`).
   5. Each warp `k`'s `WarpSegs` is at `J = 0`: no shuffle, so `Piece.Wait.shflOk` at `J = 0` is
      `rfl` and the keeping, the waits' memories and the phases' starts are about no `i < 0`;
      the lanes' memories `M 0 j` are chosen in turn from the lemma of step 2 (by
      `Classical.choose`, `M 0 (j + 1)` from `M 0 j` with `P (k + j)`), and each lane's run is
      `RunsVia.of_runs` of its `Runs`.
   6. `Q (M 0 len)` is `P` at the next warp's first thread: a warp's lanes are its threads
      `k + j`, `j < (warpLanes L k).length`, and the next warp starts at
      `k + (warpLanes L k).length`, or that is `g.threads.size` after the last warp. A lemma
      about `warps` is missing for this: `warpsCover L (warps L N) 0 N = true`
      (`warpsCover`, CanonBar.lean:827, the property `CanonRun.of_turns` takes), with the
      index form `(warps L N)[i + 1]? = some (ws[i] + (warpLanes L ws[i]).length)` derived from
      it.
   7. The end: `P ws.length` is `P g.threads.size`, the `else` branch, and the checks are the
      present premise's.

   The cost: steps 2, 5 and 6 are new proof lines (about 25 moved, 30 new); the move changes
   Kernel.lean and KernelCmd.lean, so every module that imports them is rebuilt (about 10
   minutes, the full build).

What they would replace in the two kernels' proofs (proof lines, prooflines.py; the families of
the table in "What a generator would have to produce" are the start, the assembly, not bad and
the trace's extension, which are library theorems already):

| Kernel | Lemma (file:line) | Proof lines | By |
|---|---|---|---|
| gemv_kernel | `GemvSound.grid_end` (MojoProofTest/GemvSound.lean:283), the end of the run | 44 | `Kernel.sound_of_warps` |
| | `GemvWarpRun.Lanes.grid_run_inv` (MojoProofTest/GemvWarpRun.lean:1367), the warps in turn | 117 | the same |
| | `GemvWarpRun.Lanes.warp` (GemvWarpRun.lean:791) and `GemvWarpRun.Out.warp` (:1229), their `WarpRun.of_waits` calls | 18 and 14 | `WarpSegs.run` |
| gevm_kernel | `GevmWarp1.grid` (MojoProofTest/GevmWarp1.lean:795) and `GevmWarp1.blocks` (:697), the grid's run | 43 and 67 | `Kernel.sound_of_phases` |
| | `GevmWarp0.block` (MojoProofTest/GevmWarp0.lean:279) and `GevmWarp1.block` (GevmWarp1.lean:558), the block to its barrier and after it | 42 and 88 | the same |
| | `GevmWarp0.warp` (GevmWarp0.lean:227) and `GevmWarp1.Warp.warp` (GevmWarp1.lean:375), each warp's run to the barrier and after it | 26 and 59 | `WarpSegsBar`, `WarpSegs` |

What stays per kernel is what the premises ask: the memory invariant and its frame lemmas
(gemv's `Pre.frame`, `warp_frame`, `row_eq`), the lane lemmas (gevm's `GevmWarp1.resume`, 26
proof lines) and their symbolic premises, and the end's
checks (`racy_ev`, `kept_ev`, `rows_of_loads`; gevm's `grid_bad`). Both kernels' theorems are
at `sig` (`GPUProof.Kernel.Sound`, by `kernel_sound_sig`); for them the run part applies,
`Kernel.run_of_phases` (KernelWarps.lean:410, by `PhaseRun.start_done`, CanonBar.lean:518, in
place of `PhaseRun.start_sound`): it gives `kernel_sound_sig`'s run and done conjuncts, and the
kernel gives not bad and the observation from the end memory's predicate.

**gevm's phase to the barrier as a `WarpSegsBar`: what does not match yet.** `WarpSegsBar`'s
lanes' runs (`RunsVia`, MojoProof/Sym/OblSeg.lean:78) go through all of each lane's waits to its
end, the barrier's and the ones after it, from the memory the barrier's wait names (`dlv.2`);
only the clause for `V` uses the part after the barrier, and the next phase's `WarpSegs` asks for
it again. At a gevm warp the part after the barrier is `GevmWarp1.resume`'s run
(MojoProofTest/GevmWarp1.lean:84) through the five shuffles, which needs a memory whose shared
array holds binary32 values (its premise `hv`, :93). A lane's phase to the barrier has only
`GevmWarp0.Bufs` (MojoProofTest/GevmWarp0.lean:46), which says nothing of the shared array's
bytes, and the memory past the barrier is the block's, after all its warps. So at gevm the
`WarpSegsBar` premise would need a memory built for that purpose (the shared array filled with
binary32 bytes), besides each lane's memories `M 0 j` chosen in turn from `GevmWarp0.lane`'s
runs (`GevmWarp0.lane`, :172, concludes an existential memory). A form whose lanes' runs stop at
the barrier's wait (a `RunsVia` with no run to the end, and `WarpWait.of_waits` for it) removes
the first; the reduction of gevm's `grid` and `blocks` waits for it. The prefix form below is
that form. The second point needs no choice: `WarpSegsTo.of_inv` (KernelWarps.lean) takes the
lanes' memories from `nextWait`, one function, from an invariant on each lane's run to the
barrier's wait. The plan for gevm and its remaining obligations are in docs/proofs/gemv.md,
item (e).

**The prefix form: a phase's runs stop at its barrier (steps 1 to 5 built).** A phase to a
barrier asks
of each lane only its run to the barrier's wait; the run after the barrier is the next phase's
premise, which `Kernel.sound_of_phases` already asks (`WarpSegs` or `WarpSegsBar` from the threads
`T b (i + 1)` on the memory `P b (i + 1) 0`). The steps, as planned and then as built:

1. `RunsUpto c ws t m` (MojoProof/Sym/WarpWaits.lean, by recursion on `ws` as `RunsVia`): for
   each pair `(P, d)` of `ws` in turn, a run to a collective call (`ToWait`) whose wait meets
   `P`, then the thread resumed with `d`'s value on `d`'s memory; after the last pair, nothing
   (no run to the end and no final predicate). `RunsVia.upto`: a `RunsVia` through `ws` gives
   `RunsUpto` through `ws.take n`, for every `n`.
2. `WarpWait.of_upto`: `WarpWait.of_waits` with each lane's `RunsUpto` through its first `J + 1`
   waits in place of its `RunsVia` through `N > J` waits to its end, and without the conclusion
   about the run after the `J`-th wait. Its proof is `WarpWait.of_waits`' with `RunsUpto` in the
   lanes' invariant. `WarpWait.of_waits` keeps its statement and becomes its corollary: the
   prefix by `RunsVia.upto`, the run after the `J`-th wait by `RunsVia.drop_statusAt` (from a
   `RunsVia` through `ws` and `statusAt` of its first `n` deliveries being the wait by `u`, the
   `RunsVia` through `ws.drop (n + 1)` from `u` resumed with the `n`-th delivery; by induction on
   `n`, `nextWait_eq` at each wait).
3. `WarpSegsTo … bar l p V Q` (MojoProof/Sym/KernelWarps.lean): `WarpSegsBar`'s fields with no
   `N` and no final predicates `F`, each lane's `RunsUpto` through its first `J + 1` waits, and
   the clause for `V` without the run after the barrier: each lane's thread `u` waiting there
   (`statusAt` of its first `J` deliveries), at `(fn.name, l, p)`, resumed with no value, is of
   `V`. `WarpSegsTo.wait` is `WarpSegsBar.wait`'s conclusion from it (by `WarpWait.of_upto`);
   `WarpSegsBar.to`: `WarpSegsBar … V Q` gives `WarpSegsTo … V Q` (`RunsVia.upto` and
   `RunsVia.drop_statusAt` for `V`'s premise), so `WarpSegsBar.wait` (statement unchanged) is
   `WarpSegsTo.wait` at it.
4. `Kernel.run_of_prefixes` and `Kernel.sound_of_prefixes`: `Kernel.run_of_phases`' and
   `Kernel.sound_of_phases`' statements with `WarpSegsTo` in place of `WarpSegsBar`, their proofs
   the present ones. `Kernel.run_of_phases` and `Kernel.sound_of_phases` keep their statements
   and become their corollaries (each phase's `WarpSegsBar` by `WarpSegsBar.to`);
   `Kernel.sound_of_warps` (no barrier) is unchanged, a corollary of `Kernel.sound_of_phases`.
   A premise is dropped, none added: the new theorems generalize the old ones (the old are their
   instances at the `WarpSegsTo` that `WarpSegsBar.to` gives).
   As built, the start's premises on the phases are one definition, `Kernel.Prefixes prog fn L c
   g J T P` (KernelWarps.lean:297: the start's threads and memory, each phase to a barrier a
   `WarpSegsTo`, the barrier's log, the last phase's `WarpSegs`, each block's end), which
   `Kernel.run_of_prefixes` (:328) takes and `Kernel.sound_of_prefixes` (:446) asks for each
   admitted start with the end checks: restating `Kernel.sound_of_phases`' 33 lines with one word
   changed made the two a near-duplicate cluster (scripts/near_dups.py). `Kernel.run_of_phases`
   (:410) and `Kernel.sound_of_phases` (:485) keep their statements and are corollaries
   (`WarpSegsBar.to` at each phase); `WarpWait.of_waits` (WarpWaits.lean:270) and
   `WarpSegsBar.wait` (:272) keep theirs and are corollaries of `WarpWait.of_upto` (:155) and
   `WarpSegsTo.wait` (:225). The cut is `RunsVia.cut` (WarpWaits.lean:113).
5. Tests. In MojoProofTest/KernelPhases.lean, `seg_to`: SymColl's warp's phase to the barrier as
   a `WarpSegsTo` from SymChain's `waits` alone (`seg_bar` needs `lane` past the barrier too),
   and the kernel sound by `Kernel.sound_of_prefixes` from it. The instance the review asks for
   is a kernel of two warps parsed from text, one block of 33 threads (`launch2 1 1 33 1`, warp 0
   of 32 lanes and warp 32 of one), a shared array `@sh` of two `i32`s: thread 32 stores 7 to
   word 0 of `@sh` before the barrier, thread 0 loads word 0 after it and stores it to word 1,
   every thread waits at the barrier. Its statement: `Kernel.Sound` at that launch, no
   arguments, on the empty memory, admission 0, observation word 1 of the block's `@sh`, `R`
   that it is 7, by `Kernel.sound_of_prefixes` with `J = 1`: phase 0's memory predicates name
   word 0's bytes (undefined before warp 32 runs, 7 after), phase 1's word 1's. The phase-0
   premise of warp 0 is a `WarpSegsTo` with no run past the barrier; warp 0's phase-1
   `WarpSegs` is the one proof that reads `@sh`, from the memory after the barrier. The twin:
   the same kernel with the store after the barrier, where thread 32's store and thread 0's load
   of word 0 are in one phase, a data race, so the kernel is sound for no observation and `R`.
   Built: `seg_to`, `prefixes` (`Kernel.Prefixes` at SymColl's one barrier), `sound` by
   `Kernel.sound_of_prefixes` (statement unchanged), and the twin `bar_other_to` (no `WarpSegsTo`
   at a barrier word other than 0; `bar_other` is now its corollary). The two-warp instance is
   MojoProofTest/KernelTwoWarp.lean: `sound` (`Kernel.Sound prog kern L33 [] {} adm0 (obs shB)
   (· = leBytes 4 7)`) by `Kernel.sound_of_prefixes` at `prefixes` (`J = 1`), each warp's phase
   0 a `WarpSegsTo` (`seg_to`, by `WarpSegsTo.of_inv`) and its phase 1 a `WarpSegs` (`seg_end`);
   the memory predicates are equalities with the memories each lane's run leaves in turn (`pm`),
   not statements about word 0's and word 1's bytes as planned above. Its twin `race`
   (`¬ Kernel.Sound progLate kernLate L33 [] {} adm0 o R` for every type `β`, observation `o` and
   relation `R`) is `Kernel.replay_unsafe` at the race the checker reports.

   **What is still done by hand there**, each a step the command does not take:
   - the program: `kern` and `kernLate` are written in the parser's form and checked against
     `importBytes text` by `#guard`, as MojoProofTest/SymCanonBar.lean does; no command imports
     a text written in a test (`mojo_import` reads corpus files);
   - the lanes' runs: `lanes` states each thread's run to the barrier and past it as `runTo`
     equations on the memories the threads before it leave (`chain`, from `next`), decided by
     the kernel one thread at a time (33 `interval_cases` goals, `kernel_rfl_late`);
   - the phase premises: the thread predicates `T`, the memories `pm` and their seven
     equations, the per-warp `WarpSegsTo` and `WarpSegs` witnesses (`J = 0`, the barrier wait
     `bw`, the lanes' memories), and the case split over the block's two warps (`phase0`,
     `phase1`); `mojo_kernel`'s `barrier` clause (below) would derive them from the summaries;
   - the end checks: `racy`, `kept` and the observation decided on the last memory by
     `decide +kernel` and `kernel_rfl`, as in the other tests.
   Elaboration needs care: `subst` on an equation whose right side is one of these memories
   evaluates it in the elaborator and runs out of heartbeats, so the proofs rewrite with
   `P_iff` and the `pm_*` equations instead.

**The command's clauses, in order.** After the ones it has (`reads`, `writes`, `scalars`,
`pointers`, `map2`, `contract`, `alloca`), and before `loop` and `mat`:

1. `segments`: a flag. The command cuts each block at the positions where `summarizeTo` or
   `summarizeLife` gives a summary (its collectives and lifetime markers) and summarizes it by
   `summarizePieces`, with the `alloca` flag; a block with no such position is summarized as
   now. It adds `n.pieces_<l>` (the segments of block `l`, by `decide +kernel`), and for each
   path the lane lemma in `RunsVia.of_fires`' form (`Piece.through`, then `RunsVia.of_fires`,
   then `RunsVia.of_ends` to the `ret`), its `Piece.fires` premise left as the thread's
   premise, as `RetWith` is now.
2. `shfl i := mo, ofs, cl` (one per shuffle, in order): the mode, lane operand and clamp of the
   `i`-th shuffle, which `Piece.Wait.shflOk` checks against the waits. Without a `barrier`
   clause the command adds `n.sound_of` by `Kernel.sound_of_warps`, the shuffles' premises left
   as premises; when `prog.shflNil` holds (`decide +kernel`), the keeping premise is closed by
   `Program.shfl_nil`.
3. `barrier i := bar` (one per barrier, in order): its number, a numeral below 16. The command
   then adds `n.sound_of` by `Kernel.sound_of_phases`.

The refusals, each with one message:

- a collective call that the clauses do not list, or a listed one at no collective: the message
  names the block, the position and the call, as LLVM text (`refusedText`,
  MojoProof/Sym/Info.lean:58);
- a segment that `summarizePieces` refuses: the message names the first statement it refuses,
  as `refusalAt` (Info.lean:40) does for a whole block;
- `segments` with `map2` or `mat` (their theorems are about whole blocks), or with a `loop`
  clause whose loop has a collective in it (a loop's round is one path of whole blocks);
- `shfl` or `barrier` without `segments`;
- a global in address space 3 (a shared array): `map2` and `mat` refuse it today, and the
  start's shared arrays need their own premises in `WarpSegsBar`, which this plan does not
  give.

**The first two steps, with their cost.**

1. `Kernel.sound_of_warps`, `WarpSegs` and `WarpSegs.run` (MojoProof/Sym/KernelWarps.lean, a new
   module that imports WarpRoute and CanonBar and is imported by nothing in the library), and
   the test MojoProofTest/KernelWarps.lean: `sound40`, the kernel `kern` of
   MojoProofTest/SymCanon.lean sound at one block of 40 threads (a warp of 32 lanes that shuffles
   and one of 8 that skips the shuffle) on the empty memory, from `seg0` and `seg32`, each
   warp's `WarpSegs` by SymCanon's lane lemmas, and a twin whose wait fails
   `Piece.Wait.shflOk`. Two new modules, nothing else rebuilt: 13.4 s, 3.3 GB. Built.
2. `Kernel.sound_of_phases`, `WarpSegsBar` and `WarpSegsBar.wait`, in KernelWarps.lean (it
   imports WarpWaits), with the test MojoProofTest/KernelPhases.lean: SymColl's kernel
   (MojoProofTest/SymColl.lean: a barrier, then two butterfly shuffles) sound at one block of 4
   and of 8 threads on the empty memory, from SymChain's lemmas (`waits` for the runs to the
   barrier, `lane` and `shfls` past it, `checks` for the trace), its blocks at the end the
   start's; the twin, a wait at another barrier word, refused (`bar_other`). SymChain's `bar0`
   is not used: the theorem builds the block's `BlockBar` itself, by `BlockBar.of_waits`. Three
   modules built (KernelWarps and its two tests): 17.6 s, 3.3 GB. Built.

The clauses come after these two: they change MojoProof/Sym/KernelCmd.lean, so every module
that imports it is rebuilt, about 10 minutes (the full build of the `alloca` clause's change
took 10.5 minutes).

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
- `MojoProofTest/KernelWarps.lean`: `Kernel.sound_of_warps` on SymCanon's kernel at one block of
  40 threads, on the empty memory, at address choice and oracle 0 (`sound40`): warp 0's 32 lanes
  shuffle (`seg0`) and warp 32's 8 lanes skip the shuffle (`seg32`). The twin is a lane operand
  of 8 in place of 16, which fails `Piece.Wait.shflOk`.
- `MojoProofTest/KernelPhases.lean`: `Kernel.sound_of_phases` on SymColl's kernel (a barrier,
  then two butterfly shuffles) at one block of 4 and of 8 threads, on the empty memory, at
  address choice and oracle 0 (`sound`; `run`, the run to a done grid by
  `Kernel.run_of_phases`): the phase to the barrier by `WarpSegsBar` (`seg_bar`),
  the phase past it by `WarpSegs` (`seg_end`), the trace's checks by SymChain's `checks` and the
  blocks at the end the start's (`blocks_end`). The twin: no `WarpSegsBar` at a barrier word
  other than 0 (`bar_other`).

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
