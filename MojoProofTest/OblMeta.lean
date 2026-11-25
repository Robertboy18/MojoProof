import MojoProofTest.MetaRun
import MojoProof.Sym.Obl

/-!
# mojo_obl on a closed memory obligation

At the valuation and summary of MojoProofTest/MetaRun.lean (vector_addition at one launch,
thread 5, the entry of the first block with a `store`), the obligation `Cond.mem` of the
summary's effects is closed. mojo_obl proves it by the kernel's evaluation of the check on
metadata (`MojoProof.Sym.SEff.runMeta`, through `MojoProof.Sym.SEff.holds_of_runMeta_toBool`):
`vadd_mem`, and the proof names that lemma (checked by a meta program below).
-/

namespace MojoProofTest.OblMeta

open Lean MojoProof MojoProof.Sem MojoProof.Sym MojoProofTest.MetaRun

/-- The valuation and summary of `MojoProofTest.MetaRun.vaddAt` (with the memory unchanged),
which the evaluator reaches (`decide +kernel`). -/
def at0 : Valuation × Summary := (vaddAt id).get (by decide +kernel)

/-- The valuation of `at0`. -/
def V0 : Valuation := at0.1

/-- The summary of `at0`. -/
def S0 : Summary := at0.2

/-- The memory obligation of `S0` at `V0`, by mojo_obl. -/
theorem vadd_mem : Cond.Holds V0 (vals V0 S0.nodes) (.mem S0.effs) := by
  mojo_obl

-- the proof is the check on metadata
run_meta do
  let some (.thmInfo t) := (← getEnv).find? ``vadd_mem | throwError "no proof"
  unless t.value.getUsedConstants.contains ``SEff.holds_of_runMeta_toBool do
    throwError "not by the check on metadata"

end MojoProofTest.OblMeta
