---
id: refused-asm-cvt-rn-satfinite-e4m3x2-f32-3
title: Refused: inline asm `cvt.rn.satfinite.e4m3x2.f32` with 3 operands
kind: construct
ref: PTX ISA 9.5 #data-movement-and-conversion-instructions-cvt
quote: "Convert a value from one type to another."
lean: not stated yet
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_float8_e4m3fn_bfloat16_bfloat16_True_16_c159_00c8af24fa246f7a.nvptx.ll
tests: MojoProofTest.Corpus
upstream:
level: L0
---
# Refused: inline asm `cvt.rn.satfinite.e4m3x2.f32` with 3 operands

## Rule

The importer refuses a call of inline assembly: `Parser.inst` reads no `asm` callee, and the corpus check records the files it refuses in tests/corpus/REFUSALS.tsv with the reason `unsupported inline asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f"`. The quote is the first sentence of PTX ISA's section on `cvt`, the instruction the string holds.

## Corpus

1 of the 114 corpus files use it (1 uses).

## Out of scope

Everything: no Lean model exists, and the files that call it are not imported.

## Open

A model of the instruction (an intrinsic family with a stated contract) before the importer can accept these files.
