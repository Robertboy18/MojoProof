import MojoProofTest.SkelVadd
import MojoProofTest.Eval

/-!
# 2-D cells apart, and `Elem.Out` at the end of a run

Tests.

* `L2x3`, `valid2x3`: one block of 2 × 3 threads. `apart2x3`: an instance of `Launch.apart_xy`
  there, the `float` cells `(row * 3 + col) * 4` of the threads with row below 2 and column
  below 3 (every thread) are 4 bytes apart. The twin `apart2x3_twin`: with the stride 2 below the
  column bound 3 the cells are not apart (threads 4, at row 0 and column 2, and 1, at row 1 and
  column 0, share cell 8), so `Launch.apart_xy`'s premise `n ≤ s` cannot be dropped.
* `out_run`: an instance of `Elem.Out.of_run` on a run of `vector_addition` (the start, a
  complete run and the bounded check `outV` of `MojoProofTest/SkelVadd.lean`): `Elem.Out` of the
  final blocks, with the premise on the bytes beyond the bound from `Grid.start_reach_above`.

Each covers one launch, or one run at one argument list, memory, address choice and oracle.
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

/-- **The twin: with a stride below the column bound the cells are not apart.** At row stride 2
and column bound 3, threads 4 (row 0, column 2) and 1 (row 1, column 0) of `L2x3` both have
cell 8. -/
theorem apart2x3_twin : ¬ Apart (fun i : {k // k < volume L2x3.grid * volume L2x3.block ∧
    L2x3.index k .x < 2 ∧ L2x3.index k .y < 3} => (L2x3.index i.1 .x * 2 + L2x3.index i.1 .y) * 4)
    4 := by
  intro h
  have := h ⟨4, by decide⟩ ⟨1, by decide⟩ fun e => absurd (congrArg Subtype.val e) (by decide)
  revert this
  decide

open MojoProofTest.Kernel (ch₀ ω₀ mem5 x5 y5 mem5_none bytes5_end) in
open MojoProofTest.SkelVadd (vaddOk mem5_blocks outV) in
/-- **`Elem.Out` at the end of a run of `vector_addition`** (`Elem.Out.of_run`): the start on
`mem5` at `ch₀` and `ω₀` succeeds, the start's grid reaches a complete grid, and that grid's
blocks are `Elem.Out`'s for the bytes `Kernels.vadd.bytes ω₀ x5 y5 5` at cells `4 * i` of block 3
after the one thread of the launch. The premise on the bytes beyond the bound holds since
`mem5`'s blocks are owned by no thread and fit below it (`mem5_blocks`). -/
theorem out_run : ∃ g c z, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    Relation.ReflTransGen (Grid.Step .one c) g z ∧ z.Done ∧
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
