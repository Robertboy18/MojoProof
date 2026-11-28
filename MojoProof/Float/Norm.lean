import MojoProof.Float.Welford
import MojoProof.Sem.FloatRel
import FloatLib.Floats.Formats.Block.Working.Binary
import TorchLean.Verify.RuntimeApprox.TransformerBlock

/-!
# Layer norm's and RMS norm's outputs with `rsqrt.approx` (docs/proofs/float-norm.md)

The compiled layer norm kernels normalize each input `x j` with the Welford mean word `μ` and the
reciprocal square root word `r = rsqrt.approx (v + ε)` of the variance word `v` plus the word `ε`,
then scale by the weight and add the bias: `((x j - μ) · r) · γ j + β j`
(tests/corpus/layernorm/ln_rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a.nvptx.ll, lines 430-432 for
`v` by `fdiv`, `v + ε` and `llvm.nvvm.rsqrt.approx.ftz.f`, lines 513-516 for the output, all four
operations `contract`). RMS norm computes the mean of squares `m` (`msq`,
MojoProof/Float/Stats.lean), `r = rsqrt.approx (m + ε)` and `(x j · r) · γ j`.

Definitions: `rsqrtRel`, the relative error of a reciprocal square root word computed from an
approximate operand; `lnOut` and `lnErr`, the layer norm output word and its error; `lnorm`, the
binary32 layer norm word with the Welford statistics and `rsqrt.approx`, and `lnDev`, the error of
its operand `v + ε`; `rmsOut`, the RMS norm output word, and `rmsnorm`, the binary32 RMS norm word;
`rmsOff` and `rmsOffErr`, the RMS norm output word with a weight offset in a dtype and its error,
and `rmsnormOff`, the RMS norm word with the offset, accumulated in binary32.

Proved:
* `rsqrt_rel`: a word within relative error `ρ` of `1 / √s` for an `s` within FloatLib's mixed
  error `(r, a)` of `t > 0` is within relative error `rsqrtRel r ρ a t` of `1 / √t`, when
  `r + a / t < 1`.
* `lnOut_error`, in every IEEE format, for every mean word within `e` of `μ₀` and reciprocal
  word within relative error `κ` of `w`: the finite output is within FloatLib's mixed error
  `(u, lnErr u η e κ w γ (x - μ₀))` of `(x - μ₀) · w · γ + β`, unfused or with the last
  multiplication and addition fused.
* `lnorm_error`, in binary32, for every tree over `0, …, n - 1`, `n ≤ 2 ^ 24`, inputs within `B`
  in magnitude, weights, biases, `ε > 0` and oracle number of `rsqrt.approx`: the finite output
  at `j` is within `(u, lnErr …)` of TorchLean's real layer norm
  `TorchLean.TransformerBlock.layerNorm γ β ε x j`.
* `rmsOut_error` and `rmsnorm_error`: the same for RMS norm, against the real value
  `x j / √(𝔼 k, x k ^ 2 + ε) · γ j`. TorchLean's `TorchLean.Tensor.rmsNorm` divides by the row's
  largest magnitude first and has no proved closed form over the reals (its docstring states this
  value for a positive scale), so the real value is written out here; no second RMS norm is
  defined.
* `rmsOff_error` and `rmsnormOff_error`: RMS norm with a weight offset `o` and a dtype, in the
  two orders of Mojo's RMS norm (max/kernels/src/nn/normalization.mojo, lines 339-345 at the
  pinned commit): multiplied in the accumulator before the cast into the dtype,
  `cast ((x · r) · (cast g + o))`, or cast first, `cast (x · r) · (g + cast o)`, for every IEEE
  accumulator format and dtype (`rmsnormOff_error`: accumulated in binary32), against the real
  value `x j / √(𝔼 k, x k ^ 2 + ε) · (γ j + o)`.
* `cast_widen`: for all IEEE formats `fs` and `fd` with `fd` at least as wide in exponent and
  fraction, the cast of a finite word of `fs` into `fd` is finite and keeps its real value.
* `rmsnormOff_widen`: `rmsnormOff_error` at inputs of an IEEE format with at most binary32's
  widths (binary16, bfloat16) cast into binary32, against the inputs' own real values.

`rsqrt.approx` enters through its contract (`Sem.rsqrt_close`, MojoProof/Sem/FloatRel.lean):
the word is within relative error `rsqrtErr` of `1 / √s` for a positive normal `s`. `fused`
covers only the output's last multiplication and addition (lines 515-516). Not covered: the
Welford words' fused multiply-adds. `lnorm` takes the words of `welford`, which rounds every
product, while the kernel's merge has two `fmul contract` products feeding `fadd contract`
(lines 263-264 and 266-268) and so has its loop's update (lines 151-152 and 155-156), each pair
free to fuse; `welfordC_error` bounds the merge for every choice of contraction at each node,
and `wloop_error` the loop for every choice at each iteration, on their own, not composed into
`lnorm` here. Also not covered: RMS norm's squares fused into the additions that sum them, and
casts into binary32 of input formats with another encoding or bias than IEEE's (finite-only and
FNUZ formats), which `rmsnormOff_widen` does not take. Each cast of the offset, the weight or the
output is bounded as a rounding, also where it is exact. Nothing is claimed when the output is
infinite or a NaN. The instances are in MojoProofTest/FloatNorm.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange
open scoped BigOperators

variable {fmt : FloatFormat}

/-- The relative error of a reciprocal square root word against `1 / √t`, for an operand within
FloatLib's mixed error `(r, a)` of `t` and a word within relative error `ρ` of the reciprocal
square root of the operand: `(1 + ρ) · δ / (1 - δ) + ρ` with `δ = r + a / t`. -/
noncomputable def rsqrtRel (r ρ a t : ℝ) : ℝ :=
  (1 + ρ) * ((r + a / t) / (1 - (r + a / t))) + ρ

/-- **A reciprocal square root of an approximate operand.** For reals `s`, `t > 0` with `s` within
FloatLib's mixed error `(r, a)` of `t`, `r + a / t < 1`, `ρ ≥ 0` and `w` within relative error `ρ`
of `1 / √s`: `w` is within relative error `rsqrtRel r ρ a t` of `1 / √t`. FloatLib's
`MixedError.relative_of_le_abs`, `MixedError.sqrt`, `MixedError.inv` and `MixedError.trans`. -/
theorem rsqrt_rel {s t r ρ a w : ℝ} (hs : MixedError s t r a) (ht : 0 < t) (hδ : r + a / t < 1)
    (hρ : 0 ≤ ρ) (hw : |w - 1 / √s| ≤ ρ / √s) : MixedError w (1 / √t) (rsqrtRel r ρ a t) 0 := by
  have h1 := (hs.relative_of_le_abs ht (le_abs_self t)).sqrt ht.le
  rw [Real.sqrt_zero] at h1
  have h2 := h1.inv hδ
  have hw' : MixedError w (√s)⁻¹ ρ 0 := MixedError.of_abs_sub_le_mul hρ (by
    rw [abs_inv, abs_of_nonneg (Real.sqrt_nonneg _), ← div_eq_mul_inv, ← one_div]
    exact hw)
  have h3 := hw'.trans h2
  rw [mul_zero, add_zero] at h3
  simpa only [rsqrtRel, one_div] using h3

/-- The layer norm output word of input `x`, mean word `μ`, reciprocal standard deviation word
`r`, weight `g` and bias `b`, as the compiled kernels compute it: `((x - μ) · r) · g + b` by
`Model.sub`, `Model.mul`, `Model.mul` and `Model.add`, or, when `fused`, with the last
multiplication and addition one `Model.fma` (a contracted `fmul` / `fadd` pair). -/
def lnOut (fused : Bool) (x μ r g b : Model fmt) : Model fmt :=
  if fused then Model.fma (Model.mul (Model.sub x μ) r) g b
  else Model.add (Model.mul (Model.mul (Model.sub x μ) r) g) b

/-- The absolute error of `lnOut_error`, for unit roundoff `u`, underflow allowance `η`, mean
error `e`, relative error `κ` of the reciprocal word against `w`, weight `g` and centered input
`y`: `(1 + u) · ((1 + u) · ρ + u) · |y w g| + (1 + u) · ((1 + u) · α · |g| + η)`, with
`ρ = (1 + u) · (u + κ + u κ) + u` and `α = (1 + u) · (1 + κ) · (1 + u) · e · |w| + η` the errors
of `(x - μ) · r`. -/
noncomputable def lnErr (u η e κ w g y : ℝ) : ℝ :=
  (1 + u) * (((1 + u) * ((1 + u) * (u + κ + u * κ) + u) + u) * |y * w * g| +
    ((1 + u) * ((1 + u) * ((1 + κ) * ((1 + u) * e) * |w|) + η) * |g| + η))

/-- **The layer norm output.** In every IEEE format, fused or not, for words `x`, `μ`, `r`, `g`,
`b` and reals `μ₀`, `w`, `e`, `κ` with the mean word within `e` of `μ₀` and the reciprocal word
`r` within relative error `κ` of `w`: if the output word `lnOut fused x μ r g b` is finite, it is
within FloatLib's mixed error `(u, lnErr u η e κ w g (x - μ₀))` of `(x - μ₀) · w · g + b`. One
FloatLib lemma per operation (`Model.mixedError_toReal_sub`, `_mul`, `_add`, `_fma`); the fused
bound is below the unfused one. Nothing is claimed when the output is infinite or a NaN. -/
theorem lnOut_error (hfmt : fmt.isIEEE = true) (fused : Bool) {x μ r g b : Model fmt}
    {μ₀ w e κ : ℝ} (hμ : |μ.toReal - μ₀| ≤ e) (hr : MixedError r.toReal w κ 0)
    (h : (lnOut fused x μ r g b).isFinite = true) :
    MixedError (lnOut fused x μ r g b).toReal ((x.toReal - μ₀) * w * g.toReal + b.toReal)
      (Model.unitRoundoffAt fmt)
      (lnErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) e κ w g.toReal
        (x.toReal - μ₀)) := by
  have hu : 0 ≤ Model.unitRoundoffAt fmt := (Model.unitRoundoffAt_pos fmt).le
  have hη : 0 ≤ Model.underflowErrorAt fmt := (Model.underflowErrorAt_pos fmt).le
  have hκ : 0 ≤ κ := hr.r_nonneg
  have he : 0 ≤ e := (abs_nonneg _).trans hμ
  have eg : MixedError g.toReal g.toReal 0 0 := MixedError.of_eq rfl
  have eb : MixedError b.toReal b.toReal 0 0 := MixedError.of_eq rfl
  cases fused <;> simp only [lnOut, Bool.false_eq_true, ↓reduceIte] at h ⊢
  · have h1 := Model.isFinite_of_isFinite_add hfmt h
    have h2 := Model.isFinite_of_isFinite_mul hfmt h1.1
    have ec := Model.mixedError_toReal_sub hfmt (Model.isFinite_of_isFinite_mul hfmt h2.1).1
      (MixedError.of_eq (x₀ := x.toReal) rfl) (MixedError.of_abs_sub_le hμ)
    have eo := Model.mixedError_toReal_add hfmt h
      (Model.mixedError_toReal_mul hfmt h1.1 (Model.mixedError_toReal_mul hfmt h2.1 ec hr) eg) eb
    exact eo.mono le_rfl (le_of_eq (by unfold lnErr; ring))
  · have h1 := Model.isFinite_of_isFinite_fma hfmt h
    have ec := Model.mixedError_toReal_sub hfmt (Model.isFinite_of_isFinite_mul hfmt h1.1).1
      (MixedError.of_eq (x₀ := x.toReal) rfl) (MixedError.of_abs_sub_le hμ)
    have eo := Model.mixedError_toReal_fma hfmt h (Model.mixedError_toReal_mul hfmt h1.1 ec hr)
      eg eb
    refine eo.mono le_rfl ?_
    unfold lnErr
    generalize Model.unitRoundoffAt fmt = u at hu ⊢
    generalize Model.underflowErrorAt fmt = η at hη ⊢
    have hA := abs_nonneg ((x.toReal - μ₀) * w * g.toReal)
    have hG := abs_nonneg g.toReal
    have hW := abs_nonneg w
    have hd : 0 ≤ (1 + u) * (u * ((1 + u) * (u + κ + u * κ) + u) + u) *
        |(x.toReal - μ₀) * w * g.toReal| +
      (1 + u) * u * ((1 + u) * ((1 + κ) * ((1 + u) * e) * |w|) + η) * |g.toReal| + u * η := by
      positivity
    linarith [hd]

/-- The absolute error `(1 + u) · (u · V + ((1 + u) · g + η))` of the operand `v + ε` of
`rsqrt.approx` in `lnorm`, with `g = (welfErr u η B d).2` and `V` the variance: the variance
word's error (`wvar_error`) and the rounding of the addition. -/
noncomputable def lnDev (u η B : ℝ) (d : ℕ) (V : ℝ) : ℝ :=
  (1 + u) * (u * V + ((1 + u) * (welfErr u η B d).2 + η))

/-- The binary32 layer norm word at `j` of the compiled kernels: `lnOut fused` of `x j`, the
Welford mean word of `x` along `t`, `rsqrt.approx.ftz.f32` with oracle number `k` of the variance
word plus `ε`, the weight `g j` and the bias `b j`. -/
def lnorm {n : ℕ} (t : ReductionTree (Fin n)) (x g b : Fin n → Model .binary32)
    (ε : Model .binary32) (k : ℕ) (fused : Bool) (j : Fin n) : Model .binary32 :=
  lnOut fused (x j) (welford t x).2.1 (Sem.rsqrt (Model.add (wvar t x) ε) k) (g j) (b j)

-- FloatLib's `unitRoundoffAt` and `underflowErrorAt` are powers `bpow 2 e`, and Mathlib v4.36.0
-- exposes `Real`'s operations to files outside the module system: a premise about these reals
-- in weak head normal form would unfold the powers past the default recursion limit. `bpow` is
-- irreducible here, so it is not unfolded.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **Layer norm against TorchLean's.** In binary32, for every `n ≤ 2 ^ 24`, tree `t` whose leaves
are `0, …, n - 1` up to order, inputs `x` within `B` in magnitude, weights `g`, biases `b`, word
`ε > 0`, oracle number `k` of `rsqrt.approx`, fused or not, and index `j`: if the Welford words
and the variance word are finite, the operand `s = v + ε` of `rsqrt.approx` is finite, positive
and normal, `u + lnDev u η B t.depth V / (V + ε) < 1` (`V` the inputs' variance) and the output
`lnorm t x g b ε k fused j` is finite, then the output is within FloatLib's mixed error
`(u, lnErr u η e κ (1 / √(V + ε)) (g j) (x j - 𝔼 x))` of TorchLean's real layer norm
`TorchLean.TransformerBlock.layerNorm g b ε x j`, with `e = (welfErr u η B t.depth).1` and
`κ = rsqrtRel u rsqrtErr (lnDev u η B t.depth V) (V + ε)`. `wmean_error`, `wvar_error`,
`Sem.rsqrt_close`, `rsqrt_rel` and `lnOut_error`. Nothing is claimed when the output is infinite
or a NaN. -/
theorem lnorm_error {n : ℕ} (t : ReductionTree (Fin n)) (ht : t.leaves.Perm (List.finRange n))
    (x g b : Fin n → Model .binary32) {B : ℝ} (hB : ∀ j, |(x j).toReal| ≤ B)
    (hn : n ≤ 2 ^ (FloatFormat.binary32.fracWidth + 1)) {ε : Model .binary32} (k : ℕ)
    (fused : Bool) (h₁ : (welford t x).1.isFinite = true)
    (h₂ : (welford t x).2.1.isFinite = true) (h₃ : (welford t x).2.2.isFinite = true)
    (hv : (wvar t x).isFinite = true) (hε : 0 < ε.toReal)
    (hs : (Model.add (wvar t x) ε).isFinite = true)
    (hz : (Model.add (wvar t x) ε).isZero = false)
    (hsub : (Model.add (wvar t x) ε).isSubnormal = false)
    (hsg : (Model.add (wvar t x) ε).signBit = false)
    (hδ : Model.unitRoundoffAt .binary32 +
        lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) B t.depth
          (TorchLean.var fun j => (x j).toReal) /
          (TorchLean.var (fun j => (x j).toReal) + ε.toReal) < 1)
    (j : Fin n) (h : (lnorm t x g b ε k fused j).isFinite = true) :
    MixedError (lnorm t x g b ε k fused j).toReal
      (TorchLean.TransformerBlock.layerNorm (fun j => (g j).toReal) (fun j => (b j).toReal)
        ε.toReal (fun j => (x j).toReal) j)
      (Model.unitRoundoffAt .binary32)
      (lnErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) B
          t.depth).1
        (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
          (lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) B t.depth
            (TorchLean.var fun j => (x j).toReal))
          (TorchLean.var (fun j => (x j).toReal) + ε.toReal))
        (1 / √(TorchLean.var (fun j => (x j).toReal) + ε.toReal)) (g j).toReal
        ((x j).toReal - 𝔼 i, (x i).toReal)) := by
  have hV := TorchLean.var_nonneg fun j => (x j).toReal
  have eμ := wmean_error rfl t ht x hB hn h₁ h₂ h₃
  have es := Model.mixedError_toReal_add rfl hs (wvar_error rfl t ht x hB hn h₁ h₂ h₃ hv)
    (MixedError.of_eq (x₀ := ε.toReal) rfl)
  rw [abs_of_nonneg hV] at es
  have es' : MixedError (Model.add (wvar t x) ε).toReal
      (TorchLean.var (fun j => (x j).toReal) + ε.toReal) (Model.unitRoundoffAt .binary32)
      (lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) B t.depth
        (TorchLean.var fun j => (x j).toReal)) :=
    es.mono le_rfl (le_of_eq (by unfold lnDev; ring))
  have hρ : (0 : ℝ) ≤ Sem.rsqrtErr := Rat.cast_nonneg.2 (by rw [Sem.rsqrtErr]; positivity)
  have er := rsqrt_rel es' (add_pos_of_nonneg_of_pos hV hε) hδ hρ
    (Sem.rsqrt_close hs hz hsub hsg k).2
  have eo := lnOut_error rfl fused eμ er h
  have hL : TorchLean.TransformerBlock.layerNorm (fun j => (g j).toReal) (fun j => (b j).toReal)
      ε.toReal (fun j => (x j).toReal) j = ((x j).toReal - 𝔼 i, (x i).toReal) *
        (1 / √(TorchLean.var (fun j => (x j).toReal) + ε.toReal)) * (g j).toReal +
        (b j).toReal := by
    simp only [TorchLean.TransformerBlock.layerNorm]
    ring
  rw [hL]
  exact eo

/-- The RMS norm output word of input `x`, reciprocal word `r` and weight `g`: `(x · r) · g` by
`Model.mul` twice. -/
def rmsOut (x r g : Model fmt) : Model fmt :=
  Model.mul (Model.mul x r) g

/-- **The RMS norm output.** In every IEEE format, for words `x`, `r`, `g` and reals `w`, `κ` with
`r` within relative error `κ` of `w`: if the output word `rmsOut x r g` is finite, it is within
FloatLib's mixed error `((1 + u) · ((1 + u) · κ + u) + u, (1 + u) · η · |g| + η)` of `x · w · g`.
FloatLib's `Model.mixedError_toReal_mul` twice. Nothing is claimed when the output is infinite or
a NaN. -/
theorem rmsOut_error (hfmt : fmt.isIEEE = true) {x r g : Model fmt} {w κ : ℝ}
    (hr : MixedError r.toReal w κ 0) (h : (rmsOut x r g).isFinite = true) :
    MixedError (rmsOut x r g).toReal (x.toReal * w * g.toReal)
      ((1 + Model.unitRoundoffAt fmt) * ((1 + Model.unitRoundoffAt fmt) * κ +
        Model.unitRoundoffAt fmt) + Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt * |g.toReal| +
        Model.underflowErrorAt fmt) := by
  have ep := Model.mixedError_toReal_mul hfmt (Model.isFinite_of_isFinite_mul hfmt h).1
    (MixedError.of_eq (x₀ := x.toReal) rfl) hr
  have eo := Model.mixedError_toReal_mul hfmt h ep (MixedError.of_eq (x₀ := g.toReal) rfl)
  exact eo.mono (le_of_eq (by ring)) (le_of_eq (by ring))

/-- The binary32 RMS norm word at `j`: `rmsOut` of `x j`, `rsqrt.approx.ftz.f32` with oracle
number `k` of the mean of squares word `msq t x N` plus `ε`, and the weight `g j`. -/
def rmsnorm {n : ℕ} (t : ReductionTree (Fin n)) (x g : Fin n → Model .binary32)
    (N ε : Model .binary32) (k : ℕ) (j : Fin n) : Model .binary32 :=
  rmsOut (x j) (Sem.rsqrt (Model.add (msq t x N) ε) k) (g j)

-- `bpow` is irreducible here, as above.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **RMS norm.** In binary32, for every `n`, tree `t` whose leaves are `0, …, n - 1` up to order,
inputs `x`, weights `g`, finite word `N` of real value `n`, word `ε > 0`, oracle number `k` of
`rsqrt.approx` and index `j`: if the operand `s = m + ε` of `rsqrt.approx` (`m = msq t x N`) is
finite, positive and normal, `u + (1 + u) · (u · M + msqErr u η t.depth x) / (M + ε) < 1`
(`M = 𝔼 i, x i ^ 2`) and the output `rmsnorm t x g N ε k j` is finite, then the output is within
FloatLib's mixed error `((1 + u) · ((1 + u) · κ + u) + u, (1 + u) · η · |g j| + η)` of the real RMS
norm `x j / √(M + ε) · g j`, with `κ = rsqrtRel u rsqrtErr ((1 + u) · (u · M + msqErr …)) (M + ε)`.
That real value is the one `TorchLean.Tensor.rmsNorm`'s docstring states; TorchLean proves no
closed form of it over the reals. `msq_error`, `Sem.rsqrt_close`, `rsqrt_rel` and
`rmsOut_error`. Nothing is claimed when the output is infinite or a NaN. -/
theorem rmsnorm_error {n : ℕ} (t : ReductionTree (Fin n)) (ht : t.leaves.Perm (List.finRange n))
    (x g : Fin n → Model .binary32) {N ε : Model .binary32} (hN : N.isFinite = true)
    (hNn : N.toReal = n) (k : ℕ) (hε : 0 < ε.toReal)
    (hs : (Model.add (msq t x N) ε).isFinite = true)
    (hz : (Model.add (msq t x N) ε).isZero = false)
    (hsub : (Model.add (msq t x N) ε).isSubnormal = false)
    (hsg : (Model.add (msq t x N) ε).signBit = false)
    (hδ : Model.unitRoundoffAt .binary32 + (1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
          msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) t.depth
            (fun i => (x i).toReal)) / ((𝔼 i, (x i).toReal ^ 2) + ε.toReal) < 1)
    (j : Fin n) (h : (rmsnorm t x g N ε k j).isFinite = true) :
    MixedError (rmsnorm t x g N ε k j).toReal
      ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal) * (g j).toReal)
      ((1 + Model.unitRoundoffAt .binary32) * ((1 + Model.unitRoundoffAt .binary32) *
          rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
            ((1 + Model.unitRoundoffAt .binary32) *
              (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
                msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                  t.depth (fun i => (x i).toReal)))
            ((𝔼 i, (x i).toReal ^ 2) + ε.toReal) +
          Model.unitRoundoffAt .binary32) + Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) * Model.underflowErrorAt .binary32 * |(g j).toReal| +
        Model.underflowErrorAt .binary32) := by
  have hM : 0 ≤ 𝔼 i, (x i).toReal ^ 2 := Finset.expect_nonneg fun i _ => sq_nonneg _
  have es := Model.mixedError_toReal_add rfl hs
    (msq_error rfl t ht x hN hNn (Model.isFinite_of_isFinite_add rfl hs).1)
    (MixedError.of_eq (x₀ := ε.toReal) rfl)
  rw [abs_of_nonneg hM] at es
  have er := rsqrt_rel (es.mono le_rfl (le_of_eq (by ring))) (add_pos_of_nonneg_of_pos hM hε)
    hδ (by norm_num [Sem.rsqrtErr]) (Sem.rsqrt_close hs hz hsub hsg k).2
  have eo := rmsOut_error rfl er h
  rw [show (x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal) * (g j).toReal =
    (x j).toReal * (1 / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) * (g j).toReal by ring]
  exact eo

/-- **A widening cast is exact.** For all IEEE formats `fs` and `fd` such that `fd` has at least
`fs`'s exponent and fraction widths (binary16 or bfloat16 into binary32, for example), and every
finite word `x` of `fs`: the cast `Model.cast fs fd x` (to nearest) is finite and has `x`'s real
value. FloatLib's `Block.Working.cast_exact_of_grid`, whose premises (`fd`'s grid contains `fs`'s
and `fd`'s largest finite value is at least `fs`'s) follow from the widths with the IEEE bias
`2 ^ (e - 1) - 1` (`Model.toReal_posMaxFinite_ieee`). Formats with another encoding or bias
(FloatLib's finite-only and FNUZ formats) are not covered. -/
theorem cast_widen {fs fd : FloatFormat} (hs : fs.isIEEE = true) (hd : fd.isIEEE = true)
    (he : fs.expWidth ≤ fd.expWidth) (hf : fs.fracWidth ≤ fd.fracWidth) {x : Model fs}
    (hx : x.isFinite = true) :
    (Model.cast fs fd x).isFinite = true ∧ (Model.cast fs fd x).toReal = x.toReal := by
  obtain ⟨-, hbs⟩ := (FloatFormat.isIEEE_eq_true_iff fs).1 hs
  obtain ⟨-, hbd⟩ := (FloatFormat.isIEEE_eq_true_iff fd).1 hd
  have hb : fs.bias ≤ fd.bias :=
    Nat.sub_le_sub_right (Nat.pow_le_pow_right two_pos (Nat.sub_le_sub_right he 1)) 1
  refine Block.Working.cast_exact_of_grid x hx hf ?_ ?_
  · simp only [FloatFormat.minSubnormalExponent, FloatFormat.minNormalExponent, hbs, hbd,
      Int.ofNat_eq_natCast]
    omega
  · rw [Model.toReal_posMaxFinite_ieee fs hs, Model.toReal_posMaxFinite_ieee fd hd]
    simp only [FloatFormat.ieeeMaxNormalExponent, Model.pow2_eq_two_pow, Model.bpow, Flocq.bpow,
      FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal, Int.ofNat_eq_natCast]
    obtain ⟨k, hk⟩ := Nat.exists_eq_add_of_le hf
    have hA : (2 ^ (fs.fracWidth + 1) - 1) * 2 ^ k ≤ 2 ^ (fd.fracWidth + 1) - 1 := by
      have h1 : 1 ≤ 2 ^ k := Nat.one_le_two_pow
      rw [hk, Nat.sub_mul, one_mul, ← pow_add, show fs.fracWidth + k + 1 = fs.fracWidth + 1 + k by
        omega]
      omega
    calc (((2 ^ (fs.fracWidth + 1) - 1 : ℕ) : ℝ)) * (2 : ℝ) ^ ((fs.bias : ℤ) - fs.fracWidth)
        = (((2 ^ (fs.fracWidth + 1) - 1) * 2 ^ k : ℕ) : ℝ) *
            (2 : ℝ) ^ ((fs.bias : ℤ) - fd.fracWidth) := by
          rw [Nat.cast_mul, Nat.cast_pow, Nat.cast_ofNat, mul_assoc, ← zpow_natCast,
            ← zpow_add₀ two_ne_zero, hk]
          congr 2
          push_cast
          ring
      _ ≤ (((2 ^ (fd.fracWidth + 1) - 1 : ℕ) : ℝ)) * (2 : ℝ) ^ ((fs.bias : ℤ) - fd.fracWidth) := by
          gcongr
      _ ≤ (((2 ^ (fd.fracWidth + 1) - 1 : ℕ) : ℝ)) * (2 : ℝ) ^ ((fd.bias : ℤ) - fd.fracWidth) := by
          gcongr
          norm_num

/-- The RMS norm output word with a weight offset, in the two orders of Mojo's RMS norm kernels,
for an accumulator format `fa` and a dtype `fd`: the input `x`, the reciprocal word `r` and the
offset `o` in `fa`, the weight `g` in `fd`. Multiplied before the cast (`mbc`),
`cast fd ((x · r) · (cast fa g + o))`; otherwise `cast fd (x · r) · (g + cast fd o)`, the last
product and sum in `fd`. Each operation is FloatLib's, each cast `Model.cast` to nearest. -/
def rmsOff {fa fd : FloatFormat} (mbc : Bool) (x r o : Model fa) (g : Model fd) : Model fd :=
  if mbc then Model.cast fa fd (Model.mul (Model.mul x r) (Model.add (Model.cast fd fa g) o))
  else Model.mul (Model.cast fa fd (Model.mul x r)) (Model.add g (Model.cast fa fd o))

/-- The relative and absolute errors of `rmsOff_error`, for the unit roundoffs and underflow
allowances `ua`, `ηa` of the accumulator format and `ud`, `ηd` of the dtype, the reciprocal's
relative error `κ`, the exact product `y = x · w`, the weight `g` and the offset `o`. With
`p = (1 + ua) · κ + ua`, the relative error of the product `x · r`:
* multiplied before the cast, with `a = (1 + ua) · (ua · |g| + ηa)` the error of the shifted
  weight: `(1 + ud) · ((1 + ua) · (p + ua + p · ua) + ua) + ud` and
  `(1 + ud) · ((1 + ua) · ((1 + ua) · ηa · |g + o| + (1 + p) · a · |y| + ηa · a) + ηa) + ηd`;
* cast first, with `q = (1 + ud) · p + ud`, `c = (1 + ud) · ηa + ηd` and
  `b = (1 + ud) · (ud · |o| + ηd)`: `(1 + ud) · (q + ud + q · ud) + ud` and
  `(1 + ud) · ((1 + ud) · c · |g + o| + (1 + q) · b · |y| + c · b) + ηd`. -/
noncomputable def rmsOffErr (mbc : Bool) (ua ηa ud ηd κ y g o : ℝ) : ℝ × ℝ :=
  let p := (1 + ua) * κ + ua
  if mbc then
    let a := (1 + ua) * (ua * |g| + ηa)
    ((1 + ud) * ((1 + ua) * (p + ua + p * ua) + ua) + ud,
      (1 + ud) * ((1 + ua) * ((1 + ua) * ηa * |g + o| + (1 + p) * a * |y| + ηa * a) + ηa) + ηd)
  else
    let q := (1 + ud) * p + ud
    let c := (1 + ud) * ηa + ηd
    let b := (1 + ud) * (ud * |o| + ηd)
    ((1 + ud) * (q + ud + q * ud) + ud,
      (1 + ud) * ((1 + ud) * c * |g + o| + (1 + q) * b * |y| + c * b) + ηd)

/-- **The RMS norm output with a weight offset and a dtype.** For every IEEE accumulator format
`fa` and IEEE dtype `fd`, order `mbc`, words `x`, `r`, `o` of `fa` and `g` of `fd`, and reals
`w`, `κ` with `r` within relative error `κ` of `w`: if the output word `rmsOff mbc x r o g` is
finite, it is within FloatLib's mixed error `rmsOffErr mbc ua ηa ud ηd κ (x · w) g o` of
`x · w · (g + o)`. FloatLib's `Model.mixedError_toReal_mul`, `Model.mixedError_toReal_add` and
`Model.mixedError_toReal_cast` in the kernel's order; each cast is bounded as a rounding, also
where it is exact (a widening of the weight). Nothing is claimed when the output is infinite or a
NaN. -/
theorem rmsOff_error {fa fd : FloatFormat} (ha : fa.isIEEE = true) (hd : fd.isIEEE = true)
    (mbc : Bool) {x r o : Model fa} {g : Model fd} {w κ : ℝ} (hr : MixedError r.toReal w κ 0)
    (h : (rmsOff mbc x r o g).isFinite = true) :
    MixedError (rmsOff mbc x r o g).toReal (x.toReal * w * (g.toReal + o.toReal))
      (rmsOffErr mbc (Model.unitRoundoffAt fa) (Model.underflowErrorAt fa)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd) κ (x.toReal * w) g.toReal
        o.toReal).1
      (rmsOffErr mbc (Model.unitRoundoffAt fa) (Model.underflowErrorAt fa)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd) κ (x.toReal * w) g.toReal
        o.toReal).2 := by
  have e0 : MixedError x.toReal x.toReal 0 0 := MixedError.of_eq rfl
  cases mbc with
  | true =>
    simp only [rmsOff, rmsOffErr, ↓reduceIte] at h ⊢
    have hq := Model.isFinite_of_isFinite_cast hd h
    obtain ⟨hp, hs⟩ := Model.isFinite_of_isFinite_mul ha hq
    have hc := (Model.isFinite_of_isFinite_add ha hs).1
    have e1 := Model.mixedError_toReal_mul ha hp e0 hr
    have e2 := Model.mixedError_toReal_cast ha hc (MixedError.of_eq (x₀ := g.toReal) rfl)
    have e3 := Model.mixedError_toReal_add ha hs e2 (MixedError.of_eq (x₀ := o.toReal) rfl)
    have e5 := Model.mixedError_toReal_cast hd h (Model.mixedError_toReal_mul ha hq e1 e3)
    exact e5.mono (le_of_eq (by ring)) (le_of_eq (by ring))
  | false =>
    simp only [rmsOff, rmsOffErr, Bool.false_eq_true, ↓reduceIte] at h ⊢
    obtain ⟨hc, hs⟩ := Model.isFinite_of_isFinite_mul hd h
    have hp := Model.isFinite_of_isFinite_cast hd hc
    have ho := (Model.isFinite_of_isFinite_add hd hs).2
    have e1 := Model.mixedError_toReal_cast hd hc (Model.mixedError_toReal_mul ha hp e0 hr)
    have e2 := Model.mixedError_toReal_cast hd ho (MixedError.of_eq (x₀ := o.toReal) rfl)
    have e3 := Model.mixedError_toReal_add hd hs (MixedError.of_eq (x₀ := g.toReal) rfl) e2
    have e5 := Model.mixedError_toReal_mul hd h e1 e3
    exact e5.mono (le_of_eq (by ring)) (le_of_eq (by ring))

/-- The RMS norm word at `j` with a weight offset `o`, in the order `mbc` and the dtype `fd` of
Mojo's RMS norm kernels, accumulated in binary32: `rmsOff` of `x j`, `rsqrt.approx.ftz.f32` with
oracle number `k` of the mean of squares word `msq t x N` plus `ε`, the offset `o` and the
weight `g j` of the dtype. -/
def rmsnormOff {fd : FloatFormat} {n : ℕ} (mbc : Bool) (t : ReductionTree (Fin n))
    (x : Fin n → Model .binary32) (g : Fin n → Model fd) (N ε o : Model .binary32) (k : ℕ)
    (j : Fin n) : Model fd :=
  rmsOff mbc (x j) (Sem.rsqrt (Model.add (msq t x N) ε) k) o (g j)

-- The premise on the operand's error is `¬ 1 ≤ …`, not `… < 1`: a linter puts the type of every
-- hypothesis in weak head normal form, and `<` on reals unfolds into the arithmetic of binary32's
-- constants past the default recursion limit, while `¬` stops at the implication.
/-- **RMS norm with a weight offset and a dtype.** For every IEEE dtype `fd`, order `mbc`, `n`,
tree `t` whose leaves are `0, …, n - 1` up to order, binary32 inputs `x`, weights `g` of the
dtype, finite word `N` of real value `n`, words `ε > 0` and `o`, oracle number `k` of
`rsqrt.approx` and index `j`: under `rmsnorm_error`'s premises on the operand `m + ε` of
`rsqrt.approx` (the one on its error stated as `¬ 1 ≤ u + …`), if the output
`rmsnormOff mbc t x g N ε o k j` is finite, it is within FloatLib's mixed error
`rmsOffErr mbc u η ud ηd κ (x j / √(M + ε)) (g j) o` of the real RMS norm with the offset
`x j / √(M + ε) · (g j + o)` (`M = 𝔼 i, x i ^ 2`), with `rmsnorm_error`'s `κ`. The inputs are the
binary32 words the kernel computes with; `rmsnormOff_widen` states it at inputs of a narrower
format cast into binary32. `msq_error`, `Sem.rsqrt_close`, `rsqrt_rel` and `rmsOff_error`. Nothing
is claimed when the output is infinite or a NaN. -/
theorem rmsnormOff_error {fd : FloatFormat} (hd : fd.isIEEE = true) (mbc : Bool) {n : ℕ}
    (t : ReductionTree (Fin n)) (ht : t.leaves.Perm (List.finRange n))
    (x : Fin n → Model .binary32) (g : Fin n → Model fd) {N ε : Model .binary32}
    (hN : N.isFinite = true) (hNn : N.toReal = n) (o : Model .binary32) (k : ℕ)
    (hε : 0 < ε.toReal) (hs : (Model.add (msq t x N) ε).isFinite = true)
    (hz : (Model.add (msq t x N) ε).isZero = false)
    (hsub : (Model.add (msq t x N) ε).isSubnormal = false)
    (hsg : (Model.add (msq t x N) ε).signBit = false)
    (hδ : ¬ 1 ≤ Model.unitRoundoffAt .binary32 + (1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
          msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) t.depth
            (fun i => (x i).toReal)) / ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
    (j : Fin n) (h : (rmsnormOff mbc t x g N ε o k j).isFinite = true) :
    MixedError (rmsnormOff mbc t x g N ε o k j).toReal
      ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal) * ((g j).toReal + o.toReal))
      (rmsOffErr mbc (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd)
        (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
          ((1 + Model.unitRoundoffAt .binary32) *
            (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
              msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                t.depth (fun i => (x i).toReal)))
          ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
        ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) (g j).toReal o.toReal).1
      (rmsOffErr mbc (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd)
        (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
          ((1 + Model.unitRoundoffAt .binary32) *
            (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
              msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                t.depth (fun i => (x i).toReal)))
          ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
        ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) (g j).toReal o.toReal).2 := by
  have hM : 0 ≤ 𝔼 i, (x i).toReal ^ 2 := Finset.expect_nonneg fun i _ => sq_nonneg _
  have es := Model.mixedError_toReal_add rfl hs
    (msq_error rfl t ht x hN hNn (Model.isFinite_of_isFinite_add rfl hs).1)
    (MixedError.of_eq (x₀ := ε.toReal) rfl)
  rw [abs_of_nonneg hM] at es
  have es' : MixedError (Model.add (msq t x N) ε).toReal ((𝔼 i, (x i).toReal ^ 2) + ε.toReal)
      (Model.unitRoundoffAt .binary32) ((1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
          msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) t.depth
            (fun i => (x i).toReal))) :=
    es.mono le_rfl (le_of_eq (by ring))
  have hρ : (0 : ℝ) ≤ Sem.rsqrtErr := (Real.rpow_nonneg zero_le_two _).trans Sem.rpow_le_rsqrtErr
  have hw := (Sem.rsqrt_close hs hz hsub hsg k).2
  have er : MixedError (Sem.rsqrt (Model.add (msq t x N) ε) k).toReal
      (1 / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
      (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
        ((1 + Model.unitRoundoffAt .binary32) *
          (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
            msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
              t.depth (fun i => (x i).toReal)))
        ((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) 0 := by
    clear h
    generalize Model.unitRoundoffAt .binary32 = u at es' hδ ⊢
    generalize Model.underflowErrorAt .binary32 = η at es' hδ ⊢
    exact rsqrt_rel es' (add_pos_of_nonneg_of_pos hM hε) (not_le.1 hδ) hρ hw
  have eo := rmsOff_error rfl hd mbc er h
  rw [div_eq_mul_one_div (x j).toReal]
  exact eo


/-- **RMS norm with a weight offset and a dtype, at inputs of a narrower format.**
`rmsnormOff_error` at the binary32 words `Model.cast fs binary32 (x i)` of finite inputs `x` of an
IEEE format `fs` with at most binary32's exponent and fraction widths (binary16 and bfloat16 among
them), for every IEEE dtype `fd`, order `mbc`, `n`, tree `t` whose leaves are `0, …, n - 1` up to
order, weights `g` of the dtype, finite word `N` of real value `n`, words `ε > 0` and `o`, oracle
number `k` and index `j`, under `rmsnormOff_error`'s premises on the operand of `rsqrt.approx`:
its bound and the real RMS norm with the offset are stated with the real values of `x`, which the
casts keep (`cast_widen`). Nothing is claimed when the output is infinite or a NaN. -/
theorem rmsnormOff_widen {fs fd : FloatFormat} (hs : fs.isIEEE = true)
    (he : fs.expWidth ≤ FloatFormat.binary32.expWidth)
    (hf : fs.fracWidth ≤ FloatFormat.binary32.fracWidth) (hd : fd.isIEEE = true) (mbc : Bool)
    {n : ℕ} (t : ReductionTree (Fin n)) (ht : t.leaves.Perm (List.finRange n))
    (x : Fin n → Model fs) (hx : ∀ i, (x i).isFinite = true) (g : Fin n → Model fd)
    {N ε : Model .binary32} (hN : N.isFinite = true) (hNn : N.toReal = n) (o : Model .binary32)
    (k : ℕ) (hε : 0 < ε.toReal)
    (hs' : (Model.add (msq t (fun i => Model.cast fs .binary32 (x i)) N) ε).isFinite = true)
    (hz : (Model.add (msq t (fun i => Model.cast fs .binary32 (x i)) N) ε).isZero = false)
    (hsub : (Model.add (msq t (fun i => Model.cast fs .binary32 (x i)) N) ε).isSubnormal = false)
    (hsg : (Model.add (msq t (fun i => Model.cast fs .binary32 (x i)) N) ε).signBit = false)
    (hδ : ¬ 1 ≤ Model.unitRoundoffAt .binary32 + (1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
          msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) t.depth
            (fun i => (x i).toReal)) / ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
    (j : Fin n)
    (h : (rmsnormOff mbc t (fun i => Model.cast fs .binary32 (x i)) g N ε o k j).isFinite = true) :
    MixedError (rmsnormOff mbc t (fun i => Model.cast fs .binary32 (x i)) g N ε o k j).toReal
      ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal) * ((g j).toReal + o.toReal))
      (rmsOffErr mbc (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd)
        (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
          ((1 + Model.unitRoundoffAt .binary32) *
            (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
              msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                t.depth (fun i => (x i).toReal)))
          ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
        ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) (g j).toReal o.toReal).1
      (rmsOffErr mbc (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (Model.unitRoundoffAt fd) (Model.underflowErrorAt fd)
        (rsqrtRel (Model.unitRoundoffAt .binary32) (Sem.rsqrtErr : ℝ)
          ((1 + Model.unitRoundoffAt .binary32) *
            (Model.unitRoundoffAt .binary32 * 𝔼 i, (x i).toReal ^ 2 +
              msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                t.depth (fun i => (x i).toReal)))
          ((𝔼 i, (x i).toReal ^ 2) + ε.toReal))
        ((x j).toReal / √((𝔼 i, (x i).toReal ^ 2) + ε.toReal)) (g j).toReal o.toReal).2 := by
  have hv (i : Fin n) := (cast_widen hs rfl he hf (hx i)).2
  simpa only [hv] using rmsnormOff_error hd mbc t ht _ g hN hNn o k hε hs' hz hsub hsg
    (by simpa only [hv] using hδ) j h

end MojoProof.Float
