import MojoProof.Sym.MetaRun
import MojoProof.Sym.Block
import MojoProofTest.Eval

/-!
# The memory obligation on metadata at one block of one program

One program (vector_addition) at one launch (`launch2 4 1 32 1`, the inputs of
`MojoProofTest.vaddTests`): thread 5 of the start that `MojoProofTest.startF32` makes is run by
the evaluator (`MojoProof.Sem.step`) to the entry of the first block of the kernel whose summary
(`MojoProof.Sym.summarize`) has a `store` effect. At that entry the effects run on metadata
(`MojoProof.Sym.SEff.runMeta`) and on the memory (`SEff.run`), and the obligation holds
(`Cond.Holds`, decided). The mutant marks every block read-only: the check on metadata refuses it,
and so does the run on the memory. The checks are the evaluator's (`#guard`).
-/

namespace MojoProofTest.MetaRun

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- The thread `t` on memory `m` in context `c`, stepped by the evaluator (at most `n` steps) to
the entry of block `lbl` of its innermost frame, if it gets there without a fault or a wait. -/
def runTo (c : Ctx) (lbl : Nat) : Nat → Thread → Mem → Option (Thread × Mem)
  | 0, _, _ => none
  | n + 1, t, m => match t.frames.head? with
    | some f =>
      if f.label = lbl ∧ f.pc = 0 then some (t, m)
      else match step c t m with
        | .ok (.next t' m') => runTo c lbl n t' m'
        | _ => none
    | none => none

/-- One program (vector_addition) at one launch: the valuation at the entry of the first block of
the kernel whose summary has a `store`, reached by thread 5 from the start, with the summary; the
valuation's memory is `f` of the thread's. -/
def vaddAt (f : Mem → Mem) : Option (Valuation × Summary) := do
  let (g, ctx, _) ← (startF32 Kernels.vadd.prog (launch2 4 1 32 1) (fun _ _ => 0) vaddIns 100
    [.bits 32 (BitVec.ofNat 32 100)]).toOption
  let .run t ← g.threads[5]? | none
  let fr ← t.frames.head?
  let P := Kernels.vadd.prog
  let (lbl, σ) ← fr.fn.blocks.findSome? fun b => (summarize P fr.fn b.label 0).bind fun σ =>
    if σ.effs.any (fun | .store .. => true | _ => false) then some (b.label, σ) else none
  let (t', m) ← runTo (ctx 5) lbl 1000 t g.mem
  let fr' ← t'.frames.head?
  let V := Valuation.entry (ctx 5) t'.k (f m) fr'
  return (V, σ)

/-- Every block of memory `m` read-only. -/
def readOnly (m : Mem) : Mem :=
  { m with blocks := fun b => (m.blocks b).map fun k => { k with readOnly := true } }

-- the block has a store, and its effects run on metadata and on the memory: the obligation holds
#guard (vaddAt id).any fun (V, σ) => let vs := vals V σ.nodes; let es := σ.effs
  es.any (fun | .store .. => true | _ => false) && (SEff.runMeta V vs es).toBool &&
    (SEff.run V vs es).toBool && decide (Cond.Holds V vs (.mem es))
-- the mutant with every block read-only: the check on metadata refuses it, and so does the run
#guard (vaddAt readOnly).any fun (V, σ) => let vs := vals V σ.nodes; let es := σ.effs
  !(SEff.runMeta V vs es).toBool && !(SEff.run V vs es).toBool

end MojoProofTest.MetaRun
