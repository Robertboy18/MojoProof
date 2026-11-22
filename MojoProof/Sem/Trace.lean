import MojoProof.Sem.OneRun
import MojoProof.Sem.Race
import MojoProof.Sem.Buffer

/-!
# Traces and grids through the one-run theorem

Proved for every trace (the predicates `racy` and `kept` of MojoProof/Sem/Spec.lean):

* a racy trace stays racy, and a trace that breaks the promise of `!invariant.load` stays broken,
  when an event is added (`racy_cons`, `kept_cons`); `kept` is a property of the set of events
  (`kept_iff`, `kept_perm`); loads with `!invariant.load` outside the blocks written keep it
  (`kept_of_split`);
* ownership gives race freedom: if each access lies in its thread's tile of a `Tiling` of its
  block, or reads a block nobody writes (`Owned`), and threads that share a tiled block have
  different tiles, the trace has no race, whatever its barriers (`racy_eq_false_of_owned`).
  The tiling and the tiles may change at each barrier of a block of threads
  (`racy_eq_false_of_phased`, with the phases of MojoProof/Sem/Race.lean): the per-phase
  discipline must agree across blocks of threads on each block, and two accesses with one tile
  that no barrier orders must be by one thread; `racy_eq_false_of_owned` is its instance with one
  discipline for every phase. Instance: MojoProofTest/Phased.lean, a trace that only the per-phase
  form covers (`not_owned`).
  Offsets that are apart and in bounds are a tiling (`Tiling.ofApart`), so the row-major tiles
  of an output tensor (MojoProof/Sem/Buffer.lean) are one. Instance: the strided tiling of a
  buffer of `n` elements of `w` bytes (`Tiling.strided`, by `apart_stride`).
  The trace lemma of an elementwise kernel (`racy_kept_of_cells`, every trace): if every access
  to an output block lies in its thread's cell, the cells being `w` bytes apart (`Apart`), every
  access to another block is a read, and no access with `!invariant.load` is to the output block,
  the trace has no race and keeps `!invariant.load`. Its case of cells `k * w`: a trace whose
  writes are thread `k`'s element `k` of one buffer and whose other accesses are reads of other
  blocks (`racy_kept_pointwise`). Statements about traces, not about a kernel; instances in
  MojoProofTest/ScheduleOwned.lean.

Proved for every program, launch and observation:

* `Grid.sound_of_one_run`: all seven fields of `Grid.Sound` from one run of a step relation on
  any state type that projects onto `Grid.Step` and lifts its steps, when that relation is
  `Confluent` (MojoProof/Sem/OneRun.lean) up to an equivalence that preserves `Done` and the
  observation, with faults, racy traces and broken `!invariant.load` promises bad, and the run
  ends in a state whose grid has returned, is not bad and has an observation that satisfies `R`.
  The confluence is a hypothesis; no kernel's is proved here. The proof is in
  docs/proofs/adapter.md.

Instances on the real `Grid.Step`:

* `Grid.sound_one`: a grid of one thread whose step returns, from and to memories whose traces
  have no race and keep `!invariant.load`, is sound for every observation defined on the final
  memory and relation its value satisfies (the states are the reachable grids);
* `Grid.sound_returning`: a grid of `N` threads that each return in one step without changing
  memory, whose trace has no race and keeps `!invariant.load`, is sound for every observation
  defined on that memory and relation its value satisfies, for every `N` (the states are the
  sets of returned threads; the diamond holds for every pair of threads);
* `Kernel.sound_ret_launch`: the kernel `define void @k() { ret void }` is sound on every launch,
  for every closed memory (`Mem.Closed`), address choice and oracle.
-/

namespace MojoProof.Sem

open LLVM Relation

section Trace

/-- A racy trace stays racy when an event is added. -/
theorem racy_cons (e : Event) {tr : List Event} (h : racy tr = true) : racy (e :: tr) = true := by
  cases e with
  | access a => simp [racy, h]
  | barrier k => simpa [racy] using h

/-- `kept` by membership: no write of the trace overlaps a load with `!invariant.load` of it. -/
theorem kept_iff {tr : List Event} : kept tr = true ↔
    ∀ a e, Event.access a ∈ tr → a.invariant = true → Event.access e ∈ tr → e.write = true →
      a.overlaps e = false := by
  simp only [kept, List.all_eq_true]
  constructor
  · intro h a e ha hi he hw
    have h1 := h (.access e) he
    simp only [hw, Bool.not_true, Bool.false_or, List.all_eq_true, List.mem_filterMap] at h1
    have h2 := h1 a ⟨.access a, ha, by simp [hi]⟩
    simpa using h2
  · intro h x hx
    cases x with
    | barrier k => rfl
    | access e =>
      cases hw : e.write with
      | false => simp [hw]
      | true =>
        simp only [hw, Bool.not_true, Bool.false_or, List.all_eq_true, List.mem_filterMap]
        rintro a ⟨y, hy, hya⟩
        cases y with
        | barrier k => simp at hya
        | access b =>
          by_cases hb : b.invariant = true
          · simp only [hb, ite_true, Option.some.injEq] at hya
            subst hya
            simp [h b e hy hb hx hw]
          · simp [hb] at hya

/-- A broken `!invariant.load` promise stays broken when an event is added. -/
theorem kept_cons (e : Event) {tr : List Event} (h : kept tr = false) : kept (e :: tr) = false := by
  cases hk : kept (e :: tr) with
  | false => rfl
  | true =>
    have : kept tr = true := kept_iff.2 fun a e' ha hi he hw =>
      kept_iff.1 hk a e' (List.mem_cons_of_mem _ ha) hi (List.mem_cons_of_mem _ he) hw
    rw [this] at h
    cases h

/-- `kept` does not depend on the order of the trace. -/
theorem kept_perm {tr tr' : List Event} (h : tr.Perm tr') : kept tr = kept tr' := by
  rw [Bool.eq_iff_iff, kept_iff, kept_iff]
  constructor
  · intro k a e ha hi he hw
    exact k a e (h.mem_iff.2 ha) hi (h.mem_iff.2 he) hw
  · intro k a e ha hi he hw
    exact k a e (h.mem_iff.1 ha) hi (h.mem_iff.1 he) hw

/-- If loads with `!invariant.load` stay outside a set `W` of blocks and writes stay inside it,
the trace keeps the promise. -/
theorem kept_of_split {W : Nat → Prop} {tr : List Event}
    (hi : ∀ a, Event.access a ∈ tr → a.invariant = true → ¬ W a.ptr.block)
    (hw : ∀ e, Event.access e ∈ tr → e.write = true → W e.ptr.block) : kept tr = true :=
  kept_iff.2 fun a e ha hia he hwe => by
    have hb : a.ptr.block ≠ e.ptr.block := fun hb => hi a ha hia (hb ▸ hw e he hwe)
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

/-- **Ownership per barrier interval gives race freedom** (`racy`, every trace). The tiling
`T p` and the tile map `own p` may change with the phase `p` (`phases`). If every access follows
the discipline of its phase, accesses of one block by two blocks of threads see one tiling of it,
and two accesses of a tiled block with one tile, by different blocks of threads or in one phase,
are by one thread, the trace has no race. -/
theorem racy_eq_false_of_phased {ι : Type} {T : Nat → Nat → Option (Tiling ι)}
    {own : Nat → Nat → ι} {tr : List Event}
    (hO : ∀ x ∈ (phases tr).1, Owned (T x.2) (own x.2) x.1)
    (hG : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.who.cta ≠ y.1.who.cta →
      x.1.ptr.block = y.1.ptr.block → T x.2 x.1.ptr.block = T y.2 x.1.ptr.block)
    (hX : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.ptr.block = y.1.ptr.block →
      T x.2 x.1.ptr.block ≠ none → (x.1.who.cta ≠ y.1.who.cta ∨ x.2 = y.2) →
      own x.2 x.1.who.thread = own y.2 y.1.who.thread → x.1.who.thread = y.1.who.thread) :
    racy tr = false := by
  cases h : racy tr
  · rfl
  obtain ⟨x, hx, y, hy, hc⟩ := racy_iff.1 h
  simp only [clash, Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.or_eq_true, beq_iff_eq] at hc
  obtain ⟨⟨ht, hc⟩, hk⟩ := hc
  have hb : x.1.ptr.block = y.1.ptr.block := by
    by_contra hb
    simp [Access.conflict, Access.overlaps, hb] at hc
  have hτ : T x.2 x.1.ptr.block = T y.2 x.1.ptr.block := by
    rcases hk with hk | hk
    · exact hG x hx y hy hk hb
    · rw [hk]
  let o n := if n = x.1.who.thread then own x.2 n else own y.2 n
  have ox : o x.1.who.thread = own x.2 x.1.who.thread := by simp [o]
  have oy : o y.1.who.thread = own y.2 y.1.who.thread := by simp [o, Ne.symm ht]
  have h1 : Owned (T x.2) o x.1 := (hO x hx).congr rfl ox.symm
  have h2 : Owned (T x.2) o y.1 := (hO y hy).congr (by rw [← hb]; exact hτ.symm) oy.symm
  have := h1.apart h2 (fun hb hT ho => ht (hX x hx y hy hb hT hk (by rw [← ox, ← oy, ho])))
    (by simp only [Access.conflict, Bool.and_eq_true] at hc; exact hc.1.1)
  simp [Access.conflict, this] at hc

/-- **Ownership gives race freedom** (`racy`, every trace). If every access of a trace
follows the discipline `(T, own)`, and threads that access one tiled block have different tiles,
the trace has no race, whatever its barriers. The discipline of `racy_eq_false_of_phased` that
does not depend on the phase. -/
theorem racy_eq_false_of_owned {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι} :
    ∀ {tr : List Event}, (∀ a, Event.access a ∈ tr → Owned T own a) →
      (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
        T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
          a.who.thread = e.who.thread) → racy tr = false := fun h hi =>
  racy_eq_false_of_phased (T := fun _ => T) (own := fun _ => own) (fun _ hx => h _ (mem_phases hx))
    (fun _ _ _ _ _ _ => rfl) fun _ hx _ hy hb hT _ ho =>
      hi _ _ (mem_phases hx) (mem_phases hy) hb hT ho

/-- **The trace lemma of an elementwise kernel** (every trace, output block `out`, width `w` and
cell map `cell` whose cells are `w` bytes apart, `Apart`): if every access of the trace to `out`
lies in its thread's cell, the `w` bytes from `cell` of its thread number, every access to another
block is a read, and no access with `!invariant.load` is to `out`, the trace is not racy and keeps
the promise of `!invariant.load`. `racy_kept_pointwise` is its case of cells `k * w`, each access
the whole cell. -/
theorem racy_kept_of_cells {tr : List Event} {out w : Nat} {cell : Nat → Nat}
    (hap : Apart cell w)
    (hc : ∀ a, Event.access a ∈ tr → a.ptr.block = out →
      (cell a.who.thread : Int) ≤ a.ptr.off ∧ a.ptr.off + a.len ≤ cell a.who.thread + w)
    (hr : ∀ a, Event.access a ∈ tr → a.ptr.block ≠ out → a.write = false)
    (hi : ∀ a, Event.access a ∈ tr → a.invariant = true → a.ptr.block ≠ out) :
    racy tr = false ∧ kept tr = true := by
  refine ⟨?_, kept_of_split (W := (· = out)) hi fun e he hw => ?_⟩
  · cases h : racy tr
    · rfl
    obtain ⟨x, hx, y, hy, hc'⟩ := racy_iff.1 h
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
      · simp [hr _ hx' ho] at hw
      · simp [hr _ hy' (hb ▸ ho)] at hw
  · by_contra hb
    simp [hr e he hb] at hw

/-- Instance, for every trace, element count `n` and element width `w`: if every access is a read
of a block other than `out`, or an access without `!invariant.load` by a thread `k < n` to
exactly the bytes `[k * w, k * w + w)` of `out`, the trace has no race and keeps the promise of
`!invariant.load`. This is the access pattern of a pointwise kernel with one element per thread;
it is a statement about traces, not about a kernel. `racy_kept_of_cells` with the cells `k * w`
(`apart_stride`). -/
theorem racy_kept_pointwise {out n w : Nat} {tr : List Event}
    (h : ∀ a, Event.access a ∈ tr → (a.ptr.block ≠ out ∧ a.write = false) ∨
      (a.ptr.block = out ∧ a.invariant = false ∧ a.who.thread < n ∧
        a.ptr.off = ((a.who.thread * w : Nat) : Int) ∧ a.len = w)) :
    racy tr = false ∧ kept tr = true :=
  racy_kept_of_cells (out := out) (cell := (· * w)) (by simpa using apart_stride 0 (le_refl w))
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

/-- A grid in which every thread has returned does not fault. -/
theorem done_not_faults {g : Grid} (h : g.Done) : ¬ g.Faults L c := by
  rintro ⟨n, e, hf⟩
  rcases h.get n with hn | hn <;> simp [Grid.advance, Grid.fire, hn, pure, Except.pure] at hf

/-- **`Grid.Sound` from one run** (all seven fields of `Grid.Sound`). `rc` is a step
relation on states `γ` (for example the grids reachable from the start, or grids with extra
ghost state) that projects onto `Grid.Step` and lifts every grid step. If `rc` is confluent up to
`e` with `Bad` persistent; faults, racy traces and traces that break `!invariant.load` are bad;
and `e` preserves `Done` and the observation; then one run of `rc` from `x₀` to a state whose
grid is done, is not bad and observes `y` with `R y` makes the grid of `x₀` sound. -/
theorem Grid.sound_of_one_run {γ : Type*} {π : γ → Grid} {rc e : γ → γ → Prop} {Bad : γ → Prop}
    (hc : Confluent rc e Bad)
    (proj : ∀ {x x'}, rc x x' → Grid.Step L c (π x) (π x'))
    (lift : ∀ {x g'}, Grid.Step L c (π x) g' → ∃ x', rc x x' ∧ π x' = g')
    (hF : ∀ x, (π x).Faults L c → Bad x)
    (hT : ∀ x, racy (π x).mem.trace = true → Bad x)
    (hK : ∀ x, kept (π x).mem.trace = false → Bad x)
    (hD : ∀ {x x'}, e x x' → (π x).Done → (π x').Done)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ {x x'}, e x x' → obs (π x).mem = obs (π x').mem)
    {n : Nat} {x₀ z : γ} (run : Path rc n x₀ z) (hz : (π z).Done) (hb : ¬ Bad z)
    {y : β} (hy : obs (π z).mem = some y) (hR : R y) :
    Grid.Sound L c (π x₀) obs R := by
  have hzn : Normal rc z := fun b hr => Grid.Done.final hz (proj hr)
  have up : ∀ g, ReflTransGen (Grid.Step L c) (π x₀) g → ∃ x, ReflTransGen rc x₀ x ∧ π x = g := by
    intro g hg
    induction hg with
    | refl => exact ⟨x₀, .refl, rfl⟩
    | tail _ hs ih =>
      obtain ⟨x, hx, rfl⟩ := ih
      obtain ⟨x', hr, rfl⟩ := lift hs
      exact ⟨x', hx.tail hr, rfl⟩
  obtain ⟨hacc, hnb, hdet, hprog⟩ := hc.one_run run hzn hb
  have final : ∀ g, ReflTransGen (Grid.Step L c) (π x₀) g → g.Done → obs g.mem = some y := by
    intro g hg hd
    obtain ⟨x, hx, rfl⟩ := up g hg
    rw [← hO (hdet x hx fun b hr => Grid.Done.final hd (proj hr))]
    exact hy
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro g hg hf
    obtain ⟨x, hx, rfl⟩ := up g hg
    exact hnb x hx (hF x hf)
  · intro g hg
    obtain ⟨x, hx, rfl⟩ := up g hg
    exact Bool.eq_false_iff.mpr fun ht => hnb x hx (hT x ht)
  · intro g hg
    obtain ⟨x, hx, rfl⟩ := up g hg
    cases hk : kept (π x).mem.trace with
    | true => rfl
    | false => exact absurd (hK x hk) (hnb x hx)
  · intro g hg hnd
    obtain ⟨x, hx, rfl⟩ := up g hg
    obtain ⟨m, z', _, hp, he⟩ := hprog x hx
    cases hp with
    | nil => exact absurd (hD he hz) hnd
    | cons hr _ => exact ⟨_, proj hr⟩
  · have : ∀ x, Acc (fun b a => rc a b) x → Acc (fun g' g => Grid.Step L c g g') (π x) := by
      intro x hx
      induction hx with
      | intro x _ ih =>
        refine ⟨_, fun g' hs => ?_⟩
        obtain ⟨x', hr, rfl⟩ := lift hs
        exact ih x' hr
    exact this x₀ hacc
  · intro g g' hg hg' hd hd'
    rw [final g hg hd, final g' hg' hd']
  · intro g hg hd
    exact ⟨y, final g hg hd, hR⟩

/-- A grid of one thread whose step returns, with memory `M'`, is sound for every observation
defined on `M'` and relation `R` its value satisfies, when the traces of `M` and `M'` have no
race and keep `!invariant.load`. An instance of every premise of `Grid.sound_of_one_run`: the
states are the reachable grids, and `Bad` is a fault, a racy trace or a broken
`!invariant.load` promise. -/
theorem Grid.sound_one {t : Thread} {M M' : Mem} (h : step (c 0) t M = .ok (.done M'))
    {β : Type} {obs : Mem → Option β} {R : β → Prop} {y : β} (hy : obs M' = some y) (hR : R y)
    (hM : racy M.trace = false) (hM' : racy M'.trace = false)
    (kM : kept M.trace = true) (kM' : kept M'.trace = true) :
    Grid.Sound L c ⟨#[.run t], M⟩ obs R := by
  let g₀ : Grid := ⟨#[.run t], M⟩
  let z₀ : Grid := ⟨#[.done], M'⟩
  have hd : z₀.Done := by simp [z₀, Grid.Done]
  have reach : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → g = g₀ ∨ g = z₀ := by
    intro g hr
    induction hr with
    | refl => exact .inl rfl
    | tail _ hs ih =>
      rcases ih with rfl | rfl
      · exact .inr (Grid.step_one h hs)
      · exact absurd hs (Grid.Done.final hd)
  have hstep : Grid.Step L c g₀ z₀ := by
    refine ⟨0, .inl ?_⟩
    simp only [g₀, Grid.advance, List.getElem?_toArray, List.getElem?_cons_zero, h, bind,
      Except.bind, pure, Except.pure]
    rfl
  have nf : ¬ g₀.Faults L c := by
    rintro ⟨n, e, hf⟩
    cases n with
    | zero => simp [g₀, Grid.advance, Grid.fire, h, bind, Except.bind, pure, Except.pure] at hf
    | succ n => simp [g₀, Grid.advance, Grid.fire, pure, Except.pure] at hf
  let γ := { g : Grid // ReflTransGen (Grid.Step L c) g₀ g }
  let rc : γ → γ → Prop := fun a b => Grid.Step L c a.1 b.1
  have nb : ∀ g, ReflTransGen (Grid.Step L c) g₀ g →
      ¬ (g.Faults L c ∨ racy g.mem.trace = true ∨ kept g.mem.trace = false) := by
    intro g hg hbad
    rcases reach g hg with rfl | rfl
    · rcases hbad with hf | ht | hk
      · exact nf hf
      · simp [g₀, hM] at ht
      · simp [g₀, kM] at hk
    · rcases hbad with hf | ht | hk
      · exact done_not_faults hd hf
      · simp [z₀, hM'] at ht
      · simp [z₀, kM'] at hk
  have hc : Confluent rc Eq
      (fun x : γ => x.1.Faults L c ∨ racy x.1.mem.trace = true ∨ kept x.1.mem.trace = false) := by
    refine ⟨fun _ => rfl, Eq.symm, Eq.trans, ?_, ?_, ?_, ?_⟩
    · rintro a _ b rfl hr
      exact ⟨b, hr, rfl⟩
    · rintro a _ rfl hb
      exact hb
    · rintro ⟨a, ha⟩ ⟨b, hb⟩ hbad hr
      exact absurd hbad (nb a ha)
    · rintro ⟨a, ha⟩ ⟨b, hb⟩ ⟨c', hc'⟩ hr hr'
      rcases reach a ha with rfl | rfl
      · exact .inl (Subtype.ext ((Grid.step_one h hr).trans (Grid.step_one h hr').symm))
      · exact absurd hr (Grid.Done.final hd)
  exact Grid.sound_of_one_run (π := fun x : γ => x.1) (x₀ := ⟨g₀, .refl⟩)
    (z := ⟨z₀, .single hstep⟩) hc (fun hr => hr)
    (fun {x g'} hs => ⟨⟨g', x.2.tail hs⟩, hs, rfl⟩) (fun _ hf => .inl hf)
    (fun _ ht => .inr (.inl ht)) (fun _ hk => .inr (.inr hk))
    (fun he hd' => he ▸ hd') (fun he => he ▸ rfl) (.cons hstep (.nil _)) hd
    (nb z₀ (.single hstep)) hy hR

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

/-- If every thread's step returns at once without changing `M`, thread `n`'s step in
`retGrid N ts M D` marks it returned when it is below `N` and running, and is `none` otherwise. -/
theorem retGrid_advance (h : ∀ n, n < N → step (c n) (ts n) M = .ok (.done M)) (D : Nat → Bool)
    (n : Nat) :
    (retGrid N ts M D).advance c n =
      if n < N ∧ D n = false then .ok (some (retGrid N ts M (Function.update D n true)))
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

/-- **A grid of `N` returning threads is sound, by the one-run theorem.** If every thread `n < N`
returns in one step from memory `M` without changing it, the grid of these threads is sound
(all seven fields) for every observation defined on `M` and relation `R` its value satisfies,
when the trace of `M` has no race and keeps `!invariant.load`: the states are the sets of returned
threads, two threads' steps commute (the diamond, for every pair of threads), and the run in
thread order is the one run. For every `N`, launch and contexts. -/
theorem Grid.sound_returning (h : ∀ n, n < N → step (c n) (ts n) M = .ok (.done M))
    {β : Type} {obs : Mem → Option β} {R : β → Prop} {y : β} (hy : obs M = some y) (hR : R y)
    (hM : racy M.trace = false) (kM : kept M.trace = true) :
    Grid.Sound L c (retGrid N ts M fun _ => false) obs R := by
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
  have proj : ∀ {D D'}, rc D D' → Grid.Step L c (retGrid N ts M D) (retGrid N ts M D') := by
    rintro D _ ⟨n, hn, hD, rfl⟩
    exact ⟨n, .inl (by simp only [retGrid_advance h, hn, hD, and_self, ite_true])⟩
  have lift : ∀ {D g'}, Grid.Step L c (retGrid N ts M D) g' →
      ∃ D', rc D D' ∧ retGrid N ts M D' = g' := by
    rintro D g' ⟨n, hs | hs⟩
    · rw [retGrid_advance h] at hs
      split at hs
      · rename_i hcond
        cases hs
        exact ⟨_, ⟨n, hcond.1, hcond.2, rfl⟩, rfl⟩
      · cases hs
    · rw [retGrid_fire] at hs
      cases hs
  have nf : ∀ D, ¬ (retGrid N ts M D).Faults L c := by
    rintro D ⟨n, e, hf | hf⟩
    · rw [retGrid_advance h] at hf
      split at hf <;> cases hf
    · rw [retGrid_fire] at hf
      cases hf
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
  have hd : (retGrid N ts M fun i => decide (i < N)).Done := by
    rw [Grid.Done, Array.all_eq_true]
    intro i hi
    simp [retGrid]
  exact Grid.sound_of_one_run (π := retGrid N ts M) hc proj lift (fun D hf => nf D hf)
    (fun D ht => Bool.noConfusion (hM.symm.trans ht))
    (fun D hk => Bool.noConfusion (kM.symm.trans hk))
    (fun he hd' => he ▸ hd') (fun he => he ▸ rfl) run hd id hy hR

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

/-- A fold in `Except` whose step succeeds and keeps an invariant indexed by the number of
elements folded. -/
theorem foldlM_ok {α β ε : Type} {f : β → α → Except ε β} {P : Nat → β → Prop}
    (hP : ∀ k b a, P k b → ∃ b', f b a = .ok b' ∧ P (k + 1) b') :
    ∀ (xs : List α) (k : Nat) (b : β) {r : Except ε β}, xs.foldlM f b = r → P k b →
      ∃ b', r = .ok b' ∧ P (k + xs.length) b'
  | [], k, b, r, hr, hb => ⟨b, hr.symm, hb⟩
  | a :: xs, k, b, r, hr, hb => by
    obtain ⟨b1, h1, hb1⟩ := hP k b a hb
    rw [List.foldlM_cons, h1] at hr
    obtain ⟨b2, h2, hb2⟩ := foldlM_ok hP xs (k + 1) b1 hr hb1
    exact ⟨b2, h2, by simpa [Nat.add_assoc, Nat.add_comm 1] using hb2⟩

/-- The launch of `ret void` starts, for every launch, closed memory, address choice and oracle,
in a grid of `volume L.grid * volume L.block` running threads with an empty trace. -/
theorem start_ret (L : Launch) {m : Mem} (hm : m.Closed []) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (Program.ofFunc retFn) retFn L [] m ch oracle = .ok (g, c) ∧ g.mem.trace = [] ∧
      g.threads.size = volume L.grid * volume L.block ∧
      ∀ n, n < volume L.grid * volume L.block → g.threads[n]? = some (.run retThread) := by
  unfold Grid.start
  rw [Mem.checkClosed_of_closed hm]
  simp only [bind, Except.bind]
  have hck : Func.check (Program.ofFunc retFn).module retFn = Except.ok () := rfl
  split
  · rename_i e heq
    exact absurd (hck.symm.trans heq) (by simp)
  · split
    · rename_i e heq
      obtain ⟨b', hb', -⟩ := foldlM_ok
        (P := fun _ (b : Mem × List (List (String × Ptr))) =>
          ∀ c, b.1.next ≤ c → b.1.blocks c = none)
        (fun k b a hb => by
          obtain ⟨m, acc⟩ := b
          simp only at hb
          have h0 : m.blocks m.next = none := hb m.next le_rfl
          simp only [shared, Mem.allocNext, h0]
          refine ⟨_, rfl, fun c hc => ?_⟩
          simp only [Mem.alloc, Mem.set] at hc ⊢
          simp only [show c ≠ m.next by omega, ↓reduceIte]
          exact hb c (by omega)) _ 0 _ heq hm.above
      cases hb'
    · rename_i v1 heq1
      obtain ⟨m1, tabs⟩ := v1
      simp only
      split
      · rename_i e heq
        obtain ⟨b', hb', -⟩ := foldlM_ok (P := fun _ _ => True) (fun k b a _ => by
          obtain ⟨m, ts⟩ := b
          exact ⟨_, rfl, trivial⟩) _ 0 _ heq trivial
        cases hb'
      · rename_i v2 heq2
        obtain ⟨m2, ts⟩ := v2
        obtain ⟨b', hb', hsz, hall⟩ := foldlM_ok
          (P := fun k (b : Mem × Array Status) => b.2.size = k ∧
            ∀ n, n < k → b.2[n]? = some (.run retThread)) (fun k b a hb => by
          obtain ⟨m, ts⟩ := b
          refine ⟨(m, ts.push (.run retThread)), rfl, ?_, fun n hn => ?_⟩
          · simp [hb.1]
          · have hs : ts.size = k := hb.1
            rw [Array.getElem?_push]
            split
            · rfl
            · exact hb.2 n (by omega)) _ 0 _ heq2 ⟨rfl, fun n hn => by omega⟩
        cases hb'
        simp only [List.length_range, Nat.zero_add] at hsz hall
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
  exact Grid.sound_returning (fun n _ => step_retThread (c n) g.mem) rfl trivial
    (by rw [htr]; rfl) (by rw [htr]; rfl)

end Grid

end MojoProof.Sem
