---
id: deliver
title: deliver, the result of a floating-point operation as a word, NaNs from the oracle
kind: construct
ref: LLVM LangRef 24.0.0git #behavior-of-floating-point-nan-values
quote: ""
lean: MojoProof.Sem.deliver, MojoProof.Sem.deliver_finite, MojoProof.Sem.exists_deliver, MojoProof.Sem.not_finite_deliver, MojoProof.Sem.FinEq, MojoProof.Sem.FinEq.deliver, MojoProof.Sem.Ctx.oracle
corpus: none
tests: MojoProofTest.FloatRel, MojoProofTest.Kernel.vadd_finEq
upstream:
level: L1
evidence: L3: vadd, vmul
---

# deliver

**The rule.** Where LangRef leaves a floating-point result open (a NaN's bits), the semantics
takes the choice from an oracle, and a statement holds for every oracle.

**In Lean.** `MojoProof.Sem.deliver r n` is the IEEE result `r` unless it is a NaN, and
otherwise the NaN with bits `n` (`r` if `n` encodes no NaN): `deliver_finite`,
`not_finite_deliver`, `exists_deliver`. `FinEq` relates two words that are equal or both not
finite; `FinEq.deliver` and `vadd_finEq` use it.

**Open.** L2: no recorded GPU run. Ref: quote to be added.
