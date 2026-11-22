import MojoProof.Sem.Writes
import MojoProofTest.Closed

/-!
# An instance and a twin of L1b (`Mem.Changes`)

In the context `Pending.ctx0` (thread 0), on `Closed.mem1` (block 1 of 8 live bytes of every
thread, `next = 2`): the step of a thread at `store i32 7, ptr %0` with a pointer to block 1 in
register 0 succeeds, logs the write of 4 bytes at block 1, offset 0, and changes the memory only
at the bytes that write writes; it changes no liveness, as no block is the thread's and its frame
allocated none, and adds no block but `fresh 0 0` (`store`, by `step_changes`). The twin:
`step_changes` needs that the frames' allocas be in `L`. A thread at the `ret void` of an empty
kernel whose frame lists block 1 among its allocas makes block 1 dead at its return, a change of
liveness at a number outside `L` (`ret_twin`). The allocas invariant: the launch of `ret void` on
`Close.mem (some 5)` starts, and in every grid reachable from its grid every step of a running
thread is `Mem.Changes` with `L` the blocks the thread owns (`changes`, by
`Grid.start_reach_changes`, for every address choice and oracle). The twin: the grid of `returner`
on `Closed.mem1` is not `Grid.Owns`, as block 1 is of every thread (`owns_twin`). Statements about
these threads, grids and this launch, not about every thread.
-/

namespace MojoProofTest.Writes

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending

/-- `store i32 7, ptr %0`. -/
def store7 : Stmt := { res := none, inst := .store false ⟨.int 32, .int 7⟩ ⟨.ptr 0, .loc 0⟩ none }

/-- A thread at `store7` with a pointer to block 1 in register 0. -/
def storer : Thread :=
  ⟨[{ fn := kernel #[store7], label := 0, pc := 0,
      regs := fun n => if n = 0 then some (.ptr ⟨1, 0⟩) else none, prods := fun _ => none,
      allocas := [], dest := none }], 0⟩

/-- Every block of `Closed.mem1` is of every thread. -/
theorem mem1_owner (b : Nat) (x : MojoProof.Sem.Block) (h : Closed.mem1.blocks b = some x) :
    x.owner = .all := by
  simp only [Closed.mem1, memOf, List.lookup] at h
  split at h
  · cases h
    rfl
  · cases h

/-- L1b on a store: the step logs the write of 4 bytes at block 1 and changes the memory only
there, and at no liveness. -/
theorem store :
    ∃ t' m', step ctx0 storer Closed.mem1 = .ok (.next t' m') ∧
      m'.trace = [.access ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩] ∧
      Closed.mem1.Changes (fun _ => False) (· = Closed.mem1.fresh 0 0) m' := by
  obtain ⟨t', m', h⟩ : ∃ t' m', step ctx0 storer Closed.mem1 = .ok (.next t' m') :=
    ⟨_, _, rfl⟩
  refine ⟨t', m', h, (step_pending (r := .next t' m') h).trans rfl,
    step_changes (L := fun _ => False) (N := (· = Closed.mem1.fresh 0 0)) (r := .next t' m')
      (fun b x hx ho => ?_) (by simp [storer]) rfl h⟩
  rw [mem1_owner b x hx] at ho
  cases ho

/-- A thread at the `ret void` of an empty kernel whose frame lists block 1 among its allocas. -/
def returner : Thread :=
  ⟨[{ fn := kernel #[], label := 0, pc := 0, regs := fun _ => none, prods := fun _ => none,
      allocas := [1], dest := none }], 0⟩

/-- The twin: the return of `returner` makes block 1 dead, though no thread owns it, so the
memory changes at the liveness of a block outside `fun _ => False`. -/
theorem ret_twin :
    ∃ m', step ctx0 returner Closed.mem1 = .ok (.done m') ∧
      ¬ Closed.mem1.Changes (fun _ => False) (fun _ => False) m' := by
  refine ⟨_, rfl, fun h => ?_⟩
  obtain ⟨d, -, ho⟩ := h.old
  obtain ⟨x', hx', -, -, hl | ⟨hl, -⟩⟩ := ho 1 _ rfl
  · exact hl
  · cases hx'
    cases hl

/-- L1b from the start, for every address choice and oracle: the launch of `ret void` on
`Close.mem (some 5)` starts, and in every grid reachable from its grid a step of a running thread
changes the memory only at the blocks the thread owns, the bytes it writes and its fresh block. -/
theorem changes (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (Program.ofFunc retFn) retFn .one [] (Close.mem (some 5)) ch oracle =
      .ok (g, c) ∧ ∀ g₁ g₂ n t, Relation.ReflTransGen (Grid.Step .one c) g g₁ →
        g₁.threads[n]? = some (.run t) → g₁.advance c n = .ok (some g₂) →
        g₁.mem.Changes (g₁.mem.Owned (c n).who.thread)
          (· = g₁.mem.fresh (c n).who.thread t.k) g₂.mem := by
  obtain ⟨g, c, h⟩ : ∃ g c, Grid.start (Program.ofFunc retFn) retFn .one []
      (Close.mem (some 5)) ch oracle = .ok (g, c) := ⟨_, _, rfl⟩
  exact ⟨g, c, h, fun _ _ _ _ => Grid.start_reach_changes h⟩

/-- The twin: the frame of `returner` lists block 1 among its allocas, which is of every thread,
so the grid of `returner` on `Closed.mem1` is not `Grid.Owns`. -/
theorem owns_twin :
    ¬ ({ threads := #[.run returner], mem := Closed.mem1 } : Grid).Owns (fun _ => ctx0) := by
  intro h
  obtain ⟨x, hx, ho⟩ := h 0 _ rfl _ List.mem_cons_self 1 List.mem_cons_self
  rw [mem1_owner 1 x hx] at ho
  cases ho

end MojoProofTest.Writes
