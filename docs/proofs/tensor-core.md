# Tensor cores: fragments, `ldmatrix` and `mma` (`Frag`, `Frag.bijOn`, `fragA_inv`, `fragB_inv`, `fragC_inv`, `ldm_inv`, `quad_inv`, `mmaFrags_inv`, `ldmatrix_gather`, `ldmatrix_fragA`, `ldmatrix_fragB_cols`, `ldmatrix_fragB`, `ldmatrix_fragBt`, `mmaStep_gather`, `mma_exact`, `mma_contract`, `castDot_ok`, `fuseAcc_ok`, `gridAcc_ok`, `seqAcc_ok`, `Grid.warpReady`, `mmaWarp_spec`, `ldmWarp_spec`, `Grid.fire_mma`)

Lean: MojoProof/Sem/TensorCore.lean, for the fused accumulation
MojoProof/Sem/TensorCoreAcc.lean, for the steps on run-time values and the grid's step
MojoProof/Sem/TensorCoreWarp.lean, and the definitions the grid runs in
MojoProof/Sem/TensorCoreDef.lean; instances and twins in MojoProofTest/TensorCore.lean,
MojoProofTest/TensorCoreWarp.lean and MojoProofTest/TensorCoreGrid.lean. Most statements are
about functions of the 32 lanes' registers and arguments. The grid runs `llvm.nvvm.mma…` with
bf16 and f16 inputs and an f32 accumulator (`Grid.fire_mma`, "The grid's step"); it reports
`llvm.nvvm.ldmatrix…` and every other `mma` unsupported. See "Not proved".

## The fragment model

The source is the PTX ISA, version 9.5: section 9.7.16.5.14 (`mma`, its "Matrix Fragments for
mma.m…n8k…" tables in sections 9.7.16.5.1-4 and 9.7.16.5.6-11) and section 9.7.16.5.15
(`ldmatrix`), as docs/TRUST.md T14 reads them. The
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
With 8-bit and 4-bit inputs, four and eight to a register (sections 9.7.16.5.3-4 and
9.7.16.5.9-11), `m16n8k32` is `fragA 2 4 2`, `fragB 4 2` in 8 bits and `fragA 2 8 1`,
`fragB 8 1` in 4 bits; `m16n8k16` in 8 bits is `fragA 2 4 1`, `fragB 4 1`; `m16n8k64` in 4 bits
is `fragA 2 8 2`, `fragB 8 2`; `m8n8k16` and `m8n8k32` are `fragA 1 4 1`, `fragB 4 1` and
`fragA 1 8 1`, `fragB 8 1`; the s32 accumulators are `fragC 2 1` and `fragC 1 1`. The importer
reads no such `mma`.
`mmaFrags v` maps the importer's `Mma` to these three layouts for every shape `m16n8k<k>` with a
tf32, bf16 or f16 input and an f32 accumulator, or in f64, `k` a positive multiple of `4 p`
(`p = (abForm v.ab).pack`), and for `m8n8k4 .f64`. `m8n8k4` with f16 inputs, whose layouts
(section 9.7.16.5.1) are not these families, gets none, and since the importer reads no f16
accumulator, `mmaFrags` never gives `fragC 2 2`. That `mma` is four products at once: the quad
pair `q = l % 16 / 4`, lanes `4q` to `4q + 3` and `4q + 16` to `4q + 19`, multiplies its own
`8 × 4` A and `4 × 8` B tiles into its own `8 × 8` accumulator. `quadA t`, `quadB t` and
`quadC p` place the four tiles stacked (product `q` in rows `8 q` to `8 q + 7` of A and C/D and
`4 q` to `4 q + 3` of B), with `u = 4 (l / 16)` and two elements to a register except the f32
accumulator:

| layout | rows × cols | regs | pos l r s |
|---|---|---|---|
| `quadA false` (A, row major) | 32 × 4 | 2 | `(8 q + u + t, 2 r + s)` |
| `quadA true` (A, column major) | 32 × 4 | 2 | `(8 q + u + 2 r + s, t)` |
| `quadB false` (B, column major) | 16 × 8 | 2 | `(4 q + 2 r + s, u + t)` |
| `quadB true` (B, row major) | 16 × 8 | 2 | `(4 q + t, u + 2 r + s)` |
| `quadC 2` (C and D, f16) | 32 × 8 | 4 | `(8 q + u + t, 2 r + s)` |
| `quadC 1` (C and D, f32) | 32 × 8 | 8 | `(8 q + u + l % 2 + 2 (r % 4 / 2), 4 (r / 4) + 2 (t / 2) + r % 2)` |

The product of stacked tiles is block diagonal, so `mmaStep` does not model this `mma`. For
`ldmatrix`, the tile of `ldm q t` is the `q` matrices of 8 × 8 16-bit elements stacked: row
`8 m + i` is row `i` of matrix `m`, whose address lane `8 m + i` gives; `.x1` uses lanes 0-7,
`.x2` lanes 0-15, `.x4` all 32.

These are the conventions of GPUProof's PTX front end (its `aRow`/`aCol`, `bRow`/`bCol`,
`cRow`/`cCol` and its `ldmatrix` destinations), restated here without depending on it. Where we
differ: lanes, registers and elements are numbers with bounds rather than `Fin` and bit vectors;
one theorem covers each family for every `p`, `c` and `q`, where the front end checks shapes one
by one (its `exec_tileA` and `exec_tileBt` are `ldmatrix_fragA` and `ldmatrix_fragBt` at
`c = 2`); `.trans` has a theorem here (`ldm_inv q true`, `ldmatrix_fragB_cols`,
`ldmatrix_fragB`) and none in the front end; and the front end cites PTX ISA 9.4 where we cite
9.5.

## Statements

1. `Frag.bijOn`, for every layout: if `F.Inv`, `pos` is a bijection from the domain onto the tile
   (`Set.BijOn`).
2. `fragA_inv`, `fragB_inv`: for every `h`, `p` and `c`, `(fragA h p c).Inv` and
   `(fragB p c).Inv` (for `p = 0` the tile and the registers are empty); `fragC_inv`: for every
   `h` and `p` 1 or 2, `(fragC h p).Inv` (the twin `fragC_three`: not for `p = 3`); `ldm_inv`:
   for every `q` and both values of `.trans`, `(ldm q t).Inv`; `quad_inv`: for both values of
   the flag and `p` 1 or 2, `(quadA t).Inv`, `(quadB t).Inv` and `(quadC p).Inv`. The tests
   check by `decide`, for every lane, that the layouts at `m16n8k8 .tf32`,
   `m16n8k16 .bf16`/`.f16` and the f32 accumulator put each element where the ISA's tables,
   written in their own form, put it
   (`tableA8`, `tableB8`, `tableA16`, `tableB16`, `tableC`), and likewise the f16 accumulator
   (`tableC16`), `m8n8k4 .f64` (`tableA64`, `tableB64`, `tableC64`), A of `m16n8k4`
   (`tableA4`) and `m16n8k16 .f64` (`tableA16d`, `tableB16d`), the 8-bit and 4-bit inputs
   (`tableA32s8`, `tableB32s8`, `tableA16s8`, `tableB16s8`, `tableA8s8`, `tableA64s4`,
   `tableB64s4`, `tableA32s4`, `tableB32s4`, `tableA8s4`) and `m8n8k4` with f16 inputs
   (`tableQA`, `tableQB`, `tableQC`, the quad pairs written as the ISA's lane ranges); `bijA16`
   is `Frag.bijOn` at `fragA 2 2 2`.
3. `mmaFrags_inv`: for every importer `Mma` value `v` that `mmaFrags` accepts (exactly those of
   `Mma.table`, the one finite list of shapes and types that the importer's `Mma.ok` reads too;
   the layouts' formulas stay general in `m`, `k` and the element count), the three layouts
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
   its columns `8 m` to `8 m + 7`, loads the same B (the front end's `exec_tileBt` at `c = 2`).
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

On run-time values (MojoProof/Sem/TensorCoreWarp.lean), an element is its bit pattern and a
register holds its elements in one of three forms (`RegForm`): `word w`, one `w`-bit scalar
`Val.bits w` (tf32 in an `i32`, f64 in a `double`, the `float` and `double` accumulators);
`pair`, two 16-bit elements in an `i32`, element 0 in the low half (bf16, and `ldmatrix`'s
`b16`); `vec2`, the two lanes of a `<2 x half>` (f16). `RegForm.get` reads element `s` of a
`Val`, `none` for poison, `undef`, a pointer or another width or shape, and `RegForm.put` builds
the register. For every form, a built register reads back as its elements modulo `2 ^ width`
(`RegForm.get_put`), and a register of the form is rebuilt from its elements
(`RegForm.put_elem`).

- `mmaWarp v acc x` is the warp's `mma` of the importer's value `v`, from the 32 lanes'
  arguments `x l` (A, then B in `abForm v.ab`, then C in `accForm v.cd`, as the
  intrinsic's signature types them) to each lane's aggregate of D registers, with the
  accumulation `acc` on bit patterns; `none` when `mmaFrags` rejects `v`, a lane passes another
  number of registers, or a register does not decode. **`mmaWarp_spec`**: for every `v` that
  `mmaFrags` accepts, every `acc` and all tiles of elements of the forms' widths, on the
  arguments that hold the tiles (`encode`) the step succeeds and its results, read in the
  layout of D, are `acc (TA i ·) (TB · j) (TC i j)` at every cell, modulo `2 ^ width`.
- `ldmWarp q t rd x` is the warp's `ldmatrix.x<q>`, lane `R < 8q` passing its row's pointer and
  `rd` reading a 16-bit element at a pointer; `none` when a row's lane passes no pointer or an
  element does not read. **`ldmWarp_spec`**: for every `q` and `t`, when lane `R` passes `P R`
  and element `C` of its row reads as `T R C`, the step succeeds and its results, read in
  `ldm q t`, are `T`.

MojoProofTest/TensorCoreWarp.lean instantiates both at two shapes (`m16n8k16 .bf16` and
`m16n8k8 .tf32`; `.x4` and `.x2`) and runs them on registers written by hand from the ISA's
tables.

## The grid's step

`Grid.fire`'s `mma` arm (MojoProof/Sem/Grid.lean) is the step of the warp of thread `n`: the
warp must lie whole in its block of threads, and `mmaRes` reads the 32 lanes' statuses. A lane
that waits at another collective or another instruction, or has returned, is unsupported; while
a lane runs the result is `none`; when all 32 wait at the same `mma` at the same instruction,
`mmaGrid L.acc v` runs `mmaWarp v` on their arguments with the launch's accumulation policy
`L.acc` on bit patterns (`L.acc.bits fi`, "Accumulation policies"), and each lane resumes with
its aggregate of D registers under its callee's return attributes, the memory unchanged. The
inputs are bf16 and f16 (`gridFmt` gives their formats `fi`) with an f32 accumulator; a call
whose words are not all finite, a shape `Mma.table` does not list, and every other input or
accumulator type are unsupported.

**`Grid.fire_mma`**: for every launch `L`, so every accumulation policy `L.acc`, every warp and
every `mma` of the table with bf16 or f16 inputs and an f32 accumulator
(`mmaFrags v = some (FA, FB, FC)`, `gridFmt v.ab = some fi`, `v.cd = .float`): when the warp lies
whole in its block and each lane `j < 32` waits, from thread `u j`, at the `mma` at the
instruction of thread `n`, with arguments that encode the tiles `TA`, `TB`, `TC` of finite words
in the layouts, and with a callee `d j` none of whose return attributes is a `range`, `nonnull`
or `align`, the step succeeds: `g.fire L c n = .ok (some g')`, where `g'` has the memory of `g`,
every thread outside the warp unchanged and lane `j` running `(u j).resume (some (y j))`, and
`y` read in `FC` is `L.acc.bits fi (TA i ·) (TB · j) (TC i j)` at every cell. The premise on the
return attributes is the weakest the step allows: those three are the attributes `withAttrs`
refuses on an aggregate (a fault, "nonnull or align on a non-pointer" for the latter two), and
every other attribute passes the aggregate of words through. No premise is on the policy. The
lanes' argument functions in the grid (`xs.getD l []`) and in `mmaWarp_spec` (`encode … l`)
agree on the 32 lanes only; `mmaWarp` reads no other lane, which the private lemma
`mmaWarp_lanes` checks on the concrete layouts.

MojoProofTest/TensorCoreGrid.lean instantiates it at `m16n8k16` with f16 inputs and at
`m16n8k8` with bf16 inputs, and runs one program (one block of 32 threads, every lane passing the
same registers) at both shapes, whose stored words are the sums 16.5 and 32.5 (f16) and 8.5 and
16.5 (bf16); the same program with one lane at the other `mma` is unsupported, and with the
intrinsic declared with a `nonnull` return it faults. A warp waiting at `m16n8k24 .bf16`, a
shape the table does not list, with registers of `Mma.regs`' counts, is unsupported, and one at
`m16n8k8 .bf16` steps; with f16 inputs, a warp at `m16n8k32`, another shape the table does not
list, is unsupported, and one at `m16n8k16` steps, each with registers of its own counts and
forms.

## Accumulation policies

The PTX ISA (version 9.5, section 9.7.16.5.14) guarantees of `mma`'s accumulation only that it
is performed with at least single precision; its order, its rounding and its handling of
subnormal inputs are unspecified. So the semantics does not fix one: a policy (`MmaAcc`, in
MojoProof/Sem/TensorCoreDef.lean) is a function that, for every input format `fi`, accumulator
format `fc` and number `K` of products, gives the D word from the `K` input pairs and the C
word, over FloatLib's values. Each launch carries one (`Launch.acc`, `gridAcc` by default), and
`Grid.fire` runs the launch's. Every statement about a grid with an `mma` is quantified over the
launch, so it holds for every policy; one that needs a property of the D words takes a contract
on `L.acc` as a premise, and the premise is only what its proof uses.

- The measured policy, **`gridAcc fi fc = fuseAcc fi fc 8 24`** (the fused, truncating block
  accumulation below), the launches' default: the A100's words at `m16n8k16 .bf16` on every
  recorded launch ("GPU runs"). **`gridAcc_ok`**: for every input format, IEEE accumulator
  format and `K`, it meets `AccBy` with the magnitudes `wt a_k · wt b_k` and `|c| + 2^emin` and
  the bound `fuseBound fc 8 24 ⌈K / 8⌉` (`fuseAcc_ok` at blocks of 8 with 24 bits).
- The sequential policy, **`seqAcc`**: the inputs cast to the accumulator's format (FloatLib's
  `Model.cast`) and folded from C by `dotLoop`, each product and each sum rounded to nearest,
  ties to even, in the order `k = 0, …, K - 1`. **`seqAcc_ok`**: for every IEEE accumulator
  format and input format whose finite words cast exactly, it meets `AccOk (dotBound fc K)`
  (`castDot_ok`).
- The two differ: on one cell of `m16n8k8` with f16 inputs and C = `2^24`, whose products are
  `1`, `-2^24`, `0`, … (the pairs `(1, 1)` and `(-4096, 4096)`), `gridAcc` adds the block
  exactly and gives 1, while `seqAcc` rounds `2^24 + 1` to the even `2^24` and gives `+0`
  (MojoProofTest/TensorCore.lean on the policies, MojoProofTest/TensorCoreGrid.lean on a
  program run at both). So no statement about the D words holds for every policy without a
  contract.

`mma_contract` takes the contract `AccBy mag magC bnd acc` and is instantiated at both policies,
at `m16n8k16 .bf16` (`contract16` with `seqAcc` and `bf16_ok`, `contractFuse` with `gridAcc` and
`fuse16_ok`). `Grid.fire_mma` and `mmaWarp_spec` need no contract: they give the D words as the
policy's value at every cell. One policy covers a whole launch, every warp and every shape; a
device whose accumulation depends on the shape, the warp or the call is a policy of the launch
only if it is a function of the formats, the products and C.

## The accumulation model

The ISA does not specify the arithmetic inside `mma` ("Accumulation policies"); the internal
layout of `.tf32` is implementation defined. FloatLib has no fused multi-term accumulator (its
blocked dot products are chains of fused multiply-adds), so the accumulation is a parameter
`acc` of the step, with three models.

- Exact, over `ℝ`: `exactAcc a b c = Σ_k a_k b_k + c`. `mma_exact`: for every set of `Inv`
  layouts of fitting shapes `m × K`, `K × n`, `m × n` and real tensors `TA`, `TB`, `TC`, the D
  tile at `(i, j)` is `get2 (Tensor.matmul TA TB + TC) i j`, TorchLean's matrix product plus C.
- A contract with a stated error: `AccBy mag magC bnd acc` says that for finite input words and a
  finite result, `|acc a b c - (Σ_k a_k b_k + c)| ≤ bnd (Σ_k mag a_k b_k + magC c)` over the
  words' real values; `AccOk bnd` is `AccBy` with `mag a b = |a b|` and `magC c = |c|`.
  `mma_contract`: under `AccBy mag magC bnd acc`, a finite D entry is within
  `bnd (Σ_k mag + magC)` of TorchLean's real `matmul TA' TB' + TC'` entry (the tensors mapped
  by `Model.toReal`). `castDot_ok` is a concrete accumulator meeting `AccOk`: the inputs cast
  exactly to the accumulator's IEEE format (FloatLib's `Model.cast`, exact for bfloat16 to
  binary32 by `toReal_cast_bfloat16_binary32`) and folded from C by `dotLoop`, with
  `bnd = dotBound fmt K`.
- A fused, truncating block accumulation (MojoProof/Sem/TensorCoreAcc.lean), a function over
  FloatLib's values: `fuseAcc fi fc n p` takes the `K` input pairs `n` at a time, in order, and
  makes each block one pass of an aligning adder from the running value (C for the first). A pass
  gives each addend an exponent (`expAt`: `⌊log₂ |x|⌋`, raised to the least normal exponent; a
  product's is the sum of its factors'), truncates every addend toward zero to a multiple of
  `2^(E - p)`, `E` the largest exponent of a nonzero addend (`fuseSum`), adds them exactly, and
  rounds the sum toward zero with FloatLib's `roundRat` (`fuseRound`): beyond the largest finite
  magnitude it gives that magnitude with the sum's sign below `2^(emax + 1)`, emax the largest
  normal exponent, and the infinity of its sign from there on. `fuseAcc_ok`: for every input format,
  IEEE accumulator format, block size `n ≥ 1`, `p` and `K`, it meets `AccBy` with the magnitudes
  `wt a_k · wt b_k` and `|c| + 2^emin` (`wt x = max |x| 2^emin`, emin the least normal exponent) and
  the bound `fuseBound fc n p J W = ((1 + α)^J - 1)(W + η / α)`, with `J = ⌈K / n⌉` blocks,
  `α = (n + 1) 2^-p (1 + u) + u` and `u`, `η` FloatLib's toward-zero unit roundoff and underflow
  error. The proof goes up from a pass: the truncation moves each of the at most `n + 1` addends by
  at most `2^-p` times the largest one's power of two (`fuseSum_err`), the rounding is within
  FloatLib's toward-zero error (`fuseRound_err`), so a block errs by at most
  `α (|r| + 2^emin + Σ wt wt) + η` (`fuseStep_err`), and an induction on the blocks gives the bound
  (`fuseFold_err`). Nothing in it is fitted to a measurement. The tests instantiate it at 16
  products in blocks of 8 with 24 bits (`fuse16_ok`, the A100's accumulation on every recorded
  launch below) and at 8 in blocks of 4 (`fuse8_ok`), and `mma_contract` with each at `m16n8k16` and
  `m16n8k8` (`contractFuse`, `contract8`).

That a GPU's accumulation is a given policy, or meets `AccBy` for some magnitudes and bound, is
a trust item (a reading of the ISA's precision text, which gives no bound; docs/TRUST.md T14).
A statement about a grid covers a GPU for every policy; one that takes a contract covers it only
if the GPU's accumulation meets the premise. The GPU runs below support, without proving it,
that an A100's `m16n8k16 .bf16` accumulation is `gridAcc`, which meets its contract by
`gridAcc_ok`. The bit-level model of one GPU's accumulation in GPUProof's PTX front end is
another candidate, and it is not used here.

## GPU runs

tests/gpu/mma/record.txt is a conformance test, not a proof: one warp's
`mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32` on an NVIDIA A100 (sm_80), 20 launches on
registers from a seed (random inputs of nine kinds and two fixed probes), the 32 lanes' A, B, C
and D registers dumped. MojoProofTest/TensorCoreGpu.lean (run by tests/gpu/mma/Compare.lean)
evaluates `mmaStep (fragA 2 2 2) (fragB 2 2) (fragC 2 1)` on the dumped registers with
`gridAcc .bfloat16 .binary32` (printed as `fuseAcc`), with `seqAcc .bfloat16 .binary32`
(printed as `bfAcc`; `bf16_ok` puts it within `dotBound .binary32 16`) and with the exact
rational sum, and compares each D word; `dotBoundQ_eq` says that its rational bound is
`dotBound .binary32 K`.

- All 2,560 D words, infinities included, are `fuseAcc`'s bit for bit. Besides small integers,
  normal numbers, any finite words, subnormal times large elements, products about the least
  normal number and an alignment probe (D = 1 + 15 equal small products at 23 distances below
  1), the launches test the model on cancelling pairs of products, wide exponent spreads,
  subnormal and mixed products and sums near overflow; an overflow-threshold probe fixes
  `fuseRound`'s middle case: a sum between the largest finite magnitude and `2^128` gives the
  largest finite word, not an infinity.
- On the two launches of small integers, where every partial sum is exact and so every order of
  the additions gives the same word, all 256 D words are also `bfAcc`'s: the hardware pairs the
  elements as the library's layouts at `m16n8k16 .bf16` say.
- Of the 2,025 other finite D words, 2,024 are within `dotBound .binary32 16 T` of the exact sum
  and one is not: |D - exact| is 18.9 u T (u = 2^-24), 1.11 times the bound, on a sum of
  products of subnormal bfloat16 elements with large ones, and the word is `fuseAcc`'s. So the
  A100's accumulation does not meet `AccOk (dotBound .binary32 16)`; and no fold from C in some
  order of the products, each addition rounded to nearest (fused or not), gives that word, since
  `castDot_ok` puts every such fold within the bound.
- The runs do not separate `fuseAcc` from every other accumulation: another block size,
  truncation width or exponent rule that gives the same words on these inputs is not excluded.

tests/gpu/ldmatrix/record.txt is a second conformance test: one warp's `ldmatrix.x4` and
`ldmatrix.x4.trans` on the A100, 8 launches, each from 512 random 16-bit words of shared memory
at row addresses from the seed (in order in the first launch, random multiples of 16, repeats
allowed, in the others). `ldmCompare` (MojoProofTest/TensorCoreGpu.lean, run by
tests/gpu/ldmatrix/Compare.lean) compares every element of the dumped registers with
`ldmatrix 4 false` and `ldmatrix 4 true` on the dumped words and addresses: all 4,096 agree. So
on these inputs the hardware's `ldm 4 t` is the library's, plain and transposed.

## Not proved

- The grid's dispatch of `ldmatrix`. Its rows are reads of shared memory, and a completed
  collective call is a function of the waiting threads' statuses that changes no memory: every
  `Grid.fire_*` statement says so (`Grid.fire_frame`: the results are the same on every grid
  with those statuses; `Grid.fire_blocks`, `Grid.mem_fired`). A fire that reads memory needs
  those statements to change: the results a function of the memory too, the reads logged as
  accesses of the warp's lanes, and `Grid.advance_fire_comm`'s premise extended to a step that
  writes the rows. Until then `Grid.fire` reports `ldmatrix` unsupported, and that `ldmWarp`'s
  reader is the memory's 16-bit load of shared memory is not stated.
- The grid's `mma` on other types than bf16 and f16 inputs with an f32 accumulator: a call whose
  operands do not decode, or with a word that is not finite (where `fuseAcc` reads 0), and every
  other type (tf32, whose internal layout is implementation defined, and f64, not measured) stay
  unsupported. A completed call depends on nothing but the statuses and the launch's policy (no
  context's payload choices).
- A policy that varies within a launch: `Launch.acc` is one function for every warp, call and
  shape. A device whose accumulation depends on more than the formats, the products and C is not
  a policy of the semantics.
- `ldmatrix.x1` and `.x2` are modelled here, but the importer recognises only `ldmatrix.x4`
  (with and without `.trans`), so a kernel using the others does not import. The importer reads
  the `mma` shapes of `Mma.table` (`Mma.ok`), the ones the ISA lists for f16 and bf16 inputs
  with f32 accumulators, tf32 and f64, without `m8n8k4` with f16 inputs; `mmaFrags` gives layouts
  to exactly those, from the same table.
- An `mma` with f16 accumulators: the layout `fragC 2 2` is checked, but the importer reads no
  such name, and its `Mma.regs` counts one accumulator to a register.
- `mma` on `m8n8k4` with f16 inputs: its layouts are checked, but no step multiplies the quad
  pairs' tiles. `mma` on 8-bit and 4-bit inputs: the layouts are checked, but the importer reads
  no such name and no step accumulates integers. Sparse `mma.sp`, and `.b1` inputs.
- A GPU record of `m8n8k4` with f16 inputs or of an 8-bit `mma`. With Mojo 1.3.0.dev2026112105
  the library's `mma` at `m8n8k4` does not compile for sm_80: it calls
  `llvm.nvvm.mma.m8n8k4.row.col.f32.f32` with one f16 for each of A and B and expects two floats
  back, where the intrinsic returns eight (and `….f16.f16` two halves, where it returns four
  `<2 x half>`). The library's only 8-bit `mma` is fp8 (e4m3, e5m2) at `m16n8k32` in inline PTX,
  which ptxas accepts only from sm_89, so the A100 cannot run it; it has no `s8` or `u8` `mma`.
- That the hardware's accumulation is a given policy or meets a contract (the trust item above).
  The GPU runs show that `dotBound .binary32 16` is not a bound for the A100 at
  `m16n8k16 .bf16`, so it is not `seqAcc` there, and that its words on the recorded launches are
  those of `gridAcc`, which meets `AccBy` with `fuseBound` by `gridAcc_ok`; that it computes
  `gridAcc` on other inputs, shapes or types is not tested.
