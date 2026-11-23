---
id: layernorm
title: layer_norm_gpu, the 34 row-wise layer norm specializations (TorchLean.Tensor.layerNorm)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/test/gpu/nn/test_layer_norm.mojo:27
quote: "def run_layer_norm_gpu["
lean: TorchLean.Tensor.layerNorm
corpus: tests/corpus/layernorm
tests: MojoProofTest.Corpus, MojoProofTest.SymSeg
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

**Float bounds.** For the two-pass mean and variance along any two trees, in every IEEE format,
`MojoProof.Float.mean_error` and `MojoProof.Float.var_error` (docs/proofs/float-reductions.md)
bound the words against the exact mean and `TorchLean.var`, the statistics of
`TorchLean.TransformerBlock.layerNorm`, which `TorchLean.TransformerBlock.get2_layerNorm_forward`
links to TorchLean's op table. They are not the corpus kernels' bound: those merge Welford
statistics (mean, sum of squared deviations and the count) across lanes by butterfly shuffles.

**Open.** Every level above L0, first for one specialization, then for the family.
