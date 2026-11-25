import MojoProof.Sem.ScheduleOwned

/-!
# Race freedom of shared memory across barriers, from a run

docs/proofs/barrier-owned.md and docs/proofs/reduction.md. A block of threads' shared memory is
a block whose owner is that block of threads (`shared`, MojoProof/Sem/Grid.lean); `Mem.ctaOf`
names it.

Proved for every trace; a race is one of the core's `racy` at `sig`, and the theorems about races
are for every launch and trace whose accesses are by threads of the launch in their blocks of
threads and that is shaped (the premises of `racy_iff`, which every reachable grid's trace has,
`Grid.start_reach_fits`):

- `racy_shared`: for every number `B` of threads per block of threads, map `ofSh` from a memory
  block to the block of threads whose shared memory it is, writer map `wr` (phase, block, byte
  to a thread's number in its block of threads, `none` for a byte nobody writes in that phase)
  and discipline `G` (`Owned`) of the other blocks: if every access to `β`'s shared memory is by a
  thread `k` of `β` (`k / B = β`) and, at each of its bytes, is by the byte's writer `k % B` or is
  a read of a byte with no writer, and every access to another block follows `G` with each thread
  its own tile, the trace has no race. It is `racy_eq_false_of_writers`, which lets a thread read
  bytes outside its tile, unlike `racy_eq_false_of_phased`.
- `racy_halving`, the halving tree of a reduction, for every `B`, cell width `w` and stride
  sequence `s` (by phase): each access to `β`'s shared memory lies in one cell `c` of `w` bytes,
  and is either by the thread `c` of `β` with `c < s p` (it writes or reads its own cell) or a
  read with `s p ≤ c`. `racy_shared` with cell `c` written in phase `p` by thread `c` when
  `c < s p`.
- `racy_cells`, for every `B > 0`, cell width `w` and cell map `cell` injective on `[0, B)`: each
  access to `β`'s shared memory by its thread `k` lies, in phase 0, among the bytes of cell
  `cell (k % B)`, and is a read in every later phase. `racy_shared` with the cell's one thread as
  its writer in phase 0. `racy_tpose` (MojoProof/Sem/Transpose.lean) is about the case
  `cell = tpose n`. `toNat_div_of_cell`: a byte of an access inside a cell is of that cell.
- `racy_dropBlocks`, for every selector `A` of blocks: if every two accesses to one selected
  block are atomics of one commuting operation (`RmwOp.commutes`) at one pointer with one length
  (as a reduction's output word is), the trace has no race when the trace without them
  (`dropBlocks`) has none; the other accesses keep their phases (`phases_dropBlocks`), and the
  trace without them keeps the premises of `racy_iff` (`mem_dropBlocks`,
  `Trace.Shaped.dropBlocks`).
- `phases_rounds`, for every number `G` of blocks of threads and property `Q` of an access at a
  phase: in a trace of rounds (`rounds`, with the barriers of blocks of threads `0` to `G - 1`,
  `bars G`, between two rounds), if every event of round `p` is an access by a block of threads
  below `G` with `Q p`, every access has `Q` at its phase. One theorem gives the access premises
  of `racy_cells` and of `racy_halving` from the rounds' accesses; MojoProof/Sym/SegTrace.lean
  gives those from a segment's summary. `Mem.log_barriers`: logged barriers are `bars G`, and
  the blocks stay.

Proved for every program, kernel, launch, arguments, memory, address choice and oracle:

- `Grid.start_reach_cta`: in every grid reachable from the start's, every access of the trace is
  by a thread `k` of block of threads `k / volume L.block`, and an access to `β`'s shared memory
  is by a thread of `β`. So the first two premises of `racy_shared` (and of `racy_cells` and
  `racy_halving`) hold of every run, with `B = volume L.block` and `ofSh = Mem.ctaOf`.
- `Grid.start_reach_commutes`: on a caller's memory every pointer byte of whose blocks names a
  number below `next` or with a block, in every grid reachable from the start's, every
  `atomicrmw`'s access of the trace is by a commuting operation (`RmwOp.commutes`). So on a run,
  atomics of one operation at one pointer with one length meet `racy_dropBlocks`'s premise.
- `Grid.start_sound_of_racy`: on a caller's memory every pointer byte of whose blocks names a
  number below `next` or with a block, one run to a grid in which every thread has returned,
  whose trace has no race and no access with `!invariant.load` to a block that a write touches,
  and whose observation satisfies `R`, makes the start's grid sound (`Grid.Sound`): every
  schedule gives that observation.
- `Grid.sound_cells`, for every cell width `w`, launch with `volume L.block > 0` and cell map
  injective on `[0, volume L.block)`: if in that run every access to a block of threads' shared
  memory lies, before the block's first barrier, among the `w` bytes of its thread `k`'s cell
  `cell (k % volume L.block)`, and is a read after it, and the other accesses follow a discipline
  `G` with each thread its own tile, the start's grid is sound. With `cell = tpose 32` and `w = 4`
  it is gevm_kernel's transposition on every valid launch with `ntid.x = 1024`
  (`Launch.tpose_env`).
- `Grid.sound_rounds`: the same when the run's trace is a trace of rounds (`rounds`) each of whose
  accesses meets both premises at its round (`Mem.CellAt`), a round touching only global blocks
  allowed; `Grid.sound_cells` with `phases_rounds`.
- `Grid.sound_halving`, for every cell width `w`, stride sequence `s` and selector `A` of blocks
  of atomics, with `B = volume L.block`: the same from `racy_dropBlocks` (with
  `Grid.start_reach_commutes`) and `racy_halving`, so that thread 0 of every block of threads may
  add its word to one output word by `atomicrmw`.

That a kernel's trace has the access pattern these premises state is not proved here; the
instances are in MojoProofTest/Shared.lean (the halving tree and the blocks of atomics on traces,
and their twins), MojoProofTest/Transpose.lean (`Grid.sound_cells` at `cell = tpose 32`) and
MojoProofTest/GevmTrace.lean (`Grid.sound_rounds` at gevm_kernel's two rounds, with its global
loads and store).
-/

namespace MojoProof.Sem

open LLVM Relation
open GPUProof

/-- The block of threads whose shared memory block `b` of `m` is: `β` when the block's owner is
`.cta β` (the blocks `shared` makes), `none` for every other block and for a number with no
block. -/
def Mem.ctaOf (m : Mem) (b : Nat) : Option Nat :=
  (m.blocks b).bind fun x => match x.owner with
    | .cta β => some β
    | _ => none

/-- **Shared memory with one writer per byte and phase has no race** (the core's `racy` at `sig`,
for every launch and trace with the premises of `racy_iff`). For every number `B` of threads per
block of threads, map `ofSh` from a memory block to the block of threads whose shared memory it
is (`none` for other blocks), writer map `wr` (phase, block, byte
to a thread's number in its block of threads, `none` for a byte nobody writes in that phase) and
discipline `G` (`Owned`) of the other blocks: if every access `x` (with its phase, `phases`) to
`β`'s shared memory is by a thread `k` of `β` (`x.who.cta = β` and `k / B = β`) and, at each of its
bytes, is by the byte's writer `k % B` or is a read of a byte with no writer, and every access to
another block follows `G` with each thread its own tile, the trace has no race.
`racy_eq_false_of_writers` with the writer `β * B + wr p b i` at `β`'s shared memory and the tile
of `G b` that holds the byte elsewhere (`Owned.at`). -/
theorem racy_shared {L : Launch} {tr : List Event} {B : Nat} {ofSh : Nat → Option Nat}
    {wr : Nat → Nat → Int → Option Nat} {G : Nat → Option (Tiling Nat)}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧
        ∀ i : Int, x.1.ptr.off ≤ i → i < x.1.ptr.off + x.1.len →
          wr x.2 x.1.ptr.block i = some (x.1.who.thread % B) ∨
            (x.1.write = false ∧ wr x.2 x.1.ptr.block i = none))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  refine racy_eq_false_of_writers (own := fun _ => id)
    (W := fun p b i => match ofSh b with
      | some β => (wr p b i).map (β * B + ·)
      | none => (G b).bind (·.at i)) hU hs (fun x hx i h1 h2 => ?_) (fun x hx y hy hc hb => ?_)
    fun _ _ _ _ _ _ _ ho => ho
  · cases e : ofSh x.1.ptr.block with
    | none => simpa only [e] using (hG x hx e).at h1 h2
    | some β =>
      obtain ⟨-, hk, hw⟩ := hS x hx β e
      have hd : β * B + x.1.who.thread % B = x.1.who.thread := by
        rw [← hk, Nat.mul_comm]
        exact Nat.div_add_mod _ _
      rcases hw i h1 h2 with h | ⟨hr, h⟩
      · left
        simp only
        rw [h]
        exact congrArg some hd
      · right
        refine ⟨hr, ?_⟩
        simp only
        rw [h]
        rfl
  · cases e : ofSh x.1.ptr.block with
    | none => simp only
    | some β => exact absurd ((hS x hx β e).1.trans (hS y hy β (hb ▸ e)).1.symm) hc

/-- **A byte of an access inside a cell is of that cell**, for every cell `c`, cell width `w`,
offset `o`, length `l` and byte `i`: if the bytes from `o` to `o + l - 1` lie among the `w` bytes
from `c * w` and `o ≤ i < o + l`, then `i.toNat / w = c`. -/
theorem toNat_div_of_cell {c w : Nat} {o l i : Int} (h1 : ((c * w : Nat) : Int) ≤ o)
    (h2 : o + l ≤ ((c * w + w : Nat) : Int)) (i1 : o ≤ i) (i2 : i < o + l) : i.toNat / w = c := by
  generalize hm : c * w = m at h1 h2
  have e : ((i.toNat : Nat) : Int) = i := Int.toNat_of_nonneg (by omega)
  apply Nat.div_eq_of_lt_le
  · rw [hm]
    omega
  · rw [Nat.succ_mul, hm]
    omega

/-- **Shared memory written at an injective cell map before the barrier and only read after it
has no race** (the core's `racy` at `sig`, for every launch and trace with the premises of
`racy_iff`). For every number `B > 0` of threads per block of threads,
cell width `w`, cell map `cell` injective on `[0, B)`, map `ofSh` from a memory block to the block
of threads whose shared memory it is and discipline `G` of the other blocks: if every access `x`
in phase `p` to `β`'s shared memory is by a thread `k` of `β` (`x.who.cta = β` and `k / B = β`),
lies in phase 0 among the `w` bytes of cell `cell (k % B)` (from `cell (k % B) * w`) and is a read
in every later phase, and every access to another block follows `G` with each thread its own
tile, the trace has no race. `racy_shared` with cell `c` written in phase 0 by the first `j < B`
with `cell j = c` (`List.find?`), which is the only one, and by nobody later. `racy_tpose`
(MojoProof/Sem/Transpose.lean) has the premises of the case `cell = tpose n`, `B = n * n`, with
each access the whole cell; it is proved from `racy_eq_false_of_phased` and `Tiling.tpose`. -/
theorem racy_cells {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    {B w : Nat} (hB : 0 < B) {cell : Nat → Nat}
    (hc : ∀ i < B, ∀ j < B, cell i = cell j → i = j) {ofSh : Nat → Option Nat}
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧
        (x.2 = 0 → ((cell (x.1.who.thread % B) * w : Nat) : Int) ≤ x.1.ptr.off ∧
          x.1.ptr.off + x.1.len ≤ ((cell (x.1.who.thread % B) * w + w : Nat) : Int)) ∧
        (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false :=
  racy_shared hU hs (B := B) (ofSh := ofSh) (G := G)
    (wr := fun p _ i => if p = 0 then (List.range B).find? (cell · == i.toNat / w) else none)
    (fun x hx β e => by
      obtain ⟨hct, hk, h0, hr⟩ := hS x hx β e
      refine ⟨hct, hk, fun i i1 i2 => ?_⟩
      by_cases hp : x.2 = 0
      · obtain ⟨h1, h2⟩ := h0 hp
        have hi : i.toNat / w = cell (x.1.who.thread % B) := toNat_div_of_cell h1 h2 i1 i2
        have hm : x.1.who.thread % B ∈ List.range B := List.mem_range.2 (Nat.mod_lt _ hB)
        left
        show (if x.2 = 0 then (List.range B).find? (cell · == i.toNat / w) else none) = _
        rw [ite_eq_left hp, hi]
        cases ef : (List.range B).find? (cell · == cell (x.1.who.thread % B)) with
        | none => exact absurd (beq_self_eq_true _) (List.find?_eq_none.1 ef _ hm)
        | some j =>
          have hj := List.find?_some ef
          simp only [beq_iff_eq] at hj
          rw [hc j (List.mem_range.1 (List.mem_of_find?_eq_some ef)) _ (Nat.mod_lt _ hB) hj]
      · right
        refine ⟨hr hp, ?_⟩
        show (if x.2 = 0 then (List.range B).find? (cell · == i.toNat / w) else none) = none
        rw [ite_eq_right hp])
    hG

/-- **The halving tree of a reduction has no race** (the core's `racy` at `sig`, for every
launch and trace with the premises of `racy_iff`). For every number `B`
of threads per block of threads, cell width `w`, stride sequence `s` (by phase), map `ofSh` from
a memory block to the block of threads whose shared memory it is and discipline `G` of the other
blocks: if every access `x` in phase `p` to `β`'s shared memory is by a thread `k` of `β`
(`x.who.cta = β` and `k / B = β`), lies in one cell `c` of `w` bytes (the bytes from `c * w`), and
either is by the cell's thread (`c = k % B`) with `c < s p`, or is a read with `s p ≤ c`, and every
access to another block follows `G` with each thread its own tile, the trace has no race. At
stride `s p`, thread `c < s p` reads cells `c` and `c + s p` and writes cell `c`. `racy_shared`
with cell `c` written in phase `p` by thread `c` when `c < s p`, by nobody otherwise. -/
theorem racy_halving {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    {B w : Nat} {s : Nat → Nat} {ofSh : Nat → Option Nat} {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧ ∃ c : Nat, ((c * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((c * w + w : Nat) : Int) ∧
        (c = x.1.who.thread % B ∧ c < s x.2 ∨ x.1.write = false ∧ s x.2 ≤ c))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false :=
  racy_shared hU hs (B := B) (ofSh := ofSh) (G := G)
    (wr := fun p _ i => if i.toNat / w < s p then some (i.toNat / w) else none)
    (fun x hx β e => by
      obtain ⟨hc, hk, c, h1, h2, h⟩ := hS x hx β e
      refine ⟨hc, hk, fun i i1 i2 => ?_⟩
      have hi : i.toNat / w = c := toNat_div_of_cell h1 h2 i1 i2
      show (if i.toNat / w < s x.2 then some (i.toNat / w) else none) = _ ∨
        (_ ∧ (if i.toNat / w < s x.2 then some (i.toNat / w) else none) = none)
      rw [hi]
      rcases h with ⟨hct, hlt⟩ | ⟨hr, hle⟩
      · exact .inl (by rw [ite_eq_left hlt, hct])
      · exact .inr ⟨hr, by rw [ite_eq_right (by omega)]⟩)
    hG

/-- The trace `tr` without its accesses to the blocks `A` selects; barriers are kept. -/
def dropBlocks (A : Nat → Bool) : List Event → List Event
  | [] => []
  | .barrier k :: tr => .barrier k :: dropBlocks A tr
  | .access a :: tr => if A a.ptr.block then dropBlocks A tr else .access a :: dropBlocks A tr

/-- **Dropping blocks keeps the other accesses' phases**, for every selector `A` and trace: the
accesses of `dropBlocks A tr` with their phases are those of `tr` to blocks `A` does not select,
and the barrier counts are those of `tr`. By induction on the trace. -/
theorem phases_dropBlocks (A : Nat → Bool) : ∀ tr : List Event,
    phases (dropBlocks A tr) = ((phases tr).1.filter fun x => !A x.1.ptr.block, (phases tr).2)
  | [] => rfl
  | .barrier k :: tr => by
    rw [dropBlocks, phases_barrier, phases_barrier, phases_dropBlocks A tr]
  | .access a :: tr => by
    cases h : A a.ptr.block <;>
      simp [dropBlocks, h, phases_access, phases_dropBlocks A tr]

/-- The events of `dropBlocks A tr` are events of `tr`, for every selector and trace. -/
theorem mem_dropBlocks {A : Nat → Bool} {e : Event} : ∀ {tr : List Event},
    e ∈ dropBlocks A tr → e ∈ tr
  | [], h => h
  | .barrier _ :: _, h => by
    rcases List.mem_cons.1 h with rfl | h
    · exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (mem_dropBlocks h)
  | .access a :: _, h => by
    simp only [dropBlocks] at h
    split at h
    · exact List.mem_cons_of_mem _ (mem_dropBlocks h)
    · rcases List.mem_cons.1 h with rfl | h
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (mem_dropBlocks h)

/-- `dropBlocks A` keeps the barriers and the accesses to blocks `A` does not select, for every
selector and trace. -/
theorem dropBlocks_eq_filter (A : Nat → Bool) : ∀ tr : List Event,
    dropBlocks A tr = tr.filter fun | .barrier _ => true | .access a => !A a.ptr.block
  | [] => rfl
  | .barrier _ :: tr => by simp [dropBlocks, dropBlocks_eq_filter A tr]
  | .access a :: tr => by
    cases h : A a.ptr.block <;> simp [dropBlocks, h, dropBlocks_eq_filter A tr]

/-- **Dropping blocks keeps the shape**, for every selector and trace `tr` (newest first) whose
reverse is shaped: an `atomicrmw`'s read and write are at one block, so both stay or both go
(`Trace.Shaped.filter`). -/
theorem Trace.Shaped.dropBlocks {A : Nat → Bool} {tr : List Event}
    (h : Trace.Shaped tr.reverse) : Trace.Shaped (dropBlocks A tr).reverse := by
  rw [dropBlocks_eq_filter, ← List.filter_reverse]
  exact h.filter fun _ => rfl

/-- **Blocks of atomics of one commuting operation on the same bytes do not race** (the core's
`racy` at `sig`, for every launch and trace with the premises of `racy_iff`, which the trace
without the selected blocks then has too, `mem_dropBlocks` and `Trace.Shaped.dropBlocks`). For
every selector `A` of blocks: if every two accesses (with their phases, `phases`) to
one block `A` selects are atomics of one commuting operation (`RmwOp.commutes`) at one pointer with
one length, and the trace without the accesses to those blocks (`dropBlocks`) has no race, then
`tr` has no race. Two such accesses do not conflict (`Access.conflict`), an access to such a block
overlaps no access to another block, and the other pairs are pairs of `dropBlocks A tr` with the
same phases (`phases_dropBlocks`). -/
theorem racy_dropBlocks {L : Launch} {A : Nat → Bool} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hA : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, A x.1.ptr.block = true →
      x.1.ptr.block = y.1.ptr.block → x.1.atomic.any RmwOp.commutes = true ∧
        x.1.atomic = y.1.atomic ∧ x.1.ptr = y.1.ptr ∧ x.1.len = y.1.len)
    (h : GPUProof.racy sig ((dropBlocks A tr).map (Event.toCore L)).reverse = false) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  cases hr : GPUProof.racy sig (tr.map (Event.toCore L)).reverse with
  | false => rfl
  | true =>
    obtain ⟨x, hx, y, hy, hc⟩ := (racy_iff hU hs).1 hr
    have hcf : x.1.conflict y.1 = true := by
      simp only [clash, Bool.and_eq_true] at hc
      exact hc.1.2
    have hb : x.1.ptr.block = y.1.ptr.block := by
      simp only [Access.conflict, Access.overlaps, Bool.and_eq_true, beq_iff_eq] at hcf
      exact hcf.1.1.1.1.1.1
    cases ex : A x.1.ptr.block with
    | true =>
      obtain ⟨h1, h2, h3, h4⟩ := hA x hx y hy ex hb
      rw [Access.conflict, h1, h2, h3, h4] at hcf
      simp at hcf
    | false =>
      have ey : A y.1.ptr.block = false := hb ▸ ex
      have hd : GPUProof.racy sig ((dropBlocks A tr).map (Event.toCore L)).reverse = true :=
        (racy_iff (fun a ha => hU a (mem_dropBlocks ha)) hs.dropBlocks).2 ⟨x, by
        rw [phases_dropBlocks]
        simpa [ex] using hx, y, by
        rw [phases_dropBlocks]
        simpa [ey] using hy, hc⟩
      rw [h] at hd
      exact absurd hd (by decide)

/-- The barriers of blocks of threads `0` to `G - 1`, newest first, for every `G`: the events a
barrier's fire puts in front of the trace on a grid of `G` blocks of threads (`Mem.log_barriers`;
`Grid.fire_barriers`, MojoProof/Sym/SchedWait.lean). -/
def bars (G : Nat) : List Event :=
  ((List.range G).map .barrier).reverse

/-- **Logged barriers**, for every memory and list `bs` of blocks of threads: logging `.barrier b`
for each `b` of `bs` in turn puts their barriers, newest first, in front of the trace and changes
nothing else, so the blocks are `m`'s. With `bs = List.range G` they are `bars G`. -/
theorem Mem.log_barriers (bs : List Nat) (m : Mem) :
    bs.foldl (fun m b => m.log (.barrier b)) m =
      { m with trace := (bs.map .barrier).reverse ++ m.trace } := by
  induction bs generalizing m with
  | nil => rfl
  | cons b bs ih =>
    rw [List.foldl_cons, ih]
    simp [Mem.log]

/-- A trace of rounds, for every number `G` of blocks of threads: the events `Es` of the rounds,
oldest first, with the barriers of blocks of threads `0` to `G - 1` (`bars G`) between two rounds
and the newest round in front, as a trace is. -/
def rounds (G : Nat) : List (List Event) → List Event
  | [] => []
  | E :: Es => Es.foldl (fun tr E' => E' ++ (bars G ++ tr)) E

/-- **The phases of a trace of rounds**, for every number `G` of blocks of threads, property `Q`
of an access at a phase and rounds `Es`: if every event of round `p` (`Es[p]?`) is an access by a
block of threads below `G` with `Q p`, every access of `rounds G Es` has `Q` at its phase
(`phases`). Each round's accesses are in the phase the barriers before it count, since each of
those barriers is one of every block of threads below `G`. With `Q` the cell pattern it gives the
access premise of `racy_cells` and `Grid.sound_cells`; with the halving pattern, that of
`racy_halving` and `Grid.sound_halving`. By `phasesF_eq` and induction on the rounds. -/
theorem phases_rounds {G : Nat} {Q : Nat → Access → Prop} {Es : List (List Event)}
    (h : ∀ p E, Es[p]? = some E → ∀ e ∈ E, ∃ a, e = .access a ∧ a.who.cta < G ∧ Q p a) :
    ∀ x ∈ (phases (rounds G Es)).1, Q x.2 x.1 := by
  have hacc : ∀ (n : Nat) (E tr : List Event),
      (∀ e ∈ E, ∃ a, e = .access a ∧ a.who.cta < G ∧ Q n a) →
      (∀ j < G, (phasesF tr).2 j = n) → (∀ x ∈ (phasesF tr).1, Q x.2 x.1) →
      (∀ j < G, (phasesF (E ++ tr)).2 j = n) ∧ ∀ x ∈ (phasesF (E ++ tr)).1, Q x.2 x.1 := by
    intro n E tr hE h1 h2
    induction E with
    | nil => exact ⟨h1, h2⟩
    | cons e E ih =>
      obtain ⟨a, rfl, ha, hq⟩ := hE _ (List.mem_cons_self ..)
      obtain ⟨i1, i2⟩ := ih fun e he => hE e (List.mem_cons_of_mem _ he)
      refine ⟨i1, fun x hx => ?_⟩
      change x ∈ (a, (phasesF (E ++ tr)).2 a.who.cta) :: (phasesF (E ++ tr)).1 at hx
      rcases List.mem_cons.1 hx with rfl | hx
      · rw [i1 _ ha]
        exact hq
      · exact i2 x hx
  have hbar : ∀ (bs : List Nat) (tr : List Event), phasesF (bs.map .barrier ++ tr) =
      ((phasesF tr).1, fun j => (phasesF tr).2 j + bs.count j) := by
    intro bs tr
    induction bs with
    | nil => rfl
    | cons b bs ih =>
      change ((phasesF (bs.map .barrier ++ tr)).1, fun j => if b = j then
        (phasesF (bs.map .barrier ++ tr)).2 j + 1 else (phasesF (bs.map .barrier ++ tr)).2 j) = _
      rw [ih]
      congr 1
      funext j
      simp only [List.count_cons, beq_iff_eq]
      split <;> omega
  have hrun : ∀ (Es' : List (List Event)) (tr : List Event) (n : Nat),
      (∀ j < G, (phasesF tr).2 j = n) → (∀ x ∈ (phasesF tr).1, Q x.2 x.1) →
      (∀ p E, Es'[p]? = some E → ∀ e ∈ E,
        ∃ a, e = .access a ∧ a.who.cta < G ∧ Q (n + 1 + p) a) →
      ∀ x ∈ (phasesF (Es'.foldl (fun tr E' => E' ++ (bars G ++ tr)) tr)).1, Q x.2 x.1 := by
    intro Es'
    induction Es' with
    | nil => exact fun _ _ _ h2 _ => h2
    | cons E Es' ih =>
      intro tr n h1 h2 hE
      have hb := hbar (List.range G).reverse tr
      rw [List.map_reverse] at hb
      have ⟨i1, i2⟩ := hacc (n + 1) E (bars G ++ tr) (hE 0 E rfl)
        (fun j hj => by
          rw [bars, hb]
          dsimp only
          rw [List.count_reverse,
            List.count_eq_one_of_mem List.nodup_range (List.mem_range.2 hj), h1 j hj])
        (fun x hx => by
          rw [bars, hb] at hx
          exact h2 x hx)
      exact ih _ (n + 1) i1 i2 fun p E' hp => by
        have := hE (p + 1) E' (by rwa [List.getElem?_cons_succ])
        rwa [show n + 1 + (p + 1) = n + 1 + 1 + p by omega] at this
  rw [(phasesF_eq _).1]
  cases Es with
  | nil => simp [rounds, phasesF]
  | cons E Es =>
    have ⟨i1, i2⟩ := hacc 0 E [] (h 0 E rfl) (fun _ _ => rfl) (by simp [phasesF])
    rw [List.append_nil] at i1 i2
    exact hrun Es E 0 i1 i2 fun p E' hp => by
      have := h (p + 1) E' (by rwa [List.getElem?_cons_succ])
      rwa [show 0 + 1 + p = p + 1 by omega]

section Grid

variable {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
  {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}

/-- **Every access of a run is by a thread of its block of threads, and shared memory is only
its block of threads'**, for every program, kernel, launch, arguments, memory, address choice and
oracle: in every grid reachable from the start's, every access of the trace is by a thread `k`
of block of threads `k / volume L.block` (`Grid.start_ctx`), and an access to `β`'s shared memory
(`Mem.ctaOf`) is by a thread of `β`, as the block's owner admits it (`Grid.advance_admits`) and a
step keeps every block's owner (`Grid.start_reach_changes`). -/
theorem Grid.start_reach_cta (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) :
    ∀ a, .access a ∈ g.mem.trace → a.who.cta = a.who.thread / volume L.block ∧
      ∀ β, g.mem.ctaOf a.ptr.block = some β → a.who.cta = β := by
  have key : ∀ a, .access a ∈ g.mem.trace → a.who.cta = a.who.thread / volume L.block ∧
      ∃ x, g.mem.blocks a.ptr.block = some x ∧ x.owner.admits a.who = true := by
    induction hr with
    | refl =>
      intro a ha
      rw [Grid.start_trace h] at ha
      cases ha
    | @tail g g' hr hs ih =>
      obtain ⟨n, hn | hn⟩ := hs
      · obtain ⟨t, s, m', ht, rfl, htr, -⟩ := Grid.advance_set hn
        obtain ⟨_, -, hold⟩ := (Grid.start_reach_changes h hr ht hn).old
        intro a ha
        change .access a ∈ m'.trace at ha
        rw [htr] at ha
        rcases List.mem_append.1 ha with ha | ha
        · obtain ⟨x, hx, hadm⟩ := Grid.advance_admits hn a ha
          obtain ⟨x', hx', -, hown, -⟩ := hold _ x hx
          have hw : a.who = ⟨n, n / volume L.block⟩ := by
            rw [Grid.pending_who ha, (Grid.start_ctx h n).2.1]
          rw [← Grid.pending_who ha] at hadm
          exact ⟨by rw [hw], x', hx', by rw [hown]; exact hadm⟩
        · obtain ⟨hw, x, hx, hadm⟩ := ih a ha
          obtain ⟨x', hx', -, hown, -⟩ := hold _ x hx
          exact ⟨hw, x', hx', by rw [hown]; exact hadm⟩
      · obtain ⟨-, i, -, -, -, htr⟩ := Grid.fire_trace hn
        intro a ha
        rw [htr] at ha
        have ha' : .access a ∈ g.mem.trace := by
          rcases List.mem_append.1 ha with ha | ha
          · split at ha <;> simp at ha
          · exact ha
        rw [(Grid.fire_blocks hn).1]
        exact ih a ha'
  intro a ha
  obtain ⟨hc, x, hx, hadm⟩ := key a ha
  refine ⟨hc, fun β hβ => ?_⟩
  cases ho : x.owner with
  | cta b =>
    simp only [Mem.ctaOf, hx, ho, Option.bind_some, Option.some.injEq] at hβ
    simpa [ho, Owner.admits, hβ] using hadm
  | all => simp [Mem.ctaOf, hx, ho] at hβ
  | thread n => simp [Mem.ctaOf, hx, ho] at hβ

/-- **Every atomic of a run commutes**, for every program, kernel, launch, arguments, address
choice and oracle, on a caller's memory every pointer byte of whose blocks names a number below
`next` or with a block (`m.BytesIn m.Known`): in every grid reachable from the start's, the
operation of every `atomicrmw`'s access of the trace commutes (`RmwOp.commutes`). Each is logged by
a step that succeeds from a closed grid (`Grid.start_reach_closed`, `Grid.advance_commutes`); a
fire logs only barriers. -/
theorem Grid.start_reach_commutes (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {g : Grid} (hr : ReflTransGen (Grid.Step L c) g₀ g) :
    ∀ a op, .access a ∈ g.mem.trace → a.atomic = some op → op.commutes = true := by
  induction hr with
  | refl =>
    intro a op ha
    rw [Grid.start_trace h] at ha
    cases ha
  | @tail g g' hr hs ih =>
    obtain ⟨n, hn | hn⟩ := hs
    · obtain ⟨t, s, m', ht, rfl, htr, -⟩ := Grid.advance_set hn
      intro a op ha ho
      change .access a ∈ m'.trace at ha
      rw [htr] at ha
      rcases List.mem_append.1 ha with ha | ha
      · exact Grid.advance_commutes (Grid.start_reach_closed h hm hr) hn ha ho
      · exact ih a op ha ho
    · obtain ⟨-, i, -, -, -, htr⟩ := Grid.fire_trace hn
      intro a op ha
      rw [htr] at ha
      rcases List.mem_append.1 ha with ha | ha
      · split at ha <;> simp at ha
      · exact ih a op ha

/-- **One race-free run decides every schedule**, for every program, kernel, launch, arguments,
address choice and oracle, on a caller's memory every pointer byte of whose blocks names a number
below `next` or with a block, and every observation `obs` that reads only the blocks: one run
from the start's grid to a grid `z` in which every thread has returned, whose trace has no race
and no access with `!invariant.load` to a block that a write of the trace touches, and whose
observation is `y` with `R y`, makes the start's grid sound (`Grid.Sound`). `Grid.start_sound`
with `Grid.Done.bad_iff`, `kept_of_split` and `Trace.Shaped.writes` (`Grid.start_reach_shaped`).
-/
theorem Grid.start_sound_of_racy (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    (hr : GPUProof.racy sig (z.mem.trace.map (Event.toCore L)).reverse = false)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  Grid.start_sound h hm hB run hz (fun hb => by
    have hz' := Path.exists_iff.1 ⟨_, run⟩
    have hsh := (Grid.start_reach_shaped h hz' 0).1
    rw [Grid.Done.bad_iff (Grid.start_reach_size h hz').le hz, hr,
      kept_of_split (W := fun b => ∃ e, Event.access e ∈ z.mem.trace ∧
      e.write = true ∧ e.ptr.block = b) (fun a ha hi ⟨e, he, hw, hb⟩ => hI a e ha he hi hw hb.symm)
      fun e he hw => by
        obtain ⟨e', he', hw', hp⟩ := hsh.writes he hw
        exact ⟨e', he', hw', by rw [hp]⟩] at hb
    simp at hb) hy hR

/-- **A valid launch's block of threads has a thread**: for every valid launch, `volume L.block`
is positive, the premise `hv` of `Grid.sound_cells`. -/
theorem Launch.Valid.volume_pos {L : Launch} (h : L.Valid) : 0 < volume L.block :=
  Nat.mul_pos (Nat.mul_pos (h.block_pos .x) (h.block_pos .y)) (h.block_pos .z)

/-- **Cells written before the barrier and only read after it, on a run** (gevm_kernel's barrier).
For every program, kernel, launch, arguments, address choice and oracle with `volume L.block > 0`
(on a valid launch, `Launch.Valid.volume_pos`), every cell width `w` and cell map `cell` injective
on `[0, volume L.block)`, on a caller's memory every pointer byte of whose blocks names a number
below `next` or with a block, every observation `obs` that reads only the blocks and every
discipline `G` (`Owned`): one run from the start's grid to a grid `z` in which every thread has
returned, in whose trace every access `x` by a thread `k` (with its phase, `phases`) to a block of
threads' shared memory (`Mem.ctaOf`) lies, before its block's first barrier, among the `w` bytes at
`cell (k % volume L.block) * w`, and after it is a read, every access to another block follows `G`
with each thread its own tile, no access with `!invariant.load` is to a block that a write touches,
and whose observation is `y` with `R y`, makes the start's grid sound (`Grid.Sound`): no schedule
races, and every schedule observes `y`. `racy_cells`, whose premises on the threads of each shared
block `Grid.start_reach_cta` gives. gevm_kernel's cell map is `tpose 32` on every valid launch with
`ntid.x = 1024` (`Launch.tpose_env`; `sound1024`, MojoProofTest/Transpose.lean). -/
theorem Grid.sound_cells (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {w : Nat} {cell : Nat → Nat} (hv : 0 < volume L.block)
    (hc : ∀ i < volume L.block, ∀ j < volume L.block, cell i = cell j → i = j)
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → ((cell (x.1.who.thread % volume L.block) * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((cell (x.1.who.thread % volume L.block) * w + w : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  have hf := Grid.start_reach_fits h (Path.exists_iff.1 ⟨_, run⟩)
  Grid.start_sound_of_racy h hm hB run hz (racy_cells hf.trace hf.2 hv hc (ofSh := z.mem.ctaOf)
    (fun x hx b e => by
      obtain ⟨hk, hb⟩ := Grid.start_reach_cta h (Path.exists_iff.1 ⟨_, run⟩) _ (mem_phases hx)
      exact ⟨hb b e, by rw [← hk, hb b e], hS x hx b e⟩) hG) hI hy hR

/-- **The access premises of `Grid.sound_cells` at one access**, for every memory `m`, number `B`
of threads per block of threads, cell width `w`, cell map `cell` and discipline `G`: access `a`
in phase `p`, if it is to a block of threads' shared memory (`m.ctaOf`), lies in phase 0 among
the `w` bytes at `cell (k % B) * w` of its thread `k` and is a read in every later phase; if it is
to another block, it follows `G` with each thread its own tile (`Owned G id`). An access to a
block that is no block of threads' shared memory meets the first part vacuously. -/
def Mem.CellAt (m : Mem) (B w : Nat) (cell : Nat → Nat) (G : Nat → Option (Tiling Nat))
    (p : Nat) (a : Access) : Prop :=
  (∀ b, m.ctaOf a.ptr.block = some b →
    (p = 0 → ((cell (a.who.thread % B) * w : Nat) : Int) ≤ a.ptr.off ∧
      a.ptr.off + a.len ≤ ((cell (a.who.thread % B) * w + w : Nat) : Int)) ∧
    (p ≠ 0 → a.write = false)) ∧
  (m.ctaOf a.ptr.block = none → MojoProof.Sem.Owned G id a)

/-- **Cells written before the barrier and only read after it, on a run of rounds**, for every
program, kernel, launch, arguments, address choice and oracle with `volume L.block > 0`, every cell
width `w`, cell map `cell` injective on `[0, volume L.block)`, discipline `G`, caller's memory and
observation as in `Grid.sound_cells`: one run from the start's grid to a grid `z` in which every
thread has returned, whose trace is a trace of rounds `rounds (volume L.grid) Es` (the barriers of
every block of threads between two rounds) in which every event of round `p` is an access by a
block of threads of the grid that meets `z.mem.CellAt (volume L.block) w cell G p` (a round may
touch only global blocks), no access with `!invariant.load` is to a block that a write touches,
and whose observation is `y` with `R y`, makes the start's grid sound (`Grid.Sound`).
`Grid.sound_cells`, whose two access premises `phases_rounds` gives. -/
theorem Grid.sound_rounds (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {w : Nat} {cell : Nat → Nat} (hv : 0 < volume L.block)
    (hc : ∀ i < volume L.block, ∀ j < volume L.block, cell i = cell j → i = j)
    {G : Nat → Option (Tiling Nat)} {Es : List (List Event)}
    (ht : z.mem.trace = rounds (volume L.grid) Es)
    (hE : ∀ p E, Es[p]? = some E → ∀ e ∈ E, ∃ a, e = .access a ∧ a.who.cta < volume L.grid ∧
      z.mem.CellAt (volume L.block) w cell G p a)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  have hQ := phases_rounds hE
  Grid.sound_cells h hm hB run hz hv hc (fun x hx => (hQ x (by rwa [← ht])).1)
    (fun x hx => (hQ x (by rwa [← ht])).2) hI hy hR

/-- **The halving tree of a reduction, on a run**, with blocks of atomics. For every program,
kernel, launch, arguments, address choice and oracle, every cell width `w`, stride sequence `s`
(by phase) and selector `A` of blocks, on a caller's memory every pointer byte of whose blocks
names a number below `next` or with a block, every observation `obs` that reads only the blocks and
every discipline `G` (`Owned`): one run from the start's grid to a grid `z` in which every thread
has returned, in whose trace every two accesses to one block `A` selects are atomics of one
operation at one pointer with one length, every other access `x` in phase `p` by a thread `k` to a
block of threads' shared memory (`Mem.ctaOf`) lies in one cell `c` of `w` bytes and either is by
the cell's thread (`c = k % volume L.block`) with `c < s p` or is a read with `s p ≤ c`, every
other access to another block follows `G` with each thread its own tile, no access with
`!invariant.load` is to a block that a write touches, and whose observation is `y` with `R y`,
makes the start's grid sound (`Grid.Sound`). The operation commutes on every run
(`Grid.start_reach_commutes`), so `racy_dropBlocks` applies; then `racy_halving` on the trace
without the selected blocks (`phases_dropBlocks`), whose premises on the threads of each shared
block `Grid.start_reach_cta` gives. With `A` selecting no block it is the halving tree alone. -/
theorem Grid.sound_halving (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {w : Nat} {s : Nat → Nat} {A : Nat → Bool} {G : Nat → Option (Tiling Nat)}
    (hA : ∀ x ∈ (phases z.mem.trace).1, ∀ y ∈ (phases z.mem.trace).1, A x.1.ptr.block = true →
      x.1.ptr.block = y.1.ptr.block → x.1.atomic.isSome = true ∧ x.1.atomic = y.1.atomic ∧
        x.1.ptr = y.1.ptr ∧ x.1.len = y.1.len)
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, A x.1.ptr.block = false →
      z.mem.ctaOf x.1.ptr.block = some b →
      ∃ c : Nat, ((c * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((c * w + w : Nat) : Int) ∧
        (c = x.1.who.thread % volume L.block ∧ c < s x.2 ∨ x.1.write = false ∧ s x.2 ≤ c))
    (hG : ∀ x ∈ (phases z.mem.trace).1, A x.1.ptr.block = false →
      z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R := by
  have hd : ∀ {x}, x ∈ (phases (dropBlocks A z.mem.trace)).1 →
      x ∈ (phases z.mem.trace).1 ∧ A x.1.ptr.block = false := fun hx => by
    rw [phases_dropBlocks] at hx
    simpa using hx
  have hA' : ∀ x ∈ (phases z.mem.trace).1, ∀ y ∈ (phases z.mem.trace).1,
      A x.1.ptr.block = true → x.1.ptr.block = y.1.ptr.block →
        x.1.atomic.any RmwOp.commutes = true ∧ x.1.atomic = y.1.atomic ∧ x.1.ptr = y.1.ptr ∧
          x.1.len = y.1.len := fun x hx y hy hb e => by
    obtain ⟨h1, h2⟩ := hA x hx y hy hb e
    obtain ⟨op, hop⟩ := Option.isSome_iff_exists.1 h1
    refine ⟨?_, h2⟩
    rw [hop, Option.any_some]
    exact Grid.start_reach_commutes h hm (Path.exists_iff.1 ⟨_, run⟩) x.1 op (mem_phases hx) hop
  have hf := Grid.start_reach_fits h (Path.exists_iff.1 ⟨_, run⟩)
  refine Grid.start_sound_of_racy h hm hB run hz (racy_dropBlocks hf.trace hf.2 hA' (racy_halving
    (fun a ha => hf.trace a (mem_dropBlocks ha)) hf.2.dropBlocks (B := volume L.block) (w := w)
    (ofSh := z.mem.ctaOf) (s := s) (fun x hx b e => ?_)
    fun x hx e => hG x (hd hx).1 (hd hx).2 e)) hI hy hR
  obtain ⟨hx, ha⟩ := hd hx
  obtain ⟨hc, hb⟩ := Grid.start_reach_cta h (Path.exists_iff.1 ⟨_, run⟩) _ (mem_phases hx)
  exact ⟨hb b e, by rw [← hc, hb b e], hS x hx b ha e⟩

end Grid

end MojoProof.Sem
