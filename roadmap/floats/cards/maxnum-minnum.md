---
id: maxnum-minnum
title: llvm.maxnum and llvm.minnum, the floating-point maximum and minimum
kind: construct
ref: LLVM LangRef 24.0.0git #llvm-maxnum-intrinsic
quote: ""
lean: MojoProof.Sem.maxnum, MojoProof.Sem.maxnum_of_not_nan, MojoProof.Sem.maxnum_nanEq, MojoProof.Sem.intrinsic_fminmax, MojoProof.Sem.intrinsic_fminmax_ofFloat, MojoProof.Sem.intrinsic_fminmax_vec, MojoProof.Sem.fminmax_of_not_nan, MojoProof.Sem.fminmax_nanEq, MojoProof.Sem.fminmax_vec_of_not_nan, MojoProof.Sem.fminmax_vec_nanEq, FloatLib.Floats.Formats.BinaryInterchange.Model.maximumNumber, FloatLib.Floats.Formats.BinaryInterchange.Model.minimumNumber
corpus: none
tests: MojoProofTest.FloatRel.maxnum_inst, MojoProofTest.FloatRel.maxnum_coupled
upstream:
depends: nan-payloads
level: L1
---

# maxnum and minnum

**The rule.** `llvm.maxnum` and `llvm.minnum` return the larger or the smaller operand; with
one quiet NaN operand they return the other. LangRef leaves the result open for a signaling
NaN operand, and under `nsz` for zeros of opposite signs.

**In Lean.** One definition for both, `MojoProof.Sem.maxnum` (by a flag), at the intrinsic on
scalars (`intrinsic_fminmax_ofFloat`) and on vectors (`intrinsic_fminmax_vec`). With no
signaling NaN operand and not two NaNs, the result is FloatLib's `Model.maximumNumber` or
`Model.minimumNumber` (`fminmax_of_not_nan`), which order `-0` below `+0` as PTX's `max` and
`min` do; a NaN result is any NaN, and `fminmax_nanEq` relates results by `NaNEq`. The
semantics refuses `nsz`, and the block checker refuses these calls.

**Reductions.** `MojoProof.Float.max_exact`: in every format, a tree of `Model.maximumNumber` of
any shape over inputs finite at its leaves is finite, its real value is one input's and it is at
least every input's, so a softmax's maximum is exact (docs/proofs/float-reductions.md). It is
about words, not a kernel, and raises no level.

**Open.** L2: no recorded GPU run. L3: no proved kernel calls them. Ref: quote to be added.
