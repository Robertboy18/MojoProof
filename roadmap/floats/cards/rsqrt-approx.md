---
id: rsqrt-approx
title: rsqrt.approx.ftz.f32, the approximate reciprocal square root
kind: construct
ref: PTX ISA 9.5 #9.7.3.16
quote: ""
lean: MojoProof.Sem.rsqrt, MojoProof.Sem.rsqrtErr, MojoProof.Sem.rsqrtOk, MojoProof.Sem.rpow_le_rsqrtErr, MojoProof.Sem.rsqrtOk_rSqrt, MojoProof.Sem.rsqrtOk_of_rsqrt, MojoProof.Sem.rsqrt_toNatBits, MojoProof.Sem.intrinsic_rsqrt, MojoProof.Sem.rsqrt_close, FloatLib.Floats.Formats.BinaryInterchange.Model.rSqrt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_rSqrt_eq_roundAt
corpus: tests/corpus/layernorm
tests: MojoProofTest.FloatRel
upstream:
depends: deliver
level: L1
---

# rsqrt.approx

**The rule.** `llvm.nvvm.rsqrt.approx.ftz.f` lowers to PTX's `rsqrt.approx.ftz.f32`, which the
PTX ISA documents only by its table of special inputs, a maximum relative error of 2^-22.9 over
the positive finite range, and the flushing of subnormal inputs and results.

**In Lean.** `MojoProof.Sem.rsqrt` returns the oracle's word when it meets that contract
(`rsqrtOk`, with the rational bound `rsqrtErr`, at least 2^-22.9 by `rpow_le_rsqrtErr`),
else FloatLib's `Model.rSqrt` of the flushed operand, which meets it (`rsqrtOk_rSqrt`). So its
values are exactly the words that meet the contract (`rsqrtOk_of_rsqrt`, `rsqrt_toNatBits`).
All 34 layer norm specializations call it.

**Out of scope.** Hardware outside the documented bound, and the non-`ftz` form.

**Open.** L2: no recorded GPU run. L3: no proved kernel calls it. Ref: the section is the one
docs/TRUST.md cites; quote to be added.
