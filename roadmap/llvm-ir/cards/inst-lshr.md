---
id: inst-lshr
title: The `lshr` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #lshr-instruction
quote: "The ‘lshr’ instruction (logical shift right) returns the first operand shifted to the right a specified number of bits with zero fill."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intBin, MojoProof.Sym.exec_bin
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs1024_ec7277c3.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs128_96d6b42c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs256_68ef3272.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w1_bs64_7668624f.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r5_ax4_w4_bs1024_053a42d0.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `lshr` instruction

## Rule

LangRef's section on `lshr` (the quote is the first sentence of its overview). The importer reads `lshr` as `Inst.bin` with `BinOp.lshr` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intBin`. MojoProofTest/Modelled.lean runs a kernel of it (its row `lshr`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_bin`.

## Corpus

20 of the 116 corpus files use it (150 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `lshr` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
