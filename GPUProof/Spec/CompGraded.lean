import GPUProof.Spec.Comp

/-!
# A graded rule then an `exact` one, through a modulus of continuity

An `exact` rule claims `Sp.f σ Y` at input words that decode to `Y`; a graded rule makes its
claim about the exact inputs `A` that the decoded ones approximate. A modulus of continuity
(`Spec.Modulus Sp ω σ E`) joins the two at one size `σ` and encoding `E`. For every inputs `A` in
the domain and every inputs `Y` within grades `G` of `A` at `E`'s inputs (`Encoding.Within`: some
input words decode to `Y`, and at every entry the grade's magnitude is at most its format's
`NumFormat.safeMax` and `Y`'s value is near `A`'s within the grade), it asks three things:

* `Sp.f σ Y` is within the grade `ω σ E A G` of `Sp.f σ A` (`Spec.Modulus.near`);
* `Y` is in the domain (`Spec.Modulus.dom`);
* some output words of `E` decode to `Sp.f σ Y` (`Spec.Modulus.rep`), since the `exact` rule
  claims only there and a graded rule has no such premise.

From it, behaviors that meet the `exact` rule meet the graded rule `Spec.modGrade ω`
(`Spec.Modulus.holds` at one size and encoding, `MeetsAt.graded_of_exact` at encodings `E`). That
grade is `ω`'s where every input grade's magnitude is at most its format's `NumFormat.safeMax`,
and elsewhere `GPUProof.Grade.onlyIf`'s grade that claims nothing: there an input word may have no
value, and the `exact` rule then claims nothing. It grows with the input grades where `ω` does
(`Spec.modGrade_mono`). The spec with the derived rule in place of its own is `Spec.withRule`.

`MeetsAt.comp_graded_exact`: a graded rule then an `exact` one, at encodings built from parts.
Given a modulus of `S₂` at the encodings along the wiring (`GPUProof.Wiring.encs₂`) at every
size, it is `GPUProof.MeetsAt.comp` at the wiring into `S₂` with the derived rule
(`Wiring.withRule`, the same extra inputs, wire and types), so the composite's grade is
`GPUProof.Wiring.grade` at `S₁`'s grade and `Spec.modGrade ω`, with no second composition proof.
`Meets.comp_graded_exact`: the same at every composite encoding, for behaviors that meet their
specs at every encoding, with the intermediate's encoding chosen at each composite encoding
(`GPUProof.Wiring.behavMid`, as `GPUProof.Meets.comp`), at every composite encoding at which `ω`
is a modulus. That premise is on the composite's encodings: the modulus gives words for
`S₂.f σ Y` at the composite encoding's outputs (`Spec.Modulus.rep`), and an output encoding with
no word of that value refutes it, so the composite is not claimed there; the graded composite's
grade has no representability condition that would exclude such an encoding.

docs/proofs/spec.md gives the plan and the test instance.
-/

namespace GPUProof

variable {Sz : Type}

/-- A near value is a value, for every entry type, grade, decoded value `v` and exact value `a`:
if `v` is near `a` within grade `g` (`DType.Near`), it is `some y` with `some y` near `a`. -/
theorem DType.Near.exists_some {d : DType} {g : Grade} {v : Option d.Val} {a : d.Val}
    (h : d.Near g v a) : ∃ y, v = some y ∧ d.Near g (some y) a := by
  cases d
  · obtain ⟨r, rfl, hr⟩ := h
    exact ⟨r, rfl, r, rfl, hr⟩
  · exact ⟨a, h, rfl⟩
  · exact ⟨a, h, rfl⟩

/-- Entries `Y` within grades `G` of entries `A` at encoding `e`, for every index type, entry
types, encoding, grades and two entries: some words of `e` decode to `Y`, and at every entry the
grade's magnitude is at most the entry's format's `NumFormat.safeMax` and `Y`'s value is near
`A`'s within the grade (`DType.Near`). -/
def Encoding.Within {ι : Type} {d : ι → DType} (e : Encoding ι d) (G : ι → Grade)
    (A Y : Ents ι d) : Prop :=
  (∃ W : e.Words, ∀ i, e.decode W i = some (Y i)) ∧
    ∀ i, (G i).mag ≤ (e.fmt i).safeMax ∧ (d i).Near (G i) (some (Y i)) (A i)

/-- Spec `Sp` with rule `r` in place of its own, for every spec and every rule of its domain and
function: the same entries, domain and function. -/
@[implicit_reducible]
def Spec.withRule (Sp : Spec Sz) (r : FloatRule Sp.In Sp.Out Sp.dIn Sp.dOut Sp.Dom Sp.f) :
    Spec Sz :=
  { Sp with rule := r }

/-- A modulus of continuity `ω` of spec `Sp`'s function at size `σ` and encoding `E`, for every
spec, grade function `ω` of its entries, size and encoding: at every inputs `A` in the domain,
grades `G` and inputs `Y` within `G` of `A` at `E`'s inputs (`Encoding.Within`), `Sp.f σ Y` is
within `ω σ E A G` of `Sp.f σ A`, `Y` is in the domain, and some output words of `E` decode to
`Sp.f σ Y`. -/
structure Spec.Modulus (Sp : Spec Sz)
    (ω : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade)
    (σ : Sz) (E : Sp.Encs σ) : Prop where
  /-- Builds `Spec.Modulus Sp ω σ E` from its three fields. -/
  mk ::
  /-- At inputs within the grades, every output of the function is within `ω`'s grade of its
  value at the exact inputs. -/
  near : ∀ A G Y, Sp.Dom σ A → E.inp.Within G A Y →
    ∀ o, (Sp.dOut σ o).Near (ω σ E A G o) (some (Sp.f σ Y o)) (Sp.f σ A o)
  /-- Inputs within the grades of inputs in the domain are in the domain. -/
  dom : ∀ A G Y, Sp.Dom σ A → E.inp.Within G A Y → Sp.Dom σ Y
  /-- At inputs within the grades, the function's value has output words. -/
  rep : ∀ A G Y, Sp.Dom σ A → E.inp.Within G A Y →
    ∃ V : E.out.Words, ∀ o, E.out.decode V o = some (Sp.f σ Y o)

/-- The grade derived from a modulus `ω`, for every spec and grade function `ω` of its entries:
at size `σ`, encoding `E`, exact inputs `A`, grades `G` and output `o`, `ω`'s grade where every
input grade's magnitude is at most its format's `NumFormat.safeMax`, elsewhere
`GPUProof.Grade.onlyIf`'s grade that claims nothing: there an input word may have no value, and
an `exact` rule then claims nothing. -/
noncomputable def Spec.modGrade (Sp : Spec Sz)
    (ω : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade) :
    ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade :=
  fun σ E A G o =>
    Grade.onlyIf (∀ i, (G i).mag ≤ (E.inp.fmt i).safeMax) (E.out.fmt o) (ω σ E A G o)

/-- `Spec.modGrade` grows with the inputs' grades, for every spec and grade function `ω` that does,
at every size, encoding and exact inputs: a larger grade only drops the claim
(`GPUProof.Grade.onlyIf_mono`) or grows `ω`'s. -/
theorem Spec.modGrade_mono (Sp : Spec Sz)
    {ω : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade}
    (mω : ∀ σ E A, Monotone (ω σ E A)) : ∀ σ E A, Monotone (Sp.modGrade ω σ E A) :=
  fun σ E A _ _ h o => Grade.onlyIf_mono (fun hc i => (h i).2.trans (hc i)) _ (mω σ E A h o)

/-- **An `exact` rule gives a graded one through a modulus**, at one size and encoding, for every
spec `Sp` with the `exact` rule, monotone grade function `ω`, size `σ` and encoding `E` at which
`ω` is a modulus (`Spec.Modulus`): output words `W'` that meet the `exact` rule at input words `W`
meet the graded rule `Spec.modGrade ω` there. Where every input grade's magnitude is at most its
format's `NumFormat.safeMax`, every input word decodes to some `Y` within the grades, the `exact`
rule gives `Sp.f σ Y` (the domain and representability fields of the modulus give its premises),
and the modulus puts it within `ω`'s grade; elsewhere `Spec.modGrade` claims nothing. -/
theorem Spec.Modulus.holds {Sp : Spec Sz} (h : Sp.rule = .exact)
    {ω : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade}
    (mω : ∀ σ E A, Monotone (ω σ E A)) {σ : Sz} {E : Sp.Encs σ} (hω : Sp.Modulus ω σ E)
    {W : E.inp.Words} {W' : E.out.Words} (H : Sp.rule.Holds σ E W W') :
    (Sp.withRule (.graded (Sp.modGrade ω) (Sp.modGrade_mono mω))).rule.Holds σ E W W' := by
  rw [h] at H
  show ∀ (A : Ents (Sp.In σ) (Sp.dIn σ)) (G : Sp.In σ → Grade), Sp.Dom σ A →
    (∀ i, Approx (Sp.dIn σ i) (G i) (E.inp.fmt i) (E.inp.decode W i) (A i)) →
      ∀ o, Approx (Sp.dOut σ o) (Grade.onlyIf (∀ i, (G i).mag ≤ (E.inp.fmt i).safeMax)
        (E.out.fmt o) (ω σ E A G o)) (E.out.fmt o) (E.out.decode W' o) (Sp.f σ A o)
  intro A G hD hG o
  by_cases hc : ∀ i, (G i).mag ≤ (E.inp.fmt i).safeMax
  · rw [Grade.onlyIf_pos hc]
    have hY := fun i => (hG i (hc i)).exists_some
    choose Y hY hYn using hY
    have hw : E.inp.Within G A Y := ⟨⟨W, hY⟩, fun i => ⟨hc i, hYn i⟩⟩
    intro _
    rw [H Y hY (hω.dom A G Y hD hw) (hω.rep A G Y hD hw) o]
    exact hω.near A G Y hD hw o
  · exact Approx.onlyIf_neg hc _ _ _ _ _

/-- **An `exact` rule gives a graded one through a modulus**, for every spec `Sp` with the `exact`
rule, monotone grade function `ω`, behaviors `k` and encodings `E` at which `ω` is a modulus at
every size (`Spec.Modulus`): if `k` meets `Sp` at `E`, it meets `Sp` with the graded rule
`Spec.modGrade ω` in place of its own at `E` (`Spec.Modulus.holds`). -/
theorem MeetsAt.graded_of_exact {Sp : Spec Sz} (h : Sp.rule = .exact)
    {ω : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade}
    (mω : ∀ σ E A, Monotone (ω σ E A)) {k : ∀ σ (E : Sp.Encs σ), E.inp.Words → Set E.out.Words}
    {E : ∀ σ, Sp.Encs σ} (hω : ∀ σ, Sp.Modulus ω σ (E σ)) (hk : MeetsAt Sp k E) :
    MeetsAt (Sp.withRule (.graded (Sp.modGrade ω) (Sp.modGrade_mono mω))) k E :=
  fun σ W W' hW => (hω σ).holds h mω (hk σ W W' hW)

/-- Wiring `w` into spec `S₂` with rule `r` in place of its own (`Spec.withRule`), for every
wiring and rule of `S₂`'s domain and function: the same extra inputs, wire and types. -/
def Wiring.withRule {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    (r : FloatRule S₂.In S₂.Out S₂.dIn S₂.dOut S₂.Dom S₂.f) : Wiring S₁ (S₂.withRule r) :=
  ⟨w.Extra, w.dEx, w.wire, w.types⟩

/-- **Composition of a graded rule with an `exact` one**, for every two specs over one size type,
`S₁` with a graded rule `g₁` and `S₂` with the `exact` rule, wiring, monotone grade function `ω`
of `S₂`, behaviors `k₁`, `k₂` and encodings `E₁` of `S₁`, `Ex` of the extra inputs and `Eo` of
`S₂`'s outputs: if `ω` is a modulus of `S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo`
(`Wiring.encs₂`) at every size (`Spec.Modulus`), `k₁` meets `S₁` at `E₁` and `k₂` meets `S₂`
there, then their composition (`Wiring.behav`) meets the composite spec with the graded rule
`Wiring.grade` at `g₁` and `Spec.modGrade ω` at `Wiring.encs`: `MeetsAt.comp` at the wiring into
`S₂` with the derived rule (`Wiring.withRule`, `MeetsAt.graded_of_exact`). With a modulus too
small it fails: MojoProofTest/GPUProof/SpecCompGraded.lean, `sumZero_refused`. -/
theorem MeetsAt.comp_graded_exact {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {m₁ : ∀ σ E A, Monotone (g₁ σ E A)} (h₁ : S₁.rule = .graded g₁ m₁) (h₂ : S₂.rule = .exact)
    {ω : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    (mω : ∀ σ E A, Monotone (ω σ E A)) {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    (hω : ∀ σ, S₂.Modulus ω σ (w.encs₂ E₁ Ex Eo σ)) (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.graded (w.grade E₁ Ex g₁ (S₂.modGrade ω))
        (w.grade_mono E₁ Ex m₁ (S₂.modGrade_mono mω))))
      (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) :=
  MeetsAt.comp (w.withRule (.graded (S₂.modGrade ω) (S₂.modGrade_mono mω))) h₁ rfl E₁ Ex Eo hk₁
    (hk₂.graded_of_exact h₂ mω hω)

/-- **Composition of a graded rule with an `exact` one at every encoding with a modulus**, for
every two specs over one size type, `S₁` with a graded rule `g₁` and `S₂` with the `exact` rule,
wiring, monotone grade function `ω` of `S₂`, behaviors `k₁`, `k₂` and encodings `M` of the
intermediate chosen at each composite encoding: if `k₁` meets `S₁` and `k₂` meets `S₂`, each at
every encoding, then at every composite encodings `E` at which `ω` is a modulus of `S₂` at `M`
and `E`'s extra inputs along the wiring (`Wiring.exEnc`) with `E`'s outputs, at every size
(`Spec.Modulus`, whose `rep` is the outputs' representability premise), their composition with
`M` (`Wiring.behavMid`) meets the composite spec with the graded rule `Wiring.gradeBy` at `g₁`
and `Spec.modGrade ω`, at `E`'s first inputs and `M` (`Wiring.fstEncs`) and `Wiring.exEnc`:
`GPUProof.Meets.comp`'s step at the wiring into `S₂` with the derived rule (`Wiring.withRule`,
`Spec.Modulus.holds`). -/
theorem Meets.comp_graded_exact {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {m₁ : ∀ σ E A, Monotone (g₁ σ E A)} (h₁ : S₁.rule = .graded g₁ m₁) (h₂ : S₂.rule = .exact)
    {ω : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    (mω : ∀ σ E A, Monotone (ω σ E A)) {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words}
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ)) (hk₁ : Meets S₁ k₁) (hk₂ : Meets S₂ k₂)
    {E : ∀ σ, w.Encs σ}
    (hω : ∀ σ, S₂.Modulus ω σ ⟨w.inpEnc σ (M σ (E σ)) (w.exEnc σ (E σ)), (E σ).out⟩) :
    MeetsAt (w.spec (.graded (w.gradeBy (w.fstEncs M) w.exEnc g₁ (S₂.modGrade ω))
        (w.gradeBy_mono _ _ m₁ (S₂.modGrade_mono mω))))
      (w.behavMid k₁ k₂ M) E :=
  fun σ W W' ⟨V, hV, hW'⟩ =>
    (w.withRule (.graded (S₂.modGrade ω) (S₂.modGrade_mono mω))).holds_comp h₁ rfl (w.fstEncs M)
      w.exEnc (W₁ := W) (X := W) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)
      (hk₁ (fun σ => w.fstEncs M σ (E σ)) σ W V hV)
      ((hω σ).holds h₂ mω
        (hk₂ (fun σ => ⟨w.inpEnc σ (M σ (E σ)) (w.exEnc σ (E σ)), (E σ).out⟩) σ _ W' hW'))

end GPUProof
