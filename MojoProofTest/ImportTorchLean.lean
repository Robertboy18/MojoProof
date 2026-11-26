import MojoProof.Import.TorchLean

/-!
# The TorchLean importer at 2 × 3, 3 × 5 and 2 × 2

`MojoProof.Import.torchLean` relates TorchLean's matrix-vector and vector-matrix contractions to
`GPUProof.Spec.matVec` and `GPUProof.Spec.vecMat`. Here both sides of its `eq` are evaluated at
concrete tensors built with TorchLean's `Tensor.Rep.ofFn`: the left side through TorchLean's own
lemmas on the contraction (`Tensor.getScalar_contract_matVec` and
`Tensor.getScalar_contract_vecMat`, folds over `List.finRange`, after
`MojoProof.Import.readOut_getScalar` or `entry_getScalar`), the right side through Mathlib's
`Matrix.mulVec` and `Matrix.vecMul` (each a `Finset.sum`), after `readIn_get2` and
`readIn_vecMat_get2` (TorchLean's `get2` and `getScalar`). The reals do not compute, so neither
side is run: each is rewritten by the simp or norm_num tactic, and the kernel checks every step.

* `out23`, `spec23`: at 2 × 3, the matrix with rows `1 2 3`, `4 5 6` and the vector `1 2 3`,
  TorchLean's contraction read through `readOut` and the spec's function at the inputs read
  through `readIn` are both `14 32`; `eq23` is `eq` at these tensors;
* `out35`, `spec35`: at 3 × 5, the matrix with entries `1` to `15` row by row and the vector
  `1` to `5`, both sides are `55 130 205`;
* `mutant_transposed`: at 2 × 2, the matrix with rows `1 2`, `3 4` and the vector `1 0`, the
  reading of the matrix transposed would break `eq`: TorchLean's contraction is `1 3`, the spec's
  function at the transposed reading `1 2`;
* `outv23`, `specv23`, `eqv23`: `.vecMat` at 2 × 3, the vector `1 2` and the matrix of `out23`,
  both sides `9 12 15`;
* `vecMat35`: `.vecMat` at 3 × 5, the vector `1 2 3` and the matrix of `out35`, both sides
  `46 52 58 64 70`;
* `vecMat22`: `.vecMat` at 2 × 2, the vector `1 0` and the matrix of `mutant_transposed`, both
  sides `1 2`, where the matrix-vector product is `1 3` (`mutant_transposed`), so proposing
  `GPUProof.Spec.matVec` for `.vecMat` would break `eq`;
* `mutant_vecMat_transposed`: at the same tensors, `GPUProof.Spec.vecMat`'s function at the
  reading of the matrix transposed is `1 3`, so that reading would break `eq`;
* `translate_vecMat`: `translate` proposes `GPUProof.Spec.vecMat` at `.vecMat`;
* `cell_spec`: in every format and at every size, the exact sum of the products of the real values
  of `MojoProof.Sem.matVecPairs A v i` is `GPUProof.Spec.matVec`'s function at the words' real
  values, from `eq` through `readOut_map` and `readIn_map`.

Tests at 2 × 3, 3 × 5 and 2 × 2, for every pair of grades `g`, `gv`; `torchLean`'s `eq` is for
every size.
-/

namespace MojoProofTest.ImportTorchLean

open TorchLean MojoProof.Import

variable (g : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
  (mono : ∀ σ E A, Monotone (g σ E A))
  (gv : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
  (monov : ∀ σ E A, Monotone (gv σ E A))

/-- The 2 × 3 matrix with rows `1 2 3` and `4 5 6`. A test tensor. -/
noncomputable def A23 : Tensor ℝ [2, 3] :=
  Tensor.Rep.ofFn fun c => 3 * (c.1 : ℕ) + (c.2.1 : ℕ) + 1

/-- The vector `1 2 3`. A test tensor. -/
noncomputable def x3 : Tensor ℝ [3] :=
  Tensor.Rep.ofFn fun c => (c.1 : ℕ) + 1

/-- The 3 × 5 matrix with entries `1` to `15`, row by row. A test tensor. -/
noncomputable def A35 : Tensor ℝ [3, 5] :=
  Tensor.Rep.ofFn fun c => 5 * (c.1 : ℕ) + (c.2.1 : ℕ) + 1

/-- The vector `1 2 3 4 5`. A test tensor. -/
noncomputable def x5 : Tensor ℝ [5] :=
  Tensor.Rep.ofFn fun c => (c.1 : ℕ) + 1

/-- The vector `1 2`. A test tensor. -/
noncomputable def y2 : Tensor ℝ [2] :=
  Tensor.Rep.ofFn fun c => (c.1 : ℕ) + 1

/-- The 2 × 2 matrix with rows `1 2` and `3 4`. A test tensor. -/
noncomputable def A22 : Tensor ℝ [2, 2] :=
  Tensor.Rep.ofFn fun c => 2 * (c.1 : ℕ) + (c.2.1 : ℕ) + 1

/-- The vector `1 0`. A test tensor. -/
noncomputable def x2 : Tensor ℝ [2] :=
  Tensor.Rep.ofFn fun c => if (c.1 : ℕ) = 0 then 1 else 0

/-- **TorchLean's side at 2 × 3** (test at 2 × 3): TorchLean's contraction of `A23` and `x3`,
read through the importer's `readOut`, is `14 32`. By `readOut_getScalar`, TorchLean's
`Tensor.getScalar_contract_matVec` and `simp`, `norm_num`. -/
theorem out23 : (torchLean g mono gv monov).readOut .matVec _ rfl (2, 3)
    ((torchLean g mono gv monov).denote .matVec (2, 3) (A23, x3)) = (![14, 32] : Fin 2 → ℝ) := by
  have hr : List.finRange 3 = [0, 1, 2] := by decide
  refine (readOut_getScalar g mono gv monov (2, 3) _).trans ?_
  refine funext fun (i : Fin 2) => ?_
  show (Tensor.contract A23 x3 _ _ [2] .matVec).getScalar i = _
  rw [Tensor.getScalar_contract_matVec, hr]
  fin_cases i <;> simp [A23, x3, Tensor.get2] <;> norm_num

/-- **The spec's side at 2 × 3** (test at 2 × 3): `GPUProof.Spec.matVec`'s function at `A23` and
`x3` read through the importer's `readIn` is `14 32`. By `readIn_get2`, Mathlib's
`Matrix.mulVec`, `Fin.sum_univ_succ` and `norm_num`. -/
theorem spec23 : (GPUProof.Spec.matVec g mono).f (2, 3)
    ((torchLean g mono gv monov).readIn .matVec _ rfl (2, 3) (A23, x3)) =
      (![14, 32] : Fin 2 → ℝ) := by
  refine (congrArg ((GPUProof.Spec.matVec g mono).f (2, 3))
    (readIn_get2 g mono gv monov (2, 3) A23 x3)).trans ?_
  refine funext fun (i : Fin 2) => ?_
  show Matrix.mulVec (Matrix.of fun i k => Tensor.get2 A23 i k) (fun k => x3.getScalar k) i = _
  fin_cases i <;> simp [Matrix.mulVec, dotProduct, Fin.sum_univ_succ, Tensor.get2, A23, x3] <;>
    norm_num

/-- **`eq` at 2 × 3** (test at 2 × 3): the importer's `eq` at `A23` and `x3`, whose two sides
are `out23`'s and `spec23`'s. -/
theorem eq23 : (torchLean g mono gv monov).readOut .matVec _ rfl (2, 3)
    ((torchLean g mono gv monov).denote .matVec (2, 3) (A23, x3)) =
      (GPUProof.Spec.matVec g mono).f (2, 3)
        ((torchLean g mono gv monov).readIn .matVec _ rfl (2, 3) (A23, x3)) :=
  (torchLean g mono gv monov).eq .matVec _ rfl (2, 3) (A23, x3) trivial

/-- **TorchLean's side at 3 × 5** (test at 3 × 5): TorchLean's contraction of `A35` and `x5`,
read through the importer's `readOut`, is `55 130 205`. By `readOut_getScalar`,
TorchLean's `Tensor.getScalar_contract_matVec` and `simp`, `norm_num`. -/
theorem out35 : (torchLean g mono gv monov).readOut .matVec _ rfl (3, 5)
    ((torchLean g mono gv monov).denote .matVec (3, 5) (A35, x5)) =
      (![55, 130, 205] : Fin 3 → ℝ) := by
  have hr : List.finRange 5 = [0, 1, 2, 3, 4] := by decide
  refine (readOut_getScalar g mono gv monov (3, 5) _).trans ?_
  refine funext fun (i : Fin 3) => ?_
  show (Tensor.contract A35 x5 _ _ [3] .matVec).getScalar i = _
  rw [Tensor.getScalar_contract_matVec, hr]
  fin_cases i <;> simp [A35, x5, Tensor.get2] <;> norm_num

/-- **The spec's side at 3 × 5** (test at 3 × 5): `GPUProof.Spec.matVec`'s function at `A35` and
`x5` read through the importer's `readIn` is `55 130 205`. By `readIn_get2`, Mathlib's
`Matrix.mulVec`, `Fin.sum_univ_succ` and `norm_num`. -/
theorem spec35 : (GPUProof.Spec.matVec g mono).f (3, 5)
    ((torchLean g mono gv monov).readIn .matVec _ rfl (3, 5) (A35, x5)) =
      (![55, 130, 205] : Fin 3 → ℝ) := by
  refine (congrArg ((GPUProof.Spec.matVec g mono).f (3, 5))
    (readIn_get2 g mono gv monov (3, 5) A35 x5)).trans ?_
  refine funext fun (i : Fin 3) => ?_
  show Matrix.mulVec (Matrix.of fun i k => Tensor.get2 A35 i k) (fun k => x5.getScalar k) i = _
  fin_cases i <;> simp [Matrix.mulVec, dotProduct, Fin.sum_univ_succ, Tensor.get2, A35, x5] <;>
    norm_num

/-- **Mutant: the matrix read transposed** (test at 2 × 2): at `A22` and `x2`, TorchLean's
contraction read through `readOut` is `1 3`, and `GPUProof.Spec.matVec`'s function at the reading
that takes input `inl (i, k)` from the matrix's entry `(k, i)` is `1 2`. So an importer with the
transposed `readIn` has no `eq`. By TorchLean's `Tensor.getScalar_contract_matVec`, Mathlib's
`Matrix.mulVec` and `norm_num`. -/
theorem mutant_transposed :
    (torchLean g mono gv monov).readOut .matVec _ rfl (2, 2)
        ((torchLean g mono gv monov).denote .matVec (2, 2) (A22, x2)) = (![1, 3] : Fin 2 → ℝ) ∧
      (GPUProof.Spec.matVec g mono).f (2, 2)
        (Sum.elim (fun ik => Tensor.get2 A22 ik.2 ik.1) fun k => x2.getScalar k) =
          (![1, 2] : Fin 2 → ℝ) := by
  have hr : List.finRange 2 = [0, 1] := by decide
  constructor
  · refine funext fun (i : Fin 2) => ?_
    show entry (Tensor.contract A22 x2 _ _ [2] .matVec) (i, ()) = _
    rw [entry_getScalar, Tensor.getScalar_contract_matVec, hr]
    fin_cases i <;> norm_num [A22, x2, Tensor.get2]
  · refine funext fun (i : Fin 2) => ?_
    show Matrix.mulVec (Matrix.of fun i k => Tensor.get2 A22 k i) (fun k => x2.getScalar k) i = _
    fin_cases i <;> norm_num [Matrix.mulVec, dotProduct, Tensor.get2, A22, x2]

/-- **TorchLean's side of `.vecMat` at 2 × 3** (test at 2 × 3): TorchLean's vector-matrix
contraction of `y2` and `A23`, read through the importer's `readOut`, is `9 12 15`. By
`readOut_vecMat`, `entry_getScalar`, TorchLean's `Tensor.getScalar_contract_vecMat` and `simp`,
`norm_num`. -/
theorem outv23 : (torchLean g mono gv monov).readOut .vecMat _ rfl (2, 3)
    ((torchLean g mono gv monov).denote .vecMat (2, 3) (y2, A23)) =
      (![9, 12, 15] : Fin 3 → ℝ) := by
  have hr : List.finRange 2 = [0, 1] := by decide
  refine funext fun (j : Fin 3) =>
    (congrFun (readOut_vecMat g mono gv monov (2, 3) _) j).trans ?_
  show entry (Tensor.contract y2 A23 _ _ [3] .vecMat) (j, ()) = _
  rw [entry_getScalar, Tensor.getScalar_contract_vecMat, hr]
  fin_cases j <;> simp [A23, y2, Tensor.get2] <;> norm_num

/-- **The spec's side of `.vecMat` at 2 × 3** (test at 2 × 3): `GPUProof.Spec.vecMat`'s function
at `y2` and `A23` read through the importer's `readIn` is `9 12 15`. By `readIn_vecMat_get2`,
Mathlib's `Matrix.vecMul`, `Fin.sum_univ_succ` and `norm_num`. -/
theorem specv23 : (GPUProof.Spec.vecMat gv monov).f (2, 3)
    ((torchLean g mono gv monov).readIn .vecMat _ rfl (2, 3) (y2, A23)) =
      (![9, 12, 15] : Fin 3 → ℝ) := by
  refine (congrArg ((GPUProof.Spec.vecMat gv monov).f (2, 3))
    (readIn_vecMat_get2 g mono gv monov (2, 3) y2 A23)).trans ?_
  refine funext fun (j : Fin 3) => ?_
  show Matrix.vecMul (fun i => y2.getScalar i) (Matrix.of fun i j => Tensor.get2 A23 i j) j = _
  fin_cases j <;> simp [Matrix.vecMul, dotProduct, Fin.sum_univ_succ, Tensor.get2, A23, y2] <;>
    norm_num

/-- **`eq` at `.vecMat` and 2 × 3** (test at 2 × 3): the importer's `eq` at `y2` and `A23`,
whose two sides are `outv23`'s and `specv23`'s. -/
theorem eqv23 : (torchLean g mono gv monov).readOut .vecMat _ rfl (2, 3)
    ((torchLean g mono gv monov).denote .vecMat (2, 3) (y2, A23)) =
      (GPUProof.Spec.vecMat gv monov).f (2, 3)
        ((torchLean g mono gv monov).readIn .vecMat _ rfl (2, 3) (y2, A23)) :=
  (torchLean g mono gv monov).eq .vecMat _ rfl (2, 3) (y2, A23) trivial

/-- **Both sides of `.vecMat` at 3 × 5** (test at 3 × 5): at `x3` and `A35`, TorchLean's
vector-matrix contraction read through `readOut` and `GPUProof.Spec.vecMat`'s function at the
inputs read through `readIn` are both `46 52 58 64 70`. By `entry_getScalar`,
`readIn_vecMat_get2`, TorchLean's `Tensor.getScalar_contract_vecMat`, Mathlib's `Matrix.vecMul`
and `norm_num`. -/
theorem vecMat35 :
    (torchLean g mono gv monov).readOut .vecMat _ rfl (3, 5)
        ((torchLean g mono gv monov).denote .vecMat (3, 5) (x3, A35)) =
        (![46, 52, 58, 64, 70] : Fin 5 → ℝ) ∧
      (GPUProof.Spec.vecMat gv monov).f (3, 5)
        ((torchLean g mono gv monov).readIn .vecMat _ rfl (3, 5) (x3, A35)) =
        (![46, 52, 58, 64, 70] : Fin 5 → ℝ) := by
  have hr : List.finRange 3 = [0, 1, 2] := by decide
  constructor
  · refine funext fun (j : Fin 5) => ?_
    show entry (Tensor.contract x3 A35 _ _ [5] .vecMat) (j, ()) = _
    rw [entry_getScalar, Tensor.getScalar_contract_vecMat, hr]
    fin_cases j <;> simp [A35, x3, Tensor.get2] <;> norm_num
  · refine (congrArg ((GPUProof.Spec.vecMat gv monov).f (3, 5))
      (readIn_vecMat_get2 g mono gv monov (3, 5) x3 A35)).trans ?_
    refine funext fun (j : Fin 5) => ?_
    show Matrix.vecMul (fun i => x3.getScalar i) (Matrix.of fun i j => Tensor.get2 A35 i j) j = _
    fin_cases j <;> simp [Matrix.vecMul, dotProduct, Fin.sum_univ_succ, Tensor.get2, A35, x3] <;>
      norm_num

/-- **`.vecMat` at 2 × 2** (test at 2 × 2): at `x2` and `A22`, TorchLean's vector-matrix
contraction read through `readOut` is `1 2`, and so is `GPUProof.Spec.vecMat`'s function at the
inputs read through `readIn`. The matrix-vector product at the same tensors is `1 3`
(`mutant_transposed`), so a `translate` proposing `GPUProof.Spec.matVec` for `.vecMat` would
have no `eq`. By `entry_getScalar`, `readIn_vecMat_get2`,
TorchLean's `Tensor.getScalar_contract_vecMat`, Mathlib's `Matrix.vecMul` and `norm_num`. -/
theorem vecMat22 :
    (torchLean g mono gv monov).readOut .vecMat _ rfl (2, 2)
        ((torchLean g mono gv monov).denote .vecMat (2, 2) (x2, A22)) = (![1, 2] : Fin 2 → ℝ) ∧
      (GPUProof.Spec.vecMat gv monov).f (2, 2)
        ((torchLean g mono gv monov).readIn .vecMat _ rfl (2, 2) (x2, A22)) =
          (![1, 2] : Fin 2 → ℝ) := by
  have hr : List.finRange 2 = [0, 1] := by decide
  constructor
  · refine funext fun (j : Fin 2) => ?_
    show entry (Tensor.contract x2 A22 _ _ [2] .vecMat) (j, ()) = _
    rw [entry_getScalar, Tensor.getScalar_contract_vecMat, hr]
    fin_cases j <;> norm_num [A22, x2, Tensor.get2]
  · refine (congrArg ((GPUProof.Spec.vecMat gv monov).f (2, 2))
      (readIn_vecMat_get2 g mono gv monov (2, 2) x2 A22)).trans ?_
    refine funext fun (j : Fin 2) => ?_
    show Matrix.vecMul (fun i => x2.getScalar i) (Matrix.of fun i j => Tensor.get2 A22 i j) j = _
    fin_cases j <;> norm_num [Matrix.vecMul, dotProduct, Tensor.get2, A22, x2]

/-- **Mutant: the matrix of `.vecMat` read transposed** (test at 2 × 2): at `x2` and `A22`,
`GPUProof.Spec.vecMat`'s function at the reading that takes input `inr (i, j)` from the matrix's
entry `(j, i)` is `1 3`, not TorchLean's `1 2` (`vecMat22`). So an importer with the transposed
`readIn` at `.vecMat` has no `eq`. By Mathlib's `Matrix.vecMul` and `norm_num`. -/
theorem mutant_vecMat_transposed :
    (GPUProof.Spec.vecMat gv monov).f (2, 2)
        (Sum.elim (fun i => x2.getScalar i) fun ij => Tensor.get2 A22 ij.2 ij.1) =
      (![1, 3] : Fin 2 → ℝ) := by
  refine funext fun (j : Fin 2) => ?_
  show Matrix.vecMul (fun i => x2.getScalar i) (Matrix.of fun i j => Tensor.get2 A22 j i) j = _
  fin_cases j <;> norm_num [Matrix.vecMul, dotProduct, Tensor.get2, A22, x2]

/-- **The importer proposes `GPUProof.Spec.vecMat` for `.vecMat`** (test, for every pair of
grades): `translate` at TorchLean's vector-matrix contraction is `GPUProof.Spec.vecMat gv`. By
`rfl`. -/
theorem translate_vecMat :
    (torchLean g mono gv monov).translate .vecMat = some (GPUProof.Spec.vecMat gv monov) := rfl

open FloatLib.Floats.Formats.BinaryInterchange in
include gv monov in
/-- **The exact gemv cell is the spec's function at the words' real values** (test, for every
grade `g`, format `fmt`, size `σ`, matrix `A`, vector `v` of words of `fmt` and row `i`, with the
importer at any grade `gv` of `.vecMat`): the sum of the products of the real values of
`MojoProof.Sem.matVecPairs A v i` is `GPUProof.Spec.matVec`'s function, at `i`, at the inputs
whose entry `inl (i, k)` is the real value of `Tensor.get2 A i k` and `inr k` that of
`v.getScalar k`. The importer's `eq` at the maps of `A` and `v` by `Model.toReal`, read through
`readOut_map` and `readIn_map`. -/
theorem cell_spec {fmt : FloatFormat} (σ : ℕ × ℕ) (A : Tensor (Model fmt) [σ.1, σ.2])
    (v : Tensor (Model fmt) [σ.2]) (i : Fin σ.1) :
    ((MojoProof.Sem.matVecPairs A v i).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      (GPUProof.Spec.matVec g mono).f σ
        (Sum.elim (fun ik => (Tensor.get2 A ik.1 ik.2).toReal) fun k => (v.getScalar k).toReal)
        i := by
  calc _ = readOut g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
          (TorchOp.denote .matVec σ (Tensor.map Model.toReal A, Tensor.map Model.toReal v)) i :=
        (readOut_map g mono gv monov σ A v i).symm
    _ = (GPUProof.Spec.matVec g mono).f σ
          (readIn g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
            (Tensor.map Model.toReal A, Tensor.map Model.toReal v)) i :=
        congrFun ((torchLean g mono gv monov).eq .matVec (GPUProof.Spec.matVec g mono) rfl σ
          (Tensor.map Model.toReal A, Tensor.map Model.toReal v) trivial) i
    _ = _ := by rw [readIn_map]

end MojoProofTest.ImportTorchLean
