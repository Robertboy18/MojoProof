---
id: binary-op-rounding
title: the rounding of fadd, fsub, fmul and fdiv, to nearest even in the operation's format
kind: construct
ref: LLVM LangRef 24.0.0git #fadd-instruction
quote: ""
lean: MojoProof.Sem.floatBin, MojoProof.Sem.floatBin_ofFloat, MojoProof.Sem.floatOp, MojoProof.Sem.fbin, MojoProof.Sem.fbin_finite, FloatLib.Floats.Formats.BinaryInterchange.Model.add, FloatLib.Floats.Formats.BinaryInterchange.Model.sub, FloatLib.Floats.Formats.BinaryInterchange.Model.mul, FloatLib.Floats.Formats.BinaryInterchange.Model.div, FloatLib.Floats.Formats.BinaryInterchange.Model.roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_add_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_sub_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_mul_eq_roundAt, FloatLib.Floats.Formats.BinaryInterchange.Model.toReal_div_eq_roundAt
corpus: tests/corpus/vadd, tests/corpus/vmul, tests/corpus/vsub, tests/corpus/mgemm_nocontract
tests: MojoProofTest.FloatRel, MojoProofTest.Ops, MojoProofTest.Gpu
upstream:
depends: deliver
level: L3
evidence: L2: tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vmul, vsub
---

# The rounding of the binary operations

**The rule.** `fadd`, `fsub`, `fmul` and `fdiv` without fast-math flags give the IEEE 754
result in the default environment: the exact result rounded to nearest, ties to even, in the
operands' format.

**In Lean.** `MojoProof.Sem.fbin` is the IEEE operation, FloatLib's `Model.add`, `Model.sub`,
`Model.mul` or `Model.div` (none for `frem`); `floatBin` applies it to values under the flags
and delivers the result. FloatLib's `toReal_add_eq_roundAt` (and the others) give
a finite result's real value as the exact one rounded (`Model.roundAt`).

**Tested against a GPU (L2).** A conformance test, not a proof. The records
tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt and tests/gpu/vsub/record.txt are runs on
one A100 of the corpus kernels whose only float operation is, in each thread, one binary32
`fadd contract`, `fmul` or `fsub contract` of two loaded words (`contract` fuses nothing there:
no operand is an `fmul contract`, so the result is rounded once, as without the flag). At six
launches each, every word of the output buffer is the same on the GPU and in the grid
evaluator, bit for bit, so `floatBin` agrees with the GPU's rounding on those operands: finite
binary32 words from the records' generator, 32 of them subnormal in each run. Not tested:
`fdiv`, formats other than binary32, and non-finite operands. The naive matmul's record does
not count here: its oracle fuses every `fadd contract` (the contract card).

**Used by a proved kernel (L3).** vadd, vmul and vsub: their real theorems
(`MojoProofTest.Kernel.vadd_real` and the others) give a finite output's real value as the
exact one rounded, with `toReal_add_eq_roundAt` and the others. naive-matmul: its theorems
hold for every oracle, the separately rounded `fmul` and `fadd` among the choices, and
`NaiveOff.correct` is about the kernel compiled with contraction off
(tests/corpus/mgemm_nocontract), whose `fmul` and `fadd` have no flag.

**Reductions.** In every IEEE format, the rounded `Model.add` along any tree of the inputs (a
loop, a butterfly of any width and order, a block's halving loop) is within
`((1 + u) ^ depth - 1) · Σ |v j|` of the exact sum when its result is finite
(`MojoProof.Float.sum_error`; `MojoProof.Float.sum_mixedError` for inputs with their own mixed
errors; `MojoProof.Float.block_error` for warps' butterflies followed by a tree over the warps).
The two-pass mean and variance (`MojoProof.Float.mean_error`, `MojoProof.Float.var_error`) and the
max-subtracted exponential sum and softmax entry (`MojoProof.Float.expSum_error`,
`MojoProof.Float.softmax_error`) add `Model.sub`, `Model.mul`, `Model.div` and FloatLib's correctly
rounded exponential (docs/proofs/float-reductions.md). They are about words, not a kernel, and
raise no level.

**Out of scope.** Other rounding modes and the floating-point environment (LLVM's default
assumes neither changes), and `frem`.

**Open.** The construct ladder's top level. A GPU run of an `fdiv` and of other formats would
test more of the rule. Ref: quote to be added.
