import MojoProof.Float.CanonHalve
import MojoProofTest.FloatTree

/-!
# Instances of the butterfly and halving trees' canonical forms

Tests at 2, 4, 8 and 32 lanes or cells (docs/proofs/float-reductions.md, statements 34 to 37):

* `halve3`: cell 0's tree after the halving rounds over 8 cells is
  `((0 + 4) + (2 + 6)) + ((1 + 5) + (3 + 7))`, by evaluation; `succ2`: `halve_succ` there.
* `canon3`: that tree is its own `canon`, by evaluation; `canon5`: `canon_halve` at 32 cells.
* `lane13`: `canon` of lane 13's tree after a warp's five rounds `warpOffsets` is the halving
  tree over 32 cells, by evaluation; `lane13_canon`: `canon_bflyOffsets` there.
* `lane1_tree`: lane 1's tree after the rounds `2, 1` over 4 lanes is `(1 + 3) + (0 + 2)`, not
  its own `canon`, by evaluation: the forms agree only up to swapped children.
* `lane5_out`: lane 5 is not below `4`, and its tree after the rounds `2, 1` has another
  `canon` than the halving tree over 4 cells, by evaluation: `canon_bflyOffsets` needs `l < 2 ^ k`.
* `order6`: `canon_bflyTree_lane` at the rounds `1, 4, 2` over 8 lanes and lane 6;
  `order_ne`: in that order lane 0's `canon` is not the halving tree, by evaluation, so
  `canon_bflyOffsets` is about the order `bflyOffsets k`.
* `zero_order`: after the rounds `1, 4, 2` lane 0's tree is
  `((0 + 1) + (4 + 5)) + ((2 + 3) + (6 + 7))`, its own `canon`, by evaluation; `perm6`:
  `canon_bflyTree_perm` there at lane 6, whose canonical form is lane 0's tree; `xor13`:
  `bflyTree_xor` there at lane 13; `perm13`: `canon_bflyTree_perm` at lane 13, lane 0's tree
  shifted by `8`.
* `perm_four`: `canon_bflyTree_perm` at the rounds `1, 2` over 4 lanes and lane 6, lane 0's tree
  shifted by `4`; `lane5_canon`: at the rounds `2, 1` and lane 5, the halving tree over 4 cells
  shifted by `4`.
* `dup_ne`: the mutant with the offset `1` twice, where lane 0's tree is not its own `canon`.
* `warp13`: `bfly_nanEq_halve` in binary32 at a warp (`k = 5`), lane 13, every value `1`.
* `payload_ne`: at 2 lanes (`k = 1`) holding the binary32 quiet NaNs `0x7fc00001` and
  `0x7fc00002`, lane 1's butterfly sum and cell 0's halving sum are different words, by
  evaluation: `bfly_nanEq_halve`'s `NaNEq` is not equality.
-/

namespace MojoProofTest.FloatCanonHalve

open MojoProof.Float MojoProof.Sem FloatLib.Numerics FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange

/-- **The halving tree over 8 cells** (test at 8): cell 0's tree after the strides `4, 2, 1` is
`((0 + 4) + (2 + 6)) + ((1 + 5) + (3 + 7))`. By evaluation. -/
theorem halve3 : roundsTree halveStep (bflyOffsets 3) 0 =
    .node (.node (.node (.leaf 0) (.leaf 4)) (.node (.leaf 2) (.leaf 6)))
      (.node (.node (.leaf 1) (.leaf 5)) (.node (.leaf 3) (.leaf 7))) := by
  decide

/-- **`halve_succ` at 8 cells** (test at 8): the tree after the strides `4, 2, 1` is the node of
the tree after `2, 1` relabelled `2i` and relabelled `2i + 1`. -/
theorem succ2 := halve_succ 2

/-- **The halving tree over 8 cells is canonical** (test at 8): it is its own `canon`. By
evaluation. -/
theorem canon3 : canon (roundsTree halveStep (bflyOffsets 3) 0) =
    roundsTree halveStep (bflyOffsets 3) 0 := by
  decide

/-- **`canon_halve` at 32 cells** (test at 32): the halving tree over a warp's 32 cells is its
own `canon`. -/
theorem canon5 := canon_halve 5

/-- **A warp lane's canonical form** (test at 32): `canon` of lane 13's tree after the rounds
`16, 8, 4, 2, 1` is the halving tree over 32 cells. By evaluation. -/
theorem lane13 : canon (bflyTree warpOffsets 13) = roundsTree halveStep warpOffsets 0 := by
  decide

/-- **`canon_bflyOffsets` at a warp lane** (test at 32): lane 13 after the rounds `bflyOffsets 5`,
the premise `13 < 2 ^ 5` by evaluation. -/
theorem lane13_canon := canon_bflyOffsets 5 (l := 13) (by decide)

/-- **A lane's tree is not canonical** (test at 4): lane 1's tree after the rounds `2, 1` is
`(1 + 3) + (0 + 2)`, and its `canon` is another tree. By evaluation. -/
theorem lane1_tree : bflyTree (bflyOffsets 2) 1 =
      .node (.node (.leaf 1) (.leaf 3)) (.node (.leaf 0) (.leaf 2)) ∧
    canon (bflyTree (bflyOffsets 2) 1) ≠ bflyTree (bflyOffsets 2) 1 := by
  decide

/-- **A lane at or above `2 ^ k`** (test at 4): lane 5's tree after the rounds `2, 1` has the
leaves `4, ..., 7`, so its `canon` is not the halving tree's over 4 cells. By evaluation. -/
theorem lane5_out :
    canon (bflyTree (bflyOffsets 2) 5) ≠ canon (roundsTree halveStep (bflyOffsets 2) 0) := by
  decide

/-- **`canon_bflyTree_lane` in another order** (test at 8): after the rounds `1, 4, 2`, lane 6
has lane 0's canonical form, the premises by evaluation. -/
theorem order6 := canon_bflyTree_lane (k := 3) (ms := [1, 4, 2]) (by decide) (l := 6) (by decide)

/-- **In another order the form is not the halving tree** (test at 8): after the rounds
`1, 4, 2`, lane 0's `canon` is not the halving tree over 8 cells. By evaluation. -/
theorem order_ne : canon (bflyTree [1, 4, 2] 0) ≠ roundsTree halveStep (bflyOffsets 3) 0 := by
  decide

/-- **Lane 0's tree in another order** (test at 8): after the rounds `1, 4, 2`, lane 0's tree is
`((0 + 1) + (4 + 5)) + ((2 + 3) + (6 + 7))`, and it is its own `canon`. By evaluation. -/
theorem zero_order : bflyTree [1, 4, 2] 0 =
      .node (.node (.node (.leaf 0) (.leaf 1)) (.node (.leaf 4) (.leaf 5)))
        (.node (.node (.leaf 2) (.leaf 3)) (.node (.leaf 6) (.leaf 7))) ∧
    canon (bflyTree [1, 4, 2] 0) = bflyTree [1, 4, 2] 0 := by
  decide

/-- **`canon_bflyTree_perm` below `2 ^ k`** (test at 8): after the rounds `1, 4, 2`, lane 6's
canonical form is lane 0's tree, the premise and the shift `2 ^ 3 ⌊6 / 2 ^ 3⌋ = 0` by
evaluation. -/
theorem perm6 : canon (bflyTree [1, 4, 2] 6) = bflyTree [1, 4, 2] 0 :=
  (canon_bflyTree_perm (k := 3) (ms := [1, 4, 2]) (by decide) 6).trans (by decide)

/-- **`bflyTree_xor` at a lane above `2 ^ k`** (test at 8): after the rounds `1, 4, 2`, lane 13's
tree is lane 0's with each leaf `j` relabelled `j ^^^ 13`. -/
theorem xor13 := bflyTree_xor [1, 4, 2] 13

/-- **`canon_bflyTree_perm` above `2 ^ k`** (test at 8): after the rounds `1, 4, 2`, lane 13's
canonical form is `((8 + 9) + (12 + 13)) + ((10 + 11) + (14 + 15))`, lane 0's tree shifted by
`2 ^ 3 ⌊13 / 2 ^ 3⌋ = 8`, the premise and the tree by evaluation. -/
theorem perm13 : canon (bflyTree [1, 4, 2] 13) =
    .node (.node (.node (.leaf 8) (.leaf 9)) (.node (.leaf 12) (.leaf 13)))
      (.node (.node (.leaf 10) (.leaf 11)) (.node (.leaf 14) (.leaf 15))) :=
  (canon_bflyTree_perm (k := 3) (ms := [1, 4, 2]) (by decide) 13).trans (by decide)

/-- **`canon_bflyTree_perm` at 4 lanes in another order** (test at 4): after the rounds `1, 2`,
lane 6's canonical form is `(4 + 5) + (6 + 7)`, lane 0's tree `(0 + 1) + (2 + 3)` shifted by
`4`, the premise and the tree by evaluation. -/
theorem perm_four : canon (bflyTree [1, 2] 6) =
    .node (.node (.leaf 4) (.leaf 5)) (.node (.leaf 6) (.leaf 7)) :=
  (canon_bflyTree_perm (k := 2) (ms := [1, 2]) (by decide) 6).trans (by decide)

/-- **Lane 5's canonical form** (test at 4): after the rounds `2, 1` (`bflyOffsets 2`), lane 5's
canonical form is `(4 + 6) + (5 + 7)`, the halving tree over 4 cells shifted by `4`, which
`lane5_out` shows is not the halving tree; the tree by evaluation. -/
theorem lane5_canon : canon (bflyTree (bflyOffsets 2) 5) =
    .node (.node (.leaf 4) (.leaf 6)) (.node (.leaf 5) (.leaf 7)) :=
  (canon_bflyTree_perm (k := 2) (List.Perm.refl _) 5).trans (by decide)

/-- **A repeated offset** (mutant, test at 2): after the rounds `1, 1`, which are not
`bflyOffsets k` in any order, lane 0's tree `(0 + 1) + (1 + 0)` is not its own `canon`, so
`canon_bflyTree_perm` needs its premise. By evaluation. -/
theorem dup_ne : canon (bflyTree [1, 1] 0) ≠ bflyTree [1, 1] 0 := by
  decide

/-- **`bfly_nanEq_halve` at a warp** (test at 32): in binary32 with every value `1`, lane 13's
sum after the rounds `bflyOffsets 5` and cell 0's after the halving rounds over 32 cells are
equal or both NaNs, the premise `13 < 2 ^ 5` by evaluation. -/
theorem warp13 := bfly_nanEq_halve (fmt := .binary32) 5 (fun _ => MojoProofTest.FloatTree.one)
  (l := 13) (by decide)

/-- The binary32 values of the test `payload_ne`: the quiet NaN `0x7fc00001` at cell 0 and
`0x7fc00002` elsewhere. -/
def nans (j : Nat) : Model .binary32 :=
  if j = 0 then MojoProofTest.FloatRel.f32 0x7fc00001 else MojoProofTest.FloatRel.f32 0x7fc00002

/-- **`NaNEq` is not equality here** (test at 2): with the quiet NaNs `nans`, lane 1's sum after
the round `1` is `0x7fc00002 + 0x7fc00001` and cell 0's after the stride `1` is
`0x7fc00001 + 0x7fc00002`, two different words. By evaluation. -/
theorem payload_ne : bflyRounds (fun x y => Model.add x y) (bflyOffsets 1) nans 1 ≠
    rounds (fun x y => Model.add x y) halveStep (bflyOffsets 1) nans 0 := by
  decide +kernel

end MojoProofTest.FloatCanonHalve
