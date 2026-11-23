---
id: inst-fsub
title: The `fsub` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #fsub-instruction
quote: "The ‘fsub’ instruction returns the difference of its two operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.floatBin, MojoProof.Sym.exec_fbin, MojoProof.Sym.exec_fbinC
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L3
evidence: L2: tests/gpu/vsub/record.txt; L3: vsub
---
# The `fsub` instruction

## Rule

LangRef's section on `fsub` (the quote is the first sentence of its overview). The importer reads `fsub` as `Inst.fbin` with `FBinOp.fsub` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.floatBin`. MojoProofTest/Modelled.lean runs a kernel of it (its row `fsub`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_fbin` (on a float element type, but fmul contract); `Sym.exec_fbinC` (on a float element type, fmul contract included, with coversC); refused (fmul contract without coversC, or a non-float element type): SState.stmt takes a contracted fmul only with its contract flag and no fbin on a non-float element type.

## Corpus

35 of the 114 corpus files use it (480 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`).

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/vsub/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Proved kernels

Used by a proved kernel, not proved on its own. The kernel cards with L2 evidence whose `Kernel.Sound` theorems are about a program whose IR uses it, with those theorems: vsub (`MojoProof.Kernels.vsub.correct`). A theorem's program is the corpus file `mojo_import` or `mojo_corpus` binds it to; the other files a kernel card cites do not count. Each such theorem covers the forms of the construct in the IR of the program it is about, at the launches and on the memories its premises admit.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `fsub` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), and on the GPU runs above for their inputs, not on a check against LLVM.

## Open

L3 is the top of the construct ladder. It says the construct is used by a proved kernel, not that it has a theorem of its own: the forms of it that no proved kernel's IR uses are covered by no theorem.
