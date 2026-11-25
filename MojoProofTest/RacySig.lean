import GPUProof.Chunks
import MojoProofTest.Eval
import MojoProof.Sem.SigDef

/-!
# `racy` and `kept` through `sig` in the kernel, in one proof each

One program (vector_addition) at one launch through `sig`: the launch of the evaluator tests
(`MojoProofTest.vaddTests`: `launch2 4 1 32 1`, 4 blocks of 32 threads on 100 floats, the zero
oracle), whose trace has 684 accesses and no barrier.

* `vaddTrace`: the trace of the run that `MojoProofTest.runF32` checks at that launch
  (`MojoProofTest.gridF32`, from the start `MojoProofTest.startF32`).
* `trSig`: that trace through `sig` (`MojoProof.Sem.Event.toCore`), oldest first, written out by
  `trace_literal%`, with a `#guard` that it is the run's (the evaluator's check; the kernel's is
  in MojoProofTest/RacySigRun.lean).
* `vadd_sig_racy`: `GPUProof.racy sig trSig = false` by `decide +kernel`, in one proof: `sig`
  proves its placement injective (`GPUProof.Sig.placeInj`), so the pass decides whether two
  accesses share a byte by their buffers and offsets (`GPUProof.Sig.share`).
* `vadd_sig_kept`: `GPUProof.kept sig trSig = true` by `decide +kernel`, in one proof: no access
  of the trace writes a byte that a frozen load (`!invariant.load`) of it reads.

Both theorems are about the literal trace: the trace the evaluator produced. Its equality with the
run is checked by the evaluator here and by the kernel in MojoProofTest/RacySigRun.lean
(`trSig_run`, `vadd_run_racy`).
-/

namespace MojoProofTest.RacySig

open Lean GPUProof MojoProof MojoProof.LLVM MojoProof.Sem MojoProofTest

/-- `sig`'s threads as terms: numerals. -/
instance : ToExpr sig.Tid := inferInstanceAs (ToExpr Nat)
/-- `sig` has no job. -/
instance : ToExpr sig.Job := inferInstanceAs (ToExpr Empty)
/-- `sig`'s buffers as terms: numerals. -/
instance : ToExpr sig.Buf := inferInstanceAs (ToExpr Nat)
/-- `sig`'s updates: the operations of `atomicrmw` (their terms from MojoProof/LLVM/Quote.lean). -/
instance : ToExpr sig.Op := inferInstanceAs (ToExpr RmwOp)
/-- `sig`'s one proxy. -/
instance : ToExpr sig.Proxy := inferInstanceAs (ToExpr Unit)
/-- `sig`'s barriers as terms: numerals. -/
instance : ToExpr sig.Obj := inferInstanceAs (ToExpr Nat)
/-- `sig`'s bytes as terms: pairs of a block and an offset. -/
instance : ToExpr sig.Loc := inferInstanceAs (ToExpr (Nat × Int))

/-- One program (vector_addition) at one launch: the trace, newest first, of its run at the launch
of the evaluator tests (`launch2 4 1 32 1`, the inputs `MojoProofTest.vaddIns`, `input 1` and
`input 2` at 100 floats, the zero oracle): the run of `MojoProofTest.gridF32`, which
`MojoProofTest.runF32` checks. -/
def vaddTrace : Except String (List Event) := do
  let (g, _) ← gridF32 Kernels.vadd.prog (launch2 4 1 32 1) (fun _ _ => 0) vaddIns 100
    [.bits 32 (BitVec.ofNat 32 100)]
  return g.mem.trace

/-- One program (vector_addition) at one launch through `sig`: the trace of `vaddTrace` through
`MojoProof.Sem.Event.toCore`, oldest first, as the evaluator produced it (`trace_literal%`). -/
def trSig : List sig.Event :=
  trace_literal% ((vaddTrace.toOption.getD []).map (Event.toCore (launch2 4 1 32 1))).reverse

-- the literal is the run's trace through `sig`, of 684 accesses, and the evaluator's `racy`
-- passes it
#guard (vaddTrace.toOption.map fun t => (t.map (Event.toCore (launch2 4 1 32 1))).reverse) ==
  some trSig
#guard trSig.length == 684 && trSig.all (·.access?.isSome)
#guard !racy sig trSig

/-- One program (vector_addition) at one launch through `sig`: the literal trace `trSig` is race
free, by `decide +kernel` (684 positions in one proof). -/
theorem vadd_sig_racy : racy sig trSig = false := by
  decide +kernel

/-- One program (vector_addition) at one launch through `sig`: the literal trace `trSig` keeps its
frozen reads (no access writes a byte of a frozen load, `GPUProof.Kept` by `GPUProof.kept_iff`),
by `decide +kernel` (684 positions, 200 frozen loads, in one proof). -/
theorem vadd_sig_kept : kept sig trSig = true := by
  decide +kernel

end MojoProofTest.RacySig
