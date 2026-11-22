---
id: coalesce
title: `coalesce` keeps the offsets and merges contiguous modes
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:2475
quote: "The result is the simplest layout that maps coordinates to the same"
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# `coalesce` keeps the offsets and merges contiguous modes

## Rule

`coalesce` (layout.mojo:2462) skips shape-1 modes and merges a mode into the previous one when `prev_shape * prev_stride == current_stride` (lines 2468-2473). The docstring says the result maps coordinates to the same linear offsets.

## In scope

Equality of offsets on every index of the flattened layout.

## Out of scope

"Simplest" as a minimality claim: no Lean statement is planned for it.

## Open

A Lean statement that the coalesced layout and the original agree on every index. MojoProof states no layout law yet.
