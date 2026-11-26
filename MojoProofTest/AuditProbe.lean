import MojoProof.Sem.Index

/-!
# A probe of the audit's equivalence count, duplicate comparison and instance search

scripts/Audit.lean counts as an equivalence a theorem `f = g` (or `f ↔ g`) between two different
definitions, as its conclusion or as a conjunct of it, except a `@[csimp]` theorem whose
right-hand side is a private definition: the code the compiler runs for the left-hand side, which
nothing else names. This module plants one theorem of each kind and a conjunction, and the audit
fails unless it classifies them so:

* `addZero_csimp`, a `@[csimp]` equality between two public definitions, must be counted;
* `zeroAdd_csimp`, a `@[csimp]` equality whose right-hand side is private, must not be;
* `addZero_and`, a conjunction whose second conjunct is an equation between two public
  definitions, must be counted;
* `evenA_iff`, an `iff` between two inductive predicates (`EvenA` and `EvenB`, the even numbers
  by the same two constructors), must be counted.
* `addZero_fixed`, `Function.IsFixedPt addZero (mulOne 0)`, an equation between two public
  definitions under a definition that unfolds to it, must be counted;
* `addZero_injective`, `Function.Injective addZero`, which unfolds to an equation between bound
  variables, must not be.

The definitions compute `n`, the predicates hold of the even numbers, and nothing else uses
them.

A row of scripts/laws.tsv exempts the pairs of definitions it lists in the one statement it
records. This module plants a law and the law's conjunction with an unexempted equation, and the
audit, with a row for each that exempts the pair `(double, twice)`, fails unless it classifies
them so:

* `double_twice`, the law, must not be counted;
* `double_and`, the law and the equation `addZero n = mulOne n`, must be counted;
* a row for `double_twice` with `double_and`'s statement, or with the pair `(addZero, mulOne)`,
  must be stale and exempt nothing.

The audit's `DUPTHM` compares statements also after unfolding reducible definitions. This module
plants two theorems whose statements differ only through the `abbrev` `pairAbbrev`, and the audit
fails unless it pairs them:

* `pairAbbrev_lt`, about `pairAbbrev`;
* `pair_lt`, the same statement about `pairAbbrev`'s value `(2, 3)`.

The audit's `DUPDEF` compares two definitions with the auxiliary constants they use renamed. Lean
shares a `match` between two definitions with the same patterns, and the shared matcher calls a
helper under the first definition's name. This module plants two such definitions, and the audit
fails unless it pairs them:

* `pickA`, the first, which owns the matcher's helper;
* `pickB`, the same definition, whose matcher is `pickA`'s.

The audit's `instances` search reports a theorem whose statement is an instance of a library
theorem's statement and whose proof does not use it. This module plants one of each kind, both
instances of `MojoProof.Sem.outS_of_lt` at width 8, and the audit fails unless it reports
exactly the first:

* `outS_eight`, proved again by unfolding `outS`, must be reported;
* `outS_eight_of_lt`, the one-line corollary `outS_of_lt hk`, must not be.

The audit compares the probe's theorems and definitions for duplicates only with each other, and reports their
instances apart, so no count includes them.
-/

namespace MojoProofTest.AuditProbe

/-- `n + 0`, for every natural `n`: the left-hand side of the probe's public `@[csimp]`
equality. -/
def addZero (n : Nat) : Nat := n + 0

/-- `n`, for every natural `n`, written `n * 1`: the public right-hand side of
`addZero_csimp`. -/
def mulOne (n : Nat) : Nat := n * 1

/-- **A `@[csimp]` equality between two public definitions, which the audit counts as an
equivalence**: `addZero` and `mulOne` are the same function. -/
@[csimp] theorem addZero_csimp : @addZero = @mulOne := by
  funext n
  simp [addZero, mulOne]

/-- `0 + n`, for every natural `n`: the left-hand side of the probe's `@[csimp]` equality with a
private right-hand side. -/
def zeroAdd (n : Nat) : Nat := 0 + n

/-- `n`, written `1 * n`: the private code compiled for `zeroAdd`. -/
private def oneMul (n : Nat) : Nat := 1 * n

/-- **A `@[csimp]` equality whose right-hand side is private, which the audit does not count**:
`zeroAdd` and the private `oneMul` are the same function. -/
@[csimp] theorem zeroAdd_csimp : @zeroAdd = @oneMul := by
  funext n
  simp [zeroAdd, oneMul]

/-- **An equation between two public definitions as a conjunct, which the audit counts as an
equivalence**: for every natural `n`, `addZero n` is `n`, and it is `mulOne n`. -/
theorem addZero_and (n : Nat) : addZero n = n ∧ addZero n = mulOne n :=
  ⟨rfl, by simp [addZero, mulOne]⟩

/-- The even natural numbers, by `zero` and `add_two`: the left-hand side of the probe's `iff`
between two inductive predicates. -/
inductive EvenA : Nat → Prop
  /-- `0` is even. -/
  | zero : EvenA 0
  /-- `n + 2` is even when `n` is. -/
  | add_two {n : Nat} : EvenA n → EvenA (n + 2)

/-- The even natural numbers again, by the same two constructors: the right-hand side of the
probe's `iff` between two inductive predicates. -/
inductive EvenB : Nat → Prop
  /-- `0` is even. -/
  | zero : EvenB 0
  /-- `n + 2` is even when `n` is. -/
  | add_two {n : Nat} : EvenB n → EvenB (n + 2)

/-- **An `iff` between two inductive predicates, which the audit counts as an equivalence**: for
every natural `n`, `EvenA n` holds exactly when `EvenB n` does. -/
theorem evenA_iff {n : Nat} : EvenA n ↔ EvenB n := by
  constructor <;> intro h <;> induction h <;> constructor <;> assumption

/-- **A fixed point, which the audit counts as an equivalence**:
`Function.IsFixedPt addZero (mulOne 0)`, which is the equation `addZero (mulOne 0) = mulOne 0`
between two public definitions once `Function.IsFixedPt` is unfolded. -/
theorem addZero_fixed : Function.IsFixedPt addZero (mulOne 0) :=
  show addZero (mulOne 0) = mulOne 0 from rfl

/-- **An injectivity, which the audit does not count**: `Function.Injective addZero`, which
unfolds to `addZero a = addZero b → a = b`, an equation between two bound variables. -/
theorem addZero_injective : Function.Injective addZero := fun a b h => by
  simpa [addZero] using h

/-- `n + n`, for every natural `n`: one side of the probe's law. -/
def double (n : Nat) : Nat := n + n

/-- `2 * n`, for every natural `n`: the other side of the probe's law. -/
def twice (n : Nat) : Nat := 2 * n

/-- **The probe's law, which a row exempts**: for every natural `n`, `double n` is `twice n`. -/
theorem double_twice (n : Nat) : double n = twice n := by
  unfold double twice
  omega

/-- **The probe's law with a further, unexempted equation, which the audit counts**: for every
natural `n`, `double n` is `twice n` and `addZero n` is `mulOne n`. A row that exempts the pair
`(double, twice)` in this statement leaves the pair `(addZero, mulOne)` counted. -/
theorem double_and (n : Nat) : double n = twice n ∧ addZero n = mulOne n :=
  ⟨double_twice n, by simp [addZero, mulOne]⟩

/-- Three values: the type the probe's two duplicate definitions match on. -/
inductive Three
  /-- The first value. -/
  | a
  /-- The second value. -/
  | b
  /-- The third value. -/
  | c

/-- **The first of the probe's duplicate definitions with a `match`**: 2 at `Three.a` and 1
elsewhere. -/
def pickA : Three → Nat
  | .a => 2
  | _ => 1

/-- **The second of the probe's duplicate definitions with a `match`**: `pickA` again, which the
audit must pair with it. -/
def pickB : Three → Nat
  | .a => 2
  | _ => 1

/-- The pair `(2, 3)` under a reducible name: the `abbrev` that the probe's two duplicate
theorems differ through. -/
abbrev pairAbbrev : Nat × Nat := (2, 3)

/-- **The first of the probe's duplicates behind an `abbrev`**: `pairAbbrev`'s first component is
below its second. -/
theorem pairAbbrev_lt : pairAbbrev.1 < pairAbbrev.2 := by decide

/-- **The second of the probe's duplicates behind an `abbrev`**: `pairAbbrev_lt`'s statement about
`(2, 3)` written out, which the audit must pair with it. -/
theorem pair_lt : (2, 3).1 < (2, 3).2 := by decide

/-- **The probe's specialization proved again**: a natural number `k` with `2 k < 2 ^ 8` is in
the signed range of 8 bits, by unfolding `outS`. Its statement is `MojoProof.Sem.outS_of_lt` at
`w = 8` and its proof does not use it, so the audit must report it. -/
theorem outS_eight {k : Nat} (hk : 2 * k < 2 ^ 8) : MojoProof.Sem.outS 8 k = false := by
  unfold MojoProof.Sem.outS
  simp only [Bool.not_eq_false', decide_eq_true_eq]
  constructor <;> omega

/-- **The probe's specialization as a corollary**: `outS_eight`'s statement, proved by
`MojoProof.Sem.outS_of_lt` at `w = 8`, which the audit must not report. -/
theorem outS_eight_of_lt {k : Nat} (hk : 2 * k < 2 ^ 8) : MojoProof.Sem.outS 8 k = false :=
  MojoProof.Sem.outS_of_lt hk

end MojoProofTest.AuditProbe
