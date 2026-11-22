import MojoProof.Sem.Closed
import MojoProofTest.Close
import MojoProofTest.Pending

/-!
# Instances and negative twins of C1's closed-grid invariant (`Grid.Closed`) and W5's other part

The grid of one thread holding a pointer to block 1 in register 0 (`Pending.threadAt 1`, at a
`load i32` through a GEP of it), on the memory of block 1 with `next = 2`, in the context
`Pending.ctx0` (no globals), is closed (`grid1_closed`). For every launch, every grid reachable
from it is closed (`Grid.reach_closed`), and the thread has there the pending accesses it has on
the first memory (`Grid.pending_reach`) (`closed`). The twin: a grid whose thread 1 holds a pointer
to block 2, which is `next` and has no block, beside a thread 0 at `alloca i64`, is not closed;
for every launch, thread 0's step makes block 2 (`Mem.fresh`), after which thread 1 has an access
pending that it did not have, so `Grid.pending_reach` needs its premise (`pending_twin`).
W5's other part: the launch of `ret void` on `Close.mem (some 5)` starts, and in every grid
reachable from its grid every waiting thread is at its call (`atCalls`, by
`Grid.start_reach_atCalls`, for every address choice and oracle). The twin: a grid whose thread
waits at barrier 0 at the `ret` of an empty block (`Pending.atBarrier`) does not have its waiting
threads at their calls, in any context (`atCalls_twin`); its barrier still completes
(`Pending.fire`). C1 and L1c from the start: that launch's grid, and every grid reachable from
it, is closed, and its thread 0 keeps its pending accesses there (`start_closed`, by
`Grid.start_reach_closed` and `Grid.start_pending`, for every address choice and oracle). The twin
of the premise on the pointer bytes: on a memory with `next = 2` and one block 5 holding a pointer
to block 100, the start's check passes and the launch starts, but its grid is not closed
(`start_twin`).
Statements about these grids and these launches, not about every grid.
-/

namespace MojoProofTest.Closed

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending

/-- The memory of block 1 of 8 live bytes, with `next = 2`. -/
def mem1 : Mem := { memOf [(1, blk 8 true)] with next := 2 }

/-- The grid of the one thread `threadAt 1` on `mem1`. -/
def grid1 : Grid := { threads := #[.run (threadAt 1)], mem := mem1 }

/-- `grid1` is closed: null and block 1 are below `next`, the block holds no pointer byte and
`ctx0` has no globals. -/
theorem grid1_closed : grid1.Closed (fun _ => ctx0) where
  null := Or.inl (by decide)
  threads n s hs := by
    rcases n with _ | n
    · simp [grid1] at hs
      subst hs
      intro f hf r v hr
      simp only [threadAt, List.mem_singleton] at hf
      subst hf
      simp only [frameAt] at hr
      split at hr
      · cases hr
        exact Or.inl (by decide)
      · cases hr
    · simp [grid1] at hs
  bytes c b i p j hc _ hp := by
    simp only [grid1, mem1, memOf, List.lookup] at hc
    split at hc
    · cases hc
      cases hp
    · cases hc
  globals _ _ _ h := by cases h

/-- C1 on `grid1`, for every launch: every grid reachable from it is closed and gives the thread
the pending accesses it has on `mem1`. -/
theorem closed (L : Launch) :
    ∀ g', Relation.ReflTransGen (Grid.Step L (fun _ => ctx0)) grid1 g' →
      g'.Closed (fun _ => ctx0) ∧
        (threadAt 1).pending ctx0 g'.mem = (threadAt 1).pending ctx0 mem1 :=
  fun _ h => ⟨Grid.reach_closed h grid1_closed, Grid.pending_reach (n := 0) grid1_closed h rfl⟩

/-- `alloca i64`, its result unnamed. -/
def alloc64 : Stmt := { res := none, inst := .alloca (.int 64) none none }

/-- Thread 0 at `alloca i64` and thread 1 holding a pointer to block 2 (`threadAt 2`), on
`mem1`. -/
def grid2 : Grid := { threads := #[.run (thread #[alloc64]), .run (threadAt 2)], mem := mem1 }

/-- The twin: `grid2` is not closed, as block 2 is `next` and has no block. For every launch,
thread 0's step makes block 2, after which thread 1 has its `load` pending, which it does not have
on `mem1`: in a grid that is not closed, a step of one thread can change the pending accesses of
another, so `Grid.pending_reach` needs `Grid.Closed`. -/
theorem pending_twin (L : Launch) :
    ¬ grid2.Closed (fun _ => ctx0) ∧ (threadAt 2).pending ctx0 mem1 = [] ∧
      ∃ g', Grid.Step L (fun _ => ctx0) grid2 g' ∧
        (threadAt 2).pending ctx0 g'.mem = [.access ⟨⟨0, 0⟩, ⟨2, 4⟩, 4, false, none, false⟩] :=
  ⟨fun h => by
    have := h.threads 1 _ rfl (frameAt 2) List.mem_cons_self 0 _ rfl
    simp [Val.NamesIn, Mem.Known, grid2, mem1, memOf] at this,
   rfl, _, ⟨0, .inl rfl⟩, rfl⟩

/-- W5's other part from the start, for every address choice and oracle: the launch of
`ret void` on `Close.mem (some 5)` starts, and every grid reachable from its grid has its waiting
threads at their calls. -/
theorem atCalls (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (Program.ofFunc retFn) retFn .one [] (Close.mem (some 5)) ch oracle =
      .ok (g, c) ∧ ∀ g', Relation.ReflTransGen (Grid.Step .one c) g g' → g'.AtCalls c := by
  obtain ⟨g, c, h⟩ : ∃ g c, Grid.start (Program.ofFunc retFn) retFn .one []
      (Close.mem (some 5)) ch oracle = .ok (g, c) := ⟨_, _, rfl⟩
  exact ⟨g, c, h, fun _ => Grid.start_reach_atCalls h⟩

/-- `Close.mem e` has no pointer byte, for every `e`. -/
theorem mem_bytesIn (e : Option Nat) : (Close.mem e).BytesIn (Close.mem e).Known :=
  fun c b i p j hc _ hp => by
    simp only [Close.mem] at hc
    split at hc
    · cases hc
      cases hp
    · cases hc

/-- C1 and L1c from the start, for every address choice and oracle: the launch of `ret void` on
`Close.mem (some 5)` starts, and every grid reachable from its grid is closed and gives thread 0
the pending accesses it has at the start (`Grid.start_reach_closed`, `Grid.start_pending`). -/
theorem start_closed (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c t, Grid.start (Program.ofFunc retFn) retFn .one [] (Close.mem (some 5)) ch oracle =
      .ok (g, c) ∧ g.threads[0]? = some (.run t) ∧
        ∀ g', Relation.ReflTransGen (Grid.Step .one c) g g' →
          g'.Closed c ∧ t.pending (c 0) g'.mem = t.pending (c 0) g.mem := by
  obtain ⟨g, c, t, h, ht⟩ : ∃ g c t, Grid.start (Program.ofFunc retFn) retFn .one []
      (Close.mem (some 5)) ch oracle = .ok (g, c) ∧ g.threads[0]? = some (.run t) :=
    ⟨_, _, _, rfl, rfl⟩
  exact ⟨g, c, t, h, ht, fun _ hr => ⟨Grid.start_reach_closed h (mem_bytesIn _) hr,
    Grid.start_pending h (mem_bytesIn _) hr ht⟩⟩

/-- A block of `Close.blk`'s shape whose byte 0 is a pointer to block 100. -/
def blk100 : MojoProof.Sem.Block :=
  { Close.blk with bytes := fun i => if i = 0 then .ptr ⟨100, 0⟩ 0 else .undef }

/-- A memory with `next = 2` and one block, 5 (from `next` on), which is `blk100`: its byte 0
points to block 100, which does not exist. -/
def mem100 : Mem := { blocks := fun c => if c = 5 then some blk100 else none, next := 2 }

/-- The twin of `Grid.start_closed`'s premise on the pointer bytes: `mem100` passes the start's
check, which reads the bytes of
the blocks below `next` only, and the launch of `ret void` on it starts, but its grid is not
closed, for every address choice and oracle: block 5 is kept (`Grid.start_blocks`) and names
block 100, which is from the start's `next` on and has no block. So `Grid.start_closed` needs its
premise on the bytes. -/
theorem start_twin (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    mem100.checkClosed [] = .ok () ∧
      ∃ g c, Grid.start (Program.ofFunc retFn) retFn .one [] mem100 ch oracle = .ok (g, c) ∧
        ¬ g.Closed c := by
  have h : Grid.start (Program.ofFunc retFn) retFn .one [] mem100 ch oracle = .ok (_, _) := rfl
  refine ⟨rfl, _, _, h, fun hg => ?_⟩
  have := hg.bytes 5 blk100 0 _ _ (Grid.start_blocks h rfl) (by decide) rfl
  simp [Mem.Known, Mem.compact_eq, Mem.set, mem100] at this

/-- The twin: the thread of `Pending.atBarrier` waits at barrier 0 at the `ret` of an empty
block, not at a call, so its grid does not have its waiting threads at their calls, in any
context. -/
theorem atCalls_twin (c : Nat → Ctx) :
    ¬ ({ threads := #[atBarrier], mem := {} } : Grid).AtCalls c := by
  intro h
  obtain ⟨f, rest, b, st, -, -, -, -, hf, hb, hs, -⟩ := h 0 _ rfl
  simp only [thread, List.cons.injEq] at hf
  obtain ⟨rfl, -⟩ := hf
  simp [kernel] at hb
  subst hb
  simp at hs

end MojoProofTest.Closed
