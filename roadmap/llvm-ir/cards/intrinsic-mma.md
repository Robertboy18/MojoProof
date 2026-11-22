---
id: intrinsic-mma
title: The intrinsic family `Intrinsic.mma`
kind: construct
ref: PTX ISA 9.5 #warp-level-matrix-instructions-mma
quote: "Perform matrix multiply-and-accumulate operation"
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The intrinsic family `Intrinsic.mma`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

29 of the 111 corpus files use it (1541 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.mma.m16n8k16.row.col.bf16`, `llvm.nvvm.mma.m16n8k4.row.col.tf32`, `llvm.nvvm.mma.m16n8k8.row.col.bf16`, `llvm.nvvm.mma.m16n8k8.row.col.f32.f32`, `llvm.nvvm.mma.m16n8k8.row.col.tf32`, `llvm.nvvm.mma.m8n8k4.row.col.f64`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
