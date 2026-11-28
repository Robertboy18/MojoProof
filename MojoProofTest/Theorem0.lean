import MojoProof.Sym.SigKernel
import MojoProofTest.Determinism

/-!
# `Grid.start_sound` from Theorem 0 at `sig`

For every program, kernel, launch, arguments, memory every pointer byte of whose blocks names a
number below `next` or with a block (`m.BytesIn m.Known`, the good start of `sig`), address
choice and oracle: `Grid.start_sound`'s statement, with its binders, premises and conclusion,
follows from Theorem 0 (`GPUProof.Sound.of_one_run`) at `sig` with the instance `OneRun sig`
(`sound_sig`, MojoProof/Sym/SigKernel.lean, with `sig_step_iff` and `sig_obs`), carried back to
the grid field by field (`Grid.Sound.of_sig`, in the same module): the faults, the races, the
frozen reads, progress and termination by `Grid.Sound.of_clean` (the reachable states by
`sig_reach_iff`, the steps by `sig_step_iff`), and the observations by `sig_obs`. The proof uses
no `Grid.start_sound`, `Grid.sound_of_one_run` or `Grid.confluent`; `OneRun sig` reaches
`Grid.confluent` through `Grid.start_oneRun` only.

The example applies on memories that are not closed (`Mem.Closed`): at `memAt 2 5 4` (`next = 2`,
no block 0, a block 5 of 4 data bytes) with no arguments, which is `sig.Closed` but not closed,
the launch of `ret void` on one thread starts, its one step gives a grid in which every thread
has returned and that is not bad, and the example's proof (`sound_sig`, `Grid.Sound.of_sig`)
makes the start's grid sound (`applies_one`); the same at `memAt 3 7 8` (`next = 3`, a block 7 of
8 data bytes) on 2 blocks of 3 threads (`applies_six`). Tests of these two examples, at address
choice and oracle 0.
-/

namespace MojoProofTest.Theorem0

open MojoProof.Sem MojoProof.LLVM MojoProof Relation
open GPUProof (Path)
open MojoProofTest.Determinism (advs oks path_advs)

/-- `Grid.start_sound`'s statement (at `m.BytesIn m.Known`, `sig.Closed`), from Theorem 0 at
`sig`, for every program, kernel, launch, arguments, memory every pointer byte of whose blocks
names a number below `next` or with a block, address choice, oracle and observation that reads
only the blocks. -/
example {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {n : Nat} {z : Grid} (run : Path (Grid.Step L c) n g₀ z) (hz : GPUProof.Done sig (z, L, c))
    (hb : ¬ GPUProof.Bad sig (z, L, c))
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  Grid.Sound.of_sig hO (sound_sig h hm hO run hz hb hy hR)

/-! ### The example at two memories that are not closed -/

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- A live block of `n` data bytes 0 in space 1 that every thread may access. -/
def scalars (n : Nat) : Sem.Block :=
  { space := 1, size := n, live := true, readOnly := false, owner := .all,
    bytes := fun _ => .byte 0, addr := 0, gaddr := 0 }

/-- The memory with `next = k` and one block, `scalars n` at number `b`. -/
def memAt (k b n : Nat) : Mem :=
  { blocks := fun c => if c = b then some (scalars n) else none, next := k }

/-- `memAt k b n` has no pointer byte, for every `k`, `b` and `n`: it is `sig.Closed`. -/
theorem memAt_bytesIn (k b n : Nat) : (memAt k b n).BytesIn (memAt k b n).Known :=
  fun c x i p j hc _ hp => by
    simp only [memAt] at hc
    split at hc
    · cases hc
      cases hp
    · cases hc

/-- `memAt k b n` is not closed (`Mem.Closed`) for any arguments when its block is from `next`
on, for every `k ≤ b` and `n`. -/
theorem memAt_not_closed {k b n : Nat} (vs : List Val) (h : k ≤ b) : ¬ (memAt k b n).Closed vs :=
  fun hc => by simpa [memAt] using hc.above b h

/-- The grid and contexts of the start of `ret void` on launch `L` from memory `m` with no
arguments, at address choice and oracle 0 (no threads, and every context at `retFn`'s program,
if it fails). -/
def startRet (L : Launch) (m : Mem) : Grid × (Nat → Ctx) :=
  match Grid.start (Program.ofFunc retFn) retFn L [] m (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], m⟩, fun _ => ⟨Program.ofFunc retFn, fun _ => none, ⟨fun _ _ => 0, 0⟩,
      ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩)

/-- The grid after one step of each thread of `startRet L m`, by number from 0, for every launch
and memory. -/
def doneRet (L : Launch) (m : Mem) : Grid :=
  advs (startRet L m).2 (startRet L m).1 (List.range (volume L.grid * volume L.block))

/-- The example's premises and conclusion at `ret void` on launch `L` from memory `m` with no
arguments, at address choice and oracle 0, the observation `fun _ => some ()` and the relation
`True`, at a memory that is not closed: `m` is `sig.Closed` and not closed (`Mem.Closed`) for no
arguments; the start succeeds, at `startRet L m`; one step of each thread is a run to
`doneRet L m`, in which every thread has returned and which is not bad; and the start's grid is
sound (`Grid.Sound`). -/
def Applies (L : Launch) (m : Mem) : Prop :=
  m.BytesIn m.Known ∧ ¬ m.Closed [] ∧
    Grid.start (Program.ofFunc retFn) retFn L [] m (fun _ => 0) (fun _ _ => 0) =
      .ok (startRet L m) ∧
    Path (Grid.Step L (startRet L m).2) (volume L.grid * volume L.block) (startRet L m).1
      (doneRet L m) ∧
    GPUProof.Done sig (doneRet L m, L, (startRet L m).2) ∧
    ¬ GPUProof.Bad sig (doneRet L m, L, (startRet L m).2) ∧
    Grid.Sound L (startRet L m).2 (startRet L m).1 (fun _ => some ()) (fun _ => True)

/-- `Applies L m` from evaluations, for every launch `L` and memory `m` that is `sig.Closed` and
not closed for no arguments: the start succeeds at `startRet L m`, every thread's step succeeds
(`oks`), every thread of `doneRet L m` has returned (so it is done, `Grid.done_of_all`), and its
trace is not racy and keeps the promise of `!invariant.load`; the soundness is the example's
proof (`sound_sig`, `Grid.Sound.of_sig`). -/
theorem applies {L : Launch} {m : Mem} (hm : m.BytesIn m.Known) (hn : ¬ m.Closed [])
    (h : Grid.start (Program.ofFunc retFn) retFn L [] m (fun _ => 0) (fun _ _ => 0) =
      .ok (startRet L m))
    (hk : oks (startRet L m).2 (startRet L m).1 (List.range (volume L.grid * volume L.block)) =
      true)
    (ha : (doneRet L m).threads.all (· matches .done) = true)
    (hr : GPUProof.racy sig ((doneRet L m).mem.trace.map (Event.toCore L)).reverse = false)
    (hp : GPUProof.kept sig ((doneRet L m).mem.trace.map (Event.toCore L)).reverse = true) :
    Applies L m := by
  have hd : GPUProof.Done sig (doneRet L m, L, (startRet L m).2) := Grid.done_of_all ha
  have run := path_advs (L := L) (k := 0) (z := doneRet L m) _ _ hk (.nil _)
  rw [List.length_range, Nat.zero_add] at run
  have hb : ¬ GPUProof.Bad sig (doneRet L m, L, (startRet L m).2) := fun hb => by
    rw [Grid.Done.bad_iff (Grid.start_reach_size h (Path.exists_iff.1 ⟨_, run⟩)).le hd, hr,
      hp] at hb
    simp at hb
  exact ⟨hm, hn, h, run, hd, hb, Grid.Sound.of_sig (obs := fun _ => some ())
    (R := fun _ => True) (fun _ _ _ => rfl) (sound_sig (obs := fun _ => some ())
      (R := fun _ => True) (y := ()) h hm (fun _ _ _ => rfl) run hd hb rfl trivial)⟩

/-- **The example applies where `Mem.Closed` fails**, a test of one example (evaluated): at
`memAt 2 5 4` (`next = 2`, no block 0, a block 5 of 4 data bytes), on `Launch.one`. -/
theorem applies_one : Applies .one (memAt 2 5 4) :=
  applies (memAt_bytesIn 2 5 4) (memAt_not_closed [] (by decide)) rfl rfl rfl (by decide +kernel)
    (by decide +kernel)

/-- **The example applies where `Mem.Closed` fails, at another memory and size**, a test of one
example (evaluated): at `memAt 3 7 8` (`next = 3`, a block 7 of 8 data bytes), on 2 blocks of 3
threads (`launch2 2 1 3 1`). -/
theorem applies_six : Applies (launch2 2 1 3 1) (memAt 3 7 8) :=
  applies (memAt_bytesIn 3 7 8) (memAt_not_closed [] (by decide)) rfl rfl rfl (by decide +kernel)
    (by decide +kernel)

end MojoProofTest.Theorem0
