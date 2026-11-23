---
id: crd2idx
title: `crd2idx` is the dot product of a coordinate with the strides
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/utils/coord.mojo:864
quote: "The dot product is computed at `out_type` precision"
lean: MojoProof.Layout.crd2idx, MojoProof.Layout.Lay.call, MojoProof.Layout.Lay.call_scalar, MojoProof.Layout.crd2idx_flat, MojoProof.Layout.Lay.call_leaves, MojoProof.Layout.Lay.call_flat, MojoProof.Layout.crd2idx_leaf_leaf
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
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

MojoProof/Layout/Basic.lean transcribes `crd2idx` with its four branches (`crd2idx`, and `Lay.call` for `Layout.__call__`); docs/proofs/layout-laws.md gives the transcription line by line. For every shape and stride: `Lay.call_scalar`, a scalar below the size has the offset of its colexicographic digits against the shape's leaves dotted with the stride's leaves, when shape and stride have the same nesting; `crd2idx_flat`, `Lay.call_leaves` and `Lay.call_flat`, a coordinate with one leaf per mode has the dot product as its offset, with no bound on the coordinate and whatever the extents; `crd2idx_leaf_leaf`, a leaf against a leaf stride is the product. MojoProofTest.LayoutConformance compares the model with the offsets that Mojo's compiler folds into a kernel for static flat and nested layouts, scalar and exact coordinates (one seed; a test, not a proof).

## Open

A general theorem for mixed coordinates (a tuple coordinate whose entries are scalars against tuple modes); the definition covers them, and the tests check instances. Layouts with runtime leaves in the conformance test.
