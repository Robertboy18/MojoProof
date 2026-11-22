---
id: inst-select
title: The `select` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #select-instruction
quote: "The ‘select’ instruction is used to choose one value based on a condition, without IR-level branching."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_select
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `select` instruction

## Rule

LangRef's section on `select` (the quote is the first sentence of its overview). The importer reads `select` as `Inst.select` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_select` (of integers); refused (of floats, pointers or vectors): SState.stmt takes select of integers only.

## Corpus

108 of the 111 corpus files use it (5861 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `select` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
