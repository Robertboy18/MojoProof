import MojoProof.Sem.Bad

/-!
# Determinism: schedule independence, and one run for every schedule

For every program, kernel, launch, arguments, address choice and oracle, on a caller's memory
every pointer byte of whose blocks names a number below `next` or with a block (`Mem.BytesIn`):

- `Grid.confluent` (schedule independence, T2 in docs/proofs/schedule.md): the steps between grids
  reachable from the start's are confluent up to `Grid.Same` with the core's `Bad` at `sig`
  persistent (`Confluent`). Its parts: `Grid.Same.refl`, `Grid.Same.symm`, `Grid.Same.trans`,
  `Grid.Same.step` (`bisim`), `Grid.Same.bad` (`bad_eqv`, with the premises of `racy_iff` at both
  grids, `Grid.start_reach_fits`), `Grid.start_reach_bad` (`bad_step`) and the diamond: two steps
  of one thread give one grid; steps of two threads none of whose pending accesses conflict join
  (`Grid.start_reach_comm`), and if two conflict both grids after have a race enabled
  (`Grid.advance_raceEnabled`, with `Grid.start_reach_fits`); a step and a collective call that
  completes join (`Grid.start_reach_fire_comm`); two collective calls give one grid or join
  (`Grid.start_fire_fire_comm`).
- `Grid.start_sound` (one run decides every schedule; conclusion 2 of T2 in
  docs/proofs/schedule.md): for every observation that reads only the blocks, one run from the
  start's grid to a grid in which every thread has returned, that is not bad, and whose observation
  is defined and satisfies `R`, makes the start's grid sound (`Grid.Sound`), by
  `Grid.sound_of_one_run`. `Mem.tensor_blocks`: the observation of an output buffer (`Mem.tensor`)
  reads only the blocks.
- `Grid.Done.bad_iff`: a done grid (the core's `Done` at `sig`) with at most the launch's number of
  threads neither faults (`done_not_faults`) nor has a race enabled
  (`Grid.Done.not_raceEnabled`), so it is bad exactly when its trace is racy or breaks the promise
  of `!invariant.load` (every launch, contexts and grid).
- `Grid.start_refute` (a bad grid in one schedule makes every final grid bad; conclusion 3 of T2
  in docs/proofs/schedule.md): if some grid reachable from the start's is bad, so is every
  reachable grid without a step (`Confluent.bad_normal`). No schedule hides a fault, a race
  or a broken promise.

Lemma L3 of docs/proofs/schedule.md (the choices do not depend on the schedule) holds by
construction, with no Lean lemma: a thread's step reads its address choices and oracle values from
its own context (`Ctx.addr`, `Ctx.oracle`) at its own step count (`Thread.k`, `Ctx.scope`), so they
do not depend on the order of the steps of the threads.

Schedule independence under an ownership discipline (`Grid.confluent_owned`, T2′ in
docs/proofs/schedule-owned.md) is proved in `MojoProof/Sem/ScheduleOwned.lean`. Under its ownership
discipline every reachable grid's trace is race-free and keeps the promises of `!invariant.load`
(`Grid.owned_clean`), and a reachable grid with an enabled race faults (`Grid.owned_race`: the
racing thread's step is a fault). An enabled race is not excluded: a thread's pending accesses are
listed before they are checked, so a pending access that conflicts with another thread's may be one
whose step faults.
-/

namespace MojoProof.Sem

open MojoProof.LLVM Relation TorchLean
open GPUProof

/-- **Schedule independence (T2 in docs/proofs/schedule.md).** For every program, kernel, launch,
arguments, address choice and oracle, on a caller's memory every pointer byte of whose blocks names
a number below `next` or with a block: the steps between grids reachable from the start's are
confluent up to `Grid.Same`, with the core's `Bad` at `sig` persistent. -/
theorem Grid.confluent {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known) :
    Confluent (fun x y : {g // ReflTransGen (Grid.Step L c) g₀ g} => Grid.Step L c x.1 y.1)
      (fun x y => x.1.Same y.1) (fun x => GPUProof.Bad sig (x.1, L, c)) where
  refl x := .refl x.1
  symm := Grid.Same.symm
  trans := Grid.Same.trans
  bisim {_ x' _} he hs := by
    obtain ⟨g', hs', he'⟩ := he.step hs
    exact ⟨⟨g', x'.2.tail hs'⟩, hs', he'⟩
  bad_eqv {x y} he hb :=
    Grid.Same.bad he (Grid.start_reach_fits h x.2) (Grid.start_reach_fits h y.2) hb
  bad_step {x _} hb hs := Grid.start_reach_bad h hm x.2 hs hb
  diamond := by
    rintro ⟨g, hg⟩ ⟨gn, hgn⟩ ⟨gk, hgk⟩ ⟨n, hn | hn⟩ ⟨k, hk | hk⟩
    · by_cases hnk : n = k
      · subst hnk
        rw [hn] at hk
        cases hk
        exact .inl (.refl _)
      by_cases hW : ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
          a.conflict a' = false
      · obtain ⟨g₁, g₂, h₁, h₂, he⟩ := Grid.start_reach_comm h hm hg hnk hn hk hW
        exact .inr (.inr ⟨⟨g₁, hgn.tail ⟨k, .inl h₁⟩⟩, ⟨g₂, hgk.tail ⟨n, .inl h₂⟩⟩, ⟨k, .inl h₁⟩,
          ⟨n, .inl h₂⟩, .inl he⟩)
      simp only [not_forall, Bool.not_eq_false] at hW
      obtain ⟨a, a', ha, ha', hc⟩ := hW
      obtain ⟨tn, -, -, htn, -⟩ := Grid.advance_set hn
      obtain ⟨tk, -, -, htk, -⟩ := Grid.advance_set hk
      have hcl := Grid.start_reach_closed h hm hg
      have hw : (c n).who.thread ≠ (c k).who.thread := by
        rw [(Grid.start_ctx h n).2.1, (Grid.start_ctx h k).2.1]
        exact hnk
      exact .inr (.inl ⟨.inr (.inr (.inr (Grid.advance_raceEnabled hcl
        (Grid.start_reach_fits h hgn) hw.symm htk hn ha' ha
        ((Access.conflict_comm _ _).trans hc)))),
        .inr (.inr (.inr (Grid.advance_raceEnabled hcl (Grid.start_reach_fits h hgk) hw htn hk ha
          ha' hc)))⟩)
    · obtain ⟨g₁, g₂, h₁, h₂, he⟩ := Grid.start_reach_fire_comm h hg hn hk
      exact .inr (.inr ⟨⟨g₁, hgn.tail ⟨k, .inr h₁⟩⟩, ⟨g₂, hgk.tail ⟨n, .inl h₂⟩⟩, ⟨k, .inr h₁⟩,
        ⟨n, .inl h₂⟩, .inl he⟩)
    · obtain ⟨g₁, g₂, h₁, h₂, he⟩ := Grid.start_reach_fire_comm h hg hk hn
      exact .inr (.inr ⟨⟨g₂, hgn.tail ⟨k, .inl h₂⟩⟩, ⟨g₁, hgk.tail ⟨n, .inr h₁⟩⟩, ⟨k, .inl h₂⟩,
        ⟨n, .inr h₁⟩, .inl he.symm⟩)
    · rcases Grid.start_fire_fire_comm h hn hk with rfl | ⟨g₁, g₂, h₁, h₂, he⟩
      · exact .inl (.refl _)
      · exact .inr (.inr ⟨⟨g₁, hgn.tail ⟨k, .inr h₁⟩⟩, ⟨g₂, hgk.tail ⟨n, .inr h₂⟩⟩, ⟨k, .inr h₁⟩,
          ⟨n, .inr h₂⟩, .inl he⟩)

/-- **One run decides every schedule (conclusion 2 of T2 in docs/proofs/schedule.md).** For every
program, kernel, launch, arguments, address choice and oracle, on a caller's memory every pointer
byte of whose blocks names a number below `next` or with a block, and every observation `obs` that
reads only the blocks: one run of `n` steps from the start's grid to a grid `z` in which every
thread has returned, that is not bad, and whose observation is `y` with `R y`, makes the start's
grid sound (`Grid.Sound`: no reachable grid faults, has a racy trace or breaks the promise of
`!invariant.load`; every reachable grid in which some thread has not returned has a step; every run
is finite; and every reachable grid in which every thread has returned observes `y`). -/
theorem Grid.start_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {n : Nat} {z : Grid} (run : Path (Grid.Step L c) n g₀ z) (hz : GPUProof.Done sig (z, L, c))
    (hb : ¬ GPUProof.Bad sig (z, L, c)) {y : β} (hy : obs z.mem = some y) (hR : R y) :
    Grid.Sound L c g₀ obs R := by
  obtain ⟨_, hp⟩ := run.lift .refl
  exact Grid.sound_of_one_run (π := Subtype.val) (Grid.confluent h hm) (fun hs => hs)
    (fun {x g'} hs => ⟨⟨g', x.2.tail hs⟩, hs, rfl⟩) (fun _ => .inl) (fun _ => (.inr <| .inl ·))
    (fun _ => (.inr <| .inr <| .inl ·))
    (fun {x _} => Grid.Done.final (Grid.start_reach_size h x.2).le)
    (fun he hd => by rw [Grid.done_iff] at *; rwa [← he.1]) (fun he => hO _ _ he.2.1) hp hz hb
    hy hR

/-- **Refutation transfer (conclusion 3 of T2 in docs/proofs/schedule.md).** For every program,
kernel, launch, arguments, address choice and oracle, on a caller's memory every pointer byte of
whose blocks names a number below `next` or with a block: if some grid reachable from the start's is
bad (a fault, a racy trace, a broken promise of `!invariant.load` or an enabled race in one
schedule), so is every reachable grid without a step. -/
theorem Grid.start_refute {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {b z : Grid} (hb : ReflTransGen (Grid.Step L c) g₀ b) (hB : GPUProof.Bad sig (b, L, c))
    (hz : ReflTransGen (Grid.Step L c) g₀ z) (hn : ∀ g, ¬ Grid.Step L c z g) :
    GPUProof.Bad sig (z, L, c) := by
  obtain ⟨_, hb⟩ := Path.exists_iff.2 hb
  obtain ⟨_, hz⟩ := Path.exists_iff.2 hz
  obtain ⟨_, hb⟩ := hb.lift .refl
  obtain ⟨_, hz⟩ := hz.lift .refl
  exact (Grid.confluent h hm).bad_normal (Path.exists_iff.1 ⟨_, hb⟩) hB
    (Path.exists_iff.1 ⟨_, hz⟩) fun x => hn x.1

/-- In a done grid with at most the launch's number of threads no race is enabled (the core's
`RaceEnabled` at `sig`), for every launch and contexts: no thread runs and no collective call
completes. -/
theorem Grid.Done.not_raceEnabled {L : Launch} {c : Nat → Ctx} {g : Grid}
    (hs : g.threads.size ≤ volume L.grid * volume L.block) (h : GPUProof.Done sig (g, L, c)) :
    ¬ GPUProof.RaceEnabled sig (g, L, c) := by
  intro he
  rcases Grid.raceEnabled_iff.1 he with ⟨n, t, ht, -⟩ | ⟨n, g', hf, -⟩
  · rcases Grid.Done.get hs h n with hn | hn <;> simp [hn] at ht
  · rcases Grid.Done.get hs h n with hn | hn <;> simp [Grid.fire, hn, pure, Except.pure] at hf

/-- **A done grid is bad only by its trace.** For every launch, contexts and done grid with at
most the launch's number of threads: the grid is bad exactly when its trace is racy or breaks the
promise of `!invariant.load`, since it neither faults (`done_not_faults`) nor has a race enabled
(`Grid.Done.not_raceEnabled`). -/
theorem Grid.Done.bad_iff {L : Launch} {c : Nat → Ctx} {g : Grid}
    (hs : g.threads.size ≤ volume L.grid * volume L.block) (h : GPUProof.Done sig (g, L, c)) :
    GPUProof.Bad sig (g, L, c) ↔
      GPUProof.racy sig (g.mem.trace.map (Event.toCore L)).reverse = true ∨
      GPUProof.kept sig (g.mem.trace.map (Event.toCore L)).reverse = false :=
  ⟨fun hb => (hb.resolve_left (done_not_faults hs h)).imp_right
      fun hb => hb.resolve_right (Grid.Done.not_raceEnabled hs h),
    fun hb => .inr (hb.imp_right .inl)⟩

/-- The observation of an output buffer reads only the blocks: for every layout, block number,
type, encoding and offsets, memories with the same blocks observe the same tensor. -/
theorem Mem.tensor_blocks {α : Type} {s : Shape} {l : Layout} {t : Ty} {enc : α → Val}
    {off : Shape.Coord s → Nat} {m m' : Mem} (b : Nat) (h : m.blocks = m'.blocks) :
    m.tensor l b t enc off = m'.tensor l b t enc off := by
  unfold Mem.tensor Mem.Holds
  rw [h]

end MojoProof.Sem
