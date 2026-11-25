import GPUProof.Chunks
import MojoProofTest.GPUProof.Toy

/-!
# The race check by chunks on the test machine

One test machine (`toy`) at two sizes of the ring (`MojoProofTest.GPUProof.Toy.ring`, with the
launch's barrier), 11 and 37 threads, through `racy_by_chunks` (`GPUProof/Chunks.lean`):

* `ring11_racy_chunks`: `racy toy (final (ring true 11) 11).trace = false` by
  `racy_by_chunks 5`, on the run itself: the kernel runs the schedule and the pass, in 5 chunks
  of at most 5 of the 23 positions.
* `ring37`: the trace of the ring at 37 threads (75 events) written out by `trace_literal%`, with
  a `#guard` that it is the run's trace, and `ring37_racy_chunks`: `racy toy ring37 = false` by
  `racy_by_chunks 16`, in 5 chunks, the last of 11 positions. The theorem is about the literal
  trace; its equality with the run is checked by the evaluator.
* the failures: on the mutant without the barrier `racy_by_chunks` names the chunk in which the
  pass finds a race, and on a goal that is not `racy S tr = false` it says so (`#guard_msgs`).
* where the chunks end (`#guard`): `chunkStatesFrom` with one chunk of 1 position from position
  `0` on the first two events of the ring at 1 thread ends at position 1, not at the length 2;
  `chunkStates` with chunks of 0 positions on `ring37` gives no chunk, and with chunks of 16
  positions ends at 16, 32, 48, 64 and the length 75, each with the pass over the positions
  before it (`scan`).
-/

open Lean GPUProof MojoProofTest.GPUProof.Toy

namespace MojoProofTest.GPUProof.Chunks

/-- The test machine's threads as terms: numerals. -/
instance : ToExpr toy.Tid := inferInstanceAs (ToExpr Nat)
/-- The test machine has no job. -/
instance : ToExpr toy.Job := inferInstanceAs (ToExpr Empty)
/-- The test machine's buffers as terms: numerals. -/
instance : ToExpr toy.Buf := inferInstanceAs (ToExpr Nat)
/-- The test machine's one update. -/
instance : ToExpr toy.Op := inferInstanceAs (ToExpr Unit)
/-- The test machine's two proxies. -/
instance : ToExpr toy.Proxy := inferInstanceAs (ToExpr Bool)
/-- The test machine's barriers as terms: numerals. -/
instance : ToExpr toy.Obj := inferInstanceAs (ToExpr Nat)
/-- The test machine's bytes as terms: pairs of a buffer and an offset. -/
instance : ToExpr toy.Loc := inferInstanceAs (ToExpr (Nat × Int))

/-- One test machine (`toy`), at 11 threads: the ring's run with the barrier is race free, by
`racy_by_chunks 5` on the run itself (23 positions in 5 chunks). -/
theorem ring11_racy_chunks : racy toy (final (ring true 11) 11).trace = false := by
  racy_by_chunks 5

/-- One test machine (`toy`), at 37 threads: the trace of the ring's run with the barrier, as the
evaluator produced it (`trace_literal%`). -/
def ring37 : List toy.Event := trace_literal% (final (ring true 37) 37).trace

-- the literal is the run's trace, and the run ends with every thread done
#guard ring37 == (final (ring true 37) 37).trace && ring37.length == 75 &&
  allDone (final (ring true 37) 37)

/-- One test machine (`toy`), at 37 threads: the literal trace of the ring's run with the barrier
(`ring37`) is race free, by `racy_by_chunks 16` (75 positions in 5 chunks). -/
theorem ring37_racy_chunks : racy toy ring37 = false := by
  racy_by_chunks 16

-- one chunk of 1 position from position `0` on two events ends at position 1, before the length
#guard ((final (ring true 1) 1).trace.take 2).length == 2 &&
  (chunkStatesFrom (S := toy) ((final (ring true 1) 1).trace.take 2) 1 1 0
    ⟨[], [], [], [], [], false⟩).map (·.1) == [1]

-- chunks of 0 positions give no chunk; chunks of 16 positions end at the multiples of 16 below
-- the length 75 and at the length, each with the pass over the positions before it
#guard (chunkStates ring37 0).isEmpty && (chunkStates ring37 16).map (·.1) == [16, 32, 48, 64, 75]
  && (chunkStates ring37 16).all fun p => p.2 == scan toy ring37 p.1

/--
error: racy_by_chunks: the pass finds a race in positions 0 to 3
-/
#guard_msgs in
example : racy toy (final (ring false 8) 8).trace = false := by
  racy_by_chunks 4

/--
error: racy_by_chunks: the goal is not `GPUProof.racy S tr = false`:
  racy toy (final (ring true 8) 8).trace = true
-/
#guard_msgs in
example : racy toy (final (ring true 8) 8).trace = true := by
  racy_by_chunks 4

end MojoProofTest.GPUProof.Chunks
