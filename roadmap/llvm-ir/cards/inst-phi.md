---
id: inst-phi
title: The `phi` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #phi-instruction
quote: "The ‘phi’ instruction is used to implement the φ node in the SSA graph representing the function."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L2
evidence: L2: tests/gpu/naive/record.txt
---
# The `phi` instruction

## Rule

LangRef's section on `phi` (the quote is the first sentence of its overview). The importer reads `phi` as `Inst.phi` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `phi`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): refused: set on the edge into its block (SState.phiConds), not by SState.stmt.

## Corpus

102 of the 114 corpus files use it (3412 uses); `corpus` lists the first 5 in path order.

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `phi` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), and on the GPU runs above for their inputs, not on a check against LLVM.

## Open

L3 needs a kernel card (roadmap/kernels/) with L2 evidence, a proved kernel, whose program uses the construct; this script reads no kernel card and writes no L3 evidence.
