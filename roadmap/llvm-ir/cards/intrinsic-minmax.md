---
id: intrinsic-minmax
title: The intrinsic family `Intrinsic.minmax`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-smax-intrinsic
quote: "Return the larger of %a and %b comparing the values as signed integers."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sem.intMinMax, MojoProof.Sym.exec_minmax
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The intrinsic family `Intrinsic.minmax`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is `llvm.smax`, `llvm.smin`, `llvm.umax` and `llvm.umin`; the ref is the section on `llvm.smax`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_minmax` (two arguments, no flags or attributes, before or after a store); refused (with other arguments, flags or attributes): SState.stmt takes minmax with two arguments and no flags or attributes only.

## Corpus

79 of the 111 corpus files use it (459 uses); `corpus` lists the first 5 in path order. The members called: `llvm.smax.i64`, `llvm.smin.i64`.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
