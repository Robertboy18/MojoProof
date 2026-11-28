import Lean
import MojoProof.LLVM.Quote
import MojoProof.Util.Modules

/-!
# The programs of the proved kernels' theorems, their witnesses, kinds and L3 and L4 evidence

`lake env lean --run scripts/L3Programs.lean` imports every module under `MojoProof/` and
`MojoProofTest/` (`MojoProof.Util.modulesIn`) and writes four tables under `roadmap/llvm-ir/`:
`programs.tsv`, which `scripts/roadmap_llvm.py` reads for its L3 rule (a construct is used by a
proved kernel), `scripts/roadmap_status.py` for its L2 check and `scripts/kernel_universe.py` for
the coverage page; `witnesses.tsv`, which `scripts/roadmap_status.py` reads for its L2 check;
`evidence.tsv`, which it reads for its L3 and L4 checks; and `kinds.tsv`, which
`scripts/kernel_universe.py` reads to count the theorems that state a specification apart from
the spec-free ones.

The theorems of `programs.tsv` are the L2 evidence of the kernel cards
(`roadmap/kernels/cards/*.md`, the names of their `evidence:` line's `L2:` part, read as
`scripts/roadmap_status.py` reads them) and every theorem of those modules that concludes
soundness of a corpus file's kernel.

A theorem is about the soundness terms its conclusion is (`soundTerms`): after its binders are
opened (`∀` and `→`, without unfolding a definition), the conclusion must be an application of
`MojoProof.Sem.Kernel.Sound` to all its arguments, of `MojoProof.Sem.Kernel.Safe` to all its
arguments, or of `GPUProof.Kernel.Sound` to all its arguments at the machine `MojoProof.Sem.sig`
(its program a pair `(prog, fn)`), or a conjunction of conclusions; each such application whose
program (`prog`) has no bound variable is one, with its function (`fn`). A mention in a premise,
under a negation, inside another connective or another definition, or of `Kernel.Obs` (an
observation, not soundness) is no soundness term.

Each soundness term is bound to a corpus file by its program's and its function's terms, not by
the digest the program records (`boundSound`). The program must unfold, by its head at
transparency `all` (`Meta.whnfHeadPred`, so through any definitions that alias it), to a program
constant `mojo_import`'s core added and recorded with the file it read
(`MojoProof.LLVM.progFiles`, MojoProof/LLVM/Quote.lean; `boundOf`). Such a constant passed the
import's checks: its digest is the file's manifest row, and its term evaluates to the importer's
program and prints back to the file's tokens. The function must unfold the same way to the
function constant the import added for one of the file's `ptx_kernel` functions (the program's
kernel names, `kernelFns`): `Grid.start` starts the function it is given, so a theorem about
another function (one that only returns) at the kernel's program is about no corpus file. A
program that reaches no such constant (a `Program.mk` term, a mutant that keeps an imported
program's digest with another module, `Mutant.program`) is bound to no file, even when its
recorded digest is a corpus file's.

For each theorem, `programs.tsv` has one row per soundness term, `theorem, module, program, file,
sha256`: the program constant it is bound to, the file (`tests/corpus/<path>`) and the digest the
constant records; a term bound to no file has its program's term as program and `-` for file and
digest, and a theorem with no soundness term `-` for all three, and a name that is no declaration
also `-` for its module (a declaration's module is the one that adds it, or else the main
module). The names are Lean's, as elaborated: a program the statement names through a namespace,
an `open` or a shadowing declaration is the constant Lean resolved it to, then unfolded.

`kinds.tsv` has, for each theorem of `programs.tsv`, one row `theorem, program, kind` per
soundness term (`kindRows`; the program as in `programs.tsv`, its constant or its term): `safe`
when the term's relation is constant `True` (`isTrueRel`: the relation applied to a new variable
reduces, by `whnfD`, to `True`, so `fun _ => True` and a definition that unfolds to it), else
`correct`; a theorem with no soundness term has one row `-`, `safe`. So each conjunct of a
`Kernel.Sound … ∧ Kernel.Sound …` has its own kind, and a relation that ignores its argument
but is no `True` (`fun _ => 1 = 1`) is `correct`, as is one that mentions its argument and holds
of every output (`fun y => y = y`).

`witnesses.tsv` has, for each theorem of `programs.tsv`, one row `theorem, witness` per witness
of it, or one row with `-` when it has none. A witness (`witnessOf`) is a theorem of those
modules whose statement is closed and in the witness form,
`L.Valid ∧ ∃ y, Kernel.Obs prog fn L args m obs ch ω y ∧ Q y` with the same launch `L` in both
conjuncts (`witnessForm?`), read by its syntax: no definition or abbreviation around it is
unfolded, and one that hides it is refused (`whnfD` only names that refusal). Its binders
(`openWitness`) are no propositions and have closed inhabitants: an `Inhabited` instance in the
empty local context (`closedInhabited`; the address choice `Nat → Nat` and the oracle
`Nat → Nat → Nat` have one). Its proof is opened with the same binders as its statement, and its
body is `⟨_, Kernel.Sound.exists_obs h …⟩` at the launch `L`, with an observation that depends
on its argument. So the statement holds at closed values of its binders, the launch has a block
and a thread (`L.Valid`), some complete run is observed there and its observation meets `Q`. It
witnesses the theorems `h` applies (`chain`): `h`'s head theorem, then through a **conversion**
(`conversionArg?`, recognized by its shape: one `GPUProof.Kernel.Sound` premise, a
`Kernel.Sound` conclusion with the same program, function, launch, arguments, memory, admission
and relation) the theorems of its premise, and through an **instance** (a theorem whose proof is
another theorem applied, `GemvSound.sound64 := kernel_sound …`) that theorem's; a case split, a
`match`, an `if`, a `fun` or a bridge that rewrites the admission or the relation ends the chain.
When the relation is constant `True` (`isTrueRel`), only the spec-free theorems of the chain are
witnessed. A theorem that holds only because its premises or its admission cannot be met, or
because no run is observed (a launch with no thread), has no witness.

`evidence.tsv` has, for each name of the cards' `L3:` and `L4:` parts, one row `name, kind,
levels, program, file, sha256` per program its type mentions anywhere (`mentions`: soundness
terms and `Kernel.Obs`, in premises included), bound with its function as above; `kind` is
`theorem`, `definition` or `other`, or `-` for a name that is no declaration; `levels` is the
level rule's for the runs of that program and function only (`runLevels`), `-` for none. A run is
a `Kernel.Obs` premise or a `Kernel.Obs` atom of the conclusion at an `∃` variable; its outputs
are its observed value and the variables an identifying equation makes outputs of it
(`outputsOf`: `x = e`, `some x = e` or `Layout.encode l t (Val.ofFloat t' x) = e`, with `e`
mentioning the outputs of exactly one run and no other unidentified variable). Then `L3`: an
equation (`=`, `NaNEq`, `FinEq`) of an output and a TorchLean operation's value that mentions no
output; `L4`: `toReal` of an output equals `Model.roundAt` of a real that mentions no output, or
`|s - t| ≤ b` with `s` about one run's outputs and `t`, `b` about none. So a kernel whose run is
only a premise of another kernel's theorem gets no level, and `(y, z) = (y, z) ∧ z = TorchLean.op`
gives none (`z` is no output).

`--check` writes nothing and exits with 1 unless the four tables are the committed ones.
`--self-test` imports `MojoProof.Kernels`, `MojoProof.Sem.Spec`, `MojoProof.LLVM.Mutate`,
`MojoProofTest.Kernel` and `MojoProofTest.GemvObs` only, elaborates a module (`selfTest`) at the
first conversion found by shape, and exits with 1 unless its tables, verdicts, chains and
refusals are the expected ones (`runSelfTest` lists them): the programs and kinds of the outer,
shadowed, mutant and void programs, the conjunction `conj_k` (one `safe` and one `correct` row)
and `nospec_k` (`safe`); the witnesses of `MojoProof.Kernels.vadd.correct` (`obs_w`, `have_w`,
`have_k_w`); the chains of a bridge, a case split (`choose_w`: `choose` only), `Kernel.Sound.map`
and gemv's observation through the conversion (the conversion, `GemvSound.sound64`,
`GemvSound.kernel_sound`); the refusals of a premise, a class binder whose instance proves
`False`, a statement behind an abbreviation, a constant relation, the old form and a launch with
no thread; and the evidence rows of `vmul_extra` (vadd's run `L3 L4`, the premise's vmul run
`-`), `pair` (`-`), `premise`, `both` and `MojoProofTest.Kernel.vadd_real` (`L3 L4`).
-/

open Lean

open MojoProof.Util (modulesIn)

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

/-- The names of the part of an `evidence:` value at level `lv` (`"L2"`, `"L3"`, …; parts split
at `;`, names at `,`). -/
def levelNames (lv ev : String) : List String :=
  (ev.splitOn ";").flatMap fun part =>
    let p := trim part
    if p.startsWith (lv ++ ":") then
      ((p.drop (lv.length + 1)).toString.splitOn ",").map trim |>.filter (· ≠ "")
    else []

/-- The evidence names of the kernel cards at the levels `lvs`, sorted, without repetition. -/
def cardNamesAt (lvs : List String) : IO (Array String) := do
  let mut out := #[]
  for e in ← System.FilePath.readDir "roadmap/kernels/cards" do
    if e.path.extension == some "md" then
      if let some ev := frontKey (← IO.FS.readFile e.path) "evidence" then
        for n in lvs.flatMap (levelNames · ev) do
          unless out.contains n do out := out.push n
  return out.qsort (· < ·)

/-- The L2 evidence names of the kernel cards, sorted. -/
def cardNames : IO (Array String) := cardNamesAt ["L2"]

/-- The program and the function of a pair `P` of a program and a function, at
`MojoProof.Sem.sig`: `P`'s components when `P` is a pair `(prog, fn)`, or else when `P` unfolds to
one at reducible transparency (`whnfR`); `none` otherwise. -/
def pairParts? (P : Expr) : Meta.MetaM (Option (Expr × Expr)) := do
  let P ← if P.isAppOfArity `Prod.mk 4 then pure P else Meta.whnfR P
  return if P.isAppOfArity `Prod.mk 4 then some (P.getArg! 2, P.getArg! 3) else none

/-- What a soundness term is about: its program and its function, and whether it relates the
output (it has a relation that is not constant `True`, `isTrueRel`; never for `Kernel.Safe`). -/
structure SoundTerm where
  /-- The program. -/
  prog : Expr
  /-- The function. -/
  fn : Expr
  /-- Whether the relation is not constant `True`. -/
  relates : Bool

/-- Whether function `f` depends on its argument: `f` applied to a new variable of its argument's
type (its type's first binder, at reducible transparency) mentions that variable after
beta-reduction. A function that mentions its argument but is constant by proof (`fun y => y = y`)
counts as depending on it. -/
def dependsOnArg (f : Expr) : Meta.MetaM Bool := do
  Meta.forallBoundedTelescope (← Meta.whnfR (← Meta.inferType f)) (some 1) fun xs _ => do
    let some x := xs[0]? | return false
    return (mkApp f x).headBeta.containsFVar x.fvarId!

/-- Whether relation `r` (a soundness term's) is constant `True` by definition: `r` applied to a
new variable of its argument's type (its type's first binder, at reducible transparency),
beta-reduced, then unfolded by its head at default transparency (`whnfD`, through definitions and
abbreviations, so a named `noSpec _ := True` is unfolded), is the constant `True`. A relation
that holds of every value only by proof (`fun y => y = y`, `fun _ => True ∧ True`) is not
detected and counts as relating the output. -/
def isTrueRel (r : Expr) : Meta.MetaM Bool := do
  Meta.forallBoundedTelescope (← Meta.whnfR (← Meta.inferType r)) (some 1) fun xs _ => do
    let some x := xs[0]? | return false
    return (← Meta.whnfD (mkApp r x).headBeta).isConstOf ``True

/-- The parts of soundness term `c`: `MojoProof.Sem.Kernel.Sound` applied to its nine arguments
(the program the second, the function the third, the relation the ninth),
`MojoProof.Sem.Kernel.Safe` applied to its eight (the program, the function, and `none`: its
relation is `True`), or `GPUProof.Kernel.Sound` applied to its nine at machine
`MojoProof.Sem.sig` (the components of its program, the third argument, by `pairParts?`, and the
ninth); `none` for any other term. -/
def soundParts? (c : Expr) : Meta.MetaM (Option (Expr × Expr × Option Expr)) := do
  if c.isAppOfArity `MojoProof.Sem.Kernel.Sound 9 then
    return some (c.getArg! 1, c.getArg! 2, some (c.getArg! 8))
  if c.isAppOfArity `MojoProof.Sem.Kernel.Safe 8 then
    return some (c.getArg! 1, c.getArg! 2, none)
  if c.isAppOfArity `GPUProof.Kernel.Sound 9 && (c.getArg! 0).isConstOf `MojoProof.Sem.sig &&
      !(c.getArg! 2).hasLooseBVars then
    if let some (p, f) ← pairParts? (c.getArg! 2) then return some (p, f, some (c.getArg! 8))
  return none

/-- The soundness terms type `t` concludes: after the binders of `t` (opened without unfolding),
its conclusion must be a soundness term (`soundParts?`: `MojoProof.Sem.Kernel.Sound`,
`MojoProof.Sem.Kernel.Safe`, or `GPUProof.Kernel.Sound` at `MojoProof.Sem.sig`), which counts
when its program has no free variable, or a conjunction, whose two sides count; anything else
concludes nothing. Each term relates the output when it has a relation that is not constant
`True` (`isTrueRel`). -/
partial def soundTerms (t : Expr) : Meta.MetaM (Array SoundTerm) :=
  Meta.forallTelescope t fun _ c => do
    let c := c.consumeMData
    if c.isAppOfArity ``And 2 then
      return (← soundTerms c.appFn!.appArg!) ++ (← soundTerms c.appArg!)
    if let some (p, f, r) ← soundParts? c then
      if p.hasFVar || p.hasMVar then return #[]
      return #[⟨p, f, ← r.elim (pure false) fun r => return !(← isTrueRel r)⟩]
    return #[]

/-- The program constant `mojo_import` added (`progFiles`, with its file) that program `p`
unfolds to by its head at transparency `all`, stopping at the first such constant; `none` when
the unfolding stops at another term. -/
def boundOf (files : NameMap String) (p : Expr) : Meta.MetaM (Option (Name × String)) := do
  let e ← Meta.withTransparency .all <| Meta.whnfHeadPred p fun e =>
    return !(e.constName?.any files.contains)
  return e.constName?.bind fun c => (files.find? c).map (c, ·)

/-- The elements of a list term `List.cons _ a (List.cons _ b … (List.nil _))`, as
`mojo_import`'s core writes them (`quoteArray`, `toExpr`); the elements before the first other
tail. -/
partial def listElems (e : Expr) : Array Expr :=
  if e.isAppOfArity ``List.cons 3 then #[e.getArg! 1] ++ listElems (e.getArg! 2) else #[]

/-- The function constants of the kernels of program constant `c`, as `mojo_import`'s core adds
them (`quoteProgram`): `c`'s value is `Program.mk` of its module constant and four more fields,
the last its kernel names (the names of the module's `ptx_kernel` functions,
MojoProof/LLVM/Import.lean); the module constant's value is `Module.mk` with the array of its
function constants as fifth field; the kernels are those function constants whose value is
`Func.mk` with a name (its fifth field, a string literal) among the kernel names. Empty for a
constant of another shape. -/
def kernelFns (env : Environment) (c : Name) : Array Name := Id.run do
  let value (n : Name) := (env.find? n).bind (·.value?)
  let some v := value c | return #[]
  unless v.isAppOfArity ``MojoProof.LLVM.Program.mk 5 do return #[]
  let names := (listElems (v.getArg! 4)).filterMap fun
    | .lit (.strVal s) => some s
    | _ => none
  let some mc := (v.getArg! 0).constName? | return #[]
  let some mv := value mc | return #[]
  unless mv.isAppOfArity ``MojoProof.LLVM.Module.mk 8 &&
      (mv.getArg! 4).isAppOfArity ``List.toArray 2 do return #[]
  return (listElems (mv.getArg! 4).appArg!).filterMap fun f => do
    let n ← f.constName?
    let fv ← value n
    guard (fv.isAppOfArity ``MojoProof.LLVM.Func.mk 9)
    let .lit (.strVal s) := fv.getArg! 4 | none
    guard (names.contains s)
    return n

/-- The program constant and file soundness term `s` is bound to: its program bound to a file
(`boundOf`), and its function unfolding, by its head at transparency `all` (as `boundOf`), to the
function constant of one of that program's kernels (`kernelFns`); `none` otherwise, and then a
theorem about a function the importer did not add for one of the file's kernels (one that only
returns, at the kernel's program) is about no corpus file. -/
def boundSound (env : Environment) (files : NameMap String) (prog fn : Expr) :
    Meta.MetaM (Option (Name × String)) := do
  let some (c, f) ← boundOf files prog | return none
  let ks := kernelFns env c
  let e ← Meta.withTransparency .all <| Meta.whnfHeadPred fn fun e =>
    return !(e.constName?.any ks.contains)
  return if e.constName?.any ks.contains then some (c, f) else none

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

/-- `a` without repetition, in order. -/
def dedup (a : Array String) : Array String :=
  a.foldl (fun o r => if o.contains r then o else o.push r) #[]

/-- The rows of theorem `n`: `theorem, module, program, file, digest`, one per program its
conclusion is about (`soundTerms`), bound to its file with its function (`boundSound`), without
repetition. -/
def rowsOf (env : Environment) (n : Name) : Meta.MetaM (Array String) := do
  let some ci := env.find? n | return #[s!"{n}\t-\t-\t-\t-"]
  let mod := match env.getModuleIdxFor? n with
    | some i => env.header.moduleNames[i.toNat]!
    | none => env.mainModule
  let ss ← soundTerms ci.type
  if ss.isEmpty then return #[s!"{n}\t{mod}\t-\t-\t-"]
  let files := MojoProof.LLVM.progFiles.getState env
  dedup <$> ss.mapM fun s => do
    match ← boundSound env files s.prog s.fn with
    | some (c, f) => return s!"{n}\t{mod}\t{c}\t{f}\t{(← digestOf (mkConst c)).getD "-"}"
    | none => return s!"{n}\t{mod}\t{programText s.prog}\t-\t-"

/-- The kinds rows of theorem `n`: one row `theorem, program, kind` per soundness term of its
conclusion (`soundTerms`), its program as in `rowsOf` (the program constant it is bound to, or its
program's term), its kind `correct` when it relates the output (its relation is not constant
`True` after unfolding, `isTrueRel`) and `safe` when not (`Kernel.Safe`, or a relation `True`);
one row `theorem, -, safe` for a theorem with no soundness term or no declaration. Without
repetition: a conjunction's two terms at two programs give a row each, at one program with two
kinds two rows. -/
def kindRows (env : Environment) (n : Name) : Meta.MetaM (Array String) := do
  let some ci := env.find? n | return #[s!"{n}\t-\tsafe"]
  let ss ← soundTerms ci.type
  if ss.isEmpty then return #[s!"{n}\t-\tsafe"]
  let files := MojoProof.LLVM.progFiles.getState env
  dedup <$> ss.mapM fun s => do
    let p := match ← boundSound env files s.prog s.fn with
      | some (c, _) => c.toString
      | none => programText s.prog
    return s!"{n}\t{p}\t{if s.relates then "correct" else "safe"}"

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

/-- The theorems of the table: the cards' L2 names, then every theorem of the modules `mods` that
concludes soundness (`soundTerms`) of a program bound to a corpus file with its function
(`boundSound`). -/
def theorems (env : Environment) (mods : NameSet) : IO (Array Name) := do
  let mut out : Array Name := (← cardNames).map String.toName
  let files := MojoProof.LLVM.progFiles.getState env
  for i in [0:env.header.moduleNames.size] do
    if mods.contains env.header.moduleNames[i]! then
      for n in env.header.moduleData[i]!.constNames do
        if let some (.thmInfo t) := env.find? n then
          if !n.isInternal && !out.contains n then
            let bound ← runMeta env do
              (← soundTerms t.type).anyM fun s =>
                return (← boundSound env files s.prog s.fn).isSome
            if bound then out := out.push n
  return out

/-- `e` with its metadata and the `let`s at its head substituted (zeta-reduced): a head
`let x := v; b`, or `have x := v; b` (a `let` whose body's type does not depend on `x`, as Lean
elaborates `have`), applied to arguments or not, is `b` at `v` applied to them, beta-reduced, and
so on until the head is no `let`. -/
partial def zetaHead (e : Expr) : Expr :=
  let e := e.consumeMData
  match e.getAppFn.consumeMData with
  | .letE _ _ v b _ => zetaHead ((b.instantiate1 v).betaRev e.getAppRevArgs)
  | _ => e

/-- The body of `e` under its leading `fun`s, the metadata and the `let`s and `have`s at their
heads dropped and substituted (`zetaHead`), its bound variables loose. -/
partial def lamBody (e : Expr) : Expr :=
  match zetaHead e with
  | .lam _ _ b _ => lamBody b
  | e => e

/-- The position of the soundness premise of a **conversion** of type `ty`, or `none` when `ty`
is no conversion. A conversion, by shape and not by name: after its binders (opened without
unfolding), its conclusion is `MojoProof.Sem.Kernel.Sound` applied to its nine arguments, and
exactly one binder's type is a soundness term (`soundParts?`), which is `GPUProof.Kernel.Sound`
at `MojoProof.Sem.sig` whose program is the pair of the conclusion's program and function
(`pairParts?`), whose launch, arguments, memory and relation are the conclusion's (`isDefEq` at
reducible transparency), and whose admission `adm` is the conclusion's uncurried (the
conclusion's admission at new `ch` and `ω`, beta-reduced, is `adm (ch, ω)` by `isDefEq`). The
observations may differ (one of the blocks, one of the memory), and the other binders are no
soundness terms (a law of the observation, as the `hO` of gemv's conversion). -/
def conversionArg? (ty : Expr) : Meta.MetaM (Option Nat) :=
  Meta.forallTelescope ty fun xs c => do
    let c := c.consumeMData
    unless c.isAppOfArity `MojoProof.Sem.Kernel.Sound 9 do return none
    let same (a b : Expr) : Meta.MetaM Bool := Meta.withReducible (Meta.isDefEq a b)
    let mut found : Option Nat := none
    for i in [0:xs.size] do
      let t := (← instantiateMVars (← Meta.inferType xs[i]!)).consumeMData
      if (← soundParts? t).isNone then continue
      if found.isSome then return none
      unless t.isAppOfArity `GPUProof.Kernel.Sound 9 &&
          (t.getArg! 0).isConstOf `MojoProof.Sem.sig do
        return none
      let some (p, f) ← pairParts? (t.getArg! 2) | return none
      for (a, b) in [(p, c.getArg! 1), (f, c.getArg! 2), (t.getArg! 3, c.getArg! 3),
          (t.getArg! 4, c.getArg! 4), (t.getArg! 5, c.getArg! 5), (t.getArg! 8, c.getArg! 8)] do
        unless ← same a b do return none
      let adm := t.getArg! 6
      let uncurried ← Meta.forallBoundedTelescope (← Meta.inferType (c.getArg! 6)) (some 2)
        fun cw _ => do
          let #[ch, ω] := cw | return false
          Meta.isDefEq (mkAppN (c.getArg! 6) cw).headBeta
            (mkApp adm (← Meta.mkAppM ``Prod.mk #[ch, ω]))
      unless uncurried do return none
      found := some i
    return found

/-- The theorems that soundness proof `h` applies, outermost first, at most `fuel` deep: `h`'s
head constant `T` (the `let`s and `have`s at its head substituted, `zetaHead`) when it is a
theorem, and then:
* when `T` is a conversion (`conversionArg?`), the theorems of `T`'s argument at its soundness
  premise, by the same rule (gemv's conversion at `GemvSound.sound64` gives the conversion and
  then `GemvSound.sound64`'s);
* else, when `T`'s value applied to `h`'s arguments (beta-reduced, `zetaHead`) is an application
  of a theorem whose type (inferred, then at reducible transparency) is a soundness term
  (`soundParts?`), `T` is an **instance** of that theorem, and the theorems of that application
  follow (`GemvSound.sound64 := kernel_sound …` gives `kernel_sound`);
* else nothing more. A `fun` (a proof by cases, a `match`, an `if`, a bridge that rewrites the
  admission or the relation), a constructor or a definition at the head of `T`'s value ends the
  chain, so a case split `choose vacuous k` credits `choose` and neither `vacuous` nor `k`, and a
  bridge `bridge (k x)` credits `bridge` only. -/
partial def chain (env : Environment) (h : Expr) (fuel : Nat := 8) (out : Array Name := #[]) :
    Meta.MetaM (Array Name) := do
  let e := zetaHead h
  let .const c us := e.getAppFn.consumeMData | return out
  let some (.thmInfo t) := env.find? c | return out
  if fuel == 0 || out.contains c then return out
  let out := out.push c
  if let some i ← conversionArg? (t.type.instantiateLevelParams t.levelParams us) then
    return ← match e.getAppArgs[i]? with
      | some a => chain env a (fuel - 1) out
      | none => pure out
  let next := zetaHead ((t.value.instantiateLevelParams t.levelParams us).beta e.getAppArgs)
  let .const c' _ := next.getAppFn.consumeMData | return out
  let some (.thmInfo _) := env.find? c' | return out
  if next.hasLooseBVars then return out
  let sound ← try
      let ty := (← instantiateMVars (← Meta.inferType next)).consumeMData
      pure ((← soundParts? ty).isSome || (← soundParts? (← Meta.whnfR ty)).isSome)
    catch _ => pure false
  if sound then chain env next (fuel - 1) out else return out

/-- Whether type `t` has an inhabitant the witness rule names: `t` has no free, loose bound or
meta variable, and an `Inhabited` instance of `t` is found in the empty local context (no binder
of the statement is in it), so `default`, at that instance, is a closed term of type `t`.
`Nat → Nat`, `Nat → Nat → Nat` and `TorchLean.Tensor` types have one; a class whose only instance
needs an instance of itself, or a type that mentions a binder before it, has none. -/
def closedInhabited (t : Expr) : Meta.MetaM Bool := do
  if t.hasFVar || t.hasMVar || t.hasLooseBVars then return false
  Meta.withLCtx {} {} do
    try return (← Meta.synthInstance? (← Meta.mkAppM ``Inhabited #[t])).isSome
    catch _ => return false

/-- `k` at the body of a witness's statement `ty` and the body of its proof `v` under the same
binders: each binder of `ty`, opened without unfolding (the `let`s and `have`s at its head
substituted, `zetaHead`, so that none hides a binder), must be no proposition (else `"a
premise"`) and have a closed inhabitant (`closedInhabited`, else `"a binder of no known
inhabitant"`); it is opened as a new local, and `v` (its head's `let`s and `have`s substituted) is
opened with it: the body of `v`'s `fun` at that local, or `v` applied to it when `v` is no
`fun`. Every binder's type has a closed inhabitant, so the statement holds at those inhabitants:
a witness that holds for every value of its binders holds at one. -/
partial def openWitness {α : Type} (ty v : Expr)
    (k : Expr → Expr → Meta.MetaM (Except String α)) : Meta.MetaM (Except String α) := do
  match zetaHead ty with
  | .forallE n t b bi =>
    if ← Meta.isProp t then return .error "a premise"
    unless ← closedInhabited t do return .error "a binder of no known inhabitant"
    Meta.withLocalDecl n bi t fun x => do
      let v' := match zetaHead v with
        | .lam _ _ bv _ => bv.instantiate1 x
        | v => (mkApp v x).headBeta
      openWitness (b.instantiate1 x) v' k
  | body => k body (zetaHead v)

/-- The launch and the observed run of a witness statement's body `b` in **the witness form**,
read syntactically (metadata dropped, no definition unfolded): `b` is
`MojoProof.Sem.Launch.Valid L ∧ ∃ y, MojoProof.Sym.Kernel.Obs prog fn L' args m obs ch ω y ∧ Q y`,
the `Kernel.Obs` application with its ten arguments, the last the bound `y` and the others
mentioning no `y`; `(L, Kernel.Obs …)` with the `∃`'s variable loose, else `none`. -/
def witnessForm? (b : Expr) : Option (Expr × Expr) := do
  let b := b.consumeMData
  guard (b.isAppOfArity ``And 2)
  let v := (b.getArg! 0).consumeMData
  guard (v.isAppOfArity `MojoProof.Sem.Launch.Valid 1)
  let ex := (b.getArg! 1).consumeMData
  guard (ex.isAppOfArity ``Exists 2)
  let .lam _ _ body _ := (ex.getArg! 1).consumeMData | none
  let body := body.consumeMData
  guard (body.isAppOfArity ``And 2)
  let o := (body.getArg! 0).consumeMData
  guard (o.isAppOfArity `MojoProof.Sym.Kernel.Obs 10)
  guard ((o.getArg! 9).consumeMData == .bvar 0)
  guard ((List.range 9).all fun i => !(o.getArg! i).hasLooseBVars)
  return (v.getArg! 0, o)

/-- **The witness rule.** Theorem `w`, of type `ty` and value `v`, is a witness of the theorems
`chain` gives at its soundness proof when:
* its binders pass `openWitness` (none a proposition, each of a type with a closed `Inhabited`
  instance, the proof opened at the same locals);
* its statement's body is in the witness form (`witnessForm?`):
  `L.Valid ∧ ∃ y, Kernel.Obs prog fn L args m obs ch ω y ∧ Q y`, with the same launch `L` in both
  conjuncts (`isDefEq` at reducible transparency), mentioning no binder;
* its proof's body is `And.intro` of a proof of `L.Valid` and
  `MojoProof.Sem.Kernel.Sound.exists_obs` applied to its 13 arguments (the `let`s and `have`s at
  their heads substituted), at the launch `L` (`isDefEq`);
* the observation (`exists_obs`'s eighth argument) depends on its argument (`dependsOnArg`).

`L.Valid` holds, so the launch has a block and a thread: a kernel sound at a launch with no thread
(`launch2 0 1 1 1`, sound for any relation of the initial memory) has no witness there. When the
relation (`exists_obs`'s ninth) is not constant `True` (`isTrueRel`), `w` witnesses every theorem
of the chain; when it is, only the spec-free ones: those that conclude a soundness term
(`soundTerms`) and none that relates the output. Otherwise `.error` with the first rule that
fails: `"a premise"`, `"a binder of no known inhabitant"`, `"a binder behind a definition"` (the
body is no witness form and unfolds, by `whnfD`, to a `∀`: a definition or abbreviation hides a
binder), `"not the witness form"`, `"an open launch"` (`L` mentions a binder), `"another launch"`,
`"not the witness proof"`, `"no exists_obs"`, `"a constant observation"` or `"a constant
relation"` (no spec-free theorem in the chain). `whnfD` only names the refusal: a body is accepted
by its syntax alone. -/
def witnessOf (env : Environment) (ty v : Expr) : Meta.MetaM (Except String (Array Name)) :=
  openWitness ty v fun b pv => do
    let some (L, o) := witnessForm? b |
      return .error (if (← Meta.whnfD b).isForall then "a binder behind a definition"
        else "not the witness form")
    if L.hasFVar || L.hasMVar || L.hasLooseBVars then return .error "an open launch"
    unless ← Meta.withReducible (Meta.isDefEq L (o.getArg! 3)) do return .error "another launch"
    let pb := zetaHead pv
    unless pb.isAppOfArity ``And.intro 4 do return .error "not the witness proof"
    let h := zetaHead (pb.getArg! 3)
    unless h.isAppOfArity `MojoProof.Sem.Kernel.Sound.exists_obs 13 do
      return .error "no exists_obs"
    unless ← Meta.isDefEq (h.getArg! 3) L do return .error "another launch"
    unless ← dependsOnArg (h.getArg! 7) do return .error "a constant observation"
    let ts ← chain env (h.getArg! 9)
    unless ← isTrueRel (h.getArg! 8) do return .ok ts
    let safe ← ts.filterM fun n => do
      let some ci := env.find? n | return false
      let ss ← soundTerms ci.type
      return !ss.isEmpty && !ss.any (·.relates)
    if safe.isEmpty then return .error "a constant relation"
    return .ok safe

/-- Whether value `v` is a candidate of the witness rule: under its `fun`s (`lamBody`) it is
`MojoProof.Sem.Kernel.Sound.exists_obs` applied to 13 arguments (the old form, which the rule
refuses for its statement), or `And.intro` applied to four whose last is such an application (the
`let`s and `have`s at each head substituted). -/
def candidateValue (v : Expr) : Bool :=
  let b := lamBody v
  let obs (e : Expr) := (zetaHead e).isAppOfArity `MojoProof.Sem.Kernel.Sound.exists_obs 13
  obs b || (b.isAppOfArity ``And.intro 4 && obs (b.getArg! 3))

/-- The theorems of `env` that the witness rule is tried on: those of the modules `mods`, and
the main module's, whose value is a candidate (`candidateValue`), sorted by name. -/
def candidates (env : Environment) (mods : NameSet) : Array (Name × Expr × Expr) := Id.run do
  let ok (n : Name) (ci : ConstantInfo) : Option (Name × Expr × Expr) :=
    match ci with
    | .thmInfo t =>
      if !n.isInternal && candidateValue t.value then some (n, t.type, t.value) else none
    | _ => none
  let mut out := #[]
  for i in [0:env.header.moduleNames.size] do
    if mods.contains env.header.moduleNames[i]! then
      for n in env.header.moduleData[i]!.constNames do
        if let some ci := env.find? n then
          if let some c := ok n ci then out := out.push c
  out := env.constants.foldStage2 (fun acc n ci => match ok n ci with
    | some c => acc.push c
    | none => acc) out
  return out.qsort (fun a b => a.1.lt b.1)

/-- The witness rule's verdict on each candidate (`candidates`, `witnessOf`); an exception
raised while checking one is its verdict, as `.error`. -/
def verdicts (env : Environment) (mods : NameSet) :
    IO (Array (Name × Except String (Array Name))) :=
  (candidates env mods).mapM fun (w, ty, v) => do
    let r ← runMeta env do
      try witnessOf env ty v catch e => return .error s!"error: {← e.toMessageData.toString}"
    return (w, r)

/-- The witness table's header line. -/
def witnessHeader : String := "theorem\twitness\n"

/-- The witness table's text for the theorems `names`: one row `theorem, witness` per witness of
each (a candidate whose verdict lists it), or one row with `-` when it has none; header first,
rows sorted, without repetition. -/
def witnessTable (names : Array Name) (vs : Array (Name × Except String (Array Name))) :
    String := Id.run do
  let mut rows : Array String := #[]
  for n in names do
    let ws := vs.filterMap fun (w, r) => match r with
      | .ok ts => if ts.contains n then some w else none
      | .error _ => none
    let rs := if ws.isEmpty then #[s!"{n}\t-"] else ws.map (s!"{n}\t{·}")
    for r in rs do
      unless rows.contains r do rows := rows.push r
  return witnessHeader ++ String.join ((rows.qsort (· < ·)).toList.map (· ++ "\n"))

/-- The programs mentioned in `e`, anywhere, each with its function when that has no loose bound
variable, free variable or metavariable: the program and function of each soundness term in it
(`soundParts?`) and of each application of `MojoProof.Sym.Kernel.Obs` to its ten arguments (the
second and third), when the program has none of those. Without repetition. -/
partial def mentions (e : Expr) : Meta.MetaM (Array (Expr × Option Expr)) := do
  let mut out := #[]
  let pf? ← if e.isAppOfArity `MojoProof.Sym.Kernel.Obs 10 then
      pure (some (e.getArg! 1, e.getArg! 2))
    else pure ((← soundParts? e).map fun (p, f, _) => (p, f))
  let closed (x : Expr) := !x.hasLooseBVars && !x.hasFVar && !x.hasMVar
  if let some (p, f) := pf? then
    if closed p then out := out.push (p, if closed f then some f else none)
  let subs := match e with
    | .app f a => #[f, a]
    | .lam _ t b _ | .forallE _ t b _ => #[t, b]
    | .letE _ t v b _ => #[t, v, b]
    | .mdata _ b | .proj _ _ b => #[b]
    | _ => #[]
  for s in subs do
    for p in ← mentions s do
      unless out.contains p do out := out.push p
  return out

/-- The conclusion `e` of a statement read for the level rule, its variables new free variables
that no local context holds (the rule only compares terms and their heads): the variables its
`∃`s bind and its atoms, through `∃` (its body), `∧` (both sides) and `∀` or `→` (the body; the
premise is no atom); what is left is an atom. -/
partial def conclusionAtoms (e : Expr) : Meta.MetaM (Array Expr × Array Expr) := do
  let e := e.consumeMData
  if e.isAppOfArity ``Exists 2 then
    if let .lam _ _ b _ := (e.getArg! 1).consumeMData then
      let x := mkFVar (← mkFreshFVarId)
      let (xs, ats) ← conclusionAtoms (b.instantiate1 x)
      return (#[x] ++ xs, ats)
  if e.isAppOfArity ``And 2 then
    let (x1, a1) ← conclusionAtoms (e.getArg! 0)
    let (x2, a2) ← conclusionAtoms (e.getArg! 1)
    return (x1 ++ x2, a1 ++ a2)
  if let .forallE _ _ b _ := e then
    return ← conclusionAtoms (b.instantiate1 (mkFVar (← mkFreshFVarId)))
  return (#[], #[e])

/-- The variable term `e` names an output by, when it has one of the accepted shapes (metadata
dropped): a variable `x`, `some x`, or `MojoProof.Sem.Layout.encode l t (MojoProof.Sem.Val.ofFloat
t' x)` (the bytes of the float `x`); `x`, else `none`. -/
def identVar? (e : Expr) : Option Expr :=
  let e := e.consumeMData
  let var (x : Expr) : Option Expr := let x := x.consumeMData; if x.isFVar then some x else none
  if e.isFVar then some e
  else if e.isAppOfArity ``Option.some 2 then var (e.getArg! 1)
  else if e.isAppOfArity `MojoProof.Sem.Layout.encode 3 then
    let v := (e.getArg! 2).consumeMData
    if v.isAppOfArity `MojoProof.Sem.Val.ofFloat 2 then var (v.getArg! 1) else none
  else none

/-- The runs of the outputs that term `e` mentions (`outs` maps each output to its run), without
repetition. -/
def runsIn (outs : Array (Expr × Nat)) (e : Expr) : Array Nat :=
  outs.foldl (fun rs (o, r) => if e.containsFVar o.fvarId! && !rs.contains r then rs.push r
    else rs) #[]

/-- The outputs of a statement and their runs: the observed values `outs` (each with its run),
then each variable `x` of `xs` (its conclusion's `∃`s) that an **identifying equation** among the
atoms `atoms` makes an output: an `Eq` atom one side of which names `x` (`identVar?`: `x`,
`some x` or the bytes of the float `x`) and the other mentions the outputs of exactly one run and
no variable of `xs` that is no output yet; `x` is then an output of that run. Repeated until none
is added. So `Elem.word … B k = some v` makes `v` an output of `B`'s run, and neither
`(y, z) = (y, z)` nor `z = z` makes `z` one. -/
def outputsOf (outs : Array (Expr × Nat)) (xs atoms : Array Expr) : Array (Expr × Nat) := Id.run do
  let mut out := outs
  for _ in [0:xs.size] do
    for a in atoms do
      let a := a.consumeMData
      unless a.isAppOfArity ``Eq 3 do continue
      for (s, t) in [(a.getArg! 1, a.getArg! 2), (a.getArg! 2, a.getArg! 1)] do
        let some x := identVar? s | continue
        unless xs.contains x && !out.any (·.1 == x) do continue
        if xs.any fun z => !out.any (·.1 == z) && t.containsFVar z.fvarId! then continue
        if let #[r] := runsIn out t then out := out.push (x, r)
  return out

/-- Whether `e`'s value is a TorchLean operation's: its head constant is in the namespace
`TorchLean`, or it is an arithmetic operator (`+`, `-`, `*`, `/`, negation, `max`, `min`) at a
type whose head constant is (`x + y` of TorchLean tensors, applied to an index or not). -/
def torchValue (e : Expr) : Bool :=
  let torch (x : Expr) := x.getAppFn.consumeMData.constName?.any (`TorchLean).isPrefixOf
  let ops := [``HAdd.hAdd, ``HSub.hSub, ``HMul.hMul, ``HDiv.hDiv, ``Neg.neg, ``Max.max, ``Min.min]
  torch e || (e.getAppFn.consumeMData.constName?.any ops.contains && e.getAppNumArgs > 0 &&
    torch (e.getArg! 0))

/-- The run of `e` when it is an output (a variable of `outs`), or with `real`, `toReal` (a
constant whose last component is `toReal`) of one. -/
def outputRun? (outs : Array (Expr × Nat)) (real : Bool) (e : Expr) : Option Nat :=
  let e := e.consumeMData
  let run (x : Expr) := (outs.find? (·.1 == x.consumeMData)).map (·.2)
  if real then
    if e.getAppFn.consumeMData.constName?.any (fun n => n.componentsRev.head? == some `toReal) &&
      e.getAppNumArgs > 0 then run e.appArg! else none
  else run e

/-- The levels atom `a` of a conclusion states, each with the run it is about (`outs`, from
`outputsOf`): `L3` for an equation, `NaNEq` or `FinEq` (MojoProof/Sem/FloatRel.lean) of an output
and a TorchLean operation's value (`torchValue`) that mentions no output; `L4` for an equation of
an output's real value (`toReal`) and `Model.roundAt` of a real that mentions no output (the real
result rounded, so the exact float), or an inequality `|s - t| ≤ b` where one of `s`, `t`
mentions outputs of exactly one run and the other and `b` mention none (an error bound against a
value that is no output). The level goes to that run. -/
def atomLevels (outs : Array (Expr × Nat)) (a : Expr) : Array (Nat × String) := Id.run do
  let a := a.consumeMData
  let none? (e : Expr) := (runsIn outs e).isEmpty
  let mut lv := #[]
  if a.isAppOfArity ``Eq 3 || a.isAppOfArity `MojoProof.Sem.NaNEq 3 ||
      a.isAppOfArity `MojoProof.Sem.FinEq 3 then
    let round (e : Expr) :=
      e.getAppFn.consumeMData.isConstOf `FloatLib.Floats.Formats.BinaryInterchange.Model.roundAt
    for (l, r) in [(a.getArg! 1, a.getArg! 2), (a.getArg! 2, a.getArg! 1)] do
      if let some i := outputRun? outs false l then
        if torchValue r && none? r then lv := lv.push (i, "L3")
      if let some i := outputRun? outs true l then
        if a.isAppOfArity ``Eq 3 && round r && none? r then lv := lv.push (i, "L4")
  if a.isAppOfArity ``LE.le 4 then
    let l := (a.getArg! 2).consumeMData
    if l.getAppFn.consumeMData.isConstOf ``abs && l.getAppNumArgs > 0 && none? (a.getArg! 3) then
      let d := l.appArg!.consumeMData
      if d.isAppOfArity ``HSub.hSub 6 then
        for (s, t) in [(d.getArg! 4, d.getArg! 5), (d.getArg! 5, d.getArg! 4)] do
          if let #[i] := runsIn outs s then
            if none? t then lv := lv.push (i, "L4")
  return lv

/-- **The level rule.** The observed runs of statement `t`, each with its program, its function
and the levels its conclusion states about it, read by head constants and argument shapes,
without unfolding. A run is a premise `MojoProof.Sym.Kernel.Obs prog fn L args m obs ch ω y`
(the binders of `t`, opened in order; its last argument a variable, the run's output) or such an
atom of the conclusion at a variable its `∃`s bind; the outputs of each run are its observed
value and the variables identifying equations make outputs of it (`outputsOf`); and the conclusion's
atoms (`conclusionAtoms`) give each run the levels of `atomLevels`: `L3`, an output of the run is
a TorchLean operation's value; `L4`, an output's real value is a real rounded, or its error
against a value is bounded. Levels in the order `L3`, `L4`. A statement whose conclusion is
soundness (`Kernel.Sound … ∧ True`), mentions a program only in a soundness premise, or relates
no output to such a value states no level of any run; an output of one run gives no level to
another. The rule does not read what the TorchLean value is of: an equation of an output and
TorchLean's sum of two other tensors (not those the memory holds) has the form of `L3`, as a
bound of any size has the form of `L4`. -/
def runLevels (t : Expr) : Meta.MetaM (Array (Expr × Expr × Array String)) := do
  let mut e := t
  let mut runs : Array (Expr × Expr) := #[]
  let mut outs : Array (Expr × Nat) := #[]
  repeat
    let .forallE _ ty b _ := e.consumeMData | break
    let ty := ty.consumeMData
    if ty.isAppOfArity `MojoProof.Sym.Kernel.Obs 10 && (ty.getArg! 9).consumeMData.isFVar then
      outs := outs.push ((ty.getArg! 9).consumeMData, runs.size)
      runs := runs.push (ty.getArg! 1, ty.getArg! 2)
    e := b.instantiate1 (mkFVar (← mkFreshFVarId))
  let (xs, atoms) ← conclusionAtoms e
  for a in atoms do
    let a := a.consumeMData
    if a.isAppOfArity `MojoProof.Sym.Kernel.Obs 10 then
      let y := (a.getArg! 9).consumeMData
      if xs.contains y && !outs.any (·.1 == y) then
        outs := outs.push (y, runs.size)
        runs := runs.push (a.getArg! 1, a.getArg! 2)
  let all := outputsOf outs xs atoms
  let lvs := atoms.flatMap (atomLevels all)
  return runs.mapIdx fun i (p, f) => (p, f, #["L3", "L4"].filter fun l => lvs.contains (i, l))

/-- The evidence table's header line. -/
def evidenceHeader : String := "name\tkind\tlevels\tprogram\tfile\tsha256\n"

/-- The rows of evidence name `n`: `name, kind, levels, program, file, digest`, one per program its
type mentions (`mentions`), bound to its file with its function (`boundSound`); its kind is
`theorem`, `definition` or `other` (another declaration), `-` with all else `-` when it is no
declaration; its levels those the level rule gives the runs of that program and function
(`runLevels`, terms compared syntactically; a mention whose function is open takes the runs of its
program), `-` for none; and `-` for the program, file, digest and levels when its type mentions
none. So a theorem about two kernels' runs has each kernel's levels in its own row. -/
def evidenceRows (env : Environment) (n : Name) : Meta.MetaM (Array String) := do
  let some ci := env.find? n | return #[s!"{n}\t-\t-\t-\t-\t-"]
  let kind := match ci with
    | .thmInfo _ => "theorem"
    | .defnInfo _ => "definition"
    | _ => "other"
  let rl ← runLevels ci.type
  let ps ← mentions ci.type
  if ps.isEmpty then return #[s!"{n}\t{kind}\t-\t-\t-\t-"]
  let files := MojoProof.LLVM.progFiles.getState env
  dedup <$> ps.mapM fun (p, f) => do
    let lv := #["L3", "L4"].filter fun l => rl.any fun (p', f', ls) =>
      p'.consumeMData == p.consumeMData && f.all (·.consumeMData == f'.consumeMData) &&
        ls.contains l
    let lv := if lv.isEmpty then "-" else " ".intercalate lv.toList
    let b ← match f with
      | some f => boundSound env files p f
      | none => pure none
    match b with
    | some (c, file) =>
      return s!"{n}\t{kind}\t{lv}\t{c}\t{file}\t{(← digestOf (mkConst c)).getD "-"}"
    | none => return s!"{n}\t{kind}\t{lv}\t{programText p}\t-\t-"

/-- The evidence table's text for the names `names`, header first, rows sorted. -/
def evidenceTable (env : Environment) (names : Array Name) : IO String := do
  let rows := (← runMeta env (names.flatMapM (evidenceRows env))).qsort (· < ·)
  return evidenceHeader ++ String.join (rows.toList.map (· ++ "\n"))

/-- The kinds table's header line. -/
def kindsHeader : String := "theorem\tprogram\tkind\n"

/-- The kinds table's text for the theorems `names` (those of `programs.tsv`): the rows of each
(`kindRows`: `theorem, program, kind`, one per soundness term), header first, rows sorted, without
repetition. -/
def kindsTable (env : Environment) (names : Array Name) : IO String := do
  let rows ← runMeta env (names.flatMapM (kindRows env))
  return kindsHeader ++ String.join (((dedup rows).qsort (· < ·)).toList.map (· ++ "\n"))

/-- The corpus file of the self-test's outer program. -/
def vaddFile : String := "vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll"
/-- The corpus file of the self-test's inner program. -/
def vmulFile : String :=
  "vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll"

/-- The self-test's module, at conversion `conv` (a theorem `conversionArg?` accepts, found by
shape): `Outer.p.prog` imported, `Outer.Inner.p.prog` shadowing it, `Outer.q.prog` a mutant with
its digest, theorems about them (`outer`, `both` a conjunction, `inner`, `mutant`, `premise` a
premise only, `negated`, `gpu` in `GPUProof`'s form, `conj_k` a conjunction at two programs and
`nospec_k` at the relation `noSpec`), a term elaborator `wform%` that states the witness form of
a soundness proof, the witnesses in that form (`obs_w`, `have_w`, `have_k_w`, `gemv_w` through
`conv`), the candidates the witness rule refuses or credits less (the module docstring), and the
level fixtures `vmul_extra` and `pair`. -/
def selfTest (conv : String) : String := s!"
namespace L3Test.Outer
mojo_import \"{vaddFile}\" as p
open Lean Elab Term Meta in
/-- `wform% L h ch ω`: the witness form of soundness proof `h`, of
`Kernel.Sound prog fn L' args m adm obs R`, at `ch`, `ω` and launch `L`:
`L.Valid ∧ ∃ y, Kernel.Obs prog fn L' args m obs ch ω y ∧ R y`. -/
elab \"wform% \" L:term:max h:term:max ch:term:max ω:term:max : term => do
  let h ← elabTerm h none
  synthesizeSyntheticMVarsNoPostponing
  let t ← instantiateMVars (← inferType h)
  unless t.isAppOfArity `MojoProof.Sem.Kernel.Sound 9 do throwError \"wform%: no Kernel.Sound\"
  let a := t.getAppArgs
  let nat := Lean.mkConst ``Nat
  let L ← elabTermEnsuringType L (Lean.mkConst `MojoProof.Sem.Launch)
  let ch ← elabTermEnsuringType ch (← mkArrow nat nat)
  let ω ← elabTermEnsuringType ω (← mkArrow nat (← mkArrow nat nat))
  synthesizeSyntheticMVarsNoPostponing
  let body ← withLocalDeclD `y a[0]! fun y => do
    let o := mkAppN (Lean.mkConst `MojoProof.Sym.Kernel.Obs)
      #[a[0]!, a[1]!, a[2]!, a[3]!, a[4]!, a[5]!, a[7]!, ch, ω, y]
    mkLambdaFVars #[y] (mkAnd o (mkApp a[8]! y).headBeta)
  instantiateMVars (mkAnd (mkApp (Lean.mkConst `MojoProof.Sem.Launch.Valid) L)
    (mkApp2 (Lean.mkConst ``Exists [Level.one]) a[0]! body))
/-- A statement about the outer program. -/
theorem outer (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) := fun _ _ h => h.elim
/-- `outer`'s observation from a premise `False`. -/
theorem outer_w (h : False) :
    wform% MojoProofTest.Kernel.L23 (outer MojoProofTest.Kernel.L23 MojoProofTest.Kernel.mem5)
      id (fun _ _ => 0) :=
  ⟨MojoProofTest.Kernel.valid23, (outer _ _).exists_obs (ch := id) (ω := fun _ _ => 0) h⟩
/-- A class whose instance proves `False`. -/
class Gate : Type where
  /-- The proof of `False`. -/
  impossible : False
/-- `Gate` is inhabited when it has an instance: that instance. -/
instance gate_inhabited [g : Gate] : Inhabited Gate := ⟨g⟩
/-- A statement about the outer program at `correct23`'s launch, arguments and memory that admits
nothing, its observation the blocks and its relation `y = y`. -/
theorem seen : MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0
    MojoProofTest.Kernel.L23 (MojoProof.Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5))
    MojoProofTest.Kernel.mem5 (fun _ _ => False) (fun m => some m.blocks) (fun y => y = y) :=
  fun _ _ h => h.elim
/-- `seen`'s observation from a `Gate` instance, whose field proves the admission `False`. -/
theorem gate_w [g : Gate] : wform% MojoProofTest.Kernel.L23 seen id (fun _ _ => 0) :=
  ⟨MojoProofTest.Kernel.valid23, (seen).exists_obs (ch := id) (ω := fun _ _ => 0) g.impossible⟩
/-- An alias of a statement whose premise `False` discharges `seen`'s admission. -/
abbrev Hidden : Prop := ∀ _h : False, wform% MojoProofTest.Kernel.L23 seen id (fun _ _ => 0)
/-- `seen`'s observation at the alias `Hidden`. -/
theorem hidden_w : Hidden := fun h =>
  ⟨MojoProofTest.Kernel.valid23, (seen).exists_obs (ch := id) (ω := fun _ _ => 0) h⟩
/-- `correct23`'s observation in the witness form. -/
theorem obs_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (MojoProofTest.Kernel.correct23 ω) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (MojoProofTest.Kernel.correct23 ω).exists_obs (ch := ch) (ω := ω)
    rfl⟩
/-- `correct23`'s observation in the form before the launch conjunct. -/
theorem old_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    type_of% ((MojoProofTest.Kernel.correct23 ω).exists_obs (ch := ch) (ω := ω) rfl) :=
  (MojoProofTest.Kernel.correct23 ω).exists_obs rfl
/-- `correct23`'s observation, its relation weakened to `True`. -/
theorem trivial_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (MojoProof.Sem.Kernel.Sound.map (f := some)
      (R' := fun _ => True) (fun y _ => ⟨y, rfl, trivial⟩) (MojoProofTest.Kernel.correct23 ω))
      ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (MojoProof.Sem.Kernel.Sound.map (f := some) (R' := fun _ => True)
    (fun y _ => ⟨y, rfl, trivial⟩) (MojoProofTest.Kernel.correct23 ω)).exists_obs (ch := ch)
    (ω := ω) rfl⟩
/-- A bridge: soundness at an admission gives it at the admission and `True`, by a `fun`. -/
theorem bridge \{β : Type} \{prog : MojoProof.LLVM.Program} \{fn : MojoProof.LLVM.Func}
    \{L : MojoProof.Sem.Launch} \{args : List MojoProof.Sem.Val} \{m : MojoProof.Sem.Mem}
    \{adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} \{obs : MojoProof.Sem.Mem → Option β}
    \{R : β → Prop} (h : MojoProof.Sem.Kernel.Sound prog fn L args m adm obs R) :
    MojoProof.Sem.Kernel.Sound prog fn L args m (fun ch ω => adm ch ω ∧ True) obs R :=
  fun ch ω ha => h ch ω ha.1
/-- `correct23`'s observation through `bridge`. -/
theorem bridge_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (bridge (MojoProofTest.Kernel.correct23 ω)) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (bridge (MojoProofTest.Kernel.correct23 ω)).exists_obs (ch := ch)
    (ω := ω) ⟨rfl, trivial⟩⟩
/-- `seen`'s observation through `bridge` from a `Gate` instance (the admission `False ∧ True`). -/
theorem bridge_gate_w [g : Gate] :
    wform% MojoProofTest.Kernel.L23 (bridge seen) id (fun _ _ => 0) :=
  ⟨MojoProofTest.Kernel.valid23,
    (bridge seen).exists_obs (ch := id) (ω := fun _ _ => 0) ⟨g.impossible, trivial⟩⟩
/-- `correct23`'s observation through `Kernel.Sound.map` at the relation `y = y`. -/
theorem remap_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (MojoProof.Sem.Kernel.Sound.map (f := some)
      (R' := fun y => y = y) (fun y _ => ⟨y, rfl, rfl⟩) (MojoProofTest.Kernel.correct23 ω)) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (MojoProof.Sem.Kernel.Sound.map (f := some) (R' := fun y => y = y)
    (fun y _ => ⟨y, rfl, rfl⟩) (MojoProofTest.Kernel.correct23 ω)).exists_obs (ch := ch) (ω := ω)
    rfl⟩
/-- Every kernel is sound at the admission `False`. -/
theorem vacuous \{β : Type} \{prog : MojoProof.LLVM.Program} \{fn : MojoProof.LLVM.Func}
    \{L : MojoProof.Sem.Launch} \{args : List MojoProof.Sem.Val} \{m : MojoProof.Sem.Mem}
    \{obs : MojoProof.Sem.Mem → Option β} \{R : β → Prop} :
    MojoProof.Sem.Kernel.Sound prog fn L args m (fun _ _ => False) obs R := fun _ _ h => h.elim
/-- A bridge that does not use its first argument: the second's soundness, by a `fun`. -/
theorem ignore \{β : Type} \{prog : MojoProof.LLVM.Program} \{fn : MojoProof.LLVM.Func}
    \{L : MojoProof.Sem.Launch} \{args : List MojoProof.Sem.Val} \{m : MojoProof.Sem.Mem}
    \{adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} \{obs : MojoProof.Sem.Mem → Option β}
    \{R : β → Prop} (_h : MojoProof.Sem.Kernel.Sound prog fn L args m (fun _ _ => False) obs R)
    (h : MojoProof.Sem.Kernel.Sound prog fn L args m adm obs R) :
    MojoProof.Sem.Kernel.Sound prog fn L args m adm obs R := fun ch ω ha => h ch ω ha
/-- `correct23`'s observation through `ignore`, its unused argument `vacuous`. -/
theorem ignore_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (ignore vacuous (MojoProofTest.Kernel.correct23 ω)) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (ignore vacuous (MojoProofTest.Kernel.correct23 ω)).exists_obs
    (ch := ch) (ω := ω) rfl⟩
/-- A case split: soundness at either of two admissions gives it at their disjunction. -/
theorem choose \{β : Type} \{prog : MojoProof.LLVM.Program} \{fn : MojoProof.LLVM.Func}
    \{L : MojoProof.Sem.Launch} \{args : List MojoProof.Sem.Val} \{m : MojoProof.Sem.Mem}
    \{adm adm' : (Nat → Nat) → (Nat → Nat → Nat) → Prop} \{obs : MojoProof.Sem.Mem → Option β}
    \{R : β → Prop} (h : MojoProof.Sem.Kernel.Sound prog fn L args m adm obs R)
    (h' : MojoProof.Sem.Kernel.Sound prog fn L args m adm' obs R) :
    MojoProof.Sem.Kernel.Sound prog fn L args m (fun ch ω => adm ch ω ∨ adm' ch ω) obs R :=
  fun ch ω ha => ha.elim (h ch ω) (h' ch ω)
/-- `correct23`'s observation through `choose`, at the branch of `correct23`, not `vacuous`'s. -/
theorem choose_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (choose vacuous (MojoProofTest.Kernel.correct23 ω)) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (choose vacuous (MojoProofTest.Kernel.correct23 ω)).exists_obs
    (ch := ch) (ω := ω) (Or.inr rfl)⟩
/-- `correct23`'s observation, its proof a `have` of `correct23`. -/
theorem have_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (MojoProofTest.Kernel.correct23 ω) ch ω :=
  have h := MojoProofTest.Kernel.correct23 ω
  ⟨MojoProofTest.Kernel.valid23, h.exists_obs (ch := ch) (ω := ω) rfl⟩
/-- `correct23`, its proof a `have` of it. -/
theorem have_k (ω : Nat → Nat → Nat) : type_of% (MojoProofTest.Kernel.correct23 ω) :=
  have h := MojoProofTest.Kernel.correct23 ω
  h
/-- `have_k`'s observation. -/
theorem have_k_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (have_k ω) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (have_k ω).exists_obs (ch := ch) (ω := ω) rfl⟩
/-- `seen`'s observation from a `Gate` instance, its proof a `have` of `seen`. -/
theorem have_gate_w [g : Gate] : wform% MojoProofTest.Kernel.L23 seen id (fun _ _ => 0) :=
  have h := seen
  ⟨MojoProofTest.Kernel.valid23, h.exists_obs (ch := id) (ω := fun _ _ => 0) g.impossible⟩
/-- `seen`'s observation from a premise `False` behind a `have` in its statement. -/
theorem have_prem_w : have _z := 0; ∀ _h : False,
    wform% MojoProofTest.Kernel.L23 seen id (fun _ _ => 0) := fun h =>
  ⟨MojoProofTest.Kernel.valid23, (seen).exists_obs (ch := id) (ω := fun _ _ => 0) h⟩
section
open MojoProof.Sem MojoProof.LLVM
/-- A start at a launch whose grid has no block has no thread and an empty trace. -/
theorem start_empty \{prog : Program} \{fn : Func} \{L : Launch} \{args : List Val} \{m : Mem}
    \{ch : Nat → Nat} \{ω : Nat → Nat → Nat} \{g : Grid} \{c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch ω = .ok (g, c)) (h0 : volume L.grid = 0) :
    g.threads = #[] ∧ g.mem.trace = [] := by
  unfold Grid.start at h
  rw [h0] at h
  simp only [Nat.zero_mul, List.range_zero, List.foldlM_nil] at h
  revert h
  cases fn.check prog.module <;> cases fn.checkLaunch prog.module L.block args.length <;>
    cases m.checkClosed args <;> simp [bind, Except.bind, pure, Except.pure]
  rintro rfl rfl
  simp
/-- A grid with no thread and an empty trace is sound for an observation its memory has. -/
theorem empty_sound \{L : Launch} \{c : Nat → Ctx} \{g : Grid} (h0 : g.threads = #[])
    (ht : g.mem.trace = []) \{β : Type} \{obs : Mem → Option β} \{R : β → Prop} \{y : β}
    (hy : obs g.mem = some y) (hR : R y) : Grid.Sound L c g obs R := by
  have nost : ∀ g', ¬ Grid.Step L c g g' := by
    rintro g' ⟨n, h⟩
    simp [Grid.advance, Grid.fire, h0, pure, Except.pure] at h
  have reach : ∀ g', Relation.ReflTransGen (Grid.Step L c) g g' → g' = g := by
    intro g' h
    induction h with
    | refl => rfl
    | tail _ hs ih => subst ih; exact absurd hs (nost _)
  have done : GPUProof.Done sig (g, L, c) := Grid.done_iff.2 fun n _ => .inl (by simp [h0])
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro g' hr hf
    rw [reach g' hr] at hf
    obtain ⟨n, e, he | he⟩ := Grid.faults_iff.1 hf <;>
      simp [Grid.advance, Grid.fire, h0, pure, Except.pure] at he
  · intro g' hr; rw [reach g' hr, ht]; rfl
  · intro g' hr; rw [reach g' hr, ht]; simp only [List.map_nil, List.reverse_nil]; decide
  · intro g' hr hnd; rw [reach g' hr] at hnd; exact absurd done hnd
  · exact ⟨_, fun g' hs => absurd hs (nost g')⟩
  · intro g₁ g₂ h1 h2 _ _; rw [reach _ h1, reach _ h2]
  · intro g' hr _; rw [reach g' hr]; exact ⟨y, hy, hR⟩
/-- `vector_addition` at the launch `launch2 0 1 1 1`, which has no thread: sound at every
admission for the blocks and `y = y`. -/
theorem zero_k : Kernel.Sound MojoProof.Kernels.vadd.prog MojoProof.Kernels.vadd.fn_0
    (launch2 0 1 1 1) (MojoProof.Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5))
    MojoProofTest.Kernel.mem5 (fun _ _ => True) (fun m => some m.blocks) (fun y => y = y) :=
  fun ch ω _ => by
    obtain ⟨g, c, h⟩ := MojoProof.Kernels.vadd.starts (launch2 0 1 1 1) 1 2 3 _
      MojoProofTest.Kernel.pre5.closed ch ω
    obtain ⟨h0, ht⟩ := start_empty h rfl
    exact ⟨g, c, h, empty_sound h0 ht rfl rfl⟩
/-- `zero_k`'s observation in the form before the launch conjunct: the caller's blocks, at once. -/
theorem zero_w : type_of% (zero_k.exists_obs (ch := fun _ => 0) (ω := fun _ _ => 0) trivial) :=
  zero_k.exists_obs trivial
/-- `zero_k`'s observation in the witness form, its launch conjunct at another launch. -/
theorem zero_v_w : wform% (launch2 1 1 1 1) zero_k (fun _ => 0) (fun _ _ => 0) :=
  ⟨launch2_valid (by decide), zero_k.exists_obs (ch := fun _ => 0) (ω := fun _ _ => 0) trivial⟩
end
/-- `vadd_real` behind an unused premise about the `vmul` program. -/
theorem vmul_extra (_h : MojoProof.Sem.Kernel.Sound MojoProof.Kernels.vmul.prog
      MojoProof.Kernels.vmul.fn_0 MojoProofTest.Kernel.L23 [] MojoProofTest.Kernel.mem5
      (fun _ _ => False) (fun _ => (none : Option Unit)) (fun _ => True)) :
    type_of% @MojoProofTest.Kernel.vadd_real :=
  by intro _; intros; apply MojoProofTest.Kernel.vadd_real <;> assumption
/-- An equation of a pair that holds of every output, then one of its second component and a
TorchLean sum. -/
theorem pair \{L : MojoProof.Sem.Launch} \{m : MojoProof.Sem.Mem} \{ch : Nat → Nat}
    \{ω : Nat → Nat → Nat} \{B : Nat → Option MojoProof.Sem.Block} \{N : Nat}
    (x y : TorchLean.Tensor
      (FloatLib.Floats.Formats.BinaryInterchange.Model (MojoProof.LLVM.FloatTy.float).fmt) [N])
    (_hB : MojoProof.Sym.Kernel.Obs MojoProof.Kernels.vadd.prog MojoProof.Kernels.vadd.fn_0 L
      (MojoProof.Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) m (fun m => some m.blocks) ch ω B) :
    ∃ z, (B, z) = (B, z) ∧ z = x + y := ⟨x + y, rfl, rfl⟩
/-- A named relation that holds of every value. -/
def noSpec \{β : Type} (_ : β) : Prop := True
/-- `correct23`'s soundness weakened to `noSpec`. -/
theorem nospec_k (ω : Nat → Nat → Nat) :
    type_of% (MojoProof.Sem.Kernel.Sound.map (f := some) (R' := noSpec)
      (fun y _ => ⟨y, rfl, trivial⟩) (MojoProofTest.Kernel.correct23 ω)) :=
  MojoProof.Sem.Kernel.Sound.map (f := some) (R' := noSpec) (fun y _ => ⟨y, rfl, trivial⟩)
    (MojoProofTest.Kernel.correct23 ω)
/-- `nospec_k`'s observation. -/
theorem nospec_w (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    wform% MojoProofTest.Kernel.L23 (nospec_k ω) ch ω :=
  ⟨MojoProofTest.Kernel.valid23, (nospec_k ω).exists_obs (ch := ch) (ω := ω) rfl⟩
/-- A conjunction of a spec-free soundness term about the outer program and one with a
specification about the `vmul` program. -/
theorem conj_k (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Nat)) (fun _ => True) ∧
    MojoProof.Sem.Kernel.Sound MojoProof.Kernels.vmul.prog MojoProof.Kernels.vmul.fn_0 L [] m
      (fun _ _ => False) (fun _ => (none : Option Nat)) (fun y => y = 0) :=
  ⟨fun _ _ h => h.elim, fun _ _ h => h.elim⟩
section
open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest
/-- gemv_kernel's observation at one block of 64 threads through the conversion `{conv}` of
`GemvSound.sound64`. -/
theorem gemv_w : wform% (launch2 1 1 64 1)
    ({conv} (obs := GemvSound.rowsObs (launch2 1 1 64 1) 2 3)
      (fun _ _ hb => congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _))
      GemvSound.sound64) (fun _ => 0) (fun _ _ => 0) :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs
    ({conv} (obs := GemvSound.rowsObs (launch2 1 1 64 1) 2 3)
      (fun _ _ hb => congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _))
      GemvSound.sound64)
    (ch := fun _ => 0) (ω := fun _ _ => 0) fun _ => Nat.two_pow_pos 60⟩
end
/-- A conjunction, about the outer program. -/
theorem both (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog MojoProof.Kernels.vadd.fn_0 L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) ∧ True := ⟨fun _ _ h => h.elim, trivial⟩
/-- A function that only returns, with the outer program's kernel's header. -/
def void.fn : MojoProof.LLVM.Func :=
  \{ MojoProof.Kernels.vadd.fn_0 with blocks := #[⟨0, #[], .ret none⟩] }
/-- A statement about the outer program and the function that only returns. -/
theorem void_k (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    MojoProof.Sem.Kernel.Sound p.prog void.fn L [] m (fun _ _ => False)
      (fun _ => (none : Option Unit)) (fun _ => True) := fun _ _ h => h.elim
/-- A statement about the outer program in `GPUProof`'s form. -/
theorem gpu (L : MojoProof.Sem.Launch) (m : MojoProof.Sem.Mem) :
    GPUProof.Kernel.Sound MojoProof.Sem.sig (p.prog, MojoProof.Kernels.vadd.fn_0) L [] m
      (fun _ => False) (fun _ => (none : Option Unit)) (fun _ => True) := fun _ h => h.elim
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

/-- The conversions of `env` (`conversionArg?`), sorted by name: its theorems whose statement's
conclusion, after its binders, is `MojoProof.Sem.Kernel.Sound` and one of whose binders' types is
`GPUProof.Kernel.Sound` (read syntactically first), checked by shape. -/
def conversions (env : Environment) : IO (Array Name) := do
  let mut out := #[]
  for (n, ci) in env.constants.toList do
    let .thmInfo t := ci | continue
    if n.isInternal || !t.type.getForallBody.isAppOf `MojoProof.Sem.Kernel.Sound then continue
    let rec binders : Expr → List Expr
      | .forallE _ d b _ => d :: binders b
      | _ => []
    unless (binders t.type).any (·.isAppOf `GPUProof.Kernel.Sound) do continue
    if (← runMeta env (conversionArg? t.type)).isSome then out := out.push n
  return out.qsort (·.lt ·)

/-- The self-test (the module docstring): exit code 0 when every table and verdict is the
expected one. -/
unsafe def runSelfTest : IO UInt32 := do
  let env ← importModules #[{ module := `MojoProof.Kernels }, { module := `MojoProof.Sem.Spec },
    { module := `MojoProof.LLVM.Mutate }, { module := `MojoProofTest.Kernel },
    { module := `MojoProofTest.GemvObs }] {} (trustLevel := 1024) (loadExts := true)
  let convs ← conversions env
  IO.println s!"conversions: {convs}"
  let some conv := convs[0]? | IO.eprintln "self-test failed: no conversion"; return 1
  let (env, msgs) ← Elab.process (selfTest conv.toString) (env.setMainModule `L3Test) {}
    (fileName := "<L3Programs self-test>")
  for m in msgs.toList do
    IO.eprintln (← m.toString)
  if msgs.hasErrors then return 1
  let o (n : Name) : Name := `L3Test.Outer ++ n
  let names := (#[`outer, `both, `gpu, `premise, `negated, `mutant, `void_k, `Inner.inner].map o)
    |>.push `MojoProof.Kernels.vadd.correct
  let got ← table env names
  let vadd ← manifestDigest vaddFile
  let vmul ← manifestDigest vmulFile
  let row (n p f d : String) := s!"L3Test.Outer.{n}\tL3Test\t{p}\t{f}\t{d}\n"
  let want := header ++
    row "Inner.inner" "MojoProof.Kernels.vmul.prog" s!"tests/corpus/{vmulFile}" vmul ++
    row "both" "L3Test.Outer.p.prog" s!"tests/corpus/{vaddFile}" vadd ++
    row "gpu" "L3Test.Outer.p.prog" s!"tests/corpus/{vaddFile}" vadd ++
    row "mutant" "L3Test.Outer.q.prog" "-" "-" ++
    row "negated" "-" "-" "-" ++
    row "outer" "L3Test.Outer.p.prog" s!"tests/corpus/{vaddFile}" vadd ++
    row "premise" "-" "-" "-" ++
    row "void_k" "L3Test.Outer.p.prog" "-" "-" ++
    s!"MojoProof.Kernels.vadd.correct\tMojoProof.Kernels.Vadd\tMojoProof.Kernels.vadd.prog\t\
      tests/corpus/{vaddFile}\t{vadd}\n"
  IO.print got
  -- The mutant records the outer program's digest: the digest alone would bind it to `vadd`.
  let kept ← runMeta env (digestOf (mkConst `L3Test.Outer.q.prog))
  if got != want || kept != some vadd then
    IO.eprintln s!"self-test failed: expected\n{want}and the mutant's digest {vadd}, not {kept}"
    return 1
  -- The witness rule on the main module's candidates only.
  let vs ← verdicts env {}
  let why (w : Name) : String := match vs.find? (·.1 == w) with
    | some (_, .error e) => e
    | some (_, .ok _) => "accepted"
    | none => "no candidate"
  let ts (w : Name) : Array Name := match vs.find? (·.1 == w) with
    | some (_, .ok ts) => ts
    | _ => #[]
  let wt := witnessTable names vs
  let wrow (n w : String) := s!"L3Test.Outer.{n}\t{w}\n"
  let vrow (w : String) := s!"MojoProof.Kernels.vadd.correct\tL3Test.Outer.{w}\n"
  let wwant := witnessHeader ++ wrow "Inner.inner" "-" ++ wrow "both" "-" ++ wrow "gpu" "-" ++
    wrow "mutant" "-" ++ wrow "negated" "-" ++ wrow "outer" "-" ++ wrow "premise" "-" ++
    wrow "void_k" "-" ++ vrow "have_k_w" ++ vrow "have_w" ++ vrow "obs_w"
  IO.print wt
  -- `obs_w`'s chain `ts0` starts at `correct23` and holds `vadd.correct`.
  let ts0 := ts (o `obs_w)
  let gemv := ts (o `gemv_w)
  let chains : List (Name × Array Name) := [(o `obs_w, ts0), (o `have_w, ts0),
    (o `have_k_w, #[o `have_k] ++ ts0), (o `bridge_w, #[o `bridge]),
    (o `ignore_w, #[o `ignore]), (o `remap_w, #[`MojoProof.Sem.Kernel.Sound.map]),
    (o `choose_w, #[o `choose]), (o `nospec_w, #[o `nospec_k])]
  -- gemv's chain: the conversion, `sound64` and the theorem it is an instance of, then on.
  let gemvWant := #[conv, `MojoProofTest.GemvSound.sound64, `MojoProofTest.GemvSound.kernel_sound]
  let refused : List (Name × String) := [(o `outer_w, "a premise"),
    (o `gate_w, "a binder of no known inhabitant"),
    (o `bridge_gate_w, "a binder of no known inhabitant"),
    (o `have_gate_w, "a binder of no known inhabitant"), (o `have_prem_w, "a premise"),
    (o `hidden_w, "a binder behind a definition"), (o `trivial_w, "a constant relation"),
    (o `old_w, "not the witness form"), (o `zero_w, "not the witness form"),
    (o `zero_v_w, "another launch")]
  -- Each `have` fixture has its form: a `let` under the value's `fun`s, or the statement's head.
  let isLet (e : Expr) : IO Bool := runMeta env (Meta.lambdaTelescope e fun _ b =>
    return b.consumeMData.isLet)
  let value (n : Name) : Expr := match env.find? n with
    | some (.thmInfo t) => t.value
    | _ => default
  let forms := [← isLet (value (o `have_w)), ← isLet (value (o `have_k)),
    ← isLet (value (o `have_gate_w)),
    ((env.find? (o `have_prem_w)).map (·.type.consumeMData.isLet)) == some true]
  for (w, _) in chains ++ [(o `gemv_w, gemv)] do
    IO.println s!"{w}: {why w} {ts w}"
  for (w, _) in refused do
    IO.println s!"{w}: {why w}"
  if wt != wwant || ts0.size < 2 || ts0[0]? != some `MojoProofTest.Kernel.correct23 ||
      !ts0.contains `MojoProof.Kernels.vadd.correct || gemv.extract 0 3 != gemvWant ||
      chains.any (fun (w, want) => why w != "accepted" || ts w != want) ||
      refused.any (fun (w, r) => why w != r) || forms.any (!·) then
    IO.eprintln s!"self-test failed: expected the witness table\n{wwant}obs_w's chain {ts0} to \
      start with correct23 and hold vadd.correct, gemv_w's to start with {gemvWant}, the chains \
      {chains}, the refusals {refused}, and each have fixture's let (got {forms})"
    return 1
  let knames := names ++ #[o `conj_k, o `nospec_k]
  let kt ← kindsTable env knames
  let krow (n p k : String) := s!"L3Test.Outer.{n}\t{p}\t{k}\n"
  let op := "L3Test.Outer.p.prog"
  let kwant := kindsHeader ++ krow "Inner.inner" "MojoProof.Kernels.vmul.prog" "safe" ++
    krow "both" op "safe" ++ krow "conj_k" op "safe" ++
    krow "conj_k" "MojoProof.Kernels.vmul.prog" "correct" ++ krow "gpu" op "safe" ++
    krow "mutant" "L3Test.Outer.q.prog" "safe" ++ krow "negated" "-" "safe" ++
    krow "nospec_k" "MojoProof.Kernels.vadd.prog" "safe" ++ krow "outer" op "safe" ++
    krow "premise" "-" "safe" ++ krow "void_k" op "safe" ++
    "MojoProof.Kernels.vadd.correct\tMojoProof.Kernels.vadd.prog\tcorrect\n"
  IO.print kt
  if kt != kwant then
    IO.eprintln s!"self-test failed: expected the kinds table\n{kwant}"
    return 1
  let ev ← evidenceTable env #[o `premise, o `both, `MojoProofTest.Kernel.vadd_real,
    o `vmul_extra, o `pair]
  let erow (n lv p f d : String) := s!"{n}\ttheorem\t{lv}\t{p}\ttests/corpus/{f}\t{d}\n"
  let ewant := evidenceHeader ++ erow "L3Test.Outer.both" "-" op vaddFile vadd ++
    erow "L3Test.Outer.pair" "-" "MojoProof.Kernels.vadd.prog" vaddFile vadd ++
    erow "L3Test.Outer.premise" "-" op vaddFile vadd ++
    erow "L3Test.Outer.vmul_extra" "-" "MojoProof.Kernels.vmul.prog" vmulFile vmul ++
    erow "L3Test.Outer.vmul_extra" "L3 L4" "MojoProof.Kernels.vadd.prog" vaddFile vadd ++
    erow "MojoProofTest.Kernel.vadd_real" "L3 L4" "MojoProof.Kernels.vadd.prog" vaddFile vadd
  IO.print ev
  if ev != ewant then
    IO.eprintln s!"self-test failed: expected the evidence table\n{ewant}"
    return 1
  IO.println "self-test: the shadowing program is bound through the inner declaration to the \
    vmul file, the conjunction and the GPUProof form to the vadd file; the mutant keeps the vadd \
    digest and is bound to no file, and the function that only returns is bound to no file with \
    the vadd program; the premise and the negation are about no program; in the witness form, \
    correct23's observation (directly, through a have, or through have_k, an instance) witnesses \
    vadd.correct, and gemv's through the conversion witnesses sound64 and kernel_sound; the \
    bridge, the unused-argument bridge, the remap and the case split credit their head only; the \
    premise, Gate, alias, constant-relation, old-form, empty-launch and other-launch candidates \
    are refused; noSpec and the conjunction's True term are safe, its vmul term correct; vadd_real \
    is of L3 and L4 at vadd, its vmul_extra copy at vadd only, and the pair fixture of no level"
  return 0

/-- The four tables' files. -/
def outs : List System.FilePath :=
  ["roadmap/llvm-ir/programs.tsv", "roadmap/llvm-ir/witnesses.tsv",
    "roadmap/llvm-ir/evidence.tsv", "roadmap/llvm-ir/kinds.tsv"]

/-- `--self-test`, `--check`, or with no argument writes the tables (the module docstring). -/
unsafe def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  if args == ["--self-test"] then return ← runSelfTest
  if args != [] && args != ["--check"] then
    IO.eprintln "usage: lake env lean --run scripts/L3Programs.lean [--check | --self-test]"
    return 2
  let mods := (← modulesIn "MojoProof") ++ (← modulesIn "MojoProofTest")
  let env ← importModules (mods.map ({ module := · })) {} (trustLevel := 1024) (loadExts := true)
  let set := mods.foldl NameSet.insert {}
  let names ← theorems env set
  let texts := [← table env names, witnessTable names (← verdicts env set),
    ← evidenceTable env ((← cardNamesAt ["L3", "L4"]).map String.toName),
    ← kindsTable env names]
  if args == ["--check"] then
    let mut ok := true
    for (out, text) in outs.zip texts do
      let old ← if ← out.pathExists then IO.FS.readFile out else pure ""
      if old != text then
        IO.eprintln s!"{out} is stale: run `lake env lean --run scripts/L3Programs.lean`"
        IO.eprint text
        ok := false
      else
        IO.println s!"{out} is current ({(text.splitOn "\n").length - 2} rows)"
    return if ok then 0 else 1
  for (out, text) in outs.zip texts do
    IO.FS.writeFile out text
    IO.println s!"wrote {out} ({(text.splitOn "\n").length - 2} rows)"
  return 0
