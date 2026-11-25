import MojoProof.Sym.SchedWait
import MojoProof.Sym.OblLemmas
import MojoProof.Sem.Shared

/-!
# A segment's events: the loads and stores of its summary

docs/proofs/barrier-owned.md, "A phase's accesses from the IR". A segment is a thread's run from
its start or its resumption after a collective to its next collective call (`Waits`, which
`Seg.sound` gives) or to its block's end (`EndsWith`, which `Block.sound` gives); its summary
lists its memory effects (`SEff`, a load or a store at a statement through a pointer term) and its
nodes, whose values `vals V S.nodes` give the terms' values. Proved for every program and launch:

* `SEff.access`: the access effect `e` logs under valuation `V` and node values `vs`, a read for a
  load and a write for a store, by `V.ctx.who`, of `stored t` bytes at the address the pointer
  term evaluates to (none for an `alloca`'s, which logs nothing).
* `SEff.apply_trace`: an effect other than an `alloca`'s that applies logs its access in front of
  the trace.
* `SEff.foldlM_trace`: effects without an `alloca`'s (`SEff.allocates`) that run log their
  accesses in order, newest first in the trace;
  `SEff.foldlM_loads`: loads that run change only the trace; `SEff.mapM_loads`: the accesses of
  loads are reads by `V.ctx.who`.
* `ToWait.det`: a thread's run to a collective call is determined by the thread and memory.
* `Waits.events`: the events every run of a thread to its next collective call adds are its
  segment summary's loads and stores, in order, at the addresses its nodes evaluate to;
  `EndsWith.events`: those of a run of a block to its terminator. `Waits.loads`: a segment whose
  effects are loads changes only the trace. `Waits.resume`: every run to the collective, resumed
  with any value, is at the position after the call, with the summary's value at every register
  but the call's result.
* `Ext`: a memory extends another's trace by events with a property; `Ext.trans`: extensions
  compose. `EndsWith.reads`: a block whose effects are loads extends the trace by reads by its
  thread.
* `Turns.events`: an event of threads run in turn (`Turns`) is an event of one thread's run;
  `Ext.turns`: threads in turn whose runs each extend the trace by events of a property extend it
  by such events.
* `Seq.bar_rounds`: the trace `Seq.start_sound_bar` reads, the threads' runs to the barrier from
  the start's empty trace, the barriers of the blocks of threads and their runs after it, is the
  two rounds of `rounds`, so `phases_rounds` gives its accesses' phases; `Ext.rounds`: an
  extension of an empty trace, the barriers and an extension after them are two such rounds.
* `Turns.blocks`: when each thread's run maps a block by `u n`, threads run in turn map it by
  each `u n` in turn.
* `Turns.cells`: when each thread `n`'s run writes the encoding of its value `val n` at the
  offset of its cell `cell n` of a block (or leaves the block for no cell), and the threads cover
  the cells with one thread per cell, the block after the threads run in turn holds the tensor of
  the cells' writers' values and has the block's other fields; `Mem.BufferIn.bytes`: so a buffer
  premise on it carries over.
* `Turns.imp`: a memory predicate that each thread's run keeps holds at every thread's start in
  a run of threads in turn, so a premise the first thread starts with is one each thread has.

The summary is given: these are statements about the run, the trace and the memory. Tests:
MojoProofTest/SegEvents.lean (gevm_kernel's segments before and after its barrier, each adding
one access at its cell, and their two rounds meeting the access premise of `Grid.sound_cells` at
`tpose 32`, with the twin without the barrier; the shared array after the first round holding
the threads' words, and every thread of the second round starting on it) and
MojoProofTest/GevmTrace.lean (gevm_kernel's whole trace of two rounds, with its global loads and
lane 0's global store, meeting `Grid.sound_rounds`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The access effect `e` logs under valuation `V`, given the values `vs` of the nodes, for every
program and launch: for a load, a read by `V.ctx.who` of `stored t` bytes at the address its
pointer term evaluates to, invariant when the load has `!invariant.load`; for a store, a write of
`stored t` bytes there, not atomic. It faults where `SEff.apply` reads no such statement or
pointer, and for an `alloca`'s effect (`SEff.alloca`), which logs no access. -/
def SEff.access (V : Valuation) (vs : List (Except Fault Val)) : SEff → Except Fault Access
  | .load lbl pc p => match V.stmt lbl pc with
    | some ⟨_, .load _ t (.mk (.ptr _) _) _, md⟩ => do
      let q ← (← p.eval V vs).addr?
      pure ⟨V.ctx.who, q, V.ctx.prog.layout.stored t, false, none,
        md.any (·.1 == "invariant.load")⟩
    | _ => throw (.unsupported "symbolic load at no load")
  | .store lbl pc _ p => match V.stmt lbl pc with
    | some ⟨_, .store _ (.mk t _) (.mk (.ptr _) _) _, _⟩ => do
      let q ← (← p.eval V vs).addr?
      pure ⟨V.ctx.who, q, V.ctx.prog.layout.stored t, true, none, false⟩
    | _ => throw (.unsupported "symbolic store at no store")
  | .alloca .. => throw (.unsupported "symbolic alloca logs no access")

/-- **An effect logs its access**, for every program, valuation `V`, node values `vs`, effect
`e` other than an `alloca`'s (`SEff.allocates [e] = false`) and memory: if `e` applies to `m`
giving `m'`, its access (`SEff.access`) is defined and `m'`'s trace is that access in front of
`m`'s. A store by `Mem.store_trace`. -/
theorem SEff.apply_trace {V : Valuation} {vs : List (Except Fault Val)} {m m' : Mem} {e : SEff}
    (ha : SEff.allocates [e] = false) (h : e.apply V vs m = .ok m') :
    ∃ a, e.access V vs = .ok a ∧ m'.trace = .access a :: m.trace := by
  revert h
  cases e with
  | load lbl pc p =>
    simp only [SEff.apply, SEff.access]
    split
    · rename_i heq
      intro h
      simp only [heq]
      obtain ⟨u, hu, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨q, hq, h⟩ := Except.bind_eq_ok.1 h
      cases h
      exact ⟨_, Except.bind_eq_ok.2 ⟨u, hu, Except.bind_eq_ok.2 ⟨q, hq, rfl⟩⟩, rfl⟩
    · intro h
      cases h
  | store lbl pc v p =>
    simp only [SEff.apply, SEff.access]
    split
    · rename_i heq
      intro h
      simp only [heq]
      obtain ⟨x, -, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨u, hu, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨q, hq, h⟩ := Except.bind_eq_ok.1 h
      exact ⟨_, Except.bind_eq_ok.2 ⟨u, hu, Except.bind_eq_ok.2 ⟨q, hq, rfl⟩⟩, Mem.store_trace h⟩
    · intro h
      cases h
  | alloca => cases ha

/-- **Effects log their accesses, in order**, for every program, valuation `V`, node values `vs`,
effects `es` without an `alloca`'s (`SEff.allocates`) and memory `m`: if `es` run from `m`
(`SEff.apply` in turn) to `m'`, their accesses
are defined (`SEff.access`, `as` in the effects' order) and `m'`'s trace is `as`, newest first, in
front of `m`'s. A segment's run of its summary's effects (`SEff.run`) is the case `m = V.mem`. -/
theorem SEff.foldlM_trace {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ {es : List SEff} {m m' : Mem}, SEff.allocates es = false →
      es.foldlM (SEff.apply V vs) m = .ok m' →
      ∃ as, es.mapM (SEff.access V vs) = .ok as ∧
        m'.trace = (as.map .access).reverse ++ m.trace
  | [], _, _, _, h => by
    cases h
    exact ⟨[], rfl, rfl⟩
  | e :: es, m, m', hA, h => by
    simp only [SEff.allocates, List.any_cons, Bool.or_eq_false_iff] at hA
    rw [List.foldlM_cons] at h
    obtain ⟨m₁, h₁, h⟩ := Except.bind_eq_ok.1 h
    obtain ⟨a, ha, e₁⟩ := SEff.apply_trace
      (by simp only [SEff.allocates, List.any_cons, List.any_nil, Bool.or_false]; exact hA.1) h₁
    obtain ⟨as, has, e₂⟩ := SEff.foldlM_trace hA.2 h
    refine ⟨a :: as, ?_, by simp [e₂, e₁]⟩
    rw [List.mapM_cons, ha, has]
    rfl

/-- **Loads change only the trace**, for every program, valuation `V`, node values `vs`, effects
`es` and memory `m`: if every effect of `es` is a load and `es` run from `m` (`SEff.apply` in
turn) to `m'`, then `m'` is `m` with `m'`'s trace: its blocks and next fresh number are `m`'s. -/
theorem SEff.foldlM_loads {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ {es : List SEff} {m m' : Mem}, (∀ e ∈ es, ∃ lbl pc p, e = .load lbl pc p) →
      es.foldlM (SEff.apply V vs) m = .ok m' → m' = { m with trace := m'.trace }
  | [], _, _, _, h => by
    cases h
    rfl
  | e :: es, m, m', hl, h => by
    obtain ⟨lbl, pc, p, rfl⟩ := hl e List.mem_cons_self
    rw [List.foldlM_cons] at h
    obtain ⟨m₁, h₁, h₂⟩ := Except.bind_eq_ok.1 h
    have e₁ : m₁ = { m with trace := m₁.trace } := by
      revert h₁
      simp only [SEff.apply]
      split
      · intro h₁
        obtain ⟨u, -, h₁⟩ := Except.bind_eq_ok.1 h₁
        obtain ⟨q, -, h₁⟩ := Except.bind_eq_ok.1 h₁
        cases h₁
        rfl
      · intro h₁
        cases h₁
    have e₂ := SEff.foldlM_loads (fun e he => hl e (List.mem_cons_of_mem _ he)) h₂
    calc m' = { m₁ with trace := m'.trace } := e₂
      _ = { m with trace := m'.trace } := by rw [e₁]

/-- **Loads log reads**, for every program, valuation `V`, node values `vs` and effects `es`: if
every effect of `es` is a load and their accesses are defined (`SEff.access`, `as`), every access
of `as` is by `V.ctx.who` and reads. -/
theorem SEff.mapM_loads {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ {es : List SEff} {as : List Access}, (∀ e ∈ es, ∃ lbl pc p, e = .load lbl pc p) →
      es.mapM (SEff.access V vs) = .ok as → ∀ a ∈ as, a.who = V.ctx.who ∧ a.write = false
  | [], _, _, h => by
    simp only [List.mapM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    intro a ha
    cases ha
  | e :: es, as, hl, h => by
    obtain ⟨lbl, pc, p, rfl⟩ := hl e List.mem_cons_self
    rw [List.mapM_cons] at h
    obtain ⟨a, ha, h⟩ := Except.bind_eq_ok.1 h
    obtain ⟨as', has, h⟩ := Except.bind_eq_ok.1 h
    cases h
    have h₁ : a.who = V.ctx.who ∧ a.write = false := by
      revert ha
      simp only [SEff.access]
      split
      · intro ha
        obtain ⟨u, -, ha⟩ := Except.bind_eq_ok.1 ha
        obtain ⟨q, -, ha⟩ := Except.bind_eq_ok.1 ha
        cases ha
        exact ⟨rfl, rfl⟩
      · intro ha
        cases ha
    intro x hx
    rcases List.mem_cons.1 hx with rfl | hx
    · exact h₁
    · exact SEff.mapM_loads (fun e he => hl e (List.mem_cons_of_mem _ he)) has x hx

/-- **A run to a wait is determined**, for every context, thread `t` and memory `m`: two runs of
`t` from `m` to a collective call (`ToWait`) reach the same status and memory, since a step is a
function of the thread and memory, and a run continues only through steps that continue it. -/
theorem ToWait.det {c : Ctx} {t : Thread} {m m₁ m₂ : Mem} {s₁ s₂ : Status}
    (h₁ : ToWait c t m s₁ m₁) (h₂ : ToWait c t m s₂ m₂) : s₁ = s₂ ∧ m₁ = m₂ := by
  obtain ⟨u₁, i₁, as₁, d₁, rfl, hs₁, hw₁⟩ := h₁
  obtain ⟨u₂, i₂, as₂, d₂, rfl, hs₂, hw₂⟩ := h₂
  induction hs₁ with
  | refl =>
    cases hs₂ with
    | refl =>
      rw [hw₁] at hw₂
      cases hw₂
      exact ⟨rfl, rfl⟩
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

/-- **The events of a segment's run to its collective**, for every program, context, thread `t`,
memory `m`, frames, valuation `V`, block and segment summary `S` with the facts of `Waits` (which
`Seg.sound` gives) and without an `alloca`'s effect (`SEff.allocates`; `Seg.sound`'s summaries
have none): the accesses of `S`'s effects are defined (`SEff.access` at the nodes' values,
`as` in the effects' order), and every run of `t` from `m` to a collective call (`ToWait`; one
exists, `Waits.toWait`) leaves a memory whose trace is those accesses, newest first, in front of
`V.mem`'s. At an entry valuation `V.mem` is `m`, so these are the events the thread adds. By
`SEff.foldlM_trace` and `ToWait.det`. -/
theorem Waits.events {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : SegSummary} (h : Waits c t m f rest (V, lbl, S))
    (hA : SEff.allocates S.effs = false) :
    ∃ as, S.effs.mapM (SEff.access V (vals V S.nodes)) = .ok as ∧
      ∀ s m', ToWait c t m s m' → m'.trace = (as.map .access).reverse ++ V.mem.trace :=
  have ⟨_, _, _, _, hs, _, _, _, _, _, _, _, hr, _, hw⟩ := h
  have ⟨as, ha, e⟩ := SEff.foldlM_trace hA hr
  ⟨as, ha, fun _ _ h' => by rw [(ToWait.det h' ⟨_, _, _, _, rfl, hs, hw⟩).2, e]⟩

/-- **A segment of loads changes only the trace**, for every program, context, thread `t`,
memory `m`, frames, valuation `V`, block and segment summary `S` with the facts of `Waits`: if
every effect of `S` is a load, every run of `t` from `m` to a collective call (`ToWait`) leaves
`V.mem` with another trace, so its blocks and next fresh number. At an entry valuation `V.mem` is
`m`. By `SEff.foldlM_loads` and `ToWait.det`. -/
theorem Waits.loads {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : SegSummary} (h : Waits c t m f rest (V, lbl, S))
    (hl : ∀ e ∈ S.effs, ∃ lbl pc p, e = .load lbl pc p) :
    ∀ s m', ToWait c t m s m' → m' = { V.mem with trace := m'.trace } := by
  obtain ⟨_, _, _, _, hs, _, _, _, _, _, _, _, hr, _, hw⟩ := h
  intro s m' h'
  obtain ⟨-, rfl⟩ := ToWait.det h' ⟨_, _, _, _, rfl, hs, hw⟩
  exact SEff.foldlM_loads hl hr

/-- **A segment's run to its collective, resumed**, for every program, context, thread `t`, memory
`m`, frames `f` above `rest`, valuation `V`, block `lbl` and segment summary `S` with the facts of
`Waits` (which `Seg.sound` gives): every run of `t` from `m` to a collective call (`ToWait`) ends at
the wait of a thread `u`, and for every value `v`, `u` resumed with `v` (`Thread.resume`) has a top
frame `fr` above `rest` running `V.fn` at block `lbl` and position `f.pc + S.len + 1`, with, at
every register but the result of the call at `f.pc + S.len`, the value `S`'s registers give
(`regVal`). It is `Seg.resume` and `Seg.resume_regs` at every run to the wait rather than at one.
By `ToWait.det`, `Thread.resume_at` and `Thread.resume_regs`. -/
theorem Waits.resume {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : SegSummary} (h : Waits c t m f rest (V, lbl, S)) :
    ∀ s m', ToWait c t m s m' → ∃ u i ws d, s = .wait u i ws d ∧ ∀ v, ∃ fr,
      (Thread.resume u v).frames = fr :: rest ∧ fr.fn = V.fn ∧ fr.label = lbl ∧
        fr.pc = f.pc + S.len + 1 ∧
        ∀ r, ((V.fn.blocks.find? (·.label == lbl)).bind
            fun b => b.stmts[f.pc + S.len]?.bind (·.res)) ≠ some r →
          fr.regs r = regVal V (vals V S.nodes) S.regs r := by
  obtain ⟨fe, me, ws, fd, hs, hfe, hle, hpe, -, -, hreg, -, -, -, hwt⟩ := h
  intro s m' h'
  obtain ⟨rfl, -⟩ := ToWait.det h' ⟨_, _, _, _, rfl, hs, hwt⟩
  refine ⟨_, _, _, _, rfl, fun v => ?_⟩
  obtain ⟨fr, hr, h1, h2, h3, -, -⟩ := Thread.resume_at fe rest (V.k + S.len) v
  obtain ⟨fr', hr', hfr⟩ := Thread.resume_regs fe rest (V.k + S.len) v
  obtain rfl := (List.cons.inj (congrArg Thread.frames (hr.symm.trans hr'))).1
  refine ⟨fr, by rw [hr], h1.trans hfe, h2.trans hle, by rw [h3, hpe],
    fun r hne => (hfr r ?_).trans (hreg r)⟩
  rw [hfe, hle, hpe]
  exact hne

/-- **A block's run to its end, with its events**, for every program, `fmul contract` setting,
context, thread, memory, frames, valuation `V`, block and summary `S` without an `alloca`'s
effect (`SEff.allocates`; `Block.sound`'s summaries have none): the facts of `EndsWith`
(`Ends` and `EndsC`, which `Block.sound` gives) contain the thread's steps to the block's
terminator at the frame `fe` with step count `V.k + S.len`, on a memory `me` whose trace is the
accesses of `S`'s effects (`SEff.access` at the nodes' values, `as` in the effects' order),
newest first, in front of `V.mem`'s, and the terminator's step there succeeds. -/
theorem EndsWith.events {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation} {lbl : Nat} {S : Summary}
    (h : EndsWith contract c t m f rest (V, lbl, S)) (hA : SEff.allocates S.effs = false) :
    ∃ fe me as r, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧
      step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r ∧
      S.effs.mapM (SEff.access V (vals V S.nodes)) = .ok as ∧
      me.trace = (as.map .access).reverse ++ V.mem.trace :=
  have ⟨fe, me, hs, _, _, _, _, _, _, hr, r, _, hx⟩ := h
  have ⟨as, ha, e⟩ := SEff.foldlM_trace hA hr
  ⟨fe, me, as, r, hs, hx, ha, e⟩

/-- Memory `m'` extends `m`'s trace by events of `P`: `m'`'s trace is a list of events, each
with `P`, in front of `m`'s. -/
def Ext (P : Event → Prop) (m m' : Mem) : Prop :=
  ∃ E, m'.trace = E ++ m.trace ∧ ∀ e ∈ E, P e

/-- **Extensions compose**, for every property `P` of events and memories: if `m₂` extends `m₁`'s
trace by events of `P` and `m₃` extends `m₂`'s, `m₃` extends `m₁`'s. -/
theorem Ext.trans {P : Event → Prop} {m₁ m₂ m₃ : Mem} (h₁ : Ext P m₁ m₂) (h₂ : Ext P m₂ m₃) :
    Ext P m₁ m₃ :=
  have ⟨E₁, e₁, p₁⟩ := h₁
  have ⟨E₂, e₂, p₂⟩ := h₂
  ⟨E₂ ++ E₁, by rw [e₂, e₁, List.append_assoc], fun e he =>
    (List.mem_append.1 he).elim (p₂ e) (p₁ e)⟩

/-- **A block of loads reads**, for every program, `fmul contract` setting, context, thread,
memory, frames, valuation `V`, block and summary `S` with the facts of `EndsWith` (which
`Block.sound` gives): if every effect of `S` is a load, the thread's steps reach the block's
terminator, whose step succeeds, on a memory that extends `V.mem`'s trace by reads by
`V.ctx.who` only (`Ext`). `EndsWith.events` and `SEff.mapM_loads`. -/
theorem EndsWith.reads {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation} {lbl : Nat} {S : Summary}
    (h : EndsWith contract c t m f rest (V, lbl, S))
    (hl : ∀ e ∈ S.effs, ∃ lbl pc p, e = .load lbl pc p) :
    ∃ fe me r, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧
      step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r ∧
      Ext (fun e => ∃ a, e = .access a ∧ a.who = V.ctx.who ∧ a.write = false) V.mem me :=
  have ⟨fe, me, as, r, hs, hx, ha, e⟩ := EndsWith.events h (by
    simp only [SEff.allocates, List.any_eq_false]
    intro e he
    obtain ⟨_, _, _, rfl⟩ := hl e he
    exact Bool.false_ne_true)
  ⟨fe, me, r, hs, hx, _, e, fun x hx => by
    obtain ⟨a, ha', rfl⟩ := List.mem_map.1 (List.mem_reverse.1 hx)
    exact ⟨a, rfl, SEff.mapM_loads hl ha a ha'⟩⟩

/-- **An event of threads in turn is an event of one thread's run**, for every family of runs
`R`, threads `ns` and memories: every event of the trace `Turns` adds (`Turns.trace`) is put in
front by the run of some thread `n` of `ns`, from a memory `m₀` to `m₁` with
`m₁.trace = E ++ m₀.trace` and the event in `E`. -/
theorem Turns.events {R : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') :
    ∀ e ∈ Es.reverse.flatten,
      ∃ n ∈ ns, ∃ m₀ m₁ E, R n m₀ m₁ ∧ m₁.trace = E ++ m₀.trace ∧ e ∈ E := by
  induction h with
  | nil => simp
  | cons hR e₁ _ ih =>
    intro e he
    simp only [List.reverse_cons, List.flatten_append, List.flatten_cons, List.flatten_nil,
      List.append_nil, List.mem_append] at he
    rcases he with he | he
    · obtain ⟨n, hn, m₀, m₁, E, h1, h2, h3⟩ := ih e he
      exact ⟨n, List.mem_cons_of_mem _ hn, m₀, m₁, E, h1, h2, h3⟩
    · exact ⟨_, List.mem_cons_self .., _, _, _, hR, e₁, he⟩

/-- **The trace through one barrier is two rounds**, for every number `G` of blocks of threads,
families of runs `R₁` and `R₂`, threads `ns` and memories: threads `ns` run in turn by `R₁` from a
memory with an empty trace (as the start's, `Grid.start_trace`) to `m₁`, the barriers of blocks of
threads `0` to `G - 1` are logged, and threads `ns` run in turn by `R₂` from there to `m'`: then
`m'`'s trace is `rounds G` of the two runs' events (`Turns.trace`, `Mem.log_barriers`). With
`R₁` the runs to a barrier (`Seq.ToWait`) and `R₂` the runs to the end (`Seq`) it is the trace of
`Seq.start_sound_bar`, whose accesses' phases `phases_rounds` gives. -/
theorem Seq.bar_rounds {G : Nat} {R₁ R₂ : Nat → Mem → Mem → Prop} {ns : List Nat}
    {m₀ m₁ m' : Mem} {Es₁ Es₂ : List (List Event)} (h0 : m₀.trace = [])
    (h₁ : Turns R₁ ns m₀ Es₁ m₁)
    (h₂ : Turns R₂ ns ((List.range G).foldl (fun m b => m.log (.barrier b)) m₁) Es₂ m') :
    m'.trace = rounds G [Es₁.reverse.flatten, Es₂.reverse.flatten] := by
  rw [h₂.trace, Mem.log_barriers, h₁.trace, h0, List.append_nil]
  rfl

/-- **Threads in turn extend the trace by their events**, for every family of runs `R`, threads
`ns`, memories and properties `P n` of events: if every run of a thread `n` of `ns` by `R`
extends the trace by events of `P n` (`Ext`), threads `ns` run in turn by `R` (`Turns`) extend
it by events each of which has `P n` for some `n` of `ns`. `Turns.trace` and `Turns.events`. -/
theorem Ext.turns {R : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') {P : Nat → Event → Prop}
    (hR : ∀ n ∈ ns, ∀ m₁ m₂, R n m₁ m₂ → Ext (P n) m₁ m₂) :
    Ext (fun e => ∃ n ∈ ns, P n e) m m' := by
  refine ⟨_, h.trace, fun e he => ?_⟩
  obtain ⟨n, hn, m₀, m₁, E, hr, hE, he⟩ := Turns.events h e he
  obtain ⟨E', hE', hp⟩ := hR n hn m₀ m₁ hr
  rw [hE] at hE'
  rw [List.append_cancel_right hE'] at he
  exact ⟨n, hn, hp e he⟩

/-- **Extensions around the barriers are two rounds**, for every number `G` of blocks of threads,
properties `P₀` and `P₁` of events and memories: if `m₁` extends a memory `m₀` with an empty
trace (as the start's, `Grid.start_trace`) by events of `P₀`, and `m'` extends `m₁` with the
barriers of blocks of threads `0` to `G - 1` logged by events of `P₁`, then `m'`'s trace is
`rounds G [E₀, E₁]` for a round `E₀` of events of `P₀` and a round `E₁` of events of `P₁`
(`Mem.log_barriers`), the form `phases_rounds` and `Grid.sound_rounds` take. -/
theorem Ext.rounds {G : Nat} {P₀ P₁ : Event → Prop} {m₀ m₁ m' : Mem} (h0 : m₀.trace = [])
    (h₁ : Ext P₀ m₀ m₁)
    (h₂ : Ext P₁ ((List.range G).foldl (fun m b => m.log (.barrier b)) m₁) m') :
    ∃ E₀ E₁, m'.trace = rounds G [E₀, E₁] ∧ (∀ e ∈ E₀, P₀ e) ∧ ∀ e ∈ E₁, P₁ e := by
  obtain ⟨E₀, e₀, p₀⟩ := h₁
  obtain ⟨E₁, e₁, p₁⟩ := h₂
  refine ⟨E₀, E₁, ?_, p₀, p₁⟩
  rw [e₁, Mem.log_barriers, e₀, h0, List.append_nil]
  rfl

/-- **Threads in turn map a block by each thread's map**, for every family of runs `R`, threads
`ns`, memories, block number `b` and maps `u n` of a block: if every run of thread `n` of `ns`
from a memory whose block `b` is `blk` ends with block `b` being `u n blk`, then threads `ns` run
in turn (`Turns`) from a memory whose block `b` is `blk` end with block `b` being `blk` mapped by
each `u n` in `ns`'s order. -/
theorem Turns.blocks {R : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') {b : Nat}
    {u : Nat → Sem.Block → Sem.Block}
    (hR : ∀ n ∈ ns, ∀ m₁ m₂, R n m₁ m₂ → ∀ blk, m₁.blocks b = some blk →
      m₂.blocks b = some (u n blk)) :
    ∀ {blk : Sem.Block}, m.blocks b = some blk →
      m'.blocks b = some (ns.foldl (fun blk n => u n blk) blk) := by
  induction h with
  | nil => exact fun hb => hb
  | cons hr _ _ ih =>
    intro blk hb
    exact ih (fun n hn => hR n (List.mem_cons_of_mem _ hn))
      (hR _ (List.mem_cons_self ..) _ _ hr blk hb)

open TorchLean in
/-- **Threads that store their values at their cells in turn leave the tensor of the cells'
writers**, for every family of runs `R`, threads `ns`, memories, block number `b`, codec,
offsets `off` that are `l.stored t` bytes apart and in the block, cell map
`cell : Nat → Option (Shape.Coord s)` and values `val n` with encodings `bs n`: if no two threads
of `ns` map to one cell, every cell has a thread of `ns` mapping to it, and every run of thread `n`
of `ns` writes `bs n` at `off i` of block `b` for `cell n = some i` and keeps block `b` for
`cell n = none`, then after threads `ns` run in turn (`Turns`) block `b` is the block before with
other bytes, and holds the tensor whose element `i` is `val (wr i)`, for a thread `wr i` of `ns`
that maps to `i`. `Turns.blocks` and `Block.holds_cells`. -/
theorem Turns.cells {α : Type} [Storage α] {s : Shape} {l : Layout} {t : Ty} {enc : α → Val}
    {R : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') {b : Nat} {off : Shape.Coord s → Nat}
    {cell : Nat → Option (Shape.Coord s)} {val : Nat → α} {bs : Nat → List MemByte}
    (hc : l.Codec t enc) (hbs : ∀ n, l.encode t (enc (val n)) = some (bs n))
    (hap : Apart off (l.stored t))
    (hu : ∀ n ∈ ns, ∀ n' ∈ ns, ∀ i, cell n = some i → cell n' = some i → n = n')
    (hR : ∀ n ∈ ns, ∀ m₁ m₂, R n m₁ m₂ → ∀ blk, m₁.blocks b = some blk →
      m₂.blocks b = some ((cell n).elim blk fun i => blk.put (off i) (bs n)))
    {blk : Sem.Block} (hb : m.blocks b = some blk) (hin : ∀ i, off i + l.stored t ≤ blk.size)
    (hall : ∀ i, ∃ n ∈ ns, cell n = some i) :
    (∃ β, m'.blocks b = some { blk with bytes := β }) ∧
      ∃ wr : Shape.Coord s → Nat, (∀ i, wr i ∈ ns ∧ cell (wr i) = some i) ∧
        m'.Holds l b t enc off (Tensor.Rep.ofFn fun i => val (wr i)) := by
  have e := h.blocks hR hb
  obtain ⟨β, hβ⟩ := Block.cells_bytes (off := off) (bs := bs) (cell := cell) ns blk
  obtain ⟨wr, hwr, hH⟩ := Block.holds_cells (val := val) hc hap hin hbs hu hall
  exact ⟨⟨β, e.trans (congrArg some hβ)⟩, wr, hwr, _, e, hH⟩

/-- **A buffer premise carries over writes to its bytes**, for every pair of memories, address
space, block number `c`, size, alignment, owner and access: if block `c` of `m'` is `m`'s block
`c` with other bytes, `Mem.BufferIn` at `c` on `m` gives it on `m'`. -/
theorem _root_.MojoProof.Sem.Mem.BufferIn.bytes {m m' : Mem} {s c size al : Nat} {o : Owner}
    {w : Bool} {blk : Sem.Block} {β : Nat → MemByte} (h : m.BufferIn s c size al o w)
    (hb : m.blocks c = some blk) (hb' : m'.blocks c = some { blk with bytes := β }) :
    m'.BufferIn s c size al o w := by
  obtain ⟨x, hx, h1⟩ := h
  rw [hb] at hx
  cases hx
  exact ⟨_, hb', h1⟩

/-- **Threads in turn under an invariant**, for every pair of families of runs `R` and `R'`,
threads `ns`, memories and memory predicate `P`: if every run of a thread `n` of `ns` by `R` from
a memory of `P` is a run by `R'` and leaves a memory of `P`, then threads `ns` run in turn by `R`
(`Turns`) from a memory of `P` run in turn by `R'`, to a memory of `P`. At
`R' n m₁ m₂ := P m₁ ∧ R n m₁ m₂`, every thread starts on a memory of `P`. -/
theorem Turns.imp {R R' : Nat → Mem → Mem → Prop} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m') {P : Mem → Prop}
    (hR : ∀ n ∈ ns, ∀ m₁ m₂, R n m₁ m₂ → P m₁ → R' n m₁ m₂ ∧ P m₂) (h0 : P m) :
    Turns R' ns m Es m' ∧ P m' := by
  induction h with
  | nil m => exact ⟨.nil m, h0⟩
  | cons hr e _ ih =>
    obtain ⟨hr', h1⟩ := hR _ List.mem_cons_self _ _ hr h0
    obtain ⟨ht, hP⟩ := ih (fun n hn => hR n (List.mem_cons_of_mem _ hn)) h1
    exact ⟨.cons hr' e ht, hP⟩

end MojoProof.Sym
