import Lean
import MojoProof.Sym.OblLemmas
import MojoProof.Sym.Loop

/-!
# The tactic mojo_obl

A block summary (`Summary`, MojoProof/Sym/Checker.lean) carries obligations (`Cond`) on the values
of its node table, and a path of summaries is walked (`Walk`) when each block's obligations hold and
each exit goes to the next block. MojoProof/Sym/OblLemmas.lean reduces these, node kind by node
kind, to the semantics' operations; this module's tactic chains those lemmas over concrete
summaries.

mojo_obl (syntax `mojoObl`, elaborator `evalMojoObl`, method `Obl.run`) closes goals that are
conjunctions and implications of `Walk V ps`, `∀ d ∈ ds, d.Holds V (vals V S.nodes)`,
`d.Holds V (vals V S.nodes)` and `S.exit.target V (vals V S.nodes) = some l`, of their forms for
paths into blocks with `phi`s (`WalkI V ps`, `S.exit.dest V (vals V S.nodes) = some l`, a loop's
`Edge h p V l ds S E` and `Round h p ds S B V` of MojoProof/Sym/Loop.lean), and of statements
`∀ i < K, P i` for a literal `K` (one `P i` per `i`). `V` is a valuation under `after`s and
`into`s (an entry valuation `Valuation.entry c k m f`, or any other); a loop's rounds
`Valuation.round h S B W`, an iterate `f^[k] W` with a literal `k` and another constant are first
rewritten to them. The summaries are concrete (as `sym_summary` and `mojo_kernel` define them).
It builds each proof term from the lemmas of MojoProof/Sym/OblLemmas.lean, every argument given,
reads the concrete summaries, statements and paths by kernel `whnf`, and proves:

1. a node's value from the hypotheses, by type: the registers (`f.regs r = some v` of an entry
   frame, `V.regs r = some v` of another valuation), the function and program (`f.fn = F` or
   `V.fn = F`, `c.prog = P` or `V.ctx.prog = P`), struct loads (`m.load … = .ok v`), and
   for the launch (`L.Valid`, `c.env = L.env k`, and the 1-D hypotheses of
   `Launch.index_oneDim`) the register ranges of `Launch.sreg_lt`, `Launch.index_lt` and
   `Launch.sreg_bound` and the index equation;
2. a pointer into a buffer and its loads and stores from `m.Buffer`, a no-wrap fact (`Mem.Fits`
   of MojoProof/Sem/Precond.lean, or any hypothesis that unfolds to the existential), `m.Holds`
   and the alignment `A ∣ al`;
3. arithmetic premises by `omega`, from the local context and the launch facts, after
   evaluating their closed `Nat` subterms; `rfl` premises by kernel defeq; closed decidable
   propositions by `decide`, and so an obligation on a closed valuation that the lemmas do not
   reach (a store to a block no `m.Buffer` describes);
4. an edge into a block with `phi`s: where it goes from its condition, each `phi`'s value from
   its operand for the edge (`Valuation.into_regs_phi`, `enter`'s lemma), and the position it
   enters at (`Exit.pc`, from the function).

Each obligation and exit it proves is checked by the kernel against its statement. One it does not
prove stays a goal and is logged ("mojo_obl: open goal"); with `set_option mojo_obl.debug true` it
logs why. A goal of another form stays open whole. The node kinds it evaluates and the exits it
proves are listed in the docstring of the syntax `mojoObl`. Tests: MojoProofTest/Obl.lean
(`vector_addition`'s two paths, every thread of every valid one-dimensional launch; the counting
loop's edges, rounds and path out).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-! ## The tactic

mojo_obl builds every proof term itself, from the lemmas of OblLemmas.lean with all their
arguments known, and lets the kernel do the reductions: it reads the summaries, statements and
paths by kernel `whnf`, checks the `rfl` premises by kernel defeq, and proves the arithmetic
premises by `omega` after evaluating their closed `Nat` subterms. The elaborator never unfolds a
program, so no premise costs more than its own size, except a closed obligation that the lemmas
do not reach, which the kernel decides by evaluating it. Each obligation and exit it proves is
checked by the kernel against its statement; one it does not prove is left as a goal and
logged. -/

namespace Obl

open Lean Meta Elab Tactic

/-- When true, `mojo_obl` logs why it leaves each goal open (default false). -/
register_option mojo_obl.debug : Bool := {
  defValue := false
  descr := "log why mojo_obl leaves a goal open"
}


/-- What `mojo_obl` knows of a goal's valuations, cached. -/
structure St where
  /-- A cache with the given launch facts, node values, register values, memories and open goals. -/
  mk ::
  /-- Launch facts for `omega`: register ranges and the 1-D index. -/
  facts : List Expr := []
  /-- The node values of a valuation and summary: each
  `(v, (vals V S.nodes)[j]? = some (.ok v))`. -/
  nodes : Std.HashMap (Expr × Expr) (Array (Option (Expr × Expr))) := {}
  /-- The register values of a valuation: `(v, V.regs r = some v)`. -/
  regs : Std.HashMap (Expr × Nat) (Expr × Expr) := {}
  /-- The memory of a valuation: `(M, V.mem = M, M.blocks = m.blocks)`, `m` the entry memory. -/
  mems : Std.HashMap Expr (Expr × Expr × Expr) := {}
  /-- The goals left open. -/
  opens : Array MVarId := #[]
  /-- The debugging messages (kept across backtracking, logged at the end). -/
  dbgs : Array MessageData := #[]
  /-- The tactic's name, in the log of an open goal. -/
  name : String := "mojo_obl"
  /-- Whether a goal that is not proved fails instead of being left open. -/
  strict : Bool := false
  /-- The branch conditions that `omega` decided neither way (kept across backtracking). -/
  undec : Array Expr := #[]

/-- The tactic's monad. -/
abbrev M := StateRefT St MetaM

/-- How `Obl.use` gets one explicit argument of a lemma. -/
inductive Arg where
  /-- This term, whose type is unified with the argument's (assigning the lemma's implicits). -/
  | pf (e : Expr)
  /-- This proof, whose type the kernel checks equal to the argument's, once instantiated. -/
  | kd (e : Expr)
  /-- `Eq.refl`, the kernel checking the two sides equal; a right side with unassigned implicits
  is first unified with the left side's kernel normal form. -/
  | rfl
  /-- `of_decide_eq_true rfl`, the kernel evaluating the instance. -/
  | dec
  /-- `omega` on the argument with its closed `Nat` subterms evaluated, from the local context
  and the launch facts. -/
  | arith
  /-- The first local hypothesis whose type unifies with the argument's. -/
  | hyp
  /-- The proof this function makes of the argument's instantiated type. -/
  | fn (k : Expr → M Expr)

/-- Keep `m` for the log when `mojo_obl.debug` is set. -/
def dbg (m : MessageData) : M Unit := do
  if mojo_obl.debug.get (← getOptions) then
    let m ← addMessageContext m
    modify fun s => { s with dbgs := s.dbgs.push m }

/-- Proof `e` with its type shown as `t` (the kernel checks the two equal). -/
def hint (e t : Expr) : Expr := mkApp2 (mkConst ``id [Level.zero]) t e

/-- Kernel `whnf`. -/
def kwhnf (e : Expr) : MetaM Expr := do
  match Kernel.whnf (← getEnv) (← getLCtx) (← instantiateMVars e) with
  | .ok r => return r
  | .error _ => throwError "mojo_obl: the kernel does not reduce{indentExpr e}"

/-- Kernel definitional equality (false on a term with metavariables). -/
def kdefeq (a b : Expr) : MetaM Bool := do
  let a ← instantiateMVars a
  let b ← instantiateMVars b
  if a.hasMVar || b.hasMVar then return false
  match Kernel.isDefEq (← getEnv) (← getLCtx) a b with
  | .ok r => return r
  | .error _ => return false

/-- Kernel `whnf`, then the same on the arguments of the constructor it gives, to depth `d`. -/
partial def kdeep (e : Expr) (d : Nat) : MetaM Expr := do
  let e ← kwhnf e
  if d == 0 then return e
  match e.getAppFn with
  | .const n _ =>
    if let some (.ctorInfo ci) := (← getEnv).find? n then
      let args := e.getAppArgs
      let mut out := args
      for i in [ci.numParams:args.size] do
        out := out.set! i (← kdeep args[i]! (d - 1))
      return mkAppN e.getAppFn out
    return e
  | _ => return e

/-- The number `e` reduces to. -/
def natOf (e : Expr) : MetaM Nat := do
  match (← kwhnf e) with
  | .lit (.natVal n) => return n
  | r => throwError "mojo_obl: not a number{indentExpr r}"

/-- The elements of the list `e` reduces to. -/
partial def klist (e : Expr) : MetaM (List Expr) := do
  let e ← kwhnf e
  match e.getAppFnArgs with
  | (``List.cons, #[_, h, t]) => return h :: (← klist t)
  | (``List.nil, _) => return []
  | _ => throwError "mojo_obl: not a list{indentExpr e}"

/-- Head and tail of the list `e` reduces to, if it is a `cons`. -/
def kcons (e : Expr) : MetaM (Option (Expr × Expr)) := do
  let e ← kwhnf e
  match e.getAppFnArgs with
  | (``List.cons, #[_, h, t]) => return some (h, t)
  | (``List.nil, _) => return none
  | _ => throwError "mojo_obl: not a list{indentExpr e}"

/-- The components of the pair `e` reduces to. -/
def kpair (e : Expr) : MetaM (Expr × Expr) := do
  let e ← kwhnf e
  match e.getAppFnArgs with
  | (``Prod.mk, #[_, _, a, b]) => return (a, b)
  | _ => throwError "mojo_obl: not a pair{indentExpr e}"

/-- `e` with every closed `Nat` subterm the kernel reduces to a literal replaced by it. -/
def litify (e : Expr) : MetaM Expr := do
  let env ← getEnv
  let lctx ← getLCtx
  let nat := mkConst ``Nat
  Meta.transform e (pre := fun t => do
    if let .lit (.natVal n) := t then return .done (mkNatLit n)
    if t.hasLooseBVars || t.hasFVar || t.hasMVar then return .continue
    if t.isAppOfArity ``OfNat.ofNat 3 then return .done t
    let ty ← try inferType t catch _ => return .continue
    if ty != nat then return .continue
    match Kernel.whnf env lctx t with
    | .ok (.lit (.natVal n)) => return .done (mkNatLit n)
    | _ => return .continue)

/-- A proof of `a = b` by `Eq.refl a`, the kernel checking it. -/
def krfl (a b : Expr) : MetaM Expr := do
  unless ← kdefeq a b do
    throwError "mojo_obl: the kernel does not show{indentExpr a}\nequal to{indentExpr b}"
  let eq ← mkEq a b
  return hint (← mkEqRefl a) eq

/-- An `omega` proof of `t`, from the local context and the launch facts. -/
def arith (t : Expr) : M Expr := do
  let t' ← litify (← instantiateMVars t)
  let g ← mkFreshExprMVar t'
  let facts := (← get).facts
  let some g' ← g.mvarId!.falseOrByContra | return hint (← instantiateMVars g) t
  g'.withContext do
    let hyps ← getLocalHyps
    Lean.Elab.Tactic.Omega.omega (hyps.toList ++ facts) g'
  return hint (← instantiateMVars g) t

/-- A quick test that `a` and `b` do not unify, to skip a hypothesis before unifying: different
literals, applications of two different constructors, or applications of one constant to
arguments two of which pass this test. A heuristic: it can skip a hypothesis that unifies only by
unfolding, and never accepts one. -/
partial def rigidNe (a b : Expr) : MetaM Bool := do
  match a, b with
  | .lit x, .lit y => return x != y
  | _, _ =>
    let (some na, some nb) := (a.getAppFn.constName?, b.getAppFn.constName?) | return false
    let isCtor (n : Name) : MetaM Bool := do
      return (← getEnv).find? n matches some (.ctorInfo _)
    if na != nb then return (← isCtor na) && (← isCtor nb)
    let (xs, ys) := (a.getAppArgs, b.getAppArgs)
    if xs.size != ys.size then return false
    (xs.zip ys).anyM fun (x, y) => rigidNe x y

/-- The first local hypothesis whose type unifies with `t`; for an existential `t`, also one whose
type unfolds to an existential by one step of its head (as `Mem.Fits` does). -/
def findHyp (t : Expr) : MetaM Expr := do
  let t ← instantiateMVars t
  let some hd := t.getAppFn.constName? | throwError "mojo_obl: no hypothesis{indentExpr t}"
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let dt ← instantiateMVars d.type
    let some hd' := dt.getAppFn.constName? | continue
    let dt? : Option Expr ← if hd == hd' then pure (some dt)
      else if hd == ``Exists then do
        let u ← unfoldDefinition? dt
        pure (u.filter (·.isAppOf ``Exists))
      else pure none
    let some dt := dt? | continue
    if t.getAppNumArgs == dt.getAppNumArgs then
      if ← (t.getAppArgs.zip dt.getAppArgs).anyM fun (x, y) => rigidNe x y then continue
    let s ← saveState
    if ← isDefEq t dt then
      if hd == hd' then return d.toExpr
      return hint d.toExpr (← instantiateMVars t)
    s.restore
  throwError "mojo_obl: no hypothesis{indentExpr t}"

/-- The names of the binders of `t`, outermost first. -/
partial def binderNames : Expr → Array Name
  | .forallE n _ b _ => #[n] ++ binderNames b
  | _ => #[]

/-- **Lemma `c` applied**, its arguments named in `named` and its explicit ones from `args`, in
order: the proof and its type. The term arguments go first, then `rfl`, then the hypotheses,
then the rest. -/
def use (c : Name) (named : List (Name × Expr)) (args : List Arg) : M (Expr × Expr) := do
  let ci ← getConstInfo c
  let us ← ci.levelParams.mapM fun _ => mkFreshLevelMVar
  let ty := ci.type.instantiateLevelParams ci.levelParams us
  let (mvs, bis, concl) ← forallMetaTelescope ty
  let names := binderNames ty
  for (n, v) in named do
    match names.findIdx? (· == n) with
    | some i => mvs[i]!.mvarId!.assign v
    | none => throwError "mojo_obl: {c} has no argument {n}"
  let expl := (List.range mvs.size).filter fun i => bis[i]! == .default
  unless expl.length == args.length do
    throwError "mojo_obl: {c} takes {expl.length} explicit arguments, not {args.length}"
  let pairs := expl.zip args
  for (i, a) in pairs do
    if let .pf e := a then
      unless ← isDefEq (← inferType mvs[i]!) (← inferType e) do
        throwError
          "mojo_obl: argument {names[i]!} of {c}: type mismatch{indentExpr (← inferType e)}"
      unless ← isDefEq mvs[i]! e do
        throwError "mojo_obl: argument {names[i]!} of {c} is assigned"
  -- `rfl` when its left side is known: before the hypotheses, after them, and at the end
  let rflPass (last : Bool) : MetaM Unit := do
    for (i, a) in pairs do
      if let .rfl := a then
        if ← mvs[i]!.mvarId!.isAssigned then continue
        let t ← instantiateMVars (← inferType mvs[i]!)
        let some (_, lhs, rhs) := t.eq? | throwError "mojo_obl: {names[i]!} of {c} is no equation"
        if lhs.hasExprMVar && !last then continue
        if rhs.hasExprMVar then
          unless ← isDefEq rhs (← kdeep lhs 8) do
            throwError
              "mojo_obl: argument {names[i]!} of {c} does not reduce to its form{indentExpr t}"
        let t ← instantiateMVars t
        let some (_, lhs, rhs) := t.eq? | unreachable!
        mvs[i]!.mvarId!.assign (hint (← krfl lhs rhs) t)
  rflPass false
  for (i, a) in pairs do
    if let .hyp := a then
      mvs[i]!.mvarId!.assign (← findHyp (← inferType mvs[i]!))
  rflPass false
  for (i, a) in pairs do
    let t ← instantiateMVars (← inferType mvs[i]!)
    match a with
    | .kd e =>
      unless ← kdefeq (← inferType e) t do
        throwError
          "mojo_obl: argument {names[i]!} of {c}{indentExpr (← inferType e)}\nis not{indentExpr t}"
      mvs[i]!.mvarId!.assign (hint e t)
    | .dec =>
      if t.hasExprMVar then throwError "mojo_obl: argument {names[i]!} of {c} is not determined"
      let inst ← synthInstance (mkApp (mkConst ``Decidable) t)
      let dt := mkApp2 (mkConst ``Decidable.decide) t inst
      unless ← kdefeq dt (mkConst ``Bool.true) do
        throwError "mojo_obl: argument {names[i]!} of {c} is false{indentExpr t}"
      mvs[i]!.mvarId!.assign (mkApp3 (mkConst ``of_decide_eq_true) t inst
        (mkApp2 (mkConst ``Eq.refl [Level.one]) (mkConst ``Bool) (mkConst ``Bool.true)))
    | .arith =>
      if t.hasExprMVar then throwError "mojo_obl: argument {names[i]!} of {c} is not determined"
      mvs[i]!.mvarId!.assign (← arith t)
    | .fn k =>
      let p ← k t
      unless ← isDefEq t (← inferType p) do
        throwError
          "mojo_obl: argument {names[i]!} of {c}{indentExpr (← inferType p)}\nis not{indentExpr t}"
      mvs[i]!.mvarId!.assign p
    | _ => pure ()
  rflPass true
  for i in [0:mvs.size] do
    unless ← mvs[i]!.mvarId!.isAssigned do
      throwError "mojo_obl: argument {names[i]!} of {c} is not determined"
  let e ← instantiateMVars (mkAppN (mkConst c us) mvs)
  return (e, ← instantiateMVars concl)

/-- `.ok v`, a node's value. -/
def mkOk (v : Expr) : Expr :=
  mkApp3 (mkConst ``Except.ok [Level.zero, Level.zero]) (mkConst ``Fault) (mkConst ``Val) v

/-- The right side of the equation `t`. -/
def rhsOf (t : Expr) : MetaM Expr := do
  let some (_, _, r) := (← instantiateMVars t).eq?
    | throwError "mojo_obl: no equation{indentExpr t}"
  return r

/-- The value `v` of a proof of `_ = .ok v` or `_ = some v` or `_ = some (.ok v)`. -/
def valOf (t : Expr) : MetaM Expr := do
  let r ← rhsOf t
  match r.getAppFnArgs with
  | (``Except.ok, #[_, _, v]) => return v
  | (``Option.some, #[_, v]) =>
    match v.getAppFnArgs with
    | (``Except.ok, #[_, _, v]) => return v
    | _ => return v
  | _ => throwError "mojo_obl: not a value{indentExpr r}"

/-- The width and number of a value `.bits w (BitVec.ofNat w K)`. -/
def wordOf (v : Expr) : MetaM (Expr × Expr) := do
  match v.getAppFnArgs with
  | (``Val.bits, #[w, b]) =>
    match b.getAppFnArgs with
    | (``BitVec.ofNat, #[_, k]) => return (w, k)
    | _ => throwError "mojo_obl: not a word of a number{indentExpr v}"
  | _ => throwError "mojo_obl: not a word{indentExpr v}"

/-- The pointer of a value `.ptr q`. -/
def ptrOf (v : Expr) : MetaM Expr := do
  match v.getAppFnArgs with
  | (``Val.ptr, #[q]) => return q
  | _ =>
    match (← kdeep v 1).getAppFnArgs with
    | (``Val.ptr, #[q]) => return q
    | _ => throwError "mojo_obl: not a pointer{indentExpr v}"

/-- The block of pointer `q`, and the `K` of an offset `↑(K * s)`. -/
def ptrParts (q : Expr) : MetaM (Expr × Option Expr) := do
  let (c, off) ← match q.getAppFnArgs with
    | (``MojoProof.Sem.Ptr.mk, #[c, off]) => pure (c, off)
    | _ => match (← kdeep q 1).getAppFnArgs with
      | (``MojoProof.Sem.Ptr.mk, #[c, off]) => pure (c, off)
      | _ => throwError "mojo_obl: not a pointer{indentExpr q}"
  let c ← if c.isFVar then pure c else kwhnf c
  match off.getAppFnArgs with
  | (``Nat.cast, #[_, _, p]) =>
    match p.getAppFnArgs with
    | (``HMul.hMul, #[_, _, _, _, k, _]) => return (c, some k)
    | _ => return (c, none)
  | _ => return (c, none)

/-- `vals V S.nodes`, and `vals V (S.nodes.take j)`. -/
def vsOf (V S : Expr) (j : Option Nat := none) : Expr :=
  let ns := mkApp (mkConst ``Summary.nodes) S
  match j with
  | none => mkApp2 (mkConst ``vals) V ns
  | some j => mkApp2 (mkConst ``vals) V (mkApp3 (mkConst ``List.take [Level.zero])
      (mkConst ``SNode) (mkNatLit j) ns)

/-- The valuation under `after`s and `into`s. -/
partial def rootOf (V : Expr) : Expr :=
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', _]) => rootOf V'
  | (``Valuation.into, #[V', _, _]) => rootOf V'
  | _ => V

/-- The context, memory and frame of the valuation under `after`s and `into`s: those of an entry
valuation `Valuation.entry c k m f`, else its context and memory and no frame. -/
def baseOf (V : Expr) : Expr × Expr × Option Expr :=
  let R := rootOf V
  match R.getAppFnArgs with
  | (``Valuation.entry, #[c, _, m, f]) => (c, m, some f)
  | _ => (mkApp (mkConst ``Valuation.ctx) R, mkApp (mkConst ``Valuation.mem) R, none)

/-- A hypothesis `lhs = rhs` with `lhs` the kernel's equal of `a`, or `a = a`. -/
def eqHyp (a : Expr) : MetaM (Expr × Expr) := do
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    if let some (_, l, r) := (← instantiateMVars d.type).eq? then
      if l.getAppFn == a.getAppFn && (← kdefeq l a) then return (r, d.toExpr)
  return (a, ← mkEqRefl a)

/-- `V.fn = R.fn` (`k = 1`) or `V.ctx = R.ctx` (`k = 0`), `R` the valuation under `after`s
and `into`s, through each `into` by `Valuation.into_k` (and each `after` by definition); `none`
when there is no `into` (the kernel then reduces the field itself). -/
partial def intoField (k : Nat) (V : Expr) : MetaM (Option Expr) := do
  let fld := if k == 0 then ``Valuation.ctx else ``Valuation.fn
  let R := rootOf V
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', _]) =>
    let some h ← intoField k V' | return none
    return some (hint h (← mkEq (mkApp (mkConst fld) V) (mkApp (mkConst fld) R)))
  | (``Valuation.into, #[V', l, S]) =>
    let hk := mkApp3 (mkConst ``Valuation.into_k) V' l S
    let h := if k == 0 then mkProj ``And 0 hk else mkProj ``And 0 (mkProj ``And 1 hk)
    let h := hint h (← mkEq (mkApp (mkConst fld) V) (mkApp (mkConst fld) V'))
    match ← intoField k V' with
    | some h' => return some (← mkEqTrans h h')
    | none => return some (← mkEqTrans h (← mkEqRefl (mkApp (mkConst fld) V')))
  | _ => return none

/-- `V.fn = F`: the entry frame's function or the valuation's, from a hypothesis on it. -/
def fnOf (V : Expr) : MetaM (Expr × Expr) := do
  let (F, hF) ← match baseOf V with
    | (_, _, some f) => eqHyp (mkApp (mkConst ``Frame.fn) f)
    | _ => eqHyp (mkApp (mkConst ``Valuation.fn) (rootOf V))
  let some h ← intoField 1 V | return (F, hF)
  let R := rootOf V
  return (F, ← mkEqTrans h (hint hF (← mkEq (mkApp (mkConst ``Valuation.fn) R) F)))

/-- A field `fld` of the context, `V.ctx.fld = X`, from `c.fld = X` of the context `c` under
`after`s and `into`s. -/
def ctxOf (fld : Name) (V : Expr) : MetaM (Expr × Expr) := do
  let (c, _, _) := baseOf V
  let (X, hX) ← eqHyp (mkApp (mkConst fld) c)
  let some h ← intoField 0 V | return (X, hX)
  let R := rootOf V
  let h1 ← mkCongrArg (mkConst fld) h
  return (X, ← mkEqTrans h1
    (hint hX (← mkEq (mkApp (mkConst fld) (mkApp (mkConst ``Valuation.ctx) R)) X)))

/-- `V.ctx.prog = P`. -/
def progOf (V : Expr) : MetaM (Expr × Expr) := ctxOf ``Ctx.prog V

/-- `V.ctx.env = E`. -/
def envOf (V : Expr) : MetaM (Expr × Expr) := ctxOf ``Ctx.env V

/-- `V.ctx.who`. -/
def whoOf (V : Expr) : Expr := mkApp (mkConst ``Ctx.who) (mkApp (mkConst ``Valuation.ctx) V)

/-- The `Launch.sreg_bound` of a goal `r.lo ≤ (L.env k).sreg r d ∧ (L.env k).sreg r d < r.hi d`. -/
def sregBound (t : Expr) : MetaM Expr := do
  let fail : MetaM Expr := throwError "mojo_obl: no launch range for{indentExpr t}"
  let (``And, #[a, _]) := t.getAppFnArgs | fail
  let (``LE.le, #[_, _, _, s]) := a.getAppFnArgs | fail
  let (``Env.sreg, #[E, r, d]) := s.getAppFnArgs | fail
  let (``Launch.env, #[L, k]) := E.getAppFnArgs | fail
  let hL ← findHyp (mkApp (mkConst ``Launch.Valid) L)
  return mkApp5 (mkConst ``Launch.sreg_bound) L hL k r d

/-- **Launch facts for `omega`**, for every hypothesis `c.env = L.env k` and `L.Valid`: the
register bounds and the index bound in each dimension, and the 1-D index when the hypotheses of
`Launch.index_oneDim` are there. -/
def launchFacts : MetaM (List Expr) := do
  let mut out := []
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (_, _, r) := (← instantiateMVars d.type).eq? | continue
    let (``Launch.env, #[L, k]) := r.getAppFnArgs | continue
    let some hL ← try some <$> findHyp (mkApp (mkConst ``Launch.Valid) L) catch _ => pure none
      | continue
    for dim in [``Dim.x, ``Dim.y, ``Dim.z] do
      let h := mkApp4 (mkConst ``Launch.sreg_lt) L hL k (mkConst dim)
      out := mkProj ``And 0 h :: mkProj ``And 0 (mkProj ``And 1 h) ::
        mkProj ``And 1 (mkProj ``And 1 h) ::
        mkApp4 (mkConst ``Launch.index_lt) L hL k (mkConst dim) ::
        out
    try
      let t ← inferType (mkApp4 (mkConst ``Launch.index_oneDim) L (← mkFreshExprMVar none)
        (← mkFreshExprMVar none) k)
      let .forallE _ hn _ _ := t | pure ()
      let hn ← findHyp hn
      -- `L.grid .y = 1 ∧ L.grid .z = 1` and the same for `L.block`
      let one (f : Name) : MetaM Expr := do
        mkAppM ``And #[← mkEq (mkApp2 (mkConst f) L (mkConst ``Dim.y)) (mkNatLit 1),
          ← mkEq (mkApp2 (mkConst f) L (mkConst ``Dim.z)) (mkNatLit 1)]
      let hg ← findHyp (← one ``Launch.grid)
      let hb ← findHyp (← one ``Launch.block)
      out := mkApp5 (mkConst ``Launch.index_oneDim) L hg hb k hn :: out
    catch _ => pure ()
  out.mapM fun h => do return hint h (← litify (← inferType h))

mutual

/-- **The value of operand `x`** at valuation `V` on summary `S`'s nodes (the first `j` of them,
or all): `(v, x.eval V vs = .ok v)`. -/
partial def opnd (V S : Expr) (j : Option Nat) (x : Expr) : M (Expr × Expr) := do
  let x ← kdeep x 2
  let vs := vsOf V S j
  match x.getAppFnArgs with
  | (``SVal.node, #[i]) =>
    let i ← natOf i
    let ns ← nodeVals V S
    let some (_, h) := ns[i]?.join | throwError "mojo_obl: node {i} has no value"
    let (p, t) ← match j with
      | some j => use ``SVal.eval_node_take [(`j, mkNatLit j)] [.arith, .pf h]
      | none => use ``SVal.eval_node [(`V, V), (`vs, vs)] [.pf h]
    return (← valOf t, p)
  | (``SVal.reg, #[r]) =>
    let (_, h) ← regOf V (← natOf r)
    let (p, t) ← use ``SVal.eval_reg [(`vs, vs)] [.pf h]
    return (← valOf t, p)
  | (``SVal.int, #[w, i]) =>
    let (``Int.ofNat, #[k]) := i.getAppFnArgs
      | throwError "mojo_obl: negative constant{indentExpr x}"
    let (p, t) ← use ``SVal.eval_int_ofNat [(`V, V), (`vs, vs)] [.pf w, .pf k]
    return (← valOf t, p)
  | _ => throwError "mojo_obl: operand{indentExpr x}"

/-- **The value of register `r`** at valuation `V`: `(v, V.regs r = some v)`. -/
partial def regOf (V : Expr) (r : Nat) : M (Expr × Expr) := do
  if let some x := (← get).regs[(V, r)]? then return x
  let res ← match V.getAppFnArgs with
    | (``Valuation.after, #[V', S]) =>
      let lk ← kdeep (← mkAppM ``List.lookup #[mkNatLit r, mkApp (mkConst ``Summary.regs) S]) 2
      match lk.getAppFnArgs with
      | (``Option.some, #[_, x]) =>
        let (_, hx) ← opnd V' S none x
        let (p, t) ← use ``Valuation.after_regs_some [(`S, S), (`r, mkNatLit r), (`x, x)]
          [.rfl, .pf hx]
        pure (← valOf t, p)
      | _ =>
        let (_, h) ← regOf V' r
        let (p, t) ← use ``Valuation.after_regs_none [(`S, S), (`r, mkNatLit r)] [.rfl, .pf h]
        pure (← valOf t, p)
    | (``Valuation.into, #[V', l, S]) => intoReg V' l S r
    | _ =>
      -- the entry frame's register, or the valuation's
      let a := match baseOf V with
        | (_, _, some f) => mkApp2 (mkConst ``Frame.regs) f (mkNatLit r)
        | _ => mkApp2 (mkConst ``Valuation.regs) V (mkNatLit r)
      let t (v : Expr) : MetaM Expr := do
        mkEq (mkApp2 (mkConst ``Valuation.regs) V (mkNatLit r)) (← mkSome (mkConst ``Val) v)
      let (v, h) ← eqHyp a
      if h.isFVar then
        let (``Option.some, #[_, v]) := v.getAppFnArgs
          | throwError "mojo_obl: register {r} has no value"
        pure (v, hint h (← t v))
      else
        -- a closed register (of a concrete frame), by the kernel
        let a ← instantiateMVars a
        if a.hasFVar || a.hasMVar then throwError "mojo_obl: register {r} has no value"
        let (``Option.some, #[_, v]) := (← kwhnf a).getAppFnArgs
          | throwError "mojo_obl: register {r} has no value"
        pure (v, hint (← krfl a (← mkSome (mkConst ``Val) v)) (← t v))
  modify fun s => { s with regs := s.regs.insert (V, r) res }
  return res

/-- **The memory of valuation `V`**: `(M, V.mem = M, M.blocks = m.blocks)`, `m` the memory of
the valuation under `after`s and `into`s. -/
partial def memOf (V : Expr) : M (Expr × Expr × Expr) := do
  if let some x := (← get).mems[V]? then return x
  let (_, m0, _) := baseOf V
  let bl (M : Expr) := mkApp (mkConst ``Mem.blocks) M
  let res ← match V.getAppFnArgs with
    | (``Valuation.after, #[V', S]) =>
      let (M', hM', _) ← memOf V'
      let es ← klist (mkApp (mkConst ``Summary.effs) S)
      let (Mf, hf) ← foldExact V' S es M'
      let (p, _) ← use ``Valuation.after_mem_fold [(`V, V'), (`S, S), (`M, M'), (`M', Mf)]
        [.pf hM', .kd hf]
      pure (Mf, p, ← krfl (bl Mf) (bl m0))
    | (``Valuation.into, #[V', l, S]) =>
      let (M, hM, hb) ← memOf (mkApp2 (mkConst ``Valuation.after) V' S)
      pure (M, ← mkEqTrans (mkApp3 (mkConst ``Valuation.into_mem) V' l S) hM, hb)
    | _ => pure (m0, ← krfl (mkApp (mkConst ``Valuation.mem) V) m0, ← mkEqRefl (bl m0))
  modify fun s => { s with mems := s.mems.insert V res }
  return res

/-- `V.mem.blocks = m.blocks`. -/
partial def blocksOf (V : Expr) : M Expr := do
  let (_, hM, hMb) ← memOf V
  mkEqTrans (← mkCongrArg (mkConst ``Mem.blocks) hM) hMb

/-- **The node values** of summary `S` at valuation `V`. -/
partial def nodeVals (V S : Expr) : M (Array (Option (Expr × Expr))) := do
  if let some x := (← get).nodes[(V, S)]? then return x
  let ns ← klist (mkApp (mkConst ``Summary.nodes) S)
  -- a placeholder, so that a node reads only the nodes before it
  let mut acc : Array (Option (Expr × Expr)) := #[]
  for j in [0:ns.length] do
    modify fun s => { s with nodes := s.nodes.insert (V, S) acc }
    let nd ← kdeep ns[j]! 3
    let t0 ← IO.monoMsNow
    let r ← try
        let (v, he) ← nodeEval V S j nd
        let (p, _) ← use ``vals_getElem?_eval [(`V, V), (`ns, mkApp (mkConst ``Summary.nodes) S),
          (`j, mkNatLit j), (`nd, nd), (`r, mkOk v)] [.rfl, .kd he]
        dbg m!"mojo_obl: node {j} in {(← IO.monoMsNow) - t0} ms:{indentExpr v}"
        pure (some (v, p))
      catch e =>
        dbg m!"mojo_obl: node {j} ({(← IO.monoMsNow) - t0} ms): {e.toMessageData}"
        pure none
    acc := acc.push r
  modify fun s => { s with nodes := s.nodes.insert (V, S) acc }
  return acc

/-- **Node `nd`** (number `j` of `S`) at `V`: `(v, nd.eval V (vals V (S.nodes.take j)) = .ok v)`. -/
partial def nodeEval (V S : Expr) (j : Nat) (nd : Expr) : M (Expr × Expr) := do
  let vs := vsOf V S (some j)
  let op (x : Expr) := opnd V S (some j) x
  let (F, hF) ← fnOf V
  let (P, hP) ← progOf V
  let at_ := [(`V, V), (`vs, vs), (`F, F), (`P, P)]
  let fin (p : Expr × Expr) : M (Expr × Expr) := do return (← valOf p.2, p.1)
  match nd.getAppFnArgs with
  | (``SNode.load, #[lbl, pc, p]) =>
    let (qv, hp) ← op p
    let q ← ptrOf qv
    let named := at_ ++ [(`lbl, lbl), (`pc, pc)]
    match ← ptrParts q with
    | (c, some K) =>
      let hMb ← blocksOf V
      let st ← get
      let k (t : Expr) : MetaM Expr := do
        let (``Eq, #[_, ld, _]) := t.getAppFnArgs | throwError "mojo_obl: load"
        let al := ld.getAppArgs[6]!
        let (``Option.some, #[_, a]) := (← kdeep al 1).getAppFnArgs
          | throwError "mojo_obl: load alignment"
        let A ← natOf a
        let (pf, _) ← (use ``load_buffer [(`M, mkApp (mkConst ``Valuation.mem) V),
          (`who, whoOf V), (`c, c), (`K, K), (`A, mkNatLit A)]
          [.pf hMb, .hyp, .hyp, .hyp, .hyp, .arith, .arith, .arith]).run' st
        return pf
      fin (← use ``SNode.eval_load_at named [.kd hF, .kd hP, .rfl, .pf hp, .fn fun t => k t, .rfl])
    | _ => fin (← use ``SNode.eval_load_at named [.kd hF, .kd hP, .rfl, .pf hp, .hyp, .rfl])
  | (``SNode.extract, #[is, a]) =>
    let (av, ha) ← op a
    let r := mkApp2 (mkConst ``extractV) av is
    let r' ← kdeep r 4
    let (``Except.ok, #[_, _, v]) := r'.getAppFnArgs | throwError "mojo_obl: extractvalue fails"
    let (p, _) ← use ``SNode.eval_extract [(`is, is)] [.pf ha, .pf (← krfl r r')]
    return (v, p)
  | (``SNode.cast, #[cop, w, a]) =>
    let (av, ha) ← op a
    let (w', K) ← wordOf av
    let (p2, t2) ← match (← kwhnf cop).constName? with
      | some ``CastOp.sext => use ``intCast_sext_ofNat [(`w, w'), (`k, K)] [.pf w, .arith]
      | _ => use ``intCast_ofNat [(`op, cop), (`w, w'), (`k, K)] [.dec, .pf w, .arith]
    let (p1, _) ← use ``SNode.eval_cast [(`op, cop), (`w, w)] [.pf ha, .pf p2]
    return (← valOf t2, p1)
  | (``SNode.bin, #[bop, fl, w, a, b]) =>
    let (av, ha) ← op a
    let (bv, hb) ← op b
    let (_, Ka) ← wordOf av
    let (_, Kb) ← wordOf bv
    let (p2, t2) ← match (← kwhnf bop).constName? with
      | some ``BinOp.add => use ``intBin_add_ofNat [(`w, w), (`a, Ka), (`b, Kb)] [.pf fl, .arith]
      | some ``BinOp.mul =>
        use ``intBin_mul_ofNat [(`w, w), (`a, Ka), (`b, Kb)] [.pf fl, .arith, .arith, .arith]
      | _ => throwError "mojo_obl: integer operator{indentExpr bop}"
    let (p1, _) ← use ``SNode.eval_bin [(`op, bop), (`fl, fl)] [.pf ha, .pf hb, .pf p2]
    return (← valOf t2, p1)
  | (``SNode.icmp, #[pr, _, a, b]) =>
    let (_, ha) ← op a
    let (_, hb) ← op b
    match (← kwhnf pr).constName? with
    | some ``ICmp.slt => fin (← use ``SNode.eval_icmp_slt_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | some ``ICmp.ult => fin (← use ``SNode.eval_icmp_ult_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | _ => throwError "mojo_obl: comparison{indentExpr pr}"
  | (``SNode.call, #[lbl, pc]) =>
    let (E, hE) ← envOf V
    fin (← use ``SNode.eval_sreg_at (at_ ++ [(`lbl, lbl), (`pc, pc), (`E, E)])
      [.kd hF, .kd hP, .rfl, .rfl, .rfl, .rfl, .dec, .dec, .kd hE, .fn fun t => sregBound t])
  | (``SNode.gep, #[lbl, pc, base, idx]) =>
    let (iv, hi) ← op idx
    let (bv, hb) ← op base
    let (w, K) ← wordOf iv
    let (c, _) ← ptrParts (← ptrOf bv)
    let hMb ← blocksOf V
    let st ← get
    -- `gep_buffer` at the statement's flags and source type, once the statement is matched
    let k (t : Expr) : MetaM Expr := do
      let some (_, g, _) := t.eq? | throwError "mojo_obl: getelementptr"
      let ga := g.getAppArgs
      let (pf, _) ← (use ``gep_buffer [(`M, mkApp (mkConst ``Valuation.mem) V), (`fl, ga[2]!),
        (`src, ga[3]!), (`c, c), (`K, K), (`w, w)]
        [.pf hMb, .hyp, .hyp, .arith, .arith, .arith, .arith]).run' st
      return pf
    fin (← use ``SNode.eval_gep_at (at_ ++ [(`lbl, lbl), (`pc, pc)])
      [.kd hF, .kd hP, .rfl, .pf hi, .pf hb, .fn fun t => k t])
  | (``SNode.fbin, #[fop, fm, _, n, _, _]) =>
    let args := nd.getAppArgs
    let (_, ha) ← op args[4]!
    let (_, hb) ← op args[5]!
    fin (← use ``SNode.eval_fbin_ofFloat [(`op, fop), (`fm, fm), (`n, n)]
      [.pf ha, .pf hb, .rfl, .rfl, .rfl, .rfl, .rfl, .rfl])
  | _ => throwError "mojo_obl: node{indentExpr nd}"

/-- A `load` effect at `V` on summary `S`'s values, on memory `m`: its proof and the memory. -/
partial def effLoad (V S e m : Expr) : M (Expr × Expr) := do
  let (``SEff.load, #[lbl, pc, p]) := e.getAppFnArgs | throwError "mojo_obl: not a load"
  let (_, hp) ← opnd V S none p
  let (F, hF) ← fnOf V
  let (pf, t) ← use ``SEff.apply_load_at [(`V, V), (`vs, vsOf V S), (`m, m), (`F, F),
    (`lbl, lbl), (`pc, pc)] [.kd hF, .rfl, .pf hp]
  return (pf, ← valOf t)

/-- Effects `es` from memory `m`, all loads: the memory and the proof of the fold. -/
partial def foldExact (V S : Expr) : List Expr → Expr → M (Expr × Expr)
  | [], m => do
    let (p, _) ← use ``SEff.foldlM_nil_ok [(`V, V), (`vs, vsOf V S)] [.pf m]
    return (m, p)
  | e :: es, m => do
    let (h, m1) ← effLoad V S (← kdeep e 2) m
    let (mf, hr) ← foldExact V S es m1
    let (p, _) ← use ``SEff.foldlM_cons_ok [] [.pf h, .pf hr]
    return (mf, p)

/-- A `store` effect at `V` on memory `m`, whose blocks are the entry memory's: `∃ M', _`. -/
partial def effStore (V S e m : Expr) : M Expr := do
  let (``SEff.store, #[lbl, pc, v, p]) := e.getAppFnArgs | throwError "mojo_obl: not a store"
  let (x, hv) ← opnd V S none v
  let (qv, hp) ← opnd V S none p
  let (c, some K) ← ptrParts (← ptrOf qv) | throwError "mojo_obl: store not to a buffer"
  let (F, hF) ← fnOf V
  let (P, hP) ← progOf V
  let (_, m0, _) := baseOf V
  let hMb ← krfl (mkApp (mkConst ``Mem.blocks) m) (mkApp (mkConst ``Mem.blocks) m0)
  let st ← get
  let k (t : Expr) : MetaM Expr := do
    let (``Exists, #[_, lam]) := t.getAppFnArgs | throwError "mojo_obl: store"
    let .lam _ _ body _ := lam | throwError "mojo_obl: store"
    let (``Eq, #[_, sto, _]) := body.getAppFnArgs | throwError "mojo_obl: store"
    let sa := sto.getAppArgs
    let (``Option.some, #[_, a]) := (← kdeep sa[7]! 1).getAppFnArgs
      | throwError "mojo_obl: store alignment"
    let A ← natOf a
    let (pf, _) ← (use ``store_buffer [(`M, m), (`who, whoOf V), (`c, c), (`K, K), (`t, sa[4]!),
      (`v, x), (`A, mkNatLit A)] [.pf hMb, .hyp, .hyp, .hyp, .arith, .rfl, .arith, .arith]).run' st
    return pf
  let (pf, _) ← use ``SEff.apply_store_ex [(`V, V), (`vs, vsOf V S), (`m, m), (`P, P), (`F, F),
    (`lbl, lbl), (`pc, pc)] [.kd hF, .kd hP, .rfl, .pf hv, .pf hp, .fn fun t => k t]
  return pf

/-- Effects `es` from memory `m` (`none`: any memory, then only loads): `∃ M', fold = .ok M'`. -/
partial def foldEx (V S : Expr) : List Expr → Option Expr → M Expr
  | [], some m => do
    return (← use ``SEff.foldlM_nil_ex [(`V, V), (`vs, vsOf V S)] [.pf m]).1
  | es, none => throwError "mojo_obl: {es.length} effects on an unknown memory"
  | e :: es, some m => do
    let e ← kdeep e 2
    if e.isAppOf ``SEff.store then
      let h ← effStore V S e m
      let h' ← withLocalDeclD `m (mkConst ``Mem) fun m1 => do
        mkLambdaFVars #[m1] (← foldAny V S es m1)
      return (← use ``SEff.foldlM_cons_all [] [.pf h, .pf h']).1
    let (h, m1) ← effLoad V S e m
    let h' ← foldEx V S es (some m1)
    return (← use ``SEff.foldlM_cons_ex [] [.pf h, .pf h']).1

/-- Load effects `es` from an arbitrary memory `m`: `∃ M', fold = .ok M'`. -/
partial def foldAny (V S : Expr) : List Expr → Expr → M Expr
  | [], m => do return (← use ``SEff.foldlM_nil_ex [(`V, V), (`vs, vsOf V S)] [.pf m]).1
  | e :: es, m => do
    let (h, m1) ← effLoad V S (← kdeep e 2) m
    let h' ← foldAny V S es m1
    return (← use ``SEff.foldlM_cons_ex [] [.pf h, .pf h']).1

/-- `S.exit.target V (vals V S.nodes) = some l`. -/
partial def exitP (V S l : Expr) : M Expr := do
  let vs := vsOf V S
  let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
  match x.getAppFnArgs with
  | (``Exit.br, #[d]) => return (← use ``Exit.target_br [(`V, V), (`vs, vs), (`d, d)] []).1
  | (``Exit.cond, #[c, d, e]) =>
    let (v, h) ← opnd V S none c
    let (``Val.ofBool, #[b]) := v.getAppFnArgs | throwError "mojo_obl: branch on no boolean"
    let (``Decidable.decide, #[q, _]) := b.getAppFnArgs
      | throwError "mojo_obl: branch on no comparison"
    let l ← natOf l
    -- `omega` on the condition, which is kept when it fails
    let dec (t : Expr) : M Expr := do
      try arith t catch ex =>
        modify fun s => { s with undec := s.undec.push q }
        throw ex
    if l == (← natOf d) then
      let hb ← mkAppM ``decide_eq_true #[← dec q]
      return (← use ``Exit.target_cond_true [(`d, d), (`e, e)] [.pf h, .pf hb]).1
    if l == (← natOf e) then
      let hb ← mkAppM ``decide_eq_false #[← dec (mkNot q)]
      return (← use ``Exit.target_cond_false [(`d, d), (`e, e)] [.pf h, .pf hb]).1
    throwError "mojo_obl: the branch goes to neither target"
  | _ => throwError "mojo_obl: exit{indentExpr x}"

/-- **Where the exit of summary `S` goes** at `V`, to `l` if given:
`(d, S.exit.dest V (vals V S.nodes) = some d)`. A `br` or a conditional branch by `exitP`
(`Exit.dest_of_target`); a branch into blocks with `phi`s on a constant word by its low bit, on a
comparison by `omega` on its direction (`Exit.dest_phi_true` and the others). -/
partial def exitD (V S : Expr) (l : Option Expr) : M (Expr × Expr) := do
  let vs := vsOf V S
  let ty (d : Expr) : MetaM Expr := do
    mkEq (mkApp3 (mkConst ``Exit.dest) V vs (mkApp (mkConst ``Summary.exit) S))
      (← mkSome (mkConst ``Nat) d)
  let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
  let tgt (d : Expr) : M (Expr × Expr) := do
    let h ← exitP V S d
    let (p, _) ← use ``Exit.dest_of_target [] [.pf h]
    return (d, hint p (← ty d))
  match x.getAppFnArgs with
  | (``Exit.br, #[d]) => tgt d
  | (``Exit.cond, #[_, d, e]) =>
    match l with
    | some l => tgt l
    | none => try tgt d catch _ => tgt e
  | (``Exit.phi, #[c, d, e]) =>
    let (v, h) ← opnd V S none c
    let want (t : Expr) : MetaM Bool := do
      match l with
      | some l => return (← natOf l) == (← natOf t)
      | none => return true
    let named := [(`d, d), (`e, e)]
    if let (``Val.ofBool, #[b]) := v.getAppFnArgs then
      let (``Decidable.decide, #[q, _]) := b.getAppFnArgs
        | throwError "mojo_obl: branch on no comparison"
      if ← want d then
        try
          let hb ← mkAppM ``decide_eq_true #[← arith q]
          let (p, _) ← use ``Exit.dest_phi_ofBool_true named [.pf h, .pf hb]
          return (d, hint p (← ty d))
        catch ex => if l.isSome then throw ex
      unless ← want e do throwError "mojo_obl: the branch goes to neither target"
      let hb ← mkAppM ``decide_eq_false #[← arith (mkNot q)]
      let (p, _) ← use ``Exit.dest_phi_ofBool_false named [.pf h, .pf hb]
      return (e, hint p (← ty e))
    let (w, K) ← wordOf v
    let bit ← kwhnf (mkApp3 (mkConst ``BitVec.getLsbD) w
      (mkApp2 (mkConst ``BitVec.ofNat) w K) (mkNatLit 0))
    let (t, lem) := if bit.isConstOf ``Bool.true then (d, ``Exit.dest_phi_true)
      else (e, ``Exit.dest_phi_false)
    unless ← want t do throwError "mojo_obl: the branch goes to neither target"
    let (p, _) ← use lem named [.pf h, .dec]
    return (t, hint p (← ty t))
  | _ => throwError "mojo_obl: exit{indentExpr x}"

/-- **Register `r` after the edge of block `l`** (summary `S`) from `V`: `Valuation.after`'s for
a `br` or a conditional branch (`Valuation.into_regs_br`, `Valuation.into_regs_cond`); for a
branch into blocks with `phi`s, the value of the last `phi` that sets `r`, each operand's value
in the edge's scope from the registers after the block (`Valuation.into_regs_phi`,
`evalOps_cons`, `evalV_loc`, `evalV_int_ofNat`), else `Valuation.after`'s
(`setRegs_of_forall_ne`). -/
partial def intoReg (V l S : Expr) (r : Nat) : M (Expr × Expr) := do
  let A := mkApp2 (mkConst ``Valuation.after) V S
  let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
  let named := [(`V, V), (`l, l), (`S, S), (`r, mkNatLit r)]
  match x.getAppFnArgs with
  | (``Exit.br, _) =>
    let (_, h) ← regOf A r
    let (p, t) ← use ``Valuation.into_regs_br named [.rfl, .pf h]
    return (← valOf t, p)
  | (``Exit.cond, _) =>
    let (_, h) ← regOf A r
    let (p, t) ← use ``Valuation.into_regs_cond named [.rfl, .pf h]
    return (← valOf t, p)
  | (``Exit.phi, _) =>
    let (d, hd) ← exitD V S none
    let (F, hF) ← fnOf V
    let ops ← kdeep (mkApp3 (mkConst ``phiOps) F l d) 1
    let (``Option.some, #[_, ops]) := ops.getAppFnArgs
      | throwError "mojo_obl: no phi operands for the edge into {d}"
    let ops ← klist ops
    let s ← mkAppM ``Ctx.scope #[mkApp (mkConst ``Valuation.ctx) V,
      mkApp (mkConst ``Valuation.mem) A, mkApp3 (mkConst ``Valuation.frameAt) V l S,
      ← mkAppM ``HAdd.hAdd #[mkApp (mkConst ``Valuation.k) V, mkApp (mkConst ``Summary.len) S]]
    -- each operand's value in the edge's scope
    let mut items : Array (Expr × Expr × Expr) := #[]
    for op in ops do
      let (o, rest) ← kpair op
      let (t, v) ← kpair rest
      let v ← kdeep v 2
      match v.getAppFnArgs with
      | (``Value.loc, #[r']) =>
        let (xv, hx) ← regOf A (← natOf r')
        let (p, _) ← use ``evalV_loc [(`s, s), (`t, t), (`r, r'), (`x, xv)] [.kd hx]
        items := items.push (o, xv, p)
      | (``Value.int, #[i]) =>
        let (``Int.ofNat, #[k]) := i.getAppFnArgs | throwError "mojo_obl: negative phi operand"
        let (``Ty.int, #[w]) := (← kdeep t 1).getAppFnArgs | throwError "mojo_obl: phi type"
        let (p, ty) ← use ``evalV_int_ofNat [] [.pf s, .pf w, .pf k]
        items := items.push (o, ← valOf ty, p)
      | _ => throwError "mojo_obl: phi operand{indentExpr v}"
    let mut hxs := (← use ``evalOps_nil [] [.pf s]).1
    for (o, _, p) in items.reverse do
      hxs := (← use ``evalOps_cons [(`o, o)] [.pf p, .pf hxs]).1
    let (p, t) ← use ``Valuation.into_regs_phi [(`V, V), (`l, l), (`S, S), (`F, F), (`d, d)]
      [.rfl, .pf hd, .kd hF, .rfl, .pf hxs, .pf (mkNatLit r)]
    let rhs ← rhsOf t
    let mut last : Option Expr := none
    for (o, xv, _) in items do
      if let (``Option.some, #[_, o]) := (← kwhnf o).getAppFnArgs then
        if (← natOf o) == r then last := some xv
    let some_ (v : Expr) := mkSome (mkConst ``Val) v
    match last with
    | some xv =>
      return (xv, ← mkEqTrans p (← krfl rhs (← some_ xv)))
    | none =>
      -- no `phi` sets `r` (`setRegs_of_forall_ne`; the kernel would evaluate both sides)
      let (xv, h) ← regOf A r
      let (``setRegs, #[rs, xs, g, _]) := rhs.getAppFnArgs | throwError "mojo_obl: phi registers"
      let (q, _) ← use ``setRegs_of_forall_ne [(`rs, rs), (`xs, xs), (`g, g), (`r, mkNatLit r)]
        [.dec]
      return (xv, ← mkEqTrans p (← mkEqTrans q h))
  | _ => throwError "mojo_obl: exit{indentExpr x}"

end

/-- Effects `es` of summary `S` at `V` run: `∃ M', SEff.run V (vals V S.nodes) es = .ok M'`
(`foldEx` from `V`'s memory). -/
def runEx (V S : Expr) (es : List Expr) : M Expr := do
  let (M0, hM) ← if es.isEmpty then
      pure (mkApp (mkConst ``Valuation.mem) V, ← mkEqRefl (mkApp (mkConst ``Valuation.mem) V))
    else do let (M0, hM, _) ← memOf V; pure (M0, hM)
  let h ← foldEx V S es (some M0)
  return (← use ``SEff.run_of_fold_ex [(`vs, vsOf V S)] [.pf hM, .pf h]).1

/-- The goal `ty`, left open and logged (an error in strict mode). -/
def openGoal (ty : Expr) : M Expr := do
  let st ← get
  if st.strict then throwError "{st.name}: no proof of{indentExpr ty}"
  let g ← mkFreshExprSyntheticOpaqueMVar ty
  logInfo m!"{st.name}: open goal{indentExpr ty}"
  modify fun s => { s with opens := s.opens.push g.mvarId! }
  return g

/-- Proof `k` of `ty`, checked by the kernel, or the goal left open. -/
def attempt (ty : Expr) (k : M Expr) : M Expr := do
  let s ← (saveState : MetaM Meta.SavedState)
  let t0 ← IO.monoMsNow
  let r : Except MessageData Expr ← try
      let p ← instantiateMVars (← k)
      if p.hasMVar then
        if ← kdefeq (← inferType p) ty then pure (.ok p)
        else pure (.error m!"the proof's type is not the goal")
      else
        match Lean.Kernel.check (← getEnv) (← getLCtx) p with
        | .ok t =>
          if ← kdefeq t ty then pure (.ok p) else pure (.error m!"the proof's type is not the goal")
        | .error e =>
          pure (.error m!"the kernel rejects the proof: {e.toMessageData (← getOptions)}")
    catch e => pure (.error e.toMessageData)
  let t1 ← IO.monoMsNow
  match r with
  | .ok p =>
    dbg m!"mojo_obl: proved in {t1 - t0} ms{indentExpr ty}"
    return hint p ty
  | .error e =>
    (s.restore : MetaM Unit)
    dbg m!"mojo_obl: {e} ({t1 - t0} ms){indentExpr ty}"
    openGoal ty

/-- A proof of the closed decidable proposition `ty` by `decide`, the kernel evaluating it (an
obligation on a concrete valuation that the lemmas do not reach, such as a store to a block that
no `Mem.Buffer` hypothesis describes). -/
def closedDec (ty : Expr) : MetaM Expr := do
  let ty ← instantiateMVars ty
  if ty.hasFVar || ty.hasMVar then throwError "mojo_obl: not closed{indentExpr ty}"
  let inst ← synthInstance (mkApp (mkConst ``Decidable) ty)
  let dt := mkApp2 (mkConst ``Decidable.decide) ty inst
  unless ← kdefeq dt (mkConst ``Bool.true) do throwError "mojo_obl: false{indentExpr ty}"
  return mkApp3 (mkConst ``of_decide_eq_true) ty inst
    (mkApp2 (mkConst ``Eq.refl [Level.one]) (mkConst ``Bool) (mkConst ``Bool.true))

/-- Proof `k` of `ty`, else, when `ty` is closed, `closedDec`. -/
def orClosed (ty : Expr) (k : M Expr) : M Expr := do
  try k catch e =>
    dbg e.toMessageData
    try closedDec ty catch _ => throw e

/-- Obligation `d` of summary `S` at `V`. -/
def obl (V S d : Expr) : M Expr := do
  let d ← kdeep d 2
  match d.getAppFnArgs with
  | (``Cond.ok, #[x]) =>
    let (_, h) ← opnd V S none x
    return (← use ``Cond.holds_ok [] [.pf h]).1
  | (``Cond.bool, #[x]) =>
    let (v, h) ← opnd V S none x
    if v.isAppOf ``Val.ofBool then return (← use ``Cond.holds_ofBool [] [.pf h]).1
    return (← use ``Cond.holds_bool [] [.pf h]).1
  | (``Cond.mem, #[es]) =>
    let h ← runEx V S (← klist es)
    return (← use ``Cond.holds_mem [] [.pf h]).1
  | _ => throwError "mojo_obl: obligation{indentExpr d}"

/-- `∀ d ∈ ds, d.Holds V (vals V S.nodes)`, each obligation proved or left open. -/
def obls (V S ds : Expr) : M Expr := do
  let vs := vsOf V S
  let P ← withLocalDeclD `d (mkConst ``Cond) fun d => do
    mkLambdaFVars #[d] (mkApp3 (mkConst ``Cond.Holds) V vs d)
  let rec /-- The obligations `ds` as a list term, with the proof of `∀ d ∈ ds, P d`. -/
    go : List Expr → M (Expr × Expr)
    | [] => return (mkApp (mkConst ``List.nil [Level.zero]) (mkConst ``Cond),
        mkApp (mkConst ``forall_mem_nil') P)
    | d :: ds => do
      let d ← kdeep d 2
      let ty := mkApp3 (mkConst ``Cond.Holds) V vs d
      let h ← attempt ty (orClosed ty (obl V S d))
      let (l, t) ← go ds
      return (mkApp3 (mkConst ``List.cons [Level.zero]) (mkConst ``Cond) d l,
        mkApp5 (mkConst ``forall_mem_cons') P d l h t)
  let (_, p) ← go (← klist ds)
  return p

/-- The summary `S` of node values `vals V S.nodes`. -/
def summaryOf (vs : Expr) : MetaM Expr := do
  let (``vals, #[_, ns]) := vs.getAppFnArgs | throwError "mojo_obl: not the values of a summary"
  let (``Summary.nodes, #[S]) := ns.getAppFnArgs
    | throwError "mojo_obl: not the values of a summary"
  return S

/-- `Walk V ps`: each block's obligations and exit, proved or left open. -/
partial def walk (V ps : Expr) : M Expr := do
  match ← kcons ps with
  | none => return mkApp (mkConst ``Walk.nil') V
  | some (hd, tl) =>
    let (l, rest) ← kpair hd
    let (ds, S) ← kpair rest
    match ← kcons tl with
    | none =>
      let h ← obls V S ds
      return (← use ``Walk.one [(`V, V), (`l, l), (`ds, ds), (`S, S)] [.kd h]).1
    | some (hd', tl') =>
      let (l', rest') ← kpair hd'
      let (ds', S') ← kpair rest'
      let h1 ← obls V S ds
      let ty2 ← mkEq
        (mkApp3 (mkConst ``Exit.target) V (vsOf V S) (mkApp (mkConst ``Summary.exit) S))
        (← mkSome (mkConst ``Nat) l')
      let h2 ← attempt ty2 (exitP V S l')
      let V' := mkApp2 (mkConst ``Valuation.after) V S
      let h3 ← walk V' tl
      return (← use ``Walk.cons2 [(`V, V), (`l, l), (`l', l'), (`ds, ds), (`ds', ds'), (`S, S),
        (`S', S'), (`ps, tl')] [.kd h1, .kd h2, .kd h3]).1

/-- The literal `K` of a statement `∀ i : Nat, i < K → P i` (binder type `a`, body `b`) whose
`P` does not use the proof of `i < K`. -/
def belowLit (a b : Expr) : MetaM (Option Nat) := do
  unless a.isConstOf ``Nat do return none
  let .forallE _ lt body _ := b | return none
  if body.hasLooseBVar 0 then return none
  let (``LT.lt, #[_, _, i, K]) := lt.getAppFnArgs | return none
  unless i == .bvar 0 && !K.hasLooseBVars do return none
  try some <$> natOf K catch _ => return none

/-- `WalkI V ps`: each block's obligations and exit (`Exit.dest`), proved or left open, the
valuation of each block after the first `Valuation.into` of the one before. -/
partial def walkI (V ps : Expr) : M Expr := do
  match ← kcons ps with
  | none => return mkApp (mkConst ``WalkI.nil') V
  | some (hd, tl) =>
    let (l, rest) ← kpair hd
    let (ds, S) ← kpair rest
    match ← kcons tl with
    | none =>
      let h ← obls V S ds
      return (← use ``WalkI.one [(`V, V), (`l, l), (`ds, ds), (`S, S)] [.kd h]).1
    | some (hd', tl') =>
      let (l', rest') ← kpair hd'
      let (ds', S') ← kpair rest'
      let h1 ← obls V S ds
      let ty2 ← mkEq
        (mkApp3 (mkConst ``Exit.dest) V (vsOf V S) (mkApp (mkConst ``Summary.exit) S))
        (← mkSome (mkConst ``Nat) l')
      let h2 ← attempt ty2 (do return (← exitD V S (some l')).2)
      let V' := mkApp3 (mkConst ``Valuation.into) V l S
      let h3 ← walkI V' tl
      return (← use ``WalkI.cons2 [(`V, V), (`l, l), (`l', l'), (`ds, ds), (`ds', ds'), (`S, S),
        (`S', S'), (`ps, tl')] [.kd h1, .kd h2, .kd h3]).1

/-- The last block of the path `(l, _, S) :: E` with `phi`s from `V` (`Valuation.lastI`): its
entry valuation, built with `Valuation.into`, its label and its summary. -/
partial def lastIOf (V l S E : Expr) : MetaM (Expr × Expr × Expr) := do
  match ← kcons E with
  | none => return (V, l, S)
  | some (hd, tl) =>
    let (l', rest) ← kpair hd
    let (_, S') ← kpair rest
    lastIOf (mkApp3 (mkConst ``Valuation.into) V l S) l' S' tl

/-- Valuation `V` as `Valuation.after`s and `Valuation.into`s of an entry valuation or of another
valuation: a loop's round (`Valuation.round`) by the edges of its path, an iterate `f^[k] a` with
a literal `k` by `k` applications, and another constant by its definition. The kernel checks the
result equal to `V`. -/
partial def normV (V : Expr) : MetaM Expr := do
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', S]) => return mkApp2 (mkConst ``Valuation.after) (← normV V') S
  | (``Valuation.into, #[V', l, S]) => return mkApp3 (mkConst ``Valuation.into) (← normV V') l S
  | (``Valuation.entry, _) => return V
  | (``Valuation.round, #[h, S, B, W]) =>
    let (W', l', S') ← lastIOf (← normV W) h S B
    return mkApp3 (mkConst ``Valuation.into) W' l' S'
  | (``Nat.iterate, #[_, f, k, a]) =>
    let some n ← (try some <$> natOf k catch _ => pure none) | return V
    let mut a ← normV a
    for _ in [0:n] do
      a ← normV (mkApp f a).headBeta
    return a
  | _ =>
    unless V.getAppFn.isConst do return V
    match ← unfoldDefinition? V with
    | some V' => normV V'.headBeta
    | none => return V

/-- `Edge h p V l ds S E`: the path's premises (`walkI`), and the last block's exit goes to `h`
(`exitD`) at position `p` (`Exit.pc_of_fn`, the kernel computing `Exit.pc`). -/
partial def edge (ty h p V l ds S E : Expr) : M Expr := do
  let V ← normV V
  let ps ← mkAppM ``List.cons #[← mkAppM ``Prod.mk #[l, ← mkAppM ``Prod.mk #[ds, S]], E]
  let w ← try walkI V ps catch e => dbg e.toMessageData; openGoal (mkApp2 (mkConst ``WalkI) V ps)
  let (W, _, S') ← lastIOf V l S E
  let x := mkApp (mkConst ``Summary.exit) S'
  let tyD ← mkEq (mkApp3 (mkConst ``Exit.dest) W (vsOf W S') x) (← mkSome (mkConst ``Nat) h)
  let hD ← attempt tyD (do return (← exitD W S' (some h)).2)
  let fnV := mkApp (mkConst ``Valuation.fn) V
  let tyP ← mkEq (mkApp3 (mkConst ``Exit.pc) fnV h x) p
  let hP ← attempt tyP (do
    let (F, hF) ← fnOf V
    let hF := hint hF (← mkEq fnV F)
    return (← use ``Exit.pc_of_fn [(`x, x), (`fn, fnV), (`F, F), (`d, h), (`p, p)]
      [.pf hF, .rfl]).1)
  let pf ← mkAppM ``And.intro #[w, ← mkAppM ``And.intro #[hD, hP]]
  let pf ← instantiateMVars pf
  unless pf.hasMVar do
    unless ← kdefeq (← inferType pf) ty do throwError "mojo_obl: the path is not the edge"
  return hint pf ty

/-- A proof of `ty`: conjunctions, implications, statements for every number below a literal,
paths (with or without `phi`s), a loop's edges and rounds, obligations and exits. -/
partial def prove (ty : Expr) : M Expr := do
  let ty ← instantiateMVars ty
  match ty.getAppFnArgs with
  | (``And, #[a, b]) => return mkApp4 (mkConst ``And.intro) a b (← prove a) (← prove b)
  | (``Walk, #[V, ps]) =>
    try return hint (← walk V ps) ty
    catch e => dbg e.toMessageData; openGoal ty
  | (``WalkI, #[V, ps]) =>
    try return hint (← walkI (← normV V) ps) ty
    catch e => dbg e.toMessageData; openGoal ty
  | (``Edge, #[h, p, V, l, ds, S, E]) =>
    try edge ty h p V l ds S E
    catch e => dbg e.toMessageData; openGoal ty
  | (``Round, #[h, p, ds, S, B, V]) =>
    try edge ty h p V h ds S B
    catch e => dbg e.toMessageData; openGoal ty
  | (``Cond.Holds, #[V, vs, d]) => attempt ty (orClosed ty (do obl V (← summaryOf vs) d))
  | (``Eq, #[_, lhs, rhs]) =>
    match lhs.getAppFnArgs, rhs.getAppFnArgs with
    | (``Exit.target, #[V, vs, x]), (``Option.some, #[_, l]) =>
      attempt ty (do
        let S ← summaryOf vs
        unless ← kdefeq x (mkApp (mkConst ``Summary.exit) S) do throwError "mojo_obl: exit"
        exitP V S l)
    | (``Exit.dest, #[V, vs, x]), (``Option.some, #[_, l]) =>
      attempt ty (do
        let S ← summaryOf vs
        unless ← kdefeq x (mkApp (mkConst ``Summary.exit) S) do throwError "mojo_obl: exit"
        return (← exitD V S (some l)).2)
    | _, _ => openGoal ty
  | _ =>
    match ty with
    | .forallE n a b bi =>
      if b.hasLooseBVars then
        if let some K ← belowLit a b then
          -- `∀ i < K, P i` for a literal `K`: `P 0`, …, `P (K - 1)`
          let .forallE _ _ body _ := b | openGoal ty
          let P := Expr.lam n a (body.lowerLooseBVars 1 1) bi
          let mut pf := mkApp (mkConst ``forall_lt_zero') P
          for k in [0:K] do
            let hk ← prove ((body.lowerLooseBVars 1 1).instantiate1 (mkNatLit k))
            pf := mkApp4 (mkConst ``forall_lt_succ') P (mkNatLit k) pf hk
          return hint pf ty
        else if a.isAppOf ``Cond then
          -- `∀ d ∈ ds, d.Holds V vs`
          let .forallE _ mem body _ := b | openGoal ty
          let (``Membership.mem, #[_, _, _, ds, _]) := mem.getAppFnArgs | openGoal ty
          let (``Cond.Holds, #[V, vs, _]) := body.getAppFnArgs | openGoal ty
          try return hint (← obls V (← summaryOf vs) ds) ty
          catch e => dbg e.toMessageData; openGoal ty
        else openGoal ty
      else
        withLocalDecl n bi a fun h => do mkLambdaFVars #[h] (← prove b)
    | _ => openGoal ty

/-- **`mojo_obl` on goal `g`**: the goals it leaves open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let facts ← launchFacts
    let (p, st) ← (prove (← instantiateMVars (← g.getType))).run { facts }
    g.assign p
    for m in st.dbgs do logInfo m
    return st.opens

end Obl

/-- **`mojo_obl`** proves the premises of a path summary: a goal `Walk V ps` for a path `ps` of
summaries (`MojoProof.Sym.Kernel` asks one per thread), its blocks' obligations
`∀ d ∈ ds, d.Holds V vs`, one obligation `d.Holds V vs` and an exit `S.exit.target V vs = some l`;
for a path into blocks with `phi`s `WalkI V ps` and `S.exit.dest V vs = some l`, and a loop's
`Edge` and `Round`; statements `∀ i < K, P i` for a literal `K`; and conjunctions and implications
of them. `V` is a valuation under `after`s and `into`s: an entry valuation
`Valuation.entry c k m f`, or any other; rounds `Valuation.round`, iterates `f^[k]` with a literal
`k` and other constants are first rewritten to them.

It evaluates each node of each block from the hypotheses: the registers (`f.regs r = some v` of
an entry frame, else `V.regs r = some v`), the function and program (`f.fn = F` or `V.fn = F`,
`c.prog = P` or `V.ctx.prog = P`), the launch (`c.env = L.env k`, `L.Valid`, and for the 1-D index
`Launch.index_oneDim`'s hypotheses), struct loads (`m.load … = .ok v`), and the buffers the
pointers point into (`m.Buffer`, `Mem.Fits` or its unfolding, `m.Holds`, the alignment
`A ∣ al`). It evaluates the nodes of integer `add` and `mul`, the comparisons `slt` and `ult`,
casts, `extractvalue`, `getelementptr`, loads, special-register calls and float operators, on
words `BitVec.ofNat w K` whose bounds `omega` proves; a node of another kind gets no value. It
proves the exits `br` and a conditional branch on a comparison whose direction `omega` proves,
and a branch into blocks with `phi`s on such a comparison or on a constant word; after such an
edge, the registers its `phi`s set get their operands' values (registers, or integer constants of
natural numbers), the others keep theirs, and the position the edge enters at is computed from
the function. An obligation on a closed valuation that no lemma reaches is decided by the
kernel. Each obligation or exit it does not prove (one that needs a node without a value, a
branch `omega` does not decide, a position of an unknown function) is left as a goal, and logged
as `mojo_obl: open goal`; a goal of another form is left open whole. -/
syntax (name := mojoObl) "mojo_obl" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_obl` on the main goal. -/
@[tactic mojoObl] def evalMojoObl : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Obl.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
