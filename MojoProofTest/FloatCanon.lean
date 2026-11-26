import MojoProof.Float.Canon
import MojoProofTest.FloatRel

/-!
# Instances of commutativity up to NaN payloads and of canonical trees

Tests of one example each (docs/proofs/float-reductions.md, statements 27 to 31):

* `nan_add32`, `nan_add16`: `Model.add x y ≠ Model.add y x` at two quiet NaNs of different
  payloads, in binary32 (`0x7fc00001`, `0x7fc00002`) and in binary16 (`0x7e01`, `0x7e02`), by
  evaluation: `add_comm_nanEq`'s `NaNEq` is not equality.
* `canon3`, `canon5`: `canon` of a tree of 3 natural-number leaves (`t3`) and of 5 (`t5`), by
  evaluation, and `canon` of the result is the result.
* `swap5`: `eval_nanEq_of_canon` at `t5` and `t5s`, `t5` with the children of four of its nodes
  swapped, in every format, its premise `canon t5 = canon t5s` by evaluation.
* `assoc_canon`, `assoc_vals`, `assoc_ne`: the trees `(a + b) + c` and `a + (b + c)` (`l3`, `r3`)
  have different `canon`, and their binary32 sums at `a = 1`, `b = 2 ^ 24`, `c = -2 ^ 24` are `+0`
  and `1`, not `NaNEq`: `eval_canon_nanEq`'s relation does not hold between all trees with the
  same leaves.
-/

namespace MojoProofTest.FloatCanon

open MojoProof.Float MojoProof.Sem FloatLib.Numerics FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatRel

/-- At the binary32 quiet NaNs `0x7fc00001` and `0x7fc00002`, `Model.add` returns the first
operand, so the two orders give different words, by evaluation: a test of one example. -/
theorem nan_add32 :
    Model.add (f32 0x7fc00001) (f32 0x7fc00002) ≠ Model.add (f32 0x7fc00002) (f32 0x7fc00001) := by
  decide +kernel

/-- The binary16 word with bits `n`. -/
def f16 (n : Nat) : Model .binary16 := Model.ofNatBits n

/-- At the binary16 quiet NaNs `0x7e01` and `0x7e02`, the two orders of `Model.add` give
different words, by evaluation: a test of one example. -/
theorem nan_add16 :
    Model.add (f16 0x7e01) (f16 0x7e02) ≠ Model.add (f16 0x7e02) (f16 0x7e01) := by
  decide +kernel

/-- The tree `(2 + 0) + 1` of three natural-number leaves. -/
def t3 : ReductionTree Nat := .node (.node (.leaf 2) (.leaf 0)) (.leaf 1)

/-- `canon t3` is `1 + (0 + 2)`, and `canon` of it is itself, by evaluation: a test of one
example. -/
theorem canon3 :
    canon t3 = .node (.leaf 1) (.node (.leaf 0) (.leaf 2)) ∧
      canon (.node (.leaf 1) (.node (.leaf 0) (.leaf 2)) : ReductionTree Nat) =
        .node (.leaf 1) (.node (.leaf 0) (.leaf 2)) := by
  decide

/-- The tree `(4 + (3 + 1)) + (0 + 2)` of five natural-number leaves. -/
def t5 : ReductionTree Nat :=
  .node (.node (.leaf 4) (.node (.leaf 3) (.leaf 1))) (.node (.leaf 0) (.leaf 2))

/-- `canon t5` is `(0 + 2) + (4 + (1 + 3))`, and `canon` of it is itself, by evaluation: a test of
one example. -/
theorem canon5 :
    canon t5 = .node (.node (.leaf 0) (.leaf 2)) (.node (.leaf 4) (.node (.leaf 1) (.leaf 3))) ∧
      canon (.node (.node (.leaf 0) (.leaf 2)) (.node (.leaf 4) (.node (.leaf 1) (.leaf 3))) :
        ReductionTree Nat) =
        .node (.node (.leaf 0) (.leaf 2)) (.node (.leaf 4) (.node (.leaf 1) (.leaf 3))) := by
  decide

/-- `t5` with the children of its root, of `0 + 2`, of `4 + (3 + 1)` and of `3 + 1` swapped:
`(2 + 0) + ((1 + 3) + 4)`. -/
def t5s : ReductionTree Nat :=
  .node (.node (.leaf 2) (.leaf 0)) (.node (.node (.leaf 1) (.leaf 3)) (.leaf 4))

/-- `t5` and `t5s` have the same IEEE sums up to NaN payloads, in every format and at every
values: `eval_nanEq_of_canon` with `canon t5 = canon t5s` by evaluation, a test of one pair of
trees. -/
theorem swap5 {fmt : FloatFormat} (v : Nat → Model fmt) :
    NaNEq (t5.eval (fun x y => Model.add x y) v) (t5s.eval (fun x y => Model.add x y) v) :=
  eval_nanEq_of_canon (by decide) v

/-- The tree `(a + b) + c` over the leaves `0, 1, 2` of `Fin 3`. -/
def l3 : ReductionTree (Fin 3) := .node (.node (.leaf 0) (.leaf 1)) (.leaf 2)

/-- The tree `a + (b + c)` over the leaves `0, 1, 2` of `Fin 3`. -/
def r3 : ReductionTree (Fin 3) := .node (.leaf 0) (.node (.leaf 1) (.leaf 2))

/-- `l3` and `r3` are not swaps of each other: their `canon` differ, by evaluation, a test of one
pair of trees. -/
theorem assoc_canon : canon l3 ≠ canon r3 := by
  decide

/-- The binary32 inputs `1`, `2 ^ 24`, `-2 ^ 24` (`0x3f800000`, `0x4b800000`, `0xcb800000`). -/
def abc : Fin 3 → Model .binary32 := ![f32 0x3f800000, f32 0x4b800000, f32 0xcb800000]

/-- At `abc`, `(a + b) + c` is `+0` (`1 + 2 ^ 24` rounds to `2 ^ 24`, the even neighbour) and
`a + (b + c)` is `1`, by evaluation: a test of one example. -/
theorem assoc_vals :
    l3.eval (fun x y => Model.add x y) abc = f32 0 ∧
      r3.eval (fun x y => Model.add x y) abc = f32 0x3f800000 := by
  decide +kernel

/-- At `abc`, the binary32 sums along `l3` and `r3` are not `NaNEq` (`assoc_vals`; neither is a
NaN), a test of one example: trees with the same leaves but different `canon` need not agree. -/
theorem assoc_ne :
    ¬ NaNEq (l3.eval (fun x y => Model.add x y) abc) (r3.eval (fun x y => Model.add x y) abc) := by
  rw [assoc_vals.1, assoc_vals.2]
  unfold NaNEq GPUProof.UpToNaN
  decide +kernel

end MojoProofTest.FloatCanon
