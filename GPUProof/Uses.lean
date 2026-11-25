import GPUProof.Race

/-!
# Use maps decide race freedom, on every machine

A use map says, for each vector of phases and each byte, how the accesses made at those phases
may use the byte (`Use`): one agent reads and writes it, the members of one instance read it,
everyone reads it, or only exempt updates of one word touch it; each through one proxy. The phase
of an instance at a position of a trace is the number of rendezvous of its members before it
(`phase`), and `phases` pairs each access of a trace with the phases at its position.

Uses are separated (`Use.Separated`) when any two accesses that conflict and that `Use.Admits`
accepts, the first at phases `π` and the second at phases `π' ≥ π`, go through one proxy, and are
one agent's or are told apart by an instance containing both agents whose phase grows from `π` to
`π'`. A trace whose every access its use admits is then race free (`racy_eq_false_of_uses`):
the instance's rendezvous between the two accesses orders them, by `GPUProof.HB`.

docs/proofs/laminar.md gives the definitions, the proof and where they depart from the design.
-/

namespace GPUProof

variable (S : Sig)

/-- How the accesses at one vector of phases may use a byte of machine `S`, for every machine:
each case names the one proxy its accesses go through. -/
inductive Use where
  /-- Agent `a` reads and writes the byte, through proxy `p`; no other agent touches it. -/
  | writer (a : S.Agent) (p : S.Proxy)
  /-- The members of instance `g` read the byte, through proxy `p`; nobody writes it. -/
  | readers (g : S.Gid) (p : S.Proxy)
  /-- Every agent may read the byte, through proxy `p`; nobody writes it. -/
  | frozen (p : S.Proxy)
  /-- Only updates by operation `op` with their result unused, of exactly the bytes `word`,
  through proxy `p`, touch the byte. -/
  | rmw (op : S.Op) (word : List S.Loc) (p : S.Proxy)

/-- Use `u` admits access `x` in launch `L` of machine `S`: `x` goes through `u`'s proxy, and is
by `u`'s agent (`writer`), a read or a frozen read by a member of `u`'s instance (`readers`), a
read or a frozen read (`frozen`), or an unused-result update by `u`'s operation of exactly `u`'s
bytes (`rmw`). -/
def Use.Admits (L : S.Launch) : Use S → S.Access → Prop
  | .writer a p, x => x.who = a ∧ x.proxy = p
  | .readers g p, x =>
    (∃ t ∈ S.members L g, x.who = .thread t) ∧ x.kind.writes = false ∧ x.proxy = p
  | .frozen p, x => x.kind.writes = false ∧ x.proxy = p
  | .rmw op word p, x => x.kind = .rmw op ∧ x.locs S = word ∧ x.proxy = p

/-- `Use.Admits` is decidable, for every machine, launch, use and access. -/
instance Use.decAdmits (L : S.Launch) : (u : Use S) → (x : S.Access) → Decidable (u.Admits S L x)
  | .writer a p, x => inferInstanceAs (Decidable (x.who = a ∧ x.proxy = p))
  | .readers g p, x => inferInstanceAs
    (Decidable ((∃ t ∈ S.members L g, x.who = .thread t) ∧ x.kind.writes = false ∧ x.proxy = p))
  | .frozen p, x => inferInstanceAs (Decidable (x.kind.writes = false ∧ x.proxy = p))
  | .rmw op word p, x => inferInstanceAs
    (Decidable (x.kind = .rmw op ∧ x.locs S = word ∧ x.proxy = p))

/-- The event `o`, if any, is a rendezvous whose agents are the members of instance `g` of launch
`L`, as threads, in any order and with any repetition. -/
def isSyncOf (L : S.Launch) (g : S.Gid) : Option S.Event → Bool
  | some (.sync _ ms) =>
    (ms.all fun c => match c with
      | .thread t => decide (t ∈ S.members L g)
      | .job _ => false) && (S.members L g).all fun t => decide (Agent.thread t ∈ ms)
  | _ => false

/-- The phase of instance `g` of launch `L` at position `i` of trace `tr` of machine `S`: the
number of rendezvous of `g`'s members (`isSyncOf`) at positions before `i`. -/
def phase (L : S.Launch) (tr : List S.Event) (i : Nat) (g : S.Gid) : Nat :=
  (List.range i).countP fun k => isSyncOf S L g tr[k]?

/-- The accesses of trace `tr` of machine `S`, oldest first, each with the phase of every
instance of launch `L` at its position. -/
def phases (L : S.Launch) (tr : List S.Event) : List (S.Access × (S.Gid → Nat)) :=
  (List.range tr.length).filterMap fun i =>
    (tr[i]?.bind Event.access?).map fun a => (a, phase S L tr i)

/-- The uses `U` of launch `L` of machine `S` are separated: whenever use `U π l` admits access
`x` and use `U π' l` admits access `y`, at phases `π ≤ π'` and a byte `l` of both, and `x` and
`y` conflict, then `x` and `y` go through one proxy, and they are one agent's, or some instance
`g` contains both agents (as threads) and `π g < π' g`. -/
def Use.Separated (L : S.Launch) (U : (S.Gid → Nat) → S.Loc → Use S) : Prop :=
  ∀ (π π' : S.Gid → Nat) (l : S.Loc) (x y : S.Access), π ≤ π' → l ∈ x.locs S → l ∈ y.locs S →
    (U π l).Admits S L x → (U π' l).Admits S L y → Access.conflict S x y = true →
      x.proxy = y.proxy ∧ (x.who = y.who ∨ ∃ g, (∃ t ∈ S.members L g, x.who = .thread t) ∧
        (∃ t ∈ S.members L g, y.who = .thread t) ∧ π g < π' g)

variable {S}

/-- Phases only grow along a trace, on every machine: `phase` at `i ≤ j` is at most `phase` at
`j`, at every instance. -/
theorem phase_mono {L : S.Launch} {tr : List S.Event} {i j : Nat} (hij : i ≤ j) :
    phase S L tr i ≤ phase S L tr j := fun _ =>
  (List.range_sublist.2 hij).countP_le

/-- The phase of an instance grows from position `i` to position `j` only at a rendezvous of its
members at a position `k` with `i ≤ k < j`, on every machine. -/
theorem phase_lt {L : S.Launch} {tr : List S.Event} {g : S.Gid} {i j : Nat}
    (h : phase S L tr i g < phase S L tr j g) :
    ∃ k, i ≤ k ∧ k < j ∧ isSyncOf S L g tr[k]? = true := by
  induction j with
  | zero => simp [phase] at h
  | succ j ih =>
    by_cases hj : phase S L tr i g < phase S L tr j g
    · obtain ⟨k, hik, hkj, hk⟩ := ih hj
      exact ⟨k, hik, Nat.lt_succ_of_lt hkj, hk⟩
    have hs : phase S L tr (j + 1) g =
        phase S L tr j g + if isSyncOf S L g tr[j]? = true then 1 else 0 := by
      simp only [phase, List.range_succ, List.countP_append, List.countP_singleton]
    have hij : i ≤ j := by
      by_contra hji
      exact absurd (phase_mono (L := L) (tr := tr) (Nat.succ_le_of_lt (Nat.lt_of_not_le hji)) g)
        (Nat.not_le_of_lt h)
    by_cases hk : isSyncOf S L g tr[j]? = true
    · exact ⟨j, hij, Nat.lt_succ_self j, hk⟩
    · simp only [hs, hk, Bool.false_eq_true, ↓reduceIte, Nat.add_zero] at h
      exact absurd h hj

/-- Uses decide race freedom, on every machine and trace: if the uses `U` of launch `L` are
separated (`Use.Separated`) and, at every access of `tr` and every byte of it, the use at the
access's phases (`phases`) admits it, then `racy` passes `tr`. -/
theorem racy_eq_false_of_uses {L : S.Launch} {tr : List S.Event}
    (U : (S.Gid → Nat) → S.Loc → Use S) (hU : Use.Separated S L U)
    (h : ∀ x ∈ phases S L tr, ∀ l ∈ x.1.locs S, (U x.2 l).Admits S L x.1) :
    racy S tr = false := by
  rw [Bool.eq_false_iff]
  intro hr
  obtain ⟨i, j, x, y, hij, hx, hy, hc, ho⟩ := (racy_iff S).1 hr
  have hmem : ∀ {k : Nat} {a : S.Access}, tr[k]? = some (.access a) →
      (a, phase S L tr k) ∈ phases S L tr := by
    intro k a hk
    refine List.mem_filterMap.2 ⟨k, List.mem_range.2 (List.getElem?_eq_some_iff.1 hk).1, ?_⟩
    rw [hk]
    rfl
  -- an edge of `HB` from a shared agent
  have hedge : ∀ {m n : Nat} {e e' : S.Event} {c : S.Agent}, m < n → tr[m]? = some e →
      tr[n]? = some e' → c ∈ e.agents → c ∈ e'.agents → edge S tr m n = true := by
    intro m n e e' c hmn hm hn hc hc'
    simp only [edge, hm, hn, Option.any_some, Bool.and_eq_true, decide_eq_true_eq,
      Bool.or_eq_true, List.any_eq_true]
    exact ⟨hmn, .inl ⟨c, hc, hc'⟩⟩
  obtain ⟨l, hlx, hly⟩ : ∃ l ∈ x.locs S, l ∈ y.locs S := by
    simp only [Access.conflict, Bool.and_eq_true, List.any_eq_true, decide_eq_true_eq] at hc
    exact hc.1.1
  obtain ⟨hp, hw⟩ := hU _ _ l x y (phase_mono (Nat.le_of_lt hij)) hlx hly
    (h _ (hmem hx) l hlx) (h _ (hmem hy) l hly) hc
  refine ho (.inl ⟨hp, ?_⟩)
  rcases hw with hw | ⟨g, ⟨t, ht, hxt⟩, ⟨t', ht', hyt⟩, hlt⟩
  · exact .single (hedge hij hx hy (List.mem_singleton_self x.who)
      (by rw [hw]; exact List.mem_singleton_self y.who))
  obtain ⟨k, hik, hkj, hk⟩ := phase_lt hlt
  obtain ⟨e, he⟩ : ∃ e, tr[k]? = some e := Option.isSome_iff_exists.1 (by
    cases hk' : tr[k]? <;> simp_all [isSyncOf])
  rw [he] at hk
  rcases e with _ | ⟨o, ms⟩ | _ | _ | _ <;> simp only [isSyncOf, Bool.false_eq_true] at hk
  simp only [Bool.and_eq_true] at hk
  have hin : ∀ t ∈ S.members L g, Agent.thread t ∈ ms := fun t ht => by
    have := List.all_eq_true.1 hk.2 t ht
    simpa using this
  have hik' : i < k := by
    rcases Nat.lt_or_eq_of_le hik with hik | rfl
    · exact hik
    · rw [hx] at he
      cases he
  exact .tail (.single (hedge hik' hx he (List.mem_singleton_self x.who)
    (show x.who ∈ ms by rw [hxt]; exact hin t ht)))
    (hedge hkj he hy (show y.who ∈ ms by rw [hyt]; exact hin t' ht')
      (List.mem_singleton_self y.who))

end GPUProof
