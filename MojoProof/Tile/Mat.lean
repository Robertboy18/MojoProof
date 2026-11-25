import MojoProof.Tile.Dot
import MojoProof.Sym.Kernel
import MojoProof.Sem.Index

/-!
# The tile matrix product and the kernels of `mojo_kernel`'s `mat` clause

This module relates the tile program `dot c K` of MojoProof/Tile/Dot.lean to every matmul kernel
whose theorem is `Kernel.Sound` for `Elem.Out` at the cells of `Kernel.sound_mat`'s conclusion.
It defines:

* `place L m p`: the placement of a launch's threads, thread `t` below the thread count with
  row `L.index t .x < m` and column `L.index t .y < p` at that row and column, the other threads
  at none;
* `matBytes l ft c o L hA hB A B`: the bytes a thread of such a kernel puts at its cell, the
  encoding of `dotLoop c` at its oracle numbers `o k` from `+0` over the first `K` pairs of its
  row of `A` and its row of `B`.

It proves:

* `place_inj`: no two threads of `place L m p` are at one cell, on every valid launch whose
  grid and block have side 1 in `z` (`Launch.xy_inj`);
* `mat_word`: the float at a cell of `Elem.Out` for `matBytes` (`Elem.word`) is the
  thread's `dotLoop`;
* `mat_refines`: for every program, kernel, launch valid with `z` sides 1, arguments, memory,
  admission, layout, float type, contraction flag, oracle numbers, sizes, row strides, cell
  width and matrices, `Kernel.Sound` for `Elem.Out` with `matBytes` gives that in every
  observation of a complete run (`Kernel.Obs`) at an admitted choice the run of
  `dot c K (place L m p)` from `mats A B` at the tile oracle `pairOracle o` ends without a fault,
  and every cell `(r, col)` in bounds and in the launch's window is computed by a thread whose
  output cell holds the word at cell `Nat.pair r col` of buffer 2, a word that meets TorchLean's
  product (`Meets`: up to NaN payloads with the contraction off, within `dotBound` when finite,
  and `GPUProof.Approx` at `GPUProof.dotGrade` of every exact entries and grades at which its
  row and column are `GPUProof.Approx`). It covers every kernel with such a theorem.

Nothing here is in the trusted base.
-/

namespace MojoProof.Tile

open MojoProof.Sem MojoProof.Sym FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  TorchLean

/-- The placement of the threads of launch `L` on `m` rows and `p` columns: thread `t` below the
thread count with `L.index t .x < m` and `L.index t .y < p` at row `L.index t .x` and column
`L.index t .y`, the other threads at none. -/
def place (L : Launch) (m p : Nat) (t : Nat) : Option (Fin m × Fin p) :=
  if h : t < volume L.grid * volume L.block ∧ L.index t .x < m ∧ L.index t .y < p then
    some (⟨L.index t .x, h.2.1⟩, ⟨L.index t .y, h.2.2⟩)
  else none

/-- No two threads of `place L m p` are at one cell, on every valid launch whose grid and block
have side 1 in `z`, for all `m` and `p` (`Launch.xy_inj`). -/
theorem place_inj {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1) (m p : Nat)
    (t t' : Nat) (x : Fin m × Fin p) (h : place L m p t = some x)
    (h' : place L m p t' = some x) : t = t' := by
  unfold place at h h'
  split at h <;> split at h' <;> simp only [Option.some.injEq, reduceCtorEq] at h h'
  rename_i h1 h2
  rw [← h'] at h
  simp only [Prod.mk.injEq, Fin.mk.injEq] at h
  exact Launch.xy_inj hL hz h1.1 h2.1 (by rw [h.1]) (by rw [h.2])

/-- **The bytes of a matmul kernel's thread** under layout `l`, of float type `ft`, contraction
flag `c`, oracle numbers `o` and launch `L`, for `K ≤ sA`, `K ≤ sB` and matrices `A` (`m × sA`)
and `B` (`p × sB`): thread `k` below the thread count with row `L.index k .x < m` and column
`L.index k .y < p` puts the encoding of `dotLoop c (o k)` from `+0` over the pairs
`(get2 A row j, get2 B column j)`, `j < K`; the other threads put nothing. -/
def matBytes (l : Layout) (ft : LLVM.FloatTy) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (L : Launch) {m p sA sB K : Nat} (hA : K ≤ sA) (hB : K ≤ sB)
    (A : Tensor (Model ft.fmt) [m, sA]) (B : Tensor (Model ft.fmt) [p, sB]) (k : Nat) :
    Option (List MemByte) :=
  if h : k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < p then
    l.encode (.fp ft) (.ofFloat ft (dotLoop c (o k) (Model.zero _ false)
      (List.ofFn fun j : Fin K => (Tensor.get2 A ⟨_, h.2.1⟩ (Fin.castLE hA j),
        Tensor.get2 B ⟨_, h.2.2⟩ (Fin.castLE hB j)))))
  else none

/-- **The float at a cell of `Elem.Out` for `matBytes`.** For every memory `mem` with a block
`out`, launch `L` valid with `z` sides 1, layout `l`, float type `ft` whose stored size is `w`,
flag `c`, oracle numbers `o`, sizes with `p ≤ sC`, matrices and blocks `B` that meet `Elem.Out`
after all the launch's threads for `matBytes` at the cells `(row * sC + column) * w`: every thread
`k` below the thread count with row `L.index k .x < m` and column `L.index k .y < p` leaves at its
cell (`Elem.word`) its `dotLoop` (`Launch.apart_xy`, `Elem.put_read`, `Elem.encode_float`). -/
theorem mat_word {mem : Mem} {out : Nat} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {l : Layout} {ft : LLVM.FloatTy} {w : Nat}
    (hw : l.stored (.fp ft) = w) {c : Bool} {o : Nat → Nat → Nat × Nat} {m p sA sB sC K : Nat}
    (hsC : p ≤ sC) {hA : K ≤ sA} {hB : K ≤ sB} {A : Tensor (Model ft.fmt) [m, sA]}
    {B : Tensor (Model ft.fmt) [p, sB]} {Bk : Nat → Option Sem.Block}
    (h : Elem.Out mem out (fun k => (L.index k .x * sC + L.index k .y) * w)
      (matBytes l ft c o L hA hB A B) (volume L.grid * volume L.block) Bk)
    (hb : ∃ blk, mem.blocks out = some blk) {k : Nat} (hk : k < volume L.grid * volume L.block)
    (hr : L.index k .x < m) (hc : L.index k .y < p) :
    Elem.word l ft out (fun k => (L.index k .x * sC + L.index k .y) * w) Bk k =
      some (dotLoop c (o k) (Model.zero _ false) (List.ofFn fun j : Fin K =>
        (Tensor.get2 A ⟨_, hr⟩ (Fin.castLE hA j), Tensor.get2 B ⟨_, hc⟩ (Fin.castLE hB j)))) := by
  obtain ⟨blk, hblk⟩ := hb
  have hS : ∀ k b, matBytes l ft c o L hA hB A B k = some b →
      (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < p) ∧
        b.length = w := fun k b hb => by
    unfold matBytes at hb
    split at hb
    · exact ⟨by assumption, hw ▸ (Elem.encode_float hb).1⟩
    · cases hb
  have hap : Apart (fun i : {i // matBytes l ft c o L hA hB A B i ≠ none} =>
      (L.index i.1 .x * sC + L.index i.1 .y) * w) w := fun i j hij => by
    have hs : ∀ i : {i // matBytes l ft c o L hA hB A B i ≠ none},
        i.1 < volume L.grid * volume L.block ∧ L.index i.1 .x < m ∧ L.index i.1 .y < p :=
      fun i => (hS _ _ (Option.ne_none_iff_exists'.1 i.2).choose_spec).1
    exact Launch.apart_xy (m := m) hL hz hsC w ⟨i.1, hs i⟩ ⟨j.1, hs j⟩
      fun e => hij (Subtype.ext (Subtype.mk.inj e))
  obtain ⟨e, he, -, hd⟩ := (Layout.Codec.float l ft).round
    (dotLoop c (o k) (Model.zero _ false) (List.ofFn fun j : Fin K =>
      (Tensor.get2 A ⟨_, hr⟩ (Fin.castLE hA j), Tensor.get2 B ⟨_, hc⟩ (Fin.castLE hB j))))
  have hbk : matBytes l ft c o L hA hB A B k = some e := by
    unfold matBytes
    rw [dite_eq_left ⟨hk, hr, hc⟩]
    exact he
  have hpr := Elem.put_read (cell := fun k => (L.index k .x * sC + L.index k .y) * w) hap
    (fun k l h => (hS k l h).2) blk (k := k) (by simp [hbk]) (volume L.grid * volume L.block)
  rw [ite_eq_left hk, hbk, Option.getD_some] at hpr
  simp only [Elem.word, h.1 blk hblk, Option.bind_some, hw, hpr, hd, Val.float?_ofFloat]

/-- **A kernel of the `mat` clause refines the tile matrix product.** For every program, kernel,
launch `L` valid with `z` sides 1, arguments, memory `mem` with a block `out`, admission, layout
`l`, float type `ft` whose stored size is `w`, contraction flag `c`, oracle numbers `o`, sizes
`m`, `p`, `K` with `K ≤ sA`, `K ≤ sB` and `p ≤ sC`, and matrices `A` (`m × sA`) and `B`
(`p × sB`): if the kernel is sound (`Kernel.Sound`) for `Elem.Out` of `mem`'s block `out` after
all the launch's threads with `matBytes` at the cells `(row * sC + column) * w` (the shape of
`Kernel.sound_mat`'s conclusion), then for every admitted address choice and oracle and every
observation `Bk` of a complete run (`Kernel.Obs`), the run of `dot c K (place L m p)` on all the
launch's threads from `mats A B` at the tile oracle `pairOracle o` ends without a fault in a
state `st`, and every cell `(r, col)` with `r < m`, `col < p` and in the launch's window is
computed by a thread `k` of row `r` and column `col` whose output cell holds (`Elem.word`) the
word `v` at cell `Nat.pair r col` of buffer 2 of `st`, and `v` meets TorchLean's product of the
first `K` columns of `A` and the transpose of the first `K` columns of `B` at `(r, col)` under
the oracle numbers `o k` (`Meets`, with its graded clause: `GPUProof.Approx` at
`GPUProof.dotGrade`; `dot_run`, `mat_word`, `meets_dotLoop`). It covers every kernel with such a
theorem. -/
theorem mat_refines {prog : LLVM.Program} {fn : LLVM.Func} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {args : List Val} {mem : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {out : Nat} {l : Layout} {ft : LLVM.FloatTy}
    {w : Nat} (hw : l.stored (.fp ft) = w) {c : Bool} {o : Nat → Nat → Nat × Nat}
    {m p sA sB sC K : Nat} (hsC : p ≤ sC) {hA : K ≤ sA} {hB : K ≤ sB}
    {A : Tensor (Model ft.fmt) [m, sA]} {B : Tensor (Model ft.fmt) [p, sB]}
    (h : Kernel.Sound prog fn L args mem adm (fun m => some m.blocks)
      (Elem.Out mem out (fun k => (L.index k .x * sC + L.index k .y) * w)
        (matBytes l ft c o L hA hB A B) (volume L.grid * volume L.block)))
    (hb : ∃ blk, mem.blocks out = some blk) {ch : Nat → Nat} {ω : Nat → Nat → Nat}
    (ha : adm ch ω) {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle o) (dot c K (place L m p)) (volume L.grid * volume L.block)
        (mats A B) = .ok st ∧
      ∀ r col (hr : r < m) (hc : col < p), r < L.grid .x * L.block .x →
        col < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = col ∧
          ∃ v, st.cells 2 (Nat.pair r col) = some v ∧
            Elem.word l ft out (fun k => (L.index k .x * sC + L.index k .y) * w) Bk k = some v ∧
            Meets A B hA hB ⟨r, hr⟩ ⟨col, hc⟩ c (o k) v := by
  obtain ⟨st, hr, -, h2⟩ := dot_run c hA hB A B (place_inj hL hz m p) (pairOracle o)
    (volume L.grid * volume L.block)
  refine ⟨st, hr, fun r col hr' hc' hX hY => ?_⟩
  obtain ⟨k, hk, rfl, rfl⟩ := Launch.cell_onto hL hX hY
  have hp : place L m p k = some (⟨L.index k .x, hr'⟩, ⟨L.index k .y, hc'⟩) := by
    unfold place
    rw [dite_eq_left ⟨hk, hr', hc'⟩]
  have hv := h2 k _ _ hk hp
  rw [dotOracle_pair] at hv
  exact ⟨k, hk, rfl, rfl, _, hv,
    mat_word hL hz hw hsC (Kernel.Sound.obs h ha hO) hb hk hr' hc',
    meets_dotLoop A B hA hB _ _ c _⟩

end MojoProof.Tile
