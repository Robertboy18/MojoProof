import MojoProofTest.SymPhi
import MojoProof.Sym.Loop
import MojoProof.Sem.Index

/-!
# Loops: a counting loop, two loops in sequence, two nested loops, and the naive kernel's back edges

`cnt` is a function of four blocks:
- the entry `0` branches to the header `1`;
- the header starts with `%i = phi i64 [0, %0], [%inext, %2]`, compares `%i < %n`
  (`icmp slt`), and branches to the body `2` or to the exit `3`;
- the body computes `%inext = add nsw %i, 1` and the address `%q` of cell `%i` of the `i64` array
  at `%p` (`getelementptr i64`), stores `%i` there, then branches back to the header (the back
  edge, `Exit.phi`);
- the exit returns.

The fixtures:
- `cntP`: the program of `cnt` (`Program.ofFunc`);
- `ctxC`: the context, `ctx0` of MojoProofTest/SymRun.lean with `cntP`;
- `outC`: the memory, with one global writable block of three `i64` cells;
- `frameC n`: the frame at the entry block's position 0, with the bound `%n = n` and `%p` at the
  block;
- `hdrC n`: the header's entry valuation after the entry edge, which sets `%i = 0`;
- `Cells w n b i m`: block `b` of memory `m` is not the null block, is live, writable, in address
  space 1, 8-aligned, admits thread `w`, has room for `n` cells of `i64`, and cells `j < i` hold
  `j`.

The results:
* `cntL`: the loop's paths (`LoopPaths`); `cnt_covers`: the path checker with `phi`s accepts them
  (`LoopPaths.covers`):
  - the entry block from position 0, whose `br` enters the header with the integer constant 0
    as the `phi` operand;
  - the loop path `1 → 2` from position 1;
  - the path out of the loop `1 → 3` from position 1.

  `cnt_loops`: `coversLoops` accepts `[cntL]` (it starts at `cnt`'s first block).
* `cnt_retL`: `RetL` of `cntL` at the entry valuation of every frame at `cnt`'s entry with
  `%n = n ≤ 2 ^ 60` and `%p` at a block `b` of `Cells _ n b 0`, with the invariant `invN`
  (`%i = i`, `%n = n`, `%p` at `b`, and `Cells _ n b i`) and trip count `n`. Its premises are
  symbolic proofs for every `n` and round `i`, not evaluations:
  - `invN_entry`: the entry's premises, its edge to the header at position 1, and `invN` at
    round 0;
  - `invN_step`: a round's premises (`Round`) from `invN` at round `i < n`, and `invN` at round
    `i + 1` after it: the header's comparison `i < n` (`hdr_vals`, `slt_ofNat`), the body's
    increment and address (`body_vals`), the store to cell `i` and the cells before it
    (`Cells.store`, load after store), and the `phi` (`cnt_enter`, `Valuation.into_of_enter`);
  - `invN_exit`: at round `n`, the exit path's premises, its `ret`, and the cells
    (`Cells.load`).

  The bound `n ≤ 2 ^ 60` keeps the address offset `8 i` below `2 ^ 63`, where `getelementptr`'s
  reduction modulo `2 ^ 64` (`Int.bmod`) is the identity.
* `cnt_run`: **the loop for every trip count**. For every context of `cntP`, every bound
  `n ≤ 2 ^ 60`, every memory `m` and block `b` of `Cells _ n b 0 m`, and every thread whose one
  frame is at `cnt`'s entry with `%n = n`, `%p` at `b` and `b` not among its `alloca` blocks, the
  thread runs to its end (`Runs`), and in the memory it leaves cell `j` holds `j` for every
  `j < n`. This is `Runs.of_loop` with `cnt_retL`; the cleanup of the frame's `alloca` blocks
  keeps block `b` and its loads (`Mem.foldl_setLive_load`).
* `cnt_run_outC`: the kernel-thread form `Runs.of_loops` with `cnt_loops` and `cnt_retL` on one
  memory, `outC` with `frameC n`, for every `n < 4` (the block has room for three cells).
* `cnt_twins`: the premises of a fourth round fail from `hdrC 3` (`%i = 3` is not below
  `%n = 3`) and from `hdrC 4` (the store to cell 3 is outside the three-cell block, so with
  bound 4 the fourth round's premises fail on `outC`), and the path checker refuses the loop
  path from the header's position 0, whose `phi` is outside the fragment.
* `cnt_inv_twin`: the invariant `badC 3` (the iterate with `%i = 0`) holds at round 0 but is not
  preserved, so `Runs.of_loop`'s preservation premise fails.
* `cnt2`: two counting loops in sequence. The first loop's exit block `3` branches to the
  second loop's header `4`, which counts `%j` and stores it to cell `%j` of the array at `%s`;
  the second loop's exit returns. `cnt2C`: the two loops after the entry block (`LoopChain`,
  `loop1`, `loop2`); `cnt2_covers`: `coversChains` accepts them.
  - `cnt2_retLs`: `RetLs` of the two loops at `frame2`'s entry valuation (bound `%n = 2`, `%p` and
    `%s` at the two blocks of `out3`), each loop by `ChainWith.of_rounds` with trip count 2; its
    premises, and the cells of the memory the `ret` leaves (`run_ok`), by `decide +kernel`.
  - `cnt2_run`: `Runs.of_chainsWith` with `cnt2_covers` and `cnt2_retLs`. The thread runs to its
    end, and cells 0 and 1 of both blocks hold 0 and 1 in the memory it leaves.
  - `cnt2_twins`: the first loop alone (`RetLs` of `[loop1]`) does not run to `ret`, for every
    predicate and valuation, since its path out ends at the second header; and `coversChains`
    refuses the second loop's path from its header's position 0, its `phi`.
* `nest`: two nested counting loops, `for i in [0, n): for j in [0, n): p[j] = i`. The
  outer header `1`'s `condBr` enters the inner header `2` (a `phi` block) or the exit; the inner
  loop's path out `2 → 4` ends at the latch, whose `br` goes back to the outer header. `nestC`: the
  outer loop `loopI` after the entry block, whose round is its header alone followed by the inner
  loop `loopJ` (`LoopSeg.inner`); `nest_covers`: `coversChains` accepts it, the nested loop's
  paths included.
  - `nest_rounds`: the premises of the outer loop's two rounds from `hdrT`, each with the inner
    loop's two rounds, by `decide +kernel`.
  - `nest_retLs`: `RetLs` of the nested loops at `frameT`'s entry valuation (`%n = 2`, `%p` at
    `out2`'s block), the outer loop by `ChainWith.of_iter` with the round function `outerT` and
    trip count 2, each round's inner loop by `ChainWith.of_rounds`.
  - `nest_run`: `Runs.of_chainsWith` with `nest_covers` and `nest_retLs`. The thread runs to its
    end, and cells 0 and 1 hold 1 in the memory it leaves.
  - `nest_twins`: without its nested loop the outer loop does not run to `ret` from `frameT`'s
    entry valuation, for every predicate; and `coversChains` refuses the inner loop's paths from
    its header's position 0.
* `cnt_back`, `naive_back`: the back edges and cut points, as `#mojo_info` lists them:
  - of `cnt`: `2 → 1`, header `1`;
  - of the naive matmul kernel of MojoProofTest/SymPhi.lean: `%52 → %46`, header `%46`.

  The forward edges are not listed.
* `naive_out_refusal`: `#mojo_info`'s verdict on the naive kernel's `%51`, whose `br` enters the
  `phi` block `%67`, is "in the fragment", as `summarize` says.
* `naive_latch_refusal`: the checker runs the naive kernel's latch `%52` past its integer
  `select` (statement 2) and refuses it at its `fmul contract` (statement 12), whose product the
  `fadd contract` at statement 13 reads.

`cnt_retL` and `cnt_run` cover the one program `cntP`, every context of it, every bound up to
`2 ^ 60`, every memory with the cells, and every such frame and thread. `cnt2_twins`' first part
covers every predicate and valuation, and `nest_twins`' first part every predicate. The other
results cover only the programs, paths, context, memory, frames and bounds they name.
-/

namespace MojoProofTest.SymLoop

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymRun
open MojoProofTest.SymPhi

/-- The counting loop: `for i in [0, n): p[i] = i`. -/
def cnt : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "cnt", params := [],
    group := none, names := #["entry", "hdr", "body", "exit", "i", "inext", "c", "n", "p", "q"],
    blocks := #[⟨0, #[], .br 1⟩,
      ⟨1, #[{ res := some 4, inst := .phi (.int 64) [(.int 0, 0), (.loc 5, 2)] },
        { res := some 6, inst := .icmp .slt (.int 64) (.loc 4) (.loc 7) }], .condBr (.loc 6) 2 3⟩,
      ⟨2, #[{ res := some 5, inst := .bin .add { nsw := true } (.int 64) (.loc 4) (.int 1) },
        { res := some 9,
          inst := .gep {} (.int 64) (.mk (.ptr 1) (.loc 8)) [.mk (.int 64) (.loc 4)] },
        { res := none,
          inst := .store false (.mk (.int 64) (.loc 4)) (.mk (.ptr 1) (.loc 9)) (some 8) }],
        .br 1⟩,
      ⟨3, #[], .ret none⟩] }

/-- The program of `cnt` alone. -/
def cntP : Program := .ofFunc cnt

/-- The context: `ctx0` with `cntP`. -/
def ctxC : Ctx := { ctx0 with prog := cntP }

/-- The memory with one global writable block of 24 bytes (three `i64` cells), and its number. -/
def outC : Mem × Nat := ({} : Mem).alloc cntP.layout 1 24 8 true false .all 1 1

/-- The frame at the entry block's position 0 with the bound `%n = n` and `%p` at `outC`'s
block. -/
def frameC (n : Nat) : Frame :=
  ⟨cnt, 0, 0,
    fun r => if r = 7 then some (.bits 64 (BitVec.ofNat 64 n))
      else if r = 8 then some (.ptr ⟨outC.2, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- The entry block: a `br` into the header. -/
sym_summary cntE := cntP cnt 0 0

/-- The header from position 1, after its `phi`. -/
sym_summary cntH := cntP cnt 1 1

/-- The body: the increment, the address, the store and the back edge. -/
sym_summary cntB := cntP cnt 2 0

/-- The rest of the loop path: the body. -/
def bodyC : List (Nat × List Cond × Summary) := [(2, cntB.obls, cntB)]

/-- The rest of the path out of the loop: the exit, whose summary, `ret void` alone, is
`Kernels.vadd.b3` (that of `vector_addition`'s `%31`). -/
def exitC : List (Nat × List Cond × Summary) := [(3, Kernels.vadd.b3.obls, Kernels.vadd.b3)]

/-- The entry valuation at `frameC n`, step count 0. -/
def start (n : Nat) : Valuation := Valuation.entry ctxC 0 outC.1 (frameC n)

/-- The header's entry valuation after the entry edge from `start n`, which sets `%i = 0`. -/
def hdrC (n : Nat) : Valuation := Valuation.round 0 cntE [] (start n)

/-- The value of `%i` in valuation `W`, as a natural number. -/
def reg4 (W : Valuation) : Option Nat :=
  match W.regs 4 with
  | some (.bits _ b) => some b.toNat
  | _ => none

/-- An invariant that is not preserved: the iterate, with `%i = 0`. -/
def badC (n i : Nat) (W : Valuation) : Prop :=
  W = (Valuation.round 1 cntH bodyC)^[i] (hdrC n) ∧ reg4 W = some 0

/-- The counting loop's paths (`LoopPaths`): the entry block `0`, whose edge goes to the header
`1` at position 1 (after its `phi`), the loop path `1 → 2` and the path out of the loop `1 → 3`. -/
def cntL : LoopPaths :=
  { l := 0, ds := cntE.obls, S := cntE, E := [], h := 1, p := 1, dh := cntH.obls, H := cntH,
    B := bodyC, X := exitC, inner := [] }

/-- The path checker with `phi`s accepts the counting loop's three paths (`LoopPaths.covers`): the
entry block from position 0, whose `br` enters the header (`Exit.phi`, the `phi` operand the
integer constant 0), and the loop path `1 → 2` and the path out of the loop `1 → 3` from the
header's position 1. -/
theorem cnt_covers : cntL.covers cntP cnt 0 = true := by
  decide +kernel

/-- `coversLoops` accepts the counting loop: it starts at `cnt`'s first block `0`, and its paths
are accepted (`cnt_covers`). -/
theorem cnt_loops : coversLoops cntP cnt [cntL] = true := by
  decide +kernel

/-! ## The loop for every trip count -/

/-- Statement 1 of the body: `%q = getelementptr i64, ptr %p, i64 %i`. -/
theorem cnt_gep {W : Valuation} (hfn : W.fn = cnt) : W.stmt 2 1 = some {
    res := some 9,
    inst := .gep {} (.int 64) (.mk (.ptr 1) (.loc 8)) [.mk (.int 64) (.loc 4)] } := by
  rw [Valuation.stmt, hfn]
  rfl

/-- Statement 2 of the body: `store i64 %i, ptr %q, align 8`. -/
theorem cnt_store {W : Valuation} (hfn : W.fn = cnt) : W.stmt 2 2 = some {
    res := none,
    inst := .store false (.mk (.int 64) (.loc 4)) (.mk (.ptr 1) (.loc 9)) (some 8) } := by
  rw [Valuation.stmt, hfn]
  rfl

/-- The pointers of address space 1 of `cntP`'s layout have 64 bits. -/
theorem cntP_ptr : cntP.layout.ptr 1 = (64, 64) := by rfl

/-- An `i64` has 8 bytes in `cntP`'s layout. -/
theorem cntP_size : cntP.layout.size (.int 64) = 8 := by rfl

/-- The `i64` comparison `x < y` is `true` for the words of `i < n` when `n < 2 ^ 63`. -/
theorem slt_ofNat {i n : Nat} (hi : i < n) (hn : n < 2 ^ 63) :
    (BitVec.ofNat 64 i).slt (BitVec.ofNat 64 n) = true := by
  simp [BitVec.slt, BitVec.toInt_ofNat_of_lt (w := 64) (k := n) (by omega),
    BitVec.toInt_ofNat_of_lt (w := 64) (k := i) (by omega), hi]

/-- The header's node values at every valuation with words `%i = x` and `%n = y`: the
comparison `x < y`. -/
theorem hdr_vals {W : Valuation} {x y : BitVec 64}
    (h4 : W.regs 4 = some (.bits 64 x)) (h7 : W.regs 7 = some (.bits 64 y)) :
    vals W cntH.nodes = [.ok (.ofBool (x.slt y))] := by
  delta cntH
  simp [vals, SNode.eval, SVal.eval, h4, h7, icmpV, lanes2, strict2, ICmp.holds, bind,
    Except.bind, pure, Except.pure]

/-- The body's node values at every valuation of `cnt` in a context of `cntP` with `%i = i`
(`i < 2 ^ 60`) and `%p` at offset 0 of block `b` (not the null block) of address space 1: the
increment `i + 1` and the address of cell `i`, offset `8 i`. -/
theorem body_vals {W : Valuation} (hfn : W.fn = cnt) (hP : W.ctx.prog = cntP) {i b : Nat}
    {blk : Sem.Block} (h4 : W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h8 : W.regs 8 = some (.ptr ⟨b, 0⟩)) (hb : W.mem.blocks b = some blk) (hb0 : b ≠ 0)
    (hsp : blk.space = 1) (hi : i < 2 ^ 60) :
    vals W cntB.nodes =
      [.ok (.bits 64 (BitVec.ofNat 64 (i + 1))), .ok (.ptr ⟨b, 8 * (i : Int)⟩)] := by
  delta cntB
  simp [vals, SNode.eval, SVal.eval, h4, h8, cnt_gep hfn, lanes2, intBin, intBits, bind,
    Except.bind, pure, Except.pure, MojoProof.Sem.gep, gepPtr, hP, cntP_ptr, gepSteps,
    gepSteps.into, Mem.addr, Mem.block, hb, hb0, hsp, cntP_size,
    BitVec.toInt_ofNat_of_lt (w := 64) (k := i) (by omega), outS]
  refine ⟨?_, ?_⟩
  · rw [ite_eq_right (by omega)]
    congr 1
    apply BitVec.eq_of_toNat_eq
    simp
  · rw [Int.bmod_eq_of_le (n := (i : Int) * 8) (m := 18446744073709551616) (by omega) (by omega)]
    exact Int.mul_comm _ _

/-- The cells of the loop's output: block `b` of memory `m` is not the null block 0, and is live,
writable, in address space 1, 8-aligned, admits thread `w`, has room for `n` cells of `i64`
(`8 n` bytes), and cells `j < i` hold `j` (`leBytes`). -/
def Cells (w : Who) (n b i : Nat) (m : Mem) : Prop :=
  b ≠ 0 ∧ ∃ blk : Sem.Block, m.blocks b = some blk ∧ blk.space = 1 ∧ blk.live = true ∧
    blk.readOnly = false ∧ blk.owner.admits w = true ∧ 8 * n ≤ blk.size ∧ blk.addr % 8 = 0 ∧
    ∀ j < i, blk.read (8 * j) 8 = leBytes 8 j

/-- `Mem.check` admits the 8 bytes of cell `j < n` of a block with room for `n` cells. -/
theorem Cells.check {w : Who} {n b : Nat} {m : Mem} {blk : Sem.Block} (hb0 : b ≠ 0)
    (hb : m.blocks b = some blk) (hs : blk.space = 1) (hl : blk.live = true)
    (hw : blk.owner.admits w = true) (hn : 8 * n ≤ blk.size) (ha : blk.addr % 8 = 0) {j : Nat}
    (hj : j < n) :
    m.check cntP.layout w 1 ⟨b, 8 * (j : Int)⟩ 8 (some 8) = .ok (blk, 8 * j) := by
  have hc := Mem.check_ok (l := cntP.layout) (p := ⟨b, 8 * (j : Int)⟩) (n := 8) (al := some 8)
    hb hl hw (by simp) (by simp; omega)
    (hs ▸ Mem.addr_own (l := cntP.layout) (p := ⟨b, 8 * (j : Int)⟩) hb hb0)
    (fun k hk => by
      cases hk
      rw [cntP_ptr]
      show (((blk.addr : Int) + 8 * (j : Int)) % 2 ^ 64).toNat % 8 = 0
      omega)
  rw [hc]
  simp only [Except.ok.injEq, Prod.mk.injEq, true_and]
  omega

/-- **Store, then the cells before it**: for `i < n ≤ 2 ^ 60`, the store of `i` to cell `i` of
`Cells w n b i m` succeeds, and gives `Cells w n b (i + 1)`: cell `i` holds `i`
(`Block.read_put_self`), and the cells `j < i` keep their values (`Block.read_put_apart`). -/
theorem Cells.store {w : Who} {n b i : Nat} {m : Mem} (h : Cells w n b i m) (hi : i < n)
    (hn : n ≤ 2 ^ 60) :
    ∃ m', m.store cntP.layout w 1 (.int 64) (.bits 64 (BitVec.ofNat 64 i)) ⟨b, 8 * (i : Int)⟩
      (some 8) = .ok m' ∧ Cells w n b (i + 1) m' := by
  obtain ⟨hb0, blk, hb, hs, hl, hr, hw, hsz, ha, hc⟩ := h
  have hbs : cntP.layout.encode (.int 64) (.bits 64 (BitVec.ofNat 64 i)) =
      some (leBytes 8 i) := by
    simp [Layout.encode]
    rw [Nat.mod_eq_of_lt (by omega)]
  refine ⟨_, Mem.store_of_check hbs (Cells.check hb0 hb hs hl hw hsz ha hi) hr, hb0,
    blk.put (8 * i) (leBytes 8 i), by simp [Mem.log, Mem.set], hs, hl, hr, hw, hsz, ha,
    fun j hj => ?_⟩
  rcases Nat.lt_succ_iff_lt_or_eq.1 hj with hj | rfl
  · rw [Block.read_put_apart _ _ (by simp [leBytes]; omega), hc j hj]
  · have := Block.read_put_self blk (8 * j) (leBytes 8 j)
    simpa [leBytes] using this

/-- The load of cell `j < n` of `Cells w n b n m` gives `j`. -/
theorem Cells.load {w : Who} {n b : Nat} {m : Mem} (h : Cells w n b n m) (hn : n ≤ 2 ^ 60)
    {j : Nat} (hj : j < n) :
    m.load cntP.layout w 1 (.int 64) ⟨b, 8 * (j : Int)⟩ (some 8) =
      .ok (.bits 64 (BitVec.ofNat 64 j)) := by
  obtain ⟨hb0, blk, hb, hs, hl, hr, hw, hsz, ha, hc⟩ := h
  refine Mem.load_of_check (Cells.check hb0 hb hs hl hw hsz ha hj) ?_
  have := Layout.scalarOf_leBytes (n := 8) (BitVec.ofNat 64 j) (by omega)
  rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)] at this
  show Layout.scalarOf 64 (blk.read (8 * j) 8) = _
  rw [hc j hj, this]

/-- After the header, at every valuation: the context, function and memory are kept, and every
register but `%c` (6). -/
theorem hdr_after (W : Valuation) : (W.after cntH).ctx = W.ctx ∧ (W.after cntH).fn = W.fn ∧
    (W.after cntH).mem = W.mem ∧ ∀ r, r ≠ 6 → (W.after cntH).regs r = W.regs r := by
  refine ⟨rfl, rfl, rfl, fun r hr => ?_⟩
  have : (r == 6) = false := by simpa using hr
  delta cntH
  simp [Valuation.after, regVal, this, List.lookup]

/-- The registers after a block, for every valuation `V` and summary `S`: `regVal` of the values
of `S`'s nodes (a rewrite that leaves `V` folded). -/
theorem after_regs (V : Valuation) (S : Summary) :
    (V.after S).regs = regVal V (vals V S.nodes) S.regs := rfl

/-- The header's `condBr` has a target, so its edge keeps `Valuation.after`'s valuation. -/
theorem hdr_into (W : Valuation) : W.into 1 cntH = W.after cntH := rfl

/-- One round of the loop path: the header, then the body's edge into the header. -/
theorem cnt_round (W : Valuation) :
    Valuation.round 1 cntH bodyC W = (W.after cntH).into 2 cntB := rfl

/-- The edge into the header from the entry (`phi` operand the constant 0) or from the body
(`%inext`), for every scope and frame of `cnt`: `enter` sets `%i` to the operand's value and
enters at position 1. -/
theorem cnt_enter {s : Scope} {F : Frame} (hfn : F.fn = cnt) {v : Value}
    (hv : F.label = 0 ∧ v = .int 0 ∨ F.label = 2 ∧ v = .loc 5) {x : Val}
    (hx : evalV s (.int 64) v = .ok x) :
    enter s F 1 = .ok { F.set (some 4) (some x) none with label := 1, pc := 1 } := by
  rcases hv with ⟨hl, rfl⟩ | ⟨hl, rfl⟩ <;>
    simp [enter, hfn, hl, cnt, Stmt.checkMd, hx, pure, Except.pure, bind, Except.bind]

/-- The invariant of round `i` for the bound `n` and the block `b`, in context `c`: the
valuation is in `c` and `cnt`, `%i = i`, `%n = n`, `%p` at offset 0 of `b`, and
`Cells c.who n b i`. -/
def invN (c : Ctx) (n b i : Nat) (W : Valuation) : Prop :=
  W.ctx = c ∧ W.fn = cnt ∧ W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩) ∧
    Cells c.who n b i W.mem

/-- **The invariant's preservation**, for every context `c` of `cntP`, bound `n ≤ 2 ^ 60`, block
`b`, round `i < n` and valuation `W` of `invN c n b i`: the round's premises hold at `W`
(`Round`: the header's comparison is true, the body's obligations hold, its edge goes to the
header at position 1), and `invN c n b (i + 1)` holds after it. -/
theorem invN_step {c : Ctx} (hP : c.prog = cntP) {n b : Nat} (hn : n ≤ 2 ^ 60) {i : Nat}
    (hi : i < n) {W : Valuation} (h : invN c n b i W) :
    Round 1 1 cntH.obls cntH bodyC W ∧ invN c n b (i + 1) (Valuation.round 1 cntH bodyC W) := by
  obtain ⟨hc, hfn, h4, h7, h8, hm⟩ := h
  obtain ⟨m', hst, hm'⟩ := Cells.store hm hi hn
  obtain ⟨hb0, blk, hb, hs, -⟩ := hm
  have hH := hdr_vals h4 h7
  have hslt := slt_ofNat hi (by omega)
  obtain ⟨hc1, hf1, hm1, hr1⟩ := hdr_after W
  have hB := body_vals (W := W.after cntH) (hf1.trans hfn) (by rw [hc1, hc]; exact hP)
    (by rw [hr1 4 (by decide)]; exact h4) (by rw [hr1 8 (by decide)]; exact h8)
    (by rw [hm1]; exact hb) hb0 hs (by omega)
  have hrun : SEff.run (W.after cntH) (vals (W.after cntH) cntB.nodes) cntB.effs = .ok m' := by
    rw [hB]
    delta cntB
    simp [SEff.run, SEff.apply, cnt_store (hf1.trans hfn), SVal.eval, hr1 4 (by decide),
      h4, hc1, hc, hP, Val.addr?, hm1]
    exact hst
  have hE := Valuation.into_of_enter (V := W.after cntH) (l := 2) (S := cntB) rfl rfl
    (cnt_enter (s := (W.after cntH).ctx.scope ((W.after cntH).after cntB).mem
        ((W.after cntH).frameAt 2 cntB) ((W.after cntH).k + cntB.len))
      (F := (W.after cntH).frameAt 2 cntB) (hf1.trans hfn) (.inr ⟨rfl, rfl⟩)
      (x := .bits 64 (BitVec.ofNat 64 (i + 1)))
      (by
        simp only [evalV, Ctx.scope, Valuation.frameAt, Valuation.frameAtWith, Valuation.afterWith,
          after_regs, hB]
        delta cntB
        simp [regVal, List.lookup, SVal.eval, pure, Except.pure, Except.toOption]))
  refine ⟨⟨⟨?_, ?_, ?_⟩, ?_, ?_⟩, ?_⟩
  · rw [hH]
    delta cntH
    simp [Cond.Holds, SVal.eval, SEff.run, hslt, Val.ofBool, pure, Except.pure]
  · rw [hH]
    delta cntH
    simp [Exit.dest, Exit.target, SVal.eval, hslt, Val.ofBool]
  · rw [show W.intoWith false 1 cntH = W.after cntH from hdr_into W]
    intro d hd
    delta cntB at hd
    simp only [List.mem_cons, List.mem_nil_iff, or_false] at hd
    rcases hd with rfl | rfl | rfl | rfl
    · exact ⟨_, by rw [hB]; rfl⟩
    · exact ⟨m', hrun⟩
    · exact ⟨_, by rw [hB]; rfl⟩
    · exact ⟨_, by rw [hB]; rfl⟩
  · rfl
  · show phiCount W.fn 1 = 1
    rw [hfn]
    rfl
  · rw [cnt_round, hE]
    refine ⟨hc1.trans hc, hf1.trans hfn, by simp [Frame.set], ?_, ?_, ?_⟩
    · simp only [Frame.set, Valuation.frameAt, Valuation.frameAtWith, Valuation.afterWith,
        after_regs]
      delta cntB
      simp [regVal, List.lookup]
      rw [hr1 7 (by decide)]
      exact h7
    · simp only [Frame.set, Valuation.frameAt, Valuation.frameAtWith, Valuation.afterWith,
        after_regs]
      delta cntB
      simp [regVal, List.lookup]
      rw [hr1 8 (by decide)]
      exact h8
    · show Cells c.who n b (i + 1) ((SEff.run (W.after cntH) (vals (W.after cntH) cntB.nodes)
        cntB.effs).toOption.getD _)
      rw [hrun]
      exact hm'

/-- **The exit**, for every bound `n ≤ 2 ^ 60`, block `b` and valuation of `invN c n b n`: the
exit path's premises hold (the header's comparison `n < n` is false), its last exit is `ret`, and
its memory has `j` in cell `j` for every `j < n`. -/
theorem invN_exit {c : Ctx} {n b : Nat} (hn : n ≤ 2 ^ 60) {W : Valuation} (h : invN c n b n W) :
    WalkWith false W ((1, cntH.obls, cntH) :: exitC) ∧
      (W.lastWith false 1 cntH exitC).2.2.exit = .ret ∧
      ∃ me, SEff.run (W.lastWith false 1 cntH exitC).1
          (vals (W.lastWith false 1 cntH exitC).1 (W.lastWith false 1 cntH exitC).2.2.nodes)
          (W.lastWith false 1 cntH exitC).2.2.effs = .ok me ∧
        ∀ j < n, me.load cntP.layout c.who 1 (.int 64) ⟨b, 8 * j⟩ (some 8) =
          .ok (.bits 64 (BitVec.ofNat 64 j)) := by
  obtain ⟨-, -, h4, h7, -, hm⟩ := h
  have hH := hdr_vals h4 h7
  obtain ⟨-, -, hm1, -⟩ := hdr_after W
  refine ⟨⟨?_, ?_, fun d hd => ?_⟩, rfl, W.mem, by rw [← hm1]; rfl,
    fun j hj => Cells.load hm hn hj⟩
  · rw [hH]
    delta cntH
    simp [Cond.Holds, SVal.eval, SEff.run, Val.ofBool, pure, Except.pure]
  · rw [hH]
    delta cntH
    simp [Exit.dest, Exit.target, SVal.eval, Val.ofBool, BitVec.slt]
  · change d ∈ Kernels.vadd.b3.obls at hd
    delta Kernels.vadd.b3 at hd
    simp only [List.mem_cons, List.mem_nil_iff, or_false] at hd
    subst hd
    exact ⟨_, rfl⟩

/-- **The entry**, for every context `c`, bound `n`, block `b`, step count `k`, memory `m` of
`Cells c.who n b 0` and frame `f` of `cnt` with `%n = n` and `%p` at `b`: the entry block's
premises hold, its edge goes to the header at position 1, and `invN c n b 0` holds at the
header's entry valuation (`%i = 0`). -/
theorem invN_entry {c : Ctx} {n b k : Nat} {m : Mem} {f : Frame} (hfn : f.fn = cnt)
    (h7 : f.regs 7 = some (.bits 64 (BitVec.ofNat 64 n))) (h8 : f.regs 8 = some (.ptr ⟨b, 0⟩))
    (hm : Cells c.who n b 0 m) :
    WalkWith false (Valuation.entry c k m f) [(0, cntE.obls, cntE)] ∧
      ((Valuation.entry c k m f).lastWith false 0 cntE []).2.2.exit.dest
        ((Valuation.entry c k m f).lastWith false 0 cntE []).1
        (vals ((Valuation.entry c k m f).lastWith false 0 cntE []).1
          ((Valuation.entry c k m f).lastWith false 0 cntE []).2.2.nodes) = some 1 ∧
      ((Valuation.entry c k m f).lastWith false 0 cntE []).2.2.exit.pc cnt 1 = 1 ∧
      invN c n b 0 (Valuation.round 0 cntE [] (Valuation.entry c k m f)) := by
  have hE := Valuation.into_of_enter (V := Valuation.entry c k m f) (l := 0) (S := cntE) rfl rfl
    (cnt_enter (F := (Valuation.entry c k m f).frameAt 0 cntE) hfn (.inl ⟨rfl, rfl⟩)
      (x := .bits 64 (BitVec.ofNat 64 0)) rfl)
  have hR : Valuation.round 0 cntE [] (Valuation.entry c k m f) = _ := hE
  refine ⟨fun d hd => ?_, rfl, rfl, by rw [hR]; rfl, by rw [hR]; exact hfn,
    by rw [hR]; simp [Frame.set], ?_, ?_, ?_⟩
  · change d ∈ cntE.obls at hd
    delta cntE at hd
    simp only [List.mem_cons, List.mem_nil_iff, or_false] at hd
    rcases hd with rfl | rfl
    · exact ⟨_, rfl⟩
    · exact ⟨_, rfl⟩
  · rw [hR]
    delta cntE
    simpa [Frame.set, Valuation.frameAt, Valuation.frameAtWith, Valuation.afterWith,
      Valuation.after, regVal, Valuation.entry] using h7
  · rw [hR]
    delta cntE
    simpa [Frame.set, Valuation.frameAt, Valuation.frameAtWith, Valuation.afterWith,
      Valuation.after, regVal, Valuation.entry] using h8
  · rw [hR]
    exact hm

/-- **The counting loop's run from its entry**, for every context `c` of `cntP`, bound
`n ≤ 2 ^ 60`, block `b`, step count `k`, memory `m` of `Cells c.who n b 0` and frame `f` of `cnt`
with `%n = n` and `%p` at offset 0 of `b`: `RetL` of `cntL` at `f`'s entry valuation, with the
invariant `invN c n b` and trip count `n` (`invN_entry`, `invN_step`, `invN_exit`), leaving a
memory whose cell `j` holds `j` for every `j < n`. -/
theorem cnt_retL {c : Ctx} (hP : c.prog = cntP) {n b k : Nat} (hn : n ≤ 2 ^ 60) {m : Mem}
    {f : Frame} (hfn : f.fn = cnt) (h7 : f.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h8 : f.regs 8 = some (.ptr ⟨b, 0⟩)) (hm : Cells c.who n b 0 m) :
    RetL (Valuation.entry c k m f) (fun me => ∀ j < n,
      me.load cntP.layout c.who 1 (.int 64) ⟨b, 8 * j⟩ (some 8) =
        .ok (.bits 64 (BitVec.ofNat 64 j))) cntL := by
  obtain ⟨hW, hd, hpc, h0⟩ := invN_entry (k := k) hfn h7 h8 hm
  rw [← show (Valuation.entry c k m f).fn = cnt from hfn] at hpc
  exact ChainWith.loop (contract := false) (invN c n b) n ⟨hW, hd, hpc⟩ h0
    (fun i hi W hW => ChainWith.last (invN_step hP hn hi hW))
    fun W hW => ChainWith.last (invN_exit hn hW)

/-- **The counting loop for every trip count.** For every context `c` of `cntP`, bound
`n ≤ 2 ^ 60`, block `b`, memory `m` of `Cells c.who n b 0` (room for `n` cells), and thread `t`
whose one frame `f` is at `cnt`'s entry with `%n = n` and `%p` at offset 0 of `b`, where `b` is
not one of `f`'s `alloca` blocks: the thread runs to its end (`Runs`), leaving a memory (with
`f`'s `alloca` blocks dead) whose cell `j` holds `j` for every `j < n`. This is `Runs.of_loop`
with `cnt_retL`; the loads hold on the memory the return leaves, because its cleanup keeps block
`b` (`Mem.foldl_setLive_load`). -/
theorem cnt_run {c : Ctx} (hP : c.prog = cntP) {n b : Nat} (hn : n ≤ 2 ^ 60) {t : Thread}
    {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = cnt) (hl : f.label = 0)
    (hp : f.pc = 0) (h7 : f.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h8 : f.regs 8 = some (.ptr ⟨b, 0⟩)) (hm : Cells c.who n b 0 m) (hb : b ∉ f.allocas) :
    ∃ m', Runs c t m m' ∧ ∀ j < n, m'.load cntP.layout c.who 1 (.int 64) ⟨b, 8 * j⟩ (some 8) =
      .ok (.bits 64 (BitVec.ofNat 64 j)) := by
  obtain ⟨me, hR, hQ⟩ := Runs.of_loop hP cnt_covers ht hfn hl hp (cnt_retL hP hn hfn h7 h8 hm)
  exact ⟨_, hR, fun j hj => (Mem.foldl_setLive_load (p := ⟨b, 8 * j⟩) hb _ _ _ _ _).trans (hQ j hj)⟩

/-- The counting loop as a kernel's thread on one memory (`Runs.of_loops` with `cnt_loops` and
`cnt_retL`): for every `n < 4`, the thread whose one frame is `frameC n` (at `cnt`'s first block,
position 0, no `alloca` blocks) runs on `outC` to its end, and cell `j` of `outC`'s block holds
`j` for every `j < n` in the memory it leaves. -/
theorem cnt_run_outC : ∀ n : Nat, n < 4 → ∃ m', Runs ctxC ⟨[frameC n], 0⟩ outC.1 m' ∧
    ∀ j < n, m'.load cntP.layout ctxC.who 1 (.int 64) ⟨outC.2, 8 * j⟩ (some 8) =
      .ok (.bits 64 (BitVec.ofNat 64 j)) := by
  intro n hn
  exact Runs.of_loops (P := cntP) (c := ctxC) (t := ⟨[frameC n], 0⟩) (f := frameC n) rfl cnt_loops
    rfl rfl rfl rfl rfl ⟨cntL, List.mem_singleton.2 rfl, cnt_retL (n := n) (b := outC.2) rfl
      (by omega) rfl rfl rfl ⟨by decide, _, rfl, rfl, rfl, rfl, rfl, by show 8 * n ≤ 24; omega,
        rfl, nofun⟩⟩

/-- **The twins**: the premises of a fourth round fail from `hdrC 3` (`%i = 3` is not below
`%n = 3`) and from `hdrC 4` (its store to cell 3 is outside the three-cell block), and the path
checker refuses the loop path from the header's position 0, its `phi`. -/
theorem cnt_twins :
    ¬ Round 1 1 cntH.obls cntH bodyC ((Valuation.round 1 cntH bodyC)^[3] (hdrC 3)) ∧
    ¬ Round 1 1 cntH.obls cntH bodyC ((Valuation.round 1 cntH bodyC)^[3] (hdrC 4)) ∧
    coversPathWith false cntP cnt 0 ((1, cntH.obls, cntH) :: bodyC) = false := by
  decide +kernel

/-- **The invariant twin**: `badC 3` holds at round 0, but it is not preserved, so `Runs.of_loop`'s
preservation premise fails: round 0 makes `%i = 1`. -/
theorem cnt_inv_twin : badC 3 0 (hdrC 3) ∧
    ¬ ∀ i < 3, ∀ W, badC 3 i W →
      Round 1 1 cntH.obls cntH bodyC W ∧ badC 3 (i + 1) (Valuation.round 1 cntH bodyC W) := by
  refine ⟨⟨rfl, by decide +kernel⟩, fun h => ?_⟩
  obtain ⟨-, -, h1⟩ := h 0 (by decide) (hdrC 3) ⟨rfl, by decide +kernel⟩
  revert h1
  decide +kernel

/-! ## Two loops in sequence -/

/-- Two counting loops in sequence: `for i in [0, n): p[i] = i`, then `for j in [0, n): s[j] = j`.
The first loop's exit `3` branches to the second loop's header `4`. -/
def cnt2 : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "cnt2", params := [],
    group := none,
    names := #["entry", "hdr", "body", "mid", "hdr2", "body2", "exit", "i", "inext", "c", "n",
      "p", "q", "j", "jnext", "d", "s", "r"],
    blocks := #[⟨0, #[], .br 1⟩,
      ⟨1, #[{ res := some 7, inst := .phi (.int 64) [(.int 0, 0), (.loc 8, 2)] },
        { res := some 9, inst := .icmp .slt (.int 64) (.loc 7) (.loc 10) }],
        .condBr (.loc 9) 2 3⟩,
      ⟨2, #[{ res := some 8, inst := .bin .add { nsw := true } (.int 64) (.loc 7) (.int 1) },
        { res := some 12,
          inst := .gep {} (.int 64) (.mk (.ptr 1) (.loc 11)) [.mk (.int 64) (.loc 7)] },
        { res := none,
          inst := .store false (.mk (.int 64) (.loc 7)) (.mk (.ptr 1) (.loc 12)) (some 8) }],
        .br 1⟩,
      ⟨3, #[], .br 4⟩,
      ⟨4, #[{ res := some 13, inst := .phi (.int 64) [(.int 0, 3), (.loc 14, 5)] },
        { res := some 15, inst := .icmp .slt (.int 64) (.loc 13) (.loc 10) }],
        .condBr (.loc 15) 5 6⟩,
      ⟨5, #[{ res := some 14, inst := .bin .add { nsw := true } (.int 64) (.loc 13) (.int 1) },
        { res := some 17,
          inst := .gep {} (.int 64) (.mk (.ptr 1) (.loc 16)) [.mk (.int 64) (.loc 13)] },
        { res := none,
          inst := .store false (.mk (.int 64) (.loc 13)) (.mk (.ptr 1) (.loc 17)) (some 8) }],
        .br 4⟩,
      ⟨6, #[], .ret none⟩] }

/-- The program of `cnt2` alone. -/
def cnt2P : Program := .ofFunc cnt2

/-- The context: `ctx0` with `cnt2P`. -/
def ctx2 : Ctx := { ctx0 with prog := cnt2P }

/-- The memory with one global writable block of 16 bytes (two `i64` cells), and its number. -/
def out2 : Mem × Nat := ({} : Mem).alloc cnt2P.layout 1 16 8 true false .all 1 1

/-- `out2`'s memory with a second such block, and its number. -/
def out3 : Mem × Nat := out2.1.alloc cnt2P.layout 1 16 8 true false .all 4 4

/-- The frame at the entry block's position 0 with the bound `%n = 2`, `%p` at `out2`'s block and
`%s` at `out3`'s. -/
def frame2 : Frame :=
  ⟨cnt2, 0, 0,
    fun r => if r = 10 then some (.bits 64 (BitVec.ofNat 64 2))
      else if r = 11 then some (.ptr ⟨out2.2, 0⟩)
      else if r = 16 then some (.ptr ⟨out3.2, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- The first header from position 1, after its `phi`. -/
sym_summary c2H := cnt2P cnt2 1 1

/-- The first body. -/
sym_summary c2B := cnt2P cnt2 2 0

/-- The first loop's exit: a `br` into the second header. -/
sym_summary c2M := cnt2P cnt2 3 0

/-- The second header from position 1, after its `phi`. -/
sym_summary c2G := cnt2P cnt2 4 1

/-- The second body. -/
sym_summary c2D := cnt2P cnt2 5 0

/-- The first loop: header `1` at position 1, loop path `1 → 2`, path out `1 → 3`, whose `br`
enters the second header. -/
def loop1 : LoopSeg := ⟨1, 1, c2H.obls, c2H, [(2, c2B.obls, c2B)], [(3, c2M.obls, c2M)], []⟩

/-- The second loop: header `4` at position 1, loop path `4 → 5`, path out `4 → 6` to `ret`
(block 6's summary, `ret void` alone, is `Kernels.vadd.b3`). -/
def loop2 : LoopSeg :=
  ⟨4, 1, c2G.obls, c2G, [(5, c2D.obls, c2D)], [(6, Kernels.vadd.b3.obls, Kernels.vadd.b3)], []⟩

/-- The two loops after the entry block `0` (`LoopChain`), whose summary, a `br` into the first
header, is `cnt`'s entry block's (`cntE`). -/
def cnt2C : LoopChain := ⟨0, cntE.obls, cntE, [], [loop1, loop2]⟩

/-- `coversChains` accepts the two loops: they start at `cnt2`'s first block, and the path
checker with `phi`s accepts the entry block, both loop paths and both paths out. -/
theorem cnt2_covers : coversChains cnt2P cnt2 [cnt2C] = true := by
  decide +kernel

/-- The number in the `i64` cell `j` of block `b` of memory `me`, if a load there gives one. -/
def cell2 (me : Mem) (b j : Nat) : Option Nat :=
  match me.load cnt2P.layout ctx2.who 1 (.int 64) ⟨b, 8 * j⟩ (some 8) with
  | .ok (.bits _ x) => some x.toNat
  | _ => none

/-- A run of effects that a decision of `Q` accepts, for every decidable predicate `Q` on
memories and result `r`: `r` is `.ok me` with `Q me` (the kernel evaluates the premise on a
concrete run). -/
theorem run_ok {Q : Mem → Prop} [DecidablePred Q] {r : Except Fault Mem}
    (h : (match r with | .ok me => decide (Q me) | .error _ => false) = true) :
    ∃ me, r = .ok me ∧ Q me := by
  cases r with
  | error e => cases h
  | ok me => exact ⟨me, rfl, of_decide_eq_true h⟩

/-- The run of the two loops from `frame2`'s entry valuation to `ret` (`RetLs`), each loop with
no nested loop by `ChainWith.of_rounds` (the invariant: the iterates of its header's entry
valuation) and trip count 2: the premises of the entry, of each round and of each path out are
evaluated by the kernel, and so are the cells of the memory the `ret` leaves (`run_ok`). -/
theorem cnt2_retLs : RetLs (fun me => ∀ j < 2, cell2 me out2.2 j = some j ∧
    cell2 me out3.2 j = some j) [loop1, loop2] (Valuation.entry ctx2 0 out3.1 frame2) 0
    cntE.obls cntE [] :=
  ChainWith.of_rounds (contract := false) (by rfl) 2 (by decide +kernel)
    (ChainWith.of_rounds (by rfl) 2 (by decide +kernel)
      (ChainWith.last (by refine ⟨?_, ?_, run_ok ?_⟩ <;> decide +kernel)))

/-- **Two loops in sequence** (`Runs.of_chainsWith` with `cnt2_covers` and `cnt2_retLs`): the thread
whose one frame is `frame2` runs on `out3`'s memory to its end, and in the memory it leaves cells
0 and 1 of both blocks hold 0 and 1. -/
theorem cnt2_run : ∃ m', Runs ctx2 ⟨[frame2], 0⟩ out3.1 m' ∧
    ∀ j < 2, cell2 m' out2.2 j = some j ∧ cell2 m' out3.2 j = some j :=
  Runs.of_chainsWith (contract := false) (P := cnt2P) (c := ctx2) (t := ⟨[frame2], 0⟩)
    (f := frame2) rfl cnt2_covers rfl rfl rfl rfl rfl ⟨cnt2C, List.mem_singleton.2 rfl, cnt2_retLs⟩

/-- **The twins.** The first loop alone does not run to `ret`, for every predicate and valuation:
its path out ends at block `3`, whose exit goes to the second header (the invariant holds at the
trip count, by induction from its premises, so `Ret`'s `ret` premise is reached). The path
checker refuses the second loop's path from its header's position 0, its `phi`. -/
theorem cnt2_twins :
    (∀ (Q : Mem → Prop) (V : Valuation), ¬ RetLs Q [loop1] V 0 cntE.obls cntE []) ∧
    coversChains cnt2P cnt2 [{ cnt2C with loops := [loop1, { loop2 with p := 0 }] }] = false := by
  refine ⟨fun Q V => ?_, by decide +kernel⟩
  rintro (_ | ⟨I, n, -, h0, hr, hx⟩)
  have hI : ∀ i ≤ n, ∃ W, I i W := by
    intro i
    induction i with
    | zero => exact fun _ => ⟨_, h0⟩
    | succ i ih =>
      intro hi
      obtain ⟨W, hW⟩ := ih (by omega)
      have h1 : ChainWith false _ [] _ _ _ _ _ := hr i (by omega) W hW
      cases h1 with
      | last h =>
        obtain ⟨-, hJ⟩ := h
        exact ⟨_, hJ⟩
  obtain ⟨W, hW⟩ := hI n le_rfl
  cases hx W hW with
  | last h =>
    obtain ⟨-, hX, -⟩ := h
    exact absurd hX (by show c2M.exit ≠ .ret; decide +kernel)

/-! ## Two nested loops -/

/-- Two nested counting loops: `for i in [0, n): for j in [0, n): p[j] = i`. The outer header `1`
branches into the inner header `2` (both start with a `phi`) or to the exit `5`; the inner
header branches to the body `3`, whose back edge goes to `2`, or to the latch `4`, which
increments `%i` and branches back to `1`. -/
def nest : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "nest", params := [],
    group := none,
    names := #["entry", "outer", "inner", "body", "latch", "exit", "i", "inext", "c", "n", "j",
      "jnext", "d", "p", "q"],
    blocks := #[⟨0, #[], .br 1⟩,
      ⟨1, #[{ res := some 6, inst := .phi (.int 64) [(.int 0, 0), (.loc 7, 4)] },
        { res := some 8, inst := .icmp .slt (.int 64) (.loc 6) (.loc 9) }],
        .condBr (.loc 8) 2 5⟩,
      ⟨2, #[{ res := some 10, inst := .phi (.int 64) [(.int 0, 1), (.loc 11, 3)] },
        { res := some 12, inst := .icmp .slt (.int 64) (.loc 10) (.loc 9) }],
        .condBr (.loc 12) 3 4⟩,
      ⟨3, #[{ res := some 11, inst := .bin .add { nsw := true } (.int 64) (.loc 10) (.int 1) },
        { res := some 14,
          inst := .gep {} (.int 64) (.mk (.ptr 1) (.loc 13)) [.mk (.int 64) (.loc 10)] },
        { res := none,
          inst := .store false (.mk (.int 64) (.loc 6)) (.mk (.ptr 1) (.loc 14)) (some 8) }],
        .br 2⟩,
      ⟨4, #[{ res := some 7, inst := .bin .add { nsw := true } (.int 64) (.loc 6) (.int 1) }],
        .br 1⟩,
      ⟨5, #[], .ret none⟩] }

/-- The program of `nest` alone. -/
def nestP : Program := .ofFunc nest

/-- The context: `ctx0` with `nestP`. -/
def ctxT : Ctx := { ctx0 with prog := nestP }

/-- The frame at the entry block's position 0 with the bound `%n = 2` and `%p` at `out2`'s
block. -/
def frameT : Frame :=
  ⟨nest, 0, 0,
    fun r => if r = 9 then some (.bits 64 (BitVec.ofNat 64 2))
      else if r = 13 then some (.ptr ⟨out2.2, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- The outer header from position 1, after its `phi`; its `condBr` enters the inner header
(`Exit.phi`). -/
sym_summary nH := nestP nest 1 1

/-- The inner header from position 1, after its `phi`. -/
sym_summary nG := nestP nest 2 1

/-- The inner body: the increment of `%j`, the address of cell `%j`, the store of `%i`, the back
edge. -/
sym_summary nB := nestP nest 3 0

/-- The latch: the increment of `%i` and the back edge into the outer header. -/
sym_summary nM := nestP nest 4 0

/-- The inner loop: header `2` at position 1, loop path `2 → 3`, path out `2 → 4`, whose `br`
goes back to the outer header. -/
def loopJ : LoopSeg := ⟨2, 1, nG.obls, nG, [(3, nB.obls, nB)], [(4, nM.obls, nM)], []⟩

/-- The outer loop: header `1` at position 1, whose round is the header alone, then the inner
loop (`inner`), and whose path out `1 → 5` goes to `ret` (block 5's summary, `ret void` alone, is
`Kernels.vadd.b3`). -/
def loopI : LoopSeg :=
  ⟨1, 1, nH.obls, nH, [], [(5, Kernels.vadd.b3.obls, Kernels.vadd.b3)], [loopJ]⟩

/-- The outer loop after the entry block `0` (`LoopChain`), whose summary, a `br` into the outer
header, is `cnt`'s entry block's (`cntE`). -/
def nestC : LoopChain := ⟨0, cntE.obls, cntE, [], [loopI]⟩

/-- `coversChains` accepts the nested loops: they start at `nest`'s first block, and the path
checker with `phi`s accepts the entry block, the outer header from position 1, the inner loop
path `2 → 3` and path out `2 → 4` from position 1, and the outer path out `1 → 5`. -/
theorem nest_covers : coversChains nestP nest [nestC] = true := by
  decide +kernel

/-- The outer header's entry valuation after the entry edge from `frameT`'s entry valuation on
`out2`'s memory (`%i = 0`). -/
def hdrT : Valuation := Valuation.round 0 cntE [] (Valuation.entry ctxT 0 out2.1 frameT)

/-- One round of the outer loop from the outer header's entry valuation `W`: the header, two
rounds of the inner loop, and the inner loop's path out with the latch's edge into the outer
header. -/
def outerT (W : Valuation) : Valuation :=
  Valuation.round 2 nG [(4, nM.obls, nM)]
    ((Valuation.round 2 nG [(3, nB.obls, nB)])^[2] (Valuation.round 1 nH [] W))

/-- The premises of the outer loop's rounds `i < 2` from `hdrT`, evaluated by the kernel: the
outer header's edge into the inner header at position 1, the inner loop's two rounds, and the
inner path out's edge into the outer header at position 1. -/
theorem nest_rounds : ∀ i < 2,
    (Edge 2 1 (outerT^[i] hdrT) 1 nH.obls nH [] ∧
      ∀ j < 2, Round 2 1 nG.obls nG [(3, nB.obls, nB)]
        ((Valuation.round 2 nG [(3, nB.obls, nB)])^[j]
          (Valuation.round 1 nH [] (outerT^[i] hdrT)))) ∧
    Edge 1 1 ((Valuation.round 2 nG [(3, nB.obls, nB)])^[2]
      (Valuation.round 1 nH [] (outerT^[i] hdrT))) 2 nG.obls nG [(4, nM.obls, nM)] := by
  decide +kernel

/-- The run of the nested loops from `frameT`'s entry valuation to `ret` (`RetLs`): the outer
loop by `ChainWith.of_iter` with round function `outerT` and trip count 2, each of its rounds by
`ChainWith.of_rounds` on the inner loop with trip count 2 (`nest_rounds`), and the outer path out to
`ret` with the cells of the memory it leaves (`run_ok`), by `decide +kernel`. -/
theorem nest_retLs : RetLs (fun me => ∀ j < 2, cell2 me out2.2 j = some 1) [loopI]
    (Valuation.entry ctxT 0 out2.1 frameT) 0 cntE.obls cntE [] :=
  ChainWith.of_iter (contract := false) outerT 2 (by decide +kernel)
    (fun i hi => ChainWith.of_rounds (L := loopJ) (by rfl) 2 (nest_rounds i hi).1
      (ChainWith.last ⟨(nest_rounds i hi).2, rfl⟩))
    (ChainWith.last (by refine ⟨?_, ?_, run_ok ?_⟩ <;> decide +kernel))

/-- **Two nested loops** (`Runs.of_chainsWith` with `nest_covers` and `nest_retLs`): the thread
whose one frame is `frameT` runs on `out2`'s memory to its end, and in the memory it leaves cells
0 and 1 hold 1, the outer counter's last value. -/
theorem nest_run : ∃ m', Runs ctxT ⟨[frameT], 0⟩ out2.1 m' ∧ ∀ j < 2, cell2 m' out2.2 j = some 1 :=
  Runs.of_chainsWith (contract := false) (P := nestP) (c := ctxT) (t := ⟨[frameT], 0⟩)
    (f := frameT) rfl nest_covers rfl rfl rfl rfl rfl ⟨nestC, List.mem_singleton.2 rfl, nest_retLs⟩

/-- **The twins.** Without its nested loop, the outer loop does not run to `ret` from
`frameT`'s entry valuation, for every predicate: with trip count 0 the outer path out fails at
`%i = 0 < 2`, and otherwise the first round's path, the header alone, does not go back to the
header. The path checker refuses the inner loop's paths from its header's position 0, its `phi`:
`coversChains` checks the nested loop's paths. -/
theorem nest_twins :
    (∀ Q : Mem → Prop, ¬ RetLs Q [{ loopI with inner := [] }]
      (Valuation.entry ctxT 0 out2.1 frameT) 0 cntE.obls cntE []) ∧
    coversChains nestP nest
      [{ nestC with loops := [{ loopI with inner := [{ loopJ with p := 0 }] }] }] = false := by
  refine ⟨fun Q => ?_, by decide +kernel⟩
  rintro (_ | ⟨I, n, -, h0, hr, hx⟩)
  cases n with
  | zero =>
    cases hx _ h0 with
    | last h =>
      obtain ⟨hW, -⟩ := h
      exact absurd hW (by decide +kernel)
  | succ n =>
    have h1 : ChainWith false _ [] _ _ _ _ _ := hr 0 (Nat.zero_lt_succ n) _ h0
    cases h1 with
    | last h =>
      obtain ⟨hE, -⟩ := h
      exact absurd hE (by decide +kernel)

/-- The back edge of `cnt` is the body's branch to the header, its one cut point. -/
theorem cnt_back : backEdges cnt = [(2, 1)] ∧ cutPoints cnt = [1] := by
  decide +kernel

/-- The back edge of the naive matmul kernel is `%52 → %46`, its one cut point `%46`. -/
theorem naive_back :
    backEdges naive.fn_0 = [(naive.fn_0.b_6.label, naive.fn_0.b_3.label)] ∧
    cutPoints naive.fn_0 = [naive.fn_0.b_3.label] := by
  decide +kernel

/-- The verdict `#mojo_info` prints on `%51`, a `br` into the `phi` block `%67`: in the fragment. -/
theorem naive_out_refusal : refusal naive.prog naive.fn_0 naive.fn_0.b_5 0 = none := by
  decide +kernel

/-- **The latch outside the fragment**: the checker runs the naive kernel's latch `%52` past
its integer `select` (statement 2, `%55`) and refuses it at statement 12, `%65 = fmul contract`,
whose product feeds `%66 = fadd contract` at statement 13. -/
theorem naive_latch_refusal : refusal naive.prog naive.fn_0 naive.fn_0.b_6 0 = some 12 := by
  decide +kernel

end MojoProofTest.SymLoop
