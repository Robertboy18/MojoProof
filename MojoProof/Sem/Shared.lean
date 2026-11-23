import MojoProof.Sem.ScheduleOwned

/-!
# Race freedom of shared memory across barriers, from a run

docs/proofs/barrier-owned.md and docs/proofs/reduction.md. A block of threads' shared memory is
a block whose owner is that block of threads (`shared`, MojoProof/Sem/Grid.lean); `Mem.ctaOf`
names it.

Proved for every trace:

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
  block are atomics of one operation at one pointer with one length (as a reduction's output word
  is), the trace has no race when the trace without them (`dropBlocks`) has none; the other
  accesses keep their phases (`phases_dropBlocks`).

Proved for every program, kernel, launch, arguments, memory, address choice and oracle:

- `Grid.start_reach_cta`: in every grid reachable from the start's, every access of the trace is
  by a thread `k` of block of threads `k / volume L.block`, and an access to `β`'s shared memory
  is by a thread of `β`. So the first two premises of `racy_shared` (and of `racy_cells` and
  `racy_halving`) hold of every run, with `B = volume L.block` and `ofSh = Mem.ctaOf`.
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
- `Grid.sound_halving`, for every cell width `w`, stride sequence `s` and selector `A` of blocks
  of atomics, with `B = volume L.block`: the same from `racy_dropBlocks` and `racy_halving`, so
  that thread 0 of every block of threads may add its word to one output word by `atomicrmw`.

That a kernel's trace has the access pattern these premises state is not proved here; the
instances are in MojoProofTest/Shared.lean (the halving tree and the blocks of atomics on traces,
and their twins) and MojoProofTest/Transpose.lean (`Grid.sound_cells` at `cell = tpose 32`).
-/

namespace MojoProof.Sem

open LLVM Relation

/-- The block of threads whose shared memory block `b` of `m` is: `β` when the block's owner is
`.cta β` (the blocks `shared` makes), `none` for every other block and for a number with no
block. -/
def Mem.ctaOf (m : Mem) (b : Nat) : Option Nat :=
  (m.blocks b).bind fun x => match x.owner with
    | .cta β => some β
    | _ => none

/-- **Shared memory with one writer per byte and phase has no race** (`racy`, every trace). For
every number `B` of threads per block of threads, map `ofSh` from a memory block to the block of
threads whose shared memory it is (`none` for other blocks), writer map `wr` (phase, block, byte
to a thread's number in its block of threads, `none` for a byte nobody writes in that phase) and
discipline `G` (`Owned`) of the other blocks: if every access `x` (with its phase, `phases`) to
`β`'s shared memory is by a thread `k` of `β` (`x.who.cta = β` and `k / B = β`) and, at each of its
bytes, is by the byte's writer `k % B` or is a read of a byte with no writer, and every access to
another block follows `G` with each thread its own tile, the trace has no race.
`racy_eq_false_of_writers` with the writer `β * B + wr p b i` at `β`'s shared memory and the tile
of `G b` that holds the byte elsewhere (`Owned.at`). -/
theorem racy_shared {tr : List Event} {B : Nat} {ofSh : Nat → Option Nat}
    {wr : Nat → Nat → Int → Option Nat} {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧
        ∀ i : Int, x.1.ptr.off ≤ i → i < x.1.ptr.off + x.1.len →
          wr x.2 x.1.ptr.block i = some (x.1.who.thread % B) ∨
            (x.1.write = false ∧ wr x.2 x.1.ptr.block i = none))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    racy tr = false := by
  refine racy_eq_false_of_writers (own := fun _ => id)
    (W := fun p b i => match ofSh b with
      | some β => (wr p b i).map (β * B + ·)
      | none => (G b).bind (·.at i)) (fun x hx i h1 h2 => ?_) (fun x hx y hy hc hb => ?_)
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
has no race** (`racy`, every trace). For every number `B > 0` of threads per block of threads,
cell width `w`, cell map `cell` injective on `[0, B)`, map `ofSh` from a memory block to the block
of threads whose shared memory it is and discipline `G` of the other blocks: if every access `x`
in phase `p` to `β`'s shared memory is by a thread `k` of `β` (`x.who.cta = β` and `k / B = β`),
lies in phase 0 among the `w` bytes of cell `cell (k % B)` (from `cell (k % B) * w`) and is a read
in every later phase, and every access to another block follows `G` with each thread its own
tile, the trace has no race. `racy_shared` with cell `c` written in phase 0 by the first `j < B`
with `cell j = c` (`List.find?`), which is the only one, and by nobody later. `racy_tpose`
(MojoProof/Sem/Transpose.lean) has the premises of the case `cell = tpose n`, `B = n * n`, with
each access the whole cell; it is proved from `racy_eq_false_of_phased` and `Tiling.tpose`. -/
theorem racy_cells {tr : List Event} {B w : Nat} (hB : 0 < B) {cell : Nat → Nat}
    (hc : ∀ i < B, ∀ j < B, cell i = cell j → i = j) {ofSh : Nat → Option Nat}
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧
        (x.2 = 0 → ((cell (x.1.who.thread % B) * w : Nat) : Int) ≤ x.1.ptr.off ∧
          x.1.ptr.off + x.1.len ≤ ((cell (x.1.who.thread % B) * w + w : Nat) : Int)) ∧
        (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    racy tr = false :=
  racy_shared (B := B) (ofSh := ofSh) (G := G)
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

/-- **The halving tree of a reduction has no race** (`racy`, every trace). For every number `B`
of threads per block of threads, cell width `w`, stride sequence `s` (by phase), map `ofSh` from
a memory block to the block of threads whose shared memory it is and discipline `G` of the other
blocks: if every access `x` in phase `p` to `β`'s shared memory is by a thread `k` of `β`
(`x.who.cta = β` and `k / B = β`), lies in one cell `c` of `w` bytes (the bytes from `c * w`), and
either is by the cell's thread (`c = k % B`) with `c < s p`, or is a read with `s p ≤ c`, and every
access to another block follows `G` with each thread its own tile, the trace has no race. At
stride `s p`, thread `c < s p` reads cells `c` and `c + s p` and writes cell `c`. `racy_shared`
with cell `c` written in phase `p` by thread `c` when `c < s p`, by nobody otherwise. -/
theorem racy_halving {tr : List Event} {B w : Nat} {s : Nat → Nat} {ofSh : Nat → Option Nat}
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧ ∃ c : Nat, ((c * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((c * w + w : Nat) : Int) ∧
        (c = x.1.who.thread % B ∧ c < s x.2 ∨ x.1.write = false ∧ s x.2 ≤ c))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    racy tr = false :=
  racy_shared (B := B) (ofSh := ofSh) (G := G)
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

/-- **Blocks of atomics of one operation on the same bytes do not race** (`racy`, every trace). For
every selector `A` of blocks: if every two accesses (with their phases, `phases`) to one block `A`
selects are atomics of one operation at one pointer with one length, and the trace without the
accesses to those blocks (`dropBlocks`) has no race, then `tr` has no race. Two such accesses do
not conflict (`Access.conflict`), an access to such a block overlaps no access to another block,
and the other pairs are pairs of `dropBlocks A tr` with the same phases (`phases_dropBlocks`). -/
theorem racy_dropBlocks {A : Nat → Bool} {tr : List Event}
    (hA : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, A x.1.ptr.block = true →
      x.1.ptr.block = y.1.ptr.block → x.1.atomic.isSome = true ∧ x.1.atomic = y.1.atomic ∧
        x.1.ptr = y.1.ptr ∧ x.1.len = y.1.len)
    (h : racy (dropBlocks A tr) = false) : racy tr = false := by
  cases hr : racy tr with
  | false => rfl
  | true =>
    obtain ⟨x, hx, y, hy, hc⟩ := racy_iff.1 hr
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
      have hd : racy (dropBlocks A tr) = true := racy_iff.2 ⟨x, by
        rw [phases_dropBlocks]
        simpa [ex] using hx, y, by
        rw [phases_dropBlocks]
        simpa [ey] using hy, hc⟩
      rw [h] at hd
      exact absurd hd (by decide)

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

/-- **One race-free run decides every schedule**, for every program, kernel, launch, arguments,
address choice and oracle, on a caller's memory every pointer byte of whose blocks names a number
below `next` or with a block, and every observation `obs` that reads only the blocks: one run
from the start's grid to a grid `z` in which every thread has returned, whose trace has no race
and no access with `!invariant.load` to a block that a write of the trace touches, and whose
observation is `y` with `R y`, makes the start's grid sound (`Grid.Sound`). `Grid.start_sound`
with `Grid.Done.bad_iff` and `kept_of_split`. -/
theorem Grid.start_sound_of_racy (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : z.Done)
    (hr : racy z.mem.trace = false)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  Grid.start_sound h hm hB run hz (fun hb => by
    rw [hz.bad_iff, hr, kept_of_split (W := fun b => ∃ e, Event.access e ∈ z.mem.trace ∧
      e.write = true ∧ e.ptr.block = b) (fun a ha hi ⟨e, he, hw, hb⟩ => hI a e ha he hi hw hb.symm)
      fun e he hw => ⟨e, he, hw, rfl⟩] at hb
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
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : z.Done)
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
  Grid.start_sound_of_racy h hm hB run hz (racy_cells hv hc (ofSh := z.mem.ctaOf)
    (fun x hx b e => by
      obtain ⟨hk, hb⟩ := Grid.start_reach_cta h (Path.exists_iff.1 ⟨_, run⟩) _ (mem_phases hx)
      exact ⟨hb b e, by rw [← hk, hb b e], hS x hx b e⟩) hG) hI hy hR

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
makes the start's grid sound (`Grid.Sound`). `racy_dropBlocks`, then `racy_halving` on the trace
without the selected blocks (`phases_dropBlocks`), whose premises on the threads of each shared
block `Grid.start_reach_cta` gives. With `A` selecting no block it is the halving tree alone. -/
theorem Grid.sound_halving (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : z.Done)
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
  refine Grid.start_sound_of_racy h hm hB run hz (racy_dropBlocks hA (racy_halving
    (B := volume L.block) (w := w) (ofSh := z.mem.ctaOf) (s := s) (fun x hx b e => ?_)
    fun x hx e => hG x (hd hx).1 (hd hx).2 e)) hI hy hR
  obtain ⟨hx, ha⟩ := hd hx
  obtain ⟨hc, hb⟩ := Grid.start_reach_cta h (Path.exists_iff.1 ⟨_, run⟩) _ (mem_phases hx)
  exact ⟨hb b e, by rw [← hc, hb b e], hS x hx b ha e⟩

end Grid

end MojoProof.Sem
