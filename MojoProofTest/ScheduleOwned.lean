import MojoProof.Sem.ScheduleOwned
import MojoProofTest.Determinism

/-!
# Instances and twins of `Grid.confluent_owned`, `Grid.owned_bad`, `Grid.owned_clean` and `Grid.owned_sound` (T2′)

A checker, for every launch, contexts and Boolean property of grids: `every L c P f g` evaluates `P`
on every grid reachable from `g` within `f` steps and asks that none have a step after `f`, so every
grid reachable from `g` meets `P` (`every_sound`, with `mem_succs`: every step's grid is among
`succs`). `ownedB` is `Owned` as a Boolean (`ownedB_sound`); `discB c T own` asks every access a
thread would log to follow the discipline `(T, own)` or be to a block the thread owns, and one with
`!invariant.load` to be to an untiled block it does not own, and gives `hH` and `hI` for that
discipline (`discB_sound`, `disc_hyps`); `noFaultB` asks no step or fire to fault and gives
that the grid does not fault (`GPUProof.Faults` at `sig`, `noFaultB_sound`).

The instance with no tiled block, one kernel on one launch: `start2` of
MojoProofTest/Confluence.lean, two threads each at `%0 = alloca i32`, `store i32 7, ptr %0`,
`ret void`, on the empty memory. By evaluation every grid reachable from its start meets `discB`
with no tiled block and `own := id` (`local2`: each access is to a block its thread owns), so its
steps are confluent with the faults as the bad set (`confluent_owned2`), and on every reachable
grid the trace is not racy, keeps the promise of `!invariant.load`, and the grid is bad exactly
when it faults (`clean2`).

The tiled instance, one kernel on one launch: `cellK i16`, `@k(ptr addrspace(1) %0)` with
`%1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`,
`%2 = getelementptr inbounds i16, ptr addrspace(1) %0, i32 %1`,
`store i16 7, ptr addrspace(1) %2, align 1`, `ret void`, launched by `Grid.start` on two threads
(`two`) with a pointer to block 1, a caller's buffer of 4 bytes (`Close.mem none`). With
`T := cells`, block 1 tiled into two cells of 2 bytes (`Tiling.strided 0 2 2`), and `own := tileOf`,
by evaluation every reachable grid meets `discB`, each store being in its thread's cell, and does
not fault (`cells16`); so `hH`, `hI` and `hX` hold, its steps are confluent with the faults as the
bad set, and on every reachable grid the trace is not racy, keeps the promise of `!invariant.load`,
and the grid does not fault (`confluent_cells`). Its twin, `cellK i8`: the cells are one byte apart,
so the two stores of two bytes overlap; the grid after both threads' steps is reachable and its
trace is racy, so for every discipline whose tile map is injective on the two threads `hH` and `hI`
fail (`cells_twin`).

The instance of conclusion 3 (`Grid.owned_sound`), one kernel on one launch: the run of `cellK i16`
in which thread 0 takes its four steps and then thread 1 ends in `cellDone (.int 16)`, in which
every thread has returned; its trace meets `traceB` for `(cells, tileOf)` (the premises `hO`,
`hL`, `hX` and `hI` of `racy_kept_of_local` with no thread-local block, `traceB_sound` for every
discipline and trace),
so the start's grid is sound for bytes 0 to 3 of block 1, 7 and 7 as 16-bit words
(`cells_sound`). Its twin: the same schedule of `cellK i8` ends in a done grid whose trace is racy,
so it is bad, no discipline with thread-local blocks meets the premises on its trace, and the
start's grid is sound for no observation (`cells_sound_twin`).

The twin, one kernel on one launch of one thread, which shows that keeping the promise of
`!invariant.load` does not follow from safety and race freedom: `%0 = alloca i32`,
`%1 = load i32, ptr %0, !invariant.load`,
`store i32 7, ptr %0`, `ret void`. The `alloca` gives `g1` and the load gives `gL` (`stepsI`; the
load by unfolding `Layout.decode` once), so the grids
reachable from the start's are it, `g1` and those reachable from `gL` (`reachI`), and by evaluation
none reachable from `gL` faults or has a racy trace (`safeL`). After the four steps every thread
has returned and the trace breaks the promise of `!invariant.load`, so that grid is bad but does
not fault, and no discipline meets `hH` and `hI` on its launch (`inv_twin`).

The instance of the elementwise trace lemma (`racy_kept_of_cells`), on one trace, not a kernel
run: `elemTr o`, two threads, each an `!invariant.load` of its 4 bytes of block 2 and a store of
4 bytes at offset `o n` of block 1. With `o n = 4 n + 8` each store is in its thread's cell, so
the trace is not racy and keeps the promise (`elem_clean`); its tiling `elemCells` gives the same
race freedom by `racy_eq_false_of_owned` (`elem_owned`). Twins: with both stores at offset 8
the trace is racy (`elem_twin_cell`); with an `!invariant.load` of bytes that thread 0 stores,
the promise is broken (`elem_twin_inv`).
-/

namespace MojoProofTest.ScheduleOwned

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Confluence MojoProofTest.Determinism Relation
open GPUProof (Path Path.exists_iff Confluent)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-! ## The checker -/

/-- The grids of every step and fire of `g`'s threads that succeeds. -/
def succs (L : Launch) (c : Nat → Ctx) (g : Grid) : List Grid :=
  (List.range g.threads.size).flatMap fun n =>
    (match g.advance c n with | .ok (some g') => [g'] | _ => []) ++
      (match g.fire L c n with | .ok (some g') => [g'] | _ => [])

/-- Every step's grid is among `succs`, for every launch, contexts and grid. -/
theorem mem_succs {L : Launch} {c : Nat → Ctx} {g g' : Grid} (h : Grid.Step L c g g') :
    g' ∈ succs L c g := by
  obtain ⟨n, hn⟩ := h
  have hlt : n < g.threads.size := by
    by_contra hlt
    have h0 : g.threads[n]? = none := Array.getElem?_eq_none (Nat.le_of_not_lt hlt)
    rcases hn with hn | hn
    · obtain ⟨t, -, -, ht, -⟩ := Grid.advance_set hn
      rw [h0] at ht
      cases ht
    · obtain ⟨t, i, args, r, ht, -⟩ := Grid.fire_trace hn
      rw [h0] at ht
      cases ht
  refine List.mem_flatMap.2 ⟨n, List.mem_range.2 hlt, ?_⟩
  rcases hn with hn | hn <;> simp [hn]

/-- `P` holds on every grid reachable from `g` within `f` steps, and no grid reached in `f` steps
has a step. -/
def every (L : Launch) (c : Nat → Ctx) (P : Grid → Bool) : Nat → Grid → Bool
  | 0, g => P g && (succs L c g).all fun _ => false
  | f + 1, g => P g && (succs L c g).all (every L c P f)

/-- So `P` holds on every grid reachable from `g`, for every launch, contexts, property and
bound. -/
theorem every_sound {L : Launch} {c : Nat → Ctx} {P : Grid → Bool} {g z : Grid}
    (hr : ReflTransGen (Grid.Step L c) g z) : ∀ {f}, every L c P f g = true → P z = true := by
  induction hr using ReflTransGen.head_induction_on with
  | refl =>
    intro f h
    cases f <;> simp only [every, Bool.and_eq_true] at h <;> exact h.1
  | head hs _ ih =>
    intro f h
    cases f with
    | zero =>
      simp only [every, Bool.and_eq_true, List.all_eq_true] at h
      simpa using h.2 _ (mem_succs hs)
    | succ f =>
      simp only [every, Bool.and_eq_true, List.all_eq_true] at h
      exact ih (h.2 _ (mem_succs hs))

/-- Access `a` follows the discipline `(T, own)` (`Owned`), as a Boolean. -/
def ownedB {ι : Type} (T : Nat → Option (Tiling ι)) (own : Nat → ι) (a : Access) : Bool :=
  match T a.ptr.block with
  | none => !a.write
  | some t => decide ((t.off (own a.who.thread) : Int) ≤ a.ptr.off) &&
      decide (a.ptr.off + a.len ≤ t.off (own a.who.thread) + t.len (own a.who.thread))

/-- What `ownedB` says, for every discipline and access. -/
theorem ownedB_sound {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι} {a : Access}
    (h : ownedB T own a = true) : Owned T own a := by
  unfold ownedB at h
  split at h
  · rename_i hT
    exact ⟨fun _ => by simpa using h, fun t ht => by rw [hT] at ht; cases ht⟩
  · rename_i t hT
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    refine ⟨fun h' => ?_, fun t' ht => ?_⟩
    · rw [hT] at h'
      cases h'
    · rw [hT] at ht
      cases ht
      exact h

/-- Every access that a thread `n` of `g` would log follows the discipline `(T, own)` or is to a
block that `n` owns, and one with `!invariant.load` is to an untiled block that `n` does not
own. -/
def discB {ι : Type} (c : Nat → Ctx) (T : Nat → Option (Tiling ι)) (own : Nat → ι) (g : Grid) :
    Bool :=
  (List.range g.threads.size).all fun n => (g.pending c n).all fun
    | .access a =>
      let mine := (g.mem.blocks a.ptr.block).any (·.owner == Owner.thread n)
      (ownedB T own a || mine) && (!a.invariant || (T a.ptr.block).isNone && !mine)
    | _ => true

/-- What `discB` says, for every contexts, discipline and grid: the premises `hH` and `hI` of
`Grid.owned_clean` at `g`. -/
theorem discB_sound {ι : Type} {c : Nat → Ctx} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {g : Grid} (h : discB c T own g = true) {n : Nat} {a : Access}
    (ha : .access a ∈ g.pending c n) :
    (Owned T own a ∨ g.mem.Owned n a.ptr.block) ∧
      (a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block) := by
  have hn : n < g.threads.size := by
    by_contra hn
    have h0 : g.threads[n]? = none := Array.getElem?_eq_none (Nat.le_of_not_lt hn)
    simp [Grid.pending, h0] at ha
  have := List.all_eq_true.1 (List.all_eq_true.1 h n (List.mem_range.2 hn)) _ ha
  have hm : (g.mem.blocks a.ptr.block).any (·.owner == Owner.thread n) = true ↔
      g.mem.Owned n a.ptr.block := by
    simp only [Option.any_eq_true, beq_iff_eq, Mem.Owned]
  simp only [Bool.and_eq_true, Bool.or_eq_true, Bool.not_eq_true', Option.isNone_iff_eq_none,
    hm] at this
  obtain ⟨ho, hi⟩ := this
  refine ⟨ho.imp_left ownedB_sound, fun hv => ?_⟩
  rcases hi with hi | hi
  · rw [hv] at hi
    cases hi
  · refine ⟨hi.1, fun ho => ?_⟩
    rw [← hm, hi.2] at ho
    cases ho

/-- If every grid reachable from `g₀` meets `discB` for `(T, own)`, the hypotheses `hH` and `hI`
of `Grid.owned_clean` hold for `(T, own)`, for every launch, contexts and discipline. -/
theorem disc_hyps {L : Launch} {c : Nat → Ctx} {g₀ : Grid} {ι : Type}
    {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    (h : ∀ g, ReflTransGen (Grid.Step L c) g₀ g → discB c T own g = true) :
    (∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      Owned T own a ∨ g.mem.Owned n a.ptr.block) ∧
    (∀ g, ReflTransGen (Grid.Step L c) g₀ g → ∀ n a, .access a ∈ g.pending c n →
      a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block) :=
  ⟨fun _ hr _ _ ha => (discB_sound (h _ hr) ha).1, fun _ hr _ _ ha => (discB_sound (h _ hr) ha).2⟩

/-- No step or fire of a thread of `g` faults. -/
def noFaultB (L : Launch) (c : Nat → Ctx) (g : Grid) : Bool :=
  (List.range g.threads.size).all fun n =>
    (match g.advance c n with | .error _ => false | .ok _ => true) &&
      (match g.fire L c n with | .error _ => false | .ok _ => true)

/-- What `noFaultB` says, for every launch, contexts and grid: the grid does not fault. -/
theorem noFaultB_sound {L : Launch} {c : Nat → Ctx} {g : Grid} (h : noFaultB L c g = true) :
    ¬ GPUProof.Faults sig (g, L, c) := by
  intro hf
  obtain ⟨n, e, he⟩ := Grid.faults_iff.1 hf
  by_cases hn : n < g.threads.size
  · have := List.all_eq_true.1 h n (List.mem_range.2 hn)
    rcases he with he | he <;> simp [he] at this
  · have h0 : g.threads[n]? = none := Array.getElem?_eq_none (Nat.le_of_not_lt hn)
    rcases he with he | he <;> simp [Grid.advance, Grid.fire, h0, pure, Except.pure] at he

/-! ## The instance: `start2` -/

/-- Every grid reachable from `start2`'s meets `discB` with no tiled block and `own := id`: each
access is to a block its thread owns, without `!invariant.load`; the runs end within 6 steps. -/
theorem local2 :
    every two c2 (discB c2 (fun _ => (none : Option (Tiling Nat))) id) 6 run2.1 = true := by
  decide +kernel

/-- The instance of `Grid.confluent_owned`: with no tiled block and `own := id`, `start2`'s steps
are confluent with the faults as the bad set. -/
theorem confluent_owned2 :
    Confluent (fun x y : {g // ReflTransGen (Grid.Step two c2) run2.1 g} =>
      Grid.Step two c2 x.1 y.1) (fun x y => x.1.Same y.1)
      (fun x => GPUProof.Faults sig (x.1, two, c2)) :=
  have hD := disc_hyps fun _ hr => every_sound hr local2
  Grid.confluent_owned start2_eq (fun _ _ _ _ _ h => by cases h) hD.1 hD.2 fun _ _ _ _ h => h

/-- The instances of `Grid.owned_clean` and `Grid.owned_bad`: on every grid reachable from
`start2`'s the trace is not racy and keeps the promise of `!invariant.load`, and the grid is bad
exactly when it faults. -/
theorem clean2 : ∀ g, ReflTransGen (Grid.Step two c2) run2.1 g →
    GPUProof.racy sig (g.mem.trace.map (Event.toCore two)).reverse = false ∧
      GPUProof.kept sig (g.mem.trace.map (Event.toCore two)).reverse = true ∧
      (GPUProof.Bad sig (g, two, c2) ↔ GPUProof.Faults sig (g, two, c2)) :=
  fun _ hr =>
    have hD := disc_hyps fun _ hr => every_sound hr local2
    ⟨(Grid.owned_clean start2_eq hD.1 hD.2 (fun _ _ _ _ h => h) hr).1,
      (Grid.owned_clean start2_eq hD.1 hD.2 (fun _ _ _ _ h => h) hr).2,
      Grid.owned_bad start2_eq hD.1 hD.2 (fun _ _ _ _ h => h) hr, Or.inl⟩

/-! ## The tiled instance: two threads, each storing to its own cell of the caller's buffer -/

/-- The special register `%tid.x`'s intrinsic. -/
def tidName : String := "llvm.nvvm.read.ptx.sreg.tid.x"

/-- `declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()`. -/
def tidDecl : Func := { kern with name := tidName, ret := .int 32, names := #[], blocks := #[] }

/-- The kernel `@k(ptr addrspace(1) %0)` on cells of type `e`:
`%1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`,
`%2 = getelementptr inbounds e, ptr addrspace(1) %0, i32 %1`,
`store i16 7, ptr addrspace(1) %2, align 1`, `ret void`. -/
def cellK (e : Ty) : Func :=
  { kern with
    params := [⟨.ptr 1, [], some 0⟩],
    blocks := #[⟨0, #[{ res := some 1, inst := .call {} (.int 32) (.fn tidName) [] },
      { res := some 2, inst := .gep { inbounds := true } e ⟨.ptr 1, .loc 0⟩ [⟨.int 32, .loc 1⟩] },
      { res := none, inst := .store false ⟨.int 16, .int 7⟩ ⟨.ptr 1, .loc 2⟩ (some 1) }],
      .ret none⟩] }

/-- The program of `cellK e` and `tidDecl`, the declaration as the intrinsic `%tid.x`, with the
default data layout. -/
def cellP (e : Ty) : Program :=
  { kprog with
    module := { (default : Module) with funcs := #[cellK e, tidDecl] }
    intrinsics := [(tidName, .sreg .tid .x)] }

/-- The launch of `cellK e` on `two` with a pointer to block 1, of 4 bytes, on `Close.mem none`,
with address choice and oracle 0. -/
def cellStart (e : Ty) : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start (cellP e) (cellK e) two [.ptr ⟨1, 0⟩] (Close.mem none) (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `cellStart e`. -/
def cellRun (e : Ty) : Grid × (Nat → Ctx) :=
  match cellStart e with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨cellP e, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The tiling of block 1 into two cells of 2 bytes, and no tiling of the other blocks. -/
def cells (b : Nat) : Option (Tiling (Fin 2)) := if b = 1 then some (.strided 0 2 2) else none

/-- Every grid reachable from the start of `cellK i16` meets `discB` for `(cells, tileOf)`, thread
`n`'s store being to bytes `2 n` and `2 n + 1` of block 1, and does not fault; the runs end within
8 steps. -/
theorem cells16 :
    every two (cellRun (.int 16)).2 (fun g => discB (cellRun (.int 16)).2 cells tileOf g &&
      noFaultB two (cellRun (.int 16)).2 g) 8 (cellRun (.int 16)).1 = true := by
  decide +kernel

/-- **The tiled instance of `Grid.confluent_owned` and `Grid.owned_clean`** (one kernel, one
launch): the start of `cellK i16`, whose two threads store to the two cells of the caller's
buffer, with `T := cells` and `own := tileOf` (injective on the two threads): `hH` holds by the
tiled arm of the discipline, `hI` as no access has `!invariant.load`, and `hX`; so its steps are
confluent with the faults as the bad set, and every reachable grid has a trace that is not racy
and keeps the promise of `!invariant.load`, and does not fault. -/
theorem confluent_cells :
    Confluent (fun x y : {g // ReflTransGen (Grid.Step two (cellRun (.int 16)).2)
        (cellRun (.int 16)).1 g} => Grid.Step two (cellRun (.int 16)).2 x.1 y.1)
      (fun x y => x.1.Same y.1) (fun x => GPUProof.Faults sig (x.1, two, (cellRun (.int 16)).2)) ∧
    ∀ g, ReflTransGen (Grid.Step two (cellRun (.int 16)).2) (cellRun (.int 16)).1 g →
      GPUProof.racy sig (g.mem.trace.map (Event.toCore two)).reverse = false ∧
        GPUProof.kept sig (g.mem.trace.map (Event.toCore two)).reverse = true ∧
        ¬ GPUProof.Faults sig (g, two, (cellRun (.int 16)).2) :=
  have hs : cellStart (.int 16) = .ok ((cellRun (.int 16)).1, (cellRun (.int 16)).2) := rfl
  have hD := disc_hyps fun _ hr => by
    have := every_sound hr cells16
    simp only [Bool.and_eq_true] at this
    exact this.1
  have hX : ∀ n k, n < (cellRun (.int 16)).1.threads.size →
      k < (cellRun (.int 16)).1.threads.size → tileOf n = tileOf k → n = k := fun n k hn hk => by
    have e : (cellRun (.int 16)).1.threads.size = 2 := rfl
    have hd : ∀ n, n < 2 → ∀ k, k < 2 → tileOf n = tileOf k → n = k := by decide
    exact hd n (by omega) k (by omega)
  ⟨Grid.confluent_owned hs (Closed.mem_bytesIn none) hD.1 hD.2 hX, fun _ hr =>
    have hc := Grid.owned_clean hs hD.1 hD.2 hX hr
    ⟨hc.1, hc.2, noFaultB_sound (by
      have := every_sound hr cells16
      simp only [Bool.and_eq_true] at this
      exact this.2)⟩⟩

/-- The start of `cellK i8` after thread 0's three steps and then thread 1's: both stores done,
thread 0's to bytes 0 and 1 of block 1, thread 1's to bytes 1 and 2. -/
def overlap : Grid := advs (cellRun (.int 8)).2 (cellRun (.int 8)).1 [0, 0, 0, 1, 1, 1]

/-- **The twin of `confluent_cells`**: in `cellK i8` the cells are one byte apart, so the threads'
stores of two bytes overlap. `overlap` is reachable from the start and its trace is racy, so for
every discipline whose tile map is injective on the two threads, `hH` and `hI` fail. -/
theorem cells_twin :
    ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1 overlap ∧
    GPUProof.racy sig (overlap.mem.trace.map (Event.toCore two)).reverse = true ∧
    ∀ {ι : Type} (T : Nat → Option (Tiling ι)) (own : Nat → ι),
      (∀ n k, n < 2 → k < 2 → own n = own k → n = k) →
      ¬ ((∀ g, ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1 g →
          ∀ n a, .access a ∈ g.pending (cellRun (.int 8)).2 n →
            Owned T own a ∨ g.mem.Owned n a.ptr.block) ∧
        ∀ g, ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1 g →
          ∀ n a, .access a ∈ g.pending (cellRun (.int 8)).2 n →
            a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block) := by
  have hr : ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1 overlap :=
    Path.exists_iff.1 ⟨_, path_advs _ [0, 0, 0, 1, 1, 1] (by decide +kernel) (.nil _)⟩
  have hk : GPUProof.racy sig (overlap.mem.trace.map (Event.toCore two)).reverse = true :=
    by decide +kernel
  refine ⟨hr, hk, fun T own hX ⟨hH, hI⟩ => ?_⟩
  have e : (cellRun (.int 8)).1.threads.size = 2 := rfl
  have := (Grid.owned_clean
    (show cellStart (.int 8) = .ok ((cellRun (.int 8)).1, (cellRun (.int 8)).2) from rfl) hH hI
    (fun n k hn hk => hX n k (by omega) (by omega)) hr).1
  rw [hk] at this
  cases this

/-! ## Conclusion 3: one run, and the discipline of its trace -/

/-- The premises `hO`, `hL`, `hX` and `hI` of `racy_kept_of_local` with no block local to a
thread, as a Boolean, on a trace `tr`: every access follows `(T, own)` (`ownedB`) without
`!invariant.load`, and two accesses to one tiled block by threads of one tile are by one
thread. -/
def traceB {ι : Type} [DecidableEq ι] (T : Nat → Option (Tiling ι)) (own : Nat → ι)
    (tr : List Event) : Bool :=
  tr.all fun
    | .access a => ownedB T own a && !a.invariant && tr.all fun
      | .access e => !(a.ptr.block == e.ptr.block && (T a.ptr.block).isSome &&
          own a.who.thread == own e.who.thread) || a.who.thread == e.who.thread
      | _ => true
    | _ => true

/-- What `traceB` says, for every discipline and trace: the premises `hO`, `hL`, `hX` and `hI` of
`racy_kept_of_local` with no block local to a thread (`loc := fun _ _ => False`). -/
theorem traceB_sound {ι : Type} [DecidableEq ι] {T : Nat → Option (Tiling ι)} {own : Nat → ι}
    {tr : List Event} (h : traceB T own tr = true) :
    (∀ a, Event.access a ∈ tr → (∀ w, ¬ (fun _ _ => False : Nat → Nat → Prop) a.ptr.block w) →
      Owned T own a) ∧
    (∀ a w, Event.access a ∈ tr → (fun _ _ => False : Nat → Nat → Prop) a.ptr.block w →
      a.who.thread = w) ∧
    (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
        a.who.thread = e.who.thread) ∧
    (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.invariant = true →
      e.write = true → a.ptr.block ≠ e.ptr.block) := by
  have hA : ∀ a, Event.access a ∈ tr → ownedB T own a = true ∧ a.invariant = false ∧
      ∀ e, Event.access e ∈ tr → a.ptr.block = e.ptr.block → T a.ptr.block ≠ none →
        own a.who.thread = own e.who.thread → a.who.thread = e.who.thread := by
    intro a ha
    have h₁ := List.all_eq_true.1 h _ ha
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at h₁
    refine ⟨h₁.1.1, h₁.1.2, fun e he hb hT ho => ?_⟩
    have h₂ := List.all_eq_true.1 h₁.2 _ he
    have hT' : (T e.ptr.block).isSome = true := hb ▸ Option.isSome_iff_ne_none.2 hT
    simp only [hb, hT', ho, beq_self_eq_true, Bool.and_true, Bool.not_true, Bool.false_or,
      beq_iff_eq] at h₂
    exact h₂
  exact ⟨fun a ha _ => ownedB_sound (hA a ha).1, fun _ _ _ h => h.elim,
    fun a e ha he hb hT ho => (hA a ha).2.2 e he hb hT ho,
    fun a _ ha _ hi => by rw [(hA a ha).2.1] at hi; cases hi⟩

/-- The start of `cellK e` after every thread's four steps, thread 0's first: both threads have
stored and returned. -/
def cellDone (e : Ty) : Grid := advs (cellRun e).2 (cellRun e).1 [0, 0, 0, 0, 1, 1, 1, 1]

/-- Bytes 0 to 3 of block 1, the caller's buffer of `cellStart`. -/
def obs1 (m : Mem) : Option (List MemByte) := (m.blocks 1).map (·.read 0 4)

/-- **The instance of `Grid.owned_sound`** (conclusion 3 of T2′, one kernel, one launch): the run
of `cellK i16` to `cellDone (.int 16)`, every thread returned, whose trace follows `(cells, tileOf)`
with no thread-local block (`traceB`, by evaluation) and whose block 1 holds 7 and 7 as 16-bit
words, makes the start's grid sound for those bytes. -/
theorem cells_sound :
    Grid.Sound two (cellRun (.int 16)).2 (cellRun (.int 16)).1 obs1
      (· = leBytes 2 7 ++ leBytes 2 7) :=
  have hk := traceB_sound (show traceB cells tileOf (cellDone (.int 16)).mem.trace = true by
    decide +kernel)
  Grid.owned_sound (T := cells) (own := tileOf) (z := cellDone (.int 16))
    (loc := fun _ _ => False) (show cellStart (.int 16) = .ok ((cellRun (.int 16)).1, (cellRun (.int 16)).2)
      from rfl) (Closed.mem_bytesIn none) (fun m m' h => by simp only [obs1, h])
    (path_advs _ [0, 0, 0, 0, 1, 1, 1, 1] (by decide +kernel) (.nil _))
    (Grid.done_of_all (by decide +kernel))
    hk.1 hk.2.1 hk.2.2.1 hk.2.2.2 (by decide +kernel) rfl

/-- **The twin of `cells_sound`**: in `cellK i8` the threads' stores of two bytes overlap, so the
done grid of the same schedule is reachable, every thread has returned, its trace is racy and the
grid is bad; no discipline `(T, own)` with thread-local blocks `loc` meets the premises of
`Grid.owned_sound` on its trace, and the start's grid is sound for no observation. -/
theorem cells_sound_twin :
    ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1 (cellDone (.int 8)) ∧
    GPUProof.Done sig (cellDone (.int 8), two, (cellRun (.int 8)).2) ∧
    GPUProof.racy sig ((cellDone (.int 8)).mem.trace.map (Event.toCore two)).reverse = true ∧
    GPUProof.Bad sig (cellDone (.int 8), two, (cellRun (.int 8)).2) ∧
    (∀ {ι : Type} (T : Nat → Option (Tiling ι)) (own : Nat → ι) (loc : Nat → Nat → Prop),
      let tr := (cellDone (.int 8)).mem.trace
      ¬ ((∀ a, Event.access a ∈ tr → (∀ w, ¬ loc a.ptr.block w) → Owned T own a) ∧
        (∀ a w, Event.access a ∈ tr → loc a.ptr.block w → a.who.thread = w) ∧
        (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
          T a.ptr.block ≠ none → own a.who.thread = own e.who.thread →
            a.who.thread = e.who.thread) ∧
        (∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.invariant = true →
          e.write = true → a.ptr.block ≠ e.ptr.block))) ∧
    ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
      ¬ Grid.Sound two (cellRun (.int 8)).2 (cellRun (.int 8)).1 obs R := by
  have hr : ReflTransGen (Grid.Step two (cellRun (.int 8)).2) (cellRun (.int 8)).1
      (cellDone (.int 8)) :=
    Path.exists_iff.1 ⟨_, path_advs _ [0, 0, 0, 0, 1, 1, 1, 1] (by decide +kernel) (.nil _)⟩
  have hd : GPUProof.Done sig (cellDone (.int 8), two, (cellRun (.int 8)).2) :=
    Grid.done_of_all (by decide +kernel)
  have hk : GPUProof.racy sig ((cellDone (.int 8)).mem.trace.map (Event.toCore two)).reverse =
      true := by decide +kernel
  have hf := Grid.start_reach_fits
    (show cellStart (.int 8) = .ok ((cellRun (.int 8)).1, (cellRun (.int 8)).2) from rfl) hr
  refine ⟨hr, hd, hk, (Grid.Done.bad_iff (by decide +kernel) hd).2 (.inl hk),
    fun T own loc ⟨hO, hL, hX, hI⟩ => ?_,
    fun obs R hS => ?_⟩
  · have := racy_eq_false_of_local hf.trace hf.2 hO hL hX
    rw [hk] at this
    cases this
  · have := hS.raceFree _ hr
    rw [hk] at this
    cases this

/-! ## The twin: an `!invariant.load`, then a store to its bytes -/

/-- `%0 = alloca i32`, `%1 = load i32, ptr %0, !invariant.load`, `store i32 7, ptr %0`. -/
def invStore : Array Stmt :=
  #[{ res := some 0, inst := .alloca (.int 32) none none },
    { res := some 1, inst := .load false (.int 32) ⟨.ptr 0, .loc 0⟩ none,
      md := [("invariant.load", 0)] },
    { res := none, inst := .store false ⟨.int 32, .int 7⟩ ⟨.ptr 0, .loc 0⟩ none }]

/-- The kernel `@k`: `invStore`, then `ret void`. -/
def kernI : Func := { kern with blocks := #[⟨0, invStore, .ret none⟩] }

/-- The program of `kernI` alone, with the default data layout. -/
def progI : Program := { kprog with module := { (default : Module) with funcs := #[kernI] } }

/-- The launch of `kernI` on one thread on the empty memory, with address choice and oracle 0. -/
def startI : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start progI kernI .one [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `startI`. -/
def runI : Grid × (Nat → Ctx) :=
  match startI with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨progI, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The start's contexts. -/
def cI : Nat → Ctx := runI.2

/-- The launch starts, at `runI`. -/
theorem startI_eq : startI = .ok (runI.1, cI) := rfl

/-- `startI`'s grid after the `alloca`. -/
def g1 : Grid := adv cI runI.1 0

/-- The thread of `g1`. -/
def t1 : Thread := match g1.threads[0]? with | some (Status.run t) => t | _ => ⟨[], 0⟩

/-- The frame of `t1`. -/
def f1 : Frame := match t1.frames with
  | f :: _ => f
  | [] => ⟨kernI, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- The pointer in register 0 of `f1`, to the `alloca`'s block. -/
def q1 : Ptr := match f1.regs 0 with | some (.ptr p) => p | _ => ⟨0, 0⟩

/-- `g1` after the `!invariant.load`: `undef` in register 1, and the load's read of bytes 0 to 3
of the `alloca`'s block, with `!invariant.load`, logged. -/
def gL : Grid :=
  { threads := g1.threads.set! 0 (.run ⟨[{ f1.set (some 1) (some .undef) none with pc := 2 }],
      t1.k + 1⟩),
    mem := g1.mem.log (.access ⟨(cI 0).who, q1, 4, false, none, true⟩) }

/-- The `alloca` of `startI`'s grid gives `g1`, and the load of `g1` gives `gL`. The load is
evaluated after unfolding `Layout.decode` once. -/
theorem stepsI : runI.1.advance cI 0 = .ok (some g1) ∧ g1.advance cI 0 = .ok (some gL) :=
  ⟨rfl, by
    simp only [Grid.advance, step, exec, Mem.load, Layout.decode.eq_def]
    rfl⟩

/-- The grids reachable from `startI`'s: it, `g1`, and those reachable from `gL`. -/
theorem reachI {z : Grid} (h : ReflTransGen (Grid.Step .one cI) runI.1 z) :
    z = runI.1 ∨ z = g1 ∨ ReflTransGen (Grid.Step .one cI) gL z := by
  rcases h.cases_head with rfl | ⟨y, hy, h⟩
  · exact .inl rfl
  have hs : succs .one cI runI.1 = [g1] := rfl
  have e := mem_succs hy
  rw [hs, List.mem_singleton] at e
  subst e
  rcases h.cases_head with rfl | ⟨y, hy, h⟩
  · exact .inr (.inl rfl)
  have hs : succs .one cI g1 = [gL] := by
    simp only [succs, show g1.threads.size = 1 from rfl, show List.range 1 = [0] from rfl,
      List.flatMap_cons, List.flatMap_nil, stepsI.2, show g1.fire .one cI 0 = .ok none from rfl,
      List.append_nil]
  have e := mem_succs hy
  rw [hs, List.mem_singleton] at e
  subst e
  exact .inr (.inr h)

/-- `gL` after the store and the `ret`. -/
def doneI : Grid := advs cI gL [0, 0]

/-- No grid reachable from `gL` faults or has a racy trace; the runs end within 2 steps. -/
theorem safeL :
    every .one cI (fun g => noFaultB .one cI g &&
      !GPUProof.racy sig (g.mem.trace.map (Event.toCore .one)).reverse) 2 gL = true := by
  decide +kernel

/-- **The twin** (`Grid.Kept` does not follow from `Grid.Safe` and `Grid.RaceFree`): no grid
reachable from
`startI`'s faults or has a racy trace, but after the thread's four steps, reachable, every thread
has returned and the store has written the bytes of the `!invariant.load`, so the trace breaks its
promise; that grid is bad and does not fault, so `Grid.owned_bad`'s conclusion fails there, and no
discipline meets `hH` and `hI` on `startI`'s launch. -/
theorem inv_twin : ReflTransGen (Grid.Step .one cI) runI.1 doneI ∧
    GPUProof.Done sig (doneI, Launch.one, cI) ∧
    (∀ g, ReflTransGen (Grid.Step .one cI) runI.1 g →
      ¬ GPUProof.Faults sig (g, Launch.one, cI) ∧
        GPUProof.racy sig (g.mem.trace.map (Event.toCore Launch.one)).reverse = false) ∧
    GPUProof.kept sig (doneI.mem.trace.map (Event.toCore Launch.one)).reverse = false ∧
    GPUProof.Bad sig (doneI, Launch.one, cI) ∧
    ¬ GPUProof.Faults sig (doneI, Launch.one, cI) ∧
    ∀ {ι : Type} (T : Nat → Option (Tiling ι)) (own : Nat → ι),
      ¬ ((∀ g, ReflTransGen (Grid.Step .one cI) runI.1 g → ∀ n a, .access a ∈ g.pending cI n →
          Owned T own a ∨ g.mem.Owned n a.ptr.block) ∧
        ∀ g, ReflTransGen (Grid.Step .one cI) runI.1 g → ∀ n a, .access a ∈ g.pending cI n →
          a.invariant = true → T a.ptr.block = none ∧ ¬ g.mem.Owned n a.ptr.block) := by
  have hr : ReflTransGen (Grid.Step .one cI) runI.1 doneI :=
    .head ⟨0, .inl stepsI.1⟩ (.head ⟨0, .inl stepsI.2⟩
      (Path.exists_iff.1 ⟨_, path_advs gL [0, 0] rfl (.nil _)⟩))
  have h1 : noFaultB .one cI g1 = true := by
    simp only [noFaultB, show g1.threads.size = 1 from rfl, show List.range 1 = [0] from rfl,
      List.all_cons, List.all_nil, stepsI.2, show g1.fire .one cI 0 = .ok none from rfl,
      Bool.and_true]
  have hS : ∀ g, ReflTransGen (Grid.Step .one cI) runI.1 g →
      ¬ GPUProof.Faults sig (g, Launch.one, cI) ∧
        GPUProof.racy sig (g.mem.trace.map (Event.toCore Launch.one)).reverse = false :=
      fun _ hg => by
    rcases reachI hg with rfl | rfl | hg
    · exact ⟨noFaultB_sound (by decide +kernel), by decide +kernel⟩
    · exact ⟨noFaultB_sound h1, by decide +kernel⟩
    · have := every_sound hg safeL
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at this
      exact ⟨noFaultB_sound this.1, this.2⟩
  have hk : GPUProof.kept sig (doneI.mem.trace.map (Event.toCore Launch.one)).reverse = false := by
    decide +kernel
  refine ⟨hr, Grid.done_of_all rfl, hS, hk, .inr (.inr (.inl hk)), (hS _ hr).1,
    fun T own hD => ?_⟩
  obtain ⟨hH, hI⟩ := hD
  have := (Grid.owned_clean startI_eq hH hI (fun n k h₁ h₂ _ => by
    have e : runI.1.threads.size = 1 := rfl
    omega) hr).2
  rw [hk] at this
  cases this


/-- Thread `n` of an elementwise kernel, in block of threads 0, newest first: an
`!invariant.load` of 4 bytes at offset `4 n` of block 2 (an input), then a store of 4 bytes at
offset `o n` of block 1 (the output). -/
def elemAcc (o : Nat → Int) (n : Nat) : List Event :=
  [.access ⟨⟨n, 0⟩, ⟨1, o n⟩, 4, true, none, false⟩,
    .access ⟨⟨n, 0⟩, ⟨2, 4 * n⟩, 4, false, none, true⟩]

/-- Threads 1 and 0 of the elementwise kernel, thread 1's accesses newest. -/
def elemTr (o : Nat → Int) : List Event := elemAcc o 1 ++ elemAcc o 0

/-- The four accesses of `elemTr o`. -/
theorem mem_elemTr {o : Nat → Int} {a : Access} (h : Event.access a ∈ elemTr o) :
    a = ⟨⟨1, 0⟩, ⟨1, o 1⟩, 4, true, none, false⟩ ∨ a = ⟨⟨1, 0⟩, ⟨2, 4⟩, 4, false, none, true⟩ ∨
      a = ⟨⟨0, 0⟩, ⟨1, o 0⟩, 4, true, none, false⟩ ∨
        a = ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, false, none, true⟩ := by
  simpa [elemTr, elemAcc] using h

/-- The premises of `racy_iff` on `elemTr` with the stores at offsets `4 n + 8`, at `two`: every
access is by a thread of `two` in its block of threads, and the trace is shaped
(`Trace.Shaped`, oldest first). -/
theorem elem_fits :
    (∀ a, Event.access a ∈ elemTr (4 * · + 8) → a.who.thread < volume two.grid * volume two.block ∧
      a.who.cta = a.who.thread / volume two.block) ∧ Trace.Shaped (elemTr (4 * · + 8)).reverse := by
  refine ⟨fun a ha => ?_, fun a ha hi => ?_, fun p a hp ho _ => ?_⟩
  · rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;> decide
  · rcases mem_elemTr (List.mem_reverse.1 ha) with rfl | rfl | rfl | rfl <;> revert hi <;> decide
  · rcases mem_elemTr (List.mem_reverse.1 (List.mem_of_getElem? hp)) with rfl | rfl | rfl | rfl <;>
      simp at ho

/-- **Instance of `racy_kept_of_cells`** (one trace): at `two`, with the stores at offsets
`4 n + 8`, each in its thread's cell of 4 bytes from `4 n + 8`, the trace of the two threads is
not racy (it has the premises of `racy_iff`, `elem_fits`) and keeps the promise of
`!invariant.load`. The cells start at 8, not at `4 n`, so `racy_kept_pointwise` does not
apply. -/
theorem elem_clean :
    GPUProof.racy sig ((elemTr (4 * · + 8)).map (Event.toCore two)).reverse = false ∧
      GPUProof.kept sig ((elemTr (4 * · + 8)).map (Event.toCore two)).reverse = true :=
  have h := racy_kept_of_cells (L := two) (out := 1) (w := 4) (cell := (4 * · + 8))
    (fun i j h => by beta_reduce; omega)
    (fun a ha => by rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;> decide)
    (fun a ha => by rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;> decide)
    (fun a ha => by rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;> decide)
  ⟨h.1 elem_fits.1 elem_fits.2, h.2⟩

/-- The tiling of `elemTr`'s output: block 1 in two cells of 4 bytes from offset 8. -/
def elemCells (b : Nat) : Option (Tiling (Fin 2)) := if b = 1 then some (.strided 8 2 4) else none

/-- **Instance of `racy_eq_false_of_owned`** on the same trace, at `two`: it has the premises of
`racy_iff` (`elem_fits`), every access follows `(elemCells, tileOf)` (`ownedB`, by evaluation),
and threads with one tile are one thread, so the trace is not racy, as `elem_clean` says. -/
theorem elem_owned :
    GPUProof.racy sig ((elemTr (4 * · + 8)).map (Event.toCore two)).reverse = false :=
  racy_eq_false_of_owned (T := elemCells) (own := tileOf) elem_fits.1 elem_fits.2
    (fun a ha => ownedB_sound (by
      rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;> decide +kernel))
    fun a e ha he _ _ ho => by
      rcases mem_elemTr ha with rfl | rfl | rfl | rfl <;>
        rcases mem_elemTr he with rfl | rfl | rfl | rfl <;>
        first | rfl | exact absurd ho (by decide)

/-- **Twin of the cell premise**: at `two`, with both stores at offset 8, thread 1's store is
outside its cell, and the trace is racy. -/
theorem elem_twin_cell :
    GPUProof.racy sig ((elemTr fun _ => 8).map (Event.toCore two)).reverse = true := by
  decide +kernel

/-- **Twin of the `!invariant.load` premise**: after a further `!invariant.load` of the output's
bytes 8 to 11, which thread 0 stores, the trace breaks the promise of `!invariant.load`. -/
theorem elem_twin_inv :
    GPUProof.kept sig ((.access ⟨⟨0, 0⟩, ⟨1, 8⟩, 4, false, none, true⟩ :: elemTr (4 * · + 8)).map
      (Event.toCore Launch.one)).reverse = false := by
  decide +kernel

end MojoProofTest.ScheduleOwned
