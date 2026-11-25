---
id: inst-insertvalue
title: The `insertvalue` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #insertvalue-instruction
quote: "The ‘insertvalue’ instruction inserts a value into a member field in an aggregate value."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_insertvalue
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `insertvalue` instruction

## Rule

LangRef's section on `insertvalue` (the quote is the first sentence of its overview). The importer reads `insertvalue` as `Inst.insertvalue` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `insertvalue`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_insertvalue` (into an operand or a constant its type gives (zeroinitializer, undef or poison)).

## Corpus

64 of the 116 corpus files use it (8963 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `insertvalue` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
