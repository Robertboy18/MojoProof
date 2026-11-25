# The precondition of a binary elementwise kernel, and its satisfiability

Lean: MojoProof/Sem/Precond.lean; instances and twins in MojoProofTest/Precond.lean.

**Scope.** The codecs, `Mem.Closed.alloc`, `Map2.Pre` and `Map2.pre_mem` are for every layout, element
type with a codec, length, inputs, element count, alignment and address choice the pointer widths
admit. `pre_starts` (the precondition gives the start and W1) is for one program, `vector_addition`
(`Kernels.vadd`), and every memory meeting the precondition, launch, address choice and oracle.
`byval_codec` and `pre5` are one layout (`vadd`'s) and one memory. `Mem.allocs` and
`Mem.allocs_spec` are for every number of blocks; `Mem.three`, `Mem.three_spec`,
`Mat.Pre` and `Mat.pre_mem` (the matmul precondition) and the store forms `Mem.store_blocks`,
`Mem.Buffer.store`, `Mem.Fits.store` and `Mem.Holds.store` are for every layout, element type,
size, stride and store; `preN` and its twins are one layout (the naive matmul kernel's) and one
memory.

## Statement

`Map2.Pre l t enc al z m a b o n x y`, for tensors `x y : Tensor α [N]`:
- `closed`: `m` is closed (`Mem.Closed`) under the arguments `Map2.args z a b o n`, which are three
  structures `.agg [.ptr ⟨c, 0⟩, z]` for `c = a, b, o` and the i32 `n`;
- `ne`: `a`, `b` and `o` are distinct;
- `bufs`: each is a live global buffer (`Mem.Buffer`: space 1, owned by all threads) of at least
  `n * l.size t` bytes at addresses in space 1 and in the generic space that `al` divides; `a` and
  `b` are read-only and `o` is writable;
- `x`, `y`: `a` holds `x` and `b` holds `y` row-major from offset 0 (`Mem.Holds`);
- `le`, `lt`: `n ≤ N` and `n < 2 ^ 31`;
- `fits`: the first `n * l.size t` bytes of each of `a`, `b` and `o` have generic addresses
  below `2 ^ w`, `w` the pointer width of address space 0 (`Mem.Fits l c (n * l.size t)`: the
  block's `gaddr` plus that size is at most `2 ^ w`).

## Why each clause is there

- `closed`: `Grid.start` checks the caller's memory (`Mem.checkClosed`), and `Mem.Closed` passes the
  check (`Mem.checkClosed_of_closed`); it also gives `m.BytesIn m.Known` (`Mem.Closed.bytesIn`), the
  premise of `Grid.start_reach_closed` (W1 from the start) and of `Grid.owned_sound`.
- `ne`: an output that overlaps an input makes the kernel an in-place update. `alias_twin` shows the
  start does not see it.
- `bufs`: the kernel's loads and stores go through `Mem.check` (live, owner, bounds, alignment).
- `x`, `y`: the observation of the inputs (`Mem.tensor_eq`) and the values the loads give
  (`Mem.load_holds`).
- `le`, `lt`: the guard `icmp slt i, n` compares the i32 count as a signed number, which is `n` only
  below `2 ^ 31`.
- `fits`: `vector_addition`'s `getelementptr inbounds` into a buffer is `poison` when the address
  wraps `2 ^ 64`, and the load through it then faults. `Mem.Buffer` and `Mem.Closed` allow such a
  block; with `Mem.Fits`, `addr_buffer` (MojoProof/Sym/OblLemmas.lean) gives the addresses without wrap
  that the geps need.

## The byval arguments

The caller passes values, not blocks: `launchArgs` (MojoProof/Sem/Thread.lean) encodes each value at
its `byval` type into a new block per thread, and the kernel loads `{ ptr, { { {} }, { {} } } }` back
from it. So the kernel needs `decode` after `encode` to be the identity at that type.

- `Layout.ptrOf_range`: for every pointer `p` and `n > 0`, `ptrOf` of `.ptr p 0, ..., .ptr p (n - 1)`
  is `p`. Proof: the list starts with `.ptr p 0`, contains no `poison` or `undef`, and is the list
  `ptrOf` compares it with.
- `Layout.Codec.ptr`: for every layout and address space whose pointers have at least one byte,
  `Val.ptr` is a codec. `encode` gives those bytes, of length `storeSize`, and `ptrOf_range` decodes
  them.
- `Layout.Codec.ptrArg`: for every layout, address space as above, and type `u` of size 0 whose value
  `z` is defined, encodes to `[]` and decodes from `[]`, `p ↦ .agg [.ptr p, z]` is a codec for
  `.struct [.ptr a, u]`. Proof: the field offsets are 0 (`roundUp_zero`) and `u`'s stored size is 0
  (`stored_le_size`), so the encoding is the pointer's bytes followed by padding; the first slice is
  the pointer's bytes (`List.take_left'`), the second is empty, and `decodeFields` gives the
  structure back. At `vadd`'s layout and `{ { {} }, { {} } }` the premises hold by evaluation
  (`byval_codec`).

## Satisfiability

`Map2.mem` builds a memory from `{}` by three `Mem.alloc`: blocks 1 and 2 hold `tensorBytes` of `x`
and `y` (read-only), block 3 has `no` undefined elements (writable). `Map2.pre_mem`: if the codec's
values name no block, `n ≤ N`, `n < 2 ^ 31`, `n ≤ no`, the addresses `A i * al` are below
`2 ^ w₁` (`hA`, `w₁` the pointer width of space 1), `G i * al + n * l.size t ≤ 2 ^ w₀` (`hG`, `w₀`
the generic space's: room for the `n` elements below `2 ^ w₀`), and `z` names no block, then `Map2.mem` meets `Map2.Pre` at blocks 1, 2
and 3.

Proof.
- `closed`: `Mem.Closed.alloc` three times from `Mem.closed_empty`. An allocation at the next number
  whose initial bytes name numbers below `next` keeps a memory closed under every list of values
  naming numbers up to the new block's: `pos` and `null` since `next` stays positive and block 0 is
  not allocated, `above` since the new block is at the old `next`, and `bytes` from the initial bytes
  (`mem_of_getD`) or the old memory. The tensors' bytes name no block (`tensorBytes_namesIn`, from
  `encode_namesIn`), and the arguments name blocks 1, 2 and 3 only (`Val.bounds` is 4).
- `ne`: by evaluation.
- `bufs`: the fields are `Mem.alloc`'s; the sizes from `n ≤ N` and `n ≤ no`; the addresses are
  `A i * al` and `G i * al` reduced modulo the pointer width. That leaves `A i * al` unchanged, and
  `G i * al` too unless it is `2 ^ w₀` (only when `n * l.size t = 0`), where it becomes 0, which
  `al` divides as well.
- `fits`: the generic address is `G i * al % 2 ^ w₀ ≤ G i * al` (`Nat.mod_le`), so `hG` bounds it
  plus `n * l.size t`.
- `x`, `y`: `Mem.holds_alloc`.

## Instance and twins (MojoProofTest/Precond.lean)

- `byval_codec`: `Codec.ptrArg` at `vadd`'s layout and `byval` type.
- `pre5`: binary32 inputs of length 5 (`x5`, `y5`), `n = 5`, alignment 16, block `i + 1` at address
  `16 (i + 1)` in both spaces (so `hG` is `16 (i + 1) + 20 ≤ 2 ^ 64`, by evaluation); `memX`
  meets `Map2.Pre`, `fits` included.
- `pre_starts`: for every memory meeting `Map2.Pre` with `vadd`'s tail value, every launch, address
  choice and oracle, `vadd` starts on `Map2.args` (`SymLaunch.vadd_starts`), and every grid
  reachable from the start is closed (`Grid.start_reach_closed`). `start5` is it at `memX`.
- Twins: the output at block 1, the first input: `memX` is closed for the arguments and `vadd` starts,
  but `Map2.Pre` fails (`alias_twin`); the output at block 7, which `memX` does not have: `memX` is not
  closed for the arguments (`missing_twin`); `memW`, `memX` with every block's generic address
  `16 (2 ^ 60 - 1)`: block 1 is an input buffer of 20 bytes (`Mem.Buffer`) but does not fit
  below `2 ^ 64` (`¬ Mem.Fits`), and `pre_mem`'s `hG` fails at that address (`fits_twin`).

## The precondition of a matmul kernel

`C[r][c] = Σₖ<K A[r][k] B[c][k]` for `r < m`, `c < n`, over row-major buffers with row strides
`sA`, `sB`, `sC`. The naive kernel (`matmul_kernel_naive`, tests/corpus/mgemm/) takes `C`, `A`, `B`
as three `byval` structures `{ ptr, { { {}, {} }, { {}, {} } } }`, then the i32 `m`, `n`, `K`; it
loads `A` at `row * 768 + k`, `B` at `col * 768 + k` and stores `C` at `row * 50257 + col`, so
there `sA = sB = 768` and `sC = 50257`.

`Mat.args z o a b m n K` is `[.agg [.ptr ⟨o, 0⟩, z], .agg [.ptr ⟨a, 0⟩, z], .agg [.ptr ⟨b, 0⟩, z]]`
followed by the i32 words of `m`, `n` and `K`: the output first, as the kernel takes it.

`Mat.Pre l t enc al z mem o a b m n K sA sB sC x y`, for `x : Tensor α [m, sA]` and
`y : Tensor α [n, sB]`:
- `closed`: `mem` is closed under `Mat.args z o a b m n K`; so `mem.BytesIn mem.Known` is
  `closed.bytesIn` (`Mem.Closed.bytesIn`), as `Kernel.sound_map2` gets it from `Map2.Pre`;
- `ne`: `o`, `a` and `b` are distinct, so the output overlaps no input;
- `bufs`: `a` and `b` are read-only and `o` writable live global buffers (`Mem.Buffer`) of
  `m * sA`, `n * sB` and `m * sC` elements (times `l.size t` bytes) at addresses `al` divides;
- `x`, `y`: `a` holds `x` and `b` holds `y` row-major from offset 0 (`Mem.Holds`);
- `le`: `n ≤ sC`, `K ≤ sA` and `K ≤ sB`: a row of `C` has room for `n` cells and a row of `A` or
  `B` for `K` elements;
- `lt`: `m * sC`, `m * sA` and `n * sB` are below `2 ^ 31`, so the kernel's i32 products
  `row * sC + col`, `row * sA + k` and `col * sB + k` do not wrap (`NaiveSpec.At.dims` with the
  strides as parameters);
- `fits`: the three buffers' bytes have generic addresses below `2 ^ w` (`Mem.Fits`).

At `sA = sB = 768`, `sC = 50257`, alignment 4 and binary32, `bufs`, `x`, `y`, `le` and `lt` are
the buffer facts and `dims` of `NaiveSpec.At` on the caller's memory.

`Map2.Pre` is not `Mat.Pre` at `m = 1`: `Map2.args` lists the two inputs, then the output, then
one i32 count, and `Map2.Pre`'s tensors are vectors read at the same index. The two share their
three allocations, `Mem.three_spec` below.

**Satisfiability.** `Mem.allocs l al k S R I A G` is the memory of `k` live global allocations
owned by all threads from `{}`, for every `k`: block `i + 1` (`i : Fin k`) of `S i` bytes,
read-only exactly if `R i`, whose first bytes are `I i`, at addresses `A i * al` and `G i * al`.
`Mem.allocs_spec`: if no `I i` holds a pointer byte, `n i ≤ S i`, `A i * al < 2 ^ w₁` and
`G i * al + n i ≤ 2 ^ w₀`, then the memory is closed under every list of values naming numbers
up to `k` (`Val.bounds vs ≤ k + 1`), and block `i + 1` is a `Mem.Buffer` of `n i` bytes, writable
exactly if not `R i`, that fits (`Mem.Fits`). Proof: by induction on `k`; the memory's `next` is
`k + 1`, so `Mem.Closed.alloc` extends the closed memory and the last block is the new one, while
the earlier blocks carry over (`Mem.Buffer.of_block`, `Mem.Fits.of_block`). `Mem.three` is
`Mem.allocs` at `k = 3` unrolled, and `Mem.three_spec` is `Mem.allocs_spec` at 3. `Map2.pre_mem`
is `Mem.three_spec` at `Map2.mem` (which is `Mem.three` by unfolding) plus `Mem.holds_alloc`
twice. A second size: `allocs5` (MojoProofTest/Precond.lean), five blocks of 20 bytes.

`Mat.mem l t enc al x y sC A G` is `Mem.three` with block 1 the output (`m * sC` undefined
elements, writable), blocks 2 and 3 the bytes of `x` and `y` (read-only). `Mat.pre_mem`: if the
codec's values name no block, `n ≤ sC ∧ K ≤ sA ∧ K ≤ sB`, the three products are below `2 ^ 31`,
`A i * al < 2 ^ w₁`, `G i * al` plus the size of block `i + 1` is at most `2 ^ w₀`, and `z` names
no block, then `Mat.mem` meets `Mat.Pre` at `o = 1`, `a = 2`, `b = 3`. Proof: `Mem.three_spec`,
`Mem.holds_alloc` for `x` and `y`, and the arguments name blocks 1 to 3 only.

**Instance and twins** (MojoProofTest/Precond.lean). `preN`: the naive kernel's layout, binary32,
alignment 4, strides 768, 768, 50257, `m = 2`, `n = 3`, `K = 5`, inputs whose cells differ
(`xN`, `yN`), block `i + 1` at address `4 (i + 1)`. `overlap_twin`: with the output at block 2,
the input `A`, the memory is closed for the arguments but `Mat.Pre` fails. `absent_twin`: with
the output at block 7, which the memory does not have, `Mat.Pre` fails (the memory is not closed for
the arguments).

## Stores and logs at other blocks

`Mem.log` changes only the trace, so `(m.log e).blocks = m.blocks` by definition, and `Mem.Buffer`,
`Mem.Fits` and `Mem.Holds` of `m.log e` are those of `m`. `Mem.store_blocks`: a store that succeeds
at a pointer into block `p.block ≠ q` keeps `m.blocks q` (`Mem.store_inv`: the store is a
`Mem.set` at `p.block` and a log). So `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` at `q` carry over
(`Mem.Buffer.store`, `Mem.Fits.store`, `Mem.Holds.store`). `store_x` (MojoProofTest/Precond.lean):
a store of a float at block 3 of `memX` succeeds and keeps `pre5.x`, the first input at block 1.

## Not covered

- The kernel's run: it is not in this file. The kernel theorem `vadd.correct`
  (MojoProof/Kernels/Vadd.lean, kernel.md) composes `Map2.Pre` with the start and the block
  summaries.
- Inputs that alias each other: `a = b` is excluded by `ne`, though `vadd` would compute the right
  result on it.
- Layouts with a non-empty runtime part (a dynamic `LayoutTensor`): `Codec.ptrArg` needs `u` of
  size 0.
