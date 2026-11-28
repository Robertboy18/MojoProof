# Float bounds of layer norm's and RMS norm's outputs with `rsqrt.approx`

Lean: MojoProof/Float/Norm.lean, with `msq` and `msq_error` in MojoProof/Float/Stats.lean.
Instances: MojoProofTest/FloatNorm.lean. Floats are FloatLib's `Model fmt` words;
`u = Model.unitRoundoffAt fmt` is FloatLib's unit roundoff and `η = Model.underflowErrorAt fmt`
its underflow allowance (in binary32, `u = 2 ^ -24` and `η = 2 ^ -150`). `MixedError x x₀ r a` is
FloatLib's `|x - x₀| ≤ r · |x₀| + a` with `r, a ≥ 0`.

The statements are about words and the operations a kernel performs on them, as functions of the
inputs. That a grid run of a kernel performs those operations is not proved here, except for one
thread of the block kernel's last loop (below, and [layernorm.md](layernorm.md)). The shape is
the one of docs/proofs/float-reductions.md: for every input meeting the premises, if the computed
word is finite, it is within the stated bound of the exact real value, TorchLean's where TorchLean
has one.

## The outputs

The compiled layer norm kernels normalize each input `x j` with the Welford mean word `μ` and the
word `r = rsqrt.approx (v + ε)` of the variance word `v` (docs/proofs/float-welford.md) plus the
word `ε`, then scale and shift: `((x j - μ) · r) · γ j + β j`
(tests/corpus/layernorm/ln_rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a.nvptx.ll, lines 430-432 for
`v` by `fdiv`, `v + ε` and `llvm.nvvm.rsqrt.approx.ftz.f`, lines 513-516 for the output, all four
operations `contract`). `lnOut fused x μ r g b` is that word, by `Model.sub`, `Model.mul`,
`Model.mul` and `Model.add`, or with the last multiplication and addition one `Model.fma` when
`fused`. `lnorm t x g b ε k fused j` is the binary32 word at `j` with the Welford words along the
tree `t` and `Sem.rsqrt` with oracle number `k`.

RMS norm computes the mean of squares `msq t x N` (each square by `Model.mul`, summed by
`Model.add` along `t`, divided by a word `N` denoting `n`), `r = rsqrt.approx (msq t x N + ε)` and
`rmsOut (x j) r (g j) = (x j · r) · g j`; `rmsnorm t x g N ε k j` is that binary32 word.
Mojo's RMS norm (max/kernels/src/nn/normalization.mojo, lines 339-345 at the pinned commit) adds
a weight offset `o` to the weight `g` of the dtype, in one of two orders: multiplied in the
accumulator before the cast into the dtype, `cast ((x · r) · (cast g + o))`, or cast first,
`cast (x · r) · (g + cast o)`. `rmsOff mbc x r o g` is that word for an accumulator format and a
dtype, each cast `Model.cast` to nearest; `rmsnormOff mbc t x g N ε o k j` is the word at `j`
accumulated in binary32.

`rsqrt.approx` enters through its contract `Sem.rsqrt_close` (MojoProof/Sem/FloatRel.lean): for a
positive normal operand `s`, every word `Sem.rsqrt s k` is finite and within relative error
`rsqrtErr = 1.0718 · 2 ^ -23` of `1 / √s`.

## Statements

1. `msq_error`: in every IEEE format, for every `n`, tree over `0, …, n - 1` up to order, inputs
   and finite word `N` of real value `n`: if the mean of squares word is finite, it is within
   `MixedError … u (msqErr u η t.depth x)` of `𝔼 j, x j ^ 2`, with
   `msqErr u η d x = (1 + u) · (((1 + u) ^ d - 1) · 𝔼 x² + (1 + u) ^ d · 𝔼 (u · x² + η)) + η`.
2. `rsqrt_rel`: for reals `s`, `t > 0` with `s` within `MixedError … r a` of `t`, `r + a / t < 1`,
   `ρ ≥ 0` and `w` within relative error `ρ` of `1 / √s`: `w` is within relative error
   `rsqrtRel r ρ a t = (1 + ρ) · δ / (1 - δ) + ρ`, `δ = r + a / t`, of `1 / √t`.
3. `lnOut_error`: in every IEEE format, fused or not, for a mean word within `e` of `μ₀` and a
   reciprocal word within relative error `κ` of `w`: a finite output is within
   `MixedError … u (lnErr u η e κ w g (x - μ₀))` of `(x - μ₀) · w · g + b`. The fused bound is
   below the unfused one, which `lnErr` states.
4. `lnorm_error`: in binary32, for every `n ≤ 2 ^ 24`, tree over `0, …, n - 1` up to order, inputs
   within `B` in magnitude, weights, biases, word `ε > 0`, oracle number `k`, fused or not, and
   index `j`: if the Welford words and the variance word are finite, the operand `v + ε` of
   `rsqrt.approx` is finite, positive and normal, `u + lnDev u η B t.depth V / (V + ε) < 1` (`V`
   the inputs' variance) and the output is finite, then the output is within
   `MixedError … u (lnErr u η e κ (1 / √(V + ε)) (g j) (x j - 𝔼 x))` of TorchLean's real layer norm
   `TorchLean.TransformerBlock.layerNorm g b ε x j`, with `e = (welfErr u η B t.depth).1` and
   `κ = rsqrtRel u rsqrtErr (lnDev u η B t.depth V) (V + ε)`.
5. `rmsOut_error`: in every IEEE format, for a reciprocal word within relative error `κ` of `w`: a
   finite `(x · r) · g` is within `MixedError … ((1 + u) · ((1 + u) · κ + u) + u)
   ((1 + u) · η · |g| + η)` of `x · w · g`.
6. `rmsnorm_error`: in binary32, for every `n`, tree over `0, …, n - 1` up to order, inputs,
   weights, finite word `N` of real value `n`, word `ε > 0`, oracle number `k` and index `j`: if
   the operand `msq t x N + ε` is finite, positive and normal,
   `u + (1 + u) · (u · M + msqErr u η t.depth x) / (M + ε) < 1` (`M = 𝔼 x²`) and the output is
   finite, the output is within statement 5's mixed error, with
   `κ = rsqrtRel u rsqrtErr ((1 + u) · (u · M + msqErr …)) (M + ε)`, of the real RMS norm
   `x j / √(M + ε) · g j`.
7. `rmsOff_error`: for every IEEE accumulator format and IEEE dtype, order `mbc`, and reciprocal
   word within relative error `κ` of `w`: a finite `rmsOff mbc x r o g` is within
   `MixedError … (rmsOffErr mbc ua ηa ud ηd κ (x · w) g o)` of `x · w · (g + o)`, with the unit
   roundoffs and underflow allowances of the two formats.
8. `rmsnormOff_error`: accumulated in binary32, for every IEEE dtype, order `mbc`, `n`, tree over
   `0, …, n - 1` up to order, binary32 inputs, weights of the dtype, finite word `N` of real value
   `n`, words `ε > 0` and `o`, oracle number `k` and index `j`: under statement 6's premises on
   the operand (the one on its error written `¬ 1 ≤ …`), a finite output is within statement 7's
   mixed error, with statement 6's `κ`, of the real RMS norm with the offset
   `x j / √(M + ε) · (g j + o)`.
9. `cast_widen`: for all IEEE formats `fs` and `fd` with `fd`'s exponent and fraction widths at
   least `fs`'s, and every finite word `x` of `fs`: `Model.cast fs fd x` is finite and has the real
   value of `x`.
10. `rmsnormOff_widen`: statement 8 at the binary32 words `Model.cast fs binary32 (x i)` of finite
   inputs `x` of an IEEE format `fs` with at most binary32's exponent and fraction widths
   (binary16 and bfloat16 among them), its premise on the operand's error and its real value
   stated with the real values of `x`.

TorchLean's `TorchLean.Tensor.rmsNorm` (TorchLean/Tensor/Layers/Normalization.lean) divides each
fiber by its largest magnitude before it takes the mean of the squares, and TorchLean proves no
closed form of it over the reals; its docstring states `x / sqrt (mean x ^ 2 + epsilon) · gamma`
for a positive scale. Statement 6 is against that real value, written out; no second RMS norm is
defined. TorchLean.TransformerBlock has no RMS norm.

## Instances (MojoProofTest/FloatNorm.lean)

In binary32, with weights `1`. `lnorm_iota` is statement 4 at the inputs `1, …, 2 ^ k` along the
halving tree `halveFin k`, for every `k ≤ 24`, with the inputs' variance
`((2 ^ k) ^ 2 - 1) / 12` in place of `V`; the tactic `lndev_num` closes its premise `… < 1` at a
concrete `k` and `ε` by `norm_num` on FloatLib's binary32 constants. Its instances, fused or not,
with biases `0`, are `lnorm_xs` at `k = 2` (the inputs `1, 2, 3, 4` along `(0 + 2) + (1 + 3)`)
with `ε = 2.75`, where the variance word is `1.25`, the operand is `4` and, under the oracle number
of the word `0.5`, the output at `0` is `-0.75` (`outs_xs`), and `lnorm8` at `k = 3` with
`ε = 10.75`, where the real operand is `5.25 + 10.75 = 16`, under the oracle number of `0.25`.
`rmsnorm_iota` is statement 6 at `1, …, 2 ^ k` along `halveFin k` with `N = 2 ^ k`, for every
`k ≤ 24`, with the inputs' mean of squares `(2 ^ k + 1) (2 · 2 ^ k + 1) / 6` in place of `M`, and
`lndev_num` closes its premise `… < 1` too. Its instances are `rmsnorm_xs` at `k = 2` with
`ε = 8.5`, where the mean of squares word is `7.5`, the operand `16` and, under the oracle number
of `0.25`, the output at `0` is `0.25`, and `rmsnorm8` at `k = 3` with `ε = 38.5`, where the real
operand is `25.5 + 38.5 = 64`, under the oracle number of `0.125`. The finiteness and normality
premises are discharged by evaluation (`decide +kernel`). `var_xs_eq` (`V = 5 / 4`) and
`msq_xs_eq` (`M = 15 / 2`) are the instances at `4` of
`var_iota` and `msq_iota` (the variance `(n ^ 2 - 1) / 12` and the mean of squares
`(n + 1) (2 n + 1) / 6` of `1, …, n`, MojoProofTest/FloatStats.lean), whose instances at `8` are
`var8` and `msq8`. Statement 8's instances, with the offset `1` and the tactic `rmsoff_num` for
its premise on the operand's error, are `rmsnormOff_bf16` at `k = 2` with `ε = 8.5`, bfloat16
weights `1` and the order multiplied before the cast, and `rmsnormOff_f16` at `k = 3` with
`ε = 38.5`, binary16 weights `1` and the cast first. Statement 9's instances are `widen_words`,
the binary16 word `0x3c01` and the bfloat16 word `0x3f81` cast into binary32 (the words
`0x3f802000` and `0x3f810000`, finite, with the same values), and its mutant `narrow16`, the
binary32 word `0x3f800001` (`1 + 2⁻²³`) cast into binary16, where statement 9's premise on the
fraction widths fails and the cast is the word `0x3c00` of `1`. Statement 10's instances are
`rmsnormOff_in16` and `rmsnormOff_inbf16`, `rmsnormOff_bf16`'s case with the inputs `1, 2, 3, 4`
in binary16 and in bfloat16 (`iotaIn`) cast into binary32, cast first and multiplied first;
`iotaIn_toReal` gives their inputs' real values by statement 9. Each instance is one example and
`lnorm_iota` and `rmsnorm_iota` cover only the inputs `1, …, 2 ^ k`; none is a claim about a
program.

## Proofs

1. Each square is the rounding of `x j ^ 2` (FloatLib's `Model.toReal_mul_eq_roundAt`), so within
   `(u, η)` of it; `sum_mixedError` sums them along the tree; FloatLib's
   `Model.mixedError_toReal_div` divides by the exact `N`.
2. FloatLib's `MixedError.relative_of_le_abs` makes the operand's error relative, then
   `MixedError.sqrt`, `MixedError.inv` (which needs `δ < 1`) and `MixedError.trans` with `w`'s
   relative error.
3. One FloatLib lemma per operation: `Model.mixedError_toReal_sub` with the mean's absolute error,
   `Model.mixedError_toReal_mul` twice and `Model.mixedError_toReal_add`, or
   `Model.mixedError_toReal_fma` for the fused pair.
4. `wmean_error` for the mean, `wvar_error` and `Model.mixedError_toReal_add` for the operand,
   `Sem.rsqrt_close` and statement 2 for the reciprocal, statement 3, and
   `layerNorm γ β ε x j = (x j - 𝔼 x) · (1 / √(V + ε)) · γ j + β j`.
5. `Model.mixedError_toReal_mul` twice.
6. Statement 1 and `Model.mixedError_toReal_add` for the operand, `Sem.rsqrt_close` and statement
   2, then statement 5.
7. In the kernel's order, `Model.mixedError_toReal_mul`, `Model.mixedError_toReal_add` and
   `Model.mixedError_toReal_cast` per operation, each cast bounded as a rounding.
8. As 6, then statement 7.
9. FloatLib's `Block.Working.cast_exact_of_grid`
   (FloatLib/Floats/Formats/Block/Working/Binary.lean), which takes a finite input, at most as
   many fraction bits, a smallest subnormal exponent at least the target's and a largest finite
   value at most the target's. The last two follow from the IEEE bias `2 ^ (e - 1) - 1`
   (FloatLib's `FloatFormat.isIEEE_eq_true_iff`) and `Model.toReal_posMaxFinite_ieee`.
10. Statement 9 rewrites the inputs' real values in statement 8.

## Not proved

- The Welford words' fused multiply-adds. `lnorm` takes the words of `welford`, which rounds
  every product, while the kernel's merge has two `fmul contract` products feeding `fadd contract`
  (lines 263-264 and 266-268 of the file above) and so has its loop's update (lines 151-152 and
  155-156), each pair free to fuse. `fused` covers only the output's last multiplication and
  addition (lines 515-516). The merge and the loop are bounded on their own for every choice of
  contraction at each node and each iteration (`welfordC_error` and `wloop_error`,
  docs/proofs/float-welford.md), not composed into `lnorm` here.
- RMS norm's squares fused into the additions that sum them.
- The cast into binary32 before the squares of an input format with another encoding or bias than
  IEEE's (FloatLib's finite-only and FNUZ formats): statement 10 takes IEEE formats with at most
  binary32's widths. The casts of the weight, the offset and the output are bounded as roundings,
  also where they are exact (a widening).
- That a grid run of a kernel computes these words. One thread's run of the last loop of layer
  norm's block kernel (tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll,
  :718-722) stores, at each of its floats, a value that, when finite, is `lnOut fused` of its row
  entries and the registers `%460`, `%464`, with `fused` fixed by the context's oracle
  (MojoProofTest/LnRun.lean's `lnVal_finite`, and `lnVal_error` for this page's bound). The words
  of those two registers are not run, so `lnorm` is not reached.
- Any bound when the output is infinite or a NaN.
