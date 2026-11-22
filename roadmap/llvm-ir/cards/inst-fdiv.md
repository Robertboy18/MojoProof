---
id: inst-fdiv
title: The `fdiv` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #fdiv-instruction
quote: "The ‘fdiv’ instruction returns the quotient of its two operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.floatBin, MojoProof.Sym.exec_fbin, MojoProof.Sym.exec_fbinC
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `fdiv` instruction

## Rule

LangRef's section on `fdiv` (the quote is the first sentence of its overview). The importer reads `fdiv` as `Inst.fbin` with `FBinOp.fdiv` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.floatBin`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_fbin` (on a float element type, but fmul contract); `Sym.exec_fbinC` (on a float element type, fmul contract included, with coversC); refused (fmul contract without coversC, or a non-float element type): SState.stmt takes a contracted fmul only with its contract flag and no fbin on a non-float element type.

## Corpus

34 of the 111 corpus files use it (445 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `fdiv` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
