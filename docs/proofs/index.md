# The global thread index (`Launch.index_ops`, `Launch.index_oneDim`, `Launch.index_inj`)

Lean: proved, for every launch, thread number, dimension, width and flags as stated below, in
MojoProof/Sem/Index.lean. Instance and twin: MojoProofTest/Index.lean.

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

## Use

`own` of T2′ for `vector_addition` is the global index. On a launch whose grid and block have
size 1 in `y` and `z`, the index of each thread below `volume L.grid * volume L.block` is its
thread number (3, `Launch.index_oneDim`), so two such threads with one index are one thread. 4
(`Launch.index_inj`) does not give this: it gives equal `ctaid d` and `tid d` in the one
dimension `d` only, and on the 2-D block of `twin22` threads 0 and 2 have one index. The
ownership argument therefore needs the premises of 3 (a one-dimensional grid and block, and
threads in range) and goes through `Launch.index_oneDim`. The block checker's
`SNode.eval` of the `.cast` and `.bin` nodes is `lanes` of `intCast` and `intBin`, so its terms
meet 1 and 2 by rewriting.
