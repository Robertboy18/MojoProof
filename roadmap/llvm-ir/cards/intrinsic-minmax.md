---
id: intrinsic-minmax
title: The intrinsic family `Intrinsic.minmax`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-smax-intrinsic
quote: "Return the larger of %a and %b comparing the values as signed integers."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sem.intMinMax, MojoProof.Sym.exec_minmax
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L2
evidence: L2: tests/gpu/naive/record.txt
---
# The intrinsic family `Intrinsic.minmax`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is `llvm.smax`, `llvm.smin`, `llvm.umax` and `llvm.umin`; the ref is the section on `llvm.smax`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.minmax`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_minmax` (two arguments, no flags or attributes, before or after a store); refused (with other arguments, flags or attributes): SState.stmt takes minmax with two arguments and no flags or attributes only.

## Corpus

82 of the 114 corpus files use it (462 uses); `corpus` lists the first 5 in path order. The members called: `llvm.smax.i64`, `llvm.smin.i64`.

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L3 needs a kernel card (roadmap/kernels/) with L2 evidence, a proved kernel, whose program uses the construct; this script reads no kernel card and writes no L3 evidence.
