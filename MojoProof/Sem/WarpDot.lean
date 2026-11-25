import MojoProof.Sem.Bfly
import MojoProof.Sem.Matmul
import Mathlib.Data.Int.CardIntervalMod

/-!
# The warp's dot product: strided loops and a butterfly (docs/proofs/warp-dot.md)

Both kernels of tests/corpus/gemv/ compute a dot product the same way: the factor pairs are split
by position modulo 32 into 32 strided lists, lane `l` folds list `l` from `+0` with the contracted
loop `dotLoop`, and the five butterfly rounds at the offsets `warpOffsets` add the 32 lanes' sums,
lane 0's result being the output. In gemv_kernel, lane `l` of row `i`'s warp folds the pairs
`(a[i, 32 j + l], b[32 j + l])`
(gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, lines 89-101; rounds at
113-132, lane 0's store at 136); in gevm_kernel, thread `(w, l)` folds
`(a[32 j + w], b[32 j + w, 32 β + l])`, the sums are transposed through shared memory, and the
same rounds give column `32 β + w`'s total at lane 0
(gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll, lines 60-69 for the loop,
74-82 for the transposition, 83-102 for the rounds, 115 for the store). This module states that
value once, for every group of `2 ^ k` lanes (the warp is `k = 5`), every format, every length
and every oracle; a kernel's theorem is then a corollary at its pairs (`matVecPairs`,
`vecMatPairs`).

Definitions:
* `stride w l xs`: the elements of `xs` at the positions `≡ l (mod w)`, in order.
* `vecMatPairs v A j`: the factor pairs `(v.getScalar k, get2 A k j)` of entry `j` of the product
  of the vector `v` and the matrix `A` (TorchLean's `contract v A _ _ [n] .vecMat`).
* `groupDot k c o ps`: lane 0's value after the `k` rounds of FloatLib's `Model.add` at the
  offsets `bflyOffsets k`, from lane `l`'s value `dotLoop c (o l) (Model.zero fmt false)
  (stride (2 ^ k) l ps)`, for a group of `2 ^ k` lanes; `warpDot` is `groupDot 5`, a warp's
  five rounds at `warpOffsets` over the 32 lanes. The kernels' `fadd` of a round goes through
  `deliver`, which changes only a NaN result (`nanEq_deliver`); `groupDot` adds without it.

Proved:
* `sum_stride`, `length_stride`, `length_stride_le`: for every `w > 0`, the sums over the `w`
  strided lists add up to the sum over the list, in every commutative monoid; list `l < w` has
  `K / w + [l < K % w]` elements, at most `⌈K / w⌉`, for a list of length `K`.
* `bfly_stride`: for all offsets, lanes `l` and widths `w` such that lane `l`'s tree has the
  lanes below `w` as leaves, each once (`leaves_warp` at a warp), the rounds of `+` over the exact
  strided sums give the sum over the list, in every commutative monoid. Over `ℝ`, for the
  products of the real values: `bfly_matVec`, TorchLean's real matrix-vector entry, and
  `bfly_vecMat` (with `vecMat_cell_real`), its real vector-matrix entry.
* `bfly_stride_error`, `groupDot_error`, `groupDot_matVec`, `groupDot_vecMat`: in every IEEE
  format, for every flag and oracle family (each iteration fused or not), a finite result is
  within the error of `GPUProof.laneGrade (.ieee fmt) W d L n` at the real values of the words
  with the grades `⟨0, 0⟩`, `((1 + u) ^ (L + d) - 1) T + W (1 + u) ^ d (2 + u) η
  ((1 + u) ^ L - 1) / u`, of the exact sum, with `T` the sum of the absolute products, `L` a bound
  on the lists' lengths, `d` the number of rounds, `u` FloatLib's unit roundoff and `η` its
  underflow allowance; for `groupDot k` over `n` pairs, `L = ⌈n / 2 ^ k⌉`, `d = k`, `W = 2 ^ k`,
  and the exact sum is TorchLean's real matrix-vector or vector-matrix entry. Each is
  `treeDot_error` (MojoProof/Sem/Dot.lean) along lane 0's tree, with no induction of its own.
  `warpDot_error`, `warpDot_matVec` and `warpDot_vecMat` are their cases `k = 5`.
* `bflyRounds_nanEq`, for all operations `f`, `g` that respect `NaNEq` together: the rounds of
  `f` and of `g` over values that are lane by lane `NaNEq` are `NaNEq`; so the rounds of the
  semantics' `fadd` at one oracle number `n`, `deliver (Model.add x y) n`, are those of
  `Model.add` up to NaNs.
* `bflyRoundsAt_nanEq`, `bflyDeliver_nanEq`, `bflyDeliver_error`: the same with a combination
  per round and lane (`bflyRoundsAt`, MojoProof/Sem/Bfly.lean), so the semantics' `fadd` rounds
  with an oracle number for every round and lane are `Model.add`'s up to NaNs, and, in every IEEE
  format, a finite lane value of them is the `Model.add` rounds' and within `bfly_add_error`'s
  bound of the exact sum.
* `bfly_stride_nanEq`, `groupDot_nanEq`, `groupDot_eq`: with the contraction off, the result and
  FloatLib's `Model.reduceAlong` along lane 0's tree `bflyTree (bflyOffsets k) 0` of FloatLib's
  in-order dot products `Model.dotInOrder` of the `2 ^ k` lists are the same word or both NaNs;
  `warpDot_nanEq` and `warpDot_eq` are their cases `k = 5`.

That a grid run of either kernel computes `warpDot` of its loaded pairs is not proved here. The
instances at 40 pairs, over 32 lanes and over 8, are in MojoProofTest/WarpDot.lean.
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

/-- The dot product of the factor pairs `ps` over a group of `2 ^ k` lanes: lane 0's value after
the `k` butterfly rounds of FloatLib's `Model.add` at `bflyOffsets k`, from lane `l`'s contracted
loop `dotLoop c (o l)` from `+0` over `stride (2 ^ k) l ps`, with the flag `c` and lane `l`'s
oracle numbers `o l`. -/
def groupDot (k : Nat) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) : Model fmt :=
  bflyRounds (fun x y => Model.add x y) (bflyOffsets k)
    (fun l => dotLoop c (o l) (Model.zero fmt false) (stride (2 ^ k) l ps)) 0

/-- The warp's dot product of the factor pairs `ps`: `groupDot 5`, lane 0's value after the five
butterfly rounds of FloatLib's `Model.add` at `warpOffsets`, from lane `l`'s contracted loop
`dotLoop c (o l)` from `+0` over `stride 32 l ps`, with the flag `c` and lane `l`'s oracle
numbers `o l`. -/
def warpDot (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt)) :
    Model fmt :=
  groupDot 5 c o ps

/-- **The roundoff of a butterfly over strided loops is `GPUProof.laneGrade`'s**: in every IEEE
format, for every flag `c`, oracle family `o` (each iteration of each loop fused or not, as `o`
chooses), words `w k`, `v k` for `k < n`, offsets `ms`, lane `l` and width `W` whose lanes are lane
`l`'s leaves once (`bfly_stride`), and every `L` at least the length of each list `stride W j` of
the pairs `(w k, v k)` with `j < W`: if lane `l`'s value `r` after the rounds of `Model.add` over
the loops `dotLoop c (o j)` from `+0` is finite, then `|r - Σₖ wₖ vₖ|` (real values) is at most
the error of `laneGrade (.ieee fmt) W d L n` at the real values with the grades `⟨0, 0⟩`, which
is `((1 + u) ^ (L + d) - 1) T + W (1 + u) ^ d (2 + u) η ((1 + u) ^ L - 1) / u`, with
`d = ms.length`, `T = Σₖ |wₖ vₖ|`, `u` FloatLib's unit roundoff and `η` its underflow allowance.
Lane `l`'s value is `treeDot` along `bflyTree ms l` (`eval_bflyTree`, `depth_bflyTree`), so this
is `treeDot_error` at exact inputs. Nothing is claimed when `r` is infinite or a NaN. -/
theorem bfly_stride_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (w v : Fin n → Model fmt) {ms : List Nat} {W l L : Nat}
    (hp : (bflyTree ms l).leaves.Perm (List.range W))
    (hL : ∀ j < W, (stride W j (List.ofFn fun k => (w k, v k))).length ≤ L)
    (h : (bflyRounds (fun x y => Model.add x y) ms (fun j => dotLoop c (o j)
      (Model.zero fmt false) (stride W j (List.ofFn fun k => (w k, v k)))) l).isFinite = true) :
    |(bflyRounds (fun x y => Model.add x y) ms (fun j => dotLoop c (o j)
        (Model.zero fmt false) (stride W j (List.ofFn fun k => (w k, v k)))) l).toReal -
        ∑ k, (w k).toReal * (v k).toReal| ≤
      (GPUProof.laneGrade (.ieee fmt) W ms.length L n (fun k => (w k).toReal)
        (fun k => (v k).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err := by
  have hW : 0 < W := by
    have := hp.length_eq
    rw [ReductionTree.length_leaves, List.length_range] at this
    omega
  have hs : ∀ g : Model fmt × Model fmt → ℝ, ∑ j ∈ Finset.range W,
      ((stride W j (List.ofFn fun k => (w k, v k))).map g).sum = ∑ k, g (w k, v k) := fun g => by
    rw [Finset.sum_eq_multiset_sum, Finset.range_val, Multiset.range, Multiset.map_coe,
      Multiset.sum_coe, sum_stride hW, List.map_ofFn, List.sum_ofFn]
    rfl
  have e := treeDot_error hfmt c o (bflyTree ms l) hp _ hL w v hs (fun k => (w k).toReal)
    (fun k => (v k).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩) (fun _ => by simp)
    (fun _ => by simp) (by rwa [treeDot, eval_bflyTree])
  rwa [depth_bflyTree, treeDot, eval_bflyTree] at e

/-- **The roundoff of a lane group's dot product is `GPUProof.laneGrade`'s**: in every IEEE
format, for every `k` (a group of `2 ^ k` lanes), flag `c`, oracle family `o` (each iteration
fused or not) and words `w i`, `v i` for `i < n`, if `groupDot k c o` of the pairs `(w i, v i)` is
finite, it is within the error of `laneGrade (.ieee fmt) (2 ^ k) k ⌈n / 2 ^ k⌉ n` at the real
values with the grades `⟨0, 0⟩` of `Σᵢ wᵢ vᵢ`: `bfly_stride_error` at `leaves_offsets` and
`length_stride_le`. Nothing is claimed when the result is infinite or a NaN. -/
theorem groupDot_error (hfmt : fmt.isIEEE = true) (k : Nat) (c : Bool)
    (o : Nat → Nat → Nat × Nat) (w v : Fin n → Model fmt)
    (h : (groupDot k c o (List.ofFn fun i => (w i, v i))).isFinite = true) :
    |(groupDot k c o (List.ofFn fun i => (w i, v i))).toReal - ∑ i, (w i).toReal * (v i).toReal| ≤
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((n + (2 ^ k - 1)) / 2 ^ k) n
        (fun i => (w i).toReal) (fun i => (v i).toReal) (fun _ => ⟨0, 0⟩)
        (fun _ => ⟨0, 0⟩)).err := by
  have e := bfly_stride_error hfmt c o w v (leaves_offsets k 0 (Nat.two_pow_pos k))
    (fun _ hj => (length_stride_le hj _).trans_eq
      (by rw [List.length_ofFn, Nat.add_sub_assoc Nat.one_le_two_pow])) h
  rwa [show (bflyOffsets k).length = k by simp [bflyOffsets]] at e

/-- **The roundoff of the warp's dot product is `GPUProof.laneGrade`'s**: in every IEEE format, for
every flag `c`, oracle family `o` (each iteration fused or not) and words `w i`, `v i` for `i < n`,
if `warpDot c o` of the pairs `(w i, v i)` is finite, it is within the error of
`laneGrade (.ieee fmt) 32 5 ⌈n / 32⌉ n` at the real values with the grades `⟨0, 0⟩` of
`Σᵢ wᵢ vᵢ`: `groupDot_error` at `k = 5`. Nothing is claimed when the result is infinite or a
NaN. -/
theorem warpDot_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (w v : Fin n → Model fmt) (h : (warpDot c o (List.ofFn fun i => (w i, v i))).isFinite = true) :
    |(warpDot c o (List.ofFn fun i => (w i, v i))).toReal - ∑ i, (w i).toReal * (v i).toReal| ≤
      (GPUProof.laneGrade (.ieee fmt) 32 5 ((n + 31) / 32) n (fun i => (w i).toReal)
        (fun i => (v i).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err :=
  groupDot_error hfmt 5 c o w v h

/-- **The roundoff of a gemv row's group value against TorchLean's real matrix-vector product**:
in every IEEE format, for all sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices
`i`, every `k` (a group of `2 ^ k` lanes), flag `c` and oracle family `o`, if
`groupDot k c o (matVecPairs A v i)` is finite, it is within the error of
`laneGrade (.ieee fmt) (2 ^ k) k ⌈n / 2 ^ k⌉ n` at the real values of row `i` and `v` with the
grades `⟨0, 0⟩` of entry `i` of `contract A' v' _ _ [m] .matVec`, with `A'`, `v'` the maps by
`Model.toReal` (`groupDot_error`, `matVec_cell_real`). -/
theorem groupDot_matVec (hfmt : fmt.isIEEE = true) (k : Nat) (c : Bool)
    (o : Nat → Nat → Nat × Nat) (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n])
    (i : Fin m) (h : (groupDot k c o (matVecPairs A v i)).isFinite = true) :
    |(groupDot k c o (matVecPairs A v i)).toReal -
        (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
          .matVec).getScalar i| ≤
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((n + (2 ^ k - 1)) / 2 ^ k) n
        (fun j => (Tensor.get2 A i j).toReal) (fun j => (v.getScalar j).toReal) (fun _ => ⟨0, 0⟩)
        (fun _ => ⟨0, 0⟩)).err := by
  rw [← matVec_cell_real, matVecPairs, List.map_ofFn, List.sum_ofFn]
  exact groupDot_error hfmt k c o (fun j => Tensor.get2 A i j) (fun j => v.getScalar j) h

/-- **The roundoff of a gemv row's warp value against TorchLean's real matrix-vector product**: in
every IEEE format, for all sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices `i`,
every flag `c` and oracle family `o`, if `warpDot c o (matVecPairs A v i)` is finite, it is within
the error of `laneGrade (.ieee fmt) 32 5 ⌈n / 32⌉ n` at the real values with the grades `⟨0, 0⟩`
of entry `i` of `contract A' v' _ _ [m] .matVec`, with `A'`, `v'` the maps by `Model.toReal`:
`groupDot_matVec` at `k = 5`. -/
theorem warpDot_matVec (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n]) (i : Fin m)
    (h : (warpDot c o (matVecPairs A v i)).isFinite = true) :
    |(warpDot c o (matVecPairs A v i)).toReal -
        (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
          .matVec).getScalar i| ≤
      (GPUProof.laneGrade (.ieee fmt) 32 5 ((n + 31) / 32) n (fun j => (Tensor.get2 A i j).toReal)
        (fun j => (v.getScalar j).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err :=
  groupDot_matVec hfmt 5 c o A v i h

/-- **The roundoff of a gevm column's group value against TorchLean's real vector-matrix
product**: in every IEEE format, for all sizes, vectors `v` (length `m`), matrices `A`
(`m × n`), indices `j`, every `k` (a group of `2 ^ k` lanes), flag `c` and oracle family `o`, if
`groupDot k c o (vecMatPairs v A j)` is finite, it is within the error of
`laneGrade (.ieee fmt) (2 ^ k) k ⌈m / 2 ^ k⌉ m` at the real values of `v` and column `j` with
the grades `⟨0, 0⟩` of entry `j` of `contract v' A' _ _ [n] .vecMat`, with `v'`, `A'` the maps by
`Model.toReal` (`groupDot_error`, `vecMat_cell_real`). -/
theorem groupDot_vecMat (hfmt : fmt.isIEEE = true) (k : Nat) (c : Bool)
    (o : Nat → Nat → Nat × Nat) (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n])
    (j : Fin n) (h : (groupDot k c o (vecMatPairs v A j)).isFinite = true) :
    |(groupDot k c o (vecMatPairs v A j)).toReal -
        (Tensor.contract (Tensor.map Model.toReal v) (Tensor.map Model.toReal A) _ _ [n]
          .vecMat).getScalar j| ≤
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((m + (2 ^ k - 1)) / 2 ^ k) m
        (fun i => (v.getScalar i).toReal) (fun i => (Tensor.get2 A i j).toReal) (fun _ => ⟨0, 0⟩)
        (fun _ => ⟨0, 0⟩)).err := by
  rw [← vecMat_cell_real, vecMatPairs, List.map_ofFn, List.sum_ofFn]
  exact groupDot_error hfmt k c o (fun i => v.getScalar i) (fun i => Tensor.get2 A i j) h

/-- **The roundoff of a gevm column's warp value against TorchLean's real vector-matrix
product**: in every IEEE format, for all sizes, vectors `v` (length `m`), matrices `A`
(`m × n`), indices `j`, every flag `c` and oracle family `o`, if
`warpDot c o (vecMatPairs v A j)` is finite, it is within the error of
`laneGrade (.ieee fmt) 32 5 ⌈m / 32⌉ m` at the real values with the grades `⟨0, 0⟩` of entry `j`
of `contract v' A' _ _ [n] .vecMat`, with `v'`, `A'` the maps by `Model.toReal`:
`groupDot_vecMat` at `k = 5`. -/
theorem warpDot_vecMat (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (v : Tensor (Model fmt) [m]) (A : Tensor (Model fmt) [m, n]) (j : Fin n)
    (h : (warpDot c o (vecMatPairs v A j)).isFinite = true) :
    |(warpDot c o (vecMatPairs v A j)).toReal -
        (Tensor.contract (Tensor.map Model.toReal v) (Tensor.map Model.toReal A) _ _ [n]
          .vecMat).getScalar j| ≤
      (GPUProof.laneGrade (.ieee fmt) 32 5 ((m + 31) / 32) m (fun i => (v.getScalar i).toReal)
        (fun i => (Tensor.get2 A i j).toReal) (fun _ => ⟨0, 0⟩) (fun _ => ⟨0, 0⟩)).err :=
  groupDot_vecMat hfmt 5 c o v A j h

/-! ## Without contraction -/

/-- **Butterfly rounds with a combination per round and lane respect `NaNEq`**, in every format:
for every family `F` of operations and every operation `g` such that `F r l x y` and `g x' y'` are
the same word or both NaNs on operands that are, for every round `r` and lane `l`, offsets `ms`,
values `v`, `v'` that are lane by lane the same word or both NaNs, and every lane, the value after
the rounds of `F` over `v` (`bflyRoundsAt`) and the value after the rounds of `g` over `v'` are
the same word or both NaNs. -/
theorem bflyRoundsAt_nanEq {F : Nat → Nat → Model fmt → Model fmt → Model fmt}
    {g : Model fmt → Model fmt → Model fmt}
    (hF : ∀ r l x x' y y', NaNEq x x' → NaNEq y y' → NaNEq (F r l x y) (g x' y'))
    (ms : List Nat) {v v' : Nat → Model fmt} (h : ∀ j, NaNEq (v j) (v' j)) (l : Nat) :
    NaNEq (bflyRoundsAt F ms v l) (bflyRounds g ms v' l) := by
  induction ms generalizing F v v' with
  | nil => exact h l
  | cons m ms ih =>
    rw [bflyRoundsAt]
    exact ih (fun r => hF (r + 1)) fun j => hF 0 j _ _ _ _ (h j) (h (j ^^^ m))

/-- **Butterfly rounds respect `NaNEq`**, in every format: for all operations `f` and `g` that
give the same word or both NaNs on operands that are the same word or both NaNs, offsets `ms`,
values `v`, `v'` that are lane by lane the same word or both NaNs, and every lane, the value after
the rounds of `f` over `v` and the value after the rounds of `g` over `v'` are the same word or
both NaNs. At `f = g = Model.add` (`NaNEq.op`) it is the rounds of `warpDot`; at
`f x y = deliver (Model.add x y) n` and `g = Model.add` (`nanEq_deliver`) it carries the
semantics' `fadd` at the oracle number `n` through the rounds. `bflyRoundsAt_nanEq` with one
operation in every round and lane. -/
theorem bflyRounds_nanEq {f g : Model fmt → Model fmt → Model fmt}
    (hf : ∀ x x' y y', NaNEq x x' → NaNEq y y' → NaNEq (f x y) (g x' y'))
    (ms : List Nat) {v v' : Nat → Model fmt} (h : ∀ j, NaNEq (v j) (v' j)) (l : Nat) :
    NaNEq (bflyRounds f ms v l) (bflyRounds g ms v' l) := by
  exact bflyRoundsAt_nanEq (F := fun _ _ => f) (fun _ _ => hf) ms h l

/-- **The semantics' `fadd` rounds with an oracle number per round and lane are `Model.add`'s up
to NaNs**, in every format: for every oracle family `o`, offsets `ms`, values `v` and lane `l`,
the value after the rounds of `deliver (Model.add x y) (o r l)` in round `r` at lane `l` and the
value after the rounds of `Model.add` are the same word or both NaNs (`bflyRoundsAt_nanEq` with
`nanEq_deliver`). -/
theorem bflyDeliver_nanEq (o : Nat → Nat → Nat) (ms : List Nat) (v : Nat → Model fmt) (l : Nat) :
    NaNEq (bflyRoundsAt (fun r l x y => deliver (Model.add x y) (o r l)) ms v l)
      (bflyRounds (fun x y => Model.add x y) ms v l) :=
  bflyRoundsAt_nanEq (fun r l _ _ _ _ hx hy => (nanEq_deliver _ (o r l)).trans
      (NaNEq.op (op := .fadd) (f := fun x y => Model.add x y) rfl hx hy))
    ms (fun _ => .inl rfl) l

/-- **The roundoff of the semantics' butterfly with an oracle number per round and lane**: in
every IEEE format, for every oracle family `o`, values `v`, offsets `ms`, lane `l` and width `w`
whose lanes below `w` are the leaves of lane `l`'s tree `bflyTree ms l`, each once (`leaves_warp`
at a warp): if the lane's value after the rounds of `deliver (Model.add x y) (o r l)` is finite,
it is the value after the rounds of `Model.add`, every value below `w` is finite, and it is within
`((1 + u) ^ ms.length - 1) · Σ_{j<w} |v j|` of `Σ_{j<w} v j` (`bflyDeliver_nanEq`,
`bfly_add_error`). Nothing is claimed when the value is infinite or a NaN. -/
theorem bflyDeliver_error (hfmt : fmt.isIEEE = true) (o : Nat → Nat → Nat) (v : Nat → Model fmt)
    {ms : List Nat} {w l : Nat} (hp : (bflyTree ms l).leaves.Perm (List.range w))
    (h : (bflyRoundsAt (fun r l x y => deliver (Model.add x y) (o r l)) ms v l).isFinite = true) :
    bflyRoundsAt (fun r l x y => deliver (Model.add x y) (o r l)) ms v l =
        bflyRounds (fun x y => Model.add x y) ms v l ∧
      (∀ j < w, (v j).isFinite = true) ∧
      |(bflyRoundsAt (fun r l x y => deliver (Model.add x y) (o r l)) ms v l).toReal -
          ((List.range w).map fun j => (v j).toReal).sum| ≤
        ((1 + Model.unitRoundoffAt fmt) ^ ms.length - 1) *
          ((List.range w).map fun j => |(v j).toReal|).sum := by
  have he := (bflyDeliver_nanEq o ms v l).eq_isNaN
  have hq := he.1 (by rw [← he.2]; exact Model.isNaN_eq_false_of_isFinite_eq_true _ h)
  rw [hq] at h ⊢
  exact ⟨rfl, bfly_add_error hfmt v hp h⟩

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

/-- **A lane group's dot product without contraction is FloatLib's fixed-order reduction**, up to
NaNs: in every format, for every `k` (a group of `2 ^ k` lanes), flag `c`, oracle family `o` with
the contraction off and list of factor pairs `ps`, `groupDot k c o ps` and FloatLib's
`Model.reduceAlong fmt fmt` along lane 0's tree `bflyTree (bflyOffsets k) 0` of the in-order dot
products of the `2 ^ k` strided lists are the same word or both NaNs (`bfly_stride_nanEq`). -/
theorem groupDot_nanEq (k : Nat) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) (hu : ∀ j i, c = true → (o j i).2 % 3 ≠ 2) :
    NaNEq (groupDot k c o ps)
      (Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride (2 ^ k) j ps))
        (bflyTree (bflyOffsets k) 0)) :=
  bfly_stride_nanEq c o ps (bflyOffsets k) (2 ^ k) 0 hu

/-- **The warp's dot product without contraction is FloatLib's fixed-order reduction**, up to
NaNs: in every format, for every flag `c`, oracle family `o` with the contraction off and list of
factor pairs `ps`, `warpDot c o ps` and FloatLib's `Model.reduceAlong fmt fmt` along lane 0's
tree `bflyTree warpOffsets 0` of the in-order dot products of the 32 strided lists are the same
word or both NaNs: `groupDot_nanEq` at `k = 5`. -/
theorem warpDot_nanEq (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j k, c = true → (o j k).2 % 3 ≠ 2) :
    NaNEq (warpDot c o ps)
      (Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride 32 j ps))
        (bflyTree warpOffsets 0)) :=
  groupDot_nanEq 5 c o ps hu

/-- The two halves of `groupDot_nanEq`, under its premises (every format, every `k`, the
contraction off): when FloatLib's reduction along `bflyTree (bflyOffsets k) 0` of the `2 ^ k`
in-order dot products is not a NaN, `groupDot k c o ps` is that word, bit for bit; and
`groupDot k c o ps` is a NaN exactly when FloatLib's word is. -/
theorem groupDot_eq (k : Nat) (c : Bool) (o : Nat → Nat → Nat × Nat)
    (ps : List (Model fmt × Model fmt)) (hu : ∀ j i, c = true → (o j i).2 % 3 ≠ 2) :
    ((Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride (2 ^ k) j ps))
        (bflyTree (bflyOffsets k) 0)).isNaN = false →
        groupDot k c o ps = Model.reduceAlong fmt fmt
          (fun j => Model.dotInOrder fmt fmt (stride (2 ^ k) j ps)) (bflyTree (bflyOffsets k) 0)) ∧
      (groupDot k c o ps).isNaN = (Model.reduceAlong fmt fmt
        (fun j => Model.dotInOrder fmt fmt (stride (2 ^ k) j ps))
          (bflyTree (bflyOffsets k) 0)).isNaN :=
  (groupDot_nanEq k c o ps hu).eq_isNaN

/-- The two halves of `warpDot_nanEq`, under its premises (every format, the contraction off):
when FloatLib's reduction along `bflyTree warpOffsets 0` of the 32 in-order dot products is not a
NaN, `warpDot c o ps` is that word, bit for bit; and `warpDot c o ps` is a NaN exactly when
FloatLib's word is: `groupDot_eq` at `k = 5`. -/
theorem warpDot_eq (c : Bool) (o : Nat → Nat → Nat × Nat) (ps : List (Model fmt × Model fmt))
    (hu : ∀ j k, c = true → (o j k).2 % 3 ≠ 2) :
    ((Model.reduceAlong fmt fmt (fun j => Model.dotInOrder fmt fmt (stride 32 j ps))
        (bflyTree warpOffsets 0)).isNaN = false →
        warpDot c o ps = Model.reduceAlong fmt fmt
          (fun j => Model.dotInOrder fmt fmt (stride 32 j ps)) (bflyTree warpOffsets 0)) ∧
      (warpDot c o ps).isNaN = (Model.reduceAlong fmt fmt
        (fun j => Model.dotInOrder fmt fmt (stride 32 j ps)) (bflyTree warpOffsets 0)).isNaN :=
  groupDot_eq 5 c o ps hu

end MojoProof.Sem
