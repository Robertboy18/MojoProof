import MojoProof.Sem.Dot
import MojoProof.Sem.Buffer
import TorchLean.Tensor.Contract
import TorchLean.Tensor.Movement
import TorchLean.Tensor.ShapeChange
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

The thread's loads and accumulator, for every layout, element type and codec, every float type,
count and oracle sequence (`Bᵀ` is TorchLean's transpose
`Tensor.permute B (Shape.adjacentSwap [p, n] 0) [n, p]`):
* `rowMajor_two`, `Mem.load_get2`: element `(r, k)` of an `M × S` tensor row-major from offset `o`
  is at `o + (r * S + k) * l.size t`, and a load there from a block that holds the tensor gives
  `enc (get2 A r k)`.
* `get2_swap`, `matmulPairs_swap`: `get2 Bᵀ k j = get2 B j k` for every element type, so
  `matmulPairs A Bᵀ i j` lists `(get2 A i k, get2 B j k)`.
* `dotLoop_of_floatBin`: for pairs `f : Fin K → Model t.fmt × Model t.fmt`, values `acc`, `prod`
  with `acc 0` the word `a₀`, `prod k` the `fmul` of pair `k` under `(o k).1` and `acc (k + 1)`
  the `fadd` of `acc k` and `prod k` under `(o k).2` (with the factors `exec` records) end in
  `acc K = .ofFloat t (dotLoop fm.contract o a₀ (List.ofFn f))`.
* `cell_of_floatBin`: the same for the pairs `(get2 A i k, get2 B j k)` from `+0`, whose loop is
  over `matmulPairs A Bᵀ i j`, so the cell statements above apply to it.

The first `K` of `s` columns, for every element type, all sizes with `K ≤ s` and all indices:
* `cols K h A`: TorchLean's `Tensor.slice` of `A : Tensor α [m, s]` along axis 1 from `0` to `K`
  with step `1`, cast to the shape `[m, K]`; `get2_cols`: its entry `(r, k)` is entry `(r, k)` of
  `A`.
* `take_pairs`: in every format, the first `K` of the pairs `(get2 A i k, get2 B j k)` of row `i`
  of `A` (`m × s`) and row `j` of `B` (`p × s`) are `matmulPairs (cols K h A) (cols K h B)ᵀ i j`;
  so `matmul_take_nanEq`, `matmul_take_eq` and `matmul_take_error` are `matmul_cell_nanEq`,
  `matmul_cell_eq` and `matmul_cell_error` for them, against entry `(i, j)` of
  `Tensor.matmul (cols K h A) (cols K h B)ᵀ`, the bound with `K` terms.

Scope: the float and the real half of a matmul or gemv cell and the words of a thread's loads and
float operations, for every format, size and oracle sequence. These lemmas stand alone: none
names a program, and none runs `exec`. In the naive matmul kernel of the corpus (`naive`,
MojoProofTest/SymPhi.lean), A is read at `row * 768 + k` and B at `col * 768 + k`, so thread
`(row, col)` computes entry `(row, col)` of `A Bᵀ`. For that one program the connection with the
loop that `exec` runs is proved in MojoProofTest, at every launch and memory of `Mat.Pre`:
* `NaiveThread.thread_run` runs the loop round by round (`Round.of_inv`), each round's
  accumulator by `floatBin_dotStep`;
* `NaiveThread.steps` proves the step counts that put round `j`'s `fmul` and `fadd` of a thread
  with oracle `w` at `w (Nat.pair (54 + 18 j) 0)` and `w (Nat.pair (55 + 18 j) 0)`
  (`NaiveThread.oN`, and `NaiveSpec.o`, the oracle numbers in `NaiveSpec.bytes`);
* `NaiveIn.runIn` is the run of every thread in bounds, and `NaiveKernel.correct` the kernel
  theorem; `NaiveSound.naive_matmul` reads its cells against TorchLean with `matmul_take_nanEq`
  and `matmul_take_error`.

That proof applies `floatBin_dotStep` once per round and does not go through
`dotLoop_of_floatBin` or `cell_of_floatBin`, which are tested on concrete words only
(MojoProofTest/Matmul.lean); `rowMajor_two` and `Mem.load_get2` are not used there either (its
loads go through the obligation lemmas of MojoProof/Sym/OblLemmas.lean). MojoProofTest/NaiveRun.lean
still checks the `fadd`'s oracle numbers by evaluation on one launch.
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange TorchLean LLVM

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

/-! ## The thread's loads and accumulator -/

/-- **Row-major offsets of a matrix**: for every layout `l`, element type `t`, offset `o`, sizes
`M`, `S` and indices `r < M`, `k < S`, element `(r, k)` of an `M × S` tensor laid out row-major
from `o` (`rowMajor`) is at `o + (r * S + k) * l.size t`. -/
theorem rowMajor_two (l : Layout) (t : Ty) (o : Nat) {M S r k : Nat} (hr : r < M) (hk : k < S) :
    rowMajor (s := [M, S]) l t o (⟨r, hr⟩, ⟨k, hk⟩, ()) = o + (r * S + k) * l.size t := by
  have h1 := Shape.Coord.linearize_cons_val (n := M) (s := [S]) ⟨r, hr⟩ (⟨k, hk⟩, ())
  have h2 := Shape.Coord.val_linearize_vector (n := S) ⟨k, hk⟩
  unfold rowMajor
  erw [h1, h2]
  simp [Shape.size, Nat.mul_comm, Nat.add_comm]

/-- **A load of a matrix element**: for every layout, element type `t` with encoder `enc`, memory
`m` whose block `c` is live, admits thread `w` and holds the `M × S` tensor `A` row-major from
offset `o` (`Block.Holds`), indices `r < M`, `k < S`, address space `a` and alignment `al` that
the address `ad` of the element meets, the load of type `t` at offset `o + (r * S + k) * l.size t`
of block `c` gives `enc (get2 A r k)`. -/
theorem Mem.load_get2 {α : Type} [Storage α] {l : Layout} {t : Ty} {enc : α → Val} {m : Mem}
    {c : Nat} {blk : Block} (hb : m.blocks c = some blk) {M S : Nat} {A : Tensor α [M, S]}
    {o : Nat} (h : blk.Holds l t enc (rowMajor l t o) A) (hl : blk.live = true) {w : Who}
    (hw : blk.owner.admits w = true) {r k : Nat} (hr : r < M) (hk : k < S) {a ad : Nat}
    {al : Option Nat} (ha : m.addr l a ⟨c, ((o + (r * S + k) * l.size t : Nat) : Int)⟩ = .ok ad)
    (hal : ∀ q ∈ al, ad % q = 0) :
    m.load l w a t ⟨c, ((o + (r * S + k) * l.size t : Nat) : Int)⟩ al =
      .ok (enc (Tensor.get2 A ⟨r, hr⟩ ⟨k, hk⟩)) := by
  have e := rowMajor_two l t o hr hk
  have := Mem.load_holds hb h hl hw (⟨r, hr⟩, ⟨k, hk⟩, ()) (by rw [e]; exact ha) hal
  rwa [e, ← Tensor.get2_eq_apply] at this

/-- **The transpose of a matrix**, for every element type with TorchLean's `Storage`, all sizes
`m`, `n`, matrices `B` (`m × n`) and indices `k`, `j`: entry `(k, j)` of TorchLean's transpose
`Tensor.permute B (Shape.adjacentSwap [m, n] 0) [n, m]` is entry `(j, k)` of `B`. (TorchLean's
`get2_transpose` is the same rule over `ℝ` only.) -/
theorem get2_swap {α : Type} [Storage α] {m n : Nat} (B : Tensor α [m, n]) (k : Fin n)
    (j : Fin m) :
    Tensor.get2 (Tensor.permute B (Shape.adjacentSwap [m, n] 0) [n, m]) k j =
      Tensor.get2 B j k := by
  rw [Tensor.get2_eq_apply, Tensor.get2_eq_apply, Tensor.permute_adjacentSwap_zero_apply]

/-- The factor pairs of entry `(i, j)` of the product of `A` (`m × n`) and the transpose of `B`
(`p × n`), in every format and for all sizes and indices: `(get2 A i k, get2 B j k)` for
`k = 0, …, n - 1`, row `i` of `A` against row `j` of `B`. -/
theorem matmulPairs_swap (A : Tensor (Model fmt) [m, n]) (B : Tensor (Model fmt) [p, n])
    (i : Fin m) (j : Fin p) :
    matmulPairs A (Tensor.permute B (Shape.adjacentSwap [p, n] 0) [n, p]) i j =
      List.ofFn fun k => (Tensor.get2 A i k, Tensor.get2 B j k) := by
  simp only [matmulPairs, get2_swap]

/-- **The words of a dot-product loop are `dotLoop`**: for every float type `t`, flags `fm`
without `nnan`, `ninf`, `nsz`, `reassoc`, `arcp` and `afn`, oracle sequence `o`, count `K`, pairs
`f : Fin K → Model t.fmt × Model t.fmt`, start word `a₀` and values `acc`, `prod` with
`acc 0 = .ofFloat t a₀`: if for every `k < K` the `fmul` of the words of pair `k` (no factors
recorded for either) under the oracle number `(o k).1` is `prod k`, and the `fadd` of `acc k` (no
factors) and `prod k` (the factors of pair `k` when `fm.contract`, as `exec` records them) under
`(o k).2` is `acc (k + 1)`, then `acc K` is the scalar of
`dotLoop fm.contract o a₀ (List.ofFn f)`. -/
theorem dotLoop_of_floatBin {t : FloatTy} {fm : FastMath}
    (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false) (hn : fm.nnan = false)
    (hi : fm.ninf = false) (o : Nat → Nat × Nat) {K : Nat} (f : Fin K → Model t.fmt × Model t.fmt)
    (a₀ : Model t.fmt) (acc prod : Nat → Val) (h0 : acc 0 = .ofFloat t a₀)
    (hm : ∀ k (hk : k < K), floatBin t .fmul fm (.ofFloat t (f ⟨k, hk⟩).1)
      (.ofFloat t (f ⟨k, hk⟩).2) none none (o k).1 = .ok (prod k))
    (ha : ∀ k (hk : k < K), floatBin t .fadd fm (acc k) (prod k) none
      (if fm.contract then some (.ofFloat t (f ⟨k, hk⟩).1, .ofFloat t (f ⟨k, hk⟩).2) else none)
      (o k).2 = .ok (acc (k + 1))) :
    acc K = .ofFloat t (dotLoop fm.contract o a₀ (List.ofFn f)) := by
  have app : ∀ (o : Nat → Nat × Nat) (a : Model t.fmt) (ps : List (Model t.fmt × Model t.fmt))
      (ab : Model t.fmt × Model t.fmt), dotLoop fm.contract o a (ps ++ [ab]) =
        dotStep fm.contract (dotLoop fm.contract o a ps) ab (o ps.length) := by
    intro o a ps ab
    induction ps generalizing o a with
    | nil => rfl
    | cons x ps ih => exact ih _ _
  have key : ∀ j (hj : j ≤ K), acc j =
      .ofFloat t (dotLoop fm.contract o a₀ (List.ofFn fun i : Fin j => f ⟨i, by omega⟩)) := by
    intro j hj
    induction j with
    | zero => simpa [dotLoop] using h0
    | succ j ih =>
      have hk : j < K := hj
      rw [List.ofFn_succ_last, app, List.length_ofFn]
      have e := floatBin_dotStep hc hn hi
        (dotLoop fm.contract o a₀ (List.ofFn fun i : Fin j => f ⟨i, by omega⟩))
        (f ⟨j, hk⟩).1 (f ⟨j, hk⟩).2 (o j).1 (o j).2
      rw [hm j hk, ← ih (by omega)] at e
      exact Except.ok.inj ((ha j hk).symm.trans e)
  simpa using key K le_rfl

/-- **The cell of `A Bᵀ` from the loop's words**: `dotLoop_of_floatBin` for the pairs
`(get2 A i k, get2 B j k)` of row `i` of `A` (`m × n`) and row `j` of `B` (`p × n`), from `+0`,
under its premises (every float type, the same flags, every oracle sequence `o`): `acc n` is the
scalar of the loop over `matmulPairs A Bᵀ i j`, with `Bᵀ` TorchLean's transpose
`Tensor.permute B (Shape.adjacentSwap [p, n] 0) [n, p]`; `matmul_cell_nanEq`, `matmul_cell_eq`
and `matmul_cell_error` then give it against entry `(i, j)` of `Tensor.matmul A Bᵀ`. -/
theorem cell_of_floatBin {t : FloatTy} {fm : FastMath}
    (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false) (hn : fm.nnan = false)
    (hi : fm.ninf = false) (o : Nat → Nat × Nat) (A : Tensor (Model t.fmt) [m, n])
    (B : Tensor (Model t.fmt) [p, n]) (i : Fin m) (j : Fin p) (acc prod : Nat → Val)
    (h0 : acc 0 = .ofFloat t (Model.zero t.fmt false))
    (hm : ∀ k (hk : k < n), floatBin t .fmul fm (.ofFloat t (Tensor.get2 A i ⟨k, hk⟩))
      (.ofFloat t (Tensor.get2 B j ⟨k, hk⟩)) none none (o k).1 = .ok (prod k))
    (ha : ∀ k (hk : k < n), floatBin t .fadd fm (acc k) (prod k) none
      (if fm.contract then some (.ofFloat t (Tensor.get2 A i ⟨k, hk⟩),
        .ofFloat t (Tensor.get2 B j ⟨k, hk⟩)) else none) (o k).2 = .ok (acc (k + 1))) :
    acc n = .ofFloat t (dotLoop fm.contract o (Model.zero t.fmt false)
      (matmulPairs A (Tensor.permute B (Shape.adjacentSwap [p, n] 0) [n, p]) i j)) := by
  rw [matmulPairs_swap]
  exact dotLoop_of_floatBin hc hn hi o (fun k => (Tensor.get2 A i k, Tensor.get2 B j k)) _ acc
    prod h0 hm ha

/-- The first `K` columns of a matrix `A` (`m × s`) of any element type, for `K ≤ s`: TorchLean's
`Tensor.slice` of `A` along axis 1 from `0` to `K` with step `1`, cast to the shape `[m, K]`
(`get2_cols`). -/
def cols {α : Type} [Storage α] {m s : Nat} (K : Nat) (h : K ≤ s) (A : Tensor α [m, s]) :
    Tensor α [m, K] :=
  Tensor.castShape (Tensor.slice A [⟨1, Nat.one_lt_two⟩] [0] [K] [1]
      (Nat.zero_add K ▸ Shape.sliceValid_singleton [m, s] ⟨1, Nat.one_lt_two⟩ 0 K
        (by show 0 + K ≤ s; omega)))
    (by simpa using Shape.slice_singleton [m, s] ⟨1, Nat.one_lt_two⟩ 0 K)

/-- Entry `(r, k)` of `cols K h A` is entry `(r, k)` of `A`, for every element type, all sizes
with `K ≤ s`, every matrix `A` (`m × s`) and all indices `r < m`, `k < K`. -/
theorem get2_cols {α : Type} [Storage α] {m s K : Nat} (h : K ≤ s) (A : Tensor α [m, s])
    (r : Fin m) (k : Fin K) : Tensor.get2 (cols K h A) r k = Tensor.get2 A r (Fin.castLE h k) := by
  rw [Tensor.get2_eq_apply, Tensor.get2_eq_apply, cols, Tensor.castShape_apply_reindex,
    Tensor.slice_apply]
  congr 1
  apply Shape.Coord.ext_val
  intro d
  rw [Shape.Coord.get_ofFun]
  fin_cases d
  all_goals
    simp [Shape.valueAt, Shape.Coord.val_get]
    erw [Shape.Coord.index_reindexEq]
    rfl

/-- **The first `K` pairs of two rows are the pairs of a matmul cell**: in every format, for all
sizes with `K ≤ s`, matrices `A` (`m × s`) and `B` (`p × s`) and indices `i`, `j`, the first `K`
of the pairs `(get2 A i k, get2 B j k)`, `k < s`, are `matmulPairs` at `(i, j)` of `cols K h A`
and TorchLean's transpose of `cols K h B`. -/
theorem take_pairs {s K : Nat} (A : Tensor (Model fmt) [m, s]) (B : Tensor (Model fmt) [p, s])
    (h : K ≤ s) (i : Fin m) (j : Fin p) :
    (List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K =
      matmulPairs (cols K h A) (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p])
        i j := by
  rw [matmulPairs_swap]
  apply List.ext_getElem
  · simp [h]
  · intro k h1 h2
    simp [get2_cols]

/-- `matmul_cell_nanEq` for the first `K` pairs of two rows (`take_pairs`): in every format, for
all sizes with `K ≤ s`, matrices `A` (`m × s`), `B` (`p × s`), indices `i`, `j`, every flag `c`
and oracle sequence `o` with the contraction off, the loop from `+0` over the first `K` pairs
`(get2 A i k, get2 B j k)` and entry `(i, j)` of TorchLean's product of `cols K h A` and the
transpose of `cols K h B` are the same word or both NaNs. -/
theorem matmul_take_nanEq (c : Bool) (o : Nat → Nat × Nat) {s K : Nat}
    (A : Tensor (Model fmt) [m, s]) (B : Tensor (Model fmt) [p, s]) (h : K ≤ s) (i : Fin m)
    (j : Fin p) (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    NaNEq (dotLoop c o (Model.zero fmt false)
        ((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K))
      (Tensor.get2 (Tensor.matmul (cols K h A)
        (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p])) i j) := by
  rw [take_pairs A B h]; exact matmul_cell_nanEq c o _ _ i j hu

/-- The two halves of `matmul_take_nanEq`, under its premises: when TorchLean's entry is not a
NaN, the loop's word over the first `K` pairs is that entry, bit for bit; and the loop's word is a
NaN exactly when TorchLean's is. -/
theorem matmul_take_eq (c : Bool) (o : Nat → Nat × Nat) {s K : Nat}
    (A : Tensor (Model fmt) [m, s]) (B : Tensor (Model fmt) [p, s]) (h : K ≤ s) (i : Fin m)
    (j : Fin p) (hu : ∀ k, c = true → (o k).2 % 3 ≠ 2) :
    ((Tensor.get2 (Tensor.matmul (cols K h A)
        (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p])) i j).isNaN = false →
        dotLoop c o (Model.zero fmt false)
            ((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K) =
          Tensor.get2 (Tensor.matmul (cols K h A)
            (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p])) i j) ∧
      (dotLoop c o (Model.zero fmt false)
          ((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K)).isNaN =
        (Tensor.get2 (Tensor.matmul (cols K h A)
          (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p])) i j).isNaN :=
  (matmul_take_nanEq c o A B h i j hu).eq_isNaN

/-- `matmul_cell_error` for the first `K` pairs of two rows (`take_pairs`): in every IEEE format,
for all sizes with `K ≤ s`, matrices `A` (`m × s`), `B` (`p × s`), indices `i`, `j`, every flag
`c` and oracle sequence `o`, a finite loop word from `+0` over the first `K` pairs
`(get2 A i k, get2 B j k)` is within `dotBound fmt K T` of entry `(i, j)` of TorchLean's real
product of `cols K h A` and the transpose of `cols K h B` mapped by `Model.toReal`, with `T` the
sum of the absolute products of the `K` pairs. -/
theorem matmul_take_error (hfmt : fmt.isIEEE = true) (c : Bool) (o : Nat → Nat × Nat)
    {s K : Nat} (A : Tensor (Model fmt) [m, s]) (B : Tensor (Model fmt) [p, s]) (h : K ≤ s)
    (i : Fin m) (j : Fin p)
    (hf : (dotLoop c o (Model.zero fmt false)
      ((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K)).isFinite =
        true) :
    |(dotLoop c o (Model.zero fmt false)
        ((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take K)).toReal -
        Tensor.get2 (Tensor.matmul (Tensor.map Model.toReal (cols K h A)) (Tensor.map Model.toReal
          (Tensor.permute (cols K h B) (Shape.adjacentSwap [p, K] 0) [K, p]))) i j| ≤
      dotBound fmt K (((List.ofFn fun k : Fin s => (Tensor.get2 A i k, Tensor.get2 B j k)).take
        K).map fun ab => |ab.1.toReal * ab.2.toReal|).sum := by
  rw [take_pairs A B h] at hf ⊢; exact matmul_cell_error hfmt c o _ _ i j hf

end MojoProof.Sem
