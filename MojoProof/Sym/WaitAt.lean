import MojoProof.Sym.WaitVia

/-!
# The memory at a thread's wait, as a function

A thread's run to a collective call is determined (`ToWait.det`, MojoProof/Sym/SegTrace.lean):
its status and memory there are functions of the thread and the memory it starts on.

* `nextWait`: that status and memory, by choice of the only pair when there is one;
  `nextWait_eq`: it is the pair of every run to a call.
* `waitAt`: the memory at the thread's wait after deliveries `ds`, from wait to wait, the thread
  resumed with each delivery on its memory.
* `RunsVia.waitAt`: in every run through waits `ws₁` and then a wait of predicate `P`, `P` holds
  at `waitAt` of `ws₁`'s deliveries. So a run lemma can name the memory at a wait that its proof
  chooses (`RunsVia.pin`), and `WarpRun.of_waits`'s memories, one function of phase and lane, can
  be its lanes' `waitAt`s.
* `Steps.keeps`, `ToWait.keeps`: a thread's steps keep every block and `next` (`Mem.Keeps`); so
  `RunsVia.waitAt_keeps`: `waitAt` has every property that `Mem.Keeps` carries and the deliveries'
  memories have, and `RunsVia.waitAt_next`: it has the `next` of the start memory and the
  deliveries' memories when they share it.
* `Runs.det`: a thread's run to its end is determined too; `endAt`: the memory at the thread's
  end after deliveries `ds`, from wait to wait as `waitAt`, then the only end memory there is.
  `RunsVia.endAt`: every run through waits `ws` ends on `endAt` of their deliveries, which has
  the run's final predicate, so a run lemma's final predicate can be one memory, the form of
  `WarpRun.of_waits`'s; `RunsVia.endAt_keeps`, `RunsVia.endAt_next`: as at a wait (`Runs.keeps`).

For every program, context, thread, memory and deliveries.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The status and memory at which thread `t` of context `c`, from memory `m`, reaches its next
collective call (`ToWait`): the only such pair (`ToWait.det`) if there is one, otherwise any. -/
noncomputable def nextWait (c : Ctx) (t : Thread) (m : Mem) : Status × Mem :=
  @Classical.epsilon _ ⟨(.done, {})⟩ fun p => ToWait c t m p.1 p.2

/-- For every context `c`, thread `t`, memories `m`, `m'` and status `s`: if `t` runs from `m` to
a collective call at status `s` on `m'`, then `nextWait c t m` is `(s, m')` (`ToWait.det`). -/
theorem nextWait_eq {c : Ctx} {t : Thread} {m m' : Mem} {s : Status} (h : ToWait c t m s m') :
    nextWait c t m = (s, m') := by
  have hs := Classical.epsilon_spec (p := fun p : Status × Mem => ToWait c t m p.1 p.2) ⟨(s, m'), h⟩
  obtain ⟨e₁, e₂⟩ := ToWait.det hs h
  exact Prod.ext e₁ e₂

/-- The memory at thread `t`'s wait after the deliveries `ds` of its earlier waits, from memory
`m`: with no delivery, the memory at its next collective call (`nextWait`); with a delivery `d`
first, the memory at the wait after the others from the waiting thread resumed with `d`'s value
(`Thread.resume`) on `d`'s memory. -/
noncomputable def waitAt (c : Ctx) : List (Option Val × Mem) → Thread → Mem → Mem
  | [], t, m => (nextWait c t m).2
  | d :: ds, t, m => match (nextWait c t m).1 with
    | .wait u _ _ _ => waitAt c ds (u.resume d.1) d.2
    | _ => m

/-- **The memory at a run's wait is `waitAt`'s.** For every context `c`, final predicate `Q`,
predicate `P`, delivery `d`, waits `ws₁` and `ws₂`, thread `t` and memory `m`: if `t` runs from
`m` through `ws₁` and then a wait of `P` (`RunsVia`), `P` holds at that wait with the memory
`waitAt c (ws₁.map (·.2)) t m`. By induction on `ws₁`, each run to a call being `nextWait`'s
(`nextWait_eq`). -/
theorem RunsVia.waitAt {c : Ctx} {Q : Mem → Prop} {P : Thread → Intrinsic → List Val → Mem → Prop}
    {d : Option Val × Mem}
    {ws₂ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))} :
    ∀ (ws₁ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, RunsVia c Q (ws₁ ++ (P, d) :: ws₂) t m →
      ∃ u i xs, P u i xs (MojoProof.Sym.waitAt c (ws₁.map (·.2)) t m)
  | [], t, m, h => by
    obtain ⟨u, i, xs, e, m₁, hT, hP, -⟩ := h
    refine ⟨u, i, xs, ?_⟩
    simp only [List.map_nil, MojoProof.Sym.waitAt, nextWait_eq hT]
    exact hP
  | (_, d') :: ws₁, t, m, h => by
    obtain ⟨u, i, xs, e, m₁, hT, -, hr⟩ := h
    simp only [List.map_cons, MojoProof.Sym.waitAt, nextWait_eq hT]
    exact RunsVia.waitAt ws₁ hr

/-- **Steps keep every block and `next`**: for every context, threads and memories: steps that
continue the thread (`Steps`) keep every block of the memory with its shape, `next`, and the
numbers below `next` with no block (`Mem.Keeps`; each step by `step_keeps`). -/
theorem Steps.keeps {c : Ctx} {t t' : Thread} {m m' : Mem} (h : Steps c t m t' m') :
    m.Keeps m' := by
  induction h with
  | refl => exact Mem.Keeps.refl _
  | cons h₁ _ ih =>
    have e₁ := step_keeps h₁
    simp only at e₁
    exact e₁.trans ih

/-- **A run to a wait keeps every block and `next`**: for every context, thread, memories and
status: a run of the thread to a collective call (`ToWait`) keeps the memory (`Mem.Keeps`, by
`Steps.keeps`; the waiting step changes no memory). -/
theorem ToWait.keeps {c : Ctx} {t : Thread} {m m' : Mem} {s : Status} (h : ToWait c t m s m') :
    m.Keeps m' :=
  have ⟨_, _, _, _, _, hs, _⟩ := h
  hs.keeps

/-- **A property the runs keep holds at a run's wait.** For every context `c`, final predicate
`Q`, predicate `P`, delivery `d`, waits `ws₁` and `ws₂`, thread `t`, memory `m` and property `S`
of memories that `Mem.Keeps` carries: if `t` runs from `m` through `ws₁` and then a wait of `P`
(`RunsVia`), the memories of `ws₁`'s deliveries have `S`, and so has `m` when `ws₁` is empty,
then so has `waitAt c (ws₁.map (·.2)) t m`: the run from the last delivery's memory (or `m`) to
the next call keeps the memory (`ToWait.keeps`). By induction on `ws₁`. -/
theorem RunsVia.waitAt_keeps {c : Ctx} {Q : Mem → Prop}
    {P : Thread → Intrinsic → List Val → Mem → Prop} {d : Option Val × Mem}
    {ws₂ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {S : Mem → Prop} (hS : ∀ m m', m.Keeps m' → S m → S m') :
    ∀ (ws₁ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, RunsVia c Q (ws₁ ++ (P, d) :: ws₂) t m → (ws₁ = [] → S m) →
      (∀ e ∈ ws₁, S e.2.2) → S (MojoProof.Sym.waitAt c (ws₁.map (·.2)) t m)
  | [], t, m, h, hm, _ => by
    obtain ⟨u, i, xs, e, m₁, hT, -, -⟩ := h
    simp only [List.map_nil, MojoProof.Sym.waitAt, nextWait_eq hT]
    exact hS _ _ hT.keeps (hm rfl)
  | (P', d') :: ws₁, t, m, h, _, hd => by
    obtain ⟨u, i, xs, e, m₁, hT, -, hr⟩ := h
    simp only [List.map_cons, MojoProof.Sym.waitAt, nextWait_eq hT]
    exact RunsVia.waitAt_keeps hS ws₁ hr (fun _ => hd (P', d') (by simp)) fun e he =>
      hd e (List.mem_cons_of_mem _ he)

/-- **The `next` at a run's wait.** For every context `c`, final predicate `Q`, predicate `P`,
delivery `d`, waits `ws₁` and `ws₂`, thread `t`, memory `m` and number `N`: if `t` runs from `m`
through `ws₁` and then a wait of `P` (`RunsVia`), and `m` and the memories of `ws₁`'s deliveries
have `next = N`, then so has `waitAt c (ws₁.map (·.2)) t m` (`RunsVia.waitAt_keeps`, since
`Mem.Keeps` keeps `next`). -/
theorem RunsVia.waitAt_next {c : Ctx} {Q : Mem → Prop}
    {P : Thread → Intrinsic → List Val → Mem → Prop} {d : Option Val × Mem}
    {ws₂ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))} {N : Nat} :
    ∀ (ws₁ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, RunsVia c Q (ws₁ ++ (P, d) :: ws₂) t m → m.next = N →
      (∀ e ∈ ws₁, e.2.2.next = N) → (MojoProof.Sym.waitAt c (ws₁.map (·.2)) t m).next = N := by
  intro ws₁ t m h hm hd
  exact RunsVia.waitAt_keeps (S := fun m => m.next = N) (fun _ _ hk hm => hk.next.trans hm) ws₁ h
    (fun _ => hm) hd

/-- **A run to its end is determined**, for every context, thread `t` and memory `m`: two runs
of `t` from `m` to its end (`Runs`) leave the same memory, since a step is a function of the
thread and memory, and a run continues only through steps that continue it (as `ToWait.det`). -/
theorem Runs.det {c : Ctx} {t : Thread} {m m₁ m₂ : Mem} (h₁ : Runs c t m m₁)
    (h₂ : Runs c t m m₂) : m₁ = m₂ := by
  obtain ⟨u₁, n₁, hs₁, hw₁⟩ := h₁
  obtain ⟨u₂, n₂, hs₂, hw₂⟩ := h₂
  induction hs₁ with
  | refl =>
    cases hs₂ with
    | refl =>
      rw [hw₁] at hw₂
      cases hw₂
      rfl
    | cons h _ =>
      rw [hw₁] at h
      cases h
  | cons h _ ih =>
    cases hs₂ with
    | refl =>
      rw [hw₂] at h
      cases h
    | cons h' hs' =>
      rw [h] at h'
      cases h'
      exact ih hw₁ hs'

/-- **A run to its end keeps every block and `next`**: for every context, thread and memories: a
run of the thread to its end (`Runs`) keeps the memory (`Mem.Keeps`, by `Steps.keeps` and
`step_keeps` at the last step). -/
theorem Runs.keeps {c : Ctx} {t : Thread} {m m' : Mem} (h : Runs c t m m') : m.Keeps m' := by
  obtain ⟨_, _, hs, hd⟩ := h
  have e := step_keeps hd
  simp only at e
  exact hs.keeps.trans e

/-- The memory at thread `t`'s end after the deliveries `ds` of its waits, from memory `m`: with
no delivery, the memory of its run to its end (`Runs`), the only one (`Runs.det`) if there is
one, otherwise any; with a delivery `d` first, the memory at the end after the others from the
waiting thread at its next collective call (`nextWait`) resumed with `d`'s value
(`Thread.resume`) on `d`'s memory, as `waitAt`. -/
noncomputable def endAt (c : Ctx) : List (Option Val × Mem) → Thread → Mem → Mem
  | [], t, m => @Classical.epsilon _ ⟨m⟩ fun m' => Runs c t m m'
  | d :: ds, t, m => match (nextWait c t m).1 with
    | .wait u _ _ _ => endAt c ds (u.resume d.1) d.2
    | _ => m

/-- **A run's end memory is `endAt`'s.** For every context `c`, final predicate `Q`, waits `ws`,
thread `t` and memory `m`: if `t` runs from `m` through `ws` to its end with `Q` (`RunsVia`), it
runs through `ws` to the one memory `endAt c (ws.map (·.2)) t m`, which has `Q`. By induction
on `ws`, each run to a call being `nextWait`'s (`nextWait_eq`) and the run to the end
`endAt`'s (`Classical.epsilon_spec`, `Runs.det`). -/
theorem RunsVia.endAt {c : Ctx} {Q : Mem → Prop} :
    ∀ (ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, RunsVia c Q ws t m →
      RunsVia c (· = MojoProof.Sym.endAt c (ws.map (·.2)) t m) ws t m ∧
        Q (MojoProof.Sym.endAt c (ws.map (·.2)) t m)
  | [], t, m, h => by
    obtain ⟨m', hr, hq⟩ := h
    have hs := Classical.epsilon_spec (p := fun m' => Runs c t m m') ⟨m', hr⟩
    have e : MojoProof.Sym.endAt c [] t m = m' := Runs.det hs hr
    simp only [List.map_nil]
    rw [e]
    exact ⟨⟨m', hr, rfl⟩, hq⟩
  | (P, d) :: ws, t, m, h => by
    obtain ⟨u, i, xs, e, m₁, hT, hP, hr⟩ := h
    have ih := RunsVia.endAt ws hr
    simp only [List.map_cons, MojoProof.Sym.endAt, nextWait_eq hT]
    exact ⟨⟨u, i, xs, e, m₁, hT, hP, ih.1⟩, ih.2⟩

/-- **A property the runs keep holds at a run's end.** For every context `c`, final predicate
`Q`, waits `ws`, thread `t`, memory `m` and property `S` of memories that `Mem.Keeps` carries:
if `t` runs from `m` through `ws` to its end (`RunsVia`), the memories of `ws`'s deliveries have
`S`, and so has `m` when `ws` is empty, then so has `endAt c (ws.map (·.2)) t m`: the run from
the last delivery's memory (or `m`) to the end keeps the memory (`Runs.keeps`). By induction on
`ws`. -/
theorem RunsVia.endAt_keeps {c : Ctx} {Q : Mem → Prop} {S : Mem → Prop}
    (hS : ∀ m m', m.Keeps m' → S m → S m') :
    ∀ (ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, RunsVia c Q ws t m → (ws = [] → S m) →
      (∀ e ∈ ws, S e.2.2) → S (MojoProof.Sym.endAt c (ws.map (·.2)) t m)
  | [], t, m, h, hm, _ => by
    obtain ⟨m', hr, -⟩ := h
    have hs := Classical.epsilon_spec (p := fun m' => Runs c t m m') ⟨m', hr⟩
    exact hS _ _ hs.keeps (hm rfl)
  | (P', d') :: ws, t, m, h, _, hd => by
    obtain ⟨u, i, xs, e, m₁, hT, -, hr⟩ := h
    simp only [List.map_cons, MojoProof.Sym.endAt, nextWait_eq hT]
    exact RunsVia.endAt_keeps hS ws hr (fun _ => hd (P', d') (by simp)) fun e he =>
      hd e (List.mem_cons_of_mem _ he)

/-- **The `next` at a run's end.** For every context `c`, final predicate `Q`, waits `ws`,
thread `t`, memory `m` and number `N`: if `t` runs from `m` through `ws` to its end (`RunsVia`),
and `m` and the memories of `ws`'s deliveries have `next = N`, then so has
`endAt c (ws.map (·.2)) t m` (`RunsVia.endAt_keeps`, since `Mem.Keeps` keeps `next`). -/
theorem RunsVia.endAt_next {c : Ctx} {Q : Mem → Prop} {N : Nat}
    (ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
    {t : Thread} {m : Mem} (h : RunsVia c Q ws t m) (hm : m.next = N)
    (hd : ∀ e ∈ ws, e.2.2.next = N) : (MojoProof.Sym.endAt c (ws.map (·.2)) t m).next = N :=
  RunsVia.endAt_keeps (S := fun m => m.next = N) (fun _ _ hk hm => hk.next.trans hm) ws h
    (fun _ => hm) hd

end MojoProof.Sym
