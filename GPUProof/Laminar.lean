import GPUProof.Race

/-!
# Laminar levels and happens-before, on every machine with `Levels`

A machine's level instances nest: every thread lies in one instance of each level, the instance
of a higher level contains the instance of a lower one, the top level's one instance is the
launch and the bottom level's instances are single threads. `Levels` states these laws of the
fields `group`, `levelOf` and `members` of `Sig`.

A trace is laminar for a launch (`Laminar`) when its only ordering events are rendezvous of the
members of one level instance: no releases or acquires. On a laminar trace of a machine with
`Levels`, two events that share an agent have nested agent lists (`Laminar.nested`), so
happens-before needs no chains: `i` happens before `j` exactly when the events there share an
agent, or one rendezvous between them contains an agent of each (`HB.laminar_iff`). A job lies in
no instance, so it is ordered only with its own events.

docs/proofs/laminar.md gives the definitions, the proof and where they depart from the design.
-/

namespace GPUProof

open Relation

/-- The laws of the level instances of machine `S`, for every launch `L`, level, instance and
thread: the members of an instance are the threads whose instance at its level it is; an
instance's level is the level it was taken at; threads in one instance of a level are in one
instance of every higher level; the instance of `⊤` holds every thread of the launch and an
instance of `⊥` one thread; the launch's threads and each instance's members are without
repetition. -/
class Levels (S : Sig) : Prop where
  /-- Builds `Levels S` from its six fields. -/
  mk ::
  /-- Thread `u` is a member of instance `g` of launch `L` exactly when `u` is a thread of `L`
  whose instance at `g`'s level is `g`. -/
  mem_members {L : S.Launch} {g : S.Gid} {u : S.Tid} :
    u ∈ S.members L g ↔ u ∈ S.threads L ∧ S.group L (S.levelOf g) u = g
  /-- The instance of a thread at level `ℓ` has level `ℓ`. -/
  levelOf_group {L : S.Launch} {ℓ : S.Level} {t : S.Tid} : S.levelOf (S.group L ℓ t) = ℓ
  /-- Two threads in one instance of level `ℓ` are in one instance of every level `ℓ' ≥ ℓ`. -/
  nest {L : S.Launch} {ℓ ℓ' : S.Level} {t u : S.Tid} :
    ℓ ≤ ℓ' → S.group L ℓ t = S.group L ℓ u → S.group L ℓ' t = S.group L ℓ' u
  /-- The members of a thread's instance of `⊤` are the threads of the launch, up to order. -/
  top {L : S.Launch} {t : S.Tid} :
    t ∈ S.threads L → (S.members L (S.group L ⊤ t)).Perm (S.threads L)
  /-- The members of a thread's instance of `⊥` are that thread alone. -/
  bot {L : S.Launch} {t : S.Tid} : t ∈ S.threads L → S.members L (S.group L ⊥ t) = [t]
  /-- The threads of the launch, and the members of each instance, have no repetition. -/
  nodup {L : S.Launch} {g : S.Gid} : (S.threads L).Nodup ∧ (S.members L g).Nodup

variable (S : Sig)

/-- Trace `tr` of machine `S` is laminar for launch `L`: every event of `tr` is an access, a
fence, or a rendezvous whose agents are the members of one level instance `g` of `L`, as threads
(the same agents, in any order and with any repetition). A laminar trace has no releases and no
acquires, and no rendezvous of a job. -/
def Laminar (L : S.Launch) (tr : List S.Event) : Prop :=
  ∀ e ∈ tr, (∃ a, e = .access a) ∨ (∃ w p q, e = .fence w p q) ∨
    ∃ o ms g, e = .sync o ms ∧ ∀ c, c ∈ ms ↔ ∃ u ∈ S.members L g, c = .thread u

variable {S}

/-- An event of a laminar trace has one agent, or the members of a level instance as its agents,
on every machine. -/
theorem Laminar.agents {L : S.Launch} {tr : List S.Event} (hl : Laminar S L tr) {e : S.Event}
    (he : e ∈ tr) : (∃ a, e.agents = [a]) ∨
      ∃ g, ∀ c, c ∈ e.agents ↔ ∃ u ∈ S.members L g, c = .thread u := by
  rcases hl e he with ⟨a, rfl⟩ | ⟨w, p, q, rfl⟩ | ⟨o, ms, g, rfl, h⟩
  · exact .inl ⟨_, rfl⟩
  · exact .inl ⟨_, rfl⟩
  · exact .inr ⟨g, h⟩

/-- Two events of a laminar trace that share an agent have nested agent lists: every agent of
one is an agent of the other, on every machine with `Levels`. -/
theorem Laminar.nested [Levels S] {L : S.Launch} {tr : List S.Event} (hl : Laminar S L tr)
    {e e' : S.Event} (he : e ∈ tr) (he' : e' ∈ tr) {c : S.Agent} (hc : c ∈ e.agents)
    (hc' : c ∈ e'.agents) :
    (∀ x ∈ e.agents, x ∈ e'.agents) ∨ ∀ x ∈ e'.agents, x ∈ e.agents := by
  rcases hl.agents he with ⟨a, ha⟩ | ⟨g, hg⟩
  · rw [ha, List.mem_singleton] at hc
    subst hc
    exact .inl fun x hx => by rw [ha, List.mem_singleton] at hx; subst hx; exact hc'
  rcases hl.agents he' with ⟨a, ha⟩ | ⟨g', hg'⟩
  · rw [ha, List.mem_singleton] at hc'
    subst hc'
    exact .inr fun x hx => by rw [ha, List.mem_singleton] at hx; subst hx; exact hc
  obtain ⟨u, hu, rfl⟩ := (hg c).1 hc
  obtain ⟨u', hu', hcu⟩ := (hg' _).1 hc'
  injection hcu with hcu
  subst hcu
  rw [Levels.mem_members] at hu hu'
  -- the instance of the lower level lies inside the other, through `nest` at their common member
  have sub : ∀ {g g' : S.Gid}, (∀ c, c ∈ e.agents ↔ ∃ u ∈ S.members L g, c = .thread u) →
      (∀ c, c ∈ e'.agents ↔ ∃ u ∈ S.members L g', c = .thread u) →
      S.group L (S.levelOf g) u = g → S.group L (S.levelOf g') u = g' →
      S.levelOf g ≤ S.levelOf g' → ∀ x ∈ e.agents, x ∈ e'.agents := by
    intro g g' hg hg' hu hu' hle x hx
    obtain ⟨v, hv, rfl⟩ := (hg x).1 hx
    rw [Levels.mem_members] at hv
    refine (hg' _).2 ⟨v, Levels.mem_members.2 ⟨hv.1, ?_⟩, rfl⟩
    rw [Levels.nest hle (hv.2.trans hu.symm), hu']
  have sub' : ∀ {g g' : S.Gid}, (∀ c, c ∈ e'.agents ↔ ∃ u ∈ S.members L g, c = .thread u) →
      (∀ c, c ∈ e.agents ↔ ∃ u ∈ S.members L g', c = .thread u) →
      S.group L (S.levelOf g) u = g → S.group L (S.levelOf g') u = g' →
      S.levelOf g ≤ S.levelOf g' → ∀ x ∈ e'.agents, x ∈ e.agents := by
    intro g g' hg hg' hu hu' hle x hx
    obtain ⟨v, hv, rfl⟩ := (hg x).1 hx
    rw [Levels.mem_members] at hv
    refine (hg' _).2 ⟨v, Levels.mem_members.2 ⟨hv.1, ?_⟩, rfl⟩
    rw [Levels.nest hle (hv.2.trans hu.symm), hu']
  rcases le_total (S.levelOf g) (S.levelOf g') with hle | hle
  · exact .inl (sub hg hg' hu.2 hu'.2 hle)
  · exact .inr (sub' hg' hg hu'.2 hu.2 hle)

/-- On a laminar trace `tr` of launch `L`, on every machine with `Levels`, position `i` happens
before position `j` exactly when `i < j`, both are positions of `tr`, and either the events there
share an agent, or a rendezvous strictly between them (at a position `k` with `i < k < j`)
contains an agent of each. By `Laminar` that rendezvous's agents are the members of one level
instance, so the instance contains an agent of each event; for an event with several agents (a
rendezvous) one of its agents suffices. A job lies in no instance, so an event of a job is
ordered only with a later event that has that job among its agents. -/
theorem HB.laminar_iff [Levels S] {L : S.Launch} {tr : List S.Event} (hl : Laminar S L tr)
    {i j : Nat} :
    HB S tr i j ↔ i < j ∧ ∃ e e', tr[i]? = some e ∧ tr[j]? = some e' ∧
      ((∃ a ∈ e.agents, a ∈ e'.agents) ∨
        ∃ k o ms, i < k ∧ k < j ∧ tr[k]? = some (.sync o ms) ∧ (∃ a ∈ e.agents, a ∈ ms) ∧
          ∃ b ∈ e'.agents, b ∈ ms) := by
  have hedge : ∀ {x y : Nat} {ex ey : S.Event}, x < y → tr[x]? = some ex → tr[y]? = some ey →
      (∃ a ∈ ex.agents, a ∈ ey.agents) → edge S tr x y = true := by
    rintro x y ex ey hxy hx hy ⟨a, ha, ha'⟩
    simp only [edge, hx, hy, Option.any_some, Bool.and_eq_true, decide_eq_true_eq,
      Bool.or_eq_true, List.any_eq_true]
    exact ⟨hxy, .inl ⟨a, ha, ha'⟩⟩
  constructor
  swap
  · rintro ⟨hij, e, e', hi, hj, h | ⟨k, o, ms, hik, hkj, hk, ha, hb⟩⟩
    · exact .single (hedge hij hi hj h)
    · obtain ⟨a, ha, ha'⟩ := ha
      obtain ⟨b, hb, hb'⟩ := hb
      exact .tail (.single (hedge hik hi hk ⟨a, ha, ha'⟩)) (hedge hkj hk hj ⟨b, hb', hb⟩)
  intro h
  -- an edge of a laminar trace is a shared agent: no event of it releases
  have hedge' : ∀ {x y : Nat}, edge S tr x y = true → x < y ∧ ∃ ex ey, tr[x]? = some ex ∧
      tr[y]? = some ey ∧ ∃ a ∈ ex.agents, a ∈ ey.agents := by
    intro x y hxy
    have hlt := (edge_lt S hxy).1
    simp only [edge, Bool.and_eq_true, decide_eq_true_eq, Option.any_eq_true, Bool.or_eq_true,
      List.any_eq_true] at hxy
    obtain ⟨-, ex, hx, ey, hy, hs | hr⟩ := hxy
    · exact ⟨hlt, ex, ey, hx, hy, hs⟩
    · rcases hl ex (List.mem_of_getElem? hx) with ⟨a, rfl⟩ | ⟨w, p, q, rfl⟩ | ⟨o, ms, g, rfl, -⟩ <;>
        cases ey <;> simp [Event.relAcq] at hr
  -- the invariant: the events at `i` and `m` have agents, and one event between them holds both
  have inv : ∀ {m : Nat}, HB S tr i m → i < m ∧ ∃ ei em, tr[i]? = some ei ∧ tr[m]? = some em ∧
      (∃ a, a ∈ ei.agents) ∧ (∃ a, a ∈ em.agents) ∧ ∃ k ek, i ≤ k ∧ k ≤ m ∧ tr[k]? = some ek ∧
        (∀ x ∈ ei.agents, x ∈ ek.agents) ∧ ∀ x ∈ em.agents, x ∈ ek.agents := by
    intro m hm
    induction hm with
    | single hxy =>
      obtain ⟨hlt, ei, em, hi, hm, a, ha, ha'⟩ := hedge' hxy
      refine ⟨hlt, ei, em, hi, hm, ⟨a, ha⟩, ⟨a, ha'⟩, ?_⟩
      rcases hl.nested (List.mem_of_getElem? hi) (List.mem_of_getElem? hm) ha ha' with hs | hs
      · exact ⟨_, em, Nat.le_of_lt hlt, Nat.le_refl _, hm, hs, fun _ => id⟩
      · exact ⟨_, ei, Nat.le_refl _, Nat.le_of_lt hlt, hi, fun _ => id, hs⟩
    | tail _ hxy ih =>
      obtain ⟨hlt, ei, em, hi, hm, hai, -, k, ek, hik, hkm, hk, hsi, hsm⟩ := ih
      obtain ⟨hlt', em₂, em', hm₂, hm', c, hc, hc'⟩ := hedge' hxy
      rw [hm] at hm₂
      cases hm₂
      refine ⟨Nat.lt_trans hlt hlt', ei, em', hi, hm', hai, ⟨c, hc'⟩, ?_⟩
      rcases hl.nested (List.mem_of_getElem? hm) (List.mem_of_getElem? hm') hc hc' with hs | hs
      · rcases hl.nested (List.mem_of_getElem? hk) (List.mem_of_getElem? hm') (hsm c hc) hc' with
          hs' | hs'
        · exact ⟨_, em', Nat.le_of_lt (Nat.lt_trans hlt hlt'), Nat.le_refl _, hm',
            fun x hx => hs' x (hsi x hx), fun _ => id⟩
        · exact ⟨k, ek, hik, Nat.le_trans hkm (Nat.le_of_lt hlt'), hk, hsi, hs'⟩
      · exact ⟨k, ek, hik, Nat.le_trans hkm (Nat.le_of_lt hlt'), hk, hsi,
          fun x hx => hsm x (hs x hx)⟩
  obtain ⟨hij, ei, ej, hi, hj, ⟨a, ha⟩, ⟨b, hb⟩, k, ek, hik, hkj, hk, hsi, hsj⟩ := inv h
  refine ⟨hij, ei, ej, hi, hj, ?_⟩
  rcases Nat.lt_or_eq_of_le hik with hik | rfl
  · rcases Nat.lt_or_eq_of_le hkj with hkj | rfl
    · rcases hl ek (List.mem_of_getElem? hk) with ⟨a', rfl⟩ | ⟨w, p, q, rfl⟩ | ⟨o, ms, g, rfl, -⟩
      · have h1 := hsi a ha
        have h2 := hsj b hb
        simp only [Event.agents, List.mem_singleton] at h1 h2
        subst h1 h2
        exact .inl ⟨_, ha, hb⟩
      · have h1 := hsi a ha
        have h2 := hsj b hb
        simp only [Event.agents, List.mem_singleton] at h1 h2
        subst h1 h2
        exact .inl ⟨_, ha, hb⟩
      · exact .inr ⟨k, o, ms, hik, hkj, hk, ⟨a, ha, hsi a ha⟩, b, hb, hsj b hb⟩
    · rw [hj] at hk
      cases hk
      exact .inl ⟨a, ha, hsi a ha⟩
  · rw [hi] at hk
    cases hk
    exact .inl ⟨b, hsj b hb, hb⟩

end GPUProof
