---
id: cosize
title: `cosize` is the offset of the last coordinate plus one
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:645
quote: "`(m-1)*r + (n-1)*s + 1`, representing the memory footprint."
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# `cosize` is the offset of the last coordinate plus one

## Rule

`Layout.cosize` (layout.mojo:639) returns `self(self.product() - 1) + 1` (line 653): the offset of the last index, plus one. For shape (m, n) and stride (r, s) the docstring gives the quoted sum.

## In scope

Non-negative strides, where the last index has the largest offset, so the sum is the footprint.

## Out of scope

Negative strides. The docstring's formula is not the footprint there, and the code computes the same sum.

## Open

A Lean statement for non-negative strides. MojoProof states no layout law yet.
