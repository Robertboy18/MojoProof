# Phi entry along a path (`Block.sound_pathI`, `Ends.edge`)

Lean: `MojoProof/Sym/Checker.lean` (the checker) and `MojoProof/Sym/Block.lean` (the proof).
Tests: `MojoProofTest/SymPhi.lean`.

**Scope.** Every program, function, context, thread and path that the path checker with `phi` edges
(`coversPathI`) accepts. An edge into a block that starts with `phi`s, from `br` or `br i1`, is the
exit `Exit.phi c d e` (a `br` is `.phi (.int 1 1) d d`); `SState.exitAt` gives `SState.exit`'s exit
when it has one, else `SState.phiExit`'s, whose obligations (`SState.phiConds`) say that each `phi`
of the target has an operand for the edge and that the operand evaluates. Operands are registers and
integer constants; float constants are refused, since the kernel does not reduce `floatLit`.

## Statement

Hypotheses: `coversPathI P fn p0 ((l, ds, S) :: ps) = true`; `c.prog = P`; the thread's innermost
frame `f` is at block `l`, position `p0`, of `fn`; `WalkI (Valuation.entry c t.k m f) ((l, ds, S) ::
ps)`: each block's conditions hold at its entry valuation, each exit but the last goes (`Exit.dest`)
to the next block, and the next block's entry valuation is `Valuation.into` of the one before.
`Valuation.into` is `Valuation.after` for exits with a target; for `Exit.phi` it takes the registers
and `fmul contract` operands of the frame `enter` gives from `Valuation.frameAt`.

Conclusion: `Ends c t m f rest ((Valuation.entry c t.k m f).lastI l S ps)`: the thread's steps reach
the last block's end from its entry valuation (`Valuation.lastI`), with the step count
`t.k + pathLen S ps` (`Valuation.lastI_k`, which also says that `lastI` keeps the context and the
function). `Block.sound_retI`: for a one-frame thread whose last block returns, the next step is
`.done`, on the memory the last block's effects make.

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
whose entry valuation is `V.after S = V.into l S` (`Exit.of_target`). For `.phi`, the step is
`.next` of the frame `enter` gives on `fe`; `fe` agrees with `V.frameAt l S` on `fn`, `label`,
`regs` and `prods` (from `Ends`), and the scope's memory is `(V.after S).mem` (the effects' run), so
by A both `enter`s give the same registers and operands: the entry valuation is `V.into l S`, at
position `phiCount fn d`, which is `Exit.pc`.

E (`Block.sound_pathI`). Induction on `ps`: `Block.sound` on the first block (position `p0`), D on
its exit, the induction hypothesis from the new frame (position `S.exit.pc fn l'`, the position
`coversPathI` checked), then `Ends.pre`.

F (frozen forms, `Walk.toI`). Under `Walk`, every exit before the last has `Exit.target = some _`,
so it is `.br` or `.cond`; there `dest = target`, `into = after` and `Exit.pc = 0`, so `Walk` and
`coversPath` give `WalkI` and `coversPathI`, and `lastI = last`. `Block.sound_path` and
`Block.sound_ret` are corollaries of `Block.sound_pathI` and `Block.sound_retI`.

## Dependencies

`Block.sound`, `SState.exit_sound`, `SState.op_eval`, `Exit.next_target`, `Ends.pre`, `enter`
(MojoProof/Sem/Thread.lean).

## Instances

MojoProofTest/SymPhi.lean, on the naive matmul kernel (one program, one path, one context, memory
and frame): the path `%46 → %51 → %67 → %69` of a thread whose loop runs no trip, whose edge
`%51 → %67` sets `%68 = %48`; `trip0_cell` reads the stored value 1. Twins: the summary of `%45`
(a float constant `0.0` for `%48`) is refused, an edge without a `phi` operand is refused, the path
premises fail with bound 1, and the frozen checker refuses the path. MojoProofTest/SymLoop.lean's
`cnt_covers`'s entry path accepts an integer constant operand.

## Limits

`covers` requires both edges' obligations of a `br i1` into blocks with `phi`s; `coversTo`
(edge.md) requires only the taken edge's. Phi operands are registers and integer constants; float
constants, globals, `undef`, `poison` and constant expressions are refused.
