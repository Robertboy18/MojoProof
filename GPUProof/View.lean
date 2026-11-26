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
* `View.inner v n`, `View.outer v n`, `View.Inside v L ℓ i j`, `View.coarsen v ℓ n bind'`: the
  key's `n` least significant digits and the others, instance `j` of the view's level lying in
  instance `i` of level `ℓ`, and the view at level `ℓ` whose layout has the inner digits as one
  more mode.

It proves, for every machine:

* `View.off_lt`: at a well formed view, every offset of an owner's tile is below
  `radixProd · cosize`;
* `View.key_fits`: at a well formed view and every width `w` at which the key's radix product is
  below `2 ^ (w - 1)`, an owner's key value fits `w` bits (`WordFit`, by `MixedRadix.fits`); the
  offsets are natural numbers, models of a kernel's words, and this is the premise that relates
  the two;
* `View.tiling`: when the machine's placement is injective (`PlaceInj`), the tiles of a view well
  formed at `σ` and `L` tile its bytes (`Tiling`): they lie in `View.bytes` and two instances'
  tiles are disjoint (by `MixedRadix.lt_prod`, `Lay.call_lt_cosize`,
  `MixedRadix.add_mul_eq_iff`, `MixedRadix.eq_iff_digits` and `WF.key_inj`);
* `View.cover`, `View.cover_iff`: the owners' tiles cover the first `B · cosize` bytes of the
  view's buffer when every offset below the cosize is a coordinate's (`hl`) and every key value
  below `B` is an owner's (`hk`), and, at a well formed view on an injective placement and a
  positive `B`, only then;
* `View.coarsen_size`, `View.coarsen_call`, `View.coarsen_cosize`: the coarse layout's size is
  the size times the inner radix product `R`, its offset of `c'` is the offset of `c' % size` plus
  `c' / size` cosizes, and its cosize is `R` cosizes (by `colex_append` and `Lay.call_scalar`);
* `View.tile_subset_coarsen`: at a view well formed at `σ` and `L` and an instance `i` of `ℓ`
  whose owners agree on the outer digits (`hn`), the tiles of the instances inside `i` lie in the
  coarse view's tile of `i` (by `MixedRadix.val_append`);
* `View.coarsen_tile`: when the owners inside `i` also realize every inner key value (`ho`), the
  coarse view's tile of `i` is the union of the tiles of the instances inside it.

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

/-- **The tiles of a well formed view tile its bytes.** For every machine whose placement is
injective (`PlaceInj`), view, size assignment `σ` and launch `L` at which the view is well formed
(`WF`): every tile of an instance of the view's level lies in the view's bytes (`off_lt`), and
the tiles of two instances are disjoint. A byte of two tiles is one offset of the buffer
(`PlaceInj`), `k C + a = k' C + a'` with `a, a' < C` the cosize, so the keys are equal
(`MixedRadix.add_mul_eq_iff`), the digits are equal (`MixedRadix.eq_iff_digits` at the two
bindings), and the instances are one (`WF.key_inj`). -/
theorem tiling (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) : Tiling (v.tiles σ L) (v.bytes σ) := by
  refine ⟨?_, ?_⟩
  · rintro ⟨g, hg⟩ x ⟨ho, c, hc, rfl⟩
    exact ⟨_, off_lt hv ⟨hg, ho⟩ hc, rfl⟩
  · rintro ⟨g, hg⟩ ⟨g', hg'⟩ hne
    refine Set.disjoint_left.2 fun x hx hx' => hne (Subtype.ext ?_)
    obtain ⟨ho, c, hc, rfl⟩ := hx
    obtain ⟨ho', c', hc', he⟩ := hx'
    have he' : v.off σ L g c = v.off σ L g' c' := Int.ofNat_inj.1 (hp he).2
    have ha := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc
    have ha' := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c' false hc'
    have he2 : (v.lay σ).call (leaf c false) + (v.lay σ).cosize * v.key.val (v.bind L g σ) =
        (v.lay σ).call (leaf c' false) + (v.lay σ).cosize * v.key.val (v.bind L g' σ) := by
      simp only [off] at he'
      rw [Nat.mul_comm (v.lay σ).cosize, Nat.mul_comm (v.lay σ).cosize]
      omega
    have hk := ((MixedRadix.add_mul_eq_iff ha ha').1 he2).2
    exact hv.key_inj g g' ⟨hg, ho⟩ ⟨hg', ho'⟩ ((MixedRadix.eq_iff_digits (hv.range g ⟨hg, ho⟩)
      (hv.range g' ⟨hg', ho'⟩) ((hv.radices g ⟨hg, ho⟩).trans
        (hv.radices g' ⟨hg', ho'⟩).symm)).1 hk)

/-- **The owners' tiles cover the bytes of the first `B` key values**, for every machine, view,
size assignment `σ`, launch `L` and bound `B`: when every offset below the layout's cosize is the
offset of a coordinate below its size (`hl`) and every key value below `B` is an owner's (`hk`),
each of the first `B · cosize` bytes of the view's buffer is in an owner's tile. Byte `i` is the
offset of coordinate `c` of the owner whose key value is `i / cosize`, with `c` the coordinate at
offset `i % cosize`. At `B` the radix product the bytes are `bytes`. At a well formed view on an
injective placement and every positive `B` the two premises are needed (`cover_iff`); at `B = 0`
the set is empty, and a layout with holes covers it. -/
theorem cover (v : View S) {σ : Sizes} {L : S.Launch} {B : Nat}
    (hl : ∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a)
    (hk : ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g := by
  rintro x ⟨i, hi, rfl⟩
  have hC : 0 < (v.lay σ).cosize := Nat.succ_pos _
  obtain ⟨g, hg, hgk⟩ := hk (i / (v.lay σ).cosize) ((Nat.div_lt_iff_lt_mul hC).2 hi)
  obtain ⟨c, hc, hca⟩ := hl (i % (v.lay σ).cosize) (Nat.mod_lt _ hC)
  refine Set.mem_iUnion.2 ⟨⟨g, hg.1⟩, hg.2, c, hc, ?_⟩
  show S.place v.buf i = S.place v.buf ↑(v.off σ L g c)
  rw [off, hgk, hca, Nat.div_add_mod']

/-- **`cover`'s premises are the least at every positive bound**, for every machine whose
placement is injective (`PlaceInj`), view, size assignment `σ` and launch `L` at which the view is
well formed, and positive bound `B` (`hB`): the owners' tiles cover the first `B · cosize` bytes
of the view's buffer exactly when every offset below the cosize is a coordinate's and every key
value below `B` is an owner's. Byte `k · cosize + a`, with `a` below the cosize, in the tile of
owner `g` at coordinate `c` is `g`'s key value times the cosize plus the offset of `c`, which is
below the cosize (`Lay.call_lt_cosize`), so the key value is `k` and the offset `a`
(`MixedRadix.add_mul_eq_iff`). At `B = 0` the covered set is empty, and a layout with holes
covers it, so `hl` is not among the least premises there. -/
theorem cover_iff (v : View S) (hp : PlaceInj S.place) {σ : Sizes} {L : S.Launch}
    (hv : v.WF σ L) {B : Nat} (hB : 0 < B) :
    {x | ∃ i : Nat, i < B * (v.lay σ).cosize ∧ x = S.place v.buf i} ⊆ ⋃ g, v.tiles σ L g ↔
      (∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a) ∧
        ∀ k < B, ∃ g, v.Owner σ L g ∧ v.key.val (v.bind L g σ) = k := by
  refine ⟨fun h => ?_, fun ⟨hl, hk⟩ => cover v hl hk⟩
  have hd : ∀ k < B, ∀ a < (v.lay σ).cosize, ∃ g, v.Owner σ L g ∧ ∃ c < (v.lay σ).size,
      v.key.val (v.bind L g σ) = k ∧ (v.lay σ).call (leaf c false) = a := by
    intro k hk a ha
    have hi : k * (v.lay σ).cosize + a < B * (v.lay σ).cosize :=
      calc k * (v.lay σ).cosize + a < (k + 1) * (v.lay σ).cosize := by
            rw [Nat.succ_mul]; exact Nat.add_lt_add_left ha _
        _ ≤ B * (v.lay σ).cosize := Nat.mul_le_mul_right _ hk
    obtain ⟨⟨g, hg⟩, ho, c, hc, he⟩ := Set.mem_iUnion.1 (h ⟨_, hi, rfl⟩)
    have he' : k * (v.lay σ).cosize + a = v.off σ L g c := Int.ofNat_inj.1 (hp he).2
    have hca := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc
    have he2 : a + (v.lay σ).cosize * k =
        (v.lay σ).call (leaf c false) + (v.lay σ).cosize * v.key.val (v.bind L g σ) := by
      simp only [off] at he'
      rw [Nat.mul_comm (v.lay σ).cosize, Nat.mul_comm (v.lay σ).cosize]
      omega
    obtain ⟨e1, e2⟩ := (MixedRadix.add_mul_eq_iff ha hca).1 he2
    exact ⟨g, ⟨hg, ho⟩, c, hc, e2.symm, e1.symm⟩
  refine ⟨fun a ha => ?_, fun k hk => ?_⟩
  · obtain ⟨-, -, c, hc, -, e⟩ := hd 0 hB a ha
    exact ⟨c, hc, e⟩
  · obtain ⟨g, hg, -, -, e, -⟩ := hd k hk 0 (Nat.succ_pos _)
    exact ⟨g, hg, e⟩

/-! ## Coarsening -/

/-- The key's `n` least significant digits, for every machine. -/
def inner (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.take n⟩

/-- The key's digits after the `n` least significant ones, for every machine. -/
def outer (v : View S) (n : Nat) : MixedRadix := ⟨v.key.digits.drop n⟩

/-- Instance `j` of the view's level lies in instance `i` of level `ℓ` in launch `L`, for every
machine: a thread of `L` is in both. -/
def Inside (v : View S) (L : S.Launch) (ℓ : S.Level) (i j : S.Gid) : Prop :=
  ∃ t ∈ S.threads L, S.group L v.level t = j ∧ S.group L ℓ t = i

/-- **The view at level `ℓ`**, for every machine: the key's `n` least significant digits become
one more layout mode, of extent their radix product and stride the cosize; the key is the other
digits, `bind'` binds them at an instance of `ℓ`, and an instance of `ℓ` owns a tile when an owner
of the view lies in it. -/
def coarsen (v : View S) (ℓ : S.Level) (n : Nat) (bind' : S.Launch → S.Gid → Sizes → Sizes) :
    View S where
  lay σ := ⟨(v.lay σ).shape ++ [leaf ((v.inner n).radixProd σ) false],
    (v.lay σ).stride ++ [leaf (v.lay σ).cosize false]⟩
  level := ℓ
  buf := v.buf
  key := v.outer n
  bind := bind'
  owns L i σ := ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ

/-- **The coarse layout's size**, for every machine, view, level, digit count, binding and size
assignment: the layout's size times the inner radix product. -/
theorem coarsen_size (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) (σ : Sizes) :
    ((v.coarsen ℓ n bind').lay σ).size = (v.lay σ).size * (v.inner n).radixProd σ := by
  simp only [coarsen, Lay.size, Tup.size, Tup.leaves, Tup.leavesL_append, leavesL,
    List.prod_append, List.append_nil, List.prod_cons, List.prod_nil, Nat.mul_one]

/-- The coarse layout's shape and stride are congruent, for every machine, view, level, digit
count, binding and size assignment at which the layout's are. -/
theorem coarsen_congruent (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true) :
    congruentL ((v.coarsen ℓ n bind').lay σ).shape ((v.coarsen ℓ n bind').lay σ).stride = true :=
  Tup.congruentL_append _ _ _ _ h rfl

/-- **The coarse layout's offsets**, for every machine, view, level, digit count, binding and
size assignment at which the layout is congruent with positive extents: the coarse offset of
`c'` below the coarse size is the layout's offset of `c' % size` plus `c' / size` cosizes (the
colexicographic digits split at the last mode, `colex_append`). -/
theorem coarsen_call (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true)
    (hpos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s) {c : Nat}
    (hc : c < ((v.coarsen ℓ n bind').lay σ).size) :
    ((v.coarsen ℓ n bind').lay σ).call (leaf c false) =
      (v.lay σ).call (leaf (c % (v.lay σ).size) false) + c / (v.lay σ).size * (v.lay σ).cosize := by
  have hZ : 0 < (v.lay σ).size := prod_pos _ hpos
  have hZ' : (v.lay σ).size = (leavesL (v.lay σ).shape).prod := by
    simp only [Lay.size, Tup.size, Tup.leaves]
  have hR : c / (v.lay σ).size < (v.inner n).radixProd σ := by
    rw [coarsen_size] at hc
    exact Nat.div_lt_of_lt_mul hc
  rw [Lay.call_scalar _ (coarsen_congruent v ℓ n bind' h) c false hc,
    Lay.call_scalar _ h _ false (Nat.mod_lt _ hZ)]
  simp only [coarsen, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil]
  rw [hZ'] at hR
  rw [colex_append, sum_zipWith_append _ _ _ _ (by
      rw [colex_length]; exact congruentL_leaves_length _ _ h), hZ', colex_mod]
  simp [colex, Nat.mod_eq_of_lt hR]

/-- **The coarse layout's cosize**, for every machine, view, level, digit count, binding and
size assignment at which the layout is congruent with positive extents and the inner radix
product `R` is positive: `R` times the layout's cosize (`Lay.cosize_eq` at both). -/
theorem coarsen_cosize (v : View S) (ℓ : S.Level) (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes}
    (h : congruentL (v.lay σ).shape (v.lay σ).stride = true)
    (hpos : ∀ s ∈ leavesL (v.lay σ).shape, 0 < s) (hR : 0 < (v.inner n).radixProd σ) :
    ((v.coarsen ℓ n bind').lay σ).cosize = (v.inner n).radixProd σ * (v.lay σ).cosize := by
  have hpos' : ∀ s ∈ leavesL ((v.coarsen ℓ n bind').lay σ).shape, 0 < s := by
    simp only [coarsen, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil,
      List.mem_append, List.mem_singleton]
    rintro s (hs | rfl)
    · exact hpos s hs
    · exact hR
  rw [Lay.cosize_eq _ (coarsen_congruent v ℓ n bind' h) hpos', Lay.cosize_eq _ h hpos]
  simp only [coarsen, Tup.leavesL_append, leavesL, Tup.leaves, List.append_nil]
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

/-- **The offsets of an inner owner in the coarse view**, for every machine, view well formed at
`σ` and `L`, level `ℓ`, digit count `n`, binding and instance `i` of `ℓ` whose owners agree on the
outer digits (`hn`): at an owner `j` inside `i` with inner key value `k` and every coordinate `c`
below the layout's size, the offset of `c` is the coarse offset of `i` at `k · size + c`
(`MixedRadix.val_append`, `coarsen_call`, `coarsen_cosize`), and `k · size + c` is below the
coarse size. -/
theorem off_coarsen {v : View S} {ℓ : S.Level} {n : Nat}
    {bind' : S.Launch → S.Gid → Sizes → Sizes} {σ : Sizes} {L : S.Launch} {i j : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (hj : v.Inside L ℓ i j) (ho : v.owns L j σ) {c : Nat} (hc : c < (v.lay σ).size) :
    (v.inner n).val (v.bind L j σ) * (v.lay σ).size + c < ((v.coarsen ℓ n bind').lay σ).size ∧
      v.off σ L j c =
        (v.coarsen ℓ n bind').off σ L i ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) := by
  have hw : v.Owner σ L j := ⟨let ⟨t, ht, hjt, _⟩ := hj; ⟨t, ht, hjt⟩, ho⟩
  obtain ⟨hin, hR⟩ := inner_at hv hw n
  have hk := MixedRadix.lt_prod hin
  rw [hR] at hk
  have hZ : 0 < (v.lay σ).size := prod_pos _ hv.pos
  have hb : (v.inner n).val (v.bind L j σ) * (v.lay σ).size + c <
      ((v.coarsen ℓ n bind').lay σ).size := by
    rw [coarsen_size]
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
  have hR0 : 0 < (v.inner n).radixProd σ := Nat.lt_of_le_of_lt (Nat.zero_le _) hk
  show v.key.val (v.bind L j σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false) =
    (v.outer n).val (bind' L i σ) * ((v.coarsen ℓ n bind').lay σ).cosize +
      ((v.coarsen ℓ n bind').lay σ).call
        (leaf ((v.inner n).val (v.bind L j σ) * (v.lay σ).size + c) false)
  rw [coarsen_call v ℓ n bind' hv.congruent hv.pos hb, hm, hd,
    coarsen_cosize v ℓ n bind' hv.congruent hv.pos hR0, hkey]
  ring

/-- **The tiles inside an instance lie in its coarse tile.** For every machine, view, level `ℓ`,
digit count `n`, binding `bind'`, size assignment `σ` and launch `L` at which the view is well
formed, and instance `i` of `ℓ` whose owners agree on the outer digits with `bind' L i σ`
(`hn`): the tile of every instance of the view's level inside `i` lies in the coarsened view's
tile of `i`, as the coordinate `c` of an owner `j` inside `i` with inner key value `k` is the
coarse coordinate `k · size + c` (`off_coarsen`). No premise on the inner key values: at an
instance whose owners have only some of them, the coarse tile also has the others' bytes. -/
theorem tile_subset_coarsen (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ)) :
    ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j ⊆ (v.coarsen ℓ n bind').tile σ L i := by
  intro x hx
  simp only [Set.mem_iUnion] at hx
  obtain ⟨j, hj, hjo, c, hc, rfl⟩ := hx
  obtain ⟨hb, he⟩ := off_coarsen hv hn hj hjo hc
  exact ⟨⟨j, hj, hjo⟩, _, hb, by rw [he]; rfl⟩

/-- **The coarse tile is the union of the tiles inside it.** For every machine, view, level `ℓ`,
digit count `n`, binding `bind'`, size assignment `σ` and launch `L` at which the view is well
formed, and instance `i` of `ℓ`: when the owners inside `i` agree on the outer digits with
`bind' L i σ` (`hn`) and every inner key value below the inner radix product is an owner's inside
`i` (`ho`), the coarsened view's tile of `i` is the union of the tiles of the instances of the
view's level inside `i`. A coarse coordinate `c'` is the coordinate `c' % size` of the owner whose
inner key value is `c' / size` (`ho`, `off_coarsen`); the other inclusion is
`tile_subset_coarsen`. -/
theorem coarsen_tile (v : View S) {ℓ : S.Level} (n : Nat)
    (bind' : S.Launch → S.Gid → Sizes → Sizes) {σ : Sizes} {L : S.Launch} {i : S.Gid}
    (hv : v.WF σ L)
    (hn : ∀ j, v.Inside L ℓ i j → v.owns L j σ →
      (v.outer n).val (v.bind L j σ) = (v.outer n).val (bind' L i σ))
    (ho : ∀ k < (v.inner n).radixProd σ,
      ∃ j, v.Inside L ℓ i j ∧ v.owns L j σ ∧ (v.inner n).val (v.bind L j σ) = k) :
    (v.coarsen ℓ n bind').tile σ L i = ⋃ j ∈ {j | v.Inside L ℓ i j}, v.tile σ L j := by
  have hZ : 0 < (v.lay σ).size := prod_pos _ hv.pos
  refine Set.Subset.antisymm ?_ (tile_subset_coarsen v n bind' hv hn)
  rintro x ⟨-, c', hc', rfl⟩
  have hk : c' / (v.lay σ).size < (v.inner n).radixProd σ := by
    rw [coarsen_size] at hc'
    exact Nat.div_lt_of_lt_mul hc'
  obtain ⟨j, hj, hjo, hjk⟩ := ho _ hk
  refine Set.mem_iUnion.2 ⟨j, Set.mem_iUnion.2 ⟨hj, hjo, c' % (v.lay σ).size, Nat.mod_lt _ hZ, ?_⟩⟩
  have he := (off_coarsen hv hn hj hjo (Nat.mod_lt c' hZ)).2
  rw [hjk, Nat.div_add_mod'] at he
  rw [he]
  rfl

end View

end GPUProof
