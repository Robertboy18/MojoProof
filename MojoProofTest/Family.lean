import MojoProof.LLVM.Family
import MojoProofTest.SymPhi
import MojoProofTest.SymLane

/-!
# Tests of the command `mojo_family`: the naive kernel at every row stride

`NaiveFam.prog sA sB sC` and `NaiveFam.fn sA sB sC` are the naive matmul kernel of
tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll
(`SymPhi.naive`) with the constants of its three stride multiplications as parameters: `%26 = mul
i32 %25, 768` (line 27, the row stride of `A`, `sA`), `%37 = mul i32 %36, 768` (line 38, of `B`,
`sB`) and `%27 = mul i32 %25, 50257` (line 28, of `C`, `sC`). The equation
`NaiveFam.prog_corpus`, which the command adds, is the corpus file at `768, 768, 50257`.

The second specialization, tests/corpus/naive_k512/ (`K = 512`, `N = 256`), is the family at
`512, 512, 256` up to its kernel's name (its lines 27, 28 and 38 are `mul i32 %25, 512`, `mul i32
%25, 256` and `mul i32 %36, 512`), by `rfl` below. The three refusals are a statement with no
integer constant operand, a local the function does not have and two parameters at one statement.

gevm_kernel's specialization at tile size 512, tests/corpus/gevm_t512/, is not an instance of a
family of constants of the tile-1024 file (tests/corpus/gemv/, `SymLane.gevm`): a family keeps
every block's statements and changes constants only, and the two functions' blocks have different
numbers of statements (the 512 one has four shuffles, not five), as the last `example` decides.
-/

namespace MojoProofTest

open MojoProof MojoProof.LLVM

mojo_import "naive_k512/naive_f32_\
  matmul_kernel_naive_float32_float32_float32_True_16_50910765.nvptx.ll" as naive512

mojo_import "gevm_t512/gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll"
  as gevm512

/-- The naive matmul kernel at row strides `sA` (of `A`), `sB` (of `B`) and `sC` (of `C`). -/
mojo_family NaiveFam := SymPhi.naive.prog 0 with sA at "%26", sB at "%37", sC at "%27"

example : NaiveFam.prog 768 768 50257 = SymPhi.naive.prog ∧
    NaiveFam.fn 768 768 50257 = SymPhi.naive.fn_0 :=
  NaiveFam.prog_corpus

-- The second specialization: the family at `512, 512, 256` with the name of `naive512`'s
-- kernel, the one difference left in the function (the `define` at line 7 of its file).
example : NaiveFam.fn 512 512 256 = { naive512.fn_0 with name := SymPhi.naive.fn_0.name } := rfl

example : (NaiveFam.fn 512 512 256).blocks = naive512.fn_0.blocks := rfl

/--
error: mojo_family: %25 is not a two-operand integer instruction with one integer constant operand
-/
#guard_msgs in
mojo_family Bad := SymPhi.naive.prog 0 with x at "%25"

/-- error: mojo_family: function 0 has no local %no -/
#guard_msgs in
mojo_family Bad := SymPhi.naive.prog 0 with x at "%no"

/-- error: mojo_family: two parameters name the same statement -/
#guard_msgs in
mojo_family Bad := SymPhi.naive.prog 0 with x at "%26", y at "26"

example : gevm512.fn_0.blocks.toList.map (·.stmts.size) ≠
    SymLane.gevm.fn_0.blocks.toList.map (·.stmts.size) := by decide

end MojoProofTest
