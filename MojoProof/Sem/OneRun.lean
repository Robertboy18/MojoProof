import Mathlib.Logic.Relation

/-!
# One run suffices

For every type, step relation `r`, equivalence `e` and set `Bad`: if `r` is `Confluent` up to
`e` with `Bad` persistent (`e` an equivalence and a simulation for `r`, `Bad` closed under `e` and
under steps, and two steps from one state equivalent, or both bad, or joined by one more step
each up to `e`, or both leading in one more step to bad states), then one run of `n` steps from
`a` to a normal form `z` that is not bad gives (`Confluent.one_run`):

* every run from `a` is finite;
* no state reachable from `a` is bad;
* every normal form reachable from `a` is equivalent to `z`;
* every state reachable from `a` reaches a state equivalent to `z` in at most `n` steps.

Read backwards (`Confluent.bad_normal`): if some state reachable from `a` is bad, so is every
normal form reachable from `a`. A run is a chain of steps (`Path.exists_iff`), and a run from a
state reachable from `a₀` is a run, of the same length, of the steps between states reachable
from `a₀` (`Path.lift`).

This is Newman's random descent with an equivalence and a bad set, not a new principle. The proof
is in docs/proofs/one-run.md; `Grid.sound_of_one_run` (MojoProof/Sem/Trace.lean) applies it to
grids.
-/

namespace MojoProof.Sem

open Relation

section OneRun

variable {α : Type*}

/-- A run of exactly `n` steps. -/
inductive Path (r : α → α → Prop) : Nat → α → α → Prop
  /-- The run of no steps from `a` to itself. -/
  | nil (a : α) : Path r 0 a a
  /-- A step from `a` to `b`, then a run of `n` steps from `b` to `c`. -/
  | cons {n : Nat} {a b c : α} : r a b → Path r n b c → Path r (n + 1) a c

/-- A chain of steps is a run of some length. -/
theorem Path.exists_iff {r : α → α → Prop} {a z : α} :
    (∃ n, Path r n a z) ↔ ReflTransGen r a z := by
  constructor
  · rintro ⟨n, h⟩
    induction h with
    | nil => exact .refl
    | cons hs _ ih => exact .head hs ih
  · intro h
    induction h using ReflTransGen.head_induction_on with
    | refl => exact ⟨0, .nil _⟩
    | head hs _ ih =>
      obtain ⟨n, hp⟩ := ih
      exact ⟨n + 1, .cons hs hp⟩

/-- A run from a state reachable from `a₀` is a run of the states reachable from `a₀`. -/
theorem Path.lift {r : α → α → Prop} {a₀ : α} {n : Nat} {a z : α} (h : Path r n a z) :
    ∀ ha : ReflTransGen r a₀ a,
      ∃ hz, Path (fun x y : {g // ReflTransGen r a₀ g} => r x.1 y.1) n ⟨a, ha⟩ ⟨z, hz⟩ := by
  induction h with
  | nil => exact fun ha => ⟨ha, .nil _⟩
  | cons hs _ ih =>
    intro ha
    obtain ⟨hz, hp⟩ := ih (ha.tail hs)
    exact ⟨hz, .cons hs hp⟩

/-- A state without a step. -/
def Normal (r : α → α → Prop) (a : α) : Prop := ∀ b, ¬ r a b

/-- `r` is confluent up to the equivalence `e`, with `Bad` persistent: two steps from one state
are equivalent, or both bad, or join in one more step each, or lead in one more step each to bad
states. -/
structure Confluent (r e : α → α → Prop) (Bad : α → Prop) : Prop where
  /-- Builds `Confluent` from its seven fields. -/
  mk ::
  /-- `e` is reflexive. -/
  refl : ∀ a, e a a
  /-- `e` is symmetric. -/
  symm : ∀ {a b}, e a b → e b a
  /-- `e` is transitive. -/
  trans : ∀ {a b c}, e a b → e b c → e a c
  /-- `e` is a simulation for `r`: a step from a state has an equivalent step from every
  equivalent state. -/
  bisim : ∀ {a a' b}, e a a' → r a b → ∃ b', r a' b' ∧ e b b'
  /-- A state equivalent to a bad state is bad. -/
  bad_eqv : ∀ {a a'}, e a a' → Bad a → Bad a'
  /-- A step from a bad state leads to a bad state. -/
  bad_step : ∀ {a b}, Bad a → r a b → Bad b
  /-- The one-step diamond: two steps from one state give equivalent states, or two bad states, or
  states with one more step each to equivalent states or to two bad states. -/
  diamond : ∀ {a b c}, r a b → r a c →
    e b c ∨ (Bad b ∧ Bad c) ∨ ∃ d d', r b d ∧ r c d' ∧ (e d d' ∨ (Bad d ∧ Bad d'))

variable {r e : α → α → Prop} {Bad : α → Prop}

namespace Confluent

/-- A state equivalent to a normal state is normal. -/
theorem normal_eqv (h : Confluent r e Bad) {a a' : α} (he : e a a') (hn : Normal r a) :
    Normal r a' := fun b hb => by
  obtain ⟨b', hb', _⟩ := h.bisim (h.symm he) hb
  exact hn b' hb'

/-- A run of `n` steps from `a` to `z` gives, from every state equivalent to `a`, a run of `n`
steps to a state equivalent to `z`. -/
theorem path_eqv (h : Confluent r e Bad) {n : Nat} {a z : α} (hp : Path r n a z) :
    ∀ {a'}, e a a' → ∃ z', Path r n a' z' ∧ e z z' := by
  induction hp with
  | nil a => exact fun he => ⟨_, .nil _, he⟩
  | cons hr _ ih =>
    intro a' he
    obtain ⟨b', hb', he'⟩ := h.bisim he hr
    obtain ⟨z', hp', hz⟩ := ih he'
    exact ⟨z', .cons hb' hp', hz⟩

/-- A run from a bad state ends in a bad state. -/
theorem bad_path (h : Confluent r e Bad) {n : Nat} {a z : α} (hp : Path r n a z) (hb : Bad a) :
    Bad z := by
  induction hp with
  | nil => exact hb
  | cons hr _ ih => exact ih (h.bad_step hb hr)

/-- The key lemma: if `a` has a run of `n` steps to a normal form `z` that is not bad, then every
step from a state equivalent to `a` leaves a run of exactly `n - 1` steps to a state equivalent
to `z`. -/
theorem key (h : Confluent r e Bad) : ∀ (n : Nat) {a z : α}, Path r n a z → Normal r z → ¬ Bad z →
    ∀ {a' b : α}, e a a' → r a' b → ∃ m z', n = m + 1 ∧ Path r m b z' ∧ e z z'
  | 0, a, z, hp, hz, _, a', b, he, hr => by
    cases hp
    exact absurd hr (h.normal_eqv he hz b)
  | n + 1, a, z, hp, hz, hb, a', b, he, hr => by
    cases hp with
    | cons h1 hp' =>
      obtain ⟨a₁', h1', he1⟩ := h.bisim he h1
      rcases h.diamond hr h1' with hbc | ⟨_, hbad⟩ | ⟨d, d', hbd, had, hj⟩
      · obtain ⟨z', hp'', hez⟩ := h.path_eqv hp' (h.trans he1 (h.symm hbc))
        exact ⟨n, z', rfl, hp'', hez⟩
      · obtain ⟨z', hp'', hez⟩ := h.path_eqv hp' he1
        exact absurd (h.bad_eqv (h.symm hez) (h.bad_path hp'' hbad)) hb
      · obtain ⟨m, z'', hn, hpm, hez''⟩ := h.key n hp' hz hb he1 had
        rcases hj with hdd | ⟨_, hbd'⟩
        · obtain ⟨z3, hp3, he3⟩ := h.path_eqv hpm (h.symm hdd)
          subst hn
          exact ⟨m + 1, z3, rfl, .cons hbd hp3, h.trans hez'' he3⟩
        · exact absurd (h.bad_eqv (h.symm hez'') (h.bad_path hpm hbd')) hb

/-- If `a` has a run to a normal state that is not bad, every run from `a` is finite. -/
theorem acc (h : Confluent r e Bad) : ∀ (n : Nat) {a z : α}, Path r n a z → Normal r z → ¬ Bad z →
    Acc (fun b a => r a b) a
  | 0, a, z, hp, hz, _ => by
    cases hp
    exact ⟨_, fun b hr => absurd hr (hz b)⟩
  | n + 1, a, z, hp, hz, hb => ⟨_, fun b hr => by
    obtain ⟨m, z', hn, hp', he⟩ := h.key (n + 1) hp hz hb (h.refl a) hr
    obtain rfl : n = m := by omega
    exact h.acc n hp' (h.normal_eqv he hz) fun hbad => hb (h.bad_eqv (h.symm he) hbad)⟩

/-- If `a` has a run of `n` steps to a normal state `z` that is not bad, every state reachable
from `a` has a run of at most `n` steps to a state equivalent to `z`. -/
theorem reach (h : Confluent r e Bad) {n : Nat} {a z : α} (hp : Path r n a z) (hz : Normal r z)
    (hb : ¬ Bad z) {g : α} (hg : ReflTransGen r a g) :
    ∃ m z', m ≤ n ∧ Path r m g z' ∧ e z z' := by
  induction hg with
  | refl => exact ⟨n, z, Nat.le_refl n, hp, h.refl z⟩
  | tail _ hs ih =>
    obtain ⟨m, z', hm, hp', he⟩ := ih
    obtain ⟨m', z'', hn, hp'', he'⟩ := h.key m hp' (h.normal_eqv he hz)
      (fun hbad => hb (h.bad_eqv (h.symm he) hbad)) (h.refl _) hs
    exact ⟨m', z'', by omega, hp'', h.trans he he'⟩

/-- **One run suffices.** If some run from `a` ends after `n` steps in a normal form `z` that is
not bad, then: every run from `a` is finite; no state reachable from `a` is bad; every normal
form reachable from `a` is equivalent to `z`; and every state reachable from `a` reaches a state
equivalent to `z` in at most `n` steps. -/
theorem one_run (h : Confluent r e Bad) {n : Nat} {a z : α} (hp : Path r n a z) (hz : Normal r z)
    (hb : ¬ Bad z) :
    Acc (fun b a => r a b) a ∧
    (∀ g, ReflTransGen r a g → ¬ Bad g) ∧
    (∀ g, ReflTransGen r a g → Normal r g → e z g) ∧
    (∀ g, ReflTransGen r a g → ∃ m z', m ≤ n ∧ Path r m g z' ∧ e z z') := by
  refine ⟨h.acc n hp hz hb, fun g hg hbad => ?_, fun g hg hn => ?_, fun g hg => h.reach hp hz hb hg⟩
  · obtain ⟨m, z', _, hp', he⟩ := h.reach hp hz hb hg
    exact hb (h.bad_eqv (h.symm he) (h.bad_path hp' hbad))
  · obtain ⟨m, z', _, hp', he⟩ := h.reach hp hz hb hg
    cases hp' with
    | nil => exact he
    | cons hr _ => exact absurd hr (hn _)

/-- **Refutation transfer.** If some state reachable from `a` is bad, so is every normal form
reachable from `a`. -/
theorem bad_normal (h : Confluent r e Bad) {a b z : α} (hb : ReflTransGen r a b) (hB : Bad b)
    (hz : ReflTransGen r a z) (hn : Normal r z) : Bad z := by
  obtain ⟨n, hp⟩ := Path.exists_iff.2 hz
  exact Classical.byContradiction fun hz' => (h.one_run hp hn hz').2.1 b hb hB

end Confluent

end OneRun

end MojoProof.Sem
