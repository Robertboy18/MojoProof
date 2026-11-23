import MojoProof.Sym.Block
import MojoProof.Sem.Spec
import MojoProof.Sem.OneRun
import MojoProof.Sem.Determinism

/-!
# Sequential schedules: one thread's run in a grid, and threads run in turn

Every result here is for every program, launch and contexts.

* `Steps.grid`: steps that continue a thread (`Steps`, MojoProof/Sym/Block.lean), when thread `n`
  of a grid runs that thread on the grid's memory, are a run of grid steps (`Grid.Step`) to the
  grid with only thread `n`'s status (running the thread after the steps) and the memory changed.
* `Runs`: a thread's run to its end, steps that continue it and then a step that returns
  (`.done`). `Runs.grid`: such a run by thread `n` is a run of grid steps to the grid with thread
  `n` done and the memory the return leaves, every other thread unchanged. `Steps.trace` and
  `Runs.trace`: the steps and the run put events in front of the trace.
* `Turns R`: threads `ns` in turn, each by the relation `R n` from the memory the one before it
  left, with the events each puts in front of the trace. `Turns.grid`: when each thread's turn is
  a run of grid steps setting its status to `s n` (`foldl_set_getElem?`, `foldl_set_size`), the
  turns are a run of grid steps to the grid with each of the distinct threads `ns` at `s n`.
  `Turns.trace`, and `Turns.of_inv`: threads `0` to `N - 1` in turn by an invariant.
* `Seq`: threads `ns` run in turn, each alone to its end from the memory the one before it left,
  with the events each puts in front of the trace. `Seq.grid`: from a grid in which each of the
  distinct threads `ns` runs its thread and whose memory is the first, the runs in turn are a run
  of grid steps to the grid with threads `ns` done, every other thread unchanged, and the last
  memory. `Seq.trace`: that memory's trace is the threads' events (the last thread's in front) in
  front of the first memory's. `Seq.done`: when `ns` names every thread of the grid, the run ends
  in a grid that is done (`Grid.Done`, `Grid.done_foldl`).
* `Seq.start_sound`: from the grid `Grid.start` gives, threads run in turn to a done grid that is
  not bad make the start's grid sound (`Grid.Sound`, by `Grid.start_sound`); the premise that the
  done grid is not bad is the caller's.
* `Seq.of_inv`: threads `0` to `N - 1`, each of which takes a memory of an invariant `P k` to one
  of `P (k + 1)` by its run to its end, run in turn from `P 0` to `P N`. `Seq.start_sound_inv`:
  the start's grid is sound when its memory is of `P 0`, each of its threads (`Grid.thread`)
  keeps the invariant that way, and every memory of `P N` has a trace with no data race that
  keeps the promise of `!invariant.load` and an observation meeting `R`; the per-thread premise
  is about one thread on every memory of `P k`, not about a schedule, and the trace premise is
  about the memory only.
  On a launch whose grid and block have side 1 in `y` and `z`, thread `k` of `Seq.of_inv` is
  the thread of index `k` (`Launch.index_oneDim`, MojoProof/Sem/Index.lean).

`Seq` is `Turns` of `Runs`; `Seq.grid`, `Seq.trace` and `Seq.of_inv` are
`Turns.grid`, `Turns.trace` and `Turns.of_inv` at it. No collective call is involved in `Seq`:
every grid step is a thread's step (`Grid.advance`), and no thread waits, since `Steps` continues
the thread and `Runs` ends in `.done`. `Turns` is not tied to `Runs`: MojoProof/Sym/SchedWait.lean
uses it with runs to a wait.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- An array whose entry `n` is `a` is unchanged by setting entry `n` to `a`. -/
theorem Array.set!_of_getElem? {α : Type} {xs : Array α} {n : Nat} {a : α} (h : xs[n]? = some a) :
    xs.set! n a = xs := by
  apply Array.ext_getElem?
  intro j
  rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
  split
  · subst j
    simp only [(Array.getElem?_eq_some_iff.1 h).1, ↓reduceIte, h]
  · rfl

/-- The statuses after `ns` are set, each `n` to `s n`: entry `j` is `s j` if `j` is one of `ns`
and in range, as before otherwise. -/
theorem foldl_set_getElem? (s : Nat → Status) (ns : List Nat) :
    ∀ (ts : Array Status) (j : Nat), (ns.foldl (fun ts n => ts.set! n (s n)) ts)[j]? =
      if j ∈ ns then ts[j]?.map fun _ => s j else ts[j]? := by
  induction ns with
  | nil => intro ts j; simp
  | cons n ns ih =>
    intro ts j
    rw [List.foldl_cons, ih, Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
    by_cases hj : j = n
    · subst j
      by_cases hl : n < ts.size
      · simp [hl]
      · simp [hl]
    · simp [hj, Ne.symm hj]

/-- Setting entries keeps the number of statuses. -/
theorem foldl_set_size (s : Nat → Status) (ns : List Nat) :
    ∀ ts : Array Status, (ns.foldl (fun ts n => ts.set! n (s n)) ts).size = ts.size := by
  induction ns with
  | nil => intro ts; rfl
  | cons n ns ih => intro ts; rw [List.foldl_cons, ih, Array.size_set!]

/-- Entry `j` of an array after setting the entries `ns` to `.done`: `.done` if `j` is one of
`ns` and in range, as before otherwise (`foldl_set_getElem?`). -/
theorem foldl_done_getElem? (ns : List Nat) :
    ∀ (ts : Array Status) (j : Nat), (ns.foldl (fun ts n => ts.set! n .done) ts)[j]? =
      if j ∈ ns then ts[j]?.map fun _ => .done else ts[j]? :=
  foldl_set_getElem? (fun _ => .done) ns

/-- **A thread's steps in a grid.** For every launch `L`, contexts `c` and grid `g` whose thread
`n` runs `t` on `g`'s memory `m`: steps of `t` that continue it, to `t'` on `m'`, are a run of
grid steps from `g` to the grid with thread `n` running `t'`, every other thread unchanged, and
memory `m'`. -/
theorem Steps.grid {L : Launch} {c : Nat → Ctx} {n : Nat} {t t' : Thread} {m m' : Mem}
    (h : Steps (c n) t m t' m') :
    ∀ {g : Grid}, g.threads[n]? = some (.run t) → g.mem = m →
      ∃ k, Path (Grid.Step L c) k g ⟨g.threads.set! n (.run t'), m'⟩ := by
  induction h with
  | refl t m =>
    intro g hg hm
    obtain ⟨ts, mg⟩ := g
    subst hm
    refine ⟨0, ?_⟩
    rw [Array.set!_of_getElem? hg]
    exact .nil _
  | @cons t t₁ t'' m m₁ m'' hs _ ih =>
    intro g hg hm
    have hn : n < g.threads.size := (Array.getElem?_eq_some_iff.1 hg).1
    have ha : g.advance c n = .ok (some ⟨g.threads.set! n (.run t₁), m₁⟩) := by
      unfold Grid.advance
      rw [hg, hm]
      simp only [bind, Except.bind, hs, pure, Except.pure]
    obtain ⟨k, hp⟩ := ih (g := ⟨g.threads.set! n (.run t₁), m₁⟩)
      (by simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_self_of_lt hn])
      rfl
    simp only [Array.set!_eq_setIfInBounds, Array.setIfInBounds_setIfInBounds] at hp
    rw [Array.set!_eq_setIfInBounds]
    exact ⟨k + 1, .cons ⟨n, .inl ha⟩ hp⟩

/-- A run of thread `t` in context `c` to its end, from memory `m`: steps that continue it, then
a step that returns, leaving memory `m'`. -/
def Runs (c : Ctx) (t : Thread) (m m' : Mem) : Prop :=
  ∃ t' m₁, Steps c t m t' m₁ ∧ step c t' m₁ = .ok (.done m')

/-- **A thread's run in a grid.** For every launch `L`, contexts `c` and grid `g` whose thread
`n` runs `t` on `g`'s memory `m`: a run of `t` to its end leaving `m'` is a run of grid steps from
`g` to the grid with thread `n` done, every other thread unchanged, and memory `m'`. -/
theorem Runs.grid {L : Launch} {c : Nat → Ctx} {n : Nat} {t : Thread} {m m' : Mem}
    (h : Runs (c n) t m m') {g : Grid} (hg : g.threads[n]? = some (.run t)) (hm : g.mem = m) :
    ∃ k, Path (Grid.Step L c) k g ⟨g.threads.set! n .done, m'⟩ := by
  obtain ⟨t', m₁, hs, hd⟩ := h
  obtain ⟨k, hp⟩ := Steps.grid (L := L) hs hg hm
  have hn : n < g.threads.size := (Array.getElem?_eq_some_iff.1 hg).1
  have ha : Grid.advance c ⟨g.threads.set! n (.run t'), m₁⟩ n =
      .ok (some ⟨g.threads.set! n .done, m'⟩) := by
    unfold Grid.advance
    simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_self_of_lt hn, bind,
      Except.bind, hd, pure, Except.pure, Array.setIfInBounds_setIfInBounds]
  exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨k, hp⟩).tail ⟨n, .inl ha⟩)

/-- **The events of steps**: for every context, steps that continue a thread put events in front
of the trace (each step its pending accesses, `step_pending`). -/
theorem Steps.trace {c : Ctx} {t t' : Thread} {m m' : Mem} (h : Steps c t m t' m') :
    ∃ E, m'.trace = E ++ m.trace := by
  induction h with
  | refl => exact ⟨[], rfl⟩
  | cons h₁ _ ih =>
    obtain ⟨E, e⟩ := ih
    have e₁ := step_pending h₁
    simp only at e₁
    exact ⟨E ++ _, by rw [e, e₁, List.append_assoc]⟩

/-- **The events of a run**: for every context, a thread's run to its end puts events in front of
the trace (`Steps.trace`, then the return's pending accesses, `step_pending`). -/
theorem Runs.trace {c : Ctx} {t : Thread} {m m' : Mem} (h : Runs c t m m') :
    ∃ E, m'.trace = E ++ m.trace := by
  obtain ⟨t', m₁, hs, hd⟩ := h
  obtain ⟨E, e⟩ := hs.trace
  have e₁ := step_pending hd
  simp only at e₁
  exact ⟨_ ++ E, by rw [e₁, e, List.append_assoc]⟩

/-- Threads `ns` in turn by the runs `R`, where `R n m m'` is a run of thread `n` from memory `m`
leaving `m'`: the first from memory `m`, each next one from the memory the one before left, the
last leaving `m'`. `Es` lists the events each run puts in front of the trace. `Seq` is the case of
runs to the end; `Seq.ToWait` (MojoProof/Sym/SchedWait.lean) the case of runs to
a collective call. -/
inductive Turns (R : Nat → Mem → Mem → Prop) : List Nat → Mem → List (List Event) → Mem → Prop
  /-- No thread. -/
  | nil (m : Mem) : Turns R [] m [] m
  /-- Thread `n` runs from `m` to `m₁`, putting `E` in front of the trace; then the others. -/
  | cons {n : Nat} {ns : List Nat} {m m₁ m₂ : Mem} {E : List Event} {Es : List (List Event)} :
      R n m m₁ → m₁.trace = E ++ m.trace → Turns R ns m₁ Es m₂ → Turns R (n :: ns) m (E :: Es) m₂

/-- **The trace of threads in turn**: for every family of runs, the last memory's trace is the
threads' events, the last thread's in front, in front of the first memory's. -/
theorem Turns.trace {R : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | nil => rfl
  | cons _ e _ ih => simp only [ih, e, List.reverse_cons, List.flatten_append, List.flatten_cons,
      List.flatten_nil, List.append_nil, List.append_assoc]

/-- **Threads in turn, in a grid.** For every launch `L`, contexts `c`, threads `t`, statuses `s`
and family of runs `R` each of which, by thread `n` from memory `m` to `m'`, is a run of grid steps
from every grid whose thread `n` runs `t n` on memory `m` to that grid with thread `n`'s status
set to `s n` and memory `m'`: from a grid `g` in which each of the distinct threads `ns` runs its
thread `t n` and whose memory is `m`, threads `ns` in turn by `R` from `m` to `m'` (`Turns`) are a
run of grid steps from `g` to the grid with each thread `n` of `ns` at `s n`, every other thread
unchanged, and memory `m'`. -/
theorem Turns.grid {L : Launch} {c : Nat → Ctx} {R : Nat → Mem → Mem → Prop} {t : Nat → Thread}
    {s : Nat → Status}
    (hR : ∀ {n : Nat} {m m' : Mem} {g : Grid}, R n m m' → g.threads[n]? = some (.run (t n)) →
      g.mem = m → ∃ k, Path (Grid.Step L c) k g ⟨g.threads.set! n (s n), m'⟩)
    {ns : List Nat} {m m' : Mem} {Es : List (List Event)} (h : Turns R ns m Es m') :
    ∀ {g : Grid}, ns.Nodup → (∀ n ∈ ns, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ k, Path (Grid.Step L c) k g ⟨ns.foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩ := by
  induction h with
  | nil m =>
    intro g _ _ hm
    obtain ⟨ts, mg⟩ := g
    subst hm
    exact ⟨0, .nil _⟩
  | @cons n ns m m₁ m₂ E Es hr _ _ ih =>
    intro g hd hg hm
    obtain ⟨k₁, hp₁⟩ := hR hr (hg n List.mem_cons_self) hm
    have hd' := List.nodup_cons.1 hd
    obtain ⟨k₂, hp₂⟩ := ih (g := ⟨g.threads.set! n (s n), m₁⟩) hd'.2
      (fun j hj => by
        rw [Array.set!_eq_setIfInBounds,
          Array.getElem?_setIfInBounds_ne (fun e => hd'.1 (by subst e; exact hj))]
        exact hg j (List.mem_cons_of_mem n hj))
      rfl
    exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨k₁, hp₁⟩).trans (Path.exists_iff.1 ⟨k₂, hp₂⟩))

/-- **Threads in turn by an invariant.** For every family of runs `R` each of which puts events
in front of the trace, number `N` and family `P` of memory predicates indexed by the number of
threads that have run: if each thread `k < N`, from every memory of `P k`, has a run by `R`
leaving a memory of `P (k + 1)`, then threads `0` to `N - 1` run in turn (`Turns`) from every
memory of `P 0` to a memory of `P N`. -/
theorem Turns.of_inv {R : Nat → Mem → Mem → Prop} {P : Nat → Mem → Prop} {N : Nat}
    (hE : ∀ {n : Nat} {m m' : Mem}, R n m m' → ∃ E, m'.trace = E ++ m.trace)
    (h : ∀ k < N, ∀ m, P k m → ∃ m', R k m m' ∧ P (k + 1) m') {m : Mem}
    (h0 : P 0 m) : ∃ Es m', Turns R (List.range N) m Es m' ∧ P N m' := by
  have go : ∀ r k m, k + r = N → P k m →
      ∃ Es m', Turns R (List.range' k r) m Es m' ∧ P N m' := by
    intro r
    induction r with
    | zero =>
      intro k m hk hm
      obtain rfl : k = N := by omega
      exact ⟨[], m, .nil m, hm⟩
    | succ r ih =>
      intro k m hk hm
      obtain ⟨m₁, hr, hm₁⟩ := h k (by omega) m hm
      obtain ⟨E, e⟩ := hE hr
      obtain ⟨Es, m', hs, hm'⟩ := ih (k + 1) m₁ (by omega) hm₁
      rw [List.range'_succ]
      exact ⟨E :: Es, m', .cons hr e hs, hm'⟩
  rw [List.range_eq_range']
  exact go N 0 m (Nat.zero_add N) h0

/-- Threads `ns` in turn, each in its context `c n` from its thread `t n`, run alone to their
ends: the first from memory `m`, each next one from the memory the one before left, the last
leaving `m'`. `Es` lists the events each run puts in front of the trace (`Runs.trace`). `Turns`
of `Runs`. -/
abbrev Seq (c : Nat → Ctx) (t : Nat → Thread) :
    List Nat → Mem → List (List Event) → Mem → Prop :=
  Turns fun n => Runs (c n) (t n)

/-- **The trace of threads run in turn**: for every contexts and threads, the last memory's trace
is the threads' events, the last thread's in front, in front of the first memory's
(`Turns.trace`). -/
theorem Seq.trace {c : Nat → Ctx} {t : Nat → Thread} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Seq c t ns m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace :=
  Turns.trace h

/-- **Threads run in turn, in a grid.** For every launch `L`, contexts `c`, threads `t` and grid
`g` in which each of the distinct threads `ns` runs its thread `t n` and whose memory is `m`:
threads `ns` run in turn from `m` to `m'` (`Seq`) are a run of grid steps from `g` to the grid
with threads `ns` done, every other thread unchanged, and memory `m'` (`Turns.grid` with
`Runs.grid`). -/
theorem Seq.grid {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Seq c t ns m Es m') :
    ∀ {g : Grid}, ns.Nodup → (∀ n ∈ ns, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ k, Path (Grid.Step L c) k g ⟨ns.foldl (fun ts n => ts.set! n .done) g.threads, m'⟩ :=
  Turns.grid (s := fun _ => .done) (fun hr hg hm => Runs.grid hr hg hm) h

/-- For every array of statuses and memory: setting the entries `ns` to `.done`, when every index
of the array is one of `ns`, leaves a done grid. -/
theorem Grid.done_foldl {ns : List Nat} {ts : Array Status} (m : Mem)
    (hall : ∀ j < ts.size, j ∈ ns) : Grid.Done ⟨ns.foldl (fun ts n => ts.set! n .done) ts, m⟩ := by
  simp only [Grid.Done, Array.all_eq_true]
  intro j hj
  have e := foldl_done_getElem? ns ts j
  have hj' : j < ts.size := by
    have := congrArg Option.isSome e
    simp only [Array.getElem?_eq_getElem hj, Option.isSome_some] at this
    by_contra hn
    rw [Array.getElem?_eq_none_iff.2 (Nat.not_lt.1 hn)] at this
    split at this <;> simp at this
  simp only [Array.getElem?_eq_getElem hj, hall j hj', ↓reduceIte, Array.getElem?_eq_getElem hj',
    Option.map_some, Option.some.injEq] at e
  rw [e]

/-- **Threads run in turn to a done grid.** For every launch `L`, contexts `c`, threads `t` and
grid `g` in which each of the distinct threads `ns` runs its thread `t n`, whose memory is `m`
and every one of whose threads is one of `ns`: threads `ns` run in turn from `m` to `m'` are a run
of grid steps from `g` to a done grid (`Grid.Done`) with memory `m'`, whose trace is the threads'
events in front of `m`'s (`Seq.trace`). -/
theorem Seq.done {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Seq c t ns m Es m') {g : Grid} (hd : ns.Nodup)
    (hg : ∀ n ∈ ns, g.threads[n]? = some (.run (t n))) (hm : g.mem = m)
    (hall : ∀ j < g.threads.size, j ∈ ns) :
    ∃ z, (∃ k, Path (Grid.Step L c) k g z) ∧ z.Done ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ m.trace :=
  ⟨_, Seq.grid h hd hg hm, Grid.done_foldl m' hall, rfl, h.trace⟩

/-- **Threads run in turn from the start, sound.** For every program, kernel `fn`, launch `L`,
arguments, address choice and oracle whose start (`Grid.start`) gives grid `g₀` and contexts `c`,
on a caller's memory `m` every pointer byte of whose blocks names a number below `next` or with a
block (`Mem.BytesIn`), and every observation `obs` that reads only the blocks: if the distinct
threads `ns`, which name every thread of `g₀`, each running its thread `t n` in `g₀`, run in turn
from `g₀`'s memory to `m'` (`Seq`), the done grid this leaves (threads `ns` done, memory `m'`) is
not bad, and `obs m' = some y` with `R y`, then `g₀` is sound (`Grid.Sound`): `Seq.grid`,
`Grid.done_foldl` and `Grid.start_sound`. -/
theorem Seq.start_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {t : Nat → Thread} {ns : List Nat} {Es : List (List Event)} {m' : Mem}
    (hs : Seq c t ns g₀.mem Es m') (hd : ns.Nodup)
    (hg : ∀ n ∈ ns, g₀.threads[n]? = some (.run (t n))) (hall : ∀ j < g₀.threads.size, j ∈ ns)
    (hb : ¬ Grid.Bad L c ⟨ns.foldl (fun ts n => ts.set! n .done) g₀.threads, m'⟩)
    {y : β} (hy : obs m' = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  have ⟨_, hp⟩ := Seq.grid (L := L) hs hd hg rfl
  Grid.start_sound h hm hO hp (Grid.done_foldl m' hall) hb hy hR

/-- Thread `n` of grid `g`: the thread it runs if its status is `.run`, the thread with no frame
otherwise. -/
def Grid.thread (g : Grid) (n : Nat) : Thread :=
  match g.threads[n]? with
  | some (.run t) => t
  | _ => ⟨[], 0⟩

/-- **Threads in turn by an invariant.** For every contexts `c`, threads `t`, number `N` and
family `P` of memory predicates indexed by the number of threads done: if each thread `k < N`,
from every memory of `P k`, runs to its end (`Runs`) leaving a memory of `P (k + 1)`, then threads
`0` to `N - 1` run in turn (`Seq`) from every memory of `P 0` to a memory of `P N`
(`Turns.of_inv`). -/
theorem Seq.of_inv {c : Nat → Ctx} {t : Nat → Thread} {P : Nat → Mem → Prop} {N : Nat}
    (h : ∀ k < N, ∀ m, P k m → ∃ m', Runs (c k) (t k) m m' ∧ P (k + 1) m') {m : Mem}
    (h0 : P 0 m) : ∃ Es m', Seq c t (List.range N) m Es m' ∧ P N m' :=
  Turns.of_inv (fun hr => hr.trace) h h0

/-- **A start sound by an invariant.** For every program, kernel `fn`, launch `L`, arguments,
address choice and oracle whose start (`Grid.start`) gives grid `g₀`, with `N` threads, and
contexts `c`, on a caller's memory `m` meeting `Mem.BytesIn`, every observation `obs` that reads
only the blocks and every family `P` of memory predicates indexed by the number of threads done:
if `g₀`'s memory is of `P 0`, each thread `k < N` of `g₀` (`Grid.thread`), from every memory of
`P k`, runs to its end leaving a memory of `P (k + 1)`, and every memory `m'` of `P N` has a trace
with no data race (`racy`) that keeps the promise of `!invariant.load` (`kept`) and has
`obs m' = some y` with `R y`, then `g₀` is sound (`Grid.Sound`): `Seq.of_inv`, `Grid.start_run`
(every thread of `g₀` runs), `Grid.Done.bad_iff` (the done grid the threads leave is bad only by
its trace) and `Seq.start_sound`. The trace premise is the caller's. -/
theorem Seq.start_sound_inv {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') {P : Nat → Mem → Prop}
    (h0 : P 0 g₀.mem)
    (hk : ∀ k < g₀.threads.size, ∀ m, P k m →
      ∃ m', Runs (c k) (Grid.thread g₀ k) m m' ∧ P (k + 1) m')
    (hb : ∀ m', P g₀.threads.size m' → racy m'.trace = false ∧ kept m'.trace = true)
    (hy : ∀ m', P g₀.threads.size m' → ∃ y, obs m' = some y ∧ R y) : Grid.Sound L c g₀ obs R := by
  obtain ⟨Es, m', hs, hP⟩ := Seq.of_inv hk h0
  obtain ⟨y, hy, hR⟩ := hy m' hP
  refine Seq.start_sound h hm hO hs List.nodup_range (fun n hn => ?_)
    (fun j hj => List.mem_range.2 hj)
    (fun hb' => ((Grid.Done.bad_iff
        (Grid.done_foldl m' fun j hj => List.mem_range.2 hj)).1 hb').elim
      (fun h' => Bool.false_ne_true ((hb m' hP).1.symm.trans h'))
      fun h' => Bool.false_ne_true (h'.symm.trans (hb m' hP).2)) hy hR
  have hn := List.mem_range.1 hn
  obtain ⟨-, _, t, -, e⟩ := Grid.start_run h n _ (Array.getElem?_eq_getElem hn)
  have e' : g₀.threads[n]? = some (.run t) := by rw [Array.getElem?_eq_getElem hn, e]
  unfold Grid.thread
  rw [e']

end MojoProof.Sym
