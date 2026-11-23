---
id: mma
title: mma, a warp's tensor-core multiply-accumulate
kind: construct
ref: PTX ISA 9.5 #9.7.16.5.14
quote: ""
lean: MojoProof.Sem.Frag, MojoProof.Sem.Frag.bijOn, MojoProof.Sem.fragA_inv, MojoProof.Sem.fragB_inv, MojoProof.Sem.fragC_inv, MojoProof.Sem.mmaPack, MojoProof.Sem.mmaFrags, MojoProof.Sem.mmaFrags_inv, MojoProof.Sem.mmaStep, MojoProof.Sem.mmaStep_gather, MojoProof.Sem.mma_exact, MojoProof.Sem.AccOk, MojoProof.Sem.mma_contract, MojoProof.Sem.castDot_ok, MojoProof.Sem.Grid.warpReady
corpus: none
tests: MojoProofTest.TensorCore.tableA8, MojoProofTest.TensorCore.tableA16, MojoProofTest.TensorCore.tableC, MojoProofTest.TensorCore.tableC16, MojoProofTest.TensorCore.tableA64, MojoProofTest.TensorCore.tableC64, MojoProofTest.TensorCore.regs16, MojoProofTest.TensorCore.regs64, MojoProofTest.TensorCore.frags_m8_f16, MojoProofTest.TensorCore.exact16, MojoProofTest.TensorCore.contract16, MojoProofTest.TensorCore.ready_twin
upstream:
depends: launch
level: L1
---

# mma

**The rule.** `llvm.nvvm.mma.m<m>n<n>k<k>.row.col.<types>` multiplies an `m × k` and a
`k × n` tile, held in fragments across the warp's lanes, and adds an `m × n` accumulator. Every
lane of the warp executes it (`.sync.aligned`); the order, rounding and subnormal handling of
the accumulation are unspecified.

**In Lean.** The fragment layouts of `m16n8k<k>` with tf32, bf16 or f16 inputs and f32
accumulators or in f64, and of `m8n8k4 .f64` (`MojoProof.Sem.mmaFrags`, with `m16n8k8 .tf32` and
`m16n8k16 .bf16`/`.f16` among them), are bijections between the lanes' registers and the tiles,
one theorem per family (`MojoProof.Sem.fragA_inv`, `fragB_inv`, `fragC_inv`, the last also for f16
accumulators, two to a register), checked against the ISA's tables at those shapes by `decide` in
the tests (sections 9.7.16.5.2 and 9.7.16.5.6-8). `MojoProof.Sem.mmaStep` is the warp-collective
step with the accumulation as a parameter: with the exact sum over the reals it is TorchLean's
`matmul A B + C` on the tile (`MojoProof.Sem.mma_exact`), and under a contract with a stated error
(`MojoProof.Sem.AccOk`) each finite output is within it of that value
(`MojoProof.Sem.mma_contract`); `MojoProof.Sem.castDot_ok` is a FloatLib accumulator meeting the
contract. That the hardware meets it is a trust item. `MojoProof.Sem.Grid.warpReady` states the
all-lanes obligation. All for every layout and accumulation as stated; the grid does not dispatch
`mma` to the step yet (a run reaching it is unsupported).

**Out of scope.** `m8n8k4` with f16 inputs (its layouts are not these families), sparse
`mma.sp`, and 8-bit and 4-bit inputs. f16 accumulators have a checked layout, but the importer
reads no such `mma`.

**Open.** The grid's dispatch to `mmaStep` under `warpReady`. L2: no recorded GPU run. L3: no
proved kernel uses it. Ref: the section is the one docs/TRUST.md cites; quote to be added.
