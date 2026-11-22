---
id: binary-op-rounding
title: the rounding of fadd, fsub, fmul and fdiv, to nearest even in the operation's format
kind: construct
ref: LLVM LangRef 24.0.0git #fadd-instruction
quote: ""
lean: MojoProof.Sem.floatBin, MojoProof.Sem.floatBin_ofFloat, MojoProof.Sem.floatOp, MojoProof.Sem.fbin, MojoProof.Sem.fbin_finite, FloatLib.Floats.Formats.BinaryInterchange.Model.add, FloatLib.Floats.Formats.BinaryInterchange.Model.sub, FloatLib.Floats.Formats.BinaryInterchange.Model.mul, FloatLib.Floats.Formats.BinaryInterchange.Model.div, FloatLib.Floats.Formats.BinaryInterchange.Model.roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_add_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_sub_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_mul_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_div_eq_roundAt
corpus: tests/corpus/vadd, tests/corpus/vmul
tests: MojoProofTest.FloatRel, MojoProofTest.Ops
upstream:
depends: deliver
level: L1
evidence: L3: vadd, vmul
---

# The rounding of the binary operations

**The rule.** `fadd`, `fsub`, `fmul` and `fdiv` without fast-math flags give the IEEE 754
result in the default environment: the exact result rounded to nearest, ties to even, in the
operands' format.

**In Lean.** `MojoProof.Sem.fbin` is the IEEE operation, FloatLib's `Model.add`, `Model.sub`,
`Model.mul` or `Model.div` (none for `frem`); `floatBin` applies it to values under the flags
and delivers the result. FloatLib's `toReal_add_eq_roundAt` (and
the others) give a finite result's real value as the exact one rounded (`Model.roundAt`); vadd
and vmul's real theorems use them.

**Out of scope.** Other rounding modes and the floating-point environment (LLVM's default
assumes neither changes), and `frem`.

**Open.** L2: no recorded GPU run. Ref: quote to be added.
