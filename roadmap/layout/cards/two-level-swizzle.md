---
id: two-level-swizzle
title: `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/two_level_layout.mojo:1108
quote: "with `L_in`, so the result evaluates to `Swizzle(L(x))` for every"
lean: MojoProof.Layout.TwoLevel, MojoProof.Layout.TwoLevel.offset, MojoProof.Layout.TwoLevel.call, MojoProof.Layout.Swizzle.period, MojoProof.Layout.Swizzle.innerBits, MojoProof.Layout.Swizzle.twoLevel, MojoProof.Layout.swizzleValid, MojoProof.Layout.Swizzle.disjoint, MojoProof.Layout.Swizzle.testBit_call, MojoProof.Layout.Swizzle.call_add, MojoProof.Layout.xorBits_map, MojoProof.Layout.Swizzle.twoLevel_parts, MojoProof.Layout.Swizzle.twoLevel_call
corpus: none
tests: MojoProofTest.LayoutLaws
upstream:
depends: swizzle, is-affine, bit-layout
level: L1
---
# `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))`

## Rule

`two_level_layout_from_swizzle` (two_level_layout.mojo:1101-1133) splits `L = L_out + L_in`, where `L_in` is every coordinate contribution below the swizzle's period `base + bits + |shift|` (lines 956-959), and composes the swizzle with `L_in`, "so the result evaluates to `Swizzle(L(x))` for every coordinate `x`" (lines 1106-1109). It asserts that the layout is flat with static extents and strides that are powers of two (lines 1066-1078) and that no two modes' inner bits reach the same offset bit (lines 1081-1098). The module docstring states that `Lambda` is injective, so the layout is not affine (lines 29-31).

## In scope

The equation for every swizzle and every flat static layout that passes both asserts, at tuple coordinates and scalar indices, and the injectivity of `Lambda`.

## Out of scope

`TwoLevelLayout` with nested or runtime outer layouts, a nonzero `x0`, `idx2crd`, and offsets from bit 63 on, where Mojo's `Int` wraps and the model does not.

## In MojoProof

MojoProof/Layout/TwoLevel.lean transcribes `TwoLevelLayout.__call__` on a flat static outer layout (`TwoLevel.call`: a tuple coordinate's values, or a scalar index split by `divmod` by the full extents; the outer offset plus `x0` XOR the inner images of each mode's low bits), `_SwizzleInnerBits` (`Swizzle.innerBits`), the outer and inner parts of `SwizzledTwoLevelLayout` (`Swizzle.twoLevel`) and the two asserts (`swizzleValid`, `Swizzle.disjoint`). `Swizzle.twoLevel_call`: for every swizzle (any bits, base and shift, positive or not) and every flat layout that passes both asserts, with extents and strides below `2 ^ 64`, the two-level layout's value is `Swizzle(L(x))` at every tuple coordinate with one leaf per mode, each inside its extent, and at every scalar index below the size. The proof uses the swizzle's linearity over F2 (`Swizzle.call_xor`, card `swizzle`), the bit layouts' `xorBits` lemmas (card `bit-layout`), and `Swizzle.call_add`: the swizzle changes no bit from its period on, so adding a multiple of `2 ^ period` commutes with it. MojoProofTest.LayoutLaws has an instance (`Swizzle(3, 0, 3)` on `row_major(16, 8)`: the coordinate (13, 5) to 104 and the index 109 to 107) and, by `decide`, the twins: without disjoint inner bits, (2, 2):(1, 1) with `Swizzle(1, 0, 1)` gives 0 at (1, 1) where `Swizzle(L(1, 1))` is 3; past an extent, the tuple coordinate (2, 0) of (2, 2):(1, 2), which passes both asserts, gives 2 where `Swizzle(L(2, 0))` is 3, so "every coordinate" needs the coordinate inside the shape; and with a zero shift, which the integer overload accepts, `Swizzle(1, 0, 0)` on (2):(1) sends both indices to 0, so `Lambda` is not injective. The conformance test does not compile `two_level_layout_from_swizzle`.

## Open

The injectivity of `Lambda` when `bits ≤ |shift|` (from `Swizzle.call_call`), and `two_level_layout_from_swizzle` in the conformance test.
