import MojoProof.Float.Tree
import MojoProof.Sem.Bfly

/-!
# Block reductions through shared memory (docs/proofs/float-reductions.md)

A block reduction through shared memory halves the active cells each round: with stride `s`,
every thread `c < s` combines cell `c + s` into cell `c`, for the strides `2 ^ (k - 1), ..., 2, 1`
over `2 ^ k` cells, with a barrier between rounds. This module gives that loop as rounds of
MojoProof/Float/Tree.lean, so cell 0's result is the evaluation of a FloatLib `ReductionTree`,
and composes it with the warp butterfly of MojoProof/Sem/Bfly.lean.

Definitions: `halveStep s c`, the tree of cell `c`'s value after the round with stride `s`;
`halvings k`, the strides `2 ^ (k - 1), ..., 1`.

Proved:
* `leaves_halve`, `depth_halve`, for every `k`: cell 0's tree after the halving rounds over
  `2 ^ k` cells has every cell below `2 ^ k` as a leaf exactly once, and depth `k`.
* `halve_error`, in every IEEE format, for every `k` and values: if cell 0's sum after the
  halving rounds of FloatLib's `Model.add` is finite, every value below `2 ^ k` is finite and the
  sum is within `((1 + u) ^ k - 1) · Σ_{j<2^k} |v j|` of `Σ_{j<2^k} v j`.
* `block_error`, in every IEEE format, for every tree `T` over `W` warps (each warp once), offsets
  `ms` that are `1, 2, ..., 2 ^ (j - 1)` in any order and values of the `W · 2 ^ j` threads (thread
  `2 ^ j · w + l` is lane `l` of warp `w`): if the sum along `T` of each warp's lane 0 after its
  butterfly rounds is finite, every thread's value is finite and the sum is within
  `((1 + u) ^ (T.depth + j) - 1) · Σ |v|` of `Σ v`: the two stages are one tree, `T` grafted with
  the warps' butterfly trees, whose depth is the sum of the two depths. At `T` the halving tree
  over `2 ^ k` warps (`leaves_halve`, `depth_halve`) the depth is `k + j`.

The statements are about the rounds as functions of the values; that a grid run of a kernel
performs them is not proved here. The instances are in MojoProofTest/FloatTree.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  MojoProof.Sem

/-- The tree of cell `c`'s value after the halving round with stride `s`: a cell `c < s` combines
its own value with cell `c + s`'s, its own first; every other cell keeps its value. -/
def halveStep (s c : Nat) : ReductionTree Nat :=
  if c < s then .node (.leaf c) (.leaf (c + s)) else .leaf c

/-- The strides of the halving rounds over `2 ^ k` cells, first to last:
`2 ^ (k - 1), ..., 2, 1`. -/
def halvings (k : Nat) : List Nat := (List.range k).reverse.map (2 ^ ·)

/-- The halving rounds over `2 ^ (k + 1)` cells are the stride `2 ^ k`, then the rounds over
`2 ^ k` cells. -/
private theorem halvings_succ (k : Nat) : halvings (k + 1) = 2 ^ k :: halvings k := by
  simp [halvings, List.range_succ]

/-- For every `k`, cell 0's tree after the halving rounds over `2 ^ k` cells has the leaves
`0, ..., 2 ^ k - 1` up to order: every cell below `2 ^ k` exactly once. -/
theorem leaves_halve (k : Nat) :
    (roundsTree halveStep (halvings k) 0).leaves.Perm (List.range (2 ^ k)) := by
  induction k with
  | zero => exact .refl _
  | succ k ih =>
    rw [halvings_succ, roundsTree, leaves_graft]
    refine (ih.flatMap_right _).trans ?_
    rw [List.flatMap_congr (g := fun c => [c] ++ [c + 2 ^ k]) fun c hc => by
      simp [halveStep, List.mem_range.1 hc, ReductionTree.leaves]]
    refine (List.flatMap_append_perm _ _ _).symm.trans (.of_eq ?_)
    rw [List.flatMap_singleton', ← List.map_eq_flatMap, Nat.pow_succ, Nat.mul_two,
      List.range_add]
    exact congrArg _ (List.map_congr_left fun j _ => Nat.add_comm j _)

/-- For every `k`, cell 0's tree after the halving rounds over `2 ^ k` cells has depth `k`. -/
theorem depth_halve (k : Nat) : (roundsTree halveStep (halvings k) 0).depth = k := by
  induction k with
  | zero => rfl
  | succ k ih =>
    rw [halvings_succ, roundsTree, depth_graft _ _ (d := 1) fun c hc => by
      simp [halveStep, List.mem_range.1 ((leaves_halve k).mem_iff.1 hc), ReductionTree.depth], ih]

/-- **The halving loop of IEEE additions.** In every IEEE format, for every `k` and values `v`:
if cell 0's value after the halving rounds of FloatLib's `Model.add` over `2 ^ k` cells is
finite, every `v j` with `j < 2 ^ k` is finite and that value is within
`((1 + u) ^ k - 1) · Σ_{j<2^k} |v j|` of `Σ_{j<2^k} v j`, with `u` FloatLib's unit roundoff:
`sum_error` at cell 0's tree. Nothing is claimed when the result is infinite or a NaN. -/
theorem halve_error {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (k : Nat)
    (v : Nat → Model fmt)
    (h : (rounds (fun x y => Model.add x y) halveStep (halvings k) v 0).isFinite = true) :
    (∀ j < 2 ^ k, (v j).isFinite = true) ∧
      |(rounds (fun x y => Model.add x y) halveStep (halvings k) v 0).toReal -
          ((List.range (2 ^ k)).map fun j => (v j).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt fmt) ^ k - 1) *
          ((List.range (2 ^ k)).map fun j => |(v j).toReal|).sum := by
  simpa only [eval_roundsTree, depth_halve, List.mem_range] using
    sum_error hfmt _ v (leaves_halve k) (by rwa [eval_roundsTree])

/-- **A warp butterfly, then a tree over the warps.** In every IEEE format, for every tree `T`
whose leaves are the warps `0, ..., W - 1` up to order, offsets `ms` that are a permutation of
`1, 2, ..., 2 ^ (j - 1)` and values `v` of the threads, thread `2 ^ j · w + l` being lane `l` of
warp `w`: if the sum along `T` (FloatLib's `Model.add`) of each warp's lane 0 after its butterfly
rounds is finite, then every `v i` with `i < W · 2 ^ j` is finite and that sum is within
`((1 + u) ^ (T.depth + j) - 1) · Σ_{i<W·2^j} |v i|` of `Σ_{i<W·2^j} v i`, with `u` FloatLib's unit
roundoff. The two stages are one tree (`graft`) with the threads as leaves (`leaves_graft_range`,
`leaves_bfly`) and depth `T.depth + j` (`depth_graft`). With `T` the halving tree over `2 ^ k`
warps (`leaves_halve`, `depth_halve`, `eval_roundsTree`) the depth is `k + j`. Nothing is claimed
when the result is infinite or a NaN. -/
theorem block_error {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (T : ReductionTree Nat)
    {W j : Nat} (hT : T.leaves.Perm (List.range W)) {ms : List Nat}
    (hms : ms.Perm ((List.range j).map (2 ^ ·))) (v : Nat → Model fmt)
    (h : (T.eval (fun x y => Model.add x y) fun w =>
      bflyRounds (fun x y => Model.add x y) ms (fun l => v (2 ^ j * w + l)) 0).isFinite = true) :
    (∀ i < W * 2 ^ j, (v i).isFinite = true) ∧
      |(T.eval (fun x y => Model.add x y) fun w =>
          bflyRounds (fun x y => Model.add x y) ms (fun l => v (2 ^ j * w + l)) 0).toReal -
          ((List.range (W * 2 ^ j)).map fun i => (v i).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt fmt) ^ (T.depth + j) - 1) *
          ((List.range (W * 2 ^ j)).map fun i => |(v i).toReal|).sum := by
  have hv : (graft T fun w => (bflyTree ms 0).map (2 ^ j * w + ·)).eval
      (fun x y => Model.add x y) v = T.eval (fun x y => Model.add x y) fun w =>
        bflyRounds (fun x y => Model.add x y) ms (fun l => v (2 ^ j * w + l)) 0 := by
    rw [eval_graft]
    congr 1
    funext w
    rw [ReductionTree.eval_map]
    exact eval_bflyTree _ ms _ 0
  have hd : (graft T fun w => (bflyTree ms 0).map (2 ^ j * w + ·)).depth = T.depth + j :=
    depth_graft _ _ fun w _ => by
      rw [ReductionTree.depth_map, depth_bflyTree, hms.length_eq, List.length_map,
        List.length_range]
  have hl := leaves_graft_range T (fun w => (bflyTree ms 0).map (2 ^ j * w + ·)) hT
    fun w _ => by
      rw [ReductionTree.leaves_map]
      exact (leaves_bfly hms (Nat.two_pow_pos j)).map _
  simpa only [hv, hd, List.mem_range] using sum_error hfmt _ v hl (hv ▸ h)

end MojoProof.Float
