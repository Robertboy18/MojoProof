# Schedule independence by ownership (T2′, `Grid.confluent_owned`)

Lean: conclusions 1 and 2 proved, for every program, kernel, launch, arguments, address choice,
oracle and discipline, in MojoProof/Sem/ScheduleOwned.lean (`Grid.confluent_owned`,
`Grid.owned_clean`, `Grid.owned_race`, `Grid.owned_bad`), by the route of section "Route in Lean"
below: T2 (`Grid.confluent`, schedule.md) with its bad set replaced by `Grid.Faults`
(`Confluent.of_iff`), which conclusion 2 allows. Conclusion 3 is proved in a stronger form, for
every program, kernel, launch, arguments, address choice, oracle and discipline
(`Grid.owned_sound`, with the trace lemma `racy_kept_of_local` and `Grid.Done.bad_iff`,
MojoProof/Sem/Determinism.lean): its premises are on the trace of the done grid of the one run,
not on every reachable grid (section "Conclusion 3 in Lean"). This document's own route, below the
statement, is not formalized; it is kept because it needs no commutation of atomics.

It uses that an `alloca`'s block number is `Mem.fresh`, from its thread and step count, and that no
step changes `Mem.next`. That an `alloca` reads its addresses from the skeleton choices
(`Ctx.addr`) and that the oracle holds the float choices only are not needed: this proof fixes
both. The lemmas it uses (section "Lemmas used") are proved, for the Lean route, in schedule.md's
setting: L1a (`step_pending`, `Grid.advance_pending`, `Grid.fire_trace`, and `exec_retrace`,
`step_retrace`, `Grid.advance_retrace`, `Grid.fire_retrace` for the trace no step or fire reads),
MojoProof/Sem/Schedule.lean, and with it `bisim` and the fault part of `bad_eqv`
(`Grid.Same.step`, `Grid.Same.faults`); L1c for the memory (`Thread.pending_shape`) and W5's block
part (`Grid.reach_keeps`: every grid reachable from `g` keeps every block of `g`, and, C1's part
about memory, its `next` and every number below `next` with no block free); C1's other part, the
closed-grid invariant (`Grid.reach_closed` and `Grid.pending_reach`, MojoProof/Sem/Closed.lean:
every step and fire keeps `Grid.Closed`, and a running thread of a closed grid has the same
pending accesses in every grid reachable from it; from the start, on a caller's memory whose
pointer bytes name known numbers, `Grid.start_closed`, `Grid.start_reach_closed` and
`Grid.start_pending`); W5's other part (`Grid.start_reach_atCalls`: in every grid reachable from
the start, every waiting thread is at its collective call, `Thread.AtCall`); and L1b
(`step_changes`, and in every grid reachable from the start `Grid.start_reach_changes`,
MojoProof/Sem/Writes.lean; `Grid.fire_blocks`, Schedule.lean). MojoProofTest/Launch.lean checks
the start's invariants on a launch that allocates, stores, waits at a barrier and returns.

The start makes the invariants hold. `Grid.start` first checks the caller's memory
(`Mem.checkClosed`, MojoProof/Sem/Grid.lean): a memory with `next = 0` or a block 0 is unsupported,
and so is one in which an argument, or a pointer byte of a block below `next`, names a number from
`next` on. The launch's own blocks (shared memory, `byval` copies) come at `next` and above. An
`alloca` whose number is in use is unsupported, and so is an allocation of the start
(`Mem.allocNext`) at a number that has a block, so no block is ever overwritten, and the start
deletes no block of the caller's memory (`Grid.start_blocks`, proved for every program, launch,
memory and choice). `Mem.checkClosed` checks the fields of `Mem.Closed` except `above` (no block
from `next` on), which no function can check, and except the pointer bytes of blocks from `next`
on, which `above` says do not exist; so T2 takes the hypothesis that the caller's memory is closed
for the arguments. The invariant that every block number a thread holds is allocated (W1) is
replaced by the closed-grid invariant `Grid.Closed`, which holds at the start of a closed memory
and which every step keeps (section "The closed-grid invariant"). Without the check the statement
is false: a pointer argument naming the number that another thread's `alloca` takes later faults
in one order and runs in the other (the counterexample in section "The closed-grid invariant").
`lifetime.start` makes the bytes of a thread's own block undefined; L1b, L2, the disjointness
argument and `bad_step` include those bytes.

**Scope.** Every program, launch, start memory, skeleton choice and oracle, under the hypotheses
below. The hypotheses hold for kernels whose memory accesses follow one tiling for the whole run
(`vector_addition`). They fail for kernels whose shared-memory tiles change hands at a barrier
(`tiled_matmul`, which needs race freedom per barrier interval, barrier-owned.md) and for kernels
with atomics on one location (`reduction`, which needs L10: two `atomicrmw`s that
`Access.conflict` exempts, of one operation on the same bytes, commute). The hypotheses constrain
where accesses go, not whether steps fault. Faults are the bad states. An out-of-bounds access lies
in no tile, so a kernel with one is not covered.

## Statement

**Data.** `hs : Grid.start prog fn L args m ch oracle = .ok (g₀, c)` and `hm : m.Closed args`, for
every start memory `m` and argument values `args`. A closed memory passes the start's check
(`Mem.checkClosed_of_closed`), and the start keeps every block of `m` (`Grid.start_blocks`). Let
`N := g₀.threads.size`, the number of the start grid's threads. The Lean statement takes T2's
hypothesis on the caller's memory instead of `hm`: every pointer byte of its blocks names a number
below `next` or with a block (`hm : m.BytesIn m.Known`, schedule.md).
The states are `γ := { g // ReflTransGen (Grid.Step L c) g₀ g }`. The relation is `rc x y := Grid.Step L c x.1 y.1`.
A discipline is a tiling map `T : Nat → Option (Tiling ι)` and a tile map `own : Nat → ι` (`Tiling`, `Owned`:
MojoProof/Sem/Trace.lean).

**A definition the proof adds (part of L1).** `Thread.pending (c : Ctx) (t : Thread) (m : Mem) : List Event`
lists the accesses that the step of `t` from `m` makes: for a `load`, `store` or `atomicrmw` at the thread's
position whose pointer operand evaluates, its access (two for `atomicrmw`, read then write), and nothing
otherwise. This holds whether the step then succeeds or faults. On success the step logs exactly these
accesses (`step_pending`). (Proved in MojoProof/Sem/Schedule.lean, as a list of events, newest first, so
an `atomicrmw`'s write is in front of its read; `step_pending` for every context, thread and memory.)

**Hypotheses.**

- `hH` (owned accesses): for every reachable `g`, every thread `n` and every access `a` among
  `Grid.pending c g n` (`Thread.pending (c n) t g.mem` if `g.threads[n]? = some (.run t)`, none
  otherwise), either `Owned T own a`, or `a` is thread-local: `g.mem.Owned n a.ptr.block` (block
  `a.ptr.block` of `g.mem` has owner `.thread n`).
- `hX` (exclusive tiles): `own` is injective on thread numbers below `N`.
- `hI` (invariant loads): for every reachable `g`, thread `n` and access `a` among `Grid.pending c g n`
  with `invariant = true`, `T a.ptr.block = none` and `a` is not thread-local
  (`¬ g.mem.Owned n a.ptr.block`).

**Equivalence.** `Grid.Same g g'`: `g.threads = g'.threads`, `g.mem.blocks = g'.mem.blocks`,
`g.mem.next = g'.mem.next`, and `g.mem.trace` is a permutation of `g'.mem.trace` (`List.Perm`). No renaming
of blocks is needed: a block's number (`Mem.fresh`) does not depend on the schedule. T2 (schedule.md)
replaces `List.Perm` with `Trace.Same`, which also keeps each access's barrier phase, and proves T2′ as
its corollary; the Lean proof follows schedule.md, and this document's own route is kept as the one
that needs no atomic commutation.

**Conclusions.**

1. `Confluent rc (fun x y => Grid.Same x.1 y.1) (fun x => x.1.Faults L c)`.
2. For every reachable `g`: `racy g.mem.trace = false` and `kept g.mem.trace = true`; and if a race
   is enabled in `g` (`Grid.RaceEnabled`), `g` faults (the racing thread's step is a fault). So on
   reachable grids `Grid.Bad` is `Grid.Faults`: no reachable grid has a racy trace or a broken
   promise of `!invariant.load`. An enabled race is not excluded, only one whose step succeeds:
   `Stmt.pending` lists an access before the step checks it, so a thread's pending access may
   conflict with another's and still be one the memory refuses.
3. Corollary through `Grid.sound_of_one_run` (adapter.md): if one run reaches a done grid `z` and
   `obs` depends only on `Mem.blocks`, then `Grid.Sound L c g₀ obs R` with `R` the property of `obs z.mem`.
   `hT` and `hK` come from conclusion 2. `hF` holds because `Bad` is `Faults`. `hD` and `hO` hold because
   `Same` keeps the threads and the blocks. The Lean form (`Grid.owned_sound`) goes through T2's
   `Grid.start_sound` instead, and needs the discipline of the done grid's trace only: section
   "Conclusion 3 in Lean".

**Why the bad set is `Faults`.** `Bad := False` would make the adapter's `hF` say that no reachable
grid faults, which the hypotheses do not give: a kernel can fault in every schedule. `Bad := Faults`
needs `bad_step`, which says that faults persist. Under `hH` this is a frame argument (case P
below). It needs neither `Grid.RaceEnabled` nor L7.

## Lemmas used

- L1a (trace): `step` and `Grid.fire` do not read `Mem.trace`. A successful step's trace is
  `Thread.pending ... ++ m.trace`. A fire's trace is `m.trace` with one `.barrier` event in front for a barrier,
  and unchanged for a shuffle. (Proved for steps: `step_pending`, with `exec_pending` for every statement; a
  step that stops at a collective has no pending accesses; `Grid.advance_pending`, the same for a grid
  step of thread `n`, for every grid. Proved for fires: `Grid.fire_trace`, for every grid. Proved: no
  step or fire reads the trace, for every context, statement, scope, thread, grid and trace `tr`: on
  the input with its trace replaced by `tr`, the result is the same with `tr` and the logged events in
  front as its trace (`exec_retrace`, `step_retrace`, `Grid.advance_retrace`, `Grid.fire_retrace`).)
- L1b (writes): a successful step of thread `n` changes `m` only:
  - at the bytes of its pending writes;
  - at the liveness of blocks with owner `.thread n`, and at all bytes of such a block, which
    `lifetime.start` makes undefined with no pending write (`Mem.setLive`; LangRef,
    `llvm.lifetime.start`, resets the contents of an object that is already live too);
  - by adding the block `m.fresh n k` at an `alloca` at step `k`, which no block had (an
    `alloca` whose number is in use faults);
  - at the trace.

  It never changes `m.next` and never removes a block. A fire changes no block.

  In Lean (MojoProof/Sem/Writes.lean, for every context, thread and memory): `Mem.Changes L N m m'`
  says that `m'` keeps every block of `m` with its shape, read-only flag and owner (and `Mem.Keeps`),
  adds blocks only at numbers of `N`, and has the trace of `m` with events `d` in front, and that a
  block at a number outside `L` keeps its liveness, and its bytes but those below its size that an
  access of `d` writes (`Access.Writes`; a store's check bounds the bytes it writes by the block's
  size, `Mem.store_changes`). So such a block keeps its owner, its size and its bytes from its size
  on (`Mem.Changes.above`). `step_changes`: a step of thread `c.who.thread` that continues or returns
  satisfies `Mem.Changes L N m m'` if `L` has every block the thread owns and every alloca of its
  frames, and `N` has `m.fresh c.who.thread t.k`; by `step_pending`, `d` is its pending accesses.
  The premise on the allocas is needed: a return makes the frame's allocas dead (`Mem.setLive`),
  and a frame whose allocas list a block of every thread makes that block dead
  (MojoProofTest/Writes.lean, `ret_twin`). `Grid.advance_changes` is the same for the step of
  thread `n` of a grid, in context `c n`; `Grid.fire_blocks` (Schedule.lean): a fire changes no
  block and keeps `next`. The premise on the allocas holds in every grid reachable from the start
  (`Grid.Owns`: every alloca of a frame of thread `n` is a block that thread `(c n).who.thread`
  owns; `Grid.start_owns`, `Grid.advance_owns`, `Grid.fire_owns`, `Grid.reach_owns`), so
  `Grid.start_reach_changes`, for every program, kernel, launch, arguments, memory and choices:
  in every grid reachable from the start, a step of the running thread `t` at `n` is
  `Mem.Changes` with `L` the blocks thread `(c n).who.thread` owns and `N` its fresh block
  `fresh (c n).who.thread t.k`. The twin of the invariant: the grid of a thread whose frame lists a
  block of every thread among its allocas is not `Grid.Owns` (`owns_twin`).
  `Grid.start_reach_above`, for the same scope: in every grid reachable from the start, every
  block of the start's memory whose owner is no thread has its owner, its size and its bytes from
  its size on (a step by `Mem.Changes.above`, a fire changes no block), and the caller's blocks are
  blocks of the start's memory (`Grid.start_blocks`). This is the part of the equality of a final
  block with an expected one that evaluation cannot check, the bytes being a function: a check of
  the fields and of the bytes below a bound at least every block's size gives the rest. The
  premise on the owner is needed: making a block live (`Mem.setLive`) makes every byte of it
  undefined, those from its size on too (MojoProofTest/Writes.lean, `above_twin`). Instance:
  vector_addition's run on one thread (MojoProofTest/SkelVadd.lean, `above_vadd`).
- L2 (frame): let `t` be a thread `n` with step count `k`, and let its *names* be the block numbers of the
  pointers it holds (`Grid.Closed` below) and, if it is at an `alloca`, `m.fresh n k`. If `m₁` and `m₂` agree
  on three things, then the steps of `t` from `m₁` and from `m₂` both fault, or both succeed with the same
  thread state and the same changes (L1b) applied to their memories. The three things are:
  - `next`, and the bytes of the pending reads of `t` in blocks that another thread does not own;
  - the existence, space, size, addresses, `readOnly` and owner of every block `t` names;
  - the liveness of every block `t` names that another thread does not own.

  An access of `t` to a block that another thread owns faults in every state, before any byte is
  read (`Mem.check`: dead, or live and owned by another thread), and so does a lifetime marker of
  `t` on it (unsupported); so `t` reads neither the liveness nor the bytes of such a block.

  A step looks a block up only through a pointer it holds (`Mem.block`, `Mem.addr`, `Mem.check`) or at its
  `alloca`'s number, so it does not see the blocks it does not name. The same holds of a fire and the
  names of its participants.

  In Lean (MojoProof/Sem/Frame.lean), for steps. `Mem.Agree w S P m₁ m₂`: `m₁` and `m₂` have the
  same `next`, and at every number `b` of `S` both have no block, or blocks with the same shape,
  `readOnly` and owner which, if the owner admits thread `w` (`Owner.admits`), have the same
  liveness and the same bytes where a read access of `P` reads (`Reads P b`; `Block.Agree`). `S`
  stands for the names: it must have every number the scope of the innermost frame names
  (`Scope.NamesIn`: null, the registers and the globals) and the `alloca`'s number. The changes
  are a list of `Mem.Op` (bytes put into a block, a block set, a block made live or dead, an event
  logged), applied in order by `Mem.run`; `Step.withMem m r` is `r` with its memory, if it has one,
  replaced by `m`. For every context, thread and memories:

      theorem step_agree {c : Ctx} {t : Thread} {m₁ m₂ : Mem} {r : Step}
          (hs : ∀ f, t.frames.head? = some f → (c.scope m₁ f t.k).NamesIn S)
          (hk : S (m₁.fresh c.who.thread t.k)) (h : m₁.Agree c.who S (t.pending c m₁) m₂)
          (he : step c t m₁ = .ok r) :
          ∃ ops, (∀ o ∈ ops, o.At m₁ c.who (fun b => m₁.Owned c.who.thread b ∨ ∃ f ∈ t.frames,
              b ∈ f.allocas) (· = m₁.fresh c.who.thread t.k) (ops.filterMap Mem.Op.event)) ∧
            r = r.withMem (m₁.run ops) ∧ step c t m₂ = .ok (r.withMem (m₂.run ops))

  and `step_fault`, under the same hypotheses: `step c t m₁ = .error x → ∃ y, step c t m₂ =
  .error y` (by `step_agree` from `m₂`, with `Mem.Agree.symm` and `Thread.pending_shape`). So
  both fault, or both succeed with the same result and the same changes. `exec_agree` is the same
  for a statement. Instances: MojoProofTest/Frame.lean (`agree`, `store`, and `load`: a load of an
  `i32` gives 7 from two memories that differ only at bytes it does not read); the twins
  `names_twin` (a store through a pointer to a block outside `S` continues on a memory with that
  block and faults on one without it) and `load_twin` (two memories that differ at a byte the load
  reads give 7 and 8). The first conjunct, where the ops act (`Mem.Op.At`), is
  step 2 of the two-thread case below. L2 for the grid's steps is `Grid.advance_agree`, and its
  use in the diamond with the changes of another thread's step (L1b) is `Grid.advance_agree_other`
  and `Grid.advance_comm` (MojoProof/Sem/Confluence.lean). A fire
  changes no block (`Grid.fire_blocks`).
- L3 (choices): step `k` of thread `n` reads its skeleton choices `(c n).addr` and its oracle `oracle n` at
  `Nat.pair k i` only, and `k` is the thread's own count. This holds by construction, with no Lean
  lemma: `Ctx.scope` gives step `k` the oracle numbers `c.oracle (Nat.pair k i)`, and `exec`
  gives an `alloca` the addresses `c.addr (Nat.pair k 0)` and `c.addr (Nat.pair k 1)`.
- W1 (closed grids): `Grid.Closed` holds of every reachable grid (next section).
  W2: a block made by thread `n`'s `alloca` has owner `.thread n`. W5: a waiting thread is at its
  collective call, and a block's space, size and addresses never change. Both parts of W5 are
  proved: `Grid.reach_keeps` (MojoProof/Sem/Schedule.lean), and `Grid.start_reach_atCalls`
  (MojoProof/Sem/Closed.lean; `Thread.AtCall c t i fn`: the current statement of `t` calls `fn`,
  the function of `c`'s module whose intrinsic is `i`).
- `Mem.check` (MojoProof/Sem/Value.lean): an access to a block owned by another thread is undefined
  behavior, dead or live. So such an access faults in every order, and a logged access to a thread-local
  block is by its owner.

## The closed-grid invariant (W1)

A grid *holds* a pointer if it occurs (inside vectors and aggregates too) in a register, the `fmul`
operands (`prods`) or the `allocas` of a frame of a thread, in the arguments of a waiting thread, in the
globals table of a context, or as a pointer byte `.ptr p i` below the size of a block. Define

    Grid.Closed g := ∀ p held by g, p.block < g.mem.next ∨ (g.mem.blocks p.block).isSome.

- *Start.* After `Grid.start`, every held pointer names a number below `next`. The caller's memory is
  closed for the arguments (the hypothesis `hm`, `Mem.Closed`): `next` is at least 1, block 0 and every
  number from `next` on have no block, and every block number the arguments name (`Val.bounds`) and
  every pointer byte below the size of a block names is below `next`. The start changes none of its
  blocks (`Grid.start_blocks`) and allocates the shared memory and the `byval` copies at `next` and up, whose bytes encode the arguments. The registers of a thread are its `launchArgs`: a `byval` copy is a pointer to a block
  below `next`, and every other argument is its value under `withAttrs`, which holds no pointer the value
  does not hold. The globals tables point to shared blocks below `next`. Null is block 0, below `next` (at least 1),
  and no block has number 0, so an access through null is undefined behavior in every grid.
- *Step.* Every successful step of a closed grid gives a closed grid. `next` never changes and no block is
  removed (L1b), so a pointer that was held keeps its property. The new held pointers are: an `alloca`'s
  result (its block exists); a GEP, `select`, `phi`, call or return of held values (GEP keeps the block
  number); a loaded value, decoded from pointer bytes of an existing block (held) or null from zero bytes;
  the bytes a store writes, encoded from a held value (`lifetime.start` writes undefined bytes, which
  hold no pointer); a shuffle's results, the operands of its lanes or
  poison. No operation makes a pointer from an integer (`inttoptr` is unsupported), and no intrinsic
  returns a pointer it was not given.

In Lean (MojoProof/Sem/Names.lean and Closed.lean), a number is *known* to `m` (`Mem.Known`) if it
is below `m.next` or has a block, and `Grid.Closed c g` has four fields: `null` (0 is known),
`threads` (`Status.NamesIn`: every value in a register of a frame of a thread, and every argument of
a waiting thread, names only known numbers, `Val.NamesIn`), `bytes` (`Mem.BytesIn`: every pointer
byte below the size of a block does) and `globals` (every global of every context `c n` does). It
leaves out `prods` and `allocas`, as no step takes a pointer from them: an `fadd` makes only floats
from the `fmul` operands, and a return's `setLive` on the `allocas` changes only liveness. Proved,
for every program, context map, launch and grid: *Step* (`exec_closed`, `enter_closed`, `step_closed`,
`Grid.advance_closed`, `Grid.fire_closed`; every grid reachable from a closed grid is closed,
`Grid.reach_closed`) and C1 below (`Grid.pending_reach`, from `Grid.reach_keeps`,
`Mem.Keeps.sameShape` and `Thread.pending_shape`) and *Start* (`Grid.start_closed`, for every
program, kernel, launch, arguments, choices and memory whose pointer bytes name known numbers,
`Mem.BytesIn m m.Known`, which a closed memory has, `Mem.Closed.bytesIn`; the start's check gives the
rest, `Mem.checkClosed_ok`). So C1 holds from the start (`Grid.start_reach_closed`,
`Grid.start_pending`). The premise on the bytes is needed: the memory `mem100` (`next = 2`, one block 5
holding a pointer to block 100) passes the check and starts, and its grid is not closed
(MojoProofTest/Closed.lean, `start_twin`). Not proved: C2.

Two consequences carry the proof.

- (C1) In a closed grid, a pointer to no block names a number below `next`. No step makes a block below
  `next` (an `alloca`'s number `m.fresh n k = next + Nat.pair n k` is at least `next`), so the pointer
  points to no block in every grid reachable from there.
- (C2) The number of the block a step of thread `m` adds, `m.fresh m k`, had no block and is at least
  `next`, so in the closed grid before the step nothing held a pointer to it: no other thread names it.
  It is also different from every `m.fresh n k'` with `n ≠ m` (`Nat.pair` is injective).

Under `Closed`, an `alloca`'s number is never in use in a reachable grid. The blocks at numbers from
`next` on are those of earlier `alloca`s, `m.fresh n' k'` with `k'` below thread `n'`'s count. The check
in `exec` is kept anyway, because with it L1b needs no invariant.

**Counterexample without the start's check (MojoProofTest/Eval.lean, `startMemTests`).** Two
threads run `%a = alloca i32; %x = ptrtoint ptr %p to i64; ret void` with `%p = .ptr ⟨5, 0⟩`.
Without the check, `next = 3` after the buffer (block 1) and the dynamic shared memory (block 2),
and thread 1's `alloca` takes `3 + Nat.pair 1 0 = 5`. Thread 0 first: its `ptrtoint` is undefined
behavior (pointer to no block). Thread 1 first: block 5 exists, and both threads run to the end. A
step takes a faulting grid to one that does not fault, against `bad_step`. With the check, the
caller's memory (the buffer as block 1, `next = 2`) names block 5 from `next` on through the
argument, so the start (`Mem.checkClosed`) refuses the launch, in both orders; the test checks the
refusal.

## Proof

**Disjointness.** Let two different threads `n` and `m` both run in a reachable `g`. Each write that `n`'s step
makes lies in tile `own n` of a tiled block, or in a block owned by `.thread n`. `Owned.read` forbids writes to
untiled blocks. Each read that `m`'s step makes lies in tile `own m`, in an untiled block, or in a block owned
by `.thread m`. Tiles `own n` and `own m` are disjoint (`hX`, `Tiling.disj`). Untiled blocks are never written,
and owners differ. So `n`'s writes miss `m`'s reads and `m`'s writes. Both steps add blocks only at numbers
keyed by their own thread, which the other thread does not name (C2), and change liveness, and reset
bytes (`lifetime.start`), only of their own blocks, to which the other thread's accesses fault in every
state (`Mem.check`).

In Lean, the part about memories (MojoProof/Sem/Frame.lean, `Mem.Changes.agree`): if `m'` is `m`
changed as L1b allows (`Mem.Changes L N m m'`, with events `d` in front of its trace), then `m` and
`m'` agree for thread `w` at `S` and the reads of `P` (L2's `Mem.Agree`) if `N` has no number of
`S`, no block of `m` at a number of `S` and `L` admits `w`, and no access of `d` writes a byte that
a read of `P` reads in a block of `S` that admits `w`:

    theorem Mem.Changes.agree {L N : Nat → Prop} {m m' : Mem} {w : Who} {P : List Event}
        (h : m.Changes L N m') (hN : ∀ b, S b → ¬ N b)
        (hL : ∀ b x, S b → L b → m.blocks b = some x → x.owner.admits w = false)
        (hd : ∀ d, m'.trace = d ++ m.trace → ∀ b x i a, S b → m.blocks b = some x →
          x.owner.admits w = true → Reads P b i → .access a ∈ d → ¬ a.Writes b i) :
        m.Agree w S P m'

With `m'` the memory after `m`'s step (`Grid.start_reach_changes`: `L` the blocks `m` owns, `N`
its fresh block, `d` its pending accesses), `S` `n`'s names and `P` `n`'s pending accesses, the
three premises are C2, the owners and the tiles; that they hold in every reachable grid is not yet
proved. Instance: MojoProofTest/Frame.lean, `changes_agree` (a store of bytes 0 to 3 and a read of
bytes 4 to 7); the twin `changes_twin`: at a read of the bytes the store writes, the memories do not
agree.

**`refl`, `symm`, `trans`** hold because `Same` is equality and `List.Perm`.

**`bisim`.** Take `Same a a'` and a step `a → b`. By L1a the same thread (or the same fire) steps from `a'` to
`b'`, with the same new events in front of a permuted trace. So `Same b b'`. (Lean: `Grid.Same.step`, for
every launch and context map.)

**`bad_eqv`.** `Faults` reads the threads and, through `step` and `Grid.fire`, the memory without its trace
(L1a). `Same` keeps both. (Proved for `Faults`: `Grid.Same.faults`.)

**`diamond`.** Take two steps `g → b` and `g → b'`, with `g` reachable.

- *A thread's step and the same thread's step.* `Grid.advance` is a function, so `b = b'` and `Same b b'`.
- *The steps of two threads `n ≠ m`.* By disjointness and C2, `n`'s step leaves `m`'s footprint (the
  three things of L2) unchanged. So by L2,
  `m` steps from `b` to `d`, with the same changes as from `g`. Symmetrically, `n` steps from `b'` to `d'`.
  `d` and `d'` apply the same two sets of changes in the two orders. The changes touch disjoint bytes,
  liveness flags and block numbers (a reset by `lifetime.start` touches the bytes of the stepping
  thread's own block, which the other thread's successful step does not access), so the blocks are
  equal. The traces are `Eₘ ++ Eₙ ++ tr` and
  `Eₙ ++ Eₘ ++ tr`, a permutation. Thread states change only at `n` and `m`, so `Same d d'`.
  L3 makes each thread's choices the same in both orders.
- *A thread's step and a fire at `k`.* An enabled fire has no running participant: `Grid.fire` gives `none`
  while a participant of the barrier's block, or a lane of the shuffle's warp, runs (L5). So the running
  thread `n` is not a participant. Thread `n`'s step leaves the participants' states unchanged. It also
  leaves the memory that the fire reads unchanged: the fire reads only block addresses, through `withAttrs`,
  and these never change (W5). So the fire is still enabled from `b` and gives the same resumed threads.
  The fire changes no block and no state of `n` (L1a), so `n`'s step from `b'` is the same as from `g` (L2).
  The two results differ at most in the order of one `.barrier` event in the trace, so `Same d d'`.
- *Two fires, at `k` and `j`.* If their participant sets are disjoint, they commute as in the previous
  case, with traces equal up to the order of two barrier events.
  - Two barriers sharing a thread: they share the whole block of threads. Each resumes every thread of the
    block with no value and logs `.barrier` of that block, so `b = b'`.
  - Two shuffles sharing a lane: they share the warp. Both enabled fires check every waiting lane against
    their own mode, mask and position, so `k`'s and `j`'s agree. Their `base`, `lanes`, `parts` and results
    are then equal, and `b = b'`.
  - A barrier and a shuffle cannot share a thread, because a thread waits at one call.

**The two-thread case in Lean (done, under its premises).** `step_agree` gave `∃ ops` without saying
where the ops act, and two lists of ops commute only if they act at different places. Five steps,
all done:

1. `Mem.Op.At m w L N W o` (MojoProof/Sem/Frame.lean): where op `o` of a step of thread `w` on
   memory `m` acts. A put `.put b o bs` is into a block of `m` whose owner admits `w`, and every
   byte `i` from `o` below `o + bs.length` is written by an access of `W` (`Access.Writes a b i`);
   a set `.set b _` has `N b` and no block at `b` in `m`; a liveness change `.live b _` has `L b`;
   a log `.log e` has `e` an access (a step logs its pending accesses, `step_pending`, and
   `Stmt.pending` lists only accesses). The puts are the stores' `Mem.write`s, the sets the
   `alloca`s at the fresh number, the liveness changes `lifetime.start` and `.end`
   (`Intrinsic.ops`, `intrinsic_at`) and the returns' `alloca`s.

       def Mem.Op.At (m : Mem) (w : Who) (L N : Nat → Prop) (W : List Event) : Mem.Op → Prop
         | .put b o bs => (∃ x, m.blocks b = some x ∧ x.owner.admits w = true) ∧
             ∀ i, o ≤ i → i < o + bs.length → ∃ a, .access a ∈ W ∧ a.Writes b i
         | .set b _ => N b ∧ m.blocks b = none
         | .live b _ => L b
         | .log e => ∃ a, e = .access a

2. `exec_agree` and `step_agree` give the places of their ops, with `W` the events the ops log:
   `step_agree`'s conclusion is

       ∃ ops, (∀ o ∈ ops, o.At m₁ c.who (fun b => m₁.Owned c.who.thread b ∨ ∃ f ∈ t.frames,
           b ∈ f.allocas) (· = m₁.fresh c.who.thread t.k) (ops.filterMap Mem.Op.event)) ∧
         r = r.withMem (m₁.run ops) ∧ step c t m₂ = .ok (r.withMem (m₂.run ops))

   and `exec_agree`'s the same with `L` the blocks of `s.mem` the thread owns and `N` the fresh
   number at step `k`. `Mem.write_agree` and `Mem.store_agree` give a
   store's put inside the block, in a block that admits the thread.
3. `Mem.run_comm`: ops at disjoint places commute. Proved (MojoProof/Sem/Confluence.lean, for every
   memory and all ops; `Mem.Op.Apart` and, for each number `c`, `Mem.Op.on c`, what an op does to
   the block there). Two puts at one block are apart if no byte the first puts is one the second
   puts (`∀ i, o ≤ i → i < o + bs.length → i < o' ∨ o' + bs'.length ≤ i`), so empty puts are
   apart from every put:

       theorem Mem.run_comm (m : Mem) {os₁ os₂ : List Mem.Op}
           (h : ∀ o₁ ∈ os₁, ∀ o₂ ∈ os₂, o₁.Apart o₂) :
           ((m.run os₁).run os₂).blocks = ((m.run os₂).run os₁).blocks ∧
             ((m.run os₁).run os₂).next = ((m.run os₂).run os₁).next ∧
             Trace.Same ((m.run os₁).run os₂).trace ((m.run os₂).run os₁).trace

   Instances: MojoProofTest/Confluence.lean `comm` and `same` (puts at the two halves of one
   block, writes by threads 0 and 1 logged, and a set); the twins `twin` (two puts at byte 0: not
   apart, and the orders differ there) and `trace_twin` (a write by thread 1 and a barrier of its
   block of threads: not apart, and after a write by thread 0 one order is racy and the other
   not).
4. The ops of two threads' steps are apart (`Mem.Op.At.apart`, for every memory and all ops): for
   threads `w`, `w'` with different numbers, if their liveness changes are at blocks of `m` each
   owns, their sets at different numbers, and no write one logs overlaps a write the other logs.
   A put of one and a set of the other are at different blocks, as the put's block exists and the
   set's does not; a liveness change of one is at a block owned by it, whose owner admits no other
   thread, so not at the other's put or liveness change; two puts at one block are at disjoint
   bytes, as a common byte would be written by a write of each; two logs are accesses, which are
   independent.

       theorem Mem.Op.At.apart {m : Mem} {w w' : Who} {L L' N N' : Nat → Prop}
           {W W' : List Event} (hw : w.thread ≠ w'.thread) (hL : ∀ b, L b → m.Owned w.thread b)
           (hL' : ∀ b, L' b → m.Owned w'.thread b) (hN : ∀ b, N b → ¬N' b)
           (hW : ∀ a a', .access a ∈ W → .access a' ∈ W' → a.overlaps a' = true →
             a.write = false ∨ a'.write = false) :
           ∀ {o o' : Mem.Op}, o.At m w L N W → o'.At m w' L' N' W' → o.Apart o'

   In a grid whose threads own their allocas (`Grid.Owns`) the blocks a step's frames allocated
   are blocks it owns, and the fresh numbers of two threads differ (`Mem.fresh_inj`, by
   `Nat.pair_eq_pair`).
5. The case (`Grid.advance_comm`). `Grid.advance_agree` lifts `step_agree` to the grid: `n`'s step
   from `g` gives a status `s` and ops at those places with `g' = {threads := g.threads.set! n s,
   mem := g.mem.run ops}`, and from every grid with `n`'s thread at `n` and a memory `m₂` that
   agrees with `g.mem` for `n`, the same `s` and ops on `m₂`. `Grid.advance_agree_other`: in a
   grid whose threads own their allocas, `k`'s step leaves the memory agreeing for a thread `n`
   with another number at the numbers `g.mem` knows and `n`'s fresh number, if no write of `k`
   overlaps an access of `n` (by `Mem.Changes.agree` with `Grid.advance_changes`). In a closed
   grid those numbers are all `n`'s scope names (`Grid.Closed.scope`), so `n`'s step from `gₖ` is
   `n`'s ops on `gₖ.mem`, and symmetrically; by `Mem.run_comm` and `Array.setIfInBounds_comm` the
   two grids are `Grid.Same`:

       theorem Grid.advance_comm {c : Nat → Ctx} {g gn gk : Grid} {n k : Nat}
           (hg : g.Closed c) (ho : g.Owns c) (hw : (c n).who.thread ≠ (c k).who.thread)
           (hn : g.advance c n = .ok (some gn)) (hk : g.advance c k = .ok (some gk))
           (hW : ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
             a.conflict a' = false) :
           ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧
             g₁.Same g₂

   For every grid, every context map and all threads `n`, `k`. `n ≠ k` follows from `hw`. The
   premise `hW` asks that no pending access of either conflict with one of the other
   (`Access.conflict`). If some write of one overlaps an access of the other, the two are an
   exempt pair, two `atomicrmw`s of one operation at one pointer and size, and
   `Grid.advance_atomic_comm` gives the conclusion (L10, below). Otherwise no write of either
   overlaps any access of the other (not only the other's writes), as the agreement of L2 needs,
   and the argument above applies.

The instance (MojoProofTest/Confluence.lean `diamond`): on `stores 4`, threads 0 and 1 storing `7`
and `8` to bytes 0 to 3 and 4 to 7 of one block, the premises hold and the two orders give the same
grid. The twins: `diamond_twin` (on `stores 0` both store to bytes 0 to 3, two plain writes that
conflict, so `hW` fails, and the two orders give grids that differ at byte 0); `who_twin` (two threads at `alloca` with one thread number
in their contexts: both take block 2, and after either step the other's faults); `owns_twin` (a
thread whose frame lists block 1, of every thread, among its allocas, so the grid is not
`Grid.Owns`: its return makes block 1 dead, after which the other thread's store to block 1 faults,
while in the other order both succeed). `Closed.pending_twin` shows a grid that is not closed in
which one thread's step changes another's pending accesses.

From the start (`Grid.start_reach_comm`, Confluence.lean): the start's contexts give thread `n`
the program and the number `n` (`Grid.start_ctx`, Grid.lean), and every grid reachable from the
start's is closed and owns its allocas (`Grid.start_reach_closed`, `Grid.start_owns`,
`Grid.reach_owns`), so for every program, kernel, launch, arguments and choices on a caller's
memory with `m.BytesIn m.Known`:

    theorem Grid.start_reach_comm {prog : Program} {fn : Func} {L : Launch} {args : List Val}
        {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' gn gk : Grid}
        {c : Nat → Ctx} {n k : Nat} (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
        (hm : m.BytesIn m.Known) (hr : Relation.ReflTransGen (Grid.Step L c) g g')
        (hnk : n ≠ k) (hn : g'.advance c n = .ok (some gn))
        (hk : g'.advance c k = .ok (some gk))
        (hW : ∀ a a', .access a ∈ g'.pending c n → .access a' ∈ g'.pending c k →
          a.conflict a' = false) :
        ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧
          g₁.Same g₂

Its instance (`start_diamond`): the launch on two threads of `alloca i32`, a store of `7` to it and
`ret void`; after both `alloca`s (blocks 2 and 4) the two stores commute. The twin of `n ≠ k`
(`start_twin`): in the launch of MojoProofTest/Launch.lean thread 0's return from `g4` succeeds
and accesses nothing, but after it thread 0 takes no step, so the conclusion fails for
`n = k = 0`. The twin of `hm` is `Closed.start_twin` (a memory that passes the start's check and
gives a grid that is not closed); that of `hW` is `diamond_twin`.

**The case of a thread and a collective call in Lean (done for every grid).**
`Grid.advance_fire_comm` (Confluence.lean), for every launch, contexts and grid, at a barrier or a
shuffle, with no premise of closedness or ownership:

    theorem Grid.advance_fire_comm {L : Launch} {c : Nat → Ctx} {g gk gf : Grid} {n k : Nat}
        (hk : g.advance c k = .ok (some gk)) (hf : g.fire L c n = .ok (some gf))
        (hw : .barrier (c k).who.cta ∉ g.fired L n) :
        ∃ g₁ g₂, gk.fire L c n = .ok (some g₁) ∧ gf.advance c k = .ok (some g₂) ∧
          g₁.Same g₂

`Grid.fired L g n` is `[.barrier (n / size)]` if `n` waits at a barrier and `[]` otherwise, so at
a barrier `hw` says that `k`'s context is not of `n`'s block of threads, and at a shuffle it holds.

The proof: `k` runs (`Grid.advance_set`). So `k` is not a participant: at a barrier a running
thread of `n`'s block makes the barrier give `none`, and at a shuffle a running lane of `n`'s warp
makes `parts.mapM id` `none` (`Grid.fire_frame`, by `mapM_ok_mem` and `mapM_id_mem`). The call
changes no thread but its participants (`resumeAll_getElem?`) and no block. The participants'
results go through `withAttrs` on the memory, which reads it only by `Mem.addr`, and so only at
the shape of a block that exists. A step keeps every block's shape (`Grid.advance_keeps`, W5), so
what the call gives on `g`'s memory it gives on the memory after `k`'s step (`Mem.addr_keeps`,
`withAttrs_keeps`, `resumeAll_set`). No closedness is needed: only success moves from one memory
to the other. So each order gives `g` with `k`'s new status, the participants resumed and `k`'s
memory, with traces `Grid.fired L g n` in front of `k`'s accesses or behind them
(`Grid.advance_retrace`). Every one of those accesses is by `(c k).who` (`Thread.pending_who`), and
every event fired is `.barrier (n / size)` (`Grid.mem_fired`), so by `hw` the two are independent
and the traces are `Trace.Same` (L11).

Its instances (MojoProofTest/Confluence.lean):
- `fire_diamond`: thread 0 at barrier 0 and thread 1 storing, one thread per block of threads, in
  contexts that put thread `n` in block of threads `n`.
- `shfl_diamond`: thread 0 at a butterfly shuffle, which with one thread per block of threads is a
  warp of one lane. `shfl_value` checks that it gives thread 0 its own value `5` under the
  callee's `range(i32 0, 8)`.

The twin of `hw` (`fire_twin`): `fire_diamond`'s grid in contexts that put both threads in block
of threads 0. After a write by thread 0 of the bytes thread 1 stores to, one order's trace is racy
and the other's not, so the grids are not the same.

**The case of a thread and a collective call from the start (done).** `Grid.start_reach_fire_comm`
(Confluence.lean), for every program, kernel, launch, arguments, caller's memory, address choice
and oracle, in every grid reachable from the start's, at a barrier or a shuffle, with no premise on
blocks of threads:

    theorem Grid.start_reach_fire_comm {prog : Program} {fn : Func} {L : Launch} {args : List Val}
        {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ g gk gf : Grid} {c : Nat → Ctx}
        {n k : Nat}
        (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c))
        (hr : Relation.ReflTransGen (Grid.Step L c) g₀ g)
        (hk : g.advance c k = .ok (some gk)) (hf : g.fire L c n = .ok (some gf)) :
        ∃ g₁ g₂, gk.fire L c n = .ok (some g₁) ∧ gf.advance c k = .ok (some g₂) ∧
          g₁.Same g₂

The proof: `hw` of `Grid.advance_fire_comm`. If the call fires a `.barrier`, it is `n`'s
(`Grid.mem_fired`), and `k` is not among `n`'s block's threads `n / size * size + j`, `j < size`
(`Grid.fire_frame`). The start's contexts give `k` the block of threads `k / size`
(`Grid.start_ctx`). If `k / size = n / size`, then `k = n / size * size + k % size` would be one of
them, with `k % size < size` when `size > 0`. And `size > 0`, as `k` is a thread
(`Grid.start_reach_block`). That holds because the start has a thread only if `size > 0`
(`Grid.start_run`), a step sets one thread, and a fire resumes threads at numbers that had one
(`Grid.fire_threads`).

Its instance (`start_fire_diamond`): the kernel of MojoProofTest/Launch.lean (an `alloca`, a
store, barrier 0, `ret void`) on two blocks of one thread, with thread 0 at the barrier and thread
1's store next. The twin of the start's contexts (`start_fire_twin`): `fire_twin`'s contexts are no
start's, since the start of its launch puts thread 1 in block of threads 1.

**The case of two collective calls in Lean (done).** `Grid.fire_fire_comm` (Confluence.lean), for
every launch, contexts and grid, at barriers and shuffles alike, if the two threads' contexts have
one layout:

    theorem Grid.fire_fire_comm {L : Launch} {c : Nat → Ctx} {g gn gj : Grid} {n j : Nat}
        (hl : (c n).prog.layout = (c j).prog.layout)
        (hn : g.fire L c n = .ok (some gn)) (hj : g.fire L c j = .ok (some gj)) :
        gn = gj ∨
          ∃ g₁ g₂, gn.fire L c j = .ok (some g₁) ∧ gj.fire L c n = .ok (some g₂) ∧ g₁.Same g₂

The first alternative is the diamond's degenerate case: the two fires are one step of `Grid.Step`.
`Grid.start_fire_fire_comm` gives the same for every grid in the start's contexts, for every
program, kernel, launch, arguments, caller's memory and choices, since the start gives every
thread the one program (`Grid.start_ctx`).

The proof rests on `Grid.fire_frame`: a call that completes for `n` has a list `P` of participants,
each waiting (at a barrier, `n`'s block of threads `n / size * size + j`, `j < size`), with
results `v`, such that
- the new threads are `resumeAll l g.mem g.threads P v`, with `l` the layout of `n`'s context;
- the new memory is the old with `Grid.fired L g n` in front of its trace;
- every participant's fire, in all contexts that give it `n`'s layout, gives the same grid;
- from every grid with `g`'s statuses at `n` and at the participants, the call gives the same
  `resumeAll` on that grid's threads and memory, and the same log.

Then:
- If the participant lists meet, or `j` is among `n`'s participants, or `n` among `j`'s, then one
  thread is a participant of both calls, and its fire gives `gn` and `gj` alike, so `gn = gj`
  (this needs `hl`).
- Otherwise each call keeps the other's participants (`resumeAll_getElem?`), so it still completes
  after the other with the same results. The blocks do not change, and in the memory each call
  leaves `withAttrs` gives what it gave (`resumeAll_agree`, by `Mem.Keeps`). The threads agree at
  every number (`Array.ext_getElem?`), and the traces differ by the order of the two logs. Both
  logs are `.barrier`s (`Grid.mem_fired`), which are independent, so the traces are `Trace.Same`
  (`Trace.Same.swap`).

A launch whose block of threads has no threads (`size = 0`) has no participant at a barrier, so
`n ∉ P`. The case split covers it by `j ∈ P ∨ n ∈ Q`.

Its instances (MojoProofTest/Confluence.lean):
- `bars_diamond`: two threads at barrier 0, one thread per block of threads, where the fires give
  grids that differ and commute;
- `bars_same` and `shfls_same`: both threads in one block of threads, or one warp, where either
  fire gives one grid;
- `start_bars`: the start of `startB` after thread 1 reaches the barrier too
  (`Grid.start_fire_fire_comm`).

The twin of `hl` (`layout_twin`): two lanes at a shuffle of a `nonnull` pointer at address
`2 ^ 32`, thread 0 with 64-bit pointers and thread 1 with 32-bit ones. Thread 0's fire keeps the
pointer, thread 1's makes it poison, and after either fire no thread waits, so neither
alternative holds.

**The premise on accesses from ownership in Lean (done for every grid).** `Grid.pending_apart`
(Confluence.lean) is the disjointness argument above, for the two threads' pending accesses: for
every discipline `(T, own)`, contexts and grid, `hH` at the two threads and `hX` at their contexts'
threads give `hW`.

    theorem Grid.pending_apart {ι : Type} {T : Nat → Option (Tiling ι)} {own : Nat → ι}
        {c : Nat → Ctx} {g gn gk : Grid} {n k : Nat}
        (hn : g.advance c n = .ok (some gn)) (hk : g.advance c k = .ok (some gk))
        (hX : own (c n).who.thread ≠ own (c k).who.thread)
        (hH : ∀ p ∈ [n, k], ∀ a, .access a ∈ g.pending c p →
          Owned T own a ∨ g.mem.Owned (c p).who.thread a.ptr.block) :
        ∀ a a', .access a ∈ g.pending c n → .access a' ∈ g.pending c k →
          a.overlaps a' = true → a.write = false ∧ a'.write = false

The proof, for overlapping `a` of `n` and `a'` of `k` (so of one block):
- Both follow the discipline: they are by `(c n).who` and `(c k).who` (`Grid.pending_who`), whose
  tiles differ, so they are reads (`Owned.apart`, Trace.lean). At an untiled block both are reads
  (`Owned.read`). At a tiled one they lie in different tiles, which are disjoint (`Tiling.disj`), so
  they do not overlap. `Owned.apart` replaces `Owned.conflict` and gives `racy_eq_false_of_phased`
  too.
- One is to a block that its thread owns, `.thread` of that thread: the other thread's step
  succeeds, so its access is to a block whose owner admits it (`Grid.advance_admits`, from
  `Mem.check_block`, which also gives the admission), so the two threads' numbers are equal and
  their tiles too, against `hX`.

From the start (`Grid.start_reach_comm_of_owned`): `Grid.start_reach_comm` with `hW` from
`Grid.pending_apart` through `Access.conflict_eq_false` (accesses that overlap only if neither
writes do not conflict), `hX` as `own n ≠ own k` (the start gives thread `n` the number `n`,
`Grid.start_ctx`), and the premise `n ≠ k` from it.

    theorem Grid.start_reach_comm_of_owned {ι : Type} {T : Nat → Option (Tiling ι)}
        {own : Nat → ι} {prog : Program} {fn : Func} {L : Launch} {args : List Val}
        {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' gn gk : Grid}
        {c : Nat → Ctx} {n k : Nat} (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
        (hm : m.BytesIn m.Known) (hr : Relation.ReflTransGen (Grid.Step L c) g g')
        (hX : own n ≠ own k)
        (hn : g'.advance c n = .ok (some gn)) (hk : g'.advance c k = .ok (some gk))
        (hH : ∀ p ∈ [n, k], ∀ a, .access a ∈ g'.pending c p →
          Owned T own a ∨ g'.mem.Owned p a.ptr.block) :
        ∃ g₁ g₂, gn.advance c k = .ok (some g₁) ∧ gk.advance c n = .ok (some g₂) ∧
          g₁.Same g₂

`hH` here is at the two threads of one grid. `hH` above, at every running thread of every reachable
grid, gives it. `hI` is not needed: invariant loads are reads.

Its instances (MojoProofTest/Confluence.lean):
- `stores_apart`: `hW` on `stores 4` from the discipline `(tiles, tileOf)` that cuts block 1 into
  two tiles of 4 bytes (`Tiling.strided 0 2 4`), tile 0 for thread 0;
- an `example` with `start_diamond`'s statement: its stores are to the threads' own `alloca`s,
  which they own.

The twins (`apart_twins`), on `stores 0`, where `hW` and the conclusion fail (`diamond_twin`):
- of `hX`: with every thread in tile 0 both stores follow the discipline;
- of `hH`: with `tileOf` thread 1's store is neither in its tile nor to a block it owns.

Two `atomicrmw`s of one operation on the same bytes (L10, done): `Access.conflict` exempts them,
so `Grid.advance_comm` covers them, but they follow no discipline with different tiles, so
`Grid.start_reach_comm_of_owned` does not. The steps, in Lean: `Mem.load_store` (Confluence.lean), for every layout, memory, two threads, type,
value, pointer and two alignments, gives that a load after a store that succeeds, at the same
pointer, by a thread and with an alignment whose check succeeds before the store, gives what the
stored bytes decode to, and `Mem.load_store_codec` that for a codec (integers, floats) this is the
stored value. So in the diamond the second thread's load, which succeeds from `g`, reads what the
first stored. Instances `store_load`, `store_load_other`; twins `store_load_i0` (a poison `i0`
loads back as `bits 0 0`) and `load_other` (of the check). `rmw_comm_of_ok` (Rmw.lean) gives the final value from a
scalar for all operands, if both updates succeed from it, since an operand need not be a scalar.
`Mem.load_scalar` gives that the loaded value of an integer type is `Val.Scalar` (instance
`load_scalar`; twin `load_ptr`), and `Layout.scalar_round` that a scalar of a positive width
round-trips through its bytes (instance `undef_round`; twins `poison_i0`, `ptr_i32`). From these,
`Mem.update_comm`: for every two layouts, memory, threads, spaces, operands and alignments, every
operation and every positive width `n`, two updates (`Mem.update`, what `exec` does at an
`atomicrmw`) of type `.int n` at one pointer that each succeed from `m` succeed in both orders and
give the same blocks, `next` and trace up to swaps (instance `update_comm`, two `add`s). Then
`exec_atomic`, `step_atomic` and `Grid.advance_atomic`: a step that succeeds and would log an atomic
access `e` is, from every memory with the same shape, the update at `e`'s pointer of type
`.int (8 * e.len)` (`Stmt.checkAtomic_int`) by an operand that is a scalar of that width (`exec`
checks it); and `Grid.advance_atomic_comm`, for every closed grid
and contexts: two threads `n ≠ k` whose steps succeed, with pending accesses by `atomicrmw`s of one
operation at one pointer and size, give the same grid in both orders (`Grid.Same`) (instance
`atomic_comm`, two `atomicrmw add`s at one word; with `Grid.advance_comm`, `atomic_diamond`).

**`bad_step` (P, faults persist).** Let `g` fault at `n` and let `g → g'`.

- *`n`'s advance faults.* Then `n` runs and the step is by another thread or a fire.
  - Another thread `m`: by disjointness, `m`'s step changes none of `n`'s footprint. `n`'s pending reads are
    owned or thread-local by `hH`, and `m`'s writes miss them. Liveness, and the bytes `lifetime.start`
    resets, change only for `m`'s own blocks, and an access by `n` to one of them faults in every state
    (`Mem.check`). The new block, if any, is one `n`
    does not name (C2); a pointer of `n` to no block keeps pointing to no block (C1), and an `alloca` of `n`
    whose number is in use keeps it in use (no block is removed). So `n`'s step from `g'` faults too (L2).
  - A fire: `n` is not a participant, and the fire changes no block.
- *`n`'s fire faults.* Then `n` waits, and no step but a fire of `n`'s group moves `n`. That fire is
  `n`'s fire up to the participant it is checked against, and it faults too. `Grid.fire` faults for one of
  four reasons.
  - Its own operands: the barrier number is not defined or is outside 0–15, or the member mask is not
    defined or is partial. These do not change while `n` waits.
  - A returned participant. `.done` is final.
  - A participant `p` that waits at an incompatible call. `p` moves only by a fire that includes it.
    - A barrier fire of `p`'s block includes `n`. It faults if `n` waits at another barrier, and it is not
      enabled if `n` waits at a shuffle (`pure false`).
    - A shuffle fire of `p`'s warp includes `n` and faults against it.
    So `p` keeps its state.
  - A lane at the same shuffle whose lane or clamp operand is undefined, or a fault of `withAttrs` in
    `resumeAll`. The first is that lane's own operands, which do not change while it waits. The second
    reads only block addresses (`Mem.addr`), which never change (W5). A barrier resumes with no value
    and never calls `withAttrs`.

  `Grid.fire` checks the participants in order, and an earlier participant can change from running to
  waiting in `g'`. Then the fire faults at that participant, or it reaches the same fault as in `g`.
  Either way `g'` faults.

**Conclusion 2.** By induction on reachability:
- every access in a reachable trace was logged by a successful step from a reachable grid, so it is a
  pending access there (L1a), and owned or thread-local (`hH`);
- the thread-local ones are by the owner of their block (`Mem.check`).

Two accesses of different threads to one block are therefore both owned. They lie in different tiles
(`hX`), so they do not race; this is `racy_eq_false_of_owned` with thread-local accesses added, a small
generalization. An invariant load is on an untiled block (`hI`), which no access writes (`Owned.read`), so
`kept` holds (`kept_of_split`).

In detail, the invariant, for every grid `g` reachable from `g₀`:
- every thread number `j` of `g` is below `N`;
- for every access `a` in `g.mem.trace`: `a.who.thread < N`, and block `a.ptr.block` of `g.mem` is some
  `x` whose owner admits `a.who` (`Owner.admits`), with `Owned T own a` or `x.owner = .thread a.who.thread`,
  and, if `a.invariant = true`, `T a.ptr.block = none` and `x.owner` is no `.thread w`.

At the start the trace is empty. A step of thread `n` (`Grid.advance_set`) keeps the size of the
threads and logs `Grid.pending c g n` in front of the trace. Each of these accesses is by `(c n).who`
(`Grid.pending_who`), whose thread is `n` (`Grid.start_ctx`), below `N` since `n` is a thread of `g`; it
is to a block whose owner admits `n` (`Grid.advance_admits`); `hH` gives the third part, and `hI` the
fourth, since an owner `.thread w` that admits `n` is `.thread n`. The step keeps every block's owner
(`Grid.start_reach_changes`, `Mem.Changes.old`), so the accesses already in the trace keep theirs. A
fire logs no access (`Grid.fire_trace`), changes no block (`Grid.fire_blocks`) and adds no thread
(`Grid.fire_threads`).

From the invariant: a clash of the trace (`racy_iff`) is of two accesses of different threads to one
block. If the block's owner is a `.thread w`, both threads are `w` (the owner admits them); otherwise
both accesses are owned, and `Owned.apart` with `hX` makes both reads, which do not conflict
(`racy_eq_false_of_local`, with "local to `w`" being `g.mem.Owned w`). For `kept`, `kept_of_split` with
`W b := T b ≠ none ∨ ∃ w, g.mem.Owned w b`: a write is owned, so to a tiled block (`Owned.read`), or
thread-local; an invariant load is to an untiled block with no thread owner.

The enabled race: if `g` has a running thread `n` with `racy (Thread.pending (c n) t g.mem ++
g.mem.trace) = true` and `n`'s step succeeds, the grid after is reachable and its trace is that list
(`Grid.advance_set`), which is not racy by the above; a running thread's step is never `none`
(`Grid.advance_run`), so it faults.

## Conclusion 3 in Lean

**Statement** (`Grid.owned_sound`, MojoProof/Sem/ScheduleOwned.lean). For every program, kernel,
launch, arguments, address choice, oracle and discipline `(T, own)`, given `hs`, T2's `hm`, an
observation `obs` with `obs m = obs m'` whenever `m.blocks = m'.blocks`, a run
`Path (Grid.Step L c) n g₀ z` with `z.Done`, a predicate `loc b w` ("block `b` is local to thread
`w`"), and `obs z.mem = some y` with `R y`, if the trace `tr := z.mem.trace` meets

- `hO`: every access of `tr` to a block local to no thread follows the discipline (`Owned T own a`);
- `hL`: every access of `tr` to a block local to `w` is by `w`;
- `hX`: two accesses of `tr` to one tiled block (`T b ≠ none`) by threads with one tile
  (`own`) are by one thread;
- `hI`: no access of `tr` with `!invariant.load` is to the block of a write of `tr`,

then `Grid.Sound L c g₀ obs R`.

**Proof.**

1. A done grid is bad only by its trace (`Grid.Done.bad_iff`, every launch, contexts and grid).
   `Grid.Bad` is `Faults ∨ racy ∨ ¬ kept ∨ RaceEnabled`. A fault is a thread's step or fire that
   errs, and in a done grid every thread is `.done` or absent, so `Grid.advance` and `Grid.fire`
   return `.ok none` (`done_not_faults`). An enabled race needs a thread `.run t`, which a done grid
   has not (`Grid.Done.not_raceEnabled`).
2. The trace lemma (`racy_kept_of_local`, every trace). `racy tr = false` is
   `racy_eq_false_of_local` from `hO`, `hL` and `hX`. For `kept`, let `W b` say that some write of
   `tr` is to block `b`. Every write is to a block of `W` by definition, and every access with
   `!invariant.load` is to a block not in `W` by `hI`; that is `kept_of_split`.
3. So `z` is not bad: by 1, a bad `z` has `racy tr = true` or `kept tr = false`, and 2 refutes
   both. `Grid.start_sound` (T2's conclusion 2) then gives `Grid.Sound` from the run, `hs`, `hm` and
   the observation's premises.

**Relation to the statement above.** The hypotheses `hH`, `hI` and `hX` of T2′ give the trace
premises at every reachable grid with `loc b w := g.mem.Owned w b` (the argument of
`Grid.owned_clean`: an owned block's owner admits only its thread, and a write that follows the
discipline is to a tiled block, which an access with `!invariant.load` is not to). The Lean form
asks them of one trace only, which a checker evaluates on one run.

**Instance and twin** (MojoProofTest/ScheduleOwned.lean, one kernel each). `cells_sound`: the run
of `cellK i16` in which thread 0 takes its four steps and then thread 1, with `T := cells`,
`own := tileOf` and no local block; the trace premises are a Boolean check on the done grid's trace
(`traceB`, sound for every discipline and trace by `traceB_sound`), and the observation is bytes 0
to 3 of block 1, 7 and 7 as 16-bit words. `cells_sound_twin`: in `cellK i8` the same schedule
reaches a done grid with a racy trace, so it is bad, no `(T, own, loc)` meets the trace premises
(they would make it not racy), and the start's grid is sound for no observation.

## The trace lemma of an elementwise kernel

**Statement** (`racy_kept_of_cells`, MojoProof/Sem/Trace.lean, every trace `tr`, output
block `out`, width `w` and cell map `cell : Nat → Nat` with `Apart cell w`, that is, for threads
`i ≠ j`, `cell i + w ≤ cell j` or `cell j + w ≤ cell i`). If

- `hc`: every access `a` of `tr` to `out` lies in its thread's cell:
  `cell a.who.thread ≤ a.ptr.off` and `a.ptr.off + a.len ≤ cell a.who.thread + w`;
- `hr`: every access of `tr` to another block is a read;
- `hi`: no access of `tr` with `!invariant.load` is to `out`,

then `racy tr = false` and `kept tr = true`. This is the premise `racy m'.trace = false ∧
kept m'.trace = true` of a sequential run's soundness, for a kernel in which each thread writes
only its own cells of one output block and reads blocks that nobody writes. It covers cells at
any offsets `w` bytes apart (a row-major tensor from any base offset) and accesses inside a cell
(a narrower load or store of it). `racy_kept_pointwise` (same file: cells `k * w`, each access the
whole cell, threads below a bound) is its corollary, with `Apart` from `apart_stride`.

**Proof.**

1. `kept`. Let `W b` say `b = out`. Every write is to `out`: a write to another block contradicts
   `hr`. Every access with `!invariant.load` is to a block other than `out` by `hi`. That is
   `kept_of_split`.
2. `racy`. Suppose `racy tr = true`. By `racy_iff` there are two accesses `x`, `y` of the phases of
   `tr`, so of `tr` (`mem_phases`), that clash, which needs (among its conditions) different
   threads `i ≠ j`, one block, overlapping bytes (`x.off < y.off + y.len` and
   `y.off < x.off + x.len`), and at least one write.
   - If the block is `out`, by `hc` `x`'s bytes are inside `[cell i, cell i + w)` and `y`'s inside
     `[cell j, cell j + w)`. By `Apart` these two intervals are disjoint, so `x` and `y` do not
     overlap: a contradiction (linear arithmetic).
   - Otherwise both accesses are reads by `hr`, and a clash needs a write: a contradiction.

**Instance and twins** (MojoProofTest/ScheduleOwned.lean, statements about one trace). `elemTr o`:
two threads, each an `!invariant.load` of its 4 bytes of block 2 and a store of 4 bytes at offset
`o n` of block 1. `elem_clean`: with `o n = 4 n + 8` and cells `4 n + 8` of width 4 (apart by
linear arithmetic, an offset `racy_kept_pointwise` does not cover), the premises hold for each of
the four accesses by evaluation, so the trace is not racy and keeps the promise. `elem_owned`:
the same trace follows the tiling `elemCells` (block 1 in two cells of 4 bytes from 8), so
`racy_eq_false_of_owned` also gives that it is not racy.
`elem_twin_cell` (the cell premise): with both stores at offset 8 the trace is racy.
`elem_twin_inv` (the `!invariant.load` premise): after a further `!invariant.load` of bytes 8 to
11 of block 1, which thread 0 stores, `kept` is false.

## Route in Lean

T2 (`Grid.confluent`) gives `Confluent rc Same Grid.Bad` on `γ` from the start alone. A general
lemma, `Confluent.of_iff`, replaces the bad set of a confluent system by one with the same members:
`refl`, `symm`, `trans` and `bisim` do not mention it, and `bad_eqv`, `bad_step` and `diamond` go
through the equivalence. Conclusion 2 makes `Grid.Bad` and `Grid.Faults` agree on `γ`
(`Grid.owned_bad`), so conclusion 1 is `Grid.confluent` with `Confluent.of_iff`
(`Grid.confluent_owned`). This route needs `hm : m.BytesIn m.Known` (T2's hypothesis) and none of
the lemmas of the sections above that T2 does not already use.

## Dependencies

- `Confluent`, `Confluent.one_run` (MojoProof/Sem/OneRun.lean);
- `Grid.start`, `Mem.checkClosed`, `Mem.allocNext`, `Grid.start_blocks`, `Val.bounds`, `Grid.Step`,
  `Grid.advance`, `Grid.fire`, `step`, `Mem.check`, `Mem.fresh` (MojoProof/Sem/Grid.lean, Thread.lean,
  Value.lean); `Mem.Known` (MojoProof/Sem/Names.lean); `Grid.Closed`, `Thread.AtCall`,
  `Grid.AtCalls` (MojoProof/Sem/Closed.lean);
  `Access.Writes`, `Mem.Changes`, `Mem.Owned`, `Status.AllocasIn`, `Grid.Owns`
  (MojoProof/Sem/Writes.lean);
- `Nat.pair` and its injectivity (Mathlib);
- `Tiling`, `Owned`, `racy_eq_false_of_owned`, `kept_of_split`, `Grid.sound_of_one_run`,
  `done_not_faults` (MojoProof/Sem/Trace.lean); `Grid.start_sound`, `Grid.Done.bad_iff`
  (MojoProof/Sem/Determinism.lean);
- `Grid.Faults`, `Grid.Done`, `racy`, `kept` (MojoProof/Sem/Spec.lean);
- `List.Perm`, `Relation.ReflTransGen` (Lean core, Mathlib).

## Instances and twins

Given (MojoProofTest/ScheduleOwned.lean, one kernel each, by evaluation of every reachable grid with
the checker `every`, whose soundness `every_sound` holds for every launch):

- the checker `discB c T own`, which gives `hH` and `hI` for the discipline `(T, own)` on every grid
  that meets it (`discB_sound`, `disc_hyps`, for every launch, contexts and discipline);
- the instance `confluent_owned2` and `clean2`: `start2` of MojoProofTest/Confluence.lean, two threads
  each at `%0 = alloca i32`, `store i32 7, ptr %0`, `ret void`. Every access of every reachable grid is
  to a block its thread owns (`local2`, `discB` with `T = none` and `own = id`), so the steps are
  confluent with the faults as the bad set, and on every reachable grid the trace is not racy, keeps
  its promises, and the grid is bad exactly when it faults;
- the tiled instance `confluent_cells`: `cellK i16`, two threads each at
  `%1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`,
  `%2 = getelementptr inbounds i16, ptr addrspace(1) %0, i32 %1`,
  `store i16 7, ptr addrspace(1) %2, align 1`, `ret void`, launched by `Grid.start` with a pointer to the
  caller's buffer, block 1 of 4 bytes. With `T` tiling block 1 into two cells of 2 bytes
  (`Tiling.strided 0 2 2`) and `own = tileOf`, every reachable grid meets `discB`, each store being in
  its thread's cell, and does not fault (`cells16`), so `hH`, `hI` and `hX` hold, the steps are
  confluent with the faults as the bad set, and every reachable grid's trace is not racy and keeps its
  promises. Its twin `cells_twin`: in `cellK i8` the cells are one byte apart and the two stores of two
  bytes overlap, the grid after both stores is reachable with a racy trace, so no discipline whose tile
  map is injective on the two threads meets `hH` and `hI`;
- the twin `inv_twin` (counterexample (ii): a broken `!invariant.load` promise): one thread at `%0 = alloca i32`,
  `%1 = load i32, ptr %0, !invariant.load`, `store i32 7, ptr %0`, `ret void`. No reachable grid faults
  or has a racy trace, but the done grid breaks the promise of the load, so it is bad and does not
  fault, and no discipline meets `hH` and `hI` on its launch. The load's step is evaluated after
  unfolding `Layout.decode` once (`stepsI`), and the checker runs from the grid after the load (`reachI`, `safeL`);
- the instance `cells_sound` of conclusion 3 (`Grid.owned_sound`) and its twin `cells_sound_twin`,
  section "Conclusion 3 in Lean".

Not given here:

- `vector_addition` on a 2 × 2 launch.
  - The tiling is `Tiling.strided` on the output buffer, and `T = none` on the inputs (read only,
    `!invariant.load`). `own` is the global thread index, injective on the threads of a
    one-dimensional launch (`Launch.index_oneDim`, index.md).
  - `hH` is checked on the reachable grids by the summary of one thread, which is T3 and T4's job, so this
    instance is not given. `racy_kept_pointwise` covers the trace half for this kernel.
- Negative twins, which are not instances:
  - `reduction`: all block leaders write one word, so `hX` fails, and the commutation goes by L10;
  - `tiled_matmul`: a shared tile is written by different threads in different barrier intervals, so
    `Owned` fails for any one `T`, and the proof goes by race freedom per barrier interval
    (barrier-owned.md).
