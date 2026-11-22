import MojoProof.Sem.Matmul
import MojoProofTest.FloatRel

/-!
# Instances and twins of the matmul and gemv cells of MojoProof/Sem/Matmul.lean

On binary32, the matrices `mA = [[-1, 1 + 2 ^ -23], [1, 2]]` and `mB = [[1, 1], [1 - 2 ^ -23, 1]]`
and the vector `vB = [1, 1 - 2 ^ -23]`, the first column of `mB`, as TorchLean tensors:

* `matmul_vals`: TorchLean's `Tensor.matmul mA mB` is `[[+0, 2 ^ -23], [3 - 2 ^ -22, 3]]`, by
  evaluating TorchLean's definition in the kernel. Entry `(0, 0)` is `+0` because the rounded
  product `(1 + 2 ^ -23) (1 - 2 ^ -23)` is 1.
* `matmul_cell_inst`, the instance of `matmul_cell_eq`: the loop over `matmulPairs mA mB 0 0`
  without the `contract` flag (oracle numbers `(0, 0)`), and with it under the oracle numbers
  `(0, 1)`, is TorchLean's entry.
* `matmul_cell_twin`, the twin of the premise that no `fadd` oracle number is 2 modulo 3: under
  the oracle numbers `(0, 2)` every iteration is fused, the last `fma` is exact, and the loop
  gives `-2 ^ -46`, which is not TorchLean's `+0`.
* `matmul_error_inst`, the instance of `matmul_cell_error`: that fused word is finite, so it is
  within `dotBound .binary32 2 T` of entry `(0, 0)` of TorchLean's real matmul.
* `matmul_real_inst`, the instance of `matmul_cell_real`: that real entry is `-2 ^ -46`, the
  exact sum, so the fused word is exact and TorchLean's binary32 `+0` is `2 ^ -46` from it.
* `matVec_vals`, `matVec_cell_inst`: TorchLean's `contract mA vB _ _ [2] .matVec` is
  `[+0, 3 - 2 ^ -22]`, by evaluating TorchLean's definition in the kernel, and the loop without
  the `contract` flag over `matVecPairs mA vB 1` is its entry 1 (`matVec_cell_eq`); that word is
  finite, so it is within `dotBound .binary32 2 T` of entry 1 of the real product
  (`matVec_error_inst`, the instance of `matVec_cell_error`).
-/

namespace MojoProofTest.Matmul

open MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange TorchLean
open MojoProofTest.FloatRel (f32)

/-- The binary32 matrix `[[-1, 1 + 2 ^ -23], [1, 2]]` (words `0xbf800000`, `0x3f800001`,
`0x3f800000`, `0x40000000`), as a TorchLean tensor of shape `[2, 2]`. -/
def mA : Tensor (Model .binary32) [2, 2] :=
  Tensor.Rep.ofFn fun c =>
    ![![f32 0xbf800000, f32 0x3f800001], ![f32 0x3f800000, f32 0x40000000]] c.1 c.2.1

/-- The binary32 matrix `[[1, 1], [1 - 2 ^ -23, 1]]` (words `0x3f800000`, `0x3f800000`,
`0x3f7ffffe`, `0x3f800000`), as a TorchLean tensor of shape `[2, 2]`. -/
def mB : Tensor (Model .binary32) [2, 2] :=
  Tensor.Rep.ofFn fun c =>
    ![![f32 0x3f800000, f32 0x3f800000], ![f32 0x3f7ffffe, f32 0x3f800000]] c.1 c.2.1

/-- The binary32 vector `[1, 1 - 2 ^ -23]` (words `0x3f800000`, `0x3f7ffffe`), the first column
of `mB`, as a TorchLean tensor of shape `[2]`. -/
def vB : Tensor (Model .binary32) [2] :=
  Tensor.Rep.ofFn fun c => ![f32 0x3f800000, f32 0x3f7ffffe] c.1

/-- **TorchLean's binary32 product of `mA` and `mB`**: `Tensor.matmul mA mB` is
`[[+0, 2 ^ -23], [3 - 2 ^ -22, 3]]` (words `0`, `0x34000000`, `0x403fffff`, `0x40400000`): the
kernel evaluates `Tensor.matmul mA mB` at each coordinate (`decide +kernel`). -/
theorem matmul_vals :
    Tensor.get2 (Tensor.matmul mA mB) 0 0 = f32 0 ∧
      Tensor.get2 (Tensor.matmul mA mB) 0 1 = f32 0x34000000 ∧
      Tensor.get2 (Tensor.matmul mA mB) 1 0 = f32 0x403fffff ∧
      Tensor.get2 (Tensor.matmul mA mB) 1 1 = f32 0x40400000 := by
  simp only [Tensor.get2_eq_apply, mA, mB]
  decide +kernel

/-- **The instance of `matmul_cell_eq`**: entry `(0, 0)` of TorchLean's `Tensor.matmul mA mB` is
not a NaN, so the loop over `matmulPairs mA mB 0 0` from `+0` without the `contract` flag
(oracle numbers `(0, 0)`), and with it under the oracle numbers `(0, 1)`, is that entry. -/
theorem matmul_cell_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        Tensor.get2 (Tensor.matmul mA mB) 0 0 ∧
      dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        Tensor.get2 (Tensor.matmul mA mB) 0 0 := by
  have hn : (Tensor.get2 (Tensor.matmul mA mB) 0 0).isNaN = false := by
    rw [matmul_vals.1]
    decide +kernel
  exact ⟨(matmul_cell_eq false _ mA mB 0 0 (fun _ _ => by simp)).1 hn,
    (matmul_cell_eq true _ mA mB 0 0 (fun _ _ => by simp)).1 hn⟩

/-- **The twin of `matmul_cell_eq`'s premise** that no `fadd` oracle number is 2 modulo 3 when
the `contract` flag is set: with the `contract` flag under the oracle numbers `(0, 2)`, the loop
over `matmulPairs mA mB 0 0` from `+0` gives `-2 ^ -46` (`0xa8800000`), by evaluation, and that
word is not TorchLean's entry `(0, 0)` of `Tensor.matmul mA mB`, which is `+0`. -/
theorem matmul_cell_twin :
    dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        f32 0xa8800000 ∧
      dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) ≠
        Tensor.get2 (Tensor.matmul mA mB) 0 0 := by
  have h : dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
      f32 0xa8800000 := by
    simp only [matmulPairs, Tensor.get2_eq_apply, mA, mB, Tensor.Rep.get_ofFn]
    decide +kernel
  refine ⟨h, ?_⟩
  rw [h, matmul_vals.1]
  decide +kernel

/-- **The instance of `matmul_cell_error`**: the fused loop of `matmul_cell_twin` gives a finite
word, so it is within `dotBound .binary32 2 T` of entry `(0, 0)` of TorchLean's `Tensor.matmul`
over `ℝ` of `mA` and `mB` mapped by `Model.toReal`, with `T` the sum of the absolute products. -/
theorem matmul_error_inst :
    |(dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false)
          (matmulPairs mA mB 0 0)).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal mA) (Tensor.map Model.toReal mB))
          0 0| ≤
      dotBound .binary32 2
        ((matmulPairs mA mB 0 0).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  matmul_cell_error rfl true _ mA mB 0 0 (by rw [matmul_cell_twin.1]; decide +kernel)

/-- **The instance of `matmul_cell_real`**: entry `(0, 0)` of TorchLean's `Tensor.matmul` over
`ℝ` of `mA` and `mB` mapped by `Model.toReal` is the exact sum
`-1 · 1 + (1 + 2 ^ -23) (1 - 2 ^ -23) = -2 ^ -46`, the real value of the fused word of
`matmul_cell_twin`; TorchLean's binary32 entry `+0` is `2 ^ -46` from it. -/
theorem matmul_real_inst :
    Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal mA) (Tensor.map Model.toReal mB)) 0 0 =
      -(1 / 2 ^ 46) := by
  rw [← matmul_cell_real]
  have e : matmulPairs mA mB 0 0 =
      [(f32 0xbf800000, f32 0x3f800000), (f32 0x3f800001, f32 0x3f7ffffe)] := by
    simp only [matmulPairs, Tensor.get2_eq_apply, mA, mB, Tensor.Rep.get_ofFn]
    decide +kernel
  have h : (f32 0xbf800000).toRat? = some (-1) ∧ (f32 0x3f800000).toRat? = some 1 ∧
      (f32 0x3f800001).toRat? = some (1 + 1 / 8388608) ∧
      (f32 0x3f7ffffe).toRat? = some (1 - 1 / 8388608) := by
    decide +kernel
  obtain ⟨h1, h2, h3, h4⟩ := h
  rw [e]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    Model.Algebraic.toReal_of_toRat?_eq_some h1, Model.Algebraic.toReal_of_toRat?_eq_some h2,
    Model.Algebraic.toReal_of_toRat?_eq_some h3, Model.Algebraic.toReal_of_toRat?_eq_some h4]
  norm_num

/-- **TorchLean's binary32 product of `mA` and `vB`**: `contract mA vB _ _ [2] .matVec` is
`[+0, 3 - 2 ^ -22]` (words `0` and `0x403fffff`), the first column of `Tensor.matmul mA mB`: the
kernel evaluates the contraction at each coordinate (`decide +kernel`). -/
theorem matVec_vals :
    (Tensor.contract mA vB _ _ [2] .matVec).getScalar 0 = f32 0 ∧
      (Tensor.contract mA vB _ _ [2] .matVec).getScalar 1 = f32 0x403fffff := by
  simp only [Tensor.getScalar_eq_apply, mA, vB]
  decide +kernel

/-- **The instance of `matVec_cell_eq`**: entry 1 of TorchLean's `contract mA vB _ _ [2] .matVec`
is not a NaN, so the loop over `matVecPairs mA vB 1` from `+0` without the `contract` flag
(oracle numbers `(0, 0)`) is that entry, `3 - 2 ^ -22`. -/
theorem matVec_cell_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matVecPairs mA vB 1) =
      (Tensor.contract mA vB _ _ [2] .matVec).getScalar 1 :=
  (matVec_cell_eq false _ mA vB 1 (fun _ _ => by simp)).1 (by rw [matVec_vals.2]; decide +kernel)

/-- **The instance of `matVec_cell_error`**: the loop of `matVec_cell_inst` gives a finite word,
so it is within `dotBound .binary32 2 T` of entry 1 of TorchLean's matrix-vector product over `ℝ`
of `mA` and `vB` mapped by `Model.toReal`, with `T` the sum of the absolute products. -/
theorem matVec_error_inst :
    |(dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matVecPairs mA vB 1)).toReal -
        (Tensor.contract (Tensor.map Model.toReal mA) (Tensor.map Model.toReal vB) _ _ [2]
          .matVec).getScalar 1| ≤
      dotBound .binary32 2 ((matVecPairs mA vB 1).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  matVec_cell_error rfl false _ mA vB 1 (by rw [matVec_cell_inst, matVec_vals.2]; decide +kernel)

end MojoProofTest.Matmul
