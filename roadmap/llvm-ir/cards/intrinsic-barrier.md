---
id: intrinsic-barrier
title: The intrinsic family `Intrinsic.barrier`
kind: construct
ref: PTX ISA 9.5 #parallel-synchronization-and-communication-instructions-bar
quote: "Barrier synchronization."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic
corpus: tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gemv_dev2026112705/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.barrier`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`, and the grid completes the collective call in `MojoProof.Sem.Grid.fire`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.barrier`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

56 of the 127 corpus files use it (123 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.barrier.cta.sync.aligned.all`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a corpus kernel whose IR uses the construct; there is none. tests/gpu/cp-async/record.txt:25 records a GPU run, on NVIDIA A100-SXM4-80GB, of a test kernel of one instruction that calls `llvm.nvvm.barrier.cta.sync.aligned.all`, `llvm.nvvm.cp.async.commit.group`, `llvm.nvvm.cp.async.wait.group`; it is not a corpus kernel, so the rule of L2 (a record of a corpus kernel whose IR uses the construct) does not count it.
