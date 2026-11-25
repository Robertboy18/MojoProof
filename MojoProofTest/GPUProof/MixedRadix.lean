import GPUProof.MixedRadix

/-!
# Mixed-radix indices of gemv and the naive matmul

GPUProof/MixedRadix.lean proves, for every size assignment and radix list, that an index in range
is below its radix product (`GPUProof.MixedRadix.lt_prod`), that two indices in range with the
same radix values, at one or two size assignments, are equal exactly when their digits are
(`GPUProof.MixedRadix.eq_iff_digits`), that Horner's rule splits at a digit
(`GPUProof.MixedRadix.val_append`), and
that an index whose radix product is below `2 ^ (w - 1)` fits `w` bits
(`GPUProof.MixedRadix.fits`). Here, for every size and thread:

* `gemv_val`: gemv's write index `(ctaid * ntid + tid) / W` is the value of `warpIdx`, the warp
  `tid / W` with radix `ntid / W` and the block `ctaid` with radix the grid size, when `W`
  divides `ntid`, for every size assignment.
* `gemv_warp`: two threads of the launch write the same index exactly when they are in the same
  warp of the same block (injective on warps, constant on a warp's lanes), for every `ntid`, `W`
  dividing it, grid size and thread, by `eq_iff_digits`.
* `warp_two`: the key `warpIdx 0 1` at two threads' assignments, which differ only in variables
  the radices do not read, has one value exactly when the threads are in the same warp of the same
  block, by `eq_iff_digits` at two assignments; `mutant_assign`: at two assignments whose radices
  differ, the premise fails and so does the equivalence, decided.
* `warp_split`, `warp_split_37`: `warpIdx`'s value split after its warp digit, at every size
  assignment, by `val_append`, and at one thread by evaluation.
* `gemv_lt`: the index is below the number of rows written, `(ntid / W) * grid`, by `lt_prod`.
* `gemv_fits`: the index fits `w` bits when `(ntid / W) * grid < 2 ^ (w - 1)`, by `fits`.
* `matmul_eq`: the naive matmul's offset `row * n + k` at symbolic `n`, with `k, k' < n`, is
  `row' * n + k'` exactly when `row = row'` and `k = k'`, by `eq_iff_digits`; `omega` alone does
  not close it (the `example` after it).

The `#guard`s check the three theorems and `gemv_val` by evaluation over every thread of two
unrelated launches (`ntid = 96`, `W = 32`, three blocks; `ntid = 15`, `W = 5`, seven blocks) and
over every entry of two unrelated matrices (`3 × 4` and `5 × 7`). The mutants, decided: a thread
`tid = ntid` (out of range) whose index is the next block's first warp's, where `eq_iff_digits`
fails (`mutant_out`); the same thread of the last block, whose index is the radix product
(`mutant_lt`); `W` not dividing `ntid`, where `gemv_val` fails (`mutant_dvd`); two indices in
range with other radices, equal with other digits (`mutant_radices`); `2 ^ (w - 1)` itself,
which does not fit `w` bits (`mutant_fits`); and a digit out of range whose radix product is below
`2 ^ (w - 1)` and whose value does not fit (`mutant_range`).
-/

namespace MojoProofTest.GPUProof.MixedRadix

open _root_.GPUProof

/-- The size assignment of the list `l`: variable `v` is the `v`-th entry, `0` past the end. -/
def asg (l : List Nat) : Sizes := fun v => l.getD v 0

/-- gemv's warp index of the thread whose `tid` and `ctaid` are the variables `t` and `c`: the
digit `tid / W` with radix `ntid / W`, then `ctaid` with radix the grid size, where `ntid`, `W`
and the grid size are the variables `4`, `5` and `6`. -/
def warpIdx (t c : Nat) : MixedRadix :=
  ⟨[(.div (.var t) (.var 5), .div (.var 4) (.var 5)), (.var c, .var 6)]⟩

/-- **gemv's write index is a mixed-radix value**: `(ctaid * ntid + tid) / W` is the value of
`warpIdx` when `W` divides `ntid`, for every size assignment `σ` and variables `t`, `c`. -/
theorem gemv_val (σ : Sizes) (t c : Nat) (h : σ 5 ∣ σ 4) :
    (σ c * σ 4 + σ t) / σ 5 = (warpIdx t c).val σ := by
  obtain ⟨q, hq⟩ := h
  simp only [MixedRadix.val, warpIdx, SizeExpr.eval, List.foldr_cons, List.foldr_nil,
    Nat.mul_zero, Nat.add_zero, hq]
  rcases Nat.eq_zero_or_pos (σ 5) with h0 | hW
  · simp [h0]
  · rw [Nat.mul_div_cancel_left q hW, show σ c * (σ 5 * q) + σ t = σ t + σ 5 * (σ c * q) by
      rw [Nat.add_comm, Nat.mul_left_comm], Nat.add_mul_div_left _ _ hW, Nat.mul_comm q]

/-- `warpIdx` is in range when `W` divides `ntid`, `tid < ntid` and `ctaid` is below the grid
size, for every size assignment. -/
theorem inRange_warpIdx {σ : Sizes} {t c : Nat} (h : σ 5 ∣ σ 4) (ht : σ t < σ 4)
    (hc : σ c < σ 6) : (warpIdx t c).InRange σ := by
  intro p hp
  simp only [warpIdx, List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl
  · exact Nat.div_lt_div_of_lt_of_dvd h ht
  · exact hc

/-- **gemv's write index is injective on warps and constant on a warp's lanes**: for every block
size `ntid`, warp width `W` dividing it, grid size, and threads `(tid, ctaid)`, `(tid', ctaid')`
of the launch, the two write the same index exactly when they are in the same warp of the same
block. -/
theorem gemv_warp {ntid W grid t c t' c' : Nat} (hW : W ∣ ntid) (ht : t < ntid) (ht' : t' < ntid)
    (hc : c < grid) (hc' : c' < grid) :
    (c * ntid + t) / W = (c' * ntid + t') / W ↔ t / W = t' / W ∧ c = c' := by
  have e1 : (c * ntid + t) / W = (warpIdx 0 1).val (asg [t, c, t', c', ntid, W, grid]) :=
    gemv_val (asg [t, c, t', c', ntid, W, grid]) 0 1 hW
  have e2 : (c' * ntid + t') / W = (warpIdx 2 3).val (asg [t, c, t', c', ntid, W, grid]) :=
    gemv_val (asg [t, c, t', c', ntid, W, grid]) 2 3 hW
  have h1 : (warpIdx 0 1).InRange (asg [t, c, t', c', ntid, W, grid]) := inRange_warpIdx hW ht hc
  have h2 : (warpIdx 2 3).InRange (asg [t, c, t', c', ntid, W, grid]) :=
    inRange_warpIdx hW ht' hc'
  rw [e1, e2, MixedRadix.eq_iff_digits h1 h2 rfl]
  simp only [MixedRadix.digitVals, warpIdx, List.map_cons, List.map_nil, List.cons.injEq,
    and_true]
  rfl

/-- **gemv's write index is below the number of rows written**, `(ntid / W) * grid`, for every
block size `ntid`, warp width `W` dividing it, grid size and thread of the launch, by
`lt_prod`. -/
theorem gemv_lt {ntid W grid t c : Nat} (hW : W ∣ ntid) (ht : t < ntid) (hc : c < grid) :
    (c * ntid + t) / W < ntid / W * grid := by
  have e : (c * ntid + t) / W = (warpIdx 0 1).val (asg [t, c, 0, 0, ntid, W, grid]) :=
    gemv_val (asg [t, c, 0, 0, ntid, W, grid]) 0 1 hW
  have hx : (warpIdx 0 1).InRange (asg [t, c, 0, 0, ntid, W, grid]) := inRange_warpIdx hW ht hc
  rw [e]
  simpa [MixedRadix.radixProd, warpIdx, SizeExpr.eval, asg] using MixedRadix.lt_prod hx

/-- **gemv's write index fits `w` bits** when the number of rows written, `(ntid / W) * grid`, is
below `2 ^ (w - 1)`, for every width, block size `ntid`, warp width `W` dividing it, grid size
and thread of the launch (`GPUProof.WordFit`). -/
theorem gemv_fits {w ntid W grid t c : Nat} (hW : W ∣ ntid) (ht : t < ntid) (hc : c < grid)
    (h : ntid / W * grid < 2 ^ (w - 1)) : WordFit w ((c * ntid + t) / W) := by
  have e : (c * ntid + t) / W = (warpIdx 0 1).val (asg [t, c, 0, 0, ntid, W, grid]) :=
    gemv_val (asg [t, c, 0, 0, ntid, W, grid]) 0 1 hW
  have hx : (warpIdx 0 1).InRange (asg [t, c, 0, 0, ntid, W, grid]) := inRange_warpIdx hW ht hc
  rw [e]
  refine MixedRadix.fits hx ?_
  simpa [MixedRadix.radixProd, warpIdx, SizeExpr.eval, asg] using h

/-- **One warp index at two threads' assignments**: for every block size `ntid`, warp width `W`
dividing it, grid size and threads `(tid, ctaid)`, `(tid', ctaid')` of the launch, the key
`warpIdx 0 1` at the assignment of the first thread has the value it has at the second's exactly
when the two are in the same warp of the same block. The two assignments differ in the variables
`0` and `1`, which the radices do not read, so the radices' values agree (`rfl`;
`eq_iff_digits` at two assignments). -/
theorem warp_two {ntid W grid t c t' c' : Nat} (hW : W ∣ ntid) (ht : t < ntid) (ht' : t' < ntid)
    (hc : c < grid) (hc' : c' < grid) :
    (warpIdx 0 1).val (asg [t, c, 0, 0, ntid, W, grid]) =
        (warpIdx 0 1).val (asg [t', c', 0, 0, ntid, W, grid]) ↔ t / W = t' / W ∧ c = c' := by
  have h1 : (warpIdx 0 1).InRange (asg [t, c, 0, 0, ntid, W, grid]) := inRange_warpIdx hW ht hc
  have h2 : (warpIdx 0 1).InRange (asg [t', c', 0, 0, ntid, W, grid]) :=
    inRange_warpIdx hW ht' hc'
  rw [MixedRadix.eq_iff_digits h1 h2 rfl]
  simp only [MixedRadix.digitVals, warpIdx, List.map_cons, List.map_nil, List.cons.injEq,
    and_true]
  rfl

/-- **The mutant of the premise on radix values**: the key `warpIdx 0 1` at two assignments
whose radices differ (`ntid / W` is `3` at `ntid = 96` and `4` at `ntid = 128`) is in range at
both and has the value `3` at both, with other digits (`0, 1` and `3, 0`): the premise of
`eq_iff_digits` is false and so is its equivalence, decided. -/
theorem mutant_assign :
    let σ := asg [0, 1, 0, 0, 96, 32, 3]
    let τ := asg [96, 0, 0, 0, 128, 32, 3]
    (warpIdx 0 1).InRange σ ∧ (warpIdx 0 1).InRange τ ∧
      (warpIdx 0 1).digits.map (fun p => p.2.eval σ) ≠
        (warpIdx 0 1).digits.map (fun p => p.2.eval τ) ∧
      (warpIdx 0 1).val σ = (warpIdx 0 1).val τ ∧
      (warpIdx 0 1).digitVals σ ≠ (warpIdx 0 1).digitVals τ := by
  decide

/-- `warpIdx 0 1` split after its first digit, at every size assignment: its value is the warp
digit's plus the warp radix times the block digit's (`MixedRadix.val_append`). -/
theorem warp_split (σ : Sizes) :
    (warpIdx 0 1).val σ = MixedRadix.val ⟨[(.div (.var 0) (.var 5), .div (.var 4) (.var 5))]⟩ σ +
      MixedRadix.radixProd ⟨[(.div (.var 0) (.var 5), .div (.var 4) (.var 5))]⟩ σ *
        MixedRadix.val ⟨[(.var 1, .var 6)]⟩ σ :=
  MixedRadix.val_append [(.div (.var 0) (.var 5), .div (.var 4) (.var 5))] [(.var 1, .var 6)] σ

/-- `warp_split` at thread `37` of block `1` of the launch with `ntid = 128`, `W = 32` and two
blocks, by evaluation: the warp digit `1`, the warp radix `4` and the block digit `1` give `5`,
which is `(1 * 128 + 37) / 32`. -/
theorem warp_split_37 :
    let σ := asg [37, 1, 0, 0, 128, 32, 2]
    (warpIdx 0 1).val σ = 5 ∧
      MixedRadix.val ⟨[(.div (.var 0) (.var 5), .div (.var 4) (.var 5))]⟩ σ = 1 ∧
      MixedRadix.radixProd ⟨[(.div (.var 0) (.var 5), .div (.var 4) (.var 5))]⟩ σ = 4 ∧
      MixedRadix.val ⟨[(.var 1, .var 6)]⟩ σ = 1 ∧ (1 * 128 + 37) / 32 = 5 := by
  decide

/-- The naive matmul's offset of entry `(row, k)`, row-major, where `row` and `k` are the
variables `r` and `k`: the digit `k` with radix `n`, the variable `5`, then `row` with radix the
variable `4`. -/
def entryIdx (r k : Nat) : MixedRadix := ⟨[(.var k, .var 5), (.var r, .var 4)]⟩

/-- **The naive matmul's offsets at symbolic `n`**: for every `n` and entries `(row, k)`,
`(row', k')` with `k, k' < n`, `row * n + k = row' * n + k'` exactly when `row = row'` and
`k = k'`, by `eq_iff_digits` with any radix above both rows. -/
theorem matmul_eq {n r k r' k' : Nat} (hk : k < n) (hk' : k' < n) :
    r * n + k = r' * n + k' ↔ r = r' ∧ k = k' := by
  have hx : (entryIdx 0 1).InRange (asg [r, k, r', k', r + r' + 1, n]) := by
    intro p hp
    simp only [entryIdx, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · exact hk
    · show r < r + r' + 1
      omega
  have hy : (entryIdx 2 3).InRange (asg [r, k, r', k', r + r' + 1, n]) := by
    intro p hp
    simp only [entryIdx, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · exact hk'
    · show r' < r + r' + 1
      omega
  have e := MixedRadix.eq_iff_digits hx hy rfl
  simp only [MixedRadix.val, MixedRadix.digitVals, entryIdx, SizeExpr.eval, List.foldr_cons,
    List.foldr_nil, List.map_cons, List.map_nil, List.cons.injEq, and_true, Nat.mul_zero,
    Nat.add_zero] at e
  change k + n * r = k' + n * r' ↔ k = k' ∧ r = r' at e
  rw [Nat.add_comm (r * n), Nat.mul_comm r, Nat.add_comm (r' * n), Nat.mul_comm r', e, and_comm]

-- `omega` alone does not close `matmul_eq`: the products `r * n` and `r' * n` are of unknowns
example {n r k r' k' : Nat} (hk : k < n) (hk' : k' < n) :
    r * n + k = r' * n + k' ↔ r = r' ∧ k = k' := by
  fail_if_success omega
  exact matmul_eq hk hk'

/-- The checks of a launch with block size `ntid`, warp width `W` and `grid` blocks, over every
pair of its threads: `gemv_val` (the index is `warpIdx`'s value), `lt_prod` (below the radix
product, the rows written as the size `(ntid / W) * grid`), `eq_iff_digits` (equal indices exactly
when equal digits) and `gemv_warp` (exactly when the same warp of the same block). -/
def launchOk (ntid W grid : Nat) : Bool :=
  (List.range grid).all fun c => (List.range ntid).all fun t =>
    let σ := asg [t, c, 0, 0, ntid, W, grid]
    (warpIdx 0 1).InRange σ && (warpIdx 0 1).val σ == (c * ntid + t) / W &&
    decide ((warpIdx 0 1).val σ < (warpIdx 0 1).radixProd σ) &&
    (warpIdx 0 1).radixProd σ == (SizeExpr.mul (.div (.var 4) (.var 5)) (.var 6)).eval σ &&
    (List.range grid).all fun c' => (List.range ntid).all fun t' =>
      let τ := asg [t, c, t', c', ntid, W, grid]
      ((warpIdx 0 1).val τ == (warpIdx 2 3).val τ) ==
          ((warpIdx 0 1).digitVals τ == (warpIdx 2 3).digitVals τ) &&
        (((c * ntid + t) / W == (c' * ntid + t') / W) == (t / W == t' / W && c == c'))

#guard launchOk 96 32 3
#guard launchOk 15 5 7

/-- The checks of an `m × n` matrix over every pair of its entries: `lt_prod` (below `m n`) and
`eq_iff_digits` and `matmul_eq` (equal offsets exactly when the same entry). -/
def matrixOk (m n : Nat) : Bool :=
  (List.range m).all fun r => (List.range n).all fun k =>
    (List.range m).all fun r' => (List.range n).all fun k' =>
      let σ := asg [r, k, r', k', m, n]
      (entryIdx 0 1).InRange σ && (entryIdx 0 1).val σ == r * n + k &&
        decide ((entryIdx 0 1).val σ < (entryIdx 0 1).radixProd σ) &&
        ((entryIdx 0 1).val σ == (entryIdx 2 3).val σ) ==
          ((entryIdx 0 1).digitVals σ == (entryIdx 2 3).digitVals σ) &&
        ((r * n + k == r' * n + k') == (r == r' && k == k'))

#guard matrixOk 3 4
#guard matrixOk 5 7

/-- The size assignment of the mutants: thread `tid = 96` (one past the block, out of range) of
block `0`, and thread `0` of block `1`, of the launch with `ntid = 96`, `W = 32`, three blocks. -/
def σOut : Sizes := asg [96, 0, 0, 1, 96, 32, 3]

/-- **The mutant of `eq_iff_digits`**: with the digit `tid / W = 3` out of range (its radix
`ntid / W` is `3`), the thread's index `3` is the next block's first warp's while the digits
differ, so the equivalence fails; the other index is in range and the radices have the same
values. -/
theorem mutant_out :
    ¬ (warpIdx 0 1).InRange σOut ∧ (warpIdx 2 3).InRange σOut ∧
      (warpIdx 0 1).digits.map (fun p => p.2.eval σOut) =
        (warpIdx 2 3).digits.map (fun p => p.2.eval σOut) ∧
      ¬ ((warpIdx 0 1).val σOut = (warpIdx 2 3).val σOut ↔
        (warpIdx 0 1).digitVals σOut = (warpIdx 2 3).digitVals σOut) := by
  decide

/-- **The mutant of `lt_prod`**: thread `tid = 96`, one past the end of the last block `2` of the
same launch, out of range, writes the index `3 + 3 · 2 = 9`, the radix product (the number of
rows), not below it. -/
theorem mutant_lt :
    ¬ (warpIdx 0 1).InRange (asg [96, 2, 0, 0, 96, 32, 3]) ∧
      ¬ (warpIdx 0 1).val (asg [96, 2, 0, 0, 96, 32, 3]) <
        (warpIdx 0 1).radixProd (asg [96, 2, 0, 0, 96, 32, 3]) := by
  decide

/-- **The mutant of `gemv_val`'s premise**: with `W = 5` not dividing `ntid = 12`, thread `0` of
block `3` writes `36 / 5 = 7`, not `warpIdx`'s value `6`. -/
theorem mutant_dvd :
    (3 * 12 + 0) / 5 ≠ (warpIdx 0 1).val (asg [0, 3, 0, 0, 12, 5, 4]) := by
  decide

/-- **The mutant of `eq_iff_digits`' premise on radices**: two indices in range with other
radices (`2` then `5`, and `3` then `5`) have the same value `2` and other digits. -/
theorem mutant_radices :
    let x : MixedRadix := ⟨[(.var 0, .var 1), (.var 2, .var 3)]⟩
    let y : MixedRadix := ⟨[(.var 4, .var 5), (.var 6, .var 3)]⟩
    let σ := asg [0, 2, 1, 5, 2, 3, 0]
    x.InRange σ ∧ y.InRange σ ∧ x.val σ = y.val σ ∧ x.digitVals σ ≠ y.digitVals σ := by
  decide

/-- An instance of `gemv_fits`: thread `37` of block `1` of the launch with `ntid = 128`,
`W = 32` and two blocks fits 32 bits. -/
theorem fits_32 : WordFit 32 ((1 * 128 + 37) / 32) :=
  gemv_fits (grid := 2) ⟨4, rfl⟩ (by decide) (by decide) (by decide)

/-- **The mutant of `fits`' bound**: `2 ^ (w - 1)` itself does not fit `w` bits; at `w = 8`, the
word of `128` has the signed value `-128`. -/
theorem mutant_fits : ¬ WordFit 8 128 := fun h => absurd h.toInt (by decide)

/-- **The mutant of `fits` without `InRange`**: the one digit `200` with radix `1` is out of
range and its radix product `1` is below `2 ^ 7`, but its value `200` does not fit 8 bits (the
signed value of its word is `-56`), so the premise `InRange` of `fits` cannot be dropped. -/
theorem mutant_range :
    ¬ (⟨[(.var 0, .var 1)]⟩ : MixedRadix).InRange (asg [200, 1]) ∧
      (⟨[(.var 0, .var 1)]⟩ : MixedRadix).radixProd (asg [200, 1]) < 2 ^ (8 - 1) ∧
      ¬ WordFit 8 ((⟨[(.var 0, .var 1)]⟩ : MixedRadix).val (asg [200, 1])) :=
  ⟨by decide, by decide, fun h => absurd h.toInt (by decide)⟩

end MojoProofTest.GPUProof.MixedRadix
