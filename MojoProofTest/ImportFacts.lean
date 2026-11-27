import GPUProof.Spec.Basic
import Mathlib.Data.Fintype.Sum

/-!
# A spec with a domain and two bridges to it, for `import_spec` in another module

`diffInt` is a test spec whose domain is not everything: at every size `n`, two integer vectors
`a` and `b` of length `n`, their difference `a - b`, meant where `b i ≤ a i` at every `i`.
`sub_cast` says that the truncated difference of two natural vectors, read as integers, is
`diffInt`'s function there, given that domain; `sub_strict` says the same under the stronger
premise `b i < a i`; `sub_zero_add` says it at size `0 + n`, with vectors over `Fin (0 + n)`.
Their outputs have type `Fin n` (`Fin (0 + n)`), not `diffInt.Out n`. MojoProofTest/ImportDom.lean
uses them in `import_spec` through `using`, without restating them.

Tests at every size `n`.
-/

namespace MojoProofTest.ImportFacts

/-- One test spec (`diffInt`): at every size `n`, `2 * n` integer inputs (`a i` at `inl i` and
`b i` at `inr i`) and `n` integer outputs, the difference `a i - b i` at `i`, meant where
`b i ≤ a i` at every `i`, with the `exact` rule. -/
def diffInt : GPUProof.Spec ℕ where
  In n := Fin n ⊕ Fin n
  Out := Fin
  dIn _ _ := .int
  dOut _ _ := .int
  Dom _ x := ∀ i, (x (.inr i) : ℤ) ≤ x (.inl i)
  f _ x i := (x (.inl i) : ℤ) - x (.inr i)
  rule := .exact

/-- **The truncated difference is `diffInt`'s on its domain**, for every size `n`, natural vectors
`a` and `b` of length `n` with `b i ≤ a i` at every `i`, and output `i`: `(a - b) i`, as an
integer, is `diffInt`'s function at `a` and `b` read as integers. By `omega`. The output has type
`Fin n`, which is the type `diffInt.Out n` of `import_spec`'s goal only once `diffInt` is unfolded:
`import_fact` compares the arguments' types at default transparency. -/
theorem sub_cast (n : ℕ) (a b : Fin n → ℕ) (h : ∀ i, (b i : ℤ) ≤ a i) (i : Fin n) :
    (((a - b) i : ℕ) : ℤ) = diffInt.f n (Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)) i := by
  show ((a i - b i : ℕ) : ℤ) = a i - b i
  have := h i
  omega

/-- **`sub_cast` under a stronger premise**, for every size `n`, natural vectors `a` and `b` of
length `n` with `b i < a i` at every `i`, and output `i`: the conclusion of `sub_cast`. By
`sub_cast`. `MojoProofTest.ImportDom.Strict` gives it to `import_spec`, whose `eq` case has only
`b i ≤ a i` in its context. -/
theorem sub_strict (n : ℕ) (a b : Fin n → ℕ) (h : ∀ i, (b i : ℤ) < a i) (i : Fin n) :
    (((a - b) i : ℕ) : ℤ) = diffInt.f n (Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)) i :=
  sub_cast n a b (fun i => (h i).le) i

/-- **`sub_cast` at size `0 + n`**, for every `n`, natural vectors `a` and `b` over `Fin (0 + n)`
with `b i ≤ a i` at every `i`, and output `i`: the conclusion of `sub_cast` at size `0 + n`. By
`sub_cast`. `Fin (0 + n)` is `Fin n` only by `Nat.zero_add`, not by unfolding, so
`MojoProofTest.ImportDom.Far` refuses it at `import_spec`'s goal over `Fin n`. -/
theorem sub_zero_add (n : ℕ) (a b : Fin (0 + n) → ℕ) (h : ∀ i, (b i : ℤ) ≤ a i)
    (i : Fin (0 + n)) :
    (((a - b) i : ℕ) : ℤ) =
      diffInt.f (0 + n) (Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)) i :=
  sub_cast (0 + n) a b h i

end MojoProofTest.ImportFacts
