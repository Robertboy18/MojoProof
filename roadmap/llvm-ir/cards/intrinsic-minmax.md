---
id: intrinsic-minmax
title: The intrinsic family `Intrinsic.minmax`
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-smax-intrinsic
quote: "Return the larger of %a and %b comparing the values as signed integers."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sem.intMinMax, MojoProof.Sym.exec_minmax
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gemv_dev2026112705/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv_dev2026112705/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L3
evidence: L2: tests/gpu/naive/record.txt; L3: naive-matmul
---
# The intrinsic family `Intrinsic.minmax`

## Rule

LangRef's section on the intrinsic (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is `llvm.smax`, `llvm.smin`, `llvm.umax` and `llvm.umin`; the ref is the section on `llvm.smax`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.minmax`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_minmax` (two arguments, no flags or attributes); refused (with other arguments, flags or attributes): SState.stmt takes minmax with two arguments and no flags or attributes only.

## Corpus

90 of the 127 corpus files use it (476 uses); `corpus` lists the first 5 in path order. The members called: `llvm.smax.i64`, `llvm.smin.i64`.

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Proved kernels

Used by a proved kernel, not proved on its own. The kernel cards with L2 evidence whose `Kernel.Sound` theorems are about a program whose IR uses it, with those theorems: naive-matmul (`MojoProofTest.NaiveKernel.correct`, `MojoProofTest.NaiveOff.correct`). A theorem's program is the corpus file `mojo_import` or `mojo_corpus` binds it to; the other files a kernel card cites do not count. Each such theorem covers the forms of the construct in the IR of the program it is about, at the launches and on the memories its premises admit.

## Out of scope

Members of the family the corpus does not call. That the semantics gives the family the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7).

## Open

L3 is the top of the construct ladder. It says the construct is used by a proved kernel, not that it has a theorem of its own: the forms of it that no proved kernel's IR uses are covered by no theorem.
