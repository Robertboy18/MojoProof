---
id: inst-shl
title: The `shl` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #shl-instruction
quote: "The ‘shl’ instruction returns the first operand shifted to the left a specified number of bits."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intBin, MojoProof.Sym.exec_bin
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_float32_bfloat16_bfloat16_True_6b56a724.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `shl` instruction

## Rule

LangRef's section on `shl` (the quote is the first sentence of its overview). The importer reads `shl` as `Inst.bin` with `BinOp.shl` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intBin`. MojoProofTest/Modelled.lean runs a kernel of it (its row `shl`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_bin`.

## Corpus

9 of the 114 corpus files use it (27 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `shl` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
