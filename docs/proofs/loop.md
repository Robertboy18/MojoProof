# Loops by induction on the trip count (`Block.sound_loop`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean`,
`MojoProofTest/SymLoopAlloca.lean`.

**Scope.** Every program `P`, function `fn`, loop path `(h, ds, S) :: B` (the header `h` from
position `p`, after its `phi`s, through the body to the latch) that `coversPathWith false` accepts
from `p`, every trip count `n`, every context of `P` and every thread whose innermost frame runs
`fn` at block `h`'s position `p`.

`Block.sound_edge`, `Block.sound_loop`, `Round.of_inv` and `Block.sound_loop_inv` take a flag
`contract`, and so do `BackWith.enter`, `ChainWith`, `ChainWith.reach`, `ChainWith.enter`,
`ChainWith.of_iter`, `ChainWith.of_rounds`, `Runs.of_chainWith` and `Runs.of_chainsWith`
(`LoopPaths`, `Runs.of_loop` and `Runs.of_loops` take none). This file states the `contract = false`
case; with `contract = true` (blocks with `fmul contract`) read `coversPathWith true`,
`WalkWith true`, `Valuation.lastWith true`, `Valuation.roundWith true`, `EdgeWith true`,
`RoundWith true`, `BackWith true`, `coversChainWith true` and `ChainWith true` for
`coversPathWith false`, `WalkWith false`, `Valuation.lastWith false`, `Valuation.round`, `Edge`,
`Round`, `BackWith false`, `coversChain` and `ChainWith false` (docs/proofs/contract.md). The proofs
are the same.

All of these but `Round.of_inv` and the `ChainWith.of_` lemmas also take a flag `alloca`, for
blocks with `alloca`s: the path checker `coversPathAt alloca contract` (MojoProof/Sym/Path.lean)
and the loop checkers `coversChainAt`, `LoopSeg.coversRoundAt` and `coversChainsAt`, whose cases
with the flag off are `coversPathWith`, `coversChainWith`, `LoopSeg.coversRoundWith` and
`coversChainsWith`, by definition. With the flag, the frame a theorem reaches has some blocks
`bs` in front of `f`'s `alloca` blocks, `(bif alloca then bs else []) ++ f.allocas` (the blocks
of the paths run, `Valuation.allocsWith`); with it off that is `f.allocas`. `Block.sound_edge`
names the blocks: `f'.allocas = (Valuation.entry c t.k m f).allocsWith contract l S ps ++
f.allocas`. `Valuation.allocsWith_cond` turns that into the `bif` form, `allocas_trans` composes
two of them, and `Runs.of_chainsAt` is the kernel form with the flag (`Runs.of_chainsWith` is its
case with the flag off). Each of them also says what `bs` is: the memory reached adds exactly
the blocks `bif alloca then bs else []` to the start memory `m` (`Mem.Adds m bs m'`,
MojoProof/Sym/Path.lean: a number is in the list exactly when `m` has no block there and `m'`
has one, and every block of `m` is still there). A block's effects add their `alloca` blocks
(`SEff.run_adds`), a path its blocks' (`Block.sound_pathAt_ptrs`), and `Mem.Adds.trans` composes
two runs, so the edges, rounds and chains carry it. `Runs.of_chainsDead` is the caller's form:
for a predicate `R` that reads only the blocks of `m`, `next` and the trace, if the last path
leaves a memory `me` of `Q` and `R`, the thread runs to its end on a memory `m'` of `R` whose
block at every number is `me`'s, dead where `m` has none (`Mem.Adds.foldl_setLive`). This file
states the case with the flag off.

## Statement

`Valuation.round h S B V` is the valuation at the header after one round from header valuation
`V`: `Valuation.into` of the latch from its entry valuation (`Valuation.lastWith false`).
`Round h p ds S B V` is the premise of one round: `WalkWith false V ((h, ds, S) :: B)`, the latch's
exit goes to `h` (`Exit.dest`), and enters it at position `p` (`Exit.pc`). `Round` is decidable
(`Round.dec`).

If `Round` holds at `round^[i] (Valuation.entry c t.k m f)` for every `i < n`, the thread's steps
reach a thread `t'` with memory `m'` whose innermost frame `f'` runs `fn` at block `h`'s position
`p` above the same frames, with `f`'s `alloca` blocks and caller's register, and
`Valuation.entry c t'.k m' f' = round^[n] (Valuation.entry c t.k m f)`.

`backEdges fn` lists the branches `(l, d)` from a block `l` to a block `d` at the same or an earlier
position in `fn`'s block order, as `#mojo_info` prints them; `cutPoints fn` the labels of their
targets, the loop headers.

## Proof

`Block.sound_rounds` (the induction on `n` for every invariant, in the last section) with the
invariant "the entry valuation is the `i`-th iterate",
`fun i W => W = round^[i] (Valuation.entry c t.k m f)`, which holds at 0 by `rfl`. One round from
a thread at the header whose entry valuation is the `i`-th iterate:
- round `i`'s premises are a path's (`WalkWith false`), so `Block.sound_pathWith_ptrs` runs the
  path to the latch's end (`Ends`, from `lastWith false`), and `lastWith false` keeps the context
  and the function (`Valuation.lastWith_k`);
- the latch's exit goes to `h` (`Exit.dest`), so `Ends.edge` takes the branch, into a frame of
  `fn` at `h`'s position `Exit.pc`, which `Round` says is `p`;
- the entry valuation there is `round` of the `i`-th iterate, the `(i + 1)`-th
  (`Function.iterate_succ_apply'`).

The first two steps are `Block.sound_edge`; `Steps.trans_step` composes the steps.

## Dependencies

`Block.sound_rounds`, `Block.sound_edge` (MojoProof/Sym/Loop.lean);
`Block.sound_pathWith_ptrs`, `Ends.edge`, `Valuation.lastWith_k` (MojoProof/Sym/Path.lean);
`Steps.trans_step` (MojoProof/Sym/Rel.lean); `Function.iterate_succ_apply'` (Mathlib); `succs`
(MojoProof/Sym/Info.lean) for `backEdges`.

## Instances

See the end of this document: the instances are `cnt_retL`, `cnt_run` and `cnt_run_outC`,
through `Runs.of_loop` and `Runs.of_loops`.

# Loops from an invariant (`Round.of_inv`, `Block.sound_loop_inv`, `Runs.of_loops`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean`,
`MojoProofTest/SymLoopAlloca.lean`.

**Scope.** Every program `P`, function `fn`, entry path, loop path and exit path that
`coversPathWith false` accepts, every trip count `n`, every invariant `I : Nat → Valuation → Prop`
(indexed by the round number; an invariant `J` that does not depend on the round is `fun _ => J`),
every predicate `Q` on memories, every context of `P`, and every thread with one frame of `fn`.

## Statement

1. `Round.of_inv`. Suppose `I 0 V` holds. Suppose also that for every `i < n` and every valuation
   `W`, `I i W` gives both `Round h p ds S B W` and `I (i + 1) (Valuation.round h S B W)`. Then
   `Round` holds at `round^[i] V` for every `i < n`, and `I n (round^[n] V)` holds. These are the
   premises of every round for trip count `n`, from the invariant alone.
2. `Block.sound_edge` is `Block.sound_pathWith_ptrs` followed by the last block's edge. Take a path
   `(l, ds, S) :: ps` that `coversPathWith false` accepts from `p0`, and a thread whose innermost
   frame `f` (above `rest`) is at block `l`'s position `p0`. Suppose the path's premises hold
   (`WalkWith false`) and the last block's exit goes to `d` (`Exit.dest`). Then the thread's steps
   reach a frame `f'` above `rest` with these properties:
   - it runs `fn` at block `d`'s position `Exit.pc fn d` (after `d`'s `phi`s for `Exit.phi`);
   - its `alloca` blocks and caller's register are `f`'s;
   - its entry valuation is `Valuation.round l S ps` of `f`'s. For a path of one block that is
     `Valuation.into` of it; for a loop path it is the header's valuation after one round.
3. `Block.sound_loop_inv` is `Block.sound_loop` with its premises from (1). The thread's steps
   reach `h`'s position `p` again, in a frame like `Block.sound_loop`'s. Its entry valuation
   satisfies `I n`.
4. `Runs.of_loop` is the thread-level theorem. A loop `L : LoopPaths` bundles three paths of `fn`:
   the entry path `(L.l, L.ds, L.S) :: L.E` to the header `L.h`, the loop path
   `(L.h, L.dh, L.H) :: L.B` and the exit path `(L.h, L.dh, L.H) :: L.X`, both from the header's
   position `L.p` (after its `phi`s). `L.covers P fn p0` says `coversPathWith false` accepts the
   three, the entry path from `p0`. `Ret W Q ps` says a path runs from `W` to `ret` with a memory of
   `Q`: its premises (`WalkWith false`), a last exit `ret`, and a memory `me` of `Q` that the last
   block's effects make. `RetL V Q L` is the premise of the whole run from `V`:
   - **Entry.** The entry path's premises hold from `V` (`WalkWith false`), and its last exit goes
     to `L.h` (`Exit.dest`) at position `L.p` (`Exit.pc`).
   - **Loop.** For some invariant `I` and trip count `n`: `I 0` holds at the header's entry
     valuation `Valuation.round L.l L.S L.E V`, and every round `i < n` from a valuation of
     `I i` goes back to the header with `I (i + 1)` after it. For a loop with no nested loop
     (`L.inner = []`) that is equivalent to `Round` of the loop path and `I (i + 1)` at
     `Valuation.round`, as in (1). With nested loops the round runs through them
     (`ChainWith false`, in the last section).
   - **Exit.** For every `W`, `I n W` gives `Ret W Q` of the exit path.

   Take a thread `t` with one frame `f` of `fn` at block `L.l`'s position `p0`, on memory `m`,
   with `L.covers P fn p0 = true` and `RetL (Valuation.entry c t.k m f) Q L`. Then
   `∃ me, Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) me) ∧ Q me`. That is, the
   thread runs to its end (`Runs`, MojoProof/Sym/Sched.lean), leaving `me` with `f`'s `alloca`
   blocks dead. The memory left is `me` itself when `f` has none, as for the frames of
   `Grid.start` (`Grid.start_thread`).
5. `Runs.of_loops` is (4) in the form of `Runs.of_ret` (MojoProof/Sym/Kernel.lean), for the
   threads `Grid.start` makes. `coversLoops P fn loops` is a closed Boolean: every loop of
   `loops` starts at the label of `fn`'s first block and `L.covers P fn 0`. Take a thread `t`
   with one frame `f` of `fn` at that label, position 0, with no `alloca` blocks, on memory `m`.
   If `coversLoops P fn loops = true` and some `L ∈ loops` has
   `RetL (Valuation.entry c t.k m f) Q L`, then `∃ m', Runs c t m m' ∧ Q m'`. With `Q` the
   predicate after thread `k`, this is the per-thread premise `Seq.start_sound_inv` takes, as
   `Runs.of_ret` gives it for straight-line paths.
6. `Mem.foldl_setLive_blocks` and `Mem.foldl_setLive_load`: setting the liveness of the
   blocks of a list `bs` in turn (`Mem.setLive`, the cleanup a `ret` does with `false`) keeps
   every block `b ∉ bs`, so a load through a pointer whose block is not in `bs` gives what it gave
   before. For every memory, list, liveness, layout, thread, address space, type, pointer and
   alignment.

## Proof

1. Show `I i (round^[i] V)` for every `i ≤ n`, by induction on `i`.
   - For `0` it is the hypothesis.
   - For `i + 1 ≤ n` we have `i < n`. The induction hypothesis gives `I i (round^[i] V)`, so the
     preservation hypothesis at `i` gives `I (i + 1) (round (round^[i] V))`. This valuation is
     `round^[i + 1] V` (`Function.iterate_succ_apply'`).

   Round `i < n`'s premise is then the preservation hypothesis at `i` and `round^[i] V`, using
   `i ≤ n`. The last conjunct is the case `i = n`.
2. `Block.sound_loop` and `ChainWith.reach` use it for each round and each edge into a header.
   - `Block.sound_pathWith_ptrs` gives `Ends` at the last block's entry valuation
     (`Valuation.lastWith false`).
   - `Valuation.lastWith_k` says that valuation has `f`'s context and function.
   - `Ends.edge` takes the branch: a step into `d` at position `Exit.pc V.fn d`, with entry
     valuation `Valuation.into`. That is `Valuation.round l S ps V` by definition.
   - `Steps.trans_step` adds the branch step to the path's steps.
3. (1) gives `Block.sound_loop`'s premise. Its conclusion's entry valuation is `round^[n]` of the
   first, which (1) says satisfies `I n`.
4. `Runs.of_loop` is `Runs.of_chainWith` of the one loop (the last section), whose proof composes
   three parts:
   - `Block.sound_edge` on the entry path, with `rest = []`, reaches a frame at `h`'s position
     `Exit.pc fn h`, which is `p`. Its entry valuation is `Valuation.round l S E` of `f`'s, so
     `I 0` holds there.
   - `Block.sound_rounds` reaches `h`'s position `p` again, at a valuation of `I n`; with no
     nested loop each round is `Block.sound_edge` of the loop path.
   - The exit hypothesis there gives `WalkWith false` and `ret`. `Block.sound_retWith` then gives
     the steps to the `ret` and its `.done` step on the memory the effects make, which is the memory
     of `Q` because `Except.ok` is injective.
   - The `alloca` blocks are still `f`'s (each part keeps them), and `Steps.trans` composes the
     three runs into `Runs`.
5. `Runs.of_loops` is `Runs.of_chainsWith` (the last section) with the witness `L.chain`:
   `coversLoops` is `coversChains` of `loops.map LoopPaths.chain` (`List.mem_map_of_mem`).
   `coversChains` gives the chosen chain's start label and `coversChain` from position 0
   (`List.all_eq_true`); the start label is `f.label` because both are the label of `fn`'s first
   block. `Runs.of_chainWith` gives the run, and with `f.allocas = []` the cleanup is the identity.
6. Induction on `bs`. For `a :: bs` with `b ∉ a :: bs`, `b ≠ a`; `Mem.setLive a v` either sets
   block `a` (`Mem.set`, which changes only `a`) or leaves the memory unchanged. The load lemma
   rewrites `Mem.load`, `Mem.check`, `Mem.block` and `Mem.addr` with the block lemma.

Each round of `Block.sound_loop` is `Block.sound_edge` (the proof in the first section).

## Dependencies

- `Block.sound_rounds`, `Runs.of_chainWith`, `Runs.of_chainsWith` (MojoProof/Sym/Loop.lean);
- `Block.sound_pathWith_ptrs`, `Block.sound_retWith`, `Ends.edge`, `Valuation.lastWith_k`
  (MojoProof/Sym/Path.lean); `Steps.trans`, `Steps.trans_step` (MojoProof/Sym/Rel.lean);
- `Runs` (MojoProof/Sym/Sched.lean);
- `Mem.setLive`, `Mem.set`, `Mem.load` (MojoProof/Sem/);
- `Function.iterate_succ_apply'` (Mathlib).

## Instances

These are in MojoProofTest/SymLoop.lean. They cover one hand-written function `cnt`
(`for i in [0, n): p[i] = i`) from its entry block.

- `cntL`: the loop's paths (the entry block `0`, the loop path `1 → 2`, the exit path `1 → 3`,
  the header `1` at position 1). `cnt_covers`: `cntL.covers cntP cnt 0`; `cnt_loops`:
  `coversLoops cntP cnt [cntL]`. Both by `decide +kernel`.
- `cnt_retL`: **every trip count**, as the premise `RetL`. Take every context `c` of `cntP`, every
  bound `n ≤ 2 ^ 60`, every block `b`, step count `k` and memory `m` of `Cells c.who n b 0 m`,
  and every frame `f` of `cnt` with `%n = n` and `%p` at offset 0 of `b`. `Cells w n b i m` says
  block `b` is not the null block, is live, writable, in address space 1, 8-aligned, admits `w`,
  has room for `n` cells of `i64`, and cells `j < i` hold `j`. Then
  `RetL (Valuation.entry c k m f) Q cntL`, where `Q me` says cell `j` of `me` holds `j` for every
  `j < n`, with the invariant `invN c n b i` (the valuation is in `c` and `cnt`, `%i = i`,
  `%n = n`, `%p` at `b`, and `Cells c.who n b i`) and trip count `n`.

  Its three parts are symbolic proofs for every `n`, round `i` and valuation of the invariant;
  nothing is decided by evaluation:
  - `invN_entry`: the entry block's obligations, its edge to the header at position 1, and the
    invariant at round 0. The `phi` operand is the constant 0 (`cnt_enter`,
    `Valuation.into_of_enter`).
  - `invN_step`: from `invN c n b i W` with `i < n`, `Round` at `W` and `invN c n b (i + 1)`
    after it. The header's comparison is `i < n` as `i64` (`hdr_vals`, `slt_ofNat`). The body's
    nodes are `i + 1` and the address of cell `i`, offset `8 i` (`body_vals`). The store to cell
    `i` succeeds and gives `Cells … (i + 1)` (`Cells.store`: `Mem.store_of_check`,
    `Block.read_put_self` for cell `i`, `Block.read_put_apart` for the cells `j < i`). The `phi`
    takes `%inext` (`cnt_enter`, `Valuation.into_of_enter`). Only `%c` changes at the header
    (`hdr_after`).
  - `invN_exit`: from `invN c n b n W`, the exit path's premises (the comparison `n < n` is
    false), its `ret`, and the loads of the cells (`Cells.load`, `Mem.load_of_check`,
    `Layout.scalarOf_leBytes`).

  The bound `n ≤ 2 ^ 60` keeps the offset `8 i` below `2 ^ 63`: `getelementptr`'s offset is
  reduced by `Int.bmod` modulo `2 ^ 64` (`Int.bmod_eq_of_le`). It also keeps `n` below `2 ^ 63`,
  so `%n` is non-negative as `i64`.
- `cnt_run`: the thread-level form, for the contexts, bounds, blocks and memories of `cnt_retL`
  and every thread whose one frame `f` is at `cnt`'s entry with `%n = n`, `%p` at offset 0 of
  `b`, and `b ∉ f.allocas`. The thread runs to its end (`Runs`), and in the memory `m'` it
  leaves, the endpoint of `Runs` (with `f`'s `alloca` blocks dead), cell `j` holds `j` for every
  `j < n`. This is `Runs.of_loop` with `cnt_covers` and `cnt_retL`, then
  `Mem.foldl_setLive_load` with `b ∉ f.allocas` (an earlier `cnt_run` proved the loads on
  the memory before the cleanup; with `f.allocas = [b]` the return kills the output block and a
  load from it fails the live-block check).
- `cnt_run_outC`: `Runs.of_loops` with `cnt_loops` and `cnt_retL` on one memory, `outC`, with
  three cells, and the frame `frameC n` (at `cnt`'s first block, position 0, no `alloca` blocks),
  for every `n < 4`. Its premises are `rfl`, `decide` and `8 n ≤ 24`.
- Twin `cnt_inv_twin`: the invariant "`%i = 0`" (with the iterate) holds at entry but is not
  preserved. Round 0 makes `%i = 1`, so the preservation part of `RetL` fails.
- `cnt_twins`: the premises of a fourth round fail with bound 3 (`%i = 3` is not below `%n`) and
  with bound 4 on `outC` (the store to cell 3 is outside the three-cell block), and the loop path
  from the header's position 0 (its `phi`) is refused.

## Limits

The theorems hold for every program and invariant, and `cnt_retL` and `cnt_run` for every trip
count up to `2 ^ 60` and every memory with room for the cells. Four things are not done:
- The kernel theorem: `Kernel.sound_of_paths` (MojoProof/Sym/Kernel.lean) takes `Ret` of
  straight-line paths only; its per-thread premise has to accept `RetL` too (`Runs.of_loops`), and
  `mojo_kernel` has to find the loop paths and discharge each round's premises from an invariant.
- The instance's steps (`hdr_vals`, `body_vals`, `invN_step`) are proved for `cnt`'s summaries;
  another loop needs its own. The general steps are `Valuation.into_of_enter`,
  `Mem.addr_own` and `Mem.store_of_check` (MojoProof/Sym/Loop.lean).
- Termination. The trip count is a hypothesis, and the invariant says only which `n` it is.
- Loops whose body leaves the fragment. The naive matmul kernel's latch `%52` has a
  `fmul contract` whose product the next statement reads: `covers` refuses it, and `coversC`,
  which accepts it, has no loop theorem (`docs/proofs/contract.md`).

`backEdges` uses the block order, not dominators. For the reducible loops the compiler emits the
two agree, but this is not proved.

# Loops in sequence and nested loops (`ChainWith`, `ChainWith.reach`, `Runs.of_chainsWith`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean` (`cnt2_covers`,
`cnt2_retLs`, `cnt2_run`, `cnt2_twins`; `nest_covers`, `nest_rounds`, `nest_retLs`, `nest_run`,
`nest_twins`).

**Scope.** Every program `P`, function `fn`, list of loops `Ls` (each with the loops nested in its
rounds, to any depth), path before them, position `p0`, and predicate `F` on the last path (or
`Q` on memories), such that `coversChain` accepts the paths; for each loop, every trip count and
invariant; every context of `P` and every thread whose innermost frame runs `fn` (with one frame
for `Runs.of_chainWith`). The instances are two functions written in the test, `cnt2` (two loops in
sequence) and `nest` (two nested loops), each on one bound and one memory.

## Statement

Definitions (MojoProof/Sym/Loop.lean).

- `Edge h p V l ds S E`: the premises of the path `(l, ds, S) :: E` from `V` hold
  (`WalkWith false`), and its last block's exit goes to `h` (`Exit.dest`) at position `p`
  (`Exit.pc`). It is decided by evaluation (`Edge.dec`, :240).
- `Round h p ds S B V` is `Edge h p V h ds S B`: the loop path's last edge goes back into
  its own header (`Round.dec`, :251).
- `BackWith false h p J V l ds S E`: `Edge h p V l ds S E` and `J (Valuation.round l S E V)`. This
  is the end of a round: the last path goes back to the header at `p`, and `J` holds at the
  header's entry valuation after it.
- `LoopSeg`: one loop, with fields `h p dh H B X inner`:
  - the header `h` and the position `p` after its `phi`s;
  - the header's conditions `dh` and summary `H` from `p`;
  - the rest `B` of the loop path, to the latch or to the first nested loop's header;
  - the rest `X` of the path out of the loop: to the next loop's header, back to the header of
    the loop this one is nested in, or to a `ret`;
  - `inner`, the loops nested in a round, in the order a round runs them.

  A round runs the loop path and then the nested loops in order. The loop path's last edge goes
  to the first nested loop's header, each nested loop's path out to the next one's header, and
  the last one's back to `h`. With no nested loop, the loop path's last edge goes back to `h`.
- `LoopPaths` is `LoopSeg` extended by the entry path's `l ds S E`. `LoopChain` is
  an entry path `l ds S E` and `loops : List LoopSeg`. `LoopPaths.chain` is the chain of
  the one loop.
- `coversChain P fn p0 l ds S E Ls` and `LoopSeg.coversRound P fn L` are defined
  together (`mutual`), by structural recursion on the loops:
  - with no loop, `coversChain` is `coversPathWith false P fn p0 ((l, ds, S) :: E)`;
  - with `L :: Ls`, it is that, `L.coversRound P fn`, and
    `coversChain P fn L.p L.h L.dh L.H L.X Ls`, so the path out takes the place of the path
    before for the next loop;
  - `L.coversRound P fn` is `coversChain P fn L.p L.h L.dh L.H L.B L.inner`: the loop path from
    the header's position, and the nested loops after it.

  `LoopPaths.covers P fn p0 L` is `coversChain P fn p0 L.l L.ds L.S L.E [L.toLoopSeg]`.
  These are Booleans that the kernel evaluates (`decide +kernel`).
- `ChainWith false F Ls V l ds S E` is an inductive predicate. `F` is a predicate on a valuation
  and a path, and it holds of the last path. Its two constructors are these.
  - `ChainWith.last`: `F V l ds S E` gives `ChainWith false F [] V l ds S E`.
  - `ChainWith.loop I n`, for an invariant `I : Nat → Valuation → Prop` and a trip count `n`. It
    gives `ChainWith false F (L :: Ls) V l ds S E` from four premises:
    - `Edge L.h L.p V l ds S E`;
    - `I 0 (Valuation.round l S E V)`;
    - for every `i < n` and every `W` with `I i W`,
      `ChainWith false (BackWith false L.h L.p (I (i + 1))) L.inner W L.h L.dh L.H L.B`, so the
      round runs
      the loop path and the nested loops and goes back to the header with `I (i + 1)`;
    - for every `W` with `I n W`, `ChainWith false F Ls W L.h L.dh L.H L.X`.
- `RetLs Q Ls V l ds S E` is `RetLsWith false`, `ChainWith false` with
  `F V l ds S E := RetWith false V Q ((l, ds, S) :: E)` (`Ret`): the last path runs to `ret`
  with a memory of `Q`. `RetL V Q L` is
  `RetLs Q [L.toLoopSeg] V L.l L.ds L.S L.E`.
- `coversChains P fn Cs`: every chain of `Cs` starts at the label of `fn`'s first block,
  and `coversChain` accepts it from position 0. `coversLoops P fn loops` is
  `coversChains P fn (loops.map LoopPaths.chain)`.

Theorems.

1. `Block.sound_rounds` holds for every context `c`, function `fn`, frames `rest`, block
   `h`, position `p`, invariant `I` and trip count `n`. Suppose that for every `i < n`, every
   thread whose innermost frame `f` runs `fn` above `rest` at `h`'s position `p`, with `I i` at
   its entry valuation, steps to a frame of `fn` above `rest` at `h`'s position `p`, with `f`'s
   `alloca` blocks and caller's register and with `I (i + 1)` at its entry valuation. Then every
   such thread with `I 0` steps to such a frame with `I n`. A round is one loop path in
   `Block.sound_loop`, and it runs the nested loops in `ChainWith.reach`.
2. `ChainWith.reach`. Take `hP : c.prog = P`, `ChainWith false F Ls V l ds S E` and
   `coversChain P fn p0 l ds S E Ls = true`. Take a thread `t` on memory `m` with
   `t.frames = f :: rest`, `f.fn = fn`, `f.label = l`, `f.pc = p0` and
   `Valuation.entry c t.k m f = V`. Then `t`'s steps reach a thread `t'` on memory `m'` and a
   last path `(l', ds', S') :: E'`, such that:
   - `t'.frames = f' :: rest`, with `f'.fn = fn`, `f'.label = l'` and `f'.pc = p'`;
   - `f'.allocas = f.allocas` and `f'.dest = f.dest`;
   - `coversPathWith false P fn p' ((l', ds', S') :: E') = true`;
   - `F (Valuation.entry c t'.k m' f') l' ds' S' E'`.
3. `Runs.of_chainWith`. Take `hP`, a list `Ls`, and `coversChain P fn p0 l ds S E Ls = true`.
   Take a thread `t` with `t.frames = [f]`, `f.fn = fn`, `f.label = l`, `f.pc = p0` and
   `RetLs Q Ls (Valuation.entry c t.k m f) l ds S E`. Then
   `∃ bs me, Runs c t m (((bif alloca then bs else []) ++ f.allocas).foldl
   (fun m b => m.setLive b false) me) ∧ Q me ∧ m.Adds (bif alloca then bs else []) me`, with
   `alloca = false` here.
   `Runs.of_loop` is `Runs.of_chainWith hP [L.toLoopSeg]` without the flags.
4. `Runs.of_chainsAt` takes `Runs.of_loops`'s premises, with `coversChainsAt alloca false P fn Cs
   = true` and `∃ C ∈ Cs, RetLs Q C.loops (Valuation.entry c t.k m f) C.l C.ds C.S C.E` in place
   of theirs. It concludes `∃ bs me, Runs c t m ((bif alloca then bs else []).foldl
   (fun m b => m.setLive b false) me) ∧ Q me ∧ m.Adds (bif alloca then bs else []) me`.
   `Runs.of_chainsWith` is its case with the flag
   off, concluding `∃ m', Runs c t m m' ∧ Q m'`, and `Runs.of_loops` is `Runs.of_chainsWith` with
   the witness `L.chain`.
5. `ChainWith.of_iter` holds for every `F`, loop `L`, loops `Ls`, path `(l, ds, S) :: E`,
   valuation `V`, function `g` on valuations and trip count `n`. Write
   `V₀ = Valuation.round l S E V` for the header's entry valuation. Suppose these hold:
   - `Edge L.h L.p V l ds S E`;
   - `ChainWith false (BackWith false L.h L.p (· = g (g^[i] V₀))) L.inner (g^[i] V₀) L.h L.dh
     L.H L.B`
     for every `i < n`;
   - `ChainWith false F Ls (g^[n] V₀) L.h L.dh L.H L.X`.

   Then `ChainWith false F (L :: Ls) V l ds S E` holds. The invariant is "`W` is the `i`-th
   iterate of `g`". With nested loops the round function `g` is not `Valuation.round` of the loop
   path.
6. `ChainWith.of_rounds` is for a loop with no nested loop (`L.inner = []`). Suppose that
   `Edge L.h L.p V l ds S E` holds and that, for every `i < n`, `Round L.h L.p L.dh L.H L.B`
   holds at `(Valuation.round L.h L.H L.B)^[i] (Valuation.round l S E V)`. Suppose also that
   `ChainWith false F Ls` holds at the `n`-th iterate after `L`'s path out. Then
   `ChainWith false F (L :: Ls) V l ds S E`. On a concrete valuation and `n`, the first two
   premises are closed and decidable (`EdgeWith.dec`, `RoundWith.dec`).
7. `BackWith.enter`: take `hP`, `coversPathAt alloca false P fn p0 ((l, ds, S) :: E) = true`
   and a thread `t` on memory `m` with `t.frames = f :: rest`, `f.fn = fn`, `f.label = l`,
   `f.pc = p0` and `BackWith false d q J (Valuation.entry c t.k m f) l ds S E`. Then `t`'s steps
   reach a frame `f'` of `fn` above `rest` at block `d`'s position `q`, with
   `f'.allocas = (bif alloca then bs else []) ++ f.allocas` and `m.Adds (bif alloca then bs
   else []) m'` for some `bs`, `f'.dest = f.dest` and `J (Valuation.entry c t'.k m' f')`.
   `ChainWith.enter` concludes the same from `coversChainAt alloca false P fn p0 l ds S E Ls =
   true` and `ChainWith false (BackWith false d q J) Ls (Valuation.entry c t.k m f) l ds S E`: a
   chain whose last path out stops after its last edge, into `d` at `q`, with no second chain
   relation. A continuation from that frame, given its `alloca` blocks (`bs` in front of `f`'s
   with the flag on, `f`'s with it off), joins it (`RunsVia.of_chain`,
   MojoProof/Sym/OblSeg.lean); the instance is gemv_kernel's chain into `%78`
   (`tail78`, MojoProofTest/GemvWarp.lean), whose end memory frees `f`'s blocks.

## Proof

1. Induction on `n`. For `0` there is no step. For `n + 1`, the induction hypothesis (with the
   premises for `i < n`) reaches the header with `I n`. The premise at `n` then reaches it again
   with `I (n + 1)`. `Steps.trans` composes the steps, and each part keeps the `alloca` blocks
   and the caller's register.
2. Induction on `ChainWith`, for every position, thread, memory and frame.
   - `ChainWith.last`: there is no step. `coversChain` of no loop is `coversPathWith false` of the
     path.
   - `ChainWith.loop`: `coversChain` splits into the path, `L.coversRound` and the rest.
     `L.coversRound` is `coversChain` of the round's paths, by cases on `L`.
     - `Block.sound_edge` enters `L`'s header at `L.p`, with `I 0`.
     - `Block.sound_rounds` runs the `n` rounds. Each round is the induction hypothesis on the
       round's `ChainWith false`, which reaches its last path. There `BackWith false` gives that
       path's premises, its edge to `L.h` at `L.p` and `I (i + 1)`, and `BackWith.enter` takes
       that edge.
     - The induction hypothesis on the path out, at a valuation of `I n`, reaches the last path.

     `Steps.trans` composes the runs.
3. `ChainWith.reach` reaches the last path, where `Ret` gives `WalkWith false` and `ret`.
   `Block.sound_retWith` gives the steps and the `.done` step. `Except.ok.inj` matches the memory,
   and the `alloca` blocks are `f`'s.
4. `coversChains` gives the chosen chain's start label and `coversChain` from 0
   (`List.all_eq_true`). The start label is `f.label`, because both are the label of `fn`'s first
   block. With `f.allocas = []` the cleanup is the identity. For `Runs.of_loops`, `coversLoops`
   is `coversChains` of the map, and `List.mem_map_of_mem` gives the witness.
5. `ChainWith.loop` with `I i W := W = g^[i] V₀`. `I 0` is `rfl`. A round from the `i`-th iterate
   ends with the `(i + 1)`-th (`Function.iterate_succ_apply'`). `I n W` is `W = g^[n] V₀`.
6. `ChainWith.of_iter` with `g := Valuation.round L.h L.H L.B`. With no nested loop, a round's
   `ChainWith false` is `ChainWith.last` of `BackWith false`: the `Round` premise and `rfl`.
7. `BackWith.enter` is `Block.sound_edge` at `BackWith`'s `EdgeWith`, the position by
   `EdgeWith`'s last conjunct and the blocks by `Valuation.allocsWith_cond`. `ChainWith.enter`
   is `ChainWith.reach` to the last path, then `BackWith.enter`, the blocks composed by
   `allocas_trans`. `Block.sound_loop`'s rounds are `BackWith.enter` with `J` "the next
   iterate".

## Dependencies

`Block.sound_edge`, `Block.sound_retWith`, `Steps.trans`, `Ret`, `Valuation.round`,
`Function.iterate_succ_apply'`, `List.all_eq_true`, `List.mem_map_of_mem`.

## Instances

In MojoProofTest/SymLoop.lean. Each instance is for one program, one bound and one memory, by
evaluation.

Two loops in sequence:

- `cnt2` is two counting loops in sequence. Its blocks:
  - the entry `0` branches to header `1`;
  - header `1` counts `%i`, with body `2` storing `%i` to cell `%i` at `%p`;
  - the first loop's exit `3` branches to header `4`;
  - header `4` counts `%j`, with body `5` storing `%j` to cell `%j` at `%s`;
  - the exit `6` returns.
- `loop1` and `loop2` have no nested loop. `cnt2C` is the chain of both
  after block `0`, whose summary is `cntE`, the `br` of `cnt`'s entry block into the first
  header. `cnt2_covers` checks `coversChains cnt2P cnt2 [cnt2C] = true` by
  `decide +kernel`.
- `cnt2_retLs` is `RetLs` of the two loops at `frame2`'s entry valuation, with `%n = 2`
  and `%p` and `%s` at the two 16-byte blocks of `out3`. It uses `ChainWith.of_rounds` with trip
  count 2 twice, then `ChainWith.last`. Its premises are checked by `decide +kernel`, and so are the
  effects of the last block, which leave cells 0 and 1 of both blocks holding 0 and 1
  (`run_ok`, :651).
- `cnt2_run` is `Runs.of_chainsWith` with those two. The thread `⟨[frame2], 0⟩` runs on
  `out3`'s memory to its end, and in the memory it leaves cells 0 and 1 of both blocks hold 0
  and 1.
- `cnt2_twins` has two parts.
  - The first loop alone, `RetLs Q [loop1] V 0 cntE.obls cntE []`, fails for every `Q` and
    `V`. The invariant holds at the trip count (by induction on the rounds, each `ChainWith.last`).
    There `Ret` needs the path out `1 → 3` to end in `ret`, but block `3`'s exit goes to header
    `4`.
  - `coversChains` refuses the chain whose second loop starts at its header's position 0 (the
    `phi`).

Two nested loops:

- `nest` is `for i in [0, n): for j in [0, n): p[j] = i`. Its blocks:
  - the entry `0` branches to the outer header `1`;
  - header `1` (a `phi` for `%i`) branches into the inner header `2` or to the exit `5`;
  - header `2` (a `phi` for `%j`) branches to the body `3` or to the latch `4`;
  - the body `3` stores `%i` to cell `%j` at `%p` and branches back to `2`;
  - the latch `4` increments `%i` and branches back to `1`;
  - the exit `5` returns.
- `loopJ` is the inner loop: header `2` at position 1, loop path `2 → 3`, path out
  `2 → 4`. `loopI` is the outer loop: header `1` at position 1, the loop path the header
  alone (`B = []`), `inner = [loopJ]`, and the path out `1 → 5`. `nestC` is the chain of
  `loopI` after block `0`. `nest_covers` checks `coversChains nestP nest [nestC] = true`
  by `decide +kernel`.
- `hdrT` is the outer header's entry valuation, and `outerT` is one outer round:
  the header, two inner rounds and the inner path out. `nest_rounds` checks, for each
  outer round `i < 2` from `outerT^[i] hdrT`, the header's edge into `2` at position 1, the
  inner loop's two rounds, and the inner path out's edge into `1` at position 1, by
  `decide +kernel`.
- `nest_retLs` is `RetLs` of `[loopI]` at `frameT`'s entry valuation (`%n = 2`, `%p` at
  `out2`'s block), where `Q` says that cells 0 and 1 hold 1. It is proved in three parts:
  - the outer loop by `ChainWith.of_iter`, with `outerT` and trip count 2;
  - each outer round by `ChainWith.of_rounds` on `loopJ`, with trip count 2 (`nest_rounds`);
  - the outer path out to `ret`, with the memory's cells, by `decide +kernel`.
- `nest_run` is `Runs.of_chainsWith` with `nest_covers` and `nest_retLs`. The thread
  `⟨[frameT], 0⟩` runs on `out2`'s memory to its end, and in the memory it leaves cells 0 and 1
  hold 1, the outer counter's last value.
- `nest_twins` has two parts.
  - Without its nested loop (`inner := []`), the outer loop does not run to `ret` from
    `frameT`'s entry valuation, for every `Q`. With trip count 0 the outer path out fails at
    `%i = 0 < 2`. Otherwise the first round's path, the header alone, does not go back to the
    header.
  - `coversChains` refuses the chain whose nested loop starts at its header's position 0 (the
    `phi`), because it checks the nested loop's paths.

The one-loop instances `cnt_covers`, `cnt_loops`, `cnt_retL`, `cnt_run` and `cnt_run_outC` go
through `Runs.of_loop` and `Runs.of_loops`, which are corollaries of the theorems above.

With the flag `alloca` (MojoProofTest/SymLoopAlloca.lean), on one hand-built kernel `@k` with
gemv_kernel's header and data layout: a counting loop from 0 to 2 whose body `%4` allocates an
`i32` each round, its locals numbered as the parser numbers them; its printed text imports back
to the same module (`Mutate.admission`).

- `loopK_covers`: `coversChainsAt true false` accepts the entry block, the loop path from the
  header's position 1 and the path out; the body's summary has the `alloca`'s effect, and
  `coversChainsWith false` refuses the loop.
- `loopK_mutant`: with the flag, the checker refuses the body summary without its `alloca`
  effect and the loop entered at the header's position 0, its `phi`.
- `loopK_retLs` and `loopK_run`: for the context `ctx0` with the program, the thread whose one
  frame is at `@k`'s first block and the memory `memK` (one launch block at number 1 holding the
  `i32` 7, so the fresh numbers start at 2), `ChainWith.of_rounds` with trip count 2 and
  `Runs.of_chainsDead (alloca := true)`: the thread runs to its end on a memory whose two
  rounds' blocks 18 and 83 are dead (4 bytes each) and whose load of block 1 is `memK`'s, 7.
- `loopK_inUse`: on `memK` with a block already at 18 (`memX`), the kernel decides that the
  rounds' premises fail: the first round's `alloca` faults on the number in use.

The theorems cover every program and every chain of loops, in sequence and nested, that the
checker accepts. The first part of each twin covers every predicate, and for `cnt2_twins` every
valuation.

## Limits

- `cnt2_retLs` and `nest_retLs` are for `n = 2` on one memory, by evaluation. A proof for every
  bound needs each loop's invariant steps, as `invN_step` gives them for `cnt`.
- `Kernel.sound_of_paths` and `mojo_kernel` (MojoProof/Sym/Kernel.lean) still take loop-free
  paths.

# The naive kernel's thread through its loop (`thread_run`, `thread_skip`, `thread0`)

Lean: `MojoProofTest/NaiveThread.lean`, with `Valuation.roundWith_k` in
`MojoProof/Sym/Loop.lean`. The kernel is the naive matmul (`naive`,
MojoProofTest/SymPhi.lean); the plan of its kernel theorem is in docs/proofs/kernel.md, and this
section is that plan's run of one thread of `S` (its step 4).

**Scope.** `Valuation.roundWith_k`: every flag, header label, summary, path, valuation and number
of rounds. `steps` and `thread_run`: every valuation of `naive`'s function (so every thread of
every launch, at any step count), every list of factor pairs (the trip count `K` is its length),
and every predicate on the head's valuations and on the memory at the return. `thread_skip`:
every valuation and predicate on the memory at the return. `thread0`, `thread0_twin` and
`skip_threads` are tests: one launch, one memory, one address choice, one oracle.

## Statement

1. `Valuation.roundWith_k`. `i` rounds (`Valuation.roundWith contract`'s `i`-th iterate) keep
   the context and the function and add `i * (pathLen S B + 1)` to the step count.
2. `steps`. For the naive kernel's chain `chainN` (the path `%6 → %45` into `%46`'s position 2,
   then the loop `naiveL`, accepted by `coversChainsWith true`: `chainN_covers`): the path adds 39
   steps, a round adds 18, and the latch `%52` is entered 3 steps after the head. Its `fmul`
   (statement 12) and `fadd` (statement 13) in round `j` are thus the steps `k0 + 54 + 18 j` and
   `k0 + 55 + 18 j` of a thread whose entry valuation has step count `k0`, and their oracle numbers
   are `oN c k0 j`, the context's oracle at those steps, lane 0. The positions are proved from
   the step count, not read off a run.
3. `Inv o ps j W`: `%47 = j` and `%48` holds `dotLoop true o +0 (ps.take j)`.
4. `thread_run`. For a valuation `V` with `V.fn = naive.fn_0`, pairs `ps` and predicates `G`
   (on head valuations) and `Q` (on memories), suppose:
   - `hE`: the entry block `%6`'s obligations hold at `V` and its branch goes to `%45` (the thread
     is in bounds);
   - `h0`: `Inv (oN V.ctx V.k) ps 0` and `G` at the head after `%6 → %45`;
   - `hR`: for every `j < ps.length` and every head valuation `W` with `V`'s context and step
     count `V.k + 39 + 18 j` where `Inv` and `G` hold: the round's premises (`RoundWith true`),
     `G` after it, `%47 = j + 1` after it, and `%48` after it is the `fadd contract` of `%48`
     before it and the `fmul contract` of pair `j`, at the oracle numbers of the latch's
     statements 12 and 13;
   - `hX`: at the head after `ps.length` rounds where `Inv` and `G` hold, the path out
     `%46 → %51 → %67 → %69` returns with a memory of `Q` (`RetWith true`).

   Then `∃ C ∈ [chainN], RetLsWith true Q C.loops V C.l C.ds C.S C.E`. With
   `V = Valuation.entry (c k) 0 m' f` this is the second disjunct of the per-thread premise of
   the kernel theorem with `fmul contract` for `chains = [chainN]`.
5. `thread_skip`. For a valuation `V` and a predicate `Q` on memories: if `%6`'s obligations hold
   at `V`, its branch goes to `%44` (the thread is out of bounds), and `Q` holds of the memory
   that `%6`'s effects give (its three loads, which add trace entries), then
   `RetWith true V Q skipN`, where `skipN` is the path `%6 → %44 → %69`, accepted by
   `coversPathWith true` (`skipN_covers`): the first disjunct of that premise, for
   `paths = [skipN]`. No store runs on the path.

The premises are the obligations the checker does not decide, each at a symbolic `W`: the
bounds `%47 < %16` with `%16 = smax(K, 0)`, the address arithmetic of the latch's loads (they
read pair `j`) and of the store, and the in-bounds test of `%6`. The oracle positions are not
premises.

## Proof

`steps` is `Valuation.roundWith_k` at the path (one round of `%6 → %45`, whose `pathLen` is 38)
and at `naiveL` (`pathLen` 17), and `Valuation.lastWith_k` with the latch's length 14, the
lengths by `decide +kernel`. `thread_run` applies `Round.of_inv` with the invariant
`W.ctx = V.ctx ∧ W.k = V.k + 39 + 18 j ∧ Inv … j W ∧ G W`. In a round, `hR` gives the
registers after it; `steps` turns the latch's oracle steps into `oN`'s, `floatBin_dotStep`
turns the `fmul` and `fadd` into `dotStep true`, and `dotLoop` of `ps.take (j + 1)` is
`dotStep` of `dotLoop` of `ps.take j`. The rounds then give `ChainWith.of_rounds`, the edge
`%45 → %46` is `SymNaive.pre_edge` (every valuation), and `hX` closes the chain with
`ChainWith.last`. `thread_skip` unfolds `RetWith`: `%44` and `%69` have no effect and the one
obligation `.mem []`, `%44` is a `br`, and the memory at `%69`'s entry is that of `%6`'s effects
(`Valuation.intoWith` keeps `Valuation.after`'s memory).

## Instances

- `thread0_chain`, `thread0`: the start `startN` of `naive` on one block of 2 × 2 threads with
  `m = n = 1` and `K = 2` (`argsN`), the memory `memN` (C one cell, A and B row 0 of
  MojoProofTest/NaiveRun.lean's matrices), the address choice 0 and the oracle `ωN`, which gives 2
  (fuse the `fadd`) at step 73. All of `thread_run`'s premises at thread 0, the one in bounds,
  are closed by `decide +kernel`, with `G` the three head valuations. `Runs.of_chainsWith true`
  then runs thread 0 from `Grid.start`'s frame to its end, and cell `(0, 0)` holds
  `dotLoop true (oN (cN 0) 0) +0 psN`, the word `0xa8800000` (`-2 ^ -46`). The oracle numbers
  used are those of steps 54, 55, 72 and 73 (0, 0, 0 and 2).
- `thread0_twin`: under `oN (cN 0) 1`, the numbers one step later (55, 56, 73, 74), round 1's
  `fadd` does not fuse, `dotLoop` gives `+0`, and `Inv` fails at the head after two rounds.
- `skip_threads`: at the same start, threads 1 to 3 (out of bounds) run to their end by
  `thread_skip` and `Runs.of_retWith`, with the memory of their three loads, the premises closed
  by `decide +kernel`; thread 0's branch goes to `%45`, so `thread_skip`'s premise fails there.
  With `thread0`, every thread of the launch runs to its end.

## Limits

- `startN`'s launch has `m = n = 1` and blocks of one and two floats, so it does not meet
  `NaiveSpec.At`. MojoProofTest/NaiveStart.lean has an evaluated start that does (`m = 1`,
  `n = 2`, `C` of `50257 * 4` bytes, `A` and `B` read-only, every `A`, `B`, `K ≤ 768` and
  oracle), with `NaiveIn.runIn` and `NaiveOut.runOut` at each of its four threads
  (`NaiveStart.runs12`). `thread0`, `thread0_twin` and `skip_threads` are about `memN` and `ωN`
  (a concrete cell value, a failing invariant, the memory of the loads), so they are not
  corollaries of it.
- The kernel theorem for `naive` still needs the premises of `thread_run` and `thread_skip`
  discharged at a symbolic thread (the obligation prover), the start facts for the three
  `byval` structs, and the `Elem` bookkeeping of the plan's steps 2, 3 and 5 (among it, that an
  out-of-bounds thread's loads keep the cells).

# Facts at a loop's heads (`LoopSeg.kept`, `LoopSeg.loadsFrom`, `LoopSeg.stepAt`)

Lean: `MojoProof/Sym/LoopFacts.lean`. Tests: `MojoProofTest/LoopFacts.lean`.

**Scope.** Every program, function and loop (`LoopSeg`), every flag `contract`, valuation and
round count. The checks are Booleans and lists over the summaries, which the kernel computes on a
concrete loop; the lemmas hold for every loop the checks accept. A round here is the loop path's
(`Valuation.roundWith c L.h L.H L.B`); a round of a loop with nested loops also runs theirs, and
the lemmas then hold for its loop path alone, not for the whole round.

## Statement

*Registers the loop keeps.* `Summary.reads S` lists the registers a block reads: the `SVal.reg`
operands of its nodes, register updates, effects, obligations and exit (`SVal.reads`,
`SNode.reads`, `SEff.reads`, `Cond.reads`, `Exit.reads`). `Func.keeps F Ss r` holds when no `phi`
of `F` and no summary of `Ss` sets `r`. `LoopSeg.kept F L` lists, once each and in the order of
their first read, the registers the loop path and the path out read (`L.H`, `L.B`, `L.X`) that
the loop path `L.H :: L.B` keeps. `LoopSeg.kept_round`: a register of `LoopSeg.kept F L` that is
`v` at a valuation of `F` is `v` after every number of rounds. It is `Valuation.iterate_regs_keep`
(MojoProof/Sym/Inv.lean), the register lemma over `Valuation.roundWith`, with its two premises
read off the list.

*Memory facts.* `Summary.loadsIn rs S` holds when every effect of `S` is a load whose pointer has
its base in the registers `rs` (`SVal.baseIn`, MojoProof/Sym/Payload.lean: a register of `rs`, or
a `getelementptr` node based at one). `LoopSeg.loadsFrom F L rs` holds when the loop path keeps
each register of `rs` (`Func.keeps`) and each of its blocks passes `Summary.loadsIn rs`.
`Valuation.iterate_loads`: take a set of blocks `Q` and a property `P` of memories that logging a
read of a block of `Q` that is not an `atomicrmw`'s keeps (an access with `a.write = false`,
`a.atomic = none` and `Q a.ptr.block`; a load logs such an access). If the loop
passes `LoopSeg.loadsFrom F L rs`, the registers `rs` have values at `V` that name only blocks of
`Q`, and `P` holds at `V`'s memory, then `P` holds after every number of rounds. Instances:

- `Valuation.iterate_blocks` (`Q` every block): the memory's blocks and next block number stay
  (only the trace grows). So `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` stay (their `of_block`,
  with `Mem.blocks_keep`).
- `Valuation.iterate_elem` and `Valuation.iterate_only` (`Q = (· ≠ o)`): `Elem … o …` stays
  (`Elem.log_read`), and so does `Elem.Only o T` (`Elem.Only.log_other`).

*Oracle positions.* `pathOff S ps i` is the number of steps from the entry of the path `S :: ps`
to the entry of its block `i`. `Valuation.lastWith_off`: block `i`'s entry valuation, the last
block of the path's first `i + 1` blocks, has the path's step count plus `pathOff S ps i`.
`LoopSeg.stepAt L S E k j i` is the step count at block `i` of round `j` of `L` (block 0 is the
header), for a thread whose entry path `S :: E` starts at step count `k`: `k + (pathLen S E + 1)
+ j * (pathLen L.H L.B + 1) + pathOff L.H L.B i`. `LoopSeg.stepAt_k` says that this is the step
count of that block's entry valuation. A float node at offset `n` of its block reads the oracle at
that step count plus `n` (`SNode.fbin`'s step field). `LoopSeg.steps_k` gives the step counts of
the entry path, of `j` rounds and of the loop path's last block from the entry path's length,
the round's and the last block's offset, each a premise that `decide` proves on a concrete loop.

## Proof

`LoopSeg.kept_round`: a listed register passes `Func.keeps` for the loop path's summaries
(`List.mem_filter`), which are `Valuation.iterate_regs_keep`'s premises.

`Valuation.iterate_loads`: by induction on the round count, and within a round by induction on
the loop path. A block's memory is its effects' run (`SEff.apply` folded over the effects), or
the block's entry memory when they fault. Each load logs a read through its pointer's value,
whose block is one the base register names (`SVal.eval_baseIn`), so a block of `Q`. An edge keeps
the memory (`Valuation.intoWith`). The registers `rs` keep their values into the next block and
the next round (`Valuation.iterate_regs_keep`, with `Func.keeps` from `LoopSeg.loadsFrom`).

`Valuation.lastWith_off`: by induction on the path, with `Valuation.intoWith_k`.
`LoopSeg.stepAt_k`: `Valuation.roundWith_k` for the entry path and the rounds, then
`Valuation.lastWith_off` on the first `i` edges of the loop path. `LoopSeg.steps_k`:
`Valuation.roundWith_k` and `Valuation.lastWith_off` at `L.B.length`.

## Instances

MojoProofTest/LoopFacts.lean, on the naive kernel's `chainN` (`naiveL` after the entry path
`%6 → %45`):

- `naive_kept`: `LoopSeg.kept naive.fn_0 naiveL` is `%16`, `%26`, `%11`, `%37`, `%12`, `%40`.
  These are the bound `smax(K, 0)`, the row offset, the pointer to `A`, the column offset, the
  pointer to `B` and the cell's address (the registers `NaiveSound.naive.kept` states);
  `naive_kept_round` is `LoopSeg.kept_round` at them.
- `naive_loads`: the loop passes `LoopSeg.loadsFrom` with `%11` and `%12`. So at a head whose
  `%11` and `%12` point outside block `o`, the rounds keep `Elem` at `o` (`naive_elem`) and
  `Elem.Only o` (`naive_only`).
- `naive_blocks`: at a head whose `%11` and `%12` are pointers, the rounds keep the memory's
  blocks and next block number (`Valuation.iterate_blocks`), the premise of the buffers'
  `of_block`.
- `naive_steps`: the head of round `j` is at `k + 39 + 18 * j` and block 2 (the latch) at
  `k + 42 + 18 * j` (`LoopSeg.stepAt_k` with the entry path's length 38, the round's 17 and the
  latch's offset 3, each by `decide`). The latch's `fmul` and `fadd` (offsets 12 and 13) are at
  `k + 54 + 18 * j` and `k + 55 + 18 * j`, the steps whose oracle numbers `NaiveThread.oN` reads.

And on `cnt2`'s two loops (MojoProofTest/SymLoop.lean), which store: `cnt2_kept` (the bound `%10`
and the pointers `%11` and `%16`; the counters, set by `phi`s, are not kept), `cnt2_stores`
(`LoopSeg.loadsFrom` is false for the loop that stores) and `cnt2_steps` (`LoopSeg.steps_k`: 1
step for the entry block, 6 a round, 2 to the body).

# Design: the loop clause for a matmul thread (partly implemented)

This section is a design. Of its order of work, steps 2 and 3 are in the Lean sources ("Facts at a
loop's heads" above); steps 1 and 4 are not, and no statement of theirs is proved. It says what the
loop clause of `mojo_kernel` (docs/kernel.md, "The loop clause") must carry so that, with `mat`, the
command computes a matmul thread's chain from the loop's header and proves the thread's run, in
place of the chain and the run the user gives today, and which statements change.

## Today

- `mat paths chains` (docs/proofs/kernel.md, "The 2-D clause") takes the chains as a term
  (`[chainN]`, written by hand in MojoProofTest/NaiveThread.lean) and leaves the run `Hin` of a
  thread in bounds to the user.
- `mat paths chains inv` (docs/proofs/kernel.md, "`Hin` from an invariant" and "The heads of
  the rounds") also generates `n.runInv`, the run of a thread in bounds from its entry facts,
  `Elem`, `Elem.Only` and `LoopIterWith` (an invariant's three facts at the heads of the rounds,
  where `Mat.Head` holds) through `RetLsWith.of_iter`, with the edge by `mojo_obl` and `Mat.Head`
  at every head by mojo_inv and `Mat.Head.iterate`; `n.kept`, each register the loop keeps
  (`LoopSeg.kept`) at every head with its value at the loop head (`LoopSeg.kept_round`); and
  `n.sound_inv`, whose one premise is `LoopIterWith` at each thread's
  `Mat.Thread`. `Mat.Thread` (Sym/KernelMat.lean) is the structure of a thread's facts that
  step 1 below names `Mat.Thread` and `Mat.Facts`: one structure has both the thread's
  parameters and its facts. For the naive kernel, `NaiveIn.runIn` is `naive.runInv` at
  `head_in`, `round_in` and `exit_in` (8 lines), the last two by `mojo_obl` (`naive_rounds`,
  `naive_exit`) with `Mat.Head` and the registers the loop keeps (`naive.kept`) at the loop's
  heads; `thread_run` is then not used by it.
- The loop clause `loop h := pre inv trips post` computes the chain from the header and proves
  `n.entry`, `n.init`, `n.step` and `n.exit` at every valuation `V` of `pre`. Its four terms are
  closed terms over a valuation (`pre : Valuation → Prop`, `inv : Valuation → Nat → Valuation →
  Prop`, `trips : Valuation → Nat`, `post : Valuation → Mem → Prop`), and its default tactic
  evaluates one concrete launch.

The two do not combine, for three reasons.

1. `Hin`'s premises and its postcondition mention the binders of `Kernel.sound_mat`: the launch
   `L`, the thread `k`, the sizes `m`, `n`, `K`, the blocks `o`, `a`, `b`, the strides, the
   tensors `x` and `y`, the memory `m₀`, the cell width `w` and the bytes `bs`. A closed `pre`
   or `post` cannot name them.
2. The bytes `bs` are a binder of `Kernel.sound_mat`, so no run can show that a thread stores
   `bs k`. The clause must fix them as a function of the inputs, as `NaiveSpec.bytes` does.
3. The obligations hold only under facts that `Kernel.sound_mat` does not state: the strides
   and the element type the IR's address arithmetic and loads assume (naive's IR multiplies by
   768 and 50257 and loads `float`), `K` at most the input stride, and the `i32` products of the
   address arithmetic below `2 ^ 31` (`NaiveSpec.At.dims`).

## What the clause must carry

**The thread's parameters as one record.** A structure `Mat.Thread` with the launch, the thread,
the sizes, the blocks, the strides, the element type with its encoder and alignment, the
tensors, the memory `m₀`, the cell width and the oracle family. The clause's terms take it:

- `pre : Mat.Thread → Prop` in place of `Valuation → Prop`: the strides, the element type, `K`
  and the `i32` ranges;
- `inv : Mat.Thread → Nat → Valuation → Prop` in place of `Valuation → Nat → Valuation → Prop`:
  the loop-carried registers only (below);
- `trips : Mat.Thread → Nat` in place of `Valuation → Nat` (`max K 0` for naive);
- `bytes : Mat.Thread → Nat → Option (List MemByte)` in place of `post`: the postcondition is
  `Hin`'s, `Elem` after `k + 1` threads and `Elem.Only`, at those bytes.

**The entry facts as one predicate.** `Mat.Facts θ c m' f`: the premises of `Hin` from
`c.prog = prog` to `Elem.Only`, with the thread's entry valuation `Valuation.entry c 0 m' f`.
`n.entry` and `n.init` are stated at every `θ` of `pre`, every `c`, `m'`, `f` of
`Mat.Facts θ`, at that valuation.

**The 2-D index facts.** On a 1-D launch the index of thread `k` is `k` (`Launch.index_oneDim`),
so the index needs no name of its own. On a 2-D launch the row and the column are
`L.index k .x` and `L.index k .y`, which no tactic simplifies, so the facts must name them as two
numbers `r` and `col` with:

- `r < m` and `col < n` (the thread is in the matrix: `Hin`'s window);
- `ctaid.d * ntid.d + tid.d` of `L.env k` equal to `r` for `d = .x` and to `col` for `d = .y`
  (the definition of `Launch.index`), each special register below its bound and the sums below
  `2 ^ 42` (`Launch.sreg_lt`, `Launch.index_lt`), so the IR's `zext`, `sext`, `mul` and `add`
  of them give the words of the natural numbers (`Launch.index_ops`);
- side 1 in `z` (`hz`), so that no `z` register enters the index.

These are the hypotheses `OblMatmul.naive_entry` takes, and `mojo_obl` proves the entry path's
obligations from them at every launch.

**The heads' facts, computed.** Besides the loop-carried registers, the facts at the loop's heads
are mostly facts the checker computes ("Facts at a loop's heads" above). The `mat … inv` clause
now proves the first two kinds below at every head: the registers the loop keeps
(`naive.kept`, by `LoopSeg.kept_round`) and the memory facts with the function (`Mat.Head`, by
`Mat.Head.iterate` at `LoopSeg.bases`; docs/proofs/kernel.md, "The heads of the rounds"):

- *registers the loop keeps*: `LoopSeg.kept` and `LoopSeg.kept_round`. For naive these are `%11`,
  `%12` (the input pointers), `%16` (`smax(K, 0)`), `%26`, `%37` (row and column times the stride)
  and `%40` (the cell's address);
- *the memory facts*: `LoopSeg.loadsFrom` and `Valuation.iterate_loads`, with
  `Valuation.iterate_elem` and `Valuation.iterate_only` for `Elem` and `Elem.Only` at `o` and
  `Valuation.iterate_blocks` for `Buffer`, `Fits` and `Holds`. For naive the bases are `%11` and
  `%12`, at `a` and `b`;
- *the oracle positions*: `LoopSeg.stepAt` and `LoopSeg.stepAt_k`. The oracle numbers of each
  round's `fmul` and `fadd` (`NaiveThread.oN`) are `LoopSeg.stepAt` of the latch plus the nodes'
  offsets 12 and 13. `NaiveThread.steps` is an instance of `LoopSeg.steps_k`.

The generated invariant at round `j` is then the user's `inv θ j W` together with these three,
and the user writes only the loop-carried registers (for naive, `NaiveThread.Inv`: `%47 = j` and
`%48` the `dotLoop` of the first `j` pairs).

## Which statements change

- `Kernel.sound_mat`, `LoopChain`, `coversChainsWith`, `RetLsWith`, `NaiveThread.thread_run`,
  `thread_skip`, `NaiveSpec.At` and `naive_sound` keep their statements. The new run is an
  instance of `Hin`'s shape, so `Kernel.sound_mat` takes it as it is.
- The loop clause without `mat` keeps its four terms and its obligations.
- New with `mat` and a loop clause: `n.chains` and `n.coversChains` (as for the loop clause; for
  naive a test that `n.chains = [chainN]`), the obligations `n.entry`, `n.init`, `n.step` and
  `n.exit` over `θ` and `Mat.Facts θ`, and `n.loop`, the run of a thread in bounds at every `θ`
  of `pre`: `Hin`'s body with `bs := bytes θ`.
- New theorem `n.sound_matLoop`: `n.sound_mat` without `Hin`, with the premise `pre θ` and the
  bytes fixed to `bytes θ`. `n.sound_mat` stays, so a kernel whose run the clause does not prove
  keeps the hand proof, and no generated statement changes.
- For naive, `NaiveIn`'s four theorems would be the instances of `n.entry`, `n.init`, `n.step`
  and `n.exit`, and `NaiveIn.runIn` a corollary of `n.loop`; `Mat.Head` and `naive.kept`, which
  the `mat … inv` clause now generates, would be the generated part of the invariant, with
  `NaiveThread.Inv`.

## What the tactic must still do

The default tactic must be `mojo_obl`, which proves `OblMatmul`'s obligations at every launch,
not `decide +kernel`, which evaluates one. The accumulator's step (`floatBin_dotStep` and
`dotLoop` of `ps.take (j + 1)`, NaiveIn's `round_in`) and the stored bytes at the exit stay
kernel-specific and are the clause's tactic.

## Order of the work

1. `Mat.Thread` and `Mat.Facts`, and `Kernel.sound_mat`'s premise `Hin` over them, as a
   corollary of `Kernel.sound_mat`.
2. Done: the register list and lemma (`LoopSeg.kept`, `LoopSeg.kept_round`), and the load-only
   check with the memory lemma (`LoopSeg.loadsFrom`, `Valuation.iterate_loads`).
3. Done: the oracle positions (`pathOff`, `Valuation.lastWith_off`, `LoopSeg.stepAt`,
   `LoopSeg.stepAt_k`, `LoopSeg.steps_k`).
4. The clause in `elabMat`, and naive as its instance with the twins of the loop clause's tests
   (a tactic that leaves an obligation, a wrong header).
