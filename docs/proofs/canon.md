# The canonical run: warps in turn (`CanonRun`) and the phase level (`PhaseRun`)

Lean: `MojoProof/Sym/Canon.lean`, on top of `Seq`, `Seq.ToWait`, `Turns` and `Grid.fire_shfl`
(`MojoProof/Sym/Sched.lean`, `MojoProof/Sym/SchedWait.lean`), and `MojoProof/Sym/CanonBar.lean`
for the phase level and the one-level run's done grid and soundness. Instances:
`MojoProofTest/SymCanon.lean`, `MojoProofTest/GemvWarp.lean`, `MojoProofTest/SymCanonBar.lean`,
`MojoProofTest/SymColl.lean` and `MojoProofTest/SymChain.lean`.

**Scope.** Every definition and theorem is for every program, launch, contexts, thread and
memory. The instances are for one hand-built kernel at block sizes 40 and 70 (at 40 with the
shuffle declared without result attributes and with `noundef`, at 70 without), for gemv_kernel
at three launches with `K = 0` and two with one round of the loop, `K = 4` and `K = 3`
(docs/proofs/gemv.md), for a kernel with one barrier at one block of 34 threads and two of 6,
and for a kernel with a barrier and two shuffles at one block of four threads and at 4 and at 8
threads.

## The schedule

A launch's threads are numbered `0` to `N - 1`, `N = volume L.grid * volume L.block`. A warp is
named by its first thread `k` (`k % volume L.block % 32 = 0`). Its lanes are `warpLanes L k`
(`Grid.fire`'s lanes: the `j < 32` with thread `k + j` in `k`'s block), its threads
`warpThreads L k`:

```lean
def warpThreads (L : Launch) (k : Nat) : List Nat := (warpLanes L k).map (k + ·)
def warps (L : Launch) (N : Nat) : List Nat :=
  (List.range N).filter fun k => k % volume L.block % 32 = 0
```

`warpLanes L k` is `List.range (min 32 (volume L.block - (k % volume L.block -
k % volume L.block % 32)))` (`warpLanes_eq`): a last warp of a block has fewer than 32 lanes.

The canonical run takes the warps in turn. Within a warp, the lanes run in turn to their next
collective call (`Seq.ToWait`); once the last lane waits, the warp's shuffle fires
(`Grid.fire_shfl` at the warp's first thread) and resumes every lane with the value
`Grid.fire` delivers; this repeats until every lane of the warp has run to its end (`Seq`). Each
warp has its own number of shuffles: a warp that branches around a shuffle has one phase less.

A warp's shuffle, on lane-indexed statuses `s` (lane `j`'s is `s j`), memory `m`, threads `u`
and deliveries `r`:

```lean
def WarpShfl (L : Launch) (c : Nat → Ctx) (k : Nat) (s : Nat → Status) (m : Mem)
    (u : Nat → Thread) (r : Nat → Option Val) : Prop :=
  ∃ (mode : Shfl) (M A B C : Nat → Val) (b cl : Nat → Nat) (d : Nat → Func),
    ∀ j ∈ warpLanes L k, s j = .wait (u j) (.shfl mode) [M j, A j, B j, C j] (d j) ∧
      (M j).word? = some (2 ^ 32 - 1) ∧ (B j).word? = some (b j) ∧
      (C j).word? = some (cl j) ∧ (u j).at = (u 0).at ∧
      (some (shflVal (warpLanes L k) A (shflSource mode j (b j) (cl j)))).mapM
        (withAttrs (c k).prog.layout m (d j).ret (d j).retAttrs) = .ok (r j)
```

Each premise is one of `Grid.fire`'s checks for `.shfl`: every lane waits at a shuffle of one
mode with the full member mask, defined lane and clamp operands, at the instruction lane 0 is
at; `r j` is what the callee's return attributes make of the value `shflVal` reads (lane
`shflSource mode j (b j) (cl j)`'s offer, `poison` when that lane is not one of the warp's).
The deliveries are therefore `Grid.fire`'s, never inputs.

```lean
inductive WarpRun (L : Launch) (c : Nat → Ctx) (k : Nat) :
    (Nat → Thread) → Mem → List (List Event) → Mem → Prop
  | ends : Seq c t (warpThreads L k) m Es m' → WarpRun L c k t m Es m'
  | shfl : Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m₁ →
      WarpShfl L c k s m₁ u r →
      WarpRun L c k (fun n => (u (n - k)).resume (r (n - k))) m₁ Es' m' →
      WarpRun L c k t m (Es ++ Es') m'

inductive CanonRun (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) :
    List Nat → Mem → List (List Event) → Mem → Prop
  | nil (m : Mem) : CanonRun L c t [] m [] m
  | cons : WarpRun L c k t m Es m₁ → CanonRun L c t ks m₁ Es' m' →
      CanonRun L c t (k :: ks) m (Es ++ Es') m'
```

`Es` lists each lane's events in the order the lanes ran, as in `Seq`; a shuffle logs none.

## The run in the grid

```lean
theorem warpThreads_iff (hs : 0 < volume L.block) (hk : k % volume L.block % 32 = 0) :
    n ∈ warpThreads L k ↔ n - n % volume L.block % 32 = k

theorem WarpRun.trace (h : WarpRun L c k t m Es m') : m'.trace = Es.reverse.flatten ++ m.trace
theorem CanonRun.trace (h : CanonRun L c t ks m Es m') : m'.trace = Es.reverse.flatten ++ m.trace

theorem WarpRun.grid (hs : 0 < volume L.block) (hk : k % volume L.block % 32 = 0)
    (h : WarpRun L c k t m Es m') :
    ∀ {g : Grid}, (∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(warpThreads L k).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩

theorem CanonRun.grid (hs : 0 < volume L.block) (h : CanonRun L c t ks m Es m') :
    ∀ {g : Grid}, ks.Nodup → (∀ k ∈ ks, k % volume L.block % 32 = 0) →
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(ks.flatMap (warpThreads L)).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩
```

`WarpRun.grid` is by induction on the run: `Seq.grid` for `ends`; for `shfl`,
`Seq.ToWait.grid` to the grid with the warp's lanes at `s`, then `Grid.fire_shfl` at thread `k`
(its premises are `WarpShfl`'s, at the threads `k - k % volume L.block % 32 + j = k + j`), then
the rest of the run; the two folds over the warp's threads give the same array as one fold to
`.done` (`foldl_set_getElem?`). `CanonRun.grid` composes the warps: distinct first threads have
disjoint threads (`warpThreads_iff`), so each warp starts from the threads `t` gives
(`warps_grid_cons`, the step of one warp for every statuses the warps end at, which
`CanonWait.grid` shares). The run over every warp to a done grid (`CanonRun.done`) is the phase
level's (`PhaseRun.done`, below).

## Soundness

```lean
theorem CanonRun.done (hs : 0 < volume L.block) {g : Grid}
    (hN : g.threads.size % volume L.block = 0)
    (h : CanonRun L c t (warps L g.threads.size) g.mem Es m')
    (hg : ∀ n < g.threads.size, g.threads[n]? = some (.run (t n))) :
    ∃ z, (∃ i, Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ g.mem.trace

theorem CanonRun.start_done (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hs : 0 < volume L.block)
    (hc : CanonRun L c (Grid.thread g₀) (warps L g₀.threads.size) g₀.mem Es m') :
    ∃ z, (∃ i, Path (Grid.Step L c) i g₀ z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m'

theorem CanonRun.start_sound (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hs : 0 < volume L.block)
    (hc : CanonRun L c (Grid.thread g₀) (warps L g₀.threads.size) g₀.mem Es m')
    (hr : ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
      GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false))
    (hk : GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true)
    (hy : obs m' = some y) (hR : R y) : Grid.Sound L c g₀ obs R
```

The three are in `CanonBar.lean`, corollaries of the phase level's: a run over the warps of
whole blocks is a `PhaseRun` of one phase per block (`PhaseRun.of_canon`, below), and
`PhaseRun.done`, `PhaseRun.start_done` and `PhaseRun.start_sound` conclude. `CanonRun.done`
takes the `g.threads.size / volume L.block` blocks (`hN`); the start's grid has
`volume L.grid * volume L.block` threads (`Grid.start_size`). `CanonRun.start_done` is the done
grid alone: a canonical run from the start reaches a done grid with the run's memory, the
conclusion the instances state about the output's cells (MojoProofTest/GemvWarp.lean).
`CanonRun.start_sound` passes its four premises past the run as `PhaseRun.start_sound`'s
`EndChecks`. Both soundness proofs end in `Grid.start_done_sound`
(MojoProof/Sym/SchedWait.lean): a start that steps to a done grid whose memory is kept, race-free
under `racy_iff`'s premises and observed as `y` with `R y` is sound, by `Grid.Done.bad_iff`,
`Grid.start_reach_fits` and `Grid.start_sound`, which is Theorem 0 at `sig`.

## Per-thread run predicates

The run is built from predicates on each lane's runs, with no grid:

```lean
theorem WarpRun.of_inv {J : Nat} {T : Nat → Nat → Thread → Prop}
    {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ t m, T i j t → P i j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W i j s ∧ P i (j + 1) m')
    (hf : ∀ i < J, ∀ s : Nat → Status, (∀ j ∈ warpLanes L k, W i j (s j)) →
      ∀ m, P i (warpLanes L k).length m → ∃ u r, WarpShfl L c k s m u r ∧
        (∀ j ∈ warpLanes L k, T (i + 1) j ((u j).resume (r j))) ∧ P (i + 1) 0 m)
    (he : ∀ j ∈ warpLanes L k, ∀ t m, T J j t → P J j m →
      ∃ m', Runs (c (k + j)) t m m' ∧ P J (j + 1) m')
    {t : Nat → Thread} (ht : ∀ j ∈ warpLanes L k, T 0 j (t (k + j))) {m : Mem}
    (hm : P 0 0 m) : ∃ Es m', WarpRun L c k t m Es m' ∧ P J (warpLanes L k).length m'

theorem CanonRun.of_inv {P : Nat → Mem → Prop} :
    ∀ {ks : List Nat}, (∀ i (hi : i < ks.length), ∀ m, P i m →
      ∃ Es m', WarpRun L c ks[i] t m Es m' ∧ P (i + 1) m') →
    ∀ {m : Mem}, P 0 m → ∃ Es m', CanonRun L c t ks m Es m' ∧ P ks.length m'
```

`J` is the warp's own number of shuffles; `T i j`, `W i j` and `P i j` are lane `j`'s thread and
status and the memory after `j` lanes of phase `i`. `hf` is the shuffle's fire from every
statuses the phase's runs can leave. `WarpRun.of_inv` is `Seq.ToWait.of_inv` and `Seq.of_inv` on
the lanes `List.range (warpLanes L k).length` (`warpLanes_eq`), moved onto the warp's threads by
`Seq.ToWait.warp` and `Seq.warp` (`Turns.map`), by induction on the phases left (`warp_of_inv`).

## From lanes' runs through their waits

`RunsVia.of_fires` concludes a lane's run through the waits `Piece.walk` records
(`RunsVia` with `Piece.Wait.via`'s predicates), then through a continuation's waits, to a memory
of a final predicate `Q V A`. `V` is the valuation after the block (`Piece.after`) and `A` the
frame's `alloca` blocks then (`Piece.allocs` in front of the entry frame's), so a continuation
that returns states its end memory: `Runs.of_retMem` (MojoProof/Sym/Loop.lean) runs a path that
`retB` accepts to `Valuation.retMem`, the last block's effects with the path's and `A`'s blocks
dead. `WarpRun.of_waits` makes those runs a warp's run:

```lean
theorem WarpRun.of_waits {J : Nat} {fn : Func} {lbl : Nat → Nat} {W : Nat → Nat → Piece.Wait}
    {mo : Nat → Shfl} {X : Nat → Nat → Val} {M : Nat → Nat → Mem} {t : Nat → Thread}
    (hr : ∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (· = M J (j + 1))
      ((List.range J).map fun i => (W i j).via fn (lbl i)) (t (k + j)) (M 0 j))
    (hW : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).call.intr = .shfl (mo i) ∧
      (W i j).pos = (W i 0).pos ∧ ∃ Mk Bv Cv b cl, (W i j).args = [Mk, X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i)) →
          (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j b cl))).mapM
            (withAttrs (c k).prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
            .ok (W i j).dlv.1)
    (hm : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).mem = M i (j + 1) ∧ (W i j).dlv.2 = M (i + 1) j)
    (h0 : ∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) :
    ∃ Es, WarpRun L c k t (M 0 0) Es (M J (warpLanes L k).length)
```

`W i j` is lane `j`'s `i`-th wait, in block `lbl i`, and `M i j` the memory after `j` lanes of phase
`i`. `hW` maps each wait's recorded call, arguments and position onto `WarpShfl`'s premises: one
mode per phase, a full mask, word lane and clamp operands, and the position lane 0 is at. The
recorded delivery must be the one `Grid.fire` computes from the lanes' offered values, so the
deliveries in the warp's run are `WarpShfl`'s and not inputs. `RunsVia`'s predicates do not see the
callee of a wait. `step_wait` gives it: it is the declaration the call finds by name. So `hW` states
the delivery for every shuffle's declaration the call can find: `shflVal` under that declaration's
result attributes (`withAttrs`, on the memory after the phase's last lane), as `Grid.fire` computes
it. A `noundef` result needs a defined value there, a `range` can turn the value into `poison`, and
with no attribute the value is kept (`withAttrs_mapM_nil`; for every program whose shuffle
declarations put none on their results, `MojoProof.LLVM.Program.shfl_nil`,
MojoProof/Sym/WarpRoute.lean), as at gemv's module (`gemv_nil`, MojoProofTest/GemvWarp.lean). The
test kernel's module declares the shuffle with any result attributes `ra` (`shfl_decl`,
MojoProofTest/SymCanon.lean), and its warps take the deliveries under `ra` as a premise, which the
kernel decides at `noundef` (`sound40`). The proof is `WarpRun.of_inv` with lane `j` in phase `i`
running through its waits from the `i`-th, so the one induction is `WarpRun.of_inv`'s.

`hr`'s waits are a family indexed by phase, while `RunsVia.of_fires` gives a block's as
`(Piece.waits …).map (Piece.Wait.via fn l)`. `Piece.Wait.map_via` turns one into the other:

```lean
theorem Piece.Wait.map_via (hW : ∀ i (h : i < ws.length), W (n + i) = ws[i])
    (hl : ∀ i < ws.length, lbl (n + i) = l) :
    ws.map (Piece.Wait.via fn l) = (List.range' n ws.length).map fun i => (W i).via fn (lbl i)
```

A caller takes `W i j` as the `i`-th of lane `j`'s recorded waits (`List.getD`) and decides the
list's length `J`; the waits of two blocks in turn are `n = 0` and `n` the first block's count,
joined by `List.range'_append`. `hr` keeps its indexed form because `hW` and `hm` are stated per
phase and `WarpRun.of_inv`'s induction is over phases: a list form would move the same indexing
into `WarpRun.of_waits`.

## Why per warp

A schedule that ran every thread of the grid through one phase at a time would give every warp
the same collectives, so it could not state a warp that skips a shuffle. `CanonRun`'s phases are
per warp. Such a schedule also orders the events differently: with a cell that holds 0, let
thread 32 store 1 to it before its first shuffle and thread 0 load it after its first shuffle;
the schedule loads 1, and the canonical run (warp 0 to its end, then warp 32) loads 0. So no
theorem makes one a case of the other without a premise that makes the order irrelevant (a run
with no bad grid, through `Grid.confluent`). The one grid-wide case kept is
`Seq.start_sound_bar` (MojoProof/Sym/SchedWait.lean): every thread in turn to one barrier, the
blocks' barriers, every thread in turn to its end, with no shuffle
(MojoProofTest/SymWait.lean). A barrier's phase spans a block, which `CanonRun`'s one level does
not have; the phase level has it.

## The phase level: blocks, barriers and warps (`PhaseRun`)

Lean: `MojoProof/Sym/CanonBar.lean`, on top of `Canon.lean` and `Grid.fire_barrier`
(`MojoProof/Sym/SchedWait.lean`); instances: `MojoProofTest/SymCanonBar.lean`. Every definition
and theorem is for every program, launch, contexts, thread and memory, with no kernel and no size.

**The schedule.** The canonical run at the phase level takes the blocks of threads in turn. A
block's run takes its phases in turn. In each phase but the last, the block's warps run in turn,
each to its next barrier: its lanes in turn to their waits, its shuffles fired between, as
`WarpRun` does. Then the block's barrier fires at the block's first thread
(`Grid.fire_barrier`), resumes every thread of the block with no value and logs the block's
`.barrier b`. In the last phase the block's warps run to their ends: the one-level `CanonRun`
over the block's warps. Each block has its own number of barriers, and each warp its own number
of shuffles in each phase. A block's threads and the first threads of its warps:

```lean
def blockThreads (L : Launch) (b : Nat) : List Nat :=
  (List.range (volume L.block)).map (b * volume L.block + ·)
def blockWarps (L : Launch) (b : Nat) : List Nat :=
  ((List.range (volume L.block)).filter fun j => j % 32 = 0).map (b * volume L.block + ·)
```

`blockWarps_threads` (for `0 < volume L.block`): `n` is a thread of one of block `b`'s warps
exactly when `n / volume L.block = b`.

**The rendezvous.** `BlockBar` is `Grid.fire_barrier`'s checks on statuses, as `WarpShfl` is
`Grid.fire_shfl`'s. Its statuses are indexed by thread, since a block spans its warps
(`WarpShfl`'s are by lane), and a barrier delivers nothing:

```lean
def BlockBar (L : Launch) (b : Nat) (s : Nat → Status) (u : Nat → Thread) : Prop :=
  ∃ (x : Nat → Val) (d : Nat → Func) (bar : Nat), bar < 16 ∧
    ∀ n, n / volume L.block = b → s n = .wait (u n) .barrier [x n] (d n) ∧
      (x n).word? = some bar ∧ (u n).at = (u (b * volume L.block)).at

theorem BlockBar.fire (hs : 0 < volume L.block) (h : BlockBar L b s u)
    (hg : ∀ n, n / volume L.block = b → g.threads[n]? = some (s n)) :
    Grid.Step L c g ⟨(blockThreads L b).foldl
      (fun ts n => ts.set! n (.run ((u n).resume none))) g.threads, g.mem.log (.barrier b)⟩
```

`WarpShfl.fire` is the same step for a warp's shuffle (`Grid.fire_shfl`).

**The runs.** A warp's run to its waits at statuses `s`, the warps of `ks` in turn to theirs, a
block's run and the blocks' run:

```lean
inductive WarpWait (L : Launch) (c : Nat → Ctx) (k : Nat) :
    (Nat → Thread) → Mem → List (List Event) → (Nat → Status) → Mem → Prop
  | waits : Seq.ToWait c t s (warpThreads L k) m Es m' → WarpWait L c k t m Es s m'
  | shfl : Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m₁ →
      WarpShfl L c k s m₁ u r →
      WarpWait L c k (fun n => (u (n - k)).resume (r (n - k))) m₁ Es' s' m' →
      WarpWait L c k t m (Es ++ Es') s' m'

inductive CanonWait (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) (s : Nat → Status) :
    List Nat → Mem → List (List Event) → Mem → Prop
  | nil (m : Mem) : CanonWait L c t s [] m [] m
  | cons : WarpWait L c k t m Es s m₁ → CanonWait L c t s ks m₁ Es' m' →
      CanonWait L c t s (k :: ks) m (Es ++ Es') m'

inductive BlockRun (L : Launch) (c : Nat → Ctx) (b : Nat) :
    (Nat → Thread) → Mem → List (List Event) → Mem → Prop
  | ends : CanonRun L c t (blockWarps L b) m Es m' → BlockRun L c b t m Es m'
  | bar : CanonWait L c t s (blockWarps L b) m Es m₁ → BlockBar L b s u →
      BlockRun L c b (fun n => (u n).resume none) (m₁.log (.barrier b)) Es' m' →
      BlockRun L c b t m (Es ++ [.barrier b] :: Es') m'

inductive PhaseRun (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) :
    List Nat → Mem → List (List Event) → Mem → Prop
  | nil (m : Mem) : PhaseRun L c t [] m [] m
  | cons : BlockRun L c b t m Es m₁ → PhaseRun L c t bs m₁ Es' m' →
      PhaseRun L c t (b :: bs) m (Es ++ Es') m'
```

Each has its `trace`: the last memory's trace is `Es.reverse.flatten ++ m.trace`, each barrier's
event in its place (`Mem.log`). Each has its `grid`: from every grid whose threads run the run's
threads, a run of grid steps to the grid with those threads at their waits (`WarpWait`,
`CanonWait`) or done (`BlockRun`, `PhaseRun`), every other thread unchanged. `BlockRun.grid`
fires `BlockBar.fire` between the phases; `foldl_set_congr` and `blockWarps_threads` turn the
warps' threads into the block's. The run to a done grid and soundness:

```lean
theorem PhaseRun.done (hs : 0 < volume L.block) (hN : g.threads.size = B * volume L.block)
    (h : PhaseRun L c t (List.range B) g.mem Es m')
    (hg : ∀ n < g.threads.size, g.threads[n]? = some (.run (t n))) :
    ∃ z, (∃ i, Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ g.mem.trace

theorem PhaseRun.start_sound (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hs : 0 < volume L.block)
    (hc : PhaseRun L c (Grid.thread g₀) (List.range (volume L.grid)) g₀.mem Es m')
    (he : EndChecks L obs R m') : Grid.Sound L c g₀ obs R

def EndChecks (L : Launch) (obs : Mem → Option β) (R : β → Prop) (m' : Mem) : Prop :=
  ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
    GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
  GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧ ∃ y, obs m' = some y ∧ R y
```

`EndChecks` is `CanonRun.start_sound`'s four premises past the run (`hr`, `hk`, `hy`, `hR`) in
one: `racy` under `GPUProof.racy_iff`'s premises, which `Grid.start_done_sound` supplies, `kept`,
and the observation; `CanonRun.start_sound` passes `⟨hr, hk, y, hy, hR⟩`. `PhaseRun.start_done`
is the done grid alone.

**Per-thread run predicates.** The run is built from predicates on each lane's runs, each
warp's, each phase's and each block's, with no grid:

```lean
theorem WarpWait.of_inv {J : Nat} {T : Nat → Nat → Thread → Prop}
    {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ t m, T i j t → P i j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W i j s ∧ P i (j + 1) m')
    (hf : ∀ i < J, ∀ s : Nat → Status, (∀ j ∈ warpLanes L k, W i j (s j)) →
      ∀ m, P i (warpLanes L k).length m → ∃ u r, WarpShfl L c k s m u r ∧
        (∀ j ∈ warpLanes L k, T (i + 1) j ((u j).resume (r j))) ∧ P (i + 1) 0 m)
    (he : ∀ j ∈ warpLanes L k, ∀ t m, T J j t → P J j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W J j s ∧ P J (j + 1) m')
    {t : Nat → Thread} (ht : ∀ j ∈ warpLanes L k, T 0 j (t (k + j))) {m : Mem}
    (hm : P 0 0 m) : ∃ s Es m', WarpWait L c k t m Es s m' ∧
      (∀ j ∈ warpLanes L k, W J j (s (k + j))) ∧ P J (warpLanes L k).length m'

theorem CanonWait.of_inv {s : Nat → Status}
    (h : ∀ i (hi : i < ks.length), ∀ m, P i m →
      ∃ Es m', WarpWait L c ks[i] t m Es s m' ∧ P (i + 1) m')
    (h0 : P 0 m) : ∃ Es m', CanonWait L c t s ks m Es m' ∧ P ks.length m'

theorem CanonWait.of_merge {V : Nat → Status → Prop} (hs : 0 < volume L.block)
    (hd : ks.Nodup) (hk : ∀ k ∈ ks, k % volume L.block % 32 = 0)
    (h : ∀ i (hi : i < ks.length), ∀ m, P i m → ∃ s Es m', WarpWait L c ks[i] t m Es s m' ∧
      (∀ n ∈ warpThreads L ks[i], V n (s n)) ∧ P (i + 1) m')
    (h0 : P 0 m) : ∃ s Es m', CanonWait L c t s ks m Es m' ∧
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, V n (s n)) ∧ P ks.length m'

theorem BlockRun.of_inv {J : Nat} {T : Nat → (Nat → Thread) → Prop} {P : Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ t m, T i t → P i m →
      ∃ (s : Nat → Status) (u : Nat → Thread) (Es : List (List Event)) (m₁ : Mem),
      CanonWait L c t s (blockWarps L b) m Es m₁ ∧ BlockBar L b s u ∧
        T (i + 1) (fun n => (u n).resume none) ∧ P (i + 1) (m₁.log (.barrier b)))
    (he : ∀ t m, T J t → P J m → ∃ Es m', CanonRun L c t (blockWarps L b) m Es m' ∧ P (J + 1) m')
    {t : Nat → Thread} (ht : T 0 t) {m : Mem} (hm : P 0 m) :
    ∃ Es m', BlockRun L c b t m Es m' ∧ P (J + 1) m'
```

The statuses the waits end at are not premises: each lane's step gives one, of `W i j`, and the
shuffle's premise `hf` takes every lane-indexed family of them. `WarpWait.of_inv`'s form at
statuses `S` fixed before the run is its case `W J j := (· = S (k + j))` (with `W i j` for
`i < J` as before), then `WarpWait.congr`, with no further premise (`WarpWait.of_turns` is that
case at no shuffle). Warps in turn have two theorems. `CanonWait.of_inv` takes statuses `s` fixed
before the run, the same for every warp, and has no premise on `ks` or the block: `ks` may repeat
a warp, and the blocks may be empty. `CanonWait.of_merge` puts each warp's statuses on its
threads into one family `s` (`WarpWait.congr` and `CanonWait.congr`: a run to waits depends on
the statuses of its own threads only; distinct warps' threads are apart, which `hs`, `hd` and
`hk` give). Neither is the other's case: `CanonWait.of_merge` at `V n := (· = s n)` still needs
`hs`, `hd` and `hk`, which `CanonWait.of_inv` does not ask, and `CanonWait.of_inv` cannot give
`CanonWait.of_merge` because each warp's statuses there are chosen after the warps before it
have run, from the memory they leave, while `CanonWait.of_inv`'s statuses are fixed before the
first warp (choosing the memories first and then the statuses is a second induction, longer
than the merge's). So each is its own four-to-ten-line induction on `ks`. `BlockBar.of_waits`
gives the barrier's checks (`BlockBar`) from statuses that are each a wait at one barrier call
whose argument is a number below 16, at the same instruction. `Turns.append` joins threads in
turn, the form an invariant over lanes or warps takes for the stores so far.

`WarpWait.of_inv` is `WarpRun.of_inv` with waits in place of the ends. Both are cases of
`warp_of_inv` (`Canon.lean`), the induction on the phases left for every run predicate `Q` that a
phase's lanes to their shuffle, its fire and a run of `Q` after it give: its last phase is a
premise, `Seq.of_inv` and `Seq.warp` for the ends, `Turns.of_inv` and `Turns.map` for the waits.
`CanonWait.of_inv`, `CanonWait.of_merge` and `PhaseRun.of_inv` are `CanonRun.of_inv`'s form over
warps and blocks. `J` in `BlockRun.of_inv` is the block's own number of barriers; `T i` and `P i` are the threads and the
memory at the start of phase `i`.

**Threads in order.** When a block's threads run one after another, each from the memory the one
before it leaves, the memories are one family indexed by thread and `of_inv`'s invariants are
equalities with it. `warpsCover L ks p q` decides that the warps of first threads `ks` cover
threads `p` to `q - 1` in order (the first starts at `p`, each next one where the one before
ends, after its `warpLanes`, and the last ends at `q`), and a block of two phases with no shuffle
is:

```lean
theorem BlockRun.of_turns (hT : warpsCover L (blockWarps L b) p q = true)
    (h0 : ∀ n, p ≤ n → n < q → ToWait (c n) (t n) (M₀ n) (S n) (M₀ (n + 1)))
    (hb : BlockBar L b S U) (hm : M₁ p = (M₀ q).log (.barrier b))
    (h1 : ∀ n, p ≤ n → n < q → Runs (c n) ((U n).resume none) (M₁ n) (M₁ (n + 1))) :
    ∃ Es, BlockRun L c b t (M₀ p) Es (M₁ q)
```

`WarpWait.of_turns` and `WarpRun.of_turns` are `WarpWait.of_inv` and `WarpRun.of_inv` at no
shuffle (`J = 0`), lane `j`'s invariant the memory `M (k + j)`. `CanonWait.of_turns` and
`CanonRun.of_turns` take the warps of `ks` in turn by `warpsCover_rec`, the induction on warps
that cover threads `p` to `q - 1`. `BlockRun.of_turns` is `BlockRun.of_inv` at one barrier
(`J = 1`), its threads `t` then the resumed `U`, its memories `M₀ p`, `M₁ p` and `M₁ q`. A block
with more barriers, or with shuffles, takes `BlockRun.of_inv` directly.

**The one-level run is the case of one phase per block.** `warps_blocks` splits the warps of
whole blocks block by block, and `CanonRun.append` splits a run over `ks ++ ks'`, so:

```lean
theorem PhaseRun.of_canon (h : CanonRun L c t (warps L (B * volume L.block)) m Es m') :
    PhaseRun L c t (List.range B) m Es m'
```

A start's `CanonRun` over `warps L g₀.threads.size` is then a `PhaseRun` over every block
(`Grid.start_size`), and `CanonRun.done`, `CanonRun.start_done` and `CanonRun.start_sound` are
proved here, below `PhaseRun.of_canon`, as `PhaseRun.done`, `PhaseRun.start_done` and
`PhaseRun.start_sound` at that run (one to three lines each). `CanonRun` and `CanonRun.grid` stay
in `Canon.lean`: `BlockRun.ends` and `BlockRun.grid` use them. Their users (`GemvSound`,
`GemvWarp`, `GemvWarpRun`, `SymCanon`) import this file (`GemvWarp` directly, the gemv modules
above it through it). `warps_grid_cons` and `warp_of_inv` are in `Canon.lean` because
`CanonRun.grid` and `WarpRun.of_inv` use them.

## Instances through a barrier (`MojoProofTest/SymColl.lean`, `MojoProofTest/SymChain.lean`)

The kernel `kern` (MojoProofTest/SymColl.lean) reads `tid.x`, waits at the barrier, then does a
butterfly shuffle at offset 1 and an `add`, one at offset 2 and an `add`, and returns. On one
block of four threads (one warp), from the empty memory with address choice and oracle 0:

* `sound` (SymColl): the launch is sound by `PhaseRun.start_sound` at the one block's run
  `BlockRun.bar`: the warp's lanes to the barrier (`CanonWait` of one `WarpWait.waits`), the
  barrier (`hb1`, a `BlockBar`), then `BlockRun.ends` at the warp's `WarpRun` through the two
  shuffles (`hx2`, `hx3`, each a `WarpShfl`) to the returns. Each lane's run is the one `runTo`
  computes (`Seq.ToWait.of_runTo`, `Seq.of_runTo`). `lanes`: each lane ends with the butterfly
  rounds of the thread numbers (`bflyRoundsAt_of_shfl`), 6.
* `sound_inv` (SymChain), at 4 and at 8 threads, one proof for both: `BlockRun.of_inv` at one
  barrier, phase 0 by `WarpWait.of_inv` and the barrier `bar0`, the last phase by `warp`, which
  is `WarpRun.of_inv` at two shuffles (`fires`); the runs (`waits`, `ends`) are evaluated at each
  size.
* `shfl_wait` (SymChain), at 4 and at 8 threads: `WarpWait.of_inv` at `J = 1`, the one instance
  of its shuffle premise `hf`: past the barrier, the lanes to the first shuffle's waits, its fire
  (`fires`), then the resumed lanes to the second shuffle's waits. The waits it ends at are a
  shuffle's, not a barrier's; the lemma does not ask which collective they are at.

The open-goal twins leave out the second shuffle's fire: SymColl's leaves its `WarpShfl`,
SymChain's (`warp` at 4 threads) the shuffle in the form `WarpRun.of_inv` takes.

The grid-wide schedule these instances used before (every thread through each phase in turn,
with its own phases of barriers and shuffles) is deleted; `Seq.start_sound_bar` is proved
directly from `Seq.ToWait.grid`, `Grid.fire_barriers` and `Seq.grid`.

## Instances on gevm_kernel (`MojoProofTest/GevmWarp0.lean`, `MojoProofTest/GevmWarp1.lean`)

gevm_kernel (docs/proofs/gemv.md) has one barrier and five shuffles after it, on every valid
launch with 1024 threads per block:

* `GevmWarp0.warp`: `WarpWait.of_inv` at `J = 0`, each lane to the barrier by `GevmWarp0.lane`,
  the invariant the buffers, the other blocks and the cells the earlier lanes stored (`Turns`,
  `Turns.append`); `GevmWarp0.block`: `CanonWait.of_merge` over the block's 32 warps, then
  `BlockBar.of_waits`.
* `GevmWarp1.Warp.warp`: each warp from the barrier through its five shuffles by
  `WarpRun.of_waits` at `J = 5` (`Program.shfl_deliver_bfly` for the deliveries);
  `GevmWarp1.block`: `BlockRun.bar` at phase 0's `CanonWait` and `BlockBar`, then `BlockRun.ends`
  at `CanonRun.of_inv` over the warps.
* `GevmWarp1.blocks`: `PhaseRun.of_inv` over the blocks of a one-dimensional grid, the invariant
  the output buffer, the blocks not yet written, the columns done and the trace's accesses at
  their phases (`PhaseInv`, MojoProof/Sym/PhaseExt.lean, for every property of accesses at a
  phase: each block's run extends the trace by its phase-0 events, its barrier, then its
  phase-1 events, so `PhaseInv.ext` at the block's count 0, `PhaseInv.bar`, `PhaseInv.ext` at
  count 1); `GevmWarp1.grid` is `PhaseRun.start_done` at that run, from a start with the
  kernel's arguments and the caller's buffers, the threads' premises by `Grid.start_ctx`,
  `Grid.start_thread` and `Grid.start_scalar`, the shared arrays by `Grid.start_shared`.
  `GevmSound.grid_bad` (MojoProofTest/GevmSound.lean) takes the accesses at their phases to
  `racy_cells` directly: a run of the phase level needs no rounds of the whole grid.

## Instances (`MojoProofTest/SymCanon.lean`)

The kernel, written as LLVM text that the importer accepts and parses to the test's term
`kern` (a `#guard` compares the two):

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    %1 = and i32 %0, 32
    %2 = icmp eq i32 %1, 0
    br i1 %2, label %sh, label %end
    sh:
    %3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %0, i32 16, i32 31)
    br label %end
    end:
    ret void

Warps whose first thread has bit 5 clear shuffle; the others skip the shuffle. The module `md ra`
declares the shuffle with the result attributes `ra`: the text above is `md []`, and the same text
with `declare noundef i32 @llvm.nvvm.shfl…` (`textN`) is `md [.flag "noundef"]` (both checked by the
`#guard`). The lanes' and warps' theorems are for every `ra` at which the checkers accept the kernel
(`Checks ra`: the three paths and `sh`'s segments); `covers` decides it at `[]` and at `noundef`.
Each lane's run is by the checkers, from the thread `Grid.start` gives (`Grid.start_thread`). A lane
that shuffles (`lane`) takes the entry block's edge into `sh` (`Block.sound_edge`, the path
checker's `covers`), then `sh`'s one segment to the shuffle (`Piece.throughTo` at `shP`,
`summarizePieces`), and from there the path through `end` to `ret` (`Runs.of_retMem`);
`RunsVia.of_fires` with the end's check `retB` joins the last two, and `RunsVia.of_steps` puts the
edge in front. A lane that skips it (`skipLane`) runs the path through `end` (`Runs.of_retMem`).
`shflWarp` makes a warp's lanes' runs its run by `WarpRun.of_waits` (the one wait `wt` by
`RunsVia.of_block`, the shuffle by `WarpRun.shfl_of`), `skipWarp` with no shuffle, each one
`warp_route` call. `shflWarp` asks that `ra` keeps each delivery (`withAttrs`); the declaration a
lane's call finds is the shuffle's with `ra` (`shfl_decl`, `keep`). The kernel decides each lane's
premises (`Edge`, `Piece.fires`, `Piece.Wait.shflOk` of the wait's call, arguments, position and
delivery, and the delivery under `ra`) and evaluates its memories, lane by lane.

The cost, by `lake env lean` on one core: the module takes 30 s and 3.42 GB, with `sound40` at both
declarations; by `runTo` at fuel 8 it took 74 s and 3.49 GB. `lake build` of the module takes 29 s.
Over the import alone (10.1 s), one lane's premises (`shflWarp`'s `hc` at block size 40, lane 0)
cost under 0.1 s, and the 32 lanes of warp 0 about 0.7 s.

* `sound40`, block size 40 (warps 0 and 32), with the shuffle declared without result attributes
  and with `noundef`: warp 0 shuffles, warp 32 (8 lanes) skips; `CanonRun.start_sound` makes the
  start sound. Warp 0's deliveries are words, which `noundef` keeps. `deliver40`: lane `j` of
  warp 0 is delivered thread `j ^^^ 16`'s `%0`.
* `sound70`, block size 70 (warps 0, 32 and 64), with no attribute: warps 0 and 64 shuffle, warp
  32 skips; the run of the three warps by `CanonRun.of_inv`; the start is sound, by
  `PhaseRun.start_sound` at that run as one block of one phase (`PhaseRun.of_canon`).
  `poison70`: every lane of warp 64 (6 lanes) is delivered `poison`, as lane `j ^^^ 16` is not
  one of its lanes.
* `attrs`: with `noundef`, each of warp 64's deliveries at block size 70 faults (`withAttrs`), so
  that warp has no `WarpShfl` and `sound70` has no `noundef` case; `range(i32 0, 16)` keeps lane
  16's delivery at block size 40 and turns lane 0's into `poison`.
* Refused, at block size 40, with lanes 0 to 30 of warp 0 at the shuffle: `early`, lane 31 still
  runs, and `Grid.fire` at thread 0 gives no step (the shuffle does not fire before its last
  lane waits); `mixed`, lane 31 waits at a `shfl.sync.down`, and `Grid.fire` refuses the shuffle
  ("lanes of a warp at different collectives"). `halfMask`: with lane 31 at the shuffle with
  mask `0xffff`, the statuses have no `WarpShfl`, for every threads and deliveries.

## Instances at the phase level (`MojoProofTest/SymCanonBar.lean`)

The kernel, written as LLVM text that the importer accepts and parses to the test's term `kern`
(a `#guard` compares the module, the layout, the intrinsics and the kernels):

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    %1 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %0
    store i32 %0, ptr addrspace(3) %1, align 4
    call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
    %2 = xor i32 %0, 1
    %3 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %2
    %4 = load i32, ptr addrspace(3) %3, align 4
    %5 = add i32 %0, 40
    %6 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %5
    store i32 %4, ptr addrspace(3) %6, align 4
    ret void

`@sh` is an `internal addrspace(3)` array of 80 words, one for each block of threads. Before the
barrier each thread writes its `%tid.x` to word `tid.x` of its block's `@sh`; after it, each
reads word `tid.x xor 1`, its neighbour's (threads `2i` and `2i + 1` are in one warp), and writes
it to word `40 + tid.x`. No kernel of the corpus has one barrier and no loop, so the kernel is
written by hand. The launches start on the empty memory with address choice and oracle 0.

* `block_of_lanes`, for every launch with blocks of at least one thread, memory `m` and block `b`
  of first thread `k₀` whose warps cover its threads (`warpsCover`): the block's run
  (`BlockRun`) by `BlockRun.of_turns`, from `Lanes`: each lane runs as the evaluator says
  (`runTo`, 10 steps) to the barrier with argument `i32 0`, at instruction 3 of `@k`'s block 0,
  and, resumed, from the barrier's memory to its return, one lane at a time from the memory the
  lanes before it leave (`chain`). `BlockBar` follows from the stops, each at one instruction.
* `sound34`: one block of 34 threads (warps 0 and 32, the second of 2 lanes) is sound
  (`Grid.Sound`) by `PhaseRun.start_sound`, observing words 40 to 73 of the block's `@sh` as the
  words `j xor 1` for `j < 34`.
* `warps34`, `phase34`: the first phase of that block, each warp's lanes by `WarpWait.of_turns`
  (`warps34`), warp 0 then warp 32 to the barrier (`CanonWait`) by `CanonWait.of_inv` at the
  statuses `bars`; the invariant after `i` warps is the memory after their lanes (`chain` at
  thread 0, 32 or 34). An `example` beside it gives the same by `CanonWait.of_merge`, its
  premises (`[0, 32].Nodup`, lane 0, `0 < volume L34.block`) decided.
* `sound26`: two blocks of 6 threads (one warp each), block 0 then block 1 by `PhaseRun.of_inv`
  (the memory after `i` blocks), observing words 40 to 45 of each block's `@sh`.

Each lane's three premises (`Lanes`) are decided by the kernel one lane at a time
(`kernel_rfl_late`, one goal per lane by `interval_cases`), on the memory that the evaluator's
chain of the lanes before it gives. The trace's checks (`racy`, `kept`) and the observation are
decided on the last memory, which evaluates the whole chain once. `lake build` of the module takes
30 s and 3.92 GB.
