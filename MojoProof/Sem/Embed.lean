import MojoProof.Sem.Determinism

/-!
# MojoProof's side of Theorem 0 at the grid (docs/proofs/theorem0.md)

The facts about MojoProof's grid that the core's Theorem 0 needs to give `Grid.start_sound` at
MojoProof's signature, stated without the signature (docs/proofs/theorem0.md names the core's
statement each one serves). Each holds for every program, kernel, launch, arguments, memory,
address choice and oracle, on every grid reachable from the grid that `Grid.start` gives; those
that name no start hold for every launch, contexts and grid.

* The number of threads: every grid reachable from the start's has
  `volume L.grid * volume L.block` threads (`Grid.start_reach_size`, in `MojoProof.Sem.Bad`), so
  the core's `Done` at it reads every thread (`Grid.done_iff`, in `MojoProof.Sem.Spec`).
* For the core's blocks of threads: the trace with any thread's pending accesses in front, or
  with the barrier of its collective call in front, has every access by a thread of the grid, in
  that thread's block of threads (`Grid.start_reach_pending`, in `MojoProof.Sem.Bad`; the trace
  alone is W4, `Grid.start_reach_byThreads`).
* For the core's observation of the bytes: an observation that reads only the blocks is the
  observation of the memory with the same blocks and nothing else (`Mem.obs_blocks`).
* For the core's bad states: the core's enabled race at `sig`, at the grid
  (`Grid.raceEnabled_iff`, in `MojoProof.Sem.Bad`).
* `Grid.OneRun`, the five fields of the core's `OneRun` at the grid, and `Grid.start_oneRun`,
  which proves them from `Grid.confluent` on a caller's memory whose pointer bytes name known
  numbers (`Mem.Closed.bytesIn` gives that premise from a closed memory).
-/

namespace MojoProof.Sem

open MojoProof.LLVM Relation GPUProof

/-- **An observation that reads only the blocks is a function of them** (for the core's
observation of the bytes), for every type `β` and observation `obs` of memories:
`Grid.start_sound`'s premise on `obs` holds exactly when `obs m` is `obs` of the memory with
`m`'s blocks and the default `next` and trace. So the observation of the blocks `bs` is
`obs { blocks := bs }`. -/
theorem Mem.obs_blocks {β : Type} {obs : Mem → Option β} :
    (∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') ↔
      ∀ m : Mem, obs m = obs { blocks := m.blocks } :=
  ⟨fun h m => h _ _ rfl, fun h m m' e => by rw [h m, h m', e]⟩

/-- **The five fields of the core's `OneRun` at the grid**, for launch `L`, contexts `c` and the
start's grid `g₀`: the steps between grids reachable from `g₀` are confluent up to `Grid.Same`
with the core's `Bad` at `sig` persistent; `Grid.Same` keeps the core's `Done` at `sig`, and the
blocks; a grid reachable from `g₀` that is done (the core's `Done` at `sig`) has no step and does
not fault. -/
structure Grid.OneRun (L : Launch) (c : Nat → Ctx) (g₀ : Grid) : Prop where
  /-- Builds `Grid.OneRun` from its five fields. -/
  mk ::
  /-- Schedule independence up to bad grids (the core's `OneRun.confluent`). -/
  confluent : Confluent (fun x y : {g // ReflTransGen (Grid.Step L c) g₀ g} =>
    Grid.Step L c x.1 y.1) (fun x y => x.1.Same y.1) (fun x => GPUProof.Bad sig (x.1, L, c))
  /-- A grid the same as a done grid (the core's `Done` at `sig`) is done too. -/
  same_done : ∀ {g g' : Grid}, g.Same g' → GPUProof.Done sig (g, L, c) →
    GPUProof.Done sig (g', L, c)
  /-- Grids that are the same have the same blocks. -/
  same_bytes : ∀ {g g' : Grid}, g.Same g' → g.mem.blocks = g'.mem.blocks
  /-- A done grid reachable from `g₀` has no step. -/
  done_final : ∀ {g g' : Grid}, ReflTransGen (Grid.Step L c) g₀ g → GPUProof.Done sig (g, L, c) →
    ¬ Grid.Step L c g g'
  /-- A done grid reachable from `g₀` does not fault. -/
  done_safe : ∀ {g : Grid}, ReflTransGen (Grid.Step L c) g₀ g → GPUProof.Done sig (g, L, c) →
    ¬ GPUProof.Faults sig (g, L, c)

/-- **`OneRun` from the start**, for every program, kernel, launch, arguments, address choice and
oracle, on a caller's memory every pointer byte of whose blocks names a number below `next` or
with a block (`Mem.Closed.bytesIn` gives it from a closed memory): `Grid.confluent`, and
`Grid.Same`, `Done.final` and `done_not_faults` (with `Grid.start_reach_size`) for the other four
fields. -/
theorem Grid.start_oneRun {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known) :
    Grid.OneRun L c g₀ where
  confluent := Grid.confluent h hm
  same_done he hd := by rw [Grid.done_iff] at *; rwa [← he.1]
  same_bytes he := he.2.1
  done_final hr := Done.final (Grid.start_reach_size h hr).le
  done_safe hr := done_not_faults (Grid.start_reach_size h hr).le

end MojoProof.Sem
