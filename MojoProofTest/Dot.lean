import MojoProof.Sem.Dot
import MojoProofTest.FloatRel

/-!
# Instances and twins of the dot-product fold of MojoProof/Sem/Dot.lean

On binary32, with the factor pairs `dotData`: `(2, -1)`, `(1, 1)` and
`(1 + 2 ^ -23, 1 - 2 ^ -23)`, whose exact dot product is `-2 ^ -46` (`dotData_sum`):

* `dot_vals`: with the `contract` flag and the `fadd` oracle numbers 0 (no iteration fused) the
  loop from `+0` gives `+0` (`unfusedDot`); with the `fadd` oracle numbers 2 (every iteration
  fused) it gives `-2 ^ -46` (`fusedDot`), because the last iteration's `fma` is exact while the
  rounded product `1 - 2 ^ -46` is 1. The two words differ.
* `dot_bound_inst`, the instance of `dotLoop_error`: both results are finite, so each is within
  `dotBound .binary32 3 T` of the exact sum; the errors are `2 ^ -46` and 0 (`dot_errors`).
* `dot_inOrder_inst`, the instance of `dotLoop_eq_dotInOrder`: without the `contract` flag, and
  with it under the `fadd` oracle numbers 1 (contraction's case 1 needs factors of the accumulator,
  which a `phi` does not record), the loop's word is FloatLib's `Model.dotInOrder`, by
  `decide +kernel`. Its twin (`dot_inOrder_twin`), of the premise that no `fadd` oracle number is 2
  modulo 3: `fusedDot` is not FloatLib's word.
* `dot_nan_twin`: the NaN half of `dotLoop_nanEq` cannot be strengthened to equality of words: on
  the pair `(qNaN, 1)` the loop's NaN is the oracle's `0x7fc00002` and FloatLib's is not.
* `dot_step_inst`, the instance of `floatBin_dotStep`: `floatBin`'s `fmul contract` and then
  `fadd contract` of `-1` and the last pair under the oracle numbers 0 and 2 is the scalar of
  `-2 ^ -46`.
-/

namespace MojoProofTest.Dot

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.FloatRel (f32)

/-- The binary32 factor pairs `(2, -1)`, `(1, 1)` and `(1 + 2 ^ -23, 1 - 2 ^ -23)`. -/
def dotData : List (Model .binary32 × Model .binary32) :=
  [(f32 0x40000000, f32 0xbf800000), (f32 0x3f800000, f32 0x3f800000),
    (f32 0x3f800001, f32 0x3f7ffffe)]

/-- The loop over `dotData` from `+0` with the `contract` flag and the oracle numbers `(0, 0)` at
every iteration: no iteration is fused. -/
def unfusedDot : Model .binary32 :=
  dotLoop true (fun _ => (0, 0)) (Model.zero .binary32 false) dotData

/-- The loop over `dotData` from `+0` with the `contract` flag and the oracle numbers `(0, 2)` at
every iteration: every iteration is fused. -/
def fusedDot : Model .binary32 :=
  dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) dotData

/-- The unfused loop gives `+0`, the fused one `-2 ^ -46`, and the two words differ, by
evaluation. -/
theorem dot_vals :
    unfusedDot.toRat? = some 0 ∧ fusedDot.toRat? = some (-1 / 70368744177664) ∧
      unfusedDot ≠ fusedDot := by
  decide +kernel

/-- The exact dot product of `dotData` (the real values of its words) is `-2 ^ -46`, and the sum
of the absolute products is `4 - 2 ^ -46`. -/
theorem dotData_sum :
    (dotData.map fun ab => ab.1.toReal * ab.2.toReal).sum = -(1 / 2 ^ 46) ∧
      (dotData.map fun ab => |ab.1.toReal * ab.2.toReal|).sum = 4 - 1 / 2 ^ 46 := by
  have h : (f32 0x40000000).toRat? = some 2 ∧ (f32 0xbf800000).toRat? = some (-1) ∧
      (f32 0x3f800000).toRat? = some 1 ∧ (f32 0x3f800001).toRat? = some (1 + 1 / 8388608) ∧
      (f32 0x3f7ffffe).toRat? = some (1 - 1 / 8388608) := by
    decide +kernel
  obtain ⟨h1, h2, h3, h4, h5⟩ := h
  simp only [dotData, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    Model.Algebraic.toReal_of_toRat?_eq_some h1, Model.Algebraic.toReal_of_toRat?_eq_some h2,
    Model.Algebraic.toReal_of_toRat?_eq_some h3, Model.Algebraic.toReal_of_toRat?_eq_some h4,
    Model.Algebraic.toReal_of_toRat?_eq_some h5]
  norm_num [abs_of_nonneg, abs_of_nonpos]

/-- **The instance of `dotLoop_error`**: both `unfusedDot` and `fusedDot` are finite, so each is
within `dotBound .binary32 3 T` of the exact dot product of `dotData`, with `T` the sum of the
absolute products. -/
theorem dot_bound_inst :
    |unfusedDot.toReal - (dotData.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
        dotBound .binary32 3 (dotData.map fun ab => |ab.1.toReal * ab.2.toReal|).sum ∧
      |fusedDot.toReal - (dotData.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
        dotBound .binary32 3 (dotData.map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  ⟨dotLoop_error rfl true _ dotData (Model.Algebraic.isFinite_of_toRat?_eq_some dot_vals.1),
    dotLoop_error rfl true _ dotData (Model.Algebraic.isFinite_of_toRat?_eq_some dot_vals.2.1)⟩

/-- The errors that `dot_bound_inst` bounds: `2 ^ -46` for `unfusedDot` and 0 for `fusedDot`. -/
theorem dot_errors :
    |unfusedDot.toReal - (dotData.map fun ab => ab.1.toReal * ab.2.toReal).sum| = 1 / 2 ^ 46 ∧
      |fusedDot.toReal - (dotData.map fun ab => ab.1.toReal * ab.2.toReal).sum| = 0 := by
  rw [dotData_sum.1, Model.Algebraic.toReal_of_toRat?_eq_some dot_vals.1,
    Model.Algebraic.toReal_of_toRat?_eq_some dot_vals.2.1]
  norm_num

/-- **The instance of `dotLoop_eq_dotInOrder`**: on `dotData`, the loop without the `contract`
flag (oracle numbers `(0, 0)`), and with it under the oracle numbers `(0, 1)`, is
`Model.dotInOrder .binary32 .binary32 dotData`, by evaluation; that word is not a NaN, and
`dotLoop_eq_dotInOrder` gives the same for the second loop. -/
theorem dot_inOrder_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) dotData =
        Model.dotInOrder .binary32 .binary32 dotData ∧
      dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) dotData =
        Model.dotInOrder .binary32 .binary32 dotData :=
  ⟨by decide +kernel,
    (dotLoop_eq_dotInOrder true (fun _ => (0, 1)) dotData (fun _ _ => by simp)).1
      (by decide +kernel)⟩

/-- **The twin of `dotLoop_eq_dotInOrder`'s premise** that no `fadd` oracle number is 2 modulo 3
when the `contract` flag is set: `fusedDot`, under the oracle numbers 2, is not FloatLib's
`Model.dotInOrder .binary32 .binary32 dotData`, by evaluation. -/
theorem dot_inOrder_twin : fusedDot ≠ Model.dotInOrder .binary32 .binary32 dotData := by
  decide +kernel

/-- **The twin of the NaN half of `dotLoop_nanEq`**: on the one pair (quiet NaN `0x7fc00000`, 1),
without the `contract` flag and with the `fadd` oracle number `3 * 0x7fc00002`, the loop gives
the NaN `0x7fc00002` and `Model.dotInOrder` a NaN that is a different word, by evaluation. -/
theorem dot_nan_twin :
    dotLoop false (fun _ => (0, 3 * 0x7fc00002)) (Model.zero .binary32 false)
        [(f32 0x7fc00000, f32 0x3f800000)] = f32 0x7fc00002 ∧
      (Model.dotInOrder .binary32 .binary32 [(f32 0x7fc00000, f32 0x3f800000)]).isNaN = true ∧
      f32 0x7fc00002 ≠
        Model.dotInOrder .binary32 .binary32 [(f32 0x7fc00000, f32 0x3f800000)] := by
  decide +kernel

/-- **The instance of `floatBin_dotStep`**: on `float` with the `contract` flag, `floatBin`'s
`fmul` of `1 + 2 ^ -23` and `1 - 2 ^ -23` under oracle number 0, then its `fadd` of `-1` and that
product with the recorded factors under oracle number 2, gives the scalar of `-2 ^ -46`
(`0xa8800000`), the fused result. -/
theorem dot_step_inst :
    (floatBin .float .fmul { contract := true } (.ofFloat .float (f32 0x3f800001))
        (.ofFloat .float (f32 0x3f7ffffe)) none none 0 >>= fun p =>
      floatBin .float .fadd { contract := true } (.ofFloat .float (f32 0xbf800000)) p none
        (some (.ofFloat .float (f32 0x3f800001), .ofFloat .float (f32 0x3f7ffffe))) 2) =
      .ok (.ofFloat .float (f32 0xa8800000)) := by
  have e : dotStep true (f32 0xbf800000) (f32 0x3f800001, f32 0x3f7ffffe) (0, 2) =
      f32 0xa8800000 := by
    decide +kernel
  rw [← e]
  exact floatBin_dotStep (t := .float) (fm := { contract := true }) rfl rfl rfl
    (f32 0xbf800000) (f32 0x3f800001) (f32 0x3f7ffffe) 0 2

end MojoProofTest.Dot
