---
id: inst-phi
title: The `phi` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #phi-instruction
quote: "The ‘phi’ instruction is used to implement the φ node in the SSA graph representing the function."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `phi` instruction

## Rule

LangRef's section on `phi` (the quote is the first sentence of its overview). The importer reads `phi` as `Inst.phi` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. The block checker (MojoProof/Sym/Rules.lean): refused: set on the edge into its block (SState.phiConds), not by SState.stmt.

## Corpus

99 of the 111 corpus files use it (3402 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `phi` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
