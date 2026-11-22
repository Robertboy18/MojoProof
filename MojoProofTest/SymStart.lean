import MojoProof.Sym.Sched
import MojoProofTest.Confluence

/-!
# `Seq.start_sound_inv` on a concrete start: two threads in turn

An instance of `Seq.start_sound_inv` (MojoProof/Sym/Sched.lean), and through it of
`Seq.of_inv` and `Seq.start_sound`, on the launch `start2` of MojoProofTest/Confluence.lean: one
block of two threads, each running `%0 = alloca i32`, `store i32 7, ptr %0`, `ret void`, on the
empty memory, with address choice and oracle 0.

* `run2_runs`: thread `k` (`Grid.thread`) of the start's grid, for `k` = 0 and 1, runs alone to
  its end (two steps that continue it, then the `ret`) from `mems k`, the memory threads `0` to
  `k - 1` left, to `mems (k + 1)` (the kernel evaluates each step).
* `run2_seq`: by `Seq.of_inv`, the two threads run in turn (`Seq`) from the grid's memory to
  `mems 2`.
* `sound2_seq`: with the invariant `m = mems k`, the trace of `mems 2` has no data race and
  keeps the promise of `!invariant.load` (both evaluated), so by `Seq.start_sound_inv` the
  start's grid is sound for the observation of bytes 0 to 3 of block 4, thread 1's `alloca`,
  which hold the bytes of 7.

The twins of the premises that `Seq.start_sound_inv` passes on to `Grid.start_sound` (a racy
trace, which makes the done grid bad; an observation that reads the trace) are `racy_twin` and
`trace_twin`
(MojoProofTest/Determinism.lean); the twin of the premise that `ns` names every thread is
`vadd2_grid_twin` (MojoProofTest/SymSched.lean). Each result covers the launch named, not all
programs.
-/

namespace MojoProofTest.SymStart

open MojoProof.Sem MojoProof.LLVM MojoProof.Sym MojoProofTest.Confluence

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- Thread `t` and memory `m` after the step of `t` in context `c`, if that step continues it;
`t` and `m` otherwise. -/
def stepTo (c : Ctx) (t : Thread) (m : Mem) : Thread × Mem :=
  match step c t m with
  | .ok (.next t' m') => (t', m')
  | _ => (t, m)

/-- Thread `n` of `start2`'s grid and memory `m`, after the thread's first step from `m`. -/
def s1 (n : Nat) (m : Mem) : Thread × Mem := stepTo (c2 n) (Grid.thread run2.1 n) m

/-- Thread `n` of `start2`'s grid and memory `m`, after the thread's first two steps from `m`. -/
def s2 (n : Nat) (m : Mem) : Thread × Mem := stepTo (c2 n) (s1 n m).1 (s1 n m).2

/-- The memory thread `n` of `start2`'s grid leaves when it runs alone from `m`: two steps, then
the return; `m` if the third step does not return. -/
def ran (n : Nat) (m : Mem) : Mem :=
  match step (c2 n) (s2 n m).1 (s2 n m).2 with
  | .ok (.done m') => m'
  | _ => m

/-- The four bytes at offset 0 of block 4 (thread 1's `alloca`; block 2 is thread 0's). -/
def obs4 (m : Mem) : Option (List MemByte) := (m.blocks 4).map (·.read 0 4)

/-- The memory threads `0` to `k - 1` of `start2`'s grid leave when they run alone in turn
(`ran`) from the grid's memory. -/
def mems : Nat → Mem
  | 0 => run2.1.mem
  | k + 1 => ran k (mems k)

/-- **Each thread to its end**: threads 0 and 1 of `start2`'s grid each run alone to their ends
from the memory the threads before them left; the premise of `Seq.of_inv` for the invariant
`m = mems k`. -/
theorem run2_runs : ∀ k < 2, ∀ m, m = mems k →
    ∃ m', Runs (c2 k) (Grid.thread run2.1 k) m m' ∧ m' = mems (k + 1)
  | 0, _, _, rfl =>
    ⟨_, ⟨(s2 0 (mems 0)).1, (s2 0 (mems 0)).2, .cons rfl (.cons rfl (.refl _ _)), rfl⟩, rfl⟩
  | 1, _, _, rfl =>
    ⟨_, ⟨(s2 1 (mems 1)).1, (s2 1 (mems 1)).2, .cons rfl (.cons rfl (.refl _ _)), rfl⟩, rfl⟩
  | _ + 2, h, _, _ => absurd h (by omega)

/-- **The threads in turn** (`Seq.of_inv`): threads 0 and 1 of `start2`'s grid run in turn from
the grid's memory to `mems 2`. -/
theorem run2_seq :
    ∃ Es m', Seq c2 (Grid.thread run2.1) (List.range 2) run2.1.mem Es m' ∧ m' = mems 2 :=
  Seq.of_inv (P := fun k m => m = mems k) run2_runs rfl

/-- **The instance of `Seq.start_sound_inv`**: with the invariant `m = mems k`, the trace the
threads in turn leave has no data race and keeps the promise of `!invariant.load`, so `start2`'s
grid is sound for the bytes of block 4, which hold 7. -/
theorem sound2_seq : Grid.Sound two c2 run2.1 obs4 (· = leBytes 4 7) := by
  have hn : run2.1.threads.size = 2 := rfl
  exact Seq.start_sound_inv (P := fun k m => m = mems k) start2_eq
    (fun _ _ _ _ _ h => by cases h) (fun m m' h => by simp only [obs4, h]) rfl
    (fun k hk => run2_runs k (hn ▸ hk)) (fun m' e => by subst e; exact ⟨rfl, rfl⟩)
    (fun m' e => ⟨leBytes 4 7, by subst e; rfl, rfl⟩)

end MojoProofTest.SymStart
