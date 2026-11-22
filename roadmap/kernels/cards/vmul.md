---
id: vmul
title: vector_multiply, the elementwise product of two float32 vectors (TorchLean.Tensor.mul)
kind: kernel
ref: repo:tests/corpus/vmul/vector_multiply.mojo:86
quote: "out_tensor[global_tid] = lhs_tensor[global_tid] * rhs_tensor[global_tid]"
lean: TorchLean.Tensor.mul, MojoProof.Kernels.vmul.bytes, MojoProof.Kernels.vmul.correct
corpus: tests/corpus/vmul
tests: MojoProofTest.Kernel.vmul_real, MojoProofTest.Vmul
upstream:
depends: launch, binary-op-rounding, deliver
level: L0
evidence: L2: MojoProof.Kernels.vmul.correct; L3: MojoProofTest.Kernel.vmul_real; L4: MojoProofTest.Kernel.vmul_real
---

# vector_multiply

**The rule.** Thread `k`, for `k` below `n`, writes `lhs[k] * rhs[k]` (binary32
multiplication) to `out[k]`, and nothing else. The source is this repository's copy of
vector_addition with the sum made a product (tests/corpus/vmul/vector_multiply.mojo).

**What is proved, for one kernel.** As for vadd: `MojoProof.Kernels.vmul.correct` is the kernel
theorem for every valid one-dimensional launch and memory of `Map2.Pre`, with output cell `k`
holding `MojoProof.Kernels.vmul.bytes`; `MojoProofTest.Kernel.vmul_real` gives TorchLean's
`x * y` at `k` for a finite output and its real value as the real product rounded to binary32.

**Out of scope.** Other element types, launch shapes, and NaN payload bits.

**Open.** L1: no tracked record of a GPU run.
