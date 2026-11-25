import MojoProof.LLVM.Quote

/-!
# A program with its integer constants as parameters: the command `mojo_family`

`mojo_family F := P i with x₁ at "%r₁", …, xₙ at "%rₙ"` takes a program term `P` that
`mojo_import` added and a function index `i`, and for each `xₖ` the statement `%rₖ = …` of
function `i`, a two-operand integer instruction (`bin`: `mul`, `add`, …) with exactly one integer
constant operand `vₖ`. It adds, in the current namespace,

* `F.b_<j> (x₁ … xₙ : Nat) : Block` for each block `j` with one of the statements: the block with
  each such statement's constant `vₖ` replaced by `xₖ` (`Value.int (Int.ofNat xₖ)`);
* `F.fn (x₁ … xₙ : Nat) : Func`: function `i` with those blocks, the other blocks being the
  imported block definitions;
* `F.prog (x₁ … xₙ : Nat) : Program`: `P` with function `i` replaced by `F.fn x₁ … xₙ`; every other
  field (the other functions, the metadata, the layout, the digest `sha256`, the kernel names) is
  `P`'s, so the digest is the imported file's at every argument;
* `F.prog_corpus : F.prog v₁ … vₙ = P ∧ F.fn v₁ … vₙ = P_i`, where `P_i` is the imported
  definition of function `i`, by `rfl`, checked by the kernel.

Every theorem about `F.prog x₁ … xₙ` for every `x₁ … xₙ` is, by that equation, a theorem about
`P` at `v₁ … vₙ`; another specialization of the same source whose function differs from function
`i` only in those constants and its name is `F.fn` at its constants with its name
(MojoProofTest/Family.lean). The command fails when `P` is not a constant of type `Program`, when
function `i` or a local `%rₖ` does not exist, when no statement or more than one has result
`%rₖ`, when that statement is not a `bin` with exactly one integer constant operand, when the
constant is negative, and when two parameters name the same statement.

This module is executable code with no theorems.
-/

open Lean Elab Command Meta

namespace MojoProof.LLVM

/-- The integer constant of instruction `i` when it is a two-operand integer instruction (`bin`)
with exactly one integer constant operand; `none` otherwise. -/
def Inst.binConst? : Inst → Option Int
  | .bin _ _ _ (.int _) (.int _) => none
  | .bin _ _ _ (.int v) _ => some v
  | .bin _ _ _ _ (.int v) => some v
  | _ => none

/-- Instruction `i` with the integer constant operand of a `bin` replaced by `v` (the first
operand when both are constants; `i` itself when it is not a `bin` with a constant). -/
def Inst.setBinConst (v : Int) : Inst → Inst
  | .bin op fl t (.int _) b => .bin op fl t (.int v) b
  | .bin op fl t a (.int _) => .bin op fl t a (.int v)
  | i => i

/-- The characters of `s` without its trailing whitespace. -/
private def d' (s : String) : List Char :=
  (s.toList.reverse.dropWhile Char.isWhitespace).reverse

/-- `mojo_family F := P i with x₁ at "%r₁", …` adds `F.prog`, `F.fn`, the changed blocks and
`F.prog_corpus`: the program `P` with the integer constants of the statements `%r₁, …` of
function `i` as the parameters `x₁, …` (natural numbers), and the equation that `P` is the
instance at its own constants. An optional doc comment before the command is prepended to the
docstrings of `F.prog` and `F.fn`. -/
syntax (name := mojoFamily) (docComment)? "mojo_family " ident " := " term:max num " with "
  sepBy1(ident " at " str, ", ") : command

/-- Elaborates `mojo_family`; `unsafe` because it evaluates `P`. -/
@[command_elab mojoFamily] unsafe def elabMojoFamily : CommandElab := fun stx => do
  let F := (← getCurrNamespace) ++ stx[2].getId
  let some i := stx[5].isNatLit? | throwUnsupportedSyntax
  let ps ← stx[7].getSepArgs.mapM fun p => do
    let some r := p[2].isStrLit? | throwUnsupportedSyntax
    pure (p[0].getId, if r.startsWith "%" then String.ofList (r.toList.drop 1) else r)
  let pre ← match stx[0].getOptional? with
    | some d => pure (String.ofList (d' (← getDocStringText ⟨d⟩)) ++ " ")
    | none => pure ""
  let nm := stx[2].getId
  liftTermElabM do
    let Pe ← Term.elabTermEnsuringType stx[4] (mkConst ``Program)
    Term.synthesizeSyntheticMVarsNoPostponing
    let Pe ← instantiateMVars Pe
    let some pn := Pe.constName?
      | throwError "mojo_family: {stx[4]} is not a constant (the program `mojo_import` adds)"
    let p ← evalExpr Program (mkConst ``Program) Pe
    let some f := p.module.funcs[i]?
      | throwError "mojo_family: {pn} has no function {i}"
    -- each parameter's block, position and constant
    let locs ← ps.mapM fun (x, r) => do
      let some ri := (List.range f.names.size).find? (f.names[·]? == some r)
        | throwError "mojo_family: function {i} has no local %{r}"
      let hits := f.blocks.toList.zipIdx.flatMap fun (b, j) =>
        b.stmts.toList.zipIdx.filterMap fun (s, k) => if s.res == some ri then some (j, k, s)
          else none
      let [(j, k, s)] := hits
        | throwError "mojo_family: {hits.length} statements of function {i} have result %{r}"
      let some v := s.inst.binConst?
        | throwError "mojo_family: %{r} is not a two-operand integer instruction with one \
            integer constant operand"
      if v < 0 then throwError "mojo_family: the constant of %{r} is negative ({v})"
      pure (x, r, j, k, v.toNat)
    let ks := locs.toList.map fun (_, _, j, k, _) => (j, k)
    unless ks.eraseDups.length == ks.length do
      throwError "mojo_family: two parameters name the same statement"
    let file := (progFiles.getState (← getEnv)).find? pn
      |>.map (s!" (the corpus file `{·}`)") |>.getD ""
    let consts := ", ".intercalate <| locs.toList.map fun (x, r, _, _, v) =>
      s!"`%{r}`'s {v} as `{x}`"
    -- the sentinel constant of parameter `n`, replaced by the parameter after quoting
    let sentinel (n : Nat) : Int := -(2 ^ 80 + n)
    let xs := locs.map (·.1)
    let binders := xs.map fun x => (x, fun (_ : Array Expr) => pure (mkConst ``Nat))
    let ty (fvs : Array Expr) (t : Name) : TermElabM Expr := mkForallFVars fvs (mkConst t)
    Meta.withLocalDeclsD binders fun fvs => do
      let bs ← f.blocks.toList.zipIdx.mapM fun (b, j) => do
        let here := locs.toList.zipIdx.filter fun ((_, _, j', _, _), _) => j' == j
        if here.isEmpty then
          return (← share (F ++ (`b).appendIndexAfter j) (mkConst ``Block) (toExpr b))
        let set (n : Nat) (s : Stmt) : Stmt := { s with inst := s.inst.setBinConst (sentinel n) }
        let b' := here.foldl (fun b ((_, _, _, k, _), n) =>
          { b with stmts := b.stmts.modify k (set n) }) b
        let e := here.foldl (fun e (_, n) => let st := toExpr (Value.int (sentinel n))
          e.replace fun t => if t == st then
            some (mkApp (mkConst ``Value.int) (mkApp (mkConst ``Int.ofNat) fvs[n]!))
          else none) (toExpr b')
        let c := F ++ (`b).appendIndexAfter j
        addDef c (← ty fvs ``Block) (← mkLambdaFVars fvs e)
        let label := f.names.getD b.label ""
        addDocStringCore c s!"Block {j} (`%{label}`) of function {i} (`@{f.name}`) of \
          `{pn}`{file} with {consts} (added by `mojo_family`)."
        return mkAppN (mkConst c) fvs
      let fnBody := mkAppN (mkConst ``Func.mk) #[toExpr f.linkage, toExpr f.cconv,
        toExpr f.retAttrs, toExpr f.ret, toExpr f.name, toExpr f.params, toExpr f.group,
        toExpr f.names, quoteArray (mkConst ``Block) bs]
      addDef (F ++ `fn) (← ty fvs ``Func) (← mkLambdaFVars fvs fnBody)
      addDocStringCore (F ++ `fn) s!"{pre}Function {i} (`@{f.name}`) of `{pn}`{file} with \
        {consts}: its blocks with those statements are `{nm}.b_<j>`, the others the \
        imported definitions (added by `mojo_family`)."
      -- the other functions, by the definitions the import added (same terms)
      let fns ← p.module.funcs.toList.zipIdx.mapM fun (g, i') => do
        if i' == i then return mkAppN (mkConst (F ++ `fn)) fvs
        let gbs ← g.blocks.toList.zipIdx.mapM fun (b, j) =>
          share (F ++ (`f).appendIndexAfter i' ++ (`b).appendIndexAfter j) (mkConst ``Block)
            (toExpr b)
        share (F ++ (`f).appendIndexAfter i') (mkConst ``Func) <| mkAppN (mkConst ``Func.mk)
          #[toExpr g.linkage, toExpr g.cconv, toExpr g.retAttrs, toExpr g.ret, toExpr g.name,
            toExpr g.params, toExpr g.group, toExpr g.names, quoteArray (mkConst ``Block) gbs]
      let pj (fld : Name) (e : Expr) : Expr := mkApp (mkConst fld) e
      let me := pj ``Program.module Pe
      let modE := mkAppN (mkConst ``Module.mk) #[pj ``Module.sourceFilename me,
        pj ``Module.datalayout me, pj ``Module.triple me, pj ``Module.globals me,
        quoteArray (mkConst ``Func) fns, pj ``Module.attrGroups me, pj ``Module.namedMD me,
        pj ``Module.mds me]
      let progE := mkAppN (mkConst ``Program.mk) #[modE, pj ``Program.sha256 Pe,
        pj ``Program.layout Pe, pj ``Program.intrinsics Pe, pj ``Program.kernels Pe]
      addDef (F ++ `prog) (← ty fvs ``Program) (← mkLambdaFVars fvs progE)
      addDocStringCore (F ++ `prog) s!"{pre}The program `{pn}`{file} with function {i}'s \
        {consts} (`{nm}.fn`); every other field, the digest `sha256` included, is \
        `{pn}`'s (added by `mojo_family`)."
    -- the instance at the program's own constants
    let vs := locs.map fun (_, _, _, _, v) => toExpr v
    let fi ← do
      let fbs ← f.blocks.toList.zipIdx.mapM fun (b, j) =>
        share (F ++ `base ++ (`b).appendIndexAfter j) (mkConst ``Block) (toExpr b)
      share (F ++ `base) (mkConst ``Func) <| mkAppN (mkConst ``Func.mk) #[toExpr f.linkage,
        toExpr f.cconv, toExpr f.retAttrs, toExpr f.ret, toExpr f.name, toExpr f.params,
        toExpr f.group, toExpr f.names, quoteArray (mkConst ``Block) fbs]
    let lhsP := mkAppN (mkConst (F ++ `prog)) vs
    let lhsF := mkAppN (mkConst (F ++ `fn)) vs
    let eqP ← mkEq lhsP Pe
    let eqF ← mkEq lhsF fi
    let pf := mkApp4 (mkConst ``And.intro) eqP eqF (← mkEqRefl lhsP) (← mkEqRefl lhsF)
    let tv : TheoremVal :=
      { name := F ++ `prog_corpus, levelParams := [], type := mkAnd eqP eqF, value := pf }
    addDecl (.thmDecl tv)
    let vals := " ".intercalate (locs.toList.map fun (_, _, _, _, v) => toString v)
    addDocStringCore (F ++ `prog_corpus) s!"`{pn}` is the instance of \
      `{nm}.prog` at its own constants: `{nm}.prog {vals}` is it and \
      `{nm}.fn {vals}` its function {i} (by `rfl`, checked by the kernel; added by \
      `mojo_family`)."

end MojoProof.LLVM
