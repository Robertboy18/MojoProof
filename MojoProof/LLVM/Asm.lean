import MojoProof.LLVM.Syntax

/-!
# Asm: the inline assembly the importer accepts

The multistage GEMM kernels of the corpus (`tests/corpus/mgemm/g_multistage_gemm_*`) issue their
asynchronous copies from global to shared memory as inline assembly, not as an NVVM intrinsic,
in two forms:

    call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n"(i32 %dst,
      ptr addrspace(1) %src, i32 16)
    call void asm sideeffect "cp.async.cg.shared.global [$0], [$1], $2, $3;", "r,l,n,r"(i32 %dst,
      ptr addrspace(1) %src, i32 16, i32 %srcSize)

`AsmCall.ofText?` recognizes the two strings (the template and the constraints exactly as
written, with `sideeffect`), and `AsmCall.checkCall` the call around them: a `void` result, no
fast-math flags, no attribute on an argument, and the operands of the form
(`AsmCall.operandsOk`): the shared destination a 32-bit integer (constraint `r`, a `.u32`
register; the kernels compute it with `ptrtoint` and `trunc` from a pointer of address space 3),
the global source a pointer of address space 1 (`l`, a 64-bit register), the copy size the
integer constant 16 (`n`, an immediate), and in the second form the source size a 32-bit integer
(`r`). `Module.check` (MojoProof/LLVM/Import.lean) accepts these calls and refuses every other
inline assembly, the e4m3 conversions of the float8 kernels included.

Accepting a call does not give it a meaning: the semantics has none for inline assembly (`exec`,
MojoProof/Sem/Thread.lean, refuses the instruction form with an unsupported fault), so a grid in
which a thread reaches such a call faults (`Grid.Faults`, MojoProof/Sem/Spec.lean), no launch
that reaches one is `Kernel.Sound` (its `Grid.Sound` requires `Grid.Safe`), and nothing proved
here says what the copy does. For the same reason no copy is ever in flight in a run without a
fault, which is what lets the semantics run `cp.async.commit.group` and `cp.async.wait.group n`
(`Intrinsic.cpAsyncCommit`, `Intrinsic.cpAsyncWait`) as no-ops.

What the strings mean, from PTX ISA 9.5 §9.7.10.28.3.1 (`cp.async`; the number follows the one
the repository gives the commit and wait groups, §9.7.10.28.3.2-3): an asynchronous copy of
cp-size bytes from the global address to the shared address, where `.cg` caches at the L2 only
and allows a cp-size of 16 only; with a source size, that many bytes are read from the source
and the rest of the destination is filled with zeros. The copies a thread issues complete by
groups: `cp.async.commit.group` closes a group and `cp.async.wait.group n` waits until at most
`n` groups are pending.

This module is executable code with no theorems.
-/

namespace MojoProof.LLVM

/-- An inline-assembly call the importer accepts: an asynchronous copy of 16 bytes from global to
shared memory (PTX ISA 9.5 §9.7.10.28.3.1, `cp.async`). -/
inductive AsmCall where
  /-- `cp.async.cg.shared.global [dst], [src], 16;`: copy 16 bytes of the global `src` to the
  shared `dst`. -/
  | cpAsyncCg
  /-- `cp.async.cg.shared.global [dst], [src], 16, srcSize;`: copy `srcSize` bytes of the global
  `src` to the shared `dst` and fill the rest of its 16 bytes with zeros. -/
  | cpAsyncCgSrc
  deriving Repr, Inhabited, DecidableEq

namespace AsmCall

/-- Every form the importer accepts. -/
def all : List AsmCall := [cpAsyncCg, cpAsyncCgSrc]

/-- The template and the constraint string of form `a`, as LLVM writes them in the call. -/
def text : AsmCall → String × String
  | cpAsyncCg => ("cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n")
  | cpAsyncCgSrc => ("cp.async.cg.shared.global [$0], [$1], $2, $3;", "r,l,n,r")

/-- The form whose template and constraints are `template` and `constraints`, for a call of
inline assembly marked `sideeffect` (`sideEffect`); `none` when no form has them. -/
def ofText? (sideEffect : Bool) (template constraints : String) : Option AsmCall :=
  if sideEffect then all.find? (·.text == (template, constraints)) else none

/-- The operands of form `a`, as written in the messages. -/
def signature : AsmCall → String
  | cpAsyncCg => "(i32, ptr addrspace(1), i32 16)"
  | cpAsyncCgSrc => "(i32, ptr addrspace(1), i32 16, i32)"

/-- The operands `args` are those of form `a` (`signature`): a 32-bit integer, a pointer of
address space 1, the 32-bit constant 16 and, for `cpAsyncCgSrc`, a 32-bit integer. -/
def operandsOk : AsmCall → List TValue → Bool
  | cpAsyncCg, [.mk (.int 32) _, .mk (.ptr 1) _, .mk (.int 32) (.int 16)] => true
  | cpAsyncCgSrc, [.mk (.int 32) _, .mk (.ptr 1) _, .mk (.int 32) (.int 16), .mk (.int 32) _] =>
    true
  | _, _ => false

/-- Check a call `call fm ret asm ...(args)` of form `a`: its result type is `void`, it has no
fast-math flags (`fm`), no argument has attributes, and the arguments are the form's operands
(`operandsOk`). The error says which of these fails. -/
def checkCall (a : AsmCall) (fm : FastMath) (ret : Ty) (args : List (TValue × List Attr)) :
    Except String Unit := do
  unless ret == .void do throw "a result"
  unless fm == {} do throw "fast-math flags"
  unless args.all (·.2.isEmpty) do throw "an argument with attributes"
  unless a.operandsOk (args.map (·.1)) do throw s!"operands other than {a.signature}"

end AsmCall

end MojoProof.LLVM
