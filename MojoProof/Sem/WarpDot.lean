import MojoProof.Sem.Bfly
import MojoProof.Sem.Matmul
import Mathlib.Data.Int.CardIntervalMod

/-!
# The warp's dot product: strided loops and a butterfly (docs/proofs/warp-dot.md)

Both kernels of tests/corpus/gemv/ compute a dot product the same way: the factor pairs are split
by position modulo 32 into 32 strided lists, lane `l` folds list `l` from `+0` with the contracted
loop `dotLoop`, and the five butterfly rounds at the offsets `warpOffsets` add the 32 lanes' sums,
lane 0's result being the output. In gemv_kernel, lane `l` of row `i`'s warp folds the pairs
`(a[i, 32 j + l], b[32 j + l])`; in gevm_kernel, thread `(w, l)` folds
`(a[32 j + w], b[32 j + w, 32 β + l])`, the sums are transposed through shared memory, and the
same rounds give column `32 β + w`'s total at lane 0. This module states that value once, for
every format, every length and every oracle; a kernel's theorem is then a corollary at its pairs
(`matVecPairs`, `vecMatPairs`).

Definitions:
* `stride w l xs`: the elements of `xs` at the positions `≡ l (mod w)`, in order.
* `vecMatPairs v A j`: the factor pairs `(v.getScalar k, get2 A k j)` of entry `j` of the product
  of the vector `v` and the matrix `A` (TorchLean's `contract v A _ _ [n] .vecMat`).
* `warpDot c o ps`: lane 0's value after the five rounds of FloatLib's `Model.add` at the
  offsets `warpOffsets`, from lane `l`'s value `dotLoop c (o l) (Model.zero fmt false)
  (stride 32 l ps)`. The kernels' `fadd` of a round goes through `deliver`, which changes only a
  NaN result (`nanEq_deliver`); `warpDot` adds without it.
* `warpBound fmt n d w T`: `((1 + u) ^ (n + d + 1) - 1) T + w (1 + u) ^ d (2 + u) η
  ((1 + u) ^ n - 1) / u`, with `u` FloatLib's unit roundoff and `η` its underflow allowance.

Proved:
* `sum_stride`, `length_stride`, `length_stride_le`: for every `w > 0`, the sums over the `w`
  strided lists add up to the sum over the list, in every commutative monoid; list `l < w` has
  `K / w + [l < K % w]` elements, at most `⌈K / w⌉`, for a list of length `K`.
* `bfly_stride`: for all offsets, lanes `l` and widths `w` such that lane `l`'s tree has the
  lanes below `w` as leaves, each once (`leaves_warp` at a warp), the rounds of `+` over the exact
  strided sums give the sum over the list, in every commutative monoid. Over `ℝ`, for the
  products of the real values: `bfly_matVec`, TorchLean's real matrix-vector entry, and
  `bfly_vecMat` (with `vecMat_cell_real`), its real vector-matrix entry.
* `bfly_stride_error`, `warpDot_error`, `warpDot_matVec`, `warpDot_vecMat`: in every IEEE format,
  for every flag and oracle family (each iteration fused or not), a finite result is within
  `warpBound fmt n d w T` of the exact sum, `T` the sum of the absolute products, `n` a bound on
  the lists' lengths, `d` the number of rounds; for `warpDot` over `K` pairs, `n = ⌈K / 32⌉`,
  `d = 5`, `w = 32`, and the exact sum is TorchLean's real matrix-vector or vector-matrix entry.
* `bflyRounds_nanEq`, for all operations `f`, `g` that respect `NaNEq` together: the rounds of
  `f` and of `g` over values that are lane by lane `NaNEq` are `NaNEq`; so the rounds of the
  semantics' `fadd` at one oracle number `n`, `deliver (Model.add x y) n`, are those of
  `Model.add` up to NaNs.
* `bfly_stride_nanEq`, `warpDot_nanEq`, `warpDot_eq`: with the contraction off, the result and
  FloatLib's `Model.reduceAlong` along lane 0's tree `bflyTree warpOffsets 0` of FloatLib's
  in-order dot products `Model.dotInOrder` of the 32 lists are the same word or both NaNs.

That a grid run of either kernel computes `warpDot` of its loaded pairs is not proved here. The
instances at 40 pairs are in MojoProofTest/WarpDot.lean.
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Numerics FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  TorchLean LLVM

variable {fmt : FloatFormat} {m n : Nat}

/-! ## The strided split -/

/-- The strided sublist of `xs` with stride `w` and offset `l`: the elements at the positions
`p` with `p % w = l`, in order. For `l ≥ w` it is empty when `w > 0`. -/
def stride {α : Type} (w l : Nat) (xs : List α) : List α :=
  (xs.zipIdx.filter fun p => p.2 % w == l).map Prod.fst

/-- **The strided lists partition the sum**: in every commutative monoid, for every `w > 0`, map
`g` and list `xs`, the sum over `l < w` of the sums of `g` over `stride w l xs` is the sum of `g`
over `xs`. -/
theorem sum_stride {α M : Type} [AddCommMonoid M] {w : Nat} (hw : 0 < w) (g : α → M)
    (xs : List α) :
    ((List.range w).map fun l => ((stride w l xs).map g).sum).sum = (xs.map g).sum := by
  suffices h : ∀ s, ((List.range w).map fun l =>
      ((((xs.zipIdx s).filter fun p => p.2 % w == l).map Prod.fst).map g).sum).sum =
        (xs.map g).sum from h 0
  induction xs with
  | nil => intro s; simp
  | cons x xs ih =>
    intro s
    have hs : ((List.range w).map fun l => if s % w = l then g x else 0).sum = g x := by
      rw [List.sum_map_eq_nsmul_single (s % w) _ (fun l hl _ => by simp [Ne.symm hl]),
        List.count_eq_one_of_mem List.nodup_range (List.mem_range.2 (Nat.mod_lt _ hw))]
      simp
    rw [List.map_cons, List.sum_cons, ← ih (s + 1), ← hs, ← List.sum_map_add]
    congr 1
    refine List.map_congr_left fun l _ => ?_
    by_cases h : s % w = l <;> simp [List.zipIdx_cons, h]

/-- **The length of a strided list**: for all `l < w` and every list `xs` of length `K`,
`stride w l xs` has `K / w` elements, plus one when `l < K % w` (Mathlib's `Nat.count_modEq_card`
for the positions below `K`). -/
theorem length_stride {α : Type} {w l : Nat} (hl : l < w) (xs : List α) :
    (stride w l xs).length = xs.length / w + if l < xs.length % w then 1 else 0 := by
  have h : ∀ (ys : List α) s, ((ys.zipIdx s).filter fun p => p.2 % w == l).length =
      (List.range' s ys.length).countP fun k => k % w == l := by
    intro ys
    induction ys with
    | nil => intro s; simp
    | cons y ys ih =>
      intro s
      rw [List.zipIdx_cons, List.length_cons, List.range'_succ, List.countP_cons, ← ih (s + 1),
        List.filter_cons]
      split <;> simp_all
  rw [stride, List.length_map, h, ← List.range_eq_range']
  have e := Nat.count_modEq_card xs.length (Nat.zero_lt_of_lt hl) l
  rw [Nat.mod_eq_of_lt hl] at e
  rw [← e, Nat.count]
  congr 1
  funext k
  exact Bool.eq_iff_iff.2 (by simp [Nat.ModEq, Nat.mod_eq_of_lt hl])

/-- For all `l < w` and every list `xs` of length `K`, `stride w l xs` has at most
`⌈K / w⌉ = (K + w - 1) / w` elements (`length_stride`). -/
theorem length_stride_le {α : Type} {w l : Nat} (hl : l < w) (xs : List α) :
    (stride w l xs).length ≤ (xs.length + w - 1) / w := by
  have hw := Nat.zero_lt_of_lt hl
  rw [length_stride hl, Nat.le_div_iff_mul_le hw, Nat.add_mul]
  have h1 := Nat.mod_add_div xs.length w
  have h2 := Nat.mod_lt xs.length hw
  rw [Nat.mul_comm] at h1
  split <;> omega

/-! ## The exact value -/

/-- **The butterfly of the exact strided sums is the whole sum**: in every commutative monoid, for
all offsets `ms`, lanes `l` and widths `w` such that the leaves of lane `l`'s tree are the lanes
`0, ..., w - 1`, each once (`leaves_warp`: every `l < 32` at `warpOffsets` with `w = 32`), every
map `g` and list `xs`, lane `l`'s value after the rounds of `+` from lane `j`'s sum of `g` over
`stride w j xs` is the sum of `g` over `xs`. -/
theorem bfly_stride {α M : Type} [AddCommMonoid M] {ms : List Nat} {w l : Nat}
    (hp : (bflyTree ms l).leaves.Perm (List.range w)) (g : α → M) (xs : List α) :
    bflyRounds (· + ·) ms (fun j => ((stride w j xs).map g).sum) l = (xs.map g).sum := by
  have hw : 0 < w := by
    have := hp.length_eq
    rw [ReductionTree.length_leaves, List.length_range] at this
    omega
  rw [← eval_bflyTree, ReductionTree.eval_add_eq_sum, (hp.map _).sum_eq, sum_stride hw]

/-- The factor pairs of entry `j` of the product of the vector `v` (length `m`) and the matrix
`A` (`m × n`) of words of any format: `(v.getScalar k, get2 A k j)` for `k = 0, …, m - 1`, in that
order. -/
def vecMatPairs (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n]) (j : Fin n) :
    List (Model fmt × Model fmt) :=
  List.ofFn fun k => (v.getScalar k, Tensor.get2 A k j)

/-- **The exact gevm cell is TorchLean's real vector-matrix product**: in every format, for all
sizes, vectors `v` (length `m`), matrices `A` (`m × n`) of words and indices `j`, the sum of the
products of the real values of `vecMatPairs v A j` is entry `j` of TorchLean's
`contract v' A' _ _ [n] .vecMat` over `ℝ`, with `v'`, `A'` the maps of `v`, `A` by
`Model.toReal`. -/
theorem vecMat_cell_real (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n])
    (j : Fin n) :
    ((vecMatPairs v A j).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      (Tensor.contract (Tensor.map Model.toReal v) (Tensor.map Model.toReal A) _ _ [n]
        .vecMat).getScalar j := by
  rw [Tensor.getScalar_contract_vecMat]
  simp only [Tensor.get2, Tensor.unstack_map, Tensor.getScalar_map]
  exact dotSum_ofFn _

/-- **The exact warp value of a gemv row is TorchLean's real matrix-vector entry**: in every
format, for all sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices `i`, offsets,
lanes `l` and widths `w` whose lanes are lane `l`'s leaves once (`bfly_stride`), the rounds of `+`
over the exact sums of the strided lists of `matVecPairs A v i` give entry `i` of
`contract A' v' _ _ [m] .matVec` over `ℝ`, with `A'`, `v'` the maps by `Model.toReal`. -/
theorem bfly_matVec (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n]) (i : Fin m)
    {ms : List Nat} {w l : Nat} (hp : (bflyTree ms l).leaves.Perm (List.range w)) :
    bflyRounds (· + ·) ms (fun j => ((stride w j (matVecPairs A v i)).map fun ab =>
        ab.1.toReal * ab.2.toReal).sum) l =
      (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
        .matVec).getScalar i :=
  (bfly_stride hp _ _).trans (matVec_cell_real A v i)

/-- **The exact warp value of a gevm column is TorchLean's real vector-matrix entry**: in every
format, for all sizes, vectors `v` (length `m`), matrices `A` (`m × n`), indices `j`, offsets,
lanes `l` and widths `w` whose lanes are lane `l`'s leaves once (`bfly_stride`), the rounds of `+`
over the exact sums of the strided lists of `vecMatPairs v A j` give entry `j` of
`contract v' A' _ _ [n] .vecMat` over `ℝ`, with `v'`, `A'` the maps by `Model.toReal`. -/
theorem bfly_vecMat (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n]) (j : Fin n)
    {ms : List Nat} {w l : Nat} (hp : (bflyTree ms l).leaves.Perm (List.range w)) :
    bflyRounds (· + ·) ms (fun k => ((stride w k (vecMatPairs v A j)).map fun ab =>
        ab.1.toReal * ab.2.toReal).sum) l =
      (Tensor.contract (Tensor.map Model.toReal v) (Tensor.map Model.toReal A) _ _ [n]
        .vecMat).getScalar j :=
  (bfly_stride hp _ _).trans (vecMat_cell_real v A j)

/-! ## The roundoff with contraction allowed -/

/-- The warp's dot product of the factor pairs `ps`: lane 0's value after the five butterfly
rounds of FloatLib's `Model.add` at `warpOffsets`, from lane `l`'s contracted loop
`dotLoop c (o l)` from `+0` over `stride 32 l ps`, with the flag `c` and lane `l`'s oracle
numbers `o l`. -/
def warpDot (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt)) :
    Model fmt :=
  bflyRounds (fun x y => Model.add x y) warpOffsets
    (fun l => dotLoop c (o l) (Model.zero fmt false) (stride 32 l ps)) 0

/-- The roundoff bound of `bfly_stride_error` for `w` loops of at most `n` iterations each and
`d` rounds, at the exact absolute sum `T`: `((1 + u) ^ (n + d + 1) - 1) T +
w (1 + u) ^ d (2 + u) η ((1 + u) ^ n - 1) / u`, with `u` FloatLib's unit roundoff and `η` its
underflow allowance of `fmt`. -/
noncomputable def warpBound (fmt : FloatFormat) (n d w : Nat) (T : ℝ) : ℝ :=
  ((1 + Model.unitRoundoffAt fmt) ^ (n + d + 1) - 1) * T +
    w * (1 + Model.unitRoundoffAt fmt) ^ d * ((2 + Model.unitRoundoffAt fmt) *
      Model.underflowErrorAt fmt * ((1 + Model.unitRoundoffAt fmt) ^ n - 1) /
        Model.unitRoundoffAt fmt)

/-- **The roundoff of a butterfly over strided loops**: in every IEEE format, for every flag `c`,
oracle family `o` (each iteration of each loop fused or not, as `o` chooses), list of factor pairs
`ps`, offsets `ms`, lane `l` and width `w` whose lanes are lane `l`'s leaves once (`bfly_stride`),
and every `n` at least the length of each list `stride w j ps` with `j < w`: if lane `l`'s value
`r` after the rounds of `Model.add` over the loops `dotLoop c (o j)` from `+0` is finite, then
`|r - Σ aₖ bₖ| ≤ warpBound fmt n ms.length w T`, with `T = Σ |aₖ bₖ|` over the real values of the
words. Each loop is finite (`bfly_add_error`) and within its `dotLoop_error` bound; the butterfly
adds `bfly_add_error`'s. Nothing is claimed when `r` is infinite or a NaN. -/
theorem bfly_stride_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) {ms : List Nat} {w l n : Nat}
    (hp : (bflyTree ms l).leaves.Perm (List.range w))
    (hn : ∀ j < w, (stride w j ps).length ≤ n)
    (h : (bflyRounds (fun x y => Model.add x y) ms
      (fun j => dotLoop c (o j) (Model.zero fmt false) (stride w j ps)) l).isFinite = true) :
    |(bflyRounds (fun x y => Model.add x y) ms
        (fun j => dotLoop c (o j) (Model.zero fmt false) (stride w j ps)) l).toReal -
        (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      warpBound fmt n ms.length w (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have hw : 0 < w := by
    have := hp.length_eq
    rw [ReductionTree.length_leaves, List.length_range] at this
    omega
  set v : Nat → Model fmt := fun j => dotLoop c (o j) (Model.zero fmt false) (stride w j ps)
  obtain ⟨hfin, htree⟩ := bfly_add_error hfmt v hp h
  set R := (bflyRounds (fun x y => Model.add x y) ms v l).toReal
  set u := Model.unitRoundoffAt fmt with hu_def
  have hu : 0 < u := Model.unitRoundoffAt_pos fmt
  have hη : 0 < Model.underflowErrorAt fmt := Model.underflowErrorAt_pos fmt
  set E := (2 + u) * Model.underflowErrorAt fmt * ((1 + u) ^ n - 1) / u with hE
  set P : Nat → ℝ := fun j => ((stride w j ps).map fun ab => ab.1.toReal * ab.2.toReal).sum
  set Q : Nat → ℝ := fun j => ((stride w j ps).map fun ab => |ab.1.toReal * ab.2.toReal|).sum
  have hr : ∀ f : Nat → ℝ, ((List.range w).map f).sum = ∑ j ∈ Finset.range w, f j := fun f => by
    rw [Finset.sum_eq_multiset_sum, Finset.range_val, Multiset.range, Multiset.map_coe,
      Multiset.sum_coe]
  have hQ : ∀ j, |P j| ≤ Q j := fun j => by
    have := Multiset.abs_sum_le_sum_abs (s := (((stride w j ps).map fun ab =>
      ab.1.toReal * ab.2.toReal : List ℝ) : Multiset ℝ))
    rwa [Multiset.sum_coe, Multiset.map_coe, Multiset.sum_coe, List.map_map] at this
  have hQ0 : ∀ j, 0 ≤ Q j := fun j => (abs_nonneg _).trans (hQ j)
  have hlane : ∀ j ∈ Finset.range w, |(v j).toReal - P j| ≤
      ((1 + u) ^ (n + 1) - 1) * Q j + E := by
    intro j hj
    have hj := Finset.mem_range.1 hj
    refine (dotLoop_error hfmt c (o j) (stride w j ps) (hfin j hj)).trans ?_
    have hk := hn j hj
    unfold dotBound
    rw [← hu_def]
    have p1 : (1 + u) ^ ((stride w j ps).length + 1) ≤ (1 + u) ^ (n + 1) :=
      pow_le_pow_right₀ (by linarith) (by omega)
    have p2 : (1 + u) ^ (stride w j ps).length ≤ (1 + u) ^ n := pow_le_pow_right₀ (by linarith) hk
    have q1 : ((1 + u) ^ ((stride w j ps).length + 1) - 1) * Q j ≤
        ((1 + u) ^ (n + 1) - 1) * Q j :=
      mul_le_mul_of_nonneg_right (by linarith) (hQ0 j)
    have q2 : (2 + u) * Model.underflowErrorAt fmt * ((1 + u) ^ (stride w j ps).length - 1) / u ≤
        E :=
      div_le_div_of_nonneg_right (mul_le_mul_of_nonneg_left (by linarith)
        (mul_nonneg (by linarith) hη.le)) hu.le
    linarith
  have hS : ∑ j ∈ Finset.range w, P j = (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum := by
    rw [← hr]; exact sum_stride hw _ ps
  have hT : ∑ j ∈ Finset.range w, Q j = (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
    rw [← hr]; exact sum_stride hw _ ps
  rw [hr, hr] at htree
  rw [← hS, ← hT]
  have hV : |∑ j ∈ Finset.range w, (v j).toReal - ∑ j ∈ Finset.range w, P j| ≤
      ∑ j ∈ Finset.range w, (((1 + u) ^ (n + 1) - 1) * Q j + E) := by
    rw [← Finset.sum_sub_distrib]
    exact (Finset.abs_sum_le_sum_abs _ _).trans (Finset.sum_le_sum hlane)
  have hA : ∑ j ∈ Finset.range w, |(v j).toReal| ≤
      ∑ j ∈ Finset.range w, Q j + ∑ j ∈ Finset.range w, (((1 + u) ^ (n + 1) - 1) * Q j + E) := by
    rw [← Finset.sum_add_distrib]
    refine Finset.sum_le_sum fun j hj => ?_
    have := hlane j hj
    have := abs_sub_abs_le_abs_sub (v j).toReal (P j)
    linarith [hQ j]
  have hB : ∑ j ∈ Finset.range w, (((1 + u) ^ (n + 1) - 1) * Q j + E) =
      ((1 + u) ^ (n + 1) - 1) * ∑ j ∈ Finset.range w, Q j + w * E := by
    rw [Finset.sum_add_distrib, ← Finset.mul_sum, Finset.sum_const, Finset.card_range,
      nsmul_eq_mul]
  have hK : 0 ≤ (1 + u) ^ ms.length - 1 := by
    have := one_le_pow₀ (n := ms.length) (by linarith : (1 : ℝ) ≤ 1 + u)
    linarith
  have h3 := mul_le_mul_of_nonneg_left hA hK
  have h1 := abs_sub_le R (∑ j ∈ Finset.range w, (v j).toReal) (∑ j ∈ Finset.range w, P j)
  rw [hB] at hV h3
  have hpow : (1 + u) ^ (n + ms.length + 1) = (1 + u) ^ ms.length * (1 + u) ^ (n + 1) := by
    rw [← pow_add]; congr 1; omega
  have key : ((1 + u) ^ ms.length - 1) * (∑ j ∈ Finset.range w, Q j +
      (((1 + u) ^ (n + 1) - 1) * ∑ j ∈ Finset.range w, Q j + w * E)) +
      (((1 + u) ^ (n + 1) - 1) * ∑ j ∈ Finset.range w, Q j + w * E) =
      ((1 + u) ^ ms.length * (1 + u) ^ (n + 1) - 1) * ∑ j ∈ Finset.range w, Q j +
        w * (1 + u) ^ ms.length * E := by ring
  unfold warpBound
  rw [← hu_def, hpow, ← hE]
  linarith

/-- **The roundoff of the warp's dot product**: in every IEEE format, for every flag `c`, oracle
family `o` (each iteration fused or not) and list of `K` factor pairs `ps`, if `warpDot c o ps` is
finite, it is within `warpBound fmt ⌈K / 32⌉ 5 32 T` of `Σ aₖ bₖ`, with `T = Σ |aₖ bₖ|`:
`bfly_stride_error` at `leaves_warp` and `length_stride_le`. Nothing is claimed when the result
is infinite or a NaN. -/
theorem warpDot_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) (h : (warpDot c o ps).isFinite = true) :
    |(warpDot c o ps).toReal - (ps.map fun ab => ab.1.toReal * ab.2.toReal).sum| ≤
      warpBound fmt ((ps.length + 31) / 32) 5 32
        (ps.map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  bfly_stride_error hfmt c o ps (leaves_warp 0 (by decide)) (fun _ hj => length_stride_le hj ps) h

/-- **The roundoff of a gemv row's warp value against TorchLean's real matrix-vector product**: in
every IEEE format, for all sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices `i`,
every flag `c` and oracle family `o`, if `warpDot c o (matVecPairs A v i)` is finite, it is within
`warpBound fmt ⌈n / 32⌉ 5 32 T` of entry `i` of `contract A' v' _ _ [m] .matVec`, with `A'`, `v'`
the maps by `Model.toReal` and `T = Σₖ |aᵢₖ vₖ|` (`warpDot_error`, `matVec_cell_real`). -/
theorem warpDot_matVec (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n]) (i : Fin m)
    (h : (warpDot c o (matVecPairs A v i)).isFinite = true) :
    |(warpDot c o (matVecPairs A v i)).toReal -
        (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
          .matVec).getScalar i| ≤
      warpBound fmt ((n + 31) / 32) 5 32
        ((matVecPairs A v i).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have e := warpDot_error hfmt c o _ h
  rwa [matVec_cell_real, show (matVecPairs A v i).length = n from List.length_ofFn] at e

/-- **The roundoff of a gevm column's warp value against TorchLean's real vector-matrix
product**: in every IEEE format, for all sizes, vectors `v` (length `m`), matrices `A`
(`m × n`), indices `j`, every flag `c` and oracle family `o`, if
`warpDot c o (vecMatPairs v A j)` is finite, it is within `warpBound fmt ⌈m / 32⌉ 5 32 T` of
entry `j` of `contract v' A' _ _ [n] .vecMat`, with `v'`, `A'` the maps by `Model.toReal` and
`T = Σₖ |vₖ aₖⱼ|` (`warpDot_error`, `vecMat_cell_real`). -/
theorem warpDot_vecMat (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n]) (j : Fin n)
    (h : (warpDot c o (vecMatPairs v A j)).isFinite = true) :
    |(warpDot c o (vecMatPairs v A j)).toReal -
        (Tensor.contract (Tensor.map Model.toReal v) (Tensor.map Model.toReal A) _ _ [n]
          .vecMat).getScalar j| ≤
      warpBound fmt ((m + 31) / 32) 5 32
        ((vecMatPairs v A j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have e := warpDot_error hfmt c o _ h
  rwa [vecMat_cell_real, show (vecMatPairs v A j).length = m from List.length_ofFn] at e

/-! ## Without contraction -/

/-- **Butterfly rounds respect `NaNEq`**, in every format: for all operations `f` and `g` that
give the same word or both NaNs on operands that are the same word or both NaNs, offsets `ms`,
values `v`, `v'` that are lane by lane the same word or both NaNs, and every lane, the value after
the rounds of `f` over `v` and the value after the rounds of `g` over `v'` are the same word or
both NaNs. At `f = g = Model.add` (`NaNEq.op`) it is the rounds of `warpDot`; at
`f x y = deliver (Model.add x y) n` and `g = Model.add` (`nanEq_deliver`) it carries the
semantics' `fadd` at the oracle number `n` through the rounds. -/
theorem bflyRounds_nanEq {f g : Model fmt → Model fmt → Model fmt}
    (hf : ∀ x x' y y', NaNEq x x' → NaNEq y y' → NaNEq (f x y) (g x' y'))
    (ms : List Nat) {v v' : Nat → Model fmt} (h : ∀ j, NaNEq (v j) (v' j)) (l : Nat) :
    NaNEq (bflyRounds f ms v l) (bflyRounds g ms v' l) := by
  induction ms generalizing v v' with
  | nil => exact h l
  | cons m ms ih => exact ih fun j => hf _ _ _ _ (h j) (h (j ^^^ m))

/-- **A butterfly over strided loops without contraction is FloatLib's scheduled reduction**, up
to NaNs: in every format, for every flag `c` and oracle family `o` with the contraction off (`c`
false, or no `fadd` oracle number 2 modulo 3), list of factor pairs `ps`, offsets `ms`, stride `w`
and lane `l`, lane `l`'s value after the rounds of `Model.add` over the loops `dotLoop c (o j)`
from `+0` over `stride w j ps`, and FloatLib's `Model.reduceAlong fmt fmt` along lane `l`'s tree
`bflyTree ms l` of the terms `Model.dotInOrder fmt fmt (stride w j ps)`, are the same word or both
NaNs (`dotLoop_nanEq` at each lane, `bflyRounds_nanEq`). -/
theorem bfly_stride_nanEq (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) (ms : List Nat) (w l : Nat)
    (hu : ∀ j k, c = true → (o j k).2 % 3 ≠ 2) :
    NaNEq (bflyRounds (fun x y => Model.add x y) ms
        (fun j => dotLoop c (o j) (Model.zero fmt false) (stride w j ps)) l)
      (Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride w j ps))
        (bflyTree ms l)) := by
  rw [Model.reduceAlong, eval_bflyTree]
  exact (bflyRounds_nanEq
    (fun _ _ _ _ => NaNEq.op (op := .fadd) (f := fun x y => Model.add x y) rfl)
    ms (fun j => dotLoop_nanEq c (o j) _ (hu j)) l).trans
    (cast_self_nanEq _).symm

/-- **The warp's dot product without contraction is FloatLib's fixed-order reduction**, up to
NaNs: in every format, for every flag `c`, oracle family `o` with the contraction off and list of
factor pairs `ps`, `warpDot c o ps` and FloatLib's `Model.reduceAlong fmt fmt` along lane 0's
tree `bflyTree warpOffsets 0` of the in-order dot products of the 32 strided lists are the same
word or both NaNs (`bfly_stride_nanEq`). -/
theorem warpDot_nanEq (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j k, c = true → (o j k).2 % 3 ≠ 2) :
    NaNEq (warpDot c o ps)
      (Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride 32 j ps))
        (bflyTree warpOffsets 0)) :=
  bfly_stride_nanEq c o ps warpOffsets 32 0 hu

/-- The two halves of `warpDot_nanEq`, under its premises (every format, the contraction off):
when FloatLib's reduction along `bflyTree warpOffsets 0` of the 32 in-order dot products is not a
NaN, `warpDot c o ps` is that word, bit for bit; and `warpDot c o ps` is a NaN exactly when
FloatLib's word is. -/
theorem warpDot_eq (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j k, c = true → (o j k).2 % 3 ≠ 2) :
    ((Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride 32 j ps))
        (bflyTree warpOffsets 0)).isNaN = false →
        warpDot c o ps = Model.reduceAlong fmt fmt
          (fun j => Model.dotInOrder fmt fmt (stride 32 j ps)) (bflyTree warpOffsets 0)) ∧
      (warpDot c o ps).isNaN = (Model.reduceAlong fmt fmt
        (fun j => Model.dotInOrder fmt fmt (stride 32 j ps)) (bflyTree warpOffsets 0)).isNaN :=
  (warpDot_nanEq c o ps hu).eq_isNaN

end MojoProof.Sem
