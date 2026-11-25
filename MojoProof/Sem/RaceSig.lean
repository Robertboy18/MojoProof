import MojoProof.Sem.Race

/-!
# The core's `racy` at `sig`, below MojoProof's users of races

What the statements about races of MojoProof's traces need, below MojoProof/Sem/Trace.lean, for
every launch and trace. A trace is racy when the core's `racy` at `sig` holds of its core events,
oldest first (`Event.toCore`); MojoProof has no `racy` of its own.

* the shapes of MojoProof's traces (`Trace.Shaped`, oldest first): a load with `!invariant.load`
  neither writes nor updates, and every `atomicrmw`'s read is followed at once by its write; a
  filter that keeps or drops an access with its write keeps the shape (`Trace.Shaped.filter`);
* the core's kinds of MojoProof's accesses (`Access.kind_writes`, `Access.kind_frozen`), overlap
  as a common byte (`Access.overlaps_iff_bytes`) and the core's conflict at `sig`
  (`conflict_sig`);
* the levels of `sig` (`Levels sig`, `Launch.groupNum_nest`);
* the core's `racy` at `sig` by positions (`racy_sig_iff`), through `GPUProof.HB.laminar_iff`;
* races by phases (`phases`, `clash`) are races by positions (`Access.races_iff_rev`,
  `clash_access`, `clash_barrier`, `clash_append`, `pos_iff_phases`), so the core's `racy` at
  `sig` holds exactly when two accesses of `phases` clash (`racy_sig_rev`, and `racy_iff`, L9 of
  docs/proofs/schedule.md), for a trace whose accesses are by threads of the launch in their
  blocks of threads and that is shaped; a check that `decide` evaluates gives these two premises
  (`Trace.fits_of_check`); `fast` finds every race (`fast_sound`);
* a racy trace stays racy when events are added (`racy_of_append` at every machine, with
  `hb_append_iff`; `racy_append`, `racy_cons` at `sig`), and events with no access keep `racy`
  (`racy_append_eq` at every machine; `racy_barriers` at `sig`).
-/

namespace MojoProof.Sem

open LLVM

/-! ### Lists with one more element -/

/-- Position `k` of `U ++ [x]` holds `y` exactly when it is a position of `U` that holds `y`, or
`U`'s length with `x = y`, for every list, element and position. -/
theorem getElem?_concat_eq_some {α : Type} {U : List α} {x y : α} {k : Nat} :
    (U ++ [x])[k]? = some y ↔ (k < U.length ∧ U[k]? = some y) ∨ (k = U.length ∧ x = y) := by
  by_cases h : k < U.length
  · rw [List.getElem?_append_left h]
    refine ⟨fun e => .inl ⟨h, e⟩, ?_⟩
    rintro (⟨-, e⟩ | ⟨rfl, -⟩)
    · exact e
    · exact absurd h (Nat.lt_irrefl _)
  · rw [List.getElem?_append_right (Nat.le_of_not_lt h), List.getElem?_singleton]
    constructor
    · intro e
      split at e
      · exact .inr ⟨by omega, Option.some.inj e⟩
      · cases e
    · rintro (⟨h', -⟩ | ⟨rfl, rfl⟩)
      · exact absurd h' h
      · simp

/-- A position of `U` that holds `y` holds `y` in `U ++ V`, for every pair of lists. -/
theorem getElem?_append_of_some {α : Type} {U V : List α} {y : α} {k : Nat}
    (h : U[k]? = some y) : (U ++ V)[k]? = some y := by
  rw [List.getElem?_append_left (List.getElem?_eq_some_iff.1 h).1, h]

/-! ### The shapes of MojoProof's traces -/

/-- Trace `U` (oldest first) has the access shapes of MojoProof's steps: a load with
`!invariant.load` neither writes nor is an `atomicrmw`'s, and the read of every `atomicrmw` is
followed at once by its write, the same access with `write` set (`Stmt.pending` logs them
together). -/
def Trace.Shaped (U : List Event) : Prop :=
  (∀ a, Event.access a ∈ U → a.invariant = true → a.write = false ∧ a.atomic = none) ∧
    ∀ (p : Nat) (a : Access), U[p]? = some (.access a) → a.atomic.isSome = true → a.write = false →
      U[p + 1]? = some (.access { a with write := true })

/-- The empty trace is shaped. -/
theorem Trace.shaped_nil : Trace.Shaped [] :=
  ⟨fun _ h => by simp at h, fun _ _ h => by simp at h⟩

/-- Shaped traces append to a shaped trace, for every pair of traces. -/
theorem Trace.Shaped.append {U V : List Event} (hU : Trace.Shaped U) (hV : Trace.Shaped V) :
    Trace.Shaped (U ++ V) := by
  refine ⟨fun a ha => (List.mem_append.1 ha).elim (hU.1 a) (hV.1 a), fun p a hp ho hw => ?_⟩
  by_cases h : p < U.length
  · rw [List.getElem?_append_left h] at hp
    exact getElem?_append_of_some (hU.2 p a hp ho hw)
  · rw [List.getElem?_append_right (by omega)] at hp
    have := hV.2 _ a hp ho hw
    rw [List.getElem?_append_right (by omega), show p + 1 - U.length = p - U.length + 1 by omega]
    exact this

/-- A shaped trace without its oldest event is shaped, for every event and trace. -/
theorem Trace.Shaped.tail {x : Event} {U : List Event} (h : Trace.Shaped (x :: U)) :
    Trace.Shaped U := by
  refine ⟨fun a ha => h.1 a (List.mem_cons_of_mem _ ha), fun p a hp ho hw => ?_⟩
  have := h.2 (p + 1) a (by rwa [List.getElem?_cons_succ]) ho hw
  rwa [List.getElem?_cons_succ] at this

/-- **A filter keeps the shape**, for every shaped trace and filter `f` that keeps an access
exactly when it keeps that access with `write` set: an `atomicrmw`'s read and its write stay
together. -/
theorem Trace.Shaped.filter {f : Event → Bool}
    (hf : ∀ a, f (.access { a with write := true }) = f (.access a)) :
    ∀ {U : List Event}, Trace.Shaped U → Trace.Shaped (U.filter f)
  | [], _ => Trace.shaped_nil
  | x :: U, h => by
    have ih := Trace.Shaped.filter hf h.tail
    rw [List.filter_cons]
    split
    · rename_i hx
      refine ⟨fun a ha hi => ?_, fun p a hp ho hw => ?_⟩
      · rcases List.mem_cons.1 ha with rfl | ha
        · exact h.1 _ List.mem_cons_self hi
        · exact h.1 a (List.mem_cons_of_mem _ (List.mem_filter.1 ha).1) hi
      · rcases p with _ | p
        · have hx' : x = .access a := by simpa using hp
          subst hx'
          have h1 := h.2 0 a (by simp) ho hw
          cases U with
          | nil => simp at h1
          | cons w U =>
            simp only [List.getElem?_cons_succ, List.getElem?_cons_zero, Option.some.injEq] at h1
            subst h1
            simp [hf, hx]
        · rw [List.getElem?_cons_succ] at hp ⊢
          exact ih.2 p a hp ho hw
    · exact ih

/-- A trace of one event, not an `atomicrmw`'s read, whose load with `!invariant.load` neither
writes nor updates, is shaped, for every event. -/
theorem Trace.shaped_single {x : Event}
    (h : ∀ a, x = .access a → (a.invariant = true → a.write = false ∧ a.atomic = none) ∧
      (a.atomic.isSome = true → a.write = true)) : Trace.Shaped [x] := by
  refine ⟨fun a ha => (h a (List.mem_singleton.1 ha).symm).1, fun p a hp ho hw => ?_⟩
  rcases p with _ | p
  · have hx : x = .access a := by simpa using hp
    have := (h a hx).2 ho
    rw [hw] at this
    cases this
  · simp at hp

/-- The read and the write of an `atomicrmw`, oldest first, are shaped, for every read that
neither writes nor is a load with `!invariant.load`. -/
theorem Trace.shaped_rmw {r : Access} (hw : r.write = false) (hi : r.invariant = false) :
    Trace.Shaped [.access r, .access { r with write := true }] := by
  refine ⟨fun a ha hia => ?_, fun p a hp ho hw' => ?_⟩
  · simp only [List.mem_cons, List.not_mem_nil, or_false, Event.access.injEq] at ha
    rcases ha with rfl | rfl
    · rw [hi] at hia
      cases hia
    · simp [hi] at hia
  · rcases p with _ | _ | p
    · simp only [List.getElem?_cons_zero, Option.some.injEq, Event.access.injEq] at hp
      subst hp
      rfl
    · simp only [List.getElem?_cons_succ, List.getElem?_cons_zero, Option.some.injEq,
        Event.access.injEq] at hp
      subst hp
      simp at hw'
    · simp at hp

/-- The core's kind of access `a` writes (`Kind.writes`) exactly when `a` writes or is an
`atomicrmw`'s, for every access. -/
theorem Access.kind_writes (a : Access) : a.kind.writes = (a.write || a.atomic.isSome) := by
  obtain ⟨_, _, _, w, x, i⟩ := a
  cases x <;> cases w <;> cases i <;> rfl

/-- The core's kind of access `a` is `frozen` exactly when `a` is a load with
`!invariant.load`: no write, no `atomicrmw`, for every access. -/
theorem Access.kind_frozen (a : Access) :
    a.kind = .frozen ↔ a.atomic = none ∧ a.write = false ∧ a.invariant = true := by
  obtain ⟨_, _, _, w, x, i⟩ := a
  cases x <;> cases w <;> cases i <;> simp [Access.kind]

/-- **Two accesses overlap exactly when they touch a common byte** (block and offset,
`Access.bytes`), for every pair of accesses: `Access.overlaps` is the intersection of footprints
that the core's conflicts and `kept` read. -/
theorem Access.overlaps_iff_bytes {a e : Access} :
    a.overlaps e = true ↔ ∃ b ∈ a.bytes, b ∈ e.bytes := by
  refine ⟨Access.overlaps_bytes, ?_⟩
  rintro ⟨b, hb, he⟩
  simp only [Access.bytes, List.mem_map, List.mem_range] at hb he
  obtain ⟨i, hi, rfl⟩ := hb
  obtain ⟨j, hj, hij⟩ := he
  simp only [Prod.mk.injEq] at hij
  simp only [Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
  refine ⟨⟨⟨⟨hij.1.symm, ?_⟩, ?_⟩, ?_⟩, ?_⟩ <;> omega

/-! ### Conflicts and kinds -/

/-- **The core's conflict at `sig`**, for every pair of accesses: they overlap, one of them
writes or is an `atomicrmw`'s, and they are not both by `atomicrmw`s of one commuting operation
(`RmwOp.commutes`) on the same bytes (the exemption of MojoProof's `Access.conflict`). -/
theorem conflict_sig (a e : Access) : GPUProof.Access.conflict sig a.toCore e.toCore =
    (a.overlaps e && (a.kind.writes || e.kind.writes) &&
      !(a.atomic.any RmwOp.commutes && a.atomic == e.atomic && a.ptr == e.ptr &&
        a.len == e.len)) := by
  have ho : (a.bytes.any fun l => decide (l ∈ e.bytes)) = a.overlaps e := by
    rw [Bool.eq_iff_iff, Access.overlaps_iff_bytes]
    simp
  have hx : sigExempt a.toCore e.toCore =
      (a.atomic.any RmwOp.commutes && a.atomic == e.atomic && a.ptr == e.ptr &&
        a.len == e.len) := by
    obtain ⟨_, ⟨b, o⟩, l, w, x, i⟩ := a
    obtain ⟨_, ⟨b', o'⟩, l', w', x', i'⟩ := e
    rw [Bool.eq_iff_iff]
    cases x <;> cases x' <;> cases w <;> cases i <;> cases w' <;> cases i' <;>
      simp [sigExempt, Access.toCore, Access.kind, and_assoc]
  show ((a.bytes.any fun l => decide (l ∈ e.bytes)) && (a.kind.writes || e.kind.writes) &&
    !sigExempt a.toCore e.toCore) = _
  rw [ho, hx]

/-! ### The levels -/

/-- **Threads in one instance of a level are in one instance of every higher level**, for every
launch, pair of levels `l ≤ l'` and pair of threads: the same thread (level 0), the same warp's
first thread (level 1), the same block of threads (level 2), the grid (level 3). -/
theorem Launch.groupNum_nest (L : Launch) {l l' : Fin 4} {t u : Nat} (hl : l ≤ l')
    (h : L.groupNum l t = L.groupNum l u) : L.groupNum l' t = L.groupNum l' u := by
  have warp : ∀ n, (n - n % volume L.block % 32) / volume L.block = n / volume L.block := by
    intro n
    rcases Nat.eq_zero_or_pos (volume L.block) with hB | hB
    · simp [hB]
    · have h1 : n % volume L.block % 32 ≤ n % volume L.block := Nat.mod_le _ _
      have h2 : n % volume L.block < volume L.block := Nat.mod_lt _ hB
      have h3 := Nat.div_add_mod n (volume L.block)
      generalize n % volume L.block = r at *
      generalize r % 32 = r' at *
      have e : n - r' = (r - r') + volume L.block * (n / volume L.block) := by
        generalize volume L.block * (n / volume L.block) = p at *
        omega
      rw [e, Nat.add_mul_div_left _ _ hB, Nat.div_eq_of_lt (by omega), Nat.zero_add]
  have g0 : ∀ n, L.groupNum 0 n = n := fun _ => rfl
  have g1 : ∀ n, L.groupNum 1 n = n - n % volume L.block % 32 := fun _ => rfl
  have g2 : ∀ n, L.groupNum 2 n = n / volume L.block := fun _ => rfl
  have g3 : ∀ n, L.groupNum 3 n = 0 := fun _ => rfl
  revert hl h
  match l, l' with
  | 0, _ => intro _ h; simp only [g0] at h; rw [h]
  | 1, 1 | 2, 2 | 3, 3 => intro _ h; exact h
  | 1, 3 | 2, 3 => intro _ _; rw [g3, g3]
  | 1, 2 => intro _ h; simp only [g1] at h; rw [g2, g2, ← warp t, h, warp u]
  | 1, 0 | 2, 0 | 2, 1 | 3, 0 | 3, 1 | 3, 2 => intro hl; exact absurd hl (by decide)

/-- **The levels of `sig` nest**, for every launch: a thread's instance of level `l` is `l` with
its number (`Launch.groupNum`), whose members are the threads of the launch with that number
(`Launch.members`); the numbers nest (`Launch.groupNum_nest`); level 3's one instance is every
thread of the launch and level 0's are single threads. -/
instance sig_levels : GPUProof.Levels sig where
  mem_members {L g u} := by
    obtain ⟨l, i⟩ := g
    show u ∈ Launch.members L (l, i) ↔ u ∈ List.range _ ∧ (l, L.groupNum l u) = (l, i)
    simp [Launch.members, Prod.ext_iff]
  levelOf_group := rfl
  nest {L l l' t u} hl h :=
    Prod.ext rfl (L.groupNum_nest hl (congrArg Prod.snd h :))
  top {L t} _ := by
    show List.Perm (List.filter _ (List.range _)) _
    refine .of_eq (List.filter_eq_self.2 fun n _ => ?_)
    simp [Launch.groupNum, show (⊤ : Fin 4).val = 3 from rfl]
  bot {L t} ht := by
    show List.filter _ (List.range _) = _
    have e : ∀ n, (decide (L.groupNum ⊥ n = L.groupNum ⊥ t) : Bool) = decide (n = t) := fun n => by
      simp [Launch.groupNum, show (⊥ : Fin 4).val = 0 from rfl]
    simp only [e]
    rw [List.filter_eq, List.count_eq_one_of_mem List.nodup_range ht, List.replicate_one]
  nodup {L g} := ⟨List.nodup_range, List.nodup_range.filter _⟩

/-! ### The core's `racy` at `sig` -/

/-- **The core's `racy` at `sig` by positions**, for every launch `L` and trace `U` (oldest
first) whose accesses are by threads of `L` in their blocks of threads: `racy` of `U`'s core
events holds exactly when positions `p < q` of `U` hold accesses `a` and `b` that conflict at
`sig`, by different threads, that no barrier orders: in different blocks of threads, or with no
barrier of their block strictly between them. By `GPUProof.HB.laminar_iff` (`Levels sig`): the core
orders two accesses by a rendezvous between them that holds both threads, and a barrier's
rendezvous holds exactly the threads of its block. -/
theorem racy_sig_iff {L : Launch} {U : List Event}
    (hU : ∀ a, Event.access a ∈ U → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) :
    GPUProof.racy sig (U.map (Event.toCore L)) = true ↔
      ∃ (p q : Nat) (a b : Access), p < q ∧ U[p]? = some (.access a) ∧ U[q]? = some (.access b) ∧
        GPUProof.Access.conflict sig a.toCore b.toCore = true ∧ a.who.thread ≠ b.who.thread ∧
        ¬ (a.who.cta = b.who.cta ∧ ∃ k, p < k ∧ k < q ∧ U[k]? = some (.barrier b.who.cta)) := by
  have hl : GPUProof.Laminar sig L (U.map (Event.toCore L)) := by
    intro e he
    obtain ⟨x, -, rfl⟩ := List.mem_map.1 he
    cases x with
    | access a => exact .inl ⟨_, rfl⟩
    | barrier b =>
      refine .inr (.inr ⟨b, _, (2, b), rfl, fun c => ?_⟩)
      rw [List.mem_map]
      exact ⟨fun ⟨u, hu, e⟩ => ⟨u, hu, e.symm⟩, fun ⟨u, hu, e⟩ => ⟨u, hu, e.symm⟩⟩
  have hacc1 : ∀ {p : Nat} {A : sig.Access}, (U.map (Event.toCore L))[p]? = some (.access A) →
      ∃ a, U[p]? = some (.access a) ∧ A = a.toCore := by
    intro p A h
    rw [List.getElem?_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, e⟩ := h
    cases x with
    | access a =>
      cases e
      exact ⟨a, hx, rfl⟩
    | barrier o => cases e
  have hacc2 : ∀ {p : Nat} {a : Access}, U[p]? = some (.access a) →
      (U.map (Event.toCore L))[p]? = some (.access a.toCore) := by
    intro p a h
    rw [List.getElem?_map]
    exact Option.map_eq_some_iff.2 ⟨_, h, rfl⟩
  have hsync1 : ∀ {k o : Nat} {ms : List sig.Agent},
      (U.map (Event.toCore L))[k]? = some (.sync o ms) →
      U[k]? = some (.barrier o) ∧ ms = (L.members (2, o)).map .thread := by
    intro k o ms h
    rw [List.getElem?_map, Option.map_eq_some_iff] at h
    obtain ⟨x, hx, e⟩ := h
    cases x with
    | access a => cases e
    | barrier b =>
      cases e
      exact ⟨hx, rfl⟩
  have hsync2 : ∀ {k o : Nat}, U[k]? = some (.barrier o) →
      (U.map (Event.toCore L))[k]? = some (.sync o ((L.members (2, o)).map .thread)) := by
    intro k o h
    rw [List.getElem?_map]
    exact Option.map_eq_some_iff.2 ⟨_, h, rfl⟩
  have hfence : ∀ {k : Nat} {w : sig.Agent} {p q : Unit},
      (U.map (Event.toCore L))[k]? ≠ some (.fence w p q) := by
    intro k w p q h
    rw [List.getElem?_map, Option.map_eq_some_iff] at h
    obtain ⟨x, -, e⟩ := h
    cases x <;> cases e
  have hmem : ∀ {a : Access} {o : Nat}, Event.access a ∈ U →
      ((GPUProof.Agent.thread a.who.thread : sig.Agent) ∈
        ((L.members (2, o)).map .thread : List sig.Agent) ↔ a.who.cta = o) := by
    intro a o ha
    obtain ⟨hn, hc⟩ := hU a ha
    rw [List.mem_map]
    constructor
    · rintro ⟨u, hu, e⟩
      injection e with e
      have h2 : L.groupNum 2 u = o := of_decide_eq_true (List.mem_filter.1 hu).2
      rw [hc, ← e]
      exact h2
    · intro h
      have h2 : L.groupNum 2 a.who.thread = o := by
        show a.who.thread / volume L.block = o
        rw [← hc]
        exact h
      exact ⟨a.who.thread, List.mem_filter.2 ⟨List.mem_range.2 hn, decide_eq_true h2⟩, rfl⟩
  have hhb : ∀ {p q : Nat} {a b : Access}, p < q → U[p]? = some (.access a) →
      U[q]? = some (.access b) →
      (GPUProof.HB sig (U.map (Event.toCore L)) p q ↔ a.who.thread = b.who.thread ∨
        a.who.cta = b.who.cta ∧ ∃ k, p < k ∧ k < q ∧ U[k]? = some (.barrier b.who.cta)) := by
    intro p q a b hpq hp hq
    have ha := List.mem_of_getElem? hp
    have hb := List.mem_of_getElem? hq
    have hp' := hacc2 hp
    have hq' := hacc2 hq
    rw [GPUProof.HB.laminar_iff hl]
    constructor
    · rintro ⟨-, e, e', he, he', h⟩
      rw [hp'] at he
      rw [hq'] at he'
      cases he
      cases he'
      rcases h with ⟨x, hx, hx'⟩ | ⟨k, o, ms, hpk, hkq, hk, ⟨x, hx, hxm⟩, y, hy, hym⟩
      · have h1 : x = a.toCore.who := List.mem_singleton.1 hx
        have h2 : x = b.toCore.who := List.mem_singleton.1 hx'
        exact .inl (GPUProof.Agent.thread.inj (h1.symm.trans h2))
      · have h1 : x = a.toCore.who := List.mem_singleton.1 hx
        have h2 : y = b.toCore.who := List.mem_singleton.1 hy
        subst h1 h2
        obtain ⟨hk', rfl⟩ := hsync1 hk
        have h3 := (hmem ha).1 hxm
        have h4 := (hmem hb).1 hym
        exact .inr ⟨h3.trans h4.symm, k, hpk, hkq, by rw [h4]; exact hk'⟩
    · rintro (h | ⟨hc, k, hpk, hkq, hk⟩)
      · refine ⟨hpq, _, _, hp', hq', .inl ⟨a.toCore.who, List.mem_singleton_self _, ?_⟩⟩
        show (GPUProof.Agent.thread a.who.thread : sig.Agent) ∈
          [(GPUProof.Agent.thread b.who.thread : sig.Agent)]
        rw [h]
        exact List.mem_singleton_self _
      · exact ⟨hpq, _, _, hp', hq', .inr ⟨k, b.who.cta, _, hpk, hkq, hsync2 hk,
          ⟨a.toCore.who, List.mem_singleton_self _, (hmem ha).2 hc⟩,
          b.toCore.who, List.mem_singleton_self _, (hmem hb).2 rfl⟩⟩
  rw [GPUProof.racy_iff]
  constructor
  · rintro ⟨p, q, A, B, hpq, hp, hq, hc, ho⟩
    obtain ⟨a, hpa, rfl⟩ := hacc1 hp
    obtain ⟨b, hqb, rfl⟩ := hacc1 hq
    have hn : ¬ GPUProof.HB sig (U.map (Event.toCore L)) p q := fun h => ho (Or.inl ⟨rfl, h⟩)
    rw [hhb hpq hpa hqb] at hn
    exact ⟨p, q, a, b, hpq, hpa, hqb, hc, fun h => hn (.inl h), fun h => hn (.inr h)⟩
  · rintro ⟨p, q, a, b, hpq, hp, hq, hc, ht, hn⟩
    refine ⟨p, q, a.toCore, b.toCore, hpq, hacc2 hp, hacc2 hq, hc, fun ho => ?_⟩
    unfold GPUProof.Ordered at ho
    rcases ho with ⟨-, h⟩ | ⟨k, w, hk, -⟩
    · rcases (hhb hpq hp hq).1 h with h | h
      · exact ht h
      · exact hn h
    · exact hfence hk

/-- `Access.conflict` is symmetric. -/
theorem Access.conflict_comm (a e : Access) : a.conflict e = e.conflict a := by
  rw [Bool.eq_iff_iff]
  simp only [Access.conflict, Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq,
    Bool.or_eq_true, Bool.not_eq_true']
  grind

/-! ### Races by phases, by positions oldest first -/

/-- **An access races with a trace exactly when some access of it does, by positions**, for every
access `a`, flag `sync` and trace `tr` (newest first): `a.races sync tr` holds exactly when some
position `p` of `tr.reverse` (oldest first) holds an access `e` by another thread that conflicts
with `a` and that no barrier orders: `e` is in another block of threads than `a`, or `sync` is
false and no later position holds a barrier of `a`'s block. -/
theorem Access.races_iff_rev {a : Access} : ∀ {sync : Bool} {tr : List Event},
    a.races sync tr = true ↔ ∃ (p : Nat) (e : Access), tr.reverse[p]? = some (.access e) ∧
      e.who.thread ≠ a.who.thread ∧ a.conflict e = true ∧
      ¬ (e.who.cta = a.who.cta ∧
        (sync = true ∨ ∃ k, p < k ∧ tr.reverse[k]? = some (.barrier a.who.cta)))
  | _, [] => by simp [Access.races]
  | sync, .barrier b :: tr => by
    rw [Access.races, races_iff_rev, List.reverse_cons]
    constructor
    · rintro ⟨p, e, hp, ht, hc, hn⟩
      refine ⟨p, e, getElem?_append_of_some hp, ht, hc, fun ⟨hk, hs⟩ => hn ⟨hk, ?_⟩⟩
      rcases hs with hs | ⟨k, hpk, hb⟩
      · simp [hs]
      · rcases getElem?_concat_eq_some.1 hb with ⟨-, hb⟩ | ⟨-, hb⟩
        · exact .inr ⟨k, hpk, hb⟩
        · cases hb
          exact .inl (by simp)
    · rintro ⟨p, e, hp, ht, hc, hn⟩
      rcases getElem?_concat_eq_some.1 hp with ⟨hpl, hp⟩ | ⟨-, hp⟩
      · refine ⟨p, e, hp, ht, hc, fun ⟨hk, hs⟩ => hn ⟨hk, ?_⟩⟩
        rcases hs with hs | ⟨k, hpk, hb⟩
        · simp only [Bool.or_eq_true, beq_iff_eq] at hs
          rcases hs with hs | rfl
          · exact .inl hs
          · exact .inr ⟨tr.reverse.length, hpl, List.getElem?_concat_length⟩
        · exact .inr ⟨k, hpk, getElem?_append_of_some hb⟩
      · cases hp
  | sync, .access x :: tr => by
    rw [Access.races, Bool.or_eq_true, races_iff_rev, List.reverse_cons]
    constructor
    · rintro (h | ⟨p, e, hp, ht, hc, hn⟩)
      · simp only [Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.not_eq_true', Bool.and_eq_false_iff,
          beq_eq_false_iff_ne] at h
        obtain ⟨⟨ht, hs⟩, hc⟩ := h
        refine ⟨tr.reverse.length, x, List.getElem?_concat_length, ht, hc, fun ⟨hk, hs'⟩ => ?_⟩
        rcases hs' with hs' | ⟨k, hk', hb⟩
        · rcases hs with hs | hs
          · rw [hs] at hs'
            cases hs'
          · exact hs hk
        · rcases getElem?_concat_eq_some.1 hb with ⟨h1, -⟩ | ⟨-, hb⟩
          · omega
          · cases hb
      · refine ⟨p, e, getElem?_append_of_some hp, ht, hc, fun ⟨hk, hs⟩ => hn ⟨hk, ?_⟩⟩
        rcases hs with hs | ⟨k, hpk, hb⟩
        · exact .inl hs
        · rcases getElem?_concat_eq_some.1 hb with ⟨-, hb⟩ | ⟨-, hb⟩
          · exact .inr ⟨k, hpk, hb⟩
          · cases hb
    · rintro ⟨p, e, hp, ht, hc, hn⟩
      rcases getElem?_concat_eq_some.1 hp with ⟨-, hp⟩ | ⟨rfl, hx⟩
      · refine .inr ⟨p, e, hp, ht, hc, fun ⟨hk, hs⟩ => hn ⟨hk, ?_⟩⟩
        rcases hs with hs | ⟨k, hpk, hb⟩
        · exact .inl hs
        · exact .inr ⟨k, hpk, getElem?_append_of_some hb⟩
      · cases hx
        refine .inl ?_
        simp only [Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.not_eq_true', Bool.and_eq_false_iff,
          beq_eq_false_iff_ne]
        refine ⟨⟨ht, ?_⟩, hc⟩
        cases sync
        · exact .inl rfl
        · exact .inr fun hk => hn ⟨hk, .inl rfl⟩

/-- **Clashes by phases with a barrier in front** are the tail's, for every barrier and trace
(newest first). -/
theorem clash_barrier {b : Nat} {tr : List Event} :
    (∃ x ∈ (phases (.barrier b :: tr)).1, ∃ y ∈ (phases (.barrier b :: tr)).1, clash x y = true) ↔
      ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true := by
  rw [phases_barrier]

/-- **Clashes by phases with an access `x` in front**, for every access and trace (newest
first): `x.races false tr`, or a clash of the tail. -/
theorem clash_access {x : Access} {tr : List Event} :
    (∃ u ∈ (phases (.access x :: tr)).1, ∃ y ∈ (phases (.access x :: tr)).1,
        clash u y = true) ↔
      x.races false tr = true ∨ ∃ u ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash u y = true := by
  have head : ∀ y : Access × Nat, clash (x, (phases tr).2.getD x.who.cta 0) y = true ↔
      y.1.who.thread ≠ x.who.thread ∧ x.conflict y.1 = true ∧
        (y.1.who.cta ≠ x.who.cta ∨ false = false ∧ y.2 = (phases tr).2.getD x.who.cta 0) := by
    intro y
    simp only [clash, Bool.and_eq_true, bne_iff_ne, Bool.or_eq_true, beq_iff_eq, true_and]
    exact ⟨fun ⟨⟨ht, hc⟩, hk⟩ => ⟨Ne.symm ht, hc, hk.imp Ne.symm Eq.symm⟩,
      fun ⟨ht, hc, hk⟩ => ⟨⟨Ne.symm ht, hc⟩, hk.imp Ne.symm Eq.symm⟩⟩
  rw [phases_access, races_iff]
  refine Iff.symm ⟨?_, ?_⟩
  · rintro (⟨y, hy, h⟩ | ⟨u, hu, y, hy, h⟩)
    · exact ⟨_, List.mem_cons_self, y, List.mem_cons_of_mem _ hy, (head y).2 h⟩
    · exact ⟨u, List.mem_cons_of_mem _ hu, y, List.mem_cons_of_mem _ hy, h⟩
  · rintro ⟨u, hu, y, hy, h⟩
    rcases List.mem_cons.1 hu with rfl | hu <;> rcases List.mem_cons.1 hy with rfl | hy
    · simp [clash] at h
    · exact .inl ⟨y, hy, (head y).1 h⟩
    · exact .inl ⟨u, hu, (head u).1 (clash_comm.trans h)⟩
    · exact .inr ⟨u, hu, y, hy, h⟩

/-- **Clashes by phases survive events in front**, for every trace `tr` and events `E` (newest
first). -/
theorem clash_append {tr : List Event}
    (h : ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true) :
    ∀ E : List Event, ∃ x ∈ (phases (E ++ tr)).1, ∃ y ∈ (phases (E ++ tr)).1, clash x y = true
  | [] => h
  | .access _ :: E => by rw [List.cons_append, clash_access]; exact .inr (clash_append h E)
  | .barrier _ :: E => by rw [List.cons_append, clash_barrier]; exact clash_append h E

/-- **Races by positions are races by phases**, for every trace `tr` (newest first): positions
`p < q` of `tr.reverse` hold accesses `e` and `a` by different threads that conflict and that no
barrier orders (they are in different blocks of threads, or no position strictly between them
holds a barrier of their block) exactly when two accesses of `phases tr` clash (`clash`). Each
side is, at an access `x` in front, `x.races false tr` or the tail's, and at a barrier the
tail's. -/
theorem pos_iff_phases : ∀ {tr : List Event},
    (∃ (p q : Nat) (e a : Access), p < q ∧ tr.reverse[p]? = some (.access e) ∧
      tr.reverse[q]? = some (.access a) ∧
      e.who.thread ≠ a.who.thread ∧ a.conflict e = true ∧
      ¬ (e.who.cta = a.who.cta ∧ ∃ k, p < k ∧ k < q ∧ tr.reverse[k]? = some (.barrier a.who.cta)))
      ↔ ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true
  | [] => by simp [phases]
  | .barrier b :: tr => by
    rw [clash_barrier, ← pos_iff_phases (tr := tr), List.reverse_cons]
    refine Iff.symm ?_
    constructor
    · rintro ⟨p, q, e, a, hpq, hp, hq, ht, hc, hn⟩
      refine ⟨p, q, e, a, hpq, getElem?_append_of_some hp, getElem?_append_of_some hq, ht, hc,
        fun ⟨hk, k, hpk, hkq, hb⟩ => hn ⟨hk, k, hpk, hkq, ?_⟩⟩
      have hql := (List.getElem?_eq_some_iff.1 hq).1
      rcases getElem?_concat_eq_some.1 hb with ⟨-, hb⟩ | ⟨h1, -⟩
      · exact hb
      · omega
    · rintro ⟨p, q, e, a, hpq, hp, hq, ht, hc, hn⟩
      rcases getElem?_concat_eq_some.1 hq with ⟨-, hq⟩ | ⟨-, hq⟩
      · rcases getElem?_concat_eq_some.1 hp with ⟨-, hp⟩ | ⟨-, hp⟩
        · exact ⟨p, q, e, a, hpq, hp, hq, ht, hc,
            fun ⟨hk, k, hpk, hkq, hb⟩ => hn ⟨hk, k, hpk, hkq, getElem?_append_of_some hb⟩⟩
        · cases hp
      · cases hq
  | .access x :: tr => by
    rw [clash_access, ← pos_iff_phases (tr := tr), Access.races_iff_rev, List.reverse_cons]
    refine Iff.symm ?_
    constructor
    · rintro (⟨p, e, hp, ht, hc, hn⟩ | ⟨p, q, e, a, hpq, hp, hq, ht, hc, hn⟩)
      · have hpl := (List.getElem?_eq_some_iff.1 hp).1
        refine ⟨p, tr.reverse.length, e, x, hpl, getElem?_append_of_some hp,
          List.getElem?_concat_length, ht, hc,
          fun ⟨hk, k, hpk, hkq, hb⟩ => hn ⟨hk, .inr ⟨k, hpk, ?_⟩⟩⟩
        rcases getElem?_concat_eq_some.1 hb with ⟨-, hb⟩ | ⟨-, hb⟩
        · exact hb
        · cases hb
      · refine ⟨p, q, e, a, hpq, getElem?_append_of_some hp, getElem?_append_of_some hq, ht, hc,
          fun ⟨hk, k, hpk, hkq, hb⟩ => hn ⟨hk, k, hpk, hkq, ?_⟩⟩
        rcases getElem?_concat_eq_some.1 hb with ⟨-, hb⟩ | ⟨-, hb⟩
        · exact hb
        · cases hb
    · rintro ⟨p, q, e, a, hpq, hp, hq, ht, hc, hn⟩
      rcases getElem?_concat_eq_some.1 hq with ⟨-, hq⟩ | ⟨rfl, hx⟩
      · refine .inr ?_
        rcases getElem?_concat_eq_some.1 hp with ⟨-, hp⟩ | ⟨hp1, -⟩
        · exact ⟨p, q, e, a, hpq, hp, hq, ht, hc,
            fun ⟨hk, k, hpk, hkq, hb⟩ => hn ⟨hk, k, hpk, hkq, getElem?_append_of_some hb⟩⟩
        · have hql := (List.getElem?_eq_some_iff.1 hq).1
          omega
      · cases hx
        refine .inl ?_
        rcases getElem?_concat_eq_some.1 hp with ⟨-, hp⟩ | ⟨hp1, -⟩
        · refine ⟨p, e, hp, ht, hc, fun ⟨hk, hs⟩ => hn ⟨hk, ?_⟩⟩
          rcases hs with hs | ⟨k, hpk, hb⟩
          · cases hs
          · exact ⟨k, hpk, (List.getElem?_eq_some_iff.1 hb).1, getElem?_append_of_some hb⟩
        · omega

/-- **The core's `racy` at `sig` by positions, oldest first**, for every launch `L` and trace
`tr` (newest first) whose accesses are by threads of `L` in their blocks of threads and that is
shaped (`Trace.Shaped`, oldest first): the core's `racy` at `sig` of its core events, oldest
first, holds exactly when positions `p < q` of `tr.reverse` hold accesses `e` and `a` by
different threads that conflict (`Access.conflict`) and that no barrier orders: they are in
different blocks of threads, or no position strictly between them holds a barrier of their
block. A race of the core with an `atomicrmw`'s read, which the core counts as an update, is a
race with that `atomicrmw`'s write, logged next to it. -/
theorem racy_sig_rev {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = true ↔
    ∃ (p q : Nat) (e a : Access), p < q ∧ tr.reverse[p]? = some (.access e) ∧
      tr.reverse[q]? = some (.access a) ∧
      e.who.thread ≠ a.who.thread ∧ a.conflict e = true ∧
      ¬ (e.who.cta = a.who.cta ∧ ∃ k, p < k ∧ k < q ∧ tr.reverse[k]? = some (.barrier a.who.cta))
    := by
  rw [← List.map_reverse, racy_sig_iff fun a ha => hU a (List.mem_reverse.1 ha)]
  constructor
  · rintro ⟨p, q, a, b, hpq, hp, hq, hc, ht, hn⟩
    rw [conflict_sig] at hc
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at hc
    obtain ⟨⟨hov, hw⟩, hx⟩ := hc
    rw [Access.kind_writes, Access.kind_writes] at hw
    by_cases hab : a.write = true ∨ b.write = true
    · refine ⟨p, q, a, b, hpq, hp, hq, ht, ?_, hn⟩
      rw [Access.conflict_comm, Access.conflict, hov, hx]
      rcases hab with h | h <;> simp [h]
    simp only [not_or, Bool.not_eq_true] at hab
    obtain ⟨haw, hbw⟩ := hab
    by_cases hao : a.atomic.isSome = true
    · -- `a` is an `atomicrmw`'s read; its write is at `p + 1`
      have hp1 := hs.2 p a hp hao haw
      have hq1 : p + 1 ≠ q := by
        rintro rfl
        rw [hq] at hp1
        cases hp1
        exact ht rfl
      refine ⟨p + 1, q, { a with write := true }, b, by omega, hp1, hq, ht, ?_, ?_⟩
      · rw [Access.conflict_comm]
        show (a.overlaps b && (true || b.write) &&
          !(a.atomic.any RmwOp.commutes && a.atomic == b.atomic && a.ptr == b.ptr &&
            a.len == b.len)) = true
        simp only [hov, hx, Bool.true_or, Bool.true_and, Bool.not_false]
      · rintro ⟨h1, k, hpk, hkq, hk⟩
        exact hn ⟨h1, k, by omega, hkq, hk⟩
    · -- `b` is an `atomicrmw`'s read; its write is at `q + 1`
      have hbo : b.atomic.isSome = true := by
        simp only [haw, hbw, Bool.false_or, Bool.or_eq_true] at hw
        rcases hw with h | h
        · exact absurd h hao
        · exact h
      have hq1 := hs.2 q b hq hbo hbw
      refine ⟨p, q + 1, a, { b with write := true }, by omega, hp, hq1, ht, ?_, ?_⟩
      · rw [Access.conflict_comm]
        show (a.overlaps b && (a.write || true) &&
          !(a.atomic.any RmwOp.commutes && a.atomic == b.atomic && a.ptr == b.ptr &&
            a.len == b.len)) = true
        simp only [hov, hx, Bool.or_true, Bool.true_and, Bool.not_false]
      · rintro ⟨h1, k, hpk, hkq, hk⟩
        refine hn ⟨h1, k, hpk, ?_, hk⟩
        rcases Nat.lt_or_ge k q with h | h
        · exact h
        · rcases Nat.lt_or_eq_of_le h with h | rfl
          · omega
          · rw [hq] at hk
            cases hk
  · rintro ⟨p, q, e, a, hpq, hp, hq, ht, hc, hn⟩
    refine ⟨p, q, e, a, hpq, hp, hq, ?_, ht, hn⟩
    rw [Access.conflict_comm] at hc
    rw [conflict_sig, Access.kind_writes, Access.kind_writes]
    simp only [Access.conflict, Bool.and_eq_true, Bool.not_eq_true'] at hc
    obtain ⟨⟨hov, hw⟩, hx⟩ := hc
    rw [hov, hx]
    simp only [Bool.or_eq_true] at hw
    rcases hw with h | h <;> simp [h]

/-- **L9 at `sig`.** For every launch `L` and trace `tr` (newest first) whose accesses are by
threads of `L` in their blocks of threads and that is shaped: the core's `racy` at `sig` of its
core events, oldest first, holds exactly when two accesses of `phases tr` clash. -/
theorem racy_iff {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = true ↔
      ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true :=
  (racy_sig_rev hU hs).trans pos_iff_phases

/-- **The premises of `racy_iff` from a check**, for every launch `L` and trace `tr` (newest
first) every access of which is by a thread of `L` in its block of threads, is not of invariant
memory and is a write if it is atomic (a check `decide` evaluates at numerals): `tr` has the
premises of `racy_iff`; it is shaped, as no access is the read of a read-modify-write. -/
theorem Trace.fits_of_check {L : Launch} {tr : List Event}
    (h : tr.all (fun e => match e with
      | .access a => decide (a.who.thread < volume L.grid * volume L.block ∧
          a.who.cta = a.who.thread / volume L.block) && !a.invariant &&
            (a.atomic.isNone || a.write)
      | .barrier _ => true) = true) :
    (∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) ∧ Trace.Shaped tr.reverse := by
  have hA : ∀ a, Event.access a ∈ tr → (a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) ∧ a.invariant = false ∧
        (a.atomic = none ∨ a.write = true) := fun a ha => by
    have := List.all_eq_true.1 h (.access a) ha
    simp only [Bool.and_eq_true, decide_eq_true_eq, Bool.not_eq_true', Bool.or_eq_true,
      Option.isNone_iff_eq_none] at this
    exact ⟨this.1.1, this.1.2, this.2⟩
  refine ⟨fun a ha => (hA a ha).1, fun a ha hi => ?_, fun p a hp ho hw => ?_⟩
  · simp [(hA a (List.mem_reverse.1 ha)).2.1] at hi
  · rcases (hA a (List.mem_reverse.1 (List.mem_of_getElem? hp))).2.2 with e | e
    · simp [e] at ho
    · rw [e] at hw
      cases hw

/-- `fast` finds every data race: a trace it passes has none at `sig`, for every launch and trace
whose accesses are by threads of the launch in their blocks of threads and that is shaped. -/
theorem fast_sound {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (h : fast tr = false) : GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  cases hr : GPUProof.racy sig (tr.map (Event.toCore L)).reverse
  · rfl
  obtain ⟨x, hx, y, hy, hc⟩ := (racy_iff hU hs).1 hr
  have found : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, clash x y = true → x.1.write = true →
      fast tr = true := by
    intro x hx y hy hc hw
    simp only [clash, Access.conflict, Bool.and_eq_true] at hc
    obtain ⟨b, hbx, hby⟩ := Access.overlaps_bytes hc.1.2.1.1
    simp only [fast, List.any_eq_true, Bool.and_eq_true]
    exact ⟨x, hx, hw, b, hbx, y, mem_buckets (.inr ⟨hy, hby⟩), by
      simp only [clash, Access.conflict, Bool.and_eq_true]; exact hc⟩
  have hw : x.1.write = true ∨ y.1.write = true := by
    simp only [clash, Access.conflict, Bool.and_eq_true, Bool.or_eq_true] at hc
    exact hc.1.2.1.2
  rcases hw with hw | hw
  · rw [found x hx y hy hc hw] at h; cases h
  · rw [found y hy x hx (clash_comm ▸ hc) hw] at h; cases h

/-! ### A racy trace stays racy -/

/-- **Happens-before in a prefix**, for every machine, pair of traces `A` and `B` (oldest first)
and positions `i` and `j < A.length`: `HB` of `A ++ B` from `i` to `j` is `HB` of `A`. An edge
goes forward and reads only the events at its two ends (`GPUProof.edge`). -/
theorem hb_append_iff {S : GPUProof.Sig} {A B : List S.Event} {i j : Nat} (hj : j < A.length) :
    GPUProof.HB S (A ++ B) i j ↔ GPUProof.HB S A i j := by
  have he : ∀ {x y : Nat}, y < A.length →
      (GPUProof.edge S (A ++ B) x y = true ↔ GPUProof.edge S A x y = true) := by
    intro x y hy
    unfold GPUProof.edge
    by_cases hx : x < y
    · rw [List.getElem?_append_left (lt_trans hx hy), List.getElem?_append_left hy]
    · simp [hx]
  unfold GPUProof.HB
  constructor
  · intro h
    induction h with
    | single h => exact .single ((he hj).1 h)
    | tail _ h ih => exact .tail (ih (lt_trans (GPUProof.edge_lt S h).1 hj)) ((he hj).1 h)
  · intro h
    induction h with
    | single h => exact .single ((he hj).2 h)
    | tail _ h ih => exact .tail (ih (lt_trans (GPUProof.edge_lt S h).1 hj)) ((he hj).2 h)

/-- **A racy trace stays racy when events are added after it**, for every machine and pair of
traces `A` and `B` (oldest first): positions of `A` that `A` does not order are not ordered in
`A ++ B` either (`hb_append_iff`). -/
theorem racy_of_append {S : GPUProof.Sig} {A B : List S.Event}
    (h : GPUProof.racy S A = true) : GPUProof.racy S (A ++ B) = true := by
  rw [GPUProof.racy_iff] at h ⊢
  unfold GPUProof.Racy at h ⊢
  obtain ⟨i, j, a, b, hij, hi, hj, hc, ho⟩ := h
  have hjl := (List.getElem?_eq_some_iff.1 hj).1
  refine ⟨i, j, a, b, hij, getElem?_append_of_some hi, getElem?_append_of_some hj, hc,
    fun ho' => ho ?_⟩
  unfold GPUProof.Ordered at ho' ⊢
  rcases ho' with ⟨hp, hh⟩ | ⟨k, w, hk, h1, h2⟩
  · exact .inl ⟨hp, (hb_append_iff hjl).1 hh⟩
  · have hkl : k < A.length := lt_trans (GPUProof.HB.lt S h2).1 hjl
    exact .inr ⟨k, w, by rwa [List.getElem?_append_left hkl] at hk, (hb_append_iff hkl).1 h1,
      (hb_append_iff hjl).1 h2⟩

/-- **Events with no access after a trace keep `racy`**, for every machine and pair of traces `A`
and `B` (oldest first) where `B` has no access: a race of `A ++ B` is between two positions of
`A`, which `A ++ B` orders exactly when `A` does (`hb_append_iff`); the converse is
`racy_of_append`. -/
theorem racy_append_eq {S : GPUProof.Sig} {A B : List S.Event} (hB : ∀ a, .access a ∉ B) :
    GPUProof.racy S (A ++ B) = GPUProof.racy S A := by
  refine Bool.eq_iff_iff.2 ⟨fun h => ?_, racy_of_append⟩
  rw [GPUProof.racy_iff] at h ⊢
  unfold GPUProof.Racy at h ⊢
  obtain ⟨i, j, a, b, hij, hi, hj, hc, ho⟩ := h
  have hjl : j < A.length := by
    refine Nat.lt_of_not_le fun hn => hB b ?_
    rw [List.getElem?_append_right hn] at hj
    exact List.mem_of_getElem? hj
  rw [List.getElem?_append_left (lt_trans hij hjl)] at hi
  rw [List.getElem?_append_left hjl] at hj
  refine ⟨i, j, a, b, hij, hi, hj, hc, fun ho' => ho ?_⟩
  unfold GPUProof.Ordered at ho' ⊢
  rcases ho' with ⟨hp, hh⟩ | ⟨k, w, hk, h1, h2⟩
  · exact .inl ⟨hp, (hb_append_iff hjl).2 hh⟩
  · have hkl : k < A.length := lt_trans (GPUProof.HB.lt S h2).1 hjl
    exact .inr ⟨k, w, getElem?_append_of_some hk, (hb_append_iff hkl).2 h1,
      (hb_append_iff hjl).2 h2⟩

/-- **A racy trace stays racy when events are added** (newest first), at `sig`, for every launch,
trace `tr` and events `E`: the core's `racy` of `tr`'s core events, oldest first, gives it of
`E ++ tr`'s. -/
theorem racy_append {L : Launch} {tr : List Event}
    (h : GPUProof.racy sig (tr.map (Event.toCore L)).reverse = true) (E : List Event) :
    GPUProof.racy sig ((E ++ tr).map (Event.toCore L)).reverse = true := by
  rw [List.map_append, List.reverse_append]
  exact racy_of_append h

/-- A racy trace stays racy when an event is added, at `sig`, for every launch, event and
trace. -/
theorem racy_cons (e : Event) {L : Launch} {tr : List Event}
    (h : GPUProof.racy sig (tr.map (Event.toCore L)).reverse = true) :
    GPUProof.racy sig ((e :: tr).map (Event.toCore L)).reverse = true :=
  racy_append h [e]

/-- **Barriers in front keep `racy`**, at `sig`, for every launch, trace `tr` and events `E` with
no access (newest first): the core's `racy` of `E ++ tr`'s core events, oldest first, is that of
`tr`'s (`racy_append_eq`). -/
theorem racy_barriers {L : Launch} {tr E : List Event} (hE : ∀ a, .access a ∉ E) :
    GPUProof.racy sig ((E ++ tr).map (Event.toCore L)).reverse =
      GPUProof.racy sig (tr.map (Event.toCore L)).reverse := by
  rw [List.map_append, List.reverse_append]
  refine racy_append_eq fun a ha => ?_
  obtain ⟨e, he, h⟩ := List.mem_map.1 (List.mem_reverse.1 ha)
  cases e with
  | access x => exact hE x he
  | barrier _ => cases h

end MojoProof.Sem
