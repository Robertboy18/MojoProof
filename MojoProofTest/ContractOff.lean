import MojoProof.Sym.ContractOff
import MojoProofTest.ScheduleOwned

/-!
# The twin of the converse of `Kernel.Sound.contractOff` at a fusing oracle family

Tests of one example. The kernel `fmaK`, a hand-built `Func` with one `fmul contract` and one
`fadd contract`, stores `(1 + 2 ^ -23) * (1 - 2 ^ -23) - 1` as a binary32 word to its buffer. Fused
(one rounding), the word is `-2 ^ -46` (`0xa8800000`); with contraction off the product rounds to
1.0 and the word is `+0`.

* `fmaK`, its program `fmaP`, the program `fmaQ` of `fmaK.contractOff` (`fmaP`'s module with the
  flags removed, its layout and its intrinsics, by `rfl`), the memory `outK` (one writable block
  of 4 bytes in space 1, block 1), the arguments `argsK`, the starts `startAt` and the final grids
  `doneAt` of the evaluator `Grid.run`, on `Launch.one` at the address choice `fun _ => 0` and the
  oracle family `fun _ _ => 1`, at which every `fadd contract` fuses with the recorded product of
  its first operand.
* `startP_eq`, `startQ_eq`, `runP_eq`, `runQ_eq`: the two starts and runs, evaluated (`rfl`).
  `outK_bytesIn`: `outK` has no pointer byte. `doneQ_good`: the run of `fmaK.contractOff` ends
  with its thread returned, not bad, and the bytes of `+0` in block 1.
* `twin`: at that family, a complete run of `fmaK` in `fmaP` observes the bytes of `-2 ^ -46`;
  `fmaK.contractOff` in `fmaQ` is sound for the observation `+0` (`Grid.start_sound`), so none of
  its complete runs observes `-2 ^ -46`, and `fmaK` in `fmaP` is not sound for the same admission
  and relation: `Kernel.Sound` does not move back from the contraction-off kernel at a family with
  a fusing row. That family is no family of never-fusing rows, and at the rows `neverFuse` of it
  `fmaK` observes `+0` and not `-2 ^ -46` (`Kernel.Obs.contractOff_iff`). So the converse fails
  also in the form of `Kernel.Sound.contractOff`'s conclusion: its admission here,
  `fun ch ω => ch = (fun _ => 0) ∧ (fun n => neverFuse (ω n)) = fun _ _ => 1`, is empty, and the
  contraction-off kernel is sound for it with nothing to check.

Everything here covers one program pair, one launch, one argument list, one memory, one address
choice and one oracle family (docs/proofs/contract-off.md).
-/

namespace MojoProofTest.ContractOff

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.ScheduleOwned (obs1)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The kernel `@fk(ptr addrspace(1) %p)`, its parameter in register `%0`:
`%1 = fmul contract float 0x3FF0000020000000, 0x3FEFFFFFC0000000` (`1 + 2 ^ -23` times
`1 - 2 ^ -23`), `%2 = fadd contract float %1, -1.0`, `store float %2, ptr addrspace(1) %p`,
`ret void`. -/
def fmaK : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "fk",
    params := [⟨.ptr 1, [], some 0⟩], group := none, names := #["entry", "p", "m", "s"],
    blocks := #[⟨0, #[
      { res := some 1, inst := .fbin .fmul { contract := true } (.fp .float)
          (.float (.hex "" 0x3FF0000020000000)) (.float (.hex "" 0x3FEFFFFFC0000000)) },
      { res := some 2, inst := .fbin .fadd { contract := true } (.fp .float) (.loc 1)
          (.float (.hex "" 0xBFF0000000000000)) },
      { res := none, inst := .store false ⟨.fp .float, .loc 2⟩ ⟨.ptr 1, .loc 0⟩ (some 4) }],
      .ret none⟩] }

/-- The program of `fmaK` alone, with the default data layout. -/
def fmaP : Program := .ofFunc fmaK

/-- The program of `fmaK.contractOff` alone, with the default data layout. -/
def fmaQ : Program := .ofFunc fmaK.contractOff

/-- One writable block of 4 bytes in space 1 at address choices 1, on the empty memory: block 1.
-/
def outK : Mem × Nat := ({} : Mem).alloc fmaP.layout 1 4 4 true false .all 1 1

/-- The arguments: a pointer to `outK`'s block. -/
def argsK : List Val := [.ptr ⟨outK.2, 0⟩]

/-- The grid and contexts of the start of kernel `fn` of `prog` on `Launch.one` with `argsK`,
`outK`, address choice `fun _ => 0` and oracle family `fun _ _ => 1` (an empty grid if it
fails). -/
def startAt (prog : Program) (fn : Func) : Grid × (Nat → Ctx) :=
  match Grid.start prog fn Launch.one argsK outK.1 (fun _ => 0) (fun _ _ => 1) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The grid the evaluator `Grid.run` reaches from the grid of `s` with its contexts, 10 steps per
thread and 2 phases (the grid of `s` if it fails). -/
def doneAt (s : Grid × (Nat → Ctx)) : Grid :=
  match s.1.run Launch.one s.2 10 2 with
  | .ok g => g
  | .error _ => s.1

/-- The start of `fmaK` in `fmaP` succeeds, a test of one example (evaluated). -/
theorem startP_eq :
    Grid.start fmaP fmaK Launch.one argsK outK.1 (fun _ => 0) (fun _ _ => 1) =
      .ok (startAt fmaP fmaK) := rfl

/-- The start of `fmaK.contractOff` in `fmaQ` succeeds, a test of one example (evaluated). -/
theorem startQ_eq :
    Grid.start fmaQ fmaK.contractOff Launch.one argsK outK.1 (fun _ => 0) (fun _ _ => 1) =
      .ok (startAt fmaQ fmaK.contractOff) := rfl

/-- The evaluator runs `fmaK`'s start to `doneAt`, a test of one example (evaluated). -/
theorem runP_eq : (startAt fmaP fmaK).1.run Launch.one (startAt fmaP fmaK).2 10 2 =
    .ok (doneAt (startAt fmaP fmaK)) := rfl

/-- The evaluator runs `fmaK.contractOff`'s start to `doneAt`, a test of one example
(evaluated). -/
theorem runQ_eq :
    (startAt fmaQ fmaK.contractOff).1.run Launch.one (startAt fmaQ fmaK.contractOff).2 10 2 =
      .ok (doneAt (startAt fmaQ fmaK.contractOff)) := rfl

/-- `outK` has no pointer byte, a test of one example. -/
theorem outK_bytesIn : outK.1.BytesIn outK.1.Known :=
  Mem.alloc_bytesIn (fun _ _ _ _ _ h => by cases h) (init := []) (fun _ _ h => by cases h)
    _ _ _ _ _ _ _ _ _ _

/-- A test of one example: in the grid the run of `fmaK.contractOff` reaches, its thread has
returned, the grid is not bad, and block 1 holds the bytes of `+0`. -/
theorem doneQ_good : (doneAt (startAt fmaQ fmaK.contractOff)).Done ∧
    ¬ (doneAt (startAt fmaQ fmaK.contractOff)).Bad Launch.one (startAt fmaQ fmaK.contractOff).2 ∧
    obs1 (doneAt (startAt fmaQ fmaK.contractOff)).mem = some (leBytes 4 0) := by
  have hd : (doneAt (startAt fmaQ fmaK.contractOff)).Done := rfl
  refine ⟨hd, fun hb => ?_, rfl⟩
  rw [hd.bad_iff, show racy (doneAt (startAt fmaQ fmaK.contractOff)).mem.trace = false from rfl,
    show kept (doneAt (startAt fmaQ fmaK.contractOff)).mem.trace = true from rfl] at hb
  simp at hb

/-- **The twin of the converse of `Kernel.Sound.contractOff` at a fusing oracle family**, a test
of one example: `fmaK` in `fmaP` and `fmaK.contractOff` in `fmaQ`, on `Launch.one` with `argsK`
and `outK`, at the address choice `fun _ => 0` and the oracle family `fun _ _ => 1` (every
`fadd contract` fuses with its first operand's product), observed by bytes 0 to 3 of block 1:
1. a complete run of `fmaK` observes the bytes of `-2 ^ -46` (`0xa8800000`, one rounding);
2. `fmaK.contractOff` is sound, for the admission of that address choice and family alone, for
   the observation of the bytes of `+0` (two roundings);
3. so no complete run of `fmaK.contractOff` under that family observes the bytes of `-2 ^ -46`;
4. and `fmaK` is not sound for the same admission and relation;
5. the family is no family of never-fusing rows `neverFuse (ω n)`;
6. at the rows `neverFuse` of it (every number 0), a complete run of `fmaK` observes the bytes of
   `+0`, and none observes those of `-2 ^ -46` (`Kernel.Obs.contractOff_iff`).

Parts 4 and 5 refute the converse also in the form of `Kernel.Sound.contractOff`'s conclusion: by
5 its admission here, `fun ch ω => ch = (fun _ => 0) ∧ (fun n => neverFuse (ω n)) = fun _ _ => 1`,
is empty, so the contraction-off kernel is sound for it with nothing to check, while by 4 `fmaK`
is not sound for the admission it comes from. -/
theorem twin :
    Kernel.Obs fmaP fmaK Launch.one argsK outK.1 obs1 (fun _ => 0) (fun _ _ => 1)
      (leBytes 4 0xa8800000) ∧
    Kernel.Sound fmaQ fmaK.contractOff Launch.one argsK outK.1
      (fun ch ω => ch = (fun _ => 0) ∧ ω = fun _ _ => 1) obs1 (· = leBytes 4 0) ∧
    ¬ Kernel.Obs fmaQ fmaK.contractOff Launch.one argsK outK.1 obs1 (fun _ => 0) (fun _ _ => 1)
      (leBytes 4 0xa8800000) ∧
    ¬ Kernel.Sound fmaP fmaK Launch.one argsK outK.1
      (fun ch ω => ch = (fun _ => 0) ∧ ω = fun _ _ => 1) obs1 (· = leBytes 4 0) ∧
    (∀ ω : Nat → Nat → Nat, (fun n => neverFuse (ω n)) ≠ fun _ _ => 1) ∧
    Kernel.Obs fmaP fmaK Launch.one argsK outK.1 obs1 (fun _ => 0)
      (fun _ => neverFuse fun _ => 1) (leBytes 4 0) ∧
    ¬ Kernel.Obs fmaP fmaK Launch.one argsK outK.1 obs1 (fun _ => 0)
      (fun _ => neverFuse fun _ => 1) (leBytes 4 0xa8800000) := by
  have hP : Kernel.Obs fmaP fmaK Launch.one argsK outK.1 obs1 (fun _ => 0) (fun _ _ => 1)
      (leBytes 4 0xa8800000) := ⟨_, _, _, startP_eq, Grid.run_reach runP_eq, rfl, rfl⟩
  obtain ⟨_, hpath⟩ := Path.exists_iff.2 (Grid.run_reach (L := Launch.one) runQ_eq)
  have hS : Kernel.Sound fmaQ fmaK.contractOff Launch.one argsK outK.1
      (fun ch ω => ch = (fun _ => 0) ∧ ω = fun _ _ => 1) obs1 (· = leBytes 4 0) := by
    rintro _ _ ⟨rfl, rfl⟩
    exact ⟨_, _, startQ_eq, Grid.start_sound startQ_eq outK_bytesIn
      (fun m m' h => by simp only [obs1, h]) hpath doneQ_good.1 doneQ_good.2.1 doneQ_good.2.2 rfl⟩
  have hQ : Kernel.Obs fmaQ fmaK.contractOff Launch.one argsK outK.1 obs1 (fun _ => 0)
      (fun _ _ => 1) (leBytes 4 0) :=
    ⟨_, _, _, startQ_eq, Grid.run_reach runQ_eq, doneQ_good.1, doneQ_good.2.2⟩
  have ne : leBytes 4 0xa8800000 ≠ leBytes 4 0 := by decide
  have nQ : ¬ Kernel.Obs fmaQ fmaK.contractOff Launch.one argsK outK.1 obs1 (fun _ => 0)
      (fun _ _ => 1) (leBytes 4 0xa8800000) := fun h => ne (Kernel.Sound.obs hS ⟨rfl, rfl⟩ h)
  have hiff : ∀ y, Kernel.Obs fmaQ fmaK.contractOff Launch.one argsK outK.1 obs1 (fun _ => 0)
      (fun _ _ => 1) y ↔
        Kernel.Obs fmaP fmaK Launch.one argsK outK.1 obs1 (fun _ => 0)
          (fun _ => neverFuse fun _ => 1) y :=
    fun _ => Kernel.Obs.contractOff_iff (P := fmaP) (Q := fmaQ) rfl rfl rfl (by decide +kernel)
      (by decide +kernel)
  refine ⟨hP, hS, nQ, fun h => ne (Kernel.Sound.obs h ⟨rfl, rfl⟩ hP), fun ω h => ?_,
    (hiff _).1 hQ, fun h => nQ ((hiff _).2 h)⟩
  have h0 := congrFun (congrFun h 0) 0
  simp only [neverFuse] at h0
  omega

end MojoProofTest.ContractOff
