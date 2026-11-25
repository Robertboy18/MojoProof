import MojoProofTest.SymSegAlloca
import MojoProofTest.SymLoop

/-!
# A loop with an `alloca` in its body

The loop checker takes the `alloca` flag (`coversChainAt`, `LoopSeg.coversRoundAt`,
`coversChainsAt`, MojoProof/Sym/Loop.lean), and so do the loop theorems (`ChainWith.reach`,
`Runs.of_chainWith`, `Runs.of_chainsAt`). One hand-built kernel with gemv_kernel's header,
declarations, attribute groups, metadata and data layout (`prog`, MojoProofTest/SymSegAlloca.lean):
`@k` counts `%2` from 0 to 2, and each round of its body allocates an `i32`.

```
0:
  br label %1
1:
  %2 = phi i64 [ 0, %0 ], [ %5, %4 ]
  %3 = icmp slt i64 %2, 2
  br i1 %3, label %4, label %7
4:
  %5 = add nsw i64 %2, 1
  %6 = alloca i32, i64 1, align 4
  br label %1
7:
  ret void
```

Its locals are numbered as the parser numbers them, in the order of their first appearance in
the text (local `i` is `%n` for `n` the `i`-th of `0, 1, 5, 4, 2, 3, 7, 6`): the blocks `%0`,
`%1`, `%4` and `%7` are the locals 0, 1, 3 and 6. The module defines no name twice
(`Module.twice`), and its printed text imports back to the same module, intrinsics, data layout
and kernel `@k` (`Mutate.admission`).

* `loopK_covers`: with the `alloca` flag on, the loop checker accepts the entry block, the loop
  path `%1 → %4` from the header's position 1 and the path out `%1 → %7`; the body's summary has
  the `alloca`'s effect. With the flag off it refuses them.
* `loopK_mutant`: with the flag on, the checker refuses the body summary without its `alloca`
  effect, and the loop path from the header's position 0, its `phi`.
* `loopK_run`: for one context (`ctx0` with the program), the thread whose one frame is at
  `@k`'s first block and the start memory `memK` (one launch block at number 1 holding the `i32`
  7, so `next` is 2), the thread runs to its end (`Runs.of_chainsDead` with the flag on) on a
  memory whose blocks 18 and 83 (the numbers `Mem.fresh` gives the thread at the steps of the
  two rounds' `alloca`s) are dead and whose output load is the start memory's, 7. The premises
  are evaluated by the kernel: the entry, both rounds and the path out (`ChainWith.of_rounds`,
  trip count 2), and the memory the `ret` runs on (`run_ok`, MojoProofTest/SymLoop.lean).
* `loopK_inUse`: on the start memory with a block at 18 (`memX`), the rounds' premises fail: the
  first round's `alloca` faults on the number in use.
-/

namespace MojoProofTest.SymLoopAlloca

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymRun MojoProofTest.SymSegAlloca MojoProofTest.SymLoop

/-- `@k`: the entry block `%0` branches to the header `%1`, which counts `%2` from 0 while
`%2 < 2` into the body `%4` (`%5 = %2 + 1` and an `alloca` of an `i32`, back to `%1`), and
otherwise to `%7`, `ret void`; the locals numbered as the parser numbers them (`%2` is local 4,
`%3` local 5, `%5` local 2, `%6` local 7). -/
def kL : Func :=
  { gemv.fn_0 with
    name := "k", params := [], names := #["0", "1", "5", "4", "2", "3", "7", "6"],
    blocks := #[⟨0, #[], .br 1⟩,
      ⟨1, #[{ res := some 4, inst := .phi (.int 64) [(.int 0, 0), (.loc 2, 3)] },
        { res := some 5, inst := .icmp .slt (.int 64) (.loc 4) (.int 2) }],
        .condBr (.loc 5) 3 6⟩,
      ⟨3, #[{ res := some 2, inst := .bin .add { nsw := true } (.int 64) (.loc 4) (.int 1) },
        allocaStmt 7], .br 1⟩,
      ⟨6, #[], .ret none⟩] }

#guard ((prog kL).module.twice).isNone && admitted kL

/-- The summary of `kL`'s block `l` from position `p` with the `alloca` flag (`summarizeAt true`,
the exit from `SState.exitAt`), the default summary when there is none. -/
def sL (l p : Nat) : Summary :=
  (summarizeAt true (prog kL) kL l p fun σ tm => σ.exitAt kL l tm).getD default

/-- The loop: header `%1` at position 1 (after its `phi`), loop path `%1 → %4`, path out
`%1 → %7`. -/
def loopK : LoopSeg :=
  ⟨1, 1, (sL 1 1).obls, sL 1 1, [(3, (sL 3 0).obls, sL 3 0)], [(6, (sL 6 0).obls, sL 6 0)], []⟩

/-- The loop after the entry block `%0`, whose summary is a `br` into the header. -/
def chainK : LoopChain := ⟨0, (sL 0 0).obls, sL 0 0, [], [loopK]⟩

/-- **The loop checker with the flag accepts the loop** (`coversChainsAt true`): the entry block
from position 0, the loop path from the header's position 1 and the path out; the body's summary
has the `alloca`'s effect (an `i32`, one cell of `i64`). Without the flag (`coversChainsWith`)
the checker refuses them. -/
theorem loopK_covers :
    coversChainsAt true false (prog kL) kL [chainK] = true ∧
    (sL 3 0).effs = [.alloca 3 1 1 (some (.int 64 1))] ∧
    coversChainsWith false (prog kL) kL [chainK] = false := by
  decide +kernel

/-- The loop whose body summary drops its `alloca` effect. -/
def dropK : LoopSeg := { loopK with B := [(3, (sL 3 0).obls, { sL 3 0 with effs := [] })] }

/-- **The mutants**: with the flag on, the checker refuses the loop whose body summary drops its
`alloca` effect (`dropK`), and the loop entered at the header's position 0, its `phi`. -/
theorem loopK_mutant :
    coversChainsAt true false (prog kL) kL [{ chainK with loops := [dropK] }] = false ∧
    coversChainsAt true false (prog kL) kL [{ chainK with loops := [{ loopK with p := 0 }] }] =
      false := by
  decide +kernel

/-- The context: `ctx0` with `kL`'s program. -/
def ctxK : Ctx := { ctx0 with prog := prog kL }

/-- The frame at `kL`'s first block, position 0, with no register, product or `alloca` block. -/
def frameK : Frame := ⟨kL, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- The start memory: one launch block at number 1, as the launch allocates it on the empty
memory (`Mem.alloc` at `next`, which becomes 2): global, 4 bytes, live, writable, every thread's,
holding the `i32` 7. The thread's `alloca`s at steps 4 and 9 take the fresh numbers 18 and 83
(`Mem.fresh`: `next` plus `Nat.pair 0 4` and `Nat.pair 0 9`), above it. -/
def memK : Mem := (({} : Mem).alloc (prog kL).layout 1 4 4 true false .all 1 1 (leBytes 4 7)).1

/-- The load of the output block's `i32` (block 1, offset 0, address space 1, alignment 4) by
thread 0 of block 0, as an option. -/
def outK (me : Mem) : Option Val :=
  (me.load (prog kL).layout ⟨0, 0⟩ 1 (.int 32) ⟨1, 0⟩ (some 4)).toOption

/-- A memory with blocks 18 and 83 live, of 4 bytes each: the memory the loop's `ret` runs on
from `memK`, after the two rounds' `alloca`s and before the cleanup sets their blocks dead. -/
def allocated (me : Mem) : Prop :=
  (me.blocks 18).map (fun b => (b.live, b.size)) = some (true, 4) ∧
    (me.blocks 83).map (fun b => (b.live, b.size)) = some (true, 4)

/-- Whether a memory is `allocated`, decided by evaluating both blocks' entries. -/
instance : DecidablePred allocated := fun me => by unfold allocated; infer_instance

/-- The run of the loop from `frameK`'s entry valuation on `memK` to `ret` (`RetLsWith false`), by
`ChainWith.of_rounds` (the invariant: the iterates of the header's entry valuation) with trip
count 2: the premises of the entry, of each round and of the path out are evaluated by the
kernel, and so is the memory the `ret` runs on (`run_ok`): `allocated`, with the output's word
7. -/
theorem loopK_retLs : RetLsWith false (fun me => allocated me ∧ outK me = some (.bits 32 7))
    [loopK] (Valuation.entry ctxK 0 memK frameK) 0 (sL 0 0).obls (sL 0 0) [] :=
  ChainWith.of_rounds (contract := false) (by rfl) 2 (by decide +kernel)
    (ChainWith.last (by refine ⟨?_, ?_, run_ok ?_⟩ <;> decide +kernel))

/-- **The thread through the loop with an `alloca` runs to its end, and the memory it leaves**
(`Runs.of_chainsDead` with the flag on, `loopK_covers` and `loopK_retLs`): for the context
`ctxK`, the thread whose one frame is `frameK` and the start memory `memK`, the thread runs to
its end on a memory `m'` in which the rounds' blocks 18 and 83 are dead blocks of 4 bytes, and
the output block's load is the start memory's, the `i32` 7. -/
theorem loopK_run : ∃ m', Runs ctxK ⟨[frameK], 0⟩ memK m' ∧
    (m'.blocks 18).map (fun b => (b.live, b.size)) = some (false, 4) ∧
    (m'.blocks 83).map (fun b => (b.live, b.size)) = some (false, 4) ∧
    outK m' = outK memK ∧ outK memK = some (.bits 32 7) := by
  obtain ⟨me, m', hr, ⟨h18, h83⟩, hR, hb⟩ := Runs.of_chainsDead (alloca := true)
    (P := prog kL) (c := ctxK) (t := ⟨[frameK], 0⟩) (f := frameK) (Q := allocated)
    (R := fun me => outK me = some (.bits 32 7)) rfl loopK_covers.1 rfl rfl rfl rfl rfl
    (fun m₁ m₂ h _ _ e => by
      rw [outK, ← Mem.load_of_block (p := ⟨1, 0⟩) (h 1 rfl)]
      exact e)
    ⟨chainK, List.mem_singleton.2 rfl, loopK_retLs⟩
  have dead : ∀ b, memK.blocks b = none →
      (me.blocks b).map (fun x => (x.live, x.size)) = some (true, 4) →
      (m'.blocks b).map (fun x => (x.live, x.size)) = some (false, 4) := by
    intro b h0 h4
    rw [hb b, h0]
    cases e : me.blocks b <;> simp_all
  have h7 : outK memK = some (.bits 32 7) := by decide +kernel
  exact ⟨m', hr, dead 18 rfl h18, dead 83 rfl h83, hR.trans h7.symm, h7⟩

/-- The start memory with a block at 18, the number the first round's `alloca` takes. -/
def memX : Mem :=
  memK.set 18
    { space := 5, size := 4, live := true, readOnly := false, owner := .thread 0,
      bytes := fun _ => .undef, addr := 0, gaddr := 0 }

/-- **The mutant memory is refused**: on `memX`, whose number 18 has a block, the premises of
`ChainWith.of_rounds` fail at trip count 2: the first round's `alloca` faults ("alloca number in
use"), so its effects do not run (the `.mem` obligation). The kernel decides it. -/
theorem loopK_inUse : ¬ (EdgeWith false loopK.h loopK.p (Valuation.entry ctxK 0 memX frameK) 0
    (sL 0 0).obls (sL 0 0) [] ∧ ∀ i < 2, RoundWith false loopK.h loopK.p loopK.dh loopK.H loopK.B
      ((Valuation.roundWith false loopK.h loopK.H loopK.B)^[i]
        (Valuation.roundWith false 0 (sL 0 0) [] (Valuation.entry ctxK 0 memX frameK)))) := by
  decide +kernel

end MojoProofTest.SymLoopAlloca
