---
id: inst-and
title: The `and` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #and-instruction
quote: "The ‘and’ instruction returns the bitwise logical and of its two operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intBin, MojoProof.Sym.exec_bin
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs128_wide_5efdc703.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_False_ce0237f1.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_True_130d2561.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `and` instruction

## Rule

LangRef's section on `and` (the quote is the first sentence of its overview). The importer reads `and` as `Inst.bin` with `BinOp.and` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intBin`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_bin`.

## Corpus

39 of the 111 corpus files use it (529 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `and` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
