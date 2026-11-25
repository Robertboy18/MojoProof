import MojoProofTest.SymCall
import MojoProofTest.SymInfo

/-!
# The lane number in the block checker

The checker takes a call of `llvm.nvvm.read.ptx.sreg.laneid` (`SState.stmt`,
MojoProof/Sym/Checker.lean, node `SNode.call`; sound by `exec_laneid`, MojoProof/Sym/Exec.lean).
Tests at the two kernels of tests/corpus/gemv/:

* `call_laneid`: for every valuation, a call node whose statement calls, with no arguments, a
  declaration that the intrinsic table maps to `laneid`, with return type `i32` and return
  attributes `noundef`, `range(i32 0, 32)`, evaluates to the context's `%laneid` when it is
  below 32. `gevm_lane`: its instance at the node `(6, 5)` of gevm_kernel, `%12`.
* `gevm_entry`: the checker accepts gevm_kernel's entry block `%6` (32 statements, the lane
  number at statement 5, an `udiv` and two `sdiv`s), with `fmul contract` in the fragment or not.
* `gemv_entry`: its twin, gemv_kernel's entry block `%6` is still refused (its first
  statement is an `alloca`; docs/proofs/gemv.md lists what it needs).
* `loops_contract`: the loops' blocks with `fmul contract` (gemv_kernel's `%70`,
  gevm_kernel's `%45`) have a summary by `summarizeC`; `reductions_refused`: the blocks of the
  warp reductions (gemv_kernel's `%78`, gevm_kernel's `%59`) have none.

Tests of six blocks of two kernels; `exec_laneid` covers every program. The module imports
MojoProofTest/SymInfo.lean so that the blocks gemv_kernel has in common with the kernels imported
there are that module's constants (`mojo_import` names a block an imported module defines), not
defined twice.
-/

namespace MojoProofTest.SymLane

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymCall

mojo_import "gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll" as gevm

mojo_import "gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll" as gemv

/-- **A lane-number call node.** For every valuation `V` and node values `vs`: if the statement
at position `pc` of block `lbl` calls `g` with no arguments, `g` is declared as `fn` with return
type `i32` and return attributes `noundef`, `range(i32 0, 32)`, the intrinsic table maps `g` to
`laneid`, and the context's `%laneid` is below 32, then the node `.call lbl pc` evaluates to it
as a 32-bit value. -/
theorem call_laneid {V : Valuation} (vs : List (Except Fault Val)) {lbl pc : Nat} {dst fm ty md}
    {g : String} {fn : Func}
    (hs : V.stmt lbl pc = some ⟨dst, .call fm ty (.fn g) [], md⟩)
    (hf : V.ctx.prog.module.funcs.find? (·.name == g) = some fn)
    (hl : V.ctx.prog.intrinsics.lookup g = some .laneid)
    (hr : fn.ret = .int 32) (ha : fn.retAttrs = [.flag "noundef", .range (.int 32) 0 32])
    (hn : V.ctx.env.laneid < 32) :
    SNode.eval V vs (.call lbl pc) = .ok (.bits 32 (BitVec.ofNat 32 V.ctx.env.laneid)) :=
  SNode.eval_laneid vs rfl hs hf hl hr (by rw [ha]; decide) hn

/-- **The node `(6, 5)` of `gevm_kernel`** (`%12`, the lane number, `range(i32 0, 32)`), on every
valuation of the kernel whose `%laneid` is below 32. -/
theorem gevm_lane (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = gevm.fn_0)
    (hP : V.ctx.prog = gevm.prog) (h : V.ctx.env.laneid < 32) :
    SNode.eval V vs (.call 6 5) = .ok (.bits 32 (BitVec.ofNat 32 V.ctx.env.laneid)) := by
  have hs : V.stmt 6 5 =
      some ⟨some 12, .call {} (.int 32) (.fn "llvm.nvvm.read.ptx.sreg.laneid") [], []⟩ := by
    rw [Valuation.stmt, hf]; rfl
  obtain ⟨fn, hfn, hr, ha⟩ : ∃ fn,
      gevm.prog.module.funcs.find? (·.name == "llvm.nvvm.read.ptx.sreg.laneid") = some fn ∧
        fn.ret = .int 32 ∧ fn.retAttrs = [.flag "noundef", .range (.int 32) 0 32] :=
    ⟨_, rfl, rfl, rfl⟩
  exact call_laneid vs hs (by rw [hP]; exact hfn) (by rw [hP]; rfl) hr ha h

/-- **`gevm_kernel`'s entry block is in the fragment**: `summarize` and `summarizeC` give a
summary of block `%6` from its start. -/
theorem gevm_entry : (summarize gevm.prog gevm.fn_0 6 0).isSome = true ∧
    (summarizeC gevm.prog gevm.fn_0 6 0).isSome = true := by
  decide +kernel

/-- **The twin of `gevm_entry`**: `gemv_kernel`'s entry block `%6`, which starts with
`alloca [2 x ptr]`, has no summary. -/
theorem gemv_entry : summarize gemv.prog gemv.fn_0 6 0 = none := by
  decide +kernel

/-- **The loops' `fmul contract` blocks are in the fragment of `coversC`**: `summarizeC` gives a
summary of `gemv_kernel`'s block `%70` (its eighth, `b_7`) and of `gevm_kernel`'s block `%45`
(`b_4`): their loops' loads, `fmul contract` and `fadd contract`. -/
theorem loops_contract : (summarizeC gemv.prog gemv.fn_0 gemv.fn_0.b_7.label 0).isSome = true ∧
    (summarizeC gevm.prog gevm.fn_0 gevm.fn_0.b_4.label 0).isSome = true := by
  decide +kernel

/-- **The warp reductions are refused**: `summarizeC` gives no summary of `gemv_kernel`'s block
`%78` (`b_10`) after its `phi` (a `shfl.sync.bfly` call at statement 2) or of `gevm_kernel`'s
block `%59` (`b_5`) after its `phi` (the barrier call at statement 6). -/
theorem reductions_refused : summarizeC gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 1 = none ∧
    summarizeC gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 = none := by
  decide +kernel

end MojoProofTest.SymLane
