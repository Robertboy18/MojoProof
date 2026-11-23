---
id: inst-fpext
title: The `fpext` instruction
kind: construct
ref: LLVM LangRef 24.0.0git #fpext-to-instruction
quote: "The ‘fpext’ extends a floating-point value to a larger floating-point value."
lean: MojoProof.LLVM.Parser.inst, MojoProof.LLVM.Inst, MojoProof.Sem.exec, MojoProof.Sem.floatCast, MojoProof.Sym.exec_cast
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_bfloat16_bfloat16_bfloat16_True_16_ba3789d9.nvptx.ll, tests/corpus/mgemm/g_matmul_kernel_naive_float32_bfloat16_bfloat16_True_16_940bf0f4.nvptx.ll, tests/corpus/mgemm/g_matmul_kernel_naive_float8_e4m3fn_bfloat16_bfloat16_True_16_c159_00c8af24fa246f7a.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll, tests/corpus/mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_fee81d5b.nvptx.ll
tests: MojoProofTest.Rule, MojoProofTest.Corpus, MojoProofTest.Modelled
upstream:
level: L1
---
# The `fpext` instruction

## Rule

LangRef's section on `fpext` (the quote is the first sentence of its overview). The importer reads `fpext` as `Inst.cast` with `CastOp.fpext` (`Parser.inst`); the semantics gives it a meaning in `MojoProof.Sem.exec`, with `MojoProof.Sem.floatCast`. MojoProofTest/Modelled.lean runs a kernel of it (its row `fpext`), and the run returns. The block checker (MojoProof/Sym/Rules.lean): `Sym.exec_cast` (the casts castV evaluates (castOk): not fptoui, fptosi or inttoptr; ptrtoint before any store); refused (fptoui, fptosi, inttoptr, an ill-typed cast, or ptrtoint after a store): SState.stmt takes the casts castOk admits (castOk_iff: those castV evaluates), and ptrtoint before the block's first store only.

## Corpus

9 of the 114 corpus files use it (158 uses); `corpus` lists the first 5 in path order.

## Out of scope

Forms of the instruction the corpus does not use are read by the same parser case, but no corpus file exercises them. That the semantics gives `fpext` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), not on a check against LLVM.

## Open

L2 needs a recorded GPU run of a test of the construct; there is none.
