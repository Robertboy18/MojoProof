import FloatLib.Numerics.Reduction.Error
import FloatLib.Floats.Formats.BinaryInterchange.Reduction.Tree

/-!
# Float bounds of reductions along any tree (docs/proofs/float-reductions.md)

A reduction a kernel computes in some order, by a loop, a warp's butterfly or a block's halving
loop through shared memory, is the evaluation of a FloatLib `ReductionTree` of the input indices.
This module states the bounds once for every tree, through FloatLib's depth bounds, and the two
constructions the kernels' reductions are built from.

Definitions:
* `graft t f`: the tree `t` with each leaf `j` replaced by the tree `f j` (a reduction of
  reductions). FloatLib has no such operation.
* `roundsTree r ps c` and `rounds combine r ps v c`: rounds of a per-cell step over cells numbered
  by `Nat`. In round `p`, cell `c`'s new value is the evaluation of the tree `r p c` (a tree of
  cell numbers) at the old values. A block's shared-memory halving round is such a step.

Proved, for every carrier and combining operation:
* `eval_graft`, `leaves_graft`, `depth_graft`; `leaves_graft_range`:
  a tree over `W` blocks of `b` consecutive indices each has the indices below `W * b` as leaves,
  each once.
* `eval_roundsTree`: cell `c`'s value after the rounds is the evaluation of `roundsTree r ps c`.

Proved, in every IEEE format, for every tree over any index type:
* `finiteEval_of_isFinite`, `isFinite_of_mem_leaves`: a tree of FloatLib's `Model.add` with a
  finite root has every node's sum finite (FloatLib's `Model.ReductionTree.FiniteEval`), and
  every leaf finite.
* `eval_error`: for every carrier, FloatLib's `ReductionTree.abs_eval_sub_exact_le_depth` with
  the exact sums over any list `S` the leaves are a permutation of.
* `sum_error`: if the tree's sum of words is finite, every input is finite and the sum is within
  `((1 + u) ^ depth - 1) · Σ |v j|` of `Σ v j`, with `u` FloatLib's unit roundoff.
* `sum_mixedError`: with inputs that approximate exact reals with FloatLib `MixedError`s, the sum
  has the absolute error `((1 + u) ^ depth - 1) · Σ |w j| + (1 + u) ^ depth · Σ (r j |w j| + a j)`
  against `Σ w j`, the tree form of FloatLib's `Model.mixedError_toReal_foldl_add_absolute`.

Nothing is claimed about a sum that is infinite or a NaN. The instances are in
MojoProofTest/FloatTree.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange

/-! ## Grafting trees -/

/-- The tree `t` with each leaf `j` replaced by the tree `f j`: the schedule of a reduction of the
results of the reductions `f j`, combined along `t`. -/
def graft {α β : Type} : ReductionTree α → (α → ReductionTree β) → ReductionTree β
  | .leaf x, f => f x
  | .node a b, f => .node (graft a f) (graft b f)

/-- For every carrier, combining operation and trees: evaluating `graft t f` is evaluating `t` at
the values of the trees `f j`. -/
theorem eval_graft {α β γ : Type} (t : ReductionTree α) (f : α → ReductionTree β)
    (combine : γ → γ → γ) (value : β → γ) :
    (graft t f).eval combine value = t.eval combine fun j => (f j).eval combine value := by
  induction t with
  | leaf x => rfl
  | node a b ha hb => simp only [graft, ReductionTree.eval, ha, hb]

/-- For all trees, the leaves of `graft t f` are the leaves of the trees `f j`, for the leaves `j`
of `t` in order. -/
theorem leaves_graft {α β : Type} (t : ReductionTree α) (f : α → ReductionTree β) :
    (graft t f).leaves = t.leaves.flatMap fun j => (f j).leaves := by
  induction t with
  | leaf x => simp [graft, ReductionTree.leaves]
  | node a b ha hb => simp [graft, ReductionTree.leaves, ha, hb, List.flatMap_append]

/-- For all trees such that every tree `f j` at a leaf `j` of `t` has depth `d`, `graft t f` has
depth `t.depth + d`. -/
theorem depth_graft {α β : Type} (t : ReductionTree α) (f : α → ReductionTree β) {d : Nat}
    (h : ∀ j ∈ t.leaves, (f j).depth = d) : (graft t f).depth = t.depth + d := by
  induction t with
  | leaf x => simpa [graft, ReductionTree.depth] using h x (List.mem_singleton_self x)
  | node a b ha hb =>
    simp only [ReductionTree.leaves, List.mem_append] at h
    simp only [graft, ReductionTree.depth, ha fun j hj => h j (.inl hj),
      hb fun j hj => h j (.inr hj)]
    omega

/-- **Blocks of consecutive indices.** For every tree `t` whose leaves are a permutation of
`0, …, W - 1` and trees `f w` whose leaves, for each `w < W`, are a permutation of
`b·w, …, b·w + b - 1`: the leaves of `graft t f` are a permutation of `0, …, W·b - 1`, each index
once. -/
theorem leaves_graft_range (t : ReductionTree Nat) (f : Nat → ReductionTree Nat) {W b : Nat}
    (ht : t.leaves.Perm (List.range W))
    (hf : ∀ w < W, (f w).leaves.Perm ((List.range b).map (b * w + ·))) :
    (graft t f).leaves.Perm (List.range (W * b)) := by
  have hr : ∀ W, ((List.range W).flatMap fun w => (List.range b).map (b * w + ·)) =
      List.range (W * b) := by
    intro W
    induction W with
    | zero => simp
    | succ W ih =>
      rw [List.range_succ, List.flatMap_append, ih, Nat.succ_mul, List.range_add]
      simp [Nat.mul_comm b W]
  rw [leaves_graft, ← hr W]
  exact (ht.flatMap_right _).trans
    (List.Perm.flatMap_left _ fun w hw => hf w (List.mem_range.1 hw))

/-! ## Rounds over cells -/

/-- The tree of cell `c` after the rounds `ps`, first to last, of cell numbers at the values
before the first round. With no rounds, it is the leaf `c`; after the rounds `p :: ps`, it is the
tree after the later rounds `ps` with each cell `c'` replaced by the first round's tree `r p c'`. -/
def roundsTree {ρ : Type} (r : ρ → Nat → ReductionTree Nat) : List ρ → Nat → ReductionTree Nat
  | [], c => .leaf c
  | p :: ps, c => graft (roundsTree r ps c) (r p)

/-- The cells' values after the rounds `ps`, first to last: in round `p`, cell `c`'s new value is
the evaluation of `r p c` with `combine` at the values before the round. -/
def rounds {ρ β : Type} (combine : β → β → β) (r : ρ → Nat → ReductionTree Nat) (ps : List ρ)
    (v : Nat → β) : Nat → β :=
  ps.foldl (fun w p c => (r p c).eval combine w) v

/-- For every carrier, combining operation, step `r`, rounds `ps`, values and cell `c`: cell `c`'s
value after the rounds is the evaluation of its tree `roundsTree r ps c` at the values. -/
theorem eval_roundsTree {ρ β : Type} (combine : β → β → β) (r : ρ → Nat → ReductionTree Nat)
    (ps : List ρ) (v : Nat → β) (c : Nat) :
    (roundsTree r ps c).eval combine v = rounds combine r ps v c := by
  induction ps generalizing v with
  | nil => rfl
  | cons p ps ih =>
    rw [roundsTree, eval_graft, ih]
    rfl

/-! ## Finite sums of words -/

/-- In every IEEE format, for every tree of words: if the tree's sum by FloatLib's `Model.add` is
finite, every node's sum is finite (FloatLib's `Model.ReductionTree.FiniteEval`), because a finite
IEEE sum has finite operands (`Model.isFinite_of_isFinite_add`). -/
theorem finiteEval_of_isFinite {fmt : FloatFormat} (hfmt : fmt.isIEEE = true)
    (t : ReductionTree (Model fmt))
    (h : (t.eval (fun x y => Model.add x y) id).isFinite = true) :
    Model.ReductionTree.FiniteEval t := by
  induction t with
  | leaf x => exact h
  | node a b ha hb =>
    have hab := Model.isFinite_of_isFinite_add hfmt h
    exact ⟨ha hab.1, hb hab.2, h⟩

/-- In every format, every leaf of a tree with FloatLib's `Model.ReductionTree.FiniteEval` is
finite. -/
theorem isFinite_of_mem_leaves {fmt : FloatFormat} (t : ReductionTree (Model fmt))
    (h : Model.ReductionTree.FiniteEval t) : ∀ x ∈ t.leaves, x.isFinite = true := by
  induction t with
  | leaf x =>
    intro y hy
    rw [ReductionTree.leaves, List.mem_singleton] at hy
    exact hy ▸ h
  | node a b ha hb =>
    intro y hy
    rw [ReductionTree.leaves, List.mem_append] at hy
    exact hy.elim (ha h.1 y) (hb h.2.1 y)

/-- **Any tree within FloatLib's depth bound.** For every carrier, combining operation, values
`v`, map `interpret` to the reals, `u ≥ 0`, tree `t` over any index type and list `S` such that
the leaves of `t` are a permutation of `S`: if every combination at a node of `t` is within
`u · (|x| + |y|)` of the exact sum of its operands `x`, `y`, the tree's value is within
`((1 + u) ^ t.depth - 1) · Σ_{j∈S} |interpret (v j)|` of `Σ_{j∈S} interpret (v j)`: FloatLib's
`abs_eval_sub_exact_le_depth` with the sums over `S`. -/
theorem eval_error {β ι : Type} (combine : β → β → β) (v : ι → β) (interpret : β → ℝ)
    (u : ℝ) (hu : 0 ≤ u) (t : ReductionTree ι) {S : List ι} (hp : t.leaves.Perm S)
    (h : t.AllNodes combine v (fun x y =>
      |interpret (combine x y) - (interpret x + interpret y)| ≤
        u * (|interpret x| + |interpret y|))) :
    |interpret (t.eval combine v) - (S.map (interpret ∘ v)).sum| ≤
      ((1 + u) ^ t.depth - 1) * (S.map fun j => |interpret (v j)|).sum := by
  have e := t.abs_eval_sub_exact_le_depth combine v interpret u hu h
  rw [ReductionTree.eval_add_eq_sum, (hp.map _).sum_eq, ReductionTree.sumAbs,
    ReductionTree.eval_add_eq_sum, (hp.map _).sum_eq] at e
  exact e

/-- **Any tree of IEEE additions.** In every IEEE format, for every tree `t` over any index type,
list `S` such that the leaves of `t` are a permutation of `S`, and words `v`: if the tree's sum
`t.eval Model.add v` is finite, then every `v j` with `j ∈ S` is finite, and the sum is within
`((1 + u) ^ t.depth - 1) · Σ_{j∈S} |v j|` of `Σ_{j∈S} v j`, the real values of the words, with
`u` FloatLib's unit roundoff `Model.unitRoundoffAt fmt`. FloatLib's
`Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth` with `finiteEval_of_isFinite`. Nothing is
claimed when the sum is infinite or a NaN. -/
theorem sum_error {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {ι : Type}
    (t : ReductionTree ι) (v : ι → Model fmt) {S : List ι} (hp : t.leaves.Perm S)
    (h : (t.eval (fun x y => Model.add x y) v).isFinite = true) :
    (∀ j ∈ S, (v j).isFinite = true) ∧
      |(t.eval (fun x y => Model.add x y) v).toReal - (S.map fun j => (v j).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt fmt) ^ t.depth - 1) *
          (S.map fun j => |(v j).toReal|).sum := by
  have hr : (t.map v).eval (fun x y => Model.add x y) id =
      t.eval (fun x y => Model.add x y) v := by
    rw [ReductionTree.eval_map]
    rfl
  have hF := finiteEval_of_isFinite hfmt _ (hr ▸ h)
  refine ⟨fun j hj => isFinite_of_mem_leaves _ hF _ ?_, ?_⟩
  · rw [ReductionTree.leaves_map]
    exact List.mem_map_of_mem (hp.mem_iff.2 hj)
  · have e := Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth _ hfmt hF
    rw [hr, ReductionTree.leaves_map, ReductionTree.depth_map, ReductionTree.sumAbs,
      ReductionTree.eval_map, ReductionTree.eval_add_eq_sum, List.map_map,
      (hp.map _).sum_eq, (hp.map _).sum_eq] at e
    exact e

/-- **Any tree of IEEE additions of approximate inputs.** In every IEEE format, for every tree `t`
over any index type, list `S` such that the leaves of `t` are a permutation of `S`, words `v` and
reals `w`, `r`, `a` such that each finite `v j`, `j ∈ S`, approximates `w j` with FloatLib's mixed
error `(r j, a j)`: if the tree's sum is finite, it approximates `Σ_{j∈S} w j` with the absolute
error `((1 + u) ^ t.depth - 1) · Σ_{j∈S} |w j| + (1 + u) ^ t.depth · Σ_{j∈S} (r j · |w j| + a j)`,
`u` FloatLib's unit roundoff. The tree form of FloatLib's
`Model.mixedError_toReal_foldl_add_absolute`, with the depth for the number of additions. -/
theorem sum_mixedError {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {ι : Type}
    (t : ReductionTree ι) (v : ι → Model fmt) {S : List ι} (hp : t.leaves.Perm S)
    {w r a : ι → ℝ}
    (hv : ∀ j ∈ S, (v j).isFinite = true → MixedError (v j).toReal (w j) (r j) (a j))
    (h : (t.eval (fun x y => Model.add x y) v).isFinite = true) :
    MixedError (t.eval (fun x y => Model.add x y) v).toReal (S.map w).sum 0
      (((1 + Model.unitRoundoffAt fmt) ^ t.depth - 1) * (S.map fun j => |w j|).sum +
        (1 + Model.unitRoundoffAt fmt) ^ t.depth * (S.map fun j => r j * |w j| + a j).sum) := by
  obtain ⟨hf, e⟩ := sum_error hfmt t v hp h
  have key : ∀ L : List ι, (∀ j ∈ L, |(v j).toReal - w j| ≤ r j * |w j| + a j) →
      |(L.map fun j => (v j).toReal).sum - (L.map w).sum| ≤
          (L.map fun j => r j * |w j| + a j).sum ∧
        (L.map fun j => |(v j).toReal|).sum ≤
          (L.map fun j => |w j|).sum + (L.map fun j => r j * |w j| + a j).sum := by
    intro L
    induction L with
    | nil => simp
    | cons j L ih =>
      intro hL
      obtain ⟨h1, h2⟩ := ih fun i hi => hL i (List.mem_cons_of_mem _ hi)
      have hj := hL j List.mem_cons_self
      have h3 := abs_add_le ((v j).toReal - w j)
        ((L.map fun j => (v j).toReal).sum - (L.map w).sum)
      have h4 := abs_sub_abs_le_abs_sub (v j).toReal (w j)
      simp only [List.map_cons, List.sum_cons]
      refine ⟨?_, by linarith⟩
      rw [show (v j).toReal + (L.map fun j => (v j).toReal).sum - (w j + (L.map w).sum) =
        ((v j).toReal - w j) + ((L.map fun j => (v j).toReal).sum - (L.map w).sum) by ring]
      linarith
  obtain ⟨k1, k2⟩ := key S fun j hj => (hv j hj (hf j hj)).bound
  have hγ : 0 ≤ (1 + Model.unitRoundoffAt fmt) ^ t.depth - 1 :=
    sub_nonneg.2 (one_le_pow₀ (by linarith [Model.unitRoundoffAt_pos fmt]))
  refine MixedError.of_abs_sub_le ?_
  calc _ ≤ |(t.eval (fun x y => Model.add x y) v).toReal - (S.map fun j => (v j).toReal).sum| +
        |(S.map fun j => (v j).toReal).sum - (S.map w).sum| := abs_sub_le _ _ _
    _ ≤ ((1 + Model.unitRoundoffAt fmt) ^ t.depth - 1) *
          ((S.map fun j => |w j|).sum + (S.map fun j => r j * |w j| + a j).sum) +
        (S.map fun j => r j * |w j| + a j).sum :=
      add_le_add (e.trans (mul_le_mul_of_nonneg_left k2 hγ)) k1
    _ = _ := by ring

end MojoProof.Float
