import MojoProof.Sem.Buffer
import TorchLean.Tensor.Rep.Pointwise
import FloatLib.Floats.Formats.BinaryInterchange.Model.Instances

/-!
# The output buffer of an elementwise kernel after its stores

The observation `Mem.tensor` (MojoProof/Sem/Buffer.lean) of a block after stores to some of its
cells, and, for a rank-1 binary32 buffer, its link to TorchLean's elementwise `add`
(`Add (Tensor α s)`, `zipWith (· + ·)`, with FloatLib's binary32 `+` on the elements; no copy of
either is defined here). docs/proofs/adapter.md, section "The observation of an elementwise
output", has the informal argument. Proved here:

- `Block.size_puts`: writes keep a block's size, for every list of writes.
- `Block.holds_writes`, for every layout, type, codec, shape, offsets that are `l.stored t`
  apart, tensor and list of cells: a block that holds `x`, after the encodings of `enc (f i)` are
  written at the cells `i` of the list (in any order, with repetitions), holds the tensor with
  `f i` at the cells of the list and `x i` at the others. `Mem.tensor_writes`: the observation
  of a memory whose block is that block is that tensor.
- `Mem.tensor_vec`, for every layout, length `N`, bound `n`, base offset, words and list of cells
  that are the cells below `n`: the observation of a rank-1 binary32 buffer at row-major offsets,
  after one store of the word `w i` per cell `i < n`, is `i ↦ w i` below `n` and the buffer's own
  element at the other cells.
- `Mem.tensor_vec_add`, the same with all `N` cells stored, each with what `fadd` with no flags
  gives on `a i` and `c i` for an oracle number (`floatBin_ofFloat`: `deliver (a i + c i) k`):
  the observation is `some (a + c)`, TorchLean's elementwise sum, when no element of the sum is a
  NaN.

The instance (a buffer of 4 binary32 cells, 2 or 4 of them stored) and the twins (a cell from
`n` on keeps its value; a NaN sum delivered as another NaN) are in MojoProofTest/Elementwise.lean.
-/

namespace MojoProof.Sem

open LLVM TorchLean FloatLib.Floats.Formats.BinaryInterchange

variable {α : Type} [Storage α] {s : Shape} {l : Layout} {t : Ty} {enc : α → Val}
  {off : Shape.Coord s → Nat} {x : Tensor α s}

/-- Writes keep a block's size: for every block, offsets, bytes and list of writes. -/
theorem Block.size_puts {ι : Type} (off : ι → Nat) (bs : ι → List MemByte) (is : List ι)
    (blk : Block) : (is.foldl (fun b j => b.put (off j) (bs j)) blk).size = blk.size := by
  induction is generalizing blk with
  | nil => rfl
  | cons j is ih => rw [List.foldl_cons, ih]; rfl

/-- **Stores to some cells.** A block that holds `x`, after the encodings of `enc (f i)` are
written at the cells `i` of `is` (in any order, with repetitions), holds the tensor with `f i` at
the cells of `is` and `x i` at the others, for a codec (`Layout.Codec`) and offsets `l.stored t`
bytes apart. -/
theorem Block.holds_writes {blk : Block} (h : blk.Holds l t enc off x) (hc : l.Codec t enc)
    (hap : Apart off (l.stored t)) {f : Shape.Coord s → α} {bs : Shape.Coord s → List MemByte}
    (hbs : ∀ i, l.encode t (enc (f i)) = some (bs i)) (is : List (Shape.Coord s)) :
    (is.foldl (fun b i => b.put (off i) (bs i)) blk).Holds l t enc off
      (Tensor.Rep.ofFn fun i => if i ∈ is then f i else x i) := fun i => by
  have hr i : ∃ n, l.encode t (enc (f i)) = some (bs i) ∧ (bs i).length = n ∧
      l.decode t (bs i) = some (enc (f i)) ∧ n = l.stored t := by
    obtain ⟨bs', he, hl, hd⟩ := hc.round (f i)
    rw [hbs i, Option.some.injEq] at he
    subst he
    exact ⟨_, hbs i, rfl, hd, hl⟩
  have hl i : (bs i).length = l.stored t := by
    obtain ⟨_, -, e, -, rfl⟩ := hr i
    exact e
  refine ⟨by rw [Block.size_puts]; exact (h i).1, ?_⟩
  rw [Block.read_puts hap hl, Tensor.Rep.get_ofFn]
  by_cases hi : i ∈ is
  · simp only [hi, ↓reduceIte]
    obtain ⟨_, -, -, hd, -⟩ := hr i
    exact hd
  · simp only [hi, ↓reduceIte]
    exact (h i).2

/-- **The observation after stores to some cells.** For a codec (`Layout.Codec`) and offsets
`l.stored t` bytes apart: if block `b` of `m` is a block that held `x` after the encodings of
`enc (f i)` were written at the cells `i` of `is`, the observation of `b` is the tensor with
`f i` at the cells of `is` and `x i` at the others. -/
theorem Mem.tensor_writes {m : Mem} {b : Nat} {blk : Block} (hc : l.Codec t enc)
    (hap : Apart off (l.stored t)) (h : blk.Holds l t enc off x) {f : Shape.Coord s → α}
    {bs : Shape.Coord s → List MemByte} (hbs : ∀ i, l.encode t (enc (f i)) = some (bs i))
    {is : List (Shape.Coord s)}
    (hm : m.blocks b = some (is.foldl (fun b i => b.put (off i) (bs i)) blk)) :
    m.tensor l b t enc off = some (Tensor.Rep.ofFn fun i => if i ∈ is then f i else x i) :=
  Mem.tensor_eq hc ⟨_, hm, Block.holds_writes h hc hap hbs is⟩

/-- **A rank-1 binary32 buffer after one store per cell below `n`.** If block `b` of `m` is a
block that held `x : Tensor (Model binary32) [N]` at row-major offsets from `base`, after the
encodings of the words `w i` were written at the cells of `is`, which are the cells below `n`
(in any order), then the observation of `b` is `w i` at each cell `i < n` and `x i` at the
others. -/
theorem Mem.tensor_vec {N n : Nat} {m : Mem} {b base : Nat} {blk : Block}
    {x : Tensor (Model FloatTy.float.fmt) [N]}
    (h : blk.Holds l (.fp .float) (Val.ofFloat .float) (rowMajor l (.fp .float) base) x)
    {w : Shape.Coord [N] → Model FloatTy.float.fmt} {bs : Shape.Coord [N] → List MemByte}
    (hbs : ∀ i, l.encode (.fp .float) (Val.ofFloat .float (w i)) = some (bs i))
    {is : List (Shape.Coord [N])} (his : ∀ i, i ∈ is ↔ i.1.val < n)
    (hm : m.blocks b =
      some (is.foldl (fun b i => b.put (rowMajor l (.fp .float) base i) (bs i)) blk)) :
    m.tensor l b (.fp .float) (Val.ofFloat .float) (rowMajor l (.fp .float) base) =
      some (Tensor.Rep.ofFn fun i : Shape.Coord [N] => if i.1.val < n then w i else x i) := by
  rw [Mem.tensor_writes (Layout.Codec.float l .float) (apart_rowMajor l _ base) h hbs hm]
  simp only [his]

/-- **The output is TorchLean's elementwise sum.** If block `b` of `m` is a block that held a
rank-1 binary32 buffer at row-major offsets from `base`, after every cell `i` (in `is`, in any
order) was stored with what `fadd` with no flags gives on `a i` and `c i` for the oracle number
`k i` (`floatBin_ofFloat`: `deliver (a i + c i) (k i)`), and no element of `a + c` is a NaN,
then the observation of `b` is `a + c`, TorchLean's `Add` on tensors (`Tensor.add_apply`). -/
theorem Mem.tensor_vec_add {N : Nat} {m : Mem} {b base : Nat} {blk : Block}
    {x a c : Tensor (Model FloatTy.float.fmt) [N]}
    (h : blk.Holds l (.fp .float) (Val.ofFloat .float) (rowMajor l (.fp .float) base) x)
    {k : Shape.Coord [N] → Nat} {bs : Shape.Coord [N] → List MemByte}
    (hbs : ∀ i, l.encode (.fp .float) (Val.ofFloat .float (deliver (a i + c i) (k i))) =
      some (bs i))
    (hnan : ∀ i, (a i + c i).isNaN = false) {is : List (Shape.Coord [N])} (his : ∀ i, i ∈ is)
    (hm : m.blocks b =
      some (is.foldl (fun b i => b.put (rowMajor l (.fp .float) base i) (bs i)) blk)) :
    m.tensor l b (.fp .float) (Val.ofFloat .float) (rowMajor l (.fp .float) base) =
      some (a + c) := by
  rw [Mem.tensor_vec (n := N) h hbs (fun i => iff_of_true (his i) i.1.isLt) hm]
  congr 1
  exact Tensor.Rep.ext fun i => by
    rw [Tensor.Rep.get_ofFn, Tensor.add_apply, deliver_of_isNaN_eq_false (hnan i)]
    simp only [i.1.isLt, ↓reduceIte]

end MojoProof.Sem
