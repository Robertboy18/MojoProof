import MojoProof.Sem.Spec
import Std.Data.HashMap

/-!
# A fast race check

The core's `racy` at `sig` (GPUProof/Race.lean) checks each access of a trace against the
accesses before it, and the trace of the full `tiled_matmul` launch has about 600,000 accesses.
`fast` checks races with a hash map of the bytes touched:

* `phases` gives each access its phase, the number of barriers of its block of threads before it,
  in one pass. Two accesses of one block of threads have a barrier of that block between them
  exactly when their phases differ, so a race is a pair of accesses by different threads that
  conflict and are by different blocks of threads or in one phase (`clash`), in either order.
* `bucket` adds an access to the list of each byte it touches (block and offset); `fast` compares
  each write with the accesses of each byte the write touches. Its cost is the size of the map's
  lists plus, for each write, the accesses that share a byte with it.

Proved, for every trace:
* `races_iff`: an access races with the trace before it (`Access.races`) exactly when it clashes
  with an access of the trace's `phases`; `phases` lists exactly the accesses of the trace
  (`mem_phases`, `phases_mem`), each in a phase at most the final count (`phase_le`);
* `phasesF_eq`: `phasesF`, `phases` with the barrier counts as a function, gives the same
  accesses with the same phases and counts;
* `clash_comm`, `Access.overlaps_bytes`, and the lists of `bucket` hold each access of each byte
  it touches (`mem_insertAll`, `mem_buckets`).

From these MojoProof/Sem/RaceSig.lean proves, for every launch and trace with the premises of its
`racy_iff`, that the core's `racy` at `sig` holds exactly when two accesses of `phases` clash
(`racy_iff`, L9 of docs/proofs/schedule.md), and `fast_sound`: `fast tr = false` gives
`GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false`. The converse is not proved: `fast`
could report a race the core's `racy` does not; the tests compare the two on traces short enough
for the core's `racy`.

`phases` and `Access.bytes` are defined in MojoProof/Sem/SigDef.lean, with `sig`, which reaches
them.
-/

namespace MojoProof.Sem

open Std

/-- Accesses `x` and `y`, with their phases, race in either order: they are by different threads,
conflict, and are by different blocks of threads or in one phase. -/
def clash (x y : Access × Nat) : Bool :=
  x.1.who.thread != y.1.who.thread && x.1.conflict y.1 &&
    (x.1.who.cta != y.1.who.cta || x.2 == y.2)

/-- `m` with `x` added to the list of each byte it touches. -/
def bucket (m : HashMap (Nat × Int) (List (Access × Nat))) (x : Access × Nat) :
    HashMap (Nat × Int) (List (Access × Nat)) :=
  x.1.bytes.foldl (init := m) fun m b => m.insert b (x :: m.getD b [])

/-- Trace `tr` may have a data race: some write clashes with an access of a byte it touches.
`false` means it has none (`fast_sound`). -/
def fast (tr : List Event) : Bool :=
  let xs := (phases tr).1
  let m := xs.foldl bucket ∅
  xs.any fun x => x.1.write && x.1.bytes.any fun b => (m.getD b []).any (clash x)

/-- A barrier of block of threads `k` in front of a trace adds one to `k`'s barrier count and adds
no access. -/
theorem phases_barrier {k : Nat} {tr : List Event} :
    phases (.barrier k :: tr) =
      ((phases tr).1, (phases tr).2.insert k ((phases tr).2.getD k 0 + 1)) := rfl

/-- An access in front of a trace is listed first, with its phase: the number of barriers of its
block of threads in the rest of the trace. -/
theorem phases_access {a : Access} {tr : List Event} :
    phases (.access a :: tr) =
      ((a, (phases tr).2.getD a.who.cta 0) :: (phases tr).1, (phases tr).2) := rfl

/-- Each access `phases` lists is an access of the trace. -/
theorem mem_phases : ∀ {tr : List Event} {x : Access × Nat}, x ∈ (phases tr).1 →
    Event.access x.1 ∈ tr
  | [], _, h => by simp [phases] at h
  | .barrier _ :: _, _, h => by
    rw [phases_barrier] at h
    exact List.mem_cons_of_mem _ (mem_phases h)
  | .access _ :: _, _, h => by
    rw [phases_access] at h
    rcases List.mem_cons.1 h with rfl | h
    · exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (mem_phases h)

/-- Each access of the trace is listed by `phases`, with some phase. -/
theorem phases_mem : ∀ {tr : List Event} {a : Access}, Event.access a ∈ tr →
    ∃ n, (a, n) ∈ (phases tr).1
  | [], _, h => by simp at h
  | .barrier _ :: _, _, h => by
    rw [phases_barrier]
    exact phases_mem ((List.mem_cons.1 h).resolve_left (by simp))
  | .access _ :: _, _, h => by
    rw [phases_access]
    rcases List.mem_cons.1 h with h | h
    · cases h
      exact ⟨_, List.mem_cons_self⟩
    · obtain ⟨n, hn⟩ := phases_mem h
      exact ⟨n, List.mem_cons_of_mem _ hn⟩

/-- The phase of each access is at most the number of barriers of its block of threads in the
whole trace. -/
theorem phase_le : ∀ {tr : List Event} {y : Access × Nat}, y ∈ (phases tr).1 →
    y.2 ≤ (phases tr).2.getD y.1.who.cta 0
  | [], _, h => by simp [phases] at h
  | .barrier k :: _, y, h => by
    rw [phases_barrier] at h ⊢
    have := phase_le h
    rw [HashMap.getD_insert]
    by_cases hk : k = y.1.who.cta
    · subst hk
      simp only [beq_self_eq_true, ite_true]
      omega
    · simpa only [beq_iff_eq, hk, ite_false] using this
  | .access _ :: _, _, h => by
    rw [phases_access] at h ⊢
    rcases List.mem_cons.1 h with rfl | h
    · exact le_rfl
    · exact phase_le h

/-- `phases` with the barrier counts as a function instead of a hash map, for every trace: the
same accesses with the same phases (`phasesF_eq`). Proofs by induction on a trace read it without
the hash map's lemmas, and `decide +kernel` evaluates it (the kernel does not reduce the hash
map's lookups of a block of threads other than 0). -/
def phasesF (tr : List Event) : List (Access × Nat) × (Nat → Nat) :=
  tr.foldr (init := ([], fun _ => 0)) fun e p => match e with
    | .barrier k => (p.1, fun j => if k = j then p.2 j + 1 else p.2 j)
    | .access a => ((a, p.2 a.who.cta) :: p.1, p.2)

/-- **`phasesF` is `phases`**, for every trace: the same accesses with the same phases, and the
same barrier count of every block of threads. -/
theorem phasesF_eq : ∀ tr : List Event,
    (phases tr).1 = (phasesF tr).1 ∧ ∀ j, (phases tr).2.getD j 0 = (phasesF tr).2 j
  | [] => ⟨rfl, fun j => by simp [phases, phasesF]⟩
  | .barrier k :: tr => by
    obtain ⟨h1, h2⟩ := phasesF_eq tr
    refine ⟨by rw [phases_barrier]; exact h1, fun j => ?_⟩
    rw [phases_barrier, HashMap.getD_insert]
    show _ = if k = j then (phasesF tr).2 j + 1 else (phasesF tr).2 j
    by_cases hk : k = j
    · subst hk
      simp [h2]
    · simp [hk, h2]
  | .access a :: tr => by
    obtain ⟨h1, h2⟩ := phasesF_eq tr
    rw [phases_access]
    exact ⟨by rw [h1, h2]; rfl, h2⟩

/-- An access `a` races with trace `tr` exactly when it clashes with an access `y` of `tr`: `y`
is by another thread, conflicts with `a`, and is by another block of threads, or no barrier of
their block of threads completed after `tr` (`sync`) and `y` is in the phase of `a`. -/
theorem races_iff {a : Access} :
    ∀ {sync : Bool} {tr : List Event}, a.races sync tr = true ↔
      ∃ y ∈ (phases tr).1, y.1.who.thread ≠ a.who.thread ∧ a.conflict y.1 = true ∧
        (y.1.who.cta ≠ a.who.cta ∨ sync = false ∧ y.2 = (phases tr).2.getD a.who.cta 0)
  | _, [] => by simp [Access.races, phases]
  | sync, .barrier k :: tr => by
    simp only [Access.races]
    rw [races_iff, phases_barrier]
    refine exists_congr fun y => and_congr_right fun hy => and_congr_right fun _ =>
      and_congr_right fun _ => ?_
    by_cases hy' : y.1.who.cta = a.who.cta
    · have := phase_le hy
      rw [hy'] at this
      rw [HashMap.getD_insert]
      by_cases hk : k = a.who.cta
      · subst hk
        simp only [hy', ne_eq, not_true_eq_false, false_or, beq_self_eq_true, Bool.or_true,
          ite_true, Bool.true_eq_false, false_and, false_iff, not_and]
        intro _ h
        omega
      · simp [hk]
    · simp [hy']
  | sync, .access e :: tr => by
    simp only [Access.races, Bool.or_eq_true, Bool.and_eq_true, bne_iff_ne, ne_eq,
      Bool.not_eq_true']
    rw [races_iff, phases_access]
    simp only [List.mem_cons, exists_eq_or_imp]
    refine or_congr ?_ Iff.rfl
    by_cases he : e.who.cta = a.who.cta
    · simp [he]
      tauto
    · simp [he]

/-- `clash` is symmetric. -/
theorem clash_comm {x y : Access × Nat} : clash x y = clash y x := by
  rw [Bool.eq_iff_iff]
  simp only [clash, Access.conflict, Access.overlaps, Bool.and_eq_true, bne_iff_ne, ne_eq,
    beq_iff_eq, decide_eq_true_eq, Bool.or_eq_true, Bool.not_eq_true']
  grind

/-- Accesses that overlap touch a common byte. -/
theorem Access.overlaps_bytes {a e : Access} (h : a.overlaps e = true) :
    ∃ b ∈ a.bytes, b ∈ e.bytes := by
  simp only [overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨hb, ha⟩, he⟩, h₁⟩, h₂⟩ := h
  have mem {c : Access} {o : Int} (h₁ : c.ptr.off ≤ o) (h₂ : o < c.ptr.off + c.len) :
      (c.ptr.block, o) ∈ c.bytes :=
    List.mem_map.2 ⟨(o - c.ptr.off).toNat, List.mem_range.2 (by omega), by
      simp only [Prod.mk.injEq, true_and]; omega⟩
  rcases le_total a.ptr.off e.ptr.off with hl | hl
  · exact ⟨_, mem hl (by omega), by rw [hb]; exact mem le_rfl (by omega)⟩
  · exact ⟨_, mem le_rfl (by omega), by rw [hb]; exact mem hl (by omega)⟩

/-- Adding `x` to the list of each key of `bs` keeps the members of every list and puts `x` in the
lists of the keys of `bs`. -/
theorem mem_insertAll {x : Access × Nat} :
    ∀ {bs : List (Nat × Int)} {m : HashMap (Nat × Int) (List (Access × Nat))} {z b},
      z ∈ m.getD b [] ∨ z = x ∧ b ∈ bs →
        z ∈ (bs.foldl (init := m) fun m b => m.insert b (x :: m.getD b [])).getD b []
  | [], _, _, _, h => by simpa using h
  | c :: bs, m, z, b, h => by
    simp only [List.foldl_cons]
    apply mem_insertAll
    rw [HashMap.getD_insert]
    by_cases hc : c = b
    · subst hc
      simp only [beq_self_eq_true, ite_true, List.mem_cons]
      rcases h with h | ⟨rfl, _⟩
      · exact .inl (.inr h)
      · exact .inl (.inl rfl)
    · simp only [beq_iff_eq, hc, ite_false]
      rcases h with h | ⟨rfl, hb⟩
      · exact .inl h
      · exact .inr ⟨rfl, (List.mem_cons.1 hb).resolve_left (Ne.symm hc)⟩

/-- After `bucket`, the list of byte `b` holds each access of `xs` that touches it. -/
theorem mem_buckets :
    ∀ {xs : List (Access × Nat)} {m : HashMap (Nat × Int) (List (Access × Nat))} {z b},
      z ∈ m.getD b [] ∨ z ∈ xs ∧ b ∈ z.1.bytes → z ∈ (xs.foldl bucket m).getD b []
  | [], _, _, _, h => by simpa using h
  | x :: xs, m, z, b, h => by
    simp only [List.foldl_cons]
    apply mem_buckets
    rcases h with h | ⟨hz, hb⟩
    · exact .inl (mem_insertAll (.inl h))
    · rcases List.mem_cons.1 hz with rfl | hz
      · exact .inl (mem_insertAll (.inr ⟨rfl, hb⟩))
      · exact .inr ⟨hz, hb⟩

end MojoProof.Sem
