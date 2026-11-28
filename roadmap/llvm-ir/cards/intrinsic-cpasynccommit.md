---
id: intrinsic-cpasynccommit
title: The intrinsic family `Intrinsic.cpAsyncCommit`
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cp-async-commit-group
quote: "Commits all prior initiated but uncommitted cp.async instructions into a cp.async-group."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.cpAsyncCommit`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.cpAsyncCommit`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

24 of the 127 corpus files use it (96 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.cp.async.commit.group`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a corpus kernel whose IR uses the construct; there is none. tests/gpu/cp-async/record.txt:25 records a GPU run, on NVIDIA A100-SXM4-80GB, of a test kernel of one instruction that calls `llvm.nvvm.barrier.cta.sync.aligned.all`, `llvm.nvvm.cp.async.commit.group`, `llvm.nvvm.cp.async.wait.group`; it is not a corpus kernel, so the rule of L2 (a record of a corpus kernel whose IR uses the construct) does not count it.
