# The warp butterfly as a reduction tree (`bflyRounds`, `bflyTree`, `eval_bflyTree`, `depth_bflyTree`, `leaves_warp`, `shflSource_bfly`, `bfly_warp_error`, `bfly_warp_add`)

Lean: proved, for every carrier, combining operation, offsets, values and lane as stated below,
in MojoProof/Sem/Bfly.lean. Instances and twins: MojoProofTest/Bfly.lean. The tree type is
FloatLib's `FloatLib.Numerics.ReductionTree` (FloatLib/Numerics/Reduction/Tree.lean), and the
error bound is FloatLib's `ReductionTree.abs_eval_sub_exact_le_depth`
(FloatLib/Numerics/Reduction/Error.lean). The statements are about the rounds as functions of the
lanes' values; that a grid run of a kernel computes them is not proved (see "Not proved").

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
lane `shflSource .bfly l m 31`, which is `l ^^^ m` for `l, m < 32` (`shflSource_bfly`). A
`bitcast` from `float` to `i32` and back gives the same bits. The `fadd contract`'s operands are a
`phi` or an `fadd` result and a `bitcast`, never an `fmul contract` result, so `contract`
(MojoProof/Sem/Float.lean) is FloatLib's `Model.add` at every oracle number, through `deliver`,
which changes only a NaN result.

## Statements

Write `bflyRound combine m v` for the values after one round with offset `m`: lane `l` gets
`combine (v l) (v (l ^^^ m))`, its own value first, as in `fadd contract float %79, %82`.
`bflyRounds combine ms v` is the rounds with offsets `ms`, first to last, and `warpOffsets` is
`[16, 8, 4, 2, 1]`. `bflyTree ms l` is a `ReductionTree Nat` whose leaves are lane numbers: with
no rounds lane `l`'s tree is the leaf `l`, and a round with offset `m` makes lane `l`'s tree the
node of its own tree and lane `l ^^^ m`'s.

1. `eval_bflyTree`: for every carrier `β`, every `combine : β → β → β`, offsets `ms`, values
   `v : Nat → β` and lane `l`, evaluating lane `l`'s tree with `combine` at the leaves' values is
   lane `l`'s value after the rounds:
   `(bflyTree ms l).eval combine v = bflyRounds combine ms v l`.
2. `depth_bflyTree`: for all offsets and every lane, `(bflyTree ms l).depth = ms.length`; at a
   warp, 5.
3. `leaves_warp`: for every lane `l < 32`, the leaves of `bflyTree warpOffsets l` are a
   permutation of `0, ..., 31`: each lane's value is a leaf exactly once.
4. `shflSource_bfly`: for all `l, m < 32`, `shflSource .bfly l m 31 = l ^^^ m`.
5. `bfly_warp_error`: for every carrier, `combine`, values `v`, map `interpret : β → ℝ`,
   `u ≥ 0` and lane `l < 32`: if at every node of lane `l`'s tree the combination of the
   operands `x`, `y` it meets is within `u · (|x| + |y|)` of their exact sum
   (`ReductionTree.AllNodes`), then
   `|interpret (bflyRounds combine warpOffsets v l) - Σ_{j<32} interpret (v j)|` is at most
   `((1 + u) ^ 5 - 1) · Σ_{j<32} |interpret (v j)|`.
6. `bfly_warp_add`: for every `v : Nat → Model .binary32` and lane `l < 32`, if every addition at
   a node of lane `l`'s tree has a finite result, statement 5 holds with `combine = Model.add`,
   `interpret = Model.toReal` and `u = Model.unitRoundoffAt .binary32` (`2 ^ -24`).

The depth 5 of the bound is `⌈log₂ 32⌉`, the least depth of any schedule over 32 inputs
(FloatLib's `clog_le_depth`); a loop over the 32 values (FloatLib's `leftChain`) has depth 31.

## Proofs

1. By induction on `ms`, for every starting family of trees `T` and values `w` with
   `(T l).eval combine v = w l` at every lane: a round makes both sides the combination of lane
   `l`'s and lane `l ^^^ m`'s, which are equal by the hypothesis. Start with `T = leaf`, `w = v`.
2. The same induction: if every lane's tree has depth `d`, after a round every lane's tree has
   depth `max d d + 1 = d + 1`.
3. By kernel evaluation (`decide +kernel`) of the 32 permutation checks.
4. Unfold `shflSource`: with clamp 31 the segment mask is 0 and the largest lane is 31; `m % 32 =
   m`, and `l ^^^ m < 32` (`Nat.xor_lt_two_pow`), so the source is in range.
5. FloatLib's `abs_eval_sub_exact_le_depth` at lane `l`'s tree, rewritten by statement 1 on the
   computed side, statement 2 for the depth, and `eval_add_eq_sum` with statement 3 for the exact
   sum and for `sumAbs`.
6. FloatLib's `Model.abs_toReal_add_sub_le_unitRoundoffAt` (an IEEE addition with a finite result
   is within `2 ^ -24 · |x + y|` of the exact sum `x + y`, subnormal results included) and
   `|x + y| ≤ |x| + |y|` give statement 5's node premise; then statement 5.

## Instances and twins

- `lane0_leaves`: lane 0's leaves are `0, 16, 8, 24, 4, 20, 12, 28, 2, ...`, the lanes in
  bit-reversed order, by evaluation; `bfly_sum`: with `combine = (· + ·)` on `Nat` and
  `v j = j`, every lane ends with `0 + ... + 31 = 496`, by evaluation (`decide +kernel`).
- `bfly_twin`: with offsets `[16, 8, 4, 2, 2]` (the last round repeated instead of offset 1),
  lane 0's leaves are not a permutation of `0, ..., 31`: each even lane occurs twice and no odd
  lane occurs, so statement 3 needs the warp's offsets.

## Not proved

- That a grid run of `gemv_kernel` or `gevm_kernel` computes `bflyRounds` of the lanes' values:
  that needs the run's shuffles to complete with every lane of the warp at the same round
  (`Grid.fire`), and both kernels are outside the block checker's fragment from their entry
  block, so they have no proof path on this branch.
- That the stored output is near the row's exact dot product: lane `l`'s partial sum is a loop
  over the columns `32 i + l`, whose `fadd contract` may fuse with the `fmul contract` (`T9`);
  the row's whole schedule is the butterfly tree over 32 such loops.
- NaN and infinite results: `bfly_warp_add` assumes every node's sum is finite.
