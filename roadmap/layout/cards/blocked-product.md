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

The docstring of the blocked product type (layout.mojo:1904-1911) gives each mode i the shape `(block.shape[i], tiler.shape[i])` and the stride `(block.stride[i], block.cosize * tiler.stride[i])`: the copies of the block are placed one cosize apart, so they do not overlap.

## In scope

Compact blocks, whose cosize is their size.

## Out of scope

Blocks with gaps, whose cosize exceeds their size.

## Open

A Lean statement of the documented layout for compact blocks. MojoProof states no layout law yet.
