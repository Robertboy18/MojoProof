import MojoProof.Sem.Schedule

/-!
# An instance of `Trace.Same`, and its negative twin

Two writes of 4 bytes to block 1 by threads 0 and 1 of block of threads 0, at offsets 0 and 4, are
independent, so they give the same trace in either order (`swap`, by `Trace.Same.swap`). So after
any events `E` the two orders both have two accesses that clash by phases or neither (a race of
the core's `racy` at `sig` under the premises of `racy_iff`), and at every launch both keep
`!invariant.load` (the core's `kept` at `sig`) or both break it (`after`, by `Trace.Same.append`,
`Trace.Same.clash` and `Trace.Same.kept`). The twin: a barrier of block of threads 0 between two
writes of one word by its threads 0 and 1 orders them; moved past the newer write it orders
nothing: the barrier and the write are not independent, the trace becomes racy (the core's `racy`
at `sig`, at the launch `launch2 1 1 2 1` of one block of two threads), and the two traces, with the
same events, are not the same (`twin`). Inserting events (L13 in docs/proofs/schedule.md,
`racy_insert`): thread 1's write still clashes with thread 0's when a barrier of another block of
threads and a write elsewhere come between (`insert`); a barrier of their own block of threads
orders them (`twin`'s first trace). Grids with no threads and the two
traces of `swap` are the same (`grids`, with `Grid.Same.symm`, `trans` and `refl`); with the traces
of `twin`, or with one trace and two next block numbers, they are not (`grid_twin`). Statements
about traces and grids, not about a kernel.
-/

namespace MojoProofTest.Same

open MojoProof.Sem

/-- A write by thread `n` of block of threads 0 of 4 bytes at offset `off` of block 1. -/
def w (n off : Nat) : Event := .access ⟨⟨n, 0⟩, ⟨1, off⟩, 4, true, none, false⟩

/-- The two writes of threads 0 and 1 at offsets 0 and 4 give the same trace in either order. -/
theorem swap : Trace.Same [w 0 0, w 1 4] [w 1 4, w 0 0] :=
  Trace.Same.swap (E := [w 0 0]) (F := [w 1 4]) (by decide) []

/-- After every list of events `E`, the two orders of `swap` both have two accesses that clash by
phases or neither, and at every launch `L` both keep `!invariant.load` (the core's `kept` at
`sig`) or both break it. -/
theorem after (L : Launch) (E : List Event) :
    ((∃ x ∈ (phases (E ++ [w 0 0, w 1 4])).1, ∃ y ∈ (phases (E ++ [w 0 0, w 1 4])).1,
        clash x y = true) ↔
      ∃ x ∈ (phases (E ++ [w 1 4, w 0 0])).1, ∃ y ∈ (phases (E ++ [w 1 4, w 0 0])).1,
        clash x y = true) ∧
      GPUProof.kept sig ((E ++ [w 0 0, w 1 4]).map (Event.toCore L)).reverse =
        GPUProof.kept sig ((E ++ [w 1 4, w 0 0]).map (Event.toCore L)).reverse :=
  ⟨(swap.append E).clash, (swap.append E).kept⟩

/-- Inserting events (`racy_insert`): thread 1's write clashes with thread 0's by phases, and
still does with a barrier of block of threads 1 and another write between them. -/
theorem insert :
    ∃ x ∈ (phases ([w 1 0] ++ [.barrier 1, w 2 8] ++ [w 0 0])).1,
      ∃ y ∈ (phases ([w 1 0] ++ [.barrier 1, w 2 8] ++ [w 0 0])).1, clash x y = true :=
  racy_insert (w := ⟨1, 0⟩) (by decide) (fun _ he => ⟨_, List.mem_singleton.1 he, rfl⟩)
    (by decide +kernel)

/-- The twin of `swap` (independence is needed): a write of thread 1 and a barrier of its block of
threads 0 are not independent; with the barrier between the writes of threads 1 and 0 to one word
the trace is not racy (the core's `racy` at `sig`, at `launch2 1 1 2 1`), with the barrier moved
past thread 1's write it is, so the two traces are not the same. -/
theorem twin :
    (w 1 0).indep (.barrier 0) = false ∧
      GPUProof.racy sig
          ([w 1 0, .barrier 0, w 0 0].map (Event.toCore (launch2 1 1 2 1))).reverse = false ∧
      GPUProof.racy sig
          ([.barrier 0, w 1 0, w 0 0].map (Event.toCore (launch2 1 1 2 1))).reverse = true ∧
      ¬ Trace.Same [w 1 0, .barrier 0, w 0 0] [.barrier 0, w 1 0, w 0 0] :=
  ⟨rfl, by decide +kernel, by decide +kernel, fun h => absurd h.clash (by decide +kernel)⟩

/-- The grid with no threads, no blocks and trace `tr`. -/
def g (tr : List Event) (next : Nat := 1) : Grid := ⟨#[], { next, trace := tr }⟩

/-- Grids with no threads and the two traces of `swap` are the same, in both directions, through
`trans`, and each with itself. -/
theorem grids :
    (g [w 0 0, w 1 4]).Same (g [w 1 4, w 0 0]) ∧ (g [w 1 4, w 0 0]).Same (g [w 0 0, w 1 4]) ∧
      (g [w 0 0, w 1 4]).Same (g [w 0 0, w 1 4]) ∧ (g [w 1 4, w 0 0]).Same (g [w 1 4, w 0 0]) :=
  have h : (g [w 0 0, w 1 4]).Same (g [w 1 4, w 0 0]) := ⟨rfl, rfl, rfl, swap⟩
  ⟨h, h.symm, h.trans h.symm, .refl _⟩

/-- Twins of `grids`: grids with the two traces of `twin` are not the same, and neither are grids
with one trace and two next block numbers. -/
theorem grid_twin :
    ¬ (g [w 1 0, .barrier 0, w 0 0]).Same (g [.barrier 0, w 1 0, w 0 0]) ∧
      ¬ (g [w 0 0]).Same (g [w 0 0] 2) :=
  ⟨fun h => twin.2.2.2 h.2.2.2, fun h => absurd h.2.2.1 (by decide)⟩

end MojoProofTest.Same
