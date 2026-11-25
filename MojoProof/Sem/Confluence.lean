import MojoProof.Sem.Frame
import MojoProof.Sem.Rmw

/-!
# The diamond's cases of two threads, of a thread and a collective call, and of two collective calls

The diamond's case of two threads' steps (docs/proofs/schedule-owned.md, the two-thread case in
Lean, steps 3 to 5), its case of a thread's step and a collective call (a barrier or a shuffle),
and its case of two collective calls. Proved here, for every memory, all ops, every grid, all
contexts and every launch:

- `Mem.apply_next`, `Mem.run_next`: no op changes `next`.
- `Mem.apply_trace`, `Mem.run_trace`: ops put the events they log (`Mem.Op.event`) in front of
  the trace, the last op's first.
- `Mem.apply_blocks`: an op changes the block at each number `c` by `Mem.Op.on c`, so
  `Mem.run_congr`: the blocks after ops depend only on the blocks before.
- `Mem.apply_comm`: two ops at disjoint places (`Mem.Op.Apart`: different blocks, or disjoint
  bytes of one block if both put bytes, or independent events if both log, or one of them logs)
  give the same blocks in both orders.
- `Mem.run_comm`: two lists of ops, every op of one apart from every op of the other, give the same
  blocks, the same `next` and the same trace (`Trace.Same`) in both orders.
- `Mem.Op.At.apart` (step 4): ops of two threads with different numbers, at the places
  `Mem.Op.At` gives on one memory, are apart if their liveness changes are at blocks each owns,
  their sets at different numbers, and no write of one overlaps a write of the other.
- `Grid.advance_agree`: a thread's step from a grid gives a status and ops at those places, and
  from every grid whose memory agrees for it (`Mem.Agree`) with the first's, the same status and
  the same ops.
- `Grid.advance_agree_other`: in a closed grid whose threads own their allocas, a step of one
  thread leaves the memory agreeing for a thread with another number, if no write of the first
  overlaps an access of the second.
- `Grid.advance_comm` (step 5): in such a grid, the steps of two threads with different numbers,
  no pending access of either of which conflicts with one of the other (`Access.conflict`: they
  overlap, one writes, and they are not two `atomicrmw`s of one operation at one pointer and
  size), give the same grid (`Grid.Same`) in both orders: either no write of one overlaps an
  access of the other, or the two steps are such `atomicrmw`s (`Grid.advance_atomic_comm`).
- `Grid.start_reach_comm`: the same in every grid reachable from the start's, for every program,
  kernel, launch, arguments and choices on a caller's memory whose pointer bytes name numbers below
  `next` or with a block, and every two different threads.
- `Stmt.pending_who`, `Thread.pending_who`: every event a step would log is an access by the
  context's thread.
- `Grid.advance_set`: a step that gives a grid sets the stepping thread's status and the memory
  alone, and from every grid with that thread's status and memory gives the same status and memory.
- `Mem.addr_keeps`, `withAttrs_keeps`: what an address or a value under attributes gives in a
  memory it gives in every memory that keeps its blocks' shapes (`Mem.Keeps`), as a step's does.
- `resumeAll_getElem?`, `resumeAll_set`, `resumeAll_agree`: `resumeAll` keeps the threads it does
  not resume, gives the same in every memory that keeps its memory's, commutes with a `set!` at a
  thread it does not resume, and from threads that agree at the threads it resumes gives the same
  threads there.
- `Grid.fire_frame`: a collective call that completes resumes a list of threads that wait (at a
  barrier, `n`'s block of threads), each of which completes it to the same grid in all contexts
  that give it `n`'s layout; from every grid with the same statuses at `n` and at those threads,
  its outcome is `resumeAll` of the same threads and results on that grid's threads and memory,
  with the same events (which can fail there: a return attribute reads the memory). The threads
  include every lane of `n`'s warp inside its block of threads.
- `Grid.advance_fire_comm` (the case of a thread and a collective call): for every grid, contexts
  and launch, a collective call that thread `n` waits at and that completes, and a step of a
  thread `k` whose block of threads is not that of a barrier the call logs (`Grid.fired`), give
  the same grid in both orders.
- `resumeAll_size`, `Grid.ByThreads` (W4: every access of the trace is by a thread number below
  the number of threads, in the block of threads of that number), `Grid.Step.byThreads` (a step
  keeps W4 in contexts that give thread `n` the number `n` in block of threads
  `n / volume L.block`) and `Grid.start_reach_byThreads` (W4 in every grid reachable from the
  start's, for every program, kernel, launch, arguments, memory and choices).
- `Grid.fire_threads`: after a fire, a thread is at a number that has one before it; so
  `Grid.start_reach_block`: in every grid reachable from the start's there is a thread only if the
  blocks of threads are not empty.
- `Grid.fired_run`: for every launch with blocks of threads that are not empty, contexts and grid,
  a collective call that completes logs no barrier of the block of threads of a running thread
  `k` whose context puts it in block of threads `k / volume L.block`: a barrier with a running
  participant does not complete. So `Grid.start_reach_fired`: the same in every grid reachable
  from the start's, for every program, kernel, launch, arguments, caller's memory and choices,
  and `Grid.start_reach_fire_comm`: the case of a thread and a collective call in every grid
  reachable from the start's, with no premise on blocks of threads.
- `Grid.fire_fire_comm` (the case of two collective calls): for every launch, grid and contexts in
  which the two threads have one layout, two collective calls that complete give the same grid, or
  each completes after the other and the two orders give the same grid (`Grid.Same`);
  `Grid.start_fire_fire_comm`: the same in the start's contexts, for every grid.
- `Mem.check_bind_admits`, `Mem.load_admits`, `Mem.store_admits`, `exec_admits`, `step_admits`,
  `Grid.advance_admits`: every access a step that succeeds would log is to a block of the memory
  whose owner admits the stepping thread; `Grid.pending_who`: and is by that thread.
- `Grid.pending_apart` (the premise on accesses from ownership): for every discipline `(T, own)`
  (Trace.lean), if each pending access of two threads with different tiles whose steps succeed
  follows the discipline or is to a block its thread owns, no write of one overlaps an access of
  the other, so no two conflict (`Access.conflict_eq_false`); `Grid.start_reach_comm_of_owned`:
  so the two-thread case from the start under that premise.
- `Mem.check_log`, `Mem.check_put`, `Mem.load_inv`, `Mem.store_inv`: a log keeps a check, and a
  put into the checked block keeps it with the new block; a load that succeeds is its check and a
  decode, and a store that succeeds its check into a writable block, an encoding, a put and a log.
- `Mem.load_store`, `Mem.load_store_codec` (a step of L10's memory part): a load after a store
  that succeeds, at the same pointer, by any thread with any alignment whose check succeeds before
  the store, gives what the stored value's bytes decode to, which for a codec (integers, floats)
  is the stored value; `Layout.scalarOf_scalar`, `Mem.load_scalar`: a load of an integer type
  that succeeds gives a scalar of its width; `Layout.scalar_round`: a scalar of a positive width
  round-trips through its bytes, so a store of it and a load give it back.
- `Mem.update`, `Mem.update_eq_ok`: the update an `atomicrmw` makes (a load, its read logged,
  `rmw`, a store), and when it succeeds; `Mem.update_comm` (L10's memory part): for every two
  layouts, memory, threads, spaces, operands and alignments, every operation and every positive
  width `n`, two updates of one operation at one pointer and type `.int n` that each succeed
  succeed in both orders and give the same blocks, `next` and trace up to swaps;
  `Mem.update_before` (the same, for faults): for every two layouts and so on, an update of type
  `.int n` at a pointer by a scalar of width `n` that succeeds after another such update succeeds
  before it.
- `Stmt.checkAtomic_int`, `exec_atomic`, `step_atomic`, `Grid.advance_atomic`: a statement, step
  or grid step that succeeds and would log an atomic access `e` is, from every memory with the
  same shape, the update of type `.int (8 * e.len)` at `e`'s pointer by `e`'s operation with a
  scalar operand;
  `Grid.advance_atomic_comm` (the diamond's case of two exempt atomics): for every closed grid and
  contexts, the steps of two threads `n ≠ k` that succeed, with pending accesses by `atomicrmw`s
  of one operation at one pointer and size, succeed in both orders and give the same grid.

Every grid reachable from a closed grid is closed (`Grid.reach_closed`, Closed.lean), and from one
whose threads own their allocas such a grid (`Grid.reach_owns`, Writes.lean). The start's grid
owns its allocas (`Grid.start_owns`) and gives thread `n` the number `n` (`Grid.start_ctx`), and
it is closed if every pointer byte of the caller's memory names a number below `next` or with a
block (`Grid.start_closed`, premise `m.BytesIn m.Known`). Not proved here:
that a kernel's accesses follow a discipline (the premise of `Grid.pending_apart`, a proof about
that kernel). Two `atomicrmw`s of one operation on the same bytes follow no discipline with
different tiles, so `Grid.start_reach_comm_of_owned` leaves them out; `Grid.start_reach_comm`
covers them.
-/

namespace MojoProof.Sem

open LLVM

/-- The block op `o` changes, if any. -/
def Mem.Op.block : Mem.Op → Option Nat
  | .put b .. | .set b _ | .live b _ => some b
  | .log _ => none

/-- Ops `o₁` and `o₂` act at disjoint places: puts at different blocks or disjoint bytes (no byte
the first puts is one the second puts), logs of independent events (`Event.indep`), and otherwise
not both at one block. -/
def Mem.Op.Apart : Mem.Op → Mem.Op → Prop
  | .put b o bs, .put b' o' bs' =>
    b ≠ b' ∨ ∀ i, o ≤ i → i < o + bs.length → i < o' ∨ o' + bs'.length ≤ i
  | .log e, .log f => e.indep f = true
  | o₁, o₂ => ∀ b, o₁.block = some b → o₂.block ≠ some b

/-- What op `o` does to the block at number `c`. -/
def Mem.Op.on (c : Nat) : Mem.Op → Option Block → Option Block
  | .put b o bs, x => if c = b then x.map (·.put o bs) else x
  | .set b y, x => if c = b then some y else x
  | .live b v, x => if c = b then
      x.map fun y => { y with live := v, bytes := if v then fun _ => .undef else y.bytes }
    else x
  | .log _, x => x

/-- A change of memory keeps `next`. -/
theorem Mem.apply_next (m : Mem) : ∀ o : Mem.Op, (m.apply o).next = m.next
  | .put b _ _ => by simp only [Mem.apply]; split <;> rfl
  | .set _ _ => rfl
  | .live b _ => by simp only [Mem.apply, Mem.setLive]; split <;> rfl
  | .log _ => rfl

/-- A list of changes of memory keeps `next`. -/
theorem Mem.run_next (m : Mem) (ops : List Mem.Op) : (m.run ops).next = m.next := by
  induction ops generalizing m with
  | nil => rfl
  | cons o ops ih => exact (ih _).trans (m.apply_next o)

/-- A change of memory puts the event it logs, if any, in front of the trace. -/
theorem Mem.apply_trace (m : Mem) : ∀ o : Mem.Op, (m.apply o).trace = o.event.toList ++ m.trace
  | .put b _ _ => by simp only [Mem.apply]; split <;> rfl
  | .set _ _ => rfl
  | .live b _ => by simp only [Mem.apply, Mem.setLive]; split <;> rfl
  | .log _ => rfl

/-- A list of changes of memory puts the events it logs, last first, in front of the trace. -/
theorem Mem.run_trace (m : Mem) (ops : List Mem.Op) :
    (m.run ops).trace = (ops.filterMap Mem.Op.event).reverse ++ m.trace := by
  induction ops generalizing m with
  | nil => rfl
  | cons o ops ih =>
    simp only [Mem.run, List.foldl_cons] at ih ⊢
    rw [ih, Mem.apply_trace]
    rcases e : o.event <;> simp [e]

/-- An op changes the block at `c` by `Mem.Op.on c`. -/
theorem Mem.apply_blocks (m : Mem) (c : Nat) : ∀ o : Mem.Op,
    (m.apply o).blocks c = o.on c (m.blocks c)
  | .put b _ _ => by
    simp only [Mem.apply, Mem.Op.on]
    split <;> by_cases e : c = b <;> simp_all [Mem.set]
  | .set _ _ => rfl
  | .live b _ => by
    simp only [Mem.apply, Mem.Op.on, Mem.setLive]
    split <;> by_cases e : c = b <;> simp_all [Mem.set]
  | .log _ => rfl

/-- A list of changes of memory applied to two memories with the same blocks gives the same
blocks. -/
theorem Mem.run_congr {m m' : Mem} (h : m.blocks = m'.blocks) (ops : List Mem.Op) :
    (m.run ops).blocks = (m'.run ops).blocks := by
  induction ops generalizing m m' with
  | nil => exact h
  | cons o ops ih => exact ih (funext fun c => by simp only [Mem.apply_blocks, h])

/-- Two writes of bytes into a block commute when no byte the first writes is one the second
writes. -/
theorem Block.put_comm (x : Block) {o o' : Nat} {bs bs' : List MemByte}
    (h : ∀ i, o ≤ i → i < o + bs.length → i < o' ∨ o' + bs'.length ≤ i) :
    (x.put o bs).put o' bs' = (x.put o' bs').put o bs := by
  simp only [Block.put, Block.mk.injEq, and_true, true_and]
  funext i
  by_cases h₁ : o ≤ i ∧ i < o + bs.length
  · have := h i h₁.1 h₁.2
    have h₂ : ¬(o' ≤ i ∧ i < o' + bs'.length) := by omega
    rw [ite_eq_left h₁, ite_eq_left h₁, ite_eq_right h₂]
  · rw [ite_eq_right h₁, ite_eq_right h₁]

/-- A put over a put at the same offset, of at least as many bytes, keeps only the second's. -/
theorem Block.put_put (x : Block) (o : Nat) {bs bs' : List MemByte} (h : bs.length ≤ bs'.length) :
    (x.put o bs).put o bs' = x.put o bs' := by
  simp only [Block.put, Block.mk.injEq, and_true, true_and]
  funext i
  split_ifs <;> first | rfl | omega

/-- **Ops at disjoint places commute**: `o₁` then `o₂` gives the blocks `o₂` then `o₁` gives. -/
theorem Mem.apply_comm (m : Mem) {o₁ o₂ : Mem.Op} (h : o₁.Apart o₂) :
    ((m.apply o₁).apply o₂).blocks = ((m.apply o₂).apply o₁).blocks := by
  funext c
  simp only [Mem.apply_blocks]
  generalize m.blocks c = x
  cases o₁ <;> cases o₂ <;>
    simp only [Mem.Op.Apart, Mem.Op.block, ne_eq, Option.some.injEq, forall_eq'] at h <;>
    simp only [Mem.Op.on] <;> split_ifs <;> subst_vars <;>
    first
    | rfl
    | (simp_all; done)
    | (cases x <;> simp only [Option.map, Block.put_comm _ (h.resolve_left (· rfl))])

/-- A change of memory apart from every change of a list (`Mem.Op.Apart`) commutes with the list,
on the blocks. -/
theorem Mem.apply_run_comm (m : Mem) {o : Mem.Op} {ops : List Mem.Op}
    (h : ∀ o' ∈ ops, o.Apart o') : ((m.apply o).run ops).blocks = ((m.run ops).apply o).blocks := by
  induction ops generalizing m with
  | nil => rfl
  | cons o' ops ih =>
    exact (Mem.run_congr (m.apply_comm (h o' List.mem_cons_self)) ops).trans
      (ih (m.apply o') fun o'' ho => h o'' (List.mem_cons_of_mem _ ho))

/-- **Lists of ops at disjoint places commute**: `os₁` then `os₂` gives the blocks, the `next`
and, up to the order of independent events, the trace that `os₂` then `os₁` gives, if every op
of `os₁` is apart from every op of `os₂`. -/
theorem Mem.run_comm (m : Mem) {os₁ os₂ : List Mem.Op}
    (h : ∀ o₁ ∈ os₁, ∀ o₂ ∈ os₂, o₁.Apart o₂) :
    ((m.run os₁).run os₂).blocks = ((m.run os₂).run os₁).blocks ∧
      ((m.run os₁).run os₂).next = ((m.run os₂).run os₁).next ∧
      Trace.Same ((m.run os₁).run os₂).trace ((m.run os₂).run os₁).trace := by
  refine ⟨?_, by simp only [Mem.run_next], ?_⟩
  · induction os₁ generalizing m with
    | nil => rfl
    | cons o os₁ ih =>
      exact (ih (m.apply o) fun o₁ h₁ => h o₁ (List.mem_cons_of_mem _ h₁)).trans
        (Mem.run_congr (m.apply_run_comm (h o List.mem_cons_self)) os₁)
  · simp only [Mem.run_trace, ← List.append_assoc]
    refine (Trace.Same.swap (fun e he f hf => ?_) _).symm
    simp only [List.mem_reverse, List.mem_filterMap] at he hf
    obtain ⟨o₁, h₁, e₁⟩ := he
    obtain ⟨o₂, h₂, e₂⟩ := hf
    have a := h o₁ h₁ o₂ h₂
    cases o₁ <;> cases o₂ <;> cases e₁ <;> cases e₂
    exact a

/-- Two accesses that cover byte `i` of block `b` overlap. -/
theorem Access.overlaps_of_byte {a e : Access} {b : Nat} {i : Int}
    (ha : a.ptr.block = b ∧ a.ptr.off ≤ i ∧ i < a.ptr.off + a.len)
    (he : e.ptr.block = b ∧ e.ptr.off ≤ i ∧ i < e.ptr.off + e.len) : a.overlaps e = true := by
  simp only [Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
  omega

/-- `Access.overlaps` is symmetric. -/
theorem Access.overlaps_comm (a e : Access) : a.overlaps e = e.overlaps a := by
  have h : ∀ a e : Access, a.overlaps e = true → e.overlaps a = true := fun a e h => by
    simp only [Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h ⊢
    omega
  exact Bool.eq_iff_iff.2 ⟨h a e, h e a⟩

/-- Two `alloca` block numbers of one memory are equal only for the same thread number `n`. -/
theorem Mem.fresh_inj {m : Mem} {n n' k k' : Nat} (h : m.fresh n k = m.fresh n' k') : n = n' := by
  simp only [Mem.fresh, Nat.add_left_cancel_iff, Nat.pair_eq_pair] at h
  exact h.1

/-- **Two threads' ops are apart** (step 4 of the two-thread case): ops of steps of threads `w`
and `w'` with different numbers, at the places `Mem.Op.At` gives on one memory `m`, are apart if
their liveness changes are at blocks of `m` each thread owns (`Mem.Owned`), their sets at
different numbers, and no write one logs overlaps a write the other logs. A put of one and a set
of the other are at different blocks, since the put's block exists in `m` and the set's does not;
a put or liveness change of one and a liveness change of the other, since the latter's block is
owned by the other thread, whose owner admits no other; two puts at one block, at disjoint bytes,
since a common byte would be written by a write of each, and those overlap; two logs log
accesses, which are independent. -/
theorem Mem.Op.At.apart {m : Mem} {w w' : Who} {L L' N N' : Nat → Prop} {W W' : List Event}
    (hw : w.thread ≠ w'.thread) (hL : ∀ b, L b → m.Owned w.thread b)
    (hL' : ∀ b, L' b → m.Owned w'.thread b) (hN : ∀ b, N b → ¬N' b)
    (hW : ∀ a a', .access a ∈ W → .access a' ∈ W' → a.overlaps a' = true →
      a.write = false ∨ a'.write = false) :
    ∀ {o o' : Mem.Op}, o.At m w L N W → o'.At m w' L' N' W' → o.Apart o'
  | .put b i bs, .put b' i' bs', ⟨_, hb⟩, ⟨_, hb'⟩ => by
    by_cases e : b = b'
    · subst e
      refine Or.inr fun j h₁ h₂ =>
        (Nat.lt_or_ge j i').imp_right fun h₃ => Nat.le_of_not_lt fun h₄ => ?_
      obtain ⟨a, ha, wa⟩ := hb j h₁ h₂
      obtain ⟨a', ha', wa'⟩ := hb' j h₃ h₄
      have := hW a a' ha ha' (Access.overlaps_of_byte wa.2 wa'.2)
      simp [wa.1, wa'.1] at this
    · exact Or.inl e
  | .put b .., .set b' _, ⟨⟨x, hx, _⟩, _⟩, ⟨_, hn⟩ => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    exact nomatch hx.symm.trans hn
  | .put b .., .live b' _, ⟨⟨x, hx, ha⟩, _⟩, hl => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    obtain ⟨y, hy, ho⟩ := hL' _ hl
    obtain rfl := Option.some.inj (hx.symm.trans hy)
    rw [ho] at ha
    exact hw (by simpa [Owner.admits] using ha)
  | .set b _, .put b' .., ⟨_, hn⟩, ⟨⟨x, hx, _⟩, _⟩ => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    exact nomatch hx.symm.trans hn
  | .set b _, .set b' _, ⟨hb, _⟩, ⟨hb', _⟩ => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    exact hN _ hb hb'
  | .set b _, .live b' _, ⟨_, hn⟩, hl => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    obtain ⟨y, hy, -⟩ := hL' _ hl
    exact nomatch hy.symm.trans hn
  | .live b _, .put b' .., hl, ⟨⟨x, hx, ha⟩, _⟩ => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    obtain ⟨y, hy, ho⟩ := hL _ hl
    obtain rfl := Option.some.inj (hx.symm.trans hy)
    rw [ho] at ha
    exact hw (Eq.symm (by simpa [Owner.admits] using ha))
  | .live b _, .set b' _, hl, ⟨_, hn⟩ => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    obtain ⟨y, hy, -⟩ := hL _ hl
    exact nomatch hy.symm.trans hn
  | .live b _, .live b' _, hl, hl' => fun _ h h' => by
    obtain rfl := Option.some.inj h
    obtain rfl := Option.some.inj h'
    obtain ⟨x, hx, ho⟩ := hL _ hl
    obtain ⟨y, hy, ho'⟩ := hL' _ hl'
    obtain rfl := Option.some.inj (hx.symm.trans hy)
    exact hw (Owner.thread.inj (ho.symm.trans ho'))
  | .log _, .log _, ⟨_, e⟩, ⟨_, e'⟩ => by subst e e'; rfl
  | .log _, .put .., _, _ | .log _, .set .., _, _ | .log _, .live .., _, _ => fun _ h => nomatch h
  | .put .., .log _, _, _ | .set .., .log _, _, _ | .live .., .log _, _, _ =>
    fun _ _ h => nomatch h

/-- Every number the scope of the innermost frame of a running thread of a closed grid names is
known to the grid's memory. -/
theorem Grid.Closed.scope {S : Nat → Prop} {c : Nat → Ctx} {g : Grid} (hg : g.Closed c) {n : Nat}
    {t : Thread} (ht : g.threads[n]? = some (.run t)) (hS : ∀ b, g.mem.Known b → S b) :
    ∀ f, t.frames.head? = some f → ((c n).scope g.mem f t.k).NamesIn S := fun f hf =>
  ⟨hS _ hg.null, ((hg.threads n _ ht : t.NamesIn _) f (List.mem_of_mem_head? hf)).mono hS,
    fun x p hp => hS _ (hg.globals n x p hp)⟩

/-- **L2 for the grid's steps.** For every grid `g`, contexts `c`, thread number `n` running `t`
and memory `m₂`: under `step_agree`'s hypotheses for `g.mem` and `m₂`, if `n`'s step from `g`
gives `g'`, there are a status `s` and changes `ops`, at the places `step_agree` gives, such that
`g'` is `g` with `s` at `n` and memory `g.mem.run ops`, and `n`'s step from every grid with `t`
at `n` and memory `m₂` gives that grid with `s` at `n` and memory `m₂.run ops`. -/
theorem Grid.advance_agree {S : Nat → Prop} {c : Nat → Ctx} {g g' : Grid} {n : Nat} {t : Thread}
    {m₂ : Mem} (ht : g.threads[n]? = some (.run t))
    (hs : ∀ f, t.frames.head? = some f → ((c n).scope g.mem f t.k).NamesIn S)
    (hk : S (g.mem.fresh (c n).who.thread t.k))
    (h : g.mem.Agree (c n).who S (t.pending (c n) g.mem) m₂)
    (he : g.advance c n = .ok (some g')) :
    ∃ s ops, (∀ o ∈ ops, o.At g.mem (c n).who (fun b => g.mem.Owned (c n).who.thread b ∨
        ∃ f ∈ t.frames, b ∈ f.allocas) (· = g.mem.fresh (c n).who.thread t.k)
        (ops.filterMap Mem.Op.event)) ∧
      g' = { threads := g.threads.set! n s, mem := g.mem.run ops } ∧
      ∀ g₂ : Grid, g₂.threads[n]? = some (.run t) → g₂.mem = m₂ →
        g₂.advance c n = .ok (some { threads := g₂.threads.set! n s, mem := m₂.run ops }) := by
  unfold Grid.advance at he
  rw [ht] at he
  simp only [bind, Except.bind] at he
  split at he
  · cases he
  · rename_i r hr
    obtain ⟨ops, ha, e, h₂⟩ := step_agree hs hk h hr
    cases r with
    | next t' m =>
      cases he
      simp only [Step.withMem, Step.next.injEq, true_and] at e
      subst e
      refine ⟨_, ops, ha, rfl, fun g₂ ht₂ hm => ?_⟩
      subst hm
      unfold Grid.advance
      rw [ht₂]
      simp only [bind, Except.bind]
      rw [h₂]
      rfl
    | wait i args r =>
      cases he
      refine ⟨_, [], List.forall_mem_nil _, rfl, fun g₂ ht₂ hm => ?_⟩
      subst hm
      unfold Grid.advance
      rw [ht₂]
      simp only [bind, Except.bind]
      rw [h₂]
      rfl
    | done m =>
      cases he
      simp only [Step.withMem, Step.done.injEq] at e
      subst e
      refine ⟨_, ops, ha, rfl, fun g₂ ht₂ hm => ?_⟩
      subst hm
      unfold Grid.advance
      rw [ht₂]
      simp only [bind, Except.bind]
      rw [h₂]
      rfl

/-- **The disjointness argument for two threads' steps.** For threads `n` and `k` of a closed grid
`g` (`Grid.Closed`) whose threads own their frames' allocas (`Grid.Owns`), with different thread
numbers in their contexts, `n` running `t` and `k` running `t'`: if no write among `n`'s pending
accesses overlaps an access among `k`'s, then `n`'s step from `g` to `g'` leaves `g.mem` and
`g'.mem` agreeing for `k` (`Mem.Agree`) at the numbers `g.mem` knows and `k`'s fresh number, and
`k`'s pending accesses. By `Mem.Changes.agree`: `n`'s step adds a block only at its fresh number,
which `g.mem` does not know and which is not `k`'s (`Mem.fresh_inj`); it changes liveness, and
bytes other than those its writes write, only in blocks that `n` owns, whose owner admits `n`
alone; and its writes write no byte that a read of `k` reads. -/
theorem Grid.advance_agree_other {c : Nat → Ctx} {g g' : Grid} {n k : Nat} {t t' : Thread}
    (ho : g.Owns c) (hw : (c n).who.thread ≠ (c k).who.thread)
    (ht : g.threads[n]? = some (.run t))
    (hW : ∀ a a', .access a ∈ t.pending (c n) g.mem → .access a' ∈ t'.pending (c k) g.mem →
      a.overlaps a' = true → a.write = false)
    (h : g.advance c n = .ok (some g')) :
    g.mem.Agree (c k).who (fun b => g.mem.Known b ∨ b = g.mem.fresh (c k).who.thread t'.k)
      (t'.pending (c k) g.mem) g'.mem := by
  have hc := Grid.advance_changes (L := g.mem.Owned (c n).who.thread)
    (N := (· = g.mem.fresh (c n).who.thread t.k)) ht (fun b x hx ho => ⟨x, hx, ho⟩)
    (ho n _ ht) rfl h
  refine Mem.Changes.agree
    (N := fun b => b = g.mem.fresh (c n).who.thread t.k ∧ g.mem.blocks b = none)
    { hc with new := fun b hb hs => ⟨hc.new b hb hs, hb⟩ } ?_ ?_ ?_
  · rintro b hb ⟨rfl, hn⟩
    rcases hb with (hb | hb) | hb
    · simp only [Mem.fresh] at hb
      omega
    · simp [hn] at hb
    · exact hw (Mem.fresh_inj hb)
  · rintro b x - ⟨y, hy, hy'⟩ hx
    obtain rfl := Option.some.inj (hx.symm.trans hy)
    rw [hy']
    simpa [Owner.admits] using hw.symm
  · intro d hd b x i a _ _ _ ⟨a', ha', hr, hb, h₁, h₂⟩ had hwr
    obtain ⟨t₀, ht₀, e⟩ := Grid.advance_pending h
    obtain rfl : t = t₀ := by simpa [ht] using ht₀
    rw [e] at hd
    obtain rfl := List.append_cancel_right hd
    have := hW a a' had ha' (Access.overlaps_of_byte hwr.2 ⟨hb, h₁, h₂⟩)
    simp [hwr.1] at this



/-! ## The case of a thread and a collective call -/

/-- Every event statement `st` would log is an access by the context's thread. -/
theorem Stmt.pending_who {c : Ctx} {s : Scope} {st : Stmt} :
    ∀ e ∈ st.pending c s, ∃ a, e = .access a ∧ a.who = c.who := by
  intro e he
  unfold LLVM.Stmt.pending at he
  dsimp only at he
  repeat' (first | split at he | rw [List.mem_append] at he)
  all_goals simp only [List.mem_singleton, List.not_mem_nil, or_self] at he
  all_goals first
    | exact ⟨_, he, rfl⟩
    | (rcases he with he | he <;> exact ⟨_, he, rfl⟩)

/-- Every event thread `t`'s step would log is an access by the context's thread. -/
theorem Thread.pending_who {c : Ctx} {t : Thread} {m : Mem} :
    ∀ e ∈ t.pending c m, ∃ a, e = .access a ∧ a.who = c.who := by
  unfold Thread.pending
  repeat' split
  all_goals first | exact Stmt.pending_who | exact fun _ h => nomatch h

/-- A step of thread `n` that gives a grid: `n` runs `t`, and the grid after is `g` with a status
`s` at `n` and a memory `m` whose trace has `n`'s pending accesses in front; from every grid with
`n`'s status and memory, the step gives that grid with `s` at `n` and memory `m`. -/
theorem Grid.advance_set {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) :
    ∃ t s m, g.threads[n]? = some (.run t) ∧ g' = { threads := g.threads.set! n s, mem := m } ∧
      m.trace = g.pending c n ++ g.mem.trace ∧
      ∀ g₂ : Grid, g₂.threads[n]? = g.threads[n]? → g₂.mem = g.mem →
        g₂.advance c n = .ok (some { threads := g₂.threads.set! n s, mem := m }) := by
  obtain ⟨t, ht, htr⟩ := Grid.advance_pending h
  have hp : g.pending c n = t.pending (c n) g.mem := by simp only [Grid.pending, ht]
  unfold Grid.advance at h
  rw [ht] at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i r hr
    cases r with
    | next t' m =>
      cases h
      refine ⟨t, _, _, ht, rfl, hp ▸ htr, fun g₂ h₂ hm => ?_⟩
      unfold Grid.advance
      rw [h₂, ht, hm]
      simp only [bind, Except.bind, hr]
      rfl
    | wait i args r =>
      cases h
      refine ⟨t, _, _, ht, rfl, hp ▸ htr, fun g₂ h₂ hm => ?_⟩
      unfold Grid.advance
      rw [h₂, ht, hm]
      simp only [bind, Except.bind, hr]
      rfl
    | done m =>
      cases h
      refine ⟨t, _, _, ht, rfl, hp ▸ htr, fun g₂ h₂ hm => ?_⟩
      unfold Grid.advance
      rw [h₂, ht, hm]
      simp only [bind, Except.bind, hr]
      rfl

/-- `mapM` that succeeds succeeds at every member of the list, with a value in the result. -/
theorem mapM_ok_mem {α β ε : Type} {f : α → Except ε β} {x : α} :
    ∀ {xs : List α} {ys : List β}, xs.mapM f = .ok ys → x ∈ xs → ∃ y, f x = .ok y ∧ y ∈ ys
  | [], _, _, hx => by cases hx
  | a :: xs, ys, h, hx => by
    rw [List.mapM_cons] at h
    cases ha : f a with
    | error e => rw [ha] at h; cases h
    | ok b =>
      cases hxs : xs.mapM f with
      | error e => simp [ha, hxs, bind, Except.bind] at h
      | ok bs =>
        simp only [ha, hxs, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at h
        subst h
        rcases List.mem_cons.1 hx with rfl | hx
        · exact ⟨b, ha, List.mem_cons_self⟩
        · obtain ⟨y, hy, hm⟩ := mapM_ok_mem hxs hx
          exact ⟨y, hy, List.mem_cons_of_mem _ hm⟩

/-- `resumeAll` keeps the threads it does not resume. -/
theorem resumeAll_getElem? {l : Layout} {m : Mem} {ts ts' : Array Status} {ns : List Nat}
    {v : Nat → Option Val} {j : Nat} (h : resumeAll l m ts ns v = .ok ts') (hj : j ∉ ns) :
    ts'[j]? = ts[j]? := by
  unfold resumeAll at h
  refine foldlM_mem_inv (P := fun ts'' : Array Status => ts''[j]? = ts[j]?) (Q := (· ≠ j))
    (fun b i b' hi hb e => ?_) ns ts (fun i hi e => hj (e ▸ hi)) h rfl
  split at hb
  · simp only [bind, Except.bind, pure, Except.pure] at hb
    split at hb
    · cases hb
    · cases hb
      rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hi, e]
  · cases hb
    exact e

/-- `foldlM` of a function that gives what `f` gives wherever `f` succeeds: where the fold of `f`
succeeds, it gives the same. -/
theorem foldlM_of_ok {α β ε : Type} {f g : β → α → Except ε β}
    (h : ∀ b a b', f b a = .ok b' → g b a = .ok b') :
    ∀ (xs : List α) (b : β) {r : β}, xs.foldlM f b = .ok r → xs.foldlM g b = .ok r
  | [], _, _, hr => hr
  | a :: xs, b, r, hr => by
    rw [List.foldlM_cons] at hr ⊢
    cases hf : f b a with
    | error e => rw [hf] at hr; cases hr
    | ok b' =>
      rw [hf] at hr
      rw [h b a b' hf]
      exact foldlM_of_ok h xs b' hr

/-- `mapM` of a function that gives what `f` gives wherever `f` succeeds: where the `mapM` of `f`
succeeds, it gives the same. -/
theorem mapM_of_ok {α β ε : Type} {f g : α → Except ε β} (h : ∀ x y, f x = .ok y → g x = .ok y) :
    ∀ {xs : List α} {ys : List β}, xs.mapM f = .ok ys → xs.mapM g = .ok ys
  | [], _, hr => hr
  | x :: xs, ys, hr => by
    rw [List.mapM_cons] at hr ⊢
    cases hf : f x with
    | error e => rw [hf] at hr; cases hr
    | ok y =>
      cases hxs : xs.mapM f with
      | error e => simp [hf, hxs, bind, Except.bind] at hr
      | ok zs =>
        rw [h x y hf, mapM_of_ok h hxs]
        rw [hf, hxs] at hr
        exact hr

/-- A bind whose first part gives, wherever `x` succeeds, what `x` gives: where the bind on `x`
succeeds, the bind on `y` gives the same. -/
theorem Except.bind_of_ok {ε α β : Type} {x y : Except ε α} {f : α → Except ε β} {s : β}
    (h : ∀ r, x = .ok r → y = .ok r) (hx : x >>= f = .ok s) : y >>= f = .ok s := by
  cases hx' : x with
  | error e => rw [hx'] at hx; cases hx
  | ok r => rw [hx'] at hx; rw [h r hx']; exact hx

/-- An address in a memory that `m'` keeps (`Mem.Keeps`): what `Mem.addr` gives in `m` it gives in
`m'`, since it reads only the shape of the block. -/
theorem Mem.addr_keeps {m m' : Mem} (h : m.Keeps m') {l : Layout} {a : Nat} {p : Ptr} {x : Nat}
    (hx : m.addr l a p = .ok x) : m'.addr l a p = .ok x := by
  by_cases h0 : p.block = 0
  · simpa only [Mem.addr, h0, ↓reduceIte] using hx
  · cases hb : m.blocks p.block with
    | none => simp [Mem.addr, Mem.block, h0, hb] at hx
    | some y =>
      rw [← Mem.addr_shape (S := (· = p.block)) (fun b e => by subst e; rw [hb, h.blocks _ _ hb]; rfl) rfl]
      exact hx

/-- A value under attributes in a memory that `m'` keeps: what `withAttrs` gives in `m` it gives
in `m'`, since it reads the memory only by `Mem.addr`. -/
theorem withAttrs_keeps {l : Layout} {m m' : Mem} (h : m.Keeps m') {t : Ty} {attrs : List Attr}
    {v r : Val} (hv : withAttrs l m t attrs v = .ok r) : withAttrs l m' t attrs v = .ok r := by
  simp only [withAttrs] at hv ⊢
  revert hv
  split
  all_goals refine Except.bind_of_ok (fun w hw => ?_)
  · simp only [Functor.map, Except.map] at hw ⊢
    split at hw
    · cases hw
    · rename_i ys hys
      cases hw
      rw [mapM_of_ok (fun x y => foldlM_of_ok (fun b a b' => ?_) _ _) hys]
      split
      all_goals first | exact id | exact Except.bind_of_ok fun _ => Mem.addr_keeps h
  · revert hw
    refine foldlM_of_ok (fun b a b' => ?_) _ _
    split
    all_goals first | exact id | exact Except.bind_of_ok fun _ => Mem.addr_keeps h

/-- `withAttrs_keeps` under `Option.mapM`. -/
theorem Option.mapM_withAttrs_keeps {l : Layout} {m m' : Mem} (h : m.Keeps m') {t : Ty}
    {attrs : List Attr} {o : Option Val} {r : Option Val}
    (ho : o.mapM (withAttrs l m t attrs) = .ok r) : o.mapM (withAttrs l m' t attrs) = .ok r := by
  cases o with
  | none => exact ho
  | some x =>
    simp only [Option.mapM_some, Functor.map, Except.map] at ho ⊢
    split at ho
    · cases ho
    · rename_i y hy
      rw [withAttrs_keeps h hy]
      exact ho

/-- `resumeAll` in a memory that `m'` keeps gives the same in `m'`, and commutes with a `set!` at
a number it does not resume. -/
theorem resumeAll_set {l : Layout} {m m' : Mem} (hm : m.Keeps m') {k : Nat} {s : Status}
    {v : Nat → Option Val} :
    ∀ {ns : List Nat} {ts ts' : Array Status}, k ∉ ns →
      resumeAll l m ts ns v = .ok ts' → resumeAll l m' (ts.set! k s) ns v = .ok (ts'.set! k s)
  | [], ts, ts', _, h => by cases h; rfl
  | j :: ns, ts, ts', hk, h => by
    have hjk : k ≠ j := fun e => hk (e ▸ List.mem_cons_self)
    have hk' : k ∉ ns := fun e => hk (List.mem_cons_of_mem _ e)
    unfold resumeAll at h ⊢
    simp only [List.foldlM_cons] at h ⊢
    rw [Array.set!_eq_setIfInBounds (xs := ts), Array.getElem?_setIfInBounds_ne hjk]
    split at h
    · simp only [bind, Except.bind, pure, Except.pure] at h ⊢
      split at h
      · cases h
      · rename_i r hr
        split at hr
        · cases hr
        rename_i y hy
        cases hr
        rw [Option.mapM_withAttrs_keeps hm hy]
        simp only [Array.set!_eq_setIfInBounds] at h ⊢
        rw [Array.setIfInBounds_comm _ _ hjk]
        exact resumeAll_set hm hk' h
    · simp only [pure, Except.pure, bind, Except.bind] at h ⊢
      exact resumeAll_set hm hk' h

/-- Arrays that agree at `i` and at `j` agree at `j` after a `set!` at `i`. -/
theorem Array.set!_getElem?_congr {α : Type} {xs ys : Array α} {i j : Nat} {a : α}
    (hi : ys[i]? = xs[i]?) (hj : ys[j]? = xs[j]?) : (ys.set! i a)[j]? = (xs.set! i a)[j]? := by
  simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
  split
  · cases hx : xs[i]? with
    | none =>
      rw [hx] at hi
      simp only [Array.getElem?_eq_none_iff] at hx hi
      simp only [Nat.not_lt.2 hx, Nat.not_lt.2 hi, ↓reduceIte]
    | some y =>
      rw [hx] at hi
      simp only [(Array.getElem?_eq_some_iff.1 hx).1, (Array.getElem?_eq_some_iff.1 hi).1,
        ↓reduceIte]
  · exact hj

/-- `resumeAll` from threads that agree at the numbers it resumes, in a memory that keeps the first
memory's, succeeds where it succeeds from the first and gives the same threads at those numbers. -/
theorem resumeAll_agree {l : Layout} {m m' : Mem} (hm : m.Keeps m') {v : Nat → Option Val} :
    ∀ {ns : List Nat} {ts ts₂ ts' : Array Status}, (∀ p ∈ ns, ts₂[p]? = ts[p]?) →
      resumeAll l m ts ns v = .ok ts' →
      ∃ ts₂', resumeAll l m' ts₂ ns v = .ok ts₂' ∧ ∀ p ∈ ns, ts₂'[p]? = ts'[p]?
  | [], _, _, _, _, h => ⟨_, rfl, fun _ h => by cases h⟩
  | j :: ns, ts, ts₂, ts', ha, h => by
    have hj := ha j List.mem_cons_self
    have fin : ∀ {u u₂ : Array Status}, u₂[j]? = u[j]? → (∀ p ∈ ns, u₂[p]? = u[p]?) →
        resumeAll l m u ns v = .ok ts' →
        ∃ ts₂', resumeAll l m' u₂ ns v = .ok ts₂' ∧ ∀ p ∈ j :: ns, ts₂'[p]? = ts'[p]? := by
      intro u u₂ hj' ha' hu
      obtain ⟨ts₂', h₂, he⟩ := resumeAll_agree hm ha' hu
      refine ⟨ts₂', h₂, fun p hp => ?_⟩
      by_cases hpn : p ∈ ns
      · exact he p hpn
      · obtain rfl : p = j := by simpa [hpn] using hp
        rw [resumeAll_getElem? h₂ hpn, resumeAll_getElem? hu hpn, hj']
    have ha' : ∀ p ∈ ns, ts₂[p]? = ts[p]? := fun p hp => ha p (List.mem_cons_of_mem _ hp)
    unfold resumeAll at h ⊢
    simp only [List.foldlM_cons, hj] at h ⊢
    split at h
    · simp only [bind, Except.bind, pure, Except.pure] at h ⊢
      split at h
      · cases h
      · rename_i r hr
        split at hr
        · cases hr
        rename_i y hy
        cases hr
        rw [Option.mapM_withAttrs_keeps hm hy]
        exact fin (Array.set!_getElem?_congr hj hj)
          (fun p hp => Array.set!_getElem?_congr hj (ha' p hp)) h
    · simp only [pure, Except.pure, bind, Except.bind] at h ⊢
      exact fin hj ha' h

/-- Every member of a list of options whose `mapM id` is `some` is `some` of a value in the
result. -/
theorem mapM_id_mem {α : Type} {x : Option α} : ∀ {xs : List (Option α)} {ys : List α}, x ∈ xs →
    xs.mapM id = some ys → ∃ y, x = some y ∧ y ∈ ys
  | [], _, h, _ => by cases h
  | z :: xs, ys, h, h' => by
    simp only [List.mapM_cons, bind, Option.bind, id] at h'
    cases z with
    | none => cases h'
    | some y =>
      cases hxs : xs.mapM id with
      | none => simp [hxs] at h'
      | some zs =>
        simp only [hxs, pure, Option.some.injEq] at h'
        subst h'
        rcases List.mem_cons.1 h with rfl | hx
        · exact ⟨y, rfl, List.mem_cons_self⟩
        · obtain ⟨w, hw, hm⟩ := mapM_id_mem hx hxs
          exact ⟨w, hw, List.mem_cons_of_mem _ hm⟩

/-- The events a fire logs (`Grid.fired`) are `.barrier`s of `n`'s block of threads. -/
theorem Grid.mem_fired {L : Launch} {g : Grid} {n : Nat} {e : Event} (h : e ∈ g.fired L n) :
    e = .barrier (n / volume L.block) := by
  unfold Grid.fired at h
  split at h
  · exact List.mem_singleton.1 h
  · cases h

/-- **The frame of a collective call.** A collective call that completes for thread `n` resumes
the threads of a list `P` with results `v` (`resumeAll`, in `n`'s context's layout), each of which
waits, and logs the events `Grid.fired`; at a barrier `P` is `n`'s block of threads. Every thread
of `P` completes the same call to the same grid, in all contexts that give it `n`'s layout. From
every grid with `n`'s status and the statuses of `P`, the call's outcome is `resumeAll` of `P`
and `v` on that grid's threads and memory, with the same events logged: it need not succeed
there, since a result's return attributes read the memory (`withAttrs`). Every lane of `n`'s warp
inside its block of threads is in `P`. -/
theorem Grid.fire_frame {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) :
    ∃ (P : List Nat) (v : Nat → Option Val),
      (∀ p ∈ P, ∃ t i args fn, g.threads[p]? = some (.wait t i args fn)) ∧
      (g.fired L n ≠ [] →
        P = (List.range (volume L.block)).map (n / volume L.block * volume L.block + ·)) ∧
      resumeAll (c n).prog.layout g.mem g.threads P v = .ok g'.threads ∧
      g'.mem = { g.mem with trace := g.fired L n ++ g.mem.trace } ∧
      (∀ p ∈ P, ∀ c' : Nat → Ctx, (c' p).prog.layout = (c n).prog.layout →
        g.fire L c' p = .ok (some g')) ∧
      (∀ g₂ : Grid, g₂.threads[n]? = g.threads[n]? → (∀ p ∈ P, g₂.threads[p]? = g.threads[p]?) →
        g₂.fire L c n = resumeAll (c n).prog.layout g₂.mem g₂.threads P v >>= fun ts =>
          pure (some { threads := ts,
                       mem := { g₂.mem with trace := g.fired L n ++ g₂.mem.trace } })) ∧
      ∀ q ∈ (List.range 32).filter (fun q => decide
        (n % volume L.block - n % volume L.block % 32 + q < volume L.block)),
        n - n % volume L.block % 32 + q ∈ P := by
  obtain ⟨t, i, args, fn, hn, -⟩ := Grid.fire_trace h
  unfold Grid.fire at h
  simp only [hn] at h
  split at h
  · rename_i x
    cases hx : x.word? with
    | none => simp only [hx] at h; cases h
    | some bar =>
      simp only [hx] at h
      by_cases h16 : bar < 16
      · simp only [h16, ↓reduceIte, bind, Except.bind, pure, Except.pure] at h
        split at h
        · cases h
        · rename_i states hst
          split at h
          · rename_i hall
            split at h
            · cases h
            · rename_i ts hts
              cases h
              have hmem : ∀ p ∈ (List.range (volume L.block)).map
                  (n / volume L.block * volume L.block + ·), ∃ t' x' fn',
                  g.threads[p]? = some (.wait t' .barrier [x'] fn') ∧ x'.word? = some bar ∧
                    t'.at = t.at := by
                intro p hp
                obtain ⟨y, hy, hys⟩ := mapM_ok_mem hst hp
                obtain rfl : y = true := List.all_eq_true.1 hall y hys
                revert hy
                split
                · rename_i t' x' fn' hp'
                  split
                  · rename_i hc
                    intro
                    exact ⟨t', x', fn', hp', hc.1, hc.2⟩
                  · intro h
                    cases h
                · intro h
                  cases h
                · intro h
                  cases h
              refine ⟨_, _, fun p hp => ?_, fun _ => rfl, hts, ?_, fun p hp c' hc => ?_,
                fun g₂ hn₂ hP => ?_, fun q hq => ?_⟩
              · obtain ⟨t', x', fn', hp', -⟩ := hmem p hp
                exact ⟨t', _, _, fn', hp'⟩
              · simp only [Grid.fired, hn, Mem.log]
                rfl
              · obtain ⟨t', x', fn', hp', hx', ht'⟩ := hmem p hp
                have hdiv : p / volume L.block = n / volume L.block := by
                  obtain ⟨k, hk, rfl⟩ := List.mem_map.1 hp
                  rw [List.mem_range] at hk
                  rw [Nat.add_comm, Nat.add_mul_div_right _ _ (by omega), Nat.div_eq_of_lt hk,
                    Nat.zero_add]
                unfold Grid.fire
                simp only [hp', hx', h16, ↓reduceIte, hdiv, hc, ht', bind, Except.bind, pure,
                  Except.pure, hst, hall, hts]
              · unfold Grid.fire
                simp only [hn₂, hn, hx, h16, ↓reduceIte, bind, Except.bind, pure, Except.pure]
                rw [show List.mapM _ _ = Except.ok states from ?_]
                · simp only [hall, ↓reduceIte, Grid.fired, hn, Mem.log]
                  rfl
                · rw [← hst]
                  exact mapM_congr fun k hk => by simp only [hP k hk]
              · simp only [List.mem_filter, List.mem_range, decide_eq_true_eq] at hq
                have e0 : n % volume L.block % 32 ≤ n % volume L.block := Nat.mod_le _ _
                have e1 := Nat.div_add_mod' n (volume L.block)
                exact List.mem_map.2 ⟨n % volume L.block - n % volume L.block % 32 + q,
                  List.mem_range.2 hq.2, by omega⟩
          · cases h
      · simp only [h16, ↓reduceIte] at h
        cases h
  · rename_i mode msk a b c'
    have hfd : g.fired L n = [] := by simp only [Grid.fired, hn]
    cases hmk : msk.word? with
    | none => simp only [hmk] at h; cases h
    | some mask =>
      simp only [hmk] at h
      by_cases h32 : mask = 2 ^ 32 - 1
      · simp only [h32, ↓reduceIte, bind, Except.bind, pure, Except.pure] at h
        split at h
        · cases h
        · rename_i parts hparts
          split at h
          · rename_i ps hps
            split at h
            · cases h
            · rename_i ts hts
              cases h
              have hlane : ∀ j ∈ (List.range 32).filter (fun j => decide
                  (n % volume L.block - n % volume L.block % 32 + j < volume L.block)),
                  ∃ t' msk' a' b' c'' fn',
                    g.threads[n - n % volume L.block % 32 + j]? =
                      some (.wait t' (.shfl mode) [msk', a', b', c''] fn') ∧
                    msk'.word? = some (2 ^ 32 - 1) ∧ t'.at = t.at ∧ ∃ y ∈ ps, y.1 = j := by
                intro j hj
                obtain ⟨o, ho, hop⟩ := mapM_ok_mem hparts hj
                obtain ⟨y, rfl, hy⟩ := mapM_id_mem hop hps
                revert ho
                split
                · rename_i t' mode' msk' a' b' c'' fn' hp'
                  split
                  · rename_i hc
                    obtain ⟨rfl, hm', ht'⟩ := hc
                    split
                    · intro ho
                      cases ho
                      exact ⟨t', msk', a', b', c'', fn', hp', hm', ht', _, hy, rfl⟩
                    · intro ho
                      cases ho
                  · intro ho
                    cases ho
                all_goals intro ho; cases ho
              have hPl : ∀ y ∈ ps, y.1 ∈ (List.range 32).filter (fun j => decide
                  (n % volume L.block - n % volume L.block % 32 + j < volume L.block)) := by
                refine mapM_mem_option (P := fun p => p.1 ∈ (List.range 32).filter (fun j =>
                    decide (n % volume L.block - n % volume L.block % 32 + j < volume L.block))) hps
                  (fun o ho y hy => mapM_mem (P := fun o => ∀ y, o = some y → y.1 ∈
                    (List.range 32).filter (fun j => decide
                      (n % volume L.block - n % volume L.block % 32 + j < volume L.block)))
                    hparts (fun j hj o' ho' y' hy' => ?_) o ho y hy)
                subst hy'
                repeat' split at ho'
                all_goals cases ho'
                exact hj
              refine ⟨_, _, fun p hp => ?_, fun hne => absurd hfd hne, hts, by rw [hfd]; rfl,
                fun p hp c' hc => ?_, fun g₂ hn₂ hP => ?_, fun q hq => ?_⟩
              · obtain ⟨y, hy, rfl⟩ := List.mem_map.1 hp
                obtain ⟨t', msk', a', b', c'', fn', hp', -⟩ := hlane _ (hPl y hy)
                exact ⟨_, _, _, _, hp'⟩
              · obtain ⟨y, hy, rfl⟩ := List.mem_map.1 hp
                have hj := hPl y hy
                obtain ⟨t', msk', a', b', c'', fn', hp', hm', ht', -⟩ := hlane _ hj
                simp only [List.mem_filter, List.mem_range, decide_eq_true_eq] at hj
                have e0 : n % volume L.block % 32 ≤ n % volume L.block := Nat.mod_le _ _
                have e1 := Nat.div_add_mod' n (volume L.block)
                have hmod : (n - n % volume L.block % 32 + y.1) % volume L.block =
                    n % volume L.block - n % volume L.block % 32 + y.1 := by
                  rw [show n - n % volume L.block % 32 + y.1 =
                      (n % volume L.block - n % volume L.block % 32 + y.1) +
                        n / volume L.block * volume L.block by omega,
                    Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hj.2]
                have k1 : n - n % volume L.block % 32 + y.1 -
                    (n - n % volume L.block % 32 + y.1) % volume L.block % 32 =
                      n - n % volume L.block % 32 := by
                  rw [hmod]
                  omega
                have k2 : (n - n % volume L.block % 32 + y.1) % volume L.block -
                    (n - n % volume L.block % 32 + y.1) % volume L.block % 32 =
                      n % volume L.block - n % volume L.block % 32 := by
                  rw [hmod]
                  omega
                unfold Grid.fire
                simp only [hp', hm', ↓reduceIte, k1, k2, ht', hc, bind, Except.bind, pure,
                  Except.pure, hparts, hps, hts]
              · unfold Grid.fire
                simp only [hn₂, hn, hmk, h32, ↓reduceIte, bind, Except.bind, pure, Except.pure]
                rw [show List.mapM _ _ = Except.ok parts from ?_]
                · simp only [hps, hfd]
                  rfl
                · rw [← hparts]
                  refine mapM_congr fun j hj => ?_
                  obtain ⟨-, -, -, -, -, -, -, -, -, y, hy, e⟩ := hlane j hj
                  simp only [hP _ (List.mem_map.2 ⟨y, hy, by rw [e]⟩)]
              · obtain ⟨-, -, -, -, -, -, -, -, -, y, hy, e⟩ := hlane q hq
                exact List.mem_map.2 ⟨y, hy, by rw [e]⟩
          · cases h
      · simp only [h32, ↓reduceIte] at h
        cases h
  · rename_i v
    have hfd : g.fired L n = [] := by simp only [Grid.fired, hn]
    by_cases hw : n % volume L.block - n % volume L.block % 32 + 32 ≤ volume L.block
    · simp only [hw, ↓reduceIte, bind, Except.bind, pure, Except.pure] at h
      split at h
      · cases h
      rename_i r hr
      rcases r with _ | y
      · cases h
      dsimp only at h
      split at h
      · cases h
      rename_i ts hts
      cases h
      obtain ⟨x, -, hx⟩ := mmaRes_ok hr
      have e0 : n % volume L.block % 32 ≤ n % volume L.block := Nat.mod_le _ _
      have e1 := Nat.div_add_mod' n (volume L.block)
      have hl : ∀ j < 32, ∃ t' fn', g.threads[n - n % volume L.block % 32 + j]? =
          some (.wait t' (.mma v) (x j) fn') ∧ t'.at = t.at := by
        intro j hj
        obtain ⟨t', fn', e, ht'⟩ := hx j (by simpa using hj)
        exact ⟨t', fn', by simpa using e, ht'⟩
      refine ⟨_, _, fun p hp => ?_, fun hne => absurd hfd hne, hts, by rw [hfd]; rfl,
        fun p hp c' hc => ?_, fun g₂ hn₂ hP => ?_, fun q hq => ?_⟩
      · obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hp
        obtain ⟨t', fn', hp', -⟩ := hl j (List.mem_range.1 hj)
        exact ⟨_, _, _, _, hp'⟩
      · obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hp
        have hj := List.mem_range.1 hj
        obtain ⟨t', fn', hp', ht'⟩ := hl j hj
        have hmod : (n - n % volume L.block % 32 + j) % volume L.block =
            n % volume L.block - n % volume L.block % 32 + j := by
          rw [show n - n % volume L.block % 32 + j =
              (n % volume L.block - n % volume L.block % 32 + j) +
                n / volume L.block * volume L.block by omega,
            Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt (by omega)]
        have k1 : n - n % volume L.block % 32 + j -
            (n - n % volume L.block % 32 + j) % volume L.block % 32 =
              n - n % volume L.block % 32 := by
          rw [hmod]
          omega
        have k2 : (n - n % volume L.block % 32 + j) % volume L.block -
            (n - n % volume L.block % 32 + j) % volume L.block % 32 =
              n % volume L.block - n % volume L.block % 32 := by
          rw [hmod]
          omega
        unfold Grid.fire
        simp only [hp', k1, k2, hw, ↓reduceIte, ht', hc, bind, Except.bind, pure,
          Except.pure, hr, hts]
      · have e3 : (List.range 32).map (fun j => g₂.threads[n - n % volume L.block % 32 + j]?) =
            (List.range 32).map (fun j => g.threads[n - n % volume L.block % 32 + j]?) :=
          List.map_congr_left fun j hj => hP _ (List.mem_map.2 ⟨j, hj, rfl⟩)
        unfold Grid.fire
        simp only [hn₂, hn, hw, ↓reduceIte, bind, Except.bind, pure, Except.pure]
        rw [e3, hr]
        simp only [hfd]
        rfl
      · simp only [List.mem_filter, List.mem_range, decide_eq_true_eq] at hq
        exact List.mem_map.2 ⟨q, List.mem_range.2 hq.1, rfl⟩
    · simp only [hw, ↓reduceIte] at h
      cases h
  all_goals cases h

/-- **The diamond's case of a thread and a collective call** (T2, docs/proofs/schedule.md). For
every launch, contexts and grid: if the collective call thread `n` waits at completes, and thread
`k` takes a step, with `k`'s block of threads not that of a barrier the call logs, then the call
completes after `k`'s step and `k`'s step succeeds after the call, and the two orders give grids
that are the same (`Grid.Same`). At a barrier the premise says that `k`'s context is not of `n`'s
block of threads; at a shuffle it holds. -/
theorem Grid.advance_fire_comm {L : Launch} {c : Nat → Ctx} {g gk gf : Grid} {n k : Nat}
    (hk : g.advance c k = .ok (some gk)) (hf : g.fire L c n = .ok (some gf))
    (hw : .barrier (c k).who.cta ∉ g.fired L n) :
    ∃ g₁ g₂, gk.fire L c n = .ok (some g₁) ∧ gf.advance c k = .ok (some g₂) ∧ g₁.Same g₂ := by
  have hkeep := Grid.advance_keeps hk
  obtain ⟨tk, s, mk, htk, rfl, htr, hk₂⟩ := Grid.advance_set hk
  obtain ⟨P, v, hPw, -, hPr, hPm, -, hPf, -⟩ := Grid.fire_frame hf
  have hkP : k ∉ P := fun hp => by
    obtain ⟨_, _, _, _, e⟩ := hPw k hp
    rw [htk] at e
    cases e
  obtain ⟨_, _, _, _, hn, -⟩ := Grid.fire_trace hf
  have hkn : k ≠ n := by
    rintro rfl
    rw [htk] at hn
    cases hn
  have hts := resumeAll_getElem? hPr hkP
  obtain ⟨tsf, mf⟩ := gf
  simp only at hPm hts hPr
  subst hPm
  have h₂ := hk₂ { threads := tsf, mem := g.mem } hts rfl
  have hr := Grid.advance_retrace c { threads := tsf, mem := g.mem } (g.fired L n ++ g.mem.trace) k
  rw [h₂] at hr
  have hp : Grid.pending c { threads := tsf, mem := g.mem } k = g.pending c k := by
    simp only [Grid.pending, hts]
  have hf₂ := hPf { threads := g.threads.set! k s, mem := mk }
    (by simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hkn])
    (fun p hp => by
      simp only [Array.set!_eq_setIfInBounds,
        Array.getElem?_setIfInBounds_ne (fun e : k = p => hkP (e ▸ hp))])
  rw [resumeAll_set hkeep hkP hPr] at hf₂
  refine ⟨_, _, hf₂, hr, rfl, rfl, rfl, ?_⟩
  simp only [Grid.retrace, htr, hp]
  have := Trace.Same.swap (E := g.fired L n) (F := g.pending c k) (fun e he f hf => ?_) g.mem.trace
  · simpa using this
  · obtain rfl := Grid.mem_fired he
    unfold Grid.pending at hf
    rw [htk] at hf
    obtain ⟨a, rfl, ha⟩ := Thread.pending_who f hf
    simp only [Event.indep, bne_iff_ne, ne_eq, ha]
    exact fun e => hw (e ▸ he)

/-! ## W4: the accesses of the trace are by the grid's threads -/

/-- `resumeAll` keeps the number of threads. -/
theorem resumeAll_size {l : Layout} {m : Mem} {ts ts' : Array Status} {ns : List Nat}
    {v : Nat → Option Val} (h : resumeAll l m ts ns v = .ok ts') : ts'.size = ts.size := by
  unfold resumeAll at h
  refine foldlM_inv (P := fun ts'' : Array Status => ts''.size = ts.size)
    (fun b i b' hb e => ?_) _ _ h rfl
  split at hb
  · simp only [bind, Except.bind, pure, Except.pure] at hb
    split at hb
    · cases hb
    · cases hb
      simp only [Array.size_set!, e]
  · cases hb
    exact e

/-- W4: every access of the trace is by a thread number below the number of threads, in the block
of threads of that number. -/
def Grid.ByThreads (L : Launch) (g : Grid) : Prop :=
  ∀ a, Event.access a ∈ g.mem.trace →
    a.who.thread < g.threads.size ∧ a.who.cta = a.who.thread / volume L.block

/-- W4 for the grid's steps: for every launch, contexts that give thread `n` the number `n` in
block of threads `n / volume L.block`, and grids, a step keeps `Grid.ByThreads`. -/
theorem Grid.Step.byThreads {L : Launch} {c : Nat → Ctx}
    (hc : ∀ n, (c n).who = ⟨n, n / volume L.block⟩) {g g' : Grid} (h : Grid.Step L c g g')
    (hg : g.ByThreads L) : g'.ByThreads L := by
  obtain ⟨n, h | h⟩ := h
  · obtain ⟨t, s, m, ht, rfl, htr, -⟩ := Grid.advance_set h
    have hn : n < g.threads.size := (Array.getElem?_eq_some_iff.1 ht).1
    intro a ha
    simp only [htr, List.mem_append, Array.size_set!] at ha ⊢
    rcases ha with ha | ha
    · unfold Grid.pending at ha
      rw [ht] at ha
      obtain ⟨a', e, hw⟩ := Thread.pending_who _ ha
      cases e
      rw [hw, hc n]
      exact ⟨hn, rfl⟩
    · exact hg a ha
  · obtain ⟨P, v, -, -, hr, hm, -⟩ := Grid.fire_frame h
    intro a ha
    rw [hm, List.mem_append] at ha
    rw [resumeAll_size hr]
    rcases ha with ha | ha
    · cases Grid.mem_fired ha
    · exact hg a ha

/-- **W4 from the start.** For every program, kernel, launch, arguments, memory, address choice
and oracle: in every grid reachable from the grid that `Grid.start` gives, every access of the
trace is by a thread number below the number of threads, in the block of threads of that
number. -/
theorem Grid.start_reach_byThreads {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') : g'.ByThreads L := by
  induction hr with
  | refl =>
    unfold Grid.start at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    split at h
    · cases h
    split at h
    · cases h
    split at h
    · cases h
    cases h
    exact fun _ ha => nomatch ha
  | tail _ hs ih => exact hs.byThreads (fun n => (Grid.start_ctx h n).2.1) ih

/-! ## The case of a thread and a collective call from the start -/

/-- After a fire, a thread is at a number that has one before it. -/
theorem Grid.fire_threads {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) :
    ∀ (j : Nat) s, g'.threads[j]? = some s → ∃ s', g.threads[j]? = some s' := by
  unfold Grid.fire at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | exact resumeAll_inv (P := fun j _ => ∃ s', g.threads[j]? = some s') ‹_›
        (fun _ _ _ _ _ _ h _ => h) fun j s h => ⟨s, h⟩

/-- In every grid reachable from the start's, there is a thread only if the blocks of threads
are not empty. -/
theorem Grid.start_reach_block {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g) :
    ∀ (j : Nat) s, g.threads[j]? = some s → 0 < volume L.block := by
  refine Grid.reach_inv (P := fun g => ∀ (j : Nat) s, g.threads[j]? = some s → 0 < volume L.block)
    (fun _ _ _ ha hg => ?_) (fun _ _ _ hf hg j s hj => ?_) hr
    fun j s hs => (Grid.start_run h j s hs).1
  · obtain ⟨_, _, _, ht, rfl, -⟩ := Grid.advance_set ha
    exact set!_inv (P := fun _ _ => 0 < volume L.block) hg (hg _ _ ht)
  · obtain ⟨_, hs⟩ := Grid.fire_threads hf j s hj
    exact hg _ _ hs

/-- **A barrier with a running participant does not complete.** For every launch whose blocks of
threads are not empty, contexts and grid: a collective call that completes logs no barrier of the
block of threads of a running thread `k`'s context, if that context puts `k` in block of threads
`k / volume L.block`, as the start's do (`Grid.start_ctx`). At a barrier every thread of the
waiting thread's block of threads waits (`Grid.fire_frame`), and `k` is one of them. The premise
on `k`'s context is needed (MojoProofTest/Bad.lean `fire_race_twin`). -/
theorem Grid.fired_run {L : Launch} {c : Nat → Ctx} {g gf : Grid} {n k : Nat} {t : Thread}
    (hpos : 0 < volume L.block) (hc : (c k).who.cta = k / volume L.block)
    (htk : g.threads[k]? = some (.run t)) (hf : g.fire L c n = .ok (some gf)) :
    .barrier (c k).who.cta ∉ g.fired L n := fun hb => by
  obtain ⟨P, -, hPw, hPb, -⟩ := Grid.fire_frame hf
  obtain ⟨_, _, _, _, e⟩ := hPw k (by
    rw [hPb (List.ne_nil_of_mem hb)]
    refine List.mem_map.2 ⟨k % volume L.block, List.mem_range.2 (Nat.mod_lt _ hpos), ?_⟩
    have e := Grid.mem_fired hb
    simp only [Event.barrier.injEq, hc] at e
    rw [← e]
    exact Nat.div_add_mod' k _)
  rw [htk] at e
  cases e

/-- In every grid reachable from the start's, for every program, kernel, launch, arguments,
caller's memory, address choice and oracle, a collective call that completes logs no barrier of
the block of threads of a running thread `k`'s context: `Grid.fired_run`, as the start puts `k`
in block of threads `k / volume L.block` (`Grid.start_ctx`) and the block of threads is not empty
(`Grid.start_reach_block`). -/
theorem Grid.start_reach_fired {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g gf : Grid} {c : Nat → Ctx}
    {n k : Nat} {t : Thread}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g)
    (htk : g.threads[k]? = some (.run t)) (hf : g.fire L c n = .ok (some gf)) :
    .barrier (c k).who.cta ∉ g.fired L n :=
  Grid.fired_run (Grid.start_reach_block h hr k _ htk) (by rw [(Grid.start_ctx h k).2.1]) htk hf

/-- **The diamond's case of a thread and a collective call from the start** (T2,
docs/proofs/schedule.md). For every program, kernel, launch, arguments, caller's memory, address
choice and oracle, in every grid reachable from the start's: if the collective call thread `n`
waits at completes and thread `k`'s step succeeds, then the call completes after `k`'s step and
`k`'s step succeeds after the call, and the two orders give grids that are the same
(`Grid.Same`). No premise on blocks of threads: `k` runs, so the call logs no barrier of its
block of threads (`Grid.start_reach_fired`). -/
theorem Grid.start_reach_fire_comm {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g gk gf : Grid} {c : Nat → Ctx}
    {n k : Nat}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g)
    (hk : g.advance c k = .ok (some gk)) (hf : g.fire L c n = .ok (some gf)) :
    ∃ g₁ g₂, gk.fire L c n = .ok (some g₁) ∧ gf.advance c k = .ok (some g₂) ∧ g₁.Same g₂ :=
  have ⟨_, _, _, htk, _⟩ := Grid.advance_set hk
  Grid.advance_fire_comm hk hf (Grid.start_reach_fired h hr htk hf)

/-! ## The case of two collective calls -/

/-- **The diamond's case of two collective calls** (T2, docs/proofs/schedule.md). For every
launch, contexts and grid: if the collective calls threads `n` and `j` wait at complete, and `n`'s
and `j`'s contexts have one layout, then the two give the same grid, or each completes after the
other and the two orders give grids that are the same (`Grid.Same`). The first if a thread of one
call's participants (`Grid.fire_frame`) is `j`, `n` or one of the other's, since each participant
completes the call to the same grid; the second otherwise, since each call resumes threads the
other keeps, keeps the blocks, and logs only `.barrier`s, which are independent of each other. -/
theorem Grid.fire_fire_comm {L : Launch} {c : Nat → Ctx} {g gn gj : Grid} {n j : Nat}
    (hl : (c n).prog.layout = (c j).prog.layout)
    (hn : g.fire L c n = .ok (some gn)) (hj : g.fire L c j = .ok (some gj)) :
    gn = gj ∨
      ∃ g₁ g₂, gn.fire L c j = .ok (some g₁) ∧ gj.fire L c n = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨P, v, -, -, hPr, hPm, hPe, hPf, -⟩ := Grid.fire_frame hn
  obtain ⟨Q, w, -, -, hQr, hQm, hQe, hQf, -⟩ := Grid.fire_frame hj
  by_cases hs : (∃ p ∈ P, p ∈ Q) ∨ j ∈ P ∨ n ∈ Q
  · left
    rcases hs with ⟨p, hp, hq⟩ | hjP | hnQ
    · have e := hQe p hq (fun _ => c n) hl
      rw [hPe p hp (fun _ => c n) rfl] at e
      cases e
      rfl
    · have e := hPe j hjP c hl.symm
      rw [hj] at e
      cases e
      rfl
    · have e := hQe n hnQ c hl
      rw [hn] at e
      cases e
      rfl
  · right
    simp only [not_or, not_exists, not_and] at hs
    obtain ⟨hPQ, hjP, hnQ⟩ := hs
    have kn : g.mem.Keeps gn.mem := by
      rw [hPm]
      exact ⟨fun _ _ hx => by simp [hx], rfl, fun _ _ h => h⟩
    have kj : g.mem.Keeps gj.mem := by
      rw [hQm]
      exact ⟨fun _ _ hx => by simp [hx], rfl, fun _ _ h => h⟩
    have hnQ' : ∀ q ∈ Q, gn.threads[q]? = g.threads[q]? :=
      fun q hq => resumeAll_getElem? hPr fun hp => hPQ q hp hq
    have hjP' : ∀ p ∈ P, gj.threads[p]? = g.threads[p]? :=
      fun p hp => resumeAll_getElem? hQr (hPQ p hp)
    obtain ⟨X, hX, hXQ⟩ := resumeAll_agree kn hnQ' hQr
    obtain ⟨Y, hY, hYP⟩ := resumeAll_agree kj hjP' hPr
    refine ⟨_, _, by rw [hQf gn (resumeAll_getElem? hPr hjP) hnQ', hX]; rfl,
      by rw [hPf gj (resumeAll_getElem? hQr hnQ) hjP', hY]; rfl, ?_, ?_, ?_, ?_⟩
    · refine Array.ext_getElem? fun p => ?_
      by_cases hp : p ∈ P
      · rw [resumeAll_getElem? hX (hPQ p hp), hYP p hp]
      · by_cases hq : p ∈ Q
        · rw [hXQ p hq, resumeAll_getElem? hY hp]
        · rw [resumeAll_getElem? hX hq, resumeAll_getElem? hY hp, resumeAll_getElem? hPr hp,
            resumeAll_getElem? hQr hq]
    · simp only [hPm, hQm]
    · simp only [hPm, hQm]
    · simp only [hPm, hQm]
      have := Trace.Same.swap (E := g.fired L j) (F := g.fired L n)
        (fun e he f hf => by rw [Grid.mem_fired he, Grid.mem_fired hf]; rfl) g.mem.trace
      simpa using this

/-- **The case of two collective calls in the start's contexts.** For every program, kernel,
launch, arguments, caller's memory, address choice and oracle, and every grid in the start's
contexts: if the collective calls threads `n` and `j` wait at complete, they give the same grid,
or each completes after the other and the two orders give grids that are the same. The start's
contexts have one program (`Grid.start_ctx`). -/
theorem Grid.start_fire_fire_comm {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g gn gj : Grid} {c : Nat → Ctx}
    {n j : Nat} (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hn : g.fire L c n = .ok (some gn)) (hj : g.fire L c j = .ok (some gj)) :
    gn = gj ∨
      ∃ g₁ g₂, gn.fire L c j = .ok (some g₁) ∧ gj.fire L c n = .ok (some g₂) ∧ g₁.Same g₂ :=
  Grid.fire_fire_comm (by rw [(Grid.start_ctx h n).1, (Grid.start_ctx h j).1]) hn hj


/-! ## Ownership gives the premise on accesses -/

/-- An access that begins with a check (a load, a write) and succeeds is to a block of the memory
whose owner admits the thread (`Mem.check_block`). -/
theorem Mem.check_bind_admits {α : Type} {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr}
    {al : Option Nat} {f : Block × Nat → Except Fault α} {y : α}
    (h : (m.check l w a p n al >>= f) = .ok y) :
    ∃ x, m.blocks p.block = some x ∧ x.owner.admits w = true := by
  cases hc : m.check l w a p n al with
  | error => simp [hc, bind, Except.bind] at h
  | ok r => exact ⟨r.1, Mem.check_block (o := r.2) hc⟩

/-- A load that succeeds is from a block of the memory whose owner admits the thread. -/
theorem Mem.load_admits {l : Layout} {m : Mem} {w : Who} {a : Nat} {t : Ty} {p : Ptr}
    {al : Option Nat} {v : Val} (h : m.load l w a t p al = .ok v) :
    ∃ x, m.blocks p.block = some x ∧ x.owner.admits w = true :=
  Mem.check_bind_admits h

/-- A store that succeeds is to a block of the memory whose owner admits the thread. -/
theorem Mem.store_admits {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m') :
    ∃ x, m.blocks p.block = some x ∧ x.owner.admits w = true := by
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · exact Mem.check_bind_admits ‹Mem.write _ _ _ _ _ _ _ = _›

/-- Every access that a statement which succeeds would log (`Stmt.pending`) is to a block of the
scope's memory whose owner admits the context's thread: that of a `load` or a `store`, and both
of an `atomicrmw`, which loads at the pointer it stores to. -/
theorem exec_admits {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {e : Eff}
    (h : exec c s k f st = .ok e) :
    ∀ a, .access a ∈ st.pending c s →
      ∃ x, s.mem.blocks a.ptr.block = some x ∧ x.owner.admits c.who = true := by
  intro a ha
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals simp [LLVM.Stmt.pending, bind, Except.bind, *] at ha
  all_goals first
    | (subst ha; exact Mem.load_admits ‹_›)
    | (subst ha; exact Mem.store_admits ‹_›)
    | (rcases ha with rfl | rfl <;> exact Mem.load_admits ‹_›)

/-- Every access that a step which succeeds would log (`Thread.pending`) is to a block of the
memory whose owner admits the context's thread. -/
theorem step_admits {c : Ctx} {t : Thread} {m : Mem} {r : Step} (h : step c t m = .ok r) :
    ∀ a, .access a ∈ t.pending c m →
      ∃ x, m.blocks a.ptr.block = some x ∧ x.owner.admits c.who = true := by
  intro a ha
  unfold step at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | exact exec_admits ‹exec _ _ _ _ _ = Except.ok _› a (by simpa [Thread.pending, *] using ha)
    | simp [Thread.pending, *] at ha

/-- Every access that a step of thread `n` of a grid which gives a grid would log
(`Grid.pending`) is to a block of the grid's memory whose owner admits `n`'s context's thread. -/
theorem Grid.advance_admits {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) :
    ∀ a, .access a ∈ g.pending c n →
      ∃ x, g.mem.blocks a.ptr.block = some x ∧ x.owner.admits (c n).who = true := by
  obtain ⟨t, ht, -⟩ := Grid.advance_pending h
  unfold Grid.advance at h
  simp only [Grid.pending, ht, bind, Except.bind] at h ⊢
  split at h
  · cases h
  · exact step_admits ‹_›

/-- Every access among thread `n`'s pending accesses is by `n`'s context's thread. -/
theorem Grid.pending_who {c : Nat → Ctx} {g : Grid} {n : Nat} {a : Access}
    (h : .access a ∈ g.pending c n) : a.who = (c n).who := by
  unfold Grid.pending at h
  split at h
  · obtain ⟨_, he, hw⟩ := Thread.pending_who _ h
    cases he
    exact hw
  · cases h

/-- **Ownership gives the premise on accesses** (`hW` of `Grid.advance_comm`, through
`Access.conflict_eq_false`;
docs/proofs/schedule-owned.md, hypotheses `hH` and `hX`). For every discipline `(T, own)`,
contexts, grid, and threads `n` and `k` whose steps give grids and whose contexts' threads have
different tiles: if each of their pending accesses follows the discipline (`Owned`) or is to a
block that its thread owns (`Mem.Owned`), no write of either overlaps an access of the other. Two
accesses that follow the discipline and overlap are reads (`Owned.apart`), and an access by one
thread to a block the other owns is in no step that succeeds, since that block's owner admits
only its own thread (`Grid.advance_admits`). -/
theorem Grid.pending_apart {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {c : Nat → Ctx} {g gn gk : Grid} {n k : Nat}
    (hn : g.advance c n = .ok (some gn)) (hk : g.advance c k = .ok (some gk))
    (hX : own (c n).who.thread ≠ own (c k).who.thread)
    (hH : ∀ p ∈ [n, k], ∀ a, .access a ∈ g.pending c p →
      Owned T own a ∨ g.mem.Owned (c p).who.thread a.ptr.block) :
    ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
      a.overlaps a' = true → a.write = false ∧ a'.write = false := by
  intro a a' ha ha' hov
  have hb : a.ptr.block = a'.ptr.block := by
    simp only [Access.overlaps, Bool.and_eq_true, beq_iff_eq] at hov
    exact hov.1.1.1.1
  have hw : (c n).who.thread ≠ (c k).who.thread := fun e => hX (by rw [e])
  rcases hH n (by simp) a ha with h₁ | ⟨x, hx, ho⟩
  · rcases hH k (by simp) a' ha' with h₂ | ⟨x, hx, ho⟩
    · exact h₁.apart h₂ (fun _ _ => by rw [Grid.pending_who ha, Grid.pending_who ha']; exact hX)
        hov
    · obtain ⟨y, hy, hadm⟩ := Grid.advance_admits hn a ha
      rw [hb, hx] at hy
      cases hy
      rw [ho] at hadm
      exact absurd (by simpa [Owner.admits] using hadm) hw
  · obtain ⟨y, hy, hadm⟩ := Grid.advance_admits hk a' ha'
    rw [← hb, hx] at hy
    cases hy
    rw [ho] at hadm
    exact absurd (by simpa [Owner.admits] using hadm) (Ne.symm hw)

/-! ## L10's memory part: a load after a store, and two updates of one operation -/

/-- A log leaves every check as it is. -/
theorem Mem.check_log {l : Layout} (m : Mem) (e : Event) {w : Who} {a n : Nat} {p : Ptr}
    {al : Option Nat} : (m.log e).check l w a p n al = m.check l w a p n al := by
  rfl

/-- A check that succeeds succeeds after a put of any bytes at any offset into its block, with
the block after the put: a check reads only the block's liveness, owner and size and the
address, which a put keeps. -/
theorem Mem.check_put {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {blk : Block} {o : Nat} (o' : Nat) (bs : List MemByte)
    (h : m.check l w a p n al = .ok (blk, o)) :
    (m.set p.block (blk.put o' bs)).check l w a p n al = .ok (blk.put o' bs, o) := by
  obtain ⟨hb, hl, hadm, ⟨h0, hn⟩, ad, had, hal, rfl⟩ := Mem.check_inv h
  exact Mem.check_ok (by simp [Mem.set]) hl hadm h0 hn
    (Mem.addr_keeps (Mem.set_keeps (fun x hx => by rw [hb] at hx; cases hx; rfl)
      (.inl (by simp [hb]))) had) hal

/-- The converse of `Mem.load_of_check`: a load that succeeds passed its check, at the pointer's
offset, and what it gives is what the bytes there decode to. -/
theorem Mem.load_inv {l : Layout} {m : Mem} {w : Who} {a : Nat} {t : Ty} {p : Ptr}
    {al : Option Nat} {v : Val} (h : m.load l w a t p al = .ok v) :
    ∃ blk, m.check l w a p (l.stored t) al = .ok (blk, p.off.toNat) ∧
      l.decode t (blk.read p.off.toNat (l.stored t)) = some v := by
  unfold Mem.load at h
  obtain ⟨⟨blk, o⟩, hc, h⟩ := Except.bind_eq_ok.1 h
  obtain ⟨-, -, -, -, -, -, -, rfl⟩ := Mem.check_inv hc
  refine ⟨blk, hc, ?_⟩
  simp only at h
  split at h
  · cases h
    assumption
  · cases h

/-- The converse of `Mem.write_of_check` for a store: a store that succeeds passed its check at
the type's size, into a writable block, encoded its value, and gives the memory with those bytes
put at the pointer's offset and the write logged. -/
theorem Mem.store_inv {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val} {p : Ptr}
    {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m') :
    ∃ blk bs, m.check l w a p (l.stored t) al = .ok (blk, p.off.toNat) ∧ blk.readOnly = false ∧
      l.encode t v = some bs ∧ m' = (m.set p.block (blk.put p.off.toNat bs)).log
        (.access ⟨w, p, l.stored t, true, op, false⟩) := by
  unfold Mem.store at h
  split at h
  · rename_i bs hbs
    have hlen := l.encode_length _ _ _ hbs
    obtain ⟨m₁, hw, h⟩ := Except.bind_eq_ok.1 h
    cases h
    unfold Mem.write at hw
    obtain ⟨⟨blk, o⟩, hc, hw⟩ := Except.bind_eq_ok.1 hw
    obtain ⟨-, -, -, -, -, -, -, rfl⟩ := Mem.check_inv hc
    simp only at hw
    split at hw
    · cases hw
    · rename_i hro
      cases hw
      rw [hlen] at hc
      exact ⟨blk, bs, hc, by simpa using hro, hbs, by rw [hlen]⟩
  · cases h

/-- **A load after a store at the same pointer** (a step of L10's memory part): after a store of
`v` of type `t` that succeeds, a load of type `t` at the same pointer, by a thread `w'` with an
alignment `al'` whose check succeeds before the store, succeeds and gives what the bytes that `v`
encodes to decode to. For every layout, memory, two threads, value, pointer and two alignments. -/
theorem Mem.load_store {l : Layout} {m m' : Mem} {w w' : Who} {a : Nat} {t : Ty} {v v' : Val}
    {p : Ptr} {al al' : Option Nat} {op : Option RmwOp} {bs : List MemByte} {r : Block × Nat}
    (h : m.store l w a t v p al op = .ok m') (hc : m.check l w' a p (l.stored t) al' = .ok r)
    (hbs : l.encode t v = some bs) (hd : l.decode t bs = some v') :
    m'.load l w' a t p al' = .ok v' := by
  obtain ⟨blk, bs', hc', -, hbs', rfl⟩ := Mem.store_inv h
  obtain ⟨blk', o⟩ := r
  obtain ⟨hy, -, -, -, -, -, -, rfl⟩ := Mem.check_inv hc
  cases Option.some.inj ((Mem.check_inv hc').1.symm.trans hy)
  cases Option.some.inj (hbs'.symm.trans hbs)
  exact Mem.load_of_check ((Mem.check_log _ _).trans (Mem.check_put _ _ hc))
    (by rwa [← l.encode_length _ _ _ hbs, Block.read_put_self])

/-- For a codec `enc` of type `t` (`Layout.Codec`: integers and floats), a load after a store of
`enc x` at the same pointer, whose check succeeds before the store, gives `enc x`. -/
theorem Mem.load_store_codec {l : Layout} {m m' : Mem} {w w' : Who} {a : Nat} {t : Ty} {p : Ptr}
    {al al' : Option Nat} {op : Option RmwOp} {r : Block × Nat} {α : Type} {enc : α → Val}
    (he : l.Codec t enc) (x : α) (h : m.store l w a t (enc x) p al op = .ok m')
    (hc : m.check l w' a p (l.stored t) al' = .ok r) : m'.load l w' a t p al' = .ok (enc x) := by
  obtain ⟨_, hbs, _, hd⟩ := he.round x
  exact Mem.load_store h hc hbs hd

/-- What `Layout.scalarOf w` gives is a scalar of width `w`: bits of width `w`, poison or undef. -/
theorem Layout.scalarOf_scalar {w : Nat} {bs : List MemByte} {v : Val}
    (h : Layout.scalarOf w bs = some v) : v.Scalar w := by
  unfold Layout.scalarOf at h
  split_ifs at h
  · cases h
    exact .inr (.inl rfl)
  · cases h
    exact .inr (.inr rfl)
  · obtain ⟨k, -, rfl⟩ := Option.map_eq_some_iff.mp h
    split
    · exact .inl ⟨_, rfl⟩
    · exact .inr (.inl rfl)

/-- A load of an integer type that succeeds gives a scalar of its width. -/
theorem Mem.load_scalar {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {v : Val} (h : m.load l w a (.int n) p al = .ok v) : v.Scalar n := by
  obtain ⟨blk, -, hd⟩ := Mem.load_inv h
  simp only [Layout.decode] at hd
  exact Layout.scalarOf_scalar hd

/-- A scalar of a positive width `w` is stored as bytes that load back as it: for every layout,
bits of width `w`, poison and undef round-trip through the bytes of `.int w`. -/
theorem Layout.scalar_round {l : Layout} {w : Nat} (hw : 0 < w) {v : Val} (hv : v.Scalar w) :
    ∃ bs, l.encode (.int w) v = some bs ∧ l.decode (.int w) bs = some v := by
  have hs : 0 < l.stored (.int w) := by
    simp only [Layout.stored, Layout.storeSize, Layout.scalarBits]
    omega
  rcases hv with ⟨a, rfl⟩ | rfl | rfl
  · obtain ⟨bs, he, -, hd⟩ := (Codec.int l w).round a
    exact ⟨bs, he, hd⟩
  · refine ⟨List.replicate (l.stored (.int w)) .poison, by simp only [Layout.encode], ?_⟩
    simp only [Layout.decode, Layout.scalarOf]
    simp [List.mem_replicate, hs.ne']
  · refine ⟨List.replicate (l.stored (.int w)) .undef, by simp only [Layout.encode], ?_⟩
    simp only [Layout.decode, Layout.scalarOf]
    simp [List.mem_replicate, hs.ne']

/-- The bytes of a value at an integer type are the same in every layout. -/
theorem Layout.encode_int (l l' : Layout) (w : Nat) (v : Val) :
    l.encode (.int w) v = l'.encode (.int w) v := by
  cases v <;> simp [Layout.encode, Layout.stored, Layout.storeSize, Layout.scalarBits]

/-- The update an `atomicrmw` of operation `op` by operand `x` makes at `q` (a pointer of space
`a`, alignment `al`) of type `t`, by thread `w`, as `exec` makes it once the operands are
evaluated (`exec_atomic`): a load, its read logged, `rmw` of the old value and `x` at `t`'s width,
and a store of the result, logged as a write by `op`. -/
def Mem.update (l : Layout) (m : Mem) (w : Who) (a : Nat) (t : Ty) (op : RmwOp) (x : Val)
    (q : Ptr) (al : Option Nat) : Except Fault Mem :=
  m.load l w a t q al >>= fun old => rmw (l.scalarBits t) op old x >>= fun v =>
    (m.log (.access ⟨w, q, l.stored t, false, some op, false⟩)).store l w a t v q al (some op)

/-- An update succeeds exactly when its check succeeds into a writable block whose bytes at the
pointer decode to a value, `rmw` succeeds on that value, and its result encodes; the memory after
it has the read logged, the result's bytes put and the write logged. -/
theorem Mem.update_eq_ok {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {op : RmwOp}
    {x : Val} {q : Ptr} {al : Option Nat} :
    m.update l w a t op x q al = .ok m' ↔ ∃ blk v r bs,
      m.check l w a q (l.stored t) al = .ok (blk, q.off.toNat) ∧ blk.readOnly = false ∧
      l.decode t (blk.read q.off.toNat (l.stored t)) = some v ∧
      rmw (l.scalarBits t) op v x = .ok r ∧ l.encode t r = some bs ∧
      m' = (((m.log (.access ⟨w, q, l.stored t, false, some op, false⟩)).set q.block
        (blk.put q.off.toNat bs)).log (.access ⟨w, q, l.stored t, true, some op, false⟩)) := by
  constructor
  · intro h
    obtain ⟨v, hl, h⟩ := Except.bind_eq_ok.1 h
    obtain ⟨r, hr, h⟩ := Except.bind_eq_ok.1 h
    obtain ⟨blk, hc, hd⟩ := Mem.load_inv hl
    obtain ⟨blk', bs, hc', hro, hbs, rfl⟩ := Mem.store_inv h
    rw [Mem.check_log, hc] at hc'
    cases hc'
    exact ⟨_, v, r, bs, hc, hro, hd, hr, hbs, rfl⟩
  · rintro ⟨blk, v, r, bs, hc, hro, hd, hr, hbs, rfl⟩
    have hlen := l.encode_length _ _ _ hbs
    have hw : (m.log (.access ⟨w, q, l.stored t, false, some op, false⟩)).write l w a q bs al =
        .ok ((m.log (.access ⟨w, q, l.stored t, false, some op, false⟩)).set q.block
          (blk.put q.off.toNat bs)) :=
      Mem.write_of_check (by rw [hlen, Mem.check_log]; exact hc) hro
    simp [Mem.update, Mem.load_of_check hc hd, hr, Mem.store, hbs, hw, hlen, bind, Except.bind,
      pure, Except.pure]

/-- **Two updates of one operation on the same bytes commute** (L10's memory part). For every two
layouts, memory, threads, spaces, operands and alignments, every operation and every positive
width `n`: if two updates of type `.int n` at the same pointer each succeed from `m`, each
succeeds after the other, and the two orders give the same blocks, the same `next` and the same
trace up to the order of independent events (`Trace.Same`). Each update's result is a scalar
(`Layout.scalarOf_scalar`, `rmw_scalar`) whose bytes decode back to it (`Layout.scalar_round`),
the two results updated by the other operand agree (`rmw_comm_of_ok`), and the second put covers
the first (`Block.put_put`). -/
theorem Mem.update_comm {l₁ l₂ : Layout} {m m₁ m₂ : Mem} {w₁ w₂ : Who} {a₁ a₂ n : Nat}
    {op : RmwOp} {x₁ x₂ : Val} {q : Ptr} {al₁ al₂ : Option Nat} (hn : 0 < n)
    (h₁ : m.update l₁ w₁ a₁ (.int n) op x₁ q al₁ = .ok m₁)
    (h₂ : m.update l₂ w₂ a₂ (.int n) op x₂ q al₂ = .ok m₂) :
    ∃ m₁₂ m₂₁, m₁.update l₂ w₂ a₂ (.int n) op x₂ q al₂ = .ok m₁₂ ∧
      m₂.update l₁ w₁ a₁ (.int n) op x₁ q al₁ = .ok m₂₁ ∧
      m₁₂.blocks = m₂₁.blocks ∧ m₁₂.next = m₂₁.next ∧ Trace.Same m₁₂.trace m₂₁.trace := by
  obtain ⟨blk, v, r₁, bs₁, hc₁, hro, hd₁, hr₁, he₁, rfl⟩ := Mem.update_eq_ok.1 h₁
  obtain ⟨blk₂, v₂, r₂, bs₂, hc₂, -, hd₂, hr₂, he₂, rfl⟩ := Mem.update_eq_ok.1 h₂
  cases Option.some.inj ((Mem.check_inv hc₁).1.symm.trans (Mem.check_inv hc₂).1)
  simp only [Layout.decode, Layout.stored, Layout.storeSize, Layout.scalarBits] at hd₁ hd₂ hr₁ hr₂
  cases Option.some.inj (hd₂.symm.trans hd₁)
  have hv := Layout.scalarOf_scalar hd₁
  have hs₁ := rmw_scalar hv hr₁
  have hs₂ := rmw_scalar hv hr₂
  obtain ⟨u, hu₁, hu₂⟩ := rmw_comm_of_ok hv hr₁ hr₂
  obtain ⟨bu, heu, -⟩ := Layout.scalar_round (l := l₁) hn (rmw_scalar hs₁ hu₁)
  obtain ⟨bs₁', he₁', hd₁'⟩ := Layout.scalar_round (l := l₁) hn hs₁
  rw [he₁] at he₁'
  cases he₁'
  obtain ⟨bs₂', he₂', hd₂'⟩ := Layout.scalar_round (l := l₂) hn hs₂
  rw [he₂] at he₂'
  cases he₂'
  simp only [Layout.decode] at hd₁' hd₂'
  have L₁ : bs₁.length = (n + 7) / 8 := l₁.encode_length _ _ _ he₁
  have L₂ : bs₂.length = (n + 7) / 8 := l₂.encode_length _ _ _ he₂
  have Lu : bu.length = (n + 7) / 8 := l₁.encode_length _ _ _ heu
  refine ⟨_, _, Mem.update_eq_ok.2 ⟨blk.put q.off.toNat bs₁, r₁, u, bu,
      (Mem.check_log _ _).trans (Mem.check_put _ _ ((Mem.check_log _ _).trans hc₂)), hro, ?_, hu₁,
      (Layout.encode_int l₂ l₁ n u).trans heu, rfl⟩,
    Mem.update_eq_ok.2 ⟨blk.put q.off.toNat bs₂, r₂, u, bu,
      (Mem.check_log _ _).trans (Mem.check_put _ _ ((Mem.check_log _ _).trans hc₁)), hro, ?_, hu₂,
      heu, rfl⟩, ?_, rfl, ?_⟩
  · simp only [Layout.decode, Layout.stored, Layout.storeSize, Layout.scalarBits]
    rw [← L₁, Block.read_put_self]
    exact hd₁'
  · simp only [Layout.decode, Layout.stored, Layout.storeSize, Layout.scalarBits]
    rw [← L₂, Block.read_put_self]
    exact hd₂'
  · funext b
    simp only [Mem.set, Mem.log]
    split_ifs
    · rw [Block.put_put _ _ (by omega), Block.put_put _ _ (by omega)]
    · rfl
  · exact Trace.Same.swap (E := [_, _]) (F := [_, _]) (fun e he f hf => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at he hf
      rcases he with rfl | rfl <;> rcases hf with rfl | rfl <;> rfl) m.trace

/-- **An update that succeeds after another on the same bytes succeeds before it** (L10's memory
part, for faults). For every two layouts, memory, threads, spaces, operations, operands and
alignments, and every positive width `n`: if an update of type `.int n` at `q` succeeds from `m`
and gives `m₁`, an update of type `.int n` at `q` by a scalar of width `n` that succeeds from `m₁`
succeeds from `m`. The first update keeps the block's liveness, owner, size and address
(`Mem.addr_shape`), so the second's check passes from `m`; the first's `rmw` succeeded, so the
old value is a scalar (`Layout.scalarOf_scalar`) that is not undef, and the second's did, so its
operand is not undef (`rmw_undef`); `rmw` of two such scalars succeeds (`rmw_ok`) and gives a
scalar, which encodes (`Layout.scalar_round`). -/
theorem Mem.update_before {l₁ l₂ : Layout} {m m₁ m₂ : Mem} {w₁ w₂ : Who} {a₁ a₂ n : Nat}
    {op₁ op₂ : RmwOp} {x₁ x₂ : Val} {q : Ptr} {al₁ al₂ : Option Nat} (hn : 0 < n)
    (hx : x₂.Scalar n) (h₁ : m.update l₁ w₁ a₁ (.int n) op₁ x₁ q al₁ = .ok m₁)
    (h₂ : m₁.update l₂ w₂ a₂ (.int n) op₂ x₂ q al₂ = .ok m₂) :
    ∃ m', m.update l₂ w₂ a₂ (.int n) op₂ x₂ q al₂ = .ok m' := by
  obtain ⟨blk, v, r₁, bs₁, hc₁, hro, hd₁, hr₁, he₁, rfl⟩ := Mem.update_eq_ok.1 h₁
  obtain ⟨blk₂, v₂, r₂, bs₂, hc₂, -, hd₂, hr₂, -, -⟩ := Mem.update_eq_ok.1 h₂
  obtain ⟨hb, hl, -, ⟨h0, hsz⟩, -⟩ := Mem.check_inv hc₁
  obtain ⟨hb₂, -, hw₂, -, ad, had, hal, -⟩ := Mem.check_inv hc₂
  simp only [Mem.log, Mem.set, ↓reduceIte, Option.some.injEq] at hb₂
  subst hb₂
  have key : ∀ m' : Mem, m'.blocks q.block = some (blk.put q.off.toNat bs₁) →
      m'.addr l₂ a₂ q = m.addr l₂ a₂ q := fun m' h' =>
    Mem.addr_shape (S := (· = q.block)) (fun _ e => by subst e; rw [h', hb]; rfl) rfl l₂ a₂
  have had' := (key _ (by simp [Mem.log, Mem.set])).symm.trans had
  have L : bs₁.length = (n + 7) / 8 := l₁.encode_length _ _ _ he₁
  simp only [Layout.decode, Layout.stored, Layout.storeSize,
    Layout.scalarBits] at hsz hd₁ hd₂ hr₁ hr₂
  have hv := Layout.scalarOf_scalar hd₁
  obtain ⟨bs, he, hd⟩ := Layout.scalar_round (l := l₁) hn (rmw_scalar hv hr₁)
  rw [he₁] at he
  cases he
  simp only [Layout.decode] at hd
  rw [← L, Block.read_put_self, hd] at hd₂
  cases hd₂
  obtain ⟨r, hr⟩ := rmw_ok (rmw_commutes hr₂) hv hx (rmw_undef hr₁).1 (rmw_undef hr₂).2
  obtain ⟨bs', he', -⟩ := Layout.scalar_round (l := l₂) hn (rmw_scalar hv hr)
  exact ⟨_, Mem.update_eq_ok.2 ⟨blk, v, r, bs', Mem.check_ok hb hl hw₂ h0 hsz had' hal, hro,
    by simp only [Layout.decode, Layout.stored, Layout.storeSize, Layout.scalarBits]; exact hd₁,
    hr, he', rfl⟩⟩

/-- A width `n` that is a power of two of at least 8 is 8 times the bytes `.int n` takes, in every
layout. -/
theorem Layout.eight_mul_stored (l : Layout) {n : Nat} (h8 : 8 ≤ n) (hp : n.nextPowerOfTwo = n) :
    8 * l.stored (.int n) = n := by
  obtain ⟨j, hj⟩ := Nat.isPowerOfTwo_nextPowerOfTwo n
  rw [hp] at hj
  have hj3 : 3 ≤ j := by
    by_contra hlt
    have : 2 ^ j ≤ 2 ^ 2 := Nat.pow_le_pow_right (by norm_num) (by omega)
    norm_num at this
    omega
  obtain ⟨i, rfl⟩ : 8 ∣ n := by
    rw [hj]
    simpa using Nat.pow_dvd_pow 2 hj3
  show 8 * ((8 * i + 7) / 8) = 8 * i
  omega

/-- `Stmt.checkAtomic` admits an `atomicrmw` only at an integer type whose width is a power of two
of at least 8. -/
theorem Stmt.checkAtomic_int {fn : Func} {st : Stmt} {vol : Bool} {op : RmwOp} {p : TValue}
    {t : Ty} {v : Value} {sc : Option String} {ord : LLVM.Ordering} {al : Option Nat} {u : Unit}
    (hi : st.inst = .atomicrmw vol op p (.mk t v) sc ord al) (h : st.checkAtomic fn = .ok u) :
    ∃ w, t = .int w ∧ 8 ≤ w ∧ w.nextPowerOfTwo = w := by
  obtain ⟨res, inst, md⟩ := st
  simp only at hi
  subst hi
  cases t with
  | int w =>
    refine ⟨w, rfl, ?_⟩
    by_contra hc
    have hb : (8 ≤ w && w.nextPowerOfTwo == w) = false := by simpa using hc
    cases op <;> simp [LLVM.Stmt.checkAtomic, hb, RmwOp.commutes, bind, Except.bind] at h
  | _ =>
    cases op <;> simp [LLVM.Stmt.checkAtomic, RmwOp.commutes, bind, Except.bind] at h

/-- **An `atomicrmw` is an update.** For every context, scope naming numbers of `S`, step number,
frame and statement whose execution succeeds and that would log an atomic access `e`: `e` is by
an operation `op`, has a positive size, and from every memory with the scope's memory's shape at
`S`, the execution is the update (`Mem.update`) of type `.int (8 * e.len)` at `e`'s pointer by
`op` with one operand, a scalar of width `8 * e.len`, one space and one alignment, then the frame
at its next statement. -/
theorem exec_atomic {S : Nat → Prop} {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {r : Eff} {e : Access} (hs : s.NamesIn S) (he : .access e ∈ st.pending c s)
    (ha : e.atomic.isSome) (h : exec c s k f st = .ok r) :
    ∃ op sp x al, e.atomic = some op ∧ 0 < e.len ∧ x.Scalar (8 * e.len) ∧
      ∀ m₂, s.mem.SameShape S m₂ → exec c { s with mem := m₂ } k f st =
        (m₂.update c.prog.layout c.who sp (.int (8 * e.len)) op x e.ptr al >>=
          fun m' => pure (.next { f with pc := f.pc + 1 } m')) := by
  simp only [LLVM.Stmt.pending] at he
  split at he
  all_goals try first
    | (simp at he; done)
    | (exfalso
       split at he <;> simp only [List.mem_singleton, List.not_mem_nil, Event.access.injEq] at he
       subst he
       simp at ha)
  rename_i vol op a p t v sc ord al hi
  simp only [exec, hi, bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first | cases ‹throw _ = Except.ok _› | cases h
  have hmd := ‹st.checkMd = .ok _›
  have hso := ‹(sc.isNone && ord == .seqCst) = true›
  have hca := ‹st.checkAtomic f.fn = .ok _›
  have hpv := ‹evalV s (.ptr a) p = .ok _›
  have hq := ‹Val.addr? _ = .ok _›
  simp only [hpv, hq, bind, Except.bind, List.mem_append, List.mem_singleton,
    Event.access.injEq] at he
  obtain ⟨n, rfl, h8, hp⟩ := Stmt.checkAtomic_int hi hca
  have hlen := c.prog.layout.eight_mul_stored h8 hp
  obtain ⟨x, hx, hsx⟩ : ∃ x, evalV s (.int n) v = .ok x ∧
      decide (x.Scalar (c.prog.layout.scalarBits (.int n))) = true := ⟨_, ‹_›, ‹_›⟩
  rcases he with rfl | rfl <;>
    refine ⟨op, a, x, some (al.getD (c.prog.layout.storeSize (.int n))), rfl,
      by show 0 < c.prog.layout.stored (.int n); omega,
      by show x.Scalar (8 * c.prog.layout.stored (.int n)); rw [hlen]; exact of_decide_eq_true hsx,
      fun m₂ hm => ?_⟩ <;>
    have e1 : ∀ t v, evalV { s with mem := m₂ } t v = evalV s t v := fun t v =>
      (evalV_shape hs hm t v).1 <;>
    simp only [hlen, Mem.update, bind_assoc] <;>
    simp only [exec, hi, e1, hmd, hso, hca, hpv, hq, hx, hsx, bind, Except.bind, pure,
      Except.pure, ↓reduceIte]

/-- `exec_atomic` for steps: for every context, thread and memory, a step that succeeds and would
log an atomic access `e` is, from every memory with the shape at `S`, the update of type
`.int (8 * e.len)` at `e`'s pointer by `e`'s operation with a scalar operand, then one thread
`t'`. -/
theorem step_atomic {S : Nat → Prop} {c : Ctx} {t : Thread} {m : Mem} {r : Step} {e : Access}
    (hs : ∀ f, t.frames.head? = some f → (c.scope m f t.k).NamesIn S)
    (he : .access e ∈ t.pending c m) (ha : e.atomic.isSome) (h : step c t m = .ok r) :
    ∃ op sp x al t', e.atomic = some op ∧ 0 < e.len ∧ x.Scalar (8 * e.len) ∧
      ∀ m₂, m.SameShape S m₂ → step c t m₂ =
        (m₂.update c.prog.layout c.who sp (.int (8 * e.len)) op x e.ptr al >>=
          fun m' => pure (.next t' m')) := by
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t
  · simp [Thread.pending] at he
  cases hb : f.fn.blocks.find? (·.label == f.label) with
  | none => simp [Thread.pending, hb] at he
  | some b =>
  cases hst : b.stmts[f.pc]? with
  | none => simp [Thread.pending, hb, hst] at he
  | some st =>
  obtain ⟨hpc, rfl⟩ := Array.getElem?_eq_some_iff.1 hst
  simp only [Thread.pending, hb, hst] at he
  have hx : ∃ r', exec c (c.scope m f k) k f b.stmts[f.pc] = .ok r' := by
    simp only [step, hb, hpc, ↓reduceDIte, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · exact ⟨_, ‹_›⟩
  obtain ⟨r', hx⟩ := hx
  obtain ⟨op, sp, x, al, hop, hl, hsx, hX⟩ := exec_atomic (hs f rfl) he ha hx
  refine ⟨op, sp, x, al, ⟨{ f with pc := f.pc + 1 } :: rest, k + 1⟩, hop, hl, hsx,
    fun m₂ hm => ?_⟩
  have hsc : c.scope m₂ f k = { c.scope m f k with mem := m₂ } := rfl
  simp only [step, hb, hpc, ↓reduceDIte, hsc, hX m₂ hm]
  cases m₂.update c.prog.layout c.who sp (.int (8 * e.len)) op x e.ptr al <;> rfl

/-- `exec_atomic` for grids: for every closed grid and contexts, a step of thread `n` that gives
a grid and would log an atomic access `e` is, from every grid with `n`'s status and a memory with
`g`'s shape at its known numbers, the update of type `.int (8 * e.len)` at `e`'s pointer by `e`'s
operation with a scalar operand in that grid's memory, then `n` at one thread `t'`. -/
theorem Grid.advance_atomic {c : Nat → Ctx} {g g' : Grid} {n : Nat} {e : Access}
    (hg : g.Closed c) (h : g.advance c n = .ok (some g')) (he : .access e ∈ g.pending c n)
    (ha : e.atomic.isSome) :
    ∃ op sp x al t', e.atomic = some op ∧ 0 < e.len ∧ x.Scalar (8 * e.len) ∧ ∀ g₂ : Grid,
      g₂.threads[n]? = g.threads[n]? → g.mem.SameShape g.mem.Known g₂.mem →
      g₂.advance c n = (g₂.mem.update (c n).prog.layout (c n).who sp (.int (8 * e.len)) op x
        e.ptr al >>= fun m' =>
          pure (some { threads := g₂.threads.set! n (.run t'), mem := m' })) := by
  obtain ⟨t, ht, -⟩ := Grid.advance_pending h
  simp only [Grid.pending, ht] at he
  have hr : ∃ r, step (c n) t g.mem = .ok r := by
    unfold Grid.advance at h
    simp only [ht, bind, Except.bind] at h
    split at h
    · cases h
    · exact ⟨_, ‹_›⟩
  obtain ⟨r, hr⟩ := hr
  obtain ⟨op, sp, x, al, t', hop, h0, hsx, hs⟩ := step_atomic (hg.scope ht fun _ => id) he ha hr
  refine ⟨op, sp, x, al, t', hop, h0, hsx, fun g₂ h₂ hm => ?_⟩
  unfold Grid.advance
  simp only [h₂, ht, hs _ hm]
  cases g₂.mem.update (c n).prog.layout (c n).who sp (.int (8 * e.len)) op x e.ptr al <;> rfl

/-- **The diamond's case of two exempt atomics.** For every closed grid, contexts and threads
`n ≠ k` whose steps from `g` give `gₙ` and `gₖ`: if a pending access of `n` and one of `k` are by
`atomicrmw`s of one operation at the same pointer and size (which includes every pair
`Access.conflict` exempts), then `k`'s step from `gₙ` and `n`'s step from `gₖ` succeed and give
grids that are the same (`Grid.Same`). Both steps are updates (`Grid.advance_atomic`) of one type at
one pointer, which commute (`Mem.update_comm`). -/
theorem Grid.advance_atomic_comm {c : Nat → Ctx} {g gn gk : Grid} {n k : Nat} (hg : g.Closed c)
    (hnk : n ≠ k) (hn : g.advance c n = .ok (some gn)) (hk : g.advance c k = .ok (some gk))
    {a a' : Access} (ha : .access a ∈ g.pending c n) (ha' : .access a' ∈ g.pending c k)
    (hx : a.atomic.isSome) (he : a.atomic = a'.atomic) (hp : a.ptr = a'.ptr)
    (hl : a.len = a'.len) :
    ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨op, sp, x, al, tn, hop, h0, -, hN⟩ := Grid.advance_atomic hg hn ha hx
  obtain ⟨op', sp', x', al', tk, hop', -, -, hK⟩ := Grid.advance_atomic hg hk ha' (he ▸ hx)
  obtain rfl : op' = op := Option.some.inj (hop'.symm.trans (he.symm.trans hop))
  rw [← hp, ← hl] at hK
  have kn := (hN g rfl fun _ _ => rfl).symm.trans hn
  have kk := (hK g rfl fun _ _ => rfl).symm.trans hk
  obtain ⟨mn, hmn, kn⟩ := Except.bind_eq_ok.1 kn
  obtain ⟨mk, hmk, kk⟩ := Except.bind_eq_ok.1 kk
  cases kn
  cases kk
  obtain ⟨m₁₂, m₂₁, h₁₂, h₂₁, hb, hnx, htr⟩ := Mem.update_comm (by omega) hmn hmk
  refine ⟨_, _, (hK _ (Array.getElem?_setIfInBounds_ne hnk)
      ((Grid.advance_keeps hn).sameShape fun _ hb hn => hb.below hn)).trans (by rw [h₁₂]; rfl),
    (hN _ (Array.getElem?_setIfInBounds_ne hnk.symm)
      ((Grid.advance_keeps hk).sameShape fun _ hb hn => hb.below hn)).trans (by rw [h₂₁]; rfl),
    Array.setIfInBounds_comm _ _ hnk, hb, hnx, htr⟩

/-- **A step's atomics commute.** For every closed grid, contexts and thread `n` whose step from
`g` gives a grid: every operation of an `atomicrmw` among `n`'s pending accesses commutes
(`RmwOp.commutes`). The step is that operation's update (`Grid.advance_atomic`), and an update
that succeeds is by a commuting operation (`rmw_commutes`). -/
theorem Grid.advance_commutes {c : Nat → Ctx} {g g' : Grid} {n : Nat} {e : Access} {op : RmwOp}
    (hg : g.Closed c) (h : g.advance c n = .ok (some g')) (he : .access e ∈ g.pending c n)
    (ho : e.atomic = some op) : op.commutes = true := by
  obtain ⟨op', sp, x, al, t', hop, -, -, hX⟩ := Grid.advance_atomic hg h he (by rw [ho]; rfl)
  obtain rfl : op' = op := Option.some.inj (hop.symm.trans ho)
  obtain ⟨m', hm, -⟩ := Except.bind_eq_ok.1 ((hX g rfl fun _ _ => rfl).symm.trans h)
  obtain ⟨_, _, _, _, -, -, -, hr, -⟩ := Mem.update_eq_ok.1 hm
  exact rmw_commutes hr

/-! ## The two-thread case of the diamond -/

/-- Accesses that overlap only if neither writes do not conflict. -/
theorem Access.conflict_eq_false {a e : Access}
    (h : a.overlaps e = true → a.write = false ∧ e.write = false) : a.conflict e = false := by
  unfold Access.conflict
  cases hov : a.overlaps e
  · rfl
  · obtain ⟨h₁, h₂⟩ := h hov
    simp [h₁, h₂]

/-- **The two-thread case of the diamond** (docs/proofs/schedule-owned.md, step 5). For every
closed grid `g` whose threads own their frames' allocas, contexts `c`, and threads `n` and `k`
with different thread numbers in their contexts (so `n ≠ k`), whose steps from `g` give `gₙ` and
`gₖ`: if no access among either's pending accesses (`Grid.pending`) conflicts with one among the
other's (`Access.conflict`), then `k`'s step from `gₙ` and `n`'s step from `gₖ` give grids that
are the same (`Grid.Same`): the same threads, blocks and `next`, and traces the same up to the
order of independent events. Either no write of one overlaps an access of the other, and the two
steps' changes are apart (`Mem.run_comm`), or two of the accesses are by `atomicrmw`s of one
commuting operation on the same bytes (`Grid.advance_atomic_comm`). -/
theorem Grid.advance_comm {c : Nat → Ctx} {g gn gk : Grid} {n k : Nat} (hg : g.Closed c)
    (ho : g.Owns c) (hw : (c n).who.thread ≠ (c k).who.thread)
    (hn : g.advance c n = .ok (some gn)) (hk : g.advance c k = .ok (some gk))
    (hW : ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
      a.conflict a' = false) :
    ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧ g₁.Same g₂ := by
  have hnk : n ≠ k := fun e => hw (by rw [e])
  by_cases hx : ∃ a a', .access a ∈ g.pending c n ∧ .access a' ∈ g.pending c k ∧
      a.overlaps a' = true ∧ (a.write || a'.write) = true
  · obtain ⟨a, a', ha, ha', hov, hwr⟩ := hx
    have hE : (a.atomic.any RmwOp.commutes && a.atomic == a'.atomic && a.ptr == a'.ptr &&
        a.len == a'.len) = true := by
      have hc := hW a a' ha ha'
      revert hc
      unfold Access.conflict
      rw [hov, hwr]
      cases (a.atomic.any RmwOp.commutes && a.atomic == a'.atomic && a.ptr == a'.ptr &&
        a.len == a'.len) <;> decide
    simp only [Bool.and_eq_true, beq_iff_eq] at hE
    exact Grid.advance_atomic_comm hg hnk hn hk ha ha' (Option.isSome_of_any hE.1.1.1) hE.1.1.2
      hE.1.2 hE.2
  replace hW : ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
      a.overlaps a' = true → a.write = false ∧ a'.write = false := fun a a' ha ha' hov => by
    simpa using fun h => hx ⟨a, a', ha, ha', hov, h⟩
  obtain ⟨t, ht, hpn⟩ := Grid.advance_pending hn
  obtain ⟨t', ht', hpk⟩ := Grid.advance_pending hk
  simp only [Grid.pending, ht, ht'] at hW
  obtain ⟨s, opsn, han, rfl, advn⟩ := Grid.advance_agree
    (S := fun b => g.mem.Known b ∨ b = g.mem.fresh (c n).who.thread t.k) ht
    (hg.scope ht fun _ => Or.inl) (Or.inr rfl) (Grid.advance_agree_other (t' := t) ho hw.symm ht'
      (fun a a' ha ha' hov => (hW a' a ha' ha ((Access.overlaps_comm a' a).trans hov)).2) hk) hn
  obtain ⟨s', opsk, hak, rfl, advk⟩ := Grid.advance_agree
    (S := fun b => g.mem.Known b ∨ b = g.mem.fresh (c k).who.thread t'.k) ht'
    (hg.scope ht' fun _ => Or.inl) (Or.inr rfl) (Grid.advance_agree_other (t' := t') ho hw ht
      (fun a a' ha ha' hov => (hW a a' ha ha' hov).1) hn) hk
  have mem {ops : List Mem.Op} {P : List Event}
      (hp : (g.mem.run ops).trace = P ++ g.mem.trace) : ∀ e ∈ ops.filterMap Mem.Op.event, e ∈ P :=
    fun e he => by
      rw [← List.append_cancel_right ((Mem.run_trace _ _).symm.trans hp)]
      exact List.mem_reverse.2 he
  have hL {j : Nat} {u : Thread} (hu : g.threads[j]? = some (.run u)) (b : Nat)
      (hb : g.mem.Owned (c j).who.thread b ∨ ∃ f ∈ u.frames, b ∈ f.allocas) :
      g.mem.Owned (c j).who.thread b :=
    hb.elim id fun ⟨f, hf, hb⟩ => ho j _ hu f hf b hb
  have hr := g.mem.run_comm fun o₁ h₁ o₂ h₂ => (han o₁ h₁).apart hw (hL ht) (hL ht')
    (fun b e e' => hw (Mem.fresh_inj (e.symm.trans e')))
    (fun a a' ha ha' hov => .inl (hW a a' (mem hpn _ ha) (mem hpk _ ha') hov).1) (hak o₂ h₂)
  exact ⟨_, _, advk _ ((Array.getElem?_setIfInBounds_ne hnk).trans ht') rfl,
    advn _ ((Array.getElem?_setIfInBounds_ne hnk.symm).trans ht) rfl,
    Array.setIfInBounds_comm _ _ hnk, hr.1, hr.2.1, hr.2.2⟩

/-- **The two-thread case of the diamond from the start**: for every program, kernel, launch,
argument values, address choice and oracle, on a caller's memory every pointer byte of whose
blocks names a number below `next` or with a block, in every grid `g'` reachable from the start's
grid, the steps of two different threads `n` and `k` that succeed, no pending access of either
of which conflicts with one of the other (`Access.conflict`), succeed in the other order too and
give the same grid (`Grid.Same`). By `Grid.advance_comm`: `g'` is closed
(`Grid.start_reach_closed`), its threads own their allocas (`Grid.start_owns`, `Grid.reach_owns`),
and the start gives `n` and `k` their own numbers (`Grid.start_ctx`). -/
theorem Grid.start_reach_comm {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' gn gk : Grid} {c : Nat → Ctx}
    {n k : Nat} (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') (hnk : n ≠ k)
    (hn : g'.advance c n = .ok (some gn)) (hk : g'.advance c k = .ok (some gk))
    (hW : ∀ a a', .access a ∈ g'.pending c n → .access a' ∈ g'.pending c k →
      a.conflict a' = false) :
    ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧ g₁.Same g₂ :=
  Grid.advance_comm (Grid.start_reach_closed h hm hr) (Grid.reach_owns hr (Grid.start_owns h c))
    (by rw [(Grid.start_ctx h n).2.1, (Grid.start_ctx h k).2.1]; exact hnk) hn hk hW

/-- **The two-thread case of the diamond under a discipline, from the start**:
`Grid.start_reach_comm` with its premise on accesses from `Grid.pending_apart`. For every
program, kernel, launch, arguments, address choice and oracle, on a caller's memory every pointer
byte of whose blocks names a number below `next` or with a block, every discipline `(T, own)`, and
every grid reachable from the start's grid: the steps of two threads with different tiles that
succeed, each of whose pending accesses follows the discipline or is to a block that its thread
owns, succeed in the other order too and give the same grid (`Grid.Same`). The start gives
thread `n` the number `n` (`Grid.start_ctx`). -/
theorem Grid.start_reach_comm_of_owned {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' gn gk : Grid} {c : Nat → Ctx}
    {n k : Nat} (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') (hX : own n ≠ own k)
    (hn : g'.advance c n = .ok (some gn)) (hk : g'.advance c k = .ok (some gk))
    (hH : ∀ p ∈ [n, k], ∀ a, .access a ∈ g'.pending c p →
      Owned T own a ∨ g'.mem.Owned p a.ptr.block) :
    ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧ g₁.Same g₂ :=
  Grid.start_reach_comm h hm hr (fun e => hX (by rw [e])) hn hk fun a a' ha ha' =>
    Access.conflict_eq_false (Grid.pending_apart hn hk
      (by rw [(Grid.start_ctx h n).2.1, (Grid.start_ctx h k).2.1]; exact hX)
      (fun p hp a ha => by rw [(Grid.start_ctx h p).2.1]; exact hH p hp a ha) a a' ha ha')

end MojoProof.Sem
