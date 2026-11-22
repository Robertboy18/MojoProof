---
id: inst-atomicrmw
title: The `atomicrmw` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #atomicrmw-instruction
quote: "The ‘atomicrmw’ instruction is used to atomically modify memory."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.rmw
corpus: tests/corpus/reduction/reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `atomicrmw` instruction

## Rule

LangRef's section on `atomicrmw` (the quote is the first sentence of its overview). The importer reads `atomicrmw` as `Inst.atomicrmw` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.rmw`. The block checker (MojoProof/Sym/Rules.lean): refused: SState.stmt has no case for it.

## Corpus

1 of the 111 corpus files use it (1 uses).

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `atomicrmw` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
