---
id: layout-mma
title: the layout tensor-core tests, mma_layout_tc, matmul_naive and c_fragment_kernel (TorchLean.Tensor.matmul)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/test/gpu/layout/test_layout_mma.mojo:28
quote: "def mma_layout_tc["
lean: TorchLean.Tensor.matmul
corpus: tests/corpus/mma
tests: MojoProofTest.Corpus
upstream:
depends: mma, launch
level: L0
---

# The layout tensor-core tests

**The rule.** `mma_layout_tc` multiplies tiles with the tensor cores' `mma`, `matmul_naive`
is its one-thread-per-cell reference, and `c_fragment_kernel` writes an accumulator fragment.

**What is in the code.** 13 corpus files: 5 `mma_layout_tc`, 5 `matmul_naive`, 3
`c_fragment_kernel`. They import (MojoProofTest.Corpus runs every corpus row). The grid runs an
`mma` of a whole warp by its model (MojoProof/Sem/Grid.lean, `mmaRes`), with f16 or bf16 inputs
and binary32 accumulators, at the accumulation policy of the launch; for every such `mma` the step
gives each lane's result fragment (`MojoProof.Sem.Grid.fire_mma`, MojoProof/Sem/TensorCoreWarp.lean),
and tests/gpu/mma/record.txt records 20 launches of one `mma` (m16n8k16, bf16 inputs, binary32
accumulators) on one GPU, whose 2,560 result words are the model's at one policy (a conformance
test of that instruction, not a proof). An `mma` in a warp cut by its block of threads, other
formats and `ldmatrix` are unsupported. No theorem is about these 13 files' programs.

**Open.** Every level above L0.
