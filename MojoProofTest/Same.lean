import MojoProof.Sem.Schedule

/-!
# An instance of `Trace.Same`, and its negative twin

Two writes of 4 bytes to block 1 by threads 0 and 1 of block of threads 0, at offsets 0 and 4, are
independent, so they give the same trace in either order (`swap`, by `Trace.Same.swap`). So after
any events `E` the two orders are both racy or both not, and both keep `!invariant.load` or both
break it (`after`, by `Trace.Same.append`, `Trace.Same.racy` and `Trace.Same.kept`). The twin: a
barrier of block of threads 0 between two writes of one word by its threads 0 and 1 orders them;
moved past the newer write it orders nothing: the barrier and the write are not independent, the
trace becomes racy, and the two traces, with the same events, are not the same (`twin`). Inserting
events (L13 in docs/proofs/schedule.md, `racy_insert`): thread 1's write still races with thread 0's
when a barrier of another block of threads and a write elsewhere come between (`insert`); a barrier
of their own block of threads orders them (`twin`'s first trace). Grids with no threads and the two
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

/-- After every list of events `E`, the two orders of `swap` are both racy or both not, and both
keep `!invariant.load` or both break it. -/
theorem after (E : List Event) :
    racy (E ++ [w 0 0, w 1 4]) = racy (E ++ [w 1 4, w 0 0]) ∧
      kept (E ++ [w 0 0, w 1 4]) = kept (E ++ [w 1 4, w 0 0]) :=
  ⟨(swap.append E).racy, (swap.append E).kept⟩

/-- Inserting events (`racy_insert`): thread 1's write races with thread 0's, and still does with
a barrier of block of threads 1 and another write between them. -/
theorem insert : racy ([w 1 0] ++ [.barrier 1, w 2 8] ++ [w 0 0]) = true :=
  racy_insert (w := ⟨1, 0⟩) (by decide) (fun _ he => ⟨_, List.mem_singleton.1 he, rfl⟩)
    (by decide)

/-- The twin of `swap` (independence is needed): a write of thread 1 and a barrier of its block of
threads 0 are not independent; with the barrier between the writes of threads 1 and 0 to one word
the trace is not racy, with the barrier moved past thread 1's write it is, so the two traces are
not the same. -/
theorem twin :
    (w 1 0).indep (.barrier 0) = false ∧
      racy [w 1 0, .barrier 0, w 0 0] = false ∧ racy [.barrier 0, w 1 0, w 0 0] = true ∧
      ¬ Trace.Same [w 1 0, .barrier 0, w 0 0] [.barrier 0, w 1 0, w 0 0] :=
  ⟨rfl, by decide, by decide, fun h => absurd h.racy (by decide)⟩

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
