---
id: rms-norm
title: rms_norm_gpu, root mean square normalization (TorchLean.Tensor.rmsNorm)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/nn/normalization.mojo:833
quote: "def rms_norm_gpu["
lean: TorchLean.Tensor.rmsNorm
corpus: none
tests: none
upstream:
depends: warp-shuffles, rsqrt-approx, launch
level: L0
---

# RMS norm

**The rule.** Each row is divided by the square root of the mean of its squares plus `eps`,
then scaled by `gamma`.

**Not proved.** No float bound: TorchLean's `TorchLean.Tensor.rmsNorm` is defined over the reals
but has no closed form there, and the mean of squares with the `rsqrt.approx` contract is not
stated (docs/proofs/float-reductions.md, "Not proved").

**Open.** No corpus file yet, so every level above L0.
