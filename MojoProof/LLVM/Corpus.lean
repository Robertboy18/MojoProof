import MojoProof.LLVM.Quote

/-!
# The corpus as Lean terms: mojo_corpus

`mojo_corpus "<path>" as <name> "<directory>" ...` takes the rows of `tests/corpus/MANIFEST.tsv`
that its arguments name, in the order of the arguments (a path names its row, a directory every
row under it; no argument names every row), and runs `mojo_import`'s steps on each: the file's
SHA-256 must be the row's digest, and the importer (`parse`, then `Module.check`) must accept the
file, unless `tests/corpus/REFUSALS.tsv` (no file: no refusals) lists it, when it must refuse it
with exactly the listed reason and nothing is added. An accepted file is added by `mojo_import`'s
core (`quoteProgram`: the definitions of its blocks, functions, module and program, the evaluation
check and the printed-token check), in the current namespace, under the name its argument gives
with `as` (the argument, a path or a directory, must then name one row, not a refused one), or
else under its path: each component up to its first `.` (`mgemm/k.nvptx.ll` is `mgemm.k`,
`corpusName`), with a docstring naming the file. It fails when an argument names no row, when a row
is named twice, when `REFUSALS.tsv` lists a path with no row, and at the first row that fails a
check (`corpusPlan`, `corpusRow`). Because blocks and functions
are shared by term (`share`), the arguments' order fixes which import names a shared one: an
earlier import's names are kept when later ones are added.

`#mojo_corpus`, with the same arguments, runs the same checks, adds nothing (each row's
definitions are discarded after its checks) and logs the number of rows, imported and refused.

MojoProof/Kernels.lean imports vector_addition, vector_multiply and tiled_matmul with it, as
`vadd`, `vmul` and `matmul`; MojoProofTest/Corpus.lean checks every row with `#mojo_corpus`. The
option `mojo_import.root` names the directory, as for `mojo_import`.

This module is executable code with no theorems.
-/

open Lean Elab Command

namespace MojoProof.LLVM

/-- The rows of a tab-separated file after its header line, each split at its tabs. -/
def tsvRows (file : System.FilePath) : IO (List (List String)) := do
  return ((← IO.FS.lines file).toList.drop 1).filter (· ≠ "") |>.map (·.splitOn "\t")

/-- The name mojo_corpus gives the file at `path` when no `as` names it: each component of the path
up to its first `.`, one name component each (`mgemm/k.nvptx.ll` is `mgemm.k`). -/
def corpusName (path : String) : Name :=
  (path.splitOn "/").foldl (fun n c => .str n ((c.splitOn ".").headD c)) .anonymous

/-- What mojo_corpus does for arguments `args` (a manifest path or directory, and the name `as`
gives its one row; no argument names every row), given the manifest rows `rows` (path and digest)
and the refusals `refs` (path and reason): each row the arguments name, in their order, with its
digest, its name and its listed refusal; or the first failure: a refusal with no row, an argument
that names no row, an `as` whose argument names more than one row or whose one row is refused
(whether the argument is the row's path or a directory), or a row named twice. -/
def corpusPlan (rows refs : List (String × String)) (args : List (String × Option Name)) :
    Except String (List (String × String × Name × Option String)) := do
  if let some (p, _) := refs.find? fun (p, _) => !rows.any (·.1 == p) then
    throw s!"mojo_corpus: REFUSALS.tsv lists {p}, which has no row in MANIFEST.tsv"
  let named : List (String × Option Name) := if args.isEmpty then rows.map (·.1, none) else args
  let sel ← named.mapM fun (a, n) => do
    let s := rows.filter fun (p, _) => p == a || p.startsWith (a ++ "/")
    if s.isEmpty then throw s!"mojo_corpus: no row of MANIFEST.tsv is {a} or under {a}/"
    if let some n := n then
      unless s.length == 1 do throw s!"mojo_corpus: {a} as {n} names {s.length} rows, not one"
      -- The refusal of the one row `a` selects (`a` may be its directory).
      for (p, _) in s do
        if (refs.lookup p).isSome then throw s!"mojo_corpus: {p} as {n} is listed in REFUSALS.tsv"
    return s.map (·, n)
  let plan := sel.flatten.map fun ((p, d), n) => (p, d, n.getD (corpusName p), refs.lookup p)
  let paths := plan.map (·.1)
  if let some p := paths.zipIdx.findSome? fun (p, i) => if (paths.take i).contains p then some p
      else none then
    throw s!"mojo_corpus: {p} is named twice"
  return plan

/-- The checks of mojo_corpus on one row: the file `path` with bytes `bytes`, its manifest digest
`digest` and its listed refusal `r`. Its SHA-256 must be `digest`; then the importer's program
when it accepts the file and `r` is `none` (to be added), `none` when it refuses it with exactly
`r`, and a failure otherwise. -/
def corpusRow (path digest : String) (bytes : ByteArray) (r : Option String) :
    Except String (Option Program) := do
  let h := SHA256.hex bytes
  unless h == digest do
    throw s!"mojo_corpus: {path} has sha256 {h}, the manifest {digest}: the file changed"
  match parse bytes >>= (·.check h), r with
  | .ok prog, none => return some prog
  | .error e, some r =>
    if e == r then return none
    else throw s!"mojo_corpus: the importer refuses {path} with '{e}', REFUSALS.tsv with '{r}'"
  | .ok _, some r => throw s!"mojo_corpus: {path} imports, but REFUSALS.tsv refuses it with '{r}'"
  | .error e, none => throw s!"mojo_corpus: {path} is outside the subset: {e}"

/-- `mojo_corpus "<path>" as <name> "<directory>" ...` imports the manifest rows its arguments
name (every row when there is none) with `mojo_import`'s checks, adding each accepted file's
definitions under its `as` name or its path's name (`corpusName`); a file `REFUSALS.tsv` lists must
be refused with exactly the listed reason, and adds nothing. -/
syntax (name := mojoCorpus) "mojo_corpus" (ppSpace str (" as " ident)?)* : command

/-- `#mojo_corpus` with `mojo_corpus`'s arguments: the same checks, nothing added, and a message
with the numbers of rows, imported files and refused files. -/
syntax (name := mojoCorpusCheck) "#mojo_corpus" (ppSpace str (" as " ident)?)* : command

/-- Run mojo_corpus on the arguments of `stx`, adding each accepted row's definitions when `keep`
holds and discarding them after its checks otherwise; returns the numbers of rows, imported and
refused. `unsafe` because `quoteProgram` evaluates the terms it adds. -/
unsafe def runCorpus (stx : Syntax) (keep : Bool) : CommandElabM (Nat × Nat × Nat) := do
  let args := stx[1].getArgs.toList.filterMap fun a => a[0].isStrLit?.map fun p =>
    (p, if a[1].getNumArgs == 0 then none else some a[1][1].getId)
  let root : System.FilePath := ⟨mojo_import.root.get (← getOptions)⟩
  let rows := (← tsvRows (root / "MANIFEST.tsv")).filterMap fun
    | p :: d :: _ => some (p, d)
    | _ => none
  let refusals := root / "REFUSALS.tsv"
  let refs := (← if ← refusals.pathExists then tsvRows refusals else pure []).filterMap fun
    | p :: r@(_ :: _) => some (p, "\t".intercalate r)
    | _ => none
  let plan ← match corpusPlan rows refs args with
    | .ok plan => pure plan
    | .error e => throwError e
  let ns ← getCurrNamespace
  let mut imported := 0
  for (path, digest, name, r) in plan do
    let bytes ← IO.FS.readBinFile (root / path)
    match corpusRow path digest bytes r with
    | .error e => throwError e
    | .ok none => pure ()
    | .ok (some prog) =>
      if keep then quoteProgram (ns ++ name) path bytes prog
      else withoutModifyingEnv (quoteProgram (ns ++ name) path bytes prog)
      imported := imported + 1
  return (plan.length, imported, plan.length - imported)

/-- Elaborates mojo_corpus; `unsafe` because it evaluates the program terms it adds. -/
@[command_elab mojoCorpus] unsafe def elabMojoCorpus : CommandElab := fun stx => do
  discard <| runCorpus stx true

/-- Elaborates `#mojo_corpus`: the checks of mojo_corpus, adding nothing, and the counts. -/
@[command_elab mojoCorpusCheck] unsafe def elabMojoCorpusCheck : CommandElab := fun stx => do
  let (n, i, r) ← runCorpus stx false
  logInfo m!"mojo_corpus: {n} rows, {i} imported, {r} refused as REFUSALS.tsv lists"

end MojoProof.LLVM
