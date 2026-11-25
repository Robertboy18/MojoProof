import MojoProofTest.SegEvents
import MojoProofTest.OblGevmThread

/-!
# gevm_kernel's whole trace: two rounds that meet `Grid.sound_rounds`

docs/proofs/barrier-owned.md, "A whole trace of rounds". One program, gevm_kernel float32
`1308aaae` (`gevm`, MojoProofTest/SymLane.lean), on every valid launch with `ntid.x = 1024`.
Before its barrier a thread runs the entry block and the loop, whose events are the loop's
global loads, then stores its sum to its cell `32 l + w` of the shared array; after it the thread
loads cell `tid.x`, runs five shuffles, which add no event, and lane 0 stores the warp's sum to
the output cell `32 ctaid.x + tid.x / 32`, a global block.

* `Before`, `After`: the events of thread `k` before and after the barrier, relative to the
  last memory `z` (the owners of its blocks, `Mem.ctaOf`) and the output block `bo`.
* `warpTiles`: the output's tiling, lane 0 of warp `k / 32` owning the 4 bytes at `4 (k / 32)`.
* `gevm_rounds`: two rounds of such events meet `Mem.CellAt` at `cell = tpose 32`, `w = 4` and
  `warpTiles`; `gevm_inv`: no `!invariant.load` read is to a block a write of theirs touches.
* `gevm_sound`: so a run whose trace extends an empty one by events of `Before`, then, after the
  barriers, by events of `After` (`Ext`) makes the start's grid sound (`Grid.sound_rounds`).
* The round-by-round facts, each thread's segments in order: `entry_events` (the entry block
  adds no event), `latch_reads` (the loop's latch adds reads), `to_barrier_events` and
  `to_shfl_events` (MojoProofTest/SegEvents.lean), `shfl_events` (the segments between the
  shuffles add no event, `no_event`), and `thread_trace` (the end: lane 0's store or nothing,
  from `thread`, MojoProofTest/OblGevmThread.lean).
* `gevm_before`, `gevm_after`: threads in turn with those facts extend the trace by events of
  `Before` and of `After` (`Ext.turns`, `Ext.trans`); `out_cell`: on a grid with one block of
  threads in `y` and `z`, lane 0's output cell is `k / 32`.
* The twin of `out_cell`: without the grid's sides in `y` and `z` the goal stays open; on a grid
  of two blocks of threads in `y`, threads `0` and `1024` have output cell `0`.

Not proved here: that the loop's run adds only reads of blocks that are no block of threads'
shared memory and not the output (a premise of `gevm_before`; `latch_reads` gives reads by the
thread, not their blocks), that the start's threads reach `%59` with `to_barrier_events`'
premises, and the owners of the blocks in the last memory (premises of `Before` and `After`).
-/

namespace MojoProofTest.GevmTrace

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open GPUProof (Path)
open MojoProofTest.OblGevm MojoProofTest.SegEvents MojoProofTest.OblGevmThread
open FloatLib.Floats.Formats.BinaryInterchange

/-- An event of thread `k` of gevm_kernel before its barrier, on launch `L` with last memory `z`
and output block `bo`: `k` is a thread of the grid (`k / 1024 < volume L.grid`), and the event
is either the write of `to_barrier_events` by `k` (`⟨k, k / 1024⟩`, as `Grid.start` names it) of
4 bytes at offset `4 (32 l + w)`, lane `l = (L.env k).laneid` and warp `w = tid.x / 32`, of a
block of threads' shared memory in `z`, or a read by `k` of a block that is no block of threads'
shared memory in `z` and is not `bo` (the loop's loads). -/
def Before (L : Launch) (z : Mem) (bo k : Nat) (e : Event) : Prop :=
  k / 1024 < volume L.grid ∧
    ((∃ b, (z.ctaOf b).isSome ∧ e = .access ⟨⟨k, k / 1024⟩,
      ⟨b, ((4 * (32 * (L.env k).laneid + (L.env k).sreg .tid .x / 32) : Nat) : Int)⟩, 4, true,
      none, false⟩) ∨
    ∃ a, e = .access a ∧ a.who = ⟨k, k / 1024⟩ ∧ a.write = false ∧ z.ctaOf a.ptr.block = none ∧
      a.ptr.block ≠ bo)

/-- An event of thread `k` of gevm_kernel after its barrier, on launch `L` with last memory `z`,
output block `bo` and output length `N`: `k` is a thread of the grid, and the event is either a
read by `k` of 4 bytes of a block of threads' shared memory in `z`, not invariant
(`to_shfl_events`), or, for lane 0 (`k % 32 = 0`) with `k / 32 < N`, the write of 4 bytes at
offset `4 (k / 32)` of `bo` (`thread_trace`, at `out_cell`). -/
def After (L : Launch) (z : Mem) (bo N k : Nat) (e : Event) : Prop :=
  k / 1024 < volume L.grid ∧
    ((∃ q, (z.ctaOf q.block).isSome ∧ e = .access ⟨⟨k, k / 1024⟩, q, 4, false, none, false⟩) ∨
    k % 32 = 0 ∧ k / 32 < N ∧
      e = .access ⟨⟨k, k / 1024⟩, ⟨bo, ((k / 32 * 4 : Nat) : Int)⟩, 4, true, none, false⟩)

/-- The tiling of gevm_kernel's output of `N` binary32: thread `k` of lane 0 (`k % 32 = 0`)
with `k / 32 < N` has the 4 bytes at `4 (k / 32)`, every other thread the empty tile at
`min (4 (k / 32)) (4 N)`, inside `4 N` bytes. -/
def warpTile (N : Nat) : Tiling Nat where
  off k := min (4 * (k / 32)) (4 * N)
  len k := if k % 32 = 0 then if k / 32 < N then 4 else 0 else 0
  ext := 4 * N
  inb k := by split_ifs <;> omega
  disj i j hij := by split_ifs <;> omega

/-- The discipline of gevm_kernel's writes outside shared memory: block `bo` tiled by
`warpTile N`, no other block. -/
def warpTiles (bo N b : Nat) : Option (Tiling Nat) :=
  if b = bo then some (warpTile N) else none

/-- **gevm_kernel's rounds meet the cell premise**, for every valid launch `L` with
`ntid.x = 1024`, memory `z`, output block `bo` of no block of threads in `z`, output length `N`
and event lists `E₀` and `E₁`: if every event of `E₀` is an event of `Before` and every event of
`E₁` one of `After`, each by some thread, every event of round `p` of `[E₀, E₁]` is an access by
a block of threads of the grid meeting `Mem.CellAt` at `cell = tpose 32`, `w = 4` and
`warpTiles bo N`: the premise `hE` of `Grid.sound_rounds`. `Launch.tpose_env`. -/
theorem gevm_rounds (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024) (z : Mem) (bo N : Nat)
    (hbo : z.ctaOf bo = none) {E₀ E₁ : List Event} (h₀ : ∀ e ∈ E₀, ∃ k, Before L z bo k e)
    (h₁ : ∀ e ∈ E₁, ∃ k, After L z bo N k e) :
    ∀ p E, [E₀, E₁][p]? = some E → ∀ e ∈ E, ∃ a, e = .access a ∧ a.who.cta < volume L.grid ∧
      z.CellAt (volume L.block) 4 (tpose 32) (warpTiles bo N) p a := by
  intro p E hp e he
  rcases p with _ | _ | p <;> simp only [List.getElem?_cons_zero, List.getElem?_cons_succ,
    List.getElem?_nil, Option.some.injEq, reduceCtorEq] at hp
  · subst hp
    obtain ⟨k, hk, ⟨b, hb, rfl⟩ | ⟨a, rfl, hw, hr, hn, hne⟩⟩ := h₀ e he
    · obtain ⟨hv, -, -, hc⟩ := Launch.tpose_env hL hx k
      refine ⟨_, rfl, hk, fun _ _ => ⟨fun _ => ?_, fun h => absurd rfl h⟩,
        fun h => absurd h (Option.isSome_iff_ne_none.1 hb)⟩
      simp only [hv, hc]
      omega
    · refine ⟨a, rfl, by rw [hw]; exact hk, ?_⟩
      exact ⟨fun _ h => (by rw [hn] at h; cases h),
        fun _ => ⟨fun _ => hr, fun t ht => by simp [warpTiles, hne] at ht⟩⟩
  · subst hp
    obtain ⟨k, hk, ⟨q, hq, rfl⟩ | ⟨h0, hN, rfl⟩⟩ := h₁ e he
    · exact ⟨_, rfl, hk, fun _ _ => ⟨fun h => absurd h (by omega), fun _ => rfl⟩,
        fun h => absurd h (Option.isSome_iff_ne_none.1 hq)⟩
    · refine ⟨_, rfl, hk, ?_⟩
      refine ⟨fun _ h => (by rw [hbo] at h; cases h),
        fun _ => ⟨fun h => by simp [warpTiles] at h, fun t ht => ?_⟩⟩
      rw [warpTiles, ite_eq_left_of_eq_true _ _ (eq_true rfl), Option.some.injEq] at ht
      subst ht
      simp only [warpTile, id]
      split_ifs
      omega

/-- **gevm_kernel's rounds keep the promise of `!invariant.load`**, for every launch `L`, memory
`z`, output block `bo`, output length `N`, number `G` of blocks of threads and event lists `E₀`
and `E₁` of `Before` and `After` events: no invariant access of `rounds G [E₀, E₁]` is to the
block of one of its writes, since the invariant ones are reads of blocks of no block of threads
other than `bo`, and the writes are to shared memory or `bo`: the premise `hI` of
`Grid.sound_rounds`. -/
theorem gevm_inv (L : Launch) (z : Mem) (bo N G : Nat) {E₀ E₁ : List Event}
    (h₀ : ∀ e ∈ E₀, ∃ k, Before L z bo k e) (h₁ : ∀ e ∈ E₁, ∃ k, After L z bo N k e) :
    ∀ a e, Event.access a ∈ rounds G [E₀, E₁] → Event.access e ∈ rounds G [E₀, E₁] →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block := by
  have hmem : ∀ a, Event.access a ∈ rounds G [E₀, E₁] →
      (∃ k, Before L z bo k (.access a)) ∨ ∃ k, After L z bo N k (.access a) := by
    intro a ha
    rw [show rounds G [E₀, E₁] = E₁ ++ (bars G ++ E₀) from rfl] at ha
    have hb : Event.access a ∉ bars G := by simp [bars]
    rcases List.mem_append.1 ha with ha | ha
    · exact .inr (h₁ _ ha)
    · rcases List.mem_append.1 ha with ha | ha
      · exact absurd ha hb
      · exact .inl (h₀ _ ha)
  intro a e ha he hi hw hab
  have ha' : z.ctaOf a.ptr.block = none ∧ a.ptr.block ≠ bo := by
    rcases hmem a ha with
      ⟨k, -, ⟨b, -, h⟩ | ⟨a', h, -, -, hn, hne⟩⟩ | ⟨k, -, ⟨q, -, h⟩ | ⟨-, -, h⟩⟩ <;> cases h
    · cases hi
    · exact ⟨hn, hne⟩
    · cases hi
    · cases hi
  rcases hmem e he with
    ⟨k, -, ⟨b, hb, h⟩ | ⟨a', h, -, hw', -, -⟩⟩ | ⟨k, -, ⟨q, -, h⟩ | ⟨-, -, h⟩⟩ <;> cases h
  · rw [hab] at ha'
    exact absurd ha'.1 (Option.isSome_iff_ne_none.1 hb)
  · exact nomatch hw.symm.trans hw'
  · cases hw
  · exact ha'.2 hab

/-- **gevm_kernel's whole run, sound from its two rounds.** For every program, kernel `fn`,
valid launch `L` with `ntid.x = 1024`, arguments, address choice and oracle whose start gives
grid `g₀` and contexts `c`, on a caller's memory meeting `Mem.BytesIn`, every observation `obs`
that reads only the blocks, output block `bo` and output length `N`: one run from `g₀` to a grid
`z` in which every thread has returned, with `bo` no block of threads' shared memory in `z`,
whose trace extends a memory `m₀` with an empty trace to `m₁` by events of `Before` and then, with
the barriers of the grid's blocks of threads logged, to `z`'s memory by events of `After`
(`Ext`), and whose observation is `y` with `R y`, makes `g₀` sound (`Grid.Sound`). `Ext.rounds`,
`gevm_rounds`, `gevm_inv` and `Grid.sound_rounds` at `tpose 32` (injective on `[0, 1024)`,
`tpose_tpose`). The events of gevm_kernel's threads are `Before` and `After` events by
`gevm_before` and `gevm_after`; one program, gevm_kernel. -/
theorem gevm_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    (hL : L.Valid) (hx : L.block .x = 1024) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    (bo N : Nat)
    (hbo : z.mem.ctaOf bo = none) {m₀ m₁ : Mem} (h0 : m₀.trace = [])
    (hb : Ext (fun e => ∃ k, Before L z.mem bo k e) m₀ m₁)
    (ha : Ext (fun e => ∃ k, After L z.mem bo N k e)
      ((List.range (volume L.grid)).foldl (fun m b => m.log (.barrier b)) m₁) z.mem)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R := by
  obtain ⟨E₀, E₁, ht, h₀, h₁⟩ := Ext.rounds h0 hb ha
  have hv := (Launch.tpose_env hL hx 0).1
  exact Grid.sound_rounds h hm hB run hz hL.volume_pos
    (fun i hi j hj e => by
      rw [hv] at hi hj
      rw [← tpose_tpose (n := 32) hi, e, tpose_tpose (n := 32) hj])
    ht (gevm_rounds L hL hx z.mem bo N hbo h₀ h₁)
    (by rw [ht]; exact gevm_inv L z.mem bo N _ h₀ h₁) hy hR

/-- **The entry block adds no event**, for every `fmul contract` setting, context, thread, memory,
frames and valuation `V` with the facts of `EndsWith` at gevm_kernel's entry block `%6`
(`entry`, which `Block.sound` gives): the thread's steps reach the block's terminator, whose
step succeeds, on a memory with `V.mem`'s trace. `EndsWith.events`; `entry` has no effect. -/
theorem entry_events {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation}
    (h : EndsWith contract c t m f rest (V, gevm.fn_0.b_0.label, entry)) :
    ∃ fe me r, Steps c t m ⟨fe :: rest, V.k + entry.len⟩ me ∧
      step c ⟨fe :: rest, V.k + entry.len⟩ me = .ok r ∧ me.trace = V.mem.trace := by
  have h0 : entry.effs = [] := by decide +kernel
  obtain ⟨fe, me, xs, r, hs, hx, ha, e⟩ := EndsWith.events h (by rw [h0]; rfl)
  rw [h0] at ha
  simp only [List.mapM_nil, pure, Except.pure, Except.ok.injEq] at ha
  subst ha
  exact ⟨fe, me, r, hs, hx, e⟩

/-- **The loop's latch adds reads**, for every `fmul contract` setting, context, thread, memory,
frames and valuation `V` with the facts of `EndsWith` at gevm_kernel's latch `%45` (`latch`):
the thread's steps reach the block's terminator, whose step succeeds, on a memory that extends
`V.mem`'s trace by reads by `V.ctx.who` only (`Ext`). `EndsWith.reads`; `latch`'s effects are
its two loads. Their blocks, the matrix's and the vector's, are not stated. -/
theorem latch_reads {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation}
    (h : EndsWith contract c t m f rest (V, gevm.fn_0.b_4.label, latch)) :
    ∃ fe me r, Steps c t m ⟨fe :: rest, V.k + latch.len⟩ me ∧
      step c ⟨fe :: rest, V.k + latch.len⟩ me = .ok r ∧
      Ext (fun e => ∃ a, e = .access a ∧ a.who = V.ctx.who ∧ a.write = false) V.mem me :=
  EndsWith.reads h fun e he => by
    have hl : ∀ e ∈ latch.effs, (match e with | .load .. => true | _ => false) = true := by
      decide +kernel
    have := hl e he
    cases e with
    | load lbl pc p => exact ⟨lbl, pc, p, rfl⟩
    | store => cases this
    | alloca => cases this

/-- **A segment with no effect adds no event**, for every program, context `c`, thread `t`,
memory `m`, frames, step count `k`, block and segment summary `S` with the facts of `Waits` at
the entry valuation of `t`'s top frame on `m`: if `S` has no effect, the thread has a run to a
collective call (`ToWait`), and every such run leaves `m`'s trace (`Waits.events`). -/
theorem no_event {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} {k lbl : Nat}
    {S : SegSummary} (h : Waits c t m f rest (Valuation.entry c k m f, lbl, S))
    (hE : S.effs = []) :
    (∃ s m', ToWait c t m s m') ∧ ∀ s m', ToWait c t m s m' → m'.trace = m.trace := by
  obtain ⟨xs, hx, he⟩ := Waits.events h (by rw [hE]; rfl)
  rw [hE] at hx
  simp only [List.mapM_nil, pure, Except.pure, Except.ok.injEq] at hx
  subst hx
  obtain ⟨_, _, _, _, hw⟩ := Waits.toWait h
  exact ⟨⟨_, _, hw⟩, he⟩

/-- **The segments between the shuffles add no event**, for every context `c` of `gevm`'s
program, thread `t` whose top frame `f` (above `rest`) is of `gevm`'s function at statement
`12 + 4 j` of `%59` for `j < 4`, memory `m`, and `shfl_round_waits`' premises on `f`: the thread
has a run to the next shuffle (`ToWait`), and every such run leaves `m`'s trace. `no_event` at
`shfl_round_waits`' segment, whose effects are none (`decide +kernel` for each `j`). -/
theorem shfl_events (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (j : Nat) (hj : j < 4) (hpc : f.pc = 12 + 4 * j)
    (y z : Model FloatTy.float.fmt) (hy : f.regs (67 + 4 * j) = some (Val.ofFloat .float y))
    (hz : f.regs (69 + 4 * j) = some (Val.ofFloat .float z))
    (hp : f.prods (67 + 4 * j) = none) :
    (∃ s m', ToWait c t m s m') ∧ ∀ s m', ToWait c t m s m' → m'.trace = m.trace := by
  obtain ⟨S, hS, hW⟩ := shfl_round_waits c hcp t m f rest ht hf hlb j hj hpc y z hy hz hp
  have e : (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label (12 + 4 * j)
      (15 + 4 * j)).map (·.effs.isEmpty) = some true := by
    interval_cases j <;> decide +kernel
  simp only [hS, Option.map_some, Option.some.injEq, List.isEmpty_iff] at e
  exact no_event hW e

/-- **A thread of gevm_kernel from `%59` to its end, with its end's events.** One program,
gevm_kernel float32 `1308aaae`. For every context, thread, memory, frame and values with the
premises of `thread` (MojoProofTest/OblGevmThread.lean): the thread waits at the barrier, then at
five `shfl.sync.bfly` calls, each at its statement of `%59` (`Thread.at`), resumed each time with
the delivery, and runs to its end on a memory
whose trace is, for lane 0 (`l = 0`), the write by `c.who` of 4 bytes at cell `o` of `p0`, not
atomic, and for the other lanes nothing, in front of the trace of `d₅.2`, the memory the fifth
shuffle delivers. `thread`, with `Mem.store_trace` at its end. -/
theorem thread_trace (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (ht : t.frames = [f]) (hf : f.fn = gevm.fn_0) (hlb : f.label = gevm.fn_0.b_5.label)
    (hpc : f.pc = 1) (ha : f.allocas = []) (l w x : Nat) (hl : l < 32) (hw : w < 32)
    (hx : x < 1024) (acc : BitVec 32) (p0 N o : Nat) (ho : o < N)
    (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (h60 : f.regs 60 = some (.bits 32 acc))
    (h29 : f.regs 29 = some (.ptr ⟨p0, ((o * 4 : Nat) : Int)⟩))
    (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (d₀ d₁ d₂ d₃ d₄ d₅ : Option Val × Mem)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024])
    (hB₀ : d₀.2.BufferIn 3 b 4096 4 (.cta g) true)
    (hF₀ : ∃ blk, d₀.2.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : d₀.2.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt)
    (hd₁ : d₁.1 = some (Val.ofFloat .float z₁)) (hd₂ : d₂.1 = some (Val.ofFloat .float z₂))
    (hd₃ : d₃.1 = some (Val.ofFloat .float z₃)) (hd₄ : d₄.1 = some (Val.ofFloat .float z₄))
    (hd₅ : d₅.1 = some (Val.ofFloat .float z₅))
    (hy : d₅.2.Buffer p0 (N * 4) 4 true) (hfy : d₅.2.Fits gevm.prog.layout p0 (N * 4)) :
    RunsVia c (fun m' => m'.trace = (if l = 0 then
        [.access ⟨c.who, ⟨p0, ((o * 4 : Nat) : Int)⟩, 4, true, none, false⟩] else []) ++
        d₅.2.trace)
      [(fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6) ∧ i = .barrier, d₀),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 11) ∧
          i = .shfl .bfly, d₁),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 15) ∧
          i = .shfl .bfly, d₂),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 19) ∧
          i = .shfl .bfly, d₃),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 23) ∧
          i = .shfl .bfly, d₄),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 27) ∧
          i = .shfl .bfly, d₅)] t m := by
  have H := thread c hcp t m f ht hf hlb hpc ha l w x hl hw hx acc p0 N o ho h13 h11 h10 h60 h29
    b g hg hB hin hF d₀ d₁ d₂ d₃ d₄ d₅ A hB₀ hF₀ hA z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄ hd₅ hy hfy
  have mono : ∀ {Q Q' : Mem → Prop}, (∀ m', Q m' → Q' m') →
      ∀ ws t m, RunsVia c Q ws t m → RunsVia c Q' ws t m := by
    intro Q Q' hQ ws
    induction ws with
    | nil =>
      intro t m h
      obtain ⟨m', h, hq⟩ := h
      exact ⟨m', h, hQ m' hq⟩
    | cons p ws ih =>
      obtain ⟨P, d⟩ := p
      intro t m h
      obtain ⟨u, i, xs, e, m₁, h1, h2, h3⟩ := h
      exact ⟨u, i, xs, e, m₁, h1, h2, ih _ _ h3⟩
  refine mono (fun m' hm' => ?_) _ t m H
  by_cases hl0 : l = 0
  · rw [ite_eq_left_of_eq_true _ _ (eq_true hl0), Mem.store_trace (hm'.1 hl0), size_float.2]
    rfl
  · rw [ite_eq_right_of_eq_false _ _ (eq_false hl0), hm'.2 hl0]
    rfl

/-- **Lane 0's output cell on a grid of one row**, for every valid launch `L` with
`ntid.x = 1024` whose grid has side 1 in `y` and `z` and every thread `k` of its grid: the cell
`32 ctaid.x + tid.x / 32` of `%29` (`entry_regs`) is `k / 32`, so distinct warps have distinct
cells. -/
theorem out_cell (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024) (hgy : L.grid .y = 1)
    (hgz : L.grid .z = 1) (k : Nat) (hk : k / 1024 < volume L.grid) :
    (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 = k / 32 := by
  obtain ⟨hv, ht, -, -⟩ := Launch.tpose_env hL hx k
  rw [ht]
  simp only [Launch.env, coord, hv]
  simp only [volume, hgy, hgz, Nat.mul_one] at hk
  rw [Nat.mod_eq_of_lt hk]
  omega

/--
error: unsolved goals
L : Launch
hL : L.Valid
hx : L.block Dim.x = 1024
k : ℕ
hk : k / 1024 < volume L.grid
hv : volume L.block = 1024
ht : (L.env k).sreg SReg.tid Dim.x = k % 1024
⊢ k / 1024 % L.grid Dim.x * 32 + k % 1024 / 32 = k / 32
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `out_cell`**: without the grid's side 1 in `y` and `z`, `ctaid.x` is
`k / 1024` modulo the grid's side in `x`, and the goal stays open, as logged (the next example
is a grid where it fails). An `example`, so that no declaration with the open goal enters the
environment. -/
example (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024) (k : Nat)
    (hk : k / 1024 < volume L.grid) :
    (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 = k / 32 := by
  obtain ⟨hv, ht, -, -⟩ := Launch.tpose_env hL hx k
  rw [ht]
  simp only [Launch.env, coord, hv]

/-- **Two warps with one output cell**: on the grid of two blocks of threads in `y` (one in `x`
and `z`) with blocks of 1024 threads in `x`, threads `0` and `1024`, lane 0 of warp 0 of each
block of threads, both have the output cell `32 ctaid.x + tid.x / 32 = 0`, by `decide`. -/
example (L : Launch) (hL : L = launch2 1 2 1024 1) :
    (L.env 0).sreg .ctaid .x * 32 + (L.env 0).sreg .tid .x / 32 = 0 ∧
      (L.env 1024).sreg .ctaid .x * 32 + (L.env 1024).sreg .tid .x / 32 = 0 := by
  subst hL
  decide

/-- **The events before the barrier are `Before` events**, for every launch `L`, memory `z`,
output block `bo`, family of runs `R`, threads `ns` of the grid and memories: if every run of a
thread `n` of `ns` by `R` first extends the trace by reads by `n` of blocks of no block of
threads in `z` other than `bo` (the entry block and the loop: `entry_events`, `latch_reads`),
then puts the write of `to_barrier_events` by `n` to a block of threads' shared memory in `z` in
front, threads `ns` in turn by `R` (`Turns`) extend the trace by `Before` events. `Ext.turns`. -/
theorem gevm_before (L : Launch) (z : Mem) (bo : Nat) {R : Nat → Mem → Mem → Prop}
    {ns : List Nat} (hns : ∀ n ∈ ns, n / 1024 < volume L.grid)
    (hR : ∀ n ∈ ns, ∀ m m', R n m m' → ∃ m'', Ext (fun e => ∃ a, e = .access a ∧
        a.who = ⟨n, n / 1024⟩ ∧ a.write = false ∧ z.ctaOf a.ptr.block = none ∧
        a.ptr.block ≠ bo) m m'' ∧
      ∃ b, (z.ctaOf b).isSome ∧ m'.trace = .access ⟨⟨n, n / 1024⟩,
        ⟨b, ((4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32) : Nat) : Int)⟩, 4, true,
        none, false⟩ :: m''.trace)
    {m₀ m₁ : Mem} {Es : List (List Event)} (h : Turns R ns m₀ Es m₁) :
    Ext (fun e => ∃ k, Before L z bo k e) m₀ m₁ := by
  obtain ⟨E, hE, hP⟩ := Ext.turns h (P := Before L z bo) fun n hn m m' hr => by
    obtain ⟨m'', ⟨E, e₁, p₁⟩, b, hb, e₂⟩ := hR n hn m m' hr
    refine ⟨_ :: E, by rw [e₂, e₁, List.cons_append], fun e he => ?_⟩
    rcases List.mem_cons.1 he with rfl | he
    · exact ⟨hns n hn, .inl ⟨b, hb, rfl⟩⟩
    · exact ⟨hns n hn, .inr (p₁ e he)⟩
  refine ⟨E, hE, fun e he => ?_⟩
  obtain ⟨n, -, hn⟩ := hP e he
  exact ⟨n, hn⟩

/-- **The events after the barrier are `After` events**, for every valid launch `L` with
`ntid.x = 1024` whose grid has side 1 in `y` and `z`, memory `z`, output block `bo`, output
length `N`, families of runs `R₁` and `R₂`, threads `ns` of the grid and memories: if every run
of a thread `n` of `ns` by `R₁` puts a read by `n` of 4 bytes of a block of threads' shared
memory in `z` in front of the trace (`to_shfl_events`), the shuffle rounds then leave the trace
(`shfl_events`, `Fires.shfls`), and every run by `R₂` puts lane 0's write of 4 bytes at its
output cell `32 ctaid.x + tid.x / 32 < N` of `bo` in front, and for another lane nothing
(`thread_trace`), threads `ns` in turn by `R₁`, the rounds, and threads `ns` in turn by `R₂`
extend the trace by `After` events. `Ext.turns`, `Ext.trans` and `out_cell`. -/
theorem gevm_after (L : Launch) (hL : L.Valid) (hx : L.block .x = 1024) (hgy : L.grid .y = 1)
    (hgz : L.grid .z = 1) (z : Mem) (bo N : Nat) {R₁ R₂ : Nat → Mem → Mem → Prop}
    {ns : List Nat} (hns : ∀ n ∈ ns, n / 1024 < volume L.grid)
    (hR₁ : ∀ n ∈ ns, ∀ m m', R₁ n m m' → ∃ q, (z.ctaOf q.block).isSome ∧
      m'.trace = .access ⟨⟨n, n / 1024⟩, q, 4, false, none, false⟩ :: m.trace)
    (hR₂ : ∀ n ∈ ns, ∀ m m', R₂ n m m' →
      ((L.env n).laneid = 0 → (L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32 < N) ∧
      m'.trace = (if (L.env n).laneid = 0 then [.access ⟨⟨n, n / 1024⟩, ⟨bo,
        ((((L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩, 4,
        true, none, false⟩] else []) ++ m.trace)
    {m₁ m₂ m₃ m' : Mem} {Es₁ Es₂ : List (List Event)} (h₁ : Turns R₁ ns m₁ Es₁ m₂)
    (hs : m₃.trace = m₂.trace) (h₂ : Turns R₂ ns m₃ Es₂ m') :
    Ext (fun e => ∃ k, After L z bo N k e) m₁ m' := by
  have e₁ := Ext.turns h₁ (P := After L z bo N) fun n hn m m' hr => by
    obtain ⟨q, hq, et⟩ := hR₁ n hn m m' hr
    exact ⟨[_], et, fun e he => by
      rw [List.mem_singleton.1 he]
      exact ⟨hns n hn, .inl ⟨q, hq, rfl⟩⟩⟩
  have e₂ := Ext.turns h₂ (P := After L z bo N) fun n hn m m' hr => by
    obtain ⟨hN, et⟩ := hR₂ n hn m m' hr
    refine ⟨_, et, fun e he => ?_⟩
    obtain ⟨-, -, hl, -⟩ := Launch.tpose_env hL hx n
    have ho := out_cell L hL hx hgy hgz n (hns n hn)
    split at he
    · rename_i h0
      have hN' := hN h0
      rw [List.mem_singleton.1 he]
      refine ⟨hns n hn, .inr ⟨by omega, by omega, ?_⟩⟩
      rw [ho]
    · cases he
  obtain ⟨E, hE, hP⟩ := e₁.trans ((show Ext _ m₂ m₃ from ⟨[], hs, nofun⟩).trans e₂)
  refine ⟨E, hE, fun e he => ?_⟩
  obtain ⟨n, -, hn⟩ := hP e he
  exact ⟨n, hn⟩

end MojoProofTest.GevmTrace
