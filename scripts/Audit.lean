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
* `DUPTHM`: theorems with the same statement (up to binder names) as an earlier one; both counts
  are of the library's declarations;
* `DUPDEF_tests` and `DUPTHM_tests`: the same for a test's declaration, against the library's and
  the earlier tests';
* `unused`: declarations of `MojoProof.*` (definitions, theorems, inductive types) that no other
  declaration of `MojoProof.*` or `MojoProofTest.*` mentions (a mention by a `partial def`'s
  `_unsafe_rec` counts for the `partial def`), except instances, `main`, and the audit
  targets listed in `scripts/targets.txt`;
* `equivalences`: theorems `∀ xs, f as ↔ g bs` or `∀ xs, f as = g bs` whose sides are headed by two
  different definitions of the library (two definitions of one concept), except `@[csimp]`
  theorems (a definition and the one compiled code runs for it).

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
  let mut defs : Std.HashMap (Expr × Expr × List (Expr × Expr)) Name := {}
  let mut thms : Std.HashMap Expr Name := {}
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
      match thms[th.type]? with
      | some m => dup := dup.modify (t + 1) (·.push s!"{userName n} = {userName m}")
      | none => thms := thms.insert th.type n
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
  let equivs := counted.filter fun n => !Compiler.hasCSimpAttribute env n &&
    match env.find? n with
    | some (.thmInfo t) =>
      let body := t.type.getForallBody
      let sides := if body.isAppOfArity ``Iff 2 then some (body.appFn!.appArg!, body.appArg!)
        else if body.isAppOfArity ``Eq 3 then some (body.appFn!.appArg!, body.appArg!) else none
      match sides with
      | some (a, b) =>
        match a.getAppFn.constName?, b.getAppFn.constName? with
        | some f, some g => f != g && isDef f && isDef g
        | _, _ => false
      | none => false
    | _ => false
  let names (xs : Array Name) := xs.map (toString ∘ userName)
  for (k, xs) in [("DUPDEF", dup[0]!), ("DUPTHM", dup[1]!), ("DUPDEF_tests", dup[2]!),
      ("DUPTHM_tests", dup[3]!), ("unused", names unused), ("equivalences", names equivs)] do
    IO.println s!"{k} {xs.size}"
    for x in xs do IO.println s!"  {x}"
  if let ["--deps", out] := args then
    IO.FS.writeFile out (← depsFacts env (lib ++ tests) targets).compress
  return if bad == 0 then 0 else 1
