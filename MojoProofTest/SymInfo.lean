import MojoProof.Kernels
import MojoProof.Sym.Info
import MojoProofTest.SymPhi

/-!
# Tests of `#mojo_info`

The block checker accepts `vector_addition`'s blocks `%21` and `%4` (the entry, with its
special-register calls) from their entries, and refuses block `%30` of `withHelper` at statement
0, a call of a module function (`refusal`, the position `#mojo_info` prints; `refusal_vadd`, by
`decide +kernel`). `#mojo_info` on `vector_addition` prints its intrinsics, no other calls, one
phase, no back edges, its float operator `fadd contract` and the verdict on each of its four
blocks. On `withHelper`, `vector_addition` with a call of a module function `@helper` in its
block `%30`, it prints the call under `calls` (not under `intrinsics`), the refusal of `%30` at
that call, and `@helper`'s own report. On a program without functions with blocks it is an
error.

The fusable pairs (`fusable`): none in `vector_addition` (an `fadd contract` of two loads) or
vector_multiply (an `fmul` without flags), 64 in `tiled_matmul`; and, on the ten float32 naive
matmul kernels of the multistage GEMM test (`tests/corpus/mgemm/`, compiled with the default
flags), one each, the loop body's `fmul contract` and `fadd contract`, against none for the same
ten kernels compiled with `--fp-mode contract=off` (`tests/corpus/mgemm_nocontract/`), whose
`fmul` and `fadd` have no flags. The default compile of `16826c8c` is MojoProofTest/SymPhi.lean's
`naive`, imported there; the module imports it, so the contraction-off kernel's blocks equal to
`naive`'s are named, not defined again.
-/

namespace MojoProofTest.SymInfo

open MojoProof MojoProof.LLVM MojoProof.Sym

/-- `vector_addition` with a call `call void @helper()` as the only statement of its block `%30`,
and a definition `@helper` with one block that returns. -/
def withHelper : Program :=
  let helper : Func := { Kernels.vadd.fn_0 with
    name := "helper", params := [], names := #["h0"], blocks := #[⟨0, #[], .ret none⟩] }
  let b30 : LLVM.Block := { Kernels.vadd.fn_0.b_2 with
    stmts := #[⟨none, .call {} .void (.fn "helper") [], []⟩] }
  let fn : Func := { Kernels.vadd.fn_0 with
    blocks := Kernels.vadd.fn_0.blocks.map fun b => if b.label == b30.label then b30 else b }
  { Kernels.vadd.prog with module := { Kernels.vadd.prog.module with
    funcs := (Kernels.vadd.prog.module.funcs.map fun g =>
      if g.name == fn.name then fn else g).push helper } }

/-- The checker accepts blocks `%21` and `%4` from their entries, and refuses block `%30` of
`withHelper` at statement 0, its call of `@helper`. -/
theorem refusal_vadd :
    refusal Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1 0 = none ∧
    refusal Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_0 0 = none ∧
    (match withHelper.module.funcs.find? (·.name == Kernels.vadd.fn_0.name) with
      | some fn => match fn.blocks.find? (·.label == Kernels.vadd.fn_0.b_2.label) with
        | some b => refusal withHelper fn b 0
        | none => none
      | none => none) = some 0 := by
  decide +kernel

/--
info: @vector_addition_vector_addition6A6A_793e5fe36a195e73:
  intrinsics: [@llvm.nvvm.read.ptx.sreg.tid.x ×1, @llvm.nvvm.read.ptx.sreg.ctaid.x ×1, @llvm.nvvm.read.ptx.sreg.ntid.x ×1]
  calls: []
  phases: 1
  back edges: []
  float operators: [fadd contract]
  fusable pairs: 0
  %4: 16 statements, 0 phis, to [%21, %30]; in the fragment
  %21: 9 statements, 0 phis, to [%31]; in the fragment
  %30: 0 statements, 0 phis, to [%31]; in the fragment
  %31: 0 statements, 0 phis, to []; in the fragment
-/
#guard_msgs in
#mojo_info Kernels.vadd.prog

/--
info: @vector_addition_vector_addition6A6A_793e5fe36a195e73:
  intrinsics: [@llvm.nvvm.read.ptx.sreg.tid.x ×1, @llvm.nvvm.read.ptx.sreg.ctaid.x ×1, @llvm.nvvm.read.ptx.sreg.ntid.x ×1]
  calls: [@helper ×1]
  phases: 1
  back edges: []
  float operators: [fadd contract]
  fusable pairs: 0
  %4: 16 statements, 0 phis, to [%21, %30]; in the fragment
  %21: 9 statements, 0 phis, to [%31]; in the fragment
  %30: 1 statements, 0 phis, to [%31]; outside the fragment at statement 0: call void @helper()
  %31: 0 statements, 0 phis, to []; in the fragment
@helper:
  intrinsics: []
  calls: []
  phases: 1
  back edges: []
  float operators: []
  fusable pairs: 0
  %h0: 0 statements, 0 phis, to []; in the fragment
-/
#guard_msgs in
#mojo_info withHelper

/-- error: #mojo_info: the program has no function with blocks -/
#guard_msgs in
#mojo_info { Kernels.vadd.prog with module := { Kernels.vadd.prog.module with funcs := #[] } }

/-- The fusable pairs of program `P`: `fusable` summed over its functions. -/
def fusableIn (P : Program) : Nat := (P.module.funcs.toList.map fusable).sum

#guard fusableIn Kernels.vadd.prog == 0
#guard fusableIn Kernels.vmul.prog == 0
#guard fusableIn Kernels.matmul.prog == 64

-- The float32 naive matmul kernels, compiled with contraction off and with the default flags
-- (`16826c8c`'s is `MojoProofTest.SymPhi.naive`).
mojo_corpus "mgemm_nocontract"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_2219af54.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_51a464b3.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_5b4607bc.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_7f042754.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_9fb4f425.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_bf082016.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_ccfa9f7e.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_e97245b7.nvptx.ll"
  "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_eb5dc95e.nvptx.ll"

-- Each kernel compiled with contraction off has no fusable pair; with the default flags, one.
open Lean Elab Command in
/--
info: 16826c8c: contraction off 0, default 1
2219af54: contraction off 0, default 1
51a464b3: contraction off 0, default 1
5b4607bc: contraction off 0, default 1
7f042754: contraction off 0, default 1
9fb4f425: contraction off 0, default 1
bf082016: contraction off 0, default 1
ccfa9f7e: contraction off 0, default 1
e97245b7: contraction off 0, default 1
eb5dc95e: contraction off 0, default 1
-/
#guard_msgs in
run_cmd do
  let k := "g_matmul_kernel_naive_float32_float32_float32_True_16_"
  let mut out := #[]
  for h in ["16826c8c", "2219af54", "51a464b3", "5b4607bc", "7f042754",
    "9fb4f425", "bf082016", "ccfa9f7e", "e97245b7", "eb5dc95e"] do
    let count (c : Name) : CommandElabM Nat := liftTermElabM do
      let P ← unsafe Meta.evalExpr Program (mkConst ``Program) (mkConst (c.str "prog"))
      return fusableIn P
    let off ← count ((`MojoProofTest.SymInfo.mgemm_nocontract).str (k ++ h))
    let dflt ← count <| if h == "16826c8c" then `MojoProofTest.SymPhi.naive
      else (`MojoProofTest.SymInfo.mgemm).str (k ++ h)
    out := out.push s!"{h}: contraction off {off}, default {dflt}"
  logInfo ("\n".intercalate out.toList)

end MojoProofTest.SymInfo
