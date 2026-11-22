---
id: refused-asm-cp-async-cg-shared-global-3
title: Refused: inline asm `cp.async.cg.shared.global` with 3 operands
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cp-async
quote: "Initiates an asynchronous copy operation from one state space to another."
lean: not stated yet
corpus: tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_126ea5ea.nvptx.ll, tests/corpus/mgemm/g_multistage_gemm_kernel_bfloat16_bfloat16_bfloat16_False_d7e21bec.nvptx.ll
tests: MojoProofTest.Corpus
upstream:
level: L0
---
# Refused: inline asm `cp.async.cg.shared.global` with 3 operands

## Rule

The importer refuses a call of inline assembly: `Parser.inst` reads no `asm` callee, and the corpus check records the files it refuses in tests/corpus/REFUSALS.tsv with the reason `unsupported inline asm "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"`. The quote is the first sentence of PTX ISA's section on `cp`, the instruction the string holds.

## Corpus

2 of the 114 corpus files use it (2 uses).

## Out of scope

Everything: no Lean model exists, and the files that call it are not imported.

## Open

A model of the instruction (an intrinsic family with a stated contract) before the importer can accept these files.
