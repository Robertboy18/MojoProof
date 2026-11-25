# Asynchronous copies and their groups (`AsyncCopy`, `AsyncOp`, `Async`, `Async.Step`, `Async.Run`, `Async.lazyRun`, `Async.Run.lazy`, `Async.Run.within`, `Async.lazyRun_init`, `Async.wait_run`, `Async.visible`, `Async.determined`, `Async.visible_bytes`)

Lean: MojoProof/Sem/Async.lean; instances and twins in MojoProofTest/Async.lean. The statements
are about one thread's sequence of operations from the empty state, for every such sequence and
for every completion choice (every order and time at which the copies land); that a grid run
reaching `cp.async` computes them is not proved, since the grid does not run the copies (see
"Not proved").

## The model

The source is the PTX ISA, version 9.5: section 9.7.10.28.3.1 (`cp.async`), 9.7.10.28.3.2
(`cp.async.commit_group`) and 9.7.10.28.3.3 (`cp.async.wait_group`). The repository holds no
copy of the ISA, so the citation is by section.

A copy `AsyncCopy.mk dst src size srcSize` writes `size` bytes at the shared address `dst`, the
first `srcSize` of them from the global address `src` and the rest zeros (the ISA's `src-size`
operand; without it `srcSize = size`). `AsyncCopy.Writes c x` says that `c` writes the shared
byte `x`, and `AsyncCopy.land gm sm c` is the shared memory `sm` after `c` lands, reading the
global memory `gm`.

A thread's state `Async` has three lists: the copies issued since the last commit and not
landed (`pending`), the committed groups not yet waited for, oldest first, each with its copies
not landed (`groups`), and the copies that have landed, in landing order (`landed`).
`Async.unlanded` is the copies not landed. `Async.Step s o t` is one step, the trusted reading
of the three sections:

- `copy c`: `c` joins the uncommitted copies;
- `commit`: the uncommitted copies become the newest group, an empty group when there are none
  (the ISA: a commit with no copy since the last one makes an empty group);
- `wait n`: enabled once every group other than the `n` most recent is empty, that is, all its
  copies have landed; those groups are dropped;
- a landing (`o = none`): any copy not landed, committed or not, lands whole.

`Async.Run s ops t` says that `t` is reachable from `s` by the operations `ops`, in order, with
any landings before, between and after them. The ISA leaves the completion of a copy free until
a wait requires it; the runs are every such choice. `Async.lazyRun s ops` is one of them, the
lazy choice: a copy lands only when a wait needs it, oldest group first, in issue order.
`Async.smem gm sm s` is the shared memory after the landed copies of `s`, in landing order.
`Async.committed ops` is the copies of `ops` issued before its last commit, in order, and
`Async.uncommitted ops` those issued after it.

## Statements

1. `Async.Run.lazy`, from every state and for every `ops`: the lazy run is a run, so no
   statement below about every run is vacuous.
2. `Async.Run.within`, for every run of `ops` from `s` to `t`: the uncommitted copies of `t` are
   a sublist of the lazy run's, each pending group of `t` a sublist of the lazy run's group at
   its place, and the landed copies followed by those not landed are a permutation of the lazy
   run's.
3. `Async.lazyRun_init`, for every `ops` from `Async.init`: under the lazy choice the landed
   copies followed by the pending groups' copies are `committed ops`, in order, and the
   uncommitted copies are `uncommitted ops`.
4. `Async.wait_run`, for every `ops`, `n` and run of `ops` and `wait n` from `Async.init`: at
   most `n` groups are pending, and every copy the lazy run has landed (the committed copies
   but those of the at most `n` newest groups) has landed, whatever else landed.
5. `Async.visible`, for every `ops` and run of `ops` and `wait 0`: no group is pending, every
   copy of `committed ops` has landed, and the copies not landed are among `uncommitted ops`,
   in order.
6. `Async.determined`, the protocol theorem, for every `ops`, `gm`, `sm` and shared byte `x`:
   if every copy of `ops` that writes `x` is issued when no copy the lazy run has not landed
   writes `x` (a byte is written again only after a wait for its previous writer), and no copy
   the lazy run of `ops` has not landed writes `x`, then every run of `ops` holds at `x` the
   lazy run's byte. A byte that no possibly pending copy writes has the same value under every
   completion choice.
7. `Async.visible_bytes`, for every `ops`, `gm` and `sm`: if the destinations of all the copies
   `ops` issues are pairwise disjoint (`AsyncCopy.Disjoint`), then for every committed copy `c`,
   offset `o < c.size` and run of `ops` and `wait 0`, the shared memory holds at `c.dst + o` the
   global byte `gm (c.src + o)` when `o < c.srcSize`, and `0` otherwise. It is `determined` at
   these bytes. The premise covers the uncommitted copies too: one that overlaps a committed
   copy may land before or after it.

The tests run one sequence of two committed copies and one uncommitted copy `c2` through
`wait 1` and `wait 0`, and give the boundary twins at `c2`'s first byte: after `wait 0`, which
waits only for the earlier groups, the byte is the initial one in one run and `c2`'s in
another, both runs exhibited; once `c2`'s own group is committed and waited for, it is `c2`'s in
every run. `reused` writes a buffer, waits, and writes it again: the byte is the second copy's in
every run. The twin `overlap` has two copies to the same bytes in one group, and after `wait 0`
the byte is either copy's, as they land in either order; so neither the disjointness premise of
`visible_bytes` nor the reuse premise of `determined` can be dropped.

## A GPU run

tests/gpu/cp-async/record.txt is a conformance test, not a proof: on an NVIDIA A100 (sm_80), 6
launches of one warp, each lane issuing 4 copies of 16 bytes (`cp.async.cg.shared.global`, three
with the `src-size` operand, random from 0 to 16, and one without) into its own 64 shared bytes
from random global bytes, committed as the groups `{0, 1}`, `{2}` and `{3}`, then
`wait_group 1` and `wait_group 0`. MojoProofTest/AsyncGpu.lean (run by
tests/gpu/cp-async/Compare.lean) evaluates `Async.smem` after `Async.lazyRun` of each lane's
operations on the dumped global and initial shared bytes and compares every word the lane read
back: after `wait_group 1` the 2,304 words of the two older groups, after `wait_group 0` all
3,072 words; all agree. `wait0_bytes` there is `visible_bytes` for these operations, so every
run of the model gives the words compared after `wait_group 0`, and `wait1_bytes` is
`determined` for them, so every run gives the words compared after `wait_group 1`. Its twin
`wait1_pending`: the bytes of copy 3, which may still be pending after `wait_group 1`, differ
between runs. The run reads no byte a pending copy may write, so it does not test when or in
which order copies land, which the model leaves free.

## Race freedom is the caller's premise

The model reads the global memory `gm` when a copy lands and lets no other access touch shared
memory. That no other thread or instruction writes a pending copy's destination or its source,
and that nothing reads the destination before the wait, is the caller's premise: it is not
modelled here, and `determined` and `visible_bytes` state the bytes only under it. The parts of
it about the thread's own copies, which may land in any order, are their hypotheses.

## Plan: the copies in the grid

Not code yet; the order of the work, each step building on the last.

1. **The state.** Each thread carries its copies: a field `async : Async` of `Thread`, starting
   at `Async.init`. `Thread` is a structure that the grid's statements are about, so every
   constructor of a thread changes (`Grid.start`, the call and return steps of `exec`, and the
   others that build one from `frames` and `k`), and so does every proof that rebuilds one; the
   statements do not, since no step but those below reads or writes the field. A map from
   thread to state in `Grid` instead would need every step of one thread to touch two places,
   and the projection in step 4 to read both.
2. **The operations.** `exec` runs the importer's `AsmCall` of `cp.async.cg.shared.global` as
   `Async.Step`'s `copy` (the shared address, the global address, the size and the source
   size from the call's operands, the last one the size without `src-size`), `cp.async.commit.group`
   as `commit`, and `cp.async.wait.group n` as a wait that the thread repeats while
   `Async.Step`'s `wait n` is not enabled. The fault at inline asm and the two no-ops go.
3. **The landings.** A new step of the grid lands one copy not landed of one thread: the shared
   bytes it writes become those `AsyncCopy.land` gives from the global memory at that step.
   The access log records them as writes of shared memory and reads of global memory by the
   issuing thread, so the race-freedom premise of the kernel theorems covers a copy as it
   covers a store: a copy's source must not change while it may be pending. The landings
   commute with the other threads' steps on disjoint bytes, which the confluence and frame
   statements need as a new case.
4. **The projection.** For every grid run, the operations a thread performs and the landings
   of its copies, in order, are an `Async.Run` of that thread from `Async.init`; its shared
   memory at the bytes only its copies write is `Async.smem` of the final state.
5. **The statement.** With the projection, `Async.visible_bytes` and `Async.determined` hold of
   a grid run: after a thread's `cp.async.wait.group 0`, under disjoint destinations, every
   byte of a committed copy holds the global byte or zero in every run, the grid's choices
   of landing included. Tests: one program of each of the importer's two forms, and the twin of
   `overlap` in the grid.

## Not proved

- The grid's semantics of the copies. The importer accepts the two inline-asm forms of
  `cp.async.cg.shared.global` that the corpus uses, with and without the `src-size` operand
  (`AsmCall`, MojoProof/LLVM/Asm.lean), but `exec` runs no inline asm: a thread that reaches
  one stops with a fault (the last case of `exec`, MojoProof/Sem/Thread.lean). The grid runs
  `commit_group` and `wait_group` as no-ops, which is sound only because that fault stops every
  run that issues a copy. Wiring `Async.Step` to the grid (a per-thread `Async` state, its
  landings among the grid's steps) is a dispatch to these definitions, planned above, not
  proved here.
- The `.ca` and `.cg` cache hints, `cp.async.bulk`, `cp.async.mbarrier.arrive` and the
  `ignore-src` predicate; and an ordering between copies of different threads.
- That a copy lands whole: the model lands each copy in one step, while the ISA does not say how
  the bytes of one copy become visible. That matters only for a byte that two possibly pending
  copies write, which the premises of `determined` and `visible_bytes` exclude.
