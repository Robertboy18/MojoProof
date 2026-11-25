# `vector_addition`'s accesses are race-free by construction (`mojo_race`)

Lean: `MojoProof/Sym/Race.lean` (the lemmas and the tactic). Tests: `MojoProofTest/Race.lean`.

**Scope.** The premises that the race-freedom results take of a kernel's accesses: `Apart cell w`
and `Elem.Own out w cell a` (of `Elem.safe`, the elementwise discipline, MojoProof/Sym/Kernel.lean),
`x.conflict y = false` (pairwise, the form of `Grid.advance_comm`'s `hW`), and `Grid.owned_sound`'s
`hX`, `hL`, `hI` and `hO` (MojoProof/Sem/ScheduleOwned.lean). For `vector_addition`: every launch
`L`, every `k` (a thread's index; the accesses are a template, item 2), input blocks `a`, `b`,
output block `out` and argument blocks `p0`, `p1`, `p2`.

## Statements

All in `MojoProofTest/Race.lean`, namespace `MojoProofTest.Race`, each by `mojo_race` alone:

1. `vadd_apart : Apart (fun k => 4 * k) 4`.
2. `vadd_owned`: for every `L`, `k`, `a b out p0 p1 p2` with `a ≠ b ∧ a ≠ out ∧ b ≠ out` and
   `p0 ≠ out ∧ p1 ≠ out ∧ p2 ≠ out`, each access of a literal list of six (who `⟨k, k / volume
   L.block⟩`): the loads of 8 bytes at `⟨p2, 0⟩`, `⟨p1, 0⟩`, `⟨p0, 0⟩`, the `!invariant.load`
   loads of 4 bytes at `⟨a, 4 k⟩` and `⟨b, 4 k⟩`, and the store of 4 bytes at `⟨out, 4 k⟩`, meets
   `Elem.Own out 4 (fun k => 4 * k)`. The list is an access template: the accesses thread `k`
   makes on its active path `%4 → %21 → %31` (taken when `k < n`) of a one-dimensional launch.
   The theorem has no execution premise (that a run makes these accesses is not proved here), no
   bound `k < n` and no 1-D hypothesis; those only say when the template is the thread's.
3. `vadd_stores`: for every `L`, `i ≠ j` and `out`, the stores of threads `i` and `j` at
   `⟨out, 4 i⟩` and `⟨out, 4 j⟩` do not conflict.
4. `vadd_loads`: for every `L`, `i`, `j`, `a` and offset `o`, two loads at `⟨a, o⟩` do not
   conflict.
5. `vadd_hX`, `vadd_hL`, `vadd_hI`: `Grid.owned_sound`'s premises for every trace `tr` with
   `own t = t`, every tiling map, no local blocks, and (for `hI`) every trace whose accesses all
   meet `Elem.Own out 4 (fun k => 4 * k)`.
6. `vadd_hO`: `Grid.owned_sound`'s `hO` for every trace `tr`, output block `out`, count `n` and
   local-block relation `loc`, with the tiling `T b = if b = out then some (Tiling.clip (4 * ·) 4
   (4 n) vadd_apart) else none` and `own t = t`, from `H` (every access of `tr` meets
   `Elem.Own out 4 (fun k => 4 * k)`) and `hb` (every access of `tr` to `out` ends by `4 n`).
7. The twin, an `example` after `twin_clash` (the kernel theorem's negative twin (c), `twin_tid`, kernel.md): with `tid.x` alone as the
   index on a launch of two blocks of `B` threads, thread `t` (block 0) and thread `B + t`
   (block 1) both store 4 bytes at `⟨out, 4 t⟩`. mojo_race leaves `x.conflict y = false` open and
   logs it with both accesses (`#guard_msgs`); `twin_clash` proves `x.conflict y = true`.

## Proof

A (`Apart`). `Apart off w` is `∀ i j, i ≠ j → off i + w ≤ off j ∨ off j + w ≤ off i`. For
`off = fun k => 4 * k` and `w = 4` it is linear in `i` and `j`, so `omega` proves it after the
introductions (`4 i + 4 ≤ 4 j` when `i < j`, the other side when `j < i`). For `base + k * s` with
`w ≤ s` and `s` not a literal, `apart_stride` gives it.

B (`Elem.Own`). For an access whose fields are given, `Elem.Own out w cell a` unfolds to three
implications, on the access's block, its `write` flag and its `invariant` flag. The store to `out`
lies in `[4 k, 4 k + 4)`, which is cell `k` (`omega` on the integer offsets). Every other access
reads and is not an `atomicrmw`'s (`⟨rfl, rfl⟩` on `write = false` and `atomic = none`), and the
first implication's premise `p = out` contradicts the hypothesis `p ≠ out` (`omega`). The
`!invariant.load` loads are to `a` and `b`, which `hne` says are not `out`; the other accesses
have `invariant = false`, so the third premise is `false = true` (`contradiction`). A list of
accesses is taken element by element (`List.forall_mem_cons`).

C (pairwise conflicts). `Access.conflict x y` needs `x.overlaps y`, which needs the same block,
`x.off < y.off + y.len` and `y.off < x.off + x.len`. `Access.conflict_of_apart`: a different block
or bytes apart (`x.off + x.len ≤ y.off` or the other way) gives `false`; for the stores of threads
`i ≠ j`, `4 i + 4 ≤ 4 j ∨ 4 j + 4 ≤ 4 i` by `omega`. `Access.conflict_of_reads`: two reads never
conflict (`Access.conflict_eq_false`).

D (`Grid.owned_sound`). `hX` asks that threads with one tile `own t` at a tiled block are the same
thread. With `own t = t`, which is a 1-D launch's index of thread `t` (`Launch.index_oneDim`), that
is `t = t' → t = t'` (`omega`). `hL` with no local blocks has the premise `False`. `hI` follows
from every access being owned (`Elem.Own.invariant_apart`): an `!invariant.load` is not to `out`,
and a write is to `out` (the second implication of `Elem.Own`, contraposed), so they are to
different blocks.

`hO` asks that every access not to a local block follow the discipline `(T, own)`. A `Tiling`
bounds its tiles by its extent, so the cells `cell i` of all threads `i : Nat` are not a tiling;
`Tiling.clip cell w ext hap` is: tile `i` is `[min (cell i) ext, min (cell i + w) ext)`, the part
of cell `i` below `ext`, in bounds by construction and disjoint because the cells are
(`hap : Apart cell w`; `omega` on the `min`s). `Elem.Own.owned`: an access to `out` lies in its
thread's cell (`Elem.Own`) and ends by `ext` (`hb`), so it lies in the clipped tile of its thread
number; an access to another block has no tile (`T b = none`) and reads (`Elem.Own`). With the
thread numbers as tiles, `hX` is `t = t' → t = t'` on every launch, so no injectivity of the index
(`Launch.index_inj`) is needed. With the i64 index word `ctaid.x * ntid.x + tid.x` as the tile of
a thread, `hX` holds on every valid launch whose grid and block have side 1 in `y` and `z`, for
every trace whose threads are below the thread count and every tiling: equal words give the same
`ctaid.x` and `tid.x` (`Launch.index_inj`), and a thread's index is its number
(`Launch.index_oneDim`), so the threads are equal (`Launch.thread_eq_of_index`,
MojoProof/Sym/Race.lean; `vadd_hX_index` by mojo_race, MojoProofTest/Race.lean). Two- and
three-dimensional launches are not covered.

E (the twin). With the index `tid.x` alone, threads `t` and `B + t` have the same `tid.x = t` in
blocks 0 and 1, so their stores are both at `⟨out, 4 t⟩` with 4 bytes. No route of mojo_race
applies: the blocks are equal, the bytes overlap, and both write. The goal stays as stated, and the
log names the two accesses. `twin_clash` shows the goal is false (`simp` on `Access.conflict`),
so the collision is real; the threads and their blocks of threads differ, which
with the conflict is the condition of `clash` (MojoProof/Sem/Race.lean).

## Not covered

Cells that are not linear in the thread (`tid.x % B`, symbolic strides other than
`base + k * s`), and an `hO` with another tiling or tile map than `Tiling.clip`'s and the thread
numbers. Such goals stay open, logged. `vadd_hO`'s premises `H` and `hb` are about a trace; that a
run's trace meets them is not proved here (`Elem`'s `owned` field gives `H` for the memory it
describes; `hb` is the bounds of `out`'s buffer).
