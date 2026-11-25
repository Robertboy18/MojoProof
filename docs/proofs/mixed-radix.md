# Mixed-radix indices at symbolic sizes

Lean: `GPUProof/MixedRadix.lean`. Tests: `MojoProofTest/GPUProof/MixedRadix.lean`.

**Scope.** `MixedRadix.lt_prod`, `MixedRadix.eq_iff_digits`, `MixedRadix.val_append` and
`MixedRadix.fits` hold for every size assignment (every two, for `eq_iff_digits`), radix list and
width; `WordFit.of_lt` for every width and number. The tests
prove gemv's write index and the naive matmul's offset facts for every size and thread, and check
the theorems by evaluation at two launches and two matrices of unrelated sizes. Nothing here is
about one kernel's program: the gemv and matmul statements are about the index expressions, not
about the IR that computes them.

## Definitions

* `Sizes`, a size assignment: `Nat → Nat`, the value of each numbered size variable. A variable
  may stand for a size, a launch register, the member count of a level instance or a bound
  index.
* `SizeExpr`, a symbolic size: a variable `var v`, a product `mul a b` or a quotient `div a b`
  (rounded down, `0` when the divisor is `0`); `SizeExpr.eval σ` is its value at `σ`.
* `MixedRadix`: a list of digits with their radices, both `SizeExpr`s, the least significant
  first. At `σ`:
  * `val`: Horner's rule, `d₀ + r₀ (d₁ + r₁ (d₂ + …))` for the digits `dᵢ` with radices `rᵢ`;
  * `digitVals`: the digits' values;
  * `radixProd`: the product of the radices' values;
  * `InRange`: every digit's value is below its radix's (decidable).
* `WordFit w k`, what a width of `w` bits keeps of the index `k`, four fields over Lean's
  `BitVec`:
  * `toNat`: the `w`-bit word of `k` has the unsigned value `k` (truncation to `w` bits keeps it);
  * `toInt`: it has the signed value `k`;
  * `signExtend`: its sign extension to every width `v` is the `v`-bit word of `k`;
  * `add`: for every `a + b = k`, the add of the `w`-bit words of `a` and `b` overflows neither
    unsigned (`BitVec.uaddOverflow`) nor signed (`BitVec.saddOverflow`), so an LLVM `add` with
    `nuw` or `nsw` is not poison, and gives the word of `k`.

No definition fixes a machine constant: there is no warp width, word width or grid size in the
module.

## Statements

* `MixedRadix.lt_prod (hx : x.InRange σ) : x.val σ < x.radixProd σ`.
* `MixedRadix.eq_iff_digits (hx : x.InRange σ) (hy : y.InRange τ)
  (hr : x.digits.map (fun p => p.2.eval σ) = y.digits.map (fun p => p.2.eval τ)) :
  x.val σ = y.val τ ↔ x.digitVals σ = y.digitVals τ`, at two size assignments: the radices of `x`
  at `σ` have the values of the radices of `y` at `τ`. At one assignment with the same radix
  list, `hr` is `rfl`.
* `MixedRadix.val_append (a b) (σ) : val ⟨a ++ b⟩ σ = val ⟨a⟩ σ + radixProd ⟨a⟩ σ * val ⟨b⟩ σ`,
  Horner's rule split at a digit.
* `MixedRadix.fits (hx : x.InRange σ) (h : x.radixProd σ < 2 ^ (w - 1)) : WordFit w (x.val σ)`.
* `WordFit.of_lt (h : k < 2 ^ (w - 1)) : WordFit w k`, and `WordFit.two_mul_lt_iff :
  2 * k < 2 ^ w ↔ k < 2 ^ (w - 1)`, which turns the premise `2 k < 2 ^ w` of the MojoProof index
  lemmas into `of_lt`'s.

## Proof

* `lt_prod`: induction on the digits; `d + r v < r + r v = r (v + 1) ≤ r · P` from `d < r` and the
  tail's `v < P`.
* `eq_iff_digits`: induction on the digits of `x`, with `y`'s in step (radix values that agree
  give the same length). The step is `MixedRadix.add_mul_eq_iff`:
  `a + r v = b + r v' ↔ a = b ∧ v = v'` for `a, b < r`, by the remainder and the quotient by `r`,
  with the radix `r` at `σ` equal to the one at `τ` by `hr`'s head.
* `val_append`: induction on `a`; the step is `d + r (v_a + P_a v_b) = (d + r v_a) + (r P_a) v_b`.
* `of_lt`: from `2 k < 2 ^ w` (`two_mul_lt_iff`) the word's sign bit is clear, so its signed value
  is its unsigned one, `k`, and its sign extension is its zero extension. For `a + b = k` both
  parts are below `2 ^ (w - 1)`, so neither sum overflows, as natural numbers or as integers, and
  `BitVec.ofNat_add_ofNat` gives the word of `k`.
* `fits`: `of_lt` after `lt_prod`.

## What exists elsewhere

* Mathlib has the value of digits in one base (`Nat.ofDigits`), its bound
  (`Nat.ofDigits_lt_base_pow_length`), its injectivity at a fixed length
  (`Nat.ofDigits_inj_of_len_eq`), and the two-digit mixed radix with constant sizes
  (`finProdFinEquiv`, `Fin.divNat`, `Fin.modNat`). None has radices that vary by digit, so
  `eq_iff_digits` and `lt_prod` are written here; their one-base cases are Mathlib's.
* FloatLib has digits in base `2 ^ w` (`FloatLib.Numerics.Packed.ofDigits_lt`, the lanes of a
  packed row), again one base. TorchLean names no theorem on row-major or strided index bounds or
  injectivity.
* The layout algebra's colexicographic digits (`MojoProof.Layout.colex`, with
  `MojoProof.Layout.colex_length`, `colex_append` and `colex_mod` in MojoProof/Layout/Crd.lean)
  go the other way, from a value to its digits; its offset lemmas recover the digits of a
  strided offset (`MojoProof.Layout.digits_of_nested`) or bound it by the cosize
  (`MojoProof.Layout.sum_colex_le`), at extents that are numbers. None is `lt_prod` or
  `eq_iff_digits`, so nothing there becomes a corollary.
* MojoProof/Sem/Index.lean is the use (it imports this module; the core cannot import it). Its
  word lemmas at `2 k < 2 ^ w` are corollaries of `WordFit.of_lt` through `two_mul_lt_iff`: the
  signed value of the word (`BitVec.toInt_ofNat_of_lt`) is the field `toInt`, sign extension
  (`intCast_sext_ofNat`) the field `signExtend`, the two overflow tests of the flagged add
  (`intBin_add_ofNat`) the field `add`, and the signed range (`outS_of_lt`) is
  `k < 2 ^ (w - 1)`. `coord_onto`'s bound is `lt_prod` at the three digits of a point of a box.
  `trunc` and `zext` of a word of `k < 2 ^ w` (`intCast_ofNat`) stay there: `WordFit` holds
  below `2 ^ (w - 1)` only.

## Where the Lean form departs from the design

* `SizeExpr` has a quotient. The design's sizes are variables and products; gemv's warp count per
  block is `ntid / W`, so a radix needs `div`.
* `fits` has the premise `x.InRange σ`. The design's has only `x.radixProd σ < 2 ^ (w - 1)`, which
  does not bound the value of an index whose digits are out of range: `mutant_range` in the
  tests is an index out of range whose radix product is below `2 ^ 7` and whose value does not
  fit 8 bits, so the design's statement is false without the premise.
* `WordFit` is a structure over `BitVec` with the four fields above, the design's "sign
  extension, truncation and non-wrapping adds", where truncation is the unsigned value and a
  non-wrapping add is the absence of both overflows.
* The size variables are numbered (`Sizes := Nat → Nat`) rather than named.

## Tests (`MojoProofTest/GPUProof/MixedRadix.lean`)

For every size and thread:

* `gemv_val`: gemv's write index `(ctaid * ntid + tid) / W` is the value of `warpIdx`, the warp
  `tid / W` with radix `ntid / W` and the block `ctaid` with radix the grid size, when `W`
  divides `ntid` (every size assignment).
* `gemv_warp`: two threads of the launch write the same index exactly when they are in the same
  warp of the same block, by `eq_iff_digits` at one assignment (`hr` is `rfl`).
* `warp_two`: the same statement for one key, `warpIdx 0 1`, at the two threads' assignments, by
  `eq_iff_digits` at two assignments. The assignments differ in the variables `0` and `1` (the
  thread), which the radices `ntid / W` and the grid size do not read, so `hr` is `rfl`.
* `warp_split`: `warpIdx 0 1` split after its warp digit, by `val_append` (every size
  assignment); `warp_split_37` evaluates it at thread `37` of block `1` with `ntid = 128`,
  `W = 32`: `1 + 4 · 1 = 5 = (1 · 128 + 37) / 32`.
* `gemv_lt`: the index is below `(ntid / W) * grid`, the number of rows written, by `lt_prod`.
* `gemv_fits`: it fits `w` bits when `(ntid / W) * grid < 2 ^ (w - 1)`, by `fits`; `fits_32` is an
  instance at a launch of two blocks of 128 threads.
* `matmul_eq`: `row * n + k = row' * n + k' ↔ row = row' ∧ k = k'` for `k, k' < n` at symbolic
  `n`, by `eq_iff_digits` with the radix `row + row' + 1` above both rows; the `example` after it
  checks that `omega` alone fails on the same goal.

By evaluation (`#guard`), over every pair of threads of the launches `ntid = 96, W = 32` with three
blocks and `ntid = 15, W = 5` with seven blocks (`launchOk`), and over every pair of entries of
`3 × 4` and `5 × 7` matrices (`matrixOk`): `InRange`, `lt_prod`, `eq_iff_digits`, `gemv_val`,
`gemv_warp` and `matmul_eq`, and `radixProd` as the size `(ntid / W) * grid` (`SizeExpr.mul`).

The mutants, decided, one per rule:

* `mutant_out`: thread `tid = ntid` of block `0` writes the index of block `1`'s first warp while
  the digits differ; its digit `tid / W` is out of range, so `eq_iff_digits` fails.
* `mutant_lt`: the same thread of the last block writes the radix product, not below it.
* `mutant_dvd`: with `W` not dividing `ntid`, the write index is not `warpIdx`'s value.
* `mutant_radices`: two indices in range with other radices are equal with other digits.
* `mutant_assign`: `hr` cannot be dropped at two assignments: `warpIdx 0 1` at `ntid = 96` and at
  `ntid = 128` (`W = 32`) is in range at both with the value `3`, the warp radices `3` and `4`
  differ, and the digits (`0, 1` and `3, 0`) differ.
* `mutant_fits`: `2 ^ (w - 1)` does not fit `w` bits (`¬ WordFit 8 128`: the signed value of the
  word is `-128`).
* `mutant_range`: the premise `InRange` of `fits` cannot be dropped: the digit `200` with radix
  `1` has the radix product `1 < 2 ^ 7` and the value `200`, which does not fit 8 bits (the signed
  value of its word is `-56`).

## Footprints at symbolic sizes: the statements of `View.tiling` and `View.coarsen_tile`

**Status.** Statements and plan only: no module defines them yet. The Lean below elaborates
against this tree's `GPUProof.Sig`, `GPUProof.MixedRadix` and the layout algebra of
MojoProof/Layout/ (checked with the proofs left open, outside the repository); the proofs are
the plan after it. It goes in a new core module, GPUProof/View.lean, after the layout algebra's
move into the core (below), and imports Mathlib's `Set.iUnion` and `Pairwise` beside it. The
code opens `GPUProof.Layout` and `GPUProof.Layout.Tup` (the moved namespaces) and takes
`variable {S : Sig}`.

### Definitions

```lean
/-- The instances of level `ℓ` in launch `L`: those that a thread of `L` lies in. -/
def Sig.Inst (S : Sig) (L : S.Launch) (ℓ : S.Level) (g : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L ℓ t = g

/-- The sets `T i` tile `D`: each lies in `D`, and two of different indices are disjoint. -/
def Tiling {ι α : Type} (T : ι → Set α) (D : Set α) : Prop :=
  (∀ i, T i ⊆ D) ∧ Pairwise fun i j => Disjoint (T i) (T j)

/-- A footprint at symbolic sizes: at each size assignment `σ`, instance `g` of `level` in
launch `L` covers the bytes of buffer `buf` at the offsets `key · cosize + lay(c)`, for the
coordinates `c` below the layout's size, where `key` is valued at `bind L g σ`, the assignment
`σ` with the variables of the key's digits set to `g`'s coordinates. -/
structure View (S : Sig) where
  lay : Sizes → Lay
  level : S.Level
  buf : S.Buf
  key : MixedRadix
  bind : S.Launch → S.Gid → Sizes → Sizes

namespace View

/-- The offset of coordinate `c` of instance `g`. -/
def off (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) (c : Nat) : Nat :=
  v.key.val (v.bind L g σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false)

/-- The bytes of instance `g`. -/
def tile (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Set S.Loc :=
  {x | ∃ c < (v.lay σ).size, x = S.place v.buf (v.off σ L g c)}

/-- The bytes the view may cover: the first `radixProd · cosize` offsets of its buffer. -/
def bytes (v : View S) (σ : Sizes) : Set S.Loc :=
  {x | ∃ i : Nat, i < v.key.radixProd σ * (v.lay σ).cosize ∧ x = S.place v.buf i}

/-- The tiles of the instances of the view's level in `L`. -/
def tiles (v : View S) (σ : Sizes) (L : S.Launch) : {g // S.Inst L v.level g} → Set S.Loc :=
  fun g => v.tile σ L g.1

/-- A well-formed view, at every size assignment: its layout is congruent with positive
extents (so `Lay.call_lt_cosize` bounds its offsets), and at every instance of its level the
key is in range, its radices do not read the bound digits, and the digits tell the instances
apart. -/
structure WF (v : View S) : Prop where
  congruent : ∀ σ, congruentL (v.lay σ).shape (v.lay σ).stride = true
  pos : ∀ σ, ∀ s ∈ leavesL (v.lay σ).shape, 0 < s
  range : ∀ σ L g, S.Inst L v.level g → v.key.InRange (v.bind L g σ)
  radices : ∀ σ L g, S.Inst L v.level g →
    v.key.digits.map (fun p => p.2.eval (v.bind L g σ)) = v.key.digits.map (fun p => p.2.eval σ)
  key_inj : ∀ σ L g g', S.Inst L v.level g → S.Inst L v.level g' →
    v.key.digitVals (v.bind L g σ) = v.key.digitVals (v.bind L g' σ) → g = g'

/-- The key's `n` least significant digits, and the others. -/
def inner (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.take n⟩
def outer (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.drop n⟩

/-- Instance `j` of the view's level lies in instance `i` of `ℓ`: a thread of `L` is in both. -/
def Inside (v : View S) (L : S.Launch) (ℓ : S.Level) (i j : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L v.level t = j ∧ S.group L ℓ t = i

/-- The view at level `ℓ`: the key's `n` least significant digits become one more layout mode,
of extent their radix product and stride the cosize; `bind'` binds the other digits at an
instance of `ℓ`. -/
def coarsen (v : View S) (ℓ : S.Level) (n : Nat) (bind' : S.Launch → S.Gid → Sizes → Sizes) :
    View S where
  lay σ := ⟨(v.lay σ).shape ++ [leaf ((v.inner n).radixProd σ) false],
    (v.lay σ).stride ++ [leaf (v.lay σ).cosize false]⟩
  level := ℓ
  buf := v.buf
  key := v.outer n
  bind := bind'
```

### Statements

```lean
/-- For every machine whose placement is injective, well-formed view, size assignment and
launch, the tiles of the instances of the view's level are in bounds and pairwise disjoint. -/
theorem View.tiling (v : View S) (hp : PlaceInj S.place) (hv : v.WF) (σ : Sizes)
    (L : S.Launch) : Tiling (v.tiles σ L) (v.bytes σ)

/-- For every machine, well-formed view, level `ℓ`, digit count `n`, binding, size assignment,
launch and instance `i` of `ℓ`: when the instances inside `i` agree on the outer digits and
realize every inner key value, the coarsened view's tile of `i` is the union of their tiles. -/
theorem View.coarsen_tile (v : View S) (hv : v.WF) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hn : ∀ j, v.Inside L ℓ i j → (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ (v.inner n).val (v.bind L j σ) = k) :
    (v.coarsen ℓ n bind').tile σ L i = ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j
```

Two changes to this module that they need are made (**Status.** Proved, with the tests
`warp_two`, `mutant_assign`, `warp_split` and `warp_split_37` above):

* `MixedRadix.eq_iff_digits` is restated at two assignments, `(hx : x.InRange σ)
  (hy : y.InRange τ) (hr : x.digits.map (fun p => p.2.eval σ) = y.digits.map (fun p => p.2.eval τ))
  : x.val σ = y.val τ ↔ x.digitVals σ = y.digitVals τ`, by the same induction. The earlier
  statement, at one assignment with the premise that the two radix lists are equal, is its case
  `τ = σ` and is not kept; its uses in the tests compare two indices with the same radices, so
  they pass `rfl` for the new premise. Two instances of a view are valued at two assignments
  (`bind L g σ`, `bind L g' σ`), which is why the one-assignment form does not serve.
* `MixedRadix.val_append`: `MixedRadix.val ⟨a ++ b⟩ σ = MixedRadix.val ⟨a⟩ σ +
  MixedRadix.radixProd ⟨a⟩ σ * MixedRadix.val ⟨b⟩ σ`, Horner's rule split at a digit, for
  `coarsen_tile`.

### Proof plan

* `View.tiling`, bounds: an offset is `k C + a` with `k` the key's value and `C` the cosize;
  `k` is below the radix product at `bind L g σ` (`MixedRadix.lt_prod`, `WF.range`), which is
  the radix product at `σ` (`WF.radices`), and `a < C` (`Lay.call_lt_cosize`, `WF.congruent`,
  `WF.pos`), so `k C + a < (k + 1) C ≤ radixProd σ · C`.
* `View.tiling`, disjointness: a byte of two tiles is `place buf (k C + a) = place buf (k' C + a')`;
  `PlaceInj` gives `k C + a = k' C + a'`, `MixedRadix.add_mul_eq_iff` with `a, a' < C` gives
  `k = k'`, the two-assignment `eq_iff_digits` (with `WF.range` and `WF.radices` at both) equal
  digits, and `WF.key_inj` the same instance. Only `PlaceInj`'s injectivity in the offset is
  used, since a view has one buffer; two views on different buffers are disjoint by its other
  half (`b = b'`).
* `View.coarsen_tile`: the coarse layout's call at `c' < size · R` (with `R` the inner radix
  product) is `call (c' % size) + C · (c' / size)` (the layout algebra's `colex_append` through
  `Lay.call_scalar`), and its cosize is `C R`. `val_append` splits the key at `j` as
  `inner + R · outer`, where `R` at `bind L j σ` is `R` at `σ` (`WF.radices`) and `outer` is the
  coarse key at `i` (`hn`). So an offset of `j`'s tile at `c` is the coarse offset at
  `inner · size + c` (with `inner < R` by `lt_prod`), and a coarse offset at `c'` is the offset of
  the instance `j` that `ho` gives for `k = c' / size`, at `c' % size`.

### Where the statements depart from the design

* `[Place S]` is the premise `PlaceInj S.place`, the core's law (the field `Sig.placeInj` carries
  it when a machine gives one). It is `Place.inj` and `Place.disjoint` in one implication.
* `lay` is a layout at each size assignment, `Sizes → Lay`, not a layout term with symbolic
  extents: the layout algebra computes at extents that are numbers, and quantifying over `σ`
  covers every size without a second, symbolic copy of it.
* A view has `bind`, the assignment at an instance, because a key's digits are size expressions
  over numbered variables and an instance's coordinates must enter them; `WF.radices` keeps the
  radices independent of the instance.
* `Tiling` takes the set it tiles, `v.bytes σ`: "in bounds" is a subset of the first
  `radixProd · cosize` offsets of the buffer.
* `View.coarsen` takes the digit count `n` and the coarse binding `bind'`, and `coarsen_tile` the
  premises `hn` and `ho`. Without `ho` the equation is false when an inner radix exceeds the
  instances inside `i`: a warp digit whose radix is one more than a block's warp count gives a
  coarse tile with a row that no warp of the block covers. The design's `v.level ≤ ℓ` is not a
  premise: the proof does not use it, and `Inside` says which instances nest.

### Instances and tests planned

* gemv's output vector: the warp level, the one-element layout `⟨[leaf 1 true], [leaf 1 true]⟩`,
  the key `warpIdx` of the tests above with `bind` setting the warp's first lane and its block;
  `WF.key_inj` holds because the digits `tid / W` and `ctaid` name the warp (as in `gemv_warp`).
  Coarsened at the block level with `n = 1`, a block's tile is its `ntid / W` rows, by `ho` when
  `W` divides `ntid`; the mutant is a warp digit whose radix is one more than the block's warp
  count, where `ho` fails and the equation is refused.
* The naive matmul's output: the thread level, the one-element layout, the key `entryIdx` (the
  column with radix `n`, the row with radix `m`); `WF.key_inj` holds because the row and the
  column name the thread, and `matmul_eq` is the two digits' case of `eq_iff_digits`.
* Evaluation at two launches and two matrix sizes, as the tests above, and a mutant of each `WF`
  field (a key out of range, a radix that reads a bound digit, two instances with one key).

### The layout algebra's move into the core

The laws the views reindex by (`rowMajor_inj` and `Lay.compose_call` in Layout/Laws.lean,
`Swizzle.call_call` in Layout/Swizzle.lean, `placement_call` in Layout/Bits.lean,
`Swizzle.twoLevel_call` in Layout/TwoLevel.lean) are mathematics about layouts. The move, one
build of its own, with no aliases and no import-only files:

* Lean: MojoProof/Layout/Basic.lean (no import), Algebra.lean, Crd.lean, Laws.lean, Bits.lean,
  Swizzle.lean and TwoLevel.lean (which import only each other) become GPUProof/Layout/*.lean,
  namespace `MojoProof.Layout` becoming `GPUProof.Layout`. No MojoProof module outside the
  directory imports them, so no library module changes but these.
* The core's import test, MojoProofTest/GPUProof/Imports.lean, imports the seven modules (it
  fails unless every file under GPUProof/ is imported there) and checks that they reach neither
  `MojoProof` nor `TorchLean`.
* lakefile.lean:47, the glob `.submodules `MojoProof.Layout`, is deleted; `lean_lib GPUProof`'s
  glob covers the moved modules.
* Tests: MojoProofTest/LayoutLaws.lean (imports, lines 1-3, and `open`, line 24) moves to
  MojoProofTest/GPUProof/LayoutLaws.lean. MojoProofTest/LayoutConformance.lean (lines 1, 8, 16)
  and MojoProofTest/LayoutRuntime.lean (lines 1, 10, 20) stay: they test the claim that the
  model is Mojo's library. They are generated, so their generators change with them:
  tests/layout/extract.py:181, 188 and 197, tests/layout/runtime/extract.py:110, 118 and 128, and
  the headers tests/layout/record.txt:3 and tests/layout/runtime/record.txt:3.
* The trusted base: T16, the claim that the model is Mojo's layout library, stays MojoProof's.
  Its row in docs/TRUST.md:22 cites the moved paths, and scripts/trust.tsv:32-36 lists the five
  modules by name.
* scripts/laws.tsv:11-15, the five layout laws, and scripts/targets.txt's layout section (33
  lines) take the new namespace.
* Documents: docs/proofs/layout-laws.md (7 references), this file (lines 71-75),
  docs/proofs/README.md:517, roadmap/layout/README.md:38, the 15 layout cards under
  roadmap/layout/cards/ and roadmap/status.yaml (15); docs/DEPENDENCIES.md and docs/deps/ are
  regenerated. The ledger's rows keep the paths of their time.
* Not moved: the tensor-core fragment maps (MojoProof/Sem/TensorCore.lean), which are
  transcriptions of the PTX tables, fixed at 32 lanes and importing TorchLean.
