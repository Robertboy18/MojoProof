import MojoProof.Sym.Block

/-!
# Soundness of the block checker along a path

The block theorem (`Block.sound`, MojoProof/Sym/Block.lean) along a path of the control-flow
graph: for every program, path and thread, the steps of a thread through blocks that the path
checker accepts.

The path checker and the premises of a path take a flag `contract` (with or without
`fmul contract`) and are defined once for both values. `coversPathWith contract` accepts a path:
the first block from position `p0`, each one after from the position its edge enters it at
(`Exit.pc`: after its `phi`s for `Exit.phi`, else 0), each block by `coversWith … contract` at
its exit or, for each block but the last, at the edge into the next block. `WalkWith contract`
holds of a path from a valuation when each block's conditions hold under its entry valuation,
which is `Valuation.intoWith contract` of the block before (`Valuation.afterWith contract`: the
step count after its statements and branch, the memory of its effects, its registers and
`fmul contract` operands, with the target's `phi`s set as `enter` sets them), and each exit but
the last goes to the next block (`Exit.dest`). `Valuation.lastWith contract` is the last block
with its entry valuation, `Valuation.blocksWith contract` every block with its own. A path
without `phi`s is the case whose exits have targets (`Exit.target`): their steps enter at
position 0 and resolve no `phi` (`Exit.next_target`), and `Valuation.intoWith contract` is
`Valuation.afterWith contract` there (`Exit.of_targetWith`).

`Block.sound_pathWith_ptrs`: for every flag, `Block.sound` along a path of any length that
`coversPathWith contract` accepts, from every context of the program and thread at the first
block's position `p0` whose premises hold (`WalkWith contract`): the thread's steps run every
block, each edge by `Ends.edgeWith`, and the last one ends (`EndsWith contract`) from its entry
valuation (`Valuation.lastWith contract`), at step count `t.k + pathLen S ps`
(`Valuation.lastWith_k`), with the pointer facts (`Ptrs`) of every block. `Block.sound_retWith`:
a path whose last block returns (`ret void`), under any caller frames: its steps reach the last
block's end, on the memory the last block's effects make, and the next step is the `ret`'s:
`.done` without a caller (`rest = []`, a thread with one frame), else back to the caller after
its call. `RetWith contract`: a path whose premises hold, whose last exit is `ret` and whose last
block's effects succeed with a memory of a predicate `Q`; `Ret` is its case without
`fmul contract` (used by the loop theorems, Sym/Loop.lean, and the kernel theorem,
Sym/Kernel.lean). `Block.sound_back`: then the caller's block from the position after the call
ends too (`Block.sound` there).

With `fmul contract`: `Valuation.afterC` and `Valuation.intoC` are `Valuation.afterWith` and
`Valuation.intoWith` with the flag, whose `fmul contract` operands are the table's
(`regProdIn`); `Valuation.into` is `Valuation.intoWith` without it. `Block.sound_toWith` and
`Ends.edgeWith` are proved once, for both values of the flag; `Block.sound_to`, `Ends.edge` and
`Ends.edgeC` (from `EndsC`) are their instances, one line each. `Block.sound_pathC`: a path that
`coversPathWith false` accepts, then the block its last exit goes to, accepted by `coversC`: it
ends (`EndsC`) from `Valuation.into` of the path's last block.
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
  Block.sound_with (ex := fun σ tm => σ.exitTo fn lbl d₀ tm) (hc := hc) hP ht hfn hl hp hds
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

/-- The frame at the end of block `l` that summary `S` describes from valuation `V`: `V`'s
function, the registers and `fmul contract` operands of `Valuation.after`, position 0, no
`alloca` blocks and no caller's register (`enter` reads none of these three). It is
`Valuation.frameAtWith` without `contract`. -/
def Valuation.frameAt (V : Valuation) (l : Nat) (S : Summary) : Frame :=
  V.frameAtWith false l S

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

/-- The valuation at the entry of the block that the exit of summary `S` of block `l` goes to,
from valuation `V` at its entry: `Valuation.after`, whose registers and `fmul contract`
operands are, for a branch into blocks with `phi`s (`Exit.phi`), those of the frame `enter`
gives from `Valuation.frameAt`, with the target's `phi`s set. It is `Valuation.intoWith`
without `contract`. -/
def Valuation.into (V : Valuation) (l : Nat) (S : Summary) : Valuation :=
  V.intoWith false l S

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

/-- `Valuation.intoWith contract` keeps the context and the function, and its step count is
`Valuation.after`'s, with or without `contract`. -/
theorem Valuation.intoWith_k (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    (V.intoWith contract l S).ctx = V.ctx ∧ (V.intoWith contract l S).fn = V.fn ∧
      (V.intoWith contract l S).k = V.k + S.len + 1 := by
  unfold Valuation.intoWith
  split
  · split <;> exact ⟨rfl, rfl, rfl⟩
  · exact ⟨rfl, rfl, rfl⟩

/-- The memory at the entry of the block an edge goes to, with or without `fmul contract`, is
`Valuation.afterWith`'s, for every flag, valuation, label and summary. -/
theorem Valuation.intoWith_mem (c : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    (V.intoWith c l S).mem = (V.afterWith c S).mem := by
  unfold Valuation.intoWith
  split
  · split <;> rfl
  · rfl

/-- The memory after a block whose effects succeed with `me` is `me` (`Valuation.after`), for
every valuation and summary. -/
theorem Valuation.after_mem {V : Valuation} {S : Summary} {me : Mem}
    (h : SEff.run V (vals V S.nodes) S.effs = .ok me) : (V.after S).mem = me := by
  show (SEff.run V (vals V S.nodes) S.effs).toOption.getD V.mem = me
  rw [h]
  rfl

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
    Ends c t m f rest q :=
  EndsWith.pre (contract := false) h₁ h hq hal hde

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
  Ends.edgeWith (contract := false) hc h hd

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
  Ends.edgeWith (contract := true) hc h hd

/-- The number of steps of the path `S :: ps` to its last terminator: each block's statements,
and one step for each branch between them. -/
def pathLen (S : Summary) : List (Nat × List Cond × Summary) → Nat
  | [] => S.len
  | (_, _, S') :: ps => S.len + 1 + pathLen S' ps

/-- **The path checker, with or without `alloca` and `fmul contract`**: the blocks `(label,
conditions, summary)` of a path, the first from position `p0` and each one after from the
position its edge enters it at (`Exit.pc`: after its `phi`s for `Exit.phi`, else 0), each
accepted by `coversAt alloca … contract`: the last at `SState.exitAt`, each other one at
`SState.exitAt` or, with the obligations of its edge into the next block only, at
`SState.exitTo` that block. With the flag `alloca` on a block of the path may have `alloca`s. -/
def coversPathAt (alloca contract : Bool) (P : Program) (fn : Func) :
    Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, [(l, ds, S)] => coversAt alloca P fn l p0 (fun σ tm => σ.exitAt fn l tm) ds S contract
  | p0, (l, ds, S) :: (l', ds', S') :: ps =>
    (coversAt alloca P fn l p0 (fun σ tm => σ.exitAt fn l tm) ds S contract ||
      coversAt alloca P fn l p0 (fun σ tm => σ.exitTo fn l l' tm) ds S contract) &&
      coversPathAt alloca contract P fn (S.exit.pc fn l') ((l', ds', S') :: ps)

/-- **The path checker without `alloca`, with or without `fmul contract`**: `coversPathAt` with
the flag `alloca` off, each block accepted by `coversWith … contract` (without `contract`,
`covers` and `coversTo`). -/
def coversPathWith (contract : Bool) (P : Program) (fn : Func) :
    Nat → List (Nat × List Cond × Summary) → Bool :=
  coversPathAt false contract P fn

/-- **The premises of a path, with or without `fmul contract`**, from valuation `V` at its first
block's entry: each block's conditions hold at its entry valuation (`Valuation.intoWith contract`
of the block before: `Valuation.afterWith contract`, with the registers and `fmul contract`
operands `enter` sets for an edge into blocks with `phi`s), and each block's exit but the last
goes to the next block's label (`Exit.dest`). On a path whose exits have targets (`Exit.target`,
no `Exit.phi`), each entry valuation after the first is `Valuation.afterWith contract` of the
block before (`Exit.of_targetWith`). -/
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

/-- The last block of the path `(l, ds, S) :: ps` entered with valuation `V` at its first block,
with or without `fmul contract`: its entry valuation (`Valuation.intoWith contract` of each block
before it), label and summary. -/
def Valuation.lastWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.intoWith contract l S).lastWith contract l' S' ps

/-- The blocks of the path `(l, ds, S) :: ps` entered with valuation `V` at its first block, with
or without `fmul contract`, in order, each with its entry valuation (`Valuation.intoWith contract`
of each block before it), label and summary; `Valuation.lastWith contract` is the last. -/
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

/-- **Memory `m'` adds exactly the blocks `bs` to memory `m`**: a number is in `bs` exactly when
`m` has no block there and `m'` has one, and every number with a block in `m` has one in `m'`.
The blocks a block's effects add (`SEff.run_adds`), a path's (`Block.sound_pathAt_ptrs`) and a
run's through loops (`Runs.of_chainWith`); setting them dead, `ret`'s cleanup leaves the blocks
of `m` as they are (`Mem.Adds.foldl_setLive`). -/
structure _root_.MojoProof.Sem.Mem.Adds (m : Mem) (bs : List Nat) (m' : Mem) : Prop where
  /-- Builds the fact from its two fields. -/
  mk ::
  /-- The numbers of `bs` are those with no block in `m` and one in `m'`. -/
  new : ∀ b, b ∈ bs ↔ m.blocks b = none ∧ (m'.blocks b).isSome
  /-- Every number with a block in `m` has one in `m'`. -/
  old : ∀ b, (m.blocks b).isSome → (m'.blocks b).isSome

/-- A memory adds no block to itself, for every memory. -/
theorem _root_.MojoProof.Sem.Mem.Adds.nil {m : Mem} : m.Adds [] m :=
  ⟨fun b => ⟨fun h => by simp at h, fun ⟨h0, h1⟩ => by simp [h0] at h1⟩, fun _ h => h⟩

/-- A memory with the shape of `m` at every number (`Mem.SameShape`) adds no block to it, for
every memories. -/
theorem _root_.MojoProof.Sem.Mem.Adds.of_shape {m m' : Mem} (h : m.SameShape (fun _ => True) m') :
    m.Adds [] m' := by
  have e : ∀ b, (m.blocks b).isSome = (m'.blocks b).isSome := fun b => by
    simpa using congrArg Option.isSome (h b trivial)
  exact ⟨fun b => ⟨fun h => by simp at h, fun ⟨h0, h1⟩ => by simp [← e b, h0] at h1⟩,
    fun b hb => (e b).symm.trans hb⟩

/-- **Added blocks compose**: for every memories `m₀`, `m₁`, `m₂` and lists `xs`, `ys`, if `m₁`
adds `xs` to `m₀` and `m₂` adds `ys` to `m₁`, then `m₂` adds `ys ++ xs` to `m₀` (newest first,
the order of a frame's `alloca` blocks). -/
theorem _root_.MojoProof.Sem.Mem.Adds.trans {m₀ m₁ m₂ : Mem} {xs ys : List Nat}
    (h₁ : m₀.Adds xs m₁) (h₂ : m₁.Adds ys m₂) : m₀.Adds (ys ++ xs) m₂ := by
  refine ⟨fun b => ?_, fun b h => h₂.old b (h₁.old b h)⟩
  rw [List.mem_append, h₁.new, h₂.new]
  constructor
  · rintro (⟨h0, h1⟩ | ⟨h0, h1⟩)
    · refine ⟨?_, h1⟩
      cases e : m₀.blocks b with
      | none => rfl
      | some _ =>
        have := h₁.old b (by simp [e])
        simp [h0] at this
    · exact ⟨h0, h₂.old b h1⟩
  · rintro ⟨h0, h1⟩
    cases e : m₁.blocks b with
    | none => exact .inl ⟨rfl, h1⟩
    | some _ => exact .inr ⟨h0, by simp⟩

/-- **An effect adds its own block**: for every valuation `V`, node values `vs`, memory `m` and
effect `e` that applies (`SEff.apply`) to memory `m'`, `m'` adds exactly `e`'s block
(`SEff.block?`) to `m`: an `alloca`'s, at a number with no block in `m`, and none for a `load`
(a trace entry) or a `store` (`Mem.store_shape`). -/
theorem SEff.apply_adds {V : Valuation} {vs : List (Except Fault Val)} {m m' : Mem} {e : SEff}
    (h : SEff.apply V vs m e = .ok m') : m.Adds (e.block? V).toList m' := by
  cases e with
  | load lbl pc p =>
    simp only [SEff.apply] at h
    split at h
    · obtain ⟨x, -, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨q, -, h⟩ := Except.bind_eq_ok.1 h
      cases h
      exact Mem.Adds.of_shape fun _ _ => rfl
    · cases h
  | store lbl pc v p =>
    simp only [SEff.apply] at h
    split at h
    · obtain ⟨x, -, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨y, -, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨q, -, h⟩ := Except.bind_eq_ok.1 h
      exact Mem.Adds.of_shape (Mem.store_shape h _)
    · cases h
  | alloca lbl pc n cnt =>
    simp only [SEff.apply] at h
    split at h
    · obtain ⟨k, -, h⟩ := Except.bind_eq_ok.1 h
      split at h
      · cases h
      · rename_i hb
        cases h
        have hb0 : m.blocks (V.mem.fresh V.ctx.who.thread (V.k + n)) = none := by simpa using hb
        refine ⟨fun b => ?_, fun b hb' => ?_⟩
        · by_cases e : b = V.mem.fresh V.ctx.who.thread (V.k + n)
          · subst e
            simp [SEff.block?, Mem.alloc, Mem.set, hb0]
          · simp [SEff.block?, Mem.alloc, Mem.set, e]
        · by_cases e : b = V.mem.fresh V.ctx.who.thread (V.k + n) <;>
            simp [Mem.alloc, Mem.set, e, hb']
    · cases h

/-- **A block's effects add their `alloca` blocks**: for every valuation `V`, node values `vs`
and effects `es` that run (`SEff.run`) to memory `m`, `m` adds exactly the effects' blocks
(`SEff.blocks`) to the entry memory (`SEff.apply_adds`, `Mem.Adds.trans`). -/
theorem SEff.run_adds {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} {m : Mem}
    (h : SEff.run V vs es = .ok m) : V.mem.Adds (SEff.blocks V es) m := by
  induction es using List.reverseRecOn generalizing m with
  | nil =>
    simp only [SEff.run, List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact Mem.Adds.nil
  | append_singleton es e ih =>
    obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc h
    rw [SEff.blocks_snoc]
    exact (ih h₀).trans (SEff.apply_adds he)

/-- The `alloca` blocks of the path `(l, ds, S) :: ps` entered with valuation `V` at its first
block, with or without `fmul contract`: each block's (`SEff.blocks` at its entry valuation,
`Valuation.blocksWith contract`), newest first, so the last block's come first. -/
def Valuation.allocsWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → List Nat
  | [] => SEff.blocks V S.effs
  | (l', _, S') :: ps =>
    (V.intoWith contract l S).allocsWith contract l' S' ps ++ SEff.blocks V S.effs

/-- **Soundness along a path with `alloca`s, with or without `fmul contract`, with its pointer
facts**: for every flag `alloca` and `contract`, program, function and path `(l, ds, S) :: ps`
that `coversPathAt alloca contract` accepts (the first block from position `p0`), every context
of the program and thread whose innermost frame `f` is at block `l`'s position `p0`, with memory
`m`: if the path's premises hold from the entry valuation (`WalkWith contract`: each block's
conditions at its entry, each exit to the next block), the thread's steps run every block of the
path, each edge setting its target's `phi`s (`Ends.edgeWith` at the frame with each block's
`alloca` blocks), and the last one ends (`EndsWith contract`) from its entry valuation
(`Valuation.lastWith contract`), at step count `t.k + pathLen S ps` (`Valuation.lastWith_k`),
with the frame `f` whose `alloca` blocks are the path's (`Valuation.allocsWith contract`) in front
of `f`'s (`Block.sound_withAt`); the pointer facts (`Ptrs`) of every block of the path hold
from the thread, each from its entry valuation (`Valuation.blocksWith contract`); and every memory
the last block's effects run to adds exactly the path's `alloca` blocks to `m` (`Mem.Adds`,
`SEff.run_adds` of each block). `Block.sound_pathWith_ptrs` is the case with the flag off. -/
theorem Block.sound_pathAt_ptrs {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} :
    ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond} {S : Summary}
      {t : Thread} {m : Mem} {f : Frame},
    coversPathAt alloca contract P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest →
    f.fn = fn → f.label = l → f.pc = p0 →
    WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    EndsWith contract c t m { f with
        allocas := (Valuation.entry c t.k m f).allocsWith contract l S ps ++ f.allocas } rest
        ((Valuation.entry c t.k m f).lastWith contract l S ps) ∧
      (∀ q ∈ (Valuation.entry c t.k m f).blocksWith contract l S ps, Ptrs c t m rest q) ∧
      ∀ me, SEff.run ((Valuation.entry c t.k m f).lastWith contract l S ps).1
          (vals ((Valuation.entry c t.k m f).lastWith contract l S ps).1
            ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.nodes)
          ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.effs = .ok me →
        m.Adds ((Valuation.entry c t.k m f).allocsWith contract l S ps) me
  | [], _, _, _, _, _, _, _, hc, ht, hfn, hl, hp, hW => by
    obtain ⟨hE, hQ⟩ := Block.sound_withAt (ex := fun σ tm => σ.exitAt fn _ tm) hc hP ht hfn hl
      hp hW fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
        (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs
    refine ⟨hE, fun q hq => ?_, fun me hme => SEff.run_adds hme⟩
    rw [Valuation.blocksWith, List.mem_singleton] at hq
    subst hq
    exact hQ
  | (l₂, ds₂, S₂) :: ps, l, p0, ds, S, t, m, f, hc, ht, hfn, hl, hp, hW => by
    rw [coversPathAt, Bool.and_eq_true] at hc
    obtain ⟨hds, hd, hW'⟩ := hW
    have hE : EndsAt contract c t m f rest (Valuation.entry c t.k m f, l, S) ∧
        Ptrs c t m rest (Valuation.entry c t.k m f, l, S) := by
      have h := hc.1
      simp only [Bool.or_eq_true] at h
      rcases h with h | h
      · exact Block.sound_withAt (ex := fun σ tm => σ.exitAt fn l tm) h hP ht hfn hl hp hds
          fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
            (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs
      · exact Block.sound_withAt (ex := fun σ tm => σ.exitTo fn l l₂ tm) h hP ht hfn hl hp hds
          fun hR hb hpc hx hcs => SState.exitTo_sound hR hb hpc
            (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs hd
    obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edgeWith
      (c := c) (t := t) (m := m) (rest := rest) (V := Valuation.entry c t.k m f) (l := l)
      (f := { f with allocas := SEff.blocks (Valuation.entry c t.k m f) S.effs ++ f.allocas })
      rfl hE.1 hd
    have hV' : Valuation.entry c (t.k + S.len + 1) m₁ f' =
        (Valuation.entry c t.k m f).intoWith contract l S := hV
    have hq := Block.sound_pathAt_ptrs hP ps (t := ⟨f' :: rest, t.k + S.len + 1⟩) (m := m₁)
      (f := f') hc.2 rfl (hfn'.trans hfn) hl' (by rw [hp', ← hfn]; rfl) (by rw [hV']; exact hW')
    rw [hV'] at hq
    have hal : ((Valuation.entry c t.k m f).intoWith contract l S).allocsWith contract l₂ S₂ ps ++
        f'.allocas = (Valuation.entry c t.k m f).allocsWith contract l S ((l₂, ds₂, S₂) :: ps) ++
          f.allocas := by
      rw [Valuation.allocsWith, List.append_assoc]
      exact congrArg _ hal'
    obtain ⟨-, me₀, -, -, -, -, -, -, -, hrun, -⟩ := hE.1
    have hm₁ : m₁ = me₀ := (congrArg Valuation.mem hV').trans
      ((Valuation.intoWith_mem contract _ l S).trans (Valuation.after_mem hrun))
    subst hm₁
    refine ⟨EndsWith.pre hS₁ hst₁ hq.1 hal hde', fun q hmem => ?_, fun me hme => ?_⟩
    · rw [Valuation.blocksWith, List.mem_cons] at hmem
      rcases hmem with rfl | hmem
      · exact hE.2
      · exact Ptrs.pre (Steps.trans_step hS₁ hst₁ (.refl _ _)) (hq.2.1 q hmem)
    · rw [Valuation.allocsWith]
      exact (SEff.run_adds hrun).trans (hq.2.2 me hme)

/-- **A path without `alloca` has no `alloca` blocks**: for every flag `contract`, program,
function and path `(l, ds, S) :: ps` that `coversPathWith contract` accepts and every valuation,
`Valuation.allocsWith contract` is empty (`summarizeWith_allocates`, `SEff.blocks_eq_nil`). -/
theorem Valuation.allocsWith_nil {contract : Bool} {P : Program} {fn : Func} :
    ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond} {S : Summary},
    coversPathWith contract P fn p0 ((l, ds, S) :: ps) = true →
    ∀ V : Valuation, V.allocsWith contract l S ps = []
  | [], _, _, _, _, hc, _ => by
    rw [coversPathWith, coversPathAt] at hc
    exact SEff.blocks_eq_nil (summarizeWith_allocates (coversAt_summary hc))
  | (_, _, _) :: ps, _, _, _, S, hc, V => by
    rw [coversPathWith, coversPathAt, Bool.and_eq_true, Bool.or_eq_true] at hc
    have hA : SEff.allocates S.effs = false := by
      rcases hc.1 with h | h <;> exact summarizeWith_allocates (coversAt_summary h)
    rw [Valuation.allocsWith, Valuation.allocsWith_nil ps hc.2, SEff.blocks_eq_nil hA,
      List.append_nil]

/-- **Soundness along a path, with or without `fmul contract`, with its pointer facts**:
`Block.sound_pathAt_ptrs` with the flag `alloca` off, whose path has no `alloca` blocks
(`Valuation.allocsWith_nil`): for every flag `contract`, program, function and path
`(l, ds, S) :: ps` that `coversPathWith contract` accepts (the first block from position `p0`),
every context of the program and thread whose innermost frame `f` is at block `l`'s position
`p0`, with memory `m`: if the path's premises hold (`WalkWith contract`), the last block ends
(`EndsWith contract`) at frame `f` from its entry valuation (`Valuation.lastWith contract`), and
the pointer facts (`Ptrs`) of every block of the path hold (`Valuation.blocksWith contract`). -/
theorem Block.sound_pathWith_ptrs {contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} :
    ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond} {S : Summary}
      {t : Thread} {m : Mem} {f : Frame},
    coversPathWith contract P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest →
    f.fn = fn → f.label = l → f.pc = p0 →
    WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    EndsWith contract c t m f rest ((Valuation.entry c t.k m f).lastWith contract l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksWith contract l S ps, Ptrs c t m rest q := by
  intro ps l p0 ds S t m f hc ht hfn hl hp hW
  have h := Block.sound_pathAt_ptrs (alloca := false) hP ps hc ht hfn hl hp hW
  rw [Valuation.allocsWith_nil ps hc, List.nil_append] at h
  exact ⟨h.1, h.2.1⟩

/-- **A path, then a block with `fmul contract`**: for every program, function and path
`(l, ds, S) :: ps` that the path checker accepts without `fmul contract`
(`coversPathWith false`, the first block from position `p0`), whose last block, entered with
valuation `W` at label `l'` with summary `S'` (`Valuation.lastWith false`), exits to block `lc`
(`Exit.dest`), and every conditions `dc` and summary `Sc` that the checker with `fmul contract`
accepts for `lc` from the position that exit enters it at (`coversC`, `Exit.pc`), every context of
the program and thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`:
if the path's premises hold from the entry valuation (`WalkWith false`) and `dc` holds at `lc`'s
entry valuation `W.into l' S'`, the thread's steps run the path, its last edge and block `lc`,
which ends with the table's `fmul contract` operands (`EndsC`) from that valuation
(`Block.sound_pathWith_ptrs`, `Ends.edge`, `Block.soundC`). -/
theorem Block.sound_pathC {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 lc : Nat}
    {ds dc : List Cond} {S Sc : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathWith false P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkWith false (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) {W : Valuation}
    {l' : Nat} {S' : Summary} (hq : (Valuation.entry c t.k m f).lastWith false l S ps = (W, l', S'))
    (hd : S'.exit.dest W (vals W S'.nodes) = some lc)
    (hcc : coversC P fn lc (S'.exit.pc fn lc) dc Sc = true)
    (hdc : ∀ d ∈ dc, d.Holds (W.into l' S') (vals (W.into l' S') Sc.nodes)) :
    EndsC c t m f rest (W.into l' S', lc, Sc) := by
  have hE := (Block.sound_pathWith_ptrs hP ps hc ht hfn hl hp hW).1
  have hk := Valuation.lastWith_k false (Valuation.entry c t.k m f) l S ps
  rw [hq] at hE hk
  obtain ⟨hk1, hk2, -⟩ := hk
  have hc' : W.ctx = c := hk1
  have hf' : W.fn = fn := hk2.trans hfn
  obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edge hc' hE hd
  have h := Block.soundC hcc hP (t := ⟨f' :: rest, W.k + S'.len + 1⟩) (m := m₁) (f := f') rfl
    (hfn'.trans hf') hl' (by rw [hp', hf']) (by rw [hV]; exact hdc)
  rw [hV] at h
  exact EndsWith.pre (contract := true) (q := (W.into l' S', lc, Sc)) hS₁ hst₁ h hal' hde'

/-- A block that ends (`EndsWith contract` at frame `g`, above frames `rest`) with exit
`ret void`, from valuation `W` whose step count at its end is `t.k + n`: the thread's steps reach
the block's end on the memory `me` the block's effects make from `W`, and its next step is the
`ret`'s, with `g`'s `alloca` blocks dead: `.done` when `rest` is empty, else back to the caller.
For every flag, context, thread, memory, frames, valuation, block and summary. -/
theorem EndsWith.ret {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {g : Frame}
    {rest : List Frame} {W : Valuation} {l' n : Nat} {S' : Summary}
    (h : EndsWith contract c t m g rest (W, l', S')) (hk : W.k + S'.len = t.k + n)
    (hret : S'.exit = .ret) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + n⟩ me ∧ SEff.run W (vals W S'.nodes) S'.effs = .ok me ∧
      step c ⟨fe :: rest, t.k + n⟩ me = .ok (match (generalizing := false) rest with
        | [] => .done (g.allocas.foldl (fun m b => m.setLive b false) me)
        | g' :: gs => .next ⟨{ g'.set g.dest none none with pc := g'.pc + 1 } :: gs,
            t.k + n + 1⟩ (g.allocas.foldl (fun m b => m.setLive b false) me)) := by
  obtain ⟨fe, me, hS, -, -, hal, hde, -, -, hm, r, hn, hst⟩ := h
  rw [hret] at hn
  simp only [Exit.next, pure, Except.pure, Except.ok.injEq] at hn
  subst hn
  rw [← hal, ← hde, ← hk]
  cases rest <;> exact ⟨fe, me, hS, hm, hst⟩

/-- **A path with `phi`s and `alloca`s that returns, with or without `fmul contract`, under any
caller frames**: for every flag `alloca` and `contract`, `Block.sound_pathAt_ptrs` for a path
whose last block (entered with valuation `W` at label `l'` with summary `S'`,
`Valuation.lastWith contract`) has exit `ret void`, from a thread whose innermost frame `f` is
above frames `rest`: the thread's steps reach the last block's end at step count
`t.k + pathLen S ps`, on the memory `me` the last block's effects make from `W`, and its next step
is the `ret`'s, with the path's `alloca` blocks (`Valuation.allocsWith contract`) and `f`'s dead:
`.done` when `rest` is empty, else back to the caller `g` at the position after its call
(`g.set f.dest none none`: `ret void` sets no register). For every program, function and path
`coversPathAt alloca contract` accepts, and every list of caller frames; with the flag off the
path has no `alloca` blocks (`Valuation.allocsWith_nil`). -/
theorem Block.sound_retWith {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hc : coversPathAt alloca contract P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) {W : Valuation}
    {l' : Nat} {S' : Summary}
    (hq : (Valuation.entry c t.k m f).lastWith contract l S ps = (W, l', S'))
    (hret : S'.exit = .ret) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + pathLen S ps⟩ me ∧
      SEff.run W (vals W S'.nodes) S'.effs = .ok me ∧
      step c ⟨fe :: rest, t.k + pathLen S ps⟩ me = .ok (match (generalizing := false) rest with
        | [] => .done (((Valuation.entry c t.k m f).allocsWith contract l S ps ++ f.allocas).foldl
            (fun m b => m.setLive b false) me)
        | g :: gs => .next ⟨{ g.set f.dest none none with pc := g.pc + 1 } :: gs,
            t.k + pathLen S ps + 1⟩ (((Valuation.entry c t.k m f).allocsWith contract l S ps ++
              f.allocas).foldl (fun m b => m.setLive b false) me)) := by
  have h := (Block.sound_pathAt_ptrs hP ps hc ht hfn hl hp hW).1
  have hk := (Valuation.lastWith_k contract (Valuation.entry c t.k m f) l S ps).2.2
  rw [hq] at h hk
  exact h.ret hk hret

/-- A path from valuation `V` at its first block's entry to `ret`, leaving a memory of `Q`, with
or without `fmul contract`: its premises hold (`WalkWith contract`: each block's conditions at its
entry valuation, each exit but the last to the next block, an edge into a block with `phi`s
setting them), its last block's exit is `ret`, and the last block's effects succeed (`SEff.run`
at the last block's entry valuation, `Valuation.lastWith contract`) with a memory of `Q`. False
on the empty path. -/
def RetWith (contract : Bool) (V : Valuation) (Q : Mem → Prop) :
    List (Nat × List Cond × Summary) → Prop
  | [] => False
  | (l, ds, S) :: ps => WalkWith contract V ((l, ds, S) :: ps) ∧
      (V.lastWith contract l S ps).2.2.exit = .ret ∧
      ∃ me, SEff.run (V.lastWith contract l S ps).1
        (vals (V.lastWith contract l S ps).1 (V.lastWith contract l S ps).2.2.nodes)
        (V.lastWith contract l S ps).2.2.effs = .ok me ∧ Q me

/-- A path from valuation `V` at its first block's entry to `ret`, leaving a memory of `Q`:
`RetWith` without `fmul contract`, for every valuation, predicate and path. -/
def Ret (V : Valuation) (Q : Mem → Prop) (ps : List (Nat × List Cond × Summary)) : Prop :=
  RetWith false V Q ps

/-- A frame with no value set (`ret void`'s return to a caller) is the frame itself. -/
theorem Frame.set_none (g : Frame) (r : Option Nat) (p : Option (Val × Val)) :
    g.set r none p = g := by
  cases r <;> rfl

/-- **Return to a caller**: for every program, function and path that the path checker accepts
without `fmul contract` (`coversPathWith false`) and whose last block returns (`ret void`), every
context of the program and thread whose innermost frame `f`, at the path's first block and
position, has a caller frame `g` above frames `rest`, and every condition list `dg` and summary
`Sg` that `covers` accepts for `g`'s block from the position after the call (`g.pc + 1`): if the
path's premises hold (`WalkWith false`) and, for the memory `me` the last block's effects make
from its entry valuation (`Valuation.lastWith false`), `dg` holds at the entry valuation of
`{ g with pc := g.pc + 1 }` on `me` with `f`'s `alloca` blocks dead (at step count
`t.k + pathLen S ps + 1`), then the thread's steps run the path, return to `g` and run `g`'s
block from `g.pc + 1` to its end: it ends (`Ends`) from that valuation (`Block.sound_retWith`,
`Block.sound`). -/
theorem Block.sound_back {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f g : Frame} {rest : List Frame}
    (hc : coversPathWith false P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: g :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkWith false (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastWith false l S ps).2.2.exit = .ret)
    {dg : List Cond} {Sg : Summary} (hcg : covers P g.fn g.label (g.pc + 1) dg Sg = true)
    (hg : ∀ me, SEff.run ((Valuation.entry c t.k m f).lastWith false l S ps).1
        (vals ((Valuation.entry c t.k m f).lastWith false l S ps).1
          ((Valuation.entry c t.k m f).lastWith false l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastWith false l S ps).2.2.effs = .ok me →
      ∀ d ∈ dg, d.Holds (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
        (vals (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
          Sg.nodes)) :
    ∃ me, SEff.run ((Valuation.entry c t.k m f).lastWith false l S ps).1
        (vals ((Valuation.entry c t.k m f).lastWith false l S ps).1
          ((Valuation.entry c t.k m f).lastWith false l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastWith false l S ps).2.2.effs = .ok me ∧
      Ends c t m { g with pc := g.pc + 1 } rest
        (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 }, g.label,
          Sg) := by
  obtain ⟨fe, me, hS, hm, hst⟩ := Block.sound_retWith hP hc ht hfn hl hp hW rfl hret
  simp only [Valuation.allocsWith_nil ps hc, List.nil_append, Frame.set_none] at hst
  exact ⟨me, hm, Ends.pre hS hst
    (Block.sound hcg hP (t := ⟨{ g with pc := g.pc + 1 } :: rest, t.k + pathLen S ps + 1⟩) rfl
      rfl rfl rfl (hg me hm)) rfl rfl⟩

end MojoProof.Sym
