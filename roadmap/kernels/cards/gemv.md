---
id: gemv
title: gemv_kernel, a matrix-vector product (TorchLean.Tensor.matVecLoop)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/gemv.mojo:178
quote: "def gemv_kernel["
lean: TorchLean.Tensor.matVecLoop, MojoProof.Sem.matVec_cell_real
corpus: none
tests: MojoProofTest.Matmul
upstream:
depends: launch, binary-op-rounding
level: L0
---

# gemv

**The rule.** Each output element `y[i]` is the dot product of row `i` of the matrix with the
vector.

**What is in the code.** No corpus file. `MojoProof.Sem.matVec_cell_real` is one output
element's value over the reals for the evaluator's dot loop (tested in MojoProofTest.Matmul);
it is about the loop, not about this kernel.

**Open.** The kernel's specializations in the corpus (L0 to L1), and every level above.
