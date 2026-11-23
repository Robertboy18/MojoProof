---
id: composition
title: `composition(a, b)` maps a coordinate through `b`, then `a`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:1662
quote: "`B`'s image lies in `A`'s domain."
lean: MojoProof.Layout.Lay.compose, MojoProof.Layout.composeLeaf, MojoProof.Layout.composeStep, MojoProof.Layout.composeDiv, MojoProof.Layout.composeLeaf_prod_dot, MojoProof.Layout.Lay.compose_call
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
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

`Lay.compose`, `composeLeaf` and `composeStep` transcribe `composition` and `_compose_leaf`. `Lay.compose_call`: for every layout `a` with congruent shape and stride and every single-mode `b` = (s):(d) with s, d > 0 that meets `composeDiv` (at each mode of `a` but the last, the mode's extent divides the remaining stride, or the stride divides the extent and the remaining extent is at most the quotient or a multiple of it), the composite has the size s and maps every c < s to a(b(c)), when b(c) is below the size of `a`. `composeLeaf_prod_dot` is the same law on lists of modes. The reported failure is the twin: A = (6, 2):(1, 6) and B = (3):(4) fail `composeDiv` and give (3):(6), so B's index 1 goes to 6 where A(B(1)) = 4 (MojoProofTest.LayoutLaws, by `decide`; the conformance test finds the same in Mojo's compiled code).

## Open

`b` with more than one mode. The composite adds `a`'s offsets of `b`'s modes, which is a(b(c)) only when `a` adds over them: A = (2, 2):(1, 10) and B = (2, 2):(1, 1) meet `composeDiv` mode by mode, and the composite maps 3 to 2 where A(B(3)) = 10 (MojoProofTest.LayoutLaws, by `decide` on the model). The premise for several modes is not stated.
