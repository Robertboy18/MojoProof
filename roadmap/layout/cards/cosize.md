---
id: cosize
title: `cosize` is the offset of the last coordinate plus one
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:645
quote: "`(m-1)*r + (n-1)*s + 1`, representing the memory footprint."
lean: MojoProof.Layout.Lay.cosize, MojoProof.Layout.Lay.cosize_eq, MojoProof.Layout.Lay.call_lt_cosize
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance, MojoProofTest.LayoutRuntime
upstream:
depends: crd2idx
level: L1
---
# `cosize` is the offset of the last coordinate plus one

## Rule

`Layout.cosize` (layout.mojo:639) returns `self(self.product() - 1) + 1` (line 653): the offset of the last index, plus one. For shape (m, n) and stride (r, s) the docstring gives the quoted sum.

## In scope

Non-negative strides, where the last index has the largest offset, so the sum is the footprint.

## Out of scope

Negative strides. The docstring's formula is not the footprint there, and the code computes the same sum.

## In MojoProof

`Lay.cosize` transcribes `Layout.cosize`. `Lay.cosize_eq`: on every layout whose shape and stride have the same nesting and whose extents are positive, the cosize is `1 + Σ (sₖ - 1) * dₖ` over the leaves, the static formula. `Lay.call_lt_cosize`: every scalar below the size has an offset below the cosize. Both are for every such shape, nested or flat, with non-negative strides (the model's strides are natural numbers). MojoProofTest.LayoutRuntime finds the model's cosizes in a CPU run of a compiled program on layouts with runtime leaves, among them the size-0 (0):(0) and (0, 2):(1, 10), whose cosize is 1 (one run; a test, not a proof).

## Open

Negative strides, which the model does not have.
