---
id: idx2crd
title: `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/layout.mojo:548
quote: "This is the inverse of `__call__` (crd2idx)."
lean: not stated yet
corpus: none
tests: none
upstream:
depends: crd2idx
level: L0
---
# `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx`

## Rule

`Layout.idx2crd` (layout.mojo:540) computes `coord[i] = (idx // stride[i]) % shape[i]` (line 550). The docstring calls this the inverse of `__call__` (crd2idx).

## In scope

Layouts on which the formula inverts `crd2idx`, such as compact layouts whose strides are in column-major order.

## Out of scope

Other layouts, and hierarchical layouts from `zipped_divide` (line 551), beyond noting that the result keeps the nesting.

## Open

The precondition stated in Lean, and a Lean statement that `idx2crd` inverts `crd2idx` under it. MojoProof states no layout law yet.
