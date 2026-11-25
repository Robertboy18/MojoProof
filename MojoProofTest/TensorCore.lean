import MojoProof.Sem.TensorCore
import MojoProof.Sem.TensorCoreAcc
import MojoProofTest.Pending
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.BFloat16

/-!
# Tensor-core fragments, `ldmatrix` and `mma` at the ISA's shapes

Tests of MojoProof/Sem/TensorCore.lean.
* `tableA8`, `tableB8`, `tableA16`, `tableB16`, `tableC`: the layouts at `m16n8k8 .tf32`
  (`fragA 2 1 2`, `fragB 1 2`), at `m16n8k16 .bf16` and `.f16` (`fragA 2 2 2`, `fragB 2 2`)
  and of the f32 accumulator (`fragC 2 1`) place every element a_i, b_i, c_i of every lane
  where the PTX ISA 9.5 tables of section 9.7.16.5.14 put it, the tables written in their own
  form (a row or column by cases on `i`), by `decide`; `tableC16`: the f16 accumulator
  (`fragC 2 2`), two to a register; `tableA64`, `tableB64`, `tableC64`: `m8n8k4 .f64`
  (`fragA 1 1 1`, `fragB 1 1`, `fragC 1 1`, section 9.7.16.5.2); `tableA4`: A of `m16n8k4`
  (`fragA 2 1 1`); `tableA16d`, `tableB16d`: `m16n8k16 .f64` (`fragA 2 1 4`, `fragB 1 4`). The
  ISA's f64 tables at `m16n8k4` and `m16n8k8` are its tf32 tables there, one element to a
  64-bit register.
* 8-bit and 4-bit inputs, four and eight to a register (sections 9.7.16.5.3-4 and
  9.7.16.5.9-11): `tableA32s8`, `tableB32s8` (`m16n8k32`, `fragA 2 4 2`, `fragB 4 2`),
  `tableA16s8`, `tableB16s8` (`m16n8k16`, `fragA 2 4 1`, `fragB 4 1`, the latter also B of
  `m8n8k16`), `tableA8s8` (A of `m8n8k16`, `fragA 1 4 1`), `tableA64s4`, `tableB64s4`
  (`m16n8k64`, `fragA 2 8 2`, `fragB 8 2`), `tableA32s4`, `tableB32s4` (`m16n8k32`,
  `fragA 2 8 1`, `fragB 8 1`, the latter also B of `m8n8k32`), `tableA8s4` (A of `m8n8k32`,
  `fragA 1 8 1`); their s32 accumulators are `tableC`'s and `tableC64`'s.
* `tableQA`, `tableQB`, `tableQC`: `m8n8k4` with f16 inputs (section 9.7.16.5.1), A row and
  column major (`quadA`), B column and row major (`quadB`), and the f16 and f32 accumulators
  (`quadC 2`, `quadC 1`), the four quad pairs' tiles stacked.
* `isa_inv`: the family theorems at these shapes, at `ldmatrix.x1`, `.x2`, `.x4`, with and
  without `.trans`, and `quad_inv` at `m8n8k4` with f16 inputs; `bijA16`: the instance of
  `Frag.bijOn` at `fragA 2 2 2`; the twin `fragC_three`: three accumulators to a register have
  no `Inv`.
* `frags_tf32`, `frags16`: `mmaFrags` of the `Mma` values the importer reads from
  `llvm.nvvm.mma.m16n8k8.row.col.tf32`, `….m16n8k16.row.col.bf16` and
  `….m16n8k16.row.col.f32.f32` (three `#guard`s) are these layouts, and `regs16` the register
  counts `(4, 2, 4)` of the last two by `mmaFrags_inv`; `frags_f64`, `regs64`: the same for
  `….m8n8k4.row.col.f64`, `(1, 1, 2)`; `frags_f64_16`: the f64 `m16n8k<k>`. The twin
  `frags_m8_f16`: `m8n8k4` with f16 inputs, which the importer reads from
  `….m8n8k4.row.col.f32.f32`, has no `mmaFrags` layouts.
* The twin `mixed_not_inv`: the `.trans` positions with the plain `ldmatrix` owners are not
  inverse (lane 1's first element is at cell `(2, 0)`, which the plain layout gives to lane 8).
* `rows16`: the instance of `ldmatrix_gather` at `ldmatrix.x4` with lane `R`'s address
  `rowsA R`. `loads16`: the instances of `ldmatrix_fragA`, `ldmatrix_fragB` and
  `ldmatrix_fragBt` at `m16n8k16`: the A tile `16 i + j` stored row major in 32-byte rows from
  address 0, at the addresses `rowsA R`, is loaded by `ldmatrix.x4` and read back by
  `(fragA 2 2 2).gather`; the B tile `8 i + j` in 16-byte rows by `ldmatrix.x2.trans` and
  `(fragB 2 2).gather`; and the B tile `i + 16 j` stored transposed in 32-byte rows, at the
  addresses `rowsBt R`, by `ldmatrix.x2` and `(fragB 2 2).gather`; `loadsB2`: the instance of
  `ldmatrix_fragB_cols`, the `16 × 16` B tile `16 i + j` loaded by `ldmatrix.x4.trans` at the
  addresses `rowsA` as two B operands.
* `exact16`: the instance of `mma_exact` at `m16n8k16`, for all real tensors.
* The two accumulation policies, each with its contract: `bf16_ok`, the instance of
  `seqAcc_ok` for bfloat16 inputs and a binary32 accumulator, the cast exact by FloatLib's
  `Model.toReal_cast_bfloat16_binary32`; `fuse16_ok`, the instance of `gridAcc_ok` at 16
  products. `ones16`: D at cell `(0, 0)` at both policies, on the tiles of ones `onesA`, `onesB`
  and zeros `zerosC` (`fill`), is 16 (its `toRat?`, by `decide +kernel`); `contract16`,
  `contractFuse`: the instances of `mma_contract` at `m16n8k16` with the two policies, every
  premise discharged. `fuse8_ok`, `contract8`: the instances of `fuseAcc_ok` at 8 products in
  blocks of 4 and of `mma_contract` with it at `m16n8k8` on `ones8`, `zerosC`. Six `#guard`s
  check `fuseRound`'s three cases in binary32 and in bfloat16.
* Two `#guard`s on one cell of `m16n8k8` with f16 inputs (`cellA`, `cellB`, C = `2^24`), whose
  products are `1`, `-2^24`, `0`, …: `gridAcc` gives 1 and `seqAcc` gives `+0`, so a statement
  about the D words holds only for the policy it is stated for.
* Two `#guard`s on `Mma.table`: `Mma.ok` and `mmaFrags` accept `m16n8k8 .bf16` and
  `m16n8k16 .f16` and refuse `m16n8k24 .bf16` and `m16n8k32 .f16`.
* `ready`: the instance of `Grid.warpReady`: in the grid `warp32` of 32 threads of a block of 32,
  each waiting at `mma.m16n8k16 .bf16` at the start of a kernel, thread 5's warp is ready; the
  twin `ready_twin`: in `warp31`, whose last thread has returned, it is not.
-/

namespace MojoProofTest.TensorCore

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats TorchLean
open FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.Pending (thread kernel)

/-- `m16n8k8 .tf32`, A (PTX ISA 9.5, section 9.7.16.5.14): `a_i` is register `i` of lane `l`,
at row `groupID` for `a0`, `a2` and `groupID + 8` for `a1`, `a3`, and column `threadID_in_group`
for `a0`, `a1` and `threadID_in_group + 4` for `a2`, `a3`. -/
theorem tableA8 : ∀ l < 32, ∀ i < 4, (fragA 2 1 2).pos l i 0 =
    (if i = 0 ∨ i = 2 then l / 4 else l / 4 + 8, if i < 2 then l % 4 else l % 4 + 4) := by
  decide

/-- `m16n8k8 .tf32`, B: `b_i` is register `i` of lane `l`, at row `threadID_in_group` for `b0`
and `threadID_in_group + 4` for `b1`, and column `groupID`. -/
theorem tableB8 : ∀ l < 32, ∀ i < 2, (fragB 1 2).pos l i 0 =
    (if i = 0 then l % 4 else l % 4 + 4, l / 4) := by
  decide

/-- `m16n8k16 .bf16` and `.f16`, A: `a_i` is element `i % 2` of register `i / 2` of lane `l`, at
row `groupID` for `i < 2` and `4 ≤ i < 6` and `groupID + 8` otherwise, and column
`threadID_in_group * 2 + (i & 1)`, plus 8 for `i ≥ 4`. -/
theorem tableA16 : ∀ l < 32, ∀ i < 8, (fragA 2 2 2).pos l (i / 2) (i % 2) =
    (if i < 2 ∨ (4 ≤ i ∧ i < 6) then l / 4 else l / 4 + 8,
      if i < 4 then l % 4 * 2 + i % 2 else l % 4 * 2 + i % 2 + 8) := by
  decide

/-- `m16n8k16 .bf16` and `.f16`, B: `b_i` is element `i % 2` of register `i / 2` of lane `l`, at
row `threadID_in_group * 2 + (i & 1)`, plus 8 for `i ≥ 2`, and column `groupID`. -/
theorem tableB16 : ∀ l < 32, ∀ i < 4, (fragB 2 2).pos l (i / 2) (i % 2) =
    (if i < 2 then l % 4 * 2 + i % 2 else l % 4 * 2 + i % 2 + 8, l / 4) := by
  decide

/-- The f32 accumulators C and D of `m16n8k<k>`, and the s32 ones of the integer shapes
(sections 9.7.16.5.9-11): `c_i` is register `i` of lane `l`, at row `groupID` for `c0`, `c1` and
`groupID + 8` for `c2`, `c3`, and column `threadID_in_group * 2 + (i & 1)`. -/
theorem tableC : ∀ l < 32, ∀ i < 4, (fragC 2 1).pos l i 0 =
    (if i < 2 then l / 4 else l / 4 + 8, l % 4 * 2 + i % 2) := by
  decide

/-- The f16 accumulators C and D of `m16n8k8` and `m16n8k16` (sections 9.7.16.5.7 and
9.7.16.5.8): `c_i` is element `i % 2` of the `.f16x2` register `i / 2` of lane `l`, at row
`groupID` for `c0`, `c1` and `groupID + 8` for `c2`, `c3`, and column
`threadID_in_group * 2 + (i & 1)`. -/
theorem tableC16 : ∀ l < 32, ∀ i < 4, (fragC 2 2).pos l (i / 2) (i % 2) =
    (if i < 2 then l / 4 else l / 4 + 8, l % 4 * 2 + i % 2) := by
  decide

/-- `m8n8k4 .f64`, A (section 9.7.16.5.2): `a0`, the one f64 register of lane `l`, is at row
`%laneid >> 2` and column `%laneid % 4`. -/
theorem tableA64 : ∀ l < 32, (fragA 1 1 1).pos l 0 0 = (l / 4, l % 4) := by
  decide

/-- `m8n8k4 .f64` and `m16n8k4 .tf32`/`.f64`, B (sections 9.7.16.5.2 and 9.7.16.5.6): `b0`, the
one register of lane `l`, is at row `%laneid % 4` and column `%laneid >> 2`. -/
theorem tableB64 : ∀ l < 32, (fragB 1 1).pos l 0 0 = (l % 4, l / 4) := by
  decide

/-- `m8n8k4 .f64`, C and D (section 9.7.16.5.2), and the s32 C and D of `m8n8k16` and `m8n8k32`
(sections 9.7.16.5.3-4): `c_i`, register `i < 2` of lane `l`, is at row `groupID` and column
`threadID_in_group * 2 + (i & 1)`. -/
theorem tableC64 : ∀ l < 32, ∀ i < 2, (fragC 1 1).pos l i 0 = (l / 4, l % 4 * 2 + i % 2) := by
  decide

/-- `m16n8k4 .tf32` and `.f64`, A (section 9.7.16.5.6): `a_i`, register `i < 2` of lane `l`, is
at row `groupID` for `a0` and `groupID + 8` for `a1`, and column `threadID_in_group`. -/
theorem tableA4 : ∀ l < 32, ∀ i < 2, (fragA 2 1 1).pos l i 0 =
    (if i = 0 then l / 4 else l / 4 + 8, l % 4) := by
  decide

/-- `m16n8k16 .f64`, A (section 9.7.16.5.8): `a_i`, f64 register `i < 8` of lane `l`, is at row
`groupID` for even `i` and `groupID + 8` otherwise, and column `i * 2 + threadID_in_group` for
even `i` and `i * 2 - 2 + threadID_in_group` otherwise. -/
theorem tableA16d : ∀ l < 32, ∀ i < 8, (fragA 2 1 4).pos l i 0 =
    (if i % 2 = 0 then l / 4 else l / 4 + 8,
      if i % 2 = 0 then i * 2 + l % 4 else i * 2 - 2 + l % 4) := by
  decide

/-- `m16n8k16 .f64`, B (section 9.7.16.5.8): `b_i`, f64 register `i < 4` of lane `l`, is at row
`threadID_in_group + i * 4` and column `groupID`. -/
theorem tableB16d : ∀ l < 32, ∀ i < 4, (fragB 1 4).pos l i 0 = (l % 4 + i * 4, l / 4) := by
  decide

/-- `m16n8k32` with 8-bit inputs (`.s8`, `.u8`, `.e4m3`, `.e5m2`), A (section 9.7.16.5.10):
`a_i` is element `i % 4` of register `i / 4` of lane `l`, at row `groupID` for `i < 4` and
`8 ≤ i < 12` and `groupID + 8` otherwise, and column `threadID_in_group * 4 + (i & 3)`, plus 16
for `i ≥ 8`. -/
theorem tableA32s8 : ∀ l < 32, ∀ i < 16, (fragA 2 4 2).pos l (i / 4) (i % 4) =
    (if i < 4 ∨ (8 ≤ i ∧ i < 12) then l / 4 else l / 4 + 8,
      if i < 8 then l % 4 * 4 + i % 4 else l % 4 * 4 + i % 4 + 16) := by
  decide

/-- `m16n8k32` with 8-bit inputs, B (section 9.7.16.5.10): `b_i` is element `i % 4` of register
`i / 4` of lane `l`, at row `threadID_in_group * 4 + (i & 3)`, plus 16 for `i ≥ 4`, and column
`groupID`. -/
theorem tableB32s8 : ∀ l < 32, ∀ i < 8, (fragB 4 2).pos l (i / 4) (i % 4) =
    (if i < 4 then l % 4 * 4 + i % 4 else l % 4 * 4 + i % 4 + 16, l / 4) := by
  decide

/-- `m16n8k16` with 8-bit integer inputs, A (section 9.7.16.5.9): `a_i` is element `i % 4` of
register `i / 4` of lane `l`, at row `groupID` for `i < 4` and `groupID + 8` otherwise, and
column `threadID_in_group * 4 + (i & 3)`. -/
theorem tableA16s8 : ∀ l < 32, ∀ i < 8, (fragA 2 4 1).pos l (i / 4) (i % 4) =
    (if i < 4 then l / 4 else l / 4 + 8, l % 4 * 4 + i % 4) := by
  decide

/-- `m16n8k16` and `m8n8k16` with 8-bit integer inputs, B (sections 9.7.16.5.9 and
9.7.16.5.3): `b_i`, element `i < 4` of the one register of lane `l`, is at row
`threadID_in_group * 4 + i` and column `groupID`. -/
theorem tableB16s8 : ∀ l < 32, ∀ i < 4, (fragB 4 1).pos l 0 i = (l % 4 * 4 + i, l / 4) := by
  decide

/-- `m8n8k16` with 8-bit integer inputs, A (section 9.7.16.5.3): `a_i`, element `i < 4` of the
one register of lane `l`, is at row `groupID` and column `threadID_in_group * 4 + i`. -/
theorem tableA8s8 : ∀ l < 32, ∀ i < 4, (fragA 1 4 1).pos l 0 i = (l / 4, l % 4 * 4 + i) := by
  decide

/-- `m16n8k64` with 4-bit integer inputs, A (section 9.7.16.5.11): `a_i` is element `i % 8` of
register `i / 8` of lane `l`, at row `groupID` for `i < 8` and `16 ≤ i < 24` and `groupID + 8`
otherwise, and column `threadID_in_group * 8 + (i & 7)`, plus 32 for `i ≥ 16`. -/
theorem tableA64s4 : ∀ l < 32, ∀ i < 32, (fragA 2 8 2).pos l (i / 8) (i % 8) =
    (if i < 8 ∨ (16 ≤ i ∧ i < 24) then l / 4 else l / 4 + 8,
      if i < 16 then l % 4 * 8 + i % 8 else l % 4 * 8 + i % 8 + 32) := by
  decide

/-- `m16n8k64` with 4-bit integer inputs, B (section 9.7.16.5.11): `b_i` is element `i % 8` of
register `i / 8` of lane `l`, at row `threadID_in_group * 8 + (i & 7)`, plus 32 for `i ≥ 8`, and
column `groupID`. -/
theorem tableB64s4 : ∀ l < 32, ∀ i < 16, (fragB 8 2).pos l (i / 8) (i % 8) =
    (if i < 8 then l % 4 * 8 + i % 8 else l % 4 * 8 + i % 8 + 32, l / 4) := by
  decide

/-- `m16n8k32` with 4-bit integer inputs, A (section 9.7.16.5.10): `a_i` is element `i % 8` of
register `i / 8` of lane `l`, at row `groupID` for `i < 8` and `groupID + 8` otherwise, and
column `threadID_in_group * 8 + (i & 7)`. -/
theorem tableA32s4 : ∀ l < 32, ∀ i < 16, (fragA 2 8 1).pos l (i / 8) (i % 8) =
    (if i < 8 then l / 4 else l / 4 + 8, l % 4 * 8 + i % 8) := by
  decide

/-- `m16n8k32` and `m8n8k32` with 4-bit integer inputs, B (sections 9.7.16.5.10 and
9.7.16.5.4): `b_i`, element `i < 8` of the one register of lane `l`, is at row
`threadID_in_group * 8 + i` and column `groupID`. -/
theorem tableB32s4 : ∀ l < 32, ∀ i < 8, (fragB 8 1).pos l 0 i = (l % 4 * 8 + i, l / 4) := by
  decide

/-- `m8n8k32` with 4-bit integer inputs, A (section 9.7.16.5.4): `a_i`, element `i < 8` of the
one register of lane `l`, is at row `groupID` and column `threadID_in_group * 8 + i`. -/
theorem tableA8s4 : ∀ l < 32, ∀ i < 8, (fragA 1 8 1).pos l 0 i = (l / 4, l % 4 * 8 + i) := by
  decide

/-- `m8n8k4` with f16 inputs, A (section 9.7.16.5.1): the warp's four products are computed by
the lanes 0-3 and 16-19, 4-7 and 20-23, 8-11 and 24-27, and 12-15 and 28-31, so lane `l`'s
product is `q = l / 4` for `l < 16` and `l / 4 - 4` otherwise, in rows `8 q` to `8 q + 7` of the
stacked tile; `a_i` is element `i % 2` of register `i / 2` of lane `l`,
row major at row `%laneid % 4` for `l < 16` and `%laneid % 4 + 4` otherwise and column `i`, and
column major at row `i % 4` for `l < 16` and `i % 4 + 4` otherwise and column `%laneid % 4`. -/
theorem tableQA : ∀ l < 32, ∀ i < 4,
    (quadA false).pos l (i / 2) (i % 2) =
        (8 * (if l < 16 then l / 4 else l / 4 - 4) + (if l < 16 then l % 4 else l % 4 + 4), i) ∧
      (quadA true).pos l (i / 2) (i % 2) =
        (8 * (if l < 16 then l / 4 else l / 4 - 4) + (if l < 16 then i % 4 else i % 4 + 4),
          l % 4) := by
  decide

/-- `m8n8k4` with f16 inputs, B (section 9.7.16.5.1), product `q` (`tableQA`) in rows `4 q` to
`4 q + 3` of the stacked tile: `b_i` is element `i % 2` of register `i / 2` of lane `l`, column
major at row `i` and column `%laneid % 4` for `l < 16` and `%laneid % 4 + 4` otherwise, and row
major at row `%laneid % 4` and column `i` for `l < 16` and `i + 4` otherwise. -/
theorem tableQB : ∀ l < 32, ∀ i < 4,
    (quadB false).pos l (i / 2) (i % 2) =
        (4 * (if l < 16 then l / 4 else l / 4 - 4) + i, if l < 16 then l % 4 else l % 4 + 4) ∧
      (quadB true).pos l (i / 2) (i % 2) =
        (4 * (if l < 16 then l / 4 else l / 4 - 4) + l % 4, if l < 16 then i else i + 4) := by
  decide

/-- `m8n8k4` with f16 inputs, C and D (section 9.7.16.5.1), product `q` (`tableQA`) in rows
`8 q` to `8 q + 7` of the stacked tile: in f16, `c_i` is element `i % 2` of the `.f16x2`
register `i / 2` of lane `l`, at row `%laneid % 4` for `l < 16` and `%laneid % 4 + 4` otherwise
and column `i`; in f32, `c_i` is register `i`, at row `X` for `l < 16` and `X + 4` otherwise,
`X = (%laneid & 1) + (i & 2)`, and column `(i & 4) + (%laneid & 2) + (i & 1)`. -/
theorem tableQC : ∀ l < 32, ∀ i < 8,
    (quadC 2).pos l (i / 2) (i % 2) =
        (8 * (if l < 16 then l / 4 else l / 4 - 4) + (if l < 16 then l % 4 else l % 4 + 4), i) ∧
      (quadC 1).pos l i 0 =
        (8 * (if l < 16 then l / 4 else l / 4 - 4) +
          (if l < 16 then (l &&& 1) + (i &&& 2) else (l &&& 1) + (i &&& 2) + 4),
          (i &&& 4) + (l &&& 2) + (i &&& 1)) := by
  decide

/-- The layouts at the ISA's shapes have `Inv`, by the family theorems: A and B of `m16n8k8
.tf32` and `m16n8k16 .bf16`/`.f16`, the f32 and f16 accumulators of `m16n8k<k>`, A, B and C/D of
`m8n8k4 .f64`, `ldmatrix.x1`, `.x2`, `.x4` with and without `.trans`, and A and B of `m8n8k4`
with f16 inputs in both majors with its f32 and f16 accumulators. -/
theorem isa_inv : (fragA 2 1 2).Inv ∧ (fragB 1 2).Inv ∧ (fragA 2 2 2).Inv ∧ (fragB 2 2).Inv ∧
    (fragC 2 1).Inv ∧ (fragC 2 2).Inv ∧ (fragA 1 1 1).Inv ∧ (fragB 1 1).Inv ∧ (fragC 1 1).Inv ∧
    (∀ q ∈ [1, 2, 4], ∀ t : Bool, (ldm q t).Inv) ∧
    (∀ t : Bool, (quadA t).Inv ∧ (quadB t).Inv) ∧ (quadC 1).Inv ∧ (quadC 2).Inv :=
  ⟨fragA_inv 2 1 2, fragB_inv 1 2, fragA_inv 2 2 2, fragB_inv 2 2, fragC_inv 2 (Or.inl rfl),
    fragC_inv 2 (Or.inr rfl), fragA_inv 1 1 1, fragB_inv 1 1, fragC_inv 1 (Or.inl rfl),
    fun q _ t => ldm_inv q t,
    fun t => ⟨(quad_inv t (Or.inl rfl)).1, (quad_inv t (Or.inl rfl)).2.1⟩,
    (quad_inv false (Or.inl rfl)).2.2, (quad_inv false (Or.inr rfl)).2.2⟩

/-- The twin of `fragC_inv`'s premise: three accumulators to a register do not fit; cell
`(8, 1)`, accumulator 3 of lane 0, would be register 1, and `fragC 2 3` has one register. -/
theorem fragC_three : ¬ (fragC 2 3).Inv := fun h =>
  absurd (h.2 8 (by decide) 1 (by decide)).2.1 (by decide)

/-- The instance of `Frag.bijOn` at the A operand of `m16n8k16 .bf16` and `.f16`: `fragA 2 2 2`
maps the 32 lanes' 4 registers of 2 elements one to one onto the `16 × 16` tile. -/
theorem bijA16 : Set.BijOn (fun x : Nat × Nat × Nat => (fragA 2 2 2).pos x.1 x.2.1 x.2.2)
    {x | x.1 < 32 ∧ x.2.1 < 4 ∧ x.2.2 < 2} {ij | ij.1 < 16 ∧ ij.2 < 16} :=
  Frag.bijOn (fragA_inv 2 2 2)

/-- `mmaFrags` of `m16n8k8 .tf32` with f32 accumulators, the importer's reading of
`llvm.nvvm.mma.m16n8k8.row.col.tf32` (checked by `#guard` below), is `fragA 2 1 2`, `fragB 1 2`,
`fragC 2 1`. -/
theorem frags_tf32 :
    mmaFrags ⟨16, 8, 8, .tf32, .float⟩ = some (fragA 2 1 2, fragB 1 2, fragC 2 1) :=
  rfl

/-- `mmaFrags` of `m16n8k16` with bfloat16 or f16 inputs and f32 accumulators, the importer's
readings of `llvm.nvvm.mma.m16n8k16.row.col.bf16` and `….row.col.f32.f32` (checked by `#guard`
below), is `fragA 2 2 2`, `fragB 2 2`, `fragC 2 1`. -/
theorem frags16 (ab : MmaTy) (hab : ab = .bf16 ∨ ab = .f16) :
    mmaFrags ⟨16, 8, 16, ab, .float⟩ = some (fragA 2 2 2, fragB 2 2, fragC 2 1) := by
  rcases hab with rfl | rfl <;> rfl

#guard Mma.ofName? "llvm.nvvm.mma.m16n8k8.row.col.tf32" = some ⟨16, 8, 8, .tf32, .float⟩
#guard Mma.ofName? "llvm.nvvm.mma.m16n8k16.row.col.bf16" = some ⟨16, 8, 16, .bf16, .float⟩
#guard Mma.ofName? "llvm.nvvm.mma.m16n8k16.row.col.f32.f32" = some ⟨16, 8, 16, .f16, .float⟩

/-- The register counts of `m16n8k16` with bfloat16 or f16 inputs and f32 accumulators are
`(4, 2, 4)`, the importer's `Mma.regs`, by `mmaFrags_inv`. -/
theorem regs16 (ab : MmaTy) (hab : ab = .bf16 ∨ ab = .f16) :
    Mma.regs ⟨16, 8, 16, ab, .float⟩ = (4, 2, 4) :=
  ((mmaFrags_inv (frags16 ab hab)).2.2.2.2.2.2.2.2.2).symm

/-- `mmaFrags` of `m8n8k4 .f64`, the importer's reading of `llvm.nvvm.mma.m8n8k4.row.col.f64`
(checked by `#guard` below), is `fragA 1 1 1`, `fragB 1 1`, `fragC 1 1`. -/
theorem frags_f64 : mmaFrags ⟨8, 8, 4, .f64, .double⟩ = some (fragA 1 1 1, fragB 1 1, fragC 1 1) :=
  rfl

/-- `mmaFrags` of `m16n8k4`, `m16n8k8` and `m16n8k16` in f64 is `fragA 2 1 (k / 4)`,
`fragB 1 (k / 4)`, `fragC 2 1`, one f64 to a register. -/
theorem frags_f64_16 (k : Nat) (hk : k = 4 ∨ k = 8 ∨ k = 16) :
    mmaFrags ⟨16, 8, k, .f64, .double⟩ = some (fragA 2 1 (k / 4), fragB 1 (k / 4), fragC 2 1) := by
  rcases hk with rfl | rfl | rfl <;> rfl

#guard Mma.ofName? "llvm.nvvm.mma.m8n8k4.row.col.f64" = some ⟨8, 8, 4, .f64, .double⟩
#guard Mma.ofName? "llvm.nvvm.mma.m8n8k4.row.col.f32.f32" = some ⟨8, 8, 4, .f16, .float⟩

/-- The register counts of `m8n8k4 .f64` are `(1, 1, 2)`, the importer's `Mma.regs`, by
`mmaFrags_inv`. -/
theorem regs64 : Mma.regs ⟨8, 8, 4, .f64, .double⟩ = (1, 1, 2) :=
  ((mmaFrags_inv frags_f64).2.2.2.2.2.2.2.2.2).symm

/-- The twin: `mmaFrags` of `m8n8k4` with f16 inputs and f32 accumulators, the importer's reading
of `llvm.nvvm.mma.m8n8k4.row.col.f32.f32`, is `none`; its layouts (section 9.7.16.5.1) are
`quadA`, `quadB` and `quadC`, not these families. -/
theorem frags_m8_f16 : mmaFrags ⟨8, 8, 4, .f16, .float⟩ = none := rfl

/-- The twin of `ldm_inv`: the `.trans` positions with the plain owners are not inverse; element
0 of register 0 of lane 1 is at cell `(2, 0)`, which the plain layout gives to lane 8. -/
theorem mixed_not_inv : ¬ { ldm 1 true with own := (ldm 1 false).own }.Inv := fun h =>
  absurd (h.1 1 (by decide) 0 (by decide) 0 (by decide)).2.2 (by decide)

/-- The row address lane `R` gives to `ldmatrix.x4` for the `16 × 16` A tile stored row major in
32-byte rows from address 0: row `R % 8 + 8 (R / 8 % 2)`, from column `8 (R / 16)`. -/
def rowsA (R : Nat) : Nat := 32 * (R % 8 + 8 * (R / 8 % 2)) + 16 * (R / 16)

/-- The row address lane `R` gives to `ldmatrix.x2` for the `16 × 8` B tile stored transposed,
row `n` of the transpose (column `n` of B) in 32 bytes from address `32 n`: row `R % 8`, from
column `8 (R / 8)`. -/
def rowsBt (R : Nat) : Nat := 32 * (R % 8) + 16 * (R / 8)

/-- The instance of `ldmatrix_gather` at `ldmatrix.x4` with the addresses `rowsA` and the
16-bit element at byte `x` numbered `x / 2`: read in the layout `ldm 4 false`, cell `(R, C)` of
the registers is element `(rowsA R + 2 C) / 2`, at every `R < 32`, `C < 8`. -/
theorem rows16 : ∀ R < 32, ∀ C < 8,
    (ldm 4 false).gather (ldmatrix 4 false rowsA (· / 2)) R C = (rowsA R + 2 * C) / 2 :=
  fun _ hR _ hC => ldmatrix_gather 4 false rowsA _ hR hC

/-- The instances of `ldmatrix_fragA`, `ldmatrix_fragB` and `ldmatrix_fragBt` at `m16n8k16`,
with the 16-bit element at byte `x` numbered `x / 2`: `ldmatrix.x4` at the addresses `rowsA`
loads the A tile `16 i + j`, read back by `(fragA 2 2 2).gather`; `ldmatrix.x2.trans` at the
addresses `16 R` loads the B tile `8 i + j`, stored row major, read back by
`(fragB 2 2).gather`; and `ldmatrix.x2` at the addresses `rowsBt` loads the B tile `i + 16 j`,
stored transposed, read back by `(fragB 2 2).gather`; at every cell of each tile. -/
theorem loads16 :
    (∀ i < 16, ∀ j < 16,
      (fragA 2 2 2).gather (ldmatrix 4 false rowsA (· / 2)) i j = 16 * i + j) ∧
    (∀ i < 16, ∀ j < 8, (fragB 2 2).gather (ldmatrix 2 true (16 * ·) (· / 2)) i j = 8 * i + j) ∧
    ∀ i < 16, ∀ j < 8, (fragB 2 2).gather (ldmatrix 2 false rowsBt (· / 2)) i j = i + 16 * j :=
  ⟨fun _ hi _ hj => ldmatrix_fragA 2 rowsA _ (fun i j => 16 * i + j)
      (fun R _ C _ => by simp only [rowsA]; omega) hi hj,
    fun _ hi _ hj => ldmatrix_fragB 2 _ _ (fun i j => 8 * i + j) (fun R _ C _ => by omega) hi hj,
    fun _ hi _ hj => ldmatrix_fragBt 2 rowsBt _ (fun i j => i + 16 * j)
      (fun R _ C _ => by simp only [rowsBt]; omega) hi hj⟩

/-- The instance of `ldmatrix_fragB_cols` at `m16n8k16`, with the 16-bit element at byte `x`
numbered `x / 2`: `ldmatrix.x4.trans` at the addresses `rowsA` loads the `16 × 16` B tile
`16 i + j`, stored row major in 32-byte rows from address 0, as two B operands: operand `o < 2`,
registers `2 o` and `2 o + 1` read back by `(fragB 2 2).gather`, is its columns `8 o` to
`8 o + 7`, at every cell `i < 16`, `j < 8`. -/
theorem loadsB2 : ∀ o < 2, ∀ i < 16, ∀ j < 8,
    (fragB 2 2).gather (fun l r s => ldmatrix 4 true rowsA (· / 2) l (2 * o + r) s) i j =
      16 * i + (j + 8 * o) :=
  fun _ ho _ hi _ hj => ldmatrix_fragB_cols 2 2 rowsA _ (fun i j => 16 * i + j)
    (fun R _ C _ => by simp only [rowsA]; omega) ho hi hj

/-- The instance of `mma_exact` at `m16n8k16`: for all real tensors `TA : [16, 16]`,
`TB : [16, 8]`, `TC : [16, 8]`, the exact D tile is TorchLean's `matmul TA TB + TC`. -/
theorem exact16 (TA : Tensor ℝ [16, 16]) (TB : Tensor ℝ [16, 8]) (TC : Tensor ℝ [16, 8])
    (i : Fin 16) (j : Fin 8) :
    (fragC 2 1).gather (mmaStep (fragA 2 2 2) (fragB 2 2) (fragC 2 1) (exactAcc (K := 16))
        ((fragA 2 2 2).scatter (tileEntry 0 TA)) ((fragB 2 2).scatter (tileEntry 0 TB))
        ((fragC 2 1).scatter (tileEntry 0 TC))) i j =
      Tensor.get2 (Tensor.matmul TA TB + TC) i j :=
  mma_exact (fragA_inv 2 2 2) (fragB_inv 2 2) (fragC_inv 2 (Or.inl rfl)) rfl rfl rfl rfl rfl rfl
    TA TB TC i j

/-- The instance of `seqAcc_ok` at 16 bfloat16 pairs and a binary32 accumulator (`m16n8k16
.bf16`): the sequential policy `seqAcc .bfloat16 .binary32` meets `AccOk (dotBound .binary32
16)`, the cast of a finite bfloat16 word to binary32 being exact (FloatLib's
`Model.toReal_cast_bfloat16_binary32`). -/
theorem bf16_ok : AccOk (dotBound .binary32 16) (seqAcc .bfloat16 .binary32 (K := 16)) :=
  seqAcc_ok FloatFormat.isIEEE_binary32 fun _ hx => Model.toReal_cast_bfloat16_binary32 hx

/-- The `m × n` tile of format `f` whose every entry is the word `w`, for every format and
size. -/
def fill {f : FloatFormat} {m n : Nat} (w : Nat) : Tensor (Model f) [m, n] :=
  Tensor.Rep.ofFn fun _ => Model.ofNatBits w

/-- The `16 × 16` bfloat16 tile of ones (word `0x3f80`). -/
def onesA : Tensor (Model .bfloat16) [16, 16] := fill 0x3f80

/-- The `16 × 8` bfloat16 tile of ones (word `0x3f80`). -/
def onesB : Tensor (Model .bfloat16) [16, 8] := fill 0x3f80

/-- The `16 × 8` binary32 tile of zeros (word `0`). -/
def zerosC : Tensor (Model .binary32) [16, 8] := fill 0

/-- The D tile of the accumulation `acc` on `onesA`, `onesB` and `zerosC` in the `m16n8k16`
layouts, the cells outside the tiles read as zero words. -/
def dOnes (acc : (Fin 16 → Model .bfloat16) → (Fin 16 → Model .bfloat16) → Model .binary32 →
    Model .binary32) : Nat → Nat → Model .binary32 :=
  (fragC 2 1).gather (mmaStep (fragA 2 2 2) (fragB 2 2) (fragC 2 1) acc
    ((fragA 2 2 2).scatter (tileEntry (Model.ofNatBits 0) onesA))
    ((fragB 2 2).scatter (tileEntry (Model.ofNatBits 0) onesB))
    ((fragC 2 1).scatter (tileEntry (Model.ofNatBits 0) zerosC)))

/-- D at cell `(0, 0)` of `dOnes` at the two policies, `seqAcc .bfloat16 .binary32` and
`gridAcc .bfloat16 .binary32`, is 16, by evaluation. -/
theorem ones16 : (dOnes (seqAcc .bfloat16 .binary32) 0 0).toRat? = some 16 ∧
    (dOnes (gridAcc .bfloat16 .binary32) 0 0).toRat? = some 16 := by
  decide +kernel

/-- The instance of `mma_contract` at `m16n8k16 .bf16` with the policy `seqAcc .bfloat16
.binary32` (`bf16_ok`), every premise discharged: D at cell `(0, 0)` of `dOnes` is within
`dotBound .binary32 16` of TorchLean's real `matmul A B + C` there. -/
theorem contract16 :
    |(dOnes (seqAcc .bfloat16 .binary32) 0 0).toReal - Tensor.get2 (Tensor.matmul
        (Tensor.map Model.toReal onesA) (Tensor.map Model.toReal onesB) +
          Tensor.map Model.toReal zerosC) 0 0| ≤
      dotBound .binary32 16
        (∑ k, |(Tensor.get2 onesA 0 k).toReal * (Tensor.get2 onesB k 0).toReal| +
          |(Tensor.get2 zerosC 0 0).toReal|) :=
  mma_contract (m := 16) (n := 8) (K := 16) (fragA_inv 2 2 2) (fragB_inv 2 2)
    (fragC_inv 2 (Or.inl rfl)) rfl rfl rfl rfl rfl rfl bf16_ok onesA onesB zerosC
    (Model.ofNatBits 0) (Model.ofNatBits 0) (Model.ofNatBits 0) 0 0 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- The instance of `gridAcc_ok` at `m16n8k16 .bf16` with an f32 accumulator, 16 products in
two blocks of 8 with 24 bits (the accumulation tests/gpu/mma/record.txt measures): the policy
`gridAcc .bfloat16 .binary32` meets `AccBy` with the bound `fuseBound .binary32 8 24 2`. -/
theorem fuse16_ok : AccBy (K := 16) (fun x y : Model .bfloat16 => wt x * wt y)
    (fun c : Model .binary32 => |c.toReal| + 2 ^ FloatFormat.binary32.minNormalExponent)
    (fuseBound .binary32 8 24 2) (gridAcc .bfloat16 .binary32) :=
  gridAcc_ok FloatFormat.isIEEE_binary32

/-- The instance of `fuseAcc_ok` at 8 binary32 products in two blocks of 4 with 24 bits, a
second size and input format: `fuseAcc .binary32 .binary32 4 24` meets `AccBy` with the bound
`fuseBound .binary32 4 24 2`. -/
theorem fuse8_ok : AccBy (K := 8) (fun x y : Model .binary32 => wt x * wt y)
    (fun c : Model .binary32 => |c.toReal| + 2 ^ FloatFormat.binary32.minNormalExponent)
    (fuseBound .binary32 4 24 2) (fuseAcc .binary32 .binary32 4 24) :=
  fuseAcc_ok FloatFormat.isIEEE_binary32 (by norm_num) 24

/-- The instance of `mma_contract` at `m16n8k16 .bf16` with the policy `gridAcc .bfloat16
.binary32` (`fuse16_ok`), every premise discharged: D at cell `(0, 0)` of its `mma` on `onesA`,
`onesB` and `zerosC` is within `fuseBound .binary32 8 24 2` of TorchLean's real
`matmul A B + C` there. -/
theorem contractFuse :
    |(dOnes (gridAcc .bfloat16 .binary32) 0 0).toReal - Tensor.get2 (Tensor.matmul
        (Tensor.map Model.toReal onesA) (Tensor.map Model.toReal onesB) +
          Tensor.map Model.toReal zerosC) 0 0| ≤
      fuseBound .binary32 8 24 2
        (∑ k, wt (Tensor.get2 onesA 0 k) * wt (Tensor.get2 onesB k 0) +
          (|(Tensor.get2 zerosC 0 0).toReal| + 2 ^ FloatFormat.binary32.minNormalExponent)) :=
  mma_contract (m := 16) (n := 8) (K := 16) (fragA_inv 2 2 2) (fragB_inv 2 2)
    (fragC_inv 2 (Or.inl rfl)) rfl rfl rfl rfl rfl rfl fuse16_ok onesA onesB zerosC
    (Model.ofNatBits 0) (Model.ofNatBits 0) (Model.ofNatBits 0) 0 0 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- The `16 × 8` and `8 × 8` binary32 tiles of ones (word `0x3f800000`), A and B of the
`m16n8k8` layouts. -/
def ones8 : Tensor (Model .binary32) [16, 8] × Tensor (Model .binary32) [8, 8] :=
  (fill 0x3f800000, fill 0x3f800000)

/-- The instance of `mma_contract` at a second size, `m16n8k8` in the tf32 layouts
(`fragA 2 1 2`, `fragB 1 2`, `fragC 2 1`) with binary32 words and `fuseAcc .binary32 .binary32
4 24` (`fuse8_ok`), every premise discharged: D at cell `(0, 0)` on `ones8` and `zerosC` is
within `fuseBound .binary32 4 24 2` of TorchLean's real `matmul A B + C` there. -/
theorem contract8 :
    |((fragC 2 1).gather (mmaStep (fragA 2 1 2) (fragB 1 2) (fragC 2 1)
        (fuseAcc (K := 8) .binary32 .binary32 4 24)
        ((fragA 2 1 2).scatter (tileEntry (Model.ofNatBits 0) ones8.1))
        ((fragB 1 2).scatter (tileEntry (Model.ofNatBits 0) ones8.2))
        ((fragC 2 1).scatter (tileEntry (Model.ofNatBits 0) zerosC))) 0 0).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal ones8.1)
          (Tensor.map Model.toReal ones8.2) + Tensor.map Model.toReal zerosC) 0 0| ≤
      fuseBound .binary32 4 24 2
        (∑ k, wt (Tensor.get2 ones8.1 0 k) * wt (Tensor.get2 ones8.2 k 0) +
          (|(Tensor.get2 zerosC 0 0).toReal| + 2 ^ FloatFormat.binary32.minNormalExponent)) :=
  mma_contract (m := 16) (n := 8) (K := 8) (fragA_inv 2 1 2) (fragB_inv 1 2)
    (fragC_inv 2 (Or.inl rfl)) rfl rfl rfl rfl rfl rfl fuse8_ok ones8.1 ones8.2 zerosC
    (Model.ofNatBits 0) (Model.ofNatBits 0) (Model.ofNatBits 0) 0 0 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (by decide +kernel)

-- `fuseRound` in its three cases, in binary32 and in bfloat16: toward zero up to the largest
-- finite magnitude `M` (`M - 2^103` gives `M - 2^104` in binary32), `M` with the sum's sign
-- beyond it and below `2^128`, and the infinity of the sum's sign from `2^128` on.
#guard (fuseRound .binary32 (2 ^ 128 - 2 ^ 104 - 2 ^ 103)).toNatBits == 0x7F7FFFFE
#guard (fuseRound .binary32 (2 ^ 128 - 2 ^ 104 + 2 ^ 103)).toNatBits == 0x7F7FFFFF
#guard (fuseRound .binary32 (-(2 ^ 128 - 2 ^ 104 + 2 ^ 103))).toNatBits == 0xFF7FFFFF
#guard (fuseRound .binary32 (2 ^ 128)).toNatBits == 0x7F800000
#guard (fuseRound .bfloat16 (2 ^ 128 - 2 ^ 120 + 2 ^ 119)).toNatBits == 0x7F7F
#guard (fuseRound .bfloat16 (-(2 ^ 128))).toNatBits == 0xFF80

/-- A row of A of `m16n8k8` with f16 inputs whose two policies differ: `1`, `-4096` (words
`0x3C00`, `0xEC00`), then zeros. -/
def cellA (k : Fin 8) : Model .binary16 :=
  Model.ofNatBits (if k.val = 0 then 0x3C00 else if k.val = 1 then 0xEC00 else 0)

/-- A column of B of `m16n8k8` with f16 inputs: `1`, `4096` (words `0x3C00`, `0x6C00`), then
zeros. -/
def cellB (k : Fin 8) : Model .binary16 :=
  Model.ofNatBits (if k.val = 0 then 0x3C00 else if k.val = 1 then 0x6C00 else 0)

-- the products `1`, `-2^24`, `0`, … from C = `2^24` (`0x4B800000`): the measured policy sums
-- them in one block exactly, giving 1; the sequential one rounds `2^24 + 1` to even, `2^24`,
-- giving `+0`
#guard (gridAcc .binary16 .binary32 cellA cellB (Model.ofNatBits 0x4B800000)).toNatBits ==
  0x3F800000
#guard (seqAcc .binary16 .binary32 cellA cellB (Model.ofNatBits 0x4B800000)).toNatBits == 0

-- the one table `Mma.ok` and `mmaFrags` read: two listed shapes in, two others out
#guard Mma.ok ⟨16, 8, 8, .bf16, .float⟩ && Mma.ok ⟨16, 8, 16, .f16, .float⟩ &&
  (mmaFrags ⟨16, 8, 8, .bf16, .float⟩).isSome && (mmaFrags ⟨16, 8, 16, .f16, .float⟩).isSome
#guard !Mma.ok ⟨16, 8, 24, .bf16, .float⟩ && !Mma.ok ⟨16, 8, 32, .f16, .float⟩ &&
  (mmaFrags ⟨16, 8, 24, .bf16, .float⟩).isNone && (mmaFrags ⟨16, 8, 32, .f16, .float⟩).isNone

/-- The `mma` value of `m16n8k16 .bf16` with an f32 accumulator. -/
def mma16 : Intrinsic := .mma ⟨16, 8, 16, .bf16, .float⟩

/-- A thread at the start of the one-block kernel waiting at `mma16`, with no arguments. -/
def atMma : Status := .wait (thread #[]) mma16 [] (kernel #[])

/-- Thirty-two threads, each at `atMma`, on the empty memory. -/
def warp32 : Grid := { threads := Array.replicate 32 atMma, mem := {} }

/-- Thirty-one threads at `atMma`, then a thread that has returned, on the empty memory. -/
def warp31 : Grid := { threads := (Array.replicate 31 atMma).push .done, mem := {} }

/-- The instance of `Grid.warpReady`: in blocks of 32 threads, thread 5's warp of `warp32` waits
whole at `mma16`, at one instruction. -/
theorem ready : warp32.warpReady 32 5 mma16 :=
  ⟨by decide, (thread #[]).at, fun j hj =>
    ⟨thread #[], [], kernel #[], by simp [warp32, atMma, hj], rfl⟩⟩

/-- The twin: in `warp31`, lane 31 has returned, so thread 5's warp is not ready. -/
theorem ready_twin : ¬ warp31.warpReady 32 5 mma16 := by
  rintro ⟨-, _, h⟩
  obtain ⟨_, _, _, h1, -⟩ := h 31 (by decide)
  simp [warp31, Array.getElem_push] at h1

end MojoProofTest.TensorCore
