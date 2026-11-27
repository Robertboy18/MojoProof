# `vector_addition` walks the path its index selects (`vadd_walk`, `mojo_obl`)

Lean: `MojoProof/Sym/OblLemmas.lean` (the lemmas) and `MojoProof/Sym/Obl.lean` (the tactic).
Tests: `MojoProofTest/Obl.lean`.

**Scope.** Every valid launch, alignment, pair of input buffers and output buffer of `n < 2 ^ 31`
floats that fit below `2 ^ 64`, thread `k`, and context, memory and frame with the facts below; on
one-dimensional launches the index is `k` (`vadd_walk_launch`). The goal is the walk along the path
the index selects, the first conjunct of `Ret` in `Kernel.sound_of_paths`; `mojo_ret` proves it
inside its `Ret` goals. The program, its summaries and paths are `Kernels.vadd.*`
(MojoProof/Kernels/Vadd.lean); the lemmas are for every valuation, program and table.

## Statement

`MojoProofTest.Obl.vadd_walk` (MojoProofTest/Obl.lean). For every `L : Launch` with `L.Valid`;
every `al`
with `4 ∣ al`; every `a b out n N` and tensors `x y` of `N` binary32 values with `a`, `b`, `out`
distinct, `n ≤ N`, `n < 2 ^ 31`; every `k < volume L.grid * volume L.block`; every `c : Ctx` with
`c.prog = Kernels.vadd.prog`, `c.env = L.env k`, `c.who = ⟨k, k / volume L.block⟩`; every memory
`m` and frame `f` with `f.fn = Kernels.vadd.fn_0`, registers `0, 1, 2` the pointers `⟨p0, 0⟩`,
`⟨p1, 0⟩`, `⟨p2, 0⟩` and register `3` the word of `n`; the byval loads at `p0`, `p1`, `p2` giving
the structs of `a`, `b`, `out`; `m.Buffer` of `n * 4` bytes at `a`, `b` (read-only) and `out`
(writable), aligned to `al`; `m.Holds` of `x` at `a` and `y` at `b`, row-major; and
`m.Fits l a (n * 4)` (`Mem.Fits`, MojoProof/Sem/Precond.lean), the same for `b` and `out`:

    (L.index k .x < n → WalkWith false (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 0 [])) ∧
    (¬ L.index k .x < n → WalkWith false (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 1 []))

`L.index k .x` is `ctaid.x * ntid.x + tid.x` of thread `k` (`Launch.index`), the value of `%19`,
which the kernel computes in `i64`, so it does not wrap. `MojoProofTest.Obl.vadd_walk_launch` is
the corollary with `L.grid .y = 1 ∧ L.grid .z = 1` and `L.block .y = 1 ∧ L.block .z = 1`, where
`L.index k .x = k` (`Launch.index_oneDim`), with `k < n` and `¬ k < n` in the two conjuncts.

Path 0 is `%4 → %21 → %31` (labels 4, 21, 31), path 1 is `%4 → %30 → %31` (labels 4, 22, 31).
`m.Fits l c s` is `∃ blk, m.blocks c = some blk ∧ blk.gaddr + s ≤ 2 ^ (l.ptr 0).1`; mojo_obl
unfolds it by one step of its head. The buffer lemmas take the pointer's address space `a`, 0 or
1, and the fact `(if a = 0 then blk.gaddr else blk.addr) + s ≤ 2 ^ (l.ptr a).1`: here `a = 0`,
so the fact is `Mem.Fits`'s.

## Proof

A (the walk). `WalkWith false V ((l, ds, S) :: (l', ds', S') :: ps)` is `∀ d ∈ ds, d.Holds V
(vals V S.nodes)`, then `S.exit.dest V (vals V S.nodes) = some l'`, then the walk of the rest from
`V.intoWith false l S` (`WalkWith.cons2`; `WalkWith.one`, `WalkWith.nil'` for the ends). On an
exit other than `Exit.phi`, `Exit.dest` is `Exit.target` and `V.intoWith false l S` is
`V.after S` (`Exit.of_targetWith`). So the proof is, per block, its obligations at its entry
valuation and its exit.

B (block `%4`, at `V = Valuation.entry c 0 m f`). The node values, in order:
nodes 0, 2, 4 are the byval loads at `p2`, `p1`, `p0`, whose values are the hypotheses' structs
(`SNode.eval_load_at`, the statement and its alignment by kernel `whnf`); nodes 1, 3, 5 their first
fields, the pointers `⟨out, 0⟩`, `⟨b, 0⟩`, `⟨a, 0⟩` (`SNode.eval_extract`); node 6 is
`sext 64` of the word of `n`, the word of `n` since `2 n < 2 ^ 32` (`intCast_sext_ofNat`); nodes
7, 9, 11 are `tid.x`, `ctaid.x`, `ntid.x`, the words of the registers of `L.env k`, which are in
the `range` attributes the declarations carry (`SNode.eval_sreg_at`, `withAttrs_ofNat`,
`Launch.sreg_bound`); nodes 8, 10, 12 their extensions to 64 bits, node 13 the product and node 14
the sum, the words of the natural numbers since the register bounds (`Launch.sreg_lt`) keep them
below `2 ^ 63` (`intCast_ofNat`, `intBin_mul_ofNat`, `intBin_add_ofNat`); node 15 is
`Val.ofBool (decide (ctaid.x * ntid.x + tid.x < n))` (`SNode.eval_icmp_slt_ofNat`, both sides
below `2 ^ 63`). The obligations: `ok` of each node from its value, `bool` of node 15 from
`Val.ofBool`, and the three load effects run, each logging its access (`SEff.apply_load_at`,
`SEff.foldlM_cons_ex`). The exit `cond (node 15) 21 22` goes to 21 when the comparison holds
(`Exit.target_cond_true`) and to 22 when it fails (`Exit.target_cond_false`); the sum is
`i = L.index k .x` (`Launch.index`, which the proof unfolds in `hkn`), so the comparison is
`i < n`, which `hkn` decides either way (`omega`). On a 1-D launch `i = k` (`Launch.index_oneDim`).

C (block `%21`, at `V₁ = V.after b0`, when `i < n`). The registers of `V₁` are `b0`'s node values
(`Valuation.after_regs_some`), its memory is `m` with three trace entries, with `m`'s blocks
(`Valuation.after_mem_fold`). Node 0 is `trunc 32` of the index and node 1 its `sext 64`, the
word of `i` since `i < n < 2 ^ 31`. Nodes 2, 4, 7 are `getelementptr inbounds float` from `⟨a, 0⟩`,
`⟨b, 0⟩`, `⟨out, 0⟩` by `i`: by `gep_buffer`, `⟨c, 4 i⟩`, since `4 i < 4 n` and the buffer fits,
so its address `gaddr + 4 i` does not reach `2 ^ 64` and the `inbounds` checks pass. Nodes 3 and 5
are the loads of element `i` of `a` and `b`, the floats `x i` and `y i` (`load_buffer`: `Mem.Holds`
with `rowMajor_one`, `Mem.load_holds`, alignment from `4 ∣ al ∣ gaddr`). Node 6 is the `fadd` of
them (`SNode.eval_fbin_ofFloat`). The obligations: each node's `ok`, and the effects (the two loads,
then the store of node 6 at node 7) run: the store's check passes on the writable buffer `out`
(`store_buffer`: `Mem.check_ok`, `Mem.write_of_check`, the float's encoding). The exit is `br 31`
(`Exit.target_br`).

D (blocks `%30` and `%31`). No nodes; the one obligation `mem []` runs (`SEff.foldlM_nil_ex`); `%30`
exits by `br 31`. `%31`'s exit (`ret`) is not part of `WalkWith`.

E (the twin, `vadd_walk_open`, MojoProofTest/Obl.lean). With `hkn : ¬ Below (L.index k .x) n`
and `Below` irreducible, step B's `omega` has no fact on the index, so the exit of `%4` stays open:
the logged goal is `Exit.dest (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f)
Kernels.vadd.b0.nodes) Kernels.vadd.b0.exit = some 22` (checked by `#guard_msgs`). After
`unfold Below Launch.index at hkn`, `mojo_obl` closes it. `vadd_walk_launch_open` is its corollary
on 1-D launches, with `hkn : ¬ Below k n`.

## Why the buffers must fit

Without `Mem.Fits`, the goal is false. `Mem.Buffer` bounds a block's size and alignment, not its
generic address `gaddr`. If `gaddr + 4 k ≥ 2 ^ 64` for some `k < n`, the `getelementptr inbounds`
of step C is `poison` (`gepPtr`'s `badS`, MojoProof/Sem/Eval.lean), the load through it faults, and
`%21`'s `mem` obligation fails. So the start facts include `Mem.Fits`; `addr_buffer` is where
they are used.

## Heartbeats

`vadd_walk_launch` took 42,217 heartbeats (Mathlib's `#count_heartbeats in`, in a scratch file),
of the default 200,000, when mojo_obl proved it directly; `vadd_walk` runs the same mojo_obl calls
after unfolding `Launch.index` (not measured again), and no option is set.

## The naive matrix product (`MojoProofTest/OblMatmul.lean`)

The same tactic on the naive matrix product `naive` (MojoProofTest/SymPhi.lean), which multiplies
a row-major `m × 768` matrix `A` by the transpose of a row-major `n × 768` matrix `B` into `C`, of
`m × 50257` cells of binary32, with `fmul contract` (the forms `WalkWith true`, `EdgeWith true`,
`RoundWith true` of MojoProof/Sym/Loop.lean). Thread `(r, c)`, `r = ctaid.x * ntid.x + tid.x` and
`c = ctaid.y * ntid.y + tid.y`, runs the loop `%46 → %50 → %52` (`naiveL`) when `r < m` and
`c < n`, and the path `%6 → %44 → %69` otherwise. Each theorem's premises are named; all five
are by `mojo_obl` alone.

* `naive_entry`: for every valid launch `L`, thread `k`, context `c` with `c.prog = naive.prog`
  and `c.env = L.env k`, memory `M` and frame `f` of `naive.fn_0` whose `%0`, `%1`, `%2` point at
  the byval structs of `bC`, `bA`, `bB` (`hv0`, `hv1`, `hv2`) and whose `%3`, `%4`, `%5` are the
  words of `m`, `n`, `K`, with `K ≤ 768`, `m * 50257 < 2 ^ 31`, `n ≤ 50257`, `M.Buffer bC
  (m * 50257 * 4) 4 true`, `M.Fits naive.prog.layout bC (m * 50257 * 4)`, `r < m` and `c < n`:
  `EdgeWith true naiveL.h naiveL.p (Valuation.entry c s M f) …` (the path `%6 → %45` into the
  header, `%16 = smax(K, 0)` the word of `max K 0`, `%40` the pointer to cell `50257 r + c`).
* `naive_rounds`: for `K ≤ 768`, `m * 768 < 2 ^ 31`, `n * 768 < 2 ^ 31`, `r < m`, `c < n`,
  `i < max K 0` and a valuation `W` of `naive`'s program and function with `%47 = i`,
  `%16 = max K 0`, `%48 = acc`, `%26 = 768 r`, `%37 = 768 c`, `%11`, `%12` at offset 0 of `bA`,
  `bB`, buffers of `768 m` and `768 n` binary32 that fit and hold `A` and `B`:
  `RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W`.
* `naive_exit`: for `K ≤ 768`, `r < m`, `c < 50257` and `W` with `%47 = %16 = max K 0`,
  `%48 = acc`, `%40` at cell `50257 r + c` of a writable buffer `bC` that fits:
  `WalkWith true W ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X)`.
* `naive_skip_row` (`m ≤ r`) and `naive_skip_col` (`r < m`, `n ≤ c`), with `naive_entry`'s other
  premises but `M.Fits`: `WalkWith true (Valuation.entry c s M f)` along `%6 → %44 → %69`. Out of
  range, the index arithmetic wraps: `%26`, `%27`, `%37`, `%38` are `mul` and `add` without `nuw`
  and `nsw`, so the word modulo `2 ^ 32` (`intBin_mul_wrap`, `intBin_add_wrap`); `%39` is the
  sign extension of a word that may be negative (`intCast_sext_bits`); `%40`, a
  `getelementptr inbounds` that may leave `C`, is some value, a pointer or poison
  (`gep_buffer_ok`), which the path does not use; the `select` `%43` is the word `1` when the row
  is out of range, and the branch goes to `%44` by its low bit (`Exit.target_cond`). These two
  are tests of mojo_obl only: no proof uses them, and the kernel theorem's run of a thread out of
  bounds is `NaiveSound.naive.out`, which the `mat` clause proves by mojo_obl at the 2-D index
  facts.

What it does not discharge: nothing of these paths under these premises. The premises are
the per-thread facts the kernel's theorem supplies: the registers at each round (the loop's
invariant), the buffers and their contents. The twin `naive_rounds_open` hides `%48` behind an
irreducible definition, and the latch's `fadd contract` obligation (node 13) is left open,
checked by `#guard_msgs`.

## gevm_kernel (`MojoProofTest/OblGevm.lean`)

The same tactic on `gevm_kernel` (`gevm` of MojoProofTest/SymLane.lean, the corpus file
gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll), which multiplies
the vector `x` of `K` binary32 (`%1`) by the row-major `K × N` matrix `B` (`%2`) into `y`
(`%0`). With `ntid.x = 1024`, thread `tid.x = 32 w + l` of block `β` runs the loop
`%39 → %43 → %45` (`gevmL`) for `i < %38 = ⌈K / 32⌉`, each round adding `x (32 i + w) ·
B (32 i + w, 32 β + l)` (`fmul contract`, `fadd contract`) to its accumulator `%41`. One
program, every launch. After the loop, `%59` stores the sum to cell `32 l + w` of a shared array,
waits at a barrier and sums cell `tid.x` across the warp by shuffles: only the statements before
the barrier are proved.

* `lane`: for every context `c` of `gevm`'s program with `c.env.laneid < 32`, register `%12`
  after `%6` is the word of `c.env.laneid` (`SNode.eval_laneid_at`), by `obl_have`.
* `entry_edge`: for every valid launch `L`, thread `k` with `ntid.x = 1024`, context `c` with
  `c.prog = gevm.prog` and `c.env = L.env k`, memory `M` and frame `f` of `gevm.fn_0` whose
  `%0` is the start of `p0` and whose `%4`, `%5` are the words of `N, K < 2 ^ 31`, with
  `M.Buffer p0 (N * 4) 4 true`, `M.Fits gevm.prog.layout p0 (N * 4)` and
  `32 ctaid.x + tid.x / 32 < N`: `EdgeWith true gevmL.h gevmL.p (Valuation.entry c s M f) …`,
  every obligation of the 32 nodes of `%6` and the edge into `%39` at position 2, by mojo_obl.
  The index arithmetic is LLVM's floor division by 32 and ceiling division by `-32`: `%22 =
  sdiv %21, 32` with the correction `%25 = xor %21, 32`, `%26 = ashr %25, 63`, `%27 = select
  %24, 0, %26` (two equal words, 0, so `eval_select_same`), and `%30 = sdiv %7, -32`, `%33 =
  xor %7, -32`, `%34 = ashr %33, 63` (all ones, a negative `xor`), `%35 = select %32, 0, %34`
  on an `icmp eq` of residues `omega` does not decide (`eval_icmp_eq_mod`, then
  `eval_select_word`: an `if`), `%37 = sub 0, %36`, `%38 = smax(%37, 0)`, whose bound `omega`
  proves after splitting the `if`.
* `entry_regs`: with those premises but `%4`'s, by `obl_have` and `omega`: `%17` is the word of
  `32 ctaid.x + laneid`, `%29` the pointer to element `32 ctaid.x + tid.x / 32` of `p0`, and
  `%38` the word of `(K + 31) / 32`.
* `rounds`: for every `K` with `K % 32 = 0` and `K < 2 ^ 31`, `N` with `K N < 2 ^ 29`, `w < 32`,
  `col < N`, `i < (K + 31) / 32`, and a valuation `W` of `gevm`'s program and function with
  `%40 = i`, `%38 = (K + 31) / 32`, `%41 = acc`, `%11 = w`, `%8 = N`, `%17 = col`, `%1`, `%2` at
  offset 0 of `bA`, `bB`, buffers of `K` and `K N` binary32 that fit and hold `A` and `B`:
  `RoundWith true gevmL.h gevmL.p gevmL.dh gevmL.H gevmL.B W`. The address of `B (32 i + w,
  col)` is `gep_buffer2` (an index `r * S + k` with `r < R`, `k < S` into a buffer of `R S`
  elements, `rowMajor_lt`), so `omega` never sees the product `(32 i + w) N`.
* `to_barrier`: for every context `c` of `gevm`'s program, step count, memory `m` and frame `f`
  of `gevm.fn_0` whose `%13`, `%11` are the 64-bit words of `l, w < 32` and `%60` a 32-bit word,
  with `c.globals` giving the shared array (`sharedName`) the pointer to offset 0 of `b`,
  `m.BufferIn 3 b 4096 4 (.cta g) true`, `(Owner.cta g).admits c.who = true` and `b`'s address in
  space 3 plus 4096 at most `2 ^ 32`: every obligation of `toBarrier`, the segment of `%59` from
  statement 1 to the barrier call at 6 (`summarizeTo`, MojoProof/Sym/Segment.lean, as a
  `Summary`), by mojo_obl: `%61 = %13 * 32`, `%62 = %61 + %11`, the `trunc` `%63` of
  `32 l + w < 2 ^ 32`, the array's pointer (`SNode.globalAt`, by `SNode.eval_globalAt_at` from
  the `c.globals` hypothesis), `%64` by `gep_buffer` in space 3, the `store` by `store_buffer`.
* `to_barrier_waits`: with those premises, for a thread whose top frame `f` is at statement 1 of
  `%59`, `summarizeTo` gives a segment `S` and the thread reaches the barrier's wait
  (`Waits`), by `Seg.sound` at `to_barrier`.
* `to_shfl`: for every such context, memory and frame whose `%10` is the 64-bit word of
  `x < 1024` (`tid.x`), with `m.Holds` of a vector `A` of 1024 binary32 in the shared buffer `b`:
  every obligation of `toShfl`, the segment from statement 7 (after the barrier) to the first
  shuffle at 11, by mojo_obl: the `trunc` `%65`, the array's pointer, `%66` by `gep_buffer` in
  space 3, the load `%67` of `A x` by `load_buffer`, `%68 = bitcast %67 to i32` by
  `SNode.eval_bitcast_at`, and the shuffle's arguments. `to_shfl_waits`: a thread at statement 7
  reaches that shuffle's wait, by `Seg.sound`.
* `shfl_round`: for every `j < 4` and frame whose `%(67 + 4 j)` and `%(69 + 4 j)` are binary32
  `y`, `z` with `f.prods (67 + 4 j) = none`: every obligation of `shflRound j`, the segment from
  statement `12 + 4 j` to the shuffle at `15 + 4 j`: the `bitcast` of `z`, the `fadd contract`
  by `SNode.eval_fbin_ofFloat` (the factors of `%(67 + 4 j)` from the hypothesis) and the
  `bitcast` of the sum. `shfl_round_waits`: a thread at statement `12 + 4 j` reaches the next
  shuffle's wait. The statements after the fifth shuffle (from 28) are not covered.

The twins, each checked by `#guard_msgs` and closed after `unfold`: `lane_open` (the lane bound
behind `LaneBelow`: node 6 of `%6` open), `entry_open` (`K < 2 ^ 31` behind `Below31`: the `sdiv`
`%30`, node 24, open), `rounds_open` (`K % 32 = 0` behind `Div32`: the load `%52` of
`x (32 i + w)`, node 6 of the latch, open) and `matrix_open` (`K N < 2 ^ 29` behind `Small`:
`gep_buffer2` does not apply to `%55`, so the load `%56` of `B`, node 10, has no address), and
`shared_open` (the shared array's pointer behind `SharedAt`: node 3 of `toBarrier` open),
`bitcast_open` (`%69` a word behind `Word32`: node 0 of `shflRound 0` open) and `factors_open`
(`f.prods 67 = none` behind `Unfactored`: the `fadd`, node 1 of `shflRound 0`, open). For
`K` not divisible by 32 the last round reads rows `32 i + w ≥ K`, out of `x` and `B`: the loop
has no guard (docs/proofs/gemv.md, "The specifications' premises").

The integer lemmas whose premises in `gevm_kernel` are literals or the launch's facts have their
twins on hand-written blocks of one to three nodes (MojoProofTest/OblInt.lean), each with one
premise behind an irreducible definition, a variable or another term, checked by `#guard_msgs`
and closed once it is given: `udiv_open` (`0 < b`), `sub_open` (the flags, a variable equal to
`{}`), `xor_open` (`b < 2 ^ w`), `ashr_pos_open` and `ashr_neg_open` (the sign of the `xor` an
`ashr` by 31 shifts), `select_same_open` (operands of one value), `select_word_open` and
`icmp_eq_mod_open` (a word of a number) and `int_negSucc_open` (`k < 2 ^ w` for `-(k + 1)`).

## The naive matrix product's threads out of bounds (`MojoProofTest/NaiveOut.lean`)

`runOut` proves `NaiveSpec.RunOut ω L K bC bA bB A B`, the per-thread premise of
`Kernel.sound_mapNWith` for the threads out of bounds, for every oracle `ω`, launch `L`, sizes
`m`, `n`, `K`, blocks `bC`, `bA`, `bB` and tensors `A`, `B`: every thread `k` with
`¬ NaiveSpec.S L m n k` whose entry facts are `NaiveSpec.At` (struct copies `p0`, `p1`, `p2`,
context `c`, memory `m'`, frame `f`), and whose memory `m'` meets `Elem` after `k` threads with
every access to `bC` by a thread in bounds (`Elem.Only bC (S L m n)`), runs `skipN`
(`%6 → %44 → %69`) to `ret` (`RetWith true`) with a memory that meets `Elem` after `k + 1`
threads and `Elem.Only bC (S L m n)`. `NaiveSpec` is unchanged: `At` has every fact the proof
uses.

The proof. `runOut` is `NaiveSound.naive.out`, the run of a thread out of bounds that the `mat`
clause of `mojo_kernel` generates (docs/kernel.md), at `At`'s facts (`NaiveSpec.At.entry`), the
sizes below `2 ^ 31` (`NaiveSpec.dims_lt`) and no bytes of a thread out of bounds
(`NaiveSpec.bytes_out`). The generated proof is `RetWith.of_first` (MojoProof/Sym/KernelMat.lean)
at `skipN`: the three path facts by `decide +kernel`, the blocks' premises (`WalkWith true`) by
`mojo_obl` at the thread's 2-D index facts, on each side of the row's bound, and the memory after
the entry block's three loads, none from `bC`, by mojo_ret's goals 1 and 3 with `Elem.skip`. An
`example` after `runOut` keeps those two goals on the same threads.

Scope: one program, `naive`, and every launch, size, block, tensor, memory, frame and thread
out of bounds. Concrete instance: `runsZ`, at the start `startZ` of `naive` on `launch2 1 1 2 2`
with `m = n = 0`, `K = 2` and `memZ` (three empty global buffers, `A` and `B` read-only), where
every thread is out of bounds. `atZ` proves `At` there for each of the four threads at the start's
context, memory and frame, and `runOut` with `Runs.of_retWith` gives each thread's run to its end
from the start's memory (`Runs`), with `Elem` and `Elem.Only` after it. The launch of
`NaiveThread.startN` (`memN`) does not meet `At`: its `C` has 4 bytes, not `m * 50257 * 4`, and
its `A` and `B` have 8 bytes, not `768 * 4`, and are writable. So `NaiveThread.skip_threads`,
which proves `Runs` at that launch, is not a corollary of `runOut`.

## The memory half of a loop's invariant (`mojo_inv`, `MojoProofTest/NaiveIn.lean`)

The plan. `NaiveIn.runIn` is `NaiveSound.naive.runInv` with three premises (`head_in`,
`round_in`, `exit_in`); each premise's memory facts are the invariant's memory half: the buffers
`bA`, `bB`, `bC` (`Mem.Buffer`, `Mem.Fits`, `Mem.Holds`), `Elem` after `k` threads and
`Elem.Only` at the loop head (then a field of the invariant). Without the tactic each step is by
hand: a lemma on two reads (`keep_log`), the blocks the round keeps (`hb`), and each buffer fact
moved by `Mem.Buffer.of_block`, `Mem.Fits.of_block` or `Mem.Holds.of_block`. (Since then the
`mat … inv` clause proves these facts at every head, `Mat.Head`, by mojo_inv at the loop head and
`Mat.Head.iterate`; docs/proofs/kernel.md, "The heads of the rounds".)

`mojo_inv` proves them for every program, from the facts at the memory where the path starts:

1. The memory after the path, `V.mem = M`: a hypothesis with that left side (as `obl_have`
   gives), else mojo_obl's evaluation (`Obl.memOf`, its effects run).
2. A path that only reads has `M` the start's memory `M₀` under `Mem.log`s of accesses, with
   `M₀`'s blocks (the kernel checks `M.blocks = M₀.blocks`). A buffer fact at `V.mem` is its
   hypothesis at `M₀` moved by the block lemma (`Mem.blocks_keep`).
3. `Elem` and `Elem.Only` at `V.mem` are their hypotheses at `M₀`, carried through each logged
   access to a block other than the output block, for `Elem` a read that is not an
   `atomicrmw`'s (`Elem.log_read`, `Elem.Only.log_other`): `omega` proves the access's block other than `out`, from the
   hypotheses (for the naive kernel `At.ne`: `bA ≠ bC`, `bB ≠ bC`).
4. A goal that is a structure of propositions, such as `Mat.Head`, is proved field by field: the
   function (`Obl.fnOf`), registers (`Inv.reg`, a hypothesis with the same left side first), their
   `fmul contract` operands (`Obl.prodOf`) and the memory facts above.

Then `head_in` and `round_in` proved the invariant's memory facts and registers by `mojo_inv`,
after the `obl_have` that names the registers and memory the rest of the proof uses, with no hand
memory step; their statements stayed. Now the `mat … inv` clause proves `Mat.Head` at the loop
head by `mojo_inv` and `naive.kept` gives the registers the loop keeps, so `head_in` and
`round_in` use mojo_inv only for `%48`'s `fmul contract` operands. Since the family
`NaiveFam.prog sA sB sC` (MojoProofTest/Family.lean), `head_in`, `round_in` and `exit_in` are
`head_inF`, `round_inF` and `exit_inF` of MojoProofTest/NaiveFamRun.lean at the corpus strides,
and those call mojo_inv as described here, at every row stride.
`exit_in`'s path stores the accumulator into the thread's cell; mojo_inv's store rule gives `Elem`
after one more thread and `Elem.Only` on the memory of the store's run (`SEff.apply`, or a block's
run of one effect by `SEff.run_one`): `Elem.apply_store` and `Elem.Only.apply`, the statement from
the function, the operands as mojo_obl evaluates them, the thread from the context's hypotheses,
and the value's encoding (`NaiveSpec.bytes`) by a hypothesis `exit_in` proves on `naive.prog`.
Its test is MojoProofTest/Inv.lean's `naive_store`. Not covered: a block of several effects with
a store, a write or an access to the output block other than the thread's store, and
`Mem.BufferIn`.

The run of one `store` effect is the semantics' store, as an equation: `SEff.run_store_eq`
(MojoProof/Sym/OblLemmas.lean) says that `SEff.run V vs [.store lbl pc v p]` is
`V.mem.store P.layout V.ctx.who a t x q (some (al.getD (P.layout.align t)))` when `V`'s function
is `F`, its program `P`, statement `pc` of block `lbl` is a store of a value of type `t` through a
pointer of space `a` with alignment `al`, and `v` and `p` evaluate to `x` and `.ptr q`. The audit
lists it as an equivalence of `SEff.run` and `Mem.store`; it is kept with an `unfold` row in
scripts/laws.tsv (`SEff.run` is a fold of `SEff.apply` over the effects and is the store in the
case the premises select), not hidden behind a premise that names the store's result.
`SEff.run_store_one` is its corollary for a run that gives a memory `M`. gemv_kernel's entry
(`GemvEntryRun.entry`, its three stores) and gevm_kernel's `%59` thread (`GevmLane.thread`, the
store to the shared array) take the equation and its `.trans` with the store's result.

Done as planned (`Inv.memFact`, MojoProofTest/Inv.lean's `naive_mem` and `naive_mem_open`).
`head_in`'s `obl_have` names only `%47` and `%48`, and mojo_inv evaluated the registers and
operands of the facts at the loop head (then a structure in the invariant; now the clause's
`Mat.Head` and `naive.kept`) itself. `round_in`'s `obl_have` names `%47`, `%48` (the latch's
`fadd contract` on the symbolic accumulator, by mojo_obl's evaluator) and the memory after the
round, and mojo_inv evaluated the other registers and the operands after the round. The counts
below are of that `round_in`. Three things kept it well inside
the default heartbeat limit (`#count_heartbeats`, of 200,000): mojo_inv builds the proof
unchecked and has the kernel check it once (`Inv.run`; with each field's proof checked on its
own, `Obl.attempt`, `round_in` took 234,057, and with the one check 190,845); mojo_obl's state
keeps each edge's `phi` operands and their values for the whole run, so the registers no `phi`
sets pass each edge by `Valuation.intoWith_regs_phi_ne` without evaluating an operand (161,860);
and the memory after the round comes from the same `obl_have` run as `%48` and shares its
evaluation of the latch's nodes, which mojo_inv's first memory field otherwise repeats (about
50,000 heartbeats): 114,261. Since mojo_obl evaluates a node only when it is read, once
(`Obl.nodeVal`), the memory after a block evaluates only the nodes its effects read, the
addresses of the latch's loads and not its float nodes: without the memory in `obl_have`,
`round_in` takes 119,566 (162,079 when every node of a block was evaluated), and with it 114,268.
With the function and the memory facts out of the invariant (the clause proves `Mat.Head` at
every head), `round_in` took 76,581 and `head_in` 5,992, before `naive.kept`.
