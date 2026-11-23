---
id: is-affine
title: Stepping by a stride is exact only for an affine layout
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:120
quote: "this first: only an affine layout makes that step exact."
lean: MojoProof.Layout.Lay.call_add
corpus: none
tests: MojoProofTest.LayoutLaws
upstream:
depends: crd2idx
level: L1
---
# Stepping by a stride is exact only for an affine layout

## Rule

`is_affine` (layout.mojo:116) is whether the layout's offset is a sum of coordinate times stride (line 117). Code that steps through memory by adding a stride must check it first (lines 119-120).

## In scope

The statement that, for an affine layout, the next coordinate's offset is the current offset plus the stride.

## Out of scope

Which kernels step by a stride without checking `is_affine`: that is a per-kernel question.

## In MojoProof

`Lay.call_add`: on every flat layout, the offset of the sum of two exact coordinates is the sum of their offsets, so stepping one coordinate by 1 adds that mode's stride. A swizzle is not affine: `Swizzle(1, 0, 1)` maps 1 to 1 and 2 to 3 (MojoProofTest.LayoutLaws, by `decide`). `is_affine` itself is not transcribed.

## Open

`is_affine` in Lean, and the stepping law for every layout it accepts.
