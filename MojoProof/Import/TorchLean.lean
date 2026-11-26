import GPUProof.Spec.Import
import GPUProof.Spec.Linear
import MojoProof.Import.Command
import MojoProof.Sem.Matmul
import TorchLean.NN.FDeriv.TensorVectorization
import TorchLean.Tensor.LinearAlgebra.Real

/-!
# The TorchLean importer for the matrix-vector and vector-matrix products

`GPUProof.Importer`'s instance for TorchLean at the matrix-vector and vector-matrix products
(`torchLean`). Its operations (`TorchOp`) are TorchLean's tensor contractions `.matVec` and
`.vecMat`, each at the sizes `(m, n)`; their meaning (`TorchOp.denote`) is
`TorchLean.Tensor.contract` at the reals, on an `m × n` matrix and a vector of length `n`
(`.matVec`, output of length `m`) or on a vector of length `m` and an `m × n` matrix (`.vecMat`,
output of length `n`). `translate` proposes `GPUProof.Spec.matVec` for `.matVec` and
`GPUProof.Spec.vecMat` for `.vecMat`, each at a grade the importer takes (`TorchOp.translate`).

The tensors are read through TorchLean's flattening `Tensor.toVecₗᵢ`, a linear isometry onto
Euclidean space, at the row-major index of each coordinate (`entry`), which is the tensor's value
there (`entry_eq`). At `.matVec` the spec's input `inl (i, k)` is the matrix's entry `(i, k)` and
`inr k` the vector's entry `k`; at `.vecMat` input `inl i` is the vector's entry `i` and
`inr (i, j)` the matrix's entry `(i, j)`; output `i` is the result's entry `i` (`readIn`,
`readOut`).

* `matVec_eq`: for every shape `m`, `n`, matrix `A` and vector `x`, entry `i` of TorchLean's
  contraction `.matVec` of `A` and `x`, read through `toVecₗᵢ`, is entry `i` of Mathlib's
  `Matrix.mulVec` of `A` and `x` read the same way (by `entry_eq` and TorchLean's
  `Tensor.getScalar_contract_matVec_eq_mulVec`);
* `vecMat_eq`: the same for `.vecMat` and Mathlib's `Matrix.vecMul` (by `entry_eq` and
  TorchLean's `Tensor.getScalar_contract_vecMat_eq_sum`);
* `torchLean`: the importer, declared with the operations, their tensors, meaning and proposed
  specs, `readIn`, `readOut` and their unfoldings (readIn_matVec, readIn_vecMat,
  readOut_matVec, readOut_vecMat) by one `import_spec` command, whose `eq` is
  closed by `matVec_eq` at `.matVec` and `vecMat_eq` at `.vecMat`, found by their types.

`MojoProof.Sem.matVecPairs` reads the same tensors at words through TorchLean's `Tensor.get2` and
`Tensor.getScalar`. The two readings agree, in every format and at every size:

* `entry_get2`, `entry_getScalar`: `entry` is `get2` on real matrices and `getScalar` on real
  vectors, so `readIn` and `readOut` at `.matVec` and `readIn` at `.vecMat` are TorchLean's
  `get2`/`getScalar` reading (`readIn_get2`, `readOut_getScalar`, `readIn_vecMat_get2`);
* `entry_map_get2`, `entry_map_getScalar`: `entry` of TorchLean's `Tensor.map Model.toReal` of a
  tensor of words is the real value of the word `get2` or `getScalar` reads;
* `readIn_map`, `readOut_map`: at the maps by `Model.toReal` of a matrix `A` and a vector `v` of
  words, `readIn` is the real values of the words of `matVecPairs A v`'s pairs, and `readOut` of
  TorchLean's contraction at `i` is the exact sum of the products of `matVecPairs A v i`
  (`MojoProof.Sem.matVec_cell_real`).

docs/proofs/import.md gives the departures from the design and the command's design.
-/

namespace MojoProof.Import

open TorchLean FloatLib.Floats.Formats.BinaryInterchange

/-- Entry `c` of a real TorchLean tensor of shape `s`, for every shape: the tensor's flattening
`TorchLean.Tensor.toVecₗᵢ s` at `c`'s row-major index (`TorchLean.Shape.Coord.equivFin s`). -/
noncomputable def entry {s : Shape} (t : Tensor ℝ s) (c : Shape.Coord s) : ℝ :=
  Tensor.toVecₗᵢ s t (Shape.Coord.equivFin s c)

/-- The flattening read at a coordinate's row-major index is the tensor's value at the
coordinate, for every shape, real tensor and coordinate. By TorchLean's `toVec_apply`. -/
theorem entry_eq {s : Shape} (t : Tensor ℝ s) (c : Shape.Coord s) : entry t c = t c := by
  simp [entry, toVec_apply]

/-- **`entry` is TorchLean's `get2` on matrices**, for every shape `m`, `n`, real `m × n` matrix
`A`, row `i` and column `k`: `entry A (i, k, ())` is `Tensor.get2 A i k`, the reading of
`MojoProof.Sem.matVecPairs`. By `entry_eq` and TorchLean's `Tensor.get2_eq_apply`. -/
theorem entry_get2 {m n : ℕ} (A : Tensor ℝ [m, n]) (i : Fin m) (k : Fin n) :
    entry A (i, k, ()) = Tensor.get2 A i k := by
  rw [entry_eq, Tensor.get2_eq_apply]

/-- **`entry` is TorchLean's `getScalar` on vectors**, for every length `n`, real vector `x` and
index `k`: `entry x (k, ())` is `x.getScalar k`, the reading of `MojoProof.Sem.matVecPairs`. By
`entry_eq` and TorchLean's `Tensor.getScalar_eq_apply`. -/
theorem entry_getScalar {n : ℕ} (x : Tensor ℝ [n]) (k : Fin n) :
    entry x (k, ()) = x.getScalar k := by
  rw [entry_eq, Tensor.getScalar_eq_apply]

/-- **`entry` of the real values of a matrix of words is the real value of its `get2`**, in every
format `fmt`, for every shape `m`, `n`, matrix `A` (`m × n`) of words of `fmt`, row `i` and column
`k`: `entry` of TorchLean's `Tensor.map Model.toReal A` at `(i, k)` is the real value of
`Tensor.get2 A i k`, the word `MojoProof.Sem.matVecPairs A v i` pairs at `k`. By `entry_get2` and
TorchLean's `Tensor.unstack_map`, `Tensor.getScalar_map`. -/
theorem entry_map_get2 {fmt : FloatFormat} {m n : ℕ} (A : Tensor (Model fmt) [m, n]) (i : Fin m)
    (k : Fin n) : entry (Tensor.map Model.toReal A) (i, k, ()) = (Tensor.get2 A i k).toReal := by
  rw [entry_get2]
  simp only [Tensor.get2, Tensor.unstack_map, Tensor.getScalar_map]

/-- **`entry` of the real values of a vector of words is the real value of its `getScalar`**, in
every format `fmt`, for every length `n`, vector `v` of words of `fmt` and index `k`: `entry` of
TorchLean's `Tensor.map Model.toReal v` at `k` is the real value of `v.getScalar k`, the word
`MojoProof.Sem.matVecPairs A v i` pairs at `k`. By `entry_getScalar` and TorchLean's
`Tensor.getScalar_map`. -/
theorem entry_map_getScalar {fmt : FloatFormat} {n : ℕ} (v : Tensor (Model fmt) [n]) (k : Fin n) :
    entry (Tensor.map Model.toReal v) (k, ()) = (v.getScalar k).toReal := by
  rw [entry_getScalar, Tensor.getScalar_map]

/-- **TorchLean's matrix-vector contraction is Mathlib's `Matrix.mulVec`, read through
`toVecₗᵢ`**, for every shape `m`, `n`, real `m × n` matrix `A`, real vector `x` of length `n` and
row `i`: entry `i` of `TorchLean.Tensor.contract A x _ _ [m] .matVec`, read through `entry`, is
entry `i` of `Matrix.mulVec` of the matrix whose entry `(i, k)` is `A`'s, read the same way, and
the vector whose entry `k` is `x`'s. By `entry_eq` and TorchLean's
`Tensor.getScalar_contract_matVec_eq_mulVec`. -/
theorem matVec_eq {m n : ℕ} (A : Tensor ℝ [m, n]) (x : Tensor ℝ [n]) (i : Fin m) :
    entry (Tensor.contract A x _ _ [m] .matVec) (i, ()) =
      Matrix.mulVec (Matrix.of fun i k => entry A (i, k, ())) (fun k => entry x (k, ())) i := by
  simp only [entry_eq]
  have h := congrFun (Tensor.getScalar_contract_matVec_eq_mulVec A x) i
  rw [Tensor.getScalar_eq_apply] at h
  rw [h, show x.getScalar = fun k => x (k, ()) from funext (Tensor.getScalar_eq_apply x)]
  rfl

/-- **TorchLean's vector-matrix contraction is Mathlib's `Matrix.vecMul`, read through
`toVecₗᵢ`**, for every shape `m`, `n`, real vector `x` of length `m`, real `m × n` matrix `A` and
column `j`: entry `j` of `TorchLean.Tensor.contract x A _ _ [n] .vecMat`, read through `entry`, is
entry `j` of `Matrix.vecMul` of the vector whose entry `i` is `x`'s, read the same way, and the
matrix whose entry `(i, j)` is `A`'s. By `entry_getScalar`, `entry_eq` and TorchLean's
`Tensor.getScalar_contract_vecMat_eq_sum`. -/
theorem vecMat_eq {m n : ℕ} (x : Tensor ℝ [m]) (A : Tensor ℝ [m, n]) (j : Fin n) :
    entry (Tensor.contract x A _ _ [n] .vecMat) (j, ()) =
      Matrix.vecMul (fun i => entry x (i, ())) (Matrix.of fun i j => entry A (i, j, ())) j := by
  rw [entry_getScalar, Tensor.getScalar_contract_vecMat_eq_sum]
  simp only [Matrix.vecMul, dotProduct, Matrix.of_apply, entry_eq, Tensor.get2_eq_apply,
    Tensor.getScalar_eq_apply]

variable (g : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
  (mono : ∀ σ E A, Monotone (g σ E A))
  (gv : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
  (monov : ∀ σ E A, Monotone (gv σ E A))

/-- **The TorchLean importer for the matrix-vector and vector-matrix products**, for every grade
`g` of `GPUProof.Spec.matVec` and `gv` of `GPUProof.Spec.vecMat`: the operations `TorchOp` at the
sizes `(m, n)`, TorchLean's contractions as their meaning, `GPUProof.Spec.matVec g` proposed for
`.matVec` and `GPUProof.Spec.vecMat gv` for `.vecMat`, the tensors read through `toVecₗᵢ`
(`readIn`, `readOut`), and `eq` at every size by `matVec_eq` and `vecMat_eq`. -/
import_spec torchLean g mono gv monov : TorchOp (σ : ℕ × ℕ) where
  /-- `TorchLean.Tensor.contract A x _ _ [m] .matVec`. -/
  | matVec (A : Tensor ℝ [σ.1, σ.2]) (x : Tensor ℝ [σ.2]) → (y : Tensor ℝ [σ.1]) :=
      Tensor.contract A x _ _ [σ.1] .matVec
    ↦ GPUProof.Spec.matVec g mono
    from Sum.elim (fun ik => entry A (ik.1, ik.2, ())) fun k => entry x (k, ())
    at fun i => entry y (i, ())
  /-- `TorchLean.Tensor.contract x A _ _ [n] .vecMat`. -/
  | vecMat (x : Tensor ℝ [σ.1]) (A : Tensor ℝ [σ.1, σ.2]) → (y : Tensor ℝ [σ.2]) :=
      Tensor.contract x A _ _ [σ.2] .vecMat
    ↦ GPUProof.Spec.vecMat gv monov
    from Sum.elim (fun i => entry x (i, ())) fun ij => entry A (ij.1, ij.2, ())
    at fun j => entry y (j, ())

/-- **`readIn` at `.matVec` is TorchLean's `get2`/`getScalar` reading**, for every grade, size
`σ`, real matrix `A` and vector `x`: input `inl (i, k)` is `Tensor.get2 A i k` and `inr k` is
`x.getScalar k`, the reading of `MojoProof.Sem.matVecPairs`. By `readIn_matVec`, `entry_get2`
and `entry_getScalar`. -/
theorem readIn_get2 (σ : ℕ × ℕ) (A : Tensor ℝ [σ.1, σ.2]) (x : Tensor ℝ [σ.2]) :
    readIn g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ (A, x) =
      Sum.elim (fun ik => Tensor.get2 A ik.1 ik.2) fun k => x.getScalar k := by
  rw [readIn_matVec]
  funext c
  rcases c with ⟨i, k⟩ | k
  exacts [entry_get2 A i k, entry_getScalar x k]

/-- **`readIn` at `.vecMat` is TorchLean's `getScalar`/`get2` reading**, for every pair of
grades, size `σ`, real vector `x` and matrix `A`: input `inl i` is `x.getScalar i` and
`inr (i, j)` is `Tensor.get2 A i j`. By `readIn_vecMat`, `entry_getScalar` and `entry_get2`. -/
theorem readIn_vecMat_get2 (σ : ℕ × ℕ) (x : Tensor ℝ [σ.1]) (A : Tensor ℝ [σ.1, σ.2]) :
    readIn g mono gv monov .vecMat (GPUProof.Spec.vecMat gv monov) rfl σ (x, A) =
      Sum.elim (fun i => x.getScalar i) fun ij => Tensor.get2 A ij.1 ij.2 := by
  rw [readIn_vecMat]
  funext c
  rcases c with i | ⟨i, j⟩
  exacts [entry_getScalar x i, entry_get2 A i j]

/-- **`readOut` at `.matVec` is TorchLean's `getScalar` reading**, for every grade, size `σ` and
real vector `y`: output `i` is `y.getScalar i`. By `readOut_matVec` and `entry_getScalar`. -/
theorem readOut_getScalar (σ : ℕ × ℕ) (y : Tensor ℝ [σ.1]) :
    readOut g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ y =
      fun i => y.getScalar i := by
  rw [readOut_matVec]
  funext i
  exact entry_getScalar y i

/-- **The importer reads the real values of words as `matVecPairs` reads the words**, for every
grade, format `fmt`, size `σ`, matrix `A` (`σ.1 × σ.2`) and vector `v` (length `σ.2`) of words of
`fmt`: `readIn` at `.matVec` of their maps by `Model.toReal` (TorchLean's `Tensor.map`) takes
input `inl (i, k)` to the real value of `Tensor.get2 A i k` and `inr k` to that of
`v.getScalar k`, the two words of `MojoProof.Sem.matVecPairs A v i`'s pair `k`. By
`readIn_matVec`, `entry_map_get2` and `entry_map_getScalar`. -/
theorem readIn_map {fmt : FloatFormat} (σ : ℕ × ℕ) (A : Tensor (Model fmt) [σ.1, σ.2])
    (v : Tensor (Model fmt) [σ.2]) :
    readIn g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
        (Tensor.map Model.toReal A, Tensor.map Model.toReal v) =
      Sum.elim (fun ik => (Tensor.get2 A ik.1 ik.2).toReal) fun k => (v.getScalar k).toReal := by
  rw [readIn_matVec]
  funext x
  rcases x with ⟨i, k⟩ | k
  exacts [entry_map_get2 A i k, entry_map_getScalar v k]

/-- **The importer's output at the real values of words is the exact `matVecPairs` sum**, for
every grade, format `fmt`, size `σ`, matrix `A` (`σ.1 × σ.2`), vector `v` (length `σ.2`) of words
of `fmt` and row `i`: `readOut` at `.matVec` of TorchLean's contraction of the maps of `A` and `v`
by `Model.toReal` is, at `i`, the sum of the products of the real values of
`MojoProof.Sem.matVecPairs A v i`. By `readOut_matVec`, `entry_getScalar` and
`MojoProof.Sem.matVec_cell_real`. -/
theorem readOut_map {fmt : FloatFormat} (σ : ℕ × ℕ) (A : Tensor (Model fmt) [σ.1, σ.2])
    (v : Tensor (Model fmt) [σ.2]) (i : Fin σ.1) :
    readOut g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
        (TorchOp.denote .matVec σ (Tensor.map Model.toReal A, Tensor.map Model.toReal v)) i =
      ((MojoProof.Sem.matVecPairs A v i).map fun ab => ab.1.toReal * ab.2.toReal).sum := by
  rw [readOut_matVec]
  exact (entry_getScalar _ i).trans (MojoProof.Sem.matVec_cell_real A v i).symm

end MojoProof.Import
