---
id: naive-matmul
title: matmul_kernel_naive, one thread per output cell of C = A B (TorchLean.Tensor.matmul)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/matmul/gpu/__init__.mojo:253
quote: "def matmul_kernel_naive["
lean: TorchLean.Tensor.matmul, MojoProof.Sem.matmul_cell_real
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_*, tests/corpus/mgemm_nocontract
tests: MojoProofTest.Matmul, MojoProofTest.SymNaive, MojoProofTest.SymContract
upstream:
depends: launch, contract, binary-op-rounding
level: L0
---

# The naive matmul

**The rule.** The thread at output cell `(i, j)` inside the `m × n` result accumulates
`A[i, l] * B[l, j]` for `l` below `k`, in order, and writes the sum to `C[i, j]`.

**What is in the code.** The corpus has 13 specializations from the multistage GEMM test (10
float32, one bfloat16, one mixed float32/bfloat16, one float8 input) and the 10 float32 ones
built with contraction off (tests/corpus/mgemm_nocontract). All import but the float8 one,
refused at an inline asm conversion (tests/corpus/REFUSALS.tsv). The block checker accepts the
naive kernel's blocks, with `fmul contract` recorded (MojoProofTest.SymNaive,
MojoProofTest.SymContract). `MojoProof.Sem.matmul_cell_real` is the cell's value over the
reals for the evaluator's dot loop, a statement about the loop, not about the kernel.

**Not proved.** There is no kernel theorem: the kernel's loop is not yet covered by a
`mojo_kernel` command, so there is no L2 evidence, and no theorem for any one specialization.

**Open.** The kernel theorem (L2) for the float32 specializations, the cell against
`TorchLean.Tensor.matmul` (L3), an error bound with and without contraction (L4), and a GPU run
(L1).
