import MojoProofTest.Kernel

/-!
# The elementwise kernels' theorems have an observation, at one launch each

`Kernel.Sound.exists_obs` (MojoProof/Sem/Spec.lean) at the kernel theorems of
`vector_addition`, vector_multiply and vector_subtraction with every premise discharged
(`correct23`, `correctV23`, `correctS23`, MojoProofTest/Kernel.lean): on 2 blocks of 3 threads
(`L23`, valid, `valid23`) with count 5 and the memories `mem5` and `memV`, at the address choice 0
everywhere and the oracle family 0 everywhere, some complete run (`Kernel.Obs`) observes blocks
that meet the theorem's `Elem.Out`. Each is a theorem with no binder and no premise, at one
closed launch, arguments, memory, address choice and oracle family, whose proof applies the
kernel theorem (`Kernels.vadd.correct`, `Kernels.vmul.correct`, `Kernels.vsub.correct`) and
reaches an observation, so that theorem's premises hold together at this launch and memory, and
its observation and relation are met by an output. The examples after each give the same at
every oracle family and address choice, by the same term. They cover these launches and memories
only.
-/

namespace MojoProofTest.ElemObs

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Kernel

/-- **`correct23` has an observation**: `L23` is valid, and some complete run of
`vector_addition` on `L23` at `mem5` under the address choice 0 and the oracle family 0
(`Kernel.Obs`) observes blocks `Bk` that meet `Elem.Out` of `Kernels.vadd.bytes` at that family,
`x5`, `y5` and 5, at the 6 threads (`Kernel.Sound.exists_obs` at `correct23`). For this program,
launch, memory and choice only. -/
theorem vadd_obs23 : L23.Valid ∧
    ∃ Bk, Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) (fun _ => 0)
      (fun _ _ => 0) Bk ∧
      Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes (fun _ _ => 0) x5 y5 5) 6 Bk :=
  ⟨valid23, (correct23 _).exists_obs rfl⟩

example (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω Bk ∧
      Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω x5 y5 5) 6 Bk :=
  (correct23 ω).exists_obs rfl

/-- **`correctV23` has an observation**: `L23` is valid, and some complete run of vector_multiply
on `L23` at `memV` under the address choice 0 and the oracle family 0 observes blocks `Bk` that
meet `Elem.Out` of `Kernels.vmul.bytes` at that family, `x5`, `x5` and 5
(`Kernel.Sound.exists_obs` at `correctV23`). For this program, launch, memory and choice
only. -/
theorem vmul_obs23 : L23.Valid ∧
    ∃ Bk, Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV (fun m => some m.blocks) (fun _ => 0)
      (fun _ _ => 0) Bk ∧
      Elem.Out memV 3 (fun i => 4 * i) (Kernels.vmul.bytes (fun _ _ => 0) x5 x5 5) 6 Bk :=
  ⟨valid23, (correctV23 _).exists_obs rfl⟩

example (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV (fun m => some m.blocks) ch ω Bk ∧
      Elem.Out memV 3 (fun i => 4 * i) (Kernels.vmul.bytes ω x5 x5 5) 6 Bk :=
  (correctV23 ω).exists_obs rfl

/-- **`correctS23` has an observation**: `L23` is valid, and some complete run of
vector_subtraction on `L23` at `mem5` under the address choice 0 and the oracle family 0 observes
blocks `Bk` that meet `Elem.Out` of `Kernels.vsub.bytes` at that family, `x5`, `y5` and 5
(`Kernel.Sound.exists_obs` at `correctS23`). For this program, launch, memory and choice
only. -/
theorem vsub_obs23 : L23.Valid ∧
    ∃ Bk, Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) (fun _ => 0)
      (fun _ _ => 0) Bk ∧
      Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vsub.bytes (fun _ _ => 0) x5 y5 5) 6 Bk :=
  ⟨valid23, (correctS23 _).exists_obs rfl⟩

example (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω Bk ∧
      Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vsub.bytes ω x5 y5 5) 6 Bk :=
  (correctS23 ω).exists_obs rfl

end MojoProofTest.ElemObs
