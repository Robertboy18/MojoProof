---
id: index-width
title: With a narrow index type the caller must ensure products and sums fit
kind: construct
ref: modular/modular@bbc13a71:Mojo/stdlib/std/utils/coord.mojo:867
quote: "a narrow `out_type` (e.g. `uint32`) are responsible for ensuring the"
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# With a narrow index type the caller must ensure products and sums fit

## Rule

The docstring of `crd2idx` (coord.mojo:864-869) says that each `coord * stride` term, and the split of a scalar coordinate, are computed at `out_type`. Callers that pick a narrow type must ensure that the coordinate, every product and their sum fit.

## In scope

A per-kernel obligation: at each call with a narrow `out_type`, the products and the sum fit.

## Out of scope

A library-wide statement, since the obligation depends on the launch.

## Open

The obligation stated per kernel, where a proved kernel uses a narrow index type. MojoProof states no layout law yet.
