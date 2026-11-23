---
id: intrinsic-laneid
title: The intrinsic family `Intrinsic.laneid`
kind: construct
ref: PTX ISA 9.5 #special-registers-laneid
quote: "Lane Identifier."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sym.exec_laneid
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.laneid`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.laneid`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_laneid` (the lane number: no arguments, no fast-math flags, before any store).

## Corpus

68 of the 114 corpus files use it (68 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.read.ptx.sreg.laneid`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
