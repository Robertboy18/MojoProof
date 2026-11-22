import MojoProof.Sem.Trace

/-!
# Instances of `Mem.Closed`, `Mem.checkClosed` and `Grid.start_blocks`, and the negative twins

The start changes no block of the caller's memory (`Grid.start_blocks`). A memory with block 1
of 4 bytes and `next = 2` is closed for a pointer to block 1 and passes the start's check
(`kept`). With a second block 5, which nothing names, the launch of `ret void` starts and keeps
block 5 (`kept_above`); with the second block at 2, the number the launch's first allocation
takes, the start is refused (`twin_next`). A memory with `next = 1`, a block 40 and a pointer
argument to it is refused by the check (`twin`), and so is a memory with a block 0 (`twin_null`).
The kernel `ret void` is sound on every launch from the empty memory
(`ret_empty`, `Kernel.sound_ret_launch` with `Mem.closed_empty`). Statements about these
memories (for every address choice and oracle), not about every memory.
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

end MojoProofTest.Close
