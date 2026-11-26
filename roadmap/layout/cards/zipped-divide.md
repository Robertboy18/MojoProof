---
id: zipped-divide
title: `zipped_divide` splits a layout into tile and number-of-tiles modes
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1414
quote: "component has shape = original_shape / tile with scaled strides."
lean: GPUProof.Layout.Lay.zippedDivide, GPUProof.Layout.Lay.zippedDivide_call, GPUProof.Layout.Lay.zippedDivide_size
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
depends: crd2idx
level: L1
---
# `zipped_divide` splits a layout into tile and number-of-tiles modes

## Rule

`zipped_divide` (layout.mojo:1407) gives an inner mode with the tile shape and the original strides, and an outer mode with the shape divided by the tile and the strides multiplied by it (lines 1426-1434). The division is `_Divide`, whose static case is `Lhs[idx].static_value // Rhs[idx].static_value` (coord.mojo:1911).

## In scope

Tiles that divide the shape, where every element is in exactly one tile.

## Out of scope

Tiles that do not divide the shape.

## In MojoProof

`Lay.zippedDivide` transcribes `zipped_divide` on layouts whose modes are leaves. `Lay.zippedDivide_call`: for every flat layout and every tile with one entry per mode, the coordinate (inner, outer) has the offset of the coordinate `inner + tile * outer` of the original layout, for every rank. `Lay.zippedDivide_size`: when each tile entry divides its extent, the size is the original size. The precondition is needed: (5):(1) divided by 2 has size 4, and no index reaches the element 4 (MojoProofTest.LayoutLaws, by `decide`; the conformance test finds the same in Mojo's compiled code).

## Open

Nested modes in the divided layout.
