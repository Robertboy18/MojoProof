import MojoProof.Sym.Vals

/-!
# Registers and memory after a path or a round, and the tactic mojo_inv

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

mojo_inv (syntax `mojoInv`, elaborator `evalMojoInv`, method `Inv.run`) proves an invariant at a
valuation `V` after a path or rounds of a loop: a conjunction, or a structure of propositions
field by field, of register equations `V.regs r = some v`, the function `V.fn = F`, the
`fmul contract` operands `V.prods r = p`, and memory facts at `V.mem`. Each local hypothesis gives
its parts too (`Obl.withFacts`: the conjuncts of one that unfolds to a conjunction, the fields of
a structure of propositions), so an invariant such as `SymLoop.invN` or a structure of facts as a
hypothesis. A register equation, for `V`:

1. `i` rounds `f^[i] W` of a round `f` (`Valuation.roundWith c h S B` or `Valuation.round h S B`,
   or a constant that unfolds to one) for a count `i` that is no literal: a register that no
   `phi` of `W`'s function and no block of the round sets has its value at `W`
   (`Valuation.iterate_regs_keep`, the kernel deciding its two conditions);
2. otherwise `V` by its blocks and edges (rounds, a path's last block
   `(Valuation.lastWith c W l S ps).1`, iterates with a literal count, constants unfolded), and
   the register by mojo_obl's `Obl.regOf` (MojoProof/Sym/Obl.lean): through each block by the
   block's register list (`Valuation.after_regs_some`, `Valuation.after_regs_none`, the node's
   value from mojo_obl's evaluation) and through each edge by `Valuation.intoWith_regs_br`,
   `Valuation.intoWith_regs_cond` and `Valuation.intoWith_regs_phi` (the `phi`s' operands), the
   registers no `phi` sets by `Valuation.intoWith_regs_phi_ne` (no operand evaluated), down to a
   hypothesis on the entry frame's or valuation's register;
3. the value found equal to `v` by `Vals.conv` (syntax, congruence, kernel defeq, local equations,
   `omega`).

The function and the `fmul contract` operands are mojo_obl's `Obl.fnOf` and `Obl.prodOf` on `V`
by its blocks and edges, each after a hypothesis with the goal's left side. A memory fact
(`Inv.memFact`) is a goal `Mem.Buffer`, `Mem.Fits`, `Mem.Holds`, `Elem` or `Elem.Only` at `V.mem`,
with `V.mem` the memory `M₀` before `V`'s blocks with the events they log (a hypothesis
`V.mem = M`, as `obl_have` gives, or `Obl.memOf`): a buffer fact is its hypothesis at `M₀`, the
kernel checking that `V.mem` has `M₀`'s blocks; `Elem` and `Elem.Only` are their hypotheses at
`M₀` through each event, which must be a read that is not an `atomicrmw`'s (`Elem.log_read`) or
an access (`Elem.Only.log_other`) of a block other than the output block, the inequality by
`omega`. On a memory `m` an effect gives (a hypothesis `SEff.apply V vs M e = .ok m`, or a block's
run of one effect, as a path's last block's in `RetWith`; `SEff.run_one`), `Elem.Only` is its fact
at `M` through the effect, the thread in the set by a hypothesis (`Elem.Only.apply`), and `Elem`
after `k + 1` threads is `Elem` after `k` threads at `M` through a store (`Elem.apply_store`): the
store's statement from `V`'s function, its operands' values as mojo_obl evaluates them, `V`'s thread
from the hypotheses on its context, and on `V`'s program the value's encoding by a hypothesis and
the store's width by the kernel.

The proof is first built unchecked, and the kernel checks it once; when a goal is left open or
the kernel rejects it, each goal's proof is built again and checked on its own (`attemptIf`), so
that a proof the kernel rejects leaves only its goal open. A goal it does not prove, and a goal of
another form, is left as a goal and logged as `mojo_inv: open goal`; the goal left open has the
hypotheses of the call, not their parts. Tests:
MojoProofTest/Inv.lean (`cnt`'s counter and bound after rounds, the naive matrix product's counter
`%47` after a round and along the path to its latch with the latch's comparison `%49`, its bound
`%16` after any number of rounds, its `phi`s `%47` and `%48` (a float constant) at the loop's
entry, the buffers, `Elem` and `Elem.Only` after a round and after its last block's store, and
open-goal twins); MojoProofTest/NaiveFamRun.lean (`head_inF`'s and `round_inF`'s `%48` operands,
and `exit_inF`'s `%40` and its `Elem` and `Elem.Only` after the store, at every row stride);
MojoProof/Sym/KernelCmd.lean (`mat … inv`'s `Mat.Head` at the loop head, a structure of the
function and the memory facts above, and the function at the loop head in `n.kept`).
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

/-- **A read of another block keeps `Elem`**: logging a read that is not an `atomicrmw`'s
(`a.write = false`, `a.atomic = none`) of a block other than `out` on a memory of `Elem` after
`k` threads gives a memory of `Elem` after `k` threads, for every memory, output block, cell
width, cells, bytes and access (`Elem.log`). -/
theorem Elem.log_read {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m : Mem} {a : Access}
    (h : Elem m₀ out w cell bs k m) (hq : a.ptr.block ≠ out) (hw : a.write = false)
    (hx : a.atomic = none) : Elem m₀ out w cell bs k (m.log (.access a)) :=
  h.log ⟨fun e => absurd e hq, fun _ => ⟨hw, hx⟩, fun _ => hq⟩

/-- **An access to another block keeps `Elem.Only`**: logging an access to a block other than
`out` keeps `Elem.Only out S`, for every output block, set of threads, memory and access
(`Elem.Only.log`). -/
theorem Elem.Only.log_other {out : Nat} {S : Nat → Prop} {m : Mem} {a : Access}
    (h : Elem.Only out S m) (hq : a.ptr.block ≠ out) : Elem.Only out S (m.log (.access a)) :=
  h.log fun e => absurd e hq

/-- **A memory with `m`'s blocks has each of them**: for every two memories `m`, `m'` with the
same blocks and every block number `q`, the premise of `Mem.Buffer.of_block`, `Mem.Fits.of_block`
and `Mem.Holds.of_block`. -/
theorem Mem.blocks_keep {m m' : Mem} (h : m'.blocks = m.blocks) (q : Nat) :
    ∀ x, m.blocks q = some x → m'.blocks q = some x := fun x hx => by rw [h]; exact hx

/-- **A run of one effect is its application** to the valuation's memory, for every valuation,
node values, effect and memory: the premise `ha` of `Elem.apply_store` and `Elem.Only.apply` from
a block's run (`SEff.run`) of one store. -/
theorem SEff.run_one {V : Valuation} {vs : List (Except Fault Val)} {e : SEff} {m : Mem}
    (h : SEff.run V vs [e] = .ok m) : SEff.apply V vs V.mem e = .ok m := by
  simpa only [SEff.run, List.foldlM_cons, List.foldlM_nil, bind_pure] using h

namespace Inv

open Lean Meta Elab Tactic Obl

/-- `f` as a round: `(c, h, S, B)` for `Valuation.roundWith c h S B`, and `(false, h, S, B)` for
`Valuation.round h S B` (by definition `Valuation.roundWith false h S B`), after unfolding the
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
`(Valuation.lastWith c W l S ps).1` as `Valuation.intoWith c` along the path (`Obl.lastIOf`); a
constant at the head other than those of `heads` unfolded (as `NaiveThread.latchAt`); otherwise
`Obl.normV`. The kernel checks the result equal to `V`. -/
partial def pathV (V : Expr) : MetaM Expr := do
  match V.getAppFnArgs with
  | (``Prod.fst, #[_, _, p]) =>
    match p.getAppFnArgs with
    | (``Valuation.lastWith, #[c, W, l, S, ps]) =>
      return (← lastIOf (some c) (← normV W) l S ps).1
    | _ => return V
  | (n, _) =>
    if n.isAnonymous || heads.contains n then return ← normV V
    match ← unfoldDefinition? V with
    | some V' => pathV V'.headBeta
    | none => normV V

/-- **The value of register `r` at `V`**: `(v, V.regs r = some v)`. For `i` rounds `f^[i] W` of
a round `f` (`roundOf?`) with a count `i` that is no literal, the value at `W` when no `phi` of
`W`'s function and no block of the round sets `r` (`Valuation.iterate_regs_keep`, the kernel
deciding both; the function `Obl.fnOf` of `W` by its blocks and edges, `pathV`, so `W` may be a
valuation after a path); otherwise `Obl.regOf` on `V` by its blocks and edges (`pathV`). -/
partial def reg (V : Expr) (r : Nat) : M (Expr × Expr) := do
  let ty (v : Expr) : MetaM Expr := do
    mkEq (mkApp2 (mkConst ``Valuation.regs) V (mkNatLit r)) (← mkSome (mkConst ``Val) v)
  if let (``Nat.iterate, #[_, f, i, W]) := V.getAppFnArgs then
    if (← try some <$> natOf i catch _ => pure none).isNone then
      if let some (c, h, S, B) ← roundOf? f then
        let (v, hv) ← reg W r
        let (F, hF) ← fnOf (← pathV W)
        let (p, _) ← use ``Valuation.iterate_regs_keep
          [(`c, c), (`h, h), (`S, S), (`B, B), (`V, W), (`F, F), (`r, mkNatLit r)]
          [.kd hF, .dec, .dec, .pf hv, .pf i]
        return (v, hint p (← ty v))
  let (v, h) ← regOf (← pathV V) r
  return (v, hint h (← ty v))

/-- A local hypothesis `e = x` whose left side is `e` itself: `(x, proof)`; `none` when there is
none. -/
def hypEq? (e : Expr) : MetaM (Option (Expr × Expr)) := do
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (_, l, x) := (← instantiateMVars d.type).eq? | continue
    if l == e then return some (x, d.toExpr)
  return none

/-- **The memory of `V`**: `(M, V.mem = M)`, from a hypothesis with left side `V.mem` (as
`obl_have` gives), else by mojo_obl's evaluation of `V`'s blocks and edges (`Obl.memOf` on
`pathV`). -/
def memEq (V : Expr) : M (Expr × Expr) := do
  let e := mkApp (mkConst ``Valuation.mem) V
  if let some r ← hypEq? e then return r
  let (M, h, _) ← memOf (← pathV V)
  return (M, hint h (← mkEq e M))

/-- **The context of `V`**: `(c, V.ctx = c)`, `c` the entry valuation's context, else the context
of the valuation under `V`'s blocks and edges (`pathV`, `Obl.rootOf`) or the right side of a
hypothesis on it (`Obl.eqHyp`), through each edge by `Obl.intoField`. -/
def ctxEq (V : Expr) : M (Expr × Expr) := do
  let V' ← pathV V
  let (c, hc) ← match baseOf V' with
    | (c, _, some _) => pure (c, ← mkEqRefl c)
    | (rc, _, none) => eqHyp rc
  let h ← match ← intoField 0 V' with
    | some h => mkEqTrans h hc
    | none => pure hc
  return (c, hint h (← mkEq (mkApp (mkConst ``Valuation.ctx) V) c))

/-- **The thread of `V`**: `(y, V.ctx.who.thread = y)`, from the context (`ctxEq`) and a
hypothesis `c.who = ⟨y, _⟩` or `c.who.thread = y` on it (`Obl.eqHyp`). -/
def threadEq (V : Expr) : M (Expr × Expr) := do
  let (c, hc) ← ctxEq V
  let (X, hX) ← eqHyp (mkApp (mkConst ``Ctx.who) c)
  let hw ← mkEqTrans (← mkCongrArg (mkConst ``Ctx.who) hc) hX
  let th (e : Expr) := mkApp (mkConst ``Who.thread) e
  let (y, hy) ← match X.getAppFnArgs with
    | (``Who.mk, #[y, _]) => pure (y, ← mkEqRefl (th X))
    | _ => eqHyp (th X)
  return (y, hint (← mkEqTrans (← mkCongrArg (mkConst ``Who.thread) hw) hy)
    (← mkEq (th (whoOf V)) y))

/-- **A fact `t` on `V.ctx.prog`** from `k`'s proof of `t` with `P` for `V.ctx.prog`, where
`V.ctx.prog = P` (`ctxEq`, and a hypothesis `c.prog = P` on the context). -/
def viaProg (V t : Expr) (k : Expr → M Expr) : M Expr := do
  let (c, hc) ← ctxEq V
  let (P, hP) ← eqHyp (mkApp (mkConst ``Ctx.prog) c)
  let hQ ← mkEqTrans (← mkCongrArg (mkConst ``Ctx.prog) hc) hP
  let t ← instantiateMVars t
  let body ← kabstract t (mkApp (mkConst ``Ctx.prog) (mkApp (mkConst ``Valuation.ctx) V))
  unless body.hasLooseBVars do throwError "mojo_inv: no program of{indentExpr V}\nin{indentExpr t}"
  let f := Expr.lam `P (mkConst ``Program) body .default
  let p ← k (body.instantiate1 P)
  return hint (← mkEqMPR (← mkCongrArg f hQ) p) t

/-- A local hypothesis that memory `m` is an effect's: `SEff.apply V vs M e = .ok m`, or
`SEff.run V vs es = .ok m` (a block's run, as `RetWith` gives) for `es` the one effect `e`, as
`SEff.apply V vs V.mem e = .ok m` (`SEff.run_one`); `none` when there is none. -/
def effHyp? (m : Expr) : MetaM (Option Expr) := do
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let t ← instantiateMVars d.type
    let some (_, l, r) := t.eq? | continue
    unless r.isAppOfArity ``Except.ok 3 && r.appArg! == m do continue
    match l.getAppFnArgs with
    | (``SEff.apply, #[_, _, _, _]) => return some d.toExpr
    | (``SEff.run, #[V, vs, es]) =>
      let [e] ← (try klist es catch _ => pure []) | continue
      let e ← kdeep e 2
      let h := hint d.toExpr
        (← mkEq (mkApp3 (mkConst ``SEff.run) V vs (← mkListLit (mkConst ``SEff) [e])) r)
      return some (mkApp5 (mkConst ``SEff.run_one) V vs e m h)
    | _ => continue
  return none

/-- The memory `M` as `M₀` under logged events: `(M₀, [eₙ, …, e₁])` for
`M = (M₀.log e₁)….log eₙ`. -/
partial def logs (M : Expr) : Expr × List Expr :=
  match M.getAppFnArgs with
  | (``Mem.log, #[M', e]) => let (b, es) := logs M'; (b, e :: es)
  | _ => (M, [])

/-- The memory facts that read one block, with the lemma that moves each to a memory with that
block (whose block number is the argument after the memory). -/
def blockLemmas : List (Name × Name) :=
  [(``Mem.Buffer, ``Mem.Buffer.of_block), (``Mem.Fits, ``Mem.Fits.of_block),
    (``Mem.Holds, ``Mem.Holds.of_block)]

/-- Whether `n` is the head of a memory fact `memFact` proves. -/
def memHead (n : Name) : Bool :=
  (blockLemmas.lookup n).isSome || n == ``Elem || n == ``Elem.Only

/-- **A memory fact at `V.mem`**: a goal `P … V.mem …` for `P` one of `Mem.Buffer`, `Mem.Fits`,
`Mem.Holds`, `Elem` and `Elem.Only` (`memHead`), with `V.mem = M` (`memEq`) and `M` the memory
`M₀` under logged events (`logs`). A buffer fact is its hypothesis at `M₀` moved by `blockLemmas`
(the kernel checks that `M` has `M₀`'s blocks; `Mem.blocks_keep`); `Elem` and `Elem.Only` are
their hypotheses at `M₀` through each event, a read that is not an `atomicrmw`'s (for `Elem`)
or an access of a block other than the output block (`Elem.log_read`, `Elem.Only.log_other`,
the block's inequality by `omega`, the block read off the access's pointer). On a memory `m` an
effect gives (`effHyp?`: `SEff.apply V vs M e = .ok m`, or a block's run of one effect), `Elem.Only`
is its fact at `M` (`memFact` at `V.mem`, else a hypothesis) through the effect, a thread `y` of the
set by a hypothesis (`Elem.Only.apply`, `threadEq`), and `Elem` after `k + 1` threads, through a
store, is `Elem` after `k` threads at `M` through it (`Elem.apply_store`): the store's statement
from `V`'s function (`Valuation.stmt_of_fn`), its operands' values (`Obl.opnd`, on the nodes
`vals V S.nodes` of `vs`), the thread `k` (`threadEq`), and on `V.ctx.prog` (`viaProg`) the
value's encoding `bs k` by a hypothesis and the store's width at most `w` by the kernel or a
hypothesis. An error when it does not prove the goal. For every program. -/
partial def memFact (ty : Expr) : M Expr := do
  let f := ty.getAppFn
  let args := ty.getAppArgs
  let n := f.constName?.getD .anonymous
  let some i := args.findIdx? (·.isAppOfArity ``Valuation.mem 1)
    | do
      let fail : M Expr := throwError "mojo_inv: no valuation's memory in{indentExpr ty}"
      let some ha ← effHyp? args.back! | fail
      let (``Eq, #[_, ap, _]) := (← inferType ha).getAppFnArgs | fail
      let #[V, vs, Mb, e] := ap.getAppArgs | fail
      let before (t : Expr) : M Expr :=
        if Mb.isAppOfArity ``Valuation.mem 1 then memFact t else findHyp t
      if n == ``Elem.Only then
        let h ← before (mkAppN f (args.set! 2 Mb))
        let hS (t : Expr) : M Expr := do
          let (y, hy) ← threadEq V
          let t' := (mkApp args[1]! y).headBeta
          let p ← try findHyp t' catch err => do
            let some d ← findLocalDeclWithType? t' | throw err
            pure (mkFVar d)
          return hint (← mkEqMPR (← mkCongrArg args[1]! hy) p) t
        return (← use ``Elem.Only.apply [] [.pf h, .fn hS, .pf ha]).1
      unless n == ``Elem do throwError "mojo_inv: no valuation's memory in{indentExpr ty}"
      let (``HAdd.hAdd, #[_, _, _, _, k, one]) := args[5]!.getAppFnArgs
        | throwError "mojo_inv: no count k + 1 in{indentExpr ty}"
      unless (← natOf one) == 1 do throwError "mojo_inv: no count k + 1 in{indentExpr ty}"
      let h ← before (mkAppN f ((args.set! 5 k).set! 6 Mb))
      let (``SEff.store, #[lbl, pc, v, p]) := (← kdeep e 2).getAppFnArgs
        | throwError "mojo_inv: no store{indentExpr e}"
      let (``vals, #[_, ns]) := vs.getAppFnArgs | throwError "mojo_inv: no nodes{indentExpr vs}"
      let (``Summary.nodes, #[S]) := ns.getAppFnArgs
        | throwError "mojo_inv: no summary's nodes{indentExpr vs}"
      let V' ← pathV V
      let (x, hx) ← opnd V' S none v
      let hx := hint hx (← mkEq (mkApp3 (mkConst ``SVal.eval) V vs v) (mkOk x))
      let (_, hp) ← opnd V' S none p
      let hs (_ : Expr) : M Expr := do
        let (F, hF) ← fnOf V'
        let hF := hint hF (← mkEq (mkApp (mkConst ``Valuation.fn) V) F)
        return (← use ``Valuation.stmt_of_fn [(`V, V), (`fn, F), (`lbl, lbl), (`pc, pc)]
          [.pf hF, .rfl]).1
      let hw (t : Expr) : M Expr := do
        let (y, hy) ← threadEq V
        let some (_, _, k') := (← instantiateMVars t).eq? | throwError "mojo_inv: thread"
        let r ← try krfl y k' catch _ => do arith (← mkEq y k')
        mkEqTrans hy r
      let he (t : Expr) : M Expr := viaProg V t fun t => do
        try findHyp t catch err =>
          let some (_, a, b) := t.eq? | throw err
          try krfl a b catch _ => throw err
      let hl (t : Expr) : M Expr := viaProg V t fun t => do
        try closedDec t catch _ => findHyp t
      return (← use ``Elem.apply_store []
        [.pf h, .pf ha, .fn hs, .fn hw, .pf hx, .kd hp, .fn he, .fn hl]).1
  let (M, hM) ← memEq args[i]!.appArg!
  let (M0, es) := logs M
  let h0 ← findHyp (mkAppN f (args.set! i M0))
  if let some lem := blockLemmas.lookup n then
    let bl (m : Expr) := mkApp (mkConst ``Mem.blocks) m
    let hb ← mkEqTrans (← mkCongrArg (mkConst ``Mem.blocks) hM) (← krfl (bl M) (bl M0))
    let some q := args[i + 1]? | throwError "mojo_inv: no block in{indentExpr ty}"
    return hint (← mkAppM lem #[← mkAppM ``Mem.blocks_keep #[hb, q], h0]) ty
  let some out := (if n == ``Elem then args[1]? else args[0]?)
    | throwError "mojo_inv: no output block in{indentExpr ty}"
  let mut p := h0
  for e in es.reverse do
    let (``Event.access, #[a]) := e.getAppFnArgs
      | throwError "mojo_inv: an event other than an access{indentExpr e}"
    let q ← kwhnf (mkApp (mkConst ``Access.ptr) a)
    let blk := match q.getAppFnArgs with
      | (``MojoProof.Sem.Ptr.mk, #[b, _]) => b
      | _ => mkApp (mkConst ``Ptr.block) q
    let hq := hint (← arith (mkNot (← mkEq blk out)))
      (← mkAppM ``Ne #[mkApp (mkConst ``Ptr.block) (mkApp (mkConst ``Access.ptr) a), out])
    p ← if n == ``Elem then
        mkAppM ``Elem.log_read #[p, hq, ← krfl (mkApp (mkConst ``Access.write) a)
          (mkConst ``Bool.false), ← krfl (mkApp (mkConst ``Access.atomic) a)
          (mkApp (mkConst ``Option.none [Level.zero]) (mkConst ``RmwOp))]
      else mkAppM ``Elem.Only.log_other #[p, hq]
  let motive := Expr.lam `M (mkConst ``Mem) (mkAppN f (args.set! i (.bvar 0))) .default
  return hint (← mkEqMPR (← mkCongrArg motive hM) p) ty

/-- Proof `k` of `ty`: with `chk`, `Obl.attempt` (the kernel checking it); without, unchecked.
Either way the goal is left open and logged when `k` fails (`Obl.openGoal`). -/
def attemptIf (chk : Bool) (ty : Expr) (k : M Expr) : M Expr := do
  if chk then return ← attempt ty k
  let s ← (saveState : MetaM Meta.SavedState)
  try return hint (← instantiateMVars (← k)) ty
  catch e =>
    (s.restore : MetaM Unit)
    dbg m!"mojo_inv: {e.toMessageData}{indentExpr ty}"
    openGoal ty

/-- A proof of `ty`: a conjunction conjunct by conjunct; a register equation `V.regs r = some v`
by a hypothesis with that left side or `reg`, and `Vals.conv` (the value found equal to `v`); the
function `V.fn = F` (`Obl.fnOf`) and the `fmul contract` operands `V.prods r = p` (`Obl.prodOf`),
each by a hypothesis with that left side first; a memory fact (`memFact`); and a structure of
propositions (as an invariant's), field by field. With `chk`, each is checked by the kernel
(`attemptIf`); a goal it does not prove, and a goal of another form, is left open and logged
(`Obl.openGoal`). -/
partial def prove (chk : Bool) (ty : Expr) : M Expr := do
  let ty := (← instantiateMVars ty).consumeMData.headBeta
  -- `lhs = rhs` from a hypothesis `lhs = x` or `find`, and `x` equal to `rhs` by `eq`
  let byHyp (lhs rhs : Expr) (find : M (Expr × Expr)) (eq : Expr → Expr → M Expr) : M Expr :=
    attemptIf chk ty do
      let (x, h) ← match ← hypEq? lhs with
        | some r => pure r
        | none => find
      mkEqTrans (hint h (← mkEq lhs x)) (← eq x rhs)
  let kr (a b : Expr) : M Expr := krfl a b
  match ty.getAppFnArgs with
  | (``And, #[a, b]) => return mkApp4 (mkConst ``And.intro) a b (← prove chk a) (← prove chk b)
  | (``Eq, #[_, lhs, rhs]) =>
    match lhs.getAppFnArgs, rhs.getAppFnArgs with
    | (``Valuation.regs, #[V, r]), (``Option.some, #[_, v]) =>
      byHyp lhs rhs
        (do let (v', h) ← reg V (← natOf r); return (← mkSome (mkConst ``Val) v', h))
        fun x _ => do
          let (``Option.some, #[_, v']) := x.getAppFnArgs | throwError "mojo_inv: no value"
          mkCongrArg (mkApp (mkConst ``Option.some [Level.zero]) (mkConst ``Val)) (← Vals.conv v' v)
    | (``Valuation.fn, #[V]), _ => byHyp lhs rhs (fnOf (← pathV V)) kr
    | (``Valuation.prods, #[V, r]), _ => byHyp lhs rhs (prodOf (← pathV V) (← natOf r)) kr
    | _, _ => openGoal ty
  | (n, args) =>
    if memHead n then return ← attemptIf chk ty (memFact ty)
    let env ← getEnv
    unless isStructure env n && (← isProp ty) do return ← openGoal ty
    -- a structure of propositions, field by field
    let ctor := getStructureCtor env n
    let mut c := mkAppN (mkConst ctor.name ty.getAppFn.constLevels!) args
    let mut t ← whnf (← inferType c)
    for _ in [0:ctor.numFields] do
      let .forallE _ d b _ := t | return ← openGoal ty
      let pd ← prove chk d
      c := mkApp c pd
      t ← whnf (b.instantiate1 pd)
    return hint c ty

/-- **`mojo_inv` on goal `g`**: the goals it leaves open. First each goal's proof unchecked
(`prove false`), the kernel checking the whole proof once; when a goal is left open or the kernel
rejects the proof, again with each goal's proof checked (`prove true`), so that a proof the
kernel rejects leaves only its goal open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let ty ← instantiateMVars (← g.getType)
    let s ← (saveState : MetaM Meta.SavedState)
    let (p, st) ← (withFacts (prove false ty)).run { name := "mojo_inv" }
    let p ← instantiateMVars p
    let ok ← if !st.opens.isEmpty || p.hasMVar then pure false else
      match Lean.Kernel.check (← getEnv) (← getLCtx) p with
      | .ok t => kdefeq t ty
      | .error _ => pure false
    let (p, st) ← if ok then pure (p, st) else do
      (s.restore : MetaM Unit)
      (withFacts (prove true ty)).run { name := "mojo_inv" }
    g.assign p
    for m in st.dbgs do logInfo m
    return st.opens

end Inv

/-- **`mojo_inv`** proves a loop's invariant at a valuation `V` after a path or rounds of a loop:
a conjunction, or a structure of propositions field by field, of register equations
`V.regs r = some v`, the function `V.fn = F`, the `fmul contract` operands `V.prods r = p` and
memory facts at `V.mem` (`Mem.Buffer`, `Mem.Fits`, `Mem.Holds`, `Elem`, `Elem.Only`), from the
hypotheses found by type as mojo_obl finds them (the registers `f.regs r = some v` of an entry
frame or `W.regs r = some v`, the function `f.fn = F` or `W.fn = F`, the program, the launch,
struct loads, buffers), each hypothesis with its parts (`Obl.withFacts`: its conjuncts and the
fields of a structure of propositions).

After `i` rounds `f^[i] W` of a round `f` (`Valuation.roundWith c h S B`, `Valuation.round h S B`
or a constant that unfolds to one) for a count `i` that is no literal, a register that no `phi`
of the function and no block of the round sets is its value at `W`
(`Valuation.iterate_regs_keep`). Otherwise `V` is read by its blocks and edges (rounds, a path's
last block `(Valuation.lastWith c W l S ps).1`, iterates with a literal count, constants
unfolded): the register is the block's operand for it, evaluated as mojo_obl evaluates nodes, or
its value before the block; after an edge into blocks with `phi`s, a `phi`'s operand for the edge
(`Valuation.intoWith_regs_phi`), and otherwise the value before the edge
(`Valuation.intoWith_regs_br`, `Valuation.intoWith_regs_cond`, `Valuation.intoWith_regs_phi_ne`,
with no operand evaluated). The value
found is then proved equal to `v` (`Vals.conv`). The function and the operands are mojo_obl's
(`Obl.fnOf`, `Obl.prodOf`). A memory fact is its hypothesis at the memory before `V`'s blocks:
a buffer fact moved to `V.mem`, which has the same blocks, and `Elem` and `Elem.Only` through the
blocks' accesses, each to a block other than the output block (the inequality by `omega`, each
read for `Elem`); on a memory a store gives (`SEff.apply` or a block's run of one effect, among
the hypotheses), `Elem` after one more thread (`Elem.apply_store`) and `Elem.Only`
(`Elem.Only.apply`), the value's encoding by a hypothesis on the program. The kernel checks the
whole proof once, and each goal's proof on its own when that check fails. Each goal it does not
prove, and each goal of another form, is left as a goal and logged as `mojo_inv: open goal`. -/
syntax (name := mojoInv) "mojo_inv" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_inv` on the main goal. -/
@[tactic mojoInv] def evalMojoInv : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Inv.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
