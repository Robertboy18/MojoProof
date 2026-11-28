import MojoProofTest.GemvSound
import MojoProofTest.GemvTorch
import MojoProofTest.GevmSound

/-!
# gemv_kernel's and gevm_kernel's theorems have an observation, at one launch each

The theorems of MojoProofTest/GemvSound.lean (`kernel_sound`, `sound64`),
MojoProofTest/GemvTorch.lean (`torch64`) and MojoProofTest/GevmSound.lean (`kernel_sound`,
`sound1024`, `torch1024`) conclude soundness at `sig` (`GPUProof.Kernel.Sound`), whose choice is a
pair of an address choice and an oracle family. `Kernel.Sound.of_sig`
(MojoProof/Sym/SigKernel.lean) turns such a theorem into `Kernel.Sound` (MojoProof/Sem/Spec.lean),
at the admission of the pair, for an observation that reads only the blocks (`warpObs_blocks`);
then `Kernel.Sound.exists_obs` gives a complete run and its observation (`Kernel.Obs`, as
MojoProofTest/ElemObs.lean has it for the elementwise kernels).

* `obs64`: `GemvSound.sound64` (gemv_kernel at one block of 64 threads, `M = 2`, `K = 4`, the
  memory `GemvWarpRun.n3`) at the address choice 0 everywhere and the oracle family 0
  everywhere: the launch is valid, a complete run is observed, and its two output rows meet
  `GemvSound.RowsRule`, the rule of `GPUProof.Spec.matVec` at the input words of the `2 × 4`
  matrix of ones and the vector of twos. The choice 0 meets the admission "address choice below
  `2 ^ 60`".
* `obsTorch64`: the same from `GemvTorch.torch64`: the two rows meet `GemvTorch.TorchRows`, graded
  against TorchLean's contraction of every real matrix and vector the input words approximate.
* `obs1024`: `GevmSound.sound1024` (gevm_kernel at one block of 1024 threads, `N = K = 32`) at the
  vector `GemvLoopBfly.v32` of ones, the matrix `b32` of twos, `%3 = 0`, the address choice 0 and
  the oracle family 0: the launch is valid, a complete run is observed, and its 32 output columns
  meet `GevmSpec.ColsRule`. The choice 0 meets the admission "the shared array fits below
  `2 ^ 32`" (its address 0, 4096 bytes).
* `obsTorch1024`: the same from `GevmSound.torch1024`: the 32 columns meet `GevmSpec.TorchCols`,
  graded against TorchLean's contraction.

Each is a theorem with no binder and no premise, at one closed launch, arguments, memory,
address choice and oracle family, whose proof is `launch2_valid` and `Kernel.Sound.exists_obs` at
`Kernel.Sound.of_sig` applied to the kernel's theorem, so the kernel theorem's premises hold
together at this launch and memory, its admission at this choice, and its relation of an
observed output. Each covers its launch, memory and choice only; none evaluates a run.
-/

namespace MojoProofTest.GemvObs

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open FloatLib.Floats.Formats.BinaryInterchange

/-- **The output words read only the blocks**, for every layout, launch, count, output block and
two memories with the same blocks: `MojoProof.Tile.warpObs` is the same at both
(`Mem.load_of_block`). The premise `Kernel.Sound.of_sig` asks of `GemvSound.rowsObs` and
`GevmSpec.colsObs`. -/
theorem warpObs_blocks {l : Layout} {L : Launch} {M p0 : Nat} {m m' : Mem}
    (hb : m.blocks = m'.blocks) :
    MojoProof.Tile.warpObs l L M p0 m = MojoProof.Tile.warpObs l L M p0 m' :=
  congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _)

/-- **`GemvSound.sound64` has an observation**: gemv_kernel at one block of 64 threads
(`launch2 1 1 64 1`, valid), the output at block 3, the `2 × 4` matrix of ones at block 1 and the
vector of twos at block 2 (`GemvWarpRun.n3`), `%4 = 0`, at the address choice 0 everywhere and the
oracle family 0 everywhere: some complete run (`Kernel.Obs`) observes output rows (`rowsObs`)
that meet `GemvSound.RowsRule` at the input words `words 32 A24 v3` (each row a binary32 word
within the rule of `GPUProof.Spec.matVec` of its row and the vector). `Kernel.Sound.exists_obs`
at `Kernel.Sound.of_sig` of `sound64`; the choice 0 is below `2 ^ 60`. For this launch, memory
and choice only. -/
theorem obs64 : (launch2 1 1 64 1).Valid ∧
    ∃ y, Kernel.Obs gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 2), .bits 32 0, .bits 32 (BitVec.ofNat 32 4)]
      GemvWarpRun.n3 (GemvSound.rowsObs (launch2 1 1 64 1) 2 3) (fun _ => 0) (fun _ _ => 0) y ∧
      GemvSound.RowsRule 4 32 (GemvSound.words 32 GemvWarpRun.A24 GemvThread.v3) y :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs
    (Kernel.Sound.of_sig (obs := GemvSound.rowsObs (launch2 1 1 64 1) 2 3)
      (fun _ _ => warpObs_blocks) GemvSound.sound64)
    (ch := fun _ => 0) (ω := fun _ _ => 0) fun _ => Nat.two_pow_pos 60⟩

/-- **`GemvTorch.torch64` has an observation**: at `obs64`'s launch, arguments, memory, address
choice and oracle family, some complete run observes output rows that meet `GemvTorch.TorchRows`
at the input words `words 32 A24 v3` (each row graded against TorchLean's contraction of every
real matrix and vector those words approximate). `Kernel.Sound.exists_obs` at
`Kernel.Sound.of_sig` of `torch64`. For this launch, memory and choice only. -/
theorem obsTorch64 : (launch2 1 1 64 1).Valid ∧
    ∃ y, Kernel.Obs gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 2), .bits 32 0, .bits 32 (BitVec.ofNat 32 4)]
      GemvWarpRun.n3 (GemvSound.rowsObs (launch2 1 1 64 1) 2 3) (fun _ => 0) (fun _ _ => 0) y ∧
      GemvTorch.TorchRows 4 32 GPUProof.vecMatGrade GPUProof.vecMatGrade_mono
        (GemvSound.words 32 GemvWarpRun.A24 GemvThread.v3) y :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs
    (Kernel.Sound.of_sig (obs := GemvSound.rowsObs (launch2 1 1 64 1) 2 3)
      (fun _ _ => warpObs_blocks) GemvTorch.torch64)
    (ch := fun _ => 0) (ω := fun _ _ => 0) fun _ => Nat.two_pow_pos 60⟩

/-- The `32 × 32` matrix of binary32 twos, gevm_kernel's `B` in `obs1024`. A test definition. -/
def b32 : TorchLean.Tensor (Model FloatTy.float.fmt) [32, 32] :=
  TorchLean.Tensor.Rep.ofFn fun _ => Model.ofNatBits 0x40000000

/-- **`GevmSound.sound1024` has an observation**: gevm_kernel at one block of 1024 threads
(`launch2 1 1 1024 1`, valid), `N = K = 32`, the memory `GemvThread.mem b32 GemvLoopBfly.v32` (the
matrix of twos at block 1, the vector of ones at block 2, the output at block 3), `%3 = 0`, at the
address choice 0 everywhere and the oracle family 0 everywhere: some complete run (`Kernel.Obs`)
observes output columns (`GevmSpec.colsObs`) that meet `GevmSpec.ColsRule` at the input words
`colWords 32 GemvLoopBfly.v32 b32` (each column a binary32 word within the rule of
`GPUProof.Spec.vecMat` of the vector and its column). `Kernel.Sound.exists_obs` at
`Kernel.Sound.of_sig` of `sound1024`; the choice 0 puts the shared array at address 0, its 4096
bytes below `2 ^ 32`. For this launch, memory and choice only. -/
theorem obs1024 : (launch2 1 1 1024 1).Valid ∧
    ∃ y, Kernel.Obs gevm.prog gevm.fn_0 (launch2 1 1 1024 1) [.ptr ⟨3, 0⟩, .ptr ⟨2, 0⟩,
      .ptr ⟨1, 0⟩, .bits 32 0, .bits 32 (BitVec.ofNat 32 32), .bits 32 (BitVec.ofNat 32 32)]
      (GemvThread.mem b32 GemvLoopBfly.v32) (GevmSpec.colsObs (launch2 1 1 1024 1) 32 3)
      (fun _ => 0) (fun _ _ => 0) y ∧
      GevmSpec.ColsRule 32 32 (GevmSpec.colWords 32 GemvLoopBfly.v32 b32) y :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs
    (Kernel.Sound.of_sig (obs := GevmSpec.colsObs (launch2 1 1 1024 1) 32 3)
      (fun _ _ => warpObs_blocks) (GevmSound.sound1024 GemvLoopBfly.v32 b32 0))
    (ch := fun _ => 0) (ω := fun _ _ => 0) fun _ _ => by norm_num⟩

/-- **`GevmSound.torch1024` has an observation**: at `obs1024`'s launch, arguments, memory,
address choice and oracle family, some complete run observes output columns that meet
`GevmSpec.TorchCols` at the input words `colWords 32 GemvLoopBfly.v32 b32` (each column graded
against TorchLean's contraction of every real vector and matrix those words approximate).
`Kernel.Sound.exists_obs` at `Kernel.Sound.of_sig` of `torch1024`. For this launch, memory and
choice only. -/
theorem obsTorch1024 : (launch2 1 1 1024 1).Valid ∧
    ∃ y, Kernel.Obs gevm.prog gevm.fn_0 (launch2 1 1 1024 1) [.ptr ⟨3, 0⟩, .ptr ⟨2, 0⟩,
      .ptr ⟨1, 0⟩, .bits 32 0, .bits 32 (BitVec.ofNat 32 32), .bits 32 (BitVec.ofNat 32 32)]
      (GemvThread.mem b32 GemvLoopBfly.v32) (GevmSpec.colsObs (launch2 1 1 1024 1) 32 3)
      (fun _ => 0) (fun _ _ => 0) y ∧
      GevmSpec.TorchCols 32 32 GPUProof.matVecGrade GPUProof.matVecGrade_mono
        (GevmSpec.colWords 32 GemvLoopBfly.v32 b32) y :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs
    (Kernel.Sound.of_sig (obs := GevmSpec.colsObs (launch2 1 1 1024 1) 32 3)
      (fun _ _ => warpObs_blocks) (GevmSound.torch1024 GemvLoopBfly.v32 b32 0))
    (ch := fun _ => 0) (ω := fun _ _ => 0) fun _ _ => by norm_num⟩

end MojoProofTest.GemvObs
