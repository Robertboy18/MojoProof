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
| `MojoProof/Sym/Block.lean` | its soundness: `Block.sound`, the pointer facts, paths (`coversPath`, `coversPathI`, `Walk`, `WalkI`), returns |
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
- `extractvalue`;
- `getelementptr` with one index;
- `load` from the entry memory;
- float operators with their flags and the step whose oracle numbers they read
  (`fbin op fm ft n a b`, `n` steps after the block entry);
- `call lbl pc`, the special-register call at position `pc` of block `lbl`.

A value used twice is one node referred to twice, so the table has as many nodes as the block has
value-defining statements, whatever the sharing. A node whose instruction carries a type
(`getelementptr`'s source type, `load`'s type) names its statement by block label and position
and reads the type there. As a result `SNode` holds no `Ty`, whose derived equality the kernel
does not reduce.

`SNode.eval V vs nd` is the value of node `nd` under a valuation `V`, given the values `vs` of the
nodes before it. The valuation holds the context, the function, the step count at the entry, the
entry memory, the entry registers and the `fmul contract` operands. The value is computed by the
semantics' own operations (`intBin`, `icmpV`, `intCast`, `extractV`, `gep`, `Mem.load`,
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

- instructions: `bin`; scalar integer `icmp`; `trunc`, `zext`, `sext`; `extractvalue`;
  `getelementptr` with one index; `load`; `store`; float operators except `fmul contract`
  (`fadd contract` may fuse with its product, which the frame records and the summary of
  `covers` does not model; the checker `coversC` admits it, below); `select` of integers
  (`SNode.select`); calls of a special register (a declaration that `P.intrinsics` names
  `sreg r d`, called with no arguments and no fast-math flags, whose
  attributes `Func.check` accepts); calls of an integer maximum or minimum (`llvm.smax`,
  `llvm.smin`, `llvm.umax`, `llvm.umin`: a declaration that `P.intrinsics` names
  `minmax signed max t`, called with two arguments, no fast-math flags and no parameter, return
  or call-site attributes, whose attributes `Func.check` accepts; `SNode.minmax`);
- operands: registers and integer constants;
- order: `load`, `getelementptr`, `icmp` and special-register calls only before the block's first
  `store`, since their terms read the entry memory, which a store changes;
- terminators: `br`, `br i1` and `ret void`. On an edge into blocks with `phi`s, each `phi`'s
  operand for the edge must be a register or an integer constant, and its obligation is that the
  operand evaluates (`SState.phiConds`).

Everything else makes `summarize` give `none`, so `covers` is `false`:

- other calls (barriers, other intrinsics, module functions);
- `select` of floats, pointers or vectors, float casts and compares, atomics, `alloca`;
- aggregates other than `extractvalue`, and vectors as `getelementptr` indices;
- `phi`s inside the range (a block with `phi`s is summarized from the position after them);
- float constants (the kernel does not reduce `floatLit`), and `ret` of a value.

`coversTo P fn lbl p0 d₀` is `covers` with only the obligations of the edge into block `d₀`, for
a `br i1` into blocks with `phi`s. An operand of the untaken edge that is outside the fragment or
faults then does not refuse the block.

### Paths

A path is a list of entries `(l, ds, S)`: a block's label, its conditions and its summary.

- `coversPath P fn p0 ps` checks the first block from position `p0`, and each later one from
  position 0, with `covers`.
- `coversPathI P fn p0 ps` is the same for edges into blocks with `phi`s. Each later block is
  checked from the position its edge enters at (`Exit.pc`: after the `phi`s), and each block but
  the last by `covers` or by `coversTo` for the edge into the next block.
- `Walk V ps` is a path's premise: each block's conditions hold under its entry valuation and
  table, and each block's exit goes to the next block (`Exit.target`). `WalkI` is the same with
  `Exit.dest`, where a `br i1`'s condition picks the target, and `Valuation.into`, the entry
  valuation after the edge, with the `phi`s set.
- `Walk` and `WalkI` are decidable (`Walk.dec`, `WalkI.dec`), so `decide +kernel` decides them on
  concrete valuations.

## What it proves

Every theorem below is proved once, for every program, function, block, position, conditions
and summary (or path) that the checker accepts. Those about a block or a path are about one
thread's steps, and their premises are that the conditions hold under the thread's entry
valuation (`hds`, `Walk`, `WalkI`). The
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
says a symbolic state describes a frame and a memory. `SState.stmt_sound` shows each statement of
the fragment keeps it, `SState.run_sound` extends that to the statement list, and
`SState.exitAt_sound` covers the terminator.

`Block.sound_ptrs` concludes `Ends` and the pointer facts `Ptrs` as well: the thread's steps
reach the statement of each `load` node and each `store` effect, and there the statement's
pointer operand, evaluated in the thread's scope, is the summary term's pointer value
(`docs/proofs/ptrs.md`). `Block.sound_with` is `Block.sound` for any exit function whose exit is
the terminator's step when its obligations hold. `Block.sound_to` is `Block.sound` for
`coversTo`, when the exit goes to `d₀`.

`coversC` is `covers` with `fmul contract` in the fragment: a float operator's node records the
`fmul contract` operand terms its operands carry (`SNode.fbinP`), and `Block.soundC` concludes
`EndsC`, which is `Ends` with the frame's products at the block's end given by the table
(`regProdIn`: for a register the block sets, the values of its node's operand terms).
`Ends.edgeC` is `Ends.edge` from `EndsC`, entering the next block at `Valuation.intoC`
(`Valuation.into` with the table's products). `Block.sound_pathC` takes a path that `coversPathI`
accepts, then one block that `coversC` accepts. The path checker's inner blocks and the loop
theorems are still stated with `covers` and `Ends` (`docs/proofs/contract.md`).

### Along a path

- `Ends.edge`: from `Ends` at `(V, l, S)` with `Exit.dest = some d`, the exit's step takes the
  thread into a frame of `V.fn` at block `d`'s position `Exit.pc`, with entry valuation
  `V.into l S`.
- `Block.sound_pathI`: `coversPathI` and `WalkI` give `Ends` of the path's last block from its
  entry valuation (`Valuation.lastI`). `Block.sound_path` is its corollary for `coversPath` and
  `Walk`.
- `Block.sound_retR`: for a last block that ends in `ret void`, under any list of caller frames,
  the thread's steps reach the `ret` on the memory the last block's effects make. The next step
  is `.done` without a caller, else a return to the caller at the position after its call; the
  frame's `alloca` blocks are dead either way. `Block.sound_retI` and `Block.sound_ret` are its
  one-frame corollaries.
- `Block.sound_back`: with a caller frame `g`, if `covers` accepts `g`'s block from `g.pc + 1` and
  its conditions hold after the return, the caller's block ends (`Ends`) too
  (`docs/proofs/back.md`).
- `Block.sound_pathMem` (`MojoProof/Sym/PtrMem.lean`): along a path that `coversPathI` and
  `pathOk` accept, `Labels.MemNext` at every state the thread's steps reach gives the memory
  premises `Valuation.PathMem` of the two-run theorem. `Labels.MemOk.steps` gives `Labels.MemNext`
  at every state that a running thread's steps reach, in every grid reachable from a grid that
  meets `Labels.MemOk`.

### To the kernel theorem

`Runs.of_ret` (`MojoProof/Sym/Kernel.lean`) turns a path that `coversPathI` accepts and that is a
`Ret` to `Q` (its premises hold, its last block returns, its effects run to a memory of `Q`) into
the thread's run to its end (`Runs`). `Kernel.sound_of_paths` takes a list of paths that
`coversEntry` accepts (each from the kernel's first block) and an invariant on the memory, indexed
by the number of threads done. Each thread must take one of the paths as a `Ret` from the
invariant at `k` threads to the invariant at `k + 1`. From these and the premises it states, it
concludes `Kernel.Sound` for every launch, arguments, memory, admission and observation.
`Kernel.sound_of_chains` is the same with, for each thread, a path or a sequence of loops
(`RetLs`, through `Runs.of_chains`), and `Kernel.sound_of_paths` is its case without loops.
`mojo_kernel` enumerates a kernel's paths, and with one `loop` clause per loop its sequence of
loops, and generates these theorems (`docs/kernel.md`).

## Loops: what is automated and what is not

A loop is a path `(h, ds, S) :: B` from its header `h`, entered at position `p` (after its
`phi`s), through the body to the latch, whose exit goes back to `h`. `Valuation.round` is the
header's valuation after one round. `Round` is the decidable premise of one round: the loop path's
`WalkI`, and its last exit goes to `h` at position `p`. The theorems (`MojoProof/Sym/Loop.lean`)
are proved once, for every program, function, path, list of loops, nesting, trip count and
invariant.

- `Block.sound_loop`: if `Round` holds at the `i`-th round's valuation for every `i < n`, the
  thread's steps reach `h`'s position `p` again, with the `n`-th round's valuation.
- `Round.of_inv` and `Block.sound_loop_inv`: the same from an invariant `I i` indexed by the round
  number, from `I 0` and the fact that `I i` gives `Round` and `I (i + 1)` after the round.
- `Runs.of_loop`: a thread with one frame through an entry path, a loop and an exit path to a
  `ret` runs to its end (`Runs`), from `RetL`. `RetL` says: the entry path goes to the header, an
  invariant holds at round 0 and is preserved, and at the trip count it gives `Ret` of the exit
  path.
- `Runs.of_chain`: the same through a list of loops in sequence, each of whose rounds may run
  nested loops (`LoopSeg`), from the inductive premise `Chain`.
- `Runs.of_loops`, `Runs.of_chains`: the same for the threads `Grid.start` makes, with the paths
  checked by the closed Booleans `coversLoops` and `coversChains`.

What is automated:

- the checks of every path of the loops (`coversChain`, `coversChains`, `coversLoops`): closed
  Booleans that the kernel evaluates;
- on a concrete valuation and trip count, the premises of the rounds: `Chain.of_rounds` (a loop
  with no nested loop) and `Chain.of_iter` (a loop given by a round function) turn them into
  closed propositions that `decide +kernel` decides;
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
  without a clause, naming the header. The one kernel theorem through a loop is for the counting
  loop on one thread at one launch (`kernelK`, MojoProofTest/KernelLoop.lean); no kernel of the
  library is proved that way.
- Loops outside the fragment. The naive matmul kernel's latch `%52` is refused at the
  `fmul contract` (statement 12) whose product the `fadd contract` at statement 13 reads
  (`naive_latch_refusal`); its integer `select` (statement 2) is in the fragment. `coversC`
  accepts the latch as one block (`latch_covers`, MojoProofTest/SymContract.lean), but the loop
  theorems do not take `coversC`. Of the kernel's nine blocks, `covers` accepts all but the latch
  and the preheader `%45`, whose `br` passes the float constant `0.0` to the `phi` `%48`
  (`naive_refusals`, MojoProofTest/SymNaive.lean); `coversC` accepts all but `%45`.

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
5. For a path, list its entries, check them with `coversPathI` by `decide +kernel`, and apply
   `Block.sound_pathI` or `Block.sound_retI` with `WalkI` (`vadd_paths` and `vadd_ret` in
   `MojoProofTest/Sym.lean`).
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
  context of the kernel and thread with one frame at `%4` whose path premises (`Walk`) hold.
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
- where an operand is a global (`Value.glob name`).

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
