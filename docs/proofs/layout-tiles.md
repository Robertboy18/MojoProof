# Written tiles give the tensor (`Block.holds_of_tiles`)

Lean: proved, in MojoProof/Sem/Buffer.lean: `stride_lt`, `Apart`, `Apart.comp`, `apart_stride`,
`apart_rowMajor`, `rowMajor_inb`, `Block.holds_of_tiles`, `Block.read_puts`, `Block.holds_puts`;
in MojoProof/Sem/Trace.lean: `Tiling.ofApart`, `Tiling.strided`. Instances: MojoProofTest/Tiles.lean
and the `vector_addition` check in MojoProofTest/Eval.lean.

**Where the Lean differs from the statements below.**
- `Block.read_puts` is stated for every index type `ι` with decidable equality and every `n` (bytes
  `bs i` of length `n` at offsets `n` apart), not only for coordinates and `l.stored t`. For a tile not in
  the list it is the frame, so corollary 2 (`Block.puts_frame`, a byte frame) is not stated: nothing uses
  it.
- Corollary 3 (`Block.holds_rowMajor`) is not a theorem. Its two premises are the lemmas
  `apart_rowMajor` and `rowMajor_inb` (`rowMajor l t base i + l.stored t ≤ base + Shape.size s *
  l.size t`), and the instance applies `Block.holds_puts` to them directly (MojoProofTest/Tiles.lean,
  `holds`).
- The stride arithmetic is one lemma, `stride_lt : a < b → a * w + w ≤ b * w`. `apart_stride` is stated
  for `Nat` indices; `apart_rowMajor` is `apart_stride` composed with `linearize`, and `Tiling.strided`'s
  disjointness is `apart_stride` composed with `Fin.val`. `rowMajor_inb`, `Tiling.strided`'s bound and
  the bound inside `Mem.holds_alloc` also use `stride_lt`, so the arithmetic is proved once.
- `Tiling.strided` takes a base offset (`Tiling.strided base n w`); `racy_kept_pointwise` uses base 0.

**Scope.** Every layout `l`, type `t`, codec `enc`, shape `s`, offset map `off`, coordinate function `f`
and block. It is a statement about bytes, not about a program. A kernel is covered once a run's final
output block meets the premise `hw`. Showing that (each tile's last write is its owner's, with the bytes
of `enc (f i)`) is the summary's job (T3, T4), and it is not part of this proof.

## Statement

**Data.**
- `Block.Holds l t enc off x blk`: for every coordinate `i`, the `l.stored t` bytes of `blk` from `off i`
  lie in the block and decode to `enc (x i)` (MojoProof/Sem/Buffer.lean).
- `Layout.Codec l t enc`: `enc` is injective, and each `enc a` encodes to `l.stored t` bytes that decode
  back to it (`Codec.round`).
- `Tensor.Rep.ofFn f`: the TorchLean tensor with `x i = f i` (`Tensor.Rep.get_ofFn`).

```lean
theorem Block.holds_of_tiles {blk : Block} (hc : l.Codec t enc) {f : Shape.Coord s → α}
    (hin : ∀ i, off i + l.stored t ≤ blk.size)
    (hw : ∀ i, l.encode t (enc (f i)) = some (blk.read (off i) (l.stored t))) :
    blk.Holds l t enc off (Tensor.Rep.ofFn f)
```

The premise is per tile and does not depend on order: the bytes at tile `i` are the encoding of
`enc (f i)`. The form "the final block equals the initial block with `enc (f i)` written at tile `i`
for every `i`" is the corollary `Block.holds_puts` below. That corollary is where the tiles must be apart.

**Corollaries.**

1. Writes in any order (`Block.holds_puts`). Let `hap : Apart off (l.stored t)`, and let
   `hbs : ∀ i, l.encode t (enc (f i)) = some (bs i)`. Let `is : List (Shape.Coord s)` contain every
   coordinate, in any order and with repetitions allowed. Then
   `(is.foldl (fun b i => b.put (off i) (bs i)) blk).Holds l t enc off (Tensor.Rep.ofFn f)`, given `hin`
   for `blk`.
2. Frame (`Block.puts_frame`). If byte `o` lies outside every tile
   (`∀ i ∈ is, o < off i ∨ off i + l.stored t ≤ o`), then `(is.foldl …).bytes o = blk.bytes o`.
3. Row-major (`Block.holds_rowMajor`). Corollary 1 with `off := rowMajor l t base` and `hap :=
   apart_rowMajor l t base`. `hin` follows from `base + Shape.size s * l.size t ≤ blk.size`, because
   `l.stored t ≤ l.size t` (`stored_le_size`) and `linearize i < Shape.size s`.
4. The tiling for ownership (`Tiling.ofApart`). Offsets that are `n` apart and in bounds form a
   `Tiling ι` with `len _ := n`: `disj` is `Apart`, and `inb` is the bound. With `rowMajor`, this is the
   `T` that `Owned` (MojoProof/Sem/Trace.lean) needs for an output tensor. It connects the written
   tiles to race freedom by ownership: the tiles of ownership are the layout's.
   - **No duplicate.** `Tiling.strided n w` (Trace.lean, used by `racy_kept_pointwise`) is the same
     tiling for `ι := Fin n`, and its `disj` would repeat the arithmetic of `apart_rowMajor`. So:
     - `Apart` is stated for `ι → Nat`, not only `Shape.Coord s → Nat` (its definition uses nothing of
       the shape);
     - the arithmetic is proved once, as `apart_stride : n ≤ w → Apart (fun k : Fin m => base + k * w) n`,
       with `Apart.comp : Apart off n → Function.Injective g → Apart (off ∘ g) n`;
     - `apart_rowMajor` is `apart_stride` composed with `linearize` (`linearize_injective`);
     - `Tiling.strided`'s disjointness is `apart_stride` composed with `Fin.val`.
   - **Imports.** `Tiling` and `Tiling.ofApart` are in Trace.lean, which imports Buffer.lean, where
     `Apart` is.

## Proof

**`Block.holds_of_tiles`.** Fix `i`. The bounds conjunct is `hin i`. By `hc.round (f i)` there are bytes
`bs` with `l.encode t (enc (f i)) = some bs`, `bs.length = l.stored t` and
`l.decode t bs = some (enc (f i))`. By `hw i`, `bs = blk.read (off i) (l.stored t)`, so the read decodes to
`enc (f i)`, which is `enc ((Tensor.Rep.ofFn f) i)` by `Tensor.Rep.get_ofFn`.

**`Block.holds_puts`.**
- Lemma (`read_puts`), by induction on `is`, generalizing `blk`:
  `(is.foldl ...).read (off i) (l.stored t)` is `bs i` if `i ∈ is`, and `blk.read (off i) (l.stored t)`
  otherwise. For `j :: is`, the fold is `is.foldl ... (blk.put (off j) (bs j))`, and the induction
  hypothesis is used at the block `blk.put (off j) (bs j)`.
  - If `i ∈ is`, it gives `bs i`.
  - If `i ∉ is`, it gives `(blk.put (off j) (bs j)).read (off i) (l.stored t)`. Then:
    - if `i = j`, this is `bs i` by `Block.read_put_self`, because `(bs j).length = l.stored t` (from
      `hbs` and `hc.round`, since `encode` is a function);
    - if `i ≠ j` (so `i ∉ j :: is`), it is `blk.read (off i) (l.stored t)` by `Block.read_put_apart`, by
      `hap i j`.
- `Block.put` keeps `size`, so `hin` holds for the folded block. Every `i` is in `is`, so the lemma gives
  `hw` with `hbs`, and `Block.holds_of_tiles` applies.

**`Block.puts_frame`.** By induction on `is`: `Block.put` at `off j` changes only the bytes from `off j` to
`off j + (bs j).length`, and `(bs j).length = l.stored t`.

**`Block.holds_rowMajor`** is substitution. **`Tiling.ofApart`** is a definition. Its two fields are the
premises.

**`apart_stride`.** For `k ≠ k'`, take `k < k'`. Then `base + k * w + n ≤ base + (k + 1) * w ≤ base + k' * w`,
by `n ≤ w`. This is the arithmetic `apart_rowMajor` and `Tiling.strided` each do
(`Nat.mul_le_mul_right`, `Nat.succ_mul`, `omega`). **`Apart.comp`.** `g i ≠ g j` follows from `i ≠ j` by
injectivity.

## Lemmas used

All are proved, in MojoProof/Sem/Buffer.lean unless marked:
- `Layout.Codec.round` (Buffer.lean), `Block.read_put_self`, `Block.read_put_apart`,
  `Layout.stored_le_size`;
- `Tensor.Rep.get_ofFn` (TorchLean/Tensor/Rep.lean:340); `Shape.Coord.linearize_injective`
  (TorchLean/Tensor/Shape/Coord.lean:161).

`Tensor.Rep.ofFn` needs `[Storage α]`. Buffer.lean has `variable [Storage α]`, and TorchLean's
`instArrayStorage` (low priority, every type) covers `BitVec 32` and the FloatLib floats.

## Dependencies

- `Block.Holds`, `Layout.Codec`, `Apart`, `rowMajor`, `apart_rowMajor`
  (MojoProof/Sem/Buffer.lean);
- `Block.read`, `Block.put` (MojoProof/Sem/Value.lean). `Block.put` changes only `bytes`, so
  it keeps `size`;
- `Tiling`, `Tiling.strided`, `Owned` (MojoProof/Sem/Trace.lean), for corollary 4;
- `Tensor.Rep`, `Tensor.Rep.ofFn`, `Shape.Coord`, `Shape.Coord.linearize` (TorchLean).

## Instances and twins

All three are written: the first two are theorems in MojoProofTest/Tiles.lean (`holds_both`,
`swapped`, and `holds`, for every tensor of shape `[2]` and every order listing both coordinates;
also `tiling`, the row-major tiles as a `Tiling.ofApart`). The third is `vadd (written tiles)` in
MojoProofTest/Eval.lean (`runF32` with `tiles`), with the negative twin `vadd (swapped tiles)`: checked
against the reference of the neighboring element (`i ^^^ 1`), tile 0 fails.

- **Two `i32` elements.** Use `Codec.int l 32`, shape `[2]`, `off := rowMajor l (.int 32) 0`, a layout
  with `l.size (.int 32) = 4`, and an 8-byte block. Let `f` be 5 at coordinate 0 and 7 at coordinate 1, as
  `BitVec 32`. The encodings are `leBytes 4 5` and `leBytes 4 7` (`Codec.int`'s `round`, with
  `(32 + 7) / 8 = 4`). Writing them at 0 and 4, in either order, gives a block that holds `ofFn f`. This is
  corollary 3, with both orders listed.
- **Its negative twin.** Write the two encodings at swapped tiles, 7 at 0 and 5 at 4. That block holds
  `ofFn f'`, where `f'` is 7 at coordinate 0 and 5 at 1, by corollary 3. So it does not hold `ofFn f`:
  `Block.holds_inj` (Buffer.lean) would make `ofFn f' = ofFn f`, and `get_ofFn` at coordinate 0 gives
  7 = 5. This is the tiling `off 0 = 4`, `off 1 = 0` (the counterexample with tiles at offsets 4
  and 0). The theorem does not exclude it. The theorem names
  the tensor the block does hold, at the offsets the premise uses.
- **`vector_addition`, one launch (evaluated).** `runF32` (MojoProofTest/Eval.lean) reads the
  output of the launch by one `Mem.load` of the whole array. `check` (with `isF32`) compares
  each element with FloatLib's `Model.add` of the inputs, bit for bit, and accepts any NaN when the sum is
  a NaN.
  - The written-tiles check runs on the same final block: `hw` with `Codec.float l .float`, `rowMajor` from 0, and
    `f i` the float decoded at tile `i`. For each `i`, `f i` must also pass `isF32` against `Model.add` of
    the inputs.
  - `f` is read off the block, not given as `Model.add`, because NaN payloads may differ.
  - It covers one launch, not the kernel.
