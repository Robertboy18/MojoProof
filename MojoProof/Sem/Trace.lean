import GPUProof.Sound
import MojoProof.Sem.RaceSig
import MojoProof.Sem.Buffer

/-!
# Traces and grids through the one-run theorem

Proved for every launch and trace, with a race the core's `racy` at `sig` and the promise of
`!invariant.load` the core's `GPUProof.kept` at `sig`, both of the trace's core events, oldest
first; the theorems about races are for every trace whose accesses are by threads of the launch
in their blocks of threads and that is shaped (the premises of `racy_iff`,
MojoProof/Sem/RaceSig.lean):

* a trace that breaks the promise of `!invariant.load` stays broken when an event is added
  (`kept_cons`; a racy trace stays racy, `racy_cons`, and the kinds and overlap lemmas below are
  in MojoProof/Sem/RaceSig.lean); the core's `kept` at `sig` is a property of
  the set of events: no access that writes for the core (`GPUProof.Kind.writes`: a write or an
  `atomicrmw`'s read, `Access.kind_writes`) overlaps a frozen read (an `!invariant.load` that
  neither writes nor is atomic, `Access.kind_frozen`) of the trace (`kept_sig_iff`, `kept_perm`;
  overlap is a common byte, `Access.overlaps_iff_bytes`); loads with `!invariant.load` outside a
  set of blocks that holds the accesses that write for the core keep it (`kept_of_split`);
* ownership gives race freedom: if each access lies in its thread's tile of a `Tiling` of its
  block, or reads a block nobody writes (`Owned`), and threads that share a tiled block have
  different tiles, the trace has no race, whatever its barriers (`racy_eq_false_of_owned`).
  The tiling and the tiles may change at each barrier of a block of threads
  (`racy_eq_false_of_phased`, with the phases of MojoProof/Sem/Race.lean): the per-phase
  discipline must agree across blocks of threads on each block, and two accesses with one tile
  that no barrier orders must be by one thread; `racy_eq_false_of_owned` is its instance with one
  discipline for every phase. Instance: MojoProofTest/Phased.lean, a trace that only the per-phase
  form covers (`not_owned`).
  Both come from the writer form (`racy_eq_false_of_writers`): a map from each phase, block and
  byte to the tile of the thread that may write it, or `none`; if every access, at each of its
  bytes, is by that byte's writer or is a read of a byte with no writer, the writers agree across
  blocks of threads, and two accesses with one writer that no barrier orders are by one thread, the
  trace has no race. A thread may read bytes outside its own tile, which the halving tree of a
  reduction needs (`racy_halving`, MojoProof/Sem/Shared.lean). For the phased form the writer of a
  byte is the tile that holds it (`Tiling.at`, `Owned.at`).
  Offsets that are apart and in bounds are a tiling (`Tiling.ofApart`), so the row-major tiles
  of an output tensor (MojoProof/Sem/Buffer.lean) are one. Instance: the strided tiling of a
  buffer of `n` elements of `w` bytes (`Tiling.strided`, by `apart_stride`).
  The trace lemma of an elementwise kernel (`racy_kept_of_cells`): if every access
  to an output block lies in its thread's cell, the cells being `w` bytes apart (`Apart`), every
  access to another block is a read that is not an `atomicrmw`'s, and no access with
  `!invariant.load` is to the output block, the trace keeps `!invariant.load` and, under the
  premises of `racy_iff`, has no race.
  Its case of cells `k * w`: a trace whose writes are thread `k`'s element `k` of one buffer and
  whose other accesses are reads of other blocks (`racy_kept_pointwise`). Statements about
  traces, not about a kernel; instances in MojoProofTest/ScheduleOwned.lean.

Proved for every program, launch and observation:

* `Grid.sound_of_one_run`: all seven fields of `Grid.Sound` from one run of a step relation on
  any state type that projects onto `Grid.Step` and lifts its steps, when that relation is
  `Confluent` (GPUProof/OneRun.lean) up to an equivalence that preserves the core's `Done` at
  `sig` and the observation, with faults, racy traces and broken `!invariant.load` promises bad,
  done grids without a step, and the run ends in a state whose grid is done, is not bad and has
  an observation that satisfies `R`. It is the core's one-run theorem `GPUProof.Clean.of_lift`
  at `sig`, observing the grid's memory, along `x ↦ (π x, L, c)` (`sig_step_iff`), carried back
  to the grid by `Grid.Sound.of_clean`.
  The confluence is a hypothesis; no kernel's is proved here. The proof is in
  docs/proofs/adapter.md.

Instances on the real `Grid.Step`:

* `Grid.sound_commuting`: a grid of `N` threads that each return in one step with a change of
  memory `f n`, where the changes of two threads commute and keep the trace, from every memory with
  a property `P` that the changes keep, is sound for every observation and relation its value
  after all the changes satisfies, when the start's trace has no race and keeps
  `!invariant.load`, for every `N`, launch of at least `N` threads, contexts, threads and memory;
* `Grid.sound_returning`: its case of threads that each return in one step without changing
  memory, whose trace has no race and keeps `!invariant.load`, is sound for every observation
  defined on that memory and relation its value satisfies, for every `N` and launch of at least
  `N` threads (the states are the sets of returned threads; the diamond holds for every pair of
  threads);
* `Kernel.sound_ret_launch`: the kernel `define void @k() { ret void }` is sound on every launch,
  for every closed memory (`Mem.Closed`), address choice and oracle.
-/

namespace MojoProof.Sem

open LLVM Relation
open GPUProof

section Trace

/-- **The core's `kept` at `sig` by members**, for every launch `L` and trace `tr` (newest
first): the core's `kept` of its core events, oldest first, holds exactly when no access of `tr`
that writes for the core (`Kind.writes`: a write or an `atomicrmw`'s read) overlaps a frozen read
of `tr` (`Access.kind_frozen`: a load with `!invariant.load`), before or after it. -/
theorem kept_sig_iff {L : Launch} {tr : List Event} :
    GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true ↔
      ∀ w a, Event.access w ∈ tr → Event.access a ∈ tr → w.kind.writes = true →
        a.kind = .frozen → a.overlaps w = false := by
  rw [GPUProof.kept_iff]
  simp only [GPUProof.Kept, List.mem_reverse, List.mem_map]
  constructor
  · intro h w a hw ha hww haf
    rw [Bool.eq_false_iff]
    intro ho
    obtain ⟨l, hl, hl'⟩ := Access.overlaps_iff_bytes.1 ho
    exact h w.toCore a.toCore ⟨_, hw, rfl⟩ ⟨_, ha, rfl⟩ hww haf l hl hl'
  · rintro h _ _ ⟨⟨w⟩ | ⟨⟩, hw, ⟨⟩⟩ ⟨⟨a⟩ | ⟨⟩, ha, ⟨⟩⟩ hww haf l hl hl'
    have := h w a hw ha hww haf
    rw [Bool.eq_false_iff] at this
    exact this (Access.overlaps_iff_bytes.2 ⟨l, hl, hl'⟩)

/-- A trace that breaks the promise of `!invariant.load` (the core's `kept` at `sig`) breaks it
when an event is added, for every launch, event and trace. -/
theorem kept_cons {L : Launch} (e : Event) {tr : List Event}
    (h : GPUProof.kept sig (tr.map (Event.toCore L)).reverse = false) :
    GPUProof.kept sig ((e :: tr).map (Event.toCore L)).reverse = false := by
  cases hk : GPUProof.kept sig ((e :: tr).map (Event.toCore L)).reverse with
  | false => rfl
  | true =>
    have : GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true :=
      kept_sig_iff.2 fun w a hw ha hww haf =>
        kept_sig_iff.1 hk w a (List.mem_cons_of_mem _ hw) (List.mem_cons_of_mem _ ha) hww haf
    rw [this] at h
    cases h

/-- The core's `kept` at `sig` does not depend on the order of the trace, for every launch and
pair of traces. -/
theorem kept_perm {L : Launch} {tr tr' : List Event} (h : tr.Perm tr') :
    GPUProof.kept sig (tr.map (Event.toCore L)).reverse =
      GPUProof.kept sig (tr'.map (Event.toCore L)).reverse := by
  rw [Bool.eq_iff_iff, kept_sig_iff, kept_sig_iff]
  constructor
  · intro k w a hw ha hww haf
    exact k w a (h.mem_iff.2 hw) (h.mem_iff.2 ha) hww haf
  · intro k w a hw ha hww haf
    exact k w a (h.mem_iff.1 hw) (h.mem_iff.1 ha) hww haf

/-- If loads with `!invariant.load` stay outside a set `W` of blocks and the accesses that write
for the core (`Kind.writes`: writes and `atomicrmw`s' reads) stay inside it, the trace keeps the
promise (the core's `kept` at `sig`), for every launch, set of blocks and trace. -/
theorem kept_of_split {L : Launch} {W : Nat → Prop} {tr : List Event}
    (hi : ∀ a, Event.access a ∈ tr → a.invariant = true → ¬ W a.ptr.block)
    (hw : ∀ e, Event.access e ∈ tr → e.kind.writes = true → W e.ptr.block) :
    GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true :=
  kept_sig_iff.2 fun e a he ha hwe haf => by
    have hb : a.ptr.block ≠ e.ptr.block := fun hb =>
      hi a ha ((Access.kind_frozen a).1 haf).2.2 (hb ▸ hw e he hwe)
    simp [Access.overlaps, hb]

/-- A family of byte intervals inside an extent: in bounds and pairwise disjoint. -/
structure Tiling (ι : Type) where
  /-- Builds a tiling from its offsets, lengths, extent and the two proofs. -/
  mk ::
  /-- The first byte of each interval. -/
  off : ι → Nat
  /-- The length of each interval. -/
  len : ι → Nat
  /-- The extent. -/
  ext : Nat
  /-- Every interval ends by the extent. -/
  inb : ∀ i, off i + len i ≤ ext
  /-- Two different intervals do not overlap. -/
  disj : ∀ i j, i ≠ j → off i + len i ≤ off j ∨ off j + len j ≤ off i

/-- Offsets `n` bytes apart (`Apart`, MojoProof/Sem/Buffer.lean) whose intervals of `n` bytes end
by `ext` are a tiling. With `rowMajor`, `apart_rowMajor` and `rowMajor_inb` it is the tiling of an
output tensor's elements that `Owned` takes. -/
def Tiling.ofApart {ι : Type} (off : ι → Nat) (n ext : Nat) (hap : Apart off n)
    (hin : ∀ i, off i + n ≤ ext) : Tiling ι where
  off := off
  len _ := n
  ext := ext
  inb := hin
  disj := hap

/-- `n` intervals of `w` bytes at stride `w` from `base`: the elements of a contiguous buffer. -/
def Tiling.strided (base n w : Nat) : Tiling (Fin n) :=
  .ofApart (fun i => base + i * w) w (base + n * w)
    ((apart_stride base le_rfl).comp Fin.val_injective) fun i => by
      have := stride_lt w i.2
      omega

/-- Access `a` follows the ownership discipline `(T, own)`: `T` gives the tiling of each block
that is written (`none`: a block nobody writes), `own` the tile of each thread. An access to a
tiled block lies in its thread's tile, read or write; an access to an untiled block is a read. -/
structure Owned {ι : Type} (T : Nat → Option (Tiling ι)) (own : Nat → ι) (a : Access) : Prop where
  /-- Builds `Owned` from its two fields. -/
  mk ::
  /-- An access to an untiled block is a read. -/
  read : T a.ptr.block = none → a.write = false
  /-- An access to a tiled block lies in its thread's tile. -/
  tile : ∀ t, T a.ptr.block = some t →
    (t.off (own a.who.thread) : Int) ≤ a.ptr.off ∧
      a.ptr.off + a.len ≤ t.off (own a.who.thread) + t.len (own a.who.thread)

/-- Two accesses that follow the discipline, by threads with different tiles, that overlap are
reads: at an untiled block both are (`Owned.read`), and at a tiled one they lie in different tiles,
which are disjoint (`Tiling.disj`), so they do not overlap. -/
theorem Owned.apart {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι} {a e : Access}
    (ha : Owned T own a) (he : Owned T own e)
    (hne : a.ptr.block = e.ptr.block → T a.ptr.block ≠ none →
      own a.who.thread ≠ own e.who.thread) (ho : a.overlaps e = true) :
    a.write = false ∧ e.write = false := by
  simp only [Access.overlaps, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at ho
  obtain ⟨⟨⟨⟨hb, -⟩, -⟩, o1⟩, o2⟩ := ho
  cases hT : T a.ptr.block with
  | none => exact ⟨ha.read hT, he.read (hb ▸ hT)⟩
  | some t =>
    obtain ⟨a1, a2⟩ := ha.tile t hT
    obtain ⟨e1, e2⟩ := he.tile t (by rw [← hb]; exact hT)
    rcases t.disj _ _ (hne hb (by simp [hT])) with h | h <;> omega

/-- `Owned` reads the tiling only at the access's block and the tile map only at its thread. -/
theorem Owned.congr {ι : Type} {T T' : Nat → Option (Tiling ι)} {own own' : Nat → ι} {a : Access}
    (hT : T a.ptr.block = T' a.ptr.block) (ho : own a.who.thread = own' a.who.thread)
    (h : Owned T own a) : Owned T' own' a :=
  ⟨fun h' => h.read (hT.trans h'), fun t ht => by rw [← ho]; exact h.tile t (hT.trans ht)⟩

/-- The tile of `t` that holds byte `i`, if one does: at most one does, as the tiles are disjoint
(`Tiling.at_eq`). -/
noncomputable def Tiling.at {ι : Type} (t : Tiling ι) (i : Int) : Option ι :=
  open Classical in
  if h : ∃ j, (t.off j : Int) ≤ i ∧ i < t.off j + t.len j then some h.choose else none

/-- A byte of tile `j` is in tile `j` only, for every tiling, tile and byte. -/
theorem Tiling.at_eq {ι : Type} {t : Tiling ι} {j : ι} {i : Int} (h1 : (t.off j : Int) ≤ i)
    (h2 : i < t.off j + t.len j) : t.at i = some j := by
  unfold Tiling.at
  split
  · rename_i h
    obtain ⟨c1, c2⟩ := h.choose_spec
    by_contra hne
    rcases t.disj _ _ (fun e => hne (congrArg some e)) with h' | h' <;> omega
  · rename_i h
    exact absurd ⟨j, h1, h2⟩ h

/-- An access that follows the discipline `(T, own)`, at each of its bytes `i`: the tile of
`T` that holds `i` is its thread's, or the access is a read of an untiled block. For every
discipline, access and byte. -/
theorem Owned.at {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι} {a : Access}
    (h : Owned T own a) {i : Int} (h1 : a.ptr.off ≤ i) (h2 : i < a.ptr.off + a.len) :
    (T a.ptr.block).bind (·.at i) = some (own a.who.thread) ∨
      (a.write = false ∧ (T a.ptr.block).bind (·.at i) = none) := by
  cases hT : T a.ptr.block with
  | none => exact .inr ⟨h.read hT, rfl⟩
  | some t =>
    obtain ⟨t1, t2⟩ := h.tile t hT
    exact .inl (Tiling.at_eq (by omega) (by omega))

/-- **One writer per byte and barrier interval gives race freedom** (the core's `racy` at `sig`,
for every launch and trace with the premises of `racy_iff`). `W p b i` is the writer of byte `i`
of block `b` in phase `p` (`phases`), a tile of type `ι` or `none` for a byte nobody writes in
that phase, and `own p` maps each thread to its tile. If at each of its
bytes every access is by the byte's writer, or is a read of a byte with no writer, accesses of one
block by two blocks of threads see one writer map of it, and two accesses of a block with a
writer, with one tile, by different blocks of threads or in one phase, are by one thread, the
trace has no race. Unlike `racy_eq_false_of_phased`, a thread may read bytes outside its tile.
-/
theorem racy_eq_false_of_writers {ι : Type} {W : Nat → Nat → Int → Option ι}
    {own : Nat → Nat → ι} {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hW : ∀ x ∈ (phases tr).1, ∀ i : Int, x.1.ptr.off ≤ i → i < x.1.ptr.off + x.1.len →
      W x.2 x.1.ptr.block i = some (own x.2 x.1.who.thread) ∨
        (x.1.write = false ∧ W x.2 x.1.ptr.block i = none))
    (hG : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.who.cta ≠ y.1.who.cta →
      x.1.ptr.block = y.1.ptr.block → W x.2 x.1.ptr.block = W y.2 x.1.ptr.block)
    (hX : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.ptr.block = y.1.ptr.block →
      (∃ i, W x.2 x.1.ptr.block i ≠ none) → (x.1.who.cta ≠ y.1.who.cta ∨ x.2 = y.2) →
      own x.2 x.1.who.thread = own y.2 y.1.who.thread → x.1.who.thread = y.1.who.thread) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := by
  cases h : GPUProof.racy sig (tr.map (Event.toCore L)).reverse
  · rfl
  obtain ⟨x, hx, y, hy, hc⟩ := (racy_iff hU hs).1 h
  simp only [clash, Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.or_eq_true, beq_iff_eq] at hc
  obtain ⟨⟨ht, hc⟩, hk⟩ := hc
  simp only [Access.conflict, Access.overlaps, Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq,
    decide_eq_true_eq] at hc
  obtain ⟨⟨⟨⟨⟨⟨hb, h0x⟩, h0y⟩, h1⟩, h2⟩, hw⟩, -⟩ := hc
  have hτ : W x.2 x.1.ptr.block = W y.2 x.1.ptr.block := by
    rcases hk with hk | hk
    · exact hG x hx y hy hk hb
    · rw [hk]
  have hx' := hW x hx (max x.1.ptr.off y.1.ptr.off) (le_max_left _ _) (by omega)
  have hy' := hW y hy (max x.1.ptr.off y.1.ptr.off) (le_max_right _ _) (by omega)
  rw [← hb, ← hτ] at hy'
  rcases hx' with hx' | ⟨wx, hx'⟩ <;> rcases hy' with hy' | ⟨wy, hy'⟩
  · exact (ht (hX x hx y hy hb ⟨_, by rw [hx']; simp⟩ hk
      (Option.some.inj (hx'.symm.trans hy')))).elim
  · simp [hx'] at hy'
  · simp [hx'] at hy'
  · simp [wx, wy] at hw

/-- **Ownership per barrier interval gives race freedom** (the core's `racy` at `sig`, for every
launch and trace with the premises of `racy_iff`). The tiling
`T p` and the tile map `own p` may change with the phase `p` (`phases`). If every access follows
the discipline of its phase, accesses of one block by two blocks of threads see one tiling of it,
and two accesses of a tiled block with one tile, by different blocks of threads or in one phase,
are by one thread, the trace has no race. `racy_eq_false_of_writers` with the writer of a byte the
tile of `T p` that holds it (`Owned.at`). -/
theorem racy_eq_false_of_phased {ι : Type} {T : Nat → Nat → Option (Tiling ι)}
    {own : Nat → Nat → ι} {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse)
    (hO : ∀ x ∈ (phases tr).1, Owned (T x.2) (own x.2) x.1)
    (hG : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.who.cta ≠ y.1.who.cta →
      x.1.ptr.block = y.1.ptr.block → T x.2 x.1.ptr.block = T y.2 x.1.ptr.block)
    (hX : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.ptr.block = y.1.ptr.block →
      T x.2 x.1.ptr.block ≠ none → (x.1.who.cta ≠ y.1.who.cta ∨ x.2 = y.2) →
      own x.2 x.1.who.thread = own y.2 y.1.who.thread → x.1.who.thread = y.1.who.thread) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false :=
  racy_eq_false_of_writers (W := fun p b i => (T p b).bind (·.at i)) (own := own) hU hs
    (fun x hx _ h1 h2 => (hO x hx).at h1 h2)
    (fun x hx y hy hc hb => by simp only [hG x hx y hy hc hb])
    fun x hx y hy hb ⟨_, hi⟩ hk ho => hX x hx y hy hb (fun hT => hi (by simp [hT])) hk ho

/-- **Ownership gives race freedom** (the core's `racy` at `sig`, for every launch and trace with
the premises of `racy_iff`). If every access of a trace
follows the discipline `(T, own)`, and threads that access one tiled block have different tiles,
the trace has no race, whatever its barriers. The discipline of `racy_eq_false_of_phased` that
does not depend on the phase. -/
theorem racy_eq_false_of_owned {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {L : Launch} {tr : List Event}
    (hU : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) (hs : Trace.Shaped tr.reverse) :
    (∀ a, Event.access a ∈ tr → Owned T own a) →
      (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
        T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
          a.who.thread = e.who.thread) →
            GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false := fun h hi =>
  racy_eq_false_of_phased (T := fun _ => T) (own := fun _ => own) hU hs
    (fun _ hx => h _ (mem_phases hx))
    (fun _ _ _ _ _ _ => rfl) fun _ hx _ hy hb hT _ ho =>
      hi _ _ (mem_phases hx) (mem_phases hy) hb hT ho

/-- **The trace lemma of an elementwise kernel** (every trace, output block `out`, width `w` and
cell map `cell` whose cells are `w` bytes apart, `Apart`): if every access of the trace to `out`
lies in its thread's cell, the `w` bytes from `cell` of its thread number, every access to another
block is a read that is not an `atomicrmw`'s, and no access with `!invariant.load` is to `out`,
the trace keeps the promise of `!invariant.load` (the core's `kept` at `sig`, for every launch),
and under the premises of `racy_iff` it is not racy. `racy_kept_pointwise` is its case of cells
`k * w`, each access the whole cell. -/
theorem racy_kept_of_cells {L : Launch} {tr : List Event} {out w : Nat} {cell : Nat → Nat}
    (hap : Apart cell w)
    (hc : ∀ a, Event.access a ∈ tr → a.ptr.block = out →
      (cell a.who.thread : Int) ≤ a.ptr.off ∧ a.ptr.off + a.len ≤ cell a.who.thread + w)
    (hr : ∀ a, Event.access a ∈ tr → a.ptr.block ≠ out → a.write = false ∧ a.atomic = none)
    (hi : ∀ a, Event.access a ∈ tr → a.invariant = true → a.ptr.block ≠ out) :
    ((∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped tr.reverse →
      GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true := by
  refine ⟨fun hU hs => ?_, kept_of_split (W := (· = out)) hi fun e he hw => ?_⟩
  · cases h : GPUProof.racy sig (tr.map (Event.toCore L)).reverse
    · rfl
    obtain ⟨x, hx, y, hy, hc'⟩ := (racy_iff hU hs).1 h
    simp only [clash, Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.or_eq_true, beq_iff_eq] at hc'
    obtain ⟨⟨ht, hc'⟩, -⟩ := hc'
    have hx' := mem_phases hx
    have hy' := mem_phases hy
    simp only [Access.conflict, Access.overlaps, Bool.and_eq_true, beq_iff_eq,
      decide_eq_true_eq, Bool.or_eq_true] at hc'
    obtain ⟨⟨⟨⟨⟨⟨hb, -⟩, -⟩, o1⟩, o2⟩, hw⟩, -⟩ := hc'
    by_cases ho : x.1.ptr.block = out
    · obtain ⟨a1, a2⟩ := hc _ hx' ho
      obtain ⟨e1, e2⟩ := hc _ hy' (hb ▸ ho)
      rcases hap _ _ ht with h | h <;> omega
    · rcases hw with hw | hw
      · simp [(hr _ hx' ho).1] at hw
      · simp [(hr _ hy' (hb ▸ ho)).1] at hw
  · by_contra hb
    obtain ⟨h1, h2⟩ := hr e he hb
    simp [Access.kind_writes, h1, h2] at hw

/-- Instance, for every launch, trace, element count `n` and element width `w`: if every access
is a read, not an `atomicrmw`'s, of a block other than `out`, or an access without
`!invariant.load` by a thread `k < n` to exactly the bytes `[k * w, k * w + w)` of `out`, the
trace keeps the promise of `!invariant.load` (the core's `kept` at `sig`) and under the premises
of `racy_iff` has no race. This is
the access pattern of a pointwise kernel with one element per thread; it is a statement about
traces, not about a kernel. `racy_kept_of_cells` with the cells `k * w` (`apart_stride`). -/
theorem racy_kept_pointwise {L : Launch} {out n w : Nat} {tr : List Event}
    (h : ∀ a, Event.access a ∈ tr → (a.ptr.block ≠ out ∧ a.write = false ∧ a.atomic = none) ∨
      (a.ptr.block = out ∧ a.invariant = false ∧ a.who.thread < n ∧
        a.ptr.off = ((a.who.thread * w : Nat) : Int) ∧ a.len = w)) :
    ((∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped tr.reverse →
      GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (tr.map (Event.toCore L)).reverse = true :=
  racy_kept_of_cells (out := out) (cell := (· * w))
    (by simpa using apart_stride 0 (le_refl w))
    (fun a ha hb => by
      rcases h a ha with ⟨hb', -⟩ | ⟨-, -, -, ho, hl⟩
      · exact absurd hb hb'
      · rw [ho, hl]
        exact ⟨le_rfl, le_rfl⟩)
    (fun a ha hb => by
      rcases h a ha with ⟨-, hw⟩ | ⟨hb', -⟩
      · exact hw
      · exact absurd hb' hb)
    fun a ha hi => by
      rcases h a ha with ⟨hb, -⟩ | ⟨-, hi', -⟩
      · exact hb
      · rw [hi'] at hi
        cases hi

end Trace

section Grid

variable {L : Launch} {c : Nat → Ctx}

/-- One thread whose step returns: every step of its grid is that return. -/
theorem Grid.step_one {t : Thread} {M M' : Mem} (h : step (c 0) t M = .ok (.done M')) {g' : Grid}
    (hs : Grid.Step L c ⟨#[.run t], M⟩ g') : g' = ⟨#[.done], M'⟩ := by
  obtain ⟨n, hs | hs⟩ := hs
  · cases n with
    | zero =>
      simp only [Grid.advance, List.getElem?_toArray, List.getElem?_cons_zero, h, bind, Except.bind,
        pure, Except.pure, Except.ok.injEq, Option.some.injEq] at hs
      rw [← hs]
      rfl
    | succ n => simp [Grid.advance, pure, Except.pure] at hs
  · cases n <;> simp [Grid.fire, pure, Except.pure] at hs

/-- A done grid with at most the launch's number of threads does not fault. -/
theorem done_not_faults {g : Grid} (hs : g.threads.size ≤ volume L.grid * volume L.block)
    (h : GPUProof.Done sig (g, L, c)) : ¬ GPUProof.Faults sig (g, L, c) := by
  intro hf
  obtain ⟨n, e, hf⟩ := Grid.faults_iff.1 hf
  rcases Grid.Done.get hs h n with hn | hn <;>
    simp [Grid.advance, Grid.fire, hn, pure, Except.pure] at hf

/-- **`Grid.Sound` from one run** (all seven fields of `Grid.Sound`). `rc` is a step
relation on states `γ` (for example the grids reachable from the start, or grids with extra
ghost state) that projects onto `Grid.Step` and lifts every grid step. If `rc` is confluent up to
`e` with `Bad` persistent; faults, racy traces and traces that break `!invariant.load` are bad;
a state whose grid is done (the core's `Done` at `sig`) has no step; and `e` preserves `Done` and
the observation; then one run of `rc` from `x₀` to a state whose grid is done, is not bad and
observes `y` with `R y` makes the grid of `x₀` sound. It is `GPUProof.Clean.of_lift` at `sig`
along `x ↦ (π x, L, c)`, whose steps are `rc`'s by `sig_step_iff`, for the observation
`obs` of the grid's memory, carried back to the grid by `Grid.Sound.of_clean`. -/
theorem Grid.sound_of_one_run {γ : Type*} {π : γ → Grid} {rc e : γ → γ → Prop} {Bad : γ → Prop}
    (hc : Confluent rc e Bad)
    (proj : ∀ {x x'}, rc x x' → Grid.Step L c (π x) (π x'))
    (lift : ∀ {x g'}, Grid.Step L c (π x) g' → ∃ x', rc x x' ∧ π x' = g')
    (hF : ∀ x, GPUProof.Faults sig (π x, L, c) → Bad x)
    (hT : ∀ x, GPUProof.racy sig ((π x).mem.trace.map (Event.toCore L)).reverse = true →
      Bad x)
    (hK : ∀ x, GPUProof.kept sig ((π x).mem.trace.map (Event.toCore L)).reverse = false → Bad x)
    (hfin : ∀ {x g'}, GPUProof.Done sig (π x, L, c) → ¬ Grid.Step L c (π x) g')
    (hD : ∀ {x x'}, e x x' → GPUProof.Done sig (π x, L, c) → GPUProof.Done sig (π x', L, c))
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ {x x'}, e x x' → obs (π x).mem = obs (π x').mem)
    {n : Nat} {x₀ z : γ} (run : Path rc n x₀ z) (hz : GPUProof.Done sig (π z, L, c))
    (hb : ¬ Bad z) {y : β} (hy : obs (π z).mem = some y) (hR : R y) :
    Grid.Sound L c (π x₀) obs R := by
  obtain ⟨hC, h⟩ := GPUProof.Clean.of_lift (S := sig) (π := fun x => (π x, L, c))
    (obs := fun s => obs s.1.mem) hc (fun hr => sig_step_iff.2 ⟨_, rfl, proj hr⟩)
    (fun hs => by
      obtain ⟨g', rfl, hg⟩ := sig_step_iff.1 hs
      obtain ⟨x', hr, rfl⟩ := lift hg
      exact ⟨x', hr, rfl⟩)
    hF hT hK (fun hd hs => by
      obtain ⟨_, -, hg⟩ := sig_step_iff.1 hs
      exact hfin hd hg) hD hO run hz hb
  have final : ∀ g, ReflTransGen (Grid.Step L c) (π x₀) g → GPUProof.Done sig (g, L, c) →
      obs g.mem = some y := fun g hg hd => (h (g, L, c) (sig_reach_iff.2 ⟨g, rfl, hg⟩) hd).trans hy
  exact Grid.Sound.of_clean hC
    (fun g g' hg hg' hd hd' => (final g hg hd).trans (final g' hg' hd').symm)
    fun g hg hd => ⟨y, final g hg hd, hR⟩

/-! ### A grid of any number of threads, through the one-run theorem -/

/-- The grid of `N` threads over memory `M` in which thread `n` has returned if `D n` and is
`ts n` otherwise. -/
def retGrid (N : Nat) (ts : Nat → Thread) (M : Mem) (D : Nat → Bool) : Grid :=
  ⟨Array.ofFn (n := N) fun i => if D i then .done else .run (ts i), M⟩

/-- The memory of `retGrid N ts M D` is `M`. -/
@[simp] theorem retGrid_mem (N : Nat) (ts : Nat → Thread) (M : Mem) (D : Nat → Bool) :
    (retGrid N ts M D).mem = M := rfl

/-- Thread `n` of `retGrid N ts M D`: absent from `N` on, returned if `D n`, else running
`ts n`. -/
theorem retGrid_get (N : Nat) (ts : Nat → Thread) (M : Mem) (D : Nat → Bool) (n : Nat) :
    (retGrid N ts M D).threads[n]? =
      if n < N then some (if D n then .done else .run (ts n)) else none := by
  by_cases hn : n < N <;> simp [retGrid, hn]

/-- Setting thread `n < N` of `retGrid N ts M D` to returned gives the threads of the grid with
`D n` set to `true`. -/
theorem retGrid_set (N : Nat) (ts : Nat → Thread) (M : Mem) (D : Nat → Bool) {n : Nat}
    (hn : n < N) :
    (retGrid N ts M D).threads.set! n .done =
      (retGrid N ts M (Function.update D n true)).threads := by
  refine Array.ext_getElem? fun j => ?_
  rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds, retGrid_get, retGrid_get]
  by_cases hj : n = j
  · subst hj
    simp [retGrid, hn]
  · have hj' : j ≠ n := fun h => hj h.symm
    simp [hj, hj']

section Returning

variable {N : Nat} {ts : Nat → Thread} {M : Mem}

/-- If every thread `n < N`'s step from `M` returns at once with memory `f n`, thread `n`'s step
in `retGrid N ts M D` marks it returned over memory `f n` when it is below `N` and running, and is
`none` otherwise; for every `N`, threads, memory, `f` and `D`. -/
theorem retGrid_advance {f : Nat → Mem} (h : ∀ n, n < N → step (c n) (ts n) M = .ok (.done (f n)))
    (D : Nat → Bool) (n : Nat) :
    (retGrid N ts M D).advance c n =
      if n < N ∧ D n = false then .ok (some (retGrid N ts (f n) (Function.update D n true)))
      else .ok none := by
  by_cases hn : n < N
  · cases hD : D n with
    | false =>
      have e : (retGrid N ts M D).threads[n]? = some (.run (ts n)) := by
        rw [retGrid_get]
        simp [hn, hD]
      simp only [Grid.advance, e]
      rw [retGrid_mem, h n hn]
      simp only [bind, Except.bind, pure, Except.pure, hn, and_self, ite_true]
      rw [retGrid_set N ts M D hn]
      rfl
    | true =>
      have e : (retGrid N ts M D).threads[n]? = some .done := by
        rw [retGrid_get]
        simp [hn, hD]
      simp [Grid.advance, e, pure, Except.pure]
  · have e : (retGrid N ts M D).threads[n]? = none := by
      rw [retGrid_get]
      simp [hn]
    simp [Grid.advance, e, hn, pure, Except.pure]

/-- No collective call completes in `retGrid N ts M D`: no thread waits. -/
theorem retGrid_fire (D : Nat → Bool) (n : Nat) : (retGrid N ts M D).fire L c n = .ok none := by
  by_cases hn : n < N
  · cases hD : D n with
    | false =>
      have e : (retGrid N ts M D).threads[n]? = some (.run (ts n)) := by
        rw [retGrid_get]
        simp [hn, hD]
      simp [Grid.fire, e, pure, Except.pure]
    | true =>
      have e : (retGrid N ts M D).threads[n]? = some .done := by
        rw [retGrid_get]
        simp [hn, hD]
      simp [Grid.fire, e, pure, Except.pure]
  · have e : (retGrid N ts M D).threads[n]? = none := by
      rw [retGrid_get]
      simp [hn]
    simp [Grid.fire, e, pure, Except.pure]

/-- The memory of `M` after the steps `f k` of the threads `k` of `l` with `D k`, the last of
`l` first. -/
private def retMem (l : List Nat) (f : Nat → Mem → Mem) (M : Mem) (D : Nat → Bool) : Mem :=
  l.foldr (fun k m => if D k then f k m else m) M

section Commuting

variable {f : Nat → Mem → Mem} {P : Mem → Prop}

private theorem retMem_P (hP : ∀ n, n < N → ∀ m, P m → P (f n m)) (hM : P M) {l : List Nat}
    (hl : ∀ k ∈ l, k < N) (D : Nat → Bool) : P (retMem l f M D) := by
  induction l with
  | nil => exact hM
  | cons k l ih =>
    have := ih fun j hj => hl j (List.mem_cons_of_mem _ hj)
    simp only [retMem, List.foldr_cons] at this ⊢
    split
    · exact hP k (hl k (by simp)) _ this
    · exact this

private theorem retMem_trace (hP : ∀ n, n < N → ∀ m, P m → P (f n m))
    (hT : ∀ n, n < N → ∀ m, P m → (f n m).trace = m.trace) (hM : P M) {l : List Nat}
    (hl : ∀ k ∈ l, k < N) (D : Nat → Bool) : (retMem l f M D).trace = M.trace := by
  induction l with
  | nil => rfl
  | cons k l ih =>
    have hl' : ∀ j ∈ l, j < N := fun j hj => hl j (List.mem_cons_of_mem _ hj)
    have e := ih hl'
    have p := retMem_P hP hM hl' D
    simp only [retMem, List.foldr_cons] at e p ⊢
    split
    · rw [hT k (hl k (by simp)) _ p, e]
    · exact e

private theorem retMem_update_not_mem {l : List Nat} {n : Nat} (hn : n ∉ l) (D : Nat → Bool)
    (v : Bool) : retMem l f M (Function.update D n v) = retMem l f M D := by
  induction l with
  | nil => rfl
  | cons k l ih =>
    have hk : k ≠ n := fun h => hn (h ▸ by simp)
    have e := ih fun h => hn (List.mem_cons_of_mem _ h)
    simp only [retMem, List.foldr_cons, Function.update_apply, hk, ite_false] at e ⊢
    rw [e]

private theorem retMem_update (hP : ∀ n, n < N → ∀ m, P m → P (f n m))
    (hc : ∀ i j, i < N → j < N → i ≠ j → ∀ m, P m → f i (f j m) = f j (f i m)) (hM : P M)
    {l : List Nat} (hl : l.Nodup) (hlN : ∀ k ∈ l, k < N) {D : Nat → Bool} {n : Nat} (hn : n ∈ l)
    (hD : D n = false) : retMem l f M (Function.update D n true) = f n (retMem l f M D) := by
  induction l with
  | nil => cases hn
  | cons k l ih =>
    obtain ⟨hk, hl'⟩ := List.nodup_cons.1 hl
    have hlN' : ∀ j ∈ l, j < N := fun j hj => hlN j (List.mem_cons_of_mem _ hj)
    rcases List.mem_cons.1 hn with rfl | hn'
    · have e := retMem_update_not_mem (f := f) (M := M) hk D true
      simp only [retMem, List.foldr_cons, Function.update_self, ite_true, hD] at e ⊢
      rw [e]
      rfl
    · have hne : k ≠ n := fun h => hk (h ▸ hn')
      have e := ih hl' hlN' hn'
      have p := retMem_P hP hM hlN' D
      simp only [retMem, List.foldr_cons, Function.update_apply, hne, ite_false] at e p ⊢
      rw [e]
      split
      · exact hc k n (hlN k (by simp)) (hlN n (by simp [hn'])) hne _ p
      · rfl

/-- **A grid of `N` threads whose steps return and commute is sound, by the one-run theorem.**
For every `N`, launch `L` of at least `N` threads, contexts `c`, threads `ts`, memory `M` and
memory changes `f`: let `P` be a property of memories that `M` has and every `f n` with `n < N`
keeps. If, from every memory with `P`, thread `n < N`'s step returns at once with memory
`f n m`, the changes of two distinct threads commute and each keeps the trace, the grid of these
threads is sound (all seven fields) for every observation and relation `R` that the observation
`y` of the memory after all `N` changes, `(List.range N).foldr f M`, satisfies, when the trace of
`M` has no race and keeps `!invariant.load`. The states are the sets of returned threads, the
memory of a set is that of its threads' changes (in any order, by the commuting), two threads'
steps commute (the diamond, for every pair of threads), and the run in thread order is the one
run. -/
theorem Grid.sound_commuting (hN : N ≤ volume L.grid * volume L.block) (hM : P M)
    (hP : ∀ n, n < N → ∀ m, P m → P (f n m))
    (h : ∀ n, n < N → ∀ m, P m → step (c n) (ts n) m = .ok (.done (f n m)))
    (hc : ∀ i j, i < N → j < N → i ≠ j → ∀ m, P m → f i (f j m) = f j (f i m))
    (hT : ∀ n, n < N → ∀ m, P m → (f n m).trace = m.trace)
    {β : Type} {obs : Mem → Option β} {R : β → Prop} {y : β}
    (hy : obs ((List.range N).foldr f M) = some y) (hR : R y)
    (hM' : GPUProof.racy sig (M.trace.map (Event.toCore L)).reverse = false)
    (kM : GPUProof.kept sig (M.trace.map (Event.toCore L)).reverse = true) :
    Grid.Sound L c (retGrid N ts M fun _ => false) obs R := by
  have hr : ∀ k ∈ List.range N, k < N := fun k hk => List.mem_range.1 hk
  have hPD := retMem_P (f := f) hP hM hr
  have upd : ∀ {D : Nat → Bool} {n}, n < N → D n = false →
      retMem (List.range N) f M (Function.update D n true) = f n (retMem (List.range N) f M D) :=
    fun hn hD => retMem_update hP hc hM List.nodup_range hr (List.mem_range.2 hn) hD
  have adv : ∀ D, (retGrid N ts (retMem (List.range N) f M D) D).advance c = fun n =>
      if n < N ∧ D n = false then
        .ok (some (retGrid N ts (retMem (List.range N) f M (Function.update D n true))
          (Function.update D n true)))
      else .ok none := fun D => funext fun n => by
    rw [retGrid_advance (fun n hn => h n hn _ (hPD D))]
    split
    · rename_i hcond
      rw [upd hcond.1 hcond.2]
    · rfl
  have e0 : retMem (List.range N) f M (fun _ => false) = M := by
    simp only [retMem, Bool.false_eq_true, ite_false]
    generalize List.range N = l
    induction l with
    | nil => rfl
    | cons _ _ ih => exact ih
  have eN : retMem (List.range N) f M (fun i => decide (i < N)) = (List.range N).foldr f M := by
    unfold retMem
    generalize hl : List.range N = l
    have hl' : ∀ k ∈ l, k < N := hl ▸ hr
    clear hl
    induction l with
    | nil => rfl
    | cons k l ih =>
      simp only [List.foldr_cons, hl' k (by simp), decide_true, ite_true]
      rw [ih fun j hj => hl' j (List.mem_cons_of_mem _ hj)]
  rw [← e0]
  let rc : (Nat → Bool) → (Nat → Bool) → Prop := fun D D' =>
    ∃ n, n < N ∧ D n = false ∧ D' = Function.update D n true
  have hc : Confluent rc Eq (fun _ => False) := by
    refine ⟨fun _ => rfl, Eq.symm, Eq.trans, ?_, ?_, ?_, ?_⟩
    · rintro a _ b rfl hr
      exact ⟨b, hr, rfl⟩
    · rintro a _ rfl hb
      exact hb
    · intro a b hb _
      exact hb
    · rintro D _ _ ⟨i, hi, hDi, rfl⟩ ⟨j, hj, hDj, rfl⟩
      by_cases hij : i = j
      · subst hij
        exact .inl rfl
      · refine .inr (.inr ⟨Function.update (Function.update D i true) j true,
          Function.update (Function.update D j true) i true, ⟨j, hj, ?_, rfl⟩, ⟨i, hi, ?_, rfl⟩,
          .inl (Function.update_comm hij true true D)⟩)
        · simp [Ne.symm hij, hDj]
        · simp [hij, hDi]
  let π : (Nat → Bool) → Grid := fun D => retGrid N ts (retMem (List.range N) f M D) D
  have proj : ∀ {D D'}, rc D D' → Grid.Step L c (π D) (π D') := by
    rintro D _ ⟨n, hn, hD, rfl⟩
    exact ⟨n, .inl (by simp only [π, adv, hn, hD, and_self, ite_true])⟩
  have lift : ∀ {D g'}, Grid.Step L c (π D) g' → ∃ D', rc D D' ∧ π D' = g' := by
    rintro D g' ⟨n, hs | hs⟩
    · simp only [π, adv] at hs
      split at hs
      · rename_i hcond
        cases hs
        exact ⟨_, ⟨n, hcond.1, hcond.2, rfl⟩, rfl⟩
      · cases hs
    · rw [retGrid_fire] at hs
      cases hs
  have nf : ∀ D, ¬ GPUProof.Faults sig (π D, L, c) := by
    intro D hf
    obtain ⟨n, e, hf | hf⟩ := Grid.faults_iff.1 hf
    · simp only [π, adv] at hf
      split at hf <;> cases hf
    · rw [retGrid_fire] at hf
      cases hf
  have tr : ∀ D, (π D).mem.trace = M.trace := fun D => retMem_trace hP hT hM hr D
  have path : ∀ m k, k + m = N →
      Path rc m (fun i => decide (i < k)) (fun i => decide (i < N)) := by
    intro m
    induction m with
    | zero =>
      intro k hk
      obtain rfl : k = N := by omega
      exact .nil _
    | succ m ih =>
      intro k hk
      refine .cons ⟨k, by omega, by simp, ?_⟩ (ih (k + 1) (by omega))
      funext i
      by_cases hi : i = k
      · subst hi
        simp
      · simp only [Function.update_apply, hi, ite_false, decide_eq_decide]
        omega
  have run : Path rc N (fun _ => false) (fun i => decide (i < N)) := by
    have e0 : (fun i : Nat => decide (i < 0)) = fun _ => false := by
      funext i
      simp
    rw [← e0]
    exact path N 0 (Nat.zero_add N)
  have hd : GPUProof.Done sig (π fun i => decide (i < N), L, c) := by
    refine Grid.done_of_all ?_
    rw [Array.all_eq_true]
    intro i hi
    simp [π, retGrid]
  exact Grid.sound_of_one_run (π := π) hc proj lift (fun D hf => nf D hf)
    (fun D ht => by rw [tr D] at ht; exact Bool.noConfusion (hM'.symm.trans ht))
    (fun D hk => by rw [tr D] at hk; exact Bool.noConfusion (kM.symm.trans hk))
    (Grid.Done.final (by simpa [π, retGrid] using hN))
    (fun he hd' => he ▸ hd') (fun he => he ▸ rfl) run hd id
    (show obs (retMem (List.range N) f M _) = some y by rw [eN]; exact hy) hR

end Commuting

/-- **A grid of `N` returning threads is sound, by the one-run theorem.** If every thread `n < N`
returns in one step from memory `M` without changing it, the grid of these threads is sound
(all seven fields) for every observation defined on `M` and relation `R` its value satisfies,
when the trace of `M` has no race and keeps `!invariant.load`. For every `N`, launch of at least
`N` threads and contexts. `Grid.sound_commuting` with no change of memory (`f n m = m`, at the
memories equal to `M`). -/
theorem Grid.sound_returning (hN : N ≤ volume L.grid * volume L.block)
    (h : ∀ n, n < N → step (c n) (ts n) M = .ok (.done M))
    {β : Type} {obs : Mem → Option β} {R : β → Prop} {y : β} (hy : obs M = some y) (hR : R y)
    (hM : GPUProof.racy sig (M.trace.map (Event.toCore L)).reverse = false)
    (kM : GPUProof.kept sig (M.trace.map (Event.toCore L)).reverse = true) :
    Grid.Sound L c (retGrid N ts M fun _ => false) obs R :=
  Grid.sound_commuting (f := fun _ m => m) (P := (· = M)) hN rfl (fun _ _ _ hm => hm)
    (fun n hn _ hm => hm ▸ h n hn) (fun _ _ _ _ _ _ _ => rfl) (fun _ _ _ _ => rfl)
    (by generalize List.range N = l; induction l with | nil => exact hy | cons _ _ ih => exact ih)
    hR hM kM

end Returning

/-- A grid whose threads are all running is a `retGrid`. -/
theorem eq_retGrid {g : Grid} {N : Nat} {ts : Nat → Thread} (hs : g.threads.size = N)
    (ht : ∀ n, n < N → g.threads[n]? = some (.run (ts n))) :
    g = retGrid N ts g.mem fun _ => false := by
  cases g with
  | mk th m =>
    simp only [retGrid, Grid.mk.injEq, and_true]
    refine Array.ext_getElem? fun j => ?_
    by_cases hj : j < N
    · rw [ht j hj]
      simp [hj]
    · have h1 : th.size ≤ j := by
        simp only at hs
        omega
      simp [hj, h1]

/-- The kernel `define void @k() { ret void }`. -/
def retFn : Func := Func.ofTerm (.ret none)

/-- A thread at the start of `retFn`. -/
def retThread : Thread :=
  { frames := [{ fn := retFn, label := 0, pc := 0, regs := fun _ => none,
                 prods := fun _ => none, allocas := [], dest := none }], k := 0 }

/-- `retThread`'s step returns at once and keeps the memory, in every context and memory. -/
theorem step_retThread (c : Ctx) (M : Mem) : step c retThread M = .ok (.done M) := rfl

/-- The launch of `ret void` starts, for every launch, closed memory, address choice and oracle,
in a grid of `volume L.grid * volume L.block` running threads with an empty trace. -/
theorem start_ret (L : Launch) {m : Mem} (hm : m.Closed []) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (Program.ofFunc retFn) retFn L [] m ch oracle = .ok (g, c) ∧
      g.mem.trace = [] ∧ g.threads.size = volume L.grid * volume L.block ∧
      ∀ n, n < volume L.grid * volume L.block → g.threads[n]? = some (.run retThread) := by
  unfold Grid.start
  have hkl : Func.checkLaunch (Program.ofFunc retFn).module retFn L.block ([] : List Val).length =
      .ok () := rfl
  rw [Mem.checkClosed_of_closed hm, hkl]
  simp only [bind, Except.bind]
  have hck : Func.check (Program.ofFunc retFn).module retFn = Except.ok () := rfl
  have hg : (Program.ofFunc retFn).module.globals.toList = [] := rfl
  split
  · rename_i e heq
    exact absurd (hck.symm.trans heq) (by simp)
  · split
    · rename_i e heq
      obtain ⟨b', hb', -⟩ := Sym.sharedFold_res (fun _ h => by simp [hg] at h) _ _ hm.above heq
      cases hb'
    · rename_i v1 heq1
      obtain ⟨m1, tabs⟩ := v1
      simp only
      split
      · rename_i e heq
        obtain ⟨b', hb', -⟩ := Sym.foldlM_res (P := fun _ => True) (Q := fun _ => True)
          (fun b k y _ _ hy => by
            obtain ⟨m, ts⟩ := b
            exact ⟨_, hy.symm, trivial⟩) _ _ _ (fun _ _ => trivial) trivial heq
        cases hb'
      · rename_i v2 heq2
        obtain ⟨m2, ts⟩ := v2
        rw [List.range_eq_range'] at heq2
        obtain ⟨hsz, hall⟩ := Sym.foldlM_range'_inv
          (P := fun k (b : Mem × Array Status) => b.2.size = k ∧
            ∀ n, n < k → b.2[n]? = some (.run retThread)) (fun k b b' hs hb => by
          obtain ⟨m, ts⟩ := b
          have e : Except.ok (ε := Fault) (m, ts.push (.run retThread)) = .ok b' := hs
          cases e
          have hs : ts.size = k := hb.1
          refine ⟨by simp [hs], fun n hn => ?_⟩
          rw [Array.getElem?_push]
          split
          · rfl
          · exact hb.2 n (by omega)) _ 0 _ heq2 ⟨rfl, fun n hn => by omega⟩
        simp only [Nat.zero_add] at hsz hall
        exact ⟨_, _, rfl, rfl, hsz, hall⟩

/-- **The kernel `ret void` is sound on every launch**: for every launch `L` (any grid and block
sizes), closed memory (`Mem.Closed`), address choice and oracle. -/
theorem Kernel.sound_ret_launch (L : Launch) {m : Mem} (hm : m.Closed []) :
    Kernel.Sound (Program.ofFunc retFn) retFn L [] m (fun _ _ => True) (fun _ => some ())
      (fun _ => True) := by
  intro ch oracle _
  obtain ⟨g, c, hs, htr, hsz, hall⟩ := start_ret L hm ch oracle
  refine ⟨g, c, hs, ?_⟩
  rw [eq_retGrid (ts := fun _ => retThread) hsz hall]
  exact Grid.sound_returning le_rfl (fun n _ => step_retThread (c n) g.mem) rfl trivial
    (Bool.eq_false_iff.2 fun hr => by
      obtain ⟨_, _, _, _, _, hi, -⟩ := (GPUProof.racy_iff sig).1 hr
      simp [htr] at hi)
    ((GPUProof.kept_iff sig).2 fun _ _ hw => by simp [htr] at hw)

end Grid

end MojoProof.Sem
