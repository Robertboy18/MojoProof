---
id: inst-bitcast
title: The `bitcast` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #bitcast-to-instruction
quote: "The ‘bitcast’ instruction converts value to type ty2 without changing any bits."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.bitcast, MojoProof.Sym.exec_cast
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `bitcast` instruction

## Rule

LangRef's section on `bitcast` (the quote is the first sentence of its overview). The importer reads `bitcast` as `Inst.cast` with `CastOp.bitcast` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.bitcast`. MojoProofTest/Modelled.lean runs a kernel of it (its row `bitcast`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (trunc, zext and sext); refused (the other casts): SState.stmt takes trunc, zext and sext only.

## Corpus

33 of the 114 corpus files use it (8053 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `bitcast` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
