---
id: upcast
title: `upcast` divides strides and shapes by the factor with `shape_div`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:2228
quote: "new_stride = shape_div(d, factor)"
lean: MojoProof.Layout.Lay.upcast, MojoProof.Layout.shapeDiv, MojoProof.Layout.shapeDiv_factor, MojoProof.Layout.Lay.upcast_modes, MojoProof.Layout.Lay.upcast_call
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
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

`Lay.upcast` and `shapeDiv` transcribe `upcast` and `shape_div` on layouts whose modes are leaves. `Lay.upcast_modes`: when the factor divides every stride and every stride is positive, upcasting keeps each extent and divides each stride by the factor; `Lay.upcast_call`: the factor times the upcast offset is the original offset. For every flat layout and factor under that condition. A stride 0 gives the extent 0 (`shape_div(4, shape_div(2, 0))`, a division by 0, which the model and Mojo's compiled code both evaluate to 0); MojoProofTest.LayoutLaws has the example.

## Open

A positive stride that divides the factor, such as the stride-1 mode of the docstring's `row_major[4, 8]` example, where the extent is divided instead; nested modes.
