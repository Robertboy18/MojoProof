import GPUProof.Spec.Basic
import Mathlib.Data.Matrix.Mul
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.StandardModel

/-!
# The first specs: matrix-vector and vector-matrix products and sums

`Spec.ofReal` is the spec of a real function whose entries are all real and which is meant
everywhere, with a graded rule. Its instances are the matrix-vector product (`Spec.matVec`), the
vector-matrix product (`Spec.vecMat`) and the sum over the reals (`Spec.sumReal`), written with
Mathlib's `Matrix.mulVec`, `Matrix.vecMul` and `Finset.sum`. The sum over the integers
(`Spec.sumInt`) has the `exact` rule. Each spec takes its grade: kernels with one mathematics
have different proved bounds.

`laneGrade fmt W d L n` is the grade of a dot product of length `n` in an output format, split
over `W` lanes of at most `L` terms each whose sums are added along a tree of depth `d`: the error
`((1 + u) ^ (L + d) − 1) Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)` at the format's unit roundoff `u`
(`NumFormat.roundoff`, FloatLib's `Model.unitRoundoffAt`), plus the underflow allowance
`W (1 + u) ^ d (2 + u) η ((1 + u) ^ L − 1) / u` at its half subnormal spacing `η`
(`NumFormat.underflow`, FloatLib's `Model.underflowErrorAt`), plus the inputs' propagated error
`Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)`, where `eₐₖ`, `eₓₖ` are the inputs' grade errors taken at
least `0` (`Grade.pos`); its magnitude bound is the larger of `Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)` plus
the error and every input grade's magnitude, so that it bounds every intermediate of a
computation that feeds the dot product (`laneGrade_mag`). `dotGrade fmt n` is its case of one lane
of `n` terms and depth `0`, by definition: error `γₙ Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ) + (2 + u) η γₙ / u`
plus the propagated error, with `γₙ = (1 + u)ⁿ − 1`. Both grow with the inputs' grades
(`laneGrade_mono`, `dotGrade_mono`, for every format, count and exact inputs), so they are grades
of `Spec.matVec` (`laneVecGrade W d L`, `laneVecGrade_mono`, at `L n` terms per lane for length
`n`; `matVecGrade`, `matVecGrade_mono`, its case `laneVecGrade 1 0 id`) and `dotGrade` of
`Spec.vecMat` (`vecMatGrade`, `vecMatGrade_mono`). No kernel is proved to meet them here.

docs/proofs/spec.md gives the plan and the order in which the importers follow.
-/

namespace GPUProof

open FloatLib.Floats.Formats.BinaryInterchange (Model)

variable {Sz : Type}

/-- The grade functions of a spec whose entries are all real, for every size type and entry
index types `In`, `Out`: at each size and encoding, from the exact inputs and their grades, a
grade for each output. -/
abbrev RealGrades (In Out : Sz → Type) : Type 1 :=
  ∀ σ, Encodings In Out (fun _ _ => .real) (fun _ _ => .real) σ → (In σ → ℝ) → (In σ → Grade) →
    Out σ → Grade

/-- The spec of a real function `f`, for every size type and finite input index types: every
entry real, the function meant everywhere, and the graded rule `g`. -/
def Spec.ofReal (In Out : Sz → Type) [∀ σ, Fintype (In σ)] (f : ∀ σ, (In σ → ℝ) → Out σ → ℝ)
    (g : RealGrades In Out) (mono : ∀ σ E A, Monotone (g σ E A)) : Spec Sz where
  In := In
  Out := Out
  dIn _ _ := .real
  dOut _ _ := .real
  Dom _ _ := True
  f := f
  rule := .graded g mono

/-- The matrix-vector product, for every grade `g` and every size `(m, n)`: inputs the entries
`(i, k)` of an `m × n` matrix `A` and the entries `k` of a vector `x` of length `n`, outputs the
`m` entries of `A.mulVec x` (Mathlib's `Matrix.mulVec`). -/
noncomputable def Spec.matVec
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec (ℕ × ℕ) :=
  .ofReal _ _ (fun _ X => Matrix.mulVec (Matrix.of fun i k => X (.inl (i, k))) fun k => X (.inr k))
    g mono

/-- The vector-matrix product, for every grade `g` and every size `(m, n)`: inputs the entries
`i` of a vector `x` of length `m` and the entries `(i, j)` of an `m × n` matrix `A`, outputs the
`n` entries of `Matrix.vecMul x A` (Mathlib's). -/
noncomputable def Spec.vecMat
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec (ℕ × ℕ) :=
  .ofReal _ _
    (fun _ X => Matrix.vecMul (fun i => X (.inl i)) (Matrix.of fun i j => X (.inr (i, j)))) g mono

/-- The sum of `n` reals, for every grade `g` and every size `n`: one output, `∑ i, x i`. -/
noncomputable def Spec.sumReal (g : RealGrades Fin fun _ => Unit)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec ℕ :=
  .ofReal Fin (fun _ => Unit) (fun _ x _ => ∑ i, x i) g mono

/-- The sum of `n` integers, at every size `n`: every entry an integer, one output `∑ i, x i`,
meant everywhere, with the `exact` rule, which claims the sum only where an output word decodes
to it. -/
def Spec.sumInt : Spec ℕ where
  In := Fin
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x _ := ∑ i, x i
  rule := .exact

/-- The unit roundoff of a format, for every format: FloatLib's `Model.unitRoundoffAt` of a
binary interchange format, `0` for an integer or a Boolean. -/
noncomputable def NumFormat.roundoff : NumFormat → ℝ
  | .ieee fmt => Model.unitRoundoffAt fmt
  | _ => 0

/-- The absolute error of rounding below the normal range, for every format: FloatLib's
`Model.underflowErrorAt` of a binary interchange format (half its subnormal spacing), `0` for an
integer or a Boolean. -/
noncomputable def NumFormat.underflow : NumFormat → ℝ
  | .ieee fmt => Model.underflowErrorAt fmt
  | _ => 0

/-- The unit roundoff of every format is at least `0`. -/
theorem NumFormat.roundoff_nonneg : ∀ fmt : NumFormat, 0 ≤ fmt.roundoff
  | .ieee fmt => (Model.unitRoundoffAt_pos fmt).le
  | .int _ => le_rfl
  | .bool => le_rfl

/-- The error of a grade, taken at least `0`, for every grade. -/
noncomputable def Grade.pos (g : Grade) : ℝ := max g.err 0

/-- The grade of a dot product `Σₖ aₖ xₖ` of length `n` split over `W` lanes of at most `L`
terms each, whose lane sums are added along a tree of depth `d`, rounded to format `fmt`, for
every format, counts, exact entries `a`, `x` and their grades `ga`, `gx`: error
`((1 + u) ^ (L + d) − 1) S + W (1 + u) ^ d (2 + u) η ((1 + u) ^ L − 1) / u +
Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)` with `S = Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)`, `u = fmt.roundoff`,
`η = fmt.underflow`, `e = Grade.pos`; magnitude the larger of `S` plus that error and the
largest magnitude of the grades `ga k`, `gx k`. -/
noncomputable def laneGrade (fmt : NumFormat) (W d L n : ℕ) (a x : Fin n → ℝ)
    (ga gx : Fin n → Grade) : Grade :=
  let u := fmt.roundoff
  let S := ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos)
  let e := ((1 + u) ^ (L + d) - 1) * S +
    W * (1 + u) ^ d * ((2 + u) * fmt.underflow * ((1 + u) ^ L - 1) / u) +
    ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos)
  ⟨e, max (S + e) (⨆ k, max (ga k).mag (gx k).mag)⟩

/-- `laneGrade`'s magnitude bounds each input grade's, for every format, counts, exact entries,
grades and index `k`: `(ga k).mag` and `(gx k).mag` are at most its magnitude. -/
theorem laneGrade_mag (fmt : NumFormat) (W d L n : ℕ) (a x : Fin n → ℝ) (ga gx : Fin n → Grade)
    (k : Fin n) :
    (ga k).mag ≤ (laneGrade fmt W d L n a x ga gx).mag ∧
      (gx k).mag ≤ (laneGrade fmt W d L n a x ga gx).mag :=
  have h : max (ga k).mag (gx k).mag ≤ (laneGrade fmt W d L n a x ga gx).mag :=
    (le_ciSup (Finite.bddAbove_range fun k => max (ga k).mag (gx k).mag) k).trans
      (le_max_right _ _)
  ⟨(le_max_left _ _).trans h, (le_max_right _ _).trans h⟩

/-- `laneGrade` grows with the inputs' grades, for every format, counts and exact entries. -/
theorem laneGrade_mono (fmt : NumFormat) (W d L n : ℕ) (a x : Fin n → ℝ)
    {ga ga' gx gx' : Fin n → Grade} (ha : ga ≤ ga') (hx : gx ≤ gx') :
    laneGrade fmt W d L n a x ga gx ≤ laneGrade fmt W d L n a x ga' gx' := by
  have hu := fmt.roundoff_nonneg
  have hγ : 0 ≤ (1 + fmt.roundoff) ^ (L + d) - 1 := sub_nonneg.2 (one_le_pow₀ (by linarith))
  have ea : ∀ k, (ga k).pos ≤ (ga' k).pos := fun k => max_le_max (ha k).1 le_rfl
  have ex : ∀ k, (gx k).pos ≤ (gx' k).pos := fun k => max_le_max (hx k).1 le_rfl
  have pa : ∀ k, 0 ≤ (ga k).pos := fun k => le_max_right _ _
  have px : ∀ k, 0 ≤ (gx k).pos := fun k => le_max_right _ _
  have hS : ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) ≤
      ∑ k, (|a k| + (ga' k).pos) * (|x k| + (gx' k).pos) :=
    Finset.sum_le_sum fun k _ => mul_le_mul (add_le_add_right (ea k) _) (add_le_add_right (ex k) _)
      (add_nonneg (abs_nonneg _) (px k)) (add_nonneg (abs_nonneg _) ((pa k).trans (ea k)))
  have hP : ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos) ≤
      ∑ k, (|a k| * (gx' k).pos + |x k| * (ga' k).pos + (ga' k).pos * (gx' k).pos) :=
    Finset.sum_le_sum fun k _ => add_le_add (add_le_add
      (mul_le_mul_of_nonneg_left (ex k) (abs_nonneg _))
      (mul_le_mul_of_nonneg_left (ea k) (abs_nonneg _)))
      (mul_le_mul (ea k) (ex k) (px k) ((pa k).trans (ea k)))
  have he := add_le_add (add_le_add (mul_le_mul_of_nonneg_left hS hγ)
    (le_refl (W * (1 + fmt.roundoff) ^ d * ((2 + fmt.roundoff) * fmt.underflow *
      ((1 + fmt.roundoff) ^ L - 1) / fmt.roundoff)))) hP
  exact ⟨he, max_le_max (add_le_add hS he) (ciSup_mono (Finite.bddAbove_range _)
    fun k => max_le_max (ha k).2 (hx k).2)⟩

/-- The grade of a dot product `Σₖ aₖ xₖ` of length `n` rounded to format `fmt`, for every format,
length, exact entries `a`, `x` and their grades `ga`, `gx`: `laneGrade` at one lane of `n` terms
and a tree of depth `0`, so with error
`γₙ Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ) + (2 + u) η γₙ / u + Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)`, where
`γₙ = (1 + u)ⁿ − 1`, `u = fmt.roundoff`, `η = fmt.underflow`, `e = Grade.pos`, and magnitude the
larger of `Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)` plus that error and the largest magnitude of the grades
`ga k`, `gx k`. -/
noncomputable def dotGrade (fmt : NumFormat) (n : ℕ) (a x : Fin n → ℝ) (ga gx : Fin n → Grade) :
    Grade :=
  laneGrade fmt 1 0 n n a x ga gx

/-- `dotGrade` grows with the inputs' grades, for every format, length and exact entries
(`laneGrade_mono`). -/
theorem dotGrade_mono (fmt : NumFormat) (n : ℕ) (a x : Fin n → ℝ) {ga ga' gx gx' : Fin n → Grade}
    (ha : ga ≤ ga') (hx : gx ≤ gx') : dotGrade fmt n a x ga gx ≤ dotGrade fmt n a x ga' gx' :=
  laneGrade_mono fmt 1 0 n n a x ha hx

/-- `laneGrade` at every output `i` of `Spec.matVec`, for every size `(m, n)`, encoding, counts
`W`, `d` and lane length `L n`: the dot product of row `i` with the vector, of length `n`, over
`W` lanes of at most `L n` terms and a tree of depth `d`, in output `i`'s format. -/
noncomputable def laneVecGrade (W d : ℕ) (L : ℕ → ℕ) :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  fun σ E A G i => laneGrade (E.out.fmt i) W d (L σ.2) σ.2 (fun k => A (.inl (i, k)))
    (fun k => A (.inr k)) (fun k => G (.inl (i, k))) (fun k => G (.inr k))

/-- `laneVecGrade` grows with the inputs' grades, for all counts, at every size, encoding and
exact inputs. -/
theorem laneVecGrade_mono (W d : ℕ) (L : ℕ → ℕ) : ∀ σ E A, Monotone (laneVecGrade W d L σ E A) :=
  fun _ _ _ _ _ h _ => laneGrade_mono _ _ _ _ _ _ _ (fun _ => h _) (fun _ => h _)

/-- `dotGrade` at every output `i` of `Spec.matVec`, for every size `(m, n)` and encoding: the dot
product of row `i` with the vector, of length `n`, in output `i`'s format; `laneVecGrade` at one
lane of `n` terms and depth `0`. -/
noncomputable def matVecGrade :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  laneVecGrade 1 0 id

/-- `matVecGrade` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem matVecGrade_mono : ∀ σ E A, Monotone (matVecGrade σ E A) :=
  laneVecGrade_mono 1 0 id

/-- `dotGrade` at every output `j` of `Spec.vecMat`, for every size `(m, n)` and encoding: the dot
product of the vector with column `j`, of length `m`, in output `j`'s format. -/
noncomputable def vecMatGrade :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2 :=
  fun σ E A G j => dotGrade (E.out.fmt j) σ.1 (fun i => A (.inl i)) (fun i => A (.inr (i, j)))
    (fun i => G (.inl i)) (fun i => G (.inr (i, j)))

/-- `vecMatGrade` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem vecMatGrade_mono : ∀ σ E A, Monotone (vecMatGrade σ E A) :=
  fun _ _ _ _ _ h _ => dotGrade_mono _ _ _ _ (fun _ => h _) (fun _ => h _)

end GPUProof
