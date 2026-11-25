import MojoProof.Sem.Schedule

/-!
# Instances of `rmw_comm`, and the two-operation twin

`rmw_comm` is the part about values of L10 in docs/proofs/schedule.md: two atomic updates of one
admitted operation, applied in either order to a scalar, give the same result.

On `i32` scalars: `umax` of 3 by 7 and by 5 gives 7 in either order (`umax_both`, the second
order by `rmw_comm`); `add` with a poison operand gives poison in either order, and with an undef
operand the same fault (`add_poison`, `add_undef`). The twin: of 1, an `add` by 1 and an `or` by
1 give 3 in one order and 2 in the other (`add_or`), which is why `Access.conflict` exempts two
atomic accesses from racing only if they have the same operation, and one that commutes. From
poison, a `max` by a pointer and one by 3, each result updated by the other operand, give one
value in either order (`max_ptr`, by `rmw_comm_of_ok`; the pointer is not a scalar, so
`rmw_comm` does not apply); its twin: from 1, a `max` by undef and one by a pointer fault
differently in the two orders (`max_faults`). These are statements about values, not about a
kernel.
-/

namespace MojoProofTest.Atomics

open MojoProof.LLVM MojoProof.Sem

/-- The `i32` scalar `n`. -/
abbrev b (n : Nat) : Val := .bits 32 (BitVec.ofNat 32 n)

/-- `b n` is a scalar of width 32, for every `n`. -/
theorem scalar (n : Nat) : (b n).Scalar 32 := .inl ⟨_, rfl⟩

/-- `umax` of 3 by 7 and by 5 gives 7 in either order. -/
theorem umax_both :
    (rmw 32 .umax (b 3) (b 7) >>= (rmw 32 .umax · (b 5))) = .ok (b 7) ∧
      (rmw 32 .umax (b 3) (b 5) >>= (rmw 32 .umax · (b 7))) = .ok (b 7) :=
  ⟨rfl, (rmw_comm rfl (scalar 3) (scalar 7) (scalar 5)).symm.trans rfl⟩

/-- A poison operand gives poison in either order. -/
theorem add_poison :
    (rmw 32 .add (b 1) .poison >>= (rmw 32 .add · (b 2))) = .ok .poison ∧
      (rmw 32 .add (b 1) (b 2) >>= (rmw 32 .add · .poison)) = .ok .poison :=
  ⟨rfl, rfl⟩

/-- An undef operand gives the same fault in either order. -/
theorem add_undef :
    (rmw 32 .add (b 1) .undef >>= (rmw 32 .add · (b 2))) = .error (.unsupported "use of undef") ∧
      (rmw 32 .add (b 1) (b 2) >>= (rmw 32 .add · .undef)) =
        .error (.unsupported "use of undef") :=
  ⟨rfl, rfl⟩

/-- The twin: an `add` and an `or` do not commute. -/
theorem add_or :
    (rmw 32 .add (b 1) (b 1) >>= (rmw 32 .or · (b 1))) = .ok (b 3) ∧
      (rmw 32 .or (b 1) (b 1) >>= (rmw 32 .add · (b 1))) = .ok (b 2) ∧ b 3 ≠ b 2 :=
  ⟨rfl, rfl, by simp [b]⟩

/-- The instance of `rmw_comm_of_ok` that `rmw_comm` does not cover: from poison, a `max` by a
pointer, which is not an `i32` scalar, and one by 3 both succeed, and each result updated by the
other operand succeeds, with one value in either order. -/
theorem max_ptr : ¬ (Val.ptr ⟨1, 0⟩).Scalar 32 ∧
    ∃ u, rmw 32 .max .poison (b 3) = .ok u ∧ rmw 32 .max .poison (.ptr ⟨1, 0⟩) = .ok u :=
  ⟨by simp [Val.Scalar], rmw_comm_of_ok (x := .ptr ⟨1, 0⟩) (y := b 3) (.inr (.inl rfl)) rfl rfl⟩

/-- The twin of `rmw_comm_of_ok`'s premises `hx` and `hy`: from 1, a `max` by undef and one by a
pointer both fault, with different faults in the two orders. -/
theorem max_faults :
    (rmw 32 .max (b 1) .undef >>= (rmw 32 .max · (.ptr ⟨1, 0⟩))) =
        .error (.unsupported "use of undef") ∧
      (rmw 32 .max (b 1) (.ptr ⟨1, 0⟩) >>= (rmw 32 .max · .undef)) =
        .error (.unsupported "min/max of non-integers") :=
  ⟨rfl, rfl⟩

end MojoProofTest.Atomics
