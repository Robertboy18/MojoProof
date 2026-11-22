import MojoProof.Cert.Rup

/-!
# A RUP certificate checked by the kernel

One instance of the kernel-only certificate path (`MojoProof.Cert`): the formula
`(x ∨ y) ∧ (x ∨ ¬y) ∧ (¬x ∨ y) ∧ (¬x ∨ ¬y)` (`x` is variable 0, `y` variable 1) and a two-step
certificate (`x` by RUP from clauses 1 and 2, then the empty clause from it and clauses 3 and 4).
`decide +kernel` evaluates the checker in the kernel. Three corrupted inputs are refused, also in
the kernel: a wrong hint, a certificate without its last step, and the formula without its first
clause. One example, written by hand; the theorem it instantiates (`Cert.unsat`) covers every
formula and certificate.
-/

namespace MojoProofTest.Cert

open MojoProof.Cert

/-- The formula. -/
def F : List (List Lit) :=
  [[(0, true), (1, true)], [(0, true), (1, false)], [(0, false), (1, true)],
   [(0, false), (1, false)]]

/-- The certificate. -/
def cert : List Step := [.add 5 [(0, true)] [1, 2], .add 6 [] [5, 3, 4]]

/-- No assignment satisfies `F`: the kernel checks `cert`. -/
theorem refuted (a : Nat → Bool) : F.all (holds a) = false :=
  unsat (F := F) (p := cert) (by decide +kernel) a

/-- The formula as a Boolean function has no true value. -/
theorem refuted_bool (x y : Bool) : ((x || y) && (x || !y) && (!x || y) && (!x || !y)) = false := by
  have := refuted fun v => if v = 0 then x else y
  revert this; cases x <;> cases y <;> decide

/-- info: 'MojoProofTest.Cert.refuted_bool' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms refuted_bool

example : check (number F) [.add 5 [(0, true)] [1, 3], .add 6 [] [5, 3, 4]] = false := by
  decide +kernel
example : check (number F) [.add 5 [(0, true)] [1, 2]] = false := by decide +kernel
example : check (number F.tail) cert = false := by decide +kernel

end MojoProofTest.Cert
