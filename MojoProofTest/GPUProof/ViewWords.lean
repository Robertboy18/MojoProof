import MojoProof.Sym.OblLemmas
import MojoProofTest.GPUProof.View
import MojoProofTest.GPUProof.ViewStride

/-!
# The views' offsets as the kernels' words

The tile theorems of MojoProofTest/GPUProof/View.lean (`gemv_tile`, `naive_tile`) are
natural-number models: a tile's bytes are the key value times the cosize plus a layout offset,
with no width. The kernels compute that offset in 32- and 64-bit words, which wrap. This module
relates the two through the semantics' own operations (`intCast`, `intBin`, `icmpV`, `gep`) under
a word premise that keeps every word in its signed range: the key's radix product below
`2 ^ (w - 1)` (`GPUProof.View.key_fits` states it for every view and width, through
`GPUProof.MixedRadix.fits`), at `w = 32` for the corpus kernels' 32-bit words. The theorems
start from the 64-bit word of a thread's index `Launch.index t d`, which the IR reads from `tid`,
`ctaid` and `ntid` and computes with `zext`, `sext`, `mul` and `add` (gemv's :13-20, the naive
matmul's :18-25 and :29-36, in the files below): at every valid launch those words are
`MojoProof.Sem.Launch.index_ops`'s.
That a run of the kernel reaches the store with these words, and stores at this pointer, is not
proved here.

* `icmp_bits`, `icmp_sge`, `sge_sext` and `rowMajor_words`, for every width: `icmp` of two words
  of its width is its predicate on them; `icmp sge` of two words whose doubles fit is `≤` of their
  numbers, after a `sext` when the first fits its narrower width; and
  `trunc`, `mul`, `add` and `sext` of a row-major index `r · s + k`, `r < m` and `k < s`, give
  its word, at every flags value, when `m · s < 2 ^ (w - 1)`.
* `naive_words`, `naive_guards` and `naive_gep`: the naive matmul at every row stride `N`
  (tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll at
  `N = 50257`), at every assignment with `n = N` and `m · N < 2 ^ 31` (the word premise of its
  key `entryIdx 0 1`): the words of :26, :28, :37, :39 and :40 give the 64-bit word of
  `row · N + col`, the guards :42-43 are both false exactly when the thread owns its tile, and the
  `getelementptr` of :41 by that word is the pointer to the tile's first byte.
* `gemv_words` and `gemv_gep`: gemv
  (tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll) at
  every admissible assignment and valid launch with `m < 2 ^ 31`: the `udiv` of :21 gives the row,
  the `sext` of :11 keeps `m`, the guard :55 is false exactly when the warp owns its tile, and the
  `getelementptr` of :50 by the row is the pointer to the tile's first byte.
* `ln_offAt`, `ln_tid_lt`, `ln_words`, `ln_gep` and `ln_second`: layer norm's loop
  (tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, block size 128)
  at every block size `B`, row length `n`, thread and step `j < X`, at every admissible assignment
  and valid launch with `8 B X < 2 ^ 64` and `2 n < 2 ^ 64`: from the loop index's word `B j` and
  the 32-bit word of `tid.x`, the words of :32 and :699 give the 64-bit word of `B j + tid`, whose
  float's bytes are at the offsets `View.offAt` gives coordinates `4 j + b` at the key stride 4,
  the guard :708 is the boolean `B j + tid < n` (the guarded tile's bound `4 n`), the exit test
  :684 is `n ≤ B j`, the step :681 is the word of `B j + B` and its overflow test :682 is false,
  the `getelementptr` of :700 is the pointer to the float's first byte, and the second test of
  the bound (the `sub`, `llvm.smin` and `icmp eq` of :704-707, on which :712 branches to the
  store :722) is the guard's boolean. These are the semantics' operations at symbolic words, not
  an evaluation, and not a run theorem: that the index at step `j` is the word of `B j` and that
  a run reaches these words and stores there are not proved.
* The premises' instances: the `example`s after each, with the `getelementptr`s into `oneBuf`, a
  memory of one buffer, at the default layout (64-bit pointers, 4-byte floats).
* The mutants at the launches where the premise fails (`gemv_wrap`, `naive_wrap`, `ln_wrap`):
  gemv at one block of 32 threads and `m = 2 ^ 31` skips row 0's store, which its view owns; the
  naive kernel at `N = 50257`, grid `(2 ^ 20 + 1, 1, 1)` and block `(1, 1, 1)` computes the word
  `1105 · 2 ^ 20` at row `2 ^ 20`, whose byte is not in that row's tile; layer norm at one block
  of 128 threads and `n = 2 ^ 63` skips the store of float 0, whose bytes are in thread 0's
  guarded tile, at both tests. `naive_edge`: at `N = 0` the premise holds at every `m`, and the
  row guard alone is true at `m = 2 ^ 31`, while the thread owns no tile.
-/

namespace MojoProofTest.GPUProof.ViewWords

open _root_.GPUProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.GPUProof.MixedRadix (warpIdx entryIdx asg)
open MojoProofTest.GPUProof.View (gemvView gemvAdm gemvBind gemv_row naiveView naiveAdm naiveBind
  naive_val naive_tile naive_wf inst_sig place_inj elem_cosize elem_call)
open MojoProofTest.GPUProof.ViewStride (lnView lnAdm lnLay lnKey lnBind ln_regs ln_key lnLay_call
  ln_guard_tile)

/-! ## Words, for every width -/

/-- **`icmp` of two words of its width is the predicate on them**, for every width `w`,
predicate `p`, layout, memory and words `a`, `b`: `icmpV` at the integer type of `w` bits is the
boolean `p.holds a b`. -/
theorem icmp_bits {w : Nat} (l : Layout) (m : Mem) (p : ICmp) (a b : BitVec w) :
    icmpV l m p (.int w) (.bits w a) (.bits w b) = .ok (.ofBool (p.holds a b)) := by
  show (if h : w = w then pure (Val.ofBool (p.holds a (b.cast h))) else _ : Except Fault Val) = _
  rw [dite_eq_left rfl, BitVec.cast_eq]
  rfl

/-- **`icmp sge` of two words is `≤` of their numbers**, for every width `w`, layout and memory:
of the `w`-bit words of `v` and `a` with `2 v` and `2 a` below `2 ^ w`, `icmpV` with the
predicate `sge` is the boolean `a ≤ v` (`icmp_bits`, `ICmp.sge_ofNat`). -/
theorem icmp_sge {w a v : Nat} (l : Layout) (m : Mem) (hv : 2 * v < 2 ^ w) (ha : 2 * a < 2 ^ w) :
    icmpV l m .sge (.int w) (.bits w (BitVec.ofNat w v)) (.bits w (BitVec.ofNat w a)) =
      .ok (.ofBool (decide (a ≤ v))) := by
  rw [icmp_bits, ICmp.sge_ofNat hv ha]

/-- **A guard on a sign-extended bound**, for every pair of widths `w ≤ w'`, layout and memory:
the `sext` to `w'` bits of the `w`-bit word of `a`, with `2 a` below `2 ^ w`, compared by
`icmp sge` with the `w'`-bit word of `v`, `2 v` below `2 ^ w'`, is the boolean `a ≤ v`
(`intCast_sext_ofNat`, `icmp_sge`). -/
theorem sge_sext {w w' a v : Nat} (l : Layout) (m : Mem) (hw : w ≤ w') (ha : 2 * a < 2 ^ w)
    (hv : 2 * v < 2 ^ w') :
    (intCast .sext w' (.bits w (BitVec.ofNat w a)) >>=
        icmpV l m .sge (.int w') (.bits w' (BitVec.ofNat w' v))) =
      .ok (.ofBool (decide (a ≤ v))) := by
  have hP : 2 ^ w ≤ 2 ^ w' := Nat.pow_le_pow_right (by decide) hw
  rw [intCast_sext_ofNat w' ha]
  exact icmp_sge l m hv (by omega)

/-- **A row-major index in words**, for every pair of widths `w ≤ w'` and all flags: with
`r < m`, `k < s` and `m · s < 2 ^ (w - 1)`, `trunc` to `w` bits of the `w'`-bit words of `r`
and `k`, `mul` of `r`'s word by `s`'s, `add` of `k`'s word and `sext` to `w'` bits give the words
of `r`, `k`, `r · s` and `r · s + k`: no step wraps, so the flags (`nuw`, `nsw`) add no poison
(`intCast_ofNat`, `intBin_mul_ofNat`, `intBin_add_ofNat`, `intCast_sext_ofNat`). -/
theorem rowMajor_words {w w' m s r k : Nat} (fl fl' : IntFlags) (hw : w ≤ w') (hr : r < m)
    (hk : k < s) (h : m * s < 2 ^ (w - 1)) :
    intCast .trunc w (.bits w' (BitVec.ofNat w' r)) = .ok (.bits w (BitVec.ofNat w r)) ∧
      intCast .trunc w (.bits w' (BitVec.ofNat w' k)) = .ok (.bits w (BitVec.ofNat w k)) ∧
      intBin w .mul fl (.bits w (BitVec.ofNat w r)) (.bits w (BitVec.ofNat w s)) =
        .ok (.bits w (BitVec.ofNat w (r * s))) ∧
      intBin w .add fl' (.bits w (BitVec.ofNat w (r * s))) (.bits w (BitVec.ofNat w k)) =
        .ok (.bits w (BitVec.ofNat w (r * s + k))) ∧
      intCast .sext w' (.bits w (BitVec.ofNat w (r * s + k))) =
        .ok (.bits w' (BitVec.ofNat w' (r * s + k))) := by
  have h1 : (r + 1) * s ≤ m * s := Nat.mul_le_mul_right s hr
  have hs : s ≤ (r + 1) * s := Nat.le_mul_of_pos_left s (Nat.succ_pos r)
  have hrs : r ≤ r * s := Nat.le_mul_of_pos_right r (by omega)
  have hP : 2 ^ (w - 1) ≤ 2 ^ w' := Nat.pow_le_pow_right (by decide) (by omega)
  have h2 : ∀ j, j < 2 ^ (w - 1) → 2 * j < 2 ^ w := fun j hj => WordFit.two_mul_lt_iff.2 hj
  rw [Nat.succ_mul] at h1
  exact ⟨intCast_ofNat (.inl rfl) w (by omega), intCast_ofNat (.inl rfl) w (by omega),
    intBin_mul_ofNat fl (h2 r (by omega)) (h2 s (by omega)) (h2 _ (by omega)),
    intBin_add_ofNat fl' (h2 _ (by omega)), intCast_sext_ofNat w' (h2 _ (by omega))⟩

/-! ## The naive matmul -/

/-- The radix product of the naive view's key is `n · m`, at every assignment. -/
theorem naive_radixProd (c : Nat) (σ : Sizes) : (naiveView c).key.radixProd σ = σ 5 * σ 4 := by
  simp [naiveView, entryIdx, MixedRadix.radixProd, SizeExpr.eval]

/-- **The naive kernel's index words are its key.** At MojoProof's `sig`, for the naive kernel
of every row stride `N`, at every assignment with `n = N` (the variable 5) and the word premise
`hw`, the key's radix product `m · N` below `2 ^ 31`, every launch, every thread `t` with
`row < m` and `col < N` (its `Launch.index` in `x` and `y`) and all flags: `trunc` of the row's
64-bit word (:26), `mul` by `N` (:28), `trunc` of the column's (:37), `add` (:39) and `sext`
(:40) give the 64-bit word of the key value `row · N + col`, the index of the
`getelementptr` at :41, and the tile's first offset is `4 · (row · N + col)` (`naive_tile`). The
line numbers are those of
tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll. -/
theorem naive_words (c N : Nat) {σ : Sizes} {L : Launch} (hN : σ 5 = N)
    (hw : (naiveView c).key.radixProd σ < 2 ^ 31) {t : Nat} (hr : L.index t .x < σ 4)
    (hc : L.index t .y < N) (fl fl' : IntFlags) :
    (do
      let r ← intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 (L.index t .x)))
      let p ← intBin 32 .mul fl r (.bits 32 (BitVec.ofNat 32 N))
      let q ← intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 (L.index t .y)))
      let s ← intBin 32 .add fl' p q
      intCast .sext 64 s) =
        .ok (.bits 64 (BitVec.ofNat 64
          ((naiveView c).key.val ((naiveView c).bind L (sig.group L 0 t) σ)))) ∧
      (naiveView c).off σ L (sig.group L 0 t) 0 = 4 * (L.index t .x * N + L.index t .y) := by
  rw [naive_radixProd, hN, Nat.mul_comm] at hw
  obtain ⟨e1, e2, e3, e4, e5⟩ := rowMajor_words (w := 32) (w' := 64) fl fl' (by decide) hr hc hw
  have hv : (naiveView c).key.val ((naiveView c).bind L (sig.group L 0 t) σ) =
      L.index t .x * N + L.index t .y := by
    show (entryIdx 0 1).val (naiveBind L (sig.group L 0 t) σ) = _
    rw [naive_val, hN]
    rfl
  refine ⟨?_, ?_⟩
  · rw [hv]
    simp only [e1, e2, e3, e4, e5, bind, Except.bind]
  · show (entryIdx 0 1).val (naiveBind L (sig.group L 0 t) σ) *
      (MojoProofTest.GPUProof.View.elem 4).cosize +
      (MojoProofTest.GPUProof.View.elem 4).call (GPUProof.Layout.Tup.leaf 0 false) = _
    rw [naive_val, hN, elem_cosize (by decide), elem_call, Nat.mul_comm]
    rfl

/-- **The naive kernel's guards are its view's owners.** At MojoProof's `sig`, for the naive
view in every buffer, at every assignment with the word premise `hw` (`m · n` below `2 ^ 31`),
every valid launch, thread `t`, layout and memory: the guards `icmp sge` of the row and the
column with the sign-extended bounds `m` and `n` (:42-43) give booleans `b` and `b'` whose `or`
(the `select` of :44, on which :45 skips the store) is false exactly when `t` owns its tile. At
`n = 0` the premise holds at every `m` and the row guard may be true at `row < m` (`naive_edge`);
the `or` is still `t`'s ownership. -/
theorem naive_guards (c : Nat) {σ : Sizes} {L : Launch}
    (hw : (naiveView c).key.radixProd σ < 2 ^ 31) (hL : L.Valid) (t : Nat) (l : Layout)
    (m : Mem) :
    ∃ b b', (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (σ 4))) >>=
        icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (L.index t .x)))) = .ok (.ofBool b) ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (σ 5))) >>=
        icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (L.index t .y)))) = .ok (.ofBool b') ∧
      ((b || b') = false ↔ (naiveView c).owns L (sig.group L 0 t) σ) := by
  rw [naive_radixProd] at hw
  have hx := Launch.index_lt hL t .x
  have hy := Launch.index_lt hL t .y
  have hx2 : 2 * L.index t .x < 2 ^ 64 := by unfold Launch.index; omega
  have hy2 : 2 * L.index t .y < 2 ^ 64 := by unfold Launch.index; omega
  have ho : (naiveView c).owns L (sig.group L 0 t) σ ↔ L.index t .x < σ 4 ∧ L.index t .y < σ 5 :=
    Iff.rfl
  by_cases h5 : σ 5 = 0
  · -- at `n = 0` the column guard is true
    obtain ⟨b, hb⟩ : ∃ b, (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (σ 4))) >>=
        icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (L.index t .x)))) = .ok (.ofBool b) :=
      ⟨_, rfl⟩
    refine ⟨b, true, hb, ?_, ?_⟩
    · rw [h5, sge_sext l m (by decide) (by decide) hy2]
      simp
    · rw [ho, h5]
      simp
  · by_cases h4 : σ 4 = 0
    · -- at `m = 0` the row guard is true
      obtain ⟨b', hb'⟩ : ∃ b', (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (σ 5))) >>=
          icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (L.index t .y)))) =
            .ok (.ofBool b') := ⟨_, rfl⟩
      refine ⟨true, b', ?_, hb', ?_⟩
      · rw [h4, sge_sext l m (by decide) (by decide) hx2]
        simp
      · rw [ho, h4]
        simp
    · -- both positive: both bounds are below `2 ^ 31`
      have h4' : σ 4 ≤ σ 5 * σ 4 := Nat.le_mul_of_pos_left _ (by omega)
      have h5' : σ 5 ≤ σ 5 * σ 4 := Nat.le_mul_of_pos_right _ (by omega)
      refine ⟨_, _, sge_sext l m (by decide) (by omega) hx2,
        sge_sext l m (by decide) (by omega) hy2, ?_⟩
      rw [ho]
      simp

/-- **The naive kernel's `getelementptr` is its tile's first byte.** At MojoProof's `sig`, for
the naive kernel of every row stride `N`, at every assignment with `n = N` and the word premise
`hw`, every launch and thread `t` with `row < m` and `col < N`, every layout whose floats have 4
bytes and whose address space `a` (0 or the buffer's) has 64-bit pointers, and every memory in
which the view's buffer `c` is a buffer (`Mem.BufferIn`) of at least `4 · m · N` bytes that fits
space `a`: the `getelementptr` of a float from `⟨c, 0⟩` by the 64-bit word of `row · N + col`
(:41, the word of `naive_words`) is the pointer to byte `(naiveView c).off σ L g 0` of `c`, the
first byte of `t`'s tile (`naive_tile`), at all flags (`gep_buffer`). -/
theorem naive_gep (c N : Nat) {σ : Sizes} {L : Launch} (hN : σ 5 = N)
    (hw : (naiveView c).key.radixProd σ < 2 ^ 31) {t : Nat} (hr : L.index t .x < σ 4)
    (hc : L.index t .y < N) {l : Layout} {M m : Mem} {fl : GepFlags} {s a size al : Nat}
    {ow : Owner} {wr : Bool} (hMb : M.blocks = m.blocks) (hB : m.BufferIn s c size al ow wr)
    (ha : a = 0 ∨ a = s)
    (hF : ∃ blk, m.blocks c = some blk ∧ (if a = s then blk.addr else blk.gaddr) + size ≤
      2 ^ (l.ptr a).1)
    (hp : (l.ptr a).1 = 64) (h4 : l.size (.fp .float) = 4) (hsz : 4 * (σ 4 * N) ≤ size) :
    gep l M fl (.fp .float) a [.bits 64 (BitVec.ofNat 64 (L.index t .x * N + L.index t .y))]
        (.ptr ⟨c, 0⟩) =
      .ok (.ptr ⟨c, ((naiveView c).off σ L (sig.group L 0 t) 0 : Int)⟩) := by
  rw [(naive_words c N hN hw hr hc {} {}).2]
  rw [naive_radixProd, hN, Nat.mul_comm] at hw
  have h1 : (L.index t .x + 1) * N ≤ σ 4 * N := Nat.mul_le_mul_right N hr
  rw [Nat.succ_mul] at h1
  have e := gep_buffer (fl := fl) (src := .fp .float) (K := L.index t .x * N + L.index t .y)
    (w := 64) hMb hB ha hF (by omega) (by omega) (by rw [h4, hp]; omega) (by rw [h4]; omega)
  rw [h4, Nat.mul_comm _ 4] at e
  exact e

/-- The memory with one buffer of `size` bytes, block 1: live, writable, owned by every thread,
in address space 1 at address 0 there and in the generic space. -/
def oneBuf (size : Nat) : Mem where
  blocks := fun b => if b = 1 then some ⟨1, size, true, false, .all, fun _ => .undef, 0, 0⟩
    else none

/-- `oneBuf size`'s block 1 is a buffer of space 1 and `size` bytes, aligned to 4. -/
theorem oneBuf_in (size : Nat) : (oneBuf size).BufferIn 1 1 size 4 .all true :=
  ⟨_, rfl, rfl, rfl, rfl, rfl, Nat.le_refl _, Nat.dvd_zero _, Nat.dvd_zero _⟩

/-- `naive_gep`'s premises at one memory: the corpus kernel's stride `N = 50257` at `m = 2`, grid
(1,1,1) and block (2,2,1), thread 3 (row 1, column 1), the default layout (64-bit pointers in
space 0, 4-byte floats) and the buffer `oneBuf` of `4 · 2 · 50257` bytes. -/
example (fl : GepFlags) :
    gep {} (oneBuf (4 * (2 * 50257))) fl (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64
          ((launch2 1 1 2 2).index 3 .x * 50257 + (launch2 1 1 2 2).index 3 .y))]
        (.ptr ⟨1, 0⟩) =
      .ok (.ptr ⟨1, ((naiveView 1).off (asg [0, 0, 0, 0, 2, 50257]) (launch2 1 1 2 2)
        (sig.group (launch2 1 1 2 2) 0 3) 0 : Int)⟩) :=
  naive_gep 1 50257 rfl (by rw [naive_radixProd]; decide) (by decide) (by decide) rfl
    (oneBuf_in _) (.inl rfl) ⟨_, rfl, by decide⟩ rfl rfl (by decide)

/-- `naive_guards`'s premises at `m = 2`, `n = 50257`, grid (1,1,1) and block (2,2,1), thread 3. -/
example (c : Nat) (l : Layout) (m : Mem) :
    ∃ b b', (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 2)) >>=
        icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 ((launch2 1 1 2 2).index 3 .x)))) =
          .ok (.ofBool b) ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 50257)) >>=
        icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 ((launch2 1 1 2 2).index 3 .y)))) =
          .ok (.ofBool b') ∧
      ((b || b') = false ↔ (naiveView c).owns (launch2 1 1 2 2)
        (sig.group (launch2 1 1 2 2) 0 3) (asg [0, 0, 0, 0, 2, 50257])) :=
  naive_guards c (σ := asg [0, 0, 0, 0, 2, 50257]) (by rw [naive_radixProd]; decide)
    (launch2_valid (by decide)) 3 l m

/-- The naive kernel of `N = 50257` (the corpus kernel's stride, :28) at `m = 4` and a thread at
`row = 3`, `col = 50256`, at every launch: the index words give the word of `3 · 50257 + 50256`
and the tile's first byte is `4 · 201027`. -/
example (c : Nat) {L : Launch} {t : Nat} (hr : L.index t .x = 3) (hc : L.index t .y = 50256) :
    (naiveView c).off (asg [0, 0, 0, 0, 4, 50257]) L (sig.group L 0 t) 0 = 4 * 201027 := by
  rw [(naive_words c 50257 rfl (by rw [naive_radixProd]; decide) (by rw [hr]; decide)
    (by rw [hc]; decide) {} {}).2, hr, hc]

/-- The word premise at the naive view gives, through `GPUProof.View.key_fits` at width 32, that
the key value `row · N + col` of every owner thread fits 32 bits, at every admissible assignment
and launch. -/
example (c N : Nat) {σ : Sizes} {L : Launch} (ha : naiveAdm N σ L)
    (hw : (naiveView c).key.radixProd σ < 2 ^ 31) {t : Nat}
    (ho : (naiveView c).Owner σ L (sig.group L 0 t)) :
    WordFit 32 ((naiveView c).key.val ((naiveView c).bind L (sig.group L 0 t) σ)) :=
  View.key_fits (naive_wf c N σ L ha) ho hw

/-! ## gemv -/

/-- **gemv's row, bound and guard words.** At MojoProof's `sig`, at every admissible assignment
and valid launch with the word premise `hm`, `m` (the variable 7) below `2 ^ 31`, every thread
`t` below the thread count, layout and memory, and every flags value without `exact`: the `udiv`
of the 64-bit word of `ctaid.x · ntid.x + tid.x` by 32 (:21, lane 0's row, which the kernel
broadcasts to the warp as the word `%36` of :49) is the word of `row`; the `sext` of `m`'s 32-bit
word (:11) is its 64-bit word; the guard `icmp sge` of the row with it (:55, on which :56 skips
the store) is the boolean `m ≤ row`, false exactly when `t`'s warp owns its tile; and the tile's
first offset is `4 · row`, the index of the `getelementptr` at :50 (`gemv_gep`). The line
numbers are those of
tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll; the
broadcast is not proved here. -/
theorem gemv_words (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) (hm : σ 7 < 2 ^ 31)
    (hL : L.Valid) {t : Nat} (ht : t < volume L.grid * volume L.block) (l : Layout) (mem : Mem)
    {fl : IntFlags} (he : fl.exact = false) :
    intBin 64 .udiv fl (.bits 64 (BitVec.ofNat 64 (L.index t .x)))
        (.bits 64 (BitVec.ofNat 64 32)) = .ok (.bits 64 (BitVec.ofNat 64 (L.index t .x / 32))) ∧
      intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (σ 7))) =
        .ok (.bits 64 (BitVec.ofNat 64 (σ 7))) ∧
      icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (L.index t .x / 32)))
          (.bits 64 (BitVec.ofNat 64 (σ 7))) =
        .ok (.ofBool (decide (σ 7 ≤ L.index t .x / 32))) ∧
      (decide (σ 7 ≤ L.index t .x / 32) = false ↔ (gemvView y).owns L (sig.group L 1 t) σ) ∧
      (gemvView y).off σ L (sig.group L 1 t) 0 = 4 * (L.index t .x / 32) := by
  have hx := Launch.index_lt hL t .x
  have hx' : L.index t .x < 2 ^ 42 := by unfold Launch.index; exact hx
  have hr := gemv_row ha ht
  refine ⟨intBin_udiv_ofNat he (by omega) (by decide) (by decide),
    intCast_sext_ofNat 64 (WordFit.two_mul_lt_iff.2 hm),
    icmp_sge l mem (by omega) (by omega), ?_, ?_⟩
  · show _ ↔ (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) < σ 7
    rw [hr]
    simp
  · show (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) *
      (MojoProofTest.GPUProof.View.elem 4).cosize +
      (MojoProofTest.GPUProof.View.elem 4).call (GPUProof.Layout.Tup.leaf 0 false) = _
    rw [hr, elem_cosize (by decide), elem_call, Nat.mul_comm, Nat.add_zero]

/-- **gemv's `getelementptr` is its warp tile's first byte.** At MojoProof's `sig`, at every
admissible assignment and valid launch, every thread `t` below the thread count whose warp owns
its tile (`row < m`), every layout whose floats have 4 bytes and whose address space `a` (0 or
the buffer's) has 64-bit pointers, and every memory in which `y` is a buffer (`Mem.BufferIn`) of
at least `4 · m` bytes that fits space `a`: the `getelementptr` of a float from `⟨y, 0⟩` by the
64-bit word of `row` (:50) is the pointer to byte `(gemvView y).off σ L g 0` of `y`, the first
byte of the warp's tile (`gemv_tile`), at all flags (`gep_buffer`). -/
theorem gemv_gep (y : Nat) {σ : Sizes} {L : Launch} (ha : gemvAdm σ L) (hL : L.Valid) {t : Nat}
    (ht : t < volume L.grid * volume L.block) (ho : (gemvView y).owns L (sig.group L 1 t) σ)
    {l : Layout} {M m : Mem} {fl : GepFlags} {s a size al : Nat} {ow : Owner} {wr : Bool}
    (hMb : M.blocks = m.blocks) (hB : m.BufferIn s y size al ow wr) (ha' : a = 0 ∨ a = s)
    (hF : ∃ blk, m.blocks y = some blk ∧ (if a = s then blk.addr else blk.gaddr) + size ≤
      2 ^ (l.ptr a).1)
    (hp : (l.ptr a).1 = 64) (h4 : l.size (.fp .float) = 4) (hsz : 4 * σ 7 ≤ size) :
    gep l M fl (.fp .float) a [.bits 64 (BitVec.ofNat 64 (L.index t .x / 32))] (.ptr ⟨y, 0⟩) =
      .ok (.ptr ⟨y, ((gemvView y).off σ L (sig.group L 1 t) 0 : Int)⟩) := by
  have hr := gemv_row ha ht
  have hx := Launch.index_lt hL t .x
  have hx' : L.index t .x < 2 ^ 42 := by unfold Launch.index; exact hx
  have hlt : L.index t .x / 32 < σ 7 := by
    have h : (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) < σ 7 := ho
    rwa [hr] at h
  have hoff : (gemvView y).off σ L (sig.group L 1 t) 0 = 4 * (L.index t .x / 32) := by
    show (warpIdx 0 1).val (gemvBind L (sig.group L 1 t) σ) *
      (MojoProofTest.GPUProof.View.elem 4).cosize +
      (MojoProofTest.GPUProof.View.elem 4).call (GPUProof.Layout.Tup.leaf 0 false) = _
    rw [hr, elem_cosize (by decide), elem_call, Nat.mul_comm, Nat.add_zero]
  rw [hoff]
  have e := gep_buffer (fl := fl) (src := .fp .float) (K := L.index t .x / 32) (w := 64)
    hMb hB ha' hF (by omega) (by omega) (by rw [h4, hp]; omega) (by rw [h4]; omega)
  rw [h4, Nat.mul_comm] at e
  exact e

/-- `gemv_words`'s premises at grid (4,1,1), block (128,1,1) and `m = 500`, thread 200 (row 6)
and the IR's flags (none): the tile's first byte is `4 · 6` and the guard is false. -/
example (y : Nat) (l : Layout) (mem : Mem) :
    (gemvView y).off (asg [0, 0, 0, 0, 128, 32, 4, 500]) (launch2 4 1 128 1)
      (sig.group (launch2 4 1 128 1) 1 200) 0 = 4 * 6 ∧
    icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 ((launch2 4 1 128 1).index 200 .x / 32)))
          (.bits 64 (BitVec.ofNat 64 500)) = .ok (.ofBool false) := by
  obtain ⟨-, -, e3, -, e5⟩ := gemv_words y (σ := asg [0, 0, 0, 0, 128, 32, 4, 500])
    (L := launch2 4 1 128 1) ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ (by decide)
    (launch2_valid (by decide)) (t := 200) (by decide) l mem (fl := {}) rfl
  exact ⟨e5.trans (by decide), e3.trans (congrArg (fun b => (.ok (.ofBool b) : Except Fault Val))
    (by decide))⟩

/-- `gemv_gep`'s premises at one memory: grid (4,1,1), block (128,1,1) and `m = 500`, thread 200,
the default layout and the buffer `oneBuf` of `4 · 500` bytes. -/
example (fl : GepFlags) :
    gep {} (oneBuf (4 * 500)) fl (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64 ((launch2 4 1 128 1).index 200 .x / 32))] (.ptr ⟨1, 0⟩) =
      .ok (.ptr ⟨1, ((gemvView 1).off (asg [0, 0, 0, 0, 128, 32, 4, 500]) (launch2 4 1 128 1)
        (sig.group (launch2 4 1 128 1) 1 200) 0 : Int)⟩) :=
  gemv_gep 1 (σ := asg [0, 0, 0, 0, 128, 32, 4, 500]) (L := launch2 4 1 128 1)
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩ (launch2_valid (by decide)) (by decide)
    (by decide : (warpIdx 0 1).val (gemvBind (launch2 4 1 128 1)
      (sig.group (launch2 4 1 128 1) 1 200) (asg [0, 0, 0, 0, 128, 32, 4, 500])) <
        asg [0, 0, 0, 0, 128, 32, 4, 500] 7)
    rfl (oneBuf_in _) (.inl rfl) ⟨_, rfl, by decide⟩ rfl rfl (by decide)

/-! ## Layer norm: the loop's words at every thread and step -/

/-- **Layer norm's offsets of one float at the key stride.** At MojoProof's `sig`, for every
buffer `y`, block size `B`, assignment `σ`, launch `L`, thread `t`, step `j < X` (the variable 5)
and byte `b < 4`: the offset at the key stride 4 of coordinate `4 j + b` of `t`'s tile is
`4 (B j + tid) + b`, `tid` the thread's `tid.x` (`ln_key`, `lnLay_call`). -/
theorem ln_offAt (y B : Nat) {σ : Sizes} (L : Launch) (t : Nat) {j : Nat} (hj : j < σ 5)
    {b : Nat} (hb : b < 4) :
    (lnView y B).offAt (fun _ => 4) σ L (sig.group L 0 t) (4 * j + b) =
      4 * (B * j + (L.env t).sreg .tid .x) + b := by
  show lnKey.val (lnBind L (0, t) σ) * 4 +
    (lnLay (σ 5) B).call (GPUProof.Layout.Tup.leaf (4 * j + b) false) = _
  rw [ln_key]
  show (L.env t).sreg .tid .x * 4 + _ = _
  rw [lnLay_call (by omega), show (4 * j + b) % 4 = b by omega,
    show (4 * j + b) / 4 = j by omega, Nat.mod_eq_of_lt hj]
  ring

/-- The thread's `tid.x` is below the block size, at every assignment and launch of the kernel
of block size `B` and every thread below the thread count (`ln_regs`). -/
theorem ln_tid_lt {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L) {t : Nat}
    (ht : t < volume L.grid * volume L.block) : (L.env t).sreg .tid .x < B := by
  obtain ⟨hg, hb, -, hB, -⟩ := ha
  have hv : volume L.block = L.block .x := by simp [volume, hb.1, hb.2]
  have hpos : 0 < L.block .x := Nat.pos_of_ne_zero fun h => by simp [hv, h] at ht
  rw [(ln_regs hg hb ht).1, ← hB]
  exact Nat.mod_lt _ hpos

/-- **Layer norm's loop words are its view's offsets and guard at the key stride.** At
MojoProof's `sig`, for the kernel of every block size `B` and every row length `n`, at every
assignment and valid launch of the kernel (`lnAdm B`) with the word premises `hw` (the row's
`4 B X` bytes, `X` the variable 5, have their double below `2 ^ 64`) and `hn` (`2 n < 2 ^ 64`),
every thread `t` below the thread count, step `j < X`, flags, layout and memory, from the loop
index's word `B j` (`%471`, :679, at step `j`) and the 32-bit word of `tid.x` the special
register gives (:31):

* the `zext` (:32) is the 64-bit word of `tid`;
* the `add` (:699) is the word of `B j + tid`, the index of the `getelementptr` at :700, whose
  pointer is byte `offAt (4 j)` of `y` (`ln_gep`), and the 4 bytes the store (:722) writes there
  are the coordinates `4 j + b`, `b < 4`, at the offsets `4 (B j + tid) + b` (`ln_offAt`);
* the guard `icmp slt` with `n` (:708, on which :709 skips the store) is the boolean
  `B j + tid < n`, which is `View.guardAt`'s bound `offAt (4 j + b) < 4 n` at each of those `b`
  (`ln_guard_tile`);
* the exit test `icmp sge` (:684) is the boolean `n ≤ B j`, the step `add` (:681) the word of
  `B j + B`, the index at step `j + 1`, and its overflow test (:682) is false.

The line numbers are those of
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, at `B = 128`. The
words are the semantics' operations at symbolic words (`intCast`, `intBin`, `icmpV`), for every
thread and step, not an evaluation. It is not a run theorem: that the index at step `j` is the
word of `B j` (by induction from `0` at :679 over this step), that a run reaches these words and
that it stores there are not proved. The second test of the same bound (:704-707) is
`ln_second`. -/
theorem ln_words (y n : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L)
    (hL : L.Valid) (hw : 2 * (4 * (B * σ 5)) < 2 ^ 64) (hn : 2 * n < 2 ^ 64) {t : Nat}
    (ht : t < volume L.grid * volume L.block) {j : Nat} (hj : j < σ 5) (fl fl' : IntFlags)
    (l : Layout) (m : Mem) :
    intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L.env t).sreg .tid .x))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env t).sreg .tid .x))) ∧
      intBin 64 .add fl (.bits 64 (BitVec.ofNat 64 (B * j)))
          (.bits 64 (BitVec.ofNat 64 ((L.env t).sreg .tid .x))) =
        .ok (.bits 64 (BitVec.ofNat 64 (B * j + (L.env t).sreg .tid .x))) ∧
      (∀ b < 4, (lnView y B).offAt (fun _ => 4) σ L (sig.group L 0 t) (4 * j + b) =
        4 * (B * j + (L.env t).sreg .tid .x) + b) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 (B * j + (L.env t).sreg .tid .x)))
          (.bits 64 (BitVec.ofNat 64 n)) =
        .ok (.ofBool (decide (B * j + (L.env t).sreg .tid .x < n))) ∧
      icmpV l m .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (B * j)))
          (.bits 64 (BitVec.ofNat 64 n)) = .ok (.ofBool (decide (n ≤ B * j))) ∧
      intBin 64 .add fl' (.bits 64 (BitVec.ofNat 64 (B * j))) (.bits 64 (BitVec.ofNat 64 B)) =
        .ok (.bits 64 (BitVec.ofNat 64 (B * j + B))) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 (B * j + B)))
          (.bits 64 (BitVec.ofNat 64 (B * j))) = .ok (.ofBool false) := by
  have htid := ln_tid_lt ha ht
  have h32 : (L.env t).sreg .tid .x < 2 ^ 32 :=
    (Launch.sreg_bound hL t .tid .x).2.trans_le (by decide)
  have hBj : B * j + B ≤ B * σ 5 := by
    rw [show B * j + B = B * (j + 1) by ring]
    exact Nat.mul_le_mul_left B hj
  refine ⟨intCast_ofNat (.inr rfl) 64 h32, intBin_add_ofNat fl (by omega),
    fun b hb => ln_offAt y B L t hj hb, ?_, icmp_sge l m (by omega) hn,
    intBin_add_ofNat fl' (by omega), ?_⟩
  · rw [icmp_bits, ICmp.slt_ofNat (by omega) hn]
  · rw [icmp_bits, ICmp.slt_ofNat (by omega) (by omega),
      decide_eq_false (by omega : ¬ B * j + B < B * j)]

/-- **Layer norm's `getelementptr` is its float's first byte at the key stride.** At MojoProof's
`sig`, for every buffer `y` and block size `B`, at every assignment and launch of the kernel of
block size `B` (`lnAdm B`) with the word premise `hw` (as `ln_words`), every thread `t` below the
thread count and step `j < X`, every layout whose floats have 4 bytes and whose address space `a`
(0 or the buffer's) has 64-bit pointers, and every memory in which `y` is a buffer
(`Mem.BufferIn`) of at least `4 B X` bytes that fits space `a`: the `getelementptr` of a float
from `⟨y, 0⟩` by the 64-bit word of `B j + tid` (:700, the word of `ln_words`' `add` :699) is the
pointer to byte `offAt (4 j)` at the key stride 4 of `y`, the first byte of float `B j + tid` of
`t`'s tile, at all flags (`gep_buffer`). Not a run theorem, as `ln_words`. -/
theorem ln_gep (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} (ha : lnAdm B σ L)
    (hw : 2 * (4 * (B * σ 5)) < 2 ^ 64) {t : Nat} (ht : t < volume L.grid * volume L.block)
    {j : Nat} (hj : j < σ 5) {l : Layout} {M m : Mem} {fl : GepFlags} {s a size al : Nat}
    {ow : Owner} {wr : Bool} (hMb : M.blocks = m.blocks) (hB : m.BufferIn s y size al ow wr)
    (ha' : a = 0 ∨ a = s)
    (hF : ∃ blk, m.blocks y = some blk ∧ (if a = s then blk.addr else blk.gaddr) + size ≤
      2 ^ (l.ptr a).1)
    (hp : (l.ptr a).1 = 64) (h4 : l.size (.fp .float) = 4) (hsz : 4 * (B * σ 5) ≤ size) :
    gep l M fl (.fp .float) a [.bits 64 (BitVec.ofNat 64 (B * j + (L.env t).sreg .tid .x))]
        (.ptr ⟨y, 0⟩) =
      .ok (.ptr ⟨y, ((lnView y B).offAt (fun _ => 4) σ L (sig.group L 0 t) (4 * j) : Int)⟩) := by
  have htid := ln_tid_lt ha ht
  have hBj : B * j + B ≤ B * σ 5 := by
    rw [show B * j + B = B * (j + 1) by ring]
    exact Nat.mul_le_mul_left B hj
  have h0 := ln_offAt y B L t hj (b := 0) (by decide)
  simp only [Nat.add_zero] at h0
  rw [h0]
  have e := gep_buffer (fl := fl) (src := .fp .float) (K := B * j + (L.env t).sreg .tid .x)
    (w := 64) hMb hB ha' hF (by omega) (by omega) (by rw [h4, hp]; omega) (by rw [h4]; omega)
  rw [h4, Nat.mul_comm _ 4] at e
  exact e

/-- **Layer norm's second test of the bound is the guard.** For every row length `n` and index
`k` (the word of `B j + tid` of `ln_words`' `add`, :699) with `2 n` and `2 k` below `2 ^ 64`, at
every flags of the `sub` without `nuw` and `nsw` (the IR's has none), layout and memory: the `sub`
of `k` from `n` (:704), the `llvm.smin` of that and 1 (:705, which `MojoProof.Sem.intrinsic`
evaluates by `intMinMax true false` on scalars) and the `icmp eq` of the minimum with 1 (:707), on
which :712 branches to the store (:722), give the boolean `k < n`, the guard's (:708,
`ln_words`). So where the guard is true the branch :712 goes to the store. The `llvm.smax` of :706
is read only on the other path (:731, :741). Not a run theorem, as `ln_words`. -/
theorem ln_second {n k : Nat} (hn : 2 * n < 2 ^ 64) (hk : 2 * k < 2 ^ 64) {fl : IntFlags}
    (hu : fl.nuw = false) (hs : fl.nsw = false) (l : Layout) (m : Mem) :
    (intBin 64 .sub fl (.bits 64 (BitVec.ofNat 64 n)) (.bits 64 (BitVec.ofNat 64 k)) >>= fun d =>
      intMinMax true false d (.bits 64 (BitVec.ofNat 64 1)) >>= fun e =>
        icmpV l m .eq (.int 64) e (.bits 64 (BitVec.ofNat 64 1))) =
      .ok (.ofBool (decide (k < n))) := by
  have hmin : ∀ a b : BitVec 64, intMinMax true false (.bits 64 a) (.bits 64 b) =
      .ok (.bits 64 (if a.slt b then a else b)) := by
    intro a b
    cases h : a.slt b <;> simp [intMinMax, strict2, pure, Except.pure, h]
  rw [intBin_sub_wrap hu hs]
  simp only [bind, Except.bind, hmin, icmp_bits]
  have hd : (BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).toNat =
      (2 ^ 64 - k + n) % 2 ^ 64 := by
    rw [BitVec.toNat_ofNat, Nat.mod_mod, Nat.mod_eq_of_lt (by omega : k < 2 ^ 64)]
  by_cases hkn : k < n
  · have hs1 : (BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).slt (BitVec.ofNat 64 1) =
        false := by
      simp only [BitVec.slt, BitVec.toInt_eq_toNat_cond, hd, BitVec.toNat_ofNat]
      split_ifs <;> simp <;> omega
    simp only [hs1, Bool.false_eq_true, ↓reduceIte, decide_eq_true hkn]
    rfl
  · have hs1 : (BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).slt (BitVec.ofNat 64 1) =
        true := by
      simp only [BitVec.slt, BitVec.toInt_eq_toNat_cond, hd, BitVec.toNat_ofNat]
      split_ifs <;> simp <;> omega
    simp only [hs1, ↓reduceIte, decide_eq_false hkn]
    rw [ICmp.eq_ofNat (Nat.mod_lt _ (by decide)) (by decide), decide_eq_false (by omega)]

/-- `ln_words` at the kernel of block size 128 (the IR's), one block of 128 threads, `n = 300`
and `X = 3`, step 2 (the index word `256`), the IR's flags (none): at thread 43 the index word is
`299` and the guard is true, its float's offsets are `4 · 299 + b`; at thread 44 the index word is
`300` and the guard is false (`ln_guard_300`: float 300 is in no guarded tile). -/
example (y : Nat) (l : Layout) (m : Mem) :
    intBin 64 .add {} (.bits 64 (BitVec.ofNat 64 (128 * 2)))
        (.bits 64 (BitVec.ofNat 64 (((launch2 1 1 128 1).env 43).sreg .tid .x))) =
        .ok (.bits 64 (BitVec.ofNat 64 299)) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 299)) (.bits 64 (BitVec.ofNat 64 300)) =
        .ok (.ofBool true) ∧
      (lnView y 128).offAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 3]) (launch2 1 1 128 1)
        (sig.group (launch2 1 1 128 1) 0 43) (4 * 2 + 3) = 4 * 299 + 3 ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 (128 * 2 +
          ((launch2 1 1 128 1).env 44).sreg .tid .x))) (.bits 64 (BitVec.ofNat 64 300)) =
        .ok (.ofBool false) := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 3]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have hL : (launch2 1 1 128 1).Valid := launch2_valid (by decide)
  obtain ⟨-, e2, e3, -⟩ := ln_words y 300 ha hL (by decide) (by decide) (t := 43) (by decide)
    (j := 2) (by decide) {} {} l m
  obtain ⟨-, -, -, e4, -⟩ := ln_words y 300 ha hL (by decide) (by decide) (t := 44) (by decide)
    (j := 2) (by decide) {} {} l m
  exact ⟨e2, rfl, e3 3 (by decide), e4⟩

/-- `ln_words` at the kernel of block size 64, two blocks of 64 threads, `n = 170` and `X = 3`,
step 2 (the index word `128`): thread 41 (`tid.x` 41) has the index word `169` and the guard
true; thread 106 (`tid.x` 42, block 1, which owns no tile) has the index word `170` and the guard
false. -/
example (l : Layout) (m : Mem) :
    intBin 64 .add {} (.bits 64 (BitVec.ofNat 64 (64 * 2)))
        (.bits 64 (BitVec.ofNat 64 (((launch2 2 1 64 1).env 41).sreg .tid .x))) =
        .ok (.bits 64 (BitVec.ofNat 64 169)) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 169)) (.bits 64 (BitVec.ofNat 64 170)) =
        .ok (.ofBool true) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 (64 * 2 +
          ((launch2 2 1 64 1).env 106).sreg .tid .x))) (.bits 64 (BitVec.ofNat 64 170)) =
        .ok (.ofBool false) := by
  have ha : lnAdm 64 (asg [0, 0, 0, 0, 64, 3]) (launch2 2 1 64 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  have hL : (launch2 2 1 64 1).Valid := launch2_valid (by decide)
  obtain ⟨-, e2, -⟩ := ln_words 0 170 ha hL (by decide) (by decide) (t := 41) (by decide)
    (j := 2) (by decide) {} {} l m
  obtain ⟨-, -, -, e4, -⟩ := ln_words 0 170 ha hL (by decide) (by decide) (t := 106)
    (by decide) (j := 2) (by decide) {} {} l m
  exact ⟨e2, rfl, e4⟩

/-- `ln_gep`'s premises at one memory: the kernel of block size 128, one block, `X = 3`, thread
43 at step 2, the default layout and the buffer `oneBuf` of `4 · 384` bytes: the pointer is byte
`offAt (4 · 2)` of buffer 1, `4 · 299` (`ln_offAt`). -/
example (fl : GepFlags) :
    gep {} (oneBuf (4 * (128 * 3))) fl (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 43).sreg .tid .x))]
        (.ptr ⟨1, 0⟩) =
      .ok (.ptr ⟨1, ((lnView 1 128).offAt (fun _ => 4) (asg [0, 0, 0, 0, 128, 3])
        (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 43) (4 * 2) : Int)⟩) :=
  ln_gep 1 (B := 128) (σ := asg [0, 0, 0, 0, 128, 3]) (L := launch2 1 1 128 1)
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩ (by decide) (t := 43) (by decide) (j := 2)
    (by decide) rfl (oneBuf_in _) (.inl rfl) ⟨_, rfl, by decide⟩ rfl rfl (by decide)

/-- `ln_second` at the kernel of block size 128, one block of 128 threads, `n = 300`, step 2,
the IR's flags (none): the second test is true at thread 43 (index word `299`) and false at thread
44 (index word `300`), as the guard of `ln_words`' first example. -/
example (l : Layout) (m : Mem) :
    (intBin 64 .sub {} (.bits 64 (BitVec.ofNat 64 300))
        (.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 43).sreg .tid .x))) >>=
        fun d => intMinMax true false d (.bits 64 (BitVec.ofNat 64 1)) >>= fun e =>
          icmpV l m .eq (.int 64) e (.bits 64 (BitVec.ofNat 64 1))) = .ok (.ofBool true) ∧
      (intBin 64 .sub {} (.bits 64 (BitVec.ofNat 64 300))
        (.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 44).sreg .tid .x))) >>=
        fun d => intMinMax true false d (.bits 64 (BitVec.ofNat 64 1)) >>= fun e =>
          icmpV l m .eq (.int 64) e (.bits 64 (BitVec.ofNat 64 1))) = .ok (.ofBool false) :=
  ⟨ln_second (by decide) (by decide) rfl rfl l m, ln_second (by decide) (by decide) rfl rfl l m⟩

/-- **Mutant: layer norm at `n = 2 ^ 63`.** At MojoProof's `sig`, the kernel of block size 128 at
one block of 128 threads, `X = 1` and `n = 2 ^ 63`, every buffer, layout and memory: the
assignment and launch are admissible and valid and the word premise `hw` holds, but `hn` fails
(`2 n = 2 ^ 64`): `n`'s 64-bit word is negative, so the guard `icmp slt` (:708) of thread 0 at
step 0 (index word 0) is false, and the kernel skips the store of float 0, whose bytes are in
thread 0's guarded tile under the bound `4 n` (`ln_guard_tile`). The second test (:704-707) is
false there too: the `sub` is the negative word `2 ^ 63`, its minimum with 1 is itself (the
premise `hn` of `ln_second` fails). -/
theorem ln_wrap (y : Nat) (l : Layout) (m : Mem) :
    lnAdm 128 (asg [0, 0, 0, 0, 128, 1]) (launch2 1 1 128 1) ∧ (launch2 1 1 128 1).Valid ∧
      2 * (4 * (128 * asg [0, 0, 0, 0, 128, 1] 5)) < 2 ^ 64 ∧ ¬ 2 * 2 ^ 63 < 2 ^ 64 ∧
      sig.place y 0 ∈ (lnView y 128).guardAt (fun _ => 4) (fun _ => 4 * 2 ^ 63)
        (asg [0, 0, 0, 0, 128, 1]) (launch2 1 1 128 1) (sig.group (launch2 1 1 128 1) 0 0) ∧
      icmpV l m .slt (.int 64) (.bits 64 (BitVec.ofNat 64 (128 * 0 +
          ((launch2 1 1 128 1).env 0).sreg .tid .x))) (.bits 64 (BitVec.ofNat 64 (2 ^ 63))) =
        .ok (.ofBool false) ∧
      (intBin 64 .sub {} (.bits 64 (BitVec.ofNat 64 (2 ^ 63)))
        (.bits 64 (BitVec.ofNat 64 (128 * 0 + ((launch2 1 1 128 1).env 0).sreg .tid .x))) >>=
        fun d => intMinMax true false d (.bits 64 (BitVec.ofNat 64 1)) >>= fun e =>
          icmpV l m .eq (.int 64) e (.bits 64 (BitVec.ofNat 64 1))) = .ok (.ofBool false) := by
  have ha : lnAdm 128 (asg [0, 0, 0, 0, 128, 1]) (launch2 1 1 128 1) :=
    ⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, by decide⟩
  refine ⟨ha, launch2_valid (by decide), by decide, by decide,
    (ln_guard_tile y 128 (2 ^ 63) ha (by decide) _).2
      ⟨by decide, 0, by decide, by decide, 0, by decide, rfl⟩, ?_, ?_⟩
  · rw [icmp_bits]
    rfl
  · rw [show 128 * 0 + ((launch2 1 1 128 1).env 0).sreg .tid .x = 0 from rfl,
      intBin_sub_wrap rfl rfl]
    rfl

/-! ## Mutants: the premise fails -/

/-- **Mutant: gemv at `m = 2 ^ 31`.** At MojoProof's `sig`, at grid (1,1,1) and block (32,1,1)
with `m = 2 ^ 31`, `ntid.x = 32` and `nctaid.x = 1`, and every buffer, layout and memory: the
assignment and launch are admissible (`gemvAdm`) and valid, and warp 0 owns a tile (row 0 is
below `m`), but the word premise `m < 2 ^ 31` fails: `m`'s 32-bit word is negative, so its `sext`
(:11) is `-2 ^ 31`, and the guard (:55) at row 0 is true, so the kernel skips the store of the
float the view gives warp 0. -/
theorem gemv_wrap (y : Nat) (l : Layout) (mem : Mem) :
    gemvAdm (asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31]) (launch2 1 1 32 1) ∧
      (launch2 1 1 32 1).Valid ∧
      (gemvView y).Owner (asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31]) (launch2 1 1 32 1)
        (sig.group (launch2 1 1 32 1) 1 0) ∧
      ¬ asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31] 7 < 2 ^ 31 ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31] 7))) >>=
        icmpV l mem .sge (.int 64)
          (.bits 64 (BitVec.ofNat 64 ((launch2 1 1 32 1).index 0 .x / 32)))) =
        .ok (.ofBool true) :=
  ⟨⟨⟨rfl, rfl⟩, ⟨rfl, rfl⟩, rfl, rfl, rfl, by decide⟩, launch2_valid (by decide),
    ⟨inst_sig.2 ⟨0, by decide, rfl⟩, (by decide : (warpIdx 0 1).val (gemvBind (launch2 1 1 32 1)
      (sig.group (launch2 1 1 32 1) 1 0) (asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31])) <
        asg [0, 0, 0, 0, 32, 32, 1, 2 ^ 31] 7)⟩, by decide, rfl⟩

/-- The assignment of the naive mutant: `m = 2 ^ 20 + 1` and `n = 50257`. -/
def wrapSizes : Sizes := asg [0, 0, 0, 0, 2 ^ 20 + 1, 50257]

/-- The launch of the naive mutant: grid `(2 ^ 20 + 1, 1, 1)` and block `(1, 1, 1)`. -/
def wrapLaunch : Launch := launch2 (2 ^ 20 + 1) 1 1 1

/-- **Mutant: the naive kernel past `2 ^ 31`.** At MojoProof's `sig`, at grid `(2 ^ 20 + 1, 1, 1)`
and block `(1, 1, 1)` with `m = 2 ^ 20 + 1` and `n = 50257`, every buffer, layout and memory: the
assignment and launch are admissible (`naiveAdm 50257`), but the word premise fails
(`m · n ≥ 2 ^ 31`). Thread `2 ^ 20` (row `2 ^ 20`, column 0) owns its tile and both guards
(:42-43) are false, so it stores; but the words of :26-40, with the IR's flags (none), give the
word of `1105 · 2 ^ 20` (`50257 · 2 ^ 20` modulo `2 ^ 32`), and byte `4 · 1105 · 2 ^ 20` of `c` is
not in the thread's tile. -/
theorem naive_wrap (c : Nat) (l : Layout) (mem : Mem) :
    naiveAdm 50257 wrapSizes wrapLaunch ∧ ¬ (naiveView c).key.radixProd wrapSizes < 2 ^ 31 ∧
      (naiveView c).Owner wrapSizes wrapLaunch (sig.group wrapLaunch 0 (2 ^ 20)) ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (wrapSizes 4))) >>=
        icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (wrapLaunch.index (2 ^ 20) .x)))) =
        .ok (.ofBool false) ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (wrapSizes 5))) >>=
        icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (wrapLaunch.index (2 ^ 20) .y)))) =
        .ok (.ofBool false) ∧
      (do
        let r ← intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 (wrapLaunch.index (2 ^ 20) .x)))
        let p ← intBin 32 .mul {} r (.bits 32 (BitVec.ofNat 32 50257))
        let q ← intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 (wrapLaunch.index (2 ^ 20) .y)))
        let s ← intBin 32 .add {} p q
        intCast .sext 64 s) = .ok (.bits 64 (BitVec.ofNat 64 (1105 * 2 ^ 20))) ∧
      sig.place c ↑(4 * (1105 * 2 ^ 20)) ∉
        (naiveView c).tile wrapSizes wrapLaunch (sig.group wrapLaunch 0 (2 ^ 20)) := by
  have hx : wrapLaunch.index (2 ^ 20) .x = 2 ^ 20 := by decide
  have hy : wrapLaunch.index (2 ^ 20) .y = 0 := by decide
  refine ⟨⟨rfl, launch2_valid (by decide), ⟨rfl, rfl⟩⟩, by rw [naive_radixProd]; decide,
    ⟨inst_sig.2 ⟨2 ^ 20, by decide, rfl⟩, ?_⟩, ?_, ?_, ?_, fun h => ?_⟩
  · show wrapLaunch.index (2 ^ 20) .x < wrapSizes 4 ∧ wrapLaunch.index (2 ^ 20) .y < wrapSizes 5
    rw [hx, hy]
    decide
  · rw [hx]; rfl
  · rw [hy]; rfl
  · rw [hx, hy]; rfl
  · obtain ⟨-, b, hb, he⟩ := (naive_tile c 50257 rfl (2 ^ 20) _).1 h
    have h' := (place_inj he).2
    rw [hx, hy] at h'
    omega

/-- **The edge `n = 0`.** At MojoProof's `sig`, at grid (1,1,1) and block (1,1,1) with
`m = 2 ^ 31` and `n = 0`, every buffer, layout and memory: the word premise holds (the radix
product is 0) and thread 0's row is below `m`, but `m`'s 32-bit word is negative, so the row
guard (:42) is true; the column guard (:43) is true as well, and the thread owns no tile, so
`naive_guards`'s `or` is still the thread's ownership. -/
theorem naive_edge (c : Nat) (l : Layout) (mem : Mem) :
    (naiveView c).key.radixProd (asg [0, 0, 0, 0, 2 ^ 31, 0]) < 2 ^ 31 ∧
      Launch.one.index 0 .x < asg [0, 0, 0, 0, 2 ^ 31, 0] 4 ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (asg [0, 0, 0, 0, 2 ^ 31, 0] 4))) >>=
        icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (Launch.one.index 0 .x)))) =
        .ok (.ofBool true) ∧
      (intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (asg [0, 0, 0, 0, 2 ^ 31, 0] 5))) >>=
        icmpV l mem .sge (.int 64) (.bits 64 (BitVec.ofNat 64 (Launch.one.index 0 .y)))) =
        .ok (.ofBool true) ∧
      ¬ (naiveView c).owns Launch.one (sig.group Launch.one 0 0) (asg [0, 0, 0, 0, 2 ^ 31, 0]) :=
  ⟨by rw [naive_radixProd]; decide, by decide, rfl, rfl,
    (by decide : ¬ (Launch.one.index 0 .x < asg [0, 0, 0, 0, 2 ^ 31, 0] 4 ∧
      Launch.one.index 0 .y < asg [0, 0, 0, 0, 2 ^ 31, 0] 5))⟩

end MojoProofTest.GPUProof.ViewWords
