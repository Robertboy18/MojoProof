import MojoProof.Sem.FloatRel
import FloatLib.Floats.Formats.BinaryInterchange.Operations.FormatOf.Homogeneous
import FloatLib.Numerics.Reduction.Tree

/-!
# Addition up to NaN payloads, and trees up to swapped children (docs/proofs/float-reductions.md)

FloatLib's `Model.add` is commutative except in the payload of a NaN result, and a reduction tree
evaluated with an operation that is commutative up to an equivalence is determined, up to that
equivalence, by its form up to swapping the two children of nodes. This module states both, the
second through a canonical form `canon` of FloatLib's `ReductionTree`. FloatLib has neither; they
are items for its intake, `add_comm_nanEq` in FloatLib's namespace of `Model` and `canon`,
`canon_canon` and `eval_canon` in that of `ReductionTree`.

Definitions:
* `treeCmp s t`: the comparison of trees, for every leaf type with a linear order: two leaves by
  the leaf order, a leaf before a node, two nodes by their left children, then by their right
  ones. It is a total order on whole trees.
* `canon t`: `t` with the canonical forms of the two children of each node put in `treeCmp`'s
  order.

Proved, for every format, leaf type with a linear order and tree:
* `add_comm_nanEq`: `NaNEq (Model.add x y) (Model.add y x)`, with no premise.
* `canon_canon`, `perm_canon`, `depth_canon`: `canon` is idempotent, and keeps the leaves up to a
  permutation and the depth.
* `canon_node_comm`, `canon_node_eq_iff`: two trees have the same `canon` exactly when one is the
  other with the children of some of its nodes swapped.
* `eval_canon`: for every operation commutative up to an equivalence it respects, evaluating
  `canon t` is related to evaluating `t`; `eval_canon_nanEq` is its case at `Model.add` and
  `NaNEq`, and `eval_nanEq_of_canon` the consequence that two trees with the same `canon` agree up
  to NaN payloads on every input.

The converse, that two trees over the same distinct leaves whose sums agree up to NaN payloads on
every input have the same `canon`, in every IEEE format, is `MojoProof.Float.eval_add_eq_iff`
(MojoProof/Float/CanonIff.lean).
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem

/-- **IEEE addition commutes up to the NaN payload**, for every format and words `x`, `y`, with no
premise: `Model.add x y` and `Model.add y x` are equal or both NaNs. With a NaN operand both are
NaNs (`fbin_isNaN`). Otherwise both are FloatLib's specification `Model.Spec.add`: the rounded sum
of the operands' dyadic values at two finite operands (`Model.addDyadic_comm`), the infinite
operand at one infinite operand, and at two infinite operands the operand if their signs agree
(they are then the same word, `Model.eq_nativeOverflow_of_isInfinite`) and FloatLib's invalid
result if not. At two NaNs the sums need not be equal: `Model.chooseNaN2` returns the first of
two quiet NaNs, payload included (MojoProofTest/FloatCanon.lean, `nan_add32`). -/
theorem add_comm_nanEq {fmt : FloatFormat} (x y : Model fmt) :
    NaNEq (Model.add x y) (Model.add y x) := by
  by_cases h : x.isNaN = true ∨ y.isNaN = true
  · exact .inr ⟨fbin_isNaN (op := .fadd) rfl h, fbin_isNaN (op := .fadd) rfl h.symm⟩
  refine .inl ?_
  by_cases hxy : x = y
  · rw [hxy]
  simp only [not_or, Bool.not_eq_true] at h
  rw [Model.Proof.add_eq_spec, Model.Proof.add_eq_spec]
  unfold Model.Spec.add
  rw [Model.chooseNaN2_none_of_not_isNaN x y h.1 h.2,
    Model.chooseNaN2_none_of_not_isNaN y x h.2 h.1]
  cases hx : Model.toDyadic? x <;> cases hy : Model.toDyadic? y
  · simp only
    cases ix : x.isInfinite <;> cases iy : y.isInfinite <;>
      simp only [Bool.false_eq_true, ↓reduceIte]
    obtain ⟨-, ex⟩ := Model.eq_nativeOverflow_of_isInfinite ix
    obtain ⟨-, ey⟩ := Model.eq_nativeOverflow_of_isInfinite iy
    have hs : (x.signBit == y.signBit) = false := by
      rw [beq_eq_false_iff_ne]
      intro e
      exact hxy (ex.trans (by rw [e]; exact ey.symm))
    have hs' : (y.signBit == x.signBit) = false := by rw [Bool.beq_comm]; exact hs
    simp only [hs, hs', Bool.false_eq_true, ↓reduceIte]
  · simp [Model.isInfinite_eq_false_of_toDyadic?_some hy]
  · simp [Model.isInfinite_eq_false_of_toDyadic?_some hx]
  · simp only [Model.addDyadic_comm]

variable {ι : Type*}

/-- **The comparison of trees that `canon` orders children by**, for every leaf type with a
linear order: two leaves by `compare` of the leaf order, a leaf before a node, and two nodes by
their left children, then by their right ones (`Ordering.then`). It is a total order on trees:
`.eq` exactly at equal trees, and swapping the two trees swaps the result. -/
def treeCmp [LinearOrder ι] : ReductionTree ι → ReductionTree ι → Ordering
  | .leaf x, .leaf y => compare x y
  | .leaf _, .node _ _ => .lt
  | .node _ _, .leaf _ => .gt
  | .node a b, .node c d => (treeCmp a c).then (treeCmp b d)

/-- `treeCmp s t` is `.eq` exactly when `s = t`, for every leaf type with a linear order and
trees `s`, `t`. -/
private theorem treeCmp_eq_iff [LinearOrder ι] :
    ∀ {s t : ReductionTree ι}, treeCmp s t = .eq ↔ s = t
  | .leaf _, .leaf _ => by simp [treeCmp]
  | .leaf _, .node _ _ => by simp [treeCmp]
  | .node _ _, .leaf _ => by simp [treeCmp]
  | .node _ _, .node _ _ => by simp [treeCmp, Ordering.then_eq_eq, treeCmp_eq_iff]

/-- Swapping the two trees swaps `treeCmp`'s result, for every leaf type with a linear order and
trees `s`, `t`. -/
private theorem treeCmp_swap [LinearOrder ι] :
    ∀ s t : ReductionTree ι, (treeCmp s t).swap = treeCmp t s
  | .leaf _, .leaf _ => by simp [treeCmp, ← Std.OrientedCmp.eq_swap]
  | .leaf _, .node _ _ => rfl
  | .node _ _, .leaf _ => rfl
  | .node _ _, .node _ _ => by simp [treeCmp, Ordering.swap_then, treeCmp_swap]

/-- **The canonical form of a tree up to swapping the children of nodes**, for every leaf type
with a linear order and every tree: a leaf is its own form, and a node's is the node of its two
children's forms, the greater one in `treeCmp`'s order second. Two trees have the same `canon`
exactly when one is the other with the two children of some of its nodes swapped
(`canon_node_comm`, `canon_node_eq_iff`; a leaf's `canon` is the leaf and a node's is a node).
The children are ordered as whole trees by `treeCmp`, a total order, so this holds at every tree,
repeated leaves included; their least leaves or their leaf lists would tie at two different
children with the same leaves (`a + (b + c)` and `(a + b) + c` under one node), and the form
would then depend on the order the two were given in. -/
def canon [LinearOrder ι] : ReductionTree ι → ReductionTree ι
  | .leaf x => .leaf x
  | .node a b =>
    if treeCmp (canon a) (canon b) = .gt then .node (canon b) (canon a)
    else .node (canon a) (canon b)

variable [LinearOrder ι]

/-- **Swapping a node's children keeps `canon`**, for every leaf type with a linear order and
trees `a`, `b`: `canon (node a b) = canon (node b a)`. -/
theorem canon_node_comm (a b : ReductionTree ι) : canon (.node a b) = canon (.node b a) := by
  simp only [canon]
  have hs := treeCmp_swap (canon a) (canon b)
  cases h : treeCmp (canon a) (canon b)
  · rw [h] at hs; simp [← hs, Ordering.swap]
  · rw [treeCmp_eq_iff] at h; simp [h]
  · rw [h] at hs; simp [← hs, Ordering.swap]

/-- **When two nodes have the same `canon`**, for every leaf type with a linear order and trees
`a`, `b`, `a'`, `b'`: `canon (node a b) = canon (node a' b')` exactly when `a` and `b` have the
canonical forms of `a'` and `b'`, or of `b'` and `a'`. -/
theorem canon_node_eq_iff {a b a' b' : ReductionTree ι} :
    canon (.node a b) = canon (.node a' b') ↔
      canon a = canon a' ∧ canon b = canon b' ∨ canon a = canon b' ∧ canon b = canon a' := by
  constructor
  · intro h
    simp only [canon] at h
    split at h <;> split at h <;> simp only [ReductionTree.node.injEq] at h <;>
      simp [h.1, h.2]
  · rintro (⟨h1, h2⟩ | ⟨h1, h2⟩)
    · simp only [canon, h1, h2]
    · rw [canon_node_comm]
      simp only [canon, h1, h2]

/-- **`canon` is idempotent**, for every leaf type with a linear order and tree `t`:
`canon (canon t) = canon t`. -/
theorem canon_canon : ∀ t : ReductionTree ι, canon (canon t) = canon t
  | .leaf _ => rfl
  | .node a b => by
    have ha := canon_canon a
    have hb := canon_canon b
    by_cases h : treeCmp (canon a) (canon b) = .gt
    · have h' : treeCmp (canon b) (canon a) ≠ .gt := by
        rw [← treeCmp_swap, h]
        decide
      simp only [canon, h, h', ha, hb, ↓reduceIte]
    · simp only [canon, h, ha, hb, ↓reduceIte]

/-- **`canon` keeps the leaves up to a permutation**, for every leaf type with a linear order and
tree `t`: `(canon t).leaves` is a permutation of `t.leaves`. -/
theorem perm_canon : ∀ t : ReductionTree ι, (canon t).leaves.Perm t.leaves
  | .leaf _ => .refl _
  | .node a b => by
    unfold canon
    split
    · exact ((perm_canon b).append (perm_canon a)).trans List.perm_append_comm
    · exact (perm_canon a).append (perm_canon b)

/-- **`canon` keeps the depth**, for every leaf type with a linear order and tree `t`:
`(canon t).depth = t.depth`. -/
theorem depth_canon : ∀ t : ReductionTree ι, (canon t).depth = t.depth
  | .leaf _ => rfl
  | .node a b => by
    unfold canon
    split <;> simp only [ReductionTree.depth, depth_canon a, depth_canon b, max_comm]

/-- **Evaluating the canonical tree**, for every carrier `β`, operation `f`, equivalence `R` such
that `f x y` is related to `f y x` (`hc`) and `f` maps related operands to related results
(`hf`), every leaf type with a linear order, values `v` and tree `t`: `(canon t).eval f v` is
related to `t.eval f v`. -/
theorem eval_canon {β : Type*} {R : β → β → Prop} {f : β → β → β} (hR : Equivalence R)
    (hc : ∀ x y, R (f x y) (f y x)) (hf : ∀ {x x' y y'}, R x x' → R y y' → R (f x y) (f x' y'))
    (v : ι → β) (t : ReductionTree ι) : R ((canon t).eval f v) (t.eval f v) := by
  induction t with
  | leaf _ => exact hR.refl _
  | node a b iha ihb =>
    unfold canon
    split
    · exact hR.trans (hf ihb iha) (hc _ _)
    · exact hf iha ihb

/-- **The canonical tree's IEEE sum**, for every format, leaf type with a linear order, values `v`
and tree `t`: `(canon t).eval Model.add v` and `t.eval Model.add v` are equal or both NaNs.
`eval_canon` at `NaNEq`, with `add_comm_nanEq` and `NaNEq.op` at `fadd`. -/
theorem eval_canon_nanEq {fmt : FloatFormat} (v : ι → Model fmt) (t : ReductionTree ι) :
    NaNEq ((canon t).eval (fun x y => Model.add x y) v) (t.eval (fun x y => Model.add x y) v) :=
  eval_canon (GPUProof.UpToNaN.equivalence _) add_comm_nanEq (NaNEq.op (op := .fadd) rfl) v t

/-- **Trees with the same `canon` have the same IEEE sums up to NaN payloads**, for every format,
leaf type with a linear order and trees `t`, `t'` with `canon t = canon t'`, at every values `v`:
`t.eval Model.add v` and `t'.eval Model.add v` are equal or both NaNs (`eval_canon_nanEq` at both
trees). It is one direction of the characterization of the trees whose IEEE sums agree; the other
is not proved. -/
theorem eval_nanEq_of_canon {fmt : FloatFormat} {t t' : ReductionTree ι}
    (h : canon t = canon t') (v : ι → Model fmt) :
    NaNEq (t.eval (fun x y => Model.add x y) v) (t'.eval (fun x y => Model.add x y) v) :=
  (GPUProof.UpToNaN.equivalence _).trans ((GPUProof.UpToNaN.equivalence _).symm
    (eval_canon_nanEq v t)) (h ▸ eval_canon_nanEq v t')

end MojoProof.Float
