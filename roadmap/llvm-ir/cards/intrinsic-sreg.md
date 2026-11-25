---
id: intrinsic-sreg
title: The intrinsic family `Intrinsic.sreg`
kind: construct
ref: PTX ISA 9.5 #special-registers-tid
quote: "Thread identifier within a CTA."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sym.exec_sreg
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L3
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vmul, vsub
---
# The intrinsic family `Intrinsic.sreg`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is the special registers `%tid`, `%ntid`, `%ctaid` and `%nctaid` in x, y and z; the ref is the section on `%tid` (PTX ISA 10.1; `%ntid` 10.2, `%ctaid` 10.6, `%nctaid` 10.7). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.sreg`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_sreg` (a special register: no arguments, no fast-math flags).

## Corpus

108 of the 116 corpus files use it (532 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.read.ptx.sreg.ctaid.x`, `llvm.nvvm.read.ptx.sreg.ctaid.y`, `llvm.nvvm.read.ptx.sreg.ctaid.z`, `llvm.nvvm.read.ptx.sreg.nctaid.x`, `llvm.nvvm.read.ptx.sreg.nctaid.y`, `llvm.nvvm.read.ptx.sreg.ntid.x`, `llvm.nvvm.read.ptx.sreg.ntid.y`, `llvm.nvvm.read.ptx.sreg.tid.x`, `llvm.nvvm.read.ptx.sreg.tid.y`, `llvm.nvvm.read.ptx.sreg.tid.z`.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`).

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Proved kernels

Used by a proved kernel, not proved on its own. The kernel cards with L2 evidence whose `Kernel.Sound` theorems are about a program whose IR uses it, with those theorems: naive-matmul (`MojoProofTest.NaiveKernel.correct`, `MojoProofTest.NaiveOff.correct`); vadd (`MojoProof.Kernels.vadd.correct`); vmul (`MojoProof.Kernels.vmul.correct`); vsub (`MojoProof.Kernels.vsub.correct`). A theorem's program is the corpus file `mojo_import` or `mojo_corpus` binds it to; the other files a kernel card cites do not count. Each such theorem covers the forms of the construct in the IR of the program it is about, at the launches and on the memories its premises admit.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L3 is the top of the construct ladder. It says the construct is used by a proved kernel, not that it has a theorem of its own: the forms of it that no proved kernel's IR uses are covered by no theorem.
