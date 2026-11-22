# `fmul contract` in the block checker (`coversC`, `Block.soundC`)

Lean: `MojoProof/Sym/Term.lean` (the node `SNode.fbinP`), `MojoProof/Sym/Checker.lean` (the
checker `coversC`) and `MojoProof/Sym/Block.lean` (the proof). Tests:
`MojoProofTest/SymContract.lean`, on the naive matmul kernel's latch.

**Scope.** Every program, function, block, entry position, condition list and summary that
`coversC` accepts, every context of the program and every thread whose innermost frame runs the
function at the block's position, with any memory and caller frames, whenever the conditions hold
at the entry valuation. One block; the paths and loops of MojoProof/Sym/Block.lean and
MojoProof/Sym/Loop.lean are not generalized (see "Not done").

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
- `Block.sound`, unchanged, through `Block.sound_withC` with `contract = false`, then
  `Ends.of_C`: with `contract = false` no node of the summary has factors (`SState.stmt_factors`,
  `SState.run_factors`, `summarizeWith_factors`), so `regProdIn` is `regProd`.

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

D. `SState.run_ptrs`, `SState.run_sound` and `Block.sound_withC` are the earlier proofs with the
flag passed through; `Block.sound_with` is `Block.sound_withC` with `contract = false`, then
`Ends.of_C`.

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

MojoProof/Sym/Block.lean, for every program, path and thread:

- `Valuation.afterC` and `Valuation.intoC` are `Valuation.after` and `Valuation.into` with the
  products of the table (`regProdIn`).
- `Ends.edgeC` is `Ends.edge` on `EndsC`: the branch's step enters the next block with the
  entry valuation `Valuation.intoC`.
- Each of these is the `contract = true` instance of one declaration, and the old one is the
  `contract = false` instance, in one line. The pairs are `Valuation.afterWith`,
  `Valuation.intoWith`, `EndsWith`, `Ends.edgeWith` and `EndsWith.pre`, with the products
  `prodsWith contract` (`regProdIn` with `contract`, `regProd` without). `Ends.edge`'s proof is
  `Ends.edgeWith`'s, with the products replaced by `prodsWith contract`; `Exit.of_target` and
  `Valuation.into_k` are generalized in place the same way.
- `Block.sound_pathC`: a path that `coversPathI` accepts, then the block its last exit goes to,
  accepted by `coversC` from the position that exit enters it at. That block ends (`EndsC`)
  from `Valuation.into` of the path's last block (`Block.sound_pathI`, `Ends.edge`,
  `Block.soundC`).

Tests:

- `latch_edge` (MojoProofTest/SymContract.lean): the latch's branch enters `%46` after its two
  `phi`s at `Valuation.intoC` of the latch's valuation.
- `latch_afterC`: after the latch, `%65`'s products are the loads' values with
  `Valuation.afterC`, and none with `Valuation.after`.
- `trip1_covers`, `trip1_latch`, `trip1_round` (MojoProofTest/SymNaive.lean): `%46 → %50` from
  position 2, then the latch by `coversC`, ends (`EndsC`), and the latch's branch enters `%46`
  again after its `phi`s, at `Valuation.intoC`: one trip of the loop, from the head to the head.
  `coversPathI` refuses `%46 → %50 → %52`.

## Not done

The path checker with `phi`s (`coversPathI`, `WalkI`, `Valuation.lastI`) and the loop theorems
(`LoopChain`, `Chain`, `Runs.of_chains`, MojoProof/Sym/Loop.lean) still check every block with
`covers` and enter it with `Valuation.into`. A block with `fmul contract` can be the last block of
a path (`Block.sound_pathC`), but not an inner block, and not a block of a loop's round. So the
naive kernel's loop `%46 → %50 → %52 → %46` has no `LoopChain`: `coversPathI` refuses the round's
path (`trip1_covers`), and `trip1_round` is one trip only, with its premises assumed.

These definitions are recursive, so their `contract` versions are not definitionally the old ones.
Keeping the old statements as one-line instances needs one of two things:

- an equivalence theorem for each definition, which the audit's `equivalences` count reports;
- or the old definitions restated as the instances. That changes the equations that
  MojoProof/Sym/Kernel.lean and MojoProof/Sym/Payload.lean rewrite with.
