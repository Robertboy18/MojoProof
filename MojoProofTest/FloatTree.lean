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
* `block_halve`: `block_error` for every `k` and `j`, at `2 ^ k` groups of `2 ^ j` lanes holding
  `1`, each reduced by the butterfly at `bflyOffsets j`, then the halving tree over the groups,
  when the sum is finite. Its instances, each one line by `theorem name := e`, with the finite
  sum by evaluation: `block_ones`, two warps of 32 lanes (`k = 1`, `j = 5`, the sum `64`, depth
  `1 + 5`), and `block_ones8`, four groups of 8 lanes (`k = 2`, `j = 3`, the sum `32`, depth
  `2 + 3`).

`theorem name := e`, a `theorem` without a type after a docstring, declares the theorem `name`
whose statement is the type of `e`: the instances of a theorem over every length are stated by
Lean, not copied. A `theorem` with a type is Lean's own command.
-/

open Lean Elab Command Term Meta in
/-- `theorem name := e`, with a docstring and no type, declares the theorem `name`, with that
docstring, whose statement is the type of the term `e` (elaborated with its tactic blocks run): an
instance of a general theorem stated by Lean. It fails if the statement or the proof has holes.
Lean's `theorem` needs a type, so the two commands do not overlap: with a type, Lean's parses
further and is the one used. -/
elab doc:docComment "theorem " n:ident " := " t:term : command => do
  let name := (← getCurrNamespace) ++ n.getId
  liftTermElabM do
    let e ← instantiateMVars (← elabTermAndSynthesize t none)
    let ty ← instantiateMVars (← inferType e)
    if e.hasMVar || ty.hasMVar then throwError "theorem: the statement or the proof has holes"
    addDecl <| .thmDecl { name, levelParams := [], type := ty, value := e }
    addDocStringCore name (← getDocStringText doc)
    addDeclarationRangesFromSyntax name (← getRef) n

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
    (roundsTree halveStep (bflyOffsets 3) 0).leaves = [0, 4, 2, 6, 1, 5, 3, 7] := by
  decide +kernel

/-- **The instance of `halve_error`**, a test of one example: over 8 cells holding `1`, cell 0's
sum after the halving rounds of `Model.add` is finite (by evaluation), so every cell below 8 is
finite and the sum is within `((1 + u) ^ 3 - 1) · Σ_{j<8} |1|` of `Σ_{j<8} 1`. -/
theorem halve_ones :
    (∀ j < 2 ^ 3, one.isFinite = true) ∧
      |(rounds (fun x y => Model.add x y) halveStep (bflyOffsets 3) (fun _ => one) 0).toReal -
          ((List.range (2 ^ 3)).map fun _ => one.toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^ 3 - 1) *
          ((List.range (2 ^ 3)).map fun _ => |one.toReal|).sum :=
  halve_error rfl 3 _ (by decide +kernel)

/-- **`block_error` at every size of words of `1`**, for every `k` and `j`: `2 ^ k` groups of
`2 ^ j` lanes holding `1`, each reduced by the butterfly at `bflyOffsets j`, then the halving tree
over the groups (`leaves_halve k`); if the sum is finite, every thread below `2 ^ k · 2 ^ j` is
finite and the sum is within `((1 + u) ^ (depth + j) - 1) · Σ |1|` of `Σ 1`. -/
theorem block_halve (k j : ℕ)
    (h : ((roundsTree halveStep (bflyOffsets k) 0).eval (fun x y => Model.add x y) fun _ =>
      bflyRounds (fun x y => Model.add x y) (bflyOffsets j) (fun _ => one) 0).isFinite = true) :
    (∀ i < 2 ^ k * 2 ^ j, one.isFinite = true) ∧
      |((roundsTree halveStep (bflyOffsets k) 0).eval (fun x y => Model.add x y) fun _ =>
          bflyRounds (fun x y => Model.add x y) (bflyOffsets j) (fun _ => one) 0).toReal -
          ((List.range (2 ^ k * 2 ^ j)).map fun _ => one.toReal).sum| ≤
        ((1 + Model.unitRoundoffAt .binary32) ^
            ((roundsTree halveStep (bflyOffsets k) 0).depth + j) - 1) *
          ((List.range (2 ^ k * 2 ^ j)).map fun _ => |one.toReal|).sum :=
  block_error rfl _ (leaves_halve k) (List.reverse_perm _) (fun _ => one) h

/-- **The instance of `block_halve` at two warps**, a test of one example: two warps of 32 lanes
at the warp's offsets, then the halving tree over the two warps; the sum `64` is finite (by
evaluation). -/
theorem block_ones := block_halve 1 5 (by decide +kernel)

/-- **The instance of `block_halve` at four groups of 8 lanes**, a test of one example: the
offsets `4, 2, 1`, then the halving tree over the four groups; the sum `32` is finite (by
evaluation). -/
theorem block_ones8 := block_halve 2 3 (by decide +kernel)

end MojoProofTest.FloatTree
