import MojoProofTest.GemvWarpWord
import MojoProofTest.Theorem0

/-!
# gemv_kernel's grid is sound, from its lanes' events

MojoProofTest/GemvWarpRun.lean's `Lanes.grid_run_inv` has the warps of gemv_kernel (`gemv`,
MojoProofTest/SymLane.lean, gemv_kernel float32 `b79a852b`) run as one canonical run
(`CanonRun`) to a memory where each in-range warp's row word loads, and carries every invariant
of memories that each warp's run keeps. MojoProofTest/GemvWarpWord.lean's `rows_of_loads` makes
those words their rows' `warpDot` up to NaNs. This file adds the trace: every event of the run is
one of `Ev`, and such a trace has no race and keeps the promise of `!invariant.load`, so the
start's grid is sound (`Grid.Sound`, through `CanonRun.start_sound`), and the kernel is sound
against `GPUProof.Spec.matVec` (`GPUProof.Kernel.Sound` at `sig`, through Theorem 0's
`MojoProofTest.Theorem0.sound_sig`).

* `Ev`: a lane's events, as gemv_kernel's IR has them (tests/corpus/gemv/, the `.ll` of
  `b79a852b`): the accesses of its own `alloca` slots (`%7`, `%8`, `%9`: stores at lines 29, 32
  and 37, loads at lines 39, 40, 43 and 44), its loads of the matrix and the vector (lines 98 and
  99, `!invariant.load`), and lane 0's store of its row's word (line 136, `store float %99, ptr
  %37`), which a warp whose row is `M` or more does not reach (line 56's branch to `%43`);
* `writer`, `racy_ev`: no race among such events (`racy_eq_false_of_writers`): a slot's bytes
  are its owner's (`Mem.fresh` numbers a thread's `alloca`s by its thread), the bytes of row `i`
  of the output are thread `32 i`'s, and the matrix and the vector are only read;
* `kept_ev`: such a trace keeps the promise (`kept_of_split`): the `!invariant.load`s read the
  matrix and the vector, which no event writes;
* `mem0_trace`, `ext_of_trace`, `ext_chain`, `ext_out`, `lanes_ext`, `out_ext`: a warp's run
  extends the trace by events of `Ev` (`Ext`) if each lane's run from its second `idx` shuffle
  (`%25`) to its next wait (`Lanes.mem2`) or its end (`Out.memE`) does: the `alloca`s log
  nothing, the butterfly shuffles change no memory, and the last phase (`GemvThread.out`) logs
  lane 0's store only;
* `slotEv_ev`, `out_events`, `lanes_events`: each lane does: a lane of a warp whose row is `M`
  or more, from `%25` to its end, accesses its own `alloca` slots only (`Out.memE_ext`), and a
  lane of a warp whose row is below `M`, from `%25` to `%78`'s first shuffle, accesses its own
  `alloca` slots and reads the matrix and the vector only (`Lanes.mem2_ext`);
* `rowsObs`, `RowsDot`, `grid_end`, `grid_sound`: at a one-dimensional launch whose warps' rows
  cover the matrix's rows, the warps'
  canonical run ends at a memory with no race, the promise kept and the output rows (loaded by
  the `who` the start gives thread `32 i`) meeting `grid_rows`' relation (`Lanes.grid_run_inv`
  at the invariant "the trace since the start is of `Ev`", `rows_of_loads` at the same run's
  memory), so on a caller's memory meeting `Mem.BytesIn` the start's grid is sound
  (`CanonRun.start_sound`);
* `RowsRule`, `rows_holds`, `starts`, `kernel_sound`: rows that are their `warpDot`s up to NaNs
  meet the rule of `GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 _)`
  (`MojoProof.Tile.holds_of`, `MojoProof.Tile.groupDot_approx`); gemv_kernel's launch starts on
  a memory closed for its arguments (`Sym.Grid.start_ok`); so gemv_kernel is sound at `sig`
  for the admission "address choice below `2 ^ 60`"
  (`grid_end`, `CanonRun.start_done`, `Grid.Done.bad_iff`, `MojoProofTest.Theorem0.sound_sig`);
* `m3_bytesIn`: `GemvThread.m3` meets `Mem.BytesIn`, so `grid_sound` has an instance at one
  block of 32 threads, `M = 1`, `K = 4`, on `m3`, with no premise but the start;
* `row_race`: why the launch is one-dimensional: at one block of 32 × 2 threads, two warps have
  row 0, and their lanes 0's stores at row 0 race.

`Grid.sound_cells` (MojoProof/Sem/Shared.lean) is not used: its `racy_kept_of_cells` takes
every block other than the output cells read-only, and gemv_kernel writes its `alloca` slots.

Tests of one program, gemv_kernel float32 `b79a852b`.
-/

namespace MojoProofTest.GemvSound

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvShfl MojoProofTest.GemvLoopBfly
open MojoProofTest.GemvWarpRun MojoProofTest.GemvWarpWord
open FloatLib.Floats.Formats.BinaryInterchange

/-- The events of gemv_kernel's lanes, for every number `N` (the warps' `next`), output block
`p0`, matrix and vector blocks `bA` and `bV` and row count `M`: an access with no `atomicrmw`
that is an access with no `!invariant.load` of a block from `N` on whose `Nat.unpair` of
`b - N` has the accessing thread first (its own `alloca` slot, `Mem.fresh`), a read of the
matrix's or the vector's block, or a 4-byte access with no `!invariant.load` at row `n / 32` of
`p0` by a thread `n` first in its warp (`n % 32 = 0`) with `n / 32 < M`. -/
def Ev (N p0 bA bV M : Nat) (e : Event) : Prop :=
  ∃ a, e = .access a ∧ a.atomic = none ∧
    ((N ≤ a.ptr.block ∧ (Nat.unpair (a.ptr.block - N)).1 = a.who.thread ∧
        a.invariant = false) ∨
      (a.write = false ∧ (a.ptr.block = bA ∨ a.ptr.block = bV)) ∨
      (a.ptr = ⟨p0, ((a.who.thread / 32 * 4 : Nat) : Int)⟩ ∧ a.len = 4 ∧
        a.who.thread % 32 = 0 ∧ a.who.thread / 32 < M ∧ a.invariant = false))

/-- The writer of byte `i` of block `b` in every phase, for every number `N` and output block
`p0`: for a block from `N` on, the thread first in `Nat.unpair (b - N)` (an `alloca` slot's
owner, `Mem.fresh`); in `p0`, the first thread `32 (i / 4)` of the warp of row `i / 4`; none
elsewhere. -/
def writer (N p0 : Nat) (_ : Nat) (b : Nat) (i : Int) : Option Nat :=
  if N ≤ b then some (Nat.unpair (b - N)).1 else if b = p0 then some (32 * (i.toNat / 4))
  else none

/-- **No race among gemv_kernel's lanes' events**, for every launch `L`, number `N`, blocks
`p0`, `bA` and `bV` below `N` with `bA` and `bV` not `p0`, row count `M` and trace `tr` with the
premises of `GPUProof.racy_iff`: if every event of `tr` is one of `Ev`, `tr` has no data race
(`GPUProof.racy` at `sig`). `racy_eq_false_of_writers` at `writer`, each thread its own tile: a
slot's bytes are its owner's, row `i`'s bytes of `p0` are thread `32 i`'s, and the matrix and the
vector are only read. -/
theorem racy_ev {L : Launch} {N p0 bA bV M : Nat} {tr : List Event} (hp : p0 < N)
    (hA : bA < N) (hV : bV < N) (hA0 : bA ≠ p0) (hV0 : bV ≠ p0)
    (he : ∀ e ∈ tr, Ev N p0 bA bV M e)
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  refine racy_eq_false_of_writers (W := writer N p0) (own := fun _ n => n) hU hs ?_
    (fun _ _ _ _ _ _ => rfl) (fun _ _ _ _ _ _ _ h => h)
  intro x hx i h1 h2
  obtain ⟨a, ha, -, hc⟩ := he _ (mem_phases hx)
  have e := Event.access.inj ha
  subst e
  rcases hc with ⟨hN, hu, -⟩ | ⟨hw, hb⟩ | ⟨hptr, hlen, h32, -, -⟩
  · left
    simp only [writer, hN, ↓reduceIte, hu]
  · right
    have h3 : ¬ N ≤ x.1.ptr.block := by omega
    have h4 : x.1.ptr.block ≠ p0 := by rcases hb with hb | hb <;> rw [hb] <;> assumption
    simp only [writer, h3, h4, ↓reduceIte, hw, and_self]
  · left
    have hb : x.1.ptr.block = p0 := by rw [hptr]
    have ho : x.1.ptr.off = ((x.1.who.thread / 32 * 4 : Nat) : Int) := by rw [hptr]
    rw [ho] at h1 h2
    rw [hlen] at h2
    have h3 : ¬ N ≤ p0 := by omega
    obtain ⟨q, rfl⟩ := Int.eq_ofNat_of_zero_le (by omega : (0 : Int) ≤ i)
    simp only [writer, hb, h3, ↓reduceIte, Int.toNat_natCast, Option.some.injEq]
    omega

/-- **gemv_kernel's lanes' events keep the promise of `!invariant.load`**, for every launch, number
`N`, blocks `bA` and `bV` below `N` and not `p0`, row count `M` and trace `tr`: if every event of
`tr` is one of `Ev`, `tr` keeps it (`GPUProof.kept` at `sig`). `kept_of_split` at the blocks `p0`
and those from `N` on: the `!invariant.load`s are reads of `bA` and `bV`, and the accesses that
write are at `p0` and the slots. -/
theorem kept_ev {L : Launch} {N p0 bA bV M : Nat} {tr : List Event} (hA : bA < N) (hV : bV < N)
    (hA0 : bA ≠ p0) (hV0 : bV ≠ p0) (he : ∀ e ∈ tr, Ev N p0 bA bV M e) :
    GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true := by
  refine kept_of_split (W := fun b => b = p0 ∨ N ≤ b) (fun a ha hi => ?_) (fun a ha hw => ?_)
  · obtain ⟨a', ha', -, hc⟩ := he _ ha
    have e := Event.access.inj ha'
    subst e
    rcases hc with ⟨-, -, h⟩ | ⟨-, hb⟩ | ⟨-, -, -, -, h⟩
    · rw [h] at hi
      cases hi
    · rintro (h | h) <;> rcases hb with hb | hb <;> omega
    · rw [h] at hi
      cases hi
  · obtain ⟨a', ha', hat, hc⟩ := he _ ha
    have e := Event.access.inj ha'
    subst e
    rcases hc with ⟨h, -, -⟩ | ⟨hw', -⟩ | ⟨hptr, -⟩
    · exact .inr h
    · cases hi : a.invariant <;>
        simp [Access.kind, hat, hw', hi, GPUProof.Kind.writes] at hw
    · exact .inl (by rw [hptr])

/-- For every warp of gemv_kernel, the lanes' `alloca`s keep the trace (`Mem.alloc_trace`). -/
theorem mem0_trace (w : Alloc) : ∀ j, (w.mem0 j).trace = w.m.trace
  | 0 => rfl
  | j + 1 => by
    simp only [Alloc.mem0, GemvEntryRun.slots, Mem.alloc_trace]
    exact mem0_trace w j

/-- For every property `P` of events and memories `m`, `m'`: a memory with `m`'s trace extends
it by events of `P` (none). -/
theorem ext_of_trace {P : Event → Prop} {m m' : Mem} (h : m'.trace = m.trace) : Ext P m m' :=
  ⟨[], by rw [h, List.nil_append], fun _ he => by simp at he⟩

/-- For every property `P` of events, family of memories `mm` and count `n`: if each `mm (j + 1)`
extends `mm j`'s trace by events of `P` for `j < n`, each `mm j` for `j ≤ n` extends `mm 0`'s
(`Ext.trans`). -/
theorem ext_chain {P : Event → Prop} {mm : Nat → Mem} {n : Nat}
    (h : ∀ j < n, Ext P (mm j) (mm (j + 1))) : ∀ j ≤ n, Ext P (mm 0) (mm j)
  | 0, _ => ext_of_trace rfl
  | j + 1, hj => (ext_chain h j (by omega)).trans (h j (by omega))

/-- **A thread's final memory logs its store only**: for every property `P` of events, layout
`l`, thread `who`, value, block numbers `p0`, `b7`, `b8`, `b9`, offset `o`, decidable `z` and
memory `my`: `GemvThread.out` extends `my`'s trace by events of `P` if the binary32 store of
`who` at offset `o` of `p0` is of `P` when `z` holds (`Mem.store_trace`; the dead slots log
nothing, `Mem.foldl_setLive_trace`). -/
theorem ext_out {P : Event → Prop} (l : Layout) (who : Who) (x : Val) (p0 b7 b8 b9 : Nat)
    (o : Int) (z : Prop) [Decidable z] (my : Mem)
    (hP : z → P (.access ⟨who, ⟨p0, o⟩, l.stored (.fp .float), true, none, false⟩)) :
    Ext P my (GemvThread.out l who x p0 b7 b8 b9 o z my) := by
  unfold GemvThread.out
  refine (fun m' (h : Ext P my m') => h.trans (ext_of_trace (Mem.foldl_setLive_trace _ _ _))) _ ?_
  by_cases hz : z
  · simp only [hz, ↓reduceIte]
    split
    · rename_i me hme
      exact ⟨[_], by rw [Mem.store_trace hme]; rfl, fun e he => by
        rw [List.mem_singleton] at he
        exact he ▸ hP hz⟩
    · exact ext_of_trace rfl
  · simp only [hz, ↓reduceIte]
    exact ext_of_trace rfl

/-- **An in-range warp's events**: gemv_kernel, for every warp `w` with its premises
(`Lanes.Pre`) whose first thread `k` is its context's thread, a multiple of 32 with row
`k / 32`, and every number `N`: if each lane's run from `%25`'s shuffle to `%78`'s first
(`Lanes.mem2`) extends the trace by events of `Ev`, the warp's run to `mem7 32` does: the
`alloca`s log nothing (`mem0_trace`), the butterfly shuffles change no memory (`mem7 0` is
`mem2 32`), and the last phase logs lane 0's store at row `k / 32` (`ext_out`, `lid_eq`). -/
theorem lanes_ext {bA bV N : Nat} {w : Lanes} (h : w.Pre bA bV)
    (hwk : (w.c w.k).who.thread = w.k) (hk : w.k % 32 = 0) (hr : w.r.val = w.k / 32)
    (h2 : ∀ j < 32, Ext (Ev N w.p0 bA bV w.M) (w.mem2 j) (w.mem2 (j + 1))) :
    Ext (Ev N w.p0 bA bV w.M) w.m (w.mem7 32) := by
  have e0 : Ext (Ev N w.p0 bA bV w.M) w.m (w.mem2 0) := ext_of_trace (mem0_trace w.toAlloc 32)
  have e7 : ∀ j < 32, Ext (Ev N w.p0 bA bV w.M) (w.mem7 j) (w.mem7 (j + 1)) := by
    intro j hj
    refine ext_out gemv.prog.layout _ _ _ _ _ _ _ _ (w.mem7 j) fun hz => ?_
    have hj0 : j = 0 := (Lanes.lid_eq h hj).symm.trans hz
    subst hj0
    have hw : (w.c (w.k + 0)).who.thread = w.k := hwk
    refine ⟨_, rfl, rfl, .inr (.inr ⟨?_, rfl, ?_, ?_, rfl⟩)⟩
    · show (⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ : Ptr) = ⟨w.p0, _⟩
      rw [hw, hr]
    · rw [hw]
      exact hk
    · rw [hw, ← hr]
      exact w.r.isLt
  exact (e0.trans (ext_chain h2 32 le_rfl)).trans (ext_chain e7 32 le_rfl)

/-- **An out-of-range warp's events**: gemv_kernel, for every warp `w` whose row is `M` or more
and every number `N`: if each lane's run from `%25`'s shuffle to its end (`Out.memE`) extends
the trace by events of `Ev`, the warp's run to `memE 32` does (the `alloca`s log nothing,
`mem0_trace`). -/
theorem out_ext {bA bV N : Nat} {w : Out}
    (hE : ∀ j < 32, Ext (Ev N w.p0 bA bV w.M) (w.memE j) (w.memE (j + 1))) :
    Ext (Ev N w.p0 bA bV w.M) w.m (w.memE 32) :=
  (ext_of_trace (mem0_trace w.toAlloc 32)).trans (ext_chain hE 32 le_rfl)

/-- **A slot access is one of `Ev`**, for every memory `m`, thread `who`, step numbers `k₀`,
`k₁`, `k₂`, blocks `p0`, `bA`, `bV`, row count `M` and event: an access of `SlotEv` at the
blocks `m.fresh who.thread kᵢ` is one of `Ev` at `m.next`: its block is from `next` on, and the
`Nat.unpair` of the block minus `next` has the accessing thread first (`Mem.fresh`). -/
theorem slotEv_ev {m : Mem} {who : Who} {k₀ k₁ k₂ p0 bA bV M : Nat} {e : Event}
    (h : GemvEntryRun.SlotEv who (m.fresh who.thread k₀) (m.fresh who.thread k₁)
      (m.fresh who.thread k₂) e) :
    Ev m.next p0 bA bV M e := by
  obtain ⟨a, rfl, hw, hat, hi, hb⟩ := h
  obtain ⟨k, hk⟩ : ∃ k, a.ptr.block = m.fresh who.thread k := by
    rcases hb with hb | hb | hb <;> exact ⟨_, hb⟩
  refine ⟨a, rfl, hat, .inl ⟨?_, ?_, hi⟩⟩
  · rw [hk, Mem.fresh]
    exact Nat.le_add_right _ _
  · rw [hk, Mem.fresh, Nat.add_sub_cancel_left, Nat.unpair_pair, hw]

/-- **The events of a warp whose row is `M` or more**: gemv_kernel, for every warp `w` with its
premises (`Out.Pre`) and lane `j < 32`: lane `j`'s run from `%25`'s shuffle to its end extends
`memE j`'s trace by events of `Ev` at the warp's `next`, its accesses of its own `alloca` slots
(`Out.memE_ext`, `slotEv_ev`). -/
theorem out_events {bA bV : Nat} {w : Out} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    Ext (Ev w.m.next w.p0 bA bV w.M) (w.memE j) (w.memE (j + 1)) :=
  GemvLoop.ext_mono (Out.memE_ext h hj) fun _ he => slotEv_ev (m := w.m)
    (k₀ := (w.t (w.k + j)).k + 0) (k₁ := (w.t (w.k + j)).k + 1) (k₂ := (w.t (w.k + j)).k + 2) he

/-- **The events of a warp whose row is below `M`**: gemv_kernel, for every warp `w` with its
premises (`Lanes.Pre`) and lane `j < 32`: lane `j`'s run from `%25`'s shuffle to `%78`'s first
extends `mem2 j`'s trace by events of `Ev` at the warp's `next`, its accesses of its own `alloca`
slots and its reads of the matrix and the vector (`Lanes.mem2_ext`, `slotEv_ev`). -/
theorem lanes_events {bA bV : Nat} {w : Lanes} (h : w.Pre bA bV) {j : Nat} (hj : j < 32) :
    Ext (Ev w.m.next w.p0 bA bV w.M) (w.mem2 j) (w.mem2 (j + 1)) :=
  GemvLoop.ext_mono (Lanes.mem2_ext h hj) fun _ he => he.elim
    (fun he => slotEv_ev (m := w.m) (k₀ := (w.t (w.k + j)).k + 0)
      (k₁ := (w.t (w.k + j)).k + 1) (k₂ := (w.t (w.k + j)).k + 2) he)
    fun ⟨a, e, hw, hat, hb⟩ => ⟨a, e, hat, .inr (.inl ⟨hw, hb⟩)⟩

/-- The output rows of a memory, for every launch `L`, row count `M` and output block `p0`:
row `i`'s binary32 load at offset `4 i` of `p0` by thread `32 i` of `L`
(`⟨32 i, 32 i / volume L.block⟩`, the `who` the start gives it, `Grid.start_ctx`), for each
`i < M`. It reads only the blocks (`Mem.load_of_block`), and names no start's contexts. -/
def rowsObs (L : Launch) (M p0 : Nat) (m : Mem) : Option (Fin M → Except Fault Val) :=
  some fun i => m.load gemv.prog.layout ⟨32 * i.val, 32 * i.val / volume L.block⟩ 0 (.fp .float)
    ⟨p0, ((i.val * 4 : Nat) : Int)⟩ (some 4)

/-- `grid_rows`' relation of the output rows, for every launch, grid, contexts, sizes, output
block, matrix and vector: each row `i < M` loads as a word that is row `i`'s
`MojoProof.Sem.warpDot true` at the loop oracle numbers of the warp from thread `32 i` up to
NaNs (`NaNEq`). -/
def RowsDot (L : Launch) (g : Grid) (c : Nat → Ctx) (M K p0 : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (f : Fin M → Except Fault Val) :
    Prop :=
  ∀ i : Fin M, ∃ x, f i = .ok (Val.ofFloat .float x) ∧
    NaNEq x (warpDot true (lo (Lanes.ofStart L g c (32 * i.val) M K p0 A v i) i)
      (matVecPairs A v i))

/-- **gemv_kernel's grid runs to a sound end**: gemv_kernel, for every valid launch `L` whose blocks
and grid are one-dimensional (`y` and `z` sizes 1), whose block's `x` size 32 divides and whose
warps' rows cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), argument values `p0`, `bA`,
`bV` (pointers at offset 0), `M`, any `%4` and `K`, caller's memory `m` with no block from `next`
on, address choice below `2 ^ 60` and oracle whose start gives `(g, c)`, with `grid_rows`' bounds
and buffers: the grid's warps have a canonical run (`CanonRun`) to a memory whose trace has no data
race (`GPUProof.racy` at `sig`, under `GPUProof.racy_iff`'s premises) and keeps the promise of
`!invariant.load` (`GPUProof.kept`), and whose output rows (`rowsObs`) meet `grid_rows`' relation
(`RowsDot`). By `Lanes.grid_run_inv` with the invariant "`next` is `g`'s and the trace since the
start is of `Ev`" (`lanes_ext` by `lanes_events`; `out_ext` by `out_events`), `racy_ev`, `kept_ev`
and `rows_of_loads` at the same run's end memory. -/
theorem grid_end {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    ∃ Es m', CanonRun L c (Grid.thread g) (warps L g.threads.size) g.mem Es m' ∧
      ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
      ∃ f, rowsObs L M p0 m' = some f ∧ RowsDot L g c M K p0 A v f := by
  have hv : volume L.block = L.block .x := by simp only [volume, hby, hbz, Nat.mul_one]
  have h32 : 32 ∣ volume L.block := hv ▸ hx
  have hN : g.threads.size = volume L.grid * volume L.block := Grid.start_size hs
  have h32N : 32 ∣ g.threads.size := hN ▸ Nat.dvd_mul_left_of_dvd h32 _
  have hrow : ∀ k ∈ warps L g.threads.size, row (L.env k) = k / 32 := fun k hk =>
    row_eq hL hby hbz hgy hgz (hN ▸ (by have := (warps_mem h32 h32N hk).2.2; omega))
  have hwho : ∀ k, (c k).who.thread = k := fun k => by rw [(Grid.start_ctx hs k).2.1]
  have hfree := Grid.start_free hs gemv_globals hm
  have hnx : ∀ {q : Nat} {x : Sem.Block}, m.blocks q = some x → q < g.mem.next := by
    intro q x hx
    by_contra hq
    have h1 := hfree q (by omega)
    rw [Grid.start_blocks hs hx] at h1
    cases h1
  have hro : ∀ {q size al : Nat}, m.Buffer q size al false → q ≠ p0 := by
    intro q size al hq e
    obtain ⟨x, hx, -, -, -, h1, -⟩ := hq
    obtain ⟨y, hy, -, -, -, h2, -⟩ := hb0
    rw [e, hy] at hx
    cases hx
    rw [h1] at h2
    exact absurd h2 (by decide)
  have hp0 : p0 < g.mem.next := let ⟨_, hx, _⟩ := hb0; hnx hx
  have hA' : bA < g.mem.next := let ⟨_, hx, _⟩ := hbA; hnx hx
  have hV' : bV < g.mem.next := let ⟨_, hx, _⟩ := hbV; hnx hx
  obtain ⟨Es, m', hc, ⟨-, E, hE, hP⟩, hl⟩ := Lanes.grid_run_inv hs ha hL hx hby hbz hgy hgz hch
    hM hK hMK hm hb0 hf0 hbA hbV hfA hfV hA hV
    (fun m₁ => m₁.next = g.mem.next ∧ Ext (Ev g.mem.next p0 bA bV M) g.mem m₁)
    ⟨rfl, ext_of_trace rfl⟩
    (fun k hk r m₁ hr h ⟨hn, hx⟩ => by
      have e : Ext (Ev m₁.next p0 bA bV M) m₁
          ((⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0, A, v, r⟩ : Lanes).mem7 32) :=
        lanes_ext h (hwho k) (warps_mem h32 h32N hk).2.1 (hr.trans (hrow k hk))
          fun _ hj => lanes_events h hj
      rw [hn] at e
      exact ⟨(Lanes.warp_frame h).1.trans hn, hx.trans e⟩)
    (fun k _ m₁ _ h ⟨hn, hx⟩ => by
      have e : Ext (Ev m₁.next p0 bA bV M) m₁
          ((⟨⟨k, c, Grid.thread g, m₁⟩, L, M, K, p0⟩ : Out).memE 32) :=
        out_ext fun _ hj => out_events h hj
      rw [hn] at e
      exact ⟨(Out.warp_frame h).1.trans hn, hx.trans e⟩)
  rw [Grid.start_trace hs, List.append_nil] at hE
  have he : ∀ e ∈ m'.trace, Ev g.mem.next p0 bA bV M e := fun e he => hP e (hE ▸ he)
  refine ⟨Es, m', hc, fun hU hS => racy_ev hp0 hA' hV' (hro hbA) (hro hbV) he hU hS,
    kept_ev hA' hV' (hro hbA) (hro hbV) he, _, rfl, fun i => ?_⟩
  obtain ⟨x, h1, h2⟩ := rows_of_loads hs ha hL hx hby hbz hgy hgz hch hM hK hMK hMx hm hb0 hf0
    hbA hbV hfA hfV hA hV hl i
  rw [(Grid.start_ctx hs _).2.1] at h1
  exact ⟨x, h1, h2⟩

/-- **gemv_kernel's grid is sound**: gemv_kernel, for every valid launch `L` whose blocks and grid
are one-dimensional (`y` and `z` sizes 1), whose block's `x` size 32 divides and whose warps' rows
cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), argument values `p0`, `bA`, `bV`
(pointers at offset 0), `M`, any `%4` and `K`, caller's memory `m` meeting `Mem.BytesIn` with no
block from `next` on, address choice below `2 ^ 60` and oracle whose start gives `(g, c)`, with
`grid_rows`' bounds and buffers: the start's grid is sound (`Grid.Sound`) for the output rows
(`rowsObs`) and `grid_rows`' relation (`RowsDot`). `grid_end`, through `CanonRun.start_sound`. -/
theorem grid_sound {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    (hbi : m.BytesIn m.Known) {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    Grid.Sound L c g (rowsObs L M p0) (RowsDot L g c M K p0 A v) := by
  obtain ⟨_, _, hc, hr, hk, _, hy, hR⟩ := grid_end hs ha hL hx hby hbz hgy hgz hch hM hK hMK
    hMx hm hb0 hf0 hbA hbV hfA hfV hA hV
  exact CanonRun.start_sound hs hbi
    (fun m₁ m₂ hb => congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _))
    hL.volume_pos hc hr hk hy hR

/-- The matrix-vector rule's relation of the output rows, for every sizes `M`, `K`, width `bits`
and input words `I`: the rows load as binary32 words `W i` (`Val.ofFloat`) that meet the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` at size `(M, K)`, encoding
`MojoProof.Tile.matVecEnc FloatTy.float.fmt bits` and inputs `I` (`GPUProof.FloatRule.Holds`). It
names no oracle. -/
def RowsRule {M : Nat} (K bits : Nat)
    (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words)
    (f : Fin M → Except Fault Val) : Prop :=
  ∃ W : Fin M → Model FloatTy.float.fmt, (∀ i, f i = .ok (Val.ofFloat .float (W i))) ∧
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (M, K)
        (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)) I W

/-- **Rows that are their `warpDot`s up to NaNs meet the matrix-vector rule** (test of
gemv_kernel's relation, for every width `bits`, sizes, matrix `A`, vector `v`, input words `I`
that hold them, oracle sequences `o i` of each row and words `W`): if each `W i` is
`MojoProof.Sem.warpDot true (o i)` of row `i`'s pairs up to NaNs (`NaNEq`), `W` meets the rule
of `GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` at `I`. A NaN pair
decodes alike (`GPUProof.ScalarEnc.decode_eq`), and `MojoProof.Tile.groupDot_approx` grades
each row (`MojoProof.Tile.holds_of`), whatever its oracle. -/
theorem rows_holds (bits : Nat) {M K : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words}
    (hA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 A i j)
    (hv : ∀ j, I (.inr j) = v.getScalar j) (o : Fin M → Nat → Nat → Nat × Nat)
    (W : Fin M → Model FloatTy.float.fmt)
    (h : ∀ i, NaNEq (W i) (warpDot true (o i) (matVecPairs A v i))) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (M, K)
        (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)) I W :=
  MojoProof.Tile.holds_of bits (2 ^ 5) 5 _ fun i a x ga gx ha hx => by
    have e : matVecPairs A v i = List.ofFn fun j => (I (.inl (i, j)), I (.inr j)) := by
      simp only [matVecPairs, hA, hv]
    have hd : Model.toReal? (W i) = Model.toReal? (warpDot true (o i) (matVecPairs A v i)) :=
      GPUProof.ScalarEnc.decode_eq (e := GPUProof.ScalarEnc.ieee FloatTy.float.fmt) (h i)
    rw [hd, e]
    exact MojoProof.Tile.groupDot_approx rfl 5 true (o i) (fun j => I (.inl (i, j)))
      (fun j => I (.inr j)) a x ga gx ha hx

unseal Array.anyM.loop in
/-- **gemv_kernel's launch starts** (test of gemv_kernel, for every launch, argument values
`p0`, `bA`, `bV` (pointers at offset 0), `M`, a word `%4` and `K`, memory closed for them,
address choice and oracle): `Grid.start` gives a grid and contexts (`Sym.Grid.start_ok`: gemv
has no globals, `gemv_globals`, no `byval` parameter, and its `noundef` parameters accept the
arguments, by evaluation). -/
theorem starts (L : Launch) {m : Mem} {p0 bA bV M K : Nat} {x4 : BitVec 32}
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M),
      .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)]) (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start gemv.prog gemv.fn_0 L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩,
      .bits 32 (BitVec.ofNat 32 M), .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)] m ch oracle =
        .ok (g, c) := by
  refine Sym.Grid.start_ok ch oracle rfl hC gemv_globals (fun p v hpv t ht => ?_)
    (fun p v hpv hnb m' => ?_) (of_decide_eq_true (by kernel_rfl))
  all_goals
    simp only [gemv.fn_0, List.zip_cons_cons, List.zip_nil_right, List.mem_cons, Prod.mk.injEq,
      List.not_mem_nil] at hpv
    repeat' rcases hpv with ⟨hp, hv⟩ | hpv
  all_goals subst_vars
  all_goals first | exact ⟨_, rfl⟩ | simp at ht

/-- **gemv_kernel is sound against the matrix-vector spec**: gemv_kernel, for every valid launch `L`
whose blocks and grid are one-dimensional (`y` and `z` sizes 1), whose block's `x` size 32 divides
and whose warps' rows cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), argument values
`p0`, `bA`, `bV` (pointers at offset 0), `M`, a word `%4` and `K`, caller's memory `m` closed for
them (`Mem.Closed`) with `grid_rows`' bounds and buffers holding `A` and `v`, width `bits` and input
words `I` that hold `A` and `v`: the kernel is sound at `sig` (`GPUProof.Kernel.Sound`) for the
admission "address choice below `2 ^ 60`", the output rows (`rowsObs`) and the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` (`RowsRule`). At each admitted
choice the launch starts (`starts`), `grid_end` gives the run, `CanonRun.start_done` its done grid,
not bad by `Grid.Done.bad_iff`, and Theorem 0 at `sig` (`MojoProofTest.Theorem0.sound_sig`, by
`GPUProof.Sound.of_one_run`) the soundness; the rows' relation by `rows_holds`. -/
theorem kernel_sound {L : Launch} {m : Mem} {M K p0 bA bV : Nat} {x4 : BitVec 32}
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M),
      .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v)
    (bits : Nat) (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words)
    (hIA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 A i j)
    (hIv : ∀ j, I (.inr j) = v.getScalar j) :
    GPUProof.Kernel.Sound sig (gemv.prog, gemv.fn_0) L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩,
      .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)] m
      (fun ω => ∀ q, ω.1 q < 2 ^ 60) (fun b => rowsObs L M p0 { blocks := b })
      (RowsRule K bits I) := by
  rintro ⟨ch, oracle⟩ hch
  obtain ⟨g, c, hs⟩ := starts L hC ch oracle
  obtain ⟨_, _, hc, hr, hk, f, hy, hR⟩ := grid_end hs rfl hL hx hby hbz hgy hgz hch hM hK hMK hMx
    hC.above hb0 hf0 hbA hbV hfA hfV hA hV
  obtain ⟨z, ⟨_, hp⟩, hd, rfl⟩ := CanonRun.start_done hs hL.volume_pos hc
  have hreach := GPUProof.Path.exists_iff.1 ⟨_, hp⟩
  have hfits := Grid.start_reach_fits hs hreach
  have hb : ¬ GPUProof.Bad sig (z, L, c) := fun hb =>
    ((Grid.Done.bad_iff (Grid.start_reach_size hs hreach).le hd).1 hb).elim
      (fun h' => Bool.false_ne_true ((hr hfits.trace hfits.2).symm.trans h'))
      fun h' => Bool.false_ne_true (h'.symm.trans hk)
  refine ⟨(g, L, c), ?_, MojoProofTest.Theorem0.sound_sig hs hC.bytesIn
    (fun m₁ m₂ hb => congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _))
    hp hd hb hy ⟨fun i => (hR i).choose, fun i => (hR i).choose_spec.1,
      rows_holds bits hIA hIv _ _ fun i => (hR i).choose_spec.2⟩⟩
  show (Grid.start gemv.prog gemv.fn_0 L _ m ch oracle).map _ = _
  rw [hs]
  rfl

/-- `GemvThread.m3` has no pointer byte: the matrix's and the vector's bytes are binary32 words
(`tensorBytes_namesIn`), and the output starts with none (`Mem.alloc_bytesIn`). -/
theorem m3_bytesIn : GemvThread.m3.BytesIn GemvThread.m3.Known := by
  have h0 : ({} : Mem).BytesIn GemvThread.m3.Known := fun _ _ _ _ _ h => by cases h
  have hT : ∀ {s : TorchLean.Shape} (x : TorchLean.Tensor (Model FloatTy.float.fmt) s) p j,
      MemByte.ptr p j ∈ tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) x →
        GemvThread.m3.Known p.block := fun x p j h =>
    (tensorBytes_namesIn (S := fun _ => False)
      (fun _ => by simp [Val.NamesIn, Val.ofFloat]) x p j h).elim
  exact Mem.alloc_bytesIn (Mem.alloc_bytesIn (Mem.alloc_bytesIn h0 (hT _) _ _ _ _ _ _ _ _ _ _)
    (hT _) _ _ _ _ _ _ _ _ _ _) (init := []) (fun _ _ h => by cases h) _ _ _ _ _ _ _ _ _ _

/-- Test: `grid_sound` at one block of 32 threads (`launch2 1 1 32 1`), `M = 1`, `K = 4`, the output
at block 3, the matrix `GemvThread.A3` and vector `GemvThread.v3` at blocks 1 and 2 of
`GemvThread.m3` (no pointer byte, `m3_bytesIn`), any `%4` and every address choice below `2 ^ 60`
and oracle whose start gives `(g, c)`: the start's grid is sound for row 0 of the output and its
row's `warpDot` up to NaNs. -/
example {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat} {g : Grid}
    {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 32 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 1), x4, .bits 32 (BitVec.ofNat 32 4)]
        GemvThread.m3 ch oracle = .ok (g, c)) :
    Grid.Sound (launch2 1 1 32 1) c g (rowsObs (launch2 1 1 32 1) 1 3)
      (RowsDot (launch2 1 1 32 1) g c 1 4 3 GemvThread.A3 GemvThread.v3) :=
  grid_sound hs m3_bytesIn rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl rfl hch
    (by decide) (by decide) (by decide) (by decide) m3_free w0_pre.hb0 w0_pre.hf0 w0_pre.hbA
    w0_pre.hbV w0_pre.hfA w0_pre.hfV w0_pre.hA w0_pre.hV

/-- **Two warps of one row at a two-dimensional block** (test of gemv_kernel's row, at one block of
32 × 2 threads, `launch2 1 1 32 2`, the output at block 3): threads 0 and 32, the first threads of
its two warps, both have row 0 (`row`: gemv IR lines 13-21 read only `.x` registers), and lane 0's
stores at row 0 (IR line 136: 4 bytes at offset `4 · row` of the output) by the two of them make a
racy trace (`GPUProof.racy` at `sig`, by evaluation), while thread 32's store at row 1 (offset 4),
its row at one block of 64 threads, would not. No theorem states that a run of gemv_kernel at this
launch reaches both stores; `grid_end`'s `y = z = 1` premises exclude the launch. -/
theorem row_race : row ((launch2 1 1 32 2).env 0) = 0 ∧ row ((launch2 1 1 32 2).env 32) = 0 ∧
    GPUProof.racy sig ([Event.access ⟨⟨32, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩,
      .access ⟨⟨0, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩].map
        (Event.toCore (launch2 1 1 32 2))).reverse = true ∧
    GPUProof.racy sig ([Event.access ⟨⟨32, 0⟩, ⟨3, 4⟩, 4, true, none, false⟩,
      .access ⟨⟨0, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩].map
        (Event.toCore (launch2 1 1 32 2))).reverse = false := by
  decide +kernel

end MojoProofTest.GemvSound
