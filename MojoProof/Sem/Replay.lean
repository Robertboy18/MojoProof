import MojoProof.Sem.Spec
import MojoProof.Sem.Determinism
import MojoProof.Sem.Buffer

/-!
# Replaying one execution, with certified violations

A checker of one execution of a kernel, for every program: the launch (`Grid.start`), the
evaluator `Grid.run`, and the final grid's trace and observation, at one address choice, oracle,
fuel and number of phases (`Kernel.replay`). `Replay.run` is `Grid.run` keeping the grid and the
thread where it stops (`Replay.Stop`); `Replay.run_eq` proves its result is `Grid.run`'s, with each
stop mapped to `Grid.run`'s fault (`Replay.Stop.toFault`). The result (`Replay.Found`) is one of:

* violations: thread `n`'s step or collective call is undefined behavior (`ub`); two accesses of
  the final trace race (`race`, the later first); a write touches the bytes a load with
  `!invariant.load` reads (`broken`, the load first); a phase completed nothing and left a thread
  that has not returned (`stuck`); the final grid's observation is `none` or fails `R` (`post`);
* none found (`pass`, with the observation, which satisfies `R`);
* unknown (`unknown`): out of fuel or phases, an `.unsupported` fault, or a launch that does not
  start. An unknown is never a violation.

Proved here, for every program, launch, contexts, grid, fuel, phases, observation and decidable
relation:
* `Replay.run_eq`: the replay's result is `Grid.run`'s (through `Replay.thread_eq`,
  `Replay.all_eq`, `Replay.fire_eq`);
* `Replay.run_stop`, the fault side of `Grid.run_reach`: where the replay stops, the stop's grid is
  reachable from the start, and its thread's step or collective call faults, or it has a thread
  that has not returned and no step (`Replay.Stop.Holds`; for the deadlock, every thread waits or
  has returned after a phase, `Replay.all_ok`, and no collective call completed,
  `Replay.fire_false`); `Grid.run_ub` is the same for `Grid.run`'s undefined behavior;
* `Replay.found_bad`: a violation the replay reports gives `¬ Grid.Sound` for the grid it
  replayed, if every grid reachable from it has the premises of `racy_iff` (`Grid.Fits`)
  (`Access.races_of_raceWith`, `clash_of_race`, `racy_of_race`, `kept_of_broken`);
* `Kernel.replay_sound`: a violation gives `¬ Kernel.Sound` at those arguments and memory, for
  every admission that admits the address choice and oracle; `Kernel.replay_unsafe`: a violation
  for the trivial observation (`Grid.Sound.unit`) gives it for every observation and relation;
* `Grid.Sound.map`, `Kernel.Sound.map`: soundness for an observation read through a function and
  a relation the original gives through it; `Kernel.replay_block`: so a relation that fixes the
  final contents of one block (`Elem.Out`, MojoProof/Sym/Kernel.lean) is refuted by a replay that
  compares that block's bytes (`Replay.bytes?`) with the ones it fixes.

The probes of an output from its cells' bytes (`Probe.drop`, `Probe.stale`, `Probe.swap`,
`Probe.zero`, `Probe.copy`) are the wrong outputs a kernel theorem's relation must reject: one
cell omitted, no cell stored, two cells swapped, every cell zero, the input copied.
The control, the certified violations of the probes on `vector_addition` and a faulting launch
are in MojoProofTest/Replay.lean (one launch and memory each).
-/

namespace MojoProof.Sem

open LLVM Relation

/-- The access of trace `tr` (newest first) that access `a` races with (`Access.races`), if any;
`sync` says a barrier of `a`'s block of threads lies between `a` and the events of the trace still
to be read. -/
def Access.raceWith (a : Access) : Bool → List Event → Option Access
  | _, [] => none
  | sync, .barrier k :: tr => a.raceWith (sync || k == a.who.cta) tr
  | sync, .access e :: tr =>
    if (e.who.thread != a.who.thread && !(sync && e.who.cta == a.who.cta) && a.conflict e) = true
    then some e
    else a.raceWith sync tr

/-- If `Access.raceWith` finds an access of the trace, `Access.races` holds, for every access,
barrier flag and trace. -/
theorem Access.races_of_raceWith {a e : Access} :
    ∀ {sync : Bool} {tr : List Event}, a.raceWith sync tr = some e → a.races sync tr = true
  | _, [], h => by cases h
  | sync, .barrier k :: tr, h => by
    simp only [Access.raceWith] at h
    simp only [Access.races]
    exact races_of_raceWith h
  | sync, .access e' :: tr, h => by
    simp only [Access.raceWith] at h
    simp only [Access.races]
    split at h
    · rename_i hc
      rw [hc, Bool.true_or]
    · rw [races_of_raceWith h, Bool.or_true]

/-- A data race of trace `tr` (newest first): an access and the earlier access it races with
(`Access.races`). -/
def race? : List Event → Option (Access × Access)
  | [] => none
  | .barrier _ :: tr => race? tr
  | .access a :: tr =>
    match a.raceWith false tr with
    | some e => some (a, e)
    | none => race? tr

/-- A race `race?` finds is a race by phases, for every trace: two accesses of `phases` clash
(`clash_access`, `clash_barrier`). -/
theorem clash_of_race : ∀ {tr : List Event} {p : Access × Access}, race? tr = some p →
    ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true
  | [], _, h => by cases h
  | .barrier _ :: tr, _, h => by
    simp only [race?] at h
    exact clash_barrier.2 (clash_of_race h)
  | .access a :: tr, _, h => by
    simp only [race?] at h
    refine clash_access.2 ?_
    split at h
    · rename_i e he
      exact .inl (Access.races_of_raceWith he)
    · exact .inr (clash_of_race h)

/-- **A race `race?` finds makes the trace racy** (the core's `racy` at `sig`), for every launch
and trace whose accesses are by threads of the launch in their blocks of threads and that is
shaped, the premises of `racy_iff`: `clash_of_race`. -/
theorem racy_of_race {L : Launch} {tr : List Event} {p : Access × Access}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (h : race? tr = some p) : GPUProof.racy sig (tr.map (Event.toCore L)).reverse = true :=
  (racy_iff hU hs).2 (clash_of_race h)

/-- A broken promise of `!invariant.load` in trace `tr` (the core's `kept` at `sig`): a load with
`!invariant.load` (of kind `frozen`, `Access.kind_frozen`) and an access that writes for the core
(`Kind.writes`: a write or an `atomicrmw`'s read) that touches a byte it reads. -/
def broken? (tr : List Event) : Option (Access × Access) :=
  let inv := tr.filterMap fun | .access a => if a.kind = .frozen then some a else none | _ => none
  tr.findSome? fun
    | .access e => if e.kind.writes then (inv.find? (·.overlaps e)).map (·, e) else none
    | .barrier _ => none

/-- A broken promise `broken?` finds makes the core's `kept` at `sig` false, for every launch and
trace. -/
theorem kept_of_broken {L : Launch} {tr : List Event} {p : Access × Access}
    (h : broken? tr = some p) : GPUProof.kept sig (tr.map (Event.toCore L)).reverse = false := by
  obtain ⟨x, hx, hf⟩ := List.exists_of_findSome?_eq_some h
  cases x with
  | barrier _ => cases hf
  | access e =>
    simp only at hf
    split at hf
    · rename_i hw
      rw [Bool.eq_false_iff]
      intro hk
      revert hf
      cases hr : List.find? (fun a => a.overlaps e) (tr.filterMap fun
        | .access a => if a.kind = .frozen then some a else none | _ => none) with
      | none => intro hf; cases hf
      | some r =>
        intro _
        obtain ⟨y, hy, hyr⟩ := List.mem_filterMap.1 (List.mem_of_find?_eq_some hr)
        cases y with
        | barrier _ => cases hyr
        | access a =>
          by_cases hfz : a.kind = .frozen
          · simp only [hfz, ↓reduceIte, Option.some.injEq] at hyr
            subst hyr
            have := kept_sig_iff.1 hk e a hx hy hw hfz
            rw [List.find?_some hr] at this
            cases this
          · simp [hfz] at hyr
    · cases hf

namespace Replay

/-- Why a replay stopped short of a final grid: thread `n`'s step at grid `g` (`fire = false`),
or the completion of the collective call it waits at (`fire = true`), is the fault `e`; a phase
completed nothing and left grid `g` with a thread that has not returned (`deadlock`); or the
evaluator ran out of fuel or phases (`out`). -/
inductive Stop
  /-- Thread `n`'s step at grid `g` (`fire = false`) or its collective call's completion
  (`fire = true`) is the fault `e`. -/
  | fault (g : Grid) (n : Nat) (fire : Bool) (e : Fault)
  /-- A phase completed nothing and left grid `g` with a thread that has not returned. -/
  | deadlock (g : Grid)
  /-- Out of fuel or phases, with the message. -/
  | out (msg : String)

/-- The fault `Grid.run` reports for a stop. -/
def Stop.toFault : Stop → Fault
  | .fault _ _ _ e => e
  | .deadlock _ => .ub "deadlock: no thread runs and no collective call completes"
  | .out msg => .unsupported msg

/-- `Grid.runThread`, stopping at the grid and thread of a fault. -/
def thread (c : Nat → Ctx) (n : Nat) : Nat → Grid → Except Stop Grid
  | 0, _ => throw (.out "out of fuel")
  | fuel + 1, g =>
    match g.advance c n with
    | .error e => throw (.fault g n false e)
    | .ok (some g') => thread c n fuel g'
    | .ok none => pure g

/-- `Grid.runAll`, stopping at the grid and thread of a fault. -/
def all (c : Nat → Ctx) (fuel : Nat) : List Nat → Grid → Except Stop Grid
  | [], g => pure g
  | n :: ns, g => do all c fuel ns (← thread c n fuel g)

/-- `Grid.fireAll`, stopping at the grid and thread of a fault. -/
def fire (L : Launch) (c : Nat → Ctx) : List Nat → Grid → Except Stop (Grid × Bool)
  | [], g => pure (g, false)
  | n :: ns, g =>
    match g.fire L c n with
    | .error e => throw (.fault g n true e)
    | .ok (some g') => return ((← fire L c ns g').1, true)
    | .ok none => fire L c ns g

/-- `Grid.run`, stopping at the grid and thread of a fault, or at the grid of a deadlock. -/
def run (L : Launch) (c : Nat → Ctx) (fuel : Nat) : Nat → Grid → Except Stop Grid
  | 0, _ => throw (.out "out of phases")
  | phases + 1, g =>
    if g.threads.all (· matches .done) then pure g
    else do
      let ns := List.range g.threads.size
      let r ← fire L c ns (← all c fuel ns g)
      if r.2 then run L c fuel phases { r.1 with mem := r.1.mem.compact }
      else if r.1.threads.all (· matches .done) then pure r.1
      else throw (.deadlock r.1)

variable {L : Launch} {c : Nat → Ctx}

/-- Mapping stops to their faults commutes with `>>=`. -/
theorem bind_eq {α β : Type} {x : Except Stop α} {y : Except Fault α} {f : α → Except Stop β}
    {f' : α → Except Fault β} (h : x.mapError Stop.toFault = y)
    (hf : ∀ a, (f a).mapError Stop.toFault = f' a) :
    (x >>= f).mapError Stop.toFault = y >>= f' := by
  subst h
  cases x with
  | error s => rfl
  | ok a => exact hf a

/-- `Replay.thread`, with each stop mapped to its fault, is `Grid.runThread`, for every fuel and
grid. -/
theorem thread_eq {n : Nat} : ∀ {fuel : Nat} {g : Grid},
    (thread c n fuel g).mapError Stop.toFault = g.runThread c n fuel
  | 0, _ => rfl
  | fuel + 1, g => by
    simp only [thread, Grid.runThread, bind, Except.bind]
    rcases g.advance c n with e | (_ | g')
    · rfl
    · rfl
    · exact thread_eq

/-- `Replay.all`, with each stop mapped to its fault, is `Grid.runAll`, for every list of threads
and grid. -/
theorem all_eq {fuel : Nat} : ∀ {ns : List Nat} {g : Grid},
    (all c fuel ns g).mapError Stop.toFault = Grid.runAll c fuel ns g
  | [], _ => rfl
  | n :: ns, g => by
    have h := thread_eq (c := c) (n := n) (fuel := fuel) (g := g)
    simp only [all, Grid.runAll, bind, Except.bind]
    revert h
    rcases thread c n fuel g with s | g'
    · intro h
      rw [← h]
      rfl
    · intro h
      rw [← h]
      exact all_eq

/-- `Replay.fire`, with each stop mapped to its fault, is `Grid.fireAll`, for every list of
threads and grid. -/
theorem fire_eq : ∀ {ns : List Nat} {g : Grid},
    (fire L c ns g).mapError Stop.toFault = Grid.fireAll L c ns g
  | [], _ => rfl
  | n :: ns, g => by
    simp only [fire, Grid.fireAll]
    rcases g.fire L c n with e | (_ | g')
    · rfl
    · exact fire_eq
    · exact bind_eq fire_eq fun _ => rfl

/-- **The replay is the evaluator**: its result, with each stop mapped to its fault, is
`Grid.run`'s, for every launch, contexts, fuel, phases and grid. -/
theorem run_eq {fuel : Nat} : ∀ {phases : Nat} {g : Grid},
    (run L c fuel phases g).mapError Stop.toFault = g.run L c fuel phases
  | 0, _ => rfl
  | phases + 1, g => by
    simp only [run, Grid.run]
    split <;> split <;> rename_i h₁ h₂
    all_goals try first | exact absurd h₁ h₂ | exact absurd h₂ h₁
    · rfl
    refine bind_eq all_eq fun g₁ => bind_eq fire_eq fun r => ?_
    split
    · exact run_eq
    split <;> split <;> rename_i h₁ h₂
    all_goals first | exact absurd h₁ h₂ | exact absurd h₂ h₁ | rfl

/-- If a replay result maps to `y` and is `.ok a`, then `y` is `.ok a`. -/
theorem ok_of_eq {α : Type} {x : Except Stop α} {y : Except Fault α} {a : α}
    (h : x.mapError Stop.toFault = y) (hx : x = .ok a) : y = .ok a := by
  subst hx
  exact h.symm

/-- What a stop says about the grids reachable from `g₀`: a fault's grid is reachable and its
thread's step (or collective call) is the fault; a deadlock's grid is reachable, has a thread
that has not returned, and has no step. -/
def Stop.Holds (L : Launch) (c : Nat → Ctx) (g₀ : Grid) : Stop → Prop
  | .fault g n b e => ReflTransGen (Grid.Step L c) g₀ g ∧
      (if b then g.fire L c n else g.advance c n) = .error e
  | .deadlock g => ReflTransGen (Grid.Step L c) g₀ g ∧ ¬ GPUProof.Done sig (g, L, c) ∧
      ∀ g', ¬ Grid.Step L c g g'
  | .out _ => True

/-- What a stop says about the grids reachable from `g₁` holds from every grid `g₀` that reaches
`g₁`. -/
theorem Stop.Holds.back {g₀ g₁ : Grid} {s : Stop} (hs : s.Holds L c g₁)
    (h : ReflTransGen (Grid.Step L c) g₀ g₁) : s.Holds L c g₀ := by
  cases s with
  | fault => exact ⟨h.trans hs.1, hs.2⟩
  | deadlock => exact ⟨h.trans hs.1, hs.2⟩
  | out => trivial

/-- Thread `n` of `g` does not run: it waits, has returned, or is not a thread of `g`. -/
def Idle (g : Grid) (n : Nat) : Prop := ∀ t, g.threads[n]? ≠ some (.run t)

/-- A thread that does not run has no step. -/
theorem advance_idle {g : Grid} {n : Nat} (h : Idle g n) : g.advance c n = .ok none := by
  unfold Grid.advance
  split
  · rename_i t ht
    exact absurd ht (h t)
  · rfl

/-- A number that is not a thread of the grid completes no collective call. -/
theorem fire_none {g : Grid} {n : Nat} (h : g.threads[n]? = none) : g.fire L c n = .ok none := by
  unfold Grid.fire
  rw [h]
  rfl

/-- A step of thread `n` changes no other thread and keeps the number of threads. -/
theorem advance_frame {g g' : Grid} {n : Nat} (h : g.advance c n = .ok (some g')) :
    g'.threads.size = g.threads.size ∧ ∀ k, k ≠ n → g'.threads[k]? = g.threads[k]? := by
  unfold Grid.advance at h
  split at h
  · simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r _
      cases r <;>
      · simp only [pure, Except.pure, Except.ok.injEq, Option.some.injEq] at h
        subst h
        exact ⟨Array.size_set! .., fun k hk => by
          rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_ne (Ne.symm hk)]⟩
  · cases h

/-- Where a replayed thread stops without a fault, it neither runs nor has changed another
thread. -/
theorem thread_ok {n : Nat} : ∀ {fuel : Nat} {g g' : Grid}, thread c n fuel g = .ok g' →
    Idle g' n ∧ g'.threads.size = g.threads.size ∧ ∀ k, k ≠ n → g'.threads[k]? = g.threads[k]?
  | 0, _, _, h => by cases h
  | fuel + 1, g, g', h => by
    simp only [thread] at h
    split at h
    · cases h
    · rename_i g₁ h₁
      obtain ⟨hi, hs, ho⟩ := thread_ok h
      obtain ⟨hs₁, ho₁⟩ := advance_frame h₁
      exact ⟨hi, hs.trans hs₁, fun k hk => (ho k hk).trans (ho₁ k hk)⟩
    · rename_i h₁
      cases h
      exact ⟨fun t ht => Grid.advance_run ht h₁, rfl, fun _ _ => rfl⟩

/-- After a phase's runs, every thread run, and every thread that was idle, is idle. -/
theorem all_ok {fuel : Nat} : ∀ {ns : List Nat} {g g' : Grid}, all c fuel ns g = .ok g' →
    g'.threads.size = g.threads.size ∧ ∀ k, (k ∈ ns ∨ Idle g k) → Idle g' k
  | [], g, g', h => by
    cases h
    exact ⟨rfl, fun k hk => hk.resolve_left (by simp)⟩
  | n :: ns, g, g', h => by
    simp only [all, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i g₁ h₁
      obtain ⟨hn, hs, ho⟩ := thread_ok h₁
      obtain ⟨hs', hi⟩ := all_ok h
      refine ⟨hs'.trans hs, fun k hk => hi k ?_⟩
      by_cases hkn : k = n
      · subst hkn
        exact .inr hn
      · rcases hk with hk | hk
        · exact .inl ((List.mem_cons.1 hk).resolve_left hkn)
        · exact .inr fun t ht => hk t (by rw [← ho k hkn]; exact ht)

/-- A completion phase that completed nothing left the grid, and no collective call of its
threads completes. -/
theorem fire_false : ∀ {ns : List Nat} {g : Grid} {r : Grid × Bool}, fire L c ns g = .ok r →
    r.2 = false → r.1 = g ∧ ∀ k ∈ ns, g.fire L c k = .ok none
  | [], _, _, h, _ => by
    cases h
    exact ⟨rfl, by simp⟩
  | n :: ns, g, r, h, hb => by
    simp only [fire] at h
    split at h
    · cases h
    · simp only [bind, Except.bind] at h
      split at h
      · cases h
      · cases h
        cases hb
    · rename_i h₁
      obtain ⟨h₂, hk⟩ := fire_false h hb
      exact ⟨h₂, List.forall_mem_cons.2 ⟨h₁, hk⟩⟩

/-- Where `Replay.thread` stops, the stop holds from the grid it started at (`Stop.Holds`). -/
theorem thread_stop {n : Nat} : ∀ {fuel : Nat} {g : Grid} {s : Stop},
    thread c n fuel g = .error s → s.Holds L c g
  | 0, _, _, h => by
    cases h
    trivial
  | fuel + 1, g, s, h => by
    simp only [thread] at h
    split at h
    · rename_i e h₁
      cases h
      exact ⟨.refl, h₁⟩
    · rename_i g₁ h₁
      exact (thread_stop h).back (.single ⟨n, .inl h₁⟩)
    · cases h

/-- Where `Replay.all` stops, the stop holds from the grid it started at. -/
theorem all_stop {fuel : Nat} : ∀ {ns : List Nat} {g : Grid} {s : Stop},
    all c fuel ns g = .error s → s.Holds L c g
  | [], _, _, h => by cases h
  | n :: ns, g, s, h => by
    simp only [all, bind, Except.bind] at h
    split at h
    · rename_i s' h₁
      cases h
      exact thread_stop h₁
    · rename_i g₁ h₁
      exact (all_stop h).back (Grid.runThread_reach (ok_of_eq thread_eq h₁))

/-- Where `Replay.fire` stops, the stop holds from the grid it started at. -/
theorem fire_stop : ∀ {ns : List Nat} {g : Grid} {s : Stop},
    fire L c ns g = .error s → s.Holds L c g
  | [], _, _, h => by cases h
  | n :: ns, g, s, h => by
    simp only [fire] at h
    split at h
    · rename_i e h₁
      cases h
      exact ⟨.refl, h₁⟩
    · rename_i g₁ h₁
      simp only [bind, Except.bind] at h
      split at h
      · rename_i s' h₂
        cases h
        exact (fire_stop h₂).back (.single ⟨n, .inr h₁⟩)
      · cases h
    · exact fire_stop h

/-- **The fault side of `Grid.run_reach`.** Where the replay stops, the stop holds of the start
grid (`Stop.Holds`): the grid of a fault is reachable and its thread's step or collective call is
the fault, and the grid of a deadlock is reachable, has a thread that has not returned, and has
no step. For every launch, contexts, fuel, phases and grid with at most the launch's number of
threads. -/
theorem run_stop {fuel : Nat} : ∀ {phases : Nat} {g : Grid} {s : Stop},
    g.threads.size ≤ volume L.grid * volume L.block → run L c fuel phases g = .error s →
      s.Holds L c g
  | 0, _, _, _, h => by
    cases h
    trivial
  | phases + 1, g, s, hsz, h => by
    simp only [run] at h
    split at h
    · cases h
    · simp only [bind, Except.bind] at h
      split at h
      · rename_i s' h₁
        cases h
        exact all_stop h₁
      · rename_i g₁ h₁
        have r₁ : ReflTransGen (Grid.Step L c) g g₁ := Grid.runAll_reach (ok_of_eq all_eq h₁)
        split at h
        · rename_i s' h₂
          cases h
          exact (fire_stop h₂).back r₁
        · rename_i r h₂
          have r₂ : ReflTransGen (Grid.Step L c) g₁ r.1 :=
            Grid.fireAll_reach (ok_of_eq fire_eq h₂)
          have hsz' : r.1.threads.size ≤ volume L.grid * volume L.block :=
            (Grid.reach_size (r₁.trans r₂)).trans_le hsz
          split at h
          · have hs := run_stop (g := ⟨r.1.threads, r.1.mem.compact⟩) hsz' h
            rw [Mem.compact_eq] at hs
            exact hs.back (r₁.trans r₂)
          · rename_i hb
            split at h
            · cases h
            · rename_i hd
              cases h
              obtain ⟨he, hf⟩ := fire_false h₂ (by simpa using hb)
              obtain ⟨hs, hi⟩ := all_ok h₁
              refine ⟨r₁.trans r₂, fun hD => hd (Grid.Done.all hsz' hD), ?_⟩
              rintro g' ⟨k, hk⟩
              rw [he] at hk
              by_cases hlt : k < g.threads.size
              · have hk' : k ∈ List.range g.threads.size := List.mem_range.2 hlt
                rcases hk with hk | hk
                · rw [advance_idle (hi k (.inl hk'))] at hk
                  cases hk
                · rw [hf k hk'] at hk
                  cases hk
              · have hn : g₁.threads[k]? = none := Array.getElem?_eq_none (by omega)
                rcases hk with hk | hk
                · rw [advance_idle (fun t ht => by rw [hn] at ht; cases ht)] at hk
                  cases hk
                · rw [fire_none hn] at hk
                  cases hk

/-- The final grid of a replay is reachable from the start, and every thread has returned. -/
theorem run_ok {fuel phases : Nat} {g g' : Grid} (h : run L c fuel phases g = .ok g') :
    ReflTransGen (Grid.Step L c) g g' ∧ GPUProof.Done sig (g', L, c) :=
  have h' := ok_of_eq run_eq h
  ⟨Grid.run_reach h', Grid.run_done h'⟩

/-- What the replay of one execution found: a violation (`ub`: thread `n`'s step or collective
call is undefined behavior; `race`: an access of the final trace and the earlier access it races
with; `broken`: a load with `!invariant.load` and a write to its bytes; `stuck`: a phase completed
nothing and left a thread that has not returned; `post`: the final grid's observation, `none` or
one that fails `R`), none (`pass`, with the observation), or unknown (`unknown`: out of fuel or
phases, an `.unsupported` fault, or a launch that does not start). -/
inductive Found (β : Type)
  /-- Thread `n`'s step or collective call is undefined behavior, with the message. -/
  | ub (n : Nat) (msg : String)
  /-- An access `a` of the final trace and the earlier access `e` it races with. -/
  | race (a e : Access)
  /-- A load with `!invariant.load` and a write that touches a byte it reads. -/
  | broken (load write : Access)
  /-- A phase completed nothing and left a thread that has not returned. -/
  | stuck
  /-- The final grid's observation `y`, which is `none` or fails `R`. -/
  | post (y : Option β)
  /-- No violation; the observation `y` satisfies `R`. -/
  | pass (y : β)
  /-- Neither: out of fuel or phases, an `.unsupported` fault, or a launch that does not start. -/
  | unknown (msg : String)
  deriving Repr

/-- The result is a violation. -/
def Found.bad {β : Type} : Found β → Bool
  | .pass _ | .unknown _ => false
  | _ => true

/-- The result is "none found". -/
def Found.passed {β : Type} : Found β → Bool
  | .pass _ => true
  | _ => false

/-- The replay's result checked: a stop's fault or deadlock; for a final grid, a race of its
trace (`race?`), then a broken promise (`broken?`), then its observation `obs` against `R`. -/
def found {β : Type} (obs : Mem → Option β) (R : β → Prop) [DecidablePred R] :
    Except Stop Grid → Found β
  | .error (.fault _ n _ (.ub msg)) => .ub n msg
  | .error (.fault _ _ _ (.unsupported msg)) => .unknown msg
  | .error (.deadlock _) => .stuck
  | .error (.out msg) => .unknown msg
  | .ok g =>
    match race? g.mem.trace, broken? g.mem.trace, obs g.mem with
    | some (a, e), _, _ => .race a e
    | none, some (r, w), _ => .broken r w
    | none, none, some y => if R y then .pass y else .post (some y)
    | none, none, none => .post none

/-- **A violation the replay reports is one.** For every launch, contexts, grid with at most the
launch's number of threads every grid reachable from which has the premises of `racy_iff`
(`Grid.Fits`, as every grid reachable from a start's has, `Grid.start_reach_fits`), fuel, phases,
observation and decidable relation: if the replay of `g` reports a violation, `g` is not sound.
A fault is `¬ Safe` at its grid, a deadlock `¬ Progress`, a race `¬ RaceFree` (`racy_of_race`), a
broken promise `¬ Kept`, and a final observation that is `none` or fails `R` contradicts the
field `post`. -/
theorem found_bad {β : Type} {obs : Mem → Option β} {R : β → Prop} [DecidablePred R]
    {fuel phases : Nat} {g : Grid} (hsz : g.threads.size ≤ volume L.grid * volume L.block)
    (hf : ∀ g', ReflTransGen (Grid.Step L c) g g' → g'.Fits L c)
    (h : (found obs R (run L c fuel phases g)).bad = true) : ¬ Grid.Sound L c g obs R := by
  intro hs
  revert h
  rcases hr : run L c fuel phases g with s | g'
  · have hh := run_stop hsz hr
    cases s with
    | fault g' n b e =>
      cases e with
      | ub msg =>
        intro _
        refine hs.safe g' hh.1 (Grid.faults_iff.2 ⟨n, .ub msg, ?_⟩)
        cases b
        · exact .inl hh.2
        · exact .inr hh.2
      | unsupported msg => simp [found, Found.bad]
    | deadlock g' =>
      intro _
      obtain ⟨hreach, hnd, hno⟩ := hh
      obtain ⟨g'', hst⟩ := hs.progress g' hreach hnd
      exact hno g'' hst
    | out msg => simp [found, Found.bad]
  · obtain ⟨hreach, hd⟩ := run_ok hr
    rcases h1 : race? g'.mem.trace with _ | ⟨a, e⟩
    · rcases h2 : broken? g'.mem.trace with _ | ⟨r, w⟩
      · rcases h3 : obs g'.mem with _ | y
        · intro _
          obtain ⟨y', hy', -⟩ := hs.post g' hreach hd
          rw [h3] at hy'
          cases hy'
        · by_cases hR : R y
          · simp [found, Found.bad, h1, h2, h3, hR]
          · intro _
            obtain ⟨y', hy', hR'⟩ := hs.post g' hreach hd
            rw [h3] at hy'
            cases hy'
            exact hR hR'
      · intro _
        have := hs.kept g' hreach
        rw [kept_of_broken h2] at this
        cases this
    · intro _
      have := hs.raceFree g' hreach
      rw [racy_of_race (hf g' hreach).trace (hf g' hreach).2 h1] at this
      cases this

end Replay

/-- **The fault side of `Grid.run_reach`, for the evaluator.** A run that ends in undefined
behavior reached a grid at which some thread's step or collective call faults, or one with a
thread of the launch that has not returned and no step: the start grid is not safe, or makes no
progress. For every launch, contexts, fuel, phases and grid with at most the launch's number of
threads. -/
theorem Grid.run_ub {L : Launch} {c : Nat → Ctx} {fuel phases : Nat} {g : Grid} {msg : String}
    (hsz : g.threads.size ≤ volume L.grid * volume L.block)
    (h : g.run L c fuel phases = .error (.ub msg)) :
    ∃ g', ReflTransGen (Grid.Step L c) g g' ∧
      (GPUProof.Faults sig (g', L, c) ∨ ¬ GPUProof.Done sig (g', L, c) ∧
        ∀ g'', ¬ Grid.Step L c g' g'') := by
  have he := Replay.run_eq (L := L) (c := c) (fuel := fuel) (phases := phases) (g := g)
  rw [h] at he
  revert he
  rcases hr : Replay.run L c fuel phases g with s | g'
  · intro he
    have hh := Replay.run_stop hsz hr
    cases s with
    | fault g' n b e =>
      refine ⟨g', hh.1, .inl (Grid.faults_iff.2 ⟨n, e, ?_⟩)⟩
      cases b
      · exact .inl hh.2
      · exact .inr hh.2
    | deadlock g' => exact ⟨g', hh.1, .inr hh.2⟩
    | out msg' => cases he
  · intro he
    cases he

/-- Soundness for the observation read through `f` and a relation `R'` that `R` gives through
it, for every launch, contexts and grid. -/
theorem Grid.Sound.map {L : Launch} {c : Nat → Ctx} {g : Grid} {β γ : Type}
    {obs : Mem → Option β} {R : β → Prop} {f : β → Option γ} {R' : γ → Prop}
    (hf : ∀ y, R y → ∃ z, f y = some z ∧ R' z) (h : Grid.Sound L c g obs R) :
    Grid.Sound L c g (fun m => (obs m).bind f) R' where
  safe := h.safe
  raceFree := h.raceFree
  kept := h.kept
  progress := h.progress
  terminates := h.terminates
  determinate g₁ g₂ h₁ h₂ d₁ d₂ := by simp only [h.determinate g₁ g₂ h₁ h₂ d₁ d₂]
  post g' hr hd := by
    obtain ⟨y, hy, hR⟩ := h.post g' hr hd
    obtain ⟨z, hz, hR'⟩ := hf y hR
    exact ⟨z, by simp [hy, hz], hR'⟩

/-- `Grid.Sound.map` for kernels: soundness for the observation read through `f` and a relation
`R'` that `R` gives through it, for every program, kernel, launch, arguments, memory and
admission. -/
theorem Kernel.Sound.map {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β γ : Type} {obs : Mem → Option β}
    {R : β → Prop} {f : β → Option γ} {R' : γ → Prop} (hf : ∀ y, R y → ∃ z, f y = some z ∧ R' z)
    (h : Kernel.Sound prog fn L args m adm obs R) :
    Kernel.Sound prog fn L args m adm (fun m => (obs m).bind f) R' := fun ch o ha => by
  obtain ⟨g, c, hs, hg⟩ := h ch o ha
  exact ⟨g, c, hs, hg.map hf⟩

/-- **The checker.** Kernel `fn` of `prog` launched with `L` on `args` and memory `m` at address
choice `ch` and oracle `oracle` (`Grid.start`), run with `fuel` steps per thread and phase and
`phases` phases (`Replay.run`, which is `Grid.run`, `Replay.run_eq`), its result checked for
the observation `obs` and the decidable relation `R` (`Replay.found`); `unknown` if the launch
does not start. -/
def Kernel.replay {β : Type} (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (ch : Nat → Nat) (oracle : Nat → Nat → Nat) (fuel phases : Nat) (obs : Mem → Option β)
    (R : β → Prop) [DecidablePred R] : Replay.Found β :=
  match Grid.start prog fn L args m ch oracle with
  | .ok (g, c) => Replay.found obs R (Replay.run L c fuel phases g)
  | .error (.ub msg) | .error (.unsupported msg) => .unknown ("the launch does not start: " ++ msg)

/-- **A violation the checker reports refutes the kernel theorem** at those arguments and memory,
for every admission that admits the address choice and oracle, for every program, kernel, launch,
arguments, memory, fuel, phases, observation and decidable relation. -/
theorem Kernel.replay_sound {β : Type} {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {fuel phases : Nat}
    {obs : Mem → Option β} {R : β → Prop} [DecidablePred R]
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    (h : (Kernel.replay prog fn L args m ch oracle fuel phases obs R).bad = true)
    (hadm : adm ch oracle) : ¬ Kernel.Sound prog fn L args m adm obs R := by
  intro hk
  obtain ⟨g, c, hst, hs⟩ := hk ch oracle hadm
  unfold Kernel.replay at h
  rw [hst] at h
  exact Replay.found_bad (Grid.start_size hst).le (fun _ hg => Grid.start_reach_fits hst hg) h hs

/-- A grid sound for some observation and relation is sound for the trivial observation and
relation, for every launch, contexts and grid: it keeps the five fields `safe`, `raceFree`,
`kept`, `progress` and `terminates`, and `determinate` and `post` hold for the trivial ones. -/
theorem Grid.Sound.unit {L : Launch} {c : Nat → Ctx} {g : Grid} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} (h : Grid.Sound L c g obs R) :
    Grid.Sound L c g (fun _ => some ()) (fun _ => True) where
  safe := h.safe
  raceFree := h.raceFree
  kept := h.kept
  progress := h.progress
  terminates := h.terminates
  determinate _ _ _ _ _ _ := rfl
  post _ _ _ := ⟨(), rfl, trivial⟩

/-- **A fault, race, broken promise or deadlock refutes every kernel theorem** at those arguments
and memory: a violation the checker reports for the trivial observation and relation (so not
`post`) gives `¬ Kernel.Sound` for every observation and relation and every admission that admits
the choice and oracle, for every program, kernel, launch, arguments, memory, fuel and phases. -/
theorem Kernel.replay_unsafe {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {fuel phases : Nat}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop}
    (h : (Kernel.replay prog fn L args m ch oracle fuel phases (fun _ => some ())
      (fun _ => True)).bad = true)
    (hadm : adm ch oracle) : ¬ Kernel.Sound prog fn L args m adm obs R := fun hk =>
  Kernel.replay_sound h hadm fun ch o ha =>
    let ⟨g, c, hs, hg⟩ := hk ch o ha
    ⟨g, c, hs, hg.unit⟩

/-- The bytes of a block, if there is one. -/
def Replay.bytes? (b : Option Block) : Option (List MemByte) :=
  b.map fun b => b.read 0 b.size

/-- **A replay refutes a relation that fixes one block.** For every program, kernel, launch,
arguments, memory `m`, choice, oracle, fuel, phases, block `out` of `m`, and relation `R` on the
blocks under which block `out` ends as `f x` for `m`'s block `x` (as `Elem.Out` fixes it with
`Elem.put`): if the replay that compares block `out`'s final bytes with `f x`'s reports a
violation, the kernel is not sound for the observation of the blocks and `R`, for every admission
that admits the choice and oracle. -/
theorem Kernel.replay_block {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {fuel phases : Nat}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {R : (Nat → Option Block) → Prop}
    {out : Nat} {f : Block → Block}
    (hR : ∀ B, R B → ∀ x, m.blocks out = some x → B out = some (f x))
    (hx : (m.blocks out).isSome = true)
    (h : (Kernel.replay prog fn L args m ch oracle fuel phases
      (fun m' => Replay.bytes? (m'.blocks out))
      (fun z => some z = Replay.bytes? ((m.blocks out).map f))).bad = true)
    (hadm : adm ch oracle) : ¬ Kernel.Sound prog fn L args m adm (fun m => some m.blocks) R := by
  intro hk
  obtain ⟨x, hx⟩ := Option.isSome_iff_exists.mp hx
  have hk' := hk.map (f := fun B => Replay.bytes? (B out))
    (R' := fun z => some z = Replay.bytes? ((m.blocks out).map f)) fun B hB => by
      rw [hR B hB x hx, hx]
      exact ⟨_, rfl, rfl⟩
  exact Kernel.replay_sound h hadm hk'

namespace Probe

/-- The probe that omits cell `k`: thread `k` stores nothing. -/
def drop (k : Nat) (bs : Nat → Option (List MemByte)) (i : Nat) : Option (List MemByte) :=
  if i = k then none else bs i

/-- The probe that leaves the output stale: no thread stores. -/
def stale (_ : Nat) : Option (List MemByte) := none

/-- The probe that swaps cells `i` and `j`. -/
def swap (i j : Nat) (bs : Nat → Option (List MemByte)) (k : Nat) : Option (List MemByte) :=
  if k = i then bs j else if k = j then bs i else bs k

/-- The probe that zeroes the output: each thread below `n` stores `w` zero bytes. -/
def zero (w n k : Nat) : Option (List MemByte) :=
  if k < n then some (leBytes w 0) else none

/-- The probe that copies the input: each thread `k` below `n` stores the encoding at `t` of `x`'s
cell `k`. -/
def copy {α : Type} (l : Layout) (t : Ty) (enc : α → Val) {N : Nat} (x : TorchLean.Tensor α [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then l.encode t (enc (x (⟨k, h.2⟩, PUnit.unit))) else none

end Probe

end MojoProof.Sem
