import MojoProof.Sem.Bfly

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

end MojoProofTest.Bfly
