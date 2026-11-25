---
id: inst-addrspacecast
title: The `addrspacecast` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #addrspacecast-to-instruction
quote: "The ‘addrspacecast’ instruction converts ptrval from pty in address space n to type pty2 in address space m."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_cast
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `addrspacecast` instruction

## Rule

LangRef's section on `addrspacecast` (the quote is the first sentence of its overview). The importer reads `addrspacecast` as `Inst.cast` with `CastOp.addrspacecast` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `addrspacecast`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (the casts castV evaluates (castOk): not fptoui, fptosi or inttoptr; ptrtoint after an alloca on the memory the effects before it make (SNode.castAfter)); refused (fptoui, fptosi, inttoptr or an ill-typed cast): SState.stmt takes the casts castOk admits (castOk_iff: those castV evaluates).

## Corpus

32 of the 116 corpus files use it (282 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `addrspacecast` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
