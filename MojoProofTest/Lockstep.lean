import MojoProof.Sem.Lockstep
import MojoProofTest.Determinism

/-!
# Instance and twin of `Grid.Lockstep` (T3a)

The instance of `Grid.payload_run`, with `Grid.Lockstep.eq`: the run of `done2` (MojoProofTest/
Determinism.lean) moves to `start2`'s grid under its own contexts, to `done2` itself, which makes
`start2`'s grid sound for the bytes of 7 at block 2 (`eq_run`). The instance of T3b's lockstep
relation is `lockstep_inst` (`Grid.skel_lockstep`), and the instance of two complete runs that
differ in their payloads is `run_inst` (`Grid.skel_run`), both in MojoProofTest/SkelStep.lean.

The twin of the field `trace`: the relation between `doneP` (racy) and `done2`, in both of which
every thread has returned, has every other field of `Grid.Lockstep` (neither grid steps, waits or
has a race enabled), but `doneP` is bad and `done2` is not (`lockstep_twin`).

Statements about these launches and grids.
-/

namespace MojoProofTest.Lockstep

open MojoProof.Sem MojoProofTest.Confluence MojoProofTest.Bad MojoProofTest.Determinism

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The instance of `Grid.payload_run`, with `Grid.Lockstep.eq`. -/
theorem eq_run : ∃ z, Path (Grid.Step two c2) 6 run2.1 z ∧ z.Done ∧ ¬ z.Bad two c2 ∧
    done2 = z ∧ Grid.Sound two c2 run2.1 obs2 (· = leBytes 4 7) := by
  obtain ⟨z, p, hz, hb, e, hs⟩ := Grid.payload_run start2_eq (fun _ _ _ _ _ h => by cases h)
    (Grid.Lockstep.eq two c2) rfl run2_path done2_good.1 done2_good.2.1
  refine ⟨z, p, hz, hb, e, hs (fun m m' h => by simp only [obs2, h]) ?_ rfl⟩
  rw [← e]
  exact done2_good.2.2

/-- In a grid in which every thread has returned, no thread steps and no collective call
completes. -/
theorem done_none {L : Launch} {c : Nat → Ctx} {g : Grid} (h : g.Done) (n : Nat) :
    g.advance c n = .ok none ∧ g.fire L c n = .ok none := by
  rcases h.get n with hn | hn <;> simp [Grid.advance, Grid.fire, hn, pure, Except.pure]

/-- The twin of `Grid.Lockstep`'s field `trace`: the relation between `doneP` and `done2` agrees
on every step and collective call, on `Done` and on enabled races, but the traces differ, and
`doneP` is bad while `done2` is not. -/
theorem lockstep_twin :
    let S : Grid → Grid → Prop := fun x y => x = doneP ∧ y = done2
    (∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.advance cP n) (g₂.advance c2 n)) ∧
    (∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.fire two cP n) (g₂.fire two c2 n)) ∧
    (∀ {g₁ g₂}, S g₁ g₂ → (g₁.Done ↔ g₂.Done)) ∧
    (∀ {g₁ g₂}, S g₁ g₂ → (g₁.RaceEnabled cP ↔ g₂.RaceEnabled c2)) ∧
    S doneP done2 ∧ doneP.mem.trace ≠ done2.mem.trace ∧ doneP.Bad two cP ∧
      ¬ done2.Bad two c2 := by
  intro S
  have hP : doneP.Done := racy_twin.2.1
  have h2 : done2.Done := done2_good.1
  refine ⟨?_, ?_, ?_, ?_, ⟨rfl, rfl⟩, fun h => ?_, racy_twin.2.2.2.1, done2_good.2.1⟩
  · rintro _ _ ⟨rfl, rfl⟩ n
    rw [(done_none (L := two) hP n).1, (done_none (L := two) h2 n).1]
    trivial
  · rintro _ _ ⟨rfl, rfl⟩ n
    rw [(done_none (c := cP) hP n).2, (done_none (c := c2) h2 n).2]
    trivial
  · rintro _ _ ⟨rfl, rfl⟩
    exact iff_of_true hP h2
  · rintro _ _ ⟨rfl, rfl⟩
    exact iff_of_false hP.not_raceEnabled h2.not_raceEnabled
  · have : racy doneP.mem.trace = racy done2.mem.trace := by rw [h]
    rw [show racy doneP.mem.trace = true from rfl, show racy done2.mem.trace = false from rfl] at this
    cases this

end MojoProofTest.Lockstep
