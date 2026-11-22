# Layout laws

## Scope

The laws of the layout library in Modular's kernels (`max/kernels/src/layout/` and `Mojo/stdlib/std/utils/coord.mojo`, at commit bbc13a71): how a coordinate maps to an offset, how layouts divide, multiply, compose, coalesce and swizzle, and which layouts support stepping by a stride. Each card quotes the docstring or code line that states its law and says, from the code, where the law holds and where the code does not check it.

## Items

- [crd2idx](cards/crd2idx.md): `crd2idx` is the dot product of a coordinate with the strides
- [idx2crd](cards/idx2crd.md): `idx2crd` inverts `crd2idx` only on layouts where the formula does
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
- Every claim that needs a run. The cards read the source and do not compile or run it; where a body works an example, the arithmetic is by hand from the cited lines and is marked as such.

## Depends on

The Modular source at bbc13a71. Within the area, most laws build on `crd2idx` (the depends lines of the cards).

## Coverage in MojoProof

None. MojoProof states no layout law, so every card is L0. A kernel proof today works on the compiled IR, where a layout has already become integer arithmetic, so the laws are not needed for the kernels proved so far.

## Next steps

- A Lean model of `Layout` over integer tuples with `crd2idx`, then the laws in order of the depends lines: `cosize`, `reverse-transpose`, `coalesce`, `is-affine`, `row-major-views`, then `swizzle` and `bit-layout`.
- The cards whose code is weaker than the docstring (`idx2crd`, `zipped-divide`, `blocked-product`, `composition`, `swizzle`): a precondition in Lean, and a report upstream once each is confirmed by a run.
- `index-width` as a per-kernel obligation where a proved kernel uses a narrow index type.
