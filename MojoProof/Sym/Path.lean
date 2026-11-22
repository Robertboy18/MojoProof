import MojoProof.Sym.Block

/-!
# Soundness of the block checker along a path

The block theorem (`Block.sound`, MojoProof/Sym/Block.lean) along a path of the control-flow
graph: for every program, path and thread, the steps of a thread through blocks that the path
checker accepts.

`Block.sound_pathI`: `Block.sound` along a path of the control-flow graph of any length, for
every program `P`, function `fn` and path `(l, ds, S) :: ps` (blocks with their conditions and
summaries) that the path checker accepts (`coversPathI`: the first block from position `p0`,
each one after from the position its edge enters it at, `Exit.pc`: after its `phi`s for
`Exit.phi`, else 0; each block but the last by `covers`, or by `coversTo` for the edge into the
next block), every context of `P` and thread at block `l`'s position `p0`: if the
path's premises hold (`WalkI`: each block's conditions hold under its entry valuation, which is
`Valuation.into` of the block before, with the step count after its statements and branch, the
memory of its effects, and its registers and `fmul contract` operands with the target's `phi`s
set as `enter` sets them; each exit but the last goes to the next block, `Exit.dest`), the
thread's steps run every block, each edge by `Ends.edge`, and the last one ends from its entry
valuation (`Valuation.lastI`), at step count `t.k + pathLen S ps` (`Valuation.lastI_k`).
`Block.sound_retR`: a path whose last block returns (`ret void`), under any caller frames: its steps
reach the last block's end, on the memory the last block's effects make, and the next step is the
`ret`'s: `.done` without a caller (`rest = []`, a thread with one frame), else back to the
caller after its call. `Ret`: a path whose premises with `phi`s hold, whose last exit is `ret` and
whose last block's effects succeed with a memory of a predicate `Q` (used by the loop theorems,
Sym/Loop.lean, and the kernel theorem, Sym/Kernel.lean). `Block.sound_back`: then the
caller's block from the position after the call ends too (`Block.sound` there). `Block.sound_path`
and `Block.sound_ret` are their corollaries for the path checker without `phi`s (`coversPath`,
`Walk`, `Valuation.last`), through `Walk.toI`: there every exit has a target (`Exit.target`), whose
step enters it at position 0 and resolves no `phi` (`Exit.next_target`), and `Valuation.into` is
`Valuation.after` (`Exit.of_target`).

With `fmul contract`: `Valuation.afterC` and `Valuation.intoC` are `Valuation.after` and
`Valuation.into` with the table's `fmul contract` operands (`regProdIn`), and `Ends.edgeC` is
`Ends.edge` from `EndsC`. Each pair is the instance with and without `contract` of one
declaration (`prodsWith`, `Valuation.afterWith`, `Valuation.intoWith`, `EndsWith`,
`Ends.edgeWith`, `EndsWith.pre`), proved once. `Block.sound_pathC`: a path that `coversPathI`
accepts, then the block its last exit goes to, accepted by `coversC`: it ends (`EndsC`) from
`Valuation.into` of the path's last block.

The path checker with a flag `contract`: `coversPathWith`, `WalkWith`, `Valuation.lastWith`,
`Valuation.blocksWith` and `RetWith` check every block with `coversWith … contract` and enter
every block after the first with `Valuation.intoWith contract`; without the flag they are
`coversPathI`, `WalkI`, `Valuation.lastI`, `Valuation.blocksI` and `Ret`, definitionally (two
structural recursions with the same cases; the elaborator sees it with `smartUnfolding` off).
`Block.sound_toWith`, `Valuation.lastWith_k`, `Block.sound_pathWith_ptrs` and
`Block.sound_retWith` are proved once, for both values of the flag; `Block.sound_to`,
`Valuation.lastI_k`, `Block.sound_pathI_ptrs` and `Block.sound_retR` are their instances without
it, one line each.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-! ## Along a path -/

/-- The block exit `x` goes to, given the values `vs` of the nodes: a branch's target, the
target a conditional branch's condition selects (`none` when it is not a word), and `none` for
`ret void` and for branches into blocks with `phi`s (`Exit.dest` gives their targets). -/
def Exit.target (V : Valuation) (vs : List (Except Fault Val)) : Exit → Option Nat
  | .br d => some d
  | .cond x d e => match x.eval V vs with
    | .ok (.bits _ b) => some (if b.getLsbD 0 then d else e)
    | _ => none
  | .ret => none
  | .phi .. => none

/-- The valuation at the entry of the block that summary `S` exits to, from valuation `V` at its
entry: the step count after the block's `S.len` statements and its branch, the memory the
summary's effects make (`V`'s memory if they fault), and the registers and `fmul contract`
operands the summary gives (`regVal`, `regProd`); the context and function are `V`'s. -/
def Valuation.after (V : Valuation) (S : Summary) : Valuation :=
  ⟨V.ctx, V.fn, V.k + S.len + 1, (SEff.run V (vals V S.nodes) S.effs).toOption.getD V.mem,
    regVal V (vals V S.nodes) S.regs, regProd V S.regs⟩

/-- The block exit `x` goes to, given the values `vs` of the nodes: `Exit.target`'s, and for a
branch into blocks with `phi`s the target its condition selects (`none` when it is not a
word). -/
def Exit.dest (V : Valuation) (vs : List (Except Fault Val)) : Exit → Option Nat
  | .phi x d e => match x.eval V vs with
    | .ok (.bits _ b) => some (if b.getLsbD 0 then d else e)
    | _ => none
  | x => x.target V vs

/-- The position at which exit `x`'s step enters block `d` of `fn`: after the `phi`s
(`phiCount`) for a branch into blocks with `phi`s, 0 otherwise. -/
def Exit.pc (fn : Func) (d : Nat) : Exit → Nat
  | .phi .. => phiCount fn d
  | _ => 0

/-- `SState.exitAt_sound` for `SState.exitTo`, the exit with the obligations of the edge into
block `d₀` only: when the exit goes to `d₀` (`Exit.dest`), the terminator's step is the exit's. -/
theorem SState.exitTo_sound {V : Valuation} {vs : List (Except Fault Val)} {f fe : Frame}
    {σ : SState} {me : Mem} (hR : Rel V vs f σ fe me) {b : LLVM.Block} {rest : List Frame}
    {k : Nat} (hb : fe.fn.blocks.find? (·.label == fe.label) = some b)
    (hpc : ¬ fe.pc < b.stmts.size) {d₀ : Nat} {x : Exit} {cs : List Cond}
    (hx : σ.exitTo fe.fn fe.label d₀ b.term = some (x, cs)) (hcs : ∀ d ∈ cs, d.Holds V vs)
    (hd : x.dest V vs = some d₀) :
    ∃ r, x.next V vs rest k fe me = .ok r ∧ step V.ctx ⟨fe :: rest, k⟩ me = .ok r := by
  unfold SState.exitTo at hx
  cases he : σ.exit fe.fn b.term with
  | some y =>
    rw [he] at hx
    cases hx
    exact SState.exit_sound hR hb hpc he hcs
  | none =>
    rw [he] at hx
    change σ.phiExitTo fe.fn fe.label d₀ b.term = some (x, cs) at hx
    unfold SState.phiExitTo at hx
    split at hx
    · rename_i cv d e hterm
      split at hx
      · rename_i y c₀ hy h₀
        cases hx
        obtain ⟨w, bv, hv⟩ := hcs (.bool y) (List.Mem.head _)
        have hcv := SState.op_eval hR (s := V.ctx.scope me fe k) rfl hy hv
        have hd' : (if bv.getLsbD 0 then d else e) = d₀ := by
          simpa only [Exit.dest, hv, Option.some.injEq] using hd
        rw [← hd'] at h₀
        obtain ⟨f', hf'⟩ := SState.enter_ok hR (s := V.ctx.scope me fe k) rfl h₀
          fun c hc => hcs c (List.mem_cons_of_mem _ hc)
        refine ⟨.next ⟨f' :: rest, k + 1⟩ me, ?_, ?_⟩
        · (simp only [Exit.next, hv, hf', bind, Except.bind, pure, Except.pure])
        · (simp only [step, hb, hpc, ↓reduceDIte, hterm, hcv, hf', bind, Except.bind, pure,
            Except.pure])
      · cases hx
    · exact SState.exitAt_sound hR hb hpc (by unfold SState.exitAt; rw [he]; exact hx) hcs

/-- **Soundness of the block checker for one edge, with or without `fmul contract`**: for every
flag `contract`, `Block.sound_atWith` for a block that `coversWith` accepts with
`SState.exitTo` for the edge into block `d₀` (with the obligations of that edge only), when its
exit goes to `d₀` (`Exit.dest`) from the entry valuation: the block ends (`EndsWith contract`)
and its pointer facts hold (`Ptrs`). For every program, function, block, position, target,
conditions, summary, context of the program and thread at the block's position
(`Block.sound_with`, `SState.exitTo_sound`). -/
theorem Block.sound_toWith {contract : Bool} {P : Program} {fn : Func} {lbl p0 d₀ : Nat}
    {ds : List Cond} {S : Summary}
    (hc : coversWith P fn lbl p0 (fun σ tm => σ.exitTo fn lbl d₀ tm) ds S contract = true)
    {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes))
    (hd : S.exit.dest (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) =
      some d₀) :
    EndsWith contract c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_with (ex := fun σ tm => σ.exitTo fn lbl d₀ tm) hc hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitTo_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs hd

/-- **Soundness of the block checker for one edge**: `Block.sound` for a block that `coversTo`
accepts for the edge into block `d₀` (with the obligations of that edge only), when its exit goes
to `d₀` (`Exit.dest`) from the entry valuation, with its pointer facts (`Ptrs`). For every
program, function, block, position, target, conditions, summary, context of the program and
thread at the block's position (`Block.sound_toWith` without `fmul contract`). -/
theorem Block.sound_to {P : Program} {fn : Func} {lbl p0 d₀ : Nat} {ds : List Cond}
    {S : Summary} (hc : coversTo P fn lbl p0 d₀ ds S = true) {c : Ctx} (hP : c.prog = P)
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes))
    (hd : S.exit.dest (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) =
      some d₀) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_toWith (contract := false) hc hP ht hfn hl hp hds hd

/-- The frame at the end of block `l` that summary `S` describes from valuation `V`: `V`'s
function, the registers and `fmul contract` operands of `Valuation.after`, position 0, no
`alloca` blocks and no caller's register (`enter` reads none of these three). -/
def Valuation.frameAt (V : Valuation) (l : Nat) (S : Summary) : Frame :=
  { fn := V.fn, label := l, pc := 0, regs := (V.after S).regs, prods := (V.after S).prods,
    allocas := [], dest := none }

/-- The valuation at the entry of the block that the exit of summary `S` of block `l` goes to,
from valuation `V` at its entry: `Valuation.after`, whose registers and `fmul contract`
operands are, for a branch into blocks with `phi`s (`Exit.phi`), those of the frame `enter`
gives from `Valuation.frameAt`, with the target's `phi`s set. -/
def Valuation.into (V : Valuation) (l : Nat) (S : Summary) : Valuation :=
  match S.exit, S.exit.dest V (vals V S.nodes) with
  | .phi .., some d =>
    match enter (V.ctx.scope (V.after S).mem (V.frameAt l S) (V.k + S.len)) (V.frameAt l S) d with
    | .ok f => { V.after S with regs := f.regs, prods := f.prods }
    | .error _ => V.after S
  | _, _ => V.after S

/-- `Valuation.after` with the `fmul contract` operands `prodsWith contract`: without
`contract` it is `Valuation.after`, with it `Valuation.afterC`. -/
def Valuation.afterWith (contract : Bool) (V : Valuation) (S : Summary) : Valuation :=
  { V.after S with prods := prodsWith contract V S }

/-- **The valuation after a block with `fmul contract`**: `Valuation.after`, with the
`fmul contract` operands the table gives (`regProdIn`), as at the end of a block that `coversC`
accepts (`EndsC`, `Block.soundC`). For every valuation and summary. -/
def Valuation.afterC (V : Valuation) (S : Summary) : Valuation := V.afterWith true S

/-- `Valuation.frameAt` with the registers and `fmul contract` operands of
`Valuation.afterWith contract`. -/
def Valuation.frameAtWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) : Frame :=
  { fn := V.fn, label := l, pc := 0, regs := (V.afterWith contract S).regs,
    prods := (V.afterWith contract S).prods, allocas := [], dest := none }

/-- `Valuation.into` from `Valuation.afterWith contract` and `Valuation.frameAtWith contract`:
without `contract` it is `Valuation.into`, with it `Valuation.intoC`. -/
def Valuation.intoWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) : Valuation :=
  match S.exit, S.exit.dest V (vals V S.nodes) with
  | .phi .., some d =>
    match enter (V.ctx.scope (V.afterWith contract S).mem (V.frameAtWith contract l S)
        (V.k + S.len)) (V.frameAtWith contract l S) d with
    | .ok f => { V.afterWith contract S with regs := f.regs, prods := f.prods }
    | .error _ => V.afterWith contract S
  | _, _ => V.afterWith contract S

/-- **The valuation at the entry of the block that a block with `fmul contract` exits to**:
`Valuation.into` from `Valuation.afterC`, whose `fmul contract` operands are the table's
(`regProdIn`); for a branch into blocks with `phi`s (`Exit.phi`), the registers and
`fmul contract` operands of the frame `enter` gives, with the target's `phi`s set. For every
valuation, block and summary; `Ends.edgeC` enters it. -/
def Valuation.intoC (V : Valuation) (l : Nat) (S : Summary) : Valuation := V.intoWith true l S

/-- An exit with a target (`Exit.target`, so not `Exit.phi`): `Exit.dest` gives it, its step
enters at position 0, and `Valuation.intoWith contract` is `Valuation.afterWith contract`, with
or without `contract`. -/
theorem Exit.of_targetWith {V : Valuation} {l d : Nat} {S : Summary} (contract : Bool)
    (h : S.exit.target V (vals V S.nodes) = some d) :
    S.exit.dest V (vals V S.nodes) = some d ∧ (∀ fn d', S.exit.pc fn d' = 0) ∧
      V.intoWith contract l S = V.afterWith contract S := by
  unfold Valuation.intoWith
  cases hx : S.exit with
  | phi => rw [hx] at h; cases h
  | ret => rw [hx] at h; cases h
  | br => rw [hx] at h; exact ⟨h, fun _ _ => rfl, rfl⟩
  | cond => rw [hx] at h; exact ⟨h, fun _ _ => rfl, rfl⟩

/-- An exit with a target (`Exit.target`, so not `Exit.phi`): `Exit.dest` gives it, its step
enters at position 0, and `Valuation.into` is `Valuation.after` (`Exit.of_targetWith` without
`contract`). -/
theorem Exit.of_target {V : Valuation} {l d : Nat} {S : Summary}
    (h : S.exit.target V (vals V S.nodes) = some d) :
    S.exit.dest V (vals V S.nodes) = some d ∧ (∀ fn d', S.exit.pc fn d' = 0) ∧
      V.into l S = V.after S :=
  Exit.of_targetWith (l := l) false h

/-- `Valuation.intoWith contract` keeps the context and the function, and its step count is
`Valuation.after`'s, with or without `contract`. -/
theorem Valuation.intoWith_k (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    (V.intoWith contract l S).ctx = V.ctx ∧ (V.intoWith contract l S).fn = V.fn ∧
      (V.intoWith contract l S).k = V.k + S.len + 1 := by
  unfold Valuation.intoWith
  split
  · split <;> exact ⟨rfl, rfl, rfl⟩
  · exact ⟨rfl, rfl, rfl⟩

/-- `Valuation.into` keeps the context and the function, and its step count is
`Valuation.after`'s (`Valuation.intoWith_k` without `contract`). -/
theorem Valuation.into_k (V : Valuation) (l : Nat) (S : Summary) :
    (V.into l S).ctx = V.ctx ∧ (V.into l S).fn = V.fn ∧ (V.into l S).k = V.k + S.len + 1 :=
  Valuation.intoWith_k false V l S

/-- An exit with target `d`: its step enters block `d` at position 0 (`Exit.br` and
`Exit.cond` go to blocks without `phi`s), with the frame's other fields and the memory
unchanged. -/
theorem Exit.next_target {V : Valuation} {vs : List (Except Fault Val)} {rest : List Frame}
    {k : Nat} {fe : Frame} {me : Mem} {x : Exit} {d : Nat} {r : Step}
    (h : x.target V vs = some d) (hn : x.next V vs rest k fe me = .ok r) :
    r = .next ⟨{ fe with label := d, pc := 0 } :: rest, k + 1⟩ me := by
  cases x with
  | br d' =>
    simp only [Exit.target, Option.some.injEq] at h
    subst h
    simp only [Exit.next, pure, Except.pure, Except.ok.injEq] at hn
    exact hn.symm
  | cond y d' e' =>
    simp only [Exit.target] at h
    split at h
    · rename_i w b hy
      simp only [Option.some.injEq] at h
      subst h
      simp only [Exit.next, hy, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hn
      exact hn.symm
    · cases h
  | ret => cases h
  | phi => cases h

/-- Steps, a step that continues the thread, then the end of a block from the thread after it
(`EndsWith contract`), whose frame keeps the `alloca` blocks and caller's register of `f`: the
block ends from the first thread too, with or without `contract`. -/
theorem EndsWith.pre {contract : Bool} {c : Ctx} {t t₁ t₂ : Thread} {m m₁ m₂ : Mem}
    {f f₂ : Frame} {rest : List Frame} {q : Valuation × Nat × Summary} (h₁ : Steps c t m t₁ m₁)
    (h : step c t₁ m₁ = .ok (.next t₂ m₂)) (hq : EndsWith contract c t₂ m₂ f₂ rest q)
    (hal : f₂.allocas = f.allocas) (hde : f₂.dest = f.dest) :
    EndsWith contract c t m f rest q := by
  obtain ⟨V, lbl, S⟩ := q
  obtain ⟨fe, me, hS, hfn, hl, hal', hde', hr, hpr, hm, r, hn, hst⟩ := hq
  exact ⟨fe, me, Steps.trans_step h₁ h hS, hfn, hl, hal'.trans hal, hde'.trans hde, hr, hpr, hm, r,
    hn, hst⟩

/-- Steps, a step that continues the thread, then the end of a block from the thread after it,
whose frame keeps the `alloca` blocks and caller's register of `f`: the block ends from the
first thread too (`EndsWith.pre` without `contract`). -/
theorem Ends.pre {c : Ctx} {t t₁ t₂ : Thread} {m m₁ m₂ : Mem} {f f₂ : Frame} {rest : List Frame}
    {q : Valuation × Nat × Summary} (h₁ : Steps c t m t₁ m₁) (h : step c t₁ m₁ = .ok (.next t₂ m₂))
    (hq : Ends c t₂ m₂ f₂ rest q) (hal : f₂.allocas = f.allocas) (hde : f₂.dest = f.dest) :
    Ends c t m f rest q := by
  obtain ⟨V, lbl, S⟩ := q
  exact EndsWith.pre (contract := false) (q := (V, lbl, S)) h₁ h hq hal hde

/-- **An edge, with or without `fmul contract`**: block `l` with summary `S` ends with the
`fmul contract` operands `prodsWith contract` (`EndsWith`) and its exit goes to block `d`
(`Exit.dest`): the branch's step enters block `d` at position `S.exit.pc V.fn d` (after its
`phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s function whose `alloca`
blocks and caller's register are those of `f` and whose entry valuation is
`V.intoWith contract l S`. `Ends.edge` and `Ends.edgeC` are its instances. -/
theorem Ends.edgeWith {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c)
    (h : EndsWith contract c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.intoWith contract l S := by
  subst hc
  obtain ⟨fe, me, hS, hfn, hl, hal, hde, hr, hpr, hm, r, hn, hst⟩ := h
  have e1 : fe.regs = regVal V (vals V S.nodes) S.regs := funext hr
  have e2 : fe.prods = prodsWith contract V S := funext hpr
  have nophi (ht : S.exit.target V (vals V S.nodes) = some d) :
      ∃ t₁ m₁ f', Steps V.ctx t m t₁ m₁ ∧
        step V.ctx t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
        f'.label = d ∧ f'.pc = 0 ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
        Valuation.entry V.ctx (V.k + S.len + 1) m₁ f' = V.intoWith contract l S := by
    obtain rfl := Exit.next_target ht hn
    refine ⟨_, me, { fe with label := d, pc := 0 }, hS, hst, hfn, rfl, rfl, hal, hde, ?_⟩
    rw [(Exit.of_targetWith contract ht).2.2, Valuation.afterWith, Valuation.after, hm]
    simp only [Valuation.entry, Except.toOption, Option.getD, e1, e2, hfn]
  cases hx : S.exit
  case phi y d₁ e₁ =>
    rw [hx] at hd hn
    simp only [Exit.dest] at hd
    split at hd
    · rename_i w b hy
      simp only [Option.some.injEq] at hd
      subst hd
      simp only [Exit.next, hy, bind, Except.bind] at hn
      generalize he : enter _ _ _ = q at hn
      cases q with
      | error => cases hn
      | ok f' =>
        simp only [pure, Except.pure, Except.ok.injEq] at hn
        subst hn
        obtain ⟨hf1, hf2, hf3, hf4, hf5⟩ := enter_fields he
        have hg := enter_congr he (g := V.frameAtWith contract l S) hfn.symm hl.symm e1.symm
          e2.symm
        have hs : V.ctx.scope (V.afterWith contract S).mem (V.frameAtWith contract l S)
            (V.k + S.len) = V.ctx.scope me fe (V.k + S.len) := by
          simp only [Ctx.scope, Valuation.afterWith, Valuation.after, Valuation.frameAtWith, hm,
            Except.toOption, Option.getD, e1]
        have hi : V.intoWith contract l S =
            { V.afterWith contract S with regs := f'.regs, prods := f'.prods } := by
          unfold Valuation.intoWith
          rw [hx]
          simp only [Exit.dest, hy, hs, hg]
        refine ⟨_, me, f', hS, hst, hf1.trans hfn, hf2, by rw [hf3, hfn]; rfl, hf4.trans hal,
          hf5.trans hde, ?_⟩
        rw [hi]
        simp only [Valuation.entry, Valuation.afterWith, Valuation.after, hf1, hfn, hm,
          Except.toOption, Option.getD]
    · cases hd
  all_goals
    obtain ⟨t₁, m₁, f', h1, h2, h3, h4, h5, h6, h7, h8⟩ := nophi (by rw [hx] at hd ⊢; exact hd)
    exact ⟨t₁, m₁, f', h1, h2, h3, h4, h5, h6, h7, h8⟩

/-- **An edge**: block `l` with summary `S` ends (`Ends`) and its exit goes to block `d`
(`Exit.dest`): the branch's step enters block `d` at position `S.exit.pc V.fn d` (after its
`phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s function whose `alloca`
blocks and caller's register are those of `f` and whose entry valuation is `V.into l S`
(`Ends.edgeWith` without `contract`). -/
theorem Ends.edge {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c) (h : Ends c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.into l S :=
  Ends.edgeWith (contract := false) (V := V) (l := l) (S := S) hc h hd

/-- **An edge with `fmul contract`**: block `l` with summary `S` ends with the table's
`fmul contract` operands (`EndsC`, as `Block.soundC` gives for a block that `coversC` accepts)
and its exit goes to block `d` (`Exit.dest`): the branch's step enters block `d` at position
`S.exit.pc V.fn d` (after its `phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s
function whose `alloca` blocks and caller's register are those of `f` and whose entry valuation
is `V.intoC l S`. For every context, thread, block and summary (`Ends.edgeWith` with
`contract`). -/
theorem Ends.edgeC {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c) (h : EndsC c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.intoC l S :=
  Ends.edgeWith (contract := true) (V := V) (l := l) (S := S) hc h hd

/-- **The path checker**: the blocks `(label, conditions, summary)` of a path, the first from
position `p0` and each one after from its entry, are each accepted by `covers`. -/
def coversPath (P : Program) (fn : Func) : Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, (l, ds, S) :: ps => covers P fn l p0 ds S && coversPath P fn 0 ps

/-- The premises of a path from valuation `V` at its first block's entry: each block's conditions
hold at its entry valuation (`Valuation.after` of the block before), and each block's exit but
the last goes to the next block's label (`Exit.target`). -/
def Walk (V : Valuation) : List (Nat × List Cond × Summary) → Prop
  | [] => True
  | [(_, ds, S)] => ∀ d ∈ ds, d.Holds V (vals V S.nodes)
  | (_, ds, S) :: (l, ds', S') :: ps => (∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.target V (vals V S.nodes) = some l ∧ Walk (V.after S) ((l, ds', S') :: ps)

/-- Whether a path's premises hold, decided by evaluating them (the kernel reduces it on a
concrete valuation). -/
instance Walk.dec (V : Valuation) : (ps : List (Nat × List Cond × Summary)) → Decidable (Walk V ps)
  | [] => isTrue trivial
  | [(_, ds, S)] => inferInstanceAs (Decidable (∀ d ∈ ds, d.Holds V (vals V S.nodes)))
  | (_, ds, S) :: (l, ds', S') :: ps =>
    have := Walk.dec (V.after S) ((l, ds', S') :: ps)
    inferInstanceAs (Decidable ((∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.target V (vals V S.nodes) = some l ∧ Walk (V.after S) ((l, ds', S') :: ps)))

/-- The last block of the path `(l, ds, S) :: ps` entered with valuation `V` at its first block:
its entry valuation (`Valuation.after` of each block before it), label and summary. -/
def Valuation.last (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.after S).last l' S' ps

/-- The number of steps of the path `S :: ps` to its last terminator: each block's statements,
and one step for each branch between them. -/
def pathLen (S : Summary) : List (Nat × List Cond × Summary) → Nat
  | [] => S.len
  | (_, _, S') :: ps => S.len + 1 + pathLen S' ps

/-- **The path checker with `phi`s**: `coversPath`, where each block after the first is
covered from the position its edge enters it at (`Exit.pc`: after its `phi`s for `Exit.phi`),
and each block but the last is accepted by `covers` or, with the obligations of its edge into the
next block only, by `coversTo`. -/
def coversPathI (P : Program) (fn : Func) : Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, [(l, ds, S)] => covers P fn l p0 ds S
  | p0, (l, ds, S) :: (l', ds', S') :: ps =>
    (covers P fn l p0 ds S || coversTo P fn l p0 l' ds S) &&
      coversPathI P fn (S.exit.pc fn l') ((l', ds', S') :: ps)

/-- The premises of a path with `phi`s from valuation `V` at its first block's entry: each
block's conditions hold at its entry valuation (`Valuation.into` of the block before), and each
block's exit but the last goes to the next block's label (`Exit.dest`). -/
def WalkI (V : Valuation) : List (Nat × List Cond × Summary) → Prop
  | [] => True
  | [(_, ds, S)] => ∀ d ∈ ds, d.Holds V (vals V S.nodes)
  | (l, ds, S) :: (l', ds', S') :: ps => (∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧ WalkI (V.into l S) ((l', ds', S') :: ps)

/-- Whether a path's premises hold, decided by evaluating them (the kernel reduces it on a
concrete valuation). -/
instance WalkI.dec (V : Valuation) :
    (ps : List (Nat × List Cond × Summary)) → Decidable (WalkI V ps)
  | [] => isTrue trivial
  | [(_, ds, S)] => inferInstanceAs (Decidable (∀ d ∈ ds, d.Holds V (vals V S.nodes)))
  | (l, ds, S) :: (l', ds', S') :: ps =>
    have := WalkI.dec (V.into l S) ((l', ds', S') :: ps)
    inferInstanceAs (Decidable ((∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧ WalkI (V.into l S) ((l', ds', S') :: ps)))

/-- The last block of the path `(l, ds, S) :: ps` with `phi`s entered with valuation `V` at its
first block: its entry valuation (`Valuation.into` of each block before it), label and
summary. -/
def Valuation.lastI (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.into l S).lastI l' S' ps

/-- The blocks of the path `(l, ds, S) :: ps` with `phi`s entered with valuation `V` at its first
block, in order, each with its entry valuation (`Valuation.into` of each block before it), label
and summary; `Valuation.lastI` is the last. -/
def Valuation.blocksI (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → List (Valuation × Nat × Summary)
  | [] => [(V, l, S)]
  | (l', _, S') :: ps => (V, l, S) :: (V.into l S).blocksI l' S' ps

/-- **The path checker with `phi`s, with or without `fmul contract`**: `coversPathI` with every
block accepted by `coversWith … contract`: the last at `SState.exitAt`, each other one at
`SState.exitAt` or at `SState.exitTo` the next block. Without `contract` it is `coversPathI`
(definitionally). -/
def coversPathWith (contract : Bool) (P : Program) (fn : Func) :
    Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, [(l, ds, S)] => coversWith P fn l p0 (fun σ tm => σ.exitAt fn l tm) ds S contract
  | p0, (l, ds, S) :: (l', ds', S') :: ps =>
    (coversWith P fn l p0 (fun σ tm => σ.exitAt fn l tm) ds S contract ||
      coversWith P fn l p0 (fun σ tm => σ.exitTo fn l l' tm) ds S contract) &&
      coversPathWith contract P fn (S.exit.pc fn l') ((l', ds', S') :: ps)

/-- `WalkI` with every block after the first entered through `Valuation.intoWith contract`: each
block's conditions hold at its entry valuation and each exit but the last goes to the next
block's label. Without `contract` it is `WalkI` (definitionally). -/
def WalkWith (contract : Bool) (V : Valuation) : List (Nat × List Cond × Summary) → Prop
  | [] => True
  | [(_, ds, S)] => ∀ d ∈ ds, d.Holds V (vals V S.nodes)
  | (l, ds, S) :: (l', ds', S') :: ps => (∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧
      WalkWith contract (V.intoWith contract l S) ((l', ds', S') :: ps)

/-- Whether `WalkWith contract` holds, decided by evaluating it (the kernel reduces it on a
concrete valuation). -/
instance WalkWith.dec (contract : Bool) (V : Valuation) :
    (ps : List (Nat × List Cond × Summary)) → Decidable (WalkWith contract V ps)
  | [] => isTrue trivial
  | [(_, ds, S)] => inferInstanceAs (Decidable (∀ d ∈ ds, d.Holds V (vals V S.nodes)))
  | (l, ds, S) :: (l', ds', S') :: ps =>
    have := WalkWith.dec contract (V.intoWith contract l S) ((l', ds', S') :: ps)
    inferInstanceAs (Decidable ((∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧
      WalkWith contract (V.intoWith contract l S) ((l', ds', S') :: ps)))

/-- `Valuation.lastI` with every block after the first entered through
`Valuation.intoWith contract`: the last block's entry valuation, label and summary. Without
`contract` it is `Valuation.lastI` (definitionally). -/
def Valuation.lastWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.intoWith contract l S).lastWith contract l' S' ps

/-- `Valuation.blocksI` with every block after the first entered through
`Valuation.intoWith contract`: the path's blocks in order, each with its entry valuation, label
and summary. Without `contract` it is `Valuation.blocksI` (definitionally). -/
def Valuation.blocksWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → List (Valuation × Nat × Summary)
  | [] => [(V, l, S)]
  | (l', _, S') :: ps => (V, l, S) :: (V.intoWith contract l S).blocksWith contract l' S' ps

/-- For every flag, valuation, label, summary and path, the last block's entry valuation
(`Valuation.lastWith contract`) keeps the context and the function, and the step count at its
end is the entry's plus the path's length (`Valuation.intoWith_k`). -/
theorem Valuation.lastWith_k (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    ∀ ps, (V.lastWith contract l S ps).1.ctx = V.ctx ∧ (V.lastWith contract l S ps).1.fn = V.fn ∧
      (V.lastWith contract l S ps).1.k + (V.lastWith contract l S ps).2.2.len =
        V.k + pathLen S ps
  | [] => ⟨rfl, rfl, rfl⟩
  | (l', _, S') :: ps => by
    obtain ⟨h1, h2, h3⟩ := Valuation.lastWith_k contract (V.intoWith contract l S) l' S' ps
    obtain ⟨e1, e2, e3⟩ := Valuation.intoWith_k contract V l S
    rw [Valuation.lastWith]
    refine ⟨h1.trans e1, h2.trans e2, ?_⟩
    rw [h3, pathLen, e3]
    omega

set_option smartUnfolding false in
/-- The last block's entry valuation keeps the context and the function, and the step count at
its end is the entry's plus the path's length (`Valuation.lastWith_k` without
`fmul contract`). -/
theorem Valuation.lastI_k (V : Valuation) (l : Nat) (S : Summary) :
    ∀ ps, (V.lastI l S ps).1.ctx = V.ctx ∧ (V.lastI l S ps).1.fn = V.fn ∧
      (V.lastI l S ps).1.k + (V.lastI l S ps).2.2.len = V.k + pathLen S ps :=
  Valuation.lastWith_k false V l S

/-- A path that `coversPath` accepts with premises `Walk` is one that `coversPathI` accepts
with premises `WalkI`, with the same last block: its exits have targets (`Exit.of_target`). -/
theorem Walk.toI {P : Program} {fn : Func} : ∀ (ps : List (Nat × List Cond × Summary))
    {V : Valuation} {l p0 : Nat} {ds : List Cond} {S : Summary},
    Walk V ((l, ds, S) :: ps) → coversPath P fn p0 ((l, ds, S) :: ps) = true →
    WalkI V ((l, ds, S) :: ps) ∧ coversPathI P fn p0 ((l, ds, S) :: ps) = true ∧
      V.lastI l S ps = V.last l S ps
  | [], _, _, _, _, _, hW, hc =>
    ⟨hW, by simpa only [coversPath, coversPathI, Bool.and_true] using hc, rfl⟩
  | (l', ds', S') :: ps, V, l, p0, ds, S, hW, hc => by
    obtain ⟨hds, ht, hW'⟩ := hW
    rw [coversPath, Bool.and_eq_true] at hc
    obtain ⟨hd, hpc, hi⟩ := Exit.of_target (l := l) ht
    obtain ⟨hW'', hc', he⟩ := Walk.toI ps hW' hc.2
    refine ⟨⟨hds, hd, by rw [hi]; exact hW''⟩, ?_, by rw [Valuation.lastI, Valuation.last, hi, he]⟩
    rw [coversPathI, Bool.and_eq_true, hpc]
    exact ⟨by rw [hc.1, Bool.true_or], hc'⟩

/-- **Soundness along a path with `phi`s, with or without `fmul contract`, with its pointer
facts**: for every flag `contract`, program, function and path `(l, ds, S) :: ps` that
`coversPathWith contract` accepts (the first block from position `p0`), every context of the
program and thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`: if
the path's premises hold from the entry valuation (`WalkWith contract`: each block's conditions at
its entry, each exit to the next block), the thread's steps run every block of the path, each
edge setting its target's `phi`s (`Ends.edgeWith`), and the last one ends (`EndsWith contract`)
from its entry valuation (`Valuation.lastWith contract`), at step count `t.k + pathLen S ps`
(`Valuation.lastWith_k`); and the pointer facts (`Ptrs`) of every block of the path hold from the
thread, each from its entry valuation (`Valuation.blocksWith contract`). -/
theorem Block.sound_pathWith_ptrs {contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} :
    ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond} {S : Summary}
      {t : Thread} {m : Mem} {f : Frame},
    coversPathWith contract P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest →
    f.fn = fn → f.label = l → f.pc = p0 →
    WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    EndsWith contract c t m f rest ((Valuation.entry c t.k m f).lastWith contract l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksWith contract l S ps, Ptrs c t m rest q
  | [], _, _, _, _, _, _, _, hc, ht, hfn, hl, hp, hW => by
    obtain ⟨hE, hQ⟩ := Block.sound_atWith hc hP ht hfn hl hp hW
    refine ⟨hE, fun q hq => ?_⟩
    rw [Valuation.blocksWith, List.mem_singleton] at hq
    subst hq
    exact hQ
  | (l₂, ds₂, S₂) :: ps, l, p0, ds, S, t, m, f, hc, ht, hfn, hl, hp, hW => by
    rw [coversPathWith, Bool.and_eq_true] at hc
    obtain ⟨hds, hd, hW'⟩ := hW
    have hE : EndsWith contract c t m f rest (Valuation.entry c t.k m f, l, S) ∧
        Ptrs c t m rest (Valuation.entry c t.k m f, l, S) := by
      have h := hc.1
      simp only [Bool.or_eq_true] at h
      rcases h with h | h
      · exact Block.sound_atWith h hP ht hfn hl hp hds
      · exact Block.sound_toWith h hP ht hfn hl hp hds hd
    obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edgeWith rfl hE.1 hd
    have hV' : Valuation.entry c (t.k + S.len + 1) m₁ f' =
        (Valuation.entry c t.k m f).intoWith contract l S := hV
    have hq := Block.sound_pathWith_ptrs hP ps (t := ⟨f' :: rest, t.k + S.len + 1⟩) (m := m₁)
      (f := f') hc.2 rfl (hfn'.trans hfn) hl' (by rw [hp', ← hfn]; rfl) (by rw [hV']; exact hW')
    rw [hV'] at hq
    refine ⟨EndsWith.pre hS₁ hst₁ hq.1 hal' hde', fun q hmem => ?_⟩
    rw [Valuation.blocksWith, List.mem_cons] at hmem
    rcases hmem with rfl | hmem
    · exact hE.2
    · exact Ptrs.pre (Steps.trans_step hS₁ hst₁ (.refl _ _)) (hq.2 q hmem)

set_option smartUnfolding false in
/-- **Soundness along a path with `phi`s, with its pointer facts**: for every program, function
and path `(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first
block from position `p0`), every context of the program and thread whose innermost frame `f` is
at block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry
valuation (`WalkI`: each block's conditions at its entry, each exit to the next block), the
thread's steps run every block of the path, each edge setting its target's `phi`s
(`Ends.edge`), and the last one ends (`Ends`) from its entry valuation (`Valuation.lastI`), at
step count `t.k + pathLen S ps` (`Valuation.lastI_k`); and the pointer facts (`Ptrs`) of every
block of the path hold from the thread, each from its entry valuation (`Valuation.blocksI`)
(`Block.sound_pathWith_ptrs` without `fmul contract`). -/
theorem Block.sound_pathI_ptrs {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} : ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame},
    coversPathI P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest → f.fn = fn →
    f.label = l → f.pc = p0 → WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    Ends c t m f rest ((Valuation.entry c t.k m f).lastI l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksI l S ps, Ptrs c t m rest q :=
  @Block.sound_pathWith_ptrs false P fn c hP rest

/-- **Soundness along a path with `phi`s**: for every program, function and path
`(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first block
from position `p0`), every context of the program and thread whose innermost frame `f` is at
block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry
valuation (`WalkI`: each block's conditions at its entry, each exit to the next block), the
thread's steps run every block of the path, each edge setting its target's `phi`s
(`Ends.edge`), and the last one ends (`Ends`) from its entry valuation (`Valuation.lastI`), at
step count `t.k + pathLen S ps` (`Valuation.lastI_k`) (`Block.sound_pathI_ptrs`). -/
theorem Block.sound_pathI {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) :
    Ends c t m f rest ((Valuation.entry c t.k m f).lastI l S ps) :=
  (Block.sound_pathI_ptrs hP ps hc ht hfn hl hp hW).1

/-- **A path, then a block with `fmul contract`**: for every program, function and path
`(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first block from
position `p0`), whose last block, entered with valuation `W` at label `l'` with summary `S'`
(`Valuation.lastI`), exits to block `lc` (`Exit.dest`), and every conditions `dc` and summary `Sc`
that the checker with `fmul contract` accepts for `lc` from the position that exit enters it at
(`coversC`, `Exit.pc`), every context of the program and thread whose innermost frame `f` is at
block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry valuation
(`WalkI`) and `dc` holds at `lc`'s entry valuation `W.into l' S'`, the thread's steps run the
path, its last edge and block `lc`, which ends with the table's `fmul contract` operands
(`EndsC`) from that valuation (`Block.sound_pathI`, `Ends.edge`, `Block.soundC`). -/
theorem Block.sound_pathC {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 lc : Nat}
    {ds dc : List Cond} {S Sc : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) {W : Valuation} {l' : Nat}
    {S' : Summary} (hq : (Valuation.entry c t.k m f).lastI l S ps = (W, l', S'))
    (hd : S'.exit.dest W (vals W S'.nodes) = some lc)
    (hcc : coversC P fn lc (S'.exit.pc fn lc) dc Sc = true)
    (hdc : ∀ d ∈ dc, d.Holds (W.into l' S') (vals (W.into l' S') Sc.nodes)) :
    EndsC c t m f rest (W.into l' S', lc, Sc) := by
  have hE := Block.sound_pathI hP ps hc ht hfn hl hp hW
  have hk := Valuation.lastI_k (Valuation.entry c t.k m f) l S ps
  rw [hq] at hE hk
  obtain ⟨hk1, hk2, -⟩ := hk
  have hc' : W.ctx = c := hk1
  have hf' : W.fn = fn := hk2.trans hfn
  obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edge hc' hE hd
  have h := Block.soundC hcc hP (t := ⟨f' :: rest, W.k + S'.len + 1⟩) (m := m₁) (f := f') rfl
    (hfn'.trans hf') hl' (by rw [hp', hf']) (by rw [hV]; exact hdc)
  rw [hV] at h
  exact EndsWith.pre (contract := true) (q := (W.into l' S', lc, Sc)) hS₁ hst₁ h hal' hde'

/-- **A path with `phi`s that returns, with or without `fmul contract`, under any caller
frames**: for every flag `contract`, `Block.sound_pathWith_ptrs` for a path whose last block
(entered with valuation `W` at label `l'` with summary `S'`, `Valuation.lastWith contract`) has
exit `ret void`, from a thread whose innermost frame `f` is above frames `rest`: the thread's
steps reach the last block's end at step count `t.k + pathLen S ps`, on the memory `me` the last
block's effects make from `W`, and its next step is the `ret`'s, with `f`'s `alloca` blocks dead:
`.done` when `rest` is empty, else back to the caller `g` at the position after its call
(`g.set f.dest none none`: `ret void` sets no register). For every program, function and path
`coversPathWith contract` accepts, and every list of caller frames. -/
theorem Block.sound_retWith {contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hc : coversPathWith contract P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) {W : Valuation}
    {l' : Nat} {S' : Summary}
    (hq : (Valuation.entry c t.k m f).lastWith contract l S ps = (W, l', S'))
    (hret : S'.exit = .ret) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + pathLen S ps⟩ me ∧
      SEff.run W (vals W S'.nodes) S'.effs = .ok me ∧
      step c ⟨fe :: rest, t.k + pathLen S ps⟩ me = .ok (match (generalizing := false) rest with
        | [] => .done (f.allocas.foldl (fun m b => m.setLive b false) me)
        | g :: gs => .next ⟨{ g.set f.dest none none with pc := g.pc + 1 } :: gs,
            t.k + pathLen S ps + 1⟩ (f.allocas.foldl (fun m b => m.setLive b false) me)) := by
  have h := (Block.sound_pathWith_ptrs hP ps hc ht hfn hl hp hW).1
  have hk := (Valuation.lastWith_k contract (Valuation.entry c t.k m f) l S ps).2.2
  rw [hq] at h hk
  obtain ⟨fe, me, hS, -, -, hal, hde, -, -, hm, r, hn, hst⟩ := h
  simp only [Valuation.entry] at hk
  rw [hret] at hn
  simp only [Exit.next, pure, Except.pure, Except.ok.injEq] at hn
  subst hn
  rw [← hal, ← hde, ← hk]
  cases rest <;> exact ⟨fe, me, hS, hm, hst⟩

set_option smartUnfolding false in
/-- **A path with `phi`s that returns, under any caller frames**: `Block.sound_pathI` for a path
whose last block's exit is `ret void`, from a thread whose innermost frame `f` is above frames
`rest`: the thread's steps reach the last block's end at step count `t.k + pathLen S ps`, on the
memory `me` the last block's effects make from its entry valuation, and its next step is the
`ret`'s, with `f`'s `alloca` blocks dead: `.done` when `rest` is empty, else back to the caller
`g` at the position after its call (`g.set f.dest none none`: `ret void` sets no register). For
every program, function and path the checker accepts, and every list of caller frames
(`Block.sound_retWith` without `fmul contract`). -/
theorem Block.sound_retR {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit = .ret) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + pathLen S ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me ∧
      step c ⟨fe :: rest, t.k + pathLen S ps⟩ me = .ok (match (generalizing := false) rest with
        | [] => .done (f.allocas.foldl (fun m b => m.setLive b false) me)
        | g :: gs => .next ⟨{ g.set f.dest none none with pc := g.pc + 1 } :: gs,
            t.k + pathLen S ps + 1⟩ (f.allocas.foldl (fun m b => m.setLive b false) me)) :=
  Block.sound_retWith (contract := false) hP hc ht hfn hl hp hW rfl hret

/-- A path from valuation `V` at its first block's entry to `ret`, leaving a memory of `Q`: its
premises with `phi`s hold (`WalkI`: each block's conditions at its entry valuation, each exit but
the last to the next block, an edge into a block with `phi`s setting them), its last block's exit
is `ret`, and the last block's effects succeed (`SEff.run` at the last block's entry valuation,
`Valuation.lastI`) with a memory of `Q`. False on the empty path. -/
def Ret (V : Valuation) (Q : Mem → Prop) : List (Nat × List Cond × Summary) → Prop
  | [] => False
  | (l, ds, S) :: ps => WalkI V ((l, ds, S) :: ps) ∧ (V.lastI l S ps).2.2.exit = .ret ∧
      ∃ me, SEff.run (V.lastI l S ps).1 (vals (V.lastI l S ps).1 (V.lastI l S ps).2.2.nodes)
        (V.lastI l S ps).2.2.effs = .ok me ∧ Q me

/-- `Ret` with every block after the first entered through `Valuation.intoWith contract`: the
path's premises hold (`WalkWith contract`), its last block's exit is `ret`, and the last block's
effects succeed at its entry valuation (`Valuation.lastWith contract`) with a memory of `Q`.
False on the empty path. Without `contract` it is `Ret` (definitionally). -/
def RetWith (contract : Bool) (V : Valuation) (Q : Mem → Prop) :
    List (Nat × List Cond × Summary) → Prop
  | [] => False
  | (l, ds, S) :: ps => WalkWith contract V ((l, ds, S) :: ps) ∧
      (V.lastWith contract l S ps).2.2.exit = .ret ∧
      ∃ me, SEff.run (V.lastWith contract l S ps).1
        (vals (V.lastWith contract l S ps).1 (V.lastWith contract l S ps).2.2.nodes)
        (V.lastWith contract l S ps).2.2.effs = .ok me ∧ Q me

/-- A frame with no value set (`ret void`'s return to a caller) is the frame itself. -/
theorem Frame.set_none (g : Frame) (r : Option Nat) (p : Option (Val × Val)) :
    g.set r none p = g := by
  cases r <;> rfl

/-- **Return to a caller**: for every program, function and path that `coversPathI` accepts and
whose last block returns (`ret void`), every context of the program and thread whose innermost
frame `f`, at the path's first block and position, has a caller frame `g` above frames `rest`,
and every condition list `dg` and summary `Sg` that `covers` accepts for `g`'s block from the
position after the call (`g.pc + 1`): if the path's premises hold and, for the memory `me` the
last block's effects make, `dg` holds at the entry valuation of `{ g with pc := g.pc + 1 }` on
`me` with `f`'s `alloca` blocks dead (at step count `t.k + pathLen S ps + 1`), then the thread's
steps run the path, return to `g` and run `g`'s block from `g.pc + 1` to its end: it ends
(`Ends`) from that valuation. -/
theorem Block.sound_back {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f g : Frame} {rest : List Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: g :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit = .ret)
    {dg : List Cond} {Sg : Summary} (hcg : covers P g.fn g.label (g.pc + 1) dg Sg = true)
    (hg : ∀ me, SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me →
      ∀ d ∈ dg, d.Holds (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
        (vals (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
          Sg.nodes)) :
    ∃ me, SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me ∧
      Ends c t m { g with pc := g.pc + 1 } rest
        (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 }, g.label,
          Sg) := by
  obtain ⟨fe, me, hS, hm, hst⟩ := Block.sound_retR hP hc ht hfn hl hp hW hret
  simp only [Frame.set_none] at hst
  exact ⟨me, hm, Ends.pre hS hst
    (Block.sound hcg hP (t := ⟨{ g with pc := g.pc + 1 } :: rest, t.k + pathLen S ps + 1⟩) rfl
      rfl rfl rfl (hg me hm)) rfl rfl⟩

/-- **Soundness along a path, with its pointer facts**: for every program, function and path
`(l, ds, S) :: ps` the path checker accepts (`coversPath`), every context of the program and
thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`, whose premises
`Walk` hold from the entry valuation: the last block ends (`Ends`) from its entry valuation
(`Valuation.last`), and the pointer facts (`Ptrs`) of every block of the path hold from the
thread, each from its entry valuation (`Valuation.blocksI`, whose `Valuation.into` is
`Valuation.after` on such a path, `Exit.of_target`). The corollary of `Block.sound_pathI_ptrs`
(`Walk.toI`). -/
theorem Block.sound_path_ptrs {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPath P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) :
    Ends c t m f rest ((Valuation.entry c t.k m f).last l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksI l S ps, Ptrs c t m rest q := by
  obtain ⟨hW', hc', he⟩ := Walk.toI ps hW hc
  rw [← he]
  exact Block.sound_pathI_ptrs hP ps hc' ht hfn hl hp hW'

/-- **Soundness along a path**: for every program, function and path `(l, ds, S) :: ps` the path
checker accepts (`coversPath`, the first block from position `p0`), every context of the
program and thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`:
if the path's premises hold from the entry valuation (`Walk`: each block's conditions at its
entry, each exit to the next block), the thread's steps run every block of the path and the
last one ends (`Ends`) from its entry valuation (`Valuation.last`), at step count
`t.k + pathLen S ps`. The corollary of `Block.sound_path_ptrs` (`Walk.toI`): the exits of such
a path have targets, so its edges resolve no `phi` (`Exit.next_target`). -/
theorem Block.sound_path {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} : ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame},
    coversPath P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest → f.fn = fn →
    f.label = l → f.pc = p0 → Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    Ends c t m f rest ((Valuation.entry c t.k m f).last l S ps) :=
  fun ps _ _ _ _ _ _ _ hc ht hfn hl hp hW => (Block.sound_path_ptrs hP ps hc ht hfn hl hp hW).1

/-- **A path that returns**: `Block.sound_path` for a path whose last block's exit is `ret void`,
from a thread with one frame `f` (a kernel's): the thread's steps reach the last block's end at
step count `t.k + pathLen S ps`, on the memory `me` the last block's effects make from its entry
valuation, and its next step returns, `.done` with `f`'s `alloca` blocks dead. For every program,
function and path the checker accepts; the corollary of `Block.sound_retR` (`Walk.toI`). -/
theorem Block.sound_ret {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f : Frame} (hc : coversPath P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).last l S ps).2.2.exit = .ret) :
    ∃ fe me, Steps c t m ⟨[fe], t.k + pathLen S ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).last l S ps).1
        (vals ((Valuation.entry c t.k m f).last l S ps).1
          ((Valuation.entry c t.k m f).last l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).last l S ps).2.2.effs = .ok me ∧
      step c ⟨[fe], t.k + pathLen S ps⟩ me =
        .ok (.done (f.allocas.foldl (fun m b => m.setLive b false) me)) := by
  obtain ⟨hW', hc', he⟩ := Walk.toI ps hW hc
  rw [← he] at hret ⊢
  exact Block.sound_retR hP hc' ht hfn hl hp hW' hret

end MojoProof.Sym
