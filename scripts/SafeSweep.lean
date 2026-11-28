import MojoProof.LLVM.Import
import MojoProof.Sym.Info
import MojoProof.Sym.KernelCmd
import MojoProof.Kernels.SafeCmd

/-!
# The automation attempt of the breadth sweep (docs/proofs/safe.md)

`lake env lean --run scripts/SafeSweep.lean <state> <files> <revision>` reads `<state>/kept.tsv`
(written by `scripts/safe_sweep.py keep`: a header, then `file, source, function, kernel, sha256,
arch`) and, for each of its files (a per-kernel `.nvptx.ll` file under the directory `<files>`),
runs the steps of the spec-free attempt up to the first that fails (`attempt`), and writes
`<state>/attempts.tsv` (`file, sha256, revision, outcome, reason`: the digest of the bytes
attempted and the checker revision `<revision>`, which `scripts/safe_sweep.py revision` prints: a
digest of this script and the repository modules it imports), which `scripts/safe_sweep.py table`
reads. An attempt is keyed by (digest, revision): a kept file whose digest has a row at
`<revision>` in an existing `<state>/attempts.tsv` is not attempted again (`reusable`), so the step
resumes after a new compile and keep; a row at another revision or another digest is kept in the
file and not reused, so a change to the importer or the block checker attempts every file again:

1. the importer, as `mojo_import` runs it (`MojoProof.LLVM.parse`, then
   `MojoProof.LLVM.Module.check` at the file's SHA-256): on its error, `importer refusal` with
   its message;
2. the kernel (the program's first `ptx_kernel`), block by block, by the block checker with both
   flags (`MojoProof.Sym.summarizeAt true`, with `fmul contract`), from after each block's `phi`s
   (`MojoProof.Sym.phiCount`): at the first block it refuses, `automation failure` with
   `outside the fragment: <opcode>:` and the block and statement (`MojoProof.Sym.refusalAt`,
   `MojoProof.Sym.refusedText`);
3. the branches between the summaries' exits (`MojoProof.Sym.Exit.succs`), depth first from the
   entry block: at a branch back to a block on the current path, `automation failure` with
   `a loop at block <label>` (`backEdge`: the spec-free mode would need the loop's invariant);
4. the spec-free mode, as `mojo_safe` runs it (MojoProof/Kernels/SafeCmd.lean, `mode`): the
   parameter clauses from the function (`MojoProof.Sym.clausesFor`; on its error, `automation
   failure` with `the mode: <error>`), each block's summary with both flags off
   (`MojoProof.Sym.summarizeAt false`, as `mojo_kernel` without `fmul contract` and `alloca`;
   at a block refused there, `the mode: block <label> needs fmul contract or alloca`), the
   paths from the entry block to `ret` (`MojoProof.Sym.kernelSegs`), and `coversEntry` on them,
   evaluated: when it is false, `the mode: the path checker does not accept the paths`; when it
   is true, `automation failure` with `the mode applies`: `Kernel.safe_of_admits` at that
   `coversEntry` is `MojoProof.Sem.Kernel.Safe` at the admission `Kernel.Admits` for every
   launch, arguments and memory, but the attempt chooses no launch, arguments or memory at which
   the admission holds (the witness), so the outcome is not `proved`.

No step proves anything and no outcome is `proved` or `counterexample`: the attempt measures how
far the per-kernel automation gets without a specification (a `proved` row of the table is a
`mojo_safe … at` theorem of a test module, which `scripts/safe_sweep.py table` reads). With
`--self-test` it checks `reusable` at `reuseCases` and the attempt at the files of
`tests/corpus/` it names (`selfTest`), and exits 1 on a difference.
-/

open MojoProof MojoProof.LLVM MojoProof.Sym

namespace SafeSweep

/-- The rows of a tab-separated file after its header line, each split at its tabs; comment and
empty lines skipped. -/
def rows (f : System.FilePath) : IO (List (List String)) := do
  return ((← IO.FS.lines f).toList.drop 1).filter (fun l => l ≠ "" && !l.startsWith "#")
    |>.map (·.splitOn "\t")

/-- `s` on one line (tabs and line breaks as spaces), at most 240 characters. -/
def oneLine (s : String) : String :=
  String.ofList ((s.toList.map fun c => if c == '\t' || c == '\n' then ' ' else c).take 240)

/-- The block a depth-first search from block `i` reaches by a branch back to a block on the
current path `stack` (the header of a loop), given each block's successors `succ`; the blocks
finished are the state, and a finished block is not searched again. -/
partial def backEdge (succ : Nat → List Nat) (stack : List Nat) (i : Nat) :
    StateM (Array Nat) (Option Nat) := do
  if (← get).contains i then return none
  for j in succ i do
    if j == i || stack.contains j then return some j
    if let some h ← backEdge succ (i :: stack) j then return some h
  modify (·.push i)
  return none

/-- The opcode of a statement's LLVM text: the word after `= `, or the first word. -/
def opcode (t : String) : String :=
  let w := match t.splitOn " = " with
    | _ :: r :: _ => r
    | _ => t
  (w.splitOn " ").headD w

/-- Step 4, the spec-free mode at kernel `fn` of program `P`: the outcome and reason (the module
docstring). -/
def mode (P : Program) (fn : Func) : String × String := Id.run do
  if let .error e := clausesFor fn.params then
    return ("automation failure", oneLine s!"the mode: {e}")
  let mut sums : Array Summary := #[]
  for b in fn.blocks do
    match summarizeAt false P fn b.label (phiCount fn b.label) (fun σ tm => σ.exitAt fn b.label tm)
        false with
    | some S => sums := sums.push S
    | none => return ("automation failure", s!"the mode: block \
        %{fn.names[b.label]?.getD (toString b.label)} needs fmul contract or alloca (the mode is \
        at both flags off)")
  let idx (l : Nat) : Nat := (fn.blocks.findIdx? (·.label == l)).getD fn.blocks.size
  let succ (i : Nat) : List Nat := ((sums.getD i default).exit.succs).map idx
  let lbl (i : Nat) : Nat := (fn.blocks.getD i default).label
  let some es := (kernelSegs succ (fun _ => false) (fn.blocks.size + 1) [] 0).toOption
    | return ("automation failure", "the mode: a loop (no invariant)")
  let paths := (es.filterMap fun (p, e) => if e.isNone then some p else none).map fun p =>
    p.map fun i => (lbl i, (sums.getD i default).obls, sums.getD i default)
  if !coversEntry P fn paths then
    return ("automation failure", s!"the mode: the path checker does not accept the \
      {paths.length} paths (coversEntry is false)")
  return ("automation failure", s!"the mode applies ({fn.blocks.size} blocks, {paths.length} \
    paths): coversEntry holds, so Kernel.safe_of_admits gives Kernel.Safe at the admission \
    Kernel.Admits; no admitted launch, arguments and memory are chosen")

/-- The outcome and reason of the attempt at the file with bytes `bytes` and SHA-256 digest `sha`
(the module docstring's steps). -/
def attempt (bytes : ByteArray) (sha : String) : String × String := Id.run do
  let m ← match parse bytes with
    | .ok m => pure m
    | .error e => return ("importer refusal", oneLine e)
  let P ← match m.check sha with
    | .ok P => pure P
    | .error e => return ("importer refusal", oneLine e)
  let some k := P.kernels.head? | return ("importer refusal", "no ptx_kernel function")
  let some fn := m.funcs.find? (·.name == k) | return ("importer refusal", "no ptx_kernel body")
  let some b0 := fn.blocks[0]? | return ("importer refusal", "a kernel with no block")
  let mut succ : List (Nat × List Nat) := []
  for b in fn.blocks do
    let p0 := phiCount fn b.label
    match summarizeAt true P fn b.label p0 (fun σ tm => σ.exitAt fn b.label tm) true with
    | some S => succ := (b.label, S.exit.succs) :: succ
    | none =>
      let i := (refusalAt true true P fn b p0).getD b.stmts.size
      let t := refusedText fn b i
      let op := match b.stmts[i]? with
        | some _ => opcode ((t.splitOn ": ").drop 1 |> ": ".intercalate)
        | none => "terminator"
      let lbl := fn.names[b.label]?.getD (toString b.label)
      return ("automation failure", oneLine s!"outside the fragment: {op}: block %{lbl} {t}")
  let succOf (i : Nat) := (succ.lookup i).getD []
  let loop := ((backEdge succOf [] b0.label).run' #[]).run
  match loop with
  | some h =>
    return ("automation failure",
      s!"a loop at block %{fn.names[h]?.getD (toString h)}: the spec-free mode has no invariant")
  | none => return mode P fn

/-- The attempt's expected outcome at corpus files: the mode applies at `vector_addition`; the
naive matmul's kernel has its loop. Each a path under `tests/corpus/` and the start of the
reason. -/
def selfTest : List (String × String × String) := [
  ("vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll",
    "automation failure", "the mode applies (4 blocks, 2 paths)"),
  ("mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll",
    "automation failure", "a loop at block")]

/-- The row of `prev` (rows `file, sha256, revision, outcome, reason`) that the attempt at a file of
digest `sha` at revision `rev` reuses: the last with that digest and that revision, if any (the
file name is not part of the key). -/
def reusable (prev : List (List String)) (sha rev : String) : Option (List String) :=
  prev.reverse.find? fun r => r[1]? == some sha && r[2]? == some rev

/-- The rows `reusable` is checked at (`reuseCases`). -/
def reusePrev : List (List String) :=
  [["a.ll", "aa", "r0", "proved", "-"], ["b.ll", "bb", "r1", "proved", "-"],
    ["c.ll", "cc", "r1", "importer refusal", "x"]]

/-- `reusable`'s cases at `reusePrev`: (digest, revision, the file name of the row reused). A row
at the digest and the revision is reused; a row at an older revision (`aa` at `r0`), or at another
digest (`dd`), is not. -/
def reuseCases : List (String × String × Option String) :=
  [("aa", "r1", none), ("bb", "r0", none), ("dd", "r1", none), ("bb", "r1", some "b.ll"),
    ("cc", "r1", some "c.ll")]

/-- Run the attempt at every file of `<state>/kept.tsv` that `<state>/attempts.tsv` has no row for
at its digest and the revision, or the self-test. -/
def run (args : List String) : IO UInt32 := do
  if args == ["--self-test"] then
    let mut bad := 0
    for (sha, rev, f) in reuseCases do
      let g := (reusable reusePrev sha rev).bind (·.head?)
      unless g == f do
        IO.println s!"self-test: reusable {sha} {rev}: {g}, not {f}"; bad := bad + 1
    for (p, o, r) in selfTest do
      let path : System.FilePath := "tests/corpus" / p
      unless ← path.pathExists do
        IO.println s!"self-test: {p} is missing"; bad := bad + 1; continue
      let bytes ← IO.FS.readBinFile path
      let (o', r') := attempt bytes (SHA256.hex bytes)
      unless o' == o && r'.startsWith r do
        IO.println s!"self-test: {p}: {o'}: {r'}, not {o}: {r}…"; bad := bad + 1
    IO.println s!"self-test: {bad} differences"
    return if bad == 0 then 0 else 1
  let [state, files, rev] := args
    | IO.println "usage: SafeSweep.lean <state> <files> <revision>"; return 2
  let kept ← rows (System.FilePath.mk state / "kept.tsv")
  let att := System.FilePath.mk state / "attempts.tsv"
  -- rows of the older three-column format name no digest and no revision: dropped
  let prev := (← if ← att.pathExists then rows att else pure []).filter (·.length == 5)
  let mut out := "file\tsha256\trevision\toutcome\treason\n" ++
    String.join (prev.map fun r => "\t".intercalate r ++ "\n")
  let mut n := 0
  let mut reused := 0
  for r in kept do
    let some f := r.head? | continue
    let sha := r[4]?.getD ""
    if (reusable prev sha rev).isSome then reused := reused + 1; continue
    let bytes ← IO.FS.readBinFile (System.FilePath.mk files / f)
    let d := SHA256.hex bytes
    unless d == sha do IO.println s!"{f}: digest {d}, not kept.tsv's {sha}"
    let (o, why) := attempt bytes d
    out := out ++ s!"{f}\t{d}\t{rev}\t{o}\t{why}\n"
    n := n + 1
  IO.FS.writeFile att out
  IO.println s!"{n} attempts at revision {rev}, {reused} reused, {prev.length} rows kept from {att}"
  return 0

end SafeSweep

/-- The script's entry point (`SafeSweep.run`). -/
def main (args : List String) : IO UInt32 := SafeSweep.run args
