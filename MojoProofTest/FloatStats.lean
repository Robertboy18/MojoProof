import MojoProof.Float.Stats
import MojoProof.Float.ExpSum
import MojoProofTest.FloatTree

/-!
# Instances of the two-pass statistics, the exact maximum, the stable and masked softmax and
log-softmax

The fixtures for every length: `nat32 m`, the binary32 word of the natural `m`, whose real value
is `m` for `m ≤ 2 ^ 24` when it is finite (`nat32_toReal`; instances `four_toReal` and
`eight_toReal`); `iota n`, the words of `1, ..., n`, whose real values are `j + 1`
(`iota_toReal`), within `n` in magnitude (`iota_bound`), with the variance `(n ² - 1) / 12`
(`var_iota`) and the mean of squares `(n + 1) (2 n + 1) / 6` (`msq_iota`); `halveFin k`, the
halving tree over `2 ^ k` cells as a tree over `Fin (2 ^ k)` (`leaves_halveFin`). The finiteness
premises are checked by evaluation at each instance.

Tests of one example each, in binary32, over four indices, with two trees: `loop`, FloatLib's
left-to-right chain, and `pairs = halveFin 2`, the shape of a block's halving tree over four cells
(cell 0's tree after the strides 2 and 1), at the inputs `xs = iota 4`. Every premise is
discharged by evaluation (`decide +kernel`) or, for `errA_lt`, by normalizing FloatLib's binary32
constants.

* `mean_xs`, `var_xs`: `mean_error` and `var_error` at the inputs `1, 2, 3, 4` (`xs`) and the
  divisor word `4` (`four`): the mean `2.5` and the variance `1.25` are finite.
* `max_xs`: `max_exact` at `xs` along `pairs`.
* `term_xs`, `expSum_xs`: `expTerm_error` and `expSum_error` at `xs` shifted by `4`, the
  correctly rounded exponentials of `-3, -2, -1, 0` summed along `pairs`.
* `softmax_ones`: `softmax_error` at four inputs `1` (`ones`), each less their maximum along
  `pairs` (`top`, whose real value is an input's by `max_exact`); `errA_lt`: the premise `A < 1`.
* `lse_ones`, `logSoftmax_ones`: `lse_error` and `logSoftmax_error` at `ones` and `top`, with
  FloatLib's correctly rounded logarithm of the sum `4`.
* `term_masked`, `maskSum_masked`, `maskSoftmax_masked`: `expTerm_negInf`, `maskSum_error` and
  `maskSoftmax_error` at `1, -∞, 1, -∞` (`masked`) less `1`, kept at `0` and `2` (`kept`);
  `errM_lt`: the premise `A < 1`.
* `softmaxRecip4`, `softmaxRecip8`: `softmaxRecip_error`, the entry in the order `e_j * (1 / s)`,
  at four and eight inputs `1` less `1` along `halveFin 2` and `halveFin 3`, every index kept;
  `recip_num`, a tactic, closes the premise `A < 1` at each.
-/

namespace MojoProofTest.FloatStats

open MojoProof.Float FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatTree MojoProofTest.FloatRel
open scoped BigOperators

/-- The binary32 word of the natural `m`, FloatLib's rounding to nearest of the dyadic
`m · 2 ^ 0` (`Model.roundDyadic`). -/
abbrev nat32 (m : ℕ) : Model .binary32 :=
  Model.roundDyadic _ { negative := false, significand := m, exponent := 0 }

/-- **The word of a natural**, for every `m ≤ 2 ^ 24`: if `nat32 m` is finite, its real value is
`m`. FloatLib's `Model.toReal_roundDyadic_eq_roundAt`, and `Model.roundAt_intCast_of_abs_le`: an
integer of magnitude at most `2 ^ 24` is on binary32's grid. -/
theorem nat32_toReal {m : ℕ} (hm : m ≤ 2 ^ 24) (h : (nat32 m).isFinite = true) :
    (nat32 m).toReal = m := by
  rw [nat32, Model.toReal_roundDyadic_eq_roundAt _ rfl _ h, Dyadic.toReal_mk_false, zpow_zero,
    mul_one]
  have hm' : |((m : ℤ) : ℝ)| ≤ 2 ^ (FloatFormat.binary32.fracWidth + 1) := by
    rw [Int.cast_natCast, abs_of_nonneg (Nat.cast_nonneg _)]
    exact_mod_cast hm
  have e := Model.roundAt_intCast_of_abs_le .binary32 hm'
  rwa [Int.cast_natCast] at e

/-- The binary32 words of `1, 2, ..., n`: `nat32 (j + 1)` at `j`. -/
abbrev iota (n : ℕ) : Fin n → Model .binary32 := fun j => nat32 (j + 1)

/-- **The inputs `1, ..., n`**, for every `n ≤ 2 ^ 24` whose words are finite: the real value at
`j` is `j + 1`. `nat32_toReal`. -/
theorem iota_toReal {n : ℕ} (hn : n ≤ 2 ^ 24) (hf : ∀ j, (iota n j).isFinite = true)
    (j : Fin n) : (iota n j).toReal = (j : ℝ) + 1 := by
  rw [nat32_toReal (by omega) (hf j)]
  push_cast
  rfl

/-- For every `n ≤ 2 ^ 24` whose words are finite, the inputs `1, ..., n` are within `n` in
magnitude. -/
theorem iota_bound {n : ℕ} (hn : n ≤ 2 ^ 24) (hf : ∀ j, (iota n j).isFinite = true)
    (j : Fin n) : |(iota n j).toReal| ≤ n := by
  rw [iota_toReal hn hf, abs_of_nonneg (by positivity)]
  exact_mod_cast j.isLt

/-- `Σ_{i<n} (i + 1 - c)² = n (n + 1) (2 n + 1) / 6 - c n (n + 1) + n c²`, for every `n` and real
`c`. -/
private theorem sum_sq (n : ℕ) (c : ℝ) :
    ∑ i ∈ Finset.range n, ((i : ℝ) + 1 - c) * ((i : ℝ) + 1 - c) =
      n * (n + 1) * (2 * n + 1) / 6 - c * n * (n + 1) + n * c ^ 2 := by
  induction n with
  | zero => simp
  | succ n ih => rw [Finset.sum_range_succ, ih]; push_cast; ring

/-- `Σ_{i<n} (i + 1) = n (n + 1) / 2`, for every `n`. -/
private theorem sum_id (n : ℕ) : ∑ i ∈ Finset.range n, ((i : ℝ) + 1) = n * (n + 1) / 2 := by
  induction n with
  | zero => simp
  | succ n ih => rw [Finset.sum_range_succ, ih]; push_cast; ring

/-- **The variance of `1, ..., n`**, for every `0 < n ≤ 2 ^ 24` whose words are finite:
`TorchLean.var` of the real values is `(n ² - 1) / 12`. -/
theorem var_iota {n : ℕ} (hn : n ≤ 2 ^ 24) (h0 : 0 < n)
    (hf : ∀ j, (iota n j).isFinite = true) :
    TorchLean.var (fun j => (iota n j).toReal) = ((n : ℝ) ^ 2 - 1) / 12 := by
  have hn0 : (n : ℝ) ≠ 0 := by positivity
  simp only [TorchLean.var, iota_toReal hn hf, Fintype.expect_eq_sum_div_card, Fintype.card_fin]
  rw [Fin.sum_univ_eq_sum_range (fun i => (i : ℝ) + 1), sum_id,
    Fin.sum_univ_eq_sum_range (fun i => ((i : ℝ) + 1 - n * (n + 1) / 2 / n) *
      ((i : ℝ) + 1 - n * (n + 1) / 2 / n)), sum_sq]
  field_simp
  ring

/-- **The mean of the squares of `1, ..., n`**, for every `0 < n ≤ 2 ^ 24` whose words are
finite: `(n + 1) (2 n + 1) / 6`. -/
theorem msq_iota {n : ℕ} (hn : n ≤ 2 ^ 24) (h0 : 0 < n)
    (hf : ∀ j, (iota n j).isFinite = true) :
    𝔼 i, (iota n i).toReal ^ 2 = (n + 1) * (2 * n + 1) / 6 := by
  have hn0 : (n : ℝ) ≠ 0 := by positivity
  simp only [iota_toReal hn hf, Fintype.expect_eq_sum_div_card, Fintype.card_fin]
  have e := sum_sq n 0
  simp only [sub_zero, ← sq] at e
  rw [Fin.sum_univ_eq_sum_range (fun i => ((i : ℝ) + 1) ^ 2), e]
  field_simp
  ring

/-- The binary32 word `nat32 4` of `4`. -/
abbrev four : Model .binary32 := nat32 4

/-- The binary32 words of `1, 2, 3, 4`, `iota 4`. -/
abbrev xs : Fin 4 → Model .binary32 := iota 4

/-- Four binary32 words of `1`. -/
abbrev ones : Fin 4 → Model .binary32 := fun _ => one

/-- FloatLib's left-to-right chain over the indices `0, 1, 2, 3`. -/
abbrev loop : ReductionTree (Fin 4) := ReductionTree.leftChain 0 [1, 2, 3]

/-- Cell 0's tree after the halving rounds over `2 ^ k` cells (`leaves_halve`), its leaves read
as indices in `Fin (2 ^ k)`. -/
abbrev halveFin (k : ℕ) : ReductionTree (Fin (2 ^ k)) :=
  (roundsTree halveStep (MojoProof.Sem.bflyOffsets k) 0).map fun c =>
    ⟨c % 2 ^ k, Nat.mod_lt _ (Nat.two_pow_pos k)⟩

/-- For every `k`, the leaves of `halveFin k` are the indices below `2 ^ k` up to order:
`leaves_halve`, read in `Fin (2 ^ k)`. -/
theorem leaves_halveFin (k : ℕ) : (halveFin k).leaves.Perm (List.finRange (2 ^ k)) := by
  rw [ReductionTree.leaves_map]
  refine ((leaves_halve k).map _).trans (.of_eq ?_)
  apply List.ext_get <;> simp
  exact fun _ => Nat.mod_eq_of_lt

/-- The pairwise tree `(0 + 2) + (1 + 3)`, `halveFin 2`: cell 0's tree after the halving rounds
with strides `2` and `1` over four cells. -/
abbrev pairs : ReductionTree (Fin 4) := halveFin 2

/-- The real value of the binary32 word `four` is `4`: `nat32_toReal` at `4`. -/
theorem four_toReal : four.toReal = ((4 : ℕ) : ℝ) :=
  nat32_toReal (by norm_num) (by decide +kernel)

/-- The real value of the binary32 word `nat32 8` is `8`: `nat32_toReal` at `8`. -/
theorem eight_toReal := nat32_toReal (m := 8) (by norm_num) (by decide +kernel)

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
  simp only [expSumErr, maskErr, ones, one_toReal, ht, hd, sub_self, Real.exp_zero, abs_zero,
    mul_zero, mul_one, Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]

-- FloatLib's `unitRoundoffAt` and `underflowErrorAt` are powers `bpow 2 e`, and Mathlib v4.36.0
-- exposes `Real`'s operations to files outside the module system: a premise about these reals
-- in weak head normal form would unfold the powers past the default recursion limit. `bpow` is
-- irreducible here, so it is not unfolded.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
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

-- `bpow` is irreducible here, as above.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **The instance of `lse_error`**, a test of one example: at `ones` shifted by their maximum
`top` along `pairs`, the differences, the sum `4` of the exponentials and `lse = 1 + log 4` are
finite (by evaluation) and `A < 1` (`errA_lt`), so the word is within the stated mixed error of
`log Σ_i exp 1`. -/
theorem lse_ones :
    MixedError (lse pairs {} {} ones top).toReal (Real.log (∑ i, Real.exp (ones i).toReal))
      (Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 *
            Real.log (∑ i, Real.exp ((ones i).toReal - top.toReal)) +
          ((1 + Model.unitRoundoffAt .binary32) * -Real.log (1 - errA) +
            Model.underflowErrorAt .binary32))) := by
  obtain ⟨-, ⟨k, -, hk⟩, -⟩ := max_exact pairs ones (by decide +kernel)
  exact lse_error rfl pairs (by decide +kernel) {} {} ones top hk (by decide +kernel) errA_lt
    (by decide +kernel) (by decide +kernel)

-- `bpow` is irreducible here, as above.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **The instance of `logSoftmax_error`**, a test of one example: under `lse_ones`'s premises,
entry 0, `(1 - 1) - log 4`, is finite (by evaluation), so it is within the stated mixed error of
`1 - log Σ_i exp 1`. -/
theorem logSoftmax_ones :
    MixedError (logSoftmax pairs {} {} ones top 0).toReal
      ((ones 0).toReal - Real.log (∑ i, Real.exp (ones i).toReal))
      (Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) *
        (Model.unitRoundoffAt .binary32 * |(ones 0).toReal - top.toReal| +
          (Model.unitRoundoffAt .binary32 *
              Real.log (∑ i, Real.exp ((ones i).toReal - top.toReal)) +
            ((1 + Model.unitRoundoffAt .binary32) * -Real.log (1 - errA) +
              Model.underflowErrorAt .binary32)))) := by
  obtain ⟨-, ⟨k, -, hk⟩, -⟩ := max_exact pairs ones (by decide +kernel)
  exact logSoftmax_error rfl pairs (by decide +kernel) {} {} ones top hk (by decide +kernel)
    errA_lt (by decide +kernel) 0 (by decide +kernel)

/-- Four binary32 words: `1` at the indices `0` and `2`, and `-∞` (`0xFF800000`, masked) at `1`
and `3`. -/
abbrev masked : Fin 4 → Model .binary32 := ![one, f32 0xff800000, one, f32 0xff800000]

/-- The kept indices `0` and `2` of `masked`. -/
abbrev kept : Finset (Fin 4) := {0, 2}

/-- The absolute error `maskErr` of the masked sum of `masked` less `1` along `pairs`, over
`kept`, written out by a notation where it is used. -/
local notation "errM" =>
  maskErr kept (Model.unitRoundoffAt FloatFormat.binary32)
    (Model.underflowErrorAt FloatFormat.binary32) (ReductionTree.depth pairs)
    (fun j => Model.toReal (masked j) - Model.toReal one)

/-- **The instance of `expTerm_negInf`**, a test of one example: `masked 1 - 1` is `-∞` (by
evaluation), so its term is `+0`. -/
theorem term_masked : expTerm {} masked one 1 = Model.zero .binary32 false :=
  expTerm_negInf {} masked one 1 (by decide +kernel) (by decide +kernel)

/-- The premise `A < 1` of `maskSoftmax_error` at `masked`, `kept` and `m = 1`: both kept
differences are `0`, so `A` is `((1 + u) ^ 2 - 1) · 2 + (1 + u) ^ 2 · 2 · (u + η)` with binary32's
`u = 2 ^ -24` and `η = 2 ^ -150`. -/
theorem errM_lt : errM < 1 := by
  have hd : pairs.depth = 2 := rfl
  simp only [maskErr, kept, hd,
    Finset.sum_insert (show (0 : Fin 4) ∉ ({2} : Finset (Fin 4)) by decide), Finset.sum_singleton,
    masked, Matrix.cons_val_zero, Matrix.cons_val_two, Matrix.head_cons, Matrix.tail_cons,
    sub_self, Real.exp_zero, abs_zero, mul_zero, mul_one]
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]

/-- **The instance of `maskSum_error`**, a test of one example: `masked` less `1`, the differences
finite at `kept` and `-∞` elsewhere, and the sum `2` along `pairs` finite (by evaluation), so the
sum is within `errM` of `Σ_{j ∈ kept} exp (masked j - 1)`. -/
theorem maskSum_masked :
    MixedError (pairs.eval (fun a b => Model.add a b) (expTerm {} masked one)).toReal
      (∑ j ∈ kept, Real.exp ((masked j).toReal - one.toReal)) 0 errM :=
  maskSum_error rfl pairs (by decide +kernel) {} masked one kept (by decide +kernel)
    (by decide +kernel) (by decide +kernel)

-- `bpow` is irreducible here, as above.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **The instance of `maskSoftmax_error`**, a test of one example: under `maskSum_masked`'s
premises, with `m = 1 = masked 0`, `A < 1` (`errM_lt`) and entry 0 finite (by evaluation), entry
0 is within the stated mixed error of TorchLean's real softmax over `kept` at `0`, `1 / 2`. -/
theorem maskSoftmax_masked :
    MixedError (Model.div (expTerm {} masked one 0)
        (pairs.eval (fun a b => Model.add a b) (expTerm {} masked one))).toReal
      (TorchLean.TransformerBlock.softmax kept (fun i => (masked i).toReal) 0)
      ((1 + Model.unitRoundoffAt .binary32) *
        (((1 + Model.unitRoundoffAt .binary32) *
            Real.exp (Model.unitRoundoffAt .binary32 * |(masked 0).toReal - one.toReal|) - 1 +
          errM) / (1 - errM)) + Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) * (Model.underflowErrorAt .binary32 / (1 - errM)) +
        Model.underflowErrorAt .binary32) :=
  maskSoftmax_error rfl pairs (by decide +kernel) {} masked one kept (k := 0) (by decide) rfl
    (by decide +kernel) (by decide +kernel) errM_lt (by decide +kernel) 0 (by decide)
    (by decide +kernel)

/-- `recip_num` closes the premise `A < 1` of `softmaxRecip_error` at inputs `1` less `1` along
`halveFin k`, every index kept, at a concrete `k`: it unfolds `maskErr` and the tree's depth `k`,
sums the `2 ^ k` equal terms and normalizes FloatLib's binary32 constants `u = 2 ^ -24` and
`η = 2 ^ -150`. -/
macro "recip_num" : tactic => `(tactic| (
  simp only [maskErr, halveFin, ReductionTree.depth_map, depth_halve, one_toReal, sub_self,
    Real.exp_zero, abs_zero, mul_zero, mul_one, Finset.sum_const, Finset.card_univ,
    Fintype.card_fin, nsmul_eq_mul]
  norm_num [Model.unitRoundoffAt_eq, Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
    FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
    show FloatFormat.binary32.fracWidth = 23 by decide,
    show FloatFormat.binary32.exponentBias = 127 by decide]))

/-- **The instance of `softmaxRecip_error` at four inputs**, a test of one example: `ones` less
`1` along `pairs = halveFin 2`, every index kept; the differences, the sum `4` and entry 0 in the
kernel's order `e_0 * (1 / s)` are finite (by evaluation) and `A < 1` (`recip_num`), so entry 0
is within the stated mixed error of TorchLean's real softmax entry `1 / 4`. -/
theorem softmaxRecip4 := softmaxRecip_error rfl (halveFin 2) (leaves_halveFin 2) {}
  (fun _ => one) one Finset.univ (k := 0) (Finset.mem_univ _) rfl (by decide +kernel)
  (fun j hj => absurd (Finset.mem_univ j) hj) (by recip_num) (by decide +kernel) 0
  (Finset.mem_univ _) (by decide +kernel)

/-- **The instance of `softmaxRecip_error` at eight inputs**, a test of one example: eight words
`1` less `1` along `halveFin 3`, every index kept; the differences, the sum `8` and entry 0 in the
kernel's order `e_0 * (1 / s)` are finite (by evaluation) and `A < 1` (`recip_num`), so entry 0
is within the stated mixed error of TorchLean's real softmax entry `1 / 8`. -/
theorem softmaxRecip8 := softmaxRecip_error rfl (halveFin 3) (leaves_halveFin 3) {}
  (fun _ => one) one Finset.univ (k := 0) (Finset.mem_univ _) rfl (by decide +kernel)
  (fun j hj => absurd (Finset.mem_univ j) hj) (by recip_num) (by decide +kernel) 0
  (Finset.mem_univ _) (by decide +kernel)

end MojoProofTest.FloatStats
