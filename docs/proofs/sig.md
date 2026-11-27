# MojoProof's signature (`sig`)

Lean: `MojoProof/Sem/SigDef.lean` (the signature and the definitions it reaches above
`MojoProof/Sem/Grid.lean`), `MojoProof/Sem/Sig.lean` (its simp lemmas, the logging of a step, the
transport lemmas and `Levels sig`) and `MojoProof/Sym/SigOneRun.lean` (the instance
`OneRun sig`). Tests: `MojoProofTest/Sig.lean` and `MojoProofTest/Theorem0.lean` (the
gate example).

**Scope.** `sig` is one machine of the core (`GPUProof.Sig`, docs/proofs/core.md). Its lemmas
hold for every program, kernel, launch, arguments, memory, address choice and oracle; the tests
are one program (vadd) at two launches, pairs of `atomicrmw` updates at two launches,
`Grid.start_sound`'s statement for every program (`theorem0.md`), and `ret void` at two memories
that are not closed (`Mem.Closed`), on two launches.

## The fields

A state is `(g, L, c)`: a grid, its launch and its contexts, which no step changes. Each of the 84
fields of `Sig` is filled by MojoProof's own definition. The last column names a theorem of
this tree that unfolds the field at `sig`, or says that none does yet.

| Field | Filled by | Used by |
|---|---|---|
| `Launch` | `Launch` | every lemma below |
| `Tid` | `Nat`, the thread's number in the grid | every lemma below |
| `Job` | `Empty`: MojoProof has no asynchronous jobs | `Grid.done_iff` (no job is issued) |
| `threads` | `List.range (volume L.grid * volume L.block)` | `Grid.done_iff`, `sig_levels` |
| `Level` | `Fin 4`: thread, warp, block of threads, grid | `sig_levels` |
| `order` | `Fin 4`'s linear order | `sig_levels` (`nest`) |
| `bounds` | `Fin 4`'s bounds, 0 and 3 | `sig_levels` (`top`, `bot`) |
| `Gid` | `Fin 4 × Nat`: a level and a number | `sig_levels` |
| `group` | `(l, L.groupNum l n)` (`Launch.groupNum`) | `sig_levels` |
| `levelOf` | `Prod.fst` | `sig_levels` |
| `members` | `Launch.members`: the threads of the launch with that number at that level | `sig_levels`, `racy_sig_iff` (a barrier's rendezvous) |
| `Space` | `Nat`, the LLVM address space | none yet |
| `home` | `spaceHome`: shared memory (3) the block of threads', local memory (5) the thread's, every other space the grid's | none yet |
| `Loc` | `Nat × Int`, a block number and an offset | `racy_sig_iff`, `kept_sig_iff` |
| `space` | `0` for every byte | none yet |
| `key` | `Nat.pair` of the block number and the offset's number (`2·n` for `n`, `2·n+1` for `-(n+1)`), so that different bytes get different numbers (`sig_key_inj`) | `kept`'s cost only (`kept_iff` holds for every numbering) |
| `Byte` | `MemByte` | none yet |
| `Buf` | `Nat`, a block number | `racy_sig_iff`, `kept_sig_iff` |
| `place` | `(b, i)` | `conflict_sig` |
| `placeInj` | `some` of `Prod.mk.inj`: `(b, i) = (b', j)` gives `b = b'` and `i = j` | `racy`'s cost only (`Sig.share_iff` holds with or without it; `vadd_sig_racy`) |
| `Meta` | `BlockMeta`, a block without its bytes (`Block.meta`) | none yet |
| `Bytes` | `Nat → Option Block`, the blocks | `sig_obs`, `sig_oneRun` |
| `byteAt` | `sigByteAt`: byte `i` of block `b`, none outside its size | none yet |
| `metaAt` | `Block.meta` of block `b` | none yet |
| `Op` | `RmwOp`, an `atomicrmw` operation | `racy_sig_iff`, `kept_sig_iff` (`Access.kind`) |
| `commutes` | `RmwOp.commutes`: the operations `Stmt.checkAtomic` admits | none yet |
| `combine` | `sigCombine`: the old and operand bytes as integers, combined by `rmw`, stored little-endian | none yet |
| `Proxy` | `Unit`: MojoProof has one proxy | `racy_sig_iff` (`Ordered`) |
| `exempt` | `sigExempt`: MojoProof's exemption of `Access.conflict`, two updates by one commuting operation (`RmwOp.commutes`) on the same bytes | `conflict_sig` |
| `Obj` | `Nat`: a barrier's object is its block of threads | `racy_sig_iff` |
| `Prog` | `Program × Func`: a module and its kernel | `sig_oneRun`, the gate example |
| `Val` | `Val` | `sig_oneRun` |
| `Mem` | `Mem` | `sig_oneRun` |
| `memBytes` | `Mem.blocks` | none yet |
| `Choice` | `(Nat → Nat) × (Nat → Nat → Nat)`: the address choices and the oracle | `sig_oneRun` |
| `FloatSite` | `Nat × Nat`: a thread and the oracle's index in it (`Nat.pair` of the thread's step and the choice in that step) | none yet |
| `site` | the oracle at that thread and index | none yet |
| `State` | `Grid × Launch × (Nat → Ctx)` | every lemma below |
| `Thread` | `Thread` | `Grid.done_iff` (`sigStatus`) |
| `Site` | `String × Nat × Nat`, a function, block and statement | none yet |
| `Call` | `Intrinsic × List Val × Func`: a waiting thread's intrinsic, arguments and declaration | `Grid.done_iff` (`sigStatus`) |
| `CollKind` | `Intrinsic` | none yet |
| `kindOf` | `Prod.fst` | none yet |
| `operandsOf` | the arguments | none yet |
| `siteOf` | `Thread.at` | none yet |
| `level` | `collLevel`: a barrier the block of threads, a shuffle, `ldmatrix` and `mma` the warp, any other intrinsic the thread | none yet |
| `orders` | the barrier only | none yet |
| `Fault` | `Fault` | `Grid.faults_iff` |
| `launchOf` | the state's launch | `Grid.done_iff` |
| `status` | `sigStatus`: the grid's run or wait, returned for a number with no thread | `Grid.done_iff`, `Grid.raceEnabled_iff` |
| `jobs` | `[]` | `Grid.done_iff` |
| `landed` | none (no job) | `Grid.done_iff` |
| `bytes` | `g.mem.blocks` | `sig_obs`, `sig_oneRun` (`same_bytes`) |
| `trace` | `(g.mem.trace.map (Event.toCore L)).reverse`, oldest first | `sig_advance_logs`, `racy_sig_iff`, `Grid.raceEnabled_iff` |
| `pending` | `((g.pending c n).map (Event.toCore L)).reverse` (reversed, so that a step appends it) | `sig_advance_logs`, `Grid.raceEnabled_iff` |
| `firePending` | `((g.fired L n).map (Event.toCore L)).reverse` | `sig_fire_logs`, `Grid.raceEnabled_iff` |
| `reads` | `sigReads`: the bytes of the pending reads, the block of each pending access, and the block an `alloca` would get | none yet |
| `resume` | `Thread.resume` | none yet |
| `start` | `Grid.start` with the launch kept | `sig_reach_start`, `sig_oneRun` |
| `advance` | `Grid.advance` with `(L, c)` kept | `sig_advance_logs`, `sig_step_iff` |
| `fire` | `Grid.fire` with `(L, c)` kept | `sig_fire_logs`, `sig_step_iff` |
| `Same` | equal `(L, c)` and `Grid.Same` | `sig_oneRun` |
| `Agree` | `sigAgree`: `Grid.advance_agree`'s premises | none yet |
| `Delta` | `Status × List Mem.Op`: the thread's new status and its memory operations | none yet |
| `apply` | the thread's status set and the operations run (`Mem.run`) | none yet |
| `Closed` | `m.BytesIn m.Known` for every argument list, `Grid.confluent`'s premise | `sig_oneRun`, the gate example |
| `ArgsOk` | `Mem.checkClosed` succeeds | none yet |
| `StartOk` | `Func.check` succeeds | none yet |
| `ValidLaunch` | `Launch.Valid` | none yet |
| `launchCells` | `sigCells`: each block below `next` owned by a block of threads or by a thread, with that owner | none yet |
| `endLaunch` | the caller's memory with the launch's blocks owned by every thread and its `next` | none yet |
| `decTid` | `Nat`'s | `racy_sig_iff` (`edge`) |
| `decJob` | `Empty`'s | `racy_sig_iff` (`edge`) |
| `decGid` | `Fin 4 × Nat`'s | none yet |
| `decLoc` | `Nat × Int`'s | `racy_sig_iff`, `kept_sig_iff` (`Access.locs`) |
| `decBuf` | `Nat`'s | none yet |
| `decByte` | `MemByte`'s | none yet |
| `decMeta` | `BlockMeta`'s (derived) | none yet |
| `decOp` | `RmwOp`'s | `kept_sig_iff` (a frozen read) |
| `decProxy` | `Unit`'s | `racy_sig_iff` (`Ordered`) |
| `decObj` | `Nat`'s | `racy_sig_iff` (`Event.relAcq`) |
| `decKind` | `Intrinsic`'s, from `Ty.decEq` | none yet |
| `decSite` | `String × Nat × Nat`'s | none yet |
| `decVal` | `Val.decEq` | none yet |

The fields no theorem uses yet are those of the laws that are not Lean (`Local`, `Atomic`,
`Stream`, `Choices`; docs/proofs/core.md "The laws"): a byte's space and value, a buffer's
state, the operations' laws, the float sites, the collective kinds, `reads`, `Agree`, `Delta`,
`apply`, the start's checks, `launchCells` and `endLaunch`. Each is MojoProof's definition of the
thing the field names, or the nearest one; the rows below say where it falls short.

`exempt` meets the clause `exempt_rmw` of the law `Atomic` for every pair of accesses:
`Access.conflict` and `sigExempt` exempt two updates by one operation on the same bytes only when
the operation commutes (`RmwOp.commutes`, the field `commutes`). Two `xchg`s of the same bytes by
two threads with no barrier between them conflict and race, for MojoProof's `racy` and for
`GPUProof.racy sig`; with `add` they race for neither (MojoProofTest/Sig.lean, `rmwRacy`). Where a
proof needs the operations of a run's atomics to commute, it uses `Grid.start_reach_commutes`: in
every grid reachable from the start's, for every program, kernel, launch, arguments, address
choice and oracle, on a caller's memory with `m.BytesIn m.Known`, every `atomicrmw`'s operation in
the trace commutes, because an update by `rmw` succeeds only for one (`rmw_commutes`).

`Closed` and `ArgsOk`: in Lean, `Closed` enters only the good start (`GPUProof.GoodStart`) and
Theorem 0's premise, and no theorem uses `ArgsOk`. `Closed` is `Grid.confluent`'s premise, which
every proof at `sig` needs and which memories that are not closed (`Mem.Closed`) meet
(`MojoProofTest/Theorem0.lean`, `applies_one`: `next = 2`, no block 0 and a block 5). `ArgsOk` is
the start's check `Mem.checkClosed`, which every start that succeeds has passed. Neither gives
the other: the check reads no block from `next` on, so a memory with `next = 2` and a block 5
holding a pointer to block 100 passes it (MojoProofTest/Closed.lean, `start_twin`) and is not
`Closed`; and `Closed` says nothing of `next`, block 0 or the arguments, which the check reads.

## Where MojoProof falls short

- `space`: a byte is a block and an offset, and its address space is its block's
  (`Block.space`), which lies in the memory, not in the byte. `space : Loc → Space` cannot read it.
  The interface needs the space of a byte from the bytes (`space : Bytes → Loc → Option Space`)
  or from a buffer's state (`Meta → Space`, through `metaAt`).
- `Access.kind`: MojoProof logs an `atomicrmw` as a read and a write of the same bytes,
  the write first in the newest-first trace; the core has one update. Both map to `.rmw op`, so
  the core counts the read as an update, which writes. The two `racy`s agree on traces where
  every `atomicrmw`'s read is followed at once by its write (`Trace.Shaped`), which every
  reachable grid's trace is (`Grid.start_reach_shaped`). The promise of `!invariant.load` is the
  core's `kept` at `sig`, for which an `atomicrmw`'s read writes too (`Access.kind_writes`); on a
  shaped trace every access that writes for the core has a write with its pointer
  (`Trace.Shaped.writes`). MojoProof records no use of the
  result, so `.rmwRet` never arises: `Stmt.checkAtomic` admits only unused results.
- `reads`: the design's `reads` holds every buffer the step names. MojoProof's
  `Grid.advance_agree` also needs the blocks that the thread's registers name (`Frame.NamesIn`),
  and a frame's registers are a function, so they have no list. `Agree` is filled with
  `Grid.advance_agree`'s premises directly.
- `endLaunch`: MojoProof has no launch boundary. The field keeps the caller's trace and
  takes the final blocks owned by every thread and the final `next`, which drops the blocks of
  shared memory and the threads' own blocks; no MojoProof theorem says what a caller sees after a
  launch.
- `ArgsOk` and `StartOk`: `Grid.start` checks the kernel (`Func.check`) and the memory
  (`Mem.checkClosed`) first; it checks the `byval` arguments and the parameters' attributes
  (`launchArgs`) and the shared globals (`shared`) while it builds the threads and blocks, by
  faulting. So `StartOk` reads no launch and `ArgsOk` no program.

The float sites are the oracle's indices, a thread and a position in its steps, not places in
the program; `FloatResultsReadOwnSite`, the law that reads them, has no definition yet. `level`
and `orders` are read only of a waiting thread's call, and a MojoProof thread waits only at a
barrier, a shuffle, `ldmatrix` or `mma`.

## The lemmas at `sig`

- `sig_advance`, `sig_fire`: a thread's step and a fire at `(g, L, c)`, by definition
  (`MojoProof/Sem/Spec.lean`).
- `sig_advance_logs` and `sig_fire_logs`: a step appends its pending events
  (`trace s' = trace s ++ pending s (.thread n)`, and `firePending` for a fire), from
  `Grid.advance_set` and `Grid.fire_frame`. So `pending`'s reversal is proved, not argued.
  `MojoProofTest/Sig.lean` runs vadd at two launches by `sig`'s steps and checks that the trace is
  the grid evaluator's, reversed.
- The transport lemmas `sig_step_iff`, `sig_reach_iff` (`MojoProof/Sem/Spec.lean`), `sig_cta`
  and `sig_obs` (`theorem0.md`).
- `sig_levels`, the instance `Levels sig`, with `Launch.groupNum_nest`.
- In `MojoProof/Sem/Spec.lean`: `Grid.faults_iff`, the core's faults at `sig` as a thread's
  step or fire that faults; `Grid.done_iff`, the core's `Done` at `sig` as every thread
  number of the launch absent or returned; and `Grid.Sound.of_clean`, a grid whose state is
  clean at `sig` (the core's `Clean`) is sound when its done grids observe alike.
- In `MojoProof/Sem/Trace.lean`: `kept_sig_iff`, the core's `kept` at `sig` of a trace's core
  events, at every launch, as no access that writes for the core overlapping a frozen read of the
  trace.
- In `MojoProof/Sem/RaceSig.lean`: `racy_sig_iff`, the core's `racy` at `sig` of a trace's core
  events, at every launch, for a trace whose accesses are by threads of the launch in their blocks
  of threads, as two conflicting accesses by different threads that no barrier of their block
  orders; `racy_sig_rev` and `racy_iff`, the same on shaped traces by positions and by phases.
- In `MojoProof/Sem/Bad.lean`: `Grid.raceEnabled_iff`, the core's `RaceEnabled` at `sig` as a
  running thread whose pending events in front of the trace race, or a fire that completes at a
  racy trace.
- In `MojoProof/Sym/SigOneRun.lean`: the instance `sig_oneRun`.

## Removing the five duplicates (plan)

MojoProof defined five predicates that the core defines too, and `MojoProof/Sym/SigOneRun.lean`
proved each one equal to the core's at `sig`: `racy` (`racy_sig`), `kept` (`kept_sig`),
`Grid.Faults` (`sig_faults_iff`), `Grid.Done` (`sig_done_iff`) and `Grid.Bad` (`bad_embed`). This
section is the plan to remove them. Steps 1 to 5 removed `Grid.Faults`, `Grid.Done`, `racy`,
`kept` and `Grid.Bad`. A removal deletes MojoProof's definition and its equivalence
and states each use with the core's definition at `sig`; the headline theorems keep their names
and what they say. The counts below are lines that
name MojoProof's predicate (`git grep -c`, docstrings included, the core's names left out), in
`MojoProof/` and in `MojoProofTest/`, and in brackets those in the modules below `Sig.lean`.

**First, `sig` below the five (step 0, done).** `sig` was defined in `MojoProof/Sem/Sig.lean`, above
the 29 modules it imports. The five definitions were in two of them: `racy`, `kept`, `Grid.Faults`
and `Grid.Done` in `Spec.lean` and `Grid.Bad` in `Bad.lean`. Their uses run through every module
from `Spec.lean` up. `sig`'s definition reaches 23 definitions of MojoProof that were not below
`Spec.lean`:
- `Launch.Valid`, `Launch.maxGrid` and `Launch.maxBlock` (`Spec.lean`);
- `phases` and `Access.bytes` (`Race.lean`);
- `Trace.Same`, `Grid.Same`, `Stmt.pending`, `Thread.pending`, `Grid.pending`, `Grid.fired`,
  `Block.shape`, `Val.NamesIn`, `Val.AllNamesIn` and `Scope.NamesIn` (`Schedule.lean`);
- `Mem.Known` and `Mem.BytesIn` (`Names.lean`);
- `Block.Agree`, `Reads`, `Mem.Agree`, `Mem.Op`, `Mem.apply` and `Mem.run` (`Frame.lean`).

Step 0 moved these 23 definitions into a new module, `MojoProof/Sem/SigDef.lean`, between
`Grid.lean` and `Spec.lean`. With them went `sig`, the 16 other definitions of `Sig.lean` it
reaches (`Event.toCore`, `sigStatus`, `sigAgree` and the others) and the 4 `DecidableEq`
instances of `Sig.lean`. Their theorems stay where they were, and no statement changed. Step 0
changes no file of the core and removes no equivalence. No step below changes a file of
the core other than `GPUProof/Sound.lean`, which gained `Sound.of_lift` and then
`Clean.of_lift` (below). Each step after it removes one:

1. `Grid.Faults` becomes `GPUProof.Faults sig (g, L, c)` (done: `Grid.Faults` and
   `sig_faults_iff` are deleted). `sig_faults_iff` held at every grid, launch and contexts, with
   no premise; `Grid.faults_iff` (`Spec.lean`) is its statement with the grid's side written out,
   `∃ n e, g.advance c n = .error e ∨ g.fire L c n = .error e`, which names no second
   definition. A proof that builds or takes apart a fault goes through `Grid.faults_iff`, since
   `sig.advance` and `sig.fire` are `Grid.advance` and `Grid.fire` under `Except.map`.
   `Grid.Safe`, and with it `Grid.Sound`, now reads the core's faults. The plan counted 25 lines
   in 10 modules and 12 in 4 test modules (16 in 6).
2. `Grid.Done` becomes `GPUProof.Done sig (g, L, c)` (done: `Grid.Done` and `sig_done_iff` are
   deleted). The core's `Done` reads threads `0` to `N - 1` of the launch, and MojoProof's read
   every thread of the grid. `Grid.done_iff` (`Spec.lean`) is the core's `Done` at `sig` with the
   grid's side written out, `∀ n < volume L.grid * volume L.block, g.threads[n]? = none ∨
   g.threads[n]? = some .done`, at every grid, launch and contexts, with no premise.
   `Grid.done_of_all` gives it from the evaluator's test `g.threads.all (· matches .done)`, and
   `Grid.Done.all` gives the test back.
   - The statements about a done grid of any size gain `g.threads.size ≤ volume L.grid *
     volume L.block` (at most; equality is not needed): `Grid.Done.get`, `Grid.Done.all`,
     `Grid.Done.final`, `done_not_faults`, `Grid.Done.not_raceEnabled`, `Grid.Done.bad_iff`,
     `Replay.run_stop`, `Replay.found_bad` and `Grid.run_ub`. `Grid.sound_one` (since deleted)
     gained `1 ≤ volume L.grid * volume L.block` and `Grid.sound_returning` `N ≤ volume L.grid *
     volume L.block`.
   - Every grid reachable from a start has the launch's number of threads
     (`Grid.start_reach_size`, new, from `Grid.reach_size` and `Grid.start_size`, which moved to
     `Determinism.lean` from `Embed.lean` and `Sym/SchedWait.lean`). `Kernel.sound_ret_launch`
     passes `le_rfl`.
   - `Grid.sound_of_one_run` gains `hfin` (a done grid has no step), as `Sound.of_lift` below
     has it. `Grid.OneRun`'s `same_done`, `done_final` and `done_safe` read the core's `Done`, and
     the last two hold at the grids reachable from `g₀`, as the core's `OneRun` states them.

   The plan counted 76 lines in 14 modules and 53 in 19 test modules (37 in 4).
3. `racy` is deleted, with `racy_sig` and `sig_trace_agree`, its instance at the reachable grids
   (done). It could not become the core's `racy`: MojoProof's `racy` tested every trace, newest
   first, while the core's `racy` at `sig` reads a trace oldest first and takes each event's block
   of threads from the launch (`Event.toCore L`). The two agreed on a trace whose accesses are by
   threads of the launch in their blocks and in which every `atomicrmw`'s read is followed at once
   by its write (`Trace.Shaped`); the trace of every reachable grid is like that
   (`Grid.start_reach_byThreads`, `Grid.start_reach_shaped`), other traces need not be.
   - Each use is `GPUProof.racy sig ((tr.map (Event.toCore L)).reverse)`, with a launch, and
     `Grid.RaceFree`, with it `Grid.Sound`, reads the core's `racy`.
   - The new module `MojoProof/Sem/RaceSig.lean`, between `Race.lean` and `Trace.lean`, holds what
     the statements about races need: `Trace.Shaped` and its lemmas (from `ScheduleOwned.lean`),
     `Access.kind_writes`, `Access.kind_frozen` and `Access.overlaps_iff_bytes` (from
     `Trace.lean`), `conflict_sig`, `racy_sig_iff`, `Access.races_iff_rev` and
     `getElem?_concat_eq_some` (from `SigOneRun.lean`), `sig_levels` (from `Sig.lean`), and
     `racy_iff` and `fast_sound` (from `Race.lean`).
   - `racy_sig_rev` is `racy_sig`'s proof without its last rewrite: the core's `racy` at `sig` as
     positions, oldest first (the right side of the deleted `racy_iff_rev`), which names no second
     definition. `pos_iff_phases` turns positions into clashes by phases (`clash_access`,
     `clash_barrier`, `clash_append`), by an induction on the trace: at `.access a :: tr` each side
     is `a.races false tr` or the tail's, at a barrier the tail's. `racy_iff` is the two composed.
   - The statements about every trace take `racy_iff`'s two premises, `hU` (every access is by a
     thread of the launch in its block of threads) and `hs` (`Trace.Shaped tr.reverse`):
     `racy_iff`, `fast_sound`, the race-freedom lemmas of `Trace.lean`, `Shared.lean`,
     `ScheduleOwned.lean` and `Transpose.lean` (`racy_eq_false_of_*`, `racy_halving`,
     `racy_cells`, `racy_dropBlocks`, `racy_tpose`, `racy_kept_of_local`, `racy_kept_of_cells`,
     `racy_kept_pointwise`), `Elem.safe_on` and `Elem.safe`, `racy_of_race` (`Replay.lean`) and
     `Replay.found_bad`. `Trace.fits_of_check` gives both premises from a check `decide +kernel`
     evaluates, for the tests.
   - `Trace.Shaped` is not closed under prefixes: a trace whose newest event is an `atomicrmw`'s
     read is not shaped. `racy_cons` and `racy_append` need no premise: `racy_of_append` holds at
     every machine, since `HB` and `Ordered` between positions of `U` read only `U`
     (`hb_append_iff`, which replaces `hb_of_append`); events with no access keep `racy`
     (`racy_append_eq`, `racy_barriers`).
   - `Grid.Fits L c g` (`Bad.lean`) is the two premises at a grid, for its trace with any running
     thread's pending accesses in front; `Grid.start_reach_fits` gives it at every grid reachable
     from a start. `Grid.Step.raceEnabled`, `Grid.Step.bad_trace`, `Grid.advance_raceEnabled`,
     `Grid.Step.advance_fault` and `Grid.Step.bad` take it, and `Grid.start_reach_bad_trace`
     discharges it.
   - `Trace.Same.racy` is now `Trace.Same.clash`: the same traces have the same clashes by phases
     (`Schedule.lean`); with `racy_iff` at both traces they are both racy or both not.
   - The kernel theorems that take a memory's race freedom as a hypothesis
     (`Kernel.sound_of_chainsWith`, `Kernel.sound_of_chains`, `Kernel.sound_of_paths`, and
     `Kernel.sound_entryWith` and `Kernel.sound_entry` through `hend`, `Sym/Kernel.lean`, and the
     theorems `KernelCmd.lean` generates) take it under the two premises, as
     `(hU → Trace.Shaped m'.trace.reverse → racy … = false) ∧ kept … = true`; so do
     `Seq.start_sound_inv`'s `hb` (`Sched.lean`) and `Grid.start_done_sound`'s and
     `Seq.start_sound_bar`'s `hr` (`SchedWait.lean`). Their proofs discharge the premises at the
     reachable grids (`Grid.start_reach_fits` on the run's path).
   - The three changes a first attempt found:
     - `Grid.RaceEnabled` (`Bad.lean`) gains `(L : Launch)`.
     - `Grid.Same.raceEnabled` and `Grid.Same.bad` take both grids' `Grid.Fits`: `Trace.Same`
       (`phases` up to permutation) keeps the thread premise but not `Trace.Shaped`, since a swap
       can put another thread's access between an `atomicrmw`'s read and its write. Their one
       user, `bad_eqv` in `Grid.confluent` (`Determinism.lean`), discharges them by
       `Grid.start_reach_fits`.
     - `Grid.start_reach_shaped` and its helpers (`Grid.start_trace`, `Stmt.pending_shaped`,
       `Grid.pending_shaped`, `Grid.fired_shaped`) moved from `ScheduleOwned.lean` into
       `Bad.lean`, with `Grid.start_reach_pending` (from `Embed.lean`) and the thread-count
       lemmas (from `Determinism.lean`).
   - `Grid.Step.raceEnabled`'s premise on barriers keeps a twin with `Grid.Fits` on both sides
     (`fire_race_twin`, `MojoProofTest/Bad.lean`): it needs contexts that number a running thread
     of the grid as a thread of the waiting block of threads. In contexts that put a running
     thread `k` in block of threads `k / volume L.block`, as the start's do, a completing barrier
     of `k`'s block of threads waits for `k` when the blocks of threads are not empty
     (`Grid.fired_run`). `Grid.Step.raceEnabled_of_ctx` is `Grid.Step.raceEnabled` with that
     premise on contexts in place of the one on barriers: under `Grid.Fits` a running thread's
     racing accesses are by threads of the launch, so its blocks of threads are not empty.
   - The tests evaluate the core's `racy` and `kept` at a launch by `decide +kernel`, never by
     `rfl`; the four `from rfl` evaluations of `kept` are now `by decide +kernel`.

   The plan counted 165 lines in 18 modules and 161 in 28 test modules (93 in 7). The English
   word and the core's `racy` in docstrings are left: 61 lines in 16 modules and 62 in 15 test
   modules, besides `RaceSig.lean`.
4. `kept` becomes `GPUProof.kept sig ((tr.map (Event.toCore L)).reverse)` (done: `kept` and
   `kept_sig` are deleted; it came before step 3, being smaller and needing one premise where
   `racy` needs two). The core's `kept` reads no order and no block of threads, so at `sig` it
   holds of a trace's core events at every launch, with no premise: `kept_sig_iff`
   (`Trace.lean`) states it as no access that writes for the core (`GPUProof.Kind.writes`: a
   write or an `atomicrmw`'s read, `Access.kind_writes`) overlapping a frozen read
   (`GPUProof.Kind.frozen`: an `!invariant.load` that neither writes nor is atomic,
   `Access.kind_frozen`) of the trace. `kept_cons`, `kept_perm`, `kept_of_split`, `kept_append`
   (`Bad.lean`), `Trace.Same.kept` (`Schedule.lean`) and `kept_of_broken` (`Replay.lean`, whose
   `broken?` now pairs a frozen read with an access that writes for the core) hold at every
   launch.
   - `sig_trace_agree` states the two `racy`s only; `Grid.Kept`, and with it `Grid.Sound`, reads
     the core's `kept`.
   - Where MojoProof's `kept` needed a plain write, the core's needs one for each `atomicrmw`'s
     read too. `kept_of_split` takes the blocks of every access that writes for the core. Its
     callers at reachable grids (`racy_kept_of_local`, `Grid.owned_clean`, `Grid.owned_sound`,
     `Grid.start_sound_of_racy`) take the write after the read from `Trace.Shaped.writes`
     (`ScheduleOwned.lean`, new); `racy_kept_of_local` gains `Trace.Shaped tr.reverse`,
     discharged by `Grid.start_reach_shaped`, which moved to `ScheduleOwned.lean` with
     `Trace.Shaped` and its lemmas. The elementwise discipline asks for no `atomicrmw` off the
     output instead: `Elem.Own`, `racy_kept_of_cells` and `racy_kept_pointwise` take
     `a.write = false ∧ a.atomic = none` for an access to another block, so `Elem.log_read`
     takes `a.atomic = none` (mojo_inv proves it by the kernel) and `Valuation.iterate_loads`
     gives it of each load.
   - `Access.kind_writes`, `Access.kind_frozen` (from `SigOneRun.lean`) and
     `Access.overlaps_iff_bytes` (from `Embed.lean`) moved to `Trace.lean`.

   The plan counted 123 lines in 30 modules and 87 in 29 test modules (46 in 11), the English
   word in docstrings included.
5. `Grid.Bad` is last, since its parts are the other four (done). MojoProof's `Grid.Bad` was a
   fault, a racy trace, a broken `!invariant.load` promise or a race enabled at a running thread
   (`Grid.RaceEnabled`). The core's `Bad` at `sig` has the same parts in the core's terms, and
   adds the completions of collective calls to `RaceEnabled`; the two were equal at every grid
   (`bad_embed`), since a barrier in front of a trace keeps `racy` (`racy_barriers`).
   `Grid.Bad`, `Grid.RaceEnabled`, `bad_embed` and `Grid.bad_iff_pending` are deleted, and each
   use is `GPUProof.Bad sig (g, L, c)` or `GPUProof.RaceEnabled sig (g, L, c)`.
   `Grid.raceEnabled_iff` (`Bad.lean`, new) reads the core's `RaceEnabled` at `sig` in the
   grid's terms: a running thread whose pending events in front of the trace race, or a fire
   that completes at a racy trace. `Grid.start_sound`'s `hz` and `hb` are
   `GPUProof.Done sig (z, L, c)` and `¬ GPUProof.Bad sig (z, L, c)`, which say the same at its
   run's last grid. The plan counted 39 lines in 8 modules and 40 in 12 test modules (22 in 3).
   - A bad grid says the same as before at every grid. A race enabled says more: it adds the
     fire case. Where it is a premise (`Grid.Same.raceEnabled`, `Grid.Step.raceEnabled`,
     `Grid.Done.not_raceEnabled`, `Grid.owned_race`), the theorem is stronger; where it is a
     conclusion (`Grid.advance_raceEnabled`, `Grid.Step.advance_fault`, `Grid.Step.raceEnabled`,
     `Grid.Step.bad_trace`, `Grid.start_reach_bad_trace`), its fire case is the trace's race
     (`Grid.raceEnabled_iff`, `racy_barriers`). `Grid.Lockstep`'s `race` field is the core's
     `RaceEnabled` at both grids, so its instances prove the fire case too
     (`Grid.raceEnabled_contractOff` with `Grid.fire_contractOff`, and `Grid.fire_skel`).
   - `sig_trace`, `sig_pending` and `sig_firePending` (`Sig.lean`), the fields at `(g, L, c)` by
     definition, served only `bad_embed` and are deleted: `simp` reads those fields at
     `(g, L, c)` without them (`sig_advance_logs`, `sig_fire_logs`).

**`Grid.sound_of_one_run` and its two callers.** The one-run argument is written once, in
`GPUProof/Sound.lean`: `Clean.of_lift` makes `π x₀` clean and gives every reachable done state
the observation of `π z`, for every observation of the states. `Sound.of_lift` is its case at
`obs ∘ S.bytes`, and `Grid.sound_of_one_run` (`Trace.lean`) its case at `sig` along
`x ↦ (π x, L, c)` with the observation `fun s => obs s.1.mem` of the grid's whole memory:
`sig_step_iff` turns the grid's projection and lift into the core's, and `Grid.Sound.of_clean`
(`Spec.lean`, with `sig_step_iff` and `sig_reach_iff`, which moved there from `Sig.lean`) carries
the clean state back to `Grid.Sound`. Since `Clean.of_lift` observes states, not bytes,
`Grid.Sound` still observes the memory and no caller gains a premise on `obs`. Its callers:

- `Grid.start_sound` (`Determinism.lean`) is below `Sig.lean`. `OneRun sig`'s proof uses
  `Grid.start_trace` (`ScheduleOwned.lean`) and `Grid.start_size` (`Determinism.lean`). Three
  theorems below `SigOneRun.lean` use `Grid.start_sound`: `Grid.owned_sound`
  (`ScheduleOwned.lean`), `Seq.start_sound` (`Sym/Sched.lean`) and `Grid.start_done_sound`
  (`Sym/SchedWait.lean`). `Grid.start_sound` can move above `SigOneRun.lean`, with
  `MojoProofTest/Theorem0.lean`'s example as its proof, in either of two ways:
  - those three theorems move above it with it;
  - `Grid.start_trace`, with what it uses, moves below it (`Grid.start_size` is there since
    step 2).
- `Grid.sound_returning` (`Trace.lean`) starts at `retGrid`, which no start gives, so
  `Sound.of_one_run`, which needs a good start, does not apply. `Grid.sound_one`, a grid of one
  thread at any memory, had no caller and is deleted; its one instance,
  `MojoProofTest/Close.lean`'s `sound_one_ret`, is `Grid.sound_returning` at one thread.

`MojoProofTest/Theorem0.lean`'s `sound_of_sig` goes through `Grid.Sound.of_clean` too. It still
carries the core's `Sound`, which observes `sig.bytes`, back only for an `obs` that reads only
the blocks (its premise `hO`). `Sound.of_one_run` is `Sound.of_lift` at the states reachable
from a good start. `Clean.of_lift`:

```lean
theorem Clean.of_lift {γ : Type*} {π : γ → S.State} {rc e : γ → γ → Prop} {B : γ → Prop}
    (hc : Confluent rc e B) (proj : ∀ {x x'}, rc x x' → Step S (π x) (π x'))
    (lift : ∀ {x s'}, Step S (π x) s' → ∃ x', rc x x' ∧ π x' = s')
    (hF : ∀ x, Faults S (π x) → B x) (hT : ∀ x, racy S (S.trace (π x)) = true → B x)
    (hK : ∀ x, GPUProof.kept S (S.trace (π x)) = false → B x)
    (hfin : ∀ {x s'}, Done S (π x) → ¬ Step S (π x) s')
    (hD : ∀ {x x'}, e x x' → Done S (π x) → Done S (π x'))
    {α : Type*} {obs : S.State → α} (hO : ∀ {x x'}, e x x' → obs (π x) = obs (π x'))
    {n : Nat} {x₀ z : γ} (run : Path rc n x₀ z) (hz : Done S (π z)) (hb : ¬ B z) :
    Clean S (π x₀) ∧ ∀ s, Reach S (π x₀) s → Done S s → obs s = obs (π z)
```

`Grid.sound_of_one_run` stays, as a short case of `Clean.of_lift`, so that its two callers do not
repeat the transport. `Grid.OneRun` and
`Grid.start_oneRun` stay: `sig_oneRun` takes its confluence and two other fields from
`Grid.start_oneRun`, and `MojoProofTest/Embed.lean` (`embed`) proves `Grid.OneRun` for vadd.

The order is step 0 first, then `Grid.Faults`, `Grid.Done`, `kept`, `racy` and `Grid.Bad`. Steps
0 to 5 are done.
`Grid.start_sound`'s move can follow step 0.
