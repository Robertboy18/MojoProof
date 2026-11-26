import GPUProof.Spec.Comp
import GPUProof.Spec.DecEq
import GPUProof.Spec.Linear
import FloatLib.Floats.Formats.BinaryInterchange.Format.Catalog
import FloatLib.Floats.Formats.BinaryInterchange.DirectedSemantics.Basic

/-!
# Two specs composed along a wiring, on test specs

* Copy specs with a graded rule (`copyG I g mono`: at every size the inputs `I σ` as outputs, all
  real, the identity, meant everywhere) and the behaviors that output words decoding as the input
  words do (`sameK`). At the identity grade (`idGrade`) `sameK` meets `copyG` at every encodings
  whose input and output formats agree (`sameK_meets`).
* Where the magnitude condition belongs. At one input stored in a binary interchange format with
  IEEE encoding, if `sameK`, which keeps a NaN a NaN, meets `copyG` at grade `g`, then `g` has an
  output magnitude above the format's `GPUProof.NumFormat.safeMax` wherever the input's is
  (`nan_needs_mag`): at a NaN input the input's `GPUProof.Approx` holds by its magnitude premise,
  and the output's must too. A grade with magnitude `0` (`forget`) is monotone, and `sameK` does
  not meet it (`forget_refused`), while it meets the identity grade (`id_meets`). So the bound of
  an input's magnitude by an output's (`GPUProof.laneGrade_mag`) is a condition for one kernel that
  keeps NaNs to meet one graded rule; `GPUProof.MeetsAt.comp` composes two graded rules without
  it.
* Two copies at binary32 wired with no extra input (`chain`): every premise of
  `GPUProof.MeetsAt.comp` is discharged (`chain_meets`), and the composite's grade is the input's
  (`chain_grade`).
* The design's `D = A·x + e` (`dax`): `GPUProof.Spec.matVec` at `GPUProof.matVecGrade` wired into
  the entrywise sum of two vectors (`vecAdd`, at the test grade `addGrade`) with `e` as the extra
  input. The composite's function is `A.mulVec x + e` (`dax_f`), its domain is the product's
  (`dax_domOk`, `dax_dom`), its grade at output `i` is `addGrade` at `GPUProof.matVecGrade`'s
  grade of row `i` and `e i`'s (`dax_grade`), and every behaviors meeting the two specs, at the
  uniform binary32 storage of the product and every encodings of `e` and of the outputs, meet the
  composite (`dax_meets`).
* A wiring with a mismatched type is refused: no wiring feeds the integer output of
  `GPUProof.Spec.sumInt` into a real input of `copyG Fin` (`int_real_refused`).
* Two `exact` rules (`GPUProof.MeetsAt.comp_exact`). `n` integers copied (`copyInt`) into
  `GPUProof.Spec.sumInt` (`copySum`): the input words are the intermediate's, so
  `GPUProof.Wiring.MidRep` holds at every size and storage (`copySum_rep`, `copySum_meets`), and
  with 32-bit integers the composition of the behaviors that allow every output their rule allows
  (`ruleK`) gives the sum `6` at size 3 and `-7` at size 7 (the two `example`s after
  `copySum_meets`); with 32-bit integers at size 2, `decide` decides the composite's whole output
  words, whose positions instance search finds finite (`copySum_outWords`). The mutant:
  `GPUProof.Spec.sumInt` into a negation (`negInt`, `sumNeg`) with 32-bit integers, where at size
  2 and inputs `2 ^ 30` the sum has no 32-bit word and its negation has one; there `ruleK`'s
  composition does not meet the composite (`sumNeg_refused`), so `GPUProof.Wiring.MidRep` fails
  (`sumNeg_norep`). These tests are stated for every binary interchange format, which integer
  entries do not read.
* At every encoding (`GPUProof.Meets.comp`, `GPUProof.Meets.comp_exact`, the behavior
  `GPUProof.Wiring.behavMid`): `ruleK` after `ruleK` along `chain`, at every encoding of the
  intermediate (`chain_meetsAll`); along `copySum` with the intermediate encoded as the
  composite's inputs, where `GPUProof.Wiring.MidRep` holds at every composite encoding
  (`copySum_repAll`, `copySum_meetsAll`); and along `sumNeg` with the intermediate stored as a
  32-bit integer, where the composition does not meet the composite at every encoding
  (`sumNeg_refusedAll`, through the steps `sumInt_none`, `negInt_zero` and `sumNeg_fails` that
  `sumNeg_refused` uses too).
* An `exact` rule then a graded one (`GPUProof.MeetsAt.comp_exact_graded`,
  `GPUProof.Meets.comp_exact_graded`). `n` integers copied (`copyInt`) into their negations with a
  graded rule (`negG Fin`, at the grade `sameGrade`), wired by `copyNegG`: the input words are the
  intermediate's, so `GPUProof.Wiring.FstRep` holds at every size and storage (`copyNegG_rep`,
  `copyNegG_meets`) and at every encoding (`copyNegG_repAll`, `copyNegG_meetsAll`); at exact
  input grades the composite's grade is `⟨0, 0⟩` (`copyNegG_grade`). With 32-bit integers at
  size 3, the input words `1, 2, 3` and input grades `⟨0, 0⟩`, every output word of `ruleK`'s
  composition decodes to `-1, -2, -3` (the `example` after `copyNegG_grade`). The mutant:
  `GPUProof.Spec.sumInt` into the graded negation (`sumNegG`) with 32-bit integers, at size 2 and
  inputs `2 ^ 30`, where `ruleK`'s composition does not meet the composite at its encodings
  (`sumNegG_refused`) or at every encoding (`sumNegG_refusedAll`), through the steps
  `sumInt_none`, `negG_zero` and `sumNegG_fails`; so `GPUProof.Wiring.FstRep` fails
  (`sumNegG_norep`).
* Pairs with a `bitwise` rule, at every size and storage `u` of the integers, with the
  behaviors `ruleK`'s compositions in the two `example`s after each at 32-bit integers, size 3
  (words `1, 2, 3`) and size 7 (seven words `-1`). `n` integers copied by `copyBit u` (`bitwise`
  at `copyInt`'s uniform encodings, the identity word function) into `GPUProof.Spec.sumInt` along
  `bitSum`, with no representability premise (`bitSum_meets`,
  `GPUProof.MeetsAt.comp_bitwise_exact`); `copyInt` into `copyW u` (`bitwise` at the wired
  encodings `wiredEncs u`, the word function that reads the wired position) along `copyCp`, where
  the input words are the intermediate's (`copyCp_rep`, `copyCp_meets`,
  `GPUProof.MeetsAt.comp_exact_bitwise`); and `copyBit u` into `copyW u` along `bitCp`, into the
  `bitwise` rule of the composed word functions (`bitCp_meets`, `GPUProof.MeetsAt.comp_bitwise`).
* Pairs with a `bitwise` rule at one integer entry stored by `nanInt` (the word `0` with the
  value `0` and the NaN words `1`, `2`), copied by `nanId` with the `bitwise` rule at `nanEncs`
  and the identity word function. Into the graded negation along `nanIdNeg`, `ruleK`'s
  composition meets the composite with the graded rule `GPUProof.Wiring.gradeEx` at every size
  (`nanIdNeg_meets`, `GPUProof.MeetsAt.comp_bitwise_graded`). Into `nanCp` (`bitwise` at
  `nanEncs₂`, the word function that reads the first position) along `nanIdCp`, it meets the
  composite with the `bitwise` rule of the composed word functions at every size
  (`nanIdCp_meets`). Into a copy with the `bitwise` rule at `nanEncs₂` and the word function
  `squash` (`nanSq`, `squash_dec`), which maps the two NaNs to `0` and `1` (`squash_nanEq`), along
  `nanIdSq`: at size 0 `ruleK`'s composition does not meet the composite with the `bitwise` rule
  of the composed word functions (`nanIdSqW`, `nanIdSqW_dec`, `nanIdSq_refused`), so `squash`
  does not keep words equal up to NaN payloads (`nanIdSq_noresp`), the premise of
  `GPUProof.MeetsAt.comp_bitwise`.
* The mutant for `GPUProof.MeetsAt.comp_exact_bitwise`'s representability premise: `negInt` with
  its input a 32-bit integer and its output stored by `nanInt` (`negZE`) into `zeroW` (`bitwise`
  at `zeroEncs₂`, the constant word `0`, `zero_dec`) along `negZ`. At size 0 and the input `5`,
  `-5` has no word of `nanInt`, so `negInt`'s rule allows the intermediate word `0`, and the
  composite asks for the 32-bit word of `-5` (`negZ_refused`); so `GPUProof.Wiring.MidRep` fails
  (`negZ_norep`).
-/

open GPUProof
open FloatLib.Floats.Formats.BinaryInterchange (FloatFormat Model)

namespace MojoProofTest.GPUProof.SpecComp

/-- One test spec family (`copyG I g mono`), for every finite index types `I` and grade `g`: at
every size the inputs `I σ` as outputs, all real, the identity, meant everywhere, with the graded
rule `g`. -/
noncomputable def copyG (I : ℕ → Type) [∀ σ, Fintype (I σ)] (g : RealGrades I I)
    (mono : ∀ σ E A, Monotone (g σ E A)) : Spec ℕ :=
  .ofReal I I (fun _ A => A) g mono

/-- One test behavior family, for every index types `I`: at every size and encoding of real
entries `I σ` on both sides, the output words that decode as the input words do. -/
def sameK {I : ℕ → Type} (σ : ℕ)
    (E : Encodings I I (fun _ _ => .real) (fun _ _ => .real) σ) (W : E.inp.Words) :
    Set E.out.Words :=
  {W' | ∀ o, E.out.decode W' o = E.inp.decode W o}

/-- One test grade family (`idGrade`), for every index types `I`: each output's grade is the
input's. -/
def idGrade {I : ℕ → Type} : RealGrades I I := fun _ _ _ G => G

/-- `idGrade` grows with the inputs' grades, for every index types, at every size, encoding and
exact inputs. -/
theorem idGrade_mono {I : ℕ → Type} : ∀ σ E A, Monotone (idGrade (I := I) σ E A) :=
  fun _ _ _ _ _ h => h

/-- One test spec family (`copyG I idGrade`), for every finite index types `I`: `sameK` meets it
at every encodings whose output formats are the input formats. -/
theorem sameK_meets {I : ℕ → Type} [∀ σ, Fintype (I σ)]
    (E : ∀ σ, Encodings I I (fun _ _ => .real) (fun _ _ => .real) σ)
    (hE : ∀ σ o, (E σ).out.fmt o = (E σ).inp.fmt o) :
    MeetsAt (copyG I idGrade idGrade_mono) sameK E := by
  intro σ W W' hW' A G _ hG o
  rw [hW' o, hE σ o]
  exact hG o

/-- One test storage family, for every binary interchange format `fmt` and index types `I`: at
every size every entry of `I σ` on both sides stored in `fmt`. -/
noncomputable def ieeeEnc (fmt : FloatFormat) (I : ℕ → Type) (σ : ℕ) :
    Encodings I I (fun _ _ => .real) (fun _ _ => .real) σ :=
  ⟨.ofScalars fun _ => .ieee fmt, .ofScalars fun _ => .ieee fmt⟩

/-- **A NaN-keeping behavior meets a graded rule only at the magnitude condition**, at one input,
for every binary interchange format `fmt` with IEEE encoding, grade `g`, size, exact input and
input grade: if `sameK` meets `copyG` at grade `g` with the entry stored in `fmt`, then `g`'s
magnitude is above `fmt`'s `GPUProof.NumFormat.safeMax` wherever the input grade's is. The
canonical NaN meets the input's `GPUProof.Approx` at such an input grade, `sameK` allows it as the
output, and it decodes to no value. -/
theorem nan_needs_mag {fmt : FloatFormat} (hfmt : fmt.encoding = .ieee)
    {g : RealGrades (fun _ => Unit) fun _ => Unit} {mono : ∀ σ E A, Monotone (g σ E A)}
    (h : MeetsAt (copyG (fun _ => Unit) g mono) sameK (ieeeEnc fmt _)) (σ : ℕ) (A : Unit → ℝ)
    (G : Unit → Grade) (hG : NumFormat.safeMax (.ieee fmt) < (G ()).mag) :
    NumFormat.safeMax (.ieee fmt) < (g σ (ieeeEnc fmt _ σ) A G ()).mag := by
  have hnan : (Model.canonicalNaN fmt).toReal? = none :=
    (ScalarEnc.ieee fmt).decode_isNaN (Model.canonicalNaN fmt) (Model.isNaN_canonicalNaN hfmt)
  have H := h σ (fun _ => Model.canonicalNaN fmt) (fun _ => Model.canonicalNaN fmt)
    (fun _ => rfl) A G trivial (fun _ hle => absurd hle (not_le.2 hG)) ()
  by_contra hle
  obtain ⟨r, hr, -⟩ := H (not_lt.1 hle)
  exact Option.some_ne_none r (hr.symm.trans hnan)

/-- One test grade (`forget`), at one input and every size and encoding: the input grade's error
and magnitude `0`, so it does not bound the input's magnitude. -/
def forget : RealGrades (fun _ : ℕ => Unit) fun _ => Unit := fun _ _ _ G _ => ⟨(G ()).err, 0⟩

/-- `forget` grows with the input's grade, at every size, encoding and exact input. -/
theorem forget_mono : ∀ σ E A, Monotone (forget σ E A) :=
  fun _ _ _ _ _ h _ => ⟨(h ()).1, le_rfl⟩

/-- One test spec (`copyG` at one input and the grade `forget`), for every binary interchange
format `fmt` with IEEE encoding: `sameK` does not meet it with the entry stored in `fmt`
(`nan_needs_mag` at an input grade of magnitude `safeMax + 1`). -/
theorem forget_refused {fmt : FloatFormat} (hfmt : fmt.encoding = .ieee) :
    ¬ MeetsAt (copyG (fun _ => Unit) forget forget_mono) sameK (ieeeEnc fmt _) := fun h =>
  absurd (nan_needs_mag hfmt h 0 (fun _ => 0) (fun _ => ⟨0, NumFormat.safeMax (.ieee fmt) + 1⟩)
    (lt_add_one _)) (not_lt.2 (Model.toReal_posMaxFinite_nonneg fmt))

/-- One test spec (`copyG` at one input and `idGrade`), for every binary interchange format
`fmt`: `sameK` meets it with the entry stored in `fmt` (`sameK_meets`). -/
theorem id_meets (fmt : FloatFormat) :
    MeetsAt (copyG (fun _ => Unit) idGrade idGrade_mono) sameK (ieeeEnc fmt _) :=
  sameK_meets _ fun _ _ => rfl

/-- One test wiring (`chain`): at every size `n`, the `n` outputs of `copyG Fin idGrade` into the
`n` inputs of another, with no extra input. -/
def chain : Wiring (copyG Fin idGrade idGrade_mono) (copyG Fin idGrade idGrade_mono) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test encoding family: at every size, the encoding of no extra input. -/
def noExtra (n : ℕ) : Encoding (chain.Extra n) (chain.dEx n) := .ofScalars fun e => Empty.elim e

/-- One test composition (`chain`), at every size with every entry stored in binary32: `sameK`
after `sameK` meets the composite of `copyG Fin idGrade` with itself, every premise of
`GPUProof.MeetsAt.comp` discharged (`sameK_meets` twice). -/
theorem chain_meets :
    MeetsAt (chain.spec (.graded (chain.grade (ieeeEnc .binary32 Fin) noExtra idGrade idGrade)
        (chain.grade_mono _ _ idGrade_mono idGrade_mono)))
      (chain.behav sameK sameK (ieeeEnc .binary32 Fin) noExtra fun n =>
        (ieeeEnc .binary32 Fin n).out)
      (chain.encs (ieeeEnc .binary32 Fin) noExtra fun n => (ieeeEnc .binary32 Fin n).out) :=
  MeetsAt.comp chain rfl rfl _ _ _ (sameK_meets _ fun _ _ => rfl) (sameK_meets _ fun _ _ => rfl)

/-- One test composition (`chain`): at every size, encoding, exact inputs, input grades and
output, the composite's grade is the grade of the input wired to it. -/
theorem chain_grade (n : ℕ) (E : chain.Encs n) (Z : Ents (chain.In n) (chain.dIn n))
    (G : chain.In n → Grade) (o : Fin n) :
    chain.grade (ieeeEnc .binary32 Fin) noExtra idGrade idGrade n E Z G o = G (.inl o) :=
  rfl

/-- One test grade (`addGrade`) of the entrywise sum of two vectors of length `m`, at every size
`(m, n)` and encoding: at output `i`, the sums of the two inputs' grades' errors and magnitudes. It
is not a proved bound of any kernel. -/
def addGrade : RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1) fun σ => Fin σ.1 :=
  fun _ _ _ G i => ⟨(G (.inl i)).err + (G (.inr i)).err, (G (.inl i)).mag + (G (.inr i)).mag⟩

/-- `addGrade` grows with the inputs' grades, at every size, encoding and exact inputs. -/
theorem addGrade_mono : ∀ σ E A, Monotone (addGrade σ E A) :=
  fun _ _ _ _ _ h _ => ⟨add_le_add (h _).1 (h _).1, add_le_add (h _).2 (h _).2⟩

/-- One test spec (`vecAdd`), at every size `(m, n)`: the entries `inl i` of `y` and `inr i` of
`e`, two real vectors of length `m`, the outputs `y i + e i`, meant everywhere, with the graded
rule `addGrade`. -/
noncomputable def vecAdd : Spec (ℕ × ℕ) :=
  .ofReal (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1) (fun σ => Fin σ.1)
    (fun _ X i => X (.inl i) + X (.inr i)) addGrade addGrade_mono

/-- One test wiring (`dax`, the design's `D = A·x + e`), at every size `(m, n)`: the `m` outputs
of `GPUProof.Spec.matVec` at `GPUProof.matVecGrade` into the inputs `y` of `vecAdd`, and the
vector `e` of length `m` as the extra inputs. -/
noncomputable def dax : Wiring (Spec.matVec matVecGrade matVecGrade_mono) vecAdd where
  Extra σ := Fin σ.1
  dEx _ _ := .real
  wire _ := Equiv.refl _
  types _ i := by cases i <;> rfl

/-- One test composition (`dax`): at every size `(m, n)` the composite's function is
`A.mulVec x + e`, the composite inputs `inl (inl (i, k))` the matrix `A`, `inl (inr k)` the
vector `x` and `inr i` the vector `e`. -/
theorem dax_f (σ : ℕ × ℕ) (Z : Ents (dax.In σ) (dax.dIn σ)) :
    dax.f σ Z = fun i => Matrix.mulVec (Matrix.of fun i k => (Z (.inl (.inl (i, k))) : ℝ))
      (fun k => (Z (.inl (.inr k)) : ℝ)) i + show ℝ from Z (.inr i) :=
  rfl

/-- One test composition (`dax`): `GPUProof.Spec.matVec` maps its domain into `vecAdd`'s at
every size and extra input (`GPUProof.Wiring.DomOk`), both domains being everything, so the
composite's domain is the product's (`GPUProof.Wiring.dom_iff`). -/
theorem dax_domOk : dax.DomOk := fun _ _ _ _ => trivial

/-- One test composition (`dax`): at every size every composite input is in the composite's
domain, by `GPUProof.Wiring.dom_iff` at `dax_domOk`. -/
theorem dax_dom (σ : ℕ × ℕ) (Z : Ents (dax.In σ) (dax.dIn σ)) : dax.Dom σ Z :=
  (dax.dom_iff dax_domOk σ Z).2 trivial

/-- One test composition (`dax`), at every encodings `E₁` of the product and `Ex` of `e`, size,
encoding, exact inputs, input grades and output `i`: the composite's grade is `addGrade` at
`GPUProof.matVecGrade`'s grade of row `i` and `e i`'s grade, so its error is their errors'
sum. -/
theorem dax_grade (E₁ : ∀ σ, (Spec.matVec matVecGrade matVecGrade_mono).Encs σ)
    (Ex : ∀ σ, Encoding (dax.Extra σ) (dax.dEx σ)) (σ : ℕ × ℕ) (E : dax.Encs σ)
    (Z : Ents (dax.In σ) (dax.dIn σ)) (G : dax.In σ → Grade) (i : Fin σ.1) :
    (dax.grade E₁ Ex matVecGrade addGrade σ E Z G i).err =
      (matVecGrade σ (E₁ σ) (fun j => Z (.inl j)) (fun j => G (.inl j)) i).err +
        (G (.inr i)).err :=
  rfl

/-- One test composition (`dax`), for every behaviors `k₁` of `GPUProof.Spec.matVec` at
`GPUProof.matVecGrade` and `k₂` of `vecAdd`, every encodings `Ex` of `e` and `Eo` of the outputs:
if `k₁` meets the product with every entry stored in binary32 and `k₂` meets `vecAdd` at the
product's outputs and `Ex` along `dax`, the composition meets the composite
(`GPUProof.MeetsAt.comp`, its rule premises by `rfl`). -/
theorem dax_meets
    {k₁ : ∀ σ (E : (Spec.matVec matVecGrade matVecGrade_mono).Encs σ), E.inp.Words →
      Set E.out.Words}
    {k₂ : ∀ σ (E : vecAdd.Encs σ), E.inp.Words → Set E.out.Words}
    (Ex : ∀ σ, Encoding (dax.Extra σ) (dax.dEx σ))
    (Eo : ∀ σ, Encoding (vecAdd.Out σ) (vecAdd.dOut σ))
    (hk₁ : MeetsAt (Spec.matVec matVecGrade matVecGrade_mono) k₁
      (Encodings.uniform _ (ScalarEnc.std .binary32 32)))
    (hk₂ : MeetsAt vecAdd k₂
      (dax.encs₂ (Encodings.uniform _ (ScalarEnc.std .binary32 32)) Ex Eo)) :
    MeetsAt (dax.spec (.graded (dax.grade (Encodings.uniform _ (ScalarEnc.std .binary32 32)) Ex
        matVecGrade addGrade) (dax.grade_mono _ _ matVecGrade_mono addGrade_mono)))
      (dax.behav k₁ k₂ (Encodings.uniform _ (ScalarEnc.std .binary32 32)) Ex Eo)
      (dax.encs (Encodings.uniform _ (ScalarEnc.std .binary32 32)) Ex Eo) :=
  MeetsAt.comp dax rfl rfl _ Ex Eo hk₁ hk₂

/-- One test mutant (a mismatched type): no wiring feeds the integer output of
`GPUProof.Spec.sumInt` into `copyG Fin idGrade`, since at size `1` the input wired to that output
is real. -/
theorem int_real_refused : IsEmpty (Wiring Spec.sumInt (copyG Fin idGrade idGrade_mono)) := by
  refine ⟨fun w => ?_⟩
  have h := w.types 1 ((w.wire 1).symm (.inl ()))
  rw [Equiv.apply_symm_apply] at h
  cases h

/-- One test behavior family (`ruleK Sp`), for every spec: at every size and encoding, the output
words that meet `Sp`'s rule from the input words, the most that a behavior meeting `Sp` there
allows. -/
def ruleK {Sz : Type} (Sp : Spec Sz) : ∀ σ (E : Sp.Encs σ), E.inp.Words → Set E.out.Words :=
  fun σ E W => {W' | Sp.rule.Holds σ E W W'}

/-- `ruleK Sp` meets `Sp` at every encoding, for every spec: its outputs meet the rule by
definition. -/
theorem ruleK_meets {Sz : Type} (Sp : Spec Sz) : Meets Sp (ruleK Sp) :=
  fun _ _ _ _ h => h

/-- One test spec (`copyInt`), at every size `n`: `n` integer inputs as `n` integer outputs, the
identity, meant everywhere, with the `exact` rule. -/
def copyInt : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .exact

/-- One test wiring (`copySum`): at every size `n`, the `n` outputs of `copyInt` into the `n`
inputs of `GPUProof.Spec.sumInt`, with no extra input. -/
def copySum : Wiring copyInt Spec.sumInt where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test composition (`copySum`), for every storage `u` of each entry type and encoding `Eo`
of the sum: with `copyInt`'s entries stored by `u`, the intermediate is representable where the
composite's rule makes a claim (`GPUProof.Wiring.MidRep`), at every size: the input words
themselves decode to it. -/
theorem copySum_rep (u : (d : DType) → ScalarEnc d)
    (Eo : ∀ n, Encoding (Spec.sumInt.Out n) (Spec.sumInt.dOut n)) :
    copySum.MidRep (copySum.encs (Encodings.uniform _ u) noExtra Eo) fun n =>
      (Encodings.uniform _ u n).out :=
  fun _ W _ hW _ _ => ⟨fun p => W (.inl p), fun o => hW (.inl o)⟩

/-- One test composition (`copySum`), for every storage `u` of each entry type, behaviors `k₁` of
`copyInt` and `k₂` of `GPUProof.Spec.sumInt`, and encoding `Eo` of the sum: if `k₁` meets
`copyInt` with its entries stored by `u` and `k₂` meets the sum at `copyInt`'s outputs along
`copySum` with `Eo`, their composition meets the composite with the `exact` rule
(`GPUProof.MeetsAt.comp_exact`, its representability premise by `copySum_rep`). -/
theorem copySum_meets (u : (d : DType) → ScalarEnc d)
    {k₁ : ∀ n (E : copyInt.Encs n), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ n (E : Spec.sumInt.Encs n), E.inp.Words → Set E.out.Words}
    (Eo : ∀ n, Encoding (Spec.sumInt.Out n) (Spec.sumInt.dOut n))
    (hk₁ : MeetsAt copyInt k₁ (Encodings.uniform _ u))
    (hk₂ : MeetsAt Spec.sumInt k₂ (copySum.encs₂ (Encodings.uniform _ u) noExtra Eo)) :
    MeetsAt (copySum.spec .exact) (copySum.behav k₁ k₂ (Encodings.uniform _ u) noExtra Eo)
      (copySum.encs (Encodings.uniform _ u) noExtra Eo) :=
  MeetsAt.comp_exact copySum rfl rfl _ noExtra Eo (copySum_rep u Eo) hk₁ hk₂

-- `copySum_meets` at two sizes, for every binary interchange format `fmt` (which integer entries
-- do not read), with every entry stored as a 32-bit integer and the behaviors `ruleK`, its
-- premises by evaluation: at size 3 and the input words `1, 2, 3` every output word of the
-- composition decodes to `6`.
example (fmt : FloatFormat) :
    ∀ W' ∈ copySum.behav (ruleK _) (ruleK _) (Encodings.uniform _ (ScalarEnc.std fmt 32))
        noExtra (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 3
        (copySum.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
          (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 3)
        (fun | .inl i => BitVec.ofNat 32 (i.val + 1) | .inr e => e.elim),
      (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) 3).out.decode W' () =
        some (6 : ℤ) := fun W' hW' =>
  (copySum_meets (ScalarEnc.std fmt 32)
    (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out)
    (ruleK_meets _ _) (ruleK_meets _ _) 3 _ W' hW'
    (fun | .inl i => (BitVec.ofNat 32 (i.val + 1)).toInt | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun _ => (6 : BitVec 32), fun _ => rfl⟩ ()).trans rfl

-- The same at size 7 and seven input words `-1`: every output word decodes to `-7`.
example (fmt : FloatFormat) :
    ∀ W' ∈ copySum.behav (ruleK _) (ruleK _) (Encodings.uniform _ (ScalarEnc.std fmt 32))
        noExtra (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 7
        (copySum.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
          (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 7)
        (fun | .inl _ => (-1 : BitVec 32) | .inr e => e.elim),
      (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) 7).out.decode W' () =
        some (-7 : ℤ) := fun W' hW' =>
  (copySum_meets (ScalarEnc.std fmt 32)
    (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out)
    (ruleK_meets _ _) (ruleK_meets _ _) 7 _ W' hW' (fun | .inl _ => (-1 : ℤ) | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun _ => (-7 : BitVec 32), fun _ => rfl⟩ ()).trans rfl

/-- The composite of `copySum` with integers stored in 32 bits, at size 2, by `decide`: its whole
output words `2 ^ 30 + 2 ^ 30` are the words `2 ^ 31`. Instance search finds the composite's
outputs finite (`GPUProof.Wiring.spec.fintypeOut`, from `GPUProof.Spec.sumInt.fintypeOut`), so
Mathlib's `Fintype.decidablePiFintype` decides whole output words. -/
theorem copySum_outWords :
    ((fun _ => (2 ^ 30 + 2 ^ 30 : BitVec 32)) :
      (Encodings.uniform (copySum.spec .exact) (ScalarEnc.std .binary32 32) 2).out.Words) =
      fun _ => (2 ^ 31 : BitVec 32) := by
  decide

/-- One test spec (`negInt`), at every size: one integer input, its negation as the one integer
output, meant everywhere, with the `exact` rule. -/
def negInt : Spec ℕ where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x _ := - x ()
  rule := .exact

/-- One test wiring (`sumNeg`): at every size, the output of `GPUProof.Spec.sumInt` into the input
of `negInt`, with no extra input. -/
def sumNeg : Wiring Spec.sumInt negInt where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- The first step of the mutant (test of one example), for every binary interchange format
`fmt`, input encoding `e` of `GPUProof.Spec.sumInt` at size 2 and words `W` that decode to
`2 ^ 30` at both inputs: the output word `0` meets the sum's `exact` rule with the output stored
as a 32-bit integer, since the sum `2 ^ 31` has no 32-bit word and the rule claims nothing. -/
theorem sumInt_none (fmt : FloatFormat) (e : Encoding (Fin 2) fun _ => .int) (W : e.Words)
    (hW : ∀ i, e.decode W i = some (2 ^ 30 : ℤ)) :
    Spec.sumInt.rule.Holds 2 ⟨e, (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) 2).out⟩ W
      fun _ => (0 : BitVec 32) := by
  intro A hA _ ⟨V₀, hV₀⟩
  obtain rfl : A = fun _ => (2 ^ 30 : ℤ) :=
    funext fun i => Option.some.inj ((hA i).symm.trans (hW i))
  have h₀ : (V₀ () : BitVec 32).toInt = 2 ^ 31 := by
    simpa [Encodings.uniform, Encoding.ofScalars, ScalarEnc.std, ScalarEnc.int, Spec.sumInt,
      Fin.sum_univ_two] using hV₀ ()
  exact absurd (BitVec.toInt_lt (x := V₀ ())) (by omega)

/-- The second step of the mutant (test of one example), for every binary interchange format
`fmt`, input encoding `e` of `negInt` at size 2 and words `X` that decode to `0`: the output word
`0` meets the negation's `exact` rule with the output stored as a 32-bit integer. -/
theorem negInt_zero (fmt : FloatFormat) (e : Encoding Unit fun _ => .int) (X : e.Words)
    (hX : ∀ u, e.decode X u = some (0 : ℤ)) :
    negInt.rule.Holds 2 ⟨e, (Encodings.uniform negInt (ScalarEnc.std fmt 32) 2).out⟩ X
      fun _ => (0 : BitVec 32) := by
  intro A hA _ _ o
  obtain rfl : A = fun _ => (0 : ℤ) := funext fun u => Option.some.inj ((hA u).symm.trans (hX u))
  rfl

/-- The mutant's composite claim fails (test of one example), for every binary interchange format
`fmt`, with every entry stored as a 32-bit integer: at size 2 and the input words `2 ^ 30`, the
output word `0` does not meet the composite's `exact` rule, which asks for the word of
`-2 ^ 31`. -/
theorem sumNeg_fails (fmt : FloatFormat) :
    ¬ (sumNeg.spec .exact).rule.Holds 2
      (sumNeg.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform negInt (ScalarEnc.std fmt 32) n).out) 2)
      (fun | .inl _ => (2 ^ 30 : BitVec 32) | .inr e => e.elim) fun _ => (0 : BitVec 32) := by
  intro h
  have := Option.some.inj (h (fun | .inl _ => (2 ^ 30 : ℤ) | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun _ => (2 ^ 31 : BitVec 32), fun _ => rfl⟩ ())
  change (0 : ℤ) = -(2 ^ 30 + 2 ^ 30) at this
  omega

/-- **Mutant: an intermediate with no word** (test of one example), for every binary interchange
format `fmt` (which integer entries do not read), with every entry stored as a 32-bit integer:
the behaviors `ruleK` meet `GPUProof.Spec.sumInt` and `negInt` (`ruleK_meets`), and their
composition does not meet the composite with the `exact` rule. At size 2 and the input words
`2 ^ 30`, the sum `2 ^ 31` has no 32-bit word, so the sum's rule claims nothing and allows the
intermediate word `0` (`sumInt_none`), whose negation `0` the negation's rule allows
(`negInt_zero`); the composite's function `-2 ^ 31` has a 32-bit word, so its rule asks for it
(`sumNeg_fails`). -/
theorem sumNeg_refused (fmt : FloatFormat) :
    ¬ MeetsAt (sumNeg.spec .exact)
      (sumNeg.behav (ruleK _) (ruleK _) (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        fun n => (Encodings.uniform negInt (ScalarEnc.std fmt 32) n).out)
      (sumNeg.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        fun n => (Encodings.uniform negInt (ScalarEnc.std fmt 32) n).out) := fun h =>
  sumNeg_fails fmt (h 2 _ _ fun hE => by
    obtain rfl : hE = rfl := rfl
    exact ⟨_, sumInt_none fmt _ _ fun _ => rfl, negInt_zero fmt _ _ fun _ => rfl⟩)

/-- **Mutant at every encoding** (test of one example), for every binary interchange format `fmt`
(which integer entries do not read), with the intermediate stored as a 32-bit integer at every
composite encoding: `ruleK` after `ruleK` along `sumNeg` (`GPUProof.Wiring.behavMid`) does not
meet the composite with the `exact` rule at every encoding. At the encodings of `sumNeg_refused`,
size 2 and the input words `2 ^ 30`, the same intermediate word `0` and output word `0` are
allowed (`sumInt_none`, `negInt_zero`) and refused (`sumNeg_fails`). So
`GPUProof.Meets.comp_exact`'s representability premise is needed. -/
theorem sumNeg_refusedAll (fmt : FloatFormat) :
    ¬ Meets (sumNeg.spec .exact) (sumNeg.behavMid (ruleK _) (ruleK _) fun n _ =>
      (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) := fun h =>
  sumNeg_fails fmt (h (sumNeg.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
      fun n => (Encodings.uniform negInt (ScalarEnc.std fmt 32) n).out) 2 _ _
    ⟨_, sumInt_none fmt _ _ fun _ => rfl, negInt_zero fmt _ _ fun _ => rfl⟩)

/-- The mutant's intermediate is not representable where the composite's rule makes a claim
(`GPUProof.Wiring.MidRep` fails for `sumNeg`), for every binary interchange format `fmt`, with
every entry stored as a 32-bit integer: `GPUProof.MeetsAt.comp_exact` would otherwise contradict
`sumNeg_refused`. So its representability premise is needed. -/
theorem sumNeg_norep (fmt : FloatFormat) :
    ¬ sumNeg.MidRep (sumNeg.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
      fun n => (Encodings.uniform negInt (ScalarEnc.std fmt 32) n).out) fun n =>
        (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out := fun hr =>
  sumNeg_refused fmt (MeetsAt.comp_exact sumNeg rfl rfl _ _ _ hr (ruleK_meets _ _)
    (ruleK_meets _ _))

/-- One test composition (`chain`) at every encoding, for every encodings `M` of the intermediate
chosen at each composite encoding: `ruleK` after `ruleK` with `M` meets the composite of
`copyG Fin idGrade` with itself at every encoding, with the grade `GPUProof.Wiring.gradeBy`
(`GPUProof.Meets.comp`, its premises by `ruleK_meets` twice). -/
theorem chain_meetsAll (M : ∀ n, chain.Encs n → Encoding (Fin n) fun _ => .real) :
    Meets (chain.spec (.graded (chain.gradeBy (chain.fstEncs M) chain.exEnc idGrade idGrade)
        (chain.gradeBy_mono _ _ idGrade_mono idGrade_mono)))
      (chain.behavMid (ruleK _) (ruleK _) M) :=
  Meets.comp chain rfl rfl M (ruleK_meets _) (ruleK_meets _)

/-- One test composition (`copySum`) at every encoding: with the intermediate encoded as the
composite's inputs (`GPUProof.Encoding.comap` at `Sum.inl`), it is representable where the
composite's rule makes a claim at every composite encoding (`GPUProof.Wiring.MidRep`): the input
words themselves decode to it. -/
theorem copySum_repAll (E : ∀ n, copySum.Encs n) :
    copySum.MidRep E fun n => (E n).inp.comap Sum.inl :=
  fun _ W _ hW _ _ => ⟨W, fun o => hW (.inl o)⟩

/-- One test composition (`copySum`) at every encoding: with the intermediate encoded as the
composite's inputs, `ruleK` after `ruleK` meets the composite with the `exact` rule at every
encoding (`GPUProof.Meets.comp_exact`, its representability premise by `copySum_repAll`). -/
theorem copySum_meetsAll :
    Meets (copySum.spec .exact)
      (copySum.behavMid (ruleK _) (ruleK _) fun _ E => E.inp.comap Sum.inl) :=
  Meets.comp_exact copySum rfl rfl _ copySum_repAll (ruleK_meets _) (ruleK_meets _)

/-- One test grade family (`sameGrade`), for every index types `I` and entry types `d`: at every
size, encoding and exact inputs, each output's grade is the grade of the input of the same
index. -/
def sameGrade {I : ℕ → Type} {d : ∀ n, I n → DType} :
    ∀ n, Encodings I I d d n → Ents (I n) (d n) → (I n → Grade) → I n → Grade :=
  fun _ _ _ G => G

/-- `sameGrade` grows with the inputs' grades, for every index types and entry types, at every
size, encoding and exact inputs. -/
theorem sameGrade_mono {I : ℕ → Type} {d : ∀ n, I n → DType} :
    ∀ n E A, Monotone (sameGrade (I := I) (d := d) n E A) :=
  fun _ _ _ _ _ h => h

/-- One test spec family (`negG I`), for every finite index types `I`: at every size `n` the
integer inputs `I n` as outputs, each negated, meant everywhere, with the graded rule
`sameGrade`. -/
def negG (I : ℕ → Type) [∀ n, Fintype (I n)] : Spec ℕ where
  In := I
  Out := I
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x i := - x i
  rule := .graded sameGrade sameGrade_mono

/-- One test wiring (`copyNegG`): at every size `n`, the `n` outputs of `copyInt` into the `n`
inputs of `negG Fin`, with no extra input. -/
def copyNegG : Wiring copyInt (negG Fin) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test composition (`copyNegG`), for every storage `u` of each entry type and encoding `Eo`
of the negations: with `copyInt`'s entries stored by `u`, its outputs are representable where its
inputs decode exactly (`GPUProof.Wiring.FstRep`), at every size: the input words themselves
decode to them. -/
theorem copyNegG_rep (u : (d : DType) → ScalarEnc d)
    (Eo : ∀ n, Encoding ((negG Fin).Out n) ((negG Fin).dOut n)) :
    copyNegG.FstRep (copyNegG.encs (Encodings.uniform _ u) noExtra Eo) fun n =>
      (Encodings.uniform _ u n).out :=
  fun _ W _ hW _ => ⟨fun p => W (.inl p), hW⟩

/-- One test composition of an `exact` rule with a graded one (`copyNegG`), for every storage `u`
of each entry type, behaviors `k₁` of `copyInt` and `k₂` of `negG Fin`, and encoding `Eo` of the
negations: if `k₁` meets `copyInt` with its entries stored by `u` and `k₂` meets `negG Fin` at
`copyInt`'s outputs along `copyNegG` with `Eo`, their composition meets the composite with the
graded rule `GPUProof.Wiring.gradeEx` (`GPUProof.MeetsAt.comp_exact_graded`, its
representability premise by `copyNegG_rep`). -/
theorem copyNegG_meets (u : (d : DType) → ScalarEnc d)
    {k₁ : ∀ n (E : copyInt.Encs n), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ n (E : (negG Fin).Encs n), E.inp.Words → Set E.out.Words}
    (Eo : ∀ n, Encoding ((negG Fin).Out n) ((negG Fin).dOut n))
    (hk₁ : MeetsAt copyInt k₁ (Encodings.uniform _ u))
    (hk₂ : MeetsAt (negG Fin) k₂ (copyNegG.encs₂ (Encodings.uniform _ u) noExtra Eo)) :
    MeetsAt (copyNegG.spec (.graded (copyNegG.gradeEx (fun n _ => (Encodings.uniform _ u n).out)
        (fun n _ => noExtra n) sameGrade) (copyNegG.gradeEx_mono _ _ sameGrade_mono)))
      (copyNegG.behav k₁ k₂ (Encodings.uniform _ u) noExtra Eo)
      (copyNegG.encs (Encodings.uniform _ u) noExtra Eo) :=
  MeetsAt.comp_exact_graded copyNegG rfl rfl _ noExtra Eo (copyNegG_rep u Eo) hk₁ hk₂

/-- One test grade (`copyNegG`'s composite at `copyNegG_meets`'s encodings), for every storage `u`
of each entry type, size `n`, composite encoding, exact inputs, grades whose first inputs' are
exact and output: the composite's grade `GPUProof.Wiring.gradeEx` is `⟨0, 0⟩`
(`GPUProof.Wiring.gradeEx_eq`), so the composite's rule asks for the exact negations. -/
theorem copyNegG_grade (u : (d : DType) → ScalarEnc d) (n : ℕ) (E : copyNegG.Encs n)
    (Z : Ents (copyNegG.In n) (copyNegG.dIn n)) {G : copyNegG.In n → Grade}
    (hc : ∀ i, (G (.inl i)).err ≤ 0 ∧ (G (.inl i)).mag ≤ (E.inp.fmt (.inl i)).safeMax)
    (o : Fin n) :
    copyNegG.gradeEx (fun n _ => (Encodings.uniform _ u n).out) (fun n _ => noExtra n) sameGrade
      n E Z G o = ⟨0, 0⟩ :=
  copyNegG.gradeEx_eq _ _ _ E Z hc o

/-- The largest 32-bit integer is at least `0`, so a grade of magnitude `0` makes a claim in that
format (test of one value). -/
theorem safeMax_int32 : (0 : ℝ) ≤ NumFormat.safeMax (.int 32) := by
  norm_num [NumFormat.safeMax]

-- `copyNegG_meets` at size 3, for every binary interchange format `fmt` (which integer entries
-- do not read), with every entry stored as a 32-bit integer and the behaviors `ruleK`, its
-- premises by evaluation: at the input words `1, 2, 3` and input grades `⟨0, 0⟩` the
-- composite's grade is `⟨0, 0⟩` (as in `copyNegG_grade`), and every output word of the
-- composition decodes to `-1, -2, -3`.
example (fmt : FloatFormat) :
    ∀ W' ∈ copyNegG.behav (ruleK _) (ruleK _) (Encodings.uniform _ (ScalarEnc.std fmt 32))
        noExtra (fun n => (Encodings.uniform (negG Fin) (ScalarEnc.std fmt 32) n).out) 3
        (copyNegG.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
          (fun n => (Encodings.uniform (negG Fin) (ScalarEnc.std fmt 32) n).out) 3)
        (fun | .inl i => BitVec.ofNat 32 (i.val + 1) | .inr e => e.elim),
      ∀ o : Fin 3, (Encodings.uniform (negG Fin) (ScalarEnc.std fmt 32) 3).out.decode W' o =
        some (-((o.val : ℤ) + 1)) := fun W' hW' o => by
  have H := copyNegG_meets (ScalarEnc.std fmt 32)
    (fun n => (Encodings.uniform (negG Fin) (ScalarEnc.std fmt 32) n).out)
    (ruleK_meets _ _) (ruleK_meets _ _) 3 _ W' hW'
    (fun | .inl i => (BitVec.ofNat 32 (i.val + 1)).toInt | .inr e => e.elim) (fun _ => ⟨0, 0⟩)
    ⟨trivial, trivial⟩ (fun | .inl _ => fun _ => rfl | .inr e => e.elim) o
    (by
      show (Grade.onlyIf _ _ _).mag ≤ _
      rw [Grade.onlyIf_pos]
      exacts [safeMax_int32, fun _ => ⟨le_rfl, safeMax_int32⟩])
  refine H.trans ?_
  fin_cases o <;> rfl

/-- One test wiring (`sumNegG`): at every size, the output of `GPUProof.Spec.sumInt` into the
input of `negG` at one entry, with no extra input. -/
def sumNegG : Wiring Spec.sumInt (negG fun _ => Unit) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- The second step of the graded mutant (test of one example), for every binary interchange
format `fmt`, input encoding `e` of `negG` at one entry and size 2 in the 32-bit integer format,
and words `X` that decode to `0`: the output word `0` meets the negation's graded rule with the
output stored as a 32-bit integer. Where the input's grade claims nothing, so does the output's,
the two formats being one. -/
theorem negG_zero (fmt : FloatFormat) (e : Encoding Unit fun _ => .int) (X : e.Words)
    (hX : ∀ u, e.decode X u = some (0 : ℤ)) (hf : ∀ u, e.fmt u = .int 32) :
    (negG fun _ => Unit).rule.Holds 2
      ⟨e, (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) 2).out⟩ X
      fun _ => (0 : BitVec 32) := by
  intro A G _ hG ⟨⟩ hm
  obtain rfl : A = fun _ => (0 : ℤ) := funext fun ⟨⟩ =>
    Option.some.inj ((hG () (by rw [hf]; exact hm)).symm.trans (hX ()))
  rfl

/-- The graded mutant's composite claim fails (test of one example), for every binary interchange
format `fmt` and encodings `Fx` of the (no) extra inputs, with every entry stored as a 32-bit
integer: at size 2, the input words `2 ^ 30` and input grades `⟨0, 0⟩`, the composite's grade is
`⟨0, 0⟩` (`GPUProof.Grade.onlyIf_pos`), so its graded rule asks for the word of `-2 ^ 31`, and
the output word `0` does not meet it. -/
theorem sumNegG_fails (fmt : FloatFormat)
    (Fx : ∀ n, sumNegG.Encs n → Encoding (sumNegG.Extra n) (sumNegG.dEx n)) :
    ¬ (sumNegG.spec (.graded (sumNegG.gradeEx
        (fun n _ => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) Fx sameGrade)
        (sumNegG.gradeEx_mono _ _ sameGrade_mono))).rule.Holds 2
      (sumNegG.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) n).out) 2)
      (fun | .inl _ => (2 ^ 30 : BitVec 32) | .inr e => e.elim) fun _ => (0 : BitVec 32) := by
  intro h
  have := Option.some.inj (h (fun | .inl _ => (2 ^ 30 : ℤ) | .inr e => e.elim) (fun _ => ⟨0, 0⟩)
    ⟨trivial, trivial⟩ (fun | .inl _ => fun _ => rfl | .inr e => e.elim) ()
    (by
      show (Grade.onlyIf _ _ _).mag ≤ _
      rw [Grade.onlyIf_pos]
      exacts [safeMax_int32, fun _ => ⟨le_rfl, safeMax_int32⟩]))
  change (0 : ℤ) = -(2 ^ 30 + 2 ^ 30) at this
  omega

/-- **Mutant: an `exact` rule then a graded one, with no representable intermediate** (test of
one example), for every binary interchange format `fmt` (which integer entries do not read), with
every entry stored as a 32-bit integer: the behaviors `ruleK` meet `GPUProof.Spec.sumInt` and
`negG` (`ruleK_meets`), and their composition does not meet the composite with the graded rule
`GPUProof.Wiring.gradeEx`. At size 2 and the input words `2 ^ 30`, the sum `2 ^ 31` has no 32-bit
word, so the sum's rule claims nothing and allows the intermediate word `0` (`sumInt_none`),
whose negation `0` the negation's graded rule allows (`negG_zero`); at exact input grades the
composite's rule asks for the word of `-2 ^ 31` (`sumNegG_fails`). -/
theorem sumNegG_refused (fmt : FloatFormat) :
    ¬ MeetsAt (sumNegG.spec (.graded (sumNegG.gradeEx
        (fun n _ => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out)
        (fun n _ => noExtra n) sameGrade) (sumNegG.gradeEx_mono _ _ sameGrade_mono)))
      (sumNegG.behav (ruleK _) (ruleK _) (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        fun n => (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) n).out)
      (sumNegG.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        fun n => (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) n).out) :=
  fun h => sumNegG_fails fmt _ (h 2 _ _ fun hE => by
    obtain rfl : hE = rfl := rfl
    exact ⟨_, sumInt_none fmt _ _ fun _ => rfl, negG_zero fmt _ _ (fun _ => rfl) fun _ => rfl⟩)

/-- **The graded mutant at every encoding** (test of one example), for every binary interchange
format `fmt` (which integer entries do not read), with the intermediate stored as a 32-bit
integer at every composite encoding: `ruleK` after `ruleK` along `sumNegG`
(`GPUProof.Wiring.behavMid`) does not meet the composite with the graded rule
`GPUProof.Wiring.gradeEx` at every encoding. At the encodings of `sumNegG_refused`, size 2 and the
input words `2 ^ 30`, the same intermediate word `0` and output word `0` are allowed
(`sumInt_none`, `negG_zero`) and refused (`sumNegG_fails`). So the premise
`GPUProof.Wiring.FstRep` of `GPUProof.Meets.comp_exact_graded` is needed. -/
theorem sumNegG_refusedAll (fmt : FloatFormat) :
    ¬ Meets (sumNegG.spec (.graded (sumNegG.gradeEx
        (fun n _ => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) sumNegG.exEnc
        sameGrade) (sumNegG.gradeEx_mono _ _ sameGrade_mono)))
      (sumNegG.behavMid (ruleK _) (ruleK _) fun n _ =>
        (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) := fun h =>
  sumNegG_fails fmt _ (h (sumNegG.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
      fun n => (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) n).out) 2 _ _
    ⟨_, sumInt_none fmt _ _ fun _ => rfl, negG_zero fmt _ _ (fun _ => rfl) fun _ => rfl⟩)

/-- The graded mutant's first outputs are not representable where its inputs decode exactly
(`GPUProof.Wiring.FstRep` fails for `sumNegG`), for every binary interchange format `fmt`, with
every entry stored as a 32-bit integer: `GPUProof.MeetsAt.comp_exact_graded` would otherwise
contradict `sumNegG_refused`. So its representability premise is needed. -/
theorem sumNegG_norep (fmt : FloatFormat) :
    ¬ sumNegG.FstRep (sumNegG.encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
      fun n => (Encodings.uniform (negG fun _ => Unit) (ScalarEnc.std fmt 32) n).out) fun n =>
        (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out := fun hr =>
  sumNegG_refused fmt (MeetsAt.comp_exact_graded sumNegG rfl rfl _ _ _ hr (ruleK_meets _ _)
    (ruleK_meets _ _))

/-- One test composition (`copyNegG`) at every encoding: with the intermediate encoded as the
composite's inputs (`GPUProof.Encoding.comap` at `Sum.inl`), `copyInt`'s outputs are
representable where its inputs decode exactly, at every composite encoding
(`GPUProof.Wiring.FstRep`): the input words themselves decode to them. -/
theorem copyNegG_repAll (E : ∀ n, copyNegG.Encs n) :
    copyNegG.FstRep E fun n => (E n).inp.comap Sum.inl :=
  fun _ W _ hW _ => ⟨W, hW⟩

/-- One test composition of an `exact` rule with a graded one (`copyNegG`) at every encoding:
with the intermediate encoded as the composite's inputs, `ruleK` after `ruleK` meets the
composite with the graded rule `GPUProof.Wiring.gradeEx` at every encoding
(`GPUProof.Meets.comp_exact_graded`, its representability premise by `copyNegG_repAll`). -/
theorem copyNegG_meetsAll :
    Meets (copyNegG.spec (.graded (copyNegG.gradeEx (fun _ E => E.inp.comap Sum.inl)
        copyNegG.exEnc sameGrade) (copyNegG.gradeEx_mono _ _ sameGrade_mono)))
      (copyNegG.behavMid (ruleK _) (ruleK _) fun _ E => E.inp.comap Sum.inl) :=
  Meets.comp_exact_graded copyNegG rfl rfl _ copyNegG_repAll (ruleK_meets _) (ruleK_meets _)

/-- One test storage of an integer entry (`nanInt`): the words `0`, `1`, `2` of `Fin 3` in the
32-bit integer format, `0` decoding to `0` and the other two NaNs. -/
def nanInt : ScalarEnc .int where
  Word := Fin 3
  decode x := if x = 0 then some 0 else none
  isNaN x := decide (x ≠ 0)
  fmt := .int 32
  decode_isNaN _ h := ite_eq_right (of_decide_eq_true h)

/-- A word of `nanInt` with a value is `0`, and its value is `0` (test of one storage, for every
word and integer). -/
theorem nanInt_decode {x : Fin 3} {a : ℤ} (h : nanInt.decode x = some a) : x = 0 ∧ a = 0 := by
  change (if x = 0 then some 0 else none) = some a at h
  split at h
  · exact ⟨‹_›, (Option.some.inj h).symm⟩
  · cases h

/-- One test encoding (`nanEnc`): one integer entry stored by `nanInt`. -/
def nanEnc : Encoding Unit fun _ => .int := .ofScalars fun _ => nanInt

/-- One test encodings family (`nanEncs`): at every size, `nanEnc` on both sides. -/
def nanEncs (n : ℕ) :
    Encodings (fun _ : ℕ => Unit) (fun _ => Unit) (fun _ _ => .int) (fun _ _ => .int) n :=
  ⟨nanEnc, nanEnc⟩

/-- One test spec (`nanId`), at every size: one integer entry copied, meant everywhere, with the
`bitwise` rule at `nanEncs` and the identity word function. -/
def nanId : Spec ℕ where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise nanEncs (fun _ W => W) fun _ _ _ h _ o => h o

/-- One test word map (`squash`) of `nanInt`'s words: `0` and `1` to `0`, `2` to `1`. It is the
identity at the one word with a value, and it maps the NaNs `1` and `2`, equal up to NaN payloads,
to `0` and `1`, which are not. -/
def squash (x : Fin 3) : Fin 3 := if x = 2 then 1 else 0

/-- One test encodings family (`nanEncs₂`): at every size, `nanEnc` and no extra input side by
side, read along `Equiv.sumEmpty`, on the inputs, and `nanEnc` on the outputs; these are
`GPUProof.Wiring.encs₂` of `nanIdSq` at `nanEncs`. -/
def nanEncs₂ (n : ℕ) :
    Encodings (fun _ : ℕ => Unit) (fun _ => Unit) (fun _ _ => .int) (fun _ _ => .int) n :=
  ⟨(nanEnc.sum (noExtra n)).reindex (Equiv.sumEmpty Unit Empty).symm fun _ => rfl, nanEnc⟩

/-- `squash` at the first position decodes as the identity at `nanEncs₂` (test of one word
function, at every size): inputs with a value are the word `0`, which `squash` keeps. -/
theorem squash_dec :
    DecodesAs (fun _ : ℕ => Unit) (fun _ => Unit) (fun _ _ => .int) (fun _ _ => .int)
      (fun _ _ => True) (fun _ x => x) nanEncs₂ fun _ W _ => squash (W (Sum.inl ())) := by
  intro n W A hA _ ⟨⟩
  obtain ⟨h0, ha⟩ := nanInt_decode (x := W (Sum.inl ())) (hA ())
  change nanInt.decode (squash (W (Sum.inl ()))) = some (A ())
  rw [h0, ha]
  rfl

/-- One test spec (`nanSq`), at every size: one integer entry copied, meant everywhere, with the
`bitwise` rule at `nanEncs₂` and the word function `squash`. -/
def nanSq : Spec ℕ where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise nanEncs₂ (fun _ W _ => squash (W (Sum.inl ()))) squash_dec

/-- One test wiring (`nanIdSq`): at every size, the output of `nanId` into the input of `nanSq`,
with no extra input. -/
def nanIdSq : Wiring nanId nanSq where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- The composite of `nanIdSq`'s word functions (test of one word function, at every size):
`nanId`'s, the identity, at the first input, then `nanSq`'s, `squash`. -/
def nanIdSqW (n : ℕ) (W : (nanIdSq.encs nanEncs noExtra (fun _ => nanEnc) n).inp.Words) :
    (nanIdSq.encs nanEncs noExtra (fun _ => nanEnc) n).out.Words :=
  fun _ => squash (W (Sum.inl ()))

/-- The composite word function decodes as the composite's function at the composite's
encodings (test of one word function, at every size): inputs with a value are the word `0`. -/
theorem nanIdSqW_dec :
    DecodesAs nanIdSq.In nanSq.Out nanIdSq.dIn nanSq.dOut nanIdSq.Dom nanIdSq.f
      (nanIdSq.encs nanEncs noExtra fun _ => nanEnc) nanIdSqW := by
  intro n W Z hZ _ ⟨⟩
  obtain ⟨h0, hz⟩ := nanInt_decode (x := W (Sum.inl ())) (hZ (Sum.inl ()))
  change nanInt.decode (squash (W (Sum.inl ()))) = some (Z (Sum.inl ()))
  rw [h0, hz]
  rfl

/-- `squash` does not respect equality up to NaN payloads (test of one word map): the NaNs `1`
and `2` are equal up to NaN payloads (`GPUProof.ScalarEnc.nanEq` of `nanInt`), and their images
`0` and `1` are not. -/
theorem squash_nanEq :
    nanInt.nanEq (1 : Fin 3) (2 : Fin 3) ∧ ¬ nanInt.nanEq (squash 1) (squash 2) := by
  change ((1 : Fin 3) = 2 ∨ (decide ((1 : Fin 3) ≠ 0) = true ∧ decide ((2 : Fin 3) ≠ 0) = true)) ∧
    ¬ (squash 1 = squash 2 ∨ (decide (squash 1 ≠ 0) = true ∧ decide (squash 2 ≠ 0) = true))
  decide

/-- **Mutant: two `bitwise` rules do not compose into the `bitwise` rule of the composed word
functions** (test of one example), with one integer entry stored by `nanInt`: the behaviors
`ruleK` meet `nanId` and `nanSq` (`ruleK_meets`), `nanSq` at `nanId`'s outputs along `nanIdSq`
(its encodings `nanEncs₂` are `GPUProof.Wiring.encs₂` there), and their composition does not
meet the composite with the `bitwise` rule at `GPUProof.Wiring.encs` and the composed word
function `nanIdSqW`. At size 0 and the input word `1`, a NaN, `nanId`'s rule allows the
intermediate word `2`, another NaN, and `nanSq`'s rule then allows `squash 2 = 1`; the
composite's rule asks for a word equal up to NaN payloads to `squash 1 = 0`, which has a value.
The composition needs the second word function to respect equality up to NaN payloads, and
`squash` does not (`squash_nanEq`). -/
theorem nanIdSq_refused :
    ¬ MeetsAt (nanIdSq.spec (.bitwise (nanIdSq.encs nanEncs noExtra fun _ => nanEnc) nanIdSqW
        nanIdSqW_dec))
      (nanIdSq.behav (ruleK _) (ruleK _) nanEncs noExtra fun _ => nanEnc)
      (nanIdSq.encs nanEncs noExtra fun _ => nanEnc) := fun h => by
  have H := h 0 (fun | .inl _ => (1 : Fin 3) | .inr e => e.elim) (fun _ => (1 : Fin 3))
    (fun hE => by
      obtain rfl : hE = rfl := rfl
      refine ⟨fun _ => (2 : Fin 3), fun h₁ => ?_, fun h₂ => ?_⟩
      · obtain rfl : h₁ = rfl := rfl
        exact fun _ => Or.inr ⟨rfl, rfl⟩
      · obtain rfl : h₂ = rfl := rfl
        exact fun _ => Or.inl rfl) rfl
  have H₀ : (1 : Fin 3) = 0 ∨ (decide ((1 : Fin 3) ≠ 0) = true ∧ decide ((0 : Fin 3) ≠ 0) = true) :=
    H ()
  revert H₀
  decide

/-- One test wiring (`nanIdNeg`): at every size, the output of `nanId` into the input of `negG`
at one entry, with no extra input. -/
def nanIdNeg : Wiring nanId (negG fun _ => Unit) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- **A `bitwise` rule then a graded one** (test, at every size), with one integer entry stored
by `nanInt`: `ruleK` after `ruleK` along `nanIdNeg` meets the composite with the graded rule
`GPUProof.Wiring.gradeEx` at `nanEncs` and no extra input (`GPUProof.MeetsAt.comp_bitwise_graded`,
with no representability premise). -/
theorem nanIdNeg_meets :
    MeetsAt (nanIdNeg.spec (.graded (nanIdNeg.gradeEx (fun _ _ => nanEnc) (fun n _ => noExtra n)
        sameGrade) (nanIdNeg.gradeEx_mono _ _ sameGrade_mono)))
      (nanIdNeg.behav (ruleK _) (ruleK _) nanEncs noExtra fun _ => nanEnc)
      (nanIdNeg.encs nanEncs noExtra fun _ => nanEnc) :=
  MeetsAt.comp_bitwise_graded nanIdNeg nanEncs noExtra _ rfl rfl (ruleK_meets _ _)
    (ruleK_meets _ _)

/-- One test spec family (`copyBit u`), for every storage `u` of each entry type: at every size
`n`, `n` integer inputs as `n` integer outputs, the identity, meant everywhere, with the `bitwise`
rule at `copyInt`'s entries stored by `u` and the identity word function. -/
def copyBit (u : (d : DType) → ScalarEnc d) : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise (Encodings.uniform copyInt u) (fun _ W => W) fun _ _ _ h _ o => h o

/-- One test wiring (`bitSum u`), for every storage `u`: at every size `n`, the `n` outputs of
`copyBit u` into the `n` inputs of `GPUProof.Spec.sumInt`, with no extra input. -/
def bitSum (u : (d : DType) → ScalarEnc d) : Wiring (copyBit u) Spec.sumInt where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test composition of a `bitwise` rule with an `exact` one (`bitSum u`), for every storage
`u` of each entry type, behaviors `k₁` of `copyBit u` and `k₂` of `GPUProof.Spec.sumInt`, and
encoding `Eo` of the sum: if `k₁` meets `copyBit u` at its rule's encodings and `k₂` meets the sum
at `copyBit u`'s outputs along `bitSum u` with `Eo`, their composition meets the composite with
the `exact` rule (`GPUProof.MeetsAt.comp_bitwise_exact`), with no representability premise. -/
theorem bitSum_meets (u : (d : DType) → ScalarEnc d)
    {k₁ : ∀ n (E : (copyBit u).Encs n), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ n (E : Spec.sumInt.Encs n), E.inp.Words → Set E.out.Words}
    (Eo : ∀ n, Encoding (Spec.sumInt.Out n) (Spec.sumInt.dOut n))
    (hk₁ : MeetsAt (copyBit u) k₁ (Encodings.uniform copyInt u))
    (hk₂ : MeetsAt Spec.sumInt k₂ ((bitSum u).encs₂ (Encodings.uniform copyInt u) noExtra Eo)) :
    MeetsAt ((bitSum u).spec .exact)
      ((bitSum u).behav k₁ k₂ (Encodings.uniform copyInt u) noExtra Eo)
      ((bitSum u).encs (Encodings.uniform copyInt u) noExtra Eo) :=
  MeetsAt.comp_bitwise_exact (bitSum u) (Encodings.uniform copyInt u) noExtra Eo rfl rfl hk₁ hk₂

-- `bitSum_meets` at two sizes, for every binary interchange format `fmt` (which integer entries
-- do not read), with every entry stored as a 32-bit integer and the behaviors `ruleK`, its
-- premises by evaluation: at size 3 and the input words `1, 2, 3` every output word of the
-- composition decodes to `6`.
example (fmt : FloatFormat) :
    ∀ W' ∈ (bitSum (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform copyInt (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 3
        ((bitSum (ScalarEnc.std fmt 32)).encs (Encodings.uniform copyInt (ScalarEnc.std fmt 32))
          noExtra (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 3)
        (fun | .inl i => BitVec.ofNat 32 (i.val + 1) | .inr e => e.elim),
      (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) 3).out.decode W' () =
        some (6 : ℤ) := fun W' hW' =>
  (bitSum_meets (ScalarEnc.std fmt 32)
    (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out)
    (ruleK_meets _ _) (ruleK_meets _ _) 3 _ W' hW'
    (fun | .inl i => (BitVec.ofNat 32 (i.val + 1)).toInt | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun _ => (6 : BitVec 32), fun _ => rfl⟩ ()).trans rfl

-- The same at size 7 and seven input words `-1`: every output word decodes to `-7`.
example (fmt : FloatFormat) :
    ∀ W' ∈ (bitSum (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform copyInt (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 7
        ((bitSum (ScalarEnc.std fmt 32)).encs (Encodings.uniform copyInt (ScalarEnc.std fmt 32))
          noExtra (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out) 7)
        (fun | .inl _ => (-1 : BitVec 32) | .inr e => e.elim),
      (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) 7).out.decode W' () =
        some (-7 : ℤ) := fun W' hW' =>
  (bitSum_meets (ScalarEnc.std fmt 32)
    (fun n => (Encodings.uniform Spec.sumInt (ScalarEnc.std fmt 32) n).out)
    (ruleK_meets _ _) (ruleK_meets _ _) 7 _ W' hW' (fun | .inl _ => (-1 : ℤ) | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun _ => (-7 : BitVec 32), fun _ => rfl⟩ ()).trans rfl

/-- One test encodings family (`wiredEncs u`), for every storage `u` of each entry type: at every
size `n`, `copyInt`'s outputs stored by `u` and no extra input side by side, read along
`Equiv.sumEmpty`, on the inputs, and `copyInt`'s outputs stored by `u` on the outputs; these are
`GPUProof.Wiring.encs₂` of `copyCp u` and of `bitCp u` at `copyInt`'s entries stored by `u`. -/
def wiredEncs (u : (d : DType) → ScalarEnc d) (n : ℕ) :
    Encodings Fin Fin (fun _ _ => .int) (fun _ _ => .int) n :=
  ⟨((Encodings.uniform copyInt u n).out.sum (noExtra n)).reindex
    (Equiv.sumEmpty (Fin n) Empty).symm fun _ => rfl, (Encodings.uniform copyInt u n).out⟩

/-- One test spec family (`copyW u`), for every storage `u` of each entry type: at every size
`n`, `n` integer inputs as `n` integer outputs, the identity, meant everywhere, with the `bitwise`
rule at `wiredEncs u` and the word function that gives output `i` the word at position `inl i`.
It maps words equal up to NaN payloads to words equal up to NaN payloads. -/
def copyW (u : (d : DType) → ScalarEnc d) : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise (wiredEncs u) (fun _ W i => W (.inl i)) fun _ _ _ h _ o => h o

/-- One test wiring (`copyCp u`), for every storage `u`: at every size `n`, the `n` outputs of
`copyInt` into the `n` inputs of `copyW u`, with no extra input. -/
def copyCp (u : (d : DType) → ScalarEnc d) : Wiring copyInt (copyW u) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test composition (`copyCp u`), for every storage `u` of each entry type: with `copyInt`'s
entries stored by `u`, the intermediate is representable where the composite's rule makes a
claim (`GPUProof.Wiring.MidRep`), at every size: the input words themselves decode to it. -/
theorem copyCp_rep (u : (d : DType) → ScalarEnc d) :
    (copyCp u).MidRep ((copyCp u).encs (Encodings.uniform _ u) noExtra fun n =>
      (Encodings.uniform copyInt u n).out) fun n => (Encodings.uniform _ u n).out :=
  fun _ W _ hW _ _ => ⟨fun p => W (.inl p), fun o => hW (.inl o)⟩

/-- One test composition of an `exact` rule with a `bitwise` one (`copyCp u`), for every storage
`u` of each entry type and behaviors `k₁` of `copyInt` and `k₂` of `copyW u`: if `k₁` meets
`copyInt` with its entries stored by `u` and `k₂` meets `copyW u` at its rule's encodings, their
composition meets the composite with the `exact` rule (`GPUProof.MeetsAt.comp_exact_bitwise`,
its representability premise by `copyCp_rep`). -/
theorem copyCp_meets (u : (d : DType) → ScalarEnc d)
    {k₁ : ∀ n (E : copyInt.Encs n), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ n (E : (copyW u).Encs n), E.inp.Words → Set E.out.Words}
    (hk₁ : MeetsAt copyInt k₁ (Encodings.uniform _ u)) (hk₂ : MeetsAt (copyW u) k₂ (wiredEncs u)) :
    MeetsAt ((copyCp u).spec .exact)
      ((copyCp u).behav k₁ k₂ (Encodings.uniform _ u) noExtra fun n =>
        (Encodings.uniform copyInt u n).out)
      ((copyCp u).encs (Encodings.uniform _ u) noExtra fun n =>
        (Encodings.uniform copyInt u n).out) :=
  MeetsAt.comp_exact_bitwise (copyCp u) (Encodings.uniform _ u) noExtra
    (fun n => (Encodings.uniform copyInt u n).out) rfl rfl (copyCp_rep u) hk₁ hk₂

-- `copyCp_meets` at two sizes, for every binary interchange format `fmt` (which integer entries
-- do not read), with every entry stored as a 32-bit integer and the behaviors `ruleK`, its
-- premises by evaluation: at size 3 and the input words `1, 2, 3` every output word of the
-- composition decodes to `1, 2, 3`.
example (fmt : FloatFormat) :
    ∀ W' ∈ (copyCp (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 3
        ((copyCp (ScalarEnc.std fmt 32)).encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
          (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 3)
        (fun | .inl i => BitVec.ofNat 32 (i.val + 1) | .inr e => e.elim),
      ∀ o : Fin 3, (Encodings.uniform copyInt (ScalarEnc.std fmt 32) 3).out.decode W' o =
        some ((o.val : ℤ) + 1) := fun W' hW' o => by
  have H := copyCp_meets (ScalarEnc.std fmt 32) (ruleK_meets _ _) (ruleK_meets _ _) 3 _ W' hW'
    (fun | .inl i => (BitVec.ofNat 32 (i.val + 1)).toInt | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩
    ⟨fun i => BitVec.ofNat 32 (i.val + 1), fun _ => rfl⟩ o
  refine H.trans ?_
  fin_cases o <;> rfl

-- The same at size 7 and seven input words `-1`: every output word decodes to `-1`.
example (fmt : FloatFormat) :
    ∀ W' ∈ (copyCp (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 7
        ((copyCp (ScalarEnc.std fmt 32)).encs (Encodings.uniform _ (ScalarEnc.std fmt 32)) noExtra
          (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 7)
        (fun | .inl _ => (-1 : BitVec 32) | .inr e => e.elim),
      ∀ o : Fin 7, (Encodings.uniform copyInt (ScalarEnc.std fmt 32) 7).out.decode W' o =
        some (-1 : ℤ) := fun W' hW' o =>
  (copyCp_meets (ScalarEnc.std fmt 32) (ruleK_meets _ _) (ruleK_meets _ _) 7 _ W' hW'
    (fun | .inl _ => (-1 : ℤ) | .inr e => e.elim) (fun | .inl _ => rfl | .inr e => e.elim)
    ⟨trivial, trivial⟩ ⟨fun _ => (-1 : BitVec 32), fun _ => rfl⟩ o).trans rfl

/-- One test encodings family (`zeroEncs₂`): at every size, `nanEnc` and no extra input side by
side, read along `Equiv.sumEmpty`, on the inputs, and one 32-bit integer on the outputs; these are
`GPUProof.Wiring.encs₂` of `negZ` at `negZE`. -/
def zeroEncs₂ (n : ℕ) :
    Encodings (fun _ : ℕ => Unit) (fun _ => Unit) (fun _ _ => .int) (fun _ _ => .int) n :=
  ⟨(nanEnc.sum (noExtra n)).reindex (Equiv.sumEmpty Unit Empty).symm fun _ => rfl,
    .ofScalars fun _ => .int 32⟩

/-- The constant word `0` decodes as the identity at `zeroEncs₂` (test of one word function, at
every size): an input with a value is the word `0` of `nanInt`, with the value `0`
(`nanInt_decode`), and the 32-bit word `0` decodes to `0`. -/
theorem zero_dec :
    DecodesAs (fun _ : ℕ => Unit) (fun _ => Unit) (fun _ _ => .int) (fun _ _ => .int)
      (fun _ _ => True) (fun _ x => x) zeroEncs₂ fun _ _ _ => (0 : BitVec 32) := by
  intro n W A hA _ ⟨⟩
  obtain ⟨-, ha⟩ := nanInt_decode (x := W (Sum.inl ())) (hA ())
  change some (0 : BitVec 32).toInt = some (A ())
  rw [ha]
  rfl

/-- One test spec (`zeroW`), at every size: one integer entry copied, meant everywhere, with the
`bitwise` rule at `zeroEncs₂` and the constant word function `0`. -/
def zeroW : Spec ℕ where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise zeroEncs₂ (fun _ _ _ => (0 : BitVec 32)) zero_dec

/-- One test wiring (`negZ`): at every size, the output of `negInt` into the input of `zeroW`,
with no extra input. -/
def negZ : Wiring negInt zeroW where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- One test encodings family of `negInt` (`negZE`): at every size, the input as a 32-bit
integer and the output stored by `nanEnc`, whose one value is `0`. -/
def negZE (n : ℕ) : negInt.Encs n := ⟨.ofScalars fun _ => .int 32, nanEnc⟩

/-- **Mutant: an `exact` rule then a `bitwise` one, with no representable intermediate** (test of
one example): the behaviors `ruleK` meet `negInt` at `negZE` and `zeroW` (`ruleK_meets`), and their
composition along `negZ` does not meet the composite with the `exact` rule. At size 0 and the
input word `5`, the negation `-5` has no word of `nanEnc`, so `negInt`'s rule claims nothing and
allows the intermediate word `0`, which `zeroW`'s rule maps to the output word `0`; the
composite's function `-5` has a 32-bit word, so its rule asks for it. -/
theorem negZ_refused :
    ¬ MeetsAt (negZ.spec .exact)
      (negZ.behav (ruleK _) (ruleK _) negZE noExtra fun _ => .ofScalars fun _ => .int 32)
      (negZ.encs negZE noExtra fun _ => .ofScalars fun _ => .int 32) := fun h => by
  have H := h 0 (fun | .inl _ => (5 : BitVec 32) | .inr e => e.elim) (fun _ => (0 : BitVec 32))
    (fun hE => by
      obtain rfl : hE = rfl := rfl
      refine ⟨fun _ => (0 : Fin 3), fun A hA _ ⟨V, hV⟩ => ?_, fun h₂ => ?_⟩
      · obtain rfl : A = fun _ => (5 : ℤ) :=
          funext fun u => Option.some.inj ((hA u).symm.trans rfl)
        obtain ⟨-, h0⟩ := nanInt_decode (hV ())
        change (-5 : ℤ) = 0 at h0
        omega
      · obtain rfl : h₂ = rfl := rfl
        exact fun _ => Or.inl rfl)
    (fun | .inl _ => (5 : ℤ) | .inr e => e.elim) (fun | .inl _ => rfl | .inr e => e.elim)
    ⟨trivial, trivial⟩ ⟨fun _ => (-5 : BitVec 32), fun _ => rfl⟩ ()
  have H₀ : some (0 : ℤ) = some (-5) := H
  exact absurd H₀ (by decide)

/-- The intermediate of `negZ` is not representable where the composite's rule makes a claim
(`GPUProof.Wiring.MidRep` fails at `negZE`): `GPUProof.MeetsAt.comp_exact_bitwise` would
otherwise contradict `negZ_refused`. So its representability premise is needed. -/
theorem negZ_norep :
    ¬ negZ.MidRep (negZ.encs negZE noExtra fun _ => .ofScalars fun _ => .int 32) fun n =>
      (negZE n).out := fun hr =>
  negZ_refused (MeetsAt.comp_exact_bitwise negZ negZE noExtra
    (fun _ => .ofScalars fun _ => .int 32) rfl rfl hr (ruleK_meets _ _) (ruleK_meets _ _))

/-- One test wiring (`bitCp u`), for every storage `u`: at every size `n`, the `n` outputs of
`copyBit u` into the `n` inputs of `copyW u`, with no extra input. -/
def bitCp (u : (d : DType) → ScalarEnc d) : Wiring (copyBit u) (copyW u) where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire n := (Equiv.sumEmpty (Fin n) Empty).symm
  types _ _ := rfl

/-- One test composition of two `bitwise` rules (`bitCp u`), for every storage `u` of each entry
type and behaviors `k₁` of `copyBit u` and `k₂` of `copyW u`: if each meets its spec at its
rule's encodings, their composition meets the composite with the `bitwise` rule at
`GPUProof.Wiring.encs` and the composed word function `GPUProof.Wiring.bitW`
(`GPUProof.MeetsAt.comp_bitwise`): `copyW u`'s word function reads a position's word, so it maps
words equal up to NaN payloads to words equal up to NaN payloads. -/
theorem bitCp_meets (u : (d : DType) → ScalarEnc d)
    {k₁ : ∀ n (E : (copyBit u).Encs n), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ n (E : (copyW u).Encs n), E.inp.Words → Set E.out.Words}
    (hk₁ : MeetsAt (copyBit u) k₁ (Encodings.uniform copyInt u))
    (hk₂ : MeetsAt (copyW u) k₂ (wiredEncs u)) :
    MeetsAt ((bitCp u).spec (.bitwise
        ((bitCp u).encs (Encodings.uniform copyInt u) noExtra fun n =>
          (Encodings.uniform copyInt u n).out)
        ((bitCp u).bitW (Encodings.uniform copyInt u) noExtra
          (fun n => (Encodings.uniform copyInt u n).out) (fun _ W => W) fun _ W i => W (.inl i))
        ((bitCp u).bitW_dec (Encodings.uniform copyInt u) noExtra
          (fun n => (Encodings.uniform copyInt u n).out) (fun _ _ _ h _ o => h o)
          fun _ _ _ h _ o => h o)))
      ((bitCp u).behav k₁ k₂ (Encodings.uniform copyInt u) noExtra fun n =>
        (Encodings.uniform copyInt u n).out)
      ((bitCp u).encs (Encodings.uniform copyInt u) noExtra fun n =>
        (Encodings.uniform copyInt u n).out) :=
  MeetsAt.comp_bitwise (bitCp u) (Encodings.uniform copyInt u) noExtra
    (fun n => (Encodings.uniform copyInt u n).out) rfl rfl (fun _ _ _ h i => h (.inl i)) hk₁ hk₂

-- `bitCp_meets` at two sizes, for every binary interchange format `fmt` (which integer entries
-- do not read), with every entry stored as a 32-bit integer and the behaviors `ruleK`, its
-- premises by evaluation: at size 3 and the input words `1, 2, 3` every output word of the
-- composition decodes to `1, 2, 3` (`GPUProof.FloatRule.Holds.bitwise`).
example (fmt : FloatFormat) :
    ∀ W' ∈ (bitCp (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform copyInt (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 3
        ((bitCp (ScalarEnc.std fmt 32)).encs (Encodings.uniform copyInt (ScalarEnc.std fmt 32))
          noExtra (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 3)
        (fun | .inl i => BitVec.ofNat 32 (i.val + 1) | .inr e => e.elim),
      ∀ o : Fin 3, (Encodings.uniform copyInt (ScalarEnc.std fmt 32) 3).out.decode W' o =
        some ((o.val : ℤ) + 1) := fun W' hW' o => by
  have H := FloatRule.Holds.bitwise
    (bitCp_meets (ScalarEnc.std fmt 32) (ruleK_meets _ _) (ruleK_meets _ _) 3 _ W' hW')
    (A := fun | .inl i => (BitVec.ofNat 32 (i.val + 1)).toInt | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩ o
  refine H.trans ?_
  fin_cases o <;> rfl

-- The same at size 7 and seven input words `-1`: every output word decodes to `-1`.
example (fmt : FloatFormat) :
    ∀ W' ∈ (bitCp (ScalarEnc.std fmt 32)).behav (ruleK _) (ruleK _)
        (Encodings.uniform copyInt (ScalarEnc.std fmt 32)) noExtra
        (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 7
        ((bitCp (ScalarEnc.std fmt 32)).encs (Encodings.uniform copyInt (ScalarEnc.std fmt 32))
          noExtra (fun n => (Encodings.uniform copyInt (ScalarEnc.std fmt 32) n).out) 7)
        (fun | .inl _ => (-1 : BitVec 32) | .inr e => e.elim),
      ∀ o : Fin 7, (Encodings.uniform copyInt (ScalarEnc.std fmt 32) 7).out.decode W' o =
        some (-1 : ℤ) := fun W' hW' o =>
  (FloatRule.Holds.bitwise
    (bitCp_meets (ScalarEnc.std fmt 32) (ruleK_meets _ _) (ruleK_meets _ _) 7 _ W' hW')
    (A := fun | .inl _ => (-1 : ℤ) | .inr e => e.elim)
    (fun | .inl _ => rfl | .inr e => e.elim) ⟨trivial, trivial⟩ o).trans rfl

/-- One test spec (`nanCp`), at every size: one integer entry copied, meant everywhere, with the
`bitwise` rule at `nanEncs₂` and the word function that reads the first position, which maps
words equal up to NaN payloads to words equal up to NaN payloads. -/
def nanCp : Spec ℕ where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ _ := True
  f _ x := x
  rule := .bitwise nanEncs₂ (fun _ W _ => W (Sum.inl ())) fun _ _ _ h _ o => h o

/-- One test wiring (`nanIdCp`): at every size, the output of `nanId` into the input of `nanCp`,
with no extra input. -/
def nanIdCp : Wiring nanId nanCp where
  Extra _ := Empty
  dEx _ e := Empty.elim e
  wire _ := (Equiv.sumEmpty Unit Empty).symm
  types _ _ := rfl

/-- **Two `bitwise` rules compose when the second respects NaN payloads** (test, at every size),
with one integer entry stored by `nanInt`: `ruleK` after `ruleK` along `nanIdCp` meets the
composite with the `bitwise` rule at `GPUProof.Wiring.encs` and the composed word function
(`GPUProof.MeetsAt.comp_bitwise`). It is `nanIdSq_refused` with `squash` replaced by the word
function that reads the first position. -/
theorem nanIdCp_meets :
    MeetsAt (nanIdCp.spec (.bitwise (nanIdCp.encs nanEncs noExtra fun _ => nanEnc)
        (nanIdCp.bitW nanEncs noExtra (fun _ => nanEnc) (fun _ W => W) fun _ W _ => W (Sum.inl ()))
        (nanIdCp.bitW_dec nanEncs noExtra (fun _ => nanEnc) (fun _ _ _ h _ o => h o)
          fun _ _ _ h _ o => h o)))
      (nanIdCp.behav (ruleK _) (ruleK _) nanEncs noExtra fun _ => nanEnc)
      (nanIdCp.encs nanEncs noExtra fun _ => nanEnc) :=
  MeetsAt.comp_bitwise nanIdCp nanEncs noExtra (fun _ => nanEnc) rfl rfl
    (fun _ _ _ h _ => h (Sum.inl ())) (ruleK_meets _ _) (ruleK_meets _ _)

/-- `nanSq`'s word function does not map words equal up to NaN payloads to words equal up to NaN
payloads at `nanEncs₂` (test of one premise): `GPUProof.MeetsAt.comp_bitwise` would otherwise
contradict `nanIdSq_refused`. So its premise is needed; `squash_nanEq` gives the two words. -/
theorem nanIdSq_noresp :
    ¬ ∀ n (X Y : (nanEncs₂ n).inp.Words), (nanEncs₂ n).inp.nanEq X Y →
      (nanEncs₂ n).out.nanEq (fun _ => squash (X (Sum.inl ()))) fun _ => squash (Y (Sum.inl ())) :=
  fun hn => nanIdSq_refused (MeetsAt.comp_bitwise nanIdSq nanEncs noExtra (fun _ => nanEnc) rfl rfl
    hn (ruleK_meets _ _) (ruleK_meets _ _))

end MojoProofTest.GPUProof.SpecComp
