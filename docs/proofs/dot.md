# The contracted dot-product fold (`dotLoop`)

Lean: MojoProof/Sem/Dot.lean. Instances and twins: MojoProofTest/Dot.lean. The statements below
are proved for every FloatLib format where they say so, every list of factor pairs and every
oracle sequence. What is not proved is said in section "Scope". Section "The matmul and gemv
cells against TorchLean" states the loop's results against TorchLean's matrix products.

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
every format and size; the kernel's loop is not connected to them. The connection point: at the
loop's exit `%67`, the word of `%68 = phi float [ %48, %51 ]` that thread `(i, j)` stores is
`dotLoop true o (Model.zero fmt false) (matmulPairs A B i j)`, where `A` and `B` are the input
tensors that `Mem.tensor` reads from the buffers, the loads `%60` and `%64` of iteration `k` give
`get2 A i k` and `get2 B k j`, and `o k` holds the oracle numbers of that iteration's `fmul` and
`fadd`. That equation is not proved (section "Scope"). The corpus has no gemv kernel; the gemv
statements are about the fold only, and a gemv loop with the same body would meet them at the
same point, with `matVecPairs A v i` for the pairs.

## Scope

* The fold is the loop's float arithmetic only. That the kernel's loop, run by `exec` from the
  loop's entry, reaches its exit with `%48` equal to `dotLoop` of the loaded pairs is not proved:
  it needs the loop's control (the induction variable `%47`, the exit test `%49`), the loads'
  values from the input tensors and the oracle numbers at the thread's step counts. Statement 3
  is the step of that proof for one iteration.
* Statement 1 relates the loop to FloatLib's `dotInOrder` with source, accumulator and output
  formats all equal to `fmt`, the only case a loop in one format computes.
* Statement 2 is a forward bound against the exact sum of the decoded words' products. It does
  not say which choices the oracle makes, and assumes the result is finite; overflow of an
  intermediate makes the result infinite or a NaN, and then nothing is claimed.
