---
id: crd2idx
title: `crd2idx` is the dot product of a coordinate with the strides
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/utils/coord.mojo:864
quote: "The dot product is computed at `out_type` precision"
lean: not stated yet
corpus: none
tests: none
upstream:
level: L0
---
# `crd2idx` is the dot product of a coordinate with the strides

## Rule

`crd2idx(crd, shape, stride)` (coord.mojo:856) maps a coordinate to the sum of each coordinate times its stride. A scalar coordinate against a tuple shape is split by `divmod` with each mode's size, the first mode fastest, and the last mode takes the remaining quotient (coord.mojo:923-935). `Layout.__call__` (layout.mojo:484) documents the three coordinate forms (lines 494-497).

## In scope

Flat and nested coordinates, a coordinate whose nesting differs from the shape's (the scalar and rank-matching cases of layout.mojo:494-497).

## Out of scope

The index type's width: that is the card `index-width`.

## Open

A Lean statement for every shape and stride. MojoProof states no layout law yet.
