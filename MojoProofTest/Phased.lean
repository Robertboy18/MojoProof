import MojoProof.Sem.Trace

/-!
# An instance of `racy_eq_false_of_phased`, and its negative twin

The trace `tr`: two threads of block of threads 0 and a shared block 0 of 2 bytes. In phase 0 thread
`k` writes byte `k`; then a barrier of block of threads 0; in phase 1 each thread reads both bytes.
Its accesses are by threads of the launch `launch2 1 1 2 1` (one block of two threads), so it has
the premises of `racy_iff` (`Trace.fits_of_check`). The discipline that tiles block 0 by thread in
phase 0 and leaves it untiled in phase 1 meets the premises of `racy_eq_false_of_phased`, so `tr`
has no race at `launch2 1 1 2 1`. No discipline for the whole run meets those of
`racy_eq_false_of_owned` (`not_owned`). Without the barrier the trace is racy (`twin`), so no phased
discipline meets the premises either. One trace, not a kernel.
-/

namespace MojoProofTest.Phased

open MojoProof.Sem

/-- An access by thread `k` of block of threads 0 to `len` bytes at `off` of block 0. -/
def acc (k off len : Nat) (write : Bool) : Access :=
  ⟨⟨k, 0⟩, ⟨0, off⟩, len, write, none, false⟩

/-- The writes of phase 0, newest first. -/
def writes : List Event := [.access (acc 1 1 1 true), .access (acc 0 0 1 true)]

/-- The reads of phase 1, newest first. -/
def reads : List Event := [.access (acc 1 0 2 false), .access (acc 0 0 2 false)]

/-- The trace, newest first. -/
def tr : List Event := reads ++ .barrier 0 :: writes

/-- Thread `k < 2` owns byte `k`; other threads have an empty tile at offset 0. -/
def tiles : Tiling Nat where
  off k := if k < 2 then k else 0
  len k := if k < 2 then 1 else 0
  ext := 2
  inb k := by split <;> omega
  disj i j h := by split <;> split <;> omega

/-- Block 0 is tiled by `tiles` in phase 0 and untiled after. -/
def T : Nat → Nat → Option (Tiling Nat)
  | 0, _ => some tiles
  | _, _ => none

/-- The accesses of `tr` with their phases: the two reads in phase 1, the two writes in phase 0. -/
theorem phases_tr : (phases tr).1 =
    [(acc 1 0 2 false, 1), (acc 0 0 2 false, 1), (acc 1 1 1 true, 0), (acc 0 0 1 true, 0)] := by
  decide +kernel

example : GPUProof.racy sig (tr.map (Event.toCore (launch2 1 1 2 1))).reverse = false := by
  obtain ⟨hU, hs⟩ := Trace.fits_of_check (L := launch2 1 1 2 1) (tr := tr) (by decide +kernel)
  refine racy_eq_false_of_phased (T := T) (own := fun _ => id) hU hs (fun x hx => ?_)
    (fun x hx y hy hne => ?_) fun _ _ _ _ _ _ _ ho => ho
  · rw [phases_tr] at hx
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
    rcases hx with rfl | rfl | rfl | rfl <;>
      exact ⟨fun h => by simp_all [T, acc], fun t ht => by revert t ht; simp [T, tiles, acc]⟩
  · rw [phases_tr] at hx hy
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hx hy
    rcases hx with rfl | rfl | rfl | rfl <;> rcases hy with rfl | rfl | rfl | rfl <;>
      exact absurd rfl hne

/-- No discipline for the whole run covers `tr`: thread 0's write of byte 0 needs a tiling of
block 0, and thread 1's read of both bytes puts its tile over byte 0, so the two threads share a
tile. -/
theorem not_owned {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    (h : ∀ a, Event.access a ∈ tr → Owned T own a)
    (hi : ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none → own a.who.thread = own e.who.thread → a.who.thread = e.who.thread) :
    False := by
  have mw : Event.access (acc 0 0 1 true) ∈ tr := by simp [tr, reads, writes]
  have mr : Event.access (acc 1 0 2 false) ∈ tr := by simp [tr, reads, writes]
  cases hT : T 0 with
  | none => simpa [acc] using (h _ mw).read hT
  | some t =>
    have w := (h _ mw).tile t hT
    have r := (h _ mr).tile t hT
    simp only [acc] at w r
    have ho : own 0 = own 1 := by
      by_contra hne
      rcases t.disj _ _ hne with d | d <;> omega
    exact absurd (hi _ _ mw mr rfl (by simp [acc, hT]) ho) (by simp [acc])

/-- The twin without the barrier is racy. -/
example :
    GPUProof.racy sig ((reads ++ writes).map (Event.toCore (launch2 1 1 2 1))).reverse = true := by
  decide +kernel

end MojoProofTest.Phased
