import MojoProof.Sem.Matmul
import MojoProof.Sem.Grid
import MojoProof.Sem.TensorCoreDef
import TorchLean.Tensor.Arithmetic

/-!
# Tensor-core fragments, `ldmatrix` and `mma` (docs/proofs/tensor-core.md)

The PTX ISA, version 9.5, places the tiles of a warp's `mma` and `ldmatrix` in the lanes'
registers by fixed formulas (section 9.7.16.5.14, the tables "Matrix Fragments for
mma.m…n8k…" of sections 9.7.16.5.1-2 and 9.7.16.5.6-8, and section 9.7.16.5.15, `ldmatrix`).
With `g = l / 4` and `t = l % 4` for lane `l` (the ISA's groupID and threadID_in_group), and
`p` elements per register:
* A (`m<8h>n8k<4pc>`, row major): element `s` of register `r` is cell
  `(g + 8 (r % h), s + p (t + 4 (r / h)))`, for `r < hc` (`fragA h p c`);
* B (column major): cell `(s + p (t + 4 r), g)`, for `r < c` (`fragB p c`);
* C and D (`m<8h>n8`): element `i = p r + s` is cell `(g + 8 (i / 2), 2 t + i % 2)`, for
  `i < 2h` (`fragC h p`);
* `ldmatrix.x<q>` of `q` stacked 8 × 8 matrices of 16-bit elements: cell `(8 r + g, 2 t + s)`,
  and with `.trans` cell `(8 r + 2 t + s, g)`, for `r < q` (`ldm q t`);
* `m8n8k4` with f16 inputs (section 9.7.16.5.1), four products at once, the `q`-th by the quad
  pair of lanes `l % 16 / 4 = q`: A, B and C/D are `quadA t`, `quadB t` and `quadC p`, the four
  tiles stacked.
`m16n8k8 .tf32` is `h = 2`, `p = 1`, `c = 2`; `m16n8k16 .bf16` and `.f16` are `h = 2`, `p = 2`,
`c = 2`; `m16n8k<4c> .f64` is `h = 2`, `p = 1` (one f64 per 64-bit register), and
`m8n8k4 .f64` is `h = 1`, `p = 1`, `c = 1`. The accumulators are `p = 1` in f32, f64 and s32
and `p = 2` in f16 (two to an `.f16x2` register). The 8-bit and 4-bit inputs of `m16n8k<k>` and
`m8n8k<k>` (sections 9.7.16.5.3-4 and 9.7.16.5.9-11) are `p = 4` and `p = 8`; the importer
reads no such `mma`.

Definitions (`Frag`, `Frag.scatter`, `Frag.gather`, `fragA`, `fragB`, `fragC`, `mmaFrags` and
`mmaStep` are in `MojoProof.Sem.TensorCoreDef`, below the grid, which runs them):
* `Frag`: a layout, with `pos` (lane, register, element ↦ cell) and its inverse `own`;
  `Frag.Inv`: the two are inverse on the 32 lanes' registers and on the tile; `Frag.scatter` and
  `Frag.gather`: a tile into the registers and back.
* `mmaFrags v`: the three layouts of the importer's `Mma` value `v`, for every value of
  `Mma.table` (the shapes the ISA lists for tf32, bf16 and f16 inputs with an f32 accumulator
  and for f64, `m8n8k4` with f16 inputs excepted), `none` otherwise.
* `ldmatrix q t a rd`: the registers `ldmatrix.x<q>` loads, with lane `R`'s row address `a R`
  and the memory's 16-bit elements `rd`.
* `mmaStep FA FB FC acc a b c`: the D registers of every lane, with the accumulation `acc` a
  parameter; `exactAcc`, the exact sum over `ℝ`; `AccBy mag magC bnd acc`, a contract with
  magnitudes `mag`, `magC` and error `bnd`, and `AccOk bnd acc`, the one at absolute values;
  `tileEntry d T`, a rank-2 tensor as a function of two numbers; `seqAcc`, the sequential
  round-to-nearest accumulation policy (`MmaAcc`), the second policy beside `gridAcc`.
* `Grid.warpReady g size n i`: the obligation of a warp-collective step.

Proved: `Frag.bijOn` (an `Inv` layout's `pos` is a bijection, every layout);
`Frag.gather_of_scatter` (registers that hold a tile read back as it, every layout); `fragA_inv`
(every `h`, `p` and `c`), `fragB_inv` (every `p` and `c`), `fragC_inv` (every `h`, and `p` 1 or
2), `ldm_inv` (every `q` and flag), `quad_inv` (both flags, and `p` 1 or 2);
`mmaFrags_inv` (every `Mma` of the table); `ldmatrix_gather`, `ldmatrix_fragA`,
`ldmatrix_fragB_cols` (with `.trans`, B operands side by side), `ldmatrix_fragB`,
`ldmatrix_fragBt` (the loads, every count, read in the layouts as `mmaStep` reads its
operands); `mmaStep_gather` (every set of layouts and
accumulation); `mma_exact` (the exact model is TorchLean's `matmul A B + C`); `mma_contract`
(under `AccBy`, the error against TorchLean's real `matmul A B + C`); `castDot_ok` (a
cast-then-`dotLoop` accumulator meets `AccOk` with `dotBound`) and its case `seqAcc_ok`. The
ISA leaves the accumulation's order, rounding and handling of subnormal inputs unspecified, so
the grid runs a policy (`MmaAcc`, `Launch.acc`) and its statements hold for every policy; which
policy, and which contract, a GPU meets is a trust item. `MojoProof.Sem.TensorCoreAcc` proves
the bound the measured policy `gridAcc` meets (`gridAcc_ok`).
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange TorchLean LLVM

namespace Frag

/-- `pos` and `own` are inverse: every lane `l < 32`, register `r < regs` and element
`s < pack` is placed inside the tile and `own` maps its cell back to it; every cell `i < rows`,
`j < cols` is owned by a lane, register and element in range that `pos` maps back to the cell. -/
def Inv (F : Frag) : Prop :=
  (∀ l < 32, ∀ r < F.regs, ∀ s < F.pack, (F.pos l r s).1 < F.rows ∧ (F.pos l r s).2 < F.cols ∧
      F.own (F.pos l r s).1 (F.pos l r s).2 = (l, r, s)) ∧
    ∀ i < F.rows, ∀ j < F.cols, (F.own i j).1 < 32 ∧ (F.own i j).2.1 < F.regs ∧
      (F.own i j).2.2 < F.pack ∧ F.pos (F.own i j).1 (F.own i j).2.1 (F.own i j).2.2 = (i, j)

/-- **A layout with `Inv` is a bijection**, for every layout: `pos` maps the lanes' registers
`{(l, r, s) | l < 32, r < regs, s < pack}` one to one onto the tile's cells
`{(i, j) | i < rows, j < cols}` (Mathlib's `Set.BijOn`), with inverse `own`. -/
theorem bijOn {F : Frag} (h : F.Inv) :
    Set.BijOn (fun x : Nat × Nat × Nat => F.pos x.1 x.2.1 x.2.2)
      {x | x.1 < 32 ∧ x.2.1 < F.regs ∧ x.2.2 < F.pack} {ij | ij.1 < F.rows ∧ ij.2 < F.cols} := by
  refine Set.InvOn.bijOn (f' := fun ij => F.own ij.1 ij.2) ⟨?_, ?_⟩ ?_ ?_
  · rintro ⟨l, r, s⟩ ⟨hl, hr, hs⟩
    exact (h.1 l hl r hr s hs).2.2
  · rintro ⟨i, j⟩ ⟨hi, hj⟩
    exact (h.2 i hi j hj).2.2.2
  · rintro ⟨l, r, s⟩ ⟨hl, hr, hs⟩
    exact ⟨(h.1 l hl r hr s hs).1, (h.1 l hl r hr s hs).2.1⟩
  · rintro ⟨i, j⟩ ⟨hi, hj⟩
    exact ⟨(h.2 i hi j hj).1, (h.2 i hi j hj).2.1, (h.2 i hi j hj).2.2.1⟩

/-- **Registers that hold a tile read back as the tile**, for every layout `F` with `Inv`,
registers `x` and tile `T` of any type: if `x l r s = F.scatter T l r s` at every lane `l < 32`,
register `r < F.regs` and element `s < F.pack`, then `F.gather x i j = T i j` at every cell
`i < F.rows`, `j < F.cols`. -/
theorem gather_of_scatter {α : Type} {F : Frag} (h : F.Inv) {x : Nat → Nat → Nat → α}
    {T : Nat → Nat → α} (hx : ∀ l < 32, ∀ r < F.regs, ∀ s < F.pack, x l r s = F.scatter T l r s)
    {i j : Nat} (hi : i < F.rows) (hj : j < F.cols) : F.gather x i j = T i j := by
  have ho := h.2 i hi j hj
  unfold gather
  rw [hx _ ho.1 _ ho.2.1 _ ho.2.2.1]
  unfold scatter
  rw [ho.2.2.2]

/-- Reading back the registers that hold a tile gives the tile, for every layout with `Inv`,
tile `T` of any type and cell `i < rows`, `j < cols`; the case `x = F.scatter T` of
`gather_of_scatter`. -/
theorem gather_scatter {α : Type} {F : Frag} (h : F.Inv) (T : Nat → Nat → α) {i j : Nat}
    (hi : i < F.rows) (hj : j < F.cols) : F.gather (F.scatter T) i j = T i j :=
  gather_of_scatter h (fun _ _ _ _ _ _ => rfl) hi hj

end Frag

/-- The destination of `ldmatrix.sync.aligned.m8n8.x<q>.b16` (PTX ISA 9.5, section
9.7.16.5.15), with `.trans` when `t`: the tile is the `q` matrices of 8 × 8 16-bit elements
stacked (row `8 m + i` is row `i` of matrix `m`), register `r` of each lane holds matrix `r`, two
elements per register; element `s` of register `r` of lane `l` is cell
`(8 r + l / 4, 2 (l % 4) + s)`, and with `.trans` cell `(8 r + 2 (l % 4) + s, l / 4)`. -/
def ldm (q : Nat) (t : Bool) : Frag where
  rows := 8 * q
  cols := 8
  regs := q
  pack := 2
  pos l r s := if t then (8 * r + 2 * (l % 4) + s, l / 4) else (8 * r + l / 4, 2 * (l % 4) + s)
  own i j := if t then (4 * j + i % 8 / 2, i / 8, i % 2) else (4 * (i % 8) + j / 2, i / 8, j % 2)

/-- The A operand of `mma.m8n8k4` with f16 inputs (PTX ISA 9.5, section 9.7.16.5.1), row major,
or column major when `t`. The warp computes four `m8n8k4` products, the `q`-th by the quad pair
`q`, the lanes `l` with `l % 16 / 4 = q` (lanes `4q` to `4q + 3` and `4q + 16` to `4q + 19`);
the tile is the four `8 × 4` A tiles stacked (row `8 q + i` is row `i` of product `q`), in two
`.f16x2` registers per lane. Element `s` of register `r` of lane `l` is cell
`(8 q + 4 (l / 16) + l % 4, 2 r + s)`, and when `t` cell `(8 q + 4 (l / 16) + 2 r + s, l % 4)`. -/
def quadA (t : Bool) : Frag where
  rows := 32
  cols := 4
  regs := 2
  pack := 2
  pos l r s := if t then (8 * (l % 16 / 4) + 4 * (l / 16) + 2 * r + s, l % 4)
    else (8 * (l % 16 / 4) + 4 * (l / 16) + l % 4, 2 * r + s)
  own i j := if t then (16 * (i % 8 / 4) + 4 * (i / 8) + j, i % 4 / 2, i % 2)
    else (16 * (i % 8 / 4) + 4 * (i / 8) + i % 4, j / 2, j % 2)

/-- The B operand of `mma.m8n8k4` with f16 inputs (PTX ISA 9.5, section 9.7.16.5.1), column
major, or row major when `t`: the four `4 × 8` B tiles of the quad pairs `q = l % 16 / 4`
(`quadA`) stacked (row `4 q + k` is row `k` of product `q`), in two `.f16x2` registers per lane.
Element `s` of register `r` of lane `l` is cell `(4 q + 2 r + s, 4 (l / 16) + l % 4)`, and when
`t` cell `(4 q + l % 4, 4 (l / 16) + 2 r + s)`. -/
def quadB (t : Bool) : Frag where
  rows := 16
  cols := 8
  regs := 2
  pack := 2
  pos l r s := if t then (4 * (l % 16 / 4) + l % 4, 4 * (l / 16) + 2 * r + s)
    else (4 * (l % 16 / 4) + 2 * r + s, 4 * (l / 16) + l % 4)
  own i j := if t then (16 * (j / 4) + 4 * (i / 4) + i % 4, j % 4 / 2, j % 2)
    else (16 * (j / 4) + 4 * (i / 4) + j % 4, i % 4 / 2, i % 2)

/-- The C and D operands of `mma.m8n8k4` with f16 inputs (PTX ISA 9.5, section 9.7.16.5.1), with
`p` accumulators per register (1 for f32, 2 for f16): the four `8 × 8` tiles of the quad pairs
`q = l % 16 / 4` (`quadA`) stacked (row `8 q + i` is row `i` of product `q`), in `8 / p`
registers per lane. For `p = 1`, register `r` of lane `l` is cell
`(8 q + 4 (l / 16) + l % 2 + 2 (r % 4 / 2), 4 (r / 4) + 2 (l % 4 / 2) + r % 2)`; otherwise
element `s` of register `r` is cell `(8 q + 4 (l / 16) + l % 4, p r + s)`. -/
def quadC (p : Nat) : Frag where
  rows := 32
  cols := 8
  regs := 8 / p
  pack := p
  pos l r s := if p = 1 then
      (8 * (l % 16 / 4) + 4 * (l / 16) + l % 2 + 2 * (r % 4 / 2),
        4 * (r / 4) + 2 * (l % 4 / 2) + r % 2)
    else (8 * (l % 16 / 4) + 4 * (l / 16) + l % 4, p * r + s)
  own i j := if p = 1 then
      (16 * (i % 8 / 4) + 4 * (i / 8) + 2 * (j % 4 / 2) + i % 2,
        4 * (j / 4) + 2 * (i % 4 / 2) + j % 2, 0)
    else (16 * (i % 8 / 4) + 4 * (i / 8) + i % 4, j / 2, j % 2)

/-- **The A fragments are bijections**: for every `h`, `p` and `c`, `fragA h p c` has `Inv`, so
(`Frag.bijOn`) it places the `8h × 4pc` tile one to one in the lanes' `hc` registers (for `p = 0`
both are empty). -/
theorem fragA_inv (h p c : Nat) : (fragA h p c).Inv := by
  rcases Nat.eq_zero_or_pos p with rfl | hp
  · exact ⟨fun _ _ _ _ s hs => absurd hs (by simp [fragA]),
      fun _ _ j hj => absurd hj (by simp [fragA])⟩
  refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩
  · simp only [fragA] at hr hs ⊢
    have hh : 0 < h := Nat.pos_of_ne_zero (by rintro rfl; simp at hr)
    have hrh : r % h < h := Nat.mod_lt _ hh
    have hrc : r / h < c := (Nat.div_lt_iff_lt_mul hh).2 (by rwa [Nat.mul_comm])
    have hd : (s + p * (l % 4 + 4 * (r / h))) / p = l % 4 + 4 * (r / h) := by
      rw [Nat.add_mul_div_left _ _ hp, Nat.div_eq_of_lt hs, Nat.zero_add]
    have hm : (s + p * (l % 4 + 4 * (r / h))) % p = s := by
      rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hs]
    have hc : s + p * (l % 4 + 4 * (r / h)) < 4 * p * c := by
      have h1 : l % 4 + 4 * (r / h) + 1 ≤ 4 * c := by omega
      have h2 := Nat.mul_le_mul_left p h1
      rw [Nat.mul_add, Nat.mul_one] at h2
      rw [show 4 * p * c = p * (4 * c) by ring]
      omega
    have e1 : (l / 4 + 8 * (r % h)) / 8 = r % h := by omega
    have e2 : (l % 4 + 4 * (r / h)) / 4 = r / h := by omega
    rw [hd, hm, e1, e2, Nat.mod_add_div]
    refine ⟨by omega, hc, ?_⟩
    simp only [Prod.mk.injEq, and_true]
    omega
  · simp only [fragA] at hi hj ⊢
    have hh : 0 < h := by omega
    have hq : j / p < 4 * c :=
      (Nat.div_lt_iff_lt_mul hp).2 (by rw [show 4 * c * p = 4 * p * c by ring]; exact hj)
    have hj' := Nat.mod_add_div j p
    have hr : h * (j / p / 4) + h ≤ h * c := by
      have h1 := Nat.mul_le_mul_left h (show j / p / 4 + 1 ≤ c by omega)
      rwa [Nat.mul_add_one] at h1
    have hmod : (i / 8 + h * (j / p / 4)) % h = i / 8 := by
      rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (by omega)]
    have hdiv : (i / 8 + h * (j / p / 4)) / h = j / p / 4 := by
      rw [Nat.add_mul_div_left _ _ hh, Nat.div_eq_of_lt (by omega), Nat.zero_add]
    refine ⟨by omega, by omega, Nat.mod_lt _ hp, ?_⟩
    rw [hmod, hdiv]
    have e : (4 * (i % 8) + j / p % 4) % 4 + 4 * (j / p / 4) = j / p := by omega
    rw [e, hj']
    simp only [Prod.mk.injEq, and_true]
    omega

/-- **The B fragments are bijections**: for every `p` and every `c`, `fragB p c` has `Inv`, so
(`Frag.bijOn`) it places the `4pc × 8` tile one to one in the lanes' `c` registers (for `p = 0`
both are empty). -/
theorem fragB_inv (p c : Nat) : (fragB p c).Inv := by
  rcases Nat.eq_zero_or_pos p with rfl | hp
  · exact ⟨fun _ _ _ _ s hs => absurd hs (by simp [fragB]),
      fun i hi _ _ => absurd hi (by simp [fragB])⟩
  refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩
  · simp only [fragB] at hr hs ⊢
    have hd : (s + p * (l % 4 + 4 * r)) / p = l % 4 + 4 * r := by
      rw [Nat.add_mul_div_left _ _ hp, Nat.div_eq_of_lt hs, Nat.zero_add]
    have hm : (s + p * (l % 4 + 4 * r)) % p = s := by
      rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hs]
    have hc : s + p * (l % 4 + 4 * r) < 4 * p * c := by
      have h1 : l % 4 + 4 * r + 1 ≤ 4 * c := by omega
      have h2 := Nat.mul_le_mul_left p h1
      rw [Nat.mul_add, Nat.mul_one] at h2
      rw [show 4 * p * c = p * (4 * c) by ring]
      omega
    rw [hd, hm]
    refine ⟨hc, by omega, ?_⟩
    simp only [Prod.mk.injEq, and_true]
    omega
  · simp only [fragB] at hi hj ⊢
    have hq : i / p < 4 * c :=
      (Nat.div_lt_iff_lt_mul hp).2 (by rw [show 4 * c * p = 4 * p * c by ring]; exact hi)
    have hi' := Nat.mod_add_div i p
    refine ⟨by omega, by omega, Nat.mod_lt _ hp, ?_⟩
    have e : (4 * j + i / p % 4) % 4 + 4 * (i / p / 4) = i / p := by omega
    rw [e, hi']
    simp only [Prod.mk.injEq, true_and]
    omega

/-- **The accumulator fragments are bijections**: for every `h` and `p` 1 or 2, `fragC h p` has
`Inv`, so (`Frag.bijOn`) it places the `8h × 8` tile one to one in the lanes' `2h / p`
registers. -/
theorem fragC_inv (h : Nat) {p : Nat} (hp : p = 1 ∨ p = 2) : (fragC h p).Inv := by
  rcases hp with rfl | rfl <;>
    refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩ <;>
    simp only [fragC, Prod.mk.injEq] at * <;>
    exact ⟨by omega, by omega, by omega, by omega, by omega⟩

/-- **The `ldmatrix` destinations are bijections**: for every count `q` and both values `t` of
`.trans`, `ldm q t` has `Inv`, so (`Frag.bijOn`) it places the `q` stacked 8 × 8 matrices one to
one in the lanes' `q` registers of two 16-bit elements. -/
theorem ldm_inv (q : Nat) (t : Bool) : (ldm q t).Inv := by
  refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩ <;> cases t <;>
    simp only [ldm, Prod.mk.injEq, Bool.false_eq_true, ↓reduceIte] at * <;>
    exact ⟨by omega, by omega, by omega, by omega, by omega⟩

/-- **The layouts of `m8n8k4` with f16 inputs are bijections**: for both values of the flag `t`
and `p` 1 or 2, `quadA t`, `quadB t` and `quadC p` have `Inv`, so (`Frag.bijOn`) each places its
four stacked tiles one to one in the lanes' registers. -/
theorem quad_inv (t : Bool) {p : Nat} (hp : p = 1 ∨ p = 2) :
    (quadA t).Inv ∧ (quadB t).Inv ∧ (quadC p).Inv := by
  refine ⟨?_, ?_, ?_⟩
  · refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩ <;> cases t <;>
      simp only [quadA, Prod.mk.injEq, Bool.false_eq_true, ↓reduceIte] at * <;>
      exact ⟨by omega, by omega, by omega, by omega, by omega⟩
  · refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩ <;> cases t <;>
      simp only [quadB, Prod.mk.injEq, Bool.false_eq_true, ↓reduceIte] at * <;>
      exact ⟨by omega, by omega, by omega, by omega, by omega⟩
  · rcases hp with rfl | rfl <;>
      refine ⟨fun l hl r hr s hs => ?_, fun i hi j hj => ?_⟩ <;>
      simp only [quadC, Prod.mk.injEq, Nat.reduceDiv, OfNat.ofNat_ne_one, ↓reduceIte] at * <;>
      exact ⟨by omega, by omega, by omega, by omega, by omega⟩

/-- **The layouts of every accepted `mma` are bijections of the right shapes**: for every
importer `Mma` value `v` with `mmaFrags v = some (FA, FB, FC)`, the three layouts have `Inv`, A
is `m × k`, B is `k × 8`, C/D is `m × 8`, and their register counts per lane are the importer's
`Mma.regs v`. -/
theorem mmaFrags_inv {v : Mma} {FA FB FC : Frag} (h : mmaFrags v = some (FA, FB, FC)) :
    FA.Inv ∧ FB.Inv ∧ FC.Inv ∧ FA.rows = v.m ∧ FA.cols = v.k ∧ FB.rows = v.k ∧ FB.cols = 8 ∧
      FC.rows = v.m ∧ FC.cols = 8 ∧ (FA.regs, FB.regs, FC.regs) = v.regs := by
  simp only [mmaFrags] at h
  split_ifs at h with hc
  simp only [Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  refine ⟨fragA_inv _ _ _, fragB_inv _ _, fragC_inv _ (Or.inl rfl), ?_⟩
  simp only [Mma.ok, Mma.table, List.contains_cons, List.contains_nil, Bool.or_false,
    Bool.or_eq_true, beq_iff_eq] at hc
  rcases hc with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- The registers `ldmatrix.sync.aligned.m8n8.x<q>.b16` loads, with `.trans` when `t` (PTX ISA
9.5, section 9.7.16.5.15): lane `R < 8q` gives the address `a R` of row `R` of the stacked tile,
`rd x` is the 16-bit element at byte address `x`, and element `s` of register `r` of lane `l` is
`rd` at the address of the cell `(ldm q t).pos l r s`. -/
def ldmatrix {α : Type} (q : Nat) (t : Bool) (a : Nat → Nat) (rd : Nat → α) (l r s : Nat) : α :=
  rd (a ((ldm q t).pos l r s).1 + 2 * ((ldm q t).pos l r s).2)

/-- **`ldmatrix` loads the stacked tile at the rows' addresses**, for every count `q`, flag `t`,
row addresses `a` and reader `rd`: read in the layout `ldm q t`, the registers hold
`rd (a R + 2 C)`, element `C` of row `R`, at every cell `R < 8q`, `C < 8`. -/
theorem ldmatrix_gather {α : Type} (q : Nat) (t : Bool) (a : Nat → Nat) (rd : Nat → α)
    {R C : Nat} (hR : R < 8 * q) (hC : C < 8) :
    (ldm q t).gather (ldmatrix q t a rd) R C = rd (a R + 2 * C) :=
  Frag.gather_of_scatter (ldm_inv q t) (T := fun R C => rd (a R + 2 * C))
    (fun _ _ _ _ _ _ => rfl) hR hC

/-- **`ldmatrix.x<2c>` loads the A operand of a 16-bit `mma`**, for every `c`, row addresses
`a`, reader `rd` and `16 × 8c` tile `TA`: if matrix `m` of the load is A's 8 × 8 block at rows
`8 (m % 2)`, columns `8 (m / 2)` (`rd (a R + 2 C) = TA (R % 8 + 8 (R / 8 % 2)) (C + 8 (R / 16))`
for `R < 16c`, `C < 8`), the registers without `.trans`, read in the layout `fragA 2 2 c` (as
`mmaStep` reads A), are `TA` at every cell `i < 16`, `k < 8c`. -/
theorem ldmatrix_fragA {α : Type} (c : Nat) (a : Nat → Nat) (rd : Nat → α) (TA : Nat → Nat → α)
    (hT : ∀ R < 8 * (2 * c), ∀ C < 8,
      rd (a R + 2 * C) = TA (R % 8 + 8 * (R / 8 % 2)) (C + 8 * (R / 16)))
    {i k : Nat} (hi : i < 16) (hk : k < 8 * c) :
    (fragA 2 2 c).gather (ldmatrix (2 * c) false a rd) i k = TA i k := by
  refine Frag.gather_of_scatter (fragA_inv 2 2 c) (fun l hl r hr s hs => ?_) hi hk
  have hp := (ldm_inv (2 * c) false).1 l hl r hr s hs
  show rd _ = _
  rw [hT _ hp.1 _ hp.2.1]
  simp only [Frag.scatter, ldm, fragA, Bool.false_eq_true, ↓reduceIte]
  congr 1 <;> omega

/-- **`ldmatrix.x<ch>.trans` loads `h` B operands of a 16-bit `mma` side by side**, for every
`c` and `h`, row addresses `a`, reader `rd` and `8c × 8h` tile `TB` stored row major: if matrix
`m` of the load is `TB`'s 8 × 8 block at rows `8 (m % c)`, columns `8 (m / c)`
(`rd (a R + 2 C) = TB (R % 8c) (C + 8 (R / 8c))` for `R < 8ch`, `C < 8`), then for every operand
`o < h` the registers `c o` to `c o + c - 1`, read in the layout `fragB 2 c`, are the columns
`8 o` to `8 o + 7` of `TB`, at every cell `i < 8c`, `j < 8`. -/
theorem ldmatrix_fragB_cols {α : Type} (c h : Nat) (a : Nat → Nat) (rd : Nat → α)
    (TB : Nat → Nat → α)
    (hT : ∀ R < 8 * (c * h), ∀ C < 8,
      rd (a R + 2 * C) = TB (R % (8 * c)) (C + 8 * (R / (8 * c))))
    {o i j : Nat} (ho : o < h) (hi : i < 8 * c) (hj : j < 8) :
    (fragB 2 c).gather (fun l r s => ldmatrix (c * h) true a rd l (c * o + r) s) i j =
      TB i (j + 8 * o) := by
  refine Frag.gather_of_scatter (fragB_inv 2 c) (T := fun i j => TB i (j + 8 * o))
    (fun l hl m hm s hs => ?_) hi hj
  have hm : m < c := hm
  have hs : s < 2 := hs
  have hr : c * o + m < c * h := by
    have h1 : c * (o + 1) ≤ c * h := Nat.mul_le_mul_left c ho
    rw [Nat.mul_add_one] at h1
    omega
  have hp := (ldm_inv (c * h) true).1 l hl _ hr s hs
  show rd _ = _
  rw [hT _ hp.1 _ hp.2.1]
  have hx : 8 * m + 2 * (l % 4) + s < 8 * c := by omega
  have e : 8 * (c * o + m) + 2 * (l % 4) + s = 8 * c * o + (8 * m + 2 * (l % 4) + s) := by ring
  simp only [Frag.scatter, ldm, fragB, ↓reduceIte]
  rw [e, Nat.mul_add_mod (8 * c) o, Nat.mod_eq_of_lt hx, Nat.mul_add_div (by omega : 0 < 8 * c) o,
    Nat.div_eq_of_lt hx]
  exact congrArg₂ TB (by omega) (by omega)

/-- **`ldmatrix.x<c>.trans` loads the B operand of a 16-bit `mma`**, for every `c`, row addresses
`a`, reader `rd` and `8c × 8` tile `TB` stored row major (`rd (a R + 2 C) = TB R C` for
`R < 8c`, `C < 8`): the registers with `.trans`, read in the layout `fragB 2 c` (as `mmaStep`
reads B), are `TB` at every cell `i < 8c`, `j < 8`, the two layouts placing every element
alike; the case `h = 1` of `ldmatrix_fragB_cols`. -/
theorem ldmatrix_fragB {α : Type} (c : Nat) (a : Nat → Nat) (rd : Nat → α) (TB : Nat → Nat → α)
    (hT : ∀ R < 8 * c, ∀ C < 8, rd (a R + 2 * C) = TB R C) {i j : Nat} (hi : i < 8 * c)
    (hj : j < 8) : (fragB 2 c).gather (ldmatrix c true a rd) i j = TB i j := by
  have hT1 : ∀ R < 8 * (c * 1), ∀ C < 8,
      rd (a R + 2 * C) = TB (R % (8 * c)) (C + 8 * (R / (8 * c))) := fun R hR C hC => by
    rw [Nat.mod_eq_of_lt (by omega), Nat.div_eq_of_lt (by omega)]
    simpa using hT R (by omega) C hC
  simpa using ldmatrix_fragB_cols c 1 a rd TB hT1 (o := 0) Nat.one_pos hi hj

/-- **`ldmatrix.x<c>` without `.trans` loads the B operand of a 16-bit `mma` stored transposed**,
for every `c`, row addresses `a`, reader `rd` and `8c × 8` tile `TB`: if matrix `m` of the load
is columns `8 m` to `8 m + 7` of B's transpose, row `n` of each matrix holding column `n` of B
(`rd (a R + 2 C) = TB (C + 8 (R / 8)) (R % 8)` for `R < 8c`, `C < 8`), the registers, read in
the layout `fragB 2 c`, are `TB` at every cell `i < 8c`, `j < 8`. -/
theorem ldmatrix_fragBt {α : Type} (c : Nat) (a : Nat → Nat) (rd : Nat → α)
    (TB : Nat → Nat → α)
    (hT : ∀ R < 8 * c, ∀ C < 8, rd (a R + 2 * C) = TB (C + 8 * (R / 8)) (R % 8))
    {i j : Nat} (hi : i < 8 * c) (hj : j < 8) :
    (fragB 2 c).gather (ldmatrix c false a rd) i j = TB i j := by
  refine Frag.gather_of_scatter (fragB_inv 2 c) (fun l hl r hr s hs => ?_) hi hj
  have hp := (ldm_inv c false).1 l hl r hr s hs
  show rd _ = _
  rw [hT _ hp.1 _ hp.2.1]
  simp only [Frag.scatter, ldm, fragB, Bool.false_eq_true, ↓reduceIte]
  congr 1 <;> omega

/-- The obligation of a warp-collective step (`ldmatrix`, `mma`) at thread `n` of grid `g`, in
blocks of `size` threads, as `Grid.fire` checks it for `shfl.sync`: thread `n`'s warp (the 32
threads from `n - n % size % 32`) lies whole inside its block, and each of its 32 lanes waits
at a call of the same intrinsic `i` at the same instruction `p`. The ISA's `.sync.aligned`
requires every lane of the warp to execute the same instruction. -/
def Grid.warpReady (g : Grid) (size n : Nat) (i : Intrinsic) : Prop :=
  n % size - n % size % 32 + 32 ≤ size ∧
    ∃ p, ∀ j < 32, ∃ t args fn,
      g.threads[n - n % size % 32 + j]? = some (Status.wait t i args fn) ∧ t.at = p

/-- **`mma` on fragments is the accumulation on tiles**, for all layouts with `Inv` whose shapes
fit (`FC.rows ≤ FA.rows`, `FC.cols ≤ FB.cols`, `K ≤ FA.cols`, `K ≤ FB.rows`), every accumulation
`acc`, all tiles `TA`, `TB`, `TC` of any types and every cell `i < FC.rows`, `j < FC.cols`: the D
tile of `mmaStep` on the scattered tiles is `acc (TA i ·) (TB · j) (TC i j)` at `(i, j)`. -/
theorem mmaStep_gather {α β : Type} {K : Nat} {FA FB FC : Frag} (hA : FA.Inv) (hB : FB.Inv)
    (hC : FC.Inv) (hm : FC.rows ≤ FA.rows) (hn : FC.cols ≤ FB.cols) (hkA : K ≤ FA.cols)
    (hkB : K ≤ FB.rows) (acc : (Fin K → α) → (Fin K → α) → β → β) (TA TB : Nat → Nat → α)
    (TC : Nat → Nat → β) {i j : Nat} (hi : i < FC.rows) (hj : j < FC.cols) :
    FC.gather (mmaStep FA FB FC acc (FA.scatter TA) (FB.scatter TB) (FC.scatter TC)) i j =
      acc (fun k => TA i k) (fun k => TB k j) (TC i j) := by
  have hA' : ∀ k : Fin K, FA.gather (FA.scatter TA) i k = TA i k := fun k =>
    Frag.gather_scatter hA TA (by omega) (by omega)
  have hB' : ∀ k : Fin K, FB.gather (FB.scatter TB) k j = TB k j := fun k =>
    Frag.gather_scatter hB TB (by omega) (by omega)
  show mmaStep FA FB FC acc _ _ _ (FC.own i j).1 (FC.own i j).2.1 (FC.own i j).2.2 = _
  unfold mmaStep
  rw [(hC.2 i hi j hj).2.2.2]
  simp only [hA', hB', Frag.gather_scatter hC TC hi hj]

/-- Cell `(i, j)` of a rank-2 tensor `T` of shape `[m, n]` as a function of two numbers: its
entry when `i < m` and `j < n`, and `d` elsewhere. -/
def tileEntry {α : Type} {m n : Nat} (d : α) (T : Tensor α [m, n]) (i j : Nat) : α :=
  if h : i < m ∧ j < n then Tensor.get2 T ⟨i, h.1⟩ ⟨j, h.2⟩ else d

private theorem foldl_eq_sum {K : Nat} (f : Fin K → ℝ) :
    (List.finRange K).foldl (fun s k => s + f k) 0 = ∑ k, f k := by
  rw [Fin.sum_univ_def, List.sum_eq_foldl, List.foldl_map]

/-- The exact accumulation over `ℝ`: `Σ_k a_k b_k + c`. -/
noncomputable def exactAcc {K : Nat} (a b : Fin K → ℝ) (c : ℝ) : ℝ :=
  ∑ k, a k * b k + c

/-- **The exact `mma` is TorchLean's `matmul A B + C`**: for all layouts with `Inv` of shapes
`m × K` (A), `K × n` (B) and `m × n` (C), all real tensors `TA : [m, K]`, `TB : [K, n]`,
`TC : [m, n]` and every cell, the D tile of `mmaStep` with `exactAcc` on their scattered tiles
is `get2 (Tensor.matmul TA TB + TC) i j`. -/
theorem mma_exact {m n K : Nat} {FA FB FC : Frag} (hA : FA.Inv) (hB : FB.Inv) (hC : FC.Inv)
    (hmA : FA.rows = m) (hkA : FA.cols = K) (hkB : FB.rows = K) (hnB : FB.cols = n)
    (hmC : FC.rows = m) (hnC : FC.cols = n) (TA : Tensor ℝ [m, K]) (TB : Tensor ℝ [K, n])
    (TC : Tensor ℝ [m, n]) (i : Fin m) (j : Fin n) :
    FC.gather (mmaStep FA FB FC (exactAcc (K := K)) (FA.scatter (tileEntry 0 TA))
        (FB.scatter (tileEntry 0 TB)) (FC.scatter (tileEntry 0 TC))) i j =
      Tensor.get2 (Tensor.matmul TA TB + TC) i j := by
  rw [mmaStep_gather hA hB hC (by omega) (by omega) (by omega) (by omega) _ _ _ _ (by omega)
    (by omega), Tensor.add_def, Tensor.get2_zipWith, Tensor.get2_matmul, foldl_eq_sum]
  simp [exactAcc, tileEntry]

/-- The accumulation contract with magnitudes `mag`, `magC` and error `bnd`, for input format
`fi` and accumulator format `fc`: for all finite input words `a k`, `b k` and a finite `c`, a
finite result is within `bnd (Σ_k mag a_k b_k + magC c)` of `Σ_k a_k b_k + c`, over the words'
real values. Nothing is claimed of an infinite or NaN result. -/
def AccBy {fi fc : FloatFormat} {K : Nat} (mag : Model fi → Model fi → ℝ) (magC : Model fc → ℝ)
    (bnd : ℝ → ℝ) (acc : (Fin K → Model fi) → (Fin K → Model fi) → Model fc → Model fc) : Prop :=
  ∀ a b c, (∀ k, (a k).isFinite = true) → (∀ k, (b k).isFinite = true) → c.isFinite = true →
    (acc a b c).isFinite = true →
    |(acc a b c).toReal - (∑ k, (a k).toReal * (b k).toReal + c.toReal)| ≤
      bnd (∑ k, mag (a k) (b k) + magC c)

/-- The accumulation contract with error `bnd` at the absolute values: `AccBy` with the
magnitudes `|a_k b_k|` and `|c|`, so a finite result is within `bnd (Σ_k |a_k b_k| + |c|)` of
`Σ_k a_k b_k + c`. -/
def AccOk {fi fc : FloatFormat} {K : Nat} (bnd : ℝ → ℝ)
    (acc : (Fin K → Model fi) → (Fin K → Model fi) → Model fc → Model fc) : Prop :=
  AccBy (fun x y => |x.toReal * y.toReal|) (fun c => |c.toReal|) bnd acc

/-- **The `mma` contract against TorchLean**: for all layouts with `Inv` of shapes `m × K`,
`K × n` and `m × n`, all magnitudes `mag`, `magC`, every accumulation `acc` meeting
`AccBy mag magC bnd` (`AccOk bnd` among them), all tensors of words `TA : [m, K]`, `TB : [K, n]`
(format `fi`), `TC : [m, n]` (format `fc`), out-of-shape words `dA`, `dB`, `dC` and every cell
`(i, j)`: if row `i` of A, column `j` of B and `C (i, j)` are finite and D's word at `(i, j)` is
finite, it is within `bnd (Σ_k mag a_ik b_kj + magC c_ij)` of entry `(i, j)` of TorchLean's real
`matmul A' B' + C'` (the tensors mapped by `Model.toReal`). It covers a GPU only if the GPU's
accumulation meets the premise. -/
theorem mma_contract {fi fc : FloatFormat} {m n K : Nat} {FA FB FC : Frag} (hA : FA.Inv)
    (hB : FB.Inv) (hC : FC.Inv) (hmA : FA.rows = m) (hkA : FA.cols = K) (hkB : FB.rows = K)
    (hnB : FB.cols = n) (hmC : FC.rows = m) (hnC : FC.cols = n) {mag : Model fi → Model fi → ℝ}
    {magC : Model fc → ℝ} {bnd : ℝ → ℝ}
    {acc : (Fin K → Model fi) → (Fin K → Model fi) → Model fc → Model fc}
    (hacc : AccBy mag magC bnd acc)
    (TA : Tensor (Model fi) [m, K]) (TB : Tensor (Model fi) [K, n]) (TC : Tensor (Model fc) [m, n])
    (dA dB : Model fi) (dC : Model fc) (i : Fin m) (j : Fin n)
    (hfA : ∀ k, (Tensor.get2 TA i k).isFinite = true)
    (hfB : ∀ k, (Tensor.get2 TB k j).isFinite = true) (hfC : (Tensor.get2 TC i j).isFinite = true)
    (hf : (FC.gather (mmaStep FA FB FC acc (FA.scatter (tileEntry dA TA))
        (FB.scatter (tileEntry dB TB)) (FC.scatter (tileEntry dC TC))) i j).isFinite = true) :
    |(FC.gather (mmaStep FA FB FC acc (FA.scatter (tileEntry dA TA))
        (FB.scatter (tileEntry dB TB)) (FC.scatter (tileEntry dC TC))) i j).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal TA) (Tensor.map Model.toReal TB) +
          Tensor.map Model.toReal TC) i j| ≤
      bnd (∑ k, mag (Tensor.get2 TA i k) (Tensor.get2 TB k j) + magC (Tensor.get2 TC i j)) := by
  have e := mmaStep_gather hA hB hC (by omega) (by omega) (by omega) (by omega) acc
    (tileEntry dA TA) (tileEntry dB TB) (tileEntry dC TC) (i := i) (j := j) (by omega) (by omega)
  have eA : (fun k : Fin K => tileEntry dA TA i k) = fun k => Tensor.get2 TA i k := by
    funext k; simp [tileEntry]
  have eB : (fun k : Fin K => tileEntry dB TB k j) = fun k => Tensor.get2 TB k j := by
    funext k; simp [tileEntry]
  have eC : tileEntry dC TC i j = Tensor.get2 TC i j := by simp [tileEntry]
  rw [eA, eB, eC] at e
  rw [e] at hf ⊢
  rw [Tensor.add_def, Tensor.get2_zipWith, Tensor.get2_matmul, foldl_eq_sum]
  simp only [Tensor.get2, Tensor.unstack_map, Tensor.getScalar_map] at hfA hfB hfC hf ⊢
  exact hacc _ _ _ hfA hfB hfC hf

/-- **A concrete accumulation meeting the contract**: in every pair of formats `fi`, `fc` with
`fc` IEEE and a cast that is exact on finite words (`hcast`; FloatLib's
`Model.toReal_cast_bfloat16_binary32` for bfloat16 to binary32), for every `contract` flag and
oracle sequence `o`, the accumulation that casts the `K` input pairs to `fc` and folds them from
`c` with `dotLoop` (each step fused or not, as `o` chooses) meets `AccOk (dotBound fc K)`. -/
theorem castDot_ok {fi fc : FloatFormat} {K : Nat} (hfmt : fc.isIEEE = true)
    (hcast : ∀ x : Model fi, x.isFinite = true → (Model.cast fi fc x).toReal = x.toReal)
    (flag : Bool) (o : Nat → Nat × Nat) :
    AccOk (dotBound fc K) fun (a b : Fin K → Model fi) (c : Model fc) =>
      dotLoop flag o c (List.ofFn fun k => (Model.cast fi fc (a k), Model.cast fi fc (b k))) := by
  intro a b c ha hb _ hf
  have hu := Model.unitRoundoffAt_pos fc
  have h0 : |c.toReal - c.toReal| ≤ dotBound fc 0 |c.toReal| := by
    simp only [sub_self, abs_zero, dotBound, zero_add, pow_one, pow_zero, sub_self, mul_zero,
      zero_div, add_zero, add_sub_cancel_left]
    exact mul_nonneg hu.le (abs_nonneg _)
  have e := dotLoop_error_of hfmt flag _ o c 0 c.toReal |c.toReal| le_rfl h0 hf
  simp only [List.map_ofFn, List.sum_ofFn, List.length_ofFn, Function.comp_def, zero_add,
    hcast _ (ha _), hcast _ (hb _)] at e
  rwa [add_comm (c.toReal), add_comm |c.toReal|] at e

/-- **The sequential round-to-nearest policy**, for every pair of formats: the `K` input pairs
cast to the accumulator's format `fc` (`Model.cast`) and folded from C in order, `K` products
and `K` sums each rounded to nearest, ties to even (`dotLoop` unfused: FloatLib's `Model.mul`
and `Model.add`, through `deliver` at the oracle number 0, which keeps every word). -/
def seqAcc : MmaAcc := fun fi fc _ a b c =>
  dotLoop false (fun _ => (0, 0)) c
    (List.ofFn fun k => (Model.cast fi fc (a k), Model.cast fi fc (b k)))

/-- **The sequential policy meets the contract**: `castDot_ok` at `seqAcc`, in every pair of
formats `fi`, `fc` with `fc` IEEE and a cast exact on finite words (`hcast`), for every `K`. -/
theorem seqAcc_ok {fi fc : FloatFormat} {K : Nat} (hfmt : fc.isIEEE = true)
    (hcast : ∀ x : Model fi, x.isFinite = true → (Model.cast fi fc x).toReal = x.toReal) :
    AccOk (dotBound fc K) (seqAcc fi fc (K := K)) :=
  castDot_ok hfmt hcast false _

end MojoProof.Sem
