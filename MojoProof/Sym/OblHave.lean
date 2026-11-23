import MojoProof.Sym.Obl

/-!
# The tactic obl_have

obl_have (syntax `oblHave`, elaborator `evalOblHave`, method `Obl.haves`) names the values that
mojo_obl's evaluator (MojoProof/Sym/Obl.lean) computes: a register, the `fmul contract` operands
of a register, a memory and a node value at a valuation under `after`s and `into`s, each as an
equation the kernel checks, from the hypotheses and the launch facts in one run. Tests:
MojoProofTest/Obl.lean (the operands and a node's value on a hand-written block, the counting
loop's registers and operands after a round, and two refusals) and MojoProofTest/NaiveIn.lean
(the naive matrix product's registers, operands and memory after its loop's head and a round).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

namespace Obl

open Lean Meta Elab Tactic

/-- **One value the evaluator computes**, `(e = x, proof)` (for `obl_have`): for a register
`V.regs r`, `x = some v` (`regOf`); for the `fmul contract` operands `V.prods r` of a register,
those `prodOf` gives; for a memory `V.mem`, the memory `memOf` gives; for a node value
`(vals V S.nodes)[j]?`, `x = some (.ok v)` (`nodeVal`). `norm` writes `V` as `normV` does. For
every program; an error when `e` is of none of these forms or has no value. -/
def haveOf (norm : Expr → M Expr) (e : Expr) : M (Expr × Expr) := do
  let fail : M (Expr × Expr) :=
    throwError "obl_have: not a register, its fmul contract operands, a memory or a node \
      value{indentExpr e}"
  match e.getAppFnArgs with
  | (``Valuation.regs, #[V, r]) =>
    let (v, p) ← regOf (← norm V) (← natOf r)
    return (← mkEq e (← mkAppOptM ``Option.some #[mkConst ``Val, v]), p)
  | (``Valuation.prods, #[V, r]) =>
    let (x, p) ← prodOf (← norm V) (← natOf r)
    return (← mkEq e x, p)
  | (``Valuation.mem, #[V]) =>
    let (m, p, _) ← memOf (← norm V)
    return (← mkEq e m, p)
  | (``GetElem?.getElem?, #[_, _, _, _, _, xs, j]) =>
    let (``vals, #[V, ns]) := xs.getAppFnArgs | fail
    let (``Summary.nodes, #[S]) := ns.getAppFnArgs | fail
    let some (v, p) ← nodeVal (← norm V) S (← natOf j)
      | throwError "obl_have: node {j} has no value"
    let ok ← mkAppOptM ``Except.ok #[mkConst ``Fault, none, v]
    return (← mkEq e (← mkAppOptM ``Option.some #[none, ok]), p)
  | _ => fail

/-- **The values of `es` at once**: the conjunction `e₁ = x₁ ∧ … ∧ eₙ = xₙ` of the equations of
`haveOf` and its proof, from the hypotheses with their parts and the launch facts (`withFacts`),
in one run: the blocks evaluated for one value serve the others (the state's caches), and each
valuation is normalized once (`normV`). For every program; `es` is not empty. -/
def haves (es : Array Expr) : MetaM (Expr × Expr) := do
  let cache ← IO.mkRef (#[] : Array (Expr × Expr))
  let norm (V : Expr) : M Expr := do
    if let some (_, W) := (← cache.get).find? (·.1 == V) then return W
    let W ← normV V
    cache.modify (·.push (V, W))
    return W
  let (p, _) ← (withFacts do
    let mut eqs := #[]
    for e in es do eqs := eqs.push (← haveOf norm e)
    let (t, q) := eqs.pop.foldr (init := (eqs.back!.1, hint eqs.back!.2 eqs.back!.1))
      fun (t, p) (u, q) =>
        (mkApp2 (mkConst ``And) t u, mkApp4 (mkConst ``And.intro) t u (hint p t) q)
    return hint q t).run {}
  return (← instantiateMVars (← inferType p), p)

/-- The `n` conjuncts of `t = a₁ ∧ (a₂ ∧ … aₙ)` with their proofs from `h : t` (`And.left`,
`And.right`); the last one is the rest of the conjunction. -/
def andSplit (t h : Expr) : Nat → List (Expr × Expr)
  | 0 | 1 => [(t, h)]
  | n + 1 =>
    match t.getAppFnArgs with
    | (``And, #[a, b]) =>
      (a, mkApp3 (mkConst ``And.left) a b h) :: andSplit b (mkApp3 (mkConst ``And.right) a b h) n
    | _ => [(t, h)]

end Obl

/-- **`obl_have h₁ : e₁, …, hₙ : eₙ`** adds the hypotheses `hᵢ : eᵢ = xᵢ`, `xᵢ` the value that
`mojo_obl`'s evaluator computes from the hypotheses (each with its parts: conjuncts, fields of a
structure of propositions) and the launch facts: for a register `V.regs r`, `xᵢ = some v`
(`Obl.regOf`); for the `fmul contract` operands `V.prods r` of a register, those `Obl.prodOf`
gives (`some (u, v)` or `none`); for a memory `V.mem`, the memory `Obl.memOf` gives; for a node
value `(vals V S.nodes)[j]?`, `xᵢ = some (.ok v)` (`Obl.nodeVal`). Each `V` is a valuation that
`Obl.normV` writes as `after`s and `into`s of an entry valuation or of a local valuation. The
values are computed in one run (`Obl.haves`), so the blocks evaluated for one serve the others.
The kernel checks the proof; the tactic fails when some `eᵢ` gets no value. For every
program. -/
syntax (name := oblHave) "obl_have" sepBy1(group(ident " : " term), ", ") : tactic

open Lean Meta Elab Tactic in
/-- Runs `obl_have` on the main goal: the values of all items from one run (`Obl.haves`), one
conjunction split into the named hypotheses (`Obl.andSplit`). -/
@[tactic oblHave] def evalOblHave : Tactic := fun stx => withMainContext do
  let items := stx[1].getSepArgs
  let es ← items.mapM fun it => do instantiateMVars (← elabTerm it[2] none)
  let lctx ← instantiateLCtxMVars (← getLCtx)
  let (ty, p) ← withLCtx lctx (← getLocalInstances) (Obl.haves es)
  let (h, g) ← (← (← getMainGoal).assert `h ty p).intro1
  let hs := (Obl.andSplit ty (mkFVar h) es.size).toArray
  let (_, g) ← g.assertHypotheses ((items.zip hs).map fun (it, t, v) =>
    { userName := it[0].getId, type := t, value := v })
  replaceMainGoal [← g.tryClear h]

end MojoProof.Sym
