---
id: softmax
title: softmax_kernel, the row-wise softmax (TorchLean.Tensor.softmax)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/nn/softmax.mojo:539
quote: "def softmax_kernel["
lean: TorchLean.Tensor.softmax, TorchLean.TransformerBlock.softmax, MojoProof.Float.softmax_error, MojoProof.Float.maskSoftmax_error, MojoProof.Float.ex2Sum_error, MojoProof.Float.logSoftmax_error
corpus: none
tests: MojoProofTest.FloatStats, MojoProofTest.FloatEx2
upstream: https://github.com/modular/modular/issues/7741
depends: warp-shuffles, maxnum-minnum, ex2-approx, launch
level: L0
---

# Softmax

**The rule.** Each row becomes `exp(x - max) / sum(exp(x - max))`, with the maximum and the sum
taken over the row.

**Float bounds.** `MojoProof.Float.max_exact` (a tree of `maxnum` over finite inputs is exact),
`MojoProof.Float.expSum_error` and `MojoProof.Float.softmax_error`
(docs/proofs/float-reductions.md) bound the max-subtracted sum of correctly rounded exponentials
along any tree and each entry `e_j / s` against `TorchLean.TransformerBlock.softmax`, which
`TorchLean.TransformerBlock.get2_softmax_forward` links to TorchLean's op table;
`MojoProof.Float.maskSum_error` and `MojoProof.Float.maskSoftmax_error` allow masked inputs
`-inf` (the softmax over the kept indices); `MojoProof.Float.lse_error` and
`MojoProof.Float.logSoftmax_error` bound log-sum-exp and `(x_j - m) - log s` with FloatLib's
correctly rounded log. Mojo's float32 `exp` on a GPU is `ex2.approx.ftz.f32` of
`(x - m) * log2(e)` (Mojo/stdlib/std/math/math.mojo:550-552); under that instruction's contract
(`MojoProof.Float.Ex2Close`, from PTX's 2 ulp) `MojoProof.Float.ex2Sum_error` bounds the sum in
`expSum_error`'s form.

**Not proved.** The kernel's entry `e_j * (1 / s)` (softmax.mojo:693-698; the bounds above
divide once), an entry with the `ex2.approx` terms, the row maximum from `Scalar.MIN`, which is
`-inf` (softmax.mojo:656), the log-softmax variant `log(e_j * (1 / s))` with Mojo's `log`
(:701-702), and that a grid run computes these words.

**Open.** No corpus file yet, so every level above L0.
