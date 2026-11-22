import Lean

/-!
# The tactic mojo_bounds: integer and bounds obligations of bit-vector index arithmetic

The tactic mojo_bounds (syntax `mojoBounds`, elaborator `evalMojoBounds`) closes goals about bit
vectors, natural numbers and integers built from `setWidth` (`trunc`, `zext`), `signExtend`
(`sext`), `+`, `*`, signed and unsigned comparisons and `Int.bmod`, the operations of LLVM index
arithmetic in the semantics (`intCast`, `binV`, `gepPtr`, MojoProof/Sem/), under hypotheses of the
same kind: range facts of special registers, path conditions such as `i <s n`, the size of a
buffer. Its target is the access check of `Mem.check`, `0 ≤ off ∧ off + size ≤ len`, and the facts
behind it: no wrap at an `add` or `mul`, a `trunc` followed by a `sext` is the identity on the
values in range.

Method, for every goal (nothing kernel-specific; no case split on concrete values, only on the
`if`s the lowering produces):

1. Lowering: `simp only [BitVec.toNat_add, BitVec.toNat_ofNat, BitVec.toNat_setWidth, …] at *`
   (the full list is in `evalMojoBounds`) turns every bit-vector term at the goal and every
   hypothesis into `toNat` of its atoms, `%` by powers of two and `if`s (sign bits, signed values,
   balanced remainders).
2. Remainders: a remainder `t % m` whose dividend has a bound `K ≤ m` (below) is rewritten to `t`
   everywhere (`simp only [Nat.mod_eq_of_lt h] at *`), innermost first. Bounds by the term's
   structure: a hypothesis `t < K` or `t ≤ K'` in the context, `2 ^ w` for `x.toNat` with
   `x : BitVec w` (by its type, `BitVec.isLt`), the dividend's bound (`Nat.mod_lt_of_lt h`) or the
   modulus of `t % m`, sums and products of bounds (`Nat.mul_lt_mul_of_lt_of_lt h₁ h₂`). This
   keeps `omega` off the nested remainders that the lowering of `zext`, `sext` and `add` produces.
3. Conditions: each `if` condition with no `if` inside it is decided by `omega` from the
   hypotheses when it can be (the sign bit of a value in range, no wrap), and its `if`s rewritten
   to that branch everywhere (`simp only [ite_eq_left h] at *`, or `ite_eq_right h` for the
   other branch); a condition `omega` decides neither way is split on, by the `if`'s own
   `Decidable` instance (`MVarId.byCasesDec`, no classical choice). Steps 2 to 5 follow in each
   case.
4. Facts by type: every product `t * s` of natural numbers in the goal or a hypothesis, neither
   factor a numeral, with bounded factors, gets the fact `t * s < K₁ * K₂`
   (`Nat.mul_lt_mul_of_lt_of_lt h₁ h₂`), which `omega`, treating the product as an atom, cannot
   find.
5. `omega`, once no `if` is left.

The hypotheses added (remainder bounds, product facts, decided conditions, cases) have
inaccessible names (`mkFreshUserName`). A goal that `omega` does not close is left open, lowered,
with the cases taken, and the tactic logs it ("mojo_bounds: open goal"), so that a caller sees the
inequality that fails. Tests: MojoProofTest/SymBounds.lean.
-/

namespace MojoProof.Sym

open Lean Meta Elab Tactic

/-- Whether `e` is a natural-number literal. -/
private def isNumeral (e : Expr) : Bool := e.nat?.isSome || e.rawNatLit?.isSome

/-- The value of a closed natural-number term built from literals by `+`, `*`, `^` and `-`. -/
private partial def natVal? (e : Expr) : Option Nat :=
  match e.nat?, e.rawNatLit? with
  | some n, _ | none, some n => some n
  | none, none => match_expr e with
    | HAdd.hAdd α _ _ _ a b =>
      if α.isConstOf ``Nat then (· + ·) <$> natVal? a <*> natVal? b else none
    | HMul.hMul α _ _ _ a b =>
      if α.isConstOf ``Nat then (· * ·) <$> natVal? a <*> natVal? b else none
    | HPow.hPow α _ _ _ a b =>
      if α.isConstOf ``Nat then (· ^ ·) <$> natVal? a <*> natVal? b else none
    | HSub.hSub α _ _ _ a b =>
      if α.isConstOf ``Nat then (· - ·) <$> natVal? a <*> natVal? b else none
    | _ => none

/-- Whether bound `k` is smaller than bound `k'`, by their values (`natVal?`); a bound without
a value is the largest. -/
private def smaller (k k' : Expr) : Bool :=
  match natVal? k, natVal? k' with
  | some v, some v' => v < v'
  | some _, none => true
  | none, _ => false

/-- The least bound of `cs` (`smaller`), or `none` if `cs` is empty. -/
private def least (cs : Array (Expr × Expr)) : Option (Expr × Expr) :=
  cs.foldl (init := none) fun
    | none, c => some c
    | some b, c => if smaller c.1 b.1 then some c else some b

/-- A bound `K` and a proof of `e < K` for a natural-number term `e`: the least (`least`) of the
bounds from the hypotheses `e < K` and `e ≤ K` of the context with `K` closed, from a numeral,
and from the term's shape (`x.toNat` of `x : BitVec w`, a remainder, a sum or a product of
bounded terms); `none` if there is none. -/
private partial def bound (e : Expr) : MetaM (Option (Expr × Expr)) := do
  let mut cs : Array (Expr × Expr) := #[]
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let ty ← instantiateMVars d.type
    match_expr ty with
    | LT.lt α _ a k =>
      if α.isConstOf ``Nat && a == e && !k.hasFVar then cs := cs.push (k, d.toExpr)
    | LE.le α _ a k =>
      if α.isConstOf ``Nat && a == e && !k.hasFVar then
        cs := cs.push (mkNatAdd k (mkNatLit 1), ← mkAppM ``Nat.lt_succ_of_le #[d.toExpr])
    | _ => pure ()
  if isNumeral e then
    cs := cs.push (mkNatAdd e (mkNatLit 1), ← mkAppM ``Nat.lt_succ_self #[e])
  match_expr e with
  | BitVec.toNat _ x =>
    let h ← mkAppM ``BitVec.isLt #[x]
    cs := cs.push ((← inferType h).appArg!, h)
  | HMod.hMod α _ _ _ t m =>
    if α.isConstOf ``Nat then
      if let some (k, h) ← bound t then
        cs := cs.push (k, ← mkAppOptM ``Nat.mod_lt_of_lt #[t, m, k, h])
      if (natVal? m).any (0 < ·) then
        let hm ← mkDecideProof (← mkAppM ``LT.lt #[mkNatLit 0, m])
        cs := cs.push (m, ← mkAppM ``Nat.mod_lt #[t, hm])
  | HAdd.hAdd α _ _ _ t s =>
    if α.isConstOf ``Nat then
      if let some (k₁, h₁) ← bound t then
        if let some (k₂, h₂) ← bound s then
          cs := cs.push (mkNatAdd k₁ k₂, ← mkAppM ``Nat.add_lt_add #[h₁, h₂])
  | HMul.hMul α _ _ _ t s =>
    if α.isConstOf ``Nat then
      if let some (k₁, h₁) ← bound t then
        if let some (k₂, h₂) ← bound s then
          cs := cs.push (mkNatMul k₁ k₂, ← mkAppM ``Nat.mul_lt_mul_of_lt_of_lt #[h₁, h₂])
  | _ => pure ()
  return least cs

/-- A remainder `t % m` of natural numbers in `e`, with `m` closed, whose dividend's bound
(`bound`) is at most `m`, with a proof of `t < m`; the innermost first. -/
private partial def removableMod? (e : Expr) : MetaM (Option (Expr × Expr × Expr)) := do
  match e with
  | .app f a =>
    if let some r ← removableMod? f then return some r
    if let some r ← removableMod? a then return some r
  | .mdata _ b => return ← removableMod? b
  | _ => pure ()
  match_expr e with
  | HMod.hMod α _ _ _ t m =>
    unless α.isConstOf ``Nat && !e.hasLooseBVars do return none
    let some mv := natVal? m | return none
    let some (k, h) ← bound t | return none
    let some kv := natVal? k | return none
    unless kv ≤ mv do return none
    let hle ← mkDecideProof (← mkAppM ``LE.le #[k, m])
    return some (t, m, ← mkAppM ``Nat.lt_of_lt_of_le #[h, hle])
  | _ => return none

/-- The products `t * s` of natural numbers in `e`, neither factor a numeral and neither under
a binder, added to `ps`. -/
private partial def products (e : Expr) (ps : Array Expr) : Array Expr :=
  let ps := match_expr e with
    | HMul.hMul α _ _ _ t s =>
      if α.isConstOf ``Nat && !isNumeral t && !isNumeral s && !e.hasLooseBVars &&
          !ps.contains e then ps.push e else ps
    | _ => ps
  match e with
  | .app f a => products a (products f ps)
  | .mdata _ b => products b ps
  | .proj _ _ b => products b ps
  | .lam _ t b _ | .forallE _ t b _ => products b (products t ps)
  | .letE _ t v b _ => products b (products v (products t ps))
  | _ => ps

/-- Step 4 of `mojo_bounds` on goal `g`: for every product of natural numbers in its target or
hypotheses with bounded factors, the hypothesis `t * s < K₁ * K₂`, under a hygienic name. -/
private def addProductFacts (g : MVarId) : MetaM MVarId := g.withContext do
  let mut ps : Array Expr := products (← instantiateMVars (← g.getType)) #[]
  for d in ← getLCtx do
    unless d.isImplementationDetail do
      ps := products (← instantiateMVars d.type) ps
  let mut g := g
  for p in ps do
    let some (k, h) ← g.withContext (bound p) | continue
    if h.isFVar then continue
    let n ← mkFreshUserName `mojo_bound
    let (_, g') ← (← g.assert n (← mkAppM ``LT.lt #[p, k]) h).intro1P
    g := g'
  return g

/-- The `if` conditions `c` in `e` with no `if` inside them, with their `Decidable c` instances,
added to `cs`. -/
private partial def innerItes (e : Expr) (cs : Array (Expr × Expr)) : Array (Expr × Expr) :=
  let cs := if e.isAppOfArity ``ite 5 && !e.hasLooseBVars &&
      ((e.getArg! 1).find? (·.isAppOfArity ``ite 5)).isNone then
    cs.push (e.getArg! 1, e.getArg! 2) else cs
  match e with
  | .app f a => innerItes a (innerItes f cs)
  | .mdata _ b => innerItes b cs
  | .proj _ _ b => innerItes b cs
  | .lam _ t b _ | .forallE _ t b _ => innerItes b (innerItes t cs)
  | .letE _ t v b _ => innerItes b (innerItes v (innerItes t cs))
  | _ => cs

/-- The smallest (`Expr.sizeWithoutSharing`) `if` condition with no `if` inside it in the target
or a hypothesis of `g`, with its instance: sign bits of atoms before the conditions built on
them. -/
private def findCond (g : MVarId) : MetaM (Option (Expr × Expr)) := g.withContext do
  let mut cs := innerItes (← instantiateMVars (← g.getType)) #[]
  for d in ← getLCtx do
    unless d.isImplementationDetail do cs := innerItes (← instantiateMVars d.type) cs
  return cs.foldl (init := none) fun
    | none, c => some c
    | some b, c => if c.1.sizeWithoutSharing < b.1.sizeWithoutSharing then some c else some b

/-- Whether `omega` closes `g`. When it does not, including when it stops at a resource limit
(`tryCatchRuntimeEx`), the state is restored. -/
private def omegaCloses (g : MVarId) : TacticM Bool := do
  let s ← saveState
  tryCatchRuntimeEx
    (do
      setGoals [g]
      evalTactic (← `(tactic| omega))
      return true)
    fun _ => do
      s.restore
      return false

/-- A proof of `p` by `omega` in the context of `g`, or `none`. -/
private def omegaProves (g : MVarId) (p : Expr) : TacticM (Option Expr) := do
  let m ← g.withContext (mkFreshExprSyntheticOpaqueMVar p)
  return if ← omegaCloses m.mvarId! then some m else none

/-- The goals left by rewriting, at the target and every hypothesis of `g`, each `if c` by its
branch (`ite_eq_left` or `ite_eq_right` with the hypothesis named `n` of `c` or `¬c`); `[g]` if
that fails. -/
private def elimCond (g : MVarId) (n : Name) (pos : Bool) : TacticM (List MVarId) := do
  try
    setGoals [g]
    let h := mkIdent n
    if pos then
      evalTactic (← `(tactic| simp only [ite_eq_left $h:ident, Nat.add_zero, Int.add_zero] at *))
    else
      evalTactic (← `(tactic| simp only [ite_eq_right $h:ident, Nat.add_zero, Int.add_zero] at *))
    getGoals
  catch _ => return [g]

/-- A removable remainder (`removableMod?`) in the target or a hypothesis of `g`. -/
private def findMod (g : MVarId) : MetaM (Option (Expr × Expr × Expr)) := g.withContext do
  if let some r ← removableMod? (← instantiateMVars (← g.getType)) then return some r
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    if let some r ← removableMod? (← instantiateMVars d.type) then return some r
  return none

/-- Step 2 of `mojo_bounds` on goal `g`, at most `fuel` times: a remainder `t % m` whose dividend
is below `m` by its bound is rewritten to `t` at the target and every hypothesis
(`Nat.mod_eq_of_lt`); the goals left. -/
private partial def dropMods (g : MVarId) : Nat → TacticM (List MVarId)
  | 0 => return [g]
  | fuel + 1 => do
    let some (t, m, h) ← findMod g | return [g]
    let n ← mkFreshUserName `mojo_mod
    let (_, g') ← (← g.assert n (← mkAppM ``LT.lt #[t, m]) h).intro1P
    try
      setGoals [g']
      evalTactic (← `(tactic| simp only [Nat.mod_eq_of_lt $(mkIdent n):ident] at *))
    catch _ => return [g]
    match ← getGoals with
    | [g''] => dropMods g'' fuel
    | gs => return gs

/-- Steps 2 to 5 of `mojo_bounds` on goal `g`; the goals left open. The removable remainders go
first (`dropMods`), then the product facts (`addProductFacts`); a goal without `if`s is then left
to `omega`; for one with `if`s, a goal whose hypotheses `omega` refutes is closed, else the
smallest `if` condition with no `if` inside it is decided by `omega` from the hypotheses when it
can be, else split on (`byCasesDec`, by the `if`'s own `Decidable` instance), and the search goes
on in each case. -/
private partial def search (g : MVarId) : TacticM (Array MVarId) := do
  let gs ← dropMods g 64
  let [g] := gs | gs.toArray.flatMapM search
  -- after rewriting the `if`s of the condition named `n` to their branch, the search on each goal
  let next (g : MVarId) (n : Name) (pos : Bool) : TacticM (Array MVarId) := do
    let gs ← elimCond g n pos
    if gs == [g] then return #[g]
    gs.toArray.flatMapM search
  let g ← addProductFacts g
  let some (c, dec) ← findCond g |
    return if ← omegaCloses g then #[] else #[g]
  if let some h ← omegaProves g (mkConst ``False) then
    g.assign (← mkFalseElim (← g.getType) h)
    return #[]
  let n ← mkFreshUserName `mojo_case
  for (p, pos) in [(c, true), (mkNot c, false)] do
    if let some h ← omegaProves g p then
      let (_, g') ← (← g.assert n p h).intro1P
      return ← next g' n pos
  let (s₁, s₂) ← g.byCasesDec c dec n
  return (← next s₁.mvarId n true) ++ (← next s₂.mvarId n false)

/-- `mojo_bounds` closes integer, natural-number and bit-vector goals of index arithmetic:

1. lowering to `toNat`, `%` by powers of two and `if`s (`simp only` with `BitVec.toNat_add`,
   `toNat_mul`, `toNat_ofNat`, `toNat_setWidth`, `toNat_signExtend`, `msb_eq_decide`,
   `toInt_eq_toNat_cond`, `slt_iff_toInt_lt`, `ult_iff_lt`, `lt_def`, `le_def`, `Int.bmod_def`
   and `decide_eq_true_eq` at every hypothesis and the goal);
2. every remainder `t % m` whose dividend is below `m` by its bound rewritten to `t`;
3. every `if` condition, innermost first, decided by `omega` from the hypotheses when it can be
   (a sign bit of a value in range, no wrap), else split on, then steps 2 to 5 again;
4. a bound `t * s < K₁ * K₂` for every product with bounded factors;
5. `omega`.

Bounds of terms come from the context's hypotheses `t < K` and `t ≤ K`, from the types
(`x.toNat < 2 ^ w` for `x : BitVec w`), from the modulus of a remainder, and from sums and
products of bounds. The hypotheses it adds have inaccessible names. A goal that remains is left
open, lowered, with the cases taken, and logged ("mojo_bounds: open goal"). -/
syntax (name := mojoBounds) "mojo_bounds" : tactic

@[tactic mojoBounds, inherit_doc mojoBounds]
def evalMojoBounds : Tactic := fun _ => do
  evalTactic (← `(tactic| try simp only [BitVec.toNat_add, BitVec.toNat_mul, BitVec.toNat_ofNat,
    BitVec.toNat_setWidth, BitVec.toNat_signExtend, BitVec.msb_eq_decide,
    BitVec.toInt_eq_toNat_cond, BitVec.slt_iff_toInt_lt, BitVec.ult_iff_lt, BitVec.lt_def,
    BitVec.le_def, Int.bmod_def, decide_eq_true_eq] at *))
  let mut rest := #[]
  for g in ← getGoals do
    for g' in ← search g do
      logInfo m!"mojo_bounds: open goal{indentD (← g'.getType)}"
      rest := rest.push g'
  setGoals rest.toList

end MojoProof.Sym
