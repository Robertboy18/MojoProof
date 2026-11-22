import MojoProof.Sem.Bad
import MojoProofTest.Confluence

/-!
# Instances and twins of `Grid.RaceEnabled`, `Grid.Same.bad`, `Grid.Step.raceEnabled`, the
faults part of `bad_step` (`Grid.fire_error_advance`, `Grid.fire_error_fire`, `Mem.update_before`,
`Grid.advance_fault_atomic`, `Grid.Step.bad`), `Grid.start_reach_bad_trace` and
`Grid.start_reach_bad`

The instance of `Grid.RaceEnabled`, and why `Grid.Bad` has it: on `stores 0` after thread 0's
store to bytes 0 to 3 of block 1, the trace is not racy, but thread 1's pending store to the same
bytes races with it (`race_enabled`).

The instance of `Grid.Same.bad`: the grid `racer` of thread 0 at a store to bytes 0 to 3 of block
1, after writes of bytes 4 to 7 by thread 1 and of bytes 0 to 3 by thread 2, has a trace that is
not racy and an enabled race; with the two writes in the other order the grid is the same, so it
is bad (`same_bad`).

The instance of `Grid.Step.raceEnabled` at a collective call: in the contexts `ctxB` (thread `n`
of block of threads `n`), on `fires` (thread 0 at barrier 0, thread 1 at a store to bytes 4 to 7
of block 1, after a write of those bytes by thread 0), which is closed, thread 1's store races, and
no completing call logs a barrier of a running thread's block of threads; after the barrier
completes the race is still enabled (`fire_race`). The twin of that premise: in the contexts
`ctxOf` (both threads of block of threads 0) the barrier logs a barrier of thread 1's block of
threads, thread 1's store races before it, and after it the trace is not racy and no race is
enabled (`fire_race_twin`).

The instances of the faults part of `bad_step`, on `faulter o o'` (threads 0 and 1 at stores to
offsets `o` and `o'` of the block of 8 bytes of `Closed.mem1`), closed, with owned allocas and no
waiting thread: on `faulter 8 0` thread 0's store faults, thread 1's overlaps none of its
accesses, and after thread 1's step thread 0's store still faults (`fault_stays`,
`Grid.advance_fault`) and the grid is bad (`fault_bad`, `Grid.Step.bad`); on `faulter 6 4` thread
1's store overlaps thread 0's faulting one, and after it a race is enabled (`fault_race`,
`Grid.Step.advance_fault`).

The instances of `Grid.fire_error_advance` and `Grid.fire_error_fire`, on `poisonBar` (thread 0
waiting at a barrier whose number is poison, thread 1 at a store, thread 2 at barrier 0, on
`Closed.mem1`) in the contexts `ctxB`: thread 0's barrier faults, and it still faults after thread
1's store and after thread 2's barrier completes (`fire_error_stays`).

The twin of `Grid.Step.bad`'s premise that the contexts have one layout: in `ctxL` (64-bit
pointers for thread 0, 32-bit for thread 1) on `ptrsU` (both threads waiting at a shuffle of a
pointer whose result is `nonnull` and `noundef`), closed, with owned allocas, no running thread
and no pending access, thread 1's fire faults, since the pointer's address is 0 under its layout,
so the grid is bad; thread 0's fire completes, and the grid after it is not bad
(`fire_fault_twin`).

The instance of `Mem.update_before` and the twin of its premise that the later update's operand
is a scalar: on `memZ`, thread 1's `max` by poison stores poison (`max_poison`); after it
thread 0's `max` by `5` and by a pointer succeed, as `max` of poison by either is poison
(`max_ok`); so by `Mem.update_before` the one by `5` succeeds before it, while the one by the
pointer, not a scalar of width 32, faults before it, as `max` of the word 0 by a pointer faults
(`max_fault`, `update_before`). The instance of `Grid.advance_fault_atomic` and of `Grid.Step.bad`
beside an exempt pair: in `ctxOf` on `maxes` (thread 0 at `atomicrmw max ptr %0, i32 %0`, whose
operand is the pointer, and thread 1 at `atomicrmw max ptr %0, i32 poison`, on `memZ`), closed,
with owned allocas and no waiting thread, the two threads' pending writes are an exempt pair;
thread 0's step faults at `exec`'s check of its operand (`advance_rmw_fault`), thread 1's step
succeeds, and after it thread 0's step still faults and the grid is bad (`rmw_fault`).

The instance of `Grid.start_reach_bad_trace`: the launch `startP` of a store of `i32 7` to its
pointer argument on two threads, with a pointer to block 1 of `Close.mem (some 5)`, starts; after
thread 0's store the trace is not racy but thread 1's store races, and after it the trace is racy
(`start_bad`). The instance of `Grid.start_reach_bad`: the launch `startF` of an `alloca` and that
store on two threads, with a pointer to byte 4 of block 1, of 4 bytes, of `Close.mem none`; after
thread 0's `alloca` its store faults, and after thread 1's `alloca` thread 0's store still faults
and the grid is bad (`start_fault`).

The twin of `Grid.Step.bad`'s premise that the grid is closed, a thread that names a number with
no block: in `ctxOf` on `dangle` (thread 0 at `ptrtoint` of a pointer
to block 4, which is not below `next` and has no block, and thread 1 at `alloca i32`, on
`Closed.mem1`), not closed, with owned allocas, no collective call that completes and one layout,
thread 0's step faults, so the grid is bad; thread 1's `alloca` makes block 4, and the grid after
it is not bad (`closed_twin`).

Statements about these grids and launches, not about every grid or launch.
-/

namespace MojoProofTest.Bad

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending MojoProofTest.Confluence

/-- The instance of `Grid.RaceEnabled`: on `stores 0`, after thread 0's store to bytes 0 to 3 of
block 1, the trace is not racy, but thread 1's pending store to those bytes races with it. -/
theorem race_enabled : ∃ gn, (stores 0).advance ctxOf 0 = .ok (some gn) ∧
    racy gn.mem.trace = false ∧ gn.RaceEnabled ctxOf :=
  ⟨_, rfl, rfl, 1, _, rfl, rfl⟩

/-- Thread 0 at a store to bytes 0 to 3 of block 1 after the write `e` and then the write `e'`. -/
def racer (e e' : Event) : Grid :=
  { threads := #[.run (storerAt 8 0)], mem := (Closed.mem1.log e).log e' }

/-- The instance of `Grid.Same.bad`: with a write of bytes 4 to 7 by thread 1 and one of bytes 0
to 3 by thread 2 in either order, the two grids are the same, neither trace is racy, and thread
0's store races in the first, so both are bad. -/
theorem same_bad : (racer (ev 1 4) (ev 2 0)).Same (racer (ev 2 0) (ev 1 4)) ∧
    racy (racer (ev 2 0) (ev 1 4)).mem.trace = false ∧
    (racer (ev 2 0) (ev 1 4)).Bad (Pending.launch 1) ctxOf :=
  have h : (racer (ev 1 4) (ev 2 0)).Same (racer (ev 2 0) (ev 1 4)) :=
    ⟨rfl, rfl, rfl, Trace.Same.swap₁ (by decide) []⟩
  ⟨h, rfl, h.bad (.inr (.inr (.inr ⟨0, _, rfl, rfl⟩)))⟩

/-- The thread at barrier 0 names no block. -/
theorem atBarrier_namesIn : atBarrier.NamesIn (· < 2) := by
  refine ⟨fun f hf r x hr => ?_, fun x hx => ?_⟩
  · simp only [thread, List.mem_singleton] at hf
    subst hf
    cases hr
  · simp only [List.mem_singleton] at hx
    subst hx
    trivial

/-- `fires` is closed in every contexts without globals. -/
theorem fires_closed {c : Nat → Ctx} (hc : ∀ n x, (c n).globals x = none) : fires.Closed c :=
  closed_of hc (fun _ _ _ => nofun) fun n s hs => by
    rcases n with _ | _ | n <;> simp at hs <;> subst hs
    · exact atBarrier_namesIn
    · exact storerAt_namesIn _ _

/-- The instance of `Grid.Step.raceEnabled` at a collective call: in the contexts `ctxB`, thread
1's store races on `fires`, the completing barrier of thread 0 logs a barrier of block of threads
0 only, and after it the race is still enabled. -/
theorem fire_race : fires.RaceEnabled ctxB ∧ ∃ gf,
    fires.fire (Pending.launch 1) ctxB 0 = .ok (some gf) ∧
    (racy gf.mem.trace = true ∨ gf.RaceEnabled ctxB) ∧ gf.RaceEnabled ctxB := by
  have he : fires.RaceEnabled ctxB := ⟨1, _, rfl, rfl⟩
  have hw : ∀ n k t gf, fires.threads[n]? = some (.run t) →
      fires.fire (Pending.launch 1) ctxB k = .ok (some gf) →
      .barrier (ctxB n).who.cta ∉ fires.fired (Pending.launch 1) k := fun n k t gf ht _ => by
    rcases n with _ | _ | n <;> simp [fires, atBarrier] at ht
    rcases k with _ | _ | k <;> simp [Grid.fired, fires, ctxB, atBarrier]
  refine ⟨he, _, rfl, Grid.Step.raceEnabled (fires_closed fun _ _ => rfl) hw ⟨0, .inr rfl⟩ he,
    1, _, rfl, rfl⟩

/-- The twin of `Grid.Step.raceEnabled`'s premise on barriers: in the contexts `ctxOf` the
barrier logs a barrier of block of threads 0, thread 1's, whose store races on `fires`; after the
barrier the trace is not racy and no race is enabled. -/
theorem fire_race_twin : .barrier (ctxOf 1).who.cta ∈ fires.fired (Pending.launch 1) 0 ∧
    fires.RaceEnabled ctxOf ∧ ∃ gf, fires.fire (Pending.launch 1) ctxOf 0 = .ok (some gf) ∧
      racy gf.mem.trace = false ∧ ¬ gf.RaceEnabled ctxOf := by
  refine ⟨by decide, ⟨1, _, rfl, rfl⟩, _, rfl, rfl, ?_⟩
  rintro ⟨n, t, ht, hr⟩
  rcases n with _ | _ | n <;> simp [fires, atBarrier] at ht <;> subst ht <;> revert hr <;> decide

/-! ## Faults (`Grid.advance_fault`, `Grid.Step.advance_fault`, `Grid.Step.bad`) -/

/-- Thread 0 at a store to offset `o` of block 1 and thread 1 at one to offset `o'`, on
`Closed.mem1`. -/
def faulter (o o' : Int) : Grid :=
  { threads := #[.run (storerAt 7 o), .run (storerAt 7 o')], mem := Closed.mem1 }

/-- `faulter o o'` is closed in every contexts without globals. -/
theorem faulter_closed (o o' : Int) {c : Nat → Ctx} (hc : ∀ n x, (c n).globals x = none) :
    (faulter o o').Closed c :=
  closed_of hc (fun _ _ _ => nofun) fun n s hs => by
    rcases n with _ | _ | n <;> simp at hs <;> subst hs <;> exact storerAt_namesIn _ _

/-- `faulter o o'` has its frames' `alloca`s owned by their threads (it has none). -/
theorem faulter_owns (o o' : Int) : (faulter o o').Owns ctxOf := fun n s hs => by
  rcases n with _ | _ | n <;> simp [faulter] at hs <;> subst hs <;>
    simp [Status.AllocasIn, storerAt]

/-- No thread of `faulter o o'` waits, so no collective call completes or faults. -/
theorem faulter_fire (o o' : Int) (L : Launch) (n : Nat) :
    (faulter o o').fire L ctxOf n = .ok none := by
  rcases n with _ | _ | n <;> simp [Grid.fire, faulter] <;> rfl

/-- The instance of `Grid.advance_fault`: on `faulter 8 0` thread 0's store, to bytes 8 to 11 of a
block of 8 bytes, faults, thread 1's store to bytes 0 to 3 overlaps no access of thread 0's and
succeeds, and after it thread 0's store still faults. -/
theorem fault_stays : ∃ x g', (faulter 8 0).advance ctxOf 0 = .error x ∧
    (faulter 8 0).advance ctxOf 1 = .ok (some g') ∧ ∃ y, g'.advance ctxOf 0 = .error y := by
  refine ⟨_, _, rfl, rfl, ?_⟩
  refine Grid.advance_fault (n := 0) (k := 1) (faulter_closed 8 0 fun _ _ => rfl)
    (faulter_owns 8 0) (by decide) (fun a a' ha ha' => ?_) rfl rfl
  rw [show (faulter 8 0).pending ctxOf 0 = [.access ⟨⟨0, 0⟩, ⟨1, 8⟩, 4, true, none, false⟩]
      from rfl, List.mem_singleton] at ha
  rw [show (faulter 8 0).pending ctxOf 1 = [.access ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩]
      from rfl, List.mem_singleton] at ha'
  simp only [Event.access.injEq] at ha ha'
  subst ha ha'
  decide

/-- The instance of `Grid.Step.advance_fault`'s race: on `faulter 6 4` thread 0's store, to bytes
6 to 9, faults, and thread 1's store to bytes 4 to 7, which overlaps it, succeeds; after it a race
is enabled. -/
theorem fault_race : ∃ x g', (faulter 6 4).advance ctxOf 0 = .error x ∧
    (faulter 6 4).advance ctxOf 1 = .ok (some g') ∧
    (g'.Faults (Pending.launch 1) ctxOf ∨ g'.RaceEnabled ctxOf) ∧ g'.RaceEnabled ctxOf := by
  refine ⟨_, _, rfl, rfl, ?_, 0, _, rfl, rfl⟩
  exact Grid.Step.advance_fault (n := 0) (faulter_closed 6 4 fun _ _ => rfl) (faulter_owns 6 4)
    (fun _ hk => Ne.symm hk) ⟨1, .inl rfl⟩ rfl

/-- The instance of `Grid.Step.bad`: `faulter 8 0` is bad, as thread 0 faults; `ctxOf` has one
layout and no collective call completes, so after thread 1's step the grid is bad. -/
theorem fault_bad : ∃ g', (faulter 8 0).advance ctxOf 1 = .ok (some g') ∧
    g'.Bad (Pending.launch 1) ctxOf := by
  refine ⟨_, rfl, ?_⟩
  exact Grid.Step.bad (faulter_closed 8 0 fun _ _ => rfl) (faulter_owns 8 0) (fun _ _ h => h)
    (fun _ k _ _ _ hf => by rw [faulter_fire] at hf; cases hf)
    (fun _ _ => rfl) ⟨1, .inl rfl⟩ (.inl ⟨0, _, .inl rfl⟩)

/-! ## Faults at a collective call (`Grid.fire_error_advance`, `Grid.fire_error_fire`) -/

/-- Thread 0 waiting at a barrier whose number is poison, thread 1 at a store to bytes 4 to 7 of
block 1, and thread 2 at barrier 0, on `Closed.mem1`. -/
def poisonBar : Grid :=
  { threads := #[.wait (thread #[]) .barrier [.poison] (kernel #[]), .run (storerAt 8 4),
      atBarrier], mem := Closed.mem1 }

/-- The instances of `Grid.fire_error_advance` and `Grid.fire_error_fire`: in the contexts `ctxB`
(one thread per block of threads, one layout), `poisonBar` is closed and thread 0's barrier
faults, as its number is not defined; after thread 1's store, and after thread 2's barrier
completes, it still faults. -/
theorem fire_error_stays : (∃ e, poisonBar.fire (Pending.launch 1) ctxB 0 = .error e) ∧
    ∃ gk gj, poisonBar.advance ctxB 1 = .ok (some gk) ∧
      poisonBar.fire (Pending.launch 1) ctxB 2 = .ok (some gj) ∧
      (∃ e, gk.fire (Pending.launch 1) ctxB 0 = .error e) ∧
      ∃ e, gj.fire (Pending.launch 1) ctxB 0 = .error e := by
  have hg : poisonBar.Closed ctxB := closed_of (fun _ _ => rfl) (fun _ _ _ => nofun)
    fun n s hs => by
      rcases n with _ | _ | _ | n <;> simp at hs <;> subst hs
      · simp [Status.NamesIn, Thread.NamesIn, Frame.NamesIn, thread, Val.NamesIn]
      · exact storerAt_namesIn _ _
      · exact atBarrier_namesIn
  obtain ⟨e, he⟩ : ∃ e, poisonBar.fire (Pending.launch 1) ctxB 0 = .error e := ⟨_, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, poisonBar.advance ctxB 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨gj, hj⟩ : ∃ gj, poisonBar.fire (Pending.launch 1) ctxB 2 = .ok (some gj) := ⟨_, rfl⟩
  exact ⟨⟨e, he⟩, gk, gj, hk, hj, Grid.fire_error_advance hg hk he,
    Grid.fire_error_fire (fun _ => rfl) hj he⟩

/-! ## The twin of `Grid.Step.bad`'s premise on layouts -/

/-- `shflPtr` with its result also `noundef`. -/
def shflPtrU : Func := { shflPtr with retAttrs := [.flag "nonnull", .flag "noundef"] }

/-- `ptrs` with the callee `shflPtrU`: threads 0 and 1 at `regT`, waiting at a butterfly shuffle
of all lanes with lane mask `0` of the pointer of block 0 at offset `2 ^ 32`, on `Closed.mem1`. -/
def ptrsU : Grid :=
  let w : Status := .wait regT (.shfl .bfly) [.bits 32 (-1), .ptr ⟨0, 2 ^ 32⟩, .bits 32 0,
    .bits 32 31] shflPtrU
  { threads := #[w, w], mem := Closed.mem1 }

/-- The twin of `Grid.Step.bad`'s premise `hl` (the contexts have one layout): in the contexts
`ctxL` (64-bit pointers for thread 0, 32-bit for thread 1), `ptrsU` is closed, its threads own
their allocas, no thread runs and none has a pending access, so the other premises hold. The
pointer's address is `0` under thread 1's layout, so thread 1's fire gives a `nonnull` result
poison, not `noundef`, and faults: `ptrsU` is bad. But under thread 0's layout it is `2 ^ 32`,
thread 0's fire completes, and the grid after it is not bad. -/
theorem fire_fault_twin : ptrsU.Closed ctxL ∧ ptrsU.Owns ctxL ∧
    (∀ (n : Nat) (t : Thread), ptrsU.threads[n]? ≠ some (.run t)) ∧
    (∀ n, ptrsU.pending ctxL n = []) ∧
    (∃ e, ptrsU.fire (Pending.launch 2) ctxL 1 = .error e) ∧
    ∃ gn, ptrsU.fire (Pending.launch 2) ctxL 0 = .ok (some gn) ∧
      ¬ gn.Bad (Pending.launch 2) ctxL := by
  obtain ⟨gn, hn, h0, h1, hr, hk, hf0, hf1, hp0, hp1, hsz⟩ : ∃ gn,
      ptrsU.fire (Pending.launch 2) ctxL 0 = .ok (some gn) ∧
      (∃ o, gn.advance ctxL 0 = .ok o) ∧ (∃ o, gn.advance ctxL 1 = .ok o) ∧
      racy gn.mem.trace = false ∧ kept gn.mem.trace = true ∧
      gn.fire (Pending.launch 2) ctxL 0 = .ok none ∧ gn.fire (Pending.launch 2) ctxL 1 = .ok none ∧
      gn.pending ctxL 0 = [] ∧ gn.pending ctxL 1 = [] ∧ gn.threads.size = 2 := by
    refine ⟨_, rfl, ?_⟩
    exact ⟨⟨_, rfl⟩, ⟨_, rfl⟩, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  refine ⟨closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => ?_, fun n s hs => ?_,
    fun n t ht => ?_, fun n => ?_, ⟨_, rfl⟩, gn, hn, ?_⟩
  · rcases n with _ | _ | n <;> simp at hs <;> subst hs <;>
      simp [Status.NamesIn, Thread.NamesIn, Frame.NamesIn, regT, thread, Val.NamesIn]
  · rcases n with _ | _ | n <;> simp [ptrsU] at hs <;> subst hs <;>
      simp [Status.AllocasIn, regT, thread]
  · rcases n with _ | _ | n <;> simp [ptrsU] at ht
  · rcases n with _ | _ | n <;> simp [Grid.pending, ptrsU]
  have hnone : ∀ n, gn.threads[n + 2]? = none := fun n => by simp [hsz]
  rintro (⟨n, e, h | h⟩ | h | h | ⟨n, t, ht, h⟩)
  · rcases n with _ | _ | n
    · obtain ⟨o, ho⟩ := h0
      rw [ho] at h
      cases h
    · obtain ⟨o, ho⟩ := h1
      rw [ho] at h
      cases h
    · simp only [Grid.advance, hnone] at h
      cases h
  · rcases n with _ | _ | n
    · rw [hf0] at h
      cases h
    · rw [hf1] at h
      cases h
    · simp only [Grid.fire, hnone] at h
      cases h
  · rw [hr] at h
    cases h
  · rw [hk] at h
    cases h
  · have hp : t.pending (ctxL n) gn.mem = [] := by
      rcases n with _ | _ | n
      · simpa only [Grid.pending, ht] using hp0
      · simpa only [Grid.pending, ht] using hp1
      · rw [hnone] at ht
        cases ht
    rw [hp, List.nil_append, hr] at h
    cases h

/-! ## Faults beside an exempt pair (`Mem.update_before`, `Grid.advance_fault_atomic`) -/

/-- Thread 0 at `atomicrmw max ptr %0, i32 %0`, whose operand is the pointer, not an `i32`, and
thread 1 at `atomicrmw max ptr %0, i32 poison`, both at offset 0 of block 1 of `memZ`. -/
def maxes : Grid :=
  { threads := #[.run (rmwAt .max (.loc 0)), .run (rmwAt .max .poison)], mem := memZ }

/-- `memZ` after thread 1's `atomicrmw max` of poison: its read logged, bytes 0 to 3 of block 1
poison, its write logged. -/
def memP : Mem :=
  ((memZ.log (.access ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, false, some .max, false⟩)).set 1
    (zeros.put 0 (List.replicate 4 .poison))).log
    (.access ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, true, some .max, false⟩)

/-- On `memZ` thread 0's update by the pointer faults: the old value is `0`, and `rmw` of `max` of
a word by a pointer faults. -/
theorem max_fault : ∃ e, memZ.update {} ⟨0, 0⟩ 0 (.int 32) .max (.ptr ⟨1, 0⟩) ⟨1, 0⟩ (some 4) =
    .error e := by
  have hl : memZ.load {} ⟨0, 0⟩ 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 0) :=
    Mem.load_of_check (blk := zeros) (o := 0) rfl zeros_decode
  exact ⟨_, by simp only [Mem.update, hl, bind, Except.bind]; rfl⟩

/-- On `memZ` thread 1's update succeeds and gives `memP`: `max` of `0` and poison is poison. -/
theorem max_poison : memZ.update {} ⟨1, 0⟩ 0 (.int 32) .max .poison ⟨1, 0⟩ (some 4) = .ok memP :=
  Mem.update_eq_ok.2 ⟨zeros, .bits 32 0, .poison, _, rfl, rfl, zeros_decode, rfl, rfl, rfl⟩

/-- Bytes 0 to 3 of block 1 of `memP` decode at `i32` to poison (`Layout.scalar_round`). -/
theorem poison_decode : ({} : Layout).decode (.int 32)
    ((zeros.put 0 (List.replicate 4 .poison)).read 0 4) = some .poison := by
  rw [show (zeros.put 0 (List.replicate 4 MemByte.poison)).read 0 4 = List.replicate 4 .poison
    from Block.read_put_self _ _ _]
  obtain ⟨bs, he, hd⟩ := Layout.scalar_round (l := {}) (w := 32) (by omega) (v := .poison)
    (.inr (.inl rfl))
  rw [show ({} : Layout).encode (.int 32) .poison = some (List.replicate 4 .poison) from rfl,
    Option.some.injEq] at he
  rw [he]
  exact hd

/-- On `memP` thread 0's update by `5` or by the pointer succeeds: the old value is poison, and
`rmw` of `max` of poison by either is poison. -/
theorem max_ok (x : Val) (hx : x = .bits 32 5 ∨ x = .ptr ⟨1, 0⟩) :
    ∃ m', memP.update {} ⟨0, 0⟩ 0 (.int 32) .max x ⟨1, 0⟩ (some 4) = .ok m' := by
  rcases hx with rfl | rfl <;>
    exact ⟨_, Mem.update_eq_ok.2 ⟨_, .poison, .poison, _, rfl, rfl, poison_decode, rfl, rfl, rfl⟩⟩

/-- The instance of `Mem.update_before`: on `memZ` thread 0's update by `5` succeeds after thread
1's by poison (`max_poison`), and so it succeeds before it. The twin of its premise that the
later update's operand is a scalar: the pointer is not a scalar of width 32, and thread 0's update
by it succeeds after thread 1's but faults before it (`max_fault`). This is why `exec` checks an
`atomicrmw`'s operand. -/
theorem update_before :
    (∃ m', memZ.update {} ⟨0, 0⟩ 0 (.int 32) .max (.bits 32 5) ⟨1, 0⟩ (some 4) = .ok m') ∧
    ¬ (Val.ptr ⟨1, 0⟩).Scalar 32 ∧
    (∃ m', memP.update {} ⟨0, 0⟩ 0 (.int 32) .max (.ptr ⟨1, 0⟩) ⟨1, 0⟩ (some 4) = .ok m') ∧
    ∃ e, memZ.update {} ⟨0, 0⟩ 0 (.int 32) .max (.ptr ⟨1, 0⟩) ⟨1, 0⟩ (some 4) = .error e :=
  have ⟨_, h⟩ := max_ok _ (.inl rfl)
  ⟨Mem.update_before (by decide) (.inl ⟨5, rfl⟩) max_poison h, by simp [Val.Scalar],
    max_ok _ (.inr rfl), max_fault⟩

/-- The instance of `Grid.advance_fault_atomic` and of `Grid.Step.bad` beside an exempt pair: the
two threads' pending writes in `maxes`, by `max` at one pointer and size, overlap and are exempt.
Thread 0's step faults, as its operand is a pointer, not a scalar of width 32 (`exec`'s check);
thread 1's step succeeds, and after it thread 0's step still faults. As `maxes` is closed,
its threads own their allocas and no collective call completes, the grid after thread 1's step is
bad. -/
theorem rmw_fault :
    (∃ a a', .access a ∈ maxes.pending ctxOf 0 ∧ .access a' ∈ maxes.pending ctxOf 1 ∧
      a.overlaps a' = true ∧
      (a.atomic.isSome && a.atomic == a'.atomic && a.ptr == a'.ptr && a.len == a'.len) = true) ∧
    (∃ e, maxes.advance ctxOf 0 = .error e) ∧
    ∃ g', maxes.advance ctxOf 1 = .ok (some g') ∧ (∃ e, g'.advance ctxOf 0 = .error e) ∧
      g'.Bad (Pending.launch 1) ctxOf := by
  have hq : ∀ s : Scope, s.regs 0 = some (.ptr ⟨1, 0⟩) →
      evalV s (.int 32) .poison = .ok .poison := fun _ _ => by
    simp [evalV, fill, pure, Except.pure]
  have h1 := advance_rmw (g := maxes) rfl rfl hq (.inr (.inl rfl)) max_poison
  have h0 := advance_rmw_fault (g := maxes) (n := 0) (x := .ptr ⟨1, 0⟩) rfl rfl
    (fun s hr => by simp [evalV, hr, pure, Except.pure]) (by simp [Val.Scalar])
  have ha : ∀ n, n < 2 → .access ⟨⟨n, 0⟩, ⟨1, 0⟩, 4, true, some .max, false⟩ ∈
      maxes.pending ctxOf n := fun n hn => by
    rcases n with _ | _ | n
    · exact List.mem_cons_self
    · exact List.mem_cons_self
    · omega
  have hg : maxes.Closed ctxOf := closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => by
    rcases n with _ | _ | n <;> simp at hs <;> subst hs <;> exact rmwAt_namesIn _ _
  have ho : maxes.Owns ctxOf := fun n s hs => by
    rcases n with _ | _ | n <;> simp [maxes] at hs <;> subst hs <;>
      simp [Status.AllocasIn, rmwAt, frameAt]
  have hf : ∀ n, maxes.fire (Pending.launch 1) ctxOf n = .ok none := fun n => by
    rcases n with _ | _ | n <;> simp [Grid.fire, maxes] <;> rfl
  exact ⟨⟨_, _, ha 0 (by decide), ha 1 (by decide), rfl, rfl⟩, ⟨_, h0⟩, _, h1,
    Grid.advance_fault_atomic hg (by decide) h1 h0 (ha 0 (by decide)) (ha 1 (by decide)) rfl rfl
      rfl rfl,
    Grid.Step.bad hg ho (fun _ _ h => h) (fun _ k _ _ _ e => by rw [hf] at e; cases e)
      (fun _ _ => rfl) ⟨1, .inl h1⟩ (.inl ⟨0, _, .inl h0⟩)⟩

/-! ## From the start (`Grid.start_reach_bad_trace`, `Grid.start_reach_bad`) -/

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The kernel `@k(ptr %0)`: `store i32 7, ptr %0`, then `ret void`. -/
def kernP : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k",
    params := [⟨.ptr 0, [], some 0⟩], group := none, names := #["entry"],
    blocks := #[⟨0, #[storeOf 7], .ret none⟩] }

/-- The program of `kernP` alone, with the default data layout. -/
def progP : Program :=
  { module := { (default : Module) with funcs := #[kernP] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

/-- The launch of `kernP` on `two` with a pointer to block 1 on `Close.mem (some 5)`, with
address choice and oracle 0. -/
def startP : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start progP kernP two [.ptr ⟨1, 0⟩] (Close.mem (some 5)) (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `startP`. -/
def runP : Grid × (Nat → Ctx) :=
  match startP with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨progP, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The start's contexts. -/
def cP : Nat → Ctx := runP.2

/-- The launch `startP` starts, with the grid `runP.1` and contexts `cP`. -/
theorem startP_eq : startP = .ok (runP.1, cP) := rfl

/-- The instance of `Grid.start_reach_bad_trace`: from the start both threads store to bytes 0
to 3 of block 1; after thread 0's store, reachable from the start, the trace is not racy but
thread 1's store races, and after thread 1's store the trace is racy. -/
theorem start_bad : ∃ g, runP.1.advance cP 0 = .ok (some g) ∧ racy g.mem.trace = false ∧
    g.RaceEnabled cP ∧ ∃ g', g.advance cP 1 = .ok (some g') ∧ racy g'.mem.trace = true ∧
      (racy g'.mem.trace = true ∨ kept g'.mem.trace = false ∨ g'.RaceEnabled cP) := by
  refine ⟨_, rfl, ?_⟩
  refine ⟨rfl, ⟨1, _, rfl, rfl⟩, _, rfl, ?_⟩
  refine ⟨rfl, ?_⟩
  exact Grid.start_reach_bad_trace startP_eq (Closed.mem_bytesIn _) (.single ⟨0, .inl rfl⟩)
    ⟨1, .inl rfl⟩ (.inr (.inr ⟨1, _, rfl, rfl⟩))


/-- The kernel `@k(ptr %0)`: `%1 = alloca i32`, `store i32 7, ptr %0`, then `ret void`. -/
def kernF : Func :=
  { kernP with
    blocks := #[⟨0, #[{ res := some 1, inst := .alloca (.int 32) none none }, storeOf 7],
      .ret none⟩] }

/-- The program of `kernF` alone, with the default data layout. -/
def progF : Program :=
  { module := { (default : Module) with funcs := #[kernF] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

/-- The launch of `kernF` on `two` with a pointer to byte 4 of block 1, of 4 bytes, on
`Close.mem none`, with address choice and oracle 0. -/
def startF : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start progF kernF two [.ptr ⟨1, 4⟩] (Close.mem none) (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `startF`. -/
def runF : Grid × (Nat → Ctx) :=
  match startF with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨progF, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The start's contexts. -/
def cF : Nat → Ctx := runF.2

/-- The launch `startF` starts, with the grid `runF.1` and contexts `cF`. -/
theorem startF_eq : startF = .ok (runF.1, cF) := rfl

/-- After thread 0's `alloca`. -/
def gF : Grid :=
  match runF.1.advance cF 0 with
  | .ok (some g) => g
  | _ => runF.1

/-- The instance of `Grid.start_reach_bad`: in `gF`, reachable from the start, thread 0's store,
to bytes 4 to 7 of a block of 4 bytes, faults, and thread 1's `alloca` succeeds; after it thread
0's store still faults, and the grid is bad. -/
theorem start_fault : ∃ x g', gF.advance cF 0 = .error x ∧ gF.advance cF 1 = .ok (some g') ∧
    (∃ y, g'.advance cF 0 = .error y) ∧ g'.Bad two cF := by
  refine ⟨_, _, rfl, rfl, ?_⟩
  refine ⟨⟨_, rfl⟩, ?_⟩
  exact Grid.start_reach_bad startF_eq (Closed.mem_bytesIn _) (.single ⟨0, .inl rfl⟩) ⟨1, .inl rfl⟩
    (.inl ⟨0, _, .inl rfl⟩)

/-! ## The twin of `Grid.Step.bad`'s premise that the grid is closed (counterexample (i)) -/

/-- `%1 = ptrtoint ptr %0 to i64`. -/
def toInt : Stmt := { res := some 1, inst := .cast .ptrtoint ⟨.ptr 0, .loc 0⟩ (.int 64) }

/-- A thread at `toInt` with a pointer to block 4 in register 0. -/
def toIntAt : Thread :=
  ⟨[{ fn := kernel #[toInt], label := 0, pc := 0,
      regs := fun n => if n = 0 then some (.ptr ⟨4, 0⟩) else none, prods := fun _ => none,
      allocas := [], dest := none }], 0⟩

/-- Thread 0 at `toIntAt` and thread 1 at `alloca i32`, on `Closed.mem1`. In the contexts
`ctxOf` thread 1's `alloca` makes block 4 (`Mem.fresh`). -/
def dangle : Grid :=
  { threads := #[.run toIntAt, .run (thread #[alloc])], mem := Closed.mem1 }

/-- The twin of `Grid.Step.bad`'s premise that the grid is
closed: `dangle` is not closed, as thread 0 names block 4, which is not below `next` and has no
block. The other premises hold: its threads own their allocas and have different thread numbers,
no collective call completes, and the contexts have one layout. Thread 0's step faults (a pointer
to no block), so `dangle` is bad; thread 1's `alloca` makes block 4, after which thread 0's step
succeeds and the grid is not bad. So `Bad` is not persistent on grids that are not closed; every
grid reachable from the start is closed (`Grid.start_reach_closed`). -/
theorem closed_twin : ¬ dangle.Closed ctxOf ∧ dangle.Owns ctxOf ∧
    (∀ n k, n ≠ k → (ctxOf n).who.thread ≠ (ctxOf k).who.thread) ∧
    (∀ k gf, dangle.fire (Pending.launch 2) ctxOf k ≠ .ok (some gf)) ∧
    (∀ n p, (ctxOf n).prog.layout = (ctxOf p).prog.layout) ∧ dangle.Bad (Pending.launch 2) ctxOf ∧
    ∃ g', dangle.advance ctxOf 1 = .ok (some g') ∧ ¬ g'.Bad (Pending.launch 2) ctxOf := by
  obtain ⟨g', h1, h0', h1', hr, hk, hf0, hf1, hp0, hp1, hsz⟩ : ∃ g',
      dangle.advance ctxOf 1 = .ok (some g') ∧
      (∃ o, g'.advance ctxOf 0 = .ok o) ∧ (∃ o, g'.advance ctxOf 1 = .ok o) ∧
      racy g'.mem.trace = false ∧ kept g'.mem.trace = true ∧
      g'.fire (Pending.launch 2) ctxOf 0 = .ok none ∧
      g'.fire (Pending.launch 2) ctxOf 1 = .ok none ∧
      g'.pending ctxOf 0 = [] ∧ g'.pending ctxOf 1 = [] ∧ g'.threads.size = 2 := by
    refine ⟨_, rfl, ?_⟩
    exact ⟨⟨_, rfl⟩, ⟨_, rfl⟩, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  have hd : ∀ n, dangle.threads[n + 2]? = none := fun n => by simp [dangle]
  refine ⟨fun h => ?_, fun n s hs => ?_, fun _ _ h => h, fun k gf h => ?_, fun _ _ => rfl,
    .inl ⟨0, _, .inl rfl⟩, g', h1, ?_⟩
  · have := h.threads 0 _ rfl _ List.mem_cons_self 0 _ rfl
    simp [Val.NamesIn, Mem.Known, dangle, Closed.mem1, memOf] at this
  · rcases n with _ | _ | n <;> simp [dangle] at hs <;> subst hs <;>
      simp [Status.AllocasIn, toIntAt, thread]
  · rcases k with _ | _ | k
    · rw [show dangle.fire (Pending.launch 2) ctxOf 0 = .ok none from rfl] at h
      cases h
    · rw [show dangle.fire (Pending.launch 2) ctxOf 1 = .ok none from rfl] at h
      cases h
    · simp only [Grid.fire, hd] at h
      cases h
  have hnone : ∀ n, g'.threads[n + 2]? = none := fun n => by simp [hsz]
  rintro (⟨n, e, h | h⟩ | h | h | ⟨n, t, ht, h⟩)
  · rcases n with _ | _ | n
    · obtain ⟨o, ho⟩ := h0'
      rw [ho] at h
      cases h
    · obtain ⟨o, ho⟩ := h1'
      rw [ho] at h
      cases h
    · simp only [Grid.advance, hnone] at h
      cases h
  · rcases n with _ | _ | n
    · rw [hf0] at h
      cases h
    · rw [hf1] at h
      cases h
    · simp only [Grid.fire, hnone] at h
      cases h
  · rw [hr] at h
    cases h
  · rw [hk] at h
    cases h
  · have hp : t.pending (ctxOf n) g'.mem = [] := by
      rcases n with _ | _ | n
      · simpa only [Grid.pending, ht] using hp0
      · simpa only [Grid.pending, ht] using hp1
      · rw [hnone] at ht
        cases ht
    rw [hp, List.nil_append, hr] at h
    cases h

end MojoProofTest.Bad
