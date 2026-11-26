---
id: coalesce
title: `coalesce` keeps the offsets and merges contiguous modes
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:2475
quote: "The result is the simplest layout that maps coordinates to the same"
lean: GPUProof.Layout.Lay.coalesce, GPUProof.Layout.coalesceStep, GPUProof.Layout.Lay.coalesce_call, GPUProof.Layout.Lay.coalesce_size
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
depends: crd2idx
level: L1
---
# `coalesce` keeps the offsets and merges contiguous modes

## Rule

`coalesce` (layout.mojo:2462) skips shape-1 modes and merges a mode into the previous one when `prev_shape * prev_stride == current_stride` (lines 2468-2473). The docstring says the result maps coordinates to the same linear offsets.

## In scope

Equality of offsets on every index of the flattened layout.

## Out of scope

"Simplest" as a minimality claim: no Lean statement is planned for it.

## In MojoProof

`Lay.coalesce` and `coalesceStep` transcribe `coalesce` and its reducer. `Lay.coalesce_call`: on every layout whose shape and stride have the same nesting, the coalesced layout and the original give the same offset to every scalar below the size; `Lay.coalesce_size`: the sizes are equal. For every such shape, nested or flat.

## Open

Coordinates other than scalars: the coalesced layout has another rank.
