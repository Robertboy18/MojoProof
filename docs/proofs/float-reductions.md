# Float bounds of reductions: any tree, butterflies of any width, block trees, mean, variance, max-subtracted exponential sums, the compiled exponential and log-softmax, commutativity up to NaN payloads and trees up to swapped children

Lean: MojoProof/Float/Tree.lean, MojoProof/Float/Halve.lean, MojoProof/Float/Stats.lean,
MojoProof/Float/ExpSum.lean, MojoProof/Float/Ex2.lean, MojoProof/Float/Canon.lean,
MojoProof/Float/CanonIff.lean, MojoProof/Float/CardSums.lean, MojoProof/Float/CanonHalve.lean
and the additions to MojoProof/Sem/Bfly.lean and MojoProofTest/Bfly.lean. Instances:
MojoProofTest/FloatTree.lean, MojoProofTest/FloatStats.lean, MojoProofTest/FloatEx2.lean,
MojoProofTest/FloatCanon.lean, MojoProofTest/FloatCanonIff.lean, MojoProofTest/FloatCardSums.lean
and MojoProofTest/FloatCanonHalve.lean.
Welford's one-pass mean and variance are in
docs/proofs/float-welford.md, layer norm's and RMS norm's outputs in docs/proofs/float-norm.md.
Floats are FloatLib's
`Model fmt` words; `u = Model.unitRoundoffAt fmt` is FloatLib's unit roundoff and
`η = Model.underflowErrorAt fmt` its underflow allowance. `MixedError x x₀ r a` is FloatLib's
`|x - x₀| ≤ r · |x₀| + a` with `r, a ≥ 0` (FloatLib/Numerics/MixedError/Basic.lean).

Every statement here is about words and the trees of operations a kernel performs on them, as
functions of the inputs. That a grid run of a kernel performs those operations is not proved here
(see "Not proved"). Statements 1 to 26 hold in every IEEE format (`fmt.isIEEE = true`) and
statements 27 to 31 in every format, statements 32 and 33 in every IEEE format, statements 34
to 36 for every size and statement 37 in every format, for every length and every tree as stated;
none of them is about one program.

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
theirs. The strides `2 ^ (k - 1), …, 2, 1` are the butterfly's offsets `bflyOffsets k`
(MojoProof/Sem/Bfly.lean), so the halving loop over `2 ^ k` cells is
`rounds combine halveStep (bflyOffsets k)` and cell 0's tree is
`roundsTree halveStep (bflyOffsets k) 0`.

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

The same module has RMS norm's mean of squares `msq t x N` and its bound `msq_error`
(docs/proofs/float-norm.md, statement 1).

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

### The compiled exponential (MojoProof/Float/Ex2.lean)

Mojo's `exp` on float32 is not a correctly rounded exponential. Its NVPTX lowering of
`exp (x - m)` is `fsub contract`, `fmul contract` by the word `0x3FB8AA3B` of `log₂ e` (`log2e`)
and the instruction `ex2.approx.ftz.f32` as inline assembly (the standard library's `math.exp`). A
subtraction followed by a multiplication cannot contract, so the instruction's operand is
`Model.mul (Model.sub x m) log2e`. PTX ISA 9.5 §9.7.3.21 states its accuracy: at most 2 ulp from
the correctly rounded result across the full range of inputs, with subnormal inputs and results
flushed to zero of their sign. Its consequence at a finite operand `a < 128` is the contract
`Ex2Close a w`: the word `w` is finite and within `ex2Err · 2 ^ a + ex2Tiny` of `2 ^ a`, with
`ex2Err = 3 · 2 ^ -23` (two ulp of a normal value `c` are at most `2 ^ -22 · c`, and the correctly
rounded `c` is within `2 ^ -24 · 2 ^ a` of `2 ^ a`) and `ex2Tiny = 2 ^ -126` (a flushed result, a
result near the subnormal range or the `1` of a flushed subnormal operand). The contract is an
assumption on the hardware, as `rsqrt.approx`'s is; the execution model stops at inline assembly.
`ex2Rel u η ρ y = (1 + ex2Err) · exp (((1 + u) · (u + ρ + u ρ) + u) · |y| + η · log 2) - 1` is one
term's relative error.

18. `log2e_close`: the word `log2e` (`12102203 / 2 ^ 23`) is within `MixedError … 2 ^ -26 0` of
    `1 / log 2`.
19. `ex2_error`: for every binary32 multiplier word `L` within `MixedError … ρ 0` of `1 / log 2`
    and words `x`, `m`, `w`: if the operand `Model.mul (Model.sub x m) L` is finite and `w` meets
    the contract there, `w` is within `MixedError … (ex2Rel u η ρ (x - m)) ex2Tiny` of
    `exp (x - m)`.
20. `ex2Sum_error`: for every `n`, tree `t` whose leaves are a permutation of the `n` indices,
    such `L`, words `x`, word `m` and term words `e`: if every operand is finite, every `e j`
    meets the contract at its operand and the sum of the `e j` along `t` is finite, the sum is
    within `MixedError … 0 (((1 + u) ^ d - 1) · Σ_j exp (y j) + (1 + u) ^ d ·
    Σ_j (ex2Rel u η ρ (y j) · exp (y j) + ex2Tiny))` of `Σ_j exp (x j - m)`, with `y j = x j - m`
    and `d = t.depth`: statement 16's form with the compiled term's error.

### Log-sum-exp and log-softmax (MojoProof/Float/ExpSum.lean)

`lse t b c x m` is `Model.add m (log s)` and `logSoftmax t b c x m j` is
`Model.sub (Model.sub (x j) m) (log s)`, with `s` the sum of statement 16 and `log` FloatLib's
correctly rounded `Model.Transcendentals.CorrectlyRounded.log` with the search budget `c`. The
entry is in the order of Mojo's three-pass CPU log-softmax (max/kernels/src/nn/softmax.mojo,
`_softmax_3_pass_base` with `identity`, `exp`, `log` and `sub`): it stores `x j - m`, sums the
exponentials and subtracts the logarithm of the sum. With `S = Σ_j exp (x j - m)` and `A` the
absolute error of statement 16:

21. `lse_error`: in every IEEE format, for every `n`, tree `t`, budgets, inputs and word `m` whose
    real value is some input's: if every difference is finite, `A < 1`, the sum is finite and
    `lse` is finite, it is within `MixedError … u ((1 + u) · (u · log S + (1 + u) · -log (1 - A)
    + η))` of `log Σ_j exp (x j)`.
22. `logSoftmax_error`: under the same premises with the entry `j` finite in place of `lse`, the
    entry is within `MixedError … u ((1 + u) · (u · |x j - m| + (u · log S + (1 + u) ·
    -log (1 - A) + η)))` of `x j - log Σ_i exp (x i)`. TorchLean has no log-softmax over the reals
    as a function of `Fin n → ℝ` in the modules built here; its
    `TorchLean.Roundoff.CrossEntropy.log_probs_reference`
    (TorchLean/Verify/RuntimeApprox/Roundoff/CrossEntropy.lean, not built here) states its
    reference in this real form, which is written out here rather than defined a second time.

The relative part `u` is of the result itself; the absolute part grows with `log S ≤ log n` and,
through `-log (1 - A)`, with the sum's error.

### Masked inputs (MojoProof/Float/ExpSum.lean)

A masked input is `-∞`: less a finite `m`, its difference is `-∞`, whose correctly rounded
exponential is `+0`, an exact zero of the sum. `maskErr U u η d y` is `expSumErr`'s form with both
sums over the kept indices `U`, and `expSumErr` is `maskErr` with every index kept.

23. `expTerm_negInf`: in every format, if the difference `Model.sub (x j) m` is `-∞` (infinite with
    its sign bit set), the term `expTerm b x m j` is the word `+0`.
24. `maskSum_error`: in every IEEE format, for every `n`, tree `t`, inputs, word `m` and set `U` of
    kept indices: if the difference is finite at every `j ∈ U` and `-∞` at every other index and
    the sum of the terms along `t` is finite, the sum is within
    `MixedError … 0 (maskErr U u η t.depth (x - m))` of `Σ_{j ∈ U} exp (x j - m)`.
25. `maskSoftmax_error`: in every IEEE format, for every `n`, tree `t`, inputs, set `U`, word `m`
    whose real value is some kept input's and index `j ∈ U`, with `A = maskErr U u η t.depth
    (x - m)`: if the differences are as in statement 24, `A < 1`, the sum is finite and the entry
    is finite, the entry is within statement 17's mixed error with this `A` of TorchLean's real
    softmax over the kept indices `TorchLean.TransformerBlock.softmax U x j`.

Statements 16 and 17 are statements 24 and 25 with every index kept, and are proved so.

### The entry in the kernel's order (MojoProof/Float/ExpSum.lean)

Mojo's GPU softmax computes an entry as `e_j * (1 / s)`: the reciprocal of the sum rounded, then
the product, where statements 17 and 25 take one `Model.div e_j s`. With `r = termErr u (x j - m)
= (1 + u) · exp (u · |x j - m|) - 1`, the term's relative error of statement 15, and
`q = recipErr u A = (1 + u) · (A / (1 - A)) + u`, the reciprocal's:

26. `softmaxRecip_error`: in every IEEE format, for every `n`, tree `t`, inputs, set `U`, word `m`
    whose real value is some kept input's and index `j ∈ U`, under statement 25's premises on the
    differences, `A < 1` and the sum: if the entry
    `Model.mul (expTerm b x m j) (Model.div 1 s)` is finite, it is within
    `MixedError … ((1 + u) · (r + q + r · q) + u)
    ((1 + u) · ((1 + q) · η + (1 + r) · η · exp (x j - m) + η²) + η)` of TorchLean's real
    softmax over the kept indices `TorchLean.TransformerBlock.softmax U x j`; `U = Finset.univ`
    is the unmasked softmax of statement 17.

### Commutativity and trees up to swapped children (MojoProof/Float/Canon.lean)

`NaNEq x y` is `MojoProof.Sem.NaNEq`, `GPUProof.UpToNaN Model.isNaN`: the words are equal, or
both are NaNs. These statements hold in every format FloatLib's `Model` has, IEEE or not, and for
every leaf type with a linear order and every tree.

They are items for FloatLib's intake: FloatLib has no commutativity of `Model.add` and no
canonical form of a `ReductionTree`, and would carry them as `Model.add_comm_nanEq`,
`ReductionTree.canon`, `ReductionTree.canon_canon` and `ReductionTree.eval_canon`. Here they are
in the namespace `MojoProof.Float`: the pinned FloatLib (v4.1.0) takes no new declarations, and
a later FloatLib that has them would clash with declarations made in its own namespace.

`canon t` is the canonical form of `t` up to swapping the two children of nodes: at each node it
puts the canonical forms of the two children in the order of `treeCmp`. `treeCmp` compares two
leaves by the leaf type's order, puts a leaf before a node, and compares two nodes by their left
children, then by their right ones. It is a total order on whole trees (`.eq` exactly at equal
trees, and swapping the two trees swaps the result), so `canon` is defined at every tree,
repeated leaves included. Ordering the children by their least leaf or by their leaf lists would
not do: those keys tie at two different children with the same leaves (`a + (b + c)` and
`(a + b) + c` under one node), and the form would then depend on the order the two were given in.

27. `add_comm_nanEq`: for every format and words `x`, `y`,
    `NaNEq (Model.add x y) (Model.add y x)`, with no premise. Equality fails at two NaNs, as
    `Model.chooseNaN2` returns the first operand among two quiet NaNs, payload included.
28. `canon_canon`: `canon (canon t) = canon t`. `perm_canon`, `depth_canon`: the leaves of
    `canon t` are a permutation of `t`'s, and its depth is `t`'s.
29. `canon_node_comm`, `canon_node_eq_iff`: `canon (node a b) = canon (node b a)`, and
    `canon (node a b) = canon (node a' b')` exactly when `a` and `b` have the canonical forms of
    `a'` and `b'` or of `b'` and `a'`. With `canon (leaf x) = leaf x` and `canon` of a node a node,
    two trees have the same `canon` exactly when one is the other with the two children of some
    of its nodes swapped.
30. `eval_canon`: for every carrier, operation `f` and equivalence `R` such that `f x y` is
    related to `f y x` and `f` maps related operands to related results, every leaf type, values
    and tree `t`, `(canon t).eval f v` is related to `t.eval f v`. `eval_canon_nanEq` is its case
    at `Model.add` and `NaNEq`, in every format, by statement 27 and `NaNEq.op` at `fadd`.
31. `eval_nanEq_of_canon`: in every format, two trees with the same `canon` agree on every input
    up to NaN payloads: `NaNEq (t.eval Model.add v) (t'.eval Model.add v)` for every `v`. This is
    one direction of the characterization of the trees whose IEEE sums agree, Theorem 4.3.1 of
    Huang and Lehtonen (Discrete Mathematics, 2023) at IEEE addition; the other direction is
    statement 32.

### Trees whose IEEE sums agree (MojoProof/Float/CanonIff.lean)

32. `eval_add_eq_iff`: in every IEEE format (`fmt.isIEEE = true`), for every leaf type with a
    linear order and two trees `t`, `t'` whose leaves are a permutation of each other without
    repeats, `t` and `t'` agree up to NaN payloads on every input,
    `∀ v, NaNEq (t.eval Model.add v) (t'.eval Model.add v)`, exactly when
    `canon t = canon t'`. With statement 29, two such trees give the same sums up to NaN payloads
    exactly when one is the other with the children of some of its nodes swapped: Huang and
    Lehtonen's Theorem 4.3.1 at IEEE addition. `←` is statement 31 and needs neither premise on
    the leaves. With repeated leaves the proof of `→` does not apply, and the statement is not
    claimed there.

The witness and the separating input are DistLean's (`DistLean.Bracket.ieeeWitness`,
`ieeeWitness_symm` and `DistLean.Bracket.Separator.exists_eval_ne`, DistLean/Identifiability.lean),
restated for leaf membership and both orders of each sum; the module's helper lemmas are private.

### What DistLean's `identifiable_ieee` gives

`DistLean.Bracket.identifiable_ieee` (DistLean/Identifiability.lean): in every IEEE format, two
bracketings `t t' : Bracket i j` that give the same bits on every input `ℕ → Model fmt` are equal.
It does not give statement 32, `eval_add_eq_iff`:

* `Bracket i j` is another type from `ReductionTree`: its leaves are the units `i, …, j - 1` in
  order, and there is no map between the two types;
* the children of a bracketing are in the order of their units, so two trees that differ by
  swapping children are never bracketings of the same units, and the theorem says nothing of
  them. `eval_add_eq_iff` is about trees up to such swaps, which needs both orders of each
  witness sum (`DistLean.Bracket.ieeeWitness_symm`, which `identifiable_ieee` does not use);
* it assumes the same bits, and `eval_add_eq_iff` only agreement up to NaN payloads. The witness
  meets that too, since `ε` and `+0` are not NaNs (DistLean's `Separator.exists_obs_ne` at the
  observation that forgets a NaN's payload).

What carries over is the witness and its laws, the shape of the induction (roots that split
differently get `x, y, z` on three leaves; roots that split alike recurse into a child with zero
on the other side) and the evaluation lemmas, restated for leaf membership.

### The sums of distinct inputs as canonical trees (MojoProof/Float/CardSums.lean)

For every `n`, `FullTree n` is the trees over `Fin n` whose leaf list is a permutation of
`List.finRange n` (each index once), `SumFunction fmt n` is their quotient by agreeing up to NaN
payloads on every input of `fmt` (`sumSetoid fmt n`, an equivalence as `NaNEq` is), and
`CanonTree n` is the trees of `FullTree n` with `canon t = t`.

33. `sumFunctionEquiv`: in every IEEE format and for every `n`,
    `SumFunction fmt n ≃ CanonTree n`, a class to the `canon` of its trees and a canonical tree to
    its class; so `card_sumFunction`: `Nat.card (SumFunction fmt n) = Nat.card (CanonTree n)`.
    `card_canonTree`: for every `n ≥ 1`, `Nat.card (CanonTree n) = (2 * n - 3)‼` (`1` at
    `n = 1`, with `ℕ`'s subtraction); so `card_sums`: in every IEEE format and for every
    `n ≥ 2`, `Nat.card (SumFunction fmt n) = (2 * n - 3)‼`, the number of sums of `n` distinct
    inputs that differ on some input, up to NaN payloads. At `n = 0` there is no tree, hence
    `hn`.

    ```lean
    theorem card_canonTree {n : ℕ} (hn : 1 ≤ n) : Nat.card (CanonTree n) = (2 * n - 3)‼

    theorem card_sums {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) {n : ℕ} (hn : 2 ≤ n) :
        Nat.card (SumFunction fmt n) = (2 * n - 3)‼
    ```

### The butterfly and halving trees up to swapped children (MojoProof/Float/CanonHalve.lean)

Write `H k` for cell 0's tree after the halving rounds over `2 ^ k` cells,
`roundsTree halveStep (bflyOffsets k) 0`; `H 0` is the leaf `0`.

34. `halve_succ`: for every `k`, `H (k + 1)` is the node of `H k` with each leaf `i` relabelled
    `2i` and `H k` with each leaf relabelled `2i + 1` (FloatLib's `ReductionTree.map`): the even
    cells on the left, the odd ones on the right. `H 2` is `(0 + 2) + (1 + 3)`. `canon_halve`:
    for every `k`, `H k` is its own `canon` (`Function.IsFixedPt canon (H k)`).
35. `canon_bflyTree_xor`: for every list of offsets `ms`, offset `m ∈ ms` and lane `l`,
    `canon (bflyTree ms (l ^^^ m)) = canon (bflyTree ms l)`, with no other premise.
    `canon_bflyTree_lane`: for every `k` and offsets `ms` among which are
    `1, 2, …, 2 ^ (k - 1)` (in any order, other offsets allowed), every lane `l < 2 ^ k` has
    `canon (bflyTree ms l) = canon (bflyTree ms 0)`. `bflyTree_xor`: for every list of offsets
    `ms` and every lane `l`, at or above `2 ^ k` too, `bflyTree ms l` is `bflyTree ms 0` with each
    leaf `j` relabelled `j ^^^ l`.
36. `canon_bflyOffsets`: for every `k` and lane `l < 2 ^ k`, lane `l`'s tree after the rounds
    `bflyOffsets k` (`2 ^ (k - 1), …, 2, 1`) has the canonical form of `H k`, which is `H k`
    (statement 34): the butterfly's trees and the halving tree are one tree up to swapping the
    children of nodes. `canon_bflyTree_perm`: for every `k`, offsets `ms` that are `bflyOffsets k`
    in any order (`List.Perm`) and every lane `l`, `canon (bflyTree ms l)` is `bflyTree ms 0` with
    each leaf `j` relabelled `j + 2 ^ k ⌊l / 2 ^ k⌋`. At `l = 0` it says that lane 0's tree is its
    own `canon`; so every lane below `2 ^ k` has lane 0's tree as its canonical form, and a lane at
    or above `2 ^ k` has that tree over the lanes `2 ^ k ⌊l / 2 ^ k⌋` to
    `2 ^ k ⌊l / 2 ^ k⌋ + 2 ^ k - 1` of its group. In another order lane 0's tree is not `H k`
    (`order_ne` below), so statement 36's first form is about `bflyOffsets k` itself.
37. `bfly_nanEq_lane`: in every format, for every `k`, offsets `ms` as in statement 35, values
    `v` and lane `l < 2 ^ k`, lane `l`'s and lane 0's sums after the butterfly rounds of
    `Model.add` are `NaNEq`. `bfly_nanEq_halve`: in every format, for every `k`, values `v` and
    lane `l < 2 ^ k`, lane `l`'s sum after the butterfly rounds `bflyOffsets k` and cell 0's sum
    after the halving rounds over `2 ^ k` cells are `NaNEq`.

    ```lean
    theorem canon_bflyOffsets (k : Nat) {l : Nat} (hl : l < 2 ^ k) :
        canon (bflyTree (bflyOffsets k) l) = canon (roundsTree halveStep (bflyOffsets k) 0)

    theorem canon_bflyTree_perm {k : Nat} {ms : List Nat} (hms : ms.Perm (bflyOffsets k))
        (l : Nat) : canon (bflyTree ms l) = (bflyTree ms 0).map (· + 2 ^ k * (l / 2 ^ k))

    theorem bfly_nanEq_halve {fmt : FloatFormat} (k : Nat) (v : Nat → Model fmt) {l : Nat}
        (hl : l < 2 ^ k) :
        NaNEq (bflyRounds (fun x y => Model.add x y) (bflyOffsets k) v l)
          (rounds (fun x y => Model.add x y) halveStep (bflyOffsets k) v 0)
    ```

### Instances (MojoProofTest/FloatTree.lean, MojoProofTest/FloatStats.lean, MojoProofTest/FloatEx2.lean)

Each headline statement has one binary32 instance whose premises are discharged by evaluation
(`decide +kernel`): `chain_error`, `chain_mixed` (statements 5 and 6 at a loop), `halve_ones`
(statement 10 over 8 cells), `block_ones` and `block_ones8` (statement 11 with two warps and
with four groups of 8 lanes), `mean_xs` and `var_xs`
(statements 12 and 13 at the inputs `1, 2, 3, 4`, the mean along a loop and the squares along a
pairwise tree), `max_xs`, `term_xs`, `expSum_xs` (statements 14 to 16), `softmax_ones`
(statement 17 at four inputs `1` shifted by their maximum, with `A < 1` by `norm_num` on FloatLib's
binary32 constants in `errA_lt`), `lse_ones` and `logSoftmax_ones` (statements 21 and 22 under
`softmax_ones`'s premises, with the correctly rounded logarithm of the sum `4`), and
`term_masked`, `maskSum_masked` and `maskSoftmax_masked` (statements 23 to 25 at the inputs
`1, -∞, 1, -∞` less `1`, kept at `0` and `2`, with `A < 1` in `errM_lt`). Statement 26 has two,
`softmaxRecip4` and `softmaxRecip8`, at four and eight inputs `1` less `1` along `halveFin 2` and
`halveFin 3`, every index kept, each with `A < 1` closed by the tactic `recip_num`. `ex2_ones` and
`ex2Sum_ones` are statements 19 and 20 at four inputs `1` less the word `1` with `L = log2e`: the
operand is `+0`, at which the word `1` meets the contract (`zero_close`). Each is one example, not
a claim about a program.

`block_halve` is statement 11 at the inputs `1` for every `k` halving rounds after `j` butterfly
rounds, its premise the finiteness of the sum word; `block_ones` and `block_ones8` are its cases
at `(1, 5)` and `(2, 3)`, declared by the command `theorem name := e`, a `theorem` without a type
(MojoProofTest/FloatTree.lean), which states the type of the term `e`. The inputs `xs` are `iota 4`, the words of `1, …, n` at `n = 4`,
and `pairs` is `halveFin 2`, cell 0's halving tree over `2 ^ k` cells with its leaves in
`Fin (2 ^ k)` at `k = 2`; `iota_toReal`, `iota_bound`, `var_iota` and `msq_iota` give their real
values, bound, variance `(n ^ 2 - 1) / 12` and mean of squares `(n + 1) (2 n + 1) / 6` at every
`n ≤ 2 ^ 24` (MojoProofTest/FloatStats.lean). `four_toReal` and `eight_toReal` are `nat32_toReal`,
the real value of the word of a natural number `m ≤ 2 ^ 24`, at `4` and `8`.

Statements 27 to 31 have tests of one example each in MojoProofTest/FloatCanon.lean. `nan_add32`
and `nan_add16`: at the quiet NaNs `0x7fc00001` and `0x7fc00002` of binary32 and `0x7e01` and
`0x7e02` of binary16, `Model.add x y ≠ Model.add y x` by evaluation, so statement 27's `NaNEq` is
not equality. `canon3` and `canon5`: `canon` of `(2 + 0) + 1` is `1 + (0 + 2)` and `canon` of
`(4 + (3 + 1)) + (0 + 2)` is `(0 + 2) + (4 + (1 + 3))`, over natural-number leaves by `decide`,
and each result is its own `canon` (statement 28 at them). `swap5`: statement 31 in every format
at the 5-leaf tree and the tree with the children of four of its nodes swapped, the premise by
`decide`. `assoc_canon`, `assoc_vals`, `assoc_ne`: `(a + b) + c` and `a + (b + c)` have different
`canon`, and at `a = 1`, `b = 2 ^ 24`, `c = -2 ^ 24` in binary32 their sums are `+0` (`1 + 2 ^ 24`
is a tie, rounded to the even `2 ^ 24`) and `1`, not `NaNEq`: statement 30's relation does not
hold between all trees with the same leaves.

Statement 32 has tests at two sizes and three formats, and a mutant, in
MojoProofTest/FloatCanonIff.lean. `assoc_sep`: `(a + b) + c` and `a + (b + c)` over `Fin 3`
disagree beyond NaN payloads on some binary32 input, by `→` at their different `canon`
(`assoc_canon`). Over `Fin 6`, `t6` is `((0 + 1) + 2) + (3 + (4 + 5))`, `t6s` is
`((4 + 5) + 3) + ((1 + 0) + 2)` (the children of three nodes swapped) and `t6r` is
`(0 + (1 + 2)) + ((4 + 5) + 3)` (the left child regrouped, the roots splitting the leaves alike):
`swap6` is `←` in binary16 at `t6` and `t6s`, and `split6` is `→` in binary64 at `t6` and `t6r`,
their `canon` and the premises on the leaves by `decide`. `eq_mutant`: with equality in place of
`NaNEq` the statement fails at `0 + 1` and `1 + 0` over `Fin 2`, which have the same `canon` and
differ at the binary32 quiet NaNs `0x7fc00001` and `0x7fc00002` (`nan_add32`).

Statement 33 has tests in MojoProofTest/FloatCardSums.lean. `class_l3`: the binary32 class of
`(a + b) + c` goes to `canon l3`, by evaluation. `classes_ne`: the binary32 classes of
`(a + b) + c` and `a + (b + c)` differ, as their `canon` do (`assoc_canon`). `classes_eq`: the
binary16 classes of `0 + 1` and `1 + 0` over `Fin 2` are one class, as their `canon` agree.
`card3` is `card_sumFunction` in binary64 at `n = 3`. `canon1` and `canon2`: one canonical tree
over `Fin 1` and one over `Fin 2`, by hand; so `card1` and `card2`: one binary32 sum of one input
and one binary16 sum of two inputs. `canon3` and `canon4`: `card_canonTree` at 3 and 4 leaves,
`3‼ = 3` and `5‼ = 15` canonical trees; `sums3` and `sums4`: `card_sums` at 3 inputs in binary32
and 4 in binary16, 3 and 15 sums, the values by evaluation.

Statements 34 to 37 have tests in MojoProofTest/FloatCanonHalve.lean, at 2, 4, 8 and 32 lanes or
cells. `halve3`: `H 3` is `((0 + 4) + (2 + 6)) + ((1 + 5) + (3 + 7))`, by evaluation, and
`succ2` is statement 34's `halve_succ` there; `canon3`: `H 3` is its own `canon`, by evaluation,
and `canon5` is `canon_halve` at 32 cells. `lane13`: lane 13's tree after a warp's rounds
`warpOffsets` has the canonical form `H 5`, by evaluation, and `lane13_canon` is statement 36
there.
`lane1_tree`: lane 1's tree after the rounds `2, 1` is `(1 + 3) + (0 + 2)`, not its own `canon`.
`lane5_out`: lane 5's tree after the rounds `2, 1` has the leaves `4, …, 7` and another `canon`
than the halving tree over 4 cells, so statement 36 needs `l < 2 ^ k`. `order6` is statement 35
at the rounds `1, 4, 2` and lane 6; `order_ne`: in that order lane 0's `canon` is not `H 3`, so
statement 36's `canon_bflyOffsets` is about the order `bflyOffsets k`. `zero_order`: in that order
lane 0's tree is `((0 + 1) + (4 + 5)) + ((2 + 3) + (6 + 7))` and its own `canon`, by evaluation;
`perm6` is `canon_bflyTree_perm` there at lane 6, whose canonical form is lane 0's tree, and
`xor13` is `bflyTree_xor` there at lane 13. `perm13`: lane 13's canonical form in that order is
`((8 + 9) + (12 + 13)) + ((10 + 11) + (14 + 15))`, lane 0's tree shifted by 8, and
`perm_four`: after the rounds `1, 2` lane 6's is `(4 + 5) + (6 + 7)`, both by
`canon_bflyTree_perm` then evaluation; `lane5_canon`: lane 5's canonical form after the rounds
`2, 1` is `(4 + 6) + (5 + 7)`, `lane5_out`'s tree computed. `dup_ne`: after the rounds `1, 1`,
not a permutation of `bflyOffsets 2`, lane 0's tree `(0 + 1) + (1 + 0)` is not its own `canon`.
`warp13` is statement 37 in
binary32 at a warp, lane 13, every value `1`. `payload_ne`: at 2 lanes holding the quiet NaNs
`0x7fc00001` and `0x7fc00002`, lane 1's butterfly sum and cell 0's halving sum are different
words, by evaluation: statement 37's `NaNEq` is not equality.

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
9. Induction on `k`: by the definition of `roundsTree`, cell 0's tree over `bflyOffsets (k + 1)` is its
   tree over `bflyOffsets k` with each leaf `c < 2 ^ k` replaced by the pair `c, c + 2 ^ k`, so its leaves are
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
16. Statement 24 with every index kept.
17. Statement 25 with every index kept.
18. `log2e`'s value by evaluation, then Mathlib's `Real.log_two_gt_d9` and `Real.log_two_lt_d9`:
    `|log2e · log 2 - 1| ≤ 2 ^ -26`.
19. `Model.mixedError_toReal_sub` for the difference, `Model.mixedError_toReal_mul` with `L`'s
    error and FloatLib's `MixedError.const_mul` by `log 2` put `log 2 · p` within
    `((1 + u) · (u + ρ + u ρ) + u, η · log 2)` of `x - m`; then `2 ^ p = exp (log 2 · p)` and
    FloatLib's `MixedError.trans_exp` with the contract.
20. Statement 6 with statement 19 at every leaf.
21. Statement 17's relative error `A` of the sum (shared by a private lemma), FloatLib's
    `toReal_pos_of_isFinite_log` and `toReal_log_of_isFinite` (a finite correctly rounded
    logarithm of a finite input is the rounded real logarithm of a positive one), then FloatLib's
    `MixedError.trans_log`, which needs `A < 1`, for `log S`, and `Model.mixedError_toReal_add`
    with the exact `m`; `log S = log Σ_j exp (x j) - m` (`Real.exp_sub`, `Real.log_div`) and
    `log S ≥ 0`.
22. As statement 21, with `Model.mixedError_toReal_sub` for the difference `x j - m` and for the
    entry.
23. FloatLib's correctly rounded exponential of an infinite word with its sign bit set is `+0` by
    its definition (an infinite word is not a NaN, FloatLib's
    `Model.isNaN_eq_false_of_isInfinite_eq_true`).
24. Statement 6 with the weights `exp (x j - m)` at the kept leaves (statement 15) and `0` at the
    masked ones, whose terms are `+0` (statement 23), so of real value `0` with error `(0, 0)`; a
    sum over every index of terms that are `0` outside `U` is the sum over `U` (Mathlib's
    `Finset.sum_ite_mem`).
25. The term at the kept `k` is `exp 0 = 1` and every term is positive, so the exact sum over `U`
    is at least 1 and FloatLib's `MixedError.relative_of_le_abs` makes the sum's absolute error
    `A` a relative one; then `Model.mixedError_toReal_div`, TorchLean's `softmax_eq_exp_sub_div`
    over `U` (the softmax is `exp (x j - m) / Σ_{i ∈ U} exp (x i - m)` for every `m`) and
    `η / ((1 - A) · Σ) ≤ η / (1 - A)`.
26. Statement 25's relative error `A` of the sum (the same private lemma); FloatLib's
    `Model.mixedError_toReal_div` with the exact numerator `1` (`Model.toReal_posOne`) gives the
    reciprocal's error `(q, η)`, and `Model.mixedError_toReal_mul` with statement 15's term
    error the entry's (both factors are finite by `Model.isFinite_of_isFinite_mul`); then
    `softmax_eq_exp_sub_div`, `a / Σ = a · (1 / Σ)` and `|1 / Σ| ≤ 1`, as `Σ ≥ 1`.
27. With a NaN operand both sums are NaNs (`fbin_isNaN` at `fadd`). Otherwise FloatLib's
    `Model.Proof.add_eq_spec` gives both sums as `Model.Spec.add`, and `Model.chooseNaN2` is
    `none` in both orders (`Model.chooseNaN2_none_of_not_isNaN`). At two finite operands the sum
    is the rounded `Model.addDyadic` of their values, which commutes (`Model.addDyadic_comm`); at
    one infinite operand it is that operand in both orders; at two, equal signs make the operands
    one word (`Model.eq_nativeOverflow_of_isInfinite`: an infinite word is `nativeOverflow` of its
    sign) and different signs give `Model.invalidResult` in both orders.
28. Induction on `t`, with the two properties of `treeCmp`: it is `.eq` exactly at equal trees
    and swapping the trees swaps it (induction on the two trees, from the leaf order's
    `compare_eq_iff_eq` and `Std.OrientedCmp.eq_swap`, with `Ordering.then_eq_eq` and
    `Ordering.swap_then`). A node of two canonical children in order is its own `canon`; the
    leaves and the depth are those of the children, in either order (`List.perm_append_comm`,
    `max_comm`).
29. By the cases of `treeCmp` at the children's forms; `node` is injective.
30. Induction on `t`: at a node whose children `canon` swaps, `f` maps the related forms to
    related results and commutes up to `R`, and `R` is transitive.
31. Statement 30 at `t` and at `t'`, with the symmetry and transitivity of `NaNEq`
    (`GPUProof.UpToNaN.equivalence`).
32. `←` is statement 31. For `→`, the witness: with `f` fraction bits and `ε = 2^-f`
    (`Model.roundDyadic fmt ⟨false, 1, -f⟩`), `+0` is an identity on `+0`, `ε`, `2` and `-2` on
    both sides; `ε + 2 = 2 + ε = 2`, as `2 + 2^-f` lies halfway between `2` and the next word
    `2 + 2^(1-f)` and rounds to the even `2`; `2 + (-2) = (-2) + 2 = +0`, an exact zero sum of
    operands of opposite signs rounded to nearest; and `ε` and `+0` are different words that are
    not NaNs. So `ε + (2 + -2)` is `ε` and `(ε + 2) + -2` is `+0`, whichever order each sum takes
    its operands in. Evaluation with zeros, for every carrier, operation `f` and value `z` with
    `f z z = z`: a tree reads only its leaves' values; leaves that all hold `z` give `z`; one leaf
    holding `w` among zeros gives `w` when `z` is an identity on `w` on both sides; two leaves
    holding `p` and `q` among zeros give `w` when `f p q = w = f q p` and `z` is an identity on
    `p`, `q` and `w`. Then, if `canon t ≠ canon t'`, some input with values among `+0, ε, 2, -2`
    gives `ε` at one tree and `+0` at the other, by induction on `t` for every `t'`. A leaf and a
    node have different numbers of leaves (FloatLib's `ReductionTree.length_leaves`), and two
    leaves with the same leaves are equal. At two nodes, let `L, R` be the leaves of the children
    of `t`'s root and `L', R'` those of `t'`'s. If the roots split the leaves alike (`L` and `L'`
    have the same members, or `L` and `R'`), the two children whose `canon` differ
    (`canon_node_eq_iff`, statement 29) give an input by induction, set to `+0` on the other
    children's leaves, which then give `+0`. Otherwise one child of `t`'s root meets both
    children of `t'`'s root, and there are leaves `a, b, c` with `b, c` under one child of `t`'s
    root and `a` under the other, and `a, b` under one child of `t'`'s root and `c` under the
    other; `ε, 2, -2` on them and `+0` elsewhere give `ε + (2 + -2) = ε` at `t` and
    `(ε + 2) + -2 = +0` at `t'`, in some orders.
33. A class goes to the `canon` of a tree in it: `canon t` keeps `t`'s leaves up to permutation
    (`perm_canon`) and is its own `canon` (`canon_canon`), and two related trees have the same
    `canon` by statement 32's `→`, its premises as the leaves are a permutation of
    `List.finRange n`, which has no repeats (`List.nodup_finRange`). A canonical tree goes to its
    class. Back and forth: a tree is related to its `canon` by statement 31, and a canonical tree
    is its own `canon`. `card_sumFunction` is `Nat.card_congr` at the equivalence. Over `Fin 1`, a
    node has at least two leaves (`ReductionTree.length_leaves`), so the tree is the leaf `0`.
    Over `Fin 2`, by the leaf count the tree is a node of two leaves `a, b`, and of the four pairs
    only `a = 0, b = 1` has the leaves a permutation of `[0, 1]` and `canon t = t`, by
    evaluation.

    The count goes through other representatives of the trees up to swapping children: the
    min-first trees, whose every node has the child with the smaller first leaf on the left
    (`IsMinFirst`). `minFirst t` swaps the children of `t`'s nodes into that order; it keeps the
    leaves up to permutation and the `canon`, and two trees without repeated leaves with the same
    `canon` have the same `minFirst` (induction, by `canon_node_eq_iff`), so `minFirst` and
    `canon` are inverse between the canonical trees and the min-first trees over `Fin n`
    (`canonEquiv`). Then, for a list `z :: l` with `z` above every value of `l` and `l`
    nonempty, the min-first trees over `z :: l` are the pairs of a min-first tree over `l` and
    one of its `2 · |l| - 1` subtrees (`slots`), its `|l| - 1` nodes and `|l|` leaves numbered
    in preorder from `0` at the root: `insLeaf z k t` puts the node of the subtree at place `k`
    and `leaf z` in its place, and `cutLeaf z` removes `leaf z` with its parent node and records
    the place (`graftEquiv`). The new leaf goes on the right, as it is above every
    other, so a grafted tree is min-first, and the first leaf of every subtree is kept, so the
    tree left by a cut is min-first too. By induction on the list sorted down
    (`card_minFirstTree`), from the one tree over one value, with
    `Nat.doubleFactorial_add_two`, the count over `n` values is `(2n - 3)‼`; at `List.finRange n`
    reversed it is `card_canonTree`.
34. The stride `2 ^ k` comes first in `bflyOffsets (k + 1)`, so `H (k + 1)` is `H k` with each
    leaf `j` replaced by `halveStep (2 ^ k) j`, the node of `j` and `j + 2 ^ k` as `j < 2 ^ k`
    (statement 9). `halve_succ`: induction on `k`. Replacing the leaves of `H (k + 1)`, by
    induction the node of `H k` relabelled `2i` and `2i + 1`, with the nodes of `j` and
    `j + 2 ^ (k + 1)` is replacing the leaves `i` of `H k` with the nodes of `2i` and
    `2(i + 2 ^ k)`, and of `2i + 1` and `2(i + 2 ^ k) + 1`: the two halves of `H (k + 1)`
    relabelled. `canon_halve`: induction on `k` by `halve_succ`. Relabelling the leaves by a
    strictly increasing map keeps `treeCmp`, so it commutes with `canon`, and both children keep
    their `canon`; `treeCmp` of a tree relabelled `2i` and the same tree relabelled `2i + 1`
    reaches the first leaves first and returns `.lt`, so `canon` keeps the order.
35. `canon_bflyTree_xor`: induction on the offsets from the last one. After the rounds `ms`, then
    `m'`, lane `l`'s tree is the node of lane `l`'s and lane `l ^^^ m'`'s trees after `ms`. At
    `m = m'` the two lanes' trees are the same node with the children swapped
    (`canon_node_comm`); at `m ∈ ms` both children have the same `canon` as the other lane's, by
    induction at `l` and at `l ^^^ m'`, as `l ^^^ m ^^^ m' = l ^^^ m' ^^^ m`
    (`canon_node_eq_iff`). `canon_bflyTree_lane`: induction on `k`; a lane
    `2 ^ k ≤ l < 2 ^ (k + 1)` is `(l - 2 ^ k) ^^^ 2 ^ k`, as the bit `k` of `l - 2 ^ k` is clear.
36. By statement 35 at lane 0, induction on `k`. The offset `2 ^ k` comes first in
    `bflyOffsets (k + 1)`, so lane 0's tree is its tree after `bflyOffsets k` with each leaf `j`
    replaced by the node of `j` and `j ^^^ 2 ^ k`; grafting along two trees with the same `canon`
    gives trees with the same `canon` (induction, by `canon_node_eq_iff`), so the tree has the
    `canon` of `H k` with the same replacement, and there `j < 2 ^ k`, so
    `j ^^^ 2 ^ k = j + 2 ^ k` and the tree is `H (k + 1)` (statement 34's first step).
    `bflyTree_xor`: induction on the offsets from the last one; after the rounds `ms`, then `m`,
    lane `l`'s tree is the node of lane `l`'s and lane `l ^^^ m`'s trees after `ms`, by induction
    lane 0's relabelled `j ^^^ l` and `j ^^^ m ^^^ l`, the node of lane 0's and lane `m`'s
    relabelled `j ^^^ l`. Every leaf of lane 0's tree is the XOR of some of the offsets, so each
    of its bits is some offset's. `canon_bflyTree_perm`: lane 0's tree is canonical by induction
    on the offsets from the last one, which is some `2 ^ i` not among the others: the tree is the
    node of a canonical tree `T` and lane `2 ^ i`'s tree, which is `T` relabelled `j ^^^ 2 ^ i`;
    the bit `i` of every leaf of `T` is clear, so that is `j + 2 ^ i`, strictly increasing, so it
    commutes with `canon` and `treeCmp` returns `.lt` as in statement 34. The leaves of lane 0's
    tree are below `2 ^ k`, and at `j < 2 ^ k`, `j ^^^ l` is `j ^^^ (l % 2 ^ k)` plus
    `2 ^ k ⌊l / 2 ^ k⌋`; so lane `l`'s tree is lane `l % 2 ^ k`'s shifted, and its `canon` is lane
    0's (statement 35) shifted.
37. `eval_bflyTree` and `eval_roundsTree` make the sums the trees' evaluations, and statements 35
    and 36 give the trees the same `canon`; `eval_nanEq_of_canon` (statement 31) concludes.

## Not proved

- That a grid run of a kernel computes these trees. The corpus's layer norm kernels
  (tests/corpus/layernorm/) compute the mean and variance by Welford updates merged across lanes,
  not by two passes, so statements 12 and 13 are not their bound (Welford's merge is bounded in
  docs/proofs/float-welford.md); the corpus's reduction kernel sums `i32`
  (tests/corpus/reduction/reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.nvptx.ll,
  lines 151-160), so no float bound applies to it.
- A softmax entry with the compiled exponential: statement 20 bounds the sum, and statement 17's
  form with `ex2Rel` is not stated. Nor is the `-∞` operand (its `+0` is outside the contract) or
  an operand of `128` or more.
- RMS norm against TorchLean: TorchLean proves no closed form of `TorchLean.Tensor.rmsNorm`
  (TorchLean/Tensor/Layers/Normalization.lean) over the reals, so docs/proofs/float-norm.md states
  RMS norm against the real value its docstring gives. TorchLean's
  `TorchLean.Roundoff.rms_norm_forward_error`
  (TorchLean/Verify/RuntimeApprox/Roundoff/Operators.lean) bounds `TorchLean.Tensor.rmsNorm` on
  its configured tensors with left-fold reductions.
- Masked inputs in log-sum-exp and log-softmax (statements 21 and 22 keep every index), the
  maximum of a tree with `-∞` inputs (statement 14's inputs are finite; statement 25 takes any `m`
  whose real value is a kept input's) and a row whose every input is masked. Nor is the
  log-softmax entry in the order of Mojo's GPU softmax kernel, `log (e_j · (1 / s))`, stated, nor
  with Mojo's own `log`, which is not FloatLib's correctly rounded one.
- Any bound when a result is infinite or a NaN.
- The butterfly's canonical forms after offsets that are not `bflyOffsets k` in some order: an
  offset repeated (as in `dup_ne`, where lane 0's tree is not its own `canon`), one that is not a
  power of two, or more offsets than `k`. Statement 35 still gives every lane below `2 ^ k` lane
  0's form when `1, 2, …, 2 ^ (k - 1)` are among them; that form is not computed.

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
