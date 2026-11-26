import Lean
import GPUProof.Spec.Import

/-!
# `import_spec`: an importer generated from its operations

`import_spec` declares a `GPUProof.Importer` from a list of operations, each given by its input
tensors, its output tensor, its meaning, the spec it is proposed as and the readings of its
tensors as the spec's entries:

```
/-- docstring of the importer -/
import_spec imp p₁ … pₖ : Src (σ : Sz) where
  /-- docstring of the operation -/
  | op (x₁ : T₁) … (xₙ : Tₙ) → (y : T) := meaning
    ↦ spec
    from reading of x₁ … xₙ as the spec's inputs
    at reading of y as the spec's outputs
```

`p₁ … pₖ` are the section variables the specs mention, in their order, and `σ` the size, of type
`Sz` at every operation. It declares, in the current namespace and with generated docstrings:

* the inductive type `Src`, one constructor per operation, with the operation's docstring;
* `Src.SIn` and `Src.SOut` (abbreviations): at `op`, the product `T₁ × … × Tₙ` and `T`;
* `Src.denote`, at `op` and the tuple `(x₁, …, xₙ)` the meaning, and `Src.translate p₁ … pₖ`, at
  `op` the spec;
* `readIn` and `readOut`, at `op`, the proof `rfl` that `translate` proposed the spec, the tuple and
  `y`, the two readings, with the unfoldings `readIn_op` and `readOut_op`, each by `rfl`;
* the importer `imp` with these fields. Its `eq` is proved at each operation by taking the inputs
  apart as the tuple, introducing the hypothesis that their reading is in the spec's domain,
  `funext` at an output, unfolding `readIn_op`, `readOut_op` and `Src.denote` in the goal, then
  `import_fact`: the goal is then the output reading of the meaning, at the output, against the
  spec's function at the input reading, with the domain hypothesis in the context.

`using t₁ … tₘ` between the size and `where` is optional: the `eq` cases are then closed by
`import_fact using t₁ … tₘ`, which tries these theorems, of the current file or of an imported
module, before those of the current file; each must name a declaration, or the command fails at
it. If no theorem tried closes the `eq` case of some operation, `imp` is not declared and the
command warns with the open goal, so that the importer can be written by hand from the other
declarations. Names the command introduces inside its terms and proofs are hygienic; the declared
names are the given ones and `readIn`, `readOut`, `readIn_op`, `readOut_op`, so one namespace
holds one importer.

`import_fact` closes an equation with a theorem found by its type: those listed after `using`, in
their order, then those of the current file not listed, in the order they were declared, each at
fresh metavariables for its arguments. The first is used whose conclusion is definitionally the
goal and whose arguments are then all assigned: by that unification, or, for an argument left
open whose type is a proposition (a premise that the conclusion does not determine, such as the
spec's domain), by a hypothesis of that type up to definitional unfolding
(`MVarId.assumptionCore`). Two cheap tests come first, so that a theorem about the same terms but
a different right side is not unfolded far (`closesBy`): its left side has a constant at its head
and is the goal's up to reducible unfolding, and its right side's head is a constant that the
goal's right side has at its head or after unfolding its head some times, or the other way round
(`unfoldHeads`).
-/

namespace MojoProof.Import

open Lean Elab Command Meta

/-- The theorems declared in the current file, in the order they were declared, with internal
names left out: the facts `import_fact` tries after those listed after its `using`. -/
def localFacts : MetaM (Array Name) := do
  let cs ← (← getEnv).getLocalConstantInfos (skipTheoremSubDecls := true)
  return cs.filterMap fun c =>
    if c.kind matches .thm && !c.name.isInternal then some c.name else none

/-- The head constants of `e` and of its successive unfoldings, for every term: the head of `e`
in weak head normal form without unfolding definitions, then the same for `e` with its head
definition unfolded once, or a projection taken of a structure in weak head normal form, until
neither applies. `import_fact` keeps the theorems whose right side's head is among those of the
goal's right side. -/
partial def unfoldHeads (e : Expr) : MetaM (Array Name) := do
  let e ← whnfCore e
  let args := e.getAppArgs
  match e.getAppFn with
  | .const n _ =>
    let next ← match ← unfoldDefinition? e with
      | some e' => pure (some e')
      | none => match ← getProjectionFnInfo? n with
        | some info =>
          if h : info.numParams < args.size then
            pure <| (← project? args[info.numParams] info.i).map fun p =>
              mkAppN p (args.extract (info.numParams + 1) args.size)
          else pure none
        | none => pure none
    match next with
    | some e' => return #[n] ++ (← unfoldHeads e')
    | none => return #[n]
  | .proj _ i c =>
    match ← project? c i with
    | some p => unfoldHeads (mkAppN p args)
    | none => return #[]
  | _ => return #[]

/-- Whether the theorem `n` closes the goal `g`, an equation with sides `gl` and `gr`, given the
heads `hs` of `gr` and of its unfoldings (`unfoldHeads`), for every goal and theorem: at fresh
metavariables for its arguments, the theorem's conclusion is an equation whose left side has a
constant at its head and is `gl` up to reducible unfolding, whose right side `r` has a constant
`c` at its head with `c` among `hs` or the head of `gr` among the heads of `r` and its unfoldings,
and which is definitionally the goal; then each argument left unassigned whose type, instantiated,
is a proposition is assigned a hypothesis of `g`'s context of that type, the last one declared,
up to definitional unfolding (`MVarId.assumptionCore`), in the order of the arguments. If every
argument is then assigned, `g` is assigned the theorem at them, and otherwise nothing is
assigned. -/
def closesBy (g : MVarId) (gl gr : Expr) (hs : Array Name) (n : Name) : MetaM Bool := do
  let s ← saveState
  let ok ← tryCatch (do
      let e ← mkConstWithFreshMVarLevels n
      let (args, _, ty) ← forallMetaTelescopeReducing (← inferType e)
      let some (_, l, r) := ty.eq? | return false
      let .const rh _ := r.getAppFn | return false
      unless l.getAppFn.isConst do return false
      unless ← withReducible (isDefEq l gl) do return false
      unless hs.contains rh ||
          (gr.getAppFn.constName?.any (← unfoldHeads (← instantiateMVars r)).contains) do
        return false
      unless ← isDefEq ty (← g.getType) do return false
      for a in args do
        let m := a.mvarId!
        unless ← m.isAssigned do
          if ← isProp (← instantiateMVars (← m.getType)) then
            discard m.assumptionCore
      let pf ← instantiateMVars (mkAppN e args)
      if pf.hasExprMVar then return false
      g.assign pf
      return true) fun _ => pure false
  unless ok do s.restore
  return ok

/-- `import_fact`, or `import_fact using t₁ … tₘ`, for every goal: closes the main goal, an
equation, with the first theorem that `closesBy` accepts, among `t₁ … tₘ` in their order (each
names a declaration of the current file or of an imported module, or the tactic fails at it), then
the theorems of the current file not among them (`localFacts`), in declaration order. It fails
with the goal if the goal is not an equation or if none closes it. -/
syntax (name := tacticImport_fact) "import_fact" (" using" (ppSpace colGt ident)+)? : tactic

elab_rules : tactic
  | `(tactic| import_fact $[using $ts*]?) => Tactic.withMainContext do
    let ts := ts.getD #[]
    let listed ← ts.mapM fun t => realizeGlobalConstNoOverloadWithInfo t
    let g ← Tactic.getMainGoal
    let some (_, gl, gr) := (← instantiateMVars (← g.getType)).eq?
      | throwError "import_fact: the goal is not an equation{indentExpr (← g.getType)}"
    let hs ← unfoldHeads gr
    for n in listed ++ (← localFacts).filter (!listed.contains ·) do
      if ← closesBy g gl gr hs n then
        Tactic.replaceMainGoal []
        return
    if listed.isEmpty then
      throwError "import_fact: no theorem of this file closes the goal{indentExpr (← g.getType)}"
    let names := ", ".intercalate (ts.toList.map fun t => s!"`{t.getId}`")
    throwError "import_fact: neither {names} nor a theorem of this file closes the goal\
      {indentExpr (← g.getType)}"

/-- One operation of `import_spec`: its docstring, its name, its input tensors as explicit binders
with one name each, its output tensor as a binder, its meaning (after `:=`), the spec it is
proposed as (after `↦`), the reading of its inputs as the spec's inputs, a term in the inputs'
names (after `from`), and the reading of its output as the spec's outputs, a term in the
output's name (after `at`). -/
syntax importOp := atomic(docComment "| ") ident (ppSpace bracketedBinder)+ " → "
  "(" ident " : " term ")" " := " term ppIndent(ppLine "↦ " term) ppIndent(ppLine "from " term)
  ppIndent(ppLine "at " term)

/-- `import_spec imp p₁ … pₖ : Src (σ : Sz) using t₁ … tₘ where | op … := … ↦ … from … at …`,
with `using t₁ … tₘ` optional: declares the operations `Src`, their tensors, meaning, proposed
specs and readings, and the importer `imp`, its `eq` closed by `import_fact using t₁ … tₘ`, as the
module docstring of `MojoProof.Import.Command` lists. -/
syntax (name := importSpec) docComment "import_spec " ident (ppSpace ident)* " : " ident
  " (" ident " : " term ")" (" using" (ppSpace ident)+)? " where" (ppLine importOp)+ : command

/-- The source text of a piece of syntax with each run of whitespace made one space, for every
syntax: how `import_spec`'s docstrings quote the given terms. -/
def flatText (s : Syntax) : String := Id.run do
  let mut out := ""
  let mut gap := false
  for c in (s.reprint.getD "").toList do
    if c.isWhitespace then
      gap := true
    else
      if gap && !out.isEmpty then out := out.push ' '
      gap := false
      out := out.push c
  return out

/-- The docstring with the text `s`, for every string. -/
def docOf (s : String) : TSyntax ``Parser.Command.docComment :=
  ⟨mkNode ``Parser.Command.docComment
    #[mkAtom "/--", mkNode ``Parser.Command.commentBody #[mkAtom s, mkAtom "-/"]]⟩

/-- `import_spec`'s elaborator, for every use: fails at a name after `using` that names no
declaration; otherwise the declarations of the module docstring of `MojoProof.Import.Command`,
then the importer, kept only if every `eq` case closes; otherwise the importer's errors are
dropped and one warning gives them. -/
@[command_elab importSpec] def elabImportSpec : CommandElab := fun stx => do
  let `($doc:docComment import_spec $imp:ident $ps:ident* : $src:ident ($σ:ident : $sz:term)
      $[using $ts*]? where $ops:importOp*) := stx | throwUnsupportedSyntax
  let ts := ts.getD #[]
  for t in ts do
    discard <| liftCoreM <| realizeGlobalConstNoOverloadWithInfo t
  let fact ← if ts.isEmpty then `(tactic| import_fact) else `(tactic| import_fact using $ts*)
  let mut docs := #[]
  let mut names := #[]
  let mut ins := #[]
  let mut outNames := #[]
  let mut outTys := #[]
  let mut means := #[]
  let mut specs := #[]
  let mut readIns := #[]
  let mut readOuts := #[]
  for op in ops do
    let `(importOp| $d:docComment | $c:ident $bs:bracketedBinder* → ($y:ident : $t:term) := $m:term
        ↦ $sp:term from $ri:term at $ro:term) := op | throwErrorAt op "import_spec: bad operation"
    let mut xs : Array (Ident × Term) := #[]
    for b in bs do
      let `(bracketedBinder| ($x:ident : $tx:term)) := b
        | throwErrorAt b "import_spec: each input is one explicit binder `(x : T)`"
      xs := xs.push (x, tx)
    docs := docs.push d
    names := names.push c
    ins := ins.push xs
    outNames := outNames.push y
    outTys := outTys.push t
    means := means.push m
    specs := specs.push sp
    readIns := readIns.push ri
    readOuts := readOuts.push ro
  let cs := names.map fun c => mkIdentFrom c (src.getId ++ c.getId)
  let tuples ← ins.mapM fun xs => do
    let ns : Array Term := xs.map (·.1)
    if ns.size = 1 then pure ns[0]! else `(($(ns[0]!), $(ns.extract 1 ns.size),*))
  let tupleText (i : Nat) : String :=
    let ns := (ins[i]!).toList.map fun (x, _) => toString x.getId
    if ns.length = 1 then ", ".intercalate ns else s!"({", ".intercalate ns})"
  let prodText (i : Nat) : String :=
    " × ".intercalate ((ins[i]!).toList.map fun (_, t) => flatText t)
  let prods ← ins.mapM fun xs => do
    let ts : Array Term := xs.map (·.2)
    ts.pop.foldrM (fun t acc => `($t × $acc)) ts.back!
  let sinId := mkIdentFrom src (src.getId ++ `SIn)
  let soutId := mkIdentFrom src (src.getId ++ `SOut)
  let denId := mkIdentFrom src (src.getId ++ `denote)
  let trId := mkIdentFrom src (src.getId ++ `translate)
  let rdIn := mkIdentFrom imp `readIn
  let rdOut := mkIdentFrom imp `readOut
  let eId := mkIdent `e
  let σs := cs.map fun _ => σ
  let code (c : Ident) : String := s!"`{c.getId}`"
  let list (f : Nat → String) : String :=
    "; ".intercalate ((List.range names.size).map f)
  let sizeText := s!"at every size `{σ.getId}`"
  let srcDoc := docOf s!"The operations of the importer `{imp.getId}`, one constructor each: \
    {", ".intercalate (names.toList.map code)}."
  let ctors ← (docs.zip names).mapM fun (d, c) => `(Parser.Command.ctor| $d:docComment | $c:ident)
  elabCommand (← `($srcDoc:docComment inductive $src where $ctors:ctor*))
  let sinDoc := docOf s!"The input tensors of each operation of `{src.getId}`, {sizeText}: \
    {list fun i => s!"{code names[i]!}, `{prodText i}`"}."
  elabCommand (← `($sinDoc:docComment abbrev $sinId : $src → $sz → Type
    $[| $cs, $σs => $prods]*))
  let soutDoc := docOf s!"The output tensor of each operation of `{src.getId}`, {sizeText}: \
    {list fun i => s!"{code names[i]!}, `{flatText outTys[i]!}`"}."
  elabCommand (← `($soutDoc:docComment abbrev $soutId : $src → $sz → Type
    $[| $cs, $σs => $outTys]*))
  let denDoc := docOf s!"The meaning of each operation of `{src.getId}`, {sizeText} and every \
    input tensors: {list fun i => s!"{code names[i]!} at `{tupleText i}`, `{flatText means[i]!}`"}."
  elabCommand (← `($denDoc:docComment noncomputable def $denId :
      ($eId : $src) → ∀ $σ:ident, $sinId $eId $σ → $soutId $eId $σ
    $[| $cs, $σs, $tuples => $means]*))
  let trDoc := docOf s!"The spec proposed for each operation of `{src.getId}`, for every value of \
    the parameters: {list fun i => s!"{code names[i]!}, `{flatText specs[i]!}`"}."
  elabCommand (← `($trDoc:docComment noncomputable def $trId :
      ($eId : $src) → Option (GPUProof.Spec $sz)
    $[| $cs => some $specs]*))
  let rinDoc := docOf s!"The input tensors of each operation of `{src.getId}` read as the \
    proposed spec's inputs, for every value of the parameters, {sizeText} and input tensors: \
    {list fun i => s!"{code names[i]!} at `{tupleText i}`, `{flatText readIns[i]!}`"}."
  elabCommand (← `($rinDoc:docComment noncomputable def $rdIn :
      GPUProof.Importer.ReadIn $src (fun _ => $sz) $sinId ($trId $ps*)
    $[| $cs, _, rfl, $σs, $tuples => $readIns]*))
  let routDoc := docOf s!"The output tensor of each operation of `{src.getId}` read as the \
    proposed spec's outputs, for every value of the parameters, {sizeText} and output tensor: \
    {list fun i => s!"{code names[i]!} at `{outNames[i]!.getId}`, `{flatText readOuts[i]!}`"}."
  elabCommand (← `($routDoc:docComment noncomputable def $rdOut :
      GPUProof.Importer.ReadOut $src (fun _ => $sz) $soutId ($trId $ps*)
    $[| $cs, _, rfl, $σs, $outNames => $readOuts]*))
  for i in [:names.size] do
    let c := names[i]!
    let binders ← ins[i]!.mapM fun (x, tx) => `(bracketedBinder| ($x : $tx))
    let lin := mkIdentFrom c (.mkSimple s!"readIn_{c.getId}")
    let linDoc := docOf s!"`readIn` at {code c} unfolded, for every value of the parameters, \
      {sizeText} and input tensors `{tupleText i}`: `{flatText readIns[i]!}`. By `rfl`."
    elabCommand (← `($linDoc:docComment theorem $lin ($σ : $sz) $binders* :
      $rdIn $ps* $(cs[i]!) $(specs[i]!) rfl $σ $(tuples[i]!) = $(readIns[i]!) := rfl))
    let lout := mkIdentFrom c (.mkSimple s!"readOut_{c.getId}")
    let y := outNames[i]!
    let loutDoc := docOf s!"`readOut` at {code c} unfolded, for every value of the parameters, \
      {sizeText} and output tensor `{y.getId}`: `{flatText readOuts[i]!}`. By `rfl`."
    elabCommand (← `($loutDoc:docComment theorem $lout ($σ : $sz) ($y : $(outTys[i]!)) :
      $rdOut $ps* $(cs[i]!) $(specs[i]!) rfl $σ $y = $(readOuts[i]!) := rfl))
  let start ← `(tactic| (intro $eId:ident; cases $eId:ident))
  let eqTac ← (List.range names.size).foldlM (init := start) fun acc i => do
      let xs : Array (Ident × Term) := ins[i]!
      let pat : Term ← if xs.size = 1 then pure xs[0]!.1 else `(⟨$(xs.map (·.1)),*⟩)
      let c : Ident := names[i]!
      let lin := mkIdentFrom c (.mkSimple s!"readIn_{c.getId}")
      let lout := mkIdentFrom c (.mkSimple s!"readOut_{c.getId}")
      `(tactic| ($acc; case $c:ident =>
        intro Sp h $σ:ident $pat:term _
        cases h
        funext o
        dsimp only [$lin:ident, $lout:ident, $denId:ident]
        all_goals $fact:tactic))
  let impCmd ← `($doc:docComment noncomputable def $imp : GPUProof.Importer where
    Src := $src
    Sz _ := $sz
    SIn := $sinId
    SOut := $soutId
    denote := $denId
    translate := $trId $ps*
    readIn := $rdIn $ps*
    readOut := $rdOut $ps*
    eq := by $eqTac:tactic)
  let s ← get
  modify fun st => { st with messages := {} }
  withScope (fun sc => { sc with opts := sc.opts.setBool `Elab.async false }) <|
    elabCommand impCmd
  let msgs := (← get).messages
  if msgs.hasErrors then
    let errs := (msgs.toList.filter (·.severity matches .error)).map (·.data)
    set s
    logWarningAt imp m!"import_spec: `{imp.getId}` is not declared, its `eq` has an open case:\n\
      {MessageData.joinSep errs "\n"}"
  else
    modify fun st => { st with messages := s.messages ++ msgs }

end MojoProof.Import
