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

**Open.** No corpus file yet, so every level above L0.
