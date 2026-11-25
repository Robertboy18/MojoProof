import MojoProofTest.SkelVadd
import MojoProofTest.Eval

/-!
# 2-D cells apart, and `Elem.Out` at the end of a run

Tests.

* `L2x3`, `valid2x3`: one block of 2 × 3 threads. `apart2x3`: an instance of `Launch.apart_xy`
  there, the `float` cells `(row * 3 + col) * 4` of the threads with row below 2 and column
  below 3 (every thread) are 4 bytes apart.
* `not_apart_xy`: the twin of `Launch.apart_xy`, for every valid launch, row stride `s`, row
  bound `m ≥ 2`, column bound `n > s` and width `w > 0` with at least 2 rows and `s + 1` columns
  of threads: the cells `(row * s + col) * w` are not apart (the thread at row 0 and column `s`
  and the one at row 1 and column 0 share cell `s * w`), so `Launch.apart_xy`'s premise `n ≤ s`
  cannot be dropped. `apart2x3_twin` (stride 2, column bound 3, width 4 on `L2x3`) and
  `apart4x5_twin` (stride 4, column bound 5, width 8 on `L4x5`, 2 blocks of 2 × 5 threads) are
  its instances, tests at two sizes.
* `out_run`: an instance of `Elem.Out.of_run` on a run of `vector_addition` (the start, a
  complete run and the bounded check `outV` of `MojoProofTest/SkelVadd.lean`): `Elem.Out` of the
  final blocks, with the premise on the bytes beyond the bound from `Grid.start_reach_above`.

Except `not_apart_xy`, each covers one launch, or one run at one argument list, memory, address
choice and oracle.
-/

namespace MojoProofTest.KernelXY

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProof.Sym

/-- The launch of one block of 2 × 3 threads (`x` side 2, `y` side 3). -/
def L2x3 : Launch := launch2 1 1 2 3

/-- `L2x3` is valid (`launch2_valid`). For this one launch. -/
theorem valid2x3 : L2x3.Valid :=
  launch2_valid (by decide)

/-- **The 2-D cells of `L2x3` are apart** (`Launch.apart_xy` at row stride 3, row bound 2,
column bound 3 and width 4): the cells `(row * 3 + col) * 4` of its threads are 4 bytes
apart. -/
theorem apart2x3 : Apart (fun i : {k // k < volume L2x3.grid * volume L2x3.block ∧
    L2x3.index k .x < 2 ∧ L2x3.index k .y < 3} => (L2x3.index i.1 .x * 3 + L2x3.index i.1 .y) * 4)
    4 :=
  Launch.apart_xy valid2x3 ⟨rfl, rfl⟩ le_rfl 4

/-- **The twin of `Launch.apart_xy`: with a stride below the column bound the cells are not
apart.** For every valid launch `L`, row stride `s`, row bound `m ≥ 2`, column bound `n > s` and
width `w > 0`, when `L` has at least 2 rows and `s + 1` columns of threads: the cells
`(row * s + col) * w` of the threads with row below `m` and column below `n` are not `w` bytes
apart. The thread at row 0 and column `s` and the one at row 1 and column 0 (`Launch.cell_onto`)
both have cell `s * w`. -/
theorem not_apart_xy {L : Launch} (hL : L.Valid) {s m n w : Nat} (hs : s < n) (hm : 2 ≤ m)
    (hX : 2 ≤ L.grid .x * L.block .x) (hY : s < L.grid .y * L.block .y) (hw : 0 < w) :
    ¬ Apart (fun i : {k // k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
      L.index k .y < n} => (L.index i.1 .x * s + L.index i.1 .y) * w) w := by
  intro h
  obtain ⟨a, ha, ax, ay⟩ := Launch.cell_onto hL (r := 0) (c := s) (by omega) hY
  obtain ⟨b, hb, bx, byy⟩ := Launch.cell_onto hL (r := 1) (c := 0) (by omega) (by omega)
  have := h ⟨a, ha, by omega, by omega⟩ ⟨b, hb, by omega, by omega⟩ fun e => by
    have := congrArg (fun i : {k // k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
      L.index k .y < n} => L.index i.1 .x) e
    simp only [ax, bx] at this
    exact absurd this (by decide)
  simp only [ax, ay, bx, byy, Nat.zero_mul, Nat.zero_add, Nat.one_mul, Nat.add_zero] at this
  generalize s * w = q at this
  omega

/-- **The twin on `L2x3`** (`not_apart_xy` at row stride 2, row bound 2, column bound 3 and
width 4): threads 4 (row 0, column 2) and 1 (row 1, column 0) of `L2x3` both have cell 8. A test
of `not_apart_xy`. -/
theorem apart2x3_twin : ¬ Apart (fun i : {k // k < volume L2x3.grid * volume L2x3.block ∧
    L2x3.index k .x < 2 ∧ L2x3.index k .y < 3} => (L2x3.index i.1 .x * 2 + L2x3.index i.1 .y) * 4)
    4 :=
  not_apart_xy valid2x3 (by decide) le_rfl (by decide) (by decide) (by decide)

/-- The launch of 2 × 1 blocks of 2 × 5 threads: 4 rows and 5 columns of threads. -/
def L4x5 : Launch := launch2 2 1 2 5

/-- `L4x5` is valid (`launch2_valid`). For this one launch. -/
theorem valid4x5 : L4x5.Valid :=
  launch2_valid (by decide)

/-- **The twin on `L4x5`** (`not_apart_xy` at row stride 4, row bound 4, column bound 5 and
width 8): the threads at row 0, column 4 and at row 1, column 0 both have cell 32. A test of
`not_apart_xy` at a second size. -/
theorem apart4x5_twin : ¬ Apart (fun i : {k // k < volume L4x5.grid * volume L4x5.block ∧
    L4x5.index k .x < 4 ∧ L4x5.index k .y < 5} => (L4x5.index i.1 .x * 4 + L4x5.index i.1 .y) * 8)
    8 :=
  not_apart_xy valid4x5 (by decide) (by decide) (by decide) (by decide) (by decide)

open MojoProofTest.Kernel (ch₀ ω₀ mem5 x5 y5 mem5_none bytes5_end) in
open MojoProofTest.SkelVadd (vaddOk mem5_blocks outV) in
/-- **`Elem.Out` at the end of a run of `vector_addition`** (`Elem.Out.of_run`): the start on
`mem5` at `ch₀` and `ω₀` succeeds, the start's grid reaches a complete grid, and that grid's
blocks are `Elem.Out`'s for the bytes `Kernels.vadd.bytes ω₀ x5 y5 5` at cells `4 * i` of block 3
after the one thread of the launch. The premise on the bytes beyond the bound holds since
`mem5`'s blocks are owned by no thread and fit below it (`mem5_blocks`). -/
theorem out_run : ∃ g c z, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    Relation.ReflTransGen (Grid.Step .one c) g z ∧ GPUProof.Done sig (z, Launch.one, c) ∧
    Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 1 z.mem.blocks := by
  obtain ⟨g, c, z, hs, -, hr, hd, -, ho⟩ := vaddOk
  simp only [outV, Bool.and_eq_true] at ho
  refine ⟨g, c, z, hs, hr, hd, Elem.Out.of_run hs hr ho.1 mem5_none
    (fun i hi => bytes5_end i (by omega)) fun b x hx => ⟨fun w h => ?_, ?_⟩⟩
  · rw [(mem5_blocks hx).2.1] at h
    cases h
  · have := (mem5_blocks hx).2.2
    omega

end MojoProofTest.KernelXY
