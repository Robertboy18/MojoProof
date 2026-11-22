import MojoProof.Kernels
import MojoProof.Sym.KernelCmd
import MojoProof.Sym.Ops
import MojoProof.Sem.Elementwise

/-!
# `vector_addition`'s paths and the kernel theorem along them

`mojo_kernel` on `vector_addition` (`Kernels.vadd`, tests/corpus/vadd/), whose parameters are the
inputs `a0` and `a1` and the output `a2` (buffer structs passed `byval`) and the count `a3`, with
the clause `map2` at floats (`.fp .float`, `Val.ofFloat .float`) and the bytes `vadd.bytes`, the
specification written before the command (`deliver (x_k + y_k)` at thread `k`'s `fadd` oracle
number for `k < n`, nothing otherwise). The command generates:

* `vadd.b0` to `vadd.b3`: the summaries of its blocks `%4`, `%21`, `%30` and `%31`;
* `vadd.paths`: its two paths from the entry, `%4 → %21 → %31` and `%4 → %30 → %31`;
* `vadd.covers`: the path checker with `phi`s accepts both from the entry (`coversEntry`,
  evaluated by the kernel);
* `vadd.sound_of`: `Kernel.sound_of_paths` (MojoProof/Sym/Kernel.lean) at `vadd.covers`, for
  `vector_addition`, every launch, arguments, memory, admission of address choices and
  oracles, observation and predicate, from the premises that remain: the caller's pointer bytes,
  the start on every admitted choice, an observation that reads only the blocks, and an invariant
  along which each thread takes one of `vadd.paths` to `ret`;
* `vadd.args a b out n`: the arguments, buffers `a`, `b`, `out` at those block numbers and the
  count `n`; `vadd.starts`: the start on them succeeds for every launch, block numbers, count,
  memory closed for them (`Mem.Closed`), address choice and oracle (`Sym.Grid.start_ok`);
* `vadd.sound`: `vadd.sound_of` on `vadd.args` with the start by `vadd.starts`, for every launch,
  block numbers, count, closed memory, admission, observation and predicate, from the pointer
  bytes, the observation and the invariant;
* `vadd.argTy`, `vadd.argTail`: the struct type of `a0` to `a2` and the zero value of its tail;
* `vadd.ret`: thread `k`'s path from its entry is a `Ret` to the elementwise invariant `Elem`
  after `k + 1` threads with the bytes `vadd.bytes` at cells `4 i`, by the tactic mojo_ret
  (MojoProof/Sym/Ops.lean; path 0 when `k < n`, path 1 otherwise);
* `vadd.correct`, the kernel theorem of `vector_addition`: for every valid launch whose grid and
  block have side 1 in `y` and `z`, alignment that 4 divides, and every caller's memory of the
  precondition `Map2.Pre` (MojoProof/Sem/Precond.lean: closed for the arguments, distinct
  buffers `a`, `b`, `out` of at least `n` floats whose addresses do not wrap, `a`, `b` holding
  `x` and `y`, `n ≤ N`, `n < 2 ^ 31`), `vector_addition` is sound at every address choice and
  oracle `ω`: block `out` is the caller's with the bytes `vadd.bytes ω x y n i` put at cell
  `4 i` for every thread `i` (the sum's float for `i < n`, nothing for the others), and every
  other block of the caller's memory is unchanged. It is `Kernel.sound_map2`
  (MojoProof/Sym/Kernel.lean, for every kernel whose parameters `%0` to `%3` are three `byval`
  buffer structs of one type and an `i32` count) at `vadd.covers`, `vadd.starts` and `vadd.ret`;
  `Kernel.sound_map2` derives what each thread's frame holds from the start (`launchArgs`).
  It covers this one kernel, at every launch and input that meet these premises.

Nothing is written by hand after the command: the specification `vadd.bytes` before it and the
command's clauses are the whole kernel-specific text.

At one launch, memory, address choice and oracle, `Kernel.sound_eval` on `vadd.covers` closes the
kernel theorem by evaluation (`kernel22`, MojoProofTest/Kernel.lean).
-/

namespace MojoProof.Kernels

open MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean FloatLib.Floats.Formats.BinaryInterchange

/-- The bytes thread `k` of `vector_addition` stores at oracle `ω`, for count `n` and vectors
`x`, `y` of length `N`: for `k < n` and `k < N`, the encoding of `deliver (x_k + y_k)` at the
oracle number of thread `k`'s `fadd` (`ω k (Nat.pair 23 0) / 3`); `none` otherwise. -/
def vadd.bytes (ω : Nat → Nat → Nat) {N : Nat} (x y : Tensor (Model FloatTy.float.fmt) [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then
    vadd.prog.layout.encode (.fp .float) (Val.ofFloat .float
      (deliver (Model.add (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit)))
        (ω k (Nat.pair 23 0) / 3)))
  else none

mojo_kernel vadd := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) vadd.bytes

end MojoProof.Kernels
