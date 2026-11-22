import MojoProof.Kernels.Vadd
import MojoProofTest.Start

/-!
# `vadd` starts on every launch

`Sym.Grid.start_ok` (MojoProof/Sym/Start.lean) at `vadd` (`Kernels.vadd`) on three buffers
`Start.buf a`, `buf b`, `buf o` and a size `n`: for every launch, block numbers `a`, `b`, `o`, size,
memory closed for the arguments, address choice and oracle, `Grid.start` returns a grid
(`vadd_starts`). It is `Kernels.vadd.starts`, which `mojo_kernel` generates
(MojoProof/Kernels/Vadd.lean), since `Kernels.vadd.args a b o n` is these arguments by definition.
`Start.memV` is closed for `Start.argsV` (`memV_closed`; blocks 1, 2, 3 and size 4), so the premise
`Mem.Closed` holds of a memory, and `vadd` starts on every launch on `memV` (`vadd_starts_memV`).

The twin of the premise on `byval` arguments: with the size in place of the first buffer
(`argsB`), `memV` is closed for the arguments, but on `two2` the start faults for every address
choice and oracle, since the size does not encode as the buffer's type (`byval_twin`). With the
size left out (`argsV.take 3`, three values for four parameters), `vadd` starts on `two2` on
`memV` (`short_starts`): the start does not compare the number of arguments with the number of
parameters.
-/

namespace MojoProofTest.SymLaunch

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.Start

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate `Func.check` without
-- this.
unseal Array.anyM.loop

/-- **`vadd` starts on every launch.** For every launch `L`, block numbers `a`, `b`, `o`, size
`n`, memory `m` closed for `[buf a, buf b, buf o, .bits 32 n]`, address choice and oracle,
`Grid.start` of `vadd` on these arguments returns a grid and contexts. -/
theorem vadd_starts (L : Launch) (a b o : Nat) (n : BitVec 32) {m : Mem}
    (hC : m.Closed [buf a, buf b, buf o, .bits 32 n]) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L [buf a, buf b, buf o, .bits 32 n] m
      ch oracle = .ok (g, c) :=
  Kernels.vadd.starts L a b o n hC ch oracle

/-- `memV` is closed for `argsV`: `next` is 4, there is no block 0 nor from 4 on, the arguments
name blocks 1 to 3, and no byte is a pointer. -/
theorem memV_closed : memV.Closed argsV where
  pos := by decide
  null := rfl
  above c hc := by
    simp only [memV] at hc ⊢
    split
    · omega
    · rfl
  vals := by decide
  bytes c b i p j hc _ hp := by
    simp only [memV] at hc
    split at hc
    · cases hc
      cases hp
    · cases hc

/-- `vadd` starts on `memV` on every launch, for every address choice and oracle. -/
theorem vadd_starts_memV (L : Launch) (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L argsV memV ch oracle = .ok (g, c) :=
  vadd_starts L 1 2 3 (BitVec.ofNat 32 4) memV_closed ch oracle

/-- `argsV` with the size in place of the first buffer. -/
def argsB : List Val := [.bits 32 (BitVec.ofNat 32 4), buf 2, buf 3, .bits 32 (BitVec.ofNat 32 4)]

/-- **The twin of the premise on `byval` arguments.** `memV` is closed for `argsB`, but `vadd` on
`two2` on `argsB` faults, for every address choice and oracle: the size does not encode as the
first parameter's `byval` type. -/
theorem byval_twin (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    memV.Closed argsB ∧ Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 two2 argsB memV ch oracle =
      .error (.unsupported "byval argument not of its type") :=
  ⟨{ memV_closed with vals := by decide }, rfl⟩

/-- **The start does not count the arguments.** `vadd` has four parameters, `argsV.take 3` three
values, and `vadd` on `two2` starts on them on `memV`, for every address choice and oracle. -/
theorem short_starts (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    Kernels.vadd.fn_0.params.length = 4 ∧ (argsV.take 3).length = 3 ∧ ∃ g c,
      Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 two2 (argsV.take 3) memV ch oracle =
        .ok (g, c) :=
  ⟨rfl, rfl, _, _, rfl⟩

end MojoProofTest.SymLaunch
