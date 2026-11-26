import MojoProof.Float.Canon
import MojoProof.Float.Halve

/-!
# The butterfly and halving trees up to swapped children (docs/proofs/float-reductions.md)

A warp's butterfly rounds (MojoProof/Sem/Bfly.lean, `bflyTree`) and a block's halving rounds
(MojoProof/Float/Halve.lean, `halveStep`) evaluate FloatLib `ReductionTree`s of lane and cell
numbers. This module computes their canonical forms up to swapping the children of nodes
(`canon`, MojoProof/Float/Canon.lean) at every size: they are one tree, so by
`eval_nanEq_of_canon` the two loops give every lane below `2 ^ k` the same IEEE sum up to NaN
payloads.

Proved, for every `k`:
* `halve_succ`: cell 0's tree after the halving rounds over `2 ^ (k + 1)` cells is the node of
  the tree over `2 ^ k` cells with its leaves `i` relabelled `2i` and the same with `2i + 1`.
  `canon_halve`: the halving tree over `2 ^ k` cells is its own `canon`.
* `canon_bflyTree_xor`: for every list of offsets, offset `m` in it and lane `l`, the trees of
  lanes `l` and `l ^^^ m` after the butterfly rounds have the same `canon`.
  `canon_bflyTree_lane`: for offsets among which are `1, 2, ..., 2 ^ (k - 1)`, in any order and
  with other offsets allowed, every lane below `2 ^ k` has lane 0's `canon`.
* `canon_bflyOffsets`: after the rounds `bflyOffsets k` (`2 ^ (k - 1), ..., 2, 1`), every lane
  below `2 ^ k` has the halving tree's canonical form, which is the halving tree.
* `bfly_nanEq_lane`, `bfly_nanEq_halve`, in every format and at every values: the butterfly's
  IEEE sums (FloatLib's `Model.add`) at every lane below `2 ^ k` and lane 0's agree up to NaN
  payloads, and after the rounds `bflyOffsets k` they agree with cell 0's sum after the halving
  rounds over `2 ^ k` cells.

The statements are about the rounds as functions of the values; that a grid run of a kernel
performs them is not proved here. Lanes at or above `2 ^ k` have other leaves and are not covered.
The instances are in MojoProofTest/FloatCanonHalve.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem

/-- For every `k` and `j < 2 ^ k`, `j ^^^ 2 ^ k = j + 2 ^ k`: the bit `k` of `j` is clear. -/
private theorem xor_two_pow_of_lt {j k : Nat} (hj : j < 2 ^ k) : j ^^^ 2 ^ k = j + 2 ^ k := by
  have hd : (j ^^^ 2 ^ k) / 2 ^ k = 1 := by
    rw [Nat.xor_div_two_pow, Nat.div_eq_of_lt hj, Nat.div_self (Nat.two_pow_pos k), Nat.zero_xor]
  have hm : (j ^^^ 2 ^ k) % 2 ^ k = j := by
    rw [Nat.xor_mod_two_pow, Nat.mod_eq_of_lt hj, Nat.mod_self, Nat.xor_zero]
  have := Nat.div_add_mod (j ^^^ 2 ^ k) (2 ^ k)
  rw [hd, hm, Nat.mul_one] at this
  omega

/-- For every tree `t` of natural numbers and substitutions `f`, `g` that agree at the leaves of
`t`: `graft t f = graft t g`. -/
private theorem graft_congr {t : ReductionTree Nat} {f g : Nat → ReductionTree Nat}
    (h : ∀ j ∈ t.leaves, f j = g j) : graft t f = graft t g := by
  induction t with
  | leaf j => exact h j (by simp [ReductionTree.leaves])
  | node a b iha ihb =>
    simp only [ReductionTree.leaves, List.mem_append] at h
    simp only [graft, iha fun j hj => h j (.inl hj), ihb fun j hj => h j (.inr hj)]

/-- For every tree `t` of natural numbers and substitutions `f`, `g`: grafting `f`, then `g`, is
grafting the trees `f j` with `g` grafted. -/
private theorem graft_assoc (t : ReductionTree Nat) (f g : Nat → ReductionTree Nat) :
    graft (graft t f) g = graft t fun j => graft (f j) g := by
  induction t with
  | leaf _ => rfl
  | node a b iha ihb => simp only [graft, iha, ihb]

/-- For all offsets `ms`, trees `T` and lane `l`: the butterfly rounds started at the trees `T`
in place of the leaves give lane `l` the tree `bflyTree ms l` with each leaf `j` replaced by
`T j`. -/
private theorem foldl_bfly (ms : List Nat) (T : Nat → ReductionTree Nat) (l : Nat) :
    ms.foldl (fun T m l => .node (T l) (T (l ^^^ m))) T l = graft (bflyTree ms l) T := by
  induction ms generalizing T l with
  | nil => rfl
  | cons m ms ih =>
    show ms.foldl (fun T m l => .node (T l) (T (l ^^^ m))) (fun l => .node (T l) (T (l ^^^ m))) l
        = graft (ms.foldl (fun T m l => .node (T l) (T (l ^^^ m)))
          (fun l => .node (.leaf l) (.leaf (l ^^^ m))) l) T
    rw [ih, ih, graft_assoc]
    rfl

/-- The butterfly's last round at the root, for all offsets `ms`, offset `m` and lane `l`: lane
`l`'s tree after the rounds `ms`, then `m`, is the node of lane `l`'s and lane `l ^^^ m`'s trees
after `ms`. -/
private theorem bflyTree_concat (ms : List Nat) (m l : Nat) :
    bflyTree (ms ++ [m]) l = .node (bflyTree ms l) (bflyTree ms (l ^^^ m)) := by
  simp only [bflyTree, List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- For all trees `a`, `b` of natural numbers and every `x`: `canon (node a b)` is not a leaf. -/
private theorem canon_node_ne_leaf (a b : ReductionTree Nat) (x : Nat) :
    canon (.node a b) ≠ .leaf x := by
  unfold canon
  split <;> simp

/-- Grafting keeps equal canonical forms, for all trees `t`, `t'` of natural numbers with
`canon t = canon t'` and every substitution `f`: `canon (graft t f) = canon (graft t' f)`. -/
private theorem canon_graft {t t' : ReductionTree Nat} (h : canon t = canon t')
    (f : Nat → ReductionTree Nat) : canon (graft t f) = canon (graft t' f) := by
  induction t generalizing t' with
  | leaf x =>
    cases t' with
    | leaf y =>
      have hxy : x = y := by simpa [canon] using h
      rw [hxy]
    | node a b => exact absurd h.symm (canon_node_ne_leaf a b x)
  | node a b iha ihb =>
    cases t' with
    | leaf y => exact absurd h (canon_node_ne_leaf a b y)
    | node a' b' =>
      simp only [graft]
      rcases canon_node_eq_iff.1 h with ⟨h1, h2⟩ | ⟨h1, h2⟩
      · exact canon_node_eq_iff.2 (.inl ⟨iha h1, ihb h2⟩)
      · exact canon_node_eq_iff.2 (.inr ⟨iha h1, ihb h2⟩)

/-- For every tree `t` of natural numbers, `g : ℕ → ℕ` and substitution `f`: grafting `f` into
`t` with its leaves relabelled by `g` is grafting `f ∘ g` into `t`. -/
private theorem graft_map (t : ReductionTree Nat) (g : Nat → Nat) (f : Nat → ReductionTree Nat) :
    graft (t.map g) f = graft t fun j => f (g j) := by
  induction t with
  | leaf _ => rfl
  | node a b iha ihb => simp only [ReductionTree.map, graft, iha, ihb]

/-- For every tree `t` of natural numbers, substitution `f` and `g : ℕ → ℕ`: relabelling the
leaves of `graft t f` by `g` is grafting into `t` the trees `f j` relabelled by `g`. -/
private theorem map_graft (t : ReductionTree Nat) (f : Nat → ReductionTree Nat) (g : Nat → Nat) :
    (graft t f).map g = graft t fun j => (f j).map g := by
  induction t with
  | leaf _ => rfl
  | node a b iha ihb => simp only [ReductionTree.map, graft, iha, ihb]

/-- For every strictly increasing `g : ℕ → ℕ` and trees `a`, `b` of natural numbers: relabelling
both trees' leaves by `g` keeps `treeCmp`. -/
private theorem treeCmp_map {g : Nat → Nat} (hg : StrictMono g) :
    ∀ a b : ReductionTree Nat, treeCmp (a.map g) (b.map g) = treeCmp a b
  | .leaf x, .leaf y => by
    show compare (g x) (g y) = compare x y
    rcases lt_trichotomy x y with h | rfl | h
    · rw [compare_lt_iff_lt.2 h, compare_lt_iff_lt.2 (hg h)]
    · exact (compare_eq_iff_eq.2 rfl).trans (compare_eq_iff_eq.2 rfl).symm
    · rw [compare_gt_iff_gt.2 h, compare_gt_iff_gt.2 (hg h)]
  | .leaf _, .node _ _ => rfl
  | .node _ _, .leaf _ => rfl
  | .node a b, .node c d => by
    simp only [ReductionTree.map, treeCmp, treeCmp_map hg a c, treeCmp_map hg b d]

/-- For every tree `t` of natural numbers and `g g' : ℕ → ℕ` with `g x < g' x` at every `x`:
`treeCmp` of `t` relabelled by `g` and `t` relabelled by `g'` is `.lt`, from their first
leaves. -/
private theorem treeCmp_map_lt {g g' : Nat → Nat} (h : ∀ x, g x < g' x) :
    ∀ t : ReductionTree Nat, treeCmp (t.map g) (t.map g') = .lt
  | .leaf x => compare_lt_iff_lt.2 (h x)
  | .node a _ => by
    show (treeCmp (a.map g) (a.map g')).then _ = .lt
    rw [treeCmp_map_lt h a]
    rfl

/-- For every strictly increasing `g : ℕ → ℕ` and tree `t` of natural numbers: the canonical form
of `t` with its leaves relabelled by `g` is `canon t` relabelled by `g`. -/
private theorem canon_map {g : Nat → Nat} (hg : StrictMono g) :
    ∀ t : ReductionTree Nat, canon (t.map g) = (canon t).map g
  | .leaf _ => rfl
  | .node a b => by
    simp only [ReductionTree.map, canon, canon_map hg a, canon_map hg b, treeCmp_map hg]
    split_ifs <;> rfl

/-- **The halving tree, root first**, for every `k`: cell 0's tree after the halving rounds over
`2 ^ (k + 1)` cells (strides `2 ^ k, ..., 2, 1`) is the node of cell 0's tree over `2 ^ k` cells
with each leaf `i` relabelled `2i` and the same tree with each leaf relabelled `2i + 1`: the even
cells on the left, the odd ones on the right. With `roundsTree halveStep [] 0 = .leaf 0` it gives
the tree at every size; at 4 cells it is `(0 + 2) + (1 + 3)`. -/
theorem halve_succ (k : Nat) :
    roundsTree halveStep (bflyOffsets (k + 1)) 0 =
      .node ((roundsTree halveStep (bflyOffsets k) 0).map (2 * ·))
        ((roundsTree halveStep (bflyOffsets k) 0).map (2 * · + 1)) := by
  have step : ∀ k, roundsTree halveStep (bflyOffsets (k + 1)) 0 =
      graft (roundsTree halveStep (bflyOffsets k) 0) fun j => .node (.leaf j) (.leaf (j + 2 ^ k)) :=
    fun k => by
      rw [show bflyOffsets (k + 1) = 2 ^ k :: bflyOffsets k by simp [bflyOffsets, List.range_succ]]
      show graft (roundsTree halveStep (bflyOffsets k) 0) (halveStep (2 ^ k)) = _
      refine graft_congr fun j hj => ?_
      simp [halveStep, List.mem_range.1 ((leaves_halve k).mem_iff.1 hj)]
  induction k with
  | zero => decide
  | succ k ih =>
    have e : ∀ j, 2 * j + 2 ^ (k + 1) = 2 * (j + 2 ^ k) := fun j => by rw [Nat.pow_succ]; ring
    have e' : ∀ j, 2 * j + 1 + 2 ^ (k + 1) = 2 * (j + 2 ^ k) + 1 := fun j => by
      rw [Nat.pow_succ]; ring
    rw [step (k + 1)]
    conv_lhs => rw [ih]
    rw [step k]
    simp only [graft, graft_map, map_graft, ReductionTree.map, e, e']

/-- **The halving tree is canonical**, for every `k`: cell 0's tree after the halving rounds over
`2 ^ k` cells is its own `canon` (`Function.IsFixedPt canon`: `canon t = t`), as at every node the
left child's first leaf is the smaller (`halve_succ`: `2i` against `2i + 1`). -/
theorem canon_halve (k : Nat) :
    Function.IsFixedPt canon (roundsTree halveStep (bflyOffsets k) 0) := by
  induction k with
  | zero => rfl
  | succ k ih =>
    have hd : StrictMono fun x : Nat => 2 * x := fun a b h => show 2 * a < 2 * b by omega
    have hd' : StrictMono fun x : Nat => 2 * x + 1 := fun a b h =>
      show 2 * a + 1 < 2 * b + 1 by omega
    show canon _ = _
    rw [halve_succ, canon, canon_map hd, canon_map hd', ih.eq,
      treeCmp_map_lt (g := fun x => 2 * x) (g' := fun x => 2 * x + 1)
        (fun x => Nat.lt_succ_self (2 * x))]
    rfl

/-- **Lanes an offset apart have one canonical form**, for every list of offsets `ms`, offset
`m ∈ ms` and lane `l`: `canon (bflyTree ms (l ^^^ m)) = canon (bflyTree ms l)`. At the round of
`m` the two lanes' trees are the node of the same two trees in the two orders. -/
theorem canon_bflyTree_xor {ms : List Nat} {m : Nat} (hm : m ∈ ms) (l : Nat) :
    canon (bflyTree ms (l ^^^ m)) = canon (bflyTree ms l) := by
  induction ms using List.reverseRecOn generalizing l with
  | nil => exact absurd hm List.not_mem_nil
  | append_singleton ms m' ih =>
    rw [bflyTree_concat, bflyTree_concat]
    rcases List.mem_append.1 hm with hm | hm
    · rw [show l ^^^ m ^^^ m' = l ^^^ m' ^^^ m by
        rw [Nat.xor_assoc, Nat.xor_comm m m', ← Nat.xor_assoc]]
      exact canon_node_eq_iff.2 (.inl ⟨ih hm l, ih hm (l ^^^ m')⟩)
    · obtain rfl := List.mem_singleton.1 hm
      rw [Nat.xor_assoc, Nat.xor_self, Nat.xor_zero]
      exact canon_node_comm _ _

/-- **Every lane has lane 0's canonical form**, for every `k`, offsets `ms` among which are
`1, 2, ..., 2 ^ (k - 1)` (in any order, other offsets allowed) and lane `l < 2 ^ k`:
`canon (bflyTree ms l) = canon (bflyTree ms 0)`, by `canon_bflyTree_xor` at the bits of `l`. -/
theorem canon_bflyTree_lane {k : Nat} {ms : List Nat} (hms : ∀ i < k, 2 ^ i ∈ ms) {l : Nat}
    (hl : l < 2 ^ k) : canon (bflyTree ms l) = canon (bflyTree ms 0) := by
  induction k generalizing l with
  | zero =>
    obtain rfl : l = 0 := by simp at hl; omega
    rfl
  | succ k ih =>
    by_cases hlk : l < 2 ^ k
    · exact ih (fun i hi => hms i (by omega)) hlk
    · have hj : l - 2 ^ k < 2 ^ k := by rw [Nat.pow_succ] at hl; omega
      have e : l = (l - 2 ^ k) ^^^ 2 ^ k := by rw [xor_two_pow_of_lt hj]; omega
      rw [e, canon_bflyTree_xor (hms k (by omega)), ih (fun i hi => hms i (by omega)) hj]

/-- For every `k`: lane 0's tree after the rounds `bflyOffsets k` and cell 0's tree after the
halving rounds over `2 ^ k` cells have the same canonical form. -/
private theorem canon_bfly_zero (k : Nat) :
    canon (bflyTree (bflyOffsets k) 0) = canon (roundsTree halveStep (bflyOffsets k) 0) := by
  induction k with
  | zero => rfl
  | succ k ih =>
    rw [show bflyOffsets (k + 1) = 2 ^ k :: bflyOffsets k by simp [bflyOffsets, List.range_succ],
      show bflyTree (2 ^ k :: bflyOffsets k) 0 = graft (bflyTree (bflyOffsets k) 0)
        (fun j => .node (.leaf j) (.leaf (j ^^^ 2 ^ k))) from foldl_bfly (bflyOffsets k) _ 0,
      canon_graft ih,
      show roundsTree halveStep (2 ^ k :: bflyOffsets k) 0 =
        graft (roundsTree halveStep (bflyOffsets k) 0) (halveStep (2 ^ k)) from rfl]
    refine congrArg canon (graft_congr fun j hj => ?_)
    have hj := List.mem_range.1 ((leaves_halve k).mem_iff.1 hj)
    simp [halveStep, hj, xor_two_pow_of_lt hj]

/-- **The butterfly's canonical form is the halving tree's**, for every `k` and lane `l < 2 ^ k`:
lane `l`'s tree after the rounds `bflyOffsets k` (`2 ^ (k - 1), ..., 2, 1`) and cell 0's tree
after the halving rounds over `2 ^ k` cells have the same canonical form, which is the halving
tree itself (`canon_halve`). -/
theorem canon_bflyOffsets (k : Nat) {l : Nat} (hl : l < 2 ^ k) :
    canon (bflyTree (bflyOffsets k) l) = canon (roundsTree halveStep (bflyOffsets k) 0) :=
  (canon_bflyTree_lane (fun i hi => List.mem_reverse.2 (List.mem_map.2
    ⟨i, List.mem_range.2 hi, rfl⟩)) hl).trans (canon_bfly_zero k)

/-- **The butterfly's lanes agree up to NaN payloads**, in every format, for every `k`, offsets
`ms` among which are `1, 2, ..., 2 ^ (k - 1)` (in any order, other offsets allowed), values `v`
and lane `l < 2 ^ k`: lane `l`'s and lane 0's sums after the butterfly rounds of FloatLib's
`Model.add` are equal or both NaNs (`canon_bflyTree_lane`, `eval_nanEq_of_canon`). -/
theorem bfly_nanEq_lane {fmt : FloatFormat} {k : Nat} {ms : List Nat}
    (hms : ∀ i < k, 2 ^ i ∈ ms) (v : Nat → Model fmt) {l : Nat} (hl : l < 2 ^ k) :
    NaNEq (bflyRounds (fun x y => Model.add x y) ms v l)
      (bflyRounds (fun x y => Model.add x y) ms v 0) := by
  rw [← eval_bflyTree, ← eval_bflyTree]
  exact eval_nanEq_of_canon (canon_bflyTree_lane hms hl) v

/-- **The butterfly and the halving loop agree up to NaN payloads**, in every format, for every
`k`, values `v` and lane `l < 2 ^ k`: lane `l`'s sum after the butterfly rounds `bflyOffsets k`
of FloatLib's `Model.add` and cell 0's sum after the halving rounds over `2 ^ k` cells are equal
or both NaNs (`canon_bflyOffsets`, `eval_nanEq_of_canon`). -/
theorem bfly_nanEq_halve {fmt : FloatFormat} (k : Nat) (v : Nat → Model fmt) {l : Nat}
    (hl : l < 2 ^ k) :
    NaNEq (bflyRounds (fun x y => Model.add x y) (bflyOffsets k) v l)
      (rounds (fun x y => Model.add x y) halveStep (bflyOffsets k) v 0) := by
  rw [← eval_bflyTree, ← eval_roundsTree]
  exact eval_nanEq_of_canon (canon_bflyOffsets k hl) v

end MojoProof.Float
