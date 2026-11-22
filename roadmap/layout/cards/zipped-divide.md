---
id: zipped-divide
title: `zipped_divide` splits a layout into tile and number-of-tiles modes
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1414
quote: "component has shape = original_shape / tile with scaled strides."
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# `zipped_divide` splits a layout into tile and number-of-tiles modes

## Rule

`zipped_divide` (layout.mojo:1407) gives an inner mode with the tile shape and the original strides, and an outer mode with the shape divided by the tile and the strides multiplied by it (lines 1426-1434). The division is `_Divide`, whose static case is `Lhs[idx].static_value // Rhs[idx].static_value` (coord.mojo:1911).

## In scope

Tiles that divide the shape, where every element is in exactly one tile.

## Out of scope

Tiles that do not divide the shape.

## Open

A Lean statement under the divisibility precondition. MojoProof states no layout law yet.
