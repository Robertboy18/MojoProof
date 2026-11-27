import GPUProof.Spec.Basic
import Mathlib.Data.Fintype.Card

/-!
# Two specs composed along a wiring

A wiring (`Wiring S₁ S₂`) feeds the outputs of spec `S₁` into the inputs of spec `S₂`: at every
size, extra inputs with their types, a bijection `wire` of `S₂`'s inputs with `S₁`'s outputs and
the extra inputs, and the law `types` that each input of `S₂` has the type of what it is wired to.
The composite spec (`Wiring.spec`) has `S₁`'s inputs and the extra inputs as inputs and `S₂`'s
outputs as outputs; its function is `S₂`'s at the wired exact intermediate (`Wiring.mid`: `S₁`'s
function at the first inputs, side by side with the extra inputs, read along `wire`), and its
domain is `S₁`'s at the first inputs with `S₂`'s at that intermediate (`Wiring.Dom`), which is
`S₁`'s alone when `S₁` maps its domain into `S₂`'s at every extra input (`Wiring.DomOk`,
`Wiring.dom_iff`). Its outputs are finite wherever `S₂`'s are (`Wiring.spec.fintypeOut`).

The composite's encodings do not fix the intermediate's. So the claim is made either at
encodings built from parts, or at every encoding with the intermediate's encoding as data of the
behavior. At encodings built from parts: for every encodings `E₁` of `S₁`, `Ex` of the extra
inputs and `Eo` of `S₂`'s outputs, the composite's input encoding is `E₁`'s inputs side by side
with `Ex` (`Encoding.sum`), and `S₂`'s input encoding is `E₁`'s outputs side by side with `Ex`,
read along `wire` (`Encoding.reindex`). The composite behavior (`Wiring.behav`) is the relational
composition there: from words of `E₁`'s inputs and of `Ex`, the outputs of `k₂` at some output of
`k₁` and the extra words; at every other encoding it allows every output, so nothing is claimed
there. At every encoding: for every encodings `M σ E` of the intermediate chosen at each
composite encoding `E`, the behavior `Wiring.behavMid` runs `k₁` on `E`'s input words read at
the first inputs (`Encoding.comap`, `Wiring.fstEncs`) with outputs at `M σ E`, and `k₂` on those
outputs beside the same input words read at the extra inputs (`Wiring.exEnc`).

`MeetsAt.comp`: when both rules are graded, behaviors that meet `S₁` at `E₁` and `S₂` at the
wired encodings meet the composite at its encodings, with grade `g₂` at the exact intermediate,
at the grades `g₁` of `S₁`'s outputs and the extra inputs' own grades (`Wiring.grade`), monotone
when `g₁` and `g₂` are (`Wiring.grade_mono`). It needs no bound of an input's magnitude by an
output's: a graded rule's premise at each input is the same implication that the first rule's
conclusion gives at the output wired to it.

`MeetsAt.comp_exact`: when both rules are `exact`, the same behaviors meet the composite with the
`exact` rule, given that the intermediate is representable where the composite's rule makes a
claim (`Wiring.MidRep`): the `exact` rule's premise asks some intermediate words to decode to
`S₁`'s function, which the composite's premise does not give.

`Meets.comp`, `Meets.comp_exact`: the same two compositions at every encoding, for behaviors that
meet their specs at every encoding, with `Wiring.behavMid`; the graded composite's grade is
`Wiring.gradeBy` at the encodings of the parts read from the composite's (`Wiring.grade` is its
case at fixed encodings).

`MeetsAt.comp_exact_graded`, `Meets.comp_exact_graded`: an `exact` rule then a graded one, at
encodings built from parts and at every encoding. The composite's rule is graded, with grade
`Wiring.gradeEx`: where every first input's grade is exact, `g₂` at the exact intermediate with
grade `⟨0, 0⟩` at the wired outputs; elsewhere no claim (`Grade.onlyIf`), since an `exact` rule
says nothing at inexact inputs. The premise is that `S₁`'s outputs are representable where its
inputs decode exactly (`Wiring.FstRep`), which asks less than `Wiring.MidRep`: a graded
conclusion has no premise on a representable output. Both are cases of
`MeetsAt.comp_graded_of_dec`: a first stage whose outputs decode to `S₁`'s function where the
composite's first inputs decode exactly, then a graded rule.

`MeetsAt.comp_bitwise_exact`, `MeetsAt.comp_exact_bitwise`, `MeetsAt.comp_bitwise_graded`: a
`bitwise` rule with an `exact` or graded one, at encodings built from parts, where the `bitwise`
rule's encodings are the parts': `E₁` for a first `bitwise` rule, the wired encodings for a second
one. A first `bitwise` rule's outputs decode as `S₁`'s function wherever its inputs decode
(`FloatRule.Holds.bitwise`), so the pair with an `exact` rule needs no representability premise
and the pair with a graded one has grade `Wiring.gradeEx`; an `exact` rule then a `bitwise` one
needs `Wiring.MidRep`, as `MeetsAt.comp_exact` does. `MeetsAt.comp_bitwise`: two `bitwise` rules
give the `bitwise` rule at `Wiring.encs` with word function `Wiring.bitW` (`S₁`'s word function,
then `S₂`'s on its outputs beside the extra words), which decodes as the composite's function
(`Wiring.bitW_dec`), given that `S₂`'s word function maps words equal up to NaN payloads to words
equal up to NaN payloads: the first rule fixes its output only up to NaN payloads.

The theorems with an `exact` second rule follow from one step at exact decoding
(`Wiring.holds_exact_of_mid`: the first part's outputs decode as `S₁`'s function at every input
the composite's premise allows, and the second rule holds there), and the graded ones from one
composition at one size and encoding (`Wiring.holds_comp`, `Wiring.holds_comp_gradeEx`); each
carries its entrywise premise along the wiring by one lemma (`Wiring.along`, at exact decoding
`Wiring.decode_mid`). A graded rule then an `exact` one needs `S₂`'s function to move little when
its inputs do, which a rule does not name: GPUProof/Spec/CompGraded.lean derives a graded rule
from the `exact` one through a modulus of continuity and composes it as two graded rules.

An output of the composite behavior is an output of `k₁` and one of `k₂` at it
(`Wiring.mem_behav`), and words that decode to the function meet the `exact` rule
(`FloatRule.Holds.exact_of`); tests build outputs from the two.

docs/proofs/spec.md gives the plan and what the composition does not cover.
-/

namespace GPUProof

variable {Sz : Type}

/-- A value of entry type `a` as one of entry type `b`, for every two equal entry types. -/
def DType.cast {a b : DType} (h : a = b) (v : a.Val) : b.Val := h ▸ v

/-- An optional value of entry type `a` as one of entry type `b`, for every two equal entry
types. -/
def DType.castOpt {a b : DType} (h : a = b) (v : Option a.Val) : Option b.Val := h ▸ v

/-- No value stays no value along an equality of entry types, for every two equal entry types. -/
theorem DType.castOpt_none {a b : DType} (h : a = b) : DType.castOpt h none = none := by
  subst h; rfl

/-- An exact value is within the zero grade `⟨0, 0⟩` of itself, for every entry type, format and
value. -/
theorem Approx.some_zero (d : DType) (fmt : NumFormat) (a : d.Val) :
    Approx d ⟨0, 0⟩ fmt (some a) a := by
  intro _
  cases d
  · exact ⟨a, rfl, by simp⟩
  · rfl
  · rfl

/-- Under a grade with error at most `0` and magnitude at most the format's `NumFormat.safeMax`,
`Approx` is an exact decoding, for every entry type, grade, format, decoded and exact value. -/
theorem Approx.eq_some {d : DType} {g : Grade} {fmt : NumFormat} {v : Option d.Val} {a : d.Val}
    (he : g.err ≤ 0) (hm : g.mag ≤ fmt.safeMax) (h : Approx d g fmt v a) : v = some a := by
  cases d
  · obtain ⟨r, rfl, hr⟩ := h hm
    rw [abs_le] at hr
    congr 1
    linarith [hr.1, hr.2]
  · exact h hm
  · exact h hm

/-- Grade `g` where `c` holds, and elsewhere `g` with its magnitude raised above format `fmt`'s
`NumFormat.safeMax`, where `Approx` claims nothing (`Approx.onlyIf_neg`), for every condition,
format and grade. -/
noncomputable def Grade.onlyIf (c : Prop) (fmt : NumFormat) (g : Grade) : Grade :=
  open Classical in if c then g else ⟨g.err, max g.mag (fmt.safeMax + 1)⟩

/-- Where its condition holds, `Grade.onlyIf` is the grade itself, for every condition, format
and grade. -/
theorem Grade.onlyIf_pos {c : Prop} (h : c) (fmt : NumFormat) (g : Grade) :
    Grade.onlyIf c fmt g = g := by
  simp [Grade.onlyIf, h]

/-- Where its condition fails, `Grade.onlyIf` claims nothing in its format, for every condition,
entry type, format, grade, decoded and exact value: its magnitude is above the format's
`NumFormat.safeMax`. -/
theorem Approx.onlyIf_neg {c : Prop} (h : ¬ c) (d : DType) (fmt : NumFormat) (g : Grade)
    (v : Option d.Val) (a : d.Val) : Approx d (Grade.onlyIf c fmt g) fmt v a := by
  intro hm
  simp only [Grade.onlyIf, ite_eq_right h] at hm
  exact absurd ((lt_add_one _).trans_le (le_max_right _ _)) (not_lt.2 hm)

/-- `Grade.onlyIf` claims at most what its grade claims, for every condition `c`, entry type,
grade, format, decoded and exact value: a value `GPUProof.Approx` at `g` in `fmt` is `Approx` at
`Grade.onlyIf c fmt g`, by `Grade.onlyIf_pos` where `c` holds and `Approx.onlyIf_neg` where it
fails. -/
theorem Approx.onlyIf_of {d : DType} {g : Grade} {fmt : NumFormat} {v : Option d.Val} {a : d.Val}
    (c : Prop) (h : Approx d g fmt v a) : Approx d (Grade.onlyIf c fmt g) fmt v a := by
  by_cases hc : c
  · rwa [Grade.onlyIf_pos hc]
  · exact Approx.onlyIf_neg hc _ _ _ _ _

/-- `Grade.onlyIf` grows with its grade and as its condition weakens, for every two conditions
`c`, `c'` with `c'` implying `c`, format and grades `g ≤ g'`. -/
theorem Grade.onlyIf_mono {c c' : Prop} (h : c' → c) (fmt : NumFormat) {g g' : Grade}
    (hg : g ≤ g') : Grade.onlyIf c fmt g ≤ Grade.onlyIf c' fmt g' := by
  have hg' : g.err ≤ g'.err ∧ g.mag ≤ g'.mag := hg
  unfold Grade.onlyIf
  split_ifs with h₁ h₂ h₂
  · exact hg
  · exact ⟨hg'.1, le_max_of_le_left hg'.2⟩
  · exact absurd (h h₂) h₁
  · exact ⟨hg'.1, max_le_max hg'.2 le_rfl⟩

/-- The entries of two index types side by side, for every two index types, entry types and
entries: entry `inl i` is `Y i` and entry `inr j` is `X j`. -/
def Ents.sum {ι₁ ι₂ : Type} {d₁ : ι₁ → DType} {d₂ : ι₂ → DType} (Y : Ents ι₁ d₁)
    (X : Ents ι₂ d₂) : Ents (ι₁ ⊕ ι₂) (Sum.elim d₁ d₂)
  | .inl i => Y i
  | .inr j => X j

/-- Two encodings side by side, for every two index types, entry types and encodings: the
positions of both, each with its own words and NaN words; entry `inl i` decoded by `e₁` from
`e₁`'s positions and entry `inr j` by `e₂` from `e₂`'s, each in its own format. The laws follow
from each encoding's. -/
def Encoding.sum {ι₁ ι₂ : Type} {d₁ : ι₁ → DType} {d₂ : ι₂ → DType} (e₁ : Encoding ι₁ d₁)
    (e₂ : Encoding ι₂ d₂) : Encoding (ι₁ ⊕ ι₂) (Sum.elim d₁ d₂) where
  Pos := e₁.Pos ⊕ e₂.Pos
  Word := Sum.elim e₁.Word e₂.Word
  decode W
    | .inl i => e₁.decode (fun p => W (.inl p)) i
    | .inr j => e₂.decode (fun p => W (.inr p)) j
  isNaN
    | .inl p => e₁.isNaN p
    | .inr p => e₂.isNaN p
  fmt := Sum.elim e₁.fmt e₂.fmt
  decode_eq h := funext fun
    | .inl i => congrFun (e₁.decode_eq fun p => h (.inl p)) i
    | .inr j => congrFun (e₂.decode_eq fun p => h (.inr p)) j
  decode_isNaN W
    | .inl p, h => let ⟨i, hi⟩ := e₁.decode_isNaN (fun p => W (.inl p)) p h; ⟨.inl i, hi⟩
    | .inr p, h => let ⟨j, hj⟩ := e₂.decode_isNaN (fun p => W (.inr p)) p h; ⟨.inr j, hj⟩

/-- The words of two encodings side by side, for every two encodings and words of each: at
position `inl p` the first's, at `inr p` the second's. -/
def Encoding.sumWords {ι₁ ι₂ : Type} {d₁ : ι₁ → DType} {d₂ : ι₂ → DType} {e₁ : Encoding ι₁ d₁}
    {e₂ : Encoding ι₂ d₂} (V : e₁.Words) (X : e₂.Words) : (e₁.sum e₂).Words
  | .inl p => V p
  | .inr p => X p

/-- Encoding `e` read along a bijection `w` of index types, for every two index types, encoding,
bijection and entry types `d'` equal along it to `e`'s: the same positions, words, NaN words and
decoder, entry `i` decoded as entry `w i` of `e` and stored in its format. -/
def Encoding.reindex {ι ι' : Type} {d : ι → DType} {d' : ι' → DType} (e : Encoding ι d)
    (w : ι' ≃ ι) (h : ∀ i, d' i = d (w i)) : Encoding ι' d' where
  Pos := e.Pos
  Word := e.Word
  decode W i := DType.castOpt (h i).symm (e.decode W (w i))
  isNaN := e.isNaN
  fmt i := e.fmt (w i)
  decode_eq hW := congrArg (fun D i => DType.castOpt (h i).symm (D (w i))) (e.decode_eq hW)
  decode_isNaN W p hp := by
    obtain ⟨i, hi⟩ := e.decode_isNaN W p hp
    have hi' : e.decode W (w (w.symm i)) = none := by rw [w.apply_symm_apply]; exact hi
    exact ⟨w.symm i, by rw [hi']; exact DType.castOpt_none _⟩

/-- Encoding `e` read at the entries `g`, for every two index types, encoding and map `g` of
entries: the same positions and words, entry `i` decoded and stored as entry `g i` of `e`, and no
NaN words, since a NaN word of `e` may leave only entries outside `g`'s image with no value. -/
def Encoding.comap {ι ι' : Type} {d : ι → DType} (e : Encoding ι d) (g : ι' → ι) :
    Encoding ι' fun i => d (g i) where
  Pos := e.Pos
  Word := e.Word
  decode W i := e.decode W (g i)
  isNaN _ _ := false
  fmt i := e.fmt (g i)
  decode_eq {W W'} h := by
    obtain rfl : W = W' := funext fun p => (h p).resolve_right fun h' => Bool.false_ne_true h'.1
    rfl
  decode_isNaN _ _ h := absurd h Bool.false_ne_true

/-- A wiring of the outputs of spec `S₁` into the inputs of spec `S₂`, for every two specs over
one size type: at every size, extra inputs with their types, a bijection of `S₂`'s inputs with
`S₁`'s outputs and the extra inputs, and the law that each input of `S₂` has the type of the
output or extra input it is wired to. The extra inputs need no finiteness field: `S₂`'s inputs
are finite, so they are (`Wiring.spec`). -/
structure Wiring (S₁ S₂ : Spec Sz) where
  /-- Builds `Wiring S₁ S₂` from its four fields. -/
  mk ::
  /-- The extra inputs at each size. -/
  Extra : Sz → Type
  /-- The extra inputs' types. -/
  dEx : ∀ σ, Extra σ → DType
  /-- Each input of `S₂` is an output of `S₁` or an extra input. -/
  wire : ∀ σ, S₂.In σ ≃ S₁.Out σ ⊕ Extra σ
  /-- Each input of `S₂` has the type of what it is wired to. -/
  types : ∀ σ i, S₂.dIn σ i = Sum.elim (S₁.dOut σ) (dEx σ) (wire σ i)

namespace Wiring

variable {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)

/-- The composite's inputs at size `σ`, for every wiring: `S₁`'s inputs and the extra inputs. -/
abbrev In (σ : Sz) : Type := S₁.In σ ⊕ w.Extra σ

/-- The composite's input types at size `σ`, for every wiring: `S₁`'s and the extra inputs'. -/
abbrev dIn (σ : Sz) : w.In σ → DType := Sum.elim (S₁.dIn σ) (w.dEx σ)

/-- The inputs of `S₂` along the wiring at size `σ`, for every wiring, values `Y` of `S₁`'s
outputs and `X` of the extra inputs: each input takes the value of what it is wired to. -/
def join (σ : Sz) (Y : Ents (S₁.Out σ) (S₁.dOut σ)) (X : Ents (w.Extra σ) (w.dEx σ)) :
    Ents (S₂.In σ) (S₂.dIn σ) :=
  fun i => DType.cast (w.types σ i).symm (Ents.sum Y X (w.wire σ i))

/-- The grades of `S₂`'s inputs along the wiring at size `σ`, for every wiring, grades `Gy` of
`S₁`'s outputs and `Gx` of the extra inputs: each input takes the grade of what it is wired to. -/
def joinG (σ : Sz) (Gy : S₁.Out σ → Grade) (Gx : w.Extra σ → Grade) : S₂.In σ → Grade :=
  fun i => Sum.elim Gy Gx (w.wire σ i)

/-- The exact intermediate at size `σ`, for every wiring and composite inputs `Z`: `S₁`'s
function at the first inputs and the extra inputs, along the wiring. -/
def mid (σ : Sz) (Z : Ents (w.In σ) (w.dIn σ)) : Ents (S₂.In σ) (S₂.dIn σ) :=
  w.join σ (S₁.f σ fun i => Z (.inl i)) fun x => Z (.inr x)

/-- The composite's domain, for every wiring: `S₁`'s at the first inputs and `S₂`'s at the exact
intermediate. -/
def Dom (σ : Sz) (Z : Ents (w.In σ) (w.dIn σ)) : Prop :=
  S₁.Dom σ (fun i => Z (.inl i)) ∧ S₂.Dom σ (w.mid σ Z)

/-- The composite's function, for every wiring: `S₂`'s at the exact intermediate. -/
def f (σ : Sz) (Z : Ents (w.In σ) (w.dIn σ)) : Ents (S₂.Out σ) (S₂.dOut σ) :=
  S₂.f σ (w.mid σ Z)

/-- `S₁` maps its domain into `S₂`'s along the wiring, for every wiring: at every size, every
inputs in `S₁`'s domain and every extra inputs, the intermediate is in `S₂`'s domain. -/
def DomOk : Prop :=
  ∀ σ A X, S₁.Dom σ A → S₂.Dom σ (w.join σ (S₁.f σ A) X)

/-- Where `S₁` maps its domain into `S₂`'s (`Wiring.DomOk`), the composite's domain is `S₁`'s at
the first inputs, for every wiring, size and composite inputs. -/
theorem dom_iff (hd : w.DomOk) (σ : Sz) (Z : Ents (w.In σ) (w.dIn σ)) :
    w.Dom σ Z ↔ S₁.Dom σ fun i => Z (.inl i) :=
  ⟨And.left, fun h => ⟨h, hd σ _ _ h⟩⟩

/-- The composite spec with rule `r`, for every wiring and rule of its domain and function:
`S₁`'s inputs and the extra inputs, `S₂`'s outputs, the domain `Wiring.Dom` and the function
`Wiring.f`. Its inputs are finite: the extra inputs are, since `S₂`'s are and `wire` is a
bijection with `S₁`'s outputs and the extra inputs (Mathlib's `Fintype.sumRight`). -/
noncomputable def spec (r : FloatRule w.In S₂.Out w.dIn S₂.dOut w.Dom w.f) : Spec Sz where
  In := w.In
  Out := S₂.Out
  fin σ :=
    have := S₁.fin σ
    have := S₂.fin σ
    have := @Fintype.sumRight (S₁.Out σ) _ (Fintype.ofEquiv _ (w.wire σ))
    inferInstance
  dIn := w.dIn
  dOut := S₂.dOut
  Dom := w.Dom
  f := w.f
  rule := r

/-- The composite's outputs are finite wherever `S₂`'s are, for every wiring, rule and size `σ`:
they are `S₂`'s outputs. Instance search does not unfold `Wiring.spec` to find it. -/
instance spec.fintypeOut (r : FloatRule w.In S₂.Out w.dIn S₂.dOut w.Dom w.f) (σ : Sz)
    [h : Fintype (S₂.Out σ)] : Fintype ((w.spec r).Out σ) :=
  h

/-- The composite's encodings at size `σ`, for every wiring. -/
abbrev Encs (σ : Sz) := Encodings w.In S₂.Out w.dIn S₂.dOut σ

/-- The input encoding of `S₂` at size `σ`, for every wiring, encoding `e₁` of `S₁`'s outputs and
`ex` of the extra inputs: the two side by side (`Encoding.sum`), read along `wire`
(`Encoding.reindex`). -/
def inpEnc (σ : Sz) (e₁ : Encoding (S₁.Out σ) (S₁.dOut σ)) (ex : Encoding (w.Extra σ) (w.dEx σ)) :
    Encoding (S₂.In σ) (S₂.dIn σ) :=
  (e₁.sum ex).reindex (w.wire σ) (w.types σ)

/-- The encodings of `S₂` along the wiring, for every wiring, encodings `E₁` of `S₁`, `Ex` of the
extra inputs and `Eo` of `S₂`'s outputs: at every size, `E₁`'s outputs and `Ex` along the wiring
(`Wiring.inpEnc`), and `Eo`. -/
def encs₂ (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)) (σ : Sz) : S₂.Encs σ :=
  ⟨w.inpEnc σ (E₁ σ).out (Ex σ), Eo σ⟩

/-- The composite's encodings, for every wiring, encodings `E₁` of `S₁`, `Ex` of the extra inputs
and `Eo` of `S₂`'s outputs: at every size, `E₁`'s inputs and `Ex` side by side, and `Eo`. -/
def encs (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)) (σ : Sz) : w.Encs σ :=
  ⟨(E₁ σ).inp.sum (Ex σ), Eo σ⟩

/-- The composite's grade at encodings of the parts chosen at each composite encoding, for every
wiring, choices `F₁` of encodings of `S₁` and `Fx` of the extra inputs, and grades `g₁` of `S₁`
and `g₂` of `S₂`: at size `σ`, encoding `E`, exact inputs `Z` and grades `G`, the grade `g₂` at
the encodings `F₁ σ E`'s outputs and `Fx σ E` along the wiring with `E`'s outputs, the exact
intermediate `Wiring.mid`, and as input grades `g₁`'s at `F₁ σ E`, `Z`'s first inputs and their
grades for the wired outputs, the extra inputs' own grades for the rest. -/
def gradeBy (F₁ : ∀ σ, w.Encs σ → S₁.Encs σ)
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    (g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade)
    (g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade) :
    ∀ σ, w.Encs σ → Ents (w.In σ) (w.dIn σ) → (w.In σ → Grade) → S₂.Out σ → Grade :=
  fun σ E Z G => g₂ σ ⟨w.inpEnc σ (F₁ σ E).out (Fx σ E), E.out⟩ (w.mid σ Z)
    (w.joinG σ (g₁ σ (F₁ σ E) (fun i => Z (.inl i)) fun i => G (.inl i)) fun x => G (.inr x))

/-- `Wiring.gradeBy` grows with the inputs' grades, for every wiring, choices `F₁` and `Fx`, and
grades `g₁`, `g₂` that do, at every size, encoding and exact inputs. -/
theorem gradeBy_mono (F₁ : ∀ σ, w.Encs σ → S₁.Encs σ)
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    (m₁ : ∀ σ E A, Monotone (g₁ σ E A)) (m₂ : ∀ σ E A, Monotone (g₂ σ E A)) :
    ∀ σ E A, Monotone (w.gradeBy F₁ Fx g₁ g₂ σ E A) := by
  intro σ E Z G G' h
  refine m₂ σ _ _ fun i => ?_
  unfold joinG
  cases w.wire σ i with
  | inl o => exact m₁ σ (F₁ σ E) _ (fun j => h (.inl j)) o
  | inr x => exact h (.inr x)

/-- The composite's grade, for every wiring, encodings `E₁` of `S₁`, `Ex` of the extra inputs
and grades `g₁` of `S₁` and `g₂` of `S₂`: `Wiring.gradeBy` at `E₁` and `Ex` at every composite
encoding, so at size `σ`, encoding `E`, exact inputs `Z` and grades `G`, the grade `g₂` at the
encodings `E₁`'s outputs and `Ex` along the wiring with `E`'s outputs, the exact intermediate
`Wiring.mid`, and as input grades `g₁`'s at `E₁`, `Z`'s first inputs and their grades for the
wired outputs, the extra inputs' own grades for the rest. It reads `E`'s outputs' encoding
only. -/
def grade (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    (g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade)
    (g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade) :
    ∀ σ, w.Encs σ → Ents (w.In σ) (w.dIn σ) → (w.In σ → Grade) → S₂.Out σ → Grade :=
  w.gradeBy (fun σ _ => E₁ σ) (fun σ _ => Ex σ) g₁ g₂

/-- The composite's grade grows with the inputs' grades, for every wiring, encodings `E₁` and
`Ex`, and grades `g₁`, `g₂` that do, at every size, encoding and exact inputs
(`Wiring.gradeBy_mono`). -/
theorem grade_mono (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    (m₁ : ∀ σ E A, Monotone (g₁ σ E A)) (m₂ : ∀ σ E A, Monotone (g₂ σ E A)) :
    ∀ σ E A, Monotone (w.grade E₁ Ex g₁ g₂ σ E A) :=
  w.gradeBy_mono _ _ m₁ m₂

/-- The composite behavior, for every wiring, behaviors `k₁` of `S₁` and `k₂` of `S₂`, and
encodings `E₁` of `S₁`, `Ex` of the extra inputs and `Eo` of `S₂`'s outputs: at the composite's
encodings `Wiring.encs`, the relational composition, the outputs of `k₂` at the encodings
`Wiring.encs₂` from some output `V` of `k₁` at `E₁` and the extra words; at every other encoding
every output, so that nothing is claimed there. -/
def behav (k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words)
    (k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words) (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)) :
    ∀ σ (E : w.Encs σ), E.inp.Words → Set E.out.Words :=
  fun σ E W => {W' | ∀ h : E = w.encs E₁ Ex Eo σ,
    ∃ V ∈ k₁ σ (E₁ σ) (fun p => (h ▸ W : (w.encs E₁ Ex Eo σ).inp.Words) (.inl p)),
      (h ▸ W' : (w.encs E₁ Ex Eo σ).out.Words) ∈ k₂ σ (w.encs₂ E₁ Ex Eo σ)
        (Encoding.sumWords V fun p => (h ▸ W : (w.encs E₁ Ex Eo σ).inp.Words) (.inr p))}

/-- The intermediate is representable at encoding `M` where the composite's `exact` rule makes a
claim at encodings `E`, for every wiring, composite encodings `E` and encodings `M` of `S₁`'s
outputs: at every size, from input words of `E` that decode to `Z` in the composite's domain,
with some output words of `E` that decode to the composite's function at `Z`, some words of `M`
decode to `S₁`'s function at `Z`'s first inputs. -/
def MidRep (E : ∀ σ, w.Encs σ) (M : ∀ σ, Encoding (S₁.Out σ) (S₁.dOut σ)) : Prop :=
  ∀ σ (W : (E σ).inp.Words) (Z : Ents (w.In σ) (w.dIn σ)),
    (∀ i, (E σ).inp.decode W i = some (Z i)) → w.Dom σ Z →
      (∃ V : (E σ).out.Words, ∀ o, (E σ).out.decode V o = some (w.f σ Z o)) →
        ∃ V : (M σ).Words, ∀ o, (M σ).decode V o = some (S₁.f σ (fun i => Z (.inl i)) o)

/-- The extra inputs' encoding read from a composite encoding, for every wiring, size and
composite encoding `E`: `E`'s inputs at the extra inputs (`Encoding.comap`). -/
def exEnc (σ : Sz) (E : w.Encs σ) : Encoding (w.Extra σ) (w.dEx σ) :=
  E.inp.comap Sum.inr

/-- The encodings of `S₁` read from a composite encoding, for every wiring, encodings `M` of
`S₁`'s outputs chosen at each composite encoding, size and composite encoding `E`: `E`'s inputs
at the first inputs (`Encoding.comap`), and `M σ E`. -/
def fstEncs (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ)) (σ : Sz) (E : w.Encs σ) :
    S₁.Encs σ :=
  ⟨E.inp.comap Sum.inl, M σ E⟩

/-- The composite behavior at every encoding, for every wiring, behaviors `k₁` of `S₁` and `k₂`
of `S₂`, and encodings `M` of the intermediate chosen at each composite encoding: at size `σ`,
encoding `E` and input words `W`, the outputs of `k₂` at `M σ E` and `E`'s extra inputs along
the wiring (`Wiring.exEnc`) with `E`'s outputs, from some output `V` of `k₁` at `E`'s first
inputs and `M σ E` (`Wiring.fstEncs`) and from `W`. -/
def behavMid (k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words)
    (k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words)
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ)) :
    ∀ σ (E : w.Encs σ), E.inp.Words → Set E.out.Words :=
  fun σ E W => {W' | ∃ V ∈ k₁ σ (w.fstEncs M σ E) W,
    W' ∈ k₂ σ ⟨w.inpEnc σ (M σ E) (w.exEnc σ E), E.out⟩ (Encoding.sumWords V W)}

/-- **Entrywise facts carry along the wiring**, for every wiring, size `σ`, relation `R` of an
entry type, grade, format, decoded and exact value, encodings `e₁` of `S₁`'s outputs and `ex` of
the extra inputs, their words `V` and `X`, grades `Gy`, `Gx` and exact values `Y`, `X'`: if `R`
holds at every output of `S₁` and at every extra input, it holds at every input of `S₂`, with the
grade, format, decoded value and exact value read along the wiring (`Wiring.joinG`,
`Wiring.inpEnc`, `Wiring.join`). `Wiring.holds_comp` and `Wiring.holds_comp_gradeEx` use it at
`Approx`, and `Wiring.decode_mid` at exact decoding. -/
theorem along {σ : Sz} (R : ∀ d : DType, Grade → NumFormat → Option d.Val → d.Val → Prop)
    (e₁ : Encoding (S₁.Out σ) (S₁.dOut σ)) (ex : Encoding (w.Extra σ) (w.dEx σ)) {V : e₁.Words}
    {X : ex.Words} {Gy : S₁.Out σ → Grade} {Gx : w.Extra σ → Grade}
    {Y : Ents (S₁.Out σ) (S₁.dOut σ)} {X' : Ents (w.Extra σ) (w.dEx σ)}
    (hy : ∀ o, R (S₁.dOut σ o) (Gy o) (e₁.fmt o) (e₁.decode V o) (Y o))
    (hx : ∀ x, R (w.dEx σ x) (Gx x) (ex.fmt x) (ex.decode X x) (X' x)) (i : S₂.In σ) :
    R (S₂.dIn σ i) (w.joinG σ Gy Gx i) ((w.inpEnc σ e₁ ex).fmt i)
      ((w.inpEnc σ e₁ ex).decode (Encoding.sumWords V X) i) (w.join σ Y X' i) := by
  have key : ∀ j, R (Sum.elim (S₁.dOut σ) (w.dEx σ) j) (Sum.elim Gy Gx j) ((e₁.sum ex).fmt j)
      ((e₁.sum ex).decode (Encoding.sumWords V X) j) (Ents.sum Y X' j) := fun
    | .inl o => hy o
    | .inr x => hx x
  have hc : ∀ {a b : DType} (h : a = b) g fmt v x,
      R b g fmt (DType.castOpt h v) (DType.cast h x) ↔ R a g fmt v x := by
    intro a b h g fmt v x
    subst h
    rfl
  exact (hc (w.types σ i).symm _ _ _ _).2 (key (w.wire σ i))

/-- **Two graded rules compose at one size and encoding**, for every wiring of specs with graded
rules `g₁`, `g₂`, choices `F₁` of encodings of `S₁` and `Fx` of the extra inputs at each
composite encoding, size `σ` and composite encoding `E`: if the words `W₁` of `F₁ σ E`'s inputs
decode as `E`'s input words `W` at the first inputs, and the words `X` of `Fx σ E` as `W` at the
extra inputs, each entry in the same format, then from output words `V` that meet `S₁`'s rule at
`F₁ σ E` and `W₁` and words `W'` that meet `S₂`'s rule at `V` and `X` along the wiring, `W'`
meets the composite's graded rule `Wiring.gradeBy F₁ Fx g₁ g₂` at `E` and `W`. -/
theorem holds_comp
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₁ : ∀ σ E A, Monotone (g₁ σ E A)} {m₂ : ∀ σ E A, Monotone (g₂ σ E A)}
    (h₁ : S₁.rule = .graded g₁ m₁) (h₂ : S₂.rule = .graded g₂ m₂)
    (F₁ : ∀ σ, w.Encs σ → S₁.Encs σ) (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    {σ : Sz} {E : w.Encs σ} {W : E.inp.Words} {W₁ : (F₁ σ E).inp.Words} {X : (Fx σ E).Words}
    (hd₁ : ∀ i, (F₁ σ E).inp.decode W₁ i = E.inp.decode W (.inl i))
    (hf₁ : ∀ i, (F₁ σ E).inp.fmt i = E.inp.fmt (.inl i))
    (hdx : ∀ x, (Fx σ E).decode X x = E.inp.decode W (.inr x))
    (hfx : ∀ x, (Fx σ E).fmt x = E.inp.fmt (.inr x)) {V : (F₁ σ E).out.Words}
    {W' : E.out.Words} (H₁ : S₁.rule.Holds σ (F₁ σ E) W₁ V)
    (H₂ : S₂.rule.Holds σ ⟨w.inpEnc σ (F₁ σ E).out (Fx σ E), E.out⟩ (Encoding.sumWords V X) W') :
    (w.spec (.graded (w.gradeBy F₁ Fx g₁ g₂) (w.gradeBy_mono F₁ Fx m₁ m₂))).rule.Holds σ E W
      W' := by
  rw [h₁] at H₁
  rw [h₂] at H₂
  intro Z G hD hG o
  exact H₂ (w.mid σ Z) _ hD.2 (w.along (fun d g fmt v a => Approx d g fmt v a) _ _
    (fun o₁ => H₁ _ _ hD.1 (fun j => by rw [hf₁, hd₁]; exact hG (.inl j)) o₁)
    (fun x => by rw [hfx, hdx]; exact hG (.inr x))) o

/-- **Exact decodings carry along the wiring**, for every wiring, size `σ`, encodings `e₁` of
`S₁`'s outputs and `ex` of the extra inputs, their words `V` and `X`, and composite inputs `Z`: if
`V` decodes to `S₁`'s function at `Z`'s first inputs and `X` to `Z`'s extra inputs, then `V` and
`X` along the wiring (`Wiring.inpEnc`) decode to the exact intermediate `Wiring.mid σ Z`
(`Wiring.along` at exact decoding). -/
theorem decode_mid {σ : Sz} (e₁ : Encoding (S₁.Out σ) (S₁.dOut σ))
    (ex : Encoding (w.Extra σ) (w.dEx σ)) {V : e₁.Words} {X : ex.Words}
    {Z : Ents (w.In σ) (w.dIn σ)}
    (hV : ∀ o, e₁.decode V o = some (S₁.f σ (fun i => Z (.inl i)) o))
    (hX : ∀ x, ex.decode X x = some (Z (.inr x))) (i : S₂.In σ) :
    (w.inpEnc σ e₁ ex).decode (Encoding.sumWords V X) i = some (w.mid σ Z i) :=
  w.along (fun _ _ _ v a => v = some a) (Gy := fun _ => ⟨0, 0⟩) (Gx := fun _ => ⟨0, 0⟩)
    (Y := S₁.f σ fun i => Z (.inl i)) (X' := fun x => Z (.inr x)) e₁ ex hV hX i

/-- **The first spec's decoding then an `exact` claim compose at one size and encoding**, for
every wiring, size `σ`, composite encoding `E`, encodings `e₁` of `S₁`'s outputs and `ex` of the
extra inputs: if the words `X` of `ex` decode as `E`'s input words `W` at the extra inputs, the
words `V` of `e₁` decode to `S₁`'s function wherever the composite's `exact` rule makes a claim
at `E` and `W` (`hV`), and `W'` meets the `exact` rule of `S₂`'s domain and function at `V` and
`X` along the wiring, then `W'` meets the composite's `exact` rule at `E` and `W`. An `exact`
first rule gives `hV` with the intermediate representable (`Wiring.holds_comp_exact`), and a
`bitwise` one at its own encodings with no premise (`GPUProof.FloatRule.Holds.bitwise`); a
`bitwise` second rule at its own encodings gives the `exact` claim
(`MeetsAt.comp_exact_bitwise`). -/
theorem holds_exact_of_mid {σ : Sz} {E : w.Encs σ} (e₁ : Encoding (S₁.Out σ) (S₁.dOut σ))
    (ex : Encoding (w.Extra σ) (w.dEx σ)) {W : E.inp.Words} {X : ex.Words}
    (hdx : ∀ x, ex.decode X x = E.inp.decode W (.inr x)) {V : e₁.Words} {W' : E.out.Words}
    (hV : ∀ Z : Ents (w.In σ) (w.dIn σ), (∀ i, E.inp.decode W i = some (Z i)) → w.Dom σ Z →
      (∃ V' : E.out.Words, ∀ o, E.out.decode V' o = some (w.f σ Z o)) →
        ∀ o, e₁.decode V o = some (S₁.f σ (fun i => Z (.inl i)) o))
    (H₂ : (FloatRule.exact : FloatRule S₂.In S₂.Out S₂.dIn S₂.dOut S₂.Dom S₂.f).Holds σ
      ⟨w.inpEnc σ e₁ ex, E.out⟩ (Encoding.sumWords V X) W') :
    (w.spec .exact).rule.Holds σ E W W' := by
  intro Z hZ hD hR
  exact H₂ (w.mid σ Z) (w.decode_mid e₁ ex (hV Z hZ hD hR) fun x => (hdx x).trans (hZ (.inr x)))
    hD.2 hR

/-- **Two `exact` rules compose at one size and encoding**, for every wiring of specs with `exact`
rules, size `σ`, composite encoding `E`, encodings `E₁` of `S₁` and `ex` of the extra inputs: if
the words `W₁` of `E₁`'s inputs decode as `E`'s input words `W` at the first inputs, the words
`X` of `ex` as `W` at the extra inputs, and the intermediate is representable at `E₁`'s outputs
where the composite's rule makes a claim at `E` and `W` (`hr`), then from output words `V` that
meet `S₁`'s rule at `E₁` and `W₁` and words `W'` that meet `S₂`'s rule at `V` and `X` along the
wiring, `W'` meets the composite's `exact` rule at `E` and `W` (`Wiring.holds_exact_of_mid`). -/
theorem holds_comp_exact (h₁ : S₁.rule = .exact) (h₂ : S₂.rule = .exact) {σ : Sz}
    {E : w.Encs σ} (E₁ : S₁.Encs σ) (ex : Encoding (w.Extra σ) (w.dEx σ)) {W : E.inp.Words}
    {W₁ : E₁.inp.Words} {X : ex.Words} (hd₁ : ∀ i, E₁.inp.decode W₁ i = E.inp.decode W (.inl i))
    (hdx : ∀ x, ex.decode X x = E.inp.decode W (.inr x))
    (hr : ∀ Z : Ents (w.In σ) (w.dIn σ), (∀ i, E.inp.decode W i = some (Z i)) → w.Dom σ Z →
      (∃ V : E.out.Words, ∀ o, E.out.decode V o = some (w.f σ Z o)) →
        ∃ V : E₁.out.Words, ∀ o, E₁.out.decode V o = some (S₁.f σ (fun i => Z (.inl i)) o))
    {V : E₁.out.Words} {W' : E.out.Words} (H₁ : S₁.rule.Holds σ E₁ W₁ V)
    (H₂ : S₂.rule.Holds σ ⟨w.inpEnc σ E₁.out ex, E.out⟩ (Encoding.sumWords V X) W') :
    (w.spec .exact).rule.Holds σ E W W' := by
  rw [h₁] at H₁
  rw [h₂] at H₂
  exact w.holds_exact_of_mid E₁.out ex hdx
    (fun Z hZ hD hR => H₁ _ (fun i => (hd₁ i).trans (hZ (.inl i))) hD.1 (hr Z hZ hD hR)) H₂

/-- The first spec's outputs are representable at encoding `M` where its first inputs are exact,
for every wiring, composite encodings `E` and encodings `M` of `S₁`'s outputs: at every size,
from input words of `E` that decode exactly to `Z`'s first inputs, with `Z` in the composite's
domain, some words of `M` decode to `S₁`'s function at `Z`'s first inputs. Unlike
`Wiring.MidRep`, it asks nothing of the extra inputs and has no premise on the composite's
outputs: a graded rule's conclusion asks for no representable output. -/
def FstRep (E : ∀ σ, w.Encs σ) (M : ∀ σ, Encoding (S₁.Out σ) (S₁.dOut σ)) : Prop :=
  ∀ σ (W : (E σ).inp.Words) (Z : Ents (w.In σ) (w.dIn σ)),
    (∀ i, (E σ).inp.decode W (.inl i) = some (Z (.inl i))) → w.Dom σ Z →
      ∃ V : (M σ).Words, ∀ o, (M σ).decode V o = some (S₁.f σ (fun i => Z (.inl i)) o)

/-- The composite's grade after an `exact` first rule, for every wiring, encodings `M` of the
intermediate and `Fx` of the extra inputs chosen at each composite encoding, and grade `g₂` of
`S₂`: at size `σ`, encoding `E`, exact inputs `Z` and grades `G`, where every first input's grade
is exact (error at most `0`, magnitude at most its format's `NumFormat.safeMax`), the grade `g₂`
at the encodings `M σ E` and `Fx σ E` along the wiring with `E`'s outputs, the exact intermediate
`Wiring.mid`, and as input grades `⟨0, 0⟩` for the wired outputs and the extra inputs' own grades
for the rest; elsewhere `Grade.onlyIf`'s grade that claims nothing. An `exact` rule claims only
at exactly decoded inputs, so at an inexact first input nothing is known of the intermediate. -/
noncomputable def gradeEx (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    (g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade) :
    ∀ σ, w.Encs σ → Ents (w.In σ) (w.dIn σ) → (w.In σ → Grade) → S₂.Out σ → Grade :=
  fun σ E Z G o => Grade.onlyIf
    (∀ i, (G (.inl i)).err ≤ 0 ∧ (G (.inl i)).mag ≤ (E.inp.fmt (.inl i)).safeMax) (E.out.fmt o)
    (g₂ σ ⟨w.inpEnc σ (M σ E) (Fx σ E), E.out⟩ (w.mid σ Z)
      (w.joinG σ (fun _ => ⟨0, 0⟩) (fun x => G (.inr x))) o)

/-- `Wiring.gradeEx` at exact first inputs is `g₂`'s grade, for every wiring, encodings `M` and
`Fx`, grade `g₂`, size, encoding `E`, exact inputs `Z`, grades `G` whose first inputs' are exact
and output `o`: `g₂` at `M σ E` and `Fx σ E` along the wiring, the exact intermediate, `⟨0, 0⟩`
at the wired outputs and the extra inputs' grades. -/
theorem gradeEx_eq (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    (g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade)
    {σ : Sz} (E : w.Encs σ) (Z : Ents (w.In σ) (w.dIn σ)) {G : w.In σ → Grade}
    (hc : ∀ i, (G (.inl i)).err ≤ 0 ∧ (G (.inl i)).mag ≤ (E.inp.fmt (.inl i)).safeMax)
    (o : S₂.Out σ) :
    w.gradeEx M Fx g₂ σ E Z G o = g₂ σ ⟨w.inpEnc σ (M σ E) (Fx σ E), E.out⟩ (w.mid σ Z)
      (w.joinG σ (fun _ => ⟨0, 0⟩) (fun x => G (.inr x))) o :=
  Grade.onlyIf_pos hc _ _

/-- `Wiring.gradeEx` grows with the inputs' grades, for every wiring, encodings `M` and `Fx`, and
grade `g₂` that does, at every size, encoding and exact inputs: a larger first grade only drops
the claim (`Grade.onlyIf_mono`), and a larger extra grade grows `g₂`'s. -/
theorem gradeEx_mono (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    (m₂ : ∀ σ E A, Monotone (g₂ σ E A)) : ∀ σ E A, Monotone (w.gradeEx M Fx g₂ σ E A) := by
  intro σ E Z G G' h o
  refine Grade.onlyIf_mono (fun hc i => ?_) _ (m₂ σ _ _ (fun i => ?_) o)
  · exact ⟨((h (.inl i)).1).trans (hc i).1, ((h (.inl i)).2).trans (hc i).2⟩
  · unfold joinG
    cases w.wire σ i with
    | inl _ => exact le_rfl
    | inr x => exact h (.inr x)

/-- **An `exact` rule then a graded one compose at one size and encoding**, for every wiring of a
spec `S₁` with a graded spec `S₂` of grade `g₂`, encodings `M` of the intermediate and `Fx` of
the extra inputs chosen at each composite encoding, size `σ` and composite encoding `E`: if the
words `X` of `Fx σ E` decode as `E`'s input words `W` at the extra inputs, each in the same
format, the words `V` of `M σ E` decode to `S₁`'s function wherever `W`'s first inputs decode
exactly into the composite's domain (`hV`, which an `exact` rule gives with `Wiring.FstRep`, and a
`bitwise` one at its own encoding with no premise), and `W'` meets `S₂`'s rule at `V` and `X`
along the wiring, then `W'` meets the composite's graded rule `Wiring.gradeEx M Fx g₂` at `E`
and `W`. -/
theorem holds_comp_gradeEx
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₂ : ∀ σ E A, Monotone (g₂ σ E A)} (h₂ : S₂.rule = .graded g₂ m₂)
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (Fx : ∀ σ, w.Encs σ → Encoding (w.Extra σ) (w.dEx σ))
    {σ : Sz} {E : w.Encs σ} {W : E.inp.Words} {X : (Fx σ E).Words}
    (hdx : ∀ x, (Fx σ E).decode X x = E.inp.decode W (.inr x))
    (hfx : ∀ x, (Fx σ E).fmt x = E.inp.fmt (.inr x)) {V : (M σ E).Words} {W' : E.out.Words}
    (hV : ∀ Z : Ents (w.In σ) (w.dIn σ), (∀ i, E.inp.decode W (.inl i) = some (Z (.inl i))) →
      w.Dom σ Z → ∀ o, (M σ E).decode V o = some (S₁.f σ (fun i => Z (.inl i)) o))
    (H₂ : S₂.rule.Holds σ ⟨w.inpEnc σ (M σ E) (Fx σ E), E.out⟩ (Encoding.sumWords V X) W') :
    (w.spec (.graded (w.gradeEx M Fx g₂) (w.gradeEx_mono M Fx m₂))).rule.Holds σ E W W' := by
  rw [h₂] at H₂
  intro Z G hD hG o
  show Approx _ (w.gradeEx M Fx g₂ σ E Z G o) _ _ _
  by_cases hc : ∀ i, (G (.inl i)).err ≤ 0 ∧ (G (.inl i)).mag ≤ (E.inp.fmt (.inl i)).safeMax
  · rw [w.gradeEx_eq M Fx g₂ E Z hc o]
    have hZ : ∀ i, E.inp.decode W (.inl i) = some (Z (.inl i)) := fun i =>
      Approx.eq_some (hc i).1 (hc i).2 (hG (.inl i))
    exact H₂ (w.mid σ Z) _ hD.2 (w.along (fun d g fmt v a => Approx d g fmt v a) _ _
      (fun o₁ => by rw [hV Z hZ hD o₁]; exact Approx.some_zero _ _ _)
      (fun x => by rw [hfx, hdx]; exact hG (.inr x))) o
  · exact Approx.onlyIf_neg hc _ _ _ _ _

/-- The composite of two word functions along the wiring, for every wiring, encodings `E₁` of
`S₁`, `Ex` of the extra inputs and `Eo` of `S₂`'s outputs, word function `w₁` at `E₁` and `w₂` at
the encodings along the wiring (`Wiring.encs₂`): at size `σ` and words `W` of the composite's
inputs (`Wiring.encs`), `w₂` at `w₁`'s output from `W`'s first inputs and `W`'s extra inputs. -/
def bitW (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)) (w₁ : ∀ σ, (E₁ σ).inp.Words → (E₁ σ).out.Words)
    (w₂ : ∀ σ, (w.encs₂ E₁ Ex Eo σ).inp.Words → (w.encs₂ E₁ Ex Eo σ).out.Words) :
    ∀ σ, (w.encs E₁ Ex Eo σ).inp.Words → (w.encs E₁ Ex Eo σ).out.Words :=
  fun σ W => w₂ σ (Encoding.sumWords (e₁ := (E₁ σ).out) (e₂ := Ex σ) (w₁ σ fun p => W (.inl p))
    fun p => W (.inr p))

/-- The composite word function decodes as the composite's function, for every wiring, encodings
`E₁`, `Ex` and `Eo`, and word functions `w₁` that decodes as `S₁`'s function at `E₁` and `w₂` as
`S₂`'s at the encodings along the wiring: at the composite's encodings (`Wiring.encs`) and inputs
that decode into the composite's domain, `Wiring.bitW` decodes to the composite's function
(`Wiring.decode_mid`). -/
theorem bitW_dec (E₁ : ∀ σ, S₁.Encs σ) (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ))
    (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)) {w₁ : ∀ σ, (E₁ σ).inp.Words → (E₁ σ).out.Words}
    {w₂ : ∀ σ, (w.encs₂ E₁ Ex Eo σ).inp.Words → (w.encs₂ E₁ Ex Eo σ).out.Words}
    (hw₁ : DecodesAs S₁.In S₁.Out S₁.dIn S₁.dOut S₁.Dom S₁.f E₁ w₁)
    (hw₂ : DecodesAs S₂.In S₂.Out S₂.dIn S₂.dOut S₂.Dom S₂.f (w.encs₂ E₁ Ex Eo) w₂) :
    DecodesAs w.In S₂.Out w.dIn S₂.dOut w.Dom w.f (w.encs E₁ Ex Eo) (w.bitW E₁ Ex Eo w₁ w₂) :=
  fun σ W Z hZ hD => hw₂ σ (Encoding.sumWords (e₁ := (E₁ σ).out) (e₂ := Ex σ)
    (w₁ σ fun p => W (.inl p)) fun p => W (.inr p)) (w.mid σ Z)
    (w.decode_mid (E₁ σ).out (Ex σ) (hw₁ σ _ _ (fun i => hZ (.inl i)) hD.1) fun x => hZ (.inr x))
    hD.2

end Wiring

/-- **Composition of graded rules**, for every two specs over one size type with graded rules
`g₁`, `g₂`, wiring, behaviors `k₁`, `k₂` and encodings `E₁` of `S₁`, `Ex` of the extra inputs and
`Eo` of `S₂`'s outputs: if `k₁` meets `S₁` at `E₁` and `k₂` meets `S₂` at `E₁`'s outputs and `Ex`
along the wiring with `Eo` (`Wiring.encs₂`), then their composition (`Wiring.behav`) meets the
composite spec with the graded rule `Wiring.grade` at `E₁`'s inputs and `Ex` side by side with
`Eo` (`Wiring.encs`). No premise bounds an input's magnitude by an output's. -/
theorem MeetsAt.comp {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₁ : ∀ σ E A, Monotone (g₁ σ E A)} {m₂ : ∀ σ E A, Monotone (g₂ σ E A)}
    (h₁ : S₁.rule = .graded g₁ m₁) (h₂ : S₂.rule = .graded g₂ m₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    (hk₁ : MeetsAt S₁ k₁ E₁) (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.graded (w.grade E₁ Ex g₁ g₂) (w.grade_mono E₁ Ex m₁ m₂)))
      (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  exact w.holds_comp h₁ h₂ (fun σ _ => E₁ σ) (fun σ _ => Ex σ) (E := w.encs E₁ Ex Eo σ)
    (W₁ := fun p => W (.inl p)) (X := fun p => W (.inr p)) (fun _ => rfl) (fun _ => rfl)
    (fun _ => rfl) (fun _ => rfl) (hk₁ σ _ V hV) (hk₂ σ _ W' hW')

/-- **Composition of `exact` rules**, for every two specs over one size type with `exact` rules,
wiring, behaviors `k₁`, `k₂` and encodings `E₁` of `S₁`, `Ex` of the extra inputs and `Eo` of
`S₂`'s outputs: if the intermediate is representable at `E₁`'s outputs where the composite's
rule makes a claim at `Wiring.encs` (`Wiring.MidRep`), `k₁` meets `S₁` at `E₁` and `k₂` meets
`S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo` (`Wiring.encs₂`), then their
composition (`Wiring.behav`) meets the composite spec with the `exact` rule at `E₁`'s inputs and
`Ex` side by side with `Eo` (`Wiring.encs`). Without `Wiring.MidRep` it fails:
MojoProofTest/GPUProof/SpecComp.lean, `sumNeg_refused`. -/
theorem MeetsAt.comp_exact {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (h₁ : S₁.rule = .exact)
    (h₂ : S₂.rule = .exact) {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    (hr : w.MidRep (w.encs E₁ Ex Eo) fun σ => (E₁ σ).out) (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec .exact) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  exact w.holds_comp_exact h₁ h₂ (E := w.encs E₁ Ex Eo σ) (E₁ σ) (Ex σ)
    (W₁ := fun p => W (.inl p)) (X := fun p => W (.inr p)) (fun _ => rfl) (fun _ => rfl)
    (hr σ W) (hk₁ σ _ V hV) (hk₂ σ _ W' hW')

/-- **Composition of graded rules at every encoding**, for every two specs over one size type with
graded rules `g₁`, `g₂`, wiring, behaviors `k₁`, `k₂` and encodings `M` of the intermediate
chosen at each composite encoding: if `k₁` meets `S₁` and `k₂` meets `S₂`, each at every
encoding, then their composition with `M` (`Wiring.behavMid`) meets the composite spec at every
encoding, with the graded rule `Wiring.gradeBy` at `E`'s first inputs and `M` (`Wiring.fstEncs`)
and at `E`'s extra inputs (`Wiring.exEnc`). -/
theorem Meets.comp {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₁ : ∀ σ, S₁.Encs σ → Ents (S₁.In σ) (S₁.dIn σ) → (S₁.In σ → Grade) → S₁.Out σ → Grade}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₁ : ∀ σ E A, Monotone (g₁ σ E A)} {m₂ : ∀ σ E A, Monotone (g₂ σ E A)}
    (h₁ : S₁.rule = .graded g₁ m₁) (h₂ : S₂.rule = .graded g₂ m₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words}
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ)) (hk₁ : Meets S₁ k₁) (hk₂ : Meets S₂ k₂) :
    Meets (w.spec (.graded (w.gradeBy (w.fstEncs M) w.exEnc g₁ g₂)
      (w.gradeBy_mono _ _ m₁ m₂))) (w.behavMid k₁ k₂ M) :=
  fun E σ W W' ⟨V, hV, hW'⟩ => w.holds_comp h₁ h₂ (w.fstEncs M) w.exEnc (W₁ := W) (X := W)
    (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)
    (hk₁ (fun σ => w.fstEncs M σ (E σ)) σ W V hV)
    (hk₂ (fun σ => ⟨w.inpEnc σ (M σ (E σ)) (w.exEnc σ (E σ)), (E σ).out⟩) σ _ W' hW')

/-- **Composition of `exact` rules at every encoding**, for every two specs over one size type with
`exact` rules, wiring, behaviors `k₁`, `k₂` and encodings `M` of the intermediate chosen at each
composite encoding: if the intermediate is representable at `M` where the composite's rule makes
a claim, at every composite encoding (`Wiring.MidRep`), and `k₁` meets `S₁` and `k₂` meets `S₂`,
each at every encoding, then their composition with `M` (`Wiring.behavMid`) meets the composite
spec with the `exact` rule at every encoding. Without `Wiring.MidRep` it fails:
MojoProofTest/GPUProof/SpecComp.lean, `sumNeg_refusedAll`. -/
theorem Meets.comp_exact {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (h₁ : S₁.rule = .exact)
    (h₂ : S₂.rule = .exact) {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words}
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (hr : ∀ E, w.MidRep E fun σ => M σ (E σ)) (hk₁ : Meets S₁ k₁) (hk₂ : Meets S₂ k₂) :
    Meets (w.spec .exact) (w.behavMid k₁ k₂ M) :=
  fun E σ W W' ⟨V, hV, hW'⟩ => w.holds_comp_exact h₁ h₂ (w.fstEncs M σ (E σ))
    (w.exEnc σ (E σ)) (W₁ := W) (X := W) (fun _ => rfl) (fun _ => rfl) (hr E σ W)
    (hk₁ (fun σ => w.fstEncs M σ (E σ)) σ W V hV)
    (hk₂ (fun σ => ⟨w.inpEnc σ (M σ (E σ)) (w.exEnc σ (E σ)), (E σ).out⟩) σ _ W' hW')

/-- **Composition with a graded rule after a first stage whose outputs decode exactly**, for
every two specs over one size type, `S₂` with a graded rule `g₂`, wiring, behaviors `k₁`, `k₂` and
encodings `E₁` of `S₁`, `Ex` of the extra inputs and `Eo` of `S₂`'s outputs: if every output `V`
of `k₁` at `E₁` and the first inputs of the composite's words `W` decodes to `S₁`'s function
wherever `W`'s first inputs decode exactly into the composite's domain (`hdec`), and `k₂` meets
`S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo` (`Wiring.encs₂`), then their
composition (`Wiring.behav`) meets the composite spec with the graded rule `Wiring.gradeEx` at
`Wiring.encs`. An `exact` first rule gives `hdec` with `Wiring.FstRep`
(`MeetsAt.comp_exact_graded`), a `bitwise` one with no premise (`MeetsAt.comp_bitwise_graded`). -/
theorem MeetsAt.comp_graded_of_dec {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₂ : ∀ σ E A, Monotone (g₂ σ E A)} (h₂ : S₂.rule = .graded g₂ m₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    (hdec : ∀ σ (W : (w.encs E₁ Ex Eo σ).inp.Words), ∀ V ∈ k₁ σ (E₁ σ) (fun p => W (.inl p)),
      ∀ Z : Ents (w.In σ) (w.dIn σ),
        (∀ i, (w.encs E₁ Ex Eo σ).inp.decode W (.inl i) = some (Z (.inl i))) → w.Dom σ Z →
        ∀ o, (E₁ σ).out.decode V o = some (S₁.f σ (fun i => Z (.inl i)) o))
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.graded (w.gradeEx (fun σ _ => (E₁ σ).out) (fun σ _ => Ex σ) g₂)
      (w.gradeEx_mono _ _ m₂))) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  exact w.holds_comp_gradeEx h₂ (fun σ _ => (E₁ σ).out) (fun σ _ => Ex σ)
    (E := w.encs E₁ Ex Eo σ) (X := fun p => W (.inr p)) (fun _ => rfl) (fun _ => rfl)
    (hdec σ W V hV) (hk₂ σ _ W' hW')

/-- **Composition of an `exact` rule with a graded one**, for every two specs over one size type,
`S₁` with the `exact` rule and `S₂` with a graded rule `g₂`, wiring, behaviors `k₁`, `k₂` and
encodings `E₁` of `S₁`, `Ex` of the extra inputs and `Eo` of `S₂`'s outputs: if `S₁`'s outputs
are representable at `E₁`'s outputs where the first inputs are exact (`Wiring.FstRep`), `k₁`
meets `S₁` at `E₁` and `k₂` meets `S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo`
(`Wiring.encs₂`), then their composition (`Wiring.behav`) meets the composite spec with the
graded rule `Wiring.gradeEx` at `E₁`'s inputs and `Ex` side by side with `Eo` (`Wiring.encs`).
Without `Wiring.FstRep` it fails: MojoProofTest/GPUProof/SpecComp.lean, `sumNegG_refused`. -/
theorem MeetsAt.comp_exact_graded {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₂ : ∀ σ E A, Monotone (g₂ σ E A)} (h₁ : S₁.rule = .exact) (h₂ : S₂.rule = .graded g₂ m₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    (hr : w.FstRep (w.encs E₁ Ex Eo) fun σ => (E₁ σ).out) (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.graded (w.gradeEx (fun σ _ => (E₁ σ).out) (fun σ _ => Ex σ) g₂)
      (w.gradeEx_mono _ _ m₂))) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) :=
  MeetsAt.comp_graded_of_dec w h₂ E₁ Ex Eo (fun σ W V hV Z hZ hD => by
    have H₁ := hk₁ σ _ V hV
    rw [h₁] at H₁
    exact H₁ _ hZ hD.1 (hr σ W Z hZ hD)) hk₂

/-- **Composition of an `exact` rule with a graded one at every encoding**, for every two specs
over one size type, `S₁` with the `exact` rule and `S₂` with a graded rule `g₂`, wiring,
behaviors `k₁`, `k₂` and encodings `M` of the intermediate chosen at each composite encoding: if
`S₁`'s outputs are representable at `M` where the first inputs are exact, at every composite
encoding (`Wiring.FstRep`), and `k₁` meets `S₁` and `k₂` meets `S₂`, each at every encoding, then
their composition with `M` (`Wiring.behavMid`) meets the composite spec at every encoding, with
the graded rule `Wiring.gradeEx` at `M` and `E`'s extra inputs (`Wiring.exEnc`). Without
`Wiring.FstRep` it fails: MojoProofTest/GPUProof/SpecComp.lean, `sumNegG_refusedAll`. -/
theorem Meets.comp_exact_graded {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₂ : ∀ σ E A, Monotone (g₂ σ E A)} (h₁ : S₁.rule = .exact) (h₂ : S₂.rule = .graded g₂ m₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words}
    (M : ∀ σ, w.Encs σ → Encoding (S₁.Out σ) (S₁.dOut σ))
    (hr : ∀ E, w.FstRep E fun σ => M σ (E σ)) (hk₁ : Meets S₁ k₁) (hk₂ : Meets S₂ k₂) :
    Meets (w.spec (.graded (w.gradeEx M w.exEnc g₂) (w.gradeEx_mono M w.exEnc m₂)))
      (w.behavMid k₁ k₂ M) := by
  intro E σ W W' ⟨V, hV, hW'⟩
  have H₁ := hk₁ (fun σ => w.fstEncs M σ (E σ)) σ W V hV
  rw [h₁] at H₁
  exact w.holds_comp_gradeEx h₂ M w.exEnc (X := W) (fun _ => rfl) (fun _ => rfl)
    (fun Z hZ hD => H₁ _ hZ hD.1 (hr E σ W Z hZ hD))
    (hk₂ (fun σ => ⟨w.inpEnc σ (M σ (E σ)) (w.exEnc σ (E σ)), (E σ).out⟩) σ _ W' hW')

/-- **Composition of a `bitwise` rule with an `exact` one**, for every two specs over one size
type, `S₁` with the `bitwise` rule at encodings `E₁` and `S₂` with the `exact` rule, wiring,
encodings `Ex` of the extra inputs and `Eo` of `S₂`'s outputs, and behaviors `k₁`, `k₂`: if `k₁`
meets `S₁` at `E₁` and `k₂` meets `S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo`
(`Wiring.encs₂`), then their composition (`Wiring.behav`) meets the composite spec with the
`exact` rule at `Wiring.encs`. No representability premise: the `bitwise` rule makes `S₁`'s
outputs decode to its function wherever its inputs decode into its domain
(`GPUProof.FloatRule.Holds.bitwise`, `Wiring.holds_exact_of_mid`). -/
theorem MeetsAt.comp_bitwise_exact {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    {w₁ : ∀ σ, (E₁ σ).inp.Words → (E₁ σ).out.Words}
    {hw₁ : DecodesAs S₁.In S₁.Out S₁.dIn S₁.dOut S₁.Dom S₁.f E₁ w₁}
    (h₁ : S₁.rule = .bitwise E₁ w₁ hw₁) (h₂ : S₂.rule = .exact)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec .exact) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  have H₁ := hk₁ σ _ V hV
  have H₂ := hk₂ σ _ W' hW'
  rw [h₁] at H₁
  rw [h₂] at H₂
  exact w.holds_exact_of_mid (E := w.encs E₁ Ex Eo σ) (E₁ σ).out (Ex σ)
    (X := fun p => W (.inr p)) (fun _ => rfl)
    (fun Z hZ hD _ => H₁.bitwise (A := fun i => Z (.inl i)) (fun i => hZ (.inl i)) hD.1) H₂

/-- **Composition of an `exact` rule with a `bitwise` one**, for every two specs over one size
type, `S₁` with the `exact` rule and `S₂` with the `bitwise` rule at the encodings along the
wiring (`Wiring.encs₂` of `E₁`, `Ex` and `Eo`), wiring and behaviors `k₁`, `k₂`: if the
intermediate is representable at `E₁`'s outputs where the composite's rule makes a claim at
`Wiring.encs` (`Wiring.MidRep`), `k₁` meets `S₁` at `E₁` and `k₂` meets `S₂` at its rule's
encodings, then their composition (`Wiring.behav`) meets the composite spec with the `exact` rule
at `Wiring.encs`. The `bitwise` rule gives the `exact` claim at its own encodings
(`GPUProof.FloatRule.Holds.bitwise`, `Wiring.holds_exact_of_mid`). Without `Wiring.MidRep` it
fails: MojoProofTest/GPUProof/SpecComp.lean, `negZ_refused`. -/
theorem MeetsAt.comp_exact_bitwise {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    {w₂ : ∀ σ, (w.encs₂ E₁ Ex Eo σ).inp.Words → (w.encs₂ E₁ Ex Eo σ).out.Words}
    {hw₂ : DecodesAs S₂.In S₂.Out S₂.dIn S₂.dOut S₂.Dom S₂.f (w.encs₂ E₁ Ex Eo) w₂}
    (h₁ : S₁.rule = .exact) (h₂ : S₂.rule = .bitwise (w.encs₂ E₁ Ex Eo) w₂ hw₂)
    (hr : w.MidRep (w.encs E₁ Ex Eo) fun σ => (E₁ σ).out)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec .exact) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  have H₁ := hk₁ σ _ V hV
  have H₂ := hk₂ σ _ W' hW'
  rw [h₁] at H₁
  rw [h₂] at H₂
  exact w.holds_exact_of_mid (E := w.encs E₁ Ex Eo σ) (E₁ σ).out (Ex σ)
    (X := fun p => W (.inr p)) (fun _ => rfl)
    (fun Z hZ hD hR => H₁ _ (fun i => hZ (.inl i)) hD.1 (hr σ W Z hZ hD hR))
    fun A hA hD _ => H₂.bitwise hA hD

/-- **Composition of a `bitwise` rule with a graded one**, for every two specs over one size
type, `S₁` with the `bitwise` rule at encodings `E₁` and `S₂` with a graded rule `g₂`, wiring,
encodings `Ex` of the extra inputs and `Eo` of `S₂`'s outputs, and behaviors `k₁`, `k₂`: if `k₁`
meets `S₁` at `E₁` and `k₂` meets `S₂` at `E₁`'s outputs and `Ex` along the wiring with `Eo`
(`Wiring.encs₂`), then their composition (`Wiring.behav`) meets the composite spec with the graded
rule `Wiring.gradeEx` at `Wiring.encs`. No representability premise: the `bitwise` rule gives
`MeetsAt.comp_graded_of_dec`'s premise `hdec` (`GPUProof.FloatRule.Holds.bitwise`). -/
theorem MeetsAt.comp_bitwise_graded {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    {w₁ : ∀ σ, (E₁ σ).inp.Words → (E₁ σ).out.Words}
    {hw₁ : DecodesAs S₁.In S₁.Out S₁.dIn S₁.dOut S₁.Dom S₁.f E₁ w₁}
    {g₂ : ∀ σ, S₂.Encs σ → Ents (S₂.In σ) (S₂.dIn σ) → (S₂.In σ → Grade) → S₂.Out σ → Grade}
    {m₂ : ∀ σ E A, Monotone (g₂ σ E A)} (h₁ : S₁.rule = .bitwise E₁ w₁ hw₁)
    (h₂ : S₂.rule = .graded g₂ m₂) {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.graded (w.gradeEx (fun σ _ => (E₁ σ).out) (fun σ _ => Ex σ) g₂)
      (w.gradeEx_mono _ _ m₂))) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) :=
  MeetsAt.comp_graded_of_dec w h₂ E₁ Ex Eo (fun σ _ V hV Z hZ hD => by
    have H₁ := hk₁ σ _ V hV
    rw [h₁] at H₁
    exact H₁.bitwise (A := fun i => Z (.inl i)) hZ hD.1) hk₂

/-- **Composition of two `bitwise` rules**, for every two specs over one size type, `S₁` with the
`bitwise` rule at encodings `E₁` and word function `w₁`, `S₂` with the `bitwise` rule at the
encodings along the wiring (`Wiring.encs₂` of `E₁`, `Ex` and `Eo`) and word function `w₂`, wiring
and behaviors `k₁`, `k₂`: if `w₂` maps input words equal up to NaN payloads to output words equal
up to NaN payloads (`hn`), `k₁` meets `S₁` at `E₁` and `k₂` meets `S₂` at its rule's encodings,
then their composition (`Wiring.behav`) meets the composite spec with the `bitwise` rule at
`Wiring.encs` and the composed word function `Wiring.bitW` (`Wiring.bitW_dec`). `S₁`'s outputs
equal `w₁`'s up to NaN payloads at the wired positions, `hn` carries that through `w₂`, and the
two equalities up to NaN payloads compose (`GPUProof.Encoding.nanEq_equiv`). Without `hn` it
fails: MojoProofTest/GPUProof/SpecComp.lean, `nanIdSq_refused`. -/
theorem MeetsAt.comp_bitwise {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂) (E₁ : ∀ σ, S₁.Encs σ)
    (Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)) (Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ))
    {w₁ : ∀ σ, (E₁ σ).inp.Words → (E₁ σ).out.Words}
    {hw₁ : DecodesAs S₁.In S₁.Out S₁.dIn S₁.dOut S₁.Dom S₁.f E₁ w₁}
    {w₂ : ∀ σ, (w.encs₂ E₁ Ex Eo σ).inp.Words → (w.encs₂ E₁ Ex Eo σ).out.Words}
    {hw₂ : DecodesAs S₂.In S₂.Out S₂.dIn S₂.dOut S₂.Dom S₂.f (w.encs₂ E₁ Ex Eo) w₂}
    (h₁ : S₁.rule = .bitwise E₁ w₁ hw₁) (h₂ : S₂.rule = .bitwise (w.encs₂ E₁ Ex Eo) w₂ hw₂)
    (hn : ∀ σ (X Y : (w.encs₂ E₁ Ex Eo σ).inp.Words), (w.encs₂ E₁ Ex Eo σ).inp.nanEq X Y →
      (w.encs₂ E₁ Ex Eo σ).out.nanEq (w₂ σ X) (w₂ σ Y))
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} (hk₁ : MeetsAt S₁ k₁ E₁)
    (hk₂ : MeetsAt S₂ k₂ (w.encs₂ E₁ Ex Eo)) :
    MeetsAt (w.spec (.bitwise (w.encs E₁ Ex Eo) (w.bitW E₁ Ex Eo w₁ w₂)
      (w.bitW_dec E₁ Ex Eo hw₁ hw₂))) (w.behav k₁ k₂ E₁ Ex Eo) (w.encs E₁ Ex Eo) := by
  intro σ W W' hW
  obtain ⟨V, hV, hW'⟩ := hW rfl
  have H₁ := hk₁ σ _ V hV
  have H₂ := hk₂ σ _ W' hW'
  rw [h₁] at H₁
  rw [h₂] at H₂
  intro h
  obtain rfl : h = rfl := rfl
  have hm : ((E₁ σ).out.sum (Ex σ)).nanEq (Encoding.sumWords V fun p => W (.inr p))
      (Encoding.sumWords (w₁ σ fun p => W (.inl p)) fun p => W (.inr p)) := fun
    | .inl p => H₁ rfl p
    | .inr _ => (UpToNaN.equivalence _).refl _
  exact (Eo σ).nanEq_equiv.trans (H₂ rfl) (hn σ _ _ hm)

/-- Words that decode to the function meet the `exact` rule, for every size type, entry types,
domain, function, size and encodings: input words `W` that decode to `Y` and output words `W'`
that decode to `f σ Y` meet it, since the rule's premise fixes its exact inputs to `Y`. -/
theorem FloatRule.Holds.exact_of {In Out : Sz → Type} {dIn : ∀ σ, In σ → DType}
    {dOut : ∀ σ, Out σ → DType} {Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop}
    {f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)} {σ : Sz}
    {E : Encodings In Out dIn dOut σ} {W : E.inp.Words} {W' : E.out.Words}
    {Y : Ents (In σ) (dIn σ)} (hW : ∀ i, E.inp.decode W i = some (Y i))
    (hW' : ∀ o, E.out.decode W' o = some (f σ Y o)) :
    (FloatRule.exact : FloatRule In Out dIn dOut Dom f).Holds σ E W W' := by
  intro A hA _ _ o
  obtain rfl : A = Y := funext fun i => Option.some.inj ((hA i).symm.trans (hW i))
  exact hW' o

/-- An output of the composite behavior, for every wiring, behaviors `k₁` and `k₂`, encodings
`E₁`, `Ex`, `Eo`, size and input words `W` of `Wiring.encs`: an output `V` of `k₁` at `W`'s first
inputs, and an output `W'` of `k₂` at `V` beside `W`'s extra words, make `W'` an output of
`Wiring.behav` at `W`. -/
theorem Wiring.mem_behav {S₁ S₂ : Spec Sz} (w : Wiring S₁ S₂)
    {k₁ : ∀ σ (E : S₁.Encs σ), E.inp.Words → Set E.out.Words}
    {k₂ : ∀ σ (E : S₂.Encs σ), E.inp.Words → Set E.out.Words} {E₁ : ∀ σ, S₁.Encs σ}
    {Ex : ∀ σ, Encoding (w.Extra σ) (w.dEx σ)} {Eo : ∀ σ, Encoding (S₂.Out σ) (S₂.dOut σ)}
    {σ : Sz} {W : (w.encs E₁ Ex Eo σ).inp.Words} {V : (E₁ σ).out.Words}
    {W' : (w.encs E₁ Ex Eo σ).out.Words} (hV : V ∈ k₁ σ (E₁ σ) fun p => W (.inl p))
    (hW' : W' ∈ k₂ σ (w.encs₂ E₁ Ex Eo σ) (Encoding.sumWords V fun p => W (.inr p))) :
    W' ∈ w.behav k₁ k₂ E₁ Ex Eo σ (w.encs E₁ Ex Eo σ) W :=
  fun _ => ⟨V, hV, hW'⟩

end GPUProof
