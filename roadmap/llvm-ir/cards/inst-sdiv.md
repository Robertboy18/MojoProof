---
id: inst-sdiv
title: The `sdiv` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #sdiv-instruction
quote: "The ‘sdiv’ instruction returns the quotient of its two operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intBin, MojoProof.Sym.exec_bin
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_False_ce0237f1.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_True_130d2561.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `sdiv` instruction

## Rule

LangRef's section on `sdiv` (the quote is the first sentence of its overview). The importer reads `sdiv` as `Inst.bin` with `BinOp.sdiv` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intBin`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_bin`.

## Corpus

39 of the 111 corpus files use it (662 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `sdiv` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
