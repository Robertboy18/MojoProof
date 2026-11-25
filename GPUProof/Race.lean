import GPUProof.Sig
import Mathlib.Logic.Relation

/-!
# The race check, on every machine

The race predicate belongs to the core, not to a machine: a machine logs its accesses, its
ordering events and its fences as core events (`Event`), and says which pairs of updates it
exempts (`Sig.exempt`). On a trace of machine `S`, oldest first, positions are list indices.

* `edge`: an edge of happens-before from position `i` to a later position `j`, when the events
  there share an agent (program order; a rendezvous lies on the program order of every member)
  or the event at `i` releases the phase of an object that the event at `j` acquires.
* `HB`: happens-before, the transitive closure of `edge` (Mathlib's `Relation.TransGen`). It only
  goes forward (`HB.lt`).
* `scan`: one pass over the trace in order, since every edge goes forward. It gives each position
  its clock, the set of positions that are it or happen before it, kept as the bits of a number:
  the join of the position, the clocks of its agents so far and, at an acquire, the clock of the
  phase it acquires (`testBit_clock`). `hb`, the check of one pair against the clock of the
  later position (`clock`), decides `HB` (`hb_iff`).
* `Ordered`: an access through proxy `p` is ordered before an access through proxy `q` when
  `p = q` and `HB` orders them, or when `HB` orders the first before a fence from `p` to `q` and
  that fence before the second; `ordered` decides it (`ordered_iff`).
* `Racy`: two accesses that conflict (`Access.conflict`) and that the trace does not order.
  `racy`, the same pass, checks each access against the writes before it and, when it writes,
  against the other accesses before it too, since a conflict needs a write: first the order,
  through its clock and the clocks of the fences before it, then whether they share a byte
  (`Sig.share`), then the machine's exemption. On a machine that proves its placement injective
  (`Sig.placeInj`, a proof of the law `PlaceInj`) the shared byte is decided by the two buffers and
  intervals of offsets (`Access.meets_iff`), and on the others by the bytes, which the pass keeps
  with each access. It decides `Racy` (`racy_iff`). One agent's accesses through one proxy are
  ordered by its program order, so a race needs two agents, or one agent and two proxies.
* `kept`: no access that writes shares a byte with a frozen read of the trace, before or after it.
  It collects the bytes written and the frozen bytes in one walk of the trace (`keptFrom`), sorts
  them by the machine's numbering of bytes (`Sig.key`) and walks the two sorted lists once. It
  decides `Kept`, the same statement as a proposition (`kept_iff`).

docs/proofs/core.md gives the definitions and where they depart from the design.
-/

namespace GPUProof

open Relation

variable (S : Sig)

/-- Event `e` releases phase `ph` of an object `o` and event `e'` acquires phase `ph` of `o`, for
every event type with decidable equality of objects. -/
def Event.relAcq {A Buf Op Proxy Obj : Type} [DecidableEq Obj] :
    Event A Buf Op Proxy Obj → Event A Buf Op Proxy Obj → Bool
  | .rel _ o ph, .acq _ o' ph' => decide (o = o') && decide (ph = ph')
  | _, _ => false

/-- An edge of happens-before from position `i` to position `j` of trace `tr` of machine `S`:
`i < j`, both are positions of `tr`, and the events there share an agent (`Event.agents`, so
program order, a rendezvous lying on the program order of every member), or the event at `i`
releases the phase of an object that the event at `j` acquires (`Event.relAcq`). -/
def edge (tr : List S.Event) (i j : Nat) : Bool :=
  decide (i < j) && tr[i]?.any fun e => tr[j]?.any fun e' =>
    e.agents.any (fun a => decide (a ∈ e'.agents)) || e.relAcq e'

/-- An edge goes forward, to a position of the trace, on every machine and trace. -/
theorem edge_lt {tr : List S.Event} {i j : Nat} (h : edge S tr i j = true) :
    i < j ∧ j < tr.length := by
  simp only [edge, Bool.and_eq_true, decide_eq_true_eq, Option.any_eq_true] at h
  obtain ⟨hij, _, _, e', he', _⟩ := h
  exact ⟨hij, (List.getElem?_eq_some_iff.1 he').1⟩

/-- Happens-before on the positions of trace `tr` of machine `S`: the transitive closure of
`edge`, so each agent's program order (a rendezvous lies on the program order of every member)
and an edge from each release of a phase of an object to each later acquire of that phase. -/
def HB (tr : List S.Event) : Nat → Nat → Prop :=
  TransGen fun i j => edge S tr i j = true

/-- Happens-before goes forward, to a position of the trace, on every machine and trace. -/
theorem HB.lt {tr : List S.Event} {i j : Nat} (h : HB S tr i j) : i < j ∧ j < tr.length := by
  induction h with
  | single h => exact edge_lt S h
  | tail _ h ih => exact ⟨Nat.lt_trans ih.1 (edge_lt S h).1, (edge_lt S h).2⟩

/-- Happens-before into position `j`: an `edge` into `j` from `i` or from a position that `i`
happens before, on every machine and trace. -/
theorem HB.tail_iff {tr : List S.Event} {i j : Nat} :
    HB S tr i j ↔ ∃ k, edge S tr k j = true ∧ (i = k ∨ HB S tr i k) := by
  unfold HB
  rw [TransGen.tail'_iff]
  constructor
  · rintro ⟨k, h, hk⟩
    exact ⟨k, hk, (reflTransGen_iff_eq_or_transGen.1 h).imp Eq.symm id⟩
  · rintro ⟨k, hk, h⟩
    exact ⟨k, reflTransGen_iff_eq_or_transGen.2 (h.imp Eq.symm id), hk⟩

/-! ### Clocks

A clock is a set of positions of a trace, kept as the bits of a number (`Nat.testBit`): `0` has
no position, and joining two clocks is `Nat.lor`. The pass of the race check (`scan`) gives each
position the clock of the positions that are it or happen before it (`testBit_clock`). -/

/-- The clock of key `k` in the list `l` of keys and clocks: the first one listed for `k`, or `0`
when none is, for every key type with decidable equality. -/
def clockOf {κ : Type} [DecidableEq κ] : List (κ × Nat) → κ → Nat
  | [], _ => 0
  | (k', c) :: l, k => if k' = k then c else clockOf l k

/-- The list `l` of keys and clocks with clock `c` joined into the clock of key `k`, for every key
type with decidable equality. -/
def addClock {κ : Type} [DecidableEq κ] : List (κ × Nat) → κ → Nat → List (κ × Nat)
  | [], k, c => [(k, c)]
  | (k', c') :: l, k, c => if k' = k then (k', c' ||| c) :: l else (k', c') :: addClock l k c

/-- Joining clock `c` into the clock of key `k` changes the clock of `k` alone, for every key
type with decidable equality. -/
theorem clockOf_addClock {κ : Type} [DecidableEq κ] (l : List (κ × Nat)) (k x : κ) (c : Nat) :
    clockOf (addClock l k c) x = if k = x then clockOf l x ||| c else clockOf l x := by
  induction l with
  | nil => by_cases h : k = x <;> simp [addClock, clockOf, h]
  | cons p l ih =>
    obtain ⟨k', c'⟩ := p
    by_cases h1 : k' = k
    · subst h1
      by_cases h2 : k' = x <;> simp [addClock, clockOf, h2]
    · by_cases h2 : k' = x
      · subst h2
        simp [addClock, clockOf, h1, Ne.symm h1]
      · simp [addClock, clockOf, h1, h2, ih]

/-- Joining clock `c` into the clocks of the keys of list `ks`, one after the other: the clock of
key `x` gains the positions of `c` exactly when `x` is one of the keys, for every key type with
decidable equality. -/
theorem testBit_clockOf_foldl {κ : Type} [DecidableEq κ] (ks : List κ) (l : List (κ × Nat))
    (c : Nat) (x : κ) (i : Nat) :
    (clockOf (ks.foldl (fun l k => addClock l k c) l) x).testBit i = true ↔
      (clockOf l x).testBit i = true ∨ (x ∈ ks ∧ c.testBit i = true) := by
  induction ks generalizing l with
  | nil => simp
  | cons k ks ih =>
    rw [List.foldl_cons, ih, clockOf_addClock]
    by_cases h : k = x
    · subst h
      by_cases hc : c.testBit i = true <;> simp [hc]
    · simp [h, Ne.symm h]

/-- Joining the clocks `f b` of the members `b` of list `l` into clock `c`, one after the other:
the result has a position exactly when `c` or one of those clocks has it, for every list. -/
theorem testBit_foldl_or {α : Type} (l : List α) (f : α → Nat) (c i : Nat) :
    (l.foldl (fun c b => c ||| f b) c).testBit i = true ↔
      c.testBit i = true ∨ ∃ b ∈ l, (f b).testBit i = true := by
  induction l generalizing c with
  | nil => simp
  | cons b l ih => simp [ih, or_assoc]

/-- Under the law on `place` (`GPUProof.PlaceInj`), accesses `a` and `b` share a byte
(`Access.locs`) exactly when they are of one buffer and their intervals of offsets meet
(`Access.meets`), for every machine with the law. -/
theorem Access.meets_iff (h : PlaceInj S.place) {a b : S.Access} :
    Access.meets S a b = true ↔ ∃ l ∈ a.locs S, l ∈ b.locs S := by
  simp only [Access.meets, Access.locs, Bool.and_eq_true, decide_eq_true_eq, List.mem_map,
    List.mem_range]
  constructor
  · rintro ⟨⟨⟨⟨hb, h1⟩, h2⟩, ha⟩, hb0⟩
    rcases Int.le_total a.off b.off with hle | hle
    · refine ⟨_, ⟨(b.off - a.off).toNat, by omega, rfl⟩, 0, hb0, ?_⟩
      rw [hb]; congr 1; omega
    · refine ⟨_, ⟨0, ha, rfl⟩, (a.off - b.off).toNat, by omega, ?_⟩
      rw [hb]; congr 1; omega
  · rintro ⟨_, ⟨i, hi, rfl⟩, j, hj, he⟩
    by_cases hbuf : b.buf = a.buf
    · rw [hbuf] at he
      have := (h he).2
      exact ⟨⟨⟨⟨hbuf.symm, by omega⟩, by omega⟩, by omega⟩, by omega⟩
    · exact absurd (h he).1 hbuf

/-- `Sig.share` on the bytes of accesses `a` and `b` (`Access.locs`) decides whether they share
one, for every machine: by `Access.meets_iff` under the law that `Sig.placeInj` proves, and by
comparing the bytes otherwise. -/
theorem Sig.share_iff {a b : S.Access} :
    S.share a b (a.locs S) (b.locs S) = true ↔ ∃ l ∈ a.locs S, l ∈ b.locs S := by
  unfold Sig.share
  split
  next p _ => exact Access.meets_iff S p.down
  next => simp

/-- The state of the race check's pass over a trace of machine `S` (`scan`), after its first
positions, for every machine: the clock of each agent and of each phase of each object, the
fences, the accesses that write and the others, each with its position and its bytes, and whether
two of those accesses race. -/
structure Scan where
  /-- The state of the pass from its six fields, for every machine. -/
  mk ::
  /-- The clock of each agent: the positions of its events so far and of those before them in
  happens-before. -/
  cur : List (S.Agent × Nat)
  /-- The clock of each phase of each object: the positions of its releases so far and of those
  before them in happens-before. -/
  rel : List ((S.Obj × Nat) × Nat)
  /-- The fences so far, each with its position, its two proxies and its clock. -/
  fences : List (Nat × S.Proxy × S.Proxy × Nat)
  /-- The accesses so far that write (`Kind.writes`), each with its position and its bytes
  (`Access.locs`). -/
  writes : List (Nat × S.Access × List S.Loc)
  /-- The accesses so far that do not write, each with its position and its bytes. -/
  reads : List (Nat × S.Access × List S.Loc)
  /-- Whether two of the accesses so far race. -/
  racy : Bool

section Pass

variable {S}

/-- The clock of the phase that event `e` acquires, from the state `s` of the pass, for every
machine: the clock of that phase of that object when `e` acquires one, `0` otherwise. -/
def Scan.acqClock (s : Scan S) : S.Event → Nat
  | .acq _ o ph => clockOf s.rel (o, ph)
  | .access _ | .sync _ _ | .rel _ _ _ | .fence _ _ _ => 0

/-- The clock of event `e` at position `j`, from the state `s` of the pass over the positions
before `j`, for every machine: `j`, the clocks of `e`'s agents and the clock of the phase `e`
acquires, joined. -/
def Scan.clock (s : Scan S) (j : Nat) (e : S.Event) : Nat :=
  e.agents.foldl (fun c b => c ||| clockOf s.cur b) (2 ^ j ||| s.acqClock e)

/-- The check of the access `x.2.1` at position `x.1`, with bytes `x.2.2`, against a later access
`b` with clock `c` and bytes `L`, after the state `s` of the pass, for every machine: neither `c`
(when their proxies are the same) nor a fence of `s` from `x.2.1`'s proxy to `b`'s, after `x.1` in
its clock and in `c`, orders them, they share a byte (`Sig.share`, on `x.2.2` and `L`), and the
machine does not exempt them (`Sig.exempt`). The pass checks only pairs in which one of them
writes (`Scan.step`). -/
def Scan.races (s : Scan S) (c : Nat) (b : S.Access) (L : List S.Loc)
    (x : Nat × S.Access × List S.Loc) : Bool :=
  !((decide (x.2.1.proxy = b.proxy) && c.testBit x.1) ||
      s.fences.any fun f => decide (f.2.1 = x.2.1.proxy) && decide (f.2.2.1 = b.proxy) &&
        decide (x.1 < f.1) && f.2.2.2.testBit x.1 && c.testBit f.1) &&
    S.share x.2.1 b x.2.2 L && !S.exempt x.2.1 b

/-- One step of the pass over trace `tr`, at position `j`, for every machine: the event there gets
its clock (`Scan.clock`), which becomes part of the clock of each of its agents; a release joins
it into the clock of its phase, a fence is kept with it, and an access, with its bytes
(`Access.locs`), is checked (`Scan.races`) against the writes before it and, when it writes,
against the other accesses before it too, then kept with the writes or with the others. -/
def Scan.step (tr : List S.Event) (s : Scan S) (j : Nat) : Scan S :=
  match tr[j]? with
  | none => s
  | some e =>
    let c := s.clock j e
    let cur := e.agents.foldl (fun l b => addClock l b c) s.cur
    match e with
    | .access b =>
      let L := b.locs S
      match b.kind.writes with
      | true =>
        { s with
          cur := cur
          writes := (j, b, L) :: s.writes
          racy := s.racy || s.writes.any (s.races c b L) || s.reads.any (s.races c b L) }
      | false =>
        { s with
          cur := cur
          reads := (j, b, L) :: s.reads
          racy := s.racy || s.writes.any (s.races c b L) }
    | .rel _ o ph => { s with cur := cur, rel := addClock s.rel (o, ph) c }
    | .fence _ p q => { s with cur := cur, fences := (j, p, q, c) :: s.fences }
    | _ => { s with cur := cur }

end Pass

/-- The pass of the race check over the first `K` positions of trace `tr` of machine `S`, in
order from no clocks (`Scan.step`), for every machine. -/
def scan (tr : List S.Event) (K : Nat) : Scan S :=
  (List.range K).foldl (Scan.step tr) ⟨[], [], [], [], [], false⟩

/-- The clock of position `j` of trace `tr` of machine `S`, from the pass over the positions
before it, for every machine: the positions that are `j` or happen before `j`
(`testBit_clock`), or `0` when `j` is not a position of `tr`. -/
def clock (tr : List S.Event) (j : Nat) : Nat :=
  match tr[j]? with
  | some e => (scan S tr j).clock j e
  | none => 0

/-- The check of `HB S tr i j`, for every machine: `i` comes before `j` and is in the clock of `j`
(`clock`). -/
def hb (tr : List S.Event) (i j : Nat) : Bool :=
  decide (i < j) && (clock S tr j).testBit i

/-- In trace `tr` of machine `S`, an access through proxy `p` at position `i` is ordered before
an access through proxy `q` at position `j`: `p = q` and `HB S tr i j`, or `HB` orders `i` before
a fence from `p` to `q` (by any agent) and that fence before `j`. -/
def Ordered (tr : List S.Event) (p q : S.Proxy) (i j : Nat) : Prop :=
  (p = q ∧ HB S tr i j) ∨ ∃ k w, tr[k]? = some (.fence w p q) ∧ HB S tr i k ∧ HB S tr k j

/-- The event `o`, if any, is a fence from proxy `p` to proxy `q`. -/
def isFence (p q : S.Proxy) : Option S.Event → Bool
  | some (Event.fence _ p' q') => decide (p' = p) && decide (q' = q)
  | _ => false

/-- `isFence` holds exactly of the fences from `p` to `q`, on every machine. -/
theorem isFence_iff {p q : S.Proxy} {o : Option S.Event} :
    isFence S p q o = true ↔ ∃ w, o = some (.fence w p q) := by
  rcases o with _ | (_ | _ | _ | _ | ⟨w, p', q'⟩) <;> simp [isFence]

/-- The check of `Ordered S tr p q i j`, for every machine: `p = q` and `hb`, or a position of a
fence from `p` to `q` that `hb` orders after `i` and before `j`. -/
def ordered (tr : List S.Event) (p q : S.Proxy) (i j : Nat) : Bool :=
  (decide (p = q) && hb S tr i j) ||
    (List.range tr.length).any fun k => isFence S p q tr[k]? && hb S tr i k && hb S tr k j

/-- Trace `tr` of machine `S` has a data race: two accesses, at positions `i < j`, that conflict
(`Access.conflict`) and that `tr` does not order (`Ordered`, through their proxies). -/
def Racy (tr : List S.Event) : Prop :=
  ∃ i j a b, i < j ∧ tr[i]? = some (.access a) ∧ tr[j]? = some (.access b) ∧
    Access.conflict S a b = true ∧ ¬ Ordered S tr a.proxy b.proxy i j

/-- Positions `i` and `j` of trace `tr` hold accesses that conflict and that `ordered` does not
order. -/
def racePair (tr : List S.Event) (i j : Nat) : Bool :=
  match tr[i]?.bind Event.access?, tr[j]?.bind Event.access? with
  | some a, some b => Access.conflict S a b && !ordered S tr a.proxy b.proxy i j
  | _, _ => false

section Pass

variable {S}

/-- The state `s` of the pass over the first `K` positions of trace `tr` is right for them, for
every machine: the clock of each agent has the positions of its events below `K` and of those
before them in happens-before, the clock of each phase of each object the same for its releases,
and the pass keeps the fences below `K` with their clocks and the accesses below `K` with their
bytes, those that write apart from the others. -/
structure Scan.Inv (tr : List S.Event) (K : Nat) (s : Scan S) : Prop where
  /-- `Scan.Inv tr K s` from its six fields, for every machine, trace and state. -/
  mk ::
  /-- The clock of agent `b`. -/
  cur : ∀ b i, (clockOf s.cur b).testBit i = true ↔
    ∃ k < K, (∃ e, tr[k]? = some e ∧ b ∈ e.agents) ∧ (i = k ∨ HB S tr i k)
  /-- The clock of phase `ph` of object `o`. -/
  rel : ∀ o ph i, (clockOf s.rel (o, ph)).testBit i = true ↔
    ∃ k < K, (∃ w, tr[k]? = some (.rel w o ph)) ∧ (i = k ∨ HB S tr i k)
  /-- Each fence kept is a fence below `K`, with its clock. -/
  fences : ∀ f ∈ s.fences, f.1 < K ∧ (∃ w, tr[f.1]? = some (.fence w f.2.1 f.2.2.1)) ∧
    ∀ i, f.2.2.2.testBit i = true ↔ i = f.1 ∨ HB S tr i f.1
  /-- Each fence below `K` is kept. -/
  fences' : ∀ k w p q, k < K → tr[k]? = some (.fence w p q) → ∃ c, (k, p, q, c) ∈ s.fences
  /-- The writes kept are the accesses below `K` that write, with their bytes. -/
  writes : ∀ i a L, (i, a, L) ∈ s.writes ↔
    i < K ∧ tr[i]? = some (.access a) ∧ a.kind.writes = true ∧ L = a.locs S
  /-- The other accesses kept are the accesses below `K` that do not write, with their bytes. -/
  reads : ∀ i a L, (i, a, L) ∈ s.reads ↔
    i < K ∧ tr[i]? = some (.access a) ∧ a.kind.writes = false ∧ L = a.locs S

/-- After a state of the pass that is right for the positions below `K`, the clock of the event at
`K` has exactly `K` and the positions before `K` in happens-before, for every machine and trace. -/
theorem Scan.Inv.testBit_clock {tr : List S.Event} {K : Nat} {s : Scan S} {e : S.Event}
    (hs : s.Inv tr K) (he : tr[K]? = some e) (i : Nat) :
    (s.clock K e).testBit i = true ↔ i = K ∨ HB S tr i K := by
  have hacq : (s.acqClock e).testBit i = true ↔
      ∃ k < K, (∃ ek, tr[k]? = some ek ∧ ek.relAcq e = true) ∧ (i = k ∨ HB S tr i k) := by
    cases e
    case acq w o ph =>
      simp only [Scan.acqClock, hs.rel]
      refine exists_congr fun k => and_congr_right fun _ => and_congr_left fun _ => ⟨?_, ?_⟩
      · rintro ⟨w', hw'⟩
        exact ⟨_, hw', by simp [Event.relAcq]⟩
      · rintro ⟨ek, hek, h⟩
        cases ek <;> simp [Event.relAcq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨_, hek⟩
    all_goals
      simp only [Scan.acqClock, Nat.zero_testBit, Bool.false_eq_true, false_iff]
      rintro ⟨k, -, ⟨ek, -, h⟩, -⟩
      cases ek <;> simp [Event.relAcq] at h
  have hedge : ∀ k, edge S tr k K = true ↔ k < K ∧ ∃ ek, tr[k]? = some ek ∧
      ((∃ b ∈ ek.agents, b ∈ e.agents) ∨ ek.relAcq e = true) := by
    intro k
    simp only [edge, he, Bool.and_eq_true, decide_eq_true_eq, Option.any_some,
      Option.any_eq_true, Bool.or_eq_true, List.any_eq_true]
  rw [Scan.clock, testBit_foldl_or, Nat.testBit_or, Nat.testBit_two_pow, Bool.or_eq_true,
    decide_eq_true_eq, hacq, HB.tail_iff]
  simp only [hs.cur]
  constructor
  · rintro ((h | ⟨k, hk, ⟨ek, hek, hra⟩, hik⟩) | ⟨b, hb, k, hk, ⟨e', he', hb'⟩, hik⟩)
    · exact .inl h.symm
    · exact .inr ⟨k, (hedge k).2 ⟨hk, ek, hek, .inr hra⟩, hik⟩
    · exact .inr ⟨k, (hedge k).2 ⟨hk, e', he', .inl ⟨b, hb', hb⟩⟩, hik⟩
  · rintro (h | ⟨k, hkK, hik⟩)
    · exact .inl (.inl h.symm)
    · obtain ⟨hk, ek, hek, ⟨b, hbk, hbe⟩ | hra⟩ := (hedge k).1 hkK
      · exact .inr ⟨b, hbe, k, hk, ⟨ek, hek, hbk⟩, hik⟩
      · exact .inl (.inr ⟨k, hk, ⟨ek, hek, hra⟩, hik⟩)

/-- The pass over the first `K` positions of trace `tr` reaches a state that is right for them
(`Scan.Inv`), for every machine, trace and `K`. -/
theorem scan_inv (tr : List S.Event) (K : Nat) : (scan S tr K).Inv tr K := by
  induction K with
  | zero =>
    exact ⟨fun _ _ => by simp [scan, clockOf], fun _ _ _ => by simp [scan, clockOf],
      fun _ hf => by simp [scan] at hf, fun _ _ _ _ hk => absurd hk (Nat.not_lt_zero _),
      fun _ _ _ => by simp [scan], fun _ _ _ => by simp [scan]⟩
  | succ K ih =>
    rw [show scan S tr (K + 1) = Scan.step tr (scan S tr K) K by simp [scan, List.range_succ]]
    generalize scan S tr K = s at ih
    cases he : tr[K]? with
    | none =>
      have hstep : Scan.step tr s K = s := by simp only [Scan.step, he]
      rw [hstep]
      refine ⟨fun b i => ?_, fun o ph i => ?_, fun f hf => ?_, fun k w p q hk hw => ?_,
        fun i a L => ?_, fun i a L => ?_⟩
      · rw [ih.cur, Nat.exists_lt_succ_right]
        simp [he]
      · rw [ih.rel, Nat.exists_lt_succ_right]
        simp [he]
      · obtain ⟨h1, h2⟩ := ih.fences f hf
        exact ⟨Nat.lt_succ_of_lt h1, h2⟩
      · rcases Nat.lt_succ_iff_lt_or_eq.1 hk with hk | rfl
        · exact ih.fences' k w p q hk hw
        · simp [he] at hw
      all_goals
        first | rw [ih.writes] | rw [ih.reads]
        constructor
        · rintro ⟨h1, h2⟩
          exact ⟨Nat.lt_succ_of_lt h1, h2⟩
        · rintro ⟨h1, h2⟩
          rcases Nat.lt_succ_iff_lt_or_eq.1 h1 with h1 | rfl
          · exact ⟨h1, h2⟩
          · simp [he] at h2
    | some e =>
      have hc := ih.testBit_clock he
      have hcur : (Scan.step tr s K).cur =
          e.agents.foldl (fun l b => addClock l b (s.clock K e)) s.cur := by
        simp only [Scan.step, he]
        cases e
        case access a => cases hw : a.kind.writes <;> simp [hw]
        all_goals rfl
      have hrel : ∀ o ph i, (clockOf (Scan.step tr s K).rel (o, ph)).testBit i = true ↔
          (clockOf s.rel (o, ph)).testBit i = true ∨
            ((∃ w, e = .rel w o ph) ∧ (s.clock K e).testBit i = true) := by
        intro o ph i
        simp only [Scan.step, he]
        cases e
        case rel w o' ph' =>
          dsimp only
          rw [clockOf_addClock]
          by_cases h : (o', ph') = (o, ph)
          · rw [ite_eq_left h]
            obtain ⟨rfl, rfl⟩ := Prod.mk.inj h
            rw [Nat.testBit_or, Bool.or_eq_true]
            exact or_congr_right ⟨fun h => ⟨⟨w, rfl⟩, h⟩, And.right⟩
          · rw [ite_eq_right h]
            refine ⟨.inl, ?_⟩
            rintro (h' | ⟨⟨w', hw'⟩, -⟩)
            · exact h'
            · cases hw'
              exact absurd rfl h
        case access a => cases hw : a.kind.writes <;> simp [hw]
        all_goals simp
      have hfen : ∀ f, f ∈ (Scan.step tr s K).fences ↔
          (∃ w p q, e = .fence w p q ∧ f = (K, p, q, s.clock K e)) ∨ f ∈ s.fences := by
        intro f
        simp only [Scan.step, he]
        cases e
        case fence w p q =>
          dsimp only
          rw [List.mem_cons]
          refine or_congr ⟨fun h => ⟨w, p, q, rfl, h⟩, ?_⟩ Iff.rfl
          rintro ⟨_, _, _, h, rfl⟩
          cases h
          rfl
        case access a => cases hw : a.kind.writes <;> simp [hw]
        all_goals simp
      have hwr : ∀ x, x ∈ (Scan.step tr s K).writes ↔
          (∃ a, e = .access a ∧ a.kind.writes = true ∧ x = (K, a, a.locs S)) ∨ x ∈ s.writes := by
        intro x
        simp only [Scan.step, he]
        cases e
        case access a => cases hw : a.kind.writes <;> simp [hw]
        all_goals simp
      have hrd : ∀ x, x ∈ (Scan.step tr s K).reads ↔
          (∃ a, e = .access a ∧ a.kind.writes = false ∧ x = (K, a, a.locs S)) ∨ x ∈ s.reads := by
        intro x
        simp only [Scan.step, he]
        cases e
        case access a => cases hw : a.kind.writes <;> simp [hw]
        all_goals simp
      refine ⟨fun b i => ?_, fun o ph i => ?_, fun f hf => ?_, fun k w p q hk hw => ?_,
        fun i a L => ?_, fun i a L => ?_⟩
      · rw [hcur, testBit_clockOf_foldl, ih.cur, hc, Nat.exists_lt_succ_right]
        simp [he]
      · rw [hrel, ih.rel, hc, Nat.exists_lt_succ_right]
        simp [he]
      · rcases (hfen f).1 hf with ⟨w, p, q, rfl, rfl⟩ | hf
        · exact ⟨Nat.lt_succ_self K, ⟨w, he⟩, hc⟩
        · obtain ⟨h1, h2⟩ := ih.fences f hf
          exact ⟨Nat.lt_succ_of_lt h1, h2⟩
      · rcases Nat.lt_succ_iff_lt_or_eq.1 hk with hk | rfl
        · obtain ⟨c, hcm⟩ := ih.fences' k w p q hk hw
          exact ⟨c, (hfen _).2 (.inr hcm)⟩
        · rw [he] at hw
          cases hw
          exact ⟨_, (hfen _).2 (.inl ⟨w, p, q, rfl, rfl⟩)⟩
      all_goals
        first | rw [hwr, ih.writes] | rw [hrd, ih.reads]
        constructor
        · rintro (⟨a', rfl, hw, h⟩ | ⟨h1, h2⟩)
          · cases h
            exact ⟨Nat.lt_succ_self K, he, hw, rfl⟩
          · exact ⟨Nat.lt_succ_of_lt h1, h2⟩
        · rintro ⟨h1, h2, hw, rfl⟩
          rcases Nat.lt_succ_iff_lt_or_eq.1 h1 with h1 | rfl
          · exact .inr ⟨h1, h2, hw, rfl⟩
          · rw [he] at h2
            cases h2
            exact .inl ⟨a, rfl, hw, rfl⟩

end Pass

/-- The clock of position `j` of trace `tr` has exactly `j` and the positions before `j` in
happens-before, on every machine, trace and position of the trace. -/
theorem testBit_clock {tr : List S.Event} {i j : Nat} (hj : j < tr.length) :
    (clock S tr j).testBit i = true ↔ i = j ∨ HB S tr i j := by
  have he : tr[j]? = some tr[j] := List.getElem?_eq_getElem hj
  simp only [clock, he]
  exact (scan_inv tr j).testBit_clock he i

/-- `hb` decides happens-before, on every machine, trace and pair of positions. -/
theorem hb_iff {tr : List S.Event} {i j : Nat} : hb S tr i j = true ↔ HB S tr i j := by
  rw [hb, Bool.and_eq_true, decide_eq_true_eq]
  constructor
  · rintro ⟨hij, h⟩
    by_cases hj : j < tr.length
    · exact ((testBit_clock S hj).1 h).resolve_left (Nat.ne_of_lt hij)
    · simp [clock, List.getElem?_eq_none (Nat.le_of_not_lt hj)] at h
  · intro h
    exact ⟨(HB.lt S h).1, (testBit_clock S (HB.lt S h).2).2 (.inr h)⟩

/-- `ordered` decides `Ordered`, on every machine, trace, pair of proxies and pair of positions. -/
theorem ordered_iff {tr : List S.Event} {p q : S.Proxy} {i j : Nat} :
    ordered S tr p q i j = true ↔ Ordered S tr p q i j := by
  simp only [ordered, Ordered, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, hb_iff,
    List.any_eq_true, isFence_iff, List.mem_range]
  refine or_congr Iff.rfl ⟨?_, ?_⟩
  · rintro ⟨k, -, ⟨⟨w, hw⟩, hik⟩, hkj⟩
    exact ⟨k, w, hw, hik, hkj⟩
  · rintro ⟨k, w, hw, hik, hkj⟩
    exact ⟨k, (HB.lt S hik).2, ⟨⟨w, hw⟩, hik⟩, hkj⟩

/-- `racePair` holds exactly of two conflicting accesses that `tr` does not order, on every
machine, trace and pair of positions. -/
theorem racePair_iff {tr : List S.Event} {i j : Nat} :
    racePair S tr i j = true ↔ ∃ a b, tr[i]? = some (.access a) ∧ tr[j]? = some (.access b) ∧
      Access.conflict S a b = true ∧ ¬ Ordered S tr a.proxy b.proxy i j := by
  simp only [← Event.bind_access?_eq_some, ← ordered_iff]
  unfold racePair
  cases tr[i]?.bind Event.access? <;> cases tr[j]?.bind Event.access? <;> simp

section Pass

variable {S}

/-- At an access `b` at position `K` of trace `tr`, after a state `s` of the pass that is right
for the positions below `K`, the check of an access `a` at a position `i < K` against `b`
(`Scan.races`, with their bytes), when one of them writes, holds exactly when `racePair` holds at
`i` and `K`, for every machine. -/
theorem Scan.Inv.races_iff {tr : List S.Event} {K i : Nat} {s : Scan S} {a b : S.Access}
    (hs : s.Inv tr K) (hb : tr[K]? = some (.access b)) (ha : tr[i]? = some (.access a))
    (hi : i < K) (hw : (a.kind.writes || b.kind.writes) = true) :
    s.races (s.clock K (.access b)) b (b.locs S) (i, a, a.locs S) = true ↔
      racePair S tr i K = true := by
  refine Bool.eq_iff_iff.1 ?_
  have hc := hs.testBit_clock hb
  have hord : ((decide (a.proxy = b.proxy) && (s.clock K (.access b)).testBit i) ||
      s.fences.any fun f => decide (f.2.1 = a.proxy) && decide (f.2.2.1 = b.proxy) &&
        decide (i < f.1) && f.2.2.2.testBit i && (s.clock K (.access b)).testBit f.1) =
      ordered S tr a.proxy b.proxy i K := by
    rw [Bool.eq_iff_iff, ordered_iff]
    simp only [Ordered, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, List.any_eq_true,
      hc]
    refine or_congr (and_congr_right fun _ =>
      ⟨fun h => h.resolve_left (Nat.ne_of_lt hi), .inr⟩) ⟨?_, ?_⟩
    · rintro ⟨f, hf, ⟨⟨⟨hp, hq⟩, hik⟩, hci⟩, hck⟩
      obtain ⟨hk, ⟨w, hw⟩, hcf⟩ := hs.fences f hf
      refine ⟨f.1, w, by rw [← hp, ← hq]; exact hw, ?_, hck.resolve_left (Nat.ne_of_lt hk)⟩
      exact ((hcf i).1 hci).resolve_left (Nat.ne_of_lt hik)
    · rintro ⟨k, w, hw, hik, hkK⟩
      obtain ⟨c, hcm⟩ := hs.fences' k w _ _ (HB.lt S hkK).1 hw
      obtain ⟨-, -, hcf⟩ := hs.fences _ hcm
      exact ⟨_, hcm, ⟨⟨⟨rfl, rfl⟩, (HB.lt S hik).1⟩, (hcf i).2 (.inr hik)⟩, .inr hkK⟩
  have hbytes :
      S.share a b (a.locs S) (b.locs S) = (a.locs S).any fun l => decide (l ∈ b.locs S) := by
    rw [Bool.eq_iff_iff, Sig.share_iff]
    simp
  simp only [Scan.races, racePair, ha, hb, Option.bind_some, Event.access?, hord, Access.conflict,
    hw, Bool.and_true, hbytes]
  cases ordered S tr a.proxy b.proxy i K <;> simp

/-- The pass over the first `K` positions of trace `tr` finds a race exactly when two of them,
`i < j < K`, hold accesses that `racePair` checks, for every machine, trace and `K`. -/
theorem racy_scan (tr : List S.Event) (K : Nat) :
    (scan S tr K).racy = true ↔ ∃ i j, i < j ∧ j < K ∧ racePair S tr i j = true := by
  induction K with
  | zero => simp [scan]
  | succ K ih =>
    have hs := scan_inv tr K
    rw [show scan S tr (K + 1) = Scan.step tr (scan S tr K) K by simp [scan, List.range_succ]]
    generalize scan S tr K = s at ih hs
    have hsplit : (∃ i j, i < j ∧ j < K + 1 ∧ racePair S tr i j = true) ↔
        (∃ i j, i < j ∧ j < K ∧ racePair S tr i j = true) ∨
          ∃ i < K, racePair S tr i K = true := by
      constructor
      · rintro ⟨i, j, hij, hj, h⟩
        rcases Nat.lt_succ_iff_lt_or_eq.1 hj with hj | rfl
        · exact .inl ⟨i, j, hij, hj, h⟩
        · exact .inr ⟨i, hij, h⟩
      · rintro (⟨i, j, hij, hj, h⟩ | ⟨i, hi, h⟩)
        · exact ⟨i, j, hij, Nat.lt_succ_of_lt hj, h⟩
        · exact ⟨i, K, hi, Nat.lt_succ_self K, h⟩
    rw [hsplit, ← ih]
    -- no pair ends at `K` unless `K` holds an access
    have hno : (∀ b, tr[K]? ≠ some (.access b)) →
        (s.racy = true ↔ s.racy = true ∨ ∃ i < K, racePair S tr i K = true) := by
      refine fun hK => ⟨.inl, fun h => h.elim id fun ⟨i, _, h⟩ => ?_⟩
      obtain ⟨a, b, -, hb, -⟩ := (racePair_iff S).1 h
      exact absurd hb (hK b)
    cases he : tr[K]? with
    | none =>
      simp only [Scan.step, he]
      exact hno fun b => by simp [he]
    | some e =>
      cases e
      case access b =>
        cases hbw : b.kind.writes
        · -- `b` does not write: a race needs an earlier write
          simp only [Scan.step, he, hbw, Bool.or_eq_true, List.any_eq_true]
          refine or_congr Iff.rfl ⟨?_, ?_⟩
          · rintro ⟨⟨i, a, L⟩, hm, h⟩
            obtain ⟨hi, ha, haw, rfl⟩ := (hs.writes i a L).1 hm
            exact ⟨i, hi, (hs.races_iff he ha hi (by simp [haw])).1 h⟩
          · rintro ⟨i, hi, h⟩
            obtain ⟨a, b', ha, hb', hc, -⟩ := (racePair_iff S).1 h
            rw [he] at hb'
            cases hb'
            have haw : a.kind.writes = true := by
              simp only [Access.conflict, Bool.and_eq_true, hbw, Bool.or_false] at hc
              exact hc.1.2
            exact ⟨(i, a, a.locs S), (hs.writes i a _).2 ⟨hi, ha, haw, rfl⟩,
              (hs.races_iff he ha hi (by simp [haw])).2 h⟩
        · -- `b` writes: every earlier access is checked
          simp only [Scan.step, he, hbw, Bool.or_eq_true, List.any_eq_true, or_assoc]
          refine or_congr Iff.rfl ⟨?_, ?_⟩
          · rintro (⟨⟨i, a, L⟩, hm, h⟩ | ⟨⟨i, a, L⟩, hm, h⟩)
            · obtain ⟨hi, ha, -, rfl⟩ := (hs.writes i a L).1 hm
              exact ⟨i, hi, (hs.races_iff he ha hi (by simp [hbw])).1 h⟩
            · obtain ⟨hi, ha, -, rfl⟩ := (hs.reads i a L).1 hm
              exact ⟨i, hi, (hs.races_iff he ha hi (by simp [hbw])).1 h⟩
          · rintro ⟨i, hi, h⟩
            obtain ⟨a, b', ha, hb', -⟩ := (racePair_iff S).1 h
            rw [he] at hb'
            cases hb'
            have hr := (hs.races_iff he ha hi (by simp [hbw])).2 h
            cases haw : a.kind.writes
            · exact .inr ⟨(i, a, a.locs S), (hs.reads i a _).2 ⟨hi, ha, haw, rfl⟩, hr⟩
            · exact .inl ⟨(i, a, a.locs S), (hs.writes i a _).2 ⟨hi, ha, haw, rfl⟩, hr⟩
      all_goals
        simp only [Scan.step, he]
        exact hno fun b => by simp [he]

end Pass

/-- The check of `Racy S tr`, for every machine: one pass over the trace (`scan`), which gives
each position its clock and checks each access against the writes before it and, when it writes,
against the other accesses before it too (`Scan.races`). -/
def racy (tr : List S.Event) : Bool :=
  (scan S tr tr.length).racy

/-- `racy` decides `Racy`, on every machine and trace. -/
theorem racy_iff {tr : List S.Event} : racy S tr = true ↔ Racy S tr := by
  rw [racy, racy_scan]
  simp only [Racy, racePair_iff]
  constructor
  · rintro ⟨i, j, hij, -, a, b, ha, hb, hc, ho⟩
    exact ⟨i, j, a, b, hij, ha, hb, hc, ho⟩
  · rintro ⟨i, j, a, b, hij, ha, hb, hc, ho⟩
    exact ⟨i, j, hij, (List.getElem?_eq_some_iff.1 hb).1, a, b, ha, hb, hc, ho⟩

section keySort

variable {α : Type} (key : α → Nat)

/-- The elements of `ys` with a key below `c` come before `c` in a list sorted by key, for every
key, number `c` and list `ys`: an element `t` that `List.takeWhile` keeps has a key below `c`. -/
theorem lt_of_mem_takeWhile {c : Nat} {t : α} :
    ∀ {ys : List α}, t ∈ ys.takeWhile (fun y => key y < c) → key t < c
  | [], h => by simp at h
  | y :: ys, h => by
    rw [List.takeWhile_cons] at h
    split at h
    · rename_i hc
      rcases List.mem_cons.1 h with rfl | h
      · simpa using hc
      · exact lt_of_mem_takeWhile h
    · simp at h

/-- The elements of a list sorted by key that `List.dropWhile` keeps past the keys below `c` have
keys at least `c`, for every key, number `c` and sorted list `ys`. -/
theorem le_of_mem_dropWhile {c : Nat} {d : α} :
    ∀ {ys : List α}, ys.Pairwise (fun a b => key a ≤ key b) →
      d ∈ ys.dropWhile (fun y => key y < c) → c ≤ key d
  | [], _, h => by simp at h
  | y :: ys, hy, h => by
    rw [List.pairwise_cons] at hy
    rw [List.dropWhile_cons] at h
    split at h
    · exact le_of_mem_dropWhile hy.2 h
    · rename_i hc
      simp only [decide_eq_true_eq, Nat.not_lt] at hc
      rcases List.mem_cons.1 h with rfl | h
      · exact hc
      · exact Nat.le_trans hc (hy.1 d h)

/-- The merge of two lists by key, after the reversed list `acc`, for every key and lists: each
element `x` of `xs` comes after the elements of `ys` with smaller keys that are left
(`List.takeWhile`), and the merge goes on with the rest of `ys` (`List.dropWhile`). It is
structural in `xs` and tail-recursive. -/
def keyMerge : List α → List α → List α → List α
  | acc, [], ys => acc.reverseAux ys
  | acc, x :: xs, ys =>
    keyMerge (x :: (ys.takeWhile fun y => key y < key x).reverseAux acc) xs
      (ys.dropWhile fun y => key y < key x)

/-- The merge by key holds the elements of `acc`, `xs` and `ys`, for every key and lists. -/
theorem mem_keyMerge {z : α} : ∀ (acc xs ys : List α),
    z ∈ keyMerge key acc xs ys ↔ z ∈ acc ∨ z ∈ xs ∨ z ∈ ys
  | acc, [], ys => by simp [keyMerge]
  | acc, x :: xs, ys => by
    have h : z ∈ ys ↔ z ∈ ys.takeWhile (fun y => key y < key x) ∨
        z ∈ ys.dropWhile (fun y => key y < key x) := by
      rw [← List.mem_append, List.takeWhile_append_dropWhile]
    rw [keyMerge, mem_keyMerge, h]
    simp only [List.reverseAux_eq, List.mem_cons, List.mem_append, List.mem_reverse]
    simp only [or_assoc, or_left_comm, or_comm]

/-- The merge by key of two sorted lists after a sorted `acc` whose keys are at most theirs is
sorted, for every key and lists. -/
theorem pairwise_keyMerge : ∀ (acc xs ys : List α),
    acc.reverse.Pairwise (fun a b => key a ≤ key b) →
    (∀ a ∈ acc, ∀ b, b ∈ xs ∨ b ∈ ys → key a ≤ key b) →
    xs.Pairwise (fun a b => key a ≤ key b) → ys.Pairwise (fun a b => key a ≤ key b) →
    (keyMerge key acc xs ys).Pairwise (fun a b => key a ≤ key b)
  | acc, [], ys, hacc, hle, _, hy => by
    rw [keyMerge, List.reverseAux_eq, List.pairwise_append]
    exact ⟨hacc, hy, fun a ha b hb => hle a (List.mem_reverse.1 ha) b (.inr hb)⟩
  | acc, x :: xs, ys, hacc, hle, hx, hy => by
    rw [List.pairwise_cons] at hx
    have e : ys.takeWhile (fun y => key y < key x) ++ ys.dropWhile (fun y => key y < key x) = ys :=
      List.takeWhile_append_dropWhile
    have hTD := hy
    rw [← e, List.pairwise_append] at hTD
    obtain ⟨hT, hD, hTD⟩ := hTD
    have hTys : ∀ t ∈ ys.takeWhile (fun y => key y < key x), t ∈ ys :=
      fun t ht => (List.takeWhile_prefix _).subset ht
    have hDys : ∀ d ∈ ys.dropWhile (fun y => key y < key x), d ∈ ys :=
      fun d hd => (List.dropWhile_suffix _).subset hd
    have hrev : (x :: (ys.takeWhile fun y => key y < key x).reverseAux acc).reverse =
        (acc.reverse ++ ys.takeWhile fun y => key y < key x) ++ [x] := by simp
    rw [keyMerge]
    refine pairwise_keyMerge _ xs _ ?_ ?_ hx.2 hD
    · rw [hrev]
      refine List.pairwise_append.2 ⟨List.pairwise_append.2 ⟨hacc, hT, fun a ha t ht =>
        hle a (List.mem_reverse.1 ha) t (.inr (hTys t ht))⟩, List.pairwise_singleton _ _, ?_⟩
      intro b hb y hy'
      rw [List.mem_singleton] at hy'
      subst hy'
      rcases List.mem_append.1 hb with hb | hb
      · exact hle b (List.mem_reverse.1 hb) _ (.inl (by simp))
      · exact Nat.le_of_lt (lt_of_mem_takeWhile key hb)
    · intro a ha b hb
      simp only [List.reverseAux_eq, List.mem_cons, List.mem_append, List.mem_reverse] at ha
      rcases ha with rfl | ha | ha
      · rcases hb with hb | hb
        · exact hx.1 b hb
        · exact le_of_mem_dropWhile key hy hb
      · rcases hb with hb | hb
        · exact Nat.le_of_lt (Nat.lt_of_lt_of_le (lt_of_mem_takeWhile key ha) (hx.1 b hb))
        · exact hTD a ha b hb
      · rcases hb with hb | hb
        · exact hle a ha b (.inl (List.mem_cons_of_mem _ hb))
        · exact hle a ha b (.inr (hDys b hb))

/-- One round of the merge sort by key, for every key and lists of lists: the lists of `ls`
merged two by two (`keyMerge`), onto `acc`. -/
def keyPairs : List (List α) → List (List α) → List (List α)
  | acc, a :: b :: ls => keyPairs (keyMerge key [] a b :: acc) ls
  | acc, [a] => a :: acc
  | acc, [] => acc

/-- A round of the merge sort by key keeps the elements, for every key and lists of lists. -/
theorem mem_keyPairs {z : α} : ∀ (acc ls : List (List α)),
    z ∈ (keyPairs key acc ls).flatten ↔ z ∈ acc.flatten ∨ z ∈ ls.flatten
  | acc, a :: b :: ls => by
    rw [keyPairs, mem_keyPairs]
    simp only [List.flatten_cons, List.mem_append, mem_keyMerge, List.not_mem_nil, false_or]
    simp only [or_assoc, or_left_comm]
  | acc, [a] => by simp [keyPairs, or_comm]
  | acc, [] => by simp [keyPairs]

/-- A round of the merge sort by key keeps the lists sorted, for every key and lists of
lists. -/
theorem pairwise_keyPairs : ∀ (acc ls : List (List α)),
    (∀ l ∈ acc, l.Pairwise (fun a b => key a ≤ key b)) →
    (∀ l ∈ ls, l.Pairwise (fun a b => key a ≤ key b)) →
    ∀ l ∈ keyPairs key acc ls, l.Pairwise (fun a b => key a ≤ key b)
  | acc, a :: b :: ls, hacc, hls => by
    rw [keyPairs]
    refine pairwise_keyPairs _ ls ?_ fun l hl => hls l (by simp [hl])
    intro l hl
    rcases List.mem_cons.1 hl with rfl | hl
    · exact pairwise_keyMerge key [] a b (by simp) (by simp) (hls a (by simp)) (hls b (by simp))
    · exact hacc l hl
  | acc, [a], hacc, hls => by
    intro l hl
    rcases List.mem_cons.1 hl with rfl | hl
    · exact hls l (by simp)
    · exact hacc l hl
  | acc, [], hacc, _ => hacc

/-- The merge sort by key, for every key and lists of lists: at most `n` rounds (`keyPairs`) until
one list is left; past them, the lists are merged one after the other. -/
def keySortGo : Nat → List (List α) → List α
  | 0, ls => ls.foldl (keyMerge key []) []
  | _ + 1, [] => []
  | _ + 1, [a] => a
  | n + 1, a :: b :: ls => keySortGo n (keyPairs key [] (a :: b :: ls))

/-- The merge sort by key keeps the elements, for every key, number of rounds and lists. -/
theorem mem_keySortGo {z : α} : ∀ (n : Nat) (ls : List (List α)),
    z ∈ keySortGo key n ls ↔ z ∈ ls.flatten
  | 0, ls => by
    have h : ∀ (ls : List (List α)) (r : List α),
        z ∈ ls.foldl (keyMerge key []) r ↔ z ∈ r ∨ z ∈ ls.flatten := by
      intro ls
      induction ls with
      | nil => simp
      | cons l ls ih =>
        intro r
        simp only [List.foldl_cons, ih, mem_keyMerge, List.flatten_cons, List.mem_append,
          List.not_mem_nil, false_or, or_assoc]
    show z ∈ ls.foldl (keyMerge key []) [] ↔ _
    simp [h]
  | _ + 1, [] => by simp [keySortGo]
  | _ + 1, [a] => by simp [keySortGo]
  | n + 1, a :: b :: ls => by
    rw [keySortGo, mem_keySortGo, mem_keyPairs]
    simp

/-- The merge sort by key of sorted lists is sorted, for every key, number of rounds and
lists. -/
theorem pairwise_keySortGo : ∀ (n : Nat) (ls : List (List α)),
    (∀ l ∈ ls, l.Pairwise (fun a b => key a ≤ key b)) →
    (keySortGo key n ls).Pairwise (fun a b => key a ≤ key b)
  | 0, ls, hls => by
    have h : ∀ (ls : List (List α)) (r : List α), r.Pairwise (fun a b => key a ≤ key b) →
        (∀ l ∈ ls, l.Pairwise (fun a b => key a ≤ key b)) →
        (ls.foldl (keyMerge key []) r).Pairwise (fun a b => key a ≤ key b) := by
      intro ls
      induction ls with
      | nil => intro r hr _; exact hr
      | cons l ls ih =>
        intro r hr hls
        exact ih _ (pairwise_keyMerge key [] r l (by simp) (by simp) hr (hls l (by simp)))
          fun l' hl' => hls l' (by simp [hl'])
    exact h ls [] List.Pairwise.nil hls
  | _ + 1, [], _ => List.Pairwise.nil
  | _ + 1, [a], hls => hls a (by simp)
  | n + 1, a :: b :: ls, hls => by
    rw [keySortGo]
    exact pairwise_keySortGo n _ (pairwise_keyPairs key [] _ (by simp) hls)

/-- The list `l` sorted by key, for every key and list: the merge sort (`keySortGo`) of its
elements as lists of one, with as many rounds as elements. -/
def keySort (l : List α) : List α :=
  keySortGo key l.length (l.map fun a => [a])

/-- The list sorted by key has the elements of the list, for every key and list. -/
@[simp] theorem mem_keySort {z : α} {l : List α} : z ∈ keySort key l ↔ z ∈ l := by
  rw [keySort, mem_keySortGo]
  simp only [List.mem_flatten, List.mem_map]
  constructor
  · rintro ⟨_, ⟨a, ha, rfl⟩, hz⟩
    exact List.mem_singleton.1 hz ▸ ha
  · exact fun h => ⟨[z], ⟨z, h, rfl⟩, List.mem_singleton_self z⟩

/-- The list sorted by key is sorted by key, for every key and list. -/
theorem pairwise_keySort (l : List α) : (keySort key l).Pairwise (fun a b => key a ≤ key b) :=
  pairwise_keySortGo key _ _ (by simp)

/-- No element of `xs` is an element of `ys`, for every key and lists sorted by key (checked
there by `disjointSorted_iff`): for each element `x` of `xs`, the elements of `ys` with smaller
keys are passed over (`List.dropWhile`), and `x` is compared only with the next ones of the same
key (`List.takeWhile`); the next element of `xs` goes on from there. -/
def disjointSorted [DecidableEq α] : List α → List α → Bool
  | [], _ => true
  | x :: xs, ys =>
    let ys' := ys.dropWhile fun y => key y < key x
    (ys'.takeWhile fun y => key y ≤ key x).all (· != x) && disjointSorted xs ys'

/-- Passing over the elements with keys below `c` keeps every element with a key at least `c`,
for every key, number `c` and list. -/
theorem mem_dropWhile_key {c : Nat} {z : α} (hz : c ≤ key z) :
    ∀ ys : List α, z ∈ ys.dropWhile (fun y => key y < c) ↔ z ∈ ys
  | [] => Iff.rfl
  | y :: ys => by
    rw [List.dropWhile_cons]
    split
    · rename_i h
      rw [mem_dropWhile_key hz ys, List.mem_cons]
      exact ⟨.inr, fun h' => h'.elim (fun e => by subst e; simp at h; omega) id⟩
    · exact Iff.rfl

/-- In a list sorted by key, the first elements with keys at most `c` hold every element of the
list with a key at most `c`, for every key, number `c` and sorted list. -/
theorem mem_takeWhile_key {c : Nat} {z : α} (hz : key z ≤ c) :
    ∀ {ys : List α}, ys.Pairwise (fun a b => key a ≤ key b) →
      (z ∈ ys.takeWhile (fun y => key y ≤ c) ↔ z ∈ ys)
  | [], _ => Iff.rfl
  | y :: ys, h => by
    rw [List.takeWhile_cons, List.pairwise_cons] at *
    split
    · rw [List.mem_cons, List.mem_cons, mem_takeWhile_key hz h.2]
    · rename_i hy
      simp only [decide_eq_true_eq, Nat.not_le] at hy
      simp only [List.not_mem_nil, List.mem_cons, false_iff, not_or]
      exact ⟨fun e => by subst e; omega, fun hm => by have := h.1 z hm; omega⟩

/-- `disjointSorted` checks that no element of the first list is in the second, for every key
and lists sorted by key. -/
theorem disjointSorted_iff [DecidableEq α] :
    ∀ {xs ys : List α}, xs.Pairwise (fun a b => key a ≤ key b) →
      ys.Pairwise (fun a b => key a ≤ key b) →
      (disjointSorted key xs ys = true ↔ ∀ x ∈ xs, x ∉ ys)
  | [], _, _, _ => by simp [disjointSorted]
  | x :: xs, ys, hx, hy => by
    rw [List.pairwise_cons] at hx
    have hy' : (ys.dropWhile fun y => key y < key x).Pairwise (fun a b => key a ≤ key b) :=
      hy.sublist (List.dropWhile_suffix _).sublist
    have hall : ∀ L : List α, (L.all fun y => y != x) = true ↔ x ∉ L := fun L => by
      simp only [List.all_eq_true, bne_iff_ne, ne_eq]
      exact ⟨fun h hm => h x hm rfl, fun h y hm e => h (e ▸ hm)⟩
    simp only [disjointSorted, Bool.and_eq_true]
    rw [hall, mem_takeWhile_key key (Nat.le_refl _) hy', mem_dropWhile_key key (Nat.le_refl _),
      disjointSorted_iff hx.2 hy', List.forall_mem_cons]
    exact and_congr Iff.rfl
      (forall₂_congr fun x' hx' => not_congr (mem_dropWhile_key key (hx.1 x' hx') ys))

end keySort

/-- The check of `kept` on the rest `tr` of a trace of machine `S`, for every machine, with the
bytes written `W` and the frozen bytes `F` of the events before it: it walks `tr` once, adding
the bytes (`Access.locs`) of each access that writes (`Kind.writes`) to `W` and those of each
access of kind `frozen` to `F`, then sorts the two lists by the machine's numbering of bytes
(`Sig.key`, `keySort`) and walks the two sorted lists once (`disjointSorted`). -/
def keptFrom : List S.Loc → List S.Loc → List S.Event → Bool
  | W, F, [] => disjointSorted S.key (keySort S.key W) (keySort S.key F)
  | W, F, e :: tr =>
    match e.access? with
    | some a => keptFrom (if a.kind.writes then a.locs S ++ W else W)
        (if a.kind = .frozen then a.locs S ++ F else F) tr
    | none => keptFrom W F tr

/-- Trace `tr` of machine `S` keeps its frozen reads, for every machine: no access of `tr` that
writes (`Kind.writes`) shares a byte (`Access.locs`) with an access of `tr` of kind `frozen`,
before or after it, by any agent. The check (`keptFrom`) walks `tr` once, collecting the bytes
written and the frozen bytes, sorts both by the machine's numbering of bytes (`Sig.key`,
`keySort`), then walks the two sorted lists once (`disjointSorted`), comparing a byte written
only with the frozen bytes of its number. With `B` bytes in the two lists it makes about
`B·log B` comparisons of numbers, and the comparisons of bytes with equal numbers: few when
different bytes have different numbers, all pairs when every byte has the same number. -/
def kept (tr : List S.Event) : Bool :=
  keptFrom S [] [] tr

/-- Trace `tr` of machine `S` keeps its frozen reads, as a proposition, for every machine: for
all accesses `w` and `a` of `tr`, at any positions and by any agents, if `w` writes
(`Kind.writes`) and `a` is of kind `frozen`, no byte of `a` (`Access.locs`) is a byte of `w`. -/
def Kept (tr : List S.Event) : Prop :=
  ∀ w a, Event.access w ∈ tr → Event.access a ∈ tr → w.kind.writes = true →
    a.kind = .frozen → ∀ l ∈ a.locs S, l ∉ w.locs S

/-- `keptFrom` decides, for every machine, bytes `W` and `F` and trace `tr`, that no byte written
(in `W`, or a byte of an access of `tr` that writes) is frozen (in `F`, or a byte of an access of
`tr` of kind `frozen`). -/
theorem keptFrom_iff {W F : List S.Loc} {tr : List S.Event} :
    keptFrom S W F tr = true ↔ ∀ l,
      (l ∈ W ∨ ∃ a, Event.access a ∈ tr ∧ a.kind.writes = true ∧ l ∈ a.locs S) →
      ¬ (l ∈ F ∨ ∃ a, Event.access a ∈ tr ∧ a.kind = .frozen ∧ l ∈ a.locs S) := by
  induction tr generalizing W F with
  | nil =>
    rw [keptFrom, disjointSorted_iff S.key (pairwise_keySort S.key _) (pairwise_keySort S.key _)]
    constructor
    · rintro h l (hl | ⟨_, ha, -⟩) hf
      · rcases hf with hf | ⟨_, hb, -⟩
        · exact h l ((mem_keySort S.key).2 hl) ((mem_keySort S.key).2 hf)
        · cases hb
      · cases ha
    · intro h x hx hy
      exact h x (.inl ((mem_keySort S.key).1 hx)) (.inl ((mem_keySort S.key).1 hy))
  | cons e tr ih =>
    cases e with
    | access a =>
      simp only [keptFrom, Event.access?, ih, List.mem_cons, Event.access.injEq]
      by_cases hf : a.kind = .frozen
      · have hw : (Kind.frozen : Kind S.Op).writes = false := rfl
        simp [hf, hw, or_and_right, exists_or, or_assoc, or_left_comm]
      · by_cases hw : a.kind.writes = true <;>
          simp [hw, hf, or_and_right, exists_or, or_assoc, or_left_comm]
    | _ => simp [keptFrom, Event.access?, ih]

/-- `kept` decides `Kept`, on every machine and trace. -/
theorem kept_iff {tr : List S.Event} : kept S tr = true ↔ Kept S tr := by
  rw [kept, keptFrom_iff]
  simp only [List.not_mem_nil, false_or]
  constructor
  · intro h w a hw ha hww haf l hla hlw
    exact h l ⟨w, hw, hww, hlw⟩ ⟨a, ha, haf, hla⟩
  · rintro h l ⟨w, hw, hww, hlw⟩ ⟨a, ha, haf, hla⟩
    exact h w a hw ha hww haf l hla hlw

end GPUProof
