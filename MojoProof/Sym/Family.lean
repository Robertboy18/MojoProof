import MojoProof.Sym.Command
import MojoProof.Sym.Obl

/-!
# Block summaries of a program family: the command `sym_summary_family`

A program family (the command `mojo_family`, MojoProof/LLVM/Family.lean) is a program with some
integer constants as parameters. Its blocks' summaries are functions of the parameters, and the
block checker's equality test `decide (S' = S)` (`coversAt`) does not reduce on a summary with free
variables. This module gives the summaries of a family as functions and the checker's verdict at
them as an equation:

* `sym_summary_family n (x₁ … xₖ) := P fn lbl p0` (optionally ending in `contract`) defines
  `n (x₁ … xₖ : Nat) : Summary`, the summary of block `lbl` of `fn x₁ … xₖ` from position `p0`,
  and the theorem `n_eq x₁ … xₖ`, for every `x₁ … xₖ`,
  `summarizeWith (P x₁ … xₖ) (fn x₁ … xₖ) lbl p0 (fun σ tm => σ.exitAt (fn x₁ … xₖ) lbl tm) c =
  some (n x₁ … xₖ)`, `c` true with `contract`, checked by the kernel's definitional equality
  under the binders (`Obl.krfl`).
* `coversAt_eq`: the block checker at a summary that the summarizer gives is the prefix test of
  its obligations, for every program, function, block, position, exit function and flags. With
  `n_eq x₁ … xₖ` it turns a family's path checks into closed checks that the kernel evaluates.

The command evaluates the summary once, at arguments `2 ^ 80 + i` (`i` the parameter's
position), and puts `Int.ofNat xᵢ` for each such integer of the quoted result; it fails if one
is left in another form. Nothing here is trusted: `n_eq x₁ … xₖ` is checked by the kernel at every
argument, so a wrong substitution makes the command fail, not a theorem hold.
-/

open Lean Elab Command Meta

namespace MojoProof.Sym

open MojoProof.LLVM

/-- **The block checker at a summary that the summarizer gives**, for every flag `alloca`,
program, function, block, position, exit function, conditions `ds`, summary `S` and flag
`contract`: if `summarizeAt` gives `S`, then `coversAt` at `S` is whether the obligations of `S`
are the first conditions of `ds`. -/
theorem coversAt_eq {alloca : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → LLVM.Term → Option (Exit × List Cond)} {contract : Bool} {S : Summary}
    (h : summarizeAt alloca P fn lbl p0 ex contract = some S) (ds : List Cond) :
    coversAt alloca P fn lbl p0 ex ds S contract = S.obls.isPrefixOf ds := by
  simp only [coversAt, h, decide_true, Bool.true_and]

/-- `sym_summary_family n (x₁ … xₖ) := P fn lbl p0` defines `n (x₁ … xₖ : Nat) : Summary`, the
summary of block `lbl` of `fn x₁ … xₖ` in `P x₁ … xₖ` from position `p0` (exit `SState.exitAt`,
`fmul contract` in the fragment when the command ends in `contract`), and its equation `n_eq`
for every `x₁ … xₖ`, checked by the kernel; an error if the block is outside the checker's
fragment or a parameter's value is left in the summary in a form other than `Int.ofNat`. -/
syntax (name := symSummaryFamily) (docComment)? "sym_summary_family " ident " (" ident+ ")"
  " := " term:max term:max term:max term:max (&" contract")? : command

/-- Elaborates `sym_summary_family`; `unsafe` because it evaluates the summary. -/
@[command_elab symSummaryFamily] unsafe def elabSymSummaryFamily : CommandElab := fun stx => do
  let name := (← getCurrNamespace) ++ stx[2].getId
  let xs := stx[4].getArgs.map (·.getId)
  let contract := !stx[11].isNone
  liftTermElabM do
    let P ← Term.elabTerm stx[7] none
    let fn ← Term.elabTerm stx[8] none
    let lbl ← Term.elabTermEnsuringType stx[9] (mkConst ``Nat)
    let p0 ← Term.elabTermEnsuringType stx[10] (mkConst ``Nat)
    Term.synthesizeSyntheticMVarsNoPostponing
    let P ← instantiateMVars P
    let fn ← instantiateMVars fn
    let lbl ← instantiateMVars lbl
    let p0 ← instantiateMVars p0
    -- the arguments at which the summary is evaluated, one per parameter
    let sen (i : Nat) : Nat := 2 ^ 80 + i
    let args : Array Expr := (Array.range xs.size).map fun i => toExpr (sen i)
    let ex (F : Expr) : Expr :=
      .lam `σ (mkConst ``SState) (.lam `tm (mkConst ``MojoProof.LLVM.Term)
        (mkAppN (mkConst ``SState.exitAt) #[F, lbl, .bvar 1, .bvar 0]) .default) .default
    let summ (Pa Fa : Expr) : Expr :=
      mkAppN (mkConst ``summarizeWith) #[Pa, Fa, lbl, p0, ex Fa, toExpr contract]
    let ty := mkApp (mkConst ``Option [Level.zero]) (mkConst ``Summary)
    let e := summ (mkAppN P args) (mkAppN fn args)
    let some S ← evalExpr (Option Summary) ty e
      | throwError "sym_summary_family: block {stx[9]} of {stx[8]} from position {stx[10]} \
          is outside the checker's fragment"
    let binders : Array (Name × (Array Expr → TermElabM Expr)) :=
      xs.map fun x => (x, fun _ => pure (mkConst ``Nat))
    withLocalDeclsD binders fun fvs => do
      let mut q := toExpr S
      for i in [0:xs.size] do
        let st := toExpr ((sen i : Nat) : Int)
        q := q.replace fun t => if t == st then some (mkApp (mkConst ``Int.ofNat) fvs[i]!) else none
      for i in [0:xs.size] do
        if (q.find? fun t => t.rawNatLit? == some (sen i)).isSome then
          throwError "sym_summary_family: the value of parameter {xs[i]!} is left in the summary \
            in a form other than `Int.ofNat {xs[i]!}`"
      addAndCompile <| .defnDecl
        { name, levelParams := [], type := ← mkForallFVars fvs (mkConst ``Summary),
          value := ← mkLambdaFVars fvs q, hints := .abbrev, safety := .safe }
      enableRealizationsForConst name
      match stx[0].getOptional? with
      | some doc => addDocString name .missing ⟨doc⟩
      | none => addDocStringCore name s!"The summary of block `{stx[9]}` of `{stx[8]}` from \
          position `{stx[10]}` at every argument (generated by `sym_summary_family`)."
      -- the equation, checked by the kernel under the binders
      let lhs := summ (mkAppN P fvs) (mkAppN fn fvs)
      let rhs := mkApp2 (mkConst ``Option.some [Level.zero]) (mkConst ``Summary)
        (mkAppN (mkConst name) fvs)
      let pf ← Obl.krfl lhs rhs
      let eqTy ← mkForallFVars fvs (← mkEq lhs rhs)
      let eqName := name.appendAfter "_eq"
      addDecl <| .thmDecl
        { name := eqName, levelParams := [], type := eqTy, value := ← mkLambdaFVars fvs pf }
      let fm := if contract then ", `fmul contract`" else ""
      addDocStringCore eqName s!"The summary of block `{stx[9]}` of `{stx[8]}` from position \
        `{stx[10]}` (`summarizeWith`, exit `SState.exitAt`{fm}) is `{stx[2].getId}` at every \
        argument (generated by `sym_summary_family`, checked by the kernel)."

end MojoProof.Sym
