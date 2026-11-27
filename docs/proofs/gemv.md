# The gemv kernels in the block checker: what each block needs (a plan)

Lean: proved, for every program, the lane number in the block checker (`exec_laneid`,
MojoProof/Sym/Exec.lean; the node `SNode.call`, MojoProof/Sym/Term.lean; the case of
`SState.stmt`, MojoProof/Sym/Checker.lean), the casts `castV` evaluates (`castOk`, which is
`castV`'s cases by `castOk_iff`, MojoProof/Sym/Exec.lean; the node `SNode.castAt` and its value
`SNode.eval_castAt`, MojoProof/Sym/Term.lean; the step `exec_cast` in `SState.stmt_sound`), and
the value of a `bitcast` between scalar types of the same width (`SNode.eval_bitcast`, by
`bitcast_bits`). Instances and twins at the two kernels: MojoProofTest/SymLane.lean
(`call_laneid`, `gevm_lane`, `gevm_entry`, `gemv_entry`, `loops_contract`, `reductions_refused`)
and MojoProofTest/SymCast.lean (`gemv_shfl`, `gemv_bitcast`; `bf16_fpext` and `bf16_blocks` at
the bfloat16 naive matrix product), and the refusals of `fptosi`, `fptoui` and `inttoptr`
(`casts_refused`, MojoProofTest/SymCastOk.lean). Proved too, for every program, the summary of
a segment of a block that ends at a barrier or a warp shuffle (`summarizeTo` and `Seg.sound`,
MojoProof/Sym/Segment.lean), with the segments of both warp reductions as tests
(MojoProofTest/SymSeg.lean, item 3), and the pointer of a global named at a statement's
operand (`SNode.globalAt` and its value `SNode.eval_globalAt`, MojoProof/Sym/Term.lean, item 5),
and the checker's steps for `insertvalue`, `extractelement`, `insertelement` and a
`getelementptr` with two indices (`exec_insertvalue`, `exec_extractelement`,
`exec_insertelement`, `exec_gep`, MojoProof/Sym/Exec.lean, item 6), with `gemv_kernel`'s entry
block from statement 3 as a test (`gemv_segs`), and a block's `alloca`s with the checker's
`alloca` flag (`SNode.fresh`, `SEff.alloca`, `exec_alloca`, `Block.soundAt`, item 6), with
hand-built kernels and the run of `gemv_kernel`'s three `alloca`s as tests
(MojoProofTest/SymAlloca.lean). Everything after the section "What the checker
takes" is a plan, not a proof, but for items 1 to 3, item 5's node and item 6's done parts:
the constructs each block of the two kernels uses that the checker refuses, the summaries that
would take them, and the order of the work. The runs proved: `gevm_kernel`'s thread from its
entry to `ret` at every launch with 1024 threads a block, for every `K` and `N` with `K % 32 = 0`
and `K * N < 2 ^ 29` (`whole`, MojoProofTest/OblGevmWhole.lean), and `gemv_kernel`'s warps from
`Grid.start` to a done grid at three launches with `K = 0` and two with one round of the loop,
`K = 4` and `K = 3`, whose output cell holds `warpDot`'s word (item 6,
MojoProofTest/GemvWarp.lean). And at every valid one-dimensional launch whose block's `x` size
32 divides, from every start (its result a premise) at an address choice below `2 ^ 60`, with
`M`, `K < 2 ^ 31`, `M K < 2 ^ 61` and a caller's memory with no block from `next` on whose
buffers hold the matrix and the vector: the warps' canonical run to a memory where each warp
whose row is below `M` has its row word (`grid_run`), and a done grid with it (`grid_done`);
when moreover the warps' rows cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), a
done grid whose every output row is its row's `warpDot` word up to NaNs (`grid_rows`), and,
with the caller's bytes known (`m.BytesIn m.Known`), the grid's soundness (`grid_sound`). Under
the same launch, size and row-coverage premises, for every caller's memory closed for the
arguments (`Mem.Closed`) with those buffers and every input words that hold the matrix and the
vector, gemv_kernel's `GPUProof.Kernel.Sound` at the admission "address choice below `2 ^ 60`",
against the rule of `GPUProof.Spec.matVec` and TorchLean's contraction (`kernel_sound`,
`gemv_torchLean`, item 7 of the order of the work), with every premise proved at one block of
64 threads, `M = 2`, `K = 4` (`sound64`, `torch64`). And `gevm_kernel`'s blocks in turn at every
valid one-dimensional launch with 1024 threads a block and `N ≤ 32 · L.grid .x`, from threads
and a memory with the entry's premises and the buffers, to a memory whose every output column is
its column's `warpDot` word up to NaNs, and, at `N = 32 · L.grid .x`, from a start with the
arguments and the caller's buffers a done grid with it whose trace's accesses are known at their
phases (`blocks`, `grid`, MojoProofTest/GevmWarp1.lean, item 7 (c)), so not bad (`grid_bad`);
then gevm_kernel's `GPUProof.Kernel.Sound` at the admission "every block of threads' shared
array below `2 ^ 32`", against the rule of `GPUProof.Spec.vecMat` and TorchLean's contraction
(`kernel_sound`, `gevm_torchLean`, MojoProofTest/GevmSound.lean, item 7 (d)), with every premise
proved at one block of 1024 threads, `N = K = 32` (`sound1024`, `torch1024`).

## The kernels

tests/corpus/gemv/gemv_f32.mojo launches the two float32 kernels of max/kernels/src/linalg/gemv.mojo
with blocks of 1024 threads (32 warps). The line numbers below are those of the two IR files in
tests/corpus/gemv/.

`gemv_kernel` (gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll), arguments
`%0` (the output `c`), `%1` (the matrix `a`, `M × K`), `%2` (the vector `b`), `%3 = M`, `%4 = N`,
`%5 = K`, grid `⌈M / 32⌉`. One warp computes one row:

- block `%6` (lines 8-56): the row `%20 = (ctaid.x · ntid.x + tid.x) / 32`; lane 0's row is sent
  to the warp by two `shfl.sync.idx` with source lane 0 (lines 22-26: the row as `<2 x i32>`, one
  shuffle per half); each half goes through a stack slot (`alloca`, `store`, `lifetime.*`, lines
  8-10 and 27-48: the two halves' slots, a `[2 x ptr]` of their addresses, loads back through
  it); `%36` (line 49) is the row again, now lane 0's; the output cell `%37 = c + %36` (line 50),
  the row's offset `%38 = %36 · K`, the lane `%40` (lines 52-53), the test `%41 = (%40 = 0)`, and
  the guard `%36 ≥ M` (line 55), which returns;
- the loop `%44` to `%77` (lines 61-109): `⌈K / 32⌉` rounds; round `i` adds
  `a[%38 + 32 i + l] · b[32 i + l]` (`fmul contract`, `fadd contract`, lines 98-101, loads with
  `!invariant.load`) to lane `l`'s sum when `32 i + l < K` (line 94);
- block `%78` (lines 111-133): five butterfly rounds (`bitcast float` to `i32`, `shfl.sync.bfly`
  with offsets 16, 8, 4, 2, 1, `bitcast` back, `fadd contract`); lane 0 stores the result to `%37`
  (line 136).

`gevm_kernel` (gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll), the same
arguments (`a` the vector of `K`, `b` the matrix `K × N`), grid `⌈N / 32⌉`, a shared array of 1024
floats (line 6). Thread `(w, l)` (warp `%11 = tid.x / 32`, lane `%13`) of block `β`:

- block `%6` (lines 10-42): the column `%17 = 32 β + l`, the output cell `%29 = c + ⌊(β ·
  ntid.x + tid.x) / 32⌋`, the trip count `%38 = ⌈K / 32⌉`;
- the loop `%39` to `%58` (lines 44-70): round `i` adds `a[32 i + w] · b[(32 i + w) · N + %17]`
  to the thread's sum, with no guard on `32 i + w < K` or on `%17 < N`;
- block `%59` (lines 72-112): the thread stores its sum to the shared cell `32 l + w` (lines
  74-78), the block meets at the barrier (line 79), the thread loads the shared cell `tid.x =
  32 w + l` (lines 80-82), which holds the sum of thread `(l, w)` (column `32 β + w`, rows
  `≡ l` mod 32), the warp runs the same five butterfly rounds (lines 83-102), and lane 0 stores
  the column's total to `%29` (line 115).

## What the checker takes

`#mojo_info` on both files (its `summarize` is the checker without `fmul contract`), with the
lane number and the casts in the fragment:

| block | statements | verdict |
|---|---|---|
| `gemv_kernel` `%6` | 48 | refused at statement 0, `alloca [2 x ptr]` (`gemv_entry`); with the `alloca` flag, statements 0 to 16 run (`gemv_allocas`) and the `getelementptr` at 30 is refused (`gemv_allocas_twin`); from statement 3, as eleven segments ending at the shuffles and the lifetime markers (items 3 and 6): all in the fragment (`gemv_segs`) |
| `gemv_kernel` `%43`, `%44`, `%54`, `%58`, `%59`, `%60`, `%75`, `%76`, `%100` to `%103` | | in the fragment |
| `gemv_kernel` `%70` | 4 | `fmul contract`: in the fragment of `coversC` (`loops_contract`) |
| `gemv_kernel` `%78` | 21 | whole: refused at statement 2, the first `shfl.sync.bfly` (`reductions_refused`, `gemv_shfl`); as six segments ending at the shuffles (item 3): all in the fragment (`gemv_segments`) |
| `gevm_kernel` `%6` | 32 | in the fragment, the lane number at statement 5 (`gevm_entry`) |
| `gevm_kernel` `%39`, `%43`, `%44`, `%97` to `%99` | | in the fragment |
| `gevm_kernel` `%45` | 13 | `fmul contract`: in the fragment of `coversC` (`loops_contract`) |
| `gevm_kernel` `%59` | 39 | whole: refused at statement 6, the barrier (`reductions_refused`); as seven segments ending at the barrier and the shuffles (item 3): all in the fragment, the first two with the shared global's pointer (item 5, `gevm_segments`, `gevm_after_barrier`) |

So both loops, every segment of the reductions and every block after them are in the fragment;
what is left is `gemv_kernel`'s entry block's three `alloca`s in its paths (the block checker
and the segments take them, item 6) and the schedule through the reductions' collectives (item 4).

## The constructs, and the summaries that would take them

1. **The lane number** (done). `llvm.nvvm.read.ptx.sreg.laneid`, with no arguments and no
   fast-math flags, before or after a store: the node `SNode.call lbl pc`, whose value is
   the context's `laneid` under the declaration's return attributes (`withAttrs`), the step
   `exec_laneid`. `gevm_kernel`'s `%6` (line 15) and `gemv_kernel`'s `%6` (line 52).
2. **Casts of the same size** (`bitcast float` ↔ `i32`, `gemv_kernel`'s lines 113-131 and
   `gevm_kernel`'s lines 83-101; `bitcast i64` ↔ `<2 x i32>`, `gemv_kernel`'s lines 22 and 49).
   Done: the node `SNode.castAt lbl pc n a` names its statement, as `getelementptr` and `load`
   nodes do (so that `SNode` holds no `Ty`, whose derived equality the kernel does not reduce); its
   value is `castV` at that statement's operator and types and the oracle of step `n`
   (`SNode.eval_castAt`), so every cast `castV` evaluates is covered, not only `bitcast`; the step
   is `exec_cast`. The checker takes a cast only at the operator and types that `castOk` admits,
   and `castOk` is false exactly where `castV` faults with its unsupported-cast message on every
   operand (`castOk_iff`, for every layout, memory and choice), so `fptoui`, `fptosi`, `inttoptr`
   and an ill-typed cast are refused (`casts_refused`, with `#mojo_info`'s line pinned, and its
   twin `sitofp_taken`, MojoProofTest/SymCastOk.lean); no file of tests/corpus/ uses the three.
   `ptrtoint`, which reads the addresses, is taken after a store too, since a store keeps every
   block's address and size (`SEff.run_shape`). Done
   too: a scalar `bitcast` between types of the same width keeps a word (`.bits w x`:
   `bitcast_bits` for every layout, `SNode.eval_bitcast` for every node; at `%78`'s statements 1
   and 3, `gemv_bitcast`). Done in Sem: the evaluation lemma for the vectors, that `bitcast i64`
   to `<2 x i32>` gives its two halves, low first, and back (`castV_split`, `castV_join` and
   `castV_halves`, MojoProof/Sem/Eval.lean, for every layout; test MojoProofTest/Bitcast.lean
   `halves57`).
3. **Collective calls as the end of a segment** (`gemv_kernel`'s `shfl.sync` calls at lines 25-26
   and 114-130; `gevm_kernel`'s barrier at line 79 and shuffles at lines 84-100). A thread's step at
   a collective is `.wait i args fn`, and the grid resumes it with a value (`Thread.resume`: the
   call's register, `pc + 1`, `k + 1`). Done, in MojoProof/Sym/Segment.lean: `summarizeTo P fn
   lbl p0 p1` is the summary (`SegSummary`, a new structure, so `Exit` and `Summary` keep their
   constructors) of the statements `p0` to `p1 - 1`, by the checker's statement case, with, as
   its end, the collective call at `p1` (`SState.waitAt`: the barrier or a warp shuffle, `Coll`,
   called with no flags or attributes) and its arguments as terms. Its theorem `Seg.sound`, for
   every program: from a valuation meeting the summary's obligations (among them that each
   argument term evaluates), the thread's steps run the segment and its step at `p1` is the
   `.wait` of the collective on the arguments' values (`Waits`). The resumed thread is at
   `p1 + 1` with the same function, block, `alloca` blocks and caller's register
   (`Thread.resume_at`), where the next segment starts: `summarizeTo` again, or, after the last
   collective, the existing `summarize P fn lbl (p1 + 1)` and `Block.sound`, which start
   inside a block. Tests (MojoProofTest/SymSeg.lean): `gemv_kernel`'s `%78` is six segments, the
   five to its shuffles and the one from statement 19 to the branch, with their shapes pinned
   (`gemv_segments`); `gevm_kernel`'s `%59` is seven segments, to the barrier at 6, to the
   shuffles at 11, 15, 19, 23 and 27 and from statement 28 to the branch, all in the fragment
   with item 5 (`gevm_segments`); `gemv_first_wait` runs the first segment of `%78` on a thread to
   its wait and its resume at statement 3, and `gevm_after_barrier_wait` the segment of `%59`
   after the barrier to its wait at 11 and its resume at 12, each one line of `Seg.resume` (for
   every program: from the summary's collective and length, the steps to the `.wait` and the
   resumed frame at `p1 + 1`, by `Seg.sound` and `Thread.resume_at`). The resumed frame has at
   every register but the call's result the summary's value (`Seg.resume_regs`, for every
   program, by `Thread.resume_regs`); at `gevm_kernel`'s barrier, which has no result, every
   register (`gevm_barrier_regs`). `gemv_kernel`'s `%6` from statement 3 is eleven segments, to
   its two shuffles and its lifetime markers, and the summary to its branch (`gemv_segs`,
   item 6).

   **A block's segments on one thread**, done in MojoProof/Sym/Segment.lean. `summarizeSegs P fn
   lbl p0 ps` folds `summarizeTo` over the positions `ps` of the block's collective calls, each
   segment starting after the previous call, and ends with `summarize` after the last call: the
   list of segment summaries and the summary of the rest. `Seg.Through` is the run of that list on
   one thread, with the collectives' values as parameters: `w i` is the value the `i`-th call
   delivers and the memory the thread resumes on (the schedule, item 4, supplies them). If a
   segment's obligations hold at the entry valuation of its start frame, the thread reaches the
   call's wait with the facts of `Waits`, and the thread resumed with `w i` (`Thread.resume`) runs
   the rest of the list; after the last call, if the rest's obligations hold, the block ends
   (`Ends`). `Seg.through`, for every program, is the fold of `Seg.sound`, `Thread.resume_at` and,
   at the end, `Block.sound`: when `summarizeSegs` gives the summaries, `Seg.Through` holds for
   every thread at `p0` and every `w`. Each segment's obligations stay a premise at its own start
   frame, whose registers the earlier segments set (`Waits`). The test `gevm_through`
   (MojoProofTest/SymSeg.lean) runs `%59` from statement 1 with its collectives at 6, 11, 15, 19,
   23 and 27, at symbolic values: 5, 4, 3, 3, 3 and 3 statements before the calls, then 11 to
   the conditional branch. The obligations stay premises there; discharging them is left to the
   specification (item 7).
4. **A schedule through the collectives.** `Seq` (MojoProof/Sym/Sched.lean) runs threads in turn,
   each to its end, with no collective. The kernel theorem needs one completed run
   (`Grid.start_sound`), so a schedule is enough: for each block, every thread runs to the
   barrier, the barrier fires; then for each warp, its lanes run in turn to the next `shfl.sync`
   and it fires (`Grid.fire`: lane `j` receives the operand of lane `shflSource mode j b c`), five
   times for `gemv_kernel`'s `%78` (two for its `%6`); then the lanes run to their end. This is
   the phase structure of the evaluator `Grid.run` (`Grid.runAll`, then `Grid.fireAll`, both
   reachable by `Grid.Step`: `Grid.runAll_reach`, `Grid.fireAll_reach`). Done for every program
   (docs/proofs/canon.md): the warps in turn, each lane in turn to its next shuffle and then the
   warp's fire (`WarpRun`, `WarpShfl`, MojoProof/Sym/Canon.lean), the blocks in turn through
   their barriers (`PhaseRun`, `BlockRun`, `BlockBar`, MojoProof/Sym/CanonBar.lean),
   `PhaseRun.start_sound` and `bflyRoundsAt_of_shfl`. gemv_kernel's run from its segments is done
   at every one-dimensional launch (`grid_run`, by `WarpRun.of_waits` and `CanonRun.of_inv`, "The
   order of the work", item 6); so is gevm_kernel's, at every one-dimensional launch with 1024
   threads a block and `N = 32 · L.grid .x` (`GevmWarp1.grid`, item 7 (c) there). The values from
   `shflSource`: lane 0 for `idx` with lane operand 0 and clamp 31, `l ^^^ m` for `bfly`
   (`shflSource_bfly`, MojoProof/Sem/Bfly.lean). The five rounds' values are then `bflyRounds` of
   the lanes' sums, whose tree, depth and error bound are proved (`eval_bflyTree`,
   `bfly_warp_error`).
5. **A global as an operand** (`gevm_kernel`'s `%64` and `%66`, lines 77 and 81: `getelementptr`
   on the shared array). Done, in MojoProof/Sym/Term.lean: the context gives each block's globals
   (`Ctx.globals`, set by `Grid.start` per block), and `SNode.globalAt lbl pc i` is the pointer of
   the global named at operand `i` of the statement at position `pc` of block `lbl`, naming the
   statement, not the string; its evaluation lemma `SNode.eval_globalAt`, for every valuation,
   says it is the context's address of the global. The checker's `getelementptr` on a global is
   two nodes, the global's pointer and the `getelementptr` on it (`SState.stmt`), with
   `SState.stmt_sound`'s case for it; a `load` or `store` whose pointer operand is the global
   itself is the global's node at that operand (0 for a `load`, 1 for a `store`), then the `load`
   or `store` on it, with their cases of `SState.stmt_sound` (the layernorm kernels' `store` and
   `load` of their shared array: `ln_store`, `ln_store_ends`, `ln_load`). The node is skeleton
   (`SNode.pay`): the two-run theorems take one table of globals (`hg` of `vals_skel` and
   `Summary.oblivious_skel`; `Valuation.Rel` has it), so the oblivious check `Summary.oblivious`
   takes a summary with one (`ln_store_oblivious`).
   The loads after the barrier start a new segment (item 3), so they are before that segment's
   first store. Tests (MojoProofTest/SymSeg.lean): `gevm_after_barrier` pins the table of the
   segment after the barrier, and `gevm_shared` evaluates the global's nodes at statements 4 and
   8. Race freedom across the barrier is `racy_tpose` (docs/proofs/warp-dot.md, "The
   transposition through shared memory"), `racy_eq_false_of_phased` at the tiling
   `Tiling.tpose 32 4 β`: before the barrier thread `(w, l)` owns shared cell
   `32 l + w = tpose 32 (32 w + l)` (`Launch.tpose_env`, the instance at 32 warps of
   `Launch.warps_env`), after it thread `t` reads cell `t`. On a
   run the pattern, for every cell map injective on a block of threads, is `Grid.sound_cells`
   (docs/proofs/barrier-owned.md, "On a run"), with the instance `sound1024` at `tpose 32` on
   every valid launch with `ntid.x = 1024`, of `sound_tpose` (every valid launch and cell width;
   MojoProofTest/Transpose.lean). The kernel's two rounds meet `Grid.sound_rounds` with the loop's
   reads, the start's arrival at `%59` and the last memory's owners as premises (`gevm_sound`,
   MojoProofTest/GevmTrace.lean; docs/proofs/barrier-owned.md, "A whole trace of rounds").
6. **The stack round trip** (`gemv_kernel`'s `%6`, lines 8-10 and 27-48), the largest item:
   - `alloca`: done in the block checker, for every program, with its `alloca` flag
     (`SState.alloca`; `summarizeAt true`, `coversAt true`): the node `SNode.fresh` for the new
     block's pointer and the effect `SEff.alloca` that makes the block, whose run is the
     obligation that its number is fresh (`Mem.fresh` of the thread at the statement's step
     count; MojoProof/Sym/Term.lean), the step `exec_alloca` (MojoProof/Sym/Exec.lean), and the
     block's end `EndsAt true`, with the frame's `allocas` the summary's blocks (`SEff.blocks`)
     followed by the entry's (`Block.soundAt`, `Block.sound_alloca`, MojoProof/Sym/Block.lean;
     `Block.sound` is its instance with the flag off). Tests (MojoProofTest/SymAlloca.lean):
     kernels of one to three `alloca`s (`allocs_sound`, `two_sound`), the twins without the flag
     and at a used number (`allocs_twin`, `alloc_used`), and `gemv_kernel`'s `%6`, whose three
     `alloca`s and the statements to the shuffle at 17 run with three effects (`gemv_allocas`).
     After an `alloca`, `getelementptr`, `icmp` and `ptrtoint` have nodes on the memory the
     effects before them make (`SNode.gepAfter`, `SNode.gepNAfter`, `SNode.icmpAfter`,
     `SNode.castAfter`; MojoProof/Sym/Term.lean), as the entry memory has no block where the
     `alloca` made one; test `readK` (`reads_covers`, `reads_sound`, and the mutant with the
     entry memory's node, `reads_mutant`). The segments take the flag too (`summarizeTo`,
     `summarizeLife` and `summarizePieces` with `alloca` set; `Seg.sound`, `Seg.life` and
     `Piece.through` for every program, the frame's `allocas` the segment's blocks followed by
     the entry's): `gemv_segs_alloca` (MojoProofTest/SymSeg.lean) summarizes `%6` from
     statement 0 to its branch, the first segment, to the shuffle at 17, with the three
     `alloca`s' effects; its mutants `gemv_segs_alloca_mutant`. The paths and the loops take
     the flag too (`coversPathAt`, `Runs.of_retAt`, MojoProof/Sym/Path.lean and
     MojoProof/Sym/Loop.lean; `coversChainsAt`, `Runs.of_chainsAt`, MojoProof/Sym/Loop.lean):
     `tail_covers` (MojoProofTest/SymGemvTail.lean) takes `%6` from statement 41, after its last
     marker, through `%43` to `%103`'s `ret` with the flag. The two-block alloca path of
     MojoProofTest/SymAlloca.lean (`pathText`, parsed and checked, no id defined twice) is
     accepted with the flag (`path_covers`), meets `WalkWith` and `RetWith` at one launch of one
     thread (`path_walk`, `path_retWith`) and runs to its end with both `alloca` blocks dead
     (`path_dead`), as the interpreter's steps do (`path_steps`); on a memory that already has
     the first block's number, the premises fail (`path_used`). The loop at `%54` with both
     flags: a round through either arm of `%60` is accepted (`loop_rounds`), and so is the chain
     of two loops at one header, the `%70` rounds then the `%75` rounds, the order gemv's rounds
     take (`loop_arms`, with the path out cut after `%59`); with its path out through `%78` the
     chain is refused (`loop_refused`), because `%78`'s five shuffles are collectives the block
     checker does not summarize. A chain whose last path out stops after its last edge, into a
     block at a position, takes the thread to the frame there (`ChainWith.enter`, by
     `ChainWith.reach` and `BackWith.enter`, MojoProof/Sym/Loop.lean; `BackWith.enter` is a
     path's run through its last edge, and each of `Block.sound_loop`'s rounds), and a
     continuation from that frame joins it (`RunsVia.of_chain`, MojoProof/Sym/OblSeg.lean). The
     run from
     statement 0: `Piece.ThroughTo` (MojoProof/Sym/Segment.lean) is the segments' run continued
     at the frame after the last one into any continuation (`Piece.Through` is its instance
     that ends at the block's end, `EndsAt`), `Piece.throughTo` proves it for every program,
     and `RunsVia.of_fires` (MojoProof/Sym/OblSeg.lean) takes the segments' premises from the
     Boolean `Piece.fires`. One walk (`Piece.walk`) gives the check, the waits (`Piece.waits`)
     and the valuation after the last segment (`Piece.after`), each a function of the
     deliveries; each wait's predicate (`Piece.Wait.via`) states its call's instruction,
     intrinsic, argument values and memory, and the waits after the block's are a function of
     the valuation after it. For this `fill` (MojoProof/Sem/Eval.lean) is by structural
     recursion: the kernel did not unfold the well-founded one at `[2 x ptr] undef`. On the
     `%44` branch (MojoProofTest/SymGemvTail.lean): the segment checker summarizes `%78` from
     position 1 at its five `shfl.sync.bfly`s, and the path checker with both flags takes the
     path after the last one through `%100`'s `store` to `ret` (`bfly_covers`).
     The warps from `Grid.start` (MojoProofTest/GemvWarp.lean), with the output, matrix and vector
     at blocks 3, 1 and 2 (`memAB`), the row count `M` and the column count `K`. Each thread
     computes its own row `%20 = (ctaid.x · ntid.x + tid.x) / 32` (lines 13-21), but the guard and
     the rest of the lane read `%36`, the row of the warp's lane 0, which `%6`'s two `shfl.sync.idx`
     broadcast (`%24`, `%25`, lines 25-26; PTX ISA 9.5, section 9.7.10.6, mode `.idx`); a warp's row
     is this one. The two rows are equal when 32 divides the block size, and at the five launches
     below (blocks of 32, 64, 16, 32 and 32 threads) every lane's own row is its lane 0's. Otherwise
     they can differ: at 2 blocks of 48 threads and `M = 2`, thread 64 computes row 2, but its warp
     starts at thread 48 (row 1), so it takes `%44`. A lane whose warp's row is below `M` runs from
     the start's thread (`Grid.start_thread`) through `%6`'s segments to statement 41
     (`Piece.throughTo`), the chain through `%44` and `n` rounds of the loop through one arm
     (`ChainWith.of_rounds` of `lp a`: through `%70` if `a`, else `%75`), stopped after `%59`'s edge
     into `%78` (`RunsVia.of_chain`), `%78`'s segments through its five shuffles and the path to
     `ret` (`Runs.of_retMem`), joined by `RunsVia.of_fires` (`tail78`, `lane`); a lane whose warp's
     row is at least `M` runs through `%6`'s two shuffles and `%43` to `ret` (`lane43`). These are
     for every launch whose start succeeds, every arm and round count, and every deliveries and
     memory at which the kernel's `Piece.fires` passes. A warp's lanes in turn are one
     `WarpRun.of_waits`: seven phases, `%6`'s two `shfl.sync.idx` and `%78`'s five `shfl.sync.bfly`
     (`warp78`), or `%6`'s two (`warp43`). Lane `j` takes `⌈K / 32⌉` rounds (`rounds`), through
     `%70` if `j < K` and through `%75` if not (`arm`), which is its path when `K ≤ 32` or `32 ∣ K`
     (otherwise the lanes `j ≥ K % 32` take `%75` at the last round only). Each lane's waits are at
     its call's arguments and memory, and each delivery is `Grid.fire`'s from the values the lanes
     offer, each lane its own (`Warp.v`, by phase and lane; `WarpShfl`, by `shflVal` at
     `shflSource`), not an input; at the launches below they are `offer`: the lane's row at `%6`'s
     shuffles, and at `%78`'s its value after the butterfly rounds before, from its loop `dotLoop`
     over its strided pairs. The kernel decides each lane's premises (`ok78`, `ok43`: `Piece.fires`
     and the waits' calls, positions, arguments and deliveries) and evaluates its wait memories
     (`mems78`, `mems43`), each from the lanes before it. Lane `j`'s first wait in `%78` is at the
     memory after the lanes before it and its own run there (`m2 (j + 1)`, through `%6`'s lifetime
     markers), and its other four at the memory where the first fires (`Bm`). From the start to a
     done grid (`CanonRun.start_done`): at `K = 0`, the loop with no round, one block of 32 threads
     at `M = 1` (`run32`) and one block of 64 at `M = 1` (`run64`: warp 0 by `warp78`, warp 32 by
     `warp43`), the output's cell 0 holding `0.0`; at `K = 4`, one block of 32 at `M = 1` with the
     row `[2 ^ 24, 1, -2 ^ 24, 1]` and the vector of ones (`run4`): lanes 0 to 3 take one round
     through `%70`, the others one through `%75`, and the output's cell 0 holds the word of
     `warpDot` of the four pairs, `2`, not that of the left-to-right `dotLoop`, `1` (`orders`), as
     `2 ^ 24 + 1` rounds to `2 ^ 24`; at `K = 3`, the row's first three words (`run3`), `1` and not
     `0`. `run32`, `run4`, `run3` and `poison16` are each `one78` (one warp by `warp78`, then
     `CanonRun.start_done`) at its launch, the kernel deciding its premises. The mutant at one block
     of 16 threads (`poison16`): the mask stays full, so every shuffle fires, but the first `bfly`'s
     offset 16 reads lanes outside the warp, so every lane is delivered `poison` there, and the
     output's cell 0 holds `poison`. Refused (`refused`): lane 0 on the `%43` branch at row 0 < `M`,
     on the `%44` branch at `M = 0`, with `%6`'s deliveries on the start's memory, which lacks the
     lane's `alloca` blocks, and with four deliveries for `%78`'s five shuffles (twins `twins`).
     The choice and the cost (`lake env lean` on one core): the lanes are 32 concrete evaluations,
     one per lane at its own context `c (k + j)`, not one valuation with a symbolic lane index, as
     `%6` reads `%tid.x` and `%laneid` and a free index leaves its branch and shuffle operands
     undecided. The module's statements up to the warps take about 17 s and 3.4 GB over its imports
     (10 s); one lane's `Piece.fires` through `%6` and `%78` about 1.5 s, and its `ok78` about 14 s,
     as it evaluates `Bm`, the memory after every lane's `%6`; in one run of the module, `run32`
     51 s, `run64` 1 min 31 s, `run4` 1 min 17 s and `poison16` 24 s (alone, `run4` took 1 min 3 s
     and 12.2 GB); `lake build` of the module 6 min 5 s and 14.7 GB (3 min 1 s and 13.1 GB without
     `run4` and `run3`). Two blocks of 64 at `M = 2` (four warps) took 3 min 8 s and 24.1 GB as one
     declaration, and 7 min 36 s and 15.5 GB with each warp its own declaration (each re-evaluates
     the memories of the warps before it), so the second launch is one block of 64. The kernel's
     caches are per declaration, so the memory grows with the warps of one declaration. A warp's end
     memory carried as a term, a `def` per warp that the next warp starts from, does not stop the
     re-evaluation: at two blocks of 64 at `M = 2` (`lake env lean`, one declaration each, 3 min
     30 s and 12.3 GB in all), evaluating warp 0's end memory (`m7` at its 32 lanes) took 23 s and
     warp 32's, from it, 50 s; warp 0's 32 `ok78` from the start's memory 49 s, warp 32's from warp
     0's end memory 81 s. The kernel unfolds the `def` in each declaration. A memory has function
     fields (`Mem.blocks`, `Block.bytes`), so its value is no closed literal either: a term the
     kernel need not re-evaluate is a `Mem.run` of a list of `Mem.Op`s proved equal to the end
     memory once, which the walk does not output, or the frame lemma (`step_agree` at `Mem.Agree`,
     MojoProof/Sem/Frame.lean) stated for a warp's run, so that each warp is checked from the
     start's memory, which the warps before it change only at their own `alloca` blocks, output
     cells and trace. Both help only at concrete launches. So the next step chosen is the symbolic
     lane index, with the facts of the branch and the shuffles' operands that a free index leaves
     undecided as premises: the route to every launch, which the rounds at every `K` need too
     (below). A probe of it (a scratch file through `lake env lean`, 8.7 s and 4.0 GB in all)
     stopped before any evaluation. The goal was lane `j` of `x32`'s warp through `%6`
     (`Piece.fires … (V0 x32 j (m0 w32 j))`) at a free `j < 32`, with the row
     `(0 + j) / 32 = 0` and `%6`'s deliveries as premises:
     - `decide` and `decide +kernel` refuse it: "Expected type must not contain free variables".
       `+revert` would enumerate the 32 lanes, which is the concrete route again, and a delivery
       premise, an equation of memories, is not decidable.
     - `rfl` reduces neither lane `j`'s start frame `(f0 x32 j).pc` nor `(m0 w32 j).next`.
       Both equations hold at each concrete index: the frame's at every `j < 32` by the kernel,
       and `(m0 w32 j).next` is 5 at every `j ≤ 32` (`#eval`), since `alloca` blocks take
       `fresh` numbers, not `next`.

     So the route takes lane `j`'s start frame and context as the facts that `Grid.start_thread`
     and `Grid.start_arg` (MojoProof/Sym/Kernel.lean:147, :170) and `Grid.start_ctx`
     (MojoProof/Sem/Grid.lean:632) give at every thread, as premises on a free frame in place of
     the term `f0 x j`, as MojoProofTest/OblGevmThread.lean's `thread` does for `gevm_kernel`. On a
     free frame and memory no lane is evaluated: the memory is a variable with the facts the
     `alloca`s and the loads read as premises, and each node's value comes from its value lemma
     at the valuation, not from the kernel's walk. So the two things the probe seemed to need,
     `m0 w j` at a free `j` and a walk of `Piece.walk` that keeps the index a term, are not
     needed: what a free frame needs is the values of `%6`'s loads (below) and the run lemma
     that composes the nodes' values (item 6 of "The order of the work");
   - `lifetime.start` and `lifetime.end` on a block the thread owns: done as the end of a
     segment (`summarizeLife`, `Seg.lifetime`), the next segment starting after the marker on
     the memory `Mem.setLive` makes;
   - `insertvalue` into `undef` (lines 34-35), `insertelement` into `undef` (lines 41, 45) and
     `extractelement` (lines 23-24): done, for every program. The nodes `SNode.insert`,
     `SNode.eltAt` and `SNode.insEltAt` (MojoProof/Sym/Term.lean) evaluate as `insertV`,
     `extractE` and `insertE`; an `undef`, `poison` or `zeroinitializer` operand to insert into is
     its `SNode.constAt` node (`fill .undef t` for `undef`); the steps are `exec_insertvalue`,
     `exec_extractelement` and `exec_insertelement` (MojoProof/Sym/Exec.lean), in
     `SState.stmt_sound` (MojoProof/Sym/Block.lean);
   - `getelementptr` with two indices (line 38): done, for every program, on a base that is not
     a global: the node `SNode.gepN` (its indices evaluated one by one, `SState.ops_eval`), the
     step `exec_gep`; on a global with other than one index the checker still refuses. With
     these, `gemv_segs` (MojoProofTest/SymSeg.lean) summarizes `%6` from statement 3, after its
     `alloca`s, as eleven segments, to its two shuffles and nine lifetime markers, and the
     summary of statements 41 to 47 to its branch; on a thread at statement 3, the thread runs
     the block through them (`Piece.through`). Its open twin `gemv_segs_twin`: the checker
     refuses statement 0, the first `alloca`;
   - loads after stores (lines 39-44). The load
     node that carries the effects before it is done: `SNode.loadAfter` (MojoProof/Sym/Term.lean),
     which the checker makes of a `load` after the block's first `store` (on a global, on its
     `SNode.globalAt` node), with its case of `SState.stmt_sound`; its value one effect at a time
     (MojoProof/Sym/LoadAfter.lean, for every valuation): after a `store` at a pointer of the
     same value, type, space and alignment, the stored value's decoding
     (`SNode.eval_loadAfter_store`, by `Mem.load_store`); after a `store` apart from it, its value
     without the `store` (`SNode.eval_loadAfter_apart`, by `Mem.load_store_apart`); a `load`
     effect leaves it (`SNode.eval_loadAfter_log`). Tests at layernorm's `%453`
     (MojoProofTest/SymSeg.lean): `ln_after`, `ln_twin`, `ln_apart`, `ln_reload`. The values of
     `%6`'s loads are done too, for every program (MojoProof/Sym/OblPieces.lean): the element
     lemma `Mem.load_store_elem` (a load of element `k` of an array stored whole gives element
     `k`, as `Mem.load_store` gives the whole value) and its node form
     `SNode.eval_loadAfter_elem`, for `%29` and `%33` (the `[2 x ptr]` stored whole at line 37,
     read one pointer at a time); `Mem.load_store_codec_of_block` for the `i32` slots `%30` and
     `%34`, through the lifetime markers of the other blocks; and the nodes of `%31` and `%35`
     (`SNode.eval_insEltAt_at`, `SNode.eval_constAt_undef`), so `%35` is the vector of the two
     delivered words. Tests at gemv_kernel's statements 29 to 37 (MojoProofTest/GemvEntry.lean):
     `load29`, `load33`, `slot30`, `undef31`, `vec31`, `vec35`.
   Then `%36` is lane 0's `%20` (items 2, 3, 4).
7. **The kernel clause and the specification.** With items 1 to 6, each thread of `gemv_kernel` is
   a path through `%6`'s segments, the loop and `%78`'s segments; of `gevm_kernel`, through `%6`,
   the loop and `%59`'s segments. The store is lane 0's, to its row's (column's) cell. Each
   warp's value is `warpDot` of its column's pairs once the threads' loop sums are stored
   (`warpDot_tpose`).

## The order of the work

1. The lane number (item 1): done.
2. Same-size casts (item 2): the node, the step and the scalar evaluation lemma are done; `%78`
   is now refused at its first shuffle, not at the `bitcast` before it. The vector evaluation
   lemma is done too (`castV_split`, `castV_join`).
3. Segments at collectives (item 3): done, `%78`'s six segments and, with item 5, `%59`'s seven are
   in the fragment, a segment's wait and resume are one line of `Seg.resume`, and a block's segments
   run in a row on one thread (`Seg.through`). The schedule (item 4) is proved for every program;
   its phases from the segments are left. With items 2 to 4, `%78`
   of `gemv_kernel` is covered, and with item 5 `%59` of `gevm_kernel`, so `gevm_kernel` has every
   block covered before `gemv_kernel` does (whose entry block needs item 6): it is the first kernel
   to prove.
4. Globals (item 5): done; the ownership across the barrier is left (`gevm_kernel`), and a
   `load` whose pointer operand is a global, after the segment's first `store`, is still refused.
5. The obligations of `gevm_kernel`'s `%6` and its loop by mojo_obl, at every launch with
   `ntid.x = 1024`: done (MojoProofTest/OblGevm.lean); for `K` not divisible by 32 the last round
   reads past `x` and `B` (`rounds_open`).
6. The stack round trip (item 6): `gemv_kernel`'s entry block. The loads after stores are done
   (`SNode.loadAfter`, its value lemmas in MojoProof/Sym/LoadAfter.lean), a lifetime call ends a
   segment (`Seg.lifetime`), and the vector and aggregate nodes and the two-index
   `getelementptr` are done, so `%6` from statement 3 is in the fragment (`gemv_segs`). The
   `alloca` in the block checker is done (statements 0 to 2: its node and effect, the freshness
   obligation, and `EndsAt` with the frame's `allocas`, `Block.soundAt`). The segments with the
   flag are done, so `%6` is in the fragment from statement 0 (`gemv_segs_alloca`), and so are
   the paths with the flag from statement 41 (`tail_covers`), and the warps from `Grid.start`
   with `Grid.fire`'s deliveries through `%6`'s two shuffles and `%43`, or `%44`, the loop at
   `%54` with `n` rounds through one arm and `%78`'s five shuffles, to a done grid at three
   launches with `K = 0` and two with one round, `K = 4` and `K = 3`
   (MojoProofTest/GemvWarp.lean). Left, in this order:
   - rounds of the loop at every `K`. Done at one block of 32 threads, `M = 1`, `K = 4` and `K = 3`
     (`run4`, `run3`): `memAB`'s matrix and vector blocks hold four words each (`memAB` sizes
     them from the lists, `4 · a.length` and `4 · b.length` bytes, and the output from `Cfg.out`;
     16 bytes at every launch here, `memAB_size`), the trip bound is one round, through `%70` for
     the lanes `j < K` (`%65 = %40 < K`) and `%75` for the others;
     `tail78`'s chain is `ChainWith.of_rounds` at `n` rounds of `lp a`, whose `RoundWith`s the
     kernel decides at the lane's valuation (`chainP`); `Warp.v` is by phase and lane, and `r` reads
     lane `shflSource`'s offer, as `WarpShfl` does; the output cell holds the word of `warpDot` of
     the row's pairs, and (`run4_deliver`) the word of the semantics' rounds
     `bflyRoundsAt (fun _ _ x y => deliver (Model.add x y) 0)` at the run's oracle numbers 0, the
     form `MojoProof.Tile.bflyDeliver_holds` reads, through `bflyRoundsAt_deliver` (bfly.md,
     statement 8), whose premise the kernel decides at the row. These rounds read the matrix and
     vector through the stored `[2 x ptr]` by evaluation, so they need no element lemma. A round
     adds a walk of `%58`, `%60`, `%70` or `%75` and `%76` to each lane's: one lane's `ok78` took
     14 s at `K = 0` and 28 to 32 s at `K = 4` (lanes 0 and 4, checked in parallel), and the warp
     (`run4`) 1 min 17 s, against 51 s for `run32`. At every `K`, for one thread whose other
     lanes' deliveries are premises: done (MojoProofTest/GemvLoop.lean `run`, for every valid
     launch, `M, K < 2 ^ 31` with `M K < 2 ^ 61`, row `r < M`, and a matrix and a vector in
     buffers that hold them). From statement 41 of `%6` through `%44`, the `⌈K / 32⌉` rounds and
     `%59` to position 1 of `%78`, `%79` is the `dotLoop` with contraction of the lane's strided
     pairs of row `r`, `stride 32 l (matVecPairs A v ⟨r, _⟩)`, in this order: (1) the header's
     iterates, `%55 = i` and `%56` the `dotLoop` of the lane's first `i` strided pairs, kept by a
     round of each arm at symbolic registers (`roundA_inv`, `roundB_inv`, from mojo_obl's
     `roundA` and `roundB`, MojoProofTest/OblGemv.lean); (2) `ChainWith.loop` and
     `ChainWith.reach` with that invariant: `(K + 31 - l) / 32` rounds through `%70`, then the
     rest through `%75`, the two loops of `loop_arms` (`chain`); (3) the loads' obligations from
     `K`, `M` and the block sizes (`roundA`; without `M K < 2 ^ 61` the matrix load has no
     address, `matrix_open`). From position 1 of `%78` the thread runs through the five shuffles,
     with their deliveries as premises, and lane 0's store through `%37` to `ret`
     (MojoProofTest/GemvLoopTail.lean `thread`; from statement 41, `to_ret`), its waits as
     `Piece.Wait.via` states them (`waits`: each call's position, full mask, offered bits, offset
     16, 8, 4, 2 or 1 and clamp 31, gemv IR :114-130, and the memory at the call). Lane 0's word
     (`total`) is its value after the semantics' rounds `bflyRoundsAt` over `bflyOffsets 5`,
     `%78`'s offsets in order, which `MojoProof.Tile.bflyDeliver_holds` reads, when lane 0's
     oracle numbers are its five `fadd`s' and each delivery is the partner's value after the
     rounds before (MojoProofTest/GemvLoopBfly.lean `total_eq`; at the run, with the rule,
     `stored_holds`). That partner's value is what the partner offers: `offered c k0 x z i l`
     (GemvLoopBfly.lean:165) is lane `l`'s `addAt` chain over its own deliveries, the argument
     `shfls` passes at shuffle `i` (`shfls_offered`, by `rfl`). When every delivery `z i l`, at
     every lane `l < 32`, is the offered value of the partner `l ^^^ 2 ^ (4 - i)`, every lane's
     `total` is its value after the five rounds (`total_chain` :220, from `offered_eq` :193 and
     `MojoProof.Tile.bflyRoundsAt_chain`, MojoProof/Tile/MatVec.lean:637, which holds for every
     round function, offsets and set of lanes closed under partners), and at lane 0 this is
     `total_eq`'s premise. (4), the deliveries as the partners' offered values at every `K`
     (`total_chain`'s `hz`), is done in item 6 (c), and with it the cell is row `i`'s
     `warpDot` up to NaNs at every `K` (MojoProofTest/GemvWarpWord.lean `word_warpDot_nanEq`);
   - the values of the loads through the stored `[2 x ptr]` and of the `i32` slots: done
     (MojoProof/Sym/OblPieces.lean, tests in MojoProofTest/GemvEntry.lean);
   - the entry block at a free thread, the run lemma the kernel theorem at every launch needs:
     done (MojoProofTest/GemvEntryRun.lean `entry`). Statement: gemv_kernel, for every valid launch `L`, thread `k`, context `c`
     with `c.prog = gemv.prog` and `c.env = L.env k`, thread `t` whose top frame `f` is at pc 0
     of `%6` with `%0`, `%1`, `%2` pointers at offset 0, `%3 = M` and `%5 = K`, and memory `m`
     whose three `fresh` block numbers at `t.k`, `t.k + 1` and `t.k + 2` have no block, with the
     two deliveries `d₁`, `d₂` of `%24` and `%25` (statements 17 and 18) as premises (words
     `u₁`, `u₂`; in `d₂`'s memory the three blocks are the thread's writable slots of 16, 4 and
     4 bytes): `RunsVia` with the two waits as `Piece.Wait.via` states them (each call's
     position, the full mask, the low and then the high half `%22`, `%23` of the row word
     `(ctaid.x · ntid.x + tid.x) / 32` from `L.env k`'s special registers, source lane 0, clamp
     31, gemv IR :13-26; the memory after the three `alloca`s, `slots`, at the first and the first
     delivery's at the second), continued by every run from statement 41 at a frame with `%0`,
     `%1`, `%2`, `%3`, `%5`, `%10` and `%11` (by `sext`) and `%35 = <u₁, u₂>`, `alloca` blocks
     `[b9, b8, b7]` in front of `f`'s, at step `t.k + 41`, and a memory with the three blocks
     written and their lifetimes ended and every other block as in `d₂`'s memory, so
     `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` of the input blocks carry over (the meeting point
     of the loop's run lemma). The frame's `dest` is not in the continuation: the pieces' steps
     (`RunsVia.of_coll`, `RunsVia.of_life`) do not give it, and the `ret` of a thread's only
     frame does not read it. The proof runs `%6`'s pieces (the summary of
     `gemv_segs_alloca`: the two collective segments and the nine lifetime markers) one at a
     time, from `RunsVia.of_wait` and the marker's step, each piece's obligations from its
     nodes' values. The first piece's obligations (the three `alloca`s and statements 3 to 17)
     did not close by a search over the node facts within 1,000,000 heartbeats (1 min 48 s): an
     `exact` with another node's fact makes the unifier evaluate the node list. Closed one at a
     time, each from its own node's fact (`obl_have` for the nodes with no named fact), the
     whole proof checks at the default heartbeat limit (the module builds in 16 s). Its premises
     hold at lane 3 of one block of 32 threads, `M = 1`, `K = 4` (`GemvThread.run`'s instance
     below, with `Grid.fire`'s deliveries on the memory with every lane's slots), and on the
     memory without the lane's `alloca` blocks the `store` to `%9` faults (`slots_mutant`);
   - the thread from its start to its `ret`: done (MojoProofTest/GemvThread.lean `run`: `entry`,
     then `GemvLoopTail.to_ret`, which is `GemvLoop.run` and then `GemvLoopTail.thread`).
     Statement: gemv_kernel, for every valid launch `L` with `M, K < 2 ^ 31` and
     `M K < 2 ^ 61`, thread `k`, context `c` with `c.prog = gemv.prog` and `c.env = L.env k`,
     thread `t` whose only frame `f` is at pc 0 of `%6` with no `alloca` blocks (as
     `Grid.start_thread` gives it), `%0`, `%1`, `%2` pointers at offset 0 of `p0`, `bA`, `bV`,
     `%3 = M` and `%5 = K`, memory `m` whose three `fresh` block numbers have no block, row
     `r < M`, matrix `A` and vector `v`, and the first two deliveries `d₁`, `d₂` the halves of
     `r`, with the three blocks the thread's slots in `d₂`'s memory and the input and output
     buffers there: the memory `M₀ = waitAt c [d₁, d₂] t m` at `%78`'s first shuffle is `d₂`'s
     memory with the slots dead (`EntryInv` and not live), and for all deliveries `d₃` to `d₇` of
     the binary32 `z₁` to `z₅`, with the output
     buffer in `d₇`'s memory, the thread runs through its seven waits as `Piece.Wait.via` states
     them (`entry`'s two, then `waits` at step `n = t.k + 41 + 21 + 19 a + 15 (⌈K / 32⌉ - a)`,
     `a = (K + 31 - laneid) / 32`, and memory `M₀`) to its end on `d₇`'s memory with, for lane 0,
     `total` stored at element `r` of `p0`, and the slots `b9`, `b8`, `b7` dead; the output block
     stays live (`live_out`). The bridge: the input and output buffers are not the slots
     (`Mem.Buffer.ne_slot`: space 1 against 0), so `EntryInv` keeps them from `d₂`'s memory to
     the memory at statement 41 (`EntryInv.keep`). `to_ret` chooses the memory at `%78`'s first
     shuffle inside `entry`'s continuation; `RunsVia.pin` (MojoProof/Sym/WaitVia.lean) fixes it
     before the last five deliveries, as the memory at a wait depends only on the earlier
     deliveries (`ToWait.det`), and `RunsVia.waitAt` (MojoProof/Sym/WaitAt.lean) names it:
     `waitAt c ds t m` is the memory at the thread's wait after the deliveries `ds`, from wait
     to wait by `nextWait`, the status and memory of the only run to the next call. A closed
     form, a term of `m`, `t.k` and `c`, would need `entry` restated with its memory at
     statement 41 (the three slots' stores, the logged loads and the lifetime ends) and
     `GemvLoop.run`'s invariant with the trace its loads log (two per round), so `run` names
     the memory by `waitAt`, which is for every program. Instance: every premise of `run` at one
     block of 32 threads
     (`launch2 1 1 32 1`), thread 3 (lane 3), `M = 1`, `K = 4`, row 0, the start's frame `f3`,
     a memory `m3` whose blocks 1 and 2 hold a `1 × 4` matrix and a vector of binary32 words
     (`Mem.holds_alloc`) and block 3 is the output, the start memory `mUpTo 3`, `m3` after lanes
     0 to 2's `alloca`s, and `%24`'s and `%25`'s deliveries `Grid.fire`'s: the halves of row 0 on
     `mUpTo 32`, `m3` after every lane's three `alloca`s, the memory at the two shuffles when the
     lanes run in turn to their first wait (no statement of `%6` before `%24` but the `alloca`s
     touches memory, gemv IR lines 8-26). Lane 3's slots there: its own `alloca`s give `EntryInv`
     at `mUpTo 4`, and lanes 4 to 31 allocate only at their own numbers (`slotsAll_off`), which
     are not lane 3's (`Mem.not_freshOf`, by `Mem.fresh_inj`), so `EntryInv.frame` keeps it
     (`lane3_inv`); the buffers: the `alloca` numbers are not below `m3.next` (`mUpTo_blocks`).
     Another lane's change that `run` concludes `EntryInv` of (its slot stores and liveness
     changes) keeps lane 3's `EntryInv` and the buffers too (`EntryInv.off`, `EntryInv.frame`,
     `Mem.SameOff.block`; a test at lane 2). Mutants: `allocas_mutant`, the premise
     `f.allocas = []`: with the output block among the frame's `alloca` blocks the `ret` ends it,
     so the final memory is not `run`'s; `slots_mutant`, the memory with every other lane's
     slots but not lane 3's (`mNo3`) does not meet `EntryInv`, and there the `store` to `%9`
     (statement 21, after its `lifetime.end` and `lifetime.start`) faults with "access to no
     block", while on `mUpTo 32` it succeeds. `lane3_counts` checks the conclusion at lane 3: no
     store, pair 3 only, and `%78`'s first shuffle at step `t.k + 81`, not `t.k + 40`. The final
     memory is one memory (the store's result for lane 0, `d₇`'s memory for the others, then the
     slots dead): `run_out` turns the run's final predicate into `WarpRun.of_waits`'s `(· = M J (j +
     1))` with `M J (j + 1)` that memory (`out`), by `RunsVia.imp` (MojoProof/Sym/WaitVia.lean, a
     weaker final predicate, for every program, by induction on the waits);
   - then the deliveries at the warp, in this order: (a) done: lane `j`'s seven waits as
     `WarpRun.of_waits` (MojoProof/Sym/Canon.lean:493) takes them, `(W i j).via fn (lbl i)` for
     `i < 7` with `W i j` the `i`-th of `entry`'s two and `%78`'s five (`GemvLoopTail.shfls`)
     and labels 6 and 65 (`waits_range`, by `Piece.Wait.map_via_append`, MojoProof/Sym/Canon.lean,
     which is `Piece.Wait.map_via` for two blocks), with the final predicate as that equation
     (`run_out`); (b) done: `%24` and `%25` deliver to every lane of a warp lane 0's halves of
     its row word `(ctaid.x · ntid.x + tid.x₀) / 32` (MojoProofTest/GemvShfl.lean `idx_row`,
     `run`'s premises `hd₁`, `hd₂` at lane 0's row), the lane's own row when 32 divides the
     block's `x` size (`row_lane`, by `gemv_warp`), and `WarpRun.of_waits`'s delivery equation
     holds at the seven shuffles at offers that are words (`deliver7`, by
     `Program.shfl_deliver` of MojoProof/Sym/ShflDeliver.lean for every program whose shuffle
     declarations pass `Program.shflKeeps`, which gemv's do, `keeps`); tests at blocks of 32 and
     64 threads, and two mutants: at 16 threads the first `bfly`'s source lane is not a lane and
     `poison` is delivered, and at two blocks of 48 threads lane 16's row is not lane 0's;
     (c) done: `%78`'s five deliveries are the partners' offered values
     (`MojoProofTest.GemvLoopBfly.offered`, the sums after the rounds before; `total_chain`'s
     premise `hz`, MojoProofTest/GemvLoopBfly.lean:220) at every `K` and warp: each lane's
     offered values are its `acc` (`offered_acc`, MojoProofTest/GemvWarpWord.lean), so each
     delivery is its partner's (`partner_offered`), and lane 0's `total` is its value after the
     five rounds `deliver (Model.add a b)` over `bflyOffsets 5` from the lanes' sums
     (`word_rounds`, by `total_chain`); (d) done: each phase's memory after its last lane is the next
     phase's first (`WarpRun.of_waits`'s `h0`), with the memories `Lanes.mem i j` one function
     of phase and lane (MojoProofTest/GemvWarpRun.lean): lane `j` starts on the memory after
     lanes 0 to `j - 1`'s `alloca`s (`mem0`), `%24` and `%25` deliver on `mem0 32`, `%78`'s
     first shuffle waits on lane `j`'s `waitAt c [d₁, d₂] t m` (`RunsVia.waitAt`) from the
     memory the earlier lanes' waits leave (`mem2`), and each lane ends on the memory the
     earlier lanes' ends leave (`mem7`, by `out`). The lanes' `alloca` numbers are apart
     (`Mem.fresh_inj` at distinct threads, `b_inj`), so the other lanes' `alloca`s, slot
     stores and slot deaths keep a lane's `EntryInv` and the buffers (`Mem.SameOff.chain`,
     MojoProof/Sym/LaneFrame.lean, `EntryInv.frame`, `keep`); (e) done: the warp at every `K`
     (`warp`), in this order: lane `j` by `run` from `mem0 j` (`lane`); each wait's shape and
     delivery at every phase (`shape`, by `deliver7`); the induction over the lanes for
     `mem2` and for the output buffer (`out_keeps`, by `Mem.Buffer.of_store` and
     `Mem.Fits.of_store`); `WarpRun.of_waits` with `J = 7`; and lane 0's final load after the
     later lanes' slot deaths: a lane other than lane 0 stores nothing and its slot deaths are
     of other blocks (`step7`), `RunsVia.final` gives lane 0's store and
     `Mem.load_store_codec_of_block` its load. Statement: gemv_kernel, for every valid launch
     whose block size 32 divides, warp's first thread `k`, contexts at the lanes' special
     registers with distinct threads and address oracles below `2 ^ 60`, threads at gemv's
     start (`run`'s frame premises), `M, K < 2 ^ 31` with `M K < 2 ^ 61`, row `r` lane 0's
     row, and memory with no block at the warp's own `alloca` numbers (lane `j`'s `e`-th,
     `j < 32`, `e < 3`; blocks at other numbers from `next` on, such as an earlier warp's dead
     slots, may be present: `w0_not_free`, lane 0's first slot of `w0` at `m3`'s `next` after
     the warp) and the output, matrix and vector buffers (`Lanes.Pre`; a buffer at one of those
     numbers would not outlive the lane's `alloca`s, `slots_buffer`, whose instance
     `fresh_mutant` puts one at lane 0's first number of `m4`): the warp runs (`WarpRun`) from
     the memory to `mem7 32`, where the word at row `r` of the output loads as lane 0's
     `total (c k) n₀ (x 0) z₀ … z₄`, with `x l` lane `l`'s `%79` and `zᵢ` the offer of lane 0's
     partner `2 ^ (4 - i)` (`acc i (2 ^ (4 - i))`, `shfls`' `addAt` chain at the partner's
     context, step count and own deliveries). Its instance (`w0_pre`): one block of 32 threads,
     `M = 1`, `K = 4`, row 0, the threads at `f3`'s start, on `m3`. With (c)
     (MojoProofTest/GemvWarpWord.lean), under `Lanes.Pre`: the stored word is lane 0's value after
     the five rounds from the lanes' sums (`warp_word`); it is row `r` of `rowWords`, words that
     meet `bflyDeliver_holds`' rule at `k = 5`, for all input words that hold the matrix and the
     vector (`warp_row`, by `stored_holds`); and it is row `r`'s `warpDot true` at the lanes' loop
     oracle numbers up to NaNs (`word_warpDot_nanEq`, by `bflyDeliver_nanEq`), and equal to it where
     no round's sum is a NaN (`warp_dot`, by `bflyRoundsAt_deliver`; at a NaN sum the kernel's
     `fadd` delivers the oracle's NaN). Its instance: `word_warpDot_nanEq` at `w0`; (f) done: the
     next warp's premises after a warp (MojoProofTest/GemvWarpRun.lean). The memory after the warp's
     lanes (`mem7 32`) has the start's `next`, its blocks outside `p0` and the warp's `alloca`
     numbers, the output buffer, and every load from `p0` outside row `r`'s word (`warp_frame`); so
     a later warp of the launch whose threads are none of the warp's keeps its premises
     (`Pre.later`: its `alloca` numbers, at the same `next`, are neither `p0` nor the warp's), and a
     later warp with another row keeps row `r`'s word (`later_row`). Instance: the second warp of
     one block of 64 threads, `M = 2`, after the first (`w64_next_pre`), and both rows after both
     warps; (g) done: a warp's premises from the grid's start (`Pre.of_start`), for every valid
     launch whose block size 32 divides: the start's memory has no block from `next` on when the
     caller's has none (`Grid.start_free`, by `launchArgs_free`, MojoProof/Sym/LaneFrame.lean; gemv
     has no globals, `gemv_globals`), its contexts' address oracles are the address choice at
     `Nat.pair 1 (Nat.pair n j)` (`Grid.start_addr`), each parameter is `noundef`, so
     `Grid.start_scalar` gives its register, and, when 32 divides the block's `x` size
     `L.block .x` (not only its size), the rows are below `L.block .x / 32 · L.grid .x`
     (`row_lt`; at block (16, 2, 1) and grid (1, 1, 1) the block has 32 threads, but row 0 is not
     below `16 / 32 · 1 = 0`). Instance: `w0_start`; (h) done: the warps whose row is `M` or more
     (the row is the warp's, `idx_row`) run `%6`: the `alloca`s, the two `idx` shuffles `%24` and
     `%25`, the slot stores and loads and the lifetime ends; then `%42` (line 56) branches to
     `%43`, `br label %103` and `ret`. They store nothing to the output and run none of `%78`'s
     shuffles, so their `WarpRun` has two waits (`J = 2`), not seven. A lane
     (MojoProofTest/GemvOut.lean): `entry`
     (MojoProofTest/GemvEntryRun.lean) to statement 41, then `%42`'s edge to `%43` at `M ≤ r`
     (`out_path`, as `entry_edge`, MojoProofTest/OblGemv.lean, is its edge to `%44` at `r < M`), on
     to the thread's end (`out_ret`), and from its start through its two shuffles to its end
     (`run`), keeping every block outside its three `alloca` numbers. The warp (`Out`,
     MojoProofTest/GemvWarpRun.lean): each lane's run to the memory at its end after its deliveries
     (`Out.lane`, by `RunsVia.endAt`, MojoProof/Sym/WaitAt.lean, the end memory of a run being
     determined, `Runs.det`), the warp by `WarpRun.of_waits` at `J = 2` (`Out.warp`), and its frame:
     the start's `next` and every block outside the lanes' `alloca` numbers (`Out.warp_frame`); its
     premises (`Out.Pre`) from the grid's start (`Out.Pre.of_start`); (i) done at every
     one-dimensional launch: the warps as one canonical run, by `CanonRun.of_inv`
     (MojoProof/Sym/Canon.lean:569) over `warps L N`, `N` the grid's thread count, with the
     invariant after `i` warps that the output buffer is kept, every later warp's premises hold on
     the memory (`Lanes.Pre` for a row below `M`, `Out.Pre` for one at `M` or more) and every
     earlier in-range warp's row word loads. At `i = 0` the premises are the start's
     (`Pre.of_warps`, by `Pre.of_start` and `warps_mem`, and `Out.Pre.of_start`); at each warp,
     `warp` or `Out.warp` gives its run, `Lanes.Pre.frame` and `Out.Pre.frame` the later warps'
     premises on the memory after it (the warps' first threads are 32 apart, `warps_apart`, and the
     start's contexts are at the threads' numbers, `Grid.start_ctx`, so the later warps' `alloca`
     numbers are none of its lanes'), and `warp_frame`'s last part, or `Out.warp_frame`, the earlier
     rows (at a one-dimensional launch thread `n`'s row is `n / 32`, `row_eq`, so two warps' rows
     differ). Statement (`grid_run`): gemv_kernel, for every valid launch with `y` and `z` sizes 1
     whose block's `x` size 32 divides, and `Pre.of_start`'s arguments, bounds (with the address
     choice below `2 ^ 60` and a caller's memory with no block from `next` on) and buffers: the
     grid's warps have a canonical run (`CanonRun`) from the start's memory to a memory where each
     warp whose row `r : Fin M` is below `M` has its row word load as its lane 0's `word 0`.
     `grid_done`: the start steps to a done grid with that memory (`CanonRun.start_done`).
     `grid_rows` (MojoProofTest/GemvWarpWord.lean): under `grid_run`'s premises, when
     `M ≤ L.block .x / 32 · L.grid .x` (the warps' rows cover the matrix's rows), every
     row `i` of the done grid's output loads as a word that is row `i`'s `warpDot true` at the
     oracle numbers of the warp from thread `32 i` up to NaNs. Instances from the grid's start, with
     the start's result a premise: one block of 32 threads, `M = 1` (`w0_done`), of 64 threads, `M =
     2` (`w64_done`, and `grid_rows`' example), and of 64 threads, `M = 1`, whose second warp has
     row 1 (`w64_out_done`). `lane43` and `warp43` (MojoProofTest/GemvWarp.lean) stay: they are the
     same warp at a launch the kernel decides (`ok43`, `mems43`), and `warp43`'s test and `refused`
     use them. Left: launches with a `y` or `z` size above 1. There a thread's row reads only its
     `x` coordinates, so two warps can share a row; such a launch races only if two distinct
     participating warps share a row below `M` (only a warp whose row is below `M` stores), which
     not every one does: block (16, 2, 1) and grid (1, 1, 1) has one warp, and at `M = 0` no warp
     stores; block (32, 2, 1) and grid (1, 1, 1) at `M ≥ 1` has two warps of row 0, whose lanes
     0 both store it: `row_race` (MojoProofTest/GemvSound.lean:552) has threads 0 and 32 of row
     0 there and their two stores at row 0 racy (thread 32's at row 1 would not be); no theorem
     states that a run reaches both stores.
7. The kernel theorems (item 7), first gemv_kernel's.
   (a) The soundness of gemv_kernel's grid (MojoProofTest/GemvSound.lean), by
   `CanonRun.start_sound` (MojoProof/Sym/CanonBar.lean:786), whose premises past the canonical run
   are the caller's memory's `m.BytesIn m.Known` (:788), an observation `obs` of the output that
   reads only blocks (:790) with its relation `R`, and the final trace's facts: no data race
   (`GPUProof.racy` at `sig` is `false`, :793) and the `!invariant.load` promise kept
   (`GPUProof.kept`, :796). The route: the lanes' events as one predicate `Ev` (gemv IR: the
   slot stores at lines 29, 32 and 37 and loads at lines 39, 40, 43 and 44, the matrix and
   vector loads at lines 98 and 99 with `!invariant.load`, lane 0's store at line 136, which a
   warp whose row is `M` or more does not reach, line 56); no race among `Ev` events
   (`racy_ev`, by `racy_eq_false_of_writers`, MojoProof/Sem/Trace.lean:254, and
   `GPUProof.racy_iff` only: each slot is its thread's, `Mem.fresh` numbering a thread's
   `alloca`s by its thread, row `i` of the output is thread `32 i`'s, the matrix and vector are
   only read) and the promise kept (`kept_ev`, by `kept_of_split`, Trace.lean:136: no event
   writes the matrix or the vector); the trace facts carried by the same canonical run as the
   rows, as an invariant `Q` of `grid_run` (`grid_run_inv`, MojoProofTest/GemvWarpRun.lean:1367,
   at `Q m₁`: `m₁.next` is `g`'s and `m₁`'s trace extends `g`'s by `Ev` events, `Ext`,
   MojoProof/Sym/SegTrace.lean:308), a warp's from its lanes' (`lanes_ext`, `out_ext`: the
   `alloca`s log nothing, `mem0_trace`, the butterfly shuffles change no memory, and the last
   phase logs lane 0's store only, `ext_out`), and `grid_rows`' rows at that run's end memory
   (`rows_of_loads`, MojoProofTest/GemvWarpWord.lean:272). `Grid.sound_cells`
   (MojoProof/Sem/Shared.lean:567) is not used: its `racy_kept_of_cells` takes every block
   other than the output cells read-only, and gemv_kernel writes its `alloca` slots. Done:
   `grid_end` (MojoProofTest/GemvSound.lean:287): gemv_kernel, for every valid
   one-dimensional launch whose block's `x` size 32 divides, with `M ≤ L.block .x / 32 ·
   L.grid .x`, `grid_run`'s arguments, bounds and buffers: the warps' canonical run ends at a
   memory whose trace has no race and keeps the promise and whose rows meet `RowsDot`;
   `grid_sound` (GemvSound.lean:370), with `m.BytesIn m.Known` too:
   `Grid.Sound L c g (rowsObs L M p0) (RowsDot L g c M K p0 A v)`; `rowsObs` reads the `M` rows
   at `p0` with the `who` that `Grid.start_ctx` (MojoProof/Sem/Grid.lean:632) gives thread
   `32 i`, `⟨32 i, 32 i / volume L.block⟩`, so it names no start's contexts; `RowsDot` is
   `grid_rows`' relation (each row a word that is its row's `warpDot true` up to NaNs). Its
   instance, with the start from `starts` and every premise proved: one block of 32 threads,
   `M = 1`, `K = 4`, on `m3` (the example after `kernel_sound`). The memory premises are proved
   once for every size: `GemvThread.mem A v` (MojoProofTest/GemvThread.lean) is the caller's
   memory with the matrix and the vector at blocks 1 and 2 and the output at block 3, and
   `GemvThread.mem_caller` gives `Caller`, its closed memory, buffers, fits and holds, for every
   `M`, `K < 2 ^ 31` with `M K < 2 ^ 61`; `m3_caller` and `GemvWarpRun.n3_caller` are its
   instances at the one-warp and two-warp memories. The lanes'
   events, for every warp `w` with its premises: `lanes_events` (GemvSound.lean:249),
   `∀ j < 32, Ext (Ev w.m.next w.p0 bA bV w.M) (w.mem2 j) (w.mem2 (j + 1))` for an in-range warp
   (`Lanes.mem2`: lane `j`'s run from `%25`'s shuffle to `%78`'s first, IR lines 27-114), and
   `out_events` (:240), `∀ j < 32, Ext (Ev w.m.next w.p0 bA bV w.M) (w.memE j) (w.memE (j + 1))`
   for a warp whose row is `M` or more (`Out.memE`: lane `j`'s run from `%25` to its `ret`). The
   thread run lemmas carry the trace's extension to their continuations: `GemvEntryRun.entry`
   (MojoProofTest/GemvEntryRun.lean:481) the slot stores and loads of lines 29-44 as
   `Ext (SlotEv …)` (`SlotEv`, :391: the thread's accesses of its three slots, none atomic or with
   `!invariant.load`; `ext_store`, :398), `GemvLoop.run` (MojoProofTest/GemvLoop.lean:412) the loads
   of lines 98-99 as `Ext (ReadEv bA bV)` (`ReadEv`, :129; two per round through `%70`, `roundA_inv`
   by `ext_reads`; none in a round through `%75`, `two_ext` by `Valuation.iterate_loads`),
   `GemvLoopTail.to_ret` (MojoProofTest/GemvLoopTail.lean:287) the same up to `%78`,
   `GemvThread.run` (MojoProofTest/GemvThread.lean:106) both from `d₂.2` to the wait at `%78`, and
   `GemvOut.run` (MojoProofTest/GemvOut.lean:120) the out-of-range lane's slot accesses to its end;
   `Lanes.mem2_ext` and `Out.memE_ext` (MojoProofTest/GemvWarpRun.lean:749 and :1180) take them to
   the warp's lanes, and `slotEv_ev` (GemvSound.lean:224) makes a slot access an `Ev` event
   (`Mem.fresh` numbers the slots from `next` by their thread).
   (b) gemv_kernel's `GPUProof.Kernel.Sound` against `GPUProof.Spec.matVec` through Theorem 0,
   with no `Res`: `kernel_sound` (GemvSound.lean:457). Statement:
   gemv_kernel, for every valid one-dimensional launch `L` whose block's `x` size 32 divides,
   with `M ≤ L.block .x / 32 · L.grid .x`, arguments
   `[.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, M, .bits 32 x4, K]` (every parameter is
   `noundef`, IR line 7), caller's memory `m` closed for the arguments (`Mem.Closed`) with
   `grid_run`'s bounds and buffers holding `A` and `v`, and every width `bits` and input words
   `I` that hold `A` and `v`:
   `GPUProof.Kernel.Sound sig (gemv.prog, gemv.fn_0) L args m (fun ω => ∀ q, ω.1 q < 2 ^ 60)
   (fun b => rowsObs L M p0 { blocks := b }) (RowsRule K bits I)` (GPUProof/Sound.lean:88),
   where `RowsRule K bits I f` says the rows load as words `W i` that meet the rule of
   `GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` at `(M, K)`,
   `MojoProof.Tile.matVecEnc FloatTy.float.fmt bits` and `I` (`GPUProof.FloatRule.Holds`). Route: at
   each admitted choice, the start (`starts`, by `Grid.start_ok`, MojoProof/Sym/Start.lean:102, at
   gemv's check, the closed memory and the `noundef` parameters, by evaluation), `grid_end`'s run,
   its done grid (`CanonRun.start_done`, MojoProof/Sym/CanonBar.lean:768) not bad by
   `Grid.Done.bad_iff` (MojoProof/Sem/Determinism.lean:164) with `grid_end`'s race and promise
   facts, then Theorem 0 (`GPUProof.Sound.of_one_run`, GPUProof/Sound.lean:194) at `sig` as
   MojoProofTest/Theorem0.lean's `sound_sig` (:39) applies it. The rows' relation is free of the
   oracle: each row's word is its `warpDot` at its warp's loop oracle numbers up to NaNs
   (`RowsDot`, MojoProofTest/GemvSound.lean:269, `MojoProof.Tile.WarpWords` at `matVecPairs`), and
   `rows_holds` (:416) grades every row at whatever oracle numbers by
   `MojoProof.Tile.warpDot_matVec_holds` (MojoProof/Tile/MatVec.lean:597), the case of the row
   lemma `groupDot_rows_holds` (:496; through `holds_of`, :157, and `groupDot_nanEq_approx`, :420,
   with `GPUProof.ScalarEnc.decode_eq`, GPUProof/Spec/Basic.lean:154, for the NaNs).
   `gemv_torchLean` (MojoProofTest/GemvTorch.lean:70), with the same premises: the same
   `GPUProof.Kernel.Sound` for `TorchRows` (:40), the rows each within the spec's grade of
   TorchLean's contraction `.matVec` of every real matrix and vector that the input words
   approximate, read through `MojoProof.Import.torchLean` at that grade (`torchRows_of_rule`, :55,
   by the importer's `eq`).
   (c) gevm_kernel's grid run, a `PhaseRun` (docs/proofs/canon.md, "Instances on gevm_kernel"):
   each block of threads `β` a `BlockRun.bar` (its 32 warps in turn to the barrier at statement 6
   of `%59`, IR line 79, then `BlockBar`) and then a `BlockRun.ends` (its warps in turn through the
   five shuffles of `%59`, lines 84-100, to `ret`). Proved, on every valid launch `L` with
   `ntid.x = 1024`, `N < 2 ^ 31`, `K % 32 = 0`, `K < 2 ^ 31` and `K N < 2 ^ 29`, for every thread
   with the entry's premises (`GevmWarp0.Lane`, MojoProofTest/GevmWarp0.lean:64: `gevm`'s program,
   `L`'s registers, the shared array at offset 0 of its block's `sb β`, the entry frame with the
   pointers and the words of `N` and `K`) and every memory with the buffers (`GevmWarp0.Bufs`,
   :46: `p0`, `bA` and `bB` as in `whole`, holding `A : [K]` and `B : [K, N]`, and `sb β` a
   writable 4096-byte block of shared memory owned by `β`):
   - each warp to the barrier (`GevmWarp0.warp`, :227, by `WarpWait.of_inv` at `J = 0`, each lane
     by `GevmWarp0.lane`, :172, from `GevmBar.bar`), each block's warps and its `BlockBar`
     (`GevmWarp0.block`, :279), the shared array then holding at cell `x` the loop sum of thread
     `1024 β + tpose 32 x` (`SegEvents.gevm_buffer`);
   - each thread from the barrier to its end (`GevmWarp1.resume`, MojoProofTest/GevmWarp1.lean:83),
     each warp through its five shuffles (`GevmWarp1.Warp.warp`, :384, by `WarpRun.of_waits` at
     `J = 5`, the deliveries by `Program.shfl_deliver_bfly`), lane 0's word NaN-equal to column
     `32 β + w`'s `warpDot` (`Warp.acc_nanEq`, :497, by `warpDot_tpose`);
   - each block from its entry to its end (`GevmWarp1.block`, :567), its 32 columns then loading
     as their `warpDot`s up to NaNs, the other blocks and columns kept;
   - the trace: the loop adds only reads of `bA` and `bB` (`OblGevmRun.loop`, :176, an `Ext`
     conjunct, from each round's two invariant loads), so a thread to the barrier adds those
     reads and its store to its cell (`GevmBar.bar`, :79; `GevmWarp0.lane`), a block's phase 0
     events of `GevmWarp0.Ev0` (:98: reads of the inputs, each thread's 4-byte store at its cell
     `32 laneid + tid.x / 32` of the block's array) and, after its barrier, events of
     `GevmWarp1.Ev1` (:144: non-invariant reads of the array, lane 0's 4-byte store at its output
     cell; `Warp.mout_ext`, :280); `GevmWarp1.block` concludes both extensions;
   - the blocks in turn on a grid of side 1 in `y` and `z` with `N ≤ 32 · L.grid .x`
     (`GevmWarp1.blocks`, :706, by `PhaseRun.of_inv`): `∃ Es m', PhaseRun L c t
     (List.range (volume L.grid)) m Es m' ∧ ColsDot … ∧ (m.trace = [] → ∀ x ∈ (phases
     m'.trace).1, Acc L c sb bA bB p0 x.2 x.1)`, every access with its phase one of
     `GevmWarp1.Acc` (:157), the invariant's `PhaseInv` (MojoProof/Sym/PhaseExt.lean:28, for every
     property of accesses at a phase: `PhaseInv.ext` :44 over a block's `Ev0` events at count 0,
     `PhaseInv.bar` :66 at its barrier, `PhaseInv.ext` over its `Ev1` events at count 1,
     `PhaseInv.phases` :77 at the end), as the trace extends block by block
     (`GevmWarp1.ColsDot`, :683: word `j < N`
     of `p0`, read by thread `32 j`, is column `j`'s `warpDot`, `vecMatPairs A B j`, at its warp's
     loop oracle numbers up to NaNs: `MojoProof.Tile.WarpWords .float true o (vecMatPairs A B)`
     at those loads, MojoProof/Tile/Words.lean:42, the premise of `GevmSpec.cols_holds`, as
     `RowsDot`, GemvSound.lean:269, is at `matVecPairs`); and `GevmWarp1.grid`
     (:804): from a start (`Grid.start gevm.prog gevm.fn_0 L args m ch oracle = .ok (g₀, c)`)
     with arguments `[.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, x3, N, K]` (`%3` is not used),
     `N = 32 · L.grid .x`, the caller's memory `m` with the buffers `p0`, `bA` and `bB` of
     `Bufs`, and address choices whose shared arrays fit below `2 ^ 32` (`hch : ∀ β < L.grid .x,
     ch (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32`, (d)'s admission), `g₀` steps to a
     done grid whose memory has `ColsDot`, with shared arrays `sb β` of the blocks of threads
     (`g₀.mem.ctaOf (sb β) = some β`) such that every access of its trace with its phase is one of
     `Acc` (`blocks`' last conjunct at the start's empty trace): `Lane` by `Grid.start_ctx`
     (MojoProof/Sem/Grid.lean:632, the contexts' program, registers and `who`),
     `Grid.start_thread` (MojoProof/Sym/Kernel.lean:147, the entry frames) and
     `Grid.start_scalar` (the registers, each parameter `noundef`), as
     gemv's `start_lanes` does; the buffers on `g₀.mem` by `Grid.start_blocks` (Grid.lean:593);
     the shared arrays by `Grid.start_shared` (MojoProof/Sym/StartShared.lean:117, for every
     program and launch: each context of block `β` has an internal shared global's table entry
     at offset 0 of a block `q β`, `g₀.mem` has at `q β` the block `shared` allocates,
     `sharedBlock`, :39, and the `q β` are apart), here gevm's one shared global, 4096 bytes
     aligned to 4 at address `ch (Nat.pair (β + 2) 2) * 4 % 2 ^ 32`, which `hch` puts below
     `2 ^ 32` (`Bufs`' fit); then `blocks` and `PhaseRun.start_done`. Tests at gevm_kernel's
     start at one block and at the layer-norm program's for every launch:
     MojoProofTest/StartShared.lean.
   The done grid is not bad (`GevmSound.grid_bad`, MojoProofTest/GevmSound.lean:56, for every
   such start, done grid reachable from it and `sb` with `Acc`): `Grid.Done.bad_iff`
   (MojoProof/Sem/Determinism.lean:164), no race by `racy_cells` (MojoProof/Sem/Shared.lean:170)
   at cell map `tpose 32` (injective below 1024, `tpose_tpose`), cell width 4, the owners
   `z.mem.ctaOf` and the output's tiling `GevmTrace.warpTiles` (MojoProofTest/GevmTrace.lean:87;
   lane 0's cell by `GevmTrace.out_cell`, :336), and the promise kept by `kept_of_split` (the
   invariant loads read `bA` or `bB`, which no access writes). The owners at the done grid are
   those at the start (`Grid.start_reach_above`): `p0`, `bA` and `bB` are the caller's (owner
   `.all`, so no block of threads'), `sb β` is `β`'s. `GevmTrace.gevm_sound` (:174) takes the
   trace as two rounds of the whole grid (`rounds (volume L.grid) [E₀, E₁]`) and is not used:
   the run's trace extends block by block, and `PhaseInv` counts each access's phase from its
   own block's barriers (`phases`, MojoProof/Sem/SigDef.lean:185) without rounds.
   A last block past `N` (`N < 32 · L.grid .x`) is not a case of the kernel: the IR has no guard
   against `N` (`%4`). The loop reads column `%17 = 32 ctaid.x + laneid` of `B` at
   `%54 = %50 · N + %17` (lines 17-20, 64-67) and lane 0 stores at `%29`, word
   `32 ctaid.x + tid.x / 32` of `p0` (lines 21-32, 115). Lines 103-112 test only the lane
   (`laneid % 32 = 0`), and lines 79-110 have no branch. So at `N < 32 · L.grid .x` the last
   block's warps past column `N` store past the output's `N` words, and its lanes past `N` read,
   on the last row `K - 1`, past `B`'s `K N` words. The launch premise is `N = 32 · L.grid .x`
   (with buffers of exactly `N` and `K N` words). `Lane`'s column premise, `32 ctaid.x + 31 < N`,
   with `blocks`' `N ≤ 32 · L.grid .x`, already gives it at the last block.
   (d) gevm_kernel's `GPUProof.Kernel.Sound` against `GPUProof.Spec.vecMat`. Proved
   (`GevmSound.kernel_sound`, MojoProofTest/GevmSound.lean:218): with (c)'s premises on the
   launch, sizes and caller's memory, `m` closed for the arguments (`Mem.Closed`), and every
   width `bits` and input words `I` that hold `A` and `B`,
   `GPUProof.Kernel.Sound sig (gevm.prog, gevm.fn_0) L args m adm
   (fun b => colsObs L N p0 { blocks := b }) (ColsRule K bits I)` with the admission
   `adm := fun ω => ∀ β < L.grid .x, ω.1 (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32`
   (`ω.1` the address choices: `Grid.start` gives block `β`'s shared arrays the choices
   `ch (Nat.pair (β + 2) ·)`, and `shared` places gevm's one shared global, the module's first,
   at choice `2 · 0 + 2` times its alignment 4 modulo `2 ^ 32`, `sharedBlock`). It excludes only
   the choices whose 4096-byte array would cross `2 ^ 32`, where the semantics' addresses wrap
   (`Mem.addr`, MojoProof/Sem/Value.lean:462, is `(base + off) % 2 ^ w`); a GPU's shared
   addresses are far below that, so it is the semantics' wrap that it excludes, not a placement
   of the kernel. The run needs the fit: the shared cell's store goes through `mojo_obl`'s
   no-wrap obligation (`blk.addr + size ≤ 2 ^ (l.ptr s).1`, MojoProof/Sym/Obl.lean:45;
   `GevmBar.bar`'s `hF`), and `grid` derives it from `hch`, the admission at `ω.1 = ch`. Where
   `colsObs` (MojoProofTest/GevmSpec.lean:55, `MojoProof.Tile.warpObs` at gevm's layout, as
   `rowsObs`, GemvSound.lean:262) reads the `N` words at `p0`, and `ColsRule K bits I f`
   (GevmSpec.lean:64,
   `MojoProof.Tile.Loads`) says that they load as words meeting the rule of
   `GPUProof.Spec.vecMat g` at `(K, N)` and `vecMatEnc` with `g = vecMatLaneGrade 32 5 fun m =>
   (m + 31) / 32`. Proved: `cols_holds` (:80), `ColsDot` gives `ColsRule`; `TorchCols` (:98)
   and `torchCols_of_rule` (:114), the same words in TorchLean's `.vecMat` through
   `GPUProof.Importer.graded_of_holds`; tests at 3 × 2 and 40 × 3 and the mutants `off_ulp` and
   `refused`. Route, as gemv's `kernel_sound` (GemvSound.lean:457): the start by
   `GevmSound.starts` (:180, `Grid.start_ok`, MojoProof/Sym/Start.lean:102: gevm's one global an
   internal shared array with an `undef` initializer, every parameter `noundef`, IR line 9),
   (c)'s run and done grid by `GevmWarp1.grid`, not bad by (c)'s `grid_bad`, the observation
   `colsObs` at the done grid by `rfl` and the relation by `cols_holds`, then Theorem 0
   (`sound_sig`, MojoProofTest/Theorem0.lean:39). `GevmSound.gevm_torchLean` (:260) is the same
   for `TorchCols` (`torchCols_of_rule`, for every grade of the importer's `.matVec`). Tests with
   every premise proved and no run evaluated: `sound1024` (:314) and `torch1024` (:334, at
   `GPUProof.matVecGrade`), at one block of 1024 threads (`launch2 1 1 1024 1`), `N = K = 32`,
   every vector and matrix of binary32 words, the memory `GemvThread.mem B A` (the matrix at
   block 1, the vector at block 2, the output at block 3; closed for gevm's argument order,
   `mem_closed`, :296) and the input words `colWords 32 A B`. The spec side
   is in the core: the encoding `MojoProof.Tile.vecMatEnc` (MojoProof/Tile/MatVec.lean:141); the
   grade `g`, `GPUProof.vecMatLaneGrade (2 ^ 5) 5 fun m => (m + 2 ^ 5 - 1) / 2 ^ 5`
   (GPUProof/Spec/Linear.lean:296), `laneGrade (E.out.fmt j) 32 5 ⌈K / 32⌉ K` at column `j` where
   the grades of the vector and column `j` are at most their formats' `safeMax`
   (`GPUProof.vecMatGrade`, :312, is its case at one lane); and the rule's lemma
   `MojoProof.Tile.warpDot_vecMat_holds` (MojoProof/Tile/MatVec.lean:573): output words each
   `warpDot c (o j) (vecMatPairs v A j)` or a NaN with it (`NaNEq`) meet `Spec.vecMat g`'s rule at
   `vecMatEnc`, the case `k = 5` of `groupDot_cols_holds` (:552), as `bflyDeliver_holds` (:534) is
   for `Spec.matVec` (`ColsDot` is `WarpWords`, so `grid`'s conclusion is `cols_holds`'s
   premise). A last block past `N` is outside the launch's premises ((c): the IR has no guard
   against `N`).
   TorchLean's form is
   `MojoProof.Import.torchLean`'s `.vecMat` (`vecMat_eq`, MojoProof/Import/TorchLean.lean:121), as
   in `gemv_torchLean`.

## The specifications' premises

The kernels' guards fix the premises of a specification:

- `gemv_kernel`: `ntid.x` a multiple of 32. Otherwise, when the block's size is not a multiple
  of 32 either, each block's last warp is partial: its lanes past the block are not threads, so a
  butterfly partner is missing and its operand is poison (`Grid.fire`); and the rows
  `(β · ntid.x + 32 w) / 32` of two warps of consecutive blocks can be equal (with
  `ntid.x = 48`, warp 1 of block 0 and warp 0 of block 1 both get row 1), so at `M ≥ 2` their
  lanes 0 store to the same cell, a race. The rows past `M` return at the guard (line 56)
  and the columns past `K` are skipped (line 95).
- `gevm_kernel`: `ntid.x = 1024` (the shared array has 1024 cells, and the transposition through
  it pairs warp `w` with lane `w`), `K` and `N` multiples of 32: its loop reads row `32 i + w` for
  every `i < ⌈K / 32⌉` and column `32 β + l` with no guard against `K` or `N`.
- Both: the output's block apart from the inputs' (the loads carry `!invariant.load` in
  `gemv_kernel`).

The value stored is the butterfly tree over the 32 lanes of each lane's strided loop sum, not
the sequential dot product of `TorchLean.Tensor.matVecLoop`: the specification is `warpDot`
(docs/proofs/warp-dot.md), with an error bound against the exact row (column) product:
`warpDot_error`, `warpDot_matVec` and `warpDot_vecMat`, and the contraction-off word
`warpDot_eq`. The float rule gemv's `GPUProof.Kernel.Sound` is stated against: gemv's word per row,
`groupDot 5`, meets the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)`
(`MojoProof.Tile.groupDot_holds`, docs/proofs/dot.md); the kernel theorem (`kernel_sound`, item 7)
is proved at every valid one-dimensional launch whose block's `x` size 32 divides and whose warps'
rows cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), with `M`, `K < 2 ^ 31` and
`M K < 2 ^ 61`, for every caller's memory closed for the arguments whose buffers hold the matrix
and the vector, and every input words that hold them, at the admission "address choice below
`2 ^ 60`".

## Scope

`exec_laneid`, `exec_alloca`, `Block.soundAt`, `SNode.eval_castAt`, `SNode.eval_bitcast`,
`bitcast_bits`, `castOk_iff`,
`SNode.eval_globalAt`, the cast, `getelementptr`, `load` and `store` cases of
`SState.stmt_sound` (with a `load` after a `store`, and the `insertvalue`, `extractelement`,
`insertelement` and two-index `getelementptr` cases), `Seg.sound`, `Thread.resume_at`,
`Thread.resume_regs`, `Seg.resume`, `Seg.resume_regs`, `Seg.through`, `Seg.lifetime`,
`Seg.lifetime_ptr`, `Piece.throughTo`, `Piece.through`, `RunsVia.of_fires`, `BackWith.enter`,
`ChainWith.enter`, `RunsVia.of_chain`, the value lemmas of `SNode.loadAfter`, and
`Piece.Wait.via_of`, `RunsVia.of_through_via`, `SVal.mapM_shfl`, `RunsVia.imp_head`,
`RunsVia.imp` and `RunsVia.pin` (MojoProof/Sym/WaitVia.lean), `nextWait`, `waitAt` and
`RunsVia.waitAt` (MojoProof/Sym/WaitAt.lean), `Piece.Wait.map_via_append`
(MojoProof/Sym/Canon.lean), `Mem.alloc_num_ne` (MojoProof/Sym/OblPieces.lean), and
`shflVal_mapM`, `withAttrs_keepsBits`, `Program.shfl_deliver` and its `bfly` and `idx` forms,
`shflSource_idx`, `zero_mem_warpLanes` and `warpLanes_full` (MojoProof/Sym/ShflDeliver.lean)
cover every program and launch; `deliver7` and `idx_row` (MojoProofTest/GemvShfl.lean) are
gemv_kernel's shuffles at every launch whose block has threads (`deliver7`: that 32 divides),
and `row_lane` every valid launch whose block's `x` size 32 divides; `Mem.Buffer.ne_slot`, the slot
lemmas, `Mem.SameOff` and its lemmas,
`Mem.not_freshOf` and `Mem.not_freshOf_lt` (MojoProof/Sym/Slot.lean), `Mem.SameOff.chain`,
`Mem.Buffer.of_store`, `Mem.Fits.of_store` and `RunsVia.final` (MojoProof/Sym/LaneFrame.lean,
`RunsVia.final` for every program), `EntryInv.off`,
`EntryInv.frame`, `slots_off` and `slotsAll_off` (MojoProofTest/GemvEntryRun.lean),
`EntryInv.keep`, `live_out` and `run_out` (MojoProofTest/GemvThread.lean) every memory,
`waits_range` every two waits of `%6` and five of `%78`; `entry`,
`GemvLoop.run`, `GemvLoopTail.to_ret` and `GemvThread.run` are gemv_kernel's thread at every
valid launch, thread, context and memory with their premises, the other lanes' deliveries among
them; `warp` (MojoProofTest/GemvWarpRun.lean) is gemv_kernel's warp at every valid launch whose
block size 32 divides, every warp, `M` and `K` within the bounds, row and memory with its premises
(`Lanes.Pre`), the partners' offers as the `addAt` chain `acc`, and `lane`, `shape` and `step7`
every warp; `offered_acc`, `partner_offered`, `offered_congr` and `word_rounds`
(MojoProofTest/GemvWarpWord.lean) are every warp with no premise, and `x_eq`, `partner_sums`,
`word_sums`, `warp_word`, `warp_holds`, `warp_row` and `word_warpDot_nanEq` every warp with
`Lanes.Pre`, `word_warpDot` and `warp_dot` also where no round's sum is a NaN; `grid_run`,
`grid_run_inv` and `grid_done` (MojoProofTest/GemvWarpRun.lean), `rows_of_loads` and `grid_rows`
(MojoProofTest/GemvWarpWord.lean) are gemv_kernel's grid at every valid one-dimensional launch
whose block's `x` size 32 divides, with their premises (`rows_of_loads` and `grid_rows` with the
warps' rows covering the matrix's rows); `racy_ev` and `kept_ev`
(MojoProofTest/GemvSound.lean) are every launch and trace of `Ev` events with their block
bounds, `mem0_trace`,
`ext_out` and `slotEv_ev` every memory, `lanes_ext`, `out_ext`, `lanes_events` and `out_events`
every warp with its premises, `ext_store` (MojoProofTest/GemvEntryRun.lean) and `ext_reads`
(MojoProofTest/GemvLoop.lean) every memory (with `Ext.of_trace`, `Ext.refl`, `Ext.mono` and
`Ext.chain`, MojoProof/Sym/SegTrace.lean, every property of events and memory), `two_ext` every
valuation of gemv_kernel's function, `Lanes.mem2_ext` and `Out.memE_ext`
(MojoProofTest/GemvWarpRun.lean) every warp with its premises, `grid_end`, `grid_sound`, `starts`
and `kernel_sound` every such launch with their premises (`starts` every launch), as is
`gemv_torchLean` (MojoProofTest/GemvTorch.lean), and `rows_holds` and `torchRows_of_rule` every
width, size, matrix, vector, input words and oracle numbers or grade; `GemvThread.mem_caller`
(MojoProofTest/GemvThread.lean) is gemv_kernel's caller premises on `GemvThread.mem` at every
size within the bounds, matrix and vector; the tests cover the seven
blocks named above of the two kernels, two blocks of the bfloat16 naive matrix product, five
one-statement blocks built on a block of `vector_addition` (MojoProofTest/SymCastOk.lean), three
hand-built blocks of `alloca`s (MojoProofTest/SymAlloca.lean), the segments of the two reductions
and two blocks of a layernorm kernel (MojoProofTest/SymSeg.lean), gemv_kernel's thread from its
start to its `ret` at lane 3 of one block of 32 threads, `M = 1`, `K = 4`, every premise with
`Grid.fire`'s two deliveries on the memory with every lane's slots (MojoProofTest/GemvThread.lean),
and gemv_kernel's warps from `Grid.start` to a done grid at one block of 32 threads and one of 64
with `M = 1`, and one block of 16 (the `poison` mutant), each with `K = 0`, and at one block of 32
with `M = 1`, `K = 4` and `K = 3` at one row and vector each (MojoProofTest/GemvWarp.lean; `tail78`,
`lane`, `lane43`, `warp78`, `warp43` and `one78` are for every launch whose start succeeds, every
arm and round count), and `warp` at one block of 32 threads, `M = 1`, `K = 4`, row 0 on `m3`
(MojoProofTest/GemvWarpRun.lean), and `word_warpDot_nanEq` there (MojoProofTest/GemvWarpWord.lean),
and `grid_sound` there from `starts`, every premise proved, and `row_race` at one block of
32 × 2 threads (MojoProofTest/GemvSound.lean), and `kernel_sound` and `gemv_torchLean` at one
block of 64 threads, `M = 2`, `K = 4`, on `GemvWarpRun.n3`, every premise proved (`sound64`,
MojoProofTest/GemvSound.lean, and `torch64`, MojoProofTest/GemvTorch.lean). gevm_kernel's
kernel theorem (`kernel_sound`, `gevm_torchLean`, MojoProofTest/GevmSound.lean) is for every
valid launch with 1024 threads a block, a one-dimensional grid and `N = 32 · L.grid .x`, and at
one block of 1024 threads, `N = K = 32`, on `GemvThread.mem`, every premise proved (`sound1024`,
`torch1024`); at `N < 32 · L.grid .x` the kernel stores past the output (no guard against
`N`, item 7 (c)). The item numbers are this file's own.
