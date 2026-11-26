import MojoProof.Float.Canon
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.StandardModel
import FloatLib.Floats.Formats.BinaryInterchange.Model.Instances
import FloatLib.Floats.Formats.BinaryInterchange.DirectedSemantics.Exact

/-!
# Trees whose IEEE sums agree have the same canonical form (docs/proofs/float-reductions.md)

`MojoProof.Float.eval_nanEq_of_canon` says that two reduction trees with the same `canon` agree
up to NaN payloads on every input. This module proves the converse for trees over the same
distinct leaves, in every IEEE format: `eval_add_eq_iff`.

The witness is DistLean's (`DistLean.Bracket.ieeeWitness` and its symmetric form), in both orders
of each sum. With `f` fraction bits and `ε = 2^-f` (`eps`): `+0` is an identity on `+0`, `ε`, `2`
and `-2` on both sides, `ε + 2` and `2 + ε` round to `2` (a halfway case, to the even
neighbour), and `2 + -2` and `-2 + 2` are `+0`. So `ε + (2 + -2)` is `ε` and `(ε + 2) + -2` is
`+0`, whichever order each sum takes its operands in, and `ε` and `+0` are different words that
are not NaNs.

The separating input (`exists_eval_sep`), by induction on the first tree: at two nodes whose
roots split the leaves differently there are three leaves `a, b, c` with `b, c` under one child of
the first root and `a` under the other, and `a, b` under one child of the second root and `c`
under the other; `ε, 2, -2` on them and `+0` elsewhere give `ε` and `+0`. At two nodes whose roots
split the leaves alike, the two children whose `canon` differ (`canon_node_eq_iff`) give an input,
and `+0` on the other children's leaves keeps their results.

Proved, for every IEEE format, leaf type with a linear order and two trees over the same leaves
without repeats:
* `eval_add_eq_iff`: the two trees agree up to NaN payloads on every input exactly when they have
  the same `canon`.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem

section Witness

variable {fmt : FloatFormat}

/-- In every IEEE format the largest exponent of a normal value is at least `1`. -/
private theorem one_le_maxNormalExponent (hfmt : fmt.isIEEE = true) :
    1 ≤ fmt.maxNormalExponent := by
  rw [FloatFormat.maxNormalExponent_eq_ieee fmt hfmt]
  have := FloatFormat.bias_pos fmt
  simp only [FloatFormat.ieeeMaxNormalExponent, Int.ofNat_eq_natCast]
  omega

/-- In every format the exponent of the least subnormal value is at most `-f`, with `f` the
fraction bits. -/
private theorem minSubnormalExponent_le : fmt.minSubnormalExponent ≤ -(fmt.fracWidth : ℤ) := by
  have := fmt.exponentBias_pos
  simp only [FloatFormat.minSubnormalExponent, FloatFormat.minNormalExponent,
    Int.ofNat_eq_natCast]
  omega

/-- In every IEEE format the largest finite value, $(2-2^{-f})2^{b}$ with the bias `b ≥ 1`, is at
least $2+2^{1-f}$. -/
private theorem two_add_le_maxFinite (hfmt : fmt.isIEEE = true) :
    2 + 2 * (2 : ℝ) ^ (-(fmt.fracWidth : ℤ)) ≤ Model.toReal (Model.posMaxFinite fmt) := by
  have hf := fmt.fracWidth_pos
  have h := Model.abs_signed_mul_bpow_le_toReal_posMaxFinite fmt false (2 ^ fmt.fracWidth + 1)
    (1 - fmt.fracWidth) ?_ ?_
  · refine le_of_eq_of_le ?_ h
    simp only [Bool.false_eq_true, ite_false, one_mul, Model.bpow, Flocq.bpow,
      FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal]
    push_cast
    rw [abs_of_nonneg (by positivity), zpow_sub₀ (by norm_num), zpow_one, zpow_neg, zpow_natCast]
    field_simp
  · have : 2 ≤ 2 ^ fmt.fracWidth := by
      calc 2 = 2 ^ 1 := rfl
        _ ≤ 2 ^ fmt.fracWidth := Nat.pow_le_pow_right (by norm_num) hf
    simp only [Model.pow2_eq_two_pow, FloatFormat.maxFiniteFracField,
      FloatFormat.encoding_eq_ieee_of_isIEEE fmt hfmt, FloatFormat.fracMaskNat]
    omega
  · have := one_le_maxNormalExponent hfmt
    simp only [Int.ofNat_eq_natCast]
    omega

/-- The witness value `ε = 2^-f` of a format with `f` fraction bits, the word that rounding the
dyadic `1 · 2^-f` gives. -/
private def eps (fmt : FloatFormat) : Model fmt :=
  Model.roundDyadic fmt ⟨false, 1, -(fmt.fracWidth : ℤ)⟩

/-- In every IEEE format `ε` is finite with value `2^-f`. -/
private theorem eps_spec (hfmt : fmt.isIEEE = true) :
    (eps fmt).isFinite = true ∧ (eps fmt).toReal = 2 ^ (-(fmt.fracWidth : ℤ)) := by
  have hf := fmt.fracWidth_pos
  have h := Model.Internal.Directed.roundDyadic_of_representable fmt hfmt .nearest
    ⟨false, 1, -(fmt.fracWidth : ℤ)⟩ (Nat.one_lt_two_pow (by omega)) minSubnormalExponent_le ?_
  · exact ⟨h.1, h.2.trans (by simp)⟩
  · have := two_add_le_maxFinite hfmt
    have hp : (0 : ℝ) < 2 ^ (-(fmt.fracWidth : ℤ)) := by positivity
    simp only [FloatLib.Numerics.Dyadic.toReal_mk_false, Nat.cast_one, one_mul]
    rw [abs_of_pos hp]
    linarith

/-- In every IEEE format `2` is finite with value `2`. -/
private theorem two_spec (hfmt : fmt.isIEEE = true) :
    (2 : Model fmt).isFinite = true ∧ (2 : Model fmt).toReal = 2 := by
  have hf := fmt.fracWidth_pos
  have h := Model.Internal.Directed.roundDyadic_of_representable fmt hfmt .nearest
    ⟨false, 2, 0⟩ ?_ ?_ ?_
  · exact ⟨h.1, h.2.trans (by simp)⟩
  · calc 2 < 2 ^ 2 := by norm_num
      _ ≤ 2 ^ (fmt.fracWidth + 1) := Nat.pow_le_pow_right (by norm_num) (by omega)
  · have := minSubnormalExponent_le (fmt := fmt)
    change fmt.minSubnormalExponent ≤ 0
    omega
  · have := two_add_le_maxFinite hfmt
    have hp : (0 : ℝ) < 2 ^ (-(fmt.fracWidth : ℤ)) := by positivity
    simp only [FloatLib.Numerics.Dyadic.toReal_mk_false]
    norm_num
    linarith

/-- In every IEEE format `-2` is finite with value `-2`. -/
private theorem negTwo_spec (hfmt : fmt.isIEEE = true) :
    (-2 : Model fmt).isFinite = true ∧ (-2 : Model fmt).toReal = -2 := by
  change (Model.neg 2).isFinite = true ∧ (Model.neg 2).toReal = -2
  rw [Model.isFinite_neg, Model.toReal_neg _ (two_spec hfmt).1, (two_spec hfmt).2]
  exact ⟨(two_spec hfmt).1, rfl⟩

/-- In every IEEE format, adding `+0` on either side leaves a finite nonzero value unchanged, bit
for bit. -/
private theorem zero_identity (hfmt : fmt.isIEEE = true) {x : Model fmt}
    (hx : x.isFinite = true) (h0 : x.toReal ≠ 0) :
    Model.add x 0 = x ∧ Model.add 0 x = x := by
  have hz : (0 : Model fmt).isFinite = true := Model.isFinite_posZero fmt
  have hz0 : (0 : Model fmt).toReal = 0 := Model.toReal_posZero fmt
  have hb := Model.abs_toReal_le_posMaxFinite_of_isFinite x hx
  constructor
  · have hfin : (x + 0).isFinite = true :=
      Model.isFinite_add_of_abs_add_le_posMaxFinite x 0 hfmt hx hz (by
        rw [hz0, abs_zero, add_zero]; exact hb)
    have hval : (Model.add x 0).toReal = x.toReal := by
      rw [Model.toReal_add_eq_roundAt x 0 hfmt hfin, hz0, add_zero, Model.roundAt_toReal_eq x hx]
    exact Model.eq_of_toReal_eq_of_nonzero hval (hval ▸ h0)
  · have hfin : (0 + x).isFinite = true :=
      Model.isFinite_add_of_abs_add_le_posMaxFinite 0 x hfmt hz hx (by
        rw [hz0, abs_zero, zero_add]; exact hb)
    have hval : (Model.add 0 x).toReal = x.toReal := by
      rw [Model.toReal_add_eq_roundAt 0 x hfmt hfin, hz0, zero_add, Model.roundAt_toReal_eq x hx]
    exact Model.eq_of_toReal_eq_of_nonzero hval (hval ▸ h0)

/-- In every format, the sum of two finite values rounds the exact sum of their dyadics. -/
private theorem add_eq_roundDyadic {x y : Model fmt} {dx dy : FloatLib.Numerics.Dyadic}
    (hx : x.toDyadic? = some dx) (hy : y.toDyadic? = some dy) :
    Model.add x y = Model.roundDyadic fmt (Model.addDyadic dx dy) := by
  simp [Model.Proof.add_eq_spec, Model.Spec.add, hx, hy]

/-- In every format, rounding the dyadic `+0 · 2^0` gives `+0`. -/
private theorem roundDyadic_zero :
    Model.roundDyadic fmt ⟨false, 0, 0⟩ = (0 : Model fmt) :=
  (Model.Internal.Directed.roundDyadic_zero fmt .nearest false 0).trans (by simp [Model.zero])

/-- In every format `+0 + +0` is `+0`. -/
private theorem zero_add_zero : Model.add (0 : Model fmt) 0 = 0 := by
  have hz : (0 : Model fmt).toDyadic? = some ⟨false, 0, 0⟩ := by
    simpa [Model.zero] using
      Model.toDyadic?_eq_zero_of_isZero_eq_true (0 : Model fmt) (Model.isZero_zero fmt false)
  rw [add_eq_roundDyadic hz hz]
  exact roundDyadic_zero

/-- In every IEEE format, a finite value and its negation add up to `+0` in both orders: an exact
zero sum of operands of opposite signs rounds to `+0` to nearest. -/
private theorem add_neg_zero (hfmt : fmt.isIEEE = true) {x : Model fmt}
    (hx : x.isFinite = true) : Model.add x (-x) = 0 ∧ Model.add (-x) x = 0 := by
  obtain ⟨d, hd⟩ := Model.exists_toDyadic?_of_isFinite hx
  have hs : fmt.supportsSignedZero = true :=
    FloatFormat.supportsSignedZero_eq_true_of_isIEEE fmt hfmt
  have hn := Model.toDyadic?_neg_of_toDyadic?_some x hd
  change Model.add x (Model.neg x) = 0 ∧ Model.add (Model.neg x) x = 0
  rw [add_eq_roundDyadic hd hn, add_eq_roundDyadic hn hd]
  obtain ⟨n, m, e⟩ := d
  constructor <;> convert roundDyadic_zero using 2 <;> cases n <;> by_cases hm : m = 0 <;>
    simp [Model.negDyadic, hs, Model.addDyadic, FloatLib.Numerics.Dyadic.add,
      FloatLib.Numerics.Dyadic.addFields, hm]

open FloatLib.Floats.Formats.Flocq in
/-- In every format, $2+2^{-f}$, which lies halfway between `2` and the next value
$2+2^{1-f}$, rounds to `2`, whose last significand bit is even. -/
private theorem roundAt_two_add :
    Model.roundAt fmt (2 + 2 ^ (-(fmt.fracWidth : ℤ))) = 2 := by
  have hf : 1 ≤ fmt.fracWidth := fmt.fracWidth_pos
  have hq : (2 : ℝ) ^ (-(fmt.fracWidth : ℤ)) = ((2 : ℝ) ^ fmt.fracWidth)⁻¹ := by
    rw [zpow_neg, zpow_natCast]
  have hp : (0 : ℝ) < ((2 : ℝ) ^ fmt.fracWidth)⁻¹ := by positivity
  have hp1 : ((2 : ℝ) ^ fmt.fracWidth)⁻¹ ≤ 1 / 2 := by
    rw [inv_le_comm₀ (by positivity) (by norm_num)]
    norm_num
    exact le_self_pow₀ (by norm_num) (by omega)
  rw [hq]
  have hmag : magnitude FloatLib.Numerics.binaryRadix (2 + ((2 : ℝ) ^ fmt.fracWidth)⁻¹) = 2 := by
    apply magnitude_eq_of_bpow_bounds
    · rw [abs_of_pos (by positivity)]
      norm_num [bpow, FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal]
    · rw [abs_of_pos (by positivity)]
      norm_num [bpow, FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal]
      linarith
  have hcexp : cexp FloatLib.Numerics.binaryRadix (Model.fexpOf fmt)
      (2 + ((2 : ℝ) ^ fmt.fracWidth)⁻¹) = 1 - fmt.fracWidth := by
    have := minSubnormalExponent_le (fmt := fmt)
    simp only [cexp, hmag, Model.fexpOf, fltExp]
    omega
  have hsm : scaledMantissa FloatLib.Numerics.binaryRadix (Model.fexpOf fmt)
      (2 + ((2 : ℝ) ^ fmt.fracWidth)⁻¹) = ((2 ^ fmt.fracWidth : ℤ) : ℝ) + 1 / 2 := by
    rw [scaledMantissa, hcexp]
    simp only [bpow, FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal]
    rw [neg_sub, zpow_sub₀ (by norm_num), zpow_one, zpow_natCast]
    push_cast
    field_simp
  have hne : nearestEven (((2 ^ fmt.fracWidth : ℤ) : ℝ) + 1 / 2) = 2 ^ fmt.fracWidth := by
    have hfl : ⌊((2 ^ fmt.fracWidth : ℤ) : ℝ) + 1 / 2⌋ = 2 ^ fmt.fracWidth :=
      Int.floor_eq_iff.mpr ⟨by linarith, by linarith⟩
    rw [nearestEven_eq_floor_of_frac_half_even _ (by rw [hfl]; ring) ?_, hfl]
    rw [hfl]
    exact (Int.even_pow' (by omega)).mpr even_two
  change round (β := FloatLib.Numerics.binaryRadix) (fexp := Model.fexpOf fmt) nearestEven
    (2 + ((2 : ℝ) ^ fmt.fracWidth)⁻¹) = 2
  rw [round_eq_toReal_of_scaled_round_eq nearestEven _ (2 ^ fmt.fracWidth) (by rw [hsm, hne]),
    hcexp]
  simp only [toReal, bpow, FloatLib.Numerics.binaryRadix, FloatLib.Numerics.Radix.toReal]
  push_cast
  rw [zpow_sub₀ (by norm_num), zpow_one, zpow_natCast]
  field_simp

/-- In every IEEE format `2 + ε` and `ε + 2` round to `2`. -/
private theorem two_eps (hfmt : fmt.isIEEE = true) :
    Model.add 2 (eps fmt) = 2 ∧ Model.add (eps fmt) 2 = 2 := by
  have hle : |(2 : Model fmt).toReal| + |(eps fmt).toReal| ≤
      Model.toReal (Model.posMaxFinite fmt) := by
    rw [(two_spec hfmt).2, (eps_spec hfmt).2, abs_of_pos (by norm_num),
      abs_of_pos (by positivity)]
    have := two_add_le_maxFinite hfmt
    have : (0 : ℝ) < 2 ^ (-(fmt.fracWidth : ℤ)) := by positivity
    linarith
  have h2 : (2 : Model fmt).toReal ≠ 0 := by rw [(two_spec hfmt).2]; norm_num
  have h1 := Model.isFinite_add_of_abs_add_le_posMaxFinite _ _ hfmt (two_spec hfmt).1
    (eps_spec hfmt).1 hle
  have h1' := Model.isFinite_add_of_abs_add_le_posMaxFinite _ _ hfmt (eps_spec hfmt).1
    (two_spec hfmt).1 ((add_comm _ _).trans_le hle)
  constructor
  · have hval : (Model.add 2 (eps fmt)).toReal = (2 : Model fmt).toReal := by
      rw [Model.toReal_add_eq_roundAt _ _ hfmt h1, (two_spec hfmt).2, (eps_spec hfmt).2,
        roundAt_two_add]
    exact Model.eq_of_toReal_eq_of_nonzero hval (hval ▸ h2)
  · have hval : (Model.add (eps fmt) 2).toReal = (2 : Model fmt).toReal := by
      rw [Model.toReal_add_eq_roundAt _ _ hfmt h1', (two_spec hfmt).2, (eps_spec hfmt).2,
        add_comm, roundAt_two_add]
    exact Model.eq_of_toReal_eq_of_nonzero hval (hval ▸ h2)

/-- In every IEEE format `ε` and `+0` are not equal up to NaN payloads. -/
private theorem not_nanEq_eps_zero (hfmt : fmt.isIEEE = true) :
    ¬ NaNEq (eps fmt) (0 : Model fmt) := by
  rintro (h | ⟨h, -⟩)
  · have := congrArg Model.toReal h
    rw [(eps_spec hfmt).2, show (0 : Model fmt) = Model.posZero fmt from rfl,
      Model.toReal_posZero fmt] at this
    exact absurd this (by positivity)
  · simp [Model.isNaN_eq_false_of_isFinite_eq_true _ (eps_spec hfmt).1] at h

/-- In every IEEE format `+0` is an identity on `ε` on both sides. -/
private theorem eps_zero (hfmt : fmt.isIEEE = true) :
    Model.add (eps fmt) 0 = eps fmt ∧ Model.add 0 (eps fmt) = eps fmt :=
  zero_identity hfmt (eps_spec hfmt).1 (by rw [(eps_spec hfmt).2]; positivity)

/-- In every IEEE format `+0` is an identity on `2` on both sides. -/
private theorem two_zero (hfmt : fmt.isIEEE = true) :
    Model.add (2 : Model fmt) 0 = 2 ∧ Model.add 0 (2 : Model fmt) = 2 :=
  zero_identity hfmt (two_spec hfmt).1 (by rw [(two_spec hfmt).2]; norm_num)

/-- In every IEEE format `+0` is an identity on `-2` on both sides. -/
private theorem negTwo_zero (hfmt : fmt.isIEEE = true) :
    Model.add (-2 : Model fmt) 0 = -2 ∧ Model.add 0 (-2 : Model fmt) = -2 :=
  zero_identity hfmt (negTwo_spec hfmt).1 (by rw [(negTwo_spec hfmt).2]; norm_num)

end Witness

section Tree

variable {ι β : Type*} (f : β → β → β) (z : β)

/-- For every carrier, operation and tree, the tree's result reads only the values at its
leaves. -/
private theorem eval_congr_leaves {v v' : ι → β} : ∀ t : ReductionTree ι,
    (∀ a ∈ t.leaves, v a = v' a) → t.eval f v = t.eval f v'
  | .leaf a, h => h a (by simp [ReductionTree.leaves])
  | .node l r, h => by
    simp only [ReductionTree.eval]
    rw [eval_congr_leaves l fun a ha => h a (by simp [ReductionTree.leaves, ha]),
      eval_congr_leaves r fun a ha => h a (by simp [ReductionTree.leaves, ha])]

/-- For every carrier, operation `f`, value `z` with `f z z = z` and tree, leaves that all hold
`z` give `z`. -/
private theorem eval_eq_zero (h00 : f z z = z) {v : ι → β} : ∀ t : ReductionTree ι,
    (∀ a ∈ t.leaves, v a = z) → t.eval f v = z
  | .leaf a, h => h a (by simp [ReductionTree.leaves])
  | .node l r, h => by
    simp only [ReductionTree.eval]
    rw [eval_eq_zero h00 l fun a ha => h a (by simp [ReductionTree.leaves, ha]),
      eval_eq_zero h00 r fun a ha => h a (by simp [ReductionTree.leaves, ha]), h00]

/-- For every carrier, operation `f`, value `z` with `f z z = z` and tree without repeated
leaves, one leaf `x` holding `w` among zeros gives `w`, when `z` is an identity on `w` on both
sides. -/
private theorem eval_eq_single (h00 : f z z = z) {w : β} (hw : f w z = w ∧ f z w = w)
    {v : ι → β} {x : ι} (hx : v x = w) : ∀ t : ReductionTree ι, t.leaves.Nodup →
    x ∈ t.leaves → (∀ a ∈ t.leaves, a ≠ x → v a = z) → t.eval f v = w
  | .leaf a, _, hm, _ => by
    simp only [ReductionTree.leaves, List.mem_singleton] at hm
    subst hm
    exact hx
  | .node l r, hd, hm, h => by
    simp only [ReductionTree.leaves, List.nodup_append, List.mem_append] at hd hm
    have hl : ∀ a ∈ l.leaves, a ≠ x → v a = z := fun a ha =>
      h a (by simp [ReductionTree.leaves, ha])
    have hr : ∀ a ∈ r.leaves, a ≠ x → v a = z := fun a ha =>
      h a (by simp [ReductionTree.leaves, ha])
    simp only [ReductionTree.eval]
    rcases hm with hm | hm
    · have hxr : x ∉ r.leaves := fun h' => hd.2.2 x hm x h' rfl
      rw [eval_eq_single h00 hw hx l hd.1 hm hl,
        eval_eq_zero f z h00 r fun a ha => hr a ha (fun e => hxr (e ▸ ha)), hw.1]
    · have hxl : x ∉ l.leaves := fun h' => hd.2.2 x h' x hm rfl
      rw [eval_eq_zero f z h00 l fun a ha => hl a ha (fun e => hxl (e ▸ ha)),
        eval_eq_single h00 hw hx r hd.2.1 hm hr, hw.2]

/-- For every carrier, operation `f`, value `z` with `f z z = z` and tree without repeated
leaves, two leaves `x ≠ y` holding `p` and `q` among zeros give `w`, when both orders of `p` and
`q` give `w` and `z` is an identity on `p`, `q` and `w` on both sides. -/
private theorem eval_eq_pair (h00 : f z z = z) {p q w : β} (hp : f p z = p ∧ f z p = p)
    (hq : f q z = q ∧ f z q = q) (hpq : f p q = w ∧ f q p = w) (hw : f w z = w ∧ f z w = w)
    {v : ι → β} {x y : ι} (hxy : x ≠ y) (hx : v x = p) (hy : v y = q) :
    ∀ t : ReductionTree ι, t.leaves.Nodup → x ∈ t.leaves → y ∈ t.leaves →
    (∀ a ∈ t.leaves, a ≠ x → a ≠ y → v a = z) → t.eval f v = w
  | .leaf a, _, hmx, hmy, _ => by
    simp only [ReductionTree.leaves, List.mem_singleton] at hmx hmy
    exact absurd (hmx.trans hmy.symm) hxy
  | .node l r, hd, hmx, hmy, h => by
    simp only [ReductionTree.leaves, List.nodup_append, List.mem_append] at hd hmx hmy
    have hl : ∀ a ∈ l.leaves, a ≠ x → a ≠ y → v a = z := fun a ha =>
      h a (by simp [ReductionTree.leaves, ha])
    have hr : ∀ a ∈ r.leaves, a ≠ x → a ≠ y → v a = z := fun a ha =>
      h a (by simp [ReductionTree.leaves, ha])
    have nl : ∀ {b}, b ∈ r.leaves → b ∉ l.leaves := fun hb hb' => hd.2.2 _ hb' _ hb rfl
    have nr : ∀ {b}, b ∈ l.leaves → b ∉ r.leaves := fun hb hb' => hd.2.2 _ hb _ hb' rfl
    simp only [ReductionTree.eval]
    rcases hmx with hmx | hmx <;> rcases hmy with hmy | hmy
    · rw [eval_eq_pair h00 hp hq hpq hw hxy hx hy l hd.1 hmx hmy hl,
        eval_eq_zero f z h00 r fun a ha => hr a ha (fun e => nr hmx (e ▸ ha))
          (fun e => nr hmy (e ▸ ha)), hw.1]
    · rw [eval_eq_single f z h00 hp hx l hd.1 hmx fun a ha hax =>
          hl a ha hax (fun e => nl hmy (e ▸ ha)),
        eval_eq_single f z h00 hq hy r hd.2.1 hmy fun a ha hay =>
          hr a ha (fun e => nr hmx (e ▸ ha)) hay, hpq.1]
    · rw [eval_eq_single f z h00 hq hy l hd.1 hmy fun a ha hay =>
          hl a ha (fun e => nl hmx (e ▸ ha)) hay,
        eval_eq_single f z h00 hp hx r hd.2.1 hmx fun a ha hax =>
          hr a ha hax (fun e => nr hmy (e ▸ ha)), hpq.2]
    · rw [eval_eq_zero f z h00 l fun a ha => hl a ha (fun e => nl hmx (e ▸ ha))
          (fun e => nl hmy (e ▸ ha)),
        eval_eq_pair h00 hp hq hpq hw hxy hx hy r hd.2.1 hmx hmy hr, hw.2]

end Tree

section Logic

/-- For every three propositions, three points in a two-by-two grid of two partitions `P` and
`Q` of the points where `U` holds, given a point `u` off the diagonal, a point `w` on it, and
points on the other row and the other column of `u`: `b, c` on one row and `a` on the other,
`a, b` on one column and `c` on the other. -/
private theorem triple {α : Type*} (U P Q : α → Prop) {u w : α} (Uu : U u) (Uw : U w)
    (hu : P u ↔ ¬ Q u) (hw : P w ↔ Q w)
    (hrow : ∃ s, U s ∧ (P s ↔ ¬ P u)) (hcol : ∃ s, U s ∧ (Q s ↔ ¬ Q u)) :
    ∃ a b c, U a ∧ U b ∧ U c ∧ (P b ↔ P c) ∧ (P a ↔ ¬ P b) ∧ (Q a ↔ Q b) ∧
      (Q c ↔ ¬ Q a) := by
  by_cases hpw : P u ↔ P w
  · obtain ⟨s, Us, hs⟩ := hrow
    by_cases hqs : Q s ↔ Q u
    · exact ⟨s, u, w, Us, Uu, Uw, by tauto, by tauto, by tauto, by tauto⟩
    · exact ⟨s, w, u, Us, Uw, Uu, by tauto, by tauto, by tauto, by tauto⟩
  · obtain ⟨s, Us, hs⟩ := hcol
    by_cases hps : P s ↔ P u
    · exact ⟨w, u, s, Uw, Uu, Us, by tauto, by tauto, by tauto, by tauto⟩
    · exact ⟨u, w, s, Uu, Uw, Us, by tauto, by tauto, by tauto, by tauto⟩

/-- For every two propositions that differ, the first is the negation of the second. -/
private theorem iff_not_of_not_iff {p q : Prop} (h : ¬(p ↔ q)) : p ↔ ¬q := by
  tauto

/-- For every three propositions, `p` and `r` differ and `r` is `¬ q`, so `p` is `q`. -/
private theorem iff_of_not_iff_not {p q r : Prop} (h : ¬(p ↔ r)) (hr : r ↔ ¬q) : p ↔ q := by
  tauto

/-- For every six propositions, with `r` the negation of `p` at each of `a, b, c`, `b, c` on one
side and `a` on the other: `a` on `p`'s side and `b, c` on `r`'s, or the other way round. -/
private theorem one_two_of {pa pb pc ra rb rc : Prop} (ha : ra ↔ ¬pa) (hb : rb ↔ ¬pb)
    (hc : rc ↔ ¬pc) (h1 : pb ↔ pc) (h2 : pa ↔ ¬pb) : (pa ∧ rb ∧ rc) ∨ (ra ∧ pb ∧ pc) := by
  tauto

/-- For every six propositions, with `r` the negation of `q` at each of `a, b, c`, `a, b` on one
side and `c` on the other: `a, b` on `q`'s side and `c` on `r`'s, or the other way round. -/
private theorem two_one_of {qa qb qc ra rb rc : Prop} (ha : ra ↔ ¬qa) (hb : rb ↔ ¬qb)
    (hc : rc ↔ ¬qc) (h3 : qa ↔ qb) (h4 : qc ↔ ¬qa) : (qa ∧ qb ∧ rc) ∨ (ra ∧ rb ∧ qc) := by
  tauto

end Logic

section Sep

variable {ι : Type*} [LinearOrder ι] {fmt : FloatFormat}

/-- The input with `e, 2, -2` at three leaves `a, b, c` and `+0` elsewhere, for every format,
word `e` and leaf type with a linear order; the separating input is its case `e = ε` (`eps`). -/
private def input (e : Model fmt) (a b c : ι) (x : ι) : Model fmt :=
  if x = a then e else if x = b then 2 else if x = c then -2 else 0

/-- The values of `input e a b c`, for every format, word `e` and three different leaves: `e` at
`a`, `2` at `b`, `-2` at `c` and `+0` at every other leaf. -/
private theorem input_vals {e : Model fmt} {a b c : ι} (hab : a ≠ b) (hac : a ≠ c) (hbc : b ≠ c) :
    input e a b c a = e ∧ input e a b c b = 2 ∧ input e a b c c = -2 ∧
      ∀ x, x ≠ a → x ≠ b → x ≠ c → input e a b c x = 0 := by
  refine ⟨by simp [input], by simp [input, hab.symm], by simp [input, hac.symm, hbc.symm],
    fun x h1 h2 h3 => by simp [input, h1, h2, h3]⟩

/-- For every IEEE format and two subtrees `l, r` over different leaves, at three different
leaves `a, b, c`, `node l r` gives `ε` at `input ε a b c` when `a` is under one child and `b, c`
under the other, and `+0` when `a, b` are under one child and `c` under the other. -/
private theorem eval_input (hfmt : fmt.isIEEE = true) {a b c : ι} (hab : a ≠ b) (hac : a ≠ c)
    (hbc : b ≠ c) {l r : ReductionTree ι} (hd : (l.leaves ++ r.leaves).Nodup) :
    ((a ∈ l.leaves ∧ b ∈ r.leaves ∧ c ∈ r.leaves) ∨ (a ∈ r.leaves ∧ b ∈ l.leaves ∧ c ∈ l.leaves) →
      (ReductionTree.node l r).eval Model.add (input (eps fmt) a b c) = eps fmt) ∧
    ((a ∈ l.leaves ∧ b ∈ l.leaves ∧ c ∈ r.leaves) ∨ (a ∈ r.leaves ∧ b ∈ r.leaves ∧ c ∈ l.leaves) →
      (ReductionTree.node l r).eval Model.add (input (eps fmt) a b c) = 0) := by
  have hD := List.nodup_append.mp hd
  obtain ⟨ia, ib, ic, iz⟩ := input_vals (e := eps fmt) hab hac hbc
  have h00 := zero_add_zero (fmt := fmt)
  have z00 : Model.add (0 : Model fmt) 0 = 0 ∧ Model.add (0 : Model fmt) 0 = 0 := ⟨h00, h00⟩
  have bc := eval_eq_pair Model.add 0 h00 (two_zero hfmt) (negTwo_zero hfmt)
    (add_neg_zero hfmt (two_spec hfmt).1) z00 hbc ib ic
  have ab := eval_eq_pair Model.add 0 h00 (eps_zero hfmt) (two_zero hfmt)
    (two_eps hfmt).symm (two_zero hfmt) hab ia ib
  simp only [ReductionTree.eval]
  refine ⟨fun h => ?_, fun h => ?_⟩
  · rcases h with ⟨ha, hb, hc⟩ | ⟨ha, hb, hc⟩
    · rw [eval_eq_single Model.add 0 h00 (eps_zero hfmt) ia l hD.1 ha
          (fun x hx hxa => iz x hxa (hD.2.2 x hx b hb) (hD.2.2 x hx c hc)),
        bc r hD.2.1 hb hc (fun x hx hxb hxc => iz x (hD.2.2 a ha x hx).symm hxb hxc),
        (eps_zero hfmt).1]
    · rw [bc l hD.1 hb hc (fun x hx hxb hxc => iz x (hD.2.2 x hx a ha) hxb hxc),
        eval_eq_single Model.add 0 h00 (eps_zero hfmt) ia r hD.2.1 ha
          (fun x hx hxa => iz x hxa (hD.2.2 b hb x hx).symm (hD.2.2 c hc x hx).symm),
        (eps_zero hfmt).2]
  · rcases h with ⟨ha, hb, hc⟩ | ⟨ha, hb, hc⟩
    · rw [ab l hD.1 ha hb (fun x hx hxa hxb => iz x hxa hxb (hD.2.2 x hx c hc)),
        eval_eq_single Model.add 0 h00 (negTwo_zero hfmt) ic r hD.2.1 hc
          (fun x hx hxc => iz x (hD.2.2 a ha x hx).symm (hD.2.2 b hb x hx).symm hxc),
        (add_neg_zero hfmt (two_spec hfmt).1).1]
    · rw [eval_eq_single Model.add 0 h00 (negTwo_zero hfmt) ic l hD.1 hc
          (fun x hx hxc => iz x (hD.2.2 x hx a ha) (hD.2.2 x hx b hb) hxc),
        ab r hD.2.1 ha hb (fun x hx hxa hxb => iz x hxa hxb (hD.2.2 c hc x hx).symm),
        (add_neg_zero hfmt (two_spec hfmt).1).2]

/-- The two results the separating input gives, `ε` and `+0`, in either order, for every
format. -/
private def Sep (x y : Model fmt) : Prop := (x = eps fmt ∧ y = 0) ∨ (x = 0 ∧ y = eps fmt)

/-- For every IEEE format, `+0` is an identity on both sides on the two values of `Sep`. -/
private theorem sep_zero_id (hfmt : fmt.isIEEE = true) {x y : Model fmt} (h : Sep x y) :
    (Model.add x 0 = x ∧ Model.add 0 x = x) ∧ (Model.add y 0 = y ∧ Model.add 0 y = y) := by
  rcases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · exact ⟨eps_zero hfmt, zero_add_zero, zero_add_zero⟩
  · exact ⟨⟨zero_add_zero, zero_add_zero⟩, eps_zero hfmt⟩

/-- For every IEEE format and four trees, with `s, s'` over the same leaves, `o, o'` over the
same leaves and no leaf of `s` in `o`: an input at which `s` and `s'` give `ε` and `+0` (`Sep`),
set to `+0` off `s`'s leaves, gives `ε` and `+0` at a node with children `s, o` in either order
and a node with children `s', o'` in either order. -/
private theorem sep_zero (hfmt : fmt.isIEEE = true) {s s' o o' : ReductionTree ι}
    (hs : ∀ x, x ∈ s.leaves ↔ x ∈ s'.leaves) (ho : ∀ x, x ∈ o.leaves ↔ x ∈ o'.leaves)
    (hd : ∀ x ∈ s.leaves, x ∉ o.leaves) {v : ι → Model fmt}
    (hv : Sep (s.eval Model.add v) (s'.eval Model.add v)) :
    ∃ v' : ι → Model fmt, ∀ T T' : ReductionTree ι,
      (T = .node s o ∨ T = .node o s) → (T' = .node s' o' ∨ T' = .node o' s') →
      Sep (T.eval Model.add v') (T'.eval Model.add v') := by
  refine ⟨fun x => if x ∈ s.leaves then v x else 0, ?_⟩
  have h00 := zero_add_zero (fmt := fmt)
  have e1 := eval_congr_leaves Model.add (v := fun x => if x ∈ s.leaves then v x else 0)
    (v' := v) s fun x hx => by simp [hx]
  have e2 := eval_congr_leaves Model.add (v := fun x => if x ∈ s.leaves then v x else 0)
    (v' := v) s' fun x hx => by simp [(hs x).mpr hx]
  have e3 := eval_eq_zero Model.add (0 : Model fmt) h00
    (v := fun x => if x ∈ s.leaves then v x else 0) o fun x hx =>
      ite_eq_right_iff.mpr fun h => absurd hx (hd x h)
  have e4 := eval_eq_zero Model.add (0 : Model fmt) h00
    (v := fun x => if x ∈ s.leaves then v x else 0) o' fun x hx =>
      ite_eq_right_iff.mpr fun h => absurd ((ho x).mpr hx) (hd x h)
  obtain ⟨⟨a1, a2⟩, b1, b2⟩ := sep_zero_id hfmt hv
  rintro T T' (rfl | rfl) (rfl | rfl) <;>
    simp only [ReductionTree.eval, e1, e2, e3, e4, a1, a2, b1, b2] <;> exact hv

omit [LinearOrder ι] in
/-- For every leaf type and tree, the tree has a leaf. -/
private theorem exists_mem_leaves (t : ReductionTree ι) : ∃ x, x ∈ t.leaves :=
  List.exists_mem_of_length_pos (by rw [ReductionTree.length_leaves]; omega)

/-- **The separating input**, for every IEEE format, leaf type with a linear order and two trees
over the same leaves without repeats whose `canon` differ: an input at which one gives `ε` and the
other `+0`. -/
private theorem exists_eval_sep (hfmt : fmt.isIEEE = true) : ∀ (t t' : ReductionTree ι),
    t.leaves.Nodup → t.leaves.Perm t'.leaves → canon t ≠ canon t' →
    ∃ v : ι → Model fmt, Sep (t.eval Model.add v) (t'.eval Model.add v)
  | .leaf a, .leaf b, _, hp, hne => by
    simp only [ReductionTree.leaves, List.singleton_perm_singleton] at hp
    exact absurd (by rw [hp]) hne
  | .leaf a, .node l' r', _, hp, _ => by
    have := hp.length_eq
    simp only [ReductionTree.leaves, List.length_append, List.length_singleton,
      ReductionTree.length_leaves] at this
    omega
  | .node l r, .leaf b, _, hp, _ => by
    have := hp.length_eq
    simp only [ReductionTree.leaves, List.length_append, List.length_singleton,
      ReductionTree.length_leaves] at this
    omega
  | .node l r, .node l' r', hd, hp, hne => by
    have hd' : (ReductionTree.node l' r').leaves.Nodup := hp.nodup_iff.mp hd
    simp only [ReductionTree.leaves] at hd hd' hp
    have hD := List.nodup_append.mp hd
    have hD' := List.nodup_append.mp hd'
    rw [Ne, canon_node_eq_iff] at hne
    have hU : ∀ x, x ∈ l.leaves ∨ x ∈ r.leaves ↔ x ∈ l'.leaves ∨ x ∈ r'.leaves := fun x => by
      simpa using hp.mem_iff
    -- the roots split the leaves alike: `l ~ m` and `r ~ m'` with `m, m'` the children of the
    -- second root in some order
    have alike : ∀ {m m' : ReductionTree ι},
        (l'.leaves ++ r'.leaves).Perm (m.leaves ++ m'.leaves) →
        (ReductionTree.node l' r' = .node m m' ∨ ReductionTree.node l' r' = .node m' m) →
        (∀ x, x ∈ l.leaves ↔ x ∈ m.leaves) → (canon l = canon m → canon r ≠ canon m') →
        ∃ v : ι → Model fmt,
          Sep ((ReductionTree.node l r).eval Model.add v)
            ((ReductionTree.node l' r').eval Model.add v) := by
      intro m m' hp' hT hA hc
      have hm := List.nodup_append.mp ((hp.trans hp').nodup_iff.mp hd)
      have hL : l.leaves.Perm m.leaves := (List.perm_ext_iff_of_nodup hD.1 hm.1).mpr hA
      have hR : r.leaves.Perm m'.leaves :=
        (List.perm_append_left_iff _).mp ((hL.append_right _).symm.trans (hp.trans hp'))
      by_cases hl : canon l = canon m
      · obtain ⟨v, hv⟩ := exists_eval_sep hfmt r m' hD.2.1 hR (hc hl)
        obtain ⟨v', hv'⟩ := sep_zero hfmt (fun x => hR.mem_iff) hA
          (fun x h h' => hD.2.2 x h' x h rfl) hv
        exact ⟨v', hv' _ _ (Or.inr rfl) hT.symm⟩
      · obtain ⟨v, hv⟩ := exists_eval_sep hfmt l m hD.1 hL hl
        obtain ⟨v', hv'⟩ := sep_zero hfmt hA (fun x => hR.mem_iff)
          (fun x h h' => hD.2.2 x h x h' rfl) hv
        exact ⟨v', hv' _ _ (Or.inl rfl) hT⟩
    by_cases hA : ∀ x, x ∈ l.leaves ↔ x ∈ l'.leaves
    · exact alike (List.Perm.refl _) (Or.inl rfl) hA fun hl hr => hne (Or.inl ⟨hl, hr⟩)
    by_cases hB : ∀ x, x ∈ l.leaves ↔ x ∈ r'.leaves
    · exact alike List.perm_append_comm (Or.inr rfl) hB fun hl hr => hne (Or.inr ⟨hl, hr⟩)
    -- the roots split the leaves differently
    have hRx : ∀ x, x ∈ l.leaves ∨ x ∈ r.leaves → (x ∈ r.leaves ↔ x ∉ l.leaves) :=
      fun x hx => ⟨fun h h' => hD.2.2 x h' x h rfl, fun h => hx.resolve_left h⟩
    have hR'x : ∀ x, x ∈ l.leaves ∨ x ∈ r.leaves → (x ∈ r'.leaves ↔ x ∉ l'.leaves) :=
      fun x hx => ⟨fun h h' => hD'.2.2 x h' x h rfl, fun h => ((hU x).mp hx).resolve_left h⟩
    obtain ⟨u, hu⟩ := not_forall.mp hA
    obtain ⟨w, hw⟩ := not_forall.mp hB
    have Uu : u ∈ l.leaves ∨ u ∈ r.leaves := by
      by_cases h : u ∈ l.leaves
      · exact Or.inl h
      · exact (hU u).mpr (Or.inl (by
          by_contra h'
          exact hu ⟨fun h1 => absurd h1 h, fun h1 => absurd h1 h'⟩))
    have Uw : w ∈ l.leaves ∨ w ∈ r.leaves := by
      by_cases h : w ∈ l.leaves
      · exact Or.inl h
      · exact (hU w).mpr (Or.inr (by
          by_contra h'
          exact hw ⟨fun h1 => absurd h1 h, fun h1 => absurd h1 h'⟩))
    have hrow : ∃ s, (s ∈ l.leaves ∨ s ∈ r.leaves) ∧ (s ∈ l.leaves ↔ ¬ u ∈ l.leaves) := by
      by_cases h : u ∈ l.leaves
      · obtain ⟨s, hs⟩ := exists_mem_leaves r
        have := (hRx s (Or.inr hs)).mp hs
        exact ⟨s, Or.inr hs, fun h1 => absurd h1 this, fun h1 => absurd h h1⟩
      · obtain ⟨s, hs⟩ := exists_mem_leaves l
        exact ⟨s, Or.inl hs, fun _ => h, fun _ => hs⟩
    have hcol : ∃ s, (s ∈ l.leaves ∨ s ∈ r.leaves) ∧ (s ∈ l'.leaves ↔ ¬ u ∈ l'.leaves) := by
      by_cases h : u ∈ l'.leaves
      · obtain ⟨s, hs⟩ := exists_mem_leaves r'
        have Us := (hU s).mpr (Or.inr hs)
        have := (hR'x s Us).mp hs
        exact ⟨s, Us, fun h1 => absurd h1 this, fun h1 => absurd h h1⟩
      · obtain ⟨s, hs⟩ := exists_mem_leaves l'
        exact ⟨s, (hU s).mpr (Or.inl hs), fun _ => h, fun _ => hs⟩
    obtain ⟨a, b, c, Ua, Ub, Uc, h1, h2, h3, h4⟩ :=
      triple (fun x => x ∈ l.leaves ∨ x ∈ r.leaves) (· ∈ l.leaves) (· ∈ l'.leaves) Uu Uw
        (iff_not_of_not_iff hu) (iff_of_not_iff_not hw (hR'x w Uw)) hrow hcol
    have hab : a ≠ b := fun e => by subst e; exact iff_not_self h2
    have hac : a ≠ c := fun e => by subst e; exact iff_not_self (h2.trans (not_congr h1))
    have hbc : b ≠ c := fun e => by subst e; exact iff_not_self (h3.trans h4)
    exact ⟨input (eps fmt) a b c, Or.inl ⟨(eval_input hfmt hab hac hbc hd).1
      (one_two_of (hRx a Ua) (hRx b Ub) (hRx c Uc) h1 h2), (eval_input hfmt hab hac hbc hd').2
      (two_one_of (hR'x a Ua) (hR'x b Ub) (hR'x c Uc) h3 h4)⟩⟩

/-- **Trees over the same distinct leaves agree up to NaN payloads on every input exactly when
they have the same `canon`**, for every IEEE format, leaf type with a linear order and two trees
`t, t'` whose leaf lists are permutations of each other without repeats: `→` by an input with
values among `+0`, `ε = 2^-f`, `2` and `-2` at which one tree gives `ε` and the other `+0`, `←`
by `MojoProof.Float.eval_nanEq_of_canon`, which needs neither premise. -/
theorem eval_add_eq_iff (hfmt : fmt.isIEEE = true) {t t' : ReductionTree ι}
    (hd : t.leaves.Nodup) (hp : t.leaves.Perm t'.leaves) :
    (∀ v : ι → Model fmt, NaNEq (t.eval (fun x y => Model.add x y) v)
      (t'.eval (fun x y => Model.add x y) v)) ↔ canon t = canon t' := by
  refine ⟨fun h => ?_, fun h v => eval_nanEq_of_canon h v⟩
  by_contra hne
  obtain ⟨v, hv⟩ := exists_eval_sep hfmt t t' hd hp hne
  have e := h v
  change NaNEq (t.eval Model.add v) (t'.eval Model.add v) at e
  rcases hv with ⟨h1, h2⟩ | ⟨h1, h2⟩
  · rw [h1, h2] at e
    exact not_nanEq_eps_zero hfmt e
  · rw [h1, h2] at e
    exact not_nanEq_eps_zero hfmt ((GPUProof.UpToNaN.equivalence _).symm e)

end Sep

end MojoProof.Float
