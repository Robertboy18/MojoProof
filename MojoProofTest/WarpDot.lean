import MojoProof.Sem.WarpDot
import MojoProofTest.FloatRel

/-!
# The warp's dot product at 40 pairs, over 32 lanes and over 8

A test of one example of MojoProof/Sem/WarpDot.lean, on binary32: the 40 factor pairs `wd40`,
`(2 ^ 24, 1)` then 39 times `(1, 1)` (words `0x4b800000` and `0x3f800000`), the pairs of entry 0
of the product of the vector `wv = [2 ^ 24, 1, …, 1]` and the `40 × 1` matrix of ones `wA`
(`pairs40`). The exact sum is `2 ^ 24 + 39`.
* `lens40`: lists 0 to 7 of the strided split have 2 pairs and lists 8 to 31 have 1, as
  `length_stride` says (`⌈40 / 32⌉ = 2`).
* `vals40`: the warp's word, without the `contract` flag, is `2 ^ 24 + 38`, and FloatLib's
  in-order dot product of the 40 pairs is `2 ^ 24`: the two orders give different words.
* `eq40`: the instance of `warpDot_eq`: with the `contract` flag under the oracle numbers
  `(0, 0)`, the warp's word is FloatLib's reduction along `bflyTree warpOffsets 0` of the 32
  in-order dot products.
* `error40`: the instance of `warpDot_vecMat`: the warp's word is finite, so it is within the
  error of `GPUProof.laneGrade (.ieee .binary32) 32 5 2 40` (`⌈40 / 32⌉ = 2`) at the real values
  with the grades `⟨0, 0⟩` of entry 0 of TorchLean's vector-matrix product over `ℝ`.

The same pairs over a group of 8 lanes (`groupDot 3`, three rounds at the offsets `4, 2, 1`):
* `eq8`: the instance of `groupDot_eq` at `k = 3`, as `eq40` is at `k = 5`.
* `error8`: the instance of `groupDot_vecMat` at `k = 3`: the group's word is finite, so it is
  within the error of `GPUProof.laneGrade (.ieee .binary32) 8 3 5 40` (`⌈40 / 8⌉ = 5`) of the same
  real entry.
* `mutant_exact`: at no iterations and no rounds `laneGrade`'s error is `0`, and the warp's word
  `2 ^ 24 + 38` is not the exact `2 ^ 24 + 39`, so the bound's roundoff terms cannot be dropped.

And one example of `bflyRounds_nanEq` at the semantics' `fadd`: `deliver5`, with lane 5 holding
the quiet NaN `0x7fc00000` and the other lanes `1` (`nan5`), lane 0's value after the five rounds
of `deliver (Model.add x y) 7` is a NaN, because the rounds of `Model.add` give a NaN (by
`decide +kernel`).

And with an oracle number per round and lane, `oracleAt r l = 32 r + l + 7`: `deliverAt5`, the
instance of `bflyDeliver_nanEq` at `nan5`, lane 0's value is a NaN; `deliverAt_ones`, the
instance of `bflyDeliver_error` at 32 lanes `1` (`ones32`), lane 0's value is finite, so it is
the `Model.add` rounds' value and within `((1 + u) ^ 5 - 1) · 32` of `32`.
-/

namespace MojoProofTest.WarpDot

open MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange TorchLean
open MojoProofTest.FloatRel (f32)

/-- The binary32 vector `[2 ^ 24, 1, …, 1]` of length 40 (words `0x4b800000`, then 39 times
`0x3f800000`), as a TorchLean tensor of shape `[40]`. -/
def wv : Tensor (Model .binary32) [40] :=
  Tensor.Rep.ofFn fun c => if c.1.val = 0 then f32 0x4b800000 else f32 0x3f800000

/-- The binary32 `40 × 1` matrix of ones (word `0x3f800000`), as a TorchLean tensor of shape
`[40, 1]`. -/
def wA : Tensor (Model .binary32) [40, 1] :=
  Tensor.Rep.ofFn fun _ => f32 0x3f800000

/-- The 40 binary32 factor pairs `(2 ^ 24, 1)`, then 39 times `(1, 1)`. -/
def wd40 : List (Model .binary32 × Model .binary32) :=
  List.ofFn fun k : Fin 40 => (if k.val = 0 then f32 0x4b800000 else f32 0x3f800000, f32 0x3f800000)

/-- The pairs of entry 0 of the product of `wv` and `wA` are `wd40`, a test of one example, by
evaluation. -/
theorem pairs40 : vecMatPairs wv wA 0 = wd40 := by
  decide +kernel

/-- **The lengths of the strided lists of `wd40`**, a test of one example: lists 0 to 7 have 2
pairs and lists 8 to 31 have 1, by evaluation; `length_stride` gives the same numbers. -/
theorem lens40 : (List.range 32).map (fun l => (stride 32 l wd40).length) =
    List.replicate 8 2 ++ List.replicate 24 1 := by
  decide +kernel

/-- **The warp's word and the in-order word differ**, a test of one example: without the
`contract` flag, `warpDot` over `wd40` is `2 ^ 24 + 38`, and FloatLib's in-order dot product of
`wd40` is `2 ^ 24`, by evaluation. -/
theorem vals40 :
    (warpDot false (fun _ _ => (0, 0)) wd40).toRat? = some 16777254 ∧
      (Model.dotInOrder .binary32 .binary32 wd40).toRat? = some 16777216 := by
  decide +kernel

/-- **The instance of `warpDot_eq`**, a test of one example: FloatLib's reduction along
`bflyTree warpOffsets 0` of the in-order dot products of the 32 strided lists of `wd40` is not a
NaN, so `warpDot` with the `contract` flag under the oracle numbers `(0, 0)` is that word. -/
theorem eq40 :
    warpDot true (fun _ _ => (0, 0)) wd40 = Model.reduceAlong .binary32 .binary32
      (fun j => Model.dotInOrder .binary32 .binary32 (stride 32 j wd40))
      (bflyTree warpOffsets 0) :=
  (warpDot_eq true _ wd40 (fun _ _ _ => by simp)).1 (by decide +kernel)

/-- **The instance of `warpDot_vecMat`**, a test of one example: `warpDot` without the `contract`
flag over the pairs of entry 0 of the product of `wv` and `wA` is finite, so it is within the
error of `GPUProof.laneGrade (.ieee .binary32) 32 5 2 40` at the real values with the grades
`⟨0, 0⟩` of entry 0 of TorchLean's `contract v A _ _ [1] .vecMat` of the tensors mapped by
`Model.toReal`. -/
theorem error40 :
    |(warpDot false (fun _ _ => (0, 0)) (vecMatPairs wv wA 0)).toReal -
        (Tensor.contract (Tensor.map Model.toReal wv) (Tensor.map Model.toReal wA) _ _ [1]
          .vecMat).getScalar 0| ≤
      (GPUProof.laneGrade (.ieee .binary32) 32 5 2 40 (fun i => (wv.getScalar i).toReal)
        (fun i => (Tensor.get2 wA i 0).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err :=
  warpDot_vecMat rfl false _ wv wA 0 (by rw [pairs40]; decide +kernel)

/-- **The instance of `groupDot_eq` at a group of 8 lanes**, a test of one example: FloatLib's
reduction along `bflyTree (bflyOffsets 3) 0` of the in-order dot products of the 8 strided lists
of `wd40` is not a NaN, so `groupDot 3` with the `contract` flag under the oracle numbers
`(0, 0)` is that word. -/
theorem eq8 :
    groupDot 3 true (fun _ _ => (0, 0)) wd40 = Model.reduceAlong .binary32 .binary32
      (fun j => Model.dotInOrder .binary32 .binary32 (stride 8 j wd40))
      (bflyTree (bflyOffsets 3) 0) :=
  (groupDot_eq 3 true _ wd40 (fun _ _ _ => by simp)).1 (by decide +kernel)

/-- **The instance of `groupDot_vecMat` at a group of 8 lanes**, a test of one example:
`groupDot 3` without the `contract` flag over the pairs of entry 0 of the product of `wv` and
`wA` is finite, so it is within the error of `GPUProof.laneGrade (.ieee .binary32) 8 3 5 40` at
the real values with the grades `⟨0, 0⟩` of entry 0 of TorchLean's `contract v A _ _ [1] .vecMat`
of the tensors mapped by `Model.toReal`. -/
theorem error8 :
    |(groupDot 3 false (fun _ _ => (0, 0)) (vecMatPairs wv wA 0)).toReal -
        (Tensor.contract (Tensor.map Model.toReal wv) (Tensor.map Model.toReal wA) _ _ [1]
          .vecMat).getScalar 0| ≤
      (GPUProof.laneGrade (.ieee .binary32) 8 3 5 40 (fun i => (wv.getScalar i).toReal)
        (fun i => (Tensor.get2 wA i 0).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err :=
  groupDot_vecMat rfl 3 false _ wv wA 0 (by rw [pairs40]; decide +kernel)

/-- **The mutant of the bound's roundoff terms**, a test of one example: at no iterations and no
rounds (`L = d = 0`) the error of `GPUProof.laneGrade` is `0`, and without the `contract` flag the
warp's word over `wd40`, `2 ^ 24 + 38` (`vals40`), is not the exact sum `2 ^ 24 + 39`, so the
conclusion of `warpDot_error` fails at that grade: the roundoff terms cannot be dropped. -/
theorem mutant_exact :
    ¬ |(warpDot false (fun _ _ => (0, 0)) wd40).toReal -
        ∑ k : Fin 40, (if k.val = 0 then f32 0x4b800000 else f32 0x3f800000).toReal *
          (f32 0x3f800000).toReal| ≤
      (GPUProof.laneGrade (.ieee .binary32) 32 0 0 40
        (fun k => (if k.val = 0 then f32 0x4b800000 else f32 0x3f800000).toReal)
        (fun _ => (f32 0x3f800000).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err := by
  have r : (warpDot false (fun _ _ => (0, 0)) wd40).toReal = 16777254 := by
    rw [Model.Algebraic.toReal_of_toRat?_eq_some vals40.1]; norm_num
  have r1 : (f32 0x3f800000).toReal = 1 := by
    rw [Model.Algebraic.toReal_of_toRat?_eq_some (q := 1) (by decide +kernel)]; norm_num
  have r0 : (f32 0x4b800000).toReal = 16777216 := by
    rw [Model.Algebraic.toReal_of_toRat?_eq_some (q := 16777216) (by decide +kernel)]; norm_num
  rw [r, Fin.sum_univ_succ]
  simp [GPUProof.laneGrade, GPUProof.Grade.pos, r0, r1, Fin.val_succ]
  norm_num

/-- Lane 5 holds the binary32 quiet NaN `0x7fc00000`, every other lane `1` (`0x3f800000`). -/
def nan5 (j : Nat) : Model .binary32 := if j = 5 then f32 0x7fc00000 else f32 0x3f800000

/-- **The instance of `bflyRounds_nanEq` at the semantics' `fadd`**, a test of one example: in
binary32, over `nan5`, lane 0's value after the five rounds of `deliver (Model.add x y) 7` (the
`fadd` at the oracle number 7) is a NaN: it is `NaNEq` to the rounds of `Model.add`
(`nanEq_deliver` at each node), whose lane 0 is a NaN by `decide +kernel`. -/
theorem deliver5 :
    (bflyRounds (fun x y => deliver (Model.add x y) 7) warpOffsets nan5 0).isNaN = true := by
  rw [(bflyRounds_nanEq (g := fun x y => Model.add x y) (fun _ _ _ _ hx hy =>
    (nanEq_deliver _ 7).trans (NaNEq.op (op := .fadd) (f := fun x y => Model.add x y) rfl hx hy))
    warpOffsets (fun _ => .inl rfl) 0).eq_isNaN.2]
  decide +kernel

/-- The oracle number `32 r + l + 7` of round `r` at lane `l`, a different one at every round and
lane. -/
def oracleAt (r l : Nat) : Nat := 32 * r + l + 7

/-- **The instance of `bflyDeliver_nanEq`**, a test of one example: in binary32, over `nan5`, lane
0's value after the five rounds of `deliver (Model.add x y) (oracleAt r l)` is a NaN: it is
`NaNEq` to the rounds of `Model.add`, whose lane 0 is a NaN by `decide +kernel`. -/
theorem deliverAt5 :
    (bflyRoundsAt (fun r l x y => deliver (Model.add x y) (oracleAt r l)) warpOffsets nan5
      0).isNaN = true := by
  rw [(bflyDeliver_nanEq oracleAt warpOffsets nan5 0).eq_isNaN.2]
  decide +kernel

/-- Every lane holds `1` (`0x3f800000`). -/
def ones32 (_ : Nat) : Model .binary32 := f32 0x3f800000

/-- **The instance of `bflyDeliver_error`**, a test of one example: in binary32, over `ones32`, lane
0's value after the five rounds of `deliver (Model.add x y) (oracleAt r l)` is finite (by
evaluation), so it is the `Model.add` rounds' value, the 32 lanes are finite and it is within
`((1 + u) ^ 5 - 1) · 32` of `32` (`leaves_warp` at lane 0). -/
theorem deliverAt_ones :
    bflyRoundsAt (fun r l x y => deliver (Model.add x y) (oracleAt r l)) warpOffsets ones32 0 =
        bflyRounds (fun x y => Model.add x y) warpOffsets ones32 0 ∧
      (∀ j < 32, (ones32 j).isFinite = true) ∧
      |(bflyRoundsAt (fun r l x y => deliver (Model.add x y) (oracleAt r l)) warpOffsets ones32
            0).toReal - ((List.range 32).map fun j => (ones32 j).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ warpOffsets.length - 1) *
          ((List.range 32).map fun j => |(ones32 j).toReal|).sum :=
  bflyDeliver_error rfl oracleAt ones32 (leaves_warp 0 (by decide)) (by decide +kernel)

end MojoProofTest.WarpDot
