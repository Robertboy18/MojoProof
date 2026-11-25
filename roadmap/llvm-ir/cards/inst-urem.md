---
id: inst-urem
title: The `urem` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #urem-instruction
quote: "The ‘urem’ instruction returns the remainder from the unsigned division of its two arguments."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intBin, MojoProof.Sym.exec_bin
corpus: tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_False_506bb3e7.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_True_02035925.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w8_b256_gs_False_ce81e313.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `urem` instruction

## Rule

LangRef's section on `urem` (the quote is the first sentence of its overview). The importer reads `urem` as `Inst.bin` with `BinOp.urem` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intBin`. MojoProofTest/Modelled.lean runs a kernel of it (its row `urem`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_bin`.

## Corpus

30 of the 116 corpus files use it (186 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `urem` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
