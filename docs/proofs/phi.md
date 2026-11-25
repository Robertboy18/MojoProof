# Phi entry along a path (`Block.sound_pathWith_ptrs`, `Ends.edge`)

Lean: `MojoProof/Sym/Checker.lean` (the checker) and `MojoProof/Sym/Path.lean` (the proof).
Tests: `MojoProofTest/SymPhi.lean`.

**Scope.** Every program, function, context, thread and path that the path checker
(`coversPathWith false`) accepts. An edge into a block that starts with `phi`s, from `br` or
`br i1`, is the exit `Exit.phi c d e` (a `br` is `.phi (.int 1 1) d d`); `SState.exitAt` gives
`SState.exit`'s exit when it has one, else `SState.phiExit`'s, whose obligations (`SState.phiConds`)
say that each `phi` of the target has an operand for the edge and that the operand evaluates.
Operands are registers, integer constants and float constants. A float constant is a node of the
block's table, `SNode.flit ft lit`, which `summarizeWith` puts there before the first statement
(`SState.start`: one node per float constant among the statements' operands and the `phi` operands
of the block's edges, `litNodes`); its value is the semantics' `floatLit ft lit` (`vals_flit`), so
the checker does not evaluate the literal, and the obligation that it evaluates is decided on a
concrete valuation like any other (`floatLit` of a decimal literal reads its digits, 0-9 only, with
`digits`, which the kernel reduces, so `decide +kernel` decides that obligation: `SymNaive.pre_edge`
does for `%45`'s `0.0`).

## Statement

`Block.sound_pathWith_ptrs` at `contract := false` (the flag is the `fmul contract` one,
contract.md). Hypotheses: `coversPathWith false P fn p0 ((l, ds, S) :: ps) = true`; `c.prog = P`;
the thread's innermost frame `f` is at block `l`, position `p0`, of `fn`;
`WalkWith false (Valuation.entry c t.k m f) ((l, ds, S) :: ps)`: each block's conditions hold at
its entry valuation, each exit but the last goes (`Exit.dest`) to the next block, and the next
block's entry valuation is `Valuation.into` of the one before. `Valuation.into` is
`Valuation.after` for exits with a target; for `Exit.phi` it takes the registers and
`fmul contract` operands of the frame `enter` gives from `Valuation.frameAt`.

Conclusion: `Ends c t m f rest ((Valuation.entry c t.k m f).lastWith false l S ps)` (`Ends` is
`EndsWith false`): the thread's steps reach the last block's end from its entry valuation
(`Valuation.lastWith false`), with the step count `t.k + pathLen S ps` (`Valuation.lastWith_k`,
which also says that `lastWith` keeps the context and the function); with the pointer facts of
every block (ptrs.md). `Block.sound_retWith`: for a thread whose last block returns, the next step
is the `ret`'s, on the memory the last block's effects make: `.done` for a one-frame thread
(`rest = []`).

## Proof

A (`Frame.set_with`, `Frame.foldl_with`, `enter_congr`, `enter_fields`). `enter s f d` reads only `s`,
`f.fn`, `f.label`, `f.regs` and `f.prods`; on a frame `g` that agrees with `f` on those it gives
`f`'s result with `g`'s `alloca` blocks and caller's register. `Frame.set` changes the registers and
operands only, as a function of the frame's, and so does a fold of it (induction on the list).
`enter` keeps `fn`, `allocas` and `dest`, and gives `label := d`, `pc := phiCount fn d`.

B (`mapM_ok`, `SState.enter_ok`). If `phiConds fi.fn fi.label d = some cs` and every condition holds,
`enter` does not fault: each `phi`'s metadata passed `checkMd`, its operand for `fi.label` exists, and
its value is the operand's symbolic value's (`SState.op_eval` under `Rel`), which the condition says
is `.ok`; `mapM` in `Except` succeeds where `mapM` in `Option` gave results that make each step
succeed.

C (`SState.exitAt_sound`). `exitAt` is `exit` (then `SState.exit_sound`) or `phiExit`: the condition
evaluates as for `.cond`; `step` on `br d` and `br i1` calls `enter` on the same scope and frame as
`Exit.next`'s `.phi` case, which succeeds by B. So `Block.sound` holds with `exitAt`.

D (`Ends.edge`). From `Ends` at `(V, l, S)` with `Exit.dest = some d`, the exit's step continues the
thread. For `.br` and `.cond`, `Exit.next_target` gives the frame `{fe with label := d, pc := 0}`,
whose entry valuation is `V.after S = V.into l S` (`Exit.of_targetWith`). For `.phi`, the step is
`.next` of the frame `enter` gives on `fe`; `fe` agrees with `V.frameAt l S` on `fn`, `label`,
`regs` and `prods` (from `Ends`), and the scope's memory is `(V.after S).mem` (the effects' run), so
by A both `enter`s give the same registers and operands: the entry valuation is `V.into l S`, at
position `phiCount fn d`, which is `Exit.pc`.

E (`Block.sound_pathWith_ptrs`). Induction on `ps`: `Block.sound` on the first block (position
`p0`), D on its exit (`Ends.edgeWith`), the induction hypothesis from the new frame (position
`S.exit.pc fn l'`, the position `coversPathWith` checked), then `EndsWith.pre`.

F (one form). A path without `phi`s has no checker or premises of its own: it is the case of
`coversPathWith false` and `WalkWith false` whose exits have targets (`.br` or `.cond`), where
`dest = target`, `Valuation.into` is `Valuation.after` (`Exit.of_targetWith`) and `Exit.pc` is 0.

## Dependencies

`Block.sound`, `SState.exit_sound`, `SState.op_eval`, `Exit.next_target`, `EndsWith.pre`, `enter`
(MojoProof/Sem/Thread.lean).

## Instances

MojoProofTest/SymPhi.lean, on the naive matmul kernel (one program, one path, one context, memory
and frame): the path `%46 → %51 → %67 → %69` of a thread whose loop runs no trip, whose edge
`%51 → %67` sets `%68 = %48`; `trip0_cell` reads the stored value 1. `pre_covers`: the preheader
`%45`, whose edge passes the float constant `0.0` to `%48`, has that constant as node 0, and the
path `%45 → %46 → %51 → %67 → %69` is accepted (its premises are not decided: the literal is
decimal). Twins: `%45`'s certificate without node 0's obligation is refused, an edge without a
`phi` operand is refused, the path premises fail with bound 1, and the block checker refuses
`%67` from position 0, before its `phi`. MojoProofTest/SymLoop.lean's
`cnt_covers`'s entry path accepts an integer constant operand.

## Limits

`covers` requires both edges' obligations of a `br i1` into blocks with `phi`s; `coversTo`
(edge.md) requires only the taken edge's. Phi operands are registers, integer constants and float
constants; globals, `undef`, `poison` and constant expressions are refused.
