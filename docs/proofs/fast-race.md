# The fast race check finds every race (`fast_sound`)

Lean: `MojoProof/Sem/Race.lean` (`fast`, `clash`), `MojoProof/Sem/RaceSig.lean` (`racy_iff`,
`fast_sound`).

**Scope.** Every launch `L` and every trace `tr` by threads of `L` in their blocks of threads that is
shaped (`Trace.Shaped tr.reverse`), `racy_iff`'s premises. `racy tr` below is the core's `racy` at
`sig` of `tr`'s core events, oldest first (`GPUProof.racy sig ((tr.map (Event.toCore L)).reverse)`);
MojoProof has no `racy` of its own. Only `fast tr = false → racy tr = false` is proved. The converse
(`fast` reports only real races) is not; the tests compare the two on every trace that is short
enough for `racy`.

## Definitions

- `phases tr` folds the trace from its oldest event. Each access is paired with its phase: the number of
  barriers of its block of threads that are older than it. The second component counts the barriers of
  each block of threads over the whole trace.
- `clash x y`: the accesses are by different threads, they conflict (overlap, at least one writes, not
  both atomic of one commuting operation on the same bytes), and they are by different blocks of threads or have the same phase.
- `Access.bytes a`: the pairs `(block, offset)` that `a` touches. `bucket` adds an access to the list of
  each of its bytes.
- `fast tr`: some write `x` has a byte `b` such that some access in `b`'s list clashes with `x`.

## Proof

**`races_iff`, forward** (induction on `tr`; T2 uses the converse, schedule.md L9). Suppose `a.races sync tr`. Then some access `y` of `tr` meets three
conditions:

- it is by another thread;
- it conflicts with `a`;
- it is by another block of threads, or `sync = false` and `y`'s phase is the number of barriers of `a`'s
  block of threads in `tr`.

The cases:

- A barrier of another block of threads leaves that count unchanged. This is `HashMap.getD_insert` with
  distinct keys.
- A barrier of `a`'s own block of threads sets `sync`. This is how `Access.races` is defined, so the second
  alternative needs no count.
- An access `e` that races with `a` directly is `y`. Its phase is the count before it, and that count is
  the count for `tr` because no barrier lies between them.

**`racy_iff`, forward** (induction on `tr`). If `racy tr`, some two accesses `x`,
`y` in `(phases tr).1` clash. In the case of a newest access `a`, the current count of `a`'s block of
threads is `a`'s phase, so `races_iff` gives the clash. The converses are schedule.md's L9.

**`clash_comm`.** `clash` is symmetric because thread inequality, `overlaps`, `conflict` and the phase test
are symmetric.

**`Access.overlaps_bytes`.** Two overlapping accesses share a byte: the larger of their two start offsets.
This needs both lengths positive, which `overlaps` requires.

**`mem_buckets`** (induction on the list, with `mem_insertAll` for one access). After folding `bucket`, the
list of byte `b` contains every access that touches `b`.

**`fast_sound`.** Suppose `racy tr`. `racy_iff` gives `clash x y`. Their conflict makes one of them a
write; by `clash_comm`, assume it is `x`. `overlaps_bytes` gives a common byte `b`, and `mem_buckets`
puts `y` in `b`'s list. So `fast` finds `x`, `b` and `y`, and `fast tr = true`, which contradicts the
hypothesis.

## Dependencies

- `Access.races`, `Access.conflict`, `Access.overlaps` (`MojoProof/Sem/Spec.lean`);
- `GPUProof.racy` at `sig`, by positions (`racy_sig_rev`, `pos_iff_phases`,
  `MojoProof/Sem/RaceSig.lean`);
- `Std.HashMap` and its lemma `getD_insert`.
