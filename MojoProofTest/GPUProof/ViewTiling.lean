import MojoProof.Sem.Trace
import MojoProofTest.GPUProof.View

/-!
# Views at MojoProof's `sig` as tilings of byte intervals

`MojoProof.Sem.Tiling` (MojoProof/Sem/Trace.lean:146) is the tiling that the ownership discipline
`Owned` takes: intervals of bytes, each with its first byte and length, inside an extent and
pairwise disjoint. A view of GPUProof/View.lean at MojoProof's machine `sig`, well formed at an
assignment and launch, gives one over its owners and an empty interval, with an index for every
thread, and when its layout is onto its cosize each owner's tile is its interval. The views are
MojoProofTest/GPUProof/View.lean's.

* `owner_end_le` and `toTiling`: at MojoProof's `sig`, for every view, assignment and launch at
  which the view is well formed, an interval for each owner and an empty one: owner `g`'s
  (`some g`) starting at its key value times the cosize and of the cosize's length, inside
  `radixProd · cosize` bytes (`owner_end_le`), and `none`'s of no byte at the extent.
* `own`: for every view, assignment and launch, thread `t`'s index in `toTiling`, its instance
  of the view's level when that instance owns a tile (`own_some`) and `none` otherwise, with
  `own_none`: a thread whose instance owns no tile has the empty interval, and the `example` of
  gemv's thread 400 at grid (4,1,1), block (128,1,1) and `m = 8` (row 12); `owned_len`: under
  `Owned` at `toTiling` and `own`, such a thread's accesses to the view's buffer have length 0.
* `tile_toTiling`: at MojoProof's `sig`, for every such view whose layout is onto its cosize, an
  owner's tile is the bytes of the view's buffer at the offsets of its interval. Its mutant
  (`hole_toTiling`): a view whose layout has a hole below its cosize (`holeLay`, offsets 0 and
  2 of cosize 3), well formed at the launch of one thread, where byte 1 is in the owner's
  interval and not in its tile.
* `gemv_toTiling`: gemv's view at every admissible assignment and launch: the warp of an owner
  thread has the 4 bytes from `4 · row`, inside 4 times the warp count, with the `example` of
  thread 200 at grid (4,1,1), block (128,1,1) and `m = 16` (bytes 24 to 27 of 64).
* `naive_toTiling`: the naive matmul's view at every row stride `N` and admissible assignment and
  launch: the owner thread at `(row, col)` has the 4 bytes from `4 · (row · N + col)`, inside the
  `m · N` floats of `c`, with the `example` of the corpus kernel's thread 3 at one block of 2 × 2
  threads, `m = 2` and `n = 50257` (from byte `4 · 50258`).

The intervals are natural-number models of the bytes the kernels store: the kernels' words give
them under the word premise (`m < 2 ^ 31` for gemv, `m · N < 2 ^ 31` for the naive matmul;
MojoProofTest/GPUProof/ViewWords.lean), and that a run stores there is not proved here.

The index type is the owners with `none` added, so that the map from threads to indices that
`Owned` also takes (`own`) is total on threads: a thread whose instance owns no tile has the
empty interval, inside which `Owned`'s `tile` clause admits no access of a positive length.
-/

namespace MojoProofTest.GPUProof.ViewTiling

open _root_.GPUProof _root_.GPUProof.Layout _root_.GPUProof.Layout.Tup MojoProof.Sem
open MojoProofTest.GPUProof.MixedRadix (warpIdx entryIdx asg)
open MojoProofTest.GPUProof.View

/-- **An owner's interval ends by the extent.** At MojoProof's `sig`, for every view, size
assignment `σ` and launch `L` at which the view is well formed, and every owner `g`: `g`'s key
value plus one, times the layout's cosize, is at most `radixProd · cosize`, the key value being
below the radix product (`MixedRadix.lt_prod` at `WF.range` and `WF.radices`). -/
theorem owner_end_le (v : View sig) {σ : Sizes} {L : Launch} (hv : v.WF σ L)
    (g : {g // v.Owner σ L g}) :
    v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize + (v.lay σ).cosize ≤
      v.key.radixProd σ * (v.lay σ).cosize := by
  have hk : v.key.val (v.bind L g.1 σ) < v.key.radixProd σ := by
    have h := MixedRadix.lt_prod (hv.range g.1 g.2)
    rwa [MixedRadix.radixProd, hv.radices g.1 g.2] at h
  rw [← Nat.succ_mul]
  exact Nat.mul_le_mul_right _ hk

/-- **A view's tiles as byte intervals, one for each owner and an empty one.** At MojoProof's
`sig`, for every view, size assignment `σ` and launch `L` at which the view is well formed: the
`Tiling` of MojoProof/Sem/Trace.lean over the owners with `none` added, owner `g`'s interval
(`some g`) starting at its key value times the layout's cosize, of the cosize's length, and
`none`'s of length 0 at the extent `radixProd · cosize`. The owners' bounds are `owner_end_le`,
two owners' key values differ (`MixedRadix.eq_iff_digits`, `WF.key_inj`), so their intervals do
not overlap, and the empty interval starts where every owner's ends or later. -/
def toTiling (v : View sig) {σ : Sizes} {L : Launch} (hv : v.WF σ L) :
    MojoProof.Sem.Tiling (Option {g // v.Owner σ L g}) where
  off
    | some g => v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize
    | none => v.key.radixProd σ * (v.lay σ).cosize
  len
    | some _ => (v.lay σ).cosize
    | none => 0
  ext := v.key.radixProd σ * (v.lay σ).cosize
  inb i := by
    cases i with
    | some g => exact owner_end_le v hv g
    | none => exact Nat.le_refl _
  disj i j hne := by
    cases i with
    | none =>
      cases j with
      | none => exact absurd rfl hne
      | some g' => exact .inr (owner_end_le v hv g')
    | some g =>
      cases j with
      | none => exact .inl (owner_end_le v hv g)
      | some g' =>
        show v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize + (v.lay σ).cosize ≤
            v.key.val (v.bind L g'.1 σ) * (v.lay σ).cosize ∨
          v.key.val (v.bind L g'.1 σ) * (v.lay σ).cosize + (v.lay σ).cosize ≤
            v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize
        have hk : v.key.val (v.bind L g.1 σ) ≠ v.key.val (v.bind L g'.1 σ) := fun h =>
          hne (congrArg some (Subtype.ext (hv.key_inj g.1 g'.1 g.2 g'.2
            ((MixedRadix.eq_iff_digits (hv.range g.1 g.2) (hv.range g'.1 g'.2)
              ((hv.radices g.1 g.2).trans (hv.radices g'.1 g'.2).symm)).1 h))))
        rcases Nat.lt_or_gt_of_ne hk with h | h
        · left
          rw [← Nat.succ_mul]
          exact Nat.mul_le_mul_right _ h
        · right
          rw [← Nat.succ_mul]
          exact Nat.mul_le_mul_right _ h

/-- **Each thread's index in `toTiling`.** At MojoProof's `sig`, for every view, size assignment
`σ`, launch `L` and thread `t`: `some` of `t`'s instance of the view's level when that instance
owns a tile, and `none` (the empty interval) otherwise. With `toTiling` it is the pair of a tiling
and a map from threads to its indices that `Owned` (MojoProof/Sem/Trace.lean:181) takes. -/
noncomputable def own (v : View sig) (σ : Sizes) (L : Launch) (t : Nat) :
    Option {g // v.Owner σ L g} :=
  open Classical in
  if h : v.Owner σ L (sig.group L v.level t) then some ⟨_, h⟩ else none

/-- **A thread whose instance owns a tile has its owner's interval.** At MojoProof's `sig`, for
every view, size assignment `σ`, launch `L` and thread `t` whose instance of the view's level
owns a tile: `t`'s index in `toTiling` is `some` of that instance. -/
theorem own_some (v : View sig) {σ : Sizes} {L : Launch} {t : Nat}
    (h : v.Owner σ L (sig.group L v.level t)) : own v σ L t = some ⟨_, h⟩ :=
  dite_eq_left h

/-- **A thread whose instance owns no tile has the empty interval.** At MojoProof's `sig`, for
every view, size assignment `σ` and launch `L` at which the view is well formed, and every
thread `t` whose instance of the view's level owns no tile: `t`'s index is `none`, and its
interval in `toTiling` has length 0. -/
theorem own_none (v : View sig) {σ : Sizes} {L : Launch} (hv : v.WF σ L) {t : Nat}
    (h : ¬ v.Owner σ L (sig.group L v.level t)) :
    own v σ L t = none ∧ (toTiling v hv).len (own v σ L t) = 0 := by
  have he : own v σ L t = none := dite_eq_right h
  exact ⟨he, by rw [he]; rfl⟩

/-- **A non-owner's accesses to the view's buffer are empty.** At MojoProof's `sig`, for every
view, size assignment `σ` and launch `L` at which the view is well formed, every map `T` from
blocks to tilings that gives the view's buffer `toTiling`, and every access `a` to that buffer
that follows the discipline `Owned T (own v σ L)` (MojoProof/Sem/Trace.lean:181), by a thread
whose instance of the view's level owns no tile: `a` has length 0, so it overlaps no access
(`Access.overlaps` asks for positive lengths). -/
theorem owned_len (v : View sig) {σ : Sizes} {L : Launch} (hv : v.WF σ L)
    {T : Nat → Option (MojoProof.Sem.Tiling (Option {g // v.Owner σ L g}))} {a : Access}
    (hT : T v.buf = some (toTiling v hv)) (hb : a.ptr.block = v.buf)
    (ho : Owned T (own v σ L) a) (h : ¬ v.Owner σ L (sig.group L v.level a.who.thread)) :
    a.len = 0 := by
  have ht := ho.tile (toTiling v hv) (by rw [hb]; exact hT)
  rw [(own_none v hv h).1] at ht
  have h0 : (toTiling v hv).len none = 0 := rfl
  rw [h0] at ht
  omega

/-- **An owner's tile is its interval.** At MojoProof's `sig`, for every view, size assignment
`σ` and launch `L` at which the view is well formed and whose layout at `σ` is onto its cosize
(`hl`, as `View.cover` takes it), and every owner `g`: the bytes of `g`'s tile are the bytes of
the view's buffer at the offsets of `g`'s interval in `toTiling` (index `some g`). A tile's
offset is the key value times the cosize plus a layout offset below the cosize
(`Lay.call_lt_cosize`), and `hl` gives every such layout offset; without `hl` an interval may
have a byte outside the tile (`hole_toTiling`). -/
theorem tile_toTiling (v : View sig) {σ : Sizes} {L : Launch} (hv : v.WF σ L)
    (hl : ∀ a < (v.lay σ).cosize, ∃ c < (v.lay σ).size, (v.lay σ).call (leaf c false) = a)
    (g : {g // v.Owner σ L g}) (x : Nat × Int) :
    x ∈ v.tile σ L g.1 ↔ x.1 = v.buf ∧ ((toTiling v hv).off (some g) : Int) ≤ x.2 ∧
      x.2 < (toTiling v hv).off (some g) + (toTiling v hv).len (some g) := by
  show _ ↔ x.1 = v.buf ∧ ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize : Nat) : Int) ≤ x.2 ∧
      x.2 < ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize : Nat) : Int) + ((v.lay σ).cosize : Nat)
  constructor
  · rintro ⟨-, c, hc, rfl⟩
    have ha := Lay.call_lt_cosize (v.lay σ) hv.congruent hv.pos c false hc
    refine ⟨rfl, ?_⟩
    show ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize : Nat) : Int) ≤
        ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false) : Nat) :
          Int) ∧
      ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize + (v.lay σ).call (leaf c false) : Nat) :
          Int) <
        ((v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize : Nat) : Int) + ((v.lay σ).cosize : Nat)
    generalize v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize = K
    omega
  · obtain ⟨b, i⟩ := x
    rintro ⟨h1, h2, h3⟩
    simp only at h1 h2 h3
    subst h1
    obtain ⟨n, rfl⟩ := Int.eq_ofNat_of_zero_le (Int.le_trans (Int.natCast_nonneg _) h2)
    have hK : v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize ≤ n := by omega
    have hC : n < v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize + (v.lay σ).cosize := by omega
    obtain ⟨c, hc, hca⟩ := hl (n - v.key.val (v.bind L g.1 σ) * (v.lay σ).cosize) (by omega)
    refine ⟨g.2.2, c, hc, ?_⟩
    show ((v.buf, (n : Int)) : Nat × Int) = (v.buf, ((v.off σ L g.1 c : Nat) : Int))
    rw [View.off, hca, Nat.add_sub_cancel' hK]

/-- The layout of one mode of extent 2 and stride 2: offsets 0 and 2, size 2 and cosize 3, so
offset 1, below the cosize, is no coordinate's. -/
def holeLay : Lay := Lay.flat [(2, 2)]

/-- A thread view (level 0) in buffer `b` with the layout `holeLay`, the key with no digit, the
binding that changes no variable, and every thread owning a tile. -/
def holeView (b : Nat) : View sig where
  lay _ := holeLay
  level := (0 : Fin 4)
  buf := b
  key := ⟨[]⟩
  bind _ _ σ := σ
  owns _ _ _ := True

/-- `holeView` is well formed at MojoProof's `sig`, at the assignment `0` and the launch of one
thread, in every buffer: the layout has one nesting and a positive extent, the key has no digit,
and the launch has one instance of level 0. -/
theorem hole_wf (b : Nat) : (holeView b).WF (fun _ => 0) Launch.one where
  congruent := rfl
  pos s hs := by
    simp [holeView, holeLay, Lay.flat, leavesL, leaves] at hs
    omega
  range _ _ := by intro p hp; simp [holeView] at hp
  radices _ _ := rfl
  key_inj g g' hg hg' _ := by
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
    change t < 1 at ht
    change t' < 1 at ht'
    obtain rfl : t = 0 := by omega
    obtain rfl : t' = 0 := by omega
    rfl

/-- **Mutant: a layout with a hole.** At MojoProof's `sig`, at grid (1,1,1) and block (1,1,1),
the assignment `0` and every buffer `b`: `tile_toTiling`'s premise `hl` fails at `holeLay`
(offset 1 is below the cosize 3 and no coordinate's), and the owner thread 0 has byte 1 of `b`
inside its interval in `toTiling`, bytes 0 to 2, and not in its tile, bytes 0 and 2, so
`tile_toTiling`'s equation fails without `hl`. -/
theorem hole_toTiling (b : Nat) :
    ¬ (∀ a < holeLay.cosize, ∃ c < holeLay.size, holeLay.call (leaf c false) = a) ∧
      ∃ g : {g // (holeView b).Owner (fun _ => 0) Launch.one g},
        (b, (1 : Int)) ∉ (holeView b).tile (fun _ => 0) Launch.one g.1 ∧
        ((toTiling (holeView b) (hole_wf b)).off (some g) : Int) ≤ 1 ∧
        (1 : Int) < (toTiling (holeView b) (hole_wf b)).off (some g) +
          (toTiling (holeView b) (hole_wf b)).len (some g) := by
  have e0 : holeLay.call (leaf 0 false) = 0 := by decide
  have e1 : holeLay.call (leaf 1 false) = 2 := by decide
  have ec : holeLay.cosize = 3 := by decide
  refine ⟨by decide, ⟨(0, 0), inst_sig.2 ⟨0, by decide, rfl⟩, trivial⟩, ?_, ?_, ?_⟩
  · rintro ⟨-, c, hc, he⟩
    have h' : (1 : Int) = ((0 * holeLay.cosize + holeLay.call (leaf c false) : Nat) : Int) :=
      (place_inj he).2
    have hc' : c < 2 := hc
    obtain _ | _ | c := c
    · rw [e0] at h'; omega
    · rw [e1] at h'; omega
    · omega
  · show (((0 : Nat) * holeLay.cosize : Nat) : Int) ≤ 1
    omega
  · show (1 : Int) < ((0 * holeLay.cosize : Nat) : Int) + ((holeLay.cosize : Nat) : Int)
    rw [ec]
    omega

/-- **gemv's intervals.** At MojoProof's `sig`, at every admissible assignment and launch, and
every thread `t` whose warp owns a tile: the warp's interval in `toTiling` is the 4 bytes from
`4 · row`, with `row = (ctaid.x · ntid.x + tid.x) / 32` (`gemv_row`), and the extent is 4 times
the warp count: a natural-number model of the float the kernel stores, its bytes under the word
premise `m < 2 ^ 31` (MojoProofTest/GPUProof/ViewWords.lean's `gemv_words`). -/
theorem gemv_toTiling (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) (ho : (gemvView y).Owner σ L (sig.group L 1 t)) :
    (toTiling (gemvView y) (gemv_wf y σ L ha)).off (some ⟨_, ho⟩) = 4 * (L.index t .x / 32) ∧
      (toTiling (gemvView y) (gemv_wf y σ L ha)).len (some ⟨_, ho⟩) = 4 ∧
        (toTiling (gemvView y) (gemv_wf y σ L ha)).ext = 4 * (L.block .x / 32 * L.grid .x) := by
  refine ⟨?_, elem_cosize (by decide), ?_⟩
  · show (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) * (elem 4).cosize = _
    rw [gemv_row ha ht, elem_cosize (by decide), Nat.mul_comm]
  · show (warpIdx 0 1).radixProd σ * (elem 4).cosize = _
    have hR : (warpIdx 0 1).radixProd σ = σ 4 / σ 5 * σ 6 := by
      simp [warpIdx, MixedRadix.radixProd, SizeExpr.eval]
    obtain ⟨-, -, h4, h5, h6, -⟩ := ha
    rw [hR, h4, h5, h6, elem_cosize (by decide), Nat.mul_comm]

/-- At grid (4,1,1) and block (128,1,1) with `m = 16`, the warp of thread 200 (row 6) owns a tile,
and its interval is bytes 24 to 27 of 64 bytes. -/
example (y : Nat) : ∃ ho : (gemvView y).Owner (asg [0, 0, 0, 0, 128, 32, 4, 16])
    (launch2 4 1 128 1) (sig.group (launch2 4 1 128 1) 1 200),
    (toTiling (gemvView y) (gemv_wf y (asg [0, 0, 0, 0, 128, 32, 4, 16]) (launch2 4 1 128 1)
        ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩)).off (some ⟨_, ho⟩) = 24 ∧
      (toTiling (gemvView y) (gemv_wf y (asg [0, 0, 0, 0, 128, 32, 4, 16]) (launch2 4 1 128 1)
        ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩)).ext = 64 := by
  have hmem : ∀ {L : Launch} {t : Nat}, t < volume L.grid * volume L.block →
      t ∈ sig.threads L := fun h => List.mem_range.2 h
  have ha : gemvAdm (asg [0, 0, 0, 0, 128, 32, 4, 16]) (launch2 4 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩
  have ho : (gemvView y).Owner (asg [0, 0, 0, 0, 128, 32, 4, 16]) (launch2 4 1 128 1)
      (sig.group (launch2 4 1 128 1) 1 200) :=
    ⟨⟨200, hmem (by decide), rfl⟩, (by decide : (warpIdx 0 1).val (gemvBind (launch2 4 1 128 1)
      (sig.group (launch2 4 1 128 1) 1 200) (asg [0, 0, 0, 0, 128, 32, 4, 16])) < 16)⟩
  obtain ⟨h1, -, h3⟩ := gemv_toTiling y ha (by decide) ho
  exact ⟨ho, by rw [h1]; decide, by rw [h3]; decide⟩

/-- At grid (4,1,1) and block (128,1,1) with `m = 8`, fewer rows than the 16 warps, the warp of
thread 400 (row 12) owns no tile, so thread 400's index is `none`, whose interval has no byte. -/
example (y : Nat) :
    own (gemvView y) (asg [0, 0, 0, 0, 128, 32, 4, 8]) (launch2 4 1 128 1) 400 = none ∧
      (toTiling (gemvView y) (gemv_wf y (asg [0, 0, 0, 0, 128, 32, 4, 8]) (launch2 4 1 128 1)
        ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩)).len
        (own (gemvView y) (asg [0, 0, 0, 0, 128, 32, 4, 8]) (launch2 4 1 128 1) 400) = 0 :=
  own_none (gemvView y) _ fun h => absurd h.2
    (by decide : ¬ (warpIdx 0 1).val (gemvBind (launch2 4 1 128 1)
      (sig.group (launch2 4 1 128 1) 1 400) (asg [0, 0, 0, 0, 128, 32, 4, 8])) < 8)

/-- **The naive matmul's intervals.** At MojoProof's `sig`, for every row stride `N`, at every
admissible assignment and launch, and every thread `t` that owns a tile: its interval in
`toTiling` is the 4 bytes from `4 · (row · N + col)`, and the extent is the `m · N` floats of
`c`: a natural-number model of the float the kernel of row stride `N` stores, its bytes under the
word premise `m · N < 2 ^ 31` (MojoProofTest/GPUProof/ViewWords.lean's `naive_words`). -/
theorem naive_toTiling (c N : Nat) {σ : Sizes} {L : Launch} (ha : naiveAdm N σ L) {t : Nat}
    (ho : (naiveView c).Owner σ L (sig.group L 0 t)) :
    (toTiling (naiveView c) (naive_wf c N σ L ha)).off (some ⟨_, ho⟩) =
        4 * (L.index t .x * N + L.index t .y) ∧
      (toTiling (naiveView c) (naive_wf c N σ L ha)).len (some ⟨_, ho⟩) = 4 ∧
        (toTiling (naiveView c) (naive_wf c N σ L ha)).ext = 4 * (σ 4 * N) := by
  refine ⟨?_, elem_cosize (by decide), ?_⟩
  · show (entryIdx 0 1).val (naiveBind L (sig.group L 0 t) σ) * (elem 4).cosize = _
    rw [naive_val, elem_cosize (by decide), ha.1, Nat.mul_comm]
    rfl
  · show (entryIdx 0 1).radixProd σ * (elem 4).cosize = _
    have hR : (entryIdx 0 1).radixProd σ = σ 5 * σ 4 := by
      simp [entryIdx, MixedRadix.radixProd, SizeExpr.eval]
    rw [hR, ha.1, elem_cosize (by decide), Nat.mul_comm, Nat.mul_comm N]

/-- The corpus kernel's: at one block of 2 × 2 threads with `m = 2` and `n = 50257`, thread 3
(row 1, column 1) owns a tile, and its interval starts at byte `4 · 50258`. -/
example (c : Nat) : ∃ ho : (naiveView c).Owner (asg [0, 0, 0, 0, 2, 50257]) (launch2 1 1 2 2)
    (sig.group (launch2 1 1 2 2) 0 3),
    (toTiling (naiveView c) (naive_wf c 50257 _ _
      ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩)).off (some ⟨_, ho⟩) = 201032 := by
  have hmem : ∀ {L : Launch} {t : Nat}, t < volume L.grid * volume L.block →
      t ∈ sig.threads L := fun h => List.mem_range.2 h
  have ho : (naiveView c).Owner (asg [0, 0, 0, 0, 2, 50257]) (launch2 1 1 2 2)
      (sig.group (launch2 1 1 2 2) 0 3) := ⟨⟨3, hmem (by decide), rfl⟩,
    (by decide : (launch2 1 1 2 2).index 3 .x < 2 ∧ (launch2 1 1 2 2).index 3 .y < 50257)⟩
  refine ⟨ho, ?_⟩
  rw [(naive_toTiling c 50257 ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩ ho).1]
  decide

end MojoProofTest.GPUProof.ViewTiling
