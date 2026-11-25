import MojoProofTest.Confluence
import MojoProofTest.SymSeg
import MojoProof.Sym.SchedWait

/-!
# Schedules through a barrier and a shuffle, on concrete grids

Instances of MojoProof/Sym/SchedWait.lean.

* `sound`: the kernel `Launch.k` (`alloca`, `store`, a barrier, `ret`; MojoProofTest/Launch.lean)
  launched on `Confluence.two` (one block of two threads) on the empty memory is sound, by
  `Seq.start_sound_bar`: thread 0, then thread 1, runs to the barrier (`ToWait.of_runTo`, the run
  `runTo` computes), the barrier of block 0 fires (`Grid.fire_barriers`), and the threads, resumed,
  run in turn to their returns (`Runs.of_runTo`). The trace this leaves (two stores to different
  blocks, the barrier) has no race and keeps the promise of `!invariant.load`, by evaluation.
* `bar_twin`: with thread 0 alone at the barrier (the grid `Seq.ToWait.grid` reaches from `g0`
  with `ns = [0]`), the barrier does not fire: the premise of `Grid.fire_barrier` that every
  thread of the block waits is needed. Its open-goal twin (an `example` with `#guard_msgs`):
  `Grid.fire_barrier` at that grid leaves the goal that thread 1 waits.
* `shfl2_fire`: `Grid.fire_shfl` on `Confluence.shfl2` (lanes 0 and 1 of one warp at a butterfly
  shuffle of `5` and `6` with lane mask `1`): lane 0 is resumed with `6` and lane 1 with `5`.
* `shfl_twin`: with lane 1 at a shuffle of another mode (`down`), the fire faults: the premise of
  `Grid.fire_shfl` that every lane waits at the shuffle of one mode is needed.
* `gemv_toWait`: the first segment of gemv_kernel's warp reduction (`%78`, the segment of
  MojoProofTest/SymSeg.lean's `gemv_first_wait`), by `Seg.sound`, is a thread's run to its shuffle
  (`Waits.toWait`), the form of a thread's run in `Seq.ToWait`.

Each result covers the grid named, not all programs.
-/

namespace MojoProofTest.SymWait

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The launch of `Launch.k` on `Confluence.two` (one block of two threads), on the empty memory,
with address choice and oracle 0. -/
def start : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start Launch.prog Launch.k Confluence.two [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start`. -/
def run0 : Grid × (Nat → Ctx) :=
  match start with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 : Grid := run0.1

/-- The start's contexts. -/
def c : Nat → Ctx := run0.2

/-- The launch starts, with grid `g0` and contexts `c`. -/
theorem start_eq : start = .ok (g0, c) := rfl

/-- Thread `n`'s run in `c n` from `t` on `m` to its next wait or return, in at most 4 steps
(`runTo`); `t` on `m` returning to `m` if it does not get there. -/
def next (n : Nat) (t : Thread) (m : Mem) : Thread × Mem × Step :=
  (runTo (c n) 4 t m).getD (t, m, .done m)

/-- Thread 0's run from the start to the barrier. -/
def w0 : Thread × Mem × Step := next 0 (Grid.thread g0 0) g0.mem

/-- Thread 1's run from the start to the barrier, on the memory thread 0 left. -/
def w1 : Thread × Mem × Step := next 1 (Grid.thread g0 1) w0.2.1

/-- The thread thread `n` waits at the barrier from. -/
def u (n : Nat) : Thread := if n = 0 then w0.1 else w1.1

/-- The memory a returning step leaves, the empty memory for any other step. -/
def doneMem : Step → Mem
  | .done m => m
  | _ => {}

/-- The memory after the barrier of block 0. -/
def mb : Mem := (List.range 1).foldl (fun m b => m.log (.barrier b)) w1.2.1

/-- Thread 0's run after the barrier, to its return. -/
def e0 : Thread × Mem × Step := next 0 ((u 0).resume none) mb

/-- Thread 1's run after the barrier, to its return, on the memory thread 0 left. -/
def e1 : Thread × Mem × Step := next 1 ((u 1).resume none) (doneMem e0.2.2)

/-- **The launch through its barrier is sound** (`Grid.Sound`), with the observation that is
always `()`: by `Seq.start_sound_bar` with the runs `runTo` computes. -/
theorem sound : Grid.Sound Confluence.two c g0 (fun _ => some ()) fun _ => True := by
  have hsz : g0.threads.size = 2 := rfl
  have t0 := ToWait.of_runTo (c := c 0) (fuel := 4) (t := Grid.thread g0 0) (m := g0.mem)
    (u := u 0) (m' := w0.2.1) (i := .barrier) («as» := [.bits 32 0]) (d := Launch.barrierDecl) rfl
  have t1 := ToWait.of_runTo (c := c 1) (fuel := 4) (t := Grid.thread g0 1) (m := w0.2.1)
    (u := u 1) (m' := w1.2.1) (i := .barrier) («as» := [.bits 32 0]) (d := Launch.barrierDecl) rfl
  have r0 := Runs.of_runTo (c := c 0) (fuel := 4) (t := (u 0).resume none) (m := mb) (u := e0.1)
    (m₁ := e0.2.1) (m' := doneMem e0.2.2) rfl
  have r1 := Runs.of_runTo (c := c 1) (fuel := 4) (t := (u 1).resume none)
    (m := doneMem e0.2.2) (u := e1.1) (m₁ := e1.2.1) (m' := doneMem e1.2.2) rfl
  obtain ⟨E0, h0⟩ := t0.trace
  obtain ⟨E1, h1⟩ := t1.trace
  obtain ⟨F0, k0⟩ := r0.trace
  obtain ⟨F1, k1⟩ := r1.trace
  refine Seq.start_sound_bar (u := u) (x := fun _ => .bits 32 0)
    (d := fun _ => Launch.barrierDecl) (bar := fun _ => 0) start_eq
    (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl)
    (by decide) (by rw [hsz]; exact .cons t0 h0 (.cons t1 h1 (.nil _))) (fun n hn => ?_)
    (by rw [hsz]; exact .cons r0 k0 (.cons r1 k1 (.nil _))) (fun _ _ => by decide +kernel)
    (by decide +kernel) rfl trivial
  rw [hsz] at hn
  rcases (by omega : n = 0 ∨ n = 1) with rfl | rfl
  · exact ⟨rfl, by decide, rfl⟩
  · exact ⟨rfl, by decide, rfl⟩

/-- **The twin**: with thread 0 alone run to the barrier (the grid `Seq.ToWait.grid` reaches from
`g0` with `ns = [0]`: thread 0 waiting, thread 1 at the start), the barrier fired by thread 0 does
not complete (`.ok none`). -/
theorem bar_twin :
    Grid.fire Confluence.two c
      ⟨g0.threads.set! 0 (.wait (u 0) .barrier [.bits 32 0] Launch.barrierDecl), w0.2.1⟩ 0 =
      .ok none := rfl

/--
error: unsolved goals
case inr
e : volume Confluence.two.block = 2
hk : 1 < 2
⊢ (g0.threads.set! 0 (Status.wait (u 0) Intrinsic.barrier [Val.bits 32 0] Launch.barrierDecl))[1]? =
    some (Status.wait (u 1) Intrinsic.barrier [Val.bits 32 0] Launch.barrierDecl)
-/
#guard_msgs in
/-- **The open-goal twin**: `Grid.fire_barrier` at the grid of `bar_twin` leaves the goal that
thread 1 waits at the barrier, which is false (thread 1 is at the start, `.run`). -/
example : ∃ g', Grid.fire Confluence.two c
    ⟨g0.threads.set! 0 (.wait (u 0) .barrier [.bits 32 0] Launch.barrierDecl), w0.2.1⟩ 0 =
      .ok (some g') :=
  ⟨_, Grid.fire_barrier (b := 0) (bar := 0) (u := u) (x := fun _ => .bits 32 0)
    (d := fun _ => Launch.barrierDecl) (by decide) (by decide) fun k hk => by
      have e : volume Confluence.two.block = 2 := rfl
      rw [e] at hk
      rcases (by omega : k = 0 ∨ k = 1) with rfl | rfl
      · exact ⟨rfl, rfl, rfl⟩
      · simp only [e, Nat.zero_mul, Nat.zero_add]
        refine ⟨?_, rfl, rfl⟩⟩

/-- The value lane `j` of `Confluence.shfl2` offers: `5` for lane 0, `6` for the others. -/
def offer (j : Nat) : Val := if j = 0 then .bits 32 5 else .bits 32 6

/-- The value lane `j` of `Confluence.shfl2` is resumed with: `6` for lane 0, `5` for the
others. -/
def out (j : Nat) : Val := if j = 0 then .bits 32 6 else .bits 32 5

/-- **A warp's shuffle, by `Grid.fire_shfl`**: in a launch of one block of two threads, lanes 0
and 1 of `Confluence.shfl2` wait at a butterfly shuffle with lane mask `1`, and the shuffle
resumes lane 0 with lane 1's `6` and lane 1 with lane 0's `5` (`out`). -/
theorem shfl2_fire : Confluence.shfl2.fire (launch2 1 1 2 1) Confluence.ctxOf 0 =
    .ok (some ⟨(warpLanes (launch2 1 1 2 1) 0).foldl
      (fun ts j => ts.set! (0 - 0 % volume (launch2 1 1 2 1).block % 32 + j)
        (.run (Confluence.regT.resume (some (out j))))) Confluence.shfl2.threads,
      Confluence.shfl2.mem⟩) :=
  Grid.fire_shfl (u := fun _ => Confluence.regT) (M := fun _ => .bits 32 (-1)) (A := offer)
    (B := fun _ => .bits 32 1) (C := fun _ => .bits 32 31) (b := fun _ => 1) (cl := fun _ => 31)
    (d := fun _ => Confluence.shflFn) (by decide) fun j hj => by
      have e : warpLanes (launch2 1 1 2 1) 0 = [0, 1] := by decide
      rw [e] at hj
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hj
      rcases hj with rfl | rfl
      · exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩
      · exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- `Confluence.shfl2` with lane 1 at a shuffle of mode `down` instead. -/
def shflMix : Grid :=
  ⟨Confluence.shfl2.threads.set! 1 (.wait Confluence.regT (.shfl .down)
      [.bits 32 (-1), .bits 32 6, .bits 32 1, .bits 32 31] Confluence.shflFn),
    Confluence.shfl2.mem⟩

/-- **The twin**: with lane 1 at a shuffle of another mode, the shuffle fired by lane 0 faults. -/
theorem shfl_twin : ∃ e, shflMix.fire (launch2 1 1 2 1) Confluence.ctxOf 0 = .error e :=
  ⟨_, rfl⟩

/-- **gemv's first segment is a run to a wait**: for every summary `S` that `summarizeTo` gives
for statements 1 to 2 of gemv_kernel's `%78` (`b_10`; the segment of
MojoProofTest/SymSeg.lean's `gemv_first_wait`), every context of gemv_kernel's program and thread
whose innermost frame `f` (above frames `rest`) runs `gemv_kernel` at `b_10`, statement 1, with
memory `m`: if `S`'s obligations hold under `f`'s entry valuation, the
thread runs to the call of `S`'s collective (`ToWait`), waiting at a frame `fe` with step count
`t.k + S.len`. By `Waits.toWait` at `Seg.sound`. -/
theorem gemv_toWait {S : SegSummary}
    (hS : summarizeTo SymLane.gemv.prog SymLane.gemv.fn_0 SymLane.gemv.fn_0.b_10.label 1 2 =
      some S)
    {c : Ctx} (hP : c.prog = SymLane.gemv.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = SymLane.gemv.fn_0)
    (hl : f.label = SymLane.gemv.fn_0.b_10.label) (hp : f.pc = 1)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me ws fd, ToWait c t m (.wait ⟨fe :: rest, t.k + S.len⟩ S.call.intr ws fd) me :=
  Waits.toWait (Seg.sound hS hP ht hfn hl hp hds).1

end MojoProofTest.SymWait
