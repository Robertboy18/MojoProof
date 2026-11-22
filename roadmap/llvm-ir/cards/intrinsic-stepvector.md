---
id: intrinsic-stepvector
title: The intrinsic family `Intrinsic.stepvector`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-stepvector-intrinsic
quote: "The ‘llvm.stepvector’ intrinsics are used to create vectors of integers whose elements contain a linear sequence of values starting from 0 with a step of 1."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs128_2d84049c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs256_b2a56671.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs64_3aca57b2.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r2_ax1_w4_bs1024_e8108490.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The intrinsic family `Intrinsic.stepvector`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

18 of the 111 corpus files use it (18 uses); `corpus` lists the first 5 in path order. The members called: `llvm.stepvector.v2i64`, `llvm.stepvector.v4i64`.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
