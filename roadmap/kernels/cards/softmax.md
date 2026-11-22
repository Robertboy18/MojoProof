---
id: softmax
title: softmax_kernel, the row-wise softmax (TorchLean.Tensor.softmax)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/nn/softmax.mojo:539
quote: "def softmax_kernel["
lean: TorchLean.Tensor.softmax
corpus: none
tests: none
upstream:
depends: warp-shuffles, maxnum-minnum, launch
level: L0
---

# Softmax

**The rule.** Each row becomes `exp(x - max) / sum(exp(x - max))`, with the maximum and the sum
taken over the row.

**Open.** No corpus file yet, so every level above L0.
