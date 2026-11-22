---
id: two-level-swizzle
title: `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/two_level_layout.mojo:1108
quote: "with `L_in`, so the result evaluates to `Swizzle(L(x))` for every"
lean: not stated yet
corpus: none
tests: none
upstream:
depends: swizzle, is-affine
level: L0
---
# `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))`

## Rule

`two_level_layout_from_swizzle` (two_level_layout.mojo:1101) splits `L = L_out + L_in` and composes the swizzle with `L_in` (lines 1106-1109). The module docstring states that `Lambda` is injective, so the layout is not affine (lines 29-31).

## In scope

The equation for every coordinate, and the injectivity of `Lambda`.

## Out of scope

The bit-level encoding of the inner map (basis images per bit, lines 27-28) beyond what the equation needs.

## Open

A Lean statement of the equation for every swizzle that satisfies the card `swizzle`'s condition. MojoProof states no layout law yet.
