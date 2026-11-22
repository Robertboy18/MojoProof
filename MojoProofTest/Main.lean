import MojoProof.LLVM.Import
import MojoProof.LLVM.Printer
import MojoProofTest.Eval
import MojoProofTest.Gpu

/-!
# The test runner (`lake test`)

1. SHA-256 against the FIPS 180-4 example vectors.
2. Refusals: inputs outside the subset are refused with the construct named.
3. The corpus: for every file in `tests/corpus/MANIFEST.tsv`, the SHA-256 equals the manifest's,
   the file parses, printing it gives the file's tokens (`printDiff`), `parse (print m) = m`, and
   the closure check either accepts it or refuses it with exactly the reason listed in
   `tests/corpus/REFUSALS.tsv` (and every listed file is refused).
4. The evaluator on `vector_addition` and `tiled_matmul` (`MojoProofTest.Eval`).

Exits with status 1 on any failure. With the first argument `gpu`, it is instead the comparison of
a GPU run with the evaluator, `MojoProofTest.Gpu.main` on the other arguments, compiled (the
run of `lean --run tests/gpu/Compare.lean` interprets it).
-/

open MojoProof MojoProof.LLVM

/-- Example vectors of FIPS 180-4 (and the empty message). -/
def shaVectors : List (String × String) :=
  [("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
   ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
   ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")]

/-- Inputs outside the subset, with a fragment the refusal must contain. -/
def refusals : List (String × String) :=
  [("define void @f() {\n  invoke void @g()\n  ret void\n}", "unsupported instruction 'invoke'"),
   ("@g = global <{ i32 }> zeroinitializer", "unsupported type 'packed struct'"),
   ("@g = global <2 x { i32 }> zeroinitializer", "unsupported vector type"),
   ("@g = global <2 x <2 x i8>> zeroinitializer", "unsupported vector type"),
   ("@g = global <0 x i32> zeroinitializer", "unsupported vector type"),
   ("define void @f() {\n  %1 = load atomic i32, ptr null acquire, align 4\n  ret void\n}",
    "unsupported instruction 'load atomic'"),
   ("declare void @f(ptr inalloca(i32))", "unsupported attribute 'inalloca'"),
   ("define void @f() {\n  %1 = tail call i32 @g()\n  ret void\n}",
    "unsupported instruction 'tail'"),
   ("define void @f() {\n  call void @g()\n  ret void\n}", "call to undeclared function '@g'"),
   ("declare float @llvm.sqrt.f32(float)", "unsupported intrinsic '@llvm.sqrt.f32'"),
   ("declare i32 @llvm.smax.i64(i64, i64)", "unsupported intrinsic '@llvm.smax.i64'"),
   ("declare float @llvm.smax.f32(float, float)", "unsupported intrinsic '@llvm.smax.f32'"),
   ("define void @f() {\n  call void asm sideeffect \"exit;\", \"\"()\n  ret void\n}",
    "unsupported inline asm \"exit;\""),
   ("target datalayout = \"E-i64:64\"", "unsupported datalayout specification 'E'"),
   ("target datalayout = \"e-p:64:64:64:32\"",
    "unsupported datalayout specification 'p:64:64:64:32'"),
   ("target datalayout = \"e-a:64\"", "unsupported datalayout specification 'a:64'"),
   ("define void @f(i32 %0, i32 %\"0\") {\n  ret void\n}", "quoted numeric name \"0\""),
   ("declare void @\"1\"()", "quoted numeric name \"1\""),
   ("define void @f() {\n  br label %1, !llvm.loop !0\n1:\n  ret void\n}\n!0 = !{}",
    "unsupported metadata attachment on a terminator"),
   ("define void @f(i32 %a, i32 %a) {\n  ret void\n}", "'%a in @f' defined twice"),
   ("define void @f(i32 %0) {\n0:\n  ret void\n}", "'%0 in @f' defined twice"),
   ("declare void @f()\ndeclare void @f()", "'@f' defined twice"),
   ("@f = external addrspace(3) global i32\ndeclare void @f()", "'@f' defined twice"),
   ("!0 = !{}\n!0 = !{}", "'!0' defined twice"),
   ("@g = global ptr %x", "local name '%x' outside a function"),
   ("@g = global float fpext (half 0xH7E00 to float)",
    "unsupported constant expression 'fpext'"),
   ("define void @f(i8 %0, ptr %1) {\n  store i8 %0, ptr getelementptr (i8, ptr %1, i8 %0)\n" ++
    "  ret void\n}", "local name in a constant"),
   ("define void @f(i8 %0, ptr %1) {\n  store <1 x i8> <i8 %0>, ptr %1\n  ret void\n}",
    "local name in a constant")]

/-- The tab-separated rows of a file without its header. -/
def rows (path : System.FilePath) : IO (List (List String)) := do
  let ls := (← IO.FS.lines path).toList.filter (· ≠ "")
  return (ls.drop 1).map (·.splitOn "\t")

/-- The test driver `lake test` runs, on the corpus directory `args` names (default
`tests/corpus`): the SHA-256 vectors, the importer's refusals, and for every `MANIFEST.tsv` row its
digest, its parse, print and reparse, and its import or its listed refusal; then the evaluation
tests. Exit code 0 when every check passes, 1 otherwise. With the first argument `gpu`,
`MojoProofTest.Gpu.main` on the other arguments. -/
def main (args : List String) : IO UInt32 := do
  if args.head? == some "gpu" then return ← MojoProofTest.Gpu.main args.tail
  let root : System.FilePath := args.headD "tests/corpus"
  let mut fails : Array String := #[]
  for (msg, d) in shaVectors do
    let h := SHA256.hex msg.toUTF8
    unless h = d do fails := fails.push s!"sha256 \"{msg}\": {h}"
  for (src, frag) in refusals do
    match importBytes src.toUTF8 with
    | .ok _ => fails := fails.push s!"accepted: {src}"
    | .error e =>
      unless (e.splitOn frag).length > 1 do fails := fails.push s!"refusal '{e}' lacks '{frag}'"
  let listed := (← rows (root / "REFUSALS.tsv")).filterMap fun
    | [p, r] => some (p, r)
    | _ => none
  let manifest ← rows (root / "MANIFEST.tsv")
  let mut refused : Array (String × String) := #[]
  let mut ok := 0
  for row in manifest do
    let (p, sha) := (row.headD "", (row.drop 1).headD "")
    let bytes ← IO.FS.readBinFile (root / p)
    let h := SHA256.hex bytes
    unless h = sha do fails := fails.push s!"{p}: sha256 {h}, manifest {sha}"
    match parse bytes with
    | .error e => fails := fails.push s!"{p}: {e}"
    | .ok m =>
      if let some l := printDiff bytes m then
        fails := fails.push s!"{p}: the printed module's tokens differ from the file's at line {l}"
      match parse (print m).toUTF8 with
      | .error e => fails := fails.push s!"{p}: printed text does not parse: {e}"
      | .ok m' => unless m == m' do fails := fails.push s!"{p}: round trip changed the module"
      match m.check h with
      | .ok _ => ok := ok + 1
      | .error e => refused := refused.push (p, e)
  for (p, e) in refused do
    unless listed.contains (p, e) do fails := fails.push s!"{p}: refused but not listed: {e}"
  for (p, r) in listed do
    unless refused.contains (p, r) do fails := fails.push s!"{p}: listed refusal did not occur: {r}"
  fails := fails ++ (← MojoProofTest.evalTests)
  IO.println s!"sha256 vectors: {shaVectors.length}; refusal tests: {refusals.length}"
  IO.println s!"corpus: {manifest.length} files, {ok} imported, {refused.size} refused (listed)"
  for f in fails do IO.eprintln s!"FAIL {f}"
  if fails.isEmpty then IO.println "all tests passed"; return 0
  else IO.eprintln s!"{fails.size} failures"; return 1
