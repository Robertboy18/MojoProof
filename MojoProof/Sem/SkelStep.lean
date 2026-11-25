import MojoProof.Sem.SkelExec
import MojoProof.Sem.Lockstep

/-!
# T3b (`Grid.start_skel`, `Grid.skel_lockstep`, `Grid.skel_run`), its step lemmas (`step_skel`,
`Grid.advance_skel`, `Grid.fire_skel`), `Grid.FramesOk` and `Thread.pending_skel`

docs/proofs/payload.md section T3b. One step of two threads related by `Thread.Skel`, on memories
related by `Mem.SkelEq`, in a context whose program passes `Labels.Ok` and under two oracles, gives
one fault or results related by `Step.Skel` (`step_skel`), if the first thread's frames meet
`Labels.FramesOk` and its next statement meets `Labels.MemAt` (`Labels.MemNext`):
- a statement by `exec_skel`; a call's callee frame takes the argument at the first parameter named
  `r` as register `r` (`Labels.Rel.params`), and the `norecurse` check reads only the frames'
  functions, which related frames share (`Frame.Skel.any_fn`);
- `br`, `condBr` and `switch` on a skeleton condition (`evalV_skel`) by `enter_skel`;
- `ret` of a skeleton operand by `evalV_skel` and `withAttrs_shape`, of a payload operand by
  `evalV_pay` and `withAttrs_skel`; the caller's register is payload when the callee's result is
  (`Labels.FramesOk`).

`Labels.FramesOk lab prog fs`, the invariant `step_skel` needs of a thread's frames `fs`: every
frame's function is the module's function of its name, so it passes `Labels.funcOk` when the
program passes `Labels.Ok` (`Labels.FramesOk.funcOk`), and a callee whose function has a payload
result returns into a payload register of its caller. A step that continues keeps it
(`step_framesOk`): a statement and a block entry keep a frame's function and destination register
(`exec_fn`, `enter_fn`), a call's function is the module's of the callee's name, with blocks
(`exec_call`), and (O2) makes the call's result register payload when its result is.

On grids, thread `n`'s steps in two grids related by `Grid.SkelRel` under contexts that differ
only in their oracles agree if thread `n`'s program passes `Labels.Ok`, its frames meet
`Labels.FramesOk` if it runs, and the first grid meets `Labels.MemAll` (`Grid.advance_skel`, with
`Option.Rel.set!`).

`Grid.FramesOk lab prog g`: every running or waiting thread of `g` has frames that meet
`Labels.FramesOk` under one program `prog` (`Status.FramesOk`). A thread's step (`Grid.advance`)
keeps it under contexts whose program is `prog`, if `prog` passes `Labels.Ok`
(`Grid.advance_framesOk`, by `step_framesOk`), and so does a fire (`Grid.fire_framesOk`, by
`Thread.resume_framesOk`), so it holds at every grid reachable from one that has it
(`Grid.reach_framesOk`). The grid of `Grid.start` has it if the kernel is the module's function of
its name (`Grid.start_framesOk`; from the start, `Grid.start_reach_framesOk`), which `Grid.start`
does not check.

The pending accesses of threads related by `Thread.Skel`, the first's frames meeting
`Labels.FramesOk`, on memories related by `Mem.SkelEq` in a context whose program passes
`Labels.Ok`, are equal under two oracles (`Thread.pending_skel`): (O1) makes a `load`'s, `store`'s
or `atomicrmw`'s pointer operand skeleton.

Thread `n`'s fires in two grids related by `Grid.SkelRel`, the first meeting `Grid.FramesOk` and
`Grid.AtCalls` (Closed.lean: every waiting thread is at a call of its saved declaration, the
module's function of the callee's name, with no blocks), under contexts that differ only in their
oracles and whose program `prog` passes `Labels.Ok`, agree (`Grid.fire_skel`). The participants'
statuses are related, so their arguments that decide the fire are equal (`Intrinsic.barrier_args`,
`Intrinsic.shfl_args`) and so are their instructions (`Thread.Skel.at`); participants at one
instruction under one program have one label of their result (`Thread.payRes_at`), and with a
payload result the saved declaration of a shuffle has no `range` on its result
(`Thread.AtCall.noRange`, from (O3)), so `withAttrs` keeps the exchanged values related
(`withAttrs_rel`) and so does `resumeAll` (`resumeAll_skel`, `Thread.Skel.resume`). The twins
show both premises are needed: of `Grid.AtCalls`, a saved declaration with `range` that is not the
module's, and of the common program.

The start (`Grid.start_skel`): on caller memories related by `Mem.SkelEq`, the starts of one launch
under two oracles both fault, or give grids related by `Grid.SkelRel` and contexts that differ only
in their oracles. The start reads the caller's memory only in `Mem.checkClosed`, which reads which
blocks exist, their sizes and pointer bytes (`Mem.checkClosed_skel`), allocates at `next`
(`Mem.allocNext_skel`, in `shared_skel` and `launchArgs_skel`) and reads the shape in `withAttrs`.

T3b (`Grid.skel_lockstep`): for a start whose program passes `Labels.Ok`, whose kernel is the
module's function of its name and every grid reachable from whose grid meets `Labels.MemAll`
(`Labels.MemOk`), relating the reachable grids by `Grid.SkelRel` to grids under contexts that
differ only in their oracles is a lockstep bisimulation (`Grid.Lockstep`): `advance` and `fire` by
`Grid.advance_skel` and `Grid.fire_skel` (with `Grid.Agree.imp`, as a step's target is reachable),
`done` by `Grid.SkelRel.done`, `trace` by `Mem.SkelEq.trace`, and `race` by `Thread.pending_skel`.

T3b's run (`Grid.skel_run`, T3 on T3b's relation): for such a start on the first of two caller
memories related by `Mem.SkelEq`, the first naming only known numbers in its pointer bytes, a run
of `k` steps to a done grid that is not bad gives a run of `k` steps from the start on the second
memory, under any oracle, to a done grid that is not bad and is related to the first's end by
`Grid.SkelRel`, and the second start's grid is sound for every observation of the blocks and
every relation that this end's observation satisfies (`Grid.start_skel`, `Grid.skel_lockstep` and
`Grid.payload_run`). The second memory names only known numbers too, as related memories have one
`next`, the same blocks and the same pointer bytes (`Mem.SkelEq.bytesIn`).

The six-field lemma (`Grid.skel_six`, T3 for the unit payload, docs/proofs/payload.md section
"Composition"): for every program, kernel, launch, arguments and address choice that `Grid.skel_run`
covers, one run of the start on one memory and oracle to a done grid that is not bad makes the
start's grid on every memory related by `Mem.SkelEq` (every payload), under every oracle, safe,
race free, keeping `!invariant.load`, making progress, terminating and determinate for the blocks:
the first six fields of `Grid.Sound`, with the blocks as observation and `R := True`. Its proof
reads no payload value. `Grid.Sound.of_blocks` adds the seventh field, for every observation of
the blocks and relation, from one reachable grid in which every thread has returned.

The kernel theorem (docs/proofs/skel-kernel.md): `Kernel.skel_sound` is `Grid.skel_six` at every
address choice of a set `A`, each with its own run: `Kernel.Sound` on every memory related by
`Mem.SkelEq`, for the admission of `A` and every oracle, the blocks and `R := True`.
`Kernel.Sound.of_blocks` adds the seventh field, for every program, from one final grid at each
admitted address choice and oracle (instances in MojoProofTest/SkelKernel.lean).

Tests (MojoProofTest/SkelStep.lean):
- `step_inst`: `define i8 @r(i8 %0) { ret i8 %0 }` (`retFn`) returning the payload words 7 and 8
  into the payload register 0 of a caller meets every premise of `step_skel`, and the steps are
  related (`ret_eval`: the caller's register gets the word);
- `ret_twin`, of `Labels.FramesOk`'s `ret`: returning into the skeleton register 2 of the caller,
  the frames' functions are the module's but `Labels.FramesOk` fails, and the steps are not
  related;
- `fn_twin`, of `Labels.FramesOk`'s `fn`: frames of `kernel #[addSt]` in a program (of
  `kernel #[]`) that passes `Labels.Ok`, whose function is not the module's of its name and fails
  `Labels.funcOk`; the steps are not related;
- `call_framesOk`: with no payload, a call pushes a frame of `gFn`, and `step_framesOk` keeps
  `Labels.FramesOk`; `call_framesOk_twin`, of `step_framesOk`'s `Labels.Ok`: with `@g`'s result
  payload and the call's result not, the program fails (O2), and the frames after fail
  `Labels.FramesOk`;
- `advance_inst`: `Grid.advance_skel` on one-thread grids of `step_inst`'s threads;
- `start_framesOk`: every grid reachable from the start of `callProg`'s kernel meets
  `Grid.FramesOk`; `start_framesOk_twin`, of the premise on the kernel: the start of `kernel #[]`,
  which has the name of `callProg`'s kernel, does not;
- `pending_inst`: the store of `store01` (MojoProofTest/SkelExec.lean) on frames whose payload
  register 0 holds 5 and 6 has the same pending access; `pending_twin`, of `Labels.Ok`: a store
  through `getelementptr` indexed by the payload register fails (O1), and the pending accesses are
  at different offsets (on the AST; the parser refuses a constant `getelementptr` of a
  register);
- `fire_inst`: two lanes of the launches of one kernel on `memX 1` and `memX 2` (block 1
  payload, every address choice and every two oracles) each load byte 0 of block 1 and wait at a
  butterfly shuffle of it, declared with four parameters and `convergent`; the grids reached are
  related and meet every premise of `Grid.fire_skel`, and the fires complete, the lanes swapping
  the words 1 (or 2), and agree; the twins, on hand-made one-lane states each with a saved
  declaration with `range(i32 0, 6)`, whose fires give 5 and `poison` (`rng_fire`):
  `fire_atCalls_twin` (the module's declaration has no `range`), `fire_prog_twin` (the contexts'
  program is not the one that passes `Labels.Ok`), `fire_ok_twin` (the program's declaration has
  `range` and fails (O3)) and `fire_framesOk_twin` (the frame's function is not the module's);
- `start_inst`: the launches of `kernel #[]` on `memX 1` and `memX 2` start, and their grids are
  related with block 1 payload; `start_twin`, of `Mem.SkelEq`: with no payload block, neither the
  memories nor the grids are related;
- `lockstep_inst`: `Grid.skel_lockstep` on the start of `kernel #[]` on `memX 1`, with no payload
  register and block 1 payload; `Labels.MemOk` holds as every frame's function is `kernel #[]`,
  which has no statement. The twins of its premises are those of the lemmas it composes:
  `call_framesOk_twin` and `fire_ok_twin` (`Labels.Ok`), `start_framesOk_twin` (the kernel) and
  `store_ok` (`Labels.MemOk`, MojoProofTest/Labels.lean);
- `run_inst`: `Grid.skel_run` on the one-step runs of `kernel #[]` on `memX 1` and `memX 2`, with
  no payload register and block 1 payload: the ends are related, the second holds byte 2, and the
  second start is sound for it; `run_twin`, of `Mem.SkelEq`: with no payload block, no one-step
  run on `memX 2` ends at a grid related to the first's end.

`Grid.skel_six` and `Grid.Sound.of_blocks` on a kernel that loads, adds and stores a float, from
one run with 1.0 and oracle 0, for every binary32 word and every oracle:
MojoProofTest/PayloadRun.lean (`six_inst`, `sum_inst`).
-/

namespace MojoProof.Sem

open LLVM
open GPUProof

/-- Results of one step in two runs, related under labelling `lab` and payload blocks `pay` for a
thread whose next statement's result is payload when `p` (`Thread.payRes`): `next` with threads
related by `Thread.Skel` and memories by `Mem.SkelEq`; `wait` at one intrinsic declared by one
function, with arguments equal after `Intrinsic.eraseArgs` when `p` and equal when not (as
`Status.Skel` relates them); `done` with memories related by `Mem.SkelEq`. -/
def Step.Skel (lab : Labels) (pay : Nat → Prop) (p : Bool) : Step → Step → Prop
  | .next t₁ m₁, .next t₂ m₂ => t₁.Skel lab t₂ ∧ m₁.SkelEq pay m₂
  | .wait i₁ a₁ f₁, .wait i₂ a₂ f₂ =>
    i₁ = i₂ ∧ f₁ = f₂ ∧ Labels.Rel p (fun a b => i₁.eraseArgs a = i₁.eraseArgs b) a₁ a₂
  | .done m₁, .done m₂ => m₁.SkelEq pay m₂
  | _, _ => False

/-- The invariant of `step_skel` on the frames `fs` of a thread, under labelling `lab` and program
`prog`: every frame's function is the module's function of its name (so it passes `Labels.funcOk`
if the program passes `Labels.Ok`, `Labels.FramesOk.funcOk`), and of each two adjacent frames, the
callee `f` and its caller `g`, `f` returns into a payload register of `g` if `f`'s function has a
payload result. -/
structure Labels.FramesOk (lab : Labels) (prog : Program) (fs : List Frame) : Prop where
  /-- Builds `Labels.FramesOk` from its two fields. -/
  mk ::
  /-- Every frame's function is the module's function of its name. -/
  fn : ∀ f ∈ fs, prog.module.funcs.find? (·.name == f.fn.name) = some f.fn
  /-- A callee whose function has a payload result returns into a payload register of its
  caller. -/
  ret : fs.IsChain fun f g => lab.ret f.fn.name = true → f.dest.any (lab.reg g.fn.name) = true

namespace Labels.FramesOk

variable {lab : Labels} {prog : Program} {f f' : Frame} {rest fs : List Frame}

/-- In a program that passes `Labels.Ok`, every frame's function passes `Labels.funcOk`. -/
theorem funcOk (h : lab.FramesOk prog fs) (hL : Labels.Ok prog lab = true) :
    ∀ f ∈ fs, lab.funcOk prog f.fn = true := fun f hf => by
  have hP : ∀ g ∈ prog.module.funcs, lab.funcOk prog g = true := by
    simpa only [Labels.Ok, Array.all_eq_true_iff_forall_mem] using hL
  exact hP _ (Array.mem_of_find?_eq_some (h.fn f hf))

/-- `Labels.FramesOk` holds with the first frame replaced by one of the same function and
destination register. -/
theorem head (h : lab.FramesOk prog (f :: rest)) (hfn : f'.fn = f.fn) (hd : f'.dest = f.dest) :
    lab.FramesOk prog (f' :: rest) := by
  refine ⟨fun g hg => ?_, ?_⟩
  · rcases List.mem_cons.1 hg with rfl | hg
    · rw [hfn]
      exact h.fn f List.mem_cons_self
    · exact h.fn g (List.mem_cons_of_mem _ hg)
  · have hc := h.ret
    cases rest with
    | nil => exact .singleton _
    | cons g rest =>
      rw [List.isChain_cons_cons] at hc ⊢
      rw [hfn, hd]
      exact hc

/-- `Labels.FramesOk` holds without the first frame. -/
theorem tail (h : lab.FramesOk prog (f :: rest)) : lab.FramesOk prog rest :=
  ⟨fun g hg => h.fn g (List.mem_cons_of_mem _ hg), h.ret.of_cons⟩

/-- `Labels.FramesOk` holds with a frame `f'` pushed whose function is the module's function of its
name and that returns into a payload register of `f` if its function has a payload result. -/
theorem push (h : lab.FramesOk prog (f :: rest))
    (hfn : prog.module.funcs.find? (·.name == f'.fn.name) = some f'.fn)
    (hd : lab.ret f'.fn.name = true → f'.dest.any (lab.reg f.fn.name) = true) :
    lab.FramesOk prog (f' :: f :: rest) := by
  refine ⟨fun g hg => ?_, .cons_cons hd h.ret⟩
  rcases List.mem_cons.1 hg with rfl | hg
  · exact hfn
  · exact h.fn g hg

end Labels.FramesOk

/-- Setting a register keeps the frame's function. -/
theorem Frame.set_fn (f : Frame) (r : Option Nat) (v : Option Val) (prod : Option (Val × Val)) :
    (f.set r v prod).fn = f.fn := by
  unfold Frame.set
  split <;> rfl

/-- Setting a register keeps the frame's destination register. -/
theorem Frame.set_dest (f : Frame) (r : Option Nat) (v : Option Val) (prod : Option (Val × Val)) :
    (f.set r v prod).dest = f.dest := by
  unfold Frame.set
  split <;> rfl

/-- A statement that continues keeps the frame's function and destination register. -/
theorem exec_fn {c : Ctx} {s : Scope} {k : Nat} {f f' : Frame} {st : Stmt} {m' : Mem}
    (h : exec c s k f st = .ok (.next f' m')) : f'.fn = f.fn ∧ f'.dest = f.dest := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first | exact ⟨rfl, rfl⟩ | exact ⟨Frame.set_fn .., Frame.set_dest ..⟩

/-- Entering a block keeps the frame's function and destination register. -/
theorem enter_fn {s : Scope} {f f' : Frame} {d : Nat} (h : enter s f d = .ok f') :
    f'.fn = f.fn ∧ f'.dest = f.dest := by
  unfold enter at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · split at h
    · cases h
    cases h
    refine foldl_inv (P := fun f' : Frame => f'.fn = f.fn ∧ f'.dest = f.dest) (Q := fun _ => True)
      ?_ _ f (fun _ _ => trivial) ⟨rfl, rfl⟩
    rintro f' ⟨st, v⟩ _ ⟨h1, h2⟩
    exact ⟨(Frame.set_fn _ _ _ _).trans h1, (Frame.set_dest _ _ _ _).trans h2⟩
  · cases h

/-- A statement that calls `g` is a call of a function `g` of the module that has blocks. -/
theorem exec_call {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {g : Func}
    {args : List Val} (h : exec c s k f st = .ok (.call g args)) :
    ∃ fm ty n xs, st.inst = .call fm ty (.fn n) xs ∧
      c.prog.module.funcs.find? (·.name == n) = some g ∧ g.blocks.isEmpty = false := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals exact ⟨_, _, _, _, ‹_›, ‹_›,
    by simpa only [Bool.not_eq_true'] using ‹(!(Array.isEmpty _)) = true›⟩

/-- Frames related pairwise by `Frame.Skel` have the same functions, so a test `q` of the
functions holds of some frame of one list exactly when it holds of some frame of the other. -/
theorem Frame.Skel.any_fn {lab : Labels} (q : Func → Bool) {l₁ l₂ : List Frame}
    (h : List.Forall₂ (Frame.Skel lab) l₁ l₂) :
    (l₁.any fun f => q f.fn) = l₂.any fun f => q f.fn := by
  induction h with
  | nil => rfl
  | @cons f₁ f₂ _ _ hf _ ih =>
    have e : f₁.fn = f₂.fn := (congrArg Frame.fn hf.shape :)
    simp only [List.any_cons, e, ih]

/-- For every relation `R`, payload registers `P`, parameters `ps` and argument lists related at
each index `j` by `R` if parameter `j` is payload and equal if not, the register `r` of a callee
frame (the argument at the first parameter named `r`, as `step` sets it) is related by `R` if
`P r` and equal if not. -/
theorem Labels.Rel.params {R : Val → Val → Prop} {P : Nat → Bool} :
    ∀ (ps : List Param) {a₁ a₂ : List Val},
      (∀ j : Nat, Option.Rel (Labels.Rel ((ps[j]?).any fun q => q.name.any P) R) a₁[j]? a₂[j]?) →
      ∀ r, Option.Rel (Labels.Rel (P r) R) (((ps.zip a₁).find? (·.1.name == some r)).map (·.2))
        (((ps.zip a₂).find? (·.1.name == some r)).map (·.2))
  | [], _, _, _, _ => .none
  | _ :: _, [], [], _, _ => .none
  | _ :: _, [], _ :: _, h, _ => by
    have h0 := h 0
    simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
    cases h0
  | _ :: _, _ :: _, [], h, _ => by
    have h0 := h 0
    simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
    cases h0
  | q :: ps, x₁ :: a₁, x₂ :: a₂, h, r => by
    have h0 := h 0
    simp only [List.getElem?_cons_zero, Option.any_some] at h0
    cases h0 with
    | some h0 =>
      simp only [List.zip_cons_cons, List.find?_cons]
      cases hq : (q.name == some r)
      · exact Labels.Rel.params ps
          (fun j => by simpa only [List.getElem?_cons_succ] using h (j + 1)) r
      · simp only [Option.map_some]
        rw [beq_iff_eq.1 hq] at h0
        exact .some h0

/-- An operand that mentions no register of `P` passes `TValue.payOk P`. -/
theorem TValue.payOk_of {P : Nat → Bool} {v : TValue} (h : v.mentions P = false) :
    v.payOk P = true := by
  obtain ⟨t, v⟩ := v
  cases v <;> first | rfl | (show (!TValue.mentions P _) = true; rw [h]; rfl)

/-- **T3b's step lemma.** For every labelling `lab`, payload blocks `pay`, context `c` whose program
passes `Labels.Ok`, oracle `o`, threads related by `Thread.Skel` whose first meets
`Labels.FramesOk`, and memories related by `Mem.SkelEq`, with `Labels.MemAt` at the first thread's
next statement, `step` under `c` and under `c` with oracle `o` gives one fault or results related
by `Step.Skel` at the label of that statement's result (`Thread.payRes`). -/
theorem step_skel {lab : Labels} {pay : Nat → Prop} {c : Ctx} {o : Nat → Nat} {t₁ t₂ : Thread}
    {m₁ m₂ : Mem} (ht : t₁.Skel lab t₂) (hm : m₁.SkelEq pay m₂) (hL : Labels.Ok c.prog lab = true)
    (hw : lab.FramesOk c.prog t₁.frames)
    (hM : lab.MemNext pay c m₁ t₁) :
    Except.Rel (Step.Skel lab pay (t₁.payRes lab)) (step c t₁ m₁)
      (step { c with oracle := o } t₂ m₂) := by
  obtain ⟨fs₁, k⟩ := t₁
  obtain ⟨fs₂, k₂⟩ := t₂
  obtain ⟨hk, hfs⟩ := ht
  unfold Labels.MemNext at hM
  dsimp only at hk hfs hw hM
  subst hk
  cases hfs with
  | nil => exact .error _
  | @cons f₁ f₂ rest₁ rest₂ hf hrest =>
  have e := hf.shape
  simp only [Frame.mk.injEq] at e
  obtain ⟨efn, elb, epc, -, -, eal, edest⟩ := e
  have hok := hw.funcOk hL f₁ List.mem_cons_self
  unfold step
  dsimp only
  rw [← efn, ← elb, ← epc, ← eal, ← edest]
  generalize hB : f₁.fn.blocks.find? (·.label == f₁.label) = B
  cases B with
  | none => exact .error _
  | some b =>
  dsimp only
  have hb := Array.mem_of_find?_eq_some hB
  have hfo := hok
  simp only [Labels.funcOk, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem] at hfo
  have hbo := hfo.2 b hb
  by_cases hpc : f₁.pc < b.stmts.size
  · rw [dite_eq_left hpc, dite_eq_left hpc]
    have hp : Thread.payRes lab ⟨f₁ :: rest₁, k⟩ =
        b.stmts[f₁.pc].res.any (lab.reg f₁.fn.name) := by
      simp only [Thread.payRes, hB, Option.bind_some, Array.getElem?_eq_getElem hpc]
      cases b.stmts[f₁.pc].res <;> rfl
    rw [hp]
    have H := exec_skel (c := c) (o := o) (k := k) (st := b.stmts[f₁.pc]) hf hm hL
      (hbo.1 _ (Array.getElem_mem hpc))
      (hM f₁ rest₁ b _ rfl hB (Array.getElem?_eq_getElem hpc))
    refine Except.Rel.bind_ok H fun E₁ E₂ he hE => ?_
    cases E₁ <;> cases E₂
    all_goals try exact (hE : False).elim
    · exact .ok ⟨⟨rfl, .cons hE.1 hrest⟩, hE.2⟩
    · rename_i g a₁ g' a₂
      obtain ⟨rfl, ha⟩ := hE
      dsimp only
      cases g.blocks[0]? with
      | none => exact .error _
      | some e0 =>
        dsimp only
        refine Except.Rel.bind_eq _ fun _ _ => ?_
        rw [show ((f₁ :: rest₁).any fun f => f.fn.name == g.name) =
          (f₂ :: rest₂).any fun f => f.fn.name == g.name from
          Frame.Skel.any_fn (fun fn => fn.name == g.name) (.cons hf hrest)]
        exact Except.Rel.ite (fun _ => .error _) fun _ =>
          .ok ⟨⟨rfl, .cons ⟨rfl, Labels.Rel.params g.params ha, fun _ => .none⟩ (.cons hf hrest)⟩,
            hm⟩
    · exact .ok hE
  · rw [dite_eq_right hpc, dite_eq_right hpc]
    have hsk : ∀ t v, Value.mentions (lab.reg f₁.fn.name) v = false →
        evalV ({ c with oracle := o }.scope m₂ f₂ k) t v = evalV (c.scope m₁ f₁ k) t v :=
      (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
        (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).1
    have hen := fun d => enter_skel (c := c) (o := o) (k := k) hf hm hok d
    have hterm := hbo.2
    generalize b.term = T at hterm ⊢
    cases T with
    | br d => exact (hen d).bind fun _ _ h => .ok ⟨⟨rfl, .cons h hrest⟩, hm⟩
    | condBr cv d d' =>
      dsimp only at hterm ⊢
      rw [hsk _ cv (by simpa only [TValue.mentions, Bool.not_eq_true'] using hterm)]
      refine Except.Rel.bind_eq _ fun v _ => ?_
      cases v
      case bits => exact (hen _).bind fun _ _ h => .ok ⟨⟨rfl, .cons h hrest⟩, hm⟩
      all_goals exact .error _
    | switch ty v d cs =>
      dsimp only at hterm ⊢
      rw [hsk _ v (by simpa only [TValue.mentions, Bool.not_eq_true'] using hterm)]
      refine Except.Rel.bind_eq _ fun v _ => ?_
      cases v
      case bits => exact (hen _).bind fun _ _ h => .ok ⟨⟨rfl, .cons h hrest⟩, hm⟩
      all_goals exact .error _
    | unreachable => exact .error _
    | ret rv =>
      dsimp only at hterm ⊢
      refine Except.Rel.bind_ok (R := Option.Rel (Labels.Rel (lab.ret f₁.fn.name) Val.Skel)) ?_
        fun v₁ v₂ _ hv => ?_
      · cases rv with
        | none => exact .ok .none
        | some tv =>
          obtain ⟨t, v⟩ := tv
          simp only [Option.all_some, Bool.or_eq_true, Bool.and_eq_true, Bool.not_eq_true'] at hterm
          rw [Option.mapM_some, Option.mapM_some]
          refine Except.Rel.map (R := Labels.Rel (lab.ret f₁.fn.name) Val.Skel) ?_
            fun _ _ h => .some h
          cases hr : lab.ret f₁.fn.name
          · have hs : TValue.mentions (lab.reg f₁.fn.name) ⟨t, v⟩ = false := by
              rcases hterm with h | h
              · exact h
              · rw [hr] at h; exact absurd h.1 Bool.false_ne_true
            simp only [evalTV]
            rw [hsk t v hs]
            refine Except.Rel.bind_eq _ fun x _ => ?_
            rw [withAttrs_shape (hm.sameShape fun _ => True) (Val.namesIn_top x)]
            exact .refl (Labels.Rel.refl Val.Skel.refl _) _
          · have hp : TValue.payOk (lab.reg f₁.fn.name) ⟨t, v⟩ = true := by
              rcases hterm with h | h
              · exact TValue.payOk_of h
              · exact h.2
            have hra : ∀ a ∈ f₁.fn.retAttrs, a.name ≠ "range" := by
              have h1 := hfo.1.1
              simp only [hr, Bool.not_true, Bool.false_or, List.all_eq_true, bne_iff_ne] at h1
              exact h1
            simp only [evalTV]
            exact (evalV_pay hm hf.regs t hp).bind fun x₁ x₂ hx =>
              (withAttrs_skel hm _ _ _ hx (.inl hra)).imp fun _ _ h => Labels.Rel.of_rel rfl h
      · cases hrest with
        | nil => exact .ok (Mem.foldl_setLive_skel _ false hm)
        | @cons g₁ g₂ r₁ r₂ hg hr =>
          have hc := hw.ret
          rw [List.isChain_cons_cons] at hc
          exact .ok ⟨⟨rfl, .cons (hg.next (hv.imp fun _ _ h => Labels.Rel.mono Val.Skel.refl
            hc.1 h) .none) hr⟩, Mem.foldl_setLive_skel _ false hm⟩

/-- Arrays related by `Option.Rel R` at every index stay related after setting index `n` to
members related by `R`. -/
theorem _root_.Option.Rel.set! {α β : Type} {R : α → β → Prop} {xs : Array α} {ys : Array β}
    (h : ∀ j : Nat, Option.Rel R xs[j]? ys[j]?) (n : Nat) {a : α} {b : β} (hab : R a b) (j : Nat) :
    Option.Rel R (xs.set! n a)[j]? (ys.set! n b)[j]? := by
  rw [Array.set!_eq_setIfInBounds, Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds,
    Array.getElem?_setIfInBounds]
  by_cases hnj : n = j
  · rw [ite_eq_left hnj, ite_eq_left hnj]
    have hn := h n
    by_cases hx : n < xs.size <;> by_cases hy : n < ys.size
    · rw [ite_eq_left hx, ite_eq_left hy]
      exact .some hab
    · rw [Array.getElem?_eq_getElem hx, Array.getElem?_eq_none_iff.2 (Nat.le_of_not_lt hy)] at hn
      cases hn
    · rw [Array.getElem?_eq_none_iff.2 (Nat.le_of_not_lt hx), Array.getElem?_eq_getElem hy] at hn
      cases hn
    · rw [ite_eq_right hx, ite_eq_right hy]
      exact .none
  · rw [ite_eq_right hnj, ite_eq_right hnj]
    exact h j

/-- **T3b's step lemma on grids.** For every labelling `lab`, payload blocks `pay`, contexts `c₁`
and `c₂` that differ only in their oracles, grids related by `Grid.SkelRel` and thread number `n`,
if `c₁ n`'s program passes `Labels.Ok`, thread `n` of `g₁`, if it runs, has frames that meet
`Labels.FramesOk`, and `g₁` meets `Labels.MemAll`, then thread `n`'s steps agree (`Grid.Agree`). -/
theorem Grid.advance_skel {lab : Labels} {pay : Nat → Prop} {c₁ c₂ : Nat → Ctx} {g₁ g₂ : Grid}
    (hc : ∀ n, c₂ n = { c₁ n with oracle := (c₂ n).oracle }) (hg : g₁.SkelRel lab pay g₂)
    (n : Nat) (hL : Labels.Ok (c₁ n).prog lab = true)
    (hw : ∀ t, g₁.threads[n]? = some (.run t) → lab.FramesOk (c₁ n).prog t.frames)
    (hM : lab.MemAll pay c₁ g₁) :
    Grid.Agree (Grid.SkelRel lab pay) (g₁.advance c₁ n) (g₂.advance c₂ n) := by
  have ht := hg.threads n
  have hM' := hM n
  unfold Grid.advance
  generalize e₁ : g₁.threads[n]? = s₁ at ht hw hM' ⊢
  generalize g₂.threads[n]? = s₂ at ht ⊢
  cases ht with
  | none => exact trivial
  | @some x₁ x₂ hs =>
  cases x₁ <;> cases x₂
  all_goals try exact (hs : False).elim
  all_goals try exact trivial
  rename_i t₁ t₂
  dsimp only
  have hst := step_skel (c := c₁ n) (o := (c₂ n).oracle) hs hg.mem hL (hw _ rfl) (hM' _ rfl)
  rw [← hc n] at hst
  generalize step (c₁ n) t₁ g₁.mem = r₁ at hst ⊢
  generalize step (c₂ n) t₂ g₂.mem = r₂ at hst ⊢
  cases hst with
  | error => exact trivial
  | @ok y₁ y₂ h =>
  cases y₁ <;> cases y₂
  all_goals try exact (h : False).elim
  · exact Grid.SkelRel.mk (Option.Rel.set! hg.threads n h.1) h.2
  · exact Grid.SkelRel.mk (Option.Rel.set! hg.threads n ⟨hs, h⟩) hg.mem
  · exact Grid.SkelRel.mk (Option.Rel.set! hg.threads n (trivial : Status.Skel lab .done .done)) h

/-- A step that continues keeps `Labels.FramesOk`, for every labelling and context whose program
passes `Labels.Ok`. -/
theorem step_framesOk {lab : Labels} {c : Ctx} {t t' : Thread} {m m' : Mem}
    (hL : Labels.Ok c.prog lab = true) (hw : lab.FramesOk c.prog t.frames)
    (h : step c t m = .ok (.next t' m')) : lab.FramesOk c.prog t'.frames := by
  obtain ⟨fs, k⟩ := t
  dsimp only at hw
  cases fs with
  | nil => cases h
  | cons f rest =>
  have hok := hw.funcOk hL f List.mem_cons_self
  simp only [Labels.funcOk, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem] at hok
  unfold step at h
  dsimp only at h
  generalize hB : f.fn.blocks.find? (·.label == f.label) = B at h
  cases B with
  | none => cases h
  | some b =>
  dsimp only at h
  by_cases hpc : f.pc < b.stmts.size
  · rw [dite_eq_left hpc] at h
    generalize hE : exec c (c.scope m f k) k f b.stmts[f.pc] = E at h
    cases E with
    | error => cases h
    | ok E =>
    cases E with
    | next f' m₁ =>
      cases h
      exact hw.head (exec_fn hE).1 (exec_fn hE).2
    | wait => cases h
    | call g args =>
      obtain ⟨fm, ty, nm, xs, hi, hf, hne⟩ := exec_call hE
      have hs := (hok.2 b (Array.mem_of_find?_eq_some hB)).1 _ (Array.getElem_mem hpc)
      have hn : g.name = nm := beq_iff_eq.1 (Array.find?_some hf :)
      simp only [Labels.stmtOk, hi, hf, hne, Bool.false_eq_true, ↓reduceIte, Bool.and_eq_true]
        at hs
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals
        refine hw.push ?_ fun hr => ?_
        · dsimp only
          rw [hn]
          exact hf
        · have h1 := hs.1
          dsimp only at hr ⊢
          rw [← hn, hr] at h1
          simpa only [Bool.not_true, Bool.false_or] using h1
  · rw [dite_eq_right hpc] at h
    repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
    all_goals cases h
    all_goals first
      | exact hw.head (enter_fn ‹_›).1 (enter_fn ‹_›).2
      | exact hw.tail.head (Frame.set_fn ..) (Frame.set_dest ..)

/-- Thread state `s`'s frames meet `Labels.FramesOk lab prog` if it runs or waits. -/
def Status.FramesOk (lab : Labels) (prog : Program) : Status → Prop
  | .run t | .wait t .. => lab.FramesOk prog t.frames
  | .done => True

/-- Every thread of grid `g` meets `Status.FramesOk` under `lab` and program `prog`: every running
or waiting thread's frames meet `Labels.FramesOk`. With `prog` the program of every thread's
context, it is the invariant that gives `Grid.fire_skel`'s premise on frames, and
`Grid.advance_skel`'s at every thread, for the first grid. -/
def Grid.FramesOk (lab : Labels) (prog : Program) (g : Grid) : Prop :=
  ∀ (n : Nat) s, g.threads[n]? = some s → s.FramesOk lab prog

/-- Resuming a thread keeps `Labels.FramesOk`: it replaces the first frame by one of the same
function and destination register. -/
theorem Thread.resume_framesOk {lab : Labels} {prog : Program} {t : Thread} (v : Option Val)
    (h : lab.FramesOk prog t.frames) : lab.FramesOk prog (t.resume v).frames := by
  obtain ⟨fs, k⟩ := t
  cases fs with
  | nil => exact h
  | cons f rest => exact h.head (Frame.set_fn ..) (Frame.set_dest ..)

/-- A thread's step in a grid (`Grid.advance`) keeps `Grid.FramesOk`, for every labelling and
contexts of one program that passes `Labels.Ok`. -/
theorem Grid.advance_framesOk {lab : Labels} {prog : Program} {c : Nat → Ctx} {g g' : Grid}
    {n : Nat} (hp : ∀ n, (c n).prog = prog) (hL : Labels.Ok prog lab = true)
    (h : g.advance c n = .ok (some g')) (hg : g.FramesOk lab prog) : g'.FramesOk lab prog := by
  unfold Grid.FramesOk at hg ⊢
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      split at h <;> cases h
      · have hw := hg n _ ht
        rw [← hp n] at hL hw
        exact set!_inv (P := fun _ (s : Status) => s.FramesOk lab prog) hg
          (hp n ▸ step_framesOk (t := t) hL hw hr)
      · exact set!_inv (P := fun _ (s : Status) => s.FramesOk lab prog) hg (hg n (.run t) ht)
      · exact set!_inv (P := fun _ (s : Status) => s.FramesOk lab prog) hg trivial
  · cases h

/-- A fire keeps `Grid.FramesOk`: the threads it resumes keep their frames' functions and
destination registers (`Thread.resume_framesOk`). -/
theorem Grid.fire_framesOk {lab : Labels} {prog : Program} {L : Launch} {c : Nat → Ctx}
    {g g' : Grid} {n : Nat} (h : g.fire L c n = .ok (some g')) (hg : g.FramesOk lab prog) :
    g'.FramesOk lab prog := by
  unfold Grid.fire at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | exact resumeAll_inv (P := fun _ s => s.FramesOk lab prog) ‹_›
        (fun _ _ _ _ _ r h _ => Thread.resume_framesOk r h) hg

/-- In every grid reachable from one that meets `Grid.FramesOk`, under contexts of one program
that passes `Labels.Ok`, `Grid.FramesOk` holds. -/
theorem Grid.reach_framesOk {lab : Labels} {prog : Program} {L : Launch} {c : Nat → Ctx}
    {g g' : Grid} (hp : ∀ n, (c n).prog = prog) (hL : Labels.Ok prog lab = true)
    (h : Relation.ReflTransGen (Grid.Step L c) g g') (hg : g.FramesOk lab prog) :
    g'.FramesOk lab prog :=
  Grid.reach_inv (fun _ _ _ => Grid.advance_framesOk hp hL) (fun _ _ _ => Grid.fire_framesOk) h
    hg

/-- The grid that `Grid.start` gives meets `Grid.FramesOk`, for every labelling, if the kernel is
the module's function of its name: every thread has one frame of the kernel. -/
theorem Grid.start_framesOk {lab : Labels} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid}
    {c : Nat → Ctx} (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn) : g.FramesOk lab prog := by
  intro j s hs
  obtain ⟨-, as, t, ht, rfl⟩ := Grid.start_run h j s hs
  unfold Thread.start at ht
  split at ht
  · cases ht
    exact Labels.FramesOk.mk (fun f hf => by obtain rfl := List.mem_singleton.1 hf; exact hfn)
      (.singleton _)
  · cases ht

/-- `Grid.FramesOk` from the start: for every labelling under which the program passes
`Labels.Ok`, if the kernel is the module's function of its name, every grid reachable from the
grid that `Grid.start` gives meets `Grid.FramesOk`. -/
theorem Grid.start_reach_framesOk {lab : Labels} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' : Grid}
    {c : Nat → Ctx} (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hL : Labels.Ok prog lab = true) (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn)
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') : g'.FramesOk lab prog :=
  Grid.reach_framesOk (fun n => (Grid.start_ctx h n).1) hL hr (Grid.start_framesOk h hfn)

/-- The pending accesses agree: for every labelling `lab`, payload blocks `pay`, context `c` whose
program passes `Labels.Ok`, oracle `o`, threads related by `Thread.Skel` whose first's frames meet
`Labels.FramesOk`, and memories related by `Mem.SkelEq`, the second thread's pending accesses
(`Thread.pending`) under `c` with oracle `o` are the first's under `c`. (O1) makes the pointer
operand of a `load`, `store` or `atomicrmw` skeleton, so it evaluates to one value
(`evalV_skel`); the other statements have none. -/
theorem Thread.pending_skel {lab : Labels} {pay : Nat → Prop} {c : Ctx} {o : Nat → Nat}
    {t₁ t₂ : Thread} {m₁ m₂ : Mem} (ht : t₁.Skel lab t₂) (hm : m₁.SkelEq pay m₂)
    (hL : Labels.Ok c.prog lab = true) (hw : lab.FramesOk c.prog t₁.frames) :
    t₂.pending { c with oracle := o } m₂ = t₁.pending c m₁ := by
  obtain ⟨fs₁, k⟩ := t₁
  obtain ⟨fs₂, k₂⟩ := t₂
  obtain ⟨hk, hfs⟩ := ht
  dsimp only at hk hfs hw
  subst hk
  cases hfs with
  | nil => rfl
  | @cons f₁ f₂ rest₁ rest₂ hf hrest =>
  have e := hf.shape
  simp only [Frame.mk.injEq] at e
  obtain ⟨efn, elb, epc, -, -, -, -⟩ := e
  have hok := hw.funcOk hL f₁ List.mem_cons_self
  have hsk : ∀ t v, Value.mentions (lab.reg f₁.fn.name) v = false →
      evalV ({ c with oracle := o }.scope m₂ f₂ k) t v = evalV (c.scope m₁ f₁ k) t v :=
    (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
      (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).1
  unfold Thread.pending
  dsimp only
  rw [← efn, ← elb, ← epc]
  generalize hB : f₁.fn.blocks.find? (·.label == f₁.label) = B
  cases B with
  | none => rfl
  | some b =>
  dsimp only
  have hfo := hok
  simp only [Labels.funcOk, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem] at hfo
  have hbo := hfo.2 b (Array.mem_of_find?_eq_some hB)
  generalize hS : b.stmts[f₁.pc]? = S
  cases S with
  | none => rfl
  | some st =>
  dsimp only
  have hst := hbo.1 st (Array.mem_of_getElem? hS)
  obtain ⟨res, inst, md⟩ := st
  cases inst
  case load vol t p al =>
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hst
      unfold LLVM.Stmt.pending
      dsimp only
      rw [hsk _ p hst.1]
    all_goals rfl
  case store vol v p al =>
    obtain ⟨vt, v⟩ := v
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hst
      unfold LLVM.Stmt.pending
      dsimp only
      rw [hsk _ p hst.1]
    all_goals rfl
  case atomicrmw vol op p v sc ord al =>
    obtain ⟨vt, v⟩ := v
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hst
      unfold LLVM.Stmt.pending
      dsimp only
      rw [hsk _ p hst.1]
    all_goals rfl
  all_goals rfl

/-- Related threads are at one instruction (`Thread.at`). -/
theorem Thread.Skel.at {lab : Labels} {t₁ t₂ : Thread} (h : t₁.Skel lab t₂) : t₁.at = t₂.at := by
  have hf := h.frames
  unfold Thread.at
  generalize t₁.frames = l₁ at hf ⊢
  generalize t₂.frames = l₂ at hf ⊢
  cases hf with
  | nil => rfl
  | @cons f₁ f₂ _ _ hF _ =>
    have e₁ : f₁.fn = f₂.fn := congrArg (·.fn) hF.shape
    have e₂ : f₁.label = f₂.label := congrArg (·.label) hF.shape
    have e₃ : f₁.pc = f₂.pc := congrArg (·.pc) hF.shape
    simp only [List.head?_cons, Option.map_some, e₁, e₂, e₃]

/-- Threads at one instruction whose frames meet `Labels.FramesOk` under one program are at
statements whose results are both payload or both not: their first frames' functions are the
module's function of one name. -/
theorem Thread.payRes_at {lab : Labels} {prog : Program} {t₁ t₂ : Thread}
    (h₁ : lab.FramesOk prog t₁.frames) (h₂ : lab.FramesOk prog t₂.frames) (h : t₁.at = t₂.at) :
    t₁.payRes lab = t₂.payRes lab := by
  obtain ⟨_ | ⟨f₁, r₁⟩, k₁⟩ := t₁ <;> obtain ⟨_ | ⟨f₂, r₂⟩, k₂⟩ := t₂
  · rfl
  · simp [Thread.at] at h
  · simp [Thread.at] at h
  simp only [Thread.at, List.head?_cons, Option.map_some, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨hn, hl, hp⟩ := h
  have e := h₁.fn f₁ List.mem_cons_self
  rw [hn, h₂.fn f₂ List.mem_cons_self] at e
  simp only [Thread.payRes, ← Option.some.inj e, hl, hp]

/-- A thread at a call of the declaration `fn` of a `shfl.sync`, whose frames meet
`Labels.FramesOk` in a context whose program passes `Labels.Ok`, with a payload result: `fn`'s
result has no `range` attribute ((O3)). -/
theorem Thread.AtCall.noRange {lab : Labels} {c : Ctx} {t : Thread} {mode : Shfl} {fn : Func}
    (h : t.AtCall c (.shfl mode) fn) (hL : Labels.Ok c.prog lab = true)
    (hw : lab.FramesOk c.prog t.frames) (hp : t.payRes lab = true) :
    ∀ a ∈ fn.retAttrs, a.name ≠ "range" := by
  obtain ⟨f, rest, b, st, fm, ty, g, args, hf, hb, hs, hst, hfn, he, hi⟩ := h
  obtain ⟨fs, k⟩ := t
  dsimp only at hf hw
  subst hf
  have hpr : st.res.any (lab.reg f.fn.name) = true := by
    simp only [Thread.payRes, hb, hs, Option.bind_some] at hp
    revert hp
    cases st.res <;> simp
  have hok := hw.funcOk hL f List.mem_cons_self
  simp only [Labels.funcOk, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem] at hok
  have hso := (hok.2 b (Array.mem_of_find?_eq_some hb)).1 st (Array.mem_of_getElem? hs)
  simp only [Labels.stmtOk, hst, hfn, he, hi, hpr, ↓reduceIte, Bool.not_true, Bool.false_or,
    Bool.and_eq_true, List.all_eq_true, List.mem_append, bne_iff_ne] at hso
  exact fun a ha => hso.1 a (.inl ha)

/-- Resuming threads related by `Thread.Skel` with results related at the label of the call's
result register (`Thread.payRes`) gives related threads. -/
theorem Thread.Skel.resume {lab : Labels} {t₁ t₂ : Thread} (h : t₁.Skel lab t₂)
    {v₁ v₂ : Option Val} (hv : Option.Rel (Labels.Rel (t₁.payRes lab) Val.Skel) v₁ v₂) :
    (t₁.resume v₁).Skel lab (t₂.resume v₂) := by
  obtain ⟨fs₁, k⟩ := t₁
  obtain ⟨fs₂, k'⟩ := t₂
  obtain ⟨hk, hf⟩ := h
  dsimp only at hk hf
  subst hk
  cases hf with
  | nil => exact ⟨rfl, .nil⟩
  | @cons f₁ f₂ r₁ r₂ hF hr =>
    obtain ⟨fn, l, pc, rg₁, pd₁, al, d⟩ := f₁
    obtain ⟨fn', l', pc', rg₂, pd₂, al', d'⟩ := f₂
    obtain ⟨e₁, e₂, e₃⟩ : fn = fn' ∧ l = l' ∧ pc = pc' :=
      ⟨congrArg (·.fn) hF.shape, congrArg (·.label) hF.shape, congrArg (·.pc) hF.shape⟩
    subst e₁ e₂ e₃
    have hp : ∀ o : Option Nat, (o.map (lab.reg fn.name)).getD false = o.any (lab.reg fn.name) :=
      fun o => by cases o <;> rfl
    simp only [Thread.payRes, hp] at hv
    exact ⟨rfl, .cons (hF.next hv .none) hr⟩

/-- The arguments of waiting barriers related by `Status.Skel` are equal. -/
theorem _root_.MojoProof.LLVM.Intrinsic.barrier_args {p : Bool} {a₁ a₂ : List Val}
    (h : Labels.Rel p (fun a b => Intrinsic.barrier.eraseArgs a = Intrinsic.barrier.eraseArgs b)
      a₁ a₂) : a₁ = a₂ := by
  cases p <;> exact h

/-- The arguments of waiting shuffles related by `Status.Skel`: equal lists of fewer than two, or
lists that differ only in their second members, related by `Labels.Rel p Val.Skel`. -/
theorem _root_.MojoProof.LLVM.Intrinsic.shfl_args {p : Bool} {mode : Shfl} {a₁ a₂ : List Val}
    (h : Labels.Rel p (fun a b => (Intrinsic.shfl mode).eraseArgs a =
      (Intrinsic.shfl mode).eraseArgs b) a₁ a₂) :
    (a₁ = a₂ ∧ a₁.length < 2) ∨
      ∃ m x₁ x₂ r, a₁ = m :: x₁ :: r ∧ a₂ = m :: x₂ :: r ∧ Labels.Rel p Val.Skel x₁ x₂ := by
  cases p
  · rcases a₁ with _ | ⟨m, _ | ⟨x, r⟩⟩ <;> obtain rfl : _ = a₂ := h
    · exact .inl ⟨rfl, by simp⟩
    · exact .inl ⟨rfl, by simp⟩
    · exact .inr ⟨m, x, x, r, rfl, rfl, Labels.Rel.refl Val.Skel.refl _ x⟩
  · rcases a₁ with _ | ⟨m, _ | ⟨x, r⟩⟩ <;> rcases a₂ with _ | ⟨m', _ | ⟨x', r'⟩⟩ <;>
      (try cases h) <;> (try exact .inl ⟨rfl, by simp⟩)
    have h' : m :: x.erase :: r = m' :: x'.erase :: r' := h
    obtain ⟨rfl, hx, rfl⟩ : m = m' ∧ x.erase = x'.erase ∧ r = r' := by
      simpa only [List.cons.injEq] using h'
    exact .inr ⟨m, x, x', r, rfl, rfl, hx⟩

/-- For every layout, type and attributes and memories related by `Mem.SkelEq`, `withAttrs` on
values related by `Labels.Rel p Val.Skel` gives one fault or values related by it, if the
attributes have no `range` when `p` holds. -/
theorem withAttrs_rel {pay : Nat → Prop} {m₁ m₂ : Mem} (hm : m₁.SkelEq pay m₂) (l : Layout)
    (t : Ty) (attrs : List Attr) {p : Bool} {x₁ x₂ : Val} (hx : Labels.Rel p Val.Skel x₁ x₂)
    (hr : p = true → ∀ a ∈ attrs, a.name ≠ "range") :
    Except.Rel (Labels.Rel p Val.Skel) (withAttrs l m₁ t attrs x₁) (withAttrs l m₂ t attrs x₂) := by
  cases p
  · obtain rfl : x₁ = x₂ := hx
    rw [withAttrs_shape (hm.sameShape fun _ => True) (Val.namesIn_top _)]
    exact .refl (Labels.Rel.refl Val.Skel.refl _) _
  · exact (withAttrs_skel hm l t attrs (Labels.Rel.to Val.Skel.refl hx) (.inl (hr rfl))).imp
      fun _ _ h => Labels.Rel.of_rel rfl h

/-- Lists of options related element by element by `Option.Rel R` are both all `some`, with
values related element by element, or both not (`mapM id`). -/
theorem _root_.List.Forall₂.mapM_id {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List (Option α)} {ys : List (Option β)}, List.Forall₂ (Option.Rel R) xs ys →
      Option.Rel (List.Forall₂ R) (xs.mapM id) (ys.mapM id)
  | [], [], .nil => .some .nil
  | _ :: xs, _ :: ys, .cons h hs => by
    have ih := List.Forall₂.mapM_id hs
    simp only [List.mapM_cons]
    generalize xs.mapM id = o₁ at ih ⊢
    generalize ys.mapM id = o₂ at ih ⊢
    cases h with
    | none => exact .none
    | some h =>
      cases ih with
      | none => exact .none
      | some ih => exact .some (.cons h ih)

/-- In lists related element by element by `R`, predicates that agree on related members find
related members or none. -/
theorem _root_.List.Forall₂.find? {α β : Type} {R : α → β → Prop} {P : α → Bool} {Q : β → Bool}
    (hPQ : ∀ a b, R a b → P a = Q b) :
    ∀ {xs : List α} {ys : List β}, List.Forall₂ R xs ys → Option.Rel R (xs.find? P) (ys.find? Q)
  | [], [], .nil => .none
  | a :: _, b :: _, .cons h hs => by
    rw [List.find?_cons, List.find?_cons, hPQ a b h]
    cases Q b
    · exact List.Forall₂.find? hPQ hs
    · exact .some h

/-- `resumeAll` on arrays related by `Status.Skel` at every index, with results whose
`withAttrs` under each waiting thread's declaration are related at the label of its call's result
(`Thread.payRes`), gives one fault or arrays related at every index. -/
theorem resumeAll_skel {lab : Labels} {l : Layout} {m₁ m₂ : Mem} {v₁ v₂ : Nat → Option Val}
    (ns : List Nat) {ts₁ ts₂ : Array Status}
    (h : ∀ j : Nat, Option.Rel (Status.Skel lab) ts₁[j]? ts₂[j]?)
    (hv : ∀ j t i a fn, ts₁[j]? = some (.wait t i a fn) →
      Except.Rel (Option.Rel (Labels.Rel (t.payRes lab) Val.Skel))
        ((v₁ j).mapM (withAttrs l m₁ fn.ret fn.retAttrs))
        ((v₂ j).mapM (withAttrs l m₂ fn.ret fn.retAttrs))) :
    Except.Rel (fun ts₁ ts₂ => ∀ j : Nat, Option.Rel (Status.Skel lab) ts₁[j]? ts₂[j]?)
      (resumeAll l m₁ ts₁ ns v₁) (resumeAll l m₂ ts₂ ns v₂) := by
  unfold resumeAll
  refine (Except.Rel.foldlM (R := fun ts₁ ts₂ =>
    (∀ j : Nat, Option.Rel (Status.Skel lab) ts₁[j]? ts₂[j]?) ∧
    ∀ j t i a fn, ts₁[j]? = some (.wait t i a fn) →
      Except.Rel (Option.Rel (Labels.Rel (t.payRes lab) Val.Skel))
        ((v₁ j).mapM (withAttrs l m₁ fn.ret fn.retAttrs))
        ((v₂ j).mapM (withAttrs l m₂ fn.ret fn.retAttrs))) ?_ ⟨h, hv⟩).imp fun _ _ h => h.1
  intro n _ x y ⟨hx, hxv⟩
  have hn := hx n
  have hvn := hxv n
  generalize x[n]? = s₁ at hn hvn ⊢
  generalize y[n]? = s₂ at hn ⊢
  cases hn with
  | none => exact .ok ⟨hx, hxv⟩
  | @some s₁ s₂ hs =>
  cases s₁ <;> cases s₂
  all_goals try exact (hs : False).elim
  all_goals try exact .ok ⟨hx, hxv⟩
  rename_i t₁ i₁ a₁ f₁ t₂ i₂ a₂ f₂
  obtain ⟨ht, rfl, rfl, -⟩ := hs
  dsimp only
  refine (hvn _ _ _ _ rfl).bind fun r₁ r₂ hr => .ok ⟨Option.Rel.set! hx n (ht.resume hr), ?_⟩
  intro j t i a fn hj
  rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hj
  split at hj
  · split at hj <;> cases hj
  · exact hxv j t i a fn hj

/-- Results related by `Except.Rel (Option.Rel S)` agree under `S`. -/
theorem Grid.Agree.of_rel {S : Grid → Grid → Prop} {x y : Except Fault (Option Grid)}
    (h : Except.Rel (Option.Rel S) x y) : Grid.Agree S x y := by
  cases h with
  | error => exact trivial
  | ok h =>
    cases h with
    | none => exact trivial
    | some h => exact h

/-- **T3b's step lemma for collective calls.** For every labelling `lab`, payload blocks `pay`,
launch, contexts `c₁` and `c₂` that differ only in their oracles, of one program `prog` that
passes `Labels.Ok`, and grids related by `Grid.SkelRel` whose first meets `Grid.FramesOk` and
`Grid.AtCalls`, thread `n`'s fires agree (`Grid.Agree`). The arguments that decide the
participants, the barrier number, the mask, lanes and clamps, and the instruction (`Thread.at`)
are equal in the two grids; a shuffle's exchanged values are related at the label of the call's
result, which is one for every participant (`Thread.payRes_at`), and with a payload result the
declaration has no `range` on its result (`Thread.AtCall.noRange`), so `withAttrs` keeps them
related (`withAttrs_rel`, `resumeAll_skel`). -/
theorem Grid.fire_skel {lab : Labels} {pay : Nat → Prop} {L : Launch} {prog : Program}
    {c₁ c₂ : Nat → Ctx} {g₁ g₂ : Grid} (hc : ∀ n, c₂ n = { c₁ n with oracle := (c₂ n).oracle })
    (hp : ∀ n, (c₁ n).prog = prog) (hL : Labels.Ok prog lab = true)
    (hg : g₁.SkelRel lab pay g₂) (hw : g₁.FramesOk lab prog) (ha : g₁.AtCalls c₁) (n : Nat) :
    Grid.Agree (Grid.SkelRel lab pay) (g₁.fire L c₁ n) (g₂.fire L c₂ n) := by
  apply Grid.Agree.of_rel
  have hl : (c₂ n).prog.layout = (c₁ n).prog.layout := congrArg (·.prog.layout) (hc n)
  have ht := hg.threads n
  have hwn := hw n
  unfold Grid.fire
  rw [hl]
  generalize g₁.threads[n]? = s₁ at ht hwn ⊢
  generalize g₂.threads[n]? = s₂ at ht ⊢
  cases ht with
  | none => exact .ok .none
  | @some x₁ x₂ hs =>
  cases x₁ <;> cases x₂
  all_goals try exact (hs : False).elim
  all_goals try exact .ok .none
  rename_i t₁ i₁ a₁ f₁ t₂ i₂ a₂ f₂
  obtain ⟨ht, e₁, -, hA⟩ := hs
  have hwt : lab.FramesOk prog t₁.frames := hwn _ rfl
  dsimp only
  cases i₁ <;> subst e₁
  all_goals try exact .error _
  case barrier =>
    have e := Intrinsic.barrier_args hA
    rcases a₁ with _ | ⟨x, _ | ⟨y, r⟩⟩ <;> subst e
    all_goals try exact .error _
    dsimp only
    generalize x.word? = w
    cases w with
    | none => exact .error _
    | some bar =>
    dsimp only
    refine Except.Rel.ite (fun _ => ?_) (fun _ => .error _)
    refine Except.Rel.bind (Except.Rel.mapM (R := Eq) (S := Eq) ?_
      ((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl)) ?_
    · intro k k' e
      rw [← e]
      have hk := hg.threads k
      generalize g₁.threads[k]? = o₁ at hk ⊢
      generalize g₂.threads[k]? = o₂ at hk ⊢
      cases hk with
      | none => exact .ok rfl
      | @some y₁ y₂ hy =>
      cases y₁ <;> cases y₂
      all_goals try exact (hy : False).elim
      all_goals try exact .ok rfl
      all_goals try exact .error _
      rename_i u₁ j₁ b₁ h₁ u₂ j₂ b₂ h₂
      obtain ⟨hu, e₃, -, hB⟩ := hy
      cases j₁ <;> subst e₃
      all_goals try exact .ok rfl
      have e := Intrinsic.barrier_args hB
      rcases b₁ with _ | ⟨x', _ | ⟨y', r'⟩⟩ <;> subst e
      all_goals try exact .ok rfl
      dsimp only
      rw [← hu.at, ← ht.at]
      exact .refl (fun _ => rfl) _
    · intro s₁ s₂ hs
      rw [List.forall₂_eq_eq_eq] at hs
      subst hs
      refine Except.Rel.ite (fun _ => ?_) (fun _ => .ok .none)
      exact Except.Rel.bind (resumeAll_skel _ hg.threads fun _ _ _ _ _ _ => .ok .none)
        fun _ _ h => .ok (.some ⟨h, Mem.log_skel hg.mem _⟩)
  case shfl mode =>
    rcases Intrinsic.shfl_args hA with ⟨e, hlen⟩ | ⟨msk, x₁, x₂, r, rfl, rfl, -⟩
    · rcases a₁ with _ | ⟨_, _ | ⟨_, _⟩⟩ <;> subst e
      all_goals first | exact .error _ | simp at hlen
    rcases r with _ | ⟨b, _ | ⟨cc, _ | ⟨_, _⟩⟩⟩
    all_goals try exact .error _
    dsimp only
    generalize msk.word? = w
    cases w with
    | none => exact .error _
    | some mask =>
    dsimp only
    refine Except.Rel.ite (fun _ => ?_) (fun _ => .error _)
    generalize n - n % volume L.block % 32 = base
    refine Except.Rel.bind (Except.Rel.mapM (R := Eq)
      (S := Option.Rel fun y₁ y₂ : Nat × Val × Nat × Nat => y₁.1 = y₂.1 ∧
        Labels.Rel (t₁.payRes lab) Val.Skel y₁.2.1 y₂.2.1 ∧ y₁.2.2 = y₂.2.2 ∧
        ∀ t i a fn, g₁.threads[base + y₁.1]? = some (.wait t i a fn) →
          t.payRes lab = t₁.payRes lab ∧
            (t₁.payRes lab = true → ∀ x ∈ fn.retAttrs, x.name ≠ "range")) ?_
      ((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl)) ?_
    · intro j j' e
      rw [← e]
      have hj := hg.threads (base + j)
      have hwj := hw (base + j)
      have haj := ha (base + j)
      generalize e₂ : g₁.threads[base + j]? = o₁ at hj hwj haj ⊢
      generalize g₂.threads[base + j]? = o₂ at hj ⊢
      cases hj with
      | none => exact .ok .none
      | @some y₁ y₂ hy =>
      cases y₁ <;> cases y₂
      all_goals try exact (hy : False).elim
      all_goals try exact .ok .none
      all_goals try exact .error _
      rename_i u₁ j₁ b₁ h₁ u₂ j₂ b₂ h₂
      obtain ⟨hu, e₃, -, hB⟩ := hy
      cases j₁ <;> subst e₃
      all_goals try exact .error _
      rename_i mode'
      rcases Intrinsic.shfl_args hB with ⟨e, hlen⟩ | ⟨msk', z₁, z₂, r', rfl, rfl, hz⟩
      · rcases b₁ with _ | ⟨_, _ | ⟨_, _⟩⟩ <;> subst e
        all_goals first | exact .error _ | simp at hlen
      rcases r' with _ | ⟨b', _ | ⟨c', _ | ⟨_, _⟩⟩⟩
      all_goals try exact .error _
      dsimp only
      rw [← hu.at, ← ht.at]
      refine Except.Rel.ite (fun hc => ?_) (fun _ => .error _)
      have hu₁ : lab.FramesOk prog u₁.frames := hwj _ rfl
      have hpay := Thread.payRes_at hu₁ hwt hc.2.2
      generalize b'.word? = wb
      generalize c'.word? = wc
      cases wb <;> cases wc
      all_goals try exact .error _
      refine .ok (.some ⟨rfl, by rw [← hpay]; exact hz, rfl, fun t i a fn ht' => ?_⟩)
      have ht'' : g₁.threads[base + j]? = some (.wait t i a fn) := ht'
      rw [e₂] at ht''
      cases ht''
      refine ⟨hpay, fun hp₁ => Thread.AtCall.noRange (haj _ rfl) ?_ ?_ (hpay.trans hp₁)⟩
      · rw [hp]
        exact hL
      · rw [hp]
        exact hu₁
    · intro ps₁ ps₂ hps
      have ho := List.Forall₂.mapM_id hps
      generalize List.mapM (m := Option) id ps₁ = o₁ at ho ⊢
      generalize List.mapM (m := Option) id ps₂ = o₂ at ho ⊢
      cases ho with
      | none => exact .ok .none
      | @some qs₁ qs₂ hqs =>
      dsimp only
      have hns : qs₂.map (fun y : Nat × Val × Nat × Nat => base + y.1) =
          qs₁.map (fun y => base + y.1) := by
        clear * - hqs
        induction hqs with
        | nil => rfl
        | cons h _ ih => simp only [List.map_cons, ih, h.1]
      rw [hns]
      have hsrc : ∀ s, Labels.Rel (t₁.payRes lab) Val.Skel
          (((qs₁.find? fun x => decide (x.1 = s)).map (·.2.1)).getD .poison)
          (((qs₂.find? fun x => decide (x.1 = s)).map (·.2.1)).getD .poison) := fun s =>
        Option.Rel.getD (Option.Rel.map (fun _ _ h => by exact h.2.1)
          (List.Forall₂.find? (fun _ _ h => by simp only [h.1]) hqs))
          (Labels.Rel.refl Val.Skel.refl _ _)
      refine Except.Rel.bind (resumeAll_skel _ hg.threads fun k t i a fn hkt => ?_)
        fun _ _ h => .ok (.some ⟨h, hg.mem⟩)
      have hf := List.Forall₂.find? (P := fun x : Nat × Val × Nat × Nat => decide (base + x.1 = k))
        (Q := fun x => decide (base + x.1 = k)) (fun _ _ h => by simp only [h.1]) hqs
      generalize e : List.find? (fun x : Nat × Val × Nat × Nat => decide (base + x.1 = k)) qs₁ =
        o₁ at hf ⊢
      generalize List.find? (fun x : Nat × Val × Nat × Nat => decide (base + x.1 = k)) qs₂ =
        o₂ at hf ⊢
      cases hf with
      | none => exact .ok .none
      | @some y₁ y₂ hy =>
      obtain ⟨j₁, z₁, b₁, c₁⟩ := y₁
      obtain ⟨j₂, z₂, b₂, c₂⟩ := y₂
      obtain ⟨hj, -, hbc, hW⟩ := hy
      dsimp only at hj hbc hW
      subst hj
      cases hbc
      have hk : base + j₁ = k := by simpa using List.find?_some e
      subst hk
      obtain ⟨hpay, hr⟩ := hW t i a fn hkt
      rw [hpay]
      exact Option.Rel.mapM (R := Labels.Rel (t₁.payRes lab) Val.Skel)
        (fun _ _ hx => withAttrs_rel hg.mem _ _ _ hx hr) (.some (hsrc _))
  case mma v =>
    dsimp only
    refine Except.Rel.ite (fun _ => ?_) (fun _ => .error _)
    generalize n - n % volume L.block % 32 = base
    have e : mmaRes L.acc ((List.range 32).map fun j => g₂.threads[base + j]?) t₂.at v =
        mmaRes L.acc ((List.range 32).map fun j => g₁.threads[base + j]?) t₁.at v := by
      rw [← ht.at]
      unfold mmaRes
      congr 1
      rw [List.mapM_map, List.mapM_map]
      refine mapM_congr fun j _ => ?_
      have hk := hg.threads (base + j)
      simp only [Function.comp_apply]
      generalize g₁.threads[base + j]? = o₁ at hk ⊢
      generalize g₂.threads[base + j]? = o₂ at hk ⊢
      cases hk with
      | none => rfl
      | @some y₁ y₂ hy =>
      cases y₁ <;> cases y₂
      all_goals try exact (hy : False).elim
      all_goals try rfl
      rename_i u₁ j₁ b₁ h₁ u₂ j₂ b₂ h₂
      obtain ⟨hu, e₃, -, hB⟩ := hy
      cases j₁ <;> subst e₃
      all_goals try rfl
      have hb : b₂ = b₁ := by
        simp only [Labels.Rel] at hB
        split at hB <;> exact hB.symm
      subst hb
      simp only [hu.at]
    rw [e]
    refine Except.Rel.bind (R := Eq) (.refl (fun _ => rfl) _) fun r₁ r₂ hr => ?_
    subst hr
    cases r₁ with
    | none => exact .ok .none
    | some y =>
    dsimp only
    refine Except.Rel.bind (resumeAll_skel _ hg.threads fun k t i a fn _ => ?_)
      fun _ _ h => .ok (.some ⟨h, hg.mem⟩)
    refine Option.Rel.mapM (R := Eq) (fun x _ hx => ?_) (.some rfl)
    subst hx
    rw [withAttrs_shape (hg.mem.sameShape fun _ => True) (Val.namesIn_top x)]
    exact .refl (Labels.Rel.refl Val.Skel.refl _) _

/-- For every set of payload blocks, an allocation at `next` in related memories gives one fault,
or related memories and one block number. -/
theorem Mem.allocNext_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (l : Layout)
    (space size align : Nat) (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat)
    (init : List MemByte) :
    Except.Rel (fun r₁ r₂ : Mem × Nat => r₁.1.SkelEq pay r₂.1 ∧ r₁.2 = r₂.2)
      (m₁.allocNext l space size align live readOnly owner addr gaddr init)
      (m₂.allocNext l space size align live readOnly owner addr gaddr init) := by
  have hs : (m₁.blocks m₁.next).isSome = (m₂.blocks m₂.next).isSome := by
    rw [← h.next]
    exact (h.blocks _).isSome
  unfold Mem.allocNext
  rw [hs]
  exact Except.Rel.ite (fun _ => .error _)
    (fun _ => .ok (Mem.alloc_skel h l space size align live readOnly owner addr gaddr init none))

/-- For every set of payload blocks, related memories pass `Mem.checkClosed` alike: it reads
`next`, which blocks exist, their sizes and their pointer bytes, which are equal. -/
theorem Mem.checkClosed_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂)
    (vs : List Val) : m₁.checkClosed vs = m₂.checkClosed vs := by
  have hn : m₁.namesBelow vs = m₂.namesBelow vs := by
    unfold Mem.namesBelow
    rw [h.next]
    congr 2
    funext c
    have hc := h.blocks c
    generalize m₁.blocks c = o₁ at hc ⊢
    generalize m₂.blocks c = o₂ at hc ⊢
    cases hc with
    | none => rfl
    | @some B₁ B₂ hB =>
      dsimp only
      rw [show B₁.size = B₂.size from (congrArg Block.size hB.shape :)]
      congr 1
      funext i
      have hb : (B₁.bytes i).erase = (B₂.bytes i).erase := hB.bytes i
      generalize B₁.bytes i = x at hb ⊢
      generalize B₂.bytes i = y at hb ⊢
      cases x <;> cases y <;> simp_all [MemByte.erase]
  unfold Mem.checkClosed
  rw [h.next, (h.blocks 0).isSome, hn]

/-- For every set of payload blocks, `shared` on related memories gives one fault, or related
memories and one table of the shared globals' pointers. -/
theorem shared_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (l : Layout)
    (gs : List Global) (dyn c : Nat) (ch : Nat → Nat) :
    Except.Rel (fun r₁ r₂ : Mem × List (String × Ptr) => r₁.1.SkelEq pay r₂.1 ∧ r₁.2 = r₂.2)
      (shared l gs dyn c ch m₁) (shared l gs dyn c ch m₂) := by
  unfold shared
  dsimp only
  refine Except.Rel.bind (Mem.allocNext_skel h ..) fun x y hxy => ?_
  obtain ⟨a₁, d⟩ := x
  obtain ⟨a₂, d'⟩ := y
  obtain ⟨ha, rfl⟩ := hxy
  dsimp only
  refine Except.Rel.foldlM (fun gi _ x y hxy => ?_) ⟨ha, rfl⟩
  obtain ⟨g, i⟩ := gi
  obtain ⟨a₁, acc⟩ := x
  obtain ⟨a₂, acc'⟩ := y
  obtain ⟨ha, rfl⟩ := hxy
  dsimp only
  repeat' split
  all_goals first
    | exact .error _
    | exact .ok ⟨ha, rfl⟩
    | exact Except.Rel.bind (Mem.allocNext_skel ha ..) fun x y hxy => by
        obtain ⟨x₁, b⟩ := x
        obtain ⟨x₂, b'⟩ := y
        obtain ⟨hx, rfl⟩ := hxy
        exact .ok ⟨hx, rfl⟩

/-- For every set of payload blocks, `launchArgs` on related memories gives one fault, or related
memories and one list of arguments. -/
theorem launchArgs_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (l : Layout)
    (n : Nat) (fn : Func) (args : List Val) (ch : Nat → Nat) :
    Except.Rel (fun r₁ r₂ : Mem × List Val => r₁.1.SkelEq pay r₂.1 ∧ r₁.2 = r₂.2)
      (launchArgs l m₁ n fn args ch) (launchArgs l m₂ n fn args ch) := by
  unfold launchArgs
  refine Except.Rel.foldlM (fun pvi _ x y hxy => ?_) ⟨h, rfl⟩
  obtain ⟨⟨p, v⟩, i⟩ := pvi
  obtain ⟨a₁, acc⟩ := x
  obtain ⟨a₂, acc'⟩ := y
  obtain ⟨ha, rfl⟩ := hxy
  dsimp only
  rw [withAttrs_shape (ha.sameShape fun _ => True) (Val.namesIn_top v)]
  repeat' split
  all_goals first
    | exact .error _
    | exact Except.Rel.bind (.refl (fun _ => rfl) _) fun _ _ e => by
        subst e
        exact .ok ⟨ha, rfl⟩
    | exact Except.Rel.bind (Mem.allocNext_skel ha ..) fun x y hxy => by
        obtain ⟨x₁, b⟩ := x
        obtain ⟨x₂, b'⟩ := y
        obtain ⟨hx, rfl⟩ := hxy
        exact .ok ⟨hx, rfl⟩

/-- For every set of payload blocks, a memory related to one whose pointer bytes name only known
numbers (`Mem.BytesIn`, `Mem.Known`) has them too: related memories have one `next`, blocks at the
same numbers, of one size, and the same pointer bytes. -/
theorem Mem.SkelEq.bytesIn {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂)
    (hm : m₁.BytesIn m₁.Known) : m₂.BytesIn m₂.Known := by
  intro c B₂ i p j hc hi hp
  have hk : m₁.Known p.block ↔ m₂.Known p.block := by
    simp only [Mem.Known, h.next, (h.blocks p.block).isSome]
  have hB := h.blocks c
  rw [hc] at hB
  generalize hx : m₁.blocks c = o at hB
  cases hB with
  | @some B₁ _ hB =>
    have hb : (B₁.bytes i).erase = (B₂.bytes i).erase := hB.bytes i
    rw [hp] at hb
    have hp₁ : B₁.bytes i = .ptr p j := by
      generalize B₁.bytes i = x at hb
      cases x <;> simp_all [MemByte.erase]
    exact hk.1 (hm c B₁ i p j hx ((congrArg Block.size hB.shape :) ▸ hi) hp₁)

/-- **T3b's start lemma.** For every labelling, payload blocks, program, kernel, launch,
arguments, address choice and two oracles, the starts on two caller memories related by
`Mem.SkelEq` give one fault, or grids related by `Grid.SkelRel` and contexts that differ only in
their oracles. The start reads the caller's memory only in `Mem.checkClosed` (`next`, which blocks
exist, their sizes and pointer bytes) and through `withAttrs` (the shape), and allocates at
`next`; its threads read no memory. -/
theorem Grid.start_skel {lab : Labels} {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂)
    (prog : Program) (fn : Func) (L : Launch) (args : List Val) (ch : Nat → Nat)
    (o₁ o₂ : Nat → Nat → Nat) :
    Except.Rel (fun r₁ r₂ : Grid × (Nat → Ctx) => r₁.1.SkelRel lab pay r₂.1 ∧
        ∀ n, r₂.2 n = { r₁.2 n with oracle := (r₂.2 n).oracle })
      (Grid.start prog fn L args m₁ ch o₁) (Grid.start prog fn L args m₂ ch o₂) := by
  unfold Grid.start
  dsimp only
  refine Except.Rel.bind_eq _ fun _ _ => ?_
  rw [Mem.checkClosed_skel h]
  refine Except.Rel.bind_eq _ fun _ _ => ?_
  refine Except.Rel.bind (R := fun r₁ r₂ : Mem × List (List (String × Ptr)) =>
    r₁.1.SkelEq pay r₂.1 ∧ r₁.2 = r₂.2) ?_ fun x y hxy => ?_
  · refine Except.Rel.foldlM (fun b _ x y hxy => ?_) ⟨h, rfl⟩
    obtain ⟨a₁, acc⟩ := x
    obtain ⟨a₂, acc'⟩ := y
    obtain ⟨ha, rfl⟩ := hxy
    dsimp only
    exact Except.Rel.bind (shared_skel ha ..) fun x y hxy => by
      obtain ⟨x₁, t⟩ := x
      obtain ⟨x₂, t'⟩ := y
      obtain ⟨hx, rfl⟩ := hxy
      exact .ok ⟨hx, rfl⟩
  obtain ⟨a₁, tabs⟩ := x
  obtain ⟨a₂, tabs'⟩ := y
  obtain ⟨ha, rfl⟩ := hxy
  dsimp only
  refine Except.Rel.bind (R := fun r₁ r₂ : Mem × Array Status =>
    r₁.1.SkelEq pay r₂.1 ∧ r₁.2 = r₂.2) ?_ fun x y hxy => ?_
  · refine Except.Rel.foldlM (fun k _ x y hxy => ?_) ⟨ha, rfl⟩
    obtain ⟨a₁, ts⟩ := x
    obtain ⟨a₂, ts'⟩ := y
    obtain ⟨ha, rfl⟩ := hxy
    dsimp only
    refine Except.Rel.bind (launchArgs_skel ha ..) fun x y hxy => ?_
    obtain ⟨x₁, vs⟩ := x
    obtain ⟨x₂, vs'⟩ := y
    obtain ⟨hx, rfl⟩ := hxy
    dsimp only
    exact Except.Rel.bind (.refl (fun _ => rfl) _) fun _ _ e => by
      subst e
      exact .ok ⟨hx, rfl⟩
  obtain ⟨a₁, ts⟩ := x
  obtain ⟨a₂, ts'⟩ := y
  obtain ⟨ha, rfl⟩ := hxy
  refine .ok ⟨⟨fun _ => .refl (Status.Skel.refl lab) _, ?_⟩, fun _ => rfl⟩
  simp only [Mem.compact_eq]
  exact ⟨ha.next, rfl, ha.blocks⟩

/-- Results that agree under `S` agree under `S'` if `S` implies `S'` at every grid the first
result gives. -/
theorem Grid.Agree.imp {S S' : Grid → Grid → Prop} {a b : Except Fault (Option Grid)}
    (h : Grid.Agree S a b) (hS : ∀ g₁ g₂, a = .ok (.some g₁) → S g₁ g₂ → S' g₁ g₂) :
    Grid.Agree S' a b := by
  rcases a with _ | (_ | g₁) <;> rcases b with _ | (_ | g₂)
  all_goals first | exact hS g₁ g₂ rfl h | exact h

/-- Grids related by `Grid.SkelRel` are done together (the core's `Done` at `sig`), for every launch
and contexts: related statuses have one constructor. -/
theorem Grid.SkelRel.done {lab : Labels} {pay : Nat → Prop} {L : Launch} {c₁ c₂ : Nat → Ctx}
    {g₁ g₂ : Grid} (h : g₁.SkelRel lab pay g₂) :
    GPUProof.Done sig (g₁, L, c₁) ↔ GPUProof.Done sig (g₂, L, c₂) := by
  rw [Grid.done_iff, Grid.done_iff]
  refine forall_congr' fun n => imp_congr_right fun _ => ?_
  have ht := h.threads n
  generalize g₁.threads[n]? = s₁ at ht ⊢
  generalize g₂.threads[n]? = s₂ at ht ⊢
  cases ht with
  | none => simp
  | @some a b hs => cases a <;> cases b <;> first | exact (hs : False).elim | simp

/-- **T3b's lockstep.** For every labelling `lab`, payload blocks `pay`, program `prog` that
passes `Labels.Ok` under `lab`, kernel `fn` that is the module's function of its name, launch,
arguments, memory, address choice and oracle whose start gives grid `g₁` and contexts `c₁`, if
every grid reachable from `g₁` meets `Labels.MemAll` (`Labels.MemOk`), then for all contexts `c₂`
that differ from `c₁` only in their oracles, relating the grids reachable from `g₁` to grids by
`Grid.SkelRel` is a lockstep bisimulation of `c₁` and `c₂` (`Grid.Lockstep`). The reachable grids
meet `Grid.FramesOk` (`Grid.start_reach_framesOk`) and `Grid.AtCalls` (`Grid.start_reach_atCalls`),
and their contexts have the program `prog` (`Grid.start_ctx`), so `Grid.advance_skel` and
`Grid.fire_skel` give `advance` and `fire`, and `Thread.pending_skel` gives `race`. -/
theorem Grid.skel_lockstep {lab : Labels} {pay : Nat → Prop} {prog : Program} {fn : Func}
    {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat}
    {g₁ : Grid} {c₁ c₂ : Nat → Ctx} (h : Grid.start prog fn L args m ch oracle = .ok (g₁, c₁))
    (hL : Labels.Ok prog lab = true) (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn)
    (hM : lab.MemOk pay L c₁ g₁) (hc : ∀ n, c₂ n = { c₁ n with oracle := (c₂ n).oracle }) :
    Grid.Lockstep L c₁ c₂ fun x y => Relation.ReflTransGen (Grid.Step L c₁) g₁ x ∧
      x.SkelRel lab pay y where
  advance := by
    rintro x y ⟨hr, hg⟩ n
    have hp := (Grid.start_ctx h n).1
    refine Grid.Agree.imp (Grid.advance_skel hc hg n (by rw [hp]; exact hL) (fun t ht => ?_)
      (hM x hr)) fun _ _ e hs => ⟨hr.tail ⟨n, .inl e⟩, hs⟩
    rw [hp]
    exact Grid.start_reach_framesOk h hL hfn hr n _ ht
  fire := by
    rintro x y ⟨hr, hg⟩ n
    exact Grid.Agree.imp (Grid.fire_skel hc (fun n => (Grid.start_ctx h n).1) hL hg
      (Grid.start_reach_framesOk h hL hfn hr) (Grid.start_reach_atCalls h hr) n)
      fun _ _ e hs => ⟨hr.tail ⟨n, .inr e⟩, hs⟩
  done h := h.2.done
  trace h := h.2.mem.trace
  race := by
    rintro x y ⟨hr, hg⟩
    have hw := Grid.start_reach_framesOk h hL hfn hr
    rw [Grid.raceEnabled_iff, Grid.raceEnabled_iff]
    refine or_congr (exists_congr fun n => ?_) (exists_congr fun n => ?_)
    · have hp := (Grid.start_ctx h n).1
      have ht := hg.threads n
      have hwn := hw n
      rw [hc n, ← hg.mem.trace]
      generalize x.threads[n]? = s₁ at ht hwn ⊢
      generalize y.threads[n]? = s₂ at ht ⊢
      cases ht with
      | none => simp
      | @some a b hs =>
      cases a <;> cases b
      all_goals try exact (hs : False).elim
      all_goals try (simp; done)
      rename_i t₁ t₂
      simp only [Option.some.injEq, Status.run.injEq, exists_eq_left']
      rw [Thread.pending_skel (c := c₁ n) hs hg.mem (by rw [hp]; exact hL)
        (by rw [hp]; exact hwn _ rfl)]
    · have ha := Grid.fire_skel (L := L) hc (fun n => (Grid.start_ctx h n).1) hL hg hw
        (Grid.start_reach_atCalls h hr) n
      rw [← hg.mem.trace]
      generalize x.fire L c₁ n = r₁ at ha ⊢
      generalize y.fire L c₂ n = r₂ at ha ⊢
      rcases r₁ with _ | _ | _ <;> rcases r₂ with _ | _ | _ <;>
        first | exact (ha : False).elim | simp

/-- **T3b's run.** For every labelling `lab`, payload blocks `pay`, program `prog` that passes
`Labels.Ok` under `lab`, kernel `fn` that is the module's function of its name, launch, arguments,
address choice, two caller memories related by `Mem.SkelEq` the first of which names only known
numbers in its pointer bytes, and two oracles: if the start on the first memory and oracle gives
grid `g₁` and contexts `c₁` whose reachable grids meet `Labels.MemAll` (`Labels.MemOk`), and a run
of `k` steps from `g₁` ends at a done grid `z₁` that is not bad, then the start on the second
memory and oracle gives a grid `g₂` and contexts `c₂`, a run of `k` steps from `g₂` ends at a done
grid `z₂` that is not bad and is related to `z₁` by `Grid.SkelRel` (one control state, the same
memory but for the data bytes of the blocks `pay`), and `g₂` is sound for every observation of
the blocks and every relation that `z₂`'s observation satisfies (`Grid.Sound`). By
`Grid.start_skel`, `Grid.skel_lockstep` and `Grid.payload_run`. -/
theorem Grid.skel_run {lab : Labels} {pay : Nat → Prop} {prog : Program} {fn : Func}
    {L : Launch} {args : List Val} {m₁ m₂ : Mem} {ch : Nat → Nat} {o₁ o₂ : Nat → Nat → Nat}
    {g₁ : Grid} {c₁ : Nat → Ctx} (h : Grid.start prog fn L args m₁ ch o₁ = .ok (g₁, c₁))
    (hm : m₁.SkelEq pay m₂) (hk : m₁.BytesIn m₁.Known) (hL : Labels.Ok prog lab = true)
    (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn) (hM : lab.MemOk pay L c₁ g₁)
    {k : Nat} {z₁ : Grid} (run : Path (Grid.Step L c₁) k g₁ z₁)
    (hz : GPUProof.Done sig (z₁, L, c₁)) (hb : ¬ GPUProof.Bad sig (z₁, L, c₁)) :
    ∃ g₂ c₂ z₂, Grid.start prog fn L args m₂ ch o₂ = .ok (g₂, c₂) ∧
      Path (Grid.Step L c₂) k g₂ z₂ ∧ GPUProof.Done sig (z₂, L, c₂) ∧
      ¬ GPUProof.Bad sig (z₂, L, c₂) ∧ z₁.SkelRel lab pay z₂ ∧
      ∀ {β : Type} {obs : Mem → Option β} {R : β → Prop},
        (∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') →
        ∀ {y : β}, obs z₂.mem = some y → R y → Grid.Sound L c₂ g₂ obs R := by
  have hs := Grid.start_skel (lab := lab) hm prog fn L args ch o₁ o₂
  rw [h] at hs
  generalize e : Grid.start prog fn L args m₂ ch o₂ = r at hs
  cases hs with
  | @ok _ r₂ hr =>
  obtain ⟨g₂, c₂⟩ := r₂
  obtain ⟨hg, hc⟩ := hr
  obtain ⟨z₂, p, hz₂, hb₂, ⟨-, hr⟩, hs⟩ := Grid.payload_run e (hm.bytesIn hk)
    (Grid.skel_lockstep h hL hfn hM hc) ⟨.refl, hg⟩ run hz hb
  exact ⟨g₂, c₂, z₂, rfl, p, hz₂, hb₂, hr, hs⟩

/-- **The seventh field from one final grid.** For every launch, contexts and grid that meets the
first six fields of `Grid.Sound` with the blocks as observation (`R := True`, which every grid in
which every thread has returned meets), every observation `obs` that reads only the blocks and
every relation `R`: one reachable grid in which every thread has returned and whose observation
`y` satisfies `R` makes the grid sound for `obs` and `R`, since every such grid has its blocks. -/
theorem Grid.Sound.of_blocks {L : Launch} {c : Nat → Ctx} {g : Grid} {β : Type}
    {obs : Mem → Option β} {R : β → Prop}
    (h : Grid.Sound L c g (fun m => some m.blocks) (fun _ => True))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') {z : Grid}
    (hz : Relation.ReflTransGen (Grid.Step L c) g z) (hd : GPUProof.Done sig (z, L, c)) {y : β}
    (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g obs R where
  safe := h.safe
  raceFree := h.raceFree
  kept := h.kept
  progress := h.progress
  terminates := h.terminates
  determinate g₁ g₂ h₁ h₂ d₁ d₂ := hO _ _ (Option.some.inj (h.determinate g₁ g₂ h₁ h₂ d₁ d₂))
  post g' hr hd' := ⟨y, (hO _ _ (Option.some.inj (h.determinate g' z hr hz hd' hd))).trans hy, hR⟩

/-- **The six fields from one run of the skeleton (T3 for the unit payload).** For every
labelling `lab`, payload blocks `pay`, program `prog` that passes `Labels.Ok` under `lab`, kernel
`fn` that is the module's function of its name, launch, arguments, address choice `ch`, caller
memory `m₁` that names only known numbers in its pointer bytes and oracle `o₁`: if the start on
`m₁` and `o₁` gives grid `g₁` and contexts `c₁` whose reachable grids meet `Labels.MemAll`
(`Labels.MemOk`), and one run from `g₁` ends at a grid `z₁` in which every thread has returned and
that is not bad, then for every memory `m₂` related to `m₁` by `Mem.SkelEq pay` (any payload: the
data bytes of the blocks `pay`) and every oracle `o₂`, the start on `m₂` and `o₂` gives a grid
that is safe, race free, keeps the promise of `!invariant.load`, makes progress, terminates and
is determinate for the blocks: the first six fields of `Grid.Sound` with the blocks as
observation, and the seventh with `R := True`. The run is used only through `Grid.SkelRel`, `Done`
and `Bad`, never through a payload value; `Grid.Sound.of_blocks` adds the seventh field from one
final grid. By `Grid.skel_run`, which is by `Grid.payload_run`, `Grid.start_sound` and
`Grid.sound_of_one_run`. -/
theorem Grid.skel_six {lab : Labels} {pay : Nat → Prop} {prog : Program} {fn : Func}
    {L : Launch} {args : List Val} {m₁ : Mem} {ch : Nat → Nat} {o₁ : Nat → Nat → Nat}
    {g₁ : Grid} {c₁ : Nat → Ctx} (h : Grid.start prog fn L args m₁ ch o₁ = .ok (g₁, c₁))
    (hk : m₁.BytesIn m₁.Known) (hL : Labels.Ok prog lab = true)
    (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn) (hM : lab.MemOk pay L c₁ g₁)
    {z₁ : Grid} (run : Relation.ReflTransGen (Grid.Step L c₁) g₁ z₁)
    (hz : GPUProof.Done sig (z₁, L, c₁)) (hb : ¬ GPUProof.Bad sig (z₁, L, c₁)) {m₂ : Mem}
    (hm : m₁.SkelEq pay m₂) (o₂ : Nat → Nat → Nat) :
    ∃ g₂ c₂, Grid.start prog fn L args m₂ ch o₂ = .ok (g₂, c₂) ∧
      Grid.Sound L c₂ g₂ (fun m => some m.blocks) (fun _ => True) := by
  obtain ⟨_, p⟩ := Path.exists_iff.2 run
  obtain ⟨g₂, c₂, z₂, e, -, -, -, -, hs⟩ := Grid.skel_run (o₂ := o₂) h hm hk hL hfn hM p hz hb
  exact ⟨g₂, c₂, e, hs (fun _ _ h => by rw [h]) rfl trivial⟩

/-! ### The kernel theorem (docs/proofs/skel-kernel.md) -/

/-- **`Kernel.Sound` from one run per address choice.** For every labelling `lab`, payload blocks
`pay`, program `prog` that passes `Labels.Ok` under `lab`, kernel `fn` that is the module's
function of its name, launch, arguments, first memory `m₁` that names only known numbers in its
pointer bytes and set `A` of address choices: if at every `ch` in `A` some oracle `o₁` gives a
start on `m₁` with grid `g₁` and contexts `c₁` that meets `Labels.MemOk`, and one run from `g₁`
ends at a grid in which every thread has returned and that is not bad (no fault, no enabled race,
no data race in its trace, the promise of `!invariant.load` kept), then for every memory `m₂`
related to `m₁` by `Mem.SkelEq pay` the kernel on `m₂` is sound at every address choice in `A` and
every oracle, for the blocks and the trivial relation: under every schedule its grid is safe, race
free, keeps the promise of `!invariant.load`, makes progress, terminates and is determinate for the
blocks. With `A = (· = ch)` it is one run at one address choice. By `Grid.skel_six` at each
admitted address choice. -/
theorem Kernel.skel_sound {lab : Labels} {pay : Nat → Prop} {prog : Program} {fn : Func}
    {L : Launch} {args : List Val} {m₁ : Mem} (hk : m₁.BytesIn m₁.Known)
    (hL : Labels.Ok prog lab = true)
    (hfn : prog.module.funcs.find? (·.name == fn.name) = some fn) {A : (Nat → Nat) → Prop}
    (H : ∀ ch, A ch → ∃ o₁ g₁ c₁ z₁, Grid.start prog fn L args m₁ ch o₁ = .ok (g₁, c₁) ∧
      lab.MemOk pay L c₁ g₁ ∧ Relation.ReflTransGen (Grid.Step L c₁) g₁ z₁ ∧
      GPUProof.Done sig (z₁, L, c₁) ∧ ¬ GPUProof.Bad sig (z₁, L, c₁))
    {m₂ : Mem} (hm : m₁.SkelEq pay m₂) :
    Kernel.Sound prog fn L args m₂ (fun ch _ => A ch) (fun m => some m.blocks)
      (fun _ => True) := by
  intro ch o₂ ha
  obtain ⟨_, _, _, _, h, hM, run, hz, hb⟩ := H ch ha
  exact Grid.skel_six h hk hL hfn hM run hz hb hm o₂

/-- **The seventh field of `Kernel.Sound` from one final grid per admitted pair.** For every
program, kernel, launch, arguments, memory `m`, admission `adm`, observation `obs` that reads only
the blocks and relation `R`: if the kernel is sound for `adm`, the blocks and the trivial relation,
and at every admitted address choice and oracle the start's grid reaches one grid in which every
thread has returned and whose observation `y` satisfies `R`, then the kernel is sound for `adm`,
`obs` and `R`. By `Grid.Sound.of_blocks` at each admitted pair. -/
theorem Kernel.Sound.of_blocks {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop}
    (h : Kernel.Sound prog fn L args m adm (fun m => some m.blocks) (fun _ => True))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hR : ∀ ch o g c, adm ch o → Grid.start prog fn L args m ch o = .ok (g, c) →
      ∃ z, Relation.ReflTransGen (Grid.Step L c) g z ∧ GPUProof.Done sig (z, L, c) ∧
        ∃ y, obs z.mem = some y ∧ R y) :
    Kernel.Sound prog fn L args m adm obs R := by
  intro ch o ha
  obtain ⟨g, c, e, hs⟩ := h ch o ha
  obtain ⟨z, hz, hd, y, hy, hRy⟩ := hR ch o g c ha e
  exact ⟨g, c, e, hs.of_blocks hO hz hd hy hRy⟩

end MojoProof.Sem
