import Lean
import MojoProof.LLVM.Quote

/-!
# The programs of the proved kernels' theorems

`lake env lean --run scripts/L3Programs.lean` imports every module under `MojoProof/` and
`MojoProofTest/` and writes `roadmap/llvm-ir/programs.tsv`, the table `scripts/roadmap_llvm.py`
reads for its L3 rule (a construct is used by a proved kernel) and `scripts/roadmap_status.py`
for its L2 check. Its theorems are the L2 evidence of the kernel cards
(`roadmap/kernels/cards/*.md`, the names of their `evidence:` line's `L2:` part, read as
`scripts/roadmap_status.py` reads them) and the theorems of the modules `MojoProof.Kernels` and
`MojoProof.Kernels.*` that conclude `Kernel.Sound` of a program.

A theorem is about the programs its conclusion is about (`soundProgs`): after its binders are
opened (`∀` and `→`, without unfolding a definition), the conclusion must be an application of
`MojoProof.Sem.Kernel.Sound` to all its arguments, or a conjunction of conclusions; each such
application's program (its first explicit argument), when it has no bound variable, is one. A
mention in a premise, under a negation, inside another connective or another definition, or of
`Kernel.Obs` (an observation, not soundness) is about no program.

Each program is bound to a corpus file by its term, not by the digest it records (`boundOf`): it
must unfold, by its head at transparency `all` (`Meta.whnfHeadPred`, so through any definitions
that alias it), to a program constant `mojo_import`'s core added and recorded with the file it
read (`MojoProof.LLVM.progFiles`, MojoProof/LLVM/Quote.lean). Such a constant passed the
import's checks: its digest is the file's manifest row, and its term evaluates to the importer's
program and prints back to the file's tokens. A program that reaches no such constant (a
`Program.mk` term, a mutant that keeps an imported program's digest with another module,
`Mutant.program`) is bound to no file, even when its recorded digest is a corpus file's.

For each theorem, the table has one row per program, `theorem, module, program, file, sha256`:
the constant it is bound to, the file (`tests/corpus/<path>`) and the digest the constant
records; a program bound to no file has its term as program and `-` for file and digest, and a
theorem with no program `-` for all three, and a name that is no declaration also `-` for its
module (a declaration's module is the one that adds it, or else the main module). The names are
Lean's, as elaborated: a program the statement names through a namespace, an `open` or a
shadowing declaration is the constant Lean resolved it to, then unfolded.

`--check` writes nothing and exits with 1 unless the table is the committed one. `--self-test`
imports `MojoProof.Kernels`, `MojoProof.Sem.Spec` and `MojoProof.LLVM.Mutate` only, elaborates a
module (`selfTest`) and exits with 1 unless its table is the expected one: a program
`Outer.p.prog` that `mojo_import` adds for the `vadd` corpus file (theorems `outer`, and `both`,
a conjunction), a declaration `Outer.Inner.p.prog`, the `vmul` program, that shadows it in the
namespace `Outer.Inner` (theorem `inner`, bound through it to the `vmul` file), a mutant
`Outer.q.prog` that keeps the `vadd` digest with the `vmul` module (theorem `mutant`, bound to no
file, although its digest is the `vadd` file's), a premise about `p.prog` (theorem `premise`, no
program) and a negated conclusion about it (theorem `negated`, no program).
-/

open Lean

/-- The modules of the Lean files under `dir`. -/
partial def modulesIn (dir : System.FilePath) : IO (Array Name) := do
  let mut acc := #[]
  for e in ← dir.readDir do
    if ← e.path.isDir then acc := acc ++ (← modulesIn e.path)
    else if e.path.extension == some "lean" then
      let parts := (e.path.withExtension "").components
      acc := acc.push (parts.foldl (fun n s => if s == "." then n else .str n s) .anonymous)
  return acc

/-- `s` without ASCII blanks at its ends. -/
def trim (s : String) : String := s.trimAscii.toString

/-- The value of `key` in a card's front matter (between its first two `---` lines), with a
` # ` comment cut off. -/
def frontKey (text key : String) : Option String := Id.run do
  let lines := text.splitOn "\n"
  if lines.head?.map trim != some "---" then return none
  for l in lines.drop 1 do
    if trim l == "---" then return none
    if l.startsWith (key ++ ":") then
      let v := (l.drop (key.length + 1)).toString
      let v := if v.startsWith "# " then "" else ((v.splitOn " # ").headD v)
      return some (trim v)
  return none

/-- The names of the `L2:` part of an `evidence:` value (parts split at `;`, names at `,`). -/
def l2Names (ev : String) : List String :=
  (ev.splitOn ";").flatMap fun part =>
    let p := trim part
    if p.startsWith "L2:" then
      ((p.drop 3).toString.splitOn ",").map trim |>.filter (· ≠ "")
    else []

/-- The L2 evidence names of the kernel cards, sorted. -/
def cardNames : IO (Array String) := do
  let mut out := #[]
  for e in ← System.FilePath.readDir "roadmap/kernels/cards" do
    if e.path.extension == some "md" then
      if let some ev := frontKey (← IO.FS.readFile e.path) "evidence" then
        out := out ++ (l2Names ev).toArray
  return out.qsort (· < ·)

/-- The programs whose `Kernel.Sound` type `t` concludes: after the binders of `t` (opened
without unfolding), its conclusion must be an application of `MojoProof.Sem.Kernel.Sound` to its
nine arguments, whose program (the second, the first explicit) counts when it has no free
variable, or a conjunction, whose two sides count; anything else concludes nothing. Without
repetition. -/
partial def soundProgs (t : Expr) : Meta.MetaM (Array Expr) :=
  Meta.forallTelescope t fun _ c => do
    let c := c.consumeMData
    if c.isAppOfArity ``And 2 then
      let l ← soundProgs c.appFn!.appArg!
      return (← soundProgs c.appArg!).foldl (fun a p => if a.contains p then a else a.push p) l
    if c.isAppOfArity `MojoProof.Sem.Kernel.Sound 9 then
      let p := c.getArg! 1
      return if p.hasFVar || p.hasMVar then #[] else #[p]
    return #[]

/-- The program constant `mojo_import` added (`progFiles`, with its file) that program `p`
unfolds to by its head at transparency `all`, stopping at the first such constant; `none` when
the unfolding stops at another term. -/
def boundOf (files : NameMap String) (p : Expr) : Meta.MetaM (Option (Name × String)) := do
  let e ← Meta.withTransparency .all <| Meta.whnfHeadPred p fun e =>
    return !(e.constName?.any files.contains)
  return e.constName?.bind fun c => (files.find? c).map (c, ·)

/-- The digest program `p` records: `Program.sha256 p` after unfolding, if a string literal. -/
def digestOf (p : Expr) : Meta.MetaM (Option String) := do
  let e := mkApp (.const `MojoProof.LLVM.Program.sha256 []) p
  match ← Meta.withTransparency .all (Meta.whnf e) with
  | .lit (.strVal s) => return some s
  | _ => return none

/-- A program's text: its name if a constant, else the term on one line. -/
def programText (p : Expr) : String :=
  if let .const n _ := p then n.toString
  else (toString p).map fun c => if c == '\n' || c == '\t' then ' ' else c

/-- The rows of theorem `n`: `theorem, module, program, file, digest`, one per program its
conclusion is about (`soundProgs`), bound to its file (`boundOf`). -/
def rowsOf (env : Environment) (n : Name) : Meta.MetaM (Array String) := do
  let some ci := env.find? n | return #[s!"{n}\t-\t-\t-\t-"]
  let mod := match env.getModuleIdxFor? n with
    | some i => env.header.moduleNames[i.toNat]!
    | none => env.mainModule
  let ps ← soundProgs ci.type
  if ps.isEmpty then return #[s!"{n}\t{mod}\t-\t-\t-"]
  let files := MojoProof.LLVM.progFiles.getState env
  ps.mapM fun p => do
    match ← boundOf files p with
    | some (c, f) => return s!"{n}\t{mod}\t{c}\t{f}\t{(← digestOf (mkConst c)).getD "-"}"
    | none => return s!"{n}\t{mod}\t{programText p}\t-\t-"

/-- The table's header line. -/
def header : String := "theorem\tmodule\tprogram\tfile\tsha256\n"

/-- Run `x` on environment `env`, with no heartbeat limit. -/
def runMeta {α : Type} (env : Environment) (x : Meta.MetaM α) : IO α := do
  let ctx : Core.Context := { fileName := "<L3Programs>", fileMap := default, maxHeartbeats := 0 }
  let (a, _) ← (x.run' {} {}).toIO ctx { env }
  return a

/-- The table's text for the theorems `names`, header first, rows sorted. -/
def table (env : Environment) (names : Array Name) : IO String := do
  let rows := (← runMeta env (names.flatMapM (rowsOf env))).qsort (· < ·)
  return header ++ String.join (rows.toList.map (· ++ "\n"))

/-- The theorems of the table: the cards' L2 names and the theorems of the modules
`MojoProof.Kernels` and `MojoProof.Kernels.*` that conclude `Kernel.Sound` of a program
(`soundProgs`). -/
def theorems (env : Environment) : IO (Array Name) := do
  let mut out : Array Name := (← cardNames).map String.toName
  for i in [0:env.header.moduleNames.size] do
    if (`MojoProof.Kernels).isPrefixOf env.header.moduleNames[i]! then
      for n in env.header.moduleData[i]!.constNames do
        if let some (.thmInfo t) := env.find? n then
          if !n.isInternal && !out.contains n && !(← runMeta env (soundProgs t.type)).isEmpty then
            out := out.push n
  return out

/-- The corpus file of the self-test's outer program. -/
def vaddFile : String := "vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll"
/-- The corpus file of the self-test's inner program. -/
def vmulFile : String :=
  "vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll"

/-- The self-test's module: `Outer.p.prog` imported, `Outer.Inner.p.prog` shadowing it,
`Outer.q.prog` a mutant with its digest, and theorems about them: `outer`, `both` (a
conjunction), `inner`, `mutant`, `premise` (a premise only) and `negated`. -/
def selfTest : String := s!"
namespace L3Test.Outer
mojo_import \"{vaddFile}\" as p
/-- A statement about the outer program. -/
theorem outer (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) := fun _ _ h => h.elim
/-- A conjunction, about the outer program. -/
theorem both (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) ∧ True := ⟨fun _ _ h => h.elim, trivial⟩
/-- A premise about the outer program and a conclusion about none. -/
theorem premise (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem)
    (_h : MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True)) : True := trivial
/-- A negated statement about the outer program. -/
theorem negated (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    ¬ (MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) ∧ False) := fun h => h.2
/-- A mutant of the outer program: the `vmul` module, the outer program's digest. -/
def q.prog : MojoProof.LLVM.Program :=
  MojoProof.LLVM.Mutate.Mutant.program p.prog
    \{ (default : MojoProof.LLVM.Mutate.Mutant) with module := MojoProof.Kernels.vmul.module }
/-- A statement about the mutant. -/
theorem mutant (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound q.prog MojoProof.Kernels.vmul.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) := fun _ _ h => h.elim
namespace Inner
/-- The inner program, shadowing the outer one in `Inner`. -/
def p.prog : MojoProof.LLVM.Program := MojoProof.Kernels.vmul.prog
/-- A statement about the inner program. -/
theorem inner (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vmul.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) := fun _ _ h => h.elim
end Inner
end L3Test.Outer
"

/-- The manifest's digest of corpus file `path` (under tests/corpus). -/
def manifestDigest (path : String) : IO String := do
  for l in (← IO.FS.readFile "tests/corpus/MANIFEST.tsv").splitOn "\n" do
    if let p :: d :: _ := l.splitOn "\t" then
      if p == path then return d
  throw <| IO.userError s!"{path}: no manifest row"

/-- `--self-test`, `--check`, or with no argument writes the table (the module docstring). -/
unsafe def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  if args == ["--self-test"] then
    let env ← importModules #[{ module := `MojoProof.Kernels }, { module := `MojoProof.Sem.Spec },
      { module := `MojoProof.LLVM.Mutate }] {} (trustLevel := 1024) (loadExts := true)
    let (env, msgs) ← Elab.process selfTest (env.setMainModule `L3Test) {}
      (fileName := "<L3Programs self-test>")
    for m in msgs.toList do
      IO.eprintln (← m.toString)
    if msgs.hasErrors then return 1
    let got ← table env (#[`outer, `both, `premise, `negated, `mutant, `Inner.inner].map
      (`L3Test.Outer ++ ·))
    let vadd ← manifestDigest vaddFile
    let vmul ← manifestDigest vmulFile
    let row (n p f d : String) := s!"L3Test.Outer.{n}\tL3Test\t{p}\t{f}\t{d}\n"
    let want := header ++
      row "Inner.inner" "MojoProof.Kernels.vmul.prog" s!"tests/corpus/{vmulFile}" vmul ++
      row "both" "L3Test.Outer.p.prog" s!"tests/corpus/{vaddFile}" vadd ++
      row "mutant" "L3Test.Outer.q.prog" "-" "-" ++
      row "negated" "-" "-" "-" ++
      row "outer" "L3Test.Outer.p.prog" s!"tests/corpus/{vaddFile}" vadd ++
      row "premise" "-" "-" "-"
    IO.print got
    -- The mutant records the outer program's digest: the digest alone would bind it to `vadd`.
    let kept ← runMeta env (digestOf (mkConst `L3Test.Outer.q.prog))
    if got != want || kept != some vadd then
      IO.eprintln s!"self-test failed: expected\n{want}and the mutant's digest {vadd}, not {kept}"
      return 1
    IO.println "self-test: the shadowing program is bound through the inner declaration to the \
      vmul file, the conjunction to the vadd file; the mutant keeps the vadd digest and is bound \
      to no file; the premise and the negation are about no program"
    return 0
  let mods := (← modulesIn "MojoProof") ++ (← modulesIn "MojoProofTest")
  let env ← importModules (mods.map ({ module := · })) {} (trustLevel := 1024) (loadExts := true)
  let text ← table env (← theorems env)
  let out : System.FilePath := "roadmap/llvm-ir/programs.tsv"
  if args == ["--check"] then
    let old ← if ← out.pathExists then IO.FS.readFile out else pure ""
    if old != text then
      IO.eprintln s!"{out} is stale: run `lake env lean --run scripts/L3Programs.lean`"
      IO.eprint text
      return 1
    IO.println s!"{out} is current ({(text.splitOn "\n").length - 2} rows)"
    return 0
  if args != [] then
    IO.eprintln "usage: lake env lean --run scripts/L3Programs.lean [--check | --self-test]"
    return 2
  IO.FS.writeFile out text
  IO.println s!"wrote {out} ({(text.splitOn "\n").length - 2} rows)"
  return 0
