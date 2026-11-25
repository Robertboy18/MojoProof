import MojoProof.Sem.Trace
import MojoProof.Sem.Schedule

/-!
# Instances of `Mem.Closed`, `Mem.checkClosed` and `Grid.start_blocks`, and the negative twins

The start changes no block of the caller's memory (`Grid.start_blocks`). A memory with block 1
of 4 bytes and `next = 2` is closed for a pointer to block 1 and passes the start's check
(`kept`). With a second block 5, which nothing names, the launch of `ret void` starts and keeps
block 5 (`kept_above`); with the second block at 2, the number the launch's first allocation
takes, the start is refused (`twin_next`). A memory with `next = 1`, a block 40 and a pointer
argument to it is refused by the check (`twin`), and so is a memory with a block 0 (`twin_null`).
The kernel `ret void` is sound on every launch from the empty memory
(`ret_empty`, `Kernel.sound_ret_launch` with `Mem.closed_empty`), and one thread of it is a sound
grid on `Launch.one` (`sound_one_ret`, `Grid.sound_returning` at one thread). Grids of 2 and of
3 threads that each end their own `alloca` block, so that each step changes the memory, are sound
(`sound_dead`, `Grid.sound_commuting`). Statements about these memories (for every address choice
and oracle), not about every memory.
-/

namespace MojoProofTest.Close

open MojoProof.Sem

/-- A live block of 4 undefined bytes in space 1 that every thread may access. -/
def blk : Block :=
  { space := 1, size := 4, live := true, readOnly := false, owner := .all, bytes := fun _ => .undef,
    addr := 0, gaddr := 0 }

/-- Block 1 and, if `extra = some e`, block `e`, with `next = 2`. -/
def mem (extra : Option Nat) : Mem :=
  { blocks := fun c => if c = 1 ∨ extra = some c then some blk else none, next := 2 }

/-- `mem none` (block 1 of 4 bytes, `next = 2`) is closed for the argument list of one pointer to
block 1, so it passes the start's check `Mem.checkClosed` (by `Mem.checkClosed_of_closed`). -/
theorem kept : (mem none).checkClosed [.ptr ⟨1, 0⟩] = .ok () :=
  Mem.checkClosed_of_closed
    ⟨by decide, rfl, fun c (hc : 2 ≤ c) => ite_eq_right (by simp; omega), by decide,
      fun c b i p j hc _ hp => by
      simp only [mem] at hc
      split at hc
      · cases hc
        cases hp
      · cases hc⟩

/-- For every address choice and oracle, the launch `.one` of `retFn` (`ret void`) with no
arguments from `mem (some 5)` starts, and its grid's memory has block 5, which nothing names and
which is above `next`, unchanged (by `Grid.start_blocks`). -/
theorem kept_above (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (MojoProof.LLVM.Program.ofFunc retFn) retFn .one [] (mem (some 5)) ch
      oracle = .ok (g, c) ∧ g.mem.blocks 5 = some blk := by
  obtain ⟨g, c, h⟩ : ∃ g c, Grid.start (MojoProof.LLVM.Program.ofFunc retFn) retFn .one []
      (mem (some 5)) ch oracle = .ok (g, c) := ⟨_, _, rfl⟩
  exact ⟨g, c, h, Grid.start_blocks h rfl⟩

/-- The twin of a caller's block at the number the launch's first allocation takes: for every
address choice and oracle, the launch `.one` of `retFn` from `mem (some 2)`, whose block 2 is at
`next`, does not start. -/
theorem twin_next (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    (Grid.start (MojoProof.LLVM.Program.ofFunc retFn) retFn .one [] (mem (some 2)) ch
      oracle).toBool = false := rfl

/-- The twin of a pointer argument to a block from `next` on: the memory with `next = 1` and one
block 40 fails `Mem.checkClosed` for the argument list of one pointer to block 40. -/
theorem twin :
    ((({ blocks := fun c => if c = 40 then some blk else none } : Mem)).checkClosed
      [.ptr ⟨40, 0⟩]).toBool = false := rfl

/-- The twin of a block 0 (the null pointer's number): the memory with `next = 1` and one block 0
fails `Mem.checkClosed` with no arguments. -/
theorem twin_null :
    ((({ blocks := fun c => if c = 0 then some blk else none } : Mem)).checkClosed []).toBool =
      false :=
  rfl

/-- On every launch `L`, `retFn` with no arguments from the empty memory is sound for every
address choice and oracle, for the observation `fun _ => some ()` and the relation `True` (by
`Kernel.sound_ret_launch` with `Mem.closed_empty`). -/
theorem ret_empty (L : Launch) :
    Kernel.Sound (MojoProof.LLVM.Program.ofFunc retFn) retFn L [] {} (fun _ _ => True)
      (fun _ => some ()) (fun _ => True) :=
  Kernel.sound_ret_launch L Mem.closed_empty

/-- One memory and one launch: on `Launch.one`, for every contexts, the grid of one thread at the
start of `retFn` (`retThread`) on the empty memory is sound (`Grid.Sound`) for the observation
`fun _ => some ()` and the relation `True`. An instance of `Grid.sound_returning` at one thread
(the grid is `retGrid 1`, `eq_retGrid`), whose premise `1 ≤ volume L.grid * volume L.block`
holds at `Launch.one` (`decide`); the empty trace has no race and keeps `!invariant.load`
(`decide`). -/
theorem sound_one_ret (c : Nat → Ctx) :
    Grid.Sound Launch.one c ⟨#[.run retThread], {}⟩ (fun _ => some ()) (fun _ => True) := by
  rw [eq_retGrid (g := ⟨#[.run retThread], {}⟩) (N := 1) (ts := fun _ => retThread) rfl
    fun n hn => by
      obtain rfl : n = 0 := by omega
      rfl]
  exact Grid.sound_returning (by decide) (fun n _ => step_retThread (c n) _) rfl trivial
    (by decide) (by decide)

/-- A thread at the start of `retFn` whose frame owns the `alloca` block `b`. Its one step,
`ret void`, ends the block (`step_allocThread`). -/
def allocThread (b : Nat) : Thread :=
  { frames := [{ fn := retFn, label := 0, pc := 0, regs := fun _ => none,
                 prods := fun _ => none, allocas := [b], dest := none }], k := 0 }

/-- `allocThread b`'s step returns at once and sets block `b` dead (`Mem.setLive`), in every
context and memory. -/
theorem step_allocThread (c : Ctx) (b : Nat) (m : Mem) :
    step c (allocThread b) m = .ok (.done (m.setLive b false)) := rfl

/-- Setting two distinct blocks dead commutes, for every memory. -/
theorem setLive_comm {i j : Nat} (h : i ≠ j) (m : Mem) :
    (m.setLive j false).setLive i false = (m.setLive i false).setLive j false := by
  unfold Mem.setLive
  rcases hi : m.blocks i with _ | bi <;> rcases hj : m.blocks j with _ | bj <;>
    simp [Mem.set, hi, hj, h, Ne.symm h]
  funext k
  by_cases ki : k = i <;> by_cases kj : k = j <;> simp_all

/-- Blocks 1, 2 and 3 live (`blk`), with `next = 4` and an empty trace. -/
def mem3 : Mem := { blocks := fun k => if 1 ≤ k ∧ k ≤ 3 then some blk else none, next := 4 }

/-- Whether blocks 1, 2 and 3 are live. -/
def lives (m : Mem) : Option (List (Option Bool)) :=
  some ((List.range 3).map fun k => (m.blocks (k + 1)).map (·.live))

/-- One memory, two launches: for every contexts, the grid of `N` threads in which thread `n`
owns block `n + 1` (`allocThread`) on `mem3` is sound (`Grid.Sound`) for `lives` and the relation
that blocks `1` to `N` are dead and the others live, at `N = 2` on `launch2 1 1 2 1` and at `N = 3`
on `launch2 1 1 3 1`. Each thread's step changes the memory (it ends its own block), so this is an
instance of `Grid.sound_commuting` that `Grid.sound_returning` does not cover: the changes
commute (`setLive_comm`), keep the trace (`Mem.setLive_trace`), and the empty trace has no race
and keeps `!invariant.load` (`decide`). -/
theorem sound_dead (c : Nat → Ctx) :
    Grid.Sound (launch2 1 1 2 1) c (retGrid 2 (fun n => allocThread (n + 1)) mem3 fun _ => false)
      lives (· = [some false, some false, some true]) ∧
    Grid.Sound (launch2 1 1 3 1) c (retGrid 3 (fun n => allocThread (n + 1)) mem3 fun _ => false)
      lives (· = [some false, some false, some false]) :=
  ⟨Grid.sound_commuting (P := fun _ => True) (f := fun n m => m.setLive (n + 1) false) (by decide)
      trivial (fun _ _ _ _ => trivial) (fun n _ m _ => step_allocThread (c n) (n + 1) m)
      (fun _ _ _ _ hij m _ => setLive_comm (by omega) m) (fun _ _ m _ => Mem.setLive_trace m _ _)
      rfl rfl (by decide) (by decide),
    Grid.sound_commuting (P := fun _ => True) (f := fun n m => m.setLive (n + 1) false) (by decide)
      trivial (fun _ _ _ _ => trivial) (fun n _ m _ => step_allocThread (c n) (n + 1) m)
      (fun _ _ _ _ hij m _ => setLive_comm (by omega) m) (fun _ _ m _ => Mem.setLive_trace m _ _)
      rfl rfl (by decide) (by decide)⟩

end MojoProofTest.Close
