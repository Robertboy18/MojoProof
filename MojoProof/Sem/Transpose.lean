import MojoProof.Sem.Trace
import MojoProof.Sem.WarpDot
import MojoProof.Sem.Index

/-!
# The transposition through shared memory

gevm_kernel (tests/corpus/gemv/) moves each thread's loop sum through a shared array of 1024
floats: before the barrier, thread `t = 32 w + l` (warp `w = t / 32`, lane `l = t % 32`) stores
its sum to cell `32 l + w`; after it, thread `t` loads cell `t`, and each warp reduces the 32
values its lanes loaded with five butterfly rounds. docs/proofs/warp-dot.md, "The transposition
through shared memory", has the informal argument. Proved here:

- `tpose n t = n (t % n) + t / n`, the transposed position of `t` in an `n × n` square stored by
  rows, for every `n`: it maps `[0, n * n)` into itself (`tpose_lt`) and is an involution there
  (`tpose_tpose`), so a bijection of `[0, n * n)` onto itself (`tpose_bijOn`).
- `Launch.tpose_env`, for every valid launch with `ntid.x = 1024` and every thread number `k`:
  the block has 1024 threads, `tid.x` is `k % 1024`, the lane number is `k % 32`, and the cell
  `32 · laneid + tid.x / 32` the kernel stores to is `tpose 32 (k % 1024)`.
- `Tiling.tpose n w β`, for every `n > 0`, cell width `w` and block of threads `β`: the cells of
  `w` bytes at `tpose n (k % (n * n)) * w` of the threads `k` of `β` (those with
  `k / (n * n) = β`), and empty tiles for the other threads, are a tiling.
- `racy_tpose`, for every trace: if every access to block `β`'s shared array is by a thread of
  `β`, is in phase 0 the `w` bytes of its cell `tpose n (k % (n * n))`, and after the barrier a
  read, and every access to any other block follows one ownership discipline `G` with the
  thread's own tile (`Owned G id`), the trace has no race. It is `racy_eq_false_of_phased` at the
  discipline `Tiling.tpose` in phase 0, untiled in the later phases, and `G` elsewhere.
- `warpDot_tpose`, for every format, flag, oracle family, family of pair lists `P` by lane and
  content `M` of the array: if every thread `t < 1024` stored at cell `tpose 32 t` the loop sum
  of list `t / 32` of the strided split of `P (t % 32)`, then for every warp `w < 32` the rounds
  of `Model.add` over the cells `32 w + l` give lane 0 the value of the same rounds over the loop
  sums of the lists `l` of `P w`, which is `warpDot c (fun l => o (32 l + w)) (P w)` by
  definition. With `P l = vecMatPairs v A (32 β + l)`, warp `w`'s value is `warpDot` of column
  `32 β + w`'s pairs, so `warpDot_vecMat` bounds it.

That a grid run of gevm_kernel stores and loads these cells, and that its trace meets the premises
of `racy_tpose`, is not proved. The instances (one thread, one trace, one column) are in
MojoProofTest/Transpose.lean.
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- The transposed position of `t` in an `n × n` square stored by rows: `t = n q + r` with
`q = t / n` and `r = t % n` goes to `n r + q`. -/
def tpose (n t : Nat) : Nat := n * (t % n) + t / n

/-- For every `n` and `t < n * n`, `tpose n t < n * n`. -/
theorem tpose_lt {n t : Nat} (h : t < n * n) : tpose n t < n * n := by
  have hn : 0 < n := Nat.pos_of_ne_zero fun h0 => by simp [h0] at h
  have hq : t / n < n := Nat.div_lt_of_lt_mul h
  have hr := Nat.mul_le_mul_left n (Nat.succ_le_of_lt (Nat.mod_lt t hn))
  rw [Nat.mul_succ] at hr
  unfold tpose
  omega

/-- **The transposition is an involution.** For every `n` and `t < n * n`,
`tpose n (tpose n t) = t`. -/
theorem tpose_tpose {n t : Nat} (h : t < n * n) : tpose n (tpose n t) = t := by
  have hn : 0 < n := Nat.pos_of_ne_zero fun h0 => by simp [h0] at h
  have hq : t / n < n := Nat.div_lt_of_lt_mul h
  unfold tpose
  rw [Nat.mul_add_mod, Nat.mod_eq_of_lt hq, Nat.mul_add_div hn, Nat.div_eq_of_lt hq,
    Nat.add_zero]
  exact Nat.div_add_mod t n

/-- **The transposition is a bijection of `[0, n * n)`**, for every `n`: its own inverse there
(`tpose_tpose`), into the interval (`tpose_lt`). -/
theorem tpose_bijOn (n : Nat) : Set.BijOn (tpose n) (Set.Iio (n * n)) (Set.Iio (n * n)) :=
  Set.InvOn.bijOn ⟨fun _ h => tpose_tpose h, fun _ h => tpose_tpose h⟩ (fun _ h => tpose_lt h)
    fun _ h => tpose_lt h

/-- **gevm_kernel's store cell on every launch of 1024 threads per block.** For every valid launch
with `ntid.x = 1024` and every thread number `k`, of every block: the block has 1024 threads,
`tid.x` is `k % 1024`, the lane number is `k % 32`, and `32 · laneid + tid.x / 32` (the kernel's
`%62`, lane times 32 plus warp) is `tpose 32 (k % 1024)`. -/
theorem Launch.tpose_env {L : Launch} (h : L.Valid) (hx : L.block .x = 1024) (k : Nat) :
    volume L.block = 1024 ∧ (L.env k).sreg .tid .x = k % 1024 ∧ (L.env k).laneid = k % 32 ∧
      32 * (L.env k).laneid + (L.env k).sreg .tid .x / 32 = tpose 32 (k % 1024) := by
  have hv : volume L.block = 1024 := by
    have h1 := h.threads
    have hp := Nat.mul_pos (h.block_pos .y) (h.block_pos .z)
    simp only [volume, hx, Nat.mul_assoc] at h1 ⊢
    generalize L.block .y * L.block .z = a at h1 hp ⊢
    omega
  have ht : (L.env k).sreg .tid .x = k % 1024 := by
    simp only [Launch.env, coord, hv, hx, Nat.mod_mod]
  have hl : (L.env k).laneid = k % 32 := by
    simp only [Launch.env, hv]
    exact Nat.mod_mod_of_dvd k (by decide)
  refine ⟨hv, ht, hl, ?_⟩
  rw [ht, hl, tpose, Nat.mod_mod_of_dvd k (by decide : 32 ∣ 1024)]

/-- **The tiling of a block of threads' transposed cells.** For every `n > 0`, cell width `w` and
block of threads `β`: thread `k` of `β` (`k / (n * n) = β`) has the `w` bytes at
`tpose n (k % (n * n)) * w`, every other thread the empty tile at 0, inside `n * n * w` bytes.
Distinct threads of `β` have distinct cells (`tpose_tpose`), so their tiles are apart
(`stride_lt`). -/
def Tiling.tpose (n w β : Nat) (hn : 0 < n) : Tiling Nat where
  off k := if k / (n * n) = β then Sem.tpose n (k % (n * n)) * w else 0
  len k := if k / (n * n) = β then w else 0
  ext := n * n * w
  inb k := by
    by_cases hk : k / (n * n) = β
    · simp only [hk, ↓reduceIte]
      exact stride_lt w (tpose_lt (Nat.mod_lt k (Nat.mul_pos hn hn)))
    · simp only [hk, ↓reduceIte]
      omega
  disj i j hij := by
    by_cases hi : i / (n * n) = β
    swap
    · simp only [hi, ↓reduceIte]
      omega
    by_cases hj : j / (n * n) = β
    swap
    · simp only [hj, ↓reduceIte]
      omega
    simp only [hi, hj, ↓reduceIte]
    have hr : i % (n * n) ≠ j % (n * n) := fun e => hij (by
      rw [← Nat.div_add_mod i (n * n), ← Nat.div_add_mod j (n * n), hi, hj, e])
    have hp := Nat.mul_pos hn hn
    have hne : Sem.tpose n (i % (n * n)) ≠ Sem.tpose n (j % (n * n)) := fun e => hr (by
      rw [← tpose_tpose (Nat.mod_lt i hp), e, tpose_tpose (Nat.mod_lt j hp)])
    rcases Nat.lt_or_gt_of_ne hne with h | h
    · exact .inl (stride_lt w h)
    · exact .inr (stride_lt w h)

/-- **The transposition through shared memory has no race** (`racy`, every trace). For every
`n > 0`, cell width `w`, map `ofSh` from a memory block to the block of threads whose shared array
it is (`none` for other blocks), and discipline `G` (`Owned`) of the other blocks: if every
access `x` (with its phase, `phases`) to block `β`'s shared array is by a thread `k` of `β`
(`x.who.cta = β` and `k / (n * n) = β`), in phase 0 is the `w` bytes at
`tpose n (k % (n * n)) * w`, and in later phases is a read, and every access to another block
follows `G` with each thread its own tile, the trace has no race. `racy_eq_false_of_phased` at the
discipline `Tiling.tpose` in phase 0, untiled after the barrier, `G` elsewhere, and `own := id`.
At `n = 32` and `w = 4` it is gevm_kernel's discipline on every launch with `ntid.x = 1024`, at
every block of threads (`Launch.tpose_env`: the block of thread `k` is `k / 1024`). -/
theorem racy_tpose {tr : List Event} {n w : Nat} (hn : 0 < n) {ofSh : Nat → Option Nat}
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / (n * n) = β ∧
        (x.2 = 0 → x.1.ptr.off = ((tpose n (x.1.who.thread % (n * n)) * w : Nat) : Int) ∧
          x.1.len = w) ∧ (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    racy tr = false := by
  refine racy_eq_false_of_phased (own := fun _ => id)
    (T := fun p b => match ofSh b with
      | some β => if p = 0 then some (Tiling.tpose n w β hn) else none
      | none => G b) (fun x hx => ?_) (fun x hx y hy hc hb => ?_) fun _ _ _ _ _ _ _ ho => ho
  · cases hb : ofSh x.1.ptr.block with
    | none => exact (hG x hx hb).congr (by simp only [hb]) rfl
    | some β =>
      obtain ⟨-, hk, h0, h1⟩ := hS x hx β hb
      by_cases hp : x.2 = 0
      · obtain ⟨ho, hl⟩ := h0 hp
        refine ⟨fun h => by simp [hb, hp] at h, fun t ht => ?_⟩
        simp only [hb, hp, ↓reduceIte, Option.some.injEq] at ht
        subst ht
        simp only [Tiling.tpose, id, hk, ↓reduceIte, ho, hl]
        omega
      · exact ⟨fun _ => h1 hp, fun t ht => by simp [hb, hp] at ht⟩
  · cases e : ofSh x.1.ptr.block with
    | none => rfl
    | some β =>
      exact absurd ((hS x hx β e).1.trans (hS y hy β (hb ▸ e)).1.symm) hc

/-- **The transposition gives each warp its column's strided sums.** For every format, flag `c`,
oracle family `o` by thread, family `P` of pair lists by lane, and content `M` of the shared
array: if every thread `t < 1024` stored at cell `tpose 32 t` its loop sum
`dotLoop c (o t) (+0) (stride 32 (t / 32) (P (t % 32)))` (list `t / 32`, its warp, of its lane's
pairs), then for every warp `w < 32`, lane 0's value after the rounds of `Model.add` at
`warpOffsets` over the cells `32 w + l` the lanes load is the value of the same rounds over the
loop sums `dotLoop c (o (32 l + w)) (+0) (stride 32 l (P w))`, which is
`warpDot c (fun l => o (32 l + w)) (P w)` by definition: lane `l` loads the sum of thread
`32 l + w` (`tpose_tpose`), list `l` of `P w`, and only the lanes below 32 are leaves
(`leaves_warp`, `bflyRounds_congr`). With `P l` the pairs
`vecMatPairs v A (32 β + l)` of column `32 β + l`, it is `warpDot` of column `32 β + w`'s pairs,
which `warpDot_vecMat` bounds: gevm_kernel's column total at every block `β` of every launch with
`ntid.x = 1024`, once its threads' sums are these. -/
theorem warpDot_tpose {fmt : FloatFormat} (c : Bool) (o : Nat → Nat → Nat × Nat)
    (P : Nat → List (Model fmt × Model fmt)) {M : Nat → Model fmt}
    (hM : ∀ t < 1024,
      M (tpose 32 t) = dotLoop c (o t) (Model.zero fmt false) (stride 32 (t / 32) (P (t % 32))))
    {w : Nat} (hw : w < 32) :
    bflyRounds (fun x y => Model.add x y) warpOffsets (fun l => M (32 * w + l)) 0 =
      bflyRounds (fun x y => Model.add x y) warpOffsets
        (fun l => dotLoop c (o (32 * l + w)) (Model.zero fmt false) (stride 32 l (P w))) 0 := by
  refine bflyRounds_congr _ _ 0 fun l hl => ?_
  have hl : l < 32 := List.mem_range.1 ((leaves_warp 0 (by decide)).mem_iff.1 hl)
  have e := hM (32 * l + w) (by omega)
  rwa [show tpose 32 (32 * l + w) = 32 * w + l by unfold tpose; omega,
    show (32 * l + w) / 32 = l by omega, show (32 * l + w) % 32 = w by omega] at e

end MojoProof.Sem
