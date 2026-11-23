import MojoProof.Sem.Grid
import MojoProof.Float.Tree
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
- `leaves_bfly`: for every `k`, offsets that are `1, 2, ..., 2 ^ (k - 1)` in any order and lane
  below `2 ^ k`, the lane has every lane below `2 ^ k` as a leaf exactly once; `leaves_warp` is its
  case at a warp's offsets (`warpOffsets`, `k = 5`).
- `shflSource_bfly`: the semantics' source lane of a butterfly shuffle with clamp 31
  (`shflSource`, MojoProof/Sem/Grid.lean) is `l ^^^ m` for lanes and offsets below 32.
- `bfly_warp_error`, for every carrier, combining operation, offsets `ms`, values, lane and width
  `w` whose lanes below `w` are the lane's leaves, each once: FloatLib's error bound for a
  reduction tree of depth `d` (FloatLib/Numerics/Reduction/Error.lean, through `eval_error` of
  MojoProof/Float/Tree.lean) for the rounds: if every
  combination at a node of the lane's tree is within `u` relative to its operands, the lane's
  result is within `((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` of `Σ_{j<w} v j`. At a warp's
  offsets (`leaves_warp`, `w = 32`) the bound is `((1 + u) ^ 5 - 1) · Σ_{j<32} |v j|`.
- `bfly_add_error`, for every IEEE format, offsets, values, lane and width `w` whose lanes below
  `w` are the lane's leaves, each once: if the lane's result of FloatLib's `Model.add` after the
  rounds is finite, every value below `w` is finite and the result is within
  `((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` of `Σ_{j<w} v j`, with `u` FloatLib's unit roundoff
  (FloatLib's bound for a finite IEEE reduction tree, through `sum_error` of
  MojoProof/Float/Tree.lean). At binary32 and a warp's offsets (`leaves_warp`, `w = 32`) the bound
  is `((1 + 2 ^ -24) ^ 5 - 1) · Σ_{j<32} |v j|`; at `2 ^ k` lanes and offsets
  `1, ..., 2 ^ (k - 1)` in any order (`leaves_bfly`) it is `((1 + u) ^ k - 1) · Σ_{j<2^k} |v j|`.
- `bflyRounds_congr`, for every carrier, combining operation, offsets and lane: the lane's value
  after the rounds depends only on the values at the leaves of its tree.

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

/-- **Butterflies of any width and order.** For every `k`, offsets `ms` that are a permutation of
`1, 2, 4, ..., 2 ^ (k - 1)` (the rounds in any order) and lane `l < 2 ^ k`, the leaves of lane
`l`'s tree are a permutation of the lanes `0, ..., 2 ^ k - 1`: every lane below `2 ^ k` once. -/
theorem leaves_bfly {k : Nat} {ms : List Nat} (hms : ms.Perm ((List.range k).map (2 ^ ·)))
    {l : Nat} (hl : l < 2 ^ k) : (bflyTree ms l).leaves.Perm (List.range (2 ^ k)) := by
  -- As multisets, lane `l`'s leaves are lane 0's leaves XOR `l`; a round with offset `m` adds
  -- lane 0's leaves XOR `m` to them.
  have hx : ∀ ms : List Nat, ∀ l, ((bflyTree ms l).leaves : Multiset Nat) =
      (ms.foldl (fun (M : Multiset Nat) m => M + M.map (m ^^^ ·)) {0}).map (l ^^^ ·) := by
    intro ms
    induction ms using List.reverseRecOn with
    | nil => intro l; simp [bflyTree, ReductionTree.leaves]
    | append_singleton ms m ih =>
      intro l
      rw [show bflyTree (ms ++ [m]) l = .node (bflyTree ms l) (bflyTree ms (l ^^^ m)) by
          simp only [bflyTree, List.foldl_append, List.foldl_cons, List.foldl_nil],
        ReductionTree.leaves, ← Multiset.coe_add, ih, ih]
      simp only [List.foldl_append, List.foldl_cons, List.foldl_nil, Multiset.map_add,
        Multiset.map_map, Function.comp_def, Nat.xor_assoc]
  -- Two rounds commute, so lane 0's leaves depend only on the multiset of the offsets.
  have hc : ms.foldl (fun (M : Multiset Nat) m => M + M.map (m ^^^ ·)) {0} =
      ((List.range k).map (2 ^ ·)).foldl (fun (M : Multiset Nat) m => M + M.map (m ^^^ ·)) {0} := by
    refine hms.foldl_eq' (fun x _ y _ M => ?_) _
    simp only [Multiset.map_add, Multiset.map_map, Function.comp_def]
    rw [show (fun z => y ^^^ (x ^^^ z)) = fun z => x ^^^ (y ^^^ z) from funext fun z => by
      rw [← Nat.xor_assoc, Nat.xor_comm y x, Nat.xor_assoc]]
    abel
  -- In the order `1, 2, ..., 2 ^ (k - 1)`, lane 0's leaves are `0, ..., 2 ^ k - 1`.
  have hr : ∀ k, ((List.range k).map (2 ^ ·)).foldl
      (fun (M : Multiset Nat) m => M + M.map (m ^^^ ·)) {0} =
        (List.range (2 ^ k) : Multiset Nat) := by
    intro k
    induction k with
    | zero => simp
    | succ k ih =>
      have h2 : ∀ j < 2 ^ k, 2 ^ k ^^^ j = 2 ^ k + j := fun j hj => by
        have hd : (2 ^ k ^^^ j) / 2 ^ k = 1 := by
          rw [Nat.xor_div_two_pow, Nat.div_self (Nat.two_pow_pos k), Nat.div_eq_of_lt hj,
            Nat.xor_zero]
        have hm : (2 ^ k ^^^ j) % 2 ^ k = j := by
          rw [Nat.xor_mod_two_pow, Nat.mod_self, Nat.mod_eq_of_lt hj, Nat.zero_xor]
        have := Nat.div_add_mod (2 ^ k ^^^ j) (2 ^ k)
        rw [hd, hm, Nat.mul_one] at this
        exact this.symm
      simp only [List.range_succ, List.map_append, List.map_cons, List.map_nil, List.foldl_append,
        List.foldl_cons, List.foldl_nil, ih, Multiset.map_coe, Multiset.coe_add]
      rw [Nat.pow_succ, Nat.mul_two, List.range_add,
        List.map_congr_left fun j hj => h2 j (List.mem_range.1 hj)]
  -- XOR with a lane below `2 ^ k` permutes the lanes below `2 ^ k`.
  have hp : ((List.range (2 ^ k)).map (l ^^^ ·)).Perm (List.range (2 ^ k)) := by
    refine List.Subperm.perm_of_length_le (List.Nodup.subperm (List.Nodup.map ?_ List.nodup_range)
      ?_) (by simp)
    · intro a b h
      simpa [← Nat.xor_assoc] using congrArg (l ^^^ ·) h
    · intro x hx
      obtain ⟨a, ha, rfl⟩ := List.mem_map.1 hx
      exact List.mem_range.2 (Nat.xor_lt_two_pow hl (List.mem_range.1 ha))
  rw [← Multiset.coe_eq_coe, hx, hc, hr, Multiset.map_coe, Multiset.coe_eq_coe]
  exact hp

/-- At a warp's offsets, for every lane below 32, the leaves of the lane's tree are a permutation
of the lanes `0, ..., 31`: `leaves_bfly` at `k = 5`. -/
theorem leaves_warp : ∀ l < 32, (bflyTree warpOffsets l).leaves.Perm (List.range 32) :=
  fun _ hl => leaves_bfly (k := 5) (by decide) hl

/-- For all lanes and offsets below 32, a butterfly shuffle with clamp 31 reads lane `l ^^^ m`. -/
theorem shflSource_bfly {l m : Nat} (hl : l < 32) (hm : m < 32) :
    shflSource .bfly l m 31 = l ^^^ m := by
  have : l ^^^ m < 2 ^ 5 := Nat.xor_lt_two_pow hl hm
  simp [shflSource, Nat.mod_eq_of_lt hm]
  omega

/-- **The butterfly within FloatLib's tree bound.** For every carrier, combining operation,
values `v`, map `interpret` to the reals, `u ≥ 0`, offsets `ms`, lane `l` and width `w` such that
the leaves of lane `l`'s tree are the lanes `0, ..., w - 1`, each once (at a warp's offsets and
`l < 32`, `leaves_warp` with `w = 32`): if every combination at a node of lane `l`'s tree is within
`u · (|x| + |y|)` of the exact sum of its operands `x`, `y`, then lane `l`'s value after the
rounds is within `((1 + u) ^ ms.length - 1) · Σ_{j<w} |interpret (v j)|` of
`Σ_{j<w} interpret (v j)`: `eval_error` (FloatLib's `abs_eval_sub_exact_le_depth`) at lane `l`'s
tree. -/
theorem bfly_warp_error {β : Type} (combine : β → β → β) (v : Nat → β) (interpret : β → ℝ)
    (u : ℝ) (hu : 0 ≤ u) {ms : List Nat} {w l : Nat}
    (hp : (bflyTree ms l).leaves.Perm (List.range w))
    (h : (bflyTree ms l).AllNodes combine v (fun x y =>
      |interpret (combine x y) - (interpret x + interpret y)| ≤
        u * (|interpret x| + |interpret y|))) :
    |interpret (bflyRounds combine ms v l) - ((List.range w).map (interpret ∘ v)).sum| ≤
      ((1 + u) ^ ms.length - 1) * ((List.range w).map fun j => |interpret (v j)|).sum := by
  simpa only [eval_bflyTree, depth_bflyTree] using
    Float.eval_error combine v interpret u hu _ hp h

open FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange in
/-- **The butterfly of IEEE additions within FloatLib's tree bound.** In every IEEE format, for
all values `v`, offsets `ms`, lanes `l` and widths `w` such that the leaves of lane `l`'s tree are
the lanes `0, ..., w - 1`, each once (at a warp's offsets and `l < 32`, `leaves_warp` with
`w = 32`): if lane `l`'s value after the rounds of FloatLib's `Model.add` is finite, then every
`v j` with `j < w` is finite, and that value is within
`((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` of `Σ_{j<w} v j`, the real values of the words, with
`u` FloatLib's unit roundoff `Model.unitRoundoffAt fmt`: `sum_error` at lane `l`'s tree. Nothing
is claimed when the result is infinite or a NaN. -/
theorem bfly_add_error {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (v : Nat → Model fmt)
    {ms : List Nat} {w l : Nat} (hp : (bflyTree ms l).leaves.Perm (List.range w))
    (h : (bflyRounds (fun x y => Model.add x y) ms v l).isFinite = true) :
    (∀ j < w, (v j).isFinite = true) ∧
      |(bflyRounds (fun x y => Model.add x y) ms v l).toReal -
          ((List.range w).map fun j => (v j).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt fmt) ^ ms.length - 1) *
          ((List.range w).map fun j => |(v j).toReal|).sum := by
  simpa only [eval_bflyTree, depth_bflyTree, List.mem_range] using
    Float.sum_error hfmt _ v hp (by rwa [eval_bflyTree])

/-- **A lane's rounds read only its tree's leaves.** For every carrier, combining operation,
offsets `ms`, lane `l` and families `v`, `v'` that agree at every leaf of `bflyTree ms l`, lane
`l`'s value after the rounds is the same (`eval_bflyTree`, by induction on the tree). -/
theorem bflyRounds_congr {β : Type} (combine : β → β → β) (ms : List Nat) {v v' : Nat → β}
    (l : Nat) (h : ∀ j ∈ (bflyTree ms l).leaves, v j = v' j) :
    bflyRounds combine ms v l = bflyRounds combine ms v' l := by
  rw [← eval_bflyTree, ← eval_bflyTree]
  generalize bflyTree ms l = t at h ⊢
  induction t with
  | leaf x => exact h x (List.mem_singleton_self x)
  | node a b ha hb =>
    simp only [ReductionTree.leaves, List.mem_append] at h
    exact congrArg₂ combine (ha fun j hj => h j (.inl hj)) (hb fun j hj => h j (.inr hj))

end MojoProof.Sem
