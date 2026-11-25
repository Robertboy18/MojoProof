import MojoProof.Float.ExpSum
import Mathlib.Analysis.Complex.ExponentialBounds
import Mathlib.Analysis.SpecialFunctions.Pow.Real

/-!
# The compiled exponential: `ex2.approx.ftz.f32` of a scaled difference
(docs/proofs/float-reductions.md)

Mojo's `exp` on float32 does not call a correctly rounded exponential. Its NVPTX lowering of
`exp (x - m)` is the subtraction `fsub contract`, the multiplication `fmul contract` by the word
`0x3FB8AA3B` of `log₂ e` (`log2e`) and the instruction `ex2.approx.ftz.f32`, as inline assembly
(the standard library's `math.exp`). A subtraction followed by a multiplication cannot be
contracted, so the operand of `ex2.approx` is `Model.mul (Model.sub x m) log2e`.

PTX ISA 9.5 §9.7.3.21 states `ex2.approx.ftz.f32`'s accuracy: at most 2 ulp from the correctly
rounded result across the full range of inputs, with subnormal inputs and results flushed to
zero of their sign (and `+0` for `-∞`, `+1` for `±0`). The contract `Ex2Close a w` used here is
its consequence for a finite operand `a < 128`: the word `w` is finite and within
`ex2Err · 2 ^ a + ex2Tiny` of `2 ^ a`. Two ulp of a normal value `c` are at most `2 ^ -22 · c`,
and the correctly rounded `c` is within `2 ^ -24 · 2 ^ a` of `2 ^ a`, so the relative part is at
most `2 ^ -22 · (1 + 2 ^ -24) + 2 ^ -24 ≤ 3 · 2 ^ -23 = ex2Err`; a flushed result or one near
the subnormal range is within `2 ^ -126 = ex2Tiny` of `2 ^ a`, and so is the `1` of a flushed
subnormal operand. The contract is an assumption on the hardware (the execution model stops at
inline assembly), as `rsqrt.approx`'s is (`Sem.RsqrtClose`).

Definitions: `ex2Err`, `ex2Tiny` and `Ex2Close`, the contract; `log2e`, the multiplier word;
`ex2Rel`, the relative error of one term.

Proved:
* `log2e_close`: the word `log2e` is within relative error `2 ^ -26` of `1 / log 2`, from
  Mathlib's nine-digit bounds on `log 2`.
* `ex2_error`, for every multiplier word `L` within relative error `ρ` of `1 / log 2` and words
  `x`, `m`: a word meeting the contract at the finite operand `Model.mul (Model.sub x m) L`
  approximates `exp (x - m)` with FloatLib's mixed error `(ex2Rel u η ρ (x - m), ex2Tiny)`.
  FloatLib's `Model.mixedError_toReal_sub`, `Model.mixedError_toReal_mul`,
  `MixedError.const_mul` and `MixedError.trans_exp`.
* `ex2Sum_error`, for every `n` and tree whose leaves are `0, …, n - 1` up to order: if every
  operand is finite, every term word meets the contract at its operand and the sum along the tree
  is finite, the sum approximates `Σ_j exp (x j - m)` with the absolute error of `expSum_error`'s
  form, `((1 + u) ^ d - 1) · Σ_j exp (y j) + (1 + u) ^ d · Σ_j (ρ_j · exp (y j) + ex2Tiny)`, with
  `ρ_j = ex2Rel u η ρ (y j)` in place of the correctly rounded exponential's relative error.

Not covered: the flushed `-∞` operand (its `+0` is outside the contract, as in `expSum_error`
the differences are finite) and operands of `128` or more, where `2 ^ a` overflows. Nothing is
claimed when the sum is infinite or a NaN. The instances are in MojoProofTest/FloatEx2.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats.BinaryInterchange FloatLib.Floats
  FloatLib.Floats.Formats

/-- The relative error `3 · 2 ^ -23` of `ex2.approx.ftz.f32`'s contract: two ulp of the correctly
rounded result and its own rounding, `2 ^ -22 · (1 + 2 ^ -24) + 2 ^ -24`, rounded up. -/
def ex2Err : ℚ := 3 / 2 ^ 23

/-- The absolute error `2 ^ -126` of `ex2.approx.ftz.f32`'s contract: a result flushed to zero, a
result near binary32's subnormal range or the `1` of a flushed subnormal operand. -/
def ex2Tiny : ℚ := 1 / 2 ^ 126

/-- The contract of `ex2.approx.ftz.f32` at a finite operand `a < 128` (PTX ISA 9.5 §9.7.3.21):
the word `w` is finite and within `ex2Err · 2 ^ a + ex2Tiny` of `2 ^ a`. -/
def Ex2Close (a : ℝ) (w : Model .binary32) : Prop :=
  w.isFinite = true ∧ |w.toReal - (2 : ℝ) ^ a| ≤ (ex2Err : ℝ) * (2 : ℝ) ^ a + ex2Tiny

/-- The binary32 word `0x3FB8AA3B` of `log₂ e`, by which Mojo's `exp` multiplies its operand
before `ex2.approx.ftz.f32`. -/
def log2e : Model .binary32 := Model.ofNatBits 0x3FB8AA3B

/-- The relative error of one term of `ex2_error`, for unit roundoff `u`, underflow allowance `η`,
the multiplier's relative error `ρ` and the exact difference `y`:
`(1 + ex2Err) · exp (((1 + u) · (u + ρ + u ρ) + u) · |y| + η · log 2) - 1`. -/
noncomputable def ex2Rel (u η ρ y : ℝ) : ℝ :=
  (1 + ex2Err) * Real.exp (((1 + u) * (u + ρ + u * ρ) + u) * |y| + η * Real.log 2) - 1

/-- **The multiplier word.** The word `log2e` (`0x3FB8AA3B`, of value `12102203 / 2 ^ 23`) is
within FloatLib's mixed error `(2 ^ -26, 0)` of `1 / log 2`: Mathlib's `Real.log_two_gt_d9` and
`Real.log_two_lt_d9`. -/
theorem log2e_close : MixedError log2e.toReal (Real.log 2)⁻¹ (1 / 2 ^ 26) 0 := by
  have hq : log2e.toReal = ((12102203 / 8388608 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  have h1 := Real.log_two_gt_d9
  have h2 := Real.log_two_lt_d9
  have hl : 0 < Real.log 2 := by linarith
  refine MixedError.of_abs_sub_le_mul (by norm_num) ?_
  rw [hq, abs_inv, abs_of_pos hl,
    show ((12102203 / 8388608 : ℚ) : ℝ) - (Real.log 2)⁻¹ =
      ((12102203 / 8388608 : ℝ) * Real.log 2 - 1) * (Real.log 2)⁻¹ by
        field_simp; push_cast; ring,
    abs_mul, abs_of_pos (inv_pos.2 hl)]
  refine mul_le_mul_of_nonneg_right (abs_le.2 ⟨?_, ?_⟩) (inv_pos.2 hl).le <;>
    norm_num at h1 h2 ⊢ <;> linarith

/-- **One term.** For every binary32 multiplier word `L` within FloatLib's mixed error `(ρ, 0)` of
`1 / log 2`, words `x`, `m` and word `w`: if the operand `p = Model.mul (Model.sub x m) L` is
finite and `w` meets `ex2.approx`'s contract at `p` (`Ex2Close`), then `w` approximates
`exp (x - m)` of the real values with FloatLib's mixed error `(ex2Rel u η ρ (x - m), ex2Tiny)`.
The operand is within `((1 + u) · (u + ρ + u ρ) + u, η)` of `(x - m) / log 2`
(`Model.mixedError_toReal_sub`, `Model.mixedError_toReal_mul`), `2 ^ p = exp (log 2 · p)` and
FloatLib's `MixedError.trans_exp`. -/
theorem ex2_error {L : Model .binary32} {ρ : ℝ} (hL : MixedError L.toReal (Real.log 2)⁻¹ ρ 0)
    {x m w : Model .binary32} (hp : (Model.mul (Model.sub x m) L).isFinite = true)
    (hw : Ex2Close (Model.mul (Model.sub x m) L).toReal w) :
    MixedError w.toReal (Real.exp (x.toReal - m.toReal))
      (ex2Rel (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) ρ
        (x.toReal - m.toReal)) ex2Tiny := by
  have hl : 0 < Real.log 2 := Real.log_pos one_lt_two
  have ed : MixedError (Model.sub x m).toReal (x.toReal - m.toReal)
      (Model.unitRoundoffAt .binary32) 0 :=
    (Model.mixedError_toReal_sub rfl (Model.isFinite_of_isFinite_mul rfl hp).1
      (MixedError.of_eq rfl) (MixedError.of_eq rfl)).mono le_rfl (le_of_eq (by ring))
  have el := (Model.mixedError_toReal_mul rfl hp ed hL).const_mul (Real.log 2)
  rw [show Real.log 2 * ((x.toReal - m.toReal) * (Real.log 2)⁻¹) = x.toReal - m.toReal by
    field_simp, abs_of_pos hl] at el
  have ea : MixedError (Real.log 2 * (Model.mul (Model.sub x m) L).toReal)
      (x.toReal - m.toReal)
      ((1 + Model.unitRoundoffAt .binary32) * (Model.unitRoundoffAt .binary32 + ρ +
        Model.unitRoundoffAt .binary32 * ρ) + Model.unitRoundoffAt .binary32)
      (Model.underflowErrorAt .binary32 * Real.log 2) :=
    el.mono le_rfl (le_of_eq (by ring))
  have ew : MixedError w.toReal (Real.exp (Real.log 2 * (Model.mul (Model.sub x m) L).toReal))
      ex2Err ex2Tiny := by
    refine ⟨by norm_num [ex2Err], by norm_num [ex2Tiny], ?_⟩
    rw [abs_of_pos (Real.exp_pos _), ← Real.rpow_def_of_pos two_pos]
    exact hw.2
  exact ew.trans_exp ea

/-- **The exponential sum of the compiled kernels.** For every `n`, tree `t` whose leaves are the
indices `0, …, n - 1` up to order, binary32 multiplier word `L` within FloatLib's mixed error
`(ρ, 0)` of `1 / log 2` (`log2e_close` for the compiled one), words `x`, word `m` and term words
`e`: if every operand `Model.mul (Model.sub (x j) m) L` is finite, every `e j` meets
`ex2.approx`'s contract at its operand (`Ex2Close`) and the sum of the `e j` by `Model.add` along
`t` is finite, the sum approximates `Σ_j exp (x j - m)` with the absolute error
`((1 + u) ^ d - 1) · Σ_j exp (y j) + (1 + u) ^ d · Σ_j (ex2Rel u η ρ (y j) · exp (y j) + ex2Tiny)`,
`y j = x j - m` and `d = t.depth`: `expSum_error`'s form with `ex2_error`'s term error.
`sum_mixedError` with `ex2_error` at every leaf. Nothing is claimed when the sum is infinite or a
NaN. -/
theorem ex2Sum_error {n : Nat} (t : ReductionTree (Fin n)) (ht : t.leaves.Perm (List.finRange n))
    {L : Model .binary32} {ρ : ℝ} (hL : MixedError L.toReal (Real.log 2)⁻¹ ρ 0)
    (x : Fin n → Model .binary32) (m : Model .binary32) (e : Fin n → Model .binary32)
    (hp : ∀ j, (Model.mul (Model.sub (x j) m) L).isFinite = true)
    (he : ∀ j, Ex2Close (Model.mul (Model.sub (x j) m) L).toReal (e j))
    (h : (t.eval (fun a b => Model.add a b) e).isFinite = true) :
    MixedError (t.eval (fun a b => Model.add a b) e).toReal
      (∑ j, Real.exp ((x j).toReal - m.toReal)) 0
      (((1 + Model.unitRoundoffAt .binary32) ^ t.depth - 1) *
          ∑ j, Real.exp ((x j).toReal - m.toReal) +
        (1 + Model.unitRoundoffAt .binary32) ^ t.depth *
          ∑ j, (ex2Rel (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) ρ
            ((x j).toReal - m.toReal) * Real.exp ((x j).toReal - m.toReal) + ex2Tiny)) := by
  have es := sum_mixedError rfl t e ht (fun j _ _ => ex2_error hL (hp j) (he j)) h
  simpa only [Real.abs_exp, ← Fin.sum_univ_def] using es

end MojoProof.Float
