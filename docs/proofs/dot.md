# The contracted dot-product fold (`dotLoop`)

Lean: MojoProof/Sem/Dot.lean. Instances and twins: MojoProofTest/Dot.lean,
MojoProofTest/DotGrade.lean and MojoProofTest/TileLanes.lean. The statements below are proved for every FloatLib format where they
say so, every list of factor pairs and every oracle sequence. What is not proved is said in
section "Scope". Section "The matmul and gemv cells against TorchLean" states the loop's results
against TorchLean's matrix products, section "The thread's loads and accumulator" the words a
thread's loads and float operations give against the loop, and section "The loop against
`dotGrade`" the loop's word against the spec layer's grade of a dot product, and section "Lanes
added along a tree" loops per lane whose words are added along a tree, as a warp's butterfly adds
them, against that grade's family `GPUProof.laneGrade`.

## What the loop computes

The naive matmul kernel of the corpus
(tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll)
accumulates one output entry in the loop

```
46:
  %48 = phi float [ 0.000000e+00, %45 ], [ %66, %52 ]
  ...
52:
  %60 = load float, ptr %59, align 4, !invariant.load !1
  %64 = load float, ptr %63, align 4, !invariant.load !1
  %65 = fmul contract float %60, %64
  %66 = fadd contract float %48, %65
  br label %46
67:
  %68 = phi float [ %48, %51 ]
  store float %68, ptr %40, align 4
```

In the semantics (MojoProof/Sem/Thread.lean, `exec`, and MojoProof/Sem/Op.lean, `floatBin`), a
scalar float operation at step `k` of a thread reads the oracle number `n = c.oracle (Nat.pair k 0)`
(`Ctx.scope`); the contraction choice is `n % 3` and the NaN choice `n / 3`.

* `%65 = fmul contract` of the words `a`, `b` gives `deliver (Model.mul a b) (n₁ / 3)` (when no
  `nnan` / `ninf` flag makes it poison) and records the factors `(a, b)` for register `%65`,
  because its flags include `contract`.
* `%66 = fadd contract` of `%48` and `%65` is `contract false acc p px py n₂` through `deliver` at
  `n₂ / 3`, with `acc` the word of `%48`, `p` the word of `%65`, `px` the factors of `%48` and `py`
  those of `%65`. `%48` is a `phi` result, and a `phi` records no factors, so `px = none` and
  `py = some (a, b)`. So `n₂ % 3 = 2` gives the fused `Model.fma a b acc` and every other oracle
  number the unfused `Model.add acc p` (`contract`'s case 1 needs factors of `%48`).
* `%48` starts at `0.000000e+00`, the word `+0` (`Model.zero fmt false`).

`dotStep c acc (a, b) (n₁, n₂)` is one iteration, with `c` the `contract` flag of both
instructions, and `dotLoop c o acc ps` the fold over the factor pairs `ps`, with oracle numbers
`o j = (n₁, n₂)` for the `fmul` and the `fadd` of iteration `j`. The connection point: the word of
`%48` at the loop's head after `j` iterations is `dotLoop c o (Model.zero fmt false)` of the first
`j` pairs, where pair `j` holds the two words the loads `%60` and `%64` gave in iteration `j`, and
`o j` the oracle numbers of that iteration's steps. `floatBin_dotStep` proves the one-iteration
part: the `fmul` followed by the `fadd`, as `floatBin` computes them on two words with the
recorded factors `exec` passes, is `dotStep`.

## Statements

Write `E = Σ aₖ bₖ` and `T = Σ |aₖ bₖ|` over the pairs `ps` (real values of the words, in list
order), `K` for the length of `ps`, `u = Model.unitRoundoffAt fmt`,
`η = Model.underflowErrorAt fmt`, and `C = (2 + u) η`.

1. Contraction off (`dotLoop_nanEq`, `dotLoop_eq_dotInOrder`). For every format, every list `ps`
   and every oracle sequence `o` such that `c = false` or no `fadd` oracle number is 2 modulo 3
   (`∀ j, c = true → (o j).2 % 3 ≠ 2`): `dotLoop c o (Model.zero fmt false) ps` and FloatLib's
   `Model.dotInOrder fmt fmt ps` are related by `NaNEq`, that is, the same word, or both NaNs.
   So the loop's word is FloatLib's bit for bit when FloatLib's is not a NaN, and is a NaN exactly
   when FloatLib's is. For NaNs nothing more holds: the payload and sign of the loop's NaN come
   from the oracle (`deliver`) and those of FloatLib's from its NaN propagation and the final
   `Model.cast`, which quiets a NaN; they may differ.
2. Contraction on, every oracle (`dotLoop_error`). For every IEEE format, every `c`, list `ps`
   and oracle sequence `o`, if `r = dotLoop c o (Model.zero fmt false) ps` is finite:

   `|r.toReal - E| ≤ ((1 + u) ^ (K + 1) - 1) * T + C * ((1 + u) ^ K - 1) / u`.

   Each iteration may be fused or not, whatever the others are. The exponent is `K + 1` because
   this bound does not use that the first iteration's addition to `+0` is exact; statement 12
   does, with exponent `K`, and this statement is proved from it. The second term is the
   underflow allowance: at most `C` per iteration, propagated.
3. One iteration (`floatBin_dotStep`). For every float type `t`, flags `fm` without `nnan`,
   `ninf`, `nsz`, `reassoc`, `arcp`, `afn`, words `acc`, `a`, `b` and oracle numbers `n₁`, `n₂`:
   `floatBin t .fmul fm` of `a`, `b` with no factors under `n₁`, followed by `floatBin t .fadd fm`
   of `acc` and its result with no factors for `acc` and the factors `(a, b)` for the product if
   `fm.contract`, under `n₂`, gives `.ok (.ofFloat t (dotStep fm.contract acc (a, b) (n₁, n₂)))`.
4. Never-fusing numbers (`dotLoop_neverFuse`). For every format, oracle sequence `o`, word `acc`
   and list `ps`: `dotLoop true` at the numbers `(3 * ((o j).1 / 3), 3 * ((o j).2 / 3))` is
   `dotLoop false o acc ps`, since at a number with remainder 0 `contract` adds and `deliver`
   reads `n / 3` (contract-off.md uses it for the naive kernel compiled with contraction off).

## Plan of the proofs

1. `Model.cast fmt fmt x` and `x` are `NaNEq` (`cast_self_nanEq`): FloatLib proves the cast of a
   finite word to its own format is the word (`Model.cast_self_of_finite`); for an infinity the
   cast is the overflow result of its sign, which is the infinity itself
   (`Model.eq_nativeOverflow_of_isInfinite`); a NaN is quieted, which keeps it a NaN
   (`Model.isNaN_quietNaN`). FloatLib has no lemma for the cast of a non-NaN word to its own
   format, so this file proves it.
2. `deliver r n` and `r` are `NaNEq` (`nanEq_deliver`); `NaNEq` is symmetric and transitive.
3. With `px = none` and `n % 3 ≠ 2`, `contract false x y px (some ab) n = Model.add x y`
   (`contract_unfused`).
4. Statement 1 by induction on `ps`, for every start pair related by `NaNEq`, with `NaNEq.op` for
   `Model.add` and `Model.mul` and items 1-3; the final cast is item 1.
5. Statement 2 by induction on `ps`, for every start word `acc`, real `E₀`, `S₀ ≥ |E₀|` and
   count `m` with `|acc - E₀| ≤ ((1 + u) ^ (m + 1) - 1) S₀ + C ((1 + u) ^ m - 1) / u`
   (`dotLoop_error_of`). A finite result has finite intermediate words
   (`isFinite_of_dotLoop`). One iteration is `contract_error` with `px = none`,
   `py = some (a, b)`: within `max (h(ab) + h(acc + p)) h(acc + ab)` of `acc + ab`, with
   `h = Model.halfUlpAt fmt`, `p` the rounded product, `|p - ab| ≤ h(ab)` and FloatLib's
   `Model.halfUlpAt_le` (`h x ≤ u |x| + η`). The unfused `c = false` step is the unfused case of
   `contract` (item 3 at oracle number 0).
6. Statement 3 by evaluating `floatBin` as `floatBin_ofFloat` does.
7. Statement 4 by induction on `ps`, one iteration by unfolding `dotStep` and `contract`.

FloatLib's `roundoff` command analyzes FloatLib's configured executable floats, not `Model`
operations chosen by an oracle, so the bound is proved by induction from `contract_error`.

## The matmul and gemv cells against TorchLean

Lean: MojoProof/Sem/Matmul.lean. Instances and twins: MojoProofTest/Matmul.lean.

TorchLean's `Tensor.matmul A B` (TorchLean/Tensor/Contract.lean) is `contract A B _ _ [m, p]
.matMul`, and its `Tensor.get2_matmul` reads entry `(i, j)` as
`(List.finRange n).foldl (fun sum k => sum + get2 A i k * get2 B k j) 0`. Its matrix-vector
product is `contract A v _ _ [m] .matVec`, whose entry `i` is, by `getScalar_contract_matVec`,
`(List.finRange n).foldl (fun sum k => sum + get2 A i k * v.getScalar k) 0`. Over FloatLib's
`Model fmt`, `+`, `*` and `0` are FloatLib's instances (FloatLib/Floats/Formats/BinaryInterchange/
Model/Instances.lean): `Model.add`, `Model.mul` and `posZero fmt`, and `Model.zero fmt false`, the
start word of the loop, is `posZero fmt` by unfolding (`Model.zero fmt false` is
`if false && fmt.supportsSignedZero then negZero fmt else posZero fmt`). So TorchLean's matmul
over `Model fmt` is the unfused fold of `Model.add` and `Model.mul`, with no casts of the factors,
and TorchLean's matmul over `ℝ` is the exact sum.

The cells. For matrices `A : Tensor (Model fmt) [m, n]`, `B : Tensor (Model fmt) [n, p]`, a
vector `v : Tensor (Model fmt) [n]` and indices `i`, `j`:

* `matmulPairs A B i j = List.ofFn fun k => (get2 A i k, get2 B k j)`, the factor pairs of entry
  `(i, j)` in increasing `k`;
* `matVecPairs A v i = List.ofFn fun k => (get2 A i k, v.getScalar k)`, those of entry `i` of the
  matrix-vector product.

TorchLean has no name for these lists. Write `A'`, `B'`, `v'` for `Tensor.map Model.toReal` of
`A`, `B`, `v` (TorchLean's pointwise map, TorchLean/Tensor/Rep/Pointwise.lean). For every format,
every `m`, `n`, `p`, all matrices, vectors and indices, every flag `c` and oracle sequence `o`:

4. Contraction off (`matmul_cell_nanEq`, `matmul_cell_eq`; `matVec_cell_nanEq`, `matVec_cell_eq`).
   If `c = false` or no `fadd` oracle number is 2 modulo 3, the loop's word
   `dotLoop c o (Model.zero fmt false) (matmulPairs A B i j)` and TorchLean's
   `get2 (Tensor.matmul A B) i j` are `NaNEq`; so the loop's word is TorchLean's when TorchLean's is
   not a NaN, and is a NaN exactly when TorchLean's is. The same for `matVecPairs A v i` and entry
   `i` of `contract A v _ _ [m] .matVec`.
5. The reals (`matmul_cell_real`, `matVec_cell_real`). The exact sum
   `((matmulPairs A B i j).map fun ab => ab.1.toReal * ab.2.toReal).sum` is
   `get2 (Tensor.matmul A' B') i j` over `ℝ`, and the one of `matVecPairs A v i` is entry `i` of
   `contract A' v' _ _ [m] .matVec`.
6. Contraction on, every oracle (`matmul_cell_error`, `matVec_cell_error`). In every IEEE format,
   if the loop's word `r` over `matmulPairs A B i j` is finite,
   `|r.toReal - get2 (Tensor.matmul A' B') i j| ≤ dotBound fmt n T` with
   `T = Σₖ |aᵢₖ bₖⱼ|`, the sum of the absolute products of the real values; the same for
   `matVecPairs A v i` against entry `i` of `contract A' v' _ _ [m] .matVec`.

Each family is proved once, for the pairs `List.ofFn f` of any `f : Fin n → Model fmt × Model fmt`,
and the matmul and gemv statements are its corollaries:

* statement 4 is `dotLoop_nanEq_ofFn`: the loop over `List.ofFn f` and the fold
  `(List.finRange n).foldl (fun s k => s + (f k).1 * (f k).2) 0` are `NaNEq`. It is the induction
  of statement 1 (`dotLoop_nanEq_foldl`), which is stated for every map `g` of the factors with
  `NaNEq x (g x)` for every word `x`: `g = Model.cast fmt fmt` gives FloatLib's `dotInOrder`
  (statement 1), `g = id` TorchLean's fold. The two halves come from `NaNEq.eq_isNaN`, as in
  `dotLoop_eq_dotInOrder`. TorchLean's `get2_matmul` and `getScalar_contract_matVec` turn the
  entries into that fold.
* statement 5 is `dotSum_ofFn`: the exact sum over `List.ofFn f` is the fold over `List.finRange n`
  of `+` in `ℝ` from 0; `Tensor.unstack_map` and `Tensor.getScalar_map` read the entries of the
  mapped tensors.
* statement 6 is statement 2 (`dotLoop_error`) with statement 5 for the exact sum and
  `List.length_ofFn` for the length.

Scope of statements 4-6. They are the float and the real half of the kernel's correctness, for
every format and size. Section "The thread's loads and accumulator" connects them to the words a
thread's loads and float operations give; section "Scope" says where the loop that `exec` runs is
connected to them (for the one program `naive`).
The corpus has no gemv kernel; the gemv statements are about the fold only, and a gemv loop with
the same body would meet them at the same point, with `matVecPairs A v i` for the pairs.

## The thread's loads and accumulator

Lean: MojoProof/Sem/Matmul.lean (second part). Instances and twins: MojoProofTest/Matmul.lean and
MojoProofTest/NaiveRun.lean.

The naive kernel reads its operands at row `%24 = ctaid.x * ntid.x + tid.x` and column
`%35 = ctaid.y * ntid.y + tid.y`: `%60` loads element `row * 768 + k` of the buffer of `%1` (A)
and `%64` element `col * 768 + k` of the buffer of `%2` (B), both 4-byte floats, and `%40` points
at element `row * 50257 + col` of the buffer of `%0` (C). So B is read transposed: with A an
`m × 768` and B a `p × 768` matrix in row-major order, thread `(row, col)` computes entry
`(row, col)` of `A Bᵀ`, the pairs `(A[row, k], B[col, k])`. In TorchLean the transpose of
`B : Tensor α [p, n]` is `Tensor.permute B (Shape.adjacentSwap [p, n] 0) [n, p]`, written `Bᵀ`
below.

For every layout `l`, element type `t` with codec `enc`, element type `α` of the tensors, float
type `t'` and flags `fm`:

7. Row-major reads (`rowMajor_two`, `Mem.load_get2`). Element `(r, k)` of an `M × S` tensor laid
   out row-major from offset `o` (`rowMajor`) is at `o + (r * S + k) * l.size t`. If block `c` of
   memory `m` is live, admits the thread and holds `A : Tensor α [M, S]` row-major from `o`
   (`Block.Holds`, the form `Mem.Holds`, `Mem.tensor` and the preconditions use), then for every
   `r < M`, `k < S`, address space `a` and alignment `al` the address meets, the load of type `t`
   at offset `o + (r * S + k) * l.size t` of block `c` gives `enc (get2 A r k)`. With
   `t = .fp .float`, `enc = Val.ofFloat .float` (`Layout.Codec.float`), `o = 0`, `S = 768`, this is
   the reading of `%60` (`r = row`) and of `%64` (B, `r = col`).
8. The transpose (`get2_swap`, `matmulPairs_swap`). For every `α` with TorchLean's `Storage`,
   `get2 Bᵀ k j = get2 B j k`; so `matmulPairs A Bᵀ i j` is the list of `(get2 A i k, get2 B j k)`
   in increasing `k`. TorchLean proves the transpose rule over `ℝ` only (`get2_transpose`,
   TorchLean/Tensor/LinearAlgebra/Real.lean); `get2_swap` is the same rule for every `α`, from
   TorchLean's `permute_adjacentSwap_zero_apply`.
9. The accumulator (`dotLoop_of_floatBin`). For every float type `t'`, flags `fm` without `nnan`,
   `ninf`, `nsz`, `reassoc`, `arcp`, `afn`, count `K`, pairs `f : Fin K → Model t'.fmt ×
   Model t'.fmt`, start word `a₀`, oracle sequence `o`, and values `acc`, `prod` indexed by `Nat`
   with `acc 0 = .ofFloat t' a₀`: if for each `k < K`

   * `floatBin t' .fmul fm` of the words of pair `k`, with no factors for either operand, under
     the oracle number `(o k).1`, is `.ok (prod k)`, and
   * `floatBin t' .fadd fm` of `acc k` with no factors and `prod k` with the factors of pair `k`
     when `fm.contract` (none otherwise), under `(o k).2`, is `.ok (acc (k + 1))`,

   then `acc K = .ofFloat t' (dotLoop fm.contract o a₀ (List.ofFn f))`.
10. The cell (`cell_of_floatBin`). Statement 9 with `f k = (get2 A i k, get2 B j k)` for
    `A : Tensor (Model t'.fmt) [m, n]`, `B : Tensor (Model t'.fmt) [p, n]` and `a₀ = +0`: then
    `acc n = .ofFloat t' (dotLoop fm.contract o (Model.zero t'.fmt false) (matmulPairs A Bᵀ i j))`,
    and statements 4-6 give the word against `get2 (Tensor.matmul A Bᵀ) i j` (TorchLean's over
    `Model`, up to NaNs when no `fadd` oracle number is 2 modulo 3) and against TorchLean's real
    matmul (within `dotBound`, under every oracle). When the loop runs `K` iterations over
    matrices of `S > K` columns, statement 9 applies with `f k = (get2 A i k, get2 B j k)` for
    `k < K`, the cell of the first `K` columns (statement 11).
11. The first `K` columns (`cols`, `get2_cols`; `cols_pairs`, `matmul_cols_nanEq`,
    `matmul_cols_eq`, `matmul_cols_error` at two strides; `take_pairs`, `matmul_take_eq`,
    `matmul_take_error` at one). For every `α` with TorchLean's `Storage`, all
    sizes with `K ≤ s` and `A : Tensor α [m, s]`, `cols K h A : Tensor α [m, K]` is TorchLean's
    `Tensor.slice` of `A` along axis 1 from `0` to `K` with step `1`, cast to `[m, K]`, and
    `get2 (cols K h A) r k = get2 A r k` (`get2_cols`, with `k` cast from `Fin K` to `Fin s` by
    `Fin.castLE h`).

    Two strides. In every format, for all sizes `m`, `p`, `K`, every pair of row strides `sA`,
    `sB` with `K ≤ sA` and `K ≤ sB` (equal or not), `A : Tensor (Model fmt) [m, sA]`,
    `B : Tensor (Model fmt) [p, sB]` and indices `i`, `j`: the `K` pairs
    `(get2 A i k, get2 B j k)`, `k < K` (with `k` cast to `Fin sA` and to `Fin sB`), are
    `matmulPairs (cols K hA A) (cols K hB B)ᵀ i j` (`cols_pairs`). So statements 4-6 hold for the
    loop over them against entry `(i, j)` of `Tensor.matmul (cols K hA A) (cols K hB B)ᵀ`, with
    the same premises (no `fadd` oracle number 2 modulo 3 for the word, an IEEE format and a
    finite word for the bound) and the bound with `K` terms: `matmul_cols_nanEq`,
    `matmul_cols_eq`, `matmul_cols_error`. These are the forms for the preconditions' matrices
    (`Mat.Pre`), whose A and B rows have strides `sA` and `sB` with `K ≤ sA` and `K ≤ sB`.

    One stride. At `sA = sB = s` (with `hA = hB = h`) the `K` pairs are the first `K` of the `s`
    pairs `(get2 A i k, get2 B j k)`, `k < s`, and the one-stride forms state the lemmas over
    `(List.ofFn …).take K`, the list the naive kernel's proof builds: `take_pairs`,
    `matmul_take_eq`, `matmul_take_error`. Their statements are unchanged, and each is one line
    from its two-stride form. The naive kernel's cells are read with the two-stride forms
    (`matmul_cols_nanEq`, `matmul_cols_error`), at every pair of row strides.

The premises of statement 9 are the facts a run of the loop gives. Each is one statement of the
thread, and in `exec`'s `.fbin` case the operands' recorded factors are `laneOf (prodOf a) 0`
(`Frame.prods` of the register, lane 0 of a scalar):

* The `fmul` `%65`: its operands `%60` and `%64` are loads, and a load records no factors (`next`
  records `none`), so both factor arguments are `none`. It records `(x, y)`, the words of `%60`
  and `%64`, for `%65`, because its flags include `contract`.
* The `fadd` `%66`: `%48` is a `phi` result, set by `enter` with `Frame.set _ (some v) none`, and
  no statement of `%52` sets it again, so its factor argument is `none` (`px = none`); the one of
  `%65` is `some (x, y)` (`py`). A proof that goes through the block checker must keep these two
  facts in its frame: `prods` of the accumulator's `phi` is `none` at the loop's head, and the
  `fadd`'s second operand records the loads' words.
* The oracle numbers. Thread `n` of a launch with oracle `oracle` runs with the oracle `oracle n`
  (`Grid.start_ctx`), and a scalar float operation at the thread's step count `k` (the `k` of
  `Thread` before the step) reads `oracle n (Nat.pair k 0)` (`Ctx.scope`). Every non-`phi`
  statement and every terminator is one step; the `phi`s of a block are set by the branch into it.
  A thread of the naive kernel that passes the bounds test runs the 37 statements of the entry
  block at steps 0-36, its branch at 37 and `%45`'s at 38; iteration `j` then runs `%49` and the
  branch of `%46` at steps `39 + 18 j` and `40 + 18 j`, the branch of `%50` at `41 + 18 j`, the 14
  statements of `%52` at `42 + 18 j` to `55 + 18 j` and its branch at `56 + 18 j`. So `%65` runs
  at step `54 + 18 j` and `%66` at `55 + 18 j`, and the oracle sequence of thread `n` is
  `o j = (oracle n (Nat.pair (54 + 18 j) 0), oracle n (Nat.pair (55 + 18 j) 0))`.
  This count is proved for every thread of `naive` by `NaiveThread.steps` (the path into the
  loop adds 39 steps, a round 18, and the latch is entered 3 steps after the head), which gives
  `NaiveThread.oN` and `NaiveSpec.o`, the numbers in `NaiveSpec.bytes`. It was first checked on
  one launch, and the check stays as a test: MojoProofTest/NaiveRun.lean runs the grid
  evaluator on one block of 2 × 2 threads (`K = 3`) under, for each `j < 3`, the oracle that
  gives 2 (fuse with the product operand) at step `55 + 18 j` of every thread, and compares each
  of the four cells with `dotLoop` under the numbers that fuse exactly iteration `j`. The data
  make fusing iteration 1 visible in one cell and iteration 2 in another; fusing iteration 0
  changes no word (the accumulator is `+0`), so `55` itself is checked only through the stride.
  The twin gives 2 at step `56 + 18` and gets the unfused cells. The `fmul`'s number
  `54 + 18 j` is not checked (it only chooses a NaN's payload).

Plan of the proofs. Statement 7 rewrites `rowMajor` with TorchLean's `linearize_cons_val` and
`val_linearize_vector`, then applies `Mem.load_holds`; `get2_eq_apply` turns the coordinate into
`get2`. Statement 8 is `get2_eq_apply` and `permute_adjacentSwap_zero_apply`. Statement 9 is an
induction on `j ≤ K` for the first `j` pairs: `List.ofFn_succ_last` splits off the last pair,
`dotLoop` of a list with one more pair at the end is one more `dotStep` (an induction on the
list, inside the proof), and `floatBin_dotStep` with the premise for `prod j` and the induction
hypothesis for `acc j` gives `acc (j + 1)`. Statement 10 is statement 9 after statement 8.
Statement 11: `get2_cols` unfolds TorchLean's `slice_apply` and `castShape_apply_reindex` and
compares the two coordinates axis by axis (`Shape.Coord.ext_val`, `index_reindexEq`).
`cols_pairs` rewrites its right side with statement 8 and its pairs with `get2_cols`, after which
both sides are `List.ofFn` of the same function;
`matmul_cols_nanEq` and `matmul_cols_error` rewrite their pairs with `cols_pairs` and apply
`matmul_cell_nanEq` and `matmul_cell_error` at `cols K hA A` and `(cols K hB B)ᵀ`, and
`matmul_cols_eq` is the two halves of `matmul_cols_nanEq`. The one-stride forms rewrite
`(List.ofFn v).take K` as `List.ofFn (Fin.take K h v)` (Mathlib's
`Fin.ofFn_take_eq_take_ofFn`), and `Fin.take K h v k` is `v (Fin.castLE h k)` by definition, so
each is its two-stride form at `hA = hB = h`. No library lemma states the pairs of two sliced
rows: TorchLean has no lemma on `slice` and `matmul` together, and Mathlib's `Fin.take` lemmas
are about one tuple.

Instances (MojoProofTest/Matmul.lean): a 2 × 3 matrix `tA` and a 2 × 3 matrix `tB` of small
binary32 integers. Statement 7 at a memory made by `Mem.alloc` of `tB`'s bytes; statements 9 and
10 at every cell, with `acc` and `prod` the words `floatBin` gives, and the cells are those of
TorchLean's `Tensor.matmul tA tBᵀ`. The twin: reading B's six words untransposed, as a 3 × 2
matrix (element `k * 2 + j` for `(k, j)`), gives pairs whose loop is not TorchLean's entry of
`tA tBᵀ`. Statement 11 (`take_inst`): the loop over the first 2 of the 3 pairs of row 0 of `tA`
and of `tB` gives 1, entry `(0, 0)` of the product of the first 2 columns of `tA` and the
transpose of the first 2 columns of `tB`; its twin is the full entry, -2. The two-stride forms
(`cols_inst`): with `tA` (`2 × 3`, stride 3) and the `2 × 2` matrix `mB` (stride 2), the loop
over the 2 pairs of row 0 of each gives 3, entry `(0, 0)` of the product of the first 2 columns
of `tA` and the transpose of `mB`'s 2 columns (`matmul_cols_eq` at `sA = 3`, `sB = 2`). Its
premise on the oracle has the twin `matmul_cell_twin`.

## The loop against `dotGrade`

Lean: MojoProof/Sem/Dot.lean (last part). Instances and the mutant: MojoProofTest/DotGrade.lean.
With the notation of section "Statements" and `M = (Model.posMaxFinite fmt).toReal`, the largest
finite value:

12. The bound from `+0` (`dotLoop_error_zero`). For every IEEE format, every `c`, list `ps` and
    oracle sequence `o`, if `r = dotLoop c o (Model.zero fmt false) ps` is finite:

    `|r.toReal - E| ≤ dotLoopBound fmt K T = ((1 + u) ^ K - 1) * T + C * ((1 + u) ^ K - 1) / u`.

    The first iteration adds to `+0`, which is exact (unfused, FloatLib's
    `Model.toReal_add_of_isZero_left`; fused, `Model.fma a b (+0)` is one rounding of `a b`), so
    the first iteration is within `u |a b| + η` of `a b` (`dotStep_zero_bound`, at most
    `dotLoopBound fmt 1 |a b|`). A later iteration is `dotStep_loopBound`, which applies the real
    inequality `dotBound_step` through `dotStep_bound_of`. Its terms: `x` is the accumulator,
    within `e` of the exact partial sum `E'`, with `|E'| ≤ S` and `S` the sum of the absolute
    products so far, so `|x| ≤ S + e`; `P = a b` is the exact product and `y` its rounded word;
    `r` is the iteration's result. Each operation is rounded:

    * the product (`h₁`): `|y - P| ≤ u |P| + η`, so `|y| ≤ (1 + u) |P| + η`;
    * unfused, the sum `x + y` (`h₂`): `|r - (x + y)| ≤ u |x + y| + η`, with
      `|x + y| ≤ S + e + (1 + u) |P| + η`;
    * fused, the one rounding of `x + P` (`h₃`): `|r - (x + P)| ≤ u |x + P| + η`, at most the
      unfused `h₁ + h₂`.

    So `|r - (E' + P)| ≤ |x - E'| + |r - (x + P)| ≤ e + h₁ + h₂`, at most

    `(1 + u) e + u S + (2 u + u ^ 2) |P| + C`.

    The accumulated error `e` is carried and rounded again with the sum (`(1 + u) e`), the
    accumulated sum is rounded again (`u S`), the product's rounding gives `u |P|` and the sum's
    rounding of the rounded product `u (1 + u) |P|`, and each of the two roundings may add `η`,
    with `u η` from the sum's rounding of the product's `η` (`C = (2 + u) η`). At
    `e = dotLoopBound fmt (m + 1) S` this is at most `dotLoopBound fmt (m + 2) (S + |P|)`, since
    `(1 + u) ((1 + u) ^ (m + 1) - 1) + u = (1 + u) ^ (m + 2) - 1`,
    `2 u + u ^ 2 = (1 + u) ^ 2 - 1 ≤ (1 + u) ^ (m + 2) - 1` and
    `(1 + u) C ((1 + u) ^ (m + 1) - 1) / u + C = C ((1 + u) ^ (m + 2) - 1) / u`.

    So the exponent `K` is not a count of roundings: unfused, the loop rounds `K` products and
    `K - 1` sums. Each later rounding multiplies an error made before it by at most `1 + u`, and
    the exponent counts how far an error propagates: product 1 passes through its own rounding
    and the `K - 1` later sums, product `j > 1` through its own and the sums `j` to `K`, that is
    `K - j + 2 ≤ K`. In binary32 the products `1`, `2 ^ -24`, `2 ^ -24` from `+0` round back to
    `1` twice, since each `1 + 2 ^ -24` is a tie that rounds to the even `1`, an error of
    `2 ^ -23` against `dotLoopBound` of about `3 · 2 ^ -24` (`sum_rounded`, `sum_within`); a
    recurrence without the rounding of the accumulated sum (`u S`) gives about `2 ^ -24` there,
    which is not a bound (`noSum_fails`). Both inductions are one, `dotLoop_error_step`, over a
    bound family and its step. For `T ≥ 0`, `dotLoopBound fmt K T ≤ dotBound fmt K T`
    (`dotLoopBound_le_dotBound`), which gives statement 2; the matmul statements keep `dotBound`.
13. Finiteness (`isFinite_dotLoop`). For every IEEE format, `c`, oracle sequence and list `ps` of
    finite words, if `T + dotLoopBound fmt K T ≤ M`, the loop's word from `+0` is finite. The
    induction (`isFinite_dotLoop_of`) carries statement 12's bound; in one iteration
    (`dotStep_finite`) the exact product, the exact sum and the rounded sum are at most
    `S + |a b| + dotLoopBound fmt (m + 1) (S + |a b|) ≤ M` in absolute value, with `S` the sum of
    the absolute products so far, so FloatLib's `Model.isFinite_mul_of_abs_mul_le_posMaxFinite`,
    `Model.isFinite_add_of_abs_toReal_add_le_posMaxFinite` and
    `Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite` give finite words.
14. The grade (`dotGrade_ieee`, `dotLoop_error_graded`, `dotLoop_approx`). By definition
    (`dotGrade_ieee`: `GPUProof.laneGrade` at one lane of `n` terms and depth `0`, unfolded by
    `simp`), `GPUProof.dotGrade (.ieee fmt) n a x ga gx` has error
    `dotLoopBound fmt n S + P` and magnitude the larger of `S + (dotLoopBound fmt n S + P)` and
    `⨆ₖ max (ga k).mag (gx k).mag`, with `S = Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)`,
    `P = Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)` and `e = GPUProof.Grade.pos`: its
    `γₙ = (1 + u) ^ n - 1` is statement 12's, and its magnitude is at least each input grade's
    (`GPUProof.laneGrade_mag`, at one lane). The second term is needed: `GPUProof.Approx` at a grade whose
    magnitude is above `M` allows any word, a NaN included, and a NaN input makes the loop's word
    a NaN, so a grade of magnitude `S + e ≤ M` over such an input is met by no loop that
    propagates NaNs. For every IEEE format, `c`, oracle sequence, length `n`, exact
    entries `a`, `x`, grades `ga`, `gx` and words `w`, `v` with each `w k`, `v k`
    `GPUProof.Approx` at `ga k`, `gx k` of `a k`, `x k`, the loop's word over the pairs
    `List.ofFn fun k => (w k, v k)` is
    `GPUProof.Approx .real (dotGrade (.ieee fmt) n a x ga gx) (.ieee fmt)` of `Σₖ aₖ xₖ`
    (`dotLoop_approx`): when the grade's magnitude is at most `M`, so is each input grade's, so
    each word is finite and within its grade's error; then the loop's word is finite (statement
    13, since `Σₖ |wₖ vₖ| ≤ S`, `sum_abs_mul_le_graded`) and within the grade's error of
    `Σₖ aₖ xₖ` (`dotLoop_error_graded`: statement 12 at the words, `dotLoopBound` grows with `T`
    (`dotLoopBound_mono`), and `|Σₖ wₖ vₖ - Σₖ aₖ xₖ| ≤ P` term by term, `sum_mul_sub_le`).
    Both are proved once, for lanes: `dotLoop_error_graded` and `dotLoop_approx` are
    `treeDot_error` and `treeDot_approx` (statement 16) at one lane, the tree `.leaf 0` and the
    list `List.ofFn fun k => (w k, v k)`, one term each.

The bound of statement 2 has `(1 + u) ^ (n + 1) - 1` on the sum where `dotGrade` has
`(1 + u) ^ n - 1`, so it does not give statement 14; statement 12 closes that gap at
`dotGrade`'s error. `dotBound_le_dotGrade` (statement 2's bound after `K` iterations against
`dotGrade` at length `K + 1` with exact inputs) is the earlier comparison.

Instances (MojoProofTest/DotGrade.lean). `grade_one` and `grade_two` give `dotGrade`'s error at
lengths 1 and 2 with exact inputs, for every format: `u |a| |x| + (2 + u) η` and
`(2 u + u ^ 2) (|a₀| |x₀| + |a₁| |x₁|) + (2 + u) ^ 2 η`. `approx_one` is statement 14 on binary32
at length 1, on the subnormal `3 · 2 ^ -149` and `1 / 2` with exact grades; `approx_two` at length
2, on the words of `11184811 / 2 ^ 25` (nearest to `1 / 3`) and `1` against `3` and `-1`, of the
exact `1 / 3`, `1`, `3`, `-1`, with the error `2 ^ -25` on the first entry (`third_near`); both
for every flag and oracle sequence. Their premises are the words' finiteness and errors, through
`GPUProof.Approx.model`. `sum_rounded` and `sum_within` are statement 12's example above, on
binary32 from `+0`, unfused: the loop over the products `1`, `2 ^ -24`, `2 ^ -24` gives `1`, an
error of `2 ^ -23` within `dotLoopBound .binary32 3`; `noSum_fails` is the recurrence without the
rounding of the accumulated sum, below `2 ^ -23` there.

The mutant (`mutant_one`): the grade one unit in the last place tighter fails. On the pair of
`approx_one`, unfused, the exact product `1.5 · 2 ^ -149` is a tie between the subnormals
`2 ^ -149` and `2 · 2 ^ -149` and rounds to the even `2 · 2 ^ -149` (computed by the kernel), an
error of `η = 2 ^ -150` (`sub_err`). The grade with `dotGrade`'s magnitude and its error less
`2 ^ -149`, the spacing of the subnormals and so one unit in the last place of the result, has
error `4 u η < η`, and `GPUProof.Approx` at it is false. So the allowance `(2 + u) η` cannot lose
`2 ^ -149` at length 1.

## Lanes added along a tree

Lean: MojoProof/Sem/Dot.lean (`sum_mul_sub_le` to `treeDot_approx`), GPUProof/Spec/Linear.lean
(`GPUProof.laneGrade`), MojoProof/Float/Tree.lean (`MojoProof.Float.sum_error`,
`MojoProof.Float.isFinite_eval`) and MojoProof/Tile/MatVec.lean (section "Dot products over
lanes"). Instances and the mutant: MojoProofTest/TileLanes.lean.

The gemv kernel's warp splits a row's pairs over its lanes: lane `j` runs the loop over the pairs
`k ≡ j` modulo the lane count (`stride`, MojoProof/Sem/WarpDot.lean), and the butterfly's rounds
add the lanes' words (`groupDot`, `warpDot`). The plan:

* The word: `treeDot t c o ls` is lane `j`'s word `dotLoop c (o j)` from `+0` over its list
  `ls j`, the words added by FloatLib's `Model.add` along a tree `t` of lane numbers, FloatLib's
  `Numerics.ReductionTree` and its `eval` (FloatLib/Numerics/Reduction/Tree.lean). FloatLib's
  `Model.ReductionTree.abs_toReal_eval_sub_sum_le_depth` bounds such a sum, when every
  intermediate is finite, by `((1 + u) ^ depth - 1)` times the sum of the leaves' absolute
  values.
* The grade, one family: `GPUProof.laneGrade fmt W d L n a x ga gx`, of a dot product of length
  `n` over `W` lanes of at most `L` pairs each whose words are added along a tree of depth `d`.
  With `S` and `P` as in statement 14, its error is
  `((1 + u) ^ (L + d) - 1) S + W (1 + u) ^ d C ((1 + u) ^ L - 1) / u + P`, `C = (2 + u) η`, and
  its magnitude the larger of `S` plus the error and every input grade's magnitude
  (`GPUProof.laneGrade_mag`). It grows with the input grades (`GPUProof.laneGrade_mono`), so
  `GPUProof.laneVecGrade W d L` (`L n` pairs per lane at length `n`) is a grade of
  `GPUProof.Spec.matVec` (`GPUProof.laneVecGrade_mono`). `GPUProof.dotGrade fmt n` is
  `laneGrade fmt 1 0 n n` and `GPUProof.matVecGrade` is `laneVecGrade 1 0 id`, both by
  definition; there is no second grade and no equivalence between two.
* The theorem (statement 16) for every IEEE format, flag, oracle sequences, lane count `W`, lane
  length `L`, length `n`, tree whose leaves are the lanes `0, …, W - 1`, each once, lists that
  together are the pairs, and input grades.
* The butterfly's lanes. After the rounds at the offsets `bflyOffsets k`, lane `l`'s word is the
  lanes' loops added along its own tree `bflyTree (bflyOffsets k) l` (`eval_bflyTree`), whose
  leaves are all `2 ^ k` lanes, each once (`leaves_offsets`), and whose depth is `k`
  (`depth_bflyTree`). The order differs by lane: at `k = 2` lane 0 adds `(0 + 2) + (1 + 3)` and
  lane 3 adds `(3 + 1) + (2 + 0)` (`bfly_trees`). Statement 16 holds for every tree over the
  lanes, so each lane is a case of it. No commutativity lemma enters: the tree's bound is against
  the sum over its leaves, and a permutation of the leaves keeps that sum (`List.Perm.sum_eq`,
  in `MojoProof.Float.sum_error`).

FloatLib's Reduction/Schedule/ bounds a reduction along a tree with every intermediate finite
(`ReductionTree.FiniteEval`) and a final conversion; Reduction/Dot/ is the dot product with an
exact accumulator, rounded once. Neither derives finiteness from a bound on the terms, which
`GPUProof.Approx`'s premise gives, so MojoProof/Float/Tree.lean proves it
(`MojoProof.Float.isFinite_eval`).

15. Loops per lane (`lanes_error`). For every IEEE format, flag `c`, oracle sequences `o j`,
    counts `W`, `L` and lists `ls j` of at most `L` pairs for `j < W` whose loops from `+0` are
    finite, `Σⱼ` of the lanes' words is within `((1 + u) ^ L - 1) T + W C ((1 + u) ^ L - 1) / u`
    of the exact `Σⱼ Σ_{(a, b) ∈ ls j} a b`, and `Σⱼ` of their absolute values is at most
    `(1 + u) ^ L T + W C ((1 + u) ^ L - 1) / u`, with `T` the sum of the absolute products:
    statement 12 per lane, with `dotLoopBound_mono` from the lane's length to `L`.
16. The lanes against the grade (`treeDot_error`, `treeDot_approx`). For the quantifiers above,
    with `hs` saying that every sum over the lanes' pairs is the sum over the pairs
    `(w k, v k)`, `k < n`, and each `w k`, `v k` `GPUProof.Approx` at `ga k`, `gx k` of `a k`,
    `x k`: `treeDot t c o ls` is `GPUProof.Approx` at `laneGrade (.ieee fmt) W t.depth L n` of
    `Σₖ aₖ xₖ`. When the grade's magnitude is at most `M`, each input word is finite and within
    its grade's error (`GPUProof.laneGrade_mag`); every pair in a lane is then finite (`hs` at the
    count of pairs with a word that is not finite); each lane's loop is finite (statement 13); the
    tree's sum is finite (`MojoProof.Float.isFinite_eval`, since
    `(1 + u) ^ d ((1 + u) ^ L T + W C ((1 + u) ^ L - 1) / u) ≤ S +` the error); and it is within
    the error (`treeDot_error`: `MojoProof.Float.sum_error` for the tree, statement 15 for the
    lanes, `sum_abs_mul_le_graded` and `sum_mul_sub_le` for the inputs, and
    `(1 + u) ^ (L + d) = (1 + u) ^ L (1 + u) ^ d`).

Its cases (MojoProof/Tile/MatVec.lean): `MojoProof.Tile.stride_approx`, the lanes' lists
`stride W j` of the pairs, at `L = ⌈n / W⌉` (`length_stride_le`, `sum_stride`), along every tree
over the lanes; `MojoProof.Tile.bfly_approx`, every lane `l < 2 ^ k` of the butterfly, at
`W = 2 ^ k` and depth `k`; `MojoProof.Tile.groupDot_approx`, lane 0, that is `groupDot k` and so
`warpDot` at `k = 5`; `MojoProof.Tile.rowTrees_meetsAt`, the behaviors `rowTrees` (the strided
lanes along a tree per row, at some oracle sequences) meeting
`GPUProof.Spec.matVec (GPUProof.laneVecGrade W t.depth fun n => ⌈n / W⌉)` at `matVecEnc`
(`GPUProof.MeetsAt`) through `stride_approx` and `MojoProof.Tile.holds_of`, which takes `W`, `d`
and `L` (at `1`, `0`, `id` it is the rule of `GPUProof.Spec.matVec GPUProof.matVecGrade`); and
`MojoProof.Tile.groupDot_holds`, `groupDot k` per row meeting the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`, its case at lane
0's butterfly tree. WarpDot's `groupDot_error` bounds the same word by
the same error, with the exponent `⌈n / 2 ^ k⌉ + k` on the sum: it is `treeDot_error` at the
butterfly's tree and the grades `⟨0, 0⟩` (warp-dot.md, statement 6).

Instances (MojoProofTest/TileLanes.lean), on the binary32 words `1`, `2`, `-1` cyclically
(`row`), with no input error, for every flag and oracle sequence: `stride_3x7`, 3 lanes, length 7,
the tree `(0 + 1) + 2` of depth 2; `group_4x10` and `lane3_4x10`, `groupDot 2` and lane 3 of the
butterfly at 4 lanes and length 10; their words unfused at the oracle 0 are `0` and `-4`, computed
by the kernel (`value_3x7`, `value_4x10`); `rows_2x7` and `rows_3x10`, `rowTrees_meetsAt` at the
tree `(0 + 1) + 2` at size 2 × 7 and at lane 0's butterfly tree (`groupDot 2` per row) at size
3 × 10.

The mutant (`depth_mutant`): the depth term is needed. On the binary32 pairs whose exact products
are `1 / 2`, `2 ^ -26`, `2 ^ -25`, `2 ^ -26`, one per lane, `groupDot 2` unfused gives `1 / 2`:
lane 0 adds `1 / 2 + 2 ^ -25`, a tie that rounds to the even `1 / 2`, and `2 ^ -26 + 2 ^ -26`
exactly, then `1 / 2 + 2 ^ -25` again (`depth_vals`). Its error `2 ^ -24` is within the grade at
depth 2 (`depth_holds`) and above the error `u S + 4 C` of the grade at depth 0, with
`S = 1 / 2 + 2 ^ -24`, so `GPUProof.Approx` at that grade is false.

## Scope

* Statements 1-14 stand alone: none names a program or runs `exec`. For the one program `naive`
  (MojoProofTest/SymPhi.lean), the loop that `exec` runs is connected to the fold in
  MojoProofTest, at every launch and memory of `Mat.Pre`: `NaiveThread.thread_run` runs the loop
  round by round (`Round.of_inv`, with the induction variable `%47` and the exit test `%49`), each
  round's accumulator by `floatBin_dotStep`; `NaiveThread.steps` proves the oracle positions;
  the recorded factors are carried through the rounds in MojoProofTest/NaiveIn.lean;
  `NaiveIn.runIn` is the run of every thread in bounds; and `NaiveSound.naive_matmul` reads the
  cells of `NaiveKernel.correct` with statement 11 (docs/proofs/naive.md, docs/proofs/kernel.md).
  That proof applies statement 3 once per round; statements 7, 9 and 10 are not used by it and
  are tested on concrete words (MojoProofTest/Matmul.lean). No other program is connected.
* Statement 11's two-stride forms hold in every format (the bound in every IEEE format), for
  every size and every pair of row strides `sA`, `sB` with `K ≤ sA` and `K ≤ sB`.
  `NaiveSound.naive_matmul` uses the one-stride forms at `s = 768`, the naive kernel's stride for
  both A and B; no program whose two strides differ is connected to them.
* Statement 1 relates the loop to FloatLib's `dotInOrder` with source, accumulator and output
  formats all equal to `fmt`, the only case a loop in one format computes.
* Statement 2 is a forward bound against the exact sum of the decoded words' products. It does
  not say which choices the oracle makes, and assumes the result is finite; overflow of an
  intermediate makes the result infinite or a NaN, and then nothing is claimed.
* Statement 14 holds for every IEEE format, flag, oracle sequence, length and input grade. Its
  premises (the words `GPUProof.Approx` at their grades of the exact entries) are the caller's.
  The tile layer's `MojoProof.Tile.Meets` carries it as its graded clause, so every kernel of
  `mojo_kernel`'s `mat` clause has it at each cell (`MojoProof.Tile.mat_refines`,
  docs/proofs/spec.md); the naive kernel's cells are read with statement 11's `dotBound` forms.
* Statements 15 and 16 hold for every IEEE format, flag, oracle sequence, lane count, lane
  length, length, tree over the lanes and input grade. They are about the words `treeDot`,
  `groupDot` and the butterfly's lanes, not about a program: that the gemv kernel stores
  `warpDot` of its row's pairs is a plan (docs/proofs/gemv.md, item 7), so no kernel is shown to
  meet `GPUProof.laneVecGrade`.
