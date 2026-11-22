---
id: inst-bitcast
title: The `bitcast` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #bitcast-to-instruction
quote: "The ‘bitcast’ instruction converts value to type ty2 without changing any bits."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.bitcast, MojoProof.Sym.exec_cast
corpus: tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `bitcast` instruction

## Rule

LangRef's section on `bitcast` (the quote is the first sentence of its overview). The importer reads `bitcast` as `Inst.cast` with `CastOp.bitcast` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.bitcast`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (trunc, zext and sext); refused (the other casts): SState.stmt takes trunc, zext and sext only.

## Corpus

31 of the 111 corpus files use it (8031 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `bitcast` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
