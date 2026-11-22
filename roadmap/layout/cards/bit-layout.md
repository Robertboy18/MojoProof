---
id: bit-layout
title: A layout whose extents are powers of two is linear over F2
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/bit_layout.mojo:15
quote: "A layout whose extents are powers of two is linear over F2"
lean: not stated yet
corpus: none
tests: none
upstream:
depends: swizzle
level: L0
---
# A layout whose extents are powers of two is linear over F2

## Rule

The module docstring of `BitLayout` (bit_layout.mojo:13-19) says that each domain bit goes to a fixed set of codomain bits, and a point goes to the XOR of the images of its set bits. Strided modes and swizzles are both linear in this sense.

## In scope

Power-of-two extents, strided modes and swizzles.

## Out of scope

Extents that are not powers of two.

## Open

A Lean statement for strided power-of-two layouts and for swizzles. MojoProof states no layout law yet.
