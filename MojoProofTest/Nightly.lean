import MojoProof.Kernels.Formats
import MojoProof.Sym.ContractOff
import MojoProofTest.Family
import MojoProofTest.NaiveSound
import MojoProofTest.SymLane

/-!
# The kernels' theorems at the files of Mojo 1.3.0.dev2026112705

The corpus has a second row of each kernel with a theorem, compiled by Mojo
`1.3.0.dev2026112705 (03c5ad77)` with the first row's flags from the same source (the same
source sha256 in tests/corpus/MANIFEST.tsv): the directories `vadd_dev2026112705/`,
`vmul_dev2026112705/`, `vsub_dev2026112705/`, `gemv_dev2026112705/` (gemv_kernel and gevm_kernel),
`mgemm_dev2026112705/` and `mgemm_nocontract_dev2026112705/` (the naive matmul kernel at
`float32`, named `…_343aedc5` by the newer compiler, `…_16826c8c` in the first rows). Each file
imports (`#mojo_corpus` below for the vector kernels' rows, `mojo_import` for the others). This
module runs the first rows' theorems on them, with no new kernel-specific line:

* **carried over unchanged**: `vector_addition`, vector_multiply and vector_subtraction. Each new
  file is byte for byte the older one: the SHA-256 of its bytes is the digest the older program
  records (`Kernels.vadd.prog.sha256`, …), which `mojo_import` checked against the older file's
  bytes (the `#eval` below, one pair at a time, with no literal digest). The importer is a
  function of the bytes, so each new file's program is the older one's, `Kernels.vadd.prog`,
  `Kernels.vmul.prog` and `Kernels.vsub.prog`, and `Kernels.vadd.correct`, `Kernels.vmul.correct`
  and `Kernels.vsub.correct` are the kernel theorems at the new files as they stand (up to
  SHA-256 collisions). The rows are checked, not imported under new names:
  an import would define the older module again (a duplicate definition), as `mojo_import`
  names an earlier import's functions but defines each module.
* **not carried over**: the naive matmul kernel. The newer compiler folds two of its nine blocks
  into others (seven blocks, `naive_blocks`), and changes nothing else after the folding. The
  same `mojo_kernel` run as MojoProofTest/NaiveSound.lean's, with its clauses (`mat` at the skip
  path `skipN` and the loop's chain `chainN`, then `inv`), fails on the new file: the path
  checker does not accept the chains (the `#guard_msgs` below). `skipN` and `chainN`
  (MojoProofTest/NaiveThread.lean) are lists of the older program's blocks and their summaries,
  written by hand, and the clause takes them as arguments; nothing derives them from the
  program, so a change of the block structure alone stops the run. Nor is the new kernel one of
  the naive family's (MojoProofTest/Family.lean), whose kernel keeps the older one's nine blocks
  at every row stride. The contraction-off file is the contract file with its `contract` flags
  removed (`naive_off`, by evaluation), so `Kernel.Sound.contractOff` would move a theorem of
  the contract file to it, as MojoProofTest/NaiveOff.lean does for the older pair; the contract
  file has none here.
* **not carried over**: gemv_kernel and gevm_kernel. Their theorems (MojoProofTest/GemvSound.lean,
  MojoProofTest/GevmSound.lean) are proved by hand from the older files' blocks and lines, with
  no `mojo_kernel` run to repeat. gemv_kernel's new function has 13 blocks, not 15, and differs
  from the older only by the folding; gevm_kernel's has 7, not 9, and its shared tile is another
  global, `@x_shared_storage_0` of type `[1 x {[1024 x float]}]` for `@_global_alloc_0` of type
  `[1024 x float]`, so it differs beyond the folding (`gemv_blocks`).
-/

namespace MojoProofTest.Nightly

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.SymPhi MojoProofTest.NaiveThread MojoProofTest.NaiveSpec

-- The new vector rows import, each file's SHA-256 checked against its row's digest.
/-- info: mojo_corpus: 3 rows, 3 imported, 0 refused as REFUSALS.tsv lists -/
#guard_msgs in
#mojo_corpus "vadd_dev2026112705" "vmul_dev2026112705" "vsub_dev2026112705"

-- Each new vector file against the older program whose theorem it carries over, directly: the
-- SHA-256 of the file's bytes (under the directory `mojo_import.root`, `tests/corpus`) is the
-- digest the older program records, which `mojo_import` checked against the older file's bytes.
-- No literal digest and no manifest row enters: a new file replaced, with its row, prints its own
-- digest here.
/--
info: vadd_dev2026112705: the digest of Kernels.vadd.prog
vmul_dev2026112705: the digest of Kernels.vmul.prog
vsub_dev2026112705: the digest of Kernels.vsub.prog
-/
#guard_msgs in
#eval show Lean.Elab.Command.CommandElabM Unit from do
  let root : System.FilePath := ⟨mojo_import.root.get (← Lean.getOptions)⟩
  let mut out : Array String := #[]
  for (dir, file, name, prog) in [
      ("vadd_dev2026112705", "vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll",
        "Kernels.vadd.prog", Kernels.vadd.prog),
      ("vmul_dev2026112705",
        "vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll",
        "Kernels.vmul.prog", Kernels.vmul.prog),
      ("vsub_dev2026112705",
        "vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll",
        "Kernels.vsub.prog", Kernels.vsub.prog)] do
    let d := MojoProof.SHA256.hex (← IO.FS.readBinFile (root / dir / file))
    out := out.push (if d == prog.sha256 then s!"{dir}: the digest of {name}"
      else s!"{dir}: {d}, not the digest {prog.sha256} of {name}")
  Lean.logInfo ("\n".intercalate out.toList)

mojo_import "mgemm_dev2026112705/\
  g_matmul_kernel_naive_float32_float32_float32_True_16_343aedc5.nvptx.ll" as naiveNew

mojo_import "mgemm_nocontract_dev2026112705/\
  g_matmul_kernel_naive_float32_float32_float32_True_16_343aedc5.nvptx.ll" as naiveOffNew

mojo_import "gemv_dev2026112705/\
  gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll" as gemvNew

mojo_import "gemv_dev2026112705/\
  gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll" as gevmNew

/-- The new naive matmul kernel has 7 blocks, the older (`SymPhi.naive`) 9, and so has the naive
family's kernel at every row stride (`NaiveFam.fn`, MojoProofTest/Family.lean): the new kernel is
not one of the family's. -/
theorem naive_blocks :
    naiveNew.fn_0.blocks.size = 7 ∧ MojoProofTest.SymPhi.naive.fn_0.blocks.size = 9 ∧
      ∀ sA sB sC, (MojoProofTest.NaiveFam.fn sA sB sC).blocks.size = 9 :=
  ⟨rfl, rfl, fun _ _ _ => rfl⟩

/-- The new contraction-off file's module is the new contract file's with the `contract` flags
removed (`Module.contractOff`), by evaluation, as for the older pair. -/
theorem naive_off : naiveOffNew.prog.module = naiveNew.prog.module.contractOff := rfl

/-- error: mojo_kernel: mat: the path checker does not accept the chains (coversChainsWith true,
naiveNew.fn_0) -/
#guard_msgs (whitespace := lax) in
mojo_kernel naiveRun := naiveNew.prog naiveNew.fn_0 reads bA := a1, bB := a2 writes bC := a0
  scalars m := a3, n := a4, K := a5 contract mat [skipN] [chainN] inv

/-- The new gemv_kernel has 13 blocks, the older (`SymLane.gemv`) 15; the new gevm_kernel 7, the
older (`SymLane.gevm`) 9; and the new gevm_kernel's global has another type than the older's. -/
theorem gemv_blocks :
    gemvNew.fn_0.blocks.size = 13 ∧ MojoProofTest.SymLane.gemv.fn_0.blocks.size = 15 ∧
      gevmNew.fn_0.blocks.size = 7 ∧ MojoProofTest.SymLane.gevm.fn_0.blocks.size = 9 ∧
      gevmNew.prog.module.globals.map (·.ty) ≠
        MojoProofTest.SymLane.gevm.prog.module.globals.map (·.ty) :=
  ⟨rfl, rfl, rfl, rfl, by decide +kernel⟩

end MojoProofTest.Nightly
