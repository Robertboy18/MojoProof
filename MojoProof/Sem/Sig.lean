import GPUProof.Laminar
import GPUProof.Run
import MojoProof.Sem.Embed

/-!
# MojoProof's signature

The lemmas of `sig`, MojoProof's machine as a machine of the core (`GPUProof.Sig`), with every
field filled by MojoProof's own definitions. MojoProof/Sem/SigDef.lean defines `sig` and its
parts, below MojoProof/Sem/Spec.lean; docs/proofs/sig.md has the table of fields and where each
one comes from.

* A state is `(g, L, c)`: a grid, its launch and its contexts, which no step changes. The
  threads of launch `L` are `List.range (volume L.grid * volume L.block)`; there are no jobs.
* The levels are `Fin 4`: a thread, a warp, a block of threads, the grid. A level instance is a
  level and a number (`Launch.groupNum`), its members are `Launch.members`.
* A byte is a block number and an offset; a buffer is a block number; the memory is the blocks.
* The trace is the grid's trace, oldest first: `(g.mem.trace.map (Event.toCore L)).reverse`.
  `Event.toCore L` maps a barrier of block `b` to the rendezvous of block `b`'s threads at
  object `b`, and an access to its block, offset, length and kind (`Access.kind`), by its
  thread. A thread's pending events are reversed the same way, so that a step appends them
  (`sig_advance_logs`, `sig_fire_logs`).
* A step is a grid step with `(L, c)` kept (`sig_advance`, `sig_fire`, `sig_step_iff`), and the
  states reachable at `sig` are the grids reachable by `Grid.Step` (`sig_reach_iff`). These four
  are in MojoProof/Sem/Spec.lean, with `Grid.Sound.of_clean`, which uses them, below
  `Grid.sound_of_one_run` (MojoProof/Sem/Trace.lean).

The transport lemmas here: `sig_cta` (the accesses of a reachable state's trace, with a thread's
pending events or a fire's, are by threads in their blocks) and `sig_obs` (an observation that
reads only the blocks is an observation of `sig.Bytes`).

Decidable equality of values (`Val.decEq`) and of LLVM types (`Ty.decEq`, so of intrinsics) is
defined in MojoProof/Sem/SigDef.lean, by structural recursion, since `deriving` does not apply to
the nested types.
-/

namespace MojoProof.Sem

open LLVM Relation

/-! ### A step appends its pending events -/

/-- **A thread's step appends its pending events**, oldest first as the core's traces are, for
every state, thread and next state: from `Grid.advance_set`, since the grid logs its pending
events newest first in front of its trace, and `sig` reverses both. -/
theorem sig_advance_logs {s s' : sig.State} {n : Nat}
    (h : sig.advance s (.thread n) = .ok (some s')) :
    sig.trace s' = sig.trace s ++ sig.pending s (.thread n) := by
  obtain ⟨g, L, c⟩ := s
  rw [sig_advance] at h
  cases hg : g.advance c n with
  | error => simp [hg, Except.map] at h
  | ok o =>
    rcases o with _ | g' <;> simp [hg, Except.map] at h
    subst h
    obtain ⟨t, st, m, -, rfl, htr, -⟩ := Grid.advance_set hg
    simp [htr]

/-- **A completed call appends its fire's pending events** (`firePending`), for every state,
thread and next state: from `Grid.fire_frame`, since the grid logs `Grid.fired` in front of its
trace. -/
theorem sig_fire_logs {s s' : sig.State} {n : Nat} (h : sig.fire s n = .ok (some s')) :
    sig.trace s' = sig.trace s ++ sig.firePending s n := by
  obtain ⟨g, L, c⟩ := s
  rw [sig_fire] at h
  cases hg : g.fire L c n with
  | error => simp [hg, Except.map] at h
  | ok o =>
    rcases o with _ | g' <;> simp [hg, Except.map] at h
    subst h
    obtain ⟨_, _, _, _, _, hm, _⟩ := Grid.fire_frame hg
    simp [hm]

/-! ### The transport lemmas -/

/-- **The accesses of a reachable state are by threads in their blocks**, for every program,
kernel, launch, arguments, memory, address choice and oracle: at every state `(g, L', c)`
reachable at `sig` from the start, `L'` is the launch, and for every thread number `n`, every
access of the trace with `n`'s pending accesses in front, or with the barrier of `n`'s
collective call in front, is by a thread of the grid whose block of threads is its `who.cta`
(`Grid.ByThreads`). -/
theorem sig_cta {P : Program × Func} {L : Launch} {args : List Val} {m : Mem}
    {ω : (Nat → Nat) × (Nat → Nat → Nat)} {s₀ s : sig.State} (h : sig.start P L args m ω = .ok s₀)
    (hr : GPUProof.Reach sig s₀ s) (n : Nat) :
    s.2.1 = L ∧ (s.1.retrace (s.1.pending s.2.2 n ++ s.1.mem.trace)).ByThreads L ∧
      (s.1.retrace (s.1.fired L n ++ s.1.mem.trace)).ByThreads L := by
  cases hs : Grid.start P.1 P.2 L args m ω.1 ω.2 with
  | error => simp [sig, hs, Except.map] at h
  | ok r =>
    obtain ⟨g₀, c⟩ := r
    simp only [sig, hs, Except.map, Except.ok.injEq] at h
    subst h
    obtain ⟨g, rfl, hg⟩ := sig_reach_iff.1 hr
    exact ⟨rfl, Grid.start_reach_pending hs hg n⟩

/-- **An observation that reads only the blocks is an observation of `sig.Bytes`**, for every
observation of a memory that two memories with the same blocks give the same value: at every
state, it is the observation of the memory with the state's blocks (`sig.bytes`) and nothing
else (`Mem.obs_blocks`). -/
theorem sig_obs {β : Type} {obs : Mem → Option β}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (s : sig.State) :
    obs s.1.mem = obs { blocks := sig.bytes s } :=
  Mem.obs_blocks.1 hO s.1.mem

end MojoProof.Sem
