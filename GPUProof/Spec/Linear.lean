import GPUProof.Spec.Basic
import GPUProof.Spec.Comp
import Mathlib.Data.Matrix.Mul
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.StandardModel

/-!
# The first specs: matrix-vector and vector-matrix products and sums

`Spec.ofReal` is the spec of a real function whose entries are all real and which is meant
everywhere, with a graded rule. Its instances are the matrix-vector product (`Spec.matVec`), the
vector-matrix product (`Spec.vecMat`) and the sum over the reals (`Spec.sumReal`), written with
Mathlib's `Matrix.mulVec`, `Matrix.vecMul` and `Finset.sum`. The sum over the integers
(`Spec.sumInt`) has the `exact` rule. Each spec takes its grade: kernels with one mathematics
have different proved bounds. The five specs are `[implicit_reducible]`, so that instance search
sees their entry types and index types through the encodings of GPUProof/Spec/Basic.lean. A spec
written as `Spec.ofReal …`, or as an `abbrev` of one, has finite outputs wherever its output type
does (`Spec.ofReal.fintypeOut`). Instance search does not unfold a `def` to find that instance, so
each of the four specs past `Spec.ofReal` has its own (`Spec.matVec.fintypeOut`,
`Spec.vecMat.fintypeOut`, `Spec.sumReal.fintypeOut`, `Spec.sumInt.fintypeOut`); with
GPUProof/Spec/DecEq.lean's `Encodings.fintypeUniformOut` they give the finite output positions of
the specs' uniform encodings.

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
(`laneGrade_mono`, `dotGrade_mono`, for every format, count and exact inputs).
`laneGradeIn fmt W d L n fa fx` is `laneGrade` where every input grade's magnitude is at most its
input format's `safeMax` (`fa k`, `fx k`), and elsewhere `Grade.onlyIf`'s grade that claims
nothing (GPUProof/Spec/Comp.lean, imported here): an input grade above its format's `safeMax`
gives no premise on that input (`Approx`), so a claim of the output there would ask for the exact
product of words it does not constrain. It grows with the inputs' grades (`laneGradeIn_mono`), and
reals within the input grades have a dot product `Approx` at it, at all formats
(`laneGradeIn_approx`, by `sum_mul_sub_le` and `laneGrade_err_ge`). It gives the grades of
`Spec.matVec` (`laneVecGrade W d L`, `laneVecGrade_mono`, over row `i` and the vector at `L n`
terms per lane for length `n`; `matVecGrade`, `matVecGrade_mono`, its case `laneVecGrade 1 0 id`)
and of `Spec.vecMat` (`vecMatLaneGrade W d L`, `vecMatLaneGrade_mono`, over the vector and column
`j` at `L m` terms per lane for length `m`; `vecMatGrade`, `vecMatGrade_mono`, its case
`vecMatLaneGrade 1 0 id`), each in its output's format and guarded by the formats of the inputs
it reads. Words that decode to the exact product meet both at every encoding
(`laneVecGrade_holds`, `vecMatLaneGrade_holds`, by `laneGradeIn_approx`); no kernel is proved
here.

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
@[implicit_reducible]
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
@[implicit_reducible]
noncomputable def Spec.matVec
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec (ℕ × ℕ) :=
  .ofReal _ _ (fun _ X => Matrix.mulVec (Matrix.of fun i k => X (.inl (i, k))) fun k => X (.inr k))
    g mono

/-- The vector-matrix product, for every grade `g` and every size `(m, n)`: inputs the entries
`i` of a vector `x` of length `m` and the entries `(i, j)` of an `m × n` matrix `A`, outputs the
`n` entries of `Matrix.vecMul x A` (Mathlib's). -/
@[implicit_reducible]
noncomputable def Spec.vecMat
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec (ℕ × ℕ) :=
  .ofReal _ _
    (fun _ X => Matrix.vecMul (fun i => X (.inl i)) (Matrix.of fun i j => X (.inr (i, j)))) g mono

/-- The sum of `n` reals, for every grade `g` and every size `n`: one output, `∑ i, x i`. -/
@[implicit_reducible]
noncomputable def Spec.sumReal (g : RealGrades Fin fun _ => Unit)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec ℕ :=
  .ofReal Fin (fun _ => Unit) (fun _ x _ => ∑ i, x i) g mono

/-- The sum of `n` integers, at every size `n`: every entry an integer, one output `∑ i, x i`,
meant everywhere, with the `exact` rule, which claims the sum only where an output word decodes
to it. -/
@[implicit_reducible]
def Spec.sumInt : Spec ℕ where
  In := Fin
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x _ := ∑ i, x i
  rule := .exact

/-- `Spec.matVec`'s outputs are finite, for every grade and size `(m, n)`: they are `Fin m`. -/
instance Spec.matVec.fintypeOut
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A)) (σ : ℕ × ℕ) : Fintype ((Spec.matVec g mono).Out σ) :=
  inferInstanceAs (Fintype (Fin σ.1))

/-- `Spec.vecMat`'s outputs are finite, for every grade and size `(m, n)`: they are `Fin n`. -/
instance Spec.vecMat.fintypeOut
    (g : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (mono : ∀ σ E A, Monotone (g σ E A)) (σ : ℕ × ℕ) : Fintype ((Spec.vecMat g mono).Out σ) :=
  inferInstanceAs (Fintype (Fin σ.2))

/-- `Spec.sumReal`'s outputs are finite, for every grade and size: there is one, `Unit`. -/
instance Spec.sumReal.fintypeOut (g : RealGrades Fin fun _ => Unit)
    (mono : ∀ σ E A, Monotone (g σ E A)) (n : ℕ) : Fintype ((Spec.sumReal g mono).Out n) :=
  inferInstanceAs (Fintype Unit)

/-- `Spec.sumInt`'s outputs are finite, at every size: there is one, `Unit`. -/
instance Spec.sumInt.fintypeOut (n : ℕ) : Fintype (Spec.sumInt.Out n) :=
  inferInstanceAs (Fintype Unit)

/-- `Spec.ofReal`'s outputs are finite wherever its output type is, for every size type, finite
input and output index types, function, grade and size: they are `Out σ`. Instance search finds
it at a spec written as `Spec.ofReal …` or as an `abbrev` of one, not at a `def` such as
`Spec.matVec`, which it does not unfold. -/
instance Spec.ofReal.fintypeOut (In Out : Sz → Type) [∀ σ, Fintype (In σ)]
    [h : ∀ σ, Fintype (Out σ)] (f : ∀ σ, (In σ → ℝ) → Out σ → ℝ) (g : RealGrades In Out)
    (mono : ∀ σ E A, Monotone (g σ E A)) (σ : Sz) :
    Fintype ((Spec.ofReal In Out f g mono).Out σ) :=
  h σ

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

/-- **`laneGrade` where the inputs' grades claim.** For every output format `fmt`, counts `W`,
`d`, `L`, length `n`, input formats `fa`, `fx`, exact entries `a`, `x` and grades `ga`, `gx`:
`laneGrade fmt W d L n a x ga gx` where every `(ga k).mag` is at most `(fa k).safeMax` and every
`(gx k).mag` at most `(fx k).safeMax`, and elsewhere `Grade.onlyIf`'s grade that claims nothing in
`fmt`. An input grade of magnitude above its format's `safeMax` asks nothing of that input's word
(`Approx`), so no claim is made on the output there. -/
noncomputable def laneGradeIn (fmt : NumFormat) (W d L n : ℕ) (fa fx : Fin n → NumFormat)
    (a x : Fin n → ℝ) (ga gx : Fin n → Grade) : Grade :=
  Grade.onlyIf (∀ k, (ga k).mag ≤ (fa k).safeMax ∧ (gx k).mag ≤ (fx k).safeMax) fmt
    (laneGrade fmt W d L n a x ga gx)

/-- `laneGradeIn` grows with the inputs' grades, for every format, counts, input formats and exact
entries: larger grades make `laneGrade` larger (`laneGrade_mono`) and the condition stronger
(`Grade.onlyIf_mono`). -/
theorem laneGradeIn_mono (fmt : NumFormat) (W d L n : ℕ) (fa fx : Fin n → NumFormat)
    (a x : Fin n → ℝ) {ga ga' gx gx' : Fin n → Grade} (ha : ga ≤ ga') (hx : gx ≤ gx') :
    laneGradeIn fmt W d L n fa fx a x ga gx ≤ laneGradeIn fmt W d L n fa fx a x ga' gx' :=
  Grade.onlyIf_mono (fun hc k => ⟨(ha k).2.trans (hc k).1, (hx k).2.trans (hc k).2⟩) fmt
    (laneGrade_mono fmt W d L n a x ha hx)

/-- `laneGradeIn` at every output `i` of `Spec.matVec`, for every size `(m, n)`, encoding, counts
`W`, `d` and lane length `L n`: the dot product of row `i` with the vector, of length `n`, over
`W` lanes of at most `L n` terms and a tree of depth `d`, in output `i`'s format, where the grades
of row `i` and of the vector have magnitudes at most their input formats' `safeMax`, and
elsewhere a grade that claims nothing. -/
noncomputable def laneVecGrade (W d : ℕ) (L : ℕ → ℕ) :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  fun σ E A G i => laneGradeIn (E.out.fmt i) W d (L σ.2) σ.2 (fun k => E.inp.fmt (.inl (i, k)))
    (fun k => E.inp.fmt (.inr k)) (fun k => A (.inl (i, k))) (fun k => A (.inr k))
    (fun k => G (.inl (i, k))) (fun k => G (.inr k))

/-- `laneVecGrade` grows with the inputs' grades, for all counts, at every size, encoding and
exact inputs (`laneGradeIn_mono`). -/
theorem laneVecGrade_mono (W d : ℕ) (L : ℕ → ℕ) : ∀ σ E A, Monotone (laneVecGrade W d L σ E A) :=
  fun _ _ _ _ _ h _ => laneGradeIn_mono _ _ _ _ _ _ _ _ _ (fun _ => h _) (fun _ => h _)

/-- `laneVecGrade` at one lane of `n` terms and depth `0`: at every output `i` of `Spec.matVec`,
for every size `(m, n)` and encoding, `dotGrade` of row `i` with the vector, of length `n`, in
output `i`'s format, where the grades of row `i` and of the vector have magnitudes at most their
input formats' `safeMax`, and elsewhere a grade that claims nothing. -/
noncomputable def matVecGrade :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  laneVecGrade 1 0 id

/-- `matVecGrade` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem matVecGrade_mono : ∀ σ E A, Monotone (matVecGrade σ E A) :=
  laneVecGrade_mono 1 0 id

/-- `laneGradeIn` at every output `j` of `Spec.vecMat`, for every size `(m, n)`, encoding, counts
`W`, `d` and lane length `L m`: the dot product of the vector with column `j`, of length `m`, over
`W` lanes of at most `L m` terms and a tree of depth `d`, in output `j`'s format, where the grades
of the vector and of column `j` have magnitudes at most their input formats' `safeMax`, and
elsewhere a grade that claims nothing. -/
noncomputable def vecMatLaneGrade (W d : ℕ) (L : ℕ → ℕ) :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2 :=
  fun σ E A G j => laneGradeIn (E.out.fmt j) W d (L σ.1) σ.1 (fun i => E.inp.fmt (.inl i))
    (fun i => E.inp.fmt (.inr (i, j))) (fun i => A (.inl i)) (fun i => A (.inr (i, j)))
    (fun i => G (.inl i)) (fun i => G (.inr (i, j)))

/-- `vecMatLaneGrade` grows with the inputs' grades, for all counts, at every size, encoding and
exact inputs (`laneGradeIn_mono`). -/
theorem vecMatLaneGrade_mono (W d : ℕ) (L : ℕ → ℕ) :
    ∀ σ E A, Monotone (vecMatLaneGrade W d L σ E A) :=
  fun _ _ _ _ _ h _ => laneGradeIn_mono _ _ _ _ _ _ _ _ _ (fun _ => h _) (fun _ => h _)

/-- `vecMatLaneGrade` at one lane of `m` terms and depth `0`: at every output `j` of
`Spec.vecMat`, for every size `(m, n)` and encoding, `dotGrade` of the vector with column `j`, of
length `m`, in output `j`'s format, where the grades of the vector and of column `j` have
magnitudes at most their input formats' `safeMax`, and elsewhere a grade that claims nothing. -/
noncomputable def vecMatGrade :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2 :=
  vecMatLaneGrade 1 0 id

/-- `vecMatGrade` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem vecMatGrade_mono : ∀ σ E A, Monotone (vecMatGrade σ E A) :=
  vecMatLaneGrade_mono 1 0 id

/-- The absolute error of rounding below the normal range is at least `0`, for every format. -/
theorem NumFormat.underflow_nonneg : ∀ fmt : NumFormat, 0 ≤ fmt.underflow
  | .ieee fmt => (Model.underflowErrorAt_pos fmt).le
  | .int _ => le_rfl
  | .bool => le_rfl

/-- A dot product of reals near exact ones is within the cross sum of the exact dot product, for
every length, reals `w`, `v`, exact `a`, `x` and grades `ga`, `gx`: when each `w k`, `v k` is
within `(ga k).err`, `(gx k).err` of `a k`, `x k`,
`|Σₖ wₖ vₖ - Σₖ aₖ xₖ| ≤ Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)`, with `e = Grade.pos`: `laneGrade`'s
propagated error. -/
theorem sum_mul_sub_le {n : ℕ} (w v a x : Fin n → ℝ) (ga gx : Fin n → Grade)
    (hw : ∀ k, |w k - a k| ≤ (ga k).err) (hv : ∀ k, |v k - x k| ≤ (gx k).err) :
    |∑ k, w k * v k - ∑ k, a k * x k| ≤
      ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos) := by
  have ea : ∀ k, |w k - a k| ≤ (ga k).pos := fun k => (hw k).trans (le_max_left _ _)
  have ex : ∀ k, |v k - x k| ≤ (gx k).pos := fun k => (hv k).trans (le_max_left _ _)
  have pa : ∀ k, 0 ≤ (ga k).pos := fun k => le_max_right _ _
  rw [← Finset.sum_sub_distrib]
  refine (Finset.abs_sum_le_sum_abs _ _).trans (Finset.sum_le_sum fun k _ => ?_)
  have hk : w k * v k - a k * x k = a k * (v k - x k) + x k * (w k - a k) +
      (w k - a k) * (v k - x k) := by ring
  rw [hk]
  refine (abs_add_le _ _).trans (add_le_add ((abs_add_le _ _).trans (add_le_add ?_ ?_)) ?_)
  · rw [abs_mul]; exact mul_le_mul_of_nonneg_left (ex k) (abs_nonneg _)
  · rw [abs_mul]; exact mul_le_mul_of_nonneg_left (ea k) (abs_nonneg _)
  · rw [abs_mul]; exact mul_le_mul (ea k) (ex k) (abs_nonneg _) (pa k)

/-- `laneGrade`'s error is at least its propagated error, for every format, counts, exact entries
and grades: the rounding and underflow terms are at least `0` (`NumFormat.roundoff_nonneg`,
`NumFormat.underflow_nonneg`). -/
theorem laneGrade_err_ge (fmt : NumFormat) (W d L n : ℕ) (a x : Fin n → ℝ)
    (ga gx : Fin n → Grade) :
    ∑ k, (|a k| * (gx k).pos + |x k| * (ga k).pos + (ga k).pos * (gx k).pos) ≤
      (laneGrade fmt W d L n a x ga gx).err := by
  have hu := fmt.roundoff_nonneg
  have hη := fmt.underflow_nonneg
  have pa : ∀ k, 0 ≤ (ga k).pos := fun k => le_max_right _ _
  have px : ∀ k, 0 ≤ (gx k).pos := fun k => le_max_right _ _
  have hS : 0 ≤ ∑ k, (|a k| + (ga k).pos) * (|x k| + (gx k).pos) :=
    Finset.sum_nonneg fun k _ => mul_nonneg (add_nonneg (abs_nonneg _) (pa k))
      (add_nonneg (abs_nonneg _) (px k))
  have hγ : ∀ j, 0 ≤ (1 + fmt.roundoff) ^ j - 1 := fun j =>
    sub_nonneg.2 (one_le_pow₀ (by linarith))
  have hU : 0 ≤ W * (1 + fmt.roundoff) ^ d * ((2 + fmt.roundoff) * fmt.underflow *
      ((1 + fmt.roundoff) ^ L - 1) / fmt.roundoff) :=
    mul_nonneg (mul_nonneg (Nat.cast_nonneg _) (pow_nonneg (by linarith) _))
      (div_nonneg (mul_nonneg (mul_nonneg (by linarith) hη) (hγ L)) hu)
  simp only [laneGrade]
  nlinarith [mul_nonneg (hγ (L + d)) hS]

/-- **Reals within the input grades meet `laneGradeIn`.** For every output format `fmt`, counts
`W`, `d`, `L`, length `n`, input formats `fa`, `fx`, reals `w`, `v`, exact entries `a`, `x` and
grades `ga`, `gx`: when each `some (w k)` is `Approx` at `ga k` in `fa k` of `a k` and each
`some (v k)` at `gx k` in `fx k` of `x k`, `some (Σₖ wₖ vₖ)` is `Approx` at
`laneGradeIn fmt W d L n fa fx a x ga gx` in `fmt` of `Σₖ aₖ xₖ`. Where the condition holds, each
input is within its grade's error of the exact one, and the dot product moves by at most the
propagated error (`sum_mul_sub_le`), part of `laneGrade`'s error (`laneGrade_err_ge`); elsewhere
the grade claims nothing (`Approx.onlyIf_neg`). No premise on the formats: `fmt`'s `safeMax` is
not used. -/
theorem laneGradeIn_approx (fmt : NumFormat) (W d L n : ℕ) (fa fx : Fin n → NumFormat)
    {w v a x : Fin n → ℝ} {ga gx : Fin n → Grade}
    (hw : ∀ k, Approx .real (ga k) (fa k) (some (w k)) (a k))
    (hv : ∀ k, Approx .real (gx k) (fx k) (some (v k)) (x k)) :
    Approx .real (laneGradeIn fmt W d L n fa fx a x ga gx) fmt (some (∑ k, w k * v k))
      (∑ k, a k * x k) := by
  by_cases hc : ∀ k, (ga k).mag ≤ (fa k).safeMax ∧ (gx k).mag ≤ (fx k).safeMax
  · have e : ∀ {g : Grade} {f : NumFormat} {r b : ℝ}, Approx .real g f (some r) b →
        g.mag ≤ f.safeMax → |r - b| ≤ g.err := fun h hm => by
      obtain ⟨r', hr, hr'⟩ := h hm
      cases hr
      exact hr'
    rw [laneGradeIn, Grade.onlyIf_pos hc]
    exact fun _ => ⟨_, rfl, (sum_mul_sub_le w v a x ga gx (fun k => e (hw k) (hc k).1)
      fun k => e (hv k) (hc k).2).trans (laneGrade_err_ge _ _ _ _ _ _ _ _ _)⟩
  · exact Approx.onlyIf_neg hc _ _ _ _ _

/-- **Exact words meet `laneVecGrade`**, for all counts `W`, `d`, `L`, every size `(m, n)` and
every encoding `E` of `Spec.matVec` at `laneVecGrade W d L`: input words `X` that decode to reals
`Y` and output words `X'` that decode to the product at `Y` meet the graded rule
(`laneGradeIn_approx` at row `o` and the vector). No premise on the formats is left: the grade
claims only where the grades of the inputs it reads are at most their formats' `safeMax`, and
there each such input is within its grade's error of the exact one, whatever the output's
format, so an output format whose `safeMax` is above an input's is allowed. -/
theorem laneVecGrade_holds (W d : ℕ) (L : ℕ → ℕ) {σ : ℕ × ℕ}
    {E : (Spec.matVec (laneVecGrade W d L) (laneVecGrade_mono W d L)).Encs σ}
    {X : E.inp.Words} {Y : Fin σ.1 × Fin σ.2 ⊕ Fin σ.2 → ℝ}
    (hX : ∀ i, E.inp.decode X i = some (Y i)) {X' : E.out.Words}
    (hX' : ∀ o, E.out.decode X' o =
      some ((Spec.matVec (laneVecGrade W d L) (laneVecGrade_mono W d L)).f σ Y o)) :
    (Spec.matVec (laneVecGrade W d L) (laneVecGrade_mono W d L)).rule.Holds σ E X X' := by
  intro _ _ _ hA o
  rw [hX' o]
  exact laneGradeIn_approx _ _ _ _ _ _ _ (fun k => hX (.inl (o, k)) ▸ hA (.inl (o, k)))
    fun k => hX (.inr k) ▸ hA (.inr k)

/-- **Exact words meet `vecMatLaneGrade`**, for all counts `W`, `d`, `L`, every size `(m, n)` and
every encoding `E` of `Spec.vecMat` at `vecMatLaneGrade W d L`: input words `X` that decode to
reals `Y` and output words `X'` that decode to the product at `Y` meet the graded rule
(`laneGradeIn_approx` at the vector and column `o`). No premise on the formats, as for
`laneVecGrade_holds`. -/
theorem vecMatLaneGrade_holds (W d : ℕ) (L : ℕ → ℕ) {σ : ℕ × ℕ}
    {E : (Spec.vecMat (vecMatLaneGrade W d L) (vecMatLaneGrade_mono W d L)).Encs σ}
    {X : E.inp.Words} {Y : Fin σ.1 ⊕ Fin σ.1 × Fin σ.2 → ℝ}
    (hX : ∀ i, E.inp.decode X i = some (Y i)) {X' : E.out.Words}
    (hX' : ∀ o, E.out.decode X' o =
      some ((Spec.vecMat (vecMatLaneGrade W d L) (vecMatLaneGrade_mono W d L)).f σ Y o)) :
    (Spec.vecMat (vecMatLaneGrade W d L) (vecMatLaneGrade_mono W d L)).rule.Holds σ E X X' := by
  intro _ _ _ hA o
  rw [hX' o]
  exact laneGradeIn_approx _ _ _ _ _ _ _ (fun k => hX (.inl k) ▸ hA (.inl k))
    fun k => hX (.inr (k, o)) ▸ hA (.inr (k, o))

end GPUProof
