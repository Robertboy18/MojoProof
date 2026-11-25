import MojoProof.Float.Welford
import MojoProofTest.FloatStats

/-!
# Instances of Welford's merge along a tree

For every `k ≤ 24`, at the inputs `1, ..., 2 ^ k` (`iota`) along `halveFin k`, the shape of a
block's halving tree over `2 ^ k` cells, with the bound `B = 2 ^ k` on the inputs (`iota_bound`):

* `welford_iota`: `welford_error`, the count, mean and sum words against the leaves' count, mean
  and sum of squared deviations.
* `welfordC_iota`: `welfordC_error`, the same for every choice of contraction at each node.
* `wloop_iota`: `wloop_error`, Welford's loop over the inputs in order, for every choice of
  contraction at each iteration.
* `wmean_iota`: `wmean_error`, the mean word against `𝔼 j, j + 1`.
* `wvar_iota`: `wvar_error`, the variance word against `TorchLean.var`.

The fixtures `iota`, `halveFin` and `iota_bound` are in MojoProofTest/FloatStats.lean. The
instances, tests of one example each, are one line each by `theorem name := e`
(MojoProofTest/FloatTree.lean), with the finiteness premises discharged by evaluation
(`decide +kernel`): at `k = 2` (`welford_xs`, `wmean_xs`, `wvar_xs`; the inputs `xs = iota 4`
along `pairs`), where the merges give the count `4`, the mean `2.5`, the sum of squared deviations
`5` and the variance `1.25`; and at `k = 3` (`welford8`, `wmean8`, `wvar8`), the count `8`, the
mean `4.5`, the sum `42` and the variance `5.25`. `welfordC_xs` and `welfordC8` are
`welfordC_iota` at `k = 2` and `k = 3` with both pairs fused at every node, with the same words
(every operation is exact on these inputs); `welfordC_alt4` and `welfordC_alt8` are the same at
the choice `altNode`, which differs between nodes. `wloop_xs` and `wloop8` are `wloop_iota` at
`k = 2` with no pair fused and at `k = 3` with both pairs fused at every iteration, and
`wloop_alt4` and `wloop_alt8` the same at the choice `altIter`, which differs between iterations;
the loop's three words are finite by evaluation. `xs_bound`, the bound `4` on `xs` that
MojoProofTest/FloatNorm.lean uses, is `iota_bound` at `4`.
-/

namespace MojoProofTest.FloatWelford

open MojoProof.Float FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatTree MojoProofTest.FloatRel
  MojoProofTest.FloatStats
open scoped BigOperators

/-- The inputs `1, 2, 3, 4` are within `4` in magnitude: `iota_bound` at `4`. -/
theorem xs_bound (j : Fin 4) : |(xs j).toReal| ≤ 4 :=
  (iota_bound (by norm_num) (by decide +kernel) j).trans_eq (by norm_num)

/-- **`welford_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24`: if the inputs'
words and the three words of Welford's merge are finite, the count word is the number of leaves,
the mean word is within `(welfErr u η 2 ^ k depth).1` of the leaves' mean and the sum word within
`2 ^ k · (welfErr u η 2 ^ k depth).2` of their sum of squared deviations, with the bound
`B = 2 ^ k` of `iota_bound`. -/
theorem welford_iota (k : ℕ) (hk : k ≤ 24) (hf : ∀ j, (iota (2 ^ k) j).isFinite = true)
    (h₁ : (welford (halveFin k) (iota _)).1.isFinite = true)
    (h₂ : (welford (halveFin k) (iota _)).2.1.isFinite = true)
    (h₃ : (welford (halveFin k) (iota _)).2.2.isFinite = true) :
    (welford (halveFin k) (iota _)).1.toReal = (halveFin k).leaves.length ∧
      |(welford (halveFin k) (iota _)).2.1.toReal -
          ((halveFin k).leaves.map fun j => (iota _ j).toReal).sum / (halveFin k).leaves.length| ≤
        (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
          (halveFin k).depth).1 ∧
      |(welford (halveFin k) (iota _)).2.2.toReal -
          (((halveFin k).leaves.map fun j => (iota _ j).toReal ^ 2).sum -
            ((halveFin k).leaves.map fun j => (iota _ j).toReal).sum ^ 2 /
              (halveFin k).leaves.length)| ≤
        (halveFin k).leaves.length *
          (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
            (halveFin k).depth).2 := by
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have e := welford_error rfl (halveFin k) (iota _) (fun j _ => iota_bound hn hf j)
    (by rw [(leaves_halveFin k).length_eq, List.length_finRange]; exact hn) le_rfl h₁ h₂ h₃
  exact_mod_cast e

/-- **`welfordC_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24` and every
choice `c` of contraction at each node (`(c p).1` for the mean's pair at position `p`, `(c p).2`
for the sum's): if the inputs' words and the three words of Welford's merge are finite, the
count word is the number of leaves, the mean word is within `(welfErr u η 2 ^ k depth).1` of the
leaves' mean and the sum word within
`2 ^ k · (welfErr u η 2 ^ k depth).2` of their sum of squared deviations, with the bound
`B = 2 ^ k` of `iota_bound`. -/
theorem welfordC_iota (c : List Bool → Bool × Bool) (k : ℕ) (hk : k ≤ 24)
    (hf : ∀ j, (iota (2 ^ k) j).isFinite = true)
    (h₁ : (welfordC c (halveFin k) (iota _)).1.isFinite = true)
    (h₂ : (welfordC c (halveFin k) (iota _)).2.1.isFinite = true)
    (h₃ : (welfordC c (halveFin k) (iota _)).2.2.isFinite = true) :
    (welfordC c (halveFin k) (iota _)).1.toReal = (halveFin k).leaves.length ∧
      |(welfordC c (halveFin k) (iota _)).2.1.toReal -
          ((halveFin k).leaves.map fun j => (iota _ j).toReal).sum / (halveFin k).leaves.length| ≤
        (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
          (halveFin k).depth).1 ∧
      |(welfordC c (halveFin k) (iota _)).2.2.toReal -
          (((halveFin k).leaves.map fun j => (iota _ j).toReal ^ 2).sum -
            ((halveFin k).leaves.map fun j => (iota _ j).toReal).sum ^ 2 /
              (halveFin k).leaves.length)| ≤
        (halveFin k).leaves.length *
          (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
            (halveFin k).depth).2 := by
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have e := welfordC_error rfl c (halveFin k) (iota _) (fun j _ => iota_bound hn hf j)
    (by rw [(leaves_halveFin k).length_eq, List.length_finRange]; exact hn) le_rfl h₁ h₂ h₃
  exact_mod_cast e

/-- **`wloop_error` at `1, ..., 2 ^ k` in order**, for every `k ≤ 24` and every choice `c` of
contraction at each iteration (`(c i).1` for the mean's pair at iteration `i`, `(c i).2` for the
sum's): if the inputs' words and the three words of Welford's loop are
finite, the count word is `2 ^ k`, the mean word is within `(welfErr u η 2 ^ k (2 ^ k - 1)).1` of
the inputs' mean and the sum word within `2 ^ k · (welfErr u η 2 ^ k (2 ^ k - 1)).2` of their sum
of squared deviations, with the bound `B = 2 ^ k` of `iota_bound`. -/
theorem wloop_iota (c : ℕ → Bool × Bool) (k : ℕ) (hk : k ≤ 24)
    (hf : ∀ j, (iota (2 ^ k) j).isFinite = true)
    (h₁ : (wloop c (List.ofFn (iota (2 ^ k)))).1.isFinite = true)
    (h₂ : (wloop c (List.ofFn (iota (2 ^ k)))).2.1.isFinite = true)
    (h₃ : (wloop c (List.ofFn (iota (2 ^ k)))).2.2.isFinite = true) :
    (wloop c (List.ofFn (iota (2 ^ k)))).1.toReal = (List.ofFn (iota (2 ^ k))).length ∧
      |(wloop c (List.ofFn (iota (2 ^ k)))).2.1.toReal -
          ((List.ofFn (iota (2 ^ k))).map Model.toReal).sum / (List.ofFn (iota (2 ^ k))).length| ≤
        (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
          ((List.ofFn (iota (2 ^ k))).length - 1)).1 ∧
      |(wloop c (List.ofFn (iota (2 ^ k)))).2.2.toReal -
          (((List.ofFn (iota (2 ^ k))).map fun x => x.toReal ^ 2).sum -
            ((List.ofFn (iota (2 ^ k))).map Model.toReal).sum ^ 2 /
              (List.ofFn (iota (2 ^ k))).length)| ≤
        (List.ofFn (iota (2 ^ k))).length *
          (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
            ((List.ofFn (iota (2 ^ k))).length - 1)).2 := by
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have e := wloop_error rfl c (List.ofFn (iota (2 ^ k))) (B := ((2 ^ k : ℕ) : ℝ))
    (fun x hx => by
      obtain ⟨j, rfl⟩ := List.mem_ofFn.1 hx
      exact iota_bound hn hf j)
    (by rw [List.length_ofFn]; exact hn) h₁ h₂ h₃
  exact_mod_cast e

/-- **`wmean_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24`: if the inputs'
words and the three words of Welford's merge are finite, the mean word is within
`(welfErr u η 2 ^ k depth).1` of `𝔼 j, j + 1`. -/
theorem wmean_iota (k : ℕ) (hk : k ≤ 24) (hf : ∀ j, (iota (2 ^ k) j).isFinite = true)
    (h₁ : (welford (halveFin k) (iota _)).1.isFinite = true)
    (h₂ : (welford (halveFin k) (iota _)).2.1.isFinite = true)
    (h₃ : (welford (halveFin k) (iota _)).2.2.isFinite = true) :
    |(welford (halveFin k) (iota _)).2.1.toReal - 𝔼 j, (iota (2 ^ k) j).toReal| ≤
      (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
        (halveFin k).depth).1 := by
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have e := wmean_error rfl (halveFin k) (leaves_halveFin k) (iota _) (iota_bound hn hf) hn
    h₁ h₂ h₃
  exact_mod_cast e

/-- **`wvar_error` at `1, ..., 2 ^ k` along `halveFin k`**, for every `k ≤ 24`: if the inputs'
words, the three words of Welford's merge and the variance word are finite, the variance word
approximates `TorchLean.var` of the real values with the mixed error
`(u, (1 + u) · (welfErr u η 2 ^ k depth).2 + η)`. -/
theorem wvar_iota (k : ℕ) (hk : k ≤ 24) (hf : ∀ j, (iota (2 ^ k) j).isFinite = true)
    (h₁ : (welford (halveFin k) (iota _)).1.isFinite = true)
    (h₂ : (welford (halveFin k) (iota _)).2.1.isFinite = true)
    (h₃ : (welford (halveFin k) (iota _)).2.2.isFinite = true)
    (h : (wvar (halveFin k) (iota _)).isFinite = true) :
    MixedError (wvar (halveFin k) (iota _)).toReal (TorchLean.var fun j => (iota (2 ^ k) j).toReal)
      (Model.unitRoundoffAt .binary32)
      ((1 + Model.unitRoundoffAt .binary32) *
          (welfErr (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32) (2 ^ k)
            (halveFin k).depth).2 +
        Model.underflowErrorAt .binary32) := by
  have hn : 2 ^ k ≤ 2 ^ 24 := Nat.pow_le_pow_right (by decide) hk
  have e := wvar_error rfl (halveFin k) (leaves_halveFin k) (iota _) (iota_bound hn hf) hn
    h₁ h₂ h₃ h
  exact_mod_cast e

/-- **The instance of `welford_iota` at `1, 2, 3, 4` along `pairs`**, a test of one example: the
words are finite (by evaluation), with the count `4`, the mean `2.5` and the sum of squared
deviations `5`. -/
theorem welford_xs := welford_iota 2 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel)

/-- **The instance of `welford_iota` at `1, ..., 8`**, a test of one example: the words are
finite (by evaluation), with the count `8`, the mean `4.5` and the sum of squared deviations
`42`. -/
theorem welford8 := welford_iota 3 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel)

/-- **The instance of `wmean_iota` at `1, 2, 3, 4` along `pairs`**, a test of one example. -/
theorem wmean_xs := wmean_iota 2 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel)

/-- **The instance of `wmean_iota` at `1, ..., 8`**, a test of one example. -/
theorem wmean8 := wmean_iota 3 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel)

/-- **The instance of `wvar_iota` at `1, 2, 3, 4` along `pairs`**, a test of one example: the
variance word `1.25` is finite (by evaluation). -/
theorem wvar_xs := wvar_iota 2 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `wvar_iota` at `1, ..., 8`**, a test of one example: the variance word
`5.25` is finite (by evaluation). -/
theorem wvar8 := wvar_iota 3 (by norm_num) (by decide +kernel) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `welfordC_iota` at `1, 2, 3, 4` along `pairs`, both pairs fused at every
node**, a test of one example: the words are finite (by evaluation), with the count `4`, the mean
`2.5` and the sum of squared deviations `5`. -/
theorem welfordC_xs := welfordC_iota (fun _ => (true, true)) 2 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `welfordC_iota` at `1, ..., 8`, both pairs fused at every node**, a test
of one example: the words are finite (by evaluation), with the count `8`, the mean `4.5` and the
sum of squared deviations `42`. -/
theorem welfordC8 := welfordC_iota (fun _ => (true, true)) 3 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `wloop_iota` at `1, 2, 3, 4`, no pair fused at any iteration**, a test of
one example: the three words of the loop are finite (by evaluation). -/
theorem wloop_xs := wloop_iota (fun _ => (false, false)) 2 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `wloop_iota` at `1, ..., 8`, both pairs fused at every iteration**, a test
of one example: the three words of the loop are finite (by evaluation). -/
theorem wloop8 := wloop_iota (fun _ => (true, true)) 3 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- A choice of contraction at each node that is not uniform, a test fixture: at the node at
position `p` (root first), the mean's pair is fused when the node's depth `p.length` is even, and
the sum's when the node lies in the root's right subtree (`p` starts with `true`), the root
excepted. -/
def altNode (p : List Bool) : Bool × Bool := (p.length % 2 == 0, p.head? == some true)

/-- A choice of contraction at each iteration that is not uniform, a test fixture: at iteration
`i`, the mean's pair is fused when `i` is even, and the sum's when `i % 3 = 1`. -/
def altIter (i : ℕ) : Bool × Bool := (i % 2 == 0, i % 3 == 1)

-- `altNode` differs between the root, its left child and its right child, and `altIter` takes
-- three different values on the first four iterations, so neither is a uniform policy.
#guard altNode [] != altNode [false] && altNode [false] != altNode [true] &&
  altNode [] != altNode [true]
#guard (List.range 4).map altIter = [(true, false), (false, true), (true, false), (false, false)]

/-- **The instance of `welfordC_iota` at `1, 2, 3, 4` along `pairs`, at the choice `altNode`**, a
test of one example: the words are finite (by evaluation), with the count `4`, the mean `2.5` and
the sum of squared deviations `5`. -/
theorem welfordC_alt4 := welfordC_iota altNode 2 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `welfordC_iota` at `1, ..., 8`, at the choice `altNode`**, a test of one
example: the words are finite (by evaluation), with the count `8`, the mean `4.5` and the sum of
squared deviations `42`. -/
theorem welfordC_alt8 := welfordC_iota altNode 3 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `wloop_iota` at `1, 2, 3, 4`, at the choice `altIter`**, a test of one
example: the three words of the loop are finite (by evaluation). -/
theorem wloop_alt4 := wloop_iota altIter 2 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **The instance of `wloop_iota` at `1, ..., 8`, at the choice `altIter`**, a test of one
example: the three words of the loop are finite (by evaluation). -/
theorem wloop_alt8 := wloop_iota altIter 3 (by norm_num) (by decide +kernel)
  (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- **`welford` is the fold of `wmerge`**, a test of the unfused merge, for every tree and binary32
words: `welford t x` is the tree's fold `ReductionTree.eval wmerge` of the single states
`wsingle (x j)`, since the constant choice `(false, false)` runs `wmergeC false false`, which is
`wmerge`, at every node. -/
theorem welford_eq_eval {ι : Type} (t : ReductionTree ι) (x : ι → Model .binary32) :
    welford t x = t.eval wmerge fun j => wsingle (x j) := by
  show welfordC (fun _ => (false, false)) t x = _
  induction t with
  | leaf j => rfl
  | node a b iha ihb => exact congrArg₂ (wmergeC false false) iha ihb

end MojoProofTest.FloatWelford
