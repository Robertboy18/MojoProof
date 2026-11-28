import MojoProof.Float.Norm
import MojoProofTest.FloatWelford

/-!
# Instances of layer norm and RMS norm with `rsqrt.approx`

Tests in binary32 at the inputs `1, ..., n` (`iota n`, MojoProofTest/FloatStats.lean) with
weights `1` (`ones`), at `1, 2, 3, 4` (`xs`) along `pairs` unless stated. The finiteness and
normality premises are discharged by evaluation (`decide +kernel`), the premises on `u`, `η` and
`rsqrtErr` by normalizing FloatLib's binary32 constants.

* `lnorm_iota`: `lnorm_error` at `1, ..., 2 ^ k` along `halveFin k`, for every `k ≤ 24`, with the
  inputs' variance `((2 ^ k) ^ 2 - 1) / 12` (`var_iota`); `lndev_num`, a tactic, closes its
  premise on the operand's error at a concrete `k` and `ε`, and `rmsnorm_iota`'s. Its instances,
  tests of one example each, fused or not, with biases `0`: `lnorm_xs` at `k = 2` with `ε = 2.75`
  (`eps`), where the variance word is `1.25`, so `rsqrt.approx`'s operand is `4` and, under the
  oracle number of the word `0.5`, the output at `0` is `-0.75`; `lnorm8` at `k = 3` with
  `ε = 10.75`, where the real operand `V + ε` is `5.25 + 10.75 = 16`, under the oracle number of
  the word `0.25`.
* `rmsnorm_iota`: `rmsnorm_error` at `1, ..., 2 ^ k` along `halveFin k` with the divisor word
  `nat32 (2 ^ k)`, for every `k ≤ 24`, with the inputs' mean of squares
  `(2 ^ k + 1) · (2 · 2 ^ k + 1) / 6` (`msq_iota`). Its instances, tests of one example each:
  `rmsnorm_xs` at `k = 2` with `ε = 8.5` (`eps'`), where the mean of squares word is `7.5`, so the
  operand is `16` and, under the oracle number of the word `0.25`, the output at `0` is `0.25`;
  `rmsnorm8` at `k = 3` with `ε = 38.5`, where the real operand is `25.5 + 38.5 = 64`, under the
  oracle number of the word `0.125`.
* `rmsnormOff_error`'s instances, tests of one example each, with the offset `1`; `rmsoff_num`, a
  tactic, closes the premise on the operand's error: `rmsnormOff_bf16` at `1, 2, 3, 4` along
  `halveFin 2` with `ε = 8.5`, bfloat16 weights `1`, multiplied before the cast, under the
  oracle number of the word `0.25`; `rmsnormOff_f16` at `1, ..., 8` along `halveFin 3` with
  `ε = 38.5`, binary16 weights `1`, cast first, under the oracle number of the word `0.125`.
* `cast_widen`'s and `rmsnormOff_widen`'s instances, tests of one example each: `widen_words`, a
  binary16 and a bfloat16 word cast into binary32, finite with the same value, and its mutant
  `narrow16`, a binary32 word cast into binary16 whose value changes; `rmsnormOff_in16` and
  `rmsnormOff_inbf16`, `rmsnormOff_bf16`'s instance at the inputs `1, 2, 3, 4` in binary16 and in
  bfloat16 (`iotaIn`, with `iotaIn_toReal`) cast into binary32, cast first and multiplied first.
The real values, variance and mean of squares of `xs` (`xs_toReal`, `var_xs_eq`, `msq_xs_eq`) are
the instances at `4` of `iota_toReal`, `var_iota` and `msq_iota` (MojoProofTest/FloatStats.lean),
which hold at every length `n ≤ 2 ^ 24`; `var8` and `msq8` are their instances at `8`.
-/

namespace MojoProofTest.FloatNorm

open MojoProof.Float FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatTree MojoProofTest.FloatRel
  MojoProofTest.FloatStats MojoProofTest.FloatWelford
open scoped BigOperators

/-- Four binary32 words `+0`. -/
abbrev zeros : Fin 4 → Model .binary32 := fun _ => Model.posZero _

/-- The binary32 word `0x40300000` of `2.75`. -/
abbrev eps : Model .binary32 := f32 0x40300000

/-- The binary32 word `0x41080000` of `8.5`. -/
abbrev eps' : Model .binary32 := f32 0x41080000

/-- A binary32 word of rational value `q` has the real value `q`. -/
private theorem toReal_eq {w : Model .binary32} {q : ℚ} (h : w.toRat? = some q) :
    w.toReal = q :=
  Model.Algebraic.toReal_of_toRat?_eq_some h

/-- The real values of `xs` are `1, 2, 3, 4`: `iota_toReal` at `4`. -/
theorem xs_toReal (j : Fin 4) : (xs j).toReal = ![1, 2, 3, 4] j :=
  (iota_toReal (by norm_num) (by decide +kernel) j).trans (by fin_cases j <;> norm_num)

/-- The variance of `1, 2, 3, 4` is `5 / 4`: `var_iota` at `4`. -/
theorem var_xs_eq : TorchLean.var (fun j => (xs j).toReal) = 5 / 4 :=
  (var_iota (by norm_num) (by norm_num) (by decide +kernel)).trans (by norm_num)

/-- **The instance of `var_iota` at `1, ..., 8`**: the variance is `(8 ^ 2 - 1) / 12`. -/
theorem var8 := var_iota (n := 8) (by norm_num) (by norm_num) (by decide +kernel)

/-- The mean of the squares of `1, 2, 3, 4` is `15 / 2`: `msq_iota` at `4`. -/
theorem msq_xs_eq : 𝔼 i, (xs i).toReal ^ 2 = 15 / 2 :=
  (msq_iota (by norm_num) (by norm_num) (by decide +kernel)).trans (by norm_num)

/-- **The instance of `msq_iota` at `1, ..., 8`**: the mean of the squares is
`(8 + 1) · (2 · 8 + 1) / 6`. -/
theorem msq8 := msq_iota (n := 8) (by norm_num) (by norm_num) (by decide +kernel)

/-- `lndev_num` closes a premise `… < 1` of `lnorm_iota` or `rmsnorm_iota` at concrete `k` and
`e`: it unfolds `lnDev`, `welfErr` and `welfStep` where they occur and normalizes FloatLib's
binary32 constants `u = 2 ^ -24` and `η = 2 ^ -150`. -/
macro "lndev_num" : tactic => `(tactic| (
  try simp only [lnDev, welfErr, welfStep]
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]))

-- FloatLib's `unitRoundoffAt` and `underflowErrorAt` are powers `bpow 2 e`, and Mathlib v4.36.0
-- exposes `Real`'s operations to files outside the module system: a premise about these reals
-- in weak head normal form would unfold the powers past the default recursion limit. `bpow` is
-- irreducible here, so it is not unfolded.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **`lnorm_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24`, weights `g`,
biases `b`, word `ε` of rational value `e > 0`, oracle number `o` of `rsqrt.approx`, fused or not,
and index `j`: if the inputs' words, the Welford and variance words, the operand `v + ε` of
`rsqrt.approx` (finite, positive and normal) and the output at `j` are finite (`hw`) and
`u + lnDev u η 2 ^ k k V / (V + e) < 1` with the inputs' variance `V = ((2 ^ k) ^ 2 - 1) / 12`
(`var_iota`), then the output is within `lnorm_error`'s mixed error of TorchLean's real layer norm
at `j`. -/
theorem lnorm_iota (k : ℕ) (hk : k ≤ 24) (g b : Fin (2 ^ k) → Model .binary32)
    (ε : Model .binary32) {e : ℚ} (he : ε.toRat? = some e) (o : ℕ) (fused : Bool)
    (j : Fin (2 ^ k))
    (hw : (∀ j, (iota (2 ^ k) j).isFinite = true) ∧
      (welford (halveFin k) (iota _)).1.isFinite = true ∧
      (welford (halveFin k) (iota _)).2.1.isFinite = true ∧
      (welford (halveFin k) (iota _)).2.2.isFinite = true ∧
      (wvar (halveFin k) (iota _)).isFinite = true ∧
      (Model.add (wvar (halveFin k) (iota _)) ε).isFinite = true ∧
      (Model.add (wvar (halveFin k) (iota _)) ε).isZero = false ∧
      (Model.add (wvar (halveFin k) (iota _)) ε).isSubnormal = false ∧
      (Model.add (wvar (halveFin k) (iota _)) ε).signBit = false ∧
      (lnorm (halveFin k) (iota _) g b ε o fused j).isFinite = true)
    (hε : 0 < e)
    (hδ : Model.unitRoundoffAt .binary32 +
        lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k : ℕ) k
          ((((2 ^ k : ℕ) : ℝ) ^ 2 - 1) / 12) / ((((2 ^ k : ℕ) : ℝ) ^ 2 - 1) / 12 + e) < 1) :
    MixedError (lnorm (halveFin k) (iota _) g b ε o fused j).toReal
      (TorchLean.TransformerBlock.layerNorm (fun j => (g j).toReal) (fun j => (b j).toReal)
        ε.toReal (fun j => (iota (2 ^ k) j).toReal) j)
      (Model.unitRoundoffAt .binary32)
      (lnErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
        (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k : ℕ)
          (halveFin k).depth).1
        (rsqrtRel (Model.unitRoundoffAt .binary32) (MojoProof.Sem.rsqrtErr : ℝ)
          (lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k : ℕ)
            (halveFin k).depth (TorchLean.var fun j => (iota (2 ^ k) j).toReal))
          (TorchLean.var (fun j => (iota (2 ^ k) j).toReal) + ε.toReal))
        (1 / √(TorchLean.var (fun j => (iota (2 ^ k) j).toReal) + ε.toReal)) (g j).toReal
        ((iota (2 ^ k) j).toReal - 𝔼 i, (iota (2 ^ k) i).toReal)) := by
  obtain ⟨hf, h₁, h₂, h₃, hv, hs, hz, hsub, hsg, h⟩ := hw
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have hd : (halveFin k).depth = k := by rw [ReductionTree.depth_map, depth_halve]
  have hE : ε.toReal = e := toReal_eq he
  refine lnorm_error (halveFin k) (leaves_halveFin k) (iota _) g b (iota_bound hn hf) hn o fused
    h₁ h₂ h₃ hv (by rw [hE]; exact_mod_cast hε) hs hz hsub hsg ?_ j h
  rw [var_iota hn (Nat.two_pow_pos k) hf, hd, hE]
  exact hδ

/-- **The instance of `lnorm_iota` at `1, 2, 3, 4` along `pairs`**, a test of one example, fused
or not: weights `1`, biases `0`, `ε = 2.75` (`eps`) and the output at `0` under the oracle number
of the word `0.5`, its finiteness premises by evaluation and its premise on the operand's error by
`lndev_num`. -/
theorem lnorm_xs := fun fused => lnorm_iota 2 (by norm_num) ones zeros eps (e := 11 / 4)
  (by decide +kernel) 0x3f000000 fused (0 : Fin 4) (by cases fused <;> decide +kernel) (by norm_num)
  (by lndev_num)

/-- **The instance of `lnorm_iota` at `1, ..., 8` along `halveFin 3`**, a test of one example,
fused or not: weights `1`, biases `0`, `ε = 10.75`, so that the real operand `V + ε` of
`rsqrt.approx` is `5.25 + 10.75 = 16`, and the output at `0` under the oracle number of the word
`0.25`. -/
theorem lnorm8 := fun fused => lnorm_iota 3 (by norm_num) (fun _ => one) (fun _ => Model.posZero _)
  (f32 0x412C0000) (e := 43 / 4) (by decide +kernel) 0x3e800000 fused (0 : Fin 8)
  (by cases fused <;> decide +kernel) (by norm_num) (by lndev_num)

-- `bpow` is irreducible here, as above.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **`rmsnorm_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24`, weights `g`,
word `ε` of rational value `e > 0`, oracle number `o` of `rsqrt.approx` and index `j`, with the
divisor word `nat32 (2 ^ k)`: if the inputs' words, the divisor word, the operand `m + ε` of
`rsqrt.approx` (finite, positive and normal) and the output at `j` are finite (`hw`) and
`u + (1 + u) · (u · M + D) / (M + e) < 1` with the inputs' mean of squares
`M = (2 ^ k + 1) · (2 · 2 ^ k + 1) / 6` (`msq_iota`) and
`D = (1 + u) · (((1 + u) ^ k - 1) · M + (1 + u) ^ k · (u · M + η)) + η`, `msqErr` at these
inputs, then the output is within `rmsnorm_error`'s mixed error of the real RMS norm at `j`. -/
theorem rmsnorm_iota (k : ℕ) (hk : k ≤ 24) (g : Fin (2 ^ k) → Model .binary32)
    (ε : Model .binary32) {e : ℚ} (he : ε.toRat? = some e) (o : ℕ) (j : Fin (2 ^ k))
    (hw : (∀ j, (iota (2 ^ k) j).isFinite = true) ∧ (nat32 (2 ^ k)).isFinite = true ∧
      (Model.add (msq (halveFin k) (iota _) (nat32 (2 ^ k))) ε).isFinite = true ∧
      (Model.add (msq (halveFin k) (iota _) (nat32 (2 ^ k))) ε).isZero = false ∧
      (Model.add (msq (halveFin k) (iota _) (nat32 (2 ^ k))) ε).isSubnormal = false ∧
      (Model.add (msq (halveFin k) (iota _) (nat32 (2 ^ k))) ε).signBit = false ∧
      (rmsnorm (halveFin k) (iota _) g (nat32 (2 ^ k)) ε o j).isFinite = true)
    (hε : 0 < e)
    (hδ : Model.unitRoundoffAt .binary32 + (1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * ((2 ^ k + 1) * (2 * 2 ^ k + 1) / 6) +
          ((1 + Model.unitRoundoffAt .binary32) *
              (((1 + Model.unitRoundoffAt .binary32) ^ k - 1) *
                  ((2 ^ k + 1) * (2 * 2 ^ k + 1) / 6) +
                (1 + Model.unitRoundoffAt .binary32) ^ k *
                  (Model.unitRoundoffAt .binary32 * ((2 ^ k + 1) * (2 * 2 ^ k + 1) / 6) +
                    Model.underflowErrorAt .binary32)) +
            Model.underflowErrorAt .binary32)) /
        ((2 ^ k + 1) * (2 * 2 ^ k + 1) / 6 + (e : ℝ)) < 1) :
    MixedError (rmsnorm (halveFin k) (iota _) g (nat32 (2 ^ k)) ε o j).toReal
      ((iota (2 ^ k) j).toReal / √((𝔼 i, (iota (2 ^ k) i).toReal ^ 2) + ε.toReal) * (g j).toReal)
      ((1 + Model.unitRoundoffAt .binary32) * ((1 + Model.unitRoundoffAt .binary32) *
          rsqrtRel (Model.unitRoundoffAt .binary32) (MojoProof.Sem.rsqrtErr : ℝ)
            ((1 + Model.unitRoundoffAt .binary32) *
              (Model.unitRoundoffAt .binary32 * 𝔼 i, (iota (2 ^ k) i).toReal ^ 2 +
                msqErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
                  (halveFin k).depth (fun i => (iota (2 ^ k) i).toReal)))
            ((𝔼 i, (iota (2 ^ k) i).toReal ^ 2) + ε.toReal) +
          Model.unitRoundoffAt .binary32) + Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) * Model.underflowErrorAt .binary32 *
          |(g j).toReal| + Model.underflowErrorAt .binary32) := by
  obtain ⟨hf, hN, hs, hz, hsub, hsg, h⟩ := hw
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have hd : (halveFin k).depth = k := by rw [ReductionTree.depth_map, depth_halve]
  have hE : ε.toReal = e := toReal_eq he
  have : Nonempty (Fin (2 ^ k)) := ⟨j⟩
  refine rmsnorm_error (halveFin k) (leaves_halveFin k) (iota _) g hN (nat32_toReal hn hN) o
    (by rw [hE]; exact_mod_cast hε) hs hz hsub hsg (lt_of_eq_of_lt ?_ hδ) j h
  simp only [msqErr, Finset.expect_add_distrib, ← Finset.mul_expect, Fintype.expect_const,
    msq_iota hn (Nat.two_pow_pos k) hf, hd, hE, Nat.cast_pow, Nat.cast_ofNat]

/-- **The instance of `rmsnorm_iota` at `1, 2, 3, 4` along `pairs`**, a test of one example:
weights `1`, the divisor word `4`, `ε = 8.5` (`eps'`) and the output at `0` under the oracle number
of the word `0.25`, its finiteness premises by evaluation and its premise on the operand's error
by `lndev_num`. -/
theorem rmsnorm_xs := rmsnorm_iota 2 (by norm_num) ones eps' (e := 17 / 2) (by decide +kernel)
  0x3e800000 (0 : Fin 4) (by decide +kernel) (by norm_num) (by lndev_num)

/-- **The instance of `rmsnorm_iota` at `1, ..., 8` along `halveFin 3`**, a test of one example:
weights `1`, the divisor word `8`, `ε = 38.5`, so that the real operand `M + ε` of `rsqrt.approx`
is `25.5 + 38.5 = 64`, and the output at `0` under the oracle number of the word `0.125`. -/
theorem rmsnorm8 := rmsnorm_iota 3 (by norm_num) (fun _ => one) (f32 0x421A0000) (e := 77 / 2)
  (by decide +kernel) 0x3e000000 (0 : Fin 8) (by decide +kernel) (by norm_num) (by lndev_num)

/-- `rmsoff_num k ε e` closes `rmsnormOff_error`'s premise `¬ 1 ≤ …` at the inputs
`1, ..., 2 ^ k` along `halveFin k` and the word `ε` of rational value `e`: it rewrites the mean of
squares with `msq_iota`, the tree's depth to `k` and `ε` to `e`, then runs `lndev_num`. -/
macro "rmsoff_num " k:term:max ε:term:max e:term:max : tactic => `(tactic| (
  rw [not_le]
  have : Nonempty (Fin (2 ^ $k)) := ⟨⟨0, Nat.two_pow_pos _⟩⟩
  simp only [msqErr, Finset.expect_add_distrib, ← Finset.mul_expect, Fintype.expect_const,
    msq_iota (n := 2 ^ $k) (by norm_num) (Nat.two_pow_pos _) (by decide +kernel),
    ReductionTree.depth_map, depth_halve, toReal_eq (w := $ε) (q := $e) (by decide +kernel),
    Nat.cast_pow, Nat.cast_ofNat]
  lndev_num))

/-- **The instance of `rmsnormOff_error` at `1, 2, 3, 4` along `halveFin 2`, multiplied before
the cast into bfloat16**, a test of one example: bfloat16 weights `1` (`0x3f80`), the divisor
word `4`, `ε = 8.5` (`eps'`), the offset `1` and the output at `0` under the oracle number of the
word `0.25`, its finiteness premises by evaluation and its premise on the operand's error by
`rmsoff_num`. -/
theorem rmsnormOff_bf16 := rmsnormOff_error rfl true (halveFin 2) (leaves_halveFin 2) (iota _)
  (fun _ => (Model.ofNatBits 0x3f80 : Model .bfloat16)) (N := nat32 (2 ^ 2)) (ε := eps')
  (by decide +kernel) (nat32_toReal (by norm_num) (by decide +kernel)) one 0x3e800000
  (by rw [toReal_eq (q := 17 / 2) (by decide +kernel)]; norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel) (by rmsoff_num 2 eps' (17 / 2))
  ⟨0, by norm_num⟩ (by decide +kernel)

/-- **The instance of `rmsnormOff_error` at `1, ..., 8` along `halveFin 3`, cast into binary16
first**, a test of one example: binary16 weights `1` (`0x3c00`), the divisor word `8`,
`ε = 38.5`, so that the real operand `M + ε` of `rsqrt.approx` is `25.5 + 38.5 = 64`, the offset
`1` and the output at `0` under the oracle number of the word `0.125`. -/
theorem rmsnormOff_f16 := rmsnormOff_error rfl false (halveFin 3) (leaves_halveFin 3) (iota _)
  (fun _ => (Model.ofNatBits 0x3c00 : Model .binary16)) (N := nat32 (2 ^ 3))
  (ε := f32 0x421A0000) (by decide +kernel) (nat32_toReal (by norm_num) (by decide +kernel)) one
  0x3e000000 (by rw [toReal_eq (q := 77 / 2) (by decide +kernel)]; norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)
  (by rmsoff_num 3 (f32 0x421A0000) (77 / 2)) ⟨0, by norm_num⟩ (by decide +kernel)

/-- The inputs `1, ..., n` in the format `fs`: `iota n` cast into `fs`. -/
abbrev iotaIn (fs : FloatFormat) (n : ℕ) : Fin n → Model fs :=
  fun i => Model.cast .binary32 fs (iota n i)

/-- The real values of `iotaIn fs n` are those of `iota n`, for every IEEE format `fs` with at
most binary32's exponent and fraction widths, `n` and index `i`, when the words of `iotaIn fs n`
are finite and cast back into binary32 to those of `iota n`: `cast_widen`. -/
theorem iotaIn_toReal {fs : FloatFormat} (hs : fs.isIEEE = true)
    (he : fs.expWidth ≤ FloatFormat.binary32.expWidth)
    (hf : fs.fracWidth ≤ FloatFormat.binary32.fracWidth) {n : ℕ}
    (hx : ∀ i, (iotaIn fs n i).isFinite = true)
    (hc : ∀ i, Model.cast fs .binary32 (iotaIn fs n i) = iota n i) (i : Fin n) :
    (iotaIn fs n i).toReal = (iota n i).toReal :=
  (cast_widen hs rfl he hf (hx i)).2.symm.trans (congrArg Model.toReal (hc i))

/-- **`cast_widen` at a binary16 and a bfloat16 word**, a test of one example each: the binary16
word `0x3c01` (`1 + 2⁻¹⁰`) cast into binary32 is the word `0x3f802000` and the bfloat16 word
`0x3f81` (`1 + 2⁻⁷`) the word `0x3f810000`, by evaluation, and each cast is finite with the
real value of its input, by `cast_widen`. -/
theorem widen_words :
    Model.cast .binary16 .binary32 (Model.ofNatBits 0x3c01) = f32 0x3f802000 ∧
      Model.cast .bfloat16 .binary32 (Model.ofNatBits 0x3f81) = f32 0x3f810000 ∧
      ((Model.cast .binary16 .binary32 (Model.ofNatBits 0x3c01)).isFinite = true ∧
        (Model.cast .binary16 .binary32 (Model.ofNatBits 0x3c01)).toReal =
          (Model.ofNatBits 0x3c01 : Model .binary16).toReal) ∧
      ((Model.cast .bfloat16 .binary32 (Model.ofNatBits 0x3f81)).isFinite = true ∧
        (Model.cast .bfloat16 .binary32 (Model.ofNatBits 0x3f81)).toReal =
          (Model.ofNatBits 0x3f81 : Model .bfloat16).toReal) :=
  ⟨by decide +kernel, by decide +kernel, cast_widen rfl rfl (by decide) (by decide)
    (by decide +kernel), cast_widen rfl rfl (by decide) (by decide) (by decide +kernel)⟩

/-- **A narrowing cast changes a value**, the mutant of `widen_words`: binary16 has fewer
fraction bits than binary32, so `cast_widen` does not apply to the cast of binary32 into
binary16, and the binary32 word `0x3f800001` (`1 + 2⁻²³`) cast into binary16 is the word
`0x3c00` of `1`, whose real value differs. -/
theorem narrow16 :
    FloatFormat.binary16.fracWidth < FloatFormat.binary32.fracWidth ∧
      Model.cast .binary32 .binary16 (f32 0x3f800001) = Model.ofNatBits 0x3c00 ∧
      (Model.cast .binary32 .binary16 (f32 0x3f800001)).toReal ≠ (f32 0x3f800001).toReal := by
  refine ⟨by decide, by decide +kernel, ?_⟩
  rw [Model.Algebraic.toReal_of_toRat?_eq_some (q := 1) (by decide +kernel),
    toReal_eq (q := 1 + 1 / 2 ^ 23) (by decide +kernel)]
  norm_num

/-- **The instance of `rmsnormOff_widen` at the binary16 inputs `1, 2, 3, 4` (`iotaIn`) along
`halveFin 2`, cast into binary16 first**, a test of one example: binary16 weights `1`
(`0x3c00`), the divisor word `4`, `ε = 8.5` (`eps'`), the offset `1` and the output at `0` under
the oracle number of the word `0.25`, its finiteness premises by evaluation and its premise on
the operand's error by `rmsoff_num` after `iotaIn_toReal`. -/
theorem rmsnormOff_in16 := rmsnormOff_widen rfl (by decide) (by decide) rfl false (halveFin 2)
  (leaves_halveFin 2) (iotaIn .binary16 _) (by decide +kernel)
  (fun _ => (Model.ofNatBits 0x3c00 : Model .binary16)) (N := nat32 (2 ^ 2)) (ε := eps')
  (by decide +kernel) (nat32_toReal (by norm_num) (by decide +kernel)) one 0x3e800000
  (by rw [toReal_eq (q := 17 / 2) (by decide +kernel)]; norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)
  (by simp only [iotaIn_toReal (fs := .binary16) (n := 2 ^ 2) rfl (by decide) (by decide)
        (by decide +kernel) (by decide +kernel)]
      rmsoff_num 2 eps' (17 / 2))
  ⟨0, by norm_num⟩ (by decide +kernel)

/-- **The instance of `rmsnormOff_widen` at the bfloat16 inputs `1, 2, 3, 4` (`iotaIn`) along
`halveFin 2`, multiplied before the cast into bfloat16**, a test of one example: bfloat16
weights `1` (`0x3f80`), the divisor word `4`, `ε = 8.5` (`eps'`), the offset `1` and the output
at `0` under the oracle number of the word `0.25`. -/
theorem rmsnormOff_inbf16 := rmsnormOff_widen rfl (by decide) (by decide) rfl true (halveFin 2)
  (leaves_halveFin 2) (iotaIn .bfloat16 _) (by decide +kernel)
  (fun _ => (Model.ofNatBits 0x3f80 : Model .bfloat16)) (N := nat32 (2 ^ 2)) (ε := eps')
  (by decide +kernel) (nat32_toReal (by norm_num) (by decide +kernel)) one 0x3e800000
  (by rw [toReal_eq (q := 17 / 2) (by decide +kernel)]; norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)
  (by simp only [iotaIn_toReal (fs := .bfloat16) (n := 2 ^ 2) rfl (by decide) (by decide)
        (by decide +kernel) (by decide +kernel)]
      rmsoff_num 2 eps' (17 / 2))
  ⟨0, by norm_num⟩ (by decide +kernel)

/-- The output of `lnorm_xs` is the word `-0.75` and that of `rmsnorm_xs` the word `0.25`. -/
theorem outs_xs :
    lnorm pairs xs ones zeros eps 0x3f000000 false 0 = f32 0xbf400000 ∧
      lnorm pairs xs ones zeros eps 0x3f000000 true 0 = f32 0xbf400000 ∧
      rmsnorm pairs xs ones four eps' 0x3e800000 0 = f32 0x3e800000 := by
  decide +kernel

end MojoProofTest.FloatNorm
