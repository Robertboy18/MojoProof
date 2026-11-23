---
id: bit-layout
title: A layout whose extents are powers of two is linear over F2
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/bit_layout.mojo:15
quote: "A layout whose extents are powers of two is linear over F2"
lean: MojoProof.Layout.Swizzle.call_xor
corpus: none
tests: MojoProofTest.LayoutLaws
upstream:
depends: swizzle
level: L1
---
# A layout whose extents are powers of two is linear over F2

## Rule

The module docstring of `BitLayout` (bit_layout.mojo:13-19) says that each domain bit goes to a fixed set of codomain bits, and a point goes to the XOR of the images of its set bits. Strided modes and swizzles are both linear in this sense.

## In scope

Power-of-two extents, strided modes and swizzles.

## Out of scope

Extents that are not powers of two.

## In MojoProof

`Swizzle.call_xor`: every swizzle is linear over F2, `S(x ^ y) = S(x) ^ S(y)`, for every value and every bits, base and shift. The strided half of the card is not stated.

## Open

A Lean statement for strided layouts with power-of-two extents.
