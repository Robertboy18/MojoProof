import MojoProof.Sem.TensorCore
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.MixedError.Attribute
import FloatLib.Floats.Formats.BinaryInterchange.Algebraic.Rounding.DirectedEnclosureProof
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Finiteness

/-!
# A fused, truncating block accumulation for `mma` (docs/proofs/tensor-core.md)

An accumulation of the kind the ISA leaves open (section 9.7.16.5.14: at least single precision,
order and rounding unspecified), as a function over FloatLib's values: the input pairs are taken
`n` at a time, in order, and each block is one pass of an aligning adder from the running value
(C for the first block). The pass gives every addend an exponent (`expAt`: `⌊log₂ |x|⌋`, raised
to the format's least normal exponent, so a subnormal has the least normal exponent), the
product of a pair the sum of its factors' exponents; truncates every addend toward zero to a
multiple of `2^(E - p)`, `E` the largest exponent of a nonzero addend (`truncAt`, `fuseSum`);
adds them exactly; and rounds the sum toward zero into the accumulator's format with FloatLib's
`roundRat` (`fuseRound`): beyond the largest finite magnitude `M` and below `2^(emax + 1)` that
gives `M` with the sum's sign, and from `2^(emax + 1)` on the infinity of its sign.

Definitions: `expAt`, `truncAt`, `topExp`, `fuseSum`, `fuseRound`, `prodAddend`, `fuseStep`,
`fuseFold`, `fuseAcc fi fc n p` (the accumulation, for every pair of formats, block size `n` and
`p` bits below the largest addend's leading power), in `MojoProof.Sem.TensorCoreDef`, below the
grid, whose measured policy `gridAcc` is `fuseAcc fi fc 8 24`; `wt` (a word's magnitude raised
to the format's least normal number); `fuseRate` and `fuseBound` (its error bound).

Proved, for every `p`, every block size `n ≥ 1`, every input format and every IEEE accumulator
format: `abs_truncAt_sub_le`, `fuseSum_err` (a pass misses the exact sum by at most
`len · 2^-p · W`, for every bound `W` on the addends' powers of two), `fuseRound_err` (a finite
rounding is within FloatLib's toward-zero error), `fuseStep_err` (one block), `fuseFold_err` (all
blocks, by induction), and `fuseAcc_ok`: `fuseAcc fi fc n p` meets the contract `AccBy` with the
magnitudes `wt a_k · wt b_k` and `|c| + 2^emin` and the bound `fuseBound fc n p J`,
`J = ⌈K / n⌉` blocks; `gridAcc_ok`, its case at the measured policy `gridAcc`, blocks of 8
with 24 bits. That an A100's `mma.m16n8k16` with bfloat16 inputs computes
`fuseAcc .bfloat16 .binary32 8 24` is a measurement (tests/gpu/mma/record.txt), not a theorem.
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange

/-- Truncating `x` to a multiple of `2 ^ e` moves it by at most `2 ^ e`, for every `e` and `x`. -/
theorem abs_truncAt_sub_le (e : ℤ) (x : ℚ) : |truncAt e x - x| ≤ 2 ^ e := by
  have hq : (0 : ℚ) < 2 ^ e := zpow_pos (by norm_num) e
  have key : ∀ t : ℚ, |t - x / 2 ^ e| ≤ 1 → |t * 2 ^ e - x| ≤ 2 ^ e := by
    intro t ht
    have : t * 2 ^ e - x = (t - x / 2 ^ e) * 2 ^ e := by field_simp
    rw [this, abs_mul, abs_of_pos hq]
    exact mul_le_of_le_one_left hq.le ht
  unfold truncAt
  apply key
  split_ifs
  · have h1 := Int.floor_le (x / 2 ^ e)
    have h2 := Int.lt_floor_add_one (x / 2 ^ e)
    exact abs_le.mpr ⟨by linarith, by linarith⟩
  · have h1 := Int.le_ceil (x / 2 ^ e)
    have h2 := Int.ceil_lt_add_one (x / 2 ^ e)
    exact abs_le.mpr ⟨by linarith, by linarith⟩

private theorem sum_trunc_err (e : ℤ) (ys : List (ℚ × ℤ)) :
    |(ys.map fun x => truncAt e x.1).sum - (ys.map (·.1)).sum| ≤ ys.length * 2 ^ e := by
  induction ys with
  | nil => simp
  | cons y ys ih =>
    simp only [List.map_cons, List.sum_cons, List.length_cons, Nat.cast_succ]
    calc |truncAt e y.1 + (ys.map fun x => truncAt e x.1).sum - (y.1 + (ys.map (·.1)).sum)|
        = |(truncAt e y.1 - y.1) + ((ys.map fun x => truncAt e x.1).sum -
            (ys.map (·.1)).sum)| := by ring_nf
      _ ≤ |truncAt e y.1 - y.1| + |(ys.map fun x => truncAt e x.1).sum -
            (ys.map (·.1)).sum| := abs_add_le _ _
      _ ≤ 2 ^ e + ys.length * 2 ^ e := add_le_add (abs_truncAt_sub_le e y.1) ih
      _ = (ys.length + 1) * 2 ^ e := by ring

/-- **A pass misses the exact sum by at most `len · 2^-p · W`**: for every `p`, all addends `xs`
and every real `W ≥ 0` at least `2 ^ e` for each nonzero addend's exponent `e`, the pass's sum is
within `xs.length · 2^-p · W` of the exact sum of the values. -/
theorem fuseSum_err (p : ℕ) (xs : List (ℚ × ℤ)) {W : ℝ} (hW : 0 ≤ W)
    (h : ∀ x ∈ xs, x.1 ≠ 0 → (2 : ℝ) ^ x.2 ≤ W) :
    |(fuseSum p xs : ℝ) - (((xs.map (·.1)).sum : ℚ) : ℝ)| ≤ xs.length * (2 ^ (-(p : ℤ)) * W) := by
  unfold fuseSum
  split
  · rename_i hn
    have hnil : (xs.filter (·.1 ≠ 0)).map (·.2) = [] := List.max?_eq_none_iff.mp hn
    have hz : (xs.map (·.1)).sum = 0 := by
      apply List.sum_eq_zero
      intro v hv
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hv
      by_contra hne
      have hm : x.2 ∈ (xs.filter (·.1 ≠ 0)).map (·.2) :=
        List.mem_map.mpr ⟨x, List.mem_filter.mpr ⟨hx, by simpa using hne⟩, rfl⟩
      rw [hnil] at hm
      simp at hm
    rw [hz, Rat.cast_zero, sub_zero, abs_zero]
    positivity
  · rename_i E hE
    obtain ⟨x, hx, hxE⟩ := List.mem_map.mp (List.max?_mem hE)
    have hx' := List.mem_filter.mp hx
    have h2 : (2 : ℝ) ^ E ≤ W := by
      rw [← hxE]; exact h x hx'.1 (by simpa using hx'.2)
    have hq := sum_trunc_err (E - p) xs
    have hr := (Rat.cast_le (K := ℝ)).mpr hq
    rw [Rat.cast_abs, Rat.cast_sub, Rat.cast_mul, Rat.cast_natCast, Rat.cast_zpow,
      Rat.cast_ofNat] at hr
    have he : (2 : ℝ) ^ (E - p) = 2 ^ (-(p : ℤ)) * 2 ^ E := by
      rw [← zpow_add₀ two_ne_zero]; ring_nf
    calc _ ≤ (xs.length : ℝ) * (2 : ℝ) ^ (E - p) := hr
      _ ≤ xs.length * (2 ^ (-(p : ℤ)) * W) := by
        rw [he]; gcongr

/-- Beyond the largest finite magnitude `M` of an IEEE format and below `2^(emax + 1)`, `M` with
the sign of `s` is within `unitRoundoffIn fc .towardZero · |s|` of `s`. -/
private theorem maxFinite_err {fc : FloatFormat} (hfc : fc.isIEEE = true) {s : ℝ}
    (h1 : (Model.posMaxFinite fc).toReal < |s|)
    (h2 : |s| < (2 : ℝ) ^ (fc.maxNormalExponent + 1)) :
    |(Model.maxFinite fc (decide (s < 0))).toReal - s| ≤
      Model.unitRoundoffIn fc .towardZero * |s| := by
  set M := (Model.posMaxFinite fc).toReal with hMd
  set a : ℝ := (2 : ℝ) ^ fc.fracWidth with had
  set q : ℝ := (2 : ℝ) ^ (fc.maxNormalExponent - fc.fracWidth) with hqd
  have ha : 1 ≤ a := one_le_pow₀ (by norm_num)
  have hq : 0 < q := zpow_pos (by norm_num) _
  have hM : M = (2 * a - 1) * q := by
    rw [hMd, Model.toReal_posMaxFinite_ieee fc hfc, ← FloatFormat.maxNormalExponent_eq_ieee fc hfc,
      Model.pow2_eq_two_pow, Nat.cast_sub Nat.one_le_two_pow]
    simp only [Model.bpow, FloatLib.Floats.Formats.Flocq.bpow, Numerics.binaryRadix,
      Numerics.Radix.toReal, Int.ofNat_eq_natCast, had, hqd]
    push_cast
    ring
  have hB : (2 : ℝ) ^ (fc.maxNormalExponent + 1) = 2 * a * q := by
    have e : fc.maxNormalExponent + 1 =
        1 + (fc.fracWidth : ℤ) + (fc.maxNormalExponent - fc.fracWidth) := by ring
    rw [had, hqd, e, zpow_add₀ two_ne_zero, zpow_add₀ two_ne_zero, zpow_one, zpow_natCast]
  have hU : Model.unitRoundoffIn fc .towardZero = a⁻¹ := by
    have e : (2 : ℝ) ^ (-((fc.fracWidth : ℤ) + 1)) = ((2 : ℝ) ^ fc.fracWidth)⁻¹ * 2⁻¹ := by
      rw [zpow_neg, zpow_add_one₀ two_ne_zero, zpow_natCast, mul_inv]
    rw [Model.unitRoundoffIn, Model.unitRoundoffAt_eq, had, e]
    simp only [Model.IEEERoundingMode.halfUlps]
    push_cast
    ring
  have hres : |(Model.maxFinite fc (decide (s < 0))).toReal - s| = |s| - M := by
    rw [Model.toReal_maxFinite, ← hMd]
    rcases lt_or_ge s 0 with hs | hs
    · rw [abs_of_neg hs] at h1 ⊢
      rw [decide_eq_true hs]
      simp only [↓reduceIte, neg_one_mul]
      rw [abs_of_nonneg (by linarith)]
      ring
    · rw [abs_of_nonneg hs] at h1 ⊢
      rw [decide_eq_false (not_lt.mpr hs)]
      simp only [Bool.false_eq_true, ↓reduceIte, one_mul]
      rw [abs_of_nonpos (by linarith)]
      ring
  rw [hres, hU]
  have hb : a⁻¹ * a = 1 := inv_mul_cancel₀ (by linarith)
  have hb0 : 0 < a⁻¹ := inv_pos.mpr (by linarith)
  have e1 : a⁻¹ * M ≤ a⁻¹ * |s| := mul_le_mul_of_nonneg_left h1.le hb0.le
  have e2 : a⁻¹ * M = 2 * q - a⁻¹ * q := by linear_combination a⁻¹ * hM + (2 * q) * hb
  have e3 : a⁻¹ * q ≤ q := mul_le_of_le_one_left hq.le (inv_le_one_of_one_le₀ ha)
  rw [hB] at h2
  linarith

/-- Rounding the value of a finite word of `fc` gives it back, in every rounding mode. -/
private theorem roundAt_fix {fc : FloatFormat} {x : Model fc} (hx : x.isFinite = true)
    (mode : Model.IEEERoundingMode) : Model.roundAt fc x.toReal mode = x.toReal := by
  rw [Model.roundAt_eq_round]
  exact Flocq.round_preserves_generic _ _ (Model.toReal_genericFormat_of_isFinite x hx)

/-- **A finite rounding is within the toward-zero error**: in every IEEE format `fc`, for every
rational `s` whose `fuseRound` is finite, it is within `unitRoundoffIn fc .towardZero · |s| +
underflowErrorIn fc .towardZero` of `s`. -/
theorem fuseRound_err {fc : FloatFormat} (hfc : fc.isIEEE = true) (s : ℚ)
    (hf : (fuseRound fc s).isFinite = true) :
    |(fuseRound fc s).toReal - s| ≤
      Model.unitRoundoffIn fc .towardZero * |(s : ℝ)| + Model.underflowErrorIn fc .towardZero := by
  have hη : 0 ≤ Model.underflowErrorIn fc .towardZero := by
    have := Model.abs_roundAt_sub_le_mode fc 0 .towardZero
    simpa using this
  unfold fuseRound at hf ⊢
  split_ifs at hf ⊢ with h h'
  · rw [Model.AlgebraicRounding.roundRat_eq_roundReal] at hf ⊢
    by_cases hs : (s : ℝ) = 0
    · rw [hs, Model.roundReal_zero, Model.toReal_zero]
      simpa using hη
    · have hr := Model.roundReal_roundsTo (fmt := fc) .towardZero hs
      obtain ⟨m, hm, hmr⟩ := Model.Algebraic.exists_toRat?_of_isFinite
        (Model.isFinite_maxFinite fc false)
      have hM : |(s : ℝ)| ≤ (Model.posMaxFinite fc).toReal := by
        rw [show Model.posMaxFinite fc = Model.maxFinite fc false from rfl, hmr]
        rw [show Model.posMaxFinite fc = Model.maxFinite fc false from rfl, hm] at h
        exact_mod_cast (by simpa using h)
      have hfix := roundAt_fix (Model.isFinite_maxFinite fc false) .towardZero
      have hfix' := roundAt_fix (Model.isFinite_maxFinite fc true) .towardZero
      rw [Model.toReal_maxFinite] at hfix hfix'
      simp only [Bool.false_eq_true, ↓reduceIte, one_mul, neg_one_mul] at hfix hfix'
      have hin : |Model.roundAt fc (s : ℝ) .towardZero| ≤ (Model.posMaxFinite fc).toReal := by
        rcases abs_le.mp hM with ⟨h1, h2⟩
        have u := Model.roundAt_mono fc h2 .towardZero
        have l := Model.roundAt_mono fc h1 .towardZero
        rw [hfix] at u
        rw [hfix'] at l
        exact abs_le.mpr ⟨l, u⟩
      rw [(hr.finite hin).2]
      exact Model.abs_roundAt_sub_le_mode fc _ _
  · obtain ⟨m, hm, hmr⟩ := Model.Algebraic.exists_toRat?_of_isFinite
      (Model.isFinite_maxFinite fc false)
    have h0 : m < |s| := by
      rw [show Model.posMaxFinite fc = Model.maxFinite fc false from rfl, hm] at h
      simpa using h
    have h1 : (Model.posMaxFinite fc).toReal < |(s : ℝ)| := by
      rw [show Model.posMaxFinite fc = Model.maxFinite fc false from rfl, hmr]
      exact_mod_cast h0
    have h2 : |(s : ℝ)| < (2 : ℝ) ^ (fc.maxNormalExponent + 1) := by
      have := (Rat.cast_lt (K := ℝ)).mpr h'
      rwa [Rat.cast_abs, Rat.cast_zpow, Rat.cast_ofNat] at this
    have e := maxFinite_err hfc h1 h2
    rw [show decide ((s : ℝ) < 0) = decide (s < 0) by simp] at e
    exact e.trans (le_add_of_nonneg_right hη)
  · simp [Model.isFinite_nativeOverflow hfc] at hf

/-- The magnitude of a word `x` of format `f` for the adder's alignment: `|x|`, raised to `f`'s
least normal number `2 ^ emin`. -/
noncomputable def wt {f : FloatFormat} (x : Model f) : ℝ :=
  max |x.toReal| ((2 : ℝ) ^ f.minNormalExponent)

/-- The relative error of one pass over at most `n` pairs into `fc` with `p` bits:
`(n + 1) 2^-p (1 + U) + U`, with `U = unitRoundoffIn fc .towardZero`. -/
noncomputable def fuseRate (fc : FloatFormat) (n p : ℕ) : ℝ :=
  (n + 1) * (2 : ℝ) ^ (-(p : ℤ)) * (1 + Model.unitRoundoffIn fc .towardZero) +
    Model.unitRoundoffIn fc .towardZero

/-- The error bound of `J` passes at magnitude `W`: `((1 + α)^J - 1) (W + η / α)`, with
`α = fuseRate fc n p` and `η = underflowErrorIn fc .towardZero`. -/
noncomputable def fuseBound (fc : FloatFormat) (n p J : ℕ) (W : ℝ) : ℝ :=
  ((1 + fuseRate fc n p) ^ J - 1) * (W + Model.underflowErrorIn fc .towardZero / fuseRate fc n p)

private theorem two_zpow_expAt_le (f : FloatFormat) {u : ℚ} (hu : u ≠ 0) :
    (2 : ℝ) ^ expAt f u ≤ max |(u : ℝ)| ((2 : ℝ) ^ f.minNormalExponent) := by
  unfold expAt
  rcases le_total (Int.log 2 |u|) f.minNormalExponent with h | h
  · rw [max_eq_right h]; exact le_max_right _ _
  · rw [max_eq_left h]
    have := Int.zpow_log_le_self (b := 2) (r := |u|) (by norm_num) (abs_pos.mpr hu)
    have := (Rat.cast_le (K := ℝ)).mpr this
    rw [Rat.cast_zpow, Rat.cast_natCast, Nat.cast_ofNat, Rat.cast_abs] at this
    exact this.trans (le_max_left _ _)

private theorem toRat?_getD {f : FloatFormat} {x : Model f} (hx : x.isFinite = true) :
    ((x.toRat?.getD 0 : ℚ) : ℝ) = x.toReal := by
  obtain ⟨q, hq, hr⟩ := Model.Algebraic.exists_toRat?_of_isFinite hx
  rw [hq, hr]; rfl

private theorem abs_le_wt {f : FloatFormat} (x : Model f) : |x.toReal| ≤ wt x := le_max_left _ _

private theorem wt_nonneg {f : FloatFormat} (x : Model f) : 0 ≤ wt x :=
  (abs_nonneg _).trans (abs_le_wt x)

private theorem abs_sum_le {α : Type} (ps : List α) (f g : α → ℝ) (h : ∀ q ∈ ps, |f q| ≤ g q) :
    |(ps.map f).sum| ≤ (ps.map g).sum := by
  induction ps with
  | nil => simp
  | cons q ps ih =>
    simp only [List.map_cons, List.sum_cons]
    exact (abs_add_le _ _).trans (add_le_add (h q (by simp)) (ih fun q hq => h q (by simp [hq])))

private theorem abs_mul_le_wt {fi : FloatFormat} (x y : Model fi) :
    |x.toReal * y.toReal| ≤ wt x * wt y := by
  rw [abs_mul]; exact mul_le_mul (abs_le_wt x) (abs_le_wt y) (abs_nonneg _) (wt_nonneg x)

private theorem sum_wt_nonneg {fi : FloatFormat} (ps : List (Model fi × Model fi)) :
    0 ≤ (ps.map fun q => wt q.1 * wt q.2).sum :=
  List.sum_nonneg fun _ hx => by
    obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
    exact mul_nonneg (wt_nonneg _) (wt_nonneg _)

private theorem sum_prod_cast {fi : FloatFormat} (ps : List (Model fi × Model fi))
    (hps : ∀ q ∈ ps, q.1.isFinite = true ∧ q.2.isFinite = true) :
    ((((ps.map prodAddend).map (·.1)).sum : ℚ) : ℝ) =
      (ps.map fun q => q.1.toReal * q.2.toReal).sum := by
  induction ps with
  | nil => simp
  | cons y ps ih =>
    simp only [List.map_cons, List.sum_cons, Rat.cast_add]
    rw [ih fun q hq => hps q (by simp [hq])]
    congr 1
    simp only [prodAddend, Rat.cast_mul, toRat?_getD (hps y (by simp)).1,
      toRat?_getD (hps y (by simp)).2]

/-- **One pass**: in every IEEE format `fc`, for every `p` and `n`, a finite running value `r`
and at most `n` pairs `ps` of finite words of format `fi`, a finite result of `fuseStep p r ps`
is within `fuseRate fc n p · (|r| + 2^emin + Σ wt x · wt y) + η` of `r + Σ x y`. -/
theorem fuseStep_err {fi fc : FloatFormat} (hfc : fc.isIEEE = true) (n p : ℕ) {r : Model fc}
    (hr : r.isFinite = true) {ps : List (Model fi × Model fi)} (hn : ps.length ≤ n)
    (hps : ∀ q ∈ ps, q.1.isFinite = true ∧ q.2.isFinite = true)
    (hf : (fuseStep p r ps).isFinite = true) :
    |(fuseStep p r ps).toReal - (r.toReal + (ps.map fun q => q.1.toReal * q.2.toReal).sum)| ≤
      fuseRate fc n p * (|r.toReal| + (2 : ℝ) ^ fc.minNormalExponent +
        (ps.map fun q => wt q.1 * wt q.2).sum) + Model.underflowErrorIn fc .towardZero := by
  obtain ⟨q, hq, hqr⟩ := Model.Algebraic.exists_toRat?_of_isFinite hr
  have hstep :
      fuseStep p r ps = fuseRound fc (fuseSum p ((q, expAt fc q) :: ps.map prodAddend)) := by
    simp only [fuseStep, hq]
  rw [hstep] at hf ⊢
  set xs := (q, expAt fc q) :: ps.map prodAddend with hxs
  set W : ℝ := |r.toReal| + (2 : ℝ) ^ fc.minNormalExponent + (ps.map fun q => wt q.1 * wt q.2).sum
    with hWd
  have hU := (Model.unitRoundoffIn_pos fc .towardZero).le
  have hwsum := sum_wt_nonneg ps
  have hm : (0 : ℝ) < 2 ^ fc.minNormalExponent := zpow_pos (by norm_num) _
  have hW : 0 ≤ W := by positivity
  have hval : (((xs.map (·.1)).sum : ℚ) : ℝ) =
      r.toReal + (ps.map fun q => q.1.toReal * q.2.toReal).sum := by
    rw [hxs, List.map_cons, List.sum_cons, Rat.cast_add, sum_prod_cast ps hps, hqr]
  have hpow : ∀ x ∈ xs, x.1 ≠ 0 → (2 : ℝ) ^ x.2 ≤ W := by
    intro x hx hx0
    rcases List.mem_cons.mp hx with rfl | hx
    · dsimp only at hx0 ⊢
      have := two_zpow_expAt_le fc hx0
      rw [← hqr] at this
      have hle : max |r.toReal| ((2 : ℝ) ^ fc.minNormalExponent) ≤
          |r.toReal| + (2 : ℝ) ^ fc.minNormalExponent :=
        max_le (le_add_of_nonneg_right hm.le) (le_add_of_nonneg_left (abs_nonneg _))
      linarith
    · obtain ⟨y, hy, rfl⟩ := List.mem_map.mp hx
      simp only [prodAddend, ne_eq, mul_eq_zero, not_or] at hx0 ⊢
      rw [zpow_add₀ two_ne_zero]
      have ha : (2 : ℝ) ^ expAt fi (y.1.toRat?.getD 0) ≤ wt y.1 := by
        have := two_zpow_expAt_le fi hx0.1
        rwa [toRat?_getD (hps y hy).1] at this
      have hb : (2 : ℝ) ^ expAt fi (y.2.toRat?.getD 0) ≤ wt y.2 := by
        have := two_zpow_expAt_le fi hx0.2
        rwa [toRat?_getD (hps y hy).2] at this
      have hy' : wt y.1 * wt y.2 ≤ (ps.map fun q => wt q.1 * wt q.2).sum :=
        List.single_le_sum (fun _ hz => by
          obtain ⟨z, -, rfl⟩ := List.mem_map.mp hz
          exact mul_nonneg (wt_nonneg _) (wt_nonneg _)) _ (List.mem_map.mpr ⟨y, hy, rfl⟩)
      have := mul_le_mul ha hb (zpow_pos (by norm_num) _).le (wt_nonneg _)
      have : (0 : ℝ) ≤ |r.toReal| := abs_nonneg _
      linarith
  have hsum : |((fuseSum p xs : ℚ) : ℝ) - (((xs.map (·.1)).sum : ℚ) : ℝ)| ≤
      (n + 1) * ((2 : ℝ) ^ (-(p : ℤ)) * W) := by
    have hlen : (xs.length : ℝ) ≤ n + 1 := by
      rw [hxs]; simp only [List.length_cons, List.length_map]; exact_mod_cast Nat.succ_le_succ hn
    exact (fuseSum_err p xs hW hpow).trans (mul_le_mul_of_nonneg_right hlen (by positivity))
  have habs : |(((xs.map (·.1)).sum : ℚ) : ℝ)| ≤ W := by
    rw [hval]
    have h1 := abs_add_le r.toReal (ps.map fun q => q.1.toReal * q.2.toReal).sum
    have h2 := abs_sum_le ps (fun q => q.1.toReal * q.2.toReal) (fun q => wt q.1 * wt q.2)
      fun q _ => abs_mul_le_wt q.1 q.2
    linarith
  have hround := fuseRound_err hfc (fuseSum p xs) hf
  have hδ : 0 ≤ (n + 1) * ((2 : ℝ) ^ (-(p : ℤ)) * W) := by positivity
  have hs : |((fuseSum p xs : ℚ) : ℝ)| ≤ W + (n + 1) * ((2 : ℝ) ^ (-(p : ℤ)) * W) := by
    have := abs_sub_abs_le_abs_sub ((fuseSum p xs : ℚ) : ℝ) (((xs.map (·.1)).sum : ℚ) : ℝ)
    linarith
  rw [← hval]
  calc _ ≤ |(fuseRound fc (fuseSum p xs)).toReal - ((fuseSum p xs : ℚ) : ℝ)| +
        |((fuseSum p xs : ℚ) : ℝ) - (((xs.map (·.1)).sum : ℚ) : ℝ)| := abs_sub_le _ _ _
    _ ≤ (Model.unitRoundoffIn fc .towardZero * (W + (n + 1) * ((2 : ℝ) ^ (-(p : ℤ)) * W)) +
          Model.underflowErrorIn fc .towardZero) + (n + 1) * ((2 : ℝ) ^ (-(p : ℤ)) * W) :=
        add_le_add (hround.trans (by gcongr)) hsum
    _ = _ := by unfold fuseRate; ring

private theorem fuseStep_finite {fi fc : FloatFormat} (p : ℕ) {r : Model fc}
    (ps : List (Model fi × Model fi)) (h : (fuseStep p r ps).isFinite = true) :
    r.isFinite = true := by
  unfold fuseStep at h
  cases hq : r.toRat? with
  | none => rw [hq] at h; exact h
  | some q => exact Model.Algebraic.isFinite_of_toRat?_eq_some hq

private theorem fuseFold_finite {fi fc : FloatFormat} (n p : ℕ) :
    ∀ (J : ℕ) (r : Model fc) (ps : List (Model fi × Model fi)),
      (fuseFold n p J r ps).isFinite = true → r.isFinite = true
  | 0, _, _, h => h
  | J + 1, _, _, h => fuseStep_finite p _ (fuseFold_finite n p J _ _ h)

/-- **All passes**: in every IEEE format `fc`, for every `n`, `p` and `J`, a finite `r` and at
most `J · n` pairs `ps` of finite words of format `fi`, a finite result of `fuseFold n p J r ps`
is within `((1 + α)^J - 1) (|r| + 2^emin + Σ wt x · wt y + η / α)` of `r + Σ x y`, with
`α = fuseRate fc n p` and `η = underflowErrorIn fc .towardZero`. -/
theorem fuseFold_err {fi fc : FloatFormat} (hfc : fc.isIEEE = true) (n p : ℕ) :
    ∀ (J : ℕ) (r : Model fc) (ps : List (Model fi × Model fi)), r.isFinite = true →
      (∀ q ∈ ps, q.1.isFinite = true ∧ q.2.isFinite = true) → ps.length ≤ J * n →
      (fuseFold n p J r ps).isFinite = true →
      |(fuseFold n p J r ps).toReal - (r.toReal + (ps.map fun q => q.1.toReal * q.2.toReal).sum)| ≤
        ((1 + fuseRate fc n p) ^ J - 1) * (|r.toReal| + (2 : ℝ) ^ fc.minNormalExponent +
          (ps.map fun q => wt q.1 * wt q.2).sum +
            Model.underflowErrorIn fc .towardZero / fuseRate fc n p)
  | 0, r, ps, _, _, hl, _ => by
    have : ps = [] := List.eq_nil_of_length_eq_zero (by simpa using hl)
    subst this
    simp [fuseFold]
  | J + 1, r, ps, hr, hps, hl, hf => by
    have hU := Model.unitRoundoffIn_pos fc .towardZero
    have hα : 0 < fuseRate fc n p := by unfold fuseRate; positivity
    have hη : 0 ≤ Model.underflowErrorIn fc .towardZero := by
      have := Model.abs_roundAt_sub_le_mode fc 0 .towardZero
      simpa using this
    have hf' : (fuseStep p r (ps.take n)).isFinite = true := fuseFold_finite n p J _ _ hf
    have e1 := fuseStep_err hfc n p hr (List.length_take_le n ps)
      (fun q hq => hps q (List.mem_of_mem_take hq)) hf'
    have e2 := fuseFold_err hfc n p J _ (ps.drop n) hf'
      (fun q hq => hps q (List.mem_of_mem_drop hq))
      (by rw [List.length_drop]; rw [Nat.succ_mul] at hl; omega) hf
    have hsplit : ∀ f : Model fi × Model fi → ℝ,
        (ps.map f).sum = ((ps.take n).map f).sum + ((ps.drop n).map f).sum := fun f => by
      rw [← List.sum_append, ← List.map_append, List.take_append_drop]
    show |(fuseFold n p J (fuseStep p r (ps.take n)) (ps.drop n)).toReal - _| ≤ _
    rw [hsplit, hsplit (fun q => wt q.1 * wt q.2)]
    generalize fuseFold n p J (fuseStep p r (ps.take n)) (ps.drop n) = F at e2 ⊢
    generalize fuseStep p r (ps.take n) = r' at e1 e2
    have hW1 := abs_sum_le (ps.take n) (fun q => q.1.toReal * q.2.toReal)
      (fun q => wt q.1 * wt q.2) fun q _ => abs_mul_le_wt q.1 q.2
    have hW2 := sum_wt_nonneg (ps.drop n)
    generalize ((ps.take n).map fun q => q.1.toReal * q.2.toReal).sum = S1 at e1 hW1 ⊢
    generalize ((ps.drop n).map fun q => q.1.toReal * q.2.toReal).sum = S2 at e2 ⊢
    generalize ((ps.take n).map fun q => wt q.1 * wt q.2).sum = W1 at e1 hW1 ⊢
    generalize ((ps.drop n).map fun q => wt q.1 * wt q.2).sum = W2 at e2 hW2 ⊢
    have hη' : Model.underflowErrorIn fc .towardZero =
        fuseRate fc n p * (Model.underflowErrorIn fc .towardZero / fuseRate fc n p) := by
      field_simp
    generalize Model.underflowErrorIn fc .towardZero / fuseRate fc n p = c at e2 hη' ⊢
    generalize Model.underflowErrorIn fc .towardZero = η at e1 hη hη'
    subst hη'
    generalize fuseRate fc n p = α at e1 e2 hα hη ⊢
    have hc : 0 ≤ c := by
      by_contra h; have := not_le.mp h; nlinarith
    have hm : (0 : ℝ) < 2 ^ fc.minNormalExponent := zpow_pos (by norm_num) _
    generalize (2 : ℝ) ^ fc.minNormalExponent = m at e1 e2 hm ⊢
    have hP : 1 ≤ (1 + α) ^ J := one_le_pow₀ (by linarith)
    rw [pow_succ]
    generalize (1 + α) ^ J = P at e2 hP ⊢
    have hr' : |r'.toReal| ≤ |r.toReal| + W1 + (α * (|r.toReal| + m + W1) + α * c) := by
      have := abs_sub_abs_le_abs_sub r'.toReal (r.toReal + S1)
      have := abs_add_le r.toReal S1
      linarith
    have hX : 0 ≤ |r.toReal| + m + W1 := by
      have := abs_nonneg r.toReal; have := (abs_nonneg S1).trans hW1; linarith
    have e2' : |F.toReal - (r'.toReal + S2)| ≤
        (P - 1) * (|r.toReal| + W1 + (α * (|r.toReal| + m + W1) + α * c) + m + W2 + c) :=
      e2.trans (mul_le_mul_of_nonneg_left (by linarith) (by linarith))
    have htri : |F.toReal - (r.toReal + (S1 + S2))| ≤
        |F.toReal - (r'.toReal + S2)| + |r'.toReal - (r.toReal + S1)| := by
      calc _ = |(F.toReal - (r'.toReal + S2)) + (r'.toReal - (r.toReal + S1))| := by ring_nf
        _ ≤ _ := abs_add_le _ _
    have hPW : 0 ≤ P * α * W2 := mul_nonneg (mul_nonneg (by linarith) hα.le) hW2
    nlinarith

/-- **The fused block accumulation meets the contract**: in every IEEE accumulator format `fc`,
for every input format `fi`, block size `n ≥ 1`, `p` and `K`, `fuseAcc fi fc n p` meets `AccBy`
with the magnitudes `wt a_k · wt b_k` and `|c| + 2^emin` and the bound
`fuseBound fc n p ⌈K / n⌉`. -/
theorem fuseAcc_ok {fi fc : FloatFormat} (hfc : fc.isIEEE = true) {n : ℕ} (hn : 0 < n) (p : ℕ)
    {K : ℕ} :
    AccBy (K := K) (fun x y => wt x * wt y) (fun c => |c.toReal| + 2 ^ fc.minNormalExponent)
      (fuseBound fc n p ((K + n - 1) / n)) (fuseAcc fi fc n p) := by
  intro a b c ha hb hc hf
  have hK : (List.ofFn fun k => (a k, b k)).length ≤ (K + n - 1) / n * n := by
    rw [List.length_ofFn, Nat.mul_comm]
    have h1 := Nat.div_add_mod (K + n - 1) n
    have h2 := Nat.mod_lt (K + n - 1) hn
    generalize (K + n - 1) / n = q at h1 ⊢
    generalize n * q = t at h1 ⊢
    omega
  have e := fuseFold_err hfc n p ((K + n - 1) / n) c (List.ofFn fun k => (a k, b k)) hc
    (fun q hq => by
      obtain ⟨k, rfl⟩ := List.mem_ofFn.mp hq
      exact ⟨ha k, hb k⟩) hK hf
  simp only [List.map_ofFn, List.sum_ofFn, Function.comp_def] at e
  beta_reduce
  rw [add_comm (∑ k, (a k).toReal * (b k).toReal)]
  refine e.trans (le_of_eq ?_)
  unfold fuseBound
  ring

/-- **The measured policy meets the contract**: `fuseAcc_ok` at `gridAcc`, blocks of 8 with 24
bits, in every IEEE accumulator format `fc`, for every input format `fi` and `K`. -/
theorem gridAcc_ok {fi fc : FloatFormat} (hfc : fc.isIEEE = true) {K : ℕ} :
    AccBy (K := K) (fun x y => wt x * wt y) (fun c => |c.toReal| + 2 ^ fc.minNormalExponent)
      (fuseBound fc 8 24 ((K + 8 - 1) / 8)) (gridAcc fi fc) :=
  fuseAcc_ok hfc (by norm_num) 24

end MojoProof.Sem
