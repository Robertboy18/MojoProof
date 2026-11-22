# Floats

## Scope

The floating-point rules of the semantics: the rounding of the binary operations, the
`deliver` of a result and the NaNs it may be, the `contract` flag's fused multiply-add,
`llvm.maxnum` and `llvm.minnum`, and `rsqrt.approx`. Each card links the rule to the
semantics' declarations and to FloatLib's, by full name (FloatLib's names are checked against
its sources under .lake/packages). Construct cards climb the construct ladder of
roadmap/README.md.

Reference: LLVM 24.0.0git's LangRef and the PTX ISA version 9.5, the versions docs/TRUST.md
records. No copy of them is in the repository, so every quote is empty and each card says
"quote to be added".

## Cards

- [binary-op-rounding](cards/binary-op-rounding.md): `fadd`, `fsub`, `fmul`, `fdiv` round to
  nearest even (FloatLib's `Model.add` and the others, `Model.roundAt`).
- [deliver](cards/deliver.md): a result's word, with a NaN's bits from the oracle.
- [nan-payloads](cards/nan-payloads.md): any NaN, and `NaNEq` for what does not depend on which.
- [contract](cards/contract.md): `contract` lets an `fmul` and an `fadd` fuse (`Model.fma`).
- [maxnum-minnum](cards/maxnum-minnum.md): `maximumNumber` and `minimumNumber`, any NaN for
  a signaling NaN operand.
- [rsqrt-approx](cards/rsqrt-approx.md): every word within PTX's documented relative error.

## Open

No GPU run is recorded, so no rule is past L1. The rounding, `deliver` and the NaN rule are
used by the proved kernels vadd and vmul (L3 evidence); `contract`, `maxnum` and `rsqrt.approx`
wait for a proved kernel that uses them (the naive matmul, softmax, layer norm).
