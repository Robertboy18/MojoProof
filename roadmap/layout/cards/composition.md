---
id: composition
title: `composition(a, b)` maps a coordinate through `b`, then `a`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1662
quote: "`B`'s image lies in `A`'s domain."
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# `composition(a, b)` maps a coordinate through `b`, then `a`

## Rule

`composition` (layout.mojo:1641) is documented as CuTe's composition. Its constraint is that both layouts are fully static and `B`'s image lies in `A`'s domain (line 1662). The only checks are the two asserts at lines 1664-1669, and the second is `B.static_cosize <= A.static_product`. The helper `_shape_div` (line 1501) returns 1 when `b` does not divide `a`.

## In scope

The divisibility conditions (CuTe's) under which the result equals `a` after `b` on every coordinate.

## Out of scope

Layouts that pass the two asserts but break those conditions. Whether the result can then differ from `a` after `b` is not checked here.

## Open

The conditions stated in the docstring or checked, and a Lean statement under them. MojoProof states no layout law yet.
