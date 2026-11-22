import MojoProof.Sem.SkelExec
import MojoProofTest.Labels
import MojoProofTest.Skeleton

/-!
# Instances and twins of T3b's statement and block-entry lemmas (`exec_skel`, `enter_skel`)

The frames: `at0 fn r x` starts `fn` with the word `x` in register 0 and `r n` in every other
register `n`; for every function `fn`, labelling with register 0 of `fn` payload, `r`, `x` and `y`,
`at0 fn r x` and `at0 fn r y` are related by `Frame.Skel` (`at0_skel`).

The instance: `%2 = add i8 %0, %1` (`addSt`), on two frames of `kernel #[addSt]` whose payload
register 0 holds the words 7 and 8 and whose register 1 holds the word 1 (`addAt`), meets every
premise of `exec_skel` with registers 0 and 2 payload (`labP true`), for every oracle of the
second run, thread position and memory, so the two effects are related (`exec_inst`); the
results are the different words 8 and 9 (`add_eval`).

The twins of the three label premises of `exec_skel`, each meeting the other premises:
- `Labels.stmtOk`: with register 2 skeleton (`labP false`) the `add` fails it, in the context of
  the program of `kernel #[]`, which passes `Labels.Ok`, on the frames `addAt 7` and `addAt 8`,
  which `Frame.Skel` relates, and the effects are not related by `Eff.Skel`, as register 2 holds 8
  in one frame after and 9 in the other (`exec_twin`). The frames' function is not the program's:
  `Labels.funcOk` checks every statement, so in a program that passes `Labels.Ok` no function has
  a statement that fails `Labels.stmtOk`;
- `Labels.MemAt`: `store i8 %0, ptr %1` (`store01`) of the payload register 0, on frames whose
  register 0 holds the words 5 and 6 and register 1 a pointer to block 1 (`stAt`) and the memory
  `memX 1`, fails it with no block payload, and the memories after are not related by
  `Mem.SkelEq`, as block 1 holds byte 5 in one and 6 in the other (`store_eval`,
  `exec_mem_twin`);
- `Labels.Ok`: `call void @g(i8 %0)` (`callSt`) of the payload register 0, in a program whose `@g`
  has the payload parameter `i8 range(i8 0, 2) %x` (`gFn`, `callProg`), passes `Labels.stmtOk`
  while the program fails `Labels.Ok`, and on frames whose register 0 holds 1 and 2 it calls `@g`
  with 1 and with `poison`, which `Eff.Skel` does not relate (`exec_call_twin`).

The instance of `enter_skel`: `phiFn` branches from its entry (label 0) to block 1, whose head is
`%2 = phi i8 [%0, %entry]` (`phiSt`); entering block 1 from frames whose payload register 0 holds
7 and 8, with registers 0 and 2 payload (`labP true`), for every oracle of the second run, thread
position and memory, gives related frames (`enter_inst`), whose register 2 holds the word of
register 0 (`enter_eval`). Its twin, of `Labels.funcOk`: with register 2 skeleton (`labP false`)
`phiFn` fails it, and the frames after hold 7 and 8 in register 2, which `Frame.Skel` does not
relate (`enter_twin`).

`at0_skel` is for all of these; the other statements are about these statements and frames.
-/

namespace MojoProofTest.SkelExec

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending MojoProofTest.Labels
open MojoProofTest.Skeleton (memX blkX)

-- `Array.all` recurses by well-founded recursion, so `rfl` cannot evaluate `Labels.Ok` without
-- this.
unseal Array.anyM.loop

/-- `%2 = add i8 %0, %1`. -/
def addSt : Stmt := { res := some 2, inst := .bin .add {} (.int 8) (.loc 0) (.loc 1) }

/-- Register 0 of every function is payload, and register 2 when `p`; no function has a payload
result. -/
def labP (p : Bool) : Labels := { reg := fun _ n => n == 0 || p && n == 2, ret := fun _ => false }

/-- A frame at the start of `fn` whose register 0 holds the word `x` and every other register `n`
holds `r n`. -/
def at0 (fn : Func) (r : Nat → Option Val) (x : BitVec 8) : Frame :=
  { fn, label := 0, pc := 0, regs := fun n => if n = 0 then some (.bits 8 x) else r n,
    prods := fun _ => none, allocas := [], dest := none }

/-- For every function `fn`, labelling with register 0 of `fn` payload, other registers `r` and
words `x` and `y`, `at0 fn r x` and `at0 fn r y` are related by `Frame.Skel`. -/
theorem at0_skel {lab : Labels} {fn : Func} (h : lab.reg fn.name 0 = true) (r : Nat → Option Val)
    (x y : BitVec 8) : (at0 fn r x).Skel lab (at0 fn r y) := by
  refine ⟨rfl, fun n => ?_, fun _ => .none⟩
  by_cases h0 : n = 0
  · subst h0
    refine .some (Labels.Rel.of_rel h ?_)
    exact rfl
  · show Option.Rel _ (if n = 0 then _ else r n) (if n = 0 then _ else r n)
    simp only [h0, ↓reduceIte]
    rcases r n with _ | v
    · exact .none
    · exact .some (Labels.Rel.refl Val.Skel.refl _ _)

/-- A frame at the start of `kernel #[addSt]` whose register 0 holds the word `x` and register 1
the word 1. -/
def addAt (x : BitVec 8) : Frame :=
  at0 (kernel #[addSt]) (fun n => if n = 1 then some (.bits 8 1) else none) x

/-- The instance of `exec_skel`: for every oracle `o` of the second run, thread position and
memory, `addSt` on `addAt 7` and on `addAt 8` gives effects related by `Eff.Skel` under
`labP true`. -/
theorem exec_inst (o : Nat → Nat) (k : Nat) (m : Mem) :
    Except.Rel (Eff.Skel (labP true) (fun _ => False) true)
      (exec (ctxOf (kernel #[addSt])) ((ctxOf (kernel #[addSt])).scope m (addAt 7) k) k
        (addAt 7) addSt)
      (exec { ctxOf (kernel #[addSt]) with oracle := o }
        ({ ctxOf (kernel #[addSt]) with oracle := o }.scope m (addAt 8) k) k (addAt 8) addSt) :=
  exec_skel (c := ctxOf (kernel #[addSt])) (k := k) (st := addSt) (at0_skel rfl _ 7 8)
    (Mem.SkelEq.refl _ m) rfl rfl trivial

/-- For every context, memory and word `x`, `addSt` on `addAt x` sets register 2 to `x + 1`. -/
theorem add_eval (c : Ctx) (m : Mem) (x : BitVec 8) :
    exec c (c.scope m (addAt x) 0) 0 (addAt x) addSt =
      .ok (.next { (addAt x).set (some 2) (some (.bits 8 (x + 1))) none with pc := 1 } m) :=
  rfl

/-- The twin of `Labels.stmtOk`, meeting the other premises of `exec_skel`: under `labP false`
(register 2 skeleton) the program of `kernel #[]` passes `Labels.Ok`, `addAt 7` and `addAt 8` are
related by `Frame.Skel`, and `addSt` meets `Labels.MemAt` (it is no memory access) but fails
`Labels.stmtOk`; in that program's context, for every memory, its effects on the two frames are
not related by `Eff.Skel`. -/
theorem exec_twin (m : Mem) : Labels.Ok (.ofFunc (kernel #[])) (labP false) = true ∧
    (addAt 7).Skel (labP false) (addAt 8) ∧
    (labP false).MemAt (fun _ => False) ((ctxOf (kernel #[])).scope m (addAt 7) 0) (addAt 7).fn
      addSt ∧
    (labP false).stmtOk (.ofFunc (kernel #[])) (addAt 7).fn addSt = false ∧
    ¬ Except.Rel (Eff.Skel (labP false) (fun _ => False) false)
      (exec (ctxOf (kernel #[])) ((ctxOf (kernel #[])).scope m (addAt 7) 0) 0 (addAt 7) addSt)
      (exec (ctxOf (kernel #[])) ((ctxOf (kernel #[])).scope m (addAt 8) 0) 0 (addAt 8) addSt) := by
  refine ⟨rfl, at0_skel rfl _ 7 8, trivial, rfl, fun h => ?_⟩
  rw [add_eval, add_eval] at h
  cases h with
  | ok h =>
    have h2 : Option.Rel (Labels.Rel false Val.Skel) (some (Val.bits 8 8)) (some (Val.bits 8 9)) :=
      h.1.regs 2
    cases h2 with
    | some h2 =>
      change Val.bits 8 8 = Val.bits 8 9 at h2
      simp at h2

/-- A frame at the start of `kernel #[store01]` whose register 0 holds the word `x` and register 1
a pointer to block 1. -/
def stAt (x : BitVec 8) : Frame :=
  at0 (kernel #[store01]) (fun n => if n = 1 then some (.ptr ⟨1, 0⟩) else none) x

/-- For every word `x`, `store01` on `stAt x` and `memX 1` writes the byte of `x` to block 1. -/
theorem store_eval (x : BitVec 8) : ∃ m, exec (ctxOf (kernel #[store01]))
    ((ctxOf (kernel #[store01])).scope (memX 1) (stAt x) 0) 0 (stAt x) store01 =
      .ok (.next { stAt x with pc := 1 } m) ∧
      m.blocks 1 = some ((blkX 1).put 0 (leBytes 1 x.toNat)) :=
  ⟨_, by simp only [exec, store01, Mem.store]; rfl, rfl⟩

/-- The twin of `Labels.MemAt`: `kernel #[store01]` passes `Labels.Ok` and `store01` passes
`Labels.stmtOk` under `lab0`, but with no block payload `store01` on `stAt 5` fails
`Labels.MemAt`, and its effects on `stAt 5` and `stAt 6` (related by `at0_skel`) with the memory
`memX 1` are not related by `Eff.Skel`. -/
theorem exec_mem_twin : Labels.Ok (.ofFunc (kernel #[store01])) lab0 = true ∧
    lab0.stmtOk (.ofFunc (kernel #[store01])) (kernel #[store01]) store01 = true ∧
    ¬ lab0.MemAt (fun _ => False) ((ctxOf (kernel #[store01])).scope (memX 1) (stAt 5) 0)
      (stAt 5).fn store01 ∧
    ¬ Except.Rel (Eff.Skel lab0 (fun _ => False) false)
      (exec (ctxOf (kernel #[store01])) ((ctxOf (kernel #[store01])).scope (memX 1) (stAt 5) 0) 0
        (stAt 5) store01)
      (exec (ctxOf (kernel #[store01])) ((ctxOf (kernel #[store01])).scope (memX 1) (stAt 6) 0) 0
        (stAt 6) store01) := by
  refine ⟨rfl, rfl, fun h => h rfl ⟨1, 0⟩ rfl, fun h => ?_⟩
  obtain ⟨m₅, e₅, b₅⟩ := store_eval 5
  obtain ⟨m₆, e₆, b₆⟩ := store_eval 6
  rw [e₅, e₆] at h
  cases h with
  | ok h =>
    have hb := h.2.blocks 1
    rw [b₅, b₆] at hb
    cases hb with
    | some hB => exact absurd (hB.same id 0) (by decide)

/-- `define void @g(i8 range(i8 0, 2) %x) { ret void }`, its parameter register 0. -/
def gFn : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "g",
    params := [⟨.int 8, [.range (.int 8) 0 2], some 0⟩], group := none, names := #["x", "entry"],
    blocks := #[⟨1, #[], .ret none⟩] }

/-- `call void @g(i8 %0)`. -/
def callSt : Stmt := { res := none, inst := .call {} .void (.fn "g") [(⟨.int 8, .loc 0⟩, [])] }

/-- The program of `kernel #[callSt]` and `gFn`, with the default layout. -/
def callProg : Program :=
  { module := { (default : Module) with funcs := #[kernel #[callSt], gFn] }, sha256 := "",
    layout := {}, intrinsics := [], kernels := ["k"] }

/-- `ctxOf`'s context with program `callProg`. -/
def cC : Ctx := { ctxOf (kernel #[callSt]) with prog := callProg }

/-- The twin of `Labels.Ok` (the part `exec_skel` uses, (O4)'s payload parameters without
`range`): under `lab0`, `callProg` fails it, as `gFn`'s payload parameter has `range(i8 0, 2)`,
while `callSt` passes `Labels.stmtOk`; for every memory, `callSt` on frames whose payload register
0 holds 1 and 2 (`at0_skel`) calls `gFn` with 1 and with `poison`, which `Eff.Skel` does not
relate. -/
theorem exec_call_twin (m : Mem) : Labels.Ok callProg lab0 = false ∧
    lab0.stmtOk callProg (kernel #[callSt]) callSt = true ∧
    exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 1) 0) 0
      (at0 (kernel #[callSt]) (fun _ => none) 1) callSt = .ok (.call gFn [.bits 8 1]) ∧
    exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 2) 0) 0
      (at0 (kernel #[callSt]) (fun _ => none) 2) callSt = .ok (.call gFn [.poison]) ∧
    ¬ Except.Rel (Eff.Skel lab0 (fun _ => False) false)
      (exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 1) 0) 0
        (at0 (kernel #[callSt]) (fun _ => none) 1) callSt)
      (exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 2) 0) 0
        (at0 (kernel #[callSt]) (fun _ => none) 2) callSt) := by
  have e₁ : exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 1) 0) 0
      (at0 (kernel #[callSt]) (fun _ => none) 1) callSt = .ok (.call gFn [.bits 8 1]) := rfl
  have e₂ : exec cC (cC.scope m (at0 (kernel #[callSt]) (fun _ => none) 2) 0) 0
      (at0 (kernel #[callSt]) (fun _ => none) 2) callSt = .ok (.call gFn [.poison]) := rfl
  refine ⟨rfl, rfl, e₁, e₂, fun h => ?_⟩
  rw [e₁, e₂] at h
  cases h with
  | ok h =>
    have h0 := h.2 0
    cases h0 with
    | some h0 =>
      change Val.Skel (.bits 8 1) .poison at h0
      simp [Val.Skel, Val.erase] at h0

/-- `%2 = phi i8 [%0, %entry]`. -/
def phiSt : Stmt := { res := some 2, inst := .phi (.int 8) [(.loc 0, 0)] }

/-- `define void @p()`: the entry (label 0) branches to block 1, which is `phiSt` and
`ret void`. -/
def phiFn : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "p", params := [],
    group := none, names := #[], blocks := #[⟨0, #[], .br 1⟩, ⟨1, #[phiSt], .ret none⟩] }

/-- For every memory and word `x`, entering block 1 of `phiFn` from its entry with the word `x` in
register 0 sets register 2 to `x`. -/
theorem enter_eval (m : Mem) (x : BitVec 8) :
    enter ((ctxOf phiFn).scope m (at0 phiFn (fun _ => none) x) 0) (at0 phiFn (fun _ => none) x) 1 =
      .ok { (at0 phiFn (fun _ => none) x).set (some 2) (some (.bits 8 x)) none with
        label := 1, pc := 1 } :=
  rfl

/-- The instance of `enter_skel`: for every oracle `o` of the second run, thread position and
memory, entering block 1 of `phiFn` from frames whose payload register 0 holds 7 and 8 gives
frames related by `Frame.Skel` under `labP true`. -/
theorem enter_inst (o : Nat → Nat) (k : Nat) (m : Mem) :
    Except.Rel (Frame.Skel (labP true))
      (enter ((ctxOf phiFn).scope m (at0 phiFn (fun _ => none) 7) k)
        (at0 phiFn (fun _ => none) 7) 1)
      (enter ({ ctxOf phiFn with oracle := o }.scope m (at0 phiFn (fun _ => none) 8) k)
        (at0 phiFn (fun _ => none) 8) 1) :=
  enter_skel (c := ctxOf phiFn) (at0_skel rfl _ 7 8) (Mem.SkelEq.refl (fun _ => False) m) rfl 1

/-- The twin of `Labels.funcOk`: with register 2 skeleton, `phiFn` fails it, and for every memory,
entering block 1 from frames whose payload register 0 holds 7 and 8 (`at0_skel`) gives frames
that `Frame.Skel` does not relate. -/
theorem enter_twin (m : Mem) : (labP false).funcOk (.ofFunc phiFn) phiFn = false ∧
    ¬ Except.Rel (Frame.Skel (labP false))
      (enter ((ctxOf phiFn).scope m (at0 phiFn (fun _ => none) 7) 0)
        (at0 phiFn (fun _ => none) 7) 1)
      (enter ((ctxOf phiFn).scope m (at0 phiFn (fun _ => none) 8) 0)
        (at0 phiFn (fun _ => none) 8) 1) := by
  refine ⟨rfl, fun h => ?_⟩
  rw [enter_eval, enter_eval] at h
  cases h with
  | ok h =>
    have h2 : Option.Rel (Labels.Rel false Val.Skel) (some (Val.bits 8 7)) (some (Val.bits 8 8)) :=
      h.regs 2
    cases h2 with
    | some h2 =>
      change Val.bits 8 7 = Val.bits 8 8 at h2
      simp at h2

end MojoProofTest.SkelExec
