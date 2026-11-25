---
id: upcast
title: `upcast` divides strides and shapes by the factor with `shape_div`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:2228
quote: "new_stride = shape_div(d, factor)"
lean: MojoProof.Layout.Lay.upcast, MojoProof.Layout.shapeDiv, MojoProof.Layout.shapeDiv_factor, MojoProof.Layout.shapeDiv_dvd, MojoProof.Layout.shapeDiv_mul, MojoProof.Layout.Lay.upcast_fuse, MojoProof.Layout.Lay.upcast_scale, MojoProof.Layout.Lay.upcast_modes, MojoProof.Layout.Lay.upcast_call
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance, MojoProofTest.LayoutRuntime
upstream:
level: L1
---
# `upcast` divides strides and shapes by the factor with `shape_div`

## Rule

`upcast[factor]` (layout.mojo:2218) maps each mode (s, d) to stride `shape_div(d, factor)` and shape `shape_div(s, shape_div(factor, d))` (lines 2227-2229). `shape_div(a, b)` is `a // b` when `b` divides `a`, else the sign of `a * b` (lines 2231-2232).

## In scope

Factors and strides where one divides the other.

## Out of scope

Other factors, where `shape_div` returns 1 or the sign and the result is not a coarsening.

## In MojoProof

`Lay.upcast` and `shapeDiv` transcribe `upcast` and `shape_div` on layouts whose modes are leaves. `Lay.upcast_fuse`: on every flat layout whose strides are positive, each a multiple of the factor `f` or a divisor `d` of a positive `f` with `f / d` dividing the extent, upcasting keeps the extent and divides the stride by `f` on a multiple, and divides the extent by `f / d` and makes the stride 1 on a divisor; the docstring's example, `row_major[4, 8]` upcast by 2, is (4, 4):(4, 1). `Lay.upcast_scale`: on every flat layout whose positive strides are multiples or divisors of `f`, `f` times the upcast offset of a coordinate is the original offset of the coordinate with each leaf multiplied by `shape_div(f, d)`, for every coordinate with one leaf per mode. `Lay.upcast_modes` and `Lay.upcast_call` are their case where `f` divides every stride: the extents are kept and the offset is divided by `f`. A stride 0 gives the extent 0 (`shape_div(4, shape_div(2, 0))`, a division by 0, which the model and Mojo's compiled code both evaluate to 0); MojoProofTest.LayoutLaws has the example, and the one of a divisor stride whose `f / d` does not divide the extent: (3):(1) upcast by 2 is (1):(1), since `shape_div(3, 2)` is 1. The conformance test finds these values, and the docstring example's, in Mojo's compiled code (a test, not a proof). MojoProofTest.LayoutRuntime finds them in a CPU run with runtime extents and strides, where Mojo's `upcast` uses `_runtime_shape_div`: `row_major[4, 8]`, (3):(1), (4, 3):(3, 1) and (4):(0), whose `shape_div(2, 0)` is 0 since Mojo's integer `%` and `//` by 0 give 0 (one run; a test, not a proof).

## Open

Nested modes.
