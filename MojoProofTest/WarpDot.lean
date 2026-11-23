import MojoProof.Sem.WarpDot
import MojoProofTest.FloatRel

/-!
# The warp's dot product at 40 pairs

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
* `error40`: the instance of `warpDot_vecMat`: the warp's word is finite, so it is within
  `warpBound .binary32 2 5 32 T` of entry 0 of TorchLean's vector-matrix product over `ℝ`.

And one example of `bflyRounds_nanEq` at the semantics' `fadd`: `deliver5`, with lane 5 holding
the quiet NaN `0x7fc00000` and the other lanes `1` (`nan5`), lane 0's value after the five rounds
of `deliver (Model.add x y) 7` is a NaN, because the rounds of `Model.add` give a NaN (by
`decide +kernel`).
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
flag over the pairs of entry 0 of the product of `wv` and `wA` is finite, so it is within
`warpBound .binary32 2 5 32 T` of entry 0 of TorchLean's `contract v A _ _ [1] .vecMat` of the
tensors mapped by `Model.toReal`, with `T` the sum of the absolute products. -/
theorem error40 :
    |(warpDot false (fun _ _ => (0, 0)) (vecMatPairs wv wA 0)).toReal -
        (Tensor.contract (Tensor.map Model.toReal wv) (Tensor.map Model.toReal wA) _ _ [1]
          .vecMat).getScalar 0| ≤
      warpBound .binary32 2 5 32
        ((vecMatPairs wv wA 0).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  warpDot_vecMat rfl false _ wv wA 0 (by rw [pairs40]; decide +kernel)

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

end MojoProofTest.WarpDot
