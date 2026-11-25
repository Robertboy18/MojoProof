---
id: refused-asm-cvt-rn-f16x2-e4m3x2-2
title: Refused: inline asm `cvt.rn.f16x2.e4m3x2` with 2 operands
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cvt
quote: "Convert a value from one type to another."
lean: not stated yet
corpus: tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_2e0d4661.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_True_7946e0b2.nvptx.ll
tests: MojoProofTest.Corpus
upstream:
level: L0
---
# Refused: inline asm `cvt.rn.f16x2.e4m3x2` with 2 operands

## Rule

The importer refuses a call of inline assembly whose template and constraints are not of a form it accepts (`AsmCall.ofText?` in `Module.check`), and the corpus check records the files it refuses in tests/corpus/REFUSALS.tsv with the reason `unsupported inline asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h"`. The quote is the first sentence of PTX ISA's section on `cvt`, the instruction the string holds.

## Corpus

4 of the 116 corpus files use it (4 uses).

## Out of scope

Everything: no Lean model exists, and the files that call it are not imported.

## Open

A model of the instruction (an intrinsic family with a stated contract) before the importer can accept these files.
