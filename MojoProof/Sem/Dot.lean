import MojoProof.Sem.FloatRel
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
* `dotLoop_error`: for every IEEE format, every `c`, list and oracle sequence, a finite result of
  `dotLoop` from `+0` is within `dotBound fmt K T` of the exact `Σ aₖ bₖ`, with `K` the length and
  `T = Σ |aₖ bₖ|`; each iteration may be fused or not.
* `floatBin_dotStep`: for every float type and flags without `nnan`, `ninf`, `nsz`, `reassoc`,
  `arcp`, `afn`, `floatBin`'s `fmul` and then `fadd` with the factors `exec` records is `dotStep`.

With the lemmas they use: `NaNEq.symm`, `NaNEq.trans`, `NaNEq.eq_isNaN`, `nanEq_deliver`,
`cast_self_nanEq`, `contract_unfused`, `dotSum_eq`, `deliver_finite`, `dotStep_error`,
`isFinite_of_dotLoop`, `dotBound_step`, `dotStep_bound`, `dotLoop_nanEq_foldl` (for every map of
the factors that keeps each non-NaN word, so MojoProof/Sem/Matmul.lean uses it for TorchLean's
fold) and `dotLoop_error_of`.
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

/-- `NaNEq` is symmetric, in every format. -/
theorem NaNEq.symm {x y : Model fmt} (h : NaNEq x y) : NaNEq y x := by
  rcases h with rfl | ⟨hx, hy⟩
  · exact .inl rfl
  · exact .inr ⟨hy, hx⟩

/-- `NaNEq` is transitive, in every format: a word related to a NaN is a NaN. -/
theorem NaNEq.trans {x y z : Model fmt} (h₁ : NaNEq x y) (h₂ : NaNEq y z) : NaNEq x z := by
  rcases h₁ with rfl | ⟨hx, hy⟩
  · exact h₂
  · rcases h₂ with rfl | ⟨-, hz⟩
    · exact .inr ⟨hx, hy⟩
    · exact .inr ⟨hx, hz⟩

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

/-- **One iteration of the bound**: in an IEEE format, for every flag `c`, words `acc`, `a`, `b`,
oracle numbers `n`, count `m` and reals `E`, `S` with `|E| ≤ S`, if `acc` is within
`dotBound fmt m S` of `E` and `dotStep c acc (a, b) n` is finite, then that result is within
`dotBound fmt (m + 1) (S + |a b|)` of `E + a b` (real values). -/
theorem dotStep_bound (hfmt : fmt.isIEEE = true) {c : Bool} {acc a b : Model fmt} {n : Nat × Nat}
    {m : Nat} {E S : ℝ} (hE : |E| ≤ S) (hacc : |acc.toReal - E| ≤ dotBound fmt m S)
    (h : (dotStep c acc (a, b) n).isFinite = true) :
    |(dotStep c acc (a, b) n).toReal - (E + a.toReal * b.toReal)| ≤
      dotBound fmt (m + 1) (S + |a.toReal * b.toReal|) := by
  obtain ⟨-, hr⟩ := dotStep_error hfmt c acc a b n h
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have hq : 1 ≤ (1 + Model.unitRoundoffAt fmt) ^ m := one_le_pow₀ (by linarith)
  have hy : |(deliver (Model.mul a b) (n.1 / 3)).toReal| ≤
      (1 + Model.unitRoundoffAt fmt) * |a.toReal * b.toReal| + Model.underflowErrorAt fmt := by
    cases hpf : (deliver (Model.mul a b) (n.1 / 3)).isFinite
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
  have hβ' : (1 + Model.unitRoundoffAt fmt) * ((2 + Model.unitRoundoffAt fmt) *
      Model.underflowErrorAt fmt * ((1 + Model.unitRoundoffAt fmt) ^ m - 1) /
        Model.unitRoundoffAt fmt) + (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt =
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt *
        ((1 + Model.unitRoundoffAt fmt) ^ m * (1 + Model.unitRoundoffAt fmt) - 1) /
          Model.unitRoundoffAt fmt := by
    field_simp
    ring
  unfold dotBound at hacc ⊢
  simp only [pow_succ] at hacc ⊢
  exact dotBound_step hu hη hq hβ' hE hacc hy hr (Model.halfUlpAt_le fmt _)
    (Model.halfUlpAt_le fmt _) (Model.halfUlpAt_le fmt _)

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
        dotBound fmt (m + ps.length) (S + (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum)
  | [], _, acc, m, E, S, _, h, _ => by simpa [dotLoop] using h
  | (a, b) :: ps, o, acc, m, E, S, hE, h, hf => by
    have hf' : (dotLoop c (fun j => o (j + 1)) (dotStep c acc (a, b) (o 0)) ps).isFinite =
        true := hf
    have hs := dotStep_bound hfmt hE h (isFinite_of_dotLoop hfmt c ps _ _ hf')
    have hE' : |E + a.toReal * b.toReal| ≤ S + |a.toReal * b.toReal| := by
      have := abs_add_le E (a.toReal * b.toReal)
      linarith
    have ih := dotLoop_error_of hfmt c ps (fun j => o (j + 1)) _ (m + 1) _ _ hE' hs hf'
    simp only [dotLoop, List.map_cons, List.sum_cons, List.length_cons]
    rw [show m + (ps.length + 1) = m + 1 + ps.length by omega, ← add_assoc, ← add_assoc]
    exact ih

/-- **The roundoff of the contracted dot-product loop**: in every IEEE format, for every
`contract` flag `c`, oracle sequence `o` (each iteration fused or not, as `o` chooses) and list
of factor pairs `ps` of length `K`, if the loop's result `r` from `+0` is finite, then
`|r - Σ aₖ bₖ| ≤ dotBound fmt K T`, that is
`((1 + u) ^ (K + 1) - 1) T + (2 + u) η ((1 + u) ^ K - 1) / u` with `T = Σ |aₖ bₖ|`, the
real values of the words, `u` the unit roundoff and `η` the underflow allowance. Nothing is
claimed when the result is infinite or a NaN. -/
theorem dotLoop_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt))
    (h : (dotLoop c o (Model.zero fmt false) ps).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) ps).toReal -
        (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      dotBound fmt ps.length (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have := dotLoop_error_of hfmt c ps o (Model.zero fmt false) 0 0 0 (by simp)
    (by simp [dotBound]) h
  simpa using this

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

end MojoProof.Sem
