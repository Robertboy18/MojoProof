---
id: inst-fadd
title: The `fadd` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #fadd-instruction
quote: "The ‘fadd’ instruction returns the sum of its two operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.floatBin, MojoProof.Sym.exec_fbin, MojoProof.Sym.exec_fbinC
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L2
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt
---
# The `fadd` instruction

## Rule

LangRef's section on `fadd` (the quote is the first sentence of its overview). The importer reads `fadd` as `Inst.fbin` with `FBinOp.fadd` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.floatBin`. MojoProofTest/Modelled.lean runs a kernel of it (its row `fadd`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_fbin` (on a float element type, but fmul contract); `Sym.exec_fbinC` (on a float element type, fmul contract included, with coversC); refused (fmul contract without coversC, or a non-float element type): SState.stmt takes a contracted fmul only with its contract flag and no fbin on a non-float element type.

## Corpus

79 of the 114 corpus files use it (2068 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`). L3 counts that only through a kernel card (roadmap/kernels/) with L2 evidence, which this script does not read.

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `fadd` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), and on the GPU runs above for their inputs, not on a check against LLVM.

## Open

L3 needs a kernel card (roadmap/kernels/) with L2 evidence, a proved kernel, whose program uses the construct; this script reads no kernel card and writes no L3 evidence.
