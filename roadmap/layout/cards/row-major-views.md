---
id: row-major-views
title: `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/tile_tensor.mojo:2087
quote: "TileTensor.as_span requires row-major (contiguous) strides"
lean: MojoProof.Layout.rowMajor, MojoProof.Layout.rowMajor_call_lt, MojoProof.Layout.rowMajor_onto, MojoProof.Layout.rowMajor_inj
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
level: L1
---
# `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides

## Rule

`TileTensor.as_span` asserts `Self.is_row_major` at compile time (tile_tensor.mojo:2085-2087). `reshape` (line 3581) and `coalesce` (line 3701) document the same requirement (lines 3593 and 3716).

## In scope

The statement that, on row-major contiguous strides, storage order and layout order agree, so the span visits every element once (lines 2075-2077).

## Out of scope

Non-contiguous tensors, which the assert refuses at compile time.

## In MojoProof

`rowMajor` transcribes `row_major` on flat shapes. For every flat shape with positive extents: `rowMajor_call_lt`, every in-bounds exact coordinate has an offset below the size; `rowMajor_onto`, every offset below the size is reached; `rowMajor_inj`, two in-bounds coordinates with one offset are equal. Together, a row-major layout is a bijection onto the interval [0, size).

## Open

The asserts of `as_span`, `reshape` and `coalesce` themselves, and nested shapes.
