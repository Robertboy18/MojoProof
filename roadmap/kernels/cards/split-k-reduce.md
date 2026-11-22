---
id: split-k-reduce
title: matmul split-k reduce, the sum of the partial products of a split GEMM (TorchLean.Tensor.sum)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/matmul/gpu/__init__.mojo:2160
quote: "def split_k_reduce("
lean: TorchLean.Tensor.sum
corpus: tests/corpus/mgemm/g_matmul_split_k_reduce_*
tests: MojoProofTest.Corpus
upstream:
depends: launch, binary-op-rounding
level: L0
---

# The split-k reduce

**The rule.** Each output cell is the sum, over the `k` splits, of the splits' partial results
at that cell.

**What is in the code.** 12 corpus specializations (2 splits, widths 4, 8 and 16). The 8 at
widths 4 and 8 import; the 4 at width 16 are refused at an inline asm float8 conversion
(tests/corpus/REFUSALS.tsv).

**Open.** Every level above L0.
