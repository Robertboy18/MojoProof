import Mathlib.Data.Fintype.Basic
import Mathlib.Order.Monotone.Basic
import FloatLib.Floats.Formats.BinaryInterchange.Model.RealSemantics
import FloatLib.Floats.Formats.BinaryInterchange.Dyadic.Classification
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Finiteness
import GPUProof.NaN

/-!
# The spec layer: entries, formats, grades, encodings, float rules and specs

A spec is mathematics: at every size, typed entries (`DType`, `Ents`), the domain on which its
function is meant, the function, and how float outputs may differ from it (`FloatRule`). A grade
(`Grade`) bounds an error and the magnitudes it needs; `Approx` claims it only when the magnitude
is at most the format's `NumFormat.safeMax`, the largest finite value of a binary interchange
format. `Approx.model` is its form on one FloatLib word, and `Approx.finite_of_le` the range
lemma under its premise, at IEEE formats: a dyadic of magnitude at most the grade's rounds to a
finite word. An
encoding (`Encoding`) says how a kernel stores one side of a spec at one size, entry by entry
(`Encoding.ofScalars`) or all at once. Behaviors meet a spec (`Meets`) at every size and
encoding; `Meets.uniform` is the case of one storage per entry type (`Encodings.uniform`,
`ScalarEnc.std`).

Equality up to NaN payloads is not free. A scalar encoding names its NaN words, which decode to
no value (`ScalarEnc.decode_isNaN`), and its `ScalarEnc.nanEq` is `GPUProof.UpToNaN` at them:
equal, or both NaNs. An encoding of a whole side names its word positions, each with its words and
its NaN words, and its `Encoding.nanEq` is `GPUProof.UpToNaN` at every position, an equivalence
(`Encoding.nanEq_equiv`). Two laws tie the NaN words to the decoder: related words decode alike
(`Encoding.decode_eq`: the decoder reads no payload), and a NaN at a position leaves some entry
with no value, whatever the other positions hold (`Encoding.decode_isNaN`). The entrywise encoding
proves both from its scalars'. So at inputs that decode into the domain a `bitwise` rule asks for
its word function's output words themselves (`FloatRule.Holds.bitwise_eq`), and the outputs of a
`bitwise` rule decode as its word function's (`FloatRule.Holds.bitwise`).

docs/proofs/spec.md gives the plan, what each definition reuses and where it departs from the
design.
-/

namespace GPUProof

open FloatLib.Floats.Formats.BinaryInterchange (FloatFormat Model)

/-- What a spec entry holds, for every spec: a real, an integer or a Boolean. -/
inductive DType where
  /-- A real number. -/
  | real
  /-- An integer. -/
  | int
  /-- A Boolean. -/
  | bool
  deriving DecidableEq

/-- The values of an entry of type `d`, for every type: `ℝ`, `ℤ` or `Bool`. -/
abbrev DType.Val : DType → Type
  | .real => ℝ
  | .int => ℤ
  | .bool => Bool

/-- Entries of index type `ι`, entry `i` of type `d i`, for every index type. -/
abbrev Ents (ι : Type) (d : ι → DType) := (i : ι) → (d i).Val

/-- The format of one stored entry, for every entry, in its first form: a binary interchange
format of FloatLib, an integer of `bits` bits, or a Boolean. -/
inductive NumFormat where
  /-- A binary interchange format. -/
  | ieee (fmt : FloatFormat)
  /-- A two's complement integer of `bits` bits. -/
  | int (bits : Nat)
  /-- A Boolean. -/
  | bool

/-- A grade, for every entry: an absolute error, and a bound on the magnitude of every exact
intermediate with its error. -/
structure Grade where
  /-- The grade with error `err` and magnitude bound `mag`. -/
  mk ::
  /-- The absolute error. -/
  err : ℝ
  /-- The bound on the magnitude of every exact intermediate. -/
  mag : ℝ

/-- Grades are ordered fieldwise, for every two grades. -/
instance : Preorder Grade := Preorder.lift fun g => (g.err, g.mag)

/-- The largest magnitude that a grade's premise accepts, for every format: the largest finite
value of a binary interchange format, `2 ^ (bits - 1) - 1` for an integer of `bits` bits, and `1`
for a Boolean. -/
noncomputable def NumFormat.safeMax : NumFormat → ℝ
  | .ieee fmt => (Model.posMaxFinite fmt).toReal
  | .int bits => 2 ^ (bits - 1) - 1
  | .bool => 1

/-- A decoded value `v` is near the exact value `a` within grade `g`, for every entry type: `v` is
a real within `g.err` of `a`, or is `a` itself (integers and Booleans). -/
def DType.Near : (d : DType) → Grade → Option d.Val → d.Val → Prop
  | .real, g, v, a => ∃ r, v = some r ∧ |r - a| ≤ g.err
  | .int, _, v, a => v = some a
  | .bool, _, v, a => v = some a

/-- The total form of an error bound, for every entry type and format: when the grade's magnitude
is at most the format's `NumFormat.safeMax`, the decoded value `v` is near `a` within `g`. -/
def Approx (d : DType) (g : Grade) (fmt : NumFormat) (v : Option d.Val) (a : d.Val) : Prop :=
  g.mag ≤ fmt.safeMax → d.Near g v a

/-- `Approx` on one word of a binary interchange format, for every format, word, grade and real:
it says that, when the grade's magnitude is at most the format's largest finite value, the word is
finite and within the grade's error of `a`. -/
theorem Approx.model {fmt : FloatFormat} (g : Grade) (w : Model fmt) (a : ℝ) :
    Approx .real g (.ieee fmt) w.toReal? a ↔
      (g.mag ≤ (Model.posMaxFinite fmt).toReal → w.isFinite = true ∧ |w.toReal - a| ≤ g.err) := by
  have h := Model.toDyadic?_isSome_eq_isFinite w
  unfold Approx DType.Near NumFormat.safeMax
  unfold Model.toReal Model.toReal?
  cases hd : Model.toDyadic? w <;> simp_all

/-- **The range lemma**, for every IEEE binary interchange format, grade and dyadic: under
`Approx`'s premise (the grade's magnitude at most the format's `NumFormat.safeMax`), a dyadic of
magnitude at most the grade's rounds to a finite word (FloatLib's
`Model.isFinite_roundDyadic_of_isIEEE_of_abs_toReal_le_posMaxFinite`). -/
theorem Approx.finite_of_le {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {g : Grade}
    (hg : g.mag ≤ (NumFormat.ieee fmt).safeMax) {d : FloatLib.Numerics.Dyadic}
    (hd : |d.toReal| ≤ g.mag) : (Model.roundDyadic fmt d).isFinite = true :=
  Model.isFinite_roundDyadic_of_isIEEE_of_abs_toReal_le_posMaxFinite fmt hfmt d (hd.trans hg)

/-- How one entry is stored, for every entry type: its words, the value each decodes to (`none` at a
NaN, an infinity or a word out of range), which words are NaNs, its format, and the law that a
NaN decodes to no value. -/
structure ScalarEnc (d : DType) where
  /-- Builds `ScalarEnc d` from its five fields. -/
  mk ::
  /-- The words. -/
  Word : Type
  /-- The value of a word, if it has one. -/
  decode : Word → Option d.Val
  /-- The NaN words, whose payloads a `bitwise` rule ignores. -/
  isNaN : Word → Bool
  /-- The format, read by the grades. -/
  fmt : NumFormat
  /-- A NaN decodes to no value. -/
  decode_isNaN : ∀ w, isNaN w = true → decode w = none

/-- Equality up to NaN payloads of the words of scalar encoding `e`, for every entry type and
scalar encoding: `GPUProof.UpToNaN` at `e`'s NaN words, so equal words, or two NaNs. -/
def ScalarEnc.nanEq {d : DType} (e : ScalarEnc d) : e.Word → e.Word → Prop :=
  UpToNaN e.isNaN

/-- Words equal up to NaN payloads decode alike, for every entry type, scalar encoding and two
words: they are equal, or both NaNs, which decode to `none`. -/
theorem ScalarEnc.decode_eq {d : DType} {e : ScalarEnc d} {x y : e.Word} (h : e.nanEq x y) :
    e.decode x = e.decode y := by
  rcases h with rfl | ⟨hx, hy⟩
  · rfl
  · rw [e.decode_isNaN x hx, e.decode_isNaN y hy]

/-- One test format (`ieee fmt`), for every binary interchange format: words `Model fmt`, decoded
by FloatLib's `Model.toReal?`, whose NaNs are FloatLib's `Model.isNaN`. -/
noncomputable def ScalarEnc.ieee (fmt : FloatFormat) : ScalarEnc .real where
  Word := Model fmt
  decode := Model.toReal?
  isNaN := Model.isNaN
  fmt := .ieee fmt
  decode_isNaN w h := by simp [Model.toReal?, Model.toDyadic?_eq_none_of_isNaN h]

/-- Integers of `bits` bits, for every width: words `BitVec bits`, decoded as two's complement,
with no NaN. -/
def ScalarEnc.int (bits : Nat) : ScalarEnc .int where
  Word := BitVec bits
  decode w := some w.toInt
  isNaN _ := false
  fmt := .int bits
  decode_isNaN _ h := absurd h Bool.false_ne_true

/-- Booleans, stored as Booleans with no NaN: one test storage of an entry of type `bool`. -/
def ScalarEnc.bool : ScalarEnc .bool where
  Word := Bool
  decode := some
  isNaN _ := false
  fmt := .bool
  decode_isNaN _ h := absurd h Bool.false_ne_true

/-- One storage per entry type, for every binary interchange format `fmt` and integer width
`bits`: reals as words of `fmt`, integers as `bits`-bit words, Booleans as Booleans. -/
noncomputable def ScalarEnc.std (fmt : FloatFormat) (bits : Nat) : (d : DType) → ScalarEnc d
  | .real => .ieee fmt
  | .int => .int bits
  | .bool => .bool

/-- How a kernel stores one side of a spec at one size, for every index type and entry types: its
word positions, the words and the NaN words at each position, a decoder that reads all positions
at once, each entry's format, and the two laws that tie the NaN words to the decoder: words equal
up to NaN payloads at every position decode alike, and a NaN at a position leaves some entry with
no value. -/
structure Encoding (ι : Type) (d : ι → DType) where
  /-- Builds `Encoding ι d` from its seven fields. -/
  mk ::
  /-- The word positions. -/
  Pos : Type
  /-- The words at each position. -/
  Word : Pos → Type
  /-- The value of each entry, if it has one, from the words at every position. -/
  decode : ((p : Pos) → Word p) → (i : ι) → Option (d i).Val
  /-- The NaN words at each position, whose payloads a `bitwise` rule ignores. -/
  isNaN : (p : Pos) → Word p → Bool
  /-- Each entry's format, read by the grades. -/
  fmt : ι → NumFormat
  /-- Words equal up to NaN payloads at every position (`GPUProof.UpToNaN`) decode alike, at
  every entry: the decoder reads no payload. -/
  decode_eq : ∀ {W W' : (p : Pos) → Word p}, (∀ p, UpToNaN (isNaN p) (W p) (W' p)) →
    decode W = decode W'
  /-- A NaN at a position leaves some entry with no value, whatever the other positions hold. -/
  decode_isNaN : ∀ (W : (p : Pos) → Word p) p, isNaN p (W p) = true → ∃ i, decode W i = none

/-- The words of encoding `e`, for every index type, entry types and encoding: a word at every
position. -/
abbrev Encoding.Words {ι : Type} {d : ι → DType} (e : Encoding ι d) : Type := (p : e.Pos) → e.Word p

/-- Equality up to NaN payloads of the words of encoding `e`, for every index type, entry types
and encoding: `GPUProof.UpToNaN` at every position, at that position's NaN words, so at each
position equal words or two NaNs. -/
def Encoding.nanEq {ι : Type} {d : ι → DType} (e : Encoding ι d) (W W' : e.Words) : Prop :=
  ∀ p, UpToNaN (e.isNaN p) (W p) (W' p)

/-- Equality up to NaN payloads is an equivalence, for every index type, entry types and
encoding: at each position it is `GPUProof.UpToNaN`, an equivalence
(`GPUProof.UpToNaN.equivalence`). -/
theorem Encoding.nanEq_equiv {ι : Type} {d : ι → DType} (e : Encoding ι d) :
    Equivalence e.nanEq :=
  ⟨fun W p => (UpToNaN.equivalence _).refl (W p), fun h p => (UpToNaN.equivalence _).symm (h p),
    fun h h' p => (UpToNaN.equivalence _).trans (h p) (h' p)⟩

/-- The entrywise encoding, for every index type and every storage `e i` of each entry `i`: a
position per entry holding a word of `e i` with `e i`'s NaN words, each decoded alone, so that
words equal up to NaN payloads are `GPUProof.ScalarEnc.nanEq` at every entry. -/
def Encoding.ofScalars {ι : Type} {d : ι → DType} (e : (i : ι) → ScalarEnc (d i)) :
    Encoding ι d where
  Pos := ι
  Word i := (e i).Word
  decode W i := (e i).decode (W i)
  isNaN i := (e i).isNaN
  fmt i := (e i).fmt
  decode_eq h := funext fun i => ScalarEnc.decode_eq (h i)
  decode_isNaN W i h := ⟨i, (e i).decode_isNaN (W i) h⟩

variable {Sz : Type} (In Out : Sz → Type) (dIn : ∀ σ, In σ → DType) (dOut : ∀ σ, Out σ → DType)

/-- The encodings of a spec's inputs and outputs at size `σ`, for every size type. -/
structure Encodings (σ : Sz) where
  /-- Pairs an input and an output encoding at size `σ`. -/
  mk ::
  /-- The inputs' encoding. -/
  inp : Encoding (In σ) (dIn σ)
  /-- The outputs' encoding. -/
  out : Encoding (Out σ) (dOut σ)

/-- A word function `w` on the encodings `E₀` decodes as `f` on `Dom`, for every size type, entry
types, encodings, domain and function: at every size, inputs that decode to `A` in `Dom` give
outputs that decode to `f σ A`. -/
def DecodesAs (Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop)
    (f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ))
    (E₀ : ∀ σ, Encodings In Out dIn dOut σ) (w : ∀ σ, (E₀ σ).inp.Words → (E₀ σ).out.Words) :
    Prop :=
  ∀ σ W (A : Ents (In σ) (dIn σ)), (∀ i, (E₀ σ).inp.decode W i = some (A i)) → Dom σ A →
    ∀ o, (E₀ σ).out.decode (w σ W) o = some (f σ A o)

/-- How float outputs may differ from the mathematics `f` on `Dom`, for every size type, entry
types, domain and function. -/
inductive FloatRule (Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop)
    (f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)) where
  /-- At the encodings `E₀` that the rule names, output words equal, up to NaN payloads, a word
  function `w` of the input words that decodes as `f` on `Dom`: data movement, selection, sign
  changes. -/
  | bitwise (E₀ : ∀ σ, Encodings In Out dIn dOut σ) (w : ∀ σ, (E₀ σ).inp.Words → (E₀ σ).out.Words)
      (hw : DecodesAs In Out dIn dOut Dom f E₀ w)
  /-- On inputs that decode into `Dom`, and whose image under `f` some output words decode to,
  every output decodes to `f` of the decoded inputs. -/
  | exact
  /-- From inputs within grades `G` of exact values `A` in `Dom`, every output is within grade
  `g σ E A G o` of `f σ A o`; the grade grows with the inputs' grades. -/
  | graded (g : ∀ σ, Encodings In Out dIn dOut σ → Ents (In σ) (dIn σ) → (In σ → Grade) →
      Out σ → Grade) (mono : ∀ σ E A, Monotone (g σ E A))

variable {In Out dIn dOut}

/-- What rule `r` says of input words `W` and output words `W'` at size `σ` and encodings `E`,
for every size type, entry types, domain and function. A `bitwise` rule claims only at its own
encodings `E₀ σ`. -/
def FloatRule.Holds {Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop}
    {f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)} :
    FloatRule In Out dIn dOut Dom f → ∀ σ (E : Encodings In Out dIn dOut σ), E.inp.Words →
      E.out.Words → Prop
  | .bitwise E₀ w _, σ, E, W, W' => ∀ h : E = E₀ σ, (E₀ σ).out.nanEq (h ▸ W') (w σ (h ▸ W))
  | .exact, σ, E, W, W' => ∀ A : Ents (In σ) (dIn σ), (∀ i, E.inp.decode W i = some (A i)) →
      Dom σ A → (∃ V, ∀ o, E.out.decode V o = some (f σ A o)) →
        ∀ o, E.out.decode W' o = some (f σ A o)
  | .graded g _, σ, E, W, W' => ∀ (A : Ents (In σ) (dIn σ)) (G : In σ → Grade), Dom σ A →
      (∀ i, Approx (dIn σ i) (G i) (E.inp.fmt i) (E.inp.decode W i) (A i)) →
        ∀ o, Approx (dOut σ o) (g σ E A G o) (E.out.fmt o) (E.out.decode W' o) (f σ A o)

/-- A specification, for every size type: at every size, typed input and output entries indexed
by types (the inputs finite), the domain on which the mathematics is meant, the function, and
the float rule its implementations meet. -/
structure Spec (Sz : Type) where
  /-- Builds `Spec Sz` from its eight fields. -/
  mk ::
  /-- The input entries at each size. -/
  In : Sz → Type
  /-- The output entries at each size. -/
  Out : Sz → Type
  /-- Finitely many inputs at each size. -/
  [fin : ∀ σ, Fintype (In σ)]
  /-- The inputs' types. -/
  dIn : ∀ σ, In σ → DType
  /-- The outputs' types. -/
  dOut : ∀ σ, Out σ → DType
  /-- Where the function is meant. -/
  Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop
  /-- The function. -/
  f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)
  /-- How float outputs may differ from `f`. -/
  rule : FloatRule In Out dIn dOut Dom f

/-- The encodings of spec `Sp`'s entries at size `σ`, for every spec. -/
abbrev Spec.Encs (Sp : Spec Sz) (σ : Sz) := Encodings Sp.In Sp.Out Sp.dIn Sp.dOut σ

/-- Spec `Sp` is met by float behaviors `k` at the encodings `E`, for every spec: at every size,
the output words that `k` allows from input words `W` meet the spec's rule. -/
def MeetsAt (Sp : Spec Sz) (k : ∀ σ (E : Sp.Encs σ), E.inp.Words → Set E.out.Words)
    (E : ∀ σ, Sp.Encs σ) : Prop :=
  ∀ σ W, ∀ W' ∈ k σ (E σ) W, Sp.rule.Holds σ (E σ) W W'

/-- Spec `Sp` is met by float behaviors `k`, for every spec: at every size and every encoding of
its entries. -/
def Meets (Sp : Spec Sz) (k : ∀ σ (E : Sp.Encs σ), E.inp.Words → Set E.out.Words) : Prop :=
  ∀ E, MeetsAt Sp k E

/-- The outputs of a `bitwise` rule decode as its word function's, for every size type, entry
types, domain, function, encodings `E₀`, word function `w` and size `σ`: from the rule at `E₀ σ`
on input words `W` and output words `W'`, and from inputs that decode to `A` in `Dom`, every
output decodes to `f σ A o`. -/
theorem FloatRule.Holds.bitwise {Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop}
    {f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)} {E₀ : ∀ σ, Encodings In Out dIn dOut σ}
    {w : ∀ σ, (E₀ σ).inp.Words → (E₀ σ).out.Words} {hw : DecodesAs In Out dIn dOut Dom f E₀ w}
    {σ : Sz} {W : (E₀ σ).inp.Words} {W' : (E₀ σ).out.Words}
    (h : (FloatRule.bitwise E₀ w hw).Holds σ (E₀ σ) W W') {A : Ents (In σ) (dIn σ)}
    (hA : ∀ i, (E₀ σ).inp.decode W i = some (A i)) (hD : Dom σ A) (o : Out σ) :
    (E₀ σ).out.decode W' o = some (f σ A o) :=
  (congrFun ((E₀ σ).out.decode_eq (h rfl)) o).trans (hw σ W A hA hD o)

/-- At inputs that decode into the domain a `bitwise` rule asks for its word function's output
words themselves, for every size type, entry types, domain, function, encodings `E₀`, word
function `w` and size `σ`: every output of `w σ W` has a value (`hw`), so none of its words is a
NaN (`GPUProof.Encoding.decode_isNaN`), and a word equal up to NaN payloads to a word that is not
a NaN is that word (`GPUProof.UpToNaN.eq`). -/
theorem FloatRule.Holds.bitwise_eq {Dom : ∀ σ, Ents (In σ) (dIn σ) → Prop}
    {f : ∀ σ, Ents (In σ) (dIn σ) → Ents (Out σ) (dOut σ)} {E₀ : ∀ σ, Encodings In Out dIn dOut σ}
    {w : ∀ σ, (E₀ σ).inp.Words → (E₀ σ).out.Words} {hw : DecodesAs In Out dIn dOut Dom f E₀ w}
    {σ : Sz} {W : (E₀ σ).inp.Words} {W' : (E₀ σ).out.Words}
    (h : (FloatRule.bitwise E₀ w hw).Holds σ (E₀ σ) W W') {A : Ents (In σ) (dIn σ)}
    (hA : ∀ i, (E₀ σ).inp.decode W i = some (A i)) (hD : Dom σ A) : W' = w σ W := by
  funext p
  have hp : UpToNaN ((E₀ σ).out.isNaN p) (w σ W p) (W' p) := (UpToNaN.equivalence _).symm (h rfl p)
  cases hn : (E₀ σ).out.isNaN p (w σ W p)
  · exact (hp.eq hn).symm
  · obtain ⟨o, ho⟩ := (E₀ σ).out.decode_isNaN _ p hn
    rw [hw σ W A hA hD o] at ho
    cases ho

/-- The uniform encodings, for every spec: every entry of type `d` stored by `u d`. -/
def Encodings.uniform (Sp : Spec Sz) (u : (d : DType) → ScalarEnc d) (σ : Sz) : Sp.Encs σ :=
  ⟨.ofScalars fun i => u (Sp.dIn σ i), .ofScalars fun o => u (Sp.dOut σ o)⟩

/-- The uniform case, for every spec, behaviors that meet it and storage `u` of each entry type:
the behaviors meet the spec when every entry of type `d` is stored by `u d`. -/
theorem Meets.uniform {Sp : Spec Sz} {k : ∀ σ (E : Sp.Encs σ), E.inp.Words → Set E.out.Words}
    (h : Meets Sp k) (u : (d : DType) → ScalarEnc d) : MeetsAt Sp k (Encodings.uniform Sp u) :=
  h _

end GPUProof
