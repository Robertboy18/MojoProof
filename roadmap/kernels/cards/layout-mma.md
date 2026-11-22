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
`c_fragment_kernel`. They import (MojoProofTest.Corpus runs every corpus row). The evaluator has
no grid semantics for `mma` yet.

**Open.** Every level above L0.
