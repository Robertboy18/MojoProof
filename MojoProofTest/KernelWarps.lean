import MojoProofTest.SymCanon
import MojoProof.Sym.KernelWarps

/-!
# The kernel theorem from the warps' lanes' runs, on a kernel that branches around a shuffle

A test of `Kernel.sound_of_warps` and `WarpSegs` (MojoProof/Sym/KernelWarps.lean) on the
hand-built kernel `kern` of MojoProofTest/SymCanon.lean (a butterfly shuffle at offset 16 in the
warps whose first thread has bit 5 clear), its shuffle declared without result attributes
(`prog []`), launched on one block of 40 threads (`SymChain.L 40`: warp 0 of 32 lanes shuffles,
warp 32 of 8 lanes skips the shuffle), on the empty memory, at the one admitted address choice
and oracle, 0 (`adm0`).

* `seg0`, `seg32`: each warp's `WarpSegs` from the start's threads on the start's memory: the
  lanes' runs by the checkers (SymCanon's `lane` through `RunsVia.of_block`, `skipLane` through
  `RunsVia.of_runs`), warp 0's waits passing `Piece.Wait.shflOk` and the lanes' memories
  evaluated by the kernel, the deliveries kept by `Program.shfl_nil`;
* `sound40`: the kernel is sound (`Kernel.Sound`) at that launch and admission, with the
  observation that is always `()`, by `Kernel.sound_of_warps` with the memory unchanged after each
  warp.
* The twin (an `example`): with lane operand 8 in place of the call's 16, lane 0's wait of warp 0
  fails `Piece.Wait.shflOk`, so `seg0`'s premise is refused there.

Statements about this kernel at this launch, memory and admission, not about every kernel.
-/

namespace MojoProofTest.KernelWarps

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.SymCanon
open MojoProofTest.SymChain (L)
open MojoProofTest.Atomics (b)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The one admitted address choice and oracle: both 0, as `SymCanon.start` launches. -/
def adm0 (ch : Nat → Nat) (oracle : Nat → Nat → Nat) : Prop :=
  ch = (fun _ => 0) ∧ oracle = fun _ _ => 0

/-- The start at block size 40 succeeds. -/
theorem starts : (start [] 40).toBool = true := by decide +kernel

/-- **Warp 0 at block size 40 has `WarpSegs`**: its 32 lanes run through their one shuffle
(`ws [] 40 0`) from the start's threads on the start's memory and end on it, by SymCanon's
`lane`; the waits pass `Piece.Wait.shflOk` and the memories are the start's, by the kernel. -/
theorem seg0 : WarpSegs (prog []) kern (L 40) (c [] 40) 0 (Grid.thread (g0 [] 40))
    (g0 [] 40).mem (· = (g0 [] 40).mem) := by
  have hl : ∀ j ∈ warpLanes (L 40) 0, j < 32 := fun j hj =>
    List.mem_range.1 ((show warpLanes (L 40) 0 = List.range 32 by decide +kernel) ▸ hj)
  have hc : ∀ j < 32, 0 + j < (g0 [] 40).threads.size ∧ Edge [] 40 (0 + j) ∧
      Piece.fires kern 4 (retB false (endPs [])) (shP []).1 0 [dl [] 40 0 j] (V1 [] 40 (0 + j)) =
        true ∧
      (ws [] 40 0 j).length = 1 ∧
      Piece.Wait.shflOk (warpLanes (L 40) 0) (fun _ => .bfly) (fun _ => 0) (fun _ => 16)
        (fun _ => 31) (fun _ j => b (0 + j)) ⟨0, .barrier, [], {}, (none, {})⟩ 1 j (ws [] 40 0 j) =
        true := by decide +kernel
  have hm : ∀ j < 32, ((wt [] 40 0 0 j).mem, (wt [] 40 0 0 j).dlv.2,
      endMem [] 40 (0 + j) [dl [] 40 0 j]) = ((g0 [] 40).mem, (g0 [] 40).mem, (g0 [] 40).mem) :=
    fun j hj => by interval_cases j <;> kernel_rfl
  refine ⟨1, fun _ => 4, fun _ => .bfly, fun _ => 0, fun _ => 16, fun _ => 31,
    fun _ j => b (0 + j), ⟨0, .barrier, [], {}, (none, {})⟩, ws [] 40 0,
    fun _ _ => (g0 [] 40).mem, rfl, rfl, fun j hj => ?_, fun j hj => (hc j (hl j hj)).2.2.2.2,
    fun _ _ _ _ => Program.shfl_nil (by decide +kernel), fun i hi j hj => ?_, fun _ _ => rfl⟩
  · obtain ⟨hn, hE, hF, hlen, -⟩ := hc j (hl j hj)
    exact RunsVia.of_block (lane covers.1 starts hn hE hF) hlen (fun _ _ => rfl)
      fun m h => h.trans (congrArg (·.2.2) (hm j (hl j hj)))
  · obtain rfl : i = 0 := by omega
    have h := hm j (hl j hj)
    simp only [Prod.mk.injEq] at h
    exact ⟨h.1, h.2.1⟩

/-- **Warp 32 at block size 40 has `WarpSegs`**: its 8 lanes skip the shuffle and return from the
start's threads to the start's memory (no shuffle), by SymCanon's `skipLane`, their paths'
premises and memories evaluated by the kernel. -/
theorem seg32 : WarpSegs (prog []) kern (L 40) (c [] 40) 32 (Grid.thread (g0 [] 40))
    (g0 [] 40).mem (· = (g0 [] 40).mem) := by
  have hl : ∀ j ∈ warpLanes (L 40) 32, j < 8 := fun j hj =>
    List.mem_range.1 ((show warpLanes (L 40) 32 = List.range 8 by decide +kernel) ▸ hj)
  have hc : ∀ j < 8, 32 + j < (g0 [] 40).threads.size ∧
      retB false (skipPs []) (V0 [] 40 (32 + j)) = true := by decide +kernel
  have he : ∀ j < 8, (V0 [] 40 (32 + j)).retMem false [] (skipPs []) = (g0 [] 40).mem :=
    fun j hj => by interval_cases j <;> kernel_rfl
  refine ⟨0, fun _ => 4, fun _ => .bfly, fun _ => 0, fun _ => 16, fun _ => 31,
    fun _ j => b (32 + j), ⟨0, .barrier, [], {}, (none, {})⟩, fun _ => [],
    fun _ _ => (g0 [] 40).mem, rfl, rfl, fun j hj => ?_, fun _ _ => rfl,
    fun _ h => absurd h (by omega), fun _ h => absurd h (by omega), fun _ h => absurd h (by omega)⟩
  exact RunsVia.of_runs (skipLane covers.1 starts (hc j (hl j hj)).1 (hc j (hl j hj)).2)
    (he j (hl j hj))

/-- **The kernel is sound at one block of 40 threads** (`Kernel.Sound`), on the empty memory, at
the address choice and oracle 0, with the observation that is always `()`: by
`Kernel.sound_of_warps`, the warps 0 and 32 by `seg0` and `seg32` with the memory the start's
after each, the final trace's checks by the kernel. -/
theorem sound40 :
    Kernel.Sound (prog []) kern (L 40) [] {} adm0 (fun _ => some ()) fun _ => True := by
  have hs := start_eq starts
  refine Kernel.sound_of_warps (fun _ _ _ _ _ hc => by cases hc) (by decide)
    (fun ch oracle ⟨hch, ho⟩ => ⟨_, _, by subst hch ho; exact hs⟩) (fun _ _ _ => rfl)
    (fun ch oracle g c' ⟨hch, ho⟩ h => ?_)
  subst hch ho
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj (h.symm.trans hs))
  have hw : warps (L 40) (g0 [] 40).threads.size = [0, 32] := by decide +kernel
  rw [hw]
  refine ⟨fun _ m => m = (g0 [] 40).mem, rfl, fun i hi m₀ hm₀ => ?_, fun m' hm' => ?_⟩
  · subst hm₀
    match i, hi with
    | 0, _ => exact seg0
    | 1, _ => exact seg32
    | n + 2, h => simp only [List.length_cons, List.length_nil] at h; omega
  · subst hm'
    exact ⟨fun _ _ => by decide +kernel, by decide +kernel, _, rfl, trivial⟩

-- The twin: with lane operand 8 in place of 16, lane 0's wait of warp 0 fails
-- `Piece.Wait.shflOk` (its call's offset is 16, and its delivery is lane 16's offer), so `seg0`'s
-- premise is refused at that offset.
example : Piece.Wait.shflOk (warpLanes (L 40) 0) (fun _ => .bfly) (fun _ => 0) (fun _ => 8)
    (fun _ => 31) (fun _ j => b (0 + j)) ⟨0, .barrier, [], {}, (none, {})⟩ 1 0 (ws [] 40 0 0) =
    false := by decide +kernel

end MojoProofTest.KernelWarps
