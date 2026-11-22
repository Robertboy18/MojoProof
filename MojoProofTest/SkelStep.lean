import MojoProof.Sem.SkelStep
import MojoProofTest.Close
import MojoProofTest.SkelExec
import MojoProofTest.Lockstep

/-!
# Instances and twins of T3b's step lemmas and of `Grid.FramesOk`

The frames: `retFn` is `define i8 @r(i8 %0) { ret i8 %0 }`, and under `labR` register 0 of every
function is payload and `@r` has a payload result. `retAt x d` starts `retFn` with the word `x` in
register 0, returning into register `d` of `caller`, a frame of `kernel #[]`; `retProg` is the
program of the two functions and `cRet` its context. For every context,
memory, `x` and `d`, the step returns `x` into register `d` (`ret_eval`), and for every `y` the
threads of `retAt x d` and `retAt y d` over `caller` are related by `Thread.Skel`, the first
meeting `Labels.MemNext`, as `retFn`'s block has no statement (`ret_skel`).

The instance of `step_skel`: the threads of `retAt 7 0` and `retAt 8 0` over `caller` meet every
premise in the context `cRet`, for every oracle of the second run and memory, so the steps are
related (`step_inst`).

The twins of `Labels.FramesOk`, each meeting the other premises of `step_skel`:
- `ret`: `retAt 7 2` returns into the skeleton register 2 of `caller`; every frame's function is
  `retProg`'s of its name, and the steps are not related: register 2 holds 7 in one and 8 in the
  other (`ret_twin`);
- `fn`: the frames `addAt 7` and `addAt 8` of `kernel #[addSt]` (MojoProofTest/SkelExec.lean) in
  the context of the program of `kernel #[]`, which passes `Labels.Ok` under `labP false`; the
  frames' function is not the module's function `kernel #[]` of its name and fails
  `Labels.funcOk`, and the steps are not related: register 2 holds 8 in one and 9 in the other
  (`fn_twin`).
`Labels.Ok` and `Labels.MemNext` reach `exec_skel` unchanged at the thread's next statement; their
twins are `exec_call_twin` and `exec_mem_twin`.

The instance of `step_framesOk` at a call: with no payload register (`Skeleton.lab0 false`),
`callProg` passes `Labels.Ok`, and for every memory `callSt` pushes a frame of `gFn` and the
frames after meet `Labels.FramesOk` (`call_framesOk`). Its twin, of `Labels.Ok`: with `@g`'s
result payload and no register payload (`labG`), `callProg` fails (O2), as `callSt` has no result
register, and the frames after fail `Labels.FramesOk`, as the callee returns into no register
(`call_framesOk_twin`).

The instance of `Grid.advance_skel`: for every family of oracles and memory, the one-thread grids
of `step_inst`'s threads are related by `Grid.SkelRel`, and thread 0's steps under `cR` and under
`cR` with those oracles agree (`advance_inst`).

The instance of `Grid.start_reach_framesOk`: for every launch, arguments, memory, address choice
and oracle, every grid reachable from the start of `callProg`'s kernel `kernel #[callSt]` meets
`Grid.FramesOk` with no payload (`start_framesOk`). Its twin, of the premise on the kernel:
`kernel #[]` has the name of `kernel #[callSt]`, and for every address choice and oracle its launch
in `callProg` on `Close.mem (some 5)` starts, but its grid does not meet `Grid.FramesOk`, though
`callProg` passes `Labels.Ok` (`start_framesOk_twin`).

The instance of `Thread.pending_skel`: under `lab0`, for every oracle of the second run and memory,
the threads of `stAt 5` and `stAt 6` (`store01`, MojoProofTest/SkelExec.lean) have the same
pending accesses, which are not none (`pending_inst`). Its twin, of `Labels.Ok`: `storeGep` stores
through `getelementptr` indexed by the payload register 0 and fails (O1); in its program's context,
on `memX 1`, the threads of `gepAt 5` and `gepAt 6` have pending stores at offsets 5 and 6 of
block 1 (`pending_twin`). `storeGep` is an AST form only: the parser refuses a local in a constant
expression.

The instance of `Grid.fire_skel`, on grids that a launch reaches: `bflyKern` is
`define void @k(ptr %0)` with `%1 = load i8, ptr %0`, `%2 = zext i8 %1 to i32` and
`%3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %2, i32 1, i32 31)`, the shuffle declared
with four `i32` parameters and `convergent` (`bflyFn`, which `Func.check` admits), and `bflyProg`
passes `Labels.Ok` under `labB`, every register but 0 payload (`bfly_ok`). `runB x ch o` is its
launch on two lanes on `memX x` with a pointer to block 1, address choice `ch` and oracle `o`
(`startB_eq`), and `waitB x ch` the grid after lane 0's and then lane 1's three steps, both lanes
waiting at the shuffle; for `x` 1 and 2, every address choice and every oracle it is reached
(`reachB`; the loads `ld0B` and `ld1B`, the other steps `ok0B` to `adv1B`). For every memory,
address choice and oracle the launch meets `Labels.MemOk` (`bfly_memOk`). With block 1 payload,
every address choice and every two oracles, `waitB 1 ch` and `waitB 2 ch` are related by
`Grid.SkelRel` (`Grid.start_skel`, then the steps of `Grid.skel_lockstep`, `lockstep_advs`), the
first meets `Grid.FramesOk` and `Grid.AtCalls`, and thread 0's fires agree (`fire_inst`); they
complete, register 3 of each lane holding the other lane's word, 1 in one run and 2 in the other
(`fireB_eq`). This instance covers one kernel and the bytes 1 and 2, for every address choice
and every two oracles. The grids hold the address choice (the addresses of the launch's
shared block), a free variable, and the elaborator does not cache the evaluation of terms with free
variables, so lane 1's steps exceed the heartbeat limit under `with_unfolding_all rfl`; each step is
checked by the kernel instead (the tactic kernel_rfl of this file, which closes `a = b` by
`Eq.refl a`), and `fire_inst` makes the contexts and grids variables (`generalize`) before
`Grid.fire_skel`, whose elaboration otherwise unfolds the start 14,179 times, past the limit.
With a variable byte the load is stuck, as the decoded word is not syntactically the byte.

The twins wait at hand-made states, which no step reaches: `shflG ats x m` is one thread at
`thread #[shflSt]` (MojoProofTest/Labels.lean), waiting at its butterfly shuffle with the exchanged
value `x` and lane operand 0 and the saved declaration `shflDecl ats` (no parameter and no
`convergent`), and `rng` is `range(i32 0, 6)`. For all contexts the fires of `shflG [rng] 5 m` and
`shflG [rng] 6 m` give 5 and `poison` and do not agree (`rng_fire`), and under `lab0` each twin
meets every premise but one:
- `Grid.AtCalls`: in the contexts of `shflProg []`, whose declaration has no
  attribute, the saved declaration is not the module's (`fire_atCalls_twin`);
- the common program: `Labels.Ok` and `Grid.FramesOk` hold under
  `shflProg []`, but the contexts' program is `shflProg [rng]` (`fire_prog_twin`);
- `Labels.Ok`: `shflProg [rng]` fails (O3) (`fire_ok_twin`);
- `Grid.FramesOk`: in `declProg`, whose function `k` is `kernel #[]` and which passes `Labels.Ok`,
  the frame's function is not the module's (`fire_framesOk_twin`).

The instance of `Grid.start_skel`: for every labelling, address choice and two oracles, the
launches of `kernel #[]` on `memX 1` and `memX 2` (MojoProofTest/Skeleton.lean), related with block
1 payload, start, and their grids are related (`start_inst`). Its twin, of `Mem.SkelEq`: with no
payload block the memories are not related, and the grids are not either, as block 1 keeps its
byte (`start_twin`).

The instance of `Grid.skel_lockstep` (T3b): with no payload register and block 1 payload, for every
address choice and oracle, the launch of `kernel #[]` on `memX 1` starts, and for all contexts that
differ from its contexts only in their oracles the relation is a lockstep bisimulation
(`lockstep_inst`); `Labels.MemOk` holds as every frame's function is `kernel #[]`, which has no
statement (`kernel_memOk`, for every payload blocks, memory, address choice and oracle). The twins
of its premises are those of the lemmas it composes: `call_framesOk_twin` and `fire_ok_twin`
(`Labels.Ok`), `start_framesOk_twin` (the kernel) and `store_ok`'s (`Labels.MemOk`,
MojoProofTest/Labels.lean).

The instance of `Grid.skel_run` (T3b's run): `runX x ch o` is the grid and contexts of the launch
of `kernel #[]` on `memX x` (`startX_eq`), and `doneX x ch o` its grid after its thread's step. By
evaluation, for every `x`, address choice and oracle, that step is a run of one step to a grid in
which every thread has returned, which is not bad and whose block 1 holds `x` at byte 0 (`obsX`),
and every run of one step ends there (`runX_run`); `memX x` has no pointer byte (`memX_bytesIn`).
With no payload register and block 1 payload, for every address choice and two oracles, the run
on `memX 1` gives the run on `memX 2` to `doneX 2 ch o₂`, related to `doneX 1 ch o₁`, with byte
2, and the second start is sound for `obsX` and that byte (`run_inst`). Its twin, of
`Mem.SkelEq`: with no payload block, no run of one step on `memX 2` ends at a grid related to
`doneX 1 ch o₁`, as block 1 keeps byte 0 (`run_twin`). This instance covers one kernel, which
returns at once, and payload in the caller's memory only.
-/

namespace MojoProofTest.SkelStep

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending MojoProofTest.Labels
open MojoProofTest.SkelExec
open MojoProofTest.Skeleton (memX blkX skel_pay)

-- `Array.all` recurses by well-founded recursion, so `rfl` cannot evaluate `Labels.Ok` without
-- this.
unseal Array.anyM.loop

open Lean Elab Tactic Meta in
/-- `kernel_rfl` closes a goal `a = b` by `Eq.refl a` without the elaborator's check that `a` and
`b` agree, which the kernel makes when the declaration is added (and refuses if they do not). The
steps of `bflyKern` at a variable address choice need it: their grids hold the choice, a free
variable, and the elaborator does not cache the evaluation of terms with free variables. -/
elab "kernel_rfl" : tactic => do
  let g ← getMainGoal
  let some (_, a, _) := (← whnfR (← g.getType)).eq? | throwError "kernel_rfl: not an equality"
  g.assign (← mkEqRefl a)
  replaceMainGoal []

/-- `define i8 @r(i8 %0) { ret i8 %0 }`. -/
def retFn : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .int 8, name := "r",
    params := [⟨.int 8, [], some 0⟩], group := none, names := #[],
    blocks := #[⟨0, #[], .ret (some ⟨.int 8, .loc 0⟩)⟩] }

/-- Register 0 of every function is payload, and `@r` has a payload result. -/
def labR : Labels := { reg := fun _ n => n == 0, ret := fun g => g == "r" }

/-- A frame at the start of `retFn` whose register 0 holds the word `x`, returning into register
`d` of its caller. -/
def retAt (x : BitVec 8) (d : Nat) : Frame := { at0 retFn (fun _ => none) x with dest := some d }

/-- The caller, a frame at the start of `kernel #[]`. -/
def caller : Frame :=
  { fn := kernel #[], label := 0, pc := 0, regs := fun _ => none, prods := fun _ => none,
    allocas := [], dest := none }

/-- The program of `kernel #[]` and `retFn`, with the default layout. -/
def retProg : Program :=
  { module := { (default : Module) with funcs := #[kernel #[], retFn] }, sha256 := "",
    layout := {}, intrinsics := [], kernels := ["k"] }

/-- `ctxOf`'s context with program `retProg`. -/
def cRet : Ctx := { ctxOf retFn with prog := retProg }

/-- For every context, memory, word `x` and register `d`, `retAt x d` over `caller` returns `x` into
register `d` of `caller`. -/
theorem ret_eval (c : Ctx) (m : Mem) (x : BitVec 8) (d : Nat) :
    step c ⟨[retAt x d, caller], 0⟩ m =
      .ok (.next ⟨[{ caller.set (some d) (some (.bits 8 x)) none with pc := 1 }], 1⟩ m) :=
  rfl

/-- For every register `d` and words `x` and `y`, the threads `retAt x d` over `caller` and
`retAt y d` over `caller` are related by `Thread.Skel` under `labR`, and the first meets
`Labels.MemNext` (its frame has no statement). -/
theorem ret_skel (d : Nat) (x y : BitVec 8) (c : Ctx) (m : Mem) :
    Thread.Skel labR ⟨[retAt x d, caller], 0⟩ ⟨[retAt y d, caller], 0⟩ ∧
      labR.MemNext (fun _ => False) c m ⟨[retAt x d, caller], 0⟩ := by
  refine ⟨⟨rfl, .cons ⟨rfl, (at0_skel (lab := labR) (fn := retFn) rfl (fun _ => none) x y).regs,
    fun _ => .none⟩ (.cons ⟨rfl, fun _ => .none, fun _ => .none⟩ .nil)⟩, ?_⟩
  intro f rest b st h1 h2 h3
  cases h1
  cases h2
  cases h3

/-- The instance of `step_skel`: for every oracle `o` of the second run and memory, `retAt 7 0`
over `caller` and `retAt 8 0` over `caller` meet every premise under `labR` in the context `cRet`
(`Labels.FramesOk`: the frames' functions are `retProg`'s, and `@r` returns into register 0, a
payload register) and give results related by `Step.Skel`. -/
theorem step_inst (o : Nat → Nat) (m : Mem) :
    labR.FramesOk retProg [retAt 7 0, caller] ∧
    Except.Rel (Step.Skel labR (fun _ => False) false)
      (step cRet ⟨[retAt 7 0, caller], 0⟩ m)
      (step { cRet with oracle := o } ⟨[retAt 8 0, caller], 0⟩ m) := by
  have hw : labR.FramesOk retProg [retAt 7 0, caller] :=
    ⟨by simp only [List.forall_mem_cons]; exact ⟨rfl, rfl, fun _ h => nomatch h⟩,
      .cons_cons (fun _ => rfl) (.singleton _)⟩
  exact ⟨hw, step_skel (ret_skel 0 7 8 cRet m).1 (Mem.SkelEq.refl _ m) rfl hw
    (ret_skel 0 7 8 cRet m).2⟩

/-- The twin of `Labels.FramesOk`'s `ret`: with `retAt 7 2` returning into register 2 of
`caller`, a skeleton register, `retProg` passes `Labels.Ok`, for every memory the threads over
`caller` of `retAt 7 2` and `retAt 8 2` are related by `Thread.Skel` and the first meets
`Labels.MemNext` (`ret_skel`), and every frame's function is `retProg`'s of its name, but
`Labels.FramesOk` fails, and the steps give results that `Step.Skel` does not relate: register 2
of `caller` holds 7 in one and 8 in the other. -/
theorem ret_twin (m : Mem) : Labels.Ok retProg labR = true ∧
    (Thread.Skel labR ⟨[retAt 7 2, caller], 0⟩ ⟨[retAt 8 2, caller], 0⟩ ∧
      labR.MemNext (fun _ => False) cRet m ⟨[retAt 7 2, caller], 0⟩) ∧
    (∀ f ∈ [retAt 7 2, caller], retProg.module.funcs.find? (·.name == f.fn.name) = some f.fn) ∧
    ¬ labR.FramesOk retProg [retAt 7 2, caller] ∧
    ¬ Except.Rel (Step.Skel labR (fun _ => False) false)
      (step cRet ⟨[retAt 7 2, caller], 0⟩ m)
      (step cRet ⟨[retAt 8 2, caller], 0⟩ m) := by
  refine ⟨rfl, ret_skel 2 7 8 _ m,
    by simp only [List.forall_mem_cons]; exact ⟨rfl, rfl, fun _ h => nomatch h⟩, fun h => ?_,
    fun h => ?_⟩
  · have hc := h.ret
    rw [List.isChain_cons_cons] at hc
    exact absurd (hc.1 rfl) (by decide)
  · rw [ret_eval, ret_eval] at h
    cases h with
    | ok h =>
      have h2 : Option.Rel (Labels.Rel false Val.Skel) (some (Val.bits 8 7))
        (some (Val.bits 8 8)) := (List.forall₂_cons.1 h.1.frames).1.regs 2
      cases h2 with
      | some h2 =>
        change Val.bits 8 7 = Val.bits 8 8 at h2
        simp at h2

/-- The twin of `Labels.FramesOk`'s `fn`: in the context of the program of `kernel #[]`, which
passes `Labels.Ok` under `labP false`, the threads of `addAt 7` and `addAt 8` are related by
`Thread.Skel` and meet `Labels.MemNext`, but their function `kernel #[addSt]` is not the module's
function `kernel #[]` of its name `k` and fails `Labels.funcOk`, so `Labels.FramesOk` fails, and
for every memory their steps give results that `Step.Skel` does not relate (`exec_twin`). -/
theorem fn_twin (m : Mem) : Labels.Ok (.ofFunc (kernel #[])) (labP false) = true ∧
    Thread.Skel (labP false) ⟨[addAt 7], 0⟩ ⟨[addAt 8], 0⟩ ∧
    (labP false).MemNext (fun _ => False) (ctxOf (kernel #[])) m ⟨[addAt 7], 0⟩ ∧
    (labP false).funcOk (.ofFunc (kernel #[])) (addAt 7).fn = false ∧
    ¬ (labP false).FramesOk (.ofFunc (kernel #[])) [addAt 7] ∧
    ¬ Except.Rel (Step.Skel (labP false) (fun _ => False) false)
      (step (ctxOf (kernel #[])) ⟨[addAt 7], 0⟩ m)
      (step (ctxOf (kernel #[])) ⟨[addAt 8], 0⟩ m) := by
  refine ⟨rfl, ⟨rfl, .cons (at0_skel rfl _ 7 8) .nil⟩, ?_, rfl,
    fun h => absurd (h.funcOk rfl _ List.mem_cons_self) (by decide), fun h => ?_⟩
  · intro f rest b st h1 h2 h3
    cases h1
    cases h2
    cases h3
    trivial
  · have e : ∀ x : BitVec 8, step (ctxOf (kernel #[])) ⟨[addAt x], 0⟩ m =
        .ok (.next ⟨[{ (addAt x).set (some 2) (some (.bits 8 (x + 1))) none with pc := 1 }], 1⟩
          m) := fun _ => rfl
    rw [e, e] at h
    cases h with
    | ok h =>
      have h2 : Option.Rel (Labels.Rel false Val.Skel) (some (Val.bits 8 8))
        (some (Val.bits 8 9)) := (List.forall₂_cons.1 h.1.frames).1.regs 2
      cases h2 with
      | some h2 =>
        change Val.bits 8 8 = Val.bits 8 9 at h2
        simp at h2

/-- The contexts of `retProg`: every thread number has `cRet`. -/
def cR : Nat → Ctx := fun _ => cRet

/-- The instance of `Grid.advance_skel`: for every family of oracles `o` and memory, the one-thread
grids of `step_inst`'s threads are related by `Grid.SkelRel`, and thread 0's steps under `cR` and
under `cR` with oracles `o` agree. -/
theorem advance_inst (o : Nat → Nat → Nat) (m : Mem) :
    Grid.SkelRel labR (fun _ => False) ⟨#[.run ⟨[retAt 7 0, caller], 0⟩], m⟩
      ⟨#[.run ⟨[retAt 8 0, caller], 0⟩], m⟩ ∧
    Grid.Agree (Grid.SkelRel labR (fun _ => False))
      (Grid.advance cR ⟨#[.run ⟨[retAt 7 0, caller], 0⟩], m⟩ 0)
      (Grid.advance (fun n => { cR n with oracle := o n }) ⟨#[.run ⟨[retAt 8 0, caller], 0⟩], m⟩
        0) := by
  have hg : Grid.SkelRel labR (fun _ => False) ⟨#[.run ⟨[retAt 7 0, caller], 0⟩], m⟩
      ⟨#[.run ⟨[retAt 8 0, caller], 0⟩], m⟩ := by
    refine ⟨fun j => ?_, Mem.SkelEq.refl _ m⟩
    rcases j with _ | j
    · exact .some (ret_skel 0 7 8 cRet m).1
    · simp only [List.getElem?_toArray, List.getElem?_cons_succ, List.getElem?_nil]
      exact .none
  refine ⟨hg, Grid.advance_skel (fun _ => rfl) hg 0 rfl (fun t ht => ?_) (fun n t ht => ?_)⟩
  · cases ht
    exact (step_inst (fun _ => 0) m).1
  · rcases n with _ | n
    · cases ht
      exact (ret_skel 0 7 8 _ m).2
    · simp only [List.getElem?_toArray, List.getElem?_cons_succ, List.getElem?_nil] at ht
      cases ht

/-- The instance of `step_framesOk` at a call: with no payload (`Skeleton.lab0 false`), `callProg`
passes `Labels.Ok`, the frame of `kernel #[callSt]` meets `Labels.FramesOk`, and for every memory,
`callSt` steps to frames with the callee frame of `gFn` pushed, which meet it. -/
theorem call_framesOk (m : Mem) : Labels.Ok callProg (Skeleton.lab0 false) = true ∧
    (Skeleton.lab0 false).FramesOk callProg [at0 (kernel #[callSt]) (fun _ => none) 1] ∧
    ∃ t' m', step cC ⟨[at0 (kernel #[callSt]) (fun _ => none) 1], 0⟩ m = .ok (.next t' m') ∧
      t'.frames.map (·.fn.name) = ["g", "k"] ∧
        (Skeleton.lab0 false).FramesOk callProg t'.frames := by
  have hw : (Skeleton.lab0 false).FramesOk callProg [at0 (kernel #[callSt]) (fun _ => none) 1] :=
    ⟨by simp only [List.forall_mem_cons]; exact ⟨rfl, fun _ h => nomatch h⟩, .singleton _⟩
  exact ⟨rfl, hw, _, _, rfl, rfl,
    step_framesOk (c := cC) (m := m)
      (t := ⟨[at0 (kernel #[callSt]) (fun _ => none) 1], 0⟩) rfl hw rfl⟩

/-- No register is payload, and `@g` has a payload result. -/
def labG : Labels := { reg := fun _ _ => false, ret := fun g => g == "g" }

/-- The twin of `step_framesOk`'s `Labels.Ok`: under `labG`, `callProg` fails it ((O2): `callSt`
has no result register, but `@g` has a payload result), the frame of `kernel #[callSt]` meets
`Labels.FramesOk`, and for every memory, `callSt` steps to frames with the callee frame of `gFn`
pushed, which fail it, as the callee returns into no register. -/
theorem call_framesOk_twin (m : Mem) : Labels.Ok callProg labG = false ∧
    labG.FramesOk callProg [at0 (kernel #[callSt]) (fun _ => none) 1] ∧
    ∃ t' m', step cC ⟨[at0 (kernel #[callSt]) (fun _ => none) 1], 0⟩ m = .ok (.next t' m') ∧
      t'.frames.map (·.fn.name) = ["g", "k"] ∧ ¬ labG.FramesOk callProg t'.frames :=
  ⟨rfl, ⟨by simp only [List.forall_mem_cons]; exact ⟨rfl, fun _ h => nomatch h⟩, .singleton _⟩,
    _, _, rfl, rfl, fun h => absurd ((List.isChain_cons_cons.1 h.ret).1 rfl) (by decide)⟩

/-- The instance of `Grid.start_reach_framesOk`: for every launch, arguments, memory, address
choice and oracle, if the launch of `callProg`'s kernel `kernel #[callSt]` starts, every grid
reachable from its grid meets `Grid.FramesOk` with no payload (`Skeleton.lab0 false`). -/
theorem start_framesOk {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start callProg (kernel #[callSt]) L args m ch oracle = .ok (g, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') :
    g'.FramesOk (Skeleton.lab0 false) callProg :=
  Grid.start_reach_framesOk h rfl rfl hr

/-- The twin of `Grid.start_reach_framesOk`'s premise on the kernel: `kernel #[]` has the
name of `callProg`'s kernel `kernel #[callSt]`, and for every address choice and oracle its launch
in `callProg` on `Close.mem (some 5)` starts, but its grid does not meet `Grid.FramesOk` with no
payload, though `callProg` passes `Labels.Ok`: the frame's function is `kernel #[]`, and the
module's function of its name is `kernel #[callSt]`. -/
theorem start_framesOk_twin (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    Labels.Ok callProg (Skeleton.lab0 false) = true ∧
    callProg.module.funcs.find? (·.name == (kernel #[]).name) = some (kernel #[callSt]) ∧
    ∃ g c, Grid.start callProg (kernel #[]) .one [] (Close.mem (some 5)) ch oracle = .ok (g, c) ∧
      ¬ g.FramesOk (Skeleton.lab0 false) callProg := by
  have h : Grid.start callProg (kernel #[]) .one [] (Close.mem (some 5)) ch oracle =
    .ok (_, _) := rfl
  have hk : callProg.module.funcs.find? (·.name == (kernel #[]).name) = some (kernel #[callSt]) :=
    rfl
  refine ⟨rfl, hk, _, _, h, fun hg => ?_⟩
  have h0 : callProg.module.funcs.find? (·.name == (kernel #[]).name) = some (kernel #[]) :=
    Labels.FramesOk.fn (hg 0 _ rfl) _ List.mem_cons_self
  exact absurd (congrArg (fun f : Func => f.blocks[0]?.map (·.stmts.size))
    (Option.some.inj (hk.symm.trans h0))) (by decide)

/-- The instance of `Thread.pending_skel`: under `lab0` (register 0 payload), the program of
`kernel #[store01]` passes `Labels.Ok`, the thread of `stAt 5` meets `Labels.FramesOk`, and for
every oracle `o` of the second run and memory, the pending accesses of the threads of `stAt 5`
and `stAt 6` (related by `at0_skel`) are equal and not empty: the store to block 1. -/
theorem pending_inst (o : Nat → Nat) (m : Mem) :
    Labels.Ok (.ofFunc (kernel #[store01])) lab0 = true ∧
    lab0.FramesOk (.ofFunc (kernel #[store01])) [stAt 5] ∧
    Thread.pending { ctxOf (kernel #[store01]) with oracle := o } ⟨[stAt 6], 0⟩ m =
      Thread.pending (ctxOf (kernel #[store01])) ⟨[stAt 5], 0⟩ m ∧
    Thread.pending (ctxOf (kernel #[store01])) ⟨[stAt 5], 0⟩ m ≠ [] := by
  have hw : lab0.FramesOk (.ofFunc (kernel #[store01])) [stAt 5] :=
    ⟨by simp only [List.forall_mem_cons]; exact ⟨rfl, fun _ h => nomatch h⟩, .singleton _⟩
  exact ⟨rfl, hw, Thread.pending_skel ⟨rfl, .cons (at0_skel rfl _ 5 6) .nil⟩
    (Mem.SkelEq.refl (fun _ => False) m) rfl hw, List.cons_ne_nil _ _⟩

/-- The AST of `store i8 %0, ptr getelementptr (i8, ptr %1, i8 %0)`: a store through a constant
`getelementptr` whose index is register 0. It is not LLVM IR (a constant expression has constant
operands), and the parser refuses its text; `Labels.Ok` and `Thread.pending` read the AST. -/
def storeGep : Stmt :=
  { res := none, inst := .store false ⟨.int 8, .loc 0⟩
      ⟨.ptr 0, .gep {} (.int 8) ⟨.ptr 0, .loc 1⟩ [⟨.int 8, .loc 0⟩]⟩ none }

/-- A frame at the start of `kernel #[storeGep]` whose register 0 holds the word `x` and register
1 a pointer to block 1. -/
def gepAt (x : BitVec 8) : Frame :=
  at0 (kernel #[storeGep]) (fun n => if n = 1 then some (.ptr ⟨1, 0⟩) else none) x

/-- The twin of `Thread.pending_skel`'s `Labels.Ok`: under `lab0`, `storeGep` fails
`Labels.stmtOk` ((O1): its pointer operand mentions the payload register 0), so the program of
`kernel #[storeGep]` fails `Labels.Ok`; the threads of `gepAt 5` and `gepAt 6` are related by
`Thread.Skel` and the first meets `Labels.FramesOk`, but in the context of that program their
pending accesses on `memX 1` differ: the stores to block 1 at offsets 5 and 6. A counterexample
over the AST only. -/
theorem pending_twin :
    lab0.stmtOk (.ofFunc (kernel #[storeGep])) (kernel #[storeGep]) storeGep = false ∧
    Labels.Ok (.ofFunc (kernel #[storeGep])) lab0 = false ∧
    Thread.Skel lab0 ⟨[gepAt 5], 0⟩ ⟨[gepAt 6], 0⟩ ∧
    lab0.FramesOk (.ofFunc (kernel #[storeGep])) [gepAt 5] ∧
    Thread.pending (ctxOf (kernel #[storeGep])) ⟨[gepAt 6], 0⟩ (memX 1) ≠
      Thread.pending (ctxOf (kernel #[storeGep])) ⟨[gepAt 5], 0⟩ (memX 1) := by
  refine ⟨rfl, rfl, ⟨rfl, .cons (at0_skel rfl _ 5 6) .nil⟩,
    ⟨by simp only [List.forall_mem_cons]; exact ⟨rfl, fun _ h => nomatch h⟩, .singleton _⟩, ?_⟩
  have e5 : Thread.pending (ctxOf (kernel #[storeGep])) ⟨[gepAt 5], 0⟩ (memX 1) =
      [Event.access
        { who := ⟨0, 0⟩, ptr := ⟨1, 5⟩, len := 1, write := true, atomic := none,
          invariant := false }]
      := rfl
  have e6 : Thread.pending (ctxOf (kernel #[storeGep])) ⟨[gepAt 6], 0⟩ (memX 1) =
      [Event.access
        { who := ⟨0, 0⟩, ptr := ⟨1, 6⟩, len := 1, write := true, atomic := none,
          invariant := false }]
      := rfl
  rw [e5, e6]
  decide

/-- One thread at `thread #[shflSt]` (MojoProofTest/Labels.lean), waiting at its butterfly shuffle
declared by `shflDecl ats`, with the full mask, the exchanged value `x`, lane operand 0 (the lane
itself) and clamp 31, on memory `m`. -/
def shflG (ats : List Attr) (x : BitVec 32) (m : Mem) : Grid :=
  { threads := #[.wait (thread #[shflSt]) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 x, .bits 32 0, .bits 32 31] (shflDecl ats)], mem := m }

/-- The contexts of program `p`: every thread number has `ctxOf`'s context with program `p`. -/
def cP (p : Program) : Nat → Ctx := fun _ => { ctxOf (kernel #[shflSt]) with prog := p }

/-- `range(i32 0, 6)`: 5 is in it and 6 is not. -/
def rng : Attr := .range (.int 32) 0 6

/-- The program of `kernel #[]` and `shflDecl [rng]`, the declaration as `shfl.sync.bfly`: its
function `k` is not `kernel #[shflSt]`. -/
def declProg : Program :=
  { shflProg [rng] with
    module := { (default : Module) with funcs := #[kernel #[], shflDecl [rng]] } }

/-- `shflG` has no thread past thread 0. -/
theorem shflG_succ (ats : List Attr) (x : BitVec 32) (m : Mem) (n : Nat) :
    (shflG ats x m).threads[n + 1]? = none := by
  simp [shflG]

/-- For every result attributes and memory, `shflG ats 5` and `shflG ats 6` are related by
`Grid.SkelRel` under `lab0`: the exchanged values differ, and the result register 0 is payload. -/
theorem shflG_skel (ats : List Attr) (m : Mem) :
    (shflG ats 5 m).SkelRel lab0 (fun _ => False) (shflG ats 6 m) := by
  refine ⟨fun n => ?_, Mem.SkelEq.refl _ m⟩
  rcases n with _ | n
  · exact .some ⟨.refl _ _, rfl, rfl, rfl⟩
  · rw [shflG_succ, shflG_succ]
    exact .none

/-- For all result attributes `ats` and `ats'`, words and memories, `shflG ats x m` meets
`Grid.FramesOk` under `lab0` and `shflProg ats'`, whose function `k` is `kernel #[shflSt]`. -/
theorem shflG_framesOk (ats ats' : List Attr) (x : BitVec 32) (m : Mem) :
    (shflG ats x m).FramesOk lab0 (shflProg ats') := by
  intro n s h
  rcases n with _ | n
  · cases h
    exact ⟨by simp only [thread, List.forall_mem_cons]; exact ⟨rfl, fun _ h => nomatch h⟩,
      .singleton _⟩
  · rw [shflG_succ] at h
    cases h

/-- For all result attributes, words and memories, `shflG ats x m` meets `Grid.AtCalls` in the
contexts of every program whose module's function of the shuffle's name is `shflDecl ats` and
whose intrinsic of that name is `shfl.sync.bfly`. -/
theorem shflG_atCalls {ats : List Attr} {p : Program} (x : BitVec 32) (m : Mem)
    (hf : p.module.funcs.find? (·.name == "llvm.nvvm.shfl.sync.bfly.i32") = some (shflDecl ats))
    (hi : p.intrinsics.lookup "llvm.nvvm.shfl.sync.bfly.i32" = some (.shfl .bfly)) :
    (shflG ats x m).AtCalls (cP p) := by
  intro n s h
  rcases n with _ | n
  · cases h
    exact ⟨_, _, _, _, _, _, _, _, rfl, rfl, rfl, rfl, hf, rfl, hi⟩
  · rw [shflG_succ] at h
    cases h

/-- `declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #0`, attribute group 0 being
`convergent`: a declaration of the butterfly shuffle that `Func.check` admits. -/
def bflyFn : Func :=
  { shflDecl [] with params := List.replicate 4 ⟨.int 32, [], none⟩, group := some 0 }

/-- `%1 = load i8, ptr %0`. -/
def ldSt : Stmt := { res := some 1, inst := .load false (.int 8) ⟨.ptr 0, .loc 0⟩ none }

/-- `%2 = zext i8 %1 to i32`. -/
def zextSt : Stmt := { res := some 2, inst := .cast .zext ⟨.int 8, .loc 1⟩ (.int 32) }

/-- `%3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %2, i32 1, i32 31)`: the full mask,
the exchanged value `%2`, lane operand 1 (lanes 0 and 1 swap) and clamp 31. -/
def bflySt : Stmt :=
  { res := some 3, inst := .call {} (.int 32) (.fn "llvm.nvvm.shfl.sync.bfly.i32")
      [(⟨.int 32, .int (-1)⟩, []), (⟨.int 32, .loc 2⟩, []), (⟨.int 32, .int 1⟩, []),
        (⟨.int 32, .int 31⟩, [])] }

/-- The kernel `define void @k(ptr %0)`: `ldSt`, `zextSt`, `bflySt`, then `ret void`. -/
def bflyKern : Func :=
  { kernel #[ldSt, zextSt, bflySt] with params := [⟨.ptr 0, [], some 0⟩] }

/-- The program of `bflyKern` and `bflyFn`, the declaration as the intrinsic `shfl.sync.bfly`,
with attribute group 0 `convergent`. -/
def bflyProg : Program :=
  { shflProg [] with
    module := { (default : Module) with
      funcs := #[bflyKern, bflyFn], attrGroups := #[(0, [.flag "convergent"])] } }

/-- Every register but 0, the pointer, is payload; no result is. -/
def labB : Labels := { reg := fun _ r => r != 0, ret := fun _ => false }

/-- `bflyProg` passes `Labels.Ok` under `labB`: the load's pointer is skeleton, and the shuffle's
exchanged value, its only payload operand, goes to the payload register 3 of a declaration with no
`range`. -/
theorem bfly_ok : Labels.Ok bflyProg labB = true := rfl

/-- The grid and contexts of the launch of `bflyKern` on two lanes (`Confluence.two`) on `memX x`
with a pointer to block 1, address choice `ch` and oracle `o` (by default 0). -/
def runB (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat := fun _ _ => 0) :
    Grid × (Nat → Ctx) :=
  match Grid.start bflyProg bflyKern Confluence.two [.ptr ⟨1, 0⟩] (memX x) ch o with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨bflyProg, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- For every `x`, address choice `ch` and oracle `o`, the launch of `bflyKern` on `memX x` with
`ch` and `o` starts, at `runB x ch o`, whose grid is `runB x ch`'s. -/
theorem startB_eq (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Grid.start bflyProg bflyKern Confluence.two [.ptr ⟨1, 0⟩] (memX x) ch o =
      .ok ((runB x ch o).1, (runB x ch o).2) ∧ (runB x ch o).1 = (runB x ch).1 :=
  ⟨rfl, rfl⟩

/-- Grid `g` after thread `n`'s load into register 1 of `len` bytes from byte 0 of block 1 under
contexts `c`, written out: the value `v` in register 1, and the read logged. -/
def afterLd (c : Nat → Ctx) (g : Grid) (n : Nat) (v : Val) (len : Nat) : Grid :=
  match g.threads[n]? with
  | some (Status.run ⟨f :: rest, k⟩) =>
    { threads := g.threads.set! n
        (.run ⟨{ f.set (some 1) (some v) none with pc := f.pc + 1 } :: rest, k + 1⟩),
      mem := g.mem.log (.access ⟨(c n).who, ⟨1, 0⟩, len, false, none, false⟩) }
  | _ => g

/-- `runB x ch`'s grid after lane 0's load. -/
def g1B (x : BitVec 8) (ch : Nat → Nat) : Grid :=
  afterLd (runB x ch).2 (runB x ch).1 0 (.bits 8 x) 1

/-- `g1B x ch` after lane 0's `zext` and call: lane 0 waits at the shuffle. -/
def g3B (x : BitVec 8) (ch : Nat → Nat) : Grid :=
  Determinism.advs (runB x ch).2 (g1B x ch) [0, 0]

/-- `g3B x ch` after lane 1's load. -/
def g4B (x : BitVec 8) (ch : Nat → Nat) : Grid :=
  afterLd (runB x ch).2 (g3B x ch) 1 (.bits 8 x) 1

/-- `g4B x ch` after lane 1's `zext` and call: both lanes wait at the shuffle. -/
def waitB (x : BitVec 8) (ch : Nat → Nat) : Grid :=
  Determinism.advs (runB x ch).2 (g4B x ch) [1, 1]

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, lane 0's load under
`runB x ch o`'s contexts gives `g1B x ch`. The grids of `ld0B` to `fireB_eq` hold `ch`, so each
step is checked by the kernel (`kernel_rfl`). -/
theorem ld0B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    (runB x ch o).1.advance (runB x ch o).2 0 = .ok (some (g1B x ch)) := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, lane 1's load under
`runB x ch o`'s contexts gives `g4B x ch`. -/
theorem ld1B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    (g3B x ch).advance (runB x ch o).2 1 = .ok (some (g4B x ch)) := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, under `runB x ch o`'s contexts
lane 0's `zext` and call succeed. -/
theorem ok0B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Determinism.oks (runB x ch o).2 (g1B x ch) [0, 0] = true := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, under `runB x ch o`'s contexts
lane 0's `zext` and call give `g3B x ch`. -/
theorem adv0B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Determinism.advs (runB x ch o).2 (g1B x ch) [0, 0] = g3B x ch := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, under `runB x ch o`'s contexts
lane 1's `zext` and call succeed. -/
theorem ok1B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Determinism.oks (runB x ch o).2 (g4B x ch) [1, 1] = true := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, under `runB x ch o`'s contexts
lane 1's `zext` and call give `waitB x ch`. -/
theorem adv1B (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Determinism.advs (runB x ch o).2 (g4B x ch) [1, 1] = waitB x ch := by
  rcases hx with rfl | rfl <;> kernel_rfl

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, `waitB x ch` is reachable from
the grid of `runB x ch o`. -/
theorem reachB (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Relation.ReflTransGen (Grid.Step Confluence.two (runB x ch o).2) (runB x ch o).1
      (waitB x ch) := by
  have p₁ : Relation.ReflTransGen (Grid.Step Confluence.two (runB x ch o).2) (g1B x ch)
      (Determinism.advs (runB x ch o).2 (g1B x ch) [0, 0]) :=
    Path.exists_iff.1 ⟨_, Determinism.path_advs _ [0, 0] (ok0B x hx ch o) (.nil _)⟩
  have p₂ : Relation.ReflTransGen (Grid.Step Confluence.two (runB x ch o).2) (g4B x ch)
      (Determinism.advs (runB x ch o).2 (g4B x ch) [1, 1]) :=
    Path.exists_iff.1 ⟨_, Determinism.path_advs _ [1, 1] (ok1B x hx ch o) (.nil _)⟩
  rw [adv0B x hx ch o] at p₁
  rw [adv1B x hx ch o] at p₂
  exact .head ⟨0, .inl (ld0B x hx ch o)⟩ (p₁.trans (.head ⟨1, .inl (ld1B x hx ch o)⟩ p₂))

/-- Under `labB`, for every payload blocks, memory, address choice and oracle, the launch of
`bflyKern` meets `Labels.MemOk`: every reachable grid meets `Grid.FramesOk`, so every frame's
function is `bflyKern` (`bflyFn` has no block), whose only memory statement, the load, has a
payload result. -/
theorem bfly_memOk (pay : Nat → Prop) {m : Mem} {ch : Nat → Nat} {o : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx}
    (h : Grid.start bflyProg bflyKern Confluence.two [.ptr ⟨1, 0⟩] m ch o = .ok (g, c)) :
    labB.MemOk pay Confluence.two c g := by
  intro x hr n t ht f rest b st hf hb hst
  have e := Array.mem_of_find?_eq_some (Labels.FramesOk.fn
    (Grid.start_reach_framesOk (lab := labB) h bfly_ok rfl hr n _ ht) f
    (by rw [hf]; exact List.mem_cons_self))
  have e' : f.fn = bflyKern ∨ f.fn = bflyFn := by simpa [bflyProg] using e
  rcases e' with e' | e' <;> rw [e'] at hb ⊢
  · have hb' := Array.mem_of_find?_eq_some hb
    simp only [bflyKern, kernel, Array.mem_singleton] at hb'
    subst hb'
    generalize f.pc = p at hst
    match p, hst with
    | 0, hst =>
      obtain rfl : st = ldSt := (Option.some.inj hst).symm
      exact fun h => absurd h (by decide)
    | 1, hst =>
      obtain rfl : st = zextSt := (Option.some.inj hst).symm
      trivial
    | 2, hst =>
      obtain rfl : st = bflySt := (Option.some.inj hst).symm
      trivial
    | p + 3, hst => simp at hst
  · cases hb

/-- A step list that `Determinism.oks` accepts steps first by `Determinism.adv`, for every
contexts, grid, thread number and list. -/
theorem oks_cons {c : Nat → Ctx} {g : Grid} {n : Nat} {ns : List Nat}
    (h : Determinism.oks c g (n :: ns) = true) :
    g.advance c n = .ok (some (Determinism.adv c g n)) ∧
      Determinism.oks c (Determinism.adv c g n) ns = true := by
  simp only [Determinism.oks] at h
  split at h
  · rename_i g' e
    have ha : Determinism.adv c g n = g' := by simp only [Determinism.adv, e]
    rw [ha]
    exact ⟨e, h⟩
  · cases h

/-- A lockstep bisimulation relates the grids after the steps of threads `ns` from related grids,
when every step of both succeeds, for every launch, contexts and relation. -/
theorem lockstep_advs {L : Launch} {c₁ c₂ : Nat → Ctx} {S : Grid → Grid → Prop}
    (hS : Grid.Lockstep L c₁ c₂ S) :
    ∀ {x y : Grid} (ns : List Nat), S x y → Determinism.oks c₁ x ns = true →
      Determinism.oks c₂ y ns = true → S (Determinism.advs c₁ x ns) (Determinism.advs c₂ y ns)
  | _, _, [], h, _, _ => h
  | _, _, n :: ns, h, h₁, h₂ => by
    obtain ⟨e₁, h₁⟩ := oks_cons h₁
    obtain ⟨e₂, h₂⟩ := oks_cons h₂
    have ha := hS.advance h n
    rw [e₁, e₂] at ha
    exact lockstep_advs hS ns ha h₁ h₂

/-- `waitB x ch` after thread 0's fire. -/
def fireB (x : BitVec 8) (ch : Nat → Nat) : Grid :=
  match (waitB x ch).fire Confluence.two (runB x ch).2 0 with
  | .ok (some g) => g
  | _ => waitB x ch

/-- Register 3 of the first frame of thread `j` of `g`, if it runs. -/
def reg3 (g : Grid) (j : Nat) : Option Val :=
  match g.threads[j]? with
  | some (Status.run ⟨f :: _, _⟩) => f.regs 3
  | _ => none

/-- For `x` 1 and 2, every address choice `ch` and oracle `o`, thread 0's fire at `waitB x ch`
under `runB x ch o`'s contexts completes the shuffle, giving `fireB x ch`, in which register 3 of
both lanes holds the word `x`, the other lane's. -/
theorem fireB_eq (x : BitVec 8) (hx : x = 1 ∨ x = 2) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    (waitB x ch).fire Confluence.two (runB x ch o).2 0 = .ok (some (fireB x ch)) ∧
      reg3 (fireB x ch) 0 = some (.bits 32 (x.zeroExtend 32)) ∧
      reg3 (fireB x ch) 1 = some (.bits 32 (x.zeroExtend 32)) := by
  rcases hx with rfl | rfl <;>
  · refine ⟨?_, ?_, ?_⟩ <;> kernel_rfl

/-- **The instance of `Grid.fire_skel`**, on states that a launch reaches: with block 1 payload,
for every address choice `ch` and every two oracles `o₁` and `o₂`, `waitB 1 ch` and `waitB 2 ch`,
reached from the launches of `bflyKern` with `ch` on `memX 1` under `o₁` and `memX 2` under `o₂`
(`reachB`), are related by `Grid.SkelRel` under `labB` (by `Grid.start_skel` and the steps of
`Grid.skel_lockstep`, with `bfly_memOk`), the first meets `Grid.FramesOk` and `Grid.AtCalls`, and
thread 0's fires complete the shuffle of both lanes, register 3 of each lane holding the other
lane's word, 1 in one run and 2 in the other (`fireB_eq`), and agree. -/
theorem fire_inst (ch : Nat → Nat) (o₁ o₂ : Nat → Nat → Nat) :
    Relation.ReflTransGen (Grid.Step Confluence.two (runB 1 ch o₁).2) (runB 1 ch o₁).1
      (waitB 1 ch) ∧
    Relation.ReflTransGen (Grid.Step Confluence.two (runB 2 ch o₂).2) (runB 2 ch o₂).1
      (waitB 2 ch) ∧
    (waitB 1 ch).SkelRel labB (· = 1) (waitB 2 ch) ∧
    (waitB 1 ch).FramesOk labB bflyProg ∧ (waitB 1 ch).AtCalls (runB 1 ch o₁).2 ∧
    Grid.Agree (Grid.SkelRel labB (· = 1))
      ((waitB 1 ch).fire Confluence.two (runB 1 ch o₁).2 0)
      ((waitB 2 ch).fire Confluence.two (runB 2 ch o₂).2 0) := by
  have h := Grid.start_skel (lab := labB) skel_pay.1 bflyProg bflyKern Confluence.two
    [.ptr ⟨1, 0⟩] ch o₁ o₂
  rw [(startB_eq 1 ch o₁).1, (startB_eq 2 ch o₂).1] at h
  obtain ⟨h0, hc⟩ : (runB 1 ch o₁).1.SkelRel labB (· = 1) (runB 2 ch o₂).1 ∧
      ∀ n, (runB 2 ch o₂).2 n =
        { (runB 1 ch o₁).2 n with oracle := ((runB 2 ch o₂).2 n).oracle } := by
    cases h with
    | ok h => exact h
  have hS := Grid.skel_lockstep (lab := labB) (pay := (· = 1)) (startB_eq 1 ch o₁).1 bfly_ok rfl
    (bfly_memOk _ (startB_eq 1 ch o₁).1) hc
  have h1 := hS.advance ⟨.refl, h0⟩ 0
  rw [ld0B 1 (.inl rfl), ld0B 2 (.inr rfl)] at h1
  have h3 := lockstep_advs hS [0, 0] h1 (ok0B 1 (.inl rfl) ch o₁) (ok0B 2 (.inr rfl) ch o₂)
  rw [adv0B 1 (.inl rfl), adv0B 2 (.inr rfl)] at h3
  have h4 := hS.advance h3 1
  rw [ld1B 1 (.inl rfl), ld1B 2 (.inr rfl)] at h4
  have h6 := lockstep_advs hS [1, 1] h4 (ok1B 1 (.inl rfl) ch o₁) (ok1B 2 (.inr rfl) ch o₂)
  rw [adv1B 1 (.inl rfl), adv1B 2 (.inr rfl)] at h6
  have hr := reachB 1 (.inl rfl) ch o₁
  have hw := Grid.start_reach_framesOk (startB_eq 1 ch o₁).1 bfly_ok rfl hr
  have ha := Grid.start_reach_atCalls (startB_eq 1 ch o₁).1 hr
  have hp : ∀ n, ((runB 1 ch o₁).2 n).prog = bflyProg :=
    fun n => (Grid.start_ctx (startB_eq 1 ch o₁).1 n).1
  refine ⟨hr, reachB 2 (.inr rfl) ch o₂, h6.2, hw, ha, ?_⟩
  have hg := h6.2
  -- The contexts and grids as variables, so that no check unfolds the start.
  revert hc hw ha hp hg
  generalize (runB 1 ch o₁).2 = c₁
  generalize (runB 2 ch o₂).2 = c₂
  generalize waitB 1 ch = w₁
  generalize waitB 2 ch = w₂
  intro hc hw ha hp hg
  exact Grid.fire_skel hc hp bfly_ok hg hw ha 0

/-- For all contexts `c` and `c'` and memories `m`, thread 0's fires of `shflG [rng] 5 m` under
`c` and of `shflG [rng] 6 m` under `c'` complete the shuffle under the waiting declaration's
`range`, register 0 holding 5 in one and `poison` in the other, so they do not agree under
`Grid.SkelRel` with register 0 payload: the common conclusion of `Grid.fire_skel`'s twins. -/
theorem rng_fire (c c' : Nat → Ctx) (m : Mem) :
    (shflG [rng] 5 m).fire .one c 0 =
      .ok (some ⟨#[.run ((thread #[shflSt]).resume (some (.bits 32 5)))], m⟩) ∧
    (shflG [rng] 6 m).fire .one c' 0 =
      .ok (some ⟨#[.run ((thread #[shflSt]).resume (some .poison))], m⟩) ∧
    ¬ Grid.Agree (Grid.SkelRel lab0 (fun _ => False)) ((shflG [rng] 5 m).fire .one c 0)
      ((shflG [rng] 6 m).fire .one c' 0) := by
  have e₅ : (shflG [rng] 5 m).fire .one c 0 =
      .ok (some ⟨#[.run ((thread #[shflSt]).resume (some (.bits 32 5)))], m⟩) := rfl
  have e₆ : (shflG [rng] 6 m).fire .one c' 0 =
      .ok (some ⟨#[.run ((thread #[shflSt]).resume (some .poison))], m⟩) := rfl
  refine ⟨e₅, e₆, fun h => ?_⟩
  rw [e₅, e₆] at h
  have h' : Grid.SkelRel lab0 (fun _ => False)
      ⟨#[.run ((thread #[shflSt]).resume (some (.bits 32 5)))], m⟩
      ⟨#[.run ((thread #[shflSt]).resume (some .poison))], m⟩ := h
  have h0 : Thread.Skel lab0 ((thread #[shflSt]).resume (some (.bits 32 5)))
      ((thread #[shflSt]).resume (some .poison)) := by
    cases h'.threads 0 with
    | some h0 => exact h0
  have h2 : Option.Rel (Labels.Rel true Val.Skel) (some (Val.bits 32 5)) (some .poison) :=
    (List.forall₂_cons.1 h0.frames).1.regs 0
  cases h2 with
  | some h2 => simp [Labels.Rel, Val.Skel, Val.erase] at h2

/-- The twin of `Grid.fire_skel`'s `Grid.AtCalls`: in the contexts of
`shflProg []`, which passes `Labels.Ok` under `lab0`, for every memory `m` the grids
`shflG [rng] 5 m` and `shflG [rng] 6 m` are related by `Grid.SkelRel` and the first meets
`Grid.FramesOk`, but its thread waits with a declaration, `shflDecl [rng]`, that is not the
module's `shflDecl []`, so `Grid.AtCalls` fails, and thread 0's fires do not agree (`rng_fire`):
`resumeAll` applies the waiting declaration's `range`. -/
theorem fire_atCalls_twin (m : Mem) :
    Labels.Ok (shflProg []) lab0 = true ∧
    (shflG [rng] 5 m).SkelRel lab0 (fun _ => False) (shflG [rng] 6 m) ∧
    (shflG [rng] 5 m).FramesOk lab0 (shflProg []) ∧ ¬ (shflG [rng] 5 m).AtCalls (cP (shflProg [])) ∧
    ¬ Grid.Agree (Grid.SkelRel lab0 (fun _ => False))
      ((shflG [rng] 5 m).fire .one (cP (shflProg [])) 0)
      ((shflG [rng] 6 m).fire .one (cP (shflProg [])) 0) := by
  refine ⟨shfl_range_twin.1, shflG_skel _ m, shflG_framesOk _ _ 5 m, fun h => ?_,
    (rng_fire _ _ m).2.2⟩
  obtain ⟨_, _, _, _, _, _, _, _, h1, h2, h3, h4, h5, -⟩ := h 0 _ rfl
  cases h1
  cases h2
  cases h3
  cases h4
  exact absurd (congrArg (fun f : Func => f.retAttrs.length) (Option.some.inj h5)) (by decide)

/-- The twin of `Grid.fire_skel`'s common program: `shflProg []` passes
`Labels.Ok` under `lab0`, and for every memory `m` the grids `shflG [rng] 5 m` and
`shflG [rng] 6 m` are related by `Grid.SkelRel` and the first meets `Grid.FramesOk` under it and
`Grid.AtCalls` in the contexts of `shflProg [rng]`, whose declaration has `range`, but those
contexts' program is not `shflProg []`, and thread 0's fires do not agree (`rng_fire`). -/
theorem fire_prog_twin (m : Mem) :
    Labels.Ok (shflProg []) lab0 = true ∧ (cP (shflProg [rng]) 0).prog ≠ shflProg [] ∧
    (shflG [rng] 5 m).SkelRel lab0 (fun _ => False) (shflG [rng] 6 m) ∧
    (shflG [rng] 5 m).FramesOk lab0 (shflProg []) ∧
    (shflG [rng] 5 m).AtCalls (cP (shflProg [rng])) ∧
    ¬ Grid.Agree (Grid.SkelRel lab0 (fun _ => False))
      ((shflG [rng] 5 m).fire .one (cP (shflProg [rng])) 0)
      ((shflG [rng] 6 m).fire .one (cP (shflProg [rng])) 0) :=
  ⟨shfl_range_twin.1, fun h => absurd (congrArg
      (fun p : Program => p.module.funcs[1]?.map (·.retAttrs.length)) h) (by decide),
    shflG_skel _ m, shflG_framesOk _ _ 5 m, shflG_atCalls 5 m rfl rfl, (rng_fire _ _ m).2.2⟩

/-- The twin of `Grid.fire_skel`'s `Labels.Ok`: `shflProg [rng]` fails it under `lab0` ((O3): the
declaration of a shuffle with a payload result has `range`), and for every memory `m` the
grids `shflG [rng] 5 m` and `shflG [rng] 6 m` are related by `Grid.SkelRel` and the first meets
`Grid.FramesOk` and `Grid.AtCalls` in the contexts of `shflProg [rng]`, but thread 0's fires do not
agree (`rng_fire`). -/
theorem fire_ok_twin (m : Mem) :
    Labels.Ok (shflProg [rng]) lab0 = false ∧
    (shflG [rng] 5 m).SkelRel lab0 (fun _ => False) (shflG [rng] 6 m) ∧
    (shflG [rng] 5 m).FramesOk lab0 (shflProg [rng]) ∧
    (shflG [rng] 5 m).AtCalls (cP (shflProg [rng])) ∧
    ¬ Grid.Agree (Grid.SkelRel lab0 (fun _ => False))
      ((shflG [rng] 5 m).fire .one (cP (shflProg [rng])) 0)
      ((shflG [rng] 6 m).fire .one (cP (shflProg [rng])) 0) :=
  ⟨rfl, shflG_skel _ m, shflG_framesOk _ _ 5 m, shflG_atCalls 5 m rfl rfl, (rng_fire _ _ m).2.2⟩

/-- The twin of `Grid.fire_skel`'s `Grid.FramesOk`: `declProg` passes `Labels.Ok` under `lab0`
(its function `k` has no statement), and for every memory `m` the grids `shflG [rng] 5 m` and
`shflG [rng] 6 m` are related by `Grid.SkelRel` and the first meets `Grid.AtCalls` in the contexts
of `declProg`, but its frame's function `kernel #[shflSt]` is not the module's `kernel #[]`, so
`Grid.FramesOk` fails, and thread 0's fires do not agree (`rng_fire`). -/
theorem fire_framesOk_twin (m : Mem) :
    Labels.Ok declProg lab0 = true ∧
    (shflG [rng] 5 m).SkelRel lab0 (fun _ => False) (shflG [rng] 6 m) ∧
    ¬ (shflG [rng] 5 m).FramesOk lab0 declProg ∧ (shflG [rng] 5 m).AtCalls (cP declProg) ∧
    ¬ Grid.Agree (Grid.SkelRel lab0 (fun _ => False))
      ((shflG [rng] 5 m).fire .one (cP declProg) 0)
      ((shflG [rng] 6 m).fire .one (cP declProg) 0) := by
  refine ⟨rfl, shflG_skel _ m, fun h => ?_, shflG_atCalls 5 m rfl rfl, (rng_fire _ _ m).2.2⟩
  have hk : declProg.module.funcs.find? (·.name == (kernel #[shflSt]).name) = some (kernel #[]) :=
    rfl
  exact absurd (congrArg (fun f : Func => f.blocks[0]?.map (·.stmts.size))
    (Option.some.inj (hk.symm.trans (Labels.FramesOk.fn (h 0 _ rfl) _ List.mem_cons_self))))
    (by decide)

/-- `memX x` has no pointer byte, for every `x`. -/
theorem memX_bytesIn (x : BitVec 8) : (memX x).BytesIn (memX x).Known :=
  fun c b i p j hc _ hp => by
    simp only [memX] at hc
    split at hc
    · cases hc
      simp only [blkX] at hp
      split at hp <;> cases hp
    · cases hc

/-- The grid and contexts of the launch of `kernel #[]` on `memX x`, with address choice `ch` and
oracle `o`. -/
def runX (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat) : Grid × (Nat → Ctx) :=
  match Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX x) ch o with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨.ofFunc (kernel #[]), fun _ => none, ⟨fun _ _ => 0, 0⟩,
      ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩)

/-- For every `x`, address choice and oracle, the launch of `kernel #[]` on `memX x` starts, at
`runX x ch o`. -/
theorem startX_eq (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX x) ch o =
      .ok ((runX x ch o).1, (runX x ch o).2) :=
  rfl

/-- `runX x ch o`'s grid after its thread's step, its `ret void`. -/
def doneX (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat) : Grid :=
  Determinism.advs (runX x ch o).2 (runX x ch o).1 [0]

/-- Byte 0 of block 1, an observation that reads only the blocks. -/
def obsX (m : Mem) : Option MemByte := (m.blocks 1).map (·.bytes 0)

/-- For every `x`, address choice and oracle, by evaluation: the thread of `runX x ch o` returns
in one step, to `doneX x ch o`, in which every thread has returned, which is not bad and whose
block 1 holds `x` at byte 0, and every run of one step from `runX x ch o`'s grid ends there. -/
theorem runX_run (x : BitVec 8) (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    Path (Grid.Step .one (runX x ch o).2) 1 (runX x ch o).1 (doneX x ch o) ∧
      (doneX x ch o).Done ∧ ¬ (doneX x ch o).Bad .one (runX x ch o).2 ∧
      obsX (doneX x ch o).mem = some (.byte x) ∧
      ∀ z, Path (Grid.Step .one (runX x ch o).2) 1 (runX x ch o).1 z → z = doneX x ch o := by
  have hd : (doneX x ch o).Done := rfl
  refine ⟨Determinism.path_advs _ [0] rfl (.nil _), hd, ?_, rfl, fun z p => ?_⟩
  · rintro (hf | hr | hk | hr)
    · exact done_not_faults hd hf
    · rw [show racy (doneX x ch o).mem.trace = false from rfl] at hr
      cases hr
    · rw [show kept (doneX x ch o).mem.trace = true from rfl] at hk
      cases hk
    · exact hd.not_raceEnabled hr
  · cases p with
    | cons s p =>
      cases p
      exact (Grid.step_one (by rfl) s).trans rfl

/-- With no payload register (`Skeleton.lab0 false`), for every payload blocks, memory, address
choice and oracle, the launch of `kernel #[]` meets `Labels.MemOk`: every reachable grid meets
`Grid.FramesOk`, so every frame's function is `kernel #[]`, which has no statement. -/
theorem kernel_memOk (pay : Nat → Prop) {m : Mem} {ch : Nat → Nat} {o : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx}
    (h : Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] m ch o = .ok (g, c)) :
    (Skeleton.lab0 false).MemOk pay .one c g := by
  intro x hr n t ht f rest b st hf hb hst
  have e := Array.mem_of_find?_eq_some (Labels.FramesOk.fn
    (Grid.start_reach_framesOk (lab := Skeleton.lab0 false) h rfl rfl hr n _ ht) f
    (by rw [hf]; exact List.mem_cons_self))
  simp only [Program.ofFunc, Array.mem_singleton] at e
  rw [e] at hb
  have hb' := Array.mem_of_find?_eq_some hb
  simp only [kernel, Array.mem_singleton] at hb'
  subst hb'
  simp at hst

/-- The instance of `Grid.start_skel`: for every labelling, address choice and two oracles, the
launches of `kernel #[]` on `memX 1` and `memX 2`, related with block 1 payload (`skel_pay`),
start, and their grids are related by `Grid.SkelRel`. -/
theorem start_inst (lab : Labels) (ch : Nat → Nat) (o₁ o₂ : Nat → Nat → Nat) :
    ∃ g₁ c₁ g₂ c₂,
      Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX 1) ch o₁ = .ok (g₁, c₁) ∧
      Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX 2) ch o₂ = .ok (g₂, c₂) ∧
      g₁.SkelRel lab (· = 1) g₂ := by
  have h := Grid.start_skel (lab := lab) skel_pay.1 (.ofFunc (kernel #[])) (kernel #[]) .one
    [] ch o₁ o₂
  rw [startX_eq, startX_eq] at h
  cases h with
  | ok h => exact ⟨_, _, _, _, startX_eq 1 ch o₁, startX_eq 2 ch o₂, h.1⟩

/-- The twin of `Grid.start_skel`'s premise `Mem.SkelEq`: with no payload block, `memX 1` and
`memX 2` are not related (`skel_pay`), and for every labelling, address choice and two oracles the
launches of `kernel #[]` on them start, but their grids are not related by `Grid.SkelRel`: block
1 keeps its byte 0. -/
theorem start_twin (lab : Labels) (ch : Nat → Nat) (o₁ o₂ : Nat → Nat → Nat) :
    ¬ (memX 1).SkelEq (fun _ => False) (memX 2) ∧ ∃ g₁ c₁ g₂ c₂,
      Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX 1) ch o₁ = .ok (g₁, c₁) ∧
      Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX 2) ch o₂ = .ok (g₂, c₂) ∧
      ¬ g₁.SkelRel lab (fun _ => False) g₂ := by
  refine ⟨skel_pay.2, _, _, _, _, startX_eq 1 ch o₁, startX_eq 2 ch o₂, fun h => ?_⟩
  have e := (h.mem.blocks 1).map_eq (f := (·.bytes 0)) fun hB => hB.same not_false 0
  change some (MemByte.byte 1) = some (MemByte.byte 2) at e
  exact absurd e (by decide)

/-- The instance of `Grid.skel_lockstep`: with no payload register (`Skeleton.lab0 false`) and
block 1 payload, for every address choice and oracle, the launch of `kernel #[]` on `memX 1`
starts, and for all contexts that differ from its contexts only in their oracles, the relation is
a lockstep bisimulation. `Labels.MemOk` holds by `kernel_memOk`. -/
theorem lockstep_inst (ch : Nat → Nat) (o : Nat → Nat → Nat) :
    ∃ g₁ c₁, Grid.start (.ofFunc (kernel #[])) (kernel #[]) .one [] (memX 1) ch o = .ok (g₁, c₁) ∧
      ∀ c₂ : Nat → Ctx, (∀ n, c₂ n = { c₁ n with oracle := (c₂ n).oracle }) →
        Grid.Lockstep .one c₁ c₂ fun x y => Relation.ReflTransGen (Grid.Step .one c₁) g₁ x ∧
          x.SkelRel (Skeleton.lab0 false) (· = 1) y :=
  ⟨_, _, startX_eq 1 ch o, fun _ hc => Grid.skel_lockstep (lab := Skeleton.lab0 false)
    (startX_eq 1 ch o) rfl rfl (kernel_memOk _ (startX_eq 1 ch o)) hc⟩

/-- The instance of `Grid.skel_run` (T3b's run): with no payload register (`Skeleton.lab0 false`)
and block 1 payload, for every address choice and two oracles, the run of one step from the
launch of `kernel #[]` on `memX 1` to `doneX 1 ch o₁`, done and not bad (`runX_run`), gives a run
of one step from the launch on `memX 2`, whose memory differs only in the data byte 0 of block 1
(`skel_pay`). That run ends at `doneX 2 ch o₂` (every run of one step does), which is related to
`doneX 1 ch o₁` by `Grid.SkelRel` and holds the byte 2 at byte 0 of block 1, and the second
start's grid is sound for `obsX` and that byte. -/
theorem run_inst (ch : Nat → Nat) (o₁ o₂ : Nat → Nat → Nat) :
    (doneX 1 ch o₁).SkelRel (Skeleton.lab0 false) (· = 1) (doneX 2 ch o₂) ∧
      obsX (doneX 2 ch o₂).mem = some (.byte 2) ∧
      Grid.Sound .one (runX 2 ch o₂).2 (runX 2 ch o₂).1 obsX (· = .byte 2) := by
  obtain ⟨p₁, hd₁, hb₁, -, -⟩ := runX_run 1 ch o₁
  obtain ⟨g₂, c₂, z₂, e, p₂, -, -, hr, hs⟩ := Grid.skel_run (lab := Skeleton.lab0 false)
    (o₂ := o₂) (startX_eq 1 ch o₁) skel_pay.1 (memX_bytesIn 1) rfl rfl
    (kernel_memOk _ (startX_eq 1 ch o₁)) p₁ hd₁ hb₁
  rw [startX_eq] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e)
  obtain rfl := (runX_run 2 ch o₂).2.2.2.2 z₂ p₂
  have hy := (runX_run 2 ch o₂).2.2.2.1
  exact ⟨hr, hy, hs (obs := obsX) (R := (· = .byte 2)) (fun m m' h => by simp only [obsX, h])
    hy rfl⟩

/-- The twin of `Grid.skel_run`'s premise `Mem.SkelEq`: with no payload block, `memX 1` and
`memX 2` are not related (`skel_pay`). For every labelling, address choice and two oracles, the
other premises hold as in `run_inst` (`memX_bytesIn`, `kernel_memOk`, `runX_run`), but no run of
one step from the launch on `memX 2` ends at a grid related to `doneX 1 ch o₁` by
`Grid.SkelRel`: block 1 keeps byte 0, 1 in one and 2 in the other. -/
theorem run_twin (lab : Labels) (ch : Nat → Nat) (o₁ o₂ : Nat → Nat → Nat) :
    ¬ (memX 1).SkelEq (fun _ => False) (memX 2) ∧
      ∀ z, Path (Grid.Step .one (runX 2 ch o₂).2) 1 (runX 2 ch o₂).1 z →
        ¬ (doneX 1 ch o₁).SkelRel lab (fun _ => False) z := by
  refine ⟨skel_pay.2, fun z p h => ?_⟩
  obtain rfl := (runX_run 2 ch o₂).2.2.2.2 z p
  have e := (h.mem.blocks 1).map_eq (f := (·.bytes 0)) fun hB => hB.same not_false 0
  change obsX (doneX 1 ch o₁).mem = obsX (doneX 2 ch o₂).mem at e
  rw [(runX_run 1 ch o₁).2.2.2.1, (runX_run 2 ch o₂).2.2.2.1] at e
  exact absurd e (by decide)

end MojoProofTest.SkelStep
