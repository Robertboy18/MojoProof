import MojoProof.Sem.Trace

/-!
# Instances of `Block.holds_puts`, and the swapped-tile twin

Two `i32` elements, 5 at coordinate 0 and 7 at coordinate 1, in an 8-byte block of `undef`
bytes under the default layout, row-major from offset 0 (tiles at 0 and 4). Writing their
encodings tile by tile gives a block that holds the tensor `[5, 7]`, in either order
(`holds_both`, by `Block.holds_puts`; `holds` is the instance for every tensor of shape `[2]` and
every order that lists both coordinates). The twin writes the same encodings at swapped tiles,
7 at 0 and 5 at 4: that block holds `[7, 5]` and not
`[5, 7]` (`swapped`). The row-major tiles are a `Tiling` (`tiling`, by `Tiling.ofApart`), the
form `Owned` takes. These are statements about bytes, not about a kernel.
-/

namespace MojoProofTest.Tiles

open MojoProof.LLVM MojoProof.Sem TorchLean

/-- The default layout: an `i32` takes 4 bytes. -/
abbrev l : Layout := {}

/-- Row-major offsets of a tensor of shape `[2]` of `i32` from offset 0: 0 and 4. -/
abbrev off : Shape.Coord [2] → Nat := rowMajor l (.int 32) 0

/-- An 8-byte block of `undef` bytes. -/
def blk : MojoProof.Sem.Block :=
  { space := 1, size := 8, live := true, readOnly := false, owner := .all,
    bytes := fun _ => .undef, addr := 0, gaddr := 0 }

/-- Coordinate `k` of shape `[2]`. -/
def c (k : Fin 2) : Shape.Coord [2] := (k, ⟨⟩)

/-- The tensor `[5, 7]`. -/
def f (i : Shape.Coord [2]) : BitVec 32 := if i.1 = 0 then 5 else 7

/-- The other coordinate. -/
def swap (i : Shape.Coord [2]) : Shape.Coord [2] := (i.1.rev, ⟨⟩)

/-- The encoding of element `i` of `g`: 4 little-endian bytes. -/
def bs (g : Shape.Coord [2] → BitVec 32) (i : Shape.Coord [2]) : List MemByte :=
  leBytes 4 (g i).toNat

/-- Writing the tiles of `g` in an order `is` that lists both coordinates gives `ofFn g`. -/
theorem holds (g : Shape.Coord [2] → BitVec 32) {is : List (Shape.Coord [2])}
    (hall : ∀ i, i ∈ is) :
    (is.foldl (fun b i => b.put (off i) (bs g i)) blk).Holds l (.int 32) (Val.bits 32) off
      (Tensor.Rep.ofFn g) :=
  Block.holds_puts (blk := blk) (Layout.Codec.int l 32) (apart_rowMajor l _ 0)
    (fun i => (rowMajor_inb l _ 0 i).trans (by decide)) (f := g) (bs := bs g)
    (fun i => by simp [Layout.encode, bs]) hall

/-- Both orders give `[5, 7]`. -/
theorem holds_both :
    ([c 0, c 1].foldl (fun b i => b.put (off i) (bs f i)) blk).Holds l (.int 32) (Val.bits 32)
        off (Tensor.Rep.ofFn f) ∧
      ([c 1, c 0].foldl (fun b i => b.put (off i) (bs f i)) blk).Holds l (.int 32) (Val.bits 32)
        off (Tensor.Rep.ofFn f) :=
  ⟨holds f (is := [c 0, c 1]) (by decide), holds f (is := [c 1, c 0]) (by decide)⟩

/-- The swapped-tile twin: 7 at offset 0 and 5 at offset 4 hold `[7, 5]`, and not `[5, 7]`. -/
theorem swapped :
    ([c 0, c 1].foldl (fun b i => b.put (off i) (bs (f ∘ swap) i)) blk).Holds l (.int 32)
        (Val.bits 32) off (Tensor.Rep.ofFn (f ∘ swap)) ∧
      ¬ ([c 0, c 1].foldl (fun b i => b.put (off i) (bs (f ∘ swap) i)) blk).Holds l (.int 32)
        (Val.bits 32) off (Tensor.Rep.ofFn f) := by
  refine ⟨holds (f ∘ swap) (is := [c 0, c 1]) (by decide), fun h => ?_⟩
  have := congrArg (· (c 0))
    (Block.holds_inj (Layout.Codec.int l 32) (holds (f ∘ swap) (is := [c 0, c 1]) (by decide)) h)
  revert this
  simp only [Tensor.Rep.get_ofFn]
  decide

/-- The row-major tiles of the block, as a `Tiling`. -/
def tiling : Tiling (Shape.Coord [2]) :=
  .ofApart off (l.stored (.int 32)) 8 (apart_rowMajor l _ 0)
    fun i => (rowMajor_inb l _ 0 i).trans (by decide)

/-- Its tiles are the 4 bytes from 0 and from 4. -/
theorem tiling_tiles : (tiling.off (c 0), tiling.len (c 0), tiling.off (c 1)) = (0, 4, 4) := by
  decide

end MojoProofTest.Tiles
