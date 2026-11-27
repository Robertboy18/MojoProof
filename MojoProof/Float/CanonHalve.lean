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
* `bflyTree_xor`: for every list of offsets and every lane `l`, at or above `2 ^ k` too, lane
  `l`'s tree is lane 0's with each leaf `j` relabelled `j ^^^ l`.
  `canon_bflyTree_perm`: after the rounds `bflyOffsets k` in any order (a `List.Perm`), lane 0's
  tree is its own `canon`, and every lane `l` has the canonical form lane 0's tree with each leaf
  `j` relabelled `j + 2 ^ k ⌊l / 2 ^ k⌋`: lane 0's tree below `2 ^ k`, and above it the same tree
  over the lanes of `l`'s group of `2 ^ k`.
* `bfly_nanEq_lane`, `bfly_nanEq_halve`, in every format and at every values: the butterfly's
  IEEE sums (FloatLib's `Model.add`) at every lane below `2 ^ k` and lane 0's agree up to NaN
  payloads, and after the rounds `bflyOffsets k` they agree with cell 0's sum after the halving
  rounds over `2 ^ k` cells.

The statements are about the rounds as functions of the values; that a grid run of a kernel
performs them is not proved here. With other offsets than `bflyOffsets k` in some order (one
repeated, one that is not a power of two, or more than `k`) the canonical forms are not computed:
`canon_bflyTree_lane` still gives every lane below `2 ^ k` lane 0's, but lane 0's tree need not be
its own `canon`. The instances are in MojoProofTest/FloatCanonHalve.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem

/-- For every `j` and `i` with the bit `i` of `j` clear (as when `j < 2 ^ i`):
`j ^^^ 2 ^ i = j + 2 ^ i`. -/
private theorem xor_two_pow_of_testBit {j i : Nat} (h : j.testBit i = false) :
    j ^^^ 2 ^ i = j + 2 ^ i := by
  have hq : j / 2 ^ i % 2 = 0 := by
    rw [Nat.testBit_eq_decide_div_mod_eq, decide_eq_false_iff_not] at h
    omega
  have hd : (j ^^^ 2 ^ i) / 2 ^ i = j / 2 ^ i + 1 := by
    rw [Nat.xor_div_two_pow, Nat.div_self (Nat.two_pow_pos i)]
    generalize j / 2 ^ i = q at hq ⊢
    have h1 : (q ^^^ 1) / 2 = q / 2 := by simpa using Nat.xor_div_two_pow (a := q) (b := 1) (n := 1)
    have h2 : (q ^^^ 1) % 2 = 1 := by
      have := Nat.xor_mod_two_pow (a := q) (b := 1) (n := 1)
      simp only [Nat.pow_one] at this
      rw [this, hq]
      rfl
    omega
  have hm : (j ^^^ 2 ^ i) % 2 ^ i = j % 2 ^ i := by
    rw [Nat.xor_mod_two_pow, Nat.mod_self, Nat.xor_zero]
  have e₁ := Nat.div_add_mod (j ^^^ 2 ^ i) (2 ^ i)
  have e₂ := Nat.div_add_mod j (2 ^ i)
  rw [hd, hm, Nat.mul_add, Nat.mul_one] at e₁
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

/-- For every tree `t` of natural numbers and `f g : ℕ → ℕ`: relabelling the leaves of `t` by `f`,
then by `g`, is relabelling them by `g ∘ f`. -/
private theorem map_map (t : ReductionTree Nat) (f g : Nat → Nat) :
    (t.map f).map g = t.map fun j => g (f j) := by
  induction t with
  | leaf _ => rfl
  | node a b iha ihb => simp only [ReductionTree.map, iha, ihb]

/-- For every tree `t` of natural numbers and `f g : ℕ → ℕ` that agree at the leaves of `t`:
`t.map f = t.map g`. -/
private theorem map_congr {t : ReductionTree Nat} {f g : Nat → Nat}
    (h : ∀ j ∈ t.leaves, f j = g j) : t.map f = t.map g := by
  induction t with
  | leaf j => exact congrArg ReductionTree.leaf (h j (List.mem_singleton_self j))
  | node a b iha ihb =>
    simp only [ReductionTree.leaves, List.mem_append] at h
    simp only [ReductionTree.map, iha fun j hj => h j (.inl hj), ihb fun j hj => h j (.inr hj)]

/-- For every tree `t` of natural numbers: relabelling its leaves by the identity gives `t`. -/
private theorem map_self (t : ReductionTree Nat) : t.map (fun j => j) = t := by
  induction t with
  | leaf _ => rfl
  | node a b iha ihb => simp only [ReductionTree.map, iha, ihb]

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
      have e : l = (l - 2 ^ k) ^^^ 2 ^ k := by
        rw [xor_two_pow_of_testBit (Nat.testBit_lt_two_pow hj)]; omega
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
    simp [halveStep, hj, xor_two_pow_of_testBit (Nat.testBit_lt_two_pow hj)]

/-- **The butterfly's canonical form is the halving tree's**, for every `k` and lane `l < 2 ^ k`:
lane `l`'s tree after the rounds `bflyOffsets k` (`2 ^ (k - 1), ..., 2, 1`) and cell 0's tree
after the halving rounds over `2 ^ k` cells have the same canonical form, which is the halving
tree itself (`canon_halve`). -/
theorem canon_bflyOffsets (k : Nat) {l : Nat} (hl : l < 2 ^ k) :
    canon (bflyTree (bflyOffsets k) l) = canon (roundsTree halveStep (bflyOffsets k) 0) :=
  (canon_bflyTree_lane (fun i hi => List.mem_reverse.2 (List.mem_map.2
    ⟨i, List.mem_range.2 hi, rfl⟩)) hl).trans (canon_bfly_zero k)

/-- **Every lane's tree is lane 0's, relabelled**, for every list of offsets `ms` and every lane
`l`, at or above `2 ^ k` too: lane `l`'s tree after the butterfly rounds `ms` is lane 0's with
each leaf `j` relabelled `j ^^^ l`. At the last round lane `l`'s tree is the node of lane `l`'s
and lane `l ^^^ m`'s trees, and `j ^^^ m ^^^ l = j ^^^ (l ^^^ m)`. -/
theorem bflyTree_xor (ms : List Nat) (l : Nat) :
    bflyTree ms l = (bflyTree ms 0).map (· ^^^ l) := by
  induction ms using List.reverseRecOn generalizing l with
  | nil => exact congrArg ReductionTree.leaf (Nat.zero_xor l).symm
  | append_singleton ms m ih =>
    rw [bflyTree_concat, bflyTree_concat, ih l, ih (l ^^^ m), ih (0 ^^^ m)]
    simp only [ReductionTree.map, map_map]
    congr 2
    funext j
    rw [Nat.zero_xor, Nat.xor_assoc, Nat.xor_comm m l]

/-- For every list of offsets `ms`, leaf `j` of lane 0's tree after the rounds `ms` and bit `i`
of `j`: some offset in `ms` has the bit `i` (`j` is the XOR of some of the offsets). -/
private theorem exists_testBit {ms : List Nat} {j : Nat} (hj : j ∈ (bflyTree ms 0).leaves)
    {i : Nat} (hi : j.testBit i = true) : ∃ m ∈ ms, m.testBit i = true := by
  induction ms using List.reverseRecOn generalizing j with
  | nil =>
    obtain rfl : j = 0 := by simpa [bflyTree, ReductionTree.leaves] using hj
    simp at hi
  | append_singleton ms m ih =>
    rw [bflyTree_concat, bflyTree_xor ms (0 ^^^ m), Nat.zero_xor] at hj
    simp only [ReductionTree.leaves, ReductionTree.leaves_map, List.mem_append,
      List.mem_map] at hj
    rcases hj with hj | ⟨j', hj', rfl⟩
    · obtain ⟨m', hm', h'⟩ := ih hj hi
      exact ⟨m', List.mem_append_left _ hm', h'⟩
    · rw [Nat.testBit_xor] at hi
      cases hb : j'.testBit i
      · rw [hb, Bool.false_xor] at hi
        exact ⟨m, List.mem_append_right _ (List.mem_singleton_self m), hi⟩
      · obtain ⟨m', hm', h'⟩ := ih hj' hb
        exact ⟨m', List.mem_append_left _ hm', h'⟩

/-- **The butterfly's canonical forms in every order and at every lane**, for every `k`, offsets
`ms` that are `bflyOffsets k` in any order (`List.Perm`) and lane `l`: the canonical form of lane
`l`'s tree after the rounds `ms` is lane 0's tree with each leaf `j` relabelled
`j + 2 ^ k ⌊l / 2 ^ k⌋`. So lane 0's tree is its own `canon`, it is the canonical form of every
lane below `2 ^ k`, and a lane at or above `2 ^ k` has it shifted to the lanes
`2 ^ k ⌊l / 2 ^ k⌋, ..., 2 ^ k ⌊l / 2 ^ k⌋ + 2 ^ k - 1` of its group. Lane 0's tree is canonical
by induction on the rounds: after a round `2 ^ i` it is the node of a canonical tree `T` whose
leaves have the bit `i` clear and `T` with each leaf `j` relabelled `j + 2 ^ i`, which `canon`
keeps. Lane `l`'s tree is lane 0's relabelled `j ^^^ l` (`bflyTree_xor`), at leaves `j < 2 ^ k`
the tree of lane `l % 2 ^ k` shifted by `2 ^ k ⌊l / 2 ^ k⌋`, whose `canon` is lane 0's
(`canon_bflyTree_lane`). -/
theorem canon_bflyTree_perm {k : Nat} {ms : List Nat} (hms : ms.Perm (bflyOffsets k)) (l : Nat) :
    canon (bflyTree ms l) = (bflyTree ms 0).map (· + 2 ^ k * (l / 2 ^ k)) := by
  have hfix : ∀ ns : List Nat, ns.Nodup → (∀ m ∈ ns, ∃ i, m = 2 ^ i) →
      canon (bflyTree ns 0) = bflyTree ns 0 := by
    intro ns
    induction ns using List.reverseRecOn with
    | nil => intros; rfl
    | append_singleton ns m ih =>
      intro hn hp
      obtain ⟨i, rfl⟩ := hp m (List.mem_append_right _ (List.mem_singleton_self _))
      have hm : 2 ^ i ∉ ns := fun h => by simp [List.nodup_append] at hn; exact hn.2 _ h rfl
      have hT := ih (List.Nodup.of_append_left hn) fun m hm => hp m (List.mem_append_left _ hm)
      have hr : bflyTree ns (0 ^^^ 2 ^ i) = (bflyTree ns 0).map (· + 2 ^ i) := by
        rw [bflyTree_xor, Nat.zero_xor]
        refine map_congr fun j hj => xor_two_pow_of_testBit ?_
        cases hb : j.testBit i
        · rfl
        · obtain ⟨m', hm', h'⟩ := exists_testBit hj hb
          obtain ⟨i', rfl⟩ := hp m' (List.mem_append_left _ hm')
          obtain rfl : i' = i := of_decide_eq_true (Nat.testBit_two_pow ▸ h')
          exact absurd hm' hm
      have hlt := treeCmp_map_lt (g := fun j => j) (g' := (· + 2 ^ i))
        (fun j => Nat.lt_add_of_pos_right (Nat.two_pow_pos i)) (bflyTree ns 0)
      rw [map_self] at hlt
      rw [bflyTree_concat, hr, canon, hT,
        canon_map (g := (· + 2 ^ i)) fun a b h => show a + 2 ^ i < b + 2 ^ i by omega, hT, hlt]
      rfl
  have hmem : ∀ m, m ∈ ms ↔ ∃ i < k, 2 ^ i = m := fun m => by
    rw [hms.mem_iff]
    simp [bflyOffsets]
  have hn : ms.Nodup := hms.nodup_iff.2 (List.nodup_reverse.2
    (List.nodup_range.map (Nat.pow_right_injective le_rfl)))
  have hleaf : ∀ j ∈ (bflyTree ms 0).leaves, j < 2 ^ k := fun j hj =>
    Nat.lt_pow_two_of_testBit j fun i hi => by
      cases hb : j.testBit i
      · rfl
      · obtain ⟨m, hm, h⟩ := exists_testBit hj hb
        obtain ⟨i', hi', rfl⟩ := (hmem m).1 hm
        have := of_decide_eq_true (Nat.testBit_two_pow ▸ h)
        omega
  have hx : ∀ j < 2 ^ k, j ^^^ l = (j ^^^ l % 2 ^ k) + 2 ^ k * (l / 2 ^ k) := fun j hj => by
    have hd : (j ^^^ l) / 2 ^ k = l / 2 ^ k := by
      rw [Nat.xor_div_two_pow, Nat.div_eq_of_lt hj, Nat.zero_xor]
    have hm : (j ^^^ l) % 2 ^ k = j ^^^ l % 2 ^ k := by
      rw [Nat.xor_mod_two_pow, Nat.mod_eq_of_lt hj]
    have e := Nat.div_add_mod (j ^^^ l) (2 ^ k)
    rw [hd, hm] at e
    exact e.symm.trans (Nat.add_comm _ _)
  have hl : bflyTree ms l = (bflyTree ms (l % 2 ^ k)).map (· + 2 ^ k * (l / 2 ^ k)) := by
    rw [bflyTree_xor ms l, bflyTree_xor ms (l % 2 ^ k), map_map]
    exact map_congr fun j hj => hx j (hleaf j hj)
  rw [hl, canon_map (g := (· + 2 ^ k * (l / 2 ^ k))) fun a b h => show a + _ < b + _ by omega,
    canon_bflyTree_lane (fun i hi => (hmem _).2 ⟨i, hi, rfl⟩) (Nat.mod_lt _ (Nat.two_pow_pos k)),
    hfix ms hn fun m hm => (fun ⟨i, _, h⟩ => ⟨i, h.symm⟩) ((hmem m).1 hm)]

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
