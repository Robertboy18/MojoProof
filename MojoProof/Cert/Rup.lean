/-!
# RUP certificates the kernel checks

The kernel-only path for SAT-backed obligations: an untrusted SAT solver writes an
unsatisfiability proof of a formula in the RUP fragment of LRAT, and `unsat` turns
`check (number F) p = true`, proved by `decide +kernel` (the kernel evaluates `check`; no
`Lean.ofReduceBool`, no compiled evaluation), into: no assignment satisfies `F`.

Std's LRAT checker (`Std.Tactic.BVDecide.LRAT.check`, proved sound in Std) cannot serve: the
kernel does not reduce it past the first step (its loop recurses on an index by well-founded
recursion and its assignments are `Std.HashMap`s), and Std's bitblaster
(`BVLogicalExpr.bitblast`, a hash-consed AIG) does not reduce at all, even on a 2-bit `x = x`
(tried with `decide +kernel`, Lean v4.35.0). `check` here uses lists and structural recursion
only.

* A literal `(v, b)` is variable `v` with polarity `b`; a clause is a list of literals; the
  formula `check` reads is a list of clauses with their numbers (`number` numbers an input
  formula 1, 2, ... in order, as LRAT does).
* `prop` is unit propagation along hint clauses, `rup` the reverse-unit-propagation check of one
  clause, `check` a certificate: added clauses (each checked by `rup` against the clauses so far)
  and deletions, up to the empty clause.

Proved, for every formula and certificate: `rup_sound` (a clause `rup` accepts holds in every
assignment that satisfies the formula), `check_sound` and `unsat` (a certificate `check` accepts
leaves no satisfying assignment).

Not yet: RAT steps; the lowering from the symbolic expression DAG to CNF, which must also be
kernel-evaluable and proved; the solver run as a command (the instance in `MojoProofTest/Cert.lean`
is written by hand).
-/

namespace MojoProof.Cert

/-- A literal: a variable and its polarity. -/
abbrev Lit := Nat × Bool

/-- Assignment `a` makes literal `l` true. -/
def Lit.holds (a : Nat → Bool) (l : Lit) : Bool := a l.1 == l.2

/-- Assignment `a` makes a literal of clause `c` true. -/
def holds (a : Nat → Bool) (c : List Lit) : Bool := c.any (Lit.holds a)

/-- Unit propagation along the hint clauses `hs` (numbers in `F`) from the true literals `t`:
`true` if it reaches a conflict, a hint clause whose literals `t` all makes false. Every earlier
hint clause must have all its literals false but one, which becomes true. -/
def prop (F : List (Nat × List Lit)) (t : List Lit) : List Nat → Bool
  | [] => false
  | h :: hs => match F.lookup h with
    | none => false
    | some c => match c.filter fun l => !t.contains (l.1, !l.2) with
      | [] => true
      | [l] => prop F (l :: t) hs
      | _ => false

/-- Clause `c` follows from `F` by reverse unit propagation with hints `hs`: propagation from the
negations of its literals reaches a conflict. -/
def rup (F : List (Nat × List Lit)) (c : List Lit) (hs : List Nat) : Bool :=
  prop F (c.map fun l => (l.1, !l.2)) hs

/-- A step of a certificate: add clause `c` as number `i`, checked by `rup` with hints `hs`, or
delete the clauses numbered `ids`. -/
inductive Step
  /-- Add clause `c` as number `i`, checked by `rup` with the hints `hs`. -/
  | add (i : Nat) (c : List Lit) (hs : List Nat)
  /-- Delete the clauses numbered `ids`. -/
  | del (ids : List Nat)

/-- Certificate `p` refutes the numbered clauses `F`: every added clause passes `rup` against the
clauses before it, up to an added empty clause. -/
def check (F : List (Nat × List Lit)) : List Step → Bool
  | [] => false
  | .add _ [] hs :: _ => rup F [] hs
  | .add i c hs :: p => rup F c hs && check ((i, c) :: F) p
  | .del ids :: p => check (F.filter fun x => !ids.contains x.1) p

/-- The clauses of `F` numbered 1, 2, ... in order, as LRAT numbers its input. -/
def number (F : List (List Lit)) : List (Nat × List Lit) := (F.zipIdx 1).map fun (c, i) => (i, c)

/-- The negation of literal `l` holds under assignment `a` exactly when `l` does not. -/
theorem neg_holds {a : Nat → Bool} {l : Lit} : Lit.holds a (l.1, !l.2) = !Lit.holds a l := by
  rcases l with ⟨v, b⟩; simp only [Lit.holds]; cases b <;> cases a v <;> rfl

/-- Propagation that reaches a conflict leaves no assignment satisfying `F` that makes all of
`t` true. -/
theorem prop_sound {F : List (Nat × List Lit)} {a : Nat → Bool}
    (hF : ∀ x ∈ F, holds a x.2 = true) :
    ∀ {t : List Lit} {hs : List Nat}, prop F t hs = true → (∀ l ∈ t, l.holds a = true) → False
  | _, [], h, _ => by simp [prop] at h
  | t, k :: hs, h, ht => by
    simp only [prop] at h
    split at h
    · cases h
    · rename_i c hc
      have hm : (k, c) ∈ F := by
        obtain ⟨_, _, rfl, _⟩ := List.lookup_eq_some_iff.1 hc; simp
      obtain ⟨l, hl, hla⟩ := List.any_eq_true.1 (hF _ hm)
      have hlf : l ∈ c.filter fun l => !t.contains (l.1, !l.2) := by
        refine List.mem_filter.2 ⟨hl, ?_⟩
        cases hn : t.contains (l.1, !l.2)
        · rfl
        · have := ht _ (List.contains_iff_mem.1 hn)
          rw [neg_holds, hla] at this; cases this
      split at h
      · rename_i he; rw [he] at hlf; cases hlf
      · rename_i l' he
        rw [he, List.mem_singleton] at hlf
        subst hlf
        exact prop_sound hF h fun x hx => by
          rcases List.mem_cons.1 hx with rfl | hx
          · exact hla
          · exact ht x hx
      · cases h

/-- A clause `rup` accepts holds in every assignment that satisfies `F`. -/
theorem rup_sound {F : List (Nat × List Lit)} {c : List Lit} {hs : List Nat} {a : Nat → Bool}
    (h : rup F c hs = true) (hF : ∀ x ∈ F, holds a x.2 = true) : holds a c = true := by
  cases hc : holds a c
  · refine (prop_sound hF h fun l hl => ?_).elim
    obtain ⟨l, hm, rfl⟩ := List.mem_map.1 hl
    have : l.holds a = false := by
      simp only [holds, List.any_eq_false] at hc
      simpa using hc l hm
    rw [neg_holds, this]; rfl
  · rfl

/-- A certificate `check` accepts leaves no assignment satisfying `F`. -/
theorem check_sound {a : Nat → Bool} :
    ∀ {F : List (Nat × List Lit)} {p : List Step}, check F p = true →
      (∀ x ∈ F, holds a x.2 = true) → False
  | _, [], h, _ => by simp [check] at h
  | F, .add i [] hs :: p, h, hF => by
    simp only [check] at h
    simpa [holds] using rup_sound h hF
  | F, .add i (l :: c) hs :: p, h, hF => by
    simp only [check, Bool.and_eq_true] at h
    refine check_sound (a := a) h.2 fun x hx => ?_
    rcases List.mem_cons.1 hx with rfl | hx
    · exact rup_sound h.1 hF
    · exact hF x hx
  | F, .del ids :: p, h, hF => by
    simp only [check] at h
    exact check_sound (a := a) h fun x hx => hF x (List.mem_filter.1 hx).1

/-- A certificate `check` accepts for formula `F` refutes it: no assignment satisfies every
clause. -/
theorem unsat {F : List (List Lit)} {p : List Step} (h : check (number F) p = true)
    (a : Nat → Bool) : F.all (holds a) = false := by
  cases hF : F.all (holds a)
  · rfl
  · refine (check_sound (a := a) h fun x hx => ?_).elim
    obtain ⟨⟨c, i⟩, hm, rfl⟩ := List.mem_map.1 hx
    exact List.all_eq_true.1 hF c (List.fst_mem_of_mem_zipIdx hm)

end MojoProof.Cert
