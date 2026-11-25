---
id: mma
title: mma, a warp's tensor-core multiply-accumulate
kind: construct
ref: PTX ISA 9.5 #9.7.16.5.14
quote: ""
lean: MojoProof.Sem.Frag, MojoProof.Sem.Frag.bijOn, MojoProof.Sem.fragA_inv, MojoProof.Sem.fragB_inv, MojoProof.Sem.fragC_inv, MojoProof.Sem.quadA, MojoProof.Sem.quadB, MojoProof.Sem.quadC, MojoProof.Sem.quad_inv, MojoProof.Sem.mmaFrags, MojoProof.Sem.mmaFrags_inv, MojoProof.Sem.mmaStep, MojoProof.Sem.mmaStep_gather, MojoProof.Sem.mma_exact, MojoProof.Sem.AccBy, MojoProof.Sem.AccOk, MojoProof.Sem.mma_contract, MojoProof.Sem.castDot_ok, MojoProof.Sem.fuseAcc, MojoProof.Sem.fuseSum_err, MojoProof.Sem.fuseRound_err, MojoProof.Sem.fuseStep_err, MojoProof.Sem.fuseFold_err, MojoProof.Sem.fuseAcc_ok, MojoProof.Sem.Grid.warpReady, MojoProof.Sem.RegForm.get_put, MojoProof.Sem.RegForm.put_elem, MojoProof.Sem.mmaWarp, MojoProof.Sem.mmaWarp_spec, MojoProof.LLVM.Mma.table, MojoProof.Sem.MmaAcc, MojoProof.Sem.gridAcc, MojoProof.Sem.gridAcc_ok, MojoProof.Sem.seqAcc, MojoProof.Sem.seqAcc_ok, MojoProof.Sem.mmaGrid, MojoProof.Sem.Grid.fire_mma
corpus: none
tests: MojoProofTest.TensorCore.tableA8, MojoProofTest.TensorCore.tableA16, MojoProofTest.TensorCore.tableC, MojoProofTest.TensorCore.tableC16, MojoProofTest.TensorCore.tableA64, MojoProofTest.TensorCore.tableC64, MojoProofTest.TensorCore.tableA32s8, MojoProofTest.TensorCore.tableA64s4, MojoProofTest.TensorCore.tableQA, MojoProofTest.TensorCore.tableQC, MojoProofTest.TensorCore.regs16, MojoProofTest.TensorCore.regs64, MojoProofTest.TensorCore.frags_m8_f16, MojoProofTest.TensorCore.exact16, MojoProofTest.TensorCore.bf16_ok, MojoProofTest.TensorCore.contract16, MojoProofTest.TensorCore.fuse16_ok, MojoProofTest.TensorCore.fuse8_ok, MojoProofTest.TensorCore.contractFuse, MojoProofTest.TensorCore.contract8, MojoProofTest.TensorCore.ready_twin, MojoProofTest.TensorCoreGpu.dotBoundQ_eq, MojoProofTest.TensorCoreWarp.bf16Warp, MojoProofTest.TensorCoreWarp.tf32Warp, MojoProofTest.TensorCoreGrid.f16Grid, MojoProofTest.TensorCoreGrid.bf16k8Grid
upstream:
depends: launch
level: L1
---

# mma

**The rule.** `llvm.nvvm.mma.m<m>n<n>k<k>.row.col.<types>` multiplies an `m × k` and a
`k × n` tile, held in fragments across the warp's lanes, and adds an `m × n` accumulator. Every
lane of the warp executes it (`.sync.aligned`); the order, rounding and subnormal handling of
the accumulation are unspecified.

**In Lean.** The fragment layouts of the shapes of `MojoProof.LLVM.Mma.table`, the one list the
importer (`Mma.ok`) and the layouts (`MojoProof.Sem.mmaFrags`) read: `m16n8k8` and `m16n8k16`
with f16 or bf16 inputs and f32 accumulators, `m16n8k4` and `m16n8k8` with tf32, and `m8n8k4`,
`m16n8k4`, `m16n8k8` and `m16n8k16` in f64; their formulas are general in the shape. They are
bijections between the lanes' registers and the tiles,
one theorem per family (`MojoProof.Sem.fragA_inv`, `fragB_inv`, `fragC_inv`, the last also for f16
accumulators, two to a register), checked against the ISA's tables at those shapes by `decide` in
the tests (sections 9.7.16.5.2 and 9.7.16.5.6-8). The same families at four and eight elements
to a register are the ISA's layouts of 8-bit and 4-bit inputs, checked likewise (sections
9.7.16.5.3-4 and 9.7.16.5.9-11). `m8n8k4` with f16 inputs is four products at once, one to each
quad pair of lanes; its layouts, the four tiles stacked, are `MojoProof.Sem.quadA`, `quadB` and
`quadC`, bijections by `MojoProof.Sem.quad_inv` and checked against section 9.7.16.5.1.
`MojoProof.Sem.mmaStep` is the warp-collective step with the accumulation as a parameter: with
the exact sum over the reals it is TorchLean's
`matmul A B + C` on the tile (`MojoProof.Sem.mma_exact`), and under a contract with a stated error
(`MojoProof.Sem.AccBy`, with `MojoProof.Sem.AccOk` its case of the absolute products) each
finite output is within it of that value (`MojoProof.Sem.mma_contract`), which covers a GPU only
if the GPU's accumulation meets the premise. `MojoProof.Sem.castDot_ok` is a FloatLib
accumulator meeting `AccOk`. `MojoProof.Sem.fuseAcc` is a fused block accumulation over
FloatLib's values (blocks of `n` products, each addend truncated to `p` bits below the largest
one's leading power, the sum rounded toward zero with FloatLib's `roundRat`, the largest finite
magnitude below `2^(emax + 1)` and an infinity from there on), and
`MojoProof.Sem.fuseAcc_ok` proves, for every input format, IEEE accumulator format, `n ≥ 1`,
`p` and `K`, the bound it meets. As the ISA leaves the accumulation open, the semantics takes it
as a policy (`MojoProof.Sem.MmaAcc`), one per launch: `MojoProof.Sem.gridAcc`, `fuseAcc` at
`n = 8`, `p = 24` and the default, meets its contract by `MojoProof.Sem.gridAcc_ok`;
`MojoProof.Sem.seqAcc`, the cast-then-`dotLoop` fold rounding to nearest, meets `AccOk` by
`MojoProof.Sem.seqAcc_ok`; on one f16 cell they give 1 and `+0`. That the hardware is a policy
and meets a contract is a trust item; an A100 does not meet `seqAcc`'s bound, and its words are
`gridAcc`'s on every recorded launch (below). `MojoProof.Sem.Grid.warpReady` states the
all-lanes obligation. On run-time values, `MojoProof.Sem.mmaWarp` decodes the 32 lanes' `Val`
registers in the forms of the intrinsic's signature (`MojoProof.Sem.RegForm`, with
`MojoProof.Sem.RegForm.get_put` and `MojoProof.Sem.RegForm.put_elem` the round trips), runs
`mmaStep` and encodes each lane's D registers; for every `mma` that `mmaFrags` accepts and every
accumulation, its results on registers that hold tiles are the accumulation on the tiles
(`MojoProof.Sem.mmaWarp_spec`). All for every layout and accumulation as stated. The grid runs
`mma` with bf16 and f16 inputs and an f32 accumulator: at a warp whose 32 lanes wait at it,
`MojoProof.Sem.mmaGrid` is `mmaWarp` with the launch's policy on finite words, and for every
launch (so every policy), warp and `mma` of the table with those types, on lanes whose
registers hold tiles of finite words and whose callees have no `range`, `nonnull` or `align`
return attribute, the step succeeds and the lanes run on with the policy's D words
(`MojoProof.Sem.Grid.fire_mma`); that a GPU's accumulation is the launch's policy is trusted
(docs/TRUST.md T14). Other types (tf32, f64) are unsupported in the grid.

**On a GPU.** tests/gpu/mma/record.txt records one warp's `m16n8k16 .bf16` with f32
accumulators on an A100, 20 launches (random inputs of nine kinds, among them cancelling pairs,
wide exponent spreads, subnormal products and sums near overflow, an alignment probe and an
overflow-threshold probe), compared by MojoProofTest/TensorCoreGpu.lean with `mmaStep` at the
library's layouts. All 2,560 outputs are bit for bit `gridAcc .bfloat16 .binary32`'s. On
integer inputs, where the order of the additions does not matter, all 256 outputs are also
`seqAcc .bfloat16 .binary32`'s words, so the layouts are the hardware's at this shape. Of the
2,025 other finite outputs, one is outside `dotBound .binary32 16` (18.9 u T against about 17 u T): the A100's
accumulation does not meet `AccOk (dotBound .binary32 16)`, the bound `castDot_ok` proves of a
rounded fold.

**Out of scope.** The products of `m8n8k4` with f16 inputs and of 8-bit and 4-bit inputs (their
layouts are checked, but no step computes them, and the importer reads no integer `mma`), sparse
`mma.sp`, and `.b1` inputs. f16 accumulators have a checked layout, but the importer reads no
such `mma`. No GPU record of `m8n8k4` with f16 inputs or of an 8-bit `mma`: the library's `mma`
at `m8n8k4` does not compile for sm_80 (its intrinsic call expects two results where the
intrinsic returns eight), and its only 8-bit `mma`, fp8 in inline PTX, needs sm_89.

**Open.** The grid's `mma` on tf32 and f64 inputs. That the A100 computes `gridAcc` on
other inputs, shapes and types is not tested. L2: the recorded GPU run agrees with `fuseAcc` word
for word, but it ran a driver of the instruction, not a corpus kernel, and the level counts only
records of corpus kernels. L3: no proved kernel uses it. Ref: the section is the one docs/TRUST.md
cites; quote to be added.
