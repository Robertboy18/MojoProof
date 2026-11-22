import MojoProof.Sem.Grid
import FloatLib.Numerics.Reduction.Error
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.StandardModel

/-!
# The warp butterfly as a reduction tree

A warp reduction by butterfly shuffles: in each round with offset `m`, lane `l` combines its own
value with the value of lane `l ^^^ m` (`shfl.sync.bfly`). Both kernels of tests/corpus/gemv/ end
with five such rounds, offsets 16, 8, 4, 2, 1, each an `fadd contract` of the lane's value and the
shuffled one. docs/proofs/bfly.md has the informal argument. Proved here, about the rounds as
functions of the lanes' values:

- `eval_bflyTree`, for every carrier, combining operation, offsets, values and lane: the value of
  a lane after the rounds is the evaluation of a fixed FloatLib `ReductionTree` of lane numbers
  (`bflyTree`); `depth_bflyTree`: that tree's depth is the number of rounds, for every lane.
- `leaves_warp`: at a warp's offsets (`warpOffsets`), each lane below 32 has every lane below 32
  as a leaf exactly once (by `decide +kernel`).
- `shflSource_bfly`: the semantics' source lane of a butterfly shuffle with clamp 31
  (`shflSource`, MojoProof/Sem/Grid.lean) is `l ^^^ m` for lanes and offsets below 32.
- `bfly_warp_error`: FloatLib's error bound for a reduction tree of depth `d`
  (FloatLib/Numerics/Reduction/Error.lean) for the five rounds: if every combination at a node of
  the lane's tree is within `u` relative to its operands, the lane's result is within
  `((1 + u) ^ 5 - 1) · Σ |v j|` of `Σ v j` over the 32 lanes; `bfly_warp_add`: so with
  FloatLib's binary32 addition, `u = 2 ^ -24`, when every node's sum is finite.

That a grid run of a kernel computes `bflyRounds` is not proved here. The instances and the twin
(offsets that repeat a round) are in MojoProofTest/Bfly.lean.
-/

namespace MojoProof.Sem

open FloatLib.Numerics LLVM

/-- The values after one butterfly round with offset `m`: lane `l` combines its own value with
lane `l ^^^ m`'s, its own first. -/
def bflyRound {β : Type} (combine : β → β → β) (m : Nat) (v : Nat → β) : Nat → β :=
  fun l => combine (v l) (v (l ^^^ m))

/-- The values after the butterfly rounds with offsets `ms`, first to last. -/
def bflyRounds {β : Type} (combine : β → β → β) (ms : List Nat) (v : Nat → β) : Nat → β :=
  ms.foldl (fun v m => bflyRound combine m v) v

/-- The schedule of lane `l` after the butterfly rounds with offsets `ms`, a FloatLib
`ReductionTree` of lane numbers: with no rounds the leaf `l`; a round with offset `m` makes lane
`l`'s tree the node of its own tree and lane `l ^^^ m`'s. -/
def bflyTree (ms : List Nat) : Nat → ReductionTree Nat :=
  ms.foldl (fun T m l => .node (T l) (T (l ^^^ m))) .leaf

/-- The offsets of a warp's five butterfly rounds, `16, 8, 4, 2, 1`, as in tests/corpus/gemv/. -/
def warpOffsets : List Nat := [16, 8, 4, 2, 1]

/-- For every carrier, combining operation, offsets, values and lane, lane `l`'s value after the
butterfly rounds is the evaluation of its tree `bflyTree ms l` at the lanes' values. -/
theorem eval_bflyTree {β : Type} (combine : β → β → β) (ms : List Nat) (v : Nat → β) (l : Nat) :
    (bflyTree ms l).eval combine v = bflyRounds combine ms v l := by
  suffices h : ∀ (T : Nat → ReductionTree Nat) (w : Nat → β), (∀ l, (T l).eval combine v = w l) →
      ∀ l, (ms.foldl (fun T m l => .node (T l) (T (l ^^^ m))) T l).eval combine v =
        ms.foldl (fun v m => bflyRound combine m v) w l from
    h .leaf v (fun _ => rfl) l
  induction ms with
  | nil => exact fun T w h l => h l
  | cons m ms ih =>
    intro T w h l
    exact ih _ _ (fun l => by simp only [ReductionTree.eval, bflyRound, h]) l

/-- For all offsets and every lane, the tree of the lane after the butterfly rounds has depth
the number of rounds. -/
theorem depth_bflyTree (ms : List Nat) (l : Nat) : (bflyTree ms l).depth = ms.length := by
  suffices h : ∀ (T : Nat → ReductionTree Nat) (d : Nat), (∀ l, (T l).depth = d) →
      ∀ l, (ms.foldl (fun T m l => .node (T l) (T (l ^^^ m))) T l).depth = d + ms.length from
    (h .leaf 0 (fun _ => rfl) l).trans (Nat.zero_add _)
  induction ms with
  | nil => exact fun T d h l => h l
  | cons m ms ih =>
    intro T d h l
    rw [List.foldl_cons, ih (fun l => .node (T l) (T (l ^^^ m))) (d + 1)
      (fun l => by simp only [ReductionTree.depth, h, Nat.max_self]) l, List.length_cons]
    omega

/-- At a warp's offsets, for every lane below 32, the leaves of the lane's tree are a permutation
of the lanes `0, ..., 31`, by `decide +kernel`. -/
theorem leaves_warp : ∀ l < 32, (bflyTree warpOffsets l).leaves.Perm (List.range 32) := by
  decide +kernel

/-- For all lanes and offsets below 32, a butterfly shuffle with clamp 31 reads lane `l ^^^ m`. -/
theorem shflSource_bfly {l m : Nat} (hl : l < 32) (hm : m < 32) :
    shflSource .bfly l m 31 = l ^^^ m := by
  have : l ^^^ m < 2 ^ 5 := Nat.xor_lt_two_pow hl hm
  simp [shflSource, Nat.mod_eq_of_lt hm]
  omega

/-- **The warp's butterfly within FloatLib's tree bound.** For every carrier, combining
operation, values `v`, map `interpret` to the reals, `u ≥ 0` and lane `l < 32`: if every
combination at a node of lane `l`'s tree is within `u · (|x| + |y|)` of the exact sum of its
operands `x`, `y`, then lane `l`'s value after the five rounds is within
`((1 + u) ^ 5 - 1) · Σ_{j<32} |interpret (v j)|` of `Σ_{j<32} interpret (v j)`. -/
theorem bfly_warp_error {β : Type} (combine : β → β → β) (v : Nat → β) (interpret : β → ℝ)
    (u : ℝ) (hu : 0 ≤ u) {l : Nat} (hl : l < 32)
    (h : (bflyTree warpOffsets l).AllNodes combine v (fun x y =>
      |interpret (combine x y) - (interpret x + interpret y)| ≤
        u * (|interpret x| + |interpret y|))) :
    |interpret (bflyRounds combine warpOffsets v l) - ((List.range 32).map (interpret ∘ v)).sum| ≤
      ((1 + u) ^ 5 - 1) * ((List.range 32).map fun j => |interpret (v j)|).sum := by
  have e := (bflyTree warpOffsets l).abs_eval_sub_exact_le_depth combine v interpret u hu h
  rw [eval_bflyTree, depth_bflyTree, ReductionTree.eval_add_eq_sum,
    ((leaves_warp l hl).map _).sum_eq] at e
  rw [ReductionTree.sumAbs, ReductionTree.eval_add_eq_sum,
    ((leaves_warp l hl).map _).sum_eq] at e
  simpa [warpOffsets] using e

open FloatLib.Floats.Formats.BinaryInterchange in
/-- **The warp's butterfly in binary32.** For all binary32 values `v` and every lane `l < 32`, if
FloatLib's addition has a finite result at every node of lane `l`'s tree, lane `l`'s value after
the five rounds of `Model.add` is within `((1 + 2 ^ -24) ^ 5 - 1) · Σ_{j<32} |v j|` of
`Σ_{j<32} v j` (`Model.unitRoundoffAt .binary32 = 2 ^ -24`; FloatLib's
`Model.abs_toReal_add_sub_le_unitRoundoffAt` gives each node's bound). -/
theorem bfly_warp_add (v : Nat → Model .binary32) {l : Nat} (hl : l < 32)
    (h : (bflyTree warpOffsets l).AllNodes (fun x y => Model.add x y) v
      (fun x y => (Model.add x y).isFinite = true)) :
    |(bflyRounds (fun x y => Model.add x y) warpOffsets v l).toReal -
        ((List.range 32).map fun j => (v j).toReal).sum| ≤
      ((1 + Model.unitRoundoffAt .binary32) ^ 5 - 1) *
        ((List.range 32).map fun j => |(v j).toReal|).sum := by
  have imp : ∀ t : ReductionTree Nat, t.AllNodes (fun x y => Model.add x y) v
      (fun x y => (Model.add x y).isFinite = true) →
      t.AllNodes (fun x y => Model.add x y) v (fun x y =>
        |(Model.add x y).toReal - (x.toReal + y.toReal)| ≤
          Model.unitRoundoffAt .binary32 * (|x.toReal| + |y.toReal|)) := by
    intro t
    induction t with
    | leaf _ => exact fun _ => trivial
    | node a b ha hb =>
      intro ⟨h1, h2, h3⟩
      exact ⟨ha h1, hb h2, (Model.abs_toReal_add_sub_le_unitRoundoffAt _ _ rfl h3).trans
        (mul_le_mul_of_nonneg_left (abs_add_le _ _) (Model.unitRoundoffAt_pos _).le)⟩
  exact bfly_warp_error _ v Model.toReal _ (Model.unitRoundoffAt_pos _).le hl (imp _ h)

end MojoProof.Sem
