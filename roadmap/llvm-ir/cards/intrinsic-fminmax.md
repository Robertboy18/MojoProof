---
id: intrinsic-fminmax
title: The intrinsic family `Intrinsic.fminmax`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-maxnum-intrinsic
quote: "The ‘llvm.maxnum.*’ intrinsics return the maximum of the two arguments."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.fminmax`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is `llvm.maxnum` and `llvm.minnum`; the ref is the section on `llvm.maxnum`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.fminmax`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

36 of the 127 corpus files use it (381 uses); `corpus` lists the first 5 in path order. The members called: `llvm.maxnum.f32`, `llvm.maxnum.v2f32`, `llvm.maxnum.v4f32`.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
