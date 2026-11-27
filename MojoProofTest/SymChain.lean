import MojoProofTest.SymColl
import MojoProof.Sym.CanonBar

/-!
# Canonical runs by invariants: a barrier and two shuffles on blocks of 4 and of 8 threads

Tests of `BlockRun.of_inv`, `WarpWait.of_inv` and `WarpRun.of_inv` with `PhaseRun.start_sound`
(MojoProof/Sym/CanonBar.lean, MojoProof/Sym/Canon.lean) at two sizes: the kernel `kern` of
MojoProofTest/SymColl.lean (`tid.x`, a barrier, a butterfly shuffle at offset 1 and an `add`, one
at offset 2 and an `add`, `ret`) launched on one block of `k` threads (`launch2 1 1 k 1`, one
warp), for `k = 4` and `k = 8`, on the empty memory with address choice and oracle 0. One proof
covers both sizes; the runs are evaluated at each.

* `ph k j`: the threads and memory phase `j` starts on (the start's; then past the barrier, past
  the first shuffle and past the second); `stat k j n`: the status thread `n` waits at in phase
  `j`; `memAt k t m i`: the memory after threads `0` to `i - 1` run in turn.
* `waits`, `ends`: each phase's runs, as `runTo` computes them; `bar0`: the barrier (`BlockBar`);
  `fires`: the shuffles (`WarpShfl`), lane `n` resumed with lane `n ^^^ o`'s value; `warp`: the
  warp's run through the shuffles (`WarpRun.of_inv`); `checks`: the final trace's race and
  `!invariant.load` checks.
* `shfl_wait`: past the barrier, the warp to the second shuffle's waits by `WarpWait.of_inv` at
  `J = 1`, its shuffle premise `hf` by `fires` (the first shuffle, before the waits).
* `sound_inv`: the launch is sound (`Grid.Sound`), by `PhaseRun.start_sound` at the block's run
  of `BlockRun.of_inv`: the warp to the barrier (`WarpWait.of_inv`), the barrier, then `warp`.
* The open-goal twin (an `example` with `#guard_msgs`): `warp` with the second shuffle's fire
  left out leaves that phase's shuffle as the goal.

Statements about this kernel at these two sizes, not about every launch.
-/

namespace MojoProofTest.SymChain

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- One block of `k` threads. -/
abbrev L (k : Nat) : Launch := launch2 1 1 k 1

/-- The launch of `kern` on `L k`, on the empty memory, with address choice and oracle 0. -/
def start (k : Nat) : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start SymColl.prog SymColl.kern (L k) [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start k`. -/
def run0 (k : Nat) : Grid × (Nat → Ctx) :=
  match start k with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 (k : Nat) : Grid := (run0 k).1

/-- The start's contexts. -/
def c (k : Nat) : Nat → Ctx := (run0 k).2

/-- The launch starts on 4 and on 8 threads, with grid `g0 k` and contexts `c k`. -/
theorem start_eq (k : Nat) (hk : k = 4 ∨ k = 8) : start k = .ok (g0 k, c k) := by
  rcases hk with rfl | rfl <;> rfl

/-- Thread `n`'s run in `c k n` from `t` on `m` to its next wait or return, in at most 4 steps
(`runTo`); `t` on `m` returning to `m` if it does not get there. -/
def next (k n : Nat) (t : Thread) (m : Mem) : Thread × Mem × Step :=
  (runTo (c k n) 4 t m).getD (t, m, .done m)

/-- The memory after threads `0` to `i - 1` run in turn by `next`, each from its thread `t n`,
the first on `m`: what a run to a wait leaves, or what a return leaves. -/
def memAt (k : Nat) (t : Nat → Thread) (m : Mem) : Nat → Mem
  | 0 => m
  | i + 1 =>
    match next k i (t i) (memAt k t m i) with
    | (_, _, .done m') => m'
    | (_, m₁, _) => m₁

/-- The thread thread `n` stops at in the turns of `memAt k t m`. -/
def stop (k : Nat) (t : Nat → Thread) (m : Mem) (n : Nat) : Thread :=
  (next k n (t n) (memAt k t m n)).1

/-- The value lane `n` is resumed with after phase `j`'s collective: none after the barrier,
`SymColl.r2` after the first shuffle, `SymColl.r3` after the second. -/
def res : Nat → Nat → Option Val
  | 0, _ => none
  | 1, n => SymColl.r2 n
  | _, n => SymColl.r3 n

/-- The threads and memory phase `j` starts on: the start's, then the threads phase `j - 1`
stops at resumed with `res`, on the memory its runs leave, with the barrier logged after
phase 0. -/
def ph (k : Nat) : Nat → (Nat → Thread) × Mem
  | 0 => (Grid.thread (g0 k), (g0 k).mem)
  | j + 1 =>
    (fun n => (stop k (ph k j).1 (ph k j).2 n).resume (res j n),
      if j = 0 then (memAt k (ph k j).1 (ph k j).2 k).log (.barrier 0)
      else memAt k (ph k j).1 (ph k j).2 k)

/-- The status thread `n` waits at in phase `j`: the barrier, the first shuffle offering its
thread number, the second offering `SymColl.a3 n`. -/
def stat (k : Nat) : Nat → Nat → Status
  | 0, n => .wait (stop k (ph k 0).1 (ph k 0).2 n) .barrier [.bits 32 0] Launch.barrierDecl
  | 1, n => .wait (stop k (ph k 1).1 (ph k 1).2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] SymColl.shflDecl
  | _, n => .wait (stop k (ph k 2).1 (ph k 2).2 n) (.shfl .bfly)
      [.bits 32 (-1), SymColl.a3 n, .bits 32 2, .bits 32 31] SymColl.shflDecl

/-- The launch's `k` threads. -/
theorem size (k : Nat) (hk : k = 4 ∨ k = 8) : volume (L k).grid * volume (L k).block = k := by
  rcases hk with rfl | rfl <;> rfl

/-- The block's `k` threads. -/
theorem block (k : Nat) (hk : k = 4 ∨ k = 8) : volume (L k).block = k := by
  rcases hk with rfl | rfl <;> rfl

/-- Each phase's runs to the waits, as `runTo` computes them: in phase `j < 3`, thread `n` from
`(ph k j).1 n` on the memory after the threads before it runs to `stat k j n`. -/
theorem waits (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ j < 3, ∀ n < volume (L k).grid * volume (L k).block, ∀ t m, t = (ph k j).1 n →
      m = memAt k (ph k j).1 (ph k j).2 n → ∃ s m', ToWait (c k n) t m s m' ∧
        s = stat k j n ∧ m' = memAt k (ph k j).1 (ph k j).2 (n + 1) := by
  rw [size k hk]
  intro j hj n hn t m ht hm
  subst ht hm
  refine ⟨stat k j n, memAt k (ph k j).1 (ph k j).2 (n + 1), ?_, rfl, rfl⟩
  rcases hk with rfl | rfl <;> interval_cases j <;> interval_cases n <;>
    exact ToWait.of_runTo (fuel := 4) (by kernel_rfl)

/-- The runs to the returns, as `runTo` computes them: thread `n` from `(ph k 3).1 n` on the
memory after the threads before it returns. -/
theorem ends (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ n < volume (L k).grid * volume (L k).block, ∀ t m, t = (ph k 3).1 n →
      m = memAt k (ph k 3).1 (ph k 3).2 n →
      ∃ m', Runs (c k n) t m m' ∧ m' = memAt k (ph k 3).1 (ph k 3).2 (n + 1) := by
  rw [size k hk]
  intro n hn t m ht hm
  subst ht hm
  refine ⟨memAt k (ph k 3).1 (ph k 3).2 (n + 1), Runs.of_runTo (fuel := 4)
    (u := stop k (ph k 3).1 (ph k 3).2 n)
    (m₁ := (next k n ((ph k 3).1 n) (memAt k (ph k 3).1 (ph k 3).2 n)).2.1) ?_, rfl⟩
  rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl

/-- The final trace has no race and keeps the promise of `!invariant.load`, by the kernel. -/
theorem checks (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ m', m' = memAt k (ph k 3).1 (ph k 3).2 (volume (L k).grid * volume (L k).block) →
      ((∀ a, Event.access a ∈ m'.trace →
          a.who.thread < volume (L k).grid * volume (L k).block ∧
            a.who.cta = a.who.thread / volume (L k).block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore (L k))).reverse = false) ∧
        GPUProof.kept sig (m'.trace.map (Event.toCore (L k))).reverse = true := by
  rw [size k hk]
  intro m' hm
  subst hm
  rcases hk with rfl | rfl <;> exact ⟨fun _ _ => by decide +kernel, by decide +kernel⟩

/-- The warp of first thread 0 is the block's `k` threads, at 4 and at 8 threads. -/
theorem lanes (k : Nat) (hk : k = 4 ∨ k = 8) : warpLanes (L k) 0 = List.range k := by
  rcases hk with rfl | rfl <;> decide

/-- The barrier (phase 0, `BlockBar`): every thread of block 0 waits at `stat k 0`, from the
thread it stops at, at the barrier of number 0 and at the instruction of thread 0. -/
theorem bar0 (k : Nat) (hk : k = 4 ∨ k = 8) :
    BlockBar (L k) 0 (stat k 0) (stop k (ph k 0).1 (ph k 0).2) := by
  refine ⟨fun _ => .bits 32 0, fun _ => Launch.barrierDecl, 0, by decide, fun n hn => ?_⟩
  rw [block k hk] at hn
  have hn : n < k := by rcases hk with rfl | rfl <;> omega
  refine ⟨rfl, rfl, ?_⟩
  rw [Nat.zero_mul]
  rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl

/-- The shuffles (phases 1 and 2, `WarpShfl`), in the form `WarpRun.of_inv` takes: from every
statuses at `stat k (i + 1)` on the memory the phase's runs leave, the warp's butterfly shuffle at
offset `i + 1` fires, lane `j` resumed from the thread it stops at with `res (i + 1) j` (lane
`j ^^^ (i + 1)`'s value), to `(ph k (i + 2)).1`; a shuffle leaves the memory unchanged. -/
theorem fires (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ i < 2, ∀ s : Nat → Status, (∀ j ∈ warpLanes (L k) 0, s j = stat k (i + 1) j) →
      ∀ m, m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 (warpLanes (L k) 0).length →
      ∃ u r, WarpShfl (L k) (c k) 0 s m u r ∧
        (∀ j ∈ warpLanes (L k) 0, (u j).resume (r j) = (ph k (i + 1 + 1)).1 j) ∧
        m = memAt k (ph k (i + 1 + 1)).1 (ph k (i + 1 + 1)).2 0 := by
  intro i hi s hs m hm
  refine ⟨stop k (ph k (i + 1)).1 (ph k (i + 1)).2, res (i + 1), ⟨.bfly, fun _ => .bits 32 (-1),
    fun n => if i = 0 then .bits 32 (.ofNat 32 n) else SymColl.a3 n,
    fun _ => .bits 32 (if i = 0 then 1 else 2), fun _ => .bits 32 31,
    fun _ => if i = 0 then 1 else 2, fun _ => 31, fun _ => SymColl.shflDecl, fun j hj => ?_⟩,
    fun j _ => rfl, ?_⟩
  · rw [hs j hj]
    have hj := List.mem_range.1 (lanes k hk ▸ hj)
    interval_cases i
    · refine ⟨rfl, rfl, rfl, rfl, ?_, ?_⟩
      · rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl
      · rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl
    · refine ⟨rfl, rfl, rfl, rfl, ?_, ?_⟩
      · rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl
      · rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl
  · rw [memAt.eq_1, hm, lanes k hk, List.length_range]
    interval_cases i <;> rfl

/-- The warp's run past the barrier (`WarpRun.of_inv`, two shuffles), from every shuffles of the
form `fires` gives: thread `n` from `(ph k 1).1 n` on the memory past the barrier runs through the
shuffles to its return, by the runs `waits` and `ends`, at 4 and at 8 threads. -/
theorem warp (k : Nat) (hk : k = 4 ∨ k = 8) {t : Nat → Thread}
    (hf : ∀ i < 2, ∀ s : Nat → Status, (∀ j ∈ warpLanes (L k) 0, s j = stat k (i + 1) j) →
      ∀ m, m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 (warpLanes (L k) 0).length →
      ∃ u r, WarpShfl (L k) (c k) 0 s m u r ∧
        (∀ j ∈ warpLanes (L k) 0, (u j).resume (r j) = (ph k (i + 1 + 1)).1 j) ∧
        m = memAt k (ph k (i + 1 + 1)).1 (ph k (i + 1 + 1)).2 0)
    (ht : ∀ n < k, t n = (ph k 1).1 n) :
    ∃ Es, WarpRun (L k) (c k) 0 t (ph k 1).2 Es (memAt k (ph k 3).1 (ph k 3).2 k) := by
  obtain ⟨Es, m', hw, hm'⟩ := WarpRun.of_inv (L := L k) (c := c k) (k := 0) (J := 2)
    (T := fun i j t => t = (ph k (i + 1)).1 j) (W := fun i j s => s = stat k (i + 1) j)
    (P := fun i j m => m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 j)
    (fun i hi j hj t m ht hm => by
      rw [Nat.zero_add]
      exact waits k hk (i + 1) (by omega) j (by
        rw [size k hk]; exact List.mem_range.1 (lanes k hk ▸ hj)) t m ht hm)
    hf
    (fun j hj t m ht hm => by
      rw [Nat.zero_add]
      exact ends k hk j (by rw [size k hk]; exact List.mem_range.1 (lanes k hk ▸ hj)) t m ht hm)
    (t := t) (fun j hj => by
      rw [Nat.zero_add]
      exact ht j (List.mem_range.1 (lanes k hk ▸ hj))) (m := (ph k 1).2) (memAt.eq_1 _ _ _).symm
  rw [lanes k hk, List.length_range] at hm'
  exact ⟨Es, hm' ▸ hw⟩

/-- **The warp past the barrier to the second shuffle's waits, by `WarpWait.of_inv` at
`J = 1`**: from the threads `(ph k 1).1` on the memory past the barrier, the lanes run in turn to
the first shuffle's waits (`waits` at phase 1), the shuffle fires (`fires` at `i = 0`: the
premise `hf`, the shuffle before the waits), and the resumed lanes run in turn to the second
shuffle's waits at `stat k 2` (`waits` at phase 2), on the memory that phase's runs leave, at 4
and at 8 threads. -/
theorem shfl_wait (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∃ s Es, WarpWait (L k) (c k) 0 (ph k 1).1 (ph k 1).2 Es s
      (memAt k (ph k 2).1 (ph k 2).2 k) ∧ ∀ n < k, s n = stat k 2 n := by
  obtain ⟨s, Es, m', hw, hs, hm'⟩ := WarpWait.of_inv (L := L k) (c := c k) (k := 0) (J := 1)
    (T := fun i j t => t = (ph k (i + 1)).1 j) (W := fun i j s => s = stat k (i + 1) j)
    (P := fun i j m => m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 j)
    (fun i hi j hj t m ht hm => by
      rw [Nat.zero_add]
      exact waits k hk (i + 1) (by omega) j (by
        rw [size k hk]; exact List.mem_range.1 (lanes k hk ▸ hj)) t m ht hm)
    (fun i hi => fires k hk i (by omega))
    (fun j hj t m ht hm => by
      rw [Nat.zero_add]
      exact waits k hk 2 (by omega) j (by
        rw [size k hk]; exact List.mem_range.1 (lanes k hk ▸ hj)) t m ht hm)
    (t := (ph k 1).1) (fun j _ => by simp only [Nat.zero_add]) (m := (ph k 1).2)
    (memAt.eq_1 _ _ _).symm
  rw [lanes k hk, List.length_range] at hm'
  refine ⟨s, Es, hm' ▸ hw, fun n hn => ?_⟩
  simpa only [Nat.zero_add] using hs n (lanes k hk ▸ List.mem_range.2 hn)

/-- **The launch on 4 and on 8 threads is sound, by invariants**: `PhaseRun.start_sound` at the
run of the one block, by `BlockRun.of_inv` at one barrier: phase 0 the warp's run to the barrier
(`WarpWait.of_inv` with the runs `waits`) and the barrier `bar0`, the last phase the warp's run
through the shuffles (`warp` with `fires`); thread `n` of phase `j` at `(ph k j).1 n`, its status
`stat k j n` and the memory after `i` threads `memAt k (ph k j).1 (ph k j).2 i`; the final trace's
`checks`. A test of `BlockRun.of_inv` and `WarpRun.of_inv` at two sizes. -/
theorem sound_inv (k : Nat) (hk : k = 4 ∨ k = 8) :
    Grid.Sound (L k) (c k) (g0 k) (fun _ => some ()) fun _ => True := by
  have hb : blockWarps (L k) 0 = [0] := by rcases hk with rfl | rfl <;> decide
  obtain ⟨Es, m', hr, rfl⟩ := BlockRun.of_inv (L := L k) (c := c k) (b := 0) (J := 1)
    (T := fun i t => ∀ n < k, t n = (ph k i).1 n)
    (P := fun i m => m = match i with
      | 0 => (ph k 0).2 | 1 => (ph k 1).2 | _ => memAt k (ph k 3).1 (ph k 3).2 k)
    (fun i hi t m ht hm => by
      obtain rfl : i = 0 := by omega
      obtain ⟨s, Es, m₁, hw, hs, hm₁⟩ := WarpWait.of_inv (L := L k) (c := c k) (k := 0) (J := 0)
        (T := fun _ j t => t = (ph k 0).1 j) (W := fun _ j s => s = stat k 0 j)
        (P := fun _ j m => m = memAt k (ph k 0).1 (ph k 0).2 j) (fun i hi => absurd hi (by omega))
        (fun i hi => absurd hi (by omega))
        (fun j hj t m ht hm => by
          rw [Nat.zero_add]
          exact waits k hk 0 (by omega) j (by
            rw [size k hk]; exact List.mem_range.1 (lanes k hk ▸ hj)) t m ht hm)
        (t := t) (fun j hj => by
          rw [Nat.zero_add]
          exact ht j (List.mem_range.1 (lanes k hk ▸ hj))) (m := m) (by
          rw [memAt.eq_1]; exact hm)
      rw [lanes k hk, List.length_range] at hm₁
      refine ⟨stat k 0, stop k (ph k 0).1 (ph k 0).2, Es ++ [], m₁, ?_, bar0 k hk,
        fun n _ => rfl, by rw [hm₁]; rfl⟩
      rw [hb]
      exact .cons (hw.congr fun n hn => by
        obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hn
        simpa only [Nat.zero_add] using hs j hj) (.nil _))
    (fun t m ht hm => by
      obtain ⟨Es, hw⟩ := warp k hk (fires k hk) ht
      subst hm
      refine ⟨Es ++ [], _, ?_, rfl⟩
      rw [hb]
      exact .cons hw (.nil _))
    (t := Grid.thread (g0 k)) (fun _ _ => rfl) (m := (g0 k).mem) rfl
  have hc : PhaseRun (L k) (c k) (Grid.thread (g0 k)) [0] (g0 k).mem _ _ := .cons hr (.nil _)
  rw [show [0] = List.range (volume (L k).grid) by rcases hk with rfl | rfl <;> rfl] at hc
  have hC := checks k hk _ (by rw [size k hk])
  exact PhaseRun.start_sound (start_eq k hk) (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl)
    (by rw [block k hk]; rcases hk with rfl | rfl <;> decide) hc ⟨hC.1, hC.2, (), rfl, trivial⟩

/--
error: unsolved goals
case «1»
⊢ ∀ (s : ℕ → Status),
    (∀ j ∈ warpLanes (L 4) 0, s j = stat 4 (1 + 1) j) →
      ∀ (m : Mem),
        m = memAt 4 (ph 4 (1 + 1)).1 (ph 4 (1 + 1)).2 (warpLanes (L 4) 0).length →
          ∃ u r,
            WarpShfl (L 4) (c 4) 0 s m u r ∧
              (∀ j ∈ warpLanes (L 4) 0, (u j).resume (r j) = (ph 4 (1 + 1 + 1)).1 j) ∧
                m = memAt 4 (ph 4 (1 + 1 + 1)).1 (ph 4 (1 + 1 + 1)).2 0
-/
#guard_msgs in
/-- **The open-goal twin**: the warp's run past the barrier on 4 threads with the second
shuffle's fire (phase 2) left out leaves that phase's shuffle as the goal: from the statuses
`stat 4 2` on the memory the phase's runs leave, a `WarpShfl` to the threads `(ph 4 3).1` on the
memory phase 3 starts on. -/
example : ∃ Es, WarpRun (L 4) (c 4) 0 (ph 4 1).1 (ph 4 1).2 Es
    (memAt 4 (ph 4 3).1 (ph 4 3).2 4) := by
  refine warp 4 (.inl rfl) (fun i hi => ?_) fun _ _ => rfl
  interval_cases i
  · exact fires 4 (.inl rfl) 0 (by decide)
  beta_reduce
  clear * -

end MojoProofTest.SymChain
