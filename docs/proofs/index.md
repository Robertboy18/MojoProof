# The global thread index (`Launch.index_ops`, `Launch.index_oneDim`, `Launch.index_inj`, and on 2-D launches `Launch.thread_inj`, `Launch.xy_inj`, `Launch.cell_inj`, `Launch.cell_apart`; onto: `Launch.index_onto`, `Launch.cell_onto`, `Launch.index_lt_mul`)

Lean: proved, for every launch, thread number, dimension, width, flags, stride, base, cell width
and predicate as stated below, in MojoProof/Sem/Index.lean. Instances and twins:
MojoProofTest/Index.lean.

## What the kernel computes

`vector_addition`'s entry block computes its element index as

```
%12 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
%13 = zext i32 %12 to i64
%14 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
%15 = zext i32 %14 to i64
%16 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
%17 = sext i32 %16 to i64
%18 = mul i64 %15, %17
%19 = add i64 %18, %13
```

and, in block `%21` after `icmp slt i64 %19, %11` with `%11 = sext i32 %3 to i64`,
`%22 = trunc i64 %19 to i32` and `%23 = sext i32 %22 to i64`. A call to a special register gives
the i32 word `BitVec.ofNat 32 v` of its value `v = (L.env n).sreg r d` (`intrinsic`,
MojoProof/Sem/Thread.lean),
and `zext`, `sext`, `trunc`, `mul` and `add` are `intCast` and `intBin` (MojoProof/Sem/Op.lean).

## Statements

Write `t`, `c`, `k` for `tid d`, `ctaid d`, `ntid d` of thread `n` (`(L.env n).sreg r d`), and
`[x]_w` for `BitVec.ofNat w x`.

1. Words of natural numbers, for every width and all flags `fl`:
   - `trunc` and `zext` to `w'` of `.bits w [k]_w` with `k < 2^w` is `.ok (.bits w' [k]_w')`
     (`intCast_ofNat`).
   - `sext` to `w'` of `.bits w [k]_w` with `2k < 2^w` is `.ok (.bits w' [k]_w')`
     (`intCast_sext_ofNat`).
   - `add` of `[a]_w` and `[b]_w` with `2(a + b) < 2^w` is `.ok (.bits w [a + b]_w)`
     (`intBin_add_ofNat`); `mul` with `2a`, `2b`, `2ab` below `2^w` is `.ok (.bits w [ab]_w)`
     (`intBin_mul_ofNat`).
   - For `w' ≤ w` and `2k < 2^w'`, `trunc` to `w'` and `sext` back to `w` of `[k]_w` give
     `[k]_w'` and then `[k]_w` (`intCast_trunc_sext`). With `w = 64`, `w' = 32`: `%22`, `%23` are
     the identity on indices below `2^31`, which the branch `%19 < %11 < 2^31` gives.
2. `Launch.index_ops`: on a valid launch, for every `n`, `d`, `fl`, `fl'`, the five operations
   `%13`, `%15`, `%17`, `%18`, `%19` give `[t]_64`, `[c]_64`, `[k]_64`, `[ck]_64` and
   `[ck + t]_64`. `Launch.index_lt`: `ck + t < 2^42`.
3. `Launch.index_oneDim`: if the grid and the block have size 1 in `y` and `z`, then for every
   `n < volume L.grid * volume L.block` (the threads of `Grid.start`), `ck + t = n` in dimension
   `x`.
4. `Launch.index_inj`: on a valid launch, if `[c₁k + t₁]_64 = [c₂k + t₂]_64` for threads `n₁`, `n₂`
   in dimension `d`, then `c₁ = c₂` and `t₁ = t₂`.

## Proofs

1. A word `[x]_w` with `x < 2^w` has `toNat = x`. `setWidth w'` keeps `x mod 2^w'`, as does
   `[x]_w'`, so `trunc` and `zext` agree with `[x]_w'`. If `2x < 2^w` the top bit of `[x]_w` is
   clear (`x < 2^(w-1)`, and for `w = 0`, `x = 0`), so `signExtend` is `setWidth` and `toInt = x`
   (`BitVec.toInt_ofNat_of_lt`). For `add`, `[a]_w + [b]_w = [a + b]_w`; the `nuw` test
   `a + b ≥ 2^w` fails, and the `nsw` test asks whether the signed sum `a + b` lies outside
   `[-2^(w-1), 2^(w-1))`, which `2(a + b) < 2^w` excludes (`outS_of_lt`). `mul` is the same with
   the product; its `toInt`s need `2a, 2b < 2^w`.
2. On a valid launch `Launch.sreg_bound` gives `t < maxBlock d ≤ 1024`,
   `c < maxGrid d ≤ 2^31 - 1` and `k < maxBlock d + 1 ≤ 1025`, so `ck ≤ 2^31 · 1024 = 2^41` and
   `ck + t < 2^42`. Every premise of 1 holds with `w = 64` (and `w = 32` for the operands of the
   casts).
3. `Launch.env` gives `t = coord L.block (n mod B) x = (n mod B) mod B = n mod B` with
   `B = L.block x = volume L.block`, `k = B`, and
   `c = coord L.grid (n / B) x = (n / B) mod G` with `G = L.grid x = volume L.grid`. As
   `n < G B`, `n / B < G`, so `c = n / B`, and `ck + t = (n / B) B + n mod B = n`. (`B > 0`
   because `n < G B`.)
4. Both indices are below `2^42 < 2^64`, so the words' equality is that of the numbers. `k = B`
   for both threads and `t₁, t₂ < B` (`coord_lt`), so dividing `c₁B + t₁ = c₂B + t₂` by `B` gives
   `c₁ = c₂`, and then `t₁ = t₂`.

## Instance and twin

- Instance: the launch of grid (2, 1, 1) and block (4, 1, 1), valid. For its 8 threads the
  operations give `[n]_64` by the theorems (`index24`) and by evaluation (`eval24`), and equal
  index words are one thread (`inj24`). `trunc` and `sext` back are the identity on these
  indices (`roundtrip24`) and not at `2^31` (`roundtrip_twin`).
- Twin: grid (1, 1, 1) and block (2, 2, 1), valid, 4 threads. Thread 2 has `tid = (0, 1)`, so its
  `ck + t` in `x` is 0, as is thread 0's (`twin22`): without the premise on the block, 3 fails,
  and the index is not injective on thread numbers (4 still holds: `c` and `t.x` agree).

## Two-dimensional launches

The naive matmul kernel computes a row and a column, each a global index:
`%24 = ctaid.x * ntid.x + tid.x` and `%35 = ctaid.y * ntid.y + tid.y` (each by the five
operations of 2, in `x` and in `y`). It reads row `row` of A and row `col` of B and writes
`C[row, col]` at element `row * 50257 + col`, under `row < m` and `col < n`. Its race freedom
needs: two in-bounds threads with one cell are one thread. Write `Launch.index L n d` for
`ck + t` of thread `n` in dimension `d` (the number whose i64 word 2 gives), `row n` for
`Launch.index L n x` and `col n` for `Launch.index L n y`.

### Statements

5. `coord_linear`, `coord_inj`: for every box `d` and `a < volume d`,
   `a = coord d a x + d x * (coord d a y + d y * coord d a z)`; so two numbers below the volume
   with the same three coordinates are equal.
6. `Launch.env_inj`: for every launch and threads `n`, `n'` below the thread count
   `volume L.grid * volume L.block`, equal `ctaid` and equal `tid` in all three dimensions give
   `n = n'`.
7. `Launch.thread_inj`: on every valid launch, threads below the thread count whose index words
   `[row]_64`, `[col]_64` and `[Launch.index L n z]_64` are equal are one thread.
   `Launch.xy_inj`: if moreover the grid and the block have side 1 in `z`, equal words in `x` and
   `y` suffice.
8. `Launch.cell_inj`: on every valid launch of side 1 in `z`, for every stride `s` and threads
   `n`, `n'` below the thread count with `col n < s` and `col n' < s`,
   `row n * s + col n = row n' * s + col n'` gives `n = n'`.
9. `Launch.cell_apart`: on the same launches, for every stride `s`, base `b`, cell width `w` and
   predicate `p` on thread numbers such that `p n` gives `n` below the thread count and
   `col n < s`: for distinct `n`, `n'` with `p n` and `p n'`, the cells
   `b + (row n * s + col n) * w` and `b + (row n' * s + col n') * w` are `w` bytes apart (one ends
   before the other starts). With `w = 4` these are the 4-byte cells of a `float` matrix with row
   stride `s`, and `p n` is "thread `n` writes": `row n < M` and `col n < N` for the kernel's
   sizes `M` and `N ≤ s`.
10. `coord_onto`: for every box `d` and every point `p` with `p k < d k` in each dimension, the
    number `a = p x + d x * (p y + d y * p z)` is below `volume d` and `coord d a = p` (the
    converse of 5).
11. `Launch.index_onto`: for every launch and every point `r` with `r d < L.grid d * L.block d`
    in each dimension, some thread `n` below the thread count has `Launch.index L n d = r d` in
    every dimension. `Launch.index_lt_mul`: for every launch with positive sides in `d`, every
    thread's `Launch.index L n d` is below `L.grid d * L.block d`, so the bounds of 11 are sharp.
12. `Launch.cell_onto`: on every valid launch, for every `r < L.grid x * L.block x` and
    `c < L.grid y * L.block y`, some thread `n` below the thread count has `row n = r` and
    `col n = c` (11 at the point `(r, c, 0)`). With side 1 in `z` that thread is unique (7), so
    every cell `(r, c)` with `r < M` and `c < N` of a launch with `M ≤ L.grid x * L.block x` and
    `N ≤ L.grid y * L.block y` is written by exactly one thread. No premise on `z` is needed for
    existence: on a valid launch `L.grid z * L.block z > 0`.

### Proofs

5. `coord z = a / (d x · d y) mod d z = a / (d x · d y)` as `a < d x · d y · d z`; and
   `a / (d x · d y) = a / d x / d y`, so `coord y + d y · coord z = a / d x` and then
   `coord x + d x · (a / d x) = a` (`Nat.mod_add_div` twice).
6. With `B = volume L.block > 0` (as `n < G B`), `tid` is `coord L.block (n mod B)` and `ctaid` is
   `coord L.grid (n / B)`, with `n mod B < B` and `n / B < volume L.grid`: by 5, `n mod B` and
   `n / B` are those of `n'`, and `n = B (n / B) + n mod B`.
7. 4 in each dimension gives equal `ctaid d` and `tid d`; then 6. With side 1 in `z`,
   `ctaid z = tid z = 0` for every thread (a coordinate mod 1), so the `z` words are equal.
8. If `row n < row n'` then `row n * s + s ≤ row n' * s` (`stride_lt`), so
   `row n * s + col n < row n' * s ≤ row n' * s + col n'` as `col n < s`; symmetrically, so the
   rows are equal, then the columns, and 7 (`Launch.xy_inj`) gives `n = n'`.
9. `apart_stride b` (`w ≤ w`) at the two cell numbers, which differ by 8.
10. With `Y = p y + d y * p z`: `p y < d y` and `p z + 1 ≤ d z` give `Y < d y (p z + 1) ≤ d y d z`,
    and then `a = p x + d x Y < d x (Y + 1) ≤ d x d y d z`. `a mod d x = p x` (as `p x < d x`),
    `a / d x = Y` and `Y mod d y = p y`, and `a / (d x d y) = Y / d y = p z` with
    `p z mod d z = p z`.
11. Every side is positive, as `r d < L.grid d * L.block d`. Take the block point
    `b d = r d / L.block d < L.grid d` and the thread point `t d = r d mod L.block d < L.block d`,
    their numbers `B < volume L.grid` and `T < volume L.block` by 10, and
    `n = B · volume L.block + T`, which is below `volume L.grid * volume L.block`. Then
    `n / volume L.block = B` and `n mod volume L.block = T`, so `ctaid d = b d` and `tid d = t d`
    by 10, and `ctaid d * ntid d + tid d = (r d / L.block d) L.block d + r d mod L.block d = r d`.
    For `Launch.index_lt_mul`: `ctaid d < L.grid d` and `tid d < L.block d` (`coord_lt`), so
    `ctaid d * L.block d + tid d < (ctaid d + 1) L.block d ≤ L.grid d * L.block d`.
12. 11 at `r x = r`, `r y = c`, `r z = 0 < L.grid z * L.block z` (`Launch.Valid`).

### Instances and twins

- Instance: grid (2, 2, 1) and block (2, 2, 1) (`L2222`), valid, 16 threads. The cells
  `row * 4 + col` of its 16 threads are `0, ..., 15` each once (`cells2222`, by evaluation), and
  `Launch.cell_apart` gives the 4-byte cells at stride 4 apart on all of them (`apart2222`); equal
  `x` and `y` index words are one thread (`inj2222`, `Launch.xy_inj`).
- Twin of the `z` premise: grid (1, 1, 1) and block (1, 1, 2) (`L112`), valid, 2 threads with
  `row = col = 0` and different `tid z` (`twin112`): `Launch.xy_inj` needs side 1 in `z`.
- Twin of `col < s`: on `L2222` with stride 1, thread 1 (row 1, column 0) and thread 2 (row 0,
  column 1) have cell 1 (`twin_stride`): `Launch.cell_inj` needs the columns below the stride.
- Instance of 12: on `L2222`, every cell `(r, c)` with `r, c < 4` is some thread's below 16
  (`onto2222`, `Launch.cell_onto`); the thread of cell `(3, 2)` is the proof's
  `B · volume L.block + T` with block point `(1, 1, 0)`, `B = 3`, and thread point `(1, 0, 0)`,
  `T = 1`: thread 13 (`cell32`, by evaluation).
- Twin of the bound: no thread of `L2222`, below 16 or not, has row 4 or column 4 (`twin_onto`,
  `Launch.index_lt_mul`), so `Launch.cell_onto` needs `r < L.grid x * L.block x` and
  `c < L.grid y * L.block y`.

## Use

`own` of T2′ for `vector_addition` is the global index. On a launch whose grid and block have
size 1 in `y` and `z`, the index of each thread below `volume L.grid * volume L.block` is its
thread number (3, `Launch.index_oneDim`), so two such threads with one index are one thread. 4
(`Launch.index_inj`) does not give this: it gives equal `ctaid d` and `tid d` in the one
dimension `d` only, and on the 2-D block of `twin22` threads 0 and 2 have one index. The
ownership argument therefore needs the premises of 3 (a one-dimensional grid and block, and
threads in range) and goes through `Launch.index_oneDim`. On a 2-D launch of side 1 in `z` (the
naive matmul's), the pair of words of 7 is the thread (`Launch.xy_inj`), and the output cells of
the threads that write are apart (`Launch.cell_apart`, 9). Conversely, every cell `(r, c)` of an
`M × N` output with `M ≤ L.grid x * L.block x` and `N ≤ L.grid y * L.block y` is some thread's
(`Launch.cell_onto`, 12), so a kernel whose thread writes its cell when `row < M` and `col < N`
writes every cell of the output, each once. The block checker's
`SNode.eval` of the `.cast` and `.bin` nodes is `lanes` of `intCast` and `intBin`, so its terms
meet 1 and 2 by rewriting.
