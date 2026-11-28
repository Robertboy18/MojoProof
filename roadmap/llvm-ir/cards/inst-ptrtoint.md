---
id: inst-ptrtoint
title: The `ptrtoint` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #ptrtoint-to-instruction
quote: "The ‘ptrtoint’ instruction converts the pointer or a vector of pointers value to the integer (or vector of integers) type ty2."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_cast
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs128_2d84049c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs256_b2a56671.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs64_3aca57b2.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r2_ax1_w4_bs1024_e8108490.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `ptrtoint` instruction

## Rule

LangRef's section on `ptrtoint` (the quote is the first sentence of its overview). The importer reads `ptrtoint` as `Inst.cast` with `CastOp.ptrtoint` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `ptrtoint`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (the casts castV evaluates (castOk): not fptoui, fptosi or inttoptr; ptrtoint after an alloca on the memory the effects before it make (SNode.castAfter)); refused (fptoui, fptosi, inttoptr or an ill-typed cast): SState.stmt takes the casts castOk admits (castOk_iff: those castV evaluates).

## Corpus

42 of the 127 corpus files use it (1515 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `ptrtoint` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
