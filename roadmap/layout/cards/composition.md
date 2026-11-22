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

`composition` (layout.mojo:1641) is documented as CuTe's composition. Its constraint is that both layouts are fully static and `B`'s image lies in `A`'s domain (line 1662).

## In scope

The divisibility conditions (CuTe's) under which the result equals `a` after `b` on every coordinate.

## Out of scope

Layouts that do not meet those conditions.

## Open

A Lean statement of the composite under the conditions. MojoProof states no layout law yet.
