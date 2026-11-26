# The canonical run at one level: warps in turn (`CanonRun`)

Lean: `MojoProof/Sym/Canon.lean`, on top of `Seq`, `Seq.ToWait`, `Turns` and `Grid.fire_shfl`
(`MojoProof/Sym/Sched.lean`, `MojoProof/Sym/SchedWait.lean`). Instances:
`MojoProofTest/SymCanon.lean` and `MojoProofTest/GemvWarp.lean`.

**Scope.** Every definition and theorem is for every program, launch, contexts, thread and
memory. The instances are for one hand-built kernel at block sizes 40 and 70 (at 40 with the
shuffle declared without result attributes and with `noundef`, at 70 without), and for
gemv_kernel at three launches with `K = 0` and two with one round of the loop, `K = 4` and
`K = 3` (docs/proofs/gemv.md).

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

theorem CanonRun.done (hs : 0 < volume L.block) {g : Grid}
    (hN : g.threads.size % volume L.block = 0)
    (h : CanonRun L c t (warps L g.threads.size) g.mem Es m')
    (hg : ∀ n < g.threads.size, g.threads[n]? = some (.run (t n))) :
    ∃ z, (∃ i, Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ g.mem.trace
```

`WarpRun.grid` is by induction on the run: `Seq.grid` for `ends`; for `shfl`,
`Seq.ToWait.grid` to the grid with the warp's lanes at `s`, then `Grid.fire_shfl` at thread `k`
(its premises are `WarpShfl`'s, at the threads `k - k % volume L.block % 32 + j = k + j`), then
the rest of the run; the two folds over the warp's threads give the same array as one fold to
`.done` (`foldl_set_getElem?`). `CanonRun.grid` composes the warps: distinct first threads have
disjoint threads (`warpThreads_iff`), so each warp starts from the threads `t` gives. In
`CanonRun.done` every thread `j < N` is a thread of the warp `j - j % volume L.block % 32`, so the
grid reached is done (`Grid.done_foldl`), and `hN` keeps every warp's threads below `N`.

## Soundness

```lean
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

`CanonRun.start_done` is `CanonRun.done` at the start's grid `g₀` (`Grid.start_threads`, and
`Grid.start_size` for `hN`): a canonical run from the start reaches a done grid with the run's
memory, the conclusion the instances state about the output's cells
(MojoProofTest/GemvWarp.lean). `CanonRun.start_sound`'s premises are `Sched.start_sound`'s, with
the canonical run in place of the schedule and `0 < volume L.block`. Both proofs reach a done
grid (`CanonRun.start_done`, `Sched.grid`) and end in `Grid.start_done_sound`
(MojoProof/Sym/SchedWait.lean): a start that steps to a done grid whose memory is kept, race-free
under `racy_iff`'s premises and observed as `y` with `R y` is sound, by `Grid.Done.bad_iff`,
`Grid.start_reach_fits` and `Grid.start_sound`, which is Theorem 0 at `sig`.

## Per-thread run predicates

The run is built, like `Sched.of_inv`, from predicates on each lane's runs, with no grid:

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
`Seq.ToWait.warp` and `Seq.warp` (`Turns.map`), by induction on the phases left.

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

`W i j` is lane `j`'s `i`-th wait, in block `lbl i`, and `M i j` the memory after `j` lanes of
phase `i`. `hW` maps
each wait's recorded call, arguments and position onto `WarpShfl`'s premises: one mode per
phase, a full mask, word lane and clamp operands, and the position lane 0 is at. The recorded
delivery must be the one `Grid.fire` computes from the lanes' offered values, so the deliveries in
the warp's run are `WarpShfl`'s and not inputs. `RunsVia`'s predicates do not see the callee of a
wait. `step_wait` gives it: it is the declaration the call finds by name. So `hW` states the
delivery for every shuffle's declaration the call can find: `shflVal` under that declaration's
result attributes (`withAttrs`, on the memory after the phase's last lane), as `Grid.fire` computes
it. A `noundef` result needs a defined value there, a `range` can turn the value into `poison`, and
with no attribute the value is kept (`withAttrs_mapM_nil`), as at gemv's module (`shfl_retAttrs`,
MojoProofTest/GemvWarp.lean). The test kernel's module declares the shuffle with any result
attributes `ra` (`shfl_decl`, MojoProofTest/SymCanon.lean), and its warps take the deliveries under
`ra` as a premise, which the kernel decides at `noundef` (`sound40`).
The proof is `WarpRun.of_inv` with lane `j` in phase `i` running through its
waits from the `i`-th, so the one induction is `WarpRun.of_inv`'s.

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

## Relation to `Sched`

`Sched` and `Sched.of_inv` run every thread of the grid through one phase at a time, so every
warp has the same collectives: they cannot state a warp that skips a shuffle. `CanonRun`'s phases
are per warp.

No theorem relates the two: neither is proved a case of the other, and `CanonRun.start_sound`
uses no such relation. A schedule whose phases are all shuffles is not in general a `CanonRun`,
because `Sched` has no race-freedom premise and its phase runs every thread to its wait before
any warp goes on. For example, with a cell that holds 0, let thread 32 store 1 to it before its
first shuffle and thread 0 load it after its first shuffle: the schedule loads 1, and the
canonical run (warp 0 to its end, then warp 32) loads 0. Even when no two threads touch one cell,
the two orders log the events in different orders.

A conversion would need one of two things:
* a premise that makes the order irrelevant: a run with no bad grid, so that reordering its
  steps reaches a grid that is `Grid.Same` (the same threads and blocks, the trace up to
  `Trace.Same`). `Grid.confluent` gives this, and `Grid.start_sound` uses it for the observation
  only; no theorem turns a `Sched` into a `CanonRun` with it;
* the two-level case (blocks in turn, warps in turn inside each block's phase), with `Sched` its
  corollary.

A barrier's phase spans a block, which `CanonRun`'s one level does not have: `Sched` stays for
the kernels with barriers (the instances of `MojoProofTest/SymColl.lean`,
`MojoProofTest/SymChain.lean` and `MojoProofTest/GevmTrace.lean`). When the two-level case lands,
`Sched` becomes its corollary or is deleted once those callers move; there are never two families
for one case.

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
`shflWarp` makes a warp's lanes' runs its run by `WarpRun.of_waits` (the one wait `wt`, by
`Piece.Wait.map_via`), and `skipWarp` by `WarpRun.of_inv` with no shuffle. `shflWarp` asks that `ra`
keeps each delivery (`withAttrs`); the declaration a lane's call finds is the shuffle's with `ra`
(`shfl_decl`). The kernel decides each lane's premises (`Edge`, `Piece.fires`, the wait's call,
arguments, position and delivery, and the delivery under `ra`) and evaluates its memories, lane by
lane.

The cost, by `lake env lean` on one core: the module takes 30 s and 3.42 GB, with `sound40` at both
declarations; by `runTo` at fuel 8 it took 74 s and 3.49 GB. `lake build` of the module takes 25 s.
Over the import alone (10.1 s), one lane's premises (`shflWarp`'s `hc` at block size 40, lane 0)
cost under 0.1 s, and the 32 lanes of warp 0 about 0.7 s.

* `sound40`, block size 40 (warps 0 and 32), with the shuffle declared without result attributes
  and with `noundef`: warp 0 shuffles, warp 32 (8 lanes) skips; `CanonRun.start_sound` makes the
  start sound. Warp 0's deliveries are words, which `noundef` keeps. `deliver40`: lane `j` of
  warp 0 is delivered thread `j ^^^ 16`'s `%0`.
* `sound70`, block size 70 (warps 0, 32 and 64), with no attribute: warps 0 and 64 shuffle, warp
  32 skips; the run of the three warps by `CanonRun.of_inv`; the start is sound. `poison70`: every
  lane of warp 64 (6 lanes) is delivered `poison`, as lane `j ^^^ 16` is not one of its lanes.
* `attrs`: with `noundef`, each of warp 64's deliveries at block size 70 faults (`withAttrs`), so
  that warp has no `WarpShfl` and `sound70` has no `noundef` case; `range(i32 0, 16)` keeps lane
  16's delivery at block size 40 and turns lane 0's into `poison`.
* Refused, at block size 40, with lanes 0 to 30 of warp 0 at the shuffle: `early`, lane 31 still
  runs, and `Grid.fire` at thread 0 gives no step (the shuffle does not fire before its last
  lane waits); `mixed`, lane 31 waits at a `shfl.sync.down`, and `Grid.fire` refuses the shuffle
  ("lanes of a warp at different collectives"). `halfMask`: with lane 31 at the shuffle with
  mask `0xffff`, the statuses have no `WarpShfl`, for every threads and deliveries.
