---
id: term-br
title: The `br` terminator
kind: construct
ref: LLVM LangRef 24.0.0git #br-instruction
quote: "The ‘br’ instruction is used to cause control flow to transfer to a different basic block in the current function."
lean: MojoProof.LLVM.Parser.terminator, MojoProof.LLVM.Term, MojoProof.Sem.step, MojoProof.Sym.SState.exit_sound, MojoProof.Sym.SState.exitAt_sound
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L2
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt
---
# The `br` terminator

## Rule

LangRef's section on `br` (the quote is the first sentence of its overview). The importer reads `br` as `Term.br` or `Term.condBr` (`Parser.terminator`); the semantics gives it a meaning in `MojoProof.Sem.step`. MojoProofTest/Modelled.lean runs a kernel of it (its row `br`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.SState.exit_sound` (into blocks that start without a phi); `Sym.SState.exitAt_sound` (into blocks that start with phis); refused (a condition or phi operand outside the fragment): SState.exitAt gives none; `Sym.SState.exit_sound` (into blocks that start without a phi); `Sym.SState.exitAt_sound` (into blocks that start with phis); refused (a condition or phi operand outside the fragment): SState.exitAt gives none.

## Corpus

106 of the 114 corpus files use it (13759 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`). L3 counts that only through a kernel card (roadmap/kernels/) with L2 evidence, which this script does not read.

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `br` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), and on the GPU runs above for their inputs, not on a check against LLVM.

## Open

L3 needs a kernel card (roadmap/kernels/) with L2 evidence, a proved kernel, whose program uses the construct; this script reads no kernel card and writes no L3 evidence.
