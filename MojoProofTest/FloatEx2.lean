import MojoProof.Float.Ex2
import MojoProofTest.FloatStats

/-!
# Instances of the compiled exponential with `ex2.approx`

Tests of one example each, in binary32, at four inputs `1` (`ones`) less the word `1`, with
Mojo's multiplier word `log2e` (`log2e_close`). The operand of `ex2.approx` is
`(1 - 1) · log2e = +0` (by evaluation), at which the word `1` meets the contract (`zero_close`).

* `ex2_ones`: `ex2_error`, the word `1` against `exp (1 - 1)`.
* `ex2Sum_ones`: `ex2Sum_error`, the sum of four words `1` along `pairs` against
  `Σ_j exp (1 - 1)`.
-/

namespace MojoProofTest.FloatEx2

open MojoProof.Float FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatTree MojoProofTest.FloatStats
open scoped BigOperators

/-- The operand `(1 - 1) · log2e` of `ex2.approx` is finite. -/
theorem zero_finite : (Model.mul (Model.sub one one) log2e).isFinite = true := by
  decide +kernel

/-- The word `1` meets `ex2.approx`'s contract at the operand `(1 - 1) · log2e`, whose real value
is `0`. -/
theorem zero_close : Ex2Close (Model.mul (Model.sub one one) log2e).toReal one := by
  have h0 : (Model.mul (Model.sub one one) log2e).toReal = ((0 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  refine ⟨by decide +kernel, ?_⟩
  rw [h0, Rat.cast_zero, Real.rpow_zero, one_toReal]
  norm_num [ex2Err, ex2Tiny]

/-- **The instance of `ex2_error`**, a test of one example: the operand `(1 - 1) · log2e` is
finite (by evaluation) and the word `1` meets the contract there, so it approximates
`exp (1 - 1)` with the mixed error `(ex2Rel u η 2 ^ -26 0, ex2Tiny)`. -/
theorem ex2_ones :
    MixedError one.toReal (Real.exp (one.toReal - one.toReal))
      (ex2Rel (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (1 / 2 ^ 26)
        (one.toReal - one.toReal)) ex2Tiny :=
  ex2_error log2e_close zero_finite zero_close

/-- **The instance of `ex2Sum_error`**, a test of one example: four inputs `1` less the word `1`,
with term words `1`, each meeting the contract at its finite operand, and their sum along `pairs`
finite (by evaluation), so the sum is within the stated absolute error of `Σ_j exp (1 - 1)`. -/
theorem ex2Sum_ones :
    MixedError (pairs.eval (fun a b => Model.add a b) ones).toReal
      (∑ j, Real.exp ((ones j).toReal - one.toReal)) 0
      (((1 + Model.unitRoundoffAt .binary32) ^ pairs.depth - 1) *
          ∑ j, Real.exp ((ones j).toReal - one.toReal) +
        (1 + Model.unitRoundoffAt .binary32) ^ pairs.depth *
          ∑ j, (ex2Rel (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
            (1 / 2 ^ 26) ((ones j).toReal - one.toReal) *
              Real.exp ((ones j).toReal - one.toReal) + ex2Tiny)) :=
  ex2Sum_error pairs (by decide +kernel) log2e_close ones one ones (fun _ => zero_finite)
    (fun _ => zero_close) (by decide +kernel)

end MojoProofTest.FloatEx2
