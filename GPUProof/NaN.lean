/-!
# Equality up to NaN payloads, on every word type

One definition for every word type and every NaN predicate (`UpToNaN`): two words are equal up
to NaN payloads when they are equal or both are NaNs. It is an equivalence
(`UpToNaN.equivalence`); a word related to one that is not a NaN is that word (`UpToNaN.eq`); a
predicate that holds wherever `nan` does relates every two words that `nan`'s relation does
(`UpToNaN.mono`); and a binary operation that gives a NaN whenever an operand is one keeps the
relation (`UpToNaN.map₂`). The spec layer's encodings (`GPUProof.ScalarEnc.nanEq`,
`GPUProof.Encoding.nanEq`, GPUProof/Spec/Basic.lean) and the front ends' relations on float words
are its cases, at the NaN predicate of their words. FloatLib v4.1.0 has no such relation on its
words, so it is defined here, in a module that imports nothing.
-/

namespace GPUProof

universe u

/-- Words `x` and `y` are equal up to NaN payloads, for every word type and NaN predicate `nan`:
they are equal, or `nan` holds of both. -/
def UpToNaN {W : Type u} (nan : W → Bool) (x y : W) : Prop :=
  x = y ∨ (nan x = true ∧ nan y = true)

/-- `UpToNaN nan` is an equivalence, for every word type and NaN predicate `nan`. -/
theorem UpToNaN.equivalence {W : Type u} (nan : W → Bool) : Equivalence (UpToNaN nan) where
  refl _ := Or.inl rfl
  symm h := Or.elim h (fun e => Or.inl e.symm) fun ⟨hx, hy⟩ => Or.inr ⟨hy, hx⟩
  trans h₁ h₂ := Or.elim h₁ (fun e => e ▸ h₂) fun ⟨hx, hy⟩ =>
    Or.elim h₂ (fun e => Or.inr ⟨hx, e ▸ hy⟩) fun ⟨_, hz⟩ => Or.inr ⟨hx, hz⟩

/-- A word related up to NaN payloads to a word that is not a NaN is that word, for every word
type and NaN predicate `nan`. -/
theorem UpToNaN.eq {W : Type u} {nan : W → Bool} {x y : W} (h : UpToNaN nan x y)
    (hx : nan x = false) : x = y :=
  h.elim id fun h' => absurd h'.1 (by rw [hx]; exact Bool.false_ne_true)

/-- A predicate `nan'` that holds wherever `nan` holds relates every two words that `UpToNaN nan`
relates, for every word type. -/
theorem UpToNaN.mono {W : Type u} {nan nan' : W → Bool} (hn : ∀ x, nan x = true → nan' x = true)
    {x y : W} (h : UpToNaN nan x y) : UpToNaN nan' x y :=
  h.imp id fun h' => ⟨hn x h'.1, hn y h'.2⟩

/-- A binary operation that gives a word of which `nan` holds whenever `nan` holds of an operand
keeps `UpToNaN nan`, for every word type and NaN predicate: equal operands give equal results, and
an operand of which `nan` holds on both sides gives two results of which it holds. -/
theorem UpToNaN.map₂ {W : Type u} {nan : W → Bool} {f : W → W → W}
    (hf : ∀ x y, nan x = true ∨ nan y = true → nan (f x y) = true) {x x' y y' : W}
    (hx : UpToNaN nan x x') (hy : UpToNaN nan y y') : UpToNaN nan (f x y) (f x' y') := by
  rcases hx with rfl | ⟨h1, h2⟩
  · rcases hy with rfl | ⟨h3, h4⟩
    · exact .inl rfl
    · exact .inr ⟨hf _ _ (.inr h3), hf _ _ (.inr h4)⟩
  · exact .inr ⟨hf _ _ (.inl h1), hf _ _ (.inl h2)⟩

end GPUProof
