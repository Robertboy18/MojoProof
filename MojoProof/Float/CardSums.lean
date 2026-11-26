import MojoProof.Float.CanonIff
import Mathlib.Data.Nat.Factorial.DoubleFactorial

/-!
# The IEEE sums of `n` distinct inputs as canonical trees (docs/proofs/float-reductions.md)

A reduction tree over `Fin n` that uses each index once sums `n` inputs in some order and
grouping. Two such trees give the same function of the inputs, up to NaN payloads, exactly when
they have the same `canon` (`MojoProof.Float.eval_add_eq_iff`). This module counts those
functions: they are in bijection with the trees that are their own `canon`, and there are
`(2n - 3)‼` of these.

Definitions, for every format and `n`:
* `FullTree n`: the trees over `Fin n` whose leaf lists are permutations of `List.finRange n`.
* `sumSetoid fmt n`: two of them are related when they agree up to NaN payloads on every input
  of `fmt`.
* `SumFunction fmt n`: the quotient, the functions of `n` inputs that some tree computes.
* `CanonTree n`: the trees of `FullTree n` with `canon t = t`.

Proved, for every IEEE format and `n`:
* `sumFunctionEquiv`: `SumFunction fmt n ≃ CanonTree n`, a class to the `canon` of its trees.
* `card_sumFunction`: the two have the same `Nat.card`.
* `card_canonTree`, for every `n ≥ 1`: `Nat.card (CanonTree n) = (2n - 3)‼`.
* `card_sums`, for every IEEE format and `n ≥ 2`: `Nat.card (SumFunction fmt n) = (2n - 3)‼`.

The count goes through other representatives of the classes of trees up to swapping children:
the min-first trees, whose every node has the child with the smaller first leaf on the left
(`minFirst`, against `canon` by `canonEquiv`). Over the leaves `z :: l` with `z` above all of
`l`, cutting `leaf z` out of a min-first tree (`cutLeaf`) leaves a min-first tree over `l` and
the place it was grafted at, one of `2 * l.length - 1` (`slots`), and grafting it back at a place
(`insLeaf`) is the inverse (`graftEquiv`); so the count over `n` leaves is `(2n - 3)‼` by
induction from one leaf (`card_minFirstTree`). The counts at one to four leaves are tests
(MojoProofTest/FloatCardSums.lean).
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem
open scoped Nat

/-- The trees over `Fin n` that use each index once, for every `n`: those whose leaf list is a
permutation of `List.finRange n`. -/
abbrev FullTree (n : ℕ) : Type := {t : ReductionTree (Fin n) // t.leaves.Perm (List.finRange n)}

/-- Agreeing up to NaN payloads on every input, for every format and `n`: the equivalence on
`FullTree n` relating two trees whose IEEE sums are `NaNEq` at every input of `fmt` (an
equivalence because `NaNEq` is one, `GPUProof.UpToNaN.equivalence`). -/
def sumSetoid (fmt : FloatFormat) (n : ℕ) : Setoid (FullTree n) where
  r t t' := ∀ v : Fin n → Model fmt,
    NaNEq (t.1.eval (fun x y => Model.add x y) v) (t'.1.eval (fun x y => Model.add x y) v)
  iseqv := ⟨fun _ _ => (GPUProof.UpToNaN.equivalence _).refl _,
    fun h v => (GPUProof.UpToNaN.equivalence _).symm (h v),
    fun h h' v => (GPUProof.UpToNaN.equivalence _).trans (h v) (h' v)⟩

/-- The functions of `n` inputs that an IEEE sum computes, for every format and `n`: the trees of
`FullTree n` up to agreeing up to NaN payloads on every input of `fmt` (`sumSetoid`). -/
abbrev SumFunction (fmt : FloatFormat) (n : ℕ) : Type := Quotient (sumSetoid fmt n)

/-- The trees over `Fin n` that use each index once and are their own canonical form, for every
`n`: one for each class of trees up to swapping the children of nodes. -/
abbrev CanonTree (n : ℕ) : Type :=
  {t : ReductionTree (Fin n) // t.leaves.Perm (List.finRange n) ∧ canon t = t}

/-- **The IEEE sums of `n` distinct inputs are the canonical trees**, for every IEEE format and
`n`: a class of trees goes to the `canon` of any of its trees, the same for all of them by
`eval_add_eq_iff` (the leaves are those of `List.finRange n`, without repeats), and a canonical
tree to its class; a tree and its `canon` agree up to NaN payloads (`eval_nanEq_of_canon`). -/
def sumFunctionEquiv {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (n : ℕ) :
    SumFunction fmt n ≃ CanonTree n where
  toFun := Quotient.lift (fun t => ⟨canon t.1, (perm_canon t.1).trans t.2, canon_canon t.1⟩)
    fun t t' h => Subtype.ext ((eval_add_eq_iff hfmt (t.2.nodup_iff.mpr (List.nodup_finRange n))
      (t.2.trans t'.2.symm)).mp h)
  invFun s := Quotient.mk _ ⟨s.1, s.2.1⟩
  left_inv q := Quotient.inductionOn q fun t =>
    Quotient.sound fun v => eval_nanEq_of_canon (canon_canon t.1) v
  right_inv s := Subtype.ext s.2.2

/-- **The number of IEEE sums of `n` distinct inputs is the number of canonical trees**, for
every IEEE format and `n`: `Nat.card` of `sumFunctionEquiv`'s two sides. -/
theorem card_sumFunction {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (n : ℕ) :
    Nat.card (SumFunction fmt n) = Nat.card (CanonTree n) :=
  Nat.card_congr (sumFunctionEquiv hfmt n)

section Count

variable {ι : Type*}

/-- The first leaf of a tree, for every leaf type and tree: a leaf's value, and at a node the first
leaf of its left child. -/
private def firstLeaf : ReductionTree ι → ι
  | .leaf x => x
  | .node a _ => firstLeaf a

/-- A tree's first leaf is one of its leaves, for every leaf type and tree. -/
private theorem firstLeaf_mem : ∀ t : ReductionTree ι, firstLeaf t ∈ t.leaves
  | .leaf _ => List.mem_singleton_self _
  | .node a _ => List.mem_append_left _ (firstLeaf_mem a)

/-- The number of places at which a new leaf can be grafted on a tree, for every leaf type and
tree: one above each of its nodes and leaves, `2 * t.nodeCount + 1`. -/
private def slots (t : ReductionTree ι) : ℕ := 2 * t.nodeCount + 1

/-- `slots` at a node, for every leaf type and trees `a`, `b`:
`slots (node a b) = slots a + slots b + 1`. -/
private theorem slots_node (a b : ReductionTree ι) : slots (.node a b) = slots a + slots b + 1 := by
  simp only [slots, ReductionTree.nodeCount]
  omega

/-- `slots` from the leaves, for every leaf type, tree `t` and list `l` that the leaves of `t` are a
permutation of: `slots t = 2 * l.length - 1`. -/
private theorem slots_eq {t : ReductionTree ι} {l : List ι} (h : t.leaves.Perm l) :
    slots t = 2 * l.length - 1 := by
  have := ReductionTree.length_leaves t
  rw [h.length_eq] at this
  simp only [slots]
  omega

/-- **Grafting the leaf `z` at place `k` of a tree**, for every leaf type, value `z`, place `k` and
tree: at place `0`, the node of the tree and `leaf z`; at place `k + 1` of a node, place `k` of
its left child if `k < slots` of the left child, and otherwise place `k - slots` of the left child
in its right child; a leaf has no place `k + 1` and is kept. -/
private def insLeaf (z : ι) : ℕ → ReductionTree ι → ReductionTree ι
  | 0, t => .node t (.leaf z)
  | _ + 1, .leaf x => .leaf x
  | k + 1, .node a b =>
    if k < slots a then .node (insLeaf z k a) b else .node a (insLeaf z (k - slots a) b)

/-- Grafting keeps the first leaf, for every leaf type, value `z`, place `k` and tree `t`. -/
private theorem firstLeaf_insLeaf (z : ι) :
    ∀ (k : ℕ) (t : ReductionTree ι), firstLeaf (insLeaf z k t) = firstLeaf t
  | 0, _ => by simp only [insLeaf, firstLeaf]
  | _ + 1, .leaf _ => rfl
  | k + 1, .node a b => by
    simp only [insLeaf]
    split
    · exact firstLeaf_insLeaf z k a
    · rfl

/-- Grafting adds `z` to the leaves, for every leaf type, value `z`, tree `t` and place
`k < slots t`: the leaves of `insLeaf z k t` are a permutation of `z :: t.leaves`. -/
private theorem perm_insLeaf (z : ι) :
    ∀ (k : ℕ) (t : ReductionTree ι), k < slots t → (insLeaf z k t).leaves.Perm (z :: t.leaves)
  | 0, t, _ => by
    simp only [insLeaf]
    exact List.perm_append_singleton z t.leaves
  | _ + 1, .leaf _, h => by simp [slots, ReductionTree.nodeCount] at h
  | k + 1, .node a b, h => by
    rw [slots_node] at h
    simp only [insLeaf]
    split
    · next hk => exact (perm_insLeaf z k a hk).append_right b.leaves
    · next hk =>
      exact ((perm_insLeaf z (k - slots a) b (by omega)).append_left a.leaves).trans
        List.perm_middle

/-- Grafting at a place gives a node, for every leaf type, values `z`, `y`, tree `t` and place
`k < slots t`. -/
private theorem insLeaf_ne_leaf {z y : ι} :
    ∀ (k : ℕ) {t : ReductionTree ι}, k < slots t → insLeaf z k t ≠ .leaf y
  | 0, _, _ => by simp [insLeaf]
  | _ + 1, .leaf _, h => by simp [slots, ReductionTree.nodeCount] at h
  | k + 1, .node a b, _ => by
    simp only [insLeaf]
    split <;> simp

/-- **Removing the leaf `z` from a tree**, for every leaf type with decidable equality, value `z`
and tree: the tree left and the place at which `insLeaf z` grafts `z` back. At a node whose right
child is `leaf z`, its left child at place `0`; at a node with `z` among its left child's leaves,
the node with the left child cut, at one place more; at another node, the node with the right
child cut, at `slots` of the left child plus one places more. A leaf is kept, at place `0`. -/
private def cutLeaf [DecidableEq ι] (z : ι) : ReductionTree ι → ReductionTree ι × ℕ
  | .leaf x => (.leaf x, 0)
  | .node a b =>
    if b = .leaf z then (a, 0)
    else if z ∈ a.leaves then (.node (cutLeaf z a).1 b, (cutLeaf z a).2 + 1)
    else (.node a (cutLeaf z b).1, slots a + (cutLeaf z b).2 + 1)

/-- **Cutting a grafted leaf gives the tree and the place back**, for every leaf type with
decidable equality, value `z`, place `k` and tree `t` without the leaf `z` with `k < slots t`:
`cutLeaf z (insLeaf z k t) = (t, k)`. -/
private theorem cutLeaf_insLeaf [DecidableEq ι] {z : ι} :
    ∀ (k : ℕ) {t : ReductionTree ι}, z ∉ t.leaves → k < slots t →
      cutLeaf z (insLeaf z k t) = (t, k)
  | 0, t, _, _ => by simp [insLeaf, cutLeaf]
  | _ + 1, .leaf _, _, h => by simp [slots, ReductionTree.nodeCount] at h
  | k + 1, .node a b, hz, h => by
    rw [slots_node] at h
    simp only [ReductionTree.leaves, List.mem_append, not_or] at hz
    simp only [insLeaf]
    split
    · next hk =>
      have hb : b ≠ .leaf z := by
        rintro rfl
        exact hz.2 (List.mem_singleton_self z)
      have hm : z ∈ (insLeaf z k a).leaves := (perm_insLeaf z k a hk).mem_iff.mpr (by simp)
      rw [cutLeaf, ite_eq_right hb, ite_eq_left hm, cutLeaf_insLeaf k hz.1 hk]
    · next hk =>
      have hb : insLeaf z (k - slots a) b ≠ .leaf z := insLeaf_ne_leaf _ (by omega)
      rw [cutLeaf, ite_eq_right hb, ite_eq_right hz.1,
        cutLeaf_insLeaf (k - slots a) hz.2 (by omega)]
      simp only [Prod.mk.injEq, true_and]
      omega

variable [LinearOrder ι]

/-- **Min-first trees**, for every leaf type with a linear order and tree: at every node, the
first leaf of the left child is below that of the right child. -/
private def IsMinFirst : ReductionTree ι → Prop
  | .leaf _ => True
  | .node a b => firstLeaf a < firstLeaf b ∧ IsMinFirst a ∧ IsMinFirst b

/-- **Grafting a greater leaf keeps a tree min-first**, for every leaf type with a linear order,
value `z`, place `k` and min-first tree `t` whose leaves are all below `z`. -/
private theorem isMinFirst_insLeaf {z : ι} :
    ∀ (k : ℕ) {t : ReductionTree ι}, IsMinFirst t → (∀ x ∈ t.leaves, x < z) →
      IsMinFirst (insLeaf z k t)
  | 0, t, ht, hz => by
    simp only [insLeaf]
    exact ⟨hz _ (firstLeaf_mem t), ht, trivial⟩
  | _ + 1, .leaf _, _, _ => trivial
  | k + 1, .node a b, ⟨hab, ha, hb⟩, hz => by
    simp only [insLeaf]
    split
    · refine ⟨?_, isMinFirst_insLeaf k ha fun x hx => hz x (List.mem_append_left _ hx), hb⟩
      rw [firstLeaf_insLeaf]
      exact hab
    · refine ⟨?_, ha, isMinFirst_insLeaf _ hb fun x hx => hz x (List.mem_append_right _ hx)⟩
      rw [firstLeaf_insLeaf]
      exact hab

/-- **Cutting the greatest leaf of a min-first tree**, for every leaf type with a linear order,
value `z` and min-first tree `t` other than `leaf z`, with `z` among its leaves and every leaf at
most `z`: `cutLeaf z t` is a place below `slots` of a tree left, `insLeaf z` there gives `t` back,
the tree left has the leaves of `t` but one `z`, and it is min-first with the first leaf of `t`. -/
private theorem cutLeaf_spec {z : ι} :
    ∀ {t : ReductionTree ι}, IsMinFirst t → (∀ x ∈ t.leaves, x ≤ z) → z ∈ t.leaves →
      t ≠ .leaf z →
      (cutLeaf z t).2 < slots (cutLeaf z t).1 ∧ insLeaf z (cutLeaf z t).2 (cutLeaf z t).1 = t ∧
        (z :: (cutLeaf z t).1.leaves).Perm t.leaves ∧ IsMinFirst (cutLeaf z t).1 ∧
        firstLeaf (cutLeaf z t).1 = firstLeaf t
  | .leaf x, _, _, hm, hne => by
    simp only [ReductionTree.leaves, List.mem_singleton] at hm
    exact absurd (by rw [hm]) hne
  | .node a b, ⟨hab, ha, hb⟩, hle, hm, _ => by
    have hla : ∀ x ∈ a.leaves, x ≤ z := fun x hx => hle x (List.mem_append_left _ hx)
    have hlb : ∀ x ∈ b.leaves, x ≤ z := fun x hx => hle x (List.mem_append_right _ hx)
    by_cases hbz : b = .leaf z
    · subst hbz
      rw [cutLeaf, ite_eq_left rfl]
      refine ⟨by simp only [slots]; omega, by simp only [insLeaf],
        (List.perm_append_singleton z a.leaves).symm, ha, rfl⟩
    by_cases hza : z ∈ a.leaves
    · have hna : a ≠ .leaf z := by
        rintro rfl
        exact absurd (hlb _ (firstLeaf_mem b)) (not_le.mpr hab)
      obtain ⟨h1, h2, h3, h4, h5⟩ := cutLeaf_spec ha hla hza hna
      rw [cutLeaf, ite_eq_right hbz, ite_eq_left hza]
      dsimp only
      refine ⟨by rw [slots_node]; omega, ?_, h3.append_right b.leaves, ⟨?_, h4, hb⟩, h5⟩
      · simp only [insLeaf, ite_eq_left h1, h2]
      · rw [h5]
        exact hab
    · have hzb : z ∈ b.leaves := by
        simpa [ReductionTree.leaves, hza] using hm
      obtain ⟨h1, h2, h3, h4, h5⟩ := cutLeaf_spec hb hlb hzb hbz
      rw [cutLeaf, ite_eq_right hbz, ite_eq_right hza]
      dsimp only
      refine ⟨by rw [slots_node]; omega, ?_,
        List.perm_middle.symm.trans (h3.append_left a.leaves), ⟨?_, ha, h4⟩, rfl⟩
      · simp only [insLeaf, ite_eq_right (show ¬ slots a + (cutLeaf z b).2 < slots a by omega),
          Nat.add_sub_cancel_left, h2]
      · rw [h5]
        exact hab

/-- The min-first trees whose leaves are a permutation of `l`, for every leaf type with a linear
order and list `l`. -/
private abbrev MinFirstTree (l : List ι) : Type _ :=
  {t : ReductionTree ι // t.leaves.Perm l ∧ IsMinFirst t}

/-- **Grafting the greatest leaf**, for every leaf type with a linear order, value `z` and
nonempty list `l` of values below `z`: the min-first trees over `z :: l` are the pairs of a
min-first tree over `l` and one of its `2 * l.length - 1` places, by `cutLeaf z` one way and
`insLeaf z` back. -/
private def graftEquiv {z : ι} {l : List ι} (hz : ∀ x ∈ l, x < z) (hl : l ≠ []) :
    MinFirstTree (z :: l) ≃ MinFirstTree l × Fin (2 * l.length - 1) :=
  have spec (t : MinFirstTree (z :: l)) := cutLeaf_spec t.2.2
    (fun x hx => by
      rcases List.mem_cons.mp (t.2.1.mem_iff.mp hx) with rfl | hx
      · exact le_rfl
      · exact (hz x hx).le)
    (t.2.1.mem_iff.mpr (List.mem_cons_self ..))
    (by
      rintro h
      have := t.2.1.length_eq
      rw [h] at this
      simp only [ReductionTree.leaves, List.length_cons, List.length_nil] at this
      exact hl (List.eq_nil_of_length_eq_zero (by omega)))
  { toFun := fun t =>
      have hp := ((spec t).2.2.1.trans t.2.1).cons_inv
      (⟨(cutLeaf z t.1).1, hp, (spec t).2.2.2.1⟩,
        ⟨(cutLeaf z t.1).2, lt_of_lt_of_eq (spec t).1 (slots_eq hp)⟩)
    invFun := fun p =>
      ⟨insLeaf z p.2 p.1.1,
        (perm_insLeaf z p.2 p.1.1 (lt_of_lt_of_eq p.2.2 (slots_eq p.1.2.1).symm)).trans
          (p.1.2.1.cons z),
        isMinFirst_insLeaf p.2 p.1.2.2 fun x hx => hz x (p.1.2.1.mem_iff.mp hx)⟩
    left_inv := fun t => Subtype.ext (spec t).2.1
    right_inv := fun p => by
      have h := cutLeaf_insLeaf (z := z) p.2 (t := p.1.1)
        (fun hm => lt_irrefl z (hz z (p.1.2.1.mem_iff.mp hm)))
        (lt_of_lt_of_eq p.2.2 (slots_eq p.1.2.1).symm)
      ext
      · simp only [h]
      · simp only [h] }

/-- `(2m - 3)‼` times `2m - 1` is `(2(m + 1) - 3)‼`, for every `m ≥ 1`. -/
private theorem doubleFactorial_step (m : ℕ) :
    (2 * (m + 1) - 3)‼ * (2 * (m + 1) - 1) = (2 * (m + 1 + 1) - 3)‼ := by
  rcases m with _ | j
  · rfl
  · rw [show 2 * (j + 1 + 1) - 3 = 2 * j + 1 by omega,
      show 2 * (j + 1 + 1) - 1 = 2 * j + 1 + 2 by omega,
      show 2 * (j + 1 + 1 + 1) - 3 = 2 * j + 1 + 2 by omega, Nat.doubleFactorial_add_two,
      mul_comm]

/-- **The number of min-first trees over a list**, for every leaf type with a linear order and
nonempty list `l` strictly decreasing: `(2 * l.length - 3)‼`, by grafting its first, greatest,
value on the trees over the rest (`graftEquiv`). -/
private theorem card_minFirstTree :
    ∀ {l : List ι}, l.Pairwise (· > ·) → l ≠ [] → Nat.card (MinFirstTree l) = (2 * l.length - 3)‼
  | [], _, h => absurd rfl h
  | [z], _, _ => by
    rw [show (2 * [z].length - 3)‼ = 1 from rfl, Nat.card_eq_one_iff_exists]
    refine ⟨⟨.leaf z, List.Perm.refl _, trivial⟩, fun t => Subtype.ext ?_⟩
    obtain ⟨t, ht, _⟩ := t
    cases t with
    | leaf x =>
      have := List.perm_singleton.mp ht
      simp only [ReductionTree.leaves, List.cons.injEq, and_true] at this
      simp [this]
    | node a b =>
      have h := ht.length_eq
      simp only [ReductionTree.leaves, List.length_append, ReductionTree.length_leaves,
        List.length_singleton] at h
      omega
  | z :: y :: l, hp, _ => by
    have hz : ∀ x ∈ y :: l, x < z := fun x hx => (List.pairwise_cons.mp hp).1 x hx
    rw [Nat.card_congr (graftEquiv hz (List.cons_ne_nil y l)), Nat.card_prod,
      card_minFirstTree (List.pairwise_cons.mp hp).2 (List.cons_ne_nil y l),
      Nat.card_eq_fintype_card, Fintype.card_fin]
    simp only [List.length_cons]
    exact doubleFactorial_step _

/-- **The min-first form of a tree**, for every leaf type with a linear order and tree: a leaf is
its own form, and a node's is the node of its children's forms, the one with the smaller first
leaf first. -/
private def minFirst : ReductionTree ι → ReductionTree ι
  | .leaf x => .leaf x
  | .node a b =>
    if firstLeaf (minFirst b) < firstLeaf (minFirst a) then .node (minFirst b) (minFirst a)
    else .node (minFirst a) (minFirst b)

/-- `minFirst` keeps the leaves up to a permutation, for every leaf type with a linear order and
tree. -/
private theorem perm_minFirst : ∀ t : ReductionTree ι, (minFirst t).leaves.Perm t.leaves
  | .leaf _ => .refl _
  | .node a b => by
    simp only [minFirst]
    split
    · exact List.perm_append_comm.trans ((perm_minFirst a).append (perm_minFirst b))
    · exact (perm_minFirst a).append (perm_minFirst b)

/-- At a tree without repeated leaves, the first leaves of two children's `minFirst` differ, for
every leaf type with a linear order and trees `a`, `b`. -/
private theorem firstLeaf_minFirst_ne {a b : ReductionTree ι}
    (h : (ReductionTree.node a b).leaves.Nodup) :
    firstLeaf (minFirst a) ≠ firstLeaf (minFirst b) :=
  (List.nodup_append.mp h).2.2 _ ((perm_minFirst a).mem_iff.mp (firstLeaf_mem _)) _
    ((perm_minFirst b).mem_iff.mp (firstLeaf_mem _))

/-- `minFirst` of a tree without repeated leaves is min-first, for every leaf type with a linear
order and tree. -/
private theorem isMinFirst_minFirst :
    ∀ {t : ReductionTree ι}, t.leaves.Nodup → IsMinFirst (minFirst t)
  | .leaf _, _ => trivial
  | .node a b, h => by
    have hn := List.nodup_append.mp h
    have hne := firstLeaf_minFirst_ne h
    simp only [minFirst]
    split
    · next hlt => exact ⟨hlt, isMinFirst_minFirst hn.2.1, isMinFirst_minFirst hn.1⟩
    · next hlt =>
      exact ⟨lt_of_le_of_ne (not_lt.mp hlt) hne, isMinFirst_minFirst hn.1,
        isMinFirst_minFirst hn.2.1⟩

/-- A min-first tree is its own `minFirst`, for every leaf type with a linear order and tree. -/
private theorem minFirst_of_isMinFirst : ∀ {t : ReductionTree ι}, IsMinFirst t → minFirst t = t
  | .leaf _, _ => rfl
  | .node a b, ⟨hab, ha, hb⟩ => by
    rw [minFirst, minFirst_of_isMinFirst ha, minFirst_of_isMinFirst hb,
      ite_eq_right (not_lt.mpr hab.le)]

/-- `minFirst` keeps `canon`, for every leaf type with a linear order and tree:
`canon (minFirst t) = canon t`. -/
private theorem canon_minFirst : ∀ t : ReductionTree ι, canon (minFirst t) = canon t
  | .leaf _ => rfl
  | .node a b => by
    rw [minFirst]
    split
    · rw [canon_node_comm]
      exact canon_node_eq_iff.mpr (Or.inl ⟨canon_minFirst a, canon_minFirst b⟩)
    · exact canon_node_eq_iff.mpr (Or.inl ⟨canon_minFirst a, canon_minFirst b⟩)

/-- A tree whose `canon` is a leaf is that leaf, for every leaf type with a linear order, tree
and value. -/
private theorem eq_leaf_of_canon {t : ReductionTree ι} {x : ι} (h : canon t = .leaf x) :
    t = .leaf x := by
  cases t with
  | leaf _ => exact h
  | node a b =>
    simp only [canon] at h
    split at h <;> cases h

/-- **Trees with the same `canon` have the same `minFirst`**, for every leaf type with a linear
order and trees `s`, `t`, `s` without repeated leaves. -/
private theorem minFirst_eq_of_canon_eq :
    ∀ {s t : ReductionTree ι}, s.leaves.Nodup → canon s = canon t → minFirst s = minFirst t
  | .leaf _, _, _, h => by rw [eq_leaf_of_canon h.symm]
  | .node _ _, .leaf _, _, h => by cases eq_leaf_of_canon h
  | .node a b, .node c d, hn, h => by
    have hn' := List.nodup_append.mp hn
    have hne := firstLeaf_minFirst_ne hn
    rcases canon_node_eq_iff.mp h with ⟨h1, h2⟩ | ⟨h1, h2⟩
    · rw [minFirst, minFirst, minFirst_eq_of_canon_eq hn'.1 h1,
        minFirst_eq_of_canon_eq hn'.2.1 h2]
    · have e1 := minFirst_eq_of_canon_eq hn'.1 h1
      have e2 := minFirst_eq_of_canon_eq hn'.2.1 h2
      rw [minFirst, minFirst, e1, e2]
      rw [e1, e2] at hne
      rcases lt_trichotomy (firstLeaf (minFirst c)) (firstLeaf (minFirst d)) with hl | hl | hl
      · rw [ite_eq_left hl, ite_eq_right (not_lt.mpr hl.le)]
      · exact absurd hl.symm hne
      · rw [ite_eq_right (not_lt.mpr hl.le), ite_eq_left hl]

/-- **The canonical trees are the min-first trees**, for every `n`: over `Fin n` with each index
once, `minFirst` one way and `canon` back. -/
private def canonEquiv (n : ℕ) : CanonTree n ≃ MinFirstTree (List.finRange n) where
  toFun t := ⟨minFirst t.1, (perm_minFirst t.1).trans t.2.1,
    isMinFirst_minFirst (t.2.1.nodup_iff.mpr (List.nodup_finRange n))⟩
  invFun s := ⟨canon s.1, (perm_canon s.1).trans s.2.1, canon_canon s.1⟩
  left_inv t := Subtype.ext ((canon_minFirst t.1).trans t.2.2)
  right_inv s := Subtype.ext ((minFirst_eq_of_canon_eq
    (((perm_canon s.1).trans s.2.1).nodup_iff.mpr (List.nodup_finRange n))
    (canon_canon s.1)).trans (minFirst_of_isMinFirst s.2.2))

end Count

/-- **The number of canonical trees over `Fin n`**, for every `n ≥ 1`: `(2n - 3)‼` (`1` at
`n = 1`, with `ℕ`'s subtraction). Each class of trees up to swapping children has one tree whose
every node has the child with the smaller first leaf on the left (`canonEquiv`); removing the
greatest leaf from such a tree leaves one over the other leaves and one of its `2n - 3` places to
graft the leaf back (`graftEquiv`), so the count is `(2n - 3) * (2n - 5) * … * 1`. -/
theorem card_canonTree {n : ℕ} (hn : 1 ≤ n) : Nat.card (CanonTree n) = (2 * n - 3)‼ := by
  have e : MinFirstTree (List.finRange n) ≃ MinFirstTree (List.finRange n).reverse :=
    Equiv.subtypeEquivRight fun t =>
      Iff.and ⟨fun h => h.trans (List.reverse_perm _).symm, fun h => h.trans (List.reverse_perm _)⟩
        Iff.rfl
  rw [Nat.card_congr ((canonEquiv n).trans e),
    card_minFirstTree (List.pairwise_reverse.mpr (List.pairwise_lt_finRange n))
      (List.ne_nil_of_length_pos (by simp; omega)),
    List.length_reverse, List.length_finRange]

/-- **The number of IEEE sums of `n` distinct inputs**, for every IEEE format and `n ≥ 2`:
`(2n - 3)‼` functions up to NaN payloads; `card_sumFunction` with `card_canonTree`. -/
theorem card_sums {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {n : ℕ} (hn : 2 ≤ n) :
    Nat.card (SumFunction fmt n) = (2 * n - 3)‼ :=
  (card_sumFunction hfmt n).trans (card_canonTree (by omega))

end MojoProof.Float
