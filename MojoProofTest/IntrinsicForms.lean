import MojoProof.LLVM.Intrinsic

/-!
# The tensor-core intrinsic forms the importer reads, and the ones it refuses

`Intrinsic.ofDecl` is the importer's decision on a declaration (`Module.check`,
MojoProof/LLVM/Import.lean: a declaration it gives `none` makes the module "outside the subset").
Every declaration below has the signature LLVM gives the name (PTX ISA 9.5, sections
9.7.16.5.14-15: per lane, `m16n8k16` with f16 inputs has A in four `<2 x half>` registers and B
in two; f16 accumulators are two to a `<2 x half>` register, f32 ones one to a `float`).

* Read: `ldmatrix…m8n8.x4[.trans].b16.p3`, `mma….f32.f32` (f16 inputs, f32 accumulators) and
  `mma….tf32`. The corpus (tests/corpus) uses these and `mma` with `bf16` and `f64` names only:
  564 plain and 26 `.trans` `x4` loads, `m16n8k8.tf32` 977 times, `m16n8k16.bf16` 585 times,
  `m16n8k8.f32.f32`, `m16n8k8.bf16`, `m16n8k4.tf32` and `m8n8k4.f64` twice each; all import.
* Read and refused by `Mma.table`, the one list `Mma.ok` and the grid's layouts (`mmaFrags`)
  read: `m16n8k8.bf16` is read; `m16n8k24.bf16` and `m16n8k32.f32.f32`, shapes the ISA does not
  list, are refused with the register counts `Mma.regs` gives them.
* Refused, one test each: `mma` with f16 accumulators (`.f16.f16` at `m16n8k16`, `m16n8k8` and
  `m8n8k4`), with mixed accumulators (`.f32.f16`, `.f16.f32`), and `ldmatrix` `.x1` and `.x2`
  (with and without `.trans`). Reading them needs `Mma.regs`' accumulator count for f16
  (`m n / 64`, not `m n / 32`) and a load count in `Intrinsic.ldmatrix`.
-/

namespace MojoProofTest.IntrinsicForms

open MojoProof.LLVM

/-- `<2 x half>`, the register of two f16 elements. -/
def h2 : Ty := .vec 2 (.fp .half)

/-- The declaration `{ ret… } @name(a… , b…, c…)` of an `mma` with `a` A registers and `b` B
registers of type `t`, and `c` accumulator registers of type `cin` in and `cout` out. -/
def mmaDecl (name : String) (t : Ty) (a b : Nat) (cin cout : Ty) (c c' : Nat) : Option Intrinsic :=
  Intrinsic.ofDecl name (.struct (List.replicate c' cout))
    (List.replicate a t ++ List.replicate b t ++ List.replicate c cin)

-- read: f16 inputs, f32 accumulators; `ldmatrix` `x4`
#guard mmaDecl "llvm.nvvm.mma.m16n8k16.row.col.f32.f32" h2 4 2 (.fp .float) (.fp .float) 4 4 ==
  some (.mma ⟨16, 8, 16, .f16, .float⟩)
#guard mmaDecl "llvm.nvvm.mma.m16n8k8.row.col.tf32" (.int 32) 4 2 (.fp .float) (.fp .float) 4 4 ==
  some (.mma ⟨16, 8, 8, .tf32, .float⟩)
#guard Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3"
  (.struct (List.replicate 4 (.int 32))) [.ptr 3] == some (.ldmatrix false)
#guard Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.trans.b16.p3"
  (.struct (List.replicate 4 (.int 32))) [.ptr 3] == some (.ldmatrix true)

#guard mmaDecl "llvm.nvvm.mma.m16n8k8.row.col.bf16" (.int 32) 2 1 (.fp .float) (.fp .float) 4 4 ==
  some (.mma ⟨16, 8, 8, .bf16, .float⟩)
-- refused: shapes `Mma.table` does not list, `m16n8k24` with bf16 and `m16n8k32` with f16 inputs
#guard (mmaDecl "llvm.nvvm.mma.m16n8k24.row.col.bf16" (.int 32) 6 3 (.fp .float) (.fp .float) 4
  4).isNone
#guard (mmaDecl "llvm.nvvm.mma.m16n8k32.row.col.f32.f32" h2 8 4 (.fp .float) (.fp .float) 4
  4).isNone
-- refused: f16 accumulators
#guard (mmaDecl "llvm.nvvm.mma.m16n8k16.row.col.f16.f16" h2 4 2 h2 h2 2 2).isNone
#guard (mmaDecl "llvm.nvvm.mma.m16n8k8.row.col.f16.f16" h2 2 1 h2 h2 2 2).isNone
#guard (mmaDecl "llvm.nvvm.mma.m8n8k4.row.col.f16.f16" h2 2 2 h2 h2 4 4).isNone
-- refused: mixed accumulators (`d.c`: f32 out of f16 in, and f16 out of f32 in)
#guard (mmaDecl "llvm.nvvm.mma.m16n8k16.row.col.f32.f16" h2 4 2 h2 (.fp .float) 2 4).isNone
#guard (mmaDecl "llvm.nvvm.mma.m16n8k16.row.col.f16.f32" h2 4 2 (.fp .float) h2 4 2).isNone
-- refused: `ldmatrix` of one and of two matrices
#guard (Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x1.b16.p3" (.int 32)
  [.ptr 3]).isNone
#guard (Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x1.trans.b16.p3" (.int 32)
  [.ptr 3]).isNone
#guard (Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x2.b16.p3"
  (.struct [.int 32, .int 32]) [.ptr 3]).isNone
#guard (Intrinsic.ofDecl "llvm.nvvm.ldmatrix.sync.aligned.m8n8.x2.trans.b16.p3"
  (.struct [.int 32, .int 32]) [.ptr 3]).isNone

end MojoProofTest.IntrinsicForms
