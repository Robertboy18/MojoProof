# The warp butterfly as a reduction tree (`bflyRounds`, `bflyRoundsAt`, `bflyOffsets`, `bflyTree`, `eval_bflyTree`, `depth_bflyTree`, `leaves_bfly`, `leaves_offsets`, `leaves_warp`, `shflSource_group`, `shflSource_bfly`, `bfly_warp_error`, `bfly_add_error`, `bflyRounds_congr`)

Lean: proved, for every carrier, combining operation, offsets, values and lane as stated below,
in MojoProof/Sem/Bfly.lean. Instances and twins: MojoProofTest/Bfly.lean. The tree type is
FloatLib's `FloatLib.Numerics.ReductionTree` (FloatLib/Numerics/Reduction/Tree.lean), and the
error bounds are FloatLib's `ReductionTree.abs_eval_sub_exact_le_depth`
(FloatLib/Numerics/Reduction/Error.lean) and, for IEEE additions,
`Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth`
(FloatLib/Floats/Formats/BinaryInterchange/Reduction/Tree.lean), stated for every tree as
`eval_error` and `sum_error` in MojoProof/Float/Tree.lean (float-reductions.md, statements 4 and
5). The statements are about the rounds as functions of the lanes' values; that a grid run of a
kernel computes them is not proved (see "Not proved").

## What the kernels compute

Both kernels of max/kernels/src/linalg/gemv.mojo in tests/corpus/gemv/ end their warp reduction
with five butterfly rounds. In `gemv_kernel` (gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll),
each warp computes one row: lane `l` (`%40`, `laneid`) adds the products of the columns `32 i + l`
into `%56` (blocks `%54` to `%77`), and then block `%78` runs

```
%79 = phi float [ %56, %59 ]
%80 = bitcast float %79 to i32
%81 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %80, i32 16, i32 31)
%82 = bitcast i32 %81 to float
%83 = fadd contract float %79, %82
```

and the same three lines (`bitcast`, `shfl.sync.bfly`, `bitcast`, then `fadd contract` of the
lane's own value and the shuffled one) with the offsets 8, 4, 2 and 1, ending in `%99`, which lane
0 (`%41 = icmp eq i64 %40, 0`) stores to the row's output (`%37`). `gevm_kernel`
(gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll) runs the same five rounds
on the value `%67` it loads from shared memory, ending in `%87`.

In the semantics (MojoProof/Sem/Grid.lean): a `shfl.sync` with the full member mask (`-1`) and
clamp 31 completes when every lane of the warp waits at it, and lane `l` receives the operand of
lane `shflSource .bfly l m 31`, which is `l ^^^ m` for `l, m < 32` (`shflSource_bfly`). A shuffle
within groups of `2 ^ k` lanes has the clamp `(32 - 2 ^ k) · 256 + 31` (the segment mask in bits
8-12), and its source is `l ^^^ m` for `m < 2 ^ k` (`shflSource_group`); the corpus's kernels use
clamp 31 only. A
`bitcast` from `float` to `i32` and back gives the same bits. The `fadd contract`'s operands are a
`phi` or an `fadd` result and a `bitcast`, never an `fmul contract` result, so `contract`
(MojoProof/Sem/Float.lean) is FloatLib's `Model.add` at every oracle number, through `deliver`,
which changes only a NaN result.

## Statements

Write `bflyRound combine m v` for the values after one round with offset `m`: lane `l` gets
`combine (v l) (v (l ^^^ m))`, its own value first, as in `fadd contract float %79, %82`.
`bflyRoundsAt F ms v` is the rounds with offsets `ms`, first to last, in which lane `l` of round
`r` (counted from `0`) combines by `F r l`; `bflyRounds combine ms v` is its case
`F r l = combine`. `bflyOffsets k` is `2 ^ (k - 1), ..., 2, 1`, the `k` rounds of a group of
`2 ^ k` lanes, and `warpOffsets` is by definition `bflyOffsets 5`, the offsets `16, 8, 4, 2, 1`.
`bflyTree ms l` is a `ReductionTree Nat` whose leaves are lane numbers: with
no rounds lane `l`'s tree is the leaf `l`, and a round with offset `m` makes lane `l`'s tree the
node of its own tree and lane `l ^^^ m`'s.

1. `eval_bflyTree`: for every carrier `β`, every `combine : β → β → β`, offsets `ms`, values
   `v : Nat → β` and lane `l`, evaluating lane `l`'s tree with `combine` at the leaves' values is
   lane `l`'s value after the rounds:
   `(bflyTree ms l).eval combine v = bflyRounds combine ms v l`.
2. `depth_bflyTree`: for all offsets and every lane, `(bflyTree ms l).depth = ms.length`; at a
   warp, 5.
3. `leaves_bfly`: for every `k`, offsets `ms` that are a permutation of
   `1, 2, 4, ..., 2 ^ (k - 1)` (the rounds in any order) and lane `l < 2 ^ k`, the leaves of
   `bflyTree ms l` are a permutation of `0, ..., 2 ^ k - 1`: each lane's value is a leaf exactly
   once. `leaves_offsets`: its case at `bflyOffsets k`, for every `k` and lane `l < 2 ^ k`;
   `leaves_warp` is `leaves_offsets` at `k = 5`, for every lane `l < 32`.
4. `shflSource_group`: for every `k ≤ 5`, lane `l < 32` and offset `m < 2 ^ k`,
   `shflSource .bfly l m ((32 - 2 ^ k) · 256 + 31) = l ^^^ m`: a butterfly shuffle within groups
   of `2 ^ k` lanes reads lane `l ^^^ m`. `shflSource_bfly` is its case `k = 5`: for all
   `l, m < 32`, `shflSource .bfly l m 31 = l ^^^ m`.
5. `bfly_warp_error`: for every carrier, `combine`, values `v`, map `interpret : β → ℝ`,
   `u ≥ 0`, offsets `ms`, lane `l` and width `w` such that the leaves of `bflyTree ms l` are a
   permutation of `0, ..., w - 1`: if at every node of lane `l`'s tree the combination of the
   operands `x`, `y` it meets is within `u · (|x| + |y|)` of their exact sum
   (`ReductionTree.AllNodes`), then
   `|interpret (bflyRounds combine ms v l) - Σ_{j<w} interpret (v j)|` is at most
   `((1 + u) ^ ms.length - 1) · Σ_{j<w} |interpret (v j)|`. At `warpOffsets`, `l < 32` and
   `w = 32` (statement 3) the bound is `((1 + u) ^ 5 - 1) · Σ_{j<32} |interpret (v j)|`; at `2 ^ k` lanes and
   offsets as in statement 3, `((1 + u) ^ k - 1) · Σ_{j<2^k} |interpret (v j)|`.
6. `bfly_add_error`: in every IEEE format, for every `v : Nat → Model fmt`, offsets `ms`, lane `l`
   and width `w` such that the leaves of `bflyTree ms l` are a permutation of `0, ..., w - 1`: if
   lane `l`'s value `r` after the rounds of `Model.add` is finite, then every `v j` with `j < w`
   is finite, and `|r - Σ_{j<w} v j| ≤ ((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` over the real
   values, with `u = Model.unitRoundoffAt fmt`. Only the root's sum is assumed finite. At
   binary32, `warpOffsets` and `w = 32` (statement 3) the bound is
   `((1 + 2 ^ -24) ^ 5 - 1) · Σ_{j<32} |v j|`, the binary32 case of statement 5 with
   `combine = Model.add` and `interpret = Model.toReal`, under a finite root only.
7. `bflyRounds_congr`: for every carrier, combining operation, offsets and lane, lane `l`'s value
   after the rounds depends only on the values of the leaves of `bflyTree ms l`: two families
   that agree there give the same value.

The depth 5 of the bound is `⌈log₂ 32⌉`, the least depth of any schedule over 32 inputs
(FloatLib's `clog_le_depth`); a loop over the 32 values (FloatLib's `leftChain`) has depth 31.

## Proofs

1. By induction on `ms`, for every starting family of trees `T` and values `w` with
   `(T l).eval combine v = w l` at every lane: a round makes both sides the combination of lane
   `l`'s and lane `l ^^^ m`'s, which are equal by the hypothesis. Start with `T = leaf`, `w = v`.
2. The same induction: if every lane's tree has depth `d`, after a round every lane's tree has
   depth `max d d + 1 = d + 1`.
3. As multisets, lane `l`'s leaves are lane 0's leaves XOR `l` (induction on the rounds from the
   last one: a round with offset `m` makes lane `l`'s leaves its own and lane `l ^^^ m`'s, and
   XOR is associative), and a round with offset `m` adds lane 0's leaves XOR `m` to them. Two
   rounds commute (`List.Perm.foldl_eq'`), so lane 0's leaves depend only on the multiset of the
   offsets; at `1, 2, ..., 2 ^ (k - 1)` in order they are `0, ..., 2 ^ k - 1`, by induction on
   `k` with `2 ^ k ^^^ j = 2 ^ k + j` for `j < 2 ^ k`. XOR with `l < 2 ^ k` permutes that list:
   it has no duplicates (XOR with `l` is injective) and stays below `2 ^ k`
   (`Nat.xor_lt_two_pow`). `leaves_offsets`: `bflyOffsets k` is the reverse of
   `1, 2, ..., 2 ^ (k - 1)`, so a permutation of it (`List.reverse_perm`).
4. Unfold `shflSource`: the clamp's low five bits are 31 and its segment mask is
   `32 - 2 ^ k = 2 ^ k (2 ^ (5 - k) - 1)`, whose bits are those from `k` to 4, and `m % 32 = m`.
   The largest lane `(l &&& seg) ||| (31 &&& (31 ^^^ seg))` has every bit below `k` and `l`'s
   bits from `k` to 4; `l ^^^ m` has `l`'s bits from `k` on (`m < 2 ^ k`) and no bit from 5 on
   (`l < 32`), so it is at most the largest lane, bit by bit (`Nat.le_of_testBit`), and in
   range.
5. `eval_error` (FloatLib's `abs_eval_sub_exact_le_depth` with the sums over the permuted
   leaves) at lane `l`'s tree, rewritten by statement 1 on the computed side and statement 2 for
   the depth.
6. `sum_error` at lane `l`'s tree, rewritten the same way. In it, a finite IEEE sum has finite
   operands (FloatLib's `Model.isFinite_of_isFinite_add`), so by induction on the tree a finite
   root gives FloatLib's `FiniteEval` of the tree mapped by `v`, the leaves of such a tree are
   finite, and FloatLib's `Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth` bounds it.
7. Statement 1 on both sides, then induction on the tree: a leaf's value is the family's at the
   leaf, and a node's leaves are its two subtrees'.

## Instances and twins

- `lane0_leaves`: lane 0's leaves are `0, 16, 8, 24, 4, 20, 12, 28, 2, ...`, the lanes in
  bit-reversed order, by evaluation; `bfly_sum`: with `combine = (· + ·)` on `Nat` and
  `v j = j`, every lane ends with `0 + ... + 31 = 496`, by evaluation (`decide +kernel`).
- `bfly_twin`: with offsets `[16, 8, 4, 2, 2]` (the last round repeated instead of offset 1),
  lane 0's leaves are not a permutation of `0, ..., 31`: each even lane occurs twice and no odd
  lane occurs, so statement 3 needs offsets that are distinct powers of two.
- `leaves_mixed`: statement 3 at `k = 3`, the offsets `1, 4, 2` (not in descending order) and
  lane 5: the leaves are a permutation of `0, ..., 7`; with eight lanes holding `1` at binary32
  (`add_mixed`), statement 6 bounds lane 5's sum by `((1 + u) ^ 3 - 1) · 8`.
- `add_ones`: statement 6 at binary32, `warpOffsets`, lane 0 and 32 lanes holding `1`: the root's
  sum `32` is finite by evaluation, so every lane is finite and the bound holds.
- `offsets8`, `leaves8`: `bflyOffsets 3` is `4, 2, 1` and lane 0's leaves are
  `0, 4, 2, 6, 1, 5, 3, 7` (by `decide`); statement 3's `leaves_offsets` at `k = 3`.
- `shfl8`: statement 4 at `k = 3`, clamp `24 · 256 + 31 = 6175`: lane 13 with offset 5 reads
  lane 8. `shfl8_twin`: with the same clamp and offset 8, outside the group, lane 5 reads itself,
  not lane `5 ^^^ 8 = 13` (by `decide`), so statement 4 needs `m < 2 ^ k`. `shfl32`: statement 4
  at `k = 5`, the warp's clamp `0 · 256 + 31 = 31`: lane 13 with offset 21 reads lane 24.
- `exact4`: statement 5 away from a warp, at the offsets `2, 1`, lane 3 (leaves `3, 1, 2, 0`, by
  evaluation), `w = 4` and exact addition of reals (`u = 0`): for every `v`, lane 3's value is
  `Σ_{j<4} v j`.

## Not proved

- That a grid run of `gemv_kernel` or `gevm_kernel` computes `bflyRounds` of the lanes' values:
  that needs the run's shuffles to complete with every lane of the warp at the same round
  (`Grid.fire`), and both kernels are outside the block checker's fragment from their entry
  block, so they have no proof path on this branch.
- The row's dot product, the butterfly over the 32 strided loops whose `fadd contract` may fuse
  with the `fmul contract` (`T9`), is warp-dot.md: within a closed-form bound of TorchLean's real
  entry when finite, and FloatLib's reduction along lane 0's tree, up to NaNs, with the
  contraction off. That a grid run computes it is not proved there either.
- Any bound when the result is infinite or a NaN: statement 6 assumes the root's sum finite.
