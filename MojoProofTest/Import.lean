import MojoProof.Kernels

/-!
# Tests of `mojo_import`

The imported terms are usable in the kernel (their kernel names, function counts and block
constants, by `rfl`); the comparison that checks a term against the importer's program finds a
changed field (`Program.diff`); the comparison of the printed term with the file's tokens finds a
changed token and its line (`printDiff`); and the command refuses a file with no manifest row and
a file outside the subset, naming the construct, and a changed file: `tests/stale/k.ll` is a
kernel with a comment added after its manifest row was written (the row has the digest of the
file without it). The digest check alone is tested on a program (`digestError`). That functions
and blocks two imports share are defined once is checked by the gate's `DUPDEF` count.
-/

namespace MojoProofTest

open MojoProof MojoProof.LLVM

example : Kernels.vadd.prog.kernels = ["vector_addition_vector_addition6A6A_793e5fe36a195e73"] ∧
    Kernels.vadd.prog.module.funcs.size = 4 := ⟨rfl, rfl⟩

example : Kernels.matmul.prog.kernels.length = 1 := rfl

example : Kernels.vadd.fn_0.blocks = #[Kernels.vadd.fn_0.b_0, Kernels.vadd.fn_0.b_1,
    Kernels.vadd.fn_0.b_2, Kernels.vadd.fn_0.b_3] ∧
    Kernels.vadd.fn_0.names[Kernels.vadd.fn_0.b_1.label]? = some "21" :=
  ⟨rfl, rfl⟩

#guard Program.diff Kernels.vadd.prog Kernels.vadd.prog == []
#guard Program.diff Kernels.vadd.prog { Kernels.vadd.prog with kernels := [] } == ["kernels"]

#guard digestError "p" Kernels.vadd.prog.sha256 Kernels.vadd.prog == none &&
  digestError "p" "00" Kernels.vadd.prog ==
    some s!"mojo_import: p has sha256 {Kernels.vadd.prog.sha256}, the manifest 00: the file changed"

#guard
  let text := "define void @f(i32 %0) {\n  %2 = add i32 %0, 1 ; one\n  ret void\n}\n"
  match parse text.toUTF8 with
  | .ok m => printDiff text.toUTF8 m == none &&
      printDiff (text.replace "add" "sub").toUTF8 m == some 2 &&
      printDiff (text.replace "ret void\n" "ret void\n  ret void\n").toUTF8 m == some 4
  | .error _ => false

/-- error: mojo_import: vadd/none.ll has no row in tests/corpus/MANIFEST.tsv -/
#guard_msgs in
mojo_import "vadd/none.ll" as none

/--
error: mojo_import: mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll is
outside the subset: unsupported inline asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h" in
'@matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3'
-/
#guard_msgs (whitespace := lax) in
mojo_import "mgemm/g_matmul_split_k_reduce_r2_w16_b256_gs_False_623520a3.nvptx.ll" as refused

/--
error: mojo_import: k.ll has sha256
580ffd58c744f7cd264b6504e60083c7ab2535d4d70881c04faee079dbf7604f, the manifest
6266afcbca2e815512094bd6506d6b81e34233137742e8600e1443485d61e008: the file changed
-/
#guard_msgs (whitespace := lax) in
set_option mojo_import.root "tests/stale" in
mojo_import "k.ll" as stale

end MojoProofTest
