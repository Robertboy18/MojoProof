---
id: softmax
title: softmax_kernel, the row-wise softmax (TorchLean.Tensor.softmax)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/nn/softmax.mojo:539
quote: "def softmax_kernel["
lean: TorchLean.Tensor.softmax
corpus: none
tests: none
upstream: https://github.com/modular/modular/issues/7741
depends: warp-shuffles, maxnum-minnum, launch
level: L0
---

# Softmax

**The rule.** Each row becomes `exp(x - max) / sum(exp(x - max))`, with the maximum and the sum
taken over the row.

**Float bounds.** `MojoProof.Float.max_exact` (a tree of `maxnum` is exact),
`MojoProof.Float.expSum_error` and `MojoProof.Float.softmax_error`
(docs/proofs/float-reductions.md) bound the max-subtracted sum of correctly rounded exponentials
along any tree and each entry against `TorchLean.TransformerBlock.softmax`, which
`TorchLean.TransformerBlock.get2_softmax_forward` links to TorchLean's op table. They assume a
correctly rounded exponential and finite differences: an `exp` lowered to an approximate
instruction needs that instruction's contract, and `-inf` inputs are outside them.

**Open.** No corpus file yet, so every level above L0.
