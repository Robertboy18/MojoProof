---
id: reverse-transpose
title: `reverse` and `transpose` reverse the shape and the stride
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:665
quote: "A new Layout with shape and stride Coords reversed."
lean: GPUProof.Layout.Lay.reverse, GPUProof.Layout.Lay.call_reverse, GPUProof.Layout.Lay.reverse_reverse, GPUProof.Layout.Lay.size_reverse
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
level: L1
---
# `reverse` and `transpose` reverse the shape and the stride

## Rule

`Layout.reverse` (layout.mojo:656) reverses the shape and the stride coordinates (line 667), and `transpose` is `reverse` (line 689).

## In scope

Any rank. For rank 2 this swaps rows and columns (lines 673-675).

## Out of scope

Nested modes: whether the reversal recurses into them is not checked here.

## In MojoProof

`Lay.reverse` transcribes `reverse`, which reverses the top-level modes only. `Lay.call_reverse`: for every layout and every coordinate with one entry per mode (rank 2 or more), the reversed layout maps the reversed coordinate to the same offset, nested modes included. `Lay.reverse_reverse` and `Lay.size_reverse`: reversal is an involution and keeps the size, for every layout.

## Open

A scalar coordinate: the reversed layout splits it in the other order, so its offset differs in general.
