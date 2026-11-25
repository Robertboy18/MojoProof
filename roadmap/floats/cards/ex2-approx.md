---
id: ex2-approx
title: ex2.approx.ftz.f32, the approximate base-2 exponential of Mojo's float32 exp
kind: construct
ref: PTX ISA 9.5 #9.7.3.21
quote: ""
lean: MojoProof.Float.Ex2Close, MojoProof.Float.ex2Err, MojoProof.Float.ex2Tiny, MojoProof.Float.log2e, MojoProof.Float.log2e_close, MojoProof.Float.ex2_error, MojoProof.Float.ex2Sum_error
corpus: none
tests: MojoProofTest.FloatEx2
upstream:
depends: binary-op-rounding
level: L1
---

# ex2.approx

**The rule.** Mojo's float32 `exp` (the standard library's `math.exp`) multiplies its operand by
the word `0x3FB8AA3B` of `log₂ e` and applies PTX's `ex2.approx.ftz.f32`, emitted as inline
assembly. The PTX ISA documents a maximum error of 2 ulp from the correctly rounded result across
the full range of inputs, and the flushing of subnormal inputs and results to zero of their sign.

**In Lean.** `MojoProof.Float.Ex2Close a w` is the contract at a finite operand `a < 128`: the
word `w` is finite and within `ex2Err · 2 ^ a + ex2Tiny` of `2 ^ a`, with `ex2Err = 3 · 2 ^ -23`
and `ex2Tiny = 2 ^ -126`, the consequence of the documented bound. `log2e_close` bounds the
multiplier word, `ex2_error` one compiled term `exp (x - m)` and `ex2Sum_error` the
max-subtracted exponential sum along any tree. The contract is a premise on the term words: the
execution model stops at inline assembly, so no semantics' value is tied to it.

**Out of scope.** Operands of 128 or more, `-∞` (whose `+0` is outside the contract), the
non-`ftz` form, and hardware outside the documented bound.

**Open.** No corpus file has the instruction. L2: no recorded GPU run. Ref: quote to be added.
