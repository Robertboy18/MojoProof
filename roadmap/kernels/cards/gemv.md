---
id: gemv
title: gemv_kernel, a matrix-vector product (TorchLean.Tensor.matVecLoop)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/gemv.mojo:178
quote: "def gemv_kernel["
lean: TorchLean.Tensor.matVecLoop, MojoProof.Sem.matVec_cell_real, MojoProof.Sem.warpDot_matVec, MojoProof.Sem.warpDot_vecMat, MojoProof.Sem.warpDot_eq, MojoProof.Sem.racy_tpose, MojoProof.Sem.warpDot_tpose, MojoProof.Sem.castV_split, MojoProof.Sym.exec_laneid, MojoProof.Sym.SNode.eval_bitcast, MojoProof.Sym.SNode.eval_laneid, MojoProof.Sym.Seg.sound, MojoProof.Sym.Seg.through, MojoProof.Sym.SNode.eval_globalAt, MojoProof.Tile.bflyRoundsAt_chain
corpus: tests/corpus/gemv
tests: MojoProofTest.Matmul, MojoProofTest.SymLane, MojoProofTest.SymCast, MojoProofTest.SymSeg, MojoProofTest.OblGevm, MojoProofTest.WarpDot, MojoProofTest.Bitcast, MojoProofTest.Transpose, MojoProofTest.GemvEntry, MojoProofTest.GemvEntryRun, MojoProofTest.OblGemv, MojoProofTest.GemvLoop, MojoProofTest.GemvLoopTail, MojoProofTest.GemvLoopBfly, MojoProofTest.TileBfly, MojoProofTest.GemvShfl, MojoProofTest.GemvThread, MojoProofTest.GemvWarpRun, MojoProofTest.GemvWarpWord, MojoProofTest.GemvSound, MojoProofTest.GemvTorch, MojoProofTest.GevmWarp1, MojoProofTest.GevmSound
upstream:
depends: launch, binary-op-rounding
level: L0
---

# gemv

**The rule.** Each output element `y[i]` is the dot product of row `i` of the matrix with the
vector.

**What is in the code.** Two float32 specializations in tests/corpus/gemv/, `gemv_kernel` and
`gevm_kernel` (compiled from tests/corpus/gemv/gemv_f32.mojo), are imported. The block checker
takes `gevm_kernel`'s entry block, with its lane number (`llvm.nvvm.read.ptx.sreg.laneid`,
`MojoProof.Sym.exec_laneid`), and both loops (MojoProofTest/SymLane.lean: `gevm_entry`,
`loops_contract`). mojo_obl proves `gevm_kernel`'s entry block and its edge into the loop at every
thread of every valid launch with `ntid.x = 1024`, the entry's column, output cell and trip count
`⌈K / 32⌉`, and the loop's rounds for every `K` divisible by 32 (MojoProofTest/OblGevm.lean:
`entry_edge`, `entry_regs`, `rounds`; the lane number by `MojoProof.Sym.SNode.eval_laneid`). The
checker refuses `gemv_kernel`'s entry block at an `alloca [2 x ptr]` (`gemv_entry`) and takes it
from statement 3, after the three `alloca`s, to its branch (`gemv_segs`). Its summary
of each warp reduction stops at the first collective call (`reductions_refused`), and the
reductions are segments that end at their collective calls (`MojoProof.Sym.summarizeTo`; a
thread's steps over a segment reach the call's wait, `MojoProof.Sym.Seg.sound`, for every
program): `gemv_kernel`'s `%78` is six segments, five of them ending at its shuffles, and
`gevm_kernel`'s `%59` seven, ending at its barrier and its five shuffles, with the
`getelementptr`s on its shared-memory global (`MojoProof.Sym.SNode.eval_globalAt`)
(MojoProofTest/SymSeg.lean: `gemv_segments`, `gevm_segments`). A thread runs a
block's segments in a row, given the values its collectives deliver
(`MojoProof.Sym.Seg.through`; `gevm_through` at `gevm_kernel`'s `%59`). A thread of `gemv_kernel` runs from pc 0 of `%6` to statement 41, with `%6`'s two deliveries as premises (MojoProofTest/GemvEntryRun.lean: `entry`), and from statement 41 through the loop at every `K` to `%78`, with `%79` the lane's strided `dotLoop` of the row (MojoProofTest/GemvLoop.lean: `run`), and with the shuffles' deliveries as premises to `ret` (MojoProofTest/GemvLoopTail.lean: `thread`, `to_ret`); lane 0's stored word is the semantics' rounds given the deliveries (MojoProofTest/GemvLoopBfly.lean: `total_eq`, `stored_holds`); every lane's word in the same form when each delivery is the partner's offered value (`total_chain`, through `MojoProof.Tile.bflyRoundsAt_chain`). A shuffle delivers its source lane's
offered value at every mode, offset and clamp whose source is a lane of the warp
(`MojoProof.LLVM.Program.shfl_deliver`; gemv_kernel's seven shuffles, MojoProofTest/GemvShfl.lean:
`deliver7`). For every valid launch whose block size 32 divides, the 32 lanes of a warp run
from their start to `ret` at every `K` through their seven shuffles, each delivering the other
lanes' offered values, and row `r`'s stored word is lane 0's `total` of its strided sum and its
partners' offers (MojoProofTest/GemvWarpRun.lean: `warp`; its premises at one block of 32
threads, `M = 1`, `K = 4`, `w0_pre`). Lane 0's word is the five butterfly rounds over the lanes'
strided sums, and row `r`'s `warpDot` up to NaNs (MojoProofTest/GemvWarpWord.lean: `warp_word`,
`word_warpDot_nanEq`, `warp_dot`). docs/proofs/gemv.md lists, block
by block, what the checker needs and the order of the work.

`MojoProof.Sem.matVec_cell_real` is one output element's value over the reals for the
evaluator's dot loop (tested in MojoProofTest.Matmul); it is about the loop, not about this
kernel. `MojoProof.Sem.warpDot` is the kernels' order, the butterfly over the 32 strided loops;
for every IEEE format (`fmt.isIEEE = true`), length and oracle its finite results are within
the error of `GPUProof.laneGrade (.ieee fmt) 32 5 ⌈n / 32⌉ n` (grades `⟨0, 0⟩`) of TorchLean's real entries (`MojoProof.Sem.warpDot_matVec`, `MojoProof.Sem.warpDot_vecMat`), and with the
contraction off it is FloatLib's reduction along the butterfly tree up to NaNs
(`MojoProof.Sem.warpDot_eq`) (docs/proofs/warp-dot.md). So with the contraction off a kernel's
word is not the sequential fold's: at 40 binary32 pairs the two differ (MojoProofTest/WarpDot.lean
`vals40`). `gevm_kernel`'s transposition through shared memory has one owner per cell before the
barrier (`MojoProof.Sem.racy_tpose`; on a run `MojoProof.Sem.Grid.sound_cells`), and warp `w`
then reduces column `32 β + w`'s strided sums
in `warpDot`'s order (`MojoProof.Sem.warpDot_tpose`), for every launch with `ntid.x = 1024`. gemv_kernel's
done grid holds each row's `warpDot` up to NaNs at one-dimensional launches whose block's `x`
size 32 divides and whose row count is at least `M` (MojoProofTest/GemvWarpWord.lean:
`grid_rows`). gevm_kernel's done grid holds each column's `warpDot` up to NaNs at
one-dimensional launches with 1024 threads per block in `x`, `N = 32 · L.grid .x` columns and
`32 ∣ K` (MojoProofTest/GevmWarp1.lean: `grid`).

**Open.** L1: no tracked record of a GPU run of either specialization. Above it, the block
checker takes `gemv_kernel`'s entry block whole with its `alloca` flag (MojoProofTest/SymSeg.lean:
`gemv_segs_alloca`), whose run at a free thread is composed with the loop's into one thread from
its start to its `ret` with the other lanes' deliveries as premises (MojoProofTest/GemvThread.lean:
`run`), the 32 lanes of one warp are joined (MojoProofTest/GemvWarpRun.lean: `warp`), and at every
one-dimensional launch the warps from `Grid.start` form one canonical run to a done grid
(MojoProofTest/GemvWarpRun.lean: `grid_run`, `grid_done`). At those launches whose block's `x`
size 32 divides and whose warps' rows cover the matrix's rows, the grid is sound
(MojoProofTest/GemvSound.lean: `grid_sound`), and gemv_kernel's `GPUProof.Kernel.Sound` holds
against `GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` through Theorem 0
(`kernel_sound`) and against TorchLean's contraction `.matVec` (MojoProofTest/GemvTorch.lean:
`gemv_torchLean`), for this one program, hand-proved in tests, not by `mojo_kernel`. Launches
with a `y` or `z` size above 1 are not proved: two warps can share a row there, and two stores
of their lanes 0 at it race (`row_race`, the two stores' events, not a run) (docs/proofs/gemv.md
items 6 and 7). At gevm's launches above, gevm_kernel's `GPUProof.Kernel.Sound` holds against
`GPUProof.Spec.vecMat (GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉)`, for the admission that
each block of threads' shared array lies below `2 ^ 32` (MojoProofTest/GevmSound.lean:
`kernel_sound`), and against TorchLean's real vector-matrix product (`gevm_torchLean`), for this
one program, hand-proved in tests, not by `mojo_kernel`; its premises hold at one block of 1024
threads (`sound1024`, `torch1024`).
