import Lean
import MojoProof.Sym.OblLemmas
import MojoProof.Sym.Loop
import MojoProof.Sym.MetaRun

/-!
# The tactic mojo_obl

A block summary (`Summary`, MojoProof/Sym/Checker.lean) carries obligations (`Cond`) on the values
of its node table, and a path of summaries has its premises (`WalkWith`) when each block's
obligations hold and each exit goes to the next block. MojoProof/Sym/OblLemmas.lean reduces
these, node kind by node kind, to the semantics' operations; this module's tactic chains those
lemmas over concrete summaries.

mojo_obl (syntax `mojoObl`, elaborator `evalMojoObl`, method `Obl.run`) closes goals that are
conjunctions and implications of `WalkWith c V ps` (with or without a `fmul contract` setting
`c`, each block after the first entered through `Valuation.intoWith c`),
`∀ d ∈ ds, d.Holds V (vals V S.nodes)`, `d.Holds V (vals V S.nodes)`,
`S.exit.target V (vals V S.nodes) = some l` and `S.exit.dest V (vals V S.nodes) = some l`, a
loop's `Edge h p V l ds S E` and `Round h p ds S B V` of MojoProof/Sym/Loop.lean and their forms
`EdgeWith c h p V l ds S E` and `RoundWith c h p ds S B V`, and of universal
statements: `∀ i < K, P i` for a literal `K` is one `P i` per `i`; any other `∀ x, P x` is `P x`
for an arbitrary `x`, so `∀ i < K, P i` for a `K` that is no literal (a runtime trip count, a
variable or `smax(x, 0)` of an argument) is `P i` with `i < K` among the hypotheses, one proof
for every bound. `V` is a valuation under `after`s,
`into`s and `Valuation.resume`s (a thread resumed after a collective call with a delivery `d`) over
an entry valuation `Valuation.entry c k m f`, or any other; a loop's rounds
`Valuation.round h S B W`, an iterate `f^[k] W` with a literal `k` and another constant are first
rewritten to them. The summaries are concrete (as `sym_summary` and `mojo_kernel` define them).
It builds each proof term from the lemmas of MojoProof/Sym/OblLemmas.lean, every argument given,
reads the concrete summaries, statements and paths by kernel `whnf`, and proves:

1. a node's value from the hypotheses, by type (with the parts of each hypothesis of the context
   and of the goal, its conjuncts and the fields of a structure of propositions, so an invariant
   or a precondition may be one conjunction or one structure): the registers
   (`f.regs r = some v` of an entry frame, `V.regs r = some v` of another valuation), the
   function and program (`f.fn = F` or `V.fn = F`, `c.prog = P` or `V.ctx.prog = P`), struct
   loads (`m.load … = .ok v`), a global's pointer (`c.globals g = some p`), and for the launch
   (`L.Valid`, `c.env = L.env k`, and the 1-D hypotheses of `Launch.index_oneDim`) the register
   ranges of `Launch.sreg_lt`, `Launch.index_lt` and `Launch.sreg_bound` and the index equation;
2. a pointer into a buffer and its loads and stores from `m.Buffer` (a global buffer) or
   `m.BufferIn s c size al o w` (a buffer of any address space `s`, so shared memory's 3, owned by
   `o`), a no-wrap fact for the pointer's address space (in the generic space 0 `Mem.Fits` of
   MojoProof/Sem/Precond.lean, or any hypothesis that unfolds to the existential; in the
   buffer's space `s` `∃ blk, m.blocks c = some blk ∧ blk.addr + size ≤ 2 ^ (l.ptr s).1`), that
   the owner admits the thread (by the kernel for `.all`, else a hypothesis
   `o.admits c.who = true`), `m.Holds` and the alignment `A ∣ al`;
3. arithmetic premises by `omega`, from the local context and the launch facts, after
   evaluating their closed `Nat` subterms; `rfl` premises by kernel defeq; closed decidable
   propositions by `decide`, and so an obligation on a closed valuation that the lemmas do not
   reach (a store to a block no `m.Buffer` describes);
4. an edge into a block with `phi`s: where it goes from its condition, each `phi`'s value from
   its operand for the edge (`Valuation.into_regs_phi`, `enter`'s lemma), another register's
   with no operand evaluated (`Valuation.intoWith_regs_phi_ne`), and the position it enters at
   (`Exit.pc`, from the function).

Each obligation and exit it proves is checked by the kernel against its statement. One it does not
prove stays a goal and is logged ("mojo_obl: open goal"); with `set_option mojo_obl.debug true` it
logs why. A goal of another form stays open whole. The node kinds it evaluates and the exits it
proves are listed in the docstring of the syntax `mojoObl`. Tests: MojoProofTest/Obl.lean
(`vector_addition`'s two paths, every thread of every valid one-dimensional launch; the counting
loop's edges, rounds and path out, and its rounds for every bound under an invariant);
MojoProofTest/OblNaive.lean (the obligations of a block with a float constant, the naive matrix
product's `%45`); MojoProofTest/OblShared.lean (the counting loop's rounds on a buffer of shared
memory, through pointers of address space 3); MojoProofTest/OblMatmul.lean (the naive matrix
product's paths with `fmul contract`: its loop's rounds, the path out, and the paths of the
threads in and out of range of every valid launch); MojoProofTest/OblGevm.lean (gevm_kernel's
lane number, its entry block and edge into the loop at every thread of every valid launch with
`ntid.x = 1024`, the entry's registers, its loop's rounds for every `K` divisible by 32, and the
segment after the loop up to its barrier, through the shared array's pointer);
MojoProofTest/OblInt.lean (the open-goal twins of the integer lemmas, on hand-written blocks).
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
  /-- A table of the node values of a valuation and summary (mojo_vals' entries, a hypothesis
  `vals V S.nodes = ws`): each `(v, (vals V S.nodes)[j]? = some (.ok v))`. -/
  nodes : Std.HashMap (Expr × Expr) (Array (Option (Expr × Expr))) := {}
  /-- The value of one node of a valuation and summary, by valuation, summary and number, each
  computed when it is first read (`nodeVal`): `(v, (vals V S.nodes)[j]? = some (.ok v))`, or
  none. -/
  node : Std.HashMap (Expr × Expr × Nat) (Option (Expr × Expr)) := {}
  /-- The nodes of a summary (`klist` of `S.nodes`), by summary. -/
  lists : Std.HashMap Expr (Array Expr) := {}
  /-- The register values of a valuation: `(v, V.regs r = some v)`. -/
  regs : Std.HashMap (Expr × Nat) (Expr × Expr) := {}
  /-- The memory of a valuation: `(M, V.mem = M, M.blocks = m.blocks)`, `m` the entry memory. -/
  mems : Std.HashMap Expr (Expr × Expr × Expr) := {}
  /-- The `phi` operands of an edge (`phiEdge`), by valuation, block and summary. -/
  edges : Std.HashMap (Expr × Expr × Expr) (Expr × Expr × Expr × Expr × List Expr) := {}
  /-- The values of an edge's `phi` operands (`phiVals`), by valuation, summary, valuation after
  the block and frame. -/
  phis : Std.HashMap (Expr × Expr × Expr × Expr) (Array (Expr × Expr × Expr) × Expr) := {}
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
  /-- The parts of the context's hypotheses (`withFacts`), left out of the goals left open. -/
  hidden : Array FVarId := #[]

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

/-- Whether the proposition `t` is a disequality `a ≠ b` or `¬ a = b`, or a conjunction with one
among its conjuncts. -/
partial def hasNe (t : Expr) : Bool :=
  t.isAppOfArity ``Ne 3 || (t.isAppOfArity ``Not 1 && t.appArg!.isAppOfArity ``Eq 3) ||
    (t.isAppOfArity ``And 2 && (hasNe t.appFn!.appArg! || hasNe t.appArg!))

/-- An `omega` proof of `t`, from the local context and the launch facts, after splitting the
`if`s of `t` (to depth 4, `splitIfTarget?`), each case with its condition in the context: a
word an undecided `select` gives (`SNode.eval_select_word`) is an `if`. omega is first called
without the context's disequalities (`hasNe`), since it splits each in two cases before the
`max` and `min` a bound may need, then with them. -/
def arith (t : Expr) : M Expr := do
  let t' ← litify (← instantiateMVars t)
  let g ← mkFreshExprMVar t'
  let facts := (← get).facts
  let rec /-- Closes `g` by `omega` from the local context and `facts`, after splitting the `if`s
  of its target to the depth the second argument gives, each case with its condition in the
  context. -/
  go (g : MVarId) : Nat → MetaM Unit
    | d + 1 => do
      if let some (g1, g2) ← splitIfTarget? g then
        go g1.mvarId d
        go g2.mvarId d
      else go g 0
    | 0 => do
      let before ← g.withContext do return (← getLocalHyps).map (·.fvarId!)
      let some g' ← g.falseOrByContra | return
      g'.withContext do
        let hyps ← getLocalHyps
        -- first without the context's disequalities, which omega splits in two each (the
        -- negated goal stays)
        let fewer ← hyps.filterM fun h => do
          return !(before.contains h.fvarId! && hasNe (← instantiateMVars (← inferType h)))
        if fewer.size < hyps.size then
          let s ← saveState
          try
            Lean.Elab.Tactic.Omega.omega (fewer.toList ++ facts) g'
            return
          catch _ => s.restore
        Lean.Elab.Tactic.Omega.omega (hyps.toList ++ facts) g'
  go g.mvarId! 4
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
    -- a global buffer `m.Buffer c size al w` is a buffer of space 1 (`Mem.Buffer.bufferIn`)
    if hd == ``Mem.BufferIn && hd' == ``Mem.Buffer then
      let e := mkAppN (mkConst ``Mem.Buffer.bufferIn) (dt.getAppArgs.push d.toExpr)
      let s ← saveState
      if ← isDefEq t (← inferType e) then return e
      s.restore
      continue
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

/-- A hypothesis of type `t` (`findHyp`), else, when `t` is closed, `closedDec` (an alignment
`A ∣ al` of two literals). -/
def hypOrDec (t : Expr) : MetaM Expr := do
  try findHyp t catch e => try closedDec t catch _ => throw e

/-- A proof of the equation `t` by `krfl` (the kernel), else a local hypothesis (`findHyp`): an
entry register's `fmul contract` factors `none` at the entry of a frame that is a variable. -/
def rflOrHyp (t : Expr) : MetaM Expr := do
  let t ← instantiateMVars t
  let (``Eq, #[_, a, b]) := t.getAppFnArgs | findHyp t
  try krfl a b catch e => try findHyp t catch _ => throw e

/-- A proof of `t` (a buffer's owner admitting the thread, `o.admits w = true`) by `decide`, the
kernel evaluating it with the local variables in it (so `Owner.all.admits w = true` for every
thread `w`), else a local hypothesis (`findHyp`). -/
def admitsP (t : Expr) : MetaM Expr := do
  let t ← instantiateMVars t
  try
    if t.hasExprMVar then throwError "mojo_obl: not determined{indentExpr t}"
    let inst ← synthInstance (mkApp (mkConst ``Decidable) t)
    let dt := mkApp2 (mkConst ``Decidable.decide) t inst
    unless ← kdefeq dt (mkConst ``Bool.true) do throwError "mojo_obl: not decided{indentExpr t}"
    return mkApp3 (mkConst ``of_decide_eq_true) t inst
      (mkApp2 (mkConst ``Eq.refl [Level.one]) (mkConst ``Bool) (mkConst ``Bool.true))
  catch _ => findHyp t

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

/-- The valuation under `after`s and `into`s (with or without `fmul contract`). -/
partial def rootOf (V : Expr) : Expr :=
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', _]) => rootOf V'
  | (``Valuation.into, #[V', _, _]) => rootOf V'
  | (``Valuation.afterWith, #[_, V', _]) => rootOf V'
  | (``Valuation.intoWith, #[_, V', _, _]) => rootOf V'
  | _ => V

/-- The context, memory and frame of the valuation under `after`s and `into`s: those of an entry
valuation `Valuation.entry c k m f`; for the valuation after a collective call
(`Valuation.resume V' S r d`), the context of `V'` and the delivered memory `d.2`, and no frame;
else its context and memory and no frame. -/
partial def baseOf (V : Expr) : Expr × Expr × Option Expr :=
  let R := rootOf V
  match R.getAppFnArgs with
  | (``Valuation.entry, #[c, _, m, f]) => (c, m, some f)
  | (``Valuation.resume, #[V', _, _, d]) => ((baseOf V').1, mkApp3 (mkConst ``Prod.snd
      [Level.zero, Level.zero]) (mkApp (mkConst ``Option [Level.zero]) (mkConst ``Val))
      (mkConst ``Mem) d, none)
  | _ => (mkApp (mkConst ``Valuation.ctx) R, mkApp (mkConst ``Valuation.mem) R, none)

/-- A hypothesis `lhs = rhs` with `lhs` the kernel's equal of `a`, or `a = a`. -/
def eqHyp (a : Expr) : MetaM (Expr × Expr) := do
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    if let some (_, l, r) := (← instantiateMVars d.type).eq? then
      if l.getAppFn == a.getAppFn && (← kdefeq l a) then return (r, d.toExpr)
  return (a, ← mkEqRefl a)

/-- `V.fn = R.fn` (`k = 1`) or `V.ctx = R.ctx` (`k = 0`), `R` the valuation under `after`s
and `into`s, through each `into` by `Valuation.into_k` and each `Valuation.intoWith` by
`Valuation.intoWith_k` (and each `after` by definition); `none` when there is no `into` (the
kernel then reduces the field itself). -/
partial def intoField (k : Nat) (V : Expr) : MetaM (Option Expr) := do
  let fld := if k == 0 then ``Valuation.ctx else ``Valuation.fn
  let R := rootOf V
  let viaK (hk V' : Expr) : MetaM (Option Expr) := do
    let h := if k == 0 then mkProj ``And 0 hk else mkProj ``And 0 (mkProj ``And 1 hk)
    let h := hint h (← mkEq (mkApp (mkConst fld) V) (mkApp (mkConst fld) V'))
    match ← intoField k V' with
    | some h' => return some (← mkEqTrans h h')
    | none => return some (← mkEqTrans h (← mkEqRefl (mkApp (mkConst fld) V')))
  let viaAfter (V' : Expr) : MetaM (Option Expr) := do
    let some h ← intoField k V' | return none
    return some (hint h (← mkEq (mkApp (mkConst fld) V) (mkApp (mkConst fld) R)))
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', _]) => viaAfter V'
  | (``Valuation.afterWith, #[_, V', _]) => viaAfter V'
  | (``Valuation.into, #[V', l, S]) => viaK (mkApp3 (mkConst ``Valuation.into_k) V' l S) V'
  | (``Valuation.intoWith, #[c, V', l, S]) =>
    viaK (mkApp4 (mkConst ``Valuation.intoWith_k) c V' l S) V'
  | _ => return none

/-- `V.fn = F`: the entry frame's function or the valuation's, from a hypothesis on it; after a
collective call (`Valuation.resume V' S r d`, whose function is `V'`'s), `V'`'s. -/
partial def fnOf (V : Expr) : MetaM (Expr × Expr) := do
  let (F, hF) ← match baseOf V, (rootOf V).getAppFnArgs with
    | (_, _, some f), _ => eqHyp (mkApp (mkConst ``Frame.fn) f)
    | _, (``Valuation.resume, #[V', _, _, _]) => do
      let (F, h) ← fnOf V'
      pure (F, hint h (← mkEq (mkApp (mkConst ``Valuation.fn) (rootOf V)) F))
    | _, _ => eqHyp (mkApp (mkConst ``Valuation.fn) (rootOf V))
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
    out := mkApp2 (mkConst ``Launch.laneid_lt) L k :: out
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

/-- A float literal's value `v = .ofFloat t y` (as the kernel reduces `floatLit ft lit`) as
`.ofFloat ft (Model.ofNatBits N)`, `N` the literal number of `y`'s bits. -/
def flitVal (ft v : Expr) : MetaM Expr := do
  let (``Val.ofFloat, #[_, y]) := v.getAppFnArgs | throwError "mojo_obl: not a float{indentExpr v}"
  let fmt := mkApp (mkConst ``FloatTy.fmt) ft
  let n ← natOf (mkApp2 (mkConst ``FloatLib.Floats.Formats.BinaryInterchange.Model.toNatBits)
    fmt y)
  return mkApp2 (mkConst ``Val.ofFloat) ft
    (mkApp2 (mkConst ``FloatLib.Floats.Formats.BinaryInterchange.Model.ofNatBits) fmt
      (mkNatLit n))

/-- **A float literal's value**, `(v, floatLit ft lit = .ok v)` by the kernel's reduction of
`floatLit ft lit`, `v` as `flitVal` writes it when it is a float. -/
def flitOf (ft lit : Expr) : MetaM (Expr × Expr) := do
  let r := mkApp2 (mkConst ``floatLit) ft lit
  let (``Except.ok, #[_, _, v]) := (← kwhnf r).getAppFnArgs
    | throwError "mojo_obl: float literal with no value{indentExpr lit}"
  try
    let v' ← flitVal ft v
    return (v', ← krfl r (mkOk v'))
  catch _ => return (v, ← krfl r (mkOk v))

/-- Whether one of the `phi` operands `ops` (of an edge, `phiEdge`) sets register `r`. -/
def phiSets (ops : List Expr) (r : Nat) : MetaM Bool := do
  for op in ops do
    if let (``Option.some, #[_, o]) := (← kwhnf (← kpair op).1).getAppFnArgs then
      if (← natOf o) == r then return true
  return false

/-- Whether `r'` (an `Option Nat`) is `some r`, by the kernel; and the delivered value of `d`
(an `Option Val × Mem`), `(v, d.1 = some v)` from a hypothesis, when it is. -/
def resumeAt (r' d : Expr) (r : Nat) : MetaM (Option (Expr × Expr)) := do
  let (``Option.some, #[_, n]) := (← kwhnf r').getAppFnArgs | return none
  unless (← natOf n) == r do return none
  let (v, h) ← eqHyp (mkApp3 (mkConst ``Prod.fst [Level.zero, Level.zero])
    (mkApp (mkConst ``Option [Level.zero]) (mkConst ``Val)) (mkConst ``Mem) d)
  let (``Option.some, #[_, v]) := v.getAppFnArgs
    | throwError "mojo_obl: the collective's value of register {r} is not known"
  return some (v, h)

mutual

/-- **A hypothesis on a node's value**: `(v, (vals V S.nodes)[j]? = some (.ok v))` from a local
hypothesis `h : ∀ xs, P₁ → … → Pₙ → (vals V' ns)[j]? = some (.ok v)` (a literal `j`; a plain
equation when there are no binders) whose left side the kernel equates with `(vals V S.nodes)[j]?`
(`V'` and `ns` closed under the variables `xs`). Each premise `Pᵢ` is an equation on a register,
its `fmul contract` operands or a node at `V'` (`V'.regs r`, `V'.prods r`, `(vals V' T.nodes)[i]?`):
its left side's value at `V` (`regOf`, `prodOf`, `nodeVal`, which reads the nodes of `S` before
`j`) unified with its right side, which sets the variables `xs`. `none` when there is no such
hypothesis. For every program. -/
partial def nodeHyp (V S : Expr) (j : Nat) : M (Option (Expr × Expr)) := do
  let a := mkApp2 (mkConst ``vals) V (mkApp (mkConst ``Summary.nodes) S)
  let isNode (l : Expr) : Option (Array Expr) := do
    let (``GetElem?.getElem?, args) := l.getAppFnArgs | none
    guard (args.size == 7 && args[5]!.isAppOfArity ``vals 2)
    return args
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let ty ← instantiateMVars d.type
    -- the conclusion's form, before the binders are opened
    let some (_, l, _) := ty.getForallBody.eq? | continue
    let some args := isNode l | continue
    unless (args[6]!.nat? <|> args[6]!.rawNatLit?) == some j do continue
    let r ← try
        let (xs, bis, c) ← forallMetaTelescope ty
        let some (_, l, x) := c.eq? | failure
        let some args := isNode l | failure
        let V' ← instantiateMVars args[5]!.appFn!.appArg!
        let ns ← instantiateMVars args[5]!.appArg!
        if V'.hasMVar || ns.hasMVar then failure
        unless ← kdefeq args[5]! a do failure
        for xi in xs, bi in bis do
          unless bi.isExplicit do continue
          let some (_, pl, pr) := (← instantiateMVars (← inferType xi)).eq? | failure
          let (v, p) ← match pl.getAppFnArgs with
            | (``Valuation.regs, #[W, q]) =>
              unless W == V' do failure
              let (v, p) ← regOf V (← natOf q)
              pure (← mkSome (mkConst ``Val) v, p)
            | (``Valuation.prods, #[W, q]) =>
              unless W == V' do failure
              prodOf V (← natOf q)
            | _ =>
              let some qs := isNode pl | failure
              let (``vals, #[W, ns']) := qs[5]!.getAppFnArgs | failure
              let (``Summary.nodes, #[T]) := ns'.getAppFnArgs | failure
              unless W == V' do failure
              let i ← natOf qs[6]!
              -- of `S`, only a node before `j`
              if T == S && j ≤ i then failure
              let some (v, p) ← nodeVal V T i | failure
              pure (← mkAppOptM ``Option.some #[none, mkOk v], p)
          unless ← isDefEq pr v do failure
          xi.mvarId!.assign (hint p (← instantiateMVars (← inferType xi)))
        let x ← instantiateMVars x
        let (``Option.some, #[_, o]) := x.getAppFnArgs | failure
        let (``Except.ok, #[_, _, v]) := o.getAppFnArgs | failure
        let pf ← instantiateMVars (mkAppN d.toExpr xs)
        if v.hasMVar || pf.hasMVar then failure
        let lhs := mkAppN l.getAppFn (args.set! 5 a)
        pure (some (v, hint pf (← mkEq lhs x)))
      catch _ => pure none
    if r.isSome then return r
  return none

/-- **The value of operand `x`** at valuation `V` on summary `S`'s nodes (the first `j` of them,
or all): `(v, x.eval V vs = .ok v)`. -/
partial def opnd (V S : Expr) (j : Option Nat) (x : Expr) : M (Expr × Expr) := do
  let x ← kdeep x 2
  let vs := vsOf V S j
  match x.getAppFnArgs with
  | (``SVal.node, #[i]) =>
    let i ← natOf i
    -- with `j`, only a node before it
    if j.any (· ≤ i) then throwError "mojo_obl: node {i} has no value"
    let some (_, h) ← nodeVal V S i | throwError "mojo_obl: node {i} has no value"
    let (p, t) ← match j with
      | some j => use ``SVal.eval_node_take [(`j, mkNatLit j)] [.arith, .pf h]
      | none => use ``SVal.eval_node [(`V, V), (`vs, vs)] [.pf h]
    return (← valOf t, p)
  | (``SVal.reg, #[r]) =>
    let (_, h) ← regOf V (← natOf r)
    let (p, t) ← use ``SVal.eval_reg [(`vs, vs)] [.pf h]
    return (← valOf t, p)
  | (``SVal.int, #[w, i]) =>
    let (p, t) ← match i.getAppFnArgs with
      | (``Int.ofNat, #[k]) => use ``SVal.eval_int_ofNat [(`V, V), (`vs, vs)] [.pf w, .pf k]
      -- `-(k + 1)`, the word of `2 ^ w - (k + 1)`
      | (``Int.negSucc, #[k]) =>
        use ``SVal.eval_int_negSucc [(`V, V), (`vs, vs)] [.pf w, .pf k, .dec]
      | _ => throwError "mojo_obl: integer constant{indentExpr x}"
    return (← valOf t, p)
  | _ => throwError "mojo_obl: operand{indentExpr x}"

/-- **The value of register `r`** at valuation `V`: `(v, V.regs r = some v)`. After a collective
call (`Valuation.resume V S r' d`), the value a hypothesis `d.1 = some v` gives at the call's
register (`Valuation.resume_regs_self`), else the register after the segment
(`Valuation.resume_regs_ne`); an error when the call's register has no known value. -/
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
    | (``Valuation.into, #[V', l, S]) => intoReg V' l S r none
    | (``Valuation.afterWith, #[_, V', S]) =>
      -- the registers of `Valuation.after`, by definition
      let (v, h) ← regOf (mkApp2 (mkConst ``Valuation.after) V' S) r
      pure (v, hint h (← mkEq (mkApp2 (mkConst ``Valuation.regs) V (mkNatLit r))
        (← mkSome (mkConst ``Val) v)))
    | (``Valuation.intoWith, #[c, V', l, S]) => intoReg V' l S r (some c)
    | (``Valuation.resume, #[V', S, r', d]) =>
      -- the collective's value at its register, else the register after the segment
      let named := [(`V, V'), (`S, S), (`d, d)]
      match ← resumeAt r' d r with
      | some (v, h) =>
        let (p, _) ← use ``Valuation.resume_regs_self (named ++ [(`r, mkNatLit r), (`v, v)])
          [.pf h]
        pure (v, p)
      | none =>
        let (_, h) ← regOf (mkApp3 (mkConst ``Valuation.afterWith) (mkConst ``Bool.true) V' S) r
        let (p, t) ← use ``Valuation.resume_regs_ne (named ++ [(`r, r'), (`s, mkNatLit r)])
          [.dec, .pf h]
        pure (← valOf t, p)
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
the valuation under `after`s and `into`s. Each block's effects read only the nodes their operands
name (`nodeVal`). -/
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
    | (``Valuation.afterWith, #[_, V', S]) =>
      -- the memory of `Valuation.after`, by definition
      let (M, hM, hb) ← memOf (mkApp2 (mkConst ``Valuation.after) V' S)
      pure (M, hint hM (← mkEq (mkApp (mkConst ``Valuation.mem) V) M), hb)
    | (``Valuation.intoWith, #[c, V', l, S]) =>
      let (M, hM, hb) ← memOf (mkApp3 (mkConst ``Valuation.afterWith) c V' S)
      pure (M, ← mkEqTrans (mkApp4 (mkConst ``Valuation.intoWith_mem) c V' l S) hM, hb)
    | _ => pure (m0, ← krfl (mkApp (mkConst ``Valuation.mem) V) m0, ← mkEqRefl (bl m0))
  modify fun s => { s with mems := s.mems.insert V res }
  return res

/-- `V.mem.blocks = m.blocks`. -/
partial def blocksOf (V : Expr) : M Expr := do
  let (_, hM, hMb) ← memOf V
  mkEqTrans (← mkCongrArg (mkConst ``Mem.blocks) hM) hMb

/-- **The value of node `j`** of summary `S` at valuation `V`:
`(v, (vals V S.nodes)[j]? = some (.ok v))`, or none. From the table of `S`'s nodes at `V` when
there is one (`St.nodes`), else the value a hypothesis gives (`nodeHyp`), else its evaluation
(`nodeEval`), which reads only the nodes its operands name. Each node is computed once, when it is
first read (`St.node`), so the memory, a register or an exit after a block evaluates only the
nodes it uses. -/
partial def nodeVal (V S : Expr) (j : Nat) : M (Option (Expr × Expr)) := do
  if let some a := (← get).nodes[(V, S)]? then return a[j]?.join
  if let some x := (← get).node[(V, S, j)]? then return x
  -- none while it is computed
  modify fun s => { s with node := s.node.insert (V, S, j) none }
  let ns ← match (← get).lists[S]? with
    | some ns => pure ns
    | none =>
      let ns := (← klist (mkApp (mkConst ``Summary.nodes) S)).toArray
      modify fun s => { s with lists := s.lists.insert S ns }
      pure ns
  let r ← match ← nodeHyp V S j, ns[j]? with
    | some r, _ => pure (some r)
    | none, none => pure none
    | none, some nd => do
      let nd ← kdeep nd 3
      let t0 ← IO.monoMsNow
      try
        let (v, he) ← nodeEval V S j nd
        let (p, _) ← use ``vals_getElem?_eval [(`V, V), (`ns, mkApp (mkConst ``Summary.nodes) S),
          (`j, mkNatLit j), (`nd, nd), (`r, mkOk v)] [.rfl, .kd he]
        dbg m!"mojo_obl: node {j} in {(← IO.monoMsNow) - t0} ms:{indentExpr v}"
        pure (some (v, p))
      catch e =>
        dbg m!"mojo_obl: node {j} ({(← IO.monoMsNow) - t0} ms): {e.toMessageData}"
        pure none
  modify fun s => { s with node := s.node.insert (V, S, j) r }
  return r

/-- **Node `nd`** (number `j` of `S`) at `V`: `(v, nd.eval V (vals V (S.nodes.take j)) = .ok v)`.
A float operator with `fmul contract` factors (`SNode.fbinP`) on operand values with local
variables, floats `.ofFloat ft u` whose factors are float pairs or none, is `floatBin` of them by
`SNode.eval_fbinP_ofFloat` (`floatBin_contract_ofFloat` for a contracted `fadd` or `fsub`,
`floatBin_ofFloat_factors` for another operator), else by the kernel. -/
partial def nodeEval (V S : Expr) (j : Nat) (nd : Expr) : M (Expr × Expr) := do
  let vs := vsOf V S (some j)
  let op (x : Expr) := opnd V S (some j) x
  -- the function and program, for the nodes that read a statement
  let fnP : M (List (Name × Expr) × Expr × Expr) := do
    let (F, hF) ← fnOf V
    let (P, hP) ← progOf V
    return ([(`V, V), (`vs, vs), (`F, F), (`P, P)], hF, hP)
  let fin (p : Expr × Expr) : M (Expr × Expr) := do return (← valOf p.2, p.1)
  match nd.getAppFnArgs with
  | (``SNode.load, #[lbl, pc, p]) =>
    let (at_, hF, hP) ← fnP
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
        let at0 := [(`M, mkApp (mkConst ``Valuation.mem) V), (`who, whoOf V),
          (`a, ld.getAppArgs[3]!), (`c, c), (`A, mkNatLit A)]
        let args := [Arg.pf hMb, .hyp, .dec, .hyp, .fn fun t => admitsP t, .hyp,
          .fn fun t => hypOrDec t, .arith, .arith]
        -- a 1-D tensor at element `K`, else a matrix at `(r, k)` for `K = r * S + k`
        let s ← saveState
        try
          return (← (use ``load_buffer (at0 ++ [(`K, K)]) (args ++ [.arith])).run' st).1
        catch e1 =>
          s.restore
          let (``HAdd.hAdd, #[_, _, _, _, rS, k]) := K.getAppFnArgs | throw e1
          let (``HMul.hMul, #[_, _, _, _, r, S']) := rS.getAppFnArgs | throw e1
          try
            return (← (use ``load_buffer2 (at0 ++ [(`r, r), (`S, S'), (`k, k)])
              (args ++ [.arith, .arith, .dec])).run' st).1
          catch e2 => throwError "{e1.toMessageData}\n{e2.toMessageData}"
      fin (← use ``SNode.eval_load_at named [.kd hF, .kd hP, .rfl, .pf hp, .fn fun t => k t, .rfl])
    | _ => fin (← use ``SNode.eval_load_at named [.kd hF, .kd hP, .rfl, .pf hp, .hyp, .rfl])
  | (``SNode.loadAfter, #[lbl, pc, p, es]) =>
    loadAfterEval V S j lbl pc p (← (← klist es).mapM (kdeep · 2))
  | (``SNode.extract, #[is, a]) =>
    let (av, ha) ← op a
    let r := mkApp2 (mkConst ``extractV) av is
    let r' ← kdeep r 4
    let (``Except.ok, #[_, _, v]) := r'.getAppFnArgs | throwError "mojo_obl: extractvalue fails"
    let (p, _) ← use ``SNode.eval_extract [(`is, is)] [.pf ha, .pf (← krfl r r')]
    return (v, p)
  | (``SNode.cast, #[cop, w, a]) =>
    let (av, ha) ← op a
    let sext := (← kwhnf cop).isConstOf ``CastOp.sext
    let (p2, t2) ← try
        let (w', K) ← wordOf av
        if sext then use ``intCast_sext_ofNat [(`w, w'), (`k, K)] [.pf w, .arith]
        else use ``intCast_ofNat [(`op, cop), (`w, w'), (`k, K)] [.dec, .pf w, .arith]
      catch e =>
        -- `sext` of a word of no small number: its sign extension
        let (``Val.bits, #[_, x]) := av.getAppFnArgs | throw e
        unless sext do throw e
        use ``intCast_sext_bits [(`w, w)] [.pf x]
    let (p1, _) ← use ``SNode.eval_cast [(`op, cop), (`w, w)] [.pf ha, .pf p2]
    return (← valOf t2, p1)
  | (``SNode.bin, #[bop, fl, w, a, b]) =>
    let (av, ha) ← op a
    let (bv, hb) ← op b
    -- `and` of two booleans `decide p`, `decide q`: the boolean `decide (p ∧ q)`
    if (← kwhnf bop).isConstOf ``BinOp.and && av.isAppOfArity ``Val.ofBool 1 &&
        bv.isAppOfArity ``Val.ofBool 1 then
      return ← fin (← use ``SNode.eval_and_decide [(`fl, fl)] [.pf ha, .pf hb])
    let (_, Ka) ← wordOf av
    let (_, Kb) ← wordOf bv
    let named := [(`w, w), (`a, Ka), (`b, Kb)]
    -- without `nuw` and `nsw`, the word modulo `2 ^ w`; else under the no-wrap bounds
    let (p2, t2) ← match (← kwhnf bop).constName? with
      | some ``BinOp.add =>
        try use ``intBin_add_wrap (named ++ [(`fl, fl)]) [.dec, .dec]
        catch _ => use ``intBin_add_ofNat named [.pf fl, .arith]
      | some ``BinOp.mul =>
        try use ``intBin_mul_wrap (named ++ [(`fl, fl)]) [.dec, .dec]
        catch _ => use ``intBin_mul_ofNat named [.pf fl, .arith, .arith, .arith]
      | some ``BinOp.sub => use ``intBin_sub_wrap (named ++ [(`fl, fl)]) [.dec, .dec]
      | some ``BinOp.udiv =>
        use ``intBin_udiv_ofNat (named ++ [(`fl, fl)]) [.dec, .arith, .arith, .arith]
      -- a positive divisor, else a negative one (`2 ^ w ≤ 2 b`)
      | some ``BinOp.sdiv =>
        try use ``intBin_sdiv_ofNat (named ++ [(`fl, fl)]) [.dec, .arith, .arith, .arith]
        catch _ => use ``intBin_sdiv_neg (named ++ [(`fl, fl)]) [.dec, .arith, .arith, .arith]
      | some ``BinOp.xor => use ``intBin_xor_ofNat (named ++ [(`fl, fl)]) [.arith, .arith]
      -- the sign of an `xor` of a positive word with a positive or a negative one, all its bits
      | some ``BinOp.ashr =>
        let (``HXor.hXor, #[_, _, _, _, x, y]) := Ka.getAppFnArgs
          | throwError "mojo_obl: ashr of no xor{indentExpr Ka}"
        let at_ := [(`w, w), (`a, x), (`b, y), (`s, Kb), (`fl, fl)]
        try use ``intBin_ashr_xor_pos at_ [.dec, .arith, .arith, .dec]
        catch _ => use ``intBin_ashr_xor_neg at_ [.dec, .arith, .arith, .arith, .dec]
      | _ => throwError "mojo_obl: integer operator{indentExpr bop}"
    let (p1, _) ← use ``SNode.eval_bin [(`op, bop), (`fl, fl)] [.pf ha, .pf hb, .pf p2]
    return (← valOf t2, p1)
  | (``SNode.icmp, #[pr, _, a, b]) =>
    let (_, ha) ← op a
    let (_, hb) ← op b
    match (← kwhnf pr).constName? with
    | some ``ICmp.slt => fin (← use ``SNode.eval_icmp_slt_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | some ``ICmp.ult => fin (← use ``SNode.eval_icmp_ult_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | some ``ICmp.eq =>
      -- words of numbers below `2 ^ w`, else their residues
      try fin (← use ``SNode.eval_icmp_eq_ofNat [] [.pf ha, .pf hb, .arith, .arith])
      catch _ => fin (← use ``SNode.eval_icmp_eq_mod [] [.pf ha, .pf hb])
    | some ``ICmp.sge => fin (← use ``SNode.eval_icmp_sge_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | some ``ICmp.ne => fin (← use ``SNode.eval_icmp_ne_ofNat [] [.pf ha, .pf hb, .arith, .arith])
    | _ => throwError "mojo_obl: comparison{indentExpr pr}"
  | (``SNode.select, #[w, c, a, b]) =>
    let (cv, hc) ← op c
    let (av, ha) ← op a
    let (bv, hb) ← op b
    let (``Val.ofBool, #[p]) := cv.getAppFnArgs | throwError "mojo_obl: select on no boolean"
    -- an undecided condition: the one value of both operands, else the word of an `if` of two
    -- words, else the `if` of the condition's boolean
    let both : M (Expr × Expr) := do
      if ← isDefEq av bv then
        return ← fin (← use ``SNode.eval_select_same [(`w, w)] [.pf hc, .pf ha, .pf hb])
      try fin (← use ``SNode.eval_select_word [(`w, w)] [.pf hc, .pf ha, .pf hb])
      catch _ => fin (← use ``SNode.eval_select_ofBool [(`w, w)] [.pf hc, .pf ha, .pf hb])
    -- the operand the condition picks, when `omega` decides it
    let (``Decidable.decide, #[q, _]) := p.getAppFnArgs | both
    try
      let hp ← mkAppM ``decide_eq_true #[← arith q]
      fin (← use ``SNode.eval_select_true [(`w, w)] [.pf hc, .pf hp, .pf ha, .pf hb])
    catch _ =>
      try
        let hp ← mkAppM ``decide_eq_false #[← arith (mkNot q)]
        fin (← use ``SNode.eval_select_false [(`w, w)] [.pf hc, .pf hp, .pf ha, .pf hb])
      catch _ => both
  | (``SNode.minmax, #[sg, mx, a, b]) =>
    unless (← kwhnf sg).isConstOf ``Bool.true && (← kwhnf mx).isConstOf ``Bool.true do
      throwError "mojo_obl: minimum or unsigned maximum{indentExpr nd}"
    let (_, ha) ← op a
    let (_, hb) ← op b
    fin (← use ``SNode.eval_smax_ofNat [] [.pf ha, .pf hb, .arith, .arith])
  | (``SNode.call, #[lbl, pc]) =>
    let (at_, hF, hP) ← fnP
    let (E, hE) ← envOf V
    let named := at_ ++ [(`lbl, lbl), (`pc, pc), (`E, E)]
    -- a special register, else the lane number (below 32 by a hypothesis or `Launch.laneid_lt`)
    let (p, t) ← try
        use ``SNode.eval_sreg_at named
          [.kd hF, .kd hP, .rfl, .rfl, .rfl, .rfl, .dec, .dec, .kd hE, .fn fun t => sregBound t]
      catch e =>
        let lane (t : Expr) : MetaM Expr := do
          try findHyp t catch _ =>
            let (``Launch.env, #[L, k]) := E.getAppFnArgs | throw e
            return mkApp2 (mkConst ``Launch.laneid_lt) L k
        use ``SNode.eval_laneid_at named
          [.kd hF, .kd hP, .rfl, .rfl, .rfl, .rfl, .dec, .kd hE, .fn fun t => lane t]
    -- the number a hypothesis gives the register (`ntid.x = 1024`)
    let (_, K) ← wordOf (← valOf t)
    let (K', hK) ← eqHyp K
    if K'.equal K then return (← valOf t, p)
    fin (← use ``SNode.eval_word_eq [] [.pf p, .pf hK])
  -- a global's pointer, from a hypothesis `c.globals g = some p`
  | (``SNode.globalAt, #[lbl, pc, i]) =>
    let (at_, hF, _) ← fnP
    fin (← use ``SNode.eval_globalAt_at (at_.take 3 ++ [(`lbl, lbl), (`pc, pc), (`i, i)])
      [.kd hF, .rfl, .rfl, .hyp])
  -- a `bitcast` between scalar types of one width keeps its operand's word
  | (``SNode.castAt, #[lbl, pc, n, a]) =>
    let (at_, hF, hP) ← fnP
    let (_, ha) ← op a
    fin (← use ``SNode.eval_bitcast_at (at_ ++ [(`lbl, lbl), (`pc, pc), (`n, n)])
      [.kd hF, .kd hP, .pf ha, .rfl, .rfl, .rfl, .rfl])
  | (``SNode.gep, #[lbl, pc, base, idx]) =>
    let (at_, hF, hP) ← fnP
    let (iv, hi) ← op idx
    let (bv, hb) ← op base
    let (c, _) ← ptrParts (← ptrOf bv)
    let hMb ← blocksOf V
    let st ← get
    -- `gep_buffer` at the statement's flags and source type, once the statement is matched; else
    -- `gep_buffer2` at an index `r * S + k` (cell `(r, k)` of a matrix); else, by any word,
    -- `gep_buffer_ok`'s value, of no known form (`Classical.choose`)
    let k (t : Expr) : MetaM Expr := do
      let some (_, g, _) := t.eq? | throwError "mojo_obl: getelementptr"
      let ga := g.getAppArgs
      let at0 := [(`M, mkApp (mkConst ``Valuation.mem) V), (`fl, ga[2]!), (`src, ga[3]!),
        (`a, ga[4]!), (`c, c)]
      let s ← saveState
      try
        let (w, K) ← wordOf iv
        let (pf, _) ← (use ``gep_buffer (at0 ++ [(`K, K), (`w, w)])
          [.pf hMb, .hyp, .dec, .hyp, .arith, .arith, .arith, .arith]).run' st
        return pf
      catch e =>
        s.restore
        try
          let (w, K) ← wordOf iv
          let (``HAdd.hAdd, #[_, _, _, _, rS, k]) := K.getAppFnArgs | throw e
          let (``HMul.hMul, #[_, _, _, _, r, S']) := rS.getAppFnArgs | throw e
          let named := at0 ++ [(`l, ga[0]!), (`r, r), (`S, S'), (`k, k), (`w, w)]
          let (pf, _) ← (use ``gep_buffer2 named
            [.pf hMb, .hyp, .dec, .hyp, .arith, .arith, .arith, .dec, .arith, .arith]).run' st
          return pf
        catch _ => s.restore
        let (``Val.bits, #[w, x]) := iv.getAppFnArgs | throw e
        let named := at0 ++ [(`l, ga[0]!), (`w, w), (`x, x)]
        let (ex, _) ← (use ``gep_buffer_ok named [.pf hMb, .hyp, .dec]).run' st
        let sp ← mkAppM ``Classical.choose_spec #[ex]
        return hint sp (← instantiateMVars (← inferType sp)).headBeta
    fin (← use ``SNode.eval_gep_at (at_ ++ [(`lbl, lbl), (`pc, pc)])
      [.kd hF, .kd hP, .rfl, .pf hi, .pf hb, .fn fun t => k t])
  | (``SNode.fbin, #[fop, fm, _, n, _, _]) =>
    let args := nd.getAppArgs
    let (_, ha) ← op args[4]!
    let (_, hb) ← op args[5]!
    -- `SVal.prods V x = none`: at a register, the factors `prodOf` gives when they are `none`
    -- (after a collective call too), else by the kernel or a hypothesis
    let noProds (t : Expr) : M Expr := do
      let some (_, l, _) := (← instantiateMVars t).eq? | rflOrHyp t
      let (``SVal.prods, #[_, x]) := l.getAppFnArgs | rflOrHyp t
      let (``SVal.reg, #[r]) := (← kdeep x 2).getAppFnArgs | rflOrHyp t
      let s ← (saveState : MetaM Meta.SavedState)
      try
        let (pv, h) ← prodOf V (← natOf r)
        unless (← kwhnf pv).isAppOf ``Option.none do throwError "mojo_obl: factors"
        return hint h t
      catch _ =>
        (s.restore : MetaM Unit)
        rflOrHyp t
    fin (← use ``SNode.eval_fbin_ofFloat [(`op, fop), (`fm, fm), (`n, n)]
      [.pf ha, .pf hb, .fn noProds, .fn noProds, .rfl, .rfl, .rfl, .rfl])
  | (``SNode.fbinP, #[fop, fm, ft, n, a, b, pa, pb]) =>
    let (x, ha) ← op a
    let (y, hb) ← op b
    let named := [(`op, fop), (`fm, fm), (`ft, ft), (`n, n), (`pa, pa), (`pb, pb)]
    -- the semantics' `floatBin` on the operands' values and factors, by the kernel
    let kern : M (Expr × Expr) := do fin (← use ``SNode.eval_fbinP named [.pf ha, .pf hb, .rfl])
    unless x.hasFVar || y.hasFVar do return ← kern
    -- symbolic floats: lane 0 of each operand's factors as float pairs (`q`), then `floatBin`
    -- on them by `floatBin_contract_ofFloat`, else `floatBin_ofFloat_factors`
    let flt (v : Expr) : M Expr := do
      let (``Val.ofFloat, #[_, u]) := v.getAppFnArgs
        | throwError "mojo_obl: not a float{indentExpr v}"
      return u
    let sym : M (Expr × Expr) := do
      let u ← flt x
      let pty ← mkAppM ``Prod #[← inferType u, ← inferType u]
      let fac (s p : Expr) : M Expr := do
        let at0 := [(`V, V), (`vs, vs), (`x, s), (`t, ft)]
        match (← kdeep p 2).getAppFnArgs with
        | (``Option.some, #[_, st]) =>
          let (s₁, s₂) ← kpair st
          let (_, h₁) ← op s₁
          let (_, h₂) ← op s₂
          return (← use ``laneOf_prodsWith_some at0 [.pf h₁, .pf h₂]).1
        | _ =>
          let none' ← mkAppOptM ``Option.none #[some pty]
          let (``SVal.reg, #[r]) := (← kdeep s 2).getAppFnArgs
            | return (← use ``laneOf_prodsWith_none (at0 ++ [(`q, none')]) [.rfl]).1
          let (pv, hp) ← prodOf V (← natOf r)
          let q ← match (← kwhnf pv).getAppFnArgs with
            | (``Option.some, #[_, vv]) =>
              let (v₁, v₂) ← kpair vv
              mkAppOptM ``Option.some #[some pty, some (← mkAppM ``Prod.mk #[← flt v₁, ← flt v₂])]
            | _ => pure none'
          return (← use ``laneOf_prodsWith_none (at0 ++ [(`q, q)]) [.kd hp]).1
      let hpa ← fac a pa
      let hpb ← fac b pb
      -- `floatBin t op fm (.ofFloat t u) (.ofFloat t u') (qa.map _) (qb.map _) N = .ok _`
      let fl (ty : Expr) : M Expr := do
        let some (_, l, _) := (← instantiateMVars ty).eq? | throwError "mojo_obl: fbinP"
        let (``floatBin, #[t, o, fm, X, Y, PX, PY, N]) := l.getAppFnArgs
          | throwError "mojo_obl: fbinP{indentExpr l}"
        let at0 := [(`t, t), (`op, o), (`fm, fm), (`a, X.appArg!), (`b, Y.appArg!), (`n, N)]
        let s ← (saveState : MetaM Meta.SavedState)
        try
          return (← use ``floatBin_contract_ofFloat
            (at0 ++ [(`pa, PX.appArg!), (`pb, PY.appArg!)])
            [.rfl, .rfl, .rfl, .rfl, .rfl, .rfl]).1
        catch e =>
          (s.restore : MetaM Unit)
          try
            return (← use ``floatBin_ofFloat_factors (at0 ++ [(`px, PX), (`py, PY)])
              [.rfl, .rfl, .rfl, .rfl, .rfl]).1
          catch _ =>
            throwError "mojo_obl: floatBin on symbolic floats{indentExpr l}\n{e.toMessageData}"
      fin (← use ``SNode.eval_fbinP_ofFloat named [.pf ha, .pf hb, .pf hpa, .pf hpb, .fn fl])
    let s ← (saveState : MetaM Meta.SavedState)
    try sym catch e =>
      (s.restore : MetaM Unit)
      try kern catch _ => throw e
  | (``SNode.flit, #[ft, lit]) =>
    -- the literal's value by the kernel, a float `.ofFloat ft (Model.ofNatBits N)` when it is one
    fin (← use ``SNode.eval_flit [(`V, V), (`vs, vs)] [.pf (← flitOf ft lit).2])
  | _ => throwError "mojo_obl: node{indentExpr nd}"

/-- **A `load` after effects** (`SNode.loadAfter lbl pc p es`, node `j` of `S`) at `V`:
`(v, (SNode.loadAfter lbl pc p es).eval V (vals V (S.nodes.take j)) = .ok v)`, by the last
effect: a `load` effect leaves the node as it is (`SNode.eval_loadAfter_log_ex`); a `store` at a
pointer of the value of `p`'s, of an integer word or a float (`Layout.Codec.int`,
`Layout.Codec.float`), gives the stored value (`SNode.eval_loadAfter_store_codec`); a `store` at
a pointer apart from `p`'s, by `omega`, is passed by (`SNode.eval_loadAfter_apart_at`); with no
effect left, the node is the `load` from `V`'s memory (`SNode.eval_loadAfter_nil`). The effects
run as a block's (`runExAt`); an error when a step does not apply. For every program. -/
partial def loadAfterEval (V S : Expr) (j : Nat) (lbl pc p : Expr) (es : List Expr) :
    M (Expr × Expr) := do
  let vs := vsOf V S (some j)
  let some e := es.getLast? | do
    let (v, h) ← nodeEval V S j (mkApp3 (mkConst ``SNode.load) lbl pc p)
    return (v, ← mkEqTrans (← mkAppOptM ``SNode.eval_loadAfter_nil
      #[some V, some vs, some lbl, some pc, some p]) h)
  let init := es.dropLast
  let initL ← mkListLit (mkConst ``SEff) init
  let hr ← runExAt V S es (some j)
  let at0 := [(`V, V), (`vs, vs), (`lbl, lbl), (`pc, pc), (`p, p), (`es, initL)]
  match e.getAppFnArgs with
  | (``SEff.load, #[lbl', pc', y]) =>
    let (v, h) ← loadAfterEval V S j lbl pc p init
    let (pf, _) ← use ``SNode.eval_loadAfter_log_ex
      (at0 ++ [(`lbl', lbl'), (`pc', pc'), (`y, y)]) [.kd hr, .pf h]
    return (v, pf)
  | (``SEff.store, #[lbl', pc', x, y]) =>
    let (F, hF) ← fnOf V
    let (P, hP) ← progOf V
    let (qp, hp) ← opnd V S (some j) p
    let (qy, hy) ← opnd V S (some j) y
    let at1 := at0 ++ [(`F, F), (`P, P), (`lbl', lbl'), (`pc', pc'), (`x, x), (`y, y)]
    let lay := mkApp (mkConst ``Program.layout) P
    if ← isDefEq qp qy then
      -- the same pointer: the stored value, of a codec
      let (xv, hx) ← opnd V S (some j) x
      let (hc, u) ← match xv.getAppFnArgs with
        | (``Val.ofFloat, #[ft, u]) => pure (mkApp2 (mkConst ``Layout.Codec.float) lay ft, u)
        | (``Val.bits, #[w, u]) => pure (mkApp2 (mkConst ``Layout.Codec.int) lay w, u)
        | _ => throwError "mojo_obl: a load after a store of a value of no codec{indentExpr xv}"
      let (pf, _) ← use ``SNode.eval_loadAfter_store_codec (at1 ++ [(`u, u)])
        [.kd hF, .kd hP, .pf hc, .rfl, .rfl, .rfl, .kd hr, .pf (← mkEqTrans hy (← mkEqSymm hp)),
          .pf hx]
      return (xv, pf)
    let (v, h) ← loadAfterEval V S j lbl pc p init
    let (pf, _) ← use ``SNode.eval_loadAfter_apart_at at1
      [.kd hF, .kd hP, .rfl, .rfl, .kd hr, .pf hp, .pf hy, .arith, .pf h]
    return (v, pf)
  | _ => throwError "mojo_obl: a load after the effect{indentExpr e}"

/-- A `load` effect at `V` on summary `S`'s values (those before node `j`, all for `none`), on
memory `m`: its proof and the memory. -/
partial def effLoad (V S e m : Expr) (j : Option Nat := none) : M (Expr × Expr) := do
  let (``SEff.load, #[lbl, pc, p]) := e.getAppFnArgs | throwError "mojo_obl: not a load"
  let (_, hp) ← opnd V S j p
  let (F, hF) ← fnOf V
  let (pf, t) ← use ``SEff.apply_load_at [(`V, V), (`vs, vsOf V S j), (`m, m), (`F, F),
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

/-- A `store` effect at `V` on memory `m`, whose blocks are the entry memory's: `∃ M', _`, on
the values of `S`'s nodes before node `j` (all for `none`). -/
partial def effStore (V S e m : Expr) (j : Option Nat := none) : M Expr := do
  let (``SEff.store, #[lbl, pc, v, p]) := e.getAppFnArgs | throwError "mojo_obl: not a store"
  let (x, hv) ← opnd V S j v
  let (qv, hp) ← opnd V S j p
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
    let (pf, _) ← (use ``store_buffer [(`M, m), (`who, whoOf V), (`a, sa[3]!), (`c, c), (`K, K),
      (`t, sa[4]!), (`v, x), (`A, mkNatLit A)]
      [.pf hMb, .hyp, .dec, .hyp, .fn fun t => admitsP t, .fn fun t => hypOrDec t, .arith, .rfl,
        .arith, .arith]).run' st
    return pf
  let (pf, _) ← use ``SEff.apply_store_ex [(`V, V), (`vs, vsOf V S j), (`m, m), (`P, P), (`F, F),
    (`lbl, lbl), (`pc, pc)] [.kd hF, .kd hP, .rfl, .pf hv, .pf hp, .fn fun t => k t]
  return pf

/-- Effects `es` from memory `m` (`none`: any memory, then only loads): `∃ M', fold = .ok M'`,
on the values of `S`'s nodes before node `j` (all for `none`). -/
partial def foldEx (V S : Expr) (j : Option Nat) : List Expr → Option Expr → M Expr
  | [], some m => do
    return (← use ``SEff.foldlM_nil_ex [(`V, V), (`vs, vsOf V S j)] [.pf m]).1
  | es, none => throwError "mojo_obl: {es.length} effects on an unknown memory"
  | e :: es, some m => do
    let e ← kdeep e 2
    if e.isAppOf ``SEff.store then
      let h ← effStore V S e m j
      let h' ← withLocalDeclD `m (mkConst ``Mem) fun m1 => do
        mkLambdaFVars #[m1] (← foldAny V S j es m1)
      return (← use ``SEff.foldlM_cons_all [] [.pf h, .pf h']).1
    let (h, m1) ← effLoad V S e m j
    let h' ← foldEx V S j es (some m1)
    return (← use ``SEff.foldlM_cons_ex [] [.pf h, .pf h']).1

/-- Load effects `es` from an arbitrary memory `m`: `∃ M', fold = .ok M'`, on the values of
`S`'s nodes before node `j` (all for `none`). -/
partial def foldAny (V S : Expr) (j : Option Nat) : List Expr → Expr → M Expr
  | [], m => do return (← use ``SEff.foldlM_nil_ex [(`V, V), (`vs, vsOf V S j)] [.pf m]).1
  | e :: es, m => do
    let (h, m1) ← effLoad V S (← kdeep e 2) m j
    let h' ← foldAny V S j es m1
    return (← use ``SEff.foldlM_cons_ex [] [.pf h, .pf h']).1

/-- Effects `es` of summary `S` at `V` run, on the values of `S`'s nodes before node `j` (all of
them for `none`): `∃ M', SEff.run V vs es = .ok M'` (`foldEx` from `V`'s memory). -/
partial def runExAt (V S : Expr) (es : List Expr) (j : Option Nat) : M Expr := do
  let (M0, hM) ← if es.isEmpty then
      pure (mkApp (mkConst ``Valuation.mem) V, ← mkEqRefl (mkApp (mkConst ``Valuation.mem) V))
    else do let (M0, hM, _) ← memOf V; pure (M0, hM)
  let h ← foldEx V S j es (some M0)
  return (← use ``SEff.run_of_fold_ex [(`vs, vsOf V S j)] [.pf hM, .pf h]).1

/-- `S.exit.target V (vals V S.nodes) = some l`. -/
partial def exitP (V S l : Expr) : M Expr := do
  let vs := vsOf V S
  let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
  match x.getAppFnArgs with
  | (``Exit.br, #[d]) => return (← use ``Exit.target_br [(`V, V), (`vs, vs), (`d, d)] []).1
  | (``Exit.cond, #[c, d, e]) =>
    let (v, h) ← opnd V S none c
    -- on a word that is not `Val.ofBool`, by its low bit, which the kernel computes
    if let (``Val.bits, #[_, x]) := v.getAppFnArgs then
      let bit ← kwhnf (← mkAppM ``BitVec.getLsbD #[x, mkNatLit 0])
      let t ← if bit.isConstOf ``Bool.true then pure d
        else if bit.isConstOf ``Bool.false then pure e
        else throwError "mojo_obl: branch on a word of no known low bit{indentExpr x}"
      unless (← natOf t) == (← natOf l) do throwError "mojo_obl: the branch goes to{indentExpr t}"
      let (p, ty) ← use ``Exit.target_cond [(`d, d), (`e, e)] [.pf h]
      let some (_, lhs, _) := ty.eq? | throwError "mojo_obl: branch"
      return hint p (← mkEq lhs (← mkAppM ``Option.some #[l]))
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

/-- **The `phi` operands of the edge of block `l`** (summary `S`, whose exit is a branch into
blocks with `phi`s) from `V`: the block `d` it goes to with `S.exit.dest V (vals V S.nodes) =
some d` (`exitD`), the function `F` with `V.fn = F` (`fnOf`) and the operands of the `phi`s at the
head of block `d` of `F` for the edge (`phiOps`), as a list. Cached in `St.edges`. -/
partial def phiEdge (V l S : Expr) : M (Expr × Expr × Expr × Expr × List Expr) := do
  if let some x := (← get).edges[(V, l, S)]? then return x
  let (d, hd) ← exitD V S none
  let (F, hF) ← fnOf V
  let ops ← kdeep (mkApp3 (mkConst ``phiOps) F l d) 1
  let (``Option.some, #[_, ops]) := ops.getAppFnArgs
    | throwError "mojo_obl: no phi operands for the edge into {d}"
  let res := (d, hd, F, hF, ← klist ops)
  modify fun s => { s with edges := s.edges.insert (V, l, S) res }
  return res

/-- **The values of the `phi` operands `ops`** of an edge out of summary `S` from `V`, in the
edge's scope, `A` the valuation after the block and `frame` the frame at its end
(`Valuation.afterWith c` and `Valuation.frameAtWith c`, or `Valuation.after` and
`Valuation.frameAt`): each operand's register, value and `evalV` equation, for a register of `A`
(`evalV_loc`), an integer constant of a natural number (`evalV_int_ofNat`) or a float constant
(`evalV_float` and the kernel's `floatLit`), and `evalOps … ops = .ok xs` of them all
(`evalOps_cons`). Cached in `St.phis`. -/
partial def phiVals (V S A frame : Expr) (ops : List Expr) :
    M (Array (Expr × Expr × Expr) × Expr) := do
  if let some x := (← get).phis[(V, S, A, frame)]? then return x
  let s ← mkAppM ``Ctx.scope #[mkApp (mkConst ``Valuation.ctx) V,
    mkApp (mkConst ``Valuation.mem) A, frame,
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
    | (``Value.float, #[lit]) =>
      let (``Ty.fp, #[ft]) := (← kdeep t 1).getAppFnArgs | throwError "mojo_obl: phi type"
      let (xv, hl) ← flitOf ft lit
      let (p, _) ← use ``evalV_float [(`s, s), (`ft, ft), (`lit, lit), (`x, xv)] [.pf hl]
      items := items.push (o, xv, p)
    | _ => throwError "mojo_obl: phi operand{indentExpr v}"
  let mut hxs := (← use ``evalOps_nil [] [.pf s]).1
  for (o, _, p) in items.reverse do
    hxs := (← use ``evalOps_cons [(`o, o)] [.pf p, .pf hxs]).1
  modify fun st => { st with phis := st.phis.insert (V, S, A, frame) (items, hxs) }
  return (items, hxs)

/-- **Register `r` after the edge of block `l`** (summary `S`) from `V`: `Valuation.after`'s for
a `br` or a conditional branch (`Valuation.into_regs_br`, `Valuation.into_regs_cond`); for a
branch into blocks with `phi`s, the value of the last `phi` that sets `r`, from the operands'
values in the edge's scope (`Valuation.into_regs_phi`, `phiVals`), else `Valuation.after`'s,
with no operand evaluated (`Valuation.intoWith_regs_phi_ne`). -/
partial def intoReg (V l S : Expr) (r : Nat) (c? : Option Expr) : M (Expr × Expr) := do
  -- `Valuation.intoWith c` from `Valuation.afterWith c`, or `Valuation.into` from `after`
  let (A, frame, wc) := match c? with
    | some c => (mkApp3 (mkConst ``Valuation.afterWith) c V S,
        mkApp4 (mkConst ``Valuation.frameAtWith) c V l S, [(`c, c)])
    | none => (mkApp2 (mkConst ``Valuation.after) V S, mkApp3 (mkConst ``Valuation.frameAt) V l S,
        [])
  let lem (n n' : Name) := if c?.isSome then n' else n
  let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
  let named := [(`V, V), (`l, l), (`S, S), (`r, mkNatLit r)] ++ wc
  match x.getAppFnArgs with
  | (``Exit.br, _) =>
    let (_, h) ← regOf A r
    let (p, t) ← use (lem ``Valuation.into_regs_br ``Valuation.intoWith_regs_br) named
      [.rfl, .pf h]
    return (← valOf t, p)
  | (``Exit.cond, _) =>
    let (_, h) ← regOf A r
    let (p, t) ← use (lem ``Valuation.into_regs_cond ``Valuation.intoWith_regs_cond) named
      [.rfl, .pf h]
    return (← valOf t, p)
  | (``Exit.phi, _) =>
    let (d, hd, F, hF, ops) ← phiEdge V l S
    let some_ (v : Expr) := mkSome (mkConst ``Val) v
    unless ← phiSets ops r do
      -- no `phi` sets `r`: `A`'s, with no operand evaluated
      let (xv, h) ← regOf A r
      let c := c?.getD (mkConst ``Bool.false)
      let (p, _) ← use ``Valuation.intoWith_regs_phi_ne
        [(`c, c), (`V, V), (`l, l), (`S, S), (`F, F), (`d, d), (`r, mkNatLit r), (`v, ← some_ xv)]
        [.rfl, .pf hd, .kd hF, .rfl, .dec, .kd h]
      let W := match c? with
        | some c => mkApp4 (mkConst ``Valuation.intoWith) c V l S
        | none => mkApp3 (mkConst ``Valuation.into) V l S
      return (xv, hint p (← mkEq (mkApp2 (mkConst ``Valuation.regs) W (mkNatLit r)) (← some_ xv)))
    let (items, hxs) ← phiVals V S A frame ops
    let (p, t) ← use (lem ``Valuation.into_regs_phi ``Valuation.intoWith_regs_phi)
      ([(`V, V), (`l, l), (`S, S), (`F, F), (`d, d)] ++ wc)
      [.rfl, .pf hd, .kd hF, .rfl, .pf hxs, .pf (mkNatLit r)]
    let rhs ← rhsOf t
    let mut last : Option Expr := none
    for (o, xv, _) in items do
      if let (``Option.some, #[_, o]) := (← kwhnf o).getAppFnArgs then
        if (← natOf o) == r then last := some xv
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

/-- **The `fmul contract` operands of register `r`** at valuation `V`: `(p, V.prods r = p)`.
After a block with or without `fmul contract` (`Valuation.afterWith c`, and `Valuation.after` as
`Valuation.afterWith false`): for a register the block sets, none without `fmul contract`
(`Valuation.afterWith_prods_off`) or for an entry with no factors
(`Valuation.afterWith_prods_unfactored`), else the values of its factors
(`Valuation.afterWith_prods_factors`, `opnd`); for another register, those before the block
(`Valuation.afterWith_prods_none`). After an edge (`Valuation.intoWith c`, and `Valuation.into`
as `Valuation.intoWith false`): those after the block for a branch
(`Valuation.intoWith_prods_br`, `Valuation.intoWith_prods_cond`); for a branch into blocks with
`phi`s, none at a `phi`'s register that has none after the block, with no operand evaluated
(`Valuation.intoWith_prods_phi_none`), else none at a `phi`'s register, whose operands have values
(`Valuation.intoWith_prods_phi`, `phiVals`), and those after the block at another
(`Valuation.intoWith_prods_phi_ne`). After a collective call (`Valuation.resume V S r d`): none
at the call's register `r` when `d.1 = some v` by a hypothesis (`Valuation.resume_prods_self`),
else those of `V.afterWith true S` (`Valuation.resume_prods_ne`). At the
valuation under `after`s and `into`s, a hypothesis on the entry frame's operands (`f.prods r`
of `Valuation.entry c k m f`) or on the valuation's (`V.prods r`), else the kernel's reduction of
closed ones. For every program; an error when they are not known. -/
partial def prodOf (V : Expr) (r : Nat) : M (Expr × Expr) := do
  let R := mkNatLit r
  let ty (p : Expr) : MetaM Expr := mkEq (mkApp2 (mkConst ``Valuation.prods) V R) p
  -- a lemma's proof, at `V.prods r`
  let done (pt : Expr × Expr) : M (Expr × Expr) := do
    let p ← rhsOf pt.2
    return (p, hint pt.1 (← ty p))
  let ff := mkConst ``Bool.false
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', S]) =>
    let (p, h) ← prodOf (mkApp3 (mkConst ``Valuation.afterWith) ff V' S) r
    return (p, hint h (← ty p))
  | (``Valuation.into, #[V', l, S]) =>
    let (p, h) ← prodOf (mkApp4 (mkConst ``Valuation.intoWith) ff V' l S) r
    return (p, hint h (← ty p))
  | (``Valuation.afterWith, #[c, V', S]) =>
    let named := [(`V, V'), (`S, S), (`r, R)]
    match (← kdeep (← mkAppM ``List.lookup #[R, mkApp (mkConst ``Summary.regs) S]) 2).getAppFnArgs
    with
    | (``Option.some, #[_, x]) =>
      let named := named ++ [(`x, x)]
      if (← kwhnf c).isConstOf ``Bool.false then
        return ← done (← use ``Valuation.afterWith_prods_off named [.rfl])
      let fs ← kdeep (mkApp2 (mkConst ``SVal.factors) (mkApp (mkConst ``Summary.nodes) S) x) 2
      match fs.getAppFnArgs with
      | (``Option.some, #[_, ab]) =>
        let (a, b) ← kpair ab
        let (_, ha) ← opnd V' S none a
        let (_, hb) ← opnd V' S none b
        done (← use ``Valuation.afterWith_prods_factors (named ++ [(`a, a), (`b, b)])
          [.rfl, .rfl, .pf ha, .pf hb])
      | _ => done (← use ``Valuation.afterWith_prods_unfactored ((`c, c) :: named) [.rfl, .rfl])
    | _ =>
      let (_, h) ← prodOf V' r
      done (← use ``Valuation.afterWith_prods_none ((`c, c) :: named) [.rfl, .pf h])
  | (``Valuation.resume, #[V', S, r', d]) =>
    let named := [(`V, V'), (`S, S), (`d, d)]
    match ← resumeAt r' d r with
    | some (v, h) =>
      done (← use ``Valuation.resume_prods_self (named ++ [(`r, R), (`v, v)]) [.pf h])
    | none =>
      let (_, h) ← prodOf (mkApp3 (mkConst ``Valuation.afterWith) (mkConst ``Bool.true) V' S) r
      done (← use ``Valuation.resume_prods_ne (named ++ [(`r, r'), (`s, R)]) [.dec, .pf h])
  | (``Valuation.intoWith, #[c, V', l, S]) =>
    let A := mkApp3 (mkConst ``Valuation.afterWith) c V' S
    let named := [(`c, c), (`V, V'), (`l, l), (`S, S), (`r, R)]
    let x ← kdeep (mkApp (mkConst ``Summary.exit) S) 2
    match x.getAppFnArgs with
    | (``Exit.br, _) =>
      let (_, h) ← prodOf A r
      done (← use ``Valuation.intoWith_prods_br named [.rfl, .pf h])
    | (``Exit.cond, _) =>
      let (_, h) ← prodOf A r
      done (← use ``Valuation.intoWith_prods_cond named [.rfl, .pf h])
    | (``Exit.phi, _) =>
      let (d, hd, F, hF, ops) ← phiEdge V' l S
      let named := named ++ [(`F, F), (`d, d)]
      if ← phiSets ops r then
        -- none after the block stays none, with no operand evaluated
        let s ← (saveState : MetaM Meta.SavedState)
        try
          let (p, h) ← prodOf A r
          let (``Option.none, _) := (← kwhnf p).getAppFnArgs | failure
          return ← done (← use ``Valuation.intoWith_prods_phi_none named
            [.rfl, .pf hd, .kd hF, .rfl, .kd h])
        catch _ => (s.restore : MetaM Unit)
        let frame := mkApp4 (mkConst ``Valuation.frameAtWith) c V' l S
        let (_, hxs) ← phiVals V' S A frame ops
        done (← use ``Valuation.intoWith_prods_phi named
          [.rfl, .pf hd, .kd hF, .rfl, .pf hxs, .dec])
      else
        let (_, h) ← prodOf A r
        done (← use ``Valuation.intoWith_prods_phi_ne named
          [.rfl, .pf hd, .kd hF, .rfl, .dec, .pf h])
    | _ => throwError "mojo_obl: exit{indentExpr x}"
  | _ =>
    -- the entry frame's operands, or the valuation's
    let a := match baseOf V with
      | (_, _, some f) => mkApp2 (mkConst ``Frame.prods) f R
      | _ => mkApp2 (mkConst ``Valuation.prods) V R
    let (p, h) ← eqHyp a
    if h.isFVar then return (p, hint h (← ty p))
    let a ← instantiateMVars a
    if a.hasFVar || a.hasMVar then
      throwError "mojo_obl: register {r} has no known fmul contract operands"
    let p ← kdeep a 3
    return (p, hint (← krfl a p) (← ty p))

end

/-- Effects `es` of summary `S` at `V` run: `∃ M', SEff.run V (vals V S.nodes) es = .ok M'`
(`foldEx` from `V`'s memory). -/
def runEx (V S : Expr) (es : List Expr) : M Expr :=
  runExAt V S es none

/-- The goal `ty`, left open and logged (an error in strict mode), in the local context without
the parts of the context's hypotheses (`withFacts`), so that it has the hypotheses the tactic was
called with, and those the goal's own binders introduce (with their parts). -/
def openGoal (ty : Expr) : M Expr := do
  let st ← get
  if st.strict then throwError "{st.name}: no proof of{indentExpr ty}"
  let lctx ← getLCtx
  let lctx := if ty.hasAnyFVar st.hidden.contains then lctx
    else st.hidden.foldl (·.erase ·) lctx
  let g ← mkFreshExprMVarAt lctx (← getLocalInstances) ty .syntheticOpaque
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

/-- Proof `k` of `ty`, else, when `ty` is closed, `closedDec`. -/
def orClosed (ty : Expr) (k : M Expr) : M Expr := do
  try k catch e =>
    dbg e.toMessageData
    try closedDec ty catch _ => throw e

/-- Obligation `d` of summary `S` at `V`. A `mem` obligation whose check on metadata
(`SEff.runMeta`) is closed is proved by the kernel's evaluation of that check
(`SEff.holds_of_runMeta_toBool`) when it passes, else by `runEx`. -/
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
    -- a closed obligation: the check on metadata, which the kernel evaluates writing no byte
    let vs := vsOf V S
    let r ← instantiateMVars (mkApp3 (mkConst ``SEff.runMeta) V vs es)
    if !r.hasFVar && !r.hasMVar then
      let t ← mkEq (← mkAppM ``Except.toBool #[r]) (mkConst ``Bool.true)
      if let some p ← try some <$> closedDec t catch _ => pure none then
        return mkApp4 (mkConst ``SEff.holds_of_runMeta_toBool) V vs es p
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

/-- The literal `K` of a statement `∀ i : Nat, i < K → P i` (binder type `a`, body `b`) whose
`P` does not use the proof of `i < K`. -/
def belowLit (a b : Expr) : MetaM (Option Nat) := do
  unless a.isConstOf ``Nat do return none
  let .forallE _ lt body _ := b | return none
  if body.hasLooseBVar 0 then return none
  let (``LT.lt, #[_, _, i, K]) := lt.getAppFnArgs | return none
  unless i == .bvar 0 && !K.hasLooseBVars do return none
  try some <$> natOf K catch _ => return none

/-- `Valuation.into V l S`, or with `fmul contract` flag `c` `Valuation.intoWith c V l S`. -/
def intoV (c? : Option Expr) (V l S : Expr) : Expr :=
  match c? with
  | some c => mkApp4 (mkConst ``Valuation.intoWith) c V l S
  | none => mkApp3 (mkConst ``Valuation.into) V l S

/-- `WalkWith c V ps` (with flag `c`, else `WalkWith false V ps`): each block's obligations and
exit (`Exit.dest`), proved or left open, the valuation of each block after the first
`Valuation.intoWith c` (without the flag `Valuation.into`) of the one before. -/
partial def walk (c? : Option Expr) (V ps : Expr) : M Expr := do
  let c := c?.getD (mkConst ``Bool.false)
  let wc := [(`c, c)]
  match ← kcons ps with
  | none => return mkApp2 (mkConst ``WalkWith.nil') c V
  | some (hd, tl) =>
    let (l, rest) ← kpair hd
    let (ds, S) ← kpair rest
    match ← kcons tl with
    | none =>
      let h ← obls V S ds
      return (← use ``WalkWith.one ([(`V, V), (`l, l), (`ds, ds), (`S, S)] ++ wc) [.kd h]).1
    | some (hd', tl') =>
      let (l', rest') ← kpair hd'
      let (ds', S') ← kpair rest'
      let h1 ← obls V S ds
      let ty2 ← mkEq
        (mkApp3 (mkConst ``Exit.dest) V (vsOf V S) (mkApp (mkConst ``Summary.exit) S))
        (← mkSome (mkConst ``Nat) l')
      let h2 ← attempt ty2 (do return (← exitD V S (some l')).2)
      let h3 ← walk c? (intoV c? V l S) tl
      return (← use ``WalkWith.cons2 ([(`V, V), (`l, l), (`l', l'), (`ds, ds), (`ds', ds'),
        (`S, S), (`S', S'), (`ps, tl')] ++ wc) [.kd h1, .kd h2, .kd h3]).1

/-- The last block of the path `(l, _, S) :: E` from `V` (`Valuation.lastWith c` with flag `c`,
else `Valuation.lastWith false`): its entry valuation, built with `Valuation.intoWith c` (without
the flag `Valuation.into`), its label and its summary. -/
partial def lastIOf (c? : Option Expr) (V l S E : Expr) : MetaM (Expr × Expr × Expr) := do
  match ← kcons E with
  | none => return (V, l, S)
  | some (hd, tl) =>
    let (l', rest) ← kpair hd
    let (_, S') ← kpair rest
    lastIOf c? (intoV c? V l S) l' S' tl

/-- Valuation `V` as `Valuation.after`s and `Valuation.into`s (with or without `fmul contract`:
`Valuation.afterWith`, `Valuation.intoWith`) of an entry valuation or of another valuation: a
loop's round (`Valuation.round`, `Valuation.roundWith`) by the edges of its path, an iterate
`f^[k] a` with a literal `k` by `k` applications, and another constant by its definition. The
kernel checks the result equal to `V`. -/
partial def normV (V : Expr) : MetaM Expr := do
  match V.getAppFnArgs with
  | (``Valuation.after, #[V', S]) => return mkApp2 (mkConst ``Valuation.after) (← normV V') S
  | (``Valuation.into, #[V', l, S]) => return mkApp3 (mkConst ``Valuation.into) (← normV V') l S
  | (``Valuation.afterWith, #[c, V', S]) =>
    return mkApp3 (mkConst ``Valuation.afterWith) c (← normV V') S
  | (``Valuation.intoWith, #[c, V', l, S]) =>
    return mkApp4 (mkConst ``Valuation.intoWith) c (← normV V') l S
  | (``Valuation.entry, _) => return V
  | (``Valuation.resume, #[V', S, r, d]) =>
    return mkApp4 (mkConst ``Valuation.resume) (← normV V') S r d
  | (``Valuation.round, #[h, S, B, W]) =>
    let (W', l', S') ← lastIOf none (← normV W) h S B
    return mkApp3 (mkConst ``Valuation.into) W' l' S'
  | (``Valuation.roundWith, #[c, h, S, B, W]) =>
    let (W', l', S') ← lastIOf (some c) (← normV W) h S B
    return mkApp4 (mkConst ``Valuation.intoWith) c W' l' S'
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

/-- `Edge h p V l ds S E` (or with flag `c`, `EdgeWith c h p V l ds S E`): the path's premises
(`walk`), and the last block's exit goes to `h` (`exitD`) at position `p` (`Exit.pc_of_fn`, the
kernel computing `Exit.pc`). -/
partial def edge (c? : Option Expr) (ty h p V l ds S E : Expr) : M Expr := do
  let V ← normV V
  let ps ← mkAppM ``List.cons #[← mkAppM ``Prod.mk #[l, ← mkAppM ``Prod.mk #[ds, S]], E]
  let wty := mkApp3 (mkConst ``WalkWith) (c?.getD (mkConst ``Bool.false)) V ps
  let w ← try walk c? V ps catch e => dbg e.toMessageData; openGoal wty
  let (W, _, S') ← lastIOf c? V l S E
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

/-- The parts of a proof `h` of `t`, each with its type: for `t` that is `a ∧ b` up to reducible
definitions (`whnfR`), or after one unfolding of its head definition (`delta?`, so an invariant
defined as a conjunction), `h.1 : a` and `h.2 : b`; for a structure of propositions (a
precondition or an invariant declared as a `structure`), the projection of each field; for any
other `t`, none (a definition by recursion, as `WalkWith` on a path, is not unfolded). -/
def parts (h t : Expr) : MetaM (Array (Expr × Expr)) := do
  let t ← whnfR t
  let env ← getEnv
  let isPart (t : Expr) : Bool :=
    t.isAppOfArity ``And 2 || t.getAppFn.constName?.any (isStructure env)
  let t ← if isPart t then pure t else
    match ← delta? t with
    | some u => pure (if isPart u.headBeta then u.headBeta else t)
    | none => pure t
  match t.getAppFnArgs with
  | (``And, #[a, b]) =>
    return #[(mkApp3 (mkConst ``And.left) a b h, a), (mkApp3 (mkConst ``And.right) a b h, b)]
  | (n, _) =>
    unless isStructure env n && (← isProp t) do return #[]
    let mut out := #[]
    for fld in getStructureFields env n do
      try
        let p ← mkProjection h fld
        let pt ← inferType p
        if ← isProp pt then out := out.push (p, pt)
      catch _ => pure ()
    return out

/-- Proof `k` of the goal under hypothesis `h : t`, with the parts of `t` (`parts`: conjuncts, the
fields of a structure of propositions) as hypotheses too, each with its own parts in turn: the
proof is `(fun h₁ … hₙ => _) p₁ … pₙ` for the parts `pᵢ`, so that the hypotheses found by type
(registers, the function and program, buffers, the launch) and those of `omega` may come from an
invariant or a precondition given as a conjunction or a structure. With `hide`, the parts are
left out of the goals left open (`openGoal`). For every hypothesis. -/
partial def withParts (h t : Expr) (k : M Expr) (hide : Bool := false) : M Expr := do
  let ps ← parts h t
  if ps.isEmpty then return ← k
  let ns ← ps.mapM fun _ => mkFreshUserName `h
  withLocalDeclsD ((ns.zip ps).map fun (n, _, t) => (n, fun _ => pure t)) fun xs => do
    if hide then modify fun s => { s with hidden := s.hidden ++ xs.map (·.fvarId!) }
    let pf ← (xs.zip ps).foldr (fun (x, _, t) k => withParts x t k hide) k
    return mkAppN (← mkLambdaFVars xs pf) (ps.map (·.1))

/-- Proof `k` with the parts of each hypothesis of `ds` as hypotheses too (`withParts`), left
out of the goals left open. -/
def withHyps (ds : List LocalDecl) (k : M Expr) : M Expr :=
  ds.foldr (fun d k => withParts d.toExpr d.type k true) k

/-- Proof `k` with the parts of every hypothesis of the local context as hypotheses too
(`withHyps`, after the hypotheses themselves, so a hypothesis found by type is a whole one when
one fits; the parts are no hypotheses of the goals left open), and the launch facts
(`launchFacts`) of that context as the state's `facts`. -/
def withFacts (k : M Expr) : M Expr := do
  let ds := (← getLCtx).decls.toList.filterMap id |>.filter (!·.isImplementationDetail)
  withHyps ds do
    let facts ← launchFacts
    modify fun s => { s with facts }
    k

/-- A proof of `ty`: conjunctions, implications (each hypothesis with its parts, `withParts`),
statements for every number below a literal, other universal statements (for every value of the
variable: `∀ i < K, P i` for a `K` that is no literal, as a runtime trip count, is `P i` for
every `i` with `i < K` among the hypotheses), paths (with or without `phi`s, with or
without `fmul contract`), a loop's edges and rounds (`Edge`, `Round`, `EdgeWith`, `RoundWith`),
obligations and exits. -/
partial def prove (ty : Expr) : M Expr := do
  -- a goal's annotations (as `have` leaves on the goal after it) are no part of its form
  let ty := (← instantiateMVars ty).consumeMData
  match ty.getAppFnArgs with
  | (``And, #[a, b]) => return mkApp4 (mkConst ``And.intro) a b (← prove a) (← prove b)
  | (``WalkWith, #[c, V, ps]) =>
    try return hint (← walk (some c) (← normV V) ps) ty
    catch e => dbg e.toMessageData; openGoal ty
  | (``Edge, #[h, p, V, l, ds, S, E]) =>
    try edge none ty h p V l ds S E
    catch e => dbg e.toMessageData; openGoal ty
  | (``EdgeWith, #[c, h, p, V, l, ds, S, E]) =>
    try edge (some c) ty h p V l ds S E
    catch e => dbg e.toMessageData; openGoal ty
  | (``Round, #[h, p, ds, S, B, V]) =>
    try edge none ty h p V h ds S B
    catch e => dbg e.toMessageData; openGoal ty
  | (``RoundWith, #[c, h, p, ds, S, B, V]) =>
    try edge (some c) ty h p V h ds S B
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
        else
          -- for every `x`: a bound `K` that is no literal (`∀ i < K`), a valuation, a block
          withLocalDecl n bi a fun x => do mkLambdaFVars #[x] (← prove (b.instantiate1 x))
      else
        withLocalDecl n bi a fun h => do mkLambdaFVars #[h] (← withParts h a (prove b))
    | _ => openGoal ty

/-- **`mojo_obl` on goal `g`**: the goals it leaves open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let ty ← instantiateMVars (← g.getType)
    let (p, st) ← (withFacts (prove ty)).run {}
    g.assign p
    for m in st.dbgs do logInfo m
    return st.opens

end Obl

/-- **`mojo_obl`** proves the premises of a path summary: a goal `WalkWith c V ps` for a path `ps`
of summaries, with or without a `fmul contract` setting `c` (`MojoProof.Sym.Kernel` asks one per
thread), its blocks' obligations `∀ d ∈ ds, d.Holds V vs`, one obligation `d.Holds V vs` and an
exit `S.exit.target V vs = some l` or `S.exit.dest V vs = some l`, and a loop's `Edge` and
`Round` and their forms `EdgeWith` and `RoundWith`; universal statements (`∀ i < K, P i` one
`i` at a time for a literal `K`, any other for an arbitrary value, so `∀ i < K` for a runtime `K`
with `i < K` as a hypothesis);
and conjunctions and implications of them, each hypothesis (of the context or the goal) with its
parts, its conjuncts and the fields of a structure of propositions. `V` is a valuation
under `after`s, `into`s and `Valuation.resume`s (a thread resumed after a collective call: the
call's register the value a hypothesis `d.1 = some v` gives the delivery `d`, the other registers
those after the segment, the memory `d.2`) over an entry valuation
`Valuation.entry c k m f`, or any other; rounds `Valuation.round`, iterates `f^[k]` with a literal
`k` and other constants are first rewritten to them.

It evaluates the nodes of each block that are read, each once, from the hypotheses: the
registers (`f.regs r = some v` of an entry frame, else `V.regs r = some v`), the function and
program (`f.fn = F` or `V.fn = F`, `c.prog = P` or `V.ctx.prog = P`), the launch
(`c.env = L.env k`, `L.Valid`, and for the 1-D index `Launch.index_oneDim`'s hypotheses), struct
loads (`m.load … = .ok v`), and the buffers the
pointers point into (`m.Buffer`, or `m.BufferIn s c size al o w` for a buffer of address space
`s` owned by `o` with `o.admits c.who = true` unless `o` is `.all`; `Mem.Fits` or its unfolding
for a generic pointer, `∃ blk, m.blocks c = some blk ∧ blk.addr + size ≤ 2 ^ (l.ptr s).1` for
one of the buffer's space `s`; `m.Holds`, the alignment `A ∣ al`, a hypothesis or two
literals). It evaluates the nodes of integer `add`, `mul` and `sub` (under the no-wrap bounds
`omega` proves, or without `nuw` and `nsw` modulo `2 ^ w`), `udiv` and `sdiv` by a positive or
negative word, `xor` and `ashr` by `w - 1` of a `xor` (0 or all ones by the sign bit),
the comparisons `slt`, `ult`, `eq` (also of words `omega` does not compare, as an equality of
residues), `ne` and `sge`, `and` of two booleans (the boolean of the conjunction), `select` (the
operand a boolean picks, when `omega` decides it, else of two words the word of an `if`, and of
two equal operands their value), `llvm.smax`, casts (`sext`
of any word: its sign extension), `extractvalue`, a global's pointer (`SNode.globalAt`, from a
hypothesis `c.globals g = some p`), `bitcast` between scalar types of one width (`SNode.castAt`:
the operand's word), `getelementptr` (into a buffer by an index
`omega` bounds or by `r * S + k` into an `R × S` matrix's buffer, else by any word some value, a
pointer or poison, by `gep_buffer_ok`), loads (of an element of a 1-D tensor or of a row-major
matrix in a buffer), loads after a block's stores (`SNode.loadAfter`, by the effects from the
last: a `load` effect passed by, a `store` at a pointer of the same value of an integer word or
a `Val.ofFloat` float the stored value, a `store` at a pointer `omega` proves apart passed by, and
with none left the load from the memory), special-register calls (a register equal by a
hypothesis to another number, `ntid.x = 1024`, as that number's word), the lane-number call
(`%laneid`, below 32 by a hypothesis or `Launch.laneid_lt`), float operators (with
`fmul contract` factors under `c = true`; without, an operand's factors `none` by the kernel or a
hypothesis `f.prods r = none`) and float constants (the literal's value by the kernel's
evaluation of `floatLit`), on words `BitVec.ofNat w K` whose bounds `omega` proves (after
splitting the `if`s of the bound), with integer constants of natural numbers and of negative ones
(`-(k + 1)` as the word of `2 ^ w - (k + 1)`); a node of another kind gets no value, and a node
with a hypothesis `(vals V S.nodes)[j]? = some (.ok v)`, or one with premises on registers, their
`fmul contract` operands and nodes at `V` that the evaluation proves, gets that value
(`Obl.nodeHyp`). It proves the exits `br` and a conditional branch on a comparison whose direction
`omega` proves or on a word whose low bit the kernel computes, and a branch into blocks with `phi`s
on such a comparison or on a constant word; after such an edge, the registers its `phi`s set get
their operands' values (registers, integer constants of natural numbers, or float constants), the
others keep theirs, and the position the edge enters at is computed from the function. An obligation
on a closed valuation that no lemma reaches is decided by the kernel. Each obligation or exit it
does not prove (one that needs a node without a value, a branch `omega` does not decide, a position
of an unknown function) is left as a goal, and logged as `mojo_obl: open goal`; a goal of another
form is left open whole. -/
syntax (name := mojoObl) "mojo_obl" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_obl` on the main goal. -/
@[tactic mojoObl] def evalMojoObl : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Obl.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
