# Race freedom by ownership per barrier interval (`racy_eq_false_of_phased`)

Lean: proved, `racy_eq_false_of_phased` (MojoProof/Sem/Trace.lean), with `Owned.congr` (Trace.lean)
and `mem_phases` (MojoProof/Sem/Race.lean). `racy_eq_false_of_owned` (Trace.lean), race freedom
when one ownership holds for the whole run, is its corollary. The instance and its twin are in
MojoProofTest/Phased.lean. Ownership may change at a barrier of the block of threads; this is what
`tiled_matmul`'s shared-memory tiles need. The Lean proof follows this file step for step.

**Scope.** Every trace. It is a statement about `racy` (MojoProof/Sem/Spec.lean), not about a program. A
kernel is covered once its traces satisfy the premises, which is the summary's job (T3, T4). The whole-run
form becomes a one-line corollary: the discipline that does not depend on the phase.

## Statement

**Phases.** `phases tr` (MojoProof/Sem/Race.lean) lists the accesses of `tr`, newest first. Each comes with its
phase: the number of barriers of its block of threads that completed before it. Two accesses `x` and `y` are
**unordered** if they are by different threads, and either by different blocks of threads or in the same
phase. These are the pairs `clash` tests, besides `conflict`.

**Data.**
- A phased discipline: tilings `T : Nat → Nat → Option (Tiling ι)` (phase, then block) and tile maps
  `own : Nat → Nat → ι` (phase, then thread).
- `T p b = none` says that nobody writes block `b` in phase `p`.
- `Tiling` and `Owned` are as in MojoProof/Sem/Trace.lean.

```lean
theorem racy_eq_false_of_phased {ι : Type} {T : Nat → Nat → Option (Tiling ι)} {own : Nat → Nat → ι}
    {tr : List Event}
    (hO : ∀ x ∈ (phases tr).1, Owned (T x.2) (own x.2) x.1)
    (hG : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.who.cta ≠ y.1.who.cta →
      x.1.ptr.block = y.1.ptr.block → T x.2 x.1.ptr.block = T y.2 x.1.ptr.block)
    (hX : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, x.1.ptr.block = y.1.ptr.block →
      T x.2 x.1.ptr.block ≠ none → (x.1.who.cta ≠ y.1.who.cta ∨ x.2 = y.2) →
      own x.2 x.1.who.thread = own y.2 y.1.who.thread → x.1.who.thread = y.1.who.thread) :
    racy tr = false
```

- `hO` (owned per phase): each access follows the discipline of its own phase.
- `hG` (agreement across blocks of threads): accesses of one memory block by two blocks of threads see the
  same tiling of it, whatever their phases. Barriers order nothing across blocks of threads, so ownership
  of such a block cannot change at a barrier.
  - Shared memory meets `hG` vacuously: only its own block of threads accesses it (`Mem.check`), since an
    access by another faults and is never logged.
  - Global memory needs a tiling that does not depend on the phase.
- `hX` (exclusive tiles): two unordered accesses of one tiled block with the same tile are by one thread.

## Proof

1. By `racy_iff` (proved, Race.lean), `racy tr = true` gives `x, y ∈ (phases tr).1` with `clash x y`. That is:
   - different threads;
   - `x.1.conflict y.1`;
   - different blocks of threads, or `x.2 = y.2`.
2. `conflict` implies `overlaps`, so the two accesses are of one memory block `b`.
3. Both accesses see one tiling `τ := T x.2 b`:
   - for different blocks of threads, `τ = T y.2 b` by `hG`;
   - in the same phase, `x.2 = y.2`.
4. Combine the two tile maps into one, `o n := if n = x.1.who.thread then own x.2 n else own y.2 n`. The
   threads differ, so `o` agrees with `own x.2` at `x`'s thread and with `own y.2` at `y`'s.
5. `Owned` reads only `T · b` at the access's block and the tile map at its thread (lemma `Owned.congr`
   below). So `hO` gives `Owned (T x.2) o x.1` and `Owned (T x.2) o y.1`. The second uses `T y.2 b = τ`.
6. `Owned.apart` (proved, Trace.lean) needs `o x.thread ≠ o y.thread` when `τ ≠ none`. This is `hX`,
   given the same block, `τ ≠ none`, the clash's third conjunct and different threads. The two accesses
   overlap (step 1), so its conclusion is that both are reads, and then they do not conflict, which
   contradicts step 1.

Whole-run form: `racy_eq_false_of_owned` becomes `racy_eq_false_of_phased` with `T _ := T` and
`own _ := own`. Its premises are about `.access a ∈ tr`, and they transfer through `mem_phases`, so
`racy_eq_false_of_owned`'s proof is that one line plus the transfer.

## Lemmas used (proved)

- `mem_phases : x ∈ (phases tr).1 → Event.access x.1 ∈ tr`, by induction on `tr` with `phases_barrier`
  and `phases_access` (Race.lean).
- `Owned.congr : T a.ptr.block = T' a.ptr.block → own a.who.thread = own' a.who.thread →
  Owned T own a → Owned T' own' a`, by the two fields (Trace.lean).

## Dependencies

- `phases`, `clash`, `racy_iff` (MojoProof/Sem/Race.lean);
- `Tiling`, `Owned`, `Owned.apart`, `racy_eq_false_of_owned` (MojoProof/Sem/Trace.lean);
- `racy`, `Access.conflict`, `Access.overlaps` (MojoProof/Sem/Spec.lean).

## Instances and twins

- **A trace, proved.** Two threads of one block of threads and a shared block of 2 bytes:
  - in phase 0, thread 0 writes byte 0 and thread 1 writes byte 1;
  - a barrier of their block of threads;
  - in phase 1, each reads both bytes, by one access of 2 bytes.

  The discipline is `T 0 b = some` (two tiles of one byte), `T 1 b = none` and `own _ := id`.
  - The whole-run form does not apply to this trace: thread 1's read of both bytes is not inside its tile.
    Proved for every `ι`, `T` and `own` (`not_owned`, MojoProofTest/Phased.lean).
  - The per-interval form does (the first `example` of MojoProofTest/Phased.lean). `phases tr` is
    computed by `decide +kernel` (`phases_tr`), `hO` and `hG` are checked on the four accesses by
    cases, and `hX` is immediate because `own _ := id`.
- **Its negative twin.** The same trace without the barrier has a race (`racy = true`, by `decide`,
  the second `example` of MojoProofTest/Phased.lean). No discipline meets the premises: thread 0's
  write of byte 0 and thread 1's read of both bytes are in one phase.
  - If `T 0 b = none`, the write breaks `Owned.read`.
  - Otherwise their tiles overlap, so `hX` would make the threads equal.
- **`tiled_matmul`, one example (evaluated).** The file in tests/corpus/tiled_matmul/ is unrolled. It
  has eight barriers (lines 91, 283, 339, 404, 460, 525, 581, 646), and each block of threads uses its two
  `[256 x float]` shared tiles as follows:
  - it stores them in phases 0, 2, 4 and 6 (lines 56-87, 307-335, 428-456, 549-577);
  - it loads them in phases 1, 3, 5 and 7 (lines 96-280, 340-401, 461-522, 582-643);
  - it stores the output, in global memory, in phase 8 (line 654).

  So the shared tiles are written in even phases and read in odd ones. The discipline is:
  - `ι := Nat` and `own _ := id`;
  - in even phases, each shared block is tiled by the threads of its block of threads, one 4-byte element
    each, and other threads get tiles of length 0;
  - in odd phases, shared blocks are untiled;
  - the output buffer has one tiling in every phase, by the global element index;
  - the inputs are untiled (read only);
  - the kernel's `byval` argument copy is untiled (only read).

  The planned test is a Bool check of `hO`, `hG` and `hX` on the full launch's trace (37,888 accesses,
  MojoProofTest/Eval.lean). It covers one launch, not the kernel. The proof for every launch comes after
  T3 and T4.
  - With `own := id`, `hX` is immediate, and the disjointness of the global index's tiles is the
    index lemma on a one-dimensional launch (`Launch.index_oneDim`, index.md).
  - A tile of length 0 at offset 0 meets `Tiling.disj` with every tile (`0 + 0 ≤ off j`), so one
    `Tiling Nat` can give every other thread an empty tile.
