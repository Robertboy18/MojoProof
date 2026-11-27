import GPUProof.Spec.CompGraded
import GPUProof.Spec.Linear
import MojoProofTest.GPUProof.SpecComp

/-!
# A graded rule then an `exact` one, on a test instance

* An `exact` spec with a linear modulus. The sum of the `m` entries of a real vector at every size
  `(m, n)` with the `exact` rule (`sumEx`), its modulus the sum of the input grades' errors
  (`sumMod`, `|∑ Y - ∑ A| ≤ ∑ |Y i - A i|`, monotone by `sumMod_mono`), and fixed-point storage
  (`fixEnc bits`: words `BitVec bits` decoded as two's complement integers, as reals).
* `GPUProof.Spec.matVec` at `GPUProof.matVecGrade` wired into `sumEx` with no extra input
  (`mvSum`), with 8-bit words for the product's inputs and outputs (`mvEnc`) and `8 + m`-bit
  words for the sum (`sumOut`). Every field of the modulus is proved at every size
  (`sumMod_modulus`): within the grades the sums differ by at most the errors' sum
  (`sumMod_near`), the domain is everything, and `m` entries of 8 bits sum to a value of
  `8 + m` bits (`sumOut_rep`), at every encoding of the (absent) extra inputs. So
  `GPUProof.MeetsAt.comp_graded_exact` gives the composite (`mvSum_meets`), and
  `GPUProof.Meets.comp_graded_exact` gives it at every composite input encoding with the outputs
  `sumOut` and the intermediate at `mvEnc`'s outputs, for behaviors that meet the two specs at
  every encoding (`mvSum_meetsAll`).
* By the theorems, at every size `(m, n)` with `n ≤ 127`, with the behaviors `ruleK` of
  MojoProofTest/GPUProof/SpecComp.lean and input words `1`: the composition has an output, the
  word `m n` of `8 + m` bits (`toInt_ofInt_fits`) after the intermediate words `n`, each in its
  `ruleK` (`mvSum_ones_mem`, by `GPUProof.laneVecGrade_holds`, `GPUProof.FloatRule.Holds.exact_of`
  and `GPUProof.Wiring.mem_behav`), and at exact input grades every output decodes to `m n`
  (`mvSum_ones`, from `mvSum_meets`). The two `example`s after them state both, an output and
  every output's value, at size `(2, 3)` with the value `6` and at `(5, 1)` with `5`; only
  `n ≤ 127` (by `decide`) and the product `m n` (by norm_num) are evaluated there.
* The mutant: the grade of error `0` (`sumZero`) is not a modulus of `sumEx` at size `(1, 1)`
  (`sumZero_refused`): one input word `1` within grade error `1` of the exact input `0` gives the
  sum `1`, not within `0` of `0`.
* `GPUProof.matVecGrade`'s rule at inputs narrower than the outputs, 8-bit inputs and 16-bit
  outputs (`wideEnc`): the exact words meet it, at size `(1, 1)` with inputs `100` and the output
  `10000` (`wide_holds`) and at `(2, 5)` with inputs `50` and outputs `12500` (`wide_holds_2x5`),
  by `GPUProof.laneVecGrade_holds`, so `ruleK`, which meets the product at every encoding, has an
  output there (the `example` after them); and `GPUProof.vecMatGrade`'s at size `(5, 2)` with inputs
  `50` and outputs `12500` (`wide_vecMat`, by `GPUProof.vecMatLaneGrade_holds`). The grade claims
  only where the input grades it reads are at most their formats' largest values
  (`GPUProof.laneGradeIn`).
* The mutant, the grade with the output's guard only (`rawGrade`, `GPUProof.dotGrade` with no
  guard on the inputs): at `wideEnc` and size `(1, 1)` no words meet its rule (`wide_refused`). An
  input grade of magnitude `200`, above the input's largest value, gives no premise on that input,
  while the output's grade still claims the exact product, `0` at the inputs `0` and `1` at the
  inputs `1`.
-/

open GPUProof

namespace MojoProofTest.GPUProof.SpecCompGraded

open MojoProofTest.GPUProof.SpecComp (ruleK ruleK_meets)

/-- One test storage of a real entry (`fixEnc bits`), at every width: words `BitVec bits` decoded
as two's complement integers, as reals, with no NaN, in the format of a `bits`-bit integer. -/
@[implicit_reducible]
noncomputable def fixEnc (bits : ℕ) : ScalarEnc .real where
  Word := BitVec bits
  decode w := some (w.toInt : ℝ)
  isNaN _ := false
  fmt := .int bits
  decode_isNaN _ h := absurd h Bool.false_ne_true

/-- One test spec with the `exact` rule (`sumEx`), at every size `(m, n)`: the sum of the `m`
entries of a real vector, meant everywhere, one output. The size `n` is unread, so that it wires
after `GPUProof.Spec.matVec`. -/
@[implicit_reducible]
noncomputable def sumEx : Spec (ℕ × ℕ) where
  In σ := Fin σ.1
  Out _ := Unit
  dIn _ _ := .real
  dOut _ _ := .real
  Dom _ _ := True
  f _ x _ := ∑ i, x i
  rule := .exact

/-- One test modulus of `sumEx` (`sumMod`), at every size, encoding, exact inputs and grades: the
sum of the input grades' errors, with magnitude `0`. -/
noncomputable def sumMod : ∀ σ, sumEx.Encs σ → Ents (sumEx.In σ) (sumEx.dIn σ) →
    (sumEx.In σ → Grade) → sumEx.Out σ → Grade :=
  fun σ _ _ G _ => ⟨∑ i : Fin σ.1, (G i).err, 0⟩

/-- `sumMod` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem sumMod_mono : ∀ σ E A, Monotone (sumMod σ E A) :=
  fun σ _ _ G G' h _ => ⟨(Finset.sum_le_sum fun i _ => (h i).1 :
    ∑ i : Fin σ.1, (G i).err ≤ ∑ i : Fin σ.1, (G' i).err), le_rfl⟩

/-- One test wiring (`mvSum`), at every size `(m, n)`: the `m` outputs of `GPUProof.Spec.matVec`
at `GPUProof.matVecGrade` into the `m` inputs of `sumEx`, with no extra input. -/
noncomputable def mvSum : Wiring (Spec.matVec matVecGrade matVecGrade_mono) sumEx where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire σ := (Equiv.sumEmpty (Fin σ.1) Empty).symm
  types _ _ := rfl

/-- One test encoding of `GPUProof.Spec.matVec` (`mvEnc`), at every size: every input and output
stored by `fixEnc 8`. -/
noncomputable def mvEnc (σ : ℕ × ℕ) : (Spec.matVec matVecGrade matVecGrade_mono).Encs σ :=
  ⟨.ofScalars fun _ => fixEnc 8, .ofScalars fun _ => fixEnc 8⟩

/-- The encoding of `mvSum`'s extra inputs, at every size: there are none. -/
noncomputable def noEx (σ : ℕ × ℕ) : Encoding (mvSum.Extra σ) (mvSum.dEx σ) :=
  .ofScalars fun e => Empty.elim e

/-- One test encoding of `sumEx`'s output (`sumOut`), at every size `(m, n)`: `fixEnc (8 + m)`. -/
noncomputable def sumOut (σ : ℕ × ℕ) : Encoding (sumEx.Out σ) (sumEx.dOut σ) :=
  .ofScalars fun _ => fixEnc (8 + σ.1)

/-- A real near another within a grade differs from it by at most the grade's error, for every
grade and two reals. -/
theorem near_real {g : Grade} {y a : ℝ} (h : DType.Near .real g (some y) a) : |y - a| ≤ g.err := by
  obtain ⟨r, hr, h⟩ := h
  cases hr
  exact h

/-- `sumMod`'s bound, at every size, encoding, exact inputs `A`, grades `G` and inputs `Y` within
`G` of `A`: `|∑ Y - ∑ A| ≤ ∑ |Y i - A i| ≤ ∑ (G i).err`. -/
theorem sumMod_near (σ : ℕ × ℕ) (E : sumEx.Encs σ) (A G Y) (hY : E.inp.Within G A Y) (o : Unit) :
    (sumEx.dOut σ o).Near (sumMod σ E A G o) (some (sumEx.f σ Y o)) (sumEx.f σ A o) := by
  refine ⟨_, rfl, ?_⟩
  show |∑ i : Fin σ.1, (Y i : ℝ) - ∑ i : Fin σ.1, (A i : ℝ)| ≤ ∑ i : Fin σ.1, (G i).err
  rw [← Finset.sum_sub_distrib]
  exact (Finset.abs_sum_le_sum_abs _ _).trans
    (Finset.sum_le_sum fun i _ => near_real (hY.2 i).2)

/-- An integer of magnitude at most `128 m` has a word of `8 + m` bits, at every `m` and integer
`s` with `-128 m ≤ s ≤ 128 m`: `BitVec.ofInt (8 + m) s` reads back as `s`, since
`128 m < 2 ^ (7 + m)`. -/
theorem toInt_ofInt_fits (m : ℕ) {s : ℤ} (h₁ : -(128 * (m : ℤ)) ≤ s) (h₂ : s ≤ 128 * m) :
    (BitVec.ofInt (8 + m) s).toInt = s := by
  have hm : (m : ℤ) < 2 ^ m := by exact_mod_cast Nat.lt_two_pow_self
  have hp : (2 : ℤ) ^ (8 + m - 1) = 128 * 2 ^ m := by
    rw [show 8 + m - 1 = 7 + m by omega, pow_add]
    norm_num
  exact BitVec.toInt_ofInt_eq_self (by omega) (by rw [hp]; nlinarith) (by rw [hp]; nlinarith)

/-- `m` entries of 8 bits sum to a value of `8 + m` bits, at every size `(m, n)` and encoding
`ex` of `mvSum`'s extra inputs: inputs `Y` decoded from words of `mvEnc`'s outputs and `ex`
along `mvSum` have their sum decoded from a word of `sumOut`, since `m · 2 ^ 7 < 2 ^ (7 + m)`
(`toInt_ofInt_fits`). -/
theorem sumOut_rep (σ : ℕ × ℕ) (ex : Encoding (mvSum.Extra σ) (mvSum.dEx σ))
    (Y : Ents (sumEx.In σ) (sumEx.dIn σ))
    (hY : ∃ W : (mvSum.inpEnc σ (mvEnc σ).out ex).Words,
      ∀ i, (mvSum.inpEnc σ (mvEnc σ).out ex).decode W i = some (Y i)) :
    ∃ V : (sumOut σ).Words, ∀ o, (sumOut σ).decode V o = some (sumEx.f σ Y o) := by
  obtain ⟨W, hW⟩ := hY
  have hy : ∀ i : Fin σ.1, (Y i : ℝ) = ((W (Sum.inl i) : BitVec 8).toInt : ℝ) := fun i =>
    (Option.some.inj (hW i)).symm
  refine ⟨fun _ => BitVec.ofInt (8 + σ.1) (∑ i : Fin σ.1, (W (Sum.inl i) : BitVec 8).toInt),
    fun o => ?_⟩
  have hlo : ∀ i : Fin σ.1, -128 ≤ (W (Sum.inl i) : BitVec 8).toInt := fun i =>
    BitVec.le_toInt _
  have hhi : ∀ i : Fin σ.1, (W (Sum.inl i) : BitVec 8).toInt < 128 := fun i => BitVec.toInt_lt
  have hs₁ : -(128 * (σ.1 : ℤ)) ≤ ∑ i : Fin σ.1, (W (Sum.inl i) : BitVec 8).toInt := by
    have := Finset.sum_le_sum fun i (_ : i ∈ Finset.univ) => hlo i
    simp only [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul] at this
    linarith
  have hs₂ : ∑ i : Fin σ.1, (W (Sum.inl i) : BitVec 8).toInt ≤ 128 * (σ.1 : ℤ) := by
    have := Finset.sum_le_sum fun i (_ : i ∈ Finset.univ) => (hhi i).le
    simp only [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul] at this
    linarith
  show some ((BitVec.ofInt (8 + σ.1) (∑ i : Fin σ.1, (W (Sum.inl i) : BitVec 8).toInt)).toInt :
    ℝ) = some (∑ i : Fin σ.1, Y i)
  rw [toInt_ofInt_fits σ.1 hs₁ hs₂]
  congr 1
  push_cast
  exact Finset.sum_congr rfl fun i _ => (hy i).symm

/-- `sumMod` is a modulus of `sumEx` at `mvEnc`'s outputs and every encoding `ex` of `mvSum`'s
extra inputs along `mvSum`, with `sumOut`, at every size (`GPUProof.Spec.Modulus`): its bound
(`sumMod_near`), the domain is everything, and the sum has a word (`sumOut_rep`). -/
theorem sumMod_modulus (σ : ℕ × ℕ) (ex : Encoding (mvSum.Extra σ) (mvSum.dEx σ)) :
    sumEx.Modulus sumMod σ ⟨mvSum.inpEnc σ (mvEnc σ).out ex, sumOut σ⟩ :=
  ⟨fun A G Y _ hY => sumMod_near σ _ A G Y hY, fun _ _ _ _ _ => trivial,
    fun _ _ Y _ hY => sumOut_rep σ ex Y hY.1⟩

/-- One test composition (`mvSum`), for every behaviors `k₁` of `GPUProof.Spec.matVec` at
`GPUProof.matVecGrade` and `k₂` of `sumEx`: if `k₁` meets the product at `mvEnc` and `k₂` meets
`sumEx` at its outputs along `mvSum` with `sumOut`, the composition meets the composite with the
graded rule `GPUProof.Wiring.grade` at `GPUProof.matVecGrade` and `GPUProof.Spec.modGrade sumMod`
(`GPUProof.MeetsAt.comp_graded_exact`, its premises by `rfl`, `sumMod_mono` and
`sumMod_modulus`). -/
theorem mvSum_meets
    {k₁ : ∀ σ (E : (Spec.matVec matVecGrade matVecGrade_mono).Encs σ), E.inp.Words →
      Set E.out.Words}
    {k₂ : ∀ σ (E : sumEx.Encs σ), E.inp.Words → Set E.out.Words}
    (hk₁ : MeetsAt (Spec.matVec matVecGrade matVecGrade_mono) k₁ mvEnc)
    (hk₂ : MeetsAt sumEx k₂ (mvSum.encs₂ mvEnc noEx sumOut)) :
    MeetsAt (mvSum.spec (.graded (mvSum.grade mvEnc noEx matVecGrade (sumEx.modGrade sumMod))
        (mvSum.grade_mono mvEnc noEx matVecGrade_mono (sumEx.modGrade_mono sumMod_mono))))
      (mvSum.behav k₁ k₂ mvEnc noEx sumOut) (mvSum.encs mvEnc noEx sumOut) :=
  MeetsAt.comp_graded_exact mvSum rfl rfl sumMod_mono mvEnc noEx sumOut
    (fun σ => sumMod_modulus σ (noEx σ)) hk₁ hk₂

/-- One test composition (`mvSum`) at every input encoding, for every behaviors `k₁` of
`GPUProof.Spec.matVec` at `GPUProof.matVecGrade` and `k₂` of `sumEx` that meet them at every
encoding, with the intermediate at `mvEnc`'s outputs: at every composite input encoding `I` with
the outputs `sumOut`, the composition (`GPUProof.Wiring.behavMid`) meets the composite with the
graded rule `GPUProof.Wiring.gradeBy` at `GPUProof.matVecGrade` and
`GPUProof.Spec.modGrade sumMod` (`GPUProof.Meets.comp_graded_exact`, its modulus
`sumMod_modulus` at `I`'s extra inputs). -/
theorem mvSum_meetsAll
    {k₁ : ∀ σ (E : (Spec.matVec matVecGrade matVecGrade_mono).Encs σ), E.inp.Words →
      Set E.out.Words}
    {k₂ : ∀ σ (E : sumEx.Encs σ), E.inp.Words → Set E.out.Words}
    (hk₁ : Meets (Spec.matVec matVecGrade matVecGrade_mono) k₁) (hk₂ : Meets sumEx k₂)
    (I : ∀ σ, Encoding (mvSum.In σ) (mvSum.dIn σ)) :
    MeetsAt (mvSum.spec (.graded (mvSum.gradeBy (mvSum.fstEncs fun σ _ => (mvEnc σ).out)
        mvSum.exEnc matVecGrade (sumEx.modGrade sumMod))
        (mvSum.gradeBy_mono _ _ matVecGrade_mono (sumEx.modGrade_mono sumMod_mono))))
      (mvSum.behavMid k₁ k₂ fun σ _ => (mvEnc σ).out) fun σ => ⟨I σ, sumOut σ⟩ :=
  Meets.comp_graded_exact mvSum rfl rfl sumMod_mono _ hk₁ hk₂ fun σ =>
    sumMod_modulus σ (mvSum.exEnc σ ⟨I σ, sumOut σ⟩)

/-- Every output of one test composition (`mvSum`) is `m n`, at every size `(m, n)` with
`n ≤ 127`: with the behaviors `ruleK`, input words `1` and exact input grades `⟨0, 0⟩`, every
output word of the composition decodes to `m n`, by the theorem at every such size, nothing
evaluated; `mvSum_ones_mem` gives one output. The product's grade at each output is error `0` and
magnitude `n`, at most `127`, the largest 8-bit value, so `GPUProof.Spec.modGrade sumMod` is
`⟨0, 0⟩` (`mvSum_meets`, `GPUProof.Approx.eq_some`). -/
theorem mvSum_ones (σ : ℕ × ℕ) (hn : σ.2 ≤ 127) :
    ∀ W' ∈ mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut σ (mvSum.encs mvEnc noEx sumOut σ)
        (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim),
      (sumOut σ).decode W' () = some ((σ.1 * σ.2 : ℕ) : ℝ) := by
  intro W' hW'
  have h1 : (((1 : BitVec 8).toInt : ℤ) : ℝ) = 1 := by
    rw [show (1 : BitVec 8).toInt = 1 by decide]
    norm_num
  have h := mvSum_meets (ruleK_meets _ _) (ruleK_meets _ _) σ _ W' hW'
    (fun | .inl _ => (((1 : BitVec 8).toInt : ℤ) : ℝ) | .inr e => e.elim) (fun _ => ⟨0, 0⟩)
    ⟨trivial, trivial⟩ (fun | .inl _ => Approx.some_zero .real _ _ | .inr e => e.elim) ()
  have hc : ∀ i : Fin σ.1,
      matVecGrade σ (mvEnc σ) (fun _ => (((1 : BitVec 8).toInt : ℤ) : ℝ)) (fun _ => ⟨0, 0⟩) i =
        ⟨0, σ.2⟩ := by
    intro i
    have hf : (mvEnc σ).out.fmt i = .int 8 := rfl
    have h0 : (0 : ℝ) ≤ (NumFormat.int 8).safeMax := by norm_num [NumFormat.safeMax]
    simp only [matVecGrade, laneVecGrade, laneGradeIn]
    rw [Grade.onlyIf_pos]
    · simp only [laneGrade, Grade.pos, h1, hf, NumFormat.roundoff, NumFormat.underflow]
      simp
    · exact fun _ => ⟨h0, h0⟩
  have hg : mvSum.grade mvEnc noEx matVecGrade (sumEx.modGrade sumMod) σ
      (mvSum.encs mvEnc noEx sumOut σ)
      (fun | .inl _ => (((1 : BitVec 8).toInt : ℤ) : ℝ) | .inr e => e.elim) (fun _ => ⟨0, 0⟩) () =
        ⟨0, 0⟩ := by
    show Grade.onlyIf (∀ i : Fin σ.1, (matVecGrade σ (mvEnc σ)
        (fun _ => (((1 : BitVec 8).toInt : ℤ) : ℝ)) (fun _ => ⟨0, 0⟩) i).mag ≤
          (NumFormat.int 8).safeMax) (NumFormat.int (8 + σ.1))
        ⟨∑ i : Fin σ.1, (matVecGrade σ (mvEnc σ) (fun _ => (((1 : BitVec 8).toInt : ℤ) : ℝ))
          (fun _ => ⟨0, 0⟩) i).err, 0⟩ = ⟨0, 0⟩
    simp only [hc]
    rw [Grade.onlyIf_pos fun (_ : Fin σ.1) =>
      show (σ.2 : ℝ) ≤ (NumFormat.int 8).safeMax from
        show (σ.2 : ℝ) ≤ 2 ^ (8 - 1) - 1 by norm_num; exact_mod_cast hn]
    simp
  refine (Approx.eq_some ?_ ?_ (hg ▸ h)).trans ?_
  · exact le_rfl
  · exact sub_nonneg.2 (one_le_pow₀ (by norm_num))
  · show some (∑ i : Fin σ.1, ∑ k : Fin σ.2,
      (((1 : BitVec 8).toInt : ℤ) : ℝ) * (((1 : BitVec 8).toInt : ℤ) : ℝ)) = _
    rw [h1]
    simp

/-- One output of one test composition (`mvSum`), at every size `(m, n)` with `n ≤ 127`: with the
behaviors `ruleK` and input words `1`, the word `m n` of `8 + m` bits is an output of the
composition and decodes to `m n`. Its intermediate is the product's outputs, the words `n` of
8 bits: words that decode to the exact product meet `GPUProof.matVecGrade`'s rule at 8-bit
formats throughout (`GPUProof.laneVecGrade_holds`), and the word `m n`, which fits `8 + m` bits as
`m n ≤ 127 m` (`toInt_ofInt_fits`), meets `sumEx`'s `exact` rule at them
(`GPUProof.FloatRule.Holds.exact_of`); `GPUProof.Wiring.mem_behav` joins the two. -/
theorem mvSum_ones_mem (σ : ℕ × ℕ) (hn : σ.2 ≤ 127) :
    (fun _ => BitVec.ofInt (8 + σ.1) (σ.1 * σ.2 : ℕ)) ∈
        mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut σ (mvSum.encs mvEnc noEx sumOut σ)
          (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim) ∧
      (sumOut σ).decode (fun _ => BitVec.ofInt (8 + σ.1) (σ.1 * σ.2 : ℕ)) () =
        some ((σ.1 * σ.2 : ℕ) : ℝ) := by
  have h1 : (((1 : BitVec 8).toInt : ℤ) : ℝ) = 1 := by
    rw [show (1 : BitVec 8).toInt = 1 by decide]
    norm_num
  have hV : ((BitVec.ofInt 8 (σ.2 : ℤ)).toInt : ℤ) = σ.2 :=
    BitVec.toInt_ofInt_eq_self (by norm_num) (by norm_num) (by norm_num; omega)
  have hF : (BitVec.ofInt (8 + σ.1) ((σ.1 * σ.2 : ℕ) : ℤ)).toInt = ((σ.1 * σ.2 : ℕ) : ℤ) := by
    have h₀ : (0 : ℤ) ≤ ((σ.1 * σ.2 : ℕ) : ℤ) := by positivity
    have h₁ : (0 : ℤ) ≤ 128 * (σ.1 : ℤ) := by positivity
    refine toInt_ofInt_fits σ.1 (by linarith) ?_
    push_cast
    nlinarith [(by exact_mod_cast hn : (σ.2 : ℤ) ≤ 127), (Nat.cast_nonneg σ.1 : (0 : ℤ) ≤ σ.1)]
  refine ⟨Wiring.mem_behav mvSum (V := fun _ => BitVec.ofInt 8 (σ.2 : ℤ))
    (laneVecGrade_holds 1 0 id (Y := fun _ => (1 : ℝ))
      (fun _ => congrArg some h1) fun o => ?_)
    (FloatRule.Holds.exact_of (Y := fun _ => (σ.2 : ℝ)) (fun _ => ?_) fun _ => ?_), ?_⟩
  · show some (((BitVec.ofInt 8 (σ.2 : ℤ)).toInt : ℤ) : ℝ) = some (∑ k : Fin σ.2, (1 : ℝ) * 1)
    rw [hV]
    simp
  · show some (((BitVec.ofInt 8 (σ.2 : ℤ)).toInt : ℤ) : ℝ) = some (σ.2 : ℝ)
    rw [hV]
    rfl
  · show some (((BitVec.ofInt (8 + σ.1) ((σ.1 * σ.2 : ℕ) : ℤ)).toInt : ℤ) : ℝ) =
      some (∑ _ : Fin σ.1, (σ.2 : ℝ))
    rw [hF]
    simp
  · show some (((BitVec.ofInt (8 + σ.1) ((σ.1 * σ.2 : ℕ) : ℤ)).toInt : ℤ) : ℝ) = _
    rw [hF]
    rfl

-- `mvSum_ones_mem` and `mvSum_ones` at size `(2, 3)`: the composition has an output, and every
-- output word decodes to `6`.
example :
    (∃ W' ∈ mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut (2, 3)
        (mvSum.encs mvEnc noEx sumOut (2, 3)) (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim),
      (sumOut (2, 3)).decode W' () = some (6 : ℝ)) ∧
    ∀ W' ∈ mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut (2, 3)
        (mvSum.encs mvEnc noEx sumOut (2, 3)) (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim),
      (sumOut (2, 3)).decode W' () = some (6 : ℝ) :=
  ⟨⟨_, (mvSum_ones_mem (2, 3) (by decide)).1,
    (mvSum_ones_mem (2, 3) (by decide)).2.trans (by norm_num)⟩,
    fun W' hW' => (mvSum_ones (2, 3) (by decide) W' hW').trans (by norm_num)⟩

-- The same at size `(5, 1)`: the composition has an output, and every output word decodes to `5`.
example :
    (∃ W' ∈ mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut (5, 1)
        (mvSum.encs mvEnc noEx sumOut (5, 1)) (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim),
      (sumOut (5, 1)).decode W' () = some (5 : ℝ)) ∧
    ∀ W' ∈ mvSum.behav (ruleK _) (ruleK _) mvEnc noEx sumOut (5, 1)
        (mvSum.encs mvEnc noEx sumOut (5, 1)) (fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim),
      (sumOut (5, 1)).decode W' () = some (5 : ℝ) :=
  ⟨⟨_, (mvSum_ones_mem (5, 1) (by decide)).1,
    (mvSum_ones_mem (5, 1) (by decide)).2.trans (by norm_num)⟩,
    fun W' hW' => (mvSum_ones (5, 1) (by decide) W' hW').trans (by norm_num)⟩

/-- One test mutant (a modulus too small): the grade of error `0` and magnitude `0`, at every
size, encoding, exact inputs and grades. -/
noncomputable def sumZero : ∀ σ, sumEx.Encs σ → Ents (sumEx.In σ) (sumEx.dIn σ) →
    (sumEx.In σ → Grade) → sumEx.Out σ → Grade :=
  fun _ _ _ _ _ => ⟨0, 0⟩

/-- One test mutant (a modulus too small): `sumZero` is not a modulus of `sumEx` at size `(1, 1)`
along `mvSum` with `sumOut`. The one input word `1` decodes to `1`, within grade `⟨1, 0⟩` of the
exact input `0`, and the sum `1` is not within `0` of the sum `0`. -/
theorem sumZero_refused :
    ¬ sumEx.Modulus sumZero (1, 1) (mvSum.encs₂ mvEnc noEx sumOut (1, 1)) := by
  intro h
  have h1 : (((1 : BitVec 8).toInt : ℤ) : ℝ) = 1 := by
    rw [show (1 : BitVec 8).toInt = 1 by decide]
    norm_num
  have hw : (mvSum.encs₂ mvEnc noEx sumOut (1, 1)).inp.Within (fun _ => ⟨1, 0⟩)
      (fun _ => (0 : ℝ)) (fun _ => (((1 : BitVec 8).toInt : ℤ) : ℝ)) :=
    ⟨⟨fun | .inl _ => (1 : BitVec 8) | .inr e => e.elim, fun _ => rfl⟩,
      fun _ => ⟨show (0 : ℝ) ≤ 2 ^ (8 - 1) - 1 by norm_num, _, rfl, by rw [h1]; norm_num⟩⟩
  have h0 : |∑ _ : Fin 1, (((1 : BitVec 8).toInt : ℤ) : ℝ) - ∑ _ : Fin 1, (0 : ℝ)| ≤ 0 :=
    near_real (h.near _ _ _ trivial hw ())
  rw [h1] at h0
  norm_num at h0

/-- One test encoding of `GPUProof.Spec.matVec` at two widths (`wideEnc`), at every size: every
input stored by `fixEnc 8` and every output by `fixEnc 16`. -/
noncomputable def wideEnc (σ : ℕ × ℕ) : (Spec.matVec matVecGrade matVecGrade_mono).Encs σ :=
  ⟨.ofScalars fun _ => fixEnc 8, .ofScalars fun _ => fixEnc 16⟩

/-- **Exact words meet `GPUProof.matVecGrade`'s rule at `wideEnc`**, at size `(1, 1)`: the input
words `100` of 8 bits and the output word `10000` of 16 bits, the exact product, above the
inputs' largest value `127` (`GPUProof.laneVecGrade_holds`, no premise on the formats). An input
grade of magnitude above `127` gives no premise on its word, and the output's grade claims
nothing there (`GPUProof.laneGradeIn`). -/
theorem wide_holds :
    (Spec.matVec matVecGrade matVecGrade_mono).rule.Holds (1, 1) (wideEnc (1, 1))
      (fun _ => (100 : BitVec 8)) fun _ => (10000 : BitVec 16) := by
  refine laneVecGrade_holds 1 0 id (Y := fun _ => (100 : ℝ)) (fun _ => ?_) fun _ => ?_
  · show some (((100 : BitVec 8).toInt : ℤ) : ℝ) = some 100
    rw [show (100 : BitVec 8).toInt = 100 by decide]
    norm_num
  · show some (((10000 : BitVec 16).toInt : ℤ) : ℝ) = some (∑ _ : Fin 1, (100 : ℝ) * 100)
    rw [show (10000 : BitVec 16).toInt = 10000 by decide]
    norm_num

/-- **The same at size `(2, 5)`**: the input words `50` of 8 bits and the output words `12500` of
16 bits, the exact product `5 · 50 · 50` at each output, meet `GPUProof.matVecGrade`'s rule at
`wideEnc` (`GPUProof.laneVecGrade_holds`). -/
theorem wide_holds_2x5 :
    (Spec.matVec matVecGrade matVecGrade_mono).rule.Holds (2, 5) (wideEnc (2, 5))
      (fun _ => (50 : BitVec 8)) fun _ => (12500 : BitVec 16) := by
  refine laneVecGrade_holds 1 0 id (Y := fun _ => (50 : ℝ)) (fun _ => ?_) fun _ => ?_
  · show some (((50 : BitVec 8).toInt : ℤ) : ℝ) = some 50
    rw [show (50 : BitVec 8).toInt = 50 by decide]
    norm_num
  · show some (((12500 : BitVec 16).toInt : ℤ) : ℝ) = some (∑ _ : Fin 5, (50 : ℝ) * 50)
    rw [show (12500 : BitVec 16).toInt = 12500 by decide]
    norm_num

/-- **The same for `GPUProof.Spec.vecMat`, at size `(5, 2)`**: at 8-bit inputs and 16-bit
outputs (`fixEnc 8` and `fixEnc 16`), the input words `50` and the output words `12500`, the exact
product `5 · 50 · 50` at each of the two columns, meet `GPUProof.vecMatGrade`'s rule
(`GPUProof.vecMatLaneGrade_holds`, no premise on the formats). -/
theorem wide_vecMat :
    (Spec.vecMat vecMatGrade vecMatGrade_mono).rule.Holds (5, 2)
      ⟨.ofScalars fun _ => fixEnc 8, .ofScalars fun _ => fixEnc 16⟩
      (fun _ => (50 : BitVec 8)) fun _ => (12500 : BitVec 16) := by
  refine vecMatLaneGrade_holds 1 0 id (Y := fun _ => (50 : ℝ)) (fun _ => ?_) fun _ => ?_
  · show some (((50 : BitVec 8).toInt : ℤ) : ℝ) = some 50
    rw [show (50 : BitVec 8).toInt = 50 by decide]
    norm_num
  · show some (((12500 : BitVec 16).toInt : ℤ) : ℝ) = some (∑ _ : Fin 5, (50 : ℝ) * 50)
    rw [show (12500 : BitVec 16).toInt = 12500 by decide]
    norm_num

-- So `ruleK`, a behavior that meets `GPUProof.Spec.matVec` at `GPUProof.matVecGrade` at every
-- encoding (`ruleK_meets`), has an output at `wideEnc` at size `(1, 1)`: the word `10000`
-- (`wide_holds`).
example : Meets (Spec.matVec matVecGrade matVecGrade_mono) (ruleK _) ∧
    (fun _ => (10000 : BitVec 16)) ∈ ruleK (Spec.matVec matVecGrade matVecGrade_mono) (1, 1)
      (wideEnc (1, 1)) (fun _ => (100 : BitVec 8)) :=
  ⟨ruleK_meets _, wide_holds⟩

/-- One test mutant of `GPUProof.matVecGrade` with the output's guard only (`rawGrade`), at every
size, encoding, exact inputs, grades and output `i`: `GPUProof.dotGrade` of row `i` and the
vector, of length `n`, in output `i`'s format, with no guard on the input grades' magnitudes; it
claims wherever its magnitude is at most the output format's largest value (`GPUProof.Approx`). -/
noncomputable def rawGrade :
    RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  fun σ E A G i => dotGrade (E.out.fmt i) σ.2 (fun k => A (.inl (i, k))) (fun k => A (.inr k))
    (fun k => G (.inl (i, k))) (fun k => G (.inr k))

/-- `rawGrade` grows with the inputs' grades, at every size, encoding and exact inputs
(`GPUProof.dotGrade_mono`). -/
theorem rawGrade_mono : ∀ σ E A, Monotone (rawGrade σ E A) :=
  fun _ _ _ _ _ h _ => dotGrade_mono _ _ _ _ (fun _ => h _) (fun _ => h _)

/-- **The mutant: without the inputs' guard no words meet the rule at `wideEnc`.** At size
`(1, 1)`, for every input words `X` and output word `X'`, `X'` does not meet `rawGrade`'s rule.
At input grades of error `0` and magnitude `200`, above the 8-bit inputs' largest value `127`, the
rule has no premise on the inputs, while the output's grade, of error `0` and magnitude `200`, at
most the 16-bit output's `32767`, claims the exact product: the exact inputs `0` make the output
`0`, and the exact inputs `1` make it `1`. So a behavior that meets `rawGrade` at every encoding
has no output there, while `GPUProof.matVecGrade`'s rule is met (`wide_holds`). -/
theorem wide_refused (X : (wideEnc (1, 1)).inp.Words) (X' : (wideEnc (1, 1)).out.Words) :
    ¬ (Spec.matVec rawGrade rawGrade_mono).rule.Holds (1, 1) (wideEnc (1, 1)) X X' := by
  intro h
  have hv : ∀ a : ℝ, a = 0 ∨ a = 1 → (wideEnc (1, 1)).out.decode X' (0 : Fin 1) = some a := by
    intro a ha
    have hf : (wideEnc (1, 1)).out.fmt (0 : Fin 1) = .int 16 := rfl
    have hg : rawGrade (1, 1) (wideEnc (1, 1)) (fun _ => a) (fun _ => ⟨0, 200⟩) (0 : Fin 1) =
        ⟨0, 200⟩ := by
      rcases ha with rfl | rfl <;>
        simp [rawGrade, dotGrade, laneGrade, Grade.pos, hf, NumFormat.roundoff,
          NumFormat.underflow]
    have h0 := h (fun _ => a) (fun _ => ⟨0, 200⟩) trivial
      (fun _ hm => absurd (show (200 : ℝ) ≤ (NumFormat.int 8).safeMax from hm)
        (by norm_num [NumFormat.safeMax])) (0 : Fin 1)
    refine (Approx.eq_some (g := ⟨0, 200⟩) le_rfl
      (show (200 : ℝ) ≤ (NumFormat.int 16).safeMax by norm_num [NumFormat.safeMax])
      (hg ▸ h0)).trans ?_
    rcases ha with rfl | rfl <;> simp [Spec.matVec, Spec.ofReal, Matrix.mulVec, dotProduct]
  have e := (hv 0 (.inl rfl)).symm.trans (hv 1 (.inr rfl))
  norm_num at e

end MojoProofTest.GPUProof.SpecCompGraded
