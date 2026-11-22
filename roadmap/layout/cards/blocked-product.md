---
id: blocked-product
title: `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1911
quote: "block.cosize * tiler.stride[i]"
lean: not stated yet
corpus: none
tests: none
upstream:
depends: cosize
level: L0
---
# `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride

## Rule

The docstring of the blocked product type (layout.mojo:1904-1911) gives each mode i the shape `(block.shape[i], tiler.shape[i])` and the stride `(block.stride[i], block.cosize * tiler.stride[i])`. The code multiplies by the block's shape product, not its cosize. The static case passes `Coord[*BlockLayoutType._shape_types].static_product` (line 1815), and the dynamic case sets `var block_cosize = Int(block.shape_coord().product())` (line 2016).

## In scope

Compact blocks, whose cosize is their size, so the documentation and the code agree.

## Out of scope

Blocks with gaps. There the code's stride is smaller than the documented one, and tiles can overlap. This is our reading of lines 1815 and 2016; we did not run it.

## Open

Either a doc fix (the shape product) or a code fix (the cosize), and a Lean statement for compact blocks. MojoProof states no layout law yet.
