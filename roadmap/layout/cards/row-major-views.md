---
id: row-major-views
title: `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/tile_tensor.mojo:2087
quote: "TileTensor.as_span requires row-major (contiguous) strides"
lean: not stated yet
corpus: none
tests: none
upstream:
level: L0
---
# `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides

## Rule

`TileTensor.as_span` asserts `Self.is_row_major` at compile time (tile_tensor.mojo:2085-2087). `reshape` (line 3581) and `coalesce` (line 3701) document the same requirement (lines 3593 and 3716).

## In scope

The statement that, on row-major contiguous strides, storage order and layout order agree, so the span visits every element once (lines 2075-2077).

## Out of scope

Non-contiguous tensors, which the assert refuses at compile time.

## Open

A Lean statement that a row-major contiguous layout is a bijection onto an interval. MojoProof states no layout law yet.
