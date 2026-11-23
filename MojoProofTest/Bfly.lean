import MojoProof.Sem.Bfly
import MojoProofTest.FloatRel

/-!
# Instances and twin of the warp butterfly

The instances, at a warp's offsets `16, 8, 4, 2, 1` (`warpOffsets`), by `decide +kernel`: lane
0's tree has the lanes as leaves in bit-reversed order, `0, 16, 8, 24, 4, 20, 12, 28, 2, ...`
(`lane0_leaves`); with `(· + ·)` on `Nat` and lane `j` holding `j`, every lane below 32 ends with
`0 + ... + 31 = 496`, and so does the evaluation of its tree (`bfly_sum`, `eval_bflyTree`).

The twin: with the offsets `16, 8, 4, 2, 2` (the round with offset 2 twice, none with offset 1),
lane 0's leaves are not a permutation of the lanes: each even lane occurs twice and no odd lane
occurs (`bfly_twin`), so `leaves_warp` needs the warp's offsets; on the values of `bfly_sum`
lane 0 ends with 480, twice the sum of the even lanes, not 496.

The instance of `bfly_add_error` (`add_ones`): binary32, a warp's offsets, lane 0 and 32 lanes
holding `1` (word `0x3f800000`); the root's sum `32` is finite by evaluation.

The instances of `leaves_bfly` and `bfly_add_error` away from a warp and out of order
(`leaves_mixed`, `add_mixed`): the offsets `1, 4, 2`, a permutation of `1, 2, 4` (by `decide`), and
lane 5, whose leaves are the lanes below 8; with eight binary32 lanes holding `1` the root's sum
`8` is finite by evaluation.

The instance of `bfly_warp_error` away from a warp (`exact4`): the offsets `2, 1`, lane 3, whose
leaves are the lanes below 4 (by `decide +kernel`), and exact addition of reals (`u = 0`): lane
3's value is the sum of the 4 lanes' values, for every family of values.
-/

namespace MojoProofTest.Bfly

open MojoProof.Sem

/-- Lane 0's leaves at a warp's offsets are the lanes in bit-reversed order, by
`decide +kernel`. -/
theorem lane0_leaves :
    (bflyTree warpOffsets 0).leaves = [0, 16, 8, 24, 4, 20, 12, 28, 2, 18, 10, 26, 6, 22, 14, 30,
      1, 17, 9, 25, 5, 21, 13, 29, 3, 19, 11, 27, 7, 23, 15, 31] := by
  decide +kernel

/-- With `(· + ·)` on `Nat` and lane `j` holding `j`, every lane below 32 ends the five rounds
with 496, and so does the evaluation of its tree (`eval_bflyTree`), by `decide +kernel`. -/
theorem bfly_sum : ∀ l < 32, bflyRounds (· + ·) warpOffsets id l = 496 ∧
    (bflyTree warpOffsets l).eval (· + ·) id = 496 := by
  decide +kernel

/-- **Twin of `leaves_warp`.** With the offsets `16, 8, 4, 2, 2`, lane 0's leaves are not a
permutation of the lanes: lane 0 occurs twice and lane 1 not at all, and on the values of
`bfly_sum` lane 0 ends with 480, not 496; by `decide +kernel`. -/
theorem bfly_twin :
    ¬ (bflyTree [16, 8, 4, 2, 2] 0).leaves.Perm (List.range 32) ∧
      (bflyTree [16, 8, 4, 2, 2] 0).leaves.count 0 = 2 ∧
      (bflyTree [16, 8, 4, 2, 2] 0).leaves.count 1 = 0 ∧
      bflyRounds (· + ·) [16, 8, 4, 2, 2] id 0 = 480 := by
  decide +kernel

open FloatLib.Floats.Formats.BinaryInterchange in
/-- **The instance of `bfly_add_error`**, a test of one example: in binary32, with 32 lanes
holding `1` (word `0x3f800000`), lane 0's sum after the five rounds of `Model.add` is finite (by
evaluation), so every lane below 32 is finite and the sum is within
`((1 + u) ^ 5 - 1) · Σ_{j<32} |1|` of `Σ_{j<32} 1`. -/
theorem add_ones :
    (∀ j < 32, (MojoProofTest.FloatRel.f32 0x3f800000).isFinite = true) ∧
      |(bflyRounds (fun x y => Model.add x y) warpOffsets
          (fun _ => MojoProofTest.FloatRel.f32 0x3f800000) 0).toReal -
          ((List.range 32).map fun _ => (MojoProofTest.FloatRel.f32 0x3f800000).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ warpOffsets.length - 1) *
          ((List.range 32).map fun _ => |(MojoProofTest.FloatRel.f32 0x3f800000).toReal|).sum :=
  bfly_add_error rfl _ (leaves_warp 0 (by decide)) (by decide +kernel)

/-- **The instance of `leaves_bfly`** away from a warp and out of order, a test of one example:
the offsets `1, 4, 2` are a permutation of `1, 2, 4` (by `decide`), so lane 5's leaves are a
permutation of the lanes below 8. -/
theorem leaves_mixed : (bflyTree [1, 4, 2] 5).leaves.Perm (List.range 8) :=
  leaves_bfly (k := 3) (by decide) (by decide)

open FloatLib.Floats.Formats.BinaryInterchange in
/-- **The instance of `bfly_add_error` with `leaves_bfly`**, a test of one example: in binary32,
with 8 lanes holding `1` and the offsets `1, 4, 2`, lane 5's sum after the three rounds of
`Model.add` is finite (by evaluation), so every lane below 8 is finite and the sum is within
`((1 + u) ^ 3 - 1) · Σ_{j<8} |1|` of `Σ_{j<8} 1`. -/
theorem add_mixed :
    (∀ j < 8, (MojoProofTest.FloatRel.f32 0x3f800000).isFinite = true) ∧
      |(bflyRounds (fun x y => Model.add x y) [1, 4, 2]
          (fun _ => MojoProofTest.FloatRel.f32 0x3f800000) 5).toReal -
          ((List.range 8).map fun _ => (MojoProofTest.FloatRel.f32 0x3f800000).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ [1, 4, 2].length - 1) *
          ((List.range 8).map fun _ => |(MojoProofTest.FloatRel.f32 0x3f800000).toReal|).sum :=
  bfly_add_error rfl _ leaves_mixed (by decide +kernel)

/-- **The instance of `bfly_warp_error` away from a warp**, a test of one example: with the
offsets `2, 1` (two rounds over 4 lanes) lane 3's leaves are `3, 1, 2, 0` (by `decide +kernel`),
and with exact addition of reals every node is within `0` of its exact sum, so for every family
`v` lane 3's value after the rounds is `Σ_{j<4} v j`. -/
theorem exact4 (v : Nat → ℝ) : bflyRounds (· + ·) [2, 1] v 3 = ((List.range 4).map v).sum := by
  have e := bfly_warp_error (· + ·) v id 0 le_rfl (ms := [2, 1]) (w := 4) (l := 3)
    (by decide +kernel) (.of_forall _ _ _ fun x y => by simp)
  rw [add_zero, one_pow, sub_self, zero_mul] at e
  exact sub_eq_zero.1 (abs_nonpos_iff.1 e)

end MojoProofTest.Bfly
