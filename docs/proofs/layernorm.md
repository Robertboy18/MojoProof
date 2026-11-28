# Layer norm's last loop, run at every block size and row length

The kernel is tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, layer
norm by rows at block size 128 (MojoProofTest/SymSeg.lean's `ln`). The corpus has the same kernel
at block sizes 64, 128, 256 and 1024 (ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}, 828 lines
each). With the kernel's name normalized, the four files differ only at :6 (the shared array's
size), :9 (the name), :30 (`icmp slt i64 %21, B/32`), :117 (`%79 = add i64 %73, B`),
:421/:423/:641/:655 (the shared array's name), :681 (the loop's step) and :817
(`"nvvm.maxntid"="B"`). The line numbers below are the bs128 file's, which are the others' too.
Its last loop writes the
normalized row. The header `%469` (:677-690) holds the `phi`s (:678-680) and the exit test
`icmp sge` (:684). The body `%484` (:698-709) computes the float index `%485 = %471 + tid` (:699),
the four `getelementptr`s (:700-703) and the guard `icmp slt %485, %65` (:708). The store block
`%496` (:714-723) holds three loads (:715-717), the arithmetic (:718-721) and the store (:722).
The paths back are `%529` or `%531`, then `%532` (:763-772); the exit is `%482` to `%534` (:774).
This page says what is proved about that loop, in which files, and what is left. The view side
(which bytes each thread owns, `lnStores` and `ln_guard_stores`) is in
[mixed-radix.md](mixed-radix.md).

## Status and scope

**Proved** for every block size `B` with `0 < B`, `B ≤ 2 ^ 32` and the covers `LnCovers B`, in
MojoProofTest/LnGep.lean, MojoProofTest/LnRound.lean and MojoProofTest/LnRun.lean, for the
family's function `lnFam.fn B` (the bs128 file's function with the step of :681 at `B`) in a
context of the bs128 file's program `ln.prog`. These are run theorems of the symbolic layer
(`Block.sound_edge`) for one thread. They hold for:

* every context of `ln.prog`, so every launch and thread, with `tid < 1024`;
* every row length `n < 2 ^ 32`;
* every memory in which `y` (writable), `g`, `b` and `x` (read-only) are buffers of `4 n` bytes
  that fit, `x`, `g` and `b` hold the rows `X`, `G`, `Bt` (row-major binary32), and `y` is none of
  the other three.

At 128 the family's function is the corpus file's (`lnFam.prog_corpus`), and the bs128 theorems
(`run_entry`, `run`, `run_from`, `run_exit`, `entry_edge`, `AtHead.roundT`, `AtHead.roundF`,
`AtHead.exit`) are the general ones at `B := 128`, with their statements unchanged.
MojoProofTest/LnFamily.lean imports the bs64, bs256 and bs1024 files and evaluates the premises
there: each file's loop blocks summarize to the family's at its `B`, and the run theorem holds at
`lnFam.fn B` for that `B`. It does not run the files' own functions in their own programs (see
"Not proved").

The premises on `B`, with their reasons. Each holds at 64, 128, 256 and 1024 (by `decide` and
`covers_64`, `covers_128`, `covers_256`, `covers_1024`):

* `0 < B`: the fuel. `run_fromB` is an induction on the fuel `K` with `n ≤ i + B K`, and `runB`
  starts it at `K = n` and `i = 0`, where `n ≤ B n` needs `B ≥ 1`.
* `B ≤ 2 ^ 32`: the step `%473 = add i64 %471, B` (:681) and the float index `%485` (:699) do not
  overflow. With `n < 2 ^ 32` and an index `i < n + B`, the words `i + B` and `i + tid` stay below
  `2 ^ 63`. The rounds' obligations (`round_trueB`, `round_falseB`) use it.
* `LnCovers B`: the path checker (`coversPathAt`, `phi`s and `fmul contract`, no `alloca`)
  accepts the two rounds `lnTB B` and `lnFB B`, the path out of the loop and the edge into it, at
  `lnFam.fn B`. The checker computes it at each numeral.

The mean `%460` (:666) and the inverse deviation `%464` (:670) are given registers (`mu`,
`rs`). The code before this loop, which computes them, is not run. The view side is at every
block size.

MojoProofTest/LnRunTest.lean applies the run at block size 128 at a memory built from three
tensors, at every row length and thread, and evaluates it at `n = 300`.

## What mentions the block size

Before the generalization, these facts of the run mentioned 128, all through the step
`%473 = add i64 %471, 128` (:681):

* the header's summary `hdr` (`%469` from statement 3): its node 0 is
  `.bin .add {} 64 (.reg 476) (.int 64 128)`. So do the rounds `lnT` and `lnF` (their header
  `H`) and the covers `cov_T`, `cov_F`, `cov_X`, which check them;
* `round_true` and `round_false`, through `lnT` and `lnF`;
* `AtHead.next`, `AtHead.roundT`, `AtHead.roundF`: the index after a round, `%476 = i + 128`;
* `AtHead.exit`: the index at the exit, `i < n + 128`;
* `run_from`: the fuel `n ≤ i + 128 K`, the index `i < n + 128`, `lnLoop 128` and the induction's
  step `i + 128`;
* `run` and `run_entry`: `lnStores 128 n tid`.

The other summaries (`b482`, `b483`, `b484`, `b495`, `b496`, `b529`, `b531`, `b532`, `pre`) do not
mention it. Nor do the guard `icmp slt %485, %65` (:708) and the exit test (:684), whose operands
are registers. MojoProofTest/LnGep.lean's `ln_gep_row` was already stated at every `B`. The
files' other differences (:6, :30, :117, the names) are outside the loop.

`mojo_family lnFam := ln.prog 0 with B at "%473"` (MojoProof/LLVM/Family.lean) is `ln.prog` with
that constant as the parameter `B`. `hdrB B`, `lnTB B` and `lnFB B` are `hdr`, `lnT` and `lnF`
with it, and `hdrB_128`, `lnTB_128`, `lnFB_128` give them at 128.

## The pointers past the row (MojoProofTest/LnGep.lean)

At a buffer of exactly the row's `4 n` bytes, the `getelementptr inbounds` of float `128 j + tid`
(:700) is:

* `ln_gep`'s pointer inside the row (`ln_gep_row`);
* the pointer one past the end at float `n`;
* poison past the block (`gep_inbounds_past`, `ln_gep_past`). This is `gepPtr`'s rule for
  `inbounds` (MojoProof/Sem/Eval.lean), as LangRef's "getelementptr Instruction" says.

The semantics never faults there (`gep_buffer_ok`), so it accepts the step LLVM accepts.

## One round (MojoProofTest/LnRound.lean)

* `round_falseB`: at every block size `B ≤ 2 ^ 32`, with `i < n ≤ i + tid`, the round on the path
  `%469`, `%483`, `%484`, `%531`, `%532` has its premises (`RoundWith`, `lnFB B`). It evaluates
  the `getelementptr`s by `i + tid ≥ n` and has no store.
* `round_trueB`: at every `B ≤ 2 ^ 32`, with `i + tid < n`, the round through `%495` and `%496`
  (the three loads and the store at :722) has its premises (`lnTB B`).
* `round_false` and `round_true` are their instances at 128 (`lnF`, `lnT`).

## The run (MojoProofTest/LnRun.lean)

`LnHead B` is the state at the header after its `phi`s at loop index `i`, in the family's
function `lnFam.fn B`. `AtHead` is `LnHead 128` by definition (an `abbrev`); its function
`lnFam.fn 128` is `ln.fn_0` (`lnFam.prog_corpus`). Each run theorem has three conclusions about
the memory.

* **The order and number of the accesses: `LnTrace w y g b x ks m M`.** `M`'s trace
  (`Mem.trace`, newest first) is `m`'s, with the accesses of the rounds of `ks` in front, newest
  first: the reverse of `ks.flatMap (lnAcc w y g b x)`. `lnAcc` lists a round's accesses in the
  order of the run, so one round's prefix is `[write y, read b, read g, read x]`. In the order of
  the run, for each `k` of `ks` in turn:
  * thread `w` reads 4 bytes at float `k` of `x`, `g` and `b` (the loads :715-717; the last two
    carry `!invariant.load`);
  * then it writes 4 bytes at float `k` of `y` (:722);
  * there is no other event: no barrier, no atomic, no other access.

  `lnAcc_writes`: the writes, in the order of the run, are exactly the 4-byte writes at the floats
  of `ks`, in `ks`' order. `LnTrace.ext` states the trace in `Ext`'s form.
* **The final blocks: `LnOut y R ks m M`.** `M`'s blocks are `m`'s, but block `y` is `m`'s with
  byte lists put at byte `4 k` for each `k` of `ks` in turn (`putFloats`), each related to its
  `k` by `R`. It is a relation of the blocks only: `LnOut y R [] m (m.log e)` holds for every
  event `e` (`log_blind` in the tests), so the trace is `LnTrace`'s to state. `LnOut.read`: when
  `ks` has no repeated index and `R`'s lists have 4 bytes, the final 4 bytes at float `k` of `y`
  are related to `k` by `R` for each `k` of `ks`, and are `m`'s at every other float.
* **The floats stored: `R = LnBytes X G Bt mu rs`.** The bytes at float `k` are the binary32
  encoding (`Layout.encode` at `float`, the encoding `Mem.Holds` reads) of
  `lnVal X[k] G[k] Bt[k] mu rs`, under some oracle numbers (next section).

`LnHead.roundT` (the guard :708 true) and `LnHead.roundF` (the guard false) give:

* the round's premises;
* `LnHead` at `i + B`;
* `LnOut` at `LnBytes` and `LnTrace`, at `[i + tid]` or at `[]`.

In `roundT` (its memory and trace in `LnHead.roundT_out`):

* `run_put` turns the block's effects (three loads, then the store of node 6 through `%486`) into
  both relations.
* `obl_have` evaluates node 6, `%503`, from the loads' values that `LnHead`'s tensors give.
* `SEff.access` evaluates the loads' accesses. Their statements are `%496`'s, which `fnB_496`
  finds in `lnFam.fn B` at every `B`.

The false path (`%484`, `%531`, `%532`) has no load or store. `LnHead.exit` is the path out
`%469`, `%482` to `%534`, and it keeps the whole memory. `AtHead.roundT`, `AtHead.roundF` and
`AtHead.exit` are the three at 128.

`run_fromB` is the hand-proved run lemma (66 lines, 80 with its docstring). It is an induction on
the fuel `K` with `n ≤ i + B K`: one `Block.sound_edge` per round, then `run_exitB` at the end.
`runB` is `run_fromB` at `K = n` and `i = 0`. `entry_edgeB` and `run_entryB` add the edge from
`%453`'s branch (:675), whose `phi`s (:678-680) set the index to 0, so the run goes from the
loop's entry to `%534` (:774):

```lean
theorem run_entryB {B n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hcv : LnCovers B) (hB0 : 0 < B) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn B) (hl : f.label = ln.fn_0.b_42.label) (hp : f.pc = 21) ... :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn B ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores B n tid) m m' ∧
      LnTrace c.who y g b x (lnStores B n tid) m m'
```

The premises left out above are the frame's registers (the thread index, the word of `n`, `mu`
and `rs` with no recorded product, and the pointers to `y`, `g`, `b` and `x`), the four buffers
of `4 n` bytes that fit, and `x`, `g` and `b` holding `X`, `G` and `Bt` (row-major binary32).
`run_entry` is it at `B := 128`, `covers_128`, with `hf : f.fn = ln.fn_0` and
`lnStores 128 n tid`. Likewise `run_exit`, `run_from`, `run` and `entry_edge` are `run_exitB`,
`run_fromB`, `runB` and `entry_edgeB` at 128.

`lnStores_eq` gives `lnStores B n tid` as the floats `B j + tid < n`, in order
(MojoProofTest/GPUProof/ViewStride.lean). With `ln_guard_stores`, these are thread `tid`'s
guarded tile when `n ≤ tid + B X`. The run thus writes exactly the bytes of the view's tile, in
that order, and nothing else. `lnStores_nodup`: at every block size `B ≥ 1` no float repeats (at
`B = 0` one does, the `example` after it), so `LnOut.read` applies to the run's floats.

## The floats stored

`lnVal x g bt mu rs d₀ d₁ d₂ o` is `%503` by MojoProof/Sem/Float.lean's rules (its docstring,
:25-28 and :35-45). The IR is:

* `%500 = fsub contract %497, %460` (:718);
* `%501 = fmul contract %500, %464` (:719);
* `%502 = fmul contract %501, %498` (:720);
* `%503 = fadd contract %502, %499` (:721).

```lean
def lnVal (x g bt mu rs : Model FloatTy.float.fmt) (d₀ d₁ d₂ o : Nat) : Model FloatTy.float.fmt :=
  deliver (contract false (deliver ((deliver ((deliver (x.sub mu) d₀).mul rs) d₁).mul g) d₂) bt
    (some (deliver ((deliver (x.sub mu) d₀).mul rs) d₁, g)) none o) (o / 3)
```

* Each step is FloatLib's operation (`Model.sub`, `Model.mul`, `Model.add`, `Model.fma`) through
  `deliver` (Float.lean:92). A NaN result's payload is chosen by an oracle number; any other
  result is kept.
* `%500`'s operands have no recorded product, so its contraction is never fused
  (`contract_none`).
* `%503` is `contract` (Float.lean:115) with `%502`'s recorded factors `(%501, G[k])`. At an
  oracle number `o` with `o % 3 = 1` it is `Model.fma %501 G[k] Bt[k]`, a single rounding of
  `%501 · G[k] + Bt[k]`. Otherwise it is `Model.add %502 Bt[k]`, rounded separately. `py` is
  `none` (`Bt[k]` is a load), so the third case of `contract_cases` (Float.lean:124) does not
  arise.
* `lnVal_cases` states both results up to NaN payloads (`NaNEq`, MojoProof/Sem/FloatRel.lean:108),
  with `p` the rounded `(X[k] - mu) * rs`:
  * `p` is NaN-equal to FloatLib's `(X[k] - mu) * rs`;
  * `lnVal` is NaN-equal to `Model.fma p G[k] Bt[k]` when `o % 3 = 1`;
  * otherwise `lnVal` is NaN-equal to `(p * G[k]) + Bt[k]`.

In a run the oracle numbers are the context's: `oracle (Nat.pair (k + j) 0)` at node `j` of
`%496`'s summary. A context therefore fixes one result at each float. The run theorems hold for
every context, so they leave the set: at each float, the fused or the unfused value, each with a
free NaN payload. The oracle number `o = 1` gives the fused value and `o = 0` the unfused one.

A finite float stored is exactly the float library's layer norm output, and so has its error
bound:

* `lnVal_finite`: if `lnVal x g bt mu rs d₀ d₁ d₂ o` is finite, it is
  `MojoProof.Float.lnOut (o % 3 == 1) x mu rs g bt` (MojoProof/Float/Norm.lean). The results of
  the computation the oracle selects are then finite, so not NaN, and `deliver` keeps each. Fused
  (`o % 3 = 1`), these are the `fma`'s result, its factor `%501` and `%501`'s factor `%500`
  (FloatLib's `Model.isFinite_of_isFinite_fma`, `_mul`); the separately rounded product `%502` is
  not part of the fused result and may be infinite then. Unfused, these are each rounded step
  `%503`, `%502`, `%501`, `%500` (`_add`, `_mul`).
* `lnVal_inf` (the tests): at binary32 `x = 2^127`, `mu = 0`, `rs = 1`, `g = 2` and
  `bt = -(2^128 - 2^104)`, the separately rounded product `%502` is `+Inf`, and the fused float
  (`o = 1`) is `2^104`, finite.
* `lnVal_error`: with `|mu - μ₀| ≤ e` and `rs` within relative error `κ` of `w`
  (`MixedError rs w κ 0`), a finite `lnVal` is within FloatLib's mixed error
  `(u, lnErr u η e κ w g (x - μ₀))` of the real `(x - μ₀) · w · g + bt`, fused or not. This is
  `MojoProof.Float.lnOut_error` at binary32, by `lnVal_finite`. The accuracy of `mu` and `rs` is
  the premise: the run takes them as given registers.
* `LnBytes.error`: the same for the float whose bytes `LnBytes` names, at the row's entries
  `X[k]`, `G[k]`, `Bt[k]`.

## The instance at block size 128 (MojoProofTest/LnRunTest.lean)

* `mem n X G Bt` builds blocks 1, 2, 3 from the tensors `X`, `G`, `Bt` (`tensorBytes`, read-only)
  and block 4, a writable output of `n` words. The blocks are at addresses `16 n`, `32 n`, `48 n`,
  `64 n`, so they do not overlap.
* `ctx tid` is thread `tid` of one block of 128 threads (`launch2`). `frame` is at `%453`'s branch
  with exactly the registers that `run_entry` reads.
* `run_mem`: `run_entry` at that state, for every `n < 2 ^ 32`, thread `tid < 128`, rows, `mu` and
  `rs`. Every premise is proved: the buffers by `Mem.allocs_spec`, the tensors by
  `Mem.holds_alloc`, the registers by evaluation.
* `run_300`: at `n = 300`, with `lnStores` evaluated, the run's floats are:
  * thread 43: 43, 171, 299;
  * thread 44: 44, 172 (its third float, 300, is one past the row);
  * thread 45: 45, 173 (its third float, 301, is past the buffer, where the `getelementptr` is
    poison).
* `run_floats`: for every `n < 2 ^ 32`, thread `tid < 128`, rows, `mu` and `rs`, and `mu` within
  `e` of `μ₀` and `rs` within relative error `κ` of `w`, the final memory (`LnOut.read`,
  `lnStores_nodup`):
  * keeps `mem`'s blocks other than 4, and block 4's bytes at every float outside
    `lnStores 128 n tid`;
  * has, at each float `k` of `lnStores 128 n tid`, the bytes of `lnVal X[k] G[k] Bt[k] mu rs`, a
    float that, if finite, is within `lnErr` of `(X[k] - μ₀) · w · G[k] + Bt[k]`
    (`LnBytes.error`).
* `float_43`: `run_floats` at `n = 300`, thread 43 and float 43.
* `run_lnorm`: for every `n < 2 ^ 32`, thread `tid < 128`, rows, reduction tree `t`, word `ε` and
  oracle number `q`, run the thread with `mu` the float library's Welford mean word
  `(welford t X).2.1` and `rs` the word `Sem.rsqrt (wvar t X + ε) q` (MojoProof/Float/Norm.lean,
  with `X` read by index as `row X`). Each float `k` of `lnStores 128 n tid` that it stores is
  then, if finite, `lnorm t X G Bt ε q fused k` for a `fused` (`lnVal_finite`).
* `run_torch`: `run_lnorm` and `MojoProof.Float.lnorm_error`. For every `n ≤ 2 ^ 24`, tree whose
  leaves are the row's indices up to order, `X` within `Bd` in magnitude and `ε > 0`, under
  `lnorm_error`'s premises on the words of `X` (the Welford and variance words finite,
  `wvar t X + ε` finite, positive and normal, and `u + lnDev … / (V + ε) < 1`), each float the
  thread stores is, if finite, within FloatLib's mixed error `(u, lnErr …)` of TorchLean's real
  layer norm `TorchLean.TransformerBlock.layerNorm G Bt ε X` at its index. `lnorm_error`'s
  premise compares FloatLib's `Model.underflowErrorAt .binary32`, which is `bpow 2 (-150)`, with
  a real. `bpow` is irreducible for the theorem (`attribute [local irreducible] … in`, as for
  `lnorm_error` itself), so that Lean does not unfold the power past its default recursion limit.
* `torch_iota`: `run_torch` with every premise proved, at thread 0, the row `X = 1, 2, 3, 4`,
  weights `1`, biases `0`, the tree `halveFin 2`, `ε = 2.75` and the oracle number of the word
  `0.5` (`ofRow` builds the tensors from words, and `row` reads them back, `row_ofRow`). The
  words' premises are by evaluation, the premise on the operand's error by `var_iota` and
  `lndev_num`, as for MojoProofTest/FloatNorm.lean's `lnorm_xs`. So the premises hold together.
* `lnVal_two`: at `x = 1 + 2⁻²³`, `g = 1 - 2⁻²³`, `bt = -1`, `mu = 0`, `rs = 1`, by evaluation
  (`decide +kernel`), the unfused float (`o = 0`) is `+0` and the fused one (`o = 1`) is
  `-2⁻⁴⁶`, both finite. Both cases of `lnVal_cases` occur, and they differ.
* `log_blind`: `LnOut` holds after a logged event and `LnTrace` at `[]` does not.
* `short`: an output buffer of 299 words fails `run_entry`'s premise on `y`.

These are tests of one program. `run_mem`, `run_floats` and `run_lnorm` cover every row length,
thread and tensor, and `run_torch` every row length up to `2 ^ 24`. `run_300` and `float_43` are
at `n = 300`, for every row of that length. `torch_iota` and `lnVal_two` are at one input each.

## The other block sizes (MojoProofTest/LnFamily.lean)

The file imports the bs64, bs256 and bs1024 files (`mojo_import` as `ln64`, `ln256`, `ln1024`).
For each `B` of 64, 256 and 1024 (the names end in the block size):

* `hdr_64`, `hdr_256`, `hdr_1024`: the file's header `%469` from statement 3 summarizes to `hdrB B`,
  at the file's own program and function;
* `file_64`, `file_256`, `file_1024`: the path checker accepts `lnTB B`, `lnFB B`, the path out and
  the edge in at the file's own program and function. The checker summarizes each block of those
  paths in the file, so the file's loop blocks (:675-774) summarize to the family's at `B`;
* `covers_64`, `covers_256`, `covers_1024`: `LnCovers B`;
* `run_entry_64`, `run_entry_256`, `run_entry_1024`: `run_entryB` at `B`, with its premises on `B`
  discharged, for every context of `ln.prog`, thread `tid < 1024`, row length `n < 2 ^ 32`, memory
  and rows. The thread stores at `lnStores B n tid`;
* `stores_64`, `stores_256`, `stores_1024`: `lnStores B n tid` evaluated at `n = 300` (3000 at
  1024), threads 43 and 44:
  * at 64: thread 43 stores 43, 107, 171, 235, 299 and thread 44 stores 44, 108, 172, 236;
  * at 256: thread 43 stores 43, 299 and thread 44 stores 44;
  * at 1024 (`n = 3000`): thread 43 stores 43, 1067, 2091 and thread 44 stores 44, 1068, 2092.

`layouts`: the three programs have `ln.prog`'s layout. The mutant `hdr_256_ne`: the bs256 file's
header does not summarize to the bs128 `hdr`, and the checker rejects the bs128 round `lnT` at the
bs256 file. A premise at the wrong `B` fails.

The theorems at 64, 256 and 1024 are about `lnFam.fn B` in a context of `ln.prog`. The files' own
functions agree with it in the loop, block by block, only up to summaries (`file_64`, `file_256`,
`file_1024`), and their programs only up to the layout (`layouts`). The next section says what is
left.

## Not proved

* The mean `%460` (:666) and the inverse deviation `%464` (:670). They are given registers here,
  and the code that computes them is not run.
* The run of the bs64, bs256 and bs1024 files in their own program and function. The theorems at
  those block sizes are about the family's function `lnFam.fn B` in a context of `ln.prog`, the
  bs128 file's program. At 128 the family's function is the file's.
* The whole launch, with every thread at once (this is one thread's run).
* That the kernel's `mu` and `rs` are the float library's Welford words, or close to the row's
  mean and to `1 / √(var + ε)`. The code that computes them is not run, so `lnVal_error`'s
  premises and the registers of `run_lnorm` and `run_torch` are not discharged.

## Plan

The remaining statement is the run of each file in its own program and function. At 256 (and
likewise at 64 and 1024, with `ln64` or `ln1024` and `lnStores 64` or `lnStores 1024`), it is
`run_entryB`'s statement with `ln256.prog`, `ln256.fn_0` and `ln256.prog.layout` for `ln.prog`,
`lnFam.fn B` and `ln.prog.layout`:

```lean
theorem run_entry_file {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln256.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln256.fn_0) (hl : f.label = ln.fn_0.b_42.label)
    (hp : f.pc = 21) ... :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln256.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 256 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 256 n tid) m m'
```

The left-out premises are `run_entryB`'s, at `ln256.prog.layout`. Two routes:

* Generalize LnRound's and LnRun's theorems from `W.ctx.prog = ln.prog` and `W.fn = lnFam.fn B`
  to a program `P` with `P.layout = ln.prog.layout` and a function `F` whose covers at `P` hold
  (`file_256`'s four conjuncts at `P`, `F`) and whose block at label 501 is `ln.fn_0.b_48` (as
  `fnB_496`). Then `run_entry_file` follows from `file_256`, `layouts` and that block's equation
  at `ln256.fn_0`. The obstacle is the obligation tactics. `mojo_obl` and `obl_have` reduce the
  closed terms of the program's layout and the function's statements, so today the theorems take
  the constants `ln.prog` and `lnFam.fn B`, whose one free variable `B` they handle.
* A congruence in the symbolic layer: `RoundWith`, `EdgeWith` and the run that `Block.sound_edge`
  gives depend on the valuation's function only through the blocks at the path's labels, and on
  its program only through the layout. With it, the runs at `lnFam.fn B` in `ln.prog` transport
  to `ln256.fn_0` in `ln256.prog`. That layer is MojoProof/Sym/.

What a step reads, and where the files differ. `step` (MojoProof/Sem/Thread.lean:567) reads the
current block (:571), the program's layout (:434, :440), its intrinsics (:396, :504, :515) and
its module, for callees by name and their attribute groups (:502, :516, :523, :579-580).
Evaluated, `lnFam.fn 256` and `ln256.fn_0` (likewise at 64 and 1024) differ in 5 of their 60
blocks, at labels 1, 73, 97, 451 and 455. The loop's blocks (labels 471, 473, 486, 487, 488, 499,
500, 501 and 510) and the exit's target 38 are equal, and the entry edge's block 455
(`ln.fn_0.b_42`) differs only at statement 1, before the edge's start at pc 21. The parameters,
return types, local names and attribute group are equal; the names differ. `ln.prog` and
`ln256.prog` have equal layouts and intrinsics and differ in the kernels list, the shared
global's name, the kernel's name and the first of 7 attribute groups. So every block the run
visits is equal, but a transport lemma over `Steps` (MojoProof/Sym/Rel.lean:40) cannot use that:
`Steps` records no labels, so its conclusions do not say which blocks were visited. What is
missing is the second route's congruence, by induction over `EdgeWith` and `RoundWith`
(MojoProof/Sym/Loop.lean:221, :240), whose exits read the function at `exit.pc V.fn h` (:226).
`Block.sound_edge` (:299) is already generic in the program and the function, and `file_256`
gives the covers at `ln256.prog` and `ln256.fn_0`. With the congruence, `LnHead`'s fields `prog`
and `fn` (MojoProofTest/LnRun.lean:646) take a program `P` and a function `F`, and
`round_trueB` and `round_falseB` (MojoProofTest/LnRound.lean:247, :176) and `entry_edgeB` and
`run_fromB` (MojoProofTest/LnRun.lean:1509, :1313) are proved again over them.

A family that covers the files themselves is no route. `mojo_family` abstracts only one integer
constant of a `bin` statement, and the files differ also at :30 (an `icmp`) and in the names.

### Other float formats

The theorems above are at binary32 only (`Model FloatTy.float.fmt` throughout), and the source is
generic in its `dtype` (rowwise_normalization.mojo:440), with its sums at
`get_accum_type[dtype]` (:466; numerics.mojo:906: float32 for float16 and bfloat16). Measured:
test_layer_norm.mojo compiled with its `run_layer_norm_gpu` calls at `float16` and at
`bfloat16`, and the bs128 `rowwise_block_t0_r1_ax0_w1` file of each (839 lines) compared with
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll (828 lines), the
names and register numbers normalized:

* Storage format, 39 lines, each `float` become `half` (`bfloat`) with alignment 2 for 4: the
  kernel's `byval` struct, whose fourth field is epsilon (:9 and its seven `getelementptr`s
  :21-27); the ten `getelementptr inbounds` on rows; the nine loads (epsilon at :104, the row in
  the two Welford loops at :148 and :184, and the row, gamma and beta in the two copies of the
  last loop, :718, :719, :721, :753, :755, :758 of the float16 file); the two stores (:729,
  :767).
* Conversion, 11 lines added: `fpext` to float after each of the nine loads (:149, :185, :671
  for epsilon, :720, :722, :723, :756, :759, :760) and `fptrunc` to the storage format before
  each store (:728, :765).
* Accumulation format: no line differs. The Welford sums, the shared struct of three floats
  (:665), the mean `%462` and the variance `%464` (:668-670), `llvm.nvvm.rsqrt.approx.ftz.f`
  (:673) and the four operations of the last loop (:724-727) are at float in all three files.

With `half` (`bfloat`) read as `float`, alignment 2 as 4 and the 11 conversions removed, the
float16 file is the float32 one, and the bfloat16 file is the float16 one with `bfloat` for
`half`. So the last loop computes in the accumulation format and converts on load and store, as
the source's casts say: the run at float16 is the binary32 run with exact conversions of the
three inputs and of epsilon, and one rounding at the store.

The plan, in order:

1. Parameters: the storage format `s : FloatTy` and the accumulation format `a` (`float` at
   `half`, `bfloat` and `float`; `double` at `double`), and the two conversions: `fpext` from
   `s` to `a`, exact on every number when `s` is `half` or `bfloat` (and the identity at
   `s = a`), with a NaN payload chosen by an oracle number (MojoProof/Sym/Payload.lean:104), and
   `fptrunc` from `a` to `s`, one rounding to nearest even at `s` (overflow to an infinity), also
   with a NaN payload by an oracle number. The block checker already summarizes both casts
   (MojoProof/Sym/Checker.lean:164-171); `Program.retype` (MojoProof/Sym/Formats.lean) does not
   apply, because the files add statements.
2. `lnVal` and `lnVal_cases`: the same definitions at `Model a.fmt` (a format parameter in
   place of `FloatTy.float`), with the Float32 ones their instances at `a = .float`.
3. `LnBytes`: the bytes at `s` of `fptrunc` of `lnVal` at the inputs' `fpext`s, for tensors of
   `Model s.fmt`; at `s = .float` the conversions are absent from the file and the bytes are
   today's.
4. `lnVal_error` and `LnBytes.error`: the error at `a` (today's `lnOut_error` at `a`) and one more
   relative error `u_s` (2^-11 at `half`, 2^-8 at `bfloat`) with the subnormal floor of `s` for
   the store, from FloatLib's rounding bound at `s`; the inputs' error is 0.
5. The round summaries (MojoProofTest/LnRound.lean) and the run (LnRun.lean): the blocks of the
   last loop at `s` have three more nodes (`fpext`) and one (`fptrunc`) per copy, their cells
   are `size s * k` for `4 * k`, and the obligations of each node are the same kind as today's.
   The run's statements take `s` and the program at `s` (its two copies of the loop body), and
   the oracle numbers of the four casts move the positions of the float operations.

Cost: steps 2 to 4 are definitions and lemmas at a format parameter (no new run); step 5 is the
run again at each 16-bit file (the obligation tactics evaluate the program's closed terms, as
"Plan" above says), about as large as the bs128 run. The two bs128 files are the instances the
plan uses, and the 16-bit runs are about them: they are in the corpus as
tests/corpus/ln16/test_layer_norm_rowwise_block_t0_r1_ax0_w1_bs128_c5012e49.nvptx.ll and
tests/corpus/lnbf16/test_layer_norm_rowwise_block_t0_r1_ax0_w1_bs128_ae9cae70.nvptx.ll (the line
numbers above are the first's), compiled from the copies of the source in those two directories.
No theorem is about them yet.
