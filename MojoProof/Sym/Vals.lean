import MojoProof.Sym.Obl

/-!
# A block's node values, and the tactic mojo_vals

A block summary's node values `vals V S.nodes` (MojoProof/Sym/Term.lean) are what the lemmas about a
block's effects and exit take: the `Elem` steps (`Elem.Steps`, MojoProof/Sym/Ops.lean) and `Ret`
(MojoProof/Sym/Path.lean) read the loaded values, the addresses and the stored value from them.
mojo_vals proves a goal `vals V S.nodes = [r₀, …, rₙ₋₁]` for a concrete summary `S`, entry by entry,
with mojo_obl's node evaluation (MojoProof/Sym/Obl.lean), so with no hand step.

The lemmas:

* `drop_of_getElem?`, for every list: a list from entry `i` on is entry `i` followed by the list
  from `i + 1` on; from core's List.drop_eq_nil_of_le at the length and List.drop_zero, the values
  of a table are the list of their entries;

## The tactic

mojo_vals (syntax `mojoVals`, elaborator `evalMojoVals`, method `Vals.run`) closes goals
`vals V S.nodes = ws`, `ws` a list of as many entries as `S` has nodes, and goals
`nd.eval V (vals V (S.nodes.take j)) = r` for node `j` of `S` (which it leaves open when it does
not prove them), for every valuation `V` under `after`s (`Valuation.entry c k m f` or any other)
and concrete summary `S`. For node `j` and entry `rⱼ`:

1. when `rⱼ` is `.ok v`, it evaluates the node by mojo_obl's dispatch on the node's constructor
   (`Obl.nodeEval`: loads, `extractvalue`, casts, integer operators and comparisons, special
   registers, `getelementptr`, float operators, float constants), with the facts found by type
   (the registers, function, program and environment of `V`, struct loads, buffers, `Mem.Fits`,
   `Mem.Holds`, alignments, the launch), and proves the value it gets equal to `v`
   (`Vals.conv`);
2. otherwise it reads `rⱼ` as the semantics' operation of the node on its operands' values
   (`icmpV` by `SNode.eval_icmpV`, `intBin`, `intCast`, `extractV` by `SNode.eval_bin`,
   `SNode.eval_cast`, `SNode.eval_extract`), and a float constant's as its literal's value
   (`floatLit` by `SNode.eval_flit`);
3. it checks the node's proof by the kernel; if a step fails, the node's equation stays a goal,
   logged as `mojo_vals: open goal (node j)`, and the later nodes read its entry `rⱼ`.

`Vals.conv` proves two values equal by syntactic equality, by congruence argument by argument (a
value followed by proofs about it, as `Fin.mk`, by `Vals.congrDep`), by an `if` on either side whose
condition `omega` decides (`Vals.ifStep`, so `vadd.bytes`), by kernel defeq, by the first subterm
`decide p` that `omega` decides, past those it decides neither way (`Vals.decStep`, so a
comparison's `Val.ofBool (decide (i < n))`), by the local equations on the subterms of either side
(`Vals.norm`), and on `Nat` and `Int` by `omega` from the local context and the launch facts (so
`k * 4 = 4 * k`, `V.k + 6 = 23` from `V.k = 17`). With `set_option mojo_obl.debug true` it logs why
a node stays open. Tests: MojoProofTest/Vals.lean (`vadd_vals0` and `vadd_vals1`, the node values
of `vector_addition`'s blocks `%4` and `%21`, for every valid launch and thread, an open-goal twin,
and `decStep` past a `decide` that `omega` does not decide).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A list from entry `i` on**: for every list `l`, if entry `i` of `l` is `t` and `l` from
`i + 1` on is `ws`, then `l` from `i` on is `t :: ws`. -/
theorem drop_of_getElem? {α : Type} {l ws : List α} {i : Nat} {t : α} (h : l[i]? = some t)
    (h' : l.drop (i + 1) = ws) : l.drop i = t :: ws := by
  obtain ⟨hi, e⟩ := List.getElem?_eq_some_iff.1 h
  rw [List.drop_eq_getElem_cons hi, e, h']

namespace Vals

open Lean Meta Elab Tactic Obl

/-- The type `Except Fault Val` of a node's value. -/
def resTy : Expr := mkApp2 (mkConst ``Except [Level.zero, Level.zero]) (mkConst ``Fault)
  (mkConst ``Val)

/-- The `v` of `.ok v`. -/
def okVal? (t : Expr) : Option Expr :=
  match t.getAppFnArgs with
  | (``Except.ok, #[_, _, v]) => some v
  | _ => none

/-- Whether `t` is `Nat` or `Int`. -/
def numTy (t : Expr) : MetaM Bool := do
  let t ← whnfR t
  return t.isConstOf ``Nat || t.isConstOf ``Int

/-- **An `if` taken**: `e` whose head definition unfolds (one step) to `dite c t e'` or
`ite c t e'` with `c` or `¬ c` proved by `omega`, as `(r, e = r)`, `r` the branch taken. -/
def ifStep (e : Expr) : M (Option (Expr × Expr)) := do
  let some n := e.getAppFn.constName? | return none
  unless (← getEnv).find? n matches some (.defnInfo _) do return none
  let some u ← unfoldDefinition? e | return none
  let u := u.headBeta
  let take (pos neg : Name) (c inst α t f : Expr) (dep : Bool) : M (Option (Expr × Expr)) := do
    let arg (h : Expr) (b : Expr) := if dep then (mkApp b h).headBeta else b
    try
      let hc ← arith c
      let r := arg hc t
      let lv ← getLevel α
      return some (r, hint (mkAppN (mkConst pos [lv]) #[c, inst, hc, α, t, f]) (← mkEq e r))
    catch _ =>
      try
        let hc ← arith (mkNot c)
        let r := arg hc f
        let lv ← getLevel α
        return some (r, hint (mkAppN (mkConst neg [lv]) #[c, inst, hc, α, t, f]) (← mkEq e r))
      catch _ => return none
  match u.getAppFnArgs with
  | (``dite, #[α, c, inst, t, f]) => take ``dif_pos ``dif_neg c inst α t f true
  | (``ite, #[α, c, inst, t, f]) => take ``if_pos ``if_neg c inst α t f false
  | _ => return none

/-- The distinct subterms `decide p` of `e` with no bound variables, in the order `Expr.find?`
visits them (a term before its subterms, a function before its argument). -/
def decides (e : Expr) : MetaM (Array Expr) := do
  let r ← IO.mkRef (#[] : Array Expr)
  e.forEachWhere (fun x => x.isAppOfArity ``Decidable.decide 2 && !x.hasLooseBVars)
    fun d => r.modify (·.push d)
  r.get

/-- **A comparison decided**: the first subterm `decide p` of `e` (with no bound variables, in
the order of `decides`) whose `p` or `¬ p` `omega` proves, as `(e', e = e')`, `e'` with it `true`
or `false` (so the `Val.ofBool (decide (x < y))` of an `icmp slt` or `ult` of the words of
naturals is `.bits 1 1` when `x < y`); a `decide p` that `omega` decides neither way is skipped
for the next; `none` when `omega` decides none of them. -/
def decStep (e : Expr) : M (Option (Expr × Expr)) := do
  for d in ← decides e do
    let (p, inst) := (d.appFn!.appArg!, d.appArg!)
    let r ← try some <$> do
        pure (mkConst ``Bool.true, mkApp3 (mkConst ``decide_eq_true) p inst (← arith p))
      catch _ => try some <$> do
          pure (mkConst ``Bool.false, mkApp3 (mkConst ``decide_eq_false) p inst
            (← arith (mkNot p)))
        catch _ => pure none
    let some (b, h) := r | continue
    let body ← kabstract e d
    let e' := body.instantiate1 b
    let h ← mkCongrArg (.lam `x (mkConst ``Bool) body .default) h
    return some (e', hint h (← mkEq e e'))
  return none

/-- `f xs x ps = f xs y qs` from `h : x = y`, for proofs `ps` and `qs` whose types name `x` and `y`
(a value with proofs about it, as `Fin.mk`), by `Eq.ndrec` on `h`. -/
def congrDep (pre x h : Expr) (ps qs : Array Expr) : MetaM Expr := do
  let a := mkAppN (mkApp pre x) ps
  let motive ← withLocalDeclD `z (← inferType x) fun z => do
    let body ← forallBoundedTelescope (← inferType (mkApp pre z)) (some ps.size) fun zs _ => do
      mkForallFVars zs (← mkEq a (mkAppN (mkApp pre z) zs))
    mkLambdaFVars #[z] body
  let m0 ← forallBoundedTelescope (← inferType (mkApp pre x)) (some ps.size) fun zs _ => do
    mkLambdaFVars zs (hint (← mkEqRefl a) (← mkEq a (mkAppN (mkApp pre x) zs)))
  return mkAppN (← mkEqNDRec motive m0 h) qs

/-- `e` with its subterms rewritten by the local equations (`Obl.eqHyp`: the whole term or a
prefix of its application first, then the arguments, to depth `d`): `(e', e = e')`, or `none`
when no hypothesis applies. -/
partial def norm (e : Expr) (d : Nat) : M (Option (Expr × Expr)) := do
  if d == 0 || !e.isApp then return none
  let f := e.getAppFn
  let args := e.getAppArgs
  for i' in [0:args.size] do
    let i := args.size - i'
    let pre := mkAppN f (args.extract 0 i)
    let (r, h) ← eqHyp pre
    if r != pre then
      let rest := args.extract i args.size
      let mut h := h
      for x in rest do h ← mkCongrFun h x
      let e' := mkAppN r rest
      return some (e', hint h (← mkEq e e'))
  let mut h ← mkEqRefl f
  let mut out := #[]
  let mut changed := false
  for x in args do
    let r ← if ← isProof x then pure none else norm x (d - 1)
    match r with
    | some (x', hx) =>
      try
        h ← mkCongr h hx
        out := out.push x'
        changed := true
      catch _ =>
        h ← mkCongrFun h x
        out := out.push x
    | none =>
      h ← mkCongrFun h x
      out := out.push x
  unless changed do return none
  let e' := mkAppN f out
  return some (e', hint h (← mkEq e e'))

mutual

/-- **A proof of `a = b`**, `fuel` bounding the rewrites: by syntactic equality; by congruence,
for one function of as many arguments, each pair of arguments equal (proofs by proof
irrelevance; a value followed by proofs about it by `congrDep`); by an `if` on either side that
`omega` decides (`ifStep`); by kernel equality (not tried on two different constructors); by a
`decide p` on either side that `omega` decides (`decStep`); by the local equations on the
subterms of either side (`norm`); or, on `Nat` and `Int`, by `omega` from the local context and
the launch facts. -/
partial def conv (a b : Expr) (fuel : Nat := 6) : M Expr := do
  let a := (← instantiateMVars a).headBeta
  let b := (← instantiateMVars b).headBeta
  if a == b then return ← mkEqRefl a
  let fa := a.getAppFn
  if fa == b.getAppFn && a.getAppNumArgs == b.getAppNumArgs && a.getAppNumArgs > 0 then
    let s ← (saveState : MetaM Meta.SavedState)
    try return hint (← congr a b fuel) (← mkEq a b)
    catch _ => (s.restore : MetaM Unit)
  if fuel > 0 then
    if let some (b', hb) ← ifStep b then
      return ← mkEqTrans (← conv a b' (fuel - 1)) (← mkEqSymm hb)
    if let some (a', ha) ← ifStep a then return ← mkEqTrans ha (← conv a' b (fuel - 1))
  unless ← rigidNe a b do
    if ← kdefeq a b then return ← krfl a b
  if fuel > 0 then
    if let some (b', hb) ← decStep b then
      return ← mkEqTrans (← conv a b' (fuel - 1)) (← mkEqSymm hb)
    if let some (a', ha) ← decStep a then return ← mkEqTrans ha (← conv a' b (fuel - 1))
    if let some (a', ha) ← norm a 6 then return ← mkEqTrans ha (← conv a' b (fuel - 1))
    if let some (b', hb) ← norm b 6 then
      return ← mkEqTrans (← conv a b' (fuel - 1)) (← mkEqSymm hb)
  if ← numTy (← inferType a) then return ← arith (← mkEq a b)
  throwError "mojo_vals: no proof that{indentExpr a}\nequals{indentExpr b}"

/-- `f xs = f ys` argument by argument (`conv`), for two applications of one function. -/
partial def congr (a b : Expr) (fuel : Nat) : M Expr := do
  let f := a.getAppFn
  let (xs, ys) := (a.getAppArgs, b.getAppArgs)
  let mut h ← mkEqRefl f
  let mut same := true
  for i in [0:xs.size] do
    let (x, y) := (xs[i]!, ys[i]!)
    if x == y || (← isProof x) then
      h ← mkCongrFun h x
      continue
    let hx ← conv x y fuel
    try
      h ← mkCongr h hx
      same := false
    catch ex =>
      -- a value followed by proofs about it
      let (ps, qs) := (xs.extract (i + 1) xs.size, ys.extract (i + 1) ys.size)
      unless same && (← ps.allM fun p => isProof p) do throw ex
      return ← congrDep (mkAppN f (xs.extract 0 i)) x hx ps qs
  return h

end
/-- **Node `nd` (number `j` of `S`) at `V` by its operation**: a proof of
`nd.eval V (vals V (S.nodes.take j)) = t` for `t` the semantics' operation of the node on its
operands' values (`icmpV`, `intBin`, `intCast`, `extractV`), or for a float constant its
literal's value (`floatLit`), up to `conv`. -/
def raw (V S : Expr) (j : Nat) (nd t : Expr) : M Expr := do
  let op (x : Expr) := opnd V S (some j) x
  let vs := vsOf V S (some j)
  match nd.getAppFnArgs with
  | (``SNode.icmp, #[p, w, a, b]) =>
    let (u, ha) ← op a
    let (u', hb) ← op b
    let (P, hP) ← progOf V
    let (Mm, hM, _) ← memOf V
    let h ← conv (mkAppN (mkConst ``icmpV) #[mkApp (mkConst ``Program.layout) P, Mm, p,
      mkApp (mkConst ``Ty.int) w, u, u']) t
    return (← use ``SNode.eval_icmpV [(`V, V), (`vs, vs), (`P, P), (`M, Mm), (`p, p), (`w, w),
      (`r, t)] [.kd hP, .kd hM, .pf ha, .pf hb, .kd h]).1
  | (``SNode.bin, #[bop, fl, w, a, b]) =>
    let (u, ha) ← op a
    let (u', hb) ← op b
    let h ← conv (mkAppN (mkConst ``intBin) #[w, bop, fl, u, u']) t
    return (← use ``SNode.eval_bin [(`op, bop), (`fl, fl), (`w, w), (`r, t)]
      [.pf ha, .pf hb, .kd h]).1
  | (``SNode.cast, #[cop, w, a]) =>
    let (u, ha) ← op a
    let h ← conv (mkAppN (mkConst ``intCast) #[cop, w, u]) t
    return (← use ``SNode.eval_cast [(`op, cop), (`w, w), (`r, t)] [.pf ha, .kd h]).1
  | (``SNode.extract, #[is, a]) =>
    let (u, ha) ← op a
    let h ← conv (mkApp2 (mkConst ``extractV) u is) t
    return (← use ``SNode.eval_extract [(`is, is), (`r, t)] [.pf ha, .kd h]).1
  | (``SNode.flit, #[ft, lit]) =>
    let h ← conv (mkApp2 (mkConst ``floatLit) ft lit) t
    return (← use ``SNode.eval_flit [(`V, V), (`vs, vs), (`ft, ft), (`lit, lit), (`r, t)]
      [.kd h]).1
  | _ => throwError "mojo_vals: node{indentExpr nd}\nis not an operation of{indentExpr t}"

/-- **Node `nd` (number `j` of `S`) at `V` is `t`**: a proof of
`nd.eval V (vals V (S.nodes.take j)) = t`, and the node's value and `nd.eval … = .ok v` when
`Obl.nodeEval` gives them. For `t = .ok _` by `Obl.nodeEval` and `conv`, else by `raw`. -/
def node (V S : Expr) (j : Nat) (nd t : Expr) : M (Expr × Option (Expr × Expr)) := do
  if (okVal? t).isSome then
    let (v, he) ← nodeEval V S j nd
    return (← mkEqTrans he (← conv (mkOk v) t), some (v, he))
  return (← raw V S j nd t, none)

/-- The goal `ty` of node `j`, left open and logged. -/
def openNode (j : Nat) (ty : Expr) : M Expr := do
  let g ← mkFreshExprSyntheticOpaqueMVar ty
  logInfo m!"mojo_vals: open goal (node {j}){indentExpr ty}"
  modify fun s => { s with opens := s.opens.push g.mvarId! }
  return g

/-- **Node `j` of `S` at `V` is `t`**, `ty` being `nd.eval V (vals V (S.nodes.take j)) = t`: the
proof, checked by the kernel, or the goal left open; and the node's value with its proof, when
`Obl.nodeEval` gives them. -/
def tryNode (V S : Expr) (j : Nat) (nd t ty : Expr) : M (Expr × Option (Expr × Expr)) := do
  let s ← (saveState : MetaM Meta.SavedState)
  try
    let (p, nat) ← node V S j nd t
    let p ← instantiateMVars p
    unless p.hasMVar do
      match Lean.Kernel.check (← getEnv) (← getLCtx) p with
      | .ok pt =>
        unless ← kdefeq pt ty do throwError "mojo_vals: the proof's type is not the goal"
      | .error e =>
        throwError "mojo_vals: the kernel rejects the proof: {e.toMessageData (← getOptions)}"
    return (hint p ty, nat)
  catch e =>
    (s.restore : MetaM Unit)
    dbg m!"mojo_vals: node {j}: {e.toMessageData}"
    return (← openNode j ty, none)

/-- `(vals V S.nodes)[j]? = some r`, from `nd.eval V (vals V (S.nodes.take j)) = r`. -/
def entry (V S : Expr) (j : Nat) (nd r he : Expr) : M Expr := do
  return (← use ``vals_getElem?_eval [(`V, V), (`ns, mkApp (mkConst ``Summary.nodes) S),
    (`j, mkNatLit j), (`nd, nd), (`r, r)] [.rfl, .kd he]).1

/-- The goal `nd.eval V (vals V (S.nodes.take j)) = t` of node `j`. -/
def nodeGoal (V S : Expr) (j : Nat) (nd t : Expr) : MetaM Expr :=
  mkEq (mkApp3 (mkConst ``SNode.eval) V (vsOf V S (some j)) nd) t

/-- **`vals V S.nodes = ws`**: each entry of `ws` proved (or left open), the later nodes reading
the earlier ones, and the list assembled from the last entry by `drop_of_getElem?`. -/
def table (V S ws : Expr) : M Expr := do
  let nsE := mkApp (mkConst ``Summary.nodes) S
  let ns ← klist nsE
  let ts ← klist ws
  unless ns.length == ts.length do
    throwError "mojo_vals: {ns.length} nodes but {ts.length} values"
  let l := mkApp2 (mkConst ``MojoProof.Sym.vals) V nsE
  let mut acc : Array (Option (Expr × Expr)) := #[]
  let mut ents : Array Expr := #[]
  for j in [0:ns.length] do
    -- the nodes before `j`, for its operands
    modify fun s => { s with nodes := s.nodes.insert (V, S) acc }
    let nd ← kdeep ns[j]! 3
    let t := ts[j]!
    let (he, nat) ← tryNode V S j nd t (← nodeGoal V S j nd t)
    let p ← entry V S j nd t he
    ents := ents.push p
    -- the later nodes read the value `Obl.nodeEval` gives, else the entry
    acc := acc.push (← match nat, okVal? t with
      | some (v, hv), some v' => do
        if v == v' then pure (some (v, p)) else pure (some (v, ← entry V S j nd (mkOk v) hv))
      | some (v, hv), none => do pure (some (v, ← entry V S j nd (mkOk v) hv))
      | none, some v => pure (some (v, p))
      | none, none => pure none)
  -- `l.drop n = []`, `n` the number of nodes
  let n := mkNatLit ns.length
  let hn ← mkAppM ``Nat.le_of_eq #[mkApp2 (mkConst ``vals_length) V nsE]
  let mut h := mkApp4 (mkConst ``List.drop_eq_nil_of_le [Level.zero]) resTy l n
    (hint hn (mkApp4 (mkConst ``LE.le [Level.zero]) (mkConst ``Nat) (mkConst ``instLENat)
      (mkApp2 (mkConst ``List.length [Level.zero]) resTy l) n))
  let mut tail := mkApp (mkConst ``List.nil [Level.zero]) resTy
  for i in [0:ns.length] do
    let j := ns.length - 1 - i
    h := mkAppN (mkConst ``drop_of_getElem?) #[resTy, l, tail, mkNatLit j, ts[j]!, ents[j]!, h]
    tail := mkApp3 (mkConst ``List.cons [Level.zero]) resTy ts[j]! tail
  mkEqTrans (← mkEqSymm (← mkAppOptM ``List.drop_zero #[resTy, l])) h

/-- **`mojo_vals` on goal `g`**: the goals it leaves open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let ty ← instantiateMVars (← g.getType)
    let some (_, lhs, rhs) := ty.eq? | throwError "mojo_vals: not an equation{indentExpr ty}"
    let facts ← launchFacts
    let k : M Expr := match lhs.getAppFnArgs with
      | (``MojoProof.Sym.vals, #[V, _]) => do table V (← summaryOf lhs) rhs
      | (``SNode.eval, #[V, vs, nd]) => do
        let (``MojoProof.Sym.vals, #[_, tk]) := vs.getAppFnArgs
          | throwError "mojo_vals: not a node's value{indentExpr ty}"
        let (``List.take, #[_, j, ns]) := tk.getAppFnArgs
          | throwError "mojo_vals: not a node's value{indentExpr ty}"
        let S ← summaryOf (mkApp2 (mkConst ``MojoProof.Sym.vals) V ns)
        let j ← natOf j
        unless ← kdefeq nd (← kdeep ((← klist ns)[j]?.getD nd) 0) do
          throwError "mojo_vals: not node {j}{indentExpr nd}"
        return (← tryNode V S j nd rhs ty).1
      | _ => throwError "mojo_vals: not a block's node values{indentExpr ty}"
    let (p, st) ← k.run { facts }
    g.assign (hint p ty)
    for m in st.dbgs do logInfo m
    return st.opens

end Vals

/-- **`mojo_vals`** proves a block's node values: a goal `vals V S.nodes = ws` for a concrete
summary `S` and a list `ws` of one entry per node, or a goal `nd.eval V (vals V (S.nodes.take j))
= r` of node `j`. `V` is a valuation under `after`s: an entry valuation `Valuation.entry c k m f`,
or any other.

An entry `.ok v` it proves by evaluating the node from the hypotheses, found by type as mojo_obl
finds them (the registers `f.regs r = some v` or `V.regs r = some v`, the function and program
`f.fn = F` or `V.fn = F` and `c.prog = P` or `V.ctx.prog = P`, the launch `c.env = L.env k` and
`L.Valid`, struct loads `m.load … = .ok v`, buffers `m.Buffer`, `Mem.Fits`, `m.Holds` and
alignments `A ∣ al`), then the value equal to `v` by kernel defeq, congruence and `omega`; an entry
that is the node's operation (`icmpV`, `intBin`, `intCast`, `extractV`) on its operands' values,
by that operation, and a float constant's entry `floatLit ft lit` by the literal. Each node it
does not prove is left as a goal and logged as `mojo_vals: open goal (node j)`. It fails on a
goal of another form and when `ws` does not have one entry per node. -/
syntax (name := mojoVals) "mojo_vals" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_vals` on the main goal. -/
@[tactic mojoVals] def evalMojoVals : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Vals.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
