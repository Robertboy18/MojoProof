---
id: inst-icmp
title: The `icmp` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #icmp-instruction
quote: "The ‘icmp’ instruction returns a boolean value or a vector of boolean values based on comparison of its two integer, integer vector, pointer, or pointer vector operands."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.LLVM.ICmp.holds, MojoProof.Sym.exec_icmp
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `icmp` instruction

## Rule

LangRef's section on `icmp` (the quote is the first sentence of its overview). The importer reads `icmp` as `Inst.icmp` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.LLVM.ICmp.holds`. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_icmp` (on an integer type, before any store); refused (on a non-integer type, or after a store): SState.stmt takes icmp on an integer type before the block's first store only.

## Corpus

111 of the 111 corpus files use it (4869 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`). L3 counts that only through a kernel card with a recorded GPU run, and no kernel has one.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `icmp` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
