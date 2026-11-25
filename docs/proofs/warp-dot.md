# The warp's dot product: strided loops and a butterfly (`stride`, `groupDot`, `warpDot`, `sum_stride`, `length_stride`, `bfly_stride`, `bfly_matVec`, `bfly_vecMat`, `bfly_stride_error`, `groupDot_error`, `groupDot_matVec`, `groupDot_vecMat`, `warpDot_error`, `warpDot_matVec`, `warpDot_vecMat`, `bflyRounds_nanEq`, `bfly_stride_nanEq`, `groupDot_nanEq`, `groupDot_eq`, `warpDot_nanEq`, `warpDot_eq`, `bflyRoundsAt_nanEq`, `bflyDeliver_nanEq`, `bflyDeliver_error`)

Lean: proved, for every format, length, group of `2 ^ k` lanes, flag and oracle as stated below, in
MojoProof/Sem/WarpDot.lean, and `gevm_kernel`'s transposition through shared memory in
MojoProof/Sem/Transpose.lean (its own section below). Instances: MojoProofTest/WarpDot.lean, tests
of one example each (binary32, 40 pairs, over 32 lanes and over 8), and
MojoProofTest/Transpose.lean. The loop is `dotLoop`
(MojoProof/Sem/Matmul.lean), the rounds and their tree are `bflyRounds` and `bflyTree`
(MojoProof/Sem/Bfly.lean, see bfly.md), the exact values are TorchLean's `contract … .matVec` and
`contract … .vecMat`, and the bounds and the reference words are FloatLib's. The statements are
about a function of the factor pairs; that a grid run of a kernel computes it is not proved (see
"Not proved").

## What the kernels compute

Both kernels in tests/corpus/gemv/ compute each output entry as a dot product over `K` factor
pairs, in the same order. The pairs are split by position modulo 32 into 32 strided lists; lane
`l` folds list `l` from `+0` with `fmul contract` then `fadd contract` (one `dotStep`); and the
five butterfly rounds at the offsets 16, 8, 4, 2, 1 (bfly.md) add the 32 lanes' sums, lane 0's
value being the output.

- `gemv_kernel`: lane `l` of row `i`'s warp folds the pairs `(a[i, 32 j + l], b[32 j + l])`, the
  strided lists of `matVecPairs A v i`, the pairs of TorchLean's matrix-vector entry `i`.
- `gevm_kernel`: thread `(w, l)` folds the pairs `(a[32 j + w], b[32 j + w, 32 β + l])`, list
  `w` of column `32 β + l`; the sums are transposed through shared memory, so that lane `l` of
  warp `w` holds the sum of list `l` of column `32 β + w`, and warp `w`'s five rounds leave column
  `32 β + w`'s total at lane 0. A column's pairs are `vecMatPairs v A j`, the pairs of
  TorchLean's vector-matrix entry `j`.

## Statements

Write `stride w l xs` for the elements of `xs` at the positions `≡ l (mod w)`, in order, and
`groupDot k c o ps` for lane 0's value after the rounds of FloatLib's `Model.add` at
`bflyOffsets k` (bfly.md) from lane `l`'s value `dotLoop c (o l) (+0) (stride (2 ^ k) l ps)`, with
the `contract` flag `c` and lane `l`'s oracle numbers `o l`: the dot product over a group of
`2 ^ k` lanes. `warpDot` is by definition `groupDot 5`, the warp's 32 lanes. A kernel's `fadd` of a
round goes through `deliver`, which changes only a NaN result (`nanEq_deliver`); `groupDot` adds
without it. Write `u` for FloatLib's
unit roundoff `Model.unitRoundoffAt fmt`, `η` for its underflow allowance
`Model.underflowErrorAt fmt`, and `E(W, d, L)` for the error of
`GPUProof.laneGrade (.ieee fmt) W d L n a x ga gx` at the real values `a k`, `x k` of the words and
the grades `⟨0, 0⟩` (spec.md), which is

```
E(W, d, L) = ((1 + u) ^ (L + d) - 1) T + W (1 + u) ^ d (2 + u) η ((1 + u) ^ L - 1) / u,
```

with `T = Σₖ |aₖ xₖ|`. The bound of statements 5 and 6 is this one, `laneGrade`'s, the same as
the graded `GPUProof.Approx` statements of MojoProof/Tile/MatVec.lean (`stride_approx`,
`bfly_approx`, `groupDot_approx`).

1. `sum_stride`: in every commutative monoid, for every `w > 0`, map `g` and list `xs`,
   `Σ_{l<w} Σ g (stride w l xs) = Σ g xs`.
2. `length_stride`: for all `l < w` and every list of length `K`, `stride w l xs` has
   `K / w + [l < K % w]` elements; `length_stride_le`: at most `⌈K / w⌉ = (K + w - 1) / w`.
3. `bfly_stride`: in every commutative monoid, for all offsets `ms`, lanes `l` and widths `w`
   whose lanes `0, ..., w - 1` are the leaves of `bflyTree ms l`, each once (`leaves_warp`: every
   `l < 32` at `warpOffsets` with `w = 32`), lane `l`'s value after the rounds of `+` from lane
   `j`'s exact sum `Σ g (stride w j xs)` is `Σ g xs`.
4. Over `ℝ`, for every format and all sizes: `vecMat_cell_real`: `Σ aₖ bₖ` over
   `vecMatPairs v A j` is entry `j` of `contract v' A' _ _ [n] .vecMat`, with `v'`, `A'` the
   tensors mapped by `Model.toReal`; so (statement 3 with `g` the real product) `bfly_matVec`:
   the rounds of `+` over the lanes' exact sums of the strided lists of `matVecPairs A v i` give
   entry `i` of `contract A' v' _ _ [m] .matVec`, and `bfly_vecMat`: those of `vecMatPairs v A j`
   give entry `j` of `contract v' A' _ _ [n] .vecMat`, for every `ms`, `w`, `l` of statement 3.
5. `bfly_stride_error`: in every IEEE format, for every flag `c`, oracle family `o`, words `w k`,
   `v k` for `k < n` (the pairs `ps`), offsets, lane and width `W` of statement 3, and every `L`
   at least the length of each strided list: if lane `l`'s value `r` after the rounds of
   `Model.add` over the loops `dotLoop c (o j) (+0) (stride W j ps)` is finite, then
   `|r - Σ wₖ vₖ| ≤ E(W, ms.length, L)`.
6. `groupDot_error`: in every IEEE format, for every `k` and `n` pairs, `groupDot k c o ps`, if
   finite, is within `E(2 ^ k, k, ⌈n / 2 ^ k⌉)` of `Σ wₖ vₖ`; `groupDot_matVec` and
   `groupDot_vecMat`: the same against TorchLean's real entries at `matVecPairs A v i`
   (`⌈n / 2 ^ k⌉`) and `vecMatPairs v A j` (`⌈m / 2 ^ k⌉`). `warpDot_error`, `warpDot_matVec` and
   `warpDot_vecMat` are their cases `k = 5`: `E(32, 5, ⌈n / 32⌉)`.
7. `bflyRounds_nanEq`: in every format, for all operations `f`, `g` such that `f x y` and `g x' y'`
   are `NaNEq` (same word or both NaNs) whenever `x, x'` and `y, y'` are, all offsets, values `v`,
   `v'` that are lane by lane `NaNEq`, and every lane, the rounds of `f` over `v` and of `g` over
   `v'` are `NaNEq`. At `f = g = Model.add` they are `warpDot`'s rounds; at `f x y = deliver
   (Model.add x y) n` and `g = Model.add`, the semantics' `fadd` at one oracle number `n` for every
   lane and round. `bfly_stride_nanEq`: in every format, for every flag `c` and oracle family `o`
   with the contraction off (`c` false, or no oracle number 2 modulo 3), the value of statement 5
   and FloatLib's `Model.reduceAlong fmt fmt` along `bflyTree ms l` of the in-order dot products
   `Model.dotInOrder fmt fmt (stride w j ps)` are `NaNEq`.
8. `groupDot_nanEq`: statement 7 at a group of `2 ^ k` lanes, `groupDot k c o ps` against
   FloatLib's reduction along `bflyTree (bflyOffsets k) 0` of the in-order dot products of the
   lists `stride (2 ^ k) j ps`; `groupDot_eq`: when FloatLib's word is not a NaN,
   `groupDot k c o ps` is that word, bit for bit, and one is a NaN exactly when the other is.
   `warpDot_nanEq` and `warpDot_eq` are their cases `k = 5`, along `bflyTree warpOffsets 0`.
9. Write `bflyRoundsAt F ms v` (bfly.md) for the rounds in which lane `l` of round `r` (counted
   from `0`) combines by `F r l`; `bflyRounds f ms v` is by definition its case `F r l = f`.
   `bflyRoundsAt_nanEq`: in every format, for every family `F` and
   operation `g` such that `F r l x y` and `g x' y'` are `NaNEq` whenever `x, x'` and `y, y'` are,
   for every round and lane, and values and lanes as in statement 7, the rounds of `F` over `v`
   and of `g` over `v'` are `NaNEq`. `bflyDeliver_nanEq`: in every format, for every oracle family
   `o` by round and lane, the rounds of `deliver (Model.add x y) (o r l)`, the semantics' `fadd`
   with its own oracle number in every round and lane, are `NaNEq` to those of `Model.add`.
   `bflyDeliver_error`: in every IEEE format, for every such `o`, values, offsets `ms`, lane `l`
   and width `w` with lane `l`'s tree over the lanes below `w`, each once: if the lane's
   delivered value is finite, it is the `Model.add` rounds' value, every value below `w` is
   finite, and it is within `((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` of `Σ_{j<w} v j`.

With `K` pairs the bound's exponent is `⌈K / 32⌉ + 5`, against `K` for the sequential loop
(`GPUProof.dotGrade`, `laneGrade` at one lane and depth `0`), and its underflow term has
`32 (1 + u) ^ 5` loops of `⌈K / 32⌉` iterations.

## Proofs

1. Generalize the start index of `zipIdx` and induct on the list: the head at position `s` goes to
   list `s % w` only, and `Σ_{l<w} [s % w = l] g x = g x` (`List.sum_map_eq_nsmul_single`,
   `s % w < w`).
2. The filter's length is the count of `k < K` with `k % w = l` (induction on the list), which is
   Mathlib's `Nat.count_modEq_card`; the bound follows from `K = w (K / w) + K % w` and
   `K % w < w` (`omega`).
3. `eval_bflyTree` makes the rounds an evaluation of lane `l`'s tree; FloatLib's
   `eval_add_eq_sum` makes it the sum over the leaves, a permutation of `0, ..., w - 1`, and then
   statement 1.
4. TorchLean's `getScalar_contract_vecMat` and `dotSum_ofFn`, as for `matVec_cell_real`; then
   statement 3.
5. Lane `l`'s value is `treeDot` (dot.md) along `bflyTree ms l` (`eval_bflyTree`), whose depth
   is `ms.length` (`depth_bflyTree`), over the lists `stride W j ps`; their sums over the lanes
   are the sums over the pairs (statement 1). So it is dot.md's `treeDot_error` at the real values
   with the grades `⟨0, 0⟩`, each word within `0` of its own real value. There is no induction
   here: the loops' bound (`lanes_error`) and the tree's (`Float.sum_error`) are combined once, in
   `treeDot_error`.
6. Statement 5 at `leaves_offsets k 0` (bfly.md, statement 3), `length_stride_le` and
   `(bflyOffsets k).length = k`; then `matVec_cell_real` or `vecMat_cell_real` and the pairs'
   length. The warp's statements are the general ones at `k = 5`, where `2 ^ 5` reduces to 32.
7. Statement 9's `bflyRoundsAt_nanEq` at one operation in every round and lane, which is
   `bflyRounds` by definition; at `Model.add` the premise is `NaNEq.op` at `fadd`, and at `deliver` it
   is `nanEq_deliver` followed by `NaNEq.op`. Then `eval_bflyTree` on FloatLib's side,
   `dotLoop_nanEq` at each lane, and `cast_self_nanEq` for `reduceAlong`'s final cast to the same
   format.
8. Statement 7 at `bflyOffsets k`, `w = 2 ^ k`, `l = 0`; `NaNEq.eq_isNaN`. The warp's are the
   case `k = 5`.
9. Induction on the offsets, generalizing the family: one round is the premise at round `0` on
   lane `j` and lane `j ^^^ m`, and the later rounds are the family shifted by one round.
   `bflyDeliver_nanEq`: the premise is
   `nanEq_deliver` followed by `NaNEq.op` at `fadd`. `bflyDeliver_error`: a finite value is not a
   NaN, so `NaNEq.eq_isNaN` makes it the `Model.add` rounds' value; then `bfly_add_error` (bfly.md,
   statement 6).

## Instances

In MojoProofTest/WarpDot.lean, a test of one example: binary32, the 40 pairs `(2 ^ 24, 1)` then 39
times `(1, 1)`, the pairs of entry 0 of the product of the vector `[2 ^ 24, 1, …, 1]` and the
`40 × 1` matrix of ones (`pairs40`), whose exact sum is `2 ^ 24 + 39`.

- `lens40`: lists 0 to 7 have 2 pairs and lists 8 to 31 have 1 (statement 2, `⌈40 / 32⌉ = 2`).
- `vals40`: without the `contract` flag the warp's word is `2 ^ 24 + 38`, and FloatLib's in-order
  dot product of the 40 pairs is `2 ^ 24`: the butterfly's order and the sequential order give
  different words, so statement 8's reference is the tree's reduction, not the sequential fold
  that TorchLean's binary32 `contract` computes.
- `eq40`: statement 8 with the `contract` flag under the oracle numbers `(0, 0)`.
- `error40`: statement 6 (`warpDot_vecMat`) at `m = 40`, with the finite premise by evaluation:
  the bound is `E(32, 5, 2)`, `laneGrade (.ieee .binary32) 32 5 2 40`'s error.
- `eq8`, `error8`: statements 8 (`groupDot_eq`) and 6 (`groupDot_vecMat`) over a group of 8 lanes
  (`k = 3`, 5 pairs per lane), the second without the `contract` flag, with the finite premise by
  evaluation: the bound is `E(8, 3, 5)`, `laneGrade (.ieee .binary32) 8 3 5 40`'s error.
- `mutant_exact`: the roundoff terms cannot be dropped. At `L = d = 0`, `E(32, 0, 0)` is `0`, and
  the warp's word without the `contract` flag (`2 ^ 24 + 38`, `vals40`) is not the exact sum
  `2 ^ 24 + 39`, so statement 6's conclusion fails at that bound.
- `deliver5`: statement 7 at `f x y = deliver (Model.add x y) 7` and `g = Model.add`, over lane 5
  holding the quiet NaN `0x7fc00000` and the other lanes `1` (`nan5`): lane 0's delivered value
  is a NaN, because `Model.add`'s is (by evaluation).
- `deliverAt5`, `deliverAt_ones`: statement 9's `bflyDeliver_nanEq` and `bflyDeliver_error` with
  the oracle number `32 r + l + 7` in round `r` at lane `l` (`oracleAt`): over `nan5` lane 0's
  value is a NaN; over 32 lanes `1` (`ones32`) it is finite (by evaluation), so it is the
  `Model.add` rounds' value and within `((1 + u) ^ 5 - 1) · 32` of `32`.

## The transposition through shared memory (`tpose`, `tpose_lt`, `tpose_tpose`, `tpose_bijOn`, `Launch.tpose_env`, `Tiling.tpose`, `racy_tpose`, `warpDot_tpose`)

Lean: proved in MojoProof/Sem/Transpose.lean: statement 2 for every valid launch with `ntid.x =
1024` and every thread of every block, the others for every `n`, trace and content of the shared
array as stated. In `gevm_kernel` (gemv.md), thread `t = 32 w + l` of block `β` (warp `w = t / 32`,
lane `l = t % 32`) folds list `w` of column `32 β + l` and stores the sum to the shared cell `%62 =
32 l + w` (line 75, a 4-byte `float`, store at line 78); after the barrier (line 79) it loads cell
`%65 = tid.x = t` (lines 80-82), and the warp's five rounds (lines 83-102) add the 32 values it
loaded.

Write `tpose n t = n (t % n) + t / n`, the position of `t` in the transpose of an `n × n` square
stored by rows; the store cell is `tpose 32 t`.

1. `tpose_lt`, `tpose_tpose`: for every `n` and `t < n²`, `tpose n t < n²` and
   `tpose n (tpose n t) = t`; so (`tpose_bijOn`) `tpose n` is a bijection of `[0, n²)` onto
   itself (`Set.BijOn`), its own inverse. At `n = 32` thread `t` writes cell `tpose 32 t`, and
   cell `t` (which thread `t` reads) is written by thread `tpose 32 t` alone.
2. `Launch.tpose_env`: for every valid launch with `ntid.x = 1024` and every thread number `k`,
   the block has 1024 threads, `tid.x = k % 1024`, the lane number is `k % 32`, and
   `32 · laneid + tid.x / 32 = tpose 32 (k % 1024)`: the kernel's store cell is `tpose 32` of
   the thread's number in its block.
3. `Tiling.tpose n w β`: for every `n > 0`, cell width `w` and block of threads `β`, thread `k`
   of `β` (`k / n² = β`) owns the `w` bytes at `tpose n (k % n²) · w`, every other thread the
   empty tile at 0, inside `n² w` bytes; a `Tiling Nat`, one owner per cell.
4. `racy_tpose`: for every trace, every `n > 0` and `w`, a map `ofSh` from a memory block to the
   block of threads whose shared array it is, and an ownership `G` of the other blocks: if every
   access to block `β`'s array is by a thread of `β` (cta and `k / n² = β`), in phase 0 is the
   `w` bytes of its cell `tpose n (k % n²)`, in later phases is a read, and every access to
   another block follows `G` with each thread its own tile (`Owned G id`), the trace has no race.
   With `n = 32`, `w = 4` and 1024 threads per block (`k / 1024` is the thread's block, statement
   2) this is the kernel's discipline: one owner per cell before the barrier, reads after it.
5. `warpDot_tpose`: for every format, flag `c`, oracle family `o` by thread, pair lists `P` by
   lane and array content `M`: if every thread `t < 1024` stored at cell `tpose 32 t` its loop sum
   `dotLoop c (o t) (+0) (stride 32 (t / 32) (P (t % 32)))`, then for every warp `w < 32` the
   rounds of `Model.add` at `warpOffsets` over the cells `32 w + l` give lane 0 the value of the
   same rounds over the loop sums `dotLoop c (o (32 l + w)) (+0) (stride 32 l (P w))`, which is
   `warpDot c (fun l => o (32 l + w)) (P w)` by definition. With
   `P l = vecMatPairs v A (32 β + l)`, the pairs of column `32 β + l`, warp `w`'s value is
   `warpDot` of column `32 β + w`'s pairs, in `warpDot`'s order (lane `l` holds list `l`), so
   statement 6 (`warpDot_vecMat`) bounds it.

Proofs. 1: `t = n q + r` with `q, r < n`; `Nat.mul_add_mod`, `Nat.mul_add_div` give
`tpose n (n r + q) = n q + r`, and `n r + q < n²` from `r + 1 ≤ n` (`omega`); then
`Set.InvOn.bijOn`. 2: `volume = 1024 · y · z ≤ 1024` with `y, z ≥ 1` forces 1024 (`omega`);
then `Launch.env`, `coord` and `Nat.mod_mod_of_dvd` (32 divides 1024). 3: distinct threads of
`β` have distinct remainders, so distinct cells (statement 1), and `stride_lt` (Buffer.lean)
separates the cells; an empty tile is disjoint from every tile. 4: `racy_eq_false_of_phased`
with `own := id`, the tiling `Tiling.tpose` at `β`'s array in phase 0, none after, `G` elsewhere:
`hO` from the premises, `hG` because two accesses of one array are by threads of its block, `hX`
because `own` is the identity. 5: lane `l < 32` loads cell `32 w + l = tpose 32 (32 l + w)`,
thread `32 l + w`'s sum, list `l` of `P w`; the rounds read only the lanes below 32, the leaves
of lane 0's tree (`leaves_warp`, `bflyRounds_congr`, bfly.md statement 7).

Instances (MojoProofTest/Transpose.lean, tests of one example each): `thread1061`, thread 1061 of
a launch of grid (2, 1, 1) and block (1024, 1, 1) (thread 37 of block 1) stores to cell 161 and
loads cell 37, thread 161's cell and no other's (statements 1, 2); `racy4`, statement 4 at
`n = 2` and 1-byte cells on a trace of 4 threads (each writes its transposed byte, a barrier,
each reads its own); `col40`, statement 5 at binary32 with every lane's pairs `wd40`: warp 5's
value is `2 ^ 24 + 38`, the word of `vals40`.

Not proved: that a grid run of `gevm_kernel` stores and loads these cells (the `getelementptr`
on the shared global, gemv.md item 5), that its trace meets statement 4's premises, and that its
loop computes `dotLoop` of the strided lists, which needs `K` and `N` multiples of 32 (gemv.md,
"The specifications' premises": the loop reads row `32 i + w` for every `i < ⌈K / 32⌉`).

## Not proved

- That a grid run of `gemv_kernel` or `gevm_kernel` computes `warpDot` of its loaded pairs: the
  loops' loads, the shuffles of every lane of the warp at the same round, and that `gevm_kernel`'s
  run stores and loads the transposed cells (the cells' arithmetic, the race freedom of a trace
  that does, and the values each warp then reduces are proved, in the section above); both
  kernels are outside the block checker's fragment from their entry block (bfly.md).
- That the oracle numbers a grid run draws for the rounds' `fadd` are a family `o r l` by round
  and lane of statement 9: statement 9 holds for every such family, and that a run computes the
  rounds at all is the item above.
- Any bound when the result is infinite or a NaN.
