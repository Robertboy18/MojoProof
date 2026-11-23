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
- Every claim that needs a run. The conformance test compiles a program and reads its IR; nothing is run. Where a card's body works an example by hand from the cited lines, it says so.

## Depends on

The Modular source at bbc13a71. Within the area, most laws build on `crd2idx` (the depends lines of the cards).

## Coverage in MojoProof

MojoProof/Layout/ transcribes the layout functions over a model of nested integer tuples (docs/proofs/layout-laws.md gives the transcription and the laws) and proves laws of 13 cards for every shape that meets their premises: `crd2idx`, `idx2crd`, `cosize`, `reverse-transpose`, `zipped-divide`, `blocked-product`, `coalesce`, `upcast`, `swizzle`, the swizzle half of `bit-layout`, `is-affine` for flat layouts, `row-major-views` and `index-width`; `composition` is transcribed with no law. These 14 cards are L1. Where a law needs a precondition, MojoProofTest.LayoutLaws has a counterexample without it, by `decide` on the model: composition, blocked product, idx2crd, zipped divide and the swizzle. MojoProofTest.LayoutConformance compares the model with the values that Mojo's compiler folds into a kernel's LLVM IR for random static layouts and the counterexamples' inputs; they agree on all 37 cases, 323 values (tests/layout/record.txt). That is a test of the transcription on those cases, not a proof, and not a GPU run, so no card is past L1. `two-level-swizzle` is L0. No proved kernel uses the laws yet: the kernel proofs work on the compiled IR, where a layout has already become integer arithmetic.

## Next steps

- The composition law under CuTe's divisibility conditions, stated and proved on the model.
- `two-level-swizzle`: the equation `L(x) = L_out(x) + Swizzle(L_in(x))`, from `Swizzle.call_call`.
- `bit-layout` for strided modes with power-of-two extents.
- Layouts with runtime leaves in the conformance test, and a GPU run of the conformance program (construct L2).
- `index-width` as a per-kernel obligation where a proved kernel uses a narrow index type, from `Lay.call_flat_toNat`.
