---
id: bit-layout
title: A layout whose extents are powers of two is linear over F2
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/bit_layout.mojo:15
quote: "A layout whose extents are powers of two is linear over F2"
lean: MojoProof.Layout.Swizzle.call_xor, MojoProof.Layout.BitLayout, MojoProof.Layout.BitLayout.put, MojoProof.Layout.BitLayout.call, MojoProof.Layout.xorBits, MojoProof.Layout.BitLayout.call_xor, MojoProof.Layout.bitLinear, MojoProof.Layout.isBitLinear, MojoProof.Layout.placeModes, MojoProof.Layout.placement, MojoProof.Layout.xorBits_place, MojoProof.Layout.placement_call
corpus: none
tests: MojoProofTest.LayoutLaws
upstream:
depends: swizzle
level: L1
---
# A layout whose extents are powers of two is linear over F2

## Rule

The module docstring of `BitLayout` (bit_layout.mojo:13-19) says that each domain bit goes to a fixed set of codomain bits, and a point goes to the XOR of the images of its set bits. Strided modes and swizzles are both linear in this sense. `is_bit_linear` (bit_layout.mojo:230-258) states the condition in full: every extent is a power of two, every stride is 0 or a power of two, and no two coordinate bits reach the same offset bit. `placement` (bit_layout.mojo:261-283) is then the layout as a `BitLayout`.

## In scope

`BitLayout`'s `put` and `__call__`; `is_bit_linear` and `placement` on flat static layouts; swizzles.

## Out of scope

Nested layouts and runtime leaves (`is_bit_linear` refuses the latter). `kill`, `run` and the `dead` mask. Images, spans and offsets from bit 64 on, where Mojo's `UInt64` drops bits and the model does not.

## In MojoProof

MojoProof/Layout/Bits.lean transcribes `BitLayout` (images and the domain mask), `put`, `__call__` (`BitLayout.call`), `is_bit_linear` (`isBitLinear`) and `placement`. `BitLayout.call_xor`: every bit layout is linear over F2, `m(x ^ y) = m(x) ^ m(y)`, for every map and every pair of points. `placement_call`: for every flat layout that `is_bit_linear` accepts, with extents and strides below `2 ^ 64` and a size of at most `2 ^ 64`, the placement's domain mask is the size minus 1 and the placement maps every point below the size to the layout's offset of that point. `Swizzle.call_xor`: every swizzle is linear over F2, `S(x ^ y) = S(x) ^ S(y)`, for every value and every bits, base and shift. MojoProofTest.LayoutLaws has an instance of each, `row_major(4, 8)`'s placement (domain mask 31, and 13 to 11) among them, and the twin of `placement_call`: (2, 2):(1, 1), whose extents and strides are powers of two but whose two modes reach the offset bit 0, maps 1 and 2 to 1 and 3 to 2, not to 1 ^ 1 = 0, so the docstring's sentence needs `is_bit_linear`'s stride conditions; `is_bit_linear` refuses that layout.

## Open

A conformance test of `placement` and `is_bit_linear` against Mojo's compiled values; the transcription is checked by no test yet. Nested layouts.
