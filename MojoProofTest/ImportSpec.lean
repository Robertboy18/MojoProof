import MojoProof.Import.Command
import GPUProof.Spec.Linear

/-!
# `import_spec` at the sum of a vector read backwards: one importer declared, two refused

`import_spec` (MojoProof/Import/Command.lean) declares an importer from its operations and
closes its `eq` with a theorem of the current file found by its type (`import_fact`). Here one
operation, the sum of a real vector, is proposed as `GPUProof.Spec.sumReal` with the vector read
backwards (input `i` is entry `Fin.rev i`), so `eq` needs a theorem: the sum does not depend on
the order (Mathlib's `Fintype.prod_equiv` in its additive form, at `Fin.revPerm`).

* `Open`: the command before any theorem of this file closes its `eq`. It declares the operations,
  readings and their unfoldings (`Open.readIn2` uses the one of `readIn`, at size 2), but not the
  importer, and warns with the open goal (`#guard_msgs`).
* `sum_rev`: the sum is `GPUProof.Spec.sumReal`'s function at the vector read backwards.
* `Good`: the same command after `sum_rev`, which closes its `eq`; `eq2` and `eq5` are its `eq` at
  the vectors `1 2` and `1 2 3 4 5`, whose sums `out2` and `out5` are `3` and `15`.
* `Twice`: the mutant meaning `2 * ∑ i, v i`. `sum_rev` is tried and its left side is not the
  meaning, so the command refuses it with the open goal.

Tests at sizes 2 and 5, for every grade `g`.
-/

namespace MojoProofTest.ImportSpec

open MojoProof.Import

variable (g : GPUProof.RealGrades Fin fun _ => Unit) (mono : ∀ σ E A, Monotone (g σ E A))

namespace Open

/--
warning: import_spec: `sumImp` is not declared, its `eq` has an open case:
import_fact: no theorem of this file closes the goal
  ∑ i, v i = (GPUProof.Spec.sumReal g mono).f n (fun i => v (Fin.rev i)) o✝
-/
#guard_msgs in
/-- The sum of a vector read backwards, proposed as `GPUProof.Spec.sumReal g`, before any theorem
of this file closes its `eq`: not declared. -/
import_spec sumImp g mono : SumOp (n : ℕ) where
  /-- The sum of a real vector. -/
  | sum (v : Fin n → ℝ) → (y : ℝ) := ∑ i, v i
    ↦ GPUProof.Spec.sumReal g mono
    from fun i => v i.rev
    at fun _ => y

/-- error: Unknown identifier `sumImp` -/
#guard_msgs in
#check sumImp

/-- **The refused command declared the readings** (test at size 2): `readIn` at `.sum` and the
vector `1 2` is `2` at input `0`, the vector read backwards. -/
theorem readIn2 : readIn g mono .sum _ rfl 2 ![1, 2] (0 : Fin 2) = (2 : ℝ) := by
  rw [readIn_sum]
  rfl

end Open

/-- **A sum is the sum of the vector read backwards**, for every grade `g`, size `n`, real vector
`v` and output `o`: `∑ i, v i` is `GPUProof.Spec.sumReal g`'s function at `fun i => v i.rev`. By
Mathlib's `Fintype.sum_equiv` at `Fin.revPerm`. -/
theorem sum_rev (n : ℕ) (v : Fin n → ℝ) (o : Unit) :
    ∑ i, v i = (GPUProof.Spec.sumReal g mono).f n (fun i => v i.rev) o :=
  Fintype.sum_equiv Fin.revPerm _ _ fun i => by simp

namespace Good

/-- The sum of a vector read backwards, proposed as `GPUProof.Spec.sumReal g`, after `sum_rev`,
which closes its `eq`. -/
import_spec sumImp g mono : SumOp (n : ℕ) where
  /-- The sum of a real vector. -/
  | sum (v : Fin n → ℝ) → (y : ℝ) := ∑ i, v i
    ↦ GPUProof.Spec.sumReal g mono
    from fun i => v i.rev
    at fun _ => y

/-- **`eq` at size 2** (test at 2): at the vector `1 2`, the output reading of the sum is
`GPUProof.Spec.sumReal g`'s function at the vector read backwards. -/
theorem eq2 : (sumImp g mono).readOut .sum _ rfl (2 : ℕ)
      ((sumImp g mono).denote .sum (2 : ℕ) (![1, 2] : Fin 2 → ℝ)) =
    (GPUProof.Spec.sumReal g mono).f 2
      ((sumImp g mono).readIn .sum _ rfl (2 : ℕ) (![1, 2] : Fin 2 → ℝ)) :=
  (sumImp g mono).eq .sum _ rfl (2 : ℕ) (![1, 2] : Fin 2 → ℝ) trivial

/-- **The sum at size 2** (test at 2): the output reading of the sum of `1 2` is `3`. -/
theorem out2 : (sumImp g mono).readOut .sum _ rfl (2 : ℕ)
    ((sumImp g mono).denote .sum (2 : ℕ) (![1, 2] : Fin 2 → ℝ)) () = (3 : ℝ) := by
  change ∑ i : Fin 2, (![1, 2] : Fin 2 → ℝ) i = 3
  norm_num [Fin.sum_univ_succ]

/-- **`eq` at size 5** (test at 5): at the vector `1 2 3 4 5`, the output reading of the sum is
`GPUProof.Spec.sumReal g`'s function at the vector read backwards. -/
theorem eq5 : (sumImp g mono).readOut .sum _ rfl (5 : ℕ)
      ((sumImp g mono).denote .sum (5 : ℕ) (![1, 2, 3, 4, 5] : Fin 5 → ℝ)) =
    (GPUProof.Spec.sumReal g mono).f 5
      ((sumImp g mono).readIn .sum _ rfl (5 : ℕ) (![1, 2, 3, 4, 5] : Fin 5 → ℝ)) :=
  (sumImp g mono).eq .sum _ rfl (5 : ℕ) (![1, 2, 3, 4, 5] : Fin 5 → ℝ) trivial

/-- **The sum at size 5** (test at 5): the output reading of the sum of `1 2 3 4 5` is `15`. -/
theorem out5 : (sumImp g mono).readOut .sum _ rfl (5 : ℕ)
    ((sumImp g mono).denote .sum (5 : ℕ) (![1, 2, 3, 4, 5] : Fin 5 → ℝ)) () = (15 : ℝ) := by
  change ∑ i : Fin 5, (![1, 2, 3, 4, 5] : Fin 5 → ℝ) i = 15
  norm_num [Fin.sum_univ_succ]

end Good

namespace Twice

/--
warning: import_spec: `sumImp` is not declared, its `eq` has an open case:
import_fact: no theorem of this file closes the goal
  2 * ∑ i, v i = (GPUProof.Spec.sumReal g mono).f n (fun i => v (Fin.rev i)) o✝
-/
#guard_msgs in
/-- The mutant meaning `2 * ∑ i, v i` read as the sum of the vector read backwards: no theorem of
this file closes its `eq`, and `sum_rev`'s left side is not twice a sum, so it is not declared. -/
import_spec sumImp g mono : SumOp (n : ℕ) where
  /-- Twice the sum of a real vector. -/
  | sum (v : Fin n → ℝ) → (y : ℝ) := 2 * ∑ i, v i
    ↦ GPUProof.Spec.sumReal g mono
    from fun i => v i.rev
    at fun _ => y

/-- error: Unknown identifier `sumImp` -/
#guard_msgs in
#check sumImp

end Twice

end MojoProofTest.ImportSpec
