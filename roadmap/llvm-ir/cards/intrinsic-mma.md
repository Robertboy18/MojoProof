---
id: intrinsic-mma
title: The intrinsic family `Intrinsic.mma`
kind: construct
ref: PTX ISA 9.5 #warp-level-matrix-instructions-mma
quote: "Perform matrix multiply-and-accumulate operation"
lean: not stated yet
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L0
---
# The intrinsic family `Intrinsic.mma`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The level counts the family as parsed, not modelled: MojoProofTest/Modelled.lean's kernel of a call (its row `Intrinsic.mma`) stops with `unsupported: mma in a warp cut by its block of threads`. The grid gives a call a meaning in `MojoProof.Sem.Grid.fire` all the same: `MojoProof.Sem.Grid.fire_mma` (MojoProof/Sem/TensorCoreWarp.lean:445) proves that the step at it succeeds when the 32 lanes of the warp lie whole in their block of threads and wait at the same `mma`, its inputs are bf16 or f16 (`gridFmt`) with an f32 accumulator, and its A, B and C words are finite. The declarations: `MojoProof.LLVM.Intrinsic.ofDecl`, `MojoProof.LLVM.Intrinsic`, `MojoProof.Sem.intrinsic`. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

29 of the 127 corpus files use it (1541 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.mma.m16n8k16.row.col.bf16`, `llvm.nvvm.mma.m16n8k4.row.col.tf32`, `llvm.nvvm.mma.m16n8k8.row.col.bf16`, `llvm.nvvm.mma.m16n8k8.row.col.f32.f32`, `llvm.nvvm.mma.m16n8k8.row.col.tf32`, `llvm.nvvm.mma.m8n8k4.row.col.f64`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L1 needs the run of its test kernel (MojoProofTest/Modelled.lean) to return; it stops with `unsupported: mma in a warp cut by its block of threads`. That is the failure of this test kernel, not the absence of a semantics: `MojoProof.Sem.Grid.fire_mma` (MojoProof/Sem/TensorCoreWarp.lean:445) proves that the grid's step at a call succeeds, with the results the model gives, when the 32 lanes of the warp lie whole in their block of threads and wait at the same `mma`, its inputs are bf16 or f16 (`gridFmt`) with an f32 accumulator, and its A, B and C words are finite. Of the members the corpus calls, its premises admit `llvm.nvvm.mma.m16n8k16.row.col.bf16`, `llvm.nvvm.mma.m16n8k8.row.col.bf16`, `llvm.nvvm.mma.m16n8k8.row.col.f32.f32`, and not `llvm.nvvm.mma.m16n8k4.row.col.tf32`, `llvm.nvvm.mma.m16n8k8.row.col.tf32`, `llvm.nvvm.mma.m8n8k4.row.col.f64`. L2 then needs a recorded GPU run of a corpus kernel whose IR uses it; there is none. tests/gpu/mma/record.txt:63 records a GPU run, on NVIDIA A100-SXM4-80GB, of a test kernel of one instruction that calls `llvm.nvvm.mma.m16n8k16.row.col.bf16`; it is not a corpus kernel, so the rule of L2 (a record of a corpus kernel whose IR uses the construct) does not count it. Neither the theorem nor the record covers every member of the family, every launch or every GPU.
