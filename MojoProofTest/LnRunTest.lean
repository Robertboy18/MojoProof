import MojoProofTest.LnRun
import MojoProofTest.FloatNorm

/-!
# Layer norm's last loop at one memory: threads 43, 44 and 45 of a row of 300 floats

Tests of one program, layer norm at block size 128 (MojoProofTest/SymSeg.lean's `ln`,
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll):
MojoProofTest/LnRun.lean's `run_entry`, from `%453`'s branch into the loop (:675) to `%534`
(:774), with every premise proved, at a constructed context, thread, frame and memory.

* `put`, `mem s X G Bt`: for every row length `n`, output size `s` and rows `X`, `G`, `Bt` of `n`
  binary32 words, the memory built from the empty one with blocks 1, 2 and 3 read-only holding
  `X`, `G` and `Bt` (`tensorBytes`) and block 4 a writable output of `s` undefined words, all
  global, live, owned by all threads, at addresses `16 n`, `32 n`, `48 n` and `64 n` in space 1
  and in the generic space (so the four buffers of `4 n` bytes do not overlap).
* `ctx tid`, `regs`, `frame`, `thread`: thread `tid` of one block of 128 threads (`launch2`); a
  frame of layer norm's function at `%453`'s statement 21 with exactly the registers `run_entry`
  reads (the thread index, `%65 = n`, the mean `%460` and inverse deviation `%464` as `mu` and
  `rs`, and the pointers `%466`, `%467`, `%468`, `%70` to blocks 4, 2, 3 and 1).
* `run_mem`: `run_entry` at that state, for every `n < 2 ^ 32`, thread `tid < 128`, rows, `mu`
  and `rs`. Every premise is proved there for every row length and tensor: the buffers and their
  fits by `Mem.allocs_spec` (alignment 16, which 4 divides), the tensors by `Mem.holds_alloc`,
  the registers by evaluation.
* `run_300`: `run_mem` at `n = 300` with `lnStores 128 300 tid` evaluated: thread 43 writes floats
  43, 171 and 299; thread 44 floats 44 and 172 (its third round's float 300 is one past the row);
  thread 45 floats 45 and 173 (its third round's float 301 is past the buffer, where the
  `getelementptr inbounds` of :700 is poison, MojoProofTest/LnGep.lean's `ln_gep_past`); in both
  the guard (:708) is false there and the round has no access.
* `run_floats`: for every `n < 2 ^ 32`, thread `tid < 128`, rows, `mu` and `rs`, the final
  blocks other than 4 are `mem`'s, block 4's bytes at every float outside `lnStores 128 n tid` are
  `mem`'s, and those at each float `k` of `lnStores 128 n tid` are those of a value `lnVal` of
  `X[k]`, `G[k]`, `Bt[k]`, `mu` and `rs` (`LnBytes`, `LnOut.read`, `lnStores_nodup`), which, if
  finite, is within `lnErr` of the real `(X[k] - μ₀) · w · G[k] + Bt[k]` when `mu` is within `e`
  of `μ₀` and `rs` within relative error `κ` of `w` (`LnBytes.error`); `float_43` is its instance
  at `n = 300`, thread 43 and float 43, with `run_mem`'s final frame at `%534` and its trace
  (`LnTrace` at floats 43, 171 and 299).
* `row`, `run_lnorm`: for every `n < 2 ^ 32`, thread `tid < 128`, rows, reduction tree `t`, word
  `ε` and oracle number `q`, with the registers `mu` and `rs` the float library's Welford mean
  word and `Sem.rsqrt (wvar t (row X) + ε) q` (MojoProof/Float/Norm.lean), each float the thread
  stores is, if finite, `lnorm t (row X) (row G) (row Bt) ε q fused k`, fused or not.
* `run_torch`: `run_lnorm` and `MojoProof.Float.lnorm_error`. For `n ≤ 2 ^ 24`, a tree whose
  leaves are the row's indices up to order, `X` within `Bd` in magnitude, `ε > 0` and
  `lnorm_error`'s premises on the words of `row X`, each float the thread stores is, if finite,
  within FloatLib's mixed error `(u, lnErr …)` of TorchLean's real layer norm
  `TorchLean.TransformerBlock.layerNorm G Bt ε X` at its index.
* `ofRow`, `row_ofRow`, `torch_iota`: the tensor of given words, which `row` reads back, and
  `run_torch` with every premise proved at one example: thread 0, `X = 1, 2, 3, 4`, `G = 1`,
  `Bt = 0`, the tree `halveFin 2`, `ε = 2.75` and one oracle number.
* `lnVal_two`: at one input (`x = 1 + 2⁻²³`, `g = 1 - 2⁻²³`, `bt = -1`, `mu = 0`, `rs = 1`) the
  unfused float (`o = 0`) is `+0` and the fused one (`o = 1`) `-2⁻⁴⁶`, both finite.
* `lnVal_inf`: at one input (`x = 2^127`, `g = 2`, `bt = -(2^128 - 2^104)`, `mu = 0`, `rs = 1`)
  the separately rounded product `%502` is `+Inf` and the unfused float (`o = 0`) is not finite,
  while the fused one (`o = 1`) is `2^104`, finite.
* `log_blind`: for every memory and event, `LnOut y R []` holds after logging the event (a write
  outside `y`, say) and `LnTrace` at `[]` does not: `LnOut` constrains only the blocks.
* `short`: the mutant memory whose output has 299 words fails `run_entry`'s premise on `y`.

Tests of one program at the sizes named; `run_mem`, `run_floats`, `run_lnorm` and `run_torch`
cover every row length (`run_torch` up to `2 ^ 24`), thread and tensor; `torch_iota` is one
example.
-/

namespace MojoProofTest.LnRunTest

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymSeg
open MojoProofTest.LnRun
open FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.GPUProof.ViewStride (lnStores lnStores_nodup)
open scoped BigOperators

/-- `m` with one more block: a global, live, read-only block of `n` binary32 words holding `T`
(`tensorBytes`), owned by all threads, at address `16 a` in space 1 and in the generic space, for
every memory, row length, address and row. A test definition. -/
def put {n : Nat} (m : Mem) (a : Nat) (T : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) : Mem :=
  (m.alloc ln.prog.layout 1 (TorchLean.Shape.size [n] * ln.prog.layout.size (.fp .float)) 16 true
    true .all a a (tensorBytes ln.prog.layout (.fp .float) (Val.ofFloat .float) T)).1

/-- Layer norm's caller memory, for every row length `n`, output size `s` and rows `X`, `G`,
`Bt`: from the empty memory, blocks 1, 2 and 3 holding `X`, `G` and `Bt` (`put`) at addresses
`16 n`, `32 n` and `48 n`, and block 4 a writable global output of `s` undefined words at `64 n`.
A test definition. -/
def mem {n : Nat} (s : Nat) (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) : Mem :=
  ((put (put (put {} n X) (2 * n) G) (3 * n) Bt).alloc ln.prog.layout 1
    (s * ln.prog.layout.size (.fp .float)) 16 true false .all (4 * n) (4 * n)).1

/-- Thread `tid`'s context at one block of 128 threads: layer norm's program, no globals, thread
`tid` of block 0, every skeleton and oracle choice 0. A test definition. -/
def ctx (tid : Nat) : Ctx :=
  ⟨ln.prog, fun _ => none, (launch2 1 1 128 1).env tid, ⟨tid, 0⟩, fun _ => 0, fun _ => 0⟩

/-- The registers at `%453`'s branch that `run_entry` reads, and no other: the thread index `%24`
(register 24), the row length `%65` (67), the mean `%460` (462), the inverse deviation `%464`
(466), and the pointers `%466` (468, block 4), `%467` (469, block 2), `%468` (470, block 3) and
`%70` (72, block 1), for every row length, thread, `mu` and `rs`. A test definition. -/
def regs (n tid : Nat) (mu rs : Model FloatTy.float.fmt) : Nat → Option Val
  | 24 => some (.bits 64 (BitVec.ofNat 64 tid))
  | 67 => some (.bits 64 (BitVec.ofNat 64 n))
  | 462 => some (.ofFloat .float mu)
  | 466 => some (.ofFloat .float rs)
  | 468 => some (.ptr ⟨4, 0⟩)
  | 469 => some (.ptr ⟨2, 0⟩)
  | 470 => some (.ptr ⟨3, 0⟩)
  | 72 => some (.ptr ⟨1, 0⟩)
  | _ => none

/-- The frame at `%453`'s branch (statement 21, :675): `ln.fn_0`, the registers `regs`, no
recorded product, no `alloca` block, no caller register. A test definition. -/
def frame (n tid : Nat) (mu rs : Model FloatTy.float.fmt) : Frame :=
  ⟨ln.fn_0, ln.fn_0.b_42.label, 21, regs n tid mu rs, fun _ => none, [], none⟩

/-- The thread: the one frame `frame`, no step taken. A test definition. -/
def thread (n tid : Nat) (mu rs : Model FloatTy.float.fmt) : Thread :=
  ⟨[frame n tid mu rs], 0⟩

/-- **`run_entry` at a constructed state.** Layer norm (the corpus file) at block size 128, for
every row length `n < 2 ^ 32`, thread `tid < 128` of one block of 128 threads (`ctx`), rows `X`,
`G`, `Bt`, `mu` and `rs`: from `thread` and `mem n X G Bt`, the thread's steps reach `%534`'s
first statement (:774) in its one frame, and the memory's trace (newest first) is `mem`'s with
thread `tid`'s accesses of the rounds at `lnStores 128 n tid` in front, newest first (`LnTrace`,
reads of blocks 1, 2 and 3 and writes of block 4) and its blocks are `mem`'s with the bytes of a
value `lnVal` of `X[k]`, `G[k]`, `Bt[k]`, `mu` and `rs` put at each of those floats `k` of block 4
(`LnOut` at `LnBytes`). Every premise of `run_entry` proved for every row length and tensor. A run
theorem (IR :675-774); `mu` and `rs` are given registers. -/
theorem run_mem {n tid : Nat} (hn : n < 2 ^ 32) (ht : tid < 128)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) (mu rs : Model FloatTy.float.fmt) :
    ∃ t' m' f', Steps (ctx tid) (thread n tid mu rs) (mem n X G Bt) t' m' ∧ t'.frames = [f'] ∧
      f'.fn = ln.fn_0 ∧ f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = none ∧
      LnOut 4 (LnBytes X G Bt mu rs) (lnStores 128 n tid) (mem n X G Bt) m' ∧
      LnTrace ⟨tid, 0⟩ 4 2 3 1 (lnStores 128 n tid) (mem n X G Bt) m' := by
  have h4 : ln.prog.layout.size (.fp .float) = 4 := rfl
  have hw0 : (ln.prog.layout.ptr 0).1 = 64 := rfl
  have hw1 : (ln.prog.layout.ptr 1).1 = 64 := rfl
  have hv : ∀ v : Model FloatTy.float.fmt, (Val.ofFloat .float v).NamesIn fun _ => False :=
    fun _ => by simp [Val.NamesIn, Val.ofFloat]
  have h := Mem.allocs_spec ln.prog.layout 16
    ![TorchLean.Shape.size [n] * ln.prog.layout.size (.fp .float),
      TorchLean.Shape.size [n] * ln.prog.layout.size (.fp .float),
      TorchLean.Shape.size [n] * ln.prog.layout.size (.fp .float),
      n * ln.prog.layout.size (.fp .float)] ![true, true, true, false]
    (I := ![tensorBytes ln.prog.layout (.fp .float) (Val.ofFloat .float) X,
      tensorBytes ln.prog.layout (.fp .float) (Val.ofFloat .float) G,
      tensorBytes ln.prog.layout (.fp .float) (Val.ofFloat .float) Bt, []])
    (fun i p j hp => by
      fin_cases i <;> simp at hp
      exacts [tensorBytes_namesIn hv X p j hp, tensorBytes_namesIn hv G p j hp,
        tensorBytes_namesIn hv Bt p j hp])
    (A := ![n, 2 * n, 3 * n, 4 * n]) (G := ![n, 2 * n, 3 * n, 4 * n]) (n := fun _ => n * 4)
    (fun i => by fin_cases i <;> simp [TorchLean.Shape.size, h4])
    (fun i => by fin_cases i <;> simp [hw1] <;> omega)
    (fun i => by fin_cases i <;> simp [hw0] <;> omega)
  have al : ∀ {q k : Nat} {w : Bool}, (mem n X G Bt).Buffer q k 16 w →
      (mem n X G Bt).Buffer q k 4 w :=
    fun ⟨b, hb, hs, hl, ho, hr, hk, ha, hg⟩ =>
      ⟨b, hb, hs, hl, ho, hr, hk, dvd_trans (by decide) ha, dvd_trans (by decide) hg⟩
  have hc := Layout.Codec.float ln.prog.layout .float
  obtain ⟨bx, hbx, hx⟩ := Mem.holds_alloc hc X ({} : Mem) 1 16 true true .all n n
  obtain ⟨bg, hbg, hg⟩ := Mem.holds_alloc hc G (put {} n X) 1 16 true true .all (2 * n) (2 * n)
  obtain ⟨bb, hbb, hb⟩ := Mem.holds_alloc hc Bt (put (put {} n X) (2 * n) G) 1 16 true true .all
    (3 * n) (3 * n)
  exact run_entry (n := n) (tid := tid) (y := 4) (g := 2) (b := 3) (x := 1) (X := X) (G := G)
    (Bt := Bt) (mu := mu) (rs := rs) (c := ctx tid) (t := thread n tid mu rs)
    (m := mem n X G Bt) (f := frame n tid mu rs) (rest := [])
    rfl (by omega) hn (by decide) (by decide) (by decide) rfl rfl rfl rfl rfl rfl rfl rfl rfl rfl
    rfl rfl rfl rfl (al (h.2 3).1) (al (h.2 1).1) (al (h.2 2).1) (al (h.2 0).1) (h.2 3).2
    (h.2 1).2 (h.2 2).2 (h.2 0).2 ⟨bx, hbx, hx⟩ ⟨bg, hbg, hg⟩ ⟨bb, hbb, hb⟩

/-- **Threads 43, 44 and 45 of a row of 300 floats.** Layer norm (the corpus file) at block size
128, `n = 300`, for every rows `X`, `G`, `Bt`, `mu` and `rs`, at `mem 300 X G Bt` (`run_mem`):
thread 43's rounds write floats 43, 171 and 299 of block 4, thread 44's floats 44 and 172, and
thread 45's floats 45 and 173, each round after its reads of blocks 1, 2 and 3 there (`LnTrace`),
and the final blocks have the bytes of `lnVal` at those floats put there (`LnOut` at `LnBytes`).
`lnStores 128 300 tid` by evaluation. A run theorem at one row length, three threads and every row
of that length. -/
theorem run_300 (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [300])
    (mu rs : Model FloatTy.float.fmt) :
    (∃ t' m' f', Steps (ctx 43) (thread 300 43 mu rs) (mem 300 X G Bt) t' m' ∧
      t'.frames = [f'] ∧ f'.fn = ln.fn_0 ∧ f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧
      f'.dest = none ∧ LnOut 4 (LnBytes X G Bt mu rs) [43, 171, 299] (mem 300 X G Bt) m' ∧
      LnTrace ⟨43, 0⟩ 4 2 3 1 [43, 171, 299] (mem 300 X G Bt) m') ∧
    (∃ t' m' f', Steps (ctx 44) (thread 300 44 mu rs) (mem 300 X G Bt) t' m' ∧
      t'.frames = [f'] ∧ f'.fn = ln.fn_0 ∧ f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧
      f'.dest = none ∧ LnOut 4 (LnBytes X G Bt mu rs) [44, 172] (mem 300 X G Bt) m' ∧
      LnTrace ⟨44, 0⟩ 4 2 3 1 [44, 172] (mem 300 X G Bt) m') ∧
    (∃ t' m' f', Steps (ctx 45) (thread 300 45 mu rs) (mem 300 X G Bt) t' m' ∧
      t'.frames = [f'] ∧ f'.fn = ln.fn_0 ∧ f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧
      f'.dest = none ∧ LnOut 4 (LnBytes X G Bt mu rs) [45, 173] (mem 300 X G Bt) m' ∧
      LnTrace ⟨45, 0⟩ 4 2 3 1 [45, 173] (mem 300 X G Bt) m') := by
  have e : lnStores 128 300 43 = [43, 171, 299] ∧ lnStores 128 300 44 = [44, 172] ∧
      lnStores 128 300 45 = [45, 173] := by decide
  exact ⟨e.1 ▸ run_mem (by decide) (by decide) X G Bt mu rs,
    e.2.1 ▸ run_mem (by decide) (by decide) X G Bt mu rs,
    e.2.2 ▸ run_mem (by decide) (by decide) X G Bt mu rs⟩

/-- **Block 4 at the end: every float a thread writes, named, and its error.** Layer norm (the
corpus file) at block size 128, for every row length `n < 2 ^ 32`, thread `tid < 128` of one block
of 128 threads (`ctx`), rows `X`, `G`, `Bt`, `mu` and `rs`, and reals `μ₀`, `w`, `e`, `κ` with
`mu` within `e` of `μ₀` and `rs` within relative error `κ` of `w`: from `thread` and
`mem n X G Bt`, whose block 4 is `B₀`, the thread's steps reach a memory (`run_mem`) whose other
blocks are `mem`'s and whose block 4 `B` (by `LnOut.read` with `lnStores_nodup`):
* has `B₀`'s bytes at every float `k` not in `lnStores 128 n tid`;
* has, at each float `k` of `lnStores 128 n tid`, the binary32 bytes of
  `lnVal X[k] G[k] Bt[k] mu rs` under some oracle numbers (`LnBytes`), a float that, if finite,
  is within `lnErr` of `(X[k] - μ₀) · w · G[k] + Bt[k]` (`LnBytes.error`).

A run theorem (IR :675-774) at every row length, thread and float; the accuracy of `mu` and `rs`
is the premise. -/
theorem run_floats {n tid : Nat} (hn : n < 2 ^ 32) (ht : tid < 128)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) (mu rs : Model FloatTy.float.fmt)
    {μ₀ w e κ : ℝ} (hμ : |mu.toReal - μ₀| ≤ e)
    (hr : FloatLib.Numerics.MixedError rs.toReal w κ 0) :
    ∃ t' m', Steps (ctx tid) (thread n tid mu rs) (mem n X G Bt) t' m' ∧
      ∃ B₀ B, (mem n X G Bt).blocks 4 = some B₀ ∧ m'.blocks 4 = some B ∧
        (∀ q, q ≠ 4 → m'.blocks q = (mem n X G Bt).blocks q) ∧
        (∀ k, k ∉ lnStores 128 n tid → B.read (4 * k) 4 = B₀.read (4 * k) 4) ∧
        ∀ k ∈ lnStores 128 n tid, LnBytes X G Bt mu rs k (B.read (4 * k) 4) ∧
          ∃ hk : k < n, ∃ v : Model FloatTy.float.fmt,
          ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some (B.read (4 * k) 4) ∧
          (v.isFinite = true → FloatLib.Numerics.MixedError v.toReal
            (((TorchLean.Tensor.Rep.get X (⟨k, hk⟩, ())).toReal - μ₀) * w *
                (TorchLean.Tensor.Rep.get G (⟨k, hk⟩, ())).toReal +
              (TorchLean.Tensor.Rep.get Bt (⟨k, hk⟩, ())).toReal)
            (Model.unitRoundoffAt FloatTy.float.fmt)
            (MojoProof.Float.lnErr (Model.unitRoundoffAt FloatTy.float.fmt)
              (Model.underflowErrorAt FloatTy.float.fmt) e κ w
              (TorchLean.Tensor.Rep.get G (⟨k, hk⟩, ())).toReal
              ((TorchLean.Tensor.Rep.get X (⟨k, hk⟩, ())).toReal - μ₀))) := by
  obtain ⟨t', m', -, hS, -, -, -, -, -, hO, -⟩ := run_mem hn ht X G Bt mu rs
  obtain ⟨B₀, hB₀⟩ : ∃ B₀, (mem n X G Bt).blocks 4 = some B₀ := ⟨_, rfl⟩
  obtain ⟨B, hB, hin, hout⟩ := hO.read LnBytes.length (lnStores_nodup (by decide) n tid) hB₀
  exact ⟨t', m', hS, B₀, B, hB₀, hB, hO.1, hout,
    fun k hk => ⟨hin k hk, (hin k hk).error hμ hr⟩⟩

/-- **The float thread 43 writes first, named, and its error.** Layer norm (the corpus file) at
block size 128, `n = 300`, for every rows `X`, `G`, `Bt`, `mu` and `rs` and reals `μ₀`, `w`, `e`,
`κ` with `mu` within `e` of `μ₀` and `rs` within relative error `κ` of `w`, at `mem 300 X G Bt`:
thread 43's steps reach `%534`'s first statement (:774) in its one frame `f'` (`ln.fn_0`, no
caller register), the final trace is `mem`'s with the accesses of the rounds at floats 43, 171
and 299 in front, newest first (`LnTrace`), and the final block 4 has, at float 43, the binary32
bytes of `lnVal X[43] G[43] Bt[43] mu rs` under some oracle numbers (`LnBytes`), a float that, if
finite, is within `lnErr` of `(X[43] - μ₀) · w · G[43] + Bt[43]`. `run_mem` at `n = 300` and
thread 43 (`lnStores 128 300 43 = [43, 171, 299]` by evaluation), with `run_floats`' step at float
43 (`LnOut.read`, `LnBytes.error`). By `lnVal_cases` the float is, up to NaN payloads, the fused
`fma p G[43] Bt[43]` or the unfused `p * G[43] + Bt[43]`, `p` the rounded `(X[43] - mu) * rs`. A
run theorem at one row length, one thread and one float; the accuracy of `mu` and `rs` is the
premise. -/
theorem float_43 (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [300])
    (mu rs : Model FloatTy.float.fmt) {μ₀ w e κ : ℝ} (hμ : |mu.toReal - μ₀| ≤ e)
    (hr : FloatLib.Numerics.MixedError rs.toReal w κ 0) :
    ∃ t' m' f', Steps (ctx 43) (thread 300 43 mu rs) (mem 300 X G Bt) t' m' ∧
      t'.frames = [f'] ∧ f'.fn = ln.fn_0 ∧ f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧
      f'.dest = none ∧ LnTrace ⟨43, 0⟩ 4 2 3 1 [43, 171, 299] (mem 300 X G Bt) m' ∧
      ∃ B, m'.blocks 4 = some B ∧ LnBytes X G Bt mu rs 43 (B.read (4 * 43) 4) ∧
        ∃ v : Model FloatTy.float.fmt,
          ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some (B.read (4 * 43) 4) ∧
          (v.isFinite = true → FloatLib.Numerics.MixedError v.toReal
            (((TorchLean.Tensor.Rep.get X (⟨43, by decide⟩, ())).toReal - μ₀) * w *
                (TorchLean.Tensor.Rep.get G (⟨43, by decide⟩, ())).toReal +
              (TorchLean.Tensor.Rep.get Bt (⟨43, by decide⟩, ())).toReal)
            (Model.unitRoundoffAt FloatTy.float.fmt)
            (MojoProof.Float.lnErr (Model.unitRoundoffAt FloatTy.float.fmt)
              (Model.underflowErrorAt FloatTy.float.fmt) e κ w
              (TorchLean.Tensor.Rep.get G (⟨43, by decide⟩, ())).toReal
              ((TorchLean.Tensor.Rep.get X (⟨43, by decide⟩, ())).toReal - μ₀))) := by
  obtain ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO, hT⟩ :=
    run_mem (tid := 43) (by decide) (by decide) X G Bt mu rs
  have e43 : lnStores 128 300 43 = [43, 171, 299] := by decide
  obtain ⟨B₀, hB₀⟩ : ∃ B₀, (mem 300 X G Bt).blocks 4 = some B₀ := ⟨_, rfl⟩
  obtain ⟨B, hB, hin, -⟩ := hO.read LnBytes.length (lnStores_nodup (by decide) 300 43) hB₀
  have h43 : 43 ∈ lnStores 128 300 43 := by rw [e43]; decide
  obtain ⟨_, v, he, hv⟩ := (hin 43 h43).error hμ hr
  exact ⟨t', m', f', hS, h1, h2, h3, h4, h5, e43 ▸ hT, B, hB, hin 43 h43, v, he, hv⟩

-- `float_43` at 01391ef: `float_43` without its final frame and trace conjuncts.
example (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [300])
    (mu rs : Model FloatTy.float.fmt) {μ₀ w e κ : ℝ} (hμ : |mu.toReal - μ₀| ≤ e)
    (hr : FloatLib.Numerics.MixedError rs.toReal w κ 0) :
    ∃ t' m', Steps (ctx 43) (thread 300 43 mu rs) (mem 300 X G Bt) t' m' ∧
      ∃ B, m'.blocks 4 = some B ∧ LnBytes X G Bt mu rs 43 (B.read (4 * 43) 4) ∧
        ∃ v : Model FloatTy.float.fmt,
          ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some (B.read (4 * 43) 4) ∧
          (v.isFinite = true → FloatLib.Numerics.MixedError v.toReal
            (((TorchLean.Tensor.Rep.get X (⟨43, by decide⟩, ())).toReal - μ₀) * w *
                (TorchLean.Tensor.Rep.get G (⟨43, by decide⟩, ())).toReal +
              (TorchLean.Tensor.Rep.get Bt (⟨43, by decide⟩, ())).toReal)
            (Model.unitRoundoffAt FloatTy.float.fmt)
            (MojoProof.Float.lnErr (Model.unitRoundoffAt FloatTy.float.fmt)
              (Model.underflowErrorAt FloatTy.float.fmt) e κ w
              (TorchLean.Tensor.Rep.get G (⟨43, by decide⟩, ())).toReal
              ((TorchLean.Tensor.Rep.get X (⟨43, by decide⟩, ())).toReal - μ₀))) := by
  obtain ⟨t', m', -, hS, -, -, -, -, -, -, h⟩ := float_43 X G Bt mu rs hμ hr
  exact ⟨t', m', hS, h⟩

/-- The words of a row `T` of `n` binary32 words, by index (`TorchLean.Tensor.Rep.get`), for every
row length and row. A test definition. -/
def row {n : Nat} (T : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) : Fin n → Model .binary32 :=
  fun j => TorchLean.Tensor.Rep.get T (j, ())

/-- **Given the float library's statistics, the floats a thread writes are its layer norm
words.** Layer norm (the corpus file) at block size 128, for every row length `n < 2 ^ 32`, thread
`tid < 128` of one block of 128 threads (`ctx`), rows `X`, `G`, `Bt`, reduction tree `t` over the
row's indices, word `ε` and oracle number `q`, with the mean register `%460` (:666) the Welford
mean word `(welford t (row X)).2.1` and the inverse deviation `%464` (:670) the word
`Sem.rsqrt (wvar t (row X) + ε) q`: from `thread` and `mem n X G Bt` the thread's steps reach a
memory whose block 4 has, at each float `k` of `lnStores 128 n tid`, the binary32 bytes of a
float that, if finite, is MojoProof/Float/Norm.lean's `lnorm t (row X) (row G) (row Bt) ε q fused
k`, fused or not (`LnOut.read`, `lnVal_finite`). A run theorem (IR :675-774) at every row length,
thread, tree, `ε` and `q`; that the two registers hold these words is the premise (the code
before :675, which computes them, is not run). -/
theorem run_lnorm {n tid : Nat} (hn : n < 2 ^ 32) (ht : tid < 128)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n])
    (t : FloatLib.Numerics.ReductionTree (Fin n)) (ε : Model .binary32) (q : Nat) :
    ∃ t' m', Steps (ctx tid) (thread n tid (MojoProof.Float.welford t (row X)).2.1
        (MojoProof.Sem.rsqrt (Model.add (MojoProof.Float.wvar t (row X)) ε) q))
        (mem n X G Bt) t' m' ∧
      ∃ B, m'.blocks 4 = some B ∧ ∀ k ∈ lnStores 128 n tid, ∃ hk : k < n,
        ∃ v : Model FloatTy.float.fmt,
          ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some (B.read (4 * k) 4) ∧
          (v.isFinite = true → ∃ fused,
            v = MojoProof.Float.lnorm t (row X) (row G) (row Bt) ε q fused ⟨k, hk⟩) := by
  obtain ⟨t', m', -, hS, -, -, -, -, -, hO, -⟩ := run_mem hn ht X G Bt _ _
  obtain ⟨B₀, hB₀⟩ : ∃ B₀, (mem n X G Bt).blocks 4 = some B₀ := ⟨_, rfl⟩
  obtain ⟨B, hB, hin, -⟩ := hO.read LnBytes.length (lnStores_nodup (by decide) n tid) hB₀
  refine ⟨t', m', hS, B, hB, fun k hk => ?_⟩
  obtain ⟨hk', d₀, d₁, d₂, o, he⟩ := hin k hk
  exact ⟨hk', _, he, fun h => ⟨o % 3 == 1, lnVal_finite h⟩⟩

-- FloatLib's `unitRoundoffAt` and `underflowErrorAt` are powers `bpow 2 e`, and Mathlib v4.36.0
-- exposes `Real`'s operations to files outside the module system: a premise about these reals
-- in weak head normal form would unfold the powers past the default recursion limit. `bpow` is
-- irreducible here, so it is not unfolded.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **Given the float library's statistics, the floats a thread writes against TorchLean's layer
norm.** `run_lnorm` and `MojoProof.Float.lnorm_error`: layer norm (the corpus file) at block size
128, for every row length `n ≤ 2 ^ 24`, thread `tid < 128`, rows `X` within `Bd` in magnitude,
`G` and `Bt`, tree `t` whose leaves are the row's indices up to order, word `ε > 0` and oracle
number `q`, under `lnorm_error`'s premises on the words of `row X` (the Welford words and the
variance word finite, `wvar + ε` finite, positive and normal, and `u + lnDev … / (V + ε) < 1`),
with the registers as in `run_lnorm`: each float `k` of `lnStores 128 n tid` the thread stores,
if finite, is within FloatLib's mixed error `(u, lnErr …)` of TorchLean's real layer norm
`TorchLean.TransformerBlock.layerNorm G Bt ε X` at `k`. A run theorem (IR :675-774) at every row
length up to `2 ^ 24`, thread and tree; that the two registers hold the Welford words is the
premise (the code before :675 is not run). -/
theorem run_torch {n tid : Nat} (ht : tid < 128)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n])
    (t : FloatLib.Numerics.ReductionTree (Fin n)) (hl : t.leaves.Perm (List.finRange n)) {Bd : ℝ}
    (hB : ∀ j, |(row X j).toReal| ≤ Bd) (hn : n ≤ 2 ^ (FloatFormat.binary32.fracWidth + 1))
    {ε : Model .binary32} (q : ℕ)
    (h₁ : (MojoProof.Float.welford t (row X)).1.isFinite = true)
    (h₂ : (MojoProof.Float.welford t (row X)).2.1.isFinite = true)
    (h₃ : (MojoProof.Float.welford t (row X)).2.2.isFinite = true)
    (hv : (MojoProof.Float.wvar t (row X)).isFinite = true) (hε : 0 < ε.toReal)
    (hs : (Model.add (MojoProof.Float.wvar t (row X)) ε).isFinite = true)
    (hz : (Model.add (MojoProof.Float.wvar t (row X)) ε).isZero = false)
    (hsub : (Model.add (MojoProof.Float.wvar t (row X)) ε).isSubnormal = false)
    (hsg : (Model.add (MojoProof.Float.wvar t (row X)) ε).signBit = false)
    (hδ : Model.unitRoundoffAt .binary32 +
        MojoProof.Float.lnDev (Model.unitRoundoffAt .binary32) (Model.underflowErrorAt .binary32)
          Bd t.depth (TorchLean.var fun j => (row X j).toReal) /
          (TorchLean.var (fun j => (row X j).toReal) + ε.toReal) < 1) :
    ∃ t' m', Steps (ctx tid) (thread n tid (MojoProof.Float.welford t (row X)).2.1
        (MojoProof.Sem.rsqrt (Model.add (MojoProof.Float.wvar t (row X)) ε) q))
        (mem n X G Bt) t' m' ∧
      ∃ B, m'.blocks 4 = some B ∧ ∀ k ∈ lnStores 128 n tid, ∃ hk : k < n,
        ∃ v : Model FloatTy.float.fmt,
          ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some (B.read (4 * k) 4) ∧
          (v.isFinite = true → FloatLib.Numerics.MixedError v.toReal
            (TorchLean.TransformerBlock.layerNorm (fun j => (row G j).toReal)
              (fun j => (row Bt j).toReal) ε.toReal (fun j => (row X j).toReal) ⟨k, hk⟩)
            (Model.unitRoundoffAt .binary32)
            (MojoProof.Float.lnErr (Model.unitRoundoffAt .binary32)
              (Model.underflowErrorAt .binary32)
              (MojoProof.Float.welfErr (Model.unitRoundoffAt .binary32)
                (Model.underflowErrorAt .binary32) Bd t.depth).1
              (MojoProof.Float.rsqrtRel (Model.unitRoundoffAt .binary32)
                (MojoProof.Sem.rsqrtErr : ℝ)
                (MojoProof.Float.lnDev (Model.unitRoundoffAt .binary32)
                  (Model.underflowErrorAt .binary32) Bd t.depth
                  (TorchLean.var fun j => (row X j).toReal))
                (TorchLean.var (fun j => (row X j).toReal) + ε.toReal))
              (1 / √(TorchLean.var (fun j => (row X j).toReal) + ε.toReal)) (row G ⟨k, hk⟩).toReal
              ((row X ⟨k, hk⟩).toReal - 𝔼 i, (row X i).toReal))) := by
  obtain ⟨t', m', hS, B, h4, hF⟩ := run_lnorm (lt_of_le_of_lt hn (by decide)) ht X G Bt t ε q
  refine ⟨t', m', hS, B, h4, fun k hk => ?_⟩
  obtain ⟨hk', v, he, hf⟩ := hF k hk
  refine ⟨hk', v, he, fun h => ?_⟩
  obtain ⟨fused, rfl⟩ := hf h
  exact MojoProof.Float.lnorm_error t hl (row X) (row G) (row Bt) hB hn q fused h₁ h₂ h₃ hv hε hs
    hz hsub hsg hδ ⟨k, hk'⟩ h

/-- The tensor of `n` binary32 words whose entry `j` is `x j`, for every `n` and words `x`. -/
def ofRow {n : Nat} (x : Fin n → Model .binary32) :
    TorchLean.Tensor (Model FloatTy.float.fmt) [n] :=
  TorchLean.Tensor.Rep.ofFn fun c => x c.1

/-- `row` reads back the words `ofRow` builds the tensor from, for every `n` and words `x`. -/
theorem row_ofRow {n : Nat} (x : Fin n → Model .binary32) : row (ofRow x) = x := by
  funext j; exact TorchLean.Tensor.Rep.get_ofFn (s := [n]) (fun c => x c.1) (j, ())

section
open MojoProof.Float FloatLib.Numerics MojoProofTest.FloatTree MojoProofTest.FloatStats
  MojoProofTest.FloatNorm

-- `bpow` is irreducible here, as for `run_torch`.
attribute [local irreducible] FloatLib.Floats.Formats.Flocq.bpow in
/-- **`run_torch` with every premise proved**, a test of one example: thread 0, the row
`X = 1, 2, 3, 4` (`iota`, MojoProofTest/FloatStats.lean), weights `G = 1`, biases `Bt = 0`, the
tree `halveFin 2`, `Bd = 4`, `ε = 2.75` (`eps`, MojoProofTest/FloatNorm.lean) and the oracle
number of the word `0.5` for `rsqrt.approx`. The Welford, variance and operand words' premises
are by evaluation (`decide +kernel`), `ε > 0` by its rational value, and the premise on the
operand's error by `var_iota` and `lndev_num`, as for `lnorm_xs`. So `run_torch`'s premises hold
together at one memory, row and tree. -/
theorem torch_iota := run_torch (n := 2 ^ 2) (tid := 0) (by decide) (ofRow (iota _))
  (ofRow fun _ => one) (ofRow fun _ => Model.posZero _) (halveFin 2) (leaves_halveFin 2)
  (Bd := ((2 ^ 2 : ℕ) : ℝ)) (by rw [row_ofRow]; exact iota_bound (by decide) (by decide +kernel))
  (by decide) (ε := eps) 0x3f000000 (by rw [row_ofRow]; decide +kernel)
  (by rw [row_ofRow]; decide +kernel) (by rw [row_ofRow]; decide +kernel)
  (by rw [row_ofRow]; decide +kernel)
  (by rw [Model.Algebraic.toReal_of_toRat?_eq_some (q := 11 / 4) (by decide +kernel)]; norm_num)
  (by rw [row_ofRow]; decide +kernel) (by rw [row_ofRow]; decide +kernel)
  (by rw [row_ofRow]; decide +kernel) (by rw [row_ofRow]; decide +kernel)
  (by
    rw [row_ofRow, var_iota (by decide) (by decide) (by decide +kernel),
      Model.Algebraic.toReal_of_toRat?_eq_some (q := 11 / 4) (by decide +kernel),
      show (halveFin 2).depth = 2 by rw [ReductionTree.depth_map, depth_halve]]
    lndev_num)

end

/-- **The two results differ at one input.** At the binary32 words `x = 1 + 2⁻²³`
(`0x3f800001`), `g = 1 - 2⁻²³` (`0x3f7ffffe`), `bt = -1` (`0xbf800000`), `mu = 0` and `rs = 1`
(`0x3f800000`), by evaluation (`decide +kernel`): `lnVal` at the oracle numbers 0 is `+0` (the
unfused result: `x · g = 1 - 2⁻⁴⁶` rounds to 1, plus `-1`) and at `o = 1` is `-2⁻⁴⁶`
(`0xa8800000`, the fused result, one rounding of `x · g - 1`), both finite. So both of
`lnVal_cases`' results occur, `lnVal_finite`'s `fused` changes the float stored, and the run
theorems, for every context, leave a set of two floats here. A test at one input. -/
theorem lnVal_two :
    (lnVal (Model.ofNatBits 0x3f800001) (Model.ofNatBits 0x3f7ffffe) (Model.ofNatBits 0xbf800000)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 0).toNatBits = 0 ∧
    (lnVal (Model.ofNatBits 0x3f800001) (Model.ofNatBits 0x3f7ffffe) (Model.ofNatBits 0xbf800000)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 0).isFinite = true ∧
    (lnVal (Model.ofNatBits 0x3f800001) (Model.ofNatBits 0x3f7ffffe) (Model.ofNatBits 0xbf800000)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 1).toNatBits = 0xa8800000 ∧
    (lnVal (Model.ofNatBits 0x3f800001) (Model.ofNatBits 0x3f7ffffe) (Model.ofNatBits 0xbf800000)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 1).isFinite = true := by
  decide +kernel

/-- **The fused float is finite where the separately rounded product is not.** At the binary32
words `x = 2^127` (`0x7f000000`), `g = 2` (`0x40000000`), `bt = -(2^128 - 2^104)` (`0xff7fffff`),
`mu = 0` and `rs = 1` (`0x3f800000`), by evaluation (`decide +kernel`): the separately rounded
product `%502`, the rounded `((x - mu) · rs) · g = 2^128`, is `+Inf` (`0x7f800000`), and so the
unfused `lnVal` (the oracle numbers 0) is not finite; the fused `lnVal` (`o = 1`) is `2^104`
(`0x73800000`, one rounding of `2^128 - (2^128 - 2^104)`), finite. So `lnVal_finite`'s premise
holds with `%502` infinite: its proof names only the selected computation's results. A test at
one input. -/
theorem lnVal_inf :
    (deliver ((deliver ((deliver ((Model.ofNatBits 0x7f000000 : Model FloatTy.float.fmt).sub
      (Model.ofNatBits 0)) 0).mul (Model.ofNatBits 0x3f800000)) 0).mul
      (Model.ofNatBits 0x40000000)) 0).toNatBits = 0x7f800000 ∧
    (lnVal (Model.ofNatBits 0x7f000000) (Model.ofNatBits 0x40000000) (Model.ofNatBits 0xff7fffff)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 0).isFinite = false ∧
    (lnVal (Model.ofNatBits 0x7f000000) (Model.ofNatBits 0x40000000) (Model.ofNatBits 0xff7fffff)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 1).toNatBits = 0x73800000 ∧
    (lnVal (Model.ofNatBits 0x7f000000) (Model.ofNatBits 0x40000000) (Model.ofNatBits 0xff7fffff)
      (Model.ofNatBits 0) (Model.ofNatBits 0x3f800000) 0 0 0 1).isFinite = true := by
  decide +kernel

/-- **`LnOut` does not see the trace; `LnTrace` does.** For every block `y`, memory `m` and event
`e` (a write of a block other than `y`, say): `m` with `e` logged has `m`'s blocks, so
`LnOut y [] m (m.log e)` holds, though the memory saw an event; `LnTrace` at `[]` (no event)
does not hold, for every thread and blocks. -/
theorem log_blind (w : Who) (y g b x : Nat) (R : Nat → List MemByte → Prop) (m : Mem)
    (e : Event) : LnOut y R [] m (m.log e) ∧ ¬ LnTrace w y g b x [] m (m.log e) := by
  refine ⟨LnOut.refl rfl, fun h => ?_⟩
  simp [LnTrace, Mem.log] at h

/-- **The mutant with a short output fails `run_entry`'s premise.** For every rows `X`, `G`, `Bt`
of 300 floats: in `mem 299 X G Bt`, whose block 4 has 299 words, block 4 is not a writable buffer
of `4 · 300` bytes (`run_entry`'s premise on `y`). -/
theorem short (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [300]) :
    ¬ (mem 299 X G Bt).Buffer 4 (300 * 4) 4 true := by
  rintro ⟨blk, hb, -, -, -, -, hs, -⟩
  have e : ((mem 299 X G Bt).blocks 4).map MojoProof.Sem.Block.size = some (299 * 4) := rfl
  rw [hb] at e
  simp only [Option.map_some, Option.some.injEq] at e
  omega

end MojoProofTest.LnRunTest
