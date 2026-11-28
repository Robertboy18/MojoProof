import MojoProofTest.OblGevm
import MojoProof.Sym.SegTrace
import MojoProof.Sem.Transpose

/-!
# A phase's accesses from the IR: gevm_kernel around its barrier

docs/proofs/barrier-owned.md, "A phase's accesses from the IR". gevm_kernel (`gevm`,
MojoProofTest/SymLane.lean) stores each thread's loop sum to cell `32 l + w` of a shared array of
1024 binary32 (thread `32 w + l`, warp `w`, lane `l`), waits at a barrier, and loads cell `tid.x`
before its first shuffle. The two segments around the barrier are the summaries `toBarrier` and
`toShfl` of MojoProofTest/OblGevm.lean, whose obligations mojo_obl proves there.

* `one_event`: a segment with one effect adds one event to the trace, on every run to its wait
  (`Waits.events`, `Waits.toWait`).
* `to_barrier_events`: every run of a thread at `%59` after its `phi` to the barrier adds one
  event, the write of 4 bytes at offset `4 (32 l + w)` of the shared array's block; the node values
  by obl_have.
* `to_shfl_events`: every run of a thread after the barrier to the first shuffle adds one event,
  the read of 4 bytes at offset `4 tid.x`.
* `to_barrier_mem`: every such run of the first segment leaves the memory's blocks but the shared
  array's, where it writes the thread's sum `%60` at that offset (`Mem.store_inv`);
  `to_shfl_mem`: every run of the second segment changes only the trace (`Waits.loads`).
* `resume_shfl`: a thread that ran the first segment and is resumed after the barrier is at the
  second segment's start with `%10` unchanged, the premises of `to_shfl_events` on the thread.
* `gevm_cells`: on every valid launch with `ntid.x = 1024`, a trace of two rounds (`rounds`) whose
  first round is such writes of the launch's threads and whose second is reads meets the access
  premise of `Grid.sound_cells` at `cell = tpose 32` and `w = 4` (`phases_rounds`,
  `Launch.tpose_env`).
* `gevm_turns`: so does the trace of threads run in turn to the barrier from an empty trace, the
  barriers of the launch's blocks of threads, and the threads run in turn after it, when each
  thread's runs add those events (`Seq.bar_rounds`, `Turns.events`).
* `gevm_buffer`: after threads that each write their word at their cell `tpose 32` of one block
  of threads' shared array run in turn, and the barriers are logged, the memory meets the memory
  premises of `to_shfl_events`: the buffer, and the array holding the tensor whose cell `x` is
  the word of the block's thread `tpose 32 x` (`Turns.cells`).
* `gevm_reads`: when the threads then run in turn again by runs that, from such a memory, change
  only the trace (as `to_shfl_mem`'s do), every one of them starts on a memory that meets those
  premises (`ShflMem`) at that tensor, so `to_shfl_events` applies to each (`Turns.imp`).
* `no_barrier`, the twin of `gevm_cells`: without the barrier between the rounds, thread 1's read
  of cell 1 is in phase 0, outside its cell `tpose 32 1 = 32`, so the premise fails.

Not proved: that a thread's run from gevm_kernel's start reaches `%59` with these registers and
memory (the entry block, the loop and their global loads), so `to_barrier_mem` and
`gevm_buffer`'s run premise, and `to_shfl_mem` and `gevm_reads`' run premise, are not yet joined
for the launch's threads. The runs after the first shuffle are `OblGevmThread.thread` and
`GevmWarp1.resume`; the trace of a whole run, with the loop's global loads as a premise, is in
MojoProofTest/GevmTrace.lean (`gevm_sound`).
-/

namespace MojoProofTest.SegEvents

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.OblGevm FloatLib.Floats.Formats.BinaryInterchange

/-- **A segment with one effect adds one event**, for every context `c`, thread `t`, memory `m`,
frames, step count `k`, block and segment summary `S` with the facts of `Waits` at the entry
valuation of `t`'s top frame `f` on `m`: if `S`'s only effect is `e`, whose access at the nodes'
values is `a`, the thread has a run to a collective call (`ToWait`), and every such run puts
`.access a` in front of `m`'s trace. -/
theorem one_event {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} {k lbl : Nat}
    {S : SegSummary} {e : SEff} {a : Access}
    (h : Waits c t m f rest (Valuation.entry c k m f, lbl, S)) (hE : S.effs = [e])
    (ha : e.access (Valuation.entry c k m f) (vals (Valuation.entry c k m f) S.nodes) = .ok a) :
    (∃ s m', ToWait c t m s m') ∧ ∀ s m', ToWait c t m s m' → m'.trace = .access a :: m.trace := by
  obtain ⟨xs, hx, he⟩ := Waits.events h (by rw [hE]; cases e <;> first | rfl | cases ha)
  rw [hE] at hx
  simp only [List.mapM_cons, List.mapM_nil, ha, bind, Except.bind, pure, Except.pure,
    Except.ok.injEq] at hx
  subst hx
  obtain ⟨_, _, _, _, hw⟩ := Waits.toWait h
  exact ⟨⟨_, _, hw⟩, he⟩

/-- `gevm`'s layout gives a binary32 4 bytes, stored and in an array. -/
theorem size_float : gevm.prog.layout.size (.fp .float) = 4 ∧
    gevm.prog.layout.stored (.fp .float) = 4 :=
  ⟨by decide +kernel, by decide +kernel⟩

/-- **The events before the barrier**: for every context `c` of `gevm`'s program, thread `t` whose
top frame `f` (above `rest`) is of `gevm`'s function at statement 1 of `%59`, memory `m`, and
`to_barrier`'s premises on `f`, `c` and `m` (`%13`, `%11` the words of `l < 32` and `w < 32`, the
shared array at offset 0 of `m`'s buffer `b`): the thread has a run to a collective call
(`ToWait`), and every such run puts one event in front of `m`'s trace, the write by `c.who` of
4 bytes at offset `4 (32 l + w)` of block `b`, not atomic. `one_event` at `to_barrier_waits`'s
segment, the store's address by obl_have. -/
theorem to_barrier_events (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 1) (l w : Nat) (hl : l < 32)
    (hw : w < 32) (acc : BitVec 32) (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    (∃ s m', ToWait c t m s m') ∧ ∀ s m', ToWait c t m s m' →
      m'.trace = .access ⟨c.who, ⟨b, ((4 * (32 * l + w) : Nat) : Int)⟩, 4, true, none, false⟩ ::
        m.trace := by
  obtain ⟨S, hS, hW⟩ :=
    to_barrier_waits c hcp t m f rest ht hf hlb hpc l w hl hw acc h13 h11 h60 b g hg hB hin hF
  have hN : S.nodes = toBarrier.nodes := by
    rw [toBarrier, hS]
    rfl
  have hE : S.effs = [.store 48 5 (.reg 60) (.node 4)] := by
    have : toBarrier.effs = [.store 48 5 (.reg 60) (.node 4)] := by decide +kernel
    rw [← this, toBarrier, hS]
    rfl
  refine one_event hW hE ?_
  rw [hN]
  obl_have h4 : (vals (Valuation.entry c t.k m f) toBarrier.nodes)[4]?
  have hst : (gevm.fn_0.blocks.find? (·.label == 48)).bind (·.stmts[5]?) =
      some ⟨none, .store false (.mk (.fp .float) (.loc 60)) (.mk (.ptr 3) (.loc 64)) (some 4),
        []⟩ := by rfl
  have ho : (l * 32 + w) * gevm.prog.layout.size (.fp .float) = 4 * (32 * l + w) := by
    rw [size_float.1]
    omega
  simp only [SEff.access, Valuation.stmt_of_fn (V := Valuation.entry c t.k m f) hf hst,
    SVal.eval_node h4]
  simp only [Val.addr?, bind, Except.bind, pure, Except.pure, Valuation.entry, hcp, size_float.2,
    ho]

/-- **The events after the barrier**: for every context `c` of `gevm`'s program, thread `t` whose
top frame `f` (above `rest`) is of `gevm`'s function at statement 7 of `%59`, memory `m`, and
`to_shfl`'s premises on `f`, `c` and `m` (`%10` the word of `x < 1024`, the shared array at
offset 0 of `m`'s buffer `b`, holding `A`): the thread has a run to a collective call (`ToWait`),
and every such run puts one event in front of `m`'s trace, the read by `c.who` of 4 bytes at
offset `4 x` of block `b`, not atomic and not invariant. `one_event` at `to_shfl_waits`'s
segment, the load's address by obl_have. -/
theorem to_shfl_events (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 7) (x : Nat) (hx : x < 1024)
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024]) (b g : Nat)
    (hg : c.globals sharedName = some ⟨b, 0⟩) (hB : m.BufferIn 3 b 4096 4 (.cta g) true)
    (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    (∃ s m', ToWait c t m s m') ∧ ∀ s m', ToWait c t m s m' →
      m'.trace = .access ⟨c.who, ⟨b, ((4 * x : Nat) : Int)⟩, 4, false, none, false⟩ ::
        m.trace := by
  obtain ⟨S, hS, hW⟩ := to_shfl_waits c hcp t m f rest ht hf hlb hpc x hx h10 A b g hg hB hin hF hA
  have hN : S.nodes = toShfl.nodes := by
    rw [toShfl, hS]
    rfl
  have hE : S.effs = [.load 48 9 (.node 2)] := by
    have : toShfl.effs = [.load 48 9 (.node 2)] := by decide +kernel
    rw [← this, toShfl, hS]
    rfl
  refine one_event hW hE ?_
  rw [hN]
  obl_have h2 : (vals (Valuation.entry c t.k m f) toShfl.nodes)[2]?
  have hst : (gevm.fn_0.blocks.find? (·.label == 48)).bind (·.stmts[9]?) =
      some ⟨some 67, .load false (.fp .float) (.mk (.ptr 3) (.loc 66)) (some 4), []⟩ := by rfl
  have ho : x * gevm.prog.layout.size (.fp .float) = 4 * x := by
    rw [size_float.1]
    omega
  simp only [SEff.access, Valuation.stmt_of_fn (V := Valuation.entry c t.k m f) hf hst,
    SVal.eval_node h2]
  simp only [Val.addr?, bind, Except.bind, pure, Except.pure, Valuation.entry, hcp, size_float.2,
    ho, List.any_nil]

/-- **The memory after the barrier's segment**, for every context `c` of `gevm`'s program,
thread `t`, memory `m` and frame `f` with `to_barrier_events`' premises: every run of the thread
to a collective call (`ToWait`) ends with the blocks of `m` but the shared array's block `b`,
which is `m`'s block `b` with the encoding of `%60`'s word `acc` written at offset `4 (32 l + w)`.
`Mem.store_inv` at `to_barrier_waits`' store, the address by obl_have. -/
theorem to_barrier_mem (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 1) (l w : Nat) (hl : l < 32)
    (hw : w < 32) (acc : BitVec 32) (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    ∀ s m', ToWait c t m s m' → ∀ blk, m.blocks b = some blk →
      m'.blocks = (m.set b (blk.put (4 * (32 * l + w))
        ((gevm.prog.layout.encode (.fp .float) (.bits 32 acc)).getD []))).blocks := by
  obtain ⟨S, hS, hW⟩ :=
    to_barrier_waits c hcp t m f rest ht hf hlb hpc l w hl hw acc h13 h11 h60 b g hg hB hin hF
  have hN : S.nodes = toBarrier.nodes := by
    rw [toBarrier, hS]
    rfl
  have hE : S.effs = [.store 48 5 (.reg 60) (.node 4)] := by
    have : toBarrier.effs = [.store 48 5 (.reg 60) (.node 4)] := by decide +kernel
    rw [← this, toBarrier, hS]
    rfl
  obtain ⟨fe, me, ws, fd, hs, -, -, -, -, -, -, -, hr, -, hwt⟩ := hW
  intro s m' h blk hb
  obtain ⟨-, rfl⟩ := ToWait.det h ⟨_, _, _, _, rfl, hs, hwt⟩
  rw [hE, hN] at hr
  obl_have h4 : (vals (Valuation.entry c t.k m f) toBarrier.nodes)[4]?
  have hst : (gevm.fn_0.blocks.find? (·.label == 48)).bind (·.stmts[5]?) =
      some ⟨none, .store false (.mk (.fp .float) (.loc 60)) (.mk (.ptr 3) (.loc 64)) (some 4),
        []⟩ := by rfl
  have ho : (l * 32 + w) * gevm.prog.layout.size (.fp .float) = 4 * (32 * l + w) := by
    rw [size_float.1]
    omega
  simp only [SEff.run, List.foldlM_cons, List.foldlM_nil, SEff.apply,
    Valuation.stmt_of_fn (V := Valuation.entry c t.k m f) hf hst, SVal.eval_node h4] at hr
  simp only [SVal.eval, Valuation.entry, h60, Val.addr?, bind, Except.bind, pure, Except.pure,
    hcp, ho] at hr
  split at hr
  · cases hr
  · rename_i m₁ hm
    cases hr
    obtain ⟨blk', bs, hc, -, hbs, rfl⟩ := Mem.store_inv hm
    have hb' := (Mem.check_inv hc).1
    simp only at hb'
    rw [hb, Option.some.injEq] at hb'
    subst hb'
    rw [hbs]
    rfl

/-- **The memory after the segment past the barrier**, for every context `c` of `gevm`'s
program, thread `t`, memory `m`, frame `f` and tensor `A` with `to_shfl_events`' premises: every
run of the thread to a collective call (`ToWait`) leaves `m` with another trace, as the segment's
one effect is the load of cell `tid.x`. `Waits.loads` at `to_shfl_waits`' segment. -/
theorem to_shfl_mem (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 7) (x : Nat) (hx : x < 1024)
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024]) (b g : Nat)
    (hg : c.globals sharedName = some ⟨b, 0⟩) (hB : m.BufferIn 3 b 4096 4 (.cta g) true)
    (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    ∀ s m', ToWait c t m s m' → m' = { m with trace := m'.trace } := by
  obtain ⟨S, hS, hW⟩ := to_shfl_waits c hcp t m f rest ht hf hlb hpc x hx h10 A b g hg hB hin hF hA
  have hE : S.effs = [.load 48 9 (.node 2)] := by
    have : toShfl.effs = [.load 48 9 (.node 2)] := by decide +kernel
    rw [← this, toShfl, hS]
    rfl
  exact Waits.loads hW fun e he => ⟨48, 9, .node 2, by rwa [hE, List.mem_singleton] at he⟩

/-- **The thread after the barrier is where `to_shfl_events` starts**, for every context `c` of
`gevm`'s program, thread `t`, memory `m` and frame `f` with `to_barrier_events`' premises and
`%10` the word of `x`: every run of the thread to a collective call (`ToWait`) ends at a wait of
some thread `u`, and `u` resumed with any value `v` (`Thread.resume`) has a top frame `fr` above
`rest` of `gevm`'s function at statement 7 of `%59` whose `%10` is still the word of `x`: the
premises of `to_shfl_events` on the thread, so it applies on every memory that meets its premises
on the memory. The segment is 5 statements long and does not set `%10`, and the barrier call has
no result, by `decide +kernel` and `rfl`; the resumed frame by `Waits.resume`. -/
theorem resume_shfl (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 1) (l w : Nat) (hl : l < 32)
    (hw : w < 32) (acc : BitVec 32) (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (x : Nat) (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x))) :
    ∀ s m', ToWait c t m s m' → ∃ u i ws d, s = .wait u i ws d ∧ ∀ v, ∃ fr,
      (Thread.resume u v).frames = fr :: rest ∧ fr.fn = gevm.fn_0 ∧
        fr.label = gevm.fn_0.b_5.label ∧ fr.pc = 7 ∧
        fr.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)) := by
  obtain ⟨S, hS, hW⟩ :=
    to_barrier_waits c hcp t m f rest ht hf hlb hpc l w hl hw acc h13 h11 h60 b g hg hB hin hF
  have e : (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6).map
      (fun S => (S.len, (S.regs.lookup 10).isNone)) = some (5, true) := by decide +kernel
  simp only [hS, Option.map_some, Option.some.injEq, Prod.mk.injEq] at e
  have hres : ((gevm.fn_0.blocks.find? (·.label == gevm.fn_0.b_5.label)).bind
      fun b => b.stmts[1 + 5]?.bind (·.res)) = none := rfl
  intro s m' h'
  obtain ⟨u, i, ws, d, rfl, H⟩ := hW.resume s m' h'
  refine ⟨u, i, ws, d, rfl, fun v => ?_⟩
  obtain ⟨fr, h1, h2, h3, h4, h5⟩ := H v
  refine ⟨fr, h1, h2.trans hf, h3, by rw [h4, hpc, e.1], ?_⟩
  rw [h5 10 (by
    rw [show (Valuation.entry c t.k m f).fn = gevm.fn_0 from hf, hpc, e.1, hres]; nofun),
    regVal, Option.isNone_iff_eq_none.1 e.2]
  exact h10

/-- **gevm_kernel's two phases meet the cell premise at `tpose 32`**, for every valid launch `L`
with `ntid.x = 1024` and event lists `E₀` and `E₁`: if every event of `E₀` is the write of
`to_barrier_events` by a thread `k` of the launch's grid (`⟨k, k / 1024⟩`, as `Grid.start` names
it), at lane `(L.env k).laneid` and warp `tid.x / 32`, to some block `b`, and every event of `E₁`
is a read by a thread of the grid, every access of the trace `rounds` of the two, with the
barriers of the grid's blocks of threads between them, is in phase 0 inside the 4 bytes of cell
`tpose 32` of its thread's place in its block, and in a later phase a read: the access premise of
`Grid.sound_cells` at `cell = tpose 32` and `w = 4`. `phases_rounds` and `Launch.tpose_env`. -/
theorem gevm_cells (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024) {E₀ E₁ : List Event}
    (h₀ : ∀ e ∈ E₀, ∃ k b, k / 1024 < volume L.grid ∧ e = .access ⟨⟨k, k / 1024⟩,
      ⟨b, ((4 * (32 * (L.env k).laneid + (L.env k).sreg .tid .x / 32) : Nat) : Int)⟩, 4, true,
      none, false⟩)
    (h₁ : ∀ e ∈ E₁, ∃ a, e = .access a ∧ a.who.cta < volume L.grid ∧ a.write = false) :
    ∀ x ∈ (phases (rounds (volume L.grid) [E₀, E₁])).1,
      (x.2 = 0 → ((tpose 32 (x.1.who.thread % volume L.block) * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤
          ((tpose 32 (x.1.who.thread % volume L.block) * 4 + 4 : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false) := by
  refine phases_rounds (Q := fun p a =>
    (p = 0 → ((tpose 32 (a.who.thread % volume L.block) * 4 : Nat) : Int) ≤ a.ptr.off ∧
      a.ptr.off + a.len ≤ ((tpose 32 (a.who.thread % volume L.block) * 4 + 4 : Nat) : Int)) ∧
    (p ≠ 0 → a.write = false)) fun p E hp e he => ?_
  rcases p with _ | _ | p <;> simp only [List.getElem?_cons_zero, List.getElem?_cons_succ,
    List.getElem?_nil, Option.some.injEq, reduceCtorEq] at hp
  · subst hp
    obtain ⟨k, b, hk, rfl⟩ := h₀ e he
    obtain ⟨hv, -, -, hc⟩ := Launch.tpose_env hL hx k
    refine ⟨_, rfl, hk, fun _ => ?_, fun h => absurd rfl h⟩
    simp only [hv, hc]
    omega
  · subst hp
    obtain ⟨a, rfl, ha, hw⟩ := h₁ e he
    exact ⟨a, rfl, ha, fun h => absurd h (by omega), fun _ => hw⟩

/-- **The trace of gevm_kernel's threads around the barrier meets the cell premise**, for every
valid launch `L` with `ntid.x = 1024`, families of runs `R₁` and `R₂`, threads `ns` of the grid
and memories: if each run of thread `n` by `R₁` puts the write of `to_barrier_events` in front of
the trace (at lane `(L.env n).laneid` and warp `tid.x / 32`, to some block), and each run by `R₂`
a read of 4 bytes by it (`to_shfl_events`), then after threads `ns` run in turn by `R₁` from a
memory with an empty trace, the barriers of the grid's blocks of threads are logged and threads
`ns` run in turn by `R₂`, the trace meets the access premise of `Grid.sound_cells` at
`cell = tpose 32` and `w = 4`. `Seq.bar_rounds`, `Turns.events` and `gevm_cells`. -/
theorem gevm_turns (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024)
    {R₁ R₂ : Nat → Mem → Mem → Prop} {ns : List Nat} (hns : ∀ n ∈ ns, n / 1024 < volume L.grid)
    (hR₁ : ∀ n ∈ ns, ∀ m m', R₁ n m m' → ∃ b, m'.trace = .access ⟨⟨n, n / 1024⟩,
      ⟨b, ((4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32) : Nat) : Int)⟩, 4, true,
      none, false⟩ :: m.trace)
    (hR₂ : ∀ n ∈ ns, ∀ m m', R₂ n m m' →
      ∃ q, m'.trace = .access ⟨⟨n, n / 1024⟩, q, 4, false, none, false⟩ :: m.trace)
    {m₀ m₁ m' : Mem} {Es₁ Es₂ : List (List Event)} (h0 : m₀.trace = [])
    (h₁ : Turns R₁ ns m₀ Es₁ m₁)
    (h₂ : Turns R₂ ns ((List.range (volume L.grid)).foldl (fun m b => m.log (.barrier b)) m₁)
      Es₂ m') :
    ∀ x ∈ (phases m'.trace).1,
      (x.2 = 0 → ((tpose 32 (x.1.who.thread % volume L.block) * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤
          ((tpose 32 (x.1.who.thread % volume L.block) * 4 + 4 : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false) := by
  rw [Seq.bar_rounds h0 h₁ h₂]
  refine gevm_cells L hL hx (fun e he => ?_) fun e he => ?_
  · obtain ⟨n, hn, m₂, m₃, E, hR, hE, he⟩ := Turns.events h₁ e he
    obtain ⟨b, hb⟩ := hR₁ n hn m₂ m₃ hR
    rw [hb, ← List.singleton_append] at hE
    rw [List.append_cancel_right hE.symm, List.mem_singleton] at he
    exact ⟨n, b, hns n hn, he⟩
  · obtain ⟨n, hn, m₂, m₃, E, hR, hE, he⟩ := Turns.events h₂ e he
    obtain ⟨q, hq⟩ := hR₂ n hn m₂ m₃ hR
    rw [hq, ← List.singleton_append] at hE
    rw [List.append_cancel_right hE.symm, List.mem_singleton] at he
    exact ⟨_, he, hns n hn, rfl⟩

/-- **The shared array after the first round holds the threads' words**, for every valid launch
`L` with `ntid.x = 1024`, family of runs `R₁`, threads `ns`, block number `b`, block of threads
`g`, words `acc n`, memories and barriers `bs`: if each run of thread `n` of `ns` writes the
encoding of `acc n` at offset `4 (32 l + w)` of block `b` (lane `l = (L.env n).laneid`, warp
`w = tid.x / 32`, as `to_barrier_mem` does) when `n` is a thread of `g` and keeps block `b`
otherwise, every thread `1024 g + k` (`k < 1024`) is in `ns`, and `m₀` has the shared array's
buffer at `b` (`to_shfl_events`' `hB` and `hF`), then after threads `ns` run in turn from `m₀` and
the barriers `bs` are logged, the memory still has that buffer, and block `b` holds row-major the
tensor whose element `x` is the word of thread `1024 g + tpose 32 x`, the thread whose cell is
`x`: the memory premises of `to_shfl_events`, at a tensor each of whose elements is a word one
thread of the first round stored. `Turns.cells` at cell `tpose 32 (n % 1024)` for the threads of
`g` (`tpose_tpose`, `Launch.tpose_env`), `Mem.BufferIn.bytes` and `Mem.log_barriers`. -/
theorem gevm_buffer (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024)
    {R₁ : Nat → Mem → Mem → Prop} {ns : List Nat} (b g : Nat) (acc : Nat → BitVec 32)
    (hR₁ : ∀ n ∈ ns, ∀ m m', R₁ n m m' → ∀ blk, m.blocks b = some blk →
      m'.blocks b = some (if n / 1024 = g then
        blk.put (4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32))
          ((gevm.prog.layout.encode (.fp .float) (.bits 32 (acc n))).getD [])
      else blk))
    (hall : ∀ k < 1024, 1024 * g + k ∈ ns) {m₀ m₁ m₂ : Mem} {Es₁ : List (List Event)}
    (h₁ : Turns R₁ ns m₀ Es₁ m₁) (bs : List Nat)
    (h₂ : m₂ = bs.foldl (fun m b => m.log (.barrier b)) m₁)
    (hB : m₀.BufferIn 3 b 4096 4 (.cta g) true)
    (hF : ∃ blk, m₀.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    m₂.BufferIn 3 b 4096 4 (.cta g) true ∧
      (∃ blk, m₂.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) ∧
      m₂.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
        (rowMajor gevm.prog.layout (.fp .float) 0)
        (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] =>
          Model.ofBits (acc (1024 * g + tpose 32 i.1.val))) := by
  subst h₂
  rw [Mem.log_barriers]
  have hlt n : tpose 32 (n % 1024) < 1024 := tpose_lt (Nat.mod_lt n (by decide))
  let cell : Nat → Option (TorchLean.Shape.Coord [1024]) := fun n =>
    if n / 1024 = g then some (⟨tpose 32 (n % 1024), hlt n⟩, ()) else none
  have hwr n i (h : cell n = some i) : n = 1024 * g + tpose 32 i.1.val := by
    simp only [cell] at h
    split at h
    · rename_i hg
      cases h
      have := tpose_tpose (n := 32) (t := n % 1024) (Nat.mod_lt n (by decide))
      show n = 1024 * g + tpose 32 (tpose 32 (n % 1024))
      rw [this, ← hg]
      omega
    · cases h
  obtain ⟨blk, hb, -, -, -, -, hsz, -⟩ := id hB
  have hc := Layout.Codec.float gevm.prog.layout .float
  obtain ⟨⟨β, hβ⟩, wr, hwr', hH⟩ := Turns.cells
    (val := fun n => Model.ofBits (fmt := FloatTy.float.fmt) (acc n))
    (bs := fun n => (gevm.prog.layout.encode (.fp .float) (.bits 32 (acc n))).getD [])
    (cell := cell) h₁ hc (fun n => by
      obtain ⟨bs', he, -, -⟩ := hc.round (Model.ofBits (fmt := FloatTy.float.fmt) (acc n))
      exact he.trans (by rw [← he]; rfl))
    (apart_rowMajor _ _ 0)
    (fun n _ n' _ i h h' => (hwr n i h).trans (hwr n' i h').symm)
    (fun n hn m m' hr blk hb => by
      rw [hR₁ n hn m m' hr blk hb]
      obtain ⟨-, -, -, htp⟩ := Launch.tpose_env hL hx n
      by_cases hg : n / 1024 = g
      · simp only [cell, hg, ite_true, Option.elim]
        rw [rowMajor_one, size_float.1, htp, Nat.mul_comm 4]
      · simp only [cell, hg, ite_false, Option.elim])
    hb (fun i => by
      have := rowMajor_inb gevm.prog.layout (.fp .float) 0 i
      have hs : TorchLean.Shape.size [1024] * gevm.prog.layout.size (.fp .float) = 4096 := by
        rw [size_float.1]
        rfl
      rw [Nat.zero_add, hs] at this
      omega)
    (fun i => by
      obtain ⟨⟨k, hk⟩, ⟨⟩⟩ := i
      have := tpose_lt (n := 32) hk
      have e1 : (1024 * g + tpose 32 k) / 1024 = g := by omega
      have e2 : (1024 * g + tpose 32 k) % 1024 = tpose 32 k := by omega
      refine ⟨1024 * g + tpose 32 k, hall _ this, ?_⟩
      simp only [cell, e1, ite_true]
      refine congrArg some (Prod.ext (Fin.ext ?_) rfl)
      show tpose 32 ((1024 * g + tpose 32 k) % 1024) = k
      rw [e2]
      exact tpose_tpose (n := 32) hk)
  have e : (fun i => Model.ofBits (fmt := FloatTy.float.fmt) (acc (wr i))) =
      fun i : TorchLean.Shape.Coord [1024] =>
        Model.ofBits (fmt := FloatTy.float.fmt) (acc (1024 * g + tpose 32 i.1.val)) :=
    funext fun i => by rw [← hwr (wr i) i (hwr' i).2]
  rw [e] at hH
  obtain ⟨blk', hb', hF'⟩ := hF
  rw [hb, Option.some.injEq] at hb'
  subst hb'
  exact ⟨Mem.BufferIn.bytes hB hb hβ, ⟨_, hβ, hF'⟩, hH⟩

/-- The memory premises of `to_shfl_events` on `m`, for every block number `b`, block of threads
`g` and tensor `A`: block `b` is the shared array's buffer of `g`, its end is in the address
space, and it holds `A` row-major. -/
def ShflMem (b g : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024]) (m : Mem) :
    Prop :=
  m.BufferIn 3 b 4096 4 (.cta g) true ∧
    (∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) ∧
    m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A

/-- **Every thread after the barrier starts on the first round's words**, for every valid launch
`L` with `ntid.x = 1024`, families of runs `R₁` and `R₂`, threads `ns`, block number `b`, block of
threads `g`, words `acc n`, memories and barriers `bs` with `gevm_buffer`'s premises: if the
threads `ns` then run in turn again by `R₂` from the memory after the barriers, and each run of
`R₂` from a memory of `ShflMem` at the tensor `A` whose element `x` is the word of thread
`1024 g + tpose 32 x` changes only the trace (as `to_shfl_mem`'s runs do), then every thread of
that second round starts on a memory of `ShflMem` at `A`: the threads run in turn by `R₂`
restricted to such starts, so `to_shfl_events` applies to each, at a tensor each of whose
elements is the word one thread of the first round stored at its cell. `gevm_buffer` and
`Turns.imp`. -/
theorem gevm_reads (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024)
    {R₁ R₂ : Nat → Mem → Mem → Prop} {ns : List Nat} (b g : Nat) (acc : Nat → BitVec 32)
    (hR₁ : ∀ n ∈ ns, ∀ m m', R₁ n m m' → ∀ blk, m.blocks b = some blk →
      m'.blocks b = some (if n / 1024 = g then
        blk.put (4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32))
          ((gevm.prog.layout.encode (.fp .float) (.bits 32 (acc n))).getD [])
      else blk))
    (hall : ∀ k < 1024, 1024 * g + k ∈ ns) {m₀ m₁ m₂ m₃ : Mem} {Es₁ Es₂ : List (List Event)}
    (h₁ : Turns R₁ ns m₀ Es₁ m₁) (bs : List Nat)
    (h₂ : m₂ = bs.foldl (fun m b => m.log (.barrier b)) m₁)
    (hB : m₀.BufferIn 3 b 4096 4 (.cta g) true)
    (hF : ∃ blk, m₀.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (h₃ : Turns R₂ ns m₂ Es₂ m₃)
    (hR₂ : ∀ n ∈ ns, ∀ m m', R₂ n m m' →
      ShflMem b g (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] =>
        Model.ofBits (acc (1024 * g + tpose 32 i.1.val))) m →
      m' = { m with trace := m'.trace }) :
    Turns (fun n m m' =>
      ShflMem b g (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] =>
        Model.ofBits (acc (1024 * g + tpose 32 i.1.val))) m ∧ R₂ n m m') ns m₂ Es₂ m₃ := by
  refine (h₃.imp (P := ShflMem b g _) (fun n hn m m' hr hP => ⟨⟨hP, hr⟩, ?_⟩)
    (gevm_buffer L hL hx b g acc hR₁ hall h₁ bs h₂ hB hF)).1
  rw [hR₂ n hn m m' hr hP]
  exact hP

/-- **The twin of `gevm_cells`: without the barrier**, on one block of threads: thread 0's write of
cell 0 (`tpose 32 0 = 0`) and thread 1's read of cell 1 in one round, with no barrier between them,
are both in phase 0, and the read's 4 bytes at offset 4 are outside thread 1's cell
`tpose 32 1 = 32`, so the access premise of `Grid.sound_cells` at `cell = tpose 32` fails. By
`phasesF_eq` and `decide +kernel`. -/
theorem no_barrier : ¬ ∀ x ∈ (phases (rounds 1 [[.access ⟨⟨1, 0⟩, ⟨0, 4⟩, 4, false, none, false⟩,
    .access ⟨⟨0, 0⟩, ⟨0, 0⟩, 4, true, none, false⟩]])).1,
    (x.2 = 0 → ((tpose 32 (x.1.who.thread % 1024) * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
      x.1.ptr.off + x.1.len ≤ ((tpose 32 (x.1.who.thread % 1024) * 4 + 4 : Nat) : Int)) := by
  rw [(phasesF_eq _).1]
  decide +kernel

end MojoProofTest.SegEvents
