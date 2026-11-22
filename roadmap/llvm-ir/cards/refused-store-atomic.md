---
id: refused-store-atomic
title: Refused: `store atomic`
kind: construct
ref: LLVM LangRef 24.0.0git #store-instruction
quote: "The ‘store’ instruction is used to write to memory."
lean: not stated yet
corpus: none
tests: MojoProofTest.Corpus
upstream:
level: L0
---
# Refused: `store atomic`

## Rule

The importer refuses `store atomic` with the message `unsupported instruction 'store atomic'` (`Parser.inst`). The quote is the first sentence of LangRef's section on `store`; the atomic form is described in the same section.

## Corpus

No corpus file uses it: the corpus check would refuse such a file, and tests/corpus/REFUSALS.tsv gives no such reason.

## Out of scope

Everything: no Lean model exists.

## Open

A model of the atomic load and store orderings, if a kernel needs them.
