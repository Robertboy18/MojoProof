---
id: layernorm
title: layer_norm_gpu, the 34 row-wise layer norm specializations (TorchLean.Tensor.layerNorm)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/test/gpu/nn/test_layer_norm.mojo:27
quote: "def run_layer_norm_gpu["
lean: TorchLean.Tensor.layerNorm, TorchLean.TransformerBlock.layerNorm, MojoProof.Float.welford, MojoProof.Float.welford_error, MojoProof.Float.wvar_error, MojoProof.Float.lnorm, MojoProof.Float.lnorm_error
corpus: tests/corpus/layernorm
tests: MojoProofTest.Corpus, MojoProofTest.SymSeg, MojoProofTest.FloatWelford, MojoProofTest.FloatNorm
upstream:
depends: warp-shuffles, shared-memory, barriers, rsqrt-approx, launch
level: L0
---

# Layer norm

**The rule.** Each row is normalized to mean zero and variance one, then scaled and shifted:
`(x - mean) * rsqrt(var + eps) * gamma + beta`.

**What is in the code.** The corpus has 34 specializations from the test (block and warp
variants, block sizes and widths). They import (MojoProofTest.Corpus runs every corpus row). All 34
call warp shuffles and `rsqrt.approx` (the floats area), and 25 call the block barrier.

**Not proved.** No kernel theorem for any specialization: the block checker refuses barrier,
shuffle and `rsqrt.approx` calls (MojoProof/Sym/Rules.lean); it takes a `load` or `store` on the
shared-memory global (`MojoProof.Sym.SNode.eval_globalAt`; MojoProofTest/SymSeg.lean: `ln_store`,
`ln_load`), and refuses a `load` after a `store`.

**Float bounds.** The corpus kernels merge Welford statistics (count, mean and sum of squared
deviations) across lanes by butterfly shuffles
(ln_rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a.nvptx.ll:250-268). Along any reduction tree, in
every IEEE format, `MojoProof.Float.welford_error`, `MojoProof.Float.wmean_error` and
`MojoProof.Float.wvar_error` (docs/proofs/float-welford.md) bound the merged words against the
inputs' mean and `TorchLean.var`. In binary32, with the `rsqrt.approx` contract,
`MojoProof.Float.lnorm_error` (docs/proofs/float-norm.md) bounds each output
`((x - mean) * r) * gamma + beta`, fused or not, against `TorchLean.TransformerBlock.layerNorm`,
which `TorchLean.TransformerBlock.get2_layerNorm_forward` links to TorchLean's op table. The
two-pass `MojoProof.Float.mean_error` and `MojoProof.Float.var_error`
(docs/proofs/float-reductions.md) bound another algorithm. That a grid run computes these words
is not proved.

**Open.** Every level above L0, first for one specialization, then for the family.
