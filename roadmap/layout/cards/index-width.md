---
id: index-width
title: With a narrow index type the caller must ensure products and sums fit
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/utils/coord.mojo:867
quote: "a narrow `out_type` (e.g. `uint32`) are responsible for ensuring the"
lean: GPUProof.Layout.Lay.call_flat_ofNat, GPUProof.Layout.Lay.call_flat_toNat
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws
upstream:
depends: crd2idx
level: L1
---
# With a narrow index type the caller must ensure products and sums fit

## Rule

The docstring of `crd2idx` (coord.mojo:864-869) says that each `coord * stride` term, and the split of a scalar coordinate, are computed at `out_type`. Callers that pick a narrow type must ensure that the coordinate, every product and their sum fit.

## In scope

A per-kernel obligation: at each call with a narrow `out_type`, the products and the sum fit.

## Out of scope

A library-wide statement, since the obligation depends on the launch.

## In MojoProof

For every flat layout and width `w`: `Lay.call_flat_ofNat`, the offset computed in `w`-bit arithmetic is the exact offset modulo `2^w`; `Lay.call_flat_toNat`, it is the exact offset when that is below `2^w`. These are the facts a kernel's obligation needs; at 8 bits the offset 300 of (100, 2):(3, 0) wraps to 44 (MojoProofTest.LayoutLaws).

## Open

The obligation stated per kernel, where a proved kernel uses a narrow index type.
