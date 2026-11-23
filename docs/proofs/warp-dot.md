# The warp's dot product: strided loops and a butterfly (`stride`, `warpDot`, `warpBound`, `sum_stride`, `length_stride`, `bfly_stride`, `bfly_matVec`, `bfly_vecMat`, `bfly_stride_error`, `warpDot_error`, `warpDot_matVec`, `warpDot_vecMat`, `bflyRounds_nanEq`, `bfly_stride_nanEq`, `warpDot_nanEq`, `warpDot_eq`)

Lean: proved, for every format, length, flag and oracle as stated below, in
MojoProof/Sem/WarpDot.lean, and `gevm_kernel`'s transposition through shared memory in
MojoProof/Sem/Transpose.lean (its own section below). Instances: MojoProofTest/WarpDot.lean, a test
of one example (binary32, 40 pairs), and MojoProofTest/Transpose.lean. The loop is `dotLoop`
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
`warpDot c o ps` for lane 0's value after the rounds of FloatLib's `Model.add` at `warpOffsets`
from lane `l`'s value `dotLoop c (o l) (+0) (stride 32 l ps)`, with the `contract` flag `c` and
lane `l`'s oracle numbers `o l`. A kernel's `fadd` of a round goes through `deliver`, which
changes only a NaN result (`nanEq_deliver`); `warpDot` adds without it. Write `u` for FloatLib's
unit roundoff `Model.unitRoundoffAt fmt`, `η` for its underflow allowance
`Model.underflowErrorAt fmt`, and

```
warpBound fmt n d w T = ((1 + u) ^ (n + d + 1) - 1) T
                       + w (1 + u) ^ d (2 + u) η ((1 + u) ^ n - 1) / u.
```

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
5. `bfly_stride_error`: in every IEEE format, for every flag `c`, oracle family `o`, list `ps`,
   offsets, lane and width of statement 3, and every `n` at least the length of each strided list:
   if lane `l`'s value `r` after the rounds of `Model.add` over the loops `dotLoop c (o j) (+0)
   (stride w j ps)` is finite, then `|r - Σ aₖ bₖ| ≤ warpBound fmt n ms.length w T`, with
   `T = Σ |aₖ bₖ|`.
6. `warpDot_error`: for `K` pairs, `warpDot c o ps`, if finite, is within
   `warpBound fmt ⌈K / 32⌉ 5 32 T` of `Σ aₖ bₖ`; `warpDot_matVec` and `warpDot_vecMat`: the same
   against TorchLean's real entries at `matVecPairs A v i` (`⌈n / 32⌉`) and `vecMatPairs v A j`
   (`⌈m / 32⌉`).
7. `bflyRounds_nanEq`: in every format, for all operations `f`, `g` such that `f x y` and `g x' y'`
   are `NaNEq` (same word or both NaNs) whenever `x, x'` and `y, y'` are, all offsets, values `v`,
   `v'` that are lane by lane `NaNEq`, and every lane, the rounds of `f` over `v` and of `g` over
   `v'` are `NaNEq`. At `f = g = Model.add` they are `warpDot`'s rounds; at `f x y = deliver
   (Model.add x y) n` and `g = Model.add`, the semantics' `fadd` at one oracle number `n` for every
   lane and round. `bfly_stride_nanEq`: in every format, for every flag `c` and oracle family `o`
   with the contraction off (`c` false, or no oracle number 2 modulo 3), the value of statement 5
   and FloatLib's `Model.reduceAlong fmt fmt` along `bflyTree ms l` of the in-order dot products
   `Model.dotInOrder fmt fmt (stride w j ps)` are `NaNEq`.
8. `warpDot_nanEq`: statement 7 at a warp, `warpDot c o ps` against FloatLib's reduction along
   `bflyTree warpOffsets 0`; `warpDot_eq`: when FloatLib's word is not a NaN, `warpDot c o ps` is
   that word, bit for bit, and one is a NaN exactly when the other is.

With `K` pairs the bound's exponent is `⌈K / 32⌉ + 6`, against `K + 1` for the sequential loop
(`dotBound`), and its underflow term has `32 (1 + u) ^ 5` loops of `⌈K / 32⌉` iterations.

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
5. `bfly_add_error` (bfly.md, statement 6) gives that each lane's loop is finite and
   `|r - Σ_j vⱼ| ≤ (D - 1) Σ_j |vⱼ|`, `D = (1 + u) ^ ms.length`. Each loop has at most `n`
   iterations, so by `dotLoop_error` and monotony `|vⱼ - Pⱼ| ≤ (G - 1) Qⱼ + E`, with `Pⱼ`, `Qⱼ` the
   exact and absolute sums of list `j`, `G = (1 + u) ^ (n + 1)` and
   `E = (2 + u) η ((1 + u) ^ n - 1) / u`. Summing over `j` with statement 1,
   `|Σ vⱼ - Σ aₖ bₖ| ≤ (G - 1) T + w E` and `Σ |vⱼ| ≤ G T + w E`; so
   `|r - Σ aₖ bₖ| ≤ (D - 1)(G T + w E) + (G - 1) T + w E = (D G - 1) T + w D E`, which is
   `warpBound fmt n ms.length w T` (`ring`, `linarith`).
6. Statement 5 at `leaves_warp 0` and `length_stride_le`; then `matVec_cell_real` or
   `vecMat_cell_real` and the pairs' length.
7. Induction on the offsets: one round is the premise on `f` and `g` at lane `j` and lane `j ^^^ m`;
   at `Model.add` the premise is `NaNEq.op` at `fadd`, and at `deliver` it is `nanEq_deliver`
   followed by `NaNEq.op`. Then `eval_bflyTree` on FloatLib's side, `dotLoop_nanEq` at each lane,
   and `cast_self_nanEq` for `reduceAlong`'s final cast to the same format.
8. Statement 7 at `warpOffsets`, `w = 32`, `l = 0`; `NaNEq.eq_isNaN`.

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
- `error40`: statement 6 (`warpDot_vecMat`) at `m = 40`, with the finite premise by evaluation.
- `deliver5`: statement 7 at `f x y = deliver (Model.add x y) 7` and `g = Model.add`, over lane 5
  holding the quiet NaN `0x7fc00000` and the other lanes `1` (`nan5`): lane 0's delivered value
  is a NaN, because `Model.add`'s is (by evaluation).

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
- That the kernel's rounds, whose `fadd` goes through `deliver` at each lane's own oracle number,
  give `warpDot` up to NaNs: `bflyRounds_nanEq` carries `deliver` through the rounds at one oracle
  number for every lane and round, since `bflyRounds` applies one operation everywhere; rounds
  whose operation depends on the lane and the round are not defined.
- Any bound when the result is infinite or a NaN.
