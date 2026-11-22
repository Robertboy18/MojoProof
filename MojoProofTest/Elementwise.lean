import MojoProof.Sem.Elementwise
import MojoProof.Sem.FloatRel
import MojoProofTest.Tiles

/-!
# Instances and twins of the elementwise output after its stores

A buffer of 4 binary32 cells under the default layout, row-major from offset 0, in a 16-byte
block: `blk0` holds the zero tensor `z` (written tile by tile from `undef` bytes, by
`Block.holds_puts`), and block 1 of the memory `mem is ws` is `blk0` after the words `ws i` are
stored at the cells of `is`, in the order of `is`. These are statements about bytes, not about a
kernel run.

- Instance of `Mem.tensor_vec` (`vec_inst`): after one store per cell below 2, in the order
  1, 0, the observation is the stored word at cells 0 and 1 and `z` at cells 2 and 3.
- Instance of `Mem.tensor_vec_add` (`add_inst`): `a` is 1.0 and `c` is 2.0 in every cell; after
  each of the 4 cells is stored, in the order 3, 1, 0, 2, with what `fadd` with no flags gives on
  them for oracle number 0 (`fadd_word`, by `floatBin_ofFloat`), the observation is `a + c`,
  TorchLean's elementwise sum (3.0 in every cell).
- Twin of the coverage premise (`add_twin_partial`): with only the cells below 2 stored, the
  observation is not `a + c` (cell 3 keeps `z`'s 0).
- Twin of the NaN premise (`add_twin_nan`): with `+∞` and `-∞` the sum is a NaN in every cell, and
  an oracle number that names another NaN (`0x7fc00001`) makes the stored words, and so the
  observation, differ from `a + c`, though every cell is stored.
-/

namespace MojoProofTest.Elementwise

open MojoProof.LLVM MojoProof.Sem TorchLean FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.Tiles (l)

/-- The binary32 value with bits `n`. -/
def f32 (n : Nat) : Model FloatTy.float.fmt := Model.ofNatBits n

/-- Row-major offsets of a tensor of shape `[4]` of `float` from offset 0: 0, 4, 8, 12. -/
abbrev off : Shape.Coord [4] → Nat := rowMajor l (.fp .float) 0

/-- Coordinate `k` of shape `[4]`. -/
def cell (k : Fin 4) : Shape.Coord [4] := (k, ⟨⟩)

/-- The 4 bytes `Layout.encode` gives a binary32 word. -/
def enc32 (v : Model FloatTy.float.fmt) : List MemByte := leBytes 4 v.toBits.toNat

/-- `enc32` is `Layout.encode`'s encoding of a binary32 word. -/
theorem enc32_spec (v : Model FloatTy.float.fmt) :
    l.encode (.fp .float) (Val.ofFloat .float v) = some (enc32 v) := by
  simp only [Layout.encode, Val.ofFloat, enc32, FloatTy.fmt]
  rfl

/-- A 16-byte block of `undef` bytes. -/
def blkU : MojoProof.Sem.Block :=
  { space := 1, size := 16, live := true, readOnly := false, owner := .all,
    bytes := fun _ => .undef, addr := 0, gaddr := 0 }

/-- The zero tensor of shape `[4]`. -/
def z : Tensor (Model FloatTy.float.fmt) [4] := Tensor.Rep.ofFn fun _ => f32 0

/-- The block holding `z`: its 4 tiles written from `undef` bytes. -/
def blk0 : MojoProof.Sem.Block :=
  (List.finRange 4).foldl (fun b k => b.put (off (cell k)) (enc32 (f32 0))) blkU

/-- `blk0` holds `z`, by `Block.holds_puts`. -/
theorem blk0_holds : blk0.Holds l (.fp .float) (Val.ofFloat .float) off z := by
  have h := Block.holds_puts (blk := blkU) (Layout.Codec.float l .float) (apart_rowMajor l _ 0)
    (fun i => (rowMajor_inb l _ 0 i).trans (by decide)) (f := fun _ => f32 0)
    (bs := fun _ => enc32 (f32 0)) (fun _ => enc32_spec _)
    (is := (List.finRange 4).map cell) (fun i => by
      obtain ⟨k, ⟨⟩⟩ := i
      exact List.mem_map.2 ⟨k, List.mem_finRange k, rfl⟩)
  rw [List.foldl_map] at h
  exact h

/-- The memory whose block 1 is `blk0` after the words `ws i` are stored at the cells of `is`. -/
def mem (is : List (Shape.Coord [4])) (ws : Shape.Coord [4] → Model FloatTy.float.fmt) : Mem :=
  ({} : Mem).set 1 (is.foldl (fun b i => b.put (off i) (enc32 (ws i))) blk0)

/-- Block 1 of `mem is ws`. -/
theorem mem_block (is : List (Shape.Coord [4]))
    (ws : Shape.Coord [4] → Model FloatTy.float.fmt) :
    (mem is ws).blocks 1 = some (is.foldl (fun b i => b.put (off i) (enc32 (ws i))) blk0) := by
  simp [mem, Mem.set]

/-- The words 1.0 and 2.0 at cells 0 and 1 (and 3.0 elsewhere, never stored below). -/
def ws (i : Shape.Coord [4]) : Model FloatTy.float.fmt :=
  if i.1 = 0 then f32 0x3f800000 else if i.1 = 1 then f32 0x40000000 else f32 0x40400000

/-- **Instance of `Mem.tensor_vec`**: after one store per cell below 2, in the order 1, 0, the
observation is `ws` at cells 0 and 1 and `z` at the others. -/
theorem vec_inst : (mem [cell 1, cell 0] ws).tensor l 1 (.fp .float) (Val.ofFloat .float) off =
    some (Tensor.Rep.ofFn fun i : Shape.Coord [4] => if i.1.val < 2 then ws i else z i) :=
  Mem.tensor_vec blk0_holds (fun _ => enc32_spec _) (by decide) (mem_block _ _)

/-- The tensor 1.0 in every cell. -/
def a : Tensor (Model FloatTy.float.fmt) [4] := Tensor.Rep.ofFn fun _ => f32 0x3f800000

/-- The tensor 2.0 in every cell. -/
def c : Tensor (Model FloatTy.float.fmt) [4] := Tensor.Rep.ofFn fun _ => f32 0x40000000

/-- What `fadd` with no flags gives on two binary32 words for oracle number `3 k`: the word
`deliver (x + y) k`, with TorchLean's scalar `+` (FloatLib's `Model.add`), by
`floatBin_ofFloat`. -/
theorem fadd_word (x y : Model FloatTy.float.fmt) (k : Nat) :
    floatBin .float .fadd {} (.ofFloat .float x) (.ofFloat .float y) none none (3 * k) =
      .ok (.ofFloat .float (deliver (x + y) k)) := by
  rw [floatBin_ofFloat (f := fun x y => Model.add x y) rfl rfl rfl rfl x y (3 * k),
    Nat.mul_div_cancel_left k (by decide)]
  rfl

/-- The order the 4 cells are stored in. -/
def order : List (Shape.Coord [4]) := [cell 3, cell 1, cell 0, cell 2]

/-- No cell of `a + c` is a NaN. -/
theorem sum_not_nan : ∀ i : Shape.Coord [4], (a i + c i).isNaN = false := by
  simp only [a, c, Tensor.Rep.get_ofFn]
  intro _
  decide +kernel

/-- **Instance of `Mem.tensor_vec_add`**: after every cell is stored with what `fadd` stores for
oracle number 0 (`fadd_word`), the observation is `a + c`, TorchLean's elementwise sum. -/
theorem add_inst :
    (mem order fun i => deliver (a i + c i) 0).tensor l 1 (.fp .float) (Val.ofFloat .float)
      off = some (a + c) :=
  Mem.tensor_vec_add blk0_holds (fun _ => enc32_spec _) sum_not_nan (by decide) (mem_block _ _)

/-- `a + c` is 3.0 in every cell. -/
theorem sum_three (i : Shape.Coord [4]) : (a + c) i = f32 0x40400000 := by
  rw [Tensor.add_apply]
  simp only [a, c, Tensor.Rep.get_ofFn]
  decide +kernel

/-- **Twin of the coverage premise**: with only cells 0 and 1 stored with the sums, the
observation is not `a + c`: cell 3 keeps `z`'s 0. -/
theorem add_twin_partial :
    (mem [cell 0, cell 1] fun i => deliver (a i + c i) 0).tensor l 1 (.fp .float)
      (Val.ofFloat .float) off ≠ some (a + c) := by
  rw [Mem.tensor_vec (n := 2) blk0_holds (fun _ => enc32_spec _) (by decide) (mem_block _ _)]
  intro h
  have := congrArg (· (cell 3)) (Option.some.inj h)
  simp only [Tensor.Rep.get_ofFn, sum_three] at this
  revert this
  decide

/-- `+∞` in every cell. -/
def pinf : Tensor (Model FloatTy.float.fmt) [4] := Tensor.Rep.ofFn fun _ => f32 0x7f800000

/-- `-∞` in every cell. -/
def ninf : Tensor (Model FloatTy.float.fmt) [4] := Tensor.Rep.ofFn fun _ => f32 0xff800000

/-- **Twin of the NaN premise**: `+∞ + -∞` is a NaN in every cell; stored through the oracle
number that names the NaN `0x7fc00001` at every cell, the observation is not `pinf + ninf`,
though every cell is stored. -/
theorem add_twin_nan :
    (∀ i, (pinf i + ninf i).isNaN = true) ∧
      (mem order fun i => deliver (pinf i + ninf i) 0x7fc00001).tensor l 1 (.fp .float)
        (Val.ofFloat .float) off ≠ some (pinf + ninf) := by
  have hn : f32 0x7f800000 + f32 0xff800000 ≠
        deliver (f32 0x7f800000 + f32 0xff800000) 0x7fc00001 ∧
      (f32 0x7f800000 + f32 0xff800000).isNaN = true := by
    decide +kernel
  refine ⟨fun i => by simpa only [pinf, ninf, Tensor.Rep.get_ofFn] using hn.2, ?_⟩
  rw [Mem.tensor_vec (n := 4) blk0_holds (fun _ => enc32_spec _) (by decide) (mem_block _ _)]
  intro h
  have := congrArg (· (cell 0)) (Option.some.inj h)
  simp only [Tensor.Rep.get_ofFn, Tensor.add_apply, pinf, ninf, cell] at this
  exact hn.1 (by simpa using this.symm)

end MojoProofTest.Elementwise
