---
id: inst-store
title: The `store` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #store-instruction
quote: "The ‘store’ instruction is used to write to memory."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_store
corpus: tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, tests/corpus/gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L3
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vmul, vsub
---
# The `store` instruction

## Rule

LangRef's section on `store` (the quote is the first sentence of its overview). The importer reads `store` as `Inst.store` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. MojoProofTest/Modelled.lean runs a kernel of it (its row `store`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_store`.

## Corpus

116 of the 116 corpus files use it (24032 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`).

## GPU runs

A conformance test, not a proof. The records of GPU runs of corpus kernels whose IR uses it: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt. In each, the grid evaluator ran the imported corpus program on the inputs of the GPU run, and its output buffer agreed with the GPU's, bit for bit over the whole buffer, on every launch the record lists. That covers the forms of the construct those kernels use, on those inputs and launches, and nothing else.

## Proved kernels

Used by a proved kernel, not proved on its own. The kernel cards with L2 evidence whose `Kernel.Sound` theorems are about a program whose IR uses it, with those theorems: naive-matmul (`MojoProofTest.NaiveKernel.correct`, `MojoProofTest.NaiveOff.correct`); vadd (`MojoProof.Kernels.vadd.correct`); vmul (`MojoProof.Kernels.vmul.correct`); vsub (`MojoProof.Kernels.vsub.correct`). A theorem's program is the corpus file `mojo_import` or `mojo_corpus` binds it to; the other files a kernel card cites do not count. Each such theorem covers the forms of the construct in the IR of the program it is about, at the launches and on the memories its premises admit.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `store` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), and on the GPU runs above for their inputs, not on a check against LLVM.

## Open

L3 is the top of the construct ladder. It says the construct is used by a proved kernel, not that it has a theorem of its own: the forms of it that no proved kernel's IR uses are covered by no theorem.
