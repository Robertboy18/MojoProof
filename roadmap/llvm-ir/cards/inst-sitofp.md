---
id: inst-sitofp
title: The `sitofp` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #sitofp-to-instruction
quote: "The ‘sitofp’ instruction regards value as a signed integer and converts that value to the ty2 type."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.intToFloat, MojoProof.Sym.exec_cast
corpus: tests/corpus/mma/m_test_layout_mma_c_fragment_kern6A6A_805197d96be57147.nvptx.ll, tests/corpus/mma/m_test_layout_mma_c_fragment_kern6A6A_957f36c79da62114.nvptx.ll, tests/corpus/mma/m_test_layout_mma_c_fragment_kern6A6A_fb4d0f20fa0d4d7a.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `sitofp` instruction

## Rule

LangRef's section on `sitofp` (the quote is the first sentence of its overview). The importer reads `sitofp` as `Inst.cast` with `CastOp.sitofp` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.intToFloat`. MojoProofTest/Modelled.lean runs a kernel of it (its row `sitofp`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (trunc, zext and sext); refused (the other casts): SState.stmt takes trunc, zext and sext only.

## Corpus

3 of the 114 corpus files use it (10 uses).

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `sitofp` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
