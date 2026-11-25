---
id: intrinsic-shfl
title: The intrinsic family `Intrinsic.shfl`
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-shfl-sync
quote: "Register data shuffle within threads of a warp."
lean: MojoProof.LLVM.Intrinsic.ofDecl, MojoProof.LLVM.Intrinsic, MojoProof.Sem.intrinsic, MojoProof.Sem.shflSource
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The intrinsic family `Intrinsic.shfl`

## Rule

PTX ISA's section on the instruction NVPTX lowers it to (the quote is the section's first sentence). The importer accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its name and signature (`Intrinsic.name`, `Intrinsic.sig`). The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`, and the grid completes the collective call in `MojoProof.Sem.Grid.fire`. MojoProofTest/Modelled.lean runs a kernel of a call (its row `Intrinsic.shfl`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt takes calls of special registers and of minmax only.

## Corpus

62 of the 116 corpus files use it (978 uses); `corpus` lists the first 5 in path order. The members called: `llvm.nvvm.shfl.sync.bfly.i32`, `llvm.nvvm.shfl.sync.idx.i32`.

## Out of scope

Members of the family the corpus does not call. The NVPTX backend's documentation of the NVVM intrinsics is not quoted (no local copy); that the intrinsic is the PTX instruction cited rests on reading the PTX ISA (docs/TRUST.md T7).

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
