---
id: idx2crd
title: `idx2crd` inverts `crd2idx` only on layouts where the formula does
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
# `idx2crd` inverts `crd2idx` only on layouts where the formula does

## Rule

`Layout.idx2crd` (layout.mojo:540) computes `coord[i] = (idx // stride[i]) % shape[i]` (line 550). The docstring calls this the inverse of `__call__`.

## In scope

The precondition under which the formula inverts `crd2idx`. The docstring states none. By the formula, on shape (2, 2) with stride (3, 1), whose offsets 0, 3, 1, 4 are distinct, index 3 gives (1, 1), and `crd2idx` of (1, 1) is 4, not 3. This is our arithmetic from line 550; we did not run it.

## Out of scope

Hierarchical layouts from `zipped_divide` (line 551), beyond noting that the result keeps the nesting.

## Open

The precondition (for example, compact column-major order of the strides), and a Lean statement under it. MojoProof states no layout law yet.
