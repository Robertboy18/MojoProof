import MojoProof.Sem.Dot
import MojoProofTest.FloatRel

/-!
# Dot-product grades at instances

MojoProof/Sem/Dot.lean proves, for every format, length and input grade, that the word of
`dotLoop` from `+0` is `GPUProof.Approx` at `GPUProof.dotGrade` (`dotLoop_approx`). Here:

* `loop_exact`: `dotLoop_error_graded` at grades with no error is `dotLoop_error_zero`'s bound
  `dotLoopBound`, for every IEEE format and length.
* `one_pair`: `dotBound_le_dotGrade` at one pair, for every format.
* `grade_one`, `grade_two`: `GPUProof.dotGrade`'s error at lengths one and two at grades with no
  error, for every format: `u |a| |x| + (2 + u) η`, the product's one rounding, and
  `(2 u + u ^ 2) (|a₀| |x₀| + |a₁| |x₁|) + (2 + u) ^ 2 η`.
* `approx_one`, `approx_two`: the instances of `dotLoop_approx` on binary32, for every flag and
  oracle sequence: at length one on the subnormal `3 · 2 ^ -149` (`subW`) and `1 / 2` (`halfW`)
  with no input error; at length two on the words of `≈ 1 / 3` and `1` against `3` and `-1`, of
  the exact `1 / 3`, `1`, `3`, `-1`, the first word within its grade's error `2 ^ -25`
  (`third_near`). The words are `GPUProof.Approx` at their grades by `GPUProof.Approx.model`.
* `mutant_one`: the grade one ulp tighter fails. On the pair of `approx_one`, unfused, the exact
  product `1.5 · 2 ^ -149` is a tie between subnormals, which rounds to the even `2 · 2 ^ -149`,
  an error of `η = 2 ^ -150` (`sub_err`). `dotGrade`'s error less one ulp of that result,
  `2 ^ -149`, is `4 u η < η`, so `GPUProof.Approx` at that grade is false.
* `sum_rounded`, `sum_within`: each sum is rounded. On binary32, unfused, from `+0`, the loop over
  `(1, 1)`, `(2 ^ -12, 2 ^ -12)`, `(2 ^ -12, 2 ^ -12)` (`sumPairs`), whose products `1`,
  `2 ^ -24`, `2 ^ -24` are exact, gives `1`: each sum `1 + 2 ^ -24` is a tie that rounds to the
  even `1`. Its error `2 ^ -23` is within `dotLoopBound .binary32 3`.
* `noSum_fails`: the mutant. The bound of a recurrence without the rounding of the accumulated
  sum (`noSumBound`) is below `2 ^ -23` on those products, so it is not a bound of the loop.
-/

namespace MojoProofTest.DotGrade

open FloatLib.Floats.Formats.BinaryInterchange MojoProof.Sem
open MojoProofTest.FloatRel (f32)

/-- The grade with no error and no magnitude. -/
def g0 : GPUProof.Grade := ⟨0, 0⟩

/-- The contracted loop over words `w`, `v` of every IEEE format and length is within
`dotLoopBound` of `Σₖ wₖ vₖ` at the sum `Σₖ |wₖ| |vₖ|`: `dotLoop_error_graded` at the grade
`g0`. -/
theorem loop_exact {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (c : Bool)
    (o : Nat → Nat × Nat) {n : Nat} (w v : Fin n → Model fmt)
    (h : (dotLoop c o (Model.zero fmt false) (List.ofFn fun k => (w k, v k))).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) (List.ofFn fun k => (w k, v k))).toReal -
        ∑ k, (w k).toReal * (v k).toReal| ≤
      dotLoopBound fmt n (∑ k, |(w k).toReal| * |(v k).toReal|) := by
  have e := dotLoop_error_graded hfmt c o w v (fun k => (w k).toReal) (fun k => (v k).toReal)
    (fun _ => g0) (fun _ => g0) (fun _ => by simp [g0]) (fun _ => by simp [g0]) h
  simpa [dotGrade_ieee, g0, GPUProof.Grade.pos] using e

/-- At one pair of exact reals `a`, `x` and every binary interchange format, `dotBound` after no
iteration at `|a| |x|` is at most `GPUProof.dotGrade`'s error at length one and the grade `g0`. -/
theorem one_pair (fmt : FloatFormat) (a x : ℝ) :
    dotBound fmt 0 (|a| * |x|) ≤
      (GPUProof.dotGrade (.ieee fmt) 1 (fun _ => a) (fun _ => x) (fun _ => g0)
        (fun _ => g0)).err := by
  simpa using dotBound_le_dotGrade fmt 0 (fun _ => a) (fun _ => x) (ga := fun _ => g0)
    (gx := fun _ => g0) (fun _ => le_rfl) (fun _ => le_rfl)

/-- `GPUProof.dotGrade`'s error at length one and the grade `g0`, for every binary interchange
format and reals `a`, `x`: `u |a| |x| + (2 + u) η`, one rounding of the product. -/
theorem grade_one (fmt : FloatFormat) (a x : ℝ) :
    (GPUProof.dotGrade (.ieee fmt) 1 (fun _ => a) (fun _ => x) (fun _ => g0) (fun _ => g0)).err =
      Model.unitRoundoffAt fmt * (|a| * |x|) +
        (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt := by
  have hu := (Model.unitRoundoffAt_pos fmt).ne'
  simp only [dotGrade_ieee, dotLoopBound, g0, GPUProof.Grade.pos, max_self, add_zero, mul_zero,
    Finset.univ_unique, Finset.sum_singleton, Finset.sum_const_zero, pow_one]
  field_simp
  ring

/-- `GPUProof.dotGrade`'s error at length two and the grade `g0`, for every binary interchange
format and reals `a`, `x`: `(2 u + u ^ 2) (|a₀| |x₀| + |a₁| |x₁|) + (2 + u) ^ 2 η`. -/
theorem grade_two (fmt : FloatFormat) (a x : Fin 2 → ℝ) :
    (GPUProof.dotGrade (.ieee fmt) 2 a x (fun _ => g0) (fun _ => g0)).err =
      (2 * Model.unitRoundoffAt fmt + Model.unitRoundoffAt fmt ^ 2) *
          (|a 0| * |x 0| + |a 1| * |x 1|) +
        (2 + Model.unitRoundoffAt fmt) ^ 2 * Model.underflowErrorAt fmt := by
  have hu := (Model.unitRoundoffAt_pos fmt).ne'
  simp only [dotGrade_ieee, dotLoopBound, g0, GPUProof.Grade.pos, max_self, add_zero, mul_zero,
    Fin.sum_univ_two, Finset.sum_const_zero]
  field_simp
  ring

/-- The binary32 subnormal `3 · 2 ^ -149` (bits `0x00000003`). -/
def subW : Model .binary32 := f32 0x00000003

/-- The binary32 word of `1 / 2` (bits `0x3f000000`). -/
def halfW : Model .binary32 := f32 0x3f000000

/-- The real values of `subW` and `halfW`, `3 / 2 ^ 149` and `1 / 2`, both finite. -/
theorem sub_vals : subW.isFinite = true ∧ halfW.isFinite = true ∧
    subW.toReal = 3 / 2 ^ 149 ∧ halfW.toReal = 1 / 2 := by
  have h : subW.toRat? = some (3 / 2 ^ 149) ∧ halfW.toRat? = some (1 / 2) := by decide +kernel
  refine ⟨Model.Algebraic.isFinite_of_toRat?_eq_some h.1,
    Model.Algebraic.isFinite_of_toRat?_eq_some h.2, ?_, ?_⟩
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h.1]; push_cast; ring
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h.2]; push_cast; ring

/-- **The instance of `dotLoop_approx` at length one**: on binary32, for every flag and oracle
sequence, the loop over the one pair `(subW, halfW)` is `GPUProof.Approx` at `GPUProof.dotGrade`
of their values with the grade `g0`. -/
theorem approx_one (c : Bool) (o : Nat → Nat × Nat) :
    GPUProof.Approx .real (GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149)
        (fun _ => 1 / 2) (fun _ => g0) (fun _ => g0)) (.ieee .binary32)
      (dotLoop c o (Model.zero .binary32 false) (List.ofFn fun _ : Fin 1 => (subW, halfW))).toReal?
      (∑ _ : Fin 1, 3 / 2 ^ 149 * (1 / 2)) :=
  dotLoop_approx rfl c o (fun _ => subW) (fun _ => halfW) _ _ _ _
    (fun _ => (GPUProof.Approx.model _ _ _).2 fun _ =>
      ⟨sub_vals.1, by simp [sub_vals.2.2.1, g0]⟩)
    (fun _ => (GPUProof.Approx.model _ _ _).2 fun _ =>
      ⟨sub_vals.2.1, by simp [sub_vals.2.2.2, g0]⟩)

/-- The binary32 words of `approx_two`: `≈ 1 / 3` (bits `0x3eaaaaab`, `11184811 / 2 ^ 25`) and `1`
on the left, `3` and `-1` on the right. -/
def wTwo : Fin 2 → Model .binary32 := ![f32 0x3eaaaaab, f32 0x3f800000]

/-- The right words of `approx_two`, `3` and `-1`. -/
def vTwo : Fin 2 → Model .binary32 := ![f32 0x40400000, f32 0xbf800000]

/-- The grades of `approx_two`'s left entries: error `2 ^ -25` on `1 / 3`, none on `1`. -/
noncomputable def gaTwo : Fin 2 → GPUProof.Grade := ![⟨1 / 2 ^ 25, 0⟩, g0]

/-- The words of `approx_two` are finite and within their grades of `1 / 3`, `1`, `3`, `-1`; the
word of `1 / 3` is `1 / (3 · 2 ^ 25)` off it, within `2 ^ -25`. -/
theorem third_near :
    (∀ k, (wTwo k).isFinite = true ∧ |(wTwo k).toReal - ![1 / 3, 1] k| ≤ (gaTwo k).err) ∧
      ∀ k, (vTwo k).isFinite = true ∧
        |(vTwo k).toReal - ![3, -1] k| ≤ (g0 : GPUProof.Grade).err := by
  have h : (f32 0x3eaaaaab).toRat? = some (11184811 / 2 ^ 25) ∧
      (f32 0x3f800000).toRat? = some 1 ∧ (f32 0x40400000).toRat? = some 3 ∧
      (f32 0xbf800000).toRat? = some (-1) := by
    decide +kernel
  obtain ⟨h1, h2, h3, h4⟩ := h
  refine ⟨fun k => ?_, fun k => ?_⟩ <;> fin_cases k <;>
    simp only [wTwo, vTwo, gaTwo, g0, Fin.zero_eta, Fin.mk_one, Matrix.cons_val_zero,
      Matrix.cons_val_one] <;>
    refine ⟨Model.Algebraic.isFinite_of_toRat?_eq_some (by assumption), ?_⟩
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h1]; norm_num [abs_le]
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h2]; norm_num
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h3]; norm_num
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h4]; norm_num

/-- **The instance of `dotLoop_approx` at length two**, with an input error: on binary32, for
every flag and oracle sequence, the loop over the pairs of `wTwo` and `vTwo` is
`GPUProof.Approx` at `GPUProof.dotGrade` of the exact `1 / 3`, `1` and `3`, `-1`, with the grades
`gaTwo` and `g0`, of the exact dot product `1 / 3 · 3 + 1 · (-1)`. -/
theorem approx_two (c : Bool) (o : Nat → Nat × Nat) :
    GPUProof.Approx .real (GPUProof.dotGrade (.ieee .binary32) 2 ![1 / 3, 1] ![3, -1] gaTwo
        (fun _ => g0)) (.ieee .binary32)
      (dotLoop c o (Model.zero .binary32 false) (List.ofFn fun k => (wTwo k, vTwo k))).toReal?
      (∑ k, ![(1 : ℝ) / 3, 1] k * ![(3 : ℝ), -1] k) :=
  dotLoop_approx rfl c o wTwo vTwo _ _ _ _
    (fun k => (GPUProof.Approx.model _ _ _).2 fun _ => third_near.1 k)
    (fun k => (GPUProof.Approx.model _ _ _).2 fun _ => third_near.2 k)

/-- The unfused loop over `(subW, halfW)` gives `2 · 2 ^ -149`, `2 ^ -150 = η` away from the exact
product `1.5 · 2 ^ -149`: the tie rounds to the even subnormal. -/
theorem sub_err :
    (dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
        (List.ofFn fun _ : Fin 1 => (subW, halfW))).toReal = 2 / 2 ^ 149 ∧
      Model.underflowErrorAt .binary32 = 1 / 2 ^ 150 := by
  have h : (dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
      (List.ofFn fun _ : Fin 1 => (subW, halfW))).toRat? = some (2 / 2 ^ 149) := by
    decide +kernel
  refine ⟨?_, ?_⟩
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h]; push_cast; ring
  · norm_num [Model.underflowErrorAt_eq, FloatFormat.minSubnormalExponent,
      FloatFormat.minNormalExponent, FloatFormat.Encoding.defaultBias, FloatFormat.ieeeBias,
      show FloatFormat.binary32.fracWidth = 23 by decide,
      show FloatFormat.binary32.exponentBias = 127 by decide]

/-- `u` and `η` of binary32: `2 ^ -24` and `2 ^ -150`. -/
theorem u_eta : Model.unitRoundoffAt .binary32 = 1 / 2 ^ 24 ∧
    Model.underflowErrorAt .binary32 = 1 / 2 ^ 150 :=
  ⟨by norm_num [Model.unitRoundoffAt_eq, show FloatFormat.binary32.fracWidth = 23 by decide],
    sub_err.2⟩

/-- **The mutant: one ulp tighter fails.** On binary32, the grade with `GPUProof.dotGrade`'s
magnitude at the pair of `approx_one` and its error less `2 ^ -149` (one ulp of the loop's result,
the subnormal spacing) is not met by the unfused loop: `GPUProof.Approx` at it is false, since
the error `η` (`sub_err`) exceeds `4 u η`. -/
theorem mutant_one :
    ¬ GPUProof.Approx .real
      ⟨(GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
          (fun _ => g0) (fun _ => g0)).err - 1 / 2 ^ 149,
        (GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
          (fun _ => g0) (fun _ => g0)).mag⟩ (.ieee .binary32)
      (dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
        (List.ofFn fun _ : Fin 1 => (subW, halfW))).toReal?
      (∑ _ : Fin 1, 3 / 2 ^ 149 * (1 / 2)) := by
  rw [GPUProof.Approx.model]
  intro h
  have hM := Model.one_le_toReal_posMaxFinite .binary32
  obtain ⟨hu, -⟩ := u_eta
  obtain ⟨hr, hη⟩ := sub_err
  have e := grade_one .binary32 (3 / 2 ^ 149) (1 / 2)
  have hm : (GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
      (fun _ => g0) (fun _ => g0)).mag =
      max (3 / 2 ^ 150 + (GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149)
        (fun _ => 1 / 2) (fun _ => g0) (fun _ => g0)).err) 0 := by
    rw [dotGrade_ieee]
    simp only [g0, GPUProof.Grade.pos, max_self, add_zero, Finset.univ_unique,
      Finset.sum_singleton, ciSup_const]
    norm_num [abs_of_pos]
  rw [hm, e, hu, hη, hr] at h
  have h2 := (h (max_le (by norm_num [abs_of_pos]; linarith) (by linarith))).2
  norm_num [abs_of_pos, Fin.sum_univ_one] at h2

/-! ## Each sum is rounded -/

/-- The binary32 word of `2 ^ -12` (bits `0x39800000`). -/
def tinyW : Model .binary32 := f32 0x39800000

/-- The pairs `(1, 1)`, `(2 ^ -12, 2 ^ -12)`, `(2 ^ -12, 2 ^ -12)` of binary32 words, whose
products are `1`, `2 ^ -24`, `2 ^ -24`. -/
def sumPairs : List (Model .binary32 × Model .binary32) :=
  [(f32 0x3f800000, f32 0x3f800000), (tinyW, tinyW), (tinyW, tinyW)]

/-- **The unfused loop over `sumPairs` from `+0` gives `1`**, `2 ^ -23` below the exact sum
`1 + 2 ^ -23` of the products (computed by the kernel): each sum `1 + 2 ^ -24` is a tie between
`1` and `1 + 2 ^ -23` and rounds to the even `1`, while each product is exact. Its products are
`1`, `2 ^ -24`, `2 ^ -24`. -/
theorem sum_rounded :
    (dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) sumPairs).toReal = 1 ∧
      sumPairs.map (fun ab => ab.1.toReal * ab.2.toReal) = [1, 1 / 2 ^ 24, 1 / 2 ^ 24] := by
  have h : (dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) sumPairs).toRat? =
      some 1 ∧ (f32 0x3f800000).toRat? = some 1 ∧ tinyW.toRat? = some (1 / 2 ^ 12) := by
    decide +kernel
  obtain ⟨h1, h2, h3⟩ := h
  refine ⟨?_, ?_⟩
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h1]; push_cast; ring
  · simp only [sumPairs, List.map_cons, List.map_nil, Model.Algebraic.toReal_of_toRat?_eq_some h2,
      Model.Algebraic.toReal_of_toRat?_eq_some h3]
    norm_num

/-- **The error is within `dotLoopBound` at `K = 3`**: on `sumPairs`, the unfused loop's error
`2 ^ -23` is at most `dotLoopBound .binary32 3 (1 + 2 ^ -23)`, the bound of
`dotLoop_error_zero` at the sum `1 + 2 ^ -23` of the absolute products, about `3 · 2 ^ -24`. -/
theorem sum_within :
    |(dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) sumPairs).toReal -
        (sumPairs.map fun ab => ab.1.toReal * ab.2.toReal).sum| = 1 / 2 ^ 23 ∧
      1 / 2 ^ 23 ≤ dotLoopBound .binary32 3 (1 + 1 / 2 ^ 23) := by
  obtain ⟨h1, h2⟩ := sum_rounded
  obtain ⟨hu, hη⟩ := u_eta
  refine ⟨?_, ?_⟩
  · rw [h1, h2]; norm_num
  · rw [dotLoopBound, hu, hη]; norm_num

/-- The bound of a recurrence without the rounding of the accumulated sum, over the products
`P₁, …, P_K` in an IEEE format: `u |P₁| + η` after the first, then `(1 + u) e + u |P| + (2 + u) η`
for each later product `P`. -/
noncomputable def noSumBound (fmt : FloatFormat) : List ℝ → ℝ
  | [] => 0
  | P :: Ps => Ps.foldl (fun e P => (1 + Model.unitRoundoffAt fmt) * e +
      Model.unitRoundoffAt fmt * |P| + (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt)
    (Model.unitRoundoffAt fmt * |P| + Model.underflowErrorAt fmt)

/-- **The mutant: a recurrence without the rounding of the sum fails.** On `sumPairs`'s products
`1`, `2 ^ -24`, `2 ^ -24`, `noSumBound` is below the unfused loop's error `2 ^ -23`
(`sum_within`), so it is not a bound of the loop. -/
theorem noSum_fails : noSumBound .binary32 [1, 1 / 2 ^ 24, 1 / 2 ^ 24] < 1 / 2 ^ 23 := by
  rw [noSumBound, List.foldl_cons, List.foldl_cons, List.foldl_nil, u_eta.1, u_eta.2]
  norm_num [abs_of_pos]

end MojoProofTest.DotGrade
