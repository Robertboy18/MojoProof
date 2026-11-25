import MojoProofTest.SymColl
import MojoProof.Sym.SchedChain

/-!
# Schedules by invariants: a barrier and two shuffles on blocks of 4 and of 8 threads

Tests of `Sched.start_sound_inv`, `Fires.barriers_at` and `Fires.bfly`
(MojoProof/Sym/SchedChain.lean) at two sizes: the kernel `kern` of MojoProofTest/SymColl.lean
(`tid.x`, a barrier, a butterfly shuffle at offset 1 and an `add`, one at offset 2 and an `add`,
`ret`) launched on one block of `k` threads (`launch2 1 1 k 1`), for `k = 4` and `k = 8`, on the
empty memory with address choice and oracle 0. One proof covers both sizes; the runs are
evaluated at each.

* `ph k j`: the threads and memory phase `j` starts on (the start's; then past the barrier, past
  the first shuffle and past the second); `stat k j n`: the status thread `n` waits at in phase
  `j`; `memAt k t m i`: the memory after threads `0` to `i - 1` run in turn.
* `waits`, `ends`: each phase's runs, as `runTo` computes them; `fire0`: the barrier, by
  `Fires.barriers_at`; `fire1`, `fire2`: the shuffles, by `Fires.bfly`, lane `n` resumed with lane
  `n ^^^ o`'s value; `checks`: the final trace's race and `!invariant.load` checks.
* `sound_inv`: the launch is sound (`Grid.Sound`), by `Sched.start_sound_inv` at three phases.
* The open-goal twin (an `example` with `#guard_msgs`): `Sched.start_sound_inv` with the second
  shuffle's fire left out leaves that phase's fire as the goal.

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

/-- The barrier (phase 0), by `Fires.barriers_at`: the threads at `stat k 0` resumed to
`(ph k 1).1`, the memory with the block's `.barrier` logged. -/
theorem fire0 (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ s : Nat → Status, (∀ n < volume (L k).grid * volume (L k).block, s n = stat k 0 n) →
      ∀ m, m = memAt k (ph k 0).1 (ph k 0).2 (volume (L k).grid * volume (L k).block) →
      ∃ t' m', Fires (L k) (c k) (volume (L k).grid * volume (L k).block) s m t' m' ∧
        (∀ n < volume (L k).grid * volume (L k).block, t' n = (ph k 1).1 n) ∧
        m' = memAt k (ph k 1).1 (ph k 1).2 0 := by
  rw [size k hk]
  intro s hs m hm
  subst hm
  obtain ⟨t', hF, ht'⟩ := Fires.barriers_at (L := L k) (c := c k) (N := k) (B := 1) (s := s)
    (bar := fun _ => 0) (a := fun _ => (stop k (ph k 0).1 (ph k 0).2 0).at)
    (m := memAt k (ph k 0).1 (ph k 0).2 k) (by rw [block k hk]; rcases hk with rfl | rfl <;> decide)
    (by rw [block k hk, Nat.one_mul])
    fun n hn => ⟨_, .bits 32 0, Launch.barrierDecl, hs n hn, rfl, show 0 < 16 by decide,
      by rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl⟩
  refine ⟨t', _, hF, fun n hn => ?_, (memAt.eq_1 _ _ _).symm⟩
  obtain ⟨u, i, as, d, e, e'⟩ := ht' n hn
  obtain ⟨rfl, -⟩ := Status.wait.inj ((hs n hn).symm.trans e)
  exact e'

/-- The first shuffle (phase 1), by `Fires.bfly` at offset 1: lane `n` resumed with lane
`n ^^^ 1`'s thread number, to `(ph k 2).1`. -/
theorem fire1 (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ s : Nat → Status, (∀ n < volume (L k).grid * volume (L k).block, s n = stat k 1 n) →
      ∀ m, m = memAt k (ph k 1).1 (ph k 1).2 (volume (L k).grid * volume (L k).block) →
      ∃ t' m', Fires (L k) (c k) (volume (L k).grid * volume (L k).block) s m t' m' ∧
        (∀ n < volume (L k).grid * volume (L k).block, t' n = (ph k 2).1 n) ∧
        m' = memAt k (ph k 2).1 (ph k 2).2 0 := by
  rw [size k hk]
  intro s hs m hm
  subst hm
  obtain ⟨t', hF, ht'⟩ := Fires.bfly (L := L k) (c := c k) (N := k) (B := 1) (o := 1) (s := s)
    (A := fun n => .bits 32 (.ofNat 32 n)) (a := fun _ => (stop k (ph k 1).1 (ph k 1).2 0).at)
    (m := memAt k (ph k 1).1 (ph k 1).2 k) (by rw [block k hk]; rcases hk with rfl | rfl <;> decide)
    (by rw [block k hk, Nat.one_mul]) (by decide)
    fun n hn => ⟨_, .bits 32 (-1), .bits 32 1, .bits 32 31, SymColl.shflDecl, hs n hn, rfl, rfl,
      rfl, by rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl, rfl, rfl,
      by rw [block k hk]; rcases hk with rfl | rfl <;> interval_cases n <;> decide⟩
  refine ⟨t', _, hF, fun n hn => ?_, (memAt.eq_1 _ _ _).symm⟩
  obtain ⟨u, i, as, d, e, e'⟩ := ht' n hn
  obtain ⟨rfl, -⟩ := Status.wait.inj ((hs n hn).symm.trans e)
  rw [e']
  rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl

/-- The second shuffle (phase 2), by `Fires.bfly` at offset 2: lane `n` resumed with lane
`n ^^^ 2`'s `SymColl.a3`, to `(ph k 3).1`. -/
theorem fire2 (k : Nat) (hk : k = 4 ∨ k = 8) :
    ∀ s : Nat → Status, (∀ n < volume (L k).grid * volume (L k).block, s n = stat k 2 n) →
      ∀ m, m = memAt k (ph k 2).1 (ph k 2).2 (volume (L k).grid * volume (L k).block) →
      ∃ t' m', Fires (L k) (c k) (volume (L k).grid * volume (L k).block) s m t' m' ∧
        (∀ n < volume (L k).grid * volume (L k).block, t' n = (ph k 3).1 n) ∧
        m' = memAt k (ph k 3).1 (ph k 3).2 0 := by
  rw [size k hk]
  intro s hs m hm
  subst hm
  obtain ⟨t', hF, ht'⟩ := Fires.bfly (L := L k) (c := c k) (N := k) (B := 1) (o := 2) (s := s)
    (A := SymColl.a3) (a := fun _ => (stop k (ph k 2).1 (ph k 2).2 0).at)
    (m := memAt k (ph k 2).1 (ph k 2).2 k) (by rw [block k hk]; rcases hk with rfl | rfl <;> decide)
    (by rw [block k hk, Nat.one_mul]) (by decide)
    fun n hn => ⟨_, .bits 32 (-1), .bits 32 2, .bits 32 31, SymColl.shflDecl, hs n hn, rfl, rfl,
      rfl, by rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl, rfl, rfl,
      by rw [block k hk]; rcases hk with rfl | rfl <;> interval_cases n <;> decide⟩
  refine ⟨t', _, hF, fun n hn => ?_, (memAt.eq_1 _ _ _).symm⟩
  obtain ⟨u, i, as, d, e, e'⟩ := ht' n hn
  obtain ⟨rfl, -⟩ := Status.wait.inj ((hs n hn).symm.trans e)
  rw [e']
  rcases hk with rfl | rfl <;> interval_cases n <;> kernel_rfl

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

/-- **The launch on 4 and on 8 threads is sound, by invariants**: `Sched.start_sound_inv` at
three phases with thread `n` of phase `j` at `(ph k j).1 n`, its status `stat k j n` and the
memory after `i` threads `memAt k (ph k j).1 (ph k j).2 i`: the runs `waits` and `ends`, the fires
`fire0` (`Fires.barriers_at`), `fire1` and `fire2` (`Fires.bfly`), the final trace's `checks`. A
test of `Sched.start_sound_inv` at two sizes. -/
theorem sound_inv (k : Nat) (hk : k = 4 ∨ k = 8) :
    Grid.Sound (L k) (c k) (g0 k) (fun _ => some ()) fun _ => True :=
  Sched.start_sound_inv (J := 3) (T := fun j n t => t = (ph k j).1 n)
    (W := fun j n s => s = stat k j n) (P := fun j i m => m = memAt k (ph k j).1 (ph k j).2 i)
    (start_eq k hk) (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl) (fun _ _ => rfl)
    (memAt.eq_1 _ _ _).symm (waits k hk)
    (fun j hj => by interval_cases j; exacts [fire0 k hk, fire1 k hk, fire2 k hk]) (ends k hk)
    (checks k hk) fun _ _ => ⟨(), rfl, trivial⟩

/--
error: unsolved goals
case «2»
⊢ ∀ (s : ℕ → Status),
    (∀ n < volume (L 4).grid * volume (L 4).block, s n = stat 4 2 n) →
      ∀ (m : Mem),
        m = memAt 4 (ph 4 2).1 (ph 4 2).2 (volume (L 4).grid * volume (L 4).block) →
          ∃ t' m',
            Fires (L 4) (c 4) (volume (L 4).grid * volume (L 4).block) s m t' m' ∧
              (∀ n < volume (L 4).grid * volume (L 4).block, t' n = (ph 4 (2 + 1)).1 n) ∧
                m' = memAt 4 (ph 4 (2 + 1)).1 (ph 4 (2 + 1)).2 0
-/
#guard_msgs in
/-- **The open-goal twin**: `Sched.start_sound_inv` on 4 threads with the second shuffle's fire
(phase 2) left out leaves that phase's fire as the goal: from the statuses `stat 4 2` on the
memory the phase's runs leave, a `Fires` to the threads `(ph 4 3).1` on the memory phase 3 starts
on. -/
example : Grid.Sound (L 4) (c 4) (g0 4) (fun _ => some ()) fun _ => True := by
  refine Sched.start_sound_inv (J := 3) (T := fun j n t => t = (ph 4 j).1 n)
    (W := fun j n s => s = stat 4 j n) (P := fun j i m => m = memAt 4 (ph 4 j).1 (ph 4 j).2 i)
    (start_eq 4 (.inl rfl)) (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl)
    (fun _ _ => rfl) (memAt.eq_1 _ _ _).symm (waits 4 (.inl rfl)) (fun j hj => ?_)
    (ends 4 (.inl rfl)) (checks 4 (.inl rfl)) fun _ _ => ⟨(), rfl, trivial⟩
  interval_cases j
  · exact fire0 4 (.inl rfl)
  · exact fire1 4 (.inl rfl)
  beta_reduce
  clear * -

end MojoProofTest.SymChain
