---
id: upcast
title: `upcast` divides strides and shapes by the factor with `shape_div`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:2228
quote: "new_stride = shape_div(d, factor)"
lean: not stated yet
corpus: none
tests: none
upstream:
level: L0
---
# `upcast` divides strides and shapes by the factor with `shape_div`

## Rule

`upcast[factor]` (layout.mojo:2218) maps each mode (s, d) to stride `shape_div(d, factor)` and shape `shape_div(s, shape_div(factor, d))` (lines 2227-2229). `shape_div(a, b)` is `a // b` when `b` divides `a`, else the sign of `a * b` (lines 2231-2232).

## In scope

Factors and strides where one divides the other.

## Out of scope

Other factors, where `shape_div` returns 1 or the sign and the result is not a coarsening.

## Open

A Lean statement under the divisibility condition. MojoProof states no layout law yet.
