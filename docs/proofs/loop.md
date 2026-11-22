# Loops by induction on the trip count (`Block.sound_loop`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean`.

**Scope.** Every program `P`, function `fn`, loop path `(h, ds, S) :: B` (the header `h` from
position `p`, after its `phi`s, through the body to the latch) that `coversPathI` accepts from `p`,
every trip count `n`, every context of `P` and every thread whose innermost frame runs `fn` at
block `h`'s position `p`.

## Statement

`Valuation.round h S B V` is the valuation at the header after one round from header valuation
`V`: `Valuation.into` of the latch from its entry valuation (`Valuation.lastI`).
`Round h p ds S B V` is the premise of one round: `WalkI V ((h, ds, S) :: B)`, the latch's exit
goes to `h` (`Exit.dest`), and enters it at position `p` (`Exit.pc`). `Round` is decidable
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
- round `i`'s premises are a path's (`WalkI`), so `Block.sound_pathI` runs the path to the
  latch's end (`Ends`, from `lastI`), and `lastI` keeps the context and the function
  (`Valuation.lastI_k`);
- the latch's exit goes to `h` (`Exit.dest`), so `Ends.edge` takes the branch, into a frame of
  `fn` at `h`'s position `Exit.pc`, which `Round` says is `p`;
- the entry valuation there is `round` of the `i`-th iterate, the `(i + 1)`-th
  (`Function.iterate_succ_apply'`).

The first two steps are `Block.sound_edge`; `Steps.trans_step` composes the steps.

## Dependencies

`Block.sound_rounds`, `Block.sound_edge` (MojoProof/Sym/Loop.lean);
`Block.sound_pathI`, `Ends.edge`, `Valuation.lastI_k`, `Steps.trans_step`
(MojoProof/Sym/Block.lean); `Function.iterate_succ_apply'` (Mathlib);
`succs` (MojoProof/Sym/Info.lean) for `backEdges`.

## Instances

See the end of this document: the instances are `cnt_retL`, `cnt_run` and `cnt_run_outC`,
through `Runs.of_loop` and `Runs.of_loops`.

# Loops from an invariant (`Round.of_inv`, `Block.sound_loop_inv`, `Runs.of_loops`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean`.

**Scope.** Every program `P`, function `fn`, entry path, loop path and exit path that `coversPathI`
accepts, every trip count `n`, every invariant `I : Nat → Valuation → Prop` (indexed by the round
number; an invariant `J` that does not depend on the round is `fun _ => J`), every predicate `Q`
on memories, every context of `P`, and every thread with one frame of `fn`.

## Statement

1. `Round.of_inv`. Suppose `I 0 V` holds. Suppose also that for every `i < n` and every valuation
   `W`, `I i W` gives both `Round h p ds S B W` and `I (i + 1) (Valuation.round h S B W)`. Then
   `Round` holds at `round^[i] V` for every `i < n`, and `I n (round^[n] V)` holds. These are the
   premises of every round for trip count `n`, from the invariant alone.
2. `Block.sound_edge` is `Block.sound_pathI` followed by the last block's edge. Take a path
   `(l, ds, S) :: ps` that `coversPathI` accepts from `p0`, and a thread whose innermost frame `f`
   (above `rest`) is at block `l`'s position `p0`. Suppose the path's premises hold (`WalkI`) and
   the last block's exit goes to `d` (`Exit.dest`). Then the thread's steps reach a frame `f'`
   above `rest` with these properties:
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
   position `L.p` (after its `phi`s). `L.covers P fn p0` says `coversPathI` accepts the three, the
   entry path from `p0`. `Ret W Q ps` says a path runs from `W` to `ret` with a memory of `Q`:
   its premises (`WalkI`), a last exit `ret`, and a memory `me` of `Q` that the last block's
   effects make. `RetL V Q L` is the premise of the whole run from `V`:
   - **Entry.** The entry path's premises hold from `V` (`WalkI`), and its last exit goes to `L.h`
     (`Exit.dest`) at position `L.p` (`Exit.pc`).
   - **Loop.** For some invariant `I` and trip count `n`: `I 0` holds at the header's entry
     valuation `Valuation.round L.l L.S L.E V`, and every round `i < n` from a valuation of
     `I i` goes back to the header with `I (i + 1)` after it. For a loop with no nested loop
     (`L.inner = []`) that is equivalent to `Round` of the loop path and `I (i + 1)` at
     `Valuation.round`, as in (1). With nested loops the round runs through them (`Chain`, in
     the last section).
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
2. `Block.sound_loop` and `Chain.reach` use it for each round and each edge into a header.
   - `Block.sound_pathI` gives `Ends` at the last block's entry valuation (`Valuation.lastI`).
   - `Valuation.lastI_k` says that valuation has `f`'s context and function.
   - `Ends.edge` takes the branch: a step into `d` at position `Exit.pc V.fn d`, with entry
     valuation `Valuation.into`. That is `Valuation.round l S ps V` by definition.
   - `Steps.trans_step` adds the branch step to the path's steps.
3. (1) gives `Block.sound_loop`'s premise. Its conclusion's entry valuation is `round^[n]` of the
   first, which (1) says satisfies `I n`.
4. `Runs.of_loop` is `Runs.of_chain` of the one loop (the last section), whose proof composes
   three parts:
   - `Block.sound_edge` on the entry path, with `rest = []`, reaches a frame at `h`'s position
     `Exit.pc fn h`, which is `p`. Its entry valuation is `Valuation.round l S E` of `f`'s, so
     `I 0` holds there.
   - `Block.sound_rounds` reaches `h`'s position `p` again, at a valuation of `I n`; with no
     nested loop each round is `Block.sound_edge` of the loop path.
   - The exit hypothesis there gives `WalkI` and `ret`. `Block.sound_retI` then gives the steps
     to the `ret` and its `.done` step on the memory the effects make, which is the memory of `Q`
     because `Except.ok` is injective.
   - The `alloca` blocks are still `f`'s (each part keeps them), and `Steps.trans` composes the
     three runs into `Runs`.
5. `Runs.of_loops` is `Runs.of_chains` (the last section) with the witness `L.chain`:
   `coversLoops` is `coversChains` of `loops.map LoopPaths.chain` (`List.mem_map_of_mem`).
   `coversChains` gives the chosen chain's start label and `coversChain` from position 0
   (`List.all_eq_true`); the start label is `f.label` because both are the label of `fn`'s first
   block. `Runs.of_chain` gives the run, and with `f.allocas = []` the cleanup is the identity.
6. Induction on `bs`. For `a :: bs` with `b ∉ a :: bs`, `b ≠ a`; `Mem.setLive a v` either sets
   block `a` (`Mem.set`, which changes only `a`) or leaves the memory unchanged. The load lemma
   rewrites `Mem.load`, `Mem.check`, `Mem.block` and `Mem.addr` with the block lemma.

Each round of `Block.sound_loop` is `Block.sound_edge` (the proof in the first section).

## Dependencies

- `Block.sound_rounds`, `Runs.of_chain`, `Runs.of_chains` (MojoProof/Sym/Loop.lean);
- `Block.sound_pathI`, `Block.sound_retI`, `Ends.edge`, `Valuation.lastI_k`, `Steps.trans`,
  `Steps.trans_step` (MojoProof/Sym/Block.lean);
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

# Loops in sequence and nested loops (`Chain`, `Chain.reach`, `Runs.of_chains`)

Lean: `MojoProof/Sym/Loop.lean`. Tests: `MojoProofTest/SymLoop.lean` (`cnt2_covers`,
`cnt2_retLs`, `cnt2_run`, `cnt2_twins`; `nest_covers`, `nest_rounds`, `nest_retLs`, `nest_run`,
`nest_twins`).

**Scope.** Every program `P`, function `fn`, list of loops `Ls` (each with the loops nested in its
rounds, to any depth), path before them, position `p0`, and predicate `F` on the last path (or
`Q` on memories), such that `coversChain` accepts the paths; for each loop, every trip count and
invariant; every context of `P` and every thread whose innermost frame runs `fn` (with one frame
for `Runs.of_chain`). The instances are two functions written in the test, `cnt2` (two loops in
sequence) and `nest` (two nested loops), each on one bound and one memory.

## Statement

Definitions (MojoProof/Sym/Loop.lean).

- `Edge h p V l ds S E`: the premises of the path `(l, ds, S) :: E` from `V` hold
  (`WalkI`), and its last block's exit goes to `h` (`Exit.dest`) at position `p` (`Exit.pc`).
  It is decided by evaluation (`Edge.dec`, :132).
- `Round h p ds S B V` is `Edge h p V h ds S B`: the loop path's last edge goes back into
  its own header (`Round.dec`, :147).
- `Back h p J V l ds S E`: `Edge h p V l ds S E` and `J (Valuation.round l S E V)`. This
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
  - with no loop, `coversChain` is `coversPathI P fn p0 ((l, ds, S) :: E)`;
  - with `L :: Ls`, it is that, `L.coversRound P fn`, and
    `coversChain P fn L.p L.h L.dh L.H L.X Ls`, so the path out takes the place of the path
    before for the next loop;
  - `L.coversRound P fn` is `coversChain P fn L.p L.h L.dh L.H L.B L.inner`: the loop path from
    the header's position, and the nested loops after it.

  `LoopPaths.covers P fn p0 L` is `coversChain P fn p0 L.l L.ds L.S L.E [L.toLoopSeg]`.
  These are Booleans that the kernel evaluates (`decide +kernel`).
- `Chain F Ls V l ds S E` is an inductive predicate. `F` is a predicate on a valuation
  and a path, and it holds of the last path. Its two constructors are these.
  - `Chain.last`: `F V l ds S E` gives `Chain F [] V l ds S E`.
  - `Chain.loop I n`, for an invariant `I : Nat → Valuation → Prop` and a trip count `n`. It
    gives `Chain F (L :: Ls) V l ds S E` from four premises:
    - `Edge L.h L.p V l ds S E`;
    - `I 0 (Valuation.round l S E V)`;
    - for every `i < n` and every `W` with `I i W`,
      `Chain (Back L.h L.p (I (i + 1))) L.inner W L.h L.dh L.H L.B`, so the round runs the loop
      path and the nested loops and goes back to the header with `I (i + 1)`;
    - for every `W` with `I n W`, `Chain F Ls W L.h L.dh L.H L.X`.
- `RetLs Q Ls V l ds S E` is `Chain` with `F V l ds S E := Ret V Q ((l, ds, S) :: E)`:
  the last path runs to `ret` with a memory of `Q`. `RetL V Q L` is
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
   `Block.sound_loop`, and it runs the nested loops in `Chain.reach`.
2. `Chain.reach`. Take `hP : c.prog = P`, `Chain F Ls V l ds S E` and
   `coversChain P fn p0 l ds S E Ls = true`. Take a thread `t` on memory `m` with
   `t.frames = f :: rest`, `f.fn = fn`, `f.label = l`, `f.pc = p0` and
   `Valuation.entry c t.k m f = V`. Then `t`'s steps reach a thread `t'` on memory `m'` and a
   last path `(l', ds', S') :: E'`, such that:
   - `t'.frames = f' :: rest`, with `f'.fn = fn`, `f'.label = l'` and `f'.pc = p'`;
   - `f'.allocas = f.allocas` and `f'.dest = f.dest`;
   - `coversPathI P fn p' ((l', ds', S') :: E') = true`;
   - `F (Valuation.entry c t'.k m' f') l' ds' S' E'`.
3. `Runs.of_chain`. Take `hP`, a list `Ls`, and `coversChain P fn p0 l ds S E Ls = true`.
   Take a thread `t` with `t.frames = [f]`, `f.fn = fn`, `f.label = l`, `f.pc = p0` and
   `RetLs Q Ls (Valuation.entry c t.k m f) l ds S E`. Then
   `∃ me, Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) me) ∧ Q me`.
   `Runs.of_loop` is `Runs.of_chain hP [L.toLoopSeg]`.
4. `Runs.of_chains` takes `Runs.of_loops`'s premises, with `coversChains P fn Cs = true`
   and `∃ C ∈ Cs, RetLs Q C.loops (Valuation.entry c t.k m f) C.l C.ds C.S C.E` in place of
   theirs. It concludes `∃ m', Runs c t m m' ∧ Q m'`. `Runs.of_loops` is
   `Runs.of_chains` with the witness `L.chain`.
5. `Chain.of_iter` holds for every `F`, loop `L`, loops `Ls`, path `(l, ds, S) :: E`,
   valuation `V`, function `g` on valuations and trip count `n`. Write
   `V₀ = Valuation.round l S E V` for the header's entry valuation. Suppose these hold:
   - `Edge L.h L.p V l ds S E`;
   - `Chain (Back L.h L.p (· = g (g^[i] V₀))) L.inner (g^[i] V₀) L.h L.dh L.H L.B` for every
     `i < n`;
   - `Chain F Ls (g^[n] V₀) L.h L.dh L.H L.X`.

   Then `Chain F (L :: Ls) V l ds S E` holds. The invariant is "`W` is the `i`-th iterate of
   `g`". With nested loops the round function `g` is not `Valuation.round` of the loop path.
6. `Chain.of_rounds` is for a loop with no nested loop (`L.inner = []`). Suppose that
   `Edge L.h L.p V l ds S E` holds and that, for every `i < n`, `Round L.h L.p L.dh L.H L.B`
   holds at `(Valuation.round L.h L.H L.B)^[i] (Valuation.round l S E V)`. Suppose also that
   `Chain F Ls` holds at the `n`-th iterate after `L`'s path out. Then
   `Chain F (L :: Ls) V l ds S E`. On a concrete valuation and `n`, the first two premises are
   closed and decidable (`Edge.dec`, `Round.dec`).

## Proof

1. Induction on `n`. For `0` there is no step. For `n + 1`, the induction hypothesis (with the
   premises for `i < n`) reaches the header with `I n`. The premise at `n` then reaches it again
   with `I (n + 1)`. `Steps.trans` composes the steps, and each part keeps the `alloca` blocks
   and the caller's register.
2. Induction on `Chain`, for every position, thread, memory and frame.
   - `Chain.last`: there is no step. `coversChain` of no loop is `coversPathI` of the path.
   - `Chain.loop`: `coversChain` splits into the path, `L.coversRound` and the rest.
     `L.coversRound` is `coversChain` of the round's paths, by cases on `L`.
     - `Block.sound_edge` enters `L`'s header at `L.p`, with `I 0`.
     - `Block.sound_rounds` runs the `n` rounds. Each round is the induction hypothesis on the
       round's `Chain`, which reaches its last path. There `Back` gives that path's premises,
       its edge to `L.h` at `L.p` and `I (i + 1)`, and `Block.sound_edge` takes that edge.
     - The induction hypothesis on the path out, at a valuation of `I n`, reaches the last path.

     `Steps.trans` composes the runs.
3. `Chain.reach` reaches the last path, where `Ret` gives `WalkI` and `ret`. `Block.sound_retI`
   gives the steps and the `.done` step. `Except.ok.inj` matches the memory, and the `alloca`
   blocks are `f`'s.
4. `coversChains` gives the chosen chain's start label and `coversChain` from 0
   (`List.all_eq_true`). The start label is `f.label`, because both are the label of `fn`'s first
   block. With `f.allocas = []` the cleanup is the identity. For `Runs.of_loops`, `coversLoops`
   is `coversChains` of the map, and `List.mem_map_of_mem` gives the witness.
5. `Chain.loop` with `I i W := W = g^[i] V₀`. `I 0` is `rfl`. A round from the `i`-th iterate
   ends with the `(i + 1)`-th (`Function.iterate_succ_apply'`). `I n W` is `W = g^[n] V₀`.
6. `Chain.of_iter` with `g := Valuation.round L.h L.H L.B`. With no nested loop, a round's
   `Chain` is `Chain.last` of `Back`: the `Round` premise and `rfl`.

## Dependencies

`Block.sound_edge`, `Block.sound_retI`, `Steps.trans`, `Ret`, `Valuation.round`,
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
  and `%p` and `%s` at the two 16-byte blocks of `out3`. It uses `Chain.of_rounds` with trip
  count 2 twice, then `Chain.last`. Its premises are checked by `decide +kernel`, and so are the
  effects of the last block, which leave cells 0 and 1 of both blocks holding 0 and 1
  (`run_ok`, :644).
- `cnt2_run` is `Runs.of_chains` with those two. The thread `⟨[frame2], 0⟩` runs on
  `out3`'s memory to its end, and in the memory it leaves cells 0 and 1 of both blocks hold 0
  and 1.
- `cnt2_twins` has two parts.
  - The first loop alone, `RetLs Q [loop1] V 0 cntE.obls cntE []`, fails for every `Q` and
    `V`. The invariant holds at the trip count (by induction on the rounds, each `Chain.last`).
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
  - the outer loop by `Chain.of_iter`, with `outerT` and trip count 2;
  - each outer round by `Chain.of_rounds` on `loopJ`, with trip count 2 (`nest_rounds`);
  - the outer path out to `ret`, with the memory's cells, by `decide +kernel`.
- `nest_run` is `Runs.of_chains` with `nest_covers` and `nest_retLs`. The thread
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

The theorems cover every program and every chain of loops, in sequence and nested, that the
checker accepts. The first part of each twin covers every predicate, and for `cnt2_twins` every
valuation.

## Limits

- `cnt2_retLs` and `nest_retLs` are for `n = 2` on one memory, by evaluation. A proof for every
  bound needs each loop's invariant steps, as `invN_step` gives them for `cnt`.
- `Kernel.sound_of_paths` and `mojo_kernel` (MojoProof/Sym/Kernel.lean) still take loop-free
  paths.
