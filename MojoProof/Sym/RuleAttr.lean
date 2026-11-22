import MojoProof.LLVM.Syntax
import MojoProof.LLVM.Intrinsic
import Lean

/-!
# The block checker's rule table: `@[mojo_rule]`

An entry of the table (`RuleEntry`) is for one or more constructors (of `MojoProof.LLVM.Inst`,
`Term` or `Intrinsic`, or of a test table's type) and a case of them (a flag pattern, type class
or intrinsic parameter, as text; empty for every case): either a rule, the lemma that proves the
checker's step for it, or a refusal with its reason.

* `@[mojo_rule C₁ … Cₙ "case"]` on a lemma, or `attribute [mojo_rule C₁ … Cₙ "case"] l` from
  another module, adds the rule `l`. The attribute is registered with `registerBuiltinAttribute`
  and its entries are kept in a `SimplePersistentEnvExtension` (`ruleExt`), not with
  `registerTagAttribute`, whose `add` refuses a declaration of an imported module
  (`throwAttrDeclInImportedModule`); so MojoProof/Sym/Rules.lean tags the lemmas of
  MojoProof/Sym/Block.lean. Each `Cᵢ` must be a constructor; the attribute is global.
* `mojo_refuse C₁ … Cₙ "case" : "reason"` adds a refusal.
* `mojo_rules_complete T₁ … Tₙ` fails, naming them, when a constructor of a type `Tᵢ` has neither
  a rule nor a refusal; it adds nothing.
* `#mojo_rules T₁ … Tₙ` logs the table, one line per constructor of the `Tᵢ`: its rules (with
  their cases) and its refusals (with their cases and reasons).

Completeness is checked per constructor: a case is text, so that the cases of a constructor's
entries cover all of it is a convention of the table (each rule's case and the refusal of the
rest), not a check. Nor does the attribute check what the lemma states: that a rule's lemma
proves the checker's step for its constructors is a convention of the table too.

This module is executable code with no theorems.
-/

open Lean Elab Command

namespace MojoProof.Sym

/-- An entry of the rule table: for the constructors `keys` and the case `case` (a flag pattern,
type class or intrinsic parameter; empty for every case), the lemma `rule` that proves the block
checker's step, or, when `rule` is `none`, a refusal with its reason `reason`. -/
structure RuleEntry where
  /-- The entry from its constructors, case, lemma and reason. -/
  mk ::
  /-- The constructors the entry is for. -/
  keys : List Name
  /-- The case of the constructors, as text; empty for every case. -/
  case : String
  /-- The lemma of a rule; `none` for a refusal. -/
  rule : Option Name
  /-- The reason of a refusal; empty for a rule. -/
  reason : String
  deriving Inhabited

/-- The rule table: the entries of the imported modules and of the current one. -/
initialize ruleExt : SimplePersistentEnvExtension RuleEntry (Array RuleEntry) ←
  registerSimplePersistentEnvExtension {
    addEntryFn := Array.push
    addImportedFn := fun as => as.foldl (· ++ ·) #[] }

/-- The identifiers of an argument list `(ident)+`, each alone or in its group node. -/
def identArgs (stx : Syntax) : Array Syntax :=
  stx.getArgs.map fun a => if a.isIdent then a else a[0]

/-- The string of an optional argument `(str)?`, alone or in its group node; empty when absent. -/
def optStr (stx : Syntax) : String :=
  ((stx.getOptional?).bind fun a => a.isStrLit? <|> a[0].isStrLit?).getD ""

/-- The constructors the identifiers `ids` name; fails at one that names no constructor. -/
def ruleKeys (ids : Array Syntax) : CoreM (List Name) := ids.toList.mapM fun id => do
  let c ← realizeGlobalConstNoOverloadWithInfo id
  unless (← getEnv).find? c matches some (.ctorInfo _) do
    throwErrorAt id "mojo_rule: {c} is not a constructor"
  return c

/-- `@[mojo_rule C₁ … Cₙ "case"]`: the attribute's syntax. -/
syntax (name := mojo_rule) "mojo_rule" (ppSpace ident)+ (ppSpace str)? : attr

initialize registerBuiltinAttribute {
  name := `mojo_rule
  descr := "a lemma of the block checker's rule table, for the constructors it names"
  applicationTime := .afterTypeChecking
  add := fun decl stx kind => do
    unless kind == .global do throwError "mojo_rule: the attribute is global"
    let keys ← ruleKeys (identArgs stx[1])
    let case := optStr stx[2]
    modifyEnv (ruleExt.addEntry · { keys, case, rule := some decl, reason := "" }) }

/-- `mojo_refuse C₁ … Cₙ "case" : "reason"`: a refusal of the rule table. -/
syntax (name := mojoRefuse) "mojo_refuse" (ppSpace ident)+ (ppSpace str)? " : " str : command

/-- Elaborates `mojo_refuse`: adds the refusal to `ruleExt`. -/
@[command_elab mojoRefuse] def elabMojoRefuse : CommandElab := fun stx => do
  let keys ← liftCoreM <| ruleKeys (identArgs stx[1])
  let some reason := stx[4].isStrLit? | throwUnsupportedSyntax
  modifyEnv (ruleExt.addEntry · { keys, case := optStr stx[2], rule := none, reason })

/-- The constructors of the inductive types the identifiers `ids` name, each with its entries in
the rule table. -/
def ruleTable (ids : Array Syntax) : CoreM (List (Name × List RuleEntry)) := do
  let es := ruleExt.getState (← getEnv)
  let ts ← ids.toList.mapM realizeGlobalConstNoOverloadWithInfo
  let cs := (← ts.mapM fun t => return (← getConstInfoInduct t).ctors).flatten
  return cs.map fun c => (c, es.toList.filter (·.keys.contains c))

/-- `mojo_rules_complete T₁ … Tₙ`: fails when a constructor of a `Tᵢ` has neither a rule nor a
refusal. -/
syntax (name := mojoRulesComplete) "mojo_rules_complete" (ppSpace ident)+ : command

/-- Elaborates `mojo_rules_complete`. -/
@[command_elab mojoRulesComplete] def elabMojoRulesComplete : CommandElab := fun stx => do
  let missing := (← liftCoreM <| ruleTable (identArgs stx[1])).filter (·.2.isEmpty) |>.map (·.1)
  unless missing.isEmpty do
    throwError "mojo_rule: no rule and no refusal for {missing}"

/-- `#mojo_rules T₁ … Tₙ`: logs the rule table of the constructors of the `Tᵢ`. -/
syntax (name := mojoRules) "#mojo_rules" (ppSpace ident)+ : command

/-- An entry of the table as text: the rule's lemma, or `refused` and the reason, after the case
in parentheses when there is one. -/
def RuleEntry.text (e : RuleEntry) : String :=
  let case := if e.case.isEmpty then "" else s!" ({e.case})"
  match e.rule with
  | some r => s!"{r.replacePrefix `MojoProof .anonymous}{case}"
  | none => s!"refused{case}: {e.reason}"

/-- Elaborates `#mojo_rules`. -/
@[command_elab mojoRules] def elabMojoRules : CommandElab := fun stx => do
  let tbl ← liftCoreM <| ruleTable (identArgs stx[1])
  logInfo <| "\n".intercalate <| tbl.map fun (c, es) =>
    s!"{c.replacePrefix c.getPrefix.getPrefix .anonymous}: {"; ".intercalate (es.map (·.text))}"

end MojoProof.Sym
