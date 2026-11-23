import MojoProof.Sem.Eval

/-!
# The vector `bitcast` at one word

A test of one example: `castV_split` and `castV_halves` at the 64-bit word `0x0000000500000007`,
the form of gemv_kernel's `%21 = bitcast i64 %20 to <2 x i32>` and its `bitcast` back
(`%36`). The vector is `[7, 5]`, low half first, and the `bitcast` of it back is the word.
-/

namespace MojoProofTest.Bitcast

open MojoProof MojoProof.LLVM MojoProof.Sem

/-- **The halves of one word**, a test of one example: for every layout, memory and oracle
numbers, `bitcast i64` of the word `0x0000000500000007` to `<2 x i32>` is `[7, 5]`
(`castV_split`), and the `bitcast` of `[7, 5]` to `i64` is the word again (`castV_halves`). -/
theorem halves57 (l : Layout) (m : Mem) (ch : Nat → Nat) :
    castV l m .bitcast (.int 64) (.bits 64 0x0000000500000007#64) (.vec 2 (.int 32)) ch =
        .ok (.vec [.bits 32 7#32, .bits 32 5#32]) ∧
      castV l m .bitcast (.vec 2 (.int 32)) (.vec [.bits 32 7#32, .bits 32 5#32]) (.int 64) ch =
        .ok (.bits 64 0x0000000500000007#64) :=
  ⟨(castV_split l m ch (n := 2) (w := 32) _).trans rfl, (castV_halves l m ch _ _).trans rfl⟩

end MojoProofTest.Bitcast
