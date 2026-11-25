---
id: idx2crd
title: `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:548
quote: "This is the inverse of `__call__` (crd2idx)."
lean: MojoProof.Layout.idx2crd, MojoProof.Layout.idx2crd_flat, MojoProof.Layout.idx2crd_call, MojoProof.Layout.idx2crd_call_reverse
corpus: none
tests: MojoProofTest.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
depends: crd2idx
level: L1
---
# `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx`

## Rule

`Layout.idx2crd` (layout.mojo:540) computes `coord[i] = (idx // stride[i]) % shape[i]` (line 550). The docstring calls this the inverse of `__call__` (crd2idx).

## In scope

Layouts on which the formula inverts `crd2idx`, such as compact layouts whose strides are in column-major order.

## Out of scope

Other layouts, and hierarchical layouts from `zipped_divide` (line 551), beyond noting that the result keeps the nesting.

## In MojoProof

`idx2crd` transcribes `Layout.idx2crd`. `idx2crd_flat`: on a flat layout it gives `(x / d) % s` mode by mode, for every flat layout. `idx2crd_call`: it inverts the coordinate map on in-bounds exact coordinates of every flat layout whose strides are positive and whose modes are nested in order (each mode's extent times stride divides every later stride: column-major layouts, padded or not); `idx2crd_call_reverse` is the same for modes nested in reverse order (row-major layouts). The precondition is needed: the layout (2, 2):(3, 1) maps (1, 0) to 3, and `idx2crd` maps 3 to (1, 1) (MojoProofTest.LayoutLaws, by `decide`; the conformance test finds the same in Mojo's compiled code).

## Open

Orders of the modes that are neither increasing nor decreasing, and hierarchical layouts. At an extent 0, `idx2crd_flat`'s leaf `(x / d) % 0` is `x / d` in the model and 0 in Mojo, whose idx2crd takes the remainder with `umod` (coord.mojo:1966-1967), so there the law describes the model and not Mojo (from the source; the conformance tests have no such case).
