import MojoProof.Sym.OblPieces

/-!
# A thread's slots, and the blocks other threads keep

A thread's `alloca` blocks as slots (`Mem.slot`: a writable block of space 0 that the thread
owns, big and aligned enough) and what the operations of a run do to them, for every memory:

* `Mem.setLive_blocks_ne`, `Mem.setLive_blocks_self`, `Mem.store_blocks_self`: the blocks a
  liveness change and a store leave;
* `Mem.Buffer.ne_slot`: a buffer (space 1, `Mem.Buffer`) is not a slot (space 0);
* `Mem.slot_setLive`, `Mem.slot_store`, `Mem.liveAt_*`: liveness changes and stores keep
  slots, and liveness as set; `Mem.slot_check`, `Mem.slot_store_ok`,
  `Mem.slot_bufferIn`, `Mem.slot_fits`, `Mem.slot_addr`: a live slot's accesses succeed;
* `Mem.fresh_ne`, `Mem.fresh_of_next`: `alloca` numbers of one thread at different steps differ,
  and depend on a memory only through `next`.

Then the frame of the other threads (`Mem.SameOff S`: the same blocks outside a set `S` of
numbers), for every memory: an allocation at a number changes only that number
(`Mem.SameOff.alloc`, as `Mem.setLive_blocks_ne` and `Mem.store_blocks` say of a liveness change
and a store); outside `S` a memory keeps slots and the premise of `Mem.Buffer.of_block`,
`Mem.Fits.of_block` and `Mem.Holds.of_block` (`.slot`, `.block`); and the `alloca` numbers of a
set of threads (`Mem.FreshOf`) leave out every other thread's numbers (`Mem.not_freshOf`, by
`Mem.fresh_inj`) and the numbers below `next` (`Mem.not_freshOf_lt`). So another thread's
`alloca`s, slot stores and liveness changes keep a thread's slots and the launch's buffers.

The lemmas need `Mem.BufferIn` and `addr_buffer` (MojoProof/Sym/OblLemmas.lean),
`Mem.addr_own`, `Mem.store_of_check` (MojoProof/Sym/Loop.lean) and `Mem.alloc_num_ne`
(MojoProof/Sym/OblPieces.lean), which `Mem.Buffer`'s module MojoProof/Sem/Precond.lean does not
import, so they are a module of their own.
-/

namespace MojoProof.Sem
open MojoProof.LLVM

/-- For every memory, blocks `b ≠ a` and liveness: setting `a`'s liveness leaves block `b`. -/
theorem Mem.setLive_blocks_ne (m : Mem) {a b : Nat} (l : Bool) (h : b ≠ a) :
    (m.setLive a l).blocks b = m.blocks b := by
  unfold Mem.setLive
  split
  · simp [Mem.set, h]
  · rfl

/-- For every memory, block `a` and liveness `l`: setting `a`'s liveness sets its `live` field to
`l`, and its bytes to `undef` when `l` is true. -/
theorem Mem.setLive_blocks_self (m : Mem) (a : Nat) (l : Bool) :
    (m.setLive a l).blocks a =
      (m.blocks a).map fun B =>
        { B with live := l, bytes := if l then fun _ => .undef else B.bytes } := by
  unfold Mem.setLive
  split
  · rename_i B hB
    simp [Mem.set, hB]
  · rename_i hB
    simp [hB]

/-- For every layout, memories, thread, space, type, value, pointer, alignment and
read-modify-write: a store that succeeds finds a block at the pointer's block and leaves it with
bytes put at the pointer's offset. -/
theorem Mem.store_blocks_self {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m') :
    ∃ B bs, m.blocks p.block = some B ∧ m'.blocks p.block = some (B.put p.off.toNat bs) := by
  obtain ⟨blk, bs, hc, -, -, rfl⟩ := Mem.store_inv h
  exact ⟨blk, bs, (Mem.check_inv hc).1, by simp [Mem.log, Mem.set]⟩

/-- Block `b` of `m` is a writable block of space 0 owned by thread `who`, of at least `n` bytes,
at an address `a` divides with `n` bytes below `2 ^ 64`. -/
def Mem.slot (m : Mem) (who b n a : Nat) : Bool :=
  match m.blocks b with
  | some B => B.space == 0 && !B.readOnly && B.owner == .thread who && decide (n ≤ B.size) &&
      B.addr % a == 0 && B.gaddr % a == 0 && decide (B.addr + n ≤ 2 ^ 64)
  | none => false

/-- Block `b` of `m` exists and is live. -/
def Mem.liveAt (m : Mem) (b : Nat) : Bool := (m.blocks b).any (·.live)

/-- **A buffer is not a slot**: for every memory `m`, block numbers `q`, `b`, sizes, alignments,
writability and thread `who`, a buffer `q` of `m` (space 1, `Mem.Buffer`) is not a slot `b` of
thread `who` in `m` (space 0, `Mem.slot`). -/
theorem Mem.Buffer.ne_slot {m : Mem} {q size al who b n a : Nat} {w : Bool}
    (hq : m.Buffer q size al w) (hb : m.slot who b n a = true) : q ≠ b := by
  rintro rfl
  obtain ⟨B, hB, hs, -⟩ := hq
  unfold Mem.slot at hb
  rw [hB] at hb
  simp [hs] at hb

/-- For every memory, block, liveness and slot parameters: setting a block's liveness keeps
`Mem.slot`. -/
theorem Mem.slot_setLive (m : Mem) (a : Nat) (l : Bool) (who b n al : Nat) :
    (m.setLive a l).slot who b n al = m.slot who b n al := by
  by_cases h : b = a
  · subst h
    unfold Mem.slot
    rw [Mem.setLive_blocks_self]
    cases m.blocks b <;> rfl
  · unfold Mem.slot
    rw [Mem.setLive_blocks_ne _ _ h]

/-- For every layout, memories, thread and value: a store that succeeds keeps `Mem.slot` of every
block. -/
theorem Mem.slot_store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    (who b n al' : Nat) : m'.slot who b n al' = m.slot who b n al' := by
  by_cases hb : p.block = b
  · subst hb
    obtain ⟨B, bs, h1, h2⟩ := Mem.store_blocks_self h
    unfold Mem.slot
    rw [h1, h2]
    rfl
  · unfold Mem.slot
    rw [Mem.store_blocks h hb]

/-- For every memory, blocks `b ≠ a` and liveness: setting `a`'s liveness keeps `Mem.liveAt b`. -/
theorem Mem.liveAt_setLive_ne (m : Mem) {a b : Nat} (l : Bool) (h : b ≠ a) :
    (m.setLive a l).liveAt b = m.liveAt b := by
  unfold Mem.liveAt
  rw [Mem.setLive_blocks_ne _ _ h]

/-- For every memory and slot `b`: setting `b`'s liveness to `l` makes `Mem.liveAt b = l`. -/
theorem Mem.liveAt_setLive_self {m : Mem} {who b n al : Nat} (h : m.slot who b n al = true)
    (l : Bool) : (m.setLive b l).liveAt b = l := by
  unfold Mem.slot at h
  unfold Mem.liveAt
  rw [Mem.setLive_blocks_self]
  split at h
  · rename_i B hB
    simp [hB]
  · cases h

/-- For every layout, memories, thread and value: a store that succeeds keeps `Mem.liveAt` of
every block. -/
theorem Mem.liveAt_store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    (b : Nat) : m'.liveAt b = m.liveAt b := by
  by_cases hb : p.block = b
  · subst hb
    obtain ⟨B, bs, h1, h2⟩ := Mem.store_blocks_self h
    unfold Mem.liveAt
    rw [h1, h2]
    rfl
  · unfold Mem.liveAt
    rw [Mem.store_blocks h hb]

/-- For every memory: a slot of thread `who` is owned by `who` at every offset. -/
theorem Mem.slot_owner {who : Nat} {m : Mem} {b n a : Nat} (h : m.slot who b n a = true)
    (o : Int) : ((m.block ⟨b, o⟩).any fun B => B.owner == .thread who) = true := by
  unfold Mem.slot at h
  unfold Mem.block
  split at h
  · rename_i B hB
    simp only [Bool.and_eq_true, beq_iff_eq] at h
    obtain ⟨⟨⟨⟨⟨⟨-, -⟩, hown⟩, -⟩, -⟩, -⟩, -⟩ := h
    simp [hB, hown]
  · cases h

/-- For every layout with 64-bit pointers in space 0, thread `w` and memory: on a live slot of
`w`'s thread of `n` bytes aligned to `a` (not block 0), a check of `n' > 0` bytes at offset `o`
with `o + n' ≤ n` and an alignment `a'` dividing `a` and `o` succeeds with the slot's block, which
is writable. -/
theorem Mem.slot_check {l : Layout} {w : Who} {m : Mem} {b n a o n' a' : Nat}
    (h : m.slot w.thread b n a = true) (hl : m.liveAt b = true) (hw : (l.ptr 0).1 = 64)
    (hb : b ≠ 0) (hn : o + n' ≤ n) (hn' : 0 < n') (ha : a' ∣ a) (ho : a' ∣ o) :
    ∃ B, m.blocks b = some B ∧ B.readOnly = false ∧
      m.check l w 0 ⟨b, o⟩ n' (some a') = .ok (B, o) := by
  unfold Mem.slot at h
  unfold Mem.liveAt at hl
  split at h
  · rename_i B hB
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq, Bool.not_eq_true'] at h
    obtain ⟨⟨⟨⟨⟨⟨hs, hr⟩, hown⟩, hsz⟩, hal⟩, -⟩, hf⟩ := h
    simp only [hB, Option.any_some] at hl
    refine ⟨B, hB, hr, ?_⟩
    have had := Mem.addr_own (l := l) (m := m) (p := ⟨b, (o : Int)⟩) hB hb
    rw [hs] at had
    simp only [Mem.check, Mem.block, hB, hl, hown, Owner.admits, had, hw]
    have h1 : ((B.addr : Int) + (o : Int)) % 2 ^ 64 = ((B.addr + o : Nat) : Int) := by
      rw [Int.emod_eq_of_lt (by omega) (by omega)]; push_cast; rfl
    rw [h1]
    simp only [Int.toNat_natCast]
    have h2 : (B.addr + o) % a' = 0 := Nat.mod_eq_zero_of_dvd
      (Nat.dvd_add (Nat.dvd_trans ha (Nat.dvd_of_mod_eq_zero hal)) ho)
    simp [h2, pure, Except.pure, bind, Except.bind]
    omega
  · cases h

/-- A store of a value that encodes, at offset `o` of a slot. -/
theorem Mem.slot_store_ok {l : Layout} {w : Who} {m : Mem} {b n a o a' : Nat} {t : Ty} {v : Val}
    {bs : List MemByte} (h : m.slot w.thread b n a = true) (hl : m.liveAt b = true)
    (hw : (l.ptr 0).1 = 64) (hb : b ≠ 0) (hn : o + l.stored t ≤ n) (hn' : 0 < l.stored t)
    (ha : a' ∣ a) (ho : a' ∣ o) (he : l.encode t v = some bs) :
    ∃ m', m.store l w 0 t v ⟨b, o⟩ (some a') = .ok m' := by
  obtain ⟨B, -, hr, hc⟩ := Mem.slot_check h hl hw hb hn hn' ha ho
  exact ⟨_, Mem.store_of_check he hc hr⟩


/-- For every memory: a live slot of thread `who` of `n` bytes aligned to `a` is a writable
`Mem.BufferIn` of space 0 owned by `who`. -/
theorem Mem.slot_bufferIn {who : Nat} {m : Mem} {b n a : Nat} (h : m.slot who b n a = true)
    (hl : m.liveAt b = true) : m.BufferIn 0 b n a (.thread who) true := by
  unfold Mem.slot at h
  unfold Mem.liveAt at hl
  split at h
  · rename_i B hB
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq, Bool.not_eq_true'] at h
    obtain ⟨⟨⟨⟨⟨⟨hs, hr⟩, hown⟩, hsz⟩, hal⟩, hgal⟩, -⟩ := h
    simp only [hB, Option.any_some] at hl
    exact ⟨B, hB, hs, hl, hown, by rw [hr]; rfl, hsz, Nat.dvd_of_mod_eq_zero hal,
      Nat.dvd_of_mod_eq_zero hgal⟩
  · cases h

/-- For every memory: a slot's block is in space 0 and its `n` bytes end at or below `2 ^ 64`. -/
theorem Mem.slot_fits {who : Nat} {m : Mem} {b n a : Nat} (h : m.slot who b n a = true) :
    ∃ B, m.blocks b = some B ∧ B.space = 0 ∧ B.addr + n ≤ 2 ^ 64 := by
  unfold Mem.slot at h
  split at h
  · rename_i B hB
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq, Bool.not_eq_true'] at h
    exact ⟨B, hB, h.1.1.1.1.1.1, h.2⟩
  · cases h

/-- For every memory and thread: `Mem.fresh` gives different blocks at different indices. -/
theorem Mem.fresh_ne (m : Mem) (n : Nat) {i j : Nat} (h : i ≠ j) : m.fresh n i ≠ m.fresh n j := by
  intro e
  simp only [Mem.fresh, Nat.add_left_cancel_iff, Nat.pair_eq_pair] at e
  exact h e.2

open MojoProof.Sym in
/-- For every layout with 64-bit pointers in space 0 and memory: a live slot of `n > 0` bytes has
an address `g` with `g + n` at or below the pointer range. -/
theorem Mem.slot_addr {l : Layout} {who : Nat} {m : Mem} {b n a : Nat}
    (h : m.slot who b n a = true) (hl : m.liveAt b = true) (hw : (l.ptr 0).1 = 64) (hn : 0 < n) :
    ∃ g, m.addr l 0 ⟨b, 0⟩ = .ok g ∧ g + n ≤ 2 ^ (l.ptr 0).1 := by
  obtain ⟨B, hB, -, hf⟩ := Mem.slot_fits h
  obtain ⟨g, hg, hgs, -⟩ := addr_buffer (l := l) (o := 0) (Mem.slot_bufferIn h hl) (Or.inl rfl)
    ⟨B, hB, by rw [ite_eq_left rfl, hw]; exact hf⟩ hn
  exact ⟨g, by simpa using hg, hgs⟩

/-- For every two memories with the same block at number `b`: the same `Mem.slot` at `b`. -/
theorem Mem.slot_blocks {m m' : Mem} {b : Nat} (h : m'.blocks b = m.blocks b) (who n a : Nat) :
    m'.slot who b n a = m.slot who b n a := by
  unfold Mem.slot; rw [h]

/-- For every two memories with the same block at number `b`: the same `Mem.liveAt` at `b`. -/
theorem Mem.liveAt_blocks {m m' : Mem} {b : Nat} (h : m'.blocks b = m.blocks b) :
    m'.liveAt b = m.liveAt b := by
  unfold Mem.liveAt; rw [h]

/-- For every memories `m`, `m'` with the same `next`, thread number and step: the same `alloca`
number (`Mem.fresh`). -/
theorem Mem.fresh_of_next {m m' : Mem} (h : m'.next = m.next) (n k : Nat) :
    m'.fresh n k = m.fresh n k := by
  unfold Mem.fresh; rw [h]

/-! ## The blocks outside a set -/

/-- Memories `m` and `m'` have the same block, or none, at every number outside `S`. -/
def Mem.SameOff (S : Nat → Prop) (m m' : Mem) : Prop := ∀ q, ¬ S q → m'.blocks q = m.blocks q

/-- For every set `S` and memory `m`: `m` has `m`'s blocks outside `S`. -/
theorem Mem.SameOff.refl (S : Nat → Prop) (m : Mem) : m.SameOff S m := fun _ _ => rfl

/-- For every set `S` and memories `m₁`, `m₂`, `m₃`: `Mem.SameOff S` composes. -/
theorem Mem.SameOff.trans {S : Nat → Prop} {m₁ m₂ m₃ : Mem} (h : m₁.SameOff S m₂)
    (h' : m₂.SameOff S m₃) : m₁.SameOff S m₃ := fun q hq => (h' q hq).trans (h q hq)

/-- For every sets `S`, `S'` with `S` in `S'` and memories: `Mem.SameOff S` gives
`Mem.SameOff S'`. -/
theorem Mem.SameOff.mono {S S' : Nat → Prop} {m m' : Mem} (h : m.SameOff S m')
    (hS : ∀ q, S q → S' q) : m.SameOff S' m' := fun q hq => h q fun hs => hq (hS q hs)

/-- **An allocation at a number changes only that number**, for every layout, memory, space,
size, alignment, liveness, writability, owner, addresses, initial bytes and number `x`
(`Mem.alloc_num_ne`). -/
theorem Mem.SameOff.alloc (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte) (x : Nat) :
    m.SameOff (· = x)
      (m.alloc l space size align live readOnly owner addr gaddr init (some x)).1 :=
  fun _ h => Mem.alloc_num_ne l m space size align live readOnly owner addr gaddr init h

/-- For every set `S`, memories `m`, `m'` with `m'` having `m`'s blocks outside `S`, and number
`q` outside `S`: every block of `m` at `q` is `m'`'s, the premise of `Mem.Buffer.of_block`,
`Mem.Fits.of_block` and `Mem.Holds.of_block`. -/
theorem Mem.SameOff.block {S : Nat → Prop} {m m' : Mem} (h : m.SameOff S m') {q : Nat}
    (hq : ¬ S q) : ∀ x, m.blocks q = some x → m'.blocks q = some x :=
  fun _ hx => (h q hq).trans hx

/-- For every set `S`, memories `m`, `m'` with `m'` having `m`'s blocks outside `S`, number `b`
outside `S` and slot parameters: the same `Mem.slot` at `b`. -/
theorem Mem.SameOff.slot {S : Nat → Prop} {m m' : Mem} (h : m.SameOff S m') {b : Nat}
    (hb : ¬ S b) (who n a : Nat) : m'.slot who b n a = m.slot who b n a :=
  Mem.slot_blocks (h b hb) who n a

/-- The `alloca` numbers of memory `m` of the threads whose numbers are in `N`: `Mem.fresh m n k`
for `n` in `N`, at every step `k`. -/
def Mem.FreshOf (m : Mem) (N : Nat → Prop) (q : Nat) : Prop := ∃ n k, N n ∧ q = m.fresh n k

/-- **Another thread's `alloca` numbers leave a thread's.** For every memory `m`, set of thread
numbers `N`, thread number `n` not in `N` and step `k`: `n`'s number at step `k` is not an
`alloca` number of the threads of `N` (`Mem.fresh_inj`). With `Mem.SameOff`, a memory changed
only at those numbers has the same block there. -/
theorem Mem.not_freshOf {m : Mem} {N : Nat → Prop} {n : Nat} (hn : ¬ N n) (k : Nat) :
    ¬ m.FreshOf N (m.fresh n k) :=
  fun ⟨_, _, hN, e⟩ => hn (by rwa [Mem.fresh_inj e])

/-- **The `alloca` numbers leave the launch's numbers.** For every memory `m`, set of thread
numbers `N` and number `q` below `m.next`: `q` is not an `alloca` number of the threads of `N`.
-/
theorem Mem.not_freshOf_lt {m : Mem} {N : Nat → Prop} {q : Nat} (hq : q < m.next) :
    ¬ m.FreshOf N q :=
  fun ⟨_, _, _, e⟩ => by rw [e] at hq; unfold Mem.fresh at hq; omega

end MojoProof.Sem
