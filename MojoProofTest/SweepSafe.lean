import MojoProof.Kernels.SafeCmd
import MojoProofTest.Kernel
import MojoProofTest.SymNaive

/-!
# The spec-free mode on the sweep's bitonic step and on `vector_addition`

`mojo_safe` (MojoProof/Kernels/SafeCmd.lean) with no specification and no proof line:

* the two `bitonic_global_step` kernels of tests/sweep/483e1348/ (`True`, the ascending compare
  `sgt`, and `False`, `slt`), each safe for every launch, arguments and memory of its admission
  (`bitonicT.safe`, `bitonicF.safe`), and at one launch of 2 blocks of 4 threads on 8 cells
  (`bitonicT.safe_at`, `bitonicF.safe_at`, with the witnesses `bitonicT.obs`, `bitonicF.obs`);
* `vector_addition` (`Kernels.vadd`, whose `covers` the command reuses), at the launch, memory,
  choice and oracle of `MojoProofTest.Kernel.kernel22`: `vaddS.safe_at` is
  `Kernel.Safe.of_sound kernel22` (the cross-check, `rfl`);
* the twins: the bitonic step with its value buffer shorter than the count (a load out of
  bounds) and `vector_addition` with its output one cell after its first input (a data race),
  each refused with the first obligation left named, and its admission false.

With `mojo_kernel.share`, a bitonic block whose summary an imported definition has is that
definition (`MojoProofTest.SymNaive.body`, `MojoProof.Kernels.vadd.b3`). They cover these kernels
at these launches; the `safe` theorems cover every launch, arguments and memory of the admission.
-/

namespace MojoProofTest.SweepSafe

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Kernel MojoProofTest.SymRun
open MojoProofTest.Start

set_option mojo_import.root "tests/sweep" in
mojo_import "483e1348/test_argsort_bitonic_global_step_True_06300ccc.nvptx.ll" as bt

set_option mojo_import.root "tests/sweep" in
mojo_import "483e1348/test_argsort_bitonic_global_step_False_a4065c82.nvptx.ll" as bf

/-- A buffer struct `{ ptr, { { i64 }, { {} } } }` (the bitonic step's parameters): the pointer to
offset 0 of block `b`, and the length `n`. -/
def bufL (b n : Nat) : Val :=
  .agg [.ptr ⟨b, 0⟩, .agg [.agg [.bits 64 (BitVec.ofNat 64 n)], .agg [.agg []]]]

/-- Two global writable blocks of `w`-byte little-endian cells, at layout `l`: block 1 holds `a`
at address 16, block 2 holds `b` after it (16-byte aligned). -/
def memRW (l : Layout) (w : Nat) (a b : List Nat) : Mem :=
  let p := 1 + (w * a.length + 15) / 16
  let m₁ := (({} : Mem).alloc l 1 (w * a.length) 16 true false .all 1 1
    (a.flatMap (leBytes w))).1
  (m₁.alloc l 1 (w * b.length) 16 true false .all p p (b.flatMap (leBytes w))).1

/-- `memRW l w a b` has no pointer byte, so its pointer bytes are known (`Mem.BytesIn`), for
every layout, width and contents. -/
theorem memRW_bytesIn (l : Layout) (w : Nat) (a b : List Nat) :
    (memRW l w a b).BytesIn (memRW l w a b).Known := by
  have h0 : ({} : Mem).BytesIn (memRW l w a b).Known := fun _ _ _ _ _ h => by cases h
  have hA : ∀ (xs : List Nat) p j, MemByte.ptr p j ∈ xs.flatMap (leBytes w) →
      (memRW l w a b).Known p.block := by
    intro xs p j h
    simp [leBytes] at h
  exact Mem.alloc_bytesIn (Mem.alloc_bytesIn h0 (hA a) _ _ _ _ _ _ _ _ _ _) (hA b)
    _ _ _ _ _ _ _ _ _ _

/-- The bitonic step's arguments: the indices in block 1 and the values in block 2, of length
`len`, the count `n`, the partner distance `j` and the run length `k`. -/
def argsB (len n j k : Nat) : List Val :=
  [bufL 1 len, bufL 2 len, .bits 32 (BitVec.ofNat 32 n), .bits 32 (BitVec.ofNat 32 j),
    .bits 32 (BitVec.ofNat 32 k)]

/-- The indices 0 to 7 and eight values. -/
def memB : Mem := memRW bt.prog.layout 8 (List.range 8) [5, 3, 8, 1, 9, 2, 7, 4]

set_option mojo_kernel.share true in
mojo_safe bitonicT := bt.prog bt.fn_0
  at (launch2 2 1 4 1) (argsB 8 8 1 2) memB ch₀ ω₀ (memRW_bytesIn _ _ _ _)

set_option mojo_kernel.share true in
mojo_safe bitonicF := bf.prog bf.fn_0
  at (launch2 2 1 4 1) (argsB 8 8 1 2) memB ch₀ ω₀ (memRW_bytesIn _ _ _ _)

unseal Array.anyM.loop in
/-- At `bitonicT.safe_at`'s launch, arguments, memory, choice and oracle, `Kernel.firstFail` names
no obligation (a test of one launch). -/
theorem bitonicT_firstFail :
    Kernel.firstFail bt.prog bt.fn_0 (launch2 2 1 4 1) (argsB 8 8 1 2) memB bitonicT.paths
      ch₀ ω₀ = none := by
  decide +kernel

/-- The twin's memory: eight indices, but four values. -/
def memShort : Mem := memRW bt.prog.layout 8 (List.range 8) [5, 3, 8, 1]

-- At partner distance 4, thread 0 loads value 4, past the four values.
example : ¬ Kernel.Admits bt.prog bt.fn_0 (launch2 2 1 4 1) (argsB 8 8 4 8) memShort
    bitonicT.paths ch₀ ω₀ := by
  decide +kernel

/--
error: mojo_safe: the admission does not hold at (launch2 2 1 4 1): thread 0: block %34:
obligation 0 of 7 (a branch condition evaluates to a word) does not hold: undefined behavior:
access out of bounds (bt.fn_0)
-/
#guard_msgs (whitespace := lax) in
mojo_safe bitonicShort := bt.prog bt.fn_0
  at (launch2 2 1 4 1) (argsB 8 8 4 8) memShort ch₀ ω₀ (memRW_bytesIn _ _ _ _)

mojo_safe vaddS := Kernels.vadd.prog Kernels.vadd.fn_0
  at (launch2 2 1 2 1) args3 mem0 ch₀ ω₀ mem0_bytesIn

-- The cross-check: at `kernel22`'s launch, arguments, memory, choice and oracle, the mode's
-- theorem is the spec-free weakening of the kernel theorem.
example : vaddS.safe_at = Kernel.Safe.of_sound kernel22 := rfl

/-- `vector_addition`'s arguments with the output one cell (4 bytes) after the first input's
start, in block 1, and the count 3. -/
def argsRace : List Val :=
  [buf 1, buf 2, .agg [.ptr ⟨1, 4⟩, .agg [.agg [.agg []], .agg [.agg []]]],
    .bits 32 (BitVec.ofNat 32 3)]

/-- The race twin's memory: the two inputs of `mem0`, both writable. -/
def memRace : Mem := memRW Kernels.vadd.prog.layout 4 inA inB

-- Thread 0 stores cell 1 of block 1, which thread 1 loads.
example : ¬ Kernel.Admits Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsRace memRace
    Kernels.vadd.paths ch₀ ω₀ := by
  decide +kernel

/--
error: mojo_safe: the admission does not hold at (launch2 2 1 2 1): race freedom: the trace of
the threads, run in turn, has a data race (GPUProof.racy) (Kernels.vadd.fn_0)
-/
#guard_msgs (whitespace := lax) in
mojo_safe vaddRace := Kernels.vadd.prog Kernels.vadd.fn_0
  at (launch2 2 1 2 1) argsRace memRace ch₀ ω₀ (memRW_bytesIn _ _ _ _)

end MojoProofTest.SweepSafe
