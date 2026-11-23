# The contracted dot-product fold (`dotLoop`)

Lean: MojoProof/Sem/Dot.lean. Instances and twins: MojoProofTest/Dot.lean. The statements below
are proved for every FloatLib format where they say so, every list of factor pairs and every
oracle sequence. What is not proved is said in section "Scope". Section "The matmul and gemv
cells against TorchLean" states the loop's results against TorchLean's matrix products, and
section "The thread's loads and accumulator" the words a thread's loads and float operations give
against the loop.

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
   the first iteration adds its product to `+0` and the bound does not use that this addition is
   exact. The second term is the underflow allowance: at most `C` per iteration, propagated.
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
    `matmul_cols_eq`, `matmul_cols_error` at two strides; `take_pairs`, `matmul_take_nanEq`,
    `matmul_take_eq`, `matmul_take_error` at one). For every `α` with TorchLean's `Storage`, all
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
    `matmul_take_nanEq`, `matmul_take_eq`, `matmul_take_error`. Their statements are unchanged,
    and each is one line from its two-stride form.

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
hypothesis for `acc j` gives `acc (j + 1)`. Statement 10 is statement 9 after statement 8. Statement 11: `get2_cols` unfolds TorchLean's
`slice_apply` and `castShape_apply_reindex` and compares the two coordinates axis by axis
(`Shape.Coord.ext_val`, `index_reindexEq`). `cols_pairs` rewrites its right side with statement 8
and its pairs with `get2_cols`, after which both sides are `List.ofFn` of the same function;
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
of `tA` and the transpose of `mB`'s 2 columns (`matmul_cols_eq` at `sA = 3`, `sB = 2`). Its premise on
the oracle has the twin `matmul_cell_twin`.

## Scope

* Statements 1-11 stand alone: none names a program or runs `exec`. For the one program `naive`
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
