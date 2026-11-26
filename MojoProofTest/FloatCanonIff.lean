import MojoProof.Float.CanonIff
import MojoProofTest.FloatCanon

/-!
# Instances of trees whose IEEE sums agree having the same canonical form

Tests of `MojoProof.Float.eval_add_eq_iff` (docs/proofs/float-reductions.md, statement 32), at
two sizes and three formats, and its mutant:

* `assoc_sep`: `(a + b) + c` and `a + (b + c)` over `Fin 3` (`l3`, `r3`), whose `canon` differ
  (`assoc_canon`), do not agree up to NaN payloads on every binary32 input: the `→` direction at
  3 leaves.
* `t6`, `t6s`, `t6r`: three trees over `Fin 6` with the same leaves. `t6s` is `t6` with the
  children of three nodes swapped; `t6r` splits the leaves at its root as `t6` does, regroups
  the three leaves of its left child and swaps its right child's children.
  `swap6` is the `←` direction in binary16 at `t6` and `t6s`, and `split6` the `→` direction in
  binary64 at `t6` and `t6r`.
* `eq_mutant`: with bitwise equality in place of `NaNEq` the statement fails at `0 + 1` and
  `1 + 0` over `Fin 2`: they have the same `canon`, and at the binary32 quiet NaNs `0x7fc00001`
  and `0x7fc00002` their sums differ (`MojoProofTest.FloatCanon.nan_add32`).
-/

namespace MojoProofTest.FloatCanonIff

open MojoProof.Float MojoProof.Sem FloatLib.Numerics FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatRel MojoProofTest.FloatCanon

/-- **`(a + b) + c` and `a + (b + c)` disagree on some binary32 input** beyond NaN payloads:
`eval_add_eq_iff` in binary32 at `l3` and `r3`, whose `canon` differ (`assoc_canon`), its
premises by evaluation; a test at 3 leaves. -/
theorem assoc_sep : ¬ ∀ v : Fin 3 → Model .binary32,
    NaNEq (l3.eval (fun x y => Model.add x y) v) (r3.eval (fun x y => Model.add x y) v) :=
  fun h => assoc_canon ((eval_add_eq_iff FloatFormat.isIEEE_binary32 (by decide) (by decide)).mp h)

/-- The tree `((0 + 1) + 2) + (3 + (4 + 5))` over `Fin 6`. -/
def t6 : ReductionTree (Fin 6) :=
  .node (.node (.node (.leaf 0) (.leaf 1)) (.leaf 2)) (.node (.leaf 3) (.node (.leaf 4) (.leaf 5)))

/-- `t6` with the children of its root, of `3 + (4 + 5)` and of `0 + 1` swapped:
`((4 + 5) + 3) + ((1 + 0) + 2)`. -/
def t6s : ReductionTree (Fin 6) :=
  .node (.node (.node (.leaf 4) (.leaf 5)) (.leaf 3)) (.node (.node (.leaf 1) (.leaf 0)) (.leaf 2))

/-- `t6` with its left child regrouped and its right child's children swapped:
`(0 + (1 + 2)) + ((4 + 5) + 3)`. -/
def t6r : ReductionTree (Fin 6) :=
  .node (.node (.leaf 0) (.node (.leaf 1) (.leaf 2))) (.node (.node (.leaf 4) (.leaf 5)) (.leaf 3))

/-- **`t6` and `t6s` agree up to NaN payloads on every binary16 input**: `eval_add_eq_iff` in
binary16, `←`, its premises and `canon t6 = canon t6s` by evaluation; a test at 6 leaves. -/
theorem swap6 : ∀ v : Fin 6 → Model .binary16,
    NaNEq (t6.eval (fun x y => Model.add x y) v) (t6s.eval (fun x y => Model.add x y) v) :=
  (eval_add_eq_iff FloatFormat.isIEEE_binary16 (by decide) (by decide)).mpr (by decide)

/-- **`t6` and `t6r` disagree on some binary64 input** beyond NaN payloads: `eval_add_eq_iff` in
binary64, `→`, its premises and `canon t6 ≠ canon t6r` by evaluation; a test at 6 leaves, where
the roots split the leaves alike and the separating input comes from the left children. -/
theorem split6 : ¬ ∀ v : Fin 6 → Model .binary64,
    NaNEq (t6.eval (fun x y => Model.add x y) v) (t6r.eval (fun x y => Model.add x y) v) :=
  fun h => (by decide : canon t6 ≠ canon t6r)
    ((eval_add_eq_iff FloatFormat.isIEEE_binary64 (by decide) (by decide)).mp h)

/-- **The mutant with bitwise equality fails**: `0 + 1` and `1 + 0` over `Fin 2` have the same
`canon` (by evaluation), but their binary32 sums at the quiet NaNs `0x7fc00001` and `0x7fc00002`
differ (`nan_add32`); a test of one pair of trees. -/
theorem eq_mutant :
    canon (.node (.leaf 0) (.leaf 1) : ReductionTree (Fin 2)) = canon (.node (.leaf 1) (.leaf 0)) ∧
      ¬ ∀ v : Fin 2 → Model .binary32,
        (ReductionTree.node (.leaf 0) (.leaf 1)).eval (fun x y => Model.add x y) v =
          (ReductionTree.node (.leaf 1) (.leaf 0)).eval (fun x y => Model.add x y) v :=
  ⟨by decide, fun h => nan_add32 (h ![f32 0x7fc00001, f32 0x7fc00002])⟩

end MojoProofTest.FloatCanonIff
