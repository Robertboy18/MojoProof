import MojoProof.Sem.Buffer

/-!
# Instances of `Layout.encode_length`, and its twins

On the default layout with 12-bit pointers (`l12`, as `target datalayout = "e-p:12:16"` reads):
a pointer is stored in 2 bytes, its store size, and so is every encoding of a pointer
(`ptr12`, by `Layout.encode_length`); an `<2 x i32>` vector in 8 (`vec2`); the fields `i8, i32`
end at 8, padding included (`fields`, by `Layout.encodeFields_length`). The twins are the vectors
LangRef does not admit, a vector of structs and a vector of vectors: their store size is 0 and
the semantics gives them no encoding, so no encoding has more bytes than the store size
(`vec_struct`, `vec_vec`); the parser refuses their types (MojoProofTest/Main.lean, `refusals`).
Statements about one layout and one value each.
-/

namespace MojoProofTest.Bytes

open MojoProof.LLVM MojoProof.Sem

/-- The default layout with 12-bit pointers in address space 0. -/
def l12 : Layout := { ptrs := [(0, 12, 16)] }

/-- On `l12`, the pointer to block 1 at offset 0 in address space 0 has an encoding, and every
encoding of it has 2 bytes, its store size (by `Layout.encode_length`). -/
theorem ptr12 : (l12.encode (.ptr 0) (.ptr ⟨1, 0⟩)).isSome ∧
    ∀ bs, l12.encode (.ptr 0) (.ptr ⟨1, 0⟩) = some bs → bs.length = 2 :=
  ⟨rfl, fun bs h => Layout.encode_length l12 _ _ bs h⟩

/-- On `l12`, every encoding of the `<2 x i32>` vector of 1 and 2 has 8 bytes (by
`Layout.encode_length`). -/
theorem vec2 (bs : List MemByte)
    (h : l12.encode (.vec 2 (.int 32)) (.vec [.bits 32 1, .bits 32 2]) = some bs) :
    bs.length = 8 :=
  Layout.encode_length l12 _ _ bs h

/-- The fields `i8, i32` end at 8: one byte, three of padding before the `i32`, and its four. -/
theorem fields (bs : List MemByte)
    (h : l12.encodeFields 0 [.int 8, .int 32] [.bits 8 1, .bits 32 2] = some bs) :
    bs.length = 8 := by
  have h' : 0 + bs.length = 8 := (Layout.encodeFields_length l12 _ _ _ bs h).trans rfl
  omega

/-- The twin with a vector of structs: on `l12`, `<2 x {i32}>` has store size 0, and the vector of
the structs `{1}` and `{2}` has no encoding. -/
theorem vec_struct : l12.stored (.vec 2 (.struct [.int 32])) = 0 ∧
    l12.encode (.vec 2 (.struct [.int 32])) (.vec [.agg [.bits 32 1], .agg [.bits 32 2]]) =
      none :=
  ⟨rfl, rfl⟩

/-- The twin with a vector of vectors: on `l12`, `<2 x <2 x i8>>` has store size 0, and the vector
of the vectors `[1, 2]` and `[3, 4]` has no encoding. -/
theorem vec_vec : l12.stored (.vec 2 (.vec 2 (.int 8))) = 0 ∧
    l12.encode (.vec 2 (.vec 2 (.int 8)))
      (.vec [.vec [.bits 8 1, .bits 8 2], .vec [.bits 8 3, .bits 8 4]]) = none :=
  ⟨rfl, rfl⟩

end MojoProofTest.Bytes
