import GPUProof.Spec.Linear
import FloatLib.Floats.Formats.BinaryInterchange.Format.Catalog
import FloatLib.Floats.Formats.BinaryInterchange.DirectedSemantics.Basic
import FloatLib.Floats.Formats.BinaryInterchange.Conversion.Cast.Proof
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.SignedSemantics.Core
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Runtime

/-!
# The spec layer on test specs

* A copy spec (`copy`: at every size `n`, `n` real inputs and outputs, the identity, the `exact`
  rule) is met by the behaviors that output words decoding as the input words do, at every size
  and encoding (`copy_meets`), so at the uniform binary32 storage (`copy_meets_binary32`, by
  `GPUProof.Meets.uniform`) and at the uniform bfloat16 storage, whose `GPUProof.NumFormat.safeMax`
  is `255 · 2 ^ 120`, just below binary32's (`copy_meets_bfloat16`).
* `GPUProof.Approx.model` at a NaN, in every binary interchange format with IEEE encoding: with a
  grade of magnitude `0` the canonical NaN meets `GPUProof.Approx` at no real, and with a
  magnitude above `GPUProof.NumFormat.safeMax` every word does (`nan_approx`, and at binary32
  `nan_approx_binary32`).
* The overflow edge in binary32 (`overflow_edge`): a product whose exact value lies above
  `GPUProof.NumFormat.safeMax` rounds to the largest finite word; with a small positive addend
  the unfused result is finite and the fused one infinite. The exact value is above
  `GPUProof.NumFormat.safeMax`, so `GPUProof.Approx` claims nothing there, and every word, both
  results among them, meets it.
* The `exact` rule's premise that some output word decodes to the sum: at two inputs `2 ^ 30` of
  `GPUProof.Spec.sumInt` stored in 32 bits, the 32-bit sum wraps to `-2 ^ 31`, and no output word
  decodes to `2 ^ 31` (`sumInt_wraps`), so the rule claims nothing there.
* A negation spec (`neg fmt`: the `bitwise` rule with every entry stored in the binary
  interchange format `fmt`, with FloatLib's `Model.neg` as its word function) holds of output
  words when each is, up to NaN payloads, the negation of its input (`neg_holds`). It is met by
  negation at every input, NaNs included (`neg_meets`), and its outputs decode to the negated
  inputs, through `GPUProof.FloatRule.Holds.bitwise` (`neg_decode`). In binary32 at one entry and
  in binary16 at two, it refuses an output `1` from the input `1` and accepts, from a NaN input, a
  NaN with another payload and sign (`neg_words`). At a NaN input a finite output breaks it, while
  the `exact` rule says nothing there (`neg_nan_finite`).
* Equality up to NaN payloads that relates every two words is refused: no encoding of Booleans
  with words decoding to `true` and to `false` has NaN words that make it so
  (`bool_total_refused`), and the `bitwise` identity on Booleans refuses an output `false` from
  the input `true`, at every size (`boolId_refuses`).
* The sign of zero (`zero_sign`): binary32 at one position, decoded by FloatLib's `Model.toReal?`
  (`b32 nan h`), with FloatLib's NaNs and with every NaN predicate whose words decode to no real,
  under the `bitwise` identity (`id32 nan h`), refuses `-0` for `+0`, since both decode to `0`
  and so neither can be a NaN (`GPUProof.Encoding.decode_isNaN`,
  `GPUProof.FloatRule.Holds.bitwise_eq`).
* The functions of `GPUProof.Spec.matVec`, `GPUProof.Spec.vecMat` and `GPUProof.Spec.sumReal`
  are Mathlib's sums, for every grade and size (`matVec_f`, `vecMat_f`, `sumReal_f`).
* The underflow allowance of `GPUProof.dotGrade`: at length `1`, exact entries `0` and grades of
  error `0`, in every binary interchange format, the grade's error is `(2 + u) η`, which is
  positive (`dotGrade_one_zero`), where `γ₁ |a x|` alone is `0`. With `GPUProof.matVecGrade`,
  `GPUProof.Spec.matVec` is a spec (`matVecDot`), and with `GPUProof.vecMatGrade`
  `GPUProof.Spec.vecMat` (`vecMatDot`).
-/

open GPUProof
open FloatLib.Floats.Formats.BinaryInterchange (FloatFormat Model)

namespace MojoProofTest.GPUProof.Spec

/-- One test spec (`copy`): at every size `n`, `n` real inputs and `n` real outputs, the
identity, meant everywhere, with the `exact` rule. -/
def copy : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .real
  dOut _ _ := .real
  Dom _ _ := True
  f _ A := A
  rule := .exact

/-- One test behavior: at every size and encoding of `copy`, the output words that decode as the
input words do. -/
def copyK (σ : ℕ) (E : copy.Encs σ) (W : E.inp.Words) : Set E.out.Words :=
  {W' | ∀ o, E.out.decode W' o = E.inp.decode W o}

/-- One test spec (`copy`): `copyK` meets it at every size and encoding. -/
theorem copy_meets : Meets copy copyK := by
  intro E σ W W' hW' A hA _ _ o
  rw [hW' o, hA o]
  rfl

/-- One test spec (`copy`): `copyK` meets it with every entry stored in binary32, through
`GPUProof.Meets.uniform`. -/
theorem copy_meets_binary32 :
    MeetsAt copy copyK (Encodings.uniform copy (ScalarEnc.std .binary32 32)) :=
  copy_meets.uniform _

/-- One test spec (`copy`) at one format (bfloat16): `copyK` meets it with every entry stored in
bfloat16, through `GPUProof.Meets.uniform`, and bfloat16's `GPUProof.NumFormat.safeMax` is
`255 · 2 ^ 120`, eight bits of precision at binary32's largest exponent. -/
theorem copy_meets_bfloat16 :
    MeetsAt copy copyK (Encodings.uniform copy (ScalarEnc.std .bfloat16 16)) ∧
      NumFormat.safeMax (.ieee .bfloat16) = ((255 * 2 ^ 120 : ℚ) : ℝ) :=
  ⟨copy_meets.uniform _, show (Model.posMaxFinite .bfloat16).toReal = _ from
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)⟩

/-- One test encoding family (`negEnc fmt`), for every binary interchange format `fmt`: at every
size `n`, `n` real inputs and `n` real outputs, each stored in `fmt`. -/
noncomputable def negEnc (fmt : FloatFormat) (n : ℕ) :
    Encodings Fin Fin (fun _ _ => .real) (fun _ _ => .real) n :=
  ⟨.ofScalars fun _ => .ieee fmt, .ofScalars fun _ => .ieee fmt⟩

/-- In every binary interchange format, FloatLib's negation of a word that decodes to the real `a`
decodes to `-a`. -/
theorem toReal?_neg {fmt : FloatFormat} {x : Model fmt} {a : ℝ} (h : x.toReal? = some a) :
    (Model.neg x).toReal? = some (-a) := by
  unfold Model.toReal? at h ⊢
  cases hd : Model.toDyadic? x with
  | none => simp [hd] at h
  | some d =>
    simp only [hd, Option.some.injEq] at h
    rw [Model.toDyadic?_neg_of_toDyadic?_some x hd]
    simp [← h]

/-- One test spec family (`neg fmt`), for every binary interchange format `fmt`: at every size
`n`, `n` real inputs and outputs, entrywise negation, meant everywhere, with the `bitwise` rule
at the storage `negEnc fmt` and FloatLib's `Model.neg` as its word function. -/
noncomputable def neg (fmt : FloatFormat) : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .real
  dOut _ _ := .real
  Dom _ _ := True
  f _ A i := -A i
  rule := .bitwise (negEnc fmt) (fun _ W i => Model.neg (W i))
    fun _ W _ hA _ o => toReal?_neg (x := W o) (hA o)

/-- One test spec family (`neg fmt`), for every binary interchange format, size and words: the
`bitwise` rule holds of input words `W` and output words `W'` at `negEnc fmt` exactly when every
output is, up to NaN payloads (`GPUProof.UpToNaN` at FloatLib's `Model.isNaN`), the negation of
its input. -/
theorem neg_holds {fmt : FloatFormat} {n : ℕ} {W W' : Fin n → Model fmt} :
    (neg fmt).rule.Holds n (negEnc fmt n) W W' ↔
      ∀ i, UpToNaN Model.isNaN (W' i) (Model.neg (W i)) :=
  ⟨fun h => h rfl, fun h _ => h⟩

/-- One test spec family (`neg fmt`): FloatLib's negation meets the `bitwise` rule, in every binary
interchange format, at every size and every input, NaNs included. -/
theorem neg_meets (fmt : FloatFormat) (n : ℕ) (W : Fin n → Model fmt) :
    (neg fmt).rule.Holds n (negEnc fmt n) W fun i => Model.neg (W i) :=
  neg_holds.2 (((negEnc fmt n).out.nanEq_equiv.refl fun i => Model.neg (W i)) ·)

/-- One test spec family (`neg fmt`), for every binary interchange format, size and words meeting
its rule: from inputs that decode to the reals `A`, every output decodes to `-A o`
(`GPUProof.FloatRule.Holds.bitwise`). -/
theorem neg_decode {fmt : FloatFormat} {n : ℕ} {W W' : Fin n → Model fmt}
    (h : (neg fmt).rule.Holds n (negEnc fmt n) W W') {A : Fin n → ℝ}
    (hA : ∀ i, (W i).toReal? = some (A i)) (o : Fin n) : (W' o).toReal? = some (-A o) :=
  FloatRule.Holds.bitwise h hA trivial o

/-- One test spec family (`neg fmt`) at two formats of different widths: in binary32 at size `1`,
and in binary16 at size `2`, the output `1` (words `0x3F800000`, `0x3C00`) from the input `1`
does not meet the `bitwise` rule, its value being `1`, not `-1`; from the canonical NaN, a NaN
with another payload and sign (`0x7FC00001`, `0x7E01`; the negated NaN is `0xFFC00000`,
`0xFE00`) does. -/
theorem neg_words :
    (¬ (neg .binary32).rule.Holds 1 (negEnc .binary32 1)
        (fun _ => Model.ofBits 0x3F800000 : Fin 1 → Model .binary32)
        (fun _ => Model.ofBits 0x3F800000 : Fin 1 → Model .binary32) ∧
      (neg .binary32).rule.Holds 1 (negEnc .binary32 1)
        (fun _ => Model.canonicalNaN .binary32 : Fin 1 → Model .binary32)
        (fun _ => Model.ofBits 0x7FC00001 : Fin 1 → Model .binary32)) ∧
    (¬ (neg .binary16).rule.Holds 2 (negEnc .binary16 2)
        (![Model.ofBits 0x3C00, Model.canonicalNaN _] : Fin 2 → Model .binary16)
        (![Model.ofBits 0x3C00, Model.ofBits 0x7E01] : Fin 2 → Model .binary16) ∧
      (neg .binary16).rule.Holds 2 (negEnc .binary16 2)
        (![Model.ofBits 0x3C00, Model.canonicalNaN _] : Fin 2 → Model .binary16)
        (![Model.ofBits 0xBC00, Model.ofBits 0x7E01] : Fin 2 → Model .binary16)) := by
  refine ⟨⟨fun h => ?_, neg_holds.2 fun _ => ?_⟩, ⟨fun h => ?_, neg_holds.2 ?_⟩⟩
  · have h0 := neg_holds.1 h 0
    revert h0
    unfold UpToNaN
    decide
  · unfold UpToNaN
    decide
  · have h0 := neg_holds.1 h 0
    revert h0
    unfold UpToNaN
    decide
  · refine Fin.forall_fin_two.2 ⟨?_, ?_⟩ <;> unfold UpToNaN <;> decide

/-- One test spec family (`neg fmt`) at size `1` and the canonical NaN of binary32 as input: the
finite output `Model.posMaxFinite` does not meet the `bitwise` rule, while the `exact` rule with
`neg`'s domain and function says nothing there, since the input decodes to no real. -/
theorem neg_nan_finite :
    ¬ (neg .binary32).rule.Holds 1 (negEnc .binary32 1) (fun _ => Model.canonicalNaN .binary32)
        (fun _ => Model.posMaxFinite .binary32) ∧
      (FloatRule.exact : FloatRule (neg .binary32).In (neg .binary32).Out (neg .binary32).dIn
          (neg .binary32).dOut (neg .binary32).Dom (neg .binary32).f).Holds 1
        (negEnc .binary32 1) (fun _ => Model.canonicalNaN .binary32)
        (fun _ => Model.posMaxFinite .binary32) := by
  have hmax := Model.isNaN_eq_false_of_isFinite_eq_true _ (Model.isFinite_posMaxFinite .binary32)
  refine ⟨fun h => ?_, fun A hA _ _ => ?_⟩
  · rcases neg_holds.1 h 0 with h | ⟨h, _⟩
    · have := congrArg Model.isNaN h
      simp [Model.isNaN_canonicalNaN (fmt := .binary32) rfl, hmax] at this
    · simp [hmax] at h
  · have := hA (0 : Fin 1)
    simp [negEnc, Encoding.ofScalars, ScalarEnc.ieee, Model.toReal?,
      Model.toDyadic?_eq_none_of_isNaN (Model.isNaN_canonicalNaN (fmt := .binary32) rfl)] at this

/-- Equality up to NaN payloads that relates every two words refused, at every size: no encoding
of `n + 1` Booleans with a word that decodes to `true` and a word that decodes to `false` at entry
`0` has NaN words that relate every two words, since related words decode alike
(`GPUProof.Encoding.decode_eq`). -/
theorem bool_total_refused (n : ℕ) (E : Encoding (Fin (n + 1)) fun _ => .bool) {W W' : E.Words}
    (hW : E.decode W 0 = some true) (hW' : E.decode W' 0 = some false) :
    ¬ ∀ V V', E.nanEq V V' := fun h => by
  simpa [hW, hW'] using congrFun (E.decode_eq (h W W')) 0

/-- One test encoding family (`boolEnc`): at every size `n`, `n` Boolean inputs and outputs, each
stored as a Boolean (`GPUProof.ScalarEnc.bool`). -/
def boolEnc (n : ℕ) : Encodings Fin Fin (fun _ _ => .bool) (fun _ _ => .bool) n :=
  ⟨.ofScalars fun _ => .bool, .ofScalars fun _ => .bool⟩

/-- One test spec (`boolId`): at every size `n`, `n` Boolean inputs and outputs, the identity,
meant everywhere, with the `bitwise` rule at `boolEnc` and the identity as its word function. -/
def boolId : Spec ℕ where
  In := Fin
  Out := Fin
  dIn _ _ := .bool
  dOut _ _ := .bool
  Dom _ _ := True
  f _ A := A
  rule := .bitwise boolEnc (fun _ W => W) fun _ _ _ hA _ o => hA o

/-- One test spec (`boolId`), at every size `n + 1`: the output `false` at every entry, from the
input `true` at every entry, does not meet the `bitwise` rule, as the Booleans have no NaN. -/
theorem boolId_refuses (n : ℕ) :
    ¬ boolId.rule.Holds (n + 1) (boolEnc (n + 1)) (fun _ => true) fun _ => false :=
  fun h => by
    rcases h rfl (0 : Fin (n + 1)) with h | ⟨h, _⟩
    · exact Bool.false_ne_true h
    · exact Bool.false_ne_true h

/-- One test encoding family (`b32 nan h`), for every predicate `nan` on binary32 words of which
every word decodes to no real (`h`): one real entry at one position, stored as a binary32 word,
decoded by FloatLib's `Model.toReal?`, with the NaN words `nan`. At FloatLib's `Model.isNaN` it is
the entrywise encoding of `GPUProof.ScalarEnc.ieee`. -/
noncomputable def b32 (nan : Model .binary32 → Bool) (h : ∀ w, nan w = true → w.toReal? = none) :
    Encoding Unit fun _ => .real :=
  .ofScalars fun _ => ⟨Model .binary32, Model.toReal?, nan, .ieee .binary32, h⟩

/-- One test spec family (`id32 nan h`), for every NaN predicate of `b32`: at the one size, one
real input and one real output, the identity, meant everywhere, with the `bitwise` rule at
`b32 nan h` and the identity as its word function. -/
noncomputable def id32 (nan : Model .binary32 → Bool) (h : ∀ w, nan w = true → w.toReal? = none) :
    Spec Unit where
  In _ := Unit
  Out _ := Unit
  dIn _ _ := .real
  dOut _ _ := .real
  Dom _ _ := True
  f _ A := A
  rule := .bitwise (fun _ => ⟨b32 nan h, b32 nan h⟩) (fun _ W => W) fun _ _ _ hA _ o => hA o

/-- One test spec family (`id32 nan h`) at the sign of zero, with FloatLib's NaNs and with every
NaN predicate of `b32`: the `bitwise` identity refuses the output `-0` (word `0x80000000`) from
the input `+0` (`0x00000000`). The input decodes to the real `0`, so the identity's output has no
NaN word (`GPUProof.Encoding.decode_isNaN`) and the rule asks for that word itself
(`GPUProof.FloatRule.Holds.bitwise_eq`): no NaN predicate can relate `+0` and `-0`, which decode
to `0`. -/
theorem zero_sign :
    ¬ (id32 Model.isNaN (ScalarEnc.ieee .binary32).decode_isNaN).rule.Holds ()
        ⟨b32 _ (ScalarEnc.ieee .binary32).decode_isNaN,
          b32 _ (ScalarEnc.ieee .binary32).decode_isNaN⟩
        (fun _ => (Model.ofBits 0x00000000 : Model .binary32))
        (fun _ => (Model.ofBits 0x80000000 : Model .binary32)) ∧
      ∀ nan h, ¬ (id32 nan h).rule.Holds () ⟨b32 nan h, b32 nan h⟩
        (fun _ => (Model.ofBits 0x00000000 : Model .binary32))
        (fun _ => (Model.ofBits 0x80000000 : Model .binary32)) := by
  have key : ∀ nan h, ¬ (id32 nan h).rule.Holds () ⟨b32 nan h, b32 nan h⟩
      (fun _ => (Model.ofBits 0x00000000 : Model .binary32))
      (fun _ => (Model.ofBits 0x80000000 : Model .binary32)) := by
    intro nan h hH
    obtain ⟨d, hd⟩ : ∃ d, Model.toDyadic? (Model.ofBits 0x00000000 : Model .binary32) = some d :=
      Option.isSome_iff_exists.1 (by decide +kernel)
    have e : (Model.ofBits 0x80000000 : Model .binary32) = Model.ofBits 0x00000000 :=
      congrFun (FloatRule.Holds.bitwise_eq hH (A := fun _ => d.toReal) (fun _ => by
        dsimp only [b32, Encoding.ofScalars]
        unfold Model.toReal?
        simp only [hd]
        rfl) trivial) ()
    exact absurd e (by decide)
  exact ⟨key _ _, key⟩

/-- Every binary interchange format with IEEE encoding: with a grade of magnitude `0`, at most
the format's `GPUProof.NumFormat.safeMax`, the canonical NaN meets `GPUProof.Approx` at no real;
with a magnitude above it, every word meets it at every real. -/
theorem nan_approx {fmt : FloatFormat} (hfmt : fmt.encoding = .ieee) (a : ℝ) :
    ¬ Approx .real ⟨0, 0⟩ (.ieee fmt) (Model.canonicalNaN fmt).toReal? a ∧
      ∀ (w : Model fmt) (g : Grade), (Model.posMaxFinite fmt).toReal < g.mag →
        Approx .real g (.ieee fmt) w.toReal? a := by
  refine ⟨fun h => ?_, fun w g hg => (Approx.model g w a).2 fun h => absurd h (not_le.2 hg)⟩
  have := ((Approx.model _ _ a).1 h (Model.toReal_posMaxFinite_pos _).le).1
  simp [Model.isFinite_canonicalNaN hfmt] at this

/-- One test format (binary32): `nan_approx` at binary32 and the real `0`. -/
theorem nan_approx_binary32 :
    ¬ Approx .real ⟨0, 0⟩ (.ieee .binary32) (Model.canonicalNaN .binary32).toReal? 0 ∧
      ∀ (w : Model .binary32) (g : Grade), (Model.posMaxFinite .binary32).toReal < g.mag →
        Approx .real g (.ieee .binary32) w.toReal? 0 :=
  nan_approx rfl 0

/-- One test word (binary32) of the overflow edge: `8390108`, that is `(2 ^ 23 + 1500) · 2 ^ 0`. -/
def edgeX : Model .binary32 := Model.ofNatBits 0x4B0005DC

/-- One test word (binary32) of the overflow edge: `16774216 · 2 ^ 81`, that is
`(2 ^ 24 - 3000) · 2 ^ 81`, so that the exact product with `edgeX` is `(2 ^ 47 - 4500000) · 2 ^ 81`,
between the largest finite value `(2 ^ 47 - 2 ^ 23) · 2 ^ 81` and the overflow threshold
`(2 ^ 47 - 2 ^ 22) · 2 ^ 81`. -/
def edgeY : Model .binary32 := Model.ofNatBits 0x73FFF448

/-- One test word (binary32) of the overflow edge: the addend `2 ^ 100`, below half an ulp of the
largest finite value (`2 ^ 103`) and above the distance from the exact product of `edgeX` and
`edgeY` to the overflow threshold. -/
def edgeC : Model .binary32 := Model.ofNatBits 0x71800000

/-- One test format (binary32) at the overflow edge: the exact product of `edgeX` and `edgeY` lies
above the largest finite value and rounds to it; adding `edgeC` to the rounded product gives a
finite word, and the fused multiply-add of the three is infinite. The exact value is above
`GPUProof.NumFormat.safeMax`, so at every grade whose magnitude bounds it `GPUProof.Approx` holds
of every word, both results among them. -/
theorem overflow_edge :
    (Model.posMaxFinite .binary32).toReal < edgeX.toReal * edgeY.toReal ∧
      Model.mul edgeX edgeY = Model.posMaxFinite .binary32 ∧
      (Model.add (Model.mul edgeX edgeY) edgeC).isFinite = true ∧
      (Model.fma edgeX edgeY edgeC).isFinite = false ∧
      ∀ (w : Model .binary32) (g : Grade), edgeX.toReal * edgeY.toReal + edgeC.toReal ≤ g.mag →
        Approx .real g (.ieee .binary32) w.toReal?
          (edgeX.toReal * edgeY.toReal + edgeC.toReal) := by
  have hx : edgeX.toReal = ((8390108 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  have hy : edgeY.toReal = ((16774216 * 2 ^ 81 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  have hc : edgeC.toReal = ((2 ^ 100 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  have hm : (Model.posMaxFinite .binary32).toReal = (((2 ^ 24 - 1) * 2 ^ 104 : ℚ) : ℝ) :=
    Model.Algebraic.toReal_of_toRat?_eq_some (by decide +kernel)
  refine ⟨?_, by decide +kernel, by decide +kernel, by decide +kernel, fun w g hg => ?_⟩
  · rw [hx, hy, hm]; norm_num
  · refine (Approx.model g w _).2 fun h => ?_
    rw [hm] at h
    rw [hx, hy, hc] at hg
    exact absurd (hg.trans h) (by norm_num)

/-- One test spec (`GPUProof.Spec.sumInt`) at two inputs of `2 ^ 30`, with integers stored in 32
bits: the 32-bit sum of the inputs decodes to `-2 ^ 31`, and no output word decodes to their sum,
so the `exact` rule claims nothing there. -/
theorem sumInt_wraps :
    (2 ^ 30 + 2 ^ 30 : BitVec 32).toInt = -2 ^ 31 ∧
      ¬ ∃ V : (Encodings.uniform Spec.sumInt (ScalarEnc.std .binary32 32) 2).out.Words,
        ∀ o, (Encodings.uniform Spec.sumInt (ScalarEnc.std .binary32 32) 2).out.decode V o =
          some (Spec.sumInt.f 2 (fun _ => (2 ^ 30 : ℤ)) o) := by
  refine ⟨by decide, fun ⟨V, hV⟩ => ?_⟩
  have h : (V () : BitVec 32).toInt = 2 ^ 31 := by
    simpa [Encodings.uniform, Encoding.ofScalars, ScalarEnc.std, ScalarEnc.int, Spec.sumInt,
      Fin.sum_univ_two] using hV ()
  exact absurd (BitVec.toInt_lt (x := (V () : BitVec 32))) (by omega)

/-- One test spec family (`GPUProof.Spec.matVec`), for every grade and size: output `i` is
`∑ k, A i k * x k`. -/
theorem matVec_f {g} {mono} (m n : ℕ) (X : Fin m × Fin n ⊕ Fin n → ℝ) (i : Fin m) :
    (Spec.matVec g mono).f (m, n) X i = ∑ k, X (.inl (i, k)) * X (.inr k) :=
  rfl

/-- One test spec family (`GPUProof.Spec.vecMat`), for every grade and size: output `j` is
`∑ i, x i * A i j`. -/
theorem vecMat_f {g} {mono} (m n : ℕ) (X : Fin m ⊕ Fin m × Fin n → ℝ) (j : Fin n) :
    (Spec.vecMat g mono).f (m, n) X j = ∑ i, X (.inl i) * X (.inr (i, j)) :=
  rfl

/-- One test spec family (`GPUProof.Spec.sumReal`), for every grade and size: the output is
`∑ i, x i`. -/
theorem sumReal_f {g} {mono} (n : ℕ) (x : Fin n → ℝ) :
    (Spec.sumReal g mono).f n x () = ∑ i, x i :=
  rfl

/-- One test of `GPUProof.dotGrade`, in every binary interchange format: at length `1`, exact
entries `0` and grades of error `0`, the error is the underflow allowance `(2 + u) η`, and it is
positive. -/
theorem dotGrade_one_zero (fmt : FloatFormat) :
    (dotGrade (.ieee fmt) 1 0 0 (fun _ => ⟨0, 0⟩) fun _ => ⟨0, 0⟩).err =
        (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt ∧
      0 < (dotGrade (.ieee fmt) 1 0 0 (fun _ => ⟨0, 0⟩) fun _ => ⟨0, 0⟩).err := by
  have hu := Model.unitRoundoffAt_pos fmt
  have hη := Model.underflowErrorAt_pos fmt
  have h : (dotGrade (.ieee fmt) 1 0 0 (fun _ => ⟨0, 0⟩) fun _ => ⟨0, 0⟩).err =
      (2 + Model.unitRoundoffAt fmt) * Model.underflowErrorAt fmt := by
    simp only [dotGrade, laneGrade, Grade.pos, NumFormat.roundoff, NumFormat.underflow,
      Nat.cast_one, pow_zero, add_zero, one_mul]
    field_simp
    simp
    ring
  exact ⟨h, h ▸ by positivity⟩

/-- One test spec (`GPUProof.Spec.matVec` at `GPUProof.matVecGrade`): the matrix-vector product
graded by `GPUProof.dotGrade` at each output. -/
noncomputable def matVecDot : Spec (ℕ × ℕ) := Spec.matVec matVecGrade matVecGrade_mono

/-- One test spec (`GPUProof.Spec.vecMat` at `GPUProof.vecMatGrade`): the vector-matrix product
graded by `GPUProof.dotGrade` at each output. -/
noncomputable def vecMatDot : Spec (ℕ × ℕ) := Spec.vecMat vecMatGrade vecMatGrade_mono

end MojoProofTest.GPUProof.Spec
