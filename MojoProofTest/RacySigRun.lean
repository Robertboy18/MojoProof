import MojoProofTest.RacySig

/-!
# The run's trace through `sig` is race free, in the kernel

One program (vector_addition) at one launch through `sig`: the launch of the evaluator tests
(`MojoProofTest.vaddTests`: `launch2 4 1 32 1`, 4 blocks of 32 threads on 100 floats, the zero
oracle), from the start `MojoProofTest.startF32` makes.

* `trSig_run`: the trace of the run (`MojoProofTest.RacySig.vaddTrace`, the run of
  `MojoProofTest.gridF32` that `MojoProofTest.runF32` checks) through `sig` is the literal
  `MojoProofTest.RacySig.trSig`, by `decide +kernel`: the kernel evaluates the start and the run
  (128 threads, 684 accesses) in one proof.
* `vadd_run_racy`: the run's trace through `sig` is race free, from `trSig_run` and
  `MojoProofTest.RacySig.vadd_sig_racy`.

The scope is that one launch at those inputs and oracle; no other launch, input or memory.
-/

namespace MojoProofTest.RacySig

open GPUProof MojoProof MojoProof.Sem MojoProofTest

-- `Array.any` recurses by well-founded recursion, so the kernel cannot evaluate a step without
-- this.
unseal Array.anyM.loop

/-- One program (vector_addition) at one launch through `sig`: the run's trace (`vaddTrace`)
succeeds, and through `MojoProof.Sem.Event.toCore`, oldest first, it is the literal `trSig`. The
kernel evaluates the start (`MojoProofTest.startF32`) and the run (`MojoProof.Sem.Grid.run`) at
`launch2 4 1 32 1` on `input 1` and `input 2` at 100 floats and the zero oracle. -/
theorem trSig_run :
    (vaddTrace.toOption.map fun t => (t.map (Event.toCore (launch2 4 1 32 1))).reverse) =
      some trSig := by
  decide +kernel

/-- One program (vector_addition) at one launch through `sig`: the run's trace (`vaddTrace`, at
`launch2 4 1 32 1` on `input 1` and `input 2` at 100 floats and the zero oracle) succeeds, and
through `MojoProof.Sem.Event.toCore`, oldest first, it has no data race (`GPUProof.racy` is
false): `trSig_run` and `vadd_sig_racy`. -/
theorem vadd_run_racy : ∃ t, vaddTrace = .ok t ∧
    racy sig (t.map (Event.toCore (launch2 4 1 32 1))).reverse = false := by
  have h := trSig_run
  cases hv : vaddTrace with
  | error e => rw [hv] at h; cases h
  | ok t =>
    rw [hv] at h
    refine ⟨t, rfl, ?_⟩
    have ht : (t.map (Event.toCore (launch2 4 1 32 1))).reverse = trSig := Option.some.inj h
    rw [ht]
    exact vadd_sig_racy

end MojoProofTest.RacySig
