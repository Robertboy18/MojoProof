---
id: reverse-transpose
title: `reverse` and `transpose` reverse the shape and the stride
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:665
quote: "A new Layout with shape and stride Coords reversed."
lean: not stated yet
corpus: none
tests: none
upstream:
level: L0
---
# `reverse` and `transpose` reverse the shape and the stride

## Rule

`Layout.reverse` (layout.mojo:656) reverses the shape and the stride coordinates (line 667), and `transpose` is `reverse` (line 689).

## In scope

Any rank. For rank 2 this swaps rows and columns (lines 673-675).

## Out of scope

Nested modes: whether the reversal recurses into them is not checked here.

## Open

A Lean statement that the reversed layout maps the reversed coordinate to the same offset. MojoProof states no layout law yet.
