import MojoProof.Sem.Dot
import TorchLean.Tensor.Contract
import FloatLib.Floats.Formats.BinaryInterchange.Model.Instances

/-!
# The matmul and gemv cells against TorchLean (docs/proofs/dot.md)

TorchLean's `Tensor.matmul A B` is `contract A B _ _ [m, p] .matMul`, whose entry `(i, j)` is
`(List.finRange n).foldl (fun sum k => sum + get2 A i k * get2 B k j) 0`, and its
matrix-vector product is `contract A v _ _ [m] .matVec`, whose entry `i` is
`(List.finRange n).foldl (fun sum k => sum + get2 A i k * v.getScalar k) 0` (TorchLean's lemmas
get2_matmul and getScalar_contract_matVec). Over FloatLib's `Model fmt`, `+`, `*` and `0` are
`Model.add`, `Model.mul` and `posZero fmt` (FloatLib's instances), and `Model.zero fmt false`,
the loop's start word, is `posZero fmt` by unfolding. So over `Model fmt` TorchLean's products are
the unfused fold without casts of the factors, and over `ℝ` the exact sums.

Definitions, for every FloatLib format and all sizes:
* `matmulPairs A B i j`: the factor pairs `(get2 A i k, get2 B k j)` of entry `(i, j)` of the
  product of `A : Tensor (Model fmt) [m, n]` and `B : Tensor (Model fmt) [n, p]`, in increasing
  `k`.
* `matVecPairs A v i`: the factor pairs `(get2 A i k, v.getScalar k)` of entry `i` of the product
  of `A : Tensor (Model fmt) [m, n]` and `v : Tensor (Model fmt) [n]`.

Proved, for every format, all sizes `m`, `n`, `p`, all matrices, vectors and indices, every
`contract` flag `c` and oracle sequence `o`; `A'`, `B'` and `v'` are TorchLean's pointwise
`Tensor.map Model.toReal` of `A`, `B` and `v`:
* `matmul_cell_nanEq`, `matmul_cell_eq`: with the contraction off (`c` false, or no `fadd` oracle
  number 2 modulo 3), `dotLoop c o (Model.zero fmt false) (matmulPairs A B i j)` and
  `get2 (Tensor.matmul A B) i j` are the same word or both NaNs; so the loop's word is TorchLean's
  when TorchLean's is not a NaN, and is a NaN exactly when TorchLean's is.
* `matmul_cell_real`: the exact sum of the products of the real values of `matmulPairs A B i j`
  is `get2 (Tensor.matmul A' B') i j` over `ℝ`.
* `matmul_cell_error`: in every IEEE format, under every oracle sequence (each iteration fused or
  not), a finite loop word over `matmulPairs A B i j` is within `dotBound fmt n T` of
  `get2 (Tensor.matmul A' B') i j`, with `T` the sum of the absolute products.
* `matVec_cell_nanEq`, `matVec_cell_eq`, `matVec_cell_real`, `matVec_cell_error`: the same for
  `matVecPairs A v i` and entry `i` of `contract A v _ _ [m] .matVec` (over `ℝ`, of
  `contract A' v' _ _ [m] .matVec`).

Each family is proved once for the pairs `List.ofFn f` of any `f : Fin n → Model fmt × Model fmt`
(`dotLoop_nanEq_ofFn`, `dotSum_ofFn`; the bound is `dotLoop_error`), and the matmul and gemv
statements are its corollaries.

Scope: this is the float and the real half of the kernel's correctness; the kernel's loop is not
connected to it. The connection point: in the naive matmul kernel of the corpus, the word that
thread `(i, j)` stores at the loop's exit (`%68 = phi float [ %48, %51 ]`) is
`dotLoop true o (Model.zero fmt false) (matmulPairs A B i j)`, with `A` and `B` the input tensors
that `Mem.tensor` reads, the loads `%60` and `%64` of iteration `k` giving `get2 A i k` and
`get2 B k j`, and `o k` the oracle numbers of that iteration's `fmul` and `fadd`; that equation
is not proved (docs/proofs/dot.md, section "Scope").
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange TorchLean

variable {fmt : FloatFormat} {m n p : Nat}

/-- The factor pairs of entry `(i, j)` of the product of the matrices `A` (`m × n`) and `B`
(`n × p`) of words of any format: `(get2 A i k, get2 B k j)` for `k = 0, …, n - 1`, in that
order. -/
def matmulPairs (A : Tensor (Model fmt) [m, n]) (B : Tensor (Model fmt) [n, p]) (i : Fin m)
    (j : Fin p) : List (Model fmt × Model fmt) :=
  List.ofFn fun k => (Tensor.get2 A i k, Tensor.get2 B k j)

/-- The factor pairs of entry `i` of the product of the matrix `A` (`m × n`) and the vector `v`
(length `n`) of words of any format: `(get2 A i k, v.getScalar k)` for `k = 0, …, n - 1`, in that
order. -/
def matVecPairs (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n]) (i : Fin m) :
    List (Model fmt × Model fmt) :=
  List.ofFn fun k => (Tensor.get2 A i k, v.getScalar k)

/-- **The loop without contraction is TorchLean's fold**, up to NaNs: in every format, for every
`n`, every `f : Fin n → Model fmt × Model fmt`, flag `c` and oracle sequence `o` with the
contraction off (`c` false, or no `fadd` oracle number 2 modulo 3), `dotLoop` from `+0` over
`List.ofFn f` and the fold `(List.finRange n).foldl (fun s k => s + (f k).1 * (f k).2) 0` with
FloatLib's `+`, `*` and `0` (no casts of the factors) are `NaNEq`: the same word, or both NaNs. -/
theorem dotLoop_nanEq_ofFn (c : Bool) (o : Nat → Nat × Nat) (f : Fin n → Model fmt × Model fmt)
    (hu : ∀ j, c = true → (o j).2 % 3 ≠ 2) :
    NaNEq (dotLoop c o (Model.zero fmt false) (List.ofFn f))
      ((List.finRange n).foldl (fun s k => s + (f k).1 * (f k).2) 0) :=
  (dotLoop_nanEq_foldl c id (fun _ => .inl rfl) (List.ofFn f) o (acc' := Model.zero fmt false)
    hu (.inl rfl)).trans (.inl (by rw [List.ofFn_eq_map, List.foldl_map]; rfl))

/-- **The exact sum is TorchLean's real fold**: in every format, for every `n` and every
`f : Fin n → Model fmt × Model fmt`, the sum of the products of the real values of the pairs
`List.ofFn f` is the fold `(List.finRange n).foldl (fun s k => s + (f k).1.toReal *
(f k).2.toReal) 0` in `ℝ`. -/
theorem dotSum_ofFn (f : Fin n → Model fmt × Model fmt) :
    ((List.ofFn f).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      (List.finRange n).foldl (fun s k => s + (f k).1.toReal * (f k).2.toReal) 0 := by
  rw [List.ofFn_eq_map, List.map_map, List.sum_eq_foldl, List.foldl_map]
  rfl

/-- **The matmul cell without contraction is TorchLean's**, up to NaNs: in every format, for all
sizes, matrices `A` (`m × n`) and `B` (`n × p`), indices `i`, `j`, every flag `c` and oracle
sequence `o` with the contraction off (`c` false, or no `fadd` oracle number 2 modulo 3), the loop
`dotLoop c o` from `+0` over `matmulPairs A B i j` and TorchLean's `get2 (Tensor.matmul A B) i j`
are `NaNEq`: the same word, or both NaNs, whose payloads and signs may differ. -/
theorem matmul_cell_nanEq (c : Bool) (o : Nat → Nat × Nat) (A : Tensor (Model fmt) [m, n])
    (B : Tensor (Model fmt) [n, p]) (i : Fin m) (j : Fin p)
    (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    NaNEq (dotLoop c o (Model.zero fmt false) (matmulPairs A B i j))
      (Tensor.get2 (Tensor.matmul A B) i j) := by
  rw [Tensor.get2_matmul]
  exact dotLoop_nanEq_ofFn c o _ hu

/-- The two halves of `matmul_cell_nanEq`, under its premises (every format and size, the
contraction off): when TorchLean's `get2 (Tensor.matmul A B) i j` is not a NaN, the loop's word
over `matmulPairs A B i j` is that word, bit for bit; and the loop's word is a NaN exactly when
TorchLean's is. -/
theorem matmul_cell_eq (c : Bool) (o : Nat → Nat × Nat) (A : Tensor (Model fmt) [m, n])
    (B : Tensor (Model fmt) [n, p]) (i : Fin m) (j : Fin p)
    (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    ((Tensor.get2 (Tensor.matmul A B) i j).isNaN = false →
        dotLoop c o (Model.zero fmt false) (matmulPairs A B i j) =
          Tensor.get2 (Tensor.matmul A B) i j) ∧
      (dotLoop c o (Model.zero fmt false) (matmulPairs A B i j)).isNaN =
        (Tensor.get2 (Tensor.matmul A B) i j).isNaN :=
  (matmul_cell_nanEq c o A B i j hu).eq_isNaN

/-- **The exact matmul cell is TorchLean's real matmul**: in every format, for all sizes,
matrices `A` (`m × n`) and `B` (`n × p`) of words and indices `i`, `j`, the sum of the products of
the real values of `matmulPairs A B i j` is entry `(i, j)` of TorchLean's `Tensor.matmul` over `ℝ`
of `A` and `B` mapped by `Model.toReal` with TorchLean's pointwise `Tensor.map`. -/
theorem matmul_cell_real (A : Tensor (Model fmt) [m, n]) (B : Tensor (Model fmt) [n, p])
    (i : Fin m) (j : Fin p) :
    ((matmulPairs A B i j).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal A) (Tensor.map Model.toReal B)) i j := by
  rw [Tensor.get2_matmul]
  simp only [Tensor.get2, Tensor.unstack_map, Tensor.getScalar_map]
  exact dotSum_ofFn _

/-- **The roundoff of the matmul cell against TorchLean's real matmul**: in every IEEE format, for
all sizes, matrices `A` (`m × n`) and `B` (`n × p`), indices `i`, `j`, every `contract` flag `c`
and oracle sequence `o` (each iteration fused or not, as `o` chooses), if the loop's word `r` from
`+0` over `matmulPairs A B i j` is finite, then `|r - get2 (Tensor.matmul A' B') i j| ≤
dotBound fmt n T`, with `A'`, `B'` the maps of `A`, `B` by `Model.toReal` and
`T = Σₖ |aᵢₖ bₖⱼ|` over the real values. Nothing is claimed when `r` is infinite or a NaN. -/
theorem matmul_cell_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (A : Tensor (Model fmt) [m, n]) (B : Tensor (Model fmt) [n, p]) (i : Fin m) (j : Fin p)
    (h : (dotLoop c o (Model.zero fmt false) (matmulPairs A B i j)).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) (matmulPairs A B i j)).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal A) (Tensor.map Model.toReal B)) i j| ≤
      dotBound fmt n ((matmulPairs A B i j).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have e := dotLoop_error hfmt c o (matmulPairs A B i j) h
  rwa [matmul_cell_real, show (matmulPairs A B i j).length = n from List.length_ofFn] at e

/-- **The gemv cell without contraction is TorchLean's**, up to NaNs: in every format, for all
sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices `i`, every flag `c` and oracle
sequence `o` with the contraction off (`c` false, or no `fadd` oracle number 2 modulo 3), the loop
`dotLoop c o` from `+0` over `matVecPairs A v i` and entry `i` of TorchLean's matrix-vector
product `contract A v _ _ [m] .matVec` are `NaNEq`: the same word, or both NaNs. -/
theorem matVec_cell_nanEq (c : Bool) (o : Nat → Nat × Nat) (A : Tensor (Model fmt) [m, n])
    (v : Tensor (Model fmt) [n]) (i : Fin m) (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    NaNEq (dotLoop c o (Model.zero fmt false) (matVecPairs A v i))
      ((Tensor.contract A v _ _ [m] .matVec).getScalar i) := by
  rw [Tensor.getScalar_contract_matVec]
  exact dotLoop_nanEq_ofFn c o _ hu

/-- The two halves of `matVec_cell_nanEq`, under its premises (every format and size, the
contraction off): when entry `i` of TorchLean's `contract A v _ _ [m] .matVec` is not a NaN, the
loop's word over `matVecPairs A v i` is that word, bit for bit; and the loop's word is a NaN
exactly when TorchLean's is. -/
theorem matVec_cell_eq (c : Bool) (o : Nat → Nat × Nat) (A : Tensor (Model fmt) [m, n])
    (v : Tensor (Model fmt) [n]) (i : Fin m) (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    (((Tensor.contract A v _ _ [m] .matVec).getScalar i).isNaN = false →
        dotLoop c o (Model.zero fmt false) (matVecPairs A v i) =
          (Tensor.contract A v _ _ [m] .matVec).getScalar i) ∧
      (dotLoop c o (Model.zero fmt false) (matVecPairs A v i)).isNaN =
        ((Tensor.contract A v _ _ [m] .matVec).getScalar i).isNaN :=
  (matVec_cell_nanEq c o A v i hu).eq_isNaN

/-- **The exact gemv cell is TorchLean's real matrix-vector product**: in every format, for all
sizes, matrices `A` (`m × n`), vectors `v` (length `n`) of words and indices `i`, the sum of the
products of the real values of `matVecPairs A v i` is entry `i` of TorchLean's
`contract A' v' _ _ [m] .matVec` over `ℝ`, with `A'`, `v'` the maps of `A`, `v` by `Model.toReal`
(TorchLean's pointwise `Tensor.map`). -/
theorem matVec_cell_real (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n])
    (i : Fin m) :
    ((matVecPairs A v i).map fun ab => ab.1.toReal * ab.2.toReal).sum =
      (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
        .matVec).getScalar i := by
  rw [Tensor.getScalar_contract_matVec]
  simp only [Tensor.get2, Tensor.unstack_map, Tensor.getScalar_map]
  exact dotSum_ofFn _

/-- **The roundoff of the gemv cell against TorchLean's real matrix-vector product**: in every
IEEE format, for all sizes, matrices `A` (`m × n`), vectors `v` (length `n`), indices `i`, every
`contract` flag `c` and oracle sequence `o` (each iteration fused or not), if the loop's word `r`
from `+0` over `matVecPairs A v i` is finite, then `|r - (contract A' v' _ _ [m] .matVec)ᵢ| ≤
dotBound fmt n T`, with `A'`, `v'` the maps by `Model.toReal` and `T = Σₖ |aᵢₖ vₖ|` over the
real values. Nothing is claimed when `r` is infinite or a NaN. -/
theorem matVec_cell_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    (A : Tensor (Model fmt) [m, n]) (v : Tensor (Model fmt) [n]) (i : Fin m)
    (h : (dotLoop c o (Model.zero fmt false) (matVecPairs A v i)).isFinite = true) :
    |(dotLoop c o (Model.zero fmt false) (matVecPairs A v i)).toReal -
        (Tensor.contract (Tensor.map Model.toReal A) (Tensor.map Model.toReal v) _ _ [m]
          .matVec).getScalar i| ≤
      dotBound fmt n ((matVecPairs A v i).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  have e := dotLoop_error hfmt c o (matVecPairs A v i) h
  rwa [matVec_cell_real, show (matVecPairs A v i).length = n from List.length_ofFn] at e

end MojoProof.Sem
