import MojoProof.Float.Tree
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.MixedError
import TorchLean.Tensor.Statistics.Real

/-!
# Two-pass mean and variance along any trees (docs/proofs/float-reductions.md)

The two-pass statistics of `n` words `x`: the first pass sums the inputs along a tree `t₁` and
divides by a word `N` that denotes `n` (`mean`); the second subtracts that mean word from each
input, squares each difference, sums the squares along a tree `t₂` and divides by `N`
(`variance`). All operations are FloatLib's IEEE `Model.add`, `Model.sub`, `Model.mul` and
`Model.div`; the trees are any trees whose leaves are the `n` indices, each once, so a loop, a
butterfly or a block's halving tree (MojoProof/Float/Halve.lean) is a case.

Definitions: `mean`, `variance`, the words; `meanErr`, `devErr`, `varErr`, the absolute errors of
the mean, of each difference and of the variance.

Proved, in every IEEE format, for every `n`, trees and inputs:
* `mean_error`: if the mean word is finite, every input is finite and the mean is within FloatLib's
  `MixedError` with relative error `u` and absolute error `meanErr` of the exact mean
  `𝔼 j, x j` (Mathlib's `Finset.expect`).
* `var_error`: if the variance word is finite, it is within `MixedError` with relative error `u`
  and absolute error `varErr` of TorchLean's population variance `TorchLean.var` of the inputs'
  real values.

`𝔼` and `TorchLean.var` are the statistics of TorchLean's real layer norm
`TorchLean.TransformerBlock.layerNorm`. TorchLean's own two-pass analysis
`TorchLean.TransformerBlock.Arithmetic.sqrt_sum_sq_layerNorm_sub_le` bounds the whole layer norm
for an abstract rounding of reals whose sums are indexed by their length; the statements here are
about FloatLib's words and any trees, and stop at the two statistics. Nothing is claimed when a
result is infinite or a NaN. The instances are in MojoProofTest/FloatStats.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
open scoped BigOperators

variable {fmt : FloatFormat} {n : Nat}

/-- The first pass's mean word: the words `x` summed by FloatLib's `Model.add` along the tree `t`,
then divided by the word `N` with `Model.div`. -/
def mean (t : ReductionTree (Fin n)) (x : Fin n → Model fmt) (N : Model fmt) : Model fmt :=
  Model.div (t.eval (fun a b => Model.add a b) x) N

/-- The second pass's variance word: each difference `Model.sub (x j) μ` with the mean word
`μ = mean t₁ x N`, squared by `Model.mul`, summed by `Model.add` along the tree `t₂`, then divided
by `N` with `Model.div`. -/
def variance (t₁ t₂ : ReductionTree (Fin n)) (x : Fin n → Model fmt) (N : Model fmt) :
    Model fmt :=
  Model.div (t₂.eval (fun a b => Model.add a b) fun j =>
    Model.mul (Model.sub (x j) (mean t₁ x N)) (Model.sub (x j) (mean t₁ x N))) N

/-- The absolute error of `mean_error`: `(1 + u) · ((1 + u) ^ d - 1) · 𝔼 j, |x j| + η` for a sum
along a tree of depth `d`. -/
noncomputable def meanErr (u η : ℝ) (d : Nat) (x : Fin n → ℝ) : ℝ :=
  (1 + u) * (((1 + u) ^ d - 1) * 𝔼 j, |x j|) + η

/-- The absolute error of each difference `x j - μ` of `var_error` against `x j - 𝔼 x`:
`(1 + u) · (u · |𝔼 x| + meanErr)`. -/
noncomputable def devErr (u η : ℝ) (d : Nat) (x : Fin n → ℝ) : ℝ :=
  (1 + u) * (u * |𝔼 j, x j| + meanErr u η d x)

/-- The absolute error of `var_error`, with `δ j = x j - 𝔼 x`, `e = devErr u η d₁ x` and
`ρ = (1 + u) · (u + u + u²) + u` (FloatLib's relative error of a product of two values with
relative error `u`): `(1 + u) · (((1 + u) ^ d₂ - 1) · var x + (1 + u) ^ d₂ ·
𝔼 j, (ρ · δ j² + (1 + u) · (2 (1 + u) e |δ j| + e²) + η)) + η`, for the trees' depths `d₁` and
`d₂`. -/
noncomputable def varErr (u η : ℝ) (d₁ d₂ : Nat) (x : Fin n → ℝ) : ℝ :=
  (1 + u) * (((1 + u) ^ d₂ - 1) * TorchLean.var x + (1 + u) ^ d₂ *
    𝔼 j, (((1 + u) * (u + u + u * u) + u) * ((x j - 𝔼 i, x i) * (x j - 𝔼 i, x i)) +
      ((1 + u) * ((1 + u) * devErr u η d₁ x * |x j - 𝔼 i, x i| +
        (1 + u) * devErr u η d₁ x * |x j - 𝔼 i, x i| +
        devErr u η d₁ x * devErr u η d₁ x) + η))) + η

/-- A sum over `0, …, n - 1` divided by `n` is the mean over `Fin n`. -/
private theorem sum_div_eq_expect (f : Fin n → ℝ) :
    ((List.finRange n).map f).sum / n = 𝔼 j, f j := by
  rw [Finset.expect_eq_sum_div_card, Finset.card_univ, Fintype.card_fin, Fin.sum_univ_def]

/-- **The two-pass mean.** In every IEEE format, for every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, words `x` and finite word `N` whose real value is `n`: if the
mean word `mean t x N` is finite, every `x j` is finite and the mean approximates the exact mean
`𝔼 j, x j` of the real values with FloatLib's mixed error `(u, meanErr u η t.depth x)`, `u` and
`η` FloatLib's unit roundoff and underflow allowance. `sum_error` for the sum, then FloatLib's
`Model.mixedError_toReal_div` with the exact divisor. Nothing is claimed when the mean is infinite
or a NaN. -/
theorem mean_error (hfmt : fmt.isIEEE = true) (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (x : Fin n → Model fmt) {N : Model fmt}
    (hN : N.isFinite = true) (hNn : N.toReal = n) (h : (mean t x N).isFinite = true) :
    (∀ j, (x j).isFinite = true) ∧
      MixedError (mean t x N).toReal (𝔼 j, (x j).toReal) (Model.unitRoundoffAt fmt)
        (meanErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t.depth
          fun j => (x j).toReal) := by
  obtain ⟨hf, e⟩ := sum_error hfmt t x ht (Model.isFinite_left_of_isFinite_div hfmt h)
  refine ⟨fun j => hf j (List.mem_finRange j), ?_⟩
  have hd := Model.mixedError_toReal_div hfmt hN h (MixedError.of_abs_sub_le e)
    (MixedError.of_eq hNn) zero_lt_one
  simp only [add_zero, zero_div, mul_zero, zero_add, sub_zero, one_mul, Nat.abs_cast,
    mul_div_assoc, sum_div_eq_expect] at hd
  exact hd

/-- **The two-pass variance.** In every IEEE format, for every `n`, trees `t₁` and `t₂` whose
leaves are the indices `0, …, n - 1` up to order, words `x` and finite word `N` whose real value
is `n`: if the variance word `variance t₁ t₂ x N` is finite, it approximates TorchLean's
population variance `TorchLean.var` of the real values of the `x j` with FloatLib's mixed error
`(u, varErr u η t₁.depth t₂.depth x)`, `u` and `η` FloatLib's unit roundoff and underflow
allowance. Each difference with the mean word has `mean_error`'s error through FloatLib's
`Model.mixedError_toReal_sub`, each square FloatLib's `Model.mixedError_toReal_mul`, the second
tree `sum_mixedError` and the division `Model.mixedError_toReal_div`. Nothing is claimed when the
variance is infinite or a NaN. -/
theorem var_error (hfmt : fmt.isIEEE = true) (t₁ t₂ : ReductionTree (Fin n))
    (ht₁ : t₁.leaves.Perm (List.finRange n)) (ht₂ : t₂.leaves.Perm (List.finRange n))
    (x : Fin n → Model fmt) {N : Model fmt} (hN : N.isFinite = true) (hNn : N.toReal = n)
    (h : (variance t₁ t₂ x N).isFinite = true) :
    MixedError (variance t₁ t₂ x N).toReal (TorchLean.var fun j => (x j).toReal)
      (Model.unitRoundoffAt fmt)
      (varErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t₁.depth t₂.depth
        fun j => (x j).toReal) := by
  have hterm : ∀ j ∈ List.finRange n,
      (Model.mul (Model.sub (x j) (mean t₁ x N)) (Model.sub (x j) (mean t₁ x N))).isFinite =
        true →
      MixedError (Model.mul (Model.sub (x j) (mean t₁ x N))
          (Model.sub (x j) (mean t₁ x N))).toReal
        (((x j).toReal - 𝔼 i, (x i).toReal) * ((x j).toReal - 𝔼 i, (x i).toReal))
        ((1 + Model.unitRoundoffAt fmt) * (Model.unitRoundoffAt fmt + Model.unitRoundoffAt fmt +
          Model.unitRoundoffAt fmt * Model.unitRoundoffAt fmt) + Model.unitRoundoffAt fmt)
        ((1 + Model.unitRoundoffAt fmt) *
          ((1 + Model.unitRoundoffAt fmt) * devErr (Model.unitRoundoffAt fmt)
              (Model.underflowErrorAt fmt) t₁.depth (fun j => (x j).toReal) *
              |(x j).toReal - 𝔼 i, (x i).toReal| +
            (1 + Model.unitRoundoffAt fmt) * devErr (Model.unitRoundoffAt fmt)
              (Model.underflowErrorAt fmt) t₁.depth (fun j => (x j).toReal) *
              |(x j).toReal - 𝔼 i, (x i).toReal| +
            devErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t₁.depth
                (fun j => (x j).toReal) *
              devErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t₁.depth
                (fun j => (x j).toReal)) + Model.underflowErrorAt fmt) := by
    intro j _ hj
    have hc := (Model.isFinite_of_isFinite_mul hfmt hj).1
    have eμ := (mean_error hfmt t₁ ht₁ x hN hNn (Model.isFinite_of_isFinite_sub hfmt hc).2).2
    have ec : MixedError (Model.sub (x j) (mean t₁ x N)).toReal
        ((x j).toReal - 𝔼 i, (x i).toReal) (Model.unitRoundoffAt fmt)
        (devErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) t₁.depth
          fun j => (x j).toReal) :=
      (Model.mixedError_toReal_sub hfmt hc (MixedError.of_eq rfl) eμ).mono le_rfl
        (le_of_eq (by rw [devErr]; ring))
    exact Model.mixedError_toReal_mul hfmt hj ec ec
  have hs := sum_mixedError hfmt t₂ _ ht₂ hterm (Model.isFinite_left_of_isFinite_div hfmt h)
  have hd := Model.mixedError_toReal_div hfmt hN h hs (MixedError.of_eq hNn) zero_lt_one
  simp only [add_zero, zero_div, mul_zero, zero_add, sub_zero, one_mul, Nat.abs_cast, add_div,
    mul_div_assoc, sum_div_eq_expect, abs_mul_self] at hd
  exact hd

end MojoProof.Float
