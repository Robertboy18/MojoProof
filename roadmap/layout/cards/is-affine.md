---
id: is-affine
title: Stepping by a stride is exact only for an affine layout
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:120
quote: "this first: only an affine layout makes that step exact."
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# Stepping by a stride is exact only for an affine layout

## Rule

`is_affine` (layout.mojo:116) is whether the layout's offset is a sum of coordinate times stride (line 117). Code that steps through memory by adding a stride must check it first (lines 119-120).

## In scope

The statement that, for an affine layout, the next coordinate's offset is the current offset plus the stride.

## Out of scope

Which kernels step by a stride without checking `is_affine`: that is a per-kernel question.

## Open

A Lean statement for affine layouts. MojoProof states no layout law yet.
