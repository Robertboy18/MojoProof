import MojoProof.Kernels
import MojoProof.Kernels.Vadd
import MojoProof.LLVM.Quote
import MojoProof.Sym.KernelCmd
import MojoProof.Sym.Ops
import MojoProof.Sem.Elementwise

/-!
# vector_subtraction's paths and the kernel theorem along them

The worked example of docs/new-kernel.md. `mojo_import` adds `vsub.prog`, the program of
vector_subtraction (tests/corpus/vsub/, written for this library: `vector_addition` with `-` for
`+`), and `mojo_kernel` runs on it with the clauses of `vector_addition`
(MojoProof/Kernels/Vadd.lean): the inputs `a0` and `a1`, the output `a2` and the count `a3`, and
`map2` at floats with the bytes `vsub.bytes`, the specification written before the command
(`deliver (x_k - y_k)` at thread `k`'s `fsub` oracle number for `k < n`, nothing otherwise). The
command generates `vsub.b1` (the summary of block `%21`), `vsub.paths`, `vsub.covers`,
`vsub.sound_of`, `vsub.starts`, `vsub.sound`, `vsub.ret` (by mojo_ret) and the kernel theorem
`vsub.correct`: vector_subtraction is sound at every address choice and oracle `ω` for every
valid launch whose grid and block have side 1 in `y` and `z`, alignment that 4 divides, and every
caller's memory of `Map2.Pre`, block `out` being the caller's with the bytes `vsub.bytes ω x y n i`
put at cell `4 i` for every thread `i` (the difference's float for `i < n`, nothing for the
others) and every other block unchanged (`Kernel.sound_map2`). Like `vadd.correct`, it covers
this one kernel.

The file differs from `vector_addition`'s only in its names and in block `%21`'s `fsub`, so
`mojo_import` names `vector_addition`'s blocks `%4`, `%30` and `%31`, and the command names the
summaries of those blocks, the arguments, the struct type and its tail of `vector_addition`
(`vadd.b0`, `vadd.b2`, `vadd.b3`, `vadd.args`, `vadd.argTy`, `vadd.argTail`): this module
imports MojoProof/Kernels/Vadd.lean, and both commands in a library module name an earlier
definition of the same value instead of adding it again, so the library has no two definitions
of one value.

Nothing is written by hand after the command: the specification `vsub.bytes` before it and the
command's clauses are the whole kernel-specific text.
-/

namespace MojoProof.Kernels

open MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean FloatLib.Floats.Formats.BinaryInterchange

mojo_import "vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll"
  as vsub

/-- The bytes thread `k` of vector_subtraction stores at oracle `ω`, for count `n` and vectors
`x`, `y` of length `N`: for `k < n` and `k < N`, the encoding of `deliver (x_k - y_k)` at the
oracle number of thread `k`'s `fsub` (`ω k (Nat.pair 23 0) / 3`); `none` otherwise. -/
def vsub.bytes (ω : Nat → Nat → Nat) {N : Nat} (x y : Tensor (Model FloatTy.float.fmt) [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then
    vsub.prog.layout.encode (.fp .float) (Val.ofFloat .float
      (deliver (Model.sub (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit)))
        (ω k (Nat.pair 23 0) / 3)))
  else none

mojo_kernel vsub := Kernels.vsub.prog Kernels.vsub.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) vsub.bytes

end MojoProof.Kernels
