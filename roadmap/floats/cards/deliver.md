---
id: deliver
title: deliver, the result of a floating-point operation as a word, NaNs from the oracle
kind: construct
ref: LLVM LangRef 24.0.0git #behavior-of-floating-point-nan-values
quote: ""
lean: MojoProof.Sem.deliver, MojoProof.Sem.deliver_finite, MojoProof.Sem.exists_deliver, MojoProof.Sem.not_finite_deliver, MojoProof.Sem.FinEq, MojoProof.Sem.FinEq.deliver, MojoProof.Sem.Ctx.oracle
corpus: none
tests: MojoProofTest.FloatRel, MojoProofTest.Kernel.vadd_finEq, MojoProofTest.Gpu
upstream:
level: L3
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vmul, vsub
---

# deliver

**The rule.** Where LangRef leaves a floating-point result open (a NaN's bits), the semantics
takes the choice from an oracle, and a statement holds for every oracle.

**In Lean.** `MojoProof.Sem.deliver r n` is the IEEE result `r` unless it is a NaN, and
otherwise the NaN with bits `n` (`r` if `n` encodes no NaN): `deliver_finite`,
`not_finite_deliver`, `exists_deliver`. `FinEq` relates two words that are equal or both not
finite; `FinEq.deliver` and `vadd_finEq` use it.

**Tested against a GPU (L2).** A conformance test, not a proof. In the four records (naive,
vadd, vmul, vsub), every word the threads write is a float result the evaluator delivers, and
every word of each output buffer is the same on one A100 and in the grid evaluator, bit for
bit: finite words, infinities (476 cells of the naive run) and zeros (the naive run's
underflow and its `k = 0` launch). No result is a NaN (the inputs are finite and no operation
of these kernels makes a NaN from them; the fill word 0x7FBADBAD of the words no thread writes
is no result), so the records test only the case where `deliver` returns the IEEE result
(`deliver_of_isNaN_eq_false`); the oracles (always 0, and always 2 for naive) encode no NaN.
The choice of a NaN's bits is not tested.

**Used by a proved kernel (L3).** naive-matmul, vadd, vmul and vsub: every float result of
their programs is delivered, and their theorems hold for every oracle, so for every NaN
`deliver` may give (`MojoProofTest.Kernel.vadd_finEq` with `FinEq.deliver`; the naive matmul's
`matmul_nanEq` states `NaNEq`).

**Open.** The construct ladder's top level. A GPU run that makes a NaN would test the NaN
case. Ref: quote to be added.
