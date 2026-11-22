# A `ret` to a caller frame (`Block.sound_retR`, `Block.sound_back`)

Lean: `MojoProof/Sym/Block.lean`. Test: `MojoProofTest/SymPhi.lean`, the section "A `ret` to a caller
frame".

**Scope.** The results hold for every program `P` and function `fn`, and for every path
`(l, ds, S) :: ps` that `coversPathI P fn p0` accepts and whose last block returns (`ret void`).
They hold for every context of `P` and every memory `m`, and for every thread whose innermost
frame `f` runs `fn` at block `l`'s position `p0` above any caller frames `rest`. For
`Block.sound_back`, the caller frame `g` is any frame whose block `covers` accepts from
`g.pc + 1`.

**Why.** `Block.sound_retI` on its own covers only a thread with one frame, whose `ret` step is
`.done`; a callee's `ret` back into its caller needs these results.

## Statement

1. `Block.sound_retR`. Assume `coversPathI P fn p0 ((l, ds, S) :: ps) = true`,
   `t.frames = f :: rest`, `f.fn = fn`, `f.label = l`, `f.pc = p0`, `WalkI` of the path from `f`'s
   entry valuation `V`, and that the last block's exit is `.ret`. Then there are `fe` and `me` such
   that:
   - `Steps c t m ⟨fe :: rest, t.k + pathLen S ps⟩ me`;
   - the last block's effects give `me` (`SEff.run` at `V.lastI l S ps`);
   - `step c ⟨fe :: rest, t.k + pathLen S ps⟩ me` is `.ok` of the following, where `me'` is `me`
     with `f`'s `alloca` blocks dead:
     - `.done me'` if `rest = []`;
     - `.next ⟨{ g.set f.dest none none with pc := g.pc + 1 } :: gs, t.k + pathLen S ps + 1⟩ me'`
       if `rest = g :: gs`.
2. `Block.sound_retI` is item 1 with `rest = []`, in one line.
3. `Frame.set_none`: `g.set r none p = g`, since `ret void` sets no register.
4. `Block.sound_back`. Take item 1's premises with `t.frames = f :: g :: rest`, and `dg` and `Sg`
   with `covers P g.fn g.label (g.pc + 1) dg Sg = true`. Suppose that every memory `me` the last
   block's effects make satisfies every `d ∈ dg` at `W`, which is the entry valuation of
   `{ g with pc := g.pc + 1 }` at step count `t.k + pathLen S ps + 1` on `me` with `f`'s `alloca`
   blocks dead. Then for some such `me`,
   `Ends c t m { g with pc := g.pc + 1 } rest (W, g.label, Sg)`.

## Proof

1. This is `Block.sound_retI`'s proof, with `ht : t.frames = f :: rest`. `Block.sound_pathI`
   gives `Ends` of the last block, and with it the frame's `alloca` blocks and caller's register
   (`hal`, `hde`). The `ret`'s `Exit.next` is `step`'s result (`hn`, `hst`), and it is the match
   on `rest`.
2. Item 1 with `rest = []`.
3. By cases on `r`: `Frame.set` with no value is the identity.
4. Item 1 with `rest = g :: rest`, simplified by item 3, gives the step to
   `{ g with pc := g.pc + 1 } :: rest`. `Block.sound` on the caller's block, from that thread and
   at its step count, gives `Ends`. `Ends.pre` prepends item 1's steps and the return's step.

## Dependencies

`Block.sound_pathI`, `Block.sound`, `Ends.pre`, `Exit.next`, `step` (MojoProof/Sem/Thread.lean).

## Instances

MojoProofTest/SymPhi.lean, `edge_back`. This is one program (`edgeF`), one context (`ctxE`), one
memory (`mem0`) and the two frames `[frameE true, callerE]`.
- The callee's path `0 → 1` returns to `callerE`, which is block 1 of `edgeF`, returning to
  position 1 with `%4 = 7`.
- Block 1 then runs from position 1 to its `ret`, whose step is `.done`.
- The caller's conditions `edgeA.obls` hold by `decide +kernel` after the return's memory is
  computed (`cases` on the effects' run).
- `callerE` is written for the test. `step`'s `ret` sets only the caller's position, not the
  instruction there, so the theorem covers every caller frame.

## Limits

- `ret` of a value (`ret T %v`) is outside the fragment, as before. It would set the caller's
  `dest` register, for which `Frame.set_none` does not apply.
- A call into a module function (`exec`'s `.call` with blocks) is not summarized. The caller's
  block is therefore covered from the position after the call, and the call's entry into the
  callee is the theorem's premise (`t.frames = f :: g :: rest`), not a checked step.
