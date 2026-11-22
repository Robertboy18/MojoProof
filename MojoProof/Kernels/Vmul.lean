import MojoProof.Kernels
import MojoProof.Kernels.Vadd
import MojoProof.Sym.KernelCmd
import MojoProof.Sym.Ops
import MojoProof.Sem.Elementwise

/-!
# vector_multiply's paths and the kernel theorem along them

`mojo_kernel` on vector_multiply (`Kernels.vmul`, tests/corpus/vmul/, written for this library:
`vector_addition` with `*` for `+`, compiled with contraction off), with the clauses of
`vector_addition` (MojoProof/Kernels/Vadd.lean): the inputs `a0` and `a1`, the output `a2` and
the count `a3`, and `map2` at floats with the bytes `vmul.bytes`, the specification written before
the command (`deliver (x_k * y_k)` at thread `k`'s `fmul` oracle number for `k < n`, nothing
otherwise). The command generates `vmul.b1` (the summary of block `%21`), `vmul.paths`,
`vmul.covers`, `vmul.sound_of`, `vmul.starts`, `vmul.sound`, `vmul.ret` (by mojo_ret) and the
kernel theorem `vmul.correct`: vector_multiply is sound at every address choice and oracle `ω`
for every valid launch whose grid and block have side 1 in `y` and `z`, alignment that 4
divides, and every caller's memory of `Map2.Pre`, block `out` being the caller's with the bytes
`vmul.bytes ω x y n i` put at cell `4 i` for every thread `i` (the product's float for `i < n`,
nothing for the others) and every other block unchanged (`Kernel.sound_map2`). Like
`vadd.correct`, it covers this one kernel.

The summaries of blocks `%4`, `%30` and `%31`, the arguments, the struct type and its tail are
`vector_addition`'s (`vadd.b0`, `vadd.b2`, `vadd.b3`, `vadd.args`, `vadd.argTy`, `vadd.argTail`):
this module imports MojoProof/Kernels/Vadd.lean, and the command in a library module names an
earlier definition of the same value instead of adding it again, so the library has no two
definitions of one value.

Nothing is written by hand after the command: the specification `vmul.bytes` before it and the
command's clauses are the whole kernel-specific text.
-/

namespace MojoProof.Kernels

open MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean FloatLib.Floats.Formats.BinaryInterchange

/-- The bytes thread `k` of `vector_multiply` stores at oracle `ω`, for count `n` and vectors
`x`, `y` of length `N`: for `k < n` and `k < N`, the encoding of `deliver (x_k * y_k)` at the
oracle number of thread `k`'s `fmul` (`ω k (Nat.pair 23 0) / 3`); `none` otherwise. -/
def vmul.bytes (ω : Nat → Nat → Nat) {N : Nat} (x y : Tensor (Model FloatTy.float.fmt) [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then
    vmul.prog.layout.encode (.fp .float) (Val.ofFloat .float
      (deliver (Model.mul (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit)))
        (ω k (Nat.pair 23 0) / 3)))
  else none

mojo_kernel vmul := Kernels.vmul.prog Kernels.vmul.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) vmul.bytes

end MojoProof.Kernels
