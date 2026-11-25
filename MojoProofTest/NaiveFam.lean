import MojoProofTest.NaiveSpec
import MojoProof.Sym.KernelCmd

/-!
# The naive matmul family's cells, at every row stride

The naive kernel's family is its program at row strides `sA`, `sB` (of `A` and `B`) and `sC`
(of `C`); the corpus file is the one at `768`, `768` and `50257`. This module states the
family's spec at every stride and reads the cells of `C` off every kernel sound for it:

* `cell sC`, `pairs`, `bytes`: thread `k`'s cell `(row * sC + column) * 4`; the factor pairs of
  cell `(r, c)`, the first `K` of the `min sA sB` pairs of row `r` of `A` (`m × sA`) and row `c`
  of `B` (`n × sB`); the bytes thread `k` puts, `dotLoop` with `fmul contract` from `+0` over
  its pairs under its oracle numbers `NaiveSpec.o`, encoded as a binary32 word, if it is in
  bounds (`NaiveSpec.S`), else none. At `768`, `768`, `50257` they are `NaiveSpec.cell`,
  `NaiveSpec.pairs` and `NaiveSpec.bytes`, by definition.
* `read`: for every program and function, from `Kernel.Sound` for `Elem.Out` of `bytes` at
  cells `cell sC` with `n ≤ sC`, every observation's block `C`: each cell in bounds and in the
  launch's window holds the word of its one thread, the other bytes and blocks are the
  caller's.
* `matmul`: with `K ≤ sA` and `K ≤ sB`, each such cell against TorchLean's `Tensor.matmul` of
  the first `K` columns of `A` and of `B`ᵀ (`cols`), up to NaNs when no round fuses
  (`matmul_cols_nanEq`), and within `dotBound` when finite (`matmul_cols_error`).
* `cover`: `read` when the launch's window covers `m × n`, every cell read off;
  `matmul_nanEq` and `matmul_error`: `matmul`'s two clauses; `nanEq_zero`: `matmul_nanEq` at the
  oracle family `fun _ _ => 0`, which fuses nothing, its premise discharged.

`NaiveSound.naive_read` and `NaiveSound.naive_matmul` are `read` and `matmul` at the corpus
strides, and `NaiveKernel.read_cover`, `matmul_nanEq`, `matmul_error` and `nanEq_zero` the other
four there at the corpus kernel's theorem; `read_16_8_5`, `matmul_16_8_5`, `cover_16_8_5`,
`matmul_nanEq_16_8_5`, `matmul_error_16_8_5` and `nanEq_zero_16_8_5` are their tests at strides
16, 8 and 5. The kernel's soundness itself (`NaiveSound.naive_sound`) is for the corpus program
only: the family's program at every stride is not built here.
-/

namespace MojoProofTest.NaiveFam

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveSpec
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- The byte offset of thread `k`'s cell of `C` at row stride `sC` in launch `L`:
`(row * sC + column) * 4`. -/
abbrev cell (sC : Nat) (L : Launch) (k : Nat) : Nat :=
  (L.index k .x * sC + L.index k .y) * 4

/-- The factor pairs of cell `(r, c)` for `A` (`m × sA`) and `B` (`n × sB`): for
`j < min K (min sA sB)`, element `j` of row `r` of `A` and element `j` of row `c` of `B`, in
that order. -/
def pairs {m n sA sB : Nat} (A : Tensor (Model FloatTy.float.fmt) [m, sA])
    (B : Tensor (Model FloatTy.float.fmt) [n, sB]) (r : Fin m) (c : Fin n) (K : Nat) :
    List (Model FloatTy.float.fmt × Model FloatTy.float.fmt) :=
  (List.ofFn fun j : Fin (min sA sB) => (Tensor.get2 A r (Fin.castLE (Nat.min_le_left _ _) j),
    Tensor.get2 B c (Fin.castLE (Nat.min_le_right _ _) j))).take K

/-- The bytes thread `k` of launch `L` puts at its cell, under the oracles `ω`, for `A`
(`m × sA`) and `B` (`n × sB`): if it is in bounds (`S`), the binary32 encoding in `naive`'s
layout of `dotLoop` with `fmul contract` from `+0` over the factor pairs of its cell (`pairs`)
under its oracle numbers (`o (ω k)`); else none. -/
def bytes (ω : Nat → Nat → Nat) (L : Launch) {m n sA sB : Nat} (K : Nat)
    (A : Tensor (Model FloatTy.float.fmt) [m, sA]) (B : Tensor (Model FloatTy.float.fmt) [n, sB])
    (k : Nat) : Option (List MemByte) :=
  if h : S L m n k then
    naive.prog.layout.encode (.fp .float) (.ofFloat .float
      (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨_, h.2.1⟩ ⟨_, h.2.2⟩ K)))
  else none

/-- **The cells of `C` after a kernel of the naive family, read off, at every stride.** For
every program, function, arguments, oracles `ω`, launch `L` valid with `z` sides 1, sizes `m`,
`n`, row strides `sA`, `sB` and `sC ≥ n`, count `K`, block `bC`, tensors `A` (`m × sA`), `B`
(`n × sB`) and caller's memory whose block `bC` is `x`: if the kernel is sound for `Elem.Out` of
`bytes` at the cells `cell sC`, every observation `Bk` of a run under `ω` (`Kernel.Obs`) has a
block `y` at `bC` with

* for every cell `(r, c)` with `r < m`, `c < n` and in the launch's window, the one thread `k`
  of row `r` and column `c` (`Launch.cell_onto`; unique by `Launch.xy_inj`), whose `4` bytes at
  offset `(r * sC + c) * 4` encode `dotLoop` with `fmul contract`, under thread `k`'s oracle
  numbers `o (ω k)`, from `+0` over `pairs A B r c K` (`Elem.put_read`, the cells apart by
  `Launch.apart_xy`);
* `x`'s bytes at every offset outside the cells of the threads in bounds (`Elem.put_out`);
* every other block of the caller's memory unchanged. -/
theorem read {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat}
    (hn : n ≤ sC) {bC : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, sA]}
    {B : Tensor (Model FloatTy.float.fmt) [n, sB]} {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes ω L K A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧
      (∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
        c < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
          (∀ k' < volume L.grid * volume L.block, L.index k' .x = r → L.index k' .y = c →
            k' = k) ∧
          naive.prog.layout.encode (.fp .float) (.ofFloat .float
            (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨r, hr⟩ ⟨c, hc⟩ K))) =
            some (y.read ((r * sC + c) * 4) 4)) ∧
      (∀ i, (∀ k, S L m n k → i < cell sC L k ∨ cell sC L k + 4 ≤ i) → y.bytes i = x.bytes i) ∧
      ∀ b x', b ≠ bC → mem.blocks b = some x' → Bk b = some x' := by
  have hO := Kernel.Sound.obs h rfl hB
  have hS : ∀ k l, bytes ω L K A B k = some l → S L m n k ∧ l.length = 4 := fun k l hb => by
    unfold bytes at hb
    split at hb
    · exact ⟨by assumption, (Elem.encode_float hb).1⟩
    · cases hb
  refine ⟨_, hO.1 x hx, fun r c hr hc hX hY => ?_,
    fun i hi => Elem.put_out x fun k _ l hl => ?_, hO.2⟩
  · obtain ⟨k, hk, rfl, rfl⟩ := Launch.cell_onto hL hX hY
    refine ⟨k, hk, rfl, rfl, fun k' hk' ex ey => Launch.xy_inj hL hz hk' hk (by rw [ex])
      (by rw [ey]), ?_⟩
    have hap : Apart (fun i : {i // bytes ω L K A B i ≠ none} => cell sC L i) 4 := by
      intro i j hij
      have hs : ∀ i : {i // bytes ω L K A B i ≠ none}, S L m n i.1 := fun i => by
        obtain ⟨l, hl⟩ := Option.ne_none_iff_exists'.1 i.2
        exact (hS _ _ hl).1
      exact Launch.apart_xy (s := sC) (m := m) hL hz hn 4 ⟨i.1, hs i⟩ ⟨j.1, hs j⟩
        fun e => hij (Subtype.ext (congrArg (fun x : {k // S L m n k} => x.1) e))
    obtain ⟨e, he, -, -⟩ := (Layout.Codec.float naive.prog.layout .float).round
      (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨_, hr⟩ ⟨_, hc⟩ K))
    have hb : bytes ω L K A B k = some e := by
      unfold bytes
      rw [dite_eq_left ⟨hk, hr, hc⟩]
      exact he
    have := Elem.put_read hap (fun k l h => (hS k l h).2) x (k := k) (by simp [hb])
      (volume L.grid * volume L.block)
    rw [ite_eq_left hk, hb, Option.getD_some] at this
    rw [he]
    exact congrArg some this.symm
  · obtain ⟨h1, h2⟩ := hS k l hl
    rw [h2]
    exact hi k h1

/-- **The cells of `C` after a kernel of the naive family against TorchLean's product, at every
stride.** Under the premises of `read` (every program, launch valid with `z` sides 1, sizes,
strides with `n ≤ sC`, tensors and memory, given the kernel's soundness for `bytes` at
`cell sC`), and `K ≤ sA`, `K ≤ sB`: every observation has a block `y` at `bC` where every cell
`(r, c)` in bounds and in the launch's window is computed by one thread `k` and holds the
binary32 encoding of a word `v` with

* `v` and entry `(r, c)` of TorchLean's `Tensor.matmul` of the first `K` columns of `A` and the
  transpose of the first `K` columns of `B` (`cols`) `NaNEq` (the same word or both NaNs) when no
  `fadd` oracle number of thread `k` is `2` modulo `3` (no round fused; `matmul_cols_nanEq`);
* when `v` is finite, `|v - (A Bᵀ)ᵣ꜀|` over the reals on those columns at most `dotBound` of
  binary32 at `K` and `Σⱼ<K |aᵣⱼ b꜀ⱼ|`, for every choice of fused rounds (`matmul_cols_error`). -/
theorem matmul {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat}
    (hn : n ≤ sC) (hA : K ≤ sA) (hB : K ≤ sB) {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, sA]} {B : Tensor (Model FloatTy.float.fmt) [n, sB]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes ω L K A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧
      ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
        c < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
          ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
            some (y.read ((r * sC + c) * 4) 4) ∧
          ((∀ j, (o (ω k) j).2 % 3 ≠ 2) → NaNEq v (Tensor.get2 (Tensor.matmul (cols K hA A)
            (Tensor.permute (cols K hB B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩
              ⟨c, hc⟩)) ∧
          (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
            (Tensor.map Model.toReal (cols K hA A)) (Tensor.map Model.toReal
              (Tensor.permute (cols K hB B) (Shape.adjacentSwap [n, K] 0) [K, n])))
                ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt K ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                  K).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) := by
  obtain ⟨y, hy, hc, -, -⟩ := read hL hz hn h hx hO
  refine ⟨y, hy, fun r c hr hc' hX hY => ?_⟩
  obtain ⟨k, hk, ex, ey, -, he⟩ := hc r c hr hc' hX hY
  refine ⟨k, hk, ex, ey, _, he, fun hu => ?_, fun hf => ?_⟩
  · unfold pairs
    rw [← Fin.ofFn_take_eq_take_ofFn (Nat.le_min.2 ⟨hA, hB⟩)]
    exact matmul_cols_nanEq true _ A B hA hB _ _ fun j _ => hu j
  · unfold pairs at hf ⊢
    rw [← Fin.ofFn_take_eq_take_ofFn (Nat.le_min.2 ⟨hA, hB⟩)] at hf ⊢
    exact matmul_cols_error (isIEEE_fmt _) true _ A B hA hB _ _ hf

/-- **Every cell of `C` after a kernel of the naive family when the launch covers `m × n`, at
every stride.** Under the premises of `read` (every program, function, launch valid with `z`
sides 1, sizes, strides with `n ≤ sC`, tensors and memory, given the kernel's soundness for
`bytes` at `cell sC`) and a window that covers the result (`m ≤ grid.x * block.x`,
`n ≤ grid.y * block.y`): every observation `Bk` has a block `y` at `bC` where every cell `(r, c)`
with `r < m` and `c < n` is computed by one thread `k`, of row `r` and column `c`, whose 4 bytes
at offset `(r * sC + c) * 4` encode `dotLoop` with `fmul contract` under `o (ω k)` from `+0`
over `pairs A B r c K` (`read`, its window premises by `hm` and `hn'`). -/
theorem cover {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat}
    (hn : n ≤ sC) {bC : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, sA]}
    {B : Tensor (Model FloatTy.float.fmt) [n, sB]} {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes ω L K A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk)
    (hm : m ≤ L.grid .x * L.block .x) (hn' : n ≤ L.grid .y * L.block .y) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n),
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        (∀ k' < volume L.grid * volume L.block, L.index k' .x = r → L.index k' .y = c →
          k' = k) ∧
        naive.prog.layout.encode (.fp .float) (.ofFloat .float
          (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨r, hr⟩ ⟨c, hc⟩ K))) =
          some (y.read ((r * sC + c) * 4) 4) :=
  let ⟨y, hy, hc, _⟩ := read hL hz hn h hx hB
  ⟨y, hy, fun r c hr hc' => hc r c hr hc' (hr.trans_le hm) (hc'.trans_le hn')⟩

/-- **The cells of `C` after a kernel of the naive family against TorchLean's product up to NaNs,
at every stride.** Under the premises of `matmul` (those of `read`, and `K ≤ sA`, `K ≤ sB`): every
observation `Bk` has a block `y` at `bC` where every cell `(r, c)` in bounds and in the launch's
window is computed by one thread `k` and holds the binary32 encoding of a word `v` which, when no
`fadd` oracle number of thread `k` is `2` modulo `3` (no round fused), and entry `(r, c)` of
TorchLean's `Tensor.matmul` of the first `K` columns of `A` and the transpose of the first `K`
columns of `B` (`cols`) are the same word or both NaNs (`NaNEq`; `matmul`'s first clause). -/
theorem matmul_nanEq {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat}
    (hn : n ≤ sC) (hA : K ≤ sA) (hB : K ≤ sB) {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, sA]} {B : Tensor (Model FloatTy.float.fmt) [n, sB]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes ω L K A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * sC + c) * 4) 4) ∧
        ((∀ j, (o (ω k) j).2 % 3 ≠ 2) → NaNEq v (Tensor.get2 (Tensor.matmul (cols K hA A)
          (Tensor.permute (cols K hB B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩
            ⟨c, hc⟩)) :=
  let ⟨y, hy, hc⟩ := matmul hL hz hn hA hB h hx hO
  ⟨y, hy, fun r c hr hc' hX hY =>
    let ⟨k, hk, ex, ey, v, he, hu, _⟩ := hc r c hr hc' hX hY
    ⟨k, hk, ex, ey, v, he, hu⟩⟩

/-- **The finite cells of `C` after a kernel of the naive family are within `dotBound` of the
real product, at every stride.** Under the premises of `matmul`: every observation `Bk` has a
block `y` at `bC` where every cell `(r, c)` in bounds and in the launch's window is computed by
one thread `k` and holds the binary32 encoding of a word `v`; when `v` is finite,
`|v - (A Bᵀ)ᵣ꜀|` over the reals on the first `K` columns (`cols`, mapped by `Model.toReal`) is at
most `dotBound` of binary32 at `K` and `Σⱼ<K |aᵣⱼ b꜀ⱼ|`, whichever rounds the oracle fuses
(`matmul`'s second clause). -/
theorem matmul_error {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat}
    (hn : n ≤ sC) (hA : K ≤ sA) (hB : K ≤ sB) {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, sA]} {B : Tensor (Model FloatTy.float.fmt) [n, sB]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes ω L K A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * sC + c) * 4) 4) ∧
        (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
          (Tensor.map Model.toReal (cols K hA A)) (Tensor.map Model.toReal
            (Tensor.permute (cols K hB B) (Shape.adjacentSwap [n, K] 0) [K, n])))
              ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt K ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                K).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
  let ⟨y, hy, hc⟩ := matmul hL hz hn hA hB h hx hO
  ⟨y, hy, fun r c hr hc' hX hY =>
    let ⟨k, hk, ex, ey, v, he, _, hf⟩ := hc r c hr hc' hX hY
    ⟨k, hk, ex, ey, v, he, hf⟩⟩

/-- **`matmul_nanEq` at the oracle family that fuses nothing, at every stride**: at
`fun _ _ => 0` every `fadd` oracle number is `0`, so no thread fuses a round and `matmul_nanEq`'s
premise holds. Under the premises of `matmul` at that oracle family: every observation `Bk` has a
block `y` at `bC` where every cell `(r, c)` in bounds and in the launch's window holds the
binary32 encoding of a word `NaNEq` to entry `(r, c)` of TorchLean's `Tensor.matmul` of the
first `K` columns of `A` and the transpose of the first `K` columns of `B`. -/
theorem nanEq_zero {prog : Program} {fn : Func} {args : List Val} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K sA sB sC : Nat} (hn : n ≤ sC) (hA : K ≤ sA)
    (hB : K ≤ sB) {bC : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, sA]}
    {B : Tensor (Model FloatTy.float.fmt) [n, sB]} {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = fun _ _ => 0) (fun m => some m.blocks)
      (Elem.Out mem bC (cell sC L) (bytes (fun _ _ => 0) L K A B)
        (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch (fun _ _ => 0) Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * sC + c) * 4) 4) ∧
        NaNEq v (Tensor.get2 (Tensor.matmul (cols K hA A)
          (Tensor.permute (cols K hB B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩ ⟨c, hc⟩) :=
  let ⟨y, hy, hc⟩ := matmul_nanEq hL hz hn hA hB h hx hO
  ⟨y, hy, fun r c hr hc' hX hY =>
    let ⟨_, _, _, _, v, he, hu⟩ := hc r c hr hc' hX hY
    ⟨v, he, hu fun _ => by simp [o]⟩⟩

/-- `read` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of strides
(the first is `NaiveSound.naive_read`, at the corpus's). -/
theorem read_16_8_5 {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m : Nat} {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 16]} {B : Tensor (Model FloatTy.float.fmt) [5, 8]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes ω L 8 A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧
      (∀ r c (hr : r < m) (hc : c < 5), r < L.grid .x * L.block .x →
        c < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
          (∀ k' < volume L.grid * volume L.block, L.index k' .x = r → L.index k' .y = c →
            k' = k) ∧
          naive.prog.layout.encode (.fp .float) (.ofFloat .float
            (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨r, hr⟩ ⟨c, hc⟩ 8))) =
            some (y.read ((r * 5 + c) * 4) 4)) ∧
      (∀ i, (∀ k, S L m 5 k → i < cell 5 L k ∨ cell 5 L k + 4 ≤ i) → y.bytes i = x.bytes i) ∧
      ∀ b x', b ≠ bC → mem.blocks b = some x' → Bk b = some x' :=
  read hL hz le_rfl h hx hB

/-- `matmul` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of
strides (the first is `NaiveSound.naive_matmul`, at the corpus's). -/
theorem matmul_16_8_5 {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m : Nat} {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 16]} {B : Tensor (Model FloatTy.float.fmt) [5, 8]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes ω L 8 A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧
      ∀ r c (hr : r < m) (hc : c < 5), r < L.grid .x * L.block .x →
        c < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
          ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
            some (y.read ((r * 5 + c) * 4) 4) ∧
          ((∀ j, (o (ω k) j).2 % 3 ≠ 2) → NaNEq v (Tensor.get2 (Tensor.matmul
            (cols 8 (by decide) A) (Tensor.permute (cols 8 le_rfl B)
              (Shape.adjacentSwap [5, 8] 0) [8, 5])) ⟨r, hr⟩ ⟨c, hc⟩)) ∧
          (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
            (Tensor.map Model.toReal (cols 8 (by decide) A)) (Tensor.map Model.toReal
              (Tensor.permute (cols 8 le_rfl B) (Shape.adjacentSwap [5, 8] 0) [8, 5])))
                ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt 8 ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                  8).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
  matmul hL hz le_rfl (by decide) le_rfl h hx hO

/-- `cover` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of strides
(the first is `NaiveKernel.read_cover`, at the corpus's). -/
theorem cover_16_8_5 {prog : Program} {fn : Func} {args : List Val} {ω : Nat → Nat → Nat}
    {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m : Nat} {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 16]} {B : Tensor (Model FloatTy.float.fmt) [5, 8]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes ω L 8 A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk)
    (hm : m ≤ L.grid .x * L.block .x) (hn : 5 ≤ L.grid .y * L.block .y) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < 5),
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        (∀ k' < volume L.grid * volume L.block, L.index k' .x = r → L.index k' .y = c →
          k' = k) ∧
        naive.prog.layout.encode (.fp .float) (.ofFloat .float
          (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B ⟨r, hr⟩ ⟨c, hc⟩ 8))) =
          some (y.read ((r * 5 + c) * 4) 4) :=
  cover hL hz le_rfl h hx hB hm hn

/-- `matmul_nanEq` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of
strides (the first is `NaiveKernel.matmul_nanEq`, at the corpus's). -/
theorem matmul_nanEq_16_8_5 {prog : Program} {fn : Func} {args : List Val}
    {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {m : Nat} {bC : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, 16]}
    {B : Tensor (Model FloatTy.float.fmt) [5, 8]} {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes ω L 8 A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < 5), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 5 + c) * 4) 4) ∧
        ((∀ j, (o (ω k) j).2 % 3 ≠ 2) → NaNEq v (Tensor.get2 (Tensor.matmul
          (cols 8 (by decide) A) (Tensor.permute (cols 8 le_rfl B)
            (Shape.adjacentSwap [5, 8] 0) [8, 5])) ⟨r, hr⟩ ⟨c, hc⟩)) :=
  matmul_nanEq hL hz le_rfl (by decide) le_rfl h hx hO

/-- `matmul_error` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of
strides (the first is `NaiveKernel.matmul_error`, at the corpus's). -/
theorem matmul_error_16_8_5 {prog : Program} {fn : Func} {args : List Val}
    {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {m : Nat} {bC : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, 16]}
    {B : Tensor (Model FloatTy.float.fmt) [5, 8]} {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes ω L 8 A B) (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < 5), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 5 + c) * 4) 4) ∧
        (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
          (Tensor.map Model.toReal (cols 8 (by decide) A)) (Tensor.map Model.toReal
            (Tensor.permute (cols 8 le_rfl B) (Shape.adjacentSwap [5, 8] 0) [8, 5])))
              ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt 8 ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                8).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) :=
  matmul_error hL hz le_rfl (by decide) le_rfl h hx hO

/-- `nanEq_zero` at row strides 16, 8 and 5, `K = 8` and 5 columns: a test at a second set of
strides (the first is `NaiveKernel.nanEq_zero`, at the corpus's). -/
theorem nanEq_zero_16_8_5 {prog : Program} {fn : Func} {args : List Val} {L : Launch}
    (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) {m : Nat} {bC : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 16]} {B : Tensor (Model FloatTy.float.fmt) [5, 8]}
    {mem : Mem}
    (h : Kernel.Sound prog fn L args mem (fun _ ω' => ω' = fun _ _ => 0) (fun m => some m.blocks)
      (Elem.Out mem bC (cell 5 L) (bytes (fun _ _ => 0) L 8 A B)
        (volume L.grid * volume L.block)))
    {x : Sem.Block} (hx : mem.blocks bC = some x) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch (fun _ _ => 0) Bk) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < 5), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 5 + c) * 4) 4) ∧
        NaNEq v (Tensor.get2 (Tensor.matmul (cols 8 (by decide) A)
          (Tensor.permute (cols 8 le_rfl B) (Shape.adjacentSwap [5, 8] 0) [8, 5])) ⟨r, hr⟩
            ⟨c, hc⟩) :=
  nanEq_zero hL hz le_rfl (by decide) le_rfl h hx hO

end MojoProofTest.NaiveFam
