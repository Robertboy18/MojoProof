import MojoProof.Float.Tree
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.MixedError
import FloatLib.Floats.Formats.BinaryInterchange.Transcendentals.CorrectlyRounded.Proof
import FloatLib.Numerics.MixedError.Elementary
import TorchLean.Verify.RuntimeApprox.TransformerBlock

/-!
# Exact maxima, max-subtracted exponential sums and softmax along any trees
(docs/proofs/float-reductions.md)

A stable softmax over `n` words `x` takes their maximum `m`, the terms `exp (x j - m)`, their
sum and each term divided by the sum. Here the maximum is any tree of FloatLib's
`Model.maximumNumber` (LLVM's `maxnum`), each term is FloatLib's correctly rounded exponential of
the rounded difference `Model.sub (x j) m` (`expTerm`), and the sum is any tree of `Model.add`
whose leaves are the `n` indices, each once (a loop, a butterfly or a block's halving tree).

Definitions: `expTerm`, the term words; `expSumErr`, the absolute error of the sum.

Proved:
* `max_exact`, in every format, for every tree over any index type: on finite inputs the tree's
  maximum is finite, its real value is one of the inputs' and it is at least every input's.
* `expTerm_error`, in every IEEE format: a finite term of a finite difference approximates
  `exp (x j - m)` with FloatLib's mixed error `((1 + u) · exp (u · |x j - m|) - 1, η)`.
* `expSum_error`, in every IEEE format, for every `n` and tree: if every difference and the sum
  are finite, the sum approximates `Σ_j exp (x j - m)` with the absolute error `expSumErr`.
* `softmax_error`, in every IEEE format, for every `n` and tree: when `m`'s real value is one of
  the inputs' (as `max_exact` gives), a finite entry of a finite sum approximates TorchLean's real
  softmax `TorchLean.TransformerBlock.softmax Finset.univ x j`, if `expSumErr < 1`.

The exponential of a difference that is `-∞` is `+0`, a finite term, so the differences' finiteness
is a premise rather than a consequence. TorchLean's roundoff theorem softmax_error
(TorchLean/Verify/RuntimeApprox/Roundoff/Softmax.lean) bounds the stable softmax of its configured
tensors, whose reductions are left folds; the statements here are about FloatLib's words and any
trees. Nothing is claimed when a result is infinite or a NaN. The
instances are in MojoProofTest/FloatStats.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange

variable {fmt : FloatFormat}

/-- **The maximum is exact.** In every format, for every tree `t` over any index type and words
`x` finite at the leaves of `t`: the tree's maximum by FloatLib's `Model.maximumNumber` is finite,
its real value is the real value of some `x k` at a leaf `k`, and it is at least the real value of
every `x j` at a leaf. At finite operands `maximumNumber` is FloatLib's `maximum`, finite with the
real value `max` (FloatLib's `toReal_maximum_eq_max_of_isFinite`). -/
theorem max_exact {ι : Type} (t : ReductionTree ι) (x : ι → Model fmt)
    (hx : ∀ j ∈ t.leaves, (x j).isFinite = true) :
    (t.eval (fun a b => Model.maximumNumber a b) x).isFinite = true ∧
      (∃ k ∈ t.leaves, (t.eval (fun a b => Model.maximumNumber a b) x).toReal = (x k).toReal) ∧
      ∀ j ∈ t.leaves, (x j).toReal ≤ (t.eval (fun a b => Model.maximumNumber a b) x).toReal := by
  induction t with
  | leaf i =>
    exact ⟨hx i (List.mem_singleton_self i), ⟨i, List.mem_singleton_self i, rfl⟩,
      fun j hj => by rw [List.mem_singleton.1 hj]; exact le_rfl⟩
  | node a b ha hb =>
    simp only [ReductionTree.leaves, List.mem_append] at hx
    obtain ⟨fa, ⟨ka, hka, ea⟩, la⟩ := ha fun j hj => hx j (.inl hj)
    obtain ⟨fb, ⟨kb, hkb, eb⟩, lb⟩ := hb fun j hj => hx j (.inr hj)
    have hm : Model.maximumNumber (a.eval (fun a b => Model.maximumNumber a b) x)
        (b.eval (fun a b => Model.maximumNumber a b) x) =
        Model.maximum (a.eval (fun a b => Model.maximumNumber a b) x)
          (b.eval (fun a b => Model.maximumNumber a b) x) :=
      Model.maximumNumber_eq_maximum_of_not_isNaN _ _
        (Model.isNaN_eq_false_of_isFinite_eq_true _ fa)
        (Model.isNaN_eq_false_of_isFinite_eq_true _ fb)
    simp only [ReductionTree.eval, ReductionTree.leaves, List.mem_append, hm,
      Model.toReal_maximum_eq_max_of_isFinite _ _ fa fb]
    refine ⟨Model.isFinite_maximum _ _ fa fb, ?_, fun j hj => hj.elim
      (fun h => (la j h).trans (le_max_left _ _)) (fun h => (lb j h).trans (le_max_right _ _))⟩
    rcases max_choice (a.eval (fun a b => Model.maximumNumber a b) x).toReal
      (b.eval (fun a b => Model.maximumNumber a b) x).toReal with h | h
    · exact ⟨ka, .inl hka, h.trans ea⟩
    · exact ⟨kb, .inr hkb, h.trans eb⟩

/-- The term `j` of a max-subtracted exponential sum: FloatLib's correctly rounded exponential
`Model.Transcendentals.CorrectlyRounded.exp`, with the search budget `b`, of the rounded
difference `Model.sub (x j) m`. -/
def expTerm {ι : Type} (b : Certified.Budget) (x : ι → Model fmt) (m : Model fmt) (j : ι) :
    Model fmt :=
  Model.Transcendentals.CorrectlyRounded.exp (Model.sub (x j) m) b

/-- The absolute error of `expSum_error` for a sum along a tree of depth `d` of the terms of the
exact differences `y j = x j - m`: `((1 + u) ^ d - 1) · Σ_j exp (y j) +
(1 + u) ^ d · Σ_j (((1 + u) · exp (u · |y j|) - 1) · exp (y j) + η)`. -/
noncomputable def expSumErr {n : Nat} (u η : ℝ) (d : Nat) (y : Fin n → ℝ) : ℝ :=
  ((1 + u) ^ d - 1) * ∑ j, Real.exp (y j) +
    (1 + u) ^ d * ∑ j, (((1 + u) * Real.exp (u * |y j|) - 1) * Real.exp (y j) + η)

/-- **One term.** In every IEEE format, for every budget, words `x`, word `m` and index `j`: if
the difference `Model.sub (x j) m` and the term `expTerm b x m j` are finite, the term
approximates `exp (x j - m)` of the real values with FloatLib's mixed error
`((1 + u) · exp (u · |x j - m|) - 1, η)`: FloatLib's `toReal_exp_of_isFinite` (the term is the
rounded real exponential of the difference), `Model.mixedError_toReal_sub` and
`MixedError.trans_exp`. -/
theorem expTerm_error (hfmt : fmt.isIEEE = true) {ι : Type} (b : Certified.Budget)
    (x : ι → Model fmt) (m : Model fmt) (j : ι) (hd : (Model.sub (x j) m).isFinite = true)
    (h : (expTerm b x m j).isFinite = true) :
    MixedError (expTerm b x m j).toReal (Real.exp ((x j).toReal - m.toReal))
      ((1 + Model.unitRoundoffAt fmt) *
        Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1)
      (Model.underflowErrorAt fmt) := by
  have ed : MixedError (Model.sub (x j) m).toReal ((x j).toReal - m.toReal)
      (Model.unitRoundoffAt fmt) 0 :=
    (Model.mixedError_toReal_sub hfmt hd (MixedError.of_eq rfl) (MixedError.of_eq rfl)).mono
      le_rfl (le_of_eq (by ring))
  have he := Model.mixedError_toReal_of_eq_roundAt
    (Model.Transcendentals.CorrectlyRounded.toReal_exp_of_isFinite hfmt hd h)
  unfold expTerm
  simpa only [add_zero] using he.trans_exp ed

/-- **The exponential sum.** In every IEEE format, for every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, budget, words `x` and word `m`: if every difference
`Model.sub (x j) m` is finite and the sum of the terms `expTerm b x m` by `Model.add` along `t`
is finite, the sum approximates `Σ_j exp (x j - m)` with the absolute error
`expSumErr u η t.depth (x - m)`. `sum_mixedError` with `expTerm_error` at every leaf. Nothing is
claimed when the sum is infinite or a NaN. -/
theorem expSum_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (h : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) :
    MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
      (∑ j, Real.exp ((x j).toReal - m.toReal)) 0
      (expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
        fun j => (x j).toReal - m.toReal) := by
  have e := sum_mixedError hfmt t (expTerm b x m) ht
    (fun j _ hj => expTerm_error hfmt b x m j (hd j) hj) h
  rw [expSumErr]
  simpa only [Real.abs_exp, ← Fin.sum_univ_def] using e

/-- **The softmax entry.** In every IEEE format, for every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, budget, words `x`, word `m` whose real value is the real value
of some `x k` (the maximum of `max_exact`, or any input) and index `j`, with `A` the absolute error
`expSumErr u η t.depth (x - m)` of `expSum_error`: if every difference `Model.sub (x i) m` is
finite, `A < 1`, the sum `s` of the terms along `t` is finite and the entry
`Model.div (expTerm b x m j) s` is finite, the entry approximates TorchLean's real softmax
`TorchLean.TransformerBlock.softmax Finset.univ x j` of the real values with FloatLib's mixed
error `((1 + u) · ((r + A) / (1 - A)) + u, (1 + u) · η / (1 - A) + η)`, with
`r = (1 + u) · exp (u · |x j - m|) - 1` the term's relative error. The exact sum is at least
`exp (x k - m) = 1`, so its absolute error is a relative one (`MixedError.relative_of_le_abs`);
then FloatLib's `Model.mixedError_toReal_div` and TorchLean's `softmax_eq_exp_sub_div`. Nothing is
claimed when the entry is infinite or a NaN. -/
theorem softmax_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) {k : Fin n} (hk : m.toReal = (x k).toReal)
    (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (hA : expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) (j : Fin n)
    (h : (Model.div (expTerm b x m j)
      (t.eval (fun a b => Model.add a b) (expTerm b x m))).isFinite = true) :
    MixedError (Model.div (expTerm b x m j)
        (t.eval (fun a b => Model.add a b) (expTerm b x m))).toReal
      (TorchLean.TransformerBlock.softmax Finset.univ (fun i => (x i).toReal) j)
      ((1 + Model.unitRoundoffAt fmt) *
        (((1 + Model.unitRoundoffAt fmt) *
            Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1 +
          expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal)) /
          (1 - expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal))) + Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) * (Model.underflowErrorAt fmt /
          (1 - expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal))) + Model.underflowErrorAt fmt) := by
  have h1 : 1 ≤ |∑ i, Real.exp ((x i).toReal - m.toReal)| := by
    refine le_trans ?_ (le_abs_self _)
    calc (1 : ℝ) = Real.exp ((x k).toReal - m.toReal) := by rw [hk, sub_self, Real.exp_zero]
      _ ≤ _ := Finset.single_le_sum (f := fun i => Real.exp ((x i).toReal - m.toReal))
        (fun i _ => (Real.exp_pos _).le) (Finset.mem_univ k)
  have er : MixedError _ (∑ i, Real.exp ((x i).toReal - m.toReal))
      (expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
        fun j => (x j).toReal - m.toReal) 0 :=
    ((expSum_error hfmt t ht b x m hd hs).relative_of_le_abs zero_lt_one h1).mono (by simp)
      le_rfl
  have ex := expTerm_error hfmt b x m j (hd j) (Model.isFinite_left_of_isFinite_div hfmt h)
  have hq := Model.mixedError_toReal_div hfmt hs h ex er hA
  rw [TorchLean.TransformerBlock.softmax_eq_exp_sub_div _ _ m.toReal]
  refine hq.mono le_rfl ?_
  set A := expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
    (fun j => (x j).toReal - m.toReal)
  have hle : Model.underflowErrorAt fmt / ((1 - A) * |∑ i, Real.exp ((x i).toReal - m.toReal)|) ≤
      Model.underflowErrorAt fmt / (1 - A) :=
    div_le_div_of_nonneg_left ex.a_nonneg (by linarith) (le_mul_of_one_le_right (by linarith) h1)
  linarith [mul_le_mul_of_nonneg_left hle
    (by linarith [Model.unitRoundoffAt_pos fmt] : (0 : ℝ) ≤ 1 + Model.unitRoundoffAt fmt)]

end MojoProof.Float
