import MojoProof.LLVM.Import
import MojoProof.LLVM.Printer
import Lean

/-!
# Imported programs as Lean terms: `mojo_import`

`mojo_import "<path>" as <name>` imports the corpus file `tests/corpus/<path>` when the command is
elaborated and adds, in the current namespace,

* `<name>.fn_<i>.b_<j> : Block`, one definition for block `j` of function `i` of the module, and
  `<name>.fn_<i> : Func` over them, so that a theorem about one block names its constant and the
  kernel checks each block once; a block or function an earlier import defined (the same term) is
  not defined again but named (`defs`: the intrinsic declarations many kernels share are defined
  once);
* `<name>.module : Module` over the functions, and `<name>.prog : Program`.

Each added definition gets a docstring that names the file it comes from (and, for a block or a
function, its index and its LLVM name).

Nobody writes the program term or the digest: the term is quoted from the importer's result
(`MojoProof.LLVM.importBytes`) by core's derived `ToExpr` instances (`deriving instance ToExpr`, the
nested `Ty` and `MD` and the mutual `Value` and `TValue` included), and its digest
`<name>.prog.sha256` must be the file's row in `tests/corpus/MANIFEST.tsv` (docs/TRUST.md, T3).
The command fails when the file has no row, when its SHA-256 is not the row's ("the file changed"),
when the importer refuses it (its message names the construct), and when the term does not evaluate
back to the importer's program: after adding the definitions it evaluates `<name>.prog` with the
compiler (`evalConst`) and compares every field, so the quotation is checked at every import; the
check trusts Lean's compiled evaluation and the comparison code, not the kernel (docs/TRUST.md, T4).
Last, the evaluated term, printed, must have exactly the file's tokens (`printDiff`: comments and
whitespace are not tokens), so the step from the file's bytes to the term rests on the printer's
reading of LLVM syntax (T4), not on the parser alone. The lakefile makes the corpus an input of
the modules that import from it (`input_dir corpus`), so a changed file rebuilds them and the digest
check runs again. The option `mojo_import.root` (default `tests/corpus`) names the directory of the
files and their `MANIFEST.tsv`; only the test of the digest refusal sets it (to `tests/stale`, a
changed file).

This module is executable code with no theorems.
-/

open Lean Elab Command Meta

namespace MojoProof.LLVM

deriving instance ToExpr for FloatTy
deriving instance ToExpr for FloatLit
deriving instance ToExpr for BinOp
deriving instance ToExpr for IntFlags
deriving instance ToExpr for FBinOp
deriving instance ToExpr for FastMath
deriving instance ToExpr for ICmp
deriving instance ToExpr for FCmp
deriving instance ToExpr for CastOp
deriving instance ToExpr for GepFlags

deriving instance ToExpr for Ty
deriving instance ToExpr for Value, TValue
deriving instance ToExpr for MD

deriving instance ToExpr for Attr
deriving instance ToExpr for RmwOp
deriving instance ToExpr for Ordering
deriving instance ToExpr for Callee
deriving instance ToExpr for Inst
deriving instance ToExpr for Stmt
deriving instance ToExpr for Term
deriving instance ToExpr for Block
deriving instance ToExpr for Param
deriving instance ToExpr for Global
deriving instance ToExpr for Dim
deriving instance ToExpr for SReg
deriving instance ToExpr for Shfl
deriving instance ToExpr for MmaTy
deriving instance ToExpr for Mma
deriving instance ToExpr for Intrinsic
deriving instance ToExpr for Sem.Layout

/-- The definitions of the blocks and functions imported so far, by their terms. -/
initialize defs : SimplePersistentEnvExtension (Expr × Name) (Std.HashMap Expr Name) ←
  registerSimplePersistentEnvExtension {
    addEntryFn := fun m (e, n) => m.insert e n
    addImportedFn := fun as => as.foldl (fun m a => a.foldl (fun m (e, n) => m.insert e n) m) {} }

/-- Add the definition `name : type := value`, compiled, with its equation lemmas enabled
(`enableRealizationsForConst`), so that `simp only [name]` and `rw [name]` unfold it in the module
that adds it too, not only in the modules that import it. -/
def addDef (name : Name) (type value : Expr) : CoreM Unit := do
  addAndCompile <| .defnDecl
    { name, levelParams := [], type, value, hints := .abbrev, safety := .safe }
  enableRealizationsForConst name

/-- The constant whose value is `value`: an earlier one of `defs`, or `name : type := value`,
added. -/
def share (name : Name) (type value : Expr) : CoreM Expr := do
  if let some c := (defs.getState (← getEnv))[value]? then return mkConst c
  addDef name type value
  modifyEnv (defs.addEntry · (value, name))
  return mkConst name

/-- The term of an array, of type `Array ty`, from the terms of its elements. -/
def quoteArray (ty : Expr) (es : List Expr) : Expr :=
  mkApp2 (mkConst ``List.toArray [Level.zero]) ty <|
    es.foldr (fun e acc => mkApp3 (mkConst ``List.cons [Level.zero]) ty e acc)
      (mkApp (mkConst ``List.nil [Level.zero]) ty)

/-- The directory `mojo_import` and `mojo_corpus` read files and their `MANIFEST.tsv` from
(default `tests/corpus`, relative to the directory Lean runs in). -/
register_option mojo_import.root : String := {
  defValue := "tests/corpus"
  descr := "the directory of the files `mojo_import` reads and of their MANIFEST.tsv" }

/-- The digest of `path` in the manifest `MANIFEST.tsv` of directory `root`. -/
def manifestDigest (root : System.FilePath) (path : String) : IO (Option String) := do
  let rows ← IO.FS.lines (root / "MANIFEST.tsv")
  return rows.findSome? fun r => match r.splitOn "\t" with
    | p :: d :: _ => if p == path then some d else none
    | _ => none

/-- The refusal of program `prog`, imported from `path`, when its digest is not the manifest's
`digest`. -/
def digestError (path digest : String) (prog : Program) : Option String :=
  if prog.sha256 == digest then none
  else some s!"mojo_import: {path} has sha256 {prog.sha256}, the manifest {digest}: the file \
    changed"

/-- The fields of two programs that differ, by name. -/
def Program.diff (p q : Program) : List String :=
  [("module", p.module == q.module), ("sha256", p.sha256 == q.sha256),
   ("layout", p.layout == q.layout), ("intrinsics", p.intrinsics == q.intrinsics),
   ("kernels", p.kernels == q.kernels)].filterMap fun (f, ok) => if ok then none else some f

/-- `mojo_import "<path>" as <name>` imports the file `<path>` of the corpus directory
(`mojo_import.root`, default `tests/corpus`) and adds its blocks, functions, module and program as
definitions under `<name>` in the current namespace, after checking the file's SHA-256 against its
`MANIFEST.tsv` row, that the importer accepts it, that the term evaluates back to the importer's
program and that it prints back to the file's tokens. -/
syntax (name := mojoImport) "mojo_import " str " as " ident : command

/-- The core of `mojo_import`: add the definitions of program `prog` under `name` (the blocks and
functions through `share`, then `name.module` and `name.prog`), then check that `name.prog`
evaluates to `prog` and that the evaluated module, printed, has the tokens of `bytes`, the file
`path` (for the messages); `unsafe` because it evaluates the term it adds. Each definition it
adds gets a docstring naming the file (under the directory `mojo_import.root`). -/
unsafe def quoteProgram (name : Name) (path : String) (bytes : ByteArray) (prog : Program) :
    CommandElabM Unit := do
  let file := s!"{mojo_import.root.get (← getOptions)}/{path}"
  liftTermElabM do
    -- The docstring of `c` when `e`, the constant `share` returned, is `c` itself, newly added in
    -- this module (not an earlier import's constant of the same term).
    let doc (c : Name) (e : Expr) (d : String) : TermElabM Unit := do
      if e.constName? == some c && ((← getEnv).getModuleIdxFor? c).isNone then
        addDocStringCore c d
    let fns ← prog.module.funcs.toList.zipIdx.mapM fun (f, i) => do
      let c := name ++ (`fn).appendIndexAfter i
      let bs ← f.blocks.toList.zipIdx.mapM fun (b, j) => do
        let cb := c ++ (`b).appendIndexAfter j
        let e ← share cb (mkConst ``Block) (toExpr b)
        let label := f.names.getD b.label ""
        doc cb e s!"Block {j} (`%{label}`) of function {i} (`@{f.name}`) of \
          the corpus file `{file}`, as the importer parsed it (added by `mojo_import`'s core; a \
          later import with the same block names this definition)."
        return e
      let e ← share c (mkConst ``Func) <| mkAppN (mkConst ``Func.mk) #[toExpr f.linkage,
        toExpr f.cconv, toExpr f.retAttrs, toExpr f.ret, toExpr f.name, toExpr f.params,
        toExpr f.group, toExpr f.names, quoteArray (mkConst ``Block) bs]
      doc c e s!"Function {i} (`@{f.name}`, {f.blocks.size} blocks) of the corpus file `{file}`, \
        as the importer parsed it (added by `mojo_import`'s core; a later import with the same \
        function names this definition)."
      return e
    let m := prog.module
    let modE := mkAppN (mkConst ``Module.mk) #[toExpr m.sourceFilename, toExpr m.datalayout,
      toExpr m.triple, toExpr m.globals, quoteArray (mkConst ``Func) fns, toExpr m.attrGroups,
      toExpr m.namedMD, toExpr m.mds]
    addDef (name ++ `module) (mkConst ``Module) modE
    addDocStringCore (name ++ `module) s!"The module of the corpus file `{file}` as the importer \
      parsed it: its {m.funcs.size} functions, globals, attribute groups and metadata (added by \
      `mojo_import`'s core)."
    addDef (name ++ `prog) (mkConst ``Program) <| mkAppN (mkConst ``Program.mk)
      #[mkConst (name ++ `module), toExpr prog.sha256, toExpr prog.layout, toExpr prog.intrinsics,
        toExpr prog.kernels]
    addDocStringCore (name ++ `prog) s!"The program of the corpus file `{file}`: its module, its \
      SHA-256 `{prog.sha256}` (the file's `MANIFEST.tsv` digest), its data layout, intrinsic \
      declarations and kernel names. `mojo_import`'s core checks, when it adds this term, that \
      it evaluates to the importer's result and that its module prints back to the file's tokens."
  let back ← evalConst Program (name ++ `prog)
  let diff := Program.diff back prog
  unless diff.isEmpty do
    throwError "mojo_import: the term of {path} does not evaluate to the imported program: {diff}"
  if let some l := printDiff bytes back.module then
    throwError "mojo_import: the printed term of {path} differs from the file at line {l}"

/-- Elaborates `mojo_import`: the manifest's digest, the importer, the digest check, then
`quoteProgram`; `unsafe` because it evaluates the program term it adds. -/
@[command_elab mojoImport] unsafe def elabMojoImport : CommandElab := fun stx => do
  let some path := stx[1].isStrLit? | throwUnsupportedSyntax
  let name := (← getCurrNamespace) ++ stx[3].getId
  let root : System.FilePath := ⟨mojo_import.root.get (← getOptions)⟩
  let some digest ← manifestDigest root path
    | throwError "mojo_import: {path} has no row in {root / "MANIFEST.tsv"}"
  let bytes ← IO.FS.readBinFile (root / path)
  let prog ← match importBytes bytes with
    | .ok p => pure p
    | .error e => throwError "mojo_import: {path} is outside the subset: {e}"
  if let some e := digestError path digest prog then throwError e
  quoteProgram name path bytes prog

end MojoProof.LLVM
