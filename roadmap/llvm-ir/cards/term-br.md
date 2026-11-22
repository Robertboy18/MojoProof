---
id: term-br
title: The `br` terminator
kind: construct
ref: LLVM LangRef 24.0.0git #br-instruction
quote: "The ‘br’ instruction is used to cause control flow to transfer to a different basic block in the current function."
lean: MojoProof.LLVM.Parser.terminator, MojoProof.LLVM.Term, MojoProof.Sem.step, MojoProof.Sym.SState.exit_sound, MojoProof.Sym.SState.exitAt_sound
corpus: tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w4_bs1024_43a5be9b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus
upstream:
level: L1
---
# The `br` terminator

## Rule

LangRef's section on `br` (the quote is the first sentence of its overview). The importer reads `br` as `Term.br` or `Term.condBr` (`Parser.terminator`); the semantics gives it a meaning in `MojoProof.Sem.step`. The block checker (MojoProof/Sym/Rules.lean): `Sym.SState.exit_sound` (into blocks that start without a phi); `Sym.SState.exitAt_sound` (into blocks that start with phis); refused (a condition or phi operand outside the fragment): SState.exitAt gives none; `Sym.SState.exit_sound` (into blocks that start without a phi); `Sym.SState.exitAt_sound` (into blocks that start with phis); refused (a condition or phi operand outside the fragment): SState.exitAt gives none.

## Corpus

103 of the 111 corpus files use it (13729 uses); `corpus` lists the first 5 in path order.

The programs of the library's `mojo_kernel` theorems use it (`tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`, `tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll`, `tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`). L3 counts that only through a kernel card with a recorded GPU run, and no kernel has one.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `br` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
