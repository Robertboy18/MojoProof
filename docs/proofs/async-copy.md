# Asynchronous copies and their groups (`AsyncCopy`, `AsyncOp`, `Async`, `Async.step`, `Async.committed`, `Async.wait_length`, `Async.run_init`, `Async.wait_run`, `Async.visible`, `Async.visible_bytes`)

Lean: MojoProof/Sem/Async.lean; instances and twins in MojoProofTest/Async.lean. The statements
are about one thread's sequence of operations from the empty state, for every such sequence;
that a grid run reaching `cp.async` computes them is not proved, since the grid does not run the
copies (see "Not proved").

## The model

The source is the PTX ISA, version 9.5: section 9.7.10.28.3.1 (`cp.async`), 9.7.10.28.3.2
(`cp.async.commit_group`) and 9.7.10.28.3.3 (`cp.async.wait_group`). The repository holds no
copy of the ISA, so the citation is by section.

A copy `AsyncCopy.mk dst src size srcSize` writes `size` bytes at the shared address `dst`, the
first `srcSize` of them from the global address `src` and the rest zeros (the ISA's `src-size`
operand; without it `srcSize = size`). `AsyncCopy.land gm sm c` is the shared memory `sm` after
`c` lands, reading the global memory `gm`.

A thread's state `Async` has three lists: the copies issued since the last commit (`pending`),
the committed groups not yet complete, oldest first (`groups`), and the copies that have landed,
in landing order (`landed`). `Async.step` takes one `AsyncOp`:

- `copy c`: `c` joins the uncommitted copies;
- `commit`: the uncommitted copies become the newest group, an empty group when there are none
  (the ISA: a commit with no copy since the last one makes an empty group);
- `wait n`: the oldest groups land, in order, until at most `n` remain. Copies not yet committed
  are not waited for.

`Async.run s ops` takes the operations in order; `Async.smem gm sm s` is the shared memory after
the landed copies of `s`, in order. `Async.committed ops` is the copies of `ops` issued before its
last commit, in order, and `Async.uncommitted ops` those issued after it.

## Statements

1. `Async.wait_length`, from every state and for every `n`: after `wait n` at most `n` groups
   are pending.
2. `Async.run_init`, for every sequence `ops` from `Async.init`: the landed copies followed by
   the pending groups' copies are `committed ops`, in order, and the uncommitted copies are
   `uncommitted ops`.
3. `Async.wait_run`, for every `ops` and `n`: after `ops` and `wait n`, at most `n` groups are
   pending, and the landed copies followed by the pending groups' copies are `committed ops`.
4. `Async.visible`, for every `ops`: after `ops` and `wait 0`, no group is pending, the landed
   copies are exactly `committed ops`, in order, and the uncommitted copies are still
   `uncommitted ops`.
5. `Async.visible_bytes`, for every `ops`, global memory `gm` and shared memory `sm`: if the
   destinations of `committed ops` are pairwise disjoint (`AsyncCopy.Disjoint`), then for every
   committed copy `c` and offset `o < c.size`, the shared memory after `ops` and `wait 0` holds
   at `c.dst + o` the global byte `gm (c.src + o)` when `o < c.srcSize`, and `0` otherwise.

The tests run one sequence of two committed copies and one uncommitted copy through `wait 1`
and `wait 0`, and give two twins: the uncommitted copy has not landed after `wait 0`, and of two
committed copies to the same bytes the first is overwritten, so the disjointness premise of
`visible_bytes` is needed.

## Race freedom is the caller's premise

The model reads the global memory `gm` when a copy lands and lets no other access touch shared
memory. That no other thread or instruction writes a pending copy's destination or its source,
and that nothing reads the destination before the wait, is the caller's premise: it is not
modelled here, and `visible_bytes` states the visible bytes only under it. Disjointness of the
committed copies' destinations is the one part of it the theorem takes as a hypothesis.

## Not proved

- The grid's semantics of the copies: the importer refuses the inline asm
  `cp.async.cg.shared.global` that the corpus uses, and the grid runs `commit_group` and
  `wait_group` as no-ops, which is sound only while no copy can be issued. Wiring `Async.step`
  to the grid (a per-thread `Async` state, the landing at `wait_group`) is a dispatch to these
  definitions, not proved here.
- The `.ca` and `.cg` cache hints, `cp.async.bulk`, `cp.async.mbarrier.arrive` and the
  `ignore-src` predicate; and an ordering between copies of different threads.
- That the ISA lands a group's copies in issue order: the model lands them in order, which
  matters only when two committed copies overlap, and then `visible_bytes` says nothing.
