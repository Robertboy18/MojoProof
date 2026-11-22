---
id: max
title: `std.math.max` on SIMD values: `llvm.maxnum` on floats, `llvm.smax` on signed integers
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/math/math.mojo:3281
quote: "Performs elementwise maximum of x and y."
lean: MojoProof.Sem.maxnum, MojoProof.Sem.intMinMax, MojoProof.Sem.maxnum_of_not_nan, MojoProof.Sem.maxnum_nanEq
corpus: tests/corpus/layernorm, tests/corpus/mgemm_nocontract
tests: MojoProofTest.Eval, MojoProofTest.SymSelect, MojoProofTest.Rule
upstream:
depends: llvm-ir/intrinsic-fminmax, llvm-ir/intrinsic-minmax
level: L1
---
# `std.math.max` on SIMD values: `llvm.maxnum` on floats, `llvm.smax` on signed integers

## Rule

`max` on two SIMD values (math.mojo:3280) asserts a numeric or boolean type (lines 3300-3302) and is the MLIR operation `pop.max` (line 3304). The corpus IR has `llvm.maxnum` on float32 scalars and vectors (the 34 layer-norm files) and `llvm.smax.i64` (the layer-norm files, the 10 GEMM files without contraction and 35 of the 49 GEMM files). The contract on floats is LangRef's for `llvm.maxnum`, as `MojoProof.Sem.maxnum` states it: IEEE 754-2019 `maximumNumber` of the operands, except that when an operand is a signaling NaN the result may instead be a NaN. That choice and the bits of any NaN are the oracle's (docs/TRUST.md T7). On integers it is exact (`MojoProof.Sem.intMinMax`).

## In scope

float32 `maxnum` and `i64` `smax`, as the corpus IR calls them.

## Out of scope

Which source call produced each intrinsic call. `pop.max` is lowered by the compiler, which we cannot see, and the IR does not say whether the call was `std.math.max` or another `max`. Boolean and unsigned `max`, and the variadic overload (math.mojo:3308).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
