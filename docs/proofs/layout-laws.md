# The layout laws

This document states the laws of the layout library of Modular's kernels at modular/modular
bbc13a71 (`max/kernels/src/layout/` and `Mojo/stdlib/std/utils/coord.mojo`) that MojoProof
proves about its Lean model of that library, one law per card of `roadmap/layout/cards/`. It
gives the model, then each law with its premises and its scope, then the bugs that the model
shows by a counterexample, then the transcription table and the conformance test that compares
the model with the values the Mojo compiler computes.

The Lean statements are the reference. Every law below holds for all inputs that meet its
premises unless its scope says otherwise; the concrete instances and the counterexamples are in
`MojoProofTest/LayoutLaws.lean`. The model lives under `MojoProof/Layout/` (namespace
`MojoProof.Layout`), apart from the LLVM data layout `MojoProof.Sem.Layout`.

## 1. The model

`MojoProof/Layout/Basic.lean`.

* **Trees.** A shape, a stride and a coordinate are all trees `Tup`: a leaf `leaf v static`
  carries a natural number and whether Mojo knows it at compile time (`ComptimeInt[v]`) or only
  at run time (a `Scalar`); `tup ts` is a tuple. No value of the model depends on the static
  flag, except one: idx2crd answers a static extent 1 with the static coordinate 0, as Mojo does.
* **Values are natural numbers.** Mojo requires a layout's shapes and strides to be non-negative
  (layout.mojo:345), so coordinates and offsets are non-negative too. The model computes at
  unbounded precision; the index-width law (section 2.15) relates it to Mojo's fixed-width
  index types.
* **A layout** `Lay` is a list of shape modes and a list of stride modes (`Layout[shape_types,
  stride_types]`). `Lay.flat ms` is the flat static layout of the (extent, stride) pairs `ms`.
* **The coordinate map** `Lay.call L c` is `Layout.__call__`: a tuple coordinate with more
  elements than the rank is dotted with the flattened strides; every other coordinate goes to
  `crd2idx`, which (i) for a coordinate with as many elements as the shape (and more than one)
  adds the offsets of the elements in the matching modes, (ii) for a coordinate with more than
  one element but fewer than the shape dots its element values with the stride's leaves, and
  (iii) for a scalar (a leaf, or a tuple of at most one element) splits it across the modes by
  `divmod` with each mode's size, the first mode fastest, the last mode taking the quotient.
* **Rejected inputs.** Where Mojo rejects an input at compile time or aborts (a tuple
  coordinate against a leaf shape, a shape and stride of different lengths, a tuple's `value()`),
  the model returns 0 or the empty tuple, and no law holds there. Mojo's static bounds asserts
  are not modelled; each law states the bound it needs as a premise.
* **Division by zero.** The model's `a / 0` and `a % 0` are 0. This matters in two places:
  idx2crd with a stride 0 (the coordinate is then `0 % s`, so 0) and `shape_div` with a divisor
  0 (`upcast` of a stride-0 mode, whose extent becomes 0). The compiler gives the same in the
  second case on the conformance test's upcast of (4):(0) (section 5).

`MojoProof/Layout/Algebra.lean` transcribes the functions that build one layout from others
(`coalesce`, `composition`, `zipped_divide`, `blocked_product`, `upcast`) and the XOR swizzle
`Swizzle`. The layouts they return have static leaves.

## 2. The laws

Each law names its card, its Lean declarations and its premises. "Every shape" means every tree
of the model, nested or flat, static or runtime, of any rank.

### 2.1 crd2idx (`crd2idx`)

* `Lay.call_scalar`: on a layout whose shape and stride are congruent (the same tree structure),
  a scalar `v` below the size has the offset `Σₖ digitₖ(v) * dₖ`, where the digits are `v`'s
  colexicographic digits against the shape's leaves (`colex`) and the `dₖ` are the stride's
  leaves. Every shape.
* `Lay.call_flat`: on a flat layout, a coordinate with one leaf per mode has the offset
  `Σₖ cₖ * dₖ`, with no bound on the coordinates. Every rank, 0 and 1 included.
* `crd2idx_flat` and `Lay.call_leaves`: the same on any layout whose stride is a tuple of leaves,
  whatever its extents are (the extents of such a coordinate do not enter the offset).

### 2.2 idx2crd (`idx2crd`)

* `idx2crd_call`: on a flat layout whose strides are positive and whose modes are nested in order
  (each mode's extent times its stride divides every later mode's stride; column-major layouts,
  padded or not), idx2crd of the offset of an in-bounds coordinate is that coordinate.
* `idx2crd_call_reverse`: the same with the modes nested in reverse order (row-major layouts).
* Not every injective layout is inverted: for (2,2):(3,1), whose modes are not nested in either
  order, idx2crd maps the offset 3 of the coordinate (1,0) to (1,1) (section 3).

### 2.3 cosize (`cosize`)

* `Lay.cosize_eq`: on a layout whose shape and stride are congruent and whose extents are all
  positive, `cosize = 1 + Σₖ (sₖ - 1) * dₖ` over the leaves (the docstring's
  `(m-1)*r + (n-1)*s + 1`, for every rank and nesting).
* `Lay.call_lt_cosize`: under the same premises every scalar coordinate below the size has an
  offset below the cosize: the cosize bounds the footprint.

### 2.4 reverse and transpose (`reverse-transpose`)

* `Lay.reverse_reverse`: reversal is an involution. Every layout.
* `Lay.size_reverse`: reversal keeps the size. Every layout.
* `Lay.call_reverse`: on a layout whose shape and stride have equal lengths, the reversed layout
  maps the reversed coordinate to the same offset, for a coordinate with one element per mode
  and rank at least 2. Every such layout, nested modes included.

### 2.5 is-affine (`is-affine`)

* `Lay.call_add`: on a flat layout, the offset of the sum of two coordinates with one leaf per
  mode is the sum of their offsets; so stepping one coordinate by 1 adds that mode's stride. Every
  flat layout.
* A swizzle is not affine: `Swizzle(1, 0, 1)` maps 1 to 1 and 2 to 3 (instance in the test file).

### 2.6 row-major views (`row-major-views`)

`rowMajor ss` is the flat layout of `row_major(shape)` (layout.mojo:1002): the last stride is 1
and each earlier stride is the product of the later extents.

* `rowMajor_call_lt`: every in-bounds coordinate's offset is below the size.
* `rowMajor_onto`: every offset below the size is the offset of the in-bounds coordinate that
  idx2crd gives for it.
* `rowMajor_inj`: two in-bounds coordinates with the same offset are equal (from
  `idx2crd_call_reverse`).

Together: a row-major layout of positive extents is a bijection from its in-bounds coordinates
onto the interval `[0, size)`, so a span over it visits every element once. For every list of
positive extents.

### 2.7 coalesce (`coalesce`)

* `Lay.coalesce_call`: on a layout whose shape and stride are congruent, the coalesced layout
  gives every scalar coordinate below the size the same offset as the layout. Every shape,
  nested ones included (coalesce flattens them).
* `Lay.coalesce_size`: coalescing keeps the size.
* Out of scope: the docstring's "simplest", a minimality claim.

### 2.8 composition (`composition`)

* `Lay.compose_call`: for every layout A whose shape and stride are congruent (nested ones
  included) and every single-mode layout B = (s):(d) with s, d > 0 that meets `composeDiv` on
  A's flattened modes but the last, the composite has the size s and gives every scalar
  coordinate c < s the offset A(B(c)), when B(c) = c * d is below A's size. `composition`
  asserts the like bound, B's cosize at most A's size (layout.mojo:1664-1669).
  `composeLeaf_prod_dot` is the same law on lists of modes.
* `composeDiv` is the divisibility premise, taken mode by mode as `_compose_leaf` crosses A's
  modes: at a mode of extent a, with the stride r and the extent e that remain, either a divides
  r, or r divides a and e is at most a / r or a multiple of it. CuTe's stride and shape
  divisibility conditions imply it.
* The twin: A = (6,2):(1,6) and B = (3):(4) fail `composeDiv`, since neither of 4 and 6 divides
  the other, and the composite is not A after B (section 3).
* Out of scope: B with more than one mode. The composite composes each mode of B on its own and
  adds A's offsets of them, which is A after B only when A adds over B's modes. A = (2,2):(1,10)
  and B = (2,2):(1,1), each mode of B meeting `composeDiv` and B's cosize 3 within A's size 4,
  give 2 at the index 3, where A(B(3)) = A(2) = 10 (`MojoProofTest/LayoutLaws.lean`, by
  `decide` on the model; the conformance test does not compile this input).

### 2.9 zipped divide (`zipped-divide`)

* `Lay.zippedDivide_call`: on a flat layout and a tile of the same rank, the divided layout maps
  the coordinate (x, y) (tile coordinate x, tile number y) to the offset of `x + t * y`, mode by
  mode, in the original layout. For every flat layout of every rank, every tile and every
  coordinate.
* `Lay.zippedDivide_size`: when every tile extent divides the matching extent, the divided layout
  has the original size.
* When a tile extent does not divide the extent, the division floors and elements are lost
  (section 3).

### 2.10 blocked product (`blocked-product`)

* `Lay.blockedProduct_call`: for a flat block and a flat tiler of the same rank (at least 2),
  the product maps the coordinate whose mode `i` is `(xᵢ, yᵢ)` to `block(x) + size(block) *
  tiler(y)`. This is the code, which multiplies by the block's size; the docstring says cosize.
* The two agree on compact blocks (cosize = size). On a block whose cosize exceeds its size the
  copies overlap (section 3).

### 2.11 upcast (`upcast`)

* `Lay.upcast_modes`: on a flat layout whose strides are positive multiples of the factor `f`,
  upcast keeps the extents and divides the strides by `f`.
* `Lay.upcast_call`: under the same premise, `f * upcast(L)(c) = L(c)` for every coordinate with
  one leaf per mode.
* A mode of stride 0 gets the extent `shape_div(s, shape_div(f, 0))`, which is 0 in the model
  (instance in the test file) and in the compiler's output (section 5): upcast[2] of (4):(0) is
  (0):(0), a layout of size 0.
* A stride that the factor does not divide becomes 1 (`shape_div` gives 1 when there is no
  divisibility): upcast[2] of (2, 2):(2, 7) is (2, 2):(1, 1) in the model and in the compiler's
  output.
* Not stated: a positive stride that divides the factor, such as the stride-1 mode of the
  docstring's example `row_major[4, 8]`, where the extent is divided instead; remaining work.

### 2.12 swizzle (`swizzle`)

* `Swizzle.call_call`: when `bits ≤ |shift|`, the swizzle is its own inverse, for every value,
  base and shift (positive or negative). It is therefore a bijection. The step is
  `Swizzle.shiftr_and_mask`: the shifted source bits miss the source mask.
* When `bits > |shift|`, the involution fails; Mojo's compile-time interpreter skips the
  constructor's check (section 3).

### 2.13 bit layout (`bit-layout`)

* `Swizzle.call_xor`: a swizzle is linear over F2: `S(x ^ y) = S(x) ^ S(y)` for every swizzle.
* Not stated: the linearity of strided modes with power-of-two extents and the `BitLayout` type.

### 2.14 two-level swizzle (`two-level-swizzle`)

Not stated: the model has no `two_level_layout_from_swizzle`; remaining work.

### 2.15 index width (`index-width`)

* `Lay.call_flat_ofNat`: the dot product computed in `w`-bit arithmetic (each `cₖ * dₖ` and the
  sum wrapped to `w` bits) is the model's offset reduced mod `2^w`, for every width and every flat
  layout; so when the offset is below `2^w` the narrow result is exact (`Lay.call_flat_toNat`).
  It is a per-call obligation: the caller must show the offset fits.

## 3. Counterexamples

Each is an `example` by `decide` in `MojoProofTest/LayoutLaws.lean`, on the model. The
conformance test (section 5) compiles the same five inputs, and the compiler's values are the
model's, so each bug is in the code Mojo compiles, not only in the model. Each item gives the
premise under which the law holds (section 2).

* composition (filed as modular/modular #7738): A = (6,2):(1,6), B = (3):(4). The model,
  like Mojo, gives (3):(6), so B's index 1 goes to 6; A(B(1)) = A(4) = 4. B's stride 4 and
  A's first extent 6 do not divide each other, so B fails `composeDiv`, the premise under which
  the composite is A after B (2.8).
* blocked_product: block (2):(2), tiler (2):(1). The indices 1 and 2 both go to the offset
  2. The code and its docstring agree when the block is compact (2.10).
* idx2crd: (2,2):(3,1) maps the coordinate (1,0) to 3 and idx2crd maps 3 to (1,1). The
  inverse holds when the modes are nested in order or in reverse order (2.2).
* zipped_divide: (5):(1) by the tile 2 has size 4; no index reaches the element 4. The size
  is kept when every tile extent divides its extent (2.9).
* Swizzle(2, 0, 1): applied twice to 6 it gives 7. The swizzle is an involution when
  `bits ≤ |shift|` (2.12).

## 4. The transcription

Each model definition and the Mojo function it transcribes, at modular/modular bbc13a71.

| Mojo | file:line | Lean (`MojoProof.Layout.`) |
| --- | --- | --- |
| `Coord` node, `ComptimeInt` | coord.mojo:186, :97 | `Tup` |
| `__len__` | coord.mojo:125-131, :307 | `Tup.len` |
| `value()` | coord.mojo | `Tup.value` |
| `flatten` | coord.mojo:524 | `Tup.leaves`, `Tup.leavesL` |
| `product` | coord.mojo:368 | `Tup.size` |
| `crd2idx` | coord.mojo:856 (hierarchical 899-904, flat 908 via `_crd2idx_flat` :795, scalar 914-935, leaf 936-953) | `crd2idx`, `zipIdx`, `splitIdx` |
| `idx2crd` | coord.mojo:958, :1067; `_linear_idx_to_coord` :1966; static 1 at 1037-1042 | `idx2crd`, `idx2crdL` |
| `Layout` | layout.mojo:329 | `Lay` |
| `Layout.__call__` | layout.mojo:484 (513-538) | `Lay.call` |
| `Layout.size`, `product` | layout.mojo:616-635 | `Lay.size` |
| `Layout.cosize` | layout.mojo:639-653 | `Lay.cosize` |
| `Layout.reverse`, `transpose` | layout.mojo:656-667, :670 | `Lay.reverse` |
| `row_major(shape)` | layout.mojo:1002 (strides 1029-1048) | `rowMajor` |
| `_shape_div`, `_comptime_shape_div`, `_runtime_shape_div` | layout.mojo:1501, :2094, :2199 | `shapeDiv` |
| `_compose_leaf` | layout.mojo:1509 (loop 1533-1545, last mode 1546-1551) | `composeStep`, `composeLeaf` |
| `composition`, `_compose_mode` | layout.mojo:1641, :1556 | `Lay.compose` |
| `zipped_divide` | layout.mojo:1407 (1427-1432, 1457) | `Lay.zippedDivide` |
| `blocked_product` | layout.mojo:1954 (`BlockedProductLayout` :1884; size at 1995, 2016) | `Lay.blockedProduct` |
| `upcast` | layout.mojo:2218 (2263-2296) | `Lay.upcast` |
| `_CoalesceReducerIdx`, `coalesce` | layout.mojo:2316-2358, :2462 (start 2380) | `coalesceStep`, `Lay.coalesce` |
| `shiftr` | swizzle.mojo:236 | `shiftr` |
| `Swizzle`, `yyy_mask`, `__call__` | swizzle.mojo:274, :337, :369-381 | `Swizzle`, `Swizzle.mask`, `Swizzle.call` |

The transcription is trusted: no proof connects these definitions to the Mojo source. The
conformance test is the check that it does connect them on the recorded cases.

## 5. The conformance test

`tests/layout/` holds a Mojo program generated from a seed by `tests/layout/gen.py`: a GPU
kernel that stores the values of layout functions on random static layouts (offsets, cosizes,
coalesced offsets, the offsets and sizes of zipped divides, blocked products and compositions,
upcast shapes and strides, swizzled values, idx2crd coordinates) into its output, with the
inputs of the five counterexamples among them. It is compiled to LLVM IR, never run; the compiler
evaluates the static layout functions, so the values are constants in the stores of the
kernel's IR. `tests/layout/extract.py` reads them and writes `MojoProofTest/LayoutConformance.lean`,
which checks by `decide` that the model gives the same values. `tests/layout/record.txt`
records the shapes, the seed, the Mojo version and the result. The kernel's IR is kept as
`tests/layout/conformance.nvptx.ll`, so the check can be rerun without Mojo.

The result at seed 1729, Mojo 1.3.0.dev2026111705 for sm_80: the model agrees with the compiler
on all 37 cases (323 values). In particular the compiler gives the counterexamples' values:
`composition((6,2):(1,6), (3):(4))` has the offsets 0, 6, 12;
`blocked_product((2):(2), (2):(1))` the offsets 0, 2, 2, 4; `idx2crd` maps 3 in (2,2):(3,1) to
(1,1); `zipped_divide[2]((5):(1))` has size 4; and `Swizzle(2, 0, 1)` maps 6 to 5 and 5 to 7.

This is a test, not a proof: it covers the recorded cases only, all with static leaves, and the
program is compiled, never run, so it says nothing of layouts with runtime leaves (which the
compiler does not fold) or of the GPU.
