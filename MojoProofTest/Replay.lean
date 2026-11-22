import MojoProof.Sem.Replay
import MojoProofTest.Kernel

/-!
# The trace-replay checker on `vector_addition`: a control and certified violations

Instances of `Kernel.replay` (MojoProof/Sem/Replay.lean) on `vector_addition` (`Kernels.vadd`)
launched on 2 blocks of 3 threads (`L23`) with count 5, at address choice `ch₀` and oracle `ω₀`
(MojoProofTest/Kernel.lean), 100 steps per thread and phase and 3 phases, by kernel evaluation:

* `control`: on `correct23`'s memory `mem5`, the replay that compares output block 3's final
  bytes with the ones `Elem.Out` fixes for `Kernels.vadd.bytes ω₀ x5 y5 5` finds no violation
  (`Found.passed`).
* The wrong outputs: for each probe of the output (`Probe.drop 4`, `Probe.stale`, `Probe.swap 0 1`,
  `Probe.zero 4 5`, `Probe.copy` of `x5`), the replay reports the final block as a violation of
  `Elem.Out` with the probe's bytes, so `vector_addition` is not sound for it, for every
  admission that admits `ch₀` and `ω₀` (`Kernel.replay_block`): `omit_cell`, `stale_out`,
  `swap_cells`, `zero_out`, `input_copy`. `refute` is their common step. `pre_refutes`: since
  `mem5` meets `Map2.Pre` (`pre5`), each refutes the kernel theorem with that precondition.
* A faulting launch: on `mem4`, `mem5` with an output buffer of 4 floats, one short of the count,
  the replay reports undefined behavior at thread 4 (`short_found`), so `vector_addition` is not
  sound there for any observation and relation (`short_unsafe`, `Kernel.replay_unsafe`), and the
  start grid reaches a grid with a faulting step or a deadlock (`short_reach`, `Grid.run_ub`).
* `race?` and `broken?` on traces of two accesses (`Kernel.lean`'s write `w`).

Each result covers the launch, memory, choice and oracle named, not all programs.
-/

namespace MojoProofTest.Replay

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Kernel
open MojoProofTest.SymRun (ctx0)

unseal Array.anyM.loop

/-- **Control: no violation.** The replay of `correct23`'s launch on `mem5` at `ch₀` and `ω₀`
ends with output block 3 holding the bytes `Elem.Out` fixes, and finds no fault, race or broken
promise. -/
theorem control :
    (Kernel.replay Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ 100 3
      (fun m => Replay.bytes? (m.blocks 3))
      (fun z => some z = Replay.bytes? ((mem5.blocks 3).map
        (Elem.put (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 6)))).passed = true := by
  decide +kernel

/-- A replay that compares output block 3's final bytes with the ones `Elem.Out` fixes for the
bytes `bs` and reports a violation refutes `vector_addition`'s kernel theorem for `Elem.Out` with
`bs` on `mem5`, for every admission that admits `ch₀` and `ω₀` (`Kernel.replay_block`). -/
theorem refute {bs : Nat → Option (List MemByte)}
    (h : (Kernel.replay Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ 100 3
      (fun m => Replay.bytes? (m.blocks 3))
      (fun z => some z = Replay.bytes? ((mem5.blocks 3).map
        (Elem.put (fun i => 4 * i) bs 6)))).bad = true)
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) bs 6) :=
  Kernel.replay_block (fun _ hB => hB.1) (by decide +kernel) h hadm

/-- **Wrong output: one cell omitted.** Thread 4 storing nothing is refuted. -/
theorem omit_cell {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Probe.drop 4 (Kernels.vadd.bytes ω₀ x5 y5 5)) 6) :=
  refute (by decide +kernel) hadm

/-- **Wrong output: stale.** No thread storing is refuted. -/
theorem stale_out {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) Probe.stale 6) :=
  refute (by decide +kernel) hadm

/-- **Wrong output: cells permuted.** Cells 0 and 1 (the sums 33 and 18) swapped is refuted. -/
theorem swap_cells {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Probe.swap 0 1 (Kernels.vadd.bytes ω₀ x5 y5 5)) 6) :=
  refute (by decide +kernel) hadm

/-- **Wrong output: zeros.** Threads 0 to 4 storing 4 zero bytes is refuted. -/
theorem zero_out {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Probe.zero 4 5) 6) :=
  refute (by decide +kernel) hadm

/-- **Wrong output: the input copied.** Threads 0 to 4 storing the input `x5`'s cells is
refuted. -/
theorem input_copy {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i)
        (Probe.copy Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) x5 5) 6) :=
  refute (by decide +kernel) hadm

/-- **With the precondition.** `mem5` meets `Map2.Pre` (`pre5`), so a refutation on `mem5`
refutes the kernel theorem for `Elem.Out` with bytes `bs` on every memory meeting it. -/
theorem pre_refutes {bs : Nat → Option (List MemByte)}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    (h : ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) bs 6)) :
    ¬ ∀ m, Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16
      Kernels.vadd.argTail m 1 2 3 5 x5 y5 →
      Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
        (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) m adm (fun m => some m.blocks)
        (Elem.Out m 3 (fun i => 4 * i) bs 6) :=
  fun H => h (H mem5 pre5)

/-- `pre_refutes` on the canary `omit_cell`, at `correct23`'s admission for `ω₀`. -/
example : ¬ ∀ m, Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16
      Kernels.vadd.argTail m 1 2 3 5 x5 y5 →
      Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
        (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) m (fun _ ω' => ω' = ω₀)
        (fun m => some m.blocks)
        (Elem.Out m 3 (fun i => 4 * i) (Probe.drop 4 (Kernels.vadd.bytes ω₀ x5 y5 5)) 6) :=
  pre_refutes (omit_cell rfl)

/-- The replay on `mem4` reports undefined behavior at thread 4 (its store past the buffer). -/
theorem short_found :
    (Kernel.replay Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 ch₀ ω₀ 100 3 (fun _ => some ())
      (fun _ => True) matches .ub 4 _) = true := by
  decide +kernel

/-- **A certified fault**: on `mem4`, `vector_addition` is not sound for any observation and
relation, for every admission that admits `ch₀` and `ω₀` (`Kernel.replay_unsafe`). -/
theorem short_unsafe {β : Type} {obs : Mem → Option β} {R : β → Prop}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 adm obs R :=
  Kernel.replay_unsafe (fuel := 100) (phases := 3) (by decide +kernel) hadm

/-- The start's grid and contexts on `mem4` (the empty grid if it faults). -/
def run4 : Grid × (Nat → Ctx) :=
  match Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
    (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 ch₀ ω₀ with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ctx0)

/-- The launch on `mem4` starts, with `run4` (evaluated). -/
theorem start4 :
    Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 ch₀ ω₀ = .ok run4 := rfl

/-- **`Grid.run_ub` on the short buffer**: the evaluator's run of `mem4`'s start grid ends in
undefined behavior, so the start grid reaches a grid with a faulting step or a deadlock. -/
theorem short_reach : ∃ g', Relation.ReflTransGen (Grid.Step L23 run4.2) run4.1 g' ∧
    (g'.Faults L23 run4.2 ∨ ¬ g'.Done ∧ ∀ g'', ¬ Grid.Step L23 run4.2 g' g'') := by
  have h : (match run4.1.run L23 run4.2 100 3 with
      | .error (.ub _) => true
      | _ => false) = true := by
    decide +kernel
  split at h
  next msg hr => exact Grid.run_ub hr
  next => cases h

/-- `race?`: two writes of one cell by threads 0 and 2 of a block race; the later is first. -/
example : race? [w 2, w 0] =
    some (⟨⟨2, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩, ⟨⟨0, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩) := by
  decide

/-- `race?`: a barrier of their block between them orders them. -/
example : race? [w 2, .barrier 0, w 0] = none := by decide

/-- `broken?`: a write to the bytes a load with `!invariant.load` reads breaks its promise. -/
example : broken? [w 0, .access ⟨⟨1, 0⟩, ⟨3, 0⟩, 4, false, none, true⟩] =
    some (⟨⟨1, 0⟩, ⟨3, 0⟩, 4, false, none, true⟩, ⟨⟨0, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩) := by
  decide

end MojoProofTest.Replay
