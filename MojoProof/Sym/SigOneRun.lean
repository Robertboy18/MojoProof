import GPUProof.Sound
import MojoProof.Sem.Sig
import MojoProof.Sem.ScheduleOwned
import MojoProof.Sym.SchedWait

/-!
# `OneRun sig`

For every program, kernel, launch, arguments, memory, address choice and oracle:

* `sig_reach_start`: the states reachable at `sig` from a start are the start's launch and
  contexts with a grid reachable from the start's.
* `sig_oneRun`, the instance `OneRun sig`: `Grid.confluent` (through `Grid.start_oneRun`) carried
  to `sig` by `Confluent.transfer` along `g ↦ (g, L, c)`, with the same bad sets (the core's `Bad`
  at `sig` at the grid's state).
-/

namespace MojoProof.Sem

open LLVM Relation

/-! ### The reachable states -/

/-- The states reachable at `sig` from a start are the start's launch and contexts with a grid
reachable from the start's, whose number of threads is the launch's, for every program, kernel,
launch, arguments, memory, address choice and oracle. -/
theorem sig_reach_start {P : Program × Func} {L : Launch} {args : List Val} {m : Mem}
    {ω : (Nat → Nat) × (Nat → Nat → Nat)} {s₀ s : sig.State}
    (h : sig.start P L args m ω = .ok s₀) (hr : GPUProof.Reach sig s₀ s) :
    ∃ g₀ g c, Grid.start P.1 P.2 L args m ω.1 ω.2 = .ok (g₀, c) ∧ s₀ = (g₀, L, c) ∧
      s = (g, L, c) ∧ ReflTransGen (Grid.Step L c) g₀ g ∧
      g.threads.size = volume L.grid * volume L.block := by
  cases hs : Grid.start P.1 P.2 L args m ω.1 ω.2 with
  | error => simp [sig, hs, Except.map] at h
  | ok r =>
    obtain ⟨g₀, c⟩ := r
    simp only [sig, hs, Except.map, Except.ok.injEq] at h
    subst h
    obtain ⟨g, rfl, hg⟩ := sig_reach_iff.1 hr
    exact ⟨g₀, g, c, rfl, rfl, rfl, hg, Grid.start_reach_size hs hg⟩

/-! ### `OneRun sig` -/

/-- **`OneRun sig`**, for every program, kernel, launch, arguments, memory every pointer byte of
whose blocks names a number below `next` or with a block (`sig.Closed`), address choice and
oracle: the steps between the states reachable from a good start are confluent up to `sig.Same`
with `Bad` persistent, from `Grid.start_oneRun` (whose premise is `sig.Closed`) carried by
`Confluent.transfer` along `g ↦ (g, L, c)` (onto by `sig_reach_iff`, steps by `sig_step_iff`,
the same bad sets); `sig.Same` keeps the threads and the blocks; a reachable done state
neither steps nor faults (`Grid.OneRun.done_final`, `Grid.OneRun.done_safe`). -/
instance sig_oneRun : GPUProof.OneRun sig where
  confluent {s₀} hg := by
    obtain ⟨P, L, args, m, ω, h, hm⟩ := hg
    cases hs : Grid.start P.1 P.2 L args m ω.1 ω.2 with
    | error => simp [sig, hs, Except.map] at h
    | ok r =>
      obtain ⟨g₀, c⟩ := r
      simp only [sig, hs, Except.map, Except.ok.injEq] at h
      subst h
      refine GPUProof.Confluent.transfer
        (f := fun x : {g // ReflTransGen (Grid.Step L c) g₀ g} =>
          (⟨(x.1, L, c), sig_reach_iff.2 ⟨x.1, rfl, x.2⟩⟩ : {s // GPUProof.Reach sig (g₀, L, c) s}))
        ?_ ?_ ?_ ?_ (Grid.start_oneRun hs hm).confluent
      · rintro ⟨s, hs'⟩
        obtain ⟨g, rfl, hg⟩ := sig_reach_iff.1 hs'
        exact ⟨⟨g, hg⟩, rfl⟩
      · intro a b
        show GPUProof.Step sig (a.1, L, c) (b.1, L, c) ↔ Grid.Step L c a.1 b.1
        rw [sig_step_iff]
        constructor
        · rintro ⟨g', e, hs'⟩
          rw [(Prod.mk.inj e).1]
          exact hs'
        · exact fun hs' => ⟨_, rfl, hs'⟩
      · intro a b
        exact ⟨fun h => h.2, fun h => ⟨rfl, h⟩⟩
      · intro a
        exact Iff.rfl
  same_done {s₀ s s'} _ _ he hd := by
    obtain ⟨g, L, c⟩ := s
    obtain ⟨g', L', c'⟩ := s'
    obtain ⟨e, hsame⟩ := he
    cases e
    refine ⟨fun n hn => ?_, fun j => j.elim⟩
    have h1 : sigStatus g n = .done := hd.1 n hn
    show sigStatus g' n = .done
    unfold sigStatus at h1 ⊢
    rw [← hsame.1]
    exact h1
  same_bytes _ _ he := he.2.2.1
  done_final {s₀ s s'} hs hd := by
    obtain ⟨⟨P, L, args, m, ω, h, hm⟩, hr⟩ := hs
    obtain ⟨g₀, g, c, hst, rfl, rfl, hg, -⟩ := sig_reach_start h hr
    intro hstep
    obtain ⟨g', -, hstep⟩ := sig_step_iff.1 hstep
    exact (Grid.start_oneRun hst hm).done_final hg hd hstep
  done_safe {s₀ s} hs hd := by
    obtain ⟨⟨P, L, args, m, ω, h, hm⟩, hr⟩ := hs
    obtain ⟨g₀, g, c, hst, rfl, rfl, hg, -⟩ := sig_reach_start h hr
    exact (Grid.start_oneRun hst hm).done_safe hg hd

end MojoProof.Sem
