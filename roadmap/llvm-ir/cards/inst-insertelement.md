---
id: inst-insertelement
title: The `insertelement` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #insertelement-instruction
quote: "The ‘insertelement’ instruction inserts a scalar element into a vector at a specified index."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_insertelement
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv_dev2026112705/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs128_2d84049c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs256_b2a56671.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `insertelement` instruction

## Rule

LangRef's section on `insertelement` (the quote is the first sentence of its overview). The importer reads `insertelement` as `Inst.insertelement` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `insertelement`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_insertelement` (into an operand or a constant its type gives (zeroinitializer, undef or poison)).

## Corpus

53 of the 127 corpus files use it (9196 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `insertelement` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
