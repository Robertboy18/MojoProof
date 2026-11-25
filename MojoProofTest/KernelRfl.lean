import MojoProof.Sym.Obl

/-!
# `kernel_rfl`: equations the kernel shows by unfolding

The tactic `kernel_rfl` closes a goal `a = b` with `Obl.krfl` (MojoProof/Sym/Obl.lean): the
kernel's definitional equality, with the kernel's caches, in place of the elaborator's. It is for
equations whose type has no decidable equality (`Val`, `Value`, threads, memories), where
`decide +kernel` does not apply, for runs the elaborator's `rfl` re-evaluates without sharing
(MojoProofTest/SymColl.lean, MojoProofTest/NaiveStart.lean), and for equations with free
variables that the kernel shows by unfolding the rest, such as the naive family's at every row
stride (MojoProofTest/NaiveFamRun.lean, MojoProofTest/NaiveOff.lean).
-/

namespace MojoProofTest

open Lean Meta Elab Tactic in
/-- `kernel_rfl` closes a goal `a = b` that the kernel shows by unfolding (`Obl.krfl`): the
`decide +kernel` of equations whose type has no decidable equality, such as lists of `phi`
operands (`Value`, with its float literals). It fails when the kernel does not show it. -/
elab "kernel_rfl" : tactic => withMainContext do
  let g ← getMainGoal
  let some (_, a, b) := (← instantiateMVars (← g.getType)).eq?
    | throwError "kernel_rfl: not an equation"
  g.assign (← MojoProof.Sym.Obl.krfl a b)
  replaceMainGoal []

/-- error: mojo_obl: the kernel does not show
  1
equal to
  2 -/
#guard_msgs in
example : (1 : Nat) = 2 := by kernel_rfl

end MojoProofTest
