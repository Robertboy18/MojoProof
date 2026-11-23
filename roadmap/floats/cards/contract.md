---
id: contract
title: contract, the fast-math flag that lets fmul and fadd fuse into one rounding
kind: construct
ref: LLVM LangRef 24.0.0git #fast-math-flags
quote: ""
lean: MojoProof.LLVM.FastMath.contract, MojoProof.Sem.contract, MojoProof.Sem.contract_cases, MojoProof.Sem.contract_unfused, MojoProof.Sem.contract_error, MojoProof.Sem.contract_est, MojoProof.Sem.floatBin_contract, MojoProof.Sem.floatBin_contract_est, FloatLib.Floats.Formats.BinaryInterchange.Model.fma
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_*, tests/corpus/mgemm_sm80
tests: MojoProofTest.FloatRel.contract_est_inst, MojoProofTest.FloatRel.contract_est_twin, MojoProofTest.SymContract, MojoProofTest.Gpu
upstream:
depends: binary-op-rounding
level: L3
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vsub
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

**Tested against a GPU (L2).** A conformance test, not a proof.

- tests/gpu/naive/record.txt: the naive matmul kernel's loop computes each product with `fmul
  contract` and adds it to the sum with `fadd contract`, up to 768 rounds per cell. The grid
  evaluator ran every thread with the oracle that is always 2, which takes at every `fadd
  contract` the fused multiply-add of the product into the sum (`Model.fma`), and at eight
  launches every word of C is the same as on one A100, bit for bit (1356 cells written, 476 of
  them infinite). So the GPU's words are those the model gives when every pair fuses.
- tests/gpu/vadd/record.txt and tests/gpu/vsub/record.txt: one `fadd contract` or `fsub
  contract` of two loaded words per thread. No operand is an `fmul contract`, so every oracle
  number gives the separately rounded result, and the evaluator and the GPU agree on every
  word at six launches.

Not tested: the separately rounded choice where a product is offered (no record's oracle
takes it), formats other than binary32, and NaN operands (the naive record's sums reach
infinity in 476 cells, but no operand is a NaN).

**Used by a proved kernel (L3).** naive-matmul: `NaiveKernel.correct`, `matmul_nanEq` and
`matmul_error` are about the kernel built with contraction on, for every oracle family, so for
every choice, fused or not, at each `fadd contract`. vadd and vsub: their `fadd contract` and
`fsub contract` have no product to fuse, so every choice is the one rounding.

**Out of scope.** The other fast-math flags (`reassoc`, `afn` and the rest) are a separate
matter.

**Open.** The construct ladder's top level. A GPU run whose code does not fuse (or an oracle
that does not) would test the other choice. Ref: quote to be added.
