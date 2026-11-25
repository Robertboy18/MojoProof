import MojoProofTest.SymLane
import MojoProofTest.NaiveOff
import MojoProof.Sym.Info

/-!
# Casts in the block checker

The checker takes the casts `castV` evaluates (`castOk`, `SState.stmt`,
MojoProof/Sym/Checker.lean): `trunc`, `zext` and `sext` as `SNode.cast`, the others as
`SNode.castAt` (MojoProof/Sym/Term.lean), which names its statement and evaluates `castV` at the
statement's operator and types, before or after a store (`ptrtoint` reads only the blocks'
addresses, which stores keep: `SEff.run_shape`). Sound by `exec_cast` (`SState.stmt_sound`,
MojoProof/Sym/Block.lean).
Tests at the bfloat16 naive matrix product of the corpus (`NaiveOff.bf16`) and at gemv_kernel:

* `bf16_fpext`: the value of a cast node at the loop's `fpext` (`SNode.eval_castAt`, for every
  valuation of the kernel's function).
* `bf16_blocks`: the loop's latch `%51` (two `fpext bfloat` to `float`, then `fmul contract` and
  `fadd contract`) has a summary by `summarizeC`, and the exit block `%68` (`fptrunc float` to
  `bfloat` before the store) by `summarize`.
* `gemv_shfl`: the twin, gemv_kernel's warp reduction `%78` is now refused at its statement 2,
  the first `shfl.sync.bfly` call, after the `bitcast` at statement 1 (`refusal`,
  MojoProof/Sym/Info.lean).
* `gemv_bitcast`: the value of that block's first two `bitcast` nodes, `float` to `i32` and back,
  is their operand's word (`SNode.eval_bitcast`, for every valuation of the kernel's function).

Tests of three blocks of two kernels; `SNode.eval_castAt` covers every valuation and cast, and
`SNode.eval_bitcast` every same-width scalar `bitcast`.
-/

namespace MojoProofTest.SymCast

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.NaiveOff
  MojoProofTest.SymLane

/-- **The node of the loop's first `fpext`** (`%60 = fpext bfloat %59 to float`, statement 8 of
block `%51`, the seventh block, `b_6`), for every valuation `V` of the kernel's function, node
values `vs`, step offset `n` and operand `a`: the cast of `a`'s value from `bfloat` to `float`,
whose lane `i` gets the oracle number of step `V.k + n` (`SNode.eval_castAt`). -/
theorem bf16_fpext (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = bf16.fn_0)
    (n : Nat) (a : SVal) :
    (SNode.castAt bf16.fn_0.b_6.label 8 n a).eval V vs = (do
      castV V.ctx.prog.layout V.mem .fpext (.fp .bfloat) (← a.eval V vs) (.fp .float)
        fun i => V.ctx.oracle (Nat.pair (V.k + n) i)) :=
  SNode.eval_castAt (by rw [Valuation.stmt, hf]; rfl)

/-- **The blocks with float casts are in the fragment**: `summarizeC` gives a summary of the
loop's latch `%51` (`b_6`, no `phi`) and `summarize` of the exit block `%68` (`b_7`) after its
`phi`. -/
theorem bf16_blocks : (summarizeC bf16.prog bf16.fn_0 bf16.fn_0.b_6.label 0).isSome = true ∧
    (summarize bf16.prog bf16.fn_0 bf16.fn_0.b_7.label 1).isSome = true := by
  decide +kernel

/-- **The twin of `bf16_blocks`**: in `gemv_kernel`'s warp reduction `%78` (`b_10`), the
`bitcast float` to `i32` at statement 1 is in the fragment, and the checker refuses the block at
statement 2, the call of `llvm.nvvm.shfl.sync.bfly.i32`. -/
theorem gemv_shfl : refusal gemv.prog gemv.fn_0 gemv.fn_0.b_10 1 = some 2 := by
  decide +kernel

/-- **The warp reduction's `bitcast`s keep the word**: for every valuation `V` of
`gemv_kernel`'s function, node values `vs`, step offset `n`, operand `a` and 32-bit word `u` that
is `a`'s value, the cast nodes of block `%78` (`b_10`) at statement 1 (`%80 = bitcast float %79 to
i32`) and statement 3 (`%82 = bitcast i32 %81 to float`) evaluate to `u` (`SNode.eval_bitcast`). -/
theorem gemv_bitcast (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = gemv.fn_0)
    (n : Nat) (a : SVal) (u : BitVec 32) (ha : a.eval V vs = .ok (.bits 32 u)) :
    (SNode.castAt gemv.fn_0.b_10.label 1 n a).eval V vs = .ok (.bits 32 u) ∧
      (SNode.castAt gemv.fn_0.b_10.label 3 n a).eval V vs = .ok (.bits 32 u) :=
  ⟨SNode.eval_bitcast (by rw [Valuation.stmt, hf]; rfl) rfl rfl rfl ha,
    SNode.eval_bitcast (by rw [Valuation.stmt, hf]; rfl) rfl rfl rfl ha⟩

end MojoProofTest.SymCast
