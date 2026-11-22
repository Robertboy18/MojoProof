---
id: inst-call
title: The `call` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #call-instruction
quote: "The ‘call’ instruction represents a simple function call."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sym.exec_sreg, MojoProof.Sym.exec_minmax
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `call` instruction

## Rule

LangRef's section on `call` (the quote is the first sentence of its overview). The importer reads `call` as `Inst.call` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_sreg` (a special register: no arguments, no fast-math flags, before any store); `Sym.exec_minmax` (two arguments, no flags or attributes, before or after a store); refused (another callee, arguments, fast-math flags, or after a store): SState.stmt takes calls of special registers and of minmax only.

## Corpus

111 of the 111 corpus files use it (48450 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`). L3 counts that only through a kernel card with a recorded GPU run, and no kernel has one.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `call` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
