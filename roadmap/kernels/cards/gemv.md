---
id: gemv
title: gemv_kernel, a matrix-vector product (TorchLean.Tensor.matVecLoop)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/gemv.mojo:178
quote: "def gemv_kernel["
lean: TorchLean.Tensor.matVecLoop, MojoProof.Sem.matVec_cell_real, MojoProof.Sem.warpDot_matVec, MojoProof.Sem.warpDot_vecMat, MojoProof.Sem.warpDot_eq, MojoProof.Sem.racy_tpose, MojoProof.Sem.warpDot_tpose, MojoProof.Sem.castV_split, MojoProof.Sym.exec_laneid, MojoProof.Sym.SNode.eval_bitcast, MojoProof.Sym.SNode.eval_laneid, MojoProof.Sym.Seg.sound, MojoProof.Sym.Seg.through, MojoProof.Sym.SNode.eval_globalAt
corpus: tests/corpus/gemv
tests: MojoProofTest.Matmul, MojoProofTest.SymLane, MojoProofTest.SymCast, MojoProofTest.SymSeg, MojoProofTest.OblGevm, MojoProofTest.WarpDot, MojoProofTest.Bitcast, MojoProofTest.Transpose
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
checker refuses `gemv_kernel`'s entry block at an `alloca [2 x ptr]` (`gemv_entry`). Its summary
of each warp reduction stops at the first collective call (`reductions_refused`), and the
reductions are segments that end at their collective calls (`MojoProof.Sym.summarizeTo`; a
thread's steps over a segment reach the call's wait, `MojoProof.Sym.Seg.sound`, for every
program): `gemv_kernel`'s `%78` is six segments, five of them ending at its shuffles, and
`gevm_kernel`'s `%59` seven, ending at its barrier and its five shuffles, with the
`getelementptr`s on its shared-memory global (`MojoProof.Sym.SNode.eval_globalAt`)
(MojoProofTest/SymSeg.lean: `gemv_segments`, `gevm_segments`). A thread runs a
block's segments in a row, given the values its collectives deliver
(`MojoProof.Sym.Seg.through`; `gevm_through` at `gevm_kernel`'s `%59`). docs/proofs/gemv.md lists, block
by block, what the checker needs and the order of the work.

`MojoProof.Sem.matVec_cell_real` is one output element's value over the reals for the
evaluator's dot loop (tested in MojoProofTest.Matmul); it is about the loop, not about this
kernel. `MojoProof.Sem.warpDot` is the kernels' order, the butterfly over the 32 strided loops;
for every IEEE format (`fmt.isIEEE = true`), length and oracle its finite results are within
`warpBound` of TorchLean's real entries (`MojoProof.Sem.warpDot_matVec`, `MojoProof.Sem.warpDot_vecMat`), and with the
contraction off it is FloatLib's reduction along the butterfly tree up to NaNs
(`MojoProof.Sem.warpDot_eq`) (docs/proofs/warp-dot.md). So with the contraction off a kernel's
word is not the sequential fold's: at 40 binary32 pairs the two differ (MojoProofTest/WarpDot.lean
`vals40`). `gevm_kernel`'s transposition through shared memory has one owner per cell before the
barrier (`MojoProof.Sem.racy_tpose`; on a run `MojoProof.Sem.Grid.sound_cells`), and warp `w`
then reduces column `32 β + w`'s strided sums
in `warpDot`'s order (`MojoProof.Sem.warpDot_tpose`), for every launch with `ntid.x = 1024`. That
a grid run of either kernel computes `warpDot` is not proved.

**Open.** L1: no tracked record of a GPU run of either specialization. Above it, the block
checker's fragment must cover `gemv_kernel`'s entry block (the stack round trip), and both
reductions need a schedule through their collective calls (and for `gevm_kernel` the race
freedom across its barrier in a grid run) before a kernel theorem can (docs/proofs/gemv.md).
