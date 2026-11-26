import MojoProof.Float.CardSums
import MojoProofTest.FloatCanon

/-!
# Instances of the IEEE sums as canonical trees

Tests of `MojoProof.Float.sumFunctionEquiv`, `MojoProof.Float.card_sumFunction`,
`MojoProof.Float.card_canonTree` and `MojoProof.Float.card_sums`
(docs/proofs/float-reductions.md, statement 33), over `Fin 1` to `Fin 4` in binary16, binary32
and binary64:

* `class_l3`: the binary32 class of `(a + b) + c` (`l3`) goes to `canon l3`, by evaluation.
* `classes_ne`: the binary32 classes of `l3` and `a + (b + c)` (`r3`) differ, since their `canon`
  differ (`assoc_canon`): the bijection's injectivity at 3 leaves.
* `classes_eq`: the binary16 classes of `0 + 1` and `1 + 0` over `Fin 2` are one class, since
  their `canon` agree (by evaluation): the bijection's injectivity, for an equality, at 2 leaves.
* `card3`: in binary64 the number of sums of 3 inputs is the number of canonical trees over
  `Fin 3`.
* `canon1`, `canon2`: one canonical tree over `Fin 1` and one over `Fin 2`; so `card1`, `card2`:
  one binary32 sum of one input, and one binary16 sum of two inputs, by hand, without the count
  for every `n`.
* `canon3`, `canon4`: `card_canonTree` at 3 and 4 leaves, `3‼ = 3` and `5‼ = 15` canonical trees,
  by evaluation; `sums3`, `sums4`: `card_sums` at 3 inputs in binary32 and 4 in binary16, 3 and 15
  sums, by evaluation.
-/

namespace MojoProofTest.FloatCardSums

open MojoProof.Float FloatLib.Numerics FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.FloatCanon

/-- **The class of `l3` goes to `canon l3`**, in binary32: `sumFunctionEquiv` at the class of
`(a + b) + c`, by evaluation; a test at 3 leaves. -/
theorem class_l3 :
    (sumFunctionEquiv FloatFormat.isIEEE_binary32 3
      (Quotient.mk _ ⟨l3, by decide⟩)).1 = canon l3 :=
  rfl

/-- **`(a + b) + c` and `a + (b + c)` are different binary32 sums**: their classes differ, since
`sumFunctionEquiv` sends them to `canon l3 ≠ canon r3` (`assoc_canon`); a test at 3 leaves. -/
theorem classes_ne :
    (Quotient.mk (sumSetoid .binary32 3) ⟨l3, by decide⟩) ≠ Quotient.mk _ ⟨r3, by decide⟩ :=
  fun h => assoc_canon
    (congrArg Subtype.val (congrArg (sumFunctionEquiv FloatFormat.isIEEE_binary32 3) h))

/-- **`0 + 1` and `1 + 0` are one binary16 sum**: `sumFunctionEquiv` sends their classes to the
same canonical tree (by evaluation), so they are one class; a test at 2 leaves. -/
theorem classes_eq :
    (Quotient.mk (sumSetoid .binary16 2) ⟨.node (.leaf 0) (.leaf 1), by decide⟩) =
      Quotient.mk _ ⟨.node (.leaf 1) (.leaf 0), by decide⟩ :=
  (sumFunctionEquiv FloatFormat.isIEEE_binary16 2).injective (Subtype.ext (by
    show canon (.node (.leaf 0) (.leaf 1) : ReductionTree (Fin 2)) =
      canon (.node (.leaf 1) (.leaf 0))
    decide))

/-- **The number of binary64 sums of 3 inputs is the number of canonical trees over `Fin 3`**:
`card_sumFunction` in binary64; a test of the instance. -/
theorem card3 : Nat.card (SumFunction .binary64 3) = Nat.card (CanonTree 3) :=
  card_sumFunction FloatFormat.isIEEE_binary64 3

/-- **One canonical tree over one leaf**: the only tree over `Fin 1` using the index once is the
leaf `0` (a node has at least two leaves), and it is its own `canon`; a test at 1 leaf. -/
theorem canon1 : Nat.card (CanonTree 1) = 1 := by
  refine Nat.card_eq_one_iff_exists.mpr ⟨⟨.leaf 0, by decide, rfl⟩, ?_⟩
  rintro ⟨t, hp, hc⟩
  apply Subtype.ext
  have hl := hp.length_eq
  rcases t with x | ⟨l, r⟩
  · exact congrArg ReductionTree.leaf (Subsingleton.elim x 0)
  · simp only [ReductionTree.leaves, List.length_append, ReductionTree.length_leaves,
      List.length_finRange] at hl
    omega

/-- **One canonical tree over two leaves**: a tree over `Fin 2` using each index once is a node
of two leaves `a ≠ b` (by the leaf count), and it is its own `canon` only as `0 + 1` (by
evaluation over the four pairs `a, b`); a test at 2 leaves. -/
theorem canon2 : Nat.card (CanonTree 2) = 1 := by
  refine Nat.card_eq_one_iff_exists.mpr ⟨⟨.node (.leaf 0) (.leaf 1), by decide, by decide⟩, ?_⟩
  rintro ⟨t, hp, hc⟩
  apply Subtype.ext
  have hl := hp.length_eq
  rcases t with x | ⟨_ | ⟨l1, l2⟩, _ | ⟨r1, r2⟩⟩
  · simp [ReductionTree.leaves] at hl
  · rename_i a b
    show ReductionTree.node (.leaf a) (.leaf b) = .node (.leaf 0) (.leaf 1)
    revert hp hc
    revert a b
    decide
  all_goals
    simp only [ReductionTree.leaves, List.length_append, ReductionTree.length_leaves,
      List.length_finRange, List.length_singleton] at hl
    omega

/-- **One binary32 sum of one input**: `card_sumFunction` with `canon1`; a test at 1 leaf. -/
theorem card1 : Nat.card (SumFunction .binary32 1) = 1 :=
  (card_sumFunction FloatFormat.isIEEE_binary32 1).trans canon1

/-- **One binary16 sum of two inputs**: `card_sumFunction` with `canon2`, the count `(2n - 3)‼`
at `n = 2`; a test at 2 leaves. -/
theorem card2 : Nat.card (SumFunction .binary16 2) = 1 :=
  (card_sumFunction FloatFormat.isIEEE_binary16 2).trans canon2

/-- **Three canonical trees over three leaves**: `card_canonTree` at `n = 3`, `3‼ = 3` by
evaluation; a test at 3 leaves. -/
theorem canon3 : Nat.card (CanonTree 3) = 3 :=
  (card_canonTree (by decide)).trans (by decide)

/-- **Fifteen canonical trees over four leaves**: `card_canonTree` at `n = 4`, `5‼ = 15` by
evaluation; a test at 4 leaves. -/
theorem canon4 : Nat.card (CanonTree 4) = 15 :=
  (card_canonTree (by decide)).trans (by decide)

/-- **Three binary32 sums of three inputs**: `card_sums` in binary32 at `n = 3`, `3‼ = 3` by
evaluation; a test at 3 inputs. -/
theorem sums3 : Nat.card (SumFunction .binary32 3) = 3 :=
  (card_sums FloatFormat.isIEEE_binary32 (by decide)).trans (by decide)

/-- **Fifteen binary16 sums of four inputs**: `card_sums` in binary16 at `n = 4`, `5‼ = 15` by
evaluation; a test at 4 inputs. -/
theorem sums4 : Nat.card (SumFunction .binary16 4) = 15 :=
  (card_sums FloatFormat.isIEEE_binary16 (by decide)).trans (by decide)

end MojoProofTest.FloatCardSums
