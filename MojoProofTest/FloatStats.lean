import MojoProof.Float.Stats
import MojoProof.Float.ExpSum
import MojoProofTest.FloatTree

/-!
# Instances of the two-pass statistics, the exact maximum and the stable softmax

Tests of one example each, in binary32, over four indices, with two trees: `loop`, FloatLib's
left-to-right chain, and `pairs`, the shape of a block's halving tree over four cells (cell 0's
tree after the strides 2 and 1). Every premise is discharged by evaluation (`decide +kernel`) or,
for `errA_lt`, by normalizing FloatLib's binary32 constants.

* `mean_xs`, `var_xs`: `mean_error` and `var_error` at the inputs `1, 2, 3, 4` (`xs`) and the
  divisor word `4` (`four`): the mean `2.5` and the variance `1.25` are finite.
* `max_xs`: `max_exact` at `xs` along `pairs`.
* `term_xs`, `expSum_xs`: `expTerm_error` and `expSum_error` at `xs` shifted by `4`, the
  correctly rounded exponentials of `-3, -2, -1, 0` summed along `pairs`.
* `softmax_ones`: `softmax_error` at four inputs `1` (`ones`), each less their maximum along
  `pairs` (`top`, whose real value is an input's by `max_exact`); `errA_lt`: the premise `A < 1`.
-/

namespace MojoProofTest.FloatStats

open MojoProof.Float FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatTree MojoProofTest.FloatRel
open scoped BigOperators

/-- The binary32 word `0x40800000` of `4`. -/
abbrev four : Model .binary32 := f32 0x40800000

/-- The binary32 words of `1, 2, 3, 4`. -/
abbrev xs : Fin 4 → Model .binary32 := ![one, f32 0x40000000, f32 0x40400000, four]

/-- Four binary32 words of `1`. -/
abbrev ones : Fin 4 → Model .binary32 := fun _ => one

/-- FloatLib's left-to-right chain over the indices `0, 1, 2, 3`. -/
abbrev loop : ReductionTree (Fin 4) := ReductionTree.leftChain 0 [1, 2, 3]

/-- The pairwise tree `(0 + 2) + (1 + 3)`: cell 0's tree after the halving rounds with strides
`2` and `1` over four cells. -/
abbrev pairs : ReductionTree (Fin 4) := .node (.node (.leaf 0) (.leaf 2)) (.node (.leaf 1) (.leaf 3))

/-- The real value of the binary32 word `0x40800000` is `4`. -/
theorem four_toReal : four.toReal = ((4 : ℕ) : ℝ) := by
  have h : four.toRat? = some 4 := by decide +kernel
  rw [Model.Algebraic.toReal_of_toRat?_eq_some h]
  norm_num

/-- **The instance of `mean_error`**, a test of one example: the mean of `1, 2, 3, 4` along `loop`
divided by the word `4` is finite (by evaluation), so the inputs are finite and the mean is within
the mixed error `(u, meanErr)` of `𝔼 j, xs j`. -/
theorem mean_xs :
    (∀ j, (xs j).isFinite = true) ∧
      MixedError (mean loop xs four).toReal (𝔼 j, (xs j).toReal) (Model.unitRoundoffAt .binary32)
        (meanErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) loop.depth
          fun j => (xs j).toReal) :=
  mean_error rfl loop (by decide +kernel) xs (by decide +kernel) four_toReal (by decide +kernel)

/-- **The instance of `var_error`**, a test of one example: the variance of `1, 2, 3, 4`, with the
mean along `loop` and the squares along `pairs`, is finite (by evaluation), so it is within the
mixed error `(u, varErr)` of TorchLean's `TorchLean.var` of the real values. -/
theorem var_xs :
    MixedError (variance loop pairs xs four).toReal (TorchLean.var fun j => (xs j).toReal)
      (Model.unitRoundoffAt .binary32)
      (varErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) loop.depth
        pairs.depth fun j => (xs j).toReal) :=
  var_error rfl loop pairs (by decide +kernel) (by decide +kernel) xs (by decide +kernel)
    four_toReal (by decide +kernel)

/-- **The instance of `max_exact`**, a test of one example: the inputs `1, 2, 3, 4` are finite (by
evaluation), so their maximum along `pairs` is finite, is one of them and bounds them all. -/
theorem max_xs :
    (pairs.eval (fun a b => Model.maximumNumber a b) xs).isFinite = true ∧
      (∃ k ∈ pairs.leaves,
        (pairs.eval (fun a b => Model.maximumNumber a b) xs).toReal = (xs k).toReal) ∧
      ∀ j ∈ pairs.leaves,
        (xs j).toReal ≤ (pairs.eval (fun a b => Model.maximumNumber a b) xs).toReal :=
  max_exact pairs xs (by decide +kernel)

/-- **The instance of `expTerm_error`**, a test of one example: the difference `1 - 4` and its
correctly rounded exponential are finite (by evaluation). -/
theorem term_xs :
    MixedError (expTerm {} xs four 0).toReal (Real.exp ((xs 0).toReal - four.toReal))
      ((1 + Model.unitRoundoffAt .binary32) *
        Real.exp (Model.unitRoundoffAt .binary32 * |(xs 0).toReal - four.toReal|) - 1)
      (Model.underflowErrorAt .binary32) :=
  expTerm_error rfl {} xs four 0 (by decide +kernel) (by decide +kernel)

/-- **The instance of `expSum_error`**, a test of one example: the differences of `1, 2, 3, 4`
with `4` and the sum along `pairs` of their correctly rounded exponentials are finite (by
evaluation), so the sum is within `expSumErr` of `Σ_j exp (xs j - 4)`. -/
theorem expSum_xs :
    MixedError (pairs.eval (fun a b => Model.add a b) (expTerm {} xs four)).toReal
      (∑ j, Real.exp ((xs j).toReal - four.toReal)) 0
      (expSumErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) pairs.depth
        fun j => (xs j).toReal - four.toReal) :=
  expSum_error rfl pairs (by decide +kernel) {} xs four (by decide +kernel) (by decide +kernel)

/-- The maximum of `ones` along `pairs`. -/
abbrev top : Model .binary32 := pairs.eval (fun a b => Model.maximumNumber a b) ones

/-- The absolute error `expSumErr` of the exponential sum of `ones` shifted by `top` along
`pairs`, written out by a notation where it is used. -/
local notation "errA" =>
  expSumErr (Model.unitRoundoffAt FloatFormat.binary32) (Model.underflowErrorAt FloatFormat.binary32)
    (ReductionTree.depth pairs) (fun j => Model.toReal (ones j) - Model.toReal top)

/-- The premise `A < 1` of `softmax_error` at `ones`: every difference is `0`, so `A` is
`((1 + u) ^ 2 - 1) · 4 + (1 + u) ^ 2 · 4 · (u + η)` with binary32's `u = 2 ^ -24` and
`η = 2 ^ -150`. -/
theorem errA_lt : errA < 1 := by
  have ht : top.toReal = 1 := by rw [show top = one by decide +kernel, one_toReal]
  have hd : pairs.depth = 2 := rfl
  simp only [expSumErr, ones, one_toReal, ht, hd, sub_self, Real.exp_zero, abs_zero,
    mul_zero, mul_one, Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]

-- Mathlib v4.36.0 exposes `Real`'s operations to files outside the module system, so elaborating
-- the premise `A < 1` about concrete reals unfolds their arithmetic, which needs a deeper recursion
-- limit (as in MojoProof/Sem/Float.lean).
set_option maxRecDepth 4096 in
/-- **The instance of `softmax_error`**, a test of one example: four inputs `1`, shifted by their
maximum `top` along `pairs` (an input's value by `max_exact`); the differences, the sum of the
exponentials along `pairs` and entry 0 are finite (by evaluation) and `A < 1` (`errA_lt`), so
entry 0 is within the stated mixed error of TorchLean's real softmax entry `1 / 4`. -/
theorem softmax_ones :
    MixedError (Model.div (expTerm {} ones top 0)
        (pairs.eval (fun a b => Model.add a b) (expTerm {} ones top))).toReal
      (TorchLean.TransformerBlock.softmax Finset.univ (fun i => (ones i).toReal) 0)
      ((1 + Model.unitRoundoffAt .binary32) *
        (((1 + Model.unitRoundoffAt .binary32) *
            Real.exp (Model.unitRoundoffAt .binary32 * |(ones 0).toReal - top.toReal|) - 1 +
          errA) / (1 - errA)) + Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) * (Model.underflowErrorAt .binary32 / (1 - errA)) +
        Model.underflowErrorAt .binary32) := by
  obtain ⟨-, ⟨k, -, hk⟩, -⟩ := max_exact pairs ones (by decide +kernel)
  exact softmax_error rfl pairs (by decide +kernel) {} ones top hk (by decide +kernel) errA_lt
    (by decide +kernel) 0 (by decide +kernel)

end MojoProofTest.FloatStats
