import GPUProof.View
import MojoProof.Sem.Index
import MojoProof.Sem.SigDef
import MojoProofTest.GPUProof.MixedRadix
import MojoProofTest.Index

/-!
# Views at MojoProof's machine: gemv and the naive matmul, at the bytes they store

GPUProof/View.lean defines, for every machine, the instances of a level (`Sig.Inst`), views
(`View`) with the instances that own a tile (`View.Owner`), their well-formedness at one size
assignment and launch (`View.WF`) and the tile of an instance (`View.tile`). Here, at one
machine, MojoProof's `sig` (`MojoProof.Sem.sig`), whose `place b i` is byte `i` of buffer `b`,
two views are well formed at every admissible assignment and launch of their kernels, and the
tile of each instance is a natural-number model of the 4-byte float that the kernel stores: its
offsets are numbers, with no width. MojoProofTest/GPUProof/ViewWords.lean relates them to the
kernels' 32- and 64-bit words under the word premise, the key's radix product below `2 ^ 31`
(`GPUProof.View.key_fits`), at which no word wraps (`gemv_words`, `naive_words`); that a run's
store is at that address is not proved here. gemv's IR is
tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll (the
store's address at :50, the store at :136) and the naive matmul's
tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll (:41
and :84):

* `elem w`: the layout of one element of `w` bytes, of size and cosize `w`, coordinate `c` at
  byte `c`, onto its bytes (`elem_onto`); both views use it at `w = 4`.
* `gemv_wf`: gemv's output vector at the warp level (level 1), in buffer `y`, with the key
  `warpIdx 0 1` (MojoProofTest/GPUProof/MixedRadix.lean), `bind` setting the variables 0 and 1
  to the warp's first thread's `tid.x` and `ctaid.x`, and a warp owning a tile when its row is
  below `m` (the variable 7), as the kernel's `icmp sge` on the row (:55) skips the store. It is
  admitted (`gemvAdm`) at the 1-D launches (side 1 in `y` and `z`) where the variables 4, 5 and
  6 are `ntid.x`, 32 and `nctaid.x`, and 32 divides `ntid.x`. At every admissible assignment and
  launch, the key at a thread's warp is the thread's row `(ctaid.x · ntid.x + tid.x) / 32`
  (:13-21; `gemv_row`, with `Launch.index`), and the warp's tile is bytes `4 · row` to
  `4 · row + 3` of `y` when the row is below `m`, and none otherwise (`gemv_tile`), the model of
  the kernel's store when `m < 2 ^ 31` (`gemv_words`).
* `naive_wf`: the naive matmul's output at the thread level (level 0), in buffer `c`, with the
  key `entryIdx 0 1` (the column with radix `n`, the variable 5, then the row with radix `m`, the
  variable 4), whose value is `row · n + col` (`naive_val`), `bind` setting the row and the
  column (`Launch.index` in `x` and `y`), and a thread owning a tile when its row is below `m`
  and its column below `n`, as the kernel's two `icmp sge` (:42-43) skip the store. The IR's row
  stride is the constant 50257 (:28) and its column bound the argument `%4` (:15, :43), and the
  family's kernels differ by the constant, so `naiveAdm N` admits, for the kernel of row stride
  `N`, the assignments with `n = N` and the valid launches with side 1 in `z`; the corpus kernel
  is `N = 50257`. At every assignment with `n = N` and every launch, the thread at
  `(row, col)` covers bytes `4 · (row · N + col)` to `4 · (row · N + col) + 3` of `c`
  (`naive_tile`), the model of the float the kernel stores (:39-41) when `m · N < 2 ^ 31`
  (`naive_words`).

`inst_sig`: an instance of level `l` of `sig` is `(l, Launch.groupNum L l t)` for a thread `t`
below the thread count. Both guards hold at some launch (the `example`s after `gemv_tile` and
`naive_tile`: gemv's at 4 blocks of 128 threads, the corpus naive kernel's at one block of 2 × 2
threads and `n = 50257`).
The mutants:

* `gemv_gridY`: at grid (1,2,1) and block (32,1,1), `gemvAdm` fails, the two warps (threads 0
  and 32) have the row 0, the binding by the flattened thread number (`flatBind`) gives
  them the keys 0 and 1, and `WF` fails, as the two warps store the same bytes;
* `gemv_zero` and `gemv_old`: at `m = 1`, the other variables 0, and the launch of one thread,
  the guard and `WF` fail, so `WF` at every assignment and launch fails for gemv's view;
* `naive_zero`: at the assignment `0` and the launch of one thread the view is well formed (no
  thread owns a tile), and the view without the guard on instances (`naiveAll`) is not;
* `naive_overshoot`: at `m = n = 1` and one block of 2 × 1 threads (a launch that covers the
  rows, as `MojoProof.Tile.MatSetup.Fits` admits), the view is well formed, thread 1 (row 1)
  covers no byte, and the view without the guard is not well formed;
* `naive_z`: at one block of 1 × 1 × 2 threads (MojoProofTest/Index.lean's `L112`), the two
  threads have one row and one column, and `WF` fails, so `naiveAdm`'s side 1 in `z` is needed.

The tilings, `View.tiling` at `place_inj` (`sig`'s placement is injective):

* `gemv_tiling` and `naive_tiling`: at every admissible assignment and launch, every owner's tile
  is in the view's bytes and the tiles of two instances are disjoint, with two `example`s each at
  unrelated launches: gemv's at grid (4,1,1) and block (128,1,1) with `m = 500`, and at grid
  (7,1,1) and block (96,1,1) with `m = 20`; the naive one's at one block of 2 × 2 threads with
  `m = n = 2`, and at grid (3,2,1) and block (4,8,1) with `m = 10` and `n = 15`. `gemv_mem` is
  the bytes of gemv's tile at every instance.
* `gemv_overlap`: at grid (1,2,1) and block (32,1,1), the launch of `gemv_gridY`, the warps of
  threads 0 and 32 both hold byte 0 of `y`, so gemv's tiles are not a tiling.
* `naive_stride`: at `m = n = 2` and one block of 2 × 2 threads, the assignment is not the corpus
  kernel's (`naiveAdm 50257` fails), and that kernel's store of thread 1 (row 1), at byte
  `4 · 50257` of `c` in the model (`2 · 50257 < 2 ^ 31`, so its words do not wrap), is not in
  thread 1's tile, bytes 8 to 11.
* `bound_radix`: a thread view whose key's radix is a variable its binding sets (`boundView`,
  `boundKey`, `twoBind`), at grid (1,1,1) and block (2,1,1): `range` and `key_inj` hold and
  `radices` fails, and the tiles are not a tiling, as thread 1's tile is past the view's bytes.

Coverage, `View.cover` at `elem_onto`:

* `gemv_cover`: at every admissible assignment and launch with at least `m` warps, each of the
  first `4 m` bytes of `y` is in a warp's tile, with two `example`s: at grid (4,1,1) and block
  (128,1,1) with `m = 16`, and at grid (7,1,1) and block (96,1,1) with `m = 20`.
* `gemv_uncovered`: at every admissible assignment and launch, the bytes of `y` from `4 m` up to
  4 times the warp count are in `bytes` and in no tile, with the `example` of byte 80 at grid
  (7,1,1), block (96,1,1) and `m = 20` (21 warps): with more warps than rows the tiles do not
  cover `bytes`.
* `naive_cover`: at every assignment with `n = N` and every valid launch whose rows and columns
  of threads reach `m` and `N`, the tiles cover the view's bytes, the `m · N` floats of `c`, with
  three `example`s: at one block of 2 × 2 threads with `m = n = 2`, the corpus kernel's at grid
  (1,3142,1) and block (4,16,1) with `m = 4` and `n = 50257`, and at one block of 1 × 1 × 2
  threads (`L112`) with `m = n = 1`, where `naiveAdm` fails (side 2 in `z`) and the view is not
  well formed (`naive_z`).

Coarsening, `View.tile_subset_coarsen` and `View.coarsen_tile`:

* `gemv_coarsen`: gemv's view coarsened to the block level (level 2), with the warp digit as one
  more layout mode and the block digit bound to the block's number (`gemvBlock`), has at every
  block `b` a tile that holds the tiles of its warps, at every admissible assignment and launch,
  and the union of them when `b` is a block of the launch whose rows are below `m`.
  `gemv_outer`, `gemv_inner` and `gemv_innerProd` value the key's block digit, its warp digit
  and the warp digit's radix.
* `gemv_partial`: at grid (7,1,1), block (96,1,1) and `m = 20`, the last block, 6, has warps 18
  to 20, and warp 20 (row 20) owns no tile; the block's coarse tile holds its warps' tiles and
  byte 80 of `y`, which no warp's tile holds.
* `gemv_coarsen_radix`: at grid (1,1,1) and block (32,1,1) with `ntid.x` assigned 64, the warp
  digit's radix is 2, one more than the block's warp count; `gemvAdm` fails and the view is well
  formed there (every thread's warp is warp 0, `oneWarp_group`), `ho` fails at the warp digit 1,
  and the coarse tile of block 0, bytes 0 to 7 of `y`, is not the union of its warp's tile,
  bytes 0 to 3.
-/

namespace MojoProofTest.GPUProof.View

open _root_.GPUProof _root_.GPUProof.Layout _root_.GPUProof.Layout.Tup MojoProof.Sem
open MojoProofTest.GPUProof.MixedRadix (warpIdx entryIdx inRange_warpIdx asg gemv_val)
open MojoProofTest.Index (L112)

/-! ## What `WF` reads of `sig` -/

/-- An instance of level `l` of `sig` in launch `L` is the level and the number
`Launch.groupNum L l t` of a thread `t` below the thread count: `threads` is `List.range`, so
`Inst` costs one `List.mem_range`. -/
theorem inst_sig {L : Launch} {l : Fin 4} {g : Fin 4 × Nat} :
    sig.Inst L l g ↔ ∃ t < volume L.grid * volume L.block, (l, L.groupNum l t) = g := by
  simp [Sig.Inst]

/-! ## The element layout -/

/-- The layout of one element of `w` bytes: one mode of extent `w` and stride 1, so the element's
coordinate `c` is its byte `c`. -/
def elem (w : Nat) : Lay := Lay.flat [(w, 1)]

/-- The element layout's shape and stride have one nesting, for every width `w`. -/
theorem elem_congruent (w : Nat) : congruentL (elem w).shape (elem w).stride = true := rfl

/-- The element layout's one extent is positive, for every positive width `w`. -/
theorem elem_pos {w : Nat} (hw : 0 < w) : ∀ s ∈ leavesL (elem w).shape, 0 < s := by
  intro s hs
  simp [elem, Lay.flat, leavesL, leaves] at hs
  omega

/-- The element layout has `w` coordinates, for every width `w`. -/
theorem elem_size (w : Nat) : (elem w).size = w := by
  simp [elem, Lay.flat, Lay.size, Tup.size, leaves, leavesL]

/-- The element layout's offset of coordinate `c` is `c`, for every width `w` and coordinate `c`. -/
theorem elem_call (w c : Nat) (b : Bool) : (elem w).call (leaf c b) = c := by
  simp [elem, Lay.flat, Lay.call, crd2idx, splitIdx, len, scalar, value]

/-- The element layout's cosize is its width, for every positive width `w`. -/
theorem elem_cosize {w : Nat} (hw : 0 < w) : (elem w).cosize = w := by
  rw [Lay.cosize, elem_call, elem_size]
  omega

/-- The element layout is onto its bytes: every offset below its cosize is the offset of a
coordinate below its size, for every positive width `w`. -/
theorem elem_onto {w : Nat} (hw : 0 < w) :
    ∀ a < (elem w).cosize, ∃ c < (elem w).size, (elem w).call (leaf c false) = a := fun a ha =>
  ⟨a, by rw [elem_size]; rw [elem_cosize hw] at ha; exact ha, elem_call w a false⟩

/-! ## gemv: the warp view on `sig` -/

/-- A warp's first thread is `Launch.groupNum` at level 1, for every launch and thread. -/
theorem groupNum_one (L : Launch) (t : Nat) : L.groupNum 1 t = t - t % volume L.block % 32 := rfl

/-- A warp's first thread `t - t % B % 32` (`Launch.groupNum` at level 1, `B` the block's
thread count): its offset in its block is `32 (t % B / 32)` and its block `t / B`. -/
theorem warp_base {B t : Nat} (hB : 0 < B) :
    t - t % B % 32 = B * (t / B) + 32 * (t % B / 32) ∧
      (t - t % B % 32) % B = 32 * (t % B / 32) ∧ (t - t % B % 32) / B = t / B := by
  have ht := Nat.div_add_mod t B
  have hr := Nat.mod_lt t hB
  have e : t - t % B % 32 = B * (t / B) + 32 * (t % B / 32) := by omega
  refine ⟨e, ?_, ?_⟩
  · rw [e, Nat.mul_add_mod, Nat.mod_eq_of_lt (show 32 * (t % B / 32) < B by omega)]
  · rw [e, Nat.mul_add_div hB, Nat.div_eq_of_lt (show 32 * (t % B / 32) < B by omega),
      Nat.add_zero]

/-- On a launch with side 1 in `y` and `z`, the warp of thread `t` (its first thread
`Launch.groupNum L 1 t`) has `tid.x` `32 (t % B / 32)` and `ctaid.x` `t / B`, with `B` the block's
`x` side, for every thread below the thread count. -/
theorem warp_regs {L : Launch} (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {t : Nat} (ht : t < volume L.grid * volume L.block) :
    (L.env (L.groupNum 1 t)).sreg .tid .x = 32 * (t % L.block .x / 32) ∧
      (L.env (L.groupNum 1 t)).sreg .ctaid .x = t / L.block .x := by
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hG : volume L.grid = L.grid .x := by simp [volume, hg.1, hg.2]
  have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
  obtain ⟨-, hm, hq⟩ := warp_base (t := t) hB
  show coord L.block ((t - t % volume L.block % 32) % volume L.block) .x = _ ∧
    coord L.grid ((t - t % volume L.block % 32) / volume L.block) .x = _
  simp only [coord, hv, hm, hq]
  refine ⟨Nat.mod_eq_of_lt (by have := Nat.mod_lt t hB; omega), Nat.mod_eq_of_lt ?_⟩
  rw [hv, hG, Nat.mul_comm] at ht
  exact Nat.div_lt_of_lt_mul ht

/-- `bind` sets variable 0 to the `tid.x` of the warp's first thread and variable 1 to its
`ctaid.x`, as `sig`'s special registers give them (`Launch.env`). -/
def gemvBind (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) : Sizes :=
  fun x => if x = 0 then (L.env g.2).sreg .tid .x
    else if x = 1 then (L.env g.2).sreg .ctaid .x else σ x

/-- gemv's output vector at the warp level (level 1) of `sig`, in buffer `y`: the layout of one
4-byte float, the key `warpIdx 0 1`, and the warps whose key (their row) is below `m`, the
variable 7, owning a tile. Its offsets are a natural-number model of the kernel's: the kernel's
guard compares the row with the sign extension of `m`'s 32-bit word, which is `m` under the word
premise `m < 2 ^ 31` (MojoProofTest/GPUProof/ViewWords.lean's `gemv_words`). -/
def gemvView (y : Nat) : View sig where
  lay _ := elem 4
  level := (1 : Fin 4)
  buf := y
  key := warpIdx 0 1
  bind := gemvBind
  owns L g σ := (warpIdx 0 1).val (gemvBind L g σ) < σ 7

/-- The admissible assignments and launches of gemv's view: a launch with side 1 in `y` and `z`,
where the variables 4, 5, 6 are `ntid.x`, the warp width 32 and `nctaid.x`, and 32 divides
`ntid.x`. They give `WF`, the tilings and the covers; they do not bound `m`, so the word
premise `m < 2 ^ 31` is a premise of the theorems on the kernel's words alone (`gemv_words`,
`gemv_gep`), and `gemvAdm` holds at `m = 2 ^ 31`, where the kernel skips a store its view owns
(`gemv_wrap`). -/
def gemvAdm (σ : Sizes) (L : Launch) : Prop :=
  (L.grid .y = 1 ∧ L.grid .z = 1) ∧ (L.block .y = 1 ∧ L.block .z = 1) ∧
    σ 4 = L.block .x ∧ σ 5 = 32 ∧ σ 6 = L.grid .x ∧ 32 ∣ L.block .x

/-- **The key at a thread's warp is the thread's row.** At MojoProof's `sig`, at every admissible
assignment and launch, and every thread `t` below the thread count: the key's value at `t`'s warp
is `(ctaid.x · ntid.x + tid.x) / 32` of `t` (`Launch.index`), the row that gemv's IR computes
(tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll:13-21)
for every thread of the warp. -/
theorem gemv_row {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) :
    (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) = L.index t .x / 32 := by
  obtain ⟨hg, hb, h4, h5, -, hd⟩ := ha
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hf : L.groupNum 1 t < volume L.grid * volume L.block := by
    rw [groupNum_one]; omega
  rw [← gemv_val (gemvBind L (sig.group L 1 t) σ) 0 1 (show σ 5 ∣ σ 4 by rw [h4, h5]; exact hd)]
  show ((L.env (L.groupNum 1 t)).sreg .ctaid .x * σ 4 +
    (L.env (L.groupNum 1 t)).sreg .tid .x) / σ 5 = _
  rw [h4, h5, show L.block .x = (L.env (L.groupNum 1 t)).sreg .ntid .x from rfl,
    Launch.index_oneDim hg hb hf, Launch.index, Launch.index_oneDim hg hb ht, groupNum_one, hv,
    Nat.mod_mod_of_dvd t hd]
  omega

/-- gemv's key's radices, `σ 4 / σ 5` and `σ 6`, read no variable that `gemvBind` sets, for
every launch, instance and size assignment. -/
theorem gemv_radices (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) :
    (warpIdx 0 1).digits.map (fun p => p.2.eval (gemvBind L g σ)) =
      (warpIdx 0 1).digits.map (fun p => p.2.eval σ) := by
  simp [warpIdx, gemvBind, SizeExpr.eval]

/-- **gemv's warp view is well formed at MojoProof's `sig`, at every admissible assignment and
launch.** -/
theorem gemv_wf (y : Nat) (σ : Sizes) (L : Launch) (ha : gemvAdm σ L) : (gemvView y).WF σ L where
  congruent := elem_congruent 4
  pos := elem_pos (by decide)
  range g hg := by
    obtain ⟨hg1, hb, h4, h5, h6, hd⟩ := ha
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨e0, e1⟩ := warp_regs hg1 hb ht
    have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
    have hG : volume L.grid = L.grid .x := by simp [volume, hg1.1, hg1.2]
    have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
    refine inRange_warpIdx (σ := gemvBind L (1, L.groupNum 1 t) σ) ?_ ?_ ?_
    · show σ 5 ∣ σ 4
      rw [h4, h5]; exact hd
    · show (L.env (L.groupNum 1 t)).sreg .tid .x < σ 4
      rw [e0, h4]
      have := Nat.mod_lt t hB
      omega
    · show (L.env (L.groupNum 1 t)).sreg .ctaid .x < σ 6
      rw [e1, h6]
      rw [hv, hG, Nat.mul_comm] at ht
      exact Nat.div_lt_of_lt_mul ht
  radices g _ := gemv_radices L g σ
  key_inj g g' hg hg' he := by
    obtain ⟨hg1, hb, -, h5, -, -⟩ := ha
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
    obtain ⟨e0, e1⟩ := warp_regs hg1 hb ht
    obtain ⟨e0', e1'⟩ := warp_regs hg1 hb ht'
    have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
    have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
    change [(L.env (L.groupNum 1 t)).sreg .tid .x / σ 5, (L.env (L.groupNum 1 t)).sreg .ctaid .x] =
      [(L.env (L.groupNum 1 t')).sreg .tid .x / σ 5, (L.env (L.groupNum 1 t')).sreg .ctaid .x]
      at he
    rw [e0, e1, e0', e1', h5] at he
    simp only [List.cons.injEq, and_true] at he
    show ((1 : Fin 4), L.groupNum 1 t) = (1, L.groupNum 1 t')
    rw [groupNum_one, groupNum_one, hv, (warp_base hB).1, (warp_base hB).1, he.2,
      show t % L.block .x / 32 = t' % L.block .x / 32 by omega]

/-- **gemv's warp tile is the bytes of its row's float**, a natural-number model. At MojoProof's
`sig`, at every admissible assignment and launch, and every thread `t` below the thread count,
with `row` the thread's `(ctaid.x · ntid.x + tid.x) / 32`: the tile of `t`'s warp is bytes
`4 · row` to `4 · row + 3` of `y` when `row` is below `m` (the variable 7), and no byte
otherwise. The kernel's guard and `getelementptr` give these bytes under the word premise
`m < 2 ^ 31` (`gemv_words`, `gemv_gep`); that a run stores there is not proved here. -/
theorem gemv_tile (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) (x : Nat × Int) :
    x ∈ (gemvView y).tile σ L (sig.group L 1 t) ↔
      L.index t .x / 32 < σ 7 ∧ ∃ c < 4, x = sig.place y ↑(4 * (L.index t .x / 32) + c) := by
  have hr := gemv_row ha ht
  simp only [View.tile, View.off, gemvView, Set.mem_ofPred_eq, elem_size,
    elem_cosize (show 0 < 4 by decide), elem_call, hr, Nat.mul_comm _ 4]

/-- An admissible assignment exists: gemv's launch of 4 blocks of 128 threads, at `m = 500`. -/
example : gemvAdm (asg [0, 0, 0, 0, 128, 32, 4, 500]) (launch2 4 1 128 1) :=
  ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩

/-- At grid (4,1,1) and block (128,1,1), thread 200 (block 1, `tid.x` 72) is in row 6, whose
float is bytes 24 to 27 of `y`. -/
example : (launch2 4 1 128 1).index 200 .x / 32 = 6 := by decide

/-! ### Mutants of gemv's view -/

/-- The binding by the flattened thread number: variable 0 the warp's first thread's offset in
its block and variable 1 its block, which name the warp at every launch but are not its row. -/
def flatBind (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) : Sizes :=
  fun x => if x = 0 then g.2 % volume L.block else if x = 1 then g.2 / volume L.block else σ x

/-- **Mutant: two blocks in `y`.** At grid (1,2,1) and block (32,1,1), with `ntid = 32`, the
warp width 32, 2 blocks and `m = 1`: `gemvAdm` refuses the launch; the warps of threads 0 and 32
are two instances of the warp level, both in row 0 (`Launch.index` in `x` over 32); the flattened
binding gives them the keys 0 and 1, two tiles where the kernel, whose row reads no `y` register
(tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll:13-21),
stores one float twice (:136); and gemv's view is not well formed there, as the two warps have
one key. -/
theorem gemv_gridY (y : Nat) :
    ¬ gemvAdm (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1) ∧
      (launch2 1 2 32 1).index 0 .x / 32 = 0 ∧ (launch2 1 2 32 1).index 32 .x / 32 = 0 ∧
      sig.group (launch2 1 2 32 1) 1 0 ≠ sig.group (launch2 1 2 32 1) 1 32 ∧
      (warpIdx 0 1).val (flatBind (launch2 1 2 32 1) (1, 0) (asg [0, 0, 0, 0, 32, 32, 2, 1])) = 0 ∧
      (warpIdx 0 1).val (flatBind (launch2 1 2 32 1) (1, 32) (asg [0, 0, 0, 0, 32, 32, 2, 1])) =
        1 ∧
      ¬ (gemvView y).WF (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1) := by
  refine ⟨fun h => absurd h.1.1 (by decide), by decide, by decide, by decide, by decide,
    by decide, fun h => ?_⟩
  have h0 : (gemvView y).Owner (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1) (1, 0) :=
    ⟨inst_sig.2 ⟨0, by decide, rfl⟩, (by decide : (warpIdx 0 1).val
      (gemvBind (launch2 1 2 32 1) (1, 0) (asg [0, 0, 0, 0, 32, 32, 2, 1])) < 1)⟩
  have h1 : (gemvView y).Owner (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1) (1, 32) :=
    ⟨inst_sig.2 ⟨32, by decide, rfl⟩, (by decide : (warpIdx 0 1).val
      (gemvBind (launch2 1 2 32 1) (1, 32) (asg [0, 0, 0, 0, 32, 32, 2, 1])) < 1)⟩
  exact absurd (h.key_inj _ _ h0 h1 (by decide :
    (warpIdx 0 1).digitVals (gemvBind (launch2 1 2 32 1) (1, 0) (asg [0, 0, 0, 0, 32, 32, 2, 1])) =
      (warpIdx 0 1).digitVals
        (gemvBind (launch2 1 2 32 1) (1, 32) (asg [0, 0, 0, 0, 32, 32, 2, 1])))) (by decide)

/-- **Mutant: the warp radix 0.** At `m = 1` (variable 7), every other variable 0, and the launch
of one thread, the guard fails, and so does `WF`: warp `(1, 0)` owns row 0, and its warp digit
and radix are both 0, so `range` fails there. -/
theorem gemv_zero (y : Nat) :
    ¬ gemvAdm (asg [0, 0, 0, 0, 0, 0, 0, 1]) Launch.one ∧
      ¬ (gemvView y).WF (asg [0, 0, 0, 0, 0, 0, 0, 1]) Launch.one := by
  refine ⟨fun h => absurd h.2.2.2.1 (by decide), fun h => ?_⟩
  have hi : (gemvView y).Owner (asg [0, 0, 0, 0, 0, 0, 0, 1]) Launch.one (1, 0) :=
    ⟨inst_sig.2 ⟨0, by decide, rfl⟩,
      (by decide :
        (warpIdx 0 1).val (gemvBind Launch.one (1, 0) (asg [0, 0, 0, 0, 0, 0, 0, 1])) < 1)⟩
  exact absurd (h.range (1, 0) hi)
    (by decide :
      ¬ (warpIdx 0 1).InRange (gemvBind Launch.one (1, 0) (asg [0, 0, 0, 0, 0, 0, 0, 1])))

/-- So the design's `WF` at every assignment and launch fails for gemv's view. -/
theorem gemv_old (y : Nat) : ¬ ∀ σ L, (gemvView y).WF σ L := fun h => (gemv_zero y).2 (h _ _)

/-! ## The naive matmul: the thread view on `sig`, `row * n + col` at symbolic `n` -/

/-- `bind` sets variable 0 to the thread's row (`Launch.index` in `x`) and variable 1 to its
column (in `y`). -/
def naiveBind (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) : Sizes :=
  fun x => if x = 0 then L.index g.2 .x else if x = 1 then L.index g.2 .y else σ x

/-- The naive matmul's output at the thread level (level 0) of `sig`, in buffer `c`: the layout of
one 4-byte float, the key `entryIdx 0 1` (the column with radix `n`, variable 5, then the row with
radix `m`, variable 4), and the threads whose row is below `m` and column below `n` owning a
tile. Its offsets are a natural-number model of the kernel's 32-bit index words, which are the
key value under the word premise `m · n < 2 ^ 31`, the key's radix product
(MojoProofTest/GPUProof/ViewWords.lean's `naive_words`). -/
def naiveView (c : Nat) : View sig where
  lay _ := elem 4
  level := (0 : Fin 4)
  buf := c
  key := entryIdx 0 1
  bind := naiveBind
  owns L g σ := L.index g.2 .x < σ 4 ∧ L.index g.2 .y < σ 5

/-- The key's value at a thread is `row * n + col` (`n` the variable 5), at every launch,
instance and assignment. -/
theorem naive_val (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) :
    (entryIdx 0 1).val (naiveBind L g σ) = L.index g.2 .x * σ 5 + L.index g.2 .y := by
  simp [entryIdx, MixedRadix.val, naiveBind, SizeExpr.eval]
  rw [Nat.add_comm, Nat.mul_comm]

/-- The admissible assignments and launches of the naive kernel whose row stride is the constant
`N`: the column count `n` (the variable 5, the column guard's bound) is `N`, and the launch is
valid with side 1 in `z`. The family's kernels differ by `N`: the corpus kernel
tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll has
`N = 50257` (:28), and ..._51a464b3.nvptx.ll and ..._7f042754.nvptx.ll in the same folder have
257 and 17 (:28). It gives `WF`, the tiling and the cover and does not bound `m`, so the word
premise `m · N < 2 ^ 31` is a premise of the theorems on the kernel's words alone
(`naive_words`, `naive_guards`, `naive_gep`); `naiveAdm 50257` holds at `m = 2 ^ 20 + 1`, where
the kernel's index word wraps (`naive_wrap`). -/
def naiveAdm (N : Nat) (σ : Sizes) (L : Launch) : Prop :=
  σ 5 = N ∧ L.Valid ∧ (L.grid .z = 1 ∧ L.block .z = 1)

/-- **The naive matmul's view is well formed at MojoProof's `sig`, at every admissible assignment
and launch** of the kernel of row stride `N`, at symbolic `m`. -/
theorem naive_wf (c N : Nat) (σ : Sizes) (L : Launch) (ha : naiveAdm N σ L) :
    (naiveView c).WF σ L where
  congruent := elem_congruent 4
  pos := elem_pos (by decide)
  range g hg := by
    obtain ⟨-, hr, hk⟩ := hg
    intro p hp
    simp only [naiveView, entryIdx, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · exact hk
    · exact hr
  radices g _ := by simp [naiveView, entryIdx, naiveBind, SizeExpr.eval]
  key_inj g g' hg hg' he := by
    obtain ⟨-, hL, hz⟩ := ha
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
    simp [naiveView, MixedRadix.digitVals, entryIdx, naiveBind, SizeExpr.eval] at he
    have := Launch.xy_inj hL hz ht ht' (congrArg _ he.2) (congrArg _ he.1)
    subst this
    rfl

/-- **The naive thread's tile is the bytes of its output float**, a natural-number model. At
MojoProof's `sig`, at every assignment with `n = N` (the variable 5, the kernel's row stride),
every launch and every thread `t`, with `row` and `col` the thread's `Launch.index` in `x` and
`y`: the tile of `t` is bytes `4 · (row · N + col)` to `4 · (row · N + col) + 3` of `c` when
`row < m` and `col < N` (the variable 4 and the column guard's bound), and no byte otherwise.
The kernel's address words (:39-41) give these bytes under the word premise `m · N < 2 ^ 31`
(`naive_words`, `naive_gep`); without it they wrap (`naive_wrap`), and that a run stores there is
not proved here. -/
theorem naive_tile (c N : Nat) {σ : Sizes} {L : Launch} (hN : σ 5 = N) (t : Nat)
    (x : Nat × Int) :
    x ∈ (naiveView c).tile σ L (sig.group L 0 t) ↔
      (L.index t .x < σ 4 ∧ L.index t .y < N) ∧
        ∃ b < 4, x = sig.place c ↑(4 * (L.index t .x * N + L.index t .y) + b) := by
  rw [← hN]
  simp only [View.tile, View.off, naiveView, Set.mem_ofPred_eq, elem_size,
    elem_cosize (show 0 < 4 by decide), elem_call, naive_val, Nat.mul_comm _ 4]
  rfl

/-- An admissible assignment and launch of the corpus kernel (`N = 50257`): `m = 2`, `n = 50257`
and one block of 2 × 2 threads. -/
example : naiveAdm 50257 (asg [0, 0, 0, 0, 2, 50257]) (launch2 1 1 2 2) :=
  ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩

/-! ### Mutants of the naive view -/

/-- The naive view without the guard on instances: every thread owns a tile. -/
def naiveAll (c : Nat) : View sig := { naiveView c with owns := fun _ _ _ => True }

/-- **Mutant: the assignment `0`.** At `m = n = 0` and the launch of one thread, the naive view is
well formed (thread 0 owns no tile), and the view without the guard is not (`range` fails at
thread 0: the column's radix is 0). -/
theorem naive_zero (c : Nat) :
    (naiveView c).WF (fun _ => 0) Launch.one ∧ ¬ (naiveAll c).WF (fun _ => 0) Launch.one := by
  refine ⟨naive_wf c 0 _ _ ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩, fun h => ?_⟩
  have hi : (naiveAll c).Owner (fun _ => 0) Launch.one (0, 0) :=
    ⟨inst_sig.2 ⟨0, by decide, rfl⟩, trivial⟩
  exact absurd (h.range (0, 0) hi)
    (by decide : ¬ (entryIdx 0 1).InRange (naiveBind Launch.one (0, 0) fun _ => 0))

/-- **Mutant: an overshooting launch at the matrix's sizes.** At `m = n = 1` (variables 4, 5)
and one block of 2 × 1 threads, a launch that covers the rows as `MatSetup.Fits` admits
(`m ≤ grid.x · block.x`): the view is well formed, thread 1 (row 1) covers no byte, and the view
without the guard is not well formed (thread 1's row is not below `m`). -/
theorem naive_overshoot (c : Nat) :
    (naiveView c).WF (asg [0, 0, 0, 0, 1, 1]) (launch2 1 1 2 1) ∧
      (naiveView c).tile (asg [0, 0, 0, 0, 1, 1]) (launch2 1 1 2 1)
        (sig.group (launch2 1 1 2 1) 0 1) = ∅ ∧
      ¬ (naiveAll c).WF (asg [0, 0, 0, 0, 1, 1]) (launch2 1 1 2 1) := by
  refine ⟨naive_wf c 1 _ _ ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩, ?_, fun h => ?_⟩
  · ext x
    rw [naive_tile c 1 rfl]
    simp only [Set.mem_empty_iff_false, iff_false]
    exact fun h => absurd h.1.1
      (by decide : ¬ (launch2 1 1 2 1).index 1 .x < asg [0, 0, 0, 0, 1, 1] 4)
  · have hi : (naiveAll c).Owner (asg [0, 0, 0, 0, 1, 1]) (launch2 1 1 2 1) (0, 1) :=
      ⟨inst_sig.2 ⟨1, by decide, rfl⟩, trivial⟩
    exact absurd (h.range (0, 1) hi)
      (by decide :
        ¬ (entryIdx 0 1).InRange (naiveBind (launch2 1 1 2 1) (0, 1) (asg [0, 0, 0, 0, 1, 1])))

/-- **Mutant: two threads in `z`.** At `m = n = 1` and one block of 1 × 1 × 2 threads (`L112`,
the launch of MojoProofTest/Index.lean's twin), threads 0 and 1 are two instances at row 0 and
column 0, both owners, so `WF` fails (`key_inj`): `naiveAdm`'s side 1 in `z` is needed. -/
theorem naive_z (c : Nat) : ¬ (naiveView c).WF (asg [0, 0, 0, 0, 1, 1]) L112 := by
  intro h
  have h0 : (naiveView c).Owner (asg [0, 0, 0, 0, 1, 1]) L112 (0, 0) :=
    ⟨inst_sig.2 ⟨0, by decide, rfl⟩,
      (by decide : L112.index 0 .x < 1 ∧ L112.index 0 .y < 1)⟩
  have h1 : (naiveView c).Owner (asg [0, 0, 0, 0, 1, 1]) L112 (0, 1) :=
    ⟨inst_sig.2 ⟨1, by decide, rfl⟩,
      (by decide : L112.index 1 .x < 1 ∧ L112.index 1 .y < 1)⟩
  exact absurd (h.key_inj _ _ h0 h1 (by decide :
    (entryIdx 0 1).digitVals (naiveBind L112 (0, 0) (asg [0, 0, 0, 0, 1, 1])) =
      (entryIdx 0 1).digitVals (naiveBind L112 (0, 1) (asg [0, 0, 0, 0, 1, 1])))) (by decide)

/-! ## Tilings: the owners' tiles are disjoint and inside the view's bytes -/

/-- `sig`'s placement is injective: byte `i` of buffer `b` is the pair `(b, i)`. -/
theorem place_inj : PlaceInj sig.place := fun h => Prod.mk.inj h

/-- A byte is in gemv's tile of instance `g` when `g`'s key is below `m` (the variable 7) and the
byte is one of bytes `4 · key` to `4 · key + 3` of `y`, at every assignment, launch and
instance. -/
theorem gemv_mem (y : Nat) (σ : Sizes) (L : Launch) (g : Fin 4 × Nat) (x : Nat × Int) :
    x ∈ (gemvView y).tile σ L g ↔
      (warpIdx 0 1).val (gemvBind L g σ) < σ 7 ∧
        ∃ c < 4, x = sig.place y ↑(4 * (warpIdx 0 1).val (gemvBind L g σ) + c) := by
  simp only [View.tile, View.off, gemvView, Set.mem_ofPred_eq, elem_size,
    elem_cosize (show 0 < 4 by decide), elem_call, Nat.mul_comm _ 4]

/-- **gemv's warp tiles are a tiling of its bytes.** At MojoProof's `sig`, at every admissible
assignment and launch, every warp's tile is in the view's bytes and the tiles of two warps are
disjoint (`View.tiling` at `place_inj` and `gemv_wf`). -/
theorem gemv_tiling (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) :
    Tiling ((gemvView y).tiles σ L) ((gemvView y).bytes σ) :=
  View.tiling _ place_inj (gemv_wf y σ L ha)

/-- gemv's tiling at grid (4,1,1) and block (128,1,1), at `m = 500`: 16 warps, all owners. -/
example (y : Nat) :
    Tiling ((gemvView y).tiles (asg [0, 0, 0, 0, 128, 32, 4, 500]) (launch2 4 1 128 1))
      ((gemvView y).bytes (asg [0, 0, 0, 0, 128, 32, 4, 500])) :=
  gemv_tiling y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩

/-- gemv's tiling at grid (7,1,1) and block (96,1,1), at `m = 20`: 21 warps, the last one (row
20) owning no tile. -/
example (y : Nat) :
    Tiling ((gemvView y).tiles (asg [0, 0, 0, 0, 96, 32, 7, 20]) (launch2 7 1 96 1))
      ((gemvView y).bytes (asg [0, 0, 0, 0, 96, 32, 7, 20])) :=
  gemv_tiling y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩

/-- **Mutant: overlapping tiles.** At grid (1,2,1) and block (32,1,1), with `ntid = 32`, the
warp width 32, 2 blocks and `m = 1` (the launch `gemvAdm` refuses, `gemv_gridY`), the warps of
threads 0 and 32 are two instances with the key 0, and both tiles hold byte 0 of `y`: gemv's
warp tiles are not a tiling there. -/
theorem gemv_overlap (y : Nat) :
    ¬ Tiling ((gemvView y).tiles (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1))
      ((gemvView y).bytes (asg [0, 0, 0, 0, 32, 32, 2, 1])) := by
  rintro ⟨-, hd⟩
  have h0 : sig.Inst (launch2 1 2 32 1) (1 : Fin 4) (1, 0) := inst_sig.2 ⟨0, by decide, rfl⟩
  have h1 : sig.Inst (launch2 1 2 32 1) (1 : Fin 4) (1, 32) := inst_sig.2 ⟨32, by decide, rfl⟩
  have hne : (⟨(1, 0), h0⟩ : {g // sig.Inst (launch2 1 2 32 1) (gemvView y).level g}) ≠
      ⟨(1, 32), h1⟩ :=
    fun h => absurd (congrArg Subtype.val h) (by decide : ((1 : Fin 4), 0) ≠ (1, 32))
  have hm : ∀ g, (warpIdx 0 1).val
      (gemvBind (launch2 1 2 32 1) g (asg [0, 0, 0, 0, 32, 32, 2, 1])) = 0 →
      sig.place y 0 ∈ (gemvView y).tile (asg [0, 0, 0, 0, 32, 32, 2, 1]) (launch2 1 2 32 1) g :=
    fun g h => (gemv_mem y _ _ g _).2 ⟨by rw [h]; decide, 0, by decide, by rw [h]; rfl⟩
  exact Set.disjoint_left.1 (hd hne) (hm (1, 0) (by decide)) (hm (1, 32) (by decide))

/-- **The naive matmul's thread tiles are a tiling of its bytes.** At MojoProof's `sig`, at every
assignment and admissible launch (`View.tiling` at `place_inj` and `naive_wf`). -/
theorem naive_tiling (c N : Nat) {σ : Sizes} {L : Launch} (ha : naiveAdm N σ L) :
    Tiling ((naiveView c).tiles σ L) ((naiveView c).bytes σ) :=
  View.tiling _ place_inj (naive_wf c N σ L ha)

/-- The naive matmul's tiling at grid (1,1,1) and block (2,2,1), at `m = n = 2`. -/
example (c : Nat) :
    Tiling ((naiveView c).tiles (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 2))
      ((naiveView c).bytes (asg [0, 0, 0, 0, 2, 2])) :=
  naive_tiling c 2 ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩

/-- The naive matmul's tiling at grid (3,2,1) and block (4,8,1), at `m = 10` and `n = 15`: 12
rows and 16 columns of threads, rows 10 and 11 and column 15 owning no tile. -/
example (c : Nat) :
    Tiling ((naiveView c).tiles (asg [0, 0, 0, 0, 10, 15]) (launch2 3 2 4 8))
      ((naiveView c).bytes (asg [0, 0, 0, 0, 10, 15])) :=
  naive_tiling c 15 ⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩

/-- **Mutant: a column count other than the corpus kernel's row stride.** At `m = n = 2` and one
block of 2 × 2 threads, the assignment is not admissible for the corpus kernel (`N = 50257`), and
the corpus kernel's store of thread 1 (row 1, column 0), at byte `4 · (1 · 50257 + 0)` of `c`
(:39-41) in the model (`2 · 50257 < 2 ^ 31`, so its words do not wrap), is not in thread 1's
tile, bytes 8 to 11 (`naive_tile` at `N = 2`): the view at `n = 2` is the kernel's of row
stride 2, not the corpus kernel's. -/
theorem naive_stride (c : Nat) :
    ¬ naiveAdm 50257 (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 2) ∧
      sig.place c ↑(4 * ((launch2 1 1 2 2).index 1 .x * 50257 + (launch2 1 1 2 2).index 1 .y)) ∉
        (naiveView c).tile (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 2)
          (sig.group (launch2 1 1 2 2) 0 1) := by
  refine ⟨fun h => absurd h.1 (by decide), fun hx => ?_⟩
  obtain ⟨-, b, hb, he⟩ :=
    (naive_tile c 2 rfl 1 _).1 hx
  have h' := (place_inj he).2
  rw [show (launch2 1 1 2 2).index 1 .x = 1 by decide,
    show (launch2 1 1 2 2).index 1 .y = 0 by decide] at h'
  omega

/-! ## Coverage: the owners' tiles cover the bytes of the owners' key values -/

/-- **gemv's warp tiles cover `y`'s `m` floats.** At MojoProof's `sig`, at every admissible
assignment and launch with at least `m` warps (`m ≤ (ntid.x / 32) · nctaid.x`, `m` the variable
7), each of the first `4 m` bytes of `y` is in a warp's tile (`View.cover` at `B = m`): `elem 4`
is onto its 4 bytes (`elem_onto`), and row `k < m` is the key of the warp of thread `32 k`
(`gemv_row`). -/
theorem gemv_cover (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L)
    (hm : σ 7 ≤ L.block .x / 32 * L.grid .x) :
    {x | ∃ i : Nat, i < σ 7 * 4 ∧ x = sig.place y i} ⊆ ⋃ g, (gemvView y).tiles σ L g := by
  have ⟨hg, hb, _, _, _, hd⟩ := ha
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hG : volume L.grid = L.grid .x := by simp [volume, hg.1, hg.2]
  have hk : ∀ k < σ 7, ∃ g, (gemvView y).Owner σ L g ∧
      (gemvView y).key.val ((gemvView y).bind L g σ) = k := by
    intro k hk
    have ht : 32 * k < volume L.grid * volume L.block := by
      have e : L.block .x / 32 * L.grid .x * 32 = L.grid .x * L.block .x := by
        rw [Nat.mul_right_comm, Nat.div_mul_cancel hd, Nat.mul_comm]
      have := Nat.mul_le_mul_right 32 hm
      rw [hG, hv]
      omega
    have hr := gemv_row ha ht
    rw [show L.index (32 * k) .x = 32 * k from Launch.index_oneDim hg hb ht,
      Nat.mul_div_cancel_left k (by decide)] at hr
    refine ⟨sig.group L 1 (32 * k), ⟨inst_sig.2 ⟨32 * k, ht, rfl⟩, ?_⟩, hr⟩
    show (warpIdx 0 1).val (gemvBind L (sig.group L 1 (32 * k)) σ) < σ 7
    rw [hr]
    exact hk
  have h := View.cover (gemvView y) (B := σ 7) (elem_onto (w := 4) (by decide)) hk
  rwa [show ((gemvView y).lay σ).cosize = 4 from elem_cosize (by decide)] at h

/-- gemv's cover at grid (4,1,1) and block (128,1,1), at `m = 16`: 16 warps, one per row. -/
example (y : Nat) :
    {x | ∃ i : Nat, i < asg [0, 0, 0, 0, 128, 32, 4, 16] 7 * 4 ∧ x = sig.place y i} ⊆
      ⋃ g, (gemvView y).tiles (asg [0, 0, 0, 0, 128, 32, 4, 16]) (launch2 4 1 128 1) g :=
  gemv_cover y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ (by decide)

/-- gemv's cover at grid (7,1,1) and block (96,1,1), at `m = 20`: 21 warps, the first 80 bytes
of `y` covered. -/
example (y : Nat) :
    {x | ∃ i : Nat, i < asg [0, 0, 0, 0, 96, 32, 7, 20] 7 * 4 ∧ x = sig.place y i} ⊆
      ⋃ g, (gemvView y).tiles (asg [0, 0, 0, 0, 96, 32, 7, 20]) (launch2 7 1 96 1) g :=
  gemv_cover y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ (by decide)

/-- **Mutant: more warps than rows.** At MojoProof's `sig`, at every admissible assignment and
launch, each byte `i` of `y` from `4 m` up and below 4 times the warp count
`(ntid.x / 32) · nctaid.x` is in gemv's bytes and in no warp's tile, as a warp owns a tile only
at a row below `m` (`gemv_mem`): with more warps than rows, the tiles do not cover `bytes`, and
`gemv_cover`'s bound is `m`. -/
theorem gemv_uncovered (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) {i : Nat}
    (hi : 4 * σ 7 ≤ i) (hw : i < 4 * (L.block .x / 32 * L.grid .x)) :
    sig.place y i ∈ (gemvView y).bytes σ ∧ sig.place y i ∉ ⋃ g, (gemvView y).tiles σ L g := by
  obtain ⟨-, -, h4, h5, h6, -⟩ := ha
  refine ⟨⟨i, ?_, rfl⟩, fun hx => ?_⟩
  · have hR : (gemvView y).key.radixProd σ = σ 4 / σ 5 * σ 6 := by
      simp [gemvView, warpIdx, MixedRadix.radixProd, SizeExpr.eval]
    show i < (gemvView y).key.radixProd σ * (elem 4).cosize
    rw [hR, elem_cosize (by decide), h4, h5, h6]
    omega
  · obtain ⟨g, hg⟩ := Set.mem_iUnion.1 hx
    obtain ⟨hk, c, hc, he⟩ := (gemv_mem y σ L g.1 _).1 hg
    have h' := (place_inj he).2
    omega

/-- At grid (7,1,1) and block (96,1,1), at `m = 20`, 21 warps: byte 80 of `y`, row 20's first,
is in gemv's bytes and in no warp's tile. -/
example (y : Nat) :
    sig.place y 80 ∈ (gemvView y).bytes (asg [0, 0, 0, 0, 96, 32, 7, 20]) ∧
      sig.place y 80 ∉
        ⋃ g, (gemvView y).tiles (asg [0, 0, 0, 0, 96, 32, 7, 20]) (launch2 7 1 96 1) g :=
  gemv_uncovered y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ (by decide) (by decide)

/-- **The naive matmul's thread tiles cover its bytes.** At MojoProof's `sig`, for the kernel of
every row stride `N`, at every assignment with `n = N` (`hN`) and every valid launch (`hL`) whose
rows and columns of threads reach `m` and `N` (`m ≤ nctaid.x · ntid.x`, `N ≤ nctaid.y · ntid.y`),
each of the view's bytes, the `m · N` floats of `c`, is in a thread's tile (`View.cover` at `B`
the radix product): `elem 4` is onto its 4 bytes, and the key value `k < m · N` is the key of the
thread at row `k / N` and column `k % N` (`Launch.cell_onto`). The side 1 in `z` of `naiveAdm`
is not a premise: the cover holds at `L112` (side 2 in `z`), where the view is not well formed
(`naive_z`). -/
theorem naive_cover (c N : Nat) {σ : Sizes} {L : Launch} (hN : σ 5 = N) (hL : L.Valid)
    (hm : σ 4 ≤ L.grid .x * L.block .x) (hn : N ≤ L.grid .y * L.block .y) :
    (naiveView c).bytes σ ⊆ ⋃ g, (naiveView c).tiles σ L g :=
  View.cover (naiveView c) (B := (naiveView c).key.radixProd σ) (elem_onto (w := 4) (by decide))
    fun k hk => by
      have hR : (naiveView c).key.radixProd σ = σ 5 * σ 4 := by
        simp [naiveView, entryIdx, MixedRadix.radixProd, SizeExpr.eval]
      rw [hR] at hk
      have h5 : 0 < σ 5 := Nat.pos_of_ne_zero fun h => by simp [h] at hk
      have hr : k / σ 5 < σ 4 := (Nat.div_lt_iff_lt_mul h5).2 (by rwa [Nat.mul_comm] at hk)
      have hc : k % σ 5 < σ 5 := Nat.mod_lt _ h5
      obtain ⟨t, ht, ex, ey⟩ := Launch.cell_onto hL (Nat.lt_of_lt_of_le hr hm)
        (Nat.lt_of_lt_of_le hc (by rw [hN]; exact hn))
      refine ⟨sig.group L 0 t, ⟨inst_sig.2 ⟨t, ht, rfl⟩, ?_⟩, ?_⟩
      · show L.index t .x < σ 4 ∧ L.index t .y < σ 5
        rw [ex, ey]
        exact ⟨hr, hc⟩
      · show (entryIdx 0 1).val (naiveBind L (sig.group L 0 t) σ) = k
        rw [naive_val]
        show L.index t .x * σ 5 + L.index t .y = k
        rw [ex, ey, Nat.div_add_mod']

/-- The naive matmul's cover at grid (1,1,1) and block (2,2,1), at `m = n = 2`. -/
example (c : Nat) :
    (naiveView c).bytes (asg [0, 0, 0, 0, 2, 2]) ⊆
      ⋃ g, (naiveView c).tiles (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 2) g :=
  naive_cover c 2 rfl (launch2_valid (by decide)) (by decide) (by decide)

/-- The corpus kernel's cover (`N = 50257`) at grid (1,3142,1) and block (4,16,1), at `m = 4`:
50272 columns of threads, the last 15 owning no tile. -/
example (c : Nat) :
    (naiveView c).bytes (asg [0, 0, 0, 0, 4, 50257]) ⊆
      ⋃ g, (naiveView c).tiles (asg [0, 0, 0, 0, 4, 50257]) (launch2 1 3142 4 16) g :=
  naive_cover c 50257 rfl (launch2_valid (by decide)) (by decide) (by decide)

/-- The naive matmul's cover at grid (1,1,1) and block (1,1,2) (`L112`), at `m = n = 1`: the
launch is not admissible (side 2 in `z`) and the view is not well formed there (`naive_z`), and
the tiles still cover the view's bytes, the one float of `c`. -/
example (c : Nat) :
    ¬ naiveAdm 1 (asg [0, 0, 0, 0, 1, 1]) L112 ∧
      (naiveView c).bytes (asg [0, 0, 0, 0, 1, 1]) ⊆
        ⋃ g, (naiveView c).tiles (asg [0, 0, 0, 0, 1, 1]) L112 g :=
  ⟨fun h => absurd h.2.2.2 (by decide), naive_cover c 1 rfl MojoProofTest.Index.twin112.1
    (by decide) (by decide)⟩

/-! ### Mutant: a radix that reads a bound variable -/

/-- The binding that sets variable 0, the digit, to the thread's number and variable 1, the
radix, to 2. -/
def twoBind : Launch → Fin 4 × Nat → Sizes → Sizes :=
  fun _ g σ x => if x = 0 then g.2 else if x = 1 then 2 else σ x

/-- The key of one digit, variable 0, with the radix variable 1. -/
def boundKey : MixedRadix := ⟨[(.var 0, .var 1)]⟩

/-- A thread view (level 0) in buffer `b` with the layout of one 4-byte float, the key
`boundKey`, whose radix `twoBind` sets, and every thread owning a tile. -/
def boundView (b : Nat) : View sig where
  lay _ := elem 4
  level := (0 : Fin 4)
  buf := b
  key := boundKey
  bind := twoBind
  owns _ _ _ := True

/-- **Mutant: a radix that reads a bound variable.** At grid (1,1,1) and block (2,1,1), with the
radix variable assigned 1: at the binding of each thread the radix is 2, so the key is in range
(`range` holds) and tells the two threads apart (`key_inj` holds), but `radices` fails, as the
radix is 1 at the assignment, so the view is not well formed; and its tiles are not a tiling of
its bytes, bytes 0 to 3 of `b`, since thread 1's tile holds byte 4. -/
theorem bound_radix (b : Nat) :
    (∀ g, (boundView b).Owner (asg [0, 1]) (launch2 1 1 2 1) g →
      boundKey.InRange (twoBind (launch2 1 1 2 1) g (asg [0, 1]))) ∧
    (∀ g g', (boundView b).Owner (asg [0, 1]) (launch2 1 1 2 1) g →
      (boundView b).Owner (asg [0, 1]) (launch2 1 1 2 1) g' →
      boundKey.digitVals (twoBind (launch2 1 1 2 1) g (asg [0, 1])) =
        boundKey.digitVals (twoBind (launch2 1 1 2 1) g' (asg [0, 1])) → g = g') ∧
    ¬ (boundView b).WF (asg [0, 1]) (launch2 1 1 2 1) ∧
    ¬ Tiling ((boundView b).tiles (asg [0, 1]) (launch2 1 1 2 1))
      ((boundView b).bytes (asg [0, 1])) := by
  refine ⟨fun g hg => ?_, fun g g' hg hg' he => ?_, fun h => ?_, fun ⟨hs, _⟩ => ?_⟩
  · obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    change t < 2 at ht
    show boundKey.InRange (twoBind (launch2 1 1 2 1) (0, t) (asg [0, 1]))
    obtain _ | _ | t := t
    · decide
    · decide
    · omega
  · obtain ⟨t, -, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', -, rfl⟩ := inst_sig.1 hg'.1
    change [t] = [t'] at he
    rw [List.cons.inj he |>.1]
  · exact absurd (h.radices (0, 0) ⟨inst_sig.2 ⟨0, by decide, rfl⟩, trivial⟩) (by decide :
      boundKey.digits.map (fun p => p.2.eval (twoBind (launch2 1 1 2 1) (0, 0) (asg [0, 1]))) ≠
        boundKey.digits.map (fun p => p.2.eval (asg [0, 1])))
  · have hm : sig.place b 4 ∈ (boundView b).tile (asg [0, 1]) (launch2 1 1 2 1) (0, 1) := by
      refine ⟨trivial, 0, show 0 < (elem 4).size by rw [elem_size]; decide, ?_⟩
      show sig.place b 4 = sig.place b ↑(boundKey.val (twoBind (launch2 1 1 2 1) (0, 1)
        (asg [0, 1])) * (elem 4).cosize + (elem 4).call (leaf 0 false))
      rw [elem_cosize (by decide), elem_call]
      rfl
    obtain ⟨i, hi, he⟩ := hs ⟨(0, 1), inst_sig.2 ⟨1, by decide, rfl⟩⟩ hm
    change i < 1 * (elem 4).cosize at hi
    rw [elem_cosize (by decide)] at hi
    have h4 : (4 : Int) = (i : Int) := (place_inj he).2
    omega

/-! ## gemv coarsened at the block level -/

/-- The block binding: variable 1, the key's block digit, is the block instance's number; the
other variables are the assignment's. -/
def gemvBlock : Launch → Fin 4 × Nat → Sizes → Sizes :=
  fun _ i σ x => if x = 1 then i.2 else σ x

/-- gemv's key after its warp digit is the block digit, variable 1, at every assignment. -/
theorem gemv_outer (y : Nat) (τ : Sizes) : ((gemvView y).outer 1).val τ = τ 1 := by
  simp [View.outer, gemvView, warpIdx, MixedRadix.val, SizeExpr.eval]

/-- gemv's warp digit is variable 0 over variable 5, at every assignment. -/
theorem gemv_inner (y : Nat) (τ : Sizes) : ((gemvView y).inner 1).val τ = τ 0 / τ 5 := by
  simp [View.inner, gemvView, warpIdx, MixedRadix.val, SizeExpr.eval]

/-- The warp digit's radix is variable 4 over variable 5, at every assignment. -/
theorem gemv_innerProd (y : Nat) (σ : Sizes) :
    ((gemvView y).inner 1).radixProd σ = σ 4 / σ 5 := by
  simp [View.inner, gemvView, warpIdx, MixedRadix.radixProd, SizeExpr.eval]

/-- **gemv coarsened at the block level.** At MojoProof's `sig`, at every admissible assignment
and launch, and every block `b`: the view coarsened to the block level (level 2), with the warp
digit as one more layout mode and the block digit bound to the block's number (`gemvBlock`), has
at block `b` a tile that holds the tiles of the warps in it (`View.tile_subset_coarsen`), and,
when `b` is a block of the launch whose warps' rows are all below `m` (`(b + 1) · (ntid.x / 32)
≤ m`, the variable 7), the union of them (`View.coarsen_tile`). The warps in block `b` have the
block digit `b` (`hn`), and the warp of thread `b · ntid.x + 32 k` has the warp digit `k`, for
every `k` below the block's warp count `ntid.x / 32` (`ho`). At a last block that is partly
owned, the coarse tile holds more (`gemv_partial`). -/
theorem gemv_coarsen (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) (b : Nat) :
    ⋃ j ∈ {j | (gemvView y).Inside L 2 (2, b) j}, (gemvView y).tile σ L j ⊆
        ((gemvView y).coarsen 2 1 gemvBlock).tile σ L (2, b) ∧
      (b < L.grid .x → (b + 1) * (L.block .x / 32) ≤ σ 7 →
        ((gemvView y).coarsen 2 1 gemvBlock).tile σ L (2, b) =
          ⋃ j ∈ {j | (gemvView y).Inside L 2 (2, b) j}, (gemvView y).tile σ L j) := by
  have ha' := ha
  obtain ⟨hg, hbk, h4, h5, -, ⟨q, hq⟩⟩ := ha'
  have hv : volume L.block = L.block .x := by simp [volume, hbk.1, hbk.2]
  have hG : volume L.grid = L.grid .x := by simp [volume, hg.1, hg.2]
  have hn : ∀ j, (gemvView y).Inside L 2 (2, b) j → (gemvView y).owns L j σ →
      ((gemvView y).outer 1).val ((gemvView y).bind L j σ) =
        ((gemvView y).outer 1).val (gemvBlock L (2, b) σ) := by
    rintro j ⟨t, ht, rfl, hi⟩ -
    have ht' : t < volume L.grid * volume L.block := List.mem_range.1 ht
    have hi' : t / volume L.block = b := congrArg Prod.snd hi
    rw [gemv_outer, gemv_outer]
    show (L.env (L.groupNum 1 t)).sreg .ctaid .x = b
    rw [(warp_regs hg hbk ht').2, ← hv, hi']
  refine ⟨View.tile_subset_coarsen (gemvView y) (ℓ := 2) 1 gemvBlock (i := (2, b))
    (gemv_wf y σ L ha) hn, fun hb hm =>
      View.coarsen_tile (gemvView y) (ℓ := 2) 1 gemvBlock (i := (2, b)) (gemv_wf y σ L ha) hn ?_⟩
  intro k hk
  rw [gemv_innerProd, h4, h5] at hk
  have hB : 0 < L.block .x := by omega
  have ht : L.block .x * b + 32 * k < volume L.grid * volume L.block := by
    rw [hG, hv]
    calc L.block .x * b + 32 * k < L.block .x * b + L.block .x := by omega
      _ = L.block .x * (b + 1) := by ring
      _ ≤ L.grid .x * L.block .x := by
        rw [Nat.mul_comm]; exact Nat.mul_le_mul_right _ hb
  have hmod : (L.block .x * b + 32 * k) % L.block .x = 32 * k := by
    rw [Nat.mul_add_mod, Nat.mod_eq_of_lt (by omega)]
  refine ⟨sig.group L 1 (L.block .x * b + 32 * k), ⟨_, List.mem_range.2 ht, rfl, ?_⟩, ?_, ?_⟩
  · show ((2 : Fin 4), (L.block .x * b + 32 * k) / volume L.block) = (2, b)
    rw [hv, Nat.mul_add_div hB, Nat.div_eq_of_lt (by omega), Nat.add_zero]
  · show (warpIdx 0 1).val (gemvBind L (sig.group L 1 (L.block .x * b + 32 * k)) σ) < σ 7
    rw [gemv_row ha ht, show L.index (L.block .x * b + 32 * k) .x = L.block .x * b + 32 * k
      from Launch.index_oneDim hg hbk ht]
    have e1 : L.block .x * b = 32 * (b * q) := by rw [hq]; ring
    have e2 : (b + 1) * (L.block .x / 32) = b * q + q := by
      rw [hq, Nat.mul_div_cancel_left q (by decide)]; ring
    omega
  · rw [gemv_inner]
    show (L.env (L.groupNum 1 (L.block .x * b + 32 * k))).sreg .tid .x / σ 5 = k
    rw [(warp_regs hg hbk ht).1, h5, hmod]
    omega

/-- **gemv's last block, partly owned.** At grid (7,1,1) and block (96,1,1), at `m = 20` (an
admissible assignment and launch of 21 warps), block 6 holds the warps of rows 18, 19 and 20,
and row 20 owns no tile (`(6 + 1) · 3 > 20`): the tiles of block 6's warps lie in its coarse tile
(`gemv_coarsen`), and the coarse tile also holds byte 80 of `y`, row 20's first byte, which is
in no warp's tile, so the coarse tile is not the union of its warps' tiles. -/
theorem gemv_partial (y : Nat) :
    ⋃ j ∈ {j | (gemvView y).Inside (launch2 7 1 96 1) 2 (2, 6) j},
        (gemvView y).tile (asg [0, 0, 0, 0, 96, 32, 7, 20]) (launch2 7 1 96 1) j ⊆
      ((gemvView y).coarsen 2 1 gemvBlock).tile (asg [0, 0, 0, 0, 96, 32, 7, 20])
        (launch2 7 1 96 1) (2, 6) ∧
    sig.place y 80 ∈ ((gemvView y).coarsen 2 1 gemvBlock).tile (asg [0, 0, 0, 0, 96, 32, 7, 20])
        (launch2 7 1 96 1) (2, 6) ∧
    sig.place y 80 ∉ ⋃ j ∈ {j | (gemvView y).Inside (launch2 7 1 96 1) 2 (2, 6) j},
        (gemvView y).tile (asg [0, 0, 0, 0, 96, 32, 7, 20]) (launch2 7 1 96 1) j := by
  refine ⟨(gemv_coarsen y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ 6).1, ?_, fun hx => ?_⟩
  · have hc :
        8 < (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 96, 32, 7, 20])).size := by
      rw [View.coarsen_size, gemv_innerProd]
      show 8 < (elem 4).size *
        (asg [0, 0, 0, 0, 96, 32, 7, 20] 4 / asg [0, 0, 0, 0, 96, 32, 7, 20] 5)
      rw [elem_size]
      decide
    have hmem : ∀ {L : Launch} {t : Nat}, t < volume L.grid * volume L.block →
        t ∈ sig.threads L := fun h => List.mem_range.2 h
    refine ⟨⟨(1, 576), ⟨576, hmem (by decide), rfl, rfl⟩,
      (by decide : (warpIdx 0 1).val
        (gemvBind (launch2 7 1 96 1) (1, 576) (asg [0, 0, 0, 0, 96, 32, 7, 20])) < 20)⟩, 8, hc, ?_⟩
    show sig.place y 80 = sig.place y ↑(((gemvView y).outer 1).val
      (gemvBlock (launch2 7 1 96 1) (2, 6) (asg [0, 0, 0, 0, 96, 32, 7, 20])) *
        (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 96, 32, 7, 20])).cosize +
      (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 96, 32, 7, 20])).call
        (leaf 8 false))
    rw [gemv_outer, View.coarsen_call _ _ _ _ (elem_congruent 4) (elem_pos (by decide)) hc,
      View.coarsen_cosize _ _ _ _ (elem_congruent 4) (elem_pos (by decide))
        (by rw [gemv_innerProd]; decide), gemv_innerProd]
    simp only [gemvBlock, gemvView, elem_size, elem_call, elem_cosize (show 0 < 4 by decide),
      ↓reduceIte]
    rfl
  · simp only [Set.mem_iUnion] at hx
    obtain ⟨j, -, hxj⟩ := hx
    obtain ⟨hk, c, hc4, hpc⟩ := (gemv_mem y _ _ _ _).1 hxj
    have h' := (place_inj hpc).2
    change _ < 20 at hk
    omega

/-- In one block of one warp (grid (1,1,1) and block (32,1,1)), every thread's warp is warp 0. -/
theorem oneWarp_group {t : Nat}
    (ht : t < volume (launch2 1 1 32 1).grid * volume (launch2 1 1 32 1).block) :
    (launch2 1 1 32 1).groupNum 1 t = 0 := by
  have hB : volume (launch2 1 1 32 1).block = 32 := rfl
  have hG : volume (launch2 1 1 32 1).grid = 1 := rfl
  rw [hB, hG] at ht
  rw [groupNum_one, hB]
  omega

/-- **Mutant: the warp radix one more than the block's warp count.** At grid (1,1,1) and block
(32,1,1), one block of one warp, with `ntid.x` assigned 64, so the warp digit's radix is
`64 / 32 = 2`, and `m = 2`: `gemvAdm` refuses the assignment; the view is well formed there (one
warp, the owner of row 0); `ho` fails at the warp digit 1, as the block has no second warp; and
the coarsened tile of block 0, bytes 0 to 7 of `y`, is not the union of its warps' tiles, bytes
0 to 3, as byte 4 is in the one and not in the other. -/
theorem gemv_coarsen_radix (y : Nat) :
    ¬ gemvAdm (asg [0, 0, 0, 0, 64, 32, 1, 2]) (launch2 1 1 32 1) ∧
      (gemvView y).WF (asg [0, 0, 0, 0, 64, 32, 1, 2]) (launch2 1 1 32 1) ∧
      (¬ ∃ j, (gemvView y).Inside (launch2 1 1 32 1) 2 (2, 0) j ∧
        (gemvView y).owns (launch2 1 1 32 1) j (asg [0, 0, 0, 0, 64, 32, 1, 2]) ∧
        ((gemvView y).inner 1).val
          ((gemvView y).bind (launch2 1 1 32 1) j (asg [0, 0, 0, 0, 64, 32, 1, 2])) = 1) ∧
      ((gemvView y).coarsen 2 1 gemvBlock).tile (asg [0, 0, 0, 0, 64, 32, 1, 2])
          (launch2 1 1 32 1) (2, 0) ≠
        ⋃ j ∈ {j | (gemvView y).Inside (launch2 1 1 32 1) 2 (2, 0) j},
          (gemvView y).tile (asg [0, 0, 0, 0, 64, 32, 1, 2]) (launch2 1 1 32 1) j := by
  have wf : (gemvView y).WF (asg [0, 0, 0, 0, 64, 32, 1, 2]) (launch2 1 1 32 1) :=
    { congruent := elem_congruent 4
      pos := elem_pos (by decide)
      range := fun g hg => by
        obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
        show (warpIdx 0 1).InRange
          (gemvBind (launch2 1 1 32 1) (1, (launch2 1 1 32 1).groupNum 1 t)
            (asg [0, 0, 0, 0, 64, 32, 1, 2]))
        rw [oneWarp_group ht]
        decide
      radices := fun g _ => gemv_radices _ g _
      key_inj := fun g g' hg hg' _ => by
        obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
        obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
        show ((1 : Fin 4), (launch2 1 1 32 1).groupNum 1 t) =
          (1, (launch2 1 1 32 1).groupNum 1 t')
        rw [oneWarp_group ht, oneWarp_group ht'] }
  refine ⟨fun h => absurd h.2.2.1 (by decide), wf, ?_, fun he => ?_⟩
  · rintro ⟨j, ⟨t, ht, rfl, -⟩, -, hk⟩
    have ht' : t < volume (launch2 1 1 32 1).grid * volume (launch2 1 1 32 1).block :=
      List.mem_range.1 ht
    rw [gemv_inner] at hk
    change gemvBind (launch2 1 1 32 1) (1, (launch2 1 1 32 1).groupNum 1 t)
      (asg [0, 0, 0, 0, 64, 32, 1, 2]) 0 / asg [0, 0, 0, 0, 64, 32, 1, 2] 5 = 1 at hk
    rw [oneWarp_group ht'] at hk
    exact absurd hk (by decide)
  · have hc :
        4 < (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 64, 32, 1, 2])).size := by
      rw [View.coarsen_size, gemv_innerProd]
      show 4 < (elem 4).size * (asg [0, 0, 0, 0, 64, 32, 1, 2] 4 / asg [0, 0, 0, 0, 64, 32, 1, 2] 5)
      rw [elem_size]
      decide
    have hx : sig.place y 4 ∈ ((gemvView y).coarsen 2 1 gemvBlock).tile
        (asg [0, 0, 0, 0, 64, 32, 1, 2]) (launch2 1 1 32 1) (2, 0) := by
      refine ⟨⟨(1, 0), ⟨0, List.mem_range.2 (by decide), rfl, rfl⟩, (by decide : (warpIdx 0 1).val
        (gemvBind (launch2 1 1 32 1) (1, 0) (asg [0, 0, 0, 0, 64, 32, 1, 2])) < 2)⟩, 4, hc, ?_⟩
      show sig.place y 4 = sig.place y ↑(((gemvView y).outer 1).val
        (gemvBlock (launch2 1 1 32 1) (2, 0) (asg [0, 0, 0, 0, 64, 32, 1, 2])) *
          (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 64, 32, 1, 2])).cosize +
        (((gemvView y).coarsen 2 1 gemvBlock).lay (asg [0, 0, 0, 0, 64, 32, 1, 2])).call
          (leaf 4 false))
      rw [gemv_outer, View.coarsen_call _ _ _ _ (elem_congruent 4) (elem_pos (by decide)) hc]
      simp only [gemvBlock, gemvView, elem_size, elem_call, elem_cosize (show 0 < 4 by decide),
        ↓reduceIte, Nat.zero_mul, Nat.zero_add]
      rfl
    rw [he] at hx
    simp only [Set.mem_iUnion] at hx
    obtain ⟨j, ⟨t, ht, rfl, -⟩, hxj⟩ := hx
    have ht' : t < volume (launch2 1 1 32 1).grid * volume (launch2 1 1 32 1).block :=
      List.mem_range.1 ht
    obtain ⟨-, c, hc4, hpc⟩ := (gemv_mem y _ _ _ _).1 hxj
    have h0 : (warpIdx 0 1).val (gemvBind (launch2 1 1 32 1)
        (sig.group (launch2 1 1 32 1) (gemvView y).level t) (asg [0, 0, 0, 0, 64, 32, 1, 2])) =
        0 := by
      show (warpIdx 0 1).val (gemvBind (launch2 1 1 32 1) (1, (launch2 1 1 32 1).groupNum 1 t)
        (asg [0, 0, 0, 0, 64, 32, 1, 2])) = 0
      rw [oneWarp_group ht']
      decide
    rw [h0] at hpc
    have h4 : (4 : Int) = ((4 * 0 + c : Nat) : Int) := (place_inj hpc).2
    omega

end MojoProofTest.GPUProof.View
