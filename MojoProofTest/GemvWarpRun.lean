import MojoProof.Sym.LaneFrame
import MojoProofTest.GemvThread
import MojoProofTest.GemvShfl
import MojoProofTest.GemvOut

/-!
# gemv_kernel's warp at every `K`

A warp of gemv_kernel (`gemv`, MojoProofTest/SymLane.lean, gemv_kernel float32 `b79a852b`), its
32 lanes from position 0 of `%6` to their `ret`, through their seven shuffles
(`WarpRun.of_waits`, MojoProof/Sym/Canon.lean, with `J = 7` and blocks `%6`, label 6, for the
first two and `%78`, label 65, after). Each lane runs as `MojoProofTest.GemvThread.run` states
it (`Lanes.lane`), and `warp` joins them:

* `Lanes`: a warp's data (launch, first thread, contexts, threads, start memory, sizes, output
  block, matrix, vector, row), and `Lanes.Pre` the premises, those of `run` at every lane: in
  particular the warp's own `alloca` numbers have no block (`hfresh`), while blocks at other
  numbers from `next` on (an earlier warp's dead slots) may be present (`w0_not_free`). A
  buffer at one of those numbers would not outlive the lane's `alloca`s (`slots_buffer`);
* the memories `Lanes.mem i j` at lane `j`'s `i`-th wait, one function of phase and lane: lane `j`
  starts after lanes `0` to `j - 1`'s `alloca`s (`mem0`), `%24` and `%25` deliver on the memory
  with every lane's (`mem0 32`), `%78`'s first shuffle waits on the memory the earlier lanes leave
  there (`mem2`, each lane's `waitAt`, MojoProof/Sym/WaitAt.lean), and each lane ends on the
  memory the earlier lanes' ends leave (`mem7`);
* the offered values `Lanes.X`: lane 0's row word halves at `%24` and `%25`
  (`MojoProofTest.GemvShfl.idx_row`), and at `%78`'s `i`-th shuffle the lane's sum `acc i`, the
  `addAt` chain of `MojoProofTest.GemvLoopTail.shfls` at the lane's context and step count with
  its partner's offers (`j ^^^ ofs i`) delivered;
* the frame facts: lane `j`'s `alloca` numbers are no other lane's (`Mem.fresh_inj`), so the
  earlier lanes' `alloca`s, ends and slot deaths keep its slots and the buffers
  (`EntryInv.frame`, `Mem.SameOff.chain`, MojoProof/Sym/LaneFrame.lean; `lane_slots`, shared
  with `Out.lane`), and the later lanes' ends keep lane 0's store (`step7`).

`warp`: the warp runs (`WarpRun`) from the start memory, and the output word at row `r` loads,
after every lane's end, as lane 0's `total` of its sum and its five partners' offers. After it:

* `warp_frame`: the memory after the warp (`mem7 32`) has the start's `next`, its blocks outside
  `p0` and the warp's `alloca` numbers, the output buffer, and every load from `p0` outside row
  `r`'s word;
* `Pre.later`: a later warp's premises on that memory, from its premises on the start memory and
  its threads being none of the warp's; `later_row`: row `r`'s word still loads after a later
  warp with another row;
* `Pre.of_start`: the premises of the warp from thread `k` of the grid's start (`Grid.start`,
  `ofStart`) at row `row (L.env k)`, from the caller's memory and the arguments, the lanes'
  part shared with `Out.Pre.of_start` (`start_lanes`); `row_lt` bounds the rows a launch writes;
* `grid_run`: at every one-dimensional launch, the grid's warps as one canonical run
  (`CanonRun`, by `CanonRun.of_inv`) from the start's memory, those whose row is `M` or more by
  `Out.warp` (below), after which each warp whose row `r : Fin M` is below `M` has its row word
  load as its lane 0's `word 0`; `grid_run_inv`: the same run's end memory also has every
  invariant of memories that `g`'s memory has and each warp's run keeps; `grid_done`: the
  start's grid to a done grid with that memory (`CanonRun.start_done`). There the rows are
  `n / 32` (`row_eq`), the warps' first threads are 32 apart (`warps_mem`, `warps_apart`), and a
  warp's premises move to the memory after an earlier warp of either kind (`Lanes.Pre.frame`,
  `Out.Pre.frame`).

`Out`: a warp whose row is `M` or more, with `Out.Pre` its premises (those of
`MojoProofTest.GemvOut.run` at every lane: no matrix or vector, `p0` a buffer, lane 0's row `M`
or more). `Out.warp`: its 32 lanes run (`WarpRun`, `WarpRun.of_waits` with `J = 2` at `%6`'s
two `idx` shuffles, label 6) from the start memory to `memE 32`, each lane from the memory the
earlier lanes' `alloca`s leave (`mem0`) to its end after `%42`'s branch to `%43` (`endAt`,
MojoProof/Sym/WaitAt.lean, on the memory the earlier lanes' ends leave). `Out.warp_frame`: that
memory has the start's `next` and its blocks outside the lanes' `alloca` numbers;
`Out.memE_ext`: each lane's end extends the trace by its accesses of its own `alloca` blocks only
(`Lanes.mem2_ext`: an in-range lane's run from `%25` to `%78`'s first shuffle, by those and its
reads of the matrix and the vector).
`Out.Pre.of_start`: the premises from the grid's start.

Instances: one block of 32 threads, `M = 1`, `K = 4`, row 0, on `GemvThread.run`'s instance
memory `m3` (`w0`, `w0_pre`, and from the grid's start `w0_start` and `w0_done`);
`fresh_mutant`, a buffer at lane 0's first `alloca` number, which lane 0's `alloca`s replace;
`w0_not_free`, the block from `next` on that the warp leaves;
and one block of 64 threads, `M = 2`, `K = 4`: the second warp's premises after the first
(`w64_next_pre`), both rows after both warps, and from the grid's start to a done grid with both
rows (`w64_done`); one block of 64 threads, `M = 1`, whose second warp has row 1 and takes
`%42`'s branch to `ret`, from the grid's start to a done grid with row 0 (`w64_out_done`).
-/

namespace MojoProofTest.GemvWarpRun

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvLoop MojoProofTest.GemvLoopTail MojoProofTest.GemvEntryRun
open MojoProofTest.GemvThread MojoProofTest.GemvWarp MojoProofTest.GemvShfl
open FloatLib.Floats.Formats.BinaryInterchange

/-- **Three `alloca`s give three slots**: gemv_kernel, for every context `c` whose address
oracle is below `2 ^ 60`, step `k`, memory `m` and three distinct block numbers: `slots` makes
the three blocks thread `c.who.thread`'s slots (`EntryInv` at the memory itself). -/
theorem slots_inv (c : Ctx) (k : Nat) (m : Mem) {b7 b8 b9 : Nat} (h78 : b7 ≠ b8) (h79 : b7 ≠ b9)
    (h89 : b8 ≠ b9) (ha : ∀ q, c.addr q < 2 ^ 60) :
    EntryInv c.who.thread b7 b8 b9 (slots c k m b7 b8 b9) (slots c k m b7 b8 b9) := by
  have hw : (gemv.prog.layout.ptr 0).1 = 64 := by rfl
  have key : ∀ (m' : Mem) (n al b a g : Nat), n ≤ 16 → (al = 4 ∨ al = 8) → a < 2 ^ 60 →
      g < 2 ^ 60 → (m'.alloc gemv.prog.layout 0 n al false false (.thread c.who.thread) a g
        (num := some b)).1.slot c.who.thread b n al = true := by
    intro m' n al b a g hn hal ha hg
    have h1 : a * al < 2 ^ 64 := by rcases hal with rfl | rfl <;> omega
    have h2 : g * al < 2 ^ 64 := by rcases hal with rfl | rfl <;> omega
    simp only [Mem.slot, Mem.alloc, Mem.set, hw]
    rw [Nat.mod_eq_of_lt h1, Nat.mod_eq_of_lt h2]
    simp
    rcases hal with rfl | rfl <;> omega
  have hb : ∀ (m' : Mem) (q b n al a g : Nat), q ≠ b →
      (m'.alloc gemv.prog.layout 0 n al false false (.thread c.who.thread) a g
        (num := some b)).1.blocks q = m'.blocks q :=
    fun m' q b _ _ _ _ h => by simp only [Mem.alloc, Mem.set, h, ↓reduceIte]
  refine ⟨?_, ?_, ?_, fun _ _ _ _ => rfl⟩
  · exact (Mem.slot_blocks (hb _ _ _ _ _ _ _ h79) _ _ _).trans
      ((Mem.slot_blocks (hb _ _ _ _ _ _ _ h78) _ _ _).trans
        (key _ 16 8 _ _ _ (by decide) (.inr rfl) (ha _) (ha _)))
  · exact (Mem.slot_blocks (hb _ _ _ _ _ _ _ h89) _ _ _).trans
      (key _ 4 4 _ _ _ (by decide) (.inl rfl) (ha _) (ha _))
  · exact key _ 4 4 _ _ _ (by decide) (.inl rfl) (ha _) (ha _)

/-- **A slot replaces a buffer**: gemv_kernel, for every context `c` whose address oracle is below
`2 ^ 60`, step `k`, memory `m`, three distinct block numbers, size, alignment and writability:
`slots`' memory has no buffer at `b7`, whatever block `m` has there, since `Mem.alloc` at a number
sets that block (a slot of thread `c.who.thread`, `slots_inv`, which no buffer is,
`Mem.Buffer.ne_slot`). So a buffer at a lane's `alloca` number does not outlive the lane's
`alloca`s: the twin of `Lanes.Pre.hfresh`. -/
theorem slots_buffer (c : Ctx) (k : Nat) (m : Mem) {b7 b8 b9 : Nat} (h78 : b7 ≠ b8)
    (h79 : b7 ≠ b9) (h89 : b8 ≠ b9) (ha : ∀ q, c.addr q < 2 ^ 60) {size al : Nat} {wr : Bool} :
    ¬ (slots c k m b7 b8 b9).Buffer b7 size al wr :=
  fun hB => hB.ne_slot (slots_inv c k m h78 h79 h89 ha).1 rfl

/-- **`out` keeps the output buffer**: for every layout `l`, thread, value, block numbers `p0`,
`b7`, `b8`, `b9` with `p0` not one of the three, offset, decidable `z`, memory `my`, size,
alignment, writability and layout `l'`: a buffer at `p0` in `my` that fits is one in `out`'s
memory, which stores into `p0` and changes the liveness of the three only. -/
theorem out_keeps {l : Layout} {w : Who} {x : Val} {p0 b7 b8 b9 : Nat} {o : Int} {z : Prop}
    [Decidable z] {my : Mem} {size al : Nat} {wr : Bool} {l' : Layout} (h7 : p0 ≠ b7)
    (h8 : p0 ≠ b8) (h9 : p0 ≠ b9) (hB : my.Buffer p0 size al wr) (hF : my.Fits l' p0 size) :
    (GemvThread.out l w x p0 b7 b8 b9 o z my).Buffer p0 size al wr ∧
      (GemvThread.out l w x p0 b7 b8 b9 o z my).Fits l' p0 size := by
  have hn : p0 ∉ [b9, b8, b7] := by simp [h7, h8, h9]
  have hk : ∀ me : Mem, ∀ x, me.blocks p0 = some x →
      ([b9, b8, b7].foldl (fun m b => m.setLive b false) me).blocks p0 = some x :=
    fun me x hx => (Mem.foldl_setLive_blocks hn).trans hx
  unfold GemvThread.out
  split_ifs with hz
  · split
    · rename_i me hs
      exact ⟨.of_block (hk _) (Mem.Buffer.of_store (p := ⟨p0, o⟩) hs hB),
        .of_block (hk _) (Mem.Fits.of_store (p := ⟨p0, o⟩) hs hF)⟩
    · exact ⟨.of_block (hk _) hB, .of_block (hk _) hF⟩
  · exact ⟨.of_block (hk _) hB, .of_block (hk _) hF⟩

/-- For every layouts, thread, value, block numbers, offset, decidable `z` and memory `my`:
`out` keeps the memory (`Mem.Keeps`: every block with its shape, `next`, and the numbers below
`next` with no block; `Mem.store_keeps`, `Mem.foldl_setLive_keeps`). -/
theorem keeps_out (l : Layout) (w : Who) (x : Val) (p0 b7 b8 b9 : Nat) (o : Int) (z : Prop)
    [Decidable z] (my : Mem) : my.Keeps (GemvThread.out l w x p0 b7 b8 b9 o z my) := by
  unfold GemvThread.out
  refine Mem.Keeps.trans ?_ (Mem.foldl_setLive_keeps _ _ _)
  split_ifs
  · split
    · rename_i me hs
      exact Mem.store_keeps hs
    · exact Mem.Keeps.refl _
  · exact Mem.Keeps.refl _

/-- For every layout, thread, value, block numbers, offset, decidable `z` and memory `my`:
`out`'s memory has `my`'s blocks outside `p0`, `b7`, `b8` and `b9` (`Mem.store_blocks`,
`Mem.foldl_setLive_blocks`). -/
theorem out_off (l : Layout) (w : Who) (x : Val) (p0 b7 b8 b9 : Nat) (o : Int) (z : Prop)
    [Decidable z] (my : Mem) :
    my.SameOff (fun q => q = p0 ∨ q = b7 ∨ q = b8 ∨ q = b9)
      (GemvThread.out l w x p0 b7 b8 b9 o z my) := by
  intro q hq
  simp only [not_or] at hq
  obtain ⟨h0, h7, h8, h9⟩ := hq
  unfold GemvThread.out
  rw [Mem.foldl_setLive_blocks (by simp [h7, h8, h9])]
  split_ifs
  · split
    · rename_i me hs
      exact Mem.store_blocks (p := ⟨p0, o⟩) hs (Ne.symm h0)
    · rfl
  · rfl

/-- gemv_kernel's module has no globals, so `Grid.start_free`'s premise on them holds. -/
theorem gemv_globals : ∀ g ∈ gemv.prog.module.globals.toList,
    g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef) := by
  intro g hg
  rw [show gemv.prog.module.globals.toList = [] from rfl] at hg
  cases hg

/-- **The rows a launch writes**: gemv_kernel, for every valid launch `L` whose block's `x` size
32 divides and every thread `n`: thread `n`'s row (`row`) is below `L.block .x / 32 * L.grid .x`
(`gemv_lt`, MojoProofTest/GPUProof/MixedRadix.lean). A warp with row `M` or more takes `%42`'s
branch to `%43` and `ret` after `%6`'s two `idx` shuffles, storing nothing but its slots. -/
theorem row_lt {L : Launch} (hL : L.Valid) (hx : 32 ∣ L.block .x) (n : Nat) :
    row (L.env n) < L.block .x / 32 * L.grid .x := by
  simp only [row, Launch.env, coord]
  exact MojoProofTest.GPUProof.MixedRadix.gemv_lt hx (Nat.mod_lt _ (hL.block_pos .x))
    (Nat.mod_lt _ (hL.grid_pos .x))

/-- **One-dimensional rows**: gemv_kernel, for every valid launch `L` whose blocks and grid are
one-dimensional (`y` and `z` sizes 1) and every thread `n` of the launch: thread `n`'s row
(`row`) is `n / 32`, so the warps' first threads, distinct multiples of 32, have distinct rows.
-/
theorem row_eq {L : Launch} (hL : L.Valid) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) {n : Nat}
    (hn : n < volume L.grid * volume L.block) : row (L.env n) = n / 32 := by
  have hb := hL.block_pos .x
  have hv : volume L.block = L.block .x := by simp only [volume, hby, hbz, Nat.mul_one]
  have hg : volume L.grid = L.grid .x := by simp only [volume, hgy, hgz, Nat.mul_one]
  rw [hv, hg] at hn
  have hq : n / L.block .x < L.grid .x := (Nat.div_lt_iff_lt_mul hb).2 hn
  simp only [row, Launch.env, coord, hv, Nat.mod_mod, Nat.mod_eq_of_lt hq, Nat.div_add_mod']

/-- **The warps' first threads**: for every launch `L` whose block size 32 divides and every `N`
that 32 divides, each first thread `k` of a warp among threads `0` to `N - 1` (`warps`) is a
multiple of 32 in its block and in the launch, and its 32 threads are below `N`. -/
theorem warps_mem {L : Launch} {N : Nat} (h32 : 32 ∣ volume L.block) (hN : 32 ∣ N) {k : Nat}
    (hk : k ∈ warps L N) : k % volume L.block % 32 = 0 ∧ k % 32 = 0 ∧ k + 32 ≤ N := by
  rw [warps, List.mem_filter, List.mem_range, decide_eq_true_eq] at hk
  have h1 : k % 32 = 0 := by rw [← Nat.mod_mod_of_dvd k h32]; exact hk.2
  obtain ⟨q, hq⟩ := hN
  exact ⟨hk.2, h1, by omega⟩

/-- **The warps are 32 threads apart**: for every launch `L` whose block size 32 divides and
every `N` that 32 divides, the warps' first threads (`warps`) increase by 32 or more: the `i`-th
plus 32 is at most the `j`-th for `i < j` (`List.pairwise_lt_range`, `warps_mem`). -/
theorem warps_apart {L : Launch} {N : Nat} (h32 : 32 ∣ volume L.block) (hN : 32 ∣ N)
    {i j : Nat} (hi : i < (warps L N).length) (hj : j < (warps L N).length) (hij : i < j) :
    (warps L N)[i] + 32 ≤ (warps L N)[j] := by
  have hp : (warps L N).Pairwise (· < ·) := List.pairwise_lt_range.filter _
  have hl := List.pairwise_iff_getElem.1 hp i j hi hj hij
  have h1 := (warps_mem h32 hN (List.getElem_mem hi)).2.1
  have h2 := (warps_mem h32 hN (List.getElem_mem hj)).2.1
  omega

/-- **The lanes from the grid's start**: gemv_kernel, for every launch `L`, argument values
`p0`, `bA`, `bV` (pointers at offset 0), `M`, any `%4` and `K`, caller's memory `m` with no block
from `next` on and the output buffer at `p0`, address choice `ch` below `2 ^ 60`, oracle, and
thread `k` whose 32 threads from `k` are in the launch, whose start gives `(g, c)`: the 32
threads' contexts run gemv at their threads' special registers, with distinct threads and
address oracles below `2 ^ 60`, the threads are at gemv's start with the arguments in their
registers, and `g`'s memory has a positive `next`, no block from `next` on and the output
buffer. The contexts come from `Grid.start_ctx` and `Grid.start_addr`, the frames and registers
from `Grid.start_thread` and `Grid.start_scalar` (each parameter is `noundef`, which keeps a
defined value), the buffer from `Grid.start_blocks`, and `next` from `Grid.start_free`. -/
theorem start_lanes {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    {k : Nat} (hkg : k + 32 ≤ volume L.grid * volume L.block) (hch : ∀ q, ch q < 2 ^ 60)
    (hm : m.FreeAbove) (hb0 : m.Buffer p0 (M * 4) 4 true) :
    (∀ j < 32, (c (k + j)).prog = gemv.prog) ∧ (∀ j < 32, (c (k + j)).env = L.env (k + j)) ∧
    (∀ i < 32, ∀ j < 32, (c (k + i)).who.thread = (c (k + j)).who.thread → i = j) ∧
    (∀ j < 32, ∀ q, (c (k + j)).addr q < 2 ^ 60) ∧
    (∀ j < 32, ∃ f : Frame, (Grid.thread g (k + j)).frames = [f] ∧ f.fn = gemv.fn_0 ∧
      f.label = gemv.fn_0.b_0.label ∧ f.pc = 0 ∧ f.allocas = [] ∧
      f.regs 0 = some (.ptr ⟨p0, 0⟩) ∧ f.regs 1 = some (.ptr ⟨bA, 0⟩) ∧
      f.regs 2 = some (.ptr ⟨bV, 0⟩) ∧ f.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)) ∧
      f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K))) ∧
    0 < g.mem.next ∧ g.mem.FreeAbove ∧ g.mem.Buffer p0 (M * 4) 4 true := by
  have hfree := Grid.start_free hs gemv_globals hm
  have hb0' := hb0.of_block fun _ hx => Grid.start_blocks hs hx
  refine ⟨fun j _ => (Grid.start_ctx hs _).1, fun j _ => (Grid.start_ctx hs _).2.2.1,
    fun i _ j _ h => ?_, fun j _ q => ?_, fun j hj => ?_, ?_, hfree, hb0'⟩
  · rw [(Grid.start_ctx hs _).2.1, (Grid.start_ctx hs _).2.1] at h
    exact Nat.add_left_cancel h
  · rw [Grid.start_addr hs]
    exact hch _
  · have hn : k + j < g.threads.size := by rw [Grid.start_size hs]; omega
    obtain ⟨f, hgt, hfn, hl, hpc, hal⟩ := Grid.start_thread hs hn
    have hf : (Grid.thread g (k + j)).frames = [f] := by rw [hgt]
    refine ⟨f, hf, hfn, Option.some.inj (hl.symm.trans rfl), hpc, hal, ?_, ?_, ?_, ?_, ?_⟩
    · exact Grid.start_scalar hs hn hf (i := 0) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar hs hn hf (i := 1) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar hs hn hf (i := 2) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar hs hn hf (i := 3) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar hs hn hf (i := 5) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
  · obtain ⟨blk, hb, -⟩ := hb0'
    refine Nat.pos_of_ne_zero fun h0 => ?_
    rw [hfree p0 (by omega)] at hb
    cases hb

/-- **A lane's slots among a warp's**: gemv_kernel, for every contexts `c`, first thread `k`,
threads `t` and memories `mm` where `mm (i + 1)` is `mm i` with lane `i`'s three `alloca` slots
(`slots`) at its numbers `B i e`, the `fresh` numbers of its thread at steps `t.k + e` on `mm 0`,
with the 32 lanes' threads distinct, their address oracles below `2 ^ 60` and no block of `mm 0`
at their numbers: for lane `j < 32` and every memory `me` with `mm 32`'s blocks outside lanes `0`
to `j - 1`'s numbers, `mm j` has `mm 0`'s `next`, lane `j`'s `fresh` numbers `B j e` and no
block at them, lane `j`'s three slots are its own in `me` (`EntryInv`, `slots_inv`,
`EntryInv.frame`), and `me` has every block of `mm 0` (`Mem.SameOff.chain`). -/
theorem lane_slots {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {mm : Nat → Mem}
    {B : Nat → Nat → Nat}
    (hB : ∀ i e, B i e = (mm 0).fresh (c (k + i)).who.thread ((t (k + i)).k + e))
    (hmm : ∀ i, mm (i + 1) = slots (c (k + i)) (t (k + i)).k (mm i) (B i 0) (B i 1) (B i 2))
    (hwho : ∀ i < 32, ∀ j < 32, (c (k + i)).who.thread = (c (k + j)).who.thread → i = j)
    (had : ∀ j < 32, ∀ q, (c (k + j)).addr q < 2 ^ 60)
    (hfresh : ∀ j < 32, ∀ e < 3, (mm 0).blocks (B j e) = none) {j : Nat} (hj : j < 32)
    {me : Mem}
    (hS : (mm 32).SameOff (fun q => ∃ i, i < j ∧ (q = B i 0 ∨ q = B i 1 ∨ q = B i 2)) me) :
    (mm j).next = (mm 0).next ∧
    EntryInv (c (k + j)).who.thread (B j 0) (B j 1) (B j 2) me me ∧
    (∀ e, (mm j).fresh (c (k + j)).who.thread ((t (k + j)).k + e) = B j e) ∧
    (∀ e < 3, (mm j).blocks (B j e) = none) ∧
    ∀ q x, (mm 0).blocks q = some x → me.blocks q = some x := by
  have hn : ∀ i, (mm i).next = (mm 0).next := fun i => by
    induction i with
    | zero => rfl
    | succ i ih => rw [hmm]; exact ih
  have hinj : ∀ {i i' e e'}, i < 32 → i' < 32 → B i e = B i' e' → i = i' ∧ e = e' := by
    intro i i' e e' hi hi' he
    simp only [hB, Mem.fresh, Nat.add_left_cancel_iff, Nat.pair_eq_pair] at he
    obtain rfl := hwho i hi i' hi' he.1
    exact ⟨rfl, by omega⟩
  have hch : ∀ a d, (mm a).SameOff (fun q => ∃ i, a ≤ i ∧ i < a + d ∧
      (q = B i 0 ∨ q = B i 1 ∨ q = B i 2)) (mm (a + d)) := fun a =>
    Mem.SameOff.chain (mm := mm) a fun i _ => hmm i ▸ slots_off _ _ _ _ _ _
  have hblk : ∀ {i q x}, i < 32 → (mm 0).blocks q = some x →
      ¬ (q = B i 0 ∨ q = B i 1 ∨ q = B i 2) := by
    rintro i q x hi hx (rfl | rfl | rfl) <;> rw [hfresh i hi _ (by decide)] at hx <;> cases hx
  have hnot : ∀ e i, i ≠ j → i < 32 → ¬ (B j e = B i 0 ∨ B j e = B i 1 ∨ B j e = B i 2) := by
    intro e i hij hi hT
    rcases hT with hT | hT | hT <;> exact hij (hinj hi hj hT.symm).1
  have hne : ∀ e e', e ≠ e' → B j e ≠ B j e' := fun e e' h' he => h' (hinj hj hj he).2
  have hI0 : EntryInv (c (k + j)).who.thread (B j 0) (B j 1) (B j 2) (mm 32) (mm 32) := by
    have hc := hch (j + 1) (31 - j)
    rw [show j + 1 + (31 - j) = 32 by omega, hmm j] at hc
    exact EntryInv.frame (slots_inv _ _ _ (hne 0 1 (by decide)) (hne 0 2 (by decide))
      (hne 1 2 (by decide)) (had j hj)) hc
      (fun ⟨i, h1, h2, hT⟩ => hnot 0 i (by omega) h2 hT)
      (fun ⟨i, h1, h2, hT⟩ => hnot 1 i (by omega) h2 hT)
      (fun ⟨i, h1, h2, hT⟩ => hnot 2 i (by omega) h2 hT)
  refine ⟨hn j, EntryInv.frame hI0 hS (fun ⟨i, hi, hT⟩ => hnot 0 i (by omega) (by omega) hT)
      (fun ⟨i, hi, hT⟩ => hnot 1 i (by omega) (by omega) hT)
      (fun ⟨i, hi, hT⟩ => hnot 2 i (by omega) (by omega) hT),
    fun e => (Mem.fresh_of_next (hn j) _ _).trans (hB j e).symm, fun e he => ?_,
    fun q x hx => hS.block (fun ⟨_, hi, hT⟩ => hblk (by omega) hx hT) x
      ((hch 0 32).block (fun ⟨_, _, hi, hT⟩ => hblk (by omega) hx hT) x hx)⟩
  have hc := hch 0 j
  rw [Nat.zero_add] at hc
  rw [hc _ (fun ⟨i, _, hi, hT⟩ => hnot e i (by omega) (by omega) hT)]
  exact hfresh j hj e he

/-- A warp of gemv_kernel's first thread, contexts, threads and start memory: what its lanes'
`alloca` numbers and the memories after their `alloca`s read, for the warps whose row is below
`M` (`Lanes`) and those whose row is `M` or more (`Out`). A test structure. -/
structure Alloc where
  /-- The warp from its first thread, contexts, threads and start memory. -/
  mk ::
  /-- The warp's first thread. -/
  k : Nat
  /-- The threads' contexts, by thread number. -/
  c : Nat → Ctx
  /-- The threads at their start, by thread number. -/
  t : Nat → Thread
  /-- The memory the warp starts on. -/
  m : Mem

namespace Alloc

variable (w : Alloc)

/-- Lane `j`'s `e`-th `alloca` number: the `fresh` number at its thread and step `t.k + e`. -/
def b (j e : Nat) : Nat := w.m.fresh (w.c (w.k + j)).who.thread ((w.t (w.k + j)).k + e)

/-- Lane `j`'s three `alloca` numbers, as a set. -/
def T (j q : Nat) : Prop := q = w.b j 0 ∨ q = w.b j 1 ∨ q = w.b j 2

/-- The memory after lanes `0` to `j - 1`'s `alloca`s, in turn. -/
def mem0 : Nat → Mem
  | 0 => w.m
  | j + 1 => slots (w.c (w.k + j)) (w.t (w.k + j)).k (mem0 j) (w.b j 0) (w.b j 1) (w.b j 2)

variable {w}

/-- For every warp, the lanes' `alloca`s keep `next`. -/
theorem mem0_next : ∀ j, (w.mem0 j).next = w.m.next
  | 0 => rfl
  | j + 1 => mem0_next j

/-- For every warp, start `a` and count `d`, lanes `a` to `a + d - 1`'s `alloca`s in turn change
only their numbers (`slots_off`). -/
theorem chain0 (a d : Nat) :
    (w.mem0 a).SameOff (fun q => ∃ i, a ≤ i ∧ i < a + d ∧ w.T i q) (w.mem0 (a + d)) :=
  Mem.SameOff.chain (mm := w.mem0) a (fun _ _ => slots_off _ _ _ _ _ _) d

/-- For every warp whose start memory has no block at its lanes' `alloca` numbers (lane `j`'s
`e`-th, for `j < 32` and `e < 3`: `Lanes.Pre.hfresh`, `Out.Pre.hfresh`), a number with a block
in the start memory is no lane's `alloca` number. -/
theorem T_block (hf : ∀ j < 32, ∀ e < 3, w.m.blocks (w.b j e) = none) {i q : Nat} (hi : i < 32)
    {x : Sem.Block} (hx : w.m.blocks q = some x) : ¬ w.T i q := by
  rintro (rfl | rfl | rfl) <;> rw [hf i hi _ (by decide)] at hx <;> cases hx

end Alloc

/-- A warp of gemv_kernel and its data: its first thread, contexts, threads and start memory
(`Alloc`), launch, sizes, output block, matrix, vector and row. A test structure. -/
structure Lanes extends Alloc where
  /-- The warp from its first thread, contexts, threads and start memory (`Alloc`), launch,
  sizes, output block, matrix, vector and row. -/
  mk ::
  /-- The launch. -/
  L : Launch
  /-- The matrix's rows. -/
  M : Nat
  /-- The matrix's columns. -/
  K : Nat
  /-- The output buffer's block. -/
  p0 : Nat
  /-- The matrix. -/
  A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]
  /-- The vector. -/
  v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]
  /-- The warp's row. -/
  r : Fin M

/-- A warp's first thread, contexts, threads and start memory (`Alloc`). -/
add_decl_doc Lanes.toAlloc

namespace Lanes

variable (w : Lanes)

/-- Lane `j`'s `laneid`. -/
def lid (j : Nat) : Nat := (w.L.env (w.k + j)).laneid

/-- Lane `j`'s step count at `%78`'s first shuffle, as `run` states it. -/
def n (j : Nat) : Nat :=
  (w.t (w.k + j)).k + 41 + 21 + 19 * ((w.K + 31 - w.lid j) / 32) +
    15 * ((w.K + 31) / 32 - (w.K + 31 - w.lid j) / 32)

/-- Lane `j`'s `%79`: the loop's sum of every 32nd factor pair of row `r` from pair `laneid`
(`dotLoop` with contraction, at the oracle numbers of its context from step `t.k + 41`). -/
def x (j : Nat) : Model FloatTy.float.fmt :=
  dotLoop true (oG (w.c (w.k + j)) ((w.t (w.k + j)).k + 41)) (Model.zero _ false)
    (stride 32 (w.lid j) (matVecPairs w.A w.v w.r))

/-- Lane `j`'s sum at `%78`'s `p`-th shuffle: `x j`, then `addAt` of its sum and its partner
`j ^^^ ofs (p + 2)`'s, at its context and step `n j + 4 p + 3` (`shfls`' chain). -/
def acc : Nat → Nat → Model FloatTy.float.fmt
  | 0, j => w.x j
  | p + 1, j =>
    addAt (w.c (w.k + j)) (w.n j + (4 * p + 3)) (acc p j) (acc p (j ^^^ ofs (p + 2)))

/-- What lane `j` offers at the `i`-th shuffle: the low and high halves of its row word at `%24`
and `%25` (`half`), its sum `acc (i - 2) j` after. -/
def X : Nat → Nat → Val
  | 0, j => half w.L w.k 0 j
  | 1, j => half w.L w.k 32 j
  | i + 2, j => .ofFloat .float (w.acc i j)

/-- The memory at lane `j`'s first `%78` shuffle, for the lanes before it in turn: lane `j`'s
`waitAt` from `mem0 j` with the deliveries of `%24` and `%25` (on `mem0 32` and on the memory
the earlier lanes leave). -/
noncomputable def mem2 : Nat → Mem
  | 0 => w.mem0 32
  | j + 1 => waitAt (w.c (w.k + j)) [(some (w.X 0 (src 0 j)), w.mem0 32),
      (some (w.X 1 (src 1 j)), mem2 j)] (w.t (w.k + j)) (w.mem0 j)

/-- The word lane `j` stores if it is lane 0: `total` of its sum and its partners' offers. -/
def word (j : Nat) : Model FloatTy.float.fmt :=
  total (w.c (w.k + j)) (w.n j) (w.x j) (w.acc 0 (j ^^^ ofs 2)) (w.acc 1 (j ^^^ ofs 3))
    (w.acc 2 (j ^^^ ofs 4)) (w.acc 3 (j ^^^ ofs 5)) (w.acc 4 (j ^^^ ofs 6))

/-- The memory after lanes `0` to `j - 1`'s ends, in turn (`out`). -/
noncomputable def mem7 : Nat → Mem
  | 0 => w.mem2 32
  | j + 1 => GemvThread.out gemv.prog.layout (w.c (w.k + j)).who (.ofFloat .float (w.word j)) w.p0
      (w.b j 0) (w.b j 1) (w.b j 2) ((w.r.val * 4 : Nat) : Int) (w.lid j = 0) (mem7 j)

/-- The memory at phase `i` before lane `j`: `WarpRun.of_waits`'s memories. -/
noncomputable def mem : Nat → Nat → Mem
  | 0, j => w.mem0 j
  | 1, _ => w.mem0 32
  | 2, j => w.mem2 j
  | 7, j => w.mem7 j
  | _, _ => w.mem2 32

/-- Lane `j`'s delivery at the `i`-th shuffle: its source lane's offer, on the memory after the
phase's last lane. -/
noncomputable def D (i j : Nat) : Option Val × Mem := (some (w.X i (src i j)), w.mem (i + 1) j)

/-- Lane `j`'s `i`-th wait, as `run` states it. -/
noncomputable def W (i j : Nat) : Piece.Wait :=
  ([(⟨17, .shfl .idx, [.bits 32 (BitVec.ofInt 32 (-1)), w.X 0 j, .bits 32 (BitVec.ofInt 32 0),
      .bits 32 (BitVec.ofInt 32 31)],
      slots (w.c (w.k + j)) (w.t (w.k + j)).k (w.mem0 j) (w.b j 0) (w.b j 1) (w.b j 2),
      w.D 0 j⟩ : Piece.Wait),
    (⟨18, .shfl .idx, [.bits 32 (BitVec.ofInt 32 (-1)), w.X 1 j, .bits 32 (BitVec.ofInt 32 0),
      .bits 32 (BitVec.ofInt 32 31)], (w.D 0 j).2, w.D 1 j⟩ : Piece.Wait)] ++
    shfls (w.c (w.k + j)) (w.n j) (w.x j) (w.acc 0 (j ^^^ ofs 2)) (w.acc 1 (j ^^^ ofs 3))
      (w.acc 2 (j ^^^ ofs 4)) (w.acc 3 (j ^^^ ofs 5)) (w.mem2 (j + 1)) (w.D 2 j) (w.D 3 j)
      (w.D 4 j) (w.D 5 j) (w.D 6 j)).getD i ⟨0, .shfl .idx, [], w.m, (none, w.m)⟩

/-- The warp of `w`'s launch, contexts, threads, sizes, output block, matrix and vector from
first thread `k'`, with row `r'`, on memory `m'`: a later warp of the same launch. -/
def later (k' : Nat) (r' : Fin w.M) (m' : Mem) : Lanes :=
  ⟨⟨k', w.c, w.t, m'⟩, w.L, w.M, w.K, w.p0, w.A, w.v, r'⟩

/-- The premises of the warp theorem, with the matrix and vector at blocks `bA` and `bV`: a valid
launch whose block size 32 divides, `k` a warp's first thread, the lanes' contexts running gemv
at their threads' special registers, with distinct threads and addresses below `2 ^ 60`, the
lanes at gemv's start (`run`'s frame premises), the bounds on `M` and `K`, `r` lane 0's row, and
the start memory: `next` positive, no block at the warp's own `alloca` numbers (`b j e`, `j < 32`,
`e < 3`), the buffers of `run` (`p0` writable, `bA` and `bV` read-only, holding `A` and `v`).
Blocks at other numbers from `next` on may be present (an earlier warp's dead slots). -/
structure Pre (bA bV : Nat) : Prop where
  /-- The premises from each of them. -/
  mk ::
  /-- The launch is valid. -/
  hL : w.L.Valid
  /-- 32 divides the block size. -/
  h32 : 32 ∣ volume w.L.block
  /-- `k` is a warp's first thread: its index in its block is a multiple of 32. -/
  hk : w.k % volume w.L.block % 32 = 0
  /-- The lanes' contexts run gemv's program. -/
  hcp : ∀ j < 32, (w.c (w.k + j)).prog = gemv.prog
  /-- Lane `j`'s context has thread `k + j`'s special registers. -/
  hce : ∀ j < 32, (w.c (w.k + j)).env = w.L.env (w.k + j)
  /-- The lanes' threads are distinct. -/
  hwho : ∀ i < 32, ∀ j < 32, (w.c (w.k + i)).who.thread = (w.c (w.k + j)).who.thread → i = j
  /-- The lanes' address oracles are below `2 ^ 60`. -/
  had : ∀ j < 32, ∀ q, (w.c (w.k + j)).addr q < 2 ^ 60
  /-- Each lane is at gemv's start: one frame, at pc 0 of `%6` with no `alloca` blocks, `%0`,
  `%1`, `%2` pointers at offset 0 of `p0`, `bA`, `bV`, `%3 = M` and `%5 = K`. -/
  hfr : ∀ j < 32, ∃ f : Frame, (w.t (w.k + j)).frames = [f] ∧ f.fn = gemv.fn_0 ∧
    f.label = gemv.fn_0.b_0.label ∧ f.pc = 0 ∧ f.allocas = [] ∧
    f.regs 0 = some (.ptr ⟨w.p0, 0⟩) ∧ f.regs 1 = some (.ptr ⟨bA, 0⟩) ∧
    f.regs 2 = some (.ptr ⟨bV, 0⟩) ∧ f.regs 3 = some (.bits 32 (BitVec.ofNat 32 w.M)) ∧
    f.regs 5 = some (.bits 32 (BitVec.ofNat 32 w.K))
  /-- `M < 2 ^ 31`. -/
  hM : w.M < 2 ^ 31
  /-- `K < 2 ^ 31`. -/
  hK : w.K < 2 ^ 31
  /-- `M K < 2 ^ 61`. -/
  hMK : w.M * w.K < 2 ^ 61
  /-- `r` is lane 0's row (`row`). -/
  hrow : row (w.L.env w.k) = w.r.val
  /-- `next` is positive. -/
  hnx : 0 < w.m.next
  /-- The warp's `alloca` numbers have no block: lane `j`'s `e`-th, for `j < 32` and `e < 3`. -/
  hfresh : ∀ j < 32, ∀ e < 3, w.m.blocks (w.b j e) = none
  /-- `p0` is a writable buffer of `M` words. -/
  hb0 : w.m.Buffer w.p0 (w.M * 4) 4 true
  /-- `p0` fits. -/
  hf0 : w.m.Fits gemv.prog.layout w.p0 (w.M * 4)
  /-- `bA` is a read-only buffer of `M K` words. -/
  hbA : w.m.Buffer bA (w.M * w.K * 4) 4 false
  /-- `bV` is a read-only buffer of `K` words. -/
  hbV : w.m.Buffer bV (w.K * 4) 4 false
  /-- `bA` fits. -/
  hfA : w.m.Fits gemv.prog.layout bA (w.M * w.K * 4)
  /-- `bV` fits. -/
  hfV : w.m.Fits gemv.prog.layout bV (w.K * 4)
  /-- `bA` holds `A`, row-major. -/
  hA : w.m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
    (rowMajor gemv.prog.layout (.fp .float) 0) w.A
  /-- `bV` holds `v`. -/
  hV : w.m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
    (rowMajor gemv.prog.layout (.fp .float) 0) w.v

variable {w}

/-- Under the premises, two lanes' `alloca` numbers are equal only at one lane and step
(`Mem.fresh_inj`, distinct threads). -/
theorem b_inj {bA bV : Nat} (h : w.Pre bA bV) {i j e e' : Nat} (hi : i < 32) (hj : j < 32)
    (he : w.b i e = w.b j e') : i = j ∧ e = e' := by
  have he' := he
  simp only [Alloc.b, Mem.fresh, Nat.add_left_cancel_iff, Nat.pair_eq_pair] at he'
  obtain rfl := h.hwho i hi j hj he'.1
  exact ⟨rfl, by omega⟩

/-- Under the premises, for `j ≤ 32`, every block of the start memory is `mem2 j`'s if `mem2 j`
has `mem0 32`'s blocks outside lanes `0` to `j - 1`'s `alloca` numbers (`Alloc.T_block`). -/
theorem keep {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j ≤ 32)
    (hS : (w.mem0 32).SameOff (fun q => ∃ i, i < j ∧ w.T i q) (w.mem2 j)) {q : Nat} :
    ∀ x, w.m.blocks q = some x → (w.mem2 j).blocks q = some x :=
  fun x hx => hS.block (fun ⟨_, hi, hT⟩ => Alloc.T_block h.hfresh (by omega) hx hT) x
    ((Alloc.chain0 (w := w.toAlloc) 0 32).block
      (fun ⟨_, _, hi, hT⟩ => Alloc.T_block h.hfresh (by omega) hx hT) x hx)

/-- Under the premises, lane `j < 32`'s `laneid` is `j` (`warp_lane`). -/
theorem lid_eq {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) : w.lid j = j := by
  have hs := h.hL.volume_pos
  have hk := h.hk
  have h32 := h.h32
  have hm := Nat.mod_lt w.k hs
  obtain ⟨h1, -⟩ := warp_lane (s := volume w.L.block) (k := w.k) (j := j) hs (by omega)
  show (w.k + j) % volume w.L.block % 32 = j
  rw [h1]
  omega

/-- **Lane `j` of the warp**: gemv_kernel, for every warp under the premises (`Lanes.Pre`) and lane
`j < 32` whose first `%78` shuffle's memory `mem2 j` has `mem0 32`'s blocks outside the earlier
lanes' `alloca` numbers: `run` applies at lane `j` from `mem0 j`, with lane 0's row halves
delivered on `mem0 32` and `mem2 j`. So `mem2 (j + 1)` has `mem2 j`'s blocks outside lane `j`'s
three numbers, on a last memory `mem7 j` with the output buffer the lane runs through its seven
waits `W i j` (`waits_range`) to its end, where lane 0 has stored its `word` at row `r`, and
`mem2 (j + 1)`'s trace extends `mem2 j`'s by lane `j`'s accesses of its three `alloca` blocks
(`SlotEv`) and reads of `bA` or `bV` (`ReadEv`) only. -/
theorem lane {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32)
    (hS : (w.mem0 32).SameOff (fun q => ∃ i, i < j ∧ w.T i q) (w.mem2 j)) :
    (w.mem2 j).SameOff (w.T j) (w.mem2 (j + 1)) ∧
    ((w.mem7 j).Buffer w.p0 (w.M * 4) 4 true → (w.mem7 j).Fits gemv.prog.layout w.p0 (w.M * 4) →
      RunsVia (w.c (w.k + j)) (fun m' => ∃ me, (w.lid j = 0 →
          (w.mem7 j).store gemv.prog.layout (w.c (w.k + j)).who 0 (.fp .float)
            (Val.ofFloat .float (w.word j)) ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
              .ok me) ∧
          (w.lid j ≠ 0 → me = w.mem7 j) ∧
          m' = [w.b j 2, w.b j 1, w.b j 0].foldl (fun m b => m.setLive b false) me)
        ((List.range 7).map fun i => (w.W i j).via gemv.fn_0 (if i < 2 then 6 else 65))
        (w.t (w.k + j)) (w.mem0 j)) ∧
    Ext (fun e => SlotEv (w.c (w.k + j)).who (w.b j 0) (w.b j 1) (w.b j 2) e ∨ ReadEv bA bV e)
      (w.mem2 j) (w.mem2 (j + 1)) := by
  obtain ⟨f, ht, hf, hlb, hpc, hfa, g0, g1, g2, g3, g5⟩ := h.hfr j hj
  obtain ⟨hn, hI, hb, hm, hk⟩ := lane_slots (mm := w.mem0) (B := w.b) (fun _ _ => rfl)
    (fun _ => rfl) h.hwho h.had h.hfresh hj hS
  have hd₁ : (w.D 0 j).1 = some (.bits 32 ((BitVec.ofNat 64 w.r.val).extractLsb' 0 32)) := by
    show some (half w.L w.k 0 0) = _
    rw [half, Nat.add_zero, h.hrow]
  have hd₂ : (w.D 1 j).1 = some (.bits 32 ((BitVec.ofNat 64 w.r.val).extractLsb' 32 32)) := by
    show some (half w.L w.k 32 0) = _
    rw [half, Nat.add_zero, h.hrow]
  obtain ⟨⟨hE, -, -, -, hX⟩, hR⟩ := run w.L h.hL (w.k + j) (w.c (w.k + j)) (h.hcp j hj) (h.hce j hj)
    (w.t (w.k + j)) (w.mem0 j) f ht hf hlb hpc hfa w.M w.K w.r.val w.p0 bA bV h.hM h.hK h.hMK
    w.r.isLt g0 g1 g2 g3 g5 (w.b j 0) (w.b j 1) (w.b j 2) (hb 0) (hb 1) (hb 2)
    (by rw [hn]; exact h.hnx) (hm 0 (by decide)) (hm 1 (by decide)) (hm 2 (by decide)) w.A w.v
    (w.D 0 j) (w.D 1 j) hd₁ hd₂ hI
    (.of_block (hk _) h.hb0) (.of_block (hk _) h.hf0) (.of_block (hk _) h.hbA)
    (.of_block (hk _) h.hbV) (.of_block (hk _) h.hfA) (.of_block (hk _) h.hfV)
    (.of_block (hk _) h.hA) (.of_block (hk _) h.hV)
  refine ⟨hE.off, fun hB hF => ?_, hX⟩
  have hr := hR (w.D 2 j) (w.D 3 j) (w.D 4 j) (w.D 5 j) (w.D 6 j) (w.acc 0 (j ^^^ ofs 2))
    (w.acc 1 (j ^^^ ofs 3)) (w.acc 2 (j ^^^ ofs 4)) (w.acc 3 (j ^^^ ofs 5)) (w.acc 4 (j ^^^ ofs 6))
    rfl rfl rfl rfl rfl hB hF
  rw [waits_range _ _ ⟨0, .shfl .idx, [], w.m, (none, w.m)⟩] at hr
  exact hr

/-- For every warp, a lane's end keeps the output block if it is not lane 0 and the output is not
one of its `alloca` blocks: it stores nothing, and its slot deaths are of other blocks. -/
theorem step7 {j : Nat} (hl : w.lid j ≠ 0) (hn : w.p0 ∉ [w.b j 2, w.b j 1, w.b j 0]) :
    (w.mem7 (j + 1)).blocks w.p0 = (w.mem7 j).blocks w.p0 := by
  show (GemvThread.out _ _ _ _ _ _ _ _ (w.lid j = 0) _).blocks _ = _
  rw [GemvThread.out, ite_eq_right hl]
  exact Mem.foldl_setLive_blocks hn

/-- For every warp, lane `j`'s `i`-th wait, for `i < 7`, is a shuffle of mode `mode i`. -/
theorem W_call {i : Nat} (hi : i < 7) (j : Nat) : (w.W i j).call.intr = .shfl (mode i) := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp and lane `j`, the lane's `i`-th wait, for `i < 7`, is at the `i`-th of
positions 17 and 18 of `%6` and 2, 6, 10, 14 and 18 of `%78`. -/
theorem W_pos {i : Nat} (hi : i < 7) (j : Nat) :
    (w.W i j).pos = [17, 18, 2, 6, 10, 14, 18].getD i 0 := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp, lane `j`'s `i`-th wait, for `i < 7`, has the arguments mask `-1`, lane `j`'s
offer `X i j`, `ofs i` and `31`. -/
theorem W_args {i : Nat} (hi : i < 7) (j : Nat) :
    (w.W i j).args = [.bits 32 (BitVec.ofInt 32 (-1)), w.X i j,
      .bits 32 (BitVec.ofInt 32 (ofs i)), .bits 32 (BitVec.ofInt 32 31)] := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp, lane `j`'s `i`-th wait, for `i < 7`, starts on `mem i (j + 1)` and has the
delivery `D i j`. -/
theorem W_mem {i : Nat} (hi : i < 7) (j : Nat) :
    (w.W i j).mem = w.mem i (j + 1) ∧ (w.W i j).dlv = w.D i j := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | exact ⟨rfl, rfl⟩

/-- For every warp, each phase `i < 7` starts on the memory the previous one ends on. -/
theorem mem_zero {i : Nat} (hi : i < 7) : w.mem (i + 1) 0 = w.mem i 32 := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For `i < 7`, the 32-bit `ofs i` has the word `ofs i`. -/
theorem ofs_word {i : Nat} (hi : i < 7) :
    (Val.bits 32 (BitVec.ofInt 32 (ofs i))).word? = some (ofs i) := by
  rcases i with _ | _ | _ | _ | _ | _ | _ | i <;> first | omega | decide

/-- **Lane `j`'s `i`-th wait, as `WarpRun.of_waits` takes it**: under the premises, for every
phase `i < 7` and lane `j < 32`, the wait is a shuffle of mode `mode i` at one position for every
lane, of mask `2 ^ 32 - 1`, lane `j`'s offer `X i j`, `ofs i` and `31`, and every declaration a
call finds by a name mapped to the shuffle delivers the source lane's offer (`deliver7`), the
wait's delivery. -/
theorem shape {bA bV : Nat} (h : w.Pre bA bV) {i j : Nat} (hi : i < 7) (hj : j < 32) :
    (w.W i j).call.intr = .shfl (mode i) ∧
      (w.W i j).pos = (w.W i 0).pos ∧ ∃ Mk Bv Cv b cl, (w.W i j).args = [Mk, w.X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (w.c (w.k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (w.c (w.k + j)).prog.intrinsics.lookup g = some (.shfl (mode i)) →
          (some (shflVal (warpLanes w.L w.k) (w.X i) (shflSource (mode i) j b cl))).mapM
            (withAttrs (w.c w.k).prog.layout (w.mem i (warpLanes w.L w.k).length) e.ret
              e.retAttrs) = .ok (w.W i j).dlv.1 := by
  have hp := h.hcp j hj
  obtain ⟨w', x', hx⟩ : ∃ (w' : Nat) (x' : BitVec w'), w.X i (src i j) = .bits w' x' := by
    rcases i with _ | _ | i <;> exact ⟨_, _, rfl⟩
  have hd := deliver7 h.hL.volume_pos h.h32 w.k (a := w.X i) hi hj hx (w.c w.k).prog.layout
    (w.mem i (warpLanes w.L w.k).length)
  refine ⟨W_call hi j, (W_pos hi j).trans (W_pos hi 0).symm, .bits 32 (BitVec.ofInt 32 (-1)),
    .bits 32 (BitVec.ofInt 32 (ofs i)), .bits 32 (BitVec.ofInt 32 31), ofs i, 31, W_args hi j,
    by decide, ofs_word hi, by decide, fun g e he hl => ?_⟩
  rw [(W_mem hi j).2]
  exact hd g e (by rwa [hp] at he) (by rwa [hp] at hl)

/-- Under the premises, the output block is no lane's `alloca` number: it has a block in the
start memory (`Pre.hb0`), and they have none (`Pre.hfresh`). -/
theorem p0_ne {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) {e : Nat} (he : e < 3) :
    w.p0 ≠ w.b j e := fun hq => by
  obtain ⟨_, hx, -⟩ := h.hb0
  rw [hq, h.hfresh j hj e he] at hx
  cases hx

/-- Under the premises, for `j ≤ 32`, `mem2 j` has `mem0 32`'s blocks outside lanes `0` to
`j - 1`'s `alloca` numbers (`lane`, by induction on `j`). -/
theorem mem2_off {bA bV : Nat} (h : w.Pre bA bV) :
    ∀ j ≤ 32, (w.mem0 32).SameOff (fun q => ∃ i, i < j ∧ w.T i q) (w.mem2 j)
  | 0, _ => fun _ _ => rfl
  | j + 1, hj =>
    have hS := mem2_off h j (by omega)
    (hS.mono fun _ ⟨i, hi, hT⟩ => ⟨i, by omega, hT⟩).trans
      ((lane h (by omega) hS).1.mono fun _ hT => ⟨j, by omega, hT⟩)

/-- Under the premises, for `j ≤ 32`, the output block is a writable buffer of `M` words that
fits in `mem7 j` (`keep` at `mem7 0 = mem2 32`, then `out_keeps`). -/
theorem mem7_out {bA bV : Nat} (h : w.Pre bA bV) :
    ∀ j ≤ 32, (w.mem7 j).Buffer w.p0 (w.M * 4) 4 true ∧
      (w.mem7 j).Fits gemv.prog.layout w.p0 (w.M * 4)
  | 0, _ => ⟨.of_block (keep h le_rfl (mem2_off h 32 le_rfl)) h.hb0,
      .of_block (keep h le_rfl (mem2_off h 32 le_rfl)) h.hf0⟩
  | j + 1, hj =>
    have ⟨hB, hF⟩ := mem7_out h j (by omega)
    out_keeps (p0_ne h (by omega) (by decide)) (p0_ne h (by omega) (by decide))
      (p0_ne h (by omega) (by decide)) hB hF

/-- **Lane `j`'s run**: gemv_kernel, for every warp under the premises (`Lanes.Pre`) and lane
`j < 32`: the lane runs from `mem0 j` through its seven waits `W i j` to its end, where lane 0
has stored its `word` at row `r` of `mem7 j` (`lane`, with `mem2_off` and `mem7_out`). -/
theorem lane_runs {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    RunsVia (w.c (w.k + j)) (fun m' => ∃ me, (w.lid j = 0 →
        (w.mem7 j).store gemv.prog.layout (w.c (w.k + j)).who 0 (.fp .float)
          (Val.ofFloat .float (w.word j)) ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
            .ok me) ∧
        (w.lid j ≠ 0 → me = w.mem7 j) ∧
        m' = [w.b j 2, w.b j 1, w.b j 0].foldl (fun m b => m.setLive b false) me)
      ((List.range 7).map fun i => (w.W i j).via gemv.fn_0 (if i < 2 then 6 else 65))
      (w.t (w.k + j)) (w.mem0 j) :=
  (lane h hj (mem2_off h j hj.le)).2.1 (mem7_out h j hj.le).1 (mem7_out h j hj.le).2

/-- **Lane `j`'s events**: gemv_kernel, for every warp under the premises (`Lanes.Pre`) and lane
`j < 32`: `mem2 (j + 1)`'s trace extends `mem2 j`'s by lane `j`'s accesses of its three `alloca`
blocks (`SlotEv`) and reads of `bA` or `bV` (`ReadEv`) only (`lane`, with `mem2_off`). -/
theorem mem2_ext {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    Ext (fun e => SlotEv (w.c (w.k + j)).who (w.b j 0) (w.b j 1) (w.b j 2) e ∨ ReadEv bA bV e)
      (w.mem2 j) (w.mem2 (j + 1)) :=
  (lane h hj (mem2_off h j hj.le)).2.2

/-- **Lane 0's store is the output block's last change**: gemv_kernel, for every warp under the
premises (`Lanes.Pre`): lane 0's store of its `word` at row `r` of `p0` on `mem7 0` succeeds,
and `mem7 32` has the stored memory's block at `p0`, since the later lanes store nothing and
their slot deaths are of other blocks (`step7`). -/
theorem store0 {bA bV : Nat} (h : w.Pre bA bV) :
    ∃ me, (w.mem7 0).store gemv.prog.layout (w.c w.k).who 0 (.fp .float)
        (Val.ofFloat .float (w.word 0)) ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) = .ok me ∧
      (w.mem7 32).blocks w.p0 = me.blocks w.p0 := by
  have hnl : ∀ j < 32, w.p0 ∉ [w.b j 2, w.b j 1, w.b j 0] := fun j hj => by
    simp only [List.mem_cons, List.not_mem_nil, or_false, not_or]
    exact ⟨p0_ne h hj (by decide), p0_ne h hj (by decide), p0_ne h hj (by decide)⟩
  obtain ⟨-, me, hst, -, -⟩ := RunsVia.final (lane_runs h (j := 0) (by decide))
  have hl0 : w.lid 0 = 0 := lid_eq h (by decide)
  have hs0 := hst hl0
  have h1 : (w.mem7 1).blocks w.p0 = me.blocks w.p0 := by
    show (GemvThread.out _ _ _ _ _ _ _ _ (w.lid 0 = 0) _).blocks _ = _
    rw [GemvThread.out, ite_eq_left hl0, hs0]
    exact Mem.foldl_setLive_blocks (hnl 0 (by decide))
  have hj : ∀ j, 1 ≤ j → j ≤ 32 → (w.mem7 j).blocks w.p0 = (w.mem7 1).blocks w.p0 := by
    intro j
    induction j with
    | zero => intro h1; omega
    | succ j ih =>
      intro _ hj
      rcases Nat.eq_zero_or_pos j with rfl | hj0
      · rfl
      · rw [step7 (by rw [lid_eq h (by omega)]; omega) (hnl j (by omega)), ih hj0 (by omega)]
  exact ⟨me, hs0, (hj 32 (by decide) le_rfl).trans h1⟩

/-- **gemv_kernel's warp at every `K`**: gemv_kernel, for every valid launch whose block size 32
divides, warp's first thread `k`, contexts, threads, sizes `M` and `K` within `run`'s bounds, row
`r` of lane 0, and memory with the matrix, vector and output buffers (`Lanes.Pre`): the warp's 32
lanes run (`WarpRun`) from the memory to `mem7 32`, each through its seven shuffles
(`WarpRun.of_waits`, with `J = 7` and blocks `%6`, label 6, for `i < 2` and `%78`, label 65,
after), and the word at row `r` of the output buffer then loads as lane 0's `total` of its sum
`x 0` and the offers of its partners 16, 8, 4, 2 and 1 (`acc`, the `addAt` chain of each
partner's own partners). The later lanes' ends keep lane 0's store (`store0`). -/
theorem warp {bA bV : Nat} (h : w.Pre bA bV) :
    ∃ Es, WarpRun w.L w.c w.k w.t w.m Es (w.mem7 32) ∧
      (w.mem7 32).load gemv.prog.layout (w.c w.k).who 0 (.fp .float)
        ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
        .ok (Val.ofFloat .float (total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8)
          (w.acc 2 4) (w.acc 3 2) (w.acc 4 1))) := by
  have hs := h.hL.volume_pos
  have hfull := warpLanes_full (L := w.L) hs h.h32 w.k
  have hr : ∀ j ∈ warpLanes w.L w.k, RunsVia (w.c (w.k + j)) (· = w.mem 7 (j + 1))
      ((List.range 7).map fun i => (w.W i j).via gemv.fn_0 (if i < 2 then 6 else 65))
      (w.t (w.k + j)) (w.mem 0 j) := by
    intro j hj
    rw [hfull, List.mem_range] at hj
    exact run_out (lane_runs h hj)
  obtain ⟨Es, hE⟩ := WarpRun.of_waits (J := 7) (fn := gemv.fn_0)
    (lbl := fun i => if i < 2 then 6 else 65) (mo := mode) (X := w.X) (M := w.mem) (W := w.W)
    (t := w.t) hr (fun i hi j hj => shape h hi (by rwa [hfull, List.mem_range] at hj))
    (fun i hi j _ => ⟨(W_mem hi j).1, by rw [(W_mem hi j).2]; rfl⟩)
    (fun i hi => by rw [hfull, List.length_range]; exact mem_zero hi)
  rw [hfull, List.length_range] at hE
  refine ⟨Es, hE, ?_⟩
  obtain ⟨me, hs0, hb⟩ := store0 h
  obtain ⟨blk, bs, hc, -⟩ := Mem.store_inv hs0
  exact Mem.load_store_codec_of_block (Layout.Codec.float _ .float) (w.word 0) hs0 hc hb

/-- Under the premises, for `j ≤ 32`, `mem2 j` has the start memory's `next`: each lane's run to
its first `%78` shuffle keeps it (`RunsVia.waitAt_next`, on `lane_runs`). -/
theorem mem2_next {bA bV : Nat} (h : w.Pre bA bV) : ∀ j ≤ 32, (w.mem2 j).next = w.m.next
  | 0, _ => Alloc.mem0_next 32
  | j + 1, hj => by
    have hr := lane_runs h (j := j) (by omega)
    rw [show List.range 7 = [0, 1] ++ 2 :: [3, 4, 5, 6] from rfl, List.map_append] at hr
    have hn := RunsVia.waitAt_next _ hr (Alloc.mem0_next j) fun e he => by
      simp only [List.map_cons, List.map_nil, List.mem_cons, List.not_mem_nil, or_false] at he
      rcases he with rfl | rfl
      · exact Alloc.mem0_next 32
      · exact mem2_next h j (by omega)
    exact hn

/-- Under the premises, every `mem7 j` has the start memory's `next` (`mem2_next`,
`keeps_out`). -/
theorem mem7_next {bA bV : Nat} (h : w.Pre bA bV) : ∀ j, (w.mem7 j).next = w.m.next
  | 0 => mem2_next h 32 le_rfl
  | j + 1 => by
    show (GemvThread.out _ _ _ _ _ _ _ _ (w.lid j = 0) _).next = _
    exact (keeps_out _ _ _ _ _ _ _ _ _ _).next.trans (mem7_next h j)

/-- For every warp and `j`, `mem7 j` has `mem7 0`'s blocks outside the output block and lanes
`0` to `j - 1`'s `alloca` numbers (`out_off`). -/
theorem mem7_off :
    ∀ j, (w.mem7 0).SameOff (fun q => q = w.p0 ∨ ∃ i, i < j ∧ w.T i q) (w.mem7 j)
  | 0 => fun _ _ => rfl
  | j + 1 => by
    refine Mem.SameOff.trans (m₂ := w.mem7 j) ?_ ?_
    · exact (mem7_off j).mono fun _ hq => hq.imp_right fun ⟨i, hi, hT⟩ => ⟨i, by omega, hT⟩
    · exact (out_off gemv.prog.layout (w.c (w.k + j)).who (.ofFloat .float (w.word j)) w.p0
        (w.b j 0) (w.b j 1) (w.b j 2) ((w.r.val * 4 : Nat) : Int) (w.lid j = 0) (w.mem7 j)).mono
        fun _ hq => hq.imp_right fun hT => ⟨j, by omega, hT⟩

/-- **The warp's frame**: gemv_kernel, for every warp under the premises (`Lanes.Pre`): the
memory after every lane's end (`mem7 32`) has the start memory's `next`, its blocks outside
the output block `p0` and the lanes' `alloca` numbers, `p0` a writable buffer of `M` words that
fits, and at `p0` the start memory's value at every load apart from row `r`'s word. -/
theorem warp_frame {bA bV : Nat} (h : w.Pre bA bV) :
    (w.mem7 32).next = w.m.next ∧
    w.m.SameOff (fun q => q = w.p0 ∨ ∃ j, j < 32 ∧ w.T j q) (w.mem7 32) ∧
    (w.mem7 32).Buffer w.p0 (w.M * 4) 4 true ∧
    (w.mem7 32).Fits gemv.prog.layout w.p0 (w.M * 4) ∧
    ∀ (wh : Who) (a : Nat) (t : Ty) (o : Int) (al : Option Nat) (v : Val),
      (o.toNat + gemv.prog.layout.stored t ≤ w.r.val * 4 ∨ w.r.val * 4 + 4 ≤ o.toNat) →
      w.m.load gemv.prog.layout wh a t ⟨w.p0, o⟩ al = .ok v →
      (w.mem7 32).load gemv.prog.layout wh a t ⟨w.p0, o⟩ al = .ok v := by
  refine ⟨mem7_next h 32, ?_, (mem7_out h 32 le_rfl).1, (mem7_out h 32 le_rfl).2, ?_⟩
  · have h1 := Alloc.chain0 (w := w.toAlloc) 0 32
    have h2 := mem2_off h 32 le_rfl
    have h3 := mem7_off (w := w) 32
    exact ((h1.mono fun _ ⟨i, _, hi, hT⟩ => .inr ⟨i, hi, hT⟩).trans
      (h2.mono fun _ ⟨i, hi, hT⟩ => .inr ⟨i, hi, hT⟩)).trans h3
  · intro wh a t o al v ho hv
    obtain ⟨x0, hx0, -⟩ := h.hb0
    have h0 : (w.mem7 0).blocks w.p0 = w.m.blocks w.p0 := by
      rw [hx0]
      exact keep h le_rfl (mem2_off h 32 le_rfl) x0 hx0
    obtain ⟨me, hs0, hb⟩ := store0 h
    have hv0 : (w.mem7 0).load gemv.prog.layout wh a t ⟨w.p0, o⟩ al = .ok v := by
      rw [Mem.load_of_block (p := ⟨w.p0, o⟩) h0]
      exact hv
    have hst : gemv.prog.layout.stored (.fp .float) = 4 := rfl
    have hme : me.load gemv.prog.layout wh a t ⟨w.p0, o⟩ al = .ok v :=
      Mem.load_store_apart hs0 (.inr (by
        show o.toNat + _ ≤ ((w.r.val * 4 : Nat) : Int).toNat ∨
          ((w.r.val * 4 : Nat) : Int).toNat + gemv.prog.layout.stored (.fp .float) ≤ o.toNat
        rw [hst, Int.toNat_natCast]
        exact ho)) hv0
    rw [Mem.load_of_block (p := ⟨w.p0, o⟩) hb]
    exact hme

/-- **A warp's premises on a later memory**: gemv_kernel, for every warp under the premises
(`Lanes.Pre`) on its memory and every memory `m'` with its `next`, its blocks outside the
output block `p0`, `p0` a writable buffer of `M` words that fits, and no block at the warp's
`alloca` numbers: the warp's premises hold on `m'` (its `alloca` numbers are the same, by
`Mem.fresh_of_next`, and the matrix and vector blocks, read-only so not `p0`, are kept). -/
theorem Pre.frame {bA bV : Nat} (h : w.Pre bA bV) {m' : Mem}
    (hn : m'.next = w.m.next)
    (hk : ∀ q, q ≠ w.p0 → ∀ x, w.m.blocks q = some x → m'.blocks q = some x)
    (hB : m'.Buffer w.p0 (w.M * 4) 4 true) (hF : m'.Fits gemv.prog.layout w.p0 (w.M * 4))
    (hf : ∀ j < 32, ∀ e < 3, m'.blocks (w.b j e) = none) :
    ({ w with m := m' } : Lanes).Pre bA bV := by
  have hro : ∀ q size, w.m.Buffer q size 4 false → q ≠ w.p0 := by
    rintro q size ⟨x, hx, -, -, -, hr, -⟩ rfl
    obtain ⟨y, hy, -, -, -, hr', -⟩ := h.hb0
    rw [hx] at hy
    cases hy
    exact absurd (hr.symm.trans hr') (by decide)
  exact
    { hL := h.hL, h32 := h.h32, hk := h.hk, hcp := h.hcp, hce := h.hce, hwho := h.hwho
      had := h.had, hfr := h.hfr, hM := h.hM, hK := h.hK, hMK := h.hMK, hrow := h.hrow
      hnx := by
        show 0 < m'.next
        rw [hn]
        exact h.hnx
      hfresh := fun j hj e he => by
        have hb : ({ w with m := m' } : Lanes).b j e = w.b j e := Mem.fresh_of_next hn _ _
        show m'.blocks (({ w with m := m' } : Lanes).b j e) = none
        rw [hb]
        exact hf j hj e he
      hb0 := hB, hf0 := hF
      hbA := .of_block (hk bA (hro _ _ h.hbA)) h.hbA
      hbV := .of_block (hk bV (hro _ _ h.hbV)) h.hbV
      hfA := .of_block (hk bA (hro _ _ h.hbA)) h.hfA
      hfV := .of_block (hk bV (hro _ _ h.hbV)) h.hfV
      hA := .of_block (hk bA (hro _ _ h.hbA)) h.hA
      hV := .of_block (hk bV (hro _ _ h.hbV)) h.hV }

/-- **The next warp's premises**: gemv_kernel, for every warp `w` under the premises
(`Lanes.Pre`) and every later warp of `w`'s launch from first thread `k'` with row `r'`
(`later`) whose premises hold on `w`'s start memory and whose lanes' threads are none of `w`'s:
the later warp's premises hold on the memory after `w`'s lanes (`mem7 32`). That memory has
`w`'s `next` (`warp_frame`), so the later warp's `alloca` numbers are the same, and they have
no block there: they are not `p0`, which has one, nor `w`'s numbers, of other threads
(`Mem.fresh`, `Nat.pair` injective). The output block stays a buffer, and the blocks outside `p0`
and `w`'s `alloca` numbers are kept (`Pre.frame`). -/
theorem Pre.later {bA bV : Nat} (h : w.Pre bA bV) {k' : Nat} {r' : Fin w.M}
    (h' : (w.later k' r' w.m).Pre bA bV)
    (hap : ∀ i < 32, ∀ j < 32, (w.c (k' + i)).who.thread ≠ (w.c (w.k + j)).who.thread) :
    (w.later k' r' (w.mem7 32)).Pre bA bV := by
  obtain ⟨hn, hS, hB, hF, -⟩ := warp_frame h
  refine h'.frame hn (fun q hq x hx => (hS q (by
      rintro (h0 | ⟨j, hj, hT⟩)
      · exact hq h0
      · exact Alloc.T_block h.hfresh hj hx hT)).trans hx) hB hF fun j hj e he => ?_
  have hq : w.m.blocks ((w.later k' r' w.m).b j e) = none := h'.hfresh j hj e he
  rw [hS _ ?_, hq]
  rintro (h0 | ⟨i, hi, hT⟩)
  · obtain ⟨_, hx, -⟩ := h.hb0
    rw [← h0, hq] at hx
    cases hx
  · rcases hT with hT | hT | hT <;>
    · simp only [Alloc.b, Lanes.later, Mem.fresh, Nat.add_left_cancel_iff,
        Nat.pair_eq_pair] at hT
      exact hap j hj i hi hT.1

/-- **An earlier warp's row still loads**: gemv_kernel, for every warp `w` under the premises
(`Lanes.Pre`) and every later warp (`later`) from first thread `k'` with another row `r' ≠ r`,
under the premises on `w`'s last memory `mem7 32`: after the later warp's lanes, the word at
row `r` loads as `w`'s lane 0's `total` (`warp` at `w`, then the later warp's `warp_frame`). -/
theorem later_row {bA bV : Nat} (h : w.Pre bA bV) {k' : Nat} {r' : Fin w.M}
    (h' : (w.later k' r' (w.mem7 32)).Pre bA bV) (hr : r' ≠ w.r) :
    ((w.later k' r' (w.mem7 32)).mem7 32).load gemv.prog.layout (w.c w.k).who 0 (.fp .float)
        ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
      .ok (Val.ofFloat .float (total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8)
        (w.acc 2 4) (w.acc 3 2) (w.acc 4 1))) := by
  obtain ⟨_, -, hv⟩ := warp h
  refine (warp_frame h').2.2.2.2 _ _ _ _ _ _ ?_ hv
  have hst : gemv.prog.layout.stored (.fp .float) = 4 := rfl
  have hne : r'.val ≠ w.r.val := fun e => hr (Fin.ext e)
  show ((w.r.val * 4 : Nat) : Int).toNat + gemv.prog.layout.stored (.fp .float) ≤ r'.val * 4 ∨
    r'.val * 4 + 4 ≤ ((w.r.val * 4 : Nat) : Int).toNat
  rw [hst, Int.toNat_natCast]
  omega

/-- The warp from thread `k` of the grid `g` that `Grid.start` gives with contexts `c`: its
threads `Grid.thread g`, on `g`'s memory, at sizes `M`, `K`, output block `p0`, matrix `A`,
vector `v` and row `r`. A test definition. -/
def ofStart (L : Launch) (g : Grid) (c : Nat → Ctx) (k M K p0 : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (r : Fin M) : Lanes :=
  ⟨⟨k, c, Grid.thread g, g.mem⟩, L, M, K, p0, A, v, r⟩

/-- **A warp's premises from the grid's start**: gemv_kernel, for every valid launch `L` whose
block size 32 divides, argument values `p0`, `bA`, `bV` (pointers at offset 0), `M`, any `%4`
and `K`, caller's memory `m` with no block from `next` on (`Mem.FreeAbove`), address choice
`ch` below `2 ^ 60`, oracle, and warp from thread `k` (a multiple of 32 in its block, its 32
threads in the launch) with row below `M`, whose start gives `(g, c)`: if `M`, `K` and `M K` are
in range and `m` has the writable output buffer and the read-only matrix and vector buffers,
which fit, the last two holding `A` and `v`, then the warp's premises (`Lanes.Pre`) hold on
`g`'s memory at row `row (L.env k)`. The lanes' contexts, frames, `next` and output buffer come
from `start_lanes`, the other buffers from `Grid.start_blocks`, and `hfresh` from
`Grid.start_free`. -/
theorem Pre.of_start {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (h32 : 32 ∣ volume L.block) {k : Nat} (hk : k % volume L.block % 32 = 0)
    (hkg : k + 32 ≤ volume L.grid * volume L.block) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61) (hr : row (L.env k) < M)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    (ofStart L g c k M K p0 A v ⟨row (L.env k), hr⟩).Pre bA bV := by
  obtain ⟨hcp, hce, hwho, had, hfr, hnx, hfree, hb0'⟩ := start_lanes hs ha hkg hch hm hb0
  have hkeep : ∀ q, ∀ x, m.blocks q = some x → g.mem.blocks q = some x :=
    fun _ _ hx => Grid.start_blocks hs hx
  exact
    { hL := hL, h32 := h32, hk := hk, hcp := hcp, hce := hce, hwho := hwho, had := had
      hfr := hfr, hM := hM, hK := hK, hMK := hMK, hrow := rfl, hnx := hnx
      hfresh := fun j _ e _ => hfree _ (Nat.le_add_right _ _)
      hb0 := hb0'
      hf0 := hf0.of_block (hkeep _)
      hbA := hbA.of_block (hkeep _)
      hbV := hbV.of_block (hkeep _)
      hfA := hfA.of_block (hkeep _)
      hfV := hfV.of_block (hkeep _)
      hA := hA.of_block (hkeep _)
      hV := hV.of_block (hkeep _) }

end Lanes

/-- A warp of gemv_kernel whose row is `M` or more, and its data: its first thread, contexts,
threads and start memory (`Alloc`), launch, sizes and output block. A test structure. -/
structure Out extends Alloc where
  /-- The warp from its first thread, contexts, threads and start memory (`Alloc`), launch,
  sizes and output block. -/
  mk ::
  /-- The launch. -/
  L : Launch
  /-- The matrix's rows. -/
  M : Nat
  /-- The matrix's columns. -/
  K : Nat
  /-- The output buffer's block. -/
  p0 : Nat

/-- A warp's first thread, contexts, threads and start memory (`Alloc`). -/
add_decl_doc Out.toAlloc

namespace Out

variable (w : Out)

/-- What lane `j` offers at the `i`-th shuffle: the low (`i = 0`) and high halves of its row
word (`half`). -/
def X : Nat → Nat → Val
  | 0, j => half w.L w.k 0 j
  | _, j => half w.L w.k 32 j

/-- The memory after lanes `0` to `j - 1`'s ends, in turn: lane `j`'s `endAt` from `mem0 j` with
the deliveries of `%24` and `%25` (on `mem0 32` and on the memory the earlier lanes leave). -/
noncomputable def memE : Nat → Mem
  | 0 => w.mem0 32
  | j + 1 => endAt (w.c (w.k + j)) [(some (w.X 0 (src 0 j)), w.mem0 32),
      (some (w.X 1 (src 1 j)), memE j)] (w.t (w.k + j)) (w.mem0 j)

/-- The memory at phase `i` before lane `j`: `WarpRun.of_waits`'s memories. -/
noncomputable def mem : Nat → Nat → Mem
  | 0, j => w.mem0 j
  | 1, _ => w.mem0 32
  | _, j => w.memE j

/-- Lane `j`'s delivery at the `i`-th shuffle: lane 0's offer, on the memory after the phase's
last lane. -/
noncomputable def D (i j : Nat) : Option Val × Mem := (some (w.X i (src i j)), w.mem (i + 1) j)

/-- Lane `j`'s `i`-th wait, as `MojoProofTest.GemvOut.run` states it. -/
noncomputable def W (i j : Nat) : Piece.Wait :=
  [(⟨17, .shfl .idx, [.bits 32 (BitVec.ofInt 32 (-1)), w.X 0 j, .bits 32 (BitVec.ofInt 32 0),
      .bits 32 (BitVec.ofInt 32 31)],
      slots (w.c (w.k + j)) (w.t (w.k + j)).k (w.mem0 j) (w.b j 0) (w.b j 1) (w.b j 2),
      w.D 0 j⟩ : Piece.Wait),
    (⟨18, .shfl .idx, [.bits 32 (BitVec.ofInt 32 (-1)), w.X 1 j, .bits 32 (BitVec.ofInt 32 0),
      .bits 32 (BitVec.ofInt 32 31)], (w.D 0 j).2, w.D 1 j⟩ : Piece.Wait)].getD i
    ⟨0, .shfl .idx, [], w.m, (none, w.m)⟩

/-- The premises of the warp theorem, with the matrix and vector at blocks `bA` and `bV`: a valid
launch whose block size 32 divides, the lanes' contexts running gemv at their threads' special
registers, with distinct threads and addresses below `2 ^ 60`, the lanes at gemv's start, the
bounds on `M` and `K`, lane 0's row `M` or more, and the start memory: `next` positive, no block
at the warp's own `alloca` numbers, `p0` a writable buffer of `M` words. -/
structure Pre (bA bV : Nat) : Prop where
  /-- The premises from each of them. -/
  mk ::
  /-- The launch is valid. -/
  hL : w.L.Valid
  /-- 32 divides the block size. -/
  h32 : 32 ∣ volume w.L.block
  /-- The lanes' contexts run gemv's program. -/
  hcp : ∀ j < 32, (w.c (w.k + j)).prog = gemv.prog
  /-- Lane `j`'s context has thread `k + j`'s special registers. -/
  hce : ∀ j < 32, (w.c (w.k + j)).env = w.L.env (w.k + j)
  /-- The lanes' threads are distinct. -/
  hwho : ∀ i < 32, ∀ j < 32, (w.c (w.k + i)).who.thread = (w.c (w.k + j)).who.thread → i = j
  /-- The lanes' address oracles are below `2 ^ 60`. -/
  had : ∀ j < 32, ∀ q, (w.c (w.k + j)).addr q < 2 ^ 60
  /-- Each lane is at gemv's start, as in `Lanes.Pre.hfr`. -/
  hfr : ∀ j < 32, ∃ f : Frame, (w.t (w.k + j)).frames = [f] ∧ f.fn = gemv.fn_0 ∧
    f.label = gemv.fn_0.b_0.label ∧ f.pc = 0 ∧ f.allocas = [] ∧
    f.regs 0 = some (.ptr ⟨w.p0, 0⟩) ∧ f.regs 1 = some (.ptr ⟨bA, 0⟩) ∧
    f.regs 2 = some (.ptr ⟨bV, 0⟩) ∧ f.regs 3 = some (.bits 32 (BitVec.ofNat 32 w.M)) ∧
    f.regs 5 = some (.bits 32 (BitVec.ofNat 32 w.K))
  /-- `M < 2 ^ 31`. -/
  hM : w.M < 2 ^ 31
  /-- `K < 2 ^ 31`. -/
  hK : w.K < 2 ^ 31
  /-- Lane 0's row (`row`) is `M` or more. -/
  hrow : w.M ≤ row (w.L.env w.k)
  /-- `next` is positive. -/
  hnx : 0 < w.m.next
  /-- The warp's `alloca` numbers have no block: lane `j`'s `e`-th, for `j < 32` and `e < 3`. -/
  hfresh : ∀ j < 32, ∀ e < 3, w.m.blocks (w.b j e) = none
  /-- `p0` is a writable buffer of `M` words. -/
  hb0 : w.m.Buffer w.p0 (w.M * 4) 4 true

variable {w}

/-- **Lane `j` of the warp whose row is `M` or more**: gemv_kernel, for every warp under the
premises (`Out.Pre`) and lane `j < 32` whose end memory `memE j` before it has `mem0 32`'s
blocks outside the earlier lanes' `alloca` numbers: `MojoProofTest.GemvOut.run` applies at lane
`j` from `mem0 j`, with lane 0's row halves delivered on `mem0 32` and `memE j`. So the lane
runs through its two waits `W i j` to its end `memE (j + 1)`, which has `memE j`'s blocks outside
lane `j`'s three numbers and a trace that extends `memE j`'s by lane `j`'s accesses of its three
blocks only (`SlotEv`; `RunsVia.endAt`). -/
theorem lane {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32)
    (hS : (w.mem0 32).SameOff (fun q => ∃ i, i < j ∧ w.T i q) (w.memE j)) :
    (w.memE j).SameOff (w.T j) (w.memE (j + 1)) ∧
    RunsVia (w.c (w.k + j)) (· = w.memE (j + 1))
      ((List.range 2).map fun i => (w.W i j).via gemv.fn_0 6) (w.t (w.k + j)) (w.mem0 j) ∧
    Ext (SlotEv (w.c (w.k + j)).who (w.b j 0) (w.b j 1) (w.b j 2)) (w.memE j)
      (w.memE (j + 1)) := by
  obtain ⟨f, ht, hf, hlb, hpc, hfa, g0, g1, g2, g3, g5⟩ := h.hfr j hj
  obtain ⟨hn, hI, hb, hm, hk⟩ := lane_slots (mm := w.mem0) (B := w.b) (fun _ _ => rfl)
    (fun _ => rfl) h.hwho h.had h.hfresh hj hS
  have hd₁ : (w.D 0 j).1 =
      some (.bits 32 ((BitVec.ofNat 64 (row (w.L.env w.k))).extractLsb' 0 32)) := by
    show some (half w.L w.k 0 0) = _
    rw [half, Nat.add_zero]
  have hd₂ : (w.D 1 j).1 =
      some (.bits 32 ((BitVec.ofNat 64 (row (w.L.env w.k))).extractLsb' 32 32)) := by
    show some (half w.L w.k 32 0) = _
    rw [half, Nat.add_zero]
  have hr' : row (w.L.env w.k) < 2 ^ 59 :=
    Nat.lt_of_le_of_lt (Nat.div_le_self _ 32)
      (Nat.lt_trans (Launch.index_lt h.hL w.k .x) (by decide))
  have hR := MojoProofTest.GemvOut.run w.L h.hL (w.k + j) (w.c (w.k + j)) (h.hcp j hj)
    (h.hce j hj) (w.t (w.k + j)) (w.mem0 j) f ht hf hlb hpc hfa w.M w.K (row (w.L.env w.k)) w.p0
    bA bV h.hM h.hK h.hrow hr' g0 g1 g2 g3 g5 (w.b j 0) (w.b j 1) (w.b j 2) (hb 0) (hb 1) (hb 2)
    (by rw [hn]; exact h.hnx) (hm 0 (by decide)) (hm 1 (by decide)) (hm 2 (by decide))
    (w.D 0 j) (w.D 1 j) hd₁ hd₂ hI (.of_block (hk _) h.hb0)
  have hE := RunsVia.endAt _ hR
  exact ⟨hE.2.1, hE.1, hE.2.2⟩

/-- Under the premises, for `j ≤ 32`, `memE j` has `mem0 32`'s blocks outside lanes `0` to
`j - 1`'s `alloca` numbers (`lane`, by induction on `j`). -/
theorem memE_off {bA bV : Nat} (h : w.Pre bA bV) :
    ∀ j ≤ 32, (w.mem0 32).SameOff (fun q => ∃ i, i < j ∧ w.T i q) (w.memE j)
  | 0, _ => fun _ _ => rfl
  | j + 1, hj =>
    have hS := memE_off h j (by omega)
    (hS.mono fun _ ⟨i, hi, hT⟩ => ⟨i, by omega, hT⟩).trans
      ((lane h (by omega) hS).1.mono fun _ hT => ⟨j, by omega, hT⟩)

/-- **Lane `j`'s run**: gemv_kernel, for every warp under the premises (`Out.Pre`) and lane
`j < 32`: the lane runs from `mem0 j` through its two waits `W i j` to its end `memE (j + 1)`
(`lane`, with `memE_off`). -/
theorem lane_runs {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    RunsVia (w.c (w.k + j)) (· = w.memE (j + 1))
      ((List.range 2).map fun i => (w.W i j).via gemv.fn_0 6) (w.t (w.k + j)) (w.mem0 j) :=
  (lane h hj (memE_off h j hj.le)).2.1

/-- **Lane `j`'s events**: gemv_kernel, for every warp under the premises (`Out.Pre`) and lane
`j < 32`: `memE (j + 1)`'s trace extends `memE j`'s by lane `j`'s accesses of its three `alloca`
blocks only (`SlotEv`; `lane`, with `memE_off`). -/
theorem memE_ext {bA bV : Nat} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    Ext (SlotEv (w.c (w.k + j)).who (w.b j 0) (w.b j 1) (w.b j 2)) (w.memE j) (w.memE (j + 1)) :=
  (lane h hj (memE_off h j hj.le)).2.2

/-- For every warp and lane `j`, the lane's `i`-th wait, for `i < 2`, starts on `mem i (j + 1)`
and has the delivery `D i j`. -/
theorem W_mem {i : Nat} (hi : i < 2) (j : Nat) :
    (w.W i j).mem = w.mem i (j + 1) ∧ (w.W i j).dlv = w.D i j := by
  rcases i with _ | _ | i <;> first | omega | exact ⟨rfl, rfl⟩

/-- For every warp, each phase `i < 2` starts on the memory the previous one ends on. -/
theorem mem_zero {i : Nat} (hi : i < 2) : w.mem (i + 1) 0 = w.mem i 32 := by
  rcases i with _ | _ | i <;> first | omega | rfl

/-- **Lane `j`'s `i`-th wait, as `WarpRun.of_waits` takes it**: under the premises, for every
phase `i < 2` and lane `j < 32`, the wait is an `idx` shuffle (`mode i`) at one position for
every lane, of mask `2 ^ 32 - 1`, lane `j`'s offer `X i j`, `0` and `31`, and every declaration
a call finds by a name mapped to the shuffle delivers lane 0's offer (`deliver7`), the wait's
delivery. -/
theorem shape {bA bV : Nat} (h : w.Pre bA bV) {i j : Nat} (hi : i < 2) (hj : j < 32) :
    (w.W i j).call.intr = .shfl (mode i) ∧
      (w.W i j).pos = (w.W i 0).pos ∧ ∃ Mk Bv Cv b cl, (w.W i j).args = [Mk, w.X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (w.c (w.k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (w.c (w.k + j)).prog.intrinsics.lookup g = some (.shfl (mode i)) →
          (some (shflVal (warpLanes w.L w.k) (w.X i) (shflSource (mode i) j b cl))).mapM
            (withAttrs (w.c w.k).prog.layout (w.mem i (warpLanes w.L w.k).length) e.ret
              e.retAttrs) = .ok (w.W i j).dlv.1 := by
  have hp := h.hcp j hj
  obtain ⟨w', x', hx⟩ : ∃ (w' : Nat) (x' : BitVec w'), w.X i (src i j) = .bits w' x' := by
    rcases i with _ | i <;> exact ⟨_, _, rfl⟩
  have hd := deliver7 h.hL.volume_pos h.h32 w.k (a := w.X i) (by omega) hj hx
    (w.c w.k).prog.layout (w.mem i (warpLanes w.L w.k).length)
  have hargs : (w.W i j).args = [.bits 32 (BitVec.ofInt 32 (-1)), w.X i j,
      .bits 32 (BitVec.ofInt 32 (ofs i)), .bits 32 (BitVec.ofInt 32 31)] := by
    rcases i with _ | _ | i <;> first | omega | rfl
  refine ⟨by rcases i with _ | _ | i <;> first | omega | rfl,
    by rcases i with _ | _ | i <;> first | omega | rfl, .bits 32 (BitVec.ofInt 32 (-1)),
    .bits 32 (BitVec.ofInt 32 (ofs i)), .bits 32 (BitVec.ofInt 32 31), ofs i, 31, hargs,
    by decide, Lanes.ofs_word (by omega), by decide, fun g e he hl => ?_⟩
  rw [(W_mem hi j).2]
  exact hd g e (by rwa [hp] at he) (by rwa [hp] at hl)

/-- **gemv_kernel's warp whose row is `M` or more**: gemv_kernel, for every valid launch whose
block size 32 divides, warp's first thread `k`, contexts, threads, sizes `M` and `K` below
`2 ^ 31`, lane 0's row `M` or more, and memory with the output buffer (`Out.Pre`): the warp's
32 lanes run (`WarpRun`) from the memory to `memE 32`, each through `%6`'s two `idx` shuffles
(`WarpRun.of_waits`, with `J = 2` and block `%6`, label 6) and `%42`'s branch to `%43` and
`ret` (`MojoProofTest.GemvOut.run`). -/
theorem warp {bA bV : Nat} (h : w.Pre bA bV) :
    ∃ Es, WarpRun w.L w.c w.k w.t w.m Es (w.memE 32) := by
  have hs := h.hL.volume_pos
  have hfull := warpLanes_full (L := w.L) hs h.h32 w.k
  have hr : ∀ j ∈ warpLanes w.L w.k, RunsVia (w.c (w.k + j)) (· = w.mem 2 (j + 1))
      ((List.range 2).map fun i => (w.W i j).via gemv.fn_0 6) (w.t (w.k + j)) (w.mem 0 j) := by
    intro j hj
    rw [hfull, List.mem_range] at hj
    exact lane_runs h hj
  obtain ⟨Es, hE⟩ := WarpRun.of_waits (J := 2) (fn := gemv.fn_0) (lbl := fun _ => 6)
    (mo := mode) (X := w.X) (M := w.mem) (W := w.W) (t := w.t) hr
    (fun i hi j hj => shape h hi (by rwa [hfull, List.mem_range] at hj))
    (fun i hi j _ => ⟨(W_mem hi j).1, by rw [(W_mem hi j).2]; rfl⟩)
    (fun i hi => by rw [hfull, List.length_range]; exact mem_zero hi)
  rw [hfull, List.length_range] at hE
  exact ⟨Es, hE⟩

/-- Under the premises, for `j ≤ 32`, `memE j` has the start memory's `next`: each lane's run to
its end keeps it (`RunsVia.endAt_next`, on `lane_runs`). -/
theorem memE_next {bA bV : Nat} (h : w.Pre bA bV) : ∀ j ≤ 32, (w.memE j).next = w.m.next
  | 0, _ => Alloc.mem0_next 32
  | j + 1, hj => by
    have hr := lane_runs h (j := j) (by omega)
    refine RunsVia.endAt_next _ hr (Alloc.mem0_next j) fun e he => ?_
    rw [show List.range 2 = [0, 1] from rfl] at he
    simp only [List.map_cons, List.map_nil, List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl
    · exact Alloc.mem0_next 32
    · exact memE_next h j (by omega)

/-- **The warp's frame**: gemv_kernel, for every warp whose row is `M` or more under the premises
(`Out.Pre`): the memory after every lane's end (`memE 32`) has the start memory's `next` and its
blocks outside the lanes' `alloca` numbers. -/
theorem warp_frame {bA bV : Nat} (h : w.Pre bA bV) :
    (w.memE 32).next = w.m.next ∧
    w.m.SameOff (fun q => ∃ j, j < 32 ∧ w.T j q) (w.memE 32) :=
  ⟨memE_next h 32 le_rfl,
    ((Alloc.chain0 (w := w.toAlloc) 0 32).mono fun _ ⟨i, _, hi, hT⟩ => ⟨i, hi, hT⟩).trans
      (memE_off h 32 le_rfl)⟩

/-- **A warp's premises on a later memory**: gemv_kernel, for every warp whose row is `M` or more
under the premises (`Out.Pre`) on its memory and every memory `m'` with its `next`, `p0` a
writable buffer of `M` words, and no block at the warp's `alloca` numbers: the warp's premises
hold on `m'` (its `alloca` numbers are the same, by `Mem.fresh_of_next`). -/
theorem Pre.frame {bA bV : Nat} (h : w.Pre bA bV) {m' : Mem}
    (hn : m'.next = w.m.next) (hB : m'.Buffer w.p0 (w.M * 4) 4 true)
    (hf : ∀ j < 32, ∀ e < 3, m'.blocks (w.b j e) = none) :
    ({ w with m := m' } : Out).Pre bA bV :=
  { hL := h.hL, h32 := h.h32, hcp := h.hcp, hce := h.hce, hwho := h.hwho, had := h.had
    hfr := h.hfr, hM := h.hM, hK := h.hK, hrow := h.hrow
    hnx := by
      show 0 < m'.next
      rw [hn]
      exact h.hnx
    hfresh := fun j hj e he => by
      have hb : ({ w with m := m' } : Out).b j e = w.b j e := Mem.fresh_of_next hn _ _
      show m'.blocks (({ w with m := m' } : Out).b j e) = none
      rw [hb]
      exact hf j hj e he
    hb0 := hB }

/-- **A warp's premises from the grid's start, row `M` or more**: gemv_kernel, for every valid
launch `L` whose block size 32 divides, argument values `p0`, `bA`, `bV` (pointers at offset 0),
`M`, any `%4` and `K`, caller's memory `m` with no block from `next` on, address choice `ch`
below `2 ^ 60`, oracle, and warp from thread `k` (its 32 threads in the launch) with row `M` or
more, whose start gives `(g, c)`: if `M` and `K` are below `2 ^ 31` and `m` has the writable
output buffer, then the warp's premises (`Out.Pre`) hold on `g`'s memory (`start_lanes`). -/
theorem Pre.of_start {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (h32 : 32 ∣ volume L.block) {k : Nat}
    (hkg : k + 32 ≤ volume L.grid * volume L.block) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hr : M ≤ row (L.env k)) (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) :
    (⟨⟨k, c, Grid.thread g, g.mem⟩, L, M, K, p0⟩ : Out).Pre bA bV := by
  obtain ⟨hcp, hce, hwho, had, hfr, hnx, hfree, hb0'⟩ := start_lanes hs ha hkg hch hm hb0
  exact
    { hL := hL, h32 := h32, hcp := hcp, hce := hce, hwho := hwho, had := had, hfr := hfr
      hM := hM, hK := hK, hrow := hr, hnx := hnx
      hfresh := fun j _ e _ => hfree _ (Nat.le_add_right _ _), hb0 := hb0' }

end Out

namespace Lanes

/-- **Each in-range warp's premises at the grid's start**: gemv_kernel, for every valid launch
`L` whose block size 32 divides, argument values `p0`, `bA`, `bV` (pointers at offset 0), `M`,
any `%4` and `K`, caller's memory `m` with no block from `next` on, address choice below
`2 ^ 60` and oracle whose start gives `(g, c)`, and every warp of the grid from thread `k`
(`warps`) with row `r : Fin M` (`row`): under `Pre.of_start`'s bounds and buffers, the warp's
premises (`Lanes.Pre`) hold on `g`'s memory at row `r` (`Pre.of_start`, `warps_mem`). -/
theorem Pre.of_warps {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (h32 : 32 ∣ volume L.block) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v)
    {k : Nat} (hk : k ∈ warps L g.threads.size) {r : Fin M} (hr : r.val = row (L.env k)) :
    (ofStart L g c k M K p0 A v r).Pre bA bV := by
  have hN : g.threads.size = volume L.grid * volume L.block := Grid.start_size hs
  have h32N : 32 ∣ g.threads.size := hN ▸ Nat.dvd_mul_left_of_dvd h32 _
  have hk := warps_mem h32 h32N hk
  have hlt : row (L.env k) < M := hr ▸ r.isLt
  obtain rfl : r = ⟨row (L.env k), hlt⟩ := Fin.ext hr
  exact Pre.of_start hs ha hL h32 hk.1 (hN ▸ hk.2.2) hch hM hK hMK hlt hm hb0 hf0 hbA hbV
    hfA hfV hA hV

/-- **The warps as one canonical run, with an invariant `Q` of the memory**: gemv_kernel, for
every valid launch `L` whose blocks and grid are one-dimensional (`y` and `z` sizes 1) and whose
block's `x` size 32 divides, argument values `p0`, `bA`, `bV` (pointers at offset 0), `M`, any
`%4` and `K`, caller's memory `m` with no block from `next` on, address choice below `2 ^ 60` and
oracle whose start gives `(g, c)`: if `M`, `K` and `M K` are in range and `m` has the writable
output buffer and the read-only matrix and vector buffers, which fit, the last two holding `A`
and `v`, then the grid's warps (`warps`) have a canonical run (`CanonRun`) from `g`'s memory to a
memory where each warp whose row `r : Fin M` is below `M` has its row word as its lane 0's
`word 0`, and which has `Q` if `g`'s memory has it and every warp's run keeps it: an in-range
warp's from a memory of `Q` with its premises (`Lanes.Pre`) to `mem7 32`, and a warp whose row
is `M` or more from one with `Out.Pre` to `memE 32`. The warps whose row is `M` or more take
`%42`'s branch to `ret` (`Out.warp`). By `CanonRun.of_inv` with, after `i`
warps, the output buffer, every later warp's premises (`Lanes.Pre` or `Out.Pre`, on `g`'s memory
by `Pre.of_warps` and `Out.Pre.of_start`, then `Lanes.Pre.frame` and `Out.Pre.frame`: the
warps' threads are 32 apart, `warps_apart`) and every earlier in-range warp's row loading
(`warp`, then `warp_frame` at the later in-range warps, whose rows `k / 32` differ, `row_eq`,
and `Out.warp_frame`, which keeps `p0`), and `Q`. -/
theorem grid_run_inv {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) (Q : Mem → Prop) (hQ0 : Q g.mem)
    (hQL : ∀ k ∈ warps L g.threads.size, ∀ (r : Fin M) (m₁ : Mem), r.val = row (L.env k) →
      (⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0, A, v, r⟩ : Lanes).Pre bA bV → Q m₁ →
      Q ((⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0, A, v, r⟩ : Lanes).mem7 32))
    (hQO : ∀ k ∈ warps L g.threads.size, ∀ m₁ : Mem, M ≤ row (L.env k) →
      (⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0⟩ : Out).Pre bA bV → Q m₁ →
      Q ((⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0⟩ : Out).memE 32)) :
    ∃ Es m', CanonRun L c (Grid.thread g) (warps L g.threads.size) g.mem Es m' ∧ Q m' ∧
      ∀ k ∈ warps L g.threads.size, ∀ r : Fin M, r.val = row (L.env k) →
        m'.load gemv.prog.layout (c k).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
          (some 4) = .ok (Val.ofFloat .float ((ofStart L g c k M K p0 A v r).word 0)) := by
  have hv : volume L.block = L.block .x := by simp only [volume, hby, hbz, Nat.mul_one]
  have h32 : 32 ∣ volume L.block := hv ▸ hx
  have hN : g.threads.size = volume L.grid * volume L.block := Grid.start_size hs
  have h32N : 32 ∣ g.threads.size := hN ▸ Nat.dvd_mul_left_of_dvd h32 _
  have hrow : ∀ k ∈ warps L g.threads.size, row (L.env k) = k / 32 := fun k hk =>
    row_eq hL hby hbz hgy hgz (hN ▸ (by have := (warps_mem h32 h32N hk).2.2; omega))
  let w : Nat → Fin M → Mem → Lanes := fun k r m' =>
    ⟨⟨k, c, Grid.thread g, m'⟩, L, M, K, p0, A, v, r⟩
  let o : Nat → Mem → Out := fun k m' => ⟨⟨k, c, Grid.thread g, m'⟩, L, M, K, p0⟩
  let ks := warps L g.threads.size
  let P : Nat → Mem → Prop := fun i m' =>
    m'.Buffer p0 (M * 4) 4 true ∧ m'.Fits gemv.prog.layout p0 (M * 4) ∧
    (∀ i' (h : i' < ks.length), i ≤ i' → ∀ r : Fin M, r.val = row (L.env ks[i']) →
      (w ks[i'] r m').Pre bA bV) ∧
    (∀ i' (h : i' < ks.length), i ≤ i' → M ≤ row (L.env ks[i']) → (o ks[i'] m').Pre bA bV) ∧
    (∀ i' (h : i' < ks.length), i' < i → ∀ r : Fin M, r.val = row (L.env ks[i']) →
      m'.load gemv.prog.layout (c ks[i']).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
        (some 4) = .ok (Val.ofFloat .float ((w ks[i'] r g.mem).word 0))) ∧ Q m'
  have h0 : P 0 g.mem := by
    refine ⟨hb0.of_block fun _ hx => Grid.start_blocks hs hx,
      hf0.of_block fun _ hx => Grid.start_blocks hs hx, fun i' hi' _ r hr => ?_,
      fun i' hi' _ hr => ?_, fun _ _ h => absurd h (Nat.not_lt_zero _), hQ0⟩
    · exact Pre.of_warps hs ha hL h32 hch hM hK hMK hm hb0 hf0 hbA hbV hfA hfV hA hV
        (List.getElem_mem hi') hr
    · have hk := warps_mem h32 h32N (List.getElem_mem hi')
      exact Out.Pre.of_start hs ha hL h32 (hN ▸ hk.2.2) hch hM hK hr hm hb0
  have hstep : ∀ i (hi : i < ks.length), ∀ m₁, P i m₁ →
      ∃ Es m', WarpRun L c ks[i] (Grid.thread g) m₁ Es m' ∧ P (i + 1) m' := by
    intro i hi m₁ ⟨hB₁, hF₁, hpre, hpo, hld, hq⟩
    obtain ⟨x0, hx0, -⟩ := id hB₁
    have key : ∃ Es m', WarpRun L c ks[i] (Grid.thread g) m₁ Es m' ∧ m'.next = m₁.next ∧
        m₁.SameOff (fun q => q = p0 ∨ ∃ j < 32, ∃ e < 3, q = m₁.fresh
          (c (ks[i] + j)).who.thread ((Grid.thread g (ks[i] + j)).k + e)) m' ∧
        m'.Buffer p0 (M * 4) 4 true ∧ m'.Fits gemv.prog.layout p0 (M * 4) ∧
        (∀ q, q ≠ p0 → ∀ x, m₁.blocks q = some x → m'.blocks q = some x) ∧
        (∀ i' (h : i' < ks.length), i' < i + 1 → ∀ r : Fin M, r.val = row (L.env ks[i']) →
          m'.load gemv.prog.layout (c ks[i']).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
            (some 4) = .ok (Val.ofFloat .float ((w ks[i'] r g.mem).word 0))) ∧ Q m' := by
      rcases Nat.lt_or_ge (row (L.env ks[i])) M with hr | hr
      · have h := hpre i hi le_rfl ⟨_, hr⟩ rfl
        obtain ⟨Es, hw, hv⟩ := warp h
        obtain ⟨hn, hS, hB, hF, hL'⟩ := warp_frame h
        have hTS : ∀ j < 32, ∀ q, (w ks[i] ⟨_, hr⟩ m₁).T j q → ∃ e < 3, q = m₁.fresh
            (c (ks[i] + j)).who.thread ((Grid.thread g (ks[i] + j)).k + e) := by
          intro j _ q hT
          rcases hT with hT | hT | hT
          exacts [⟨0, by decide, hT⟩, ⟨1, by decide, hT⟩, ⟨2, by decide, hT⟩]
        have hk : ∀ q, q ≠ p0 → ∀ x, m₁.blocks q = some x →
            ((w ks[i] ⟨_, hr⟩ m₁).mem7 32).blocks q = some x := by
          intro q hq x hx
          refine (hS q ?_).trans hx
          rintro (h0 | ⟨j, hj, hT⟩)
          · exact hq h0
          · exact Alloc.T_block h.hfresh hj hx hT
        refine ⟨Es, _, hw, hn, hS.mono fun q hq => hq.imp_right fun ⟨j, hj, hT⟩ =>
          ⟨j, hj, hTS j hj q hT⟩, hB, hF, hk, ?_, hQL _ (List.getElem_mem hi) _ m₁ rfl h hq⟩
        intro i' hi' hlt r hr'
        rcases Nat.lt_succ_iff_lt_or_eq.1 hlt with hlt | rfl
        · have hap : ks[i'] + 32 ≤ ks[i] := warps_apart h32 h32N hi' hi hlt
          have h1 := hrow _ (List.getElem_mem hi)
          have h2 := hrow _ (List.getElem_mem hi')
          refine hL' _ _ _ _ _ _ ?_ (hld i' hi' hlt r hr')
          have hst : gemv.prog.layout.stored (.fp .float) = 4 := rfl
          show ((r.val * 4 : Nat) : Int).toNat + gemv.prog.layout.stored (.fp .float) ≤
              row (L.env ks[i]) * 4 ∨ row (L.env ks[i]) * 4 + 4 ≤ ((r.val * 4 : Nat) : Int).toNat
          rw [hst, Int.toNat_natCast, h1, hr', h2]
          omega
        · obtain rfl : r = ⟨_, hr⟩ := Fin.ext hr'
          exact hv
      · have h := hpo i hi le_rfl hr
        obtain ⟨Es, hw⟩ := Out.warp h
        obtain ⟨hn, hS⟩ := Out.warp_frame h
        have hk : ∀ q x, m₁.blocks q = some x → ((o ks[i] m₁).memE 32).blocks q = some x :=
          fun q x hx => (hS q fun ⟨j, hj, hT⟩ => Alloc.T_block h.hfresh hj hx hT).trans hx
        have hp : ((o ks[i] m₁).memE 32).blocks p0 = m₁.blocks p0 :=
          hS p0 fun ⟨j, hj, hT⟩ => Alloc.T_block h.hfresh hj hx0 hT
        have hTS : ∀ j < 32, ∀ q, (o ks[i] m₁).T j q → ∃ e < 3, q = m₁.fresh
            (c (ks[i] + j)).who.thread ((Grid.thread g (ks[i] + j)).k + e) := by
          intro j _ q hT
          rcases hT with hT | hT | hT
          exacts [⟨0, by decide, hT⟩, ⟨1, by decide, hT⟩, ⟨2, by decide, hT⟩]
        refine ⟨Es, _, hw, hn, hS.mono fun q ⟨j, hj, hT⟩ => .inr ⟨j, hj, hTS j hj q hT⟩,
          hB₁.of_block (hk p0), hF₁.of_block (hk p0), fun q _ => hk q, ?_,
          hQO _ (List.getElem_mem hi) m₁ hr h hq⟩
        intro i' hi' hlt r hr'
        rcases Nat.lt_succ_iff_lt_or_eq.1 hlt with hlt | rfl
        · rw [Mem.load_of_block (p := ⟨p0, _⟩) hp]
          exact hld i' hi' hlt r hr'
        · exact absurd r.isLt (by omega)
    obtain ⟨Es, m', hw, hn, hS, hB, hF, hk, hl, hq'⟩ := key
    have hf : ∀ i' (hi' : i' < ks.length), i < i' → ∀ j < 32, ∀ e,
        m₁.blocks (m₁.fresh (c (ks[i'] + j)).who.thread ((Grid.thread g (ks[i'] + j)).k + e)) =
          none →
        m'.blocks (m₁.fresh (c (ks[i'] + j)).who.thread ((Grid.thread g (ks[i'] + j)).k + e)) =
          none := by
      intro i' hi' hii j hj e hq
      have hap : ks[i] + 32 ≤ ks[i'] := warps_apart h32 h32N hi hi' hii
      rw [hS _ ?_, hq]
      rintro (h0 | ⟨a, ha, e', he', hq'⟩)
      · rw [← h0, hq] at hx0
        cases hx0
      · simp only [Mem.fresh, Nat.add_left_cancel_iff, Nat.pair_eq_pair] at hq'
        have e1 := hq'.1
        rw [(Grid.start_ctx hs _).2.1, (Grid.start_ctx hs _).2.1] at e1
        have e2 : ks[i'] + j = ks[i] + a := e1
        omega
    refine ⟨Es, m', hw, hB, hF, fun i' hi' hle r hr' => ?_, fun i' hi' hle hr' => ?_, hl, hq'⟩
    · have h' := hpre i' hi' (by omega) r hr'
      exact Lanes.Pre.frame h' hn hk hB hF fun j hj e he =>
        hf i' hi' (by omega) j hj e (h'.hfresh j hj e he)
    · have h' := hpo i' hi' (by omega) hr'
      exact Out.Pre.frame h' hn hB fun j hj e he =>
        hf i' hi' (by omega) j hj e (h'.hfresh j hj e he)
  obtain ⟨Es, m', hc, hP⟩ := CanonRun.of_inv (P := P) (ks := ks) hstep h0
  refine ⟨Es, m', hc, hP.2.2.2.2.2, fun k hk r hr => ?_⟩
  obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hk
  exact hP.2.2.2.2.1 i hi hi r hr

/-- **The warps as one canonical run**: gemv_kernel, for every valid launch `L` whose blocks and
grid are one-dimensional (`y` and `z` sizes 1) and whose block's `x` size 32 divides, argument
values `p0`, `bA`, `bV` (pointers at offset 0), `M`, any `%4` and `K`, caller's memory `m` with
no block from `next` on, address choice below `2 ^ 60` and oracle whose start gives `(g, c)`:
if `M`, `K` and `M K` are in range and `m` has the writable output buffer and the read-only
matrix and vector buffers, which fit, the last two holding `A` and `v`, then the grid's warps
(`warps`) have a canonical run (`CanonRun`) from `g`'s memory to a memory where each warp whose
row `r : Fin M` is below `M` has its row word as its lane 0's `word 0` (`grid_run_inv` at the
invariant `True`). -/
theorem grid_run {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    ∃ Es m', CanonRun L c (Grid.thread g) (warps L g.threads.size) g.mem Es m' ∧
      ∀ k ∈ warps L g.threads.size, ∀ r : Fin M, r.val = row (L.env k) →
        m'.load gemv.prog.layout (c k).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
          (some 4) = .ok (Val.ofFloat .float ((ofStart L g c k M K p0 A v r).word 0)) :=
  have ⟨Es, m', hc, _, hl⟩ := grid_run_inv hs ha hL hx hby hbz hgy hgz hch hM hK hMK hm hb0 hf0
    hbA hbV hfA hfV hA hV (fun _ => True) trivial (fun _ _ _ _ _ _ _ => trivial)
    (fun _ _ _ _ _ _ => trivial)
  ⟨Es, m', hc, hl⟩

/-- **The grid from its start to a done grid**: gemv_kernel, for every valid launch under
`grid_run`'s premises (one-dimensional, the block's `x` size a multiple of 32, the buffers on a
caller's memory with no block from `next` on): the start's grid steps (`Grid.Step`) to a done
grid (`GPUProof.Done` at `sig`) whose memory has each warp's row word, for the warps whose row
`r : Fin M` is below `M`, as its lane 0's `word 0` (`grid_run`, then `CanonRun.start_done`). -/
theorem grid_done {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧
      ∀ k ∈ warps L g.threads.size, ∀ r : Fin M, r.val = row (L.env k) →
        z.mem.load gemv.prog.layout (c k).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
          (some 4) = .ok (Val.ofFloat .float ((ofStart L g c k M K p0 A v r).word 0)) := by
  obtain ⟨Es, m', hc, hl⟩ := grid_run hs ha hL hx hby hbz hgy hgz hch hM hK hMK hm hb0 hf0
    hbA hbV hfA hfV hA hV
  obtain ⟨z, hp, hd, rfl⟩ := CanonRun.start_done hs hL.volume_pos hc
  exact ⟨z, hp, hd, hl⟩

end Lanes

/-! ## The instance: one block of 32 threads, `M = 1`, `K = 4` -/

open Lanes

/-- The warp of one block of 32 threads (`launch2 1 1 32 1`) from thread 0: the contexts `cl`, the
threads at `f3`'s start, the memory `m3` with `A3` at block 1, `v3` at block 2 and the output at
block 3, `M = 1`, `K = 4`, row 0 (MojoProofTest/GemvThread.lean). A test definition. -/
def w0 : Lanes := ⟨⟨0, cl, fun _ => ⟨[f3], 0⟩, m3⟩, launch2 1 1 32 1, 1, 4, 3, A3, v3, 0⟩

/-- Test: `m3` has no block from its `next`, 4, on. -/
theorem m3_free : m3.FreeAbove := by
  intro q hq
  have h4 : m3.next = 4 := rfl
  rw [h4] at hq
  simp only [GemvThread.m3, Mem.alloc, Mem.set]
  split_ifs with h
  · have : GemvThread.m2.1.next = 3 := rfl
    omega
  simp only [GemvThread.m2, Mem.alloc, Mem.set]
  split_ifs with h
  · have : GemvThread.m1.1.next = 2 := rfl
    omega
  simp only [GemvThread.m1, Mem.alloc, Mem.set]
  split_ifs with h
  · have : ({} : Mem).next = 1 := rfl
    omega
  rfl

/-- Test: the warp theorem's premises hold at `w0`, with the matrix and vector at blocks 1 and 2.
-/
theorem w0_pre : w0.Pre 1 2 where
  hL := launch2_valid (by decide)
  h32 := by decide
  hk := rfl
  hcp _ _ := rfl
  hce _ _ := rfl
  hwho i _ j _ h := by
    have : 0 + i = 0 + j := h
    omega
  had _ _ _ := show 0 < 2 ^ 60 by decide
  hfr _ _ := ⟨f3, rfl, rfl, by decide +kernel, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  hM := by decide
  hK := by decide
  hMK := by decide
  hrow := by decide +kernel
  hnx := by decide
  hfresh _ _ _ _ := m3_free _ (Nat.le_add_right _ _)
  hb0 := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hf0 := ⟨_, rfl, by decide +kernel⟩
  hbA := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hbV := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hfA := ⟨_, rfl, by decide +kernel⟩
  hfV := ⟨_, rfl, by decide +kernel⟩
  hA := m3_holds.1
  hV := m3_holds.2

/-- Test: `Pre.of_start` at one block of 32 threads (`launch2 1 1 32 1`), `M = 1`, `K = 4`, the
output at block 3, the matrix and vector at blocks 1 and 2 of `m3`, any `%4` and every address
choice below `2 ^ 60` and oracle whose start gives `(g, c)`: warp 0's premises hold on the start's
memory at row `row (L.env 0) = 0`. -/
theorem w0_start {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 32 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 1), x4, .bits 32 (BitVec.ofNat 32 4)] m3 ch oracle =
        .ok (g, c)) :
    (Lanes.ofStart (launch2 1 1 32 1) g c 0 1 4 3 A3 v3 ⟨row ((launch2 1 1 32 1).env 0),
      by decide +kernel⟩).Pre 1 2 :=
  Lanes.Pre.of_start hs rfl (launch2_valid (by decide)) (by decide) rfl (by decide) hch
    (by decide) (by decide) (by decide) _ m3_free w0_pre.hb0 w0_pre.hf0 w0_pre.hbA w0_pre.hbV
    w0_pre.hfA w0_pre.hfV w0_pre.hA w0_pre.hV

/-- Test: `grid_done` at one block of 32 threads (`launch2 1 1 32 1`), `M = 1`, `K = 4`, the
output at block 3, the matrix and vector at blocks 1 and 2 of `m3`, any `%4` and every address
choice below `2 ^ 60` and oracle whose start gives `(g, c)`: the start's grid steps to a done
grid where row 0 of the output loads as the warp's lane 0's `word 0`. -/
theorem w0_done {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 32 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 1), x4, .bits 32 (BitVec.ofNat 32 4)] m3 ch oracle =
        .ok (g, c)) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (launch2 1 1 32 1) c) i g z) ∧
      GPUProof.Done sig (z, launch2 1 1 32 1, c) ∧
      z.mem.load gemv.prog.layout (c 0).who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
        .ok (Val.ofFloat .float ((ofStart (launch2 1 1 32 1) g c 0 1 4 3 A3 v3 0).word 0)) := by
  obtain ⟨z, hp, hd, hl⟩ := grid_done hs rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl
    rfl hch (by decide) (by decide) (by decide) m3_free w0_pre.hb0 w0_pre.hf0 w0_pre.hbA
    w0_pre.hbV w0_pre.hfA w0_pre.hfV w0_pre.hA w0_pre.hV
  exact ⟨z, hp, hd, hl 0 (by rw [Grid.start_size hs]; decide) 0
    (by simp only [row, Launch.env, coord, launch2, volume]; omega)⟩

/-- `m3` with a writable global buffer of 4 bytes at block 4, lane 0's first `alloca` number at
`w0` (`m3.next + Nat.pair 0 0`). A test definition. -/
def m4 : Mem := (m3.alloc gemv.prog.layout 1 4 16 true false .all 4 4 (num := some 4)).1

/-- **Mutant of `Pre.hfresh`** (test of gemv_kernel at one block of 32 threads, `M = 1`, `K = 4`,
lane 0, on `m4`): `m4` has a writable buffer at block 4, lane 0's first `alloca` number of `w0`
on `m4`, so that warp misses `hfresh`; and the memory after lane 0's `alloca`s (`mem0 1`) has
no buffer there (`slots_buffer`). -/
theorem fresh_mutant : m4.Buffer 4 4 4 true ∧ ({ w0 with m := m4 } : Lanes).b 0 0 = 4 ∧
    ¬ (({ w0 with m := m4 } : Lanes).mem0 1).Buffer 4 4 4 true := by
  refine ⟨⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩,
    rfl, ?_⟩
  show ¬ (slots (cl 0) 0 m4 4 5 8).Buffer 4 4 4 true
  exact slots_buffer _ _ _ (by decide) (by decide) (by decide) fun _ => show 0 < 2 ^ 60 by decide

/-- **A warp leaves a block from `next` on** (test of gemv_kernel at one block of 32 threads,
`M = 1`, `K = 4`, row 0, on `m3`, `w0`): the memory after the warp, `w0.mem7 32`, has `m3`'s
`next`, 4 (`mem7_next`), and a block at 4, lane 0's first `alloca` number, so it is not
`Mem.FreeAbove`. A warp's premise that its memory has no block from `next` on fails at the
memory the warp before it leaves, so `Lanes.Pre` asks only for no block at the warp's own
`alloca` numbers (`hfresh`). The block is lane 0's slot (`slots_inv`), which the other lanes'
`alloca`s keep (`Alloc.chain0`; their numbers differ, `b_inj`), each lane's run to its first `%78`
shuffle keeps (`RunsVia.waitAt_keeps`, on `lane_runs`) and the lanes' ends keep (`keeps_out`).
-/
theorem w0_not_free : ¬ (w0.mem7 32).FreeAbove := by
  have h := w0_pre
  have hS : ∀ m m' : Mem, m.Keeps m' → m.blocks 4 ≠ none → m'.blocks 4 ≠ none :=
    fun m m' hk hm hn => by
      obtain ⟨x, hx⟩ := Option.ne_none_iff_exists'.1 hm
      have e := hk.blocks 4 x hx
      rw [hn] at e
      cases e
  have h1 : (w0.mem0 1).blocks 4 ≠ none := by
    show (slots (cl 0) 0 m3 4 5 8).blocks 4 ≠ none
    have h7 := (slots_inv (cl 0) 0 m3 (b7 := 4) (b8 := 5) (b9 := 8) (by decide) (by decide)
      (by decide) fun _ => show 0 < 2 ^ 60 by decide).1
    intro hn
    simp [Mem.slot, hn] at h7
  have h32 : (w0.mem0 32).blocks 4 ≠ none := by
    have hb : w0.b 0 0 = 4 := rfl
    have e : (w0.mem0 32).blocks 4 = (w0.mem0 1).blocks 4 :=
      Alloc.chain0 (w := w0.toAlloc) 1 31 4 fun ⟨i, hi1, hi2, hT⟩ => by
        rcases hT with hT | hT | hT <;>
          exact absurd (b_inj h (by omega) (by decide) (hT.symm.trans hb.symm)).1 (by omega)
    rw [e]
    exact h1
  have h2 : ∀ j, j ≤ 32 → (w0.mem2 j).blocks 4 ≠ none := by
    intro j
    induction j with
    | zero => intro _; exact h32
    | succ j ih =>
      intro hj
      have hr := lane_runs h (j := j) (by omega)
      rw [show List.range 7 = [0, 1] ++ 2 :: [3, 4, 5, 6] from rfl, List.map_append] at hr
      exact RunsVia.waitAt_keeps (S := fun m => m.blocks 4 ≠ none) hS _ hr
        (fun e => by simp at e) fun e he => by
          simp only [List.map_cons, List.map_nil, List.mem_cons, List.not_mem_nil,
            or_false] at he
          rcases he with rfl | rfl
          · exact h32
          · exact ih (by omega)
  have h7 : ∀ j, (w0.mem7 j).blocks 4 ≠ none := by
    intro j
    induction j with
    | zero => exact h2 32 le_rfl
    | succ j ih =>
      show (GemvThread.out _ _ _ _ _ _ _ _ (w0.lid j = 0) _).blocks 4 ≠ none
      exact hS _ _ (keeps_out _ _ _ _ _ _ _ _ _ _) ih
  have h4 : m3.next = 4 := rfl
  intro hf
  exact h7 32 (hf 4 (by rw [mem7_next h 32]; exact h4.le))

/-- Test: `warp` at one block of 32 threads, `M = 1`, `K = 4`, row 0 (`w0`): the 32 lanes run
from `m3` to `w0.mem7 32`, where the output word at block 3 loads as lane 0's `total` of its sum
and its partners' offers. -/
example : ∃ Es, WarpRun (launch2 1 1 32 1) cl 0 (fun _ => ⟨[f3], 0⟩) m3 Es (w0.mem7 32) ∧
    (w0.mem7 32).load gemv.prog.layout (cl 0).who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
      .ok (Val.ofFloat .float (total (cl 0) (w0.n 0) (w0.x 0) (w0.acc 0 16) (w0.acc 1 8)
        (w0.acc 2 4) (w0.acc 3 2) (w0.acc 4 1))) :=
  warp w0_pre

/-! ## Two warps: one block of 64 threads, `M = 2`, `K = 4` -/

/-- The `2 × 4` matrix of binary32 ones. A test definition. -/
def A24 : TorchLean.Tensor (Model FloatTy.float.fmt) [2, 4] :=
  TorchLean.Tensor.Rep.ofFn fun _ => Model.ofNatBits 0x3f800000

/-- Block 1 of the empty memory: `A24`'s bytes, global, read-only. A test definition. -/
def n1 : Mem × Nat :=
  ({} : Mem).alloc gemv.prog.layout 1
    (TorchLean.Shape.size [2, 4] * gemv.prog.layout.size (.fp .float)) 16 true true .all 1 1
    (tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) A24)

/-- Block 2 after `n1`: `v3`'s bytes, global, read-only. A test definition. -/
def n2 : Mem × Nat :=
  n1.1.alloc gemv.prog.layout 1 (TorchLean.Shape.size [4] * gemv.prog.layout.size (.fp .float))
    16 true true .all 2 2 (tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) v3)

/-- The memory: blocks 1 and 2 hold `A24` and `v3`, block 3 is a writable global output of 8
bytes. A test definition. -/
def n3 : Mem := (n2.1.alloc gemv.prog.layout 1 8 16 true false .all 3 3).1

/-- Thread `i`'s context at one block of 64 threads: gemv's program, no globals, thread `i` of
block 0, every skeleton and oracle choice 0. A test definition. -/
def c64 (i : Nat) : Ctx :=
  ⟨gemv.prog, fun _ => none, (launch2 1 1 64 1).env i, ⟨i, 0⟩, fun _ => 0, fun _ => 0⟩

/-- The start's frame with `M = 2`: position 0 of `%6`, the arguments `%0` to `%5` (blocks 3, 1,
2, `M = 2`, 0, `K = 4`), no `alloca` block. A test definition. -/
def f64 : Frame :=
  ⟨gemv.fn_0, 6, 0, fun i => [Val.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩, .ptr ⟨2, 0⟩, .bits 32 (.ofNat 32 2),
    .bits 32 0, .bits 32 (.ofNat 32 4)][i]?, fun _ => none, [], none⟩

/-- The first warp of one block of 64 threads (`launch2 1 1 64 1`), threads 0 to 31: the
contexts `c64`, the threads at `f64`'s start, the memory `n3`, `M = 2`, `K = 4`, row 0. A test
definition. -/
def w64 : Lanes := ⟨⟨0, c64, fun _ => ⟨[f64], 0⟩, n3⟩, launch2 1 1 64 1, 2, 4, 3, A24, v3, 0⟩

/-- Row 1 of `w64`'s output. A test definition. -/
def r64 : Fin w64.M := ⟨1, by decide⟩

/-- `n3` has no block from number 4 on. A test. -/
theorem n3_none {q : Nat} (hq : 4 ≤ q) : n3.blocks q = none := by
  simp only [n3, Mem.alloc, Mem.set]
  split_ifs with h
  · have : n2.1.next = 3 := rfl
    omega
  simp only [n2, Mem.alloc, Mem.set]
  split_ifs with h
  · have : n1.1.next = 2 := rfl
    omega
  simp only [n1, Mem.alloc, Mem.set]
  split_ifs with h
  · have : ({} : Mem).next = 1 := rfl
    omega
  rfl

/-- Test: `n3` has no block from its `next`, 4, on (`n3_none`). -/
theorem n3_free : n3.FreeAbove := fun q hq => n3_none (by
  have h4 : n3.next = 4 := rfl
  omega)

/-- `n3`'s blocks 1 and 2 hold `A24` and `v3` row-major (`Mem.holds_alloc`). A test. -/
theorem n3_holds :
    n3.Holds gemv.prog.layout 1 (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A24 ∧
    n3.Holds gemv.prog.layout 2 (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v3 :=
  ⟨.of_block (fun _ h => (show n3.blocks 1 = n1.1.blocks 1 from rfl).trans h)
      (Mem.holds_alloc (Layout.Codec.float _ .float) A24 ({} : Mem) 1 16 true true .all 1 1),
    .of_block (fun _ h => (show n3.blocks 2 = n2.1.blocks 2 from rfl).trans h)
      (Mem.holds_alloc (Layout.Codec.float _ .float) v3 n1.1 1 16 true true .all 2 2)⟩

/-- Test: the warp theorem's premises hold at `w64` (gemv_kernel at one block of 64 threads,
`M = 2`, `K = 4`, threads 0 to 31, row 0), with the matrix and vector at blocks 1 and 2. -/
theorem w64_pre : w64.Pre 1 2 where
  hL := launch2_valid (by decide)
  h32 := by decide
  hk := rfl
  hcp _ _ := rfl
  hce _ _ := rfl
  hwho i _ j _ h := by
    have : 0 + i = 0 + j := h
    omega
  had _ _ _ := show 0 < 2 ^ 60 by decide
  hfr _ _ := ⟨f64, rfl, rfl, by decide +kernel, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  hM := by decide
  hK := by decide
  hMK := by decide
  hrow := by decide +kernel
  hnx := by decide
  hfresh _ _ _ _ := n3_none (Nat.le_add_right _ _)
  hb0 := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hf0 := ⟨_, rfl, by decide +kernel⟩
  hbA := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hbV := ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩
  hfA := ⟨_, rfl, by decide +kernel⟩
  hfV := ⟨_, rfl, by decide +kernel⟩
  hA := n3_holds.1
  hV := n3_holds.2

/-- Test: the second warp's premises on the start memory `n3` (gemv_kernel at one block of 64
threads, `M = 2`, `K = 4`, threads 32 to 63, row 1). -/
theorem w64_later_pre : (w64.later 32 r64 w64.m).Pre 1 2 where
  hL := launch2_valid (by decide)
  h32 := by decide
  hk := by decide
  hcp _ _ := rfl
  hce _ _ := rfl
  hwho i _ j _ h := by
    have : 32 + i = 32 + j := h
    omega
  had _ _ _ := show 0 < 2 ^ 60 by decide
  hfr _ _ := ⟨f64, rfl, rfl, by decide +kernel, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  hM := by decide
  hK := by decide
  hMK := by decide
  hrow := by decide +kernel
  hnx := by decide
  hfresh _ _ _ _ := n3_none (Nat.le_add_right _ _)
  hb0 := w64_pre.hb0
  hf0 := w64_pre.hf0
  hbA := w64_pre.hbA
  hbV := w64_pre.hbV
  hfA := w64_pre.hfA
  hfV := w64_pre.hfV
  hA := w64_pre.hA
  hV := w64_pre.hV

/-- Test: gemv_kernel at one block of 64 threads, `M = 2`, `K = 4`: the second warp's premises
hold on the memory after the first warp's lanes (`Pre.later`), without evaluating it. -/
theorem w64_next_pre : (w64.later 32 r64 (w64.mem7 32)).Pre 1 2 :=
  w64_pre.later w64_later_pre fun i _ j _ h => by
    have : 32 + i = 0 + j := h
    omega

/-- Test: gemv_kernel at one block of 64 threads, `M = 2`, `K = 4`: after the first warp and then
the second on its memory, row 0 of the output (block 3) loads as the first warp's lane 0's
`total` (`later_row`) and row 1 as the second's (`warp`). -/
example : ((w64.later 32 r64 (w64.mem7 32)).mem7 32).load gemv.prog.layout (c64 0).who 0
      (.fp .float) ⟨3, 0⟩ (some 4) =
      .ok (Val.ofFloat .float (total (c64 0) (w64.n 0) (w64.x 0) (w64.acc 0 16) (w64.acc 1 8)
        (w64.acc 2 4) (w64.acc 3 2) (w64.acc 4 1))) ∧
    ((w64.later 32 r64 (w64.mem7 32)).mem7 32).load gemv.prog.layout (c64 32).who 0
      (.fp .float) ⟨3, 4⟩ (some 4) =
      .ok (Val.ofFloat .float (total (c64 32) ((w64.later 32 r64 (w64.mem7 32)).n 0)
        ((w64.later 32 r64 (w64.mem7 32)).x 0) ((w64.later 32 r64 (w64.mem7 32)).acc 0 16)
        ((w64.later 32 r64 (w64.mem7 32)).acc 1 8) ((w64.later 32 r64 (w64.mem7 32)).acc 2 4)
        ((w64.later 32 r64 (w64.mem7 32)).acc 3 2) ((w64.later 32 r64 (w64.mem7 32)).acc 4 1))) :=
  have ⟨_, _, hv⟩ := warp w64_next_pre
  ⟨later_row w64_pre w64_next_pre (by decide), hv⟩

/-- Test: `grid_done` at one block of 64 threads (`launch2 1 1 64 1`), `M = 2`, `K = 4`, the
output at block 3, the matrix `A24` and vector `v3` at blocks 1 and 2 of `n3`, any `%4` and every
address choice below `2 ^ 60` and oracle whose start gives `(g, c)`: the start's grid steps to a
done grid where row 0 of the output loads as the first warp's lane 0's `word 0` and row 1 as the
second warp's (threads 32 to 63). -/
theorem w64_done {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 2), x4, .bits 32 (BitVec.ofNat 32 4)] n3 ch oracle =
        .ok (g, c)) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (launch2 1 1 64 1) c) i g z) ∧
      GPUProof.Done sig (z, launch2 1 1 64 1, c) ∧
      z.mem.load gemv.prog.layout (c 0).who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
        .ok (Val.ofFloat .float ((ofStart (launch2 1 1 64 1) g c 0 2 4 3 A24 v3 0).word 0)) ∧
      z.mem.load gemv.prog.layout (c 32).who 0 (.fp .float) ⟨3, 4⟩ (some 4) =
        .ok (Val.ofFloat .float ((ofStart (launch2 1 1 64 1) g c 32 2 4 3 A24 v3 1).word 0)) := by
  obtain ⟨z, hp, hd, hl⟩ := grid_done hs rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl
    rfl hch (by decide) (by decide) (by decide) n3_free w64_pre.hb0 w64_pre.hf0 w64_pre.hbA
    w64_pre.hbV w64_pre.hfA w64_pre.hfV w64_pre.hA w64_pre.hV
  exact ⟨z, hp, hd, hl 0 (by rw [Grid.start_size hs]; decide) 0
      (by simp only [row, Launch.env, coord, launch2, volume]; omega),
    hl 32 (by rw [Grid.start_size hs]; decide) 1
      (by simp only [row, Launch.env, coord, launch2, volume]; omega)⟩

/-- Test: `grid_done` at one block of 64 threads (`launch2 1 1 64 1`), `M = 1`, `K = 4`, the
output at block 3, the matrix and vector at blocks 1 and 2 of `m3`, any `%4` and every address
choice below `2 ^ 60` and oracle whose start gives `(g, c)`: the second warp (threads 32 to 63)
has row 1, so `M` or more, and takes `%42`'s branch to `ret` (`Out.warp`); the start's grid
steps to a done grid where row 0 of the output loads as the first warp's lane 0's `word 0`. -/
theorem w64_out_done {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 1), x4, .bits 32 (BitVec.ofNat 32 4)] m3 ch oracle =
        .ok (g, c)) :
    row ((launch2 1 1 64 1).env 32) = 1 ∧
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (launch2 1 1 64 1) c) i g z) ∧
      GPUProof.Done sig (z, launch2 1 1 64 1, c) ∧
      z.mem.load gemv.prog.layout (c 0).who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
        .ok (Val.ofFloat .float ((ofStart (launch2 1 1 64 1) g c 0 1 4 3 A3 v3 0).word 0)) := by
  obtain ⟨z, hp, hd, hl⟩ := grid_done hs rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl
    rfl hch (by decide) (by decide) (by decide) m3_free w0_pre.hb0 w0_pre.hf0 w0_pre.hbA
    w0_pre.hbV w0_pre.hfA w0_pre.hfV w0_pre.hA w0_pre.hV
  exact ⟨by simp only [row, Launch.env, coord, launch2, volume],
    z, hp, hd, hl 0 (by rw [Grid.start_size hs]; decide) 0
      (by simp only [row, Launch.env, coord, launch2, volume]; omega)⟩

end MojoProofTest.GemvWarpRun
