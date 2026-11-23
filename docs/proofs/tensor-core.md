# Tensor cores: fragments, `ldmatrix` and `mma` (`Frag`, `Frag.bijOn`, `fragA_inv`, `fragB_inv`, `fragC_inv`, `ldm_inv`, `mmaFrags_inv`, `ldmatrix_gather`, `ldmatrix_fragA`, `ldmatrix_fragB_cols`, `ldmatrix_fragB`, `ldmatrix_fragBt`, `mmaStep_gather`, `mma_exact`, `mma_contract`, `castDot_ok`, `Grid.warpReady`)

Lean: MojoProof/Sem/TensorCore.lean; instances and twins in MojoProofTest/TensorCore.lean. The
statements are about functions of the 32 lanes' registers; that a grid run reaching
`llvm.nvvm.ldmatrix…` or `llvm.nvvm.mma…` computes them is not proved, since the grid does not
dispatch these intrinsics yet (`Grid.fire` reports them unsupported). See "Not proved".

## The fragment model

The source is the PTX ISA, version 9.5: section 9.7.16.5.14 (`mma`, its "Matrix Fragments for
mma.m…n8k…" tables in sections 9.7.16.5.2 and 9.7.16.5.6-8) and section 9.7.16.5.15
(`ldmatrix`), as docs/TRUST.md T12 reads them. The
repository holds no copy of the ISA, so the citation is by section; the layouts below are the
tables' formulas, written with `g = l / 4` (the ISA's `groupID`) and `t = l % 4`
(`threadID_in_group`) for lane `l`.

A fragment layout `F : Frag` places an `F.rows × F.cols` tile in the registers of a warp: each of
the 32 lanes holds `F.regs` registers (32-bit, and 64-bit for f64), each holding `F.pack`
elements, and
`F.pos l r s` is the tile cell `(row, column)` of element `s` of register `r` of lane `l`
(element 0 in the low bits). `F.own i j` is the inverse, the `(lane, register, element)` holding
cell `(i, j)`. `F.Inv` says the two are inverse on the 32-lane domain and the tile, and
`Frag.bijOn` turns that into Mathlib's `Set.BijOn`: `pos` is a bijection from
`{(l, r, s) | l < 32, r < regs, s < pack}` onto `{(i, j) | i < rows, j < cols}`. A tile of any
type is put into registers by `F.scatter T l r s = T (F.pos l r s)` and read back by
`F.gather x i j = x (F.own i j)`; on an `Inv` layout, registers that agree with `scatter T`
on the lanes' registers gather to `T` on the tile (`Frag.gather_of_scatter`), so
`gather (scatter T) = T` there (`Frag.gather_scatter`). The loads below are stated through
`gather`, the way `mma` reads its operands.

The families, for `h` blocks of 8 rows, `p` elements per register and `c` chunks, `K = 4 p c`:

| layout | rows × cols | regs | pos l r s |
|---|---|---|---|
| `fragA h p c` (A, row major) | 8h × K | hc | `(g + 8 (r % h), s + p (t + 4 (r / h)))` |
| `fragB p c` (B, column major) | K × 8 | c | `(s + p (t + 4 r), g)` |
| `fragC h p` (C and D) | 8h × 8 | 2h / p | `(g + 8 (i / 2), 2 t + i % 2)`, accumulator `i = p r + s` |
| `ldm q false` (`ldmatrix.x<q>`) | 8q × 8 | q | `(8 r + g, 2 t + s)` |
| `ldm q true` (`ldmatrix.x<q>.trans`) | 8q × 8 | q | `(8 r + 2 t + s, g)` |

The ISA's shapes are instances: `m16n8k8 .tf32` is `fragA 2 1 2`, `fragB 1 2`;
`m16n8k16 .bf16` and `.f16` are `fragA 2 2 2`, `fragB 2 2`; `m16n8k4 .tf32` is `fragA 2 1 1`,
`fragB 1 1`; `m16n8k8 .bf16` and `.f16` are `fragA 2 2 1`, `fragB 2 1`; all with the f32
accumulator `fragC 2 1`, or the f16 one `fragC 2 2` (two to an `.f16x2` register, sections
9.7.16.5.7 and 9.7.16.5.8). In f64, one element to a 64-bit register, `m16n8k<4c>` is
`fragA 2 1 c`, `fragB 1 c`, `fragC 2 1` (the ISA's f64 tables at `m16n8k4` and `m16n8k8` are its
tf32 ones), and `m8n8k4` is `fragA 1 1 1`, `fragB 1 1`, `fragC 1 1` (section 9.7.16.5.2).
`mmaFrags v` maps the importer's `Mma` to these three layouts for every shape `m16n8k<k>` with a
tf32, bf16 or f16 input and an f32 accumulator, or in f64, `k` a positive multiple of `4 p`
(`p = mmaPack v.ab`), and for `m8n8k4 .f64`. `m8n8k4` with f16 inputs, whose layouts
(section 9.7.16.5.1) are not these families, gets none, and since the importer reads no f16
accumulator, `mmaFrags` never gives `fragC 2 2`. For
`ldmatrix`, the tile of `ldm q t` is the `q` matrices of 8 × 8 16-bit elements stacked: row
`8 m + i` is row `i` of matrix `m`, whose address lane `8 m + i` gives; `.x1` uses lanes 0-7,
`.x2` lanes 0-15, `.x4` all 32.

These are LeanKernel's conventions (its `aRow`/`aCol`, `bRow`/`bCol`, `cRow`/`cCol` and its
`ldmatrix` destinations), restated here without depending on it. Where we differ: lanes, registers
and elements are numbers with bounds rather than `Fin` and bit vectors; one theorem covers each
family for every `p`, `c` and `q`, where LeanKernel checks shapes one by one (its `exec_tileA`
and `exec_tileBt` are `ldmatrix_fragA` and `ldmatrix_fragBt` at `c = 2`); `.trans` has a
theorem here (`ldm_inv q true`, `ldmatrix_fragB_cols`, `ldmatrix_fragB`) and none in
LeanKernel; and LeanKernel cites PTX ISA 9.4 where we cite 9.5.

## Statements

1. `Frag.bijOn`, for every layout: if `F.Inv`, `pos` is a bijection from the domain onto the tile
   (`Set.BijOn`).
2. `fragA_inv`, `fragB_inv`: for every `h`, `p` and `c`, `(fragA h p c).Inv` and
   `(fragB p c).Inv` (for `p = 0` the tile and the registers are empty); `fragC_inv`: for every
   `h` and `p` 1 or 2, `(fragC h p).Inv` (the twin `fragC_three`: not for `p = 3`); `ldm_inv`:
   for every `q` and both values of `.trans`, `(ldm q t).Inv`. The tests check by `decide`, for
   every lane, that the layouts at `m16n8k8 .tf32`, `m16n8k16 .bf16`/`.f16` and the f32
   accumulator put each element where the ISA's tables, written in their own form, put it
   (`tableA8`, `tableB8`, `tableA16`, `tableB16`, `tableC`), and likewise the f16 accumulator
   (`tableC16`), `m8n8k4 .f64` (`tableA64`, `tableB64`, `tableC64`), A of `m16n8k4`
   (`tableA4`) and `m16n8k16 .f64` (`tableA16d`, `tableB16d`); `bijA16` is `Frag.bijOn` at
   `fragA 2 2 2`.
3. `mmaFrags_inv`: for every importer `Mma` value `v` that `mmaFrags` accepts, the three layouts
   are `Inv`, A is `v.m × v.k`, B is `v.k × 8`, C is `v.m × 8`, and their register counts are
   the importer's `Mma.regs v` (`regs16`: `(4, 2, 4)` at `m16n8k16`; `regs64`: `(1, 1, 2)` at
   `m8n8k4 .f64`).
4. `ldmatrix_gather`: for every count `q`, flag `t`, lane addresses `a` and memory reader `rd`,
   the registers after `ldmatrix q t a rd`, read in the layout `ldm q t`, hold
   `rd (a R + 2 C)` at every cell `R < 8q`, `C < 8`: the stacked tile at the rows' addresses.
5. `ldmatrix_fragA`: for every `c`, `ldmatrix.x<2c>` without `.trans` loads the A operand of a
   16-bit `mma` (`(fragA 2 2 c).gather` of the registers is A) when the matrices are A's 8 × 8
   blocks in column-block order (rows 0-7, then 8-15, of each 8 columns); `ldmatrix_fragB`:
   `ldmatrix.x<c>.trans` of B's `c` blocks of 8 rows, stored row major, loads B
   (`(fragB 2 c).gather` of the registers is B), the two layouts putting every element at the
   same cell; `ldmatrix_fragBt`: `ldmatrix.x<c>` without `.trans` of B's transpose, matrix `m`
   its columns `8 m` to `8 m + 7`, loads the same B (LeanKernel's `exec_tileBt` at `c = 2`).
   `ldmatrix_fragB_cols`, for every `c` and `h`: `ldmatrix.x<ch>.trans` of an `8c × 8h` B tile
   stored row major, matrix `m` its block at rows `8 (m % c)` and columns `8 (m / c)`, loads `h`
   B operands side by side, registers `c o` to `c o + c - 1` gathering to columns `8 o` to
   `8 o + 7`; `ldmatrix_fragB` is its case `h = 1`. The tests: `rows16` is `ldmatrix_gather` at
   `.x4`, `loads16` gives the next three at `m16n8k16` with concrete addresses, and `loadsB2`
   the last at `c = h = 2`, the `.x4.trans` load of a `16 × 16` B tile as two operands.
6. `mmaStep_gather`, for all layouts, `K`, element types and accumulation functions `acc`: when
   A, B and C are `Inv` and the shapes fit (`C.rows ≤ A.rows`, `C.cols ≤ B.cols`,
   `K ≤ A.cols`, `K ≤ B.rows`), the D tile of `mmaStep` on the scattered tiles `TA`, `TB`, `TC`
   is, at every cell `(i, j)` of C, `acc (TA i ·) (TB · j) (TC i j)`.

## The warp-collective step

`mmaStep FA FB FC acc a b c` is the D registers of every lane: lane `l`'s register `r`,
element `s`, is `acc` of row `i` of the A tile gathered from all lanes' `a`, column `j` of the B
tile gathered from `b`, and `C (i, j)`, where `(i, j) = FC.pos l r s`. Each output depends on
other lanes' registers, so the step is collective: the ISA's `.sync.aligned` requires every lane
of the warp to execute the same `mma` (or `ldmatrix`). `Grid.warpReady g size n i` states that
obligation in the grid's terms, as `Grid.fire` checks it for `shfl.sync`: thread `n`'s warp is
whole inside its block of `size` threads and each of its 32 lanes waits at a call of intrinsic `i`
at the same instruction. A lane that has returned, or waits elsewhere, breaks it.

## The accumulation model

The ISA does not specify the arithmetic inside `mma`: it says the accumulation is performed with
at least single precision, and that the order, rounding and subnormal handling of the
accumulation are unspecified; the internal layout of `.tf32` is implementation defined. FloatLib
has no fused multi-term accumulator (its blocked dot products are chains of fused multiply-adds),
so the accumulation is a parameter `acc` of the step, with two models.

- Exact, over `ℝ`: `exactAcc a b c = Σ_k a_k b_k + c`. `mma_exact`: for every set of `Inv`
  layouts of fitting shapes `m × K`, `K × n`, `m × n` and real tensors `TA`, `TB`, `TC`, the D
  tile at `(i, j)` is `get2 (Tensor.matmul TA TB + TC) i j`, TorchLean's matrix product plus C.
- A contract with a stated error: `AccOk bnd acc` says that for finite input words and a finite
  result, `|acc a b c - (Σ_k a_k b_k + c)| ≤ bnd (Σ_k |a_k b_k| + |c|)` over the words' real
  values. `mma_contract`: under `AccOk bnd acc`, a finite D entry is within `bnd` of TorchLean's
  real `matmul TA' TB' + TC'` entry (the tensors mapped by `Model.toReal`). `castDot_ok` is a
  concrete accumulator meeting it: the inputs cast exactly to the accumulator's IEEE format
  (FloatLib's `Model.cast`, exact for bfloat16 to binary32 by `toReal_cast_bfloat16_binary32`)
  and folded from C by `dotLoop`, with `bnd = dotBound fmt K`.

That the hardware's accumulation meets `AccOk` for some `bnd` is a trust item (a reading of the
ISA's precision text, which gives no bound); LeanKernel's bit-level model of one GPU's
accumulation is a candidate for discharging it on that GPU, and it is not used here.

## Not proved

- The grid's dispatch of `ldmatrix` and `mma` to these steps, with the registers' values decoded
  from `Val`s; until then a run reaching them is unsupported.
- `ldmatrix.x1` and `.x2` are modelled here, but the importer recognises only `ldmatrix.x4`
  (with and without `.trans`), so a kernel using the others does not import. The importer reads
  every `mma` shape whose fragments divide among the lanes (`Mma.ok`); `mmaFrags` gives layouts
  to the `m16n8k<k>` ones with tf32, bf16 or f16 inputs and f32 accumulators or in f64, and to
  `m8n8k4 .f64`.
- An `mma` with f16 accumulators: the layout `fragC 2 2` is checked, but the importer reads no
  such name, and its `Mma.regs` counts one accumulator to a register.
- `m8n8k4` with f16 inputs (section 9.7.16.5.1), sparse `mma.sp`, and 8-bit and 4-bit inputs
  against the ISA's tables (the families include `p = 4`, but that this is the ISA's layout is
  not checked here).
- Any bound on the hardware's accumulation (the trust item above).
