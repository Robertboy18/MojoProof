import MojoProof.Tile.Dot
import MojoProofTest.DotGrade

/-!
# The graded clause of the tile matrix product at instances

`MojoProof.Tile.Meets` has a graded clause: when the format is IEEE, the word at a cell is
`GPUProof.Approx` at `GPUProof.dotGrade` of every exact entries and grades at which the cell's
inputs are `GPUProof.Approx` (by `MojoProof.Sem.dotLoop_approx`). Here:

* `meets_exact`: the clause at the inputs' own values with no input error, for every IEEE format,
  sizes, matrices, cell, flag, oracle sequence and word that meets the product, when the cell's
  inputs are finite;
* `grade_3x4`, `grade_5x7`: `dot_meets` with `meets_exact` at sizes 3 × 4 (5 terms, rows of
  stride 5) and 5 × 7 (2 terms, rows of strides 3 and 2) over the generated binary32 matrices
  `gen m s` of entries `1`, `2`, `-1`, for every flag and tile oracle; the inputs' finiteness is
  evaluated by the kernel;
* `tile_mutant`: the grade one ulp tighter is refused. The run of `dot false 1 (byRows 1 1)` at
  the tile oracle 0 from the 1 × 1 matrices of `subW` and `halfW` holds at cell `(0, 0)` the word
  of `MojoProofTest.DotGrade.mutant_one` (the pairs evaluated by the kernel): it meets the
  product, and it is not `GPUProof.Approx` at `GPUProof.dotGrade`'s error less `2 ^ -149`.
-/

namespace MojoProofTest.TileGrade

open MojoProof.Sem MojoProof.Tile MojoProofTest.DotGrade
open FloatLib.Floats.Formats.BinaryInterchange TorchLean
open MojoProofTest.FloatRel (f32)

/-- **The graded clause at exact inputs.** For every IEEE format, sizes with `K ≤ sA` and
`K ≤ sB`, matrices `A` (`m × sA`) and `B` (`p × sB`), cell `(r, col)`, flag `c`, oracle sequence
`o` and word `v` that meets the product there (`Meets`): if the first `K` entries of row `r` of
`A` and of row `col` of `B` are finite, `v` is `GPUProof.Approx` at `GPUProof.dotGrade` of their
values, with the grade `g0` of no error, of `Σₖ aₖ bₖ` over those values. -/
theorem meets_exact {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {m p sA sB K : Nat}
    {A : Tensor (Model fmt) [m, sA]} {B : Tensor (Model fmt) [p, sB]} {hA : K ≤ sA}
    {hB : K ≤ sB} {r : Fin m} {col : Fin p} {c : Bool} {o : Nat → Nat × Nat} {v : Model fmt}
    (h : Meets A B hA hB r col c o v)
    (hf : ∀ k : Fin K, (Tensor.get2 A r (Fin.castLE hA k)).isFinite = true ∧
      (Tensor.get2 B col (Fin.castLE hB k)).isFinite = true) :
    GPUProof.Approx .real (GPUProof.dotGrade (.ieee fmt) K
        (fun k => (Tensor.get2 A r (Fin.castLE hA k)).toReal)
        (fun k => (Tensor.get2 B col (Fin.castLE hB k)).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee fmt) v.toReal?
      (∑ k, (Tensor.get2 A r (Fin.castLE hA k)).toReal *
        (Tensor.get2 B col (Fin.castLE hB k)).toReal) :=
  h.2.2 hfmt _ _ _ _
    (fun k => (GPUProof.Approx.model _ _ _).2 fun _ => ⟨(hf k).1, by simp [g0]⟩)
    (fun k => (GPUProof.Approx.model _ _ _).2 fun _ => ⟨(hf k).2, by simp [g0]⟩)

/-- The binary32 words `1`, `2`, `-1` (bits `0x3f800000`, `0x40000000`, `0xbf800000`). -/
def words3 : Fin 3 → Model .binary32 := ![f32 0x3f800000, f32 0x40000000, f32 0xbf800000]

/-- The generated `m × s` binary32 matrix with entry `words3 ((i + j) % 3)` at `(i, j)`. -/
def gen (m s : Nat) : Tensor (Model .binary32) [m, s] :=
  Tensor.Rep.ofFn fun c => words3 ⟨(c.1.val + c.2.1.val) % 3, Nat.mod_lt _ (by decide)⟩

/-- **The graded clause at sizes 3 × 4**, with 5 terms: for every flag and tile oracle, the run
of `dot c 5 (byRows 3 4)` on 12 threads from `mats (gen 3 5) (gen 4 5)` ends without a fault, and
each placed cell's word is `GPUProof.Approx` at `GPUProof.dotGrade` of its row's and column's
values with no input error (`meets_exact`; the entries' finiteness evaluated by the kernel). -/
theorem grade_3x4 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 5 (byRows 3 4)) 12 (mats (gen 3 5) (gen 4 5)) = .ok st ∧
      ∀ t r col, t < 12 → byRows 3 4 t = some (r, col) → ∃ v,
        st.cells 2 (Nat.pair r col) = some v ∧
        GPUProof.Approx .real (GPUProof.dotGrade (.ieee .binary32) 5
            (fun k => (Tensor.get2 (gen 3 5) r k).toReal)
            (fun k => (Tensor.get2 (gen 4 5) col k).toReal) (fun _ => g0) (fun _ => g0))
          (.ieee .binary32) v.toReal?
          (∑ k, (Tensor.get2 (gen 3 5) r k).toReal * (Tensor.get2 (gen 4 5) col k).toReal) := by
  obtain ⟨st, hr, h⟩ := dot_meets c le_rfl le_rfl (gen 3 5) (gen 4 5) (byRows_inj 3 4) q 12
  have hf : ∀ (r : Fin 3) (col : Fin 4) (k : Fin 5), (Tensor.get2 (gen 3 5) r k).isFinite = true ∧
      (Tensor.get2 (gen 4 5) col k).isFinite = true := by
    decide +kernel
  refine ⟨st, hr, fun t r col ht hp => ?_⟩
  obtain ⟨v, hv, hm⟩ := h t r col ht hp
  exact ⟨v, hv, meets_exact rfl hm (hf r col)⟩

/-- **The graded clause at sizes 5 × 7**, with the first 2 terms of rows of strides 3 and 2: for
every flag and tile oracle, the run of `dot c 2 (byRows 5 7)` on 35 threads from
`mats (gen 5 3) (gen 7 2)` ends without a fault, and each placed cell's word is
`GPUProof.Approx` at `GPUProof.dotGrade` of the values of the first 2 entries of its row and
column with no input error (`meets_exact`; the entries' finiteness evaluated by the kernel). -/
theorem grade_5x7 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 2 (byRows 5 7)) 35 (mats (gen 5 3) (gen 7 2)) = .ok st ∧
      ∀ t r col, t < 35 → byRows 5 7 t = some (r, col) → ∃ v,
        st.cells 2 (Nat.pair r col) = some v ∧
        GPUProof.Approx .real (GPUProof.dotGrade (.ieee .binary32) 2
            (fun k => (Tensor.get2 (gen 5 3) r (Fin.castLE (by decide) k)).toReal)
            (fun k => (Tensor.get2 (gen 7 2) col k).toReal) (fun _ => g0) (fun _ => g0))
          (.ieee .binary32) v.toReal?
          (∑ k, (Tensor.get2 (gen 5 3) r (Fin.castLE (by decide) k)).toReal *
            (Tensor.get2 (gen 7 2) col k).toReal) := by
  obtain ⟨st, hr, h⟩ := dot_meets c (by decide) le_rfl (gen 5 3) (gen 7 2) (byRows_inj 5 7) q 35
  have hf : ∀ (r : Fin 5) (col : Fin 7) (k : Fin 2),
      (Tensor.get2 (gen 5 3) r (Fin.castLE (by decide) k)).isFinite = true ∧
        (Tensor.get2 (gen 7 2) col k).isFinite = true := by
    decide +kernel
  refine ⟨st, hr, fun t r col ht hp => ?_⟩
  obtain ⟨v, hv, hm⟩ := h t r col ht hp
  exact ⟨v, hv, meets_exact rfl hm (hf r col)⟩

/-- The 1 × 1 binary32 matrix of `subW` (`3 · 2 ^ -149`). -/
def subT : Tensor (Model .binary32) [1, 1] := Tensor.Rep.ofFn fun _ => subW

/-- The 1 × 1 binary32 matrix of `halfW` (`1 / 2`). -/
def halfT : Tensor (Model .binary32) [1, 1] := Tensor.Rep.ofFn fun _ => halfW

/-- **The mutant: one ulp tighter is refused.** The run of `dot false 1 (byRows 1 1)` on one
thread at the tile oracle 0 from `mats subT halfT` ends without a fault with a word `v` at cell
`(0, 0)` that meets the product (`Meets`, so `GPUProof.Approx` at `GPUProof.dotGrade` of
`3 / 2 ^ 149` and `1 / 2`, by `approx_one`), and `v` is not `GPUProof.Approx` at the grade with
`GPUProof.dotGrade`'s magnitude and its error less `2 ^ -149` (`mutant_one`; the cell's pairs
evaluated by the kernel). -/
theorem tile_mutant :
    ∃ st, runAll (fun _ => 0) (dot false 1 (byRows 1 1)) 1 (mats subT halfT) = .ok st ∧
      ∃ v, st.cells 2 (Nat.pair 0 0) = some v ∧
        Meets subT halfT le_rfl le_rfl 0 0 false (fun _ => (0, 0)) v ∧
        ¬ GPUProof.Approx .real
          ⟨(GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
              (fun _ => g0) (fun _ => g0)).err - 1 / 2 ^ 149,
            (GPUProof.dotGrade (.ieee .binary32) 1 (fun _ => 3 / 2 ^ 149) (fun _ => 1 / 2)
              (fun _ => g0) (fun _ => g0)).mag⟩ (.ieee .binary32) v.toReal?
          (∑ _ : Fin 1, 3 / 2 ^ 149 * (1 / 2)) := by
  obtain ⟨st, hr, -, h2⟩ := dot_run false le_rfl le_rfl subT halfT (byRows_inj 1 1)
    (fun _ => 0) 1
  have hv := h2 0 0 0 (by decide) (by decide)
  have e : (List.ofFn fun k : Fin 1 =>
      (Tensor.get2 subT 0 (Fin.castLE le_rfl k), Tensor.get2 halfT 0 (Fin.castLE le_rfl k))) =
      List.ofFn fun _ : Fin 1 => (subW, halfW) := by
    decide +kernel
  have hm := meets_dotLoop subT halfT le_rfl le_rfl 0 0 false (fun _ => (0, 0))
  rw [e] at hv hm
  exact ⟨st, hr, _, hv, hm, mutant_one⟩

end MojoProofTest.TileGrade
