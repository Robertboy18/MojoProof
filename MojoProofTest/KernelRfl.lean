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

`kernel_rfl_late` closes `a = b` with the same proof but leaves the check to the kernel's check of
the whole declaration, whose caches are shared by all its equations: for many equations over one
evaluation, such as the memories of a warp's lanes, each from the lanes before it
(MojoProofTest/GemvWarp.lean), which `kernel_rfl` would evaluate again for each.
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

open Lean Meta Elab Tactic in
/-- `kernel_rfl_late` closes a goal `a = b` with `Eq.refl a` at the type `a = b`, unchecked: the
kernel checks it when it checks the declaration, with the caches of that one check. A goal the
kernel does not show fails the declaration. -/
elab (name := kernelRflLate) "kernel_rfl_late" : tactic => withMainContext do
  let g ← getMainGoal
  let t ← instantiateMVars (← g.getType)
  let some (_, a, _) := t.eq? | throwError "kernel_rfl_late: not an equation"
  g.assign (MojoProof.Sym.Obl.hint (← mkEqRefl a) t)
  replaceMainGoal []

/-- error: mojo_obl: the kernel does not show
  1
equal to
  2 -/
#guard_msgs in
example : (1 : Nat) = 2 := by kernel_rfl

example : (2 : Nat) + 2 = 4 := by kernel_rfl_late

/-- error: kernel_rfl_late: not an equation -/
#guard_msgs in
example : True := by kernel_rfl_late

/-- error: (kernel) application type mismatch
  id (Eq.refl 1)
argument has type
  1 = 1
but function has type
  1 = 2 → 1 = 2 -/
#guard_msgs in
example : (1 : Nat) = 2 := by kernel_rfl_late

end MojoProofTest
