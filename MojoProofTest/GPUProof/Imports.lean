import GPUProof.Chunks
import GPUProof.Laminar
import GPUProof.Layout.Algebra
import GPUProof.Layout.Basic
import GPUProof.Layout.Bits
import GPUProof.Layout.Crd
import GPUProof.Layout.Laws
import GPUProof.Layout.Swizzle
import GPUProof.Layout.TwoLevel
import GPUProof.MixedRadix
import GPUProof.NaN
import GPUProof.OneRun
import GPUProof.Race
import GPUProof.Run
import GPUProof.Sig
import GPUProof.Sound
import GPUProof.Spec.Basic
import GPUProof.Spec.Comp
import GPUProof.Spec.CompGraded
import GPUProof.Spec.DecEq
import GPUProof.Spec.Import
import GPUProof.Spec.Linear
import GPUProof.Transfer
import GPUProof.Uses
import GPUProof.View
import Lean.Elab.Command

/-!
# The core's imports

The core, `lean_lib GPUProof` (the modules under `GPUProof/`), names no front end. This test reads
the import graph from the environment, each imported module with the imports its `.olean` file
records, not from the files' text, and fails the build unless:

* every core module imports directly only modules `GPUProof.*`, `Mathlib.*`, `FloatLib` and
  `FloatLib.*`, besides `Init`, which every module imports implicitly (`badImports` is empty);
* the import closure of the core modules has no module whose first component starts with
  `MojoProof` or `TorchLean` (`frontEnds` is empty);
* every `.lean` file under `GPUProof/` is a module of this test's environment, so the two checks
  cover every core module (a new core module is imported here).

`badImports` and `frontEnds` are functions of a graph. The `#guard`s check that they refuse a
small graph with one more import, of a `MojoProof.*` module, of a `TorchLean.*` module, or of a
module that is neither, directly from a core module or through a `Mathlib.*` module; the check of
the environment also refuses the core's graph with one more import of `MojoProof.Sem.Trace` and
of `TorchLean.Tensor`.
-/

namespace MojoProofTest.GPUProof.Imports

open Lean

/-- An import graph: modules, each with its direct imports. -/
abbrev Graph := List (Name × List Name)

/-- `m` is a module strictly under `p`, a module `p.*`. -/
def under (p m : Name) : Bool := p != m && p.isPrefixOf m

/-- The modules a core module may import directly: `GPUProof.*`, `Mathlib.*`, `FloatLib`,
`FloatLib.*`, and `Init`, which every module imports implicitly. -/
def allowed (m : Name) : Bool :=
  under `GPUProof m || under `Mathlib m || m == `FloatLib || under `FloatLib m || m == `Init

/-- The direct imports of the core modules (`GPUProof.*`) of `g` that `allowed` refuses, each
with its module. -/
def badImports (g : Graph) : List (Name × Name) :=
  g.flatMap fun (m, is) => if under `GPUProof m then (is.filter (!allowed ·)).map (m, ·) else []

/-- The modules reachable from the list `todo` by the imports `imps`, added to `seen`, in at most
`fuel` steps; each step visits the first module of `todo`. -/
def reach (imps : NameMap (List Name)) : Nat → List Name → NameSet → NameSet
  | 0, _, seen => seen
  | _ + 1, [], seen => seen
  | fuel + 1, m :: todo, seen =>
    if seen.contains m then reach imps fuel todo seen
    else reach imps fuel (((imps.find? m).getD []) ++ todo) (seen.insert m)

/-- The import closure of the core modules of `g`: the modules reachable from them by the imports
of `g`, the core modules included. The list of modules to visit gets every core module once and
the imports of each module once, so the number of core modules plus the number of imports bounds
the steps. -/
def closure (g : Graph) : NameSet :=
  let core := (g.filter fun (m, _) => under `GPUProof m).map (·.1)
  let imps := g.foldl (fun r (m, is) => r.insert m is) ({} : NameMap (List Name))
  reach imps (core.length + (g.map (·.2.length)).sum) core {}

/-- A front end's module: one whose first component starts with `MojoProof` or `TorchLean`. -/
def frontEnd (m : Name) : Bool :=
  (m.getRoot.toString.startsWith "MojoProof") || (m.getRoot.toString.startsWith "TorchLean")

/-- The front ends' modules in the import closure of the core modules of `g`. -/
def frontEnds (g : Graph) : List Name := Id.run do
  let mut r := []
  for m in closure g do
    if frontEnd m then r := m :: r
  return r.reverse

/-- A small import graph that passes both checks, a test fixture: two core modules, one importing
the other, Mathlib and FloatLib. -/
def small : Graph :=
  [(`GPUProof.A, [`Init, `GPUProof.B, `Mathlib.Logic.Relation, `FloatLib]),
   (`GPUProof.B, [`Init, `FloatLib.Numerics.Reduction.Tree]),
   (`Mathlib.Logic.Relation, [`Init, `Mathlib.Order.Basic]),
   (`Mathlib.Order.Basic, [`Init]), (`FloatLib, [`Init]),
   (`FloatLib.Numerics.Reduction.Tree, [`Init]), (`Init, [])]

/-- `small` with the module `m` imported by the module `byM`, a test fixture. -/
def plus (byM m : Name) : Graph :=
  small.map fun (n, is) => if n == byM then (n, is ++ [m]) else (n, is)

#guard badImports small == [] && frontEnds small == []
#guard (closure small).contains `Mathlib.Order.Basic && !(closure small).contains `Lean
-- a core module importing a front end's module: both checks refuse it
#guard badImports (plus `GPUProof.B `MojoProof.Sem.Trace) == [(`GPUProof.B, `MojoProof.Sem.Trace)]
#guard frontEnds (plus `GPUProof.B `MojoProof.Sem.Trace) == [`MojoProof.Sem.Trace]
#guard badImports (plus `GPUProof.A `TorchLean.Tensor) == [(`GPUProof.A, `TorchLean.Tensor)]
#guard frontEnds (plus `GPUProof.A `TorchLean.Tensor) == [`TorchLean.Tensor]
#guard frontEnds (plus `GPUProof.A `MojoProofTest.Bad) == [`MojoProofTest.Bad]
-- through an allowed module: only the closure's check refuses it
#guard badImports (plus `Mathlib.Order.Basic `TorchLean.Spec) == [] &&
  frontEnds (plus `Mathlib.Order.Basic `TorchLean.Spec) == [`TorchLean.Spec]
#guard frontEnds (plus `FloatLib `MojoProofKernels.Vadd) == [`MojoProofKernels.Vadd]
-- a module that is neither a front end's nor allowed: only the direct check refuses it
#guard badImports (plus `GPUProof.A `Lean.Elab.Command) == [(`GPUProof.A, `Lean.Elab.Command)] &&
  frontEnds (plus `GPUProof.A `Lean.Elab.Command) == []
#guard badImports (plus `GPUProof.A `FloatLibExtra) == [(`GPUProof.A, `FloatLibExtra)]
#guard badImports (plus `GPUProof.A `Mathlib) == [(`GPUProof.A, `Mathlib)]

/-- The import graph of `env`: every imported module with the imports its `.olean` file records.
-/
def envGraph (env : Environment) : Graph :=
  (List.range env.header.moduleNames.size).map fun i =>
    (env.header.moduleNames[i]!, (env.header.moduleData[i]!.imports.map (·.module)).toList)

/-- The modules of the `.lean` files under `root/GPUProof`. -/
def coreFiles (root : System.FilePath) : IO (List Name) := do
  let n := root.components.length
  let files ← System.FilePath.walkDir (root / "GPUProof")
  return (files.toList.filter (·.extension == some "lean")).map fun p =>
    ((p.withExtension "").components.drop n).foldl (fun m s => .str m s) .anonymous

open Elab Command in
/-- Throws unless the import graph of this environment passes `badImports` and `frontEnds` and
every `.lean` file under `GPUProof/` (next to this file's `MojoProofTest/`) is one of its modules;
then logs the core modules checked and the two mutants of the graph refused. -/
def checkCore : CommandElabM Unit := do
  let env ← getEnv
  let g := envGraph env
  let bad := badImports g
  unless bad.isEmpty do
    throwError "core modules import outside GPUProof.*, Mathlib.* and FloatLib: {toString bad}"
  let fe := frontEnds g
  unless fe.isEmpty do
    throwError "the core's import closure has a front end's modules: {toString fe}"
  let here := System.FilePath.mk (← getFileName)
  let root := ((here.parent.bind (·.parent)).bind (·.parent)).getD ⟨"."⟩
  let missing := (← coreFiles root).filter (!env.header.moduleNames.contains ·)
  unless missing.isEmpty do
    throwError "core modules this test does not import: {toString missing}"
  let core := (g.filter fun (m, _) => under `GPUProof m).map (·.1)
  logInfo m!"core modules: {toString core}"
  for m in [`MojoProof.Sem.Trace, `TorchLean.Tensor] do
    let g' := g.map fun (n, is) => if n == `GPUProof.OneRun then (n, is ++ [m]) else (n, is)
    if badImports g' == [(`GPUProof.OneRun, m)] && frontEnds g' == [m] then
      logInfo m!"refused: GPUProof.OneRun importing {m}"

/--
info: core modules: [GPUProof.Sig, GPUProof.Race, GPUProof.Chunks, GPUProof.Laminar,
  GPUProof.Layout.Basic, GPUProof.Layout.Algebra, GPUProof.Layout.Crd, GPUProof.Layout.Laws,
  GPUProof.Layout.Bits, GPUProof.Layout.Swizzle, GPUProof.Layout.TwoLevel, GPUProof.MixedRadix,
  GPUProof.NaN, GPUProof.OneRun, GPUProof.Run, GPUProof.Sound, GPUProof.Spec.Basic,
  GPUProof.Spec.Comp, GPUProof.Spec.CompGraded, GPUProof.Spec.DecEq, GPUProof.Spec.Import,
  GPUProof.Spec.Linear, GPUProof.Transfer, GPUProof.Uses, GPUProof.View]
---
info: refused: GPUProof.OneRun importing MojoProof.Sem.Trace
---
info: refused: GPUProof.OneRun importing TorchLean.Tensor
-/
#guard_msgs (whitespace := lax) in
#eval checkCore

end MojoProofTest.GPUProof.Imports
