# Float bounds of reductions: any tree, butterflies of any width, block trees, mean, variance and max-subtracted exponential sums

Lean: MojoProof/Float/Tree.lean, MojoProof/Float/Halve.lean, MojoProof/Float/Stats.lean,
MojoProof/Float/ExpSum.lean and the additions to MojoProof/Sem/Bfly.lean and
MojoProofTest/Bfly.lean. Instances:
MojoProofTest/FloatTree.lean and MojoProofTest/FloatStats.lean. Floats are FloatLib's
`Model fmt` words; `u = Model.unitRoundoffAt fmt` is FloatLib's unit roundoff and
`η = Model.underflowErrorAt fmt` its underflow allowance. `MixedError x x₀ r a` is FloatLib's
`|x - x₀| ≤ r · |x₀| + a` with `r, a ≥ 0` (FloatLib/Numerics/MixedError/Basic.lean).

Every statement here is about words and the trees of operations a kernel performs on them, as
functions of the inputs. That a grid run of a kernel performs those operations is not proved here
(see "Not proved"). The statements hold in every IEEE format (`fmt.isIEEE = true`), for every
length and every tree as stated; none of them is about one program.

## The shape of every bound

Each headline result has the shape of a kernel theorem's float clause (`matmul_error` in
MojoProofTest/NaiveKernel.lean): for every input meeting the premises, if the computed word is
finite then its real value is within the stated bound of the exact real value, and that exact
value is TorchLean's real specification where TorchLean has one. Nothing is claimed when the
computed word is infinite or a NaN.

## Statements

### Any tree (MojoProof/Float/Tree.lean)

`graft t f` replaces each leaf `j` of a FloatLib `ReductionTree` by the tree `f j`: the tree of a
reduction whose inputs are themselves reductions (a block reduction over the warps' butterflies).
FloatLib has no such operation.

`roundsTree r ps c` and `rounds combine r ps v c` are rounds of a per-cell step over cells
numbered by `Nat`: in round `p`, cell `c`'s new value is the tree `r p c` of cell numbers
evaluated at the values before the round. A block's shared-memory halving round is such a
step. `roundsTree r ps c` is defined by recursion on the rounds: the leaf `c` with no rounds, and
after `p :: ps` the tree after `ps` with each cell `c'` replaced by the first round's tree
`r p c'`.

1. `eval_graft`, `leaves_graft`, `depth_graft`: for every carrier, combining operation and pair
   `t`, `f`, evaluating `graft t f` is evaluating `t` at the values of the `f j`; its leaves are
   those of the `f j`, `j` along `t`'s leaves; if every `f j` at a leaf of `t` has depth `d`, its
   depth is `t.depth + d`. `eval_roundsTree`: cell `c`'s value after the rounds is the evaluation
   of `roundsTree r ps c`.
2. `leaves_graft_range`: if `t`'s leaves are a permutation of `0, …, W - 1` and the leaves of each
   `f w`, `w < W`, are a permutation of `b·w, …, b·w + b - 1`, the leaves of `graft t f` are a
   permutation of `0, …, W·b - 1`.
3. `finiteEval_of_isFinite`, `isFinite_of_mem_leaves`: in every IEEE format, a tree of
   `Model.add` whose root is finite is FloatLib's `Model.ReductionTree.FiniteEval` (every node's
   sum finite), and every leaf of such a tree is finite.
4. `eval_error`: for every carrier, combining operation, values, map `interpret` to the reals,
   `u ≥ 0`, tree `t` over any index type and list `S` such that `t`'s leaves are a permutation of
   `S`: if every combination at a node of `t` is within `u · (|x| + |y|)` of its operands' exact
   sum, the result is within `((1 + u) ^ t.depth - 1) · Σ_{j∈S} |v j|` of `Σ_{j∈S} v j`. It is
   FloatLib's `ReductionTree.abs_eval_sub_exact_le_depth` with the sums taken over `S`.
5. `sum_error`: in every IEEE format, for every tree `t` whose leaves are a permutation of `S` and
   values `v`: if `t.eval Model.add v` is finite, every `v j`, `j ∈ S`, is finite and the result
   is within `((1 + u) ^ t.depth - 1) · Σ_{j∈S} |v j|` of `Σ_{j∈S} v j`. It rests on FloatLib's
   `Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth` and statement 3.
6. `sum_mixedError`: the same tree with inputs that approximate exact reals `w j` with mixed
   errors `(r j, a j)` when finite: the result has the absolute error
   `((1 + u) ^ t.depth - 1) · Σ_{j∈S} |w j| + (1 + u) ^ t.depth · Σ_{j∈S} (r j · |w j| + a j)`
   against `Σ_{j∈S} w j`. This is the tree form of FloatLib's left-to-right
   `Model.mixedError_toReal_foldl_add_absolute`, with the depth in place of the number of
   additions.

### Butterflies of any width and order (MojoProof/Sem/Bfly.lean)

7. `leaves_bfly`: for every `k`, every list of offsets `ms` that is a permutation of
   `1, 2, 4, …, 2 ^ (k - 1)` (any order of the rounds) and every lane `l < 2 ^ k`, the leaves of
   `bflyTree ms l` are a permutation of `0, …, 2 ^ k - 1`. `leaves_warp` is its case `k = 5` at
   `warpOffsets`.
8. `bfly_warp_error` and `bfly_add_error` keep their statements (bfly.md, statements 5 and 6) and
   are statement 4 and statement 5 at `t = bflyTree ms l`, `S = 0, …, w - 1`. With statement 7,
   their width premise holds at every width `2 ^ k` and every order of the offsets.

### Block reductions (MojoProof/Float/Halve.lean)

`halveStep s c` is the tree of cell `c`'s value after the shared-memory halving round with stride
`s`: a cell `c < s` combines its value with cell `c + s`'s, its own first; the other cells keep
theirs. `halvings k` is the strides `2 ^ (k - 1), …, 2, 1`, so the halving loop over `2 ^ k` cells
is `rounds combine halveStep (halvings k)` and cell 0's tree is
`roundsTree halveStep (halvings k) 0`.

9. `leaves_halve`, `depth_halve`: for every `k`, cell 0's leaves after the halving rounds over
   `2 ^ k` cells are a permutation of `0, …, 2 ^ k - 1` and its depth is `k`.
10. `halve_error`: in every IEEE format, for every `k` and values: if cell 0's value after the
    halving rounds of `Model.add` is finite, every input below `2 ^ k` is finite and the value is
    within `((1 + u) ^ k - 1) · Σ_{j<2^k} |v j|` of `Σ_{j<2^k} v j` (statement 5).
11. `block_error`: in every IEEE format, for every tree `T` whose leaves are a permutation of the
    `W` warps, offsets `ms` that are a permutation of `1, …, 2 ^ (j - 1)` and values of the threads
    (thread `2 ^ j · w + l` is lane `l` of warp `w`): if the sum along `T` of each warp's lane 0
    after its butterfly rounds is finite, every value below `W · 2 ^ j` is finite and the sum is
    within `((1 + u) ^ (T.depth + j) - 1) · Σ |v|` of `Σ v`. The two stages are one tree,
    `graft T (fun w => (bflyTree ms 0).map (2 ^ j · w + ·))`, whose depth is the sum of the two
    stages' depths. With `T` cell 0's halving tree over `2 ^ k` warps (statement 9) the depth is
    `k + j`.

### Mean and variance, two passes (MojoProof/Float/Stats.lean)

`mean t x N` is the first pass: the `n` words `x` summed by `Model.add` along a tree `t`, divided
by a word `N` that denotes `n`. `variance t₁ t₂ x N` is the second: each difference of an input
with the mean word `mean t₁ x N` by `Model.sub`, squared by `Model.mul`, summed along a tree `t₂`
and divided by `N`. Each tree's leaves are a permutation of the `n` indices (`List.finRange n`);
the two trees are independent and of any shape. `meanErr`, `devErr` and `varErr` are the closed
forms of the absolute errors of the mean, of each difference and of the variance.

12. `mean_error`: in every IEEE format, for every `n`, tree `t`, inputs `x : Fin n → Model fmt`
    and finite word `N` whose real value is `n`: if the mean word is finite, every input is finite
    and the mean is within `MixedError … u (meanErr u η t.depth x)` of the exact mean `𝔼 j, x j`
    (Mathlib's `Finset.expect`), where `meanErr u η d x = (1 + u) · ((1 + u) ^ d - 1) · 𝔼 j, |x j|
    + η`.
13. `var_error`: under the same premises on `N`, for every two trees `t₁`, `t₂`: if the variance
    word is finite, it is within `MixedError … u (varErr u η t₁.depth t₂.depth x)` of TorchLean's
    population variance `TorchLean.var` of the inputs' real values. `𝔼` and `TorchLean.var` are
    the two statistics of TorchLean's real layer norm `TorchLean.TransformerBlock.layerNorm`.

### Max-subtracted exponential sums and softmax (MojoProof/Float/ExpSum.lean)

The maximum is a tree of `Model.maximumNumber` (LLVM's `maxnum`) over the inputs. `expTerm b x m j`
is FloatLib's correctly rounded `Model.Transcendentals.CorrectlyRounded.exp`, with the search
budget `b`, of the rounded difference `Model.sub (x j) m`; the terms are summed along any tree
whose leaves are a permutation of the `n` indices; a softmax entry is `Model.div` of term `j` by
the sum. `expSumErr u η d y` is the closed form of the sum's absolute error,
`((1 + u) ^ d - 1) · Σ_j exp (y j) + (1 + u) ^ d · Σ_j (((1 + u) · exp (u · |y j|) - 1) · exp (y j)
+ η)`, at the exact differences `y j = x j - m`.

14. `max_exact`: in every format, for every tree over any index type and inputs finite at its
    leaves, the tree's maximum is finite, its real value is one input's and it is at least every
    input's: the maximum is exact.
15. `expTerm_error`: in every IEEE format, if the difference `Model.sub (x j) m` and the term are
    finite, the term is within `MixedError … ((1 + u) · exp (u · |x j - m|) - 1) η` of
    `exp (x j - m)`.
16. `expSum_error`: in every IEEE format, for every `n`, tree `t`, inputs and word `m`: if every
    difference `Model.sub (x j) m` is finite and the sum of the terms along `t` is finite, the sum
    is within `MixedError … 0 (expSumErr u η t.depth (x - m))` of `Σ_j exp (x j - m)`.
17. `softmax_error`: in every IEEE format, for every `n`, tree `t`, inputs, word `m` whose real
    value is some input's (the maximum of statement 14, or any input) and index `j`, with `A` the
    absolute error of statement 16: if every difference is finite, `A < 1`, the sum is finite and
    the entry is finite, the entry is within `MixedError … ((1 + u) · ((r + A) / (1 - A)) + u)
    ((1 + u) · η / (1 - A) + η)` of TorchLean's real softmax
    `TorchLean.TransformerBlock.softmax Finset.univ x j`, with `r = (1 + u) · exp (u · |x j - m|) - 1`.
    The exponential of `-∞` is `+0`, a finite word, so the differences' finiteness is a premise and
    not a consequence of the entry's.

### Instances (MojoProofTest/FloatTree.lean, MojoProofTest/FloatStats.lean)

Each headline statement has one binary32 instance whose premises are discharged by evaluation
(`decide +kernel`): `chain_error`, `chain_mixed` (statements 5 and 6 at a loop), `halve_ones`
(statement 10 over 8 cells), `block_ones` (statement 11 with two warps), `mean_xs` and `var_xs`
(statements 12 and 13 at the inputs `1, 2, 3, 4`, the mean along a loop and the squares along a
pairwise tree), `max_xs`, `term_xs`, `expSum_xs` (statements 14 to 16), and `softmax_ones`
(statement 17 at four inputs `1` shifted by their maximum, with `A < 1` by `norm_num` on FloatLib's
binary32 constants in `errA_lt`). Each is one example, not a claim about a program.

## Proofs

1. Induction on `t`. The depth uses that every `f j` has the same depth at `t`'s leaves.
   `eval_roundsTree`: induction on the rounds, with `eval_graft` at the first one.
2. Statement 1 rewrites the leaves to a `flatMap`; a permutation of `t`'s leaves permutes the
   `flatMap`, and the `flatMap` over `0, …, W - 1` of the blocks `b·w + ·` is `0, …, W·b - 1`
   (induction on `W`, `List.range_add`).
3. A finite sum has finite operands (FloatLib's `Model.isFinite_of_isFinite_add`); induction.
4. FloatLib's depth bound, `eval_add_eq_sum` and the permutation on both sums.
5. Statement 3 on `t.map v`, then FloatLib's IEEE depth bound and the permutation.
6. Statement 5, then the triangle inequality with each leaf's error, bounding `Σ |v j|` by
   `Σ |w j| + Σ (r j · |w j| + a j)`.
7. The leaves of `bflyTree ms l` are `L ms` XOR `l`, with `L` the leaves of lane 0. A round
   appends `L` XOR `m` to `L`, two rounds commute up to a permutation, so `L` depends only on the
   multiset of the offsets; at `1, 2, …, 2 ^ (k - 1)` in order `L` is `0, …, 2 ^ k - 1`
   (`List.range_add`), and XOR with `l < 2 ^ k` permutes that list (it has no duplicates and stays
   below `2 ^ k`).
8. Statement 4 or 5 rewritten by `eval_bflyTree` and `depth_bflyTree`.
9. Induction on `k`: by the definition of `roundsTree`, cell 0's tree over `halvings (k + 1)` is its tree over
   `halvings k` with each leaf `c < 2 ^ k` replaced by the pair `c, c + 2 ^ k`, so its leaves are
   those of `0, …, 2 ^ k - 1` followed by those shifted by `2 ^ k` (`List.flatMap_append_perm`,
   `List.range_add`), and its depth grows by 1 (statement 1).
10. Statement 5 at cell 0's tree, with `eval_roundsTree` and statement 9.
11. Statement 1 (`eval_graft`, FloatLib's `eval_map`, `eval_bflyTree`) for the value, statement 2
    with statement 7 at lane 0 for the leaves, `depth_graft` for the depth, then statement 5.
12. Statement 5 as an absolute `MixedError` of the sum, then FloatLib's quotient rule
    `Model.mixedError_toReal_div` with the exact divisor `N` (relative error 0);
    `(Σ_j x j) / n = 𝔼 j, x j`.
13. FloatLib's `Model.mixedError_toReal_sub` for the difference with the mean of statement 12 and
    `Model.mixedError_toReal_mul` for the square give each term's error against
    `(x j - 𝔼 x) · (x j - 𝔼 x)`; statement 6 sums them along `t₂`; the quotient rule divides by
    `N`; `TorchLean.var` is the mean of those squares.
14. Induction on the tree: at finite operands `maximumNumber` is `maximum` (FloatLib's
    `maximumNumber_eq_maximum_of_not_isNaN`), finite and the real `max` (FloatLib's
    `toReal_maximum_eq_max_of_isFinite`); `max_choice` picks the side.
15. FloatLib's `toReal_exp_of_isFinite` (a finite correctly rounded exponential of a finite
    argument is the rounded real exponential), `Model.mixedError_toReal_sub` for the difference
    and `MixedError.trans_exp`.
16. Statement 6 with statement 15 at every leaf.
17. The term at `k` is `exp 0 = 1` and every term is positive, so the exact sum is at least 1 and
    FloatLib's `MixedError.relative_of_le_abs` makes the sum's absolute error `A` a relative one;
    then `Model.mixedError_toReal_div`, TorchLean's `softmax_eq_exp_sub_div` (the softmax at every
    shift `m`) and `η / ((1 - A) · Σ) ≤ η / (1 - A)`.

## Not proved

- That a grid run of a kernel computes these trees. The corpus's layer norm kernels
  (tests/corpus/layernorm/) compute the mean and variance by Welford updates merged across lanes,
  not by two passes, so statements 12 and 13 are not their bound; the corpus's reduction kernel
  sums `i32`, so no float bound applies to it.
- The normalized output of layer norm (the square root or `rsqrt.approx`, the scale and the
  shift).
- RMS norm. TorchLean's `TorchLean.Tensor.rmsNorm` (TorchLean/Tensor/Layers/Normalization.lean)
  is defined over any of its scalar contexts, the reals included, and divides each fiber by its
  largest magnitude before it takes the mean of the squares. TorchLean proves no closed form of it
  over the reals (its docstring states `x / sqrt (mean x ^ 2 + epsilon) · gamma`), and
  TorchLean.TransformerBlock, whose real softmax and layer norm the statements here are linked to,
  has no RMS norm. No statement here targets RMS norm, and none is defined here. TorchLean's
  `TorchLean.Roundoff.rms_norm_forward_error`
  (TorchLean/Verify/RuntimeApprox/Roundoff/Operators.lean) bounds `TorchLean.Tensor.rmsNorm` on
  its configured tensors with left-fold reductions.
- Any bound when a result is infinite or a NaN.

## Related results elsewhere

These are about other carriers or orders and are not reproved here:

- TorchLean's `TorchLean.Roundoff.softmax_error` (TorchLean/Verify/RuntimeApprox/Roundoff/Softmax.lean)
  bounds the stable softmax of its configured tensors, whose reductions are left folds; statements 14 to 17 are about FloatLib's `Model` words
  and any trees.
- TorchLean's `TorchLean.TransformerBlock.Arithmetic.sqrt_sum_sq_layerNorm_sub_le` bounds the
  whole layer norm for an abstract rounding of reals whose sums are indexed by their length;
  statements 12 and 13 are about words and any trees and stop at the two statistics.
- TorchLean's ordered sums and maxima (`TorchLean.Roundoff.mixedError_ordered_sum`,
  `TorchLean.Roundoff.toReal_ordered_maximum`, TorchLean/Verify/RuntimeApprox/Roundoff/Rules/ReduceOrder.lean)
  are about its configured values in a reduction order `ReduceOrder` that covers the indices.
- TorchLean's `TorchLean.TransformerBlock.get2_softmax_forward` and
  `TorchLean.TransformerBlock.get2_layerNorm_forward`
  (TorchLean/Verify/RuntimeApprox/TransformerBlock/Ops.lean) equate, at the reals, the row-wise
  forwards of its op table's `Op.softmax` and `Op.layerNorm` with `TorchLean.TransformerBlock.softmax`
  and `TorchLean.TransformerBlock.layerNorm` of each row. A kernel theorem about TorchLean's tensor
  operations can reach the statements here through them.
