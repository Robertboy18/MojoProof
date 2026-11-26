---
id: composition
title: `composition(a, b)` maps a coordinate through `b`, then `a`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1662
quote: "`B`'s image lies in `A`'s domain."
lean: GPUProof.Layout.Lay.compose, GPUProof.Layout.composeLeaf, GPUProof.Layout.composeStep, GPUProof.Layout.composeDiv, GPUProof.Layout.composeLeaf_prod_dot, GPUProof.Layout.composeLeaf_flatMap, GPUProof.Layout.Lay.compose_modes, GPUProof.Layout.Lay.compose_sum, GPUProof.Layout.noCarry, GPUProof.Layout.noCarry_one, GPUProof.Layout.dotColex_sum, GPUProof.Layout.Lay.compose_call, GPUProof.Layout.carryFree, GPUProof.Layout.carryFree_pick, GPUProof.Layout.Lay.compose_all
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws, MojoProofTest.LayoutConformance
upstream: https://github.com/modular/modular/issues/7738
depends: crd2idx
level: L1
---
# `composition(a, b)` maps a coordinate through `b`, then `a`

## Rule

`composition` (layout.mojo:1641) is documented as CuTe's composition. Its constraint is that both layouts are fully static and `B`'s image lies in `A`'s domain (line 1662).

## In scope

The divisibility conditions (CuTe's) under which the result equals `a` after `b` on every coordinate.

## Out of scope

Layouts that do not meet those conditions.

## In MojoProof

`Lay.compose`, `composeLeaf` and `composeStep` transcribe `composition`, `_compose_mode` and `_compose_leaf`. `Lay.compose_sum`: for every layout `a` and every layout `b` with congruent shapes and strides, nested or flat, whose flattened modes each meet `composeDiv` (at each mode of `a` but the last, the mode's extent divides the remaining stride, or the stride divides the extent and the remaining extent is at most the quotient or a multiple of it), the composite has `b`'s size and gives every scalar coordinate v < size(b) with b(v) below the size of `a` the sum over `b`'s modes of `a`'s offset of the mode's term (digit times stride). `Lay.compose_call`: when those terms do not carry against `a`'s extents (`noCarry`; then `a` adds over them, `dotColex_sum`), the composite maps v to a(b(v)). A `b` of one mode meets `noCarry` at every v (`noCarry_one`). `Lay.compose_all`: when, in addition to `composeDiv`, the term lists of `b`'s modes (the multiples x * d for x < s of each mode (s, d)) are `carryFree` against `a`'s extents (at each extent, the largest remainders of the lists add up to less than the extent, the same for the quotients against the remaining extents, and nothing is left above the last extent), the composite maps every v < size(b) to a(b(v)): `carryFree` gives b(v) below the size of `a` and `noCarry` at every v (`carryFree_pick`), so there is no check per coordinate. `composeLeaf_prod_dot` is the law for one leaf on lists of modes, a stride 0 included. MojoProofTest.LayoutLaws has a three-mode instance, the tile (2, (2, 2)):(1, (8, 16)) of `row_major[4, 8]`, which is a after b at all 8 coordinates by `Lay.compose_all`, a two-mode instance at a second size, the tile (4, 4):(2, 16) of `row_major[8, 16]`, which is a after b at all 16 coordinates, and the twins. Without `composeDiv`: A = (6, 2):(1, 6) and B = (3):(4) give (3):(6), so B's index 1 goes to 6 where A(B(1)) = 4 (the reported failure); this B is `carryFree` against A, so neither premise implies the other. Without `noCarry` (and so without `carryFree`): A = (2, 2):(1, 10) and B = (2, 2):(1, 1) map 3 to 2 where A(B(3)) = 10, and A = (6, 2):(1, 100) with the injective B = (3, 2):(2, 3) map 5 to 7 where A(B(5)) = 101, both within the cosize assert. The conformance test finds the same values in Mojo's compiled code (a test, not a proof).

## Open

`carryFree` is shown sufficient, not necessary: that every layout pair meeting `noCarry` and the size bound at every coordinate is `carryFree` is not proved. The premise is not compared with a text of CuTe's own condition. Layouts with runtime leaves.
