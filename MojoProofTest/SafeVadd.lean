import MojoProof.Kernels.Safe
import MojoProofTest.Kernel

/-!
# `vector_addition` is safe, and at one launch it has an observation

`MojoProof.Sem.Kernel.Safe.of_sound` at `vector_addition`'s kernel theorem
(`Kernels.vadd.correct`, MojoProof/Kernels/Vadd.lean): the spec-free statement for every launch
and input of its premises (`vadd_safe`), at the launch `L23` and memory `mem5` of
MojoProofTest/Kernel.lean (`vadd_safe23`), and the observation of a complete run there
(`vadd_safe_obs23`, `MojoProof.Sem.Kernel.Sound.exists_obs` at a valid launch, the witness form
of scripts/L3Programs.lean). They are about `vector_addition` (tests/corpus/vadd/) only.
-/

namespace MojoProofTest.SafeVadd

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Kernel
open FloatLib.Floats.Formats.BinaryInterchange

section Vadd

variable {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
  (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
  {x y : TorchLean.Tensor (Model .binary32) [N]} {m : Mem}
  (hP : Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) al
    Kernels.vadd.argTail m a b out n x y)
include hL hg hb hal hP

/-- **`vector_addition` is safe** (`Kernel.Safe`), for every valid launch whose grid and block
have side 1 in `y` and `z`, alignment that 4 divides, and every memory of `Map2.Pre`, for the
observation of the blocks: at every address choice and oracle family the launch starts, and
its grid does not fault, race, break an `!invariant.load` promise or deadlock, terminates, and
observes one value of the blocks for every schedule (`Kernel.Safe.of_sound` at
`Kernels.vadd.correct`, at each oracle family). It says nothing of the output's bytes. A test of
`Kernel.Safe.of_sound` at one program, `vector_addition`, not a kernel theorem of its own. -/
theorem vadd_safe : Kernel.Safe Kernels.vadd.prog Kernels.vadd.fn_0 L
    (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ _ => True)
    (fun m => some m.blocks) := fun ch ω _ =>
  Kernel.Safe.of_sound (adm := fun _ ω' => ω' = ω) (Kernels.vadd.correct hL hg hb hal hP) ch ω
    rfl

end Vadd

/-- **`vector_addition` is safe at `L23` and `mem5`** (`vadd_safe` at `valid23` and `pre5`): on
2 blocks of 3 threads with count 5, for the observation of the blocks, at every address choice
and oracle family. A test at one launch, not a kernel theorem. -/
theorem vadd_safe23 : Kernel.Safe Kernels.vadd.prog Kernels.vadd.fn_0 L23
    (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ _ => True)
    (fun m => some m.blocks) :=
  vadd_safe valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5

/-- **`vadd_safe23` has an observation**, for every oracle family `ω` and address choice `ch`: `L23`
is a valid launch (`valid23`), and some complete run of `vector_addition` on `L23` at `mem5` under
`ch` and `ω` (`Kernel.Obs`) observes blocks `Bk` (`MojoProof.Sem.Kernel.Sound.exists_obs` at
`vadd_safe23`). For this program, launch and memory only: a test, the witness of `vadd_safe23` and
`vadd_safe`. -/
theorem vadd_safe_obs23 (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    L23.Valid ∧ ∃ Bk, Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω Bk ∧
      True :=
  ⟨valid23, Kernel.Sound.exists_obs vadd_safe23 trivial⟩

example (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω Bk ∧
      True :=
  (vadd_safe_obs23 ω ch).2

end MojoProofTest.SafeVadd
