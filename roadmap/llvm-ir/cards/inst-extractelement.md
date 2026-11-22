---
id: inst-extractelement
title: The `extractelement` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #extractelement-instruction
quote: "The ‘extractelement’ instruction extracts a single scalar element from a vector at a specified index."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs128_2d84049c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs256_b2a56671.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs64_3aca57b2.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `extractelement` instruction

## Rule

LangRef's section on `extractelement` (the quote is the first sentence of its overview). The importer reads `extractelement` as `Inst.extractelement` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `extractelement`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt has no case for it.

## Corpus

56 of the 114 corpus files use it (16332 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `extractelement` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
