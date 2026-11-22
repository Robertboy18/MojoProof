---
id: intrinsic-lifetime
title: The intrinsic family `Intrinsic.lifetime`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-lifetime-start-intrinsic
quote: "The ‘llvm.lifetime.start’ intrinsic specifies the start of a memory object’s lifetime."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sem.lifetimeStarted
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.lifetime`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is `llvm.lifetime.start` and `llvm.lifetime.end`; the ref is the section on `llvm.lifetime.start`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.lifetime`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

67 of the 114 corpus files use it (36476 uses); `corpus` lists the first 5 in path order. The members called: `llvm.lifetime.end.p0`, `llvm.lifetime.start.p0`.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
