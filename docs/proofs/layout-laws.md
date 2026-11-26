# The layout laws

This document states the laws of the layout library of Modular's kernels at modular/modular
bbc13a71 (`max/kernels/src/layout/` and `Mojo/stdlib/std/utils/coord.mojo`) that MojoProof
proves about its Lean model of that library, one law per card of `roadmap/layout/cards/`. It
gives the model, then each law with its premises and its scope, then the bugs that the model
shows by a counterexample, then the transcription table and the conformance test that compares
the model with the values the Mojo compiler computes.

The Lean statements are the reference. Every law below holds for all inputs that meet its
premises unless its scope says otherwise; the concrete instances and the counterexamples are in
`MojoProofTest/GPUProof/LayoutLaws.lean`. The model lives in the core, under `GPUProof/Layout/`
(namespace `GPUProof.Layout`), apart from the LLVM data layout `MojoProof.Sem.Layout`.

## 1. The model

`GPUProof/Layout/Basic.lean`.

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
* **Division by zero.** The model's `a / 0` is 0 and its `a % 0` is `a`, Lean's natural-number
  division and remainder (`Nat.div_zero`, `Nat.mod_zero`). This matters in three places: idx2crd
  with a stride 0 (the coordinate is then `(i / 0) % s`, which is `0 % s`, so 0); a remainder by
  an extent 0, which keeps the whole dividend (`colex 5 [0]` is `[5]`, and `idx2crd` and
  `splitIdx` do the same at an extent 0); and `shape_div` with a divisor 0 (`upcast` of a
  stride-0 mode, whose extent becomes 0). The compiler gives the same in the last case on the
  conformance test's upcast of (4):(0) (section 5).
  Mojo's integer `//` and `%` by 0 both give 0 (`Int` is `Scalar[DType.int]`,
  std/simd.mojo:111, whose `__floordiv__`, `__mod__` and `__divmod__` select 0 for a divisor
  0), so in the second case Mojo and the model differ: the CPU run of section 5 gives the
  offset 0 at the scalars 1 and 5 of (0, 2):(1, 10), where the model's are 1 and 5. These
  scalars are past the size 0, and the laws about a scalar's offset (`Lay.call_scalar` and the
  laws built on it) ask for a scalar below the size. `idx2crd_flat` has no such
  bound: its leaves `(x / d) % s` are `x / d` in the model at an extent 0, and 0 in Mojo, whose
  idx2crd takes the remainder with `umod` (coord.mojo:1966-1967; from the source, not run), so
  at an extent 0 that law describes the model and not Mojo.

`GPUProof/Layout/Algebra.lean` transcribes the functions that build one layout from others
(`coalesce`, `composition`, `zipped_divide`, `blocked_product`, `upcast`) and the XOR swizzle
`Swizzle`. The layouts they return have static leaves. `GPUProof/Layout/Bits.lean` transcribes
`BitLayout` of `bit_layout.mojo`, a map over F2 from domain bits to codomain points, and
`is_bit_linear` and `placement` on flat static layouts. It computes on natural numbers where Mojo
computes on `UInt64`; the two agree while every image, span and offset is below `2 ^ 64`.
`GPUProof/Layout/TwoLevel.lean` transcribes `TwoLevelLayout.__call__` of
`two_level_layout.mojo` on a flat static outer layout, and `two_level_layout_from_swizzle` with
its two asserts on flat static layouts; Mojo computes in `Int`, and the two agree while every
offset is below `2 ^ 63`.

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
* `Lay.call_mixed` and `crd2idx_mixed`: on a layout whose shape and stride are congruent, a mixed
  coordinate has the offset `Σₖ digitₖ * dₖ` over the shape's leaves. A mixed coordinate
  (`fits`) is, against each mode, a leaf of any value against a leaf extent, a leaf below the
  size of a tuple mode, or a tuple of at least two elements against a tuple mode of as many
  modes, at any depth; its digits (`digits`) are a leaf's own value against a leaf extent and
  its colexicographic digits against a tuple mode. Every shape. On (2,(2,3)):(1,(2,4)) the
  coordinates (1, 5) and (1, (1, 2)) both have the digits (1, 1, 2) and the offset 11.
* The bound is needed: in (1, 6) on that layout, 6 is not below the size 6 of the mode (2,3),
  so `crd2idx` gives the mode's last leaf the whole quotient 3 and the offset is 13, where the
  digits (0, 0) of 6 would give 1 (instance in the test file). A tuple of one element is not a
  mixed coordinate: `crd2idx` reads it as a scalar.

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

`TensorLayout.is_affine` (layout.mojo:116-120) says whether a layout's offset is a sum of
coordinate times stride; code that steps through memory by adding a stride must check it.
`Layout` keeps the trait's default `True`, so `Lay.isAffine` is `true` on every layout of the
model.

* `Lay.isAffine_flat`: on a flat layout, `is_affine` holds and so does what it promises: adding
  `n` to the `k`-th element of a coordinate with one leaf per mode adds `n` times the `k`-th
  stride to the offset. Every flat layout, mode and `n`, with no bound on the coordinate.
* `Lay.call_add`: on a flat layout, the offset of the sum of two coordinates with one leaf per
  mode is the sum of their offsets. Every flat layout.
* On a nested layout the offset of a mixed coordinate is a sum of digits times strides
  (`Lay.call_mixed`, 2.1), but a step past a mode's bound carries into the next digit, so the
  stepping law is stated for flat layouts only.
* Not modelled: the two-level layouts, which set `is_affine` to `False`
  (two_level_layout.mojo:520).
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

* `Lay.compose_sum`: for every layout A and every layout B whose shapes and strides are
  congruent (nested ones included), where each of B's flattened modes meets `composeDiv` on A's
  flattened modes but the last, and every scalar coordinate v below B's size with B(v) below A's
  size, the composite has B's size and gives v the offset `Σₖ A(xₖ * dₖ)` over B's flattened
  modes (extent sₖ, stride dₖ), the xₖ being v's colexicographic digits against the sₖ. This is
  how `composition` builds the composite: each mode of B composed on its own (`_compose_mode`,
  layout.mojo:1556), the results side by side.
* `Lay.compose_call`: under the same premises, when the terms xₖ * dₖ do not carry against A's
  extents (`noCarry`), the composite gives v the offset A(B(v)). `noCarry` checks, extent by
  extent, that the terms' remainders add to less than the extent, and then the same for their
  quotients against the remaining extents; then A adds over the terms (`dotColex_sum`). A B of
  one mode meets it at every v (`noCarry_one`), so the law for one mode is the case of a single
  term. `composition` asserts B's cosize at most A's size (layout.mojo:1664-1669), which gives
  B(v) below A's size.
* `Lay.compose_all`: the law at every coordinate under premises on A and B alone. Each of B's
  flattened modes (s, d) has the term list d * x for x < s; when these lists are `carryFree`
  against A's extents (at each extent, the largest remainders of the lists add up to less than
  the extent, the same for their quotients against the remaining extents, and every quotient
  past the last extent is 0) and B's modes meet `composeDiv`, the composite gives every v below
  B's size the offset A(B(v)). `carryFree_pick` turns `carryFree` into B(v) below A's size and
  `noCarry` at every v, the per-coordinate premises of `Lay.compose_call`. The check costs the
  sum of B's extents, not their product. It is sufficient; that it is necessary is not proved.
* `composeLeaf_prod_dot` is the law for one leaf, on lists of modes, for every stride: a stride
  0 meets `composeDiv` and composes to the single mode (s, 0).
* `composeDiv` is the divisibility premise, taken mode by mode as `_compose_leaf` crosses A's
  modes: at a mode of extent a, with the stride r and the extent e that remain, either a divides
  r, or r divides a and e is at most a / r or a multiple of it. CuTe's stride and shape
  divisibility conditions imply it.
* An instance with three modes: A = `row_major[4, 8]` = (4,8):(8,1) and the tile B =
  (2,(2,2)):(1,(8,16)) give the composite (2,2,2):(8,2,4); its term lists [0, 1], [0, 8] and
  [0, 16] are `carryFree` against (4, 8), so it is A after B everywhere by `Lay.compose_all`
  (the compiler gives the same offsets, section 5).
* An instance at a second size, with two modes: A = `row_major[8, 16]` = (8,16):(16,1) and the
  tile B = (4,4):(2,16) of rows 0, 2, 4, 6 by columns 0, 2, 4, 6 give the composite
  (4,4):(32,2); its term lists [0, 2, 4, 6] and [0, 16, 32, 48] are `carryFree` against
  (8, 16), so it is A after B at all 16 coordinates by `Lay.compose_all`.
* The twin without `composeDiv`: A = (6,2):(1,6) and B = (3):(4), since neither of 4 and 6
  divides the other; the composite is not A after B (section 3). B's term list [0, 4, 8] is
  `carryFree` against (6, 2), so `carryFree` does not imply `composeDiv`.
* The twins without `noCarry`, where each mode of B meets `composeDiv` and B's cosize is within
  A's size: A = (2,2):(1,10) and B = (2,2):(1,1) give 2 at the index 3, where A(B(3)) = A(2) =
  10 (the terms 1 and 1 carry against A's extent 2); and A = (6,2):(1,100) with the injective B
  = (3,2):(2,3) give 7 at the index 5, where A(B(5)) = A(7) = 101 (the terms 4 and 3 carry
  against 6). Neither B is `carryFree` against its A. The compiler gives the same values
  (section 3).

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

* `Lay.upcast_fuse`: on a flat layout whose strides are positive, each a multiple of the factor
  `f` or a divisor `d` of a positive `f` with `f / d` dividing the extent, upcast keeps the
  extent and divides the stride by `f` on a multiple of `f`, and divides the extent by `f / d`
  and makes the stride 1 on a divisor. The docstring's example, upcast[2] of `row_major[4, 8]`
  = (4,8):(8,1), is (4,4):(4,1) (instance in the test file, and the compiler's output,
  section 5).
* `Lay.upcast_scale`: on a flat layout whose strides are positive, each a multiple or a divisor
  of `f`, `f * upcast(L)(c)` is the offset in L of `c` with each leaf `cₖ` multiplied by
  `shape_div(f, dₖ)`: by 1 on a multiple of `f`, by `f / dₖ` on a divisor, whose `f / dₖ`
  consecutive elements upcast fuses into one. For every coordinate with one leaf per mode, with
  no bound on it.
* `Lay.upcast_modes` and `Lay.upcast_call` are the case where every stride is a multiple of
  `f`: upcast keeps the extents, divides the strides by `f`, and `f * upcast(L)(c) = L(c)`.
* A mode of stride 0 gets the extent `shape_div(s, shape_div(f, 0))`, which is 0 in the model
  (instance in the test file) and in the compiler's output (section 5): upcast[2] of (4):(0) is
  (0):(0), a layout of size 0.
* A stride that the factor does not divide becomes 1 (`shape_div` gives 1 when there is no
  divisibility): upcast[2] of (2, 2):(2, 7) is (2, 2):(1, 1) in the model and in the compiler's
  output.
* A divisor stride whose `f / d` does not divide the extent: upcast[2] of (3):(1) is (1):(1),
  since `shape_div(3, 2)` is 1, a layout of size 1 for the 3 / 2 elements of width 2 (section 3).

### 2.12 swizzle (`swizzle`)

* `Swizzle.call_call`: when `bits ≤ |shift|`, the swizzle is its own inverse, for every value,
  base and shift (positive or negative). It is therefore a bijection. The step is
  `Swizzle.shiftr_and_mask`: the shifted source bits miss the source mask.
* When `bits > |shift|`, the involution fails; Mojo's compile-time interpreter skips the
  constructor's check (section 3).

### 2.13 bit layout (`bit-layout`)

* `BitLayout.call_xor`: every bit layout is linear over F2, `m(x ^ y) = m(x) ^ m(y)`, for every
  map (any images and any domain mask) and every pair of points.
* `placement_call`: for every flat layout that `is_bit_linear` accepts (every extent a power of
  two, every stride 0 or a power of two, and the spans `bits(log2(stride), log2(extent))` of the
  modes with a nonzero stride pairwise disjoint), with extents and strides below `2 ^ 64` and a
  size of at most `2 ^ 64`, the placement's domain mask is the size minus 1 and the placement
  maps every point below the size to the layout's offset of that point. The step is
  `xorBits_place`: the images of the coordinate bits XOR to the sum of digits times strides,
  because the disjoint spans make each XOR an addition with no carry.
* `Swizzle.call_xor`: a swizzle is linear over F2: `S(x ^ y) = S(x) ^ S(y)` for every swizzle.
* Without `is_bit_linear`'s stride conditions the module docstring's sentence "A layout whose
  extents are powers of two is linear over F2" (bit_layout.mojo:15) is false (section 3).
* Not modelled: `kill`, `run` and the `dead` mask (on `__call__`, `kill d` acts as `put d 0`),
  nested layouts, and the bits from 64 on.

### 2.14 two-level swizzle (`two-level-swizzle`)

* `Swizzle.twoLevel_call`: for every swizzle (any bits, base and shift, positive or negative)
  and every flat layout that passes the asserts of `two_level_layout_from_swizzle` (every extent
  and stride a power of two, `swizzleValid`, and no offset bit reached by the inner bits of two
  modes, `Swizzle.disjoint`), with extents and strides below `2 ^ 64`, the two-level layout's
  value is `Swizzle(L(x))` at every tuple coordinate with one leaf per mode, each inside its
  extent, and at every scalar index below the size. Mode `i` gives its
  `k = min(log2 extent, max(0, period - log2 stride))` low bits to the inner map
  (`Swizzle.innerBits`), where the period is `base + bits + |shift|`.
* The steps: `Swizzle.twoLevel_parts` splits the offset mode by mode into an outer part, a
  multiple of `2 ^ period` inside the shape, and an inner part below `2 ^ period`, whose
  disjoint spans make its XOR an addition; the inner images XOR to the swizzle of the inner
  part by the swizzle's linearity (`Swizzle.call_xor`, through `xorBits_map` and
  `xorBits_stride`); and `Swizzle.call_add`: the swizzle changes no bit from its period on
  (`Swizzle.testBit_call`), so adding a multiple of `2 ^ period` commutes with it.
* Without disjoint inner bits, or at a tuple coordinate past an extent, the equation fails; with
  a zero shift, `Lambda` is not injective (section 3).
* Not modelled: nested and runtime outer layouts, a nonzero `x0` (the constructor's is 0),
  `idx2crd`, and offsets from bit 63 on.

### 2.15 index width (`index-width`)

* `Lay.call_flat_ofNat`: the dot product computed in `w`-bit arithmetic (each `cₖ * dₖ` and the
  sum wrapped to `w` bits) is the model's offset reduced mod `2^w`, for every width and every flat
  layout; so when the offset is below `2^w` the narrow result is exact (`Lay.call_flat_toNat`).
  It is a per-call obligation: the caller must show the offset fits.

## 3. Counterexamples

Each is an `example` by `decide` in `MojoProofTest/GPUProof/LayoutLaws.lean`, on the model. The
conformance test (section 5) compiles the same inputs, and the compiler's values are the
model's, so each bug is in the code Mojo compiles, not only in the model. Each item gives the
premise under which the law holds (section 2).

* composition (filed as modular/modular #7738): A = (6,2):(1,6), B = (3):(4). The model,
  like Mojo, gives (3):(6), so B's index 1 goes to 6; A(B(1)) = A(4) = 4. B's stride 4 and
  A's first extent 6 do not divide each other, so B fails `composeDiv`, the premise under which
  the composite is A after B (2.8).
* composition with a B of two modes: A = (2,2):(1,10), B = (2,2):(1,1) map 3 to 2, where
  A(B(3)) = 10; and A = (6,2):(1,100), B = (3,2):(2,3), with B injective and its cosize 8
  within A's size 12, map 5 to 7, where A(B(5)) = 101. Both meet `composeDiv` mode by mode and
  `composition`'s cosize assert, while its docstring says the result "maps `B`'s coordinates
  through `B`, then through `A`" (layout.mojo:1644-1645). The law holds when B's terms do not
  carry against A's extents (`noCarry`, 2.8), at every coordinate when B's term lists are
  `carryFree` against A's extents (`Lay.compose_all`).
* blocked_product: block (2):(2), tiler (2):(1). The indices 1 and 2 both go to the offset
  2. The code and its docstring agree when the block is compact (2.10).
* idx2crd: (2,2):(3,1) maps the coordinate (1,0) to 3 and idx2crd maps 3 to (1,1). The
  inverse holds when the modes are nested in order or in reverse order (2.2).
* zipped_divide: (5):(1) by the tile 2 has size 4; no index reaches the element 4. The size
  is kept when every tile extent divides its extent (2.9).
* Swizzle(2, 0, 1): applied twice to 6 it gives 7. The swizzle is an involution when
  `bits ≤ |shift|` (2.12).
* bit layout, model only (the conformance test does not compile `BitLayout`): (2,2):(1,1) has
  extents and strides that are powers of two, maps 1 and 2 to 1 and 3 to 2, so it is not linear
  over F2 (1 ^ 1 = 0), while the module docstring says "A layout whose extents are powers of two
  is linear over F2" (bit_layout.mojo:15). Its two modes reach the offset bit 0, so
  `is_bit_linear` refuses it, and its placement maps 3 to 0. The placement is the layout when
  `is_bit_linear` holds (2.13).
* two-level swizzle, model only (the conformance test does not compile `TwoLevelLayout`):
  `Swizzle(1, 0, 1)` on (2, 2):(1, 1) gives both modes' bit 0 to the inner map, with the image
  1, so `_swizzle_inner_bits_disjoint` refuses the layout; at (1, 1) the images cancel and the
  two-level layout gives 0, where `Swizzle(L(1, 1))` = 3. On (2, 2):(1, 2), which passes both
  asserts, the tuple coordinate (2, 0), past the extent 2, keeps the outer coordinate 1 of
  stride 2 below the period and gives 2, where `Swizzle(L(2, 0))` = 3, while the docstring says
  "for every coordinate `x`" (two_level_layout.mojo:1108-1109). The equation holds inside
  the shape (2.14). With a zero shift, which the integer overload accepts, `Swizzle(1, 0, 0)` on
  (2):(1) sends the indices 0 and 1 both to 0, while the module docstring says "`Lambda` is
  injective" (line 29).
* upcast[2] of (3):(1) is (1):(1), of size 1, with no assert: `shape_div(3, 2)` is 1, though
  `_shape_div`'s docstring says the result 1 is for `a` dividing `b` (layout.mojo:1501-1506).
  The extents are kept or divided exactly when `f / d` divides the extent (2.11).

## 4. The transcription

Each model definition and the Mojo function it transcribes, at modular/modular bbc13a71.

| Mojo | file:line | Lean (`GPUProof.Layout.`) |
| --- | --- | --- |
| `Coord` node, `ComptimeInt` | coord.mojo:186, :97 | `Tup` |
| `__len__` | coord.mojo:125-131, :307 | `Tup.len` |
| `value()` | coord.mojo | `Tup.value` |
| `flatten` | coord.mojo:524 | `Tup.leaves`, `Tup.leavesL` |
| `product` | coord.mojo:368 | `Tup.size` |
| `crd2idx` | coord.mojo:856 (hierarchical 899-904, flat 908 via `_crd2idx_flat` :795, scalar 914-935, leaf 936-953) | `crd2idx`, `zipIdx`, `splitIdx` |
| `idx2crd` | coord.mojo:958, :1067; `_linear_idx_to_coord` :1966; static 1 at 1037-1042 | `idx2crd`, `idx2crdL` |
| `Layout` | layout.mojo:329 | `Lay` |
| `TensorLayout.is_affine` | layout.mojo:116-120 (`Layout` keeps the default, :329) | `Lay.isAffine` |
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
| `BitLayout`, `BitLayout()` | bit_layout.mojo:66-82, :84-88 | `BitLayout`, `BitLayout.empty` |
| `put` | bit_layout.mojo:90-104 | `BitLayout.put` |
| `BitLayout.__call__` | bit_layout.mojo:168-182 | `BitLayout.call`, `xorBits` |
| `bits` | bit_layout.mojo:52-62 | `bitsMask` |
| `_log2`, `_power_of_two` | bit_layout.mojo:222-223, :226-227 | `log2` (`trailingZeros`), `powerOfTwo` |
| `is_bit_linear` | bit_layout.mojo:230-258 | `isBitLinear`, `bitLinear` |
| `placement` | bit_layout.mojo:261-283 | `placement`, `placeModes`, `placeMode` |
| `_TwoLevelLayout`, `_InnerImage`, `_InnerBitCount` | two_level_layout.mojo:471-631, :86, :63 | `TwoLevel` |
| `_FullShapeTabulator` | two_level_layout.mojo:240-248 | `TwoLevel.shape` |
| `TwoLevelLayout.__call__` | two_level_layout.mojo:633-698 (scalar 666-680, inner bits 684-691, result 697) | `TwoLevel.call`, `TwoLevel.offset`, `innerXor` |
| `_SwizzlePeriod`, `_SwizzleInnerBits` | two_level_layout.mojo:956-959, :962-976 (`_log2_or_zero` :140) | `Swizzle.period`, `Swizzle.innerBits` |
| `two_level_layout_from_swizzle`, `SwizzledTwoLevelLayout`, `_SwizzleOuter`, `_SwizzleInner` | two_level_layout.mojo:1101-1133, :1049-1064, :1015-1047, :978-1013 | `Swizzle.twoLevel` |
| `_swizzle_layout_valid`, `_swizzle_inner_bits_disjoint` | two_level_layout.mojo:1066-1078, :1081-1098 | `swizzleValid`, `Swizzle.disjoint` |

The transcription is trusted: no proof connects these definitions to the Mojo source. The
conformance test is the check that it does connect them on the recorded cases.

## 5. The conformance test

`tests/layout/` holds a Mojo program generated from a seed by `tests/layout/gen.py`: a GPU
kernel that stores the values of layout functions on random static layouts (offsets, cosizes,
coalesced offsets, the offsets and sizes of zipped divides, blocked products and compositions,
upcast shapes and strides, swizzled values, idx2crd coordinates) into its output, with the
inputs of the counterexamples among them. It is compiled to LLVM IR, never run; the compiler
evaluates the static layout functions, so the values are constants in the stores of the
kernel's IR. `tests/layout/extract.py` reads them and writes `MojoProofTest/LayoutConformance.lean`,
which checks by `decide` that the model gives the same values. `tests/layout/record.txt`
records the shapes, the seed, the Mojo version and the result. The kernel's IR is kept as
`tests/layout/conformance.nvptx.ll`, so the check can be rerun without Mojo.

The result at seed 1729, Mojo 1.3.0.dev2026111705 for sm_80: the model agrees with the compiler
on all 43 cases (351 values). In particular the compiler gives the counterexamples' values:
`composition((6,2):(1,6), (3):(4))` has the offsets 0, 6, 12;
`composition((2,2):(1,10), (2,2):(1,1))` the offsets 0, 1, 1, 2 and
`composition((6,2):(1,100), (3,2):(2,3))` the offsets 0, 2, 4, 3, 5, 7;
`blocked_product((2):(2), (2):(1))` the offsets 0, 2, 2, 4; `idx2crd` maps 3 in (2,2):(3,1) to
(1,1); `zipped_divide[2]((5):(1))` has size 4; `Swizzle(2, 0, 1)` maps 6 to 5 and 5 to 7; and
`upcast[2]((3):(1))` is (1):(1). The instances agree too: the tile of `row_major[4, 8]` has the
offsets 0, 8, 2, 10, 4, 12, 6, 14, upcast[2] of `row_major[4, 8]` is (4,4):(4,1), and the
mixed coordinates (1, 5) and (1, (1, 2)) of (2,(2,3)):(1,(2,4)) have the offset 11.

This is a test, not a proof: it covers the recorded cases only, all with static leaves, and the
program is compiled, never run, so it says nothing of layouts with runtime leaves (which the
compiler does not fold) or of the GPU.

Layouts with runtime leaves have their own test, in `tests/layout/runtime/`: a CPU program,
`runtime.mojo`, builds 9 layouts whose extents and strides are `Int64`s offset by a
command-line argument, so the compiler cannot fold them (c3 mixes in the static `Idx[2]` and
`Idx[1]`), and prints each one's offsets, size and cosize. Mojo 1.3.0.dev2026111705 compiles
it, the CPU runs it with the argument 0, and `tests/layout/runtime/extract.py` writes
`MojoProofTest/LayoutRuntime.lean` from the printed values; `tests/layout/runtime/record.txt`
records the run. The model agrees with the run on 8 cases (79 values): flat (3,4):(1,3),
(2,3,2):(6,1,0) with a stride 0, nested (2,(2,3)):(1,(2,4)), the mixed (2,3):(3,1), and the
runtime `upcast` (`_runtime_shape_div`) of `row_major[4, 8]` (the offsets of (4,4):(4,1)), of
(3):(1) (size 1, no assert), of (4,3):(3,1) and of (4):(0) (size 0, cosize 1). It differs on
one: at the scalars 1 and 5 of (0,2):(1,10), past the size 0, Mojo gives the offset 0 and the
model 1 and 5, since Mojo's remainder by 0 is 0 and the model's keeps the dividend (section 1,
division by zero); `MojoProofTest/LayoutRuntime.lean` states the model's values there and
quotes the run's. This too is a test, not a proof: one run of these 9 layouts on one CPU,
nothing about other shapes or the GPU.
