---
id: contract
title: contract, the fast-math flag that lets fmul and fadd fuse into one rounding
kind: construct
ref: LLVM LangRef 24.0.0git #fast-math-flags
quote: ""
lean: MojoProof.LLVM.FastMath.contract, MojoProof.Sem.contract, MojoProof.Sem.contract_cases, MojoProof.Sem.contract_unfused, MojoProof.Sem.contract_error, MojoProof.Sem.contract_est, MojoProof.Sem.floatBin_contract, MojoProof.Sem.floatBin_contract_est, FloatLib.Floats.Formats.BinaryInterchange.Model.fma
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_*
tests: MojoProofTest.FloatRel.contract_est_inst, MojoProofTest.FloatRel.contract_est_twin, MojoProofTest.SymContract
upstream:
depends: binary-op-rounding
level: L1
---

# contract

**The rule.** With `contract` on an `fmul` and the `fadd` that uses it, the pair may be
computed with one rounding (a fused multiply-add) or with two.

**In Lean.** In `MojoProof.Sem.contract` the oracle number selects the separately rounded
operation or FloatLib's `Model.fma` of one of the recorded products and the other operand;
`contract_cases` says the result is one of these, `contract_unfused` when to expect the
unfused one, and `contract_error` and `contract_est` bound a finite result's distance from the
exact value, fused or not, for every IEEE format. The block checker records the
products of `fmul contract` (MojoProofTest.SymContract). The naive matmul's specializations
built with contraction on have it.

**Out of scope.** The other fast-math flags (`reassoc`, `afn` and the rest) are a separate
matter.

**Open.** L2: no recorded GPU run. L3: no proved kernel contracts (the naive matmul would).
Ref: quote to be added.
