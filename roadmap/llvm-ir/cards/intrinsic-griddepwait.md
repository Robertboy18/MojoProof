---
id: intrinsic-griddepwait
title: The intrinsic family `Intrinsic.griddepWait`
kind: construct
ref: PTX ISA 9.5 #parallel-synchronization-and-communication-instructions-griddepcontrol
quote: "Control execution of dependent grids."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w4_b256_gs_False_506bb3e7.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.griddepWait`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). PTX ISA has one section for `griddepcontrol.wait` and `griddepcontrol.launch_dependents`. The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.griddepWait`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

12 of the 116 corpus files use it (12 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.griddepcontrol.wait`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
