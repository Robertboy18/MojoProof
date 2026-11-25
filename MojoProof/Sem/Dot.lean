import MojoProof.Sem.FloatRel
import GPUProof.Spec.Linear
import MojoProof.Float.Tree
import FloatLib.Floats.Formats.BinaryInterchange.Reduction.Schedule.Runtime
import FloatLib.Floats.Formats.BinaryInterchange.Conversion.Cast.Proof
import FloatLib.Floats.Formats.BinaryInterchange.Operations.FormatOf.Homogeneous
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.HalfUlp
import FloatLib.Floats.Formats.BinaryInterchange.DirectedSemantics.Bounds

/-!
# The contracted dot-product fold (docs/proofs/dot.md)

The float arithmetic of a dot-product loop whose body is `%p = fmul contract a, b` followed by
`%acc' = fadd contract %acc, %p`, as `floatBin` computes it, with the accumulator a `phi` result
(no recorded factors) and the product's factors recorded (MojoProof/Sem/Thread.lean, `exec`).

Definitions, for every FloatLib format:
* `dotStep c acc (a, b) (n₁, n₂)`: one iteration with `contract` flag `c` and the oracle numbers
  `n₁` of the `fmul` and `n₂` of the `fadd`: the product `deliver (Model.mul a b) (n₁ / 3)`, then,
  with `c`, `contract false acc p none (some (a, b)) n₂` (fused `Model.fma a b acc` when
  `n₂ % 3 = 2`, else `Model.add acc p`), without `c` `Model.add acc p`, through
  `deliver` at `n₂ / 3`.
* `dotLoop c o acc ps`: the iterations over the factor pairs `ps` from the word `acc`, iteration
  `j` with the oracle numbers `o j`.
* `dotBound fmt K T`: `((1 + u) ^ (K + 1) - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u` with
  `u = Model.unitRoundoffAt fmt` and `η = Model.underflowErrorAt fmt`.
* `dotLoopBound fmt K T`: `((1 + u) ^ K - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u`, the bound
  from `+0`, whose first `fadd` is exact; at most `dotBound fmt K T` for `T ≥ 0`.
* `treeDot t c o ls`: the loops from `+0` per lane `j`, over the pairs `ls j` at the oracle
  sequence `o j`, added by `Model.add` along the tree `t` of lane numbers
  (`Numerics.ReductionTree`).

The connection point: in the naive matmul kernel of the corpus, the word of the accumulator `%48`
(`phi float [ 0.000000e+00, %45 ], [ %66, %52 ]`) after `j` iterations is
`dotLoop true o (Model.zero fmt false)` of the first `j` pairs of words that the loads `%60` and
`%64` gave, with `o` the oracle numbers of the steps of `%65 = fmul contract` and
`%66 = fadd contract`. `floatBin_dotStep` proves one iteration of that; the loop's control and
loads are not proved here (docs/proofs/dot.md, section "Scope").

Proved:
* `dotLoop_nanEq`, `dotLoop_eq_dotInOrder`: for every format, with the contraction off (`c` false
  or no `fadd` oracle number 2 modulo 3), `dotLoop` from `+0` and FloatLib's `Model.dotInOrder`
  in that format are the same word or both NaNs; the NaNs' payloads and signs may differ.
* `dotLoop_error_zero`, `dotLoop_error`: for every IEEE format, every `c`, list and oracle
  sequence, a finite result of `dotLoop` from `+0` is within `dotLoopBound fmt K T`, so within
  `dotBound fmt K T`, of the exact `Σ aₖ bₖ`, with `K` the length and `T = Σ |aₖ bₖ|`; each
  iteration may be fused or not.
* `isFinite_dotLoop`: for every IEEE format, every `c`, oracle sequence and list of finite words,
  `dotLoop` from `+0` is finite when `T + dotLoopBound fmt K T` is at most the largest finite
  value.
* `treeDot_approx`: for every IEEE format, flag, oracle sequence, lane count `W`, lane length
  `L`, length `n`, tree over the lanes and input grade, the word `treeDot t c o ls` (a loop from
  `+0` per lane over at most `L` of the pairs, the lanes' words added by `Model.add` along the
  tree `t` whose leaves are `0, …, W - 1`, each once) over words that are `GPUProof.Approx` at
  their grades of exact entries is `GPUProof.Approx` at `GPUProof.laneGrade (.ieee fmt) W
  t.depth L n` of the exact dot product; `treeDot_error` is the error half, from
  `Float.sum_error` (the tree's sum of the lanes), `lanes_error` (the lanes' loops) and
  `sum_mul_sub_le` (the inputs' error). Every order of the lanes' sum is covered, so each lane of
  a butterfly is an instance (MojoProof/Tile/MatVec.lean).
* `dotLoop_approx`: for every IEEE format, flag, oracle sequence, length and input grade, the word
  of `dotLoop` from `+0` over words that are `GPUProof.Approx` at their grades of exact entries
  is `GPUProof.Approx` at `GPUProof.dotGrade` of the exact dot product: `treeDot_approx` at one
  lane, the tree of one leaf, as `GPUProof.dotGrade` is `GPUProof.laneGrade` at one lane and depth
  `0`. `dotGrade_ieee` shows that grade's error is `dotLoopBound` at its sum plus its cross sum,
  and `dotLoop_error_graded` (`treeDot_error`'s case) is the error half.
* `floatBin_dotStep`: for every float type and flags without `nnan`, `ninf`, `nsz`, `reassoc`,
  `arcp`, `afn`, `floatBin`'s `fmul` and then `fadd` with the factors `exec` records is `dotStep`.
* `dotLoop_neverFuse`: for every format, oracle numbers, word and pairs, `dotLoop true` at the
  numbers `3 * (n / 3)` is `dotLoop false` at the numbers `n`.

With the lemmas they use: `NaNEq.symm`, `NaNEq.trans`, `NaNEq.eq_isNaN`, `nanEq_deliver`,
`cast_self_nanEq`, `contract_unfused`, `dotSum_eq`, `deliver_finite`, `dotStep_error`,
`isFinite_of_dotLoop`, `dotBound_step`, `abs_deliver_mul_le`, `dotStep_bound_of`,
`dotStep_bound`, `dotStep_loopBound`, `dotStep_zero_bound`, `dotLoop_nanEq_foldl` (for every map
of the factors that keeps each non-NaN word, so MojoProof/Sem/Matmul.lean uses it for TorchLean's
fold), `dotLoop_error_step`, `dotLoop_error_of`, `dotLoopBound_le_dotBound`, `dotLoopBound_succ`,
`dotLoopBound_mono`, `dotStep_finite`, `isFinite_dotLoop_of`, `sum_abs_mul_le_graded` and
`sum_mul_sub_le`;
`dotBound_le_dotGrade` compares `dotBound` after `K` iterations with `GPUProof.dotGrade` at
length `K + 1`.
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange LLVM

variable {fmt : FloatFormat}

/-- One iteration of a contracted dot-product loop, as `floatBin` computes it: the product of the
factors `ab` through `deliver` at the `fmul`'s oracle number `n.1`, then, with the `contract` flag
`c`, `contract` of the accumulator `acc` (no recorded factors) and the product (factors `ab`) at
the `fadd`'s oracle number `n.2`, without it `Model.add`, through `deliver` at `n.2 / 3`. -/
def dotStep (c : Bool) (acc : Model fmt) (ab : Model fmt × Model fmt) (n : Nat × Nat) :
    Model fmt :=
  let p := deliver (Model.mul ab.1 ab.2) (n.1 / 3)
  deliver (if c then contract false acc p none (some ab) n.2 else Model.add acc p) (n.2 / 3)

/-- The contracted dot-product loop over the factor pairs `ps` from the word `acc`: iteration `j`
is `dotStep c` with the oracle numbers `o j` of its `fmul` and `fadd`. -/
def dotLoop (c : Bool) : (Nat → Nat × Nat) → Model fmt → List (Model fmt × Model fmt) → Model fmt
  | _, acc, [] => acc
  | o, acc, ab :: ps => dotLoop c (fun j => o (j + 1)) (dotStep c acc ab (o 0)) ps

/-- The roundoff bound of `dotLoop_error` after `K` iterations, for the exact absolute sum `T`:
`((1 + u) ^ (K + 1) - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u`, with `u` FloatLib's unit roundoff
and `η` its underflow allowance of `fmt`. -/
noncomputable def dotBound (fmt : FloatFormat) (K : Nat) (T : ℝ) : ℝ :=
  ((1 + Model.unitRoundoffAt fmt) ^ (K + 1) - 1) * T +
    (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
      ((1 + Model.unitRoundoffAt fmt) ^ K - 1) / Model.unitRoundoffAt fmt

/-- The roundoff bound of `dotLoop_error_zero` after `K` iterations from `+0`, for the exact
absolute sum `T`: `((1 + u) ^ K - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u`, with `u` FloatLib's
unit roundoff and `η` its underflow allowance of `fmt`. It is `dotBound fmt K T` with one power of
`1 + u` fewer on `T`: the first `fadd` adds its product to `+0` exactly. -/
noncomputable def dotLoopBound (fmt : FloatFormat) (K : Nat) (T : ℝ) : ℝ :=
  ((1 + Model.unitRoundoffAt fmt) ^ K - 1) * T +
    (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
      ((1 + Model.unitRoundoffAt fmt) ^ K - 1) / Model.unitRoundoffAt fmt

/-- `NaNEq` is symmetric, in every format. -/
theorem NaNEq.symm {x y : Model fmt} (h : NaNEq x y) : NaNEq y x :=
  (GPUProof.UpToNaN.equivalence _).symm h

/-- `NaNEq` is transitive, in every format: a word related to a NaN is a NaN. -/
theorem NaNEq.trans {x y z : Model fmt} (h₁ : NaNEq x y) (h₂ : NaNEq y z) : NaNEq x z :=
  (GPUProof.UpToNaN.equivalence _).trans h₁ h₂

/-- The two halves of `NaNEq x y`, in every format: when `y` is not a NaN, `x` is `y`; and `x` is
a NaN exactly when `y` is. -/
theorem NaNEq.eq_isNaN {x y : Model fmt} (h : NaNEq x y) :
    (y.isNaN = false → x = y) ∧ x.isNaN = y.isNaN := by
  rcases h with h | ⟨h₁, h₂⟩
  · exact ⟨fun _ => h, by rw [h]⟩
  · refine ⟨fun h => ?_, by rw [h₁, h₂]⟩
    rw [h₂] at h
    cases h

/-- A delivered result and the IEEE 754 result are `NaNEq`, for every word and oracle number:
`deliver` replaces a NaN only, by a NaN. -/
theorem nanEq_deliver (r : Model fmt) (n : Nat) : NaNEq (deliver r n) r := by
  cases hr : r.isNaN
  · exact .inl (deliver_of_isNaN_eq_false hr n)
  · exact .inr ⟨isNaN_deliver hr n, hr⟩

/-- FloatLib's cast of a word to its own format is `NaNEq` to the word, in every format: a finite
word is kept (`Model.cast_self_of_finite`), an infinity is the overflow result of its sign, which
is itself (`Model.eq_nativeOverflow_of_isInfinite`), and a NaN is quieted, a NaN again. So the cast
is the identity on every word that is not a NaN. -/
theorem cast_self_nanEq (x : Model fmt) : NaNEq (Model.cast fmt fmt x) x := by
  by_cases hn : x.isNaN = true
  · refine .inr ⟨?_, hn⟩
    simp [Model.cast, Model.Internal.Nearest.cast, hn]
  · refine .inl ?_
    have hn' : x.isNaN = false := by simpa using hn
    by_cases hi : x.isInfinite = true
    · obtain ⟨-, he⟩ := Model.eq_nativeOverflow_of_isInfinite hi
      conv_rhs => rw [he]
      simp [Model.cast, Model.Internal.Nearest.cast, hn', hi]
    · exact Model.cast_self_of_finite x
        (Model.isFinite_eq_true_of_isNaN_eq_false_of_isInfinite_eq_false x hn' (by simpa using hi))

/-- A contracted `fadd` whose left operand has no recorded factors is the unfused `Model.add`
under every oracle number `n` with `n % 3 ≠ 2`, whatever the right operand's factors `ab`. -/
theorem contract_unfused (x y : Model fmt) (ab : Model fmt × Model fmt) {n : Nat}
    (hn : n % 3 ≠ 2) : contract false x y none (some ab) n = Model.add x y := by
  obtain ⟨a, b⟩ := ab
  have h : n % 3 = 0 ∨ n % 3 = 1 := by omega
  rcases h with h | h <;> simp [contract, h]

/-- The sum of `dotStep` is a contraction in both cases of the flag `c`: with `c` at the oracle
number `n`, without it at the oracle number 0, which is unfused (`contract_unfused`). For all
words and factors. -/
theorem dotSum_eq (c : Bool) (acc p : Model fmt) (ab : Model fmt × Model fmt) (n : Nat) :
    (if c then contract false acc p none (some ab) n else Model.add acc p) =
      contract false acc p none (some ab) (if c then n else 0) := by
  cases c
  · simp [contract_unfused acc p ab (n := 0) (by decide)]
  · simp

/-- A finite delivered word is the IEEE 754 result, which is finite, for every oracle number. -/
theorem deliver_finite {r : Model fmt} {n : Nat} (h : (deliver r n).isFinite = true) :
    r.isFinite = true ∧ deliver r n = r := by
  cases hr : r.isNaN
  · rw [deliver_of_isNaN_eq_false hr] at h ⊢
    exact ⟨h, rfl⟩
  · rw [Model.isFinite_eq_false_of_isNaN (isNaN_deliver hr n)] at h
    cases h

/-- **One iteration's roundoff** (of `contract_error`): in an IEEE format, for every flag `c`,
words `acc`, `a`, `b` and oracle numbers `n`, if `dotStep c acc (a, b) n` is finite, then `acc` is
finite and the result is within `max (h(ab) + h(acc + p)) (h(acc + ab))` of
`acc + a b` (real values), where `h` is half an ULP (`Model.halfUlpAt fmt`) and `p` the rounded
product `deliver (Model.mul a b) (n.1 / 3)`: the first term bounds the unfused choice, the second
the fused one. -/
theorem dotStep_error (hfmt : fmt.isIEEE = true) (c : Bool) (acc a b : Model fmt) (n : Nat × Nat)
    (h : (dotStep c acc (a, b) n).isFinite = true) :
    acc.isFinite = true ∧
      |(dotStep c acc (a, b) n).toReal - (acc.toReal + a.toReal * b.toReal)| ≤
        max (Model.halfUlpAt fmt (a.toReal * b.toReal) +
            Model.halfUlpAt fmt (acc.toReal + (deliver (Model.mul a b) (n.1 / 3)).toReal))
          (Model.halfUlpAt fmt (acc.toReal + a.toReal * b.toReal)) := by
  have hd : dotStep c acc (a, b) n = deliver (contract false acc (deliver (Model.mul a b)
      (n.1 / 3)) none (some (a, b)) (if c then n.2 else 0)) (n.2 / 3) := by
    simp only [dotStep]
    rw [dotSum_eq]
  rw [hd] at h ⊢
  obtain ⟨hf, he⟩ := deliver_finite h
  rw [he]
  have hP : IsProd (deliver (Model.mul a b) (n.1 / 3)) (some (a, b)) := by
    rintro _ _ ⟨⟩ hp
    obtain ⟨hm, e⟩ := deliver_finite hp
    exact ⟨hm, by rw [e]⟩
  have e := contract_error hfmt false (x := acc) (px := none) (fun _ _ h => by cases h) hP _ hf
  simp only [exact, factorErr, Bool.false_eq_true, ↓reduceIte, one_mul, zero_add] at e
  refine ⟨?_, e.trans (max_le (le_max_left _ _) le_rfl)⟩
  rcases contract_cases false acc (deliver (Model.mul a b) (n.1 / 3)) none (some (a, b))
      (if c then n.2 else 0) with hc | ⟨_, _, hc, -⟩ | ⟨_, _, -, hc⟩
  · rw [hc] at hf
    exact (Model.isFinite_of_isFinite_add hfmt (by simpa using hf)).1
  · cases hc
  · rw [hc] at hf
    exact (Model.isFinite_of_isFinite_fma hfmt hf).2.2

/-- In an IEEE format, a finite result of `dotLoop` comes from a finite start word, for every
flag, oracle sequence and list of factor pairs. -/
theorem isFinite_of_dotLoop (hfmt : fmt.isIEEE = true) (c : Bool) :
    ∀ (ps : List (Model fmt × Model fmt)) (o : Nat → Nat × Nat) (acc : Model fmt),
      (dotLoop c o acc ps).isFinite = true → acc.isFinite = true
  | [], _, _, h => h
  | (a, b) :: ps, o, acc, h =>
    (dotStep_error hfmt c acc a b (o 0) (isFinite_of_dotLoop hfmt c ps _ _ h)).1

/-- The arithmetic of one iteration of `dotLoop_error_of`, on reals: if the start `x` is within
`(q (1 + u) - 1) S + β` of `E` with `|E| ≤ S`, the rounded product `y` of the exact product `P` has
`|y| ≤ (1 + u) |P| + η`, and the result `r` is within `max (h₁ + h₂) h₃` of `x + P` with
`h₁ ≤ u |P| + η`, `h₂ ≤ u |x + y| + η`, `h₃ ≤ u |x + P| + η`, then `r` is within
`(q (1 + u) (1 + u) - 1) (S + |P|) + β'` of `E + P`, where `(1 + u) β + (2 + u) η = β'`, for all
`u, η > 0` and `q ≥ 1`. -/
theorem dotBound_step {u η q S P x y r E h₁ h₂ h₃ β β' : ℝ} (hu : 0 < u) (hη : 0 < η)
    (hq : 1 ≤ q) (hβ' : (1 + u) * β + (2 + u) * η = β') (hE : |E| ≤ S)
    (hx : |x - E| ≤ (q * (1 + u) - 1) * S + β) (hy : |y| ≤ (1 + u) * |P| + η)
    (hr : |r - (x + P)| ≤ max (h₁ + h₂) h₃) (h1 : h₁ ≤ u * |P| + η)
    (h2 : h₂ ≤ u * |x + y| + η) (h3 : h₃ ≤ u * |x + P| + η) :
    |r - (E + P)| ≤ (q * (1 + u) * (1 + u) - 1) * (S + |P|) + β' := by
  have hxa : |x| ≤ q * (1 + u) * S + β := by
    have := abs_sub_abs_le_abs_sub x E
    linarith
  have hxy := abs_add_le x y
  have hxP := abs_add_le x P
  have hP := abs_nonneg P
  have m1 : u * |x + y| ≤ u * (q * (1 + u) * S + β + ((1 + u) * |P| + η)) :=
    mul_le_mul_of_nonneg_left (by linarith) hu.le
  have m2 : u * |x + P| ≤ u * (q * (1 + u) * S + β + |P|) :=
    mul_le_mul_of_nonneg_left (by linarith) hu.le
  have m3 : ((1 + u) * (1 + u) - 1) * |P| ≤ (q * (1 + u) * (1 + u) - 1) * |P| := by
    apply mul_le_mul_of_nonneg_right _ hP
    have : 0 ≤ (q - 1) * ((1 + u) * (1 + u)) :=
      mul_nonneg (by linarith) (mul_nonneg (by linarith) (by linarith))
    linarith
  have m4 : 0 ≤ u * ((1 + u) * |P|) := mul_nonneg hu.le (mul_nonneg (by linarith) hP)
  have m5 : 0 ≤ u * η := mul_nonneg hu.le hη.le
  have hmax : max (h₁ + h₂) h₃ ≤
      u * |P| + η + u * (q * (1 + u) * S + β + ((1 + u) * |P| + η)) + η :=
    max_le (by linarith) (by linarith)
  have hd : |r - (E + P)| ≤ |x - E| + |r - (x + P)| := by
    have e : r - (E + P) = (x - E) + (r - (x + P)) := by ring
    rw [e]
    exact abs_add_le _ _
  nlinarith

/-- The rounded product of `dotStep`, for every IEEE format, words `a`, `b` and oracle number `n`:
`|deliver (Model.mul a b) n| ≤ (1 + u) |a b| + η` (real values, an infinity or a NaN at 0), from
FloatLib's `Model.abs_toReal_mul_sub_le` and `Model.halfUlpAt_le`. -/
theorem abs_deliver_mul_le (hfmt : fmt.isIEEE = true) (a b : Model fmt) (n : Nat) :
    |(deliver (Model.mul a b) n).toReal| ≤
      (1 + Model.unitRoundoffAt fmt) * |a.toReal * b.toReal| + Model.underflowErrorAt fmt := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  cases hpf : (deliver (Model.mul a b) n).isFinite
  · rw [Model.toReal_eq_zero_of_isFinite_eq_false hpf, abs_zero]
    have := mul_nonneg (by linarith : (0 : ℝ) ≤ 1 + Model.unitRoundoffAt fmt)
      (abs_nonneg (a.toReal * b.toReal))
    linarith
  · obtain ⟨hm, he⟩ := deliver_finite hpf
    rw [he]
    have e1 := Model.abs_toReal_mul_sub_le a b hfmt hm
    have e2 := Model.halfUlpAt_le fmt (a.toReal * b.toReal)
    have e3 := abs_sub_abs_le_abs_sub (Model.mul a b).toReal (a.toReal * b.toReal)
    linarith

/-- One iteration of a bound of the form
`((1 + u) ^ (m + 1) - 1) S + (2 + u) η ((1 + u) ^ j - 1) / u`: in an IEEE format, for every flag
`c`, words `acc`, `a`, `b`, oracle numbers `n`, counts `m`, `j` and reals `E`, `S` with `|E| ≤ S`,
if `acc` is within that bound of `E` and `dotStep c acc (a, b) n` is finite, then that result is
within `((1 + u) ^ (m + 2) - 1) (S + |a b|) + (2 + u) η ((1 + u) ^ (j + 1) - 1) / u` of `E + a b`
(real values). `dotBound` is the case `j = m` (`dotStep_bound`), `dotLoopBound` the case `j = m + 1`
(`dotStep_loopBound`). -/
theorem dotStep_bound_of (hfmt : fmt.isIEEE = true) {c : Bool} {acc a b : Model fmt}
    {n : Nat × Nat} {m j : Nat} {E S : ℝ} (hE : |E| ≤ S)
    (hacc : |acc.toReal - E| ≤ ((1 + Model.unitRoundoffAt fmt) ^ (m + 1) - 1) * S +
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
        ((1 + Model.unitRoundoffAt fmt) ^ j - 1) / Model.unitRoundoffAt fmt)
    (h : (dotStep c acc (a, b) n).isFinite = true) :
    |(dotStep c acc (a, b) n).toReal - (E + a.toReal * b.toReal)| ≤
      ((1 + Model.unitRoundoffAt fmt) ^ (m + 1 + 1) - 1) * (S + |a.toReal * b.toReal|) +
        (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          ((1 + Model.unitRoundoffAt fmt) ^ (j + 1) - 1) / Model.unitRoundoffAt fmt := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hq : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ m := one_le_pow₀ (by linarith)
  have hβ : (1 + Model.unitRoundoffAt fmt) * ((2 + Model.unitRoundoffAt fmt) *
      Model.underflowErrorAt fmt * ((1 + Model.unitRoundoffAt fmt) ^ j - 1) /
        Model.unitRoundoffAt fmt) + (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt =
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
        ((1 + Model.unitRoundoffAt fmt) ^ j * (1 + Model.unitRoundoffAt fmt) - 1) /
          Model.unitRoundoffAt fmt := by
    field_simp
    ring
  simp only [pow_succ] at hacc ⊢
  rw [← hβ]
  obtain ⟨-, hr⟩ := dotStep_error hfmt c acc a b n h
  exact dotBound_step hu (Model.underflowErrorAt_pos fmt) hq rfl hE hacc
    (abs_deliver_mul_le hfmt a b _) hr (Model.halfUlpAt_le fmt _) (Model.halfUlpAt_le fmt _)
    (Model.halfUlpAt_le fmt _)

/-- **One iteration of the bound**: in an IEEE format, for every flag `c`, words `acc`, `a`, `b`,
oracle numbers `n`, count `m` and reals `E`, `S` with `|E| ≤ S`, if `acc` is within
`dotBound fmt m S` of `E` and `dotStep c acc (a, b) n` is finite, then that result is within
`dotBound fmt (m + 1) (S + |a b|)` of `E + a b` (real values). -/
theorem dotStep_bound (hfmt : fmt.isIEEE = true) {c : Bool} {acc a b : Model fmt} {n : Nat × Nat}
    {m : Nat} {E S : ℝ} (hE : |E| ≤ S) (hacc : |acc.toReal - E| ≤ dotBound fmt m S)
    (h : (dotStep c acc (a, b) n).isFinite = true) :
    |(dotStep c acc (a, b) n).toReal - (E + a.toReal * b.toReal)| ≤
      dotBound fmt (m + 1) (S + |a.toReal * b.toReal|) := by
  unfold dotBound at hacc ⊢
  exact dotStep_bound_of hfmt hE hacc h

/-- **One iteration of the loop bound**: in an IEEE format, for every flag `c`, words `acc`, `a`,
`b`, oracle numbers `n`, count `m` and reals `E`, `S` with `|E| ≤ S`, if `acc` is within
`dotLoopBound fmt (m + 1) S` of `E` and `dotStep c acc (a, b) n` is finite, then that result is
within `dotLoopBound fmt (m + 1 + 1) (S + |a b|)` of `E + a b` (real values). -/
theorem dotStep_loopBound (hfmt : fmt.isIEEE = true) {c : Bool} {acc a b : Model fmt}
    {n : Nat × Nat} {m : Nat} {E S : ℝ} (hE : |E| ≤ S)
    (hacc : |acc.toReal - E| ≤ dotLoopBound fmt (m + 1) S)
    (h : (dotStep c acc (a, b) n).isFinite = true) :
    |(dotStep c acc (a, b) n).toReal - (E + a.toReal * b.toReal)| ≤
      dotLoopBound fmt (m + 1 + 1) (S + |a.toReal * b.toReal|) := by
  unfold dotLoopBound at hacc ⊢
  exact dotStep_bound_of hfmt hE hacc h

/-- **The first iteration is one rounding**: in an IEEE format, for every flag `c`, words `a`,
`b` and oracle numbers `n`, if `dotStep c (+0) (a, b) n` is finite, then it is within
`dotLoopBound fmt 1 |a b|`, that is `u |a b| + (2 + u) η`, of `a b` (real values): unfused, the
sum of `+0` and the rounded product is that product exactly (FloatLib's
`Model.toReal_add_of_isZero_left`); fused, `fma a b (+0)` is one rounding of `a b`. -/
theorem dotStep_zero_bound (hfmt : fmt.isIEEE = true) (c : Bool) (a b : Model fmt)
    (n : Nat × Nat) (h : (dotStep c (Model.zero fmt false) (a, b) n).isFinite = true) :
    |(dotStep c (Model.zero fmt false) (a, b) n).toReal - a.toReal * b.toReal| ≤
      dotLoopBound fmt 1 |a.toReal * b.toReal| := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hd : dotStep c (Model.zero fmt false) (a, b) n =
      deliver (contract false (Model.zero fmt false) (deliver (Model.mul a b) (n.1 / 3)) none
        (some (a, b)) (if c then n.2 else 0)) (n.2 / 3) := by
    simp only [dotStep]
    rw [dotSum_eq]
  rw [hd] at h ⊢
  obtain ⟨hf, he⟩ := deliver_finite h
  rw [he]
  have hb : dotLoopBound fmt 1 |a.toReal * b.toReal| =
      Model.unitRoundoffAt fmt * |a.toReal * b.toReal| +
        (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt := by
    unfold dotLoopBound
    field_simp
    ring
  rw [hb]
  have h2 := Model.halfUlpAt_le fmt (a.toReal * b.toReal)
  rcases contract_cases false (Model.zero fmt false) (deliver (Model.mul a b) (n.1 / 3)) none
      (some (a, b)) (if c then n.2 else 0) with hc | ⟨_, _, hc, -⟩ | ⟨_, _, hpy, hc⟩
  · rw [hc] at hf ⊢
    simp only [Bool.false_eq_true, ↓reduceIte] at hf ⊢
    have hp := (Model.isFinite_of_isFinite_add hfmt hf).2
    rw [Model.toReal_add_of_isZero_left _ _ hfmt (Model.isZero_zero fmt false) hp]
    obtain ⟨hm, e⟩ := deliver_finite hp
    rw [e]
    have := Model.abs_toReal_mul_sub_le a b hfmt hm
    have := mul_pos hu hη
    linarith
  · cases hc
  · obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Option.some.inj hpy)
    rw [hc] at hf ⊢
    simp only [Bool.false_eq_true, ↓reduceIte] at hf ⊢
    have := Model.abs_toReal_fma_sub_le _ _ _ hfmt hf
    simp only [Model.toReal_zero, add_zero] at this
    have := mul_pos hu hη
    linarith

/-- The induction of `dotLoop_error_of` and `dotLoop_error_zero`, for every family of bounds `B`
that one iteration keeps: in an IEEE format, for every flag `c`, if for all words `acc`, `a`, `b`,
oracle numbers, counts `m` and reals `E`, `S` with `|E| ≤ S` a finite `dotStep` from `acc` within
`B m S` of `E` is within `B (m + 1) (S + |a b|)` of `E + a b`, then for every list of factor
pairs `ps`, oracle sequence, start word `acc`, count `m` and reals `E`, `S` with `|E| ≤ S` and
`acc` within `B m S` of `E`, a finite result of `dotLoop` from `acc` is within
`B (m + K) (S + T)` of `E + Σ aₖ bₖ`, with `K` the length of `ps` and `T = Σ |aₖ bₖ|`. -/
theorem dotLoop_error_step (hfmt : fmt.isIEEE = true) (c : Bool) (B : Nat → ℝ → ℝ)
    (hB : ∀ (acc a b : Model fmt) (n : Nat × Nat) (m : Nat) (E S : ℝ), |E| ≤ S →
      |acc.toReal - E| ≤ B m S → (dotStep c acc (a, b) n).isFinite = true →
      |(dotStep c acc (a, b) n).toReal - (E + a.toReal * b.toReal)| ≤
        B (m + 1) (S + |a.toReal * b.toReal|)) :
    ∀ (ps : List (Model fmt × Model fmt)) (o : Nat → Nat × Nat) (acc : Model fmt) (m : Nat)
      (E S : ℝ), |E| ≤ S → |acc.toReal - E| ≤ B m S →
      (dotLoop c o acc ps).isFinite = true →
      |(dotLoop c o acc ps).toReal - (E + (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum)| ≤
        B (m + ps.length) (S + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum)
  | [], _, acc, m, E, S, _, h, _ => by simpa [dotLoop] using h
  | (a, b) :: ps, o, acc, m, E, S, hE, h, hf => by
    have hf' : (dotLoop c (fun j => o (j + 1)) (dotStep c acc (a, b) (o 0)) ps).isFinite =
        true := hf
    have hs := hB acc a b (o 0) m E S hE h (isFinite_of_dotLoop hfmt c ps _ _ hf')
    have hE' : |E + a.toReal * b.toReal| ≤ S + |a.toReal * b.toReal| := by
      have := abs_add_le E (a.toReal * b.toReal)
      linarith
    have ih := dotLoop_error_step hfmt c B hB ps (fun j => o (j + 1)) _ (m + 1) _ _ hE' hs hf'
    simp only [dotLoop, List.map_cons, List.sum_cons, List.length_cons]
    rw [show m + (ps.length + 1) = m + 1 + ps.length by omega, ← add_assoc, ← add_assoc]
    exact ih

/-- The induction of `dotLoop_error`: in an IEEE format, for every flag, list of factor pairs
`ps`, oracle sequence, start word `acc`, count `m` and reals `E`, `S` with `|E| ≤ S` and `acc`
within `dotBound fmt m S` of `E`, a finite result of `dotLoop` from `acc` is within
`dotBound fmt (m + K) (S + T)` of `E + Σ aₖ bₖ`, with `K` the length of `ps` and
`T = Σ |aₖ bₖ|`. -/
theorem dotLoop_error_of (hfmt : fmt.isIEEE = true) (c : Bool) :
    ∀ (ps : List (Model fmt × Model fmt)) (o : Nat → Nat × Nat) (acc : Model fmt) (m : Nat)
      (E S : ℝ), |E| ≤ S → |acc.toReal - E| ≤ dotBound fmt m S →
      (dotLoop c o acc ps).isFinite = true →
      |(dotLoop c o acc ps).toReal - (E + (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum)| ≤
        dotBound fmt (m + ps.length) (S + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
  dotLoop_error_step hfmt c (dotBound fmt) fun _ _ _ _ _ _ _ hE h hf => dotStep_bound hfmt hE h hf

/-- **The roundoff of the contracted dot-product loop from `+0`**: in every IEEE format, for every
`contract` flag `c`, oracle sequence `o` (each iteration fused or not, as `o` chooses) and list
of factor pairs `ps` of length `K`, if the loop's result `r` from `+0` is finite, then
`|r - Σ aₖ bₖ| ≤ dotLoopBound fmt K T`, that is
`((1 + u) ^ K - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u` with `T = Σ |aₖ bₖ|`, the real values of
the words, `u` the unit roundoff and `η` the underflow allowance. Each product and each sum after
the first is rounded. A rounding of a value `s` errs by at most `u |s| + η`, and `|s|` includes
the error made before, so each later rounding multiplies an earlier error by at most `1 + u`; the
exponent `K` counts the roundings a product passes through: the first product its own and the
`K - 1` later sums, since the first sum, to `+0`, is exact (`dotStep_zero_bound`), and product
`j > 1` its own and the sums `j` to `K`, `K - j + 2` of them (`dotStep_loopBound`). Nothing is
claimed when the result is infinite or a NaN. -/
theorem dotLoop_error_zero (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt))
    (h : (dotLoop c o (Model.zero fmt false) ps).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) ps).toReal -
        (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      dotLoopBound fmt ps.length (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  cases ps with
  | nil => simp [dotLoop, dotLoopBound]
  | cons ab ps =>
    obtain ⟨a, b⟩ := ab
    have hf : (dotLoop c (fun j => o (j + 1)) (dotStep c (Model.zero fmt false) (a, b) (o 0))
        ps).isFinite = true := h
    have h1 := dotStep_zero_bound hfmt c a b (o 0) (isFinite_of_dotLoop hfmt c ps _ _ hf)
    have e := dotLoop_error_step hfmt c (fun m S => dotLoopBound fmt (m + 1) S)
      (fun _ _ _ _ _ _ _ hE h hf => dotStep_loopBound hfmt hE h hf) ps (fun j => o (j + 1)) _ 0
      (a.toReal * b.toReal) |a.toReal * b.toReal| le_rfl h1 hf
    simp only [dotLoop, List.map_cons, List.sum_cons, List.length_cons]
    simpa using e

/-- `dotLoopBound` is at most `dotBound`, for every format, count `K` and real `T ≥ 0`. -/
theorem dotLoopBound_le_dotBound (fmt : FloatFormat) (K : Nat) {T : ℝ} (hT : 0 ≤ T) :
    dotLoopBound fmt K T ≤ dotBound fmt K T := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hK : (1 + Model.unitRoundoffAt fmt) ^ K ≤ (1 + Model.unitRoundoffAt fmt) ^ (K + 1) :=
    pow_le_pow_right₀ (by linarith) (Nat.le_succ K)
  have := mul_le_mul_of_nonneg_right (sub_le_sub_right hK 1) hT
  unfold dotLoopBound dotBound
  linarith

/-- **The roundoff of the contracted dot-product loop**: in every IEEE format, for every
`contract` flag `c`, oracle sequence `o` (each iteration fused or not, as `o` chooses) and list
of factor pairs `ps` of length `K`, if the loop's result `r` from `+0` is finite, then
`|r - Σ aₖ bₖ| ≤ dotBound fmt K T`, that is
`((1 + u) ^ (K + 1) - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u` with `T = Σ |aₖ bₖ|`, the
real values of the words, `u` the unit roundoff and `η` the underflow allowance. Nothing is
claimed when the result is infinite or a NaN. `dotLoop_error_zero` is the sharper bound. -/
theorem dotLoop_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt))
    (h : (dotLoop c o (Model.zero fmt false) ps).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) ps).toReal -
        (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      dotBound fmt ps.length (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  (dotLoop_error_zero hfmt c o ps h).trans
    (dotLoopBound_le_dotBound fmt _ (List.sum_nonneg fun _ h => by
      obtain ⟨_, -, rfl⟩ := List.mem_map.1 h; exact abs_nonneg _))

/-- One iteration's growth of `dotLoopBound`, for every format, count `K` and reals `S ≥ 0`, `P`:
`dotLoopBound fmt K S + u |P| + η ≤ dotLoopBound fmt (K + 1) (S + |P|)`. -/
theorem dotLoopBound_succ (fmt : FloatFormat) (K : Nat) {S : ℝ} (P : ℝ) (hS : 0 ≤ S) :
    dotLoopBound fmt K S + Model.unitRoundoffAt fmt * |P| + Model.underflowErrorAt fmt ≤
      dotLoopBound fmt (K + 1) (S + |P|) := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hq : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ K := one_le_pow₀ (by linarith)
  have e : (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
      ((1 + Model.unitRoundoffAt fmt) ^ K * (1 + Model.unitRoundoffAt fmt) - 1) /
        Model.unitRoundoffAt fmt =
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          ((1 + Model.unitRoundoffAt fmt) ^ K - 1) / Model.unitRoundoffAt fmt +
        (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          (1 + Model.unitRoundoffAt fmt) ^ K := by
    field_simp
    ring
  have p1 : 0 ≤ Model.unitRoundoffAt fmt * (1 + Model.unitRoundoffAt fmt) ^ K * S :=
    mul_nonneg (mul_nonneg hu.le (by linarith)) hS
  have p2 : 0 ≤ ((1 + Model.unitRoundoffAt fmt) ^ K - 1) *
      ((1 + Model.unitRoundoffAt fmt) * |P|) :=
    mul_nonneg (by linarith) (mul_nonneg (by linarith) (abs_nonneg P))
  have p3 : 0 ≤ ((2 + Model.unitRoundoffAt fmt) * (1 + Model.unitRoundoffAt fmt) ^ K - 1) *
      Model.underflowErrorAt fmt :=
    mul_nonneg (by nlinarith) hη.le
  unfold dotLoopBound
  rw [pow_succ, e]
  linarith

/-- `dotLoopBound` grows with the count and the sum, for every format, counts `K ≤ K'` and reals
`0 ≤ T ≤ T'`. -/
theorem dotLoopBound_mono (fmt : FloatFormat) {K K' : Nat} {T T' : ℝ} (hK : K ≤ K')
    (hT : 0 ≤ T) (hT' : T ≤ T') : dotLoopBound fmt K T ≤ dotLoopBound fmt K' T' := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hq : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ K := one_le_pow₀ (by linarith)
  have hqq : (1 + Model.unitRoundoffAt fmt) ^ K ≤ (1 + Model.unitRoundoffAt fmt) ^ K' :=
    pow_le_pow_right₀ (by linarith) hK
  have m1 : ((1 + Model.unitRoundoffAt fmt) ^ K - 1) * T ≤
      ((1 + Model.unitRoundoffAt fmt) ^ K' - 1) * T' :=
    mul_le_mul (by linarith) hT' hT (by linarith)
  have m2 : (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
      ((1 + Model.unitRoundoffAt fmt) ^ K - 1) ≤
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
        ((1 + Model.unitRoundoffAt fmt) ^ K' - 1) :=
    mul_le_mul_of_nonneg_left (by linarith) (mul_nonneg (by linarith) hη.le)
  unfold dotLoopBound
  linarith [div_le_div_of_nonneg_right m2 hu.le]

/-- **One finite iteration**: in an IEEE format, for every flag `c`, oracle numbers `n`, finite
words `acc`, `a`, `b`, count `K` and reals `E`, `S` with `|E| ≤ S` and `acc` within
`dotLoopBound fmt K S` of `E`, if `S + |a b| + dotLoopBound fmt (K + 1) (S + |a b|)` is at most
the largest finite value, then `dotStep c acc (a, b) n` is finite: the product, the sum and the
fused `fma` all stay in range (FloatLib's `Model.isFinite_mul_of_abs_mul_le_posMaxFinite`,
`Model.isFinite_add_of_abs_toReal_add_le_posMaxFinite` and
`Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite`). -/
theorem dotStep_finite (hfmt : fmt.isIEEE = true) (c : Bool) {acc a b : Model fmt}
    (n : Nat × Nat) {K : Nat} {E S : ℝ} (hacc : acc.isFinite = true) (ha : a.isFinite = true)
    (hb : b.isFinite = true) (hE : |E| ≤ S) (he : |acc.toReal - E| ≤ dotLoopBound fmt K S)
    (hmax : S + |a.toReal * b.toReal| + dotLoopBound fmt (K + 1) (S + |a.toReal * b.toReal|) ≤
      (Model.posMaxFinite fmt).toReal) :
    (dotStep c acc (a, b) n).isFinite = true := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hsucc := dotLoopBound_succ fmt K (a.toReal * b.toReal) ((abs_nonneg E).trans hE)
  have hP := mul_nonneg hu.le (abs_nonneg (a.toReal * b.toReal))
  have hxa : |acc.toReal| ≤ S + dotLoopBound fmt K S := by
    have := abs_sub_abs_le_abs_sub acc.toReal E
    linarith
  have h0 := abs_nonneg acc.toReal
  have hm : (Model.mul a b).isFinite = true :=
    Model.isFinite_mul_of_abs_mul_le_posMaxFinite a b hfmt ha hb (by rw [← abs_mul]; linarith)
  have hpe : deliver (Model.mul a b) (n.1 / 3) = Model.mul a b :=
    deliver_of_isNaN_eq_false (Model.isNaN_eq_false_of_isFinite_eq_true _ hm) _
  have hy := abs_deliver_mul_le hfmt a b (n.1 / 3)
  rw [hpe] at hy
  have hd : dotStep c acc (a, b) n = deliver (contract false acc (Model.mul a b) none
      (some (a, b)) (if c then n.2 else 0)) (n.2 / 3) := by
    simp only [dotStep]
    rw [dotSum_eq, hpe]
  rw [hd]
  suffices hr : (contract false acc (Model.mul a b) none (some (a, b))
      (if c then n.2 else 0)).isFinite = true by
    rwa [deliver_of_isNaN_eq_false (Model.isNaN_eq_false_of_isFinite_eq_true _ hr)]
  rcases contract_cases false acc (Model.mul a b) none (some (a, b)) (if c then n.2 else 0) with
    hc | ⟨_, _, hc, -⟩ | ⟨_, _, hpy, hc⟩
  · rw [hc]
    simp only [Bool.false_eq_true, ↓reduceIte]
    refine Model.isFinite_add_of_abs_toReal_add_le_posMaxFinite acc _ hfmt hacc hm ?_
    have := abs_add_le acc.toReal (Model.mul a b).toReal
    linarith
  · cases hc
  · obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Option.some.inj hpy)
    rw [hc]
    simp only [Bool.false_eq_true, ↓reduceIte]
    refine Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite _ _ acc hfmt ha hb hacc ?_
    have := abs_add_le (a.toReal * b.toReal) acc.toReal
    have := abs_mul a.toReal b.toReal
    linarith

/-- The induction of `isFinite_dotLoop`: in an IEEE format, for every flag `c`, list of factor
pairs `ps` of finite words, oracle sequence, finite start word `acc`, count `m` and reals `E`, `S`
with `|E| ≤ S` and `acc` within `dotLoopBound fmt (m + 1) S` of `E`, if
`S + T + dotLoopBound fmt (m + 1 + K) (S + T)` is at most the largest finite value, with `K` the
length of `ps` and `T = Σ |aₖ bₖ|`, then `dotLoop` from `acc` is finite. -/
theorem isFinite_dotLoop_of (hfmt : fmt.isIEEE = true) (c : Bool) :
    ∀ (ps : List (Model fmt × Model fmt)) (o : Nat → Nat × Nat) (acc : Model fmt) (m : Nat)
      (E S : ℝ), |E| ≤ S → acc.isFinite = true → |acc.toReal - E| ≤ dotLoopBound fmt (m + 1) S →
      (∀ ab ∈ ps, ab.1.isFinite = true ∧ ab.2.isFinite = true) →
      S + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
          dotLoopBound fmt (m + 1 + ps.length)
            (S + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum) ≤
        (Model.posMaxFinite fmt).toReal →
      (dotLoop c o acc ps).isFinite = true
  | [], _, _, _, _, _, _, h, _, _, _ => h
  | (a, b) :: ps, o, acc, m, E, S, hE, hacc, he, hw, hmax => by
    have hT : 0 ≤ (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
      List.sum_nonneg fun _ h => by obtain ⟨_, -, rfl⟩ := List.mem_map.1 h; exact abs_nonneg _
    have hS := (abs_nonneg E).trans hE
    have hab := hw (a, b) (List.mem_cons_self ..)
    simp only [List.map_cons, List.sum_cons, List.length_cons] at hmax
    have hmono := dotLoopBound_mono fmt (K := m + 1 + 1) (K' := m + 1 + (ps.length + 1))
      (T := S + |a.toReal * b.toReal|)
      (T' := S + (|a.toReal * b.toReal| + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum))
      (by omega) (add_nonneg hS (abs_nonneg _)) (by linarith)
    have hf := dotStep_finite hfmt c (o 0) hacc hab.1 hab.2 hE he (by linarith)
    have hs := dotStep_loopBound hfmt hE he hf
    have hE' : |E + a.toReal * b.toReal| ≤ S + |a.toReal * b.toReal| := by
      have := abs_add_le E (a.toReal * b.toReal)
      linarith
    refine isFinite_dotLoop_of hfmt c ps (fun j => o (j + 1)) _ (m + 1) _ _ hE' hf hs
      (fun ab h => hw ab (List.mem_cons_of_mem _ h)) ?_
    rw [show m + 1 + 1 + ps.length = m + 1 + (ps.length + 1) by omega]
    simpa only [add_assoc] using hmax

/-- **The loop stays finite**: in every IEEE format, for every flag `c`, oracle sequence `o` and
list of factor pairs `ps` of finite words, of length `K`, if `T + dotLoopBound fmt K T` is at
most the largest finite value of `fmt`, with `T = Σ |aₖ bₖ|` (real values), then `dotLoop` from
`+0` is finite. -/
theorem isFinite_dotLoop (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt))
    (hw : ∀ ab ∈ ps, ab.1.isFinite = true ∧ ab.2.isFinite = true)
    (hmax : (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
        dotLoopBound fmt ps.length (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum ≤
      (Model.posMaxFinite fmt).toReal) :
    (dotLoop c o (Model.zero fmt false) ps).isFinite = true := by
  cases ps with
  | nil => exact Model.isFinite_eq_true_of_isZero_eq_true _ (Model.isZero_zero fmt false)
  | cons ab ps =>
    obtain ⟨a, b⟩ := ab
    have hT : 0 ≤ (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
      List.sum_nonneg fun _ h => by obtain ⟨_, -, rfl⟩ := List.mem_map.1 h; exact abs_nonneg _
    have hab := hw (a, b) (List.mem_cons_self ..)
    simp only [List.map_cons, List.sum_cons, List.length_cons] at hmax
    have hmono := dotLoopBound_mono fmt (K := 1) (K' := ps.length + 1)
      (T := |a.toReal * b.toReal|)
      (T' := |a.toReal * b.toReal| + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum)
      (by omega) (abs_nonneg _) (by linarith)
    have h0 : |(Model.zero fmt false).toReal - 0| ≤ dotLoopBound fmt 0 0 := by
      simp [dotLoopBound]
    have hf := dotStep_finite hfmt c (o 0) (Model.isFinite_eq_true_of_isZero_eq_true _
      (Model.isZero_zero fmt false)) hab.1 hab.2 (by simp) h0 (by simp only [zero_add]; linarith)
    have hs := dotStep_zero_bound hfmt c a b (o 0) hf
    refine isFinite_dotLoop_of hfmt c ps (fun j => o (j + 1)) _ 0 _ _ le_rfl hf hs
      (fun ab h => hw ab (List.mem_cons_of_mem _ h)) ?_
    rw [show 0 + 1 + ps.length = ps.length + 1 by omega]
    exact hmax

/-- The induction of `dotLoop_nanEq`: in every format, for every flag `c` and oracle sequence `o`
with the contraction off (`c` false, or no `fadd` oracle number 2 modulo 3), every map `g` of
the factors with `NaNEq x (g x)` for every word `x`, every list of factor pairs and start words
related by `NaNEq`, `dotLoop` and the left-to-right fold of `Model.add` with `Model.mul` of the
mapped factors give words related by `NaNEq`. With `g = Model.cast fmt fmt` the fold is
FloatLib's `dotInOrder` before its final cast; with `g = id` it is TorchLean's matmul fold. -/
theorem dotLoop_nanEq_foldl (c : Bool) (g : Model fmt → Model fmt) (hg : ∀ x, NaNEq x (g x)) :
    ∀ (ps : List (Model fmt × Model fmt)) (o : Nat → Nat × Nat) {acc acc' : Model fmt},
      (∀ j, c = true → (o j).2 % 3 ≠ 2) → NaNEq acc acc' →
      NaNEq (dotLoop c o acc ps)
        (ps.foldl (fun s v => Model.add s (Model.mul (g v.1) (g v.2))) acc')
  | [], _, _, _, _, h => h
  | (a, b) :: ps, o, acc, acc', hu, h => by
    simp only [dotLoop, List.foldl_cons]
    refine dotLoop_nanEq_foldl c g hg ps _ (fun j => hu (j + 1)) ?_
    have hp : NaNEq (deliver (Model.mul a b) ((o 0).1 / 3)) (Model.mul (g a) (g b)) :=
      (nanEq_deliver _ _).trans (NaNEq.op (op := .fmul) (f := fun x y => Model.mul x y) rfl
        (hg a) (hg b))
    have hs : (if c then contract false acc (deliver (Model.mul a b) ((o 0).1 / 3)) none
        (some (a, b)) (o 0).2 else Model.add acc (deliver (Model.mul a b) ((o 0).1 / 3))) =
        Model.add acc (deliver (Model.mul a b) ((o 0).1 / 3)) := by
      cases c
      · simp
      · simpa using contract_unfused acc (deliver (Model.mul a b) ((o 0).1 / 3)) (a, b)
          (hu 0 rfl)
    simp only [dotStep]
    rw [hs]
    exact (nanEq_deliver _ _).trans (NaNEq.op (op := .fadd) (f := fun x y => Model.add x y) rfl
      h hp)

/-- **The loop without contraction is FloatLib's in-order dot product**, up to NaNs: in every
format, for every flag `c` and oracle sequence `o` with the contraction off (`c` false, or no
`fadd` oracle number 2 modulo 3) and every list of factor pairs `ps`, `dotLoop` from `+0` and
`Model.dotInOrder fmt fmt ps` are `NaNEq`: the same word, or both NaNs, whose payloads and signs
may differ (the loop's come from the oracle, FloatLib's from its propagation and final cast). -/
theorem dotLoop_nanEq (c : Bool) (o : Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j, c = true → (o j).2 % 3 ≠ 2) :
    NaNEq (dotLoop c o (Model.zero fmt false) ps) (Model.dotInOrder fmt fmt ps) := by
  have h := dotLoop_nanEq_foldl c (Model.cast fmt fmt) (fun x => (cast_self_nanEq x).symm) ps o
    (acc := Model.zero fmt false) (acc' := Model.zero fmt false) hu (.inl rfl)
  exact h.trans (cast_self_nanEq _).symm

/-- The two halves of `dotLoop_nanEq`, under its premises (every format, the contraction off):
when FloatLib's `Model.dotInOrder fmt fmt ps` is not a NaN, `dotLoop` from `+0` is that word, bit
for bit; and `dotLoop`'s word is a NaN exactly when FloatLib's is. -/
theorem dotLoop_eq_dotInOrder (c : Bool) (o : Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j, c = true → (o j).2 % 3 ≠ 2) :
    ((Model.dotInOrder fmt fmt ps).isNaN = false →
        dotLoop c o (Model.zero fmt false) ps = Model.dotInOrder fmt fmt ps) ∧
      (dotLoop c o (Model.zero fmt false) ps).isNaN = (Model.dotInOrder fmt fmt ps).isNaN :=
  (dotLoop_nanEq c o ps hu).eq_isNaN

/-- **One iteration in the semantics**: for every float type `t`, flags `fm` without `nnan`,
`ninf`, `nsz`, `reassoc`, `arcp` and `afn`, words `acc`, `a`, `b` and oracle numbers `n₁`, `n₂`,
`floatBin`'s `fmul` of `a` and `b` (no factors) under `n₁`, followed by its `fadd` of `acc` (no
factors, as for a `phi` result) and that product, with the factors `(a, b)` that `exec` records
when `fm.contract`, under `n₂`, gives the scalar of `dotStep fm.contract acc (a, b) (n₁, n₂)`. -/
theorem floatBin_dotStep {t : FloatTy} {fm : FastMath}
    (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false) (hn : fm.nnan = false)
    (hi : fm.ninf = false) (acc a b : Model t.fmt) (n₁ n₂ : Nat) :
    (floatBin t .fmul fm (.ofFloat t a) (.ofFloat t b) none none n₁ >>= fun p =>
      floatBin t .fadd fm (.ofFloat t acc) p none
        (if fm.contract then some (.ofFloat t a, .ofFloat t b) else none) n₂) =
      .ok (.ofFloat t (dotStep fm.contract acc (a, b) (n₁, n₂))) := by
  rw [floatBin_ofFloat (f := fun x y => Model.mul x y) rfl hc hn hi]
  have e1 : (FBinOp.fadd == FBinOp.fsub) = false := rfl
  cases hcon : fm.contract <;>
    simp [floatBin, FastMath.check, hc, hcon, withFlags, FastMath.poisons, hn, hi, e1, dotStep,
      Val.ofFloat, Val.float?, fbin, Model.ofBits_toBits, bind, Except.bind, pure, Except.pure]

/-- **The fold at never-fusing numbers.** For every format, oracle numbers `o`, word `acc` and
factor pairs `ps`: `dotLoop` with `contract` at the numbers `3 * (n / 3)` of `o` (each `fmul`'s and
`fadd`'s NaN choice kept, remainder 0) is `dotLoop` without `contract` at `o`. -/
theorem dotLoop_neverFuse (o : Nat → Nat × Nat) (acc : Model fmt)
    (ps : List (Model fmt × Model fmt)) :
    dotLoop true (fun j => (3 * ((o j).1 / 3), 3 * ((o j).2 / 3))) acc ps =
      dotLoop false o acc ps := by
  induction ps generalizing o acc with
  | nil => rfl
  | cons ab ps ih =>
    have h : dotStep true acc ab (3 * ((o 0).1 / 3), 3 * ((o 0).2 / 3)) =
        dotStep false acc ab (o 0) := by
      simp [dotStep, contract, Nat.mul_mod_right, Nat.mul_div_cancel_left _ (show 0 < 3 by decide)]
    simp only [dotLoop]
    rw [h]
    exact ih (fun j => o (j + 1)) _

/-- **`GPUProof.dotGrade` is the loop's bound**: for every binary interchange format `fmt`, length
`n`, exact entries `a`, `x` and grades `ga`, `gx`, `dotGrade (.ieee fmt) n a x ga gx` has error
`dotLoopBound fmt n S + P` and magnitude the larger of `S + (dotLoopBound fmt n S + P)` and
`⨆ₖ max (ga k).mag (gx k).mag`, with `S = Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)`,
`P = Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)` and `e = GPUProof.Grade.pos`: `GPUProof.laneGrade` at one
lane of `n` terms and depth `0`. -/
theorem dotGrade_ieee (fmt : FloatFormat) (n : Nat) (a x : Fin n → ℝ)
    (ga gx : Fin n → GPUProof.Grade) :
    GPUProof.dotGrade (.ieee fmt) n a x ga gx =
      ⟨dotLoopBound fmt n (∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos)) +
          ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos),
        max (∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) +
          (dotLoopBound fmt n (∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos)) +
            ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos)))
          (⨆ k, max (ga k).mag (gx k).mag)⟩ := by
  simp only [GPUProof.dotGrade, GPUProof.laneGrade, GPUProof.NumFormat.roundoff,
    GPUProof.NumFormat.underflow, Nat.cast_one, pow_zero, add_zero, one_mul, dotLoopBound]

/-- `dotBound` is at most the error of `GPUProof.dotGrade`, for every binary interchange format
`fmt`, every number of iterations `K` and exact entries `a`, `x` of length `K + 1` whose grades
carry no error: at `T = Σₖ |aₖ| |xₖ|`, `dotBound fmt K T ≤ (dotGrade (.ieee fmt) (K + 1) a x ga
gx).err`. -/
theorem dotBound_le_dotGrade (fmt : FloatFormat) (K : Nat) (a x : Fin (K + 1) → ℝ)
    {ga gx : Fin (K + 1) → GPUProof.Grade} (ha : ∀ k, (ga k).err ≤ 0) (hx : ∀ k, (gx k).err ≤ 0) :
    dotBound fmt K (∑ k, |a k| * |x k|) ≤
      (GPUProof.dotGrade (.ieee fmt) (K + 1) a x ga gx).err := by
  have pa : ∀ k, (ga k).pos = 0 := fun k => max_eq_right (ha k)
  have px : ∀ k, (gx k).pos = 0 := fun k => max_eq_right (hx k)
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hK : (1 + Model.unitRoundoffAt fmt) ^ K ≤ (1 + Model.unitRoundoffAt fmt) ^ (K + 1) :=
    pow_le_pow_right₀ (by linarith) (Nat.le_succ K)
  rw [dotGrade_ieee]
  simp only [pa, px, add_zero, mul_zero, Finset.sum_const_zero, dotBound, dotLoopBound]
  gcongr

/-- The words' absolute products are at most `GPUProof.dotGrade`'s sum, for every format, length
and input grade: when each word `w k`, `v k` is within `(ga k).err`, `(gx k).err` of the exact
`a k`, `x k`, `Σₖ |wₖ vₖ| ≤ Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)` (real values of the words), with
`e = GPUProof.Grade.pos`. -/
theorem sum_abs_mul_le_graded {n : Nat} (w v : Fin n → Model fmt) (a x : Fin n → ℝ)
    (ga gx : Fin n → GPUProof.Grade) (hw : ∀ k, |(w k).toReal - a k| ≤ (ga k).err)
    (hv : ∀ k, |(v k).toReal - x k| ≤ (gx k).err) :
    ∑ k, |(w k).toReal * (v k).toReal| ≤ ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) := by
  refine Finset.sum_le_sum fun k _ => ?_
  rw [abs_mul]
  have ea : |(w k).toReal - a k| ≤ (ga k).pos := (hw k).trans (le_max_left _ _)
  have ex : |(v k).toReal - x k| ≤ (gx k).pos := (hv k).trans (le_max_left _ _)
  have pa : 0 ≤ (ga k).pos := le_max_right _ _
  have h1 := abs_sub_abs_le_abs_sub (w k).toReal (a k)
  have h2 := abs_sub_abs_le_abs_sub (v k).toReal (x k)
  exact mul_le_mul (by linarith) (by linarith) (abs_nonneg _) (add_nonneg (abs_nonneg _) pa)

/-- The words' dot product is within the cross sum of the exact one, for every format, length
and input grade: when each word `w k`, `v k` is within `(ga k).err`, `(gx k).err` of the exact
`a k`, `x k`, `|Σₖ wₖ vₖ - Σₖ aₖ xₖ| ≤ Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)` (real values of the
words), with `e = GPUProof.Grade.pos`. -/
theorem sum_mul_sub_le {n : Nat} (w v : Fin n → Model fmt) (a x : Fin n → ℝ)
    (ga gx : Fin n → GPUProof.Grade) (hw : ∀ k, |(w k).toReal - a k| ≤ (ga k).err)
    (hv : ∀ k, |(v k).toReal - x k| ≤ (gx k).err) :
    |∑ k, (w k).toReal * (v k).toReal - ∑ k, a k * x k| ≤
      ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos) := by
  have ea : ∀ k, |(w k).toReal - a k| ≤ (ga k).pos := fun k => (hw k).trans (le_max_left _ _)
  have ex : ∀ k, |(v k).toReal - x k| ≤ (gx k).pos := fun k => (hv k).trans (le_max_left _ _)
  have pa : ∀ k, 0 ≤ (ga k).pos := fun k => le_max_right _ _
  rw [← Finset.sum_sub_distrib]
  refine (Finset.abs_sum_le_sum_abs _ _).trans (Finset.sum_le_sum fun k _ => ?_)
  have hk : (w k).toReal * (v k).toReal - a k * x k = a k * ((v k).toReal - x k) +
      x k * ((w k).toReal - a k) + ((w k).toReal - a k) * ((v k).toReal - x k) := by ring
  rw [hk]
  refine (abs_add_le _ _).trans (add_le_add ((abs_add_le _ _).trans (add_le_add ?_ ?_)) ?_)
  · rw [abs_mul]; exact mul_le_mul_of_nonneg_left (ex k) (abs_nonneg _)
  · rw [abs_mul]; exact mul_le_mul_of_nonneg_left (ea k) (abs_nonneg _)
  · rw [abs_mul]; exact mul_le_mul (ea k) (ex k) (abs_nonneg _) (pa k)

/-- **Dot loops per lane, added along a tree**, for every format, tree `t` of lane numbers, flag
`c`, oracle sequences `o j` and lists `ls j` of factor pairs: each lane `j`'s word is
`dotLoop c (o j)` from `+0` over `ls j`, and the lanes' words are added by FloatLib's `Model.add`
along `t`. A warp's strided loops followed by its butterfly are this word, at every lane
(MojoProof/Tile/MatVec.lean). -/
def treeDot (t : Numerics.ReductionTree Nat) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ls : Nat → List (Model fmt × Model fmt)) : Model fmt :=
  t.eval (fun x y => Model.add x y) fun j => dotLoop c (o j) (Model.zero fmt false) (ls j)

/-- **Loops per lane**: in every IEEE format, for every flag `c`, oracle sequences `o j`, counts
`W`, `L` and lists `ls j` of at most `L` factor pairs for `j < W`, if each lane's word
`dotLoop c (o j)` from `+0` over `ls j` is finite, the lanes' words sum to within
`((1 + u) ^ L - 1) T + W C` of the exact `Σⱼ Σ_{(a, b) ∈ ls j} a b`, and their absolute values
sum to at most `(1 + u) ^ L T + W C`, with `T = Σⱼ Σ_{(a, b) ∈ ls j} |a b|`,
`C = (2 + u) η ((1 + u) ^ L - 1) / u`, `u = Model.unitRoundoffAt fmt` and
`η = Model.underflowErrorAt fmt` (real values; `dotLoop_error_zero`, `dotLoopBound_mono`). -/
theorem lanes_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    {W L : Nat} (ls : Nat → List (Model fmt × Model fmt)) (hL : ∀ j < W, (ls j).length ≤ L)
    (h : ∀ j < W, (dotLoop c (o j) (Model.zero fmt false) (ls j)).isFinite = true) :
    |∑ j ∈ Finset.range W, (dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal -
        ∑ j ∈ Finset.range W, ((ls j).map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      ((1 + Model.unitRoundoffAt fmt) ^ L - 1) *
          ∑ j ∈ Finset.range W, ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
        W * ((2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          ((1 + Model.unitRoundoffAt fmt) ^ L - 1) / Model.unitRoundoffAt fmt) ∧
    ∑ j ∈ Finset.range W, |(dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal| ≤
      (1 + Model.unitRoundoffAt fmt) ^ L *
          ∑ j ∈ Finset.range W, ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
        W * ((2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          ((1 + Model.unitRoundoffAt fmt) ^ L - 1) / Model.unitRoundoffAt fmt) := by
  have hPQ : ∀ l : List (Model fmt × Model fmt),
      |(l.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
        (l.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := fun l => by
    induction l with
    | nil => simp
    | cons ab l ih =>
      simp only [List.map_cons, List.sum_cons]
      exact (abs_add_le _ _).trans (add_le_add le_rfl ih)
  have hQ : ∀ l : List (Model fmt × Model fmt),
      0 ≤ (l.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := fun l =>
    List.sum_nonneg fun _ h => by obtain ⟨_, _, rfl⟩ := List.mem_map.1 h; exact abs_nonneg _
  have hj : ∀ j ∈ Finset.range W,
      |(dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal -
          ((ls j).map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
        dotLoopBound fmt L ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := fun j hj =>
    (dotLoop_error_zero hfmt c (o j) (ls j) (h j (Finset.mem_range.1 hj))).trans
      (dotLoopBound_mono fmt (hL j (Finset.mem_range.1 hj)) (hQ _) le_rfl)
  have hB : ∑ j ∈ Finset.range W,
      dotLoopBound fmt L ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum =
      ((1 + Model.unitRoundoffAt fmt) ^ L - 1) *
          ∑ j ∈ Finset.range W, ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
        W * ((2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
          ((1 + Model.unitRoundoffAt fmt) ^ L - 1) / Model.unitRoundoffAt fmt) := by
    simp only [dotLoopBound, Finset.sum_add_distrib, ← Finset.mul_sum, Finset.sum_const,
      Finset.card_range, nsmul_eq_mul]
  refine ⟨?_, ?_⟩
  · rw [← Finset.sum_sub_distrib, ← hB]
    exact (Finset.abs_sum_le_sum_abs _ _).trans (Finset.sum_le_sum hj)
  · have hV : ∑ j ∈ Finset.range W, |(dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal| ≤
        ∑ j ∈ Finset.range W, (((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum +
          dotLoopBound fmt L ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
      Finset.sum_le_sum fun j hj' => by
        have := abs_sub_abs_le_abs_sub (dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal
          ((ls j).map fun ab => ab.1.toReal * ab.2.toReal).sum
        linarith [hj j hj', hPQ (ls j)]
    rw [Finset.sum_add_distrib, hB] at hV
    linarith

/-- **Loops per lane added along a tree are within `GPUProof.laneGrade`**: for every IEEE format,
flag `c`, oracle sequences `o j`, lane count `W`, lane length `L`, length `n`, tree `t` whose
leaves are the lanes `0, …, W - 1`, each once, lists `ls j` of at most `L` factor pairs that
together are the pairs `(w k, v k)`, `k < n` (`hs`: every sum over the lanes' pairs is the sum
over `k`), and input grades: when each word `w k`, `v k` is within `(ga k).err`, `(gx k).err` of
the exact `a k`, `x k`, a finite `treeDot t c o ls` is within the error of
`laneGrade (.ieee fmt) W t.depth L n a x ga gx` of `Σₖ aₖ xₖ` (`Float.sum_error`, `lanes_error`,
`sum_abs_mul_le_graded`, `sum_mul_sub_le`). -/
theorem treeDot_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    {W L n : Nat} (t : Numerics.ReductionTree Nat) (ht : t.leaves.Perm (List.range W))
    (ls : Nat → List (Model fmt × Model fmt)) (hL : ∀ j < W, (ls j).length ≤ L)
    (w v : Fin n → Model fmt)
    (hs : ∀ g : Model fmt × Model fmt → ℝ,
      ∑ j ∈ Finset.range W, ((ls j).map g).sum = ∑ k, g (w k, v k))
    (a x : Fin n → ℝ) (ga gx : Fin n → GPUProof.Grade)
    (hw : ∀ k, |(w k).toReal - a k| ≤ (ga k).err) (hv : ∀ k, |(v k).toReal - x k| ≤ (gx k).err)
    (h : (treeDot t c o ls).isFinite = true) :
    |(treeDot t c o ls).toReal - ∑ k, a k * x k| ≤
      (GPUProof.laneGrade (.ieee fmt) W t.depth L n a x ga gx).err := by
  have hr : ∀ f : Nat → ℝ, ((List.range W).map f).sum = ∑ j ∈ Finset.range W, f j := fun f => by
    rw [Finset.sum_eq_multiset_sum, Finset.range_val, Multiset.range, Multiset.map_coe,
      Multiset.sum_coe]
  obtain ⟨hf, e⟩ := Float.sum_error hfmt t
    (fun j => dotLoop c (o j) (Model.zero fmt false) (ls j)) ht h
  rw [hr, hr] at e
  obtain ⟨e1, e2⟩ := lanes_error hfmt c o ls hL fun j hj => hf j (List.mem_range.2 hj)
  have hsP : ∑ j ∈ Finset.range W, ((ls j).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      ∑ k, (w k).toReal * (v k).toReal := hs _
  have hsQ : ∑ j ∈ Finset.range W, ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum =
      ∑ k, |(w k).toReal * (v k).toReal| := hs _
  rw [hsP, hsQ] at e1
  rw [hsQ] at e2
  have hT := sum_abs_mul_le_graded w v a x ga gx hw hv
  have hD := sum_mul_sub_le w v a x ga gx hw hv
  have hu := Model.unitRoundoffAt_pos fmt
  have hq1 : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ t.depth := one_le_pow₀ (by linarith)
  have hqL : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ L := one_le_pow₀ (by linarith)
  have hp : (1 + Model.unitRoundoffAt fmt) ^ (L + t.depth) =
      (1 + Model.unitRoundoffAt fmt) ^ L * (1 + Model.unitRoundoffAt fmt) ^ t.depth :=
    pow_add _ _ _
  have hγ : 0 ≤ (1 + Model.unitRoundoffAt fmt) ^ L * (1 + Model.unitRoundoffAt fmt) ^ t.depth - 1 :=
    by nlinarith
  have m1 := mul_le_mul_of_nonneg_left e2 (sub_nonneg.2 hq1)
  have m2 := mul_le_mul_of_nonneg_left hT hγ
  simp only [GPUProof.laneGrade, GPUProof.NumFormat.roundoff, GPUProof.NumFormat.underflow]
  rw [hp]
  unfold treeDot
  linarith [abs_sub_le (t.eval (fun x y => Model.add x y)
      fun j => dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal
    (∑ j ∈ Finset.range W, (dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal)
    (∑ k, a k * x k),
    abs_sub_le (∑ j ∈ Finset.range W, (dotLoop c (o j) (Model.zero fmt false) (ls j)).toReal)
      (∑ k, (w k).toReal * (v k).toReal) (∑ k, a k * x k)]

/-- **Loops per lane added along a tree meet `GPUProof.laneGrade`**: for every IEEE format, flag
`c`, oracle sequences `o j` (each iteration fused or not), lane count `W`, lane length `L`,
length `n`, tree `t` whose leaves are the lanes `0, …, W - 1`, each once, lists `ls j` of at most
`L` factor pairs that together are the pairs `(w k, v k)` (`hs`), and input grades `ga`, `gx`:
when each word `w k`, `v k` is `GPUProof.Approx` at `ga k`, `gx k` of the exact `a k`, `x k`,
`treeDot t c o ls` is `GPUProof.Approx` at `laneGrade (.ieee fmt) W t.depth L n a x ga gx` of
`Σₖ aₖ xₖ`. When the grade's magnitude is at most the largest finite value, so is each input
grade's (`GPUProof.laneGrade_mag`): each word is finite and within its grade's error, so each
lane's pairs are finite (by `hs` at the count of pairs with a word that is not finite), each
lane's loop is finite (`isFinite_dotLoop`), the tree's sum is finite (`Float.isFinite_eval`), and
it is within the grade's error (`treeDot_error`). -/
theorem treeDot_approx (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    {W L n : Nat} (t : Numerics.ReductionTree Nat) (ht : t.leaves.Perm (List.range W))
    (ls : Nat → List (Model fmt × Model fmt)) (hL : ∀ j < W, (ls j).length ≤ L)
    (w v : Fin n → Model fmt)
    (hs : ∀ g : Model fmt × Model fmt → ℝ,
      ∑ j ∈ Finset.range W, ((ls j).map g).sum = ∑ k, g (w k, v k))
    (a x : Fin n → ℝ) (ga gx : Fin n → GPUProof.Grade)
    (hw₀ : ∀ k, GPUProof.Approx .real (ga k) (.ieee fmt) (w k).toReal? (a k))
    (hv₀ : ∀ k, GPUProof.Approx .real (gx k) (.ieee fmt) (v k).toReal? (x k)) :
    GPUProof.Approx .real (GPUProof.laneGrade (.ieee fmt) W t.depth L n a x ga gx) (.ieee fmt)
      (treeDot t c o ls).toReal? (∑ k, a k * x k) := by
  rw [GPUProof.Approx.model]
  intro hmag
  have hw : ∀ k, (w k).isFinite = true ∧ |(w k).toReal - a k| ≤ (ga k).err := fun k =>
    (GPUProof.Approx.model _ _ _).1 (hw₀ k)
      ((GPUProof.laneGrade_mag _ _ _ _ _ a x ga gx k).1.trans hmag)
  have hv : ∀ k, (v k).isFinite = true ∧ |(v k).toReal - x k| ≤ (gx k).err := fun k =>
    (GPUProof.Approx.model _ _ _).1 (hv₀ k)
      ((GPUProof.laneGrade_mag _ _ _ _ _ a x ga gx k).2.trans hmag)
  have hp : ∀ j < W, ∀ ab ∈ ls j, ab.1.isFinite = true ∧ ab.2.isFinite = true := by
    intro j hj ab hab
    let g : Model fmt × Model fmt → ℝ := fun ab =>
      if ab.1.isFinite = true ∧ ab.2.isFinite = true then 0 else 1
    have hg : ∀ l : List (Model fmt × Model fmt), ∀ y ∈ l.map g, 0 ≤ y := fun l y hy => by
      obtain ⟨ab, _, rfl⟩ := List.mem_map.1 hy
      simp only [g]
      split <;> norm_num
    have h0 : ∑ j ∈ Finset.range W, ((ls j).map g).sum = 0 := by
      rw [hs g]
      exact Finset.sum_eq_zero fun k _ => by simp [g, (hw k).1, (hv k).1]
    have h1 : g ab ≤ ((ls j).map g).sum := List.single_le_sum (hg _) _ (List.mem_map_of_mem hab)
    have h2 : ((ls j).map g).sum ≤ ∑ j ∈ Finset.range W, ((ls j).map g).sum :=
      Finset.single_le_sum (f := fun j => ((ls j).map g).sum)
        (fun i _ => List.sum_nonneg (hg _)) (Finset.mem_range.2 hj)
    by_contra hn
    have h3 : g ab = 1 := ite_eq_right hn
    linarith
  have hr : ∀ f : Nat → ℝ, ((List.range W).map f).sum = ∑ j ∈ Finset.range W, f j := fun f => by
    rw [Finset.sum_eq_multiset_sum, Finset.range_val, Multiset.range, Multiset.map_coe,
      Multiset.sum_coe]
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hq1 : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ t.depth := one_le_pow₀ (by linarith)
  have hqL : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ L := one_le_pow₀ (by linarith)
  have hC : 0 ≤ (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
      ((1 + Model.unitRoundoffAt fmt) ^ L - 1) / Model.unitRoundoffAt fmt :=
    div_nonneg (mul_nonneg (mul_nonneg (by linarith) hη.le) (by linarith)) hu.le
  have hQ : ∀ j, 0 ≤ ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := fun j =>
    List.sum_nonneg fun _ h => by obtain ⟨_, _, rfl⟩ := List.mem_map.1 h; exact abs_nonneg _
  have hsQ : ∑ j ∈ Finset.range W, ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum =
      ∑ k, |(w k).toReal * (v k).toReal| := hs _
  have hT := sum_abs_mul_le_graded w v a x ga gx (fun k => (hw k).2) (fun k => (hv k).2)
  have pa : ∀ k, 0 ≤ (ga k).pos := fun k => le_max_right _ _
  have px : ∀ k, 0 ≤ (gx k).pos := fun k => le_max_right _ _
  have hP : 0 ≤ ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos) :=
    Finset.sum_nonneg fun k _ => add_nonneg (add_nonneg (mul_nonneg (abs_nonneg _) (px k))
      (mul_nonneg (abs_nonneg _) (pa k))) (mul_nonneg (pa k) (px k))
  have hS : 0 ≤ ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) :=
    (Finset.sum_nonneg fun k _ => abs_nonneg _).trans hT
  have hγ : 0 ≤ (1 + Model.unitRoundoffAt fmt) ^ L * (1 + Model.unitRoundoffAt fmt) ^ t.depth - 1 :=
    by nlinarith
  simp only [GPUProof.laneGrade, GPUProof.NumFormat.roundoff, GPUProof.NumFormat.underflow,
    pow_add] at hmag
  have hm := (le_max_left _ _).trans hmag
  have hlane : ∀ j < W, (dotLoop c (o j) (Model.zero fmt false) (ls j)).isFinite = true := by
    intro j hj
    have hW : (1 : ℝ) ≤ W := by exact_mod_cast Nat.one_le_of_lt hj
    have h1 : ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum ≤
        ∑ i ∈ Finset.range W, ((ls i).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
      Finset.single_le_sum (f := fun i => ((ls i).map fun ab => |ab.1.toReal * ab.2.toReal|).sum)
        (fun i _ => hQ i) (Finset.mem_range.2 hj)
    have hQj : ((ls j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum ≤
        ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) := by
      linarith
    have hB := dotLoopBound_mono fmt (hL j hj) (hQ j) hQj
    have m1 := mul_le_mul_of_nonneg_right (one_le_mul_of_one_le_of_one_le hW hq1) hC
    have m2 := mul_le_mul_of_nonneg_right
      (le_mul_of_one_le_right (by linarith : (0 : ℝ) ≤ (1 + Model.unitRoundoffAt fmt) ^ L) hq1)
      hS
    refine isFinite_dotLoop hfmt c (o j) (ls j) (hp j hj) ?_
    unfold dotLoopBound at hB ⊢
    linarith
  obtain ⟨_, e2⟩ := lanes_error hfmt c o ls hL hlane
  rw [hsQ] at e2
  have m1 := mul_le_mul_of_nonneg_left e2
    (by linarith : (0 : ℝ) ≤ (1 + Model.unitRoundoffAt fmt) ^ t.depth)
  have m2 := mul_le_mul_of_nonneg_left hT (by linarith :
    (0 : ℝ) ≤ (1 + Model.unitRoundoffAt fmt) ^ L * (1 + Model.unitRoundoffAt fmt) ^ t.depth)
  have hf : (treeDot t c o ls).isFinite = true := by
    refine (Float.isFinite_eval hfmt t (fun j => dotLoop c (o j) (Model.zero fmt false) (ls j))
      (fun j hj => hlane j (List.mem_range.1 (ht.subset hj)))
      ?_).1
    rw [(ht.map _).sum_eq, hr]
    linarith
  exact ⟨hf, treeDot_error hfmt c o t ht ls hL w v hs a x ga gx (fun k => (hw k).2)
    (fun k => (hv k).2) hf⟩

/-- **The loop at inputs with error is within `GPUProof.dotGrade`**: for every binary interchange
format, flag, oracle and length `n`, when each word `w k`, `v k` is within `(ga k).err`,
`(gx k).err` of the exact `a k`, `x k`, a finite loop from `+0` over the pairs is within the error
of `dotGrade (.ieee fmt) n a x ga gx` of `Σₖ aₖ xₖ`, that is `dotLoopBound fmt n S + P` with
`S = Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)`, `P = Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)` and
`e = GPUProof.Grade.pos` (`dotGrade_ieee`): `treeDot_error` at one lane, the tree of one leaf. -/
theorem dotLoop_error_graded (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat) {n : Nat}
    (w v : Fin n → Model fmt) (a x : Fin n → ℝ) (ga gx : Fin n → GPUProof.Grade)
    (hw : ∀ k, |(w k).toReal - a k| ≤ (ga k).err) (hv : ∀ k, |(v k).toReal - x k| ≤ (gx k).err)
    (h : (dotLoop c o (Model.zero fmt false) (List.ofFn fun k => (w k, v k))).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) (List.ofFn fun k => (w k, v k))).toReal -
        ∑ k, a k * x k| ≤ (GPUProof.dotGrade (.ieee fmt) n a x ga gx).err :=
  treeDot_error (W := 1) (L := n) hfmt c (fun _ => o) (.leaf 0) (.refl _)
    (fun _ => List.ofFn fun k => (w k, v k)) (fun _ _ => (List.length_ofFn ..).le) w v
    (fun _ => by simp [List.map_ofFn, List.sum_ofFn, Function.comp_def]) a x ga gx hw hv h

/-- **dotLoop's word meets `GPUProof.dotGrade`**: for every binary interchange format, flag `c`,
oracle sequence `o` (each iteration fused or not), length `n` and input grades `ga`, `gx`, when
each word `w k`, `v k` is `GPUProof.Approx` at `ga k`, `gx k` of the exact `a k`, `x k`, the word
of `dotLoop` from `+0` over the pairs is `GPUProof.Approx` at `dotGrade (.ieee fmt) n a x ga gx`
of `Σₖ aₖ xₖ`: `treeDot_approx` at one lane, the tree of one leaf. -/
theorem dotLoop_approx (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat) {n : Nat}
    (w v : Fin n → Model fmt) (a x : Fin n → ℝ) (ga gx : Fin n → GPUProof.Grade)
    (hw₀ : ∀ k, GPUProof.Approx .real (ga k) (.ieee fmt) (w k).toReal? (a k))
    (hv₀ : ∀ k, GPUProof.Approx .real (gx k) (.ieee fmt) (v k).toReal? (x k)) :
    GPUProof.Approx .real (GPUProof.dotGrade (.ieee fmt) n a x ga gx) (.ieee fmt)
      (dotLoop c o (Model.zero fmt false) (List.ofFn fun k => (w k, v k))).toReal?
      (∑ k, a k * x k) :=
  treeDot_approx (W := 1) (L := n) hfmt c (fun _ => o) (.leaf 0) (.refl _)
    (fun _ => List.ofFn fun k => (w k, v k)) (fun _ _ => (List.length_ofFn ..).le) w v
    (fun _ => by simp [List.map_ofFn, List.sum_ofFn, Function.comp_def]) a x ga gx hw₀ hv₀

end MojoProof.Sem
