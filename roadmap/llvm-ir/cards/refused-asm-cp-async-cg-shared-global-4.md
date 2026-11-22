---
id: refused-asm-cp-async-cg-shared-global-4
title: Refused: inline asm `cp.async.cg.shared.global` with 4 operands
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cp-async
quote: "Initiates an asynchronous copy operation from one state space to another."
lean: not stated yet
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_01cf4f39.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_True_c8f5de2a.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_1_b8699ce6f48a0bbb.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_3_66061507eda154ac.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_compute_fn_float32_float32_float32_True_b_933c66779e5fed79.nvptx.ll
tests: MojoProofTest.Corpus
upstream:
level: L0
---
# Refused: inline asm `cp.async.cg.shared.global` with 4 operands

## Rule

The importer refuses a call of inline assembly: `Parser.inst` reads no `asm` callee, and the corpus check records the files it refuses in tests/corpus/REFUSALS.tsv with the reason `unsupported inline asm "cp.async.cg.shared.global [$0], [$1], $2, $3;", "r,l,n,r"`. The quote is the first sentence of PTX ISA's section on `cp`, the instruction the string holds.

## Corpus

22 of the 111 corpus files use it (22 uses); `corpus` lists the first 5 in path order.

## Out of scope

Everything: no Lean model exists, and the files that call it are not imported.

## Open

A model of the instruction (an intrinsic family with a stated contract) before the importer can accept these files.
