import MojoProofTest.SymLane
import MojoProof.Sym.OblHave
import MojoProof.Sym.Segment

/-!
# mojo_obl on gevm_kernel's entry block and loop

gevm_kernel (`gevm` of MojoProofTest/SymLane.lean, the corpus file
gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll) multiplies the
vector `x` of `K` binary32 (`%1`) by the row-major `K × N` matrix `B` of binary32 (`%2`) into
`y` (`%0`). With `ntid.x = 1024`, thread `tid.x = 32 w + l` of block `β` (warp `w`, lane `l`)
runs the loop `%39 → %43 → %45` for `%40 = i` from 0 while `i < %38`, `%38 = ⌈K / 32⌉`, each
round loading `x (32 i + w)` (`%51`) and `B (32 i + w, %17)` (`%55`), column `%17 = 32 β + l`,
and adding their `fmul contract` product to the accumulator `%41` (`fadd contract`); its output
cell is `%29 = (1024 β + tid.x) / 32 = 32 β + w` of `y`. After the loop, `%59` stores each
thread's sum `%60` to cell `32 l + w` of a shared array, waits at a barrier, loads cell `tid.x`
and sums it across the warp by five shuffles (`shfl.sync.bfly` by 16, 8, 4, 2 and 1). Its segments
up to the fifth shuffle are proved here; the statements after it are not.

Registers: `%k` is register `k` for `k ≤ 39`, `%40` (the counter) is 42 and `%41` (the
accumulator) 44 (`regs_named`).

* `lane`: the lane-number call `%12` (statement 5 of `%6`, node 6) by `obl_have`, at every
  context whose `%laneid` is below 32 (`SNode.eval_laneid_at`); `lane_open` is its twin, the
  fact behind an irreducible definition, the node's obligation left open, as logged.
* `entry_edge`: mojo_obl proves the premises of the entry block `%6` and its edge into the
  header `%39` at position 2 (`EdgeWith true`), at every thread of every valid launch with
  `ntid.x = 1024` whose output cell is in `y`: the lane number (below 32 by
  `Launch.laneid_lt`), `ntid.x` rewritten to 1024 (`SNode.eval_word_eq`), the `udiv` by 32,
  the `sdiv` by 32 and by `-32` (`intBin_sdiv_ofNat`, `intBin_sdiv_neg`), the `xor`s and
  `ashr`s by 63 (`intBin_ashr_xor_pos`, `intBin_ashr_xor_neg`), the two `select`s (on equal
  words, `SNode.eval_select_same`, and on an undecided compare of residues, the word of an `if`,
  `SNode.eval_select_word`), the `sub` (`intBin_sub_wrap`), the `smax` (its bound by `omega`
  after splitting the `if`) and the `getelementptr` `%29` into `y`.
* `entry_regs`: the entry's registers by `obl_have`: column `%17 = 32 β + l`, output cell
  `%29` at element `32 β + w` of `y`, and trip count `%38 = ⌈K / 32⌉`.
* `entry_open`: the twin of `entry_edge` at `%30`, with `K < 2 ^ 31` behind an irreducible
  definition: the obligation of the `sdiv` `%30` is left open, as logged.
* `rounds`: mojo_obl proves the premises of round `i` of the loop (`RoundWith true`) for every
  `K` divisible by 32 and below `2 ^ 31`, `N` with `K N < 2 ^ 29`, warp `w < 32`, column
  `col < N` and round `i < ⌈K / 32⌉`: the header's compare, the latch's `select`, its index
  arithmetic, the loads of `x (32 i + w)` (`load_buffer`) and `B (32 i + w, col)` (its address
  by `gep_buffer2`, the load by `load_buffer2`), the `fmul contract`, the `fadd contract` and
  the branch back to `%39`.
* `rounds_open`: the twin at the load `%52`, with `K % 32 = 0` behind an irreducible definition:
  its obligation is left open, as logged. For `K` not divisible by 32 the last round's rows
  `32 i + w ≥ K` are out of `x` and `B` (no guard in the loop).
* `matrix_open`: the twin at the load `%56`, with `K N < 2 ^ 29` behind an irreducible
  definition: `gep_buffer2` does not apply to `%55`, so the load has no address and its
  obligation is left open, as logged.
* `to_barrier`: mojo_obl proves the obligations of `%59` from statement 1 to the barrier at 6
  (`toBarrier`, the segment `summarizeTo` gives, MojoProof/Sym/Segment.lean), for every frame
  whose `%13`, `%11` are the lane and warp below 32 and every context that gives the shared
  array a pointer to offset 0 of a writable buffer of shared memory of 4096 bytes owned by the
  thread's block: the index `32 l + w` and its `trunc`, the array's pointer (`SNode.globalAt`,
  by `SNode.eval_globalAt_at`), its `getelementptr` (`gep_buffer` in space 3) and the `store`
  (`store_buffer`).
* `shared_open`: the twin of `to_barrier` at node 3, with the context's pointer for the array
  behind an irreducible definition: the node's obligation is left open, as logged.
* `to_barrier_waits`: with those premises, a thread at statement 1 of `%59` reaches the barrier
  call and its wait (`Waits`, by `Seg.sound`).
* `to_shfl`: mojo_obl proves the obligations of `%59` from statement 7, after the barrier, to the
  first shuffle at 11 (`toShfl`), for every frame whose `%10` is `tid.x < 1024` and every memory
  whose shared buffer of `to_barrier` holds a vector `A` of 1024 binary32: the `trunc` of `%10`,
  the array's pointer, the address of cell `tid.x`, the load of `A tid.x` (`load_buffer`), its
  `bitcast` to `i32` (`SNode.castAt`, by `SNode.eval_bitcast_at`) and the shuffle's arguments.
  `to_shfl_waits`: a thread at statement 7 reaches that shuffle's wait.
* `shfl_round`: for each `j < 4`, the obligations of the segment from statement `12 + 4 j` to
  shuffle `j + 1` at `15 + 4 j` (`shflRound j`), for every frame whose `%(67 + 4 j)` (the sum so
  far) and `%(69 + 4 j)` (shuffle `j`'s result) are binary32 and whose `%(67 + 4 j)` carries no
  `fmul contract` factors: the `bitcast` of the result to `float`, the `fadd contract`
  (`SNode.eval_fbin_ofFloat`, its factors by a hypothesis), the `bitcast` of the sum to `i32` and
  the shuffle's arguments. `shfl_round_waits`: a thread at statement `12 + 4 j` reaches the
  shuffle's wait.
* `bitcast_open` and `factors_open`: the twins of `shfl_round` at its `bitcast` (the shuffle's
  result a word behind an irreducible definition) and its `fadd` (the sum's factors behind one):
  each node's obligation is left open, as logged.

Tests of one program, gevm_kernel float32 `1308aaae`, for every launch, thread and buffers
with the stated premises; the lemmas they use (MojoProof/Sym/OblLemmas.lean) are for every
program.
-/

namespace MojoProofTest.OblGevm

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open FloatLib.Floats.Formats.BinaryInterchange

/-- **The register numbers of the loop's `phi`s and of the latch's registers**: `%40` is
register 42, `%41` 44, `%17` 17, `%11` 11, `%8` 8 and `%38` 38. -/
theorem regs_named : gevm.fn_0.names[42]? = some "40" ∧ gevm.fn_0.names[44]? = some "41" ∧
    gevm.fn_0.names[17]? = some "17" ∧ gevm.fn_0.names[11]? = some "11" ∧
    gevm.fn_0.names[8]? = some "8" ∧ gevm.fn_0.names[38]? = some "38" := by
  decide +kernel

/-- The entry block `%6` from its start: the index arithmetic, `%29` and `%38`. -/
sym_summary entry := gevm.prog gevm.fn_0 gevm.fn_0.b_0.label 0

/-- The loop header `%39` from position 2, after its `phi`s `%40` and `%41`: `%42 = %40 < %38`
and the branch. -/
sym_summary hdr := gevm.prog gevm.fn_0 gevm.fn_0.b_1.label 2

/-- `%43`: `br label %45`. -/
sym_summary body := gevm.prog gevm.fn_0 gevm.fn_0.b_2.label 0

/-- `%44`: `br label %59`. -/
sym_summary out := gevm.prog gevm.fn_0 gevm.fn_0.b_3.label 0

/-- The latch `%45` with `fmul contract` in the fragment (`summarizeC`, `loops_contract`): the
counter's `select`, the loads, `%57 = fmul contract` and `%58 = fadd contract`. -/
def latch : Summary := (summarizeC gevm.prog gevm.fn_0 gevm.fn_0.b_4.label 0).getD default

/-- The loop `%39 → %43 → %45`, its path out `%39 → %44` (to `%59`, not summarized). -/
def gevmL : LoopSeg :=
  ⟨gevm.fn_0.b_1.label, 2, hdr.obls, hdr,
    [(gevm.fn_0.b_2.label, body.obls, body), (gevm.fn_0.b_4.label, latch.obls, latch)],
    [(gevm.fn_0.b_3.label, out.obls, out)], []⟩

/-- **The lane number `%12` by `obl_have`**: for every context `c` of `gevm`'s program whose
`%laneid` is below 32, step count, memory and frame of `gevm`'s function, register `%12` after
the entry block is the 32-bit word of `c.env.laneid` (`SNode.eval_laneid_at` at statement 5 of
`%6`). -/
theorem lane (c : Ctx) (hcp : c.prog = gevm.prog) (s : Nat) (M : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (hb : c.env.laneid < 32) :
    ((Valuation.entry c s M f).after entry).regs 12 =
      some (.bits 32 (BitVec.ofNat 32 c.env.laneid)) := by
  obl_have h : ((Valuation.entry c s M f).after entry).regs 12
  exact h

/-- The context's `%laneid` is below 32; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def LaneBelow (c : Ctx) : Prop := c.env.laneid < 32

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c s M f) (vals (Valuation.entry c s M f) entry.nodes)
    (Cond.ok (SVal.node 6))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `lane`**: with the bound stated as `LaneBelow`, mojo_obl finds no bound for
the lane number (the context is no launch's), so it leaves node 6's obligation open, as logged;
unfolding `LaneBelow` lets it close it. -/
theorem lane_open (c : Ctx) (hcp : c.prog = gevm.prog) (s : Nat) (M : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (hb : LaneBelow c) :
    Cond.Holds (Valuation.entry c s M f) (vals (Valuation.entry c s M f) entry.nodes)
      (.ok (.node 6)) := by
  mojo_obl
  unfold LaneBelow at hb
  mojo_obl

/-- **The entry block and its edge into the loop, by mojo_obl**, for every thread of every
valid launch with `ntid.x = 1024`. For every valid launch `L`, thread number `k` with
`ntid.x = 1024`, context `c` of `gevm`'s program for thread `k` of `L`, step count `s`, memory
`M` and frame `f` of `gevm`'s function whose `%0` is the start of `p0` and whose `%4`, `%5` are
the 32-bit words of `N, K < 2 ^ 31`, with `p0` a writable buffer of `N` binary32 aligned to 4
whose generic addresses do not wrap and thread `k`'s output cell `32 ctaid.x + tid.x / 32 < N`:
the premises of the entry block `%6` with `fmul contract` hold at `f`'s entry valuation and its
exit goes to the header `%39` at position 2 (`EdgeWith true`). -/
theorem entry_edge (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx)
    (hcp : c.prog = gevm.prog) (hce : c.env = L.env k) (hn : (L.env k).sreg .ntid .x = 1024)
    (s : Nat) (M : Mem) (f : Frame) (hf : f.fn = gevm.fn_0) (N K p0 : Nat)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (hr4 : f.regs 4 = some (.bits 32 (BitVec.ofNat 32 N)))
    (hr5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (hb0 : M.Buffer p0 (N * 4) 4 true) (hf0 : M.Fits gevm.prog.layout p0 (N * 4))
    (hy : (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 < N) :
    EdgeWith true gevmL.h gevmL.p (Valuation.entry c s M f) gevm.fn_0.b_0.label entry.obls entry
      [] := by
  mojo_obl

/-- Two words of equal numbers are equal. -/
theorem word_eq {w x y : Nat} (h : x = y) :
    (some (.bits w (BitVec.ofNat w x)) : Option Val) = some (.bits w (BitVec.ofNat w y)) := by
  rw [h]

/-- Two pointers into one block at equal offsets are equal. -/
theorem ptr_eq {c x y : Nat} (h : x = y) :
    (some (.ptr ⟨c, (x : Int)⟩) : Option Val) = some (.ptr ⟨c, (y : Int)⟩) := by
  rw [h]

/-- **The entry block's registers by `obl_have`**, with the premises of `entry_edge` but `%4`'s:
after
`%6`, the column `%17` is the word of `32 ctaid.x + laneid`, the output cell `%29` is the
pointer to element `32 ctaid.x + tid.x / 32` of `p0` (4 bytes each), and the trip count `%38`
is the word of `⌈K / 32⌉ = (K + 31) / 32` (`smax` of the negated floor division of `K` by
`-32` and 0). -/
theorem entry_regs (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx)
    (hcp : c.prog = gevm.prog) (hce : c.env = L.env k) (hn : (L.env k).sreg .ntid .x = 1024)
    (s : Nat) (M : Mem) (f : Frame) (hf : f.fn = gevm.fn_0) (N K p0 : Nat)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (hr5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (hb0 : M.Buffer p0 (N * 4) 4 true) (hf0 : M.Fits gevm.prog.layout p0 (N * 4))
    (hy : (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 < N) :
    ((Valuation.entry c s M f).after entry).regs 17 =
        some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .ctaid .x * 32 + (L.env k).laneid))) ∧
      ((Valuation.entry c s M f).after entry).regs 29 =
        some (.ptr ⟨p0, ((((L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32) * 4 :
          Nat) : Int)⟩) ∧
      ((Valuation.entry c s M f).after entry).regs 38 =
        some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) := by
  obl_have h17 : ((Valuation.entry c s M f).after entry).regs 17,
    h29 : ((Valuation.entry c s M f).after entry).regs 29,
    h38 : ((Valuation.entry c s M f).after entry).regs 38
  refine ⟨h17.trans (word_eq rfl), h29.trans (ptr_eq ?_), h38.trans (word_eq ?_)⟩
  · show (((_ : Nat) * 1024 + _) / 32 + 0) * 4 = _
    omega
  · simp only [Nat.reducePow, Nat.reduceSub, Nat.reduceAdd]
    split <;> omega

/-- `K` is below `2 ^ 31`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Below31 (K : Nat) : Prop := K < 2 ^ 31

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c s M f) (vals (Valuation.entry c s M f) entry.nodes)
    (Cond.ok (SVal.node 24))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `entry_edge` at `%30`**: with `K < 2 ^ 31` stated as `Below31`, `%7 = sext %5`
need not be `K`'s 64-bit word, so the `sdiv` `%30 = %7 / -32` (node 24) has no value
(`intBin_sdiv_neg` needs `2 %7 < 2 ^ 64`) and mojo_obl leaves its obligation open, as logged;
unfolding `Below31` lets it close it, at every context, step count, memory and frame whose `%5`
is `K`'s 32-bit word (the node reads `%5` only). -/
theorem entry_open (c : Ctx) (s : Nat) (M : Mem) (f : Frame) (K : Nat) (hK : Below31 K)
    (hr5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K))) :
    Cond.Holds (Valuation.entry c s M f) (vals (Valuation.entry c s M f) entry.nodes)
      (.ok (.node 24)) := by
  mojo_obl
  unfold Below31 at hK
  mojo_obl

/-- **The rounds of gevm_kernel's loop, by mojo_obl.** For every `K` divisible by 32 with
`K < 2 ^ 31`, `N` with `K N < 2 ^ 29`, warp `w < 32`, column `col < N`, blocks `bA` and `bB`,
vector `A` of `K` and row-major matrix `B : K × N` of binary32, round `i < (K + 31) / 32` (the
entry's `%38`), accumulator word `acc` and valuation `W` of `gevm`'s program and function with
`%40 = i`, `%38 = (K + 31) / 32`, `%41 = acc`, `%11 = w`, `%8 = N`, `%17 = col` (64-bit words),
`%1` and `%2` at offset 0 of `bA` and `bB`, buffers `bA` and `bB` of `K` and `K N` binary32
aligned to 4 whose generic addresses do not wrap (`Mem.Fits`) and that hold `A` and `B`: the
premises of round `i` of `gevmL` with `fmul contract` hold at `W` (`RoundWith true`). -/
theorem rounds (K N w col bA bB i : Nat) (acc : BitVec 32)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (W : Valuation)
    (hK32 : K % 32 = 0) (hK : K < 2 ^ 31) (hKN : K * N < 2 ^ 29) (hw : w < 32) (hc : col < N)
    (hi : i < (K + 31) / 32) (hP : W.ctx.prog = gevm.prog) (hfn : W.fn = gevm.fn_0)
    (h40 : W.regs 42 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h38 : W.regs 38 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (h41 : W.regs 44 = some (.bits 32 acc))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h8 : W.regs 8 = some (.bits 64 (BitVec.ofNat 64 N)))
    (h17 : W.regs 17 = some (.bits 64 (BitVec.ofNat 64 col)))
    (h1 : W.regs 1 = some (.ptr ⟨bA, 0⟩)) (h2 : W.regs 2 = some (.ptr ⟨bB, 0⟩))
    (hbA : W.mem.Buffer bA (K * 4) 4 false) (hbB : W.mem.Buffer bB (K * N * 4) 4 false)
    (hfA : W.mem.Fits gevm.prog.layout bA (K * 4))
    (hfB : W.mem.Fits gevm.prog.layout bB (K * N * 4))
    (hA : W.mem.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (hB : W.mem.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B) :
    RoundWith true gevmL.h gevmL.p gevmL.dh gevmL.H gevmL.B W := by
  mojo_obl

/-- `K` is divisible by 32; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Div32 (K : Nat) : Prop := K % 32 = 0

/--
info: mojo_obl: open goal
  Cond.Holds
    (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H) gevm.fn_0.b_2.label body)
    (vals (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
      gevm.fn_0.b_2.label body) latch.nodes)
    (Cond.ok (SVal.node 6))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `rounds` at `%52`**: with `K % 32 = 0` stated as `Div32`, row `32 i + w` of
round `i < (K + 31) / 32` need not be below `K`, so mojo_obl finds no address in `x` for the
load `%52` (node 6 of the latch) and leaves its obligation open, as logged; unfolding `Div32`
lets it close it. For `K` not divisible by 32 the last round's rows `32 i + w ≥ K` are out of
`x` and `B` (the loop has no guard). -/
theorem rounds_open (K w bA i : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (W : Valuation) (hK32 : Div32 K) (hK : K < 2 ^ 31) (hw : w < 32) (hi : i < (K + 31) / 32)
    (hP : W.ctx.prog = gevm.prog) (hfn : W.fn = gevm.fn_0)
    (h40 : W.regs 42 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h1 : W.regs 1 = some (.ptr ⟨bA, 0⟩)) (hbA : W.mem.Buffer bA (K * 4) 4 false)
    (hfA : W.mem.Fits gevm.prog.layout bA (K * 4))
    (hA : W.mem.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    Cond.Holds (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
        gevm.fn_0.b_2.label body)
      (vals (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
        gevm.fn_0.b_2.label body) latch.nodes) (.ok (.node 6)) := by
  mojo_obl
  unfold Div32 at hK32
  mojo_obl

/-- `K N` is below `2 ^ 29`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Small (K N : Nat) : Prop := K * N < 2 ^ 29

/--
info: mojo_obl: open goal
  Cond.Holds
    (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H) gevm.fn_0.b_2.label body)
    (vals (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
      gevm.fn_0.b_2.label body) latch.nodes)
    (Cond.ok (SVal.node 10))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `rounds` at `%56`**: with `K N < 2 ^ 29` stated as `Small`, `2 K N` need not
be below `2 ^ 64`, so `gep_buffer2` does not give the `getelementptr` `%55` (node 9 of the latch)
as the pointer to element `(32 i + w) N + col` of `B` (`gep_buffer_ok` gives some value), and
mojo_obl finds no address for the load `%56` (node 10) and leaves its obligation open, as logged;
unfolding `Small` lets it close it. -/
theorem matrix_open (K N w col bB i : Nat)
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (W : Valuation)
    (hK32 : K % 32 = 0) (hKN : Small K N) (hw : w < 32) (hc : col < N)
    (hi : i < (K + 31) / 32) (hP : W.ctx.prog = gevm.prog) (hfn : W.fn = gevm.fn_0)
    (h40 : W.regs 42 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h8 : W.regs 8 = some (.bits 64 (BitVec.ofNat 64 N)))
    (h17 : W.regs 17 = some (.bits 64 (BitVec.ofNat 64 col)))
    (h2 : W.regs 2 = some (.ptr ⟨bB, 0⟩)) (hbB : W.mem.Buffer bB (K * N * 4) 4 false)
    (hfB : W.mem.Fits gevm.prog.layout bB (K * N * 4))
    (hB : W.mem.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B) :
    Cond.Holds (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
        gevm.fn_0.b_2.label body)
      (vals (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
        gevm.fn_0.b_2.label body) latch.nodes) (.ok (.node 10)) := by
  mojo_obl
  unfold Small at hKN
  mojo_obl

/-- The segment of `%59` (`b_5`) from statement 1, after its `phi`, to the barrier call at 6
(`summarizeTo`): `%61 = %13 * 32`, `%62 = %61 + %11`, `%63 = trunc %62`, the shared array's
pointer, `%64` and the `store` of `%60` to `%64`; its nodes, registers, effects and obligations
as a `Summary`, whose exit (`ret`) stands for the barrier and is read by nothing here. -/
def toBarrier : Summary :=
  ((summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6).map fun S =>
    { nodes := S.nodes, regs := S.regs, effs := S.effs, obls := S.obls, exit := .ret,
      len := S.len }).getD default

/-- The name of gevm_kernel's shared array, `[1024 x float]` in address space 3. -/
def sharedName : String :=
  "gevm_kernel_float32_float32_float32_1024_1308aaae._global_alloc_0._gpu_shared_mem"

/-- **The segment of `%59` before the barrier, by mojo_obl**: for every context `c` of `gevm`'s
program, step count `k`, memory `m` and frame `f` of `gevm`'s function whose registers `%13` and
`%11` hold the 64-bit words of `l < 32` and `w < 32` (the lane and the warp) and `%60` the 32-bit
word `acc` (the sum), where `c` gives the shared array the pointer to offset 0 of block `b`
(`Ctx.globals`), `m` has at `b` a writable buffer of 4096 bytes of shared memory aligned to 4 and
owned by the block of threads `g`, which admits `c`'s thread, and the buffer's address in space 3
plus 4096 is at most `2 ^ 32`: the obligations of statements 1 to 5 of `%59` hold at the entry
valuation, the index `32 l + w`, its `trunc`, the global's pointer (`SNode.eval_globalAt_at`), the
address of cell `32 l + w` (`gep_buffer` in space 3) and the `store` of `acc` there
(`store_buffer`). -/
theorem to_barrier (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (l w : Nat) (hl : l < 32) (hw : w < 32) (acc : BitVec 32)
    (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    ∀ d ∈ toBarrier.obls,
      d.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) toBarrier.nodes) := by
  mojo_obl

/-- The context gives the shared array the pointer to offset 0 of block `b`; irreducible, so that
mojo_obl does not find it. -/
@[irreducible] def SharedAt (c : Ctx) (b : Nat) : Prop := c.globals sharedName = some ⟨b, 0⟩

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) toBarrier.nodes)
    (Cond.ok (SVal.node 3))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `to_barrier` at the shared array's pointer**: for every context `c`, step
count `k`, memory `m` and frame `f` of `gevm`'s function, with `c`'s pointer for the array stated
as `SharedAt c b`, node 3 of `toBarrier` (`SNode.globalAt`) has a value; mojo_obl finds no
hypothesis `c.globals g = some p` for it, so it leaves that obligation open, as logged, and
closes it after `unfold SharedAt`. -/
theorem shared_open (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : f.fn = gevm.fn_0) (b : Nat)
    (hg : SharedAt c b) :
    Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) toBarrier.nodes)
      (.ok (.node 3)) := by
  mojo_obl
  unfold SharedAt at hg
  mojo_obl

/-- **A thread at `%59` after its `phi` reaches the barrier**: for every context `c` of `gevm`'s
program, thread `t` whose top frame `f` (above `rest`) is of `gevm`'s function at statement 1 of
`%59`, memory `m`, and `to_barrier`'s premises on `f`, `c` and `m`, the segment `summarizeTo`
gives from statement 1 to the barrier call at 6 is some `S`, and the thread's steps from `t` on
`m` reach that call and its wait (`Waits`, MojoProof/Sym/Segment.lean), by `Seg.sound` at
`to_barrier`'s obligations. -/
theorem to_barrier_waits (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 1) (l w : Nat) (hl : l < 32)
    (hw : w < 32) (acc : BitVec 32) (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    ∃ S, summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6 = some S ∧
      Waits c t m f rest (Valuation.entry c t.k m f, gevm.fn_0.b_5.label, S) := by
  have hs : (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6).isSome = true := by
    decide +kernel
  obtain ⟨S, hS⟩ := Option.isSome_iff_exists.1 hs
  have hds := to_barrier c hcp t.k m f hf l w hl hw acc h13 h11 h60 b g hg hB hin hF
  simp only [toBarrier, hS, Option.map_some, Option.getD_some] at hds
  exact ⟨S, hS, (Seg.sound hS hcp ht hf hlb hpc hds).1⟩

/-! `%59` after the barrier: the load of cell `tid.x` and the five shuffles. -/

/-- The segment of `%59` (`b_5`) from statement 7, after the barrier, to the first shuffle at 11
(`summarizeTo`): `%65 = trunc %10`, the shared array's pointer, `%66`, the load `%67` of cell
`%65` and `%68 = bitcast %67 to i32`, as a `Summary` (as `toBarrier`). -/
def toShfl : Summary :=
  ((summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11).map fun S =>
    { nodes := S.nodes, regs := S.regs, effs := S.effs, obls := S.obls, exit := .ret,
      len := S.len }).getD default

/-- **The load after the barrier, by mojo_obl**: for every context `c` of `gevm`'s program, step
count `k`, memory `m` and frame `f` of `gevm`'s function whose register `%10` holds the 64-bit
word of `x < 1024` (the thread's `tid.x`), where `c` gives the shared array the pointer to offset
0 of block `b`, `m` has at `b` the buffer of `to_barrier` (4096 bytes of shared memory aligned to
4, owned by the block of threads `g`, which admits `c`'s thread, whose address in space 3 plus
4096 is at most `2 ^ 32`) holding the vector `A` of 1024 binary32 row-major: the obligations of
statements 7 to 10 of `%59` hold at the entry valuation, the `trunc` of `%10`, the global's
pointer, the address of cell `x` (`gep_buffer` in space 3), the load of `A x` (`load_buffer`),
its `bitcast` to `i32` (`SNode.eval_bitcast_at`) and the arguments of the first shuffle. -/
theorem to_shfl (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (x : Nat) (hx : x < 1024)
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024]) (b g : Nat)
    (hg : c.globals sharedName = some ⟨b, 0⟩) (hB : m.BufferIn 3 b 4096 4 (.cta g) true)
    (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    ∀ d ∈ toShfl.obls,
      d.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) toShfl.nodes) := by
  mojo_obl

/-- **A thread after the barrier reaches the first shuffle**: for every context `c` of `gevm`'s
program, thread `t` whose top frame `f` (above `rest`) is of `gevm`'s function at statement 7 of
`%59`, memory `m`, and `to_shfl`'s premises on `f`, `c` and `m`, the segment `summarizeTo` gives
from statement 7 to the shuffle at 11 is some `S`, and the thread's steps from `t` on `m` reach
that call and its wait (`Waits`), by `Seg.sound` at `to_shfl`'s obligations. -/
theorem to_shfl_waits (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 7) (x : Nat) (hx : x < 1024)
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024]) (b g : Nat)
    (hg : c.globals sharedName = some ⟨b, 0⟩) (hB : m.BufferIn 3 b 4096 4 (.cta g) true)
    (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    ∃ S, summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11 = some S ∧
      Waits c t m f rest (Valuation.entry c t.k m f, gevm.fn_0.b_5.label, S) := by
  have hs : (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11).isSome = true := by
    decide +kernel
  obtain ⟨S, hS⟩ := Option.isSome_iff_exists.1 hs
  have hds := to_shfl c hcp t.k m f hf x hx h10 A b g hg hB hin hF hA
  simp only [toShfl, hS, Option.map_some, Option.getD_some] at hds
  exact ⟨S, hS, (Seg.sound hS hcp ht hf hlb hpc hds).1⟩

/-- The segment of `%59` from statement `12 + 4 j` to the shuffle at `15 + 4 j` (`summarizeTo`):
for `j < 4`, the `bitcast` of shuffle `j`'s result `%(69 + 4 j)` to `float`, its `fadd contract`
to `%(67 + 4 j)`, and the `bitcast` of the sum to `i32`, as a `Summary` (as `toBarrier`). -/
def shflRound (j : Nat) : Summary :=
  ((summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label (12 + 4 * j) (15 + 4 * j)).map fun S =>
    { nodes := S.nodes, regs := S.regs, effs := S.effs, obls := S.obls, exit := .ret,
      len := S.len }).getD default

/-- **The rounds of the warp sum, by mojo_obl**: for every context `c` of `gevm`'s program, step
count `k`, memory `m`, `j < 4` and frame `f` of `gevm`'s function whose registers `%(67 + 4 j)`
(the sum so far) and `%(69 + 4 j)` (shuffle `j`'s result) hold the binary32 `y` and `z`, and whose
`%(67 + 4 j)` carries no `fmul contract` factors: the obligations of statements `12 + 4 j` to
`14 + 4 j` hold at the entry valuation, the `bitcast` of `z` (`SNode.eval_bitcast_at`), the
`fadd contract` of `y` and `z` (`SNode.eval_fbin_ofFloat`) and the `bitcast` of the sum, with
the arguments of shuffle `j + 1`. -/
theorem shfl_round (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (j : Nat) (hj : j < 4) (y z : Model FloatTy.float.fmt)
    (hy : f.regs (67 + 4 * j) = some (Val.ofFloat .float y))
    (hz : f.regs (69 + 4 * j) = some (Val.ofFloat .float z))
    (hp : f.prods (67 + 4 * j) = none) :
    ∀ d ∈ (shflRound j).obls,
      d.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (shflRound j).nodes) := by
  interval_cases j <;> mojo_obl

/-- `v` is a 32-bit word; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Word32 (v : Val) : Prop := ∃ u : BitVec 32, v = .bits 32 u

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (shflRound 0).nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `shfl_round` at its `bitcast`**: for every context `c`, step count `k`, memory
`m` and frame `f` of `gevm`'s function whose `%69` holds a value `v` that is a 32-bit word, stated
as `Word32 v`, node 0 of `shflRound 0` (the `bitcast` of `%69`) has a value; mojo_obl finds no
word for the operand, so it leaves that obligation open, as logged, and closes it after
`unfold Word32` and `obtain`. -/
theorem bitcast_open (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : f.fn = gevm.fn_0)
    (v : Val) (hz : f.regs 69 = some v) (hv : Word32 v) :
    Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (shflRound 0).nodes)
      (.ok (.node 0)) := by
  mojo_obl
  unfold Word32 at hv
  obtain ⟨u, rfl⟩ := hv
  mojo_obl

/-- `f`'s register `r` carries no `fmul contract` factors; irreducible, so that mojo_obl does not
find it. -/
@[irreducible] def Unfactored (f : Frame) (r : Nat) : Prop := f.prods r = none

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (shflRound 0).nodes)
    (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `shfl_round` at its `fadd`**: with `shfl_round`'s premises at `j = 0` and
`f.prods 67 = none` stated as `Unfactored f 67`, node 1 of `shflRound 0` (the `fadd contract`)
has a value; mojo_obl finds no fact that `%67` carries no factors, so it leaves that obligation
open, as logged, and closes it after `unfold Unfactored`. -/
theorem factors_open (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (y z : Model FloatTy.float.fmt)
    (hy : f.regs 67 = some (Val.ofFloat .float y)) (hz : f.regs 69 = some (Val.ofFloat .float z))
    (hp : Unfactored f 67) :
    Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (shflRound 0).nodes)
      (.ok (.node 1)) := by
  mojo_obl
  unfold Unfactored at hp
  mojo_obl

/-- **A thread in the warp sum reaches the next shuffle**: for every context `c` of `gevm`'s
program, thread `t` whose top frame `f` (above `rest`) is of `gevm`'s function at statement
`12 + 4 j` of `%59` for `j < 4`, memory `m`, and `shfl_round`'s premises on `f`, the segment
`summarizeTo` gives from statement `12 + 4 j` to the shuffle at `15 + 4 j` is some `S`, and the
thread's steps from `t` on `m` reach that call and its wait (`Waits`), by `Seg.sound` at
`shfl_round`'s obligations. -/
theorem shfl_round_waits (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (j : Nat) (hj : j < 4) (hpc : f.pc = 12 + 4 * j)
    (y z : Model FloatTy.float.fmt) (hy : f.regs (67 + 4 * j) = some (Val.ofFloat .float y))
    (hz : f.regs (69 + 4 * j) = some (Val.ofFloat .float z))
    (hp : f.prods (67 + 4 * j) = none) :
    ∃ S, summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label (12 + 4 * j) (15 + 4 * j) = some S ∧
      Waits c t m f rest (Valuation.entry c t.k m f, gevm.fn_0.b_5.label, S) := by
  have hs : (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label (12 + 4 * j)
      (15 + 4 * j)).isSome = true := by
    interval_cases j <;> decide +kernel
  obtain ⟨S, hS⟩ := Option.isSome_iff_exists.1 hs
  have hds := shfl_round c hcp t.k m f hf j hj y z hy hz hp
  simp only [shflRound, hS, Option.map_some, Option.getD_some] at hds
  exact ⟨S, hS, (Seg.sound hS hcp ht hf hlb hpc hds).1⟩

end MojoProofTest.OblGevm
