---
id: rms-norm
title: rms_norm_gpu, root mean square normalization (TorchLean.Tensor.rmsNorm)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/nn/normalization.mojo:833
quote: "def rms_norm_gpu["
lean: TorchLean.Tensor.rmsNorm, MojoProof.Float.msq_error, MojoProof.Float.rmsnorm, MojoProof.Float.rmsnorm_error
corpus: none
tests: MojoProofTest.FloatNorm
upstream:
depends: warp-shuffles, rsqrt-approx, launch
level: L0
---

# RMS norm

**The rule.** Each row is divided by the square root of the mean of its squares plus `eps`,
then scaled by `gamma`.

**Float bounds.** In binary32, along any reduction tree, with the `rsqrt.approx` contract,
`MojoProof.Float.rmsnorm_error` (docs/proofs/float-norm.md) bounds each output `(x * r) * gamma`
against the real RMS norm `x / sqrt(mean(x^2) + eps) * gamma`, with the mean of squares of
`MojoProof.Float.msq_error` (every IEEE format). TorchLean's `TorchLean.Tensor.rmsNorm` divides
each fiber by its largest magnitude first and has no closed form over the reals, so the bound is
against the value its docstring states, written out.

**Not proved.** Mojo's `weight_offset` added to `gamma`
(max/kernels/src/nn/normalization.mojo:340, :344), the casts of a narrower dtype, squares fused
into the additions, and that a grid run computes these words.

**Open.** No corpus file yet, so every level above L0.
