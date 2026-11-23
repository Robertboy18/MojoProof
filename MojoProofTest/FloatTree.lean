import MojoProof.Float.Halve
import MojoProofTest.FloatRel

/-!
# Instances of the float bounds along trees and of block reductions

Tests of one example each, in binary32 with every value the word `0x3f800000` of `1`
(`one`, whose real value is `1` by `one_toReal`):

* `chain_error`: `sum_error` at FloatLib's left-to-right chain `leftChain 0 [1, 2]` (a loop over
  three values, depth 2, not a butterfly): the sum `3` is finite by evaluation.
* `chain_mixed`: `sum_mixedError` at the same chain with each input approximating the real `1`
  exactly (`MixedError.of_eq`): the sum approximates `3` with the absolute error
  `((1 + u) ^ 2 - 1) · 3`.
* `halve_ones`: `halve_error` over 8 cells (`k = 3`): cell 0's sum `8` after the strides `4, 2, 1`
  is finite by evaluation; `halve_leaves`: cell 0's leaves there are `0, 4, 2, 6, 1, 5, 3, 7`.
* `block_ones`: `block_error` with two warps of 32 lanes at the warp's offsets, then the halving
  tree over the two warps (`k = 1`): the sum `64` is finite by evaluation, and the depth is
  `1 + 5`.
-/

namespace MojoProofTest.FloatTree

open MojoProof.Float MojoProof.Sem FloatLib.Numerics FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange

/-- The binary32 word of `1`. -/
abbrev one : Model .binary32 := MojoProofTest.FloatRel.f32 0x3f800000

/-- The real value of the binary32 word `0x3f800000` is `1`. -/
theorem one_toReal : one.toReal = 1 := by
  rw [Model.Algebraic.toReal_of_toRat?_eq_some MojoProofTest.FloatRel.one_vals.1, Rat.cast_one]

/-- **The instance of `sum_error` at a loop**, a test of one example: FloatLib's left-to-right
chain over the indices `0, 1, 2` of words of `1` sums to a finite word (by evaluation), so each
input is finite and the sum is within `((1 + u) ^ 2 - 1) · Σ |1|` of `Σ 1` over three inputs. -/
theorem chain_error :
    (∀ j ∈ [0, 1, 2], one.isFinite = true) ∧
      |((ReductionTree.leftChain 0 [1, 2]).eval (fun x y => Model.add x y) fun _ => one).toReal -
          ([0, 1, 2].map fun _ => one.toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ 2 - 1) *
          ([0, 1, 2].map fun _ => |one.toReal|).sum :=
  sum_error rfl _ _ (.refl _) (by decide +kernel)

/-- **The instance of `sum_mixedError`**, a test of one example: at the chain of `chain_error`,
each input approximates the real `1` with mixed error `(0, 0)` (`one_toReal`), and the sum is
finite (by evaluation), so it approximates `3` with absolute error
`((1 + u) ^ 2 - 1) · 3 + (1 + u) ^ 2 · 0`. -/
theorem chain_mixed :
    MixedError ((ReductionTree.leftChain 0 [1, 2]).eval (fun x y => Model.add x y)
        fun _ => one).toReal ([0, 1, 2].map fun _ => (1 : ℝ)).sum 0
      (((1 + Model.unitRoundoffAt .binary32) ^ 2 - 1) * ([0, 1, 2].map fun _ => |(1 : ℝ)|).sum +
        (1 + Model.unitRoundoffAt .binary32) ^ 2 *
          ([0, 1, 2].map fun _ => (0 : ℝ) * |(1 : ℝ)| + 0).sum) :=
  sum_mixedError rfl _ _ (.refl _) (fun _ _ _ => MixedError.of_eq one_toReal) (by decide +kernel)

/-- Cell 0's leaves after the halving rounds over 8 cells (strides `4, 2, 1`) are
`0, 4, 2, 6, 1, 5, 3, 7`, by `decide +kernel`. -/
theorem halve_leaves :
    (roundsTree halveStep (halvings 3) 0).leaves = [0, 4, 2, 6, 1, 5, 3, 7] := by
  decide +kernel

/-- **The instance of `halve_error`**, a test of one example: over 8 cells holding `1`, cell 0's
sum after the halving rounds of `Model.add` is finite (by evaluation), so every cell below 8 is
finite and the sum is within `((1 + u) ^ 3 - 1) · Σ_{j<8} |1|` of `Σ_{j<8} 1`. -/
theorem halve_ones :
    (∀ j < 2 ^ 3, one.isFinite = true) ∧
      |(rounds (fun x y => Model.add x y) halveStep (halvings 3) (fun _ => one) 0).toReal -
          ((List.range (2 ^ 3)).map fun _ => one.toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ 3 - 1) *
          ((List.range (2 ^ 3)).map fun _ => |one.toReal|).sum :=
  halve_error rfl 3 _ (by decide +kernel)

/-- **The instance of `block_error`**, a test of one example: two warps of 32 lanes holding `1`,
each reduced by the butterfly at the warp's offsets, then the halving tree over the two warps
(`leaves_halve 1`); the sum is finite (by evaluation), so every thread below 64 is finite and the
sum is within `((1 + u) ^ (1 + 5) - 1) · Σ_{i<64} |1|` of `Σ_{i<64} 1`. -/
theorem block_ones :
    (∀ i < 2 ^ 1 * 2 ^ 5, one.isFinite = true) ∧
      |((roundsTree halveStep (halvings 1) 0).eval (fun x y => Model.add x y) fun _ =>
          bflyRounds (fun x y => Model.add x y) warpOffsets (fun _ => one) 0).toReal -
          ((List.range (2 ^ 1 * 2 ^ 5)).map fun _ => one.toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^
            ((roundsTree halveStep (halvings 1) 0).depth + 5) - 1) *
          ((List.range (2 ^ 1 * 2 ^ 5)).map fun _ => |one.toReal|).sum :=
  block_error rfl _ (leaves_halve 1) (ms := warpOffsets) (by decide) (fun _ => one)
    (by decide +kernel)

end MojoProofTest.FloatTree
