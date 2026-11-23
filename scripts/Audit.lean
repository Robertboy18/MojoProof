import Lean

/-!
# The audit step of the gate

`lake env lean --run scripts/Audit.lean` imports every module under `MojoProof/` and
`MojoProofTest/` and checks the environment, not the text:

* axioms: every declaration of `MojoProof.*` and `MojoProofTest.*` modules (theorems and
  definitions, private ones included) depends on no axiom other than `propext`,
  `Classical.choice` and `Quot.sound`
  (`sorry` shows up as `sorryAx`, `native_decide` as an auxiliary axiom `*._native.native_decide.*`);
* `DUPDEF`: definitions with the same type and value as an earlier one, up to their own names
  (`defKey`: a definition's matchers are compared by their cases);
* `DUPTHM`: theorems with the same statement (up to binder names) as an earlier one, also after
  unfolding reducible definitions (`abbrev`s and `@[reducible]` definitions, not instances;
  `statementKey`), so a statement about an `abbrev` repeats the one about its value; a pair equal
  only after unfolding is reported with `(up to reducible unfolding)`; both counts are of the
  library's declarations;
* `DUPDEF_tests` and `DUPTHM_tests`: the same for a test's declaration, against the library's and
  the earlier tests';
* `unused`: declarations of `MojoProof.*` (definitions, theorems, inductive types) that no other
  declaration of `MojoProof.*` or `MojoProofTest.*` mentions (a mention by a `partial def`'s
  `_unsafe_rec` counts for the `partial def`), except instances, `main`, and the audit
  targets listed in `scripts/targets.txt`;
* `equivalences`: theorems `∀ xs, f as ↔ g bs` or `∀ xs, f as = g bs` whose sides are headed by two
  different definitions of the library (two definitions of one concept), except a `@[csimp]`
  theorem whose right-hand side is a private definition (the code compiled for the left-hand
  side, which nothing else names). A `@[csimp]` equality between two public definitions is
  counted. The probe module `MojoProofTest.AuditProbe` plants one theorem of each kind, and the
  audit exits with 1 unless it counts the first and not the second;
* `instances`: theorems of the library whose statement is an instance of another library
  theorem's statement, by a proof that does not use it (a specialization proved again,
  `instancesIn`). With the other theorem's universe levels and binders as metavariables
  (`forallMetaTelescope`) and this one's binders as local hypotheses, the two conclusions are
  definitionally equal at reducible transparency, and each premise of the other theorem that is
  a proof is closed by one of this theorem's hypotheses or by that assignment. A one-line
  corollary, whose proof uses the general theorem, is not counted, nor is a theorem whose proof
  reaches it through further declarations of our modules, or one that the general theorem's proof
  uses. The conclusions are indexed in a discrimination tree (without a bare metavariable and an
  `=` or `↔` between two), so each theorem is checked only against the theorems whose conclusion
  matches its own, each check bounded by 20,000 heartbeats (`instance checks` gives the number of
  checks and of those that ran out); `instances_tests`: the same for a test's theorem, against the
  library's. It covers every pair of library theorems, and every test theorem against the
  library's; it is a check, not a proof. A specialization is not found when its conclusion
  matches only after unfolding a definition that is not reducible, or when the general theorem's
  premises follow from its hypotheses only by a further proof: for example `x = .ok (m', d) →
  m'.FreeAbove` is not an instance of `∃ r, x = .ok r ∧ r.1.FreeAbove`.

The probe module also plants two theorems whose statements differ only through an `abbrev`; the
audit exits with 1 unless the duplicate comparison pairs them (`duplicates probe`). It plants a
specialization of `MojoProof.Sem.outS_of_lt` proved again by unfolding and one proved by it; the
audit exits with 1 unless the instance search reports exactly the first (`instances probe`). The
probe's theorems are compared for duplicates only with each other, and their instances are
reported apart, so no count includes them.

Auto-generated declarations (constructors, recursors, projections, matchers, equation lemmas,
`injEq`, `sizeOf_spec`, helpers of derived instances, names with macro scopes or internal
components) are not counted. Prints each count and the offending names; exits with 1 if an axiom
check fails. Checked against a planted probe (a `sorry`, a `native_decide`, a duplicate definition,
a duplicate theorem, an equivalence, unused theorems): each is reported.

With `--deps <file>` it also writes the facts of the dependency graph (`depsFacts`), which
`scripts/deps.py` turns into docs/DEPENDENCIES.md and docs/deps/. Each claim is walked by
`closure`: through the type and body of every declaration of our modules, stopping at the first
external constant.
-/

open Lean

/-- The name a user wrote: private names without their private prefix. -/
def userName (n : Name) : Name := (privateToUserName? n).getD n

/-- Name components of auto-generated declarations (after the first component). -/
def auxPart (s : String) : Bool :=
  s ∈ ["injEq", "inj", "sizeOf_spec", "ext", "ext_iff", "eq_def", "eq", "ctorIdx", "toCtorIdx",
    "noConfusionType", "noConfusion", "ofNat", "ctorElim", "ctorElimType", "brecOn", "below",
    "binductionOn", "splitter", "congr_simp"] ||
    ["eq_", "match_", "proof_", "brecOn_", "below_", "_"].any fun p : String => s.startsWith p

/-- Auto-generated declarations, which no count includes: kernel-generated and
compiler-generated ones, and the helpers of a derived instance (names under an instance). -/
def isAux (env : Environment) (n : Name) : Bool :=
  let u := userName n
  u.isInternal || u.hasMacroScopes || (u.components.drop 1).any (auxPart ·.toString) ||
    isAuxRecursor env n || isNoConfusion env n || Meta.isMatcherCore env n ||
    env.isProjectionFn n ||
    (match env.find? n with
     | some (.ctorInfo _) | some (.recInfo _) | some (.quotInfo _) => true
     | _ => false) ||
    (u.components.length > 1 && Meta.isInstanceCore env u.getPrefix)

/-- The key of a definition `n` for `DUPDEF`: its type and value, and the type and value of each
auxiliary constant its value uses, directly or through other auxiliary constants (a constant under
`n`, such as an auxiliary proof or a matcher's `casesOn` helper, or a matcher, which Lean shares
between definitions with the same `match`), with `n` renamed `_self` and the `i`-th auxiliary
constant `_aux.i`. Two definitions with one key are equal up to their names, including two
definitions that differ only in the names of their matchers (`A.match_1` and `B.match_1`). -/
def defKey (env : Environment) (n : Name) (d : DefinitionVal) : Expr × Expr × List (Expr × Expr) :=
  let isAuxOf (c : Name) := c != n && (n.isPrefixOf c || Meta.isMatcherCore env c)
  let aux : Array Name := Id.run do
    let mut aux := #[]
    let mut todo := d.value.getUsedConstants.toList.filter isAuxOf
    for _ in [0:1000] do
      match todo with
      | [] => break
      | c :: cs =>
        todo := cs
        unless aux.contains c do
          aux := aux.push c
          if let some (.defnInfo a) := env.find? c then
            todo := todo ++ a.value.getUsedConstants.toList.filter isAuxOf
    return aux
  let ren (e : Expr) : Expr := e.replace fun
    | .const c us =>
      if c == n then some (.const `_self us)
      else (aux.findIdx? (· == c)).map fun i => .const (Name.mkNum `_aux i) us
    | _ => none
  (ren d.type, ren d.value, aux.toList.filterMap fun c =>
    match env.find? c with
    | some (.defnInfo a) => some (ren a.type, ren a.value)
    | some ci => some (ren ci.type, .sort 0)
    | none => none)

/-- Whether the duplicate comparison unfolds constant `c`: a reducible definition (an `abbrev`
or a `@[reducible] def`) that is not an instance. -/
def unfoldable (env : Environment) (c : Name) : Bool :=
  getReducibilityStatusCore env c == .reducible && !Meta.isInstanceCore env c &&
    env.find? c matches some (.defnInfo _)

/-- `e` with each constant that `vals` has a value for replaced by that value at the constant's
universe levels, each application of one beta reduced. -/
partial def unfoldWith (env : Environment) (vals : Std.HashMap Name Expr) (e : Expr) : Expr :=
  e.replace fun x =>
    match x.getAppFn with
    | .const c us => vals[c]?.map fun v =>
      let ps := (env.find? c).map (·.levelParams) |>.getD []
      (v.instantiateLevelParams ps us).beta (x.getAppArgs.map (unfoldWith env vals))
    | _ => none

/-- Adds to the cache the value, with `unfoldWith` applied, of each constant that `unfoldable`
accepts and that `e` uses, directly or through such values. A constant met again while its own
value is being unfolded stays folded. -/
partial def prepare (env : Environment) (e : Expr) : StateM (Std.HashMap Name Expr) Unit := do
  for c in e.getUsedConstants do
    if !(← get).contains c && unfoldable env c then
      let some (.defnInfo d) := env.find? c | continue
      modify (·.insert c (.const c (d.levelParams.map .param)))
      prepare env d.value
      modify fun vals => vals.insert c (unfoldWith env vals d.value)

/-- The key of a statement for `DUPTHM`: the statement with every reducible definition that is
not an instance unfolded (`unfoldable`), through the values of the cache, which it extends. -/
def statementKey (env : Environment) (ty : Expr) : StateM (Std.HashMap Name Expr) Expr := do
  prepare env ty
  return unfoldWith env (← get) ty

/-- The axioms a constant depends on, with a cache shared across constants. -/
partial def axiomsOf (env : Environment) (n : Name) :
    StateM (Std.HashMap Name (Array Name)) (Array Name) := do
  if let some r := (← get)[n]? then return r
  modify (·.insert n #[])  -- cycles (mutual definitions) contribute nothing twice
  let r ← match env.find? n with
    | some (.axiomInfo _) => pure #[n]
    | some ci => do
      let mut acc : Array Name := #[]
      for c in ci.getUsedConstantsAsSet do
        for a in ← axiomsOf env c do
          unless acc.contains a do acc := acc.push a
      pure acc
    | none => pure #[]
  modify (·.insert n r)
  return r

/-- Module names of the `.lean` files under `dir` (relative to the working directory). -/
partial def modulesIn (dir : System.FilePath) : IO (Array Name) := do
  let mut acc := #[]
  for e in ← dir.readDir do
    if ← e.path.isDir then acc := acc ++ (← modulesIn e.path)
    else if e.path.extension == some "lean" then
      let parts := (e.path.withExtension "").components
      acc := acc.push (parts.foldl (fun n s => if s == "." then n else .str n s) .anonymous)
  return acc

/-- The constants reachable from `root` through the type and body of each constant that `within`
accepts; a constant outside it is reached but not expanded. This is the transitive walk of the
claims in docs/DEPENDENCIES.md. -/
def closure (env : Environment) (within : Name → Bool) (root : Name) : NameSet := Id.run do
  let mut pending := [root]
  let mut seen : NameSet := {}
  repeat
    match pending with
    | [] => break
    | n :: rest =>
      pending := rest
      unless seen.contains n do
        seen := seen.insert n
        if within n then
          if let some ci := env.find? n then
            pending := ci.getUsedConstantsAsSet.toList ++ pending
  return seen

/-- The package of an imported module: the directory under `.lake/packages/` that holds its
`.olean` file, `lean4` for the toolchain's modules, `MojoProof` for ours. -/
def packageOf (sysroot : System.FilePath) (m : Name) : IO String := do
  let p := (← findOLean m).toString
  match p.splitOn "/.lake/packages/" with
  | [_, rest] => return (rest.splitOn "/").headD ""
  | _ => return if p.startsWith sysroot.toString then "lean4" else "MojoProof"

/-- Whether a claim reaching `reach` (of which `oursIn` are ours, with their modules) rests on the
anchor `kind arg` of `scripts/trust.tsv`: `all`; `module m`, some declaration of module `m`;
`modules p`, some declaration of a module under `p`; `const c`, the constant `c`. -/
def anchored (reach : NameSet) (oursIn : Array (Name × Name)) : String → String → Bool
  | "all", _ => true
  | "module", m => oursIn.any (·.2 == m.toName)
  | "modules", p => oursIn.any (p.toName.isPrefixOf ·.2)
  | "const", c => reach.contains c.toName
  | _, _ => false

/-- The facts of docs/DEPENDENCIES.md as JSON, for `scripts/deps.py`: the number of modules loaded
from each package; each of our modules with its imports and their packages; for each claim (a theorem among the audit targets) the declarations of
ours it reaches (`closure`, auto-generated ones not listed), the external constants it reaches by
package, its axioms, and its TRUST ids (the anchors of `scripts/trust.tsv`). Throws on an anchor
of an unknown kind or constant. -/
def depsFacts (env : Environment) (ourMods : Array Name) (targets : List Name) : IO Json := do
  let sysroot ← findSysroot
  let mods := env.header.moduleNames
  let mut pkg : Std.HashMap Name String := {}
  let mut loaded : Std.HashMap String Nat := {}
  for m in mods do
    let p ← packageOf sysroot m
    pkg := pkg.insert m p
    loaded := loaded.alter p fun k => some (k.getD 0 + 1)
  let modOf (n : Name) : Name := ((env.getModuleIdxFor? n).map (mods[·.toNat]!)).getD .anonymous
  let within (n : Name) : Bool := ourMods.contains (modOf n)
  let anchors := (← IO.FS.lines "scripts/trust.tsv").toList.filterMap fun l =>
    match l.splitOn "\t" with
    | [t, k, a] => some (t, k, a)
    | [t, k] => some (t, k, "")
    | _ => none
  for (t, k, a) in anchors do
    unless ["all", "module", "modules", "const"].contains k do throw (.userError s!"{t}: kind {k}")
    if k == "const" && !env.contains a.toName then throw (.userError s!"{t}: no constant {a}")
    if k == "module" && !ourMods.contains a.toName then throw (.userError s!"{t}: no module {a}")
  let modules := ourMods.map fun m =>
    let imps := (env.header.moduleData[(env.getModuleIdx? m).get!.toNat]!).imports.map (·.module)
    Json.mkObj [("name", toJson m.toString), ("package", toJson "MojoProof"),
      ("imports", toJson (imps.map fun i => #[i.toString, pkg.getD i ""]))]
  let mut claims := #[]
  let mut cache := {}
  for t in targets do
    let some (.thmInfo _) := env.find? t | continue
    let reach := closure env within t
    let oursIn := reach.toArray.filterMap fun n =>
      if within n && !isAux env n then some (n, modOf n) else none
    let mut ext : Std.HashMap String (Array String) := {}
    for n in reach do
      unless within n do
        ext := ext.alter (pkg.getD (modOf n) "") fun o => some ((o.getD #[]).push n.toString)
    let (axs, c) := (axiomsOf env t).run cache
    cache := c
    let trust := anchors.filter (fun (_, k, a) => anchored reach oursIn k a) |>.map (·.1) |>.eraseDups
    claims := claims.push <| Json.mkObj [("name", toJson t.toString),
      ("module", toJson (modOf t).toString),
      ("ours", toJson (oursIn.map fun (n, m) => #[(userName n).toString, m.toString])),
      ("external", Json.mkObj (ext.toList.map fun (p, cs) => (p, toJson cs))),
      ("axioms", toJson (axs.map toString)), ("trust", toJson trust)]
  return Json.mkObj [("packages", Json.mkObj (loaded.toList.map fun (p, k) => (p, toJson k))),
    ("modules", toJson modules), ("claims", toJson claims)]

/-- Whether theorem `n` is an equivalence: its statement is `∀ xs, f as ↔ g bs` or
`∀ xs, f as = g bs` with `f` and `g` two different constants that `isDef` accepts, and it is not
a `@[csimp]` theorem whose right-hand side `g` is private (the code compiled for `f`). -/
def isEquiv (env : Environment) (isDef : Name → Bool) (n : Name) : Bool :=
  match env.find? n with
  | some (.thmInfo t) =>
    let body := t.type.getForallBody
    let sides := if body.isAppOfArity ``Iff 2 then some (body.appFn!.appArg!, body.appArg!)
      else if body.isAppOfArity ``Eq 3 then some (body.appFn!.appArg!, body.appArg!) else none
    match sides with
    | some (a, b) =>
      match a.getAppFn.constName?, b.getAppFn.constName? with
      | some f, some g => f != g && isDef f && isDef g &&
          !(Compiler.hasCSimpAttribute env n && isPrivateName g)
      | _, _ => false
    | none => false
  | _ => false

section Instances
open Meta

/-- Closes the premises `ms` of a theorem whose binders are metavariables, in order: each one that
is still unassigned and is a proof of a proposition is assigned one of the hypotheses `hyps`
whose type is definitionally equal to its type at the transparency in force, backtracking over
the choices. A binder that is not a proof (data, an instance) is left as the conclusion and the
premises closed assign it, or unassigned. -/
partial def closePremises (hyps : Array Expr) : List Expr → MetaM Bool
  | [] => return true
  | m :: ms => do
    if ← m.mvarId!.isAssigned then return ← closePremises hyps ms
    let t ← instantiateMVars (← inferType m)
    unless ← isProp t do return ← closePremises hyps ms
    for h in hyps do
      let mctx ← getMCtx
      if ← isDefEq t (← inferType h) then
        m.mvarId!.assign h
        if ← closePremises hyps ms then return true
      setMCtx mctx
    return false

/-- Whether a statement with the local hypotheses `hyps` and the conclusion `concl` is an instance
of theorem `a`'s statement: with `a`'s universe levels and binders as metavariables
(`forallMetaTelescope`, no unfolding), `a`'s conclusion is definitionally equal to `concl` at
reducible transparency, and each of `a`'s premises that is a proof is closed by one of `hyps` or
by that assignment (`closePremises`). Leaves the state as it was. -/
def isInstanceOf (a : ConstantInfo) (hyps : Array Expr) (concl : Expr) : MetaM Bool :=
  withoutModifyingState <| withNewMCtxDepth <| withReducible do
    let us ← a.levelParams.mapM fun _ => mkFreshLevelMVar
    let (ms, _, c) ← forallMetaTelescope (a.type.instantiateLevelParams a.levelParams us)
    if ← isDefEq c concl then closePremises hyps ms.toList else return false

/-- The constants that the proof `v` of theorem `b` mentions, with those of every declaration
under `b`'s name that it reaches (an auxiliary proof `b.proof_1`, a matcher of `b`). -/
def proofConsts (env : Environment) (b : Name) (v : Expr) : NameSet := Id.run do
  let mut seen : NameSet := {}
  let mut todo := v.getUsedConstants.toList
  repeat
    match todo with
    | [] => break
    | c :: cs =>
      todo := cs
      unless seen.contains c do
        seen := seen.insert c
        if b.isPrefixOf c && c != b then
          if let some ci := env.find? c then todo := ci.getUsedConstantsAsSet.toList ++ todo
  return seen

/-- The discrimination tree of the conclusions of the theorems `as` (their binders opened as
metavariables, `forallMetaTelescope`, keys at reducible transparency), without the conclusions
that every statement of their logical form matches: a metavariable, and an equation or `↔`
between two metavariables. -/
def conclusionTree (env : Environment) (as : Array Name) : MetaM (DiscrTree Name) := do
  let mut tree : DiscrTree Name := {}
  for a in as do
    let some (.thmInfo t) := env.find? a | continue
    let keys ← withoutModifyingState <| withNewMCtxDepth do
      let (_, _, c) ← forallMetaTelescope t.type
      DiscrTree.mkPath c
    unless keys == #[.star] || keys == #[.const ``Eq 3, .star, .star, .star] ||
        keys == #[.const ``Iff 2, .star, .star] do
      tree := tree.insertKeyValue keys a
  return tree

/-- The pairs `(b, a)` of the `instances` count, for the theorems `bs` and the theorems of `tree`
(`conclusionTree`): `b`'s statement is an instance of `a`'s (`isInstanceOf`, with `b`'s binders
as local hypotheses, no unfolding), `a ≠ b`, and neither proof reaches the other theorem, through
the declarations that `within` accepts (`closure`; a one-line corollary of `a` reaches `a`). The
candidates for `b` are the theorems of `tree` whose conclusion matches `b`'s; each check is
bounded by `beats` heartbeats. Also gives the instances whose proof reaches the other theorem only
through further declarations (not counted), the number of checks, and the number that ran out. -/
def instancesIn (env : Environment) (within : Name → Bool) (tree : DiscrTree Name) (bs : Array Name)
    (beats : Nat) : MetaM (Array (Name × Name) × Array (Name × Name) × Nat × Nat) := do
  let mut hits := #[]
  let mut reached := #[]
  let mut checks := 0
  let mut out := 0
  for b in bs do
    let some (.thmInfo tb) := env.find? b | continue
    let used := proofConsts env b tb.value
    let (found, n, o) ← forallTelescope tb.type fun xs concl => do
      let hyps ← xs.filterM fun x => do isProp (← inferType x)
      let mut found := #[]
      let mut n := 0
      let mut o := 0
      for a in ← tree.getMatch concl do
        if a == b || used.contains a then continue
        let some ca@(.thmInfo ta) := env.find? a | continue
        if (proofConsts env a ta.value).contains b then continue
        n := n + 1
        let r ← tryCatchRuntimeEx (some <$> withCurrHeartbeats
            (withTheReader Core.Context ({ · with maxHeartbeats := beats })
              (isInstanceOf ca hyps concl))) fun _ => pure none
        match r with
        | some true => found := found.push a
        | some false => pure ()
        | none => o := o + 1
      return (found, n, o)
    checks := checks + n
    out := out + o
    for a in found do
      if (closure env within b).contains a || (closure env within a).contains b then
        reached := reached.push (b, a)
      else
        hits := hits.push (b, a)
  return (hits, reached, checks, out)

/-- `M:line`, the module and line of declaration `n`, or `M` if the line is not recorded. -/
def declPos (env : Environment) (n : Name) : MetaM String := do
  let m := ((env.getModuleIdxFor? n).map (env.header.moduleNames[·.toNat]!)).getD .anonymous
  match ← findDeclarationRanges? n with
  | some r => return s!"{m}:{r.range.pos.line}"
  | none => return s!"{m}"

end Instances

/-- Runs the audit; `unsafe` because loading the imported extensions runs initializers. -/
unsafe def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let lib ← modulesIn "MojoProof"
  let tests ← modulesIn "MojoProofTest"
  let env ← importModules ((lib ++ tests).map ({ module := · })) {} (trustLevel := 1024)
    (loadExts := true)
  let ours (mods : Array Name) : Array Name := Id.run do
    let mut acc := #[]
    for i in [0:env.header.moduleNames.size] do
      if mods.contains env.header.moduleNames[i]! then
        acc := acc ++ env.header.moduleData[i]!.constNames
    return acc
  let libDecls := ours lib
  let allDecls := libDecls ++ ours tests
  let targets := (← IO.FS.lines "scripts/targets.txt").toList.filter (· ≠ "") |>.map String.toName
  -- axioms
  let allowed := [``propext, ``Classical.choice, ``Quot.sound]
  let mut bad := 0
  let mut cache := {}
  for n in allDecls do
    let (axs, c) := (axiomsOf env n).run cache
    cache := c
    let extra := axs.filter (!allowed.contains ·)
    unless extra.isEmpty do
      bad := bad + 1
      IO.println s!"AXIOM {userName n}: {extra.toList}"
  IO.println s!"axioms: {allDecls.size} declarations checked ({libDecls.size} of the library), \
    {bad} with axioms beyond {allowed}"
  -- duplicates, of the library's declarations and, counted apart, the tests' (a test's copy of a
  -- library definition is reported after it)
  let counted := libDecls.filter fun n => !isAux env n
  let probe := `MojoProofTest.AuditProbe
  let mut defs : Std.HashMap (Expr × Expr × List (Expr × Expr)) Name := {}
  -- theorems by `statementKey`, the probe's apart; `vals`: the unfolded reducible definitions
  let mut thms : Std.HashMap Expr Name := {}
  let mut probeThms : Std.HashMap Expr Name := {}
  let mut probeDups : Array (Name × Name) := #[]
  let mut vals : Std.HashMap Name Expr := {}
  -- `dup[0]` and `dup[1]`: the library's DUPDEF and DUPTHM; `dup[2]` and `dup[3]`: the tests'
  let mut dup : Array (Array String) := #[#[], #[], #[], #[]]
  for i in [0:allDecls.size] do
    let n := allDecls[i]!
    if isAux env n then continue
    let t := if i < libDecls.size then 0 else 2
    match env.find? n with
    | some (.defnInfo d) =>
      if d.safety == .safe && !Meta.isInstanceCore env n then
        let k := defKey env n d
        match defs[k]? with
        | some m => dup := dup.modify t (·.push s!"{userName n} = {userName m}")
        | none => defs := defs.insert k n
    | some (.thmInfo th) =>
      let (k, v) := (statementKey env th.type).run vals
      vals := v
      if probe.isPrefixOf (userName n) then
        match probeThms[k]? with
        | some m => probeDups := probeDups.push (n, m)
        | none => probeThms := probeThms.insert k n
      else
        match thms[k]? with
        | some m =>
          let same := (env.find? m).any (·.type == th.type)
          dup := dup.modify (t + 1)
            (·.push s!"{userName n} = {userName m}{if same then "" else " (up to reducible unfolding)"}")
        | none => thms := thms.insert k n
    | _ => pure ()
  -- unused
  let mut used : Std.HashSet Name := {}
  for d in allDecls do
    if let some ci := env.find? d then
      for c in ci.getUsedConstantsAsSet do
        -- the members of a `partial def` call each other through their `_unsafe_rec`
        let c := match c with | .str p "_unsafe_rec" => p | _ => c
        unless c == d || (userName c).isPrefixOf (userName d) do used := used.insert c
  let unused := counted.filter fun n =>
    match env.find? n with
    | some ci => !used.contains n && !Meta.isInstanceCore env n && !targets.contains (userName n) &&
        userName n != `main && !ci.isUnsafe &&
        (ci matches .defnInfo _ | .thmInfo _ | .inductInfo _ | .opaqueInfo _)
    | none => false
  -- equivalences
  let isDef (c : Name) := counted.contains c && (env.find? c matches some (.defnInfo _))
  let equivs := counted.filter (isEquiv env isDef)
  -- the probe: a public-to-public `@[csimp]` equality is counted, one with a private right-hand
  -- side is not
  let inProbe (c : Name) := probe.isPrefixOf (userName c) &&
    (env.find? c matches some (.defnInfo _))
  let probeOk := isEquiv env inProbe (probe ++ `addZero_csimp) &&
    !isEquiv env inProbe (probe ++ `zeroAdd_csimp)
  IO.println s!"equivalences probe: {if probeOk then "ok" else "FAILED"}"
  -- the duplicates probe: two theorems whose statements differ only through an `abbrev` pair
  let pA := probe ++ `pairAbbrev_lt
  let pB := probe ++ `pair_lt
  let differ := match env.find? pA, env.find? pB with
    | some a, some b => a.type != b.type
    | _, _ => false
  let dupOk := differ && probeDups.any fun (a, b) => (a == pA && b == pB) || (a == pB && b == pA)
  IO.println s!"duplicates probe: {if dupOk then "ok" else "FAILED"}"
  -- instances: a theorem whose statement is an instance of a library theorem's, by a proof that
  -- does not reach it; the library's theorems against each other, the tests' against the library's
  let isThm (n : Name) := env.find? n matches some (.thmInfo _)
  let libThms := counted.filter isThm
  let testThms := (ours tests).filter fun n => !isAux env n && isThm n
  let modOf (n : Name) : Name :=
    ((env.getModuleIdxFor? n).map (env.header.moduleNames[·.toNat]!)).getD .anonymous
  let within (n : Name) : Bool := (lib ++ tests).contains (modOf n)
  let ctx : Core.Context := { fileName := "<audit>", fileMap := default, maxHeartbeats := 0 }
  let search : Meta.MetaM (Array (Name × Name) × Array (Name × Name) × Nat × Nat × Array String ×
      Array String) := do
    let tree ← conclusionTree env libThms
    let (l, r₁, n₁, o₁) ← instancesIn env within tree libThms (20000 * 1000)
    let (t, r₂, n₂, o₂) ← instancesIn env within tree testThms (20000 * 1000)
    let pairPos (p : Name × Name) : Meta.MetaM String := do
      return s!"{userName p.1} ({← declPos env p.1}) of {userName p.2} ({← declPos env p.2})"
    return (l, t, n₁ + n₂, o₁ + o₂, ← (l ++ t).mapM pairPos, ← (r₁ ++ r₂).mapM pairPos)
  let ((libHits, testHits, checks, outs, shown, shownReached), _) ←
    (search.run' {} {}).toIO ctx { env }
  let inProbeB (p : Name × Name) := probe.isPrefixOf (userName p.1)
  let probeHits := testHits.filter inProbeB
  let instOk := probeHits.size == 1 && probeHits.all fun (b, a) =>
    b == probe ++ `outS_eight && a == `MojoProof.Sem.outS_of_lt
  IO.println s!"instances probe: {if instOk then "ok" else "FAILED"}"
  IO.println s!"instance checks: {checks}, {outs} out of heartbeats; instances whose proof reaches \
    the general theorem through other declarations, not counted: {shownReached.size}"
  for x in shownReached do IO.println s!"  {x}"
  let shownLib := shown.extract 0 libHits.size
  let shownTests := (shown.extract libHits.size shown.size).toList.zip testHits.toList
    |>.filter (!inProbeB ·.2) |>.map (·.1) |>.toArray
  let names (xs : Array Name) := xs.map (toString ∘ userName)
  for (k, xs) in [("DUPDEF", dup[0]!), ("DUPTHM", dup[1]!), ("DUPDEF_tests", dup[2]!),
      ("DUPTHM_tests", dup[3]!), ("unused", names unused), ("equivalences", names equivs),
      ("instances", shownLib), ("instances_tests", shownTests)] do
    IO.println s!"{k} {xs.size}"
    for x in xs do IO.println s!"  {x}"
  if let ["--deps", out] := args then
    IO.FS.writeFile out (← depsFacts env (lib ++ tests) targets).compress
  return if bad == 0 && probeOk && dupOk && instOk then 0 else 1
