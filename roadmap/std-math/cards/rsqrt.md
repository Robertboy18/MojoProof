---
id: rsqrt
title: `std.math.rsqrt` on float32 on the GPU is `llvm.nvvm.rsqrt.approx.ftz.f`
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/math/math.mojo:261
quote: "Performs elementwise reciprocal square root on a SIMD vector."
lean: MojoProof.Sem.rsqrtOk, MojoProof.Sem.rsqrt, MojoProof.Sem.rsqrtErr, MojoProof.Sem.rpow_le_rsqrtErr, MojoProof.Sem.rsqrtOk_of_rsqrt
corpus: tests/corpus/layernorm
tests: MojoProofTest.FloatRel, MojoProofTest.Eval
upstream:
depends: llvm-ir/intrinsic-rsqrtapprox
level: L1
---
# `std.math.rsqrt` on float32 on the GPU is `llvm.nvvm.rsqrt.approx.ftz.f`

## Rule

`rsqrt` (math.mojo:258) asserts a floating-point type (lines 273-275). It returns `1.0 / sqrt(x)` in the compile-time interpreter, the plugin's hook if one exists, and `1.0 / sqrt(x)` otherwise (lines 277-284). The CUDA plugin's `_rsqrt_nvvm` (Mojo/stdlib/std/_plugin/cuda/cuda_math.mojo:172-182) calls `llvm.nvvm.rsqrt.approx.ftz.f` per element for float32 and `llvm.nvvm.rsqrt.approx.d` for float64. The contract is PTX's for `rsqrt.approx.ftz.f32`. PTX ISA 9.5 gives a maximum relative error of 2^-22.9, a table of special inputs, and subnormal inputs and results flushed to sign-preserving zero. `MojoProof.Sem.rsqrtOk` states it with the error `MojoProof.Sem.rsqrtErr`, a rational at least 2^-22.9 (`MojoProof.Sem.rpow_le_rsqrtErr`), and `MojoProof.Sem.rsqrt` returns a word that meets it (`MojoProof.Sem.rsqrtOk_of_rsqrt`). docs/TRUST.md T10 records the trust in that contract.

## In scope

float32 on the GPU, as the corpus IR calls it (all 34 layer-norm files).

## Out of scope

float64 (`rsqrt.approx.d`), float16 and bfloat16 (which `_sqrt` widens to float32, cuda_math.mojo:166-167; whether `rsqrt` does is not checked here), and the CPU path `1.0 / sqrt(x)`. That the hook on line 280 resolves to `_rsqrt_nvvm` is read from the IR, which has the intrinsic call, not traced through the plugin table.

## Open

L2 needs a recorded GPU run against the bound. Proving that a kernel's result is within its error is the floats area's work.
