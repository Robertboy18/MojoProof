import MojoProofTest.SkelStep
import MojoProofTest.ScheduleOwned

/-!
# Instances of `Grid.skel_run` and `Grid.skel_six` on a kernel that reads and writes the payload

`kF` is `define void @k(ptr %0) { %1 = load float, ptr %0; %2 = fadd float %1, %1;
store float %2, ptr %0; ret void }`. `memF w ro` has one block, block 1, of 4 bytes holding the
word `w` (little-endian), read-only if `ro` (default not). Under `labB` (every register but 0
payload) `progF`, the program of `kF`, passes `Labels.Ok` (`okF`). With address choice and oracle
0, the launch of `kF` on one thread on `memF w1` (`w1` is 1.0) runs in four steps to `doneF w1`,
in which every thread has returned, which is not bad and whose block 1 holds 2.0 (`runF_run`). It
meets `Labels.MemOk` with block 1 payload (`memF_ok`): every grid it reaches holds a pointer into
block 1 in register 0 (`ptr1`, checked by `ScheduleOwned.every` from the grid after the load,
`ptr1_every`), so the store of the payload register 2 writes a payload block.

The instance (`run_inst`): for every memory related to `memF w1` by `Mem.SkelEq` with block 1
payload (`memF w` is, for every `w`, `memF_skel`) and every oracle, the launch of `kF` on it with
address choice 0 starts and runs in four steps to a grid in which every thread has returned, that
is not bad, is related to `doneF w1` by `Grid.SkelRel` and has a block 1 of size 4, and the start's
grid is `Grid.Sound` for the size of block 1 and 4. It covers one example, not all programs: one
kernel, one first memory, address choice 0 and first oracle 0; the second memory and oracle are
arbitrary.

The six-field lemma (`six_inst`, `Grid.skel_six`): for every word `w` in block 1 (every binary32
input) and every oracle, the launch of `kF` on `memF w` with address choice 0 starts, and its grid
is `Grid.Sound` for the blocks and the trivial relation (safe, race free, keeps `!invariant.load`,
makes progress, terminates, determinate), from the one run of `runF_run`. `sum_inst` adds the
seventh field at `w1` and oracle 0 by `Grid.Sound.of_blocks`: the grid is sound for bytes 0 to 3
of block 1 (`word1`) and 2.0. One kernel, launch and address choice; every input word and oracle
for `six_inst`, one of each for `sum_inst`.

The twin (`run_twin`), of the premise `Mem.SkelEq`: with block 1 payload, `memF w1` and the
read-only `memF w1 true` are not related, as their blocks differ in `readOnly`; the other premises,
which concern the first launch, hold as in `run_inst`; and the launch on `memF w1 true` with oracle
0 starts, but no run of four steps from its grid ends at a grid in which every thread has returned,
as the store faults (`running_every`).
-/

namespace MojoProofTest.PayloadRun

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending MojoProofTest.Determinism
open MojoProofTest.SkelStep (labB afterLd)
open MojoProofTest.ScheduleOwned (succs mem_succs every every_sound)
open Relation

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- Block 1 of `memF w ro`: `Close.blk` with the word `w` in bytes 0 to 3, little-endian, read-only
if `ro`. -/
def blkF (w : BitVec 32) (ro : Bool) : Sem.Block :=
  { MojoProofTest.Close.blk with
    readOnly := ro, bytes := fun i => if i < 4 then .byte (w.extractLsb' (8 * i) 8) else .undef }

/-- Block 1 is `blkF w ro`, and `next = 2`. -/
def memF (w : BitVec 32) (ro : Bool := false) : Mem :=
  { blocks := fun c => if c = 1 then some (blkF w ro) else none, next := 2 }

/-- 1.0 as a binary32 word. -/
def w1 : BitVec 32 := 0x3f800000

/-- `%1 = load float, ptr %0`. -/
def ldF : Stmt := { res := some 1, inst := .load false (.fp .float) ⟨.ptr 0, .loc 0⟩ none }

/-- `%2 = fadd float %1, %1`. -/
def addF : Stmt := { res := some 2, inst := .fbin .fadd {} (.fp .float) (.loc 1) (.loc 1) }

/-- `store float %2, ptr %0`. -/
def stF : Stmt :=
  { res := none, inst := .store false ⟨.fp .float, .loc 2⟩ ⟨.ptr 0, .loc 0⟩ none }

/-- The kernel `define void @k(ptr %0)`: `ldF`, `addF`, `stF`, then `ret void`. -/
def kF : Func := { kernel #[ldF, addF, stF] with params := [⟨.ptr 0, [], some 0⟩] }

/-- The program of `kF` alone. -/
def progF : Program := .ofFunc kF

/-- `progF` passes `Labels.Ok` under `labB`: the pointer `%0` is skeleton, and the load's result,
the `fadd`'s operands and result and the stored value are payload. -/
theorem okF : Labels.Ok progF labB = true := rfl

/-- The grid and contexts of the launch of `kF` on one thread on `memF w ro` with a pointer to
block 1, address choice and oracle 0. -/
def runF (w : BitVec 32) (ro : Bool := false) : Grid × (Nat → Ctx) :=
  match Grid.start progF kF .one [.ptr ⟨1, 0⟩] (memF w ro) (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨progF, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- For every `w` and `ro`, the launch of `kF` on `memF w ro` starts, at `runF w ro`. -/
theorem startF_eq (w : BitVec 32) (ro : Bool) :
    Grid.start progF kF .one [.ptr ⟨1, 0⟩] (memF w ro) (fun _ => 0) (fun _ _ => 0) =
      .ok ((runF w ro).1, (runF w ro).2) :=
  rfl

/-- `runF w ro`'s grid after the load: the word `w` in register 1, and the read of bytes 0 to 3
of block 1 logged. -/
def gLF (w : BitVec 32) (ro : Bool := false) : Grid :=
  afterLd (runF w ro).2 (runF w ro).1 0 (.bits 32 w) 4

/-- `gLF w` after the `fadd`, the store and the `ret`. -/
def doneF (w : BitVec 32) : Grid := advs (runF w).2 (gLF w) [0, 0, 0]

/-- For `w1` and both `ro`, the load gives `gLF w1 ro`, evaluated after unfolding `Layout.decode`
once, for a fixed word. -/
theorem ldF_eq (ro : Bool) : (runF w1 ro).1.advance (runF w1 ro).2 0 = .ok (some (gLF w1 ro)) := by
  cases ro <;>
  · simp only [Grid.advance, step, exec, Mem.load, Layout.decode.eq_def]
    rfl

/-- For `w1` and both `ro`, the grids reachable from `runF w1 ro`'s: it, and those reachable
from `gLF w1 ro`. -/
theorem reachF (ro : Bool) {z : Grid}
    (h : ReflTransGen (Grid.Step .one (runF w1 ro).2) (runF w1 ro).1 z) :
    z = (runF w1 ro).1 ∨ ReflTransGen (Grid.Step .one (runF w1 ro).2) (gLF w1 ro) z := by
  rcases h.cases_head with rfl | ⟨y, hy, h⟩
  · exact .inl rfl
  have hs : succs .one (runF w1 ro).2 (runF w1 ro).1 = [gLF w1 ro] := by
    simp only [succs, show (runF w1 ro).1.threads.size = 1 from rfl,
      show List.range 1 = [0] from rfl, List.flatMap_cons, List.flatMap_nil, ldF_eq ro,
      show (runF w1 ro).1.fire .one (runF w1 ro).2 0 = .ok none from rfl, List.append_nil]
  have e := mem_succs hy
  rw [hs, List.mem_singleton] at e
  subst e
  exact .inr h

/-- Whether the first frame of every running thread of `g` holds a pointer into block 1 in
register 0. -/
def ptr1 (g : Grid) : Bool := g.threads.all fun
  | .run ⟨f :: _, _⟩ => match f.regs 0 with
    | some (.ptr p) => p.block == 1
    | _ => false
  | _ => true

/-- `ptr1` holds on every grid reachable from `gLF w1`, and the runs end within 3 steps. -/
theorem ptr1_every : every .one (runF w1).2 ptr1 3 (gLF w1) = true := by
  decide +kernel

/-- Under `labB`, with block 1 payload, the launch of `kF` on `memF w1` meets `Labels.MemOk`:
every frame's function is `kF` (`Grid.FramesOk`); the load has a payload result, and the store's
pointer, register 0, points into block 1 at every reachable grid (`ptr1_every`). -/
theorem memF_ok : labB.MemOk (· = 1) .one (runF w1).2 (runF w1).1 := by
  intro x hr n t ht f rest b st hf hb hst
  have hp : ptr1 x = true := by
    rcases reachF false hr with rfl | hr
    · decide +kernel
    · exact every_sound hr ptr1_every
  have e := Array.mem_of_find?_eq_some (Labels.FramesOk.fn
    (Grid.start_reach_framesOk (lab := labB) (startF_eq w1 false) okF rfl hr n _ ht) f
    (by rw [hf]; exact List.mem_cons_self))
  simp only [progF, Program.ofFunc, Array.mem_singleton] at e
  rw [e] at hb ⊢
  have hb' := Array.mem_of_find?_eq_some hb
  simp only [kF, kernel, Array.mem_singleton] at hb'
  subst hb'
  obtain ⟨fs, k⟩ := t
  obtain rfl : fs = f :: rest := hf
  have h1 := Array.all_eq_true'.1 hp _ (Array.mem_of_getElem? ht)
  generalize f.pc = p at hst
  match p, hst with
  | 0, hst =>
    obtain rfl : st = ldF := (Option.some.inj hst).symm
    exact fun h => absurd h (by decide)
  | 1, hst =>
    obtain rfl : st = addF := (Option.some.inj hst).symm
    trivial
  | 2, hst =>
    obtain rfl : st = stF := (Option.some.inj hst).symm
    intro _ q hq
    simp only at h1
    split at h1
    · rename_i p' h0
      simp only [Ctx.scope, evalV, h0, pure, Except.pure, Except.ok.injEq, Val.ptr.injEq] at hq
      subst hq
      simpa using h1
    · cases h1
  | p + 3, hst => simp at hst

/-- `memF w ro` has no pointer byte, for every `w` and `ro`. -/
theorem memF_bytesIn (w : BitVec 32) (ro : Bool) : (memF w ro).BytesIn (memF w ro).Known :=
  fun c b i p j hc _ hp => by
    simp only [memF] at hc
    split at hc
    · cases hc
      simp only [blkF] at hp
      split at hp <;> cases hp
    · cases hc

/-- For all words `w` and `w'`, `memF w` and `memF w'` are related when block 1 is payload, but
`memF w1` and its read-only `memF w1 true` are not. -/
theorem memF_skel (w w' : BitVec 32) :
    (memF w).SkelEq (· = 1) (memF w') ∧ ¬ (memF w1).SkelEq (· = 1) (memF w1 true) := by
  refine ⟨⟨rfl, rfl, fun b => ?_⟩, fun h => ?_⟩
  · by_cases hb : b = 1
    · subst hb
      show Option.Rel _ (some (blkF w false)) (some (blkF w' false))
      refine .some ⟨rfl, fun i => ?_, fun h => (h rfl).elim⟩
      by_cases hi : i < 4 <;> simp only [blkF, hi, ↓reduceIte] <;> rfl
    · have e : ∀ x, (memF x).blocks b = none := fun _ => ite_eq_right hb
      rw [e, e]
      exact .none
  · have hb := h.blocks 1
    change Option.Rel _ (some (blkF w1 false)) (some (blkF w1 true)) at hb
    cases hb with
    | some hB => exact absurd (congrArg Sem.Block.readOnly hB.shape) (by decide)

/-- The size of block 1, an observation that reads only the blocks. -/
def obsF (m : Mem) : Option Nat := (m.blocks 1).map (·.size)

/-- Bytes 0 to 3 of block 1. -/
def word1 (m : Mem) : Option (List MemByte) :=
  (m.blocks 1).map fun B => (List.range 4).map B.bytes

/-- For `w1`, by evaluation: the launch's thread runs in four steps to `doneF w1`, in which every
thread has returned, which is not bad, and whose block 1 holds 2.0. -/
theorem runF_run :
    Path (Grid.Step .one (runF w1).2) 4 (runF w1).1 (doneF w1) ∧ (doneF w1).Done ∧
      ¬ (doneF w1).Bad .one (runF w1).2 ∧
      word1 (doneF w1).mem = some [.byte 0, .byte 0, .byte 0, .byte 0x40] := by
  have hd : (doneF w1).Done := by
    unfold Grid.Done
    decide +kernel
  refine ⟨.cons ⟨0, .inl (ldF_eq false)⟩
    (path_advs _ [0, 0, 0] (by decide +kernel) (.nil _)), hd, ?_, by decide +kernel⟩
  rintro (hf | hr | hk | hr)
  · exact done_not_faults hd hf
  · rw [show racy (doneF w1).mem.trace = false by decide +kernel] at hr
    cases hr
  · rw [show kept (doneF w1).mem.trace = true by decide +kernel] at hk
    cases hk
  · exact hd.not_raceEnabled hr

/-- **The instance of `Grid.skel_run`** on a kernel that reads and writes the payload: under
`labB` and with block 1 payload, for every memory `m₂` related to `memF w1` by `Mem.SkelEq` and
every oracle `o₂`, the launch of `kF` on `m₂` with address choice 0 starts, its grid runs in four
steps to a grid in which every thread has returned, that is not bad, is related to `doneF w1` by
`Grid.SkelRel` and has a block 1 of size 4, and the start's grid is `Grid.Sound` for the size of
block 1 and 4. The premises: `memF_bytesIn`, `okF`, `memF_ok` and `runF_run`. -/
theorem run_inst {m₂ : Mem} (hm : (memF w1).SkelEq (· = 1) m₂) (o₂ : Nat → Nat → Nat) :
    ∃ g₂ c₂ z₂, Grid.start progF kF .one [.ptr ⟨1, 0⟩] m₂ (fun _ => 0) o₂ = .ok (g₂, c₂) ∧
      Path (Grid.Step .one c₂) 4 g₂ z₂ ∧ z₂.Done ∧ ¬ z₂.Bad .one c₂ ∧
      (doneF w1).SkelRel labB (· = 1) z₂ ∧ obsF z₂.mem = some 4 ∧
      Grid.Sound .one c₂ g₂ obsF (· = 4) := by
  obtain ⟨p₁, hd₁, hb₁, -⟩ := runF_run
  obtain ⟨g₂, c₂, z₂, e, p₂, hd₂, hb₂, hr, hs⟩ := Grid.skel_run (lab := labB) (o₂ := o₂)
    (startF_eq w1 false) hm (memF_bytesIn w1 false) okF rfl memF_ok p₁ hd₁ hb₁
  have hy : obsF z₂.mem = some 4 := by
    have hB := hr.mem.blocks 1
    unfold obsF
    revert hB
    generalize z₂.mem.blocks 1 = o
    intro hB
    change Option.Rel _ (some _) _ at hB
    cases hB with
    | some hB =>
      have e : _ = _ := congrArg Block.size hB.shape
      exact congrArg some (e.symm.trans (by decide +kernel))
  exact ⟨g₂, c₂, z₂, e, p₂, hd₂, hb₂, hr, hy,
    hs (fun m m' h => by simp only [obsF, h]) hy rfl⟩

/-- **The instance of `Grid.skel_six`** on a kernel that reads, adds and writes a float: under
`labB` and with block 1 payload, for every word `w` in block 1 (every binary32 input, `memF_skel`)
and every oracle `o₂`, the launch of `kF` on `memF w` with address choice 0 starts, and its grid is
safe, race free, keeps `!invariant.load`, makes progress, terminates and is determinate for the
blocks. From the one run of `runF_run` on `memF w1` with oracle 0; the premises are those of
`run_inst`. -/
theorem six_inst (w : BitVec 32) (o₂ : Nat → Nat → Nat) :
    ∃ g₂ c₂, Grid.start progF kF .one [.ptr ⟨1, 0⟩] (memF w) (fun _ => 0) o₂ = .ok (g₂, c₂) ∧
      Grid.Sound .one c₂ g₂ (fun m => some m.blocks) (fun _ => True) :=
  Grid.skel_six (lab := labB) (startF_eq w1 false) (memF_bytesIn w1 false) okF rfl memF_ok
    (Path.exists_iff.1 ⟨_, runF_run.1⟩) runF_run.2.1 runF_run.2.2.1 (memF_skel w1 w).1 o₂

/-- `Grid.Sound.of_blocks` on `six_inst` at `w1` and oracle 0: the one run's final grid
`doneF w1` holds 2.0 in block 1 (`runF_run`), so the start's grid is sound for bytes 0 to 3 of
block 1 and that word. -/
theorem sum_inst : Grid.Sound .one (runF w1).2 (runF w1).1 word1
    (· = [.byte 0, .byte 0, .byte 0, .byte 0x40]) := by
  obtain ⟨g, c, e, hs⟩ := six_inst w1 (fun _ _ => 0)
  rw [startF_eq] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e).symm
  exact hs.of_blocks (fun m m' h => by simp only [word1, h]) (Path.exists_iff.1 ⟨_, runF_run.1⟩)
    runF_run.2.1 runF_run.2.2.2 rfl

/-- Whether some thread of `g` has not returned. -/
def running (g : Grid) : Bool := !g.threads.all (· matches .done)

/-- `running` holds on every grid reachable from `gLF w1 true`, and the runs end within 1 step:
the `fadd`, then the store to the read-only block 1 faults. -/
theorem running_every : every .one (runF w1 true).2 running 1 (gLF w1 true) = true := by
  decide +kernel

/-- **The twin** of `Grid.skel_run`'s premise `Mem.SkelEq`: with block 1 payload, `memF w1` and
its read-only `memF w1 true` are not related (`memF_skel`), the other premises hold as in
`run_inst`, and the conclusion fails for `memF w1 true` and oracle 0: the launch of `kF` on it
starts, but no run of four steps from its grid ends at a grid in which every thread has
returned, as the store to block 1 faults (`running_every`). -/
theorem run_twin :
    ¬ (memF w1).SkelEq (· = 1) (memF w1 true) ∧
      ¬ ∃ g₂ c₂ z₂, Grid.start progF kF .one [.ptr ⟨1, 0⟩] (memF w1 true) (fun _ => 0)
          (fun _ _ => 0) = .ok (g₂, c₂) ∧ Path (Grid.Step .one c₂) 4 g₂ z₂ ∧ z₂.Done := by
  refine ⟨(memF_skel w1 w1).2, fun ⟨g₂, c₂, z₂, e, p, hd⟩ => ?_⟩
  rw [startF_eq] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e).symm
  have h : running z₂ = true := by
    rcases reachF true (Path.exists_iff.1 ⟨_, p⟩) with rfl | hz
    · decide +kernel
    · exact every_sound hz running_every
  have hd' : z₂.threads.all (· matches .done) = true := hd
  simp only [running, hd', Bool.not_true] at h
  cases h

end MojoProofTest.PayloadRun
