import MojoProof.Sym.Block
import MojoProof.LLVM.Quote

/-!
# Block summaries as Lean terms: `sym_summary`

`sym_summary n := P fn lbl p0` evaluates `summarize P fn lbl p0` with the compiler when the
command is elaborated and adds, in the current namespace, the definition `n : Summary` whose
value is the result, quoted (an optional doc comment before the command becomes its docstring),
with its equation lemmas enabled (`enableRealizationsForConst`), so that `simp only [n]` and
`unfold n` unfold it in the module that runs the command too. It records the definition in
`MojoProof.LLVM.defs` under the quoted term, unless a constant is recorded there for that term
already, so that a later `MojoProof.LLVM.share` of the same summary (the quotation of a
`mojo_kernel` theorem's summaries, say) names `n` instead of adding a second definition.
It fails, naming the block, when `summarize` gives `none` (the block is outside the checker's
fragment).

Nothing here is trusted: a theorem uses the summary through `covers P fn lbl p0 ds n = true`,
which the kernel evaluates (`decide +kernel`), so a wrong quotation or a wrong evaluation makes
the theorem fail, not hold. Nobody writes the summary by hand.

This module is executable code with no theorems.
-/

open Lean Elab Command Meta

namespace MojoProof.Sym

deriving instance ToExpr for SNode
deriving instance ToExpr for Cond
deriving instance ToExpr for Exit
deriving instance ToExpr for Summary

/-- `sym_summary n := P fn lbl p0` defines `n : Summary` as the value of `summarize P fn lbl p0`,
computed when the command is elaborated, and records it in `MojoProof.LLVM.defs` under its term
unless a constant is recorded for that term already; an error if the block is outside the
checker's fragment. -/
syntax (name := symSummary) (docComment)? "sym_summary " ident " := " term:max term:max term:max
  term:max : command

/-- Elaborates `sym_summary`; `unsafe` because it evaluates the summary. -/
@[command_elab symSummary] unsafe def elabSymSummary : CommandElab := fun stx => do
  let name := (← getCurrNamespace) ++ stx[2].getId
  liftTermElabM do
    let P ← Term.elabTermEnsuringType stx[4] (mkConst ``MojoProof.LLVM.Program)
    let fn ← Term.elabTermEnsuringType stx[5] (mkConst ``MojoProof.LLVM.Func)
    let lbl ← Term.elabTermEnsuringType stx[6] (mkConst ``Nat)
    let p0 ← Term.elabTermEnsuringType stx[7] (mkConst ``Nat)
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars (mkAppN (mkConst ``summarize) #[P, fn, lbl, p0])
    let ty := mkApp (mkConst ``Option [Level.zero]) (mkConst ``Summary)
    match ← evalExpr (Option Summary) ty e with
    | none => throwError "sym_summary: block {stx[6]} of {stx[5]} from position {stx[7]} is \
        outside the checker's fragment"
    | some S =>
      addAndCompile <| .defnDecl
        { name, levelParams := [], type := mkConst ``Summary, value := toExpr S,
          hints := .abbrev, safety := .safe }
      -- its equation lemmas, so that `simp only [n]` unfolds it in this module too
      enableRealizationsForConst name
      -- the quotation's later `share` of the same term names `n` (unless a constant has it)
      unless (MojoProof.LLVM.defs.getState (← getEnv)).contains (toExpr S) do
        modifyEnv (MojoProof.LLVM.defs.addEntry · (toExpr S, name))
      if let some doc := stx[0].getOptional? then
        addDocString name .missing ⟨doc⟩

end MojoProof.Sym
