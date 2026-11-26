import MojoProof.Tile.MatVec
import MojoProofTest.TileGrade

/-!
# Dot products over lanes at instances

MojoProof/Sem/Dot.lean proves that loops per lane added along a tree over the lanes are
`GPUProof.Approx` at `GPUProof.laneGrade` (`MojoProof.Sem.treeDot_approx`), and
MojoProof/Tile/MatVec.lean that so are the strided loops along every such tree and every lane of
a butterfly (`MojoProof.Tile.stride_approx`, `MojoProof.Tile.bfly_approx`,
`MojoProof.Tile.groupDot_approx`). Here:

* `self_approx`: a finite word is `GPUProof.Approx` at the grade `g0` of no error of its own value,
  for every IEEE format; `row_exact`: so are the generated binary32 words `row n s` (`1`, `2`,
  `-1` cyclically), for every length and start;
* `stride_3x7`, `value_3x7`: `stride_approx` at 3 lanes, length 7 and the tree `tree3`,
  `(lane 0 + lane 1) + lane 2`, of depth 2, for every flag and oracle sequence; unfused at the
  oracle 0 the word is `0` (evaluated by the kernel);
* `bfly_trees`: the trees of lanes 0 and 3 after the rounds `bflyOffsets 2`, `(0 + 2) + (1 + 3)`
  and `(3 + 1) + (2 + 0)`: each lane adds all four lanes, in its own order;
* `group_4x10`, `lane3_4x10`, `value_4x10`: `groupDot_approx` and `bfly_approx` at lane 3 with
  4 lanes (`k = 2`) and length 10, for every flag and oracle sequence; unfused at the oracle 0,
  `groupDot 2` is `-4` (evaluated by the kernel);
* `rows_2x7`, `rows_3x10`: `rowTrees_meetsAt` at 3 lanes along `tree3` at size 2 × 7, and at
  4 lanes along lane 0's butterfly tree at size 3 × 10, whose behaviors are `groupDot 2` per row;
  for every flag and oracle sequences, the words are behaviors and meet the rule;
* `depth_holds`, `depth_mutant`: the tree's depth is needed. On the binary32 pairs `depthW`,
  `depthV`, whose products `1 / 2`, `2 ^ -26`, `2 ^ -25`, `2 ^ -26` are exact, unfused at the
  oracle 0, `groupDot 2` (one pair per lane) gives `1 / 2` (`depth_vals`): lane 0's tree adds
  `1 / 2 + 2 ^ -25`, a tie that rounds to the even `1 / 2`, and the exact `2 ^ -26 + 2 ^ -26`,
  then `1 / 2 + 2 ^ -25` again. Its error `2 ^ -24` is within `GPUProof.laneGrade` at depth 2
  (`groupDot_approx`) and above the error `u S + 4 (2 + u) η` of the grade at depth 0, with
  `S = 1 / 2 + 2 ^ -24`, so the word is not `GPUProof.Approx` at that grade.
-/

namespace MojoProofTest.TileLanes

open MojoProof.Sem MojoProof.Tile MojoProofTest.DotGrade MojoProofTest.TileGrade
open FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.FloatRel (f32)

/-- A finite word is `GPUProof.Approx` at `g0` of its own value, for every IEEE format. -/
theorem self_approx {fmt : FloatFormat} {w : Model fmt} (h : w.isFinite = true) :
    GPUProof.Approx .real g0 (.ieee fmt) w.toReal? w.toReal :=
  (GPUProof.Approx.model _ _ _).2 fun _ => ⟨h, by simp [g0]⟩

/-- The binary32 words `words3 ((k + s) % 3)` for `k < n`: `1`, `2`, `-1` cyclically from `s`. -/
def row (n s : Nat) : Fin n → Model .binary32 :=
  fun k => words3 ⟨(k.val + s) % 3, Nat.mod_lt _ (by decide)⟩

/-- Each word of `row n s` is `GPUProof.Approx` at `g0` of its own value, for every `n` and `s`
(the finiteness of `words3` evaluated by the kernel). -/
theorem row_exact (n s : Nat) (k : Fin n) :
    GPUProof.Approx .real g0 (.ieee .binary32) (row n s k).toReal? (row n s k).toReal := by
  have hf : ∀ j : Fin 3, (words3 j).isFinite = true := by decide +kernel
  exact self_approx (hf _)

/-- The tree `(lane 0 + lane 1) + lane 2` over three lanes, of depth 2. -/
def tree3 : FloatLib.Numerics.ReductionTree Nat := .node (.node (.leaf 0) (.leaf 1)) (.leaf 2)

/-- **3 lanes, length 7.** For every flag and oracle sequences, the strided loops over the pairs
of `row 7 0` and `row 7 1` (lane `j` over the pairs `k ≡ j` modulo 3, at most 3) added along
`tree3` are `GPUProof.Approx` at `GPUProof.laneGrade (.ieee .binary32) 3 2 3 7` of the words'
values with no input error, of their exact dot product (`stride_approx`; the leaves by
`decide`). -/
theorem stride_3x7 (c : Bool) (o : Nat → Nat → Nat × Nat) :
    GPUProof.Approx .real (GPUProof.laneGrade (.ieee .binary32) 3 2 3 7
        (fun k => (row 7 0 k).toReal) (fun k => (row 7 1 k).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee .binary32)
      (treeDot tree3 c o fun j => stride 3 j (List.ofFn fun k => (row 7 0 k, row 7 1 k))).toReal?
      (∑ k, (row 7 0 k).toReal * (row 7 1 k).toReal) := by
  have h := stride_approx (W := 3) rfl c o tree3 (by decide) _ _ _ _ _ _ (row_exact 7 0)
    (row_exact 7 1)
  rwa [show tree3.depth = 2 from rfl] at h

/-- The word of `stride_3x7`, unfused at the oracle 0, is `0` (evaluated by the kernel). -/
theorem value_3x7 :
    (treeDot tree3 false (fun _ _ => (0, 0))
      fun j => stride 3 j (List.ofFn fun k => (row 7 0 k, row 7 1 k))).toRat? = some 0 := by
  decide +kernel

/-- The trees of lanes 0 and 3 after the rounds `bflyOffsets 2 = [2, 1]`: `(0 + 2) + (1 + 3)` and
`(3 + 1) + (2 + 0)`, each over the four lanes in its own order. -/
theorem bfly_trees :
    bflyTree (bflyOffsets 2) 0 = .node (.node (.leaf 0) (.leaf 2)) (.node (.leaf 1) (.leaf 3)) ∧
      bflyTree (bflyOffsets 2) 3 = .node (.node (.leaf 3) (.leaf 1)) (.node (.leaf 2) (.leaf 0)) :=
  ⟨rfl, rfl⟩

/-- **4 lanes, length 10.** For every flag and oracle sequences, `groupDot 2` over the pairs of
`row 10 0` and `row 10 2` (4 strided loops of at most 3 pairs and two butterfly rounds) is
`GPUProof.Approx` at `GPUProof.laneGrade (.ieee .binary32) 4 2 3 10` of the words' values with no
input error, of their exact dot product (`groupDot_approx`). -/
theorem group_4x10 (c : Bool) (o : Nat → Nat → Nat × Nat) :
    GPUProof.Approx .real (GPUProof.laneGrade (.ieee .binary32) 4 2 3 10
        (fun k => (row 10 0 k).toReal) (fun k => (row 10 2 k).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee .binary32)
      (groupDot 2 c o (List.ofFn fun k => (row 10 0 k, row 10 2 k))).toReal?
      (∑ k, (row 10 0 k).toReal * (row 10 2 k).toReal) :=
  groupDot_approx rfl 2 c o _ _ _ _ _ _ (row_exact 10 0) (row_exact 10 2)

/-- **Lane 3 of the butterfly**, at the pairs of `group_4x10`, for every flag and oracle
sequences: its word, along the tree `(3 + 1) + (2 + 0)` (`bfly_trees`), is `GPUProof.Approx` at
the same grade (`bfly_approx`). -/
theorem lane3_4x10 (c : Bool) (o : Nat → Nat → Nat × Nat) :
    GPUProof.Approx .real (GPUProof.laneGrade (.ieee .binary32) 4 2 3 10
        (fun k => (row 10 0 k).toReal) (fun k => (row 10 2 k).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee .binary32)
      (bflyRounds (fun x y => Model.add x y) (bflyOffsets 2) (fun j => dotLoop c (o j)
        (Model.zero .binary32 false) (stride 4 j (List.ofFn fun k => (row 10 0 k, row 10 2 k)))) 3
        ).toReal?
      (∑ k, (row 10 0 k).toReal * (row 10 2 k).toReal) :=
  bfly_approx rfl 2 c o (by decide) _ _ _ _ _ _ (row_exact 10 0) (row_exact 10 2)

/-- The word of `group_4x10`, unfused at the oracle 0, is `-4` (evaluated by the kernel). -/
theorem value_4x10 :
    (groupDot 2 false (fun _ _ => (0, 0))
      (List.ofFn fun k => (row 10 0 k, row 10 2 k))).toRat? = some (-4) := by
  decide +kernel

/-- The binary32 input words at size 2 × 7: row `i` is `row 7 i`, the vector `row 7 2`. -/
def in2x7 : Fin 2 × Fin 7 ⊕ Fin 7 → Model .binary32 :=
  Sum.elim (fun ik => row 7 ik.1 ik.2) (row 7 2)

/-- **3 lanes along `tree3` per row, size 2 × 7** (a test of `rowTrees_meetsAt`, not a
kernel theorem): for every flag and oracle sequences, the words of the strided lanes added along
`tree3` per row of `in2x7` are a behavior of `rowTrees` at 3 lanes and `tree3`, and they meet the
rule of `GPUProof.Spec.matVec (GPUProof.laneVecGrade 3 2 fun n => ⌈n / 3⌉)` (the leaves by
`decide`). -/
theorem rows_2x7 (c : Bool) (o : Fin 2 → Nat → Nat → Nat × Nat) :
    ∃ O ∈ rowTrees .binary32 32 3 tree3 c (2, 7) (matVecEnc .binary32 32 (2, 7)) in2x7,
      (∀ i, O i = treeDot tree3 c (o i) fun j => stride 3 j
        (List.ofFn fun k => (in2x7 (.inl (i, k)), in2x7 (.inr k)))) ∧
      (GPUProof.Spec.matVec (GPUProof.laneVecGrade 3 2 fun n => (n + 3 - 1) / 3)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (2, 7) (matVecEnc .binary32 32 (2, 7))
        in2x7 O := by
  have hm : (fun i => treeDot tree3 c (o i) fun j => stride 3 j
      (List.ofFn fun k => (in2x7 (.inl (i, k)), in2x7 (.inr k)))) ∈
      rowTrees .binary32 32 3 tree3 c (2, 7) (matVecEnc .binary32 32 (2, 7)) in2x7 :=
    ⟨rfl, o, fun _ => rfl⟩
  have h := rowTrees_meetsAt rfl 32 (W := 3) (t := tree3) (by decide) c (2, 7) in2x7 _ hm
  rw [show tree3.depth = 2 from rfl] at h
  exact ⟨_, hm, fun _ => rfl, h⟩

/-- The binary32 input words at size 3 × 10: row `i` is `row 10 i`, the vector `row 10 2`. -/
def in3x10 : Fin 3 × Fin 10 ⊕ Fin 10 → Model .binary32 :=
  Sum.elim (fun ik => row 10 ik.1 ik.2) (row 10 2)

/-- **The butterfly per row, size 3 × 10** (a test of `rowTrees_meetsAt`, not a kernel theorem):
for every flag and oracle sequences, `groupDot 2` per row of `in3x10` (4 strided lanes and two
butterfly rounds) is a behavior of `rowTrees` at 4 lanes and lane 0's tree
`bflyTree (bflyOffsets 2) 0` (`eval_bflyTree`), and it meets the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 4 2 fun n => ⌈n / 4⌉)` (`leaves_offsets`,
`depth_bflyTree`). -/
theorem rows_3x10 (c : Bool) (o : Fin 3 → Nat → Nat → Nat × Nat) :
    ∃ O ∈ rowTrees .binary32 32 4 (bflyTree (bflyOffsets 2) 0) c (3, 10)
        (matVecEnc .binary32 32 (3, 10)) in3x10,
      (∀ i, O i = groupDot 2 c (o i) (List.ofFn fun k => (in3x10 (.inl (i, k)), in3x10 (.inr k)))) ∧
      (GPUProof.Spec.matVec (GPUProof.laneVecGrade 4 2 fun n => (n + 4 - 1) / 4)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (3, 10) (matVecEnc .binary32 32 (3, 10))
        in3x10 O := by
  have hm : (fun i => groupDot 2 c (o i)
      (List.ofFn fun k => (in3x10 (.inl (i, k)), in3x10 (.inr k)))) ∈
      rowTrees .binary32 32 4 (bflyTree (bflyOffsets 2) 0) c (3, 10)
        (matVecEnc .binary32 32 (3, 10)) in3x10 :=
    ⟨rfl, o, fun _ => (eval_bflyTree _ _ _ 0).symm⟩
  have h := rowTrees_meetsAt rfl 32 (leaves_offsets 2 0 (by decide)) c (3, 10) in3x10 _ hm
  rw [depth_bflyTree, show (bflyOffsets 2).length = 2 from rfl] at h
  exact ⟨_, hm, fun _ => rfl, h⟩

/-! ## The mutant: the depth of the tree -/

/-- The binary32 word of `2 ^ -13` (bits `0x39000000`). -/
def w13 : Model .binary32 := f32 0x39000000

/-- The first factors `1 / 2`, `2 ^ -13`, `2 ^ -12`, `2 ^ -13`. -/
def depthW : Fin 4 → Model .binary32 := ![halfW, w13, tinyW, w13]

/-- The second factors `1`, `2 ^ -13`, `2 ^ -13`, `2 ^ -13`. -/
def depthV : Fin 4 → Model .binary32 := ![f32 0x3f800000, w13, w13, w13]

/-- The values of the factors, and `groupDot 2` unfused at the oracle 0 over the pairs of `depthW`
and `depthV` gives `1 / 2` (the words and the result evaluated by the kernel). -/
theorem depth_vals :
    halfW.toReal = 1 / 2 ∧ w13.toReal = 1 / 2 ^ 13 ∧ tinyW.toReal = 1 / 2 ^ 12 ∧
      (f32 0x3f800000).toReal = 1 ∧
      (groupDot 2 false (fun _ _ => (0, 0)) (List.ofFn fun i => (depthW i, depthV i))).toReal =
        1 / 2 := by
  have h : halfW.toRat? = some (1 / 2) ∧ w13.toRat? = some (1 / 2 ^ 13) ∧
      tinyW.toRat? = some (1 / 2 ^ 12) ∧ (f32 0x3f800000).toRat? = some 1 ∧
      (groupDot 2 false (fun _ _ => (0, 0))
        (List.ofFn fun i => (depthW i, depthV i))).toRat? = some (1 / 2) := by
    decide +kernel
  obtain ⟨h1, h2, h3, h4, h5⟩ := h
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h1]; push_cast; ring
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h2]; push_cast; ring
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h3]; push_cast; ring
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h4]; push_cast; ring
  · rw [Model.Algebraic.toReal_of_toRat?_eq_some h5]; push_cast; ring

/-- The words of `depthW` and `depthV` are `GPUProof.Approx` at `g0` of their own values (their
finiteness evaluated by the kernel). -/
theorem depth_exact :
    (∀ i, GPUProof.Approx .real g0 (.ieee .binary32) (depthW i).toReal? (depthW i).toReal) ∧
      ∀ i, GPUProof.Approx .real g0 (.ieee .binary32) (depthV i).toReal? (depthV i).toReal := by
  have h : ∀ i, (depthW i).isFinite = true ∧ (depthV i).isFinite = true := by decide +kernel
  exact ⟨fun i => self_approx (h i).1, fun i => self_approx (h i).2⟩

/-- **The grade at depth 2 holds**: `groupDot 2` unfused at the oracle 0 over the pairs of
`depthW` and `depthV` is `GPUProof.Approx` at `GPUProof.laneGrade (.ieee .binary32) 4 2 1 4` of
their values with no input error, of their exact dot product (`groupDot_approx`). -/
theorem depth_holds :
    GPUProof.Approx .real (GPUProof.laneGrade (.ieee .binary32) 4 2 1 4
        (fun i => (depthW i).toReal) (fun i => (depthV i).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee .binary32)
      (groupDot 2 false (fun _ _ => (0, 0)) (List.ofFn fun i => (depthW i, depthV i))).toReal?
      (∑ i, (depthW i).toReal * (depthV i).toReal) :=
  groupDot_approx rfl 2 false _ _ _ _ _ _ _ depth_exact.1 depth_exact.2

/-- **The mutant: the grade at depth 0 fails.** The word of `depth_holds` is not
`GPUProof.Approx` at `GPUProof.laneGrade (.ieee .binary32) 4 0 1 4` of the same values: its error
`2 ^ -24` (`depth_vals`) is above that grade's error `u S + 4 (2 + u) η`, with
`S = 1 / 2 + 2 ^ -24`, `u = 2 ^ -24` and `η = 2 ^ -150` (`u_eta`). -/
theorem depth_mutant :
    ¬ GPUProof.Approx .real (GPUProof.laneGrade (.ieee .binary32) 4 0 1 4
        (fun i => (depthW i).toReal) (fun i => (depthV i).toReal) (fun _ => g0) (fun _ => g0))
      (.ieee .binary32)
      (groupDot 2 false (fun _ _ => (0, 0)) (List.ofFn fun i => (depthW i, depthV i))).toReal?
      (∑ i, (depthW i).toReal * (depthV i).toReal) := by
  obtain ⟨hh, h13, h12, h1, hg⟩ := depth_vals
  obtain ⟨hu, hη⟩ := u_eta
  have hM := Model.one_le_toReal_posMaxFinite .binary32
  rw [GPUProof.Approx.model]
  intro h
  rw [hg] at h
  simp only [GPUProof.laneGrade, GPUProof.NumFormat.roundoff, GPUProof.NumFormat.underflow, g0,
    GPUProof.Grade.pos, Fin.sum_univ_four, depthW, depthV, Matrix.cons_val, hh, h13, h12, h1,
    hu, hη, max_self, ciSup_const, mul_zero, add_zero] at h
  have h2 := (h (max_le (by norm_num [abs_of_pos]; linarith) (by linarith))).2
  norm_num [abs_of_pos] at h2

end MojoProofTest.TileLanes
