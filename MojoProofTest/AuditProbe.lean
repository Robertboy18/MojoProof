import MojoProof.Sem.Index

/-!
# A probe of the audit's equivalence count, duplicate comparison and instance search

scripts/Audit.lean counts as an equivalence a theorem `f = g` (or `f ↔ g`) between two different
definitions, except a `@[csimp]` theorem whose right-hand side is a private definition: the code
the compiler runs for the left-hand side, which nothing else names. This module plants one
theorem of each kind, and the audit fails unless it classifies them so:

* `addZero_csimp`, a `@[csimp]` equality between two public definitions, must be counted;
* `zeroAdd_csimp`, a `@[csimp]` equality whose right-hand side is private, must not be.

The definitions compute `n` and are used by nothing else.

The audit's `DUPTHM` compares statements also after unfolding reducible definitions. This module
plants two theorems whose statements differ only through the `abbrev` `pairAbbrev`, and the audit
fails unless it pairs them:

* `pairAbbrev_lt`, about `pairAbbrev`;
* `pair_lt`, the same statement about `pairAbbrev`'s value `(2, 3)`.

The audit's `instances` search reports a theorem whose statement is an instance of a library
theorem's statement and whose proof does not use it. This module plants one of each kind, both
instances of `MojoProof.Sem.outS_of_lt` at width 8, and the audit fails unless it reports
exactly the first:

* `outS_eight`, proved again by unfolding `outS`, must be reported;
* `outS_eight_of_lt`, the one-line corollary `outS_of_lt hk`, must not be.

The audit compares the probe's theorems for duplicates only with each other, and reports their
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
