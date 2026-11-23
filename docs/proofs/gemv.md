# The gemv kernels in the block checker: what each block needs (a plan)

Lean: proved, for every program, the lane number in the block checker (`exec_laneid`,
MojoProof/Sym/Block.lean; the node `SNode.call`, MojoProof/Sym/Term.lean; the case of
`SState.stmt`, MojoProof/Sym/Checker.lean), the casts `castV` evaluates (`castOk`, which is
`castV`'s cases by `castOk_iff`, MojoProof/Sym/Block.lean; the node `SNode.castAt` and its value
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
operand (`SNode.globalAt` and its value `SNode.eval_globalAt`, MojoProof/Sym/Term.lean, item 5).
Everything after the section "What the checker takes" is a plan, not a proof, but for items 1 to
3 and item 5's node:
the constructs each block of the two kernels uses that the checker refuses, the summaries that
would take them, and the order of the work. No theorem about a run of either kernel is proved.

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
| `gemv_kernel` `%6` | 48 | refused at statement 0, `alloca [2 x ptr]` (`gemv_entry`) |
| `gemv_kernel` `%43`, `%44`, `%54`, `%58`, `%59`, `%60`, `%75`, `%76`, `%100` to `%103` | | in the fragment |
| `gemv_kernel` `%70` | 4 | `fmul contract`: in the fragment of `coversC` (`loops_contract`) |
| `gemv_kernel` `%78` | 21 | whole: refused at statement 2, the first `shfl.sync.bfly` (`reductions_refused`, `gemv_shfl`); as six segments ending at the shuffles (item 3): all in the fragment (`gemv_segments`) |
| `gevm_kernel` `%6` | 32 | in the fragment, the lane number at statement 5 (`gevm_entry`) |
| `gevm_kernel` `%39`, `%43`, `%44`, `%97` to `%99` | | in the fragment |
| `gevm_kernel` `%45` | 13 | `fmul contract`: in the fragment of `coversC` (`loops_contract`) |
| `gevm_kernel` `%59` | 39 | whole: refused at statement 6, the barrier (`reductions_refused`); as seven segments ending at the barrier and the shuffles (item 3): all in the fragment, the first two with the shared global's pointer (item 5, `gevm_segments`, `gevm_after_barrier`) |

So both loops, every segment of the reductions and every block after them are in the fragment;
what is left is `gemv_kernel`'s entry block and the schedule through the reductions' collectives
(item 4).

## The constructs, and the summaries that would take them

1. **The lane number** (done). `llvm.nvvm.read.ptx.sreg.laneid`, with no arguments and no
   fast-math flags, before the block's first store: the node `SNode.call lbl pc`, whose value is
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
   `ptrtoint`, which reads the addresses, is taken before the block's first store only. Done
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
   resumed frame at `p1 + 1`, by `Seg.sound` and `Thread.resume_at`). `gemv_kernel`'s `%6`
   would be three segments once item 6 takes its stack round trip.

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
   reachable by `Grid.Step`: `Grid.runAll_reach`, `Grid.fireAll_reach`). Proposed: `Seq.toWait`
   (threads in turn to a wait) and its fire, with the values from `shflSource`: lane 0 for `idx`
   with lane operand 0 and clamp 31, `l ^^^ m` for `bfly` (`shflSource_bfly`,
   MojoProof/Sem/Bfly.lean). The five rounds' values are then `bflyRounds` of the lanes' sums,
   whose tree, depth and error bound are proved (`eval_bflyTree`, `bfly_warp_error`).
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
   `32 l + w = tpose 32 (32 w + l)` (`Launch.tpose_env`), after it thread `t` reads cell `t`. On a
   run the pattern, for every cell map injective on a block of threads, is `Grid.sound_cells`
   (docs/proofs/barrier-owned.md, "On a run"), with the instance `sound1024` at `tpose 32` on
   every valid launch with `ntid.x = 1024` (MojoProofTest/Transpose.lean). That the kernel's
   trace meets its premises is left.
6. **The stack round trip** (`gemv_kernel`'s `%6`, lines 8-10 and 27-48), the largest item:
   - `alloca`: a node for the new block's pointer and an effect that allocates it, with the
     obligation that its number is fresh (`Mem.fresh` of the thread and step); the frame's
     `allocas` grows, so `Ends` and the path theorems need the frame's `allocas` to be the
     summary's allocations followed by the entry's (today they assume no `alloca` blocks:
     `Runs.of_ret`), the old statements their corollaries when a path allocates nothing;
   - `lifetime.start` and `lifetime.end` on a block the thread owns: done as the end of a
     segment (`summarizeLife`, `Seg.lifetime`), the next segment starting after the marker on
     the memory `Mem.setLive` makes;
   - `insertvalue` into `undef` (lines 34-35), `insertelement` into `undef` (lines 41, 45) and
     `extractelement` (lines 23-24): nodes over `insertV`, `insertE`, `extractE`, with an `undef`
     operand (`fill .undef t`, every element replaced before use);
   - `getelementptr` with two indices (line 38) and loads after stores (lines 39-44). The load
     node that carries the effects before it is done: `SNode.loadAfter` (MojoProof/Sym/Term.lean),
     which the checker makes of a `load` after the block's first `store` (on a global, on its
     `SNode.globalAt` node), with its case of `SState.stmt_sound`; its value one effect at a time
     (MojoProof/Sym/LoadAfter.lean, for every valuation): after a `store` at a pointer of the
     same value, type, space and alignment, the stored value's decoding
     (`SNode.eval_loadAfter_store`, by `Mem.load_store`); after a `store` apart from it, its value
     without the `store` (`SNode.eval_loadAfter_apart`, by `Mem.load_store_apart`); a `load`
     effect leaves it (`SNode.eval_loadAfter_log`). Tests at layernorm's `%453`
     (MojoProofTest/SymSeg.lean): `ln_after`, `ln_twin`, `ln_apart`, `ln_reload`. Left: the
     two-index `getelementptr`, the codec form for the `i32` slots (`Mem.load_store_codec`,
     MojoProof/Sem/Confluence.lean), and an element lemma for the `[2 x ptr]` stored whole (line
     37) and read one pointer at a time.
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
   run in a row on one thread (`Seg.through`). Then the schedule (item 4). With items 2 to 4, `%78`
   of `gemv_kernel` is covered, and with item 5 `%59` of `gevm_kernel`, so `gevm_kernel` has every
   block covered before `gemv_kernel` does (whose entry block needs item 6): it is the first kernel
   to prove.
4. Globals (item 5): done; the ownership across the barrier is left (`gevm_kernel`), and a
   `load` whose pointer operand is a global, after the segment's first `store`, is still refused.
5. The obligations of `gevm_kernel`'s `%6` and its loop by mojo_obl, at every launch with
   `ntid.x = 1024`: done (MojoProofTest/OblGevm.lean); for `K` not divisible by 32 the last round
   reads past `x` and `B` (`rounds_open`).
6. The stack round trip (item 6): `gemv_kernel`'s entry block. The loads after stores are done
   (`SNode.loadAfter`, its value lemmas in MojoProof/Sym/LoadAfter.lean), and a lifetime call
   ends a segment (`Seg.lifetime`); the `alloca`, the vector and aggregate nodes and the
   two-index `getelementptr` are left.
7. The kernel theorems (item 7), first `gevm_kernel`'s.

## The specifications' premises

The kernels' guards fix the premises of a specification:

- `gemv_kernel`: `ntid.x` a multiple of 32. Otherwise each block's last warp is partial: its
  lanes past the block are not threads, so a butterfly partner is missing and its operand is
  poison (`Grid.fire`); and the rows `(β · ntid.x + 32 w) / 32` of two warps of consecutive blocks
  can be equal (with `ntid.x = 48`, warp 1 of block 0 and warp 0 of block 1 both get row 1), so
  their lanes 0 store to the same cell, a race. The rows past `M` return at the guard (line 56)
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
`warpDot_eq`.

## Scope

`exec_laneid`, `SNode.eval_castAt`, `SNode.eval_bitcast`, `bitcast_bits`, `castOk_iff`,
`SNode.eval_globalAt`, the cast, `getelementptr`, `load` and `store` cases of
`SState.stmt_sound` (with a `load` after a `store`), `Seg.sound`, `Thread.resume_at`, `Seg.resume`,
`Seg.through`, `Seg.lifetime`, `Seg.lifetime_ptr` and the value lemmas of `SNode.loadAfter`
cover every program; the
tests cover the six blocks named above of the two kernels, two blocks of the bfloat16 naive
matrix product, five one-statement blocks built on a block of `vector_addition`
(MojoProofTest/SymCastOk.lean), the segments of the two reductions and two blocks of a layernorm
kernel (MojoProofTest/SymSeg.lean). That gevm_kernel's trace meets
`racy_tpose`'s (on a run, `Grid.sound_cells`'s) premises (item 5) and items 4, 6 and 7 are a
plan: no statement of them is proved, and the item numbers are this file's own.
