---
id: gemv
title: gemv_kernel, a matrix-vector product (TorchLean.Tensor.matVecLoop)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/gemv.mojo:178
quote: "def gemv_kernel["
lean: TorchLean.Tensor.matVecLoop, MojoProof.Sem.matVec_cell_real
corpus: tests/corpus/gemv
tests: MojoProofTest.Matmul
upstream:
depends: launch, binary-op-rounding
level: L0
---

# gemv

**The rule.** Each output element `y[i]` is the dot product of row `i` of the matrix with the
vector.

**What is in the code.** Two float32 specializations in tests/corpus/gemv/, `gemv_kernel` and
`gevm_kernel` (compiled from tests/corpus/gemv/gemv_f32.mojo), are imported. The block checker
refuses both entry blocks: `gemv_kernel` at an `alloca [2 x ptr]`, `gevm_kernel` at the lane id
(`llvm.nvvm.read.ptx.sreg.laneid`), and their warp reductions (shuffles) and `gevm_kernel`'s
shared-memory reduction are outside its fragment too. `MojoProof.Sem.matVec_cell_real` is one output
element's value over the reals for the evaluator's dot loop (tested in MojoProofTest.Matmul); it is
about the loop, not about this kernel.

**Open.** L1: no tracked record of a GPU run of either specialization. Above it, the block
checker's fragment must cover the entry blocks and the reductions before a kernel theorem can.
