import GPUProof.Spec.Basic

/-!
# Decidable equality of the words of entrywise and uniform encodings

The word at a position of `GPUProof.Encoding.ofScalars e` is a word of the scalar encoding there,
and the words of `GPUProof.Encodings.uniform Sp u σ` are those of `Encoding.ofScalars`, but only by
unfolding definitions that are not reducible, so instance search, which indexes instances at
reducible transparency, finds no `DecidableEq` for them, nor `Fintype` of the positions, and
`decide` cannot decide an equation between two such words. This module gives the instances:

* `ScalarEnc.decEqIeee`, `ScalarEnc.decEqInt`, `ScalarEnc.decEqBool`, `ScalarEnc.decEqStd`: the
  words of `ScalarEnc.ieee fmt` (FloatLib's `Model fmt`), of `ScalarEnc.int bits` (`BitVec bits`),
  of `ScalarEnc.bool` and of `ScalarEnc.std fmt bits d`, for every format, width and entry type.
* `Encoding.decEqOfScalars`: the words at every position of `Encoding.ofScalars e`, for every
  index type and storages `e` whose words have decidable equality, finite or not.
* `Encodings.decEqUniformInp`, `Encodings.decEqUniformOut`: the words at every input and output
  position of `Encodings.uniform Sp u σ`, for every spec, size and storage `u` of each entry type
  whose words have decidable equality.
* `Encoding.fintypeOfScalars`: the positions of `Encoding.ofScalars e` are finite, for every
  finite index type.
* `Encodings.fintypeUniformInp`, `Encodings.fintypeUniformOut`: the input positions of
  `Encodings.uniform Sp u σ` are finite, for every spec, storage and size (a spec's inputs are
  finite, `Spec.fin`), and its output positions are, wherever the outputs are.

With these, Mathlib's `Fintype.decidablePiFintype` gives `DecidableEq` of the whole words, the
functions on the positions: of `Encoding.ofScalars e` at every finite index type, and of the input
words of `Encodings.uniform Sp u σ` at every spec, size and storage whose words have decidable
equality, so `decide` decides an equation between two of them at a concrete size. For the output
words it needs a `Fintype` of the spec's outputs, which instance search does not find by
unfolding a concrete spec's definition (`Spec.sumInt.Out n` is `Unit` only by unfolding
`Spec.sumInt`). GPUProof/Spec/Linear.lean gives it for `Spec.matVec`, `Spec.vecMat`,
`Spec.sumReal` and `Spec.sumInt` (`Spec.sumInt.fintypeOut` and the like) and
GPUProof/Spec/Comp.lean for a composite wherever the second spec has it
(`Wiring.spec.fintypeOut`).

When the two sides of an equation have types that agree only up to unfolding (a word at the
position `Sum.inl (i, j)` and a `Model fmt`), instance search compares them at implicit
transparency, which unfolds the encodings of GPUProof/Spec/Basic.lean and the specs of
GPUProof/Spec/Linear.lean: they are `[implicit_reducible]` for it. The instances are here and not
in GPUProof/Spec/Basic.lean, which most modules import, so that a change to them rebuilds only
their users.
-/

namespace GPUProof

open FloatLib.Floats.Formats.BinaryInterchange (FloatFormat Model)

/-- The words of `ScalarEnc.ieee fmt` have decidable equality, for every binary interchange
format: they are FloatLib's `Model fmt`. -/
instance ScalarEnc.decEqIeee (fmt : FloatFormat) : DecidableEq (ScalarEnc.ieee fmt).Word :=
  inferInstanceAs (DecidableEq (Model fmt))

/-- The words of `ScalarEnc.int bits` have decidable equality, for every width: they are
`BitVec bits`. -/
instance ScalarEnc.decEqInt (bits : Nat) : DecidableEq (ScalarEnc.int bits).Word :=
  inferInstanceAs (DecidableEq (BitVec bits))

/-- The words of `ScalarEnc.bool` have decidable equality: they are Booleans. -/
instance ScalarEnc.decEqBool : DecidableEq ScalarEnc.bool.Word :=
  inferInstanceAs (DecidableEq Bool)

/-- The words of `ScalarEnc.std fmt bits d` have decidable equality, for every binary interchange
format, width and entry type: those of `ScalarEnc.ieee fmt`, `ScalarEnc.int bits` or
`ScalarEnc.bool`. -/
instance ScalarEnc.decEqStd (fmt : FloatFormat) (bits : Nat) :
    (d : DType) → DecidableEq (ScalarEnc.std fmt bits d).Word
  | .real => ScalarEnc.decEqIeee fmt
  | .int => ScalarEnc.decEqInt bits
  | .bool => ScalarEnc.decEqBool

/-- The words at a position of `Encoding.ofScalars e` have decidable equality, for every index
type, entry types, storages `e` whose words have decidable equality at every entry, and position
`p`: they are the words of `e p`. -/
instance Encoding.decEqOfScalars {ι : Type} {d : ι → DType} (e : (i : ι) → ScalarEnc (d i))
    [h : ∀ i, DecidableEq (e i).Word] (p : (Encoding.ofScalars e).Pos) :
    DecidableEq ((Encoding.ofScalars e).Word p) :=
  h p

/-- The input words at a position of `Encodings.uniform Sp u σ` have decidable equality, for every
spec, storage `u` of each entry type whose words have decidable equality, size `σ` and position
`p`: they are the words of `u` at the entry type of input `p`. -/
instance Encodings.decEqUniformInp {Sz : Type} (Sp : Spec Sz) (u : (d : DType) → ScalarEnc d)
    [∀ d, DecidableEq (u d).Word] (σ : Sz) (p : (Encodings.uniform Sp u σ).inp.Pos) :
    DecidableEq ((Encodings.uniform Sp u σ).inp.Word p) :=
  Encoding.decEqOfScalars (fun i => u (Sp.dIn σ i)) p

/-- The output words at a position of `Encodings.uniform Sp u σ` have decidable equality, for
every spec, storage `u` of each entry type whose words have decidable equality, size `σ` and
position `p`: they are the words of `u` at the entry type of output `p`. -/
instance Encodings.decEqUniformOut {Sz : Type} (Sp : Spec Sz) (u : (d : DType) → ScalarEnc d)
    [∀ d, DecidableEq (u d).Word] (σ : Sz) (p : (Encodings.uniform Sp u σ).out.Pos) :
    DecidableEq ((Encodings.uniform Sp u σ).out.Word p) :=
  Encoding.decEqOfScalars (fun o => u (Sp.dOut σ o)) p

/-- The positions of `Encoding.ofScalars e` are finite, for every finite index type, entry types
and storages `e`: they are the indices. -/
instance Encoding.fintypeOfScalars {ι : Type} [Fintype ι] {d : ι → DType}
    (e : (i : ι) → ScalarEnc (d i)) : Fintype (Encoding.ofScalars e).Pos :=
  inferInstanceAs (Fintype ι)

/-- The input positions of `Encodings.uniform Sp u σ` are finite, for every spec, storage `u` of
each entry type and size `σ`: they are the spec's inputs at `σ`, finite by `Spec.fin`. -/
instance Encodings.fintypeUniformInp {Sz : Type} (Sp : Spec Sz) (u : (d : DType) → ScalarEnc d)
    (σ : Sz) : Fintype (Encodings.uniform Sp u σ).inp.Pos :=
  @Encoding.fintypeOfScalars _ (Sp.fin σ) _ fun i => u (Sp.dIn σ i)

/-- The output positions of `Encodings.uniform Sp u σ` are finite, for every spec, storage `u` of
each entry type and size `σ` at which the spec's outputs are finite: they are the outputs. -/
instance Encodings.fintypeUniformOut {Sz : Type} (Sp : Spec Sz) (u : (d : DType) → ScalarEnc d)
    (σ : Sz) [Fintype (Sp.Out σ)] : Fintype (Encodings.uniform Sp u σ).out.Pos :=
  Encoding.fintypeOfScalars fun o => u (Sp.dOut σ o)

end GPUProof
