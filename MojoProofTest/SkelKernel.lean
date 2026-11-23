import MojoProofTest.PayloadRun

/-!
# Instances and twin of `Kernel.skel_sound` and `Kernel.Sound.of_blocks`

On the kernel `kF` of MojoProofTest/PayloadRun.lean (`load float`, `fadd`, `store` through its
pointer argument, one thread, block 1 payload under `labB`):

* `kernel_six_inst`, the instance of `Kernel.skel_sound` at one address choice: for every word `w`
  in block 1, `kF` on `memF w` is sound at address choice 0 and every oracle for the blocks and
  the trivial relation, from the one run on `memF w1` (1.0) with oracle 0 (`runF_run`).
* `kernel_sum_inst`, the instance of `Kernel.Sound.of_blocks`: at `memF w1`, address choice 0 and
  oracle 0, `kF` is sound for bytes 0 to 3 of block 1 (`word1`) and the word of 2.0, from the
  final grid of that run.
* `kernel_six_twin`, of the premise `Mem.SkelEq`: the read-only `memF w1 true` is not related to
  `memF w1`, and `kF` on it is not sound at address choice 0 for the blocks and the trivial
  relation, as no grid reachable from its start has every thread returned (`running_every`).

One kernel, launch and address choice; every input word and oracle for `kernel_six_inst`.
-/

namespace MojoProofTest.SkelKernel

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.PayloadRun
open MojoProofTest.SkelStep (labB)
open MojoProofTest.ScheduleOwned (every_sound)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- **The instance of `Kernel.skel_sound`** at one address choice: under `labB` with block 1
payload, for every word `w` in block 1, the kernel `kF` launched on one thread on `memF w` with a
pointer to block 1 is sound at address choice 0 and every oracle, for the blocks and the trivial
relation. The premises: `memF_bytesIn`, `okF`, the lookup by `rfl`, and at address choice 0 the
start `startF_eq` with oracle 0, `memF_ok` and the run `runF_run` on `memF w1`; `memF_skel`
relates `memF w1` to `memF w`. -/
theorem kernel_six_inst (w : BitVec 32) :
    Kernel.Sound progF kF .one [.ptr ⟨1, 0⟩] (memF w) (fun ch _ => ch = fun _ => 0)
      (fun m => some m.blocks) (fun _ => True) :=
  Kernel.skel_sound (lab := labB) (memF_bytesIn w1 false) okF rfl
    (fun ch h => by
      subst h
      exact ⟨fun _ _ => 0, (runF w1).1, (runF w1).2, doneF w1, startF_eq w1 false, memF_ok,
        Path.exists_iff.1 ⟨_, runF_run.1⟩, runF_run.2.1, runF_run.2.2.1⟩)
    (memF_skel w1 w).1

/-- **The instance of `Kernel.Sound.of_blocks`**: at `memF w1`, address choice 0 and oracle 0,
the kernel `kF` is sound for bytes 0 to 3 of block 1 (`word1`, which reads only the blocks) and
the word of 2.0, from `kernel_six_inst` and the final grid `doneF w1` of `runF_run`. -/
theorem kernel_sum_inst :
    Kernel.Sound progF kF .one [.ptr ⟨1, 0⟩] (memF w1)
      (fun ch o => ch = (fun _ => 0) ∧ o = fun _ _ => 0) word1
      (· = [.byte 0, .byte 0, .byte 0, .byte 0x40]) := by
  refine Kernel.Sound.of_blocks (fun ch o ha => kernel_six_inst w1 ch o ha.1)
    (fun m m' h => by simp only [word1, h]) ?_
  rintro _ _ g c ⟨rfl, rfl⟩ e
  rw [startF_eq] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e).symm
  exact ⟨doneF w1, Path.exists_iff.1 ⟨_, runF_run.1⟩, runF_run.2.1, _, runF_run.2.2.2, rfl⟩

/-- **The twin of `Kernel.skel_sound`'s premise `Mem.SkelEq`**: with block 1 payload, the
read-only `memF w1 true` is not related to `memF w1` (`run_twin`), and the kernel `kF` on it is
not sound at address choice 0 for the blocks and the trivial relation: a sound kernel reaches a
grid in which every thread has returned (`Kernel.Sound.exists_obs`), and no grid reachable from
the start's grid at oracle 0 is one (`reachF`, `running_every`), as the store to block 1
faults. -/
theorem kernel_six_twin :
    ¬ (memF w1).SkelEq (· = 1) (memF w1 true) ∧
      ¬ Kernel.Sound progF kF .one [.ptr ⟨1, 0⟩] (memF w1 true) (fun ch _ => ch = fun _ => 0)
        (fun m => some m.blocks) (fun _ => True) := by
  refine ⟨run_twin.1, fun hk => ?_⟩
  obtain ⟨_, ⟨g, c, z, e, hz, hd, -⟩, -⟩ := hk.exists_obs (ω := fun _ _ => 0) rfl
  rw [startF_eq] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e).symm
  have h : running z = true := by
    rcases reachF true hz with rfl | hz'
    · decide +kernel
    · exact every_sound hz' running_every
  -- `running z` is the negation of `z.Done`'s test, by unfolding.
  have hd' : running z = false := by
    have e := congrArg (!·) hd
    exact e
  cases h.symm.trans hd'

end MojoProofTest.SkelKernel
