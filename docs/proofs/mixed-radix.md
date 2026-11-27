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
* The layout algebra's colexicographic digits (`GPUProof.Layout.colex`, with
  `GPUProof.Layout.colex_length`, `colex_append` and `colex_mod` in GPUProof/Layout/Crd.lean)
  go the other way, from a value to its digits; its offset lemmas recover the digits of a
  strided offset (`GPUProof.Layout.digits_of_nested`) or bound it by the cosize
  (`GPUProof.Layout.sum_colex_le`), at extents that are numbers. None is `lt_prod` or
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

## Footprints at symbolic sizes: `View.tiling` and `View.coarsen_tile`

**Status.** Proved. GPUProof/View.lean, a core module, defines `Sig.Inst`, `View` (with the
instances that own a tile, `owns`), `View.Owner`, `View.WF`, `View.off`, `View.tile`, `Tiling`,
`View.bytes`, `View.tiles`, `View.inner`, `View.outer`, `View.Inside` and `View.coarsen` as below,
for every machine, and proves the six statements below, `View.tiling`, `View.cover`,
`View.cover_iff`, `View.tile_subset_coarsen`, `View.coarsen_tile` and `View.key_fits`, with the
lemmas the proofs name (`off_lt`, `coarsen_size`, `coarsen_congruent`, `coarsen_call`,
`coarsen_cosize`, `inner_at`, `coarsen_tileAt`). At a key stride it defines `View.offAt`,
`View.tileAt`, `View.tilesAt`, `View.bytesAt`, `View.Interleaved`, `View.Separated` and
`View.coarsenAt` and proves `View.tilingAt`, with the lemmas `key_eq_of_mod` and
`interleaved_cosize` (below, "Interleaved footprints"), `View.tiling_separated`,
`View.separated_of_disjoint` and `View.separated_of_interleaved` (below, "Separated
footprints"), and `View.coverAt`, `View.cover_iffAt`, `View.tile_subset_coarsenAt` and
`View.coarsenAt_tile`, of which `cover`, `cover_iff`, `tile_subset_coarsen` and `coarsen_tile`
are the cases at the cosize (below, "Coverage and coarsening at a key stride"). Under a bound
on the offset it defines `View.guardAt` and `View.guardsAt` and proves `GPUProof.Tiling.mono`,
`View.guardAt_subset`, `View.tile_subset_guardAt` and `View.cover_guardAt` (below, "Guarded
tiles"). It imports Mathlib's `Disjoint` on sets, `Pairwise`,
the notation for `⋃` and `ring`. Its test, MojoProofTest/GPUProof/View.lean, has the two views at
MojoProof's machine, with the tile of each instance, their tilings and coverage at two launches
each, a view whose tiles overlap, gemv's warps past its rows, whose bytes no tile covers, gemv
coarsened at the block level with its partly owned last block, and the refused coarsening (below,
"Instances and tests"); MojoProofTest/GPUProof/ViewTiling.lean gives a well formed view's tiles at
that machine as MojoProof's `Tiling` of byte intervals, MojoProofTest/GPUProof/ViewWords.lean
relates the two views' offsets, and layer norm's at its key stride, to the kernels' 32- and 64-bit
words, and MojoProofTest/GPUProof/ViewStride.lean has layer norm's interleaved view at a key
stride, at every row length under the guard. A view's
offsets and tiles are natural numbers, a model of the addresses a kernel computes in words that
wrap; the tile theorems are about that model, and the theorems that relate it to the words name
the word premise (`View.key_fits`). That a run of a kernel stores at the address of its tile is
not proved here.
`View.lay` and `WF`'s `congruent` and `pos` read `Lay`, `congruentL` and `leavesL`, which the
core has since the layout algebra's move (below); a core module imports only `GPUProof.*`,
Mathlib and FloatLib (MojoProofTest/GPUProof/Imports.lean). The code opens `GPUProof.Layout` and
`GPUProof.Layout.Tup` and takes `variable {S : Sig}`.

### Definitions

```lean
/-- The instances of level `ℓ` in launch `L`: those that a thread of `L` lies in. -/
def Sig.Inst (S : Sig) (L : S.Launch) (ℓ : S.Level) (g : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L ℓ t = g

/-- The sets `T i` tile `D`: each lies in `D`, and two of different indices are disjoint. -/
def Tiling {ι α : Type} (T : ι → Set α) (D : Set α) : Prop :=
  (∀ i, T i ⊆ D) ∧ Pairwise fun i j => Disjoint (T i) (T j)

/-- A footprint at symbolic sizes: at each size assignment `σ`, instance `g` of `level` in
launch `L` that `owns` a tile covers the bytes of buffer `buf` at the offsets
`key · cosize + lay(c)`, for the coordinates `c` below the layout's size, where `key` is valued
at `bind L g σ`, the assignment `σ` with the variables of the key's digits set to `g`'s
coordinates. An instance that owns no tile covers no byte. -/
structure View (S : Sig) where
  lay : Sizes → Lay
  level : S.Level
  buf : S.Buf
  key : MixedRadix
  bind : S.Launch → S.Gid → Sizes → Sizes
  owns : S.Launch → S.Gid → Sizes → Prop

namespace View

/-- The owners: the instances of the view's level in `L` that own a tile at `σ`. -/
def Owner (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Prop :=
  S.Inst L v.level g ∧ v.owns L g σ

/-- The offset of coordinate `c` of instance `g`. -/
def off (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) (c : Nat) : Nat :=
  v.key.val (v.bind L g σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false)

/-- The bytes of instance `g`: none when `g` owns no tile. -/
def tile (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Set S.Loc :=
  {x | v.owns L g σ ∧ ∃ c < (v.lay σ).size, x = S.place v.buf (v.off σ L g c)}

/-- The bytes the view may cover: the first `radixProd · cosize` offsets of its buffer. -/
def bytes (v : View S) (σ : Sizes) : Set S.Loc :=
  {x | ∃ i : Nat, i < v.key.radixProd σ * (v.lay σ).cosize ∧ x = S.place v.buf i}

/-- The tiles of the instances of the view's level in `L`. -/
def tiles (v : View S) (σ : Sizes) (L : S.Launch) : {g // S.Inst L v.level g} → Set S.Loc :=
  fun g => v.tile σ L g.1

/-- A view well formed at the size assignment `σ` and the launch `L`: its layout at `σ` is
congruent with positive extents (so `Lay.call_lt_cosize` bounds its offsets), and at every
owner the key is in range, its radices do not read the bound digits, and the digits tell the
owners apart. A view is well formed at the assignments and launches its kernel admits, not at
every one: at the assignment `0` every radix is `0`, so no owner's digits are in range. -/
structure WF (v : View S) (σ : Sizes) (L : S.Launch) : Prop where
  congruent : congruentL (v.lay σ).shape (v.lay σ).stride = true
  pos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s
  range : ∀ g, v.Owner σ L g → v.key.InRange (v.bind L g σ)
  radices : ∀ g, v.Owner σ L g →
    v.key.digits.map (fun p => p.2.eval (v.bind L g σ)) = v.key.digits.map (fun p => p.2.eval σ)
  key_inj : ∀ g g', v.Owner σ L g → v.Owner σ L g' →
    v.key.digitVals (v.bind L g σ) = v.key.digitVals (v.bind L g' σ) → g = g'

/-- The key's `n` least significant digits, and the others. -/
def inner (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.take n⟩
def outer (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.drop n⟩

/-- Instance `j` of the view's level lies in instance `i` of `ℓ`: a thread of `L` is in both. -/
def Inside (v : View S) (L : S.Launch) (ℓ : S.Level) (i j : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L v.level t = j ∧ S.group L ℓ t = i

/-- The view at level `ℓ`: the key's `n` least significant digits become one more layout mode,
of extent their radix product and stride the cosize; `bind'` binds the other digits at an
instance of `ℓ`, which owns a tile when an owner lies in it. -/
def coarsen (v : View S) (ℓ : S.Level) (n : Nat) (bind' : S.Launch → S.Gid → Sizes → Sizes) :
    View S where
  lay σ := ⟨(v.lay σ).shape ++ [leaf ((v.inner n).radixProd σ) false],
    (v.lay σ).stride ++ [leaf (v.lay σ).cosize false]⟩
  level := ℓ
  buf := v.buf
  key := v.outer n
  bind := bind'
  owns L i σ := ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ
```

### Statements

```lean
/-- For every machine whose placement is injective, view, size assignment and launch at which
the view is well formed, the tiles of the instances of the view's level are in bounds and
pairwise disjoint. -/
theorem View.tiling (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) : Tiling (v.tiles σ L) (v.bytes σ)

/-- For every machine, view, size assignment, launch and bound `B`: when every offset below the
layout's cosize is a coordinate's (`hl`) and every key value below `B` is an owner's (`hk`), the
owners' tiles cover the first `B · cosize` bytes of the view's buffer. -/
theorem View.cover (v : View S) {σ : Sizes} {L : S.Launch} {B : Nat}
    (hl : ∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a)
    (hk : ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g

/-- For every machine whose placement is injective, view, size assignment and launch at which
the view is well formed, and positive bound `B`: `cover`'s premises are the least, the tiles
covering the first `B · cosize` bytes only when `hl` and `hk` hold. -/
theorem View.cover_iff (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) {B : Nat} (hB : 0 < B) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g ↔
      (∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a) ∧
        ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k

/-- For every machine, view, size assignment and launch at which the view is well formed, owner
`g` and width `w` at which the key's radix product is below `2 ^ (w - 1)` (the word premise):
`g`'s key value fits `w` bits. -/
theorem View.key_fits {v : View S} {σ : Sizes} {L : S.Launch} {g : S.Gid} (hv : v.WF σ L)
    (hg : v.Owner σ L g) {w : Nat} (hw : v.key.radixProd σ < 2 ^ (w - 1)) :
    WordFit w (v.key.val (v.bind L g σ))

/-- For every machine, view, level `ℓ`, digit count `n`, binding, size assignment and launch at
which the view is well formed, and instance `i` of `ℓ`: when the owners inside `i` agree on the
outer digits, the tiles of the instances inside `i` lie in the coarsened view's tile of `i`. -/
theorem View.tile_subset_coarsen (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ)) :
    ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j ⊆ (v.coarsen ℓ n bind').tile σ L i

/-- For every machine, view, level `ℓ`, digit count `n`, binding, size assignment and launch at
which the view is well formed, and instance `i` of `ℓ`: when the owners inside `i` agree on the
outer digits and realize every inner key value, the coarsened view's tile of `i` is the union
of the tiles of the instances inside it. -/
theorem View.coarsen_tile (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ ∧ (v.inner n).val (v.bind L j σ) = k) :
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

### Proofs

* `View.tiling`, bounds (`off_lt`): a byte of a tile is at an owner (the tile of an instance that
  owns none is empty), and its offset is `k C + a` with `k` the key's value and `C` the cosize;
  `k` is below the radix product at `bind L g σ` (`MixedRadix.lt_prod`, `WF.range`), which is
  the radix product at `σ` (`WF.radices`), and `a < C` (`Lay.call_lt_cosize`, `WF.congruent`,
  `WF.pos`), so `k C + a < (k + 1) C ≤ radixProd σ · C`.
* `View.tiling`, disjointness: `View.tilingAt`'s at the key stride `C`, the cosize, where the
  layout interleaves as every offset is below `C` (`interleaved_cosize`). `View.tilingAt`,
  disjointness: `View.tiling_separated`'s, as an interleaving layout is separated
  (`separated_of_interleaved`: with `R` the radix product and `a, a'` below `d` modulo `R d`,
  `a = a' + m d` with `0 < m < R` would give `0 = m` by `key_eq_of_mod`). `tiling_separated`,
  disjointness: a byte of two tiles is `place buf (k d + a) = place buf (k' d + a')`; `PlaceInj`
  gives `k d + a = k' d + a'`; with `k, k' < R`, `k < k'` would make `a = a' + (k' - k) d`, which
  `Separated` forbids, so `k = k'`, the two-assignment `eq_iff_digits` (with `WF.range` and
  `WF.radices` at both) equal digits, and `WF.key_inj` the same instance. Its bounds:
  `k + 1 ≤ R` and `a` below the cosize put `k d + a` below `R d + cosize - d`. Only
  `PlaceInj`'s injectivity in the offset is used, since a view has one buffer; two views on
  different buffers are disjoint by its other half (`b = b'`).
* `View.cover`: byte `i < B C` is `place buf i`, with `C` the cosize (positive, as a cosize is
  `call (size - 1) + 1`); `hk` gives the owner `g` whose key value is `i / C < B`, and `hl` the
  coordinate `c` at offset `i % C < C`, so `off g c = (i / C) C + i % C = i`. No `WF`: the step
  reads neither the key's range nor the layout's bounds.
* `View.cover_iff`: `cover` is one direction. Conversely, for `k < B` and `a < C`, byte
  `k C + a` (below `B C`) is in the tile of an owner `g` at a coordinate `c`; `PlaceInj` gives
  `k C + a = val · C + call c`, with `call c < C` (`Lay.call_lt_cosize`, `WF.congruent`,
  `WF.pos`), so `MixedRadix.add_mul_eq_iff` gives `call c = a` and `val = k`. `hl` is the case
  `k = 0` (which `0 < B` allows) and `hk` the case `a = 0` (`0 < C`). `hl` reads `0 < B`: at
  `B = 0` there are no bytes, and the left side holds at every layout.
* `View.tile_subset_coarsen` and `View.coarsen_tile`: the coarse layout is congruent
  (`coarsen_congruent`), its size is `size · R` with `R` the inner radix product
  (`coarsen_size`), its call at `c' < size · R` is `call (c' % size) + C · (c' / size)`
  (`coarsen_call`: the layout algebra's `colex_append` through `Lay.call_scalar`), and its
  cosize is `C R` (`coarsen_cosize`, `Lay.cosize_eq`).
  `val_append` splits the key at `j` as `inner + R · outer`, where `R` at `bind L j σ` is `R` at
  `σ` (`WF.radices`, `inner_at`) and `outer` is the coarse key at `i` (`hn`); `off_coarsenAt`
  is the step below, at every key stride. So an offset of `j`'s tile at `c` is the coarse offset at
  `inner · size + c` (with `inner < R` by `lt_prod`), and a coarse offset at `c'` is the offset of
  the owner `j` that `ho` gives for `k = c' / size`, at `c' % size`. A byte of `j`'s tile is at
  an owner `j`, which is the coarse `owns`'s witness; a byte of the coarse tile is in the tile of
  the owner that `ho` gives. The first inclusion, `tile_subset_coarsen`, reads `hn` and not
  `ho`, and `coarsen_tile` takes it for its `⊇` half.
* Every step reads `WF` at the statement's `σ` and `L` only, so `hv : v.WF σ L` serves: the
  bounds read `range` and `radices` at the owner `g` of `L` and `congruent` and `pos` at `σ`;
  disjointness reads `range` and `radices` at the owners `g` and `g'` and `key_inj` at the two;
  `cover` reads no field and `cover_iff` `congruent` and `pos` at `σ`; `tile_subset_coarsen`
  and `coarsen_tile` read `range` and `radices` at the owners `j` inside `i`, which are instances
  of the view's level in `L` (`Inside` gives the thread), and `congruent` and `pos` at `σ`.

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
* Coverage is not a clause of `Tiling` but a second statement beside `View.tiling`, `View.cover`
  with its converse `View.cover_iff`, and `Tiling` stays the one notion of tiling (bounds and
  disjointness), as `MojoProof.Sem.Tiling` (MojoProof/Sem/Trace.lean:146) has no coverage clause
  either. Coverage of `bytes` fails at views whose tiling holds: at gemv with more warps than
  rows, the bytes from `4 m` up are in `bytes` and in no tile (`gemv_uncovered`, below), and the
  tiles tile `bytes` there (`gemv_tiling`); a clause in `Tiling` would make that view's tiling
  false. `cover` takes the bound `B` of the key values the owners have (`m` at gemv, `bytes`'s
  radix product at the naive matmul), and at every positive `B` its premises are the least
  (`cover_iff`): `hl`, the layout onto its cosize, and `hk`, every key value below `B` an
  owner's; at `B = 0` the covered set is empty, and a layout with holes covers it.
* `WF` is at one size assignment and launch, `v.WF σ L`, and `View.tiling` and
  `View.coarsen_tile` take it there. The design's `WF` at every assignment and launch holds for
  no view whose key has a digit and which has an owner at an assignment where its radices are
  `0`: there a size expression is `0`, so by `radices` the digit's radix at the owner is `0` and
  `range` fails (gemv's warp view at one thread and `m = 1`). A kernel admits some assignments and
  launches, those whose radices are positive and whose sizes are the ones the launch describes;
  each view proves `WF` there, `∀ σ L, adm σ L → v.WF σ L`, for its own predicate `adm`. Guarding
  each field by `adm` inside `WF` gives the same theorems with one more field of `View`, so the
  assignment and launch are parameters instead.
* A view has the instances that own a tile, `owns`, and `WF` and the tiles are over them (the
  owners, `View.Owner`; the tile of an instance that owns none is empty). A kernel's launch may have
  threads past its data that write nothing: `MojoProof.Tile.MatSetup.Fits` admits launches that only
  cover the rows (`naive_rows` launches `max m 1` blocks), and gemv and the naive matmul skip the
  store past `m` (and `n`), by the `icmp sge` cited under "Instances and tests". Without the guard,
  a footprint at the matrix's sizes fails `WF.range` at such a thread, and one at the launch's
  extents claims bytes that no thread writes. The other choice, launches of exactly the data's size,
  refuses every launch whose threads go past the data and puts that condition on every kernel's
  admissible launches; the guard is one field, and the theorems read it at owners only:
  `View.tiling` reads `WF` at owners, as the tile of another instance is empty, and
  `View.coarsen_tile` takes `hn` and `ho` at owners, the coarse view owning a tile at an instance
  with an owner in it.
* `View.coarsen` takes the digit count `n` and the coarse binding `bind'`, and `coarsen_tile` the
  premises `hn` and `ho`. Without `ho` the equation is false when an inner radix exceeds the
  instances inside `i`: a warp digit whose radix is one more than a block's warp count gives a
  coarse tile with a row that no warp of the block covers (`gemv_coarsen_radix`, below), and so
  does a last block that is partly owned (`gemv_partial`, below). The inclusion of the tiles
  inside `i` in its coarse tile holds without `ho` (`tile_subset_coarsen`), at every such
  instance. The coarse layout is not clipped to the owners inside `i`: `lay` is a layout at each
  size assignment, the same at every instance, and the inner digits' extent is their radix
  product at `σ`, so a clip at the last block would be a layout that depends on the instance. The
  design's `v.level ≤ ℓ` is not a premise: the proof does not use it, and `Inside` says which
  instances nest.

### Instances and tests

MojoProofTest/GPUProof/View.lean has the two views at MojoProof's machine `MojoProof.Sem.sig`,
over GPUProof/View.lean's definitions. An instance of level `l` there is
`(l, Launch.groupNum L l t)` for a thread `t` below the thread count, so `Inst` costs one
`List.mem_range` (`inst_sig`); `sig`'s `place b i` is byte `i` of buffer `b`. Both views have
the layout of one 4-byte float, `elem 4` with `elem w = Lay.flat [(w, 1)]` (size and cosize `w`,
coordinate `c` at offset `c`), so the tile of an owner with key `k` is bytes `4 k` to `4 k + 3`,
a natural-number model of the float that the kernel stores at element `k`: the kernel computes
the element in 32- and 64-bit words, which give that element under the word premise
(ViewWords.lean, the last item below). gemv stores at
`getelementptr inbounds float, ptr %0, i64 %36`
(tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll:50, the
store at :136), and the naive matmul at `getelementptr inbounds float, ptr %10, i64 %39`
(tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll:41,
the store at :84); below, "gemv's IR" and "the naive matmul's IR" are these two files.

* gemv's output vector (`gemv_wf`): the warp level (level 1), the key `warpIdx 0 1` of the tests
  above, `bind` setting the variables 0 and 1 to the `tid.x` and `ctaid.x` of the warp's first
  thread, and a warp owning a tile when its key is below `m` (the variable 7), as the kernel's
  `icmp sge` of the row against `m` (gemv's IR :55) skips the store. It is admitted (`gemvAdm`) at
  the launches with side 1 in `y` and `z` where the variables `4`, `5` and `6` are `ntid.x`, `32`
  and `nctaid.x`, and `32` divides `ntid.x`. There the warp of thread `t` has
  `tid.x = 32 (t % B / 32)` and `ctaid.x = t / B`, with `B = ntid.x` (`warp_regs`), which give
  `WF.range` (`inRange_warpIdx`) and `WF.key_inj` (the first thread is
  `B · (t / B) + 32 · (t % B / 32)`, `warp_base`). The key at the warp of every thread `t` is `t`'s
  row `(ctaid.x · ntid.x + tid.x) / 32`, the row gemv's IR computes (:13-21, broadcast from lane 0
  at :24-25) (`gemv_row`, by `gemv_val` and `Launch.index_oneDim`), and the warp's tile is bytes
  `4 · row` to `4 · row + 3` of `y` when `row < m`, and none otherwise (`gemv_tile`, a
  natural-number model: gemv's words give this row and guard when `m < 2 ^ 31`, `gemv_words`).
  The mutants:
  at grid (1,2,1) and block (32,1,1) (`gemv_gridY`) `gemvAdm` fails, the warps of threads 0 and 32
  are both in row 0, the binding by the flattened thread number (block `t / B` and offset `t % B`,
  `flatBind`) gives them the keys 0 and 1 though in the model the kernel stores one float twice
  (its row, :13-21, reads no `y` register), and `WF` fails (`key_inj`); at `m = 1`, the other
  variables 0 and the launch of one thread (`gemv_zero`) the guard and `WF` fail (warp `(1, 0)`
  owns row 0, and its warp digit and radix are 0), so `WF` at every assignment, the design's,
  fails for this view (`gemv_old`). Its tiles are a tiling of its bytes at every admissible
  assignment and launch
  (`gemv_tiling`, `View.tiling` at `place_inj`, `sig`'s placement being injective), with the
  `example`s at grid (4,1,1) and block (128,1,1) with `m = 500` and at grid (7,1,1) and block
  (96,1,1) with `m = 20`; at grid (1,2,1) and block (32,1,1) they are not (`gemv_overlap`): the
  warps of threads 0 and 32 both hold byte 0 of `y` (`gemv_mem`, the bytes of a tile at every
  instance). At every admissible assignment and launch with at least `m` warps
  (`m ≤ ntid.x / 32 · nctaid.x`), the tiles cover the first `4 m` bytes of `y` (`gemv_cover`,
  `View.cover` at `B = m` with `elem_onto`, the layout `elem 4` onto its 4 bytes): the warp of
  thread `32 k` is in row `k` (`gemv_row`), with the `example`s at grid (4,1,1) and block
  (128,1,1) with `m = 16` and at grid (7,1,1) and block (96,1,1) with `m = 20`. With more warps
  than rows, the bytes of `y` from `4 m` up to 4 times the warp count are in `bytes` and in no
  tile (`gemv_uncovered`, as a warp's tile is its row's float, below `4 m`), with the `example` of
  byte 80 at grid (7,1,1), block (96,1,1) and `m = 20` (21 warps), where the tiles tile `bytes`
  (`gemv_tiling`'s second `example`). Coarsened at the block level (level 2) with `n = 1` and the
  binding `gemvBlock` (the block digit, the variable 1, set to the block's number), the tile of
  every block `b` holds its warps' tiles (`gemv_coarsen`'s first half, `View.tile_subset_coarsen`:
  `hn` holds as the warps in block `b` have `ctaid.x = b`, `warp_regs`), and the tile of a block
  `b < nctaid.x` whose rows are below `m` (`(b + 1) · (ntid.x / 32) ≤ m`) is their union (its
  second half, `View.coarsen_tile`: `ho` holds as the warp of thread `b · ntid.x + 32 k` has the
  warp digit `k`, for every `k` below `ntid.x / 32`). The last block of a launch may be partly
  owned: at grid (7,1,1), block (96,1,1) and `m = 20` (`gemv_partial`), block 6 has warps 18 to
  20, warp 20 owns no tile, and the block's coarse tile, bytes 72 to 83 of `y`, holds its warps'
  tiles, bytes 72 to 79, and byte 80, which no warp's tile holds. The mutant
  (`gemv_coarsen_radix`): at grid (1,1,1) and block (32,1,1) with `ntid.x` assigned 64, the warp
  digit's radix is 2, one more than the block's one warp; `gemvAdm` fails, the view is well formed
  there, `ho` fails at the warp digit 1, and the coarse tile of block 0, bytes 0 to 7 of `y`, is not
  the union of its warp's tile, bytes 0 to 3.
* The naive matmul's output (`naive_wf`): the thread level (level 0), the key `entryIdx 0 1` (the
  column with radix `n`, the variable 5, then the row with radix `m`, the variable 4), `bind`
  setting the row and the column (`Launch.index` in `x` and `y`), and a thread owning a tile when
  its row is below `m` and its column below `n`, as the kernel's two `icmp sge` (the naive matmul's
  IR :42-43, of the row of :18-25 and the column of :29-36) skip the store. The key's value is
  `row · n + col` at symbolic `n` (`naive_val`). The IR's row stride is the constant 50257 (:28),
  its column bound the argument `%4` (:15, :43), and the family's kernels in tests/corpus/mgemm/
  differ by the constant (`mul i32 %25, 257` at :28 of
  g_matmul_kernel_naive_float32_float32_float32_True_16_51a464b3.nvptx.ll, `17` at :28 of
  ..._7f042754.nvptx.ll), so the admissibility names the kernel: `naiveAdm N` admits, for the
  kernel of row stride `N`, the assignments with `n = N` (the variable 5) and the valid launches
  with side 1 in `z`, and the corpus kernel's is `naiveAdm 50257`. At every `N`, every
  assignment with `n = N` and every launch, the tile of the thread at `(row, col)` is bytes
  `4 (row · N + col)` to `4 (row · N + col) + 3` of `c`, a natural-number model of the output
  element `row · N + col` that the kernel stores (`naive_tile`, whose premise is `n = N` alone;
  the kernel's words give this element when `m · N < 2 ^ 31`, `naive_words`). `WF` holds at
  every admissible assignment and launch (`naive_wf`): `WF.range` is the guard (`row < m`,
  `col < n`), and `WF.key_inj` is `Launch.xy_inj`. The stride's mutant (`naive_stride`): at
  `m = n = 2` and one block of 2 × 2 threads, `naiveAdm 50257` fails, and the corpus kernel's
  store of thread 1 (row 1, column 0), at byte `4 · 50257` of `c` in the model (its words do not
  wrap, as `2 · 50257 < 2 ^ 31`), is not in thread 1's tile, bytes 8 to 11, the view at `n = 2`
  being the kernel's of row stride 2. The mutants of `WF`: at the assignment `0`
  and the launch of one thread (`naive_zero`) the view is well formed, as no thread owns a tile, and
  the view without the guard (`naiveAll`, every thread an owner) is not, the column's radix being 0;
  at `m = n = 1` and one block of 2 × 1 threads, a launch that covers the rows as
  `MojoProof.Tile.MatSetup.Fits` admits (`naive_overshoot`), the view is well formed, thread 1 (row
  1) covers no byte, and the view without the guard is not well formed; at one block of 1 × 1 × 2
  threads (`naive_z`) threads 0 and 1 have one row and one column and `WF` fails, so the side 1 in
  `z` is needed. Its tiles are a tiling of its bytes at every assignment and admissible launch
  (`naive_tiling`), with the `example`s at one block of 2 × 2 threads with `m = n = 2` and at grid
  (3,2,1) and block (4,8,1) with `m = 10` and `n = 15`. At every `N`, every assignment with
  `n = N` and every valid launch whose threads reach `m` rows (`m ≤ nctaid.x · ntid.x`) and `N`
  columns (`N ≤ nctaid.y · ntid.y`), the tiles cover the view's bytes, the `m · N` floats of `c`
  (`naive_cover`, `View.cover` at `bytes`'s radix product, by `Launch.cell_onto` and
  `naive_val`); the side 1 in `z` of `naiveAdm` is not a premise. The `example`s: one block of
  2 × 2 threads with `m = n = 2`, the corpus kernel's at grid (1,3142,1) and block (4,16,1) with
  `m = 4` and `n = 50257`, and one block of 1 × 1 × 2 threads (`L112`) with `m = n = 1`, which
  `naiveAdm 1` refuses and where the view is not well formed (`naive_z`).
* Both admit a launch (gemv's at 4 blocks of 128 threads, the corpus naive kernel's at one block
  of 2 × 2 threads and `n = 50257`, the `example`s after `gemv_tile` and `naive_tile`); at grid
  (4,1,1) and block (128,1,1) thread 200 is in row 6, bytes 24 to 27 of `y`.
* A mutant of each of `WF`'s fields on the key: a key out of range (`gemv_zero`, `naive_zero`,
  `naive_overshoot`) and two instances with one key (`gemv_gridY`, `naive_z`) above, and a radix
  that reads a bound variable (`bound_radix`): a thread view at grid (1,1,1) and block (2,1,1)
  whose key's one radix is the variable 1, which its binding sets to 2 while the assignment has
  1, so `range` and `key_inj` hold and `radices` fails, and its tiles are not a tiling, thread
  1's tile (byte 4 on) being past its bytes (bytes 0 to 3).
* The tiles as MojoProof's tilings of byte intervals (MojoProofTest/GPUProof/ViewTiling.lean):
  `MojoProof.Sem.Tiling` (MojoProof/Sem/Trace.lean:146), the tiling that `Owned` takes, is a
  family of intervals inside an extent, pairwise disjoint. At `sig`, a view well formed at `σ`
  and `L` gives one over its owners with `none` added (`toTiling`): owner `g`'s interval
  (`some g`) starts at its key value times the cosize and has the cosize's length, inside
  `radixProd · cosize` bytes, by `MixedRadix.lt_prod` (`owner_end_le`) and by `WF.key_inj`
  through `eq_iff_digits` (two owners' key values differ), and `none`'s is empty, at the
  extent. When the layout is onto its cosize (`View.cover`'s `hl`), an owner's tile is the bytes
  of its interval (`tile_toTiling`); the mutant `hole_toTiling` drops `hl`: the layout
  `Lay.flat [(2, 2)]` (size 2, offsets 0 and 2, cosize 3) at the key `⟨[]⟩` and grid (1,1,1) and
  block (1,1,1) is well formed, and byte 1 of the buffer is in the owner's interval and not in
  its tile. The intervals are natural-number models of offsets, as the tiles are. gemv's warp of
  an owner thread has the 4 bytes from
  `4 · row`, inside 4 times the warp count (`gemv_toTiling`), and the naive matmul's thread at
  `(row, col)` the 4 bytes from `4 · (row · N + col)`, inside the `m · N` floats of `c`
  (`naive_toTiling`), with an `example` each (thread 200 at grid (4,1,1), block (128,1,1) and
  `m = 16`; the corpus kernel's thread 3 at one block of 2 × 2 threads and `n = 50257`). The
  map from threads to indices that `Owned` also takes is `own`, total on threads: a thread's
  instance of the view's level when it owns a tile (`own_some`), and `none` otherwise, so a thread
  whose instance owns no tile has the empty interval (`own_none`, with the `example` of gemv's
  thread 400 at grid (4,1,1), block (128,1,1) and `m = 8`, row 12 of 8 rows). Under `Owned` at
  `toTiling` and `own`, such a thread's accesses to the view's buffer have length 0
  (`owned_len`), so they overlap no access.
* The offsets as the kernels' words (MojoProofTest/GPUProof/ViewWords.lean), through the
  semantics' `intCast`, `intBin`, `icmpV` and `gep` and the lemmas of MojoProof/Sem/Index.lean
  and MojoProof/Sym/OblLemmas.lean. The word premise is `View.key_fits`'s, the key's radix
  product below `2 ^ 31`, at the kernels' 32-bit words: `m · N < 2 ^ 31` at the naive matmul;
  at gemv the key is the row and the premise is `m < 2 ^ 31`, the bound that its `sext` reads.
  The words below start from the 64-bit word of a thread's index `Launch.index t d`, which the IR
  reads from `tid`, `ctaid` and `ntid` and computes with `zext`, `sext`, `mul` and `add` (gemv's
  IR :13-20, the naive matmul's :18-25 and :29-36); at every valid launch those words are
  `MojoProof.Sem.Launch.index_ops`'s (MojoProof/Sem/Index.lean).
  For every width: `icmp_sge` (`icmp sge` of two words whose doubles fit is `≤` of their
  numbers), `sge_sext` (the same after a `sext` of the bound from a narrower width) and
  `rowMajor_words` (`trunc`, `mul`, `add` and `sext` of `r · s + k` with `r < m`, `k < s` and
  `m · s < 2 ^ (w - 1)` give its word, at every flags value). The naive matmul at every row
  stride `N`, every assignment with `n = N` and the premise: the words of the naive matmul's IR
  :26, :28, :37, :39 and :40 are the 64-bit word of `row · N + col`, its key value, at every flags
  value, and the tile's first byte is `4 (row · N + col)` (`naive_words`); at every valid launch
  the guards :42-43 are both false exactly when the thread owns its tile (`naive_guards`, also
  at `m = 0` and `n = 0`); and the `getelementptr` of :41 by that word is the pointer to that
  byte (`naive_gep`), with the corpus kernel's `example` at `m = 4`, row 3 and column 50256.
  gemv at every admissible assignment and valid launch with `m < 2 ^ 31`: the `udiv` of gemv's
  IR :21 is the row word, the `sext` of :11 is `m`'s 64-bit word, the guard :55 is false exactly
  when the warp owns its tile, and the tile's first byte is `4 · row` (`gemv_words`); the
  `getelementptr` of :50 by the row word is the pointer to it (`gemv_gep`). The premises have
  instances in the `example`s: the corpus stride at `m = 2`, grid (1,1,1), block (2,2,1) and
  thread 3, gemv at grid (4,1,1), block (128,1,1), `m = 500` and thread 200, with the
  `getelementptr`s into `oneBuf`, a memory of one buffer, at the default layout. The mutants, where
  the premise fails: at grid (1,1,1), block (32,1,1) and `m = 2 ^ 31` (`gemv_wrap`), `gemvAdm`
  holds and warp 0 owns row 0, and the guard of row 0 is true, so the kernel skips the store its
  view owns; at `N = 50257`, `m = 2 ^ 20 + 1`, grid `(2 ^ 20 + 1, 1, 1)` and block (1,1,1)
  (`naive_wrap`), `naiveAdm 50257` holds, thread `2 ^ 20` owns its tile and both guards are
  false, and the words give `1105 · 2 ^ 20` (`50257 · 2 ^ 20` modulo `2 ^ 32`), whose byte
  `4 · 1105 · 2 ^ 20` is not in that thread's tile. The edge (`naive_edge`): at `n = 0`,
  `m = 2 ^ 31` and grid (1,1,1) and block (1,1,1), the premise holds (`m · n = 0`), the row
  guard is true at row 0 (the `sext` of `m`'s word is negative) and so is the column guard, and
  the thread owns no tile, as `naive_guards` says.

### Interleaved footprints: `View.tilingAt`

**Status.** Proved: GPUProof/View.lean, with the test MojoProofTest/GPUProof/ViewStride.lean. A
view's tile lies in the bytes `[key · cosize, (key + 1) · cosize)`, so a footprint that
interleaves with other owners' is not one view tile. A target kernel has one: MAX's
layer norm, at its block kernel of rank 1 and block size 128,
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll. Its row loop runs the
body at block 0 only (the row starts at `ctaid.x`, :39, and the exit test :58, :65 is `row ≥ 1` on
the first trip), and there thread `tid` (:31-32) stores the floats `tid + 128 j` of the output for
the `j` with `128 j < n` (the step :681, the exit :684, the index and `getelementptr` :699-700, the
guard `tid + 128 j < n` :708-709, the store :722), `n` the first field of the arguments (:101). The
second store (:744, :755-756) is on the branch where `min (n - tid - 128 j) 1` is not 1 (:704-707,
:712), which the guard leaves unreached, and at element `tid + 128 j + e` for `e` below
`max (min (n - tid - 128 j) 1) 0` (:706, :731), so at the same float. The kernels of block size 64,
256 and 1024 in the same folder step by 64, 256 and 1024 (:681). At `n = 128 X` a thread's floats
are `X` floats at stride 128, and the threads' floats interleave.

The design: the key gets its own stride. At a key stride `d σ`, instance `g`'s offset of coordinate
`c` is `key · d σ + lay(c)` (`View.offAt`), its tile is `View.tileAt`, and the tiles lie in the
first `radixProd · d + cosize - d` bytes (`View.bytesAt`); at `d σ` the cosize these are `View.off`,
`View.tile` and `View.bytes`. Two keys below the radix product `R` have disjoint tiles when every
offset of the layout, modulo `R · d`, is below `d` (`View.Interleaved`): then `k d + a` modulo
`R d`, divided by `d`, is `k`. The contiguous view meets it at `d = cosize`, where every offset is
below `d`; layer norm's view meets it at `d = 4` bytes with the layout of one thread's `X` floats,
modes `(4, 1)` and `(X, 4 · 128)`, and `R = 128` threads, every offset modulo `512` being its byte
in its float. So `View.tiling` becomes the case `d = cosize` of `View.tilingAt`, with no second
disjointness proof. The other form, the layout applied to the key and the coordinate together, is
the case where `d σ` is the stride of one more layout mode; its premise, the combined layout one to
one, holds where `Interleaved` does but has no law in the core for modes out of order
(`idx2crd_call` wants them nested in order), so the premise here is the remainder bound, which an
instance proves by `Nat.add_mul_mod_self_right`.

```lean
/-- The offset of coordinate `c` of instance `g` at the key stride `d`. -/
def View.offAt (v : View S) (d : Sizes → Nat) (σ : Sizes) (L : S.Launch) (g : S.Gid)
    (c : Nat) : Nat :=
  v.key.val (v.bind L g σ) * d σ + (v.lay σ).call (leaf c false)

/-- Every offset of the layout, modulo the radix product times `d`, is below `d`. -/
def View.Interleaved (v : View S) (d : Sizes → Nat) (σ : Sizes) : Prop :=
  ∀ c < (v.lay σ).size, (v.lay σ).call (leaf c false) % (v.key.radixProd σ * d σ) < d σ

/-- For every machine whose placement is injective, view, key stride `d`, size assignment and
launch at which the view is well formed and interleaves at `d`: the tiles at `d` are in bounds
and pairwise disjoint. -/
theorem View.tilingAt (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch} (hv : v.WF σ L) (hd : v.Interleaved d σ) :
    Tiling (v.tilesAt d σ L) (v.bytesAt d σ)
```

Tests, MojoProofTest/GPUProof/ViewStride.lean: layer norm's view at MojoProof's `sig` for the
kernel of block size `B` (`lnView`), well formed and interleaved at every admissible assignment
and launch (`ln_wf`, `ln_interleaved`; `lnAdm B`, a 1-D launch of `B` threads a block, `X ≥ 1`),
its tile (`ln_tile`: thread `t` of block 0 owns the floats `t + B j`, `j < X`), its tiling
(`ln_tiling`, with `example`s at block size 128, one block and `X = 1`, and at block size 256, two
blocks and `X = 3`), and the mutant (`ln_stride64`): the stride of the kernel of block size 64 at
a launch of 128 threads, where the view is well formed, not interleaved, the tiles of threads 0
and 64 share byte 256, and the tiles are not a tiling. Coverage and coarsening at a key stride
are the next section. A row length `n` that `B` does not divide, where the last float of some
threads is past `n` and the guard (:708) skips it, is in "Guarded tiles" below.

### Coverage and coarsening at a key stride

**Status.** Proved: GPUProof/View.lean, with the tests MojoProofTest/GPUProof/ViewStride.lean
and, through the cases at the cosize, MojoProofTest/GPUProof/View.lean. `View.cover`,
`View.cover_iff` and the coarsening lemmas were stated at `d = cosize` only.

The plan. At a key stride `d` the owners' bytes come in periods of `P · d` bytes, `P` the key
values: key `k`'s bytes in period `q` are `k d + r + P d q` for `r < d`, the layout's offsets
`r + P d q`. So the bound `B · cosize` becomes `P · d · Q`, `Q` periods, and the premise on the
offsets below the cosize becomes one on the offsets `r + P d q`. At `d = cosize`, `P = B` and
`Q = 1` they are `cover`'s, so `cover` and `cover_iff` are the case `d = cosize`, `Q = 1`
(corollaries of three and five lines: the period `q < 1` is `0`, and `B · cosize · 1` is
`B · cosize`, by rewriting, not by definition). Byte `i` below `P d Q` is the offset `r + P d q`
of key `k`, with `q = i / (P d)`, `k = (i % (P d)) / d` and `r = (i % (P d)) % d`.

```lean
/-- For every machine, view, key stride `d`, size assignment, launch, key bound `P` and period
count `Q`: the owners' tiles at `d` cover the first `P · d · Q` bytes when every offset
`r + P d q` (`r < d`, `q < Q`) is a coordinate's and every key value below `P` an owner's. -/
theorem View.coverAt (v : View S) (d : Sizes → Nat) {σ : Sizes} {L : S.Launch} {P Q : Nat}
    (hl : ∀ q < Q, ∀ r < d σ, ∃ c < (v.lay σ).size,
      (v.lay σ).call (leaf c false) = r + P * d σ * q)
    (hk : ∀ k < P, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k) :
    {x | ∃ i : Nat, i < P * d σ * Q ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tilesAt d σ L g

/-- For every machine whose placement is injective, view, key stride `d`, size assignment and
launch at which the view is well formed, positive `P` and `Q`, where the layout interleaves at
the period `P · d` (`hd`) and `Q = 1` or `P` is at least the radix product (`hPQ`): the two
premises of `coverAt` are the least. -/
theorem View.cover_iffAt (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch} (hv : v.WF σ L) {P Q : Nat} (hP : 0 < P) (hQ : 0 < Q)
    (hd : ∀ c < (v.lay σ).size, (v.lay σ).call (leaf c false) % (P * d σ) < d σ)
    (hPQ : Q = 1 ∨ v.key.radixProd σ ≤ P) :
    {x | ∃ i : Nat, i < P * d σ * Q ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tilesAt d σ L g ↔
      (∀ q < Q, ∀ r < d σ, ∃ c < (v.lay σ).size,
        (v.lay σ).call (leaf c false) = r + P * d σ * q) ∧
        ∀ k < P, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k
```

`cover_iff` is false at a key stride as it is stated at the cosize, and `hd` and `hPQ` are what
is true. Layer norm's view of block size 128 at `X = 2`, at `d = 4`, interleaves at its radix
product `R = 128`. At `P = 256 = 2 R` and `Q = 1` its tiles cover the first `256 · 4` bytes (both
floats of every thread) while key value 128 is no owner's: `hd` fails at the period `256 · 4`
(offset 512, a thread's second float, modulo 1024 is 512). At `P = 64`, `Q = 2` the layout
interleaves at the period `64 · 4` and the tiles cover the first `512` bytes (every thread's first
float), while the offset `256 = 0 + 64 · 4 · 1` is no coordinate's: `hPQ` fails, as `Q = 2` and
`64 < 128`. At the cosize both premises hold for every positive `B` at `Q = 1`, as every offset
is below the cosize. With `hd` and `hPQ`, a byte `k d + r + P d q` of an owner's tile at its key
value `k'` and offset `a` has `k' < P` (from `hPQ`: `k' < R ≤ P`, or `k' d ≤ k d + r < P d` at
`Q = 1`), so `View.key_eq_of_mod` at the bound `P` gives `k' = k`, and `a = r + P d q`.

Coarsening. `View.coarsenAt v d ℓ n bind'` is `coarsen`'s view with the inner digits' mode at
stride `d σ` in place of the cosize, and `View.coarsen` is now `coarsenAt` at `d = cosize` (by
definition). The coarse key stride is `R_in · d`, `R_in` the inner radix product: an owner `j`
inside `i` with key `inner + R_in · outer` has the offset `key · d + lay(c)`, which is the coarse
offset of `i` at `inner · size + c`, `outer · (R_in d) + (lay(c) + inner · d)`
(`View.off_coarsenAt`). The size and offsets: `coarsenAt_size`, `coarsenAt_congruent` and
`coarsenAt_call` (offset of `c'`: `lay(c' % size) + (c' / size) · d`), and `coarsen_size`,
`coarsen_congruent` and `coarsen_call` their cases at the cosize, one line each. `coarsen_cosize`
stays at the cosize. The tiles:

```lean
/-- For every machine, view, key stride `d`, level, digit count, binding, size assignment and
launch at which the view is well formed, and instance `i` whose owners agree on the outer
digits: the tiles at `d` inside `i` lie in the coarse tile of `i` at the stride `R_in · d`. -/
theorem View.tile_subset_coarsenAt (v : View S) (d : Sizes → Nat) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ)) :
    ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tileAt d σ L j ⊆
      (v.coarsenAt d ℓ n bind').tileAt (fun σ => (v.inner n).radixProd σ * d σ) σ L i

/-- ... and when the owners inside `i` realize every inner key value, the coarse tile is their
union. -/
theorem View.coarsenAt_tile (v : View S) (d : Sizes → Nat) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ ∧ (v.inner n).val (v.bind L j σ) = k) :
    (v.coarsenAt d ℓ n bind').tileAt (fun σ => (v.inner n).radixProd σ * d σ) σ L i =
      ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tileAt d σ L j
```

The old `tile_subset_coarsen` and `coarsen_tile` are their cases at `d = cosize`, by
`View.coarsen_tileAt`: at a well formed view the coarse tile at the coarse cosize is the one at
the stride `R_in · cosize` (`coarsen_cosize` where `R_in` is positive; at `R_in = 0` the coarse
layout has no coordinate and both are empty). `off_coarsen` is deleted: `off_coarsenAt` replaces
its two uses, in View.lean.

Tests, MojoProofTest/GPUProof/ViewStride.lean: `ln_cover`, layer norm's tiles at `d = 4` cover
the `B X` floats of `y` at every admissible assignment and launch with a block (`coverAt` at
`P = B`, `Q = X`), with `example`s at block size 128 (one block, `X = 1`) and 256 (two blocks,
`X = 3`); the mutant `ln_stride64_uncovered`, the view of block size 64 at 128 threads and
`X = 2`, whose tiles miss byte 768 of the first `128 · 4 · 2`, float 192; and the two
counterexamples above, `ln_cover_period` (`P = 256`, `Q = 1`: covered, key value 128 no owner's,
`hd` false) and `ln_cover_short` (`P = 64`, `Q = 2`: covered, `hd` true, offset 256 no
coordinate's, `hPQ` false). The cases at the cosize keep their uses in
MojoProofTest/GPUProof/View.lean (`cover` in `gemv_cover` and `naive_cover`,
`tile_subset_coarsen` and `coarsen_tile` in `gemv_coarsen`, `coarsen_size`, `coarsen_call` and
`coarsen_cosize` in `gemv_partial` and `gemv_coarsen_radix`), unchanged. The layer norm view's
key has one digit, so its own coarsening test is at a grid-stride loop's view, `gsView y T own`:
thread `t` of the grid holds the floats `t + T j`, with the key `gsKey` of two digits, `tid.x`
then `ctaid.x`, at 2 blocks of 2 threads and `X = 2` (`gsAsg`, `gsLaunch`), where `gs_wf` and
`gs_hn` (the threads of a block agree on `ctaid.x`) hold by evaluation. `gs_coarsen`: at `T = 4`
and every thread an owner, coarsened to the block level at `d = 4` (the layout's cosize is 20),
the tile of block 1 at the key stride `2 · 4` is the union of its threads' tiles
(`coarsenAt_tile`, with `ho` by evaluation). The mutant `gs_gap`: when the threads of `tid.x` 1
own no tile, `tile_subset_coarsenAt` still holds at block 1, `ho` fails at the inner key value 1,
and byte 12 of `y`, float 3, is in the coarse tile and in no owner's tile.

### Guarded tiles: a row of `n` floats at every `n`

**Status.** Proved: GPUProof/View.lean ("Guarded tiles"), with the tests in
MojoProofTest/GPUProof/ViewStride.lean ("A row of `n` floats: the guard"). At `n = B X` every
float of a thread's tile is below `n`. Otherwise, at `X = ⌈n / B⌉`, the last float `t + B (X - 1)`
of a thread `t` with `t + B (X - 1) ≥ n` is in its tile, and the kernel's guard `%485 < n` (:708)
skips its store (:709), so the unguarded tile holds bytes the kernel does not write
(`ln_unguarded_300`).

The form: a guard on the offset, not a layout. `View.guardAt d N σ L g` is `View.tileAt`'s bytes
whose offset `offAt d σ L g c` is below a bound `N σ`, here `4 n`, the bytes of the row; the
layout still lists every iteration `j < X`. A layout cannot express the guard: `View.lay` is one
function of the sizes for every instance, so a last float present at some threads and absent at
others would need two views (the threads with `X` floats and those with `X - 1`) and a proof that
the two views' tiles are disjoint, which the core has no law for. The bound on the offset is the
kernel's own test (the float's index below `n` is its first byte below `4 n`), it is one
definition for every view, and its laws are short:

* `GPUProof.Tiling.mono`: sets inside the sets of a tiling tile its domain;
* `View.guardAt_subset`: a guarded tile lies in its tile, so guarded tiles of a tiling are a
  tiling (`Tiling.mono`);
* `View.tile_subset_guardAt`: where every offset is below the bound, the tile lies in the guarded
  tile, which is then the tile (with `guardAt_subset`); the core states the inclusion, and a test
  that needs the equation takes both (`ln_guard_dvd`);
* `View.cover_guardAt`: at an injective placement, the guarded tiles cover the bytes below the
  bound that the tiles cover.

Layer norm's tests, for every block size `B` and row length `n` at every admissible assignment
and launch: `ln_guard_tile` (thread `t` of block 0 owns the bytes of the floats `t + B j`,
`j < X`, below `n`), `ln_guard_dvd` (at the bound `4 B X` the guarded tile is `ln_tile`'s, by
`guardAt_subset` and `tile_subset_guardAt`, so `ln_wf`, `ln_tile`, `ln_tiling`, `ln_cover` and
their tests are the case `B ∣ n`),
`ln_guard_tiling` (by `ln_tiling` and `Tiling.mono`) and `ln_guard_cover` (at `n ≤ B X`, by
`ln_cover` and `cover_guardAt`). `lnLoop` and `lnStores` model the IR's loop (exit at `i ≥ n`,
store float `i + t` when `i + t < n`, step `i + B`). The model's floats are proved for every block
size `B`, row length `n`, thread `t` and count `X` with `n ≤ t + B X`: `lnStores_eq` says
`lnStores B n t` is the floats `t + B j`, `j < X`, below `n`, in order. It is `lnLoop_eq` from the
index 0, an induction on the fuel: from the index `B m`, with fuel `k` and count `X` such that
`n ≤ t + B (m + k)` and `n ≤ t + B (m + X)`, the loop stores the floats `t + B j`,
`m ≤ j < m + X`, below `n`. `lnStores`' fuel `n` meets the first premise at every `B ≥ 1`
(`n ≤ B n`), and at `B = 0` the premise `n ≤ t` does. The premise `n ≤ t + B X` is needed: at
`B ≥ 1` and `n > t + B X`, float `t + B X` is in `lnStores B n t` and is not `t + B j` for any
`j < X`. `ln_guard_stores` says that, for every `B`, `n` and admissible assignment and launch,
thread `t`'s guarded tile is the bytes of `lnStores B n t` when `n ≤ t + B X` holds at the threads
`t < B` of block 0, which `n ≤ B X` (as at `X = ⌈n / B⌉`) gives. Its uses are `ln_guard_300`
(`B = 128`, one block, `n = 300`, `X = 3`) and `ln_guard_170` (`B = 64`, two blocks, `n = 170`,
`X = 3`, where block 1 owns nothing), each one application with the premise by `omega`; an
`example` evaluates `lnStores` at both sizes. The mutant `ln_unguarded_300`: byte 1532, float
`383 = 127 + 128 · 2`, is in thread 127's unguarded tile and no thread's stores write it.
`lnLoop` is defined as a model of the IR's loop; at the IR's block size 128 the run of the loop
stores at `lnStores 128 n tid`'s floats (MojoProofTest/LnRun.lean's `run`, below).

### Layer norm's loop words at every thread and step

**Status.** Proved: MojoProofTest/GPUProof/ViewWords.lean ("Layer norm: the loop's words at every
thread and step"). It is not a run theorem. The address words of the IR's loop body (:699-722)
are related to `View.offAt` at the key stride 4 and the guarded tile's bound for every block size
`B`, row length `n`, thread `t` and step `j < X`, by the semantics' operations at symbolic words:
the word lemmas `intCast_ofNat` and `intBin_add_ofNat` (MojoProof/Sem/Index.lean) and
`ICmp.slt_ofNat`, `ICmp.sge_ofNat`, `ICmp.eq_ofNat`, `intBin_sub_wrap` and `gep_buffer`
(MojoProof/Sym/OblLemmas.lean), under the word premises `8 B X < 2 ^ 64` and `2 n < 2 ^ 64`
(and `2 k < 2 ^ 64` for the index word of `ln_second`). Neither the symbolic executor nor an
evaluation of the kernel is used; the examples at two launches are instances of the theorems.

* `ln_offAt`: the offset at the key stride 4 of coordinate `4 j + b`, `b < 4`, of thread `t`'s
  tile is `4 (B j + tid) + b`, for every assignment, launch and thread.
* `ln_words`: from the loop index's word `B j` (`%471`, :679) and the 32-bit word of `tid.x`
  (:31), the `zext` (:32) is the 64-bit word of `tid`, the `add` (:699) the word of `B j + tid`,
  whose float's bytes are at `ln_offAt`'s offsets, the guard `icmp slt` with `n` (:708) the
  boolean `B j + tid < n`, which is the bound `offAt (4 j + b) < 4 n` of `ln_guard_tile`, the exit
  test `icmp sge` (:684) the boolean `n ≤ B j`, the step `add` (:681) the word of `B j + B`, and its
  overflow test (:682) false.
* `ln_gep`: the `getelementptr` of a float from `⟨y, 0⟩` by that word (:700) is the pointer to
  byte `offAt (4 j)` of `y`, at every layout of 4-byte floats and 64-bit pointers and every
  memory in which `y` is a buffer of at least `4 B X` bytes.
* `ln_second`: the second test of the bound is the guard. For every `n` and index word `k` with
  `2 n` and `2 k` below `2 ^ 64`, the `sub` of `k` from `n` (:704), the `llvm.smin` of that and 1
  (:705) and the `icmp eq` of the minimum with 1 (:707) give the boolean `k < n`. So where the
  guard (:708) is true, the branch :712 goes to the store (:722), and the second store (:744) is
  not reached. The `llvm.smax` (:706) is read only on that other path (:731, :741). The proof
  splits on `k < n`. Where `k < n`, the difference's word is that of `n - k ≥ 1`, whose
  minimum with 1 is 1. Otherwise it is 0 or negative as a signed word, so its minimum with 1 is
  itself, which is not 1.
* Examples: at `B = 128`, one block, `n = 300`, `X = 3`, step 2, thread 43 has the index word 299
  and the guard true and thread 44 the word 300 and the guard false, and the second test is
  likewise true at 43 and false at 44; at `B = 64`, two blocks, `n = 170`, `X = 3`, step 2,
  thread 41 has the word 169 and the guard true and thread 106 (`tid.x` 42 of block 1) the guard
  false; the `getelementptr` at one buffer of `4 · 384` bytes.
* The mutant `ln_wrap`: at `n = 2 ^ 63` (`hn` fails, `hw` holds) the word of `n` is negative, so
  the guard of thread 0 at step 0 is false and the kernel skips the store of float 0, whose bytes
  are in thread 0's guarded tile under the bound `4 n`. The second test is false there too (the
  `sub` is the negative word `2 ^ 63`, whose minimum with 1 is itself).

The run that reaches these words and stores the float at the pointer (:722) is the next
section's, at the IR's block size 128.

### Layer norm's loop run at every row length

**Status.** Proved at block size 128 (the corpus file is that kernel): MojoProofTest/LnGep.lean,
MojoProofTest/LnRound.lean and MojoProofTest/LnRun.lean. These are run theorems of the symbolic
layer (`Block.sound_edge`), for one thread, every context (so every launch and thread),
`tid < 1024`, row length `n < 2 ^ 32` and memory in which `y` (writable), `g`, `b` and `x`
(read-only) are buffers of `4 n` bytes that fit, `x`, `g` and `b` hold the rows and `y` is none
of the other three. The value side is not proved: the mean `%460` and the inverse deviation
`%464` are given registers, and the bytes stored are given (4 bytes for each float); the
addresses and the guard are proved.

* The inactive threads' pointers (MojoProofTest/LnGep.lean). At a buffer of exactly the row's
  `4 n` bytes, the `getelementptr inbounds` of float `128 j + tid` (:700) is `ln_gep`'s pointer
  inside the row (`ln_gep_row`), the pointer one past the end at float `n`, and poison past the
  block (`gep_inbounds_past`, `ln_gep_past`: `gepPtr`'s rule for `inbounds`,
  MojoProof/Sem/Eval.lean, as LangRef's "getelementptr Instruction" says). The semantics never
  faults there (`gep_buffer_ok`), so it accepts the step LLVM accepts.
* One round (MojoProofTest/LnRound.lean). `round_false`: with `i < n ≤ i + tid` the round on the
  path `%469`, `%483`, `%484`, `%531`, `%532` has its premises (`RoundWith`); it evaluates the
  `getelementptr`s by `i + tid ≥ n` and has no store. `round_true`: with `i + tid < n` the round
  through `%495`, `%496` (the three loads and the store at :722) has its premises.
* The run (MojoProofTest/LnRun.lean). `AtHead` is the state at the header after its `phi`s at
  index `i`. `AtHead.roundT` and `AtHead.roundF` give the round's premises, `AtHead` at `i + 128`
  and the memory: `LnOut y [i + tid]` (4 bytes put at byte `4 (i + tid)` of `y`, by `run_put`
  from the store's effect) or `LnOut y []`. `AtHead.exit` is the path out `%469`, `%482` to
  `%534`. `run_from`, the hand-proved run lemma (57 lines, 68 with its docstring), is an induction
  on the fuel `K` with `n ≤ i + 128 K`: one `Block.sound_edge` per round and `run_exit` at the
  end, giving `LnOut y (lnLoop 128 n tid K i)`. `run` is `run_from` at `K = n`, `i = 0`:

```lean
theorem run ... (hA : AtHead n tid 0 y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (lnStores 128 n tid) m m'
```

  `entry_edge` and `run_entry` add the edge from `%453`'s branch (:675), whose `phi`s
  (:678-680) set the index to 0, so the run is from the loop's entry to `%534` (:774). With
  `lnStores_eq` and `ln_guard_stores`, the floats stored are thread `tid`'s guarded tile when
  `n ≤ tid + 128 X`.

Not proved: the floats stored (`%503`, from `%460`, `%464`, `x`, `g` and `b`), the loops before
this one (the mean and the deviation) and block sizes other than the corpus file's 128.

### Separated footprints: a condition both necessary and sufficient

**Status.** Proved: GPUProof/View.lean, with the tests MojoProofTest/GPUProof/ViewStride.lean.
`View.Interleaved` is sufficient for `View.tilingAt`'s disjointness but not necessary: `R = 2`
threads owning two of the three float columns of a row-major matrix, at `d = 4`, own the bytes
`4 j + 12 i + b` (`j < 2`, `i < 2` rows, `b < 4`), and their tiles are disjoint, while the
offset 12 modulo `2 · 4` is 4, not below 4.

The condition. The tiles at `d` of key values `k < k'` meet exactly when an offset `a` of the
layout is another offset `a'` plus `(k' - k) d`. So the layout is separated at `d`
(`View.Separated`) when no two offsets differ by `m d` with `0 < m < R`:

```lean
def View.Separated (v : View S) (d : Sizes → Nat) (σ : Sizes) : Prop :=
  ∀ c < (v.lay σ).size, ∀ c' < (v.lay σ).size, ∀ m, 0 < m → m < v.key.radixProd σ →
    (v.lay σ).call (leaf c false) ≠ (v.lay σ).call (leaf c' false) + m * d σ

/-- Sufficient, for every machine with an injective placement, view, key stride, size assignment
and launch at which the view is well formed. -/
theorem View.tiling_separated (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place)
    {σ : Sizes} {L : S.Launch} (hv : v.WF σ L) (hs : v.Separated d σ) :
    Tiling (v.tilesAt d σ L) (v.bytesAt d σ)

/-- Necessary, for every machine, view, key stride, size assignment and launch at which every key
value below the radix product is an owner's. -/
theorem View.separated_of_disjoint (v : View S) (d : Sizes → Nat) {σ : Sizes} {L : S.Launch}
    (hk : ∀ k < v.key.radixProd σ, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k)
    (hd : Pairwise fun i j => Disjoint (v.tilesAt d σ L i) (v.tilesAt d σ L j)) :
    v.Separated d σ

theorem View.separated_of_interleaved (v : View S) {d : Sizes → Nat} {σ : Sizes}
    (hd : v.Interleaved d σ) : v.Separated d σ
```

Necessity reads `hk`: an offset `a = a' + m d` puts the byte `0 · d + a = m d + a'` in the tiles
of the owners of key values `0` and `m`, two instances. Without `hk` a layout that is not
separated can have disjoint tiles, when the key values that would meet have no owner; there the
condition both necessary and sufficient is disjointness itself. `View.tilingAt` keeps its
statement and is now `tiling_separated` at `separated_of_interleaved`, one line, so the
disjointness argument is written once. The two are stated apart, not as one `iff`, as the sides
would be two definitions of the library (`Tiling` and `Separated`).

Tests, MojoProofTest/GPUProof/ViewStride.lean: `ln_separated`, the view `lnView y C` of stride `C`
floats at the kernel of block size `B ≤ C` (thread `t` owns column `t` of a row-major matrix of
`C` float columns) is separated at `d = 4` at every admissible assignment and launch;
`ln_tiling_cols`, its tiles are a tiling (`tiling_separated`); `ln_cols_not_interleaved`, the
example above at `B = 2`, `C = 3` and `X = 2` rows, a tiling that does not interleave; and the
mutant `ln_stride64_not_separated`, `ln_stride64`'s view (`C = 64`, 128 threads, `X = 2`) is not
separated (offset 256 is offset 0 plus `64 · 4`), so its tiles are not pairwise disjoint
(`separated_of_disjoint` at `ln_owners`, every key value below 128 an owner's), a second route
to `ln_stride64`'s non-tiling.

### The layout algebra's move into the core

**Status.** Done. The laws the views reindex by (`rowMajor_inj` and `Lay.compose_call` in
GPUProof/Layout/Laws.lean, `Swizzle.call_call` in GPUProof/Layout/Swizzle.lean, `placement_call`
in GPUProof/Layout/Bits.lean, `Swizzle.twoLevel_call` in GPUProof/Layout/TwoLevel.lean) are
mathematics about layouts, so they are in the core. The move had no aliases and no import-only
files:

* Lean: Basic.lean (no import), Algebra.lean, Crd.lean, Laws.lean, Bits.lean, Swizzle.lean and
  TwoLevel.lean (which import only each other) are GPUProof/Layout/*.lean, in namespace
  `GPUProof.Layout`. No library module outside the directory imported them, so no other library
  module changed.
* The core's import test, MojoProofTest/GPUProof/Imports.lean, imports the seven modules and
  checks that they reach neither `MojoProof` nor `TorchLean`; its pinned list of core modules
  has them.
* lakefile.lean's glob `.submodules `MojoProof.Layout` is deleted; `lean_lib GPUProof`'s glob
  covers the moved modules.
* Tests: the laws' instances are MojoProofTest/GPUProof/LayoutLaws.lean (namespace
  `MojoProofTest.LayoutLaws` kept). MojoProofTest/LayoutConformance.lean and
  MojoProofTest/LayoutRuntime.lean stay: they test the claim that the model is Mojo's library.
  They were regenerated from the recorded IR and dump by their generators, tests/layout/extract.py
  and tests/layout/runtime/extract.py, which name the new namespace; the headers of
  tests/layout/record.txt and tests/layout/runtime/record.txt name the new path.
* The trusted base: T16, the claim that the model is Mojo's layout library, stays MojoProof's,
  with its row in docs/TRUST.md and its anchors in scripts/trust.tsv at the moved modules.
* scripts/laws.tsv's five layout laws and scripts/targets.txt's layout section name the new
  namespace; the laws' statement fingerprints are the moved theorems'.
* Documents: docs/proofs/layout-laws.md, this file, roadmap/layout/README.md and the layout cards
  under roadmap/layout/cards/; docs/DEPENDENCIES.md, docs/deps/ and roadmap/status.yaml are
  regenerated. The ledger's rows keep the paths of their time.
* Not moved: the tensor-core fragment maps (MojoProof/Sem/TensorCore.lean), which are
  transcriptions of the PTX tables, fixed at 32 lanes and importing TorchLean.
