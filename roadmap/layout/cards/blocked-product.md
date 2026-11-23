---
id: blocked-product
title: `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1911
quote: "block.cosize * tiler.stride[i]"
lean: MojoProof.Layout.Lay.blockedProduct, MojoProof.Layout.Lay.blockedProduct_call
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
depends: cosize
level: L1
---
# `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride

## Rule

The docstring of the blocked product type (layout.mojo:1904-1911) gives each mode i the shape `(block.shape[i], tiler.shape[i])` and the stride `(block.stride[i], block.cosize * tiler.stride[i])`: the copies of the block are placed one cosize apart, so they do not overlap.

## In scope

Compact blocks, whose cosize is their size.

## Out of scope

Blocks with gaps, whose cosize exceeds their size.

## In MojoProof

`Lay.blockedProduct` transcribes the code, which multiplies the tiler's strides by the block's size, not its cosize. `Lay.blockedProduct_call`: for every pair of flat layouts of one rank, 2 or more, and every exact coordinate ((block coordinate, tiler coordinate) per mode), the offset is the block's offset plus the block's size times the tiler's offset. For a compact block (cosize equal to size) this is the documented layout. A block with gaps gives overlapping offsets: block (2):(2) and tiler (2):(1) map the indices 1 and 2 to the offset 2, where the block's cosize is 3 (MojoProofTest.LayoutLaws, by `decide`; the conformance test finds the same in Mojo's compiled code).

## Open

Nested modes in the block or the tiler.
