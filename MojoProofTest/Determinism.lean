import MojoProof.Sem.Determinism
import MojoProofTest.Bad

/-!
# Instances and twins of `Grid.confluent` and `Grid.start_sound` (T2)

The instance of `Grid.confluent` and `Grid.start_sound`: the launch `start2` of
MojoProofTest/Confluence.lean, two threads each at `%0 = alloca i32`, `store i32 7, ptr %0`,
`ret void`, on the empty memory. Its steps are confluent (`confluent2`). Thread 0's three steps
and then thread 1's give a grid in which every thread has returned, that is not bad, and whose
block 2, thread 0's `alloca`, holds the four bytes of 7 (`done2_good`), so the start's grid is
sound for the observation of those bytes (`sound2`), and every grid in which every thread has
returned that is reachable from it observes them (`final2`).

The twin of `¬ z.Bad`: in the launch `startP` of MojoProofTest/Bad.lean both threads store 7 to
bytes 0 to 3 of block 1; after thread 0's store and return and thread 1's, every thread has
returned and block 1 holds the bytes of 7, but the trace is racy, so the grid is bad and the
start's grid is sound for no observation (`racy_twin`). The twin of the premise that the
observation reads only the blocks: the newest event of the trace, which another memory with the
same blocks does not have, is thread 1's store after `done2`'s run and thread 0's after a run
with thread 1's store first (`done2'`), so `start2`'s grid is sound for no relation on it
(`trace_twin`).

The instance of `Grid.start_refute`: as `doneP` is bad, every grid reachable from `startP`'s
without a step is bad (`refuteP`). The twin of its premise that some reachable grid is bad: on
`start2`, `done2` has no step and is not bad (`refute_twin`).
-/

namespace MojoProofTest.Determinism

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Confluence MojoProofTest.Bad

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- `g` after a step of thread `n`, or `g` if it takes none. -/
def adv (c : Nat → Ctx) (g : Grid) (n : Nat) : Grid :=
  match g.advance c n with
  | .ok (some g') => g'
  | _ => g

/-- `g` after the steps of threads `ns`, first to last. -/
def advs (c : Nat → Ctx) (g : Grid) (ns : List Nat) : Grid := ns.foldl (adv c) g

/-- Every step of threads `ns` from `g`, first to last, succeeds. -/
def oks (c : Nat → Ctx) : Grid → List Nat → Bool
  | _, [] => true
  | g, n :: ns =>
    match g.advance c n with
    | .ok (some g') => oks c g' ns
    | _ => false

/-- For every launch, contexts and grid: if every step of threads `ns` succeeds, they and then a
run of `k` steps from `advs c g ns` to `z` are a run to `z`. -/
theorem path_advs {L : Launch} {c : Nat → Ctx} {k : Nat} {z : Grid} :
    ∀ (g : Grid) (ns : List Nat), oks c g ns = true → Path (Grid.Step L c) k (advs c g ns) z →
      Path (Grid.Step L c) (k + ns.length) g z
  | _, [], _, p => p
  | g, n :: ns, h, p => by
    unfold oks at h
    split at h
    · rename_i g' hg
      have e : adv c g n = g' := by simp only [adv, hg]
      have p' : Path (Grid.Step L c) k (advs c g' ns) z := by
        rw [← e]
        exact p
      exact .cons ⟨n, .inl hg⟩ (path_advs g' ns h p')
    · cases h

/-- `start2`'s grid after thread 0's three steps, then thread 1's. -/
def done2 : Grid := advs c2 run2.1 [0, 0, 0, 1, 1, 1]

/-- `start2`'s grid after thread 1's `alloca` and store, thread 0's three steps and thread 1's
return. -/
def done2' : Grid := advs c2 run2.1 [1, 1, 0, 0, 0, 1]

/-- The four bytes at offset 0 of block 2. -/
def obs2 (m : Mem) : Option (List MemByte) := (m.blocks 2).map (·.read 0 4)

/-- The instance of `Grid.confluent`: `start2`'s steps are confluent. -/
theorem confluent2 :
    Confluent (fun x y : {g // Relation.ReflTransGen (Grid.Step two c2) run2.1 g} =>
      Grid.Step two c2 x.1 y.1) (fun x y => x.1.Same y.1) (fun x => x.1.Bad two c2) :=
  Grid.confluent start2_eq fun _ _ _ _ _ h => by cases h

/-- The run of `done2`. -/
theorem run2_path : Path (Grid.Step two c2) 6 run2.1 done2 :=
  path_advs run2.1 [0, 0, 0, 1, 1, 1] rfl (.nil _)

/-- In `done2` every thread has returned, it is not bad, and block 2 holds the bytes of 7. -/
theorem done2_good : done2.Done ∧ ¬ done2.Bad two c2 ∧ obs2 done2.mem = some (leBytes 4 7) := by
  have hd : done2.Done := rfl
  refine ⟨hd, fun hb => ?_, rfl⟩
  rw [hd.bad_iff, show racy done2.mem.trace = false from rfl,
    show kept done2.mem.trace = true from rfl] at hb
  simp at hb

/-- The instance of `Grid.start_sound`. -/
theorem sound2 : Grid.Sound two c2 run2.1 obs2 (· = leBytes 4 7) :=
  Grid.start_sound start2_eq (fun _ _ _ _ _ h => by cases h)
    (fun m m' h => by simp only [obs2, h]) run2_path done2_good.1 done2_good.2.1 done2_good.2.2 rfl

/-- So every grid reachable from `start2`'s in which every thread has returned observes the bytes
of 7 (`Grid.Sound.result`). -/
theorem final2 : ∀ g, Relation.ReflTransGen (Grid.Step two c2) run2.1 g → g.Done →
    obs2 g.mem = some (leBytes 4 7) := by
  obtain ⟨y, hR, -, hy⟩ := sound2.result
  rw [← hR]
  exact hy

/-- `startP`'s grid after thread 0's store and return, then thread 1's. -/
def doneP : Grid := advs cP runP.1 [0, 0, 1, 1]

/-- The twin of `¬ z.Bad`: `doneP`, reachable from `startP`'s grid, has every thread returned and
block 1 holding the bytes of 7, but its trace is racy, so it is bad and the start's grid is sound
for no observation. -/
theorem racy_twin : Relation.ReflTransGen (Grid.Step two cP) runP.1 doneP ∧ doneP.Done ∧
    (doneP.mem.blocks 1).map (·.read 0 4) = some (leBytes 4 7) ∧ doneP.Bad two cP ∧
    ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop), ¬ Grid.Sound two cP runP.1 obs R := by
  have hr : Relation.ReflTransGen (Grid.Step two cP) runP.1 doneP :=
    Path.exists_iff.1 ⟨_, path_advs runP.1 [0, 0, 1, 1] rfl (.nil _)⟩
  have ht : racy doneP.mem.trace = true := rfl
  refine ⟨hr, rfl, rfl, .inr (.inl ht), fun _ _ hs => ?_⟩
  rw [hs.raceFree _ hr] at ht
  cases ht

/-- The instance of `Grid.start_refute`: `doneP` is bad, so every grid reachable from `startP`'s
without a step is bad. -/
theorem refuteP : ∀ z, Relation.ReflTransGen (Grid.Step two cP) runP.1 z →
    (∀ g, ¬ Grid.Step two cP z g) → z.Bad two cP :=
  fun _ hz hn =>
    Grid.start_refute startP_eq (Closed.mem_bytesIn _) racy_twin.1 racy_twin.2.2.2.1 hz hn

/-- The twin of its premise that some reachable grid is bad: `done2`, reachable from `start2`'s,
has no step and is not bad. -/
theorem refute_twin : Relation.ReflTransGen (Grid.Step two c2) run2.1 done2 ∧
    (∀ g, ¬ Grid.Step two c2 done2 g) ∧ ¬ done2.Bad two c2 :=
  ⟨Path.exists_iff.1 ⟨_, run2_path⟩, fun _ => Grid.Done.final done2_good.1, done2_good.2.1⟩

/-- The newest event of the trace. -/
def newest (m : Mem) : Option Event := m.trace.head?

/-- The twin of the premise that the observation reads only the blocks: `newest` does not, the
run of `done2` satisfies the other premises of `Grid.start_sound` for it, and `start2`'s grid is
sound for no relation on it, since `done2` and `done2'` observe thread 1's store and thread 0's. -/
theorem trace_twin : ¬ (∀ m m' : Mem, m.blocks = m'.blocks → newest m = newest m') ∧
    newest done2.mem = some (.access ⟨⟨1, 0⟩, ⟨4, 0⟩, 4, true, none, false⟩) ∧
    newest done2'.mem = some (.access ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, true, none, false⟩) ∧
    ∀ R : Event → Prop, ¬ Grid.Sound two c2 run2.1 newest R := by
  have hr' : Relation.ReflTransGen (Grid.Step two c2) run2.1 done2' :=
    Path.exists_iff.1 ⟨_, path_advs run2.1 [1, 1, 0, 0, 0, 1] rfl (.nil _)⟩
  have h₁ : newest done2.mem = some (.access ⟨⟨1, 0⟩, ⟨4, 0⟩, 4, true, none, false⟩) := rfl
  have h₂ : newest done2'.mem = some (.access ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, true, none, false⟩) := rfl
  refine ⟨fun h => ?_, h₁, h₂, fun _ hs => ?_⟩
  · have := h { trace := [.barrier 0] } {} rfl
    simp [newest] at this
  · have := hs.determinate _ _ (Path.exists_iff.1 ⟨_, run2_path⟩) hr' rfl rfl
    rw [h₁, h₂] at this
    simp at this

end MojoProofTest.Determinism
