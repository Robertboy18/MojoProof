# `fmul contract` in the block checker (`coversC`, `Block.soundC`)

Lean: `MojoProof/Sym/Term.lean` (the node `SNode.fbinP`), `MojoProof/Sym/Checker.lean` (the
checker `coversC`) and `MojoProof/Sym/Block.lean` (the proof). Tests:
`MojoProofTest/SymContract.lean`, on the naive matmul kernel's latch.

**Scope.** Every program, function, block, entry position, condition list and summary that
`coversC` accepts, every context of the program and every thread whose innermost frame runs the
function at the block's position, with any memory and caller frames, whenever the conditions hold
at the entry valuation. The same for paths and loops (MojoProof/Sym/Path.lean,
MojoProof/Sym/Loop.lean): every path and loop sequence that the checkers with a `contract` flag
accept, from every thread at its first block whose premises hold (see "Paths and loops with
`fmul contract`").

## Why `covers` refuses `fmul contract`

`exec` of `fmul contract` records the operands of the product in the frame
(`f.prods r = some (x, y)`), and a later `fadd contract` or `fsub contract` on register `r` reads
them (`floatBin` may fuse the two, by its oracle number). `Ends`, the conclusion of the frozen
`Block.sound`, says that the frame's products at the block's end are `regProd V S.regs`, which is
`none` for every register the block sets; and the frozen `.fbin` case of `SNode.eval` reads a
product only from an entry register (`SVal.prods`), `none` for a node. Both are false after an
`fmul contract` whose register the block sets, so `covers` keeps refusing it, and the new checker
is a second instance of the same functions.

## Statement

Definitions.

- `SNode.factors nd`: the operand terms of `nd` when it is an `fmul contract` (an `.fbin` or
  `.fbinP` node with `op = .fmul` and `fm.contract`), else `none`. `SVal.factors ns x`: those of
  node `x` of table `ns` (`none` for registers and constants).
- `prodVal V vs (p, q)`: the pair of the terms' values when both evaluate.
  `SVal.prodsWith V vs x o`: `x.prods V` when `o = none` (an entry register's products, as the
  frozen `.fbin` case reads them), else `prodVal` of the terms.
- `SNode.fbinP op fm ft n a b pa pb`: the float operator of `.fbin` whose operands' products are
  `a.prodsWith V vs pa` and `b.prodsWith V vs pb`. `SNode.fbinOf` is `.fbin` when both are `none`,
  else `.fbinP`.
- `regProdIn V vs ns regs r`: register `r`'s products given the table `ns`: for a register the
  block sets, `prodVal` of its entry's factors (`SVal.factors`); an entry register's own
  otherwise. It is `regProd V regs r` when no node of `ns` is an `fmul contract`
  (`Ends.of_C`).
- `SState.stmt`'s parameter `contract` (default `false`): with `contract`, `fmul contract` is in
  the fragment; the float case appends `SNode.fbinOf` of the operands' factors. `SState.run`,
  `summarizeWith` and `coversWith` pass the flag through, with `false` by default, so `summarize`,
  `covers` and `coversTo` compute what they did (with `contract = false` no node has factors, so
  `fbinOf` is `.fbin`).
- `summarizeC`, `coversC`: `summarize` and `covers` with `contract = true`.
- `EndsC`: `Ends` with the products `regProdIn`.

Theorems.

- `Block.soundC`: `coversC P fn lbl p0 ds S = true`, `c.prog = P`, a thread at the block's position,
  and the conditions of `ds` at the entry valuation give `EndsC` there.
- `Block.sound`, unchanged, through `Block.soundAt` with `contract = false`, then `Ends.of_C`:
  with `contract = false` no node of the summary has factors (`SState.stmt_factors`,
  `SState.run_factors`, `summarizeAt_factors`), so `regProdIn` is `regProd`.

## Proof

A (`Rel`). The relation between the symbolic state and the frame says that the frame's products are
`regProdIn V vs σ.nodes σ.regs` (`Rel.prods`, on the values `vs` of the final table), and that the
factors of the table's nodes refer to nodes of the table (`Rel.fwf`). `Rel.defP` appends a node
`nd` and sets the frame's register with products `pr`, when `nd`'s factors refer to nodes of the
table and evaluate to `pr` (`prodVal`). `Rel.def` is its instance for a node without factors
(`pr = none`).

B (`exec_fbinC`). `exec` of any float operator: the result is `floatBin` lane by lane with the
operands' recorded products, and the register's products are the operands' values when the
statement is `fmul contract`. `exec_fbin` is its instance for the other operators.

C (`SState.stmt_sound`). In the float case an operand's products in the frame are
`x.prodsWith V (vals V σ.nodes) (x.factors σ.nodes)` (A at the operand's register: the factors
refer to nodes before the new one, by `Rel.fwf`, so their values on the final table are those on
the table before the node), which is what `fbinOf`'s value reads (`SNode.eval_fbinOf`). For
`fmul contract` the node's factors are its operand terms (`SNode.factors_fbinOf`), whose values are
the operands', so `Rel.defP` applies with `exec`'s pair.

D. `SState.run_ptrs`, `SState.run_sound` and `Block.soundAt` are the earlier proofs with the
flag passed through; `Block.sound_withAt` is `Block.soundAt` with either flag, then `Ends.of_C`
when the flag is off.

## Tests

`MojoProofTest/SymContract.lean`, on the latch `%52` of the naive matmul kernel
(`%65 = fmul contract float %60, %64`, `%66 = fadd contract float %48, %65`):

- `latch_nodes`, `latch_covers`: `%65`'s node is the `fmul contract` of the two loads' nodes, and
  `%66`'s is an `fbinP` node whose second operand's products are those loads' nodes; `coversC`
  accepts the summary.
- `latch_refused`: `summarize` gives no summary of the latch, so `covers` refuses it.
- `latch_twins`: the summary with `%66`'s products dropped, with them swapped, or with `%65`'s
  `contract` flag cleared, is refused.
- `latch_prods`: `Block.soundC` on the latch: `%65`'s products at its end are the values of the
  loads' nodes, and `%66` has none.

## The edge and a path with `fmul contract`

MojoProof/Sym/Path.lean, for every program, path and thread:

- `Valuation.afterC` and `Valuation.intoC` are `Valuation.after` and `Valuation.into` with the
  products of the table (`regProdIn`).
- `Ends.edgeC` is `Ends.edge` on `EndsC`: the branch's step enters the next block with the
  entry valuation `Valuation.intoC`.
- Each of these is the `contract = true` instance of one declaration, and the old one is the
  `contract = false` instance, in one line. The pairs are `Valuation.afterWith`,
  `Valuation.intoWith`, `EndsWith`, `Ends.edgeWith` and `EndsWith.pre`, with the products
  `prodsWith contract` (`regProdIn` with `contract`, `regProd` without). `Ends.edge`'s proof is
  `Ends.edgeWith`'s, with the products replaced by `prodsWith contract`; `Exit.of_targetWith` and
  `Valuation.intoWith_k` take the flag the same way (`Valuation.into_k` is the latter's case
  without it).
- `Block.sound_pathC`: a path that `coversPathWith false` accepts, then the block its last exit
  goes to, accepted by `coversC` from the position that exit enters it at. That block ends
  (`EndsC`) from `Valuation.into` of the path's last block (`Block.sound_pathWith_ptrs`,
  `Ends.edge`, `Block.soundC`).

Tests:

- `latch_edge` (MojoProofTest/SymContract.lean): the latch's branch enters `%46` after its two
  `phi`s at `Valuation.intoC` of the latch's valuation.
- `latch_afterC`: after the latch, `%65`'s products are the loads' values with
  `Valuation.afterC`, and none with `Valuation.after`.
- `trip1_covers`, `trip1_latch`, `trip1_round` (MojoProofTest/SymNaive.lean): `%46 → %50` from
  position 2, then the latch by `coversC`, ends (`EndsC`), and the latch's branch enters `%46`
  again after its `phi`s, at `Valuation.intoC`: one trip of the loop, from the head to the head.
  `coversPathWith false` refuses `%46 → %50 → %52`.

## Paths and loops with `fmul contract`

MojoProof/Sym/Path.lean and MojoProof/Sym/Loop.lean, for every program, function, path, loop
sequence and thread. Each definition below takes a flag `contract` and checks every block with
`coversWith … contract`, or enters every block after the first with `Valuation.intoWith contract`.
The path's checker, premises and last valuation have no other form: where the flag is off they are
written `coversPathWith false`, `WalkWith false` and `Valuation.lastWith false`. The other
definitions' cases without the flag are named in parentheses below; each is defined as its `With`
form at `false`.

Definitions.

- `coversPathWith contract`: every block of the path accepted by `coversWith` with the flag,
  ending at `exitAt` or, for an inner block, at `exitTo` the next label.
- `WalkWith contract`, `Valuation.lastWith contract`, `Valuation.blocksWith contract`: the path's
  premises, its last block's valuation, and every block's valuation, each block after the first
  entered through `Valuation.intoWith contract`.
- `RetWith contract` (`Ret`): `WalkWith`, then the last block returns and its effects run to a
  memory meeting `Q`.
- `Valuation.roundWith`, `EdgeWith`, `RoundWith`, `BackWith` (`Valuation.round`, `Edge`, `Round`,
  `BackWith false`): the same over `WalkWith` and `lastWith`.
- `coversChainWith`, `LoopSeg.coversRoundWith`, `coversChainsWith` (`coversChain`,
  `LoopSeg.coversRound`, `coversChains`): over `coversPathWith`.
- `ChainWith contract`, `RetLsWith contract` (`RetLs`): over `EdgeWith`, `roundWith` and
  `BackWith`. Without the flag the inductive is `ChainWith false` itself, below.
- `LoopSeg` and `LoopChain` are data (labels, positions, condition lists and summaries) and take
  no flag: one value is checked with either.

Theorems, each proved once for both values of the flag.

- `Block.sound_withAt` (MojoProof/Sym/Block.lean) concludes `EndsAt contract`, which is
  `EndsWith contract` with the flag `alloca` off (`EndsAt.ends`), `Ends` without `contract` and
  `EndsC` with it (`Block.soundAt`, then `Ends.of_C` when the flag is off);
  `Block.sound_atWith` and `Block.sound_toWith` are its instances at `exitAt` and `exitTo`.
  `Block.sound_ptrs` and `Block.sound_to` are their `contract = false` instances and
  `Block.soundC` the `contract = true` one, one line each.
- `Valuation.lastWith_k`, `Block.sound_pathWith_ptrs`, `Block.sound_retWith`: by induction on
  the path, the flag passed through (`Ends.edgeWith`, `EndsWith.pre`).
- `Block.sound_edge`, `Block.sound_loop`, `Round.of_inv`, `Block.sound_loop_inv`: generalized in
  place, with `{contract : Bool}`; all but `Round.of_inv` also with `{alloca : Bool}`
  (docs/proofs/loop.md).
- `ChainWith.reach`, `ChainWith.of_iter`, `ChainWith.of_rounds`, `Runs.of_chainWith`,
  `Runs.of_chainsWith`, `Runs.of_retWith`: one statement each, for both values of the flag; the
  callers without the flag apply them at `false`.

The cases without the flag:

- `Valuation.round`, `Edge`, `Round`, `Ret`, `RetLs`, `coversChain`,
  `LoopSeg.coversRound` and `coversChains` are defined as their `With` form at `false`, so a
  statement about one is a statement about the other by unfolding, with no proof between them.
  The obligation commands match these names where the flag is off (the tactics' text and
  messages name them).
- There is no second inductive for the loops without the flag: a run through them is
  `ChainWith false`, built with `ChainWith.last` and `ChainWith.loop`, the end of a round is
  `BackWith false`, and `RetLs` is `RetLsWith false`. `Runs.of_loop`, `Runs.of_loops` and the
  kernel theorems without the flag (`Kernel.sound_of_chains`, `Kernel.sound_entry`,
  `Kernel.sound_cells`) are their `With` form at `false`, one line each.

Test (MojoProofTest/SymNaive.lean): the naive kernel's loop `%46 → %50 → %52`, as a `LoopSeg`
round (`naiveL`), is accepted by `LoopSeg.coversRoundWith true` and refused by
`LoopSeg.coversRound` (the latch's `fmul contract`; `naiveL_covers`). At one concrete thread at
`%46`'s position 2 (`frameL`: `%47 = 0`, `%48 = 0.0`, `%16 = 2`) and one memory (`mem0`), its
rounds' premises (`RoundWith true`) hold for two rounds, by `decide +kernel` (`loop_rounds`), so
`Block.sound_loop` with `contract = true` runs the thread through two rounds to `%46` again, at
the second iterate of `Valuation.roundWith true`, where `%47 = 2` and `%48 = 1.0` (`loop_regs`,
`loop_two`). This covers one thread, one memory and the trip count 2.

