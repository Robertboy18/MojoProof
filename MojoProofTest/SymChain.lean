import MojoProofTest.SymColl
import MojoProof.Sym.CanonBar
import MojoProof.Sym.WarpRoute
import MojoProof.Sym.WarpWaits

/-!
# Canonical runs by invariants: a barrier and two shuffles on blocks of 4 and of 8 threads

Tests of `BlockRun.of_inv` and `WarpWait.of_inv` with `PhaseRun.start_sound`
(MojoProof/Sym/CanonBar.lean), of `WarpRun.of_waits` (MojoProof/Sym/Canon.lean) through
`warp_route` and `WarpRun.shfl_of` (MojoProof/Sym/WarpRoute.lean), of `WarpWait.of_waits` and
`statusAt` (MojoProof/Sym/WarpWaits.lean) and of `WarpShfl.of_waits` (MojoProof/Sym/Canon.lean),
at two sizes: the kernel
`kern` of MojoProofTest/SymColl.lean (`tid.x`, a barrier, a butterfly shuffle at offset 1 and an
`add`, one at offset 2 and an `add`, `ret`) launched on one block of `k` threads
(`launch2 1 1 k 1`, one warp), for `k = 4` and `k = 8`, on the empty memory with address choice
and oracle 0. One proof covers both sizes; the runs are evaluated at each.

* `ph k j`: the threads and memory phase `j` starts on (the start's; then past the barrier, past
  the first shuffle and past the second); `stat k j n`: the status thread `n` waits at in phase
  `j`; `memAt k t m i`: the memory after threads `0` to `i - 1` run in turn.
* `waits`: each phase's runs to its waits, as `runTo` computes them; `bar0`: the barrier
  (`BlockBar`); `fires`: the two shuffles (`WarpShfl`), lane `n` resumed with lane `n ^^^ 1`'s
  and then lane `n ^^^ 2`'s value, by `WarpShfl.of_waits` from the lanes' waits `SymColl.wt`;
  `checks`: the final trace's race and `!invariant.load` checks.
* `mem_past`: in phases 1 to 3 the memories after the threads in turn are the memory past the
  barrier; `mem_end`, its case of the returns. With `mem_end` the `example`s after `checks` and
  `warp` prove the statements at 67bd004 of `checks` and `warp`, on the memory the returns leave
  (and for `warp` from every threads that agree with `(ph k 1).1` on the block).
* `stops`: past the barrier the lanes' runs to the shuffles reach `stat k 1` and `stat k 2` on
  the memory past the barrier (`waits`, `mem_past`). With it, the `example` after it proves the
  statement at 67bd004 of the deleted `ends` from `lane` (its runs to the returns), the waiting
  threads by `ToWait.det`.
* `warp`: the warp's run past the barrier through the shuffles to the returns (`WarpRun`), by
  `warp_route`: each lane's run through its two waits `SymColl.ws` (`lane`, as `runTo` computes
  it) and the shuffles' deliveries checked by the kernel (`shfls`, `Piece.Wait.shflOk`).
* `shfl_wait`: past the barrier, the warp to the second shuffle's waits by `WarpWait.of_waits`
  at `J = 1`, from the lanes' runs through their waits (`lane`) and the first shuffle's premise
  from the waits (`WarpRun.shfl_of`), as `warp` is by `WarpRun.of_waits`; each lane's status is
  `statusAt` of its first delivery. The statements before, at 01391ef on the statuses `stat k 2`
  (by `stops` and `mem_past`) and at e42713c without `statusAt`, are the `example`s after it,
  from it.
* `sound_inv`: the launch is sound (`Grid.Sound`), by `PhaseRun.start_sound` at the block's run
  of `BlockRun.of_inv`: the warp to the barrier (`WarpWait.of_inv`), the barrier, then `warp`.
* The open-goal twin (an `example` with `#guard_msgs`): `warp` on 8 threads without the lanes'
  runs (`lane`) leaves `WarpRun.of_waits`' premise on them as the goal.

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

/-- **The memories past the barrier are the one past the barrier**, at 4 and at 8 threads: no
lane changes the memory after the barrier, so in phases 1 to 3 the memory after the first `n ≤ k`
threads' runs is `(ph k 1).2`, by the kernel. The bridge from the memories of the statements at
67bd004 and 01391ef (`memAt`'s, in turn) to the one memory of the lanes' runs (`lane`). -/
theorem mem_past (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ j, 1 ≤ j → j ≤ 3 → ∀ n ≤ k, memAt k (ph k j).1 (ph k j).2 n = (ph k 1).2 := by
  intro j h1 h3 n hn
  rcases hk with rfl | rfl <;> interval_cases j <;> interval_cases n <;> kernel_rfl

/-- **The memory the returns leave is the one past the barrier**, at 4 and at 8 threads: the
memory after the `k` threads' runs of phase 3 from `(ph k 3).1` is `(ph k 1).2` (`mem_past`). The
bridge from the statements of `checks` and `warp` at 67bd004, on that memory, to theirs. -/
theorem mem_end (k : Nat) (hk : k = 4 ∨ k = 8) : memAt k (ph k 3).1 (ph k 3).2 k = (ph k 1).2 :=
  mem_past k hk 3 (by omega) (Nat.le_refl 3) k (Nat.le_refl k)

/-- The final trace, on the memory past the barrier `(ph k 1).2` (no lane changes it after), has no
race and keeps the promise of `!invariant.load`, by the kernel, at 4 and at 8 threads. The
statement at 67bd004, on the memory the returns leave, is the `example` after it (by `mem_end`). -/
theorem checks (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ m', m' = (ph k 1).2 →
      ((∀ a, Event.access a ∈ m'.trace →
          a.who.thread < volume (L k).grid * volume (L k).block ∧
            a.who.cta = a.who.thread / volume (L k).block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore (L k))).reverse = false) ∧
        GPUProof.kept sig (m'.trace.map (Event.toCore (L k))).reverse = true := by
  rw [size k hk]
  intro m' hm
  subst hm
  rcases hk with rfl | rfl <;> exact ⟨fun _ _ => by decide +kernel, by decide +kernel⟩

-- `checks` at 67bd004: the final trace on the memory the returns leave, by `checks` and `mem_end`.
example (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ m', m' = memAt k (ph k 3).1 (ph k 3).2 (volume (L k).grid * volume (L k).block) →
      ((∀ a, Event.access a ∈ m'.trace →
          a.who.thread < volume (L k).grid * volume (L k).block ∧
            a.who.cta = a.who.thread / volume (L k).block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore (L k))).reverse = false) ∧
        GPUProof.kept sig (m'.trace.map (Event.toCore (L k))).reverse = true :=
  fun m' hm => checks k hk m' (by rw [hm, size k hk, mem_end k hk])

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

/-- **Lane `j` past the barrier through its two shuffles** (`RunsVia` at `Piece.Wait.via` of
block 0, the waits `SymColl.ws` on the memory past the barrier), as `runTo` computes it, at 4 and
at 8 threads: from `(ph k 1).1 j` to the first shuffle, from `(ph k 2).1 j` to the second and from
`(ph k 3).1 j` to its return, the memory unchanged. -/
theorem lane (k : Nat) (hk : k = 4 ∨ k = 8) : ∀ j < k, RunsVia (c k (0 + j)) (· = (ph k 1).2)
    ((SymColl.ws (ph k 1).2 j).map (Piece.Wait.via SymColl.kern 0)) ((ph k 1).1 (0 + j))
    (ph k 1).2 := by
  intro j hj
  refine ⟨stop k (ph k 1).1 (ph k 1).2 j, _, _, SymColl.shflDecl, (ph k 1).2,
    ToWait.of_runTo (fuel := 4) ?_, ⟨?_, rfl, rfl, rfl⟩, stop k (ph k 2).1 (ph k 2).2 j, _, _,
    SymColl.shflDecl, (ph k 1).2, ToWait.of_runTo (fuel := 4) ?_, ⟨?_, rfl, rfl, rfl⟩, (ph k 1).2,
    Runs.of_runTo (fuel := 4) (u := stop k (ph k 3).1 (ph k 3).2 j) (m₁ := (ph k 1).2) ?_, rfl⟩ <;>
    rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl

/-- **Past the barrier the lanes wait at `stat k 1` and `stat k 2`, on the memory past the
barrier**, at 4 and at 8 threads: for `i = 1, 2`, thread `n < k` runs from `(ph k i).1 n` on
`(ph k 1).2` to `stat k i n` on it, by `waits` and `mem_past`. A run to a wait is determined
(`ToWait.det`), so this is the bridge from the lanes' runs through their waits (`lane`,
`shfl_wait`) to the statuses `stat k i`, whose waiting threads and callee the waits do not
state. -/
theorem stops (k : Nat) (hk : k = 4 ∨ k = 8) : ∀ i, 1 ≤ i → i < 3 → ∀ n < k,
    ToWait (c k n) ((ph k i).1 n) (ph k 1).2 (stat k i n) (ph k 1).2 := by
  intro i h1 h3 n hn
  obtain ⟨s, m', h, rfl, rfl⟩ := waits k hk i h3 n (by rw [size k hk]; exact hn) _ _ rfl rfl
  rwa [mem_past k hk i h1 (by omega) n (by omega), mem_past k hk i h1 (by omega) (n + 1) hn] at h

-- `ends` at 67bd004 (deleted; `lane` has these runs as its last): the runs to the returns, thread
-- `n` from `(ph k 3).1 n` on the memory after the threads before it, by `lane`: its waiting threads
-- are `stat k 1`'s and `stat k 2`'s (`stops`, `ToWait.det`) and its memories `mem_past`'s.
example (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ n < volume (L k).grid * volume (L k).block, ∀ t m, t = (ph k 3).1 n →
      m = memAt k (ph k 3).1 (ph k 3).2 n →
      ∃ m', Runs (c k n) t m m' ∧ m' = memAt k (ph k 3).1 (ph k 3).2 (n + 1) := by
  rw [size k hk]
  intro n hn t m ht hm
  subst ht hm
  have hl := lane k hk n hn
  rw [Nat.zero_add] at hl
  obtain ⟨u₁, _, _, _, m₁, h₁, -, u₂, _, _, _, m₂, h₂, -, m', hr, rfl⟩ := hl
  obtain ⟨e₁, rfl⟩ := ToWait.det h₁ (stops k hk 1 (Nat.le_refl 1) (by omega) n hn)
  obtain ⟨rfl, -, -, -⟩ := Status.wait.inj e₁
  obtain ⟨e₂, rfl⟩ := ToWait.det h₂ (stops k hk 2 (by omega) (by omega) n hn)
  obtain ⟨rfl, -, -, -⟩ := Status.wait.inj e₂
  rw [mem_past k hk 3 (by omega) (Nat.le_refl 3) n (by omega),
    mem_past k hk 3 (by omega) (Nat.le_refl 3) (n + 1) hn]
  exact ⟨_, hr, rfl⟩

/-- Each lane has two waits and runs `SymColl.prog`. -/
theorem progs (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ j < k, (SymColl.ws (ph k 1).2 j).length = 2 ∧ (c k (0 + j)).prog = SymColl.prog :=
  fun j hj => ⟨rfl, by rcases hk with rfl | rfl <;> interval_cases j <;> rfl⟩

/-- **The lanes' waits are the two butterfly shuffles** (`Piece.Wait.shflOk`) at 4 and at 8
threads: at positions 2 and 4, offsets 1 and 2, clamp 31, lane `j` offering `SymColl.x i j` and
delivered what `Grid.fire` delivers, by the kernel. -/
theorem shfls (k : Nat) (hk : k = 4 ∨ k = 8) : ∀ j < k, Piece.Wait.shflOk (warpLanes (L k) 0)
    (fun _ => .bfly) (fun i => if i = 0 then 2 else 4) (fun i => if i = 0 then 1 else 2)
    (fun _ => 31) SymColl.x ⟨0, .barrier, [], {}, (none, {})⟩ 2 j (SymColl.ws (ph k 1).2 j) =
      true := by
  rcases hk with rfl | rfl <;> decide +kernel

/-- The shuffles (phases 1 and 2, `WarpShfl`), in the form `WarpWait.of_inv` (at `J = 1`, the
first) and `WarpRun.of_inv` (at `J = 2`) take, at 4 and at 8 threads: from every statuses at
`stat k (i + 1)` on the memory the phase's runs leave, the warp's butterfly shuffle at offset
`i + 1` fires, lane `j` resumed from the thread it stops at with `res (i + 1) j` (lane
`j ^^^ (i + 1)`'s value), to `(ph k (i + 2)).1`; a shuffle leaves the memory unchanged. By
`WarpShfl.of_waits` at the lanes' `i`-th waits `SymColl.wt (ph k 1).2 i`: the statuses at their
positions, calls and arguments, the threads' positions by the kernel, and the deliveries by
`WarpRun.shfl_of` from `shfls` and `Program.shfl_nil`. -/
theorem fires (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ i < 2, ∀ s : Nat → Status, (∀ j ∈ warpLanes (L k) 0, s j = stat k (i + 1) j) →
      ∀ m, m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 (warpLanes (L k) 0).length →
      ∃ u r, WarpShfl (L k) (c k) 0 s m u r ∧
        (∀ j ∈ warpLanes (L k) 0, (u j).resume (r j) = (ph k (i + 1 + 1)).1 j) ∧
        m = memAt k (ph k (i + 1 + 1)).1 (ph k (i + 1 + 1)).2 0 := by
  intro i hi s hs m hm
  have hl : ∀ j ∈ warpLanes (L k) 0, j < k := fun j hj => List.mem_range.1 (lanes k hk ▸ hj)
  refine ⟨stop k (ph k (i + 1)).1 (ph k (i + 1)).2, res (i + 1), ?_, fun j _ => rfl, ?_⟩
  · have h := WarpShfl.of_waits (L := L k) (c := c k) (k := 0) (fn := SymColl.kern) (l := 0)
      (W := SymColl.wt (ph k 1).2 i) (mo := .bfly) (X := SymColl.x i) (m := m) (s := s)
      (u := stop k (ph k (i + 1)).1 (ph k (i + 1)).2) (fun j hj => ?_)
      (WarpRun.shfl_of (L := L k) (c := c k) (k := 0) (P := SymColl.prog) (mo := fun _ => .bfly)
        (M := fun _ => m) (fun j hj => (progs k hk j (hl j hj)).2)
        (fun j hj => shfls k hk j (hl j hj))
        (fun _ _ _ _ => Program.shfl_nil (by decide)) i hi)
    · interval_cases i <;> exact h
    · have hP := (progs k hk j (hl j hj)).2
      have hj' := hl j hj
      rw [hs j hj, hP]
      interval_cases i <;> refine ⟨SymColl.shflDecl, rfl, ?_, SymColl.shflName, rfl, rfl⟩ <;>
        rcases hk with rfl | rfl <;> interval_cases j <;> kernel_rfl
  · rw [memAt.eq_1, hm, lanes k hk, List.length_range]
    interval_cases i <;> rfl

/-- **The warp past the barrier through the two shuffles** (`WarpRun`), from `(ph k 1).1` on the
memory past the barrier to that memory, at 4 and at 8 threads, by `warp_route`: `WarpRun.of_waits`
with the lanes' runs by `lane` (`RunsVia.of_block`) and the shuffles by `WarpRun.shfl_of`, from
`shfls` and `Program.shfl_nil`; so each shuffle's deliveries are `Grid.fire`'s (`WarpShfl`). The
statement at 67bd004, from every threads that agree with `(ph k 1).1` on the block to the memory
the returns leave, is the `example` after it (by `mem_end`). -/
theorem warp (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∃ Es, WarpRun (L k) (c k) 0 (ph k 1).1 (ph k 1).2 Es (ph k 1).2 := by
  have hN : (warpLanes (L k) 0).length = k := by rw [lanes k hk, List.length_range]
  have hl := lane k hk
  have hw := progs k hk
  have hs := shfls k hk
  warp_route (J := 2) (fn := SymColl.kern) (lbl := fun _ => 0) (W := SymColl.wt (ph k 1).2)
    (mo := fun _ => .bfly) (X := SymColl.x) (M := fun _ _ => (ph k 1).2) using SymColl.mems,
    Program.shfl_nil (P := SymColl.prog) (by decide)

-- `warp` at 67bd004: from every shuffles of `fires`' form (a premise `warp` does not need) and
-- threads `t` that agree with `(ph k 1).1` on the block, to the memory the returns leave, by `warp`
-- and `mem_end`, the lanes' first runs from `t` (`Turns.imp`).
example (k : Nat) (hk : k = 4 ∨ k = 8) {t : Nat → Thread}
    (_hf : ∀ i < 2, ∀ s : Nat → Status, (∀ j ∈ warpLanes (L k) 0, s j = stat k (i + 1) j) →
      ∀ m, m = memAt k (ph k (i + 1)).1 (ph k (i + 1)).2 (warpLanes (L k) 0).length →
      ∃ u r, WarpShfl (L k) (c k) 0 s m u r ∧
        (∀ j ∈ warpLanes (L k) 0, (u j).resume (r j) = (ph k (i + 1 + 1)).1 j) ∧
        m = memAt k (ph k (i + 1 + 1)).1 (ph k (i + 1 + 1)).2 0)
    (ht : ∀ n < k, t n = (ph k 1).1 n) :
    ∃ Es, WarpRun (L k) (c k) 0 t (ph k 1).2 Es (memAt k (ph k 3).1 (ph k 3).2 k) := by
  obtain ⟨Es, hw⟩ := warp k hk
  have hT : warpThreads (L k) 0 = List.range k := by rcases hk with rfl | rfl <;> decide
  have hR {R : Nat → Thread → Mem → Mem → Prop} : ∀ n ∈ warpThreads (L k) 0, ∀ m₁ m₂,
      R n ((ph k 1).1 n) m₁ m₂ → True → R n (t n) m₁ m₂ ∧ True := fun n hn _ _ h _ =>
    ⟨ht n (List.mem_range.1 (hT ▸ hn)) ▸ h, trivial⟩
  rw [mem_end k hk]
  rcases hw with h | ⟨h, hs, hr⟩
  · exact ⟨Es, .ends (h.imp (hR (R := fun n t => Runs (c k n) t)) trivial).1⟩
  · exact ⟨_, .shfl (h.imp (hR (R := fun n t m m' => ToWait (c k n) t m _ m')) trivial).1 hs hr⟩

/-- **The warp past the barrier to the second shuffle's waits, by `WarpWait.of_waits` at
`J = 1`**, at 4 and at 8 threads: from the lanes' runs through their two waits `SymColl.ws` on
the memory past the barrier (`lane`, `RunsVia.of_block`) and the first shuffle's premise from the
waits (`WarpRun.shfl_of` from `shfls` and `Program.shfl_nil`), the warp runs from `(ph k 1).1` on
that memory to the second shuffle's waits on it, the first shuffle `Grid.fire`'s (`WarpShfl`).
There lane `j` waits at `kern`'s block 0, position 4, at the butterfly shuffle at offset 2
offering `SymColl.a3 j`; its status is the one its thread reaches from `(ph k 1).1 j` on that
memory after the first shuffle's delivery `SymColl.r2 j` (`statusAt`); and resumed with
`SymColl.r3 j` (lane `j ^^^ 2`'s offer) it runs to its return, the memory unchanged. The
statements before are the `example`s after it, from it: at 01391ef, on the statuses `stat k 2`
and the memory `memAt k (ph k 2).1 (ph k 2).2 k` (by `stops` and `mem_past`), and at e42713c,
without the `statusAt` part. -/
theorem shfl_wait (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∃ s Es, WarpWait (L k) (c k) 0 (ph k 1).1 (ph k 1).2 Es s (ph k 1).2 ∧ ∀ j < k, ∃ u e,
      s j = .wait u (.shfl .bfly) [.bits 32 (-1), SymColl.a3 j, .bits 32 2, .bits 32 31] e ∧
      s j = statusAt (c k j) [(SymColl.r2 j, (ph k 1).2)] ((ph k 1).1 j) (ph k 1).2 ∧
      u.at = some (SymColl.kern.name, 0, 4) ∧
      Runs (c k j) (u.resume (SymColl.r3 j)) (ph k 1).2 (ph k 1).2 := by
  have hl : ∀ j ∈ warpLanes (L k) 0, j < k := fun j hj => List.mem_range.1 (lanes k hk ▸ hj)
  obtain ⟨s, Es, h, hs⟩ := WarpWait.of_waits (L := L k) (c := c k) (k := 0) (J := 1) (N := 2)
    (fn := SymColl.kern) (lbl := fun _ => 0) (W := SymColl.wt (ph k 1).2) (mo := fun _ => .bfly)
    (X := SymColl.x) (M := fun _ _ => (ph k 1).2) (Q := fun _ => (· = (ph k 1).2))
    (t := (ph k 1).1) (by omega)
    (fun j hj => RunsVia.of_block (lane k hk j (hl j hj)) rfl (fun _ _ => rfl) fun _ h => h)
    (fun i hi => WarpRun.shfl_of (L := L k) (c := c k) (k := 0) (P := SymColl.prog)
      (mo := fun _ => .bfly) (M := fun _ => (ph k 1).2) (fun j hj => (progs k hk j (hl j hj)).2)
      (fun j hj => shfls k hk j (hl j hj))
      (fun _ _ _ _ => Program.shfl_nil (by decide)) i (by omega))
    (fun i hi j hj => SymColl.mems i (by omega) j hj)
    (fun j hj => (SymColl.mems 1 (by omega) j hj).1)
    (fun _ _ => rfl)
  refine ⟨s, Es, h, fun j hj => ?_⟩
  obtain ⟨u, e, hsj, hst, hat, m', hr, rfl⟩ := hs j (lanes k hk ▸ List.mem_range.2 hj)
  rw [Nat.zero_add] at hsj hst hr
  exact ⟨u, e, hsj, hst, hat, hr⟩

-- `shfl_wait` at 01391ef: the warp to the second shuffle's waits at the statuses `stat k 2`, on the
-- memory that phase's runs leave, by `shfl_wait`: its statuses are `statusAt`'s, which are
-- `stat k 2`'s by `stops` (`nextWait_eq`), and its memory is that one by `mem_past`.
example (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∃ s Es, WarpWait (L k) (c k) 0 (ph k 1).1 (ph k 1).2 Es s
      (memAt k (ph k 2).1 (ph k 2).2 k) ∧ ∀ n < k, s n = stat k 2 n := by
  obtain ⟨s, Es, h, hs⟩ := shfl_wait k hk
  refine ⟨s, Es, by rw [mem_past k hk 2 (by omega) (by omega) k (Nat.le_refl k)]; exact h,
    fun n hn => ?_⟩
  obtain ⟨-, -, -, hsn, -⟩ := hs n hn
  rw [hsn, statusAt, nextWait_eq (stops k hk 1 (Nat.le_refl 1) (by omega) n hn)]
  exact congrArg Prod.fst (nextWait_eq (stops k hk 2 (by omega) (by omega) n hn))

-- `shfl_wait` at e42713c: each lane's status a wait at the second shuffle's position, call and
-- arguments, from which it runs to its return; `shfl_wait` without its `statusAt` part.
example (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∃ s Es, WarpWait (L k) (c k) 0 (ph k 1).1 (ph k 1).2 Es s (ph k 1).2 ∧ ∀ j < k, ∃ u e,
      s j = .wait u (.shfl .bfly) [.bits 32 (-1), SymColl.a3 j, .bits 32 2, .bits 32 31] e ∧
      u.at = some (SymColl.kern.name, 0, 4) ∧
      Runs (c k j) (u.resume (SymColl.r3 j)) (ph k 1).2 (ph k 1).2 := by
  obtain ⟨s, Es, h, hs⟩ := shfl_wait k hk
  refine ⟨s, Es, h, fun j hj => ?_⟩
  obtain ⟨u, e, h₁, -, h₂, h₃⟩ := hs j hj
  exact ⟨u, e, h₁, h₂, h₃⟩

/-- **The launch on 4 and on 8 threads is sound, by invariants**: `PhaseRun.start_sound` at the
run of the one block, by `BlockRun.of_inv` at one barrier: phase 0 the warp's run to the barrier
(`WarpWait.of_inv` with the runs `waits`) and the barrier `bar0`, the last phase the warp's run
through the shuffles (`warp`); the threads of phase `j` `(ph k j).1`, their statuses `stat k 0`
and the memory after `i` threads `memAt k (ph k 0).1 (ph k 0).2 i` in phase 0; the final trace's
`checks`. A test of `BlockRun.of_inv` at two sizes. -/
theorem sound_inv (k : Nat) (hk : k = 4 ∨ k = 8) :
    Grid.Sound (L k) (c k) (g0 k) (fun _ => some ()) fun _ => True := by
  have hb : blockWarps (L k) 0 = [0] := by rcases hk with rfl | rfl <;> decide
  obtain ⟨Es, m', hr, rfl⟩ := BlockRun.of_inv (L := L k) (c := c k) (b := 0) (J := 1)
    (T := fun i t => t = (ph k i).1)
    (P := fun i m => m = match i with | 0 => (ph k 0).2 | _ => (ph k 1).2)
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
        (t := t) (fun j _ => by rw [Nat.zero_add]; exact congrFun ht j) (m := m) (by
          rw [memAt.eq_1]; exact hm)
      rw [lanes k hk, List.length_range] at hm₁
      refine ⟨stat k 0, stop k (ph k 0).1 (ph k 0).2, Es ++ [], m₁, ?_, bar0 k hk, rfl,
        by rw [hm₁]; rfl⟩
      rw [hb]
      exact .cons (hw.congr fun n hn => by
        obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hn
        simpa only [Nat.zero_add] using hs j hj) (.nil _))
    (fun t m ht hm => by
      obtain ⟨Es, hw⟩ := warp k hk
      subst ht hm
      refine ⟨Es ++ [], _, ?_, rfl⟩
      rw [hb]
      exact .cons hw (.nil _))
    (t := Grid.thread (g0 k)) rfl (m := (g0 k).mem) rfl
  have hc : PhaseRun (L k) (c k) (Grid.thread (g0 k)) [0] (g0 k).mem _ _ := .cons hr (.nil _)
  rw [show [0] = List.range (volume (L k).grid) by rcases hk with rfl | rfl <;> rfl] at hc
  have hC := checks k hk _ rfl
  exact PhaseRun.start_sound (start_eq k hk) (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl)
    (by rw [block k hk]; rcases hk with rfl | rfl <;> decide) hc ⟨hC.1, hC.2, (), rfl, trivial⟩

/--
error: unsolved goals
case refine_1
⊢ ∀ j ∈ warpLanes (L 8) 0,
    RunsVia (c 8 (0 + j)) (fun x => x = (ph 8 1).2)
      (List.map (fun i => Piece.Wait.via SymColl.kern 0 (SymColl.wt (ph 8 1).2 i j)) (List.range 2))
      ((ph 8 1).1 (0 + j)) (ph 8 1).2
-/
#guard_msgs in
/-- **The open-goal twin**: the warp's run past the barrier on 8 threads without the lanes' runs
(`lane`) leaves `WarpRun.of_waits`' premise on the lanes' runs (`hr`) as the goal. -/
example : ∃ Es, WarpRun (L 8) (c 8) 0 (ph 8 1).1 (ph 8 1).2 Es (ph 8 1).2 := by
  have hN : (warpLanes (L 8) 0).length = 8 := by decide
  have hw := progs 8 (.inr rfl)
  have hs := shfls 8 (.inr rfl)
  warp_route (J := 2) (fn := SymColl.kern) (lbl := fun _ => 0) (W := SymColl.wt (ph 8 1).2)
    (mo := fun _ => .bfly) (X := SymColl.x) (M := fun _ _ => (ph 8 1).2) using SymColl.mems,
    Program.shfl_nil (P := SymColl.prog) (by decide)
  clear * -

end MojoProofTest.SymChain
