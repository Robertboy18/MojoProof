# One edge of a `br i1` into blocks with `phi`s (`Block.sound_to`)

Lean: `MojoProof/Sym/Checker.lean` (the checker) and `MojoProof/Sym/Path.lean` (the proof).
Tests: `MojoProofTest/SymPhi.lean`, the section "A `br i1` into blocks with `phi`s, one edge at a
time".

**Scope.** Every program `P`, function `fn`, block `lbl`, entry position `p0`, target `d₀`,
condition list `ds` and summary `S` that `coversTo P fn lbl p0 d₀ ds S` accepts, every context of
`P` and every thread whose innermost frame runs `fn` at block `lbl`'s position `p0`, with any
memory, whenever the exit goes to `d₀`. Along a path: every path that `coversPathI` accepts, each
block but the last by `covers` or by `coversTo` for the edge into the next block.

**Why one edge.** `SState.phiExit` gives `br i1 c, d, e` into blocks with `phi`s the obligations
of both edges (`SState.phiConds fn lbl d ++ SState.phiConds fn lbl e`). A `phi` operand of the
untaken edge that is outside the fragment (an `undef`, say) makes `summarize` `none`, and
one that faults makes the block's premises fail, although the run never reads it.

## Statement

Definitions. `summarizeWith P fn lbl p0 ex` is `summarize`'s body with the exit and its
obligations from `ex σ b.term` (`ex : SState → Term → Option (Exit × List Cond)`); `coversWith` is
`covers`'s with `summarizeWith`. `summarize` and `covers` are their instances with
`ex := fun σ tm => σ.exitAt fn lbl tm`. `SState.phiExitTo fn lbl
d₀ σ` is `SState.phiExit` except on `br i1 c, d, e`: the exit `.phi x d e` with the obligations
`.bool x :: SState.phiConds fn lbl d₀` (the edge into `d₀` only); `SState.exitTo` is
`SState.exit`'s exit, else `SState.phiExitTo`'s; `coversTo P fn lbl p0 d₀ := coversWith P fn lbl p0
(fun σ tm => σ.exitTo fn lbl d₀ tm)`. `coversPathI`'s step `(l, ds, S) :: (l', ds', S') :: ps`
checks `covers P fn l p0 ds S || coversTo P fn l p0 l' ds S`.

1. `SState.exitTo_sound`: under `Rel` at the block's end (after its statements), if
   `σ.exitTo fe.fn fe.label d₀ b.term = some (x, cs)`, every condition of `cs` holds and
   `x.dest V vs = some d₀`, then `x.next V vs rest k fe me = .ok r` and the terminator's step is
   `.ok r`.
2. `Block.sound_with`: `Block.sound` for `coversWith` with any `ex` whose exit, at the block's end,
   is the terminator's step whenever its obligations hold (premise `hex`), and either value of
   the flag `contract`. It concludes `EndsWith contract ∧ Ptrs`, which is `Ends ∧ Ptrs` without
   the flag (docs/proofs/ptrs.md, docs/proofs/contract.md).
3. `Block.sound` is `Block.sound_with` with `SState.exitAt_sound` (`Block.sound_atWith`), through
   `Block.sound_ptrs` (`Ends ∧ Ptrs`).
4. `Block.sound_to`: `Block.sound` for `coversTo P fn lbl p0 d₀` (`Block.sound_toWith` without the
   flag), with the extra premise
   `S.exit.dest (Valuation.entry c t.k m f) (vals … S.nodes) = some d₀`; it concludes
   `Ends ∧ Ptrs`.
5. `Block.sound_pathI`, `Block.sound_retR` for the wider `coversPathI`; `Block.sound_pathI` is the
   first half of `Block.sound_pathI_ptrs`.

## Proof

1. If `SState.exit` gives the exit, `SState.exit_sound`. Otherwise `SState.phiExitTo`: on `br i1`
   the obligation `.bool x` gives the word `bv` and the condition's value (`SState.op_eval`); the
   premise `x.dest = some d₀` says `(if bv.getLsbD 0 then d else e) = d₀`, so the edge's
   obligations are those of the taken target, and `SState.enter_ok` gives `enter`'s frame; `step`
   and `Exit.next` both enter it. On other terminators `SState.phiExitTo` is `SState.phiExit`, so
   `SState.exitAt_sound`.
2. `Block.sound`'s proof with the call of `SState.exitAt_sound` replaced by `hex`.
3. and 4. `hex` from items 1 and `SState.exitAt_sound` (`Rel` gives `fe.fn = f.fn` and
   `fe.label = f.label`).
5. In `Block.sound_pathI`'s step the head block's `Ends` comes from `Block.sound` (through
   `Block.sound_ptrs`) or from `Block.sound_to` with the premise `Exit.dest = some l'` that `WalkI`
   already contains; the rest of the proof is unchanged. `Walk.toI` gives the left disjunct.

## Dependencies

`SState.exit_sound`, `SState.exitAt_sound`, `SState.op_eval`, `SState.enter_ok`, `Exit.dest`,
`Ends.edge`, `step` and `enter` (MojoProof/Sem/Thread.lean).

## Instances

MojoProofTest/SymPhi.lean, one program written in the test (`edgeF`, three blocks), one context
(`ctxE`), memory (`mem0`) and frame (`frameE true`): `entryTo` is the entry block's summary for the
edge into block 1, `edge_covers` accepts the path `0 → 1` (the entry block by `coversTo`),
`edge_walk` its premises, and `edge_run` (`Block.sound_retR`) runs the thread to block 1's `ret`.
`entry_both`: `summarize` accepts the entry block with both edges' obligations, block 2's float
constant 1.5 as its node 0 (`SNode.flit`), whose obligation holds at `frameE true`. Twins
(`edge_twins`): `coversTo` refuses the corrupted certificates `entryTo` without its first
obligation and with no obligations, the path `0 → 2` with `entryTo` is refused, and with `%3 = 0`
the premises fail.

## Limits

A path fixes the edge, so a `br i1` with both successors reached by different paths of a
certificate needs one path per edge. `phi` operands are registers, integer constants and float
constants only.
`Cond` has no implication (no constructor for it): the per-edge obligations
are the path's choice, not a condition under the branch.
