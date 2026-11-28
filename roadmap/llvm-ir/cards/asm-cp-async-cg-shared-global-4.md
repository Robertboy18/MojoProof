---
id: asm-cp-async-cg-shared-global-4
title: Inline asm `cp.async.cg.shared.global` with 4 operands
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cp-async
quote: "Initiates an asynchronous copy operation from one state space to another."
lean: not stated yet
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_3_66061507eda154ac.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_b_933c66779e5fed79.nvptx.ll
tests: MojoProofTest.Asm, MojoProofTest.Corpus
upstream:
level: L0
---
# Inline asm `cp.async.cg.shared.global` with 4 operands

## Rule

The importer accepts a call `call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2, $3;", "r,l,n,r"(...)` (`AsmCall.cpAsyncCgSrc`, recognized by `AsmCall.ofText?` and checked by `AsmCall.checkCall` in `Module.check`: the template and constraints exactly, `sideeffect`, a `void` result, no fast-math flags or argument attributes, and the operands of the form). It is parsed, not modelled: `MojoProof.Sem.exec` has no case for inline assembly and stops the thread with an `unsupported` fault, so no launch that reaches the call is `Kernel.Sound`. The declarations: `MojoProof.LLVM.AsmCall`, `MojoProof.LLVM.AsmCall.ofText?`, `MojoProof.LLVM.AsmCall.checkCall`, `MojoProof.LLVM.Module.check`, `MojoProof.Sem.exec`. The quote is the first sentence of PTX ISA's section on `cp`, the instruction the string holds.

## Corpus

22 of the 127 corpus files use it (664 uses); `corpus` lists the first 5 in path order.

## Out of scope

Everything the copy does: no Lean model of it exists, and the files that call it import but have no run without a fault.

## Open

L1 needs a semantics of the copy (pending until its group's `cp.async.wait.group`) in place of the fault.
