import MojoProofTest.NaiveSound
import MojoProofTest.NaiveIn
import MojoProofTest.NaiveOut

/-!
# The naive matmul kernel's theorem

For the one program `naive` (MojoProofTest/SymPhi.lean), compiled with `fmul contract`:

* `correct`: `Kernel.Sound` of `naive` with `Elem.Out` of the naive bytes (`NaiveSpec.bytes`),
  for every oracle family, launch valid with `z` sides 1, sizes, blocks, tensors and memory that
  meets the matmul precondition `Mat.Pre` (Sem/Precond.lean). It is `NaiveFam.sound`, the naive
  family's theorem at every row stride (MojoProofTest/NaiveFamRun.lean), at the corpus strides
  `768`, `768`, `50257` (`NaiveFam.prog_corpus`); its only premises are the launch's and
  `Mat.Pre`, whose bounds give the sizes below `2 ^ 31`.
  `NaiveSound.naive_read` and `NaiveSound.naive_matmul` read its cells against TorchLean's
  `Tensor.matmul`.
* `L12`, `in12`, `mem12`, `pre12`, `sound12`: the instance at one block of 2 × 2 threads
  (valid by `NaiveOut.validZ`) with `m = 1`, `n = 2`, `K = 768` (two threads in bounds, two out)
  on the memory `Mat.mem` builds, which meets `Mat.Pre` at every `K ≤ 768` by `Mat.pre_mem`
  (`pre12`), for every `A`, `B` and oracles.
* The corollaries of `correct`, for `naive` at every launch and memory of its family, on every
  observation of a complete run, each the theorem of MojoProofTest/NaiveFam.lean of the same name
  (`NaiveFam.cover` for `read_cover`) at the corpus strides, one line: `read_cover`, every cell
  of `C` holds its contracted dot loop when the launch's window covers `m × n` (its instance
  `read12` at `L12`, its twin `keep11` at the one-thread launch `Launch.one`, which leaves
  `C[0, 1]` the caller's); `matmul_nanEq`, each cell in the window against TorchLean's
  `Tensor.matmul` of the first `K` columns up to NaNs at a thread that fuses no round (its
  instance `nanEq_zero` at an oracle family that fuses nothing); `matmul_error`, each finite cell
  in the window within `dotBound` of the real product, for every oracle family.
-/

namespace MojoProofTest.NaiveKernel

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread MojoProofTest.NaiveSpec MojoProofTest.NaiveSound
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- **The naive matmul kernel's theorem**: `naive` is sound for `Elem.Out` of its bytes, for every
oracle family, launch valid with `z` sides 1, sizes, blocks, tensors and memory that meets the
matmul precondition `Mat.Pre` (Sem/Precond.lean) at naive's layout, binary32, alignment 4 and row
strides 768, 768 and 50257. It is `NaiveFam.sound` at those strides (`NaiveFam.prog_corpus`),
with `m`, `n`, `K` below `2 ^ 31` from `Mat.Pre`'s bounds (`dims_lt`). -/
theorem correct {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K bC bA bB : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 768]} {B : Tensor (Model FloatTy.float.fmt) [n, 768]}
    {mem : Mem} (h : Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA bB
      m n K 768 768 50257 A B) :
    Kernel.Sound naive.prog naive.fn_0 L (Mat.args z bC bA bB m n K) mem (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out mem bC (cell L) (bytes ω L K A B) (volume L.grid * volume L.block)) :=
  NaiveFam.sound hL hz h (dims_lt ⟨h.le.1, h.le.2.1, h.lt⟩)

/-- The launch of one block of 2 × 2 threads (`x` side 2, `y` side 2). -/
abbrev L12 : Launch := launch2 1 1 2 2

/-- At `m = 1` and `n = 2`, two of `L12`'s four threads are in bounds, threads 0 and 2 (row 0,
columns 0 and 1); threads 1 and 3 (row 1) are not. -/
theorem in12 : (List.range 4).filter (fun k => decide (S L12 1 2 k)) = [0, 2] := by decide

/-- The caller's memory of `sound12`: `Mat.mem` at naive's layout, binary32 and alignment 4, with
`C` (row stride 50257) at block 1, `A` at block 2 and `B` at block 3, block `i + 1` at address
`4 (i + 1)` in both spaces. -/
abbrev mem12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) : Mem :=
  Mat.mem naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 A B 50257 (fun i => i.val + 1)
    (fun i => i.val + 1)

/-- **`mem12` meets the matmul precondition**, for every `A` (`1 × 768`), `B` (`2 × 768`) and
`K ≤ 768`: at naive's layout, binary32, alignment 4, `m = 1`, `n = 2` and row strides 768, 768
and 50257, with `C`, `A` and `B` at blocks 1, 2 and 3 (`Mat.pre_mem`, the bounds by evaluation).
For this one memory. -/
theorem pre12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768) :
    Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z (mem12 A B) 1 2 3 1 2 K 768
      768 50257 A B :=
  Mat.pre_mem (Layout.Codec.float _ .float) (fun _ => trivial) 4 A B ⟨by decide, hK, hK⟩
    (by decide) (fun i => i.val + 1) (fun i => i.val + 1) (by decide +kernel) (by decide +kernel)
    rfl

/-- **`correct` at a concrete memory with two threads in bounds**: for every `A` (`1 × 768`),
`B` (`2 × 768`) and oracles `ω`, `naive` on `L12` at `m = 1`, `n = 2`, `K = 768` and `mem12 A B`
is sound for `Elem.Out` of its bytes; `Mat.Pre` is `pre12`. It covers this one launch and
memory. -/
theorem sound12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) :
    Kernel.Sound naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out (mem12 A B) 1 (cell L12) (bytes ω L12 768 A B)
        (volume L12.grid * volume L12.block)) :=
  correct NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B le_rfl)

section Read

variable {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
  {m n K bC bA bB : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, 768]}
  {B : Tensor (Model FloatTy.float.fmt) [n, 768]} {mem : Mem}
  (h : Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA bB m n K 768 768
    50257 A B)
  {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
  (hB : Kernel.Obs naive.prog naive.fn_0 L (Mat.args z bC bA bB m n K) mem
    (fun m => some m.blocks) ch ω Bk)
include hL hz h hB

/-- **Every cell of `C` holds its contracted dot loop when the launch covers `m × n`.** For every
oracle family `ω`, launch `L` valid with `z` sides 1 whose window covers the result
(`m ≤ grid.x * block.x`, `n ≤ grid.y * block.y`), sizes, blocks, tensors and memory of
`Mat.Pre`: in every observation `Bk` of a complete run of `naive` at every address choice under
`ω`, block `bC` is some `y` and every cell `(r, c)` with `r < m` and `c < n` is computed by one
thread `k`, of row `r` and column `c`, whose 4 bytes at offset `(r * 50257 + c) * 4` encode
`dotLoop` with `fmul contract` under `o (ω k)` from `+0` over `pairs A B r c K` (`NaiveFam.cover`
at the corpus strides and `correct`). The other bytes and blocks are `naive_read`'s.
It covers the one program `naive`, at every launch and memory of its family whose window covers
`m × n`; `read12` is its instance, `keep11` the twin at a launch that does not cover it. -/
theorem read_cover (hm : m ≤ L.grid .x * L.block .x) (hn : n ≤ L.grid .y * L.block .y) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n),
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        (∀ k' < volume L.grid * volume L.block, L.index k' .x = r → L.index k' .y = c →
          k' = k) ∧
        naive.prog.layout.encode (.fp .float) (.ofFloat .float
          (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨r, hr⟩ ⟨c, hc⟩ K))) =
          some (y.read ((r * 50257 + c) * 4) 4) :=
  NaiveFam.cover (A := A) (B := B) hL hz h.le.1 (correct hL hz h) h.bufs.2.2.choose_spec.1 hB hm hn

/-- **naive's cells against TorchLean's product, up to NaNs, at a thread that fuses no round.**
For every oracle family `ω`, launch `L` valid with `z` sides 1, sizes, `K ≤ 768`, blocks,
tensors and memory of `Mat.Pre`: in every observation `Bk` of a complete run of `naive` at every
address choice under `ω`, block `bC` is some `y` and every cell `(r, c)` with `r < m`, `c < n`
and in the launch's window (`r < grid.x * block.x`, `c < grid.y * block.y`) is computed by one
thread `k` and holds the binary32 encoding of a word `v`; if no `fadd` oracle number of thread `k`
is `2` modulo `3` (it fuses no round), `v` and entry `(r, c)` of TorchLean's `Tensor.matmul` of
the first `K` columns of `A` and the transpose of the first `K` columns of `B` (`cols`) are the
same word or both NaNs (`NaNEq`; `NaiveFam.matmul_nanEq` at the corpus strides and `correct`).
The equality needs that premise: a fused round rounds the product and the sum once, TorchLean's
product rounds each. Its instance `nanEq_zero` is at the oracle family `fun _ _ => 0`, which fuses
nothing. It covers the one program `naive`, at every launch and memory of its family. -/
theorem matmul_nanEq (hK : K ≤ 768) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 50257 + c) * 4) 4) ∧
        ((∀ j, (o (ω k) j).2 % 3 ≠ 2) → NaNEq v (Tensor.get2 (Tensor.matmul (cols K hK A)
          (Tensor.permute (cols K hK B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩
            ⟨c, hc⟩)) :=
  NaiveFam.matmul_nanEq hL hz h.le.1 hK hK (correct hL hz h) h.bufs.2.2.choose_spec.1 hB

/-- **naive's finite cells are within `dotBound` of the real product.** For every oracle family
`ω`, launch `L` valid with `z` sides 1, sizes, `K ≤ 768`, blocks, tensors and memory of
`Mat.Pre`: in every observation `Bk` of a complete run of `naive` at every address choice under
`ω`, block `bC` is some `y` and every cell `(r, c)` with `r < m`, `c < n` and in the launch's
window is computed by one thread `k` and holds the binary32 encoding of a word `v`; when `v` is
finite, `|v - (A Bᵀ)ᵣ꜀|` over the reals on the first `K` columns (`cols`, mapped by
`Model.toReal`) is at most `dotBound` of binary32 at `K` and `Σⱼ<K |aᵣⱼ b꜀ⱼ|`, whichever rounds
the oracle fuses (`NaiveFam.matmul_error` at the corpus strides and `correct`). It covers the one
program `naive`, at every launch and memory of its family. -/
theorem matmul_error (hK : K ≤ 768) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 50257 + c) * 4) 4) ∧
        (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
          (Tensor.map Model.toReal (cols K hK A)) (Tensor.map Model.toReal
            (Tensor.permute (cols K hK B) (Shape.adjacentSwap [n, K] 0) [K, n])))
              ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt K ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                K).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
  NaiveFam.matmul_error hL hz h.le.1 hK hK (correct hL hz h) h.bufs.2.2.choose_spec.1 hB

end Read

/-- **`matmul_nanEq` at the oracle family that fuses nothing**: at `fun _ _ => 0` every `fadd`
oracle number is `0`, so no thread fuses a round and `matmul_nanEq`'s premise holds. For every
launch `L` valid with `z` sides 1, sizes, `K ≤ 768`, blocks, tensors and memory of `Mat.Pre`: in
every observation `Bk` of a complete run of `naive` at every address choice under it, every cell
`(r, c)` with `r < m`, `c < n` and in the launch's window holds the binary32 encoding of a word
`NaNEq` to entry `(r, c)` of TorchLean's `Tensor.matmul` of the first `K` columns of `A` and the
transpose of the first `K` columns of `B` (`NaiveFam.nanEq_zero` at the corpus strides and
`correct`). It covers the one program `naive` and this one oracle family, at every launch and
memory of its family. -/
theorem nanEq_zero {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {m n K bC bA bB : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : Tensor (Model FloatTy.float.fmt) [n, 768]} {mem : Mem}
    (h : Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA bB m n K 768
      768 50257 A B) (hK : K ≤ 768) {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 L (Mat.args z bC bA bB m n K) mem
      (fun m => some m.blocks) ch (fun _ _ => 0) Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 50257 + c) * 4) 4) ∧
        NaNEq v (Tensor.get2 (Tensor.matmul (cols K hK A)
          (Tensor.permute (cols K hK B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩ ⟨c, hc⟩) :=
  NaiveFam.nanEq_zero hL hz h.le.1 hK hK (correct hL hz h) h.bufs.2.2.choose_spec.1 hB

/-- **`read_cover` at `sound12`**: for every `A` (`1 × 768`), `B` (`2 × 768`) and oracles `ω`,
every observation of `naive` on `L12` at `mem12 A B` has a
block `y` at 1 whose cells `c = 0, 1` (row 0) are read by one thread `k` each, of row 0
and column `c`: the 4 bytes at offset `c * 4` encode `dotLoop` with `fmul contract` under
`o (ω k)` from `+0` over `pairs A B 0 c 768`. `L12`'s window, 2 × 2, covers `1 × 2`. It covers
this one launch and memory. -/
theorem read12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk 1 = some y ∧ ∀ c (hc : c < 2), ∃ k < 4, L12.index k .x = 0 ∧ L12.index k .y = c ∧
      naive.prog.layout.encode (.fp .float) (.ofFloat .float
        (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B 0 ⟨c, hc⟩ 768))) =
        some (y.read (c * 4) 4) := by
  obtain ⟨y, hy, h⟩ :=
    read_cover NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B le_rfl) hB (by decide) (by decide)
  refine ⟨y, hy, fun c hc => ?_⟩
  obtain ⟨k, hk, ex, ey, -, he⟩ := h 0 c (by decide) hc
  exact ⟨k, hk, ex, ey, by simpa using he⟩

/-- **The twin of `read_cover`: a launch that does not cover `m × n` leaves a cell the caller's.**
For every `A` (`1 × 768`), `B` (`2 × 768`) and oracles `ω`, at `m = 1`, `n = 2` and `K = 768` on
`mem12 A B` (`pre12`), the one thread of `Launch.one` (window 1 × 1) is in bounds and writes only
cell `(0, 0)`, bytes 0 to 3: in every observation of a complete run, block 1 is some `y` whose
bytes from offset 4 on, cell `(0, 1)` among them, are those of the caller's block 1 (`naive_read`'s
second clause at `correct`, with no evaluation of the run). So `read_cover`'s premise
`n ≤ grid.y * block.y` is needed: `C[0, 1]` is not written. It covers this one launch and
memory. -/
theorem keep11 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 Launch.one (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk) {x : Sem.Block} (hx : (mem12 A B).blocks 1 = some x) :
    ∃ y, Bk 1 = some y ∧ ∀ i, 4 ≤ i → y.bytes i = x.bytes i := by
  obtain ⟨y, hy, -, h, -⟩ := naive_read Launch.valid_one ⟨rfl, rfl⟩ (by decide)
    (correct Launch.valid_one ⟨rfl, rfl⟩ (pre12 A B le_rfl)) hx hB
  refine ⟨y, hy, fun i hi => h i fun k hk => .inr ?_⟩
  obtain rfl : k = 0 := by
    have : volume Launch.one.grid * volume Launch.one.block = 1 := by decide
    omega
  exact (show cell Launch.one 0 + 4 = 4 by decide +kernel).trans_le hi

end MojoProofTest.NaiveKernel
