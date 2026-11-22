---
id: min
title: `std.math.min` on SIMD values: `llvm.smin` on signed integers
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/math/math.mojo:3335
quote: "Gets the elementwise minimum of x and y."
lean: MojoProof.Sem.intMinMax
corpus: tests/corpus/layernorm, tests/corpus/mgemm/g_multistage_gemm_split_k_kernel_*.ll
tests: MojoProofTest.Rule
upstream:
depends: llvm-ir/intrinsic-minmax
level: L1
---
# `std.math.min` on SIMD values: `llvm.smin` on signed integers

## Rule

`min` on two SIMD values (math.mojo:3334) asserts a numeric or boolean type (lines 3354-3356) and is the MLIR operation `pop.min` (line 3358). The corpus IR has `llvm.smin.i64` (the 34 layer-norm files and the 3 split-K GEMM files) and no `llvm.minnum`. The contract on integers is exact: the smaller of the two as signed integers (`MojoProof.Sem.intMinMax`).

## In scope

`i64` `smin`, as the corpus IR calls it.

## Out of scope

Float `min` (`llvm.minnum`), which the corpus does not call. As for `max`, which source call produced each `smin` is not traced, since the lowering is the compiler's.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
