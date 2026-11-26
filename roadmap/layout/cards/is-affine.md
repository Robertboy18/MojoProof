---
id: is-affine
title: Stepping by a stride is exact only for an affine layout
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:120
quote: "this first: only an affine layout makes that step exact."
lean: GPUProof.Layout.Lay.isAffine, GPUProof.Layout.Lay.isAffine_flat, GPUProof.Layout.Lay.call_add
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws
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

`Lay.isAffine` transcribes `is_affine`: `Layout` (layout.mojo:329) keeps the trait's default `True`, so it is `true` on every layout of the model. `Lay.isAffine_flat`: on every flat layout `is_affine` holds and adding `n` to the `k`-th element of an exact coordinate adds `n` times the `k`-th stride to the offset, for every mode and `n`, with no bound on the coordinate. `Lay.call_add`: on every flat layout, the offset of the sum of two exact coordinates is the sum of their offsets. A swizzle is not affine: `Swizzle(1, 0, 1)` maps 1 to 1 and 2 to 3 (MojoProofTest.LayoutLaws, by `decide`).

## Open

The stepping law on nested layouts, where a step past a mode's bound carries into the next digit (`Lay.call_mixed` gives the offset of each mixed coordinate). The two-level layouts, which set `is_affine` to `False` (two_level_layout.mojo:520), are not modelled.
