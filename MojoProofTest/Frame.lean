import MojoProof.Sem.Frame
import MojoProofTest.Writes

/-!
# Instances and twins of L2 (`step_agree`) and of `Mem.Changes.agree`

In the context `Pending.ctx0` (thread 0). `mem x y bs` has block 1 of 8 live bytes of every
thread, byte 0 `x`, byte 4 `y` and the others 0, the blocks `bs`, and `next = 2`. The hypothesis
at a read: for a thread at `%1 = load i32, ptr %0` with a pointer to block 1 in register 0
(`loader`), `mem 7 0 []` and `mem 7 1 [(5, _)]`, which differ at byte 4 of block 1, which the load
does not read, and at block 5, which the thread does not name, agree at every number but 5 at the
load's pending read of bytes 0 to 3 (`agree`). The instance: `mem 7 0 []` and `mem 8 1 [(5, _)]`
agree at every number but 5 at the pending write of a thread at `store i32 7, ptr %0` with a
pointer to block 1 (`storerAt 1`); its step on the first continues, and by `step_agree` its step on
the second continues with the same thread and the same changes (`store`). The twin: `storerAt 5`
holds a pointer to block 5, outside `S`; on `mem 7 0 [(5, _)]` and `mem 7 0 []`, which agree at
every other number, its step continues on the first and faults on the second (`names_twin`).
The disjointness argument: `Closed.mem1` and the memory after a store of bytes 0 to 3 of its block
1 (`stored`) agree for thread 0 at null and block 1 at a read of bytes 4 to 7 (`changes_agree`, by
`Mem.Changes.agree` and `step_changes`); the twin: at a read of bytes 0 to 3 they do not, byte 0
being undefined in the first and 7 in the second (`changes_twin`). The load itself: `ld`'s load
from `mem 7 0 []` gives the `i32` 7, by the integer codec and
`Mem.load_of_check`, and by `Mem.load_agree` and `agree` the load from `mem 7 1 [(5, _)]` gives 7
too (`load`); the twin: `mem 7 0 []` and `mem 8 0 []` agree at a read of bytes 4 to 7 but not at
the load's read of bytes 0 to 3, and the loads give 7 and 8 (`load_twin`), so the agreement at the
bytes read is needed. `decode_eval`: `Layout.decode` recurses structurally, so the kernel
evaluates it (`rfl`) under the default layout: 8 zero bytes are the structure
`{ ptr, { { {} }, { {} } } }` that `vector_addition`'s block `%4` loads (with the null pointer) and
the `<2 x float>` of two zero words, and 8 bytes 1 are no pointer (`none`). Statements about
these threads, memories and bytes, not about every thread.
-/

namespace MojoProofTest.Frame

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending

/-- `%1 = load i32, ptr %0`. -/
def ld : Stmt := { res := some 1, inst := .load false (.int 32) ⟨.ptr 0, .loc 0⟩ none }

/-- A thread at `ld` with a pointer to block 1 in register 0. -/
def loader : Thread := ⟨[{ frameAt 1 with fn := kernel #[ld] }], 0⟩

/-- A block of 8 live bytes of every thread: byte 0 is `x`, byte 4 is `y`, the others are 0. -/
def blkXY (x y : BitVec 8) : MojoProof.Sem.Block :=
  { blk 8 true with
    bytes := fun i => if i = 0 then .byte x else if i = 4 then .byte y else .byte 0 }

/-- The memory of block 1 `blkXY x y` and the blocks `bs`, with `next = 2`. -/
def mem (x y : BitVec 8) (bs : List (Nat × MojoProof.Sem.Block)) : Mem :=
  { memOf ((1, blkXY x y) :: bs) with next := 2 }

/-- `mem x y []` and `mem x' y' bs`, where `bs` has blocks at 5 only, agree at every number but 5
at the reads of `P` if their blocks 1 have the same bytes where `P` reads. -/
theorem agree_of {x y x' y' : BitVec 8} {bs : List (Nat × MojoProof.Sem.Block)} {P : List Event}
    (h5 : ∀ b, b ≠ 5 → bs.lookup b = none)
    (hb : ∀ i, Reads P 1 i → (blkXY x y).bytes i = (blkXY x' y').bytes i) :
    (mem x y []).Agree ctx0.who (· ≠ 5) P (mem x' y' bs) := by
  refine ⟨rfl, fun b h5b => ?_⟩
  by_cases h1 : b = 1
  · subst h1
    exact .some ⟨rfl, rfl, rfl, fun _ => rfl, fun _ => hb⟩
  · simp only [mem, memOf, List.lookup, beq_eq_false_iff_ne.2 h1, h5 b h5b]
    exact .none

/-- The blocks `[(5, blk 4 true)]` are at 5 only. -/
theorem lookup5 (b : Nat) (hb : b ≠ 5) : [(5, blk 4 true)].lookup b = none := by
  simp only [List.lookup, beq_eq_false_iff_ne.2 hb]

/-- A read by thread 0 of the 4 bytes of block 1 from offset `o`. -/
def read1 (o : Int) : Event := .access ⟨⟨0, 0⟩, ⟨1, o⟩, 4, false, none, false⟩

/-- The pending access of `loader` on `mem 7 0 []` is one read by thread 0 of bytes 0 to 3 of
block 1. -/
theorem pending_ld : loader.pending ctx0 (mem 7 0 []) = [read1 0] := rfl

/-- The memories of the instance agree at every number but 5 at the load's pending read, of bytes
0 to 3 of block 1. -/
theorem agree :
    (mem 7 0 []).Agree ctx0.who (· ≠ 5) (loader.pending ctx0 (mem 7 0 []))
      (mem 7 1 [(5, blk 4 true)]) :=
  agree_of lookup5 fun i ⟨a, ha, _, _, _, h4⟩ => by
    rw [pending_ld, read1, List.mem_singleton] at ha
    cases ha
    have : i ≠ 4 := by
      simp only at h4
      omega
    simp [blkXY, this]

/-- `ld`'s load from `mem x y bs`, of an `i32` at offset 0 of block 1, gives `v` if the check
admits it and bytes 0 to 3 are the little-endian bytes of `v`. -/
theorem load_of {x y : BitVec 8} {bs : List (Nat × MojoProof.Sem.Block)} {v : BitVec 32}
    (hc : (mem x y bs).check ctx0.prog.layout ctx0.who 0 ⟨1, 0⟩ 4 (some 4) = .ok (blkXY x y, 0))
    (hr : (blkXY x y).read 0 4 = leBytes 4 v.toNat) :
    (mem x y bs).load ctx0.prog.layout ctx0.who 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 v) :=
  Mem.load_of_check hc (by
    show ctx0.prog.layout.decode (.int 32) ((blkXY x y).read 0 4) = _
    rw [hr]
    simp only [Layout.decode]
    exact Layout.scalarOf_leBytes v (by omega))

/-- L2 at the load: from `mem 7 0 []` it gives 7, and so, by `Mem.load_agree`, from
`mem 7 1 [(5, _)]`, which differs at byte 4 and block 5, neither of which it reads. -/
theorem load :
    (mem 7 0 []).load ctx0.prog.layout ctx0.who 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 7) ∧
      (mem 7 1 [(5, blk 4 true)]).load ctx0.prog.layout ctx0.who 0 (.int 32) ⟨1, 0⟩ (some 4) =
        .ok (.bits 32 7) :=
  have h := load_of (x := 7) (y := 0) (bs := []) rfl rfl
  ⟨h, Mem.load_agree agree (by decide) (by rw [pending_ld]; exact List.mem_singleton_self _) h⟩

/-- The twin: `mem 7 0 []` and `mem 8 0 []` differ at byte 0 of block 1 only. They agree at a read
of bytes 4 to 7 but not at the load's read of bytes 0 to 3, and the loads give 7 and 8. -/
theorem load_twin :
    (mem 7 0 []).Agree ctx0.who (· ≠ 5) [read1 4] (mem 8 0 []) ∧
      ¬ (mem 7 0 []).Agree ctx0.who (· ≠ 5) [read1 0] (mem 8 0 []) ∧
      (mem 7 0 []).load ctx0.prog.layout ctx0.who 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 7) ∧
      (mem 8 0 []).load ctx0.prog.layout ctx0.who 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 8) := by
  refine ⟨agree_of (fun _ _ => rfl) fun i ⟨a, ha, _, _, h4, _⟩ => ?_, fun h => ?_, load.1,
    load_of rfl rfl⟩
  · rw [read1, List.mem_singleton] at ha
    cases ha
    have : i ≠ 0 := by
      simp only at h4
      omega
    simp [blkXY, this]
  · obtain ⟨y, hy, hxy⟩ := h.block (b := 1) (by decide) (x := blkXY 7 0) rfl
    cases hy
    have := hxy.bytes rfl 0 ⟨_, List.mem_singleton_self _, rfl, rfl, by decide, by decide⟩
    simp [blkXY] at this

/-- A thread at `store i32 7, ptr %0` with a pointer to block `b` in register 0. -/
def storerAt (b : Nat) : Thread := ⟨[{ frameAt b with fn := kernel #[Writes.store7] }], 0⟩

/-- L2 on a store: `mem 7 0 []` and `mem 8 1 [(5, _)]` differ at bytes 0 and 4 of block 1 and at
block 5, and agree at every number but 5 at the store's pending access, a write; the step of
`storerAt 1` on the first continues, and by `step_agree` the step on the second continues with the
same thread and the same changes. -/
theorem store :
    ∃ t' ops, step ctx0 (storerAt 1) (mem 7 0 []) = .ok (.next t' ((mem 7 0 []).run ops)) ∧
      step ctx0 (storerAt 1) (mem 8 1 [(5, blk 4 true)]) =
        .ok (.next t' ((mem 8 1 [(5, blk 4 true)]).run ops)) := by
  obtain ⟨t', m', h⟩ : ∃ t' m', step ctx0 (storerAt 1) (mem 7 0 []) = .ok (.next t' m') :=
    ⟨_, _, rfl⟩
  have ha : (mem 7 0 []).Agree ctx0.who (· ≠ 5) ((storerAt 1).pending ctx0 (mem 7 0 []))
      (mem 8 1 [(5, blk 4 true)]) :=
    agree_of lookup5 fun i ⟨a, ha, hw, _⟩ => by
        have e : (storerAt 1).pending ctx0 (mem 7 0 []) =
            [.access ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩] := rfl
        rw [e, List.mem_singleton] at ha
        cases ha
        cases hw
  obtain ⟨ops, -, e, h₂⟩ := step_agree (fun f hf => by
    cases hf
    exact names5 ctx0 (fun _ _ h => by cases h) _ _) (by decide) ha h
  simp only [Step.withMem, Step.next.injEq, true_and] at e
  subst e
  exact ⟨t', ops, h, h₂⟩

/-- The twin: `storerAt 5` holds a pointer to block 5, outside `· ≠ 5`. `mem 7 0 [(5, _)]` and
`mem 7 0 []` agree at every number but 5 at its pending access, but its step continues on the first
and faults on the second, which has no block 5: `step_agree` needs `S` to have the numbers the
scope names. -/
theorem names_twin :
    (mem 7 0 [(5, blk 4 true)]).Agree ctx0.who (· ≠ 5)
        ((storerAt 5).pending ctx0 (mem 7 0 [(5, blk 4 true)])) (mem 7 0 []) ∧
      (∃ t' m', step ctx0 (storerAt 5) (mem 7 0 [(5, blk 4 true)]) = .ok (.next t' m')) ∧
      ∃ x, step ctx0 (storerAt 5) (mem 7 0 []) = .error x :=
  ⟨(agree_of lookup5 fun _ _ => rfl).symm,
    ⟨_, _, rfl⟩, _, rfl⟩

/-- The memory after the step of `Writes.storer` (`store i32 7` through a pointer to block 1) on
`Closed.mem1` (block 1 of 8 undefined bytes of every thread, `next = 2`). -/
def stored : Mem :=
  match step ctx0 Writes.storer Closed.mem1 with
  | .ok (.next _ m) => m
  | _ => {}

/-- The step of `Writes.storer` on `Closed.mem1` succeeds with memory `stored`. -/
theorem stored_eq : ∃ t', step ctx0 Writes.storer Closed.mem1 = .ok (.next t' stored) := ⟨_, rfl⟩

/-- The disjointness argument on the store: `Closed.mem1` and `stored` agree for thread 0 at null
and block 1 at a read of bytes 4 to 7, which the store, of bytes 0 to 3, does not write
(`Mem.Changes.agree`, with `step_changes`). -/
theorem changes_agree : Closed.mem1.Agree ctx0.who (· < 2) [read1 4] stored := by
  obtain ⟨t', h⟩ := stored_eq
  have hc := step_changes (L := fun _ => False) (N := (· = Closed.mem1.fresh 0 0))
    (r := .next t' stored) (fun b x hx ho => ?_) (by simp [Writes.storer]) rfl h
  · refine hc.agree (fun b hb hN => ?_) (fun _ _ _ h => h.elim)
      fun d ht b x i a _ _ _ ⟨a', ha', _, _, h4, _⟩ ha hw => ?_
    · subst hN
      exact absurd hb (by decide)
    · have e : stored.trace = [.access ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩] := rfl
      rw [e, show Closed.mem1.trace = [] from rfl, List.append_nil] at ht
      subst ht
      rw [List.mem_singleton] at ha ha'
      cases ha
      cases ha'
      obtain ⟨-, -, -, h3⟩ := hw
      simp only at h3 h4
      omega
  · rw [Writes.mem1_owner b x hx] at ho
    cases ho

/-- The twin: at a read of bytes 0 to 3, which the store writes, `Closed.mem1` and `stored` do not
agree: byte 0 of block 1 is undefined in the first and 7 in the second. -/
theorem changes_twin : ¬ Closed.mem1.Agree ctx0.who (· < 2) [read1 0] stored := by
  intro h
  obtain ⟨y, hy, hxy⟩ := h.block (b := 1) (by decide) (x := blk 8 true) rfl
  have e : (stored.blocks 1).map (·.bytes 0) = some (.byte 7) := rfl
  rw [hy] at e
  have := hxy.bytes rfl 0 ⟨_, List.mem_singleton_self _, rfl, rfl, by decide, by decide⟩
  simp only [Option.map_some, Option.some.injEq] at e
  rw [e] at this
  cases this

/-- **`Layout.decode` evaluates.** It recurses structurally on the type, so the kernel
evaluates it by `rfl`: under the default layout, 8 zero bytes decode as the structure
`{ ptr, { { {} }, { {} } } }` with the null pointer and as the `<2 x float>` of two zero words, and
8 bytes 1 decode as no pointer. -/
theorem decode_eval :
    ({} : Layout).decode (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]])
        (List.replicate 8 (.byte 0)) =
      some (.agg [.ptr ⟨0, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]) ∧
    ({} : Layout).decode (.vec 2 (.fp .float)) (List.replicate 8 (.byte 0)) =
      some (.vec [.bits 32 0, .bits 32 0]) ∧
    ({} : Layout).decode (.ptr 0) (List.replicate 8 (.byte 1)) = none :=
  ⟨rfl, rfl, rfl⟩

end MojoProofTest.Frame
