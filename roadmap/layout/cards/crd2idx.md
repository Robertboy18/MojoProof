---
id: crd2idx
title: `crd2idx` is the dot product of a coordinate with the strides
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/utils/coord.mojo:864
quote: "The dot product is computed at `out_type` precision"
lean: MojoProof.Layout.crd2idx, MojoProof.Layout.Lay.call, MojoProof.Layout.Lay.call_scalar, MojoProof.Layout.crd2idx_flat, MojoProof.Layout.Lay.call_leaves, MojoProof.Layout.Lay.call_flat, MojoProof.Layout.crd2idx_leaf_leaf, MojoProof.Layout.fits, MojoProof.Layout.digits, MojoProof.Layout.crd2idx_mixed, MojoProof.Layout.Lay.call_mixed
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance, MojoProofTest.LayoutRuntime
upstream:
level: L1
---
# `crd2idx` is the dot product of a coordinate with the strides

## Rule

`crd2idx(crd, shape, stride)` (coord.mojo:856) maps a coordinate to the sum of each coordinate times its stride. A scalar coordinate against a tuple shape is split by `divmod` with each mode's size, the first mode fastest, and the last mode takes the remaining quotient (coord.mojo:923-935). `Layout.__call__` (layout.mojo:484) documents the three coordinate forms (lines 494-497).

## In scope

Flat and nested coordinates, a coordinate whose nesting differs from the shape's (the scalar and rank-matching cases of layout.mojo:494-497).

## Out of scope

The index type's width: that is the card `index-width`.

## In MojoProof

MojoProof/Layout/Basic.lean transcribes `crd2idx` with its four branches (`crd2idx`, and `Lay.call` for `Layout.__call__`); docs/proofs/layout-laws.md gives the transcription line by line. For every shape and stride: `Lay.call_scalar`, a scalar below the size has the offset of its colexicographic digits against the shape's leaves dotted with the stride's leaves, when shape and stride have the same nesting; `crd2idx_flat`, `Lay.call_leaves` and `Lay.call_flat`, a coordinate with one leaf per mode has the dot product as its offset, with no bound on the coordinate and whatever the extents; `crd2idx_leaf_leaf`, a leaf against a leaf stride is the product; `crd2idx_mixed` and `Lay.call_mixed`, a mixed coordinate (`fits`: against each mode a leaf of any value against a leaf extent, a leaf below the size of a tuple mode, or a tuple of at least two elements against a tuple mode of as many modes, at any depth) has its digits (`digits`) dotted with the stride's leaves as its offset, when shape and stride have the same nesting. MojoProofTest.LayoutLaws has instances and the twin past the bound: (1, 6) on (2, (2, 3)):(1, (2, 4)) has the offset 13, not the digits' 1. MojoProofTest.LayoutConformance compares the model with the offsets that Mojo's compiler folds into a kernel for static flat and nested layouts, scalar, exact and mixed coordinates (one seed; a test, not a proof). MojoProofTest.LayoutRuntime compares it with a CPU run of a compiled program on layouts with runtime leaves, flat, nested and mixed with static ones, at every scalar below the size (one run; a test, not a proof); at the scalars 1 and 5 of (0, 2):(1, 10), past the size 0, the run gives 0 and the model 1 and 5, since Mojo's remainder by 0 is 0 and the model's keeps the dividend.

## Open

A GPU run of layouts with runtime leaves.
