import MojoProof.Tile.Words
import MojoProof.Import.TorchLean
import MojoProofTest.SymLane
import MojoProofTest.TileGrade

/-!
# gevm_kernel's spec side: its stored columns, their relation and the vector-matrix rule

gevm_kernel (`gevm`, MojoProofTest/SymLane.lean, gevm_kernel float32 `1308aaae`,
tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll) reduces
column `j` of the product of a vector and a matrix with one warp and stores it from lane 0: IR
line 24 has `%21 = ctaid · ntid + tid` (lines 17-24), lines 25-31 `%28 = ⌊%21 / 32⌋`, line 32
`%29`, the float at `%28` of the output `%0`, line 111 tests `laneid mod 32 = 0` (`%13`, the
`laneid` of lines 15-16), and line 115 stores the warp's sum `%87` at `%29`. At a launch whose
blocks are one-dimensional and whose block's `x` size 32 divides, column `j` is so stored by thread
`32 j` at offset `4 j` of `p0`: the `who` and offset at which gemv_kernel stores row `j`. This file
states gevm's output words, their relation and its rule in the forms MojoProof/Tile/Words.lean
shares with gemv_kernel's rows (MojoProofTest/GemvSound.lean):

* `layout_eq`: the two programs' layouts are the same (by `rfl`);
* `colsObs`: the output columns, `MojoProof.Tile.warpObs` at gevm's layout;
* `ColsRule`: the columns load as binary32 words that meet the rule of
  `GPUProof.Spec.vecMat (GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉)` at
  `MojoProof.Tile.vecMatEnc` (`MojoProof.Tile.Loads`);
* `cols_holds`: columns that load as words NaN-equal to their `warpDot`s of `vecMatPairs`
  (`MojoProof.Tile.WarpWords`, the relation of a gevm run's columns) meet `ColsRule`, at every
  oracle (`MojoProof.Tile.warpDot_vecMat_holds`);
* `TorchCols`, `torchCols_of_rule`: the same words against TorchLean's contraction `.vecMat`
  through `MojoProof.Import.torchLean` (`GPUProof.Importer.Graded`, as gemv's `TorchRows`);
* tests: `cols_3x2`, `cols_40x3` (the relation by evaluation of concrete words, then the rule,
  at sizes 3 × 2 and 40 × 3 in binary32), `torch_3x2`, and the mutants `off_ulp` (a word one ulp
  off a column's `warpDot` is not in the relation) and `refused` (a load that is not a binary32
  `Val.ofFloat` is refused by the rule).

That a run of gevm_kernel stores words in the relation is not proved here: it is the premise of
`cols_holds`, and gevm's `GPUProof.Kernel.Sound` needs that run (docs/proofs/gemv.md (d)).
-/

namespace MojoProofTest.GevmSpec

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Import MojoProofTest.SymLane
open FloatLib.Floats.Formats.BinaryInterchange MojoProofTest.TileGrade

/-- **gemv_kernel and gevm_kernel have the same layout** (test of the two programs, gemv_kernel
float32 `b79a852b` and gevm_kernel float32 `1308aaae`): their `Program.layout`s are equal, by
`rfl`, so `colsObs` and gemv's `MojoProofTest.GemvSound.rowsObs` are the same function of the
launch, count, output block and memory. -/
theorem layout_eq : gemv.prog.layout = gevm.prog.layout := rfl

/-- The output columns of a memory, for every launch `L`, column count `N` and output block `p0`:
column `j`'s binary32 load at offset `4 j` of `p0` by thread `32 j` of `L`
(`⟨32 j, 32 j / volume L.block⟩`), for each `j < N`: `MojoProof.Tile.warpObs` at gevm_kernel's
layout (gevm IR line 115 stores column `j` at `%29`, line 32, from lane 0, line 111, of the warp
whose `ctaid · ntid + tid` is `32 j` to `32 j + 31`, lines 17-31). It reads only the blocks. -/
def colsObs (L : Launch) (N p0 : Nat) (m : Mem) : Option (Fin N → Except Fault Val) :=
  MojoProof.Tile.warpObs gevm.prog.layout L N p0 m

/-- The vector-matrix rule's relation of the output columns, for every sizes `K`, `N`, width
`bits` and input words `I`: the columns load as binary32 words `W j` (`Val.ofFloat`) that meet the
rule of `GPUProof.Spec.vecMat (GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉)` at size `(K, N)`,
encoding `MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits` and inputs `I`:
`MojoProof.Tile.Loads` at that rule, as gemv's `MojoProofTest.GemvSound.RowsRule` at
`GPUProof.Spec.matVec`. It names no oracle. -/
def ColsRule {N : Nat} (K bits : Nat)
    (I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words)
    (f : Fin N → Except Fault Val) : Prop :=
  MojoProof.Tile.Loads .float
    ((GPUProof.Spec.vecMat (GPUProof.vecMatLaneGrade (2 ^ 5) 5 fun m => (m + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.vecMatLaneGrade_mono _ _ _)).rule.Holds (K, N)
        (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)) I) f

/-- **Columns that load as their `warpDot`s up to NaNs meet the vector-matrix rule** (test of
gevm_kernel's relation, gevm_kernel float32 `1308aaae`; for every width `bits`, sizes `K`, `N`,
vector `A` (length `K`), matrix `B` (`K × N`), input words `I` that hold them, oracle sequences
`o j` of each column and loads `f`): if each column `j` loads as a binary32 word that is
`MojoProof.Sem.warpDot true (o j)` of `vecMatPairs A B j` up to NaNs (`MojoProof.Tile.WarpWords`,
the relation gevm's run states at `colsObs`), the columns meet `ColsRule`, whatever the oracle:
`MojoProof.Tile.warpDot_vecMat_holds` at the words the columns load as. That a run stores such
words is a premise here. -/
theorem cols_holds (bits : Nat) {K N : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    {I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words}
    (hA : ∀ i, I (.inl i) = A.getScalar i)
    (hB : ∀ i j, I (.inr (i, j)) = TorchLean.Tensor.get2 B i j) {o : Fin N → Nat → Nat → Nat × Nat}
    {f : Fin N → Except Fault Val}
    (h : MojoProof.Tile.WarpWords .float true o (vecMatPairs A B) f) : ColsRule K bits I f :=
  h.loads fun _ hW => MojoProof.Tile.warpDot_vecMat_holds (σ := (K, N)) rfl bits true o A B hA hB hW

/-- The columns against TorchLean's contraction, for every sizes `K`, `N`, width `bits`, grade `g`
of `GPUProof.Spec.matVec` (the importer's other operation) and input words `I`: the columns load
as binary32 words `W j` such that, for every real vector and matrix `(A', B')` (length `K` and
`K × N`) and grades `G` within which each input word approximates the importer's reading of
`(A', B')` (`readIn` at `.vecMat`), each `W j` is within the grade of
`GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉` of entry `j` of TorchLean's contraction
`.vecMat` of `A'` and `B'`, read by the importer: `MojoProof.Tile.Loads` at
`GPUProof.Importer.Graded` of `torchLean` at `.vecMat`, as gemv's
`MojoProofTest.GemvTorch.TorchRows` at `.matVec`. -/
def TorchCols {N : Nat} (K bits : Nat)
    (g : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A))
    (I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words)
    (f : Fin N → Except Fault Val) : Prop :=
  MojoProof.Tile.Loads .float
    ((torchLean g mono (GPUProof.vecMatLaneGrade (2 ^ 5) 5 fun m => (m + 2 ^ 5 - 1) / 2 ^ 5)
      (GPUProof.vecMatLaneGrade_mono _ _ _)).Graded .vecMat rfl
      (GPUProof.vecMatLaneGrade (2 ^ 5) 5 fun m => (m + 2 ^ 5 - 1) / 2 ^ 5) (K, N)
      (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)) I) f

/-- **Columns that meet the spec's rule meet `TorchCols`** (test of gevm_kernel's relation, for
every sizes, width `bits`, grade `g`, input words `I` and columns `f`): `ColsRule`'s graded rule
gives `GPUProof.Importer.Graded` at `torchLean`'s `.vecMat` (`GPUProof.Importer.graded_of_holds`,
by `torchLean`'s `eq`, `MojoProof.Import.vecMat_eq`; the spec's domain is everything), at the
same words. -/
theorem torchCols_of_rule {K N bits : Nat}
    (g : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A))
    {I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words}
    {f : Fin N → Except Fault Val} (h : ColsRule K bits I f) : TorchCols K bits g mono I f :=
  h.imp fun _ => And.imp_right (GPUProof.Importer.graded_of_holds _ _ rfl rfl fun _ _ => trivial)

/-- The relation is the column words' text: `MojoProof.Tile.WarpWords` at `vecMatPairs A B` is,
by `Iff.rfl`, "each column `j` loads as `Val.ofFloat .float x` with `x` NaN-equal to
`warpDot true (o j) (vecMatPairs A B j)`", for every sizes, oracle sequences, vector, matrix and
loads. -/
example {K N : Nat} (o : Fin N → Nat → Nat → Nat × Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (f : Fin N → Except Fault Val) :
    MojoProof.Tile.WarpWords .float true o (vecMatPairs A B) f ↔
      ∀ j : Fin N, ∃ x, f j = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true (o j) (vecMatPairs A B j)) := Iff.rfl

/-! ## Tests at concrete words -/

/-- The binary32 vector of length `n` with entry `words3 ((k + s) % 3)` at `k`: `1`, `2`, `-1`
cyclically from `s`. A test tensor. -/
def cyc (n s : Nat) : TorchLean.Tensor (Model FloatTy.float.fmt) [n] :=
  TorchLean.Tensor.Rep.ofFn fun c => words3 ⟨(c.1.val + s) % 3, Nat.mod_lt _ (by decide)⟩

/-- The input words of `MojoProof.Tile.vecMatEnc` at size `(K, N)` read from a vector `A`
(length `K`) and a matrix `B` (`K × N`) of binary32 words, for every sizes and width `bits`: entry
`i` of `A` at input `i` and entry `(i, j)` of `B` at input `(i, j)`, so that `cols_holds`'
premises hold by `rfl`. A test definition. -/
def colWords {K N : Nat} (bits : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) :
    (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words :=
  Sum.elim A.getScalar fun ij => TorchLean.Tensor.get2 B ij.1 ij.2

/-- Every lane loop's oracle choice is `(0, 0)`, at every column: each `fadd contract` rounded
separately. A test definition. -/
def oZ (N : Nat) : Fin N → Nat → Nat → Nat × Nat := fun _ _ _ => (0, 0)

/-- The loads of gevm's columns at size 3 × 2 as concrete binary32 words: `6` (`0x40c00000`) and
`-1` (`0xbf800000`). A test definition. -/
def f3x2 : Fin 2 → Except Fault Val :=
  fun j => .ok (Val.ofFloat .float (![Model.ofNatBits 0x40c00000, Model.ofNatBits 0xbf800000] j))

/-- **The relation at size 3 × 2, by evaluation** (test of `MojoProof.Tile.WarpWords` at
`vecMatPairs`, binary32, the vector `cyc 3 0` = `1 2 -1` and the matrix `gen 3 2`, oracle
`oZ`): the concrete words of `f3x2` are the columns' `warpDot`s (`(1, 2, -1) · (1, 2, -1) = 6` and
`(1, 2, -1) · (2, -1, 1) = -1`, exact), evaluated by the kernel. -/
theorem words_3x2 :
    MojoProof.Tile.WarpWords .float true (oZ 2) (vecMatPairs (cyc 3 0) (gen 3 2)) f3x2 := by
  have h : ∀ j : Fin 2, warpDot true (oZ 2 j) (vecMatPairs (cyc 3 0) (gen 3 2) j) =
      ![Model.ofNatBits 0x40c00000, Model.ofNatBits 0xbf800000] j := by
    decide +kernel
  exact fun j => ⟨_, rfl, .inl (h j).symm⟩

/-- **The rule at size 3 × 2** (test of `cols_holds`, gevm's spec side, binary32, width 32, the
vector `cyc 3 0` and the matrix `gen 3 2`): the concrete loads `f3x2` meet `ColsRule` at the input
words `colWords 32 (cyc 3 0) (gen 3 2)`, from `words_3x2`. -/
theorem cols_3x2 : ColsRule 3 32 (colWords 32 (cyc 3 0) (gen 3 2)) f3x2 :=
  cols_holds 32 (fun _ => rfl) (fun _ _ => rfl) words_3x2

/-- **The TorchLean form at size 3 × 2** (test of `torchCols_of_rule`, binary32, width 32, grade
`GPUProof.matVecGrade` of the importer's `.matVec`): the loads `f3x2` meet `TorchCols`. -/
theorem torch_3x2 :
    TorchCols 3 32 GPUProof.matVecGrade GPUProof.matVecGrade_mono
      (colWords 32 (cyc 3 0) (gen 3 2)) f3x2 :=
  torchCols_of_rule _ _ cols_3x2

/-- The loads of gevm's columns at size 40 × 3 as concrete binary32 words: `79` (`0x429e0000`),
`-11` (`0xc1300000`) and `-14` (`0xc1600000`). A test definition. -/
def f40x3 : Fin 3 → Except Fault Val :=
  fun j => .ok (Val.ofFloat .float
    (![Model.ofNatBits 0x429e0000, Model.ofNatBits 0xc1300000, Model.ofNatBits 0xc1600000] j))

/-- **The relation at size 40 × 3, by evaluation** (test of `MojoProof.Tile.WarpWords` at
`vecMatPairs`, binary32, the vector `cyc 40 0` and the matrix `gen 40 3`, oracle `oZ`: 32 lanes,
lane length 2): the concrete words of `f40x3` are the columns' `warpDot`s (`79`, `-11`, `-14`,
exact), evaluated by the kernel. -/
theorem words_40x3 :
    MojoProof.Tile.WarpWords .float true (oZ 3) (vecMatPairs (cyc 40 0) (gen 40 3)) f40x3 := by
  have h : ∀ j : Fin 3, warpDot true (oZ 3 j) (vecMatPairs (cyc 40 0) (gen 40 3) j) =
      ![Model.ofNatBits 0x429e0000, Model.ofNatBits 0xc1300000, Model.ofNatBits 0xc1600000] j := by
    decide +kernel
  exact fun j => ⟨_, rfl, .inl (h j).symm⟩

/-- **The rule at size 40 × 3** (test of `cols_holds`, binary32, width 32, the vector `cyc 40 0`
and the matrix `gen 40 3`): the concrete loads `f40x3` meet `ColsRule` at the input words
`colWords 32 (cyc 40 0) (gen 40 3)`, from `words_40x3`. -/
theorem cols_40x3 : ColsRule 40 32 (colWords 32 (cyc 40 0) (gen 40 3)) f40x3 :=
  cols_holds 32 (fun _ => rfl) (fun _ _ => rfl) words_40x3

/-- **Mutant: a word one ulp off is not in the relation** (test at size 3 × 2, binary32, the
vector `cyc 3 0`, the matrix `gen 3 2`, oracle `oZ`): if column 0 loads as `0x40c00001`, one ulp
above `6`, `MojoProof.Tile.WarpWords` fails: the loaded word's bits are not those of column 0's
`warpDot`, and that `warpDot` is not a NaN (evaluated by the kernel). -/
theorem off_ulp :
    ¬ MojoProof.Tile.WarpWords .float true (oZ 2) (vecMatPairs (cyc 3 0) (gen 3 2))
      (fun j => .ok (Val.ofFloat .float
        (![Model.ofNatBits 0x40c00001, Model.ofNatBits 0xbf800000] j))) := by
  intro h
  obtain ⟨x, hx, hn⟩ := h 0
  have hb : (Model.ofNatBits 0x40c00001 : Model FloatTy.float.fmt).toBits = x.toBits := by
    injection hx with hx
    injection hx
  rcases hn with hn | ⟨-, hn⟩
  · rw [hn] at hb
    revert hb
    decide +kernel
  · revert hn
    decide +kernel

/-- **Mutant: a load that is not a binary32 word is refused by the rule** (test at size 3 × 2,
width 32, the input words `colWords 32 (cyc 3 0) (gen 3 2)`): loads of the 64-bit word `0` are no
`Val.ofFloat .float` of a binary32 word, so they do not meet `ColsRule`. -/
theorem refused :
    ¬ ColsRule 3 32 (colWords 32 (cyc 3 0) (gen 3 2)) fun _ => .ok (.bits 64 0) := by
  rintro ⟨W, hW, -⟩
  have h := hW (0 : Fin 2)
  injection h with h
  injection h with h
  exact absurd h (by decide)

end MojoProofTest.GevmSpec
