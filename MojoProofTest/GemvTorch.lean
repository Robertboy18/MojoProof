import MojoProofTest.GemvSound
import MojoProof.Import.TorchLean

/-!
# gemv_kernel against TorchLean's matrix-vector contraction

MojoProofTest/GemvSound.lean's `kernel_sound` has gemv_kernel (`gemv`, MojoProofTest/SymLane.lean,
gemv_kernel float32 `b79a852b`) sound at `sig` for the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)`. `MojoProof.Import.torchLean`
proposes that spec for TorchLean's `.matVec`, and its `eq` says that, read through the importer,
TorchLean's contraction is the spec's function. So the rows are graded against TorchLean's own
contraction of every real matrix and vector that the input words approximate.

* `TorchRows`: the rows load as binary32 words, each within the spec's grade of the importer's
  reading of TorchLean's contraction `.matVec` of every real matrix and vector that the input
  words approximate within grades (`MojoProof.Tile.Loads` at `GPUProof.Importer.Graded`, the form
  MojoProofTest/GevmSpec.lean's `TorchCols` has at `.vecMat`);
* `torchRows_of_rule`: words that meet the spec's rule meet `TorchRows`
  (`GPUProof.Importer.graded_of_holds`, by `torchLean`'s `eq`);
* `gemv_torchLean`: gemv_kernel's `GPUProof.Kernel.Sound` for `TorchRows`, from `kernel_sound`,
  with the same premises; `torch64`: it with every premise proved, at two warps.

Tests of one program, gemv_kernel float32 `b79a852b`.
-/

namespace MojoProofTest.GemvTorch

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProof.Import
open MojoProofTest.SymLane MojoProofTest.GemvWarpRun MojoProofTest.GemvSound
open FloatLib.Floats.Formats.BinaryInterchange

/-- The rows against TorchLean's contraction, for every sizes `M`, `K`, width `bits`, grade `gv`
of `GPUProof.Spec.vecMat` (the importer's other operation) and input words `I`: the rows load as
binary32 words `W i` (`Val.ofFloat`) such that, for every real matrix and vector `(A', x')`
(`M × K` and length `K`) and grades `G` within which each input word approximates the importer's
reading of `(A', x')` (`readIn` at `.matVec`), each `W i` is within the grade of
`GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉` of entry `i` of TorchLean's contraction `.matVec`
of `A'` and `x'` (`denote`), read by the importer (`readOut`): `MojoProof.Tile.Loads` at
`GPUProof.Importer.Graded` of `torchLean` at `.matVec`. -/
def TorchRows {M : Nat} (K bits : Nat)
    (gv : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (monov : ∀ σ E A, Monotone (gv σ E A))
    (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words)
    (f : Fin M → Except Fault Val) : Prop :=
  MojoProof.Tile.Loads .float
    ((torchLean (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
      (GPUProof.laneVecGrade_mono _ _ _) gv monov).Graded .matVec rfl
      (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5) (M, K)
      (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)) I) f

/-- **Rows that meet the spec's rule meet `TorchRows`** (test of gemv_kernel's relation, for
every sizes, width `bits`, grade `gv`, input words `I` and rows `f`): `RowsRule`'s graded rule
gives `GPUProof.Importer.Graded` at `torchLean`'s `.matVec` (`GPUProof.Importer.graded_of_holds`,
by `torchLean`'s `eq`; the spec's domain is everything), at the same words. -/
theorem torchRows_of_rule {M K bits : Nat}
    (gv : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (monov : ∀ σ E A, Monotone (gv σ E A))
    {I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words}
    {f : Fin M → Except Fault Val} (h : RowsRule K bits I f) : TorchRows K bits gv monov I f :=
  h.imp fun _ => And.imp_right (GPUProof.Importer.graded_of_holds _ _ rfl rfl fun _ _ => trivial)

/-- **gemv_kernel is sound against TorchLean's matrix-vector contraction**: gemv_kernel, for every
valid launch `L` whose blocks and grid are one-dimensional, whose block's `x` size 32 divides and
whose warps' rows cover the matrix's rows, argument values `p0`, `bA`, `bV` (pointers at offset 0),
`M`, a word `%4` and `K`, caller's memory `m` closed for them with `grid_rows`' bounds and buffers
holding `A` and `v`, width `bits`, input words `I` that hold `A` and `v` and grade `gv` of the
importer's `.vecMat`: the kernel is sound at `sig` for the admission "address choice below
`2 ^ 60`", the output rows (`rowsObs`) and `TorchRows`. `kernel_sound`, each done state's rows by
`torchRows_of_rule`. -/
theorem gemv_torchLean {L : Launch} {m : Mem} {M K p0 bA bV : Nat} {x4 : BitVec 32}
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M),
      .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v)
    (bits : Nat) (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words)
    (hIA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 A i j)
    (hIv : ∀ j, I (.inr j) = v.getScalar j)
    (gv : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 ⊕ Fin σ.1 × Fin σ.2) fun σ => Fin σ.2)
    (monov : ∀ σ E A, Monotone (gv σ E A)) :
    GPUProof.Kernel.Sound sig (gemv.prog, gemv.fn_0) L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩,
      .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)] m
      (fun ω => ∀ q, ω.1 q < 2 ^ 60) (fun b => rowsObs L M p0 { blocks := b })
      (TorchRows K bits gv monov I) := fun ω hω => by
  obtain ⟨s₀, h, hS⟩ := kernel_sound hC hL hx hby hbz hgy hgz hM hK hMK hMx hb0 hf0 hbA hbV hfA
    hfV hA hV bits I hIA hIv ω hω
  refine ⟨s₀, h, { hS with post := fun s hr hd => ?_ }⟩
  obtain ⟨y, hy, hR⟩ := hS.post s hr hd
  exact ⟨y, hy, torchRows_of_rule gv monov hR⟩

/-- **Test: `gemv_torchLean` with every premise proved, at two output warps**: gemv_kernel at one
block of 64 threads (`launch2 1 1 64 1`), `M = 2`, `K = 4`, the memory `GemvWarpRun.n3`,
`%4 = 0`, width 32, the input words `GemvSound.words 32 A24 v3` (as `GemvSound.sound64`) and the
grade `GPUProof.vecMatGrade` of the importer's `.vecMat`, the library's grade of
`GPUProof.Spec.vecMat`, monotone by `GPUProof.vecMatGrade_mono`: gemv_kernel is sound at `sig`
for the admission "address choice below `2 ^ 60`", the output rows and `TorchRows`. No run is
evaluated. -/
theorem torch64 :
    GPUProof.Kernel.Sound sig (gemv.prog, gemv.fn_0) (launch2 1 1 64 1) [.ptr ⟨3, 0⟩,
      .ptr ⟨1, 0⟩, .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 2), .bits 32 0,
      .bits 32 (BitVec.ofNat 32 4)] n3 (fun ω => ∀ q, ω.1 q < 2 ^ 60)
      (fun b => rowsObs (launch2 1 1 64 1) 2 3 { blocks := b })
      (TorchRows 4 32 GPUProof.vecMatGrade GPUProof.vecMatGrade_mono
        (words 32 A24 GemvThread.v3)) :=
  gemv_torchLean (n3_caller.closed 0) (launch2_valid (by decide)) (by decide) rfl rfl rfl rfl
    (by decide) (by decide) (by decide) (by decide) n3_caller.hb0 n3_caller.hf0 n3_caller.hbA
    n3_caller.hbV n3_caller.hfA n3_caller.hfV n3_caller.hA n3_caller.hV 32 _ (fun _ _ => rfl)
    (fun _ => rfl) GPUProof.vecMatGrade GPUProof.vecMatGrade_mono

end MojoProofTest.GemvTorch
