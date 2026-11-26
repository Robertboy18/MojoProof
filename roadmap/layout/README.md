# Layout laws

## Scope

The laws of the layout library in Modular's kernels (`max/kernels/src/layout/` and `Mojo/stdlib/std/utils/coord.mojo`, at commit bbc13a71): how a coordinate maps to an offset, how layouts divide, multiply, compose, coalesce and swizzle, and which layouts support stepping by a stride. Each card quotes the docstring or code line that states its law and says, from the code, where the law holds and what is out of its scope.

## Items

- [crd2idx](cards/crd2idx.md): `crd2idx` is the dot product of a coordinate with the strides
- [idx2crd](cards/idx2crd.md): `idx2crd` maps an offset back to a coordinate, documented as the inverse of `crd2idx`
- [cosize](cards/cosize.md): `cosize` is the offset of the last coordinate plus one
- [reverse-transpose](cards/reverse-transpose.md): `reverse` and `transpose` reverse the shape and the stride
- [zipped-divide](cards/zipped-divide.md): `zipped_divide` splits a layout into tile and number-of-tiles modes
- [blocked-product](cards/blocked-product.md): `blocked_product`'s outer stride is documented as the block's cosize times the tiler's stride
- [coalesce](cards/coalesce.md): `coalesce` keeps the offsets and merges contiguous modes
- [composition](cards/composition.md): `composition(a, b)` maps a coordinate through `b`, then `a`
- [upcast](cards/upcast.md): `upcast` divides strides and shapes by the factor with `shape_div`
- [swizzle](cards/swizzle.md): `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits`
- [two-level-swizzle](cards/two-level-swizzle.md): `two_level_layout_from_swizzle` evaluates to `Swizzle(L(x))`
- [bit-layout](cards/bit-layout.md): A layout whose extents are powers of two is linear over F2
- [is-affine](cards/is-affine.md): Stepping by a stride is exact only for an affine layout
- [row-major-views](cards/row-major-views.md): `TileTensor.as_span`, `reshape` and `coalesce` need row-major contiguous strides
- [index-width](cards/index-width.md): With a narrow index type the caller must ensure products and sums fit

## Out of scope

- The legacy layout types the library no longer has.
- The tensor-core fragment layouts, which belong with the kernels that use them.
- Performance claims, such as coalesced access.
- Every claim that needs a GPU run. The conformance test compiles a GPU program and reads its IR, never running it; the runtime-leaf test runs a CPU program. Where a card's body works an example by hand from the cited lines, it says so.

## Depends on

The Modular source at bbc13a71. Within the area, most laws build on `crd2idx` (the depends lines of the cards).

## Coverage in MojoProof

GPUProof/Layout/ transcribes the layout functions over a model of nested integer tuples (docs/proofs/layout-laws.md gives the transcription and the laws) and proves laws of 15 cards for every shape that meets their premises: `crd2idx` (mixed coordinates included), `idx2crd`, `cosize`, `reverse-transpose`, `zipped-divide`, `blocked-product`, `coalesce`, `composition` (for a `b` of any number of modes that meet `composeDiv` and whose terms do not carry), `upcast`, `swizzle`, `bit-layout` (GPUProof/Layout/Bits.lean: `BitLayout` and the placement of a flat layout that `is_bit_linear` accepts), `two-level-swizzle` (GPUProof/Layout/TwoLevel.lean: `two_level_layout_from_swizzle` is `Swizzle(L(x))` on every flat layout that passes its asserts, at every coordinate inside the shape), `is-affine` (the stepping law for flat layouts), `row-major-views` and `index-width`. These 15 cards are L1. Where a law needs a precondition, MojoProofTest.LayoutLaws has a counterexample without it, by `decide` on the model: composition, blocked product, idx2crd, zipped divide, upcast, the swizzle, the placement and the two-level swizzle. MojoProofTest.LayoutConformance compares the model with the values that Mojo's compiler folds into a kernel's LLVM IR for random static layouts and the counterexamples' inputs; they agree on all 43 cases, 351 values (tests/layout/record.txt). `BitLayout` and `two_level_layout_from_swizzle` are not in that test. MojoProofTest.LayoutRuntime compares the model with a CPU run of a compiled program on 9 layouts with runtime leaves (offsets, sizes and cosizes, the runtime `upcast` among them); they agree on 8, and on the ninth, at scalars past the size 0 of (0, 2):(1, 10), Mojo's remainder by 0 is 0 where the model's keeps the dividend (tests/layout/runtime/record.txt). Both are tests of the transcription on those cases, not proofs, and neither is a GPU run, so no card is past L1. No proved kernel uses the laws yet: the kernel proofs work on the compiled IR, where a layout has already become integer arithmetic.

## Next steps

- For composition, a condition on `a` and `b` alone that gives `noCarry` at every coordinate.
- `two-level-swizzle`: the injectivity of `Lambda` when `bits ≤ |shift|`, from `Swizzle.call_call`.
- `placement`, `is_bit_linear` and `two_level_layout_from_swizzle` in the conformance test.
- A GPU run of the conformance programs (construct L2).
- At an extent 0, the model's remainder `a % 0` keeps the dividend where Mojo's gives 0: no law needs it, but a model with Mojo's remainder would make `idx2crd_flat` hold of Mojo there too.
- `index-width` as a per-kernel obligation where a proved kernel uses a narrow index type, from `Lay.call_flat_toNat`.
