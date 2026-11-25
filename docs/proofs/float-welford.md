# Float bounds of Welford's merge along any tree

Lean: MojoProof/Float/Welford.lean. Instances: MojoProofTest/FloatWelford.lean. Floats are
FloatLib's `Model fmt` words; `u = Model.unitRoundoffAt fmt` is FloatLib's unit roundoff,
`η = Model.underflowErrorAt fmt` its underflow allowance and `p = fmt.fracWidth + 1` the
precision. `MixedError x x₀ r a` is FloatLib's `|x - x₀| ≤ r · |x₀| + a` with `r, a ≥ 0`.

The statements are about words and the trees of operations a kernel performs on them, as
functions of the inputs, in every IEEE format, for every tree and length as stated. That a grid
run of a kernel performs those operations is not proved here. The shape is the one of
docs/proofs/float-reductions.md: if the computed words are finite, they are within the stated
bound of the exact real values, TorchLean's where TorchLean has them.

## The merge

A one-pass layer norm keeps a Welford state per partial result: a count word, a mean word and a
word for the sum of squared deviations from the mean. `wsingle x` is the state `(1, x, +0)` of one
input. `wmerge a b` is the merge the compiled layer norm kernels execute
(tests/corpus/layernorm/ln_rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a.nvptx.ll, lines 250-268, the
first butterfly round; the other rounds repeat it), one IEEE operation per instruction: with
`δ = μb - μa` and `f = nb / maxnum (na + nb, 1)`, the state
`(na + nb, μa + δ · f, (Ma + Mb) + ((δ · δ) · na) · f)`. `welford t x` evaluates a FloatLib
`ReductionTree` with `wmerge` at the nodes and `wsingle` at the leaves (each thread's loop, then a
warp's butterfly rounds or a block's halvings): it is `welfordC` below at the constant choice
`(false, false)`. `wvar t x` divides its sum word by its count word.

The compiled kernels write the merge's two products as `fmul contract` / `fadd contract` pairs
(lines 263-264, the sum's `((δ · δ) · na) · f` added to `Ma + Mb`; lines 266 and 268, the mean's
`δ · f` added to `μa`), which a backend may fuse into one `fma` each. `addMul fused c a b` is
`c + a · b`, one `Model.fma a b c` when `fused`, else `Model.add c (Model.mul a b)`;
`wmergeC fm fv` is the merge with the mean's pair `addMul fm` and the sum's pair `addMul fv`, so
`wmergeC false false` is `wmerge`.

LLVM's `contract` flag lets each pair be fused or not independently of every other pair, and
MojoProof's semantics draws that choice per executed instruction from the oracle. So the choice is
per node and per iteration. A choice for a tree is a function `c : List Bool → Bool × Bool` of a
node's position, the path from the root (`false` for a left child, `true` for a right child):
`welfordC c t x` is `wsingle (x j)` at a leaf `j`, and at a node `wmergeC (c []).1 (c []).2` of
its children's states, the left child's taken at the choice `c ∘ List.cons false` and the right
child's at `c ∘ List.cons true`. So the node at position `p` merges with the mean's pair fused
exactly when `(c p).1` and the sum's exactly when `(c p).2`. The four uniform policies are the
constant functions `c = fun _ => (fm, fv)`.

Each thread's loop (line 116 and lines 148-156, again at lines 184-192) updates its state one input
at a time: `wupdate fm fv (n, μ, M) x` is `(n + 1, μ + δ · f, M + ((δ · δ) · n) · f)` with
`δ = x - μ` and `f = 1 / (n + 1)`, its two pairs fused or not as in `wmergeC`. A choice for the
loop is a function `c : ℕ → Bool × Bool` of the iteration: `wloop c xs` applies
`wupdate (c i).1 (c i).2` at iteration `i` (from `0`) to the state and the word `xs[i]`, from the
state `(+0, +0, +0)`, the words in order. The uniform policies are again the constant `c`.

`welfStep u η B` maps an operand's error pair `(e, g)` (mean word within `e` of the mean, sum word
within `count · g` of the sum of squared deviations) to the merged one; `welfErr u η B d` is
`(0, 0)` at depth 0 and `welfStep` once per level.

## Statements

1. `welford_error`: in every IEEE format, for every tree over any index type with at most `2 ^ p`
   leaves, inputs within `B` in magnitude and `d ≥` the tree's depth: if the three words of
   `welford t x` are finite, the count word is the number of leaves `l`, the mean word is within
   `(welfErr u η B d).1` of the leaves' mean and the sum word within `l · (welfErr u η B d).2` of
   their sum of squared deviations `Σ x j² - (Σ x j)² / l`.
   `welfordC_error`: the same for `welfordC c t x`, for every choice `c` of contraction at each
   node, with the same bounds (they do not depend on `c`); `welford_error` is its case
   `c = fun _ => (false, false)`.
2. `wmean_error`: for every `n ≤ 2 ^ p` and tree whose leaves are `0, …, n - 1` up to order, under
   the same premises, the mean word is within `(welfErr u η B t.depth).1` of `𝔼 j, x j`.
3. `wvar_error`: if moreover the variance word is finite, it is within
   `MixedError … u ((1 + u) · (welfErr u η B t.depth).2 + η)` of TorchLean's population variance
   `TorchLean.var` of the inputs' real values.
4. `wloop_error`: in every IEEE format, for every choice `c` of contraction at each iteration and
   every list `xs` of at most `2 ^ p` words within `B` in magnitude: if the three words of
   `wloop c xs` are finite, the count word is
   the length `l`, the mean word is within `(welfErr u η B (l - 1)).1` of the words' mean and the
   sum word within `l · (welfErr u η B (l - 1)).2` of their sum of squared deviations: statement
   1's bounds at depth `l - 1`.

These cover Welford's merge and loop. The two-pass mean and variance (`mean_error` and `var_error`,
docs/proofs/float-reductions.md) are another algorithm and keep their own bounds. To first order,
`welfErr` grows with the depth like `d · u · B` for the mean and `d² · u · B²` for the sum: the
bounds are in terms of the inputs' magnitude `B`, not of their spread.

## Instances (MojoProofTest/FloatWelford.lean)

`welford_iota`, `welfordC_iota`, `wmean_iota` and `wvar_iota`: statements 1 to 3 in binary32 for
every `k ≤ 24` at the inputs `1, …, 2 ^ k` along cell 0's halving tree over `2 ^ k` cells
(`halveFin k`), with `B = 2 ^ k`, under the finiteness of the inputs' and the merges' words. Their
instances, one line each by the command `theorem name := e`, a `theorem` without a type, with the
finiteness premises discharged by evaluation (`decide +kernel`): `welford_xs`, `wmean_xs` and
`wvar_xs` at `k = 2`, the inputs `1, 2, 3, 4` along the pairwise tree `(0 + 2) + (1 + 3)`, where
the merges give the count `4`, the mean `2.5`, the sum `5` and the variance `1.25`; `welford8`,
`wmean8` and `wvar8` at `k = 3`, the count `8`, the mean `4.5`, the sum `42` and the variance
`5.25`. `welfordC_iota` is statement 1's `welfordC_error` there for every choice `c`, with the
instances `welfordC_xs` and `welfordC8` at `k = 2` and `k = 3` with both pairs fused at every node,
and `welfordC_alt4` and `welfordC_alt8` at `k = 2` and `k = 3` at the choice `altNode`, which fuses
the mean's pair at the nodes of even depth and the sum's at the nodes of the root's right
subtree (the paths that start with `true`), and so differs
between the root and its two children (checked by `#guard`). The words are the same as unfused:
every operation is exact on these inputs. `wloop_iota`: statement 4 in binary32 for every
`k ≤ 24` at the inputs `1, …, 2 ^ k` in order, for every choice `c`, with its instances `wloop_xs`
(`k = 2`, no pair fused), `wloop8` (`k = 3`, both pairs fused at every iteration), and
`wloop_alt4` and `wloop_alt8` (`k = 2` and `k = 3`) at the choice `altIter`, which fuses the
mean's pair at the even iterations and the sum's at the iterations `i` with `i % 3 = 1`; the
loop's words are finite by evaluation. `welford_eq_eval` checks that `welford` is the fold
`ReductionTree.eval wmerge` of the single states, for every tree and binary32 words, so `wmerge`
is the unfused merge. `xs_bound` is the bound `4` on `1, 2, 3, 4`. Each instance is one example,
not a claim about a program.

## Proofs

1. Induction on the tree, for every choice at once (the children take the choice shifted by
   their position), carrying the count word's exactness, the bounds on the parts' sums and
   sums of squares (`list_bound`) and the two errors. The counts are integers at most `2 ^ p`, so
   their sums are exact (FloatLib's `Model.roundAt_intCast_of_abs_le`) and `maxnum (na + nb, 1)`
   is `na + nb`. Every other operation is FloatLib's rounding (`Model.mixedError_roundAt`):
   `mean_step` bounds the merged mean word against `μa + (μb - μa) · f` and `dev_step` the merged
   sum word against `Da + Db + (μb - μa)² · na · f`, with the operands' errors as `welfStep`
   states them. `merge_mean` and `merge_dev` are the exact merges of the real statistics, and
   `stats_bound` bounds the parts' means and deviations by `B`. The proof is `welfordC_error`'s:
   `addMul_round` gives, for a finite `addMul fused c a b`, a real `P` within one rounding of
   `a · b` (the rounded product unfused, `a · b` itself fused) with the word within one rounding
   of `c + P` (FloatLib's `Model.toReal_fma_eq_roundAt` when fused), which are the premises
   `mean_step` and `dev_step` take; `welford_error` is its case without fused pairs.
2. Statement 1 at the tree's depth, the permutation on the sums and `𝔼 j, x j = Σ x j / n`.
3. Statement 1, then FloatLib's `Model.mixedError_toReal_div` with the exact count, and
   `TorchLean.var x = (Σ x j² - (Σ x j)² / n) / n` (`var_eq`).
4. Induction on the list from its end (`List.reverseRecOn`). The first step is exact: `+0 + 1`
   is `1`, `x - +0` is `x`, `1 / 1` is `1`, and `addMul_zero_one` gives `+0 + x · 1 = x` and
   `+0 + 0 · 1 = 0`. Each later step is a merge of the state with one word's statistics (count
   `1`, mean `x`, sum `0`): the count `l + 1` is exact, and `mean_step` and `dev_step` apply with
   `nb = 1`, `Db = Yb = 0` and the sum word itself in place of the rounded `Ma + Mb`, so the bound
   after `l + 1` words is `welfStep` of the bound after `l`, whatever the choice at iteration `l`.

## Not proved

- Merges with an empty state (count `0`, a thread without inputs).
- That a grid run of the corpus's layer norm kernels computes `wloop` over each thread's inputs
  and then `welford` along its tree, and the bound of that composition.
- Any bound when a word is infinite or a NaN.
