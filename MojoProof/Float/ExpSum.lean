import MojoProof.Float.Tree
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.MixedError
import FloatLib.Floats.Formats.BinaryInterchange.Transcendentals.CorrectlyRounded.Proof
import FloatLib.Numerics.MixedError.Elementary
import TorchLean.Verify.RuntimeApprox.TransformerBlock

/-!
# Exact maxima, max-subtracted exponential sums, softmax and log-softmax along any trees
(docs/proofs/float-reductions.md)

A stable softmax over `n` words `x` takes their maximum `m`, the terms `exp (x j - m)`, their
sum and each term divided by the sum. Here the maximum is any tree of FloatLib's
`Model.maximumNumber` (LLVM's `maxnum`), each term is FloatLib's correctly rounded exponential of
the rounded difference `Model.sub (x j) m` (`expTerm`), and the sum is any tree of `Model.add`
whose leaves are the `n` indices, each once (a loop, a butterfly or a block's halving tree).

Definitions: `expTerm`, the term words; `expSumErr`, the absolute error of the sum, and
`maskErr`, the same over the kept indices of a masked sum; `termErr` and `recipErr`, the relative
errors of a term and of the reciprocal of the sum; `lse` and `logSoftmax`, the
log-sum-exp `m + log s` and the log-softmax entry `(x j - m) - log s` with FloatLib's correctly
rounded logarithm of the sum `s`.

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
* `expTerm_negInf`, `maskSum_error` and `maskSoftmax_error`, masked inputs: a difference `-∞`
  gives the term `+0`; when the differences are finite on a set `U` of kept indices and `-∞`
  elsewhere, the sum approximates `Σ_{j ∈ U} exp (x j - m)` with the absolute error `maskErr`,
  and an entry at `j ∈ U` TorchLean's real softmax over the kept indices
  `TorchLean.TransformerBlock.softmax U x j`. `expSum_error` and `softmax_error` are their cases
  with every index kept.
* `softmaxRecip_error`, in every IEEE format, for every `n`, tree and set of kept indices, under
  `maskSoftmax_error`'s premises: the entry in the order `e_j * (1 / s)` (the reciprocal of the
  sum rounded, then the product) approximates the same real softmax, with the error of one more
  rounding (FloatLib's `BinaryInterchange.Model.mixedError_toReal_mul` on the term and the
  reciprocal).
* `lse_error` and `logSoftmax_error`, in every IEEE format, for every `n` and tree, under
  `softmax_error`'s premises: a finite `lse` approximates `log Σ_i exp (x i)` and a finite
  log-softmax entry `x j - log Σ_i exp (x i)`, with relative error `u` and an absolute error in
  `log Σ_i exp (x i - m)` and `-log (1 - expSumErr)` (FloatLib's `MixedError.trans_log`).

The exponential of a difference that is `-∞` is `+0`, a finite term, so the differences' finiteness
(or, for the masked statements, which differences are `-∞`) is a premise rather than a
consequence. TorchLean's roundoff theorem softmax_error
(TorchLean/Verify/RuntimeApprox/Roundoff/Softmax.lean) bounds the stable softmax of its configured
tensors, whose reductions are left folds; the statements here are about FloatLib's words and any
trees. Nothing is claimed when a result is infinite or a NaN. The instances are in
MojoProofTest/FloatStats.lean.
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

/-- The absolute error of `maskSum_error` for a sum along a tree of depth `d` of the terms of the
exact differences `y j = x j - m`, over the kept indices `U`:
`((1 + u) ^ d - 1) · Σ_{j ∈ U} exp (y j) +
(1 + u) ^ d · Σ_{j ∈ U} (((1 + u) · exp (u · |y j|) - 1) · exp (y j) + η)`. -/
noncomputable def maskErr {n : Nat} (U : Finset (Fin n)) (u η : ℝ) (d : Nat) (y : Fin n → ℝ) :
    ℝ :=
  ((1 + u) ^ d - 1) * ∑ j ∈ U, Real.exp (y j) +
    (1 + u) ^ d * ∑ j ∈ U, (((1 + u) * Real.exp (u * |y j|) - 1) * Real.exp (y j) + η)

/-- The absolute error of `expSum_error`: `maskErr` with every index kept,
`((1 + u) ^ d - 1) · Σ_j exp (y j) + (1 + u) ^ d · Σ_j (((1 + u) · exp (u · |y j|) - 1) · exp (y j)
+ η)`. -/
noncomputable def expSumErr {n : Nat} (u η : ℝ) (d : Nat) (y : Fin n → ℝ) : ℝ :=
  maskErr Finset.univ u η d y

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

/-- **A masked term.** In every format, for every budget, words `x`, word `m` and index `j`: if the
difference `Model.sub (x j) m` is `-∞` (infinite with its sign bit set, as for an input `-∞` less a
finite `m`), the term `expTerm b x m j` is the word `+0`: FloatLib's exponential of `-∞`. -/
theorem expTerm_negInf {ι : Type} (b : Certified.Budget) (x : ι → Model fmt) (m : Model fmt)
    (j : ι) (hi : (Model.sub (x j) m).isInfinite = true)
    (hn : (Model.sub (x j) m).signBit = true) : expTerm b x m j = Model.zero fmt false := by
  simp [expTerm, Model.Transcendentals.CorrectlyRounded.exp,
    Model.isNaN_eq_false_of_isInfinite_eq_true _ hi, hi, hn]

/-- **The masked exponential sum.** In every IEEE format, for every `n`, tree `t` whose leaves are
the indices `0, …, n - 1` up to order, budget, words `x`, word `m` and set `U` of kept indices: if
the difference `Model.sub (x j) m` is finite for every `j ∈ U` and `-∞` for every other `j` (a
masked input `-∞`), and the sum of the terms `expTerm b x m` by `Model.add` along `t` is finite,
the sum approximates `Σ_{j ∈ U} exp (x j - m)` with the absolute error
`maskErr U u η t.depth (x - m)`. The masked terms are `+0` (`expTerm_negInf`), exact zeros of the
sum; `sum_mixedError` with `expTerm_error` at the kept leaves. Nothing is claimed when the sum is
infinite or a NaN. -/
theorem maskSum_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (U : Finset (Fin n)) (hd : ∀ j ∈ U, (Model.sub (x j) m).isFinite = true)
    (hi : ∀ j ∉ U,
      (Model.sub (x j) m).isInfinite = true ∧ (Model.sub (x j) m).signBit = true)
    (h : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) :
    MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
      (∑ j ∈ U, Real.exp ((x j).toReal - m.toReal)) 0
      (maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
        fun j => (x j).toReal - m.toReal) := by
  have e : MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
      (∑ j, if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0) 0
      (((1 + Model.unitRoundoffAt fmt) ^ t.depth - 1) *
          ∑ j, |if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0| +
        (1 + Model.unitRoundoffAt fmt) ^ t.depth *
          ∑ j, ((if j ∈ U then (1 + Model.unitRoundoffAt fmt) *
              Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1 else 0) *
            |if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0| +
            if j ∈ U then Model.underflowErrorAt fmt else 0)) := by
    have e := sum_mixedError hfmt t (expTerm b x m) ht
      (w := fun j => if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0)
      (r := fun j => if j ∈ U then (1 + Model.unitRoundoffAt fmt) *
        Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1 else 0)
      (a := fun j => if j ∈ U then Model.underflowErrorAt fmt else 0)
      (fun j _ hj => by
        by_cases hU : j ∈ U
        · simpa only [hU, ite_true] using expTerm_error hfmt b x m j (hd j hU) hj
        · simp only [hU, ite_false]
          rw [expTerm_negInf b x m j (hi j hU).1 (hi j hU).2, Model.toReal_zero]
          exact MixedError.of_eq rfl) h
    simpa only [← Fin.sum_univ_def] using e
  have s1 : ∑ j, (if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0) =
      ∑ j ∈ U, Real.exp ((x j).toReal - m.toReal) := by
    rw [Finset.sum_ite_mem, Finset.univ_inter]
  have s2 : ∑ j, |if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0| =
      ∑ j ∈ U, Real.exp ((x j).toReal - m.toReal) :=
    calc _ = ∑ j, (if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0) :=
          Finset.sum_congr rfl fun j _ => by split_ifs <;> simp
      _ = _ := s1
  have s3 : ∑ j, ((if j ∈ U then (1 + Model.unitRoundoffAt fmt) *
          Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1 else 0) *
        |if j ∈ U then Real.exp ((x j).toReal - m.toReal) else 0| +
        if j ∈ U then Model.underflowErrorAt fmt else 0) =
      ∑ j ∈ U, (((1 + Model.unitRoundoffAt fmt) *
          Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1) *
        Real.exp ((x j).toReal - m.toReal) + Model.underflowErrorAt fmt) :=
    calc _ = ∑ j, (if j ∈ U then ((1 + Model.unitRoundoffAt fmt) *
            Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1) *
          Real.exp ((x j).toReal - m.toReal) + Model.underflowErrorAt fmt else 0) :=
          Finset.sum_congr rfl fun j _ => by split_ifs <;> simp
      _ = _ := by rw [Finset.sum_ite_mem, Finset.univ_inter]
  rw [s1, s2, s3] at e
  exact e

/-- **The exponential sum.** In every IEEE format, for every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, budget, words `x` and word `m`: if every difference
`Model.sub (x j) m` is finite and the sum of the terms `expTerm b x m` by `Model.add` along `t`
is finite, the sum approximates `Σ_j exp (x j - m)` with the absolute error
`expSumErr u η t.depth (x - m)`: `maskSum_error` with every index kept. Nothing is claimed when
the sum is infinite or a NaN. -/
theorem expSum_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (h : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) :
    MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
      (∑ j, Real.exp ((x j).toReal - m.toReal)) 0
      (expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
        fun j => (x j).toReal - m.toReal) :=
  maskSum_error hfmt t ht b x m Finset.univ (fun j _ => hd j)
    (fun j hj => absurd (Finset.mem_univ j) hj) h

/-- When `m`'s real value is the real value of some `x k` with `k ∈ U`, under `maskSum_error`'s
premises, the exact sum `Σ_{i ∈ U} exp (x i - m)` is at least `exp (x k - m) = 1`, so the sum's
absolute error `A` is a relative one: the sum word is within FloatLib's mixed error `(A, 0)` of it
(`MixedError.relative_of_le_abs`). -/
private theorem sum_rel (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (U : Finset (Fin n)) {k : Fin n} (hkU : k ∈ U)
    (hk : m.toReal = (x k).toReal) (hd : ∀ j ∈ U, (Model.sub (x j) m).isFinite = true)
    (hi : ∀ j ∉ U,
      (Model.sub (x j) m).isInfinite = true ∧ (Model.sub (x j) m).signBit = true)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) :
    1 ≤ ∑ i ∈ U, Real.exp ((x i).toReal - m.toReal) ∧
      MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
        (∑ i ∈ U, Real.exp ((x i).toReal - m.toReal))
        (maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
          fun j => (x j).toReal - m.toReal) 0 := by
  have h1 : 1 ≤ ∑ i ∈ U, Real.exp ((x i).toReal - m.toReal) :=
    calc (1 : ℝ) = Real.exp ((x k).toReal - m.toReal) := by rw [hk, sub_self, Real.exp_zero]
      _ ≤ _ := Finset.single_le_sum (f := fun i => Real.exp ((x i).toReal - m.toReal))
        (fun i _ => (Real.exp_pos _).le) hkU
  exact ⟨h1, ((maskSum_error hfmt t ht b x m U hd hi hs).relative_of_le_abs zero_lt_one
    (h1.trans (le_abs_self _))).mono (by simp) le_rfl⟩

/-- **The masked softmax entry.** In every IEEE format, for every `n`, tree `t` whose leaves are
the indices `0, …, n - 1` up to order, budget, words `x`, word `m`, set `U` of kept indices with
`m`'s real value the real value of some `x k`, `k ∈ U`, and index `j ∈ U`, with `A` the absolute
error `maskErr U u η t.depth (x - m)` of `maskSum_error`: if the difference `Model.sub (x i) m` is
finite for every `i ∈ U` and `-∞` for every other `i` (masked inputs `-∞`), `A < 1`, the sum `s`
of the terms along `t` is finite and the entry `Model.div (expTerm b x m j) s` is finite, the
entry approximates TorchLean's real softmax over the kept indices
`TorchLean.TransformerBlock.softmax U x j` with FloatLib's mixed error
`((1 + u) · ((r + A) / (1 - A)) + u, (1 + u) · η / (1 - A) + η)`,
`r = (1 + u) · exp (u · |x j - m|) - 1`. The exact sum is at least `exp (x k - m) = 1`, so its
absolute error is a relative one (`MixedError.relative_of_le_abs`); then FloatLib's
`Model.mixedError_toReal_div` and TorchLean's `softmax_eq_exp_sub_div`. Nothing is claimed when
the entry is infinite or a NaN. -/
theorem maskSoftmax_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (U : Finset (Fin n)) {k : Fin n} (hkU : k ∈ U)
    (hk : m.toReal = (x k).toReal) (hd : ∀ j ∈ U, (Model.sub (x j) m).isFinite = true)
    (hi : ∀ j ∉ U,
      (Model.sub (x j) m).isInfinite = true ∧ (Model.sub (x j) m).signBit = true)
    (hA : maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) (j : Fin n)
    (hj : j ∈ U)
    (h : (Model.div (expTerm b x m j)
      (t.eval (fun a b => Model.add a b) (expTerm b x m))).isFinite = true) :
    MixedError (Model.div (expTerm b x m j)
        (t.eval (fun a b => Model.add a b) (expTerm b x m))).toReal
      (TorchLean.TransformerBlock.softmax U (fun i => (x i).toReal) j)
      ((1 + Model.unitRoundoffAt fmt) *
        (((1 + Model.unitRoundoffAt fmt) *
            Real.exp (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal|) - 1 +
          maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal)) /
          (1 - maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal))) + Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) * (Model.underflowErrorAt fmt /
          (1 - maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
            (fun j => (x j).toReal - m.toReal))) + Model.underflowErrorAt fmt) := by
  obtain ⟨h1, er⟩ := sum_rel hfmt t ht b x m U hkU hk hd hi hs
  replace h1 : 1 ≤ |∑ i ∈ U, Real.exp ((x i).toReal - m.toReal)| := h1.trans (le_abs_self _)
  have ex := expTerm_error hfmt b x m j (hd j hj) (Model.isFinite_left_of_isFinite_div hfmt h)
  have hq := Model.mixedError_toReal_div hfmt hs h ex er hA
  rw [TorchLean.TransformerBlock.softmax_eq_exp_sub_div _ _ m.toReal]
  refine hq.mono le_rfl ?_
  set A := maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
    (fun j => (x j).toReal - m.toReal)
  have hle : Model.underflowErrorAt fmt /
      ((1 - A) * |∑ i ∈ U, Real.exp ((x i).toReal - m.toReal)|) ≤
        Model.underflowErrorAt fmt / (1 - A) :=
    div_le_div_of_nonneg_left ex.a_nonneg (by linarith) (le_mul_of_one_le_right (by linarith) h1)
  linarith [mul_le_mul_of_nonneg_left hle
    (by linarith [Model.unitRoundoffAt_pos fmt] : (0 : ℝ) ≤ 1 + Model.unitRoundoffAt fmt)]

/-- **The softmax entry.** In every IEEE format, for every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, budget, words `x`, word `m` whose real value is the real value
of some `x k` (the maximum of `max_exact`, or any input) and index `j`, with `A` the absolute error
`expSumErr u η t.depth (x - m)` of `expSum_error`: if every difference `Model.sub (x i) m` is
finite, `A < 1`, the sum `s` of the terms along `t` is finite and the entry
`Model.div (expTerm b x m j) s` is finite, the entry approximates TorchLean's real softmax
`TorchLean.TransformerBlock.softmax Finset.univ x j` of the real values with FloatLib's mixed
error `((1 + u) · ((r + A) / (1 - A)) + u, (1 + u) · η / (1 - A) + η)`, with
`r = (1 + u) · exp (u · |x j - m|) - 1` the term's relative error: `maskSoftmax_error` with every
index kept. Nothing is claimed when the entry is infinite or a NaN. -/
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
            (fun j => (x j).toReal - m.toReal))) + Model.underflowErrorAt fmt) :=
  maskSoftmax_error hfmt t ht b x m Finset.univ (Finset.mem_univ k) hk (fun j _ => hd j)
    (fun j hj => absurd (Finset.mem_univ j) hj) hA hs j (Finset.mem_univ j) h

/-- The relative error `(1 + u) · exp (u · |y|) - 1` of a correctly rounded exponential at the
difference `y` with unit roundoff `u`, as `expTerm_error` states it. -/
noncomputable def termErr (u y : ℝ) : ℝ := (1 + u) * Real.exp (u * |y|) - 1

/-- The relative error `(1 + u) · (A / (1 - A)) + u` of the rounded reciprocal `1 / s` of a sum
`s` with the relative error `A < 1`, with unit roundoff `u` (FloatLib's
`Model.mixedError_toReal_div` with an exact numerator `1`). -/
noncomputable def recipErr (u A : ℝ) : ℝ := (1 + u) * (A / (1 - A)) + u

/-- **The softmax entry in the order `e_j * (1 / s)`.** In every IEEE format, for every `n`, tree
`t` whose leaves are the indices `0, …, n - 1` up to order, budget, words `x`, word `m`, set `U`
of kept indices with `m`'s real value the real value of some `x k`, `k ∈ U`, and index `j ∈ U`,
with `A` the absolute error `maskErr U u η t.depth (x - m)` of `maskSum_error`,
`r = termErr u (x j - m)` and `q = recipErr u A`: under `maskSoftmax_error`'s premises on the
differences, `A < 1` and the finite sum `s` of the terms along `t`, if the entry
`Model.mul (expTerm b x m j) (Model.div 1 s)` (the reciprocal rounded, then the product) is
finite, it approximates TorchLean's real softmax over the kept indices
`TorchLean.TransformerBlock.softmax U x j` with FloatLib's mixed error
`((1 + u) · (r + q + r · q) + u, (1 + u) · ((1 + q) · η + (1 + r) · η · exp (x j - m) + η²) + η)`.
`U = Finset.univ` is the unmasked softmax of `softmax_error`. The reciprocal is FloatLib's
`Model.mixedError_toReal_div` at the exact `1` and the sum's relative error, the entry
`Model.mixedError_toReal_mul` with the term's error of `expTerm_error`; `1 / Σ ≤ 1` bounds the
term's absolute error carried by the reciprocal. Nothing is claimed when the entry is infinite or
a NaN. -/
theorem softmaxRecip_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) (U : Finset (Fin n)) {k : Fin n} (hkU : k ∈ U)
    (hk : m.toReal = (x k).toReal) (hd : ∀ j ∈ U, (Model.sub (x j) m).isFinite = true)
    (hi : ∀ j ∉ U,
      (Model.sub (x j) m).isInfinite = true ∧ (Model.sub (x j) m).signBit = true)
    (hA : maskErr U (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) (j : Fin n)
    (hj : j ∈ U)
    (h : (Model.mul (expTerm b x m j) (Model.div (Model.posOne fmt)
      (t.eval (fun a b => Model.add a b) (expTerm b x m)))).isFinite = true) :
    MixedError (Model.mul (expTerm b x m j) (Model.div (Model.posOne fmt)
        (t.eval (fun a b => Model.add a b) (expTerm b x m)))).toReal
      (TorchLean.TransformerBlock.softmax U (fun i => (x i).toReal) j)
      ((1 + Model.unitRoundoffAt fmt) *
        (termErr (Model.unitRoundoffAt fmt) ((x j).toReal - m.toReal) +
          recipErr (Model.unitRoundoffAt fmt) (maskErr U (Model.unitRoundoffAt fmt)
            (Model.underflowErrorAt fmt) t.depth (fun j => (x j).toReal - m.toReal)) +
          termErr (Model.unitRoundoffAt fmt) ((x j).toReal - m.toReal) *
            recipErr (Model.unitRoundoffAt fmt) (maskErr U (Model.unitRoundoffAt fmt)
              (Model.underflowErrorAt fmt) t.depth (fun j => (x j).toReal - m.toReal))) +
        Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) *
        ((1 + recipErr (Model.unitRoundoffAt fmt) (maskErr U (Model.unitRoundoffAt fmt)
              (Model.underflowErrorAt fmt) t.depth (fun j => (x j).toReal - m.toReal))) *
            Model.underflowErrorAt fmt +
          (1 + termErr (Model.unitRoundoffAt fmt) ((x j).toReal - m.toReal)) *
            Model.underflowErrorAt fmt * Real.exp ((x j).toReal - m.toReal) +
          Model.underflowErrorAt fmt * Model.underflowErrorAt fmt) +
        Model.underflowErrorAt fmt) := by
  obtain ⟨h1, er⟩ := sum_rel hfmt t ht b x m U hkU hk hd hi hs
  obtain ⟨he, hq⟩ := Model.isFinite_of_isFinite_mul hfmt h
  have ex := expTerm_error hfmt b x m j (hd j hj) he
  have ei := Model.mixedError_toReal_div hfmt hs hq
    (MixedError.of_eq (Model.toReal_posOne fmt) : MixedError (Model.posOne fmt).toReal 1 0 0) er hA
  have eo := Model.mixedError_toReal_mul hfmt h ex ei
  rw [TorchLean.TransformerBlock.softmax_eq_exp_sub_div _ _ m.toReal, div_eq_mul_one_div]
  simp only [zero_add, zero_div, mul_zero, Real.abs_exp] at ei eo
  unfold termErr recipErr
  refine eo.mono le_rfl ?_
  have hS0 : 0 < ∑ i ∈ U, Real.exp ((x i).toReal - m.toReal) := lt_of_lt_of_le one_pos h1
  have hS : |1 / ∑ i ∈ U, Real.exp ((x i).toReal - m.toReal)| ≤ 1 := by
    rw [abs_of_pos (one_div_pos.2 hS0)]
    exact (div_le_one hS0).2 h1
  have hu : (0 : ℝ) ≤ 1 + Model.unitRoundoffAt fmt := by linarith [Model.unitRoundoffAt_pos fmt]
  have key := mul_le_of_le_one_right (mul_nonneg (add_nonneg zero_le_one ei.r_nonneg) ex.a_nonneg)
    hS
  exact add_le_add (mul_le_mul_of_nonneg_left (by linarith [key]) hu) le_rfl

/-- The log-sum-exp word along a tree: `m + log s` by `Model.add`, with `s` the sum of the terms
`expTerm b x m` by `Model.add` along `t` and `log` FloatLib's correctly rounded logarithm
`Model.Transcendentals.CorrectlyRounded.log` with the search budget `c`. -/
def lse {n : Nat} (t : ReductionTree (Fin n)) (b c : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) : Model fmt :=
  Model.add m (Model.Transcendentals.CorrectlyRounded.log
    (t.eval (fun a b => Model.add a b) (expTerm b x m)) c)

/-- The log-softmax entry `j` along a tree, in the order of a three-pass kernel: `(x j - m) - log s`
by two `Model.sub`, with the sum `s` and the logarithm of `lse`. -/
def logSoftmax {n : Nat} (t : ReductionTree (Fin n)) (b c : Certified.Budget)
    (x : Fin n → Model fmt) (m : Model fmt) (j : Fin n) : Model fmt :=
  Model.sub (Model.sub (x j) m) (Model.Transcendentals.CorrectlyRounded.log
    (t.eval (fun a b => Model.add a b) (expTerm b x m)) c)

/-- The logarithm word of the sum, under `softmax_error`'s premises with `A < 1`: if it is finite,
it is within FloatLib's mixed error `(u, (1 + u) · -log (1 - A) + η)` of `log S`,
`S = Σ_i exp (x i - m)`; `log S` is nonnegative and equals `log Σ_i exp (x i) - m`. FloatLib's
`toReal_log_of_isFinite` and `MixedError.trans_log` with `sum_rel`. -/
private theorem log_rel (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b c : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) {k : Fin n} (hk : m.toReal = (x k).toReal)
    (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (hA : expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true)
    (hl : (Model.Transcendentals.CorrectlyRounded.log
      (t.eval (fun a b => Model.add a b) (expTerm b x m)) c).isFinite = true) :
    0 ≤ Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) ∧
      Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) =
        Real.log (∑ i, Real.exp (x i).toReal) - m.toReal ∧
      MixedError (Model.Transcendentals.CorrectlyRounded.log
          (t.eval (fun a b => Model.add a b) (expTerm b x m)) c).toReal
        (Real.log (∑ i, Real.exp ((x i).toReal - m.toReal))) (Model.unitRoundoffAt fmt)
        ((1 + Model.unitRoundoffAt fmt) *
            -Real.log (1 - expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt)
              t.depth (fun j => (x j).toReal - m.toReal)) + Model.underflowErrorAt fmt) := by
  obtain ⟨h1, er⟩ : 1 ≤ ∑ i, Real.exp ((x i).toReal - m.toReal) ∧
      MixedError (t.eval (fun a b => Model.add a b) (expTerm b x m)).toReal
        (∑ i, Real.exp ((x i).toReal - m.toReal))
        (expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
          fun j => (x j).toReal - m.toReal) 0 :=
    sum_rel hfmt t ht b x m Finset.univ (Finset.mem_univ k) hk (fun j _ => hd j)
      (fun j hj => absurd (Finset.mem_univ j) hj) hs
  have hpos := Model.Transcendentals.CorrectlyRounded.toReal_pos_of_isFinite_log hfmt hs hl
  have el := (Model.mixedError_toReal_of_eq_roundAt
    (Model.Transcendentals.CorrectlyRounded.toReal_log_of_isFinite hfmt hs hpos hl)).trans_log er
      (lt_of_lt_of_le one_pos h1) hA
  refine ⟨Real.log_nonneg h1, ?_, el⟩
  rw [show ∑ i, Real.exp ((x i).toReal - m.toReal) =
      (∑ i, Real.exp (x i).toReal) / Real.exp m.toReal by
        simp only [Real.exp_sub, ← Finset.sum_div],
    Real.log_div (Finset.sum_pos (fun i _ => Real.exp_pos _) ⟨k, Finset.mem_univ k⟩).ne'
      (Real.exp_pos _).ne', Real.log_exp]

/-- **The log-sum-exp.** In every IEEE format, for every `n`, tree `t` whose leaves are the indices
`0, …, n - 1` up to order, budgets `b`, `c`, words `x` and word `m` whose real value is the real
value of some `x k` (the maximum of `max_exact`, or any input), with `A` the absolute error
`expSumErr u η t.depth (x - m)` of `expSum_error` and `S = Σ_i exp (x i - m)`: if every
difference `Model.sub (x i) m` is finite, `A < 1`, the sum `s` of the terms along `t` is finite
and `lse t b c x m = m + log s` is finite, it approximates `log Σ_i exp (x i)` of the real values
with FloatLib's mixed error `(u, (1 + u) · (u · log S + (1 + u) · -log (1 - A) + η))`. The
logarithm is FloatLib's correctly rounded one; `MixedError.trans_log` turns the sum's relative
error into an absolute one on `log S`, then `Model.mixedError_toReal_add`. Nothing is claimed
when the result is infinite or a NaN. -/
theorem lse_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b c : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) {k : Fin n} (hk : m.toReal = (x k).toReal)
    (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (hA : expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true)
    (h : (lse t b c x m).isFinite = true) :
    MixedError (lse t b c x m).toReal (Real.log (∑ i, Real.exp (x i).toReal))
      (Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) *
        (Model.unitRoundoffAt fmt * Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) +
          ((1 + Model.unitRoundoffAt fmt) *
            -Real.log (1 - expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt)
              t.depth (fun j => (x j).toReal - m.toReal)) + Model.underflowErrorAt fmt))) := by
  obtain ⟨h0, heq, el⟩ :=
    log_rel hfmt t ht b c x m hk hd hA hs (Model.isFinite_of_isFinite_add hfmt h).2
  have e := Model.mixedError_toReal_add hfmt h (MixedError.of_eq rfl) el
  rw [show m.toReal + Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) =
    Real.log (∑ i, Real.exp (x i).toReal) by rw [heq]; ring] at e
  refine e.mono le_rfl (le_of_eq ?_)
  rw [abs_of_nonneg h0]
  ring

/-- **The log-softmax entry.** In every IEEE format, under `lse_error`'s premises with the entry
`logSoftmax t b c x m j = (x j - m) - log s` finite in place of `lse`'s: the entry approximates
`x j - log Σ_i exp (x i)` of the real values with FloatLib's mixed error
`(u, (1 + u) · (u · |x j - m| + (u · log S + (1 + u) · -log (1 - A) + η)))`. The difference
`x j - m` is rounded once (`Model.mixedError_toReal_sub`), the logarithm as in `lse_error`, then
`Model.mixedError_toReal_sub`. TorchLean's `TorchLean.Roundoff.CrossEntropy.log_probs_reference`
(TorchLean/Verify/RuntimeApprox/Roundoff/CrossEntropy.lean, not built here) states its reference in
the same real form. Nothing is claimed when the entry is infinite or a NaN. -/
theorem logSoftmax_error (hfmt : fmt.isIEEE = true) {n : Nat} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (b c : Certified.Budget) (x : Fin n → Model fmt)
    (m : Model fmt) {k : Fin n} (hk : m.toReal = (x k).toReal)
    (hd : ∀ j, (Model.sub (x j) m).isFinite = true)
    (hA : expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
      (fun j => (x j).toReal - m.toReal) < 1)
    (hs : (t.eval (fun a b => Model.add a b) (expTerm b x m)).isFinite = true) (j : Fin n)
    (h : (logSoftmax t b c x m j).isFinite = true) :
    MixedError (logSoftmax t b c x m j).toReal
      ((x j).toReal - Real.log (∑ i, Real.exp (x i).toReal)) (Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) *
        (Model.unitRoundoffAt fmt * |(x j).toReal - m.toReal| +
          (Model.unitRoundoffAt fmt * Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) +
            ((1 + Model.unitRoundoffAt fmt) *
              -Real.log (1 - expSumErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt)
                t.depth (fun j => (x j).toReal - m.toReal)) + Model.underflowErrorAt fmt)))) := by
  obtain ⟨h0, heq, el⟩ :=
    log_rel hfmt t ht b c x m hk hd hA hs (Model.isFinite_of_isFinite_sub hfmt h).2
  have ed : MixedError (Model.sub (x j) m).toReal ((x j).toReal - m.toReal)
      (Model.unitRoundoffAt fmt) 0 :=
    (Model.mixedError_toReal_sub hfmt (hd j) (MixedError.of_eq rfl) (MixedError.of_eq rfl)).mono
      le_rfl (le_of_eq (by ring))
  have e := Model.mixedError_toReal_sub hfmt h ed el
  rw [show (x j).toReal - m.toReal - Real.log (∑ i, Real.exp ((x i).toReal - m.toReal)) =
    (x j).toReal - Real.log (∑ i, Real.exp (x i).toReal) by rw [heq]; ring] at e
  refine e.mono le_rfl (le_of_eq ?_)
  rw [abs_of_nonneg h0]
  ring

end MojoProof.Float
