---
id: nan-payloads
title: NaN payloads, which NaN a floating-point operation may return
kind: construct
ref: LLVM LangRef 24.0.0git #behavior-of-floating-point-nan-values
quote: ""
lean: MojoProof.Sem.NaNEq, MojoProof.Sem.nanEq_deliver, MojoProof.Sem.isNaN_deliver, MojoProof.Sem.floatOp_isNaN, MojoProof.Sem.floatOp_nanEq, MojoProof.Sem.fbin_isNaN, FloatLib.Floats.Formats.BinaryInterchange.Model.isNaN, FloatLib.Floats.Formats.BinaryInterchange.Model.isSignaling, FloatLib.Floats.Formats.BinaryInterchange.Model.quietNaN, MojoProof.Float.add_comm_nanEq
corpus: none
tests: MojoProofTest.Payload, MojoProofTest.PayloadRun, MojoProofTest.FloatCanon
upstream:
depends: deliver
level: L1
evidence: L3: vadd, vmul
---

# NaN payloads

**The rule.** LangRef lets an operation whose result is a NaN return a NaN from a set: a
quiet copy of an input NaN, or a preferred or target-defined NaN, with any sign.

**In Lean.** The semantics allows any NaN (`MojoProof.Sem.deliver` on a NaN result), a
superset of LangRef's set, and states what does not depend on the choice through `NaNEq`
(two values equal but for the NaNs' bits): `nanEq_deliver`, `floatOp_nanEq`. FloatLib's
`Model.add` commutes up to NaN payloads in every format (`MojoProof.Float.add_comm_nanEq`); at
two quiet NaNs it returns the first operand's payload (`MojoProofTest.FloatCanon.nan_add32`,
`nan_add16`). The kernel theorems of vadd and vmul hold for every choice.

**Out of scope.** Narrowing the set to LangRef's (a program that inspects a NaN's payload
bits is then proved about more results than LLVM allows, never fewer).

**Open.** L2: no recorded GPU run. Ref: quote to be added.
