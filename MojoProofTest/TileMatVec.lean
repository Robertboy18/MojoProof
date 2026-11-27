import MojoProof.Tile.MatVec
import MojoProofTest.TileGrade

/-!
# Dot loops per row and the matrix-vector spec at instances

MojoProof/Tile/MatVec.lean proves that a dot loop per row, the strided lanes of `rowTrees` at
one lane and the tree `.leaf 0` (`rowLoops`), meets `GPUProof.Spec.matVec GPUProof.matVecGrade`
at the uniform IEEE encoding (`rowLoops_meetsAt`), and that the tile matrix product whose
second matrix has one row meets its rule (`meets_holds`, `mat_holds`). Here:

* `rows_holds`: for every IEEE format, width, flag, tile oracle and sizes, the run of
  `dot c K (byRows m 1)` on `m` threads from `mats A B` with `B` of one row ends without a fault,
  and the words at cells `(i, 0)` meet the spec's rule at `matIn A B` (`dot_meets`,
  `meets_holds`);
* `holds_3x4`, `holds_5x7`: `rows_holds` at sizes 3 × 4 and 5 × 7 over the generated binary32
  matrices `MojoProofTest.TileGrade.gen`, for every flag and tile oracle;
* `rowLoops_binary32`: `rowLoops_meetsAt` at binary32, the instance of `rowTrees_meetsAt` at one
  lane;
* `enc_grades`: `matVecEnc` is the uniform encoding of the spec at two other grades, `tight` at
  binary32 and size 3 × 4 and `GPUProof.laneVecGrade 4 2` at binary64 and size 5 × 7, by
  unfolding;
* `rowLoops_mutant`: the spec graded one ulp tighter (`tight`, `GPUProof.matVecGrade`'s error less
  `2 ^ -149`) is not met by `rowLoops` at binary32 unfused: at size `(1, 1)`, on the words `subW`
  and `halfW` of `MojoProofTest.DotGrade.mutant_one` and their exact values `vals`, the rule
  fails at output 0. The unfused loop there is a behavior of `rowLoops` by `rowLoops_dotLoop`.
-/

namespace MojoProofTest.TileMatVec

open MojoProof.Sem MojoProof.Tile MojoProofTest.DotGrade MojoProofTest.TileGrade
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- Thread `i < m` of `byRows m 1` is at row `i`, column 0, for every `m`. -/
theorem byRows_one (m : Nat) (i : Fin m) : byRows m 1 i = some (i, 0) := by
  simp [byRows, i.2, Nat.mod_one]

/-- **The tile product by rows with one column meets the matrix-vector spec's rule.** For every
IEEE format `fmt`, width `bits`, flag `c`, tile oracle `q`, sizes `m`, `K` and matrices `A`
(`m × K`) and `B` (`1 × K`): the run of `dot c K (byRows m 1)` on `m` threads from `mats A B` ends
without a fault in a state whose cells `(i, 0)` of buffer 2 hold words `W' i` that meet
`GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at size `(m, K)` and encoding
`matVecEnc fmt bits` from `matIn A B` (`dot_meets`, `meets_holds`). -/
theorem rows_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat) (c : Bool)
    (q : Site → Nat) {m K : Nat} (A : Tensor (Model fmt) [m, K]) (B : Tensor (Model fmt) [1, K]) :
    ∃ st, runAll q (dot c K (byRows m 1)) m (mats A B) = .ok st ∧ ∃ W' : Fin m → Model fmt,
      (∀ i : Fin m, st.cells 2 (Nat.pair i 0) = some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
        (matVecEnc fmt bits (m, K)) (matIn A B le_rfl le_rfl) W' := by
  obtain ⟨st, hr, h⟩ := dot_meets c le_rfl le_rfl A B (byRows_inj m 1) q m
  have hc : ∀ i : Fin m, ∃ v, st.cells 2 (Nat.pair i 0) = some v ∧
      ∃ oi, Meets A B le_rfl le_rfl i 0 c oi v := fun i => by
    obtain ⟨v, hv, hm⟩ := h i i 0 i.2 (byRows_one m i)
    exact ⟨v, hv, _, hm⟩
  choose W' hW' os hm using hc
  exact ⟨st, hr, W', hW', meets_holds hfmt bits hm⟩

/-- `rows_holds` at sizes 3 × 4: for every flag and tile oracle, on binary32, the run of
`dot c 4 (byRows 3 1)` from `mats (gen 3 4) (gen 1 4)` meets the matrix-vector spec's rule. -/
theorem holds_3x4 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 4 (byRows 3 1)) 3 (mats (gen 3 4) (gen 1 4)) = .ok st ∧
      ∃ W' : Fin 3 → Model .binary32, (∀ i : Fin 3, st.cells 2 (Nat.pair i 0) = some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (3, 4)
        (matVecEnc .binary32 32 (3, 4)) (matIn (gen 3 4) (gen 1 4) le_rfl le_rfl) W' :=
  rows_holds rfl 32 c q _ _

/-- `rows_holds` at sizes 5 × 7: for every flag and tile oracle, on binary32, the run of
`dot c 7 (byRows 5 1)` from `mats (gen 5 7) (gen 1 7)` meets the matrix-vector spec's rule. -/
theorem holds_5x7 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 7 (byRows 5 1)) 5 (mats (gen 5 7) (gen 1 7)) = .ok st ∧
      ∃ W' : Fin 5 → Model .binary32, (∀ i : Fin 5, st.cells 2 (Nat.pair i 0) = some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (5, 7)
        (matVecEnc .binary32 32 (5, 7)) (matIn (gen 5 7) (gen 1 7) le_rfl le_rfl) W' :=
  rows_holds rfl 32 c q _ _

/-- `rowLoops_meetsAt` at binary32, for every flag: `rowTrees` at one lane and the tree `.leaf 0`
meets the spec graded by `GPUProof.matVecGrade`. -/
theorem rowLoops_binary32 (c : Bool) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
      (rowLoops .binary32 32 c) (matVecEnc .binary32 32) :=
  rowLoops_meetsAt rfl 32 c

/-- `GPUProof.matVecGrade` one ulp tighter: its error less `2 ^ -149`, its magnitude bound. -/
noncomputable def tight :
    GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1 :=
  fun σ E A G i => ⟨(GPUProof.matVecGrade σ E A G i).err - 1 / 2 ^ 149,
    (GPUProof.matVecGrade σ E A G i).mag⟩

/-- `tight` grows with the inputs' grades, as `GPUProof.matVecGrade` does. -/
theorem tight_mono : ∀ σ E A, Monotone (tight σ E A) := fun σ E A G G' h i => by
  have hm := GPUProof.matVecGrade_mono σ E A h i
  change (⟨_ - _, _⟩ : GPUProof.Grade) ≤ ⟨_ - _, _⟩
  generalize GPUProof.matVecGrade σ E A G i = g at hm ⊢
  generalize GPUProof.matVecGrade σ E A G' i = g' at hm ⊢
  exact ⟨sub_le_sub_right hm.1 _, hm.2⟩

/-- `matVecEnc` at grades other than `GPUProof.matVecGrade`, by unfolding: at binary32 and size
3 × 4 it is the uniform encoding of the spec graded by `tight`, and at binary64 and size 5 × 7 of
the spec graded by `GPUProof.laneVecGrade 4 2` with `⌈n / 4⌉` pairs per lane. -/
theorem enc_grades :
    matVecEnc .binary32 32 (3, 4) = GPUProof.Encodings.uniform
        (GPUProof.Spec.matVec tight tight_mono) (GPUProof.ScalarEnc.std .binary32 32) (3, 4) ∧
      matVecEnc .binary64 64 (5, 7) = GPUProof.Encodings.uniform
        (GPUProof.Spec.matVec (GPUProof.laneVecGrade 4 2 fun n => (n + 3) / 4)
          (GPUProof.laneVecGrade_mono _ _ _)) (GPUProof.ScalarEnc.std .binary64 64) (5, 7) := by
  unfold matVecEnc GPUProof.Encodings.uniform GPUProof.Spec.matVec GPUProof.Spec.ofReal
  exact ⟨rfl, rfl⟩

/-- The exact inputs of the mutant at size `(1, 1)`: `3 / 2 ^ 149` in the matrix and `1 / 2` in the
vector. -/
noncomputable def vals : Fin 1 × Fin 1 ⊕ Fin 1 → ℝ :=
  Sum.elim (fun _ => 3 / 2 ^ 149) fun _ => 1 / 2

/-- The spec's value at `vals`, at output 0, is `Σ 3 / 2 ^ 149 · 1 / 2` over one term, at every
grade (here `tight`). -/
theorem vals_f : (GPUProof.Spec.matVec tight tight_mono).f (1, 1) vals (0 : Fin 1) =
    ∑ _ : Fin 1, (3 / 2 ^ 149 * (1 / 2) : ℝ) := by
  simp only [GPUProof.Spec.matVec, GPUProof.Spec.ofReal, Matrix.mulVec, dotProduct,
    Matrix.of_apply, vals, Sum.elim_inl, Sum.elim_inr]

/-- **The mutant: one ulp tighter is not met.** The behaviors `rowLoops .binary32 32 false` do
not meet `GPUProof.Spec.matVec tight` at `matVecEnc .binary32 32`: at size `(1, 1)`, the input
words `subW` and `halfW` of the exact `vals` with no input error, and the unfused loop at the
oracle 0, a behavior of `rowLoops` (`rowLoops_dotLoop`), the rule fails at output 0 (`vals_f`,
`mutant_one`): the input grades `⟨0, 0⟩` are below binary32's largest finite value, so
`GPUProof.matVecGrade` there is `GPUProof.dotGrade` (`GPUProof.Grade.onlyIf_pos`). -/
theorem rowLoops_mutant :
    ¬ GPUProof.MeetsAt (GPUProof.Spec.matVec tight tight_mono) (rowLoops .binary32 32 false)
      (matVecEnc .binary32 32) := by
  intro h
  have hm : (fun _ : Fin 1 => dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
      (List.ofFn fun _ : Fin 1 => (subW, halfW))) ∈ rowLoops .binary32 32 false (1, 1)
        (matVecEnc .binary32 32 (1, 1)) (Sum.elim (fun _ => subW) fun _ => halfW) :=
    rowLoops_dotLoop .binary32 32 false (fun _ _ => (0, 0)) _
  have h2 := h (1, 1) _ _ hm vals (fun _ => g0) trivial (by
    rintro (_ | _)
    · exact (GPUProof.Approx.model _ _ _).2 fun _ =>
        ⟨sub_vals.1, by simp [vals, sub_vals.2.2.1, g0]⟩
    · exact (GPUProof.Approx.model _ _ _).2 fun _ =>
        ⟨sub_vals.2.1, by simp [vals, sub_vals.2.2.2, g0]⟩) (0 : Fin 1)
  have h0 : g0.mag ≤ (GPUProof.NumFormat.ieee .binary32).safeMax :=
    show (0 : ℝ) ≤ (Model.posMaxFinite .binary32).toReal from
      zero_le_one.trans (Model.one_le_toReal_posMaxFinite .binary32)
  have e : GPUProof.matVecGrade (1, 1) (matVecEnc .binary32 32 (1, 1)) vals (fun _ => g0)
      (0 : Fin 1) = GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
        (fun _ => g0) (fun _ => g0) :=
    GPUProof.Grade.onlyIf_pos (fun _ => ⟨h0, h0⟩) _ _
  change GPUProof.Approx .real ⟨(GPUProof.matVecGrade (1, 1) (matVecEnc .binary32 32 (1, 1)) vals
      (fun _ => g0) (0 : Fin 1)).err - 1 / 2 ^ 149, (GPUProof.matVecGrade (1, 1)
      (matVecEnc .binary32 32 (1, 1)) vals (fun _ => g0) (0 : Fin 1)).mag⟩ _ _ _ at h2
  rw [vals_f, e] at h2
  exact mutant_one h2

end MojoProofTest.TileMatVec
