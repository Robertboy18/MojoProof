# Schedule independence (T2, `Grid.confluent`)

Lean, in MojoProof/Sem/Schedule.lean unless named: changes S1 and S2 are made; `Trace.Same` and
`Grid.Same` are defined, with `refl`, `symm` and `trans`; `Thread.pending` is defined and L1a for
steps is proved (`step_pending`, for every context, thread and memory, and `Grid.advance_pending`,
for every grid), and for fires (`Grid.fire_trace`, for every grid), and no step or fire reads the
trace (`exec_retrace`, `step_retrace`, `Grid.advance_retrace`, `Grid.fire_retrace`), with its
corollaries `bisim` (`Grid.Same.step`) and the fault part of `bad_eqv` (`Grid.Same.faults`); L1c
for the memory (`Thread.pending_shape`; with C1, a running thread of a closed grid has the same
pending accesses in every reachable grid, `Grid.pending_reach`), and W5 (`Grid.reach_keeps`:
reachable grids keep every block; `Grid.start_reach_atCalls`: a waiting thread of a grid reachable
from the start is at its call); L9 (`racy_iff`, Race.lean), L11 (`Trace.Same.append`,
`Trace.Same.swap`), L12 (`Trace.Same.racy`, `Trace.Same.kept`), L13 (`racy_insert`) and L10
(`rmw_comm` on values, `Mem.update_comm` on memory) are proved, each for every trace, list,
operation and width it names. In MojoProof/Sem/Bad.lean: `Grid.RaceEnabled` and `Grid.Bad` are
defined, `bad_eqv` is proved (`Grid.Same.bad`, for every launch, contexts and grids), and
`bad_step` (`Grid.Step.bad`, for every launch, contexts with one layout and closed grid whose
threads own their allocas and have different thread numbers, in which no collective call that
completes logs a barrier of a running thread's block of threads; a fault at a collective call
persists, `Grid.fire_error_advance`, `Grid.fire_error_fire`; a fault persists after an exempt
update, `Grid.advance_fault_atomic`, by `exec`'s check that an `atomicrmw`'s operand is a scalar
of its type; and `Grid.start_reach_bad` in every grid reachable from the start; the premise of one
layout is needed, twin `fire_fault_twin`, the check, twin `update_before`, and the closed grid,
twin `closed_twin`, counterexample (i)). L3 holds by construction. `Grid.confluent` (conclusion 1)
and `Grid.start_sound` (conclusion 2) are proved, for every program, kernel, launch, arguments,
address choice and oracle on a caller's memory whose pointer bytes name known numbers
(`Mem.BytesIn Mem.Known`), in MojoProof/Sem/Determinism.lean, with the diamond's case of two
threads with conflicting pending accesses as two grids with a race enabled
(`Grid.advance_raceEnabled`, Bad.lean); instances and twins in MojoProofTest/Determinism.lean.
Conclusion 3 is `Grid.start_refute`; conclusion 4 (T2′) is `Grid.confluent_owned` in
MojoProof/Sem/ScheduleOwned.lean, by the route of item 4 below.

The semantics this proof uses: an `alloca`'s block number is `Mem.fresh` (so no renaming of
blocks), the start checks the caller's memory (`Mem.checkClosed`) and every reachable grid is
closed (`Grid.Closed`, schedule-owned.md), `lifetime.start` resets the bytes of a block (L1b), and
two `atomicrmw`s are exempt from `Access.conflict` only if they have one operation, pointer and
size.

**Scope.** Every program, launch, start memory, argument values, skeleton choice and oracle. The
hypotheses are that `Grid.start` succeeds and that the caller's memory is closed for the arguments
(`Mem.Closed`). The start checks the fields of `Mem.Closed` except `above` (no block from `next`
on), which no function can check, and except the pointer bytes of the blocks from `next` on, which
`above` says do not exist (`Mem.checkClosed`; a closed memory passes, `Mem.checkClosed_of_closed`);
it deletes no block and refuses an allocation at a number that has one (`Mem.allocNext`), so it
keeps every block of the caller's memory (`Grid.start_blocks`, proved). Kernels with conflicting
accesses, with atomics on one location (`reduction`) and with tiles that change hands at barriers
(`tiled_matmul`) are all covered: a schedule dependence shows up as a bad grid. T2 says that the
schedule does not matter *up to bad grids*; it does not say that a kernel is race free. That is a
property of one run, which T2 transfers to all runs.

**Design choices.**
- No renaming of block numbers (`Mem.fresh`), so the equivalence `Grid.Same` is equality up to the
  order of independent trace events.
- The race predicate is `racy` itself, with its exemption of two atomics of one operation, pointer
  and size: such atomics commute (L10 below).
- W1 is `Grid.Closed` (schedule-owned.md, section "The closed-grid invariant").
- `Confluent` needs one more alternative in its diamond (change S1 below).
- One change to the semantics (change S2 below): an admitted `atomicrmw` leaves its result register
  unset.

## Changes it needs first

- **S1 (`Confluent`, MojoProof/Sem/OneRun.lean).** `diamond` gains the alternative `Bad b ∧ Bad c`:

      diamond : ∀ {a b c}, r a b → r a c →
        e b c ∨ (Bad b ∧ Bad c) ∨ ∃ d d', r b d ∧ r c d' ∧ (e d d' ∨ (Bad d ∧ Bad d'))

  Two conflicting steps from one grid give grids that are both bad at once (a race is enabled in each),
  but the second step need not be possible from either: it can fault. `one_run` still holds. In `key`, the
  third case has `Bad a₁'` for the second step's target `a₁'`; `path_eqv` carries the run `a₁ → … → z` to
  `a₁'`, and `bad_path` makes its end bad, against `¬ Bad z`. This is two lines in `key`. Of the instances
  in MojoProof/Sem/Trace.lean, `Grid.sound_returning` takes the third alternative (one-run.md) and
  `Grid.sound_one` the first. (Lean: `Confluent.diamond`, `Confluent.key`.)
- **S2 (`exec`, MojoProof/Sem/Thread.lean).** An admitted `atomicrmw` sets its result register to the
  old value, which depends on the order of the atomics. `Stmt.checkAtomic` refuses a used result, so no
  instruction reads that register, but the two orders give threads that differ in it, and `Grid.Same`
  compares threads by equality. The step leaves the register unset instead. Nothing reads it, so leaving it
  unset changes no observation; Eval's atomic tests check it. (Lean: `exec`; Eval
  `regsAfter`, two threads' `atomicrmw add` in either order give the same registers, and without
  S2 that check fails.)

## Definitions the proof adds

- `Thread.pending (c : Ctx) (t : Thread) (m : Mem) : List Event`, as in schedule-owned.md: the accesses the
  step of `t` would log, in trace order (newest first), whether the step then succeeds or faults. One
  definition serves T2 and T2′. (Proved, with `Stmt.pending` for one statement, and L1a for steps:
  `step_pending`, a step that succeeds puts exactly these in front of the trace, and one that stops at
  a collective has none; `Grid.advance_pending`, a grid step of thread `n` is a step of a running
  thread and puts its pending accesses in front of the trace; `Grid.fire_trace`, a fire logs one
  `.barrier` of the thread's block at a barrier and nothing at another collective; instance and twin
  MojoProofTest/Eval.lean `pendingTests`: two threads' 10 accesses on one launch, and a load through
  null, whose step faults with its access pending.)
- `Trace.Same tr tr'`: `(phases tr).1` is a permutation of `(phases tr').1`, and
  `(phases tr).2.getD k 0 = (phases tr').2.getD k 0` for every block of threads `k`. It is the order of the
  trace forgotten up to the phase of each access (`phases`, MojoProof/Sem/Race.lean). (Proved as stated.)
- `Grid.Same g g'`: `g.threads = g'.threads`, `g.mem.blocks = g'.mem.blocks`, `g.mem.next = g'.mem.next`,
  and `Trace.Same g.mem.trace g'.mem.trace`. It replaces schedule-owned.md's `List.Perm` (which `Trace.Same`
  implies for the accesses), so T2 and T2′ share it. (Proved as stated, with `Grid.Same.refl`, `symm`,
  `trans`; instance and twin MojoProofTest/Same.lean `grids`, `grid_twin`.)
- `Grid.RaceEnabled g`: some thread `n` runs, `g.threads[n]? = some (.run t)`, and
  `racy (Thread.pending (c n) t g.mem ++ g.mem.trace) = true`. (Proved as stated, MojoProof/Sem/Bad.lean;
  instance MojoProofTest/Bad.lean `race_enabled`.)
- `Grid.Bad g := g.Faults L c ∨ racy g.mem.trace = true ∨ kept g.mem.trace = false ∨ g.RaceEnabled c`.
  (Proved as stated.)

## Statement

**Data.** `hs : Grid.start prog fn L args m ch oracle = .ok (g₀, c)`. The states are
`γ := { g // ReflTransGen (Grid.Step L c) g₀ g }`, the relation is `rc x y := Grid.Step L c x.1 y.1`.

**Conclusions.**

1. `Grid.confluent hs : Confluent rc (fun x y => Grid.Same x.1 y.1) (fun x => Grid.Bad L c x.1)`.
   (Proved, with the caller's hypothesis `hm : m.BytesIn m.Known`; instance `confluent2`.)
2. Through `Confluent.one_run` and `Grid.sound_of_one_run`: if one run from `g₀` reaches a done grid `z`
   with a race-free trace that keeps `!invariant.load` (a done grid does not fault, `done_not_faults`, and
   has no running thread, so no enabled race), then `Grid.Sound L c g₀ obs R` for every `obs` that reads only
   `Mem.blocks`, with `R` the property of `obs z.mem`. This is a statement about every schedule from one
   run; whether the run exists is a fact about one kernel and one input. (Lean: `Grid.start_sound`,
   taking the run as a `Path` with `¬ z.Bad`; instances `sound2` and `final2` on `start2`, two
   threads' `alloca` and store; twins `racy_twin`, a done grid with a racy trace, so sound for no
   observation, and `trace_twin`, an observation of the trace's newest event, for which two
   schedules differ, so sound for no relation.)
3. Refutation transfer, the same theorem read backwards: if some reachable grid is bad (a fault, a race or a
   broken promise in one schedule), then every reachable grid without a step is bad. No schedule hides it.
   (Lean: `Grid.start_refute` by `Confluent.bad_normal`; instance `refuteP` on `startP`, twin
   `refute_twin`: on `start2`, `done2` has no step and is not bad.)
4. T2′ (schedule-owned.md) becomes a corollary. Under `hH`, `hX` and `hI`, no reachable grid has a racy
   trace, a broken promise or an enabled race (schedule-owned.md, conclusion 2, applied to the trace with
   the pending accesses in front), so on the states `γ` `Bad` is `Faults`, and `Confluent` with
   `Bad := Faults` follows by a general lemma: `Confluent r e B` and `∀ a, B a ↔ B' a` give
   `Confluent r e B'`. (Lean: `Confluent.of_iff`, `Grid.owned_bad`, `Grid.confluent_owned`, in
   MojoProof/Sem/ScheduleOwned.lean; `hX` there is `own` injective on the start grid's thread
   numbers, and the caller's memory meets T2's `Mem.BytesIn Mem.Known`.)

## Lemmas used

From schedule-owned.md, unchanged: L1a (steps and fires do not read the trace; a successful step logs
exactly its pending accesses, proved as `step_pending` and, for the grid, `Grid.advance_pending`; a barrier fire logs one `.barrier`,
proved as `Grid.fire_trace`), L1b (what a step changes, including the bytes of the thread's own blocks
that `lifetime.start` makes undefined; done for every step in every grid
reachable from the start, `Grid.start_reach_changes`, MojoProof/Sem/Writes.lean), L2 (frame; done
for statements and steps, `exec_agree`, `step_agree` and `step_fault`, and the memory part of the
no-conflict argument below, `Mem.Changes.agree`, MojoProof/Sem/Frame.lean; that changes at
disjoint places commute, `Mem.run_comm`, and the case of two threads' steps of the diamond if no
pending access of either conflicts with one of the other (`Access.conflict`), `Grid.advance_comm`,
which covers both of its subcases below (no write of one overlaps an access of the other; or an
exempt pair of `atomicrmw`s, `Grid.advance_atomic_comm`), and in every grid reachable from the
start for every two different threads, `Grid.start_reach_comm`; the premise of the first subcase
from ownership, if each of the two threads' pending accesses follows a discipline with different
tiles or is to a block its thread owns, `Grid.pending_apart`, so from the start
`Grid.start_reach_comm_of_owned`; its case of a thread's step and a collective call, a
barrier or a shuffle, for every grid, if the thread's context is not of the barrier's block of
threads, `Grid.advance_fire_comm`, and in every grid reachable from the start,
`Grid.start_reach_fire_comm`; its case of two collective calls, for every grid and contexts in
which the two threads have one layout, `Grid.fire_fire_comm`, so for every grid in the start's
contexts, `Grid.start_fire_fire_comm`, MojoProof/Sem/Confluence.lean),
L3 (choices), W2, W5, and `Grid.Closed` with C1 and C2 (which hold of every reachable grid; their proof does
not use ownership). New:

- L1c (pending): `Thread.pending (c n) t m` reads `m` only at the existence, space, size and addresses of
  the blocks that `t` names (a pointer operand is evaluated from registers, globals and constants; `gep`
  and `ptrtoint` read `Mem.block` and `Mem.addr`). These never change in reachable grids: a named block
  keeps them (W5), and a named number without a block never gets one (C1). So a thread's pending accesses
  are the same in every reachable grid in which its state is `t`. (Proved for the memory, for every
  context, thread and set `S` of block numbers: if the scope of `t`'s innermost frame names only
  numbers of `S` (`Scope.NamesIn`: null, the pointers in its registers, `Val.NamesIn`, and the
  globals) and `m`, `m'` have the same existence, space, size and addresses at every number of `S`
  (`Mem.SameShape`), then `t.pending c m = t.pending c m'` (`Thread.pending_shape`, from
  `evalV_shape`, which also says that evaluation names only numbers of `S`). W5's block part and C1's
  part about memory are done: `Mem.setLive`, `Mem.log`, a successful `Mem.write` and `Mem.store`,
  and `Mem.alloc` at a number from `next` on with no block keep every block that exists, at its
  number and with its shape, keep `next`, and add no block below it (`Mem.Keeps`,
  `Mem.store_keeps` and the others), and so do every statement that continues (`exec_keeps`; an
  `alloca` at a number in use is refused, and its number `Mem.fresh` is at least `next`), step
  (`step_keeps`, `Grid.advance_keeps`) and fire (`Grid.fire_keeps`): every grid reachable from `g`
  keeps every block of `g`, its `next`, and every number below `next` with no block free
  (`Grid.reach_keeps`, for every launch and context map). So `g` and a grid reachable from it have
  the same shape at every number of `S` if every number of `S` with no block in `g` is below
  `next` (`Mem.Keeps.sameShape`). That premise for the numbers a thread names, C1's other part, is
  done for closed grids: every step and fire keeps the closed-grid invariant of schedule-owned.md
  (`Grid.Closed`; `Grid.reach_closed`, MojoProof/Sem/Closed.lean), and a running thread of a closed
  grid has the same pending accesses in every grid reachable from it (`Grid.pending_reach`, for
  every launch, context map and closed grid). The start's grid is closed if every pointer byte of
  the caller's memory names a known number (`Grid.start_closed`; a closed memory has that), so both
  hold from the start (`Grid.start_reach_closed`, `Grid.start_pending`). W5's other part is done: in every grid reachable
  from the start, every waiting thread is at its collective call (`Grid.start_reach_atCalls`,
  `Thread.AtCall`: its current statement calls the function whose intrinsic it waits at).
  `Scope.NamesIn` asks for `S 0`, and number 0 is below `next` (at least 1, `Mem.Closed`), so
  the premise holds at 0.)
- L9 (`racy_iff`, proved for every trace, MojoProof/Sem/Race.lean, with `races_iff` for one access
  and `phase_le`; it replaces `racy_clash` and `races_phases`, its forward directions):
  `racy tr = true ↔ ∃ x ∈ (phases tr).1, ∃ y ∈ (phases tr).1, clash x y = true`. Backward: of two
  clashing accesses take the newer one; it is by another thread, they conflict, and they are by
  different blocks of threads or in one phase, in which case no barrier of their block lies between
  them (a phase is at most the final count, `phase_le`), so `Access.races` finds the older one.
- L11 (`Trace.Same` is a congruence; proved for all lists: the first half is `Trace.Same.append`,
  the second `Trace.Same.swap`, with the condition as `Event.indep` on each pair, by swapping one
  event at a time, `Trace.Same.swap₁`): `Trace.Same tr tr'` gives `Trace.Same (E ++ tr) (E ++ tr')` for every
  list `E` (`phases` folds from the oldest event, so `phases (E ++ tr)` is a function of `E` and
  `phases tr` that commutes with permuting the first part). And `Trace.Same (E ++ F ++ tr) (F ++ E ++ tr)`
  when no event of one of `E`, `F` is a barrier of the block of threads of an access of the other: such a
  swap moves no access past a barrier of its own block, so it keeps every access's phase and every count.
- L12 (invariance; `Trace.Same.racy`, `Trace.Same.kept`, proved for every trace, with `phases_mem`
  for `kept`): `racy` and `kept` are invariant under `Trace.Same`. For `racy` by L9. For `kept`, it
  reads only the accesses of the trace, as a set (`kept_iff`), and `Trace.Same` permutes them.
- L13 (inserting events; `racy_insert`, proved for all lists): if `racy (P ++ tr) = true`, `P`
  consists of accesses of one thread `w`, and `Q` contains no `.barrier w.cta`, then
  `racy (P ++ Q ++ tr) = true`. By induction on `P`, through `Access.races` rather than L9. If the
  race is in `tr`, it stays (`racy_append`). If an access `a` of `P` races with the rest, then it
  skips the other accesses of `P`, which are by its own thread (`races_skip`), so it races with
  `tr`, and events with no barrier of its block of threads keep that race (`races_insert`).
  Instance: MojoProofTest/Same.lean `insert`; the twin there shows a barrier of the access's block
  breaks `Trace.Same` (`twin`).
- L10 (two exempt atomics commute). Let `f := rmw w op` for an operation `op` that `Stmt.checkAtomic`
  admits, at a width `w` that it admits. Then for all values `v x y` (bits of width `w`, poison or undef):
  - `f v x` faults if and only if `v` or `x` is undef, and otherwise its result is bits of width `w` or
    poison (`intBin`, `strict2` in `intMinMax`);
  - if neither side faults, `f (f v x) y = f (f v y) x` (commutativity and associativity of `+`, `&&&`,
    `|||`, `^^^`, `max` and `min` on `BitVec w`, signed and unsigned; poison absorbs).

  Lean, for the values, in MojoProof/Sem/Rmw.lean: `rmw_comm` for every operation that
  `Stmt.checkAtomic` admits (`RmwOp.commutes`: `add`, `and`, `or`, `xor`, `max`, `min`, `umax`,
  `umin`), every width and all scalars `Val.Scalar` (bits of the width, poison or undef):
  `rmw w op v x >>= (rmw w op · y) = rmw w op v y >>= (rmw w op · x)`, the same fault or the same
  value in either order. This one equation gives both items above as they are used: in the
  diamond, the second step succeeds from either side with the same value; in `bad_step`, a fault
  in one order is a fault in the other. It is proved once for every operator that propagates
  undef and poison as LLVM's do (`Lifts`, `Lifts.comm`) with a right-commutative operation on
  words; `intBin_lifts` and `intMinMax_lifts` are its instances, and `select_comm` gives
  `max`/`min` for every order an injective map to `Int` reads. Instances: MojoProofTest/Atomics.lean
  (`umax`, poison, undef) and its twin `add_or` (an `add` and an `or` do not commute). `sub` also
  commutes but is not admitted.

  An operand need not be a scalar of width `w`: `evalV` (Eval.lean) gives a register's value
  and a global's pointer whatever the type, and `rmw w .max .poison (.ptr p)` succeeds (`strict2`).
  So for the diamond, `rmw_comm_of_ok` (Rmw.lean): for a scalar `v` and all operands `x y`, if
  `rmw w op v x` and `rmw w op v y` both succeed, the two orders give the same value
  (`Lifts.comm_of_ok`: from a word, an update that succeeds has a scalar operand,
  `Lifts.scalar_r`; from poison it gives poison, `Lifts.poison_ok`). `rmw_lifts` gives `Lifts` for
  every admitted operation, and both `rmw_comm` and `rmw_comm_of_ok` go through it. Instance
  `max_ptr` (the pointer operand above); twin `max_faults` (from 1, a `max` by undef and one by a
  pointer fault differently in the two orders).

  On memory: two `atomicrmw`s by threads `n ≠ m` with operation `op`, pointer `p` and size `s` (the same
  type, since the width is a power of two of at least 8) read and write the same bytes. The integer
  codec round-trips (`Layout.Codec.int`), so in either order the second reads what the first wrote, and
  the final bytes are the encoding of `f (f v x_n) x_m = f (f v x_m) x_n`. The checks (`Mem.check`) depend
  on the pointer, the size and the alignment, not on the bytes. With S2 neither thread keeps the old value,
  so the two threads end in the same states in both orders.

  In Lean so far (Confluence.lean): `Mem.load_store`, for every layout, memory, two threads, type, value,
  pointer and two alignments: after a store that succeeds, a load at the same pointer whose check succeeds
  before the store (premise `hc`; the load may be by another thread, at another alignment) succeeds and
  gives what the stored bytes decode to; `Mem.load_store_codec`: for a codec (`Layout.Codec`, integers and
  floats), that is the stored value. `Mem.check_inv` (Schedule.lean) is what a check that succeeds
  checked. Instances `store_load` (an `i32` 7) and `store_load_other` (thread 1's load at alignment 2
  after thread 0's store); twins `store_load_i0` (a poison `i0` is stored as no bytes, and the load gives
  `bits 0 0`) and `load_other` (of `hc`: in a block owned by thread 0, thread 1's load faults). `Mem.load_scalar`: a load of an integer type that succeeds
  gives a scalar of its width (instance `load_scalar`; twin `load_ptr`, a load of a pointer type gives
  a pointer). `Layout.scalar_round`: for every layout, a scalar of a positive width `w` round-trips
  through the bytes of `.int w`, so the first update's result is what the second thread loads (instance
  `undef_round`; twins `poison_i0` of `0 < w` and `ptr_i32` of the scalar). `rmw_comm_of_ok` above gives
  the final value.

  The update itself (Confluence.lean): `Mem.update` is what `exec` does at an `atomicrmw` once its
  operands are evaluated (a load, its read logged, `rmw`, a store), and `Mem.update_eq_ok` says when it
  succeeds (`Mem.load_inv`, `Mem.store_inv`: a load or a store that succeeds is its check, then a
  decode, or an encoding, a put and a log). `Mem.update_comm`: for every two layouts, memory, two
  threads, spaces, operands and alignments, every operation and every positive width `n`, if two
  updates of type `.int n` at one pointer each succeed from `m`, each succeeds after the other, and the
  two orders give the same blocks, the same `next` and the same trace up to swaps. In either order the
  second check succeeds (`Mem.check_log`, `Mem.check_put`), the second load reads the first result
  (`rmw_scalar`, `Layout.scalar_round`), the two final values agree (`rmw_comm_of_ok`), and the second
  put covers the first (`Block.put_put`). Instance MojoProofTest/Confluence.lean `update_comm` (two
  `add`s of 1 and 2 by threads 0 and 1); the twin of its one operation is `add_or` above. At width 0
  nothing is stored and the conclusion holds too, but its proof differs, and `exec` has no such width.

  For steps: `Stmt.checkAtomic_int` (an admitted `atomicrmw` is at `.int w` with `w` a power of two of
  at least 8, so `8 * l.stored (.int w) = w`, `Layout.eight_mul_stored`), and `exec_atomic`,
  `step_atomic`, `Grid.advance_atomic`: a statement, step or grid step that succeeds and would log an
  atomic access `e` is, from every memory with the same shape, the update of type `.int (8 * e.len)`
  at `e`'s pointer by `e`'s operation, with the same operand, a scalar of width `8 * e.len` (`exec`
  checks it), the same space and alignment, then the same thread. So `Grid.advance_atomic_comm`: for every closed grid and contexts, two threads `n ≠ k` whose
  steps succeed and have pending accesses by `atomicrmw`s of one operation at one pointer and size
  succeed in both orders and give the same grid (`Grid.Same`). Instance MojoProofTest/Confluence.lean
  `atomic_comm`: threads 0 and 1 at `atomicrmw add`s of 1 and 2 at offset 0 of block 1 (`adds`).
  The step is rewritten to `Mem.update` for every context and memory, or to the fault at the operand if it is not
  a scalar of width 32 (`exec_rmw`, `step_rmw`, `advance_rmw`, `advance_rmw_fault`), and the update
  shown to succeed by `Mem.update_eq_ok` (`add_ok`). `atomic_diamond`: the two threads' pending writes
  overlap and do not conflict (`Access.conflict`), and `Grid.advance_comm` gives the same grid.

## Proof

**`refl`, `symm`, `trans`**: equality and `List.Perm` on `(phases tr).1`. (Lean: `Trace.Same.refl`,
`symm`, `trans` and `Grid.Same.refl`, `symm`, `trans`.)

**`bisim`.** Take `Same a a'` and a step `a → b`. By L1a the same thread (or the same fire) steps from `a'`,
since its outcome reads the threads and the memory without the trace, which `Same` keeps. It logs the same
events `E` and makes the same changes. So `b'` has the threads, blocks and `next` of `b`, and the traces are
`E ++ tr` and `E ++ tr'`, which are `Trace.Same` by L11. (Lean: `Grid.Same.step`, for every launch and
context map; a grid the same as `a` is `a` with its trace replaced, `Grid.Same.eq_retrace`.)

**`bad_eqv`.** `Faults` reads the threads and the memory without its trace (L1a; done:
`Grid.Same.faults`). `racy` and `kept` are invariant by L12. For `RaceEnabled`, the pending accesses are the same in `a` and `a'` (same threads, same
blocks), and `Trace.Same (P ++ tr) (P ++ tr')` by L11, so L12 applies. (Lean: `Grid.Same.raceEnabled`,
with `Thread.pending_retrace`: the pending accesses read no trace; `Grid.Same.bad`, for every launch,
contexts and grids; instance MojoProofTest/Bad.lean `same_bad`.)

**`diamond`.** Take `g → b` and `g → c` with `g` reachable.

- *One thread, or one fire.* `Grid.advance` and `Grid.fire` are functions, so `b = c`.
- *Two threads `n ≠ m` whose logged accesses conflict.* Let `n`'s step log `Eₙ` and `m`'s step log `Eₘ`, and
  let `aₙ ∈ Eₙ` and `aₘ ∈ Eₘ` conflict (`Access.conflict`). In `b` thread `m` still runs with the same state,
  so its pending accesses are `Eₘ` (L1c), and the trace is `Eₙ ++ g.mem.trace`. In
  `Eₘ ++ Eₙ ++ g.mem.trace`, `aₘ` races with `aₙ`: different threads, a conflict, and only accesses between
  them. So `RaceEnabled b`, and symmetrically `RaceEnabled c`. This is the alternative `Bad b ∧ Bad c` of S1.
- *Two threads `n ≠ m` whose logged accesses do not conflict.* Then `n`'s writes miss `m`'s reads and writes,
  except where both are by exempt `atomicrmw`s (one operation, pointer and size); and conversely.
  - If no access pair is exempt, `n`'s step leaves `m`'s footprint unchanged, as in schedule-owned.md's
    diamond with "disjointness" replaced by "no conflict": bytes are the pending reads; liveness, and the
    bytes that `lifetime.start` resets (L1b), change only for `n`'s own blocks (W2), and `m`'s access to one
    of them faults in every state (`Mem.check`, live or dead), so L2 does not read them; a new block is at
    `m.fresh n k`, which `m` does not name (C2). So by L2 `m` steps from `b` to `d` with the same
    changes as from `g`, and symmetrically `n` from `c` to `d'`. The blocks of `d` and `d'` are equal (the
    changes touch disjoint bytes, flags and numbers), so are the threads and `next`, and the traces are
    `Eₘ ++ Eₙ ++ tr` and `Eₙ ++ Eₘ ++ tr`, `Trace.Same` by L11 (accesses only).
  - If an access pair is exempt, both steps are `atomicrmw`s with one operation on the same bytes (an
    `atomicrmw`'s two accesses have its own pointer and size). Every other byte, flag and number is as in the
    previous case. By L10 the second step succeeds from either side and the final bytes agree; by S2 the
    threads agree. The traces are as before. (Lean: `Grid.advance_atomic_comm`, and `Grid.advance_comm`
    with the premise that no two pending accesses conflict.)
- *A thread's step and a fire.* As in schedule-owned.md: an enabled fire has no running participant (L5),
  so the thread is not a participant; the fire reads only waiting threads and block addresses (W5) and
  changes no block. The two orders give equal threads and blocks, and traces that differ in the order of
  one `.barrier k` and the thread's accesses. The thread is not in block of threads `k` (all of `k`'s threads
  wait), so L11 applies.
- *Two fires.* As in schedule-owned.md: disjoint participants commute (traces differ in the order of two
  barriers of different blocks of threads, or of none for a shuffle); two barriers that share a thread are
  the same barrier of one block, and two shuffles that share a lane resume the same lanes with the same
  values, so `b = c`. Proved in Lean for every grid and contexts that give the two threads one layout
  (`Grid.fire_fire_comm`): with two layouts a shuffle's results can differ under `nonnull` or
  `align` (MojoProofTest/Confluence.lean `layout_twin`).

**`bad_step`.** Let `g` be bad and `g → g'`.

- *`racy` or `kept = false`.* The trace of `g'` is the trace of `g` with events in front (L1a); `racy_cons`,
  `kept_cons`. (Lean: `Grid.Step.trace`, `racy_append`, `kept_append`.)
- *`RaceEnabled g`, at thread `n` with pending accesses `P`.* If the step is `n`'s, it succeeds and logs `P`
  (L1a), so `racy g'.mem.trace`. Otherwise `n` still runs with the same state and the same `P` (L1c), and
  the trace is `Q ++ tr` where `Q` is another thread's accesses, or a `.barrier k` of a block of threads all
  of whose threads wait, so not `n`'s. By L13, `racy (P ++ Q ++ tr)`: `RaceEnabled g'`. (Lean:
  `Grid.Step.raceEnabled`, for every closed grid in which no collective call that completes logs a barrier
  of a running thread's block of threads; in a grid reachable from the start that holds
  (`Grid.start_reach_fired`), so `Grid.start_reach_bad_trace` gives the three parts but faults. Instances
  MojoProofTest/Bad.lean `fire_race` and `start_bad`; twin `fire_race_twin`: in contexts that put both
  threads in one block of threads the barrier is the racing thread's, and after it no race is enabled.)
- *`Faults g`, at thread `n`'s advance.* Then `n` runs, and the step is by another thread `m` or a fire.
  - A fire: `n` is not a participant, and the fire changes no block. (Lean: `Grid.advance_fault_fire`,
    for every launch, contexts and grid.)
  - Thread `m`, whose logged accesses `Eₘ` conflict with one of `n`'s pending accesses `P`: then
    `racy (P ++ Eₘ ++ tr)` as in the diamond, so `RaceEnabled g'`. (Lean: `racy_conflict`, in
    `Grid.Step.advance_fault`, when a write of `m`'s overlaps an access of `n`'s that is not an exempt
    `atomicrmw` with it.)
  - Thread `m`, no conflict and no exempt pair: `m`'s step leaves `n`'s footprint unchanged (as in the
    diamond: a reset by `m`'s `lifetime.start` is in a block of `m`, which `n` cannot access), so `n`
    faults from `g'` too (L2). The cases of schedule-owned.md's case P apply: a pointer of
    `n` to no block keeps pointing to no block (C1), an `alloca` number in use stays in use. (Lean:
    `Grid.advance_fault`, for every closed grid whose threads own their allocas, by `step_fault`, when
    no write of `m`'s overlaps an access of `n`'s; with the two cases above `Grid.Step.advance_fault`,
    and so `Grid.Step.bad` and `Grid.start_reach_bad`. Instances MojoProofTest/Bad.lean `fault_stays`,
    `fault_race`, `fault_bad`, `start_fault`.)
  - Thread `m`, with an exempt pair: both are `atomicrmw`s with one operation on the same bytes, and `m`'s
    succeeded from `g`, so the bytes decode to a value that is not undef, and `m`'s result is not undef
    either (L10). `n`'s `atomicrmw` checks the same pointer (its own alignment and its own thread, which do
    not change) and reads a value that is not undef in both grids. So by L10 it faults from `g'` exactly when
    it faults from `g`: when its own operand is undef, or a check that reads no bytes fails. This needs
    `n`'s operand to be a scalar of the type's width, which `exec` checks: with a pointer
    operand, `rmw` of `max` faults on an old word and gives poison on an old poison. (Lean:
    `Mem.update_before`, for every two layouts, memories, threads, spaces, operations, alignments,
    pointer and width `n > 0`: if an update succeeds after another at the same pointer and width and
    its operand is a scalar of width `n`, it succeeds before it, by `rmw_undef`, `rmw_ok`,
    `Lifts.ok` and `Layout.scalar_round`; so `Grid.advance_fault_atomic`, for every closed grid:
    were `n`'s step to succeed after `m`'s, `step_atomic` from `g`'s memory and `Mem.update_before`
    would make it succeed from `g`. Instance MojoProofTest/Bad.lean `rmw_fault` (on `maxes`, thread
    0's operand is a pointer and its step faults at the check, before and after thread 1's exempt
    update of poison); the twin of the check, `update_before`: without it, `Mem.update` by the
    pointer faults before thread 1's update and succeeds after it.)
- *`Faults g`, at a fire of thread `n`.* schedule-owned.md's argument uses no ownership: the fire's operands,
  a returned participant, an incompatible waiting participant, a lane's operands, or `withAttrs` on block
  addresses. Each persists, in contexts with one layout: after a thread's step
  (`Grid.fire_error_advance`, for every closed grid: the stepping thread runs, so it is no participant,
  and the step keeps the shape of every known block, which is all `withAttrs` reads) and after another
  collective call (`Grid.fire_error_fire`: its threads are none of `n`'s participants, for a lane of
  `n`'s warp or a thread at a barrier of `n`'s block of threads would complete `n`'s call too,
  `Grid.fire_lane`; instance MojoProofTest/Bad.lean `fire_error_stays`, a barrier with a poison
  number). In contexts with two layouts the fault need not persist, as `withAttrs` reads the
  layout of the thread whose fire it is: MojoProofTest/Bad.lean `fire_fault_twin`, where thread 1's
  fire faults under its 32-bit layout, thread 0's completes under its 64-bit one, and the grid after is
  not bad. The start's contexts have one layout. On a grid that is not closed a fault need not
  persist: MojoProofTest/Bad.lean `closed_twin`, where thread 0's `ptrtoint` of a pointer to block 4,
  which has no block, faults, thread 1's `alloca` makes block 4, and the grid after is not bad. Every
  grid reachable from the start is closed (`Grid.start_reach_closed`).

## W3 and W4, and the invariants on `vadd`

The proof does not use W3 or W4. W1 to W5 hold at every grid reachable from the grid `Grid.start`
returns, for every program, and are checked on `vadd` on a launch of 2 blocks of 2 threads.

- W3 is `Grid.start_ctx`: the start's context of thread `n` has the program and `who = ⟨n, n /
  volume L.block⟩`.
- W4, `Grid.ByThreads L g`: every access event of `g`'s trace is by a thread number below the number
  of `g`'s threads, in block of threads `thread / volume L.block`.
  - *Statement.* `Grid.Step.byThreads`: for every launch, contexts that give thread `n` the number
    `n` in block of threads `n / volume L.block`, and grids, a step keeps W4.
    `Grid.start_reach_byThreads`: for every program, kernel, launch, arguments, memory, address
    choice and oracle, W4 holds in every grid reachable from the start's.
  - *Proof.* A step of thread `n` needs a status at `n`, so `n` is below the number of threads. It
    sets that status alone (`set!`, which keeps the number) and puts its pending accesses in front of
    the trace (`Grid.advance_set`), each by `(c n).who` (`Thread.pending_who`), which is
    `⟨n, n / volume L.block⟩`. A collective call resumes threads by `set!` (`resumeAll`, so the number
    is kept, `resumeAll_size`) and logs at most a barrier event, which is no access
    (`Grid.fire_frame`, `Grid.mem_fired`). The start's trace is empty and its contexts are W3's (`Grid.start_ctx`);
    induction on the run.
- The instance (MojoProofTest/Start.lean): `vadd` on 2 blocks of 2 threads with buffers at blocks
  1 to 3 of a caller memory with no pointer byte starts, for every address choice and oracle, with
  4 running threads and an empty trace, and every grid reachable from its grid has W1
  (`Grid.start_reach_closed`), W2 (`Grid.start_owns`, `Grid.reach_owns`), W3, W4 and W5
  (`Grid.reach_keeps`, `Grid.start_reach_atCalls`) (`invariants`). Twins: W1 fails at the start's
  grid when a byte of the caller's memory points to a block from `next` on (`closed_twin`); W4 fails
  after a step in contexts that are not the start's (one block of threads for two threads on a
  launch of one thread per block, `byThreads_twin`).

## Dependencies

- `Confluent`, `Confluent.one_run` (MojoProof/Sem/OneRun.lean), with S1;
- `Grid.start`, `Mem.checkClosed`, `Mem.allocNext`, `Grid.Step`, `Grid.advance`, `Grid.fire`, `step`,
  `exec` (with S2), `rmw`, `Stmt.checkAtomic`, `Mem.check`, `Mem.fresh`, `Layout.Codec.int`
  (MojoProof/Sem/Grid.lean, Thread.lean, Value.lean, Buffer.lean);
- `phases`, `clash`, `racy_iff` (MojoProof/Sem/Race.lean); `racy`, `kept`, `Access.conflict`, `Grid.Faults`,
  `Grid.Done` (MojoProof/Sem/Spec.lean); `racy_cons`, `kept_cons`, `kept_iff`, `done_not_faults`,
  `Grid.sound_of_one_run` (MojoProof/Sem/Trace.lean);
- schedule-owned.md: `Thread.pending`, L1a, L1b, L2, L3, W2, W5, `Grid.Closed`, C1, C2;
- `BitVec` commutativity and associativity of `+`, `&&&`, `|||`, `^^^`, and of `max`/`min` in both orders
  (Lean core, Mathlib).

## Instances and twins

- The two-thread twins of `trace_examples` as grids: two `atomicrmw add`s on one word (the diamond's L10
  case: both orders give equal grids), and an `add` then an `or` (the conflict case: both grids after one
  step have an enabled race). Eval `atomics, twice` and `atomics of two operations` run them.
- `reduction` (one launch): with S2 its two orders of two block leaders' `atomicrmw add` give `Same` grids.
- Negative twin: without S2 the two orders of the first instance differ in the old-value register, so
  `Same` fails; a check that compares the threads of the two orders fails (to add with S2).
