import MojoProof.Import.Command
import MojoProofTest.ImportFacts

/-!
# `import_spec` at a spec with a domain, with a bridge of an imported module

`import_spec` (MojoProof/Import/Command.lean) closes its importer's `eq` with a theorem found by
its type (`import_fact`), in a context with the hypothesis that the input reading is in the
spec's domain. Here one operation, the truncated difference `a - b` of two natural vectors, is
proposed as `MojoProofTest.ImportFacts.diffInt`, the difference of two integer vectors, with the
vectors read as integers. The two agree only on `diffInt`'s domain (`b i ≤ a i` at every `i`), and
the bridge `sub_cast` of MojoProofTest/ImportFacts.lean has that domain as its premise; its output
has type `Fin n`, the goal's `diffInt.Out n` once `diffInt` is unfolded.

* `Bare`: the command without `using`. `sub_cast` is not a theorem of this file, so no theorem
  tried closes `eq`: the importer is not declared, and the command warns with the open goal
  (`#guard_msgs`).
* `Good`: the same command `using sub_cast`, declared with no clause written by hand: its `eq`
  takes `sub_cast`'s premise from the domain hypothesis. `eq3` and `eq5` are its `eq` at
  `a = 5 2 7`, `b = 1 2 3` and at `a = 9 4 6 1 8`, `b = 0 4 2 1 3`, both in the domain (by
  `decide`), whose outputs `out3` and `out5` are `4 0 4` and `9 0 4 0 5` (by `decide`). `off3`:
  at `a = 1 2 7`, `b = 2 2 3`, out of the domain, the truncated difference is `0 0 4` and
  `diffInt`'s function `-1 0 4`, so `eq` holds only with its domain hypothesis; `off5`: at
  `a = 9 4 6 1 8`, `b = 0 5 2 1 3`, out of the domain.
* `Strict`: the same command `using sub_strict`, whose premise `b i < a i` the domain hypothesis
  does not give: not declared, with the open goal (`#guard_msgs`).
* `Far`: the same command `using sub_zero_add`, stated over `Fin (0 + n)`, which is `Fin n` only by
  the equation `0 + n = n`: its arguments' types are not the goal's terms' types, so it is not
  declared, with the open goal (`#guard_msgs`).

Tests at sizes 3 and 5, at the spec `diffInt`.
-/

namespace MojoProofTest.ImportDom

open MojoProofTest.ImportFacts

namespace Bare

/--
warning: import_spec: `subImp` is not declared, its `eq` has an open case:
import_fact: no theorem of this file closes the goal
  ↑((a - b) o✝) = diffInt.f n (Sum.elim (fun i => ↑(a i)) fun i => ↑(b i)) o✝
-/
#guard_msgs in
/-- The truncated difference proposed as `diffInt`, without `using`: no theorem of this file
closes its `eq`, so it is not declared. -/
import_spec subImp : SubOp (n : ℕ) where
  /-- The truncated difference of two natural vectors. -/
  | sub (a : Fin n → ℕ) (b : Fin n → ℕ) → (y : Fin n → ℕ) := a - b
    ↦ diffInt
    from Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)
    at fun i => (y i : ℤ)

/-- error: Unknown identifier `subImp` -/
#guard_msgs in
#check subImp

end Bare

namespace Good

/-- The truncated difference proposed as `diffInt`, its `eq` closed by `sub_cast` of
MojoProofTest/ImportFacts.lean, given by `using`, at the domain hypothesis. -/
import_spec subImp : SubOp (n : ℕ) using sub_cast where
  /-- The truncated difference of two natural vectors. -/
  | sub (a : Fin n → ℕ) (b : Fin n → ℕ) → (y : Fin n → ℕ) := a - b
    ↦ diffInt
    from Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)
    at fun i => (y i : ℤ)

/-- **`eq` at size 3** (test at 3): at `a = 5 2 7` and `b = 1 2 3`, in `diffInt`'s domain (by
`decide`), the output reading of the truncated difference is `diffInt`'s function at the integer
readings. -/
theorem eq3 : subImp.readOut .sub _ rfl (3 : ℕ)
      (subImp.denote .sub (3 : ℕ) ((![5, 2, 7], ![1, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))) =
    diffInt.f 3
      (subImp.readIn .sub _ rfl (3 : ℕ) ((![5, 2, 7], ![1, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))) :=
  subImp.eq .sub _ rfl (3 : ℕ) ((![5, 2, 7], ![1, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))
    (by show ∀ i : Fin 3, (((![1, 2, 3] : Fin 3 → ℕ) i : ℕ) : ℤ) ≤ ((![5, 2, 7] : Fin 3 → ℕ) i : ℕ)
        decide)

/-- **The difference at size 3** (test at 3): the output reading of the truncated difference of
`5 2 7` and `1 2 3` is `4 0 4`. By `decide`. -/
theorem out3 : @Eq (Fin 3 → ℤ) (subImp.readOut .sub _ rfl (3 : ℕ)
    (subImp.denote .sub (3 : ℕ) ((![5, 2, 7], ![1, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))))
    ![4, 0, 4] := by
  show (fun i => (((![5, 2, 7] - ![1, 2, 3] : Fin 3 → ℕ) i : ℕ) : ℤ)) = ![4, 0, 4]
  decide

/-- **`eq` at size 5** (test at 5): at `a = 9 4 6 1 8` and `b = 0 4 2 1 3`, in `diffInt`'s domain
(by `decide`), the output reading of the truncated difference is `diffInt`'s function at the
integer readings. -/
theorem eq5 : subImp.readOut .sub _ rfl (5 : ℕ) (subImp.denote .sub (5 : ℕ)
      ((![9, 4, 6, 1, 8], ![0, 4, 2, 1, 3]) : (Fin 5 → ℕ) × (Fin 5 → ℕ))) =
    diffInt.f 5 (subImp.readIn .sub _ rfl (5 : ℕ)
      ((![9, 4, 6, 1, 8], ![0, 4, 2, 1, 3]) : (Fin 5 → ℕ) × (Fin 5 → ℕ))) :=
  subImp.eq .sub _ rfl (5 : ℕ) ((![9, 4, 6, 1, 8], ![0, 4, 2, 1, 3]) : (Fin 5 → ℕ) × (Fin 5 → ℕ))
    (by show ∀ i : Fin 5, (((![0, 4, 2, 1, 3] : Fin 5 → ℕ) i : ℕ) : ℤ) ≤
          ((![9, 4, 6, 1, 8] : Fin 5 → ℕ) i : ℕ)
        decide)

/-- **The difference at size 5** (test at 5): the output reading of the truncated difference of
`9 4 6 1 8` and `0 4 2 1 3` is `9 0 4 0 5`. By `decide`. -/
theorem out5 : @Eq (Fin 5 → ℤ) (subImp.readOut .sub _ rfl (5 : ℕ) (subImp.denote .sub (5 : ℕ)
    ((![9, 4, 6, 1, 8], ![0, 4, 2, 1, 3]) : (Fin 5 → ℕ) × (Fin 5 → ℕ))))
    ![9, 0, 4, 0, 5] := by
  show (fun i => (((![9, 4, 6, 1, 8] - ![0, 4, 2, 1, 3] : Fin 5 → ℕ) i : ℕ) : ℤ)) =
    ![9, 0, 4, 0, 5]
  decide

/-- **Out of the domain, `eq`'s conclusion fails** (test at 3): at `a = 1 2 7` and `b = 2 2 3`,
not in `diffInt`'s domain (`2 ≤ 1` fails at `0`), the output reading of the truncated difference
is `0 0 4` and `diffInt`'s function at the integer readings is `-1 0 4`. By `decide`. -/
theorem off3 :
    ¬ diffInt.Dom 3
        (subImp.readIn .sub _ rfl (3 : ℕ) ((![1, 2, 7], ![2, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))) ∧
      @Eq (Fin 3 → ℤ) (subImp.readOut .sub _ rfl (3 : ℕ)
        (subImp.denote .sub (3 : ℕ) ((![1, 2, 7], ![2, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))))
        ![0, 0, 4] ∧
      @Eq (Fin 3 → ℤ) (diffInt.f 3
        (subImp.readIn .sub _ rfl (3 : ℕ) ((![1, 2, 7], ![2, 2, 3]) : (Fin 3 → ℕ) × (Fin 3 → ℕ))))
        ![-1, 0, 4] :=
  ⟨fun h => (by decide : ¬ ((2 : ℕ) : ℤ) ≤ ((1 : ℕ) : ℤ)) (h 0),
    show (fun i => (((![1, 2, 7] - ![2, 2, 3] : Fin 3 → ℕ) i : ℕ) : ℤ)) = ![0, 0, 4] by decide,
    show (fun i => (((![1, 2, 7] : Fin 3 → ℕ) i : ℕ) : ℤ) - ((![2, 2, 3] : Fin 3 → ℕ) i : ℕ)) =
      ![-1, 0, 4] by decide⟩

/-- **Out of the domain at size 5** (test at 5): at `a = 9 4 6 1 8` and `b = 0 5 2 1 3`, the
input reading is not in `diffInt`'s domain (`5 ≤ 4` fails at `1`). By `decide`. -/
theorem off5 : ¬ diffInt.Dom 5 (subImp.readIn .sub _ rfl (5 : ℕ)
    ((![9, 4, 6, 1, 8], ![0, 5, 2, 1, 3]) : (Fin 5 → ℕ) × (Fin 5 → ℕ))) :=
  fun h => (by decide : ¬ ((5 : ℕ) : ℤ) ≤ ((4 : ℕ) : ℤ)) (h 1)

end Good

namespace Strict

/--
warning: import_spec: `subImp` is not declared, its `eq` has an open case:
import_fact: neither `sub_strict` nor a theorem of this file closes the goal
  ↑((a - b) o✝) = diffInt.f n (Sum.elim (fun i => ↑(a i)) fun i => ↑(b i)) o✝
-/
#guard_msgs in
/-- The truncated difference proposed as `diffInt`, with `sub_strict` given by `using`: its
premise `b i < a i` is not the domain hypothesis `b i ≤ a i`, so it is not declared. -/
import_spec subImp : SubOp (n : ℕ) using sub_strict where
  /-- The truncated difference of two natural vectors. -/
  | sub (a : Fin n → ℕ) (b : Fin n → ℕ) → (y : Fin n → ℕ) := a - b
    ↦ diffInt
    from Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)
    at fun i => (y i : ℤ)

/-- error: Unknown identifier `subImp` -/
#guard_msgs in
#check subImp

end Strict

namespace Far

/--
warning: import_spec: `subImp` is not declared, its `eq` has an open case:
import_fact: neither `sub_zero_add` nor a theorem of this file closes the goal
  ↑((a - b) o✝) = diffInt.f n (Sum.elim (fun i => ↑(a i)) fun i => ↑(b i)) o✝
-/
#guard_msgs in
/-- The truncated difference proposed as `diffInt`, with `sub_zero_add` given by `using`: its
vectors and output are over `Fin (0 + n)`, not `Fin n` by unfolding, so it is not declared. -/
import_spec subImp : SubOp (n : ℕ) using sub_zero_add where
  /-- The truncated difference of two natural vectors. -/
  | sub (a : Fin n → ℕ) (b : Fin n → ℕ) → (y : Fin n → ℕ) := a - b
    ↦ diffInt
    from Sum.elim (fun i => (a i : ℤ)) fun i => (b i : ℤ)
    at fun i => (y i : ℤ)

/-- error: Unknown identifier `subImp` -/
#guard_msgs in
#check subImp

end Far

end MojoProofTest.ImportDom
