import MojoProof.Sem.Schedule
import MojoProofTest.Same

/-!
# Instances and twins of L1a, L1c and W5's block part

For every context, a thread at the start of a kernel `@k` whose one block is `alloca i32` (its
result unnamed) and `ret void`: on the empty memory it has no pending access, and its step
succeeds and logs nothing (`alloca`, by `step_pending`). A thread at `load i32, ptr null` has the
load's access pending: by its thread, at null, of the store size of `i32`, a read (`load`). The
twin: on the empty memory that step faults (an access to no block) and so logs nothing; the
premise of `step_pending` that the step succeeds is needed (`load_twin`). Statements about one
thread for every context, not about a kernel. On a grid of that one `alloca` thread, for every
context, the thread's step succeeds and logs nothing (`grid`, by `Grid.advance_pending`); the
twin: a finished thread takes no step, so the theorem says nothing of it (`grid_twin`). For every
context, the one thread of a block at barrier 0 completes it, and the fire logs one `.barrier` of
block 0 (`fire`, by `Grid.fire_trace`); the twin: in a block of two, one thread at the barrier and
one running, the barrier does not complete (`fire_twin`).
MojoProofTest/Eval.lean `pendingTests` checks `step_pending` on one launch.

No step reads the trace: for every context and every trace, the grid of the one thread at
`load i32, ptr null` faults as it does on the empty memory (`retrace`, by
`Grid.advance_retrace`). Grids of the `alloca` thread whose traces are two writes by two threads in
either order are the same (`Grid.Same`), and for every launch and context the step from the first
has a step from the second to a grid the same as its result (`bisim`, by `Grid.Same.step`); the
grid of the `load` thread with either trace faults (`faults`, by `Grid.Same.faults`). The twin: a
grid with the same memory whose one thread has returned, not the same as the `alloca` grid, has no
step (`bisim_twin`).

Pending accesses read only the shape of the named blocks (L1c): for every context whose globals
name no block 5, a thread at `load i32, ptr (getelementptr inbounds i32, ptr %0, i64 1)` with a
pointer to block 1 in register 0 has the same pending accesses on a memory with block 1 live and
on one with block 1 dead and a block 5, and its GEP operand evaluates the same (`shape`, by
`Thread.pending_shape` and `evalTV_shape`, `evalTVs_shape`). The twins, in one
context: with block 1 of 8 bytes the access at offset 4 is pending and with block 1 of no bytes
none is (the shapes differ), and a thread with a pointer to block 5 has the access pending when
block 5 exists and none when it does not (the thread names the block where the memories differ)
(`shape_twin`).

Memory operations keep every block (W5 for the memory): on the memory of block 1, a store to it,
making it dead and an allocation at number 2 keep every block, and the stored memory has the same
shape at block 1 (`keeps`, by `Mem.store_keeps`, `Mem.setLive_keeps`, `Mem.alloc_keeps` and
`Mem.Keeps.sameShape`). The twins: an allocation at number 1, which is in use, does not keep block
1 (`keeps_twin`), and with `next = 3` an allocation at the free number 2, below `next`, does not
keep the memory either (`keeps_twin_below`). On the grid of one thread at `alloca i32` whose
memory has block 5, the step allocates block 1 and keeps block 5 (`reach_keeps`, by
`Grid.reach_keeps`). The twin: on a memory whose block 1 exists the same step is refused, so no
step replaces a block (`reach_keeps_twin`).
-/

namespace MojoProofTest.Pending

open MojoProof.Sem MojoProof.LLVM
open MojoProofTest.Same (w)

/-- A kernel `@k` with one block: statements `sts`, then `ret void`. -/
def kernel (sts : Array Stmt) : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #[], blocks := #[⟨0, sts, .ret none⟩] }

/-- A thread at the start of `kernel sts`. -/
def thread (sts : Array Stmt) : Thread :=
  ⟨[{ fn := kernel sts, label := 0, pc := 0, regs := fun _ => none, prods := fun _ => none,
      allocas := [], dest := none }], 0⟩

/-- `alloca i32`, its result unnamed. -/
def alloc : Stmt := { res := none, inst := .alloca (.int 32) none none }

/-- `load i32, ptr null`, its result unnamed. -/
def loadNull : Stmt := { res := none, inst := .load false (.int 32) ⟨.ptr 0, .null⟩ none }

/-- A step of `alloca` logs nothing, as it has no pending access. -/
theorem alloca (c : Ctx) : ∃ t' m', step c (thread #[alloc]) {} = .ok (.next t' m') ∧
    (thread #[alloc]).pending c {} = [] ∧ m'.trace = [] := by
  refine ⟨_, _, rfl, rfl, ?_⟩
  exact step_pending (c := c) (t := thread #[alloc]) (m := {}) rfl

/-- A `load` through null has its access pending. -/
theorem load (c : Ctx) : (thread #[loadNull]).pending c {} =
    [.access ⟨c.who, ⟨0, 0⟩, c.prog.layout.stored (.int 32), false, none, false⟩] := rfl

/-- The twin: that `load`'s step faults, so it logs nothing. -/
theorem load_twin (c : Ctx) : step c (thread #[loadNull]) {} = .error (.ub "access to no block") :=
  rfl

/-- A grid of one `alloca` thread, for every context: its step succeeds and logs nothing, by
`Grid.advance_pending`. -/
theorem grid (c : Nat → Ctx) :
    ∃ g', ({ threads := #[.run (thread #[alloc])], mem := {} } : Grid).advance c 0 = .ok (some g') ∧
      g'.mem.trace = [] := by
  refine ⟨_, rfl, ?_⟩
  obtain ⟨t, ht, h⟩ := Grid.advance_pending (c := c)
    (g := { threads := #[.run (thread #[alloc])], mem := {} }) (n := 0) rfl
  cases ht
  exact h

/-- A launch of one block of `size` threads. -/
def launch (size : Nat) : Launch := ⟨fun _ => 1, fun d => if d = .x then size else 1, 0⟩

/-- A thread of `kernel #[]` waiting at barrier 0. -/
def atBarrier : Status := .wait (thread #[]) .barrier [.bits 32 0] (kernel #[])

/-- For every context, the one thread of a block waiting at barrier 0: the barrier completes and
logs one `.barrier` of block 0, by `Grid.fire_trace`. -/
theorem fire (c : Nat → Ctx) :
    ∃ g', ({ threads := #[atBarrier], mem := {} } : Grid).fire (launch 1) c 0 = .ok (some g') ∧
      g'.mem.trace = [.barrier 0] := by
  refine ⟨_, rfl, ?_⟩
  obtain ⟨t, i, args, r, ht, h⟩ := Grid.fire_trace (L := launch 1) (c := c)
    (g := { threads := #[atBarrier], mem := {} }) (n := 0) rfl
  cases ht
  exact h

/-- The twin: in a block of two threads, one at barrier 0 and one still running, the barrier does
not complete, so `Grid.fire_trace` says nothing of it. -/
theorem fire_twin (c : Nat → Ctx) :
    ({ threads := #[atBarrier, .run (thread #[])], mem := {} } : Grid).fire (launch 2) c 0 =
      .ok none := rfl

/-- The twin: a finished thread takes no step. -/
theorem grid_twin (c : Nat → Ctx) :
    ({ threads := #[.done], mem := {} } : Grid).advance c 0 = .ok none := rfl

/-- The grid of one thread at `sts`, on the memory of trace `tr`. -/
def grid1 (sts : Array Stmt) (tr : List Event) : Grid :=
  { threads := #[.run (thread sts)], mem := { trace := tr } }

/-- For every context and every trace, the `load` through null faults as on the empty memory: the
step reads no trace (`Grid.advance_retrace`). -/
theorem retrace (c : Nat → Ctx) (tr : List Event) :
    (grid1 #[loadNull] tr).advance c 0 = .error (.ub "access to no block") :=
  (Grid.advance_retrace c (grid1 #[loadNull] []) tr 0).trans rfl

/-- Grids of one thread at `sts` whose traces are writes by threads 1 and 2 in either order are
the same. -/
theorem same (sts : Array Stmt) : (grid1 sts [w 1 0, w 2 4]).Same (grid1 sts [w 2 4, w 1 0]) :=
  ⟨rfl, rfl, rfl, Trace.Same.swap₁ rfl []⟩

/-- For every launch and context, the step of the `alloca` grid with one trace has a step of the
`alloca` grid with the other to a grid the same as its result (`Grid.Same.step`). -/
theorem bisim (L : Launch) (c : Nat → Ctx) :
    ∃ g₁ g₂, Grid.Step L c (grid1 #[alloc] [w 1 0, w 2 4]) g₁ ∧
      Grid.Step L c (grid1 #[alloc] [w 2 4, w 1 0]) g₂ ∧ g₁.Same g₂ := by
  obtain ⟨g₂, h₂, h⟩ := (same #[alloc]).step (L := L) (c := c) ⟨0, .inl rfl⟩
  exact ⟨_, g₂, ⟨0, .inl rfl⟩, h₂, h⟩

/-- For every launch and context, the `load` grid with either trace faults (`Grid.Same.faults`). -/
theorem faults (L : Launch) (c : Nat → Ctx) : (grid1 #[loadNull] [w 2 4, w 1 0]).Faults L c :=
  (same #[loadNull]).faults.1 ⟨0, _, .inl rfl⟩

/-- The twin: the grid with the memory of `bisim`'s first grid whose one thread has returned is
not the same as it, and has no step. -/
theorem bisim_twin (L : Launch) (c : Nat → Ctx) (g : Grid) :
    ¬ Grid.Step L c { threads := #[.done], mem := { trace := [w 1 0, w 2 4] } } g :=
  Grid.Done.final (by simp [Grid.Done])

/-- `getelementptr inbounds i32, ptr %0, i64 1`, a pointer operand. -/
def gep1 : TValue :=
  ⟨.ptr 0, .gep { inbounds := true } (.int 32) ⟨.ptr 0, .loc 0⟩ [⟨.int 64, .int 1⟩]⟩

/-- `load i32, ptr (getelementptr inbounds i32, ptr %0, i64 1)`, its result unnamed. -/
def loadGep : Stmt := { res := none, inst := .load false (.int 32) gep1 none }

/-- A frame at the start of `kernel #[loadGep]` whose register 0 holds a pointer to block `b`. -/
def frameAt (b : Nat) : Frame :=
  { fn := kernel #[loadGep], label := 0, pc := 0,
    regs := fun n => if n = 0 then some (.ptr ⟨b, 0⟩) else none, prods := fun _ => none,
    allocas := [], dest := none }

/-- A thread of the one frame `frameAt b`. -/
def threadAt (b : Nat) : Thread := ⟨[frameAt b], 0⟩

/-- A block of `size` undefined bytes in space 0 at address 0, of every thread, live or not. -/
def blk (size : Nat) (live : Bool) : MojoProof.Sem.Block :=
  { space := 0, size, live, readOnly := false, owner := .all, bytes := fun _ => .undef, addr := 0,
    gaddr := 0 }

/-- The memory whose blocks are `bs`. -/
def memOf (bs : List (Nat × MojoProof.Sem.Block)) : Mem := { blocks := fun b => bs.lookup b }

/-- A memory with block 1 live and one with block 1 dead and a block 5 have the same shape at
every number but 5. -/
theorem same5 :
    (memOf [(1, blk 8 true)]).SameShape (· ≠ 5) (memOf [(1, blk 8 false), (5, blk 4 true)]) := by
  intro b hb
  by_cases h1 : b = 1
  · subst h1
    rfl
  · have h1 : (b == 1) = false := beq_eq_false_iff_ne.2 h1
    have h5 : (b == 5) = false := beq_eq_false_iff_ne.2 hb
    simp only [memOf, List.lookup, h1, h5]

/-- For every context whose globals name no block 5, the scope of `frameAt 1` names no block 5. -/
theorem names5 (c : Ctx) (hg : ∀ g p, c.globals g = some p → p.block ≠ 5) (m : Mem) (k : Nat) :
    (c.scope m (frameAt 1) k).NamesIn (· ≠ 5) := by
  refine ⟨by decide, fun n v h => ?_, hg⟩
  simp only [Ctx.scope, frameAt] at h
  split at h
  · cases h
    exact (by decide : (1 : Nat) ≠ 5)
  · cases h

/-- For every context whose globals name no block 5: on those two memories, the GEP evaluates to
the same value, and so do the list of it and its base (`evalV_shape` and its mutual parts), and
the pending accesses of `threadAt 1` are the same (`Thread.pending_shape`). -/
theorem shape (c : Ctx) (hg : ∀ g p, c.globals g = some p → p.block ≠ 5) :
    let s := c.scope (memOf [(1, blk 8 true)]) (frameAt 1) 0
    let m' := memOf [(1, blk 8 false), (5, blk 4 true)]
    evalTV { s with mem := m' } gep1 = evalTV s gep1 ∧
      evalTVs { s with mem := m' } [gep1, ⟨.ptr 0, .loc 0⟩] = evalTVs s [gep1, ⟨.ptr 0, .loc 0⟩] ∧
      (threadAt 1).pending c m' = (threadAt 1).pending c (memOf [(1, blk 8 true)]) :=
  ⟨(evalTV_shape (names5 c hg _ _) same5 _).1, (evalTVs_shape (names5 c hg _ _) same5 _).1,
    Thread.pending_shape same5 fun f hf => by
      cases hf
      exact names5 c hg _ _⟩

/-- A context of thread 0 of block 0 of `kernel #[loadGep]` with the default layout and no
globals. -/
def ctx0 : Ctx :=
  ⟨.ofFunc (kernel #[loadGep]), fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩

/-- The twins. The premise on shapes is needed: with block 1 of 8 bytes the `load` has its
access pending, at offset 4, and with block 1 of no bytes the GEP steps out of the block, gives
poison, and the `load` has none. The premise on names is needed: a thread holding a pointer to
block 5 has the access pending when block 5 exists and none when it does not, on memories that
agree at every other number. -/
theorem shape_twin :
    (threadAt 1).pending ctx0 (memOf [(1, blk 8 true)]) =
        [.access ⟨⟨0, 0⟩, ⟨1, 4⟩, 4, false, none, false⟩] ∧
      (threadAt 1).pending ctx0 (memOf [(1, blk 0 true)]) = [] ∧
      (threadAt 5).pending ctx0 (memOf [(1, blk 8 true), (5, blk 8 true)]) =
        [.access ⟨⟨0, 0⟩, ⟨5, 4⟩, 4, false, none, false⟩] ∧
      (threadAt 5).pending ctx0 (memOf [(1, blk 8 true)]) = [] :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- W5 for memory operations, on the memory of block 1 of 8 live bytes: a store of the `i32` 7 at
offset 0, making block 1 dead and allocating block 2 keep every block (`Mem.store_keeps`,
`Mem.setLive_keeps`, `Mem.alloc_keeps`), so the stored memory has the shape of the first at block 1
(`Mem.Keeps.sameShape`). -/
theorem keeps :
    let m := memOf [(1, blk 8 true)]
    ∃ m', m.store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7) ⟨1, 0⟩ (some 4) = .ok m' ∧ m.Keeps m' ∧
      m.SameShape (· = 1) m' ∧ m.Keeps (m.setLive 1 false) ∧
      m.Keeps (m.alloc {} 0 4 1 true false .all 0 0 [] (some 2)).1 := by
  intro m
  obtain ⟨m', hs⟩ : ∃ m', m.store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7) ⟨1, 0⟩ (some 4) = .ok m' :=
    ⟨_, rfl⟩
  have h := Mem.store_keeps hs
  exact ⟨m', hs, h, h.sameShape (fun b (hb : b = 1) hn => by subst hb; cases hn),
    Mem.setLive_keeps _ _ _, Mem.alloc_keeps _ _ _ _ _ _ _ _ _ _ _ (by decide) rfl⟩

/-- The twin: an allocation at block 1, whose number is in use, does not keep it (its size goes
from 8 to 4), so `Mem.alloc_keeps` needs its premise that the number has no block. -/
theorem keeps_twin : ¬ (memOf [(1, blk 8 true)]).Keeps
    ((memOf [(1, blk 8 true)]).alloc {} 0 4 1 true false .all 0 0 [] (some 1)).1 := fun h => by
  have := h.blocks 1 (blk 8 true) rfl
  simp [Mem.alloc, Mem.set, Block.shape, blk] at this

/-- The twin of the premise `next ≤ b`: with block 1 and `next = 3`, an allocation at number 2,
which has no block but is below `next`, does not keep the memory, so `Mem.alloc_keeps` needs that
premise too. -/
theorem keeps_twin_below : ¬ ({ memOf [(1, blk 8 true)] with next := 3 } : Mem).Keeps
    (({ memOf [(1, blk 8 true)] with next := 3 } : Mem).alloc {} 0 4 1 true false .all 0 0 []
      (some 2)).1 := fun h => by
  simpa [Mem.alloc, Mem.set] using h.below 2 (by decide) rfl

/-- W5's block part on a grid, for every launch: the grid of one thread at `alloca i32` (thread 0 of
the context `ctx0`) on the memory of block 5 steps to a grid with block 1 (`Mem.fresh`), and that
grid, reachable in one step, keeps block 5 (`Grid.reach_keeps`). -/
theorem reach_keeps (L : Launch) :
    let g : Grid := { threads := #[.run (thread #[alloc])], mem := memOf [(5, blk 8 true)] }
    ∃ g', Grid.Step L (fun _ => ctx0) g g' ∧ (g'.mem.blocks 1).isSome ∧ g.mem.Keeps g'.mem :=
  ⟨_, ⟨0, .inl rfl⟩, rfl, Grid.reach_keeps (L := L) (c := fun _ => ctx0) (.single ⟨0, .inl rfl⟩)⟩

/-- The twin: on the memory of block 1 the same `alloca` is refused, as its number is in use:
the allocation at number 1 would not keep block 1 (`keeps_twin`). -/
theorem reach_keeps_twin :
    ({ threads := #[.run (thread #[alloc])], mem := memOf [(1, blk 8 true)] } : Grid).advance
      (fun _ => ctx0) 0 = .error (.unsupported "alloca number in use") := rfl

end MojoProofTest.Pending
