import MojoProof.Sem.Matmul
import MojoProofTest.FloatRel

/-!
# Instances and twins of the matmul and gemv cells of MojoProof/Sem/Matmul.lean

On binary32, the matrices `mA = [[-1, 1 + 2 ^ -23], [1, 2]]` and `mB = [[1, 1], [1 - 2 ^ -23, 1]]`
and the vector `vB = [1, 1 - 2 ^ -23]`, the first column of `mB`, as TorchLean tensors:

* `matmul_vals`: TorchLean's `Tensor.matmul mA mB` is `[[+0, 2 ^ -23], [3 - 2 ^ -22, 3]]`, by
  evaluating TorchLean's definition in the kernel. Entry `(0, 0)` is `+0` because the rounded
  product `(1 + 2 ^ -23) (1 - 2 ^ -23)` is 1.
* `matmul_cell_inst`, the instance of `matmul_cell_eq`: the loop over `matmulPairs mA mB 0 0`
  without the `contract` flag (oracle numbers `(0, 0)`), and with it under the oracle numbers
  `(0, 1)`, is TorchLean's entry.
* `matmul_cell_twin`, the twin of the premise that no `fadd` oracle number is 2 modulo 3: under
  the oracle numbers `(0, 2)` every iteration is fused, the last `fma` is exact, and the loop
  gives `-2 ^ -46`, which is not TorchLean's `+0`.
* `matmul_error_inst`, the instance of `matmul_cell_error`: that fused word is finite, so it is
  within `dotBound .binary32 2 T` of entry `(0, 0)` of TorchLean's real matmul.
* `matmul_real_inst`, the instance of `matmul_cell_real`: that real entry is `-2 ^ -46`, the
  exact sum, so the fused word is exact and TorchLean's binary32 `+0` is `2 ^ -46` from it.
* `matVec_vals`, `matVec_cell_inst`: TorchLean's `contract mA vB _ _ [2] .matVec` is
  `[+0, 3 - 2 ^ -22]`, by evaluating TorchLean's definition in the kernel, and the loop without
  the `contract` flag over `matVecPairs mA vB 1` is its entry 1 (`matVec_cell_eq`); that word is
  finite, so it is within `dotBound .binary32 2 T` of entry 1 of the real product
  (`matVec_error_inst`, the instance of `matVec_cell_error`).

The thread's loads and accumulator, on the 2 × 3 binary32 matrices `tA = [[1, 2, 3], [4, 5, 6]]`
and `tB = [[1, 0, -1], [2, 1, 0]]`, whose product `tA tBᵀ` (TorchLean's transpose `tBᵀ`) is
`[[-2, 4], [-2, 13]]` (`cells`):

* `load_inst`, the instance of `Mem.load_get2`: in the memory `Mem.alloc` makes from `tB`'s bytes
  under the default layout, the load of a `float` at element `1 * 3 + 0` of the block is
  `get2 tB 1 0`, which is entry `(0, 1)` of `tBᵀ` (`get2_swap`).
* `cell_inst`, the instance of `cell_of_floatBin` and `matmul_cell_eq` at every cell: with the
  flags `contract` and the oracle numbers `(0, 1)`, the words `floatBin` gives for the loop's
  `fmul`s and `fadd`s over row `i` of `tA` and row `j` of `tB` (`prodW`, `accW`) end in entry
  `(i, j)` of TorchLean's `Tensor.matmul tA tBᵀ`.
* `untransposed`, the twin: reading `tB`'s six words untransposed, as the 3 × 2 matrix `tBu`
  (element `k * 2 + j` at `(k, j)`), the loop over `matmulPairs tA tBu 0 0` gives 2, not entry
  `(0, 0)` of `tA tBᵀ`, which is -2.
* `take_inst`, the instance of `matmul_take_eq` and its twin: the loop over the first 2 of the 3
  pairs of row 0 of `tA` and row 0 of `tB` gives 1, entry `(0, 0)` of the product of the first 2
  columns of `tA` and the transpose of the first 2 columns of `tB`, and not the full entry -2.
* `cols_inst`, the instance of `matmul_cols_eq` at two strides: the loop over the 2 pairs of row
  0 of `tA` (stride 3) and row 0 of `mB` (stride 2) gives 3, entry `(0, 0)` of the product of the
  first 2 columns of `tA` and the transpose of `mB`'s 2 columns. The twin of its oracle premise is
  `matmul_cell_twin`.
-/

namespace MojoProofTest.Matmul

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats.BinaryInterchange TorchLean
open MojoProofTest.FloatRel (f32)

/-- The binary32 matrix `[[-1, 1 + 2 ^ -23], [1, 2]]` (words `0xbf800000`, `0x3f800001`,
`0x3f800000`, `0x40000000`), as a TorchLean tensor of shape `[2, 2]`. -/
def mA : Tensor (Model .binary32) [2, 2] :=
  Tensor.Rep.ofFn fun c =>
    ![![f32 0xbf800000, f32 0x3f800001], ![f32 0x3f800000, f32 0x40000000]] c.1 c.2.1

/-- The binary32 matrix `[[1, 1], [1 - 2 ^ -23, 1]]` (words `0x3f800000`, `0x3f800000`,
`0x3f7ffffe`, `0x3f800000`), as a TorchLean tensor of shape `[2, 2]`. -/
def mB : Tensor (Model .binary32) [2, 2] :=
  Tensor.Rep.ofFn fun c =>
    ![![f32 0x3f800000, f32 0x3f800000], ![f32 0x3f7ffffe, f32 0x3f800000]] c.1 c.2.1

/-- The binary32 vector `[1, 1 - 2 ^ -23]` (words `0x3f800000`, `0x3f7ffffe`), the first column
of `mB`, as a TorchLean tensor of shape `[2]`. -/
def vB : Tensor (Model .binary32) [2] :=
  Tensor.Rep.ofFn fun c => ![f32 0x3f800000, f32 0x3f7ffffe] c.1

/-- **TorchLean's binary32 product of `mA` and `mB`**: `Tensor.matmul mA mB` is
`[[+0, 2 ^ -23], [3 - 2 ^ -22, 3]]` (words `0`, `0x34000000`, `0x403fffff`, `0x40400000`): the
kernel evaluates `Tensor.matmul mA mB` at each coordinate (`decide +kernel`). -/
theorem matmul_vals :
    Tensor.get2 (Tensor.matmul mA mB) 0 0 = f32 0 ∧
      Tensor.get2 (Tensor.matmul mA mB) 0 1 = f32 0x34000000 ∧
      Tensor.get2 (Tensor.matmul mA mB) 1 0 = f32 0x403fffff ∧
      Tensor.get2 (Tensor.matmul mA mB) 1 1 = f32 0x40400000 := by
  simp only [Tensor.get2_eq_apply, mA, mB]
  decide +kernel

/-- **The instance of `matmul_cell_eq`**: entry `(0, 0)` of TorchLean's `Tensor.matmul mA mB` is
not a NaN, so the loop over `matmulPairs mA mB 0 0` from `+0` without the `contract` flag
(oracle numbers `(0, 0)`), and with it under the oracle numbers `(0, 1)`, is that entry. -/
theorem matmul_cell_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        Tensor.get2 (Tensor.matmul mA mB) 0 0 ∧
      dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        Tensor.get2 (Tensor.matmul mA mB) 0 0 := by
  have hn : (Tensor.get2 (Tensor.matmul mA mB) 0 0).isNaN = false := by
    rw [matmul_vals.1]
    decide +kernel
  exact ⟨(matmul_cell_eq false _ mA mB 0 0 (fun _ _ => by simp)).1 hn,
    (matmul_cell_eq true _ mA mB 0 0 (fun _ _ => by simp)).1 hn⟩

/-- **The twin of `matmul_cell_eq`'s premise** that no `fadd` oracle number is 2 modulo 3 when
the `contract` flag is set: with the `contract` flag under the oracle numbers `(0, 2)`, the loop
over `matmulPairs mA mB 0 0` from `+0` gives `-2 ^ -46` (`0xa8800000`), by evaluation, and that
word is not TorchLean's entry `(0, 0)` of `Tensor.matmul mA mB`, which is `+0`. -/
theorem matmul_cell_twin :
    dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
        f32 0xa8800000 ∧
      dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) ≠
        Tensor.get2 (Tensor.matmul mA mB) 0 0 := by
  have h : dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false) (matmulPairs mA mB 0 0) =
      f32 0xa8800000 := by
    simp only [matmulPairs, Tensor.get2_eq_apply, mA, mB, Tensor.Rep.get_ofFn]
    decide +kernel
  refine ⟨h, ?_⟩
  rw [h, matmul_vals.1]
  decide +kernel

/-- **The instance of `matmul_cell_error`**: the fused loop of `matmul_cell_twin` gives a finite
word, so it is within `dotBound .binary32 2 T` of entry `(0, 0)` of TorchLean's `Tensor.matmul`
over `ℝ` of `mA` and `mB` mapped by `Model.toReal`, with `T` the sum of the absolute products. -/
theorem matmul_error_inst :
    |(dotLoop true (fun _ => (0, 2)) (Model.zero .binary32 false)
          (matmulPairs mA mB 0 0)).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal mA) (Tensor.map Model.toReal mB))
          0 0| ≤
      dotBound .binary32 2
        ((matmulPairs mA mB 0 0).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  matmul_cell_error rfl true _ mA mB 0 0 (by rw [matmul_cell_twin.1]; decide +kernel)

/-- **The instance of `matmul_cell_real`**: entry `(0, 0)` of TorchLean's `Tensor.matmul` over
`ℝ` of `mA` and `mB` mapped by `Model.toReal` is the exact sum
`-1 · 1 + (1 + 2 ^ -23) (1 - 2 ^ -23) = -2 ^ -46`, the real value of the fused word of
`matmul_cell_twin`; TorchLean's binary32 entry `+0` is `2 ^ -46` from it. -/
theorem matmul_real_inst :
    Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal mA) (Tensor.map Model.toReal mB)) 0 0 =
      -(1 / 2 ^ 46) := by
  rw [← matmul_cell_real]
  have e : matmulPairs mA mB 0 0 =
      [(f32 0xbf800000, f32 0x3f800000), (f32 0x3f800001, f32 0x3f7ffffe)] := by
    simp only [matmulPairs, Tensor.get2_eq_apply, mA, mB, Tensor.Rep.get_ofFn]
    decide +kernel
  have h : (f32 0xbf800000).toRat? = some (-1) ∧ (f32 0x3f800000).toRat? = some 1 ∧
      (f32 0x3f800001).toRat? = some (1 + 1 / 8388608) ∧
      (f32 0x3f7ffffe).toRat? = some (1 - 1 / 8388608) := by
    decide +kernel
  obtain ⟨h1, h2, h3, h4⟩ := h
  rw [e]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    Model.Algebraic.toReal_of_toRat?_eq_some h1, Model.Algebraic.toReal_of_toRat?_eq_some h2,
    Model.Algebraic.toReal_of_toRat?_eq_some h3, Model.Algebraic.toReal_of_toRat?_eq_some h4]
  norm_num

/-- **TorchLean's binary32 product of `mA` and `vB`**: `contract mA vB _ _ [2] .matVec` is
`[+0, 3 - 2 ^ -22]` (words `0` and `0x403fffff`), the first column of `Tensor.matmul mA mB`: the
kernel evaluates the contraction at each coordinate (`decide +kernel`). -/
theorem matVec_vals :
    (Tensor.contract mA vB _ _ [2] .matVec).getScalar 0 = f32 0 ∧
      (Tensor.contract mA vB _ _ [2] .matVec).getScalar 1 = f32 0x403fffff := by
  simp only [Tensor.getScalar_eq_apply, mA, vB]
  decide +kernel

/-- **The instance of `matVec_cell_eq`**: entry 1 of TorchLean's `contract mA vB _ _ [2] .matVec`
is not a NaN, so the loop over `matVecPairs mA vB 1` from `+0` without the `contract` flag
(oracle numbers `(0, 0)`) is that entry, `3 - 2 ^ -22`. -/
theorem matVec_cell_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matVecPairs mA vB 1) =
      (Tensor.contract mA vB _ _ [2] .matVec).getScalar 1 :=
  (matVec_cell_eq false _ mA vB 1 (fun _ _ => by simp)).1 (by rw [matVec_vals.2]; decide +kernel)

/-- **The instance of `matVec_cell_error`**: the loop of `matVec_cell_inst` gives a finite word,
so it is within `dotBound .binary32 2 T` of entry 1 of TorchLean's matrix-vector product over `ℝ`
of `mA` and `vB` mapped by `Model.toReal`, with `T` the sum of the absolute products. -/
theorem matVec_error_inst :
    |(dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (matVecPairs mA vB 1)).toReal -
        (Tensor.contract (Tensor.map Model.toReal mA) (Tensor.map Model.toReal vB) _ _ [2]
          .matVec).getScalar 1| ≤
      dotBound .binary32 2 ((matVecPairs mA vB 1).map fun ab => |ab.1.toReal * ab.2.toReal|).sum :=
  matVec_cell_error rfl false _ mA vB 1 (by rw [matVec_cell_inst, matVec_vals.2]; decide +kernel)

/-! ## The thread's loads and accumulator -/

/-- The binary32 matrix `[[1, 2, 3], [4, 5, 6]]` (words `0x3f800000`, `0x40000000`,
`0x40400000`, `0x40800000`, `0x40a00000`, `0x40c00000`), as a TorchLean tensor of shape
`[2, 3]`. -/
def tA : Tensor (Model .binary32) [2, 3] :=
  Tensor.Rep.ofFn fun c =>
    ![![f32 0x3f800000, f32 0x40000000, f32 0x40400000],
      ![f32 0x40800000, f32 0x40a00000, f32 0x40c00000]] c.1 c.2.1

/-- The six binary32 words `1, 0, -1, 2, 1, 0` (`0x3f800000`, `0`, `0xbf800000`, `0x40000000`,
`0x3f800000`, `0`): the buffer of `tB`, in memory order. -/
def wB : List (Model .binary32) :=
  [f32 0x3f800000, f32 0, f32 0xbf800000, f32 0x40000000, f32 0x3f800000, f32 0]

/-- The buffer `wB` read row-major as a 2 × 3 matrix, element `j * 3 + k` at `(j, k)`:
`[[1, 0, -1], [2, 1, 0]]`. -/
def tB : Tensor (Model .binary32) [2, 3] :=
  Tensor.Rep.ofFn fun c => wB.getD (c.1 * 3 + c.2.1) (f32 0)

/-- The buffer `wB` read untransposed as a 3 × 2 matrix, element `k * 2 + j` at `(k, j)`:
`[[1, 0], [-1, 2], [1, 0]]`. -/
def tBu : Tensor (Model .binary32) [3, 2] :=
  Tensor.Rep.ofFn fun c => wB.getD (c.1 * 2 + c.2.1) (f32 0)

/-- TorchLean's transpose of `tB`, a 3 × 2 matrix. -/
abbrev tBT : Tensor (Model .binary32) [3, 2] :=
  Tensor.permute tB (Shape.adjacentSwap [2, 3] 0) [3, 2]

/-- **TorchLean's binary32 product of `tA` and `tBᵀ`**: `Tensor.matmul tA tBᵀ` is
`[[-2, 4], [-2, 13]]` (words `0xc0000000`, `0x40800000`, `0xc0000000`, `0x41500000`): the
kernel evaluates `Tensor.matmul tA tBᵀ` at each coordinate (`decide +kernel`). -/
theorem cells :
    Tensor.get2 (Tensor.matmul tA tBT) 0 0 = f32 0xc0000000 ∧
      Tensor.get2 (Tensor.matmul tA tBT) 0 1 = f32 0x40800000 ∧
      Tensor.get2 (Tensor.matmul tA tBT) 1 0 = f32 0xc0000000 ∧
      Tensor.get2 (Tensor.matmul tA tBT) 1 1 = f32 0x41500000 := by
  simp only [tBT, Tensor.get2_eq_apply, tA, tB]
  decide +kernel

/-- The memory and block number `Mem.alloc` gives under the default layout (a `float` takes 4
bytes) for `tB`'s 24 bytes (`tensorBytes`, row-major) in the empty memory: block 1, in address
space 1, live, read-only, owned by all threads, at addresses 16 in its space and in the generic
space. -/
def allocB : Mem × Nat :=
  ({} : Mem).alloc {} 1 (Shape.size [2, 3] * ({} : Layout).size (.fp .float)) 16 true true .all 1 1
    (tensorBytes {} (.fp .float) (.ofFloat .float) tB)

/-- **The instance of `Mem.load_get2`**: in the memory `allocB` makes, for every thread `w`, the
load of a `float` under the default layout through the generic space with alignment 4 at element
`1 * 3 + 0` of block 1 (offset 12, address 28) gives `get2 tB 1 0`, which is entry `(0, 1)` of
TorchLean's transpose of `tB`; the block holds `tB` by `Mem.holds_alloc`. -/
theorem load_inst (w : Who) :
    allocB.1.load {} w 0 (.fp .float)
        ⟨allocB.2, ((0 + (1 * 3 + 0) * ({} : Layout).size (.fp .float) : Nat) : Int)⟩ (some 4) =
      .ok (.ofFloat .float (Tensor.get2 tBT 0 1 : Model .binary32)) := by
  obtain ⟨blk, hb, h⟩ := Mem.holds_alloc (Layout.Codec.float {} .float) tB {} 1 16 true true .all
    1 1
  have e : blk = _ := (Option.some.inj hb).symm
  subst e
  rw [show Tensor.get2 tBT 0 1 = Tensor.get2 tB 1 0 from get2_swap tB 0 1]
  exact Mem.load_get2 (w := w) (r := 1) (k := 0) (a := 0) (ad := 28) hb h rfl rfl (by decide)
    (by decide) rfl
    (fun q hq => by simp only [Option.mem_def, Option.some.injEq] at hq; subst hq; rfl)

/-- The flags of the naive kernel's `fmul` and `fadd`: `contract` only. -/
def fmC : FastMath := { contract := true }

/-- The value of a result, `poison` for a fault. -/
def res : Except Fault Val → Val
  | .ok v => v
  | .error _ => .poison

/-- A result that is not a fault is `.ok` of its `res`. -/
theorem res_eq {x : Except Fault Val} (h : x.isOk = true) : x = .ok (res x) := by
  cases x
  · cases h
  · rfl

/-- The word of the `fmul` of iteration `k < 3` of the loop for cell `(i, j)` under oracle
sequence `o`: `floatBin`'s product of `get2 tA i k` and `get2 tB j k` with no factors, at
`(o k).1`; `poison` for `k ≥ 3`. -/
def prodW (o : Nat → Nat × Nat) (i j : Fin 2) (k : Nat) : Val :=
  if hk : k < 3 then
    res (floatBin .float .fmul fmC (.ofFloat .float (Tensor.get2 tA i ⟨k, hk⟩))
      (.ofFloat .float (Tensor.get2 tB j ⟨k, hk⟩)) none none (o k).1)
  else .poison

/-- The accumulator of the loop for cell `(i, j)` under oracle sequence `o` after `k`
iterations: `+0`, then `floatBin`'s sum of the accumulator (no factors) and `prodW o i j k` (the
factors `(get2 tA i k, get2 tB j k)`, as `exec` records them under `contract`) at `(o k).2`;
`poison` after 3. -/
def accW (o : Nat → Nat × Nat) (i j : Fin 2) : Nat → Val
  | 0 => .ofFloat .float (Model.zero .binary32 false)
  | k + 1 =>
    if hk : k < 3 then
      res (floatBin .float .fadd fmC (accW o i j k) (prodW o i j k) none
        (some (.ofFloat .float (Tensor.get2 tA i ⟨k, hk⟩),
          .ofFloat .float (Tensor.get2 tB j ⟨k, hk⟩))) (o k).2)
    else .poison

/-- **The instance of `cell_of_floatBin` and `matmul_cell_eq`**, at every cell `(i, j)`: with
the flags `contract` and the oracle numbers `(0, 1)` for every iteration, the accumulator
`accW` after 3 iterations is the word of entry `(i, j)` of TorchLean's `Tensor.matmul tA tBᵀ`.
The premises of `cell_of_floatBin` hold because no `floatBin` of the loop faults, by evaluation
in the kernel. -/
theorem cell_inst (i j : Fin 2) :
    accW (fun _ => (0, 1)) i j 3 = .ofFloat .float (Tensor.get2 (Tensor.matmul tA tBT) i j) := by
  have okM : ∀ i j : Fin 2, ∀ k : Fin 3, (floatBin .float .fmul fmC
      (.ofFloat .float (Tensor.get2 tA i k)) (.ofFloat .float (Tensor.get2 tB j k)) none none
      0).isOk = true := by
    simp only [tA, tB]
    decide +kernel
  have okA : ∀ i j : Fin 2, ∀ k : Fin 3, (floatBin .float .fadd fmC (accW (fun _ => (0, 1)) i j k)
      (prodW (fun _ => (0, 1)) i j k) none (some (.ofFloat .float (Tensor.get2 tA i k),
        .ofFloat .float (Tensor.get2 tB j k))) 1).isOk = true := by
    simp only [tA, tB]
    decide +kernel
  have hnan : ∀ i j : Fin 2, (Tensor.get2 (Tensor.matmul tA tBT) i j).isNaN = false := by
    simp only [tBT, Tensor.get2_eq_apply, tA, tB]
    decide +kernel
  have h := cell_of_floatBin (t := .float) (fm := fmC) rfl rfl rfl (fun _ => (0, 1)) tA tB i j
    (accW (fun _ => (0, 1)) i j) (prodW (fun _ => (0, 1)) i j) rfl
    (fun k hk => by simp only [prodW, hk, ↓reduceDIte]; exact res_eq (okM i j ⟨k, hk⟩))
    (fun k hk => by simp only [accW, hk, ↓reduceDIte]; exact res_eq (okA i j ⟨k, hk⟩))
  exact h.trans (congrArg (Val.ofFloat .float)
    ((matmul_cell_eq true (fun _ => (0, 1)) tA tBT i j (fun _ _ => by simp)).1 (hnan i j)))

/-- **The twin of the transposed read**: reading `tB`'s buffer untransposed, as the 3 × 2 matrix
`tBu`, the loop over `matmulPairs tA tBu 0 0` from `+0` with the `contract` flag under the oracle
numbers `(0, 1)` gives 2 (`0x40000000`), by evaluation, and that word is not entry `(0, 0)` of
`Tensor.matmul tA tBᵀ`, which is -2. -/
theorem untransposed :
    dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) (matmulPairs tA tBu 0 0) =
        f32 0x40000000 ∧
      dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) (matmulPairs tA tBu 0 0) ≠
        Tensor.get2 (Tensor.matmul tA tBT) 0 0 := by
  have h : dotLoop true (fun _ => (0, 1)) (Model.zero .binary32 false) (matmulPairs tA tBu 0 0) =
      f32 0x40000000 := by
    simp only [matmulPairs, Tensor.get2_eq_apply, tA, tBu, Tensor.Rep.get_ofFn]
    decide +kernel
  refine ⟨h, ?_⟩
  rw [h, cells.1]
  decide +kernel

/-- **The instance of `matmul_take_eq`**, and its twin: the loop without the `contract` flag
(oracle numbers `(0, 0)`) from `+0` over the first 2 of the 3 pairs of row 0 of `tA` and row 0 of
`tB`, `(1, 1)` and `(2, 0)`, gives 1 (`0x3f800000`), by evaluation; that word is entry `(0, 0)` of
TorchLean's product of the first 2 columns of `tA` and the transpose of the first 2 columns of
`tB` (`matmul_take_eq`, from its NaN half and the word); and it is not entry `(0, 0)` of the full
product `Tensor.matmul tA tBᵀ`, which is -2. -/
theorem take_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
        ((List.ofFn fun k : Fin 3 => (Tensor.get2 tA 0 k, Tensor.get2 tB 0 k)).take 2) =
        f32 0x3f800000 ∧
      dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
          ((List.ofFn fun k : Fin 3 => (Tensor.get2 tA 0 k, Tensor.get2 tB 0 k)).take 2) =
        Tensor.get2 (Tensor.matmul (cols 2 (by decide) tA)
          (Tensor.permute (cols 2 (by decide) tB) (Shape.adjacentSwap [2, 2] 0) [2, 2])) 0 0 ∧
      dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
          ((List.ofFn fun k : Fin 3 => (Tensor.get2 tA 0 k, Tensor.get2 tB 0 k)).take 2) ≠
        Tensor.get2 (Tensor.matmul tA tBT) 0 0 := by
  have h : dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false)
      ((List.ofFn fun k : Fin 3 => (Tensor.get2 tA 0 k, Tensor.get2 tB 0 k)).take 2) =
      f32 0x3f800000 := by
    simp only [Tensor.get2_eq_apply, tA, tB, Tensor.Rep.get_ofFn]
    decide +kernel
  have e := matmul_take_eq false (fun _ => (0, 0)) tA tB (K := 2) (by decide) 0 0
    (fun _ h => by cases h)
  refine ⟨h, e.1 (by rw [← e.2, h]; decide +kernel), ?_⟩
  rw [h, cells.1]
  decide +kernel

/-- **The instance of `matmul_cols_eq`**, a test of one example at two different strides: the
loop without the `contract` flag (oracle numbers `(0, 0)`) from `+0` over the 2 pairs of row 0 of
`tA` (stride 3) and row 0 of `mB` (stride 2), `(1, 1)` and `(2, 1)`, gives 3 (`0x40400000`), by
evaluation; that word is entry `(0, 0)` of TorchLean's product of the first 2 columns of `tA` and
the transpose of the 2 columns of `mB` (`matmul_cols_eq` at `sA = 3`, `sB = 2`, from its NaN half
and the word). -/
theorem cols_inst :
    dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (List.ofFn fun k : Fin 2 =>
        (Tensor.get2 tA 0 (Fin.castLE (by decide) k), Tensor.get2 mB 0 (Fin.castLE le_rfl k))) =
        f32 0x40400000 ∧
      dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (List.ofFn fun k : Fin 2 =>
          (Tensor.get2 tA 0 (Fin.castLE (by decide) k), Tensor.get2 mB 0 (Fin.castLE le_rfl k))) =
        Tensor.get2 (Tensor.matmul (cols 2 (by decide) tA)
          (Tensor.permute (cols 2 le_rfl mB) (Shape.adjacentSwap [2, 2] 0) [2, 2])) 0 0 := by
  have h : dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (List.ofFn fun k : Fin 2 =>
      (Tensor.get2 tA 0 (Fin.castLE (by decide) k), Tensor.get2 mB 0 (Fin.castLE le_rfl k))) =
      f32 0x40400000 := by
    simp only [Tensor.get2_eq_apply, tA, mB, Tensor.Rep.get_ofFn]
    decide +kernel
  have e := matmul_cols_eq false (fun _ => (0, 0)) tA mB (K := 2) (by decide) le_rfl 0 0
    (fun _ h => by cases h)
  exact ⟨h, e.1 (by rw [← e.2, h]; decide +kernel)⟩

end MojoProofTest.Matmul
