import GPUProof.Sig
import GPUProof.MixedRadix
import GPUProof.Layout.Crd
import Mathlib.Data.Set.Disjoint
import Mathlib.Logic.Pairwise
import Mathlib.Order.SetNotation
import Mathlib.Tactic.Ring

/-!
# Views: footprints at symbolic sizes

A view says, for every machine, which bytes of one buffer each instance of one level of a launch
covers, at every size assignment: a layout of the layout algebra (GPUProof/Layout/), a
mixed-radix key (GPUProof/MixedRadix.lean) that numbers the instances, a binding that sets
the key's digits to an instance's coordinates, and the instances that own a tile, so that an
instance that writes nothing (a thread of a launch past a matrix's sizes) covers no byte.
docs/proofs/mixed-radix.md ("Footprints at symbolic sizes") gives the design.

* `Sig.Inst S L ℓ g`: `g` is an instance of level `ℓ` in launch `L`, for every machine `S`.
* `View S`: a layout at each size assignment, a level, a buffer, a key, a binding and the
  instances that own a tile, for every machine `S`.
* `View.Owner v σ L g`: `g` is an instance of the view's level in `L` that owns a tile at `σ`.
* `View.WF v σ L`: the view `v` is well formed at one size assignment `σ` and one launch `L`.
* `View.off v σ L g c` and `View.tile v σ L g`: the offset of coordinate `c` of instance `g`, and
  the bytes that `g` covers, none when `g` owns no tile.
* `Tiling T D`, `View.bytes v σ`, `View.tiles v σ L`: sets that lie in `D` and are pairwise
  disjoint, the first `radixProd · cosize` bytes of the view's buffer, and the tiles of the
  instances of the view's level.
* `View.offAt v d σ L g c`, `View.tileAt`, `View.tilesAt`, `View.bytesAt` and
  `View.Interleaved v d σ`: the offsets, tiles and bytes at the key stride `d σ` in place of the
  cosize, `key · d σ + lay(c)`, and the layout interleaving there (its offsets modulo
  `radixProd · d σ` below `d σ`), for a footprint that interleaves with other instances' (a
  grid-stride loop's, where thread `t` of `T` owns elements `t`, `t + T`, ...).
* `View.Separated v d σ`: no two offsets of the layout differ by `m · d σ` for `0 < m` below the
  radix product (no more owners than columns of a row-major matrix are separated, so their tiles
  tile by `View.tiling_separated`, while their layout can fail to interleave).
* `View.guardAt v d N σ L g`, `View.guardsAt`: the bytes of `g`'s tile at the key stride `d`
  whose offsets are below a bound `N σ`, the footprint of a loop whose stores are guarded by the
  element's offset (a grid-stride loop's `i < n` where the layout lists every iteration).
* `View.inner v n`, `View.outer v n`, `View.Inside v L ℓ i j`, `View.coarsenAt v d ℓ n bind'`
  and `View.coarsen v ℓ n bind'`: the key's `n` least significant digits and the others,
  instance `j` of the view's level lying in instance `i` of level `ℓ`, and the view at level `ℓ`
  whose layout has the inner digits as one more mode, of stride `d σ` or the cosize.

It proves, for every machine:

* `View.off_lt`: at a well formed view, every offset of an owner's tile is below
  `radixProd · cosize`;
* `View.key_fits`: at a well formed view and every width `w` at which the key's radix product is
  below `2 ^ (w - 1)`, an owner's key value fits `w` bits (`WordFit`, by `MixedRadix.fits`); the
  offsets are natural numbers, models of a kernel's words, and this is the premise that relates
  the two;
* `View.tiling_separated`: when the machine's placement is injective (`PlaceInj`), the tiles at
  a key stride `d` of a view well formed at `σ` and `L` that is separated at `d` tile
  `View.bytesAt` (`Tiling`): they lie there and two instances' tiles are disjoint (by
  `MixedRadix.lt_prod`, `Lay.call_lt_cosize`, `MixedRadix.eq_iff_digits` and `WF.key_inj`);
* `View.separated_of_disjoint`: where every key value below the radix product is an owner's,
  disjoint tiles at `d` make the layout separated at `d`, so separation is the condition both
  necessary and sufficient there;
* `View.separated_of_interleaved`, `View.tilingAt`: an interleaving layout is separated (by
  `View.key_eq_of_mod`), so the tiles at an interleaving key stride tile `View.bytesAt`;
* `View.tiling`: the tiles of a view well formed at `σ` and `L` tile its bytes: they lie in
  `View.bytes` (`View.off_lt`), and two instances' tiles are disjoint by `View.tilingAt` at the
  cosize, where every well formed view interleaves (`View.interleaved_cosize`);
* `View.coverAt`, `View.cover_iffAt`: the owners' tiles at a key stride `d` cover the first
  `P · d · Q` bytes of the view's buffer when every offset `r + P d q` (`r < d σ`, `q < Q`) is a
  coordinate's (`hl`) and every key value below `P` is an owner's (`hk`), and, at a well formed
  view on an injective placement whose offsets modulo `P · d σ` are below `d σ`, with `Q = 1` or
  `P` at least the radix product, only then;
* `View.cover`, `View.cover_iff`: their cases at the cosize, `P = B` and `Q = 1`: the owners'
  tiles cover the first `B · cosize` bytes when every offset below the cosize is a coordinate's
  and every key value below `B` is an owner's, and, at a well formed view on an injective
  placement and a positive `B`, only then;
* `GPUProof.Tiling.mono`, `View.guardAt_subset`, `View.tile_subset_guardAt`,
  `View.cover_guardAt`: sets inside a tiling's sets tile its domain, so guarded tiles of a tiling
  tile it; a guarded tile lies in its tile, and holds it when every offset is below the bound; and
  on an injective placement the guarded tiles cover the first `N σ` bytes that the tiles cover;
* `View.coarsenAt_size`, `View.coarsenAt_call`, `View.coarsen_cosize`: the coarse layout's size
  is the size times the inner radix product `R`, its offset of `c'` is the offset of `c' % size`
  plus `c' / size` times the key stride (by `colex_append` and `Lay.call_scalar`), and, at the
  cosize, its cosize is `R` cosizes;
* `View.tile_subset_coarsenAt`: at a view well formed at `σ` and `L`, a key stride `d` and an
  instance `i` of `ℓ` whose owners agree on the outer digits (`hn`), the tiles at `d` of the
  instances inside `i` lie in the coarse view's tile of `i` at the key stride `R · d` (by
  `MixedRadix.val_append`);
* `View.coarsenAt_tile`: when the owners inside `i` also realize every inner key value (`ho`), the
  coarse view's tile of `i` at `R · d` is the union of the tiles at `d` of the instances inside
  it;
* `View.coarsen_size`, `View.coarsen_call`, `View.tile_subset_coarsen`, `View.coarsen_tile`:
  their cases at the cosize, through `View.coarsen_tileAt` (the coarse cosize is `R` cosizes).

MojoProofTest/GPUProof/View.lean has the instances at one machine: two views well formed at every
admissible assignment and launch of their kernels, the tiles of their instances, their tilings
and coverage, gemv's view coarsened at the block level, and the mutants.
-/

namespace GPUProof

open GPUProof.Layout GPUProof.Layout.Tup

variable {S : Sig}

/-- The instances of level `ℓ` in launch `L`, for every machine `S`: `g` is one when a thread of
`L` lies in it. -/
def Sig.Inst (S : Sig) (L : S.Launch) (ℓ : S.Level) (g : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L ℓ t = g

/-- A footprint at symbolic sizes, for every machine `S`: at each size assignment `σ`, instance
`g` of `level` in launch `L` that `owns` a tile covers the bytes of buffer `buf` at the offsets
`key · cosize + lay(c)`, for the coordinates `c` below the layout's size, where `key` is valued
at `bind L g σ`, the assignment `σ` with the variables of the key's digits set to `g`'s
coordinates. An instance that owns no tile covers no byte. -/
structure View (S : Sig) where
  /-- The view with these fields. -/
  mk ::
  /-- The layout of one instance's tile at each size assignment. -/
  lay : Sizes → Lay
  /-- The level whose instances the tiles belong to. -/
  level : S.Level
  /-- The buffer the tiles lie in. -/
  buf : S.Buf
  /-- The index that numbers the instances: an instance's tile starts at the key's value times
  the layout's cosize. -/
  key : MixedRadix
  /-- The size assignment at an instance: `bind L g σ` is `σ` with the variables of the key's
  digits set to instance `g`'s coordinates in launch `L`. -/
  bind : S.Launch → S.Gid → Sizes → Sizes
  /-- The instances that own a tile: `owns L g σ` says that instance `g` of launch `L` writes its
  tile at `σ`, as a kernel's guard on its coordinates says (the threads of a launch past a
  matrix's sizes own none). -/
  owns : S.Launch → S.Gid → Sizes → Prop

namespace View

/-- The owners of a view at a size assignment `σ` and a launch `L`, for every machine: the
instances of the view's level in `L` that own a tile at `σ`. -/
def Owner (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Prop :=
  S.Inst L v.level g ∧ v.owns L g σ

/-- The offset of coordinate `c` of instance `g` at the size assignment `σ`, for every machine:
the key's value at `bind L g σ` times the layout's cosize, plus the layout's offset of `c`. -/
def off (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) (c : Nat) : Nat :=
  v.key.val (v.bind L g σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false)

/-- The bytes of instance `g` at the size assignment `σ`, for every machine: when `g` owns a
tile, the bytes of the view's buffer at the offsets of the coordinates below the layout's size;
otherwise none. -/
def tile (v : View S) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Set S.Loc :=
  {x | v.owns L g σ ∧ ∃ c < (v.lay σ).size, x = S.place v.buf (v.off σ L g c)}

/-- A view well formed at one size assignment `σ` and one launch `L`, for every machine: its
layout at `σ` is congruent with positive extents, and at every owner (an instance of its level
in `L` that owns a tile) the key is in range, its radices do not read the bound digits, and the
digits tell the owners apart. A view is well formed at the assignments and launches its kernel
admits, not at every one: at the assignment `0` every radix is `0`, so no owner's digits are in
range, and a view whose kernel has an owner at `0` is not well formed there. -/
structure WF (v : View S) (σ : Sizes) (L : S.Launch) : Prop where
  /-- The proof of well-formedness from these fields. -/
  mk ::
  /-- The layout's shape and stride at `σ` have one nesting. -/
  congruent : congruentL (v.lay σ).shape (v.lay σ).stride = true
  /-- Every extent of the layout's shape at `σ` is positive. -/
  pos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s
  /-- At every owner, each digit of the key is below its radix. -/
  range : ∀ g, v.Owner σ L g → v.key.InRange (v.bind L g σ)
  /-- At every owner, the radices have their values at `σ`: the binding sets no variable that a
  radix reads. -/
  radices : ∀ g, v.Owner σ L g →
    v.key.digits.map (fun p => p.2.eval (v.bind L g σ)) = v.key.digits.map (fun p => p.2.eval σ)
  /-- Two owners whose digits have the same values are one. -/
  key_inj : ∀ g g', v.Owner σ L g → v.Owner σ L g' →
    v.key.digitVals (v.bind L g σ) = v.key.digitVals (v.bind L g' σ) → g = g'

/-! ## Tilings -/

/-- **Bounds and disjointness**, for every index type `ι` and element type `α`: the sets `T i`
tile `D` when each lies in `D` and two of different indices are disjoint. Coverage is not a
clause: a view's tiles cover the bytes of the key values its owners have (`View.cover`), which
may be fewer than `bytes`. -/
def _root_.GPUProof.Tiling {ι α : Type} (T : ι → Set α) (D : Set α) : Prop :=
  (∀ i, T i ⊆ D) ∧ Pairwise fun i j => Disjoint (T i) (T j)

/-- The bytes a view may cover at the size assignment `σ`, for every machine: the first
`radixProd · cosize` offsets of its buffer. -/
def bytes (v : View S) (σ : Sizes) : Set S.Loc :=
  {x | ∃ i : Nat, i < v.key.radixProd σ * (v.lay σ).cosize ∧ x = S.place v.buf i}

/-- The tiles of the instances of the view's level in launch `L` at the size assignment `σ`, for
every machine. -/
def tiles (v : View S) (σ : Sizes) (L : S.Launch) : {g // S.Inst L v.level g} → Set S.Loc :=
  fun g => v.tile σ L g.1

/-- **An owner's offsets are in bounds**, for every machine: at a view well formed at `σ` and
`L`, every owner `g` and coordinate `c` below the layout's size, the offset of `c` is below the
radix product at `σ` times the cosize. The key at `g` is below its radix product
(`MixedRadix.lt_prod`), which is the one at `σ` (`WF.radices`), and the layout's offset is below
the cosize (`Lay.call_lt_cosize`). -/
theorem off_lt {v : View S} {σ : Sizes} {L : S.Launch} {g : S.Gid} (hv : v.WF σ L)
    (hg : v.Owner σ L g) {c : Nat} (hc : c < (v.lay σ).size) :
    v.off σ L g c < v.key.radixProd σ * (v.lay σ).cosize := by
  have ha := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc
  have hk : v.key.val (v.bind L g σ) < v.key.radixProd σ := by
    have h := MixedRadix.lt_prod (hv.range g hg)
    rwa [MixedRadix.radixProd, hv.radices g hg] at h
  calc v.off σ L g c < (v.key.val (v.bind L g σ) + 1) * (v.lay σ).cosize := by
        rw [Nat.succ_mul]
        exact Nat.add_lt_add_left ha _
    _ ≤ v.key.radixProd σ * (v.lay σ).cosize := Nat.mul_le_mul_right _ hk

/-- **The word premise: an owner's key value fits `w` bits.** For every machine, view, size
assignment `σ` and launch `L` at which the view is well formed, every owner `g` and every width
`w` at which the key's radix product at `σ` is below `2 ^ (w - 1)` (`hw`, the view's word
premise at `w`): the key value at `g`'s binding fits `w` bits (`WordFit`), so its `w`-bit word
has that value, signed and unsigned, and sign extension keeps it. It is
`MixedRadix.fits` at the binding, whose radices are those at `σ` (`WF.radices`). The tiles are
natural-number models of offsets; this premise is what relates them to a kernel's `w`-bit
words. -/
theorem key_fits {v : View S} {σ : Sizes} {L : S.Launch} {g : S.Gid} (hv : v.WF σ L)
    (hg : v.Owner σ L g) {w : Nat} (hw : v.key.radixProd σ < 2 ^ (w - 1)) :
    WordFit w (v.key.val (v.bind L g σ)) := by
  refine MixedRadix.fits (hv.range g hg) ?_
  unfold MixedRadix.radixProd at hw ⊢
  rwa [hv.radices g hg]

/-! ## Interleaved tiles: a key stride -/

/-- The offset of coordinate `c` of instance `g` at the size assignment `σ` and the key stride
`d`, for every machine: the key's value at `bind L g σ` times `d σ`, plus the layout's offset of
`c`. At `d σ` the layout's cosize it is `off`. -/
def offAt (v : View S) (d : Sizes → Nat) (σ : Sizes) (L : S.Launch) (g : S.Gid) (c : Nat) :
    Nat :=
  v.key.val (v.bind L g σ) * d σ + (v.lay σ).call (leaf c false)

/-- The bytes of instance `g` at the size assignment `σ` and the key stride `d`, for every
machine: when `g` owns a tile, the bytes of the view's buffer at the offsets `offAt` of the
coordinates below the layout's size; otherwise none. At `d σ` the cosize it is `tile`. -/
def tileAt (v : View S) (d : Sizes → Nat) (σ : Sizes) (L : S.Launch) (g : S.Gid) : Set S.Loc :=
  {x | v.owns L g σ ∧ ∃ c < (v.lay σ).size, x = S.place v.buf (v.offAt d σ L g c)}

/-- The tiles at the key stride `d` of the instances of the view's level in launch `L` at the
size assignment `σ`, for every machine. -/
def tilesAt (v : View S) (d : Sizes → Nat) (σ : Sizes) (L : S.Launch) :
    {g // S.Inst L v.level g} → Set S.Loc :=
  fun g => v.tileAt d σ L g.1

/-- The bytes a view may cover at the size assignment `σ` and the key stride `d`, for every
machine: the first `radixProd · d + cosize - d` offsets of its buffer, those of the key values
below the radix product. At `d σ` the cosize it is `bytes`. -/
def bytesAt (v : View S) (d : Sizes → Nat) (σ : Sizes) : Set S.Loc :=
  {x | ∃ i : Nat, i < v.key.radixProd σ * d σ + (v.lay σ).cosize - d σ ∧ x = S.place v.buf i}

/-- The view's layout interleaves at the key stride `d` and the size assignment `σ`, for every
machine: every offset of a coordinate below the layout's size, modulo the radix product times
`d σ`, is below `d σ`. The key values' tiles, each shifted by `key · d σ`, then interleave
without meeting (`key_eq_of_mod`). A layout whose offsets are below `d σ` interleaves, so every
well formed view does at `d σ` the cosize (`interleaved_cosize`); so does the layout of `X`
elements of `d σ` bytes at the stride `radixProd · d σ`, a grid-stride loop's footprint. -/
def Interleaved (v : View S) (d : Sizes → Nat) (σ : Sizes) : Prop :=
  ∀ c < (v.lay σ).size, (v.lay σ).call (leaf c false) % (v.key.radixProd σ * d σ) < d σ

/-- The view's layout is separated at the key stride `d` and the size assignment `σ`, for every
machine: no two offsets of coordinates below the layout's size differ by `m · d σ` for an `m`
with `0 < m` below the radix product. It says that the key values' tiles, each shifted by
`key · d σ`, do not meet: it is sufficient for the tiles at `d` to be disjoint
(`tiling_separated`), and necessary where every key value below the radix product is an
owner's (`separated_of_disjoint`). Every interleaving layout is separated
(`separated_of_interleaved`); the converse fails: `R = 2` owners of the columns of a row-major
matrix of 3 floats, at `d σ = 4`, are separated (their offsets differ by no `4`) but do not
interleave (the offset 12 of the second row modulo 8 is 4). -/
def Separated (v : View S) (d : Sizes → Nat) (σ : Sizes) : Prop :=
  ∀ c < (v.lay σ).size, ∀ c' < (v.lay σ).size, ∀ m, 0 < m → m < v.key.radixProd σ →
    (v.lay σ).call (leaf c false) ≠ (v.lay σ).call (leaf c' false) + m * d σ

/-- **Two key values at one offset are one**, for every bound `R`, stride `d`, key values `k`
and `k'` below `R` and offsets `a` and `a'` whose remainders modulo `R · d` are below `d`: if
`k · d + a = k' · d + a'`, then `k = k'`, as `k · d + a` modulo `R · d`, divided by `d`, is
`k`. -/
theorem key_eq_of_mod {R d k k' a a' : Nat} (hk : k < R) (hk' : k' < R) (ha : a % (R * d) < d)
    (ha' : a' % (R * d) < d) (h : k * d + a = k' * d + a') : k = k' := by
  have e : ∀ {k a : Nat}, k < R → a % (R * d) < d → (k * d + a) % (R * d) / d = k := by
    intro k a hk ha
    have hd : 0 < d := Nat.lt_of_le_of_lt (Nat.zero_le _) ha
    have hlt : k * d + a % (R * d) < R * d :=
      calc k * d + a % (R * d) < k * d + d := Nat.add_lt_add_left ha _
        _ = (k + 1) * d := (Nat.succ_mul k d).symm
        _ ≤ R * d := Nat.mul_le_mul_right _ hk
    rw [← Nat.mod_add_div a (R * d), ← Nat.add_assoc, Nat.add_mul_mod_self_left,
      Nat.mod_eq_of_lt hlt, Nat.add_comm, Nat.add_mul_div_right _ _ hd, Nat.div_eq_of_lt ha,
      Nat.zero_add]
  rw [← e hk ha, ← e hk' ha', h]

/-- **A well formed view interleaves at its cosize**, for every machine, view, size assignment
`σ` and launch at which it is well formed: every offset of a coordinate below the layout's size
is below the cosize (`Lay.call_lt_cosize`), and so is its remainder. -/
theorem interleaved_cosize (v : View S) {σ : Sizes} {L : S.Launch} (hv : v.WF σ L) :
    v.Interleaved (fun σ => (v.lay σ).cosize) σ := fun c hc =>
  Nat.lt_of_le_of_lt (Nat.mod_le _ _)
    (Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc)

/-- **An interleaving layout is separated**, for every machine, view, key stride `d` and size
assignment `σ`: offsets `a = a' + m · d σ` with `0 < m < R` (`R` the radix product), both below
`d σ` modulo `R · d σ` (`Interleaved`), would give the key values `0` and `m` at one offset,
which `key_eq_of_mod` makes equal. -/
theorem separated_of_interleaved (v : View S) {d : Sizes → Nat} {σ : Sizes}
    (hd : v.Interleaved d σ) : v.Separated d σ := fun c hc c' hc' m hm hmR he =>
  Nat.ne_of_lt hm (key_eq_of_mod (Nat.lt_trans hm hmR) hmR (hd c hc) (hd c' hc')
    (by rw [Nat.zero_mul, Nat.zero_add, he, Nat.add_comm]))

/-- **The tiles at a separating key stride tile their bytes.** For every machine whose placement
is injective (`PlaceInj`), view, key stride `d`, size assignment `σ` and launch `L` at which the
view is well formed (`WF`) and separated at `d` (`Separated`): every tile at `d` of an instance
of the view's level lies in `bytesAt`, and the tiles of two instances are disjoint. An owner's
key value is below the radix product `R` (`MixedRadix.lt_prod`, `WF.radices`) and its layout's
offsets below the cosize `C` (`Lay.call_lt_cosize`), so its offsets are below `R d + C - d`; a
byte of two tiles is one offset `k d + a = k' d + a'` (`PlaceInj`), where `k < k'` would make
`a` the offset `a' + (k' - k) d`, so the keys are equal, the digits are equal
(`MixedRadix.eq_iff_digits` at the two bindings), and the instances are one (`WF.key_inj`).
Where every key value below `R` is an owner's, `Separated` is also necessary
(`separated_of_disjoint`). -/
theorem tiling_separated (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch} (hv : v.WF σ L) (hs : v.Separated d σ) :
    Tiling (v.tilesAt d σ L) (v.bytesAt d σ) := by
  have hk : ∀ g, v.Owner σ L g → v.key.val (v.bind L g σ) < v.key.radixProd σ := fun g hg => by
    have h := MixedRadix.lt_prod (hv.range g hg)
    rwa [MixedRadix.radixProd, hv.radices g hg] at h
  refine ⟨?_, ?_⟩
  · rintro ⟨g, hg⟩ x ⟨ho, c, hc, rfl⟩
    have ha := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc
    have hm : v.key.val (v.bind L g σ) * d σ + d σ ≤ v.key.radixProd σ * d σ := by
      rw [← Nat.succ_mul]
      exact Nat.mul_le_mul_right _ (hk g ⟨hg, ho⟩)
    refine ⟨v.offAt d σ L g c, ?_, rfl⟩
    show v.key.val (v.bind L g σ) * d σ + (v.lay σ).call (leaf c false) < _
    omega
  · rintro ⟨g, hg⟩ ⟨g', hg'⟩ hne
    refine Set.disjoint_left.2 fun x hx hx' => hne (Subtype.ext ?_)
    obtain ⟨ho, c, hc, rfl⟩ := hx
    obtain ⟨ho', c', hc', he⟩ := hx'
    have he' : v.offAt d σ L g c = v.offAt d σ L g' c' := Int.ofNat_inj.1 (hp he).2
    simp only [offAt] at he'
    have hkg := hk g ⟨hg, ho⟩
    have hkg' := hk g' ⟨hg', ho'⟩
    have hkk : v.key.val (v.bind L g σ) = v.key.val (v.bind L g' σ) := by
      rcases lt_trichotomy (v.key.val (v.bind L g σ)) (v.key.val (v.bind L g' σ)) with h | h | h
      · refine absurd ?_ (hs c hc c' hc' _ (Nat.sub_pos_of_lt h)
          (Nat.lt_of_le_of_lt (Nat.sub_le _ _) hkg'))
        have := Nat.mul_le_mul_right (d σ) h.le
        rw [Nat.sub_mul]
        omega
      · exact h
      · refine absurd ?_ (hs c' hc' c hc _ (Nat.sub_pos_of_lt h)
          (Nat.lt_of_le_of_lt (Nat.sub_le _ _) hkg))
        have := Nat.mul_le_mul_right (d σ) h.le
        rw [Nat.sub_mul]
        omega
    exact hv.key_inj g g' ⟨hg, ho⟩ ⟨hg', ho'⟩ ((MixedRadix.eq_iff_digits (hv.range g ⟨hg, ho⟩)
      (hv.range g' ⟨hg', ho'⟩) ((hv.radices g ⟨hg, ho⟩).trans
        (hv.radices g' ⟨hg', ho'⟩).symm)).1 hkk)

/-- **Separation is necessary for disjoint tiles**, for every machine, view, key stride `d`, size
assignment `σ` and launch `L` at which every key value below the radix product is an owner's
(`hk`): if the tiles at `d` of two instances of the view's level are disjoint, the layout is
separated at `d`. Offsets `a = a' + m · d σ` with `0 < m` below the radix product put the byte
`0 · d σ + a` in the tile of the owner of key value `0` and, as `m · d σ + a'`, in that of the
owner of key value `m`, two instances as their key values differ. No premise on the placement or
on `WF`. With `tiling_separated`, at a well formed view on an injective placement whose owners
have every key value, the tiles at `d` are disjoint exactly when the layout is separated. -/
theorem separated_of_disjoint (v : View S) (d : Sizes → Nat) {σ : Sizes} {L : S.Launch}
    (hk : ∀ k < v.key.radixProd σ, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k)
    (hd : Pairwise fun i j => Disjoint (v.tilesAt d σ L i) (v.tilesAt d σ L j)) :
    v.Separated d σ := by
  intro c hc c' hc' m hm hmR he
  obtain ⟨g, hg, hg0⟩ := hk 0 (Nat.lt_trans hm hmR)
  obtain ⟨g', hg', hgm⟩ := hk m hmR
  have hne : (⟨g, hg.1⟩ : {g // S.Inst L v.level g}) ≠ ⟨g', hg'.1⟩ := fun h => by
    have := congrArg (fun i : {g // S.Inst L v.level g} => v.key.val (v.bind L i.1 σ)) h
    simp only [hg0, hgm] at this
    exact Nat.ne_of_lt hm this
  have hx : S.place v.buf (v.offAt d σ L g c) ∈ v.tilesAt d σ L ⟨g, hg.1⟩ := ⟨hg.2, c, hc, rfl⟩
  refine Set.disjoint_left.1 (hd hne) hx ⟨hg'.2, c', hc', ?_⟩
  show S.place v.buf ↑(v.key.val (v.bind L g σ) * d σ + (v.lay σ).call (leaf c false)) =
    S.place v.buf ↑(v.key.val (v.bind L g' σ) * d σ + (v.lay σ).call (leaf c' false))
  rw [hg0, hgm, he, Nat.zero_mul, Nat.zero_add, Nat.add_comm]

/-- **The tiles at an interleaving key stride tile their bytes.** For every machine whose
placement is injective (`PlaceInj`), view, key stride `d`, size assignment `σ` and launch `L` at
which the view is well formed (`WF`) and interleaves at `d` (`Interleaved`): every tile at `d`
of an instance of the view's level lies in `bytesAt`, and the tiles of two instances are
disjoint. It is `tiling_separated`, as an interleaving layout is separated
(`separated_of_interleaved`, by `key_eq_of_mod`). At `d σ` the cosize it gives `tiling`'s
disjointness. -/
theorem tilingAt (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch} (hv : v.WF σ L) (hd : v.Interleaved d σ) :
    Tiling (v.tilesAt d σ L) (v.bytesAt d σ) :=
  v.tiling_separated d hp hv (v.separated_of_interleaved hd)

/-- **The tiles of a well formed view tile its bytes.** For every machine whose placement is
injective (`PlaceInj`), view, size assignment `σ` and launch `L` at which the view is well formed
(`WF`): every tile of an instance of the view's level lies in the view's bytes (`off_lt`), and
the tiles of two instances are disjoint: `tilingAt` at the key stride the cosize, at which every
well formed view interleaves (`interleaved_cosize`), as a byte of two tiles is one offset
`k C + a = k' C + a'` with `a, a' < C` the cosize. -/
theorem tiling (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) : Tiling (v.tiles σ L) (v.bytes σ) := by
  refine ⟨?_, (v.tilingAt (fun σ => (v.lay σ).cosize) hp hv (v.interleaved_cosize hv)).2⟩
  rintro ⟨g, hg⟩ x ⟨ho, c, hc, rfl⟩
  exact ⟨_, off_lt hv ⟨hg, ho⟩ hc, rfl⟩

/-- **The owners' tiles at a key stride cover the first `Q` periods**, for every machine, view,
key stride `d`, size assignment `σ`, launch `L`, key bound `P` and period count `Q`: when every
offset `r + P d q` with `r < d σ` and `q < Q` is the offset of a coordinate below the layout's
size (`hl`) and every key value below `P` is an owner's (`hk`), each of the first `P · d · Q`
bytes of the view's buffer is in an owner's tile at `d`. Byte `i` is the offset `r + P d q` of
the owner whose key value is `k`, with `q = i / (P d)`, `k = (i % (P d)) / d` and
`r = (i % (P d)) % d` (`Nat.mod_add_div`). At `d σ` the cosize, `P = B` and `Q = 1` it is
`cover`. At a well formed view on an injective placement, where the layout interleaves at the
period `P · d` and `Q = 1` or `P` is at least the radix product, the premises are needed
(`cover_iffAt`). -/
theorem coverAt (v : View S) (d : Sizes → Nat) {σ : Sizes} {L : S.Launch} {P Q : Nat}
    (hl : ∀ q < Q, ∀ r < d σ, ∃ c < (v.lay σ).size,
      (v.lay σ).call (leaf c false) = r + P * d σ * q)
    (hk : ∀ k < P, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k) :
    {x | ∃ i : Nat, i < P * d σ * Q ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tilesAt d σ L g := by
  rintro x ⟨i, hi, rfl⟩
  have hM : 0 < P * d σ := Nat.pos_of_ne_zero fun h => by
    rw [h, Nat.zero_mul] at hi
    exact Nat.not_lt_zero _ hi
  have hd : 0 < d σ := Nat.pos_of_ne_zero fun h => by
    rw [h, Nat.mul_zero] at hM
    exact lt_irrefl _ hM
  obtain ⟨g, hg, hgk⟩ := hk (i % (P * d σ) / d σ)
    (Nat.div_lt_of_lt_mul (lt_of_lt_of_eq (Nat.mod_lt _ hM) (Nat.mul_comm _ _)))
  obtain ⟨c, hc, hca⟩ := hl (i / (P * d σ)) (Nat.div_lt_of_lt_mul hi) (i % (P * d σ) % d σ)
    (Nat.mod_lt _ hd)
  refine Set.mem_iUnion.2 ⟨⟨g, hg.1⟩, hg.2, c, hc, ?_⟩
  have e1 := Nat.mod_add_div i (P * d σ)
  have e2 := Nat.mod_add_div (i % (P * d σ)) (d σ)
  have e : i % (P * d σ) / d σ * d σ + (i % (P * d σ) % d σ + P * d σ * (i / (P * d σ))) = i := by
    rw [Nat.mul_comm (i % (P * d σ) / d σ)]
    omega
  show S.place v.buf i =
    S.place v.buf ↑(v.key.val (v.bind L g σ) * d σ + (v.lay σ).call (leaf c false))
  rw [hgk, hca, e]

/-- **`coverAt`'s premises are the least where the layout interleaves at the period**, for every
machine whose placement is injective (`PlaceInj`), view, key stride `d`, size assignment `σ` and
launch `L` at which the view is well formed, and positive `P` and `Q`, when every offset of the
layout modulo `P · d σ` is below `d σ` (`hd`) and `Q = 1` or `P` is at least the radix product
(`hPQ`): the owners' tiles at `d` cover the first `P · d · Q` bytes exactly when every offset
`r + P d q` (`r < d σ`, `q < Q`) is a coordinate's and every key value below `P` is an owner's.
Byte `k d + r + P d q` in the tile of owner `g` at coordinate `c` is `g`'s key value `k'` times
`d σ` plus the offset of `c`; `k'` is below `P` (below the radix product at `σ`, or, at `Q = 1`,
`k' · d σ` is below `P · d σ`), so `k' = k` (`key_eq_of_mod` at the bound `P`) and the offset is
`r + P d q`. Without `hd` or `hPQ` it fails: docs/proofs/mixed-radix.md ("Coverage and
coarsening at a key stride") has a view, layer norm's, whose tiles cover the bytes while a key
value below `P`, or an offset `r + P d q`, is none. At `d σ` the cosize and `Q = 1` both hold
for every `P`, and it is `cover_iff`. -/
theorem cover_iffAt (v : View S) (d : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch} (hv : v.WF σ L) {P Q : Nat} (hP : 0 < P) (hQ : 0 < Q)
    (hd : ∀ c < (v.lay σ).size, (v.lay σ).call (leaf c false) % (P * d σ) < d σ)
    (hPQ : Q = 1 ∨ v.key.radixProd σ ≤ P) :
    {x | ∃ i : Nat, i < P * d σ * Q ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tilesAt d σ L g ↔
      (∀ q < Q, ∀ r < d σ, ∃ c < (v.lay σ).size,
        (v.lay σ).call (leaf c false) = r + P * d σ * q) ∧
        ∀ k < P, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k := by
  refine ⟨fun h => ?_, fun ⟨hl, hk⟩ => coverAt v d hl hk⟩
  have hd0 : 0 < d σ := Nat.lt_of_le_of_lt (Nat.zero_le _) (hd 0 (prod_pos _ hv.pos))
  have hm : ∀ k < P, ∀ q < Q, ∀ r < d σ, ∃ g, v.Owner σ L g ∧ ∃ c < (v.lay σ).size,
      v.key.val (v.bind L g σ) = k ∧ (v.lay σ).call (leaf c false) = r + P * d σ * q := by
    intro k hk q hq r hr
    have h1 : k * d σ + r < P * d σ :=
      calc k * d σ + r < (k + 1) * d σ := by rw [Nat.succ_mul]; exact Nat.add_lt_add_left hr _
        _ ≤ P * d σ := Nat.mul_le_mul_right _ hk
    have hi : k * d σ + (r + P * d σ * q) < P * d σ * Q := by
      have h2 : P * d σ * (q + 1) ≤ P * d σ * Q := Nat.mul_le_mul_left _ hq
      rw [Nat.mul_succ] at h2
      omega
    obtain ⟨⟨g, hg⟩, ho, c, hc, he⟩ := Set.mem_iUnion.1 (h ⟨_, hi, rfl⟩)
    have he' : k * d σ + (r + P * d σ * q) = v.offAt d σ L g c := Int.ofNat_inj.1 (hp he).2
    simp only [offAt] at he'
    have hgP : v.key.val (v.bind L g σ) < P := by
      rcases hPQ with rfl | hRP
      · obtain rfl : q = 0 := by omega
        refine Nat.lt_of_mul_lt_mul_right (a := d σ) ?_
        omega
      · have h := MixedRadix.lt_prod (hv.range g ⟨hg, ho⟩)
        rw [MixedRadix.radixProd, hv.radices g ⟨hg, ho⟩] at h
        exact Nat.lt_of_lt_of_le h hRP
    have hra : (r + P * d σ * q) % (P * d σ) < d σ := by
      rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (Nat.lt_of_lt_of_le hr
        (Nat.le_mul_of_pos_left _ hP))]
      exact hr
    have hkk := key_eq_of_mod hk hgP hra (hd c hc) he'
    refine ⟨g, ⟨hg, ho⟩, c, hc, hkk.symm, ?_⟩
    rw [← hkk] at he'
    omega
  refine ⟨fun q hq r hr => ?_, fun k hk => ?_⟩
  · obtain ⟨-, -, c, hc, -, e⟩ := hm 0 hP q hq r hr
    exact ⟨c, hc, e⟩
  · obtain ⟨g, hg, -, -, e, -⟩ := hm k hk 0 hQ 0 hd0
    exact ⟨g, hg, e⟩

/-- **The owners' tiles cover the bytes of the first `B` key values**, for every machine, view,
size assignment `σ`, launch `L` and bound `B`: when every offset below the layout's cosize is the
offset of a coordinate below its size (`hl`) and every key value below `B` is an owner's (`hk`),
each of the first `B · cosize` bytes of the view's buffer is in an owner's tile. It is `coverAt`
at the key stride the cosize, `P = B` and one period. At `B` the radix product the bytes are
`bytes`. At a well formed view on an injective placement and every positive `B` the two premises
are needed (`cover_iff`); at `B = 0` the set is empty, and a layout with holes covers it. -/
theorem cover (v : View S) {σ : Sizes} {L : S.Launch} {B : Nat}
    (hl : ∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a)
    (hk : ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g :=
  fun _ ⟨i, hi, hx⟩ => v.coverAt (fun σ => (v.lay σ).cosize) (Q := 1)
    (fun _ hq r hr => by obtain rfl := Nat.lt_one_iff.1 hq; exact hl r hr) hk
    ⟨i, by rwa [Nat.mul_one], hx⟩

/-- **`cover`'s premises are the least at every positive bound**, for every machine whose
placement is injective (`PlaceInj`), view, size assignment `σ` and launch `L` at which the view is
well formed, and positive bound `B` (`hB`): the owners' tiles cover the first `B · cosize` bytes
of the view's buffer exactly when every offset below the cosize is a coordinate's and every key
value below `B` is an owner's. It is `cover_iffAt` at the key stride the cosize, `P = B` and one
period, where every offset is below the cosize (`Lay.call_lt_cosize`), so below it modulo
`B · cosize`. At `B = 0` the covered set is empty, and a layout with holes covers it, so `hl` is
not among the least premises there. -/
theorem cover_iff (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) {B : Nat} (hB : 0 < B) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g ↔
      (∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a) ∧
        ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k := by
  have h := v.cover_iffAt (fun σ => (v.lay σ).cosize) hp hv hB Nat.one_pos (fun c hc =>
    Nat.lt_of_le_of_lt (Nat.mod_le _ _)
      (Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc)) (.inl rfl)
  simp only [Nat.mul_one, Nat.lt_one_iff, forall_eq, Nat.mul_zero, Nat.add_zero] at h
  exact h

/-! ## Guarded tiles -/

/-- **Sets inside the sets of a tiling tile its domain**, for every index type, element type,
sets `T`, `T'` and domain `D`: when `T` tiles `D` and each `T' i` lies in `T i`, `T'` tiles `D`
(each lies in `D`, and two of different indices are disjoint, `Disjoint.mono`). -/
theorem _root_.GPUProof.Tiling.mono {ι α : Type} {T T' : ι → Set α} {D : Set α}
    (h : Tiling T D) (hs : ∀ i, T' i ⊆ T i) : Tiling T' D :=
  ⟨fun i => (hs i).trans (h.1 i), fun _ _ hij => (h.2 hij).mono (hs _) (hs _)⟩

/-- The bytes of instance `g` at the key stride `d` under the bound `N`, for every machine,
view, key stride, bound, size assignment `σ` and launch `L`: when `g` owns a tile, the bytes of
the view's buffer at the offsets `offAt` of the coordinates below the layout's size that are
below `N σ`; otherwise none. It is the footprint of a loop whose stores are guarded by the
element's offset below a bound (a grid-stride loop's `i < n`, at `N σ` the bytes of `n`
elements), where the layout lists every iteration. Where every offset is below `N σ` it is
`tileAt` (`guardAt_subset`, `tile_subset_guardAt`). -/
def guardAt (v : View S) (d N : Sizes → Nat) (σ : Sizes) (L : S.Launch) (g : S.Gid) :
    Set S.Loc :=
  {x | v.owns L g σ ∧ ∃ c < (v.lay σ).size, v.offAt d σ L g c < N σ ∧
    x = S.place v.buf (v.offAt d σ L g c)}

/-- The tiles at the key stride `d` under the bound `N` of the instances of the view's level in
launch `L` at the size assignment `σ`, for every machine. -/
def guardsAt (v : View S) (d N : Sizes → Nat) (σ : Sizes) (L : S.Launch) :
    {g // S.Inst L v.level g} → Set S.Loc :=
  fun g => v.guardAt d N σ L g.1

/-- **A guarded tile lies in its tile**, for every machine, view, key stride `d`, bound `N`, size
assignment, launch and instance: `guardAt` keeps some coordinates of `tileAt`. So the guarded
tiles of a tiling at `d` tile its domain (`GPUProof.Tiling.mono`). -/
theorem guardAt_subset (v : View S) (d N : Sizes → Nat) (σ : Sizes) (L : S.Launch) (g : S.Gid) :
    v.guardAt d N σ L g ⊆ v.tileAt d σ L g :=
  fun _ ⟨ho, c, hc, _, hx⟩ => ⟨ho, c, hc, hx⟩

/-- **A guard that every offset meets keeps the whole tile**, for every machine, view, key
stride `d`, bound `N`, size assignment `σ`, launch `L` and instance `g`: when every offset at `d`
of a coordinate below the layout's size is below `N σ`, the tile of `g` lies in its guarded tile,
which is then the tile (`guardAt_subset`). -/
theorem tile_subset_guardAt (v : View S) {d N : Sizes → Nat} {σ : Sizes} {L : S.Launch}
    {g : S.Gid} (h : ∀ c < (v.lay σ).size, v.offAt d σ L g c < N σ) :
    v.tileAt d σ L g ⊆ v.guardAt d N σ L g :=
  fun _ ⟨ho, c, hc, hx⟩ => ⟨ho, c, hc, h c hc, hx⟩

/-- **The guarded tiles cover the bytes below the bound that the tiles cover**, for every machine
whose placement is injective (`PlaceInj`), view, key stride `d`, bound `N`, size assignment `σ`
and launch `L`: when each of the first `N σ` bytes of the view's buffer is in an owner's tile at
`d`, it is in that owner's guarded tile, as the byte's offset, below `N σ`, is the coordinate's
(`hp`). -/
theorem cover_guardAt (v : View S) (d N : Sizes → Nat) (hp : PlaceInj S.place) {σ : Sizes}
    {L : S.Launch}
    (h : {x | ∃ i : Nat, i < N σ ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tilesAt d σ L g) :
    {x | ∃ i : Nat, i < N σ ∧ x = S.place v.buf i} ⊆ ⋃ g, v.guardsAt d N σ L g := by
  rintro x ⟨i, hi, rfl⟩
  obtain ⟨g, ho, c, hc, he⟩ := Set.mem_iUnion.1 (h ⟨i, hi, rfl⟩)
  have e : i = v.offAt d σ L g.1 c := by exact_mod_cast (hp he).2
  exact Set.mem_iUnion.2 ⟨g, ho, c, hc, e ▸ hi, he⟩

/-! ## Coarsening -/

/-- The key's `n` least significant digits, for every machine. -/
def inner (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.take n⟩

/-- The key's digits after the `n` least significant ones, for every machine. -/
def outer (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.drop n⟩

/-- Instance `j` of the view's level lies in instance `i` of level `ℓ` in launch `L`, for every
machine: a thread of `L` is in both. -/
def Inside (v : View S) (L : S.Launch) (ℓ : S.Level) (i j : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L v.level t = j ∧ S.group L ℓ t = i

/-- **The view at level `ℓ` at a key stride**, for every machine, view and key stride `d`: the
key's `n` least significant digits become one more layout mode, of extent their radix product and
stride `d`; the key is the other digits, `bind'` binds them at an instance of `ℓ`, and an
instance of `ℓ` owns a tile when an owner of the view lies in it. At a size assignment and launch
where the view is well formed, the tile of an instance `i` of `ℓ` at the key stride `R · d` (`R`
the inner radix product) is the union of the view's tiles at `d` inside `i` (`coarsenAt_tile`)
when the owners inside `i` agree on the outer digits with `bind'` (`hn`) and every inner key value
below `R` is an owner's inside `i` (`ho`). Without `ho` only the inclusion of that union in the
tile holds (`tile_subset_coarsenAt`): the tile also has the bytes of the inner key values no owner
has. -/
def coarsenAt (v : View S) (d : Sizes → Nat) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) : View S where
  lay σ := ⟨(v.lay σ).shape ++ [leaf ((v.inner n).radixProd σ) false],
    (v.lay σ).stride ++ [leaf (d σ) false]⟩
  level := ℓ
  buf := v.buf
  key := v.outer n
  bind := bind'
  owns L i σ := ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ

/-- **The view at level `ℓ`**, for every machine: `coarsenAt` at the key stride the cosize. The
key's `n` least significant digits become one more layout mode, of extent their radix product and
stride the cosize; the key is the other digits, `bind'` binds them at an instance of `ℓ`, and an
instance of `ℓ` owns a tile when an owner of the view lies in it. -/
def coarsen (v : View S) (ℓ : S.Level) (n : Nat) (bind' : S.Launch → S.Gid → Sizes → Sizes) :
    View S :=
  v.coarsenAt (fun σ => (v.lay σ).cosize) ℓ n bind'

/-- **The coarse layout's size**, for every machine, view, key stride, level, digit count,
binding and size assignment: the layout's size times the inner radix product. -/
theorem coarsenAt_size (v : View S) (d : Sizes → Nat) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) (σ : Sizes) :
    ((v.coarsenAt d ℓ n bind').lay σ).size = (v.lay σ).size * (v.inner n).radixProd σ := by
  simp only [coarsenAt, Lay.size, Tup.size, Tup.leaves, Tup.leavesL_append, leavesL,
    List.prod_append, List.append_nil, List.prod_cons, List.prod_nil, Nat.mul_one]

/-- **The coarse layout's size**, for every machine, view, level, digit count, binding and size
assignment: `coarsenAt_size` at the key stride the cosize. -/
theorem coarsen_size (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) (σ : Sizes) :
    ((v.coarsen ℓ n bind').lay σ).size = (v.lay σ).size * (v.inner n).radixProd σ :=
  v.coarsenAt_size _ ℓ n bind' σ

/-- The coarse layout's shape and stride are congruent, for every machine, view, key stride,
level, digit count, binding and size assignment at which the layout's are. -/
theorem coarsenAt_congruent (v : View S) (d : Sizes → Nat) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true) :
    congruentL ((v.coarsenAt d ℓ n bind').lay σ).shape
      ((v.coarsenAt d ℓ n bind').lay σ).stride = true :=
  Tup.congruentL_append _ _ _ _ h rfl

/-- The coarse layout's shape and stride are congruent, for every machine, view, level, digit
count, binding and size assignment at which the layout's are: `coarsenAt_congruent` at the key
stride the cosize. -/
theorem coarsen_congruent (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true) :
    congruentL ((v.coarsen ℓ n bind').lay σ).shape ((v.coarsen ℓ n bind').lay σ).stride = true :=
  v.coarsenAt_congruent _ ℓ n bind' h

/-- **The coarse layout's offsets**, for every machine, view, key stride `d`, level, digit count,
binding and size assignment at which the layout is congruent with positive extents: the coarse
offset of `c'` below the coarse size is the layout's offset of `c' % size` plus `c' / size` times
`d` (the colexicographic digits split at the last mode, `colex_append`). -/
theorem coarsenAt_call (v : View S) (d : Sizes → Nat) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true)
    (hpos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s) {c : Nat}
    (hc : c < ((v.coarsenAt d ℓ n bind').lay σ).size) :
    ((v.coarsenAt d ℓ n bind').lay σ).call (leaf c false) =
      (v.lay σ).call (leaf (c % (v.lay σ).size) false) + c / (v.lay σ).size * d σ := by
  have hZ : 0 < (v.lay σ).size := prod_pos _ hpos
  have hZ' : (v.lay σ).size = (leavesL (v.lay σ).shape).prod := by
    simp only [Lay.size, Tup.size, Tup.leaves]
  have hR : c / (v.lay σ).size < (v.inner n).radixProd σ := by
    rw [coarsenAt_size] at hc
    exact Nat.div_lt_of_lt_mul hc
  rw [Lay.call_scalar _ (coarsenAt_congruent v d ℓ n bind' h) c false hc,
    Lay.call_scalar _ h _ false (Nat.mod_lt _ hZ)]
  simp only [coarsenAt, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil]
  rw [hZ'] at hR
  rw [colex_append, sum_zipWith_append _ _ _ _ (by
      rw [colex_length]; exact congruentL_leaves_length _ _ h), hZ', colex_mod]
  simp [colex, Nat.mod_eq_of_lt hR]

/-- **The coarse layout's offsets**, for every machine, view, level, digit count, binding and
size assignment at which the layout is congruent with positive extents: the coarse offset of `c'`
below the coarse size is the layout's offset of `c' % size` plus `c' / size` cosizes
(`coarsenAt_call` at the key stride the cosize). -/
theorem coarsen_call (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true)
    (hpos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s) {c : Nat}
    (hc : c < ((v.coarsen ℓ n bind').lay σ).size) :
    ((v.coarsen ℓ n bind').lay σ).call (leaf c false) =
      (v.lay σ).call (leaf (c % (v.lay σ).size) false) + c / (v.lay σ).size * (v.lay σ).cosize :=
  v.coarsenAt_call _ ℓ n bind' h hpos hc

/-- **The coarse layout's cosize**, for every machine, view, level, digit count, binding and
size assignment at which the layout is congruent with positive extents and the inner radix
product `R` is positive: `R` times the layout's cosize (`Lay.cosize_eq` at both). At another key
stride the coarse cosize need not be `R` times one: the tiles of `coarsenAt` are taken at the key
stride `R · d` (`coarsenAt_tile`), not at their cosize. -/
theorem coarsen_cosize (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true)
    (hpos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s) (hR : 0 < (v.inner n).radixProd σ) :
    ((v.coarsen ℓ n bind').lay σ).cosize = (v.inner n).radixProd σ * (v.lay σ).cosize := by
  have hpos' : ∀ s ∈ leavesL ((v.coarsen ℓ n bind').lay σ).shape, 0 < s := by
    simp only [coarsen, coarsenAt, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil,
      List.mem_append, List.mem_singleton]
    rintro s (hs | rfl)
    · exact hpos s hs
    · exact hR
  rw [Lay.cosize_eq _ (coarsen_congruent v ℓ n bind' h) hpos', Lay.cosize_eq _ h hpos]
  simp only [coarsen, coarsenAt, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil]
  rw [List.zipWith_append (congruentL_leaves_length _ _ h), List.sum_append, Lay.cosize_eq _ h hpos]
  obtain ⟨r, hr⟩ : ∃ r, (v.inner n).radixProd σ = r + 1 := ⟨_, (Nat.succ_pred_eq_of_pos hR).symm⟩
  simp only [hr, List.zipWith_cons_cons, List.zipWith_nil_left, List.sum_cons, List.sum_nil,
    Nat.add_sub_cancel]
  ring

/-- At an owner, the inner digits are in range and their radix product is the one at `σ`, for
every machine, view well formed at `σ` and `L`, and digit count. -/
theorem inner_at {v : View S} {σ : Sizes} {L : S.Launch} {j : S.Gid} (hv : v.WF σ L)
    (hj : v.Owner σ L j) (n : Nat) :
    (v.inner n).InRange (v.bind L j σ) ∧
      (v.inner n).radixProd (v.bind L j σ) = (v.inner n).radixProd σ := by
  refine ⟨fun p hp => hv.range j hj p (List.mem_of_mem_take hp), ?_⟩
  simp only [inner, MixedRadix.radixProd, List.map_take, hv.radices j hj]

/-- **The offsets of an inner owner in the coarse view at a key stride**, for every machine, view
well formed at `σ` and `L`, key stride `d`, level `ℓ`, digit count `n`, binding and instance `i`
of `ℓ` whose owners agree on the outer digits (`hn`): at an owner `j` inside `i` with inner key
value `k` and every coordinate `c` below the layout's size, the offset of `c` at the key stride
`d` is the offset of `i` in `coarsenAt d` at the key stride `R · d` (`R` the inner radix product)
and the coordinate `k · size + c` (`MixedRadix.val_append`, `coarsenAt_call`), and `k · size + c`
is below the coarse size. -/
theorem off_coarsenAt {v : View S} {d : Sizes → Nat} {ℓ : S.Level} {n : Nat}
    {bind' : S.Launch → S.Gid → Sizes → Sizes} {σ : Sizes} {L : S.Launch} {i j : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (hj : v.Inside L ℓ i j) (ho : v.owns L j σ) {c : Nat} (hc : c < (v.lay σ).size) :
    (v.inner n).val (v.bind L j σ) * (v.lay σ).size + c <
        ((v.coarsenAt d ℓ n bind').lay σ).size ∧
      v.offAt d σ L j c = (v.coarsenAt d ℓ n bind').offAt (fun σ => (v.inner n).radixProd σ * d σ)
        σ L i ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) := by
  have hw : v.Owner σ L j := ⟨let ⟨t, ht, hjt, _⟩ := hj; ⟨t, ht, hjt⟩, ho⟩
  obtain ⟨hin, hR⟩ := inner_at hv hw n
  have hk := MixedRadix.lt_prod hin
  rw [hR] at hk
  have hZ : 0 < (v.lay σ).size := prod_pos _ hv.pos
  have hb : (v.inner n).val (v.bind L j σ) * (v.lay σ).size + c <
      ((v.coarsenAt d ℓ n bind').lay σ).size := by
    rw [coarsenAt_size]
    calc (v.inner n).val (v.bind L j σ) * (v.lay σ).size + c
        < ((v.inner n).val (v.bind L j σ) + 1) * (v.lay σ).size := by
          rw [Nat.succ_mul]; exact Nat.add_lt_add_left hc _
      _ ≤ (v.inner n).radixProd σ * (v.lay σ).size := Nat.mul_le_mul_right _ hk
      _ = _ := Nat.mul_comm _ _
  refine ⟨hb, ?_⟩
  have hkey : v.key.val (v.bind L j σ) = (v.inner n).val (v.bind L j σ) +
      (v.inner n).radixProd σ * (v.outer n).val (bind' L i σ) := by
    rw [← hR, ← hn j hj ho]
    have h := MixedRadix.val_append (v.key.digits.take n) (v.key.digits.drop n) (v.bind L j σ)
    rw [List.take_append_drop] at h
    exact h
  have hm : ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) % (v.lay σ).size = c := by
    rw [Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hc]
  have hd : ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) / (v.lay σ).size =
      (v.inner n).val (v.bind L j σ) := by
    rw [Nat.add_comm, Nat.add_mul_div_right _ _ hZ, Nat.div_eq_of_lt hc, Nat.zero_add]
  show v.key.val (v.bind L j σ) * d σ + (v.lay σ).call (leaf c false) =
    (v.outer n).val (bind' L i σ) * ((v.inner n).radixProd σ * d σ) +
      ((v.coarsenAt d ℓ n bind').lay σ).call
        (leaf ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) false)
  rw [coarsenAt_call v d ℓ n bind' hv.congruent hv.pos hb, hm, hd, hkey]
  ring

/-- **The tiles inside an instance lie in its coarse tile, at a key stride.** For every machine,
view, key stride `d`, level `ℓ`, digit count `n`, binding `bind'`, size assignment `σ` and launch
`L` at which the view is well formed, and instance `i` of `ℓ` whose owners agree on the outer
digits with `bind' L i σ` (`hn`): the tile at `d` of every instance of the view's level inside
`i` lies in the tile of `i` in `coarsenAt d` at the key stride `R · d` (`R` the inner radix
product), as the coordinate `c` of an owner `j` inside `i` with inner key value `k` is the coarse
coordinate `k · size + c` (`off_coarsenAt`). No premise on the inner key values: at an instance
whose owners have only some of them, the coarse tile also has the others' bytes. -/
theorem tile_subset_coarsenAt (v : View S) (d : Sizes → Nat) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ)) :
    ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tileAt d σ L j ⊆
      (v.coarsenAt d ℓ n bind').tileAt (fun σ => (v.inner n).radixProd σ * d σ) σ L i := by
  intro x hx
  simp only [Set.mem_iUnion] at hx
  obtain ⟨j, hj, hjo, c, hc, rfl⟩ := hx
  obtain ⟨hb, he⟩ := off_coarsenAt (d := d) hv hn hj hjo hc
  exact ⟨⟨j, hj, hjo⟩, _, hb, by rw [he]; rfl⟩

/-- **The coarse tile at a key stride is the union of the tiles inside it.** For every machine,
view, key stride `d`, level `ℓ`, digit count `n`, binding `bind'`, size assignment `σ` and launch
`L` at which the view is well formed, and instance `i` of `ℓ`: when the owners inside `i` agree
on the outer digits with `bind' L i σ` (`hn`) and every inner key value below the inner radix
product `R` is an owner's inside `i` (`ho`), the tile of `i` in `coarsenAt d` at the key stride
`R · d` is the union of the tiles at `d` of the instances of the view's level inside `i`. A coarse
coordinate `c'` is the coordinate `c' % size` of the owner whose inner key value is `c' / size`
(`ho`, `off_coarsenAt`); the other inclusion is `tile_subset_coarsenAt`. -/
theorem coarsenAt_tile (v : View S) (d : Sizes → Nat) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ ∧ (v.inner n).val (v.bind L j σ) = k) :
    (v.coarsenAt d ℓ n bind').tileAt (fun σ => (v.inner n).radixProd σ * d σ) σ L i =
      ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tileAt d σ L j := by
  have hZ : 0 < (v.lay σ).size := prod_pos _ hv.pos
  refine Set.Subset.antisymm ?_ (tile_subset_coarsenAt v d n bind' hv hn)
  rintro x ⟨-, c', hc', rfl⟩
  have hk : c' / (v.lay σ).size < (v.inner n).radixProd σ := by
    rw [coarsenAt_size] at hc'
    exact Nat.div_lt_of_lt_mul hc'
  obtain ⟨j, hj, hjo, hjk⟩ := ho _ hk
  refine Set.mem_iUnion.2 ⟨j, Set.mem_iUnion.2 ⟨hj, hjo, c' % (v.lay σ).size, Nat.mod_lt _ hZ, ?_⟩⟩
  have he := (off_coarsenAt (d := d) hv hn hj hjo (Nat.mod_lt c' hZ)).2
  rw [hjk, Nat.div_add_mod'] at he
  rw [he]
  rfl

/-- **The coarse view's tile at its cosize is its tile at `R` cosizes**, for every machine, view
well formed at `σ` and `L`, level, digit count, binding and instance `i`, with `R` the inner
radix product: at `R > 0` the coarse cosize is `R` times the cosize (`coarsen_cosize`); at
`R = 0` the coarse layout has size 0 (`coarsen_size`) and both tiles are empty. -/
theorem coarsen_tileAt {v : View S} {ℓ : S.Level} {n : Nat}
    {bind' : S.Launch → S.Gid → Sizes → Sizes} {σ : Sizes} {L : S.Launch} (hv : v.WF σ L)
    (i : S.Gid) :
    (v.coarsen ℓ n bind').tileAt (fun σ => ((v.coarsen ℓ n bind').lay σ).cosize) σ L i =
      (v.coarsen ℓ n bind').tileAt (fun σ => (v.inner n).radixProd σ * (v.lay σ).cosize)
        σ L i := by
  rcases Nat.eq_zero_or_pos ((v.inner n).radixProd σ) with h0 | hR
  · ext x
    simp only [tileAt, Set.mem_ofPred_eq, coarsen_size, h0, Nat.mul_zero, Nat.not_lt_zero,
      false_and, exists_false, and_false]
  · simp only [tileAt, offAt, coarsen_cosize v ℓ n bind' hv.congruent hv.pos hR]

/-- **The tiles inside an instance lie in its coarse tile.** For every machine, view, level `ℓ`,
digit count `n`, binding `bind'`, size assignment `σ` and launch `L` at which the view is well
formed, and instance `i` of `ℓ` whose owners agree on the outer digits with `bind' L i σ`
(`hn`): the tile of every instance of the view's level inside `i` lies in the coarsened view's
tile of `i`. It is `tile_subset_coarsenAt` at the key stride the cosize, whose coarse key stride
`R` cosizes is the coarse cosize (`coarsen_tileAt`). No premise on the inner key values: at an
instance whose owners have only some of them, the coarse tile also has the others' bytes. -/
theorem tile_subset_coarsen (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ)) :
    ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j ⊆ (v.coarsen ℓ n bind').tile σ L i := by
  show _ ⊆ (v.coarsen ℓ n bind').tileAt (fun σ => ((v.coarsen ℓ n bind').lay σ).cosize) σ L i
  rw [coarsen_tileAt hv i]
  exact tile_subset_coarsenAt v (fun σ => (v.lay σ).cosize) n bind' hv hn

/-- **The coarse tile is the union of the tiles inside it.** For every machine, view, level `ℓ`,
digit count `n`, binding `bind'`, size assignment `σ` and launch `L` at which the view is well
formed, and instance `i` of `ℓ`: when the owners inside `i` agree on the outer digits with
`bind' L i σ` (`hn`) and every inner key value below the inner radix product is an owner's inside
`i` (`ho`), the coarsened view's tile of `i` is the union of the tiles of the instances of the
view's level inside `i`. It is `coarsenAt_tile` at the key stride the cosize, whose coarse key
stride `R` cosizes is the coarse cosize (`coarsen_tileAt`). -/
theorem coarsen_tile (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ ∧ (v.inner n).val (v.bind L j σ) = k) :
    (v.coarsen ℓ n bind').tile σ L i = ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j := by
  show (v.coarsen ℓ n bind').tileAt (fun σ => ((v.coarsen ℓ n bind').lay σ).cosize) σ L i = _
  rw [coarsen_tileAt hv i]
  exact coarsenAt_tile v (fun σ => (v.lay σ).cosize) n bind' hv hn ho

end View

end GPUProof
