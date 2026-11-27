import GPUProof.Layout.Laws
import GPUProof.View
import MojoProof.Sem.Index
import MojoProof.Sem.SigDef
import MojoProofTest.GPUProof.MixedRadix
import MojoProofTest.GPUProof.View

/-!
# A view at a key stride: layer norm's interleaved footprint

GPUProof/View.lean's `View.tilingAt` tiles a view whose key has its own stride `d`
(`View.offAt`: instance `g`'s offset of coordinate `c` is `key · d + lay(c)`), when every offset
of the layout, modulo the radix product times `d`, is below `d` (`View.Interleaved`). Here, at
MojoProof's `sig`, the instance is MAX's layer norm at its block kernel of rank 1,
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll. Its row loop runs
the body at block 0 only (the row starts at `ctaid.x`, :39, and the exit test :58, :65 is
`row ≥ 1` on the first trip), and there thread `tid` (:31-32) stores the floats `tid + 128 j` of
the output for the `j` with `tid + 128 j < n` (the step :681, the exit :684, the index and
`getelementptr` :699-700, the guard :708-709, the store :722), `n` the first field of the
arguments (:101). The kernels of block size 64, 256 and 1024 in the same folder
(ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, ..._bs256_762bdc07.nvptx.ll and
..._bs1024_c4d21970.nvptx.ll) step by their block size (:681). At `n = B X` (`B` the block size)
a thread's floats are `X` floats at stride `B`:

* `lnView y B`: the output of the kernel of block size `B`, in buffer `y`, at the thread level
  (level 0), with the layout of one thread's `X` floats (`lnLay`, modes `(4, 1)` and
  `(X, 4 B)`, `X` the variable 5), the key `tid.x` with radix the variable 4 (`lnKey`,
  `lnBind`), and the threads of block 0 owning a tile. `lnAdm B'` admits the 1-D launches of
  `B'` threads a block with the variable 4 the block size and `X ≥ 1`.
* `ln_wf`: the view of every block size is well formed at every assignment and launch that
  `lnAdm B'` admits, for every `B'`; `ln_interleaved`: at `B' = B` it interleaves at the key
  stride 4 bytes, as every offset modulo `4 B` is its byte in its float.
* `ln_tile`: thread `t` of a launch owns the floats `t + B j`, `j < X`, when it is in block 0,
  and no byte otherwise, with the `example` of thread 5's float 261 at `B = 128` and `X = 3`.
* `ln_tiling`: the tiles at the key stride 4 are a tiling (`View.tilingAt` at `place_inj`), with
  two `example`s: the kernel of block size 128 at one block and `X = 1`, and the kernel of block
  size 256 at two blocks and `X = 3` (block 1 owns no tile).
* The mutant, `ln_stride64`: the view of the kernel of block size 64 at a launch of 128 threads
  and `X = 2` is well formed, does not interleave, the tiles of threads 0 and 64 both hold byte
  256 of `y`, and the tiles are not a tiling.
* `ln_cover`: the tiles at the key stride 4 cover the `B X` floats of `y` at every assignment
  and launch of the kernel of block size `B` with a block (`View.coverAt` at `P = B` and
  `Q = X`), with two `example`s: block size 128 at one block and `X = 1`, and block size 256 at
  two blocks and `X = 3`.
* The mutant, `ln_stride64_uncovered`: at the view of block size 64, 128 threads and `X = 2`,
  byte 768 of `y` (float 192) is in no tile, so the tiles do not cover the first `128 · 4 · 2`
  bytes.
* `ln_cover_period` and `ln_cover_short`: `View.cover_iffAt`'s premises `hd` and `hPQ` are
  needed. At block size 128, 128 threads and `X = 2`, the tiles cover the first `256 · 4` bytes
  while key value 128 is no owner's (`P = 256`, where `hd` fails), and the first `64 · 4 · 2`
  bytes while the offset 256 is no coordinate's (`P = 64`, `Q = 2`, where `hd` holds and `hPQ`
  fails).
* `ln_owners`: every key value below `B` is a thread's of block 0, at every view `lnView y C`
  and every assignment and launch of the kernel of block size `B` with a block.
* `ln_separated` and `ln_tiling_cols`: at `B ≤ C`, the view `lnView y C` (column `t` of a
  row-major matrix of `C` float columns, for thread `t`) is separated at the key stride 4
  (`View.Separated`), so its tiles are a tiling (`View.tiling_separated`);
  `ln_cols_not_interleaved`: at `B = 2`, `C = 3` and `X = 2` it is a tiling that does not
  interleave.
* The mutant, `ln_stride64_not_separated`: `ln_stride64`'s view is not separated, and so
  (`View.separated_of_disjoint` at `ln_owners`) its tiles are not pairwise disjoint.

Coarsening at a key stride other than the cosize, `View.coarsenAt_tile` and
`View.tile_subset_coarsenAt`, at a key of two digits (layer norm's has one):

* `gsView y T own`: a grid-stride loop's output, thread `t` of the grid holding the floats
  `t + T j`, `j < X`, with the key `gsKey` (`tid.x`, then `ctaid.x`, valued `t`) and the owners
  `own`; `gs_wf`: it is well formed at 2 blocks of 2 threads and `X = 2` (`gsAsg`, `gsLaunch`),
  and `gs_hn`: the threads of a block agree on the outer digit, both by evaluation.
* `gs_coarsen`: at `T = 4` and every thread an owner, the view coarsened to the block level at
  the key stride 4 bytes (the layout's cosize is 20) has at block 1 the tile at the key stride
  8 that is the union of its threads' tiles (`View.coarsenAt_tile`).
* The mutant, `gs_gap`: with the threads of `tid.x` 1 owning no tile (`gsGap`), the threads'
  tiles still lie in block 1's coarse tile (`View.tile_subset_coarsenAt`), while `ho` fails at
  the inner key value 1, and byte 12 of `y` is in the coarse tile and in no owner's tile.

A row of `n` floats at every `n`, `B ∣ n` or not, with `X = ⌈n / B⌉`: the guard (:708) skips a
thread's last float when it is not below `n`, so the footprint is the tile under the bound `4 n`
on the offset (`View.guardAt`), not a layout (one layout serves every thread of a view):

* `lnLoop`, `lnStores`: the floats the IR's loop stores at thread `t`, a model of the loop
  (exit :684, guard :708, step :681); `lnLoop_eq`, `lnStores_eq`: for every block size `B`, row
  length `n`, thread `t` and count `X` with `n ≤ t + B X`, they are the floats `t + B j`,
  `j < X`, below `n`.
* `ln_guard_tile`: thread `t`'s guarded tile is the floats `t + B j`, `j < X`, below `n`, when
  it is in block 0, and no byte otherwise; `ln_guard_dvd`: at `n = B X` it is `ln_tile`'s tile
  (`View.guardAt_subset`, `View.tile_subset_guardAt`), so `ln_wf`, `ln_tile`, `ln_tiling`,
  `ln_cover` and their tests are the case `B ∣ n`.
* `ln_guard_tiling`, `ln_guard_cover`: the guarded tiles are a tiling (`GPUProof.Tiling.mono`)
  and cover the first `4 n` bytes when `n ≤ B X` (`View.cover_guardAt`).
* `ln_guard_stores`: for every block size, row length and thread `t`, with `n ≤ t + B X` at the
  threads of block 0, thread `t`'s guarded tile is exactly the bytes of the floats `lnStores`
  gives (`lnStores_eq`); its uses `ln_guard_300` (block size 128, one block, `n = 300`) and
  `ln_guard_170` (block size 64, two blocks, `n = 170`).
* The mutant, `ln_unguarded_300`: at `n = 300`, byte 1532 of `y` (float 383) is in thread 127's
  tile without the guard and in no thread's stores.

That a run of the kernel stores at these floats is not proved; `lnLoop` is a model of the IR's
loop, not derived from it. The `example` after `lnLay_call` checks that `View.offAt` at the stride
`cosize` is `View.off`.
-/

namespace MojoProofTest.GPUProof.ViewStride

open _root_.GPUProof _root_.GPUProof.Layout _root_.GPUProof.Layout.Tup MojoProof.Sem
open MojoProofTest.GPUProof.MixedRadix (asg)
open MojoProofTest.GPUProof.View (inst_sig place_inj gemvBind gemvBlock)

/-! ## One thread's floats -/

/-- The layout of one thread's `X` floats at stride `B` floats, for every `X` and `B`: the 4
bytes of a float (extent 4, stride 1), then the float `j < X` at byte `4 B j`. -/
def lnLay (X B : Nat) : Lay := Lay.flat [(4, 1), (X, 4 * B)]

/-- `lnLay X B` has `4 X` coordinates, for every `X` and `B`. -/
theorem lnLay_size (X B : Nat) : (lnLay X B).size = 4 * X := by
  rw [lnLay, Lay.size_flat]
  simp

/-- `lnLay X B`'s offset of coordinate `c` is `c % 4 + (c / 4 % X) · 4 B`, for every `X`, `B` and
`c < 4 X` (`GPUProof.Layout.Lay.call_scalar`). -/
theorem lnLay_call {X B c : Nat} (hc : c < 4 * X) :
    (lnLay X B).call (leaf c false) = c % 4 + c / 4 % X * (4 * B) := by
  rw [Lay.call_scalar (lnLay X B) (Lay.flat_congruent _) c false (by rw [lnLay_size]; exact hc)]
  simp [lnLay, Lay.flat, leavesL, leaves, colex]

-- At the key stride `cosize`, `View.offAt` is `View.off`, for every view of `sig`.
example (v : View sig) (σ : Sizes) (L : Launch) (g : Fin 4 × Nat) (c : Nat) :
    v.offAt (fun σ => (v.lay σ).cosize) σ L g c = v.off σ L g c := rfl

/-! ## Layer norm's view on `sig` -/

/-- The key of a thread: the digit `tid.x` (the variable 0) with radix the variable 4. -/
def lnKey : MixedRadix := ⟨[(.var 0, .var 4)]⟩

/-- `bind` sets variable 0 to the thread's `tid.x`, as `sig`'s special registers give it
(`Launch.env`). -/
def lnBind (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) : Sizes :=
  fun x => if x = 0 then (L.env g.2).sreg .tid .x else σ x

/-- The output of layer norm's block kernel of rank 1 and block size `B`, in buffer `y`, at the
thread level (level 0) of `sig`: the layout of one thread's `X` floats at stride `B` (`lnLay`, `X`
the variable 5), the key `lnKey` bound by `lnBind`, and the threads of block 0 (`ctaid.x = 0`)
owning a tile, as the kernel's row loop runs its body at block 0 only
(tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll:39, :58, :65). -/
def lnView (y B : Nat) : View sig where
  lay σ := lnLay (σ 5) B
  level := (0 : Fin 4)
  buf := y
  key := lnKey
  bind := lnBind
  owns L g _ := (L.env g.2).sreg .ctaid .x = 0

/-- The admissible assignments and launches of the kernel of block size `B`: a launch with side 1
in `y` and `z` and `B` threads a block in `x`, the variable 4 the block size, and `X ≥ 1` (the
variable 5). -/
def lnAdm (B : Nat) (σ : Sizes) (L : Launch) : Prop :=
  (L.grid .y = 1 ∧ L.grid .z = 1) ∧ (L.block .y = 1 ∧ L.block .z = 1) ∧ σ 4 = L.block .x ∧
    L.block .x = B ∧ 0 < σ 5

/-- On a launch with side 1 in `y` and `z`, thread `t` has `tid.x` `t % B` and `ctaid.x` `t / B`,
with `B` the block's `x` side, for every thread below the thread count. -/
theorem ln_regs {L : Launch} (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {t : Nat} (ht : t < volume L.grid * volume L.block) :
    (L.env t).sreg .tid .x = t % L.block .x ∧ (L.env t).sreg .ctaid .x = t / L.block .x := by
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hG : volume L.grid = L.grid .x := by simp [volume, hg.1, hg.2]
  show coord L.block (t % volume L.block) .x = _ ∧ coord L.grid (t / volume L.block) .x = _
  simp only [coord, hv, Nat.mod_mod, true_and]
  rw [hv, hG, Nat.mul_comm] at ht
  exact Nat.mod_eq_of_lt (Nat.div_lt_of_lt_mul ht)

/-- The key's value at an instance is its thread's `tid.x`, at every launch, instance and
assignment. -/
theorem ln_key (L : Launch) (g : Fin 4 × Nat) (σ : Sizes) :
    lnKey.val (lnBind L g σ) = (L.env g.2).sreg .tid .x := by
  simp [lnKey, lnBind, MixedRadix.val, SizeExpr.eval]

/-- A thread of block 0 is its `tid.x`: on a launch with side 1 in `y` and `z`, a thread `t`
below the thread count whose `ctaid.x` is 0 is below the block's `x` side and is `t % B`. -/
theorem ln_block0 {L : Launch} (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {t : Nat} (ht : t < volume L.grid * volume L.block)
    (h0 : (L.env t).sreg .ctaid .x = 0) : t < L.block .x ∧ t % L.block .x = t := by
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
  have e := Nat.div_add_mod t (L.block .x)
  rw [← (ln_regs hg hb ht).2, h0, Nat.mul_zero, Nat.zero_add] at e
  exact ⟨e ▸ Nat.mod_lt t hB, e⟩

/-- **Layer norm's view is well formed at MojoProof's `sig`**, for every buffer and block size
`B` of the kernel, at every assignment and launch admissible for some block size `B'`
(`lnAdm B'`): the key `tid.x` is below the block size, its radix reads no variable `lnBind` sets,
and two threads of block 0 with one `tid.x` are one. -/
theorem ln_wf (y B B' : Nat) (σ : Sizes) (L : Launch) (ha : lnAdm B' σ L) :
    (lnView y B).WF σ L where
  congruent := Lay.flat_congruent _
  pos s hs := by
    simp [lnView, lnLay, Lay.flat, leavesL, leaves] at hs
    rcases hs with rfl | rfl
    · decide
    · exact ha.2.2.2.2
  range g hg := by
    obtain ⟨hg1, hb, h4, -, -⟩ := ha
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
    have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
    intro p hp
    simp only [lnView, lnKey, List.mem_cons, List.not_mem_nil, or_false] at hp
    subst hp
    show (L.env t).sreg .tid .x < σ 4
    rw [(ln_regs hg1 hb ht).1, h4]
    exact Nat.mod_lt t hB
  radices g _ := by simp [lnView, lnKey, lnBind, SizeExpr.eval]
  key_inj g g' hg hg' he := by
    obtain ⟨hg1, hb, -, -, -⟩ := ha
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
    change [(L.env t).sreg .tid .x] = [(L.env t').sreg .tid .x] at he
    rw [(ln_regs hg1 hb ht).1, (ln_regs hg1 hb ht').1, (ln_block0 hg1 hb ht hg.2).2,
      (ln_block0 hg1 hb ht' hg'.2).2] at he
    simp only [List.cons.injEq, and_true] at he
    show ((0 : Fin 4), t) = (0, t')
    rw [he]

/-- **Layer norm's view interleaves at the key stride 4 bytes**, for every buffer and block size
`B`, at every assignment and launch of the kernel of block size `B` (`lnAdm B`): the key's radix
product is `B`, and every offset `c % 4 + j · 4 B` of `lnLay`, modulo `4 B`, is `c % 4`, below 4
(`Nat.add_mul_mod_self_right`). -/
theorem ln_interleaved (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) :
    (lnView y B).Interleaved (fun _ => 4) σ := by
  obtain ⟨-, -, h4, hB, -⟩ := ha
  intro c hc
  have hc' : c < 4 * σ 5 := by rw [← lnLay_size (σ 5) B]; exact hc
  have hr : lnKey.radixProd σ * 4 = 4 * B := by
    rw [show lnKey.radixProd σ = σ 4 by simp [lnKey, MixedRadix.radixProd, SizeExpr.eval], h4, hB,
      Nat.mul_comm]
  show (lnLay (σ 5) B).call (leaf c false) % (lnKey.radixProd σ * 4) < 4
  rw [lnLay_call hc', hr, Nat.add_mul_mod_self_right]
  exact Nat.lt_of_le_of_lt (Nat.mod_le _ _) (Nat.mod_lt _ (by decide))

/-- **Layer norm's thread tile is its floats at stride `B`**, a natural-number model. At
MojoProof's `sig`, for every buffer `y` and block size `B` of the kernel, at every assignment and
launch admissible for some block size `B'` (`lnAdm B'`), and every thread `t` below the thread
count: the tile of `t` at the key stride 4 is the bytes of the floats `t + B j` of `y`, `j < X`
(the variable 5), when `t` is in block 0 (`t < B'`), and no byte otherwise. At `B' = B` these are
the floats the kernel's thread stores at `n = B X`
(tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll:699-700, :722 at
`B = 128`); that a run stores there is not proved here. -/
theorem ln_tile (y B : Nat) {B' : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B' σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) (x : Nat × Int) :
    x ∈ (lnView y B).tileAt (fun _ => 4) σ L (sig.group L 0 t) ↔
      t < B' ∧ ∃ j < σ 5, ∃ b < 4, x = sig.place y ↑(4 * (t + B * j) + b) := by
  obtain ⟨hg, hb, -, hB, -⟩ := ha
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hpos : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
  show ((L.env t).sreg .ctaid .x = 0 ∧ ∃ c < (lnLay (σ 5) B).size,
      x = sig.place y ↑(lnKey.val (lnBind L (0, t) σ) * 4 + (lnLay (σ 5) B).call (leaf c false)))
    ↔ _
  rw [ln_key, lnLay_size]
  constructor
  · rintro ⟨h0, c, hc, rfl⟩
    obtain ⟨htB, hm⟩ := ln_block0 hg hb ht h0
    refine ⟨hB ▸ htB, c / 4, by omega, c % 4, Nat.mod_lt _ (by decide), ?_⟩
    rw [(ln_regs hg hb ht).1, hm, lnLay_call hc, Nat.mod_eq_of_lt (show c / 4 < σ 5 by omega),
      show t * 4 + (c % 4 + c / 4 * (4 * B)) = 4 * (t + B * (c / 4)) + c % 4 by ring]
  · rintro ⟨htB, j, hj, b, hb4, rfl⟩
    rw [← hB] at htB
    refine ⟨by rw [(ln_regs hg hb ht).2]; exact Nat.div_eq_of_lt htB, 4 * j + b, by omega, ?_⟩
    rw [(ln_regs hg hb ht).1, Nat.mod_eq_of_lt htB, lnLay_call (by omega),
      show (4 * j + b) % 4 = b by omega, show (4 * j + b) / 4 = j by omega, Nat.mod_eq_of_lt hj,
      show t * 4 + (b + j * (4 * B)) = 4 * (t + B * j) + b by ring]

/-- `ln_tile` at the kernel of block size 128, `X = 3` (`n = 384`) and one block: thread 5 owns
its float `5 + 128 · 2 = 261`, bytes 1044 to 1047 of `y`. -/
example (y : Nat) : sig.place y 1044 ∈ (lnView y 128).tileAt (fun _ => 4)
    (asg [0, 0, 0, 0, 128, 3]) (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 5) :=
  (ln_tile y 128 ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (by decide) _).2
    ⟨by decide, 2, by decide, 0, by decide, rfl⟩

/-! ## The tiling at the key stride -/

/-- **Layer norm's thread tiles are a tiling at the key stride 4 bytes.** At MojoProof's `sig`,
for every buffer and block size `B`, at every assignment and launch of the kernel of block size
`B` (`lnAdm B`), every owner's tile is in the view's bytes at the key stride and the tiles of two
threads are disjoint (`View.tilingAt` at `place_inj`, `ln_wf` and `ln_interleaved`). -/
theorem ln_tiling (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) :
    Tiling ((lnView y B).tilesAt (fun _ => 4) σ L) ((lnView y B).bytesAt (fun _ => 4) σ) :=
  View.tilingAt _ _ place_inj (ln_wf y B B σ L ha) (ln_interleaved y ha)

/-- The tiling of the kernel of block size 128 at one block of 128 threads and `X = 1`. -/
example (y : Nat) :
    Tiling ((lnView y 128).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 1]) (launch2 1 1 128 1))
      ((lnView y 128).bytesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 1])) :=
  ln_tiling y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩

/-- The tiling of the kernel of block size 256 at two blocks of 256 threads and `X = 3`: the
threads of block 1 own no tile. -/
example (y : Nat) :
    Tiling ((lnView y 256).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 256, 3]) (launch2 2 1 256 1))
      ((lnView y 256).bytesAt (fun _ => 4) (asg [0, 0, 0, 0, 256, 3])) :=
  ln_tiling y ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩

/-- **Mutant: the stride of another block size.** The view of the kernel of block size 64 at one
block of 128 threads and `X = 2` (`lnAdm 128`): it is well formed (`ln_wf`), it does not
interleave at the key stride 4 (coordinate 4, the first byte of a thread's second float, has the
offset 256, which modulo `128 · 4` is not below 4), the tiles of threads 0 and 64 both hold byte
256 of `y` (thread 0's float 64 and thread 64's float 64), and the tiles are not a tiling. -/
theorem ln_stride64 (y : Nat) :
    lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) ∧
      (lnView y 64).WF (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) ∧
      ¬ (lnView y 64).Interleaved (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) ∧
      sig.place y 256 ∈ (lnView y 64).tileAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])
        (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 0) ∧
      sig.place y 256 ∈ (lnView y 64).tileAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])
        (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 64) ∧
      ¬ Tiling ((lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1))
        ((lnView y 64).bytesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])) := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have m0 := (ln_tile y 64 ha (t := 0) (by decide) (sig.place y 256)).2
    ⟨by decide, 1, by decide, 0, by decide, rfl⟩
  have m64 := (ln_tile y 64 ha (t := 64) (by decide) (sig.place y 256)).2
    ⟨by decide, 0, by decide, 0, by decide, rfl⟩
  refine ⟨ha, ln_wf y 64 128 _ _ ha, fun h => ?_, m0, m64, ?_⟩
  · have h4 : (lnLay 2 64).call (leaf 4 false) %
        (lnKey.radixProd (asg [0, 0, 0, 0, 128, 2]) * 4) < 4 :=
      h 4 (by rw [show (lnView y 64).lay (asg [0, 0, 0, 0, 128, 2]) = lnLay 2 64 from rfl,
        lnLay_size]; decide)
    rw [lnLay_call (by decide)] at h4
    exact absurd h4 (by decide)
  · rintro ⟨-, hd⟩
    have h0 : sig.Inst (launch2 1 1 128 1) (0 : Fin 4) (0, 0) := inst_sig.2 ⟨0, by decide, rfl⟩
    have h1 : sig.Inst (launch2 1 1 128 1) (0 : Fin 4) (0, 64) :=
      inst_sig.2 ⟨64, by decide, rfl⟩
    have hne : (⟨(0, 0), h0⟩ : {g // sig.Inst (launch2 1 1 128 1) (lnView y 64).level g}) ≠
        ⟨(0, 64), h1⟩ :=
      fun h => absurd (congrArg Subtype.val h) (by decide : ((0 : Fin 4), 0) ≠ (0, 64))
    exact Set.disjoint_left.1 (hd hne) m0 m64

/-! ## Coverage at the key stride -/

/-- **Every key value below the block size is an owner's.** At MojoProof's `sig`, for every
buffer `y` and stride `C` of the view, at every assignment and launch of the kernel of block
size `B` (`lnAdm B`) with at least one block: thread `k < B` is in block 0, so it owns a tile,
and its key value is its `tid.x`, `k` (`ln_regs`, `ln_key`). -/
theorem ln_owners (y C : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L)
    (hG : 0 < L.grid .x) :
    ∀ k < B, ∃ g, (lnView y C).Owner σ L g ∧
      (lnView y C).key.val ((lnView y C).bind L g σ) = k := by
  obtain ⟨hg, hb, -, hB, -⟩ := ha
  intro k hk
  have hv : volume L.block = B := by simp [volume, hb.1, hb.2, hB]
  have hG' : volume L.grid = L.grid .x := by simp [volume, hg.1, hg.2]
  have ht : k < volume L.grid * volume L.block := by
    rw [hv, hG']
    exact Nat.lt_of_lt_of_le hk (Nat.le_mul_of_pos_left _ hG)
  obtain ⟨htid, hcta⟩ := ln_regs hg hb ht
  rw [hB] at htid hcta
  refine ⟨((0 : Fin 4), k), ⟨inst_sig.2 ⟨k, ht, rfl⟩, ?_⟩, ?_⟩
  · show (L.env k).sreg .ctaid .x = 0
    rw [hcta, Nat.div_eq_of_lt hk]
  · show lnKey.val (lnBind L ((0 : Fin 4), k) σ) = k
    rw [ln_key]
    show (L.env k).sreg .tid .x = k
    rw [htid, Nat.mod_eq_of_lt hk]

/-- **Layer norm's thread tiles cover its `B X` floats at the key stride 4 bytes.** At
MojoProof's `sig`, for every buffer `y` and block size `B`, at every assignment and launch of the
kernel of block size `B` (`lnAdm B`) with at least one block: each of the first `B · 4 · X` bytes
of `y` (`X` the variable 5) is in a thread's tile at the key stride 4 (`View.coverAt` at `P = B`
and `Q = X`, `ln_owners`): byte `4 (k + B q) + r` is byte `r` of float `q` of thread `k`, in
block 0. -/
theorem ln_cover (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L)
    (hG : 0 < L.grid .x) :
    {x | ∃ i : Nat, i < B * 4 * σ 5 ∧ x = sig.place y i} ⊆
      ⋃ g, (lnView y B).tilesAt (fun _ => 4) σ L g := by
  refine View.coverAt (lnView y B) (fun _ => 4) (P := B) (Q := σ 5) (fun q hq r hr => ?_)
    (ln_owners y B ha hG)
  refine ⟨4 * q + r, by
    show 4 * q + r < (lnLay (σ 5) B).size
    rw [lnLay_size]
    omega, ?_⟩
  show (lnLay (σ 5) B).call (leaf (4 * q + r) false) = r + B * 4 * q
  rw [lnLay_call (by omega), show (4 * q + r) % 4 = r by omega,
    show (4 * q + r) / 4 = q by omega, Nat.mod_eq_of_lt hq]
  ring

/-- `ln_cover` at the kernel of block size 128, one block of 128 threads and `X = 1`: the 128
floats of `y`, bytes 0 to 511. -/
example (y : Nat) :
    {x | ∃ i : Nat, i < 128 * 4 * 1 ∧ x = sig.place y i} ⊆
      ⋃ g, (lnView y 128).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 1]) (launch2 1 1 128 1) g :=
  ln_cover (σ := asg [0, 0, 0, 0, 128, 1]) (L := launch2 1 1 128 1) y
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (by decide)

/-- `ln_cover` at the kernel of block size 256, two blocks of 256 threads and `X = 3`: the 768
floats of `y`, bytes 0 to 3071, all in the tiles of block 0's threads. -/
example (y : Nat) :
    {x | ∃ i : Nat, i < 256 * 4 * 3 ∧ x = sig.place y i} ⊆
      ⋃ g, (lnView y 256).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 256, 3]) (launch2 2 1 256 1) g :=
  ln_cover (σ := asg [0, 0, 0, 0, 256, 3]) (L := launch2 2 1 256 1) y
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (by decide)

/-- **Mutant: the stride of another block size leaves a float uncovered.** The view of the
kernel of block size 64 at one block of 128 threads and `X = 2` (`lnAdm 128`): byte 768 of `y`,
the first byte of float 192, is below `128 · 4 · 2` and in no thread's tile at the key stride 4,
as thread `t < 128` holds the floats `t` and `t + 64` only (`ln_tile`), all below 192. So the
tiles do not cover the first `128 · 4 · 2` bytes. -/
theorem ln_stride64_uncovered (y : Nat) :
    sig.place y 768 ∉ ⋃ g, (lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])
        (launch2 1 1 128 1) g ∧
      ¬ {x | ∃ i : Nat, i < 128 * 4 * 2 ∧ x = sig.place y i} ⊆
        ⋃ g, (lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])
          (launch2 1 1 128 1) g := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have hn : sig.place y 768 ∉ ⋃ g, (lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2])
      (launch2 1 1 128 1) g := by
    intro h
    obtain ⟨⟨g, hg⟩, hx⟩ := Set.mem_iUnion.1 h
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg
    obtain ⟨htB, j, hj, b, hb, he⟩ := (ln_tile y 64 ha ht _).1 hx
    have e := (place_inj he).2
    change j < 2 at hj
    omega
  exact ⟨hn, fun h => hn (h ⟨768, by decide, rfl⟩)⟩

/-- **`View.cover_iffAt` needs its interleaving premise `hd`.** The view of the kernel of block
size 128 at one block of 128 threads and `X = 2`, at the key stride 4, the key bound `P = 256`
(twice the radix product 128) and `Q = 1`: the tiles cover the first `256 · 4 · 1` bytes (they
are the first `128 · 4 · 2`, `ln_cover`), while key value 128 is no owner's (every thread's
`tid.x` is below 128), and the layout does not interleave at the period `256 · 4` (coordinate 4,
thread 0's second float, has the offset 512). -/
theorem ln_cover_period (y : Nat) :
    {x | ∃ i : Nat, i < 256 * 4 * 1 ∧ x = sig.place y i} ⊆
        ⋃ g, (lnView y 128).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) g ∧
      ¬ (∀ k < 256, ∃ g, (lnView y 128).Owner (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) g ∧
        lnKey.val (lnBind (launch2 1 1 128 1) g (asg [0, 0, 0, 0, 128, 2])) = k) ∧
      ¬ ∀ c < ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).size,
        ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).call (leaf c false) % (256 * 4) < 4 := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  refine ⟨fun x ⟨i, hi, hx⟩ => ln_cover y ha (by decide)
    ⟨i, by rw [show asg [0, 0, 0, 0, 128, 2] 5 = 2 from rfl]; omega, hx⟩,
    fun h => ?_, fun h => ?_⟩
  · obtain ⟨g, ⟨hi, -⟩, hk⟩ := h 128 (by decide)
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hi
    rw [ln_key] at hk
    change ((launch2 1 1 128 1).env t).sreg .tid .x = 128 at hk
    rw [(ln_regs ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ ht).1] at hk
    exact absurd hk (Nat.ne_of_lt (Nat.mod_lt t (by decide)))
  · have h4 := h 4 (by
      show 4 < (lnLay 2 128).size
      rw [lnLay_size]; decide)
    change (lnLay 2 128).call (leaf 4 false) % (256 * 4) < 4 at h4
    rw [lnLay_call (by decide)] at h4
    exact absurd h4 (by decide)

/-- **`View.cover_iffAt` needs its premise `hPQ`.** The view of the kernel of block size 128 at
one block of 128 threads and `X = 2`, at the key stride 4, the key bound `P = 64` and `Q = 2`
periods: the tiles cover the first `64 · 4 · 2` bytes (every thread's first float, `ln_cover`)
and the layout interleaves at the period `64 · 4` (every offset is below 4 modulo 256), while the
offset `0 + 64 · 4 · 1 = 256` is no coordinate's (the offsets are 0 to 3 and 512 to 515), and
`hPQ` fails: `Q` is 2 and the radix product 128 is above `P`. -/
theorem ln_cover_short (y : Nat) :
    {x | ∃ i : Nat, i < 64 * 4 * 2 ∧ x = sig.place y i} ⊆
        ⋃ g, (lnView y 128).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) g ∧
      (∀ c < ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).size,
        ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).call (leaf c false) % (64 * 4) < 4) ∧
      ¬ (∀ q < 2, ∀ r < 4, ∃ c < ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).size,
        ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).call (leaf c false) = r + 64 * 4 * q) ∧
      ¬ (2 = 1 ∨ (lnView y 128).key.radixProd (asg [0, 0, 0, 0, 128, 2]) ≤ 64) := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have hs : ((lnView y 128).lay (asg [0, 0, 0, 0, 128, 2])).size = 8 := lnLay_size 2 128
  refine ⟨fun x ⟨i, hi, hx⟩ => ln_cover y ha (by decide)
    ⟨i, by rw [show asg [0, 0, 0, 0, 128, 2] 5 = 2 from rfl]; omega, hx⟩, fun c hc => ?_,
    fun h => ?_, ?_⟩
  · rw [hs] at hc
    change (lnLay 2 128).call (leaf c false) % (64 * 4) < 4
    rw [lnLay_call (by omega)]
    omega
  · obtain ⟨c, hc, e⟩ := h 1 (by decide) 0 (by decide)
    rw [hs] at hc
    change (lnLay 2 128).call (leaf c false) = 0 + 64 * 4 * 1 at e
    rw [lnLay_call (by omega)] at e
    omega
  · simp [lnView, lnKey, MixedRadix.radixProd, SizeExpr.eval, asg]

/-! ## A row of `n` floats: the guard -/

/-- The floats a thread of block 0 stores in a row of `n` floats, the loop of the kernel of block
size `B` from the loop index `i` with `k` iterations of fuel, for every `B`, `n`, `tid.x` `t`,
`k` and `i` (tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll at
`B = 128`): the loop exits at `i ≥ n` (`%476`, :684, :690), otherwise stores float `i + t`
(`%485`, :699; the `getelementptr` :700) when `i + t < n` (the guard `%494`, :708-709; the store
:722) and steps to `i + B` (`%473`, :681). A test definition, a model of the IR's loop. -/
def lnLoop (B n t : Nat) : Nat → Nat → List Nat
  | 0, _ => []
  | k + 1, i => if n ≤ i then [] else
      (if i + t < n then [i + t] else []) ++ lnLoop B n t k (i + B)

/-- The floats thread `tid.x = t` of block 0 stores in a row of `n` floats, for every block size
`B`, `n` and `t`: `lnLoop` from the index 0 (`%471`, :679) with `n` iterations of fuel, which the
loop's `⌈n / B⌉` iterations do not exceed at `B ≥ 1`. A test definition. -/
def lnStores (B n t : Nat) : List Nat := lnLoop B n t n 0

/-- **`lnLoop`'s floats are the progression's below `n`**, for every block size `B`, row length
`n`, `tid.x` `t`, fuel `k`, start `m` and count `X` with `n ≤ t + B (m + k)` (the fuel reaches the
floats past the row) and `n ≤ t + B (m + X)` (so does the count): the loop from the index `B m`
stores, in order, the floats `t + B j`, `m ≤ j < m + X`, that are below `n`. By induction on the
fuel: an iteration at `i = B m < n` stores `t + B m` when it is below `n` and steps to
`B (m + 1)`; at `n ≤ B m`, and at the end of the fuel or of the count, no float `t + B j`,
`j ≥ m`, is below `n`. -/
theorem lnLoop_eq {B n t : Nat} : ∀ {k m X : Nat}, n ≤ t + B * (m + k) → n ≤ t + B * (m + X) →
    lnLoop B n t k (B * m) =
      ((List.range' m X).filter fun j => t + B * j < n).map fun j => t + B * j := by
  have hnil : ∀ {m X : Nat}, n ≤ t + B * m →
      (List.range' m X).filter (fun j => t + B * j < n) = [] := fun {m X} h =>
    List.filter_eq_nil_iff.2 fun j hj => by
      have := Nat.mul_le_mul_left B (List.mem_range'_1.1 hj).1
      simp only [decide_eq_true_eq]
      omega
  intro k
  induction k with
  | zero =>
    intro m X hk _
    rw [Nat.add_zero] at hk
    simp [lnLoop, hnil (X := X) hk]
  | succ k ih =>
    intro m X hk hX
    have hk' : n ≤ t + B * (m + 1 + k) := by rw [show m + 1 + k = m + (k + 1) by omega]; exact hk
    have e : B * m + B = B * (m + 1) := by ring
    by_cases hm : n ≤ B * m
    · simp [lnLoop, hm, hnil (X := X) (by omega : n ≤ t + B * m)]
    · cases X with
      | zero =>
        have hX' : n ≤ t + B * m := by rw [Nat.add_zero] at hX; exact hX
        have h0 := ih (m := m + 1) (X := 0) hk' (by rw [Nat.add_zero, ← e]; omega)
        rw [lnLoop, ite_eq_right_of_eq_false _ _ (eq_false hm), e, h0,
          ite_eq_right_of_eq_false _ _ (eq_false (show ¬ B * m + t < n by omega))]
        simp
      | succ X =>
        have h1 := ih (m := m + 1) (X := X) hk'
          (by rw [show m + 1 + X = m + (X + 1) by omega]; exact hX)
        rw [lnLoop, ite_eq_right_of_eq_false _ _ (eq_false hm), e, h1, List.range'_succ,
          List.filter_cons]
        by_cases hp : t + B * m < n
        · simp [hp, Nat.add_comm (B * m) t]
        · simp [hp, Nat.add_comm (B * m) t]

/-- **`lnStores`' floats for every block size, row length and thread**: for every `B`, `n`, `t`
and count `X` with `n ≤ t + B X` (as at `n ≤ B X`, which `X = ⌈n / B⌉` gives), `lnStores B n t`
is the floats `t + B j`, `j < X`, below `n`, in order (`lnLoop_eq` from the index 0, whose fuel
`n` meets `n ≤ t + B n`: at `B ≥ 1` as `n ≤ B n`, at `B = 0` by the premise). The premise is
needed: at `n > t + B X` and `B ≥ 1`, float `t + B X` is in `lnStores B n t` and not of that
form. -/
theorem lnStores_eq {B n t X : Nat} (h : n ≤ t + B * X) :
    lnStores B n t = ((List.range X).filter fun j => t + B * j < n).map fun j => t + B * j := by
  have hk : n ≤ t + B * (0 + n) := by
    rcases Nat.eq_zero_or_pos B with rfl | hB
    · simpa using h
    · rw [Nat.zero_add]
      exact Nat.le_add_left_of_le (Nat.le_mul_of_pos_left n hB)
  have e := lnLoop_eq (k := n) (m := 0) (X := X) hk (by rw [Nat.zero_add]; exact h)
  rw [Nat.mul_zero] at e
  rw [List.range_eq_range']
  exact e

/-- **Layer norm's guarded tile at a row of `n` floats**, a natural-number model. At MojoProof's
`sig`, for every buffer `y`, block size `B` and row length `n`, at every assignment and launch
admissible for some block size `B'` (`lnAdm B'`), and every thread `t` below the thread count:
the tile of `t` at the key stride 4 under the bound `4 n` (`View.guardAt`) is the bytes of the
floats `t + B j` of `y`, `j < X` (the variable 5), that are below `n`, when `t` is in block 0, and
no byte otherwise. At `B' = B` and `X = ⌈n / B⌉` these are the floats the kernel's guarded loop
stores (tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll:699-722 at
`B = 128`: iteration `j < ⌈n / B⌉` stores float `t + B j` when it is below `n`, :708); that a run
stores there is not proved here. At `B ∣ n` the guard drops nothing (`ln_guard_dvd`). -/
theorem ln_guard_tile (y B n : Nat) {B' : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B' σ L)
    {t : Nat} (ht : t < volume L.grid * volume L.block) (x : Nat × Int) :
    x ∈ (lnView y B).guardAt (fun _ => 4) (fun _ => 4 * n) σ L (sig.group L 0 t) ↔
      t < B' ∧ ∃ j < σ 5, t + B * j < n ∧ ∃ b < 4, x = sig.place y ↑(4 * (t + B * j) + b) := by
  obtain ⟨hg, hb, -, hB, -⟩ := ha
  show ((L.env t).sreg .ctaid .x = 0 ∧ ∃ c < (lnLay (σ 5) B).size,
      lnKey.val (lnBind L (0, t) σ) * 4 + (lnLay (σ 5) B).call (leaf c false) < 4 * n ∧
      x = sig.place y ↑(lnKey.val (lnBind L (0, t) σ) * 4 + (lnLay (σ 5) B).call (leaf c false)))
    ↔ _
  rw [ln_key, lnLay_size]
  constructor
  · rintro ⟨h0, c, hc, hn, rfl⟩
    obtain ⟨htB, hm⟩ := ln_block0 hg hb ht h0
    have e : (L.env t).sreg .tid .x * 4 + (lnLay (σ 5) B).call (leaf c false) =
        4 * (t + B * (c / 4)) + c % 4 := by
      rw [(ln_regs hg hb ht).1, hm, lnLay_call hc, Nat.mod_eq_of_lt (show c / 4 < σ 5 by omega)]
      ring
    rw [e] at hn ⊢
    exact ⟨hB ▸ htB, c / 4, by omega, by omega, c % 4, Nat.mod_lt _ (by decide), rfl⟩
  · rintro ⟨htB, j, hj, hn, b, hb4, rfl⟩
    rw [← hB] at htB
    have e : (L.env t).sreg .tid .x * 4 + (lnLay (σ 5) B).call (leaf (4 * j + b) false) =
        4 * (t + B * j) + b := by
      rw [(ln_regs hg hb ht).1, Nat.mod_eq_of_lt htB, lnLay_call (by omega),
        show (4 * j + b) % 4 = b by omega, show (4 * j + b) / 4 = j by omega,
        Nat.mod_eq_of_lt hj]
      ring
    refine ⟨by rw [(ln_regs hg hb ht).2]; exact Nat.div_eq_of_lt htB, 4 * j + b, by omega,
      by rw [e]; omega, by rw [e]⟩

/-- **At `B ∣ n` the guard drops nothing**: at MojoProof's `sig`, for every buffer `y` and block
size `B`, at every assignment and launch of the kernel of block size `B` (`lnAdm B`) and every
thread `t` below the thread count, the guarded tile under the bound `4 B X` (`n = B X`, `X` the
variable 5) is `ln_tile`'s tile (`View.guardAt_subset`, `View.tile_subset_guardAt`): every
offset `4 tid + b + 4 B j` of a thread is below `4 B X`, as `tid < B` and `j < X`. So `ln_wf`,
`ln_tile`, `ln_tiling`, `ln_cover` and their tests are the guarded view's case `B ∣ n`. -/
theorem ln_guard_dvd (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) :
    (lnView y B).guardAt (fun _ => 4) (fun _ => 4 * (B * σ 5)) σ L (sig.group L 0 t) =
      (lnView y B).tileAt (fun _ => 4) σ L (sig.group L 0 t) := by
  obtain ⟨hg, hb, -, hB, -⟩ := ha
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hpos : 0 < B := hB ▸ Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
  refine Set.Subset.antisymm ((lnView y B).guardAt_subset _ _ σ L _)
    ((lnView y B).tile_subset_guardAt fun c hc => ?_)
  change c < (lnLay (σ 5) B).size at hc
  rw [lnLay_size] at hc
  change lnKey.val (lnBind L (0, t) σ) * 4 + (lnLay (σ 5) B).call (leaf c false) < 4 * (B * σ 5)
  rw [ln_key, (ln_regs hg hb ht).1, lnLay_call hc, hB]
  have h1 : t % B < B := Nat.mod_lt _ hpos
  have h2 : c / 4 % σ 5 < σ 5 := Nat.mod_lt _ (by omega)
  have h3 : t % B + B * (c / 4 % σ 5) < B * σ 5 :=
    calc t % B + B * (c / 4 % σ 5) < B + B * (c / 4 % σ 5) := Nat.add_lt_add_right h1 _
      _ = B * (c / 4 % σ 5 + 1) := by ring
      _ ≤ B * σ 5 := Nat.mul_le_mul_left _ h2
  rw [show t % B * 4 + (c % 4 + c / 4 % σ 5 * (4 * B)) =
    4 * (t % B + B * (c / 4 % σ 5)) + c % 4 by ring]
  omega

/-- **Layer norm's guarded tiles are a tiling at the key stride 4 bytes**, at every row length:
at MojoProof's `sig`, for every buffer `y`, row length `n` and block size `B`, at every
assignment and launch of the kernel of block size `B` (`lnAdm B`), the tiles under the bound
`4 n` lie in the view's bytes at the key stride and two threads' are disjoint, as each lies in
its tile (`View.guardAt_subset`) and those tile (`ln_tiling`, `GPUProof.Tiling.mono`). -/
theorem ln_guard_tiling (y n : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) :
    Tiling ((lnView y B).guardsAt (fun _ => 4) (fun _ => 4 * n) σ L)
      ((lnView y B).bytesAt (fun _ => 4) σ) :=
  (ln_tiling y ha).mono fun g => (lnView y B).guardAt_subset _ _ σ L g.1

/-- **Layer norm's guarded tiles cover its row of `n` floats at the key stride 4 bytes**: at
MojoProof's `sig`, for every buffer `y`, row length `n` and block size `B`, at every assignment
and launch of the kernel of block size `B` (`lnAdm B`) with at least one block whose `X` (the
variable 5) has `n ≤ B X` (as `X = ⌈n / B⌉` has), each of the first `4 n` bytes of `y` is in a
thread's tile under the bound `4 n`: it is in a tile (`ln_cover`, the first `4 B X` bytes), and
the guard keeps it (`View.cover_guardAt` at `place_inj`). -/
theorem ln_guard_cover (y n : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L)
    (hG : 0 < L.grid .x) (hn : n ≤ B * σ 5) :
    {x | ∃ i : Nat, i < 4 * n ∧ x = sig.place y i} ⊆
      ⋃ g, (lnView y B).guardsAt (fun _ => 4) (fun _ => 4 * n) σ L g :=
  (lnView y B).cover_guardAt _ (fun _ => 4 * n) place_inj fun _ ⟨i, hi, hx⟩ =>
    ln_cover y ha hG ⟨i, by
      have h := Nat.mul_le_mul_left 4 hn
      rw [show B * 4 * σ 5 = 4 * (B * σ 5) by ring]
      omega, hx⟩

/-- **The guarded tiles are the loop's stores, for every row length and block size**: at
MojoProof's `sig`, for every buffer `y`, block size `B` and row length `n`, at every assignment
and launch of the kernel of block size `B` (`lnAdm B`), and every thread `t` below the thread
count with `n ≤ t + B X` when `t < B` (`hn`, `X` the variable 5; at `n ≤ B X`, as at
`X = ⌈n / B⌉`, it holds at every thread): the tile of `t` under the bound `4 n` is the bytes of
the floats `lnStores B n t` when `t` is in block 0, and no byte otherwise (`ln_guard_tile`,
`lnStores_eq`). `hn` is the condition under which `lnStores B n t` lists only floats `t + B j`,
`j < X` (`lnStores_eq`'s premise). `lnStores` is a model of the IR's loop. -/
theorem ln_guard_stores (y B n : Nat) {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) (hn : t < B → n ≤ t + B * σ 5)
    (x : Nat × Int) :
    x ∈ (lnView y B).guardAt (fun _ => 4) (fun _ => 4 * n) σ L (sig.group L 0 t) ↔
      t < B ∧ ∃ i ∈ lnStores B n t, ∃ b < 4, x = sig.place y ↑(4 * i + b) := by
  rw [ln_guard_tile y B n ha ht x]
  constructor
  · rintro ⟨htB, j, hj, hn', b, hb, rfl⟩
    rw [lnStores_eq (hn htB)]
    exact ⟨htB, t + B * j, List.mem_map.2 ⟨j, List.mem_filter.2 ⟨List.mem_range.2 hj,
      decide_eq_true hn'⟩, rfl⟩, b, hb, rfl⟩
  · rintro ⟨htB, i, hi, b, hb, rfl⟩
    rw [lnStores_eq (hn htB)] at hi
    obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hi
    obtain ⟨hj, hn⟩ := List.mem_filter.1 hj
    exact ⟨htB, j, List.mem_range.1 hj, of_decide_eq_true hn, b, hb, rfl⟩

/-- **Test: at `n = 300` and block size 128 the guarded tiles are the stores.** The kernel of
block size 128 (the IR's) at one block of 128 threads, a row of `n = 300` floats (`128 ∤ 300`) and
`X = 3 = ⌈300 / 128⌉`: for every thread `t < 128`, its tile at the key stride 4 under the bound
`4 · 300` is exactly the bytes of the floats the IR loop's model stores (`lnStores 128 300 t`),
`ln_guard_stores` at these sizes, whose premise `300 ≤ t + 128 · 3` holds at every thread. -/
theorem ln_guard_300 (y : Nat) :
    ∀ t < 128, ∀ x, x ∈ (lnView y 128).guardAt (fun _ => 4) (fun _ => 4 * 300)
        (asg [0, 0, 0, 0, 128, 3]) (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 t) ↔
      t < 128 ∧ ∃ i ∈ lnStores 128 300 t, ∃ b < 4, x = sig.place y ↑(4 * i + b) :=
  fun t ht => ln_guard_stores (σ := asg [0, 0, 0, 0, 128, 3]) (L := launch2 1 1 128 1) y 128 300
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (lt_of_lt_of_eq ht rfl)
    fun _ => Nat.le_trans (by decide : 300 ≤ 128 * 3) (Nat.le_add_left _ t)

/-- **Test: at `n = 170` and block size 64 the guarded tiles are the stores.** The kernel of block
size 64 (ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, the same loop at the step 64) at
two blocks of 64 threads, a row of `n = 170` floats (`64 ∤ 170`) and `X = 3 = ⌈170 / 64⌉`: for
every thread `t < 128`, its tile at the key stride 4 under the bound `4 · 170` is the bytes of
`lnStores 64 170 t` when `t` is in block 0, and no byte for the threads of block 1,
`ln_guard_stores` at these sizes, whose premise `170 ≤ t + 64 · 3` holds at every thread. -/
theorem ln_guard_170 (y : Nat) :
    ∀ t < 128, ∀ x, x ∈ (lnView y 64).guardAt (fun _ => 4) (fun _ => 4 * 170)
        (asg [0, 0, 0, 0, 64, 3]) (launch2 2 1 64 1) (sig.group (launch2 2 1 64 1) 0 t) ↔
      t < 64 ∧ ∃ i ∈ lnStores 64 170 t, ∃ b < 4, x = sig.place y ↑(4 * i + b) :=
  fun t ht => ln_guard_stores (σ := asg [0, 0, 0, 0, 64, 3]) (L := launch2 2 1 64 1) y 64 170
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (lt_of_lt_of_eq ht rfl)
    fun _ => Nat.le_trans (by decide : 170 ≤ 64 * 3) (Nat.le_add_left _ t)

/-- The floats of the tests' model, by evaluation: at block size 128 and `n = 300`, thread
`t < 128` stores `t`, `t + 128` and, for `t < 44`, `t + 256`; at block size 64 and `n = 170`,
thread `t < 64` stores `t`, `t + 64` and, for `t < 42`, `t + 128` (`lnStores`). -/
example : (∀ t < 128, lnStores 128 300 t =
      [t, t + 128] ++ if t < 44 then [t + 256] else []) ∧
    ∀ t < 64, lnStores 64 170 t = [t, t + 64] ++ if t < 42 then [t + 128] else [] := by
  decide +kernel

/-- **Mutant: the unguarded tile holds a byte no store writes.** The kernel of block size 128 at
one block of 128 threads, `n = 300` and `X = 3` (as `ln_guard_300`): byte 1532 of `y`, the first
byte of float `383 = 127 + 128 · 2`, is in thread 127's tile at the key stride 4 without the guard
(`ln_tile`), while no thread's stores (`lnStores 128 300 t`, all below 300 by evaluation) write
it. -/
theorem ln_unguarded_300 (y : Nat) :
    sig.place y 1532 ∈ (lnView y 128).tileAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 3])
        (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 127) ∧
      ∀ t < 128, ∀ i ∈ lnStores 128 300 t, ∀ b < 4,
        sig.place y 1532 ≠ sig.place y ↑(4 * i + b) := by
  have hl : ∀ t < 128, ∀ i ∈ lnStores 128 300 t, i < 300 := by decide +kernel
  refine ⟨(ln_tile y 128 ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (by decide) _).2
    ⟨by decide, 2, by decide, 0, by decide, rfl⟩, fun t ht i hi b hb he => ?_⟩
  have e := (place_inj he).2
  have := hl t ht i hi
  omega

/-! ## No more threads than columns: separated, not always interleaved -/

/-- **No more threads than columns are separated at the key stride 4.** At MojoProof's `sig`, for
every buffer `y`, column count `C` and block size `B ≤ C`, at every assignment and launch of the
kernel of block size `B` (`lnAdm B`): the view `lnView y C`, whose thread `t` owns the floats
`t + C j` (column `t` of a row-major matrix of `C` float columns and `X` rows), is separated at
the key stride 4 (`View.Separated`). Two offsets `b + 4 C i` and `b' + 4 C i'` (`b, b' < 4`) that
differ by `4 m` with `0 < m < B` have `C i = C i' + m`, which no `m < C` allows. -/
theorem ln_separated (y : Nat) {B C : Nat} (hBC : B ≤ C) {σ : Sizes} {L : Launch}
    (ha : lnAdm B σ L) : (lnView y C).Separated (fun _ => 4) σ := by
  obtain ⟨-, -, h4, hB, -⟩ := ha
  intro c hc c' hc' m hm hmR he
  have hR : lnKey.radixProd σ = B := by
    simp [lnKey, MixedRadix.radixProd, SizeExpr.eval, h4, hB]
  change m < lnKey.radixProd σ at hmR
  change c < (lnLay (σ 5) C).size at hc
  change c' < (lnLay (σ 5) C).size at hc'
  change (lnLay (σ 5) C).call (leaf c false) = (lnLay (σ 5) C).call (leaf c' false) + m * 4 at he
  rw [hR] at hmR
  rw [lnLay_size] at hc hc'
  rw [lnLay_call hc, lnLay_call hc',
    show c / 4 % σ 5 * (4 * C) = 4 * (c / 4 % σ 5 * C) by ring,
    show c' / 4 % σ 5 * (4 * C) = 4 * (c' / 4 % σ 5 * C) by ring] at he
  have hX : c / 4 % σ 5 * C = c' / 4 % σ 5 * C + m := by omega
  rcases Nat.lt_or_ge (c' / 4 % σ 5) (c / 4 % σ 5) with h | h
  · have h' : (c' / 4 % σ 5 + 1) * C ≤ c / 4 % σ 5 * C := Nat.mul_le_mul_right C h
    rw [Nat.add_mul, Nat.one_mul] at h'
    omega
  · have h' : c / 4 % σ 5 * C ≤ c' / 4 % σ 5 * C := Nat.mul_le_mul_right C h
    omega

/-- **No more threads than columns tile at the key stride 4.** At MojoProof's `sig`, for every
buffer `y`, column count `C` and block size `B ≤ C`, at every assignment and launch of the kernel
of block size `B` (`lnAdm B`): the tiles of `lnView y C` at the key stride 4 are a tiling, by
`View.tiling_separated` at `place_inj`, `ln_wf` and `ln_separated`, so not by interleaving: the
layout can fail to interleave at 4 (`ln_cols_not_interleaved`, at `B = 2`, `C = 3` and
`X = 2`). -/
theorem ln_tiling_cols (y : Nat) {B C : Nat} (hBC : B ≤ C) {σ : Sizes} {L : Launch}
    (ha : lnAdm B σ L) :
    Tiling ((lnView y C).tilesAt (fun _ => 4) σ L) ((lnView y C).bytesAt (fun _ => 4) σ) :=
  View.tiling_separated _ _ place_inj (ln_wf y C B σ L ha) (ln_separated y hBC ha)

/-- **Two threads owning two of three float columns tile, and do not interleave.** The view
`lnView y 3` at one block of 2 threads and `X = 2` rows: thread `j < 2` owns the bytes
`4 j + 12 i + b`. Its tiles at the key stride 4 are a tiling (`ln_tiling_cols`), while the
layout does not interleave at 4 (`View.Interleaved`): coordinate 4, the first byte of a thread's
second row, has the offset 12, which modulo `2 · 4` is 4, not below 4. -/
theorem ln_cols_not_interleaved (y : Nat) :
    Tiling ((lnView y 3).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 1))
        ((lnView y 3).bytesAt (fun _ => 4) (asg [0, 0, 0, 0, 2, 2])) ∧
      ¬ (lnView y 3).Interleaved (fun _ => 4) (asg [0, 0, 0, 0, 2, 2]) := by
  have ha : lnAdm 2 (asg [0, 0, 0, 0, 2, 2]) (launch2 1 1 2 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  refine ⟨ln_tiling_cols y (by decide) ha, fun h => ?_⟩
  have h4 : (lnLay 2 3).call (leaf 4 false) %
      (lnKey.radixProd (asg [0, 0, 0, 0, 2, 2]) * 4) < 4 :=
    h 4 (by rw [show (lnView y 3).lay (asg [0, 0, 0, 0, 2, 2]) = lnLay 2 3 from rfl,
      lnLay_size]; decide)
  rw [lnLay_call (by decide)] at h4
  exact absurd h4 (by decide)

/-- **Mutant: more threads than columns are not separated, so their tiles meet.** The view of the
kernel of block size 64 at one block of 128 threads and `X = 2` (as `ln_stride64`): the offset
256 of coordinate 4 is the offset 0 of coordinate 0 plus `64 · 4`, with `64` below the radix
product 128, so the layout is not separated at the key stride 4; as every key value below 128
is an owner's (`ln_owners`), the tiles are not pairwise disjoint (`View.separated_of_disjoint`),
a second route to `ln_stride64`'s last conjunct. -/
theorem ln_stride64_not_separated (y : Nat) :
    ¬ (lnView y 64).Separated (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) ∧
      ¬ Pairwise fun i j =>
        Disjoint
          ((lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) i)
          ((lnView y 64).tilesAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1)
            j) := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 2]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have hs : ¬ (lnView y 64).Separated (fun _ => 4) (asg [0, 0, 0, 0, 128, 2]) := fun h => by
    have hz : ((lnView y 64).lay (asg [0, 0, 0, 0, 128, 2])).size = 8 := lnLay_size 2 64
    refine h 4 (by rw [hz]; decide) 0 (by rw [hz]; decide) 64 (by decide)
      (show 64 < lnKey.radixProd (asg [0, 0, 0, 0, 128, 2]) by decide) ?_
    change (lnLay 2 64).call (leaf 4 false) = (lnLay 2 64).call (leaf 0 false) + 64 * 4
    rw [lnLay_call (c := 4) (by decide), lnLay_call (c := 0) (by decide)]
  exact ⟨hs, fun hd => hs (View.separated_of_disjoint _ _ (ln_owners y 64 ha (by decide)) hd)⟩

/-! ## Coarsening at the key stride: a key of two digits -/

/-- The key of a thread of a grid-stride loop: the digit `tid.x` (the variable 0) with radix the
variable 4, the block size, then the digit `ctaid.x` (the variable 1) with radix the variable 6,
the grid size; its value is the thread's index in the grid, `tid.x + ntid.x · ctaid.x`. -/
def gsKey : MixedRadix := ⟨[(.var 0, .var 4), (.var 1, .var 6)]⟩

/-- A grid-stride loop's output in buffer `y`, at the thread level (level 0) of `sig`, for every
stride `T` and owners `own`: the layout of one thread's `X` floats at stride `T` floats (`lnLay`,
`X` the variable 5), the key `gsKey` bound by `MojoProofTest.GPUProof.View.gemvBind` (at a
thread, its own `tid.x` and `ctaid.x`), and the threads that `own` names owning a tile. At `T` the
thread count, thread `t` of the grid holds the floats `t + T j`, `j < X`. -/
def gsView (y T : Nat) (own : Launch → Fin 4 × Nat → Sizes → Prop) : View sig where
  lay σ := lnLay (σ 5) T
  level := (0 : Fin 4)
  buf := y
  key := gsKey
  bind := gemvBind
  owns := own

/-- The size assignment of the coarsening tests: block size 2 (the variable 4), 2 floats a thread
(the variable 5) and grid size 2 (the variable 6). -/
def gsAsg : Sizes := asg [0, 0, 0, 0, 2, 2, 2]

/-- The launch of the coarsening tests: 2 blocks of 2 threads. -/
def gsLaunch : Launch := launch2 2 1 2 1

/-- **The grid-stride view is well formed at `gsAsg` and `gsLaunch`**, for every buffer, stride
and owners: at each of the 4 threads (`inst_sig`) the digits `tid.x` and `ctaid.x` are below
their radices 2, the radices read no variable `gemvBind` sets, and two threads with the same
digits are one, each by evaluation over the threads (`decide`). -/
theorem gs_wf (y T : Nat) (own : Launch → Fin 4 × Nat → Sizes → Prop) :
    (gsView y T own).WF gsAsg gsLaunch where
  congruent := Lay.flat_congruent _
  pos s hs := by
    simp [gsView, lnLay, Lay.flat, leavesL, leaves] at hs
    rcases hs with rfl | rfl <;> decide
  range g hg := by
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    clear hg
    change t < 4 at ht
    show gsKey.InRange (gemvBind gsLaunch (0, t) gsAsg)
    revert t
    decide
  radices g _ := by simp [gsView, gsKey, gemvBind, SizeExpr.eval]
  key_inj g g' hg hg' he := by
    obtain ⟨t, ht, rfl⟩ := inst_sig.1 hg.1
    obtain ⟨t', ht', rfl⟩ := inst_sig.1 hg'.1
    clear hg hg'
    change t < 4 at ht
    change t' < 4 at ht'
    change gsKey.digitVals (gemvBind gsLaunch (0, t) gsAsg) =
      gsKey.digitVals (gemvBind gsLaunch (0, t') gsAsg) at he
    show ((0 : Fin 4), t) = (0, t')
    revert t
    revert t'
    decide

/-- **The threads of a block agree on the outer digit.** For every buffer, stride, owners and
block `b < 2` of `gsLaunch`: the key's digit after `tid.x`, `ctaid.x`, is `b` at every thread
inside block `b` (level 2), the value `MojoProofTest.GPUProof.View.gemvBlock` binds at block `b`,
by evaluation over the threads; this is `View.coarsenAt_tile`'s premise `hn`. -/
theorem gs_hn (y T : Nat) (own : Launch → Fin 4 × Nat → Sizes → Prop) (b : Nat) (hb : b < 2) :
    ∀ j, (gsView y T own).Inside gsLaunch 2 (2, b) j → (gsView y T own).owns gsLaunch j gsAsg →
      ((gsView y T own).outer 1).val ((gsView y T own).bind gsLaunch j gsAsg) =
        ((gsView y T own).outer 1).val (gemvBlock gsLaunch (2, b) gsAsg) := by
  rintro j ⟨t, ht, rfl, hi⟩ -
  have ht' : t < 4 := List.mem_range.1 ht
  have hi' : t / 2 = b := congrArg Prod.snd hi
  clear ht hi
  show (MixedRadix.mk (gsKey.digits.drop 1)).val (gemvBind gsLaunch (0, t) gsAsg) =
    (MixedRadix.mk (gsKey.digits.drop 1)).val (gemvBlock gsLaunch (2, b) gsAsg)
  subst hi'
  revert t
  decide

/-- **The coarse tile at the key stride 8 is the union of its threads' tiles.** At every buffer
`y`: the grid-stride view of stride 4 floats with every thread an owner, at `gsAsg` and
`gsLaunch`, coarsened to the block level (level 2) at the key stride 4 bytes, its digit `tid.x`
one more layout mode (`View.coarsenAt` at `n = 1` and `gemvBlock`), has at block 1 the tile at
the key stride `2 · 4 = 8` (the inner radix 2 times 4) that is the union of the tiles at 4 of
the threads inside block 1, threads 2 and 3 with the floats 2, 6 and 3, 7 of `y`
(`View.coarsenAt_tile` at `gs_wf` and `gs_hn`; its premise `ho`: threads 2 and 3 have `tid.x` 0
and 1, by evaluation). The key stride 4 is not the layout's cosize, 20 bytes, as a thread's two
floats are 16 bytes apart. -/
theorem gs_coarsen (y : Nat) :
    ((gsView y 4 fun _ _ _ => True).coarsenAt (fun _ => 4) 2 1 gemvBlock).tileAt (fun _ => 8)
        gsAsg gsLaunch (2, 1) =
      ⋃ j ∈ {j | (gsView y 4 fun _ _ _ => True).Inside gsLaunch 2 (2, 1) j},
        (gsView y 4 fun _ _ _ => True).tileAt (fun _ => 4) gsAsg gsLaunch j := by
  refine View.coarsenAt_tile _ (fun _ => 4) 1 gemvBlock (gs_wf y 4 _) (gs_hn y 4 _ 1 (by decide))
    fun k hk => ?_
  change k < 2 at hk
  refine ⟨(0, 2 + k), ⟨2 + k, List.mem_range.2 (by change 2 + k < 4; omega), rfl, ?_⟩, trivial,
    ?_⟩
  · show ((2 : Fin 4), (2 + k) / 2) = (2, 1)
    interval_cases k <;> rfl
  · show (MixedRadix.mk (gsKey.digits.take 1)).val (gemvBind gsLaunch (0, 2 + k) gsAsg) = k
    interval_cases k <;> rfl

/-- The grid-stride view of stride 4 floats at every buffer `y` whose owners are the threads with
`tid.x ≠ 1`: the second thread of each block owns no tile. -/
def gsGap (y : Nat) : View sig := gsView y 4 fun L g _ => (L.env g.2).sreg .tid .x ≠ 1

/-- **Mutant: an owner missing at an inner key value.** At every buffer `y`, `gsGap y` at
`gsAsg` and `gsLaunch`, coarsened as in `gs_coarsen`: the tiles at the key stride 4 of the
threads inside block 1 lie in its coarse tile at 8 (`View.tile_subset_coarsenAt` at `gs_wf` and
`gs_hn`); no owner inside block 1 has `tid.x` 1, so `View.coarsenAt_tile`'s premise `ho` fails at
the inner key value 1; byte 12 of `y`, the first byte of float 3 (thread 3's, which owns no
tile), is the offset of the coarse coordinate 8, and in no owner's tile inside block 1 (thread 2
holds bytes 8 to 11 and 24 to 27), by evaluation; so the coarse tile is not the union of the
tiles inside it. -/
theorem gs_gap (y : Nat) :
    ⋃ j ∈ {j | (gsGap y).Inside gsLaunch 2 (2, 1) j},
        (gsGap y).tileAt (fun _ => 4) gsAsg gsLaunch j ⊆
      ((gsGap y).coarsenAt (fun _ => 4) 2 1 gemvBlock).tileAt (fun _ => 8) gsAsg gsLaunch
        (2, 1) ∧
    (¬ ∃ j, (gsGap y).Inside gsLaunch 2 (2, 1) j ∧ (gsGap y).owns gsLaunch j gsAsg ∧
      ((gsGap y).inner 1).val ((gsGap y).bind gsLaunch j gsAsg) = 1) ∧
    sig.place y 12 ∈ ((gsGap y).coarsenAt (fun _ => 4) 2 1 gemvBlock).tileAt (fun _ => 8)
      gsAsg gsLaunch (2, 1) ∧
    sig.place y 12 ∉ ⋃ j ∈ {j | (gsGap y).Inside gsLaunch 2 (2, 1) j},
      (gsGap y).tileAt (fun _ => 4) gsAsg gsLaunch j ∧
    ((gsGap y).coarsenAt (fun _ => 4) 2 1 gemvBlock).tileAt (fun _ => 8) gsAsg gsLaunch (2, 1) ≠
      ⋃ j ∈ {j | (gsGap y).Inside gsLaunch 2 (2, 1) j},
        (gsGap y).tileAt (fun _ => 4) gsAsg gsLaunch j := by
  have hin : sig.place y 12 ∈ ((gsGap y).coarsenAt (fun _ => 4) 2 1 gemvBlock).tileAt
      (fun _ => 8) gsAsg gsLaunch (2, 1) := by
    have hs : (((gsGap y).coarsenAt (fun _ => 4) 2 1 gemvBlock).lay gsAsg).size = 16 := rfl
    refine ⟨⟨(0, 2), ⟨2, List.mem_range.2 (by decide), rfl, rfl⟩,
      (by decide : (gsLaunch.env 2).sreg .tid .x ≠ 1)⟩, 8, by omega, ?_⟩
    rfl
  have hout : sig.place y 12 ∉ ⋃ j ∈ {j | (gsGap y).Inside gsLaunch 2 (2, 1) j},
      (gsGap y).tileAt (fun _ => 4) gsAsg gsLaunch j := by
    intro hx
    simp only [Set.mem_iUnion] at hx
    obtain ⟨j, ⟨t, ht, rfl, hi⟩, ho, c, hc, he⟩ := hx
    have ht' : t < 4 := List.mem_range.1 ht
    have hi' : t / 2 = 1 := congrArg Prod.snd hi
    change (gsLaunch.env t).sreg .tid .x ≠ 1 at ho
    change c < (lnLay 2 4).size at hc
    have e := (place_inj he).2
    change (12 : Int) = ↑(gsKey.val (gemvBind gsLaunch (0, t) gsAsg) * 4 + (lnLay 2 4).call
      (leaf c false)) at e
    rw [lnLay_size] at hc
    rw [lnLay_call hc] at e
    clear ht hi he
    revert t
    revert c
    decide
  refine ⟨View.tile_subset_coarsenAt (gsGap y) (fun _ => 4) 1 gemvBlock (gs_wf y 4 _)
    (gs_hn y 4 _ 1 (by decide)), ?_, hin, hout, fun he => hout (he ▸ hin)⟩
  rintro ⟨j, ⟨t, ht, rfl, hi⟩, ho, hk⟩
  have ht' : t < 4 := List.mem_range.1 ht
  have hi' : t / 2 = 1 := congrArg Prod.snd hi
  change (gsLaunch.env t).sreg .tid .x ≠ 1 at ho
  change (MixedRadix.mk (gsKey.digits.take 1)).val (gemvBind gsLaunch (0, t) gsAsg) = 1 at hk
  clear ht hi
  revert t
  decide

end MojoProofTest.GPUProof.ViewStride
