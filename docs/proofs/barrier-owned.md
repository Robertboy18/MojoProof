# Race freedom by ownership per barrier interval (`racy_eq_false_of_phased`)

Lean: proved, `racy_eq_false_of_phased` (MojoProof/Sem/Trace.lean), from the writer form
`racy_eq_false_of_writers` (Trace.lean) with `Owned.at`, and `mem_phases` (MojoProof/Sem/Race.lean).
`racy_eq_false_of_owned` (Trace.lean), race freedom when one ownership holds for the whole run, is
its corollary. The instance and its twin are in MojoProofTest/Phased.lean. Ownership may change at
a barrier of the block of threads; this is what `tiled_matmul`'s shared-memory tiles need. The
Lean proof follows this file step for step. On a run, the shared-memory premises are proved of
every reachable grid (`Grid.start_reach_cta`, MojoProof/Sem/Shared.lean; "On a run" below).

**Scope.** Every trace. It is a statement about `racy` (MojoProof/Sem/Spec.lean), not about a program. A
kernel is covered once its traces satisfy the premises, which is the summary's job (T3, T4). The whole-run
form becomes a one-line corollary: the discipline that does not depend on the phase.

## Statement

**Phases.** `phases tr` (MojoProof/Sem/SigDef.lean) lists the accesses of `tr`, newest first. Each comes with its
phase: the number of barriers of its block of threads that completed before it. Two accesses `x` and `y` are
**unordered** if they are by different threads, and either by different blocks of threads or in the same
phase. These are the pairs `clash` tests, besides `conflict`.

**Data.**
- A phased discipline: tilings `T : Nat → Nat → Option (Tiling ι)` (phase, then block) and tile maps
  `own : Nat → Nat → ι` (phase, then thread).
- `T p b = none` says that nobody writes block `b` in phase `p`.
- `Tiling` and `Owned` are as in MojoProof/Sem/Trace.lean.

```lean
theorem racy_eq_false_of_phased {ι : Type} {T : Nat → Nat → Option (Tiling ι)} {own : Nat → Nat → ι}
    {tr : List Event}
    (hO : ∀ x ∈ (phases tr).1, Owned (T x.2) (own x.2) x.1)
    (hG : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.who.cta ≠ y.1.who.cta →
      x.1.ptr.block = y.1.ptr.block → T x.2 x.1.ptr.block = T y.2 x.1.ptr.block)
    (hX : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.ptr.block = y.1.ptr.block →
      T x.2 x.1.ptr.block ≠ none → (x.1.who.cta ≠ y.1.who.cta ∨ x.2 = y.2) →
      own x.2 x.1.who.thread = own y.2 y.1.who.thread → x.1.who.thread = y.1.who.thread) :
    racy tr = false
```

- `hO` (owned per phase): each access follows the discipline of its own phase.
- `hG` (agreement across blocks of threads): accesses of one memory block by two blocks of threads see the
  same tiling of it, whatever their phases. Barriers order nothing across blocks of threads, so ownership
  of such a block cannot change at a barrier.
  - Shared memory meets `hG` vacuously: only its own block of threads accesses it (`Mem.check`), since an
    access by another faults and is never logged.
  - Global memory needs a tiling that does not depend on the phase.
- `hX` (exclusive tiles): two unordered accesses of one tiled block with the same tile are by one thread.

## The writer form

`racy_eq_false_of_writers` states the same with a writer map in place of the tilings:
`W : Nat → Nat → Int → Option ι` gives, for each phase, block and byte, the tile of the thread
that may write the byte, or `none` if nobody does. Its premises:
- `hW`: every access, at each of its bytes `i`, has `W p b i = some (own p k)` for its thread
  `k`, or is a read and `W p b i = none`;
- `hG`: accesses of one block by two blocks of threads see the same writer map of it;
- `hX`: two unordered accesses of one block that has a writer at some byte, whose threads have
  one tile, are by one thread.

Unlike `Owned`, a thread may read bytes outside its own tile, as long as nobody writes them in that
phase. The halving tree of a reduction needs this: at stride `s`, thread `t` reads cell `t + s`,
which is no thread's tile (reduction.md, `racy_halving`).

## Proof

The phased form is the writer form with `W p b i := (T p b).bind (·.at i)`, the tile of `T p b`
that holds byte `i` (`Tiling.at`, which tilings' disjointness makes well defined, `Tiling.at_eq`).
`Owned.at` gives `hW` from `hO`; `hG` gives the writer maps' agreement; and a writer at some byte
means `T p b ≠ none`, so `hX` is the phased `hX`.

The writer form's proof, which is the argument below with bytes in place of tiles:

1. By `racy_iff` (proved, RaceSig.lean), `racy tr = true` gives `x, y ∈ (phases tr).1` with `clash x y`. That is:
   - different threads;
   - `x.1.conflict y.1`;
   - different blocks of threads, or `x.2 = y.2`.
2. `conflict` implies `overlaps`, so the two accesses are of one memory block `b`.
3. Both accesses see one writer map `τ := W x.2 b`:
   - for different blocks of threads, `τ = W y.2 b` by `hG`;
   - in the same phase, `x.2 = y.2`.
4. The byte `i := max x.off y.off` is touched by both, since they overlap. `hW` at `i` gives, for
   each access, `τ i = some (own p k)` for its phase and thread, or a read with `τ i = none`.
5. The cases:
   - both `some`: the two tiles are equal, so `hX` (with the writer at `i` and the clash's third
     conjunct) makes the threads equal, which contradicts step 1;
   - one `some` and one `none`: impossible, since both are `τ i`;
   - both `none`: both are reads, so they do not conflict, which contradicts step 1.

Whole-run form: `racy_eq_false_of_owned` becomes `racy_eq_false_of_phased` with `T _ := T` and
`own _ := own`. Its premises are about `.access a ∈ tr`, and they transfer through `mem_phases`, so
`racy_eq_false_of_owned`'s proof is that one line plus the transfer.

## Lemmas used (proved)

- `mem_phases : x ∈ (phases tr).1 → Event.access x.1 ∈ tr`, by induction on `tr` with `phases_barrier`
  and `phases_access` (Race.lean).
- `Tiling.at t i`: the tile of `t` that holds byte `i`, or `none` (classical choice).
  `Tiling.at_eq`: if tile `j` holds `i`, `t.at i = some j`, by `Tiling.disj` (Trace.lean).
- `Owned.at : Owned T own a → a.off ≤ i → i < a.off + a.len → (T a.block).bind (·.at i) =
  some (own a.thread) ∨ (a.write = false ∧ (T a.block).bind (·.at i) = none)`, by the two fields
  and `Tiling.at_eq` (Trace.lean).
- `Owned.congr : T a.ptr.block = T' a.ptr.block → own a.who.thread = own' a.who.thread →
  Owned T own a → Owned T' own' a`, by the two fields (Trace.lean). The phased form no longer uses
  it; `racy_tpose` does.

## Dependencies

- `phases` (MojoProof/Sem/SigDef.lean); `clash` (MojoProof/Sem/Race.lean); `racy_iff`
  (MojoProof/Sem/RaceSig.lean);
- `Tiling`, `Owned`, `Tiling.at`, `Owned.at`, `racy_eq_false_of_writers`, `racy_eq_false_of_owned`
  (MojoProof/Sem/Trace.lean);
- `racy`, `Access.conflict`, `Access.overlaps` (MojoProof/Sem/Spec.lean).

## Instances and twins

- **A trace, proved.** Two threads of one block of threads and a shared block of 2 bytes:
  - in phase 0, thread 0 writes byte 0 and thread 1 writes byte 1;
  - a barrier of their block of threads;
  - in phase 1, each reads both bytes, by one access of 2 bytes.

  The discipline is `T 0 b = some` (two tiles of one byte), `T 1 b = none` and `own _ := id`.
  - The whole-run form does not apply to this trace: thread 1's read of both bytes is not inside its tile.
    Proved for every `ι`, `T` and `own` (`not_owned`, MojoProofTest/Phased.lean).
  - The per-interval form does (the first `example` of MojoProofTest/Phased.lean). `phases tr` is
    computed by `decide +kernel` (`phases_tr`), `hO` and `hG` are checked on the four accesses by
    cases, and `hX` is immediate because `own _ := id`.
- **Its negative twin.** The same trace without the barrier has a race (`racy = true`, by `decide`,
  the second `example` of MojoProofTest/Phased.lean). No discipline meets the premises: thread 0's
  write of byte 0 and thread 1's read of both bytes are in one phase.
  - If `T 0 b = none`, the write breaks `Owned.read`.
  - Otherwise their tiles overlap, so `hX` would make the threads equal.
- **`tiled_matmul`, one example (evaluated).** The file in tests/corpus/tiled_matmul/ is unrolled. It
  has eight barriers (lines 91, 283, 339, 404, 460, 525, 581, 646), and each block of threads uses its two
  `[256 x float]` shared tiles as follows:
  - it stores them in phases 0, 2, 4 and 6 (lines 56-87, 307-335, 428-456, 549-577);
  - it loads them in phases 1, 3, 5 and 7 (lines 96-280, 340-401, 461-522, 582-643);
  - it stores the output, in global memory, in phase 8 (line 654).

  So the shared tiles are written in even phases and read in odd ones. The discipline is:
  - `ι := Nat` and `own _ := id`;
  - in even phases, each shared block is tiled by the threads of its block of threads, one 4-byte element
    each, and other threads get tiles of length 0;
  - in odd phases, shared blocks are untiled;
  - the output buffer has one tiling in every phase, by the global element index;
  - the inputs are untiled (read only);
  - the kernel's `byval` argument copy is untiled (only read).

  The planned test is a Bool check of `hO`, `hG` and `hX` on the full launch's trace (37,888 accesses,
  MojoProofTest/Eval.lean). It covers one launch, not the kernel. The proof for every launch comes after
  T3 and T4.
  - With `own := id`, `hX` is immediate, and the disjointness of the global index's tiles is the
    index lemma on a one-dimensional launch (`Launch.index_oneDim`, index.md).
  - A tile of length 0 at offset 0 meets `Tiling.disj` with every tile (`0 + 0 ≤ off j`), so one
    `Tiling Nat` can give every other thread an empty tile.
- **`gevm_kernel`'s transposition, every launch with `ntid.x = 1024` (proved, as a library
  lemma).** `racy_tpose` (MojoProof/Sem/Transpose.lean; warp-dot.md, "The transposition through
  shared memory") is this theorem at `own := id`: in phase 0 each block's shared array is tiled
  by `Tiling.tpose`, thread `t` of the block owning the 4 bytes of cell `tpose 32 t = 32 l + w`
  (a bijection of the 1024 cells, `tpose_bijOn`); after the barrier the array is untiled (reads);
  every other block follows one given discipline. Its instance is `racy4`
  (MojoProofTest/Transpose.lean, a 2 × 2 square on a trace of 4 threads). On a run, the pattern
  is proved for every cell map injective on a block of threads and every block size
  (`Grid.sound_cells`, next section); at the cell map `tpose 32` and cells of `w` bytes on every
  valid launch it is `sound_tpose` (MojoProofTest/Transpose.lean), with the instances `sound1024`
  (4-byte cells, `ntid.x = 1024`) and `sound256` (2-byte cells, blocks of 256 threads). That the
  kernel's trace meets its access-pattern premise is not proved (gemv.md, item 5).

## On a run (MojoProof/Sem/Shared.lean)

The premises about which threads access a shared block hold of every run, so the run-level
theorems state only the access pattern.

- `Grid.start_reach_cta`, for every program, kernel, launch, arguments, memory, address choice
  and oracle: in every grid reachable from the start's, every access is by thread `k` of block of
  threads `k / volume L.block` (`Grid.start_ctx`), and an access to a block whose owner is
  `.cta β` (`Mem.ctaOf`, the blocks `shared` makes) is by a thread of `β`. The second holds
  because the owner admits the access (`Grid.advance_admits`) and no step changes a block's owner
  (`Grid.start_reach_changes`). So `hG` for shared memory is a theorem, not a premise: only its
  own block of threads accesses it.
- `Grid.start_sound_of_racy`: one run to a grid in which every thread has returned, whose trace
  has no race and no access with `!invariant.load` to a block that a write touches, and whose
  observation satisfies `R`, makes the start's grid sound (`Grid.Sound`). This is
  `Grid.start_sound`, with `Grid.Done.bad_iff` and `kept_of_split`.
- `Grid.sound_cells`, for every cell width `w`, launch with `B = volume L.block > 0` and cell map
  `cell` injective on `[0, B)`: if every access to a block of threads' shared memory by thread `k`
  lies, before the block's first barrier, among the `w` bytes at `cell (k % B) * w`, and after it
  is a read, and every other access follows a discipline `G` with each thread its own tile, the
  start's grid is sound. It is `racy_cells` with `ofSh := Mem.ctaOf`, whose thread premises
  `Grid.start_reach_cta` gives. `racy_cells` is the writer form (`racy_shared`): the writer of a
  byte of cell `c` in phase 0 is the one `j < B` with `cell j = c`, found by `List.find?`; there
  is no writer in the later phases. `racy_tpose` has the premises of its case `cell = tpose n`,
  `B = n * n`, and is proved from this theorem's phased form with `Tiling.tpose`.
- `Grid.sound_halving`: the same for the halving tree, with blocks whose accesses are atomics of
  one operation on the same bytes (which commutes on every run, `Grid.start_reach_commutes`), such
  as a reduction's output word (reduction.md).

Instances on a run (MojoProofTest/Shared.lean), hand-built kernels on evaluated runs:
- `sh_sound_of`: for every launch and size `n` whose evaluated run passes the checks `shOk`, a
  kernel on the empty memory whose thread `k` stores its `%tid.x` to cell `tid.x` of a shared
  global `[n x i32]`, waits at a barrier, then loads cell `tid.x xor 1`. The checks: the
  evaluator's run (`Grid.run`, `Grid.run_reach`) ends with every thread returned, its trace meets
  the premises of `Grid.sound_cells` at the cell map `id` and 4-byte cells, and the shared block
  holds the words `0` to `n - 1`; then the start's grid is sound for those bytes. Decided
  (`decide +kernel`) on one block of two threads (`sh_sound`) and on two blocks of four threads
  (`sh_sound24`).
- `sh_twin`: the same kernel without the barrier. A schedule that runs thread 1 between thread
  0's store and its load ends with every thread returned, but thread 1's load of cell 0 and
  thread 0's store to it are in one phase. So the trace is racy, and the start's grid is sound
  for no observation.
- `red_sound_of`: `Grid.sound_halving` on a hand-built kernel with a shared halving tree of
  `2 ^ k` threads, whose thread 0 adds its block's sum to a caller's word by `atomicrmw add`, for
  every launch and `k` whose evaluated run passes the checks; decided on two blocks of four threads
  (`red_sound`) and of eight threads (`red_sound28`); `red_twin` is the tree of four threads
  without the second barrier (reduction.md).

The trace forms are tested by `racy4` and, in MojoProofTest/Shared.lean, by `racy_trR`
(`racy_cells` at the cell map `3 - ·` on four threads, with the twin that two threads writing one
cell race). `sound_tpose` is the instance at `tpose 32` on every valid launch (injective on the
block since a valid block has at most `32 · 32` threads); its premise `0 < volume L.block` is
`Launch.Valid.volume_pos`.

## A phase's accesses from the IR

The premises above are about the trace; this section derives them from the summaries of the
segments between barriers. Proved in MojoProof/Sym/SegTrace.lean and MojoProof/Sem/Shared.lean;
tests in MojoProofTest/SegEvents.lean.

**A phase's summary.** A segment is a thread's run from its start, or from its resumption after
a collective, to its next collective call (`Waits`, which `Seg.sound` gives) or to its block's
end (`EndsWith`); `Seg.through` chains them (MojoProof/Sym/Segment.lean). Its summary
(`SegSummary`, `Summary`) lists its memory effects `S.effs` (`SEff`: a load or a store at a
statement, through a pointer term) and its nodes `S.nodes`, whose values `vals V S.nodes` give
the terms' values. A phase of a block of threads is the segments its threads run between two of
its barriers.

**The theorem, for every program and launch.** `SEff.access V vs e` is the access effect `e`
logs: a read (load) or a write (store) by `V.ctx.who` of `l.stored t` bytes at the address its
pointer term evaluates to (`SEff.apply_trace`; a store by `Mem.store_trace`). If effects `es`
run from `m` to `m'` (`es.foldlM (SEff.apply V vs) m = .ok m'`; `SEff.run` is the case
`m = V.mem`), then `es.mapM (SEff.access V vs)` succeeds with accesses `as`, and `m'.trace` is
`as`, newest first, in front of `m.trace` (`SEff.foldlM_trace`). A thread's run to a collective
call (`ToWait`) is determined by the thread and the memory (`ToWait.det`), so every run of a
thread to its next collective call adds its summary's loads and stores, in order, at the
addresses its nodes evaluate to (`Waits.events`); `EndsWith.events` gives a run to the block's
terminator with those events. The summary is given; the theorem is about the run and the trace.

**The bridge, for every trace.** A trace of rounds (`rounds G Es`): the newest round in front,
and between two rounds the `.barrier`s of blocks of threads `0` to `G - 1` (`bars G`), the
trace the schedule of MojoProof/Sym/SchedWait.lean leaves (`Seq.start_sound_bar`,
`Grid.fire_barriers`; `Mem.log_barriers`). If every event of round `p` is an access by a block
of threads below `G` with property `Q p`, every access of the trace has `Q` at its phase
(`phases_rounds`, by `phasesF_eq`). With `Q p a` the cell pattern this is the access premise of
`racy_cells` and `Grid.sound_cells`; with the halving pattern, that of `racy_halving` and
`Grid.sound_halving`: one theorem for both. `Turns.events`: an event of threads run in turn is
an event of one thread's run. `Seq.bar_rounds`: threads run in turn from an empty trace, the
barriers of `G` blocks of threads, and threads run in turn again leave `rounds G` of the two
runs' events.

**The memory a round leaves, for every program.** A store that succeeds writes its value's
encoding into its pointer's block and changes no other block (`Mem.store_inv`,
MojoProof/Sem/Confluence.lean); logged barriers change only the trace (`Mem.log_barriers`). Writes
through a cell map from writers to cells, offsets apart, leave each cell with one writer that
writer's bytes (`Block.read_cells`) and a cell with none its own (`Block.read_cells_none`); when
the writers cover every cell they give the tensor of their values (`Block.holds_cells`,
MojoProof/Sem/Buffer.lean, of which `Block.holds_puts` is the case of one writer per cell). So
threads run in turn, each storing its value at its cell or keeping the block, leave the block
with only other bytes, holding the tensor whose element `i` is its writer's value
(`Turns.blocks`, `Turns.cells`), and a buffer premise on the block carries over
(`Mem.BufferIn.bytes`). Loads change only the trace (`SEff.foldlM_loads`), and so does a
segment whose effects are loads (`Waits.loads`, MojoProof/Sym/SegTrace.lean); a memory
predicate that each thread's run keeps holds at every thread's start in a run of threads in turn
(`Turns.imp`), so a round of such segments keeps the premises the round starts with.

**Instances.** gevm_kernel's segment before its barrier (statements 1 to 6 of `%59`) and the
one after it (statements 7 to 11), from the summaries `toBarrier` and `toShfl` of
MojoProofTest/OblGevm.lean, with the node values by obl_have: every run of the first adds the
write of 4 bytes at offset `4 (32 l + w)` (`to_barrier_events`), every run of the second the
read of 4 bytes at `4 tid.x` (`to_shfl_events`), and a thread that ran the first and is resumed
after the barrier is at the second's start with `%10 = tid.x` unchanged (`resume_shfl`). Every
run of the first leaves the blocks but the shared array's, where it writes the thread's sum
`%60` at that offset (`to_barrier_mem`); and when each thread of a block of threads writes its
word at its cell `tpose 32` and the barriers are logged, the memory meets the memory premises of
`to_shfl_events`: the shared array's buffer, holding the tensor whose cell `x` is the word of the
block's thread `tpose 32 x`, a word the first round stored (`gevm_buffer`). Every run of the
second segment changes only the trace (`to_shfl_mem`), so when the threads run in turn again by
such runs, every one of them starts on a memory that meets those premises at that tensor
(`gevm_reads`), and `to_shfl_events` applies to each. On every valid launch with
`ntid.x = 1024`, two rounds of such writes and reads meet the access premise of
`Grid.sound_cells` at `cell = tpose 32` and `w = 4` (`gevm_cells`, by `Launch.tpose_env`), and
so does the trace of threads run in turn
to the barrier, the barriers, and the threads run in turn after it, when each thread's runs add
those events (`gevm_turns`). The twin `no_barrier`: one round without the barrier puts thread 1's
read of cell 1 in phase 0, outside its cell `tpose 32 1 = 32`. Not proved in this module: that
a thread's run from the kernel's start reaches `%59` with the registers and memory these premises
state, so `to_barrier_mem` and `to_shfl_mem` are not joined to `gevm_buffer`'s and `gevm_reads`'
premises on each thread's run. The whole trace, with the loop's run as a premise, is the next
section.

## A whole trace of rounds

Plan (written before the proofs; the status of each step is at its end).

**The premise a whole trace meets, for every program and launch.** The access premises of
`Grid.sound_cells` are on every access of the final trace, at its phase: `hS` is guarded by
`z.mem.ctaOf … = some b`, so an access to a block that is no block of threads' shared memory
meets it vacuously, and `hG` asks such an access to follow the discipline `G` (a read of an
untiled block does). `Mem.CellAt m B w cell G p a` is the two together for one access `a` at
phase `p`: guarded by `m.ctaOf`, inside the cell of its thread in phase 0 and a read later; not
shared, `Owned G id a`. A trace of rounds (`rounds`) whose round `p`'s events are accesses by
blocks of threads of the grid with `Mem.CellAt … p` meets both premises (`phases_rounds` at
`Q = Mem.CellAt …`), so `Grid.sound_rounds` is `Grid.sound_cells` with a per-round premise: a
corollary, not a second proof. A round that touches only global blocks (the loop's loads) meets
it when its accesses follow `G`; a shuffle adds no event (`Grid.fire_shfl` leaves the memory),
so the phases after a barrier and its shuffles are one round.

**The rounds of gevm_kernel, one program.** Round 0 is each thread's run from the kernel's start
to the barrier: the entry block (no memory effect), the loop's loads of `x` and `B` (reads of
global blocks) and the store at cell `32 l + w` of the shared array. Round 1 is each thread's run
after the barrier: the load of cell `tid.x`, the five shuffles and the four segments between
them, with no memory effect, and the end, where lane 0 of each warp stores its sum at cell `32 β + w` of `y`, a global block. Each
segment's events come from its summary (`Waits.events`, `EndsWith.events`); the end's from the
memory the thread's run leaves (MojoProofTest/OblGevmThread.lean, `thread`, and
`Mem.store_trace`). The discipline tiles `y` by warps: the first thread of each warp owns its
4-byte cell, the other threads an empty tile.

**What stays a premise.** The thread's run from the kernel's start through the loop to `%59`:
its events are stated as a premise (every one a read of a global block, not `y`); its concrete
instance is the latch's run, whose two effects are loads (`EndsWith.events`). The owners of the
blocks in the final memory (the shared array a block of threads', `x`, `B` and `y` none) are
premises too.

**Status** (MojoProofTest/GevmTrace.lean; one program, gevm_kernel float32 `1308aaae`, on every
valid launch with `ntid.x = 1024`).

* Proved, for every program and launch: `Mem.CellAt` and `Grid.sound_rounds`
  (MojoProof/Sem/Shared.lean); `Ext`, `Ext.trans`, `Ext.turns`, `Ext.rounds` and
  `EndsWith.reads` (MojoProof/Sym/SegTrace.lean), the trace a run of threads in turn extends.
* Proved, one program: the two rounds meet `Mem.CellAt` at `cell = tpose 32`, `w = 4` and the
  output tiled by warps (`gevm_rounds`), keep the promise of `!invariant.load` (`gevm_inv`), and
  so a run whose trace extends an empty one by such rounds makes the start's grid sound
  (`gevm_sound`). The segments' events: the entry block adds none (`entry_events`), the latch adds
  reads by the thread (`latch_reads`), the four segments between the shuffles add none
  (`shfl_events`), and the end adds lane 0's store or nothing (`thread_trace`). Threads in turn
  with those facts extend the trace by the rounds' events (`gevm_before`, `gevm_after`).
* The output cell `32 ctaid.x + tid.x / 32` is `k / 32` only on a grid of one block of threads in
  `y` and `z` (`out_cell`); its twin leaves the goal open without those sides, and on a grid of two
  blocks of threads in `y` threads `0` and `1024` have the same output cell, 0 (an `example`
  decided after the twin).
* Still a premise: that the loop's reads are of blocks that are no block of threads' shared memory
  and not the output (`latch_reads` names the thread, not the block); that the start's threads
  reach `%59` with `to_barrier_events`' premises; the owners of the blocks in the last memory.
* Why 1024: it is the kernel's static shape. The shared array is `[1024 x float]`
  (tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll:6), the
  kernel is compiled for at most 1024 threads (`"nvvm.maxntid"="1024"`, :146), and the
  transposition reads at `tid.x` a cell that warp `tid.x % 32` writes, so a block with fewer than 32
  warps reads cells nobody wrote. The corpus has one specialization of gevm_kernel, so the family
  over block sizes needs the program built with its size as a parameter.
