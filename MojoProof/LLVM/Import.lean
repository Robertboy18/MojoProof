import MojoProof.LLVM.Parser
import MojoProof.LLVM.Intrinsic
import MojoProof.Util.SHA256
import MojoProof.Sem.Layout

/-!
# Import: parse and check a kernel file

`importFile` reads a kernel file, records its SHA-256, parses it (refusing every construct outside
the subset by name, `MojoProof.LLVM.Parser`) and checks closure: every called function is defined
in the module or is a declaration that `Intrinsic.ofDecl` recognizes as a supported intrinsic, and
no call uses inline assembly; and the data layout is one the semantics implements
(`MojoProof.Sem.Layout.parse`). The result is a `Program`: the module, its digest, its data
layout, the recognized intrinsic of every declaration, and the kernel entry points.

This module is executable code with no theorems.
-/

namespace MojoProof.LLVM

/-- An imported kernel file. -/
structure Program where
  /-- The program from its module, digest, data layout, intrinsics and kernel names. -/
  mk ::
  /-- The parsed module. -/
  module : Module
  /-- SHA-256 of the file's bytes. -/
  sha256 : String
  /-- The module's data layout. -/
  layout : Sem.Layout
  /-- Every declared function with the supported intrinsic it denotes. -/
  intrinsics : List (String × Intrinsic)
  /-- The names of the `ptx_kernel` definitions. -/
  kernels : List String

/-- The callees of a function body. -/
def Func.callees (f : Func) : List Callee :=
  f.blocks.toList.flatMap fun b => b.stmts.toList.filterMap fun s =>
    match s.inst with
    | .call _ _ c _ => some c
    | _ => none

/-- Check closure of a parsed module and build the program. Errors name the offending callee. -/
def Module.check (m : Module) (sha : String) : Except String Program := do
  let layout ← Sem.Layout.parse (m.datalayout.getD "")
  let defs := m.funcs.toList.filter (fun f => !f.blocks.isEmpty) |>.map (·.name)
  let intrinsics ← m.funcs.toList.filter (·.blocks.isEmpty) |>.mapM fun f =>
    match Intrinsic.ofDecl f.name f.ret (f.params.map (·.ty)) with
    | some i => pure (f.name, i)
    | none => throw s!"unsupported intrinsic '@{f.name}' (declared, not defined)"
  for f in m.funcs do
    for c in f.callees do
      match c with
      | .fn n =>
        unless defs.contains n || intrinsics.any (·.1 == n) do
          throw s!"call to undeclared function '@{n}' in '@{f.name}'"
      | .asm _ t k => throw s!"unsupported inline asm \"{t}\", \"{k}\" in '@{f.name}'"
  let kernels := m.funcs.toList.filter (·.cconv == some "ptx_kernel") |>.map (·.name)
  return { module := m, sha256 := sha, layout, intrinsics, kernels }

/-- Import the kernel text `bytes`: digest, parse, check. -/
def importBytes (bytes : ByteArray) : Except String Program := do
  (← parse bytes).check (SHA256.hex bytes)

/-- Import a kernel file. -/
def importFile (path : System.FilePath) : IO (Except String Program) :=
  return importBytes (← IO.FS.readBinFile path)

end MojoProof.LLVM
