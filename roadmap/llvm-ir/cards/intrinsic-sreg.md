---
id: intrinsic-sreg
title: The intrinsic family `Intrinsic.sreg`
kind: construct
ref: PTX ISA 9.5 #special-registers-tid
quote: "Thread identifier within a CTA."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sym.exec_sreg
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The intrinsic family `Intrinsic.sreg`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The family is the special registers `%tid`, `%ntid`, `%ctaid` and `%nctaid` in x, y and z; the ref is the section on `%tid` (PTX ISA 10.1; `%ntid` 10.2, `%ctaid` 10.6, `%nctaid` 10.7). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_sreg` (a special register: no arguments, no fast-math flags, before any store).

## Corpus

103 of the 111 corpus files use it (511 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.read.ptx.sreg.ctaid.x`, `llvm.nvvm.read.ptx.sreg.ctaid.y`, `llvm.nvvm.read.ptx.sreg.ctaid.z`, `llvm.nvvm.read.ptx.sreg.nctaid.x`, `llvm.nvvm.read.ptx.sreg.nctaid.y`, `llvm.nvvm.read.ptx.sreg.ntid.x`, `llvm.nvvm.read.ptx.sreg.ntid.y`, `llvm.nvvm.read.ptx.sreg.tid.x`, `llvm.nvvm.read.ptx.sreg.tid.y`, `llvm.nvvm.read.ptx.sreg.tid.z`.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`). L3 counts that only through a kernel card with a recorded GPU run, and no kernel has one.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
