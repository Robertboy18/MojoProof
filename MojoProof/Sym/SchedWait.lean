import MojoProof.Sym.Sched
import MojoProof.Sym.Segment
import MojoProof.Sem.Bfly

/-!
# Schedules through collective calls: threads in turn to their waits, then the collectives

Every result here is for every program, launch and contexts.

A thread's step at a call of the barrier or of a warp shuffle is `.wait` (`step`), the grid gives
the thread the status `.wait` (`Grid.advance`), and the call completes for all its participants
at once (`Grid.fire`), which resumes each with the call's value (`resumeAll`, `Thread.resume`).
The schedule here runs each thread of the grid in turn to its next wait, then fires the
collectives, then resumes.

* `ToWait`: a thread's run to a collective call, steps that continue it (`Steps`) and then the
  step that waits. `ToWait.grid`: such a run by thread `n` is a run of grid steps to the grid with
  thread `n` waiting; `ToWait.trace`: it puts events in front of the trace. `Waits.toWait`: the
  run a segment gives (`Waits`, `Seg.sound`, MojoProof/Sym/Segment.lean) is one.
* `Seq.ToWait`: threads in turn, each to its wait (`Turns` of `ToWait`); `Seq.ToWait.grid`
  (`Turns.grid`). `Turns.of_inv` with `ToWait.trace` gives one by an invariant.
* `Grid.fire_barrier`: when every thread of block of threads `b` waits at the barrier with one
  number below 16 and at one instruction, the fire resumes them with no value and logs the
  block's `.barrier`. `Grid.fire_barriers`: the barriers of blocks `0` to `B - 1` fired in turn.
* `Grid.fire_shfl`: when every lane of a warp waits at the shuffle of one mode, the full member
  mask and one instruction, the fire resumes lane `j` with the value of lane
  `shflSource mode j b c` (PTX ISA 9.5, section 9.7.10.6), `poison` when that lane is not one of
  the warp's, under the callee's return attributes; the memory is unchanged.
* `Fires`: a phase of collectives, from every grid whose threads have statuses `s` on memory `m`
  to one whose threads run `t` on memory `m'`. `Fires.barriers` (`Grid.fire_barriers`): every
  block's threads at one barrier; `Fires.shfls` (`Grid.fire_shfl`, every warp in turn): every
  warp's lanes at one shuffle, each resumed with the value of lane `shflSource mode j b c` under
  the callee's return attributes, for every block size, so for every width the shuffles allow.
* `Sched`: a schedule of any number of phases, each threads in turn to their waits (`Seq.ToWait`)
  and then a fire (`Fires`), and last threads in turn to their ends (`Seq`). `Sched.grid`: it is a
  run of grid steps to a finished grid. `Grid.start_done_sound`: a start that steps to a done grid
  whose memory is kept, race-free when its trace has the premises of `racy_iff`, and observed as
  `y` with `R y` is sound (`Grid.Sound`), through `Grid.start_sound`. `Sched.start_sound`: the
  same for a start whose threads (`Grid.thread`) have a schedule, by `Sched.grid`.
* `Seq.start_sound_bar`: the case of `Sched.start_sound` at one barrier phase. The per-thread
  premises have the forms the segments give: the run to the barrier is `Waits.toWait` of
  `Seg.sound`, and the run after it is from the resumed thread with no value on the memory the
  schedule reaches, the value and memory `Seg.through` takes as the collective's delivery `w 0`.
* `bflyRoundsAt_of_shfl`: for every combination per round and lane, `k ≤ 5` and offsets below
  `2 ^ k`, lanes whose value after round `r` combines their value with that of lane
  `shflSource .bfly l m 31` hold, after all rounds, `bflyRoundsAt` of their first values
  (`shflSource_bfly`); with one combining operation, `bflyRounds`.
* `Seq.ToWait.of_runTo`, `Seq.of_runTo`: threads in turn whose evaluator runs (`runTo`) reach
  their waits or ends give `Seq.ToWait` and `Seq`, so a concrete schedule is computed, not
  written out.

The values a schedule delivers are the semantics' (`Grid.fire`); which lanes read which is
`shflSource`, not a model of it.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem
open GPUProof

/-- A run of thread `t` in context `c` to a collective call, from memory `m`: steps that continue
it, to thread `u` on memory `m'`, then a step that waits at a call of the collective intrinsic `i`
with arguments `as` and the callee's declaration `d`; `s` is `.wait u i as d`, the status a grid
gives the thread there (`Grid.advance`). -/
def ToWait (c : Ctx) (t : Thread) (m : Mem) (s : Status) (m' : Mem) : Prop :=
  ∃ u i as d, s = .wait u i as d ∧ Steps c t m u m' ∧ step c u m' = .ok (.wait i as d)

/-- **A thread's run to a wait, in a grid.** For every launch `L`, contexts `c` and grid `g` whose
thread `n` runs `t` on `g`'s memory `m`: a run of `t` to a collective call (`ToWait`) at status
`s`, leaving `m'`, is a run of grid steps from `g` to the grid with thread `n` at `s`, every other
thread unchanged, and memory `m'`. -/
theorem ToWait.grid {L : Launch} {c : Nat → Ctx} {n : Nat} {t : Thread} {m m' : Mem} {s : Status}
    (h : ToWait (c n) t m s m') {g : Grid} (hg : g.threads[n]? = some (.run t)) (hm : g.mem = m) :
    ∃ k, Path (Grid.Step L c) k g ⟨g.threads.set! n s, m'⟩ := by
  obtain ⟨u, i, as, d, rfl, hs, hw⟩ := h
  obtain ⟨k, hp⟩ := Steps.grid (L := L) hs hg hm
  have hn : n < g.threads.size := (Array.getElem?_eq_some_iff.1 hg).1
  have ha : Grid.advance c ⟨g.threads.set! n (.run u), m'⟩ n =
      .ok (some ⟨g.threads.set! n (.wait u i as d), m'⟩) := by
    unfold Grid.advance
    simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_self_of_lt hn, bind,
      Except.bind, hw, pure, Except.pure, Array.setIfInBounds_setIfInBounds]
  exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨k, hp⟩).tail ⟨n, .inl ha⟩)

/-- **The events of a run to a wait**: for every context, a thread's run to a collective call
puts events in front of the trace (`Steps.trace`; the waiting step logs nothing). -/
theorem ToWait.trace {c : Ctx} {t : Thread} {m m' : Mem} {s : Status} (h : ToWait c t m s m') :
    ∃ E, m'.trace = E ++ m.trace :=
  have ⟨_, _, _, _, _, hs, _⟩ := h
  hs.trace

/-- **A segment's run is a run to a wait**: for every context, thread, memory, frames, valuation
`V`, block and segment summary `S`, the facts of `Waits` (MojoProof/Sym/Segment.lean, which
`Seg.sound` gives) contain a run of the thread (`ToWait`) to the call of `S`'s collective, waiting
at the frame `fe` the segment ends at with step count `V.k + S.len`. -/
theorem Waits.toWait {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : SegSummary} (h : Waits c t m f rest (V, lbl, S)) :
    ∃ fe me ws fd, ToWait c t m (.wait ⟨fe :: rest, V.k + S.len⟩ S.call.intr ws fd) me :=
  have ⟨fe, me, ws, fd, hs, _, _, _, _, _, _, _, _, _, hw⟩ := h
  ⟨fe, me, ws, fd, _, _, _, _, rfl, hs, hw⟩

/-- **A block's segments start with a run to a wait**: for every context, block, frames,
summaries, deliveries `w`, thread `t`, memory `m` and frame `f`, if the first segment `S`'s
obligations hold under `f`'s entry valuation, the run of the segments (`Seg.Through`,
MojoProof/Sym/Segment.lean, which `Seg.through` gives for every `w`) is a run of the thread to the
call of `S`'s collective (`ToWait`), waiting at frame `fe` with step count `t.k + S.len`, and the
thread resumed there with the delivered value `(w 0).1` runs the other segments from the delivered
memory `(w 0).2` with the deliveries `fun i => w (i + 1)`. -/
theorem Seg.Through.toWait {c : Ctx} {lbl : Nat} {rest : List Frame} {L : Summary}
    {S : SegSummary} {Ss : List SegSummary} {w : Nat → Option Val × Mem} {t : Thread} {m : Mem}
    {f : Frame} (h : Seg.Through c lbl rest L (S :: Ss) w t m f)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me ws fd, ToWait c t m (.wait ⟨fe :: rest, t.k + S.len⟩ S.call.intr ws fd) me ∧
      ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ (w 0).1 = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        Seg.Through c lbl rest L Ss (fun i => w (i + 1)) ⟨fr :: rest, t.k + S.len + 1⟩
          (w 0).2 fr :=
  have ⟨fe, me, ws, fd, hs, _, _, _, _, _, _, _, _, _, hw, hr⟩ := h hds
  ⟨fe, me, ws, fd, ⟨_, _, _, _, rfl, hs, hw⟩, hr⟩

/-- Thread `t`'s steps in context `c` from memory `m`, at most `fuel` of them, while they continue
it (`.next`), then the first step that does not: the thread and memory that step is taken from,
and its result (`.wait` or `.done`); none if a step faults or the fuel runs out. -/
def runTo (c : Ctx) : Nat → Thread → Mem → Option (Thread × Mem × Step)
  | 0, _, _ => none
  | fuel + 1, t, m => match step c t m with
    | .ok (.next t' m') => runTo c fuel t' m'
    | .ok s => some (t, m, s)
    | .error _ => none

/-- **What `runTo` gives is reached and taken**: for every context, fuel, threads `t`, `u`,
memories and step result `s`, if `runTo` gives `u` on `m'` and `s`, then steps that continue the
thread go from `t` on `m` to `u` on `m'` (`Steps`), and the step there gives `s`. -/
theorem runTo_steps {c : Ctx} : ∀ {fuel : Nat} {t u : Thread} {m m' : Mem} {s : Step},
    runTo c fuel t m = some (u, m', s) → Steps c t m u m' ∧ step c u m' = .ok s
  | 0, _, _, _, _, _, h => by cases h
  | fuel + 1, t, u, m, m', s, h => by
    unfold runTo at h
    cases he : step c t m with
    | error e => simp only [he, reduceCtorEq] at h
    | ok s' =>
      cases s' with
      | next t' m₁ =>
        simp only [he] at h
        obtain ⟨hs, hu⟩ := runTo_steps h
        exact ⟨.cons he hs, hu⟩
      | wait i as d =>
        simp only [he, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl⟩ := h
        exact ⟨.refl _ _, he⟩
      | done m₁ =>
        simp only [he, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl⟩ := h
        exact ⟨.refl _ _, he⟩

/-- A `runTo` that ends at a wait is a run to a collective call: for every context, fuel,
threads, memories, intrinsic `i`, arguments `as` and callee `d`, `ToWait` at `.wait u i as d`. -/
theorem ToWait.of_runTo {c : Ctx} {fuel : Nat} {t u : Thread} {m m' : Mem} {i : Intrinsic}
    {as : List Val} {d : Func} (h : runTo c fuel t m = some (u, m', .wait i as d)) :
    ToWait c t m (.wait u i as d) m' :=
  have ⟨hs, hw⟩ := runTo_steps h
  ⟨u, i, as, d, rfl, hs, hw⟩

/-- A `runTo` that ends at a return is a run to the end: for every context, fuel, threads and
memories, `Runs` to the memory the return leaves. -/
theorem Runs.of_runTo {c : Ctx} {fuel : Nat} {t u : Thread} {m m₁ m' : Mem}
    (h : runTo c fuel t m = some (u, m₁, .done m')) : Runs c t m m' :=
  have ⟨hs, hd⟩ := runTo_steps h
  ⟨u, m₁, hs, hd⟩

/-- Threads `ns` in turn, each in its context `c n` from its thread `t n`, run alone to a
collective call (`ToWait`) where the grid gives it status `s n`: the first from memory `m`, each
next one from the memory the one before left, the last leaving `m'`, with the events `Es` each
puts in front of the trace (`Turns`). -/
abbrev Seq.ToWait (c : Nat → Ctx) (t : Nat → Thread) (s : Nat → Status) :
    List Nat → Mem → List (List Event) → Mem → Prop :=
  Turns fun n m m' => Sym.ToWait (c n) (t n) m (s n) m'

/-- **Threads run in turn to their waits, in a grid.** For every launch `L`, contexts `c`, threads
`t`, statuses `s` and grid `g` in which each of the distinct threads `ns` runs its thread `t n`
and whose memory is `m`: threads `ns` run in turn to their waits from `m` to `m'` (`Seq.ToWait`)
are a run of grid steps from `g` to the grid with each thread `n` of `ns` at `s n`, every other
thread unchanged, and memory `m'` (`Turns.grid`, `ToWait.grid`). -/
theorem Seq.ToWait.grid {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status}
    {ns : List Nat} {m m' : Mem} {Es : List (List Event)} (h : Seq.ToWait c t s ns m Es m') :
    ∀ {g : Grid}, ns.Nodup → (∀ n ∈ ns, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ k, Path (Grid.Step L c) k g ⟨ns.foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩ :=
  Turns.grid (s := s) (fun hr hg hm => Sym.ToWait.grid hr hg hm) h

/-- **Threads in turn to their waits, computed.** For every contexts `c`, fuel, threads `t`,
statuses `s`, memories `mem` indexed by the number of threads that have run, and number `N`: if
each thread `k < N`'s evaluator run (`runTo`) from `mem k` waits at a call, at the status `s k`,
leaving `mem (k + 1)`, then threads `0` to `N - 1` run in turn to their waits (`Seq.ToWait`)
from `mem 0` to `mem N` (`Turns.of_inv`, `ToWait.of_runTo`). -/
theorem Seq.ToWait.of_runTo {c : Nat → Ctx} {fuel : Nat} {t : Nat → Thread} {s : Nat → Status}
    {mem : Nat → Mem} {N : Nat}
    (h : ∀ k < N, ∃ u i as d, s k = .wait u i as d ∧
      runTo (c k) fuel (t k) (mem k) = some (u, mem (k + 1), .wait i as d)) :
    ∃ Es, Seq.ToWait c t s (List.range N) (mem 0) Es (mem N) := by
  obtain ⟨Es, m', hs, rfl⟩ := Turns.of_inv (R := fun n m m' => Sym.ToWait (c n) (t n) m (s n) m')
    (P := fun k m => m = mem k) (N := N) (fun hr => hr.trace) (fun k hk m hm => by
      obtain ⟨u, i, as, d, e, hr⟩ := h k hk
      subst hm
      refine ⟨mem (k + 1), ?_, rfl⟩
      show Sym.ToWait (c k) (t k) (mem k) (s k) (mem (k + 1))
      rw [e]
      exact Sym.ToWait.of_runTo hr) rfl
  exact ⟨Es, hs⟩

/-- **Threads in turn to their ends, computed.** For every contexts `c`, fuel, threads `t`,
memories `mem` indexed by the number of threads that have run, and number `N`: if each thread
`k < N`'s evaluator run (`runTo`) from `mem k` returns, leaving `mem (k + 1)`, then threads `0`
to `N - 1` run in turn to their ends (`Seq`) from `mem 0` to `mem N` (`Seq.of_inv`,
`Runs.of_runTo`). -/
theorem Seq.of_runTo {c : Nat → Ctx} {fuel : Nat} {t : Nat → Thread} {mem : Nat → Mem} {N : Nat}
    (h : ∀ k < N, ∃ u m₁, runTo (c k) fuel (t k) (mem k) = some (u, m₁, .done (mem (k + 1)))) :
    ∃ Es, Seq c t (List.range N) (mem 0) Es (mem N) := by
  obtain ⟨Es, m', hs, rfl⟩ := Seq.of_inv (P := fun k m => m = mem k) (fun k hk m hm => by
      obtain ⟨u, m₁, hr⟩ := h k hk
      subst hm
      exact ⟨mem (k + 1), Runs.of_runTo hr, rfl⟩) rfl
  exact ⟨Es, hs⟩

/-- The threads of block of threads `b`, for blocks of `s > 0` threads, are those `j` with
`j / s = b`. -/
theorem mem_block {s b j : Nat} (hs : 0 < s) : j ∈ (List.range s).map (b * s + ·) ↔ j / s = b := by
  simp only [List.mem_map, List.mem_range]
  constructor
  · rintro ⟨a, ha, rfl⟩
    rw [Nat.mul_comm b s, Nat.mul_add_div hs, Nat.div_eq_of_lt ha, Nat.add_zero]
  · intro h
    exact ⟨j % s, Nat.mod_lt _ hs, by rw [← h]; exact Nat.div_add_mod' j s⟩

/-- `mapM` of a function that gives `g x` at every member `x` of the list gives the list's image
under `g`. -/
theorem mapM_ok_map {α β ε : Type} {f : α → Except ε β} {g : α → β} :
    ∀ {xs : List α}, (∀ x ∈ xs, f x = .ok (g x)) → xs.mapM f = .ok (xs.map g)
  | [], _ => rfl
  | x :: xs, h => by
    rw [List.mapM_cons, h x List.mem_cons_self,
      mapM_ok_map fun y hy => h y (List.mem_cons_of_mem x hy)]
    rfl

/-- **The barrier of a block of threads.** For every launch `L` with blocks of `volume L.block > 0`
threads, contexts `c`, grid `g` and block of threads `b`: if every thread `k` of block `b` waits,
from thread `u k`, at a barrier call with argument `x k` and callee `d k`, every `x k` is the
number `bar < 16`, and every `u k` is at the instruction `u (b * volume L.block)` is at
(`Thread.at`), then the barrier fired by thread `b * volume L.block` resumes each thread `k` of
the block running `(u k).resume none`, in turn, every other thread unchanged, and logs the
block's `.barrier b`. -/
theorem Grid.fire_barrier {L : Launch} {c : Nat → Ctx} {g : Grid} {b bar : Nat}
    {u : Nat → Thread} {x : Nat → Val} {d : Nat → Func} (hs : 0 < volume L.block)
    (hbar : bar < 16)
    (hw : ∀ k < volume L.block, g.threads[b * volume L.block + k]? =
        some (.wait (u (b * volume L.block + k)) .barrier [x (b * volume L.block + k)]
          (d (b * volume L.block + k))) ∧
      (x (b * volume L.block + k)).word? = some bar ∧
      (u (b * volume L.block + k)).at = (u (b * volume L.block)).at) :
    g.fire L c (b * volume L.block) = .ok (some
      ⟨((List.range (volume L.block)).map (b * volume L.block + ·)).foldl
        (fun ts k => ts.set! k (.run ((u k).resume none))) g.threads,
        g.mem.log (.barrier b)⟩) := by
  have hb : b * volume L.block / volume L.block = b := Nat.mul_div_cancel b hs
  obtain ⟨h0, hx0, -⟩ := hw 0 hs
  rw [Nat.add_zero] at h0 hx0
  have hd : ((List.range (volume L.block)).map (b * volume L.block + ·)).Nodup :=
    List.nodup_range.map fun _ _ => Nat.add_left_cancel
  unfold Grid.fire
  rw [h0]
  simp only [hx0, hbar, hb, ↓reduceIte, bind, Except.bind, pure, Except.pure]
  rw [mapM_ok_map (g := fun _ => true)]
  · rw [resumeAll_eq (u := u) (r := fun _ => none) hd]
    · simp
    · intro k hk
      obtain ⟨a, ha, rfl⟩ := List.mem_map.1 hk
      exact ⟨_, _, _, (hw a (List.mem_range.1 ha)).1, rfl⟩
  · intro k hk
    obtain ⟨a, ha, rfl⟩ := List.mem_map.1 hk
    obtain ⟨hk, hx, hat⟩ := hw a (List.mem_range.1 ha)
    simp only [hk, hx, hat, and_self, ↓reduceIte]

/-- **The barriers of blocks `0` to `B - 1`**, for every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, number `B` and grid `g`: if every thread `n` of the
first `B` blocks waits, from thread `u n`, at a barrier call with argument `x n`, every `x n` is
the number `bar (n / volume L.block) < 16` of its block, and every `u n` is at the instruction the
first thread of its block is at, then firing the blocks' barriers in turn is a run of grid steps
from `g` to a grid with the same number of threads, each thread `n` of the first `B` blocks
running `(u n).resume none`, every other thread unchanged, and memory `g`'s with the blocks'
`.barrier`s logged in turn (`Grid.fire_barrier`). -/
theorem Grid.fire_barriers {L : Launch} {c : Nat → Ctx} {u : Nat → Thread} {x : Nat → Val}
    {d : Nat → Func} {bar : Nat → Nat} (hs : 0 < volume L.block) (B : Nat) {g : Grid}
    (hw : ∀ n < B * volume L.block, g.threads[n]? = some (.wait (u n) .barrier [x n] (d n)) ∧
      (x n).word? = some (bar (n / volume L.block)) ∧ bar (n / volume L.block) < 16 ∧
      (u n).at = (u (n / volume L.block * volume L.block)).at) :
    ∃ g', (∃ k, Path (Grid.Step L c) k g g') ∧ g'.threads.size = g.threads.size ∧
      (∀ n, g'.threads[n]? = if n < B * volume L.block then some (.run ((u n).resume none))
        else g.threads[n]?) ∧
      g'.mem = (List.range B).foldl (fun m b => m.log (.barrier b)) g.mem := by
  induction B with
  | zero => exact ⟨g, ⟨0, .nil _⟩, rfl, fun n => by simp, rfl⟩
  | succ B ih =>
    have hlt : B * volume L.block ≤ (B + 1) * volume L.block :=
      Nat.mul_le_mul_right _ (Nat.le_succ B)
    obtain ⟨g₁, hp, hsz, hj, hm⟩ := ih fun n hn => hw n (Nat.lt_of_lt_of_le hn hlt)
    have hblk : ∀ k < volume L.block, (B * volume L.block + k) / volume L.block = B := fun k hk =>
      (mem_block hs).1 (List.mem_map.2 ⟨k, List.mem_range.2 hk, rfl⟩)
    have hf := Grid.fire_barrier (c := c) (g := g₁) (b := B) (bar := bar B) (u := u) (x := x)
      (d := d) hs (by
        have := (hw (B * volume L.block) (by rw [Nat.succ_mul]; omega)).2.2.1
        rwa [Nat.mul_div_cancel B hs] at this)
      fun k hk => by
        have hn : B * volume L.block + k < (B + 1) * volume L.block := by
          rw [Nat.succ_mul]; omega
        obtain ⟨h1, h2, -, h4⟩ := hw _ hn
        rw [hblk k hk] at h2 h4
        refine ⟨?_, h2, h4⟩
        simp only [hj, show ¬ B * volume L.block + k < B * volume L.block by omega, ↓reduceIte, h1]
    refine ⟨_, Path.exists_iff.2 ((Path.exists_iff.1 hp).tail ⟨B * volume L.block, .inr hf⟩),
      ?_, fun n => ?_, ?_⟩
    · dsimp only
      rw [foldl_set_size (fun k => .run ((u k).resume none)), hsz]
    · have e1 : n / volume L.block < B ↔ n < B * volume L.block := Nat.div_lt_iff_lt_mul hs
      have e2 : n / volume L.block < B + 1 ↔ n < (B + 1) * volume L.block :=
        Nat.div_lt_iff_lt_mul hs
      dsimp only
      rw [foldl_set_getElem? (fun k => .run ((u k).resume none)), hj]
      by_cases hb : n / volume L.block = B
      · have hn : n < (B + 1) * volume L.block := e2.1 (by omega)
        have hn' : ¬ n < B * volume L.block := fun h => by have := e1.2 h; omega
        simp only [(mem_block hs).2 hb, hn, hn', ↓reduceIte, (hw n hn).1, Option.map_some]
      · have h3 : n ∉ (List.range (volume L.block)).map (B * volume L.block + ·) :=
          fun h => hb ((mem_block hs).1 h)
        by_cases h1 : n < B * volume L.block
        · simp only [h3, h1, Nat.lt_of_lt_of_le h1 hlt, ↓reduceIte]
        · have h2 : ¬ n < (B + 1) * volume L.block := fun h => by
            have := e2.2 h
            have := e1.not.2 h1
            omega
          simp only [h3, h1, h2, ↓reduceIte]
    · dsimp only
      rw [hm, List.range_succ, List.foldl_append]
      rfl

/-- The lanes of thread `n`'s warp inside its block of threads, by lane number, in a launch with
blocks of `volume L.block` threads (`Grid.fire`): the lanes `j < 32` whose thread
`n - n % volume L.block % 32 + j` is in `n`'s block. -/
def warpLanes (L : Launch) (n : Nat) : List Nat :=
  (List.range 32).filter fun j => n % volume L.block - n % volume L.block % 32 + j < volume L.block

/-- The value lane `j` reads at a shuffle whose lanes `lanes` offer `a`: `a j` if lane `j` is
one of `lanes`, `poison` otherwise (`Grid.fire`). -/
def shflVal (lanes : List Nat) (a : Nat → Val) (j : Nat) : Val :=
  if j ∈ lanes then a j else .poison

/-- The first member of a list equal to `j`: `j` if it is a member, none otherwise. -/
theorem find?_eq_self {xs : List Nat} {j : Nat} :
    xs.find? (fun i => decide (i = j)) = if j ∈ xs then some j else none := by
  induction xs with
  | nil => simp
  | cons a xs ih =>
    rw [List.find?_cons]
    by_cases h : a = j
    · subst h
      simp
    · simp only [h, decide_false, ih, List.mem_cons, Ne.symm h, false_or]

/-- `mapM` in `Option` of the identity on a list of `some`s gives the values. -/
theorem mapM_id_some {α β : Type} {g : α → β} :
    ∀ xs : List α, (xs.map fun x => some (g x)).mapM id = some (xs.map g)
  | [] => rfl
  | x :: xs => by
    rw [List.map_cons, List.mapM_cons, mapM_id_some xs]
    rfl

/-- **A warp's shuffle.** For every launch `L` with blocks of `volume L.block > 0` threads,
contexts `c`, grid `g`, thread `n` and mode `mode`: if every lane `j` of `n`'s warp
(`warpLanes`), thread `n - n % volume L.block % 32 + j`, waits from thread `u j` at a shuffle of
mode `mode` with member mask `M j` (the full mask `2^32 - 1`), value `A j`, lane operand `B j` of
number `b j` and clamp `C j` of number `cl j`, at the instruction `n`'s lane is at, and its
callee's return attributes take the value of lane `shflSource mode j (b j) (cl j)`
(`shflVal`: `poison` when that lane is not one of the warp's) to `r j` in `g`'s memory
(`withAttrs`, in `n`'s layout), then the shuffle fired by `n` resumes each lane `j` running
`(u j).resume (r j)`, in turn, every other thread and the memory unchanged. -/
theorem Grid.fire_shfl {L : Launch} {c : Nat → Ctx} {g : Grid} {n : Nat} {mode : Shfl}
    {u : Nat → Thread} {M A B C : Nat → Val} {b cl : Nat → Nat} {d : Nat → Func}
    {r : Nat → Option Val} (hs : 0 < volume L.block)
    (hw : ∀ j ∈ warpLanes L n, g.threads[n - n % volume L.block % 32 + j]? =
        some (.wait (u j) (.shfl mode) [M j, A j, B j, C j] (d j)) ∧
      (M j).word? = some (2 ^ 32 - 1) ∧ (B j).word? = some (b j) ∧ (C j).word? = some (cl j) ∧
      (u j).at = (u (n % volume L.block % 32)).at ∧
      (some (shflVal (warpLanes L n) A (shflSource mode j (b j) (cl j)))).mapM
        (withAttrs (c n).prog.layout g.mem (d j).ret (d j).retAttrs) = .ok (r j)) :
    g.fire L c n = .ok (some ⟨(warpLanes L n).foldl
      (fun ts j => ts.set! (n - n % volume L.block % 32 + j) (.run ((u j).resume (r j))))
        g.threads, g.mem⟩) := by
  have hl : n % volume L.block % 32 ∈ warpLanes L n := by
    simp only [warpLanes, List.mem_filter, List.mem_range, decide_eq_true_eq]
    have := Nat.mod_lt n hs
    have := Nat.mod_le (n % volume L.block) 32
    exact ⟨Nat.mod_lt _ (by decide), by omega⟩
  have hn : n - n % volume L.block % 32 + n % volume L.block % 32 = n := by
    have := Nat.mod_le (n % volume L.block) 32
    have := Nat.mod_le n (volume L.block)
    omega
  obtain ⟨h0, hM0, -, -, -, -⟩ := hw _ hl
  rw [hn] at h0
  have hd : (warpLanes L n).Nodup := List.nodup_range.filter _
  unfold Grid.fire
  rw [h0]
  simp only [hM0, ↓reduceIte, bind, Except.bind, pure, Except.pure]
  rw [mapM_ok_map (g := fun j => some (j, A j, b j, cl j))]
  · rw [show (List.range 32).filter (fun j => n % volume L.block - n % volume L.block % 32 + j <
      volume L.block) = warpLanes L n from rfl]
    dsimp only
    rw [mapM_id_some]
    dsimp only
    rw [resumeAll_eq (u := fun k => u (k - (n - n % volume L.block % 32)))
      (r := fun k => r (k - (n - n % volume L.block % 32)))]
    · simp only [List.map_map, List.foldl_map, Function.comp_def, Nat.add_sub_cancel_left]
    · simp only [List.map_map, Function.comp_def]
      exact hd.map fun _ _ => Nat.add_left_cancel
    · intro k hk
      simp only [List.map_map, Function.comp_def, List.mem_map] at hk
      obtain ⟨j, hj, rfl⟩ := hk
      obtain ⟨hj', -, -, -, -, hr⟩ := hw j hj
      have hf : ((warpLanes L n).map fun j => (j, A j, b j, cl j)).find? (fun x =>
          decide (n - n % volume L.block % 32 + x.1 = n - n % volume L.block % 32 + j)) =
          some (j, A j, b j, cl j) := by
        rw [List.find?_map]
        simp [find?_eq_self, hj]
      have hv : ∀ S, ((((warpLanes L n).map fun j => (j, A j, b j, cl j)).find?
          (fun x => decide (x.1 = S))).map (·.2.1)).getD .poison = shflVal (warpLanes L n) A S := by
        intro S
        rw [List.find?_map]
        unfold shflVal
        split <;> simp [find?_eq_self, *]
      refine ⟨_, _, _, by rw [Nat.add_sub_cancel_left]; exact hj', ?_⟩
      simp only [hf, Option.map_some, hv, Nat.add_sub_cancel_left]
      exact hr
  · intro j hj
    obtain ⟨hj', hM, hB, hC, hat, -⟩ := hw j hj
    simp only [hj', hM, hB, hC, hat, and_self, ↓reduceIte]

/-- A phase's collectives, from the statuses `s` of `N` threads on memory `m` to the threads `t`
on memory `m'`, for launch `L` and contexts `c`: from every grid of `N` threads at the statuses
`s` (thread `n` at `s n`) whose memory is `m`, a run of grid steps reaches a grid of `N` threads
in which thread `n` runs `t n`, with memory `m'`. -/
def Fires (L : Launch) (c : Nat → Ctx) (N : Nat) (s : Nat → Status) (m : Mem) (t : Nat → Thread)
    (m' : Mem) : Prop :=
  ∀ g : Grid, g.threads.size = N → (∀ n < N, g.threads[n]? = some (s n)) → g.mem = m →
    ∃ g', (∃ k, Path (Grid.Step L c) k g g') ∧ g'.threads.size = N ∧
      (∀ n < N, g'.threads[n]? = some (.run (t n))) ∧ g'.mem = m'

/-- A schedule of threads `0` to `N - 1` through collective calls, for launch `L` and contexts
`c`, from the threads `t` on memory `m` to the memory `m'` they end on: phases, each the threads
in turn to their waits (`Seq.ToWait`) and the phase's collectives (`Fires`), then the threads in
turn to their ends (`Seq`). -/
inductive Sched (L : Launch) (c : Nat → Ctx) (N : Nat) : (Nat → Thread) → Mem → Mem → Prop
  /-- The threads in turn to their ends. -/
  | ends {t : Nat → Thread} {m m' : Mem} {Es : List (List Event)} :
      Seq c t (List.range N) m Es m' → Sched L c N t m m'
  /-- The threads in turn to their waits, at the statuses `s` on `m₁`, the collectives from
  there to the threads `t'` on `m₂`, then the schedule from there. -/
  | wait {t : Nat → Thread} {s : Nat → Status} {m m₁ m₂ m' : Mem} {Es : List (List Event)}
      {t' : Nat → Thread} :
      Seq.ToWait c t s (List.range N) m Es m₁ → Fires L c N s m₁ t' m₂ → Sched L c N t' m₂ m' →
        Sched L c N t m m'

/-- **A schedule through collective calls, in a grid.** For every launch `L`, contexts `c`, number
`N`, threads `t` and memories: a schedule (`Sched`) from `t` on `m` to `m'` is, from every grid
of `N` threads in which thread `n` runs `t n` and whose memory is `m`, a run of grid steps to a
done grid (the core's `Done` at `sig`) with memory `m'` (`Seq.ToWait.grid`, each phase's `Fires`,
`Seq.grid`, `Grid.done_foldl`). -/
theorem Sched.grid {L : Launch} {c : Nat → Ctx} {N : Nat} {t : Nat → Thread} {m m' : Mem}
    (h : Sched L c N t m m') : ∀ {g : Grid}, g.threads.size = N →
      (∀ n < N, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ z, (∃ k, Path (Grid.Step L c) k g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' := by
  induction h with
  | ends hs =>
    intro g hsz hg hm
    exact ⟨_, Seq.grid hs List.nodup_range (fun n hn => hg n (List.mem_range.1 hn)) hm,
      Grid.done_foldl _ fun j hj => List.mem_range.2 (hsz ▸ hj), rfl⟩
  | @wait t s _ m₁ _ _ _ _ hw hf _ ih =>
    intro g hsz hg hm
    obtain ⟨_, hp₁⟩ := hw.grid (L := L) List.nodup_range
      (fun n hn => hg n (List.mem_range.1 hn)) hm
    obtain ⟨g₂, hp₂, hsz₂, hg₂, hm₂⟩ := hf ⟨(List.range N).foldl (fun ts n => ts.set! n (s n))
      g.threads, m₁⟩ (by dsimp only; rw [foldl_set_size, hsz]) (fun n hn => by
        dsimp only
        rw [foldl_set_getElem?]
        simp only [List.mem_range, hn, ↓reduceIte, hg n hn, Option.map_some]) rfl
    obtain ⟨z, hp₃, hd, hz⟩ := ih hsz₂ hg₂ hm₂
    exact ⟨z, Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans
      ((Path.exists_iff.1 hp₂).trans (Path.exists_iff.1 hp₃))), hd, hz⟩

/-- **A start that reaches a done grid, sound.** For every program, kernel `fn`, launch `L`,
arguments, address choice and oracle whose start (`Grid.start`) gives grid `g₀` and contexts `c`,
on a caller's memory `m` meeting `Mem.BytesIn`, and every observation `obs` that reads only the
blocks: if `g₀` steps (`Grid.Step`) to a done grid `z` (`GPUProof.Done` at `sig`) whose memory's
trace keeps the promise of `!invariant.load` (the core's `GPUProof.kept` at `sig`), has no data
race (the core's `racy` at `sig`) when it has the premises of `racy_iff`, and has
`obs z.mem = some y` with `R y`, then `g₀` is sound (`Grid.Sound`): `Grid.Done.bad_iff` (with
`Grid.start_reach_size`), `Grid.start_reach_fits` (the done grid, reachable, has the premises of
`racy_iff`) and `Grid.start_sound`. -/
theorem Grid.start_done_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') {i : Nat} {z : Grid}
    (hp : Path (Grid.Step L c) i g₀ z) (hd : GPUProof.Done sig (z, L, c))
    (hr : ((∀ a, Sem.Event.access a ∈ z.mem.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped z.mem.trace.reverse →
      GPUProof.racy sig (z.mem.trace.map (Event.toCore L)).reverse = false))
    (hk : GPUProof.kept sig (z.mem.trace.map (Event.toCore L)).reverse = true)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R := by
  have hf := Grid.start_reach_fits h (Path.exists_iff.1 ⟨_, hp⟩)
  exact Grid.start_sound h hm hO hp hd (fun hb => ((Grid.Done.bad_iff
    (Grid.start_reach_size h (Path.exists_iff.1 ⟨_, hp⟩)).le hd).1 hb).elim
    (fun h' => Bool.false_ne_true ((hr hf.trace hf.2).symm.trans h'))
    fun h' => Bool.false_ne_true (h'.symm.trans hk)) hy hR

/-- **A start through collective calls, sound.** For every program, kernel `fn`, launch `L`,
arguments, address choice and oracle whose start (`Grid.start`) gives grid `g₀` and contexts `c`,
on a caller's memory `m` meeting `Mem.BytesIn`, and every observation `obs` that reads only the
blocks: if the threads of `g₀` (`Grid.thread`) on `g₀`'s memory have a schedule through
collective calls (`Sched`: phases of runs in turn to waits and the phase's collectives, then runs
in turn to the ends) to `m'`, and `m'`'s trace keeps the promise of `!invariant.load` (the
core's `GPUProof.kept` at `sig`), has no data race (the core's `racy` at `sig`) when it has the
premises of `racy_iff`, and has `obs m' = some y` with `R y`, then `g₀` is sound
(`Grid.Sound`): `Sched.grid` with `Grid.start_threads`, then `Grid.start_done_sound`. -/
theorem Sched.start_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') {m' : Mem}
    (hs : Sched L c g₀.threads.size (Grid.thread g₀) g₀.mem m')
    (hr : ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
      GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false))
    (hk : GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true)
    {y : β} (hy : obs m' = some y) (hR : R y) : Grid.Sound L c g₀ obs R := by
  obtain ⟨z, ⟨_, hp⟩, hd, rfl⟩ := Sched.grid (g := g₀) hs rfl (Grid.start_threads h) rfl
  exact Grid.start_done_sound h hm hO hp hd hr hk hy hR

/-- **The barriers as a phase's collectives.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, number `B` of blocks, `N = B * volume L.block` and
memory `m`: if every thread `n < N` waits, from thread `u n`, at a barrier call with argument
`x n` and callee `d n`, every `x n` is the number `bar (n / volume L.block) < 16` of its block,
and every `u n` is at the instruction the first thread of its block is at, then the blocks'
barriers take the threads, resumed with no value (`Thread.resume`), to the memory `m` with the
blocks' `.barrier`s logged in turn (`Fires`, by `Grid.fire_barriers`). -/
theorem Fires.barriers {L : Launch} {c : Nat → Ctx} {N B : Nat} {u : Nat → Thread}
    {x : Nat → Val} {d : Nat → Func} {bar : Nat → Nat} {m : Mem} (hs : 0 < volume L.block)
    (hN : N = B * volume L.block)
    (hx : ∀ n < N, (x n).word? = some (bar (n / volume L.block)) ∧ bar (n / volume L.block) < 16 ∧
      (u n).at = (u (n / volume L.block * volume L.block)).at) :
    Fires L c N (fun n => .wait (u n) .barrier [x n] (d n)) m (fun n => (u n).resume none)
      ((List.range B).foldl (fun m b => m.log (.barrier b)) m) := by
  intro g hsz hg hm
  subst hN
  obtain ⟨g', hp, hsz', hj, hm'⟩ := Grid.fire_barriers (c := c) (u := u) (x := x) (d := d)
    (bar := bar) hs B (g := g) fun n hn => ⟨hg n hn, hx n hn⟩
  exact ⟨g', hp, hsz'.trans hsz, fun n hn => by rw [hj, ite_eq_left hn], by rw [hm', hm]⟩

/-- **A start through one barrier, sound.** For every program, kernel `fn`, launch `L`,
arguments, address choice and oracle whose start (`Grid.start`) gives grid `g₀` and contexts `c`,
on a caller's memory `m` meeting `Mem.BytesIn`, and every observation `obs` that reads only the
blocks, with blocks of `volume L.block > 0` threads: if threads `0` to `N - 1` (`N` the number of
threads of `g₀`), each from its thread in `g₀` (`Grid.thread`), run in turn to a barrier call
(`Seq.ToWait`), thread `n` waiting from thread `u n` with argument `x n`, from `g₀`'s memory to
`m₁`; every `x n` is the number `bar (n / volume L.block) < 16` of its block and every `u n`
is at the instruction the first thread of its block is at; the threads resumed with no value
(`Thread.resume`) then run in turn to their ends (`Seq`) from `m₁` with the `volume L.grid`
blocks' `.barrier`s logged, to `m'`; and
`m'`'s trace keeps the promise of `!invariant.load` (the core's `GPUProof.kept` at `sig`), has
no data race (the core's `racy` at `sig`) when it has the premises of `racy_iff`, and has
`obs m' = some y` with `R y`: then `g₀` is sound (`Grid.Sound`).
`Sched.start_sound` at the schedule of one phase, `Fires.barriers` (`Grid.start_size`). -/
theorem Seq.start_sound_bar {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {u : Nat → Thread} {x : Nat → Val} {d : Nat → Func} {bar : Nat → Nat}
    {Es₁ : List (List Event)} {m₁ : Mem}
    (hs0 : 0 < volume L.block)
    (hw : Seq.ToWait c (Grid.thread g₀) (fun n => .wait (u n) .barrier [x n] (d n))
      (List.range g₀.threads.size) g₀.mem Es₁ m₁)
    (hx : ∀ n < g₀.threads.size, (x n).word? = some (bar (n / volume L.block)) ∧
      bar (n / volume L.block) < 16 ∧ (u n).at = (u (n / volume L.block * volume L.block)).at)
    {Es₂ : List (List Event)} {m' : Mem}
    (hs : Seq c (fun n => (u n).resume none) (List.range g₀.threads.size)
      ((List.range (volume L.grid)).foldl (fun m b => m.log (.barrier b)) m₁) Es₂ m')
    (hr : ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
      GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false))
    (hk : GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true)
    {y : β} (hy : obs m' = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  Sched.start_sound h hm hO (.wait hw (Fires.barriers hs0 (Grid.start_size h) hx) (.ends hs)) hr hk
    hy hR

/-- **A shuffle as a phase's collectives.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, number `B` of blocks, `N = B * volume L.block`, mode
`mode` and memory `m`: write `p n = n % volume L.block % 32` for thread `n`'s lane and `n - p n`
for its warp's first thread. If every thread `n < N` waits, from thread `u n`, at a shuffle of mode
`mode` with member mask `M n` (the full mask `2^32 - 1`), value `A n`, lane operand `O n` of
number `b n`, clamp `C n` of number `cl n` and callee `d n`, at the instruction its warp's first
thread is at, and its callee's return attributes take the value its warp's lane
`shflSource mode (p n) (b n) (cl n)` offers (`shflVal` over its warp's lanes `warpLanes L n`, the
value `A` of thread `n - p n + j` at lane `j`; `poison` for a lane not of the warp) to `r n` in
`m` (`withAttrs`, in the layout of the context of `n - p n`), then the warps' shuffles take each
thread `n`, resumed with `r n` (`Thread.resume`), to the same memory `m` (`Fires`, by
`Grid.fire_shfl` at the warps' first threads in turn). -/
theorem Fires.shfls {L : Launch} {c : Nat → Ctx} {N B : Nat} {mode : Shfl} {m : Mem}
    {u : Nat → Thread} {M A O C : Nat → Val} {b cl : Nat → Nat} {d : Nat → Func}
    {r : Nat → Option Val} (hs : 0 < volume L.block) (hN : N = B * volume L.block)
    (hw : ∀ n < N, (M n).word? = some (2 ^ 32 - 1) ∧ (O n).word? = some (b n) ∧
      (C n).word? = some (cl n) ∧ (u n).at = (u (n - n % volume L.block % 32)).at ∧
      (some (shflVal (warpLanes L n) (fun j => A (n - n % volume L.block % 32 + j))
        (shflSource mode (n % volume L.block % 32) (b n) (cl n)))).mapM
        (withAttrs (c (n - n % volume L.block % 32)).prog.layout m (d n).ret (d n).retAttrs) =
          .ok (r n)) :
    Fires L c N (fun n => .wait (u n) (.shfl mode) [M n, A n, O n, C n] (d n)) m
      (fun n => (u n).resume (r n)) m := by
  intro g hsz hg hm
  beta_reduce at hg ⊢
  -- `s` threads a block; a thread's warp starts at `n - n % s % 32`, a multiple of 32 in its block
  generalize hS : volume L.block = s at hs hN hw
  have hbase : ∀ n, (n - n % s % 32) % s = n % s - n % s % 32 := fun n => by
    have h1 := Nat.mod_add_div n s
    have h2 := Nat.mod_le (n % s) 32
    have h3 := Nat.mod_lt n hs
    rw [show n - n % s % 32 = n % s - n % s % 32 + s * (n / s) by omega,
      Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (by omega)]
  -- a lane `j` of the warp that starts at `k`
  have hlane : ∀ k j, k % s % 32 = 0 → j < 32 → k % s + j < s →
      (k + j) % s = k % s + j ∧ (k + j) / s = k / s := fun k j _ _ hj => by
    have h1 := Nat.mod_add_div k s
    rw [show k + j = k % s + j + s * (k / s) by omega, Nat.add_mul_mod_self_left,
      Nat.add_mul_div_left _ _ hs, Nat.mod_eq_of_lt hj, Nat.div_eq_of_lt hj, Nat.zero_add]
    exact ⟨rfl, rfl⟩
  have hmem : ∀ k n, k % s % 32 = 0 → (n ∈ (warpLanes L k).map (k + ·) ↔ n - n % s % 32 = k) :=
    fun k n hk => by
      simp only [List.mem_map, warpLanes, hS, List.mem_filter, List.mem_range, decide_eq_true_eq]
      constructor
      · rintro ⟨j, ⟨hj, hj'⟩, rfl⟩
        have := (hlane k j hk hj (by omega)).1
        rw [this]
        omega
      · intro e
        have := hbase n
        rw [e] at this
        have := Nat.mod_lt n hs
        have := Nat.mod_le (n % s) 32
        have := Nat.mod_le n s
        exact ⟨n % s % 32, ⟨Nat.mod_lt _ (by decide), by omega⟩, by omega⟩
  -- the warps whose first thread is below `k` fired
  have key : ∀ k ≤ N, ∃ g', (∃ i, Path (Grid.Step L c) i g g') ∧ g'.threads.size = N ∧
      (∀ n < N, g'.threads[n]? = some (if n - n % s % 32 < k then .run ((u n).resume (r n))
        else .wait (u n) (.shfl mode) [M n, A n, O n, C n] (d n))) ∧ g'.mem = m := by
    intro k
    induction k with
    | zero => exact fun _ => ⟨g, ⟨0, .nil _⟩, hsz, fun n hn => by simp [hg n hn], hm⟩
    | succ k ih =>
      intro hk
      obtain ⟨g₁, hp, hsz₁, hst, hm₁⟩ := ih (by omega)
      by_cases hl : k % s % 32 = 0
      · have hf := Grid.fire_shfl (L := L) (c := c) (g := g₁) (n := k) (mode := mode)
          (u := fun j => u (k + j)) (M := fun j => M (k + j)) (A := fun j => A (k + j))
          (B := fun j => O (k + j)) (C := fun j => C (k + j)) (b := fun j => b (k + j))
          (cl := fun j => cl (k + j)) (d := fun j => d (k + j)) (r := fun j => r (k + j))
          (by rw [hS]; exact hs) fun j hj => by
            rw [hS, hl, Nat.sub_zero, Nat.add_zero]
            have hj' := hj
            simp only [warpLanes, hS, List.mem_filter, List.mem_range, decide_eq_true_eq] at hj'
            obtain ⟨hj1, hj2⟩ := hj'
            obtain ⟨e1, e2⟩ := hlane k j hl hj1 (by omega)
            have e3 : (k + j) % s % 32 = j := by rw [e1]; omega
            have e4 : k + j - (k + j) % s % 32 = k := by rw [e3]; omega
            have hkj : k + j < N := by
              rw [hN, ← Nat.div_lt_iff_lt_mul hs, e2, Nat.div_lt_iff_lt_mul hs, ← hN]
              omega
            have e5 : warpLanes L (k + j) = warpLanes L k := by
              unfold warpLanes
              rw [hS, e3, e1, hl, Nat.add_sub_cancel, Nat.sub_zero]
            obtain ⟨hM, hO, hC, hat, hr⟩ := hw (k + j) hkj
            rw [e4] at hat hr
            rw [e5, e3] at hr
            refine ⟨?_, hM, hO, hC, hat, by rw [hm₁]; exact hr⟩
            rw [hst _ hkj, e4, ite_eq_right (Nat.lt_irrefl k)]
        beta_reduce at hf
        rw [hS, hl, Nat.sub_zero] at hf
        have e : (warpLanes L k).foldl (fun ts j => ts.set! (k + j)
            (.run ((u (k + j)).resume (r (k + j))))) g₁.threads =
            ((warpLanes L k).map (k + ·)).foldl (fun ts n => ts.set! n
              (.run ((u n).resume (r n)))) g₁.threads := by
          rw [List.foldl_map]
        refine ⟨_, Path.exists_iff.2 ((Path.exists_iff.1 hp).tail ⟨k, .inr hf⟩), ?_,
          fun n hn => ?_, hm₁⟩
        · dsimp only
          rw [e, foldl_set_size, hsz₁]
        · dsimp only
          rw [e, foldl_set_getElem?, hst n hn]
          by_cases hb : n - n % s % 32 = k
          · simp [(hmem k n hl).2 hb, hb]
          · have hb' : n - n % s % 32 < k + 1 ↔ n - n % s % 32 < k := by omega
            simp [mt (hmem k n hl).1 hb, hb']
      · refine ⟨g₁, hp, hsz₁, fun n hn => ?_, hm₁⟩
        rw [hst n hn]
        have hb : n - n % s % 32 ≠ k := fun e => hl (by
          have := hbase n
          rw [e] at this
          rw [this]
          omega)
        have hb' : n - n % s % 32 < k + 1 ↔ n - n % s % 32 < k := by omega
        simp only [hb']
  obtain ⟨g', hp, hsz', hj, hm'⟩ := key N le_rfl
  exact ⟨g', hp, hsz', fun n hn => by rw [hj n hn, ite_eq_left (by omega)], hm'⟩

/-- **The butterfly rounds of the shuffles.** For every carrier, combination `F r l` per round `r`
and lane `l`, width `2 ^ k` with `k ≤ 5` (at most a warp), offsets `ms` below `2 ^ k`, values
`v r l` of lane `l` at round `r` and first values `w` that are the lanes' values at round 0 below
`2 ^ k`: if at every round `r` each lane `l < 2 ^ k` combines, by `F r l`, its value with that of
the lane a butterfly shuffle with offset `ms[r]` and clamp 31 reads (`shflSource`, which is
`l ^^^ ms[r]` by `shflSource_bfly`), then after the rounds each lane `l < 2 ^ k` holds the
butterfly rounds of `w` (`bflyRoundsAt`, MojoProof/Sem/Bfly.lean). With one combining operation
`combine`, `F` is `fun _ _ => combine` and the rounds are `bflyRounds combine`. -/
theorem bflyRoundsAt_of_shfl {β : Type} {k : Nat} (hk : k ≤ 5) :
    ∀ {ms : List Nat}, (∀ m ∈ ms, m < 2 ^ k) →
      ∀ {F : Nat → Nat → β → β → β} {v : Nat → Nat → β} {w : Nat → β},
      (∀ l < 2 ^ k, v 0 l = w l) → (∀ r (hr : r < ms.length), ∀ l < 2 ^ k,
        v (r + 1) l = F r l (v r l) (v r (shflSource .bfly l ms[r] 31))) →
      ∀ l < 2 ^ k, v ms.length l = bflyRoundsAt F ms w l := by
  have h32 : 2 ^ k ≤ 32 := Nat.pow_le_pow_right (by decide) hk
  intro ms
  induction ms with
  | nil => exact fun _ _ v w h0 _ l hl => h0 l hl
  | cons a ms ih =>
    intro hm F v w h0 h l hl
    have ha := hm a List.mem_cons_self
    refine ih (fun m hm' => hm m (List.mem_cons_of_mem a hm')) (F := fun r => F (r + 1))
      (v := fun r => v (r + 1)) (w := fun l => F 0 l (w l) (w (l ^^^ a))) (fun l hl => ?_)
      (fun r hr l hl => h (r + 1) (by simp only [List.length_cons]; omega) l hl) l hl
    have hx : l ^^^ a < 2 ^ k := Nat.xor_lt_two_pow hl ha
    show v (0 + 1) l = F 0 l (w l) (w (l ^^^ a))
    rw [h 0 (by simp) l hl, List.getElem_cons_zero, shflSource_bfly (by omega) (by omega),
      h0 l hl, h0 _ hx]

end MojoProof.Sym
