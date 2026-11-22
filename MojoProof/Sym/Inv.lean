import MojoProof.Sym.Vals

/-!
# Registers after a path or a round, and the tactic mojo_inv

A loop's invariant (`Round.of_inv`, MojoProof/Sym/Loop.lean) speaks of the registers at the
header after each round: the `phi`s take their operands' values on the back edge, and every other
register keeps the value it has at the end of the latch. This module gives them for every
program and loop.

* `Func.phiSets F r`: whether a `phi` of function `F` sets register `r` (the `phi`s at the head
  of a block, which `enter` sets on an edge into it).
* `Valuation.iterate_regs_keep`: for every flag `c` (with or without `fmul contract`), header,
  summary and path, valuation `V` of a function `F`, register `r` that no `phi` of `F` and no
  block of the path sets, and every count `i`, `i` rounds (`Valuation.roundWith c h S B`'s `i`-th
  iterate) keep `r`'s value at `V`. A path from any block with its last edge is
  `Valuation.roundWith` too (`NaiveThread.head`), so this covers paths as well as loops.

The registers after one edge are `Valuation.intoWith_regs_br`, `Valuation.intoWith_regs_cond` and
`Valuation.intoWith_regs_phi` (MojoProof/Sym/OblLemmas.lean): a branch keeps the block's
registers, and a branch into blocks with `phi`s sets the target's `phi`s to their operands'
values for the edge and keeps the others (`setRegs`, `setRegs_of_forall_ne`).

## The tactic

mojo_inv (syntax `mojoInv`, elaborator `evalMojoInv`, method `Inv.run`) proves the register
half of an invariant: a goal that is a register equation `V.regs r = some v`, or a conjunction of
them, for a valuation `V` after a path or rounds of a loop. Each local hypothesis gives its parts
too (`Obl.withFacts`: the conjuncts of one that unfolds to a conjunction, the fields of a structure
of propositions), so an invariant such as `SymLoop.invN` or a structure of facts as a hypothesis.
For `V`:

1. `i` rounds `f^[i] W` of a round `f` (`Valuation.roundWith c h S B` or `Valuation.round h S B`,
   or a constant that unfolds to one) for a count `i` that is no literal: a register that no
   `phi` of `W`'s function and no block of the round sets has its value at `W`
   (`Valuation.iterate_regs_keep`, the kernel deciding its two conditions);
2. otherwise `V` by its blocks and edges (rounds, a path's last block
   `(Valuation.lastWith c W l S ps).1`, iterates with a literal count, constants unfolded), and
   the register by mojo_obl's `Obl.regOf` (MojoProof/Sym/Obl.lean): through each block by the
   block's register list (`Valuation.after_regs_some`, `Valuation.after_regs_none`, the node's
   value from mojo_obl's evaluation) and through each edge by `Valuation.intoWith_regs_br`,
   `Valuation.intoWith_regs_cond` and `Valuation.intoWith_regs_phi` (the `phi`s' operands, the
   others by `setRegs_of_forall_ne`), down to a hypothesis on the entry frame's or valuation's
   register;
3. the value found equal to `v` by `Vals.conv` (syntax, congruence, kernel defeq, local equations,
   `omega`).

A register equation it does not prove, and a conjunct of another form, is left as a goal and
logged as `mojo_inv: open goal`; the goal left open has the hypotheses of the call, not their
parts. Tests: MojoProofTest/Inv.lean (`cnt`'s counter and bound after rounds, the naive matrix
product's counter `%47` after a round and along the path to its latch with the latch's comparison
`%49`, its bound `%16` after any number of rounds, its `phi`s `%47` and `%48` (a float constant)
at the loop's entry, and open-goal twins). The memory half of an invariant (the buffers and their
contents after a round's stores) is not here.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- Whether a `phi` of function `F` sets register `r`: some block of `F` has, among the `phi`s at
its head (those `enter` sets on an edge into the block), one with result `r`. -/
def Func.phiSets (F : Func) (r : Nat) : Bool :=
  F.blocks.toList.any fun b => (b.stmts.toList.takeWhile isPhi).any (·.res == some r)

/-- **The registers rounds keep.** For every flag `c` (with or without `fmul contract`), header
`h`, summary `S`, path `B`, valuation `V` whose function is `F`, register `r` that no `phi` of `F`
sets (`Func.phiSets`) and that no summary of `S :: B` sets (`Summary.regs`), value `v` of `r` at
`V` and count `i`: `r` is `v` after `i` rounds (`Valuation.roundWith c h S B`'s `i`-th iterate).
Each block keeps `r` (`Valuation.after`, by `regVal`); each edge too, since a branch's registers
are the block's and the frame `enter` gives sets the target's `phi`s alone (`foldl_set_regs`,
`setRegs_of_forall_ne`). For every program, loop and path. -/
theorem Valuation.iterate_regs_keep {c : Bool} {h : Nat} {S : Summary}
    {B : List (Nat × List Cond × Summary)} {V : Valuation} {F : Func} {r : Nat} {v : Val}
    (hF : V.fn = F) (hP : Func.phiSets F r = false)
    (hS : (S :: B.map (·.2.2)).all (fun S => (S.regs.lookup r).isNone) = true)
    (hv : V.regs r = some v) (i : Nat) :
    ((Valuation.roundWith c h S B)^[i] V).regs r = some v := by
  -- the frame `enter` gives from a frame of `F` keeps `r`
  have hen : ∀ (s : Scope) (f0 : Frame) (d : Nat) (f : Frame), f0.fn = F →
      enter s f0 d = .ok f → f.regs r = f0.regs r := by
    intro s f0 d f hf he
    cases hb : f0.fn.blocks.find? (·.label == d) with
    | none =>
      simp only [enter, hb] at he
      cases he
    | some b =>
      rw [enter_of_find hb] at he
      obtain ⟨xs, -, he⟩ := Except.bind_eq_ok.1 he
      simp only [pure, Except.pure, Except.ok.injEq] at he
      subst he
      refine (congrFun (foldl_set_regs _ xs f0) r).trans (setRegs_of_forall_ne fun o ho e => ?_)
      obtain ⟨st, hst, rfl⟩ := List.mem_map.1 ho
      have hbF : b ∈ F.blocks.toList := by
        rw [← hf]
        exact Array.mem_toList_iff.2 (Array.mem_of_find?_eq_some hb)
      have hT : Func.phiSets F r = true :=
        List.any_eq_true.2 ⟨b, hbF, List.any_eq_true.2 ⟨st, hst, by simp [e]⟩⟩
      rw [hP] at hT
      cases hT
  -- an edge from a valuation of `F` keeps the block's `r`
  have edge : ∀ (W : Valuation) (l : Nat) (T : Summary), W.fn = F →
      (W.intoWith c l T).regs r = (W.afterWith c T).regs r := by
    intro W l T hW
    unfold Valuation.intoWith
    split
    · split
      · rename_i f he
        exact hen _ (W.frameAtWith c l T) _ f hW he
      · rfl
    · rfl
  -- a block that does not set `r` keeps it
  have blk : ∀ (W : Valuation) (T : Summary), (T.regs.lookup r).isNone = true →
      (W.afterWith c T).regs r = W.regs r := by
    intro W T hT
    have hl : T.regs.lookup r = none := Option.isNone_iff_eq_none.1 hT
    show (W.after T).regs r = W.regs r
    simp only [Valuation.after, regVal, hl]
  -- one round
  have round : ∀ (B : List (Nat × List Cond × Summary)) (h : Nat) (S : Summary) (W : Valuation),
      W.fn = F → (S :: B.map (·.2.2)).all (fun S => (S.regs.lookup r).isNone) = true →
      (W.roundWith c h S B).regs r = W.regs r := by
    intro B
    induction B with
    | nil =>
      intro h S W hW hS
      simp only [List.map_nil, List.all_cons, List.all_nil, Bool.and_true] at hS
      exact (edge W h S hW).trans (blk W S hS)
    | cons p B ih =>
      intro h S W hW hS
      obtain ⟨l', ds, S'⟩ := p
      simp only [List.map_cons, List.all_cons, Bool.and_eq_true] at hS
      show ((W.intoWith c h S).roundWith c l' S' B).regs r = W.regs r
      rw [ih l' S' _ ((Valuation.intoWith_k c W h S).2.1.trans hW)
        (by simp only [List.all_cons, Bool.and_eq_true]; exact hS.2)]
      exact (edge W h S hW).trans (blk W S hS.1)
  induction i generalizing V with
  | zero => exact hv
  | succ i ih =>
    exact ih ((Valuation.roundWith_k c h S B 1 V).2.1.trans hF) ((round B h S V hF hS).trans hv)

namespace Inv

open Lean Meta Elab Tactic Obl

/-- `f` as a round: `(c, h, S, B)` for `Valuation.roundWith c h S B`, and `(false, h, S, B)` for
`Valuation.round h S B` (definitionally `Valuation.roundWith false h S B`), after unfolding the
constants at its head (as `NaiveThread.round`); `none` for another function. -/
partial def roundOf? (f : Expr) : MetaM (Option (Expr × Expr × Expr × Expr)) := do
  let f := f.eta
  match f.getAppFnArgs with
  | (``Valuation.roundWith, #[c, h, S, B]) => return some (c, h, S, B)
  | (``Valuation.round, #[h, S, B]) => return some (mkConst ``Bool.false, h, S, B)
  | _ =>
    unless f.getAppFn.isConst do return none
    match ← unfoldDefinition? f with
    | some f' => roundOf? f'.headBeta
    | none => return none

/-- The heads `Obl.normV` reads; `pathV` unfolds any other constant at the head first. -/
def heads : List Name :=
  [``Valuation.after, ``Valuation.into, ``Valuation.afterWith, ``Valuation.intoWith,
    ``Valuation.entry, ``Valuation.round, ``Valuation.roundWith, ``Nat.iterate]

/-- Valuation `V` by its blocks and edges, for `Obl.regOf`: a path's last block
`(Valuation.lastWith c W l S ps).1` (or `(W.lastI l S ps).1`) as `Valuation.intoWith c` (or
`Valuation.into`) along the path (`Obl.lastIOf`); a constant at the head other than those of
`heads` unfolded (as `NaiveThread.latchAt`); otherwise `Obl.normV`. The kernel checks the result
equal to `V`. -/
partial def pathV (V : Expr) : MetaM Expr := do
  match V.getAppFnArgs with
  | (``Prod.fst, #[_, _, p]) =>
    match p.getAppFnArgs with
    | (``Valuation.lastWith, #[c, W, l, S, ps]) =>
      return (← lastIOf (some c) (← normV W) l S ps).1
    | (``Valuation.lastI, #[W, l, S, ps]) => return (← lastIOf none (← normV W) l S ps).1
    | _ => return V
  | (n, _) =>
    if n.isAnonymous || heads.contains n then return ← normV V
    match ← unfoldDefinition? V with
    | some V' => pathV V'.headBeta
    | none => normV V

/-- **The value of register `r` at `V`**: `(v, V.regs r = some v)`. For `i` rounds `f^[i] W` of
a round `f` (`roundOf?`) with a count `i` that is no literal, the value at `W` when no `phi` of
`W`'s function and no block of the round sets `r` (`Valuation.iterate_regs_keep`, the kernel
deciding both); otherwise `Obl.regOf` on `V` by its blocks and edges (`pathV`). -/
partial def reg (V : Expr) (r : Nat) : M (Expr × Expr) := do
  let ty (v : Expr) : MetaM Expr := do
    mkEq (mkApp2 (mkConst ``Valuation.regs) V (mkNatLit r)) (← mkSome (mkConst ``Val) v)
  if let (``Nat.iterate, #[_, f, i, W]) := V.getAppFnArgs then
    if (← try some <$> natOf i catch _ => pure none).isNone then
      if let some (c, h, S, B) ← roundOf? f then
        let (v, hv) ← reg W r
        let (F, hF) ← fnOf W
        let (p, _) ← use ``Valuation.iterate_regs_keep
          [(`c, c), (`h, h), (`S, S), (`B, B), (`V, W), (`F, F), (`r, mkNatLit r)]
          [.kd hF, .dec, .dec, .pf hv, .pf i]
        return (v, hint p (← ty v))
  let (v, h) ← regOf (← pathV V) r
  return (v, hint h (← ty v))

/-- A proof of `ty`: a conjunction conjunct by conjunct, and a register equation
`V.regs r = some v` by `reg` and `Vals.conv` (the value found equal to `v`), checked by the
kernel; a register equation it does not prove, and a goal of another form, is left open and
logged (`Obl.attempt`, `Obl.openGoal`). -/
partial def prove (ty : Expr) : M Expr := do
  let ty := (← instantiateMVars ty).consumeMData
  match ty.getAppFnArgs with
  | (``And, #[a, b]) => return mkApp4 (mkConst ``And.intro) a b (← prove a) (← prove b)
  | (``Eq, #[_, lhs, rhs]) =>
    match lhs.getAppFnArgs, rhs.getAppFnArgs with
    | (``Valuation.regs, #[V, r]), (``Option.some, #[_, v]) =>
      attempt ty do
        let (v', h) ← reg V (← natOf r)
        let e ← Vals.conv v' v
        mkEqTrans h (← mkCongrArg (mkApp (mkConst ``Option.some [Level.zero]) (mkConst ``Val)) e)
    | _, _ => openGoal ty
  | _ => openGoal ty

/-- **`mojo_inv` on goal `g`**: the goals it leaves open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let ty ← instantiateMVars (← g.getType)
    let (p, st) ← (withFacts (prove ty)).run { name := "mojo_inv" }
    g.assign p
    for m in st.dbgs do logInfo m
    return st.opens

end Inv

/-- **`mojo_inv`** proves the register half of a loop's invariant: a goal `V.regs r = some v`, or
a conjunction of them, for a valuation `V` after a path or rounds of a loop, from the hypotheses
found by type as mojo_obl finds them (the registers `f.regs r = some v` of an entry frame or
`W.regs r = some v`, the function `f.fn = F` or `W.fn = F`, the program, the launch, struct loads,
buffers), each hypothesis with its parts (`Obl.withFacts`: its conjuncts and the fields of a
structure of propositions).

After `i` rounds `f^[i] W` of a round `f` (`Valuation.roundWith c h S B`, `Valuation.round h S B`
or a constant that unfolds to one) for a count `i` that is no literal, a register that no `phi`
of the function and no block of the round sets is its value at `W`
(`Valuation.iterate_regs_keep`). Otherwise `V` is read by its blocks and edges (rounds, a path's
last block `(Valuation.lastWith c W l S ps).1`, iterates with a literal count, constants
unfolded): the register is the block's operand for it, evaluated as mojo_obl evaluates nodes, or
its value before the block; after an edge into blocks with `phi`s, a `phi`'s operand for the edge
(`Valuation.intoWith_regs_phi`), and otherwise the value before the edge
(`Valuation.intoWith_regs_br`, `Valuation.intoWith_regs_cond`, `setRegs_of_forall_ne`). The value
found is then proved equal to `v` (`Vals.conv`). Each register equation it does not prove, and
each conjunct of another form, is left as a goal and logged as `mojo_inv: open goal`. -/
syntax (name := mojoInv) "mojo_inv" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_inv` on the main goal. -/
@[tactic mojoInv] def evalMojoInv : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Inv.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
