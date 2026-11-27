import GPUProof.Spec.Basic

/-!
# Spec importers

A spec importer relates a front end's own semantics of its operations to the specs it proposes
for them. `Importer` has the operations of the source (`Src`), each with its sizes (`Sz e`), its
input and output tensors at every size (`SIn e σ`, `SOut e σ`) and its meaning (`denote`), the
source's semantics at the reals, defined before and apart from any spec. `translate` proposes a
spec for each operation it supports and `none` for every other. `readIn` and `readOut` read the
source's tensors as the proposed spec's entries, through the source's own layout of its tensors
(`Importer.ReadIn`, `Importer.ReadOut`: each takes the proof that `translate` proposed that spec,
since the entries' index and entry types are the spec's). `eq` says that on the spec's domain,
at every size, the source's meaning read as entries is the spec's function at the inputs read as
entries. It cannot be closed by `rfl` in general: `denote` exists before the spec and does not
mention it.

`Importer.Graded` states an operation's output words graded against the source's meaning (not
the spec's function), and `Importer.graded_of_holds` gives it from a graded rule that holds, by
`eq`.

The core names no front end. MojoProof/Import/ has the importers, each with its `eq`.
docs/proofs/import.md gives the design's departures and what an importer command generates.
-/

namespace GPUProof

/-- How an importer reads its source's input tensors, for every type of operations `Src`, sizes
`Sz e` per operation, input tensors `SIn e σ` and proposed specs `translate e`: for each operation
`e` and spec `Sp` that `translate` proposes for it, at every size `σ`, a map from the input
tensors to `Sp`'s input entries. -/
abbrev Importer.ReadIn (Src : Type) (Sz : Src → Type) (SIn : (e : Src) → Sz e → Type)
    (translate : (e : Src) → Option (Spec (Sz e))) : Type 1 :=
  ∀ e Sp, translate e = some Sp → ∀ σ, SIn e σ → Ents (Sp.In σ) (Sp.dIn σ)

/-- How an importer reads its source's output tensors, for every type of operations `Src`, sizes
`Sz e` per operation, output tensors `SOut e σ` and proposed specs `translate e`: for each
operation `e` and spec `Sp` that `translate` proposes for it, at every size `σ`, a map from the
output tensors to `Sp`'s output entries. -/
abbrev Importer.ReadOut (Src : Type) (Sz : Src → Type) (SOut : (e : Src) → Sz e → Type)
    (translate : (e : Src) → Option (Spec (Sz e))) : Type 1 :=
  ∀ e Sp, translate e = some Sp → ∀ σ, SOut e σ → Ents (Sp.Out σ) (Sp.dOut σ)

/-- A spec importer, for every front end: the source's operations `Src`, the sizes `Sz e` of each
operation, its input and output tensors `SIn e σ` and `SOut e σ` at every size, its meaning
`denote` in the source's own semantics at the reals, the spec `translate e` it proposes for each
operation (`none` outside the supported fragment), the readings `readIn` and `readOut` of the
tensors as the proposed spec's entries, and `eq`: for every operation `e` with
`translate e = some Sp`, every size `σ` and input tensors `x` whose reading is in `Sp`'s domain,
the reading of `denote e σ x` is `Sp`'s function at the reading of `x`. -/
structure Importer where
  /-- Builds an `Importer` from its nine fields. -/
  mk ::
  /-- The source's operations or programs, in its own syntax. -/
  Src : Type
  /-- The sizes of each operation. -/
  Sz : Src → Type
  /-- The input tensors of each operation at each size. -/
  SIn : (e : Src) → Sz e → Type
  /-- The output tensors of each operation at each size. -/
  SOut : (e : Src) → Sz e → Type
  /-- The source's own meaning of each operation at each size, at the reals. -/
  denote : (e : Src) → ∀ σ, SIn e σ → SOut e σ
  /-- The spec proposed for each operation, `none` outside the supported fragment. -/
  translate : (e : Src) → Option (Spec (Sz e))
  /-- The input tensors read as the proposed spec's input entries. -/
  readIn : Importer.ReadIn Src Sz SIn translate
  /-- The output tensors read as the proposed spec's output entries. -/
  readOut : Importer.ReadOut Src Sz SOut translate
  /-- The source's meaning agrees with the proposed spec on its domain at every size. -/
  eq : ∀ e Sp (h : translate e = some Sp) σ x, Sp.Dom σ (readIn e Sp h σ x) →
    readOut e Sp h σ (denote e σ x) = Sp.f σ (readIn e Sp h σ x)

/-- **Output words graded against the source's meaning**, for every importer `Imp`, operation `e`,
proposed spec `Sp` (`h : Imp.translate e = some Sp`), grade `g` of `Sp`'s graded shape, size `σ`,
encodings `E`, input words `I` and output words `W`: at every input tensors `x` of the source and
input grades `G` at which each input word is `Approx` at its grade of `x`'s reading, each output
word is `Approx` at `g`'s grade of the reading of the source's own meaning `Imp.denote e σ x`. It
names the source's meaning, not `Sp.f`; `Importer.graded_of_holds` gives it from `Sp`'s rule. -/
def Importer.Graded (Imp : Importer) (e : Imp.Src) {Sp : Spec (Imp.Sz e)}
    (h : Imp.translate e = some Sp)
    (g : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade)
    (σ : Imp.Sz e) (E : Sp.Encs σ) (I : E.inp.Words) (W : E.out.Words) : Prop :=
  ∀ x (G : Sp.In σ → Grade),
    (∀ i, Approx (Sp.dIn σ i) (G i) (E.inp.fmt i) (E.inp.decode I i) (Imp.readIn e Sp h σ x i)) →
    ∀ o, Approx (Sp.dOut σ o) (g σ E (Imp.readIn e Sp h σ x) G o) (E.out.fmt o) (E.out.decode W o)
      (Imp.readOut e Sp h σ (Imp.denote e σ x) o)

/-- **A graded rule's words are graded against the source's meaning**: for every importer `Imp`,
operation `e`, proposed spec `Sp` whose rule is `.graded g mono` and whose domain is every input
(`hD`), size `σ`, encodings `E`, input words `I` and output words `W` that meet `Sp`'s rule, `W`
is `Importer.Graded` at `g`: the importer's `eq` turns `Sp.f` at the input tensors' reading into
the reading of the source's meaning. -/
theorem Importer.graded_of_holds (Imp : Importer) (e : Imp.Src) {Sp : Spec (Imp.Sz e)}
    (h : Imp.translate e = some Sp)
    {g : ∀ σ, Sp.Encs σ → Ents (Sp.In σ) (Sp.dIn σ) → (Sp.In σ → Grade) → Sp.Out σ → Grade}
    {mono : ∀ σ E A, Monotone (g σ E A)} (hr : Sp.rule = .graded g mono)
    (hD : ∀ σ A, Sp.Dom σ A) {σ : Imp.Sz e} {E : Sp.Encs σ} {I : E.inp.Words}
    {W : E.out.Words} (hW : Sp.rule.Holds σ E I W) : Imp.Graded e h g σ E I W :=
  fun x G hG o => by
    rw [Imp.eq e Sp h σ x (hD σ _)]
    rw [hr] at hW
    exact hW _ G (hD σ _) hG o

end GPUProof
