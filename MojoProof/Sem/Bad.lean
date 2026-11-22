import MojoProof.Sem.Confluence

/-!
# T2's bad grids: `Grid.RaceEnabled`, `Grid.Bad`, `bad_eqv` and `bad_step`

The bad grids of T2 (docs/proofs/schedule.md, "Definitions the proof adds"): a grid is bad
(`Grid.Bad`) if it faults, its trace has a data race or breaks the promise of `!invariant.load`,
or a race is enabled (`Grid.RaceEnabled`: the trace with some running thread's pending accesses
in front is racy). Proved here:

- `Stmt.pending_retrace`, `Thread.pending_retrace`: for every context, scope or memory and trace,
  the pending accesses read no trace.
- `Grid.Same.raceEnabled` and so `Grid.Same.bad` (`bad_eqv` of `Confluent`): for every launch,
  contexts and grids, a grid the same as a bad grid (`Grid.Same`) is bad.
- `Grid.Step.trace`: for every launch and contexts, a step puts events in front of the trace;
  `kept_append`: a trace that breaks the promise breaks it with events in front.
- `Grid.Step.raceEnabled`: for every launch, contexts and closed grid in which no collective call
  that completes logs a barrier of a running thread's block of threads, a step from a grid with
  an enabled race gives a racy trace (the step of the racing thread, which logs its pending
  accesses) or a grid with the race still enabled (by L1c, `Grid.pending_reach`, and L13,
  `racy_insert`).
- `Grid.Step.bad_trace`: `bad_step` for the three parts of `Grid.Bad` other than faults, under the
  premises of `Grid.Step.raceEnabled`; `Grid.start_reach_bad_trace`: the same for a step from
  every grid reachable from the start's, for every program, kernel, launch, arguments, address
  choice and oracle, on a caller's memory whose pointer bytes name known numbers
  (`Grid.start_reach_closed`, `Grid.start_reach_fired`).

- `races_mem`, `racy_conflict`: an access races with events in front of a trace that hold, with no
  barrier of its block of threads, an access by another thread that conflicts with it; so a trace
  with the access in front of such events is racy. `Access.conflict_comm`: conflict is symmetric.
  `Grid.advance_raceEnabled` (the diamond's conflict case): for every closed grid, the step of a
  thread `k` with a pending access that conflicts with one of a running thread `n` of another
  thread number enables a race.
- `Grid.advance_error`: a step that faults is that of a running thread. `Grid.advance_fault` (L2
  for a fault): for every closed grid whose threads own their allocas, the fault of thread `n`'s
  step persists after the step of a thread `k` with another thread number none of whose pending
  writes overlaps an access of `n`'s (`step_fault`). `Grid.advance_fault_atomic` (L10 for
  faults): for every closed grid, it persists after the step of a thread `k ≠ n` with a pending
  access by an `atomicrmw` at the pointer and size of one of `n`'s (`Mem.update_before`).
  `Grid.advance_fault_fire`: for every launch, contexts and grid, it persists after a collective
  call completes.
- `Grid.Step.advance_fault`: for every launch, contexts and closed grid whose threads own their
  allocas and have thread numbers other than that of thread `n`, whose step faults: after a step
  the grid faults or has a race enabled.
- `mapM_error`: where one `mapM` throws and another over the same list succeeds, the two functions
  differ at a member where the first throws. `resumeAll_set_eq`, `resumeAll_shape`,
  `resumeAll_none`: `resumeAll` commutes with a `set!` at a thread it does not resume, gives the
  same in two memories of the same shape at the blocks its results name, and with no results
  succeeds.
- `Grid.fire_error_advance`: for every launch, contexts and closed grid, a fault of thread `n`'s
  collective call persists after a thread's step. `Grid.fire_lane`: in contexts with one layout,
  if the call of a lane of `n`'s warp inside its block of threads completes, `n`'s completes to
  the same grid. `Grid.fire_error_fire`: for every launch, grid and contexts with one layout, a
  fault of `n`'s collective call persists after another collective call completes.
- `Grid.Step.bad`: `bad_step` for every launch, contexts with one layout and closed grid whose
  threads own their allocas and have different thread numbers, in which no collective call that
  completes logs a barrier of a running thread's block of threads; `Grid.start_reach_bad`: the
  same for a step from every grid reachable from the start's, as for
  `Grid.start_reach_bad_trace`.

The premise of one layout, `hl` of `Grid.Step.bad`, is needed (MojoProofTest/Bad.lean
`fire_fault_twin`: a fire that faults under one thread's layout completes under another's, and
the grid after is not bad). `Grid.advance_fault_atomic` rests on `exec`'s check that an
`atomicrmw`'s operand is a scalar of its type (MojoProofTest/Bad.lean `update_before`:
without it, an update by a pointer faults before another thread's update and succeeds after it).
`Grid.confluent` and `Grid.start_sound` are in MojoProof/Sem/Determinism.lean.
-/

namespace MojoProof.Sem

open MojoProof.LLVM

/-- Some running thread `n` of grid `g` has pending accesses that make the trace racy when put in
front of it (T2's `RaceEnabled`): its step would log them there. This includes every grid with a
running thread whose trace is already racy. -/
def Grid.RaceEnabled (c : Nat → Ctx) (g : Grid) : Prop :=
  ∃ (n : Nat) (t : Thread), g.threads[n]? = some (.run t) ∧
    racy (t.pending (c n) g.mem ++ g.mem.trace) = true

/-- Grid `g` is bad: it faults, its trace has a data race or breaks the promise of
`!invariant.load`, or a race is enabled (T2's `Bad`). -/
def Grid.Bad (L : Launch) (c : Nat → Ctx) (g : Grid) : Prop :=
  g.Faults L c ∨ racy g.mem.trace = true ∨ kept g.mem.trace = false ∨ g.RaceEnabled c

/-- The pending accesses of a statement read no trace. -/
theorem Stmt.pending_retrace (c : Ctx) (s : Scope) (tr : List Event) (st : Stmt) :
    st.pending c (s.retrace tr) = st.pending c s := by
  simp only [LLVM.Stmt.pending, evalV_retrace]

/-- The pending accesses of a thread read no trace. -/
theorem Thread.pending_retrace (c : Ctx) (t : Thread) (m : Mem) (tr : List Event) :
    t.pending c { m with trace := tr } = t.pending c m := by
  have hs : ∀ f k, c.scope { m with trace := tr } f k = (c.scope m f k).retrace tr :=
    fun _ _ => rfl
  simp only [Thread.pending, hs, Stmt.pending_retrace]

/-- For every contexts, a grid the same as one with an enabled race has the race enabled: the
same thread runs with the same pending accesses (`Thread.pending_retrace`) in front of a trace
that is the same (L11), so racy too (L12). -/
theorem Grid.Same.raceEnabled {c : Nat → Ctx} {g₁ g₂ : Grid} (h : g₁.Same g₂)
    (he : g₁.RaceEnabled c) : g₂.RaceEnabled c := by
  obtain ⟨n, t, ht, hr⟩ := he
  refine ⟨n, t, h.1 ▸ ht, ?_⟩
  have e : t.pending (c n) g₂.mem = t.pending (c n) g₁.mem := by
    rw [h.eq_retrace]
    exact Thread.pending_retrace _ _ _ _
  rw [e, ← (h.2.2.2.append _).racy]
  exact hr

/-- **`bad_eqv`** (T2, docs/proofs/schedule.md). For every launch and contexts, a grid the same as
a bad grid is bad: faults by `Grid.Same.faults`, the trace by L12, an enabled race by
`Grid.Same.raceEnabled`. -/
theorem Grid.Same.bad {L : Launch} {c : Nat → Ctx} {g₁ g₂ : Grid} (h : g₁.Same g₂)
    (hb : g₁.Bad L c) : g₂.Bad L c :=
  hb.imp h.faults.1 <| Or.imp (fun hr => h.2.2.2.racy.symm.trans hr) <|
    Or.imp (fun hk => h.2.2.2.kept.symm.trans hk) h.raceEnabled

/-- For every launch and contexts, a step puts events in front of the trace: a thread's step its
pending accesses (`Grid.advance_pending`), a collective call's completion its events
(`Grid.fire_trace`). -/
theorem Grid.Step.trace {L : Launch} {c : Nat → Ctx} {g g' : Grid} (h : Grid.Step L c g g') :
    ∃ E, g'.mem.trace = E ++ g.mem.trace := by
  obtain ⟨n, h | h⟩ := h
  · obtain ⟨_, _, e⟩ := Grid.advance_pending h
    exact ⟨_, e⟩
  · obtain ⟨_, _, _, _, _, e⟩ := Grid.fire_trace h
    exact ⟨_, e⟩

/-- A trace that breaks the promise of `!invariant.load` breaks it with events in front. -/
theorem kept_append {tr : List Event} (h : kept tr = false) :
    ∀ E : List Event, kept (E ++ tr) = false
  | [] => h
  | e :: E => kept_cons e (kept_append h E)

/-- **`bad_step` for an enabled race.** For every launch, contexts and closed grid `g` in which no
collective call that completes logs a barrier of a running thread's block of threads (`hw`): if a
race is enabled at thread `n` and `g` steps, the trace after is racy, or a race is still
enabled. If `n` steps, it logs its pending accesses `P` (L1a). Otherwise `n` runs with the same
`P` (L1c, `Grid.pending_reach`), and the step puts in front of the trace another thread's
accesses or a call's events, none a barrier of `n`'s block of threads, so `P` still races (L13,
`racy_insert`). -/
theorem Grid.Step.raceEnabled {L : Launch} {c : Nat → Ctx} {g g' : Grid} (hg : g.Closed c)
    (hw : ∀ n k t gf, g.threads[n]? = some (.run t) → g.fire L c k = .ok (some gf) →
      .barrier (c n).who.cta ∉ g.fired L k)
    (hs : Grid.Step L c g g') (he : g.RaceEnabled c) :
    racy g'.mem.trace = true ∨ g'.RaceEnabled c := by
  obtain ⟨n, t, ht, hr⟩ := he
  have hP : ∀ e ∈ t.pending (c n) g.mem, ∃ a, e = .access a ∧ a.who = (c n).who :=
    Thread.pending_who
  have hp' : t.pending (c n) g'.mem = t.pending (c n) g.mem := Grid.pending_reach hg (.single hs) ht
  obtain ⟨k, hk | hk⟩ := hs
  · obtain ⟨tk, s, mk, htk, rfl, htr, -⟩ := Grid.advance_set hk
    by_cases hkn : k = n
    · subst hkn
      refine .inl ?_
      rw [show mk.trace = _ from htr]
      simp only [Grid.pending, ht]
      exact hr
    · refine .inr ⟨n, t, ?_, ?_⟩
      · simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hkn, ht]
      · rw [hp']
        show racy (t.pending (c n) g.mem ++ mk.trace) = true
        rw [htr, ← List.append_assoc]
        refine racy_insert (fun hb => ?_) hP hr
        unfold Grid.pending at hb
        rw [htk] at hb
        obtain ⟨_, e, -⟩ := Thread.pending_who _ hb
        cases e
  · obtain ⟨P, _, hPw, -, hPr, hPm, -⟩ := Grid.fire_frame hk
    have hnP : n ∉ P := fun hp => by
      obtain ⟨_, _, _, _, e⟩ := hPw n hp
      rw [ht] at e
      cases e
    refine .inr ⟨n, t, (resumeAll_getElem? hPr hnP).trans ht, ?_⟩
    rw [hp', hPm]
    show racy (t.pending (c n) g.mem ++ (g.fired L k ++ g.mem.trace)) = true
    rw [← List.append_assoc]
    exact racy_insert (hw n k t _ ht hk) hP hr

/-- **`bad_step` without faults.** For every launch, contexts and closed grid in which no
collective call that completes logs a barrier of a running thread's block of threads: a step from
a grid whose trace is racy or breaks the promise of `!invariant.load`, or that has an enabled
race, gives a grid with one of the three. The trace gets events in front (`Grid.Step.trace`;
`racy_append`, `kept_append`), and an enabled race is `Grid.Step.raceEnabled`. -/
theorem Grid.Step.bad_trace {L : Launch} {c : Nat → Ctx} {g g' : Grid} (hg : g.Closed c)
    (hw : ∀ n k t gf, g.threads[n]? = some (.run t) → g.fire L c k = .ok (some gf) →
      .barrier (c n).who.cta ∉ g.fired L k)
    (hs : Grid.Step L c g g')
    (hb : racy g.mem.trace = true ∨ kept g.mem.trace = false ∨ g.RaceEnabled c) :
    racy g'.mem.trace = true ∨ kept g'.mem.trace = false ∨ g'.RaceEnabled c := by
  obtain ⟨E, hE⟩ := hs.trace
  rcases hb with hb | hb | hb
  · exact .inl (by rw [hE]; exact racy_append hb E)
  · exact .inr (.inl (by rw [hE]; exact kept_append hb E))
  · exact (hs.raceEnabled hg hw hb).imp_right .inr

/-- **`bad_step` without faults, from the start.** For every program, kernel, launch, arguments,
address choice and oracle, on a caller's memory every pointer byte of whose blocks names a number
below `next` or with a block, in every grid reachable from the start's: `Grid.Step.bad_trace`,
whose grid is closed (`Grid.start_reach_closed`) and in which no collective call that completes
logs a barrier of a running thread's block of threads (`Grid.start_reach_fired`). -/
theorem Grid.start_reach_bad_trace {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g) (hs : Grid.Step L c g g')
    (hb : racy g.mem.trace = true ∨ kept g.mem.trace = false ∨ g.RaceEnabled c) :
    racy g'.mem.trace = true ∨ kept g'.mem.trace = false ∨ g'.RaceEnabled c :=
  hs.bad_trace (Grid.start_reach_closed h hm hr)
    (fun _ _ _ _ hn hf => Grid.start_reach_fired h hr hn hf) hb

/-- An access races with events `X` in front of a trace if `X` has no barrier of its block of
threads and an access by another thread that conflicts with it. -/
theorem races_mem {a b : Access} {tr : List Event} :
    ∀ {X : List Event}, .barrier a.who.cta ∉ X → .access b ∈ X → b.who.thread ≠ a.who.thread →
      a.conflict b = true → a.races false (X ++ tr) = true
  | [], _, hb, _, _ => by simp at hb
  | .access e :: X, hX, hb, ht, hc => by
    rcases List.mem_cons.1 hb with he | hb
    · cases he
      simp [Access.races, ht, hc]
    · simp [Access.races, races_mem (fun h => hX (List.mem_cons_of_mem _ h)) hb ht hc]
  | .barrier k :: X, hX, hb, ht, hc => by
    have hk : k ≠ a.who.cta := fun hk => hX (hk ▸ List.mem_cons_self)
    rw [List.cons_append, Access.races, beq_eq_false_iff_ne.2 hk, Bool.or_false]
    exact races_mem (fun h => hX (List.mem_cons_of_mem _ h)) (by simpa using hb) ht hc

/-- **The race of a conflict** (the diamond's conflict case, docs/proofs/schedule.md). A trace
with events `P` in front, one of them the access `a`, after events `Q` with an access by another
thread that conflicts with `a`, is racy if neither `P` nor `Q` has a barrier of `a`'s block of
threads. -/
theorem racy_conflict {a b : Access} {tr Q : List Event} (hQ : .barrier a.who.cta ∉ Q)
    (hb : .access b ∈ Q) (ht : b.who.thread ≠ a.who.thread) (hc : a.conflict b = true) :
    ∀ {P : List Event}, .barrier a.who.cta ∉ P → .access a ∈ P → racy (P ++ Q ++ tr) = true
  | [], _, ha => by simp at ha
  | e :: P, hP, ha => by
    have hP' : .barrier a.who.cta ∉ P := fun h => hP (List.mem_cons_of_mem _ h)
    rcases List.mem_cons.1 ha with rfl | ha
    · have h := races_mem (tr := tr) (fun h => (List.mem_append.1 h).elim hP' hQ)
        (List.mem_append_right P hb) ht hc
      simp only [List.cons_append, racy, Bool.or_eq_true]
      exact .inl h
    · exact racy_cons e (racy_conflict hQ hb ht hc hP' ha)

/-- `Access.conflict` is symmetric. -/
theorem Access.conflict_comm (a e : Access) : a.conflict e = e.conflict a := by
  rw [Bool.eq_iff_iff]
  simp only [Access.conflict, Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq,
    Bool.or_eq_true, Bool.not_eq_true']
  grind

/-- **The diamond's conflict case** (docs/proofs/schedule.md). For every closed grid: if the step
of thread `k` succeeds and one of its pending accesses conflicts with one of a running thread `n`
of another thread number, the grid after has a race enabled. `k`'s step logs its pending
accesses, `n` runs with the same pending accesses (L1c, `Thread.pending_shape`), and neither has
a barrier (`racy_conflict`). -/
theorem Grid.advance_raceEnabled {c : Nat → Ctx} {g g' : Grid} {n k : Nat} {t : Thread}
    (hg : g.Closed c) (hw : (c n).who.thread ≠ (c k).who.thread)
    (ht : g.threads[n]? = some (.run t)) (hk : g.advance c k = .ok (some g'))
    {a a' : Access} (ha : .access a ∈ g.pending c n) (ha' : .access a' ∈ g.pending c k)
    (hc : a.conflict a' = true) : g'.RaceEnabled c := by
  have hkn : k ≠ n := by
    rintro rfl
    exact hw rfl
  have hp := Thread.pending_shape ((Grid.advance_keeps hk).sameShape fun _ hb hn => hb.below hn)
    fun f hf => ⟨hg.null, hg.threads n _ ht f (List.mem_of_mem_head? hf), hg.globals n⟩
  obtain ⟨_, s, mk, -, rfl, htr, -⟩ := Grid.advance_set hk
  have hnb : ∀ j w, .barrier w ∉ g.pending c j := fun j w hb => by
    unfold Grid.pending at hb
    split at hb
    · obtain ⟨_, e, -⟩ := Thread.pending_who _ hb
      cases e
    · cases hb
  have hn : g.pending c n = t.pending (c n) g.mem := by simp only [Grid.pending, ht]
  refine ⟨n, t, ?_, ?_⟩
  · simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hkn, ht]
  · rw [hp]
    show racy (t.pending (c n) g.mem ++ mk.trace) = true
    rw [htr, ← List.append_assoc, ← hn]
    exact racy_conflict (hnb k _) ha'
      (by rw [Grid.pending_who ha, Grid.pending_who ha']; exact hw.symm) hc (hnb n _) ha

/-- A step of thread `n` that faults: `n` runs, and its step faults. -/
theorem Grid.advance_error {c : Nat → Ctx} {g : Grid} {n : Nat} {x : Fault}
    (h : g.advance c n = .error x) :
    ∃ t, g.threads[n]? = some (.run t) ∧ step (c n) t g.mem = .error x := by
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    refine ⟨t, ht, ?_⟩
    cases hs : step (c n) t g.mem with
    | error y => simpa [hs, bind, Except.bind] using h
    | ok r => cases r <;> simp [hs, bind, Except.bind, pure, Except.pure] at h
  · cases h

/-- **L2 for a fault of a thread.** For every closed grid whose threads own their allocas, and
threads `n` and `k` with different thread numbers in their contexts: if `n`'s step faults and no
write among `k`'s pending accesses overlaps one of `n`'s, `n`'s step faults after `k`'s
(`step_fault`, with `Grid.advance_agree_other`). -/
theorem Grid.advance_fault {c : Nat → Ctx} {g g' : Grid} {n k : Nat} {x : Fault} (hg : g.Closed c)
    (ho : g.Owns c) (hw : (c n).who.thread ≠ (c k).who.thread)
    (hW : ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
      a.overlaps a' = true → a'.write = false)
    (hk : g.advance c k = .ok (some g')) (he : g.advance c n = .error x) :
    ∃ y, g'.advance c n = .error y := by
  have hnk : k ≠ n := fun e => hw (by rw [e])
  obtain ⟨t, ht, hs⟩ := Grid.advance_error he
  obtain ⟨tk, _, _, htk, rfl, -, -⟩ := Grid.advance_set hk
  simp only [Grid.pending, ht, htk] at hW
  obtain ⟨y, hy⟩ := step_fault (S := fun b => g.mem.Known b ∨ b = g.mem.fresh (c n).who.thread t.k)
    (hg.scope ht fun _ => Or.inl) (Or.inr rfl)
    (Grid.advance_agree_other (t' := t) ho hw.symm htk
      (fun a a' ha ha' hov => hW a' a ha' ha ((Access.overlaps_comm a' a).trans hov)) hk) hs
  refine ⟨y, ?_⟩
  unfold Grid.advance
  simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hnk, ht, hy, bind,
    Except.bind]

/-- A fault of a thread's step persists after a collective call completes, for every launch,
contexts and grid: the call resumes waiting threads only and puts its events in front of the
trace (`Grid.fire_frame`), which the step does not read (`step_retrace`). -/
theorem Grid.advance_fault_fire {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n k : Nat}
    {x : Fault} (hk : g.fire L c k = .ok (some g')) (he : g.advance c n = .error x) :
    g'.advance c n = .error x := by
  obtain ⟨t, ht, hs⟩ := Grid.advance_error he
  obtain ⟨P, _, hPw, -, hPr, hPm, -⟩ := Grid.fire_frame hk
  have hnP : n ∉ P := fun hp => by
    obtain ⟨_, _, _, _, e⟩ := hPw n hp
    rw [ht] at e
    cases e
  have e : step (c n) t g'.mem = .error x := by
    rw [hPm]
    exact (step_retrace _ _ _ _).trans (by rw [hs]; rfl)
  unfold Grid.advance
  rw [(resumeAll_getElem? hPr hnP).trans ht]
  simp only [e, bind, Except.bind]

/-- **L2 for a fault at an `atomicrmw`, after an update of the same bytes** (L10 for faults). For
every closed grid and contexts and threads `n ≠ k`: if `n`'s step faults, `k`'s step gives `g'`,
and a pending access of `n` and one of `k` are by `atomicrmw`s at one pointer and size, `n`'s
step faults after `k`'s. Were it to succeed after `k`'s, it would be an update by a scalar
operand there and from `g` (`step_atomic`, as `n`'s pending accesses and scope are the same,
`Thread.pending_shape`), `k`'s step is an update of the same type at the same pointer
(`Grid.advance_atomic`), and an update that succeeds after it succeeds before it
(`Mem.update_before`). -/
theorem Grid.advance_fault_atomic {c : Nat → Ctx} {g g' : Grid} {n k : Nat} {x : Fault}
    (hg : g.Closed c) (hnk : n ≠ k) (hk : g.advance c k = .ok (some g'))
    (he : g.advance c n = .error x) {a a' : Access} (ha : .access a ∈ g.pending c n)
    (ha' : .access a' ∈ g.pending c k) (hx : a.atomic.isSome) (hx' : a'.atomic.isSome)
    (hp : a.ptr = a'.ptr) (hl : a.len = a'.len) : ∃ y, g'.advance c n = .error y := by
  obtain ⟨t, ht, hs⟩ := Grid.advance_error he
  obtain ⟨_, sp', x', al', tk, -, -, -, hK⟩ := Grid.advance_atomic hg hk ha' hx'
  have hsh : g.mem.SameShape g.mem.Known g'.mem :=
    (Grid.advance_keeps hk).sameShape fun _ hb hn => hb.below hn
  obtain ⟨mk, hmk, kk⟩ := Except.bind_eq_ok.1 ((hK g rfl fun _ _ => rfl).symm.trans hk)
  cases kk
  rw [← hp, ← hl] at hmk
  cases hr : step (c n) t mk with
  | error y =>
    refine ⟨y, ?_⟩
    unfold Grid.advance
    simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne hnk.symm, ht, hr,
      bind, Except.bind]
  | ok r =>
    exfalso
    have hS := hg.scope ht fun _ => id
    have hS' : ∀ f, t.frames.head? = some f → ((c n).scope mk f t.k).NamesIn g.mem.Known :=
      fun f hf => ⟨(hS f hf).null, (hS f hf).regs, (hS f hf).globals⟩
    have han : .access a ∈ t.pending (c n) mk := by
      rw [Thread.pending_shape hsh hS]
      simpa only [Grid.pending, ht] using ha
    obtain ⟨_, sp, xn, al, _, -, h0, hsx, hN⟩ := step_atomic hS' han hx hr
    obtain ⟨m₂, hm₂, -⟩ := Except.bind_eq_ok.1 ((hN mk fun _ _ => rfl).symm.trans hr)
    obtain ⟨m', hm'⟩ := Mem.update_before (by omega) hsx hmk hm₂
    have e := hN g.mem fun b hb => (hsh b hb).symm
    rw [hs, hm'] at e
    cases e

/-- **`bad_step` for a fault of a thread's step.** For every launch, contexts and closed grid `g`
whose threads own their allocas, and in whose contexts every thread other than `n` has a thread
number other than `n`'s: if thread `n`'s step faults and `g` steps, the grid after faults or has
a race enabled. The
stepping thread `k` is not `n`, whose step faults. If a write of `k`'s overlaps an access of
`n`'s and the two conflict, a race is enabled (`Grid.advance_raceEnabled`). If they do not
conflict, they are by `atomicrmw`s at one pointer and size, and `n`'s step still faults
(`Grid.advance_fault_atomic`). If no write of `k`'s overlaps an access of `n`'s, `n`'s step still
faults (`Grid.advance_fault`); after a collective call it faults too
(`Grid.advance_fault_fire`). -/
theorem Grid.Step.advance_fault {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat} {x : Fault}
    (hg : g.Closed c) (ho : g.Owns c) (hw : ∀ k, k ≠ n → (c n).who.thread ≠ (c k).who.thread)
    (hs : Grid.Step L c g g') (he : g.advance c n = .error x) :
    g'.Faults L c ∨ g'.RaceEnabled c := by
  obtain ⟨k, hk | hk⟩ := hs
  · have hkn : k ≠ n := by
      rintro rfl
      rw [he] at hk
      cases hk
    by_cases hx : ∃ a a', .access a ∈ g.pending c n ∧ .access a' ∈ g.pending c k ∧
        a.overlaps a' = true ∧ a'.write = true
    · obtain ⟨a, a', ha, ha', hov, hwr⟩ := hx
      cases hc : a.conflict a'
      · have hex : a.atomic.isSome ∧ a.atomic = a'.atomic ∧ a.ptr = a'.ptr ∧ a.len = a'.len := by
          simpa [Access.conflict, hov, hwr, and_assoc] using hc
        obtain ⟨y, hy⟩ := Grid.advance_fault_atomic hg (Ne.symm hkn) hk he ha ha' hex.1
          (hex.2.1 ▸ hex.1) hex.2.2.1 hex.2.2.2
        exact .inl ⟨n, y, .inl hy⟩
      obtain ⟨t, ht, -⟩ := Grid.advance_error he
      exact .inr (Grid.advance_raceEnabled hg (hw k hkn) ht hk ha ha' hc)
    · simp only [not_exists, not_and, Bool.not_eq_true] at hx
      obtain ⟨y, hy⟩ := Grid.advance_fault hg ho (hw k hkn) hx hk he
      exact .inl ⟨n, y, .inl hy⟩
  · exact .inl ⟨n, x, .inl (Grid.advance_fault_fire hk he)⟩

/-! ## Faults at a collective call -/

/-- Where one `mapM` throws and another over the same list succeeds, the two functions differ at
a member where the first throws. -/
theorem mapM_error {α β ε : Type} {f g : α → Except ε β} :
    ∀ {xs : List α} {e : ε} {ys : List β}, xs.mapM f = .error e → xs.mapM g = .ok ys →
      ∃ x ∈ xs, ∃ e, f x = .error e ∧ ∃ y, g x = .ok y
  | [], _, _, h, _ => by cases h
  | x :: xs, e, ys, h, h' => by
    simp only [List.mapM_cons, bind, Except.bind, pure, Except.pure] at h h'
    cases hgx : g x with
    | error => simp only [hgx] at h'; cases h'
    | ok y =>
      cases hx : f x with
      | error e₀ => exact ⟨x, List.mem_cons_self, e₀, hx, y, hgx⟩
      | ok =>
        simp only [hx] at h
        simp only [hgx] at h'
        cases hxs : xs.mapM f with
        | error e₂ =>
          cases hgs : xs.mapM g with
          | error => simp only [hgs] at h'; cases h'
          | ok =>
            obtain ⟨z, hz, e', hze, w, hzw⟩ := mapM_error hxs hgs
            exact ⟨z, List.mem_cons_of_mem _ hz, e', hze, w, hzw⟩
        | ok => simp only [hxs] at h; cases h

/-- `resumeAll` commutes with a `set!` at a number it does not resume. -/
theorem resumeAll_set_eq {l : Layout} {m : Mem} {k : Nat} {s : Status} {v : Nat → Option Val} :
    ∀ {ns : List Nat} {ts : Array Status}, k ∉ ns →
      resumeAll l m (ts.set! k s) ns v = (resumeAll l m ts ns v).map (·.set! k s)
  | [], ts, _ => rfl
  | j :: ns, ts, hk => by
    have hjk : k ≠ j := fun e => hk (e ▸ List.mem_cons_self)
    have hk' : k ∉ ns := fun e => hk (List.mem_cons_of_mem _ e)
    unfold resumeAll
    simp only [List.foldlM_cons]
    rw [Array.set!_eq_setIfInBounds (xs := ts), Array.getElem?_setIfInBounds_ne hjk]
    split
    · rename_i t _ _ fn _
      simp only [bind, Except.bind, pure, Except.pure]
      cases (v j).mapM (withAttrs l m fn.ret fn.retAttrs) with
      | error => rfl
      | ok r =>
        simp only [Array.set!_eq_setIfInBounds]
        rw [Array.setIfInBounds_comm _ _ hjk]
        exact resumeAll_set_eq hk'
    · simp only [pure, Except.pure, bind, Except.bind]
      exact resumeAll_set_eq hk'

/-- `resumeAll` gives the same in two memories of the same shape (`Mem.SameShape`) at the blocks
its results name. -/
theorem resumeAll_shape {S : Nat → Prop} {l : Layout} {m m' : Mem} (h : m.SameShape S m')
    {v : Nat → Option Val} :
    ∀ {ns : List Nat} (ts : Array Status), (∀ p ∈ ns, ∀ x, v p = some x → x.NamesIn S) →
      resumeAll l m ts ns v = resumeAll l m' ts ns v
  | [], _, _ => rfl
  | j :: ns, ts, hv => by
    unfold resumeAll
    simp only [List.foldlM_cons]
    split
    · rw [Option.mapM_withAttrs_shape h (hv j List.mem_cons_self)]
      simp only [bind, Except.bind, pure, Except.pure]
      split
      · rfl
      · exact resumeAll_shape h _ fun p hp => hv p (List.mem_cons_of_mem _ hp)
    · simp only [pure, Except.pure, bind, Except.bind]
      exact resumeAll_shape h _ fun p hp => hv p (List.mem_cons_of_mem _ hp)

/-- `resumeAll` with no results succeeds. -/
theorem resumeAll_none {l : Layout} {m : Mem} :
    ∀ {ns : List Nat} (ts : Array Status), ∃ ts', resumeAll l m ts ns (fun _ => none) = .ok ts'
  | [], ts => ⟨ts, rfl⟩
  | j :: ns, ts => by
    unfold resumeAll
    simp only [List.foldlM_cons]
    split
    · simp only [Option.mapM_none, bind, Except.bind, pure, Except.pure]
      exact resumeAll_none (l := l) (m := m) _
    · exact resumeAll_none (l := l) (m := m) _

/-- **A fault at a collective call persists after a thread's step.** For every launch, contexts
and closed grid: if thread `n`'s collective call faults and thread `k` takes a step, `n`'s call
faults after it. `k` runs, so it is none of the participants that make the `mapM` throw
(`mapM_error`), and none that `resumeAll` resumes; the step keeps the shape of every known block
(`Mem.Keeps.sameShape`), which is all `withAttrs` reads of the results, whose blocks are known
(`Grid.Closed`). -/
theorem Grid.fire_error_advance {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n k : Nat}
    {e : Fault} (hg : g.Closed c) (hk : g.advance c k = .ok (some g'))
    (he : g.fire L c n = .error e) : ∃ e', g'.fire L c n = .error e' := by
  have hkeep := Grid.advance_keeps hk
  obtain ⟨tk, s, mk, htk, rfl, -, -⟩ := Grid.advance_set hk
  have hsh : g.mem.SameShape g.mem.Known mk :=
    hkeep.sameShape fun b hb hn => hb.resolve_right (by simp [hn])
  have hn' : ∃ t i args fn, g.threads[n]? = some (.wait t i args fn) := by
    unfold Grid.fire at he
    split at he
    · exact ⟨_, _, _, _, ‹_›⟩
    · cases he
  obtain ⟨t, i, args, fn, hn⟩ := hn'
  have hkn : k ≠ n := by
    rintro rfl
    rw [htk] at hn
    cases hn
  have hset : ∀ p, p ≠ k → (g.threads.set! k s)[p]? = g.threads[p]? := fun p hp => by
    simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne (Ne.symm hp)]
  cases hg' : Grid.fire L c { threads := g.threads.set! k s, mem := mk } n with
  | error e' => exact ⟨e', rfl⟩
  | ok x =>
    exfalso
    unfold Grid.fire at he hg'
    simp only [hn] at he
    simp only [hset n (Ne.symm hkn), hn] at hg'
    split at hg'
    · rename_i x
      cases hx : x.word? with
      | none => simp only [hx] at he hg'; cases hg'
      | some bar =>
        simp only [hx] at he hg'
        by_cases h16 : bar < 16
        · simp only [h16, ↓reduceIte, bind, Except.bind, pure, Except.pure] at he hg'
          split at hg'
          · cases hg'
          · rename_i states' hst'
            split at he
            · obtain ⟨p, hp, e₀, hpe, y, hpy⟩ := mapM_error ‹_› hst'
              by_cases hpk : p = k
              · subst hpk
                simp only [htk] at hpe
                cases hpe
              · simp only [hset p hpk] at hpy
                rw [hpy] at hpe
                cases hpe
            · rename_i states hst
              have hkg : k ∉ (List.range (volume L.block)).map
                  (n / volume L.block * volume L.block + ·) := fun hkg => by
                obtain ⟨y, hy, hys⟩ := mapM_ok_mem hst hkg
                simp only [htk] at hy
                cases hy
                split at he
                · rename_i hall
                  exact absurd (List.all_eq_true.1 hall _ hys) (by decide)
                · cases he
              have e2 : (Except.ok states' : Except Fault (List Bool)) = .ok states := by
                rw [← hst', ← hst]
                exact mapM_congr fun p hp => by
                  simp only [hset p (fun e => hkg (e ▸ hp))]
              cases e2
              split at he
              · rename_i hall
                simp only [hall, ↓reduceIte] at hg'
                rw [resumeAll_set_eq hkg, ← resumeAll_shape hsh _ (fun _ _ _ h => by cases h)]
                  at hg'
                cases hr : resumeAll (c n).prog.layout g.mem g.threads
                    ((List.range (volume L.block)).map (n / volume L.block * volume L.block + ·))
                    (fun _ => none) with
                | error => simp only [hr] at hg'; cases hg'
                | ok => simp only [hr] at he; cases he
              · cases he
        · simp only [h16, ↓reduceIte] at hg'
          cases hg'
    · rename_i mode msk a b c'
      cases hmk : msk.word? with
      | none => simp only [hmk] at he hg'; cases hg'
      | some mask =>
        simp only [hmk] at he hg'
        by_cases h32 : mask = 2 ^ 32 - 1
        · simp only [h32, ↓reduceIte, bind, Except.bind, pure, Except.pure] at he hg'
          split at hg'
          · cases hg'
          · rename_i parts' hparts'
            split at he
            · obtain ⟨j, hj, e₀, hje, y, hjy⟩ := mapM_error ‹_› hparts'
              by_cases hjk : n - n % volume L.block % 32 + j = k
              · rw [hjk] at hje
                simp only [htk] at hje
                cases hje
              · simp only [hset _ hjk] at hjy
                rw [hjy] at hje
                cases hje
            · rename_i parts hparts
              split at he
              · rename_i ps hps
                have hkl : ∀ j ∈ (List.range 32).filter (fun j => decide
                    (n % volume L.block - n % volume L.block % 32 + j < volume L.block)),
                    n - n % volume L.block % 32 + j ≠ k := fun j hj e => by
                  obtain ⟨o, ho, hop⟩ := mapM_ok_mem hparts hj
                  rw [e] at ho
                  simp only [htk] at ho
                  cases ho
                  obtain ⟨y, hy, -⟩ := mapM_id_mem hop hps
                  cases hy
                have e2 : (Except.ok parts' : Except Fault _) = .ok parts := by
                  rw [← hparts', ← hparts]
                  exact mapM_congr fun j hj => by simp only [hset _ (hkl j hj)]
                cases e2
                simp only [hps] at hg'
                have hPl : ∀ y ∈ ps, y.1 ∈ (List.range 32).filter (fun j => decide
                    (n % volume L.block - n % volume L.block % 32 + j < volume L.block)) ∧
                    y.2.1.NamesIn g.mem.Known := by
                  refine mapM_mem_option hps (fun o ho y hy => mapM_mem
                    (P := fun o => ∀ y, o = some y → y.1 ∈ (List.range 32).filter (fun j =>
                      decide (n % volume L.block - n % volume L.block % 32 + j <
                        volume L.block)) ∧ y.2.1.NamesIn g.mem.Known)
                    hparts (fun j hj o' ho' y' hy' => ?_) o ho y hy)
                  subst hy'
                  repeat' split at ho'
                  all_goals cases ho'
                  have hs := hg.threads _ _ ‹g.threads[_]? = some _›
                  simp only [Status.NamesIn] at hs
                  exact ⟨hj, hs.2 _ (by simp)⟩
                have hkP : k ∉ ps.map (n - n % volume L.block % 32 + ·.1) := fun h => by
                  obtain ⟨y, hy, e⟩ := List.mem_map.1 h
                  exact hkl _ (hPl y hy).1 e
                rw [resumeAll_set_eq hkP, ← resumeAll_shape hsh _ (fun p _ x hx => ?_)] at hg'
                · split at he
                  · rename_i hr
                    simp only [hr] at hg'
                    cases hg'
                  · cases he
                · obtain ⟨y, -, rfl⟩ := Option.map_eq_some_iff.1 hx
                  cases hf : ps.find? (·.1 = shflSource mode y.1 y.2.2.1 y.2.2.2) with
                  | none => simp only [Option.map_none, Option.getD_none]; trivial
                  | some z =>
                    simp only [Option.map_some, Option.getD_some]
                    exact (hPl z (List.mem_of_find?_eq_some hf)).2
              · cases he
        · simp only [h32, ↓reduceIte] at hg'
          cases hg'
    all_goals cases hg'

/-- **A lane's collective call completes `n`'s.** In contexts with one layout: if the call of a
lane of thread `n`'s warp inside its block of threads completes, `n`'s completes to the same grid:
at a barrier `n` is of the lane's block of threads, at a shuffle of its warp. -/
theorem Grid.fire_lane {L : Launch} {c : Nat → Ctx} {g g₂ : Grid} {n q : Nat}
    (hl : ∀ p, (c p).prog.layout = (c n).prog.layout)
    (hq : q ∈ (List.range 32).filter (fun q => decide
      (n % volume L.block - n % volume L.block % 32 + q < volume L.block)))
    (hp : g.fire L c (n - n % volume L.block % 32 + q) = .ok (some g₂)) :
    g.fire L c n = .ok (some g₂) := by
  obtain ⟨p, hpq⟩ : ∃ p, p = n - n % volume L.block % 32 + q := ⟨_, rfl⟩
  rw [← hpq] at hp
  obtain ⟨P, -, -, -, -, -, hPe, -, hPl⟩ := Grid.fire_frame hp
  simp only [List.mem_filter, List.mem_range, decide_eq_true_eq] at hq
  have e0 : n % volume L.block % 32 ≤ n % volume L.block := Nat.mod_le _ _
  have e1 := Nat.div_add_mod' n (volume L.block)
  have hmod : p % volume L.block = n % volume L.block - n % volume L.block % 32 + q := by
    rw [hpq, show n - n % volume L.block % 32 + q =
        (n % volume L.block - n % volume L.block % 32 + q) +
          n / volume L.block * volume L.block by omega,
      Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hq.2]
  have k1 : p - p % volume L.block % 32 = n - n % volume L.block % 32 := by
    rw [hmod]
    omega
  have k2 : p % volume L.block - p % volume L.block % 32 =
      n % volume L.block - n % volume L.block % 32 := by
    rw [hmod]
    omega
  have hlt := Nat.mod_lt n (show 0 < volume L.block by omega)
  have hn := hPl (n % volume L.block % 32) (List.mem_filter.2 ⟨List.mem_range.2
    (Nat.mod_lt _ (by omega)), by rw [k2]; simp only [decide_eq_true_eq]; omega⟩)
  rw [k1, show n - n % volume L.block % 32 + n % volume L.block % 32 = n by omega] at hn
  exact hPe n hn c ((hl n).trans (hl p).symm)

/-- **A fault at a collective call persists after another collective call.** For every launch,
grid and contexts with one layout: if thread `n`'s collective call faults and thread `j`'s
completes, `n`'s call faults after it. `n` is none of the threads `j`'s call resumes
(`Grid.fire_frame`), which would complete `n`'s; none of them is a lane of `n`'s warp
(`Grid.fire_lane`) or waits at a barrier of `n`'s block of threads (its call would be `n`'s
block's), so `n`'s participants have the same statuses for its `mapM`, and the call only puts a
barrier in front of the trace. A barrier's `resumeAll` has no results and cannot fault
(`resumeAll_none`). -/
theorem Grid.fire_error_fire {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n j : Nat} {e : Fault}
    (hl : ∀ p, (c p).prog.layout = (c n).prog.layout)
    (hj : g.fire L c j = .ok (some g')) (he : g.fire L c n = .error e) :
    ∃ e', g'.fire L c n = .error e' := by
  obtain ⟨P, v, hPw, -, hPr, hPm, hPe, -⟩ := Grid.fire_frame hj
  have hfire : ∀ p ∈ P, g.fire L c p = .ok (some g') := fun p hp =>
    hPe p hp c ((hl p).trans (hl j).symm)
  have hnP : n ∉ P := fun hp => by
    rw [hfire n hp] at he
    cases he
  have hset : ∀ p, p ∉ P → g'.threads[p]? = g.threads[p]? := fun p hp =>
    resumeAll_getElem? hPr hp
  have hkeep : g'.mem.Keeps g.mem := by
    rw [hPm]
    exact ⟨fun b x hx => by change g.mem.blocks b = some x at hx; simp [hx], rfl, fun _ _ h => h⟩
  have hn' : ∃ t i args fn, g.threads[n]? = some (.wait t i args fn) := by
    unfold Grid.fire at he
    split at he
    · exact ⟨_, _, _, _, ‹_›⟩
    · cases he
  obtain ⟨t, i, args, fn, hn⟩ := hn'
  have hbar : ∀ p ∈ P, p ∈ (List.range (volume L.block)).map
      (n / volume L.block * volume L.block + ·) →
      ∀ t' a fn', g.threads[p]? ≠ some (.wait t' .barrier a fn') := fun p hp hpg t' a fn' hw => by
    obtain ⟨Q, -, -, hQb, -, -, hQe, -⟩ := Grid.fire_frame (hfire p hp)
    obtain ⟨q, hq, rfl⟩ := List.mem_map.1 hpg
    rw [List.mem_range] at hq
    have hdiv : (n / volume L.block * volume L.block + q) / volume L.block =
        n / volume L.block := by
      rw [Nat.add_comm, Nat.add_mul_div_right _ _ (by omega), Nat.div_eq_of_lt hq, Nat.zero_add]
    have hnQ : n ∈ Q := by
      rw [hQb (by simp [Grid.fired, hw])]
      refine List.mem_map.2 ⟨n % volume L.block, List.mem_range.2 (Nat.mod_lt _ (by omega)), ?_⟩
      rw [hdiv]
      exact Nat.div_add_mod' n _
    rw [hQe n hnQ c ((hl n).trans (hl _).symm)] at he
    cases he
  have hQ0 : ∀ p s, g.threads[p]? = some s → p ∈ P → p ∈ (List.range (volume L.block)).map
      (n / volume L.block * volume L.block + ·) →
      (∀ t' a fn', s ≠ .wait t' .barrier a fn') ∧ s ≠ .done := fun p s hs hp hpg => by
    obtain ⟨t', i', a', fn', hw⟩ := hPw p hp
    rw [hw] at hs
    cases hs
    exact ⟨fun t'' a fn'' h => hbar p hp hpg t'' a fn'' (by rw [hw, h]), fun h => by cases h⟩
  have hQ := resumeAll_inv (P := fun p s => p ∈ P → p ∈ (List.range (volume L.block)).map
      (n / volume L.block * volume L.block + ·) →
      (∀ t' a fn', s ≠ .wait t' .barrier a fn') ∧ s ≠ .done) hPr
    (fun _ _ _ _ _ _ _ _ _ _ => ⟨fun _ _ _ h => (by cases h), fun h => by cases h⟩) hQ0
  have hlP : ∀ q ∈ (List.range 32).filter (fun q => decide
      (n % volume L.block - n % volume L.block % 32 + q < volume L.block)),
      n - n % volume L.block % 32 + q ∉ P := fun q hq hp => by
    rw [Grid.fire_lane hl hq (hfire _ hp)] at he
    cases he
  cases hg' : g'.fire L c n with
  | error e' => exact ⟨e', rfl⟩
  | ok x =>
    exfalso
    unfold Grid.fire at he hg'
    simp only [hn] at he
    simp only [hset n hnP, hn] at hg'
    split at hg'
    · rename_i x
      cases hx : x.word? with
      | none => simp only [hx] at he hg'; cases hg'
      | some bar =>
        simp only [hx] at he hg'
        by_cases h16 : bar < 16
        · simp only [h16, ↓reduceIte, bind, Except.bind, pure, Except.pure] at he hg'
          split at hg'
          · cases hg'
          · rename_i states' hst'
            split at he
            · rename_i e₀ hst
              have e2 : (Except.ok states' : Except Fault (List Bool)) = .error e₀ := by
                rw [← hst', ← hst]
                refine mapM_congr fun p hp => ?_
                by_cases hpP : p ∈ P
                · split <;> split
                  all_goals first
                    | exact ((hQ _ _ ‹g'.threads[p]? = some _› hpP hp).1 _ _ _ rfl).elim
                    | exact ((hQ _ _ ‹g'.threads[p]? = some _› hpP hp).2 rfl).elim
                    | exact ((hQ0 _ _ ‹g.threads[p]? = some _› hpP hp).1 _ _ _ rfl).elim
                    | exact ((hQ0 _ _ ‹g.threads[p]? = some _› hpP hp).2 rfl).elim
                    | rfl
                · simp only [hset p hpP]
              cases e2
            · rename_i states hst
              have e2 : (Except.ok states' : Except Fault (List Bool)) = .ok states := by
                rw [← hst', ← hst]
                refine mapM_congr fun p hp => ?_
                by_cases hpP : p ∈ P
                · split <;> split
                  all_goals first
                    | exact ((hQ _ _ ‹g'.threads[p]? = some _› hpP hp).1 _ _ _ rfl).elim
                    | exact ((hQ _ _ ‹g'.threads[p]? = some _› hpP hp).2 rfl).elim
                    | exact ((hQ0 _ _ ‹g.threads[p]? = some _› hpP hp).1 _ _ _ rfl).elim
                    | exact ((hQ0 _ _ ‹g.threads[p]? = some _› hpP hp).2 rfl).elim
                    | rfl
                · simp only [hset p hpP]
              cases e2
              split at he
              · obtain ⟨ts, hts⟩ := resumeAll_none (l := (c n).prog.layout) (m := g.mem)
                  (ns := (List.range (volume L.block)).map
                    (n / volume L.block * volume L.block + ·)) g.threads
                simp only [hts] at he
                cases he
              · cases he
        · simp only [h16, ↓reduceIte] at hg'
          cases hg'
    · rename_i mode msk a b c'
      cases hmk : msk.word? with
      | none => simp only [hmk] at he hg'; cases hg'
      | some mask =>
        simp only [hmk] at he hg'
        by_cases h32 : mask = 2 ^ 32 - 1
        · simp only [h32, ↓reduceIte, bind, Except.bind, pure, Except.pure] at he hg'
          split at hg'
          · cases hg'
          · rename_i parts' hparts'
            split at he
            · rename_i e₀ hparts
              have e2 : (Except.ok parts' : Except Fault _) = .error e₀ := by
                rw [← hparts', ← hparts]
                exact mapM_congr fun q hq => by simp only [hset _ (hlP q hq)]
              cases e2
            · rename_i parts hparts
              have e2 : (Except.ok parts' : Except Fault _) = .ok parts := by
                rw [← hparts', ← hparts]
                exact mapM_congr fun q hq => by simp only [hset _ (hlP q hq)]
              cases e2
              split at he
              · rename_i ps hps
                simp only [hps] at hg'
                have hPl : ∀ y ∈ ps, y.1 ∈ (List.range 32).filter (fun j => decide
                    (n % volume L.block - n % volume L.block % 32 + j < volume L.block)) := by
                  refine mapM_mem_option (P := fun p => p.1 ∈ (List.range 32).filter (fun j =>
                      decide (n % volume L.block - n % volume L.block % 32 + j <
                        volume L.block))) hps
                    (fun o ho y hy => mapM_mem (P := fun o => ∀ y, o = some y → y.1 ∈
                      (List.range 32).filter (fun j => decide
                        (n % volume L.block - n % volume L.block % 32 + j < volume L.block)))
                      hparts (fun j hj o' ho' y' hy' => ?_) o ho y hy)
                  subst hy'
                  repeat' split at ho'
                  all_goals cases ho'
                  exact hj
                split at hg'
                · cases hg'
                · rename_i ts' hts'
                  obtain ⟨ts, hts, -⟩ := resumeAll_agree hkeep (fun p hp => by
                    obtain ⟨y, hy, rfl⟩ := List.mem_map.1 hp
                    exact (hset _ (hlP _ (hPl y hy))).symm) hts'
                  simp only [hts] at he
                  cases he
              · cases he
        · simp only [h32, ↓reduceIte] at hg'
          cases hg'
    all_goals cases hg'

/-- **`bad_step`.** For every launch, contexts with one layout (`hl`) and closed grid `g` whose
threads own their allocas, have different thread numbers in their contexts and are such that no
collective call that completes logs a barrier of a running thread's block of threads: if `g` is
bad, the grid after a step is bad. `Grid.Step.advance_fault` for a fault of a thread's step,
`Grid.fire_error_advance` and `Grid.fire_error_fire` for a fault at a collective call,
`Grid.Step.bad_trace` for the rest. `hl` is needed (twin MojoProofTest/Bad.lean
`fire_fault_twin`). -/
theorem Grid.Step.bad {L : Launch} {c : Nat → Ctx} {g g' : Grid} (hg : g.Closed c) (ho : g.Owns c)
    (hd : ∀ n k, n ≠ k → (c n).who.thread ≠ (c k).who.thread)
    (hw : ∀ n k t gf, g.threads[n]? = some (.run t) → g.fire L c k = .ok (some gf) →
      .barrier (c n).who.cta ∉ g.fired L k)
    (hl : ∀ n p, (c n).prog.layout = (c p).prog.layout)
    (hs : Grid.Step L c g g') (hb : g.Bad L c) : g'.Bad L c := by
  rcases hb with ⟨n, e, he | he⟩ | hb
  · exact (hs.advance_fault hg ho (fun k hk => hd n k (Ne.symm hk)) he).elim .inl
      fun h => .inr (.inr (.inr h))
  · obtain ⟨k, hk | hk⟩ := hs
    · obtain ⟨e', he'⟩ := Grid.fire_error_advance hg hk he
      exact .inl ⟨n, e', .inr he'⟩
    · obtain ⟨e', he'⟩ := Grid.fire_error_fire (hl · n) hk he
      exact .inl ⟨n, e', .inr he'⟩
  · exact .inr (hs.bad_trace hg hw hb)

/-- **`bad_step` from the start.** For every program, kernel, launch, arguments, address choice
and oracle, on a caller's memory every pointer byte of whose blocks names a number below `next` or
with a block, in every grid reachable from the start's: `Grid.Step.bad`, whose contexts have one
program and so one layout and give thread `n` the number `n` (`Grid.start_ctx`), whose grid is
closed (`Grid.start_reach_closed`), has its threads own their allocas (`Grid.start_owns`,
`Grid.reach_owns`) and has no collective call that completes log a barrier of a running thread's
block of threads (`Grid.start_reach_fired`). -/
theorem Grid.start_reach_bad {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g) (hs : Grid.Step L c g g') (hb : g.Bad L c) :
    g'.Bad L c :=
  hs.bad (Grid.start_reach_closed h hm hr) (Grid.reach_owns hr (Grid.start_owns h c))
    (fun n k hnk => by rw [(Grid.start_ctx h n).2, (Grid.start_ctx h k).2]; exact hnk)
    (fun _ _ _ _ hn hf => Grid.start_reach_fired h hr hn hf)
    (fun n p => by rw [(Grid.start_ctx h n).1, (Grid.start_ctx h p).1]) hb

end MojoProof.Sem
