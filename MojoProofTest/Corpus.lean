import MojoProof.Kernels

/-!
# Tests of mojo_corpus (MojoProof/LLVM/Corpus.lean)

`#mojo_corpus` with no argument runs every row of `tests/corpus/MANIFEST.tsv`: every file has its
recorded digest, every file `tests/corpus/REFUSALS.tsv` does not list imports with `mojo_import`'s
checks, and every listed one is refused with exactly its reason. mojo_corpus on the directory
`reduction` adds its one file under the name its path gives (and its function unfolds with `rw` in
this module), and the names MojoProof/Kernels.lean gives with `as` are kept (`Kernels.vadd.*` and
`Kernels.matmul.*`; MojoProofTest/Import.lean tests their terms). The failures: `corpusPlan` on an
argument that names no row, `as` on a directory of two rows or on a refused row (named by its path
or by its directory), a row named twice, and a refusal with no row; `corpusRow` on a changed file, a
refusal with another reason, a listed file that imports and an unlisted one that is refused; and the
commands on a missing row and on the changed file `tests/stale/k.ll` (its directory has no
`REFUSALS.tsv`).
-/

namespace MojoProofTest.Corpus

open Lean (Name)
open MojoProof MojoProof.LLVM

-- Every row of the corpus.
/-- info: mojo_corpus: 111 rows, 82 imported, 29 refused as REFUSALS.tsv lists -/
#guard_msgs in
#mojo_corpus

/-! A directory imported under the names of its paths. -/

mojo_corpus "reduction"

example :
  reduction.reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.prog.kernels =
    ["reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d"] := rfl

-- A definition the command adds unfolds in this module too: its equation lemmas are enabled.
example : reduction.reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.fn_0 =
    reduction.reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.fn_0 := by
  rw [reduction.reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.fn_0]

#guard corpusName "mgemm/k.nvptx.ll" == `mgemm.k

-- The names Kernels.lean gives: `vmul` and `matmul` name their own block constants.
example : Kernels.vadd.prog.module = Kernels.vadd.module ∧
    Kernels.vmul.module.funcs[0]? = some Kernels.vmul.fn_0 ∧
    Kernels.matmul.module.funcs[0]? = some Kernels.matmul.fn_0 := ⟨rfl, rfl, rfl⟩

/-! The plan's failures, on two rows `d/a.ll` and `d/b.ll`. -/

/-- The plan of `args` over the rows `d/a.ll` and `d/b.ll` and the refusals `refs`, as the paths
and names it gives, or its failure. -/
def planText (refs : List (String × String)) (args : List (String × Option Name)) : String :=
  match corpusPlan [("d/a.ll", "0a"), ("d/b.ll", "0b")] refs args with
  | .ok plan => toString (plan.map fun (p, _, n, _) => (p, n))
  | .error e => e

/--
info: [(d/a.ll, d.a), (d/b.ll, d.b)]
[(d/b.ll, x), (d/a.ll, d.a)]
mojo_corpus: no row of MANIFEST.tsv is e or under e/
mojo_corpus: d as x names 2 rows, not one
mojo_corpus: d/a.ll as x is listed in REFUSALS.tsv
mojo_corpus: d/a.ll is named twice
mojo_corpus: REFUSALS.tsv lists e/c.ll, which has no row in MANIFEST.tsv
-/
#guard_msgs in
#eval IO.println ("\n".intercalate [planText [] [],
  planText [] [("d/b.ll", some `x), ("d/a.ll", none)], planText [] [("e", none)],
  planText [] [("d", some `x)], planText [("d/a.ll", "r")] [("d/a.ll", some `x)],
  planText [] [("d", none), ("d/a.ll", none)], planText [("e/c.ll", "r")] []])

-- `as` on a directory whose one row is refused: the row's refusal is found.
/-- info: mojo_corpus: e/c.ll as x is listed in REFUSALS.tsv -/
#guard_msgs in
#eval IO.println (match corpusPlan [("e/c.ll", "0c")] [("e/c.ll", "r")] [("e", some `x)] with
  | .ok _ => "planned" | .error e => e)

/-! The row checks. -/

/-- `corpusRow` on `text` with its digest (or `digest`) and the listed refusal `r`, as text. -/
def rowText (text : String) (r : Option String) (digest : Option String := none) : String :=
  match corpusRow "p" (digest.getD (SHA256.hex text.toUTF8)) text.toUTF8 r with
  | .ok (some _) => "imports"
  | .ok none => "refused as listed"
  | .error e => e

/-- A definition the importer accepts. -/
def good : String := "define void @f() {\n  ret void\n}\n"

/-- A declaration the importer refuses. -/
def bad : String := "declare float @llvm.sqrt.f32(float)\n"

/-- The importer's reason for refusing `bad`. -/
def badWhy : String := "unsupported intrinsic '@llvm.sqrt.f32' (declared, not defined)"

/--
info: imports
refused as listed
mojo_corpus: p has sha256 7957fcd37342c6824d64f017ef08aca2a643a2b4eab94258891ed0e1009ce109,
the manifest 00: the file changed
mojo_corpus: the importer refuses p with 'unsupported intrinsic '@llvm.sqrt.f32' (declared, not
defined)', REFUSALS.tsv with 'other'
mojo_corpus: p imports, but REFUSALS.tsv refuses it with 'r'
mojo_corpus: p is outside the subset: unsupported intrinsic '@llvm.sqrt.f32' (declared, not
defined)
-/
#guard_msgs (whitespace := lax) in
#eval IO.println ("\n".intercalate [rowText good none, rowText bad (some badWhy),
  rowText good none (some "00"), rowText bad (some "other"), rowText good (some "r"),
  rowText bad none])

/-! The commands' failures. -/

/-- error: mojo_corpus: no row of MANIFEST.tsv is vadd/none.ll or under vadd/none.ll/ -/
#guard_msgs in
mojo_corpus "vadd/none.ll" as none

/--
error: mojo_corpus: k.ll has sha256
580ffd58c744f7cd264b6504e60083c7ab2535d4d70881c04faee079dbf7604f, the manifest
6266afcbca2e815512094bd6506d6b81e34233137742e8600e1443485d61e008: the file changed
-/
#guard_msgs (whitespace := lax) in
set_option mojo_import.root "tests/stale" in
#mojo_corpus

end MojoProofTest.Corpus
