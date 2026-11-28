---
id: intrinsic-extract
title: The intrinsic family `Intrinsic.extract`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-vector-extract-intrinsic
quote: "The ‘llvm.vector.extract.*’ intrinsics extract a vector from within another vector starting from a given index."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs128_2d84049c.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs256_b2a56671.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs64_3aca57b2.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r2_ax1_w4_bs1024_e8108490.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.extract`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.extract`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

30 of the 127 corpus files use it (4868 uses); `corpus` lists the first 5 in path order. The members called: `llvm.vector.extract.v2bf16.v4bf16`, `llvm.vector.extract.v2f16.v4f16`, `llvm.vector.extract.v2f32.v2f32`, `llvm.vector.extract.v2i32.v4i32`, `llvm.vector.extract.v4bf16.v8bf16`, `llvm.vector.extract.v4f32.v4f32`, `llvm.vector.extract.v4i32.v8i32`.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
