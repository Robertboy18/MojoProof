import GPUProof.Transfer
import MojoProof.Sem.Determinism

/-!
# T2′: schedule independence under an ownership discipline

docs/proofs/schedule-owned.md, by its route in Lean: T2 (`Grid.confluent`) with its bad set
replaced by the faults. A discipline is a tiling map `T` and a tile map `own` (`Owned`,
MojoProof/Sem/Trace.lean). Its hypotheses, on the grids reachable from the start's: every access
that a thread `n` would log (`Grid.pending`) follows the discipline or is to a block that `n` owns
(`Mem.Owned`, `hH`); every such access with `!invariant.load` is to an untiled block that no
thread owns (`hI`); and `own` is injective on the thread numbers of the start's grid (`hX`).

For every program, kernel, launch, arguments, address choice, oracle and discipline:

- `Grid.owned_reach`: under `hH` and `hI`, in every grid reachable from the start's, every thread
  number is one of the start's, and every access of the trace is by such a thread, to a block of
  the memory whose owner admits it, follows the discipline or is to a block its thread owns, and,
  with `!invariant.load`, is to an untiled block that no thread owns. `Trace.Shaped.writes`: in a
  shaped trace (`Trace.Shaped`, as every reachable grid's is, `Grid.start_reach_shaped` in
  MojoProof/Sem/Bad.lean) an access that writes for the core (`GPUProof.Kind.writes`) has a
  write at its pointer.
- `Grid.owned_clean` (conclusion 2's trace part): under `hH`, `hI` and `hX`, no reachable grid has
  a racy trace or breaks the promise of `!invariant.load`. Its trace lemma,
  `racy_eq_false_of_local` (every launch and trace with the premises of `racy_iff`, as a
  reachable grid's has, `Grid.start_reach_fits`): accesses that follow the discipline or are to a
  block local to their thread, with `own` injective on the threads of one tiled block, do not
  race.
- `Grid.owned_race` (conclusion 2's race part): a reachable grid with a race enabled faults.
- `Grid.owned_bad`: so a reachable grid that is bad faults; with the converse (every grid),
  on reachable grids the core's `Bad` at `sig` is the core's `GPUProof.Faults` at `sig`.
- `Grid.confluent_owned` (T2′, conclusion 1), on a caller's memory every pointer byte of whose
  blocks names a number below `next` or with a block: the steps between grids reachable from the
  start's are confluent up to `Grid.Same` with the faults (`GPUProof.Faults` at `sig`)
  persistent. It is `Grid.confluent` with `Confluent.transfer` along the identity (two bad sets
  with the same members).

- `Grid.owned_sound` (conclusion 3, one run for all), on such a memory and for every observation
  that reads only the blocks: one run from the start's grid to a grid in which every thread has
  returned, whose trace meets the premises of `racy_kept_of_local`, and whose observation is
  defined and satisfies `R`, makes the start's grid sound (`Grid.Sound`). Its trace lemma,
  `racy_kept_of_local` (every launch and trace with the premises of `racy_iff`): under the
  premises of `racy_eq_false_of_local`, with no access with `!invariant.load` to a block that a
  write of the trace touches, the trace is not racy and keeps the promise of `!invariant.load`
  (the core's `GPUProof.kept` at `sig`). It asks the discipline
  of the done grid's trace only, not of every reachable grid (`hH`, `hI`).

The instance (two threads, each storing to its own `alloca`) and the twin (one thread, an
`!invariant.load` and then a store to its bytes, which no discipline meets) are in
MojoProofTest/ScheduleOwned.lean, one kernel each.
-/

namespace MojoProof.Sem

open MojoProof.LLVM Relation
open GPUProof

/-- **Ownership with thread-local blocks gives race freedom** (the core's `racy` at `sig`, for
every launch and trace whose accesses are by threads of the launch in their blocks of threads and
that is shaped, the premises of `racy_iff`). `loc b w` says that block `b` is local to thread
`w`. If every access of the trace to a block local to no thread follows the discipline
`(T, own)`, every access to a block local to `w` is by `w`, and threads that access one tiled
block have different tiles, the trace has no race. -/
theorem racy_eq_false_of_local {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {loc : Nat → Nat → Prop} {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hO : ∀ a, Event.access a ∈ tr → (∀ w, ¬ loc a.ptr.block w) → Owned T own a)
    (hL : ∀ a w, Event.access a ∈ tr → loc a.ptr.block w → a.who.thread = w)
    (hX : ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
        a.who.thread = e.who.thread) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  cases h : GPUProof.racy sig (tr.map (Event.toCore L)).reverse
  · rfl
  obtain ⟨x, hx, y, hy, hc⟩ := (racy_iff hU hs).1 h
  simp only [clash, Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.or_eq_true, beq_iff_eq] at hc
  obtain ⟨⟨ht, hc⟩, -⟩ := hc
  have hb : x.1.ptr.block = y.1.ptr.block := by
    by_contra hb
    simp [Access.conflict, Access.overlaps, hb] at hc
  have hx' := mem_phases hx
  have hy' := mem_phases hy
  by_cases hl : ∃ w, loc x.1.ptr.block w
  · obtain ⟨w, hl⟩ := hl
    exact absurd ((hL _ w hx' hl).trans (hL _ w hy' (by rw [← hb]; exact hl)).symm) ht
  · have hl := not_exists.1 hl
    have := (hO _ hx' hl).apart (hO _ hy' (by rw [← hb]; exact hl))
      (fun hb' hT ho => ht (hX _ _ hx' hy' hb' hT ho))
      (by simp only [Access.conflict, Bool.and_eq_true] at hc; exact hc.1.1)
    simp [Access.conflict, this] at hc

/-- **An access that writes for the core has a write at its pointer** in every trace `tr` (newest
first) whose reverse is shaped, for every access `e` of `tr` that writes for the core
(`Kind.writes`): `e` writes, or it is an `atomicrmw`'s read and its write, the same access with
`write` set, is in `tr`. -/
theorem Trace.Shaped.writes {tr : List Event} (hs : Trace.Shaped tr.reverse) {e : Access}
    (he : Event.access e ∈ tr) (hw : e.kind.writes = true) :
    ∃ e', Event.access e' ∈ tr ∧ e'.write = true ∧ e'.ptr = e.ptr := by
  rw [Access.kind_writes] at hw
  cases hwr : e.write
  · rw [hwr, Bool.false_or] at hw
    obtain ⟨p, hp⟩ := List.getElem?_of_mem (List.mem_reverse.2 he)
    exact ⟨{ e with write := true },
      List.mem_reverse.1 (List.mem_of_getElem? (hs.2 p e hp hw hwr)), rfl, rfl⟩
  · exact ⟨e, he, hwr, rfl⟩

/-- **The trace lemma of conclusion 3 of T2′** (every launch and trace whose accesses are by
threads of the launch in their blocks of threads and whose reverse is shaped, `Trace.Shaped`):
under the premises of `racy_eq_false_of_local`, and if no access with `!invariant.load` is to a
block that a write of the trace touches, the trace is not racy and keeps the promise of
`!invariant.load` (the core's `kept` at `sig`; an `atomicrmw`'s read has its write in the trace,
`Trace.Shaped.writes`). -/
theorem racy_kept_of_local {L : Launch} {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {loc : Nat → Nat → Prop} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hO : ∀ a, Event.access a ∈ tr → (∀ w, ¬ loc a.ptr.block w) → Owned T own a)
    (hL : ∀ a w, Event.access a ∈ tr → loc a.ptr.block w → a.who.thread = w)
    (hX : ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
        a.who.thread = e.who.thread)
    (hI : ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.invariant = true →
      e.write = true → a.ptr.block ≠ e.ptr.block) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false ∧
      GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true :=
  ⟨racy_eq_false_of_local hU hs hO hL hX,
    kept_of_split (W := fun b => ∃ e, Event.access e ∈ tr ∧ e.write = true ∧ e.ptr.block = b)
      (fun a ha hi ⟨e, he, hw, hb⟩ => hI a e ha he hi hw hb.symm)
      fun e he hw => by
        obtain ⟨e', he', hw', hp⟩ := hs.writes he hw
        exact ⟨e', he', hw', by rw [hp]⟩⟩

section Owned

variable {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
  {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx} {ι : Type} {T : Nat → Option (Tiling ι)}
  {own : Nat → ι}

/-- The invariant of conclusion 2 of T2′, for every program, kernel, launch, arguments, memory,
choices and discipline `(T, own)` that meets `hH` and `hI` on the grids reachable from the start's:
in every reachable grid, every thread number is one of the start's grid, and every access of the
trace is by such a thread, to a block of the memory whose owner admits it, follows the discipline
or is to a block that its thread owns, and, with `!invariant.load`, is to an untiled block that no
thread owns. -/
theorem Grid.owned_reach (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hH : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block)
    (hI : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block)
    {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) :
    (∀ (j : Nat) s, g.threads[j]? = some s → j < g₀.threads.size) ∧
      ∀ a, .access a ∈ g.mem.trace → a.who.thread < g₀.threads.size ∧
        ∃ x, g.mem.blocks a.ptr.block = some x ∧ x.owner.admits a.who = true ∧
          (Owned T own a ∨ x.owner = .thread a.who.thread) ∧
          (a.invariant = true → T a.ptr.block = none ∧ ∀ w, x.owner ≠ .thread w) := by
  induction hr with
  | refl =>
    refine ⟨fun j s hj => ?_, fun a ha => ?_⟩
    · by_contra hj'
      rw [Array.getElem?_eq_none (Nat.le_of_not_lt hj')] at hj
      cases hj
    · rw [Grid.start_trace h] at ha
      cases ha
  | @tail g g' hr hs ih =>
    obtain ⟨hT, hA⟩ := ih
    obtain ⟨n, hn | hn⟩ := hs
    · obtain ⟨t, s, m', ht, rfl, htr, -⟩ := Grid.advance_set hn
      obtain ⟨_, -, hold⟩ := (Grid.start_reach_changes h hr ht hn).old
      have hnt : n < g₀.threads.size := hT n _ ht
      refine ⟨set!_inv (P := fun j _ => j < g₀.threads.size) hT hnt, fun a ha => ?_⟩
      change .access a ∈ m'.trace at ha
      rw [htr] at ha
      rcases List.mem_append.1 ha with ha | ha
      · obtain ⟨x, hx, hadm⟩ := Grid.advance_admits hn a ha
        obtain ⟨x', hx', -, hown, -⟩ := hold _ x hx
        have hwa : a.who.thread = n := by rw [Grid.pending_who ha, (Grid.start_ctx h n).2.1]
        rw [← Grid.pending_who ha] at hadm
        refine ⟨by rw [hwa]; exact hnt, x', hx', by rw [hown]; exact hadm, ?_, fun hi => ?_⟩
        · rcases hH g hr n a ha with ho | ⟨y, hy, hyo⟩
          · exact .inl ho
          · rw [hx] at hy
            cases hy
            exact .inr (by rw [hown, hyo, hwa])
        · obtain ⟨hTn, hno⟩ := hI g hr n a ha hi
          refine ⟨hTn, fun w hw => hno ⟨x, hx, ?_⟩⟩
          rw [hown] at hw
          rw [hw] at hadm
          have e : a.who.thread = w := by simpa [Owner.admits] using hadm
          rw [hw, ← e, hwa]
      · obtain ⟨hlt, x, hx, hadm, hO, hi⟩ := hA a ha
        obtain ⟨x', hx', -, hown, -⟩ := hold _ x hx
        exact ⟨hlt, x', hx', by rw [hown]; exact hadm, by rw [hown]; exact hO,
          by rw [hown]; exact hi⟩
    · obtain ⟨-, i, -, -, -, htr⟩ := Grid.fire_trace hn
      refine ⟨fun j s hj => ?_, fun a ha => ?_⟩
      · obtain ⟨s', hs'⟩ := Grid.fire_threads hn j s hj
        exact hT j s' hs'
      · rw [htr] at ha
        have ha' : .access a ∈ g.mem.trace := by
          rcases List.mem_append.1 ha with ha | ha
          · split at ha <;> simp at ha
          · exact ha
        rw [(Grid.fire_blocks hn).1]
        exact hA a ha'

/-- **Conclusion 2 of T2′, the trace.** For every program, kernel, launch, arguments, memory,
choices and discipline `(T, own)` that meets `hH` and `hI` on the grids reachable from the start's
and whose `own` is injective on the start grid's thread numbers (`hX`): no reachable grid has a
racy trace or breaks the promise of `!invariant.load`. -/
theorem Grid.owned_clean (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hH : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block)
    (hI : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block)
    (hX : ∀ n k, n < g₀.threads.size → k < g₀.threads.size → own n = own k → n = k)
    {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) :
    GPUProof.racy sig (g.mem.trace.map (Event.toCore L)).reverse = false ∧
      GPUProof.kept sig (g.mem.trace.map (Event.toCore L)).reverse = true := by
  have hA := (Grid.owned_reach h hH hI hr).2
  have hf := Grid.start_reach_fits h hr
  have hsh := hf.2
  refine ⟨racy_eq_false_of_local (T := T) (own := own) (loc := fun b w => g.mem.Owned w b)
    hf.trace hsh (fun a ha hl => ?_) (fun a w ha hl => ?_)
    (fun a e ha he _ _ ho => hX _ _ (hA a ha).1 (hA e he).1 ho),
    kept_of_split (W := fun b => T b ≠ none ∨ ∃ w, g.mem.Owned w b) (fun a ha hi => ?_)
      fun e he hw => ?_⟩
  · obtain ⟨-, x, hx, -, ho, -⟩ := hA a ha
    exact ho.resolve_right fun ho => hl _ ⟨x, hx, ho⟩
  · obtain ⟨-, x, hx, hadm, -, -⟩ := hA a ha
    obtain ⟨y, hy, hyo⟩ := hl
    rw [hx] at hy
    cases hy
    simpa [Owner.admits, hyo] using hadm
  · obtain ⟨-, x, hx, -, -, hI'⟩ := hA a ha
    obtain ⟨hTn, hno⟩ := hI' hi
    rintro (hT | ⟨w, y, hy, hyo⟩)
    · exact hT hTn
    · rw [hx] at hy
      cases hy
      exact hno w hyo
  · obtain ⟨e', he', hw', hp⟩ := hsh.writes he hw
    rw [← hp]
    obtain ⟨-, x, hx, -, ho | ho, -⟩ := hA e' he'
    · exact Or.inl fun hT => by rw [ho.read hT] at hw'; cases hw'
    · exact Or.inr ⟨_, x, hx, ho⟩

/-- **Conclusion 2 of T2′, the enabled race.** Under the hypotheses of `Grid.owned_clean`, a
reachable grid with a race enabled (the core's `RaceEnabled` at `sig`) faults: the step of the
racing thread is a fault, since if it succeeded the grid after would be reachable with a racy
trace; a race enabled by a collective call that completes needs a racy trace, which no reachable
grid has. -/
theorem Grid.owned_race (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hH : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block)
    (hI : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block)
    (hX : ∀ n k, n < g₀.threads.size → k < g₀.threads.size → own n = own k → n = k)
    {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) (hE : GPUProof.RaceEnabled sig (g, L, c)) :
    GPUProof.Faults sig (g, L, c) := by
  rcases Grid.raceEnabled_iff.1 hE with ⟨n, t, ht, hR⟩ | ⟨-, -, -, hR⟩
  swap
  · exact nomatch (Grid.owned_clean h hH hI hX hr).1.symm.trans hR
  match hA : g.advance c n with
  | .error e => exact Grid.faults_iff.2 ⟨n, e, .inl hA⟩
  | .ok none => exact absurd hA (Grid.advance_run ht)
  | .ok (some g') =>
    have hc := (Grid.owned_clean h hH hI hX (hr.tail ⟨n, .inl hA⟩)).1
    obtain ⟨-, _, m', -, rfl, htr, -⟩ := Grid.advance_set hA
    have hp : g.pending c n = t.pending (c n) g.mem := by simp only [Grid.pending, ht]
    change GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false at hc
    rw [htr, hp, hR] at hc
    cases hc

/-- Under the hypotheses of `Grid.owned_clean`, a reachable grid that is bad (the core's `Bad` at
`sig`) faults; the converse holds for every grid (`Or.inl`). -/
theorem Grid.owned_bad (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hH : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block)
    (hI : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block)
    (hX : ∀ n k, n < g₀.threads.size → k < g₀.threads.size → own n = own k → n = k)
    {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) (hb : GPUProof.Bad sig (g, L, c)) :
    GPUProof.Faults sig (g, L, c) := by
  obtain ⟨hR, hK⟩ := Grid.owned_clean h hH hI hX hr
  rcases hb with hf | hb | hb | hb
  · exact hf
  · exact nomatch hR.symm.trans hb
  · exact nomatch hK.symm.trans hb
  · exact Grid.owned_race h hH hI hX hr hb

/-- **T2′.** For every program, kernel, launch, arguments, address choice and oracle, on a
caller's memory every pointer byte of whose blocks names a number below `next` or with a block,
and every discipline `(T, own)` that meets `hH`, `hI` and `hX`: the steps between grids reachable
from the start's are confluent up to `Grid.Same`, with the faults (`GPUProof.Faults` at `sig`)
persistent. -/
theorem Grid.confluent_owned (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known)
    (hH : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block)
    (hI : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block)
    (hX : ∀ n k, n < g₀.threads.size → k < g₀.threads.size → own n = own k → n = k) :
    Confluent (fun x y : {g // ReflTransGen (Grid.Step L c) g₀ g} => Grid.Step L c x.1 y.1)
      (fun x y => x.1.Same y.1) (fun x => GPUProof.Faults sig (x.1, L, c)) :=
  (Grid.confluent h hm).transfer Function.surjective_id (fun _ _ => .rfl) (fun _ _ => .rfl)
    fun x => ⟨Or.inl, Grid.owned_bad h hH hI hX x.2⟩

/-- **Conclusion 3 of T2′: one run for all.** For every program, kernel, launch, arguments,
address choice, oracle and discipline `(T, own)`, on a caller's memory every pointer byte of whose
blocks names a number below `next` or with a block, and every observation `obs` that reads only
the blocks: one run of `n` steps from the start's grid to a grid `z` in which every thread has
returned, whose trace meets the premises of `racy_kept_of_local` (every access follows the
discipline or is to a block local to its thread, `own` is injective on the threads of one tiled
block, and no access with `!invariant.load` is to a block that a write touches), and whose
observation is `y` with `R y`, makes the start's grid sound (`Grid.Sound`). By `Grid.start_sound`:
`z` is not bad, as a done grid is bad only by its trace (`Grid.Done.bad_iff`). -/
theorem Grid.owned_sound (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {n : Nat} {z : Grid} (run : Path (Grid.Step L c) n g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {loc : Nat → Nat → Prop}
    (hO : ∀ a, Event.access a ∈ z.mem.trace → (∀ w, ¬ loc a.ptr.block w) → Owned T own a)
    (hL : ∀ a w, Event.access a ∈ z.mem.trace → loc a.ptr.block w → a.who.thread = w)
    (hX : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.ptr.block = e.ptr.block → T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
        a.who.thread = e.who.thread)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  Grid.start_sound h hm hB run hz (fun hb => by
    have hf := Grid.start_reach_fits h (Path.exists_iff.1 ⟨_, run⟩)
    obtain ⟨hr, hk⟩ := racy_kept_of_local hf.trace hf.2 hO hL hX hI
    rw [Grid.Done.bad_iff (Grid.start_reach_size h (Path.exists_iff.1 ⟨_, run⟩)).le hz, hr, hk]
      at hb
    simp at hb) hy hR

end Owned

end MojoProof.Sem
