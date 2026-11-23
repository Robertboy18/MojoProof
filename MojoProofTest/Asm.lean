import MojoProof.LLVM.Import

/-!
# Tests of the inline assembly the importer accepts (MojoProof/LLVM/Asm.lean)

`AsmCall.ofText?` recognizes the two `cp.async` strings of the multistage GEMM kernels, with
`sideeffect`, and nothing else: not the strings without `sideeffect`, not one form's template with
the other's constraints, not the two e4m3 conversions of the float8 kernels. `AsmCall.checkCall`
accepts the corpus calls and fails, naming the check, on a result, fast-math flags, an argument
attribute and each wrong operand (a size other than the constant 16, a shared destination given as
a pointer, a source in another address space, a missing or an extra operand). `Module.check`, on
modules written here, accepts both forms and refuses a near miss with the check that fails and the
conversions with the message it gives every other inline assembly.
-/

namespace MojoProofTest.Asm

open MojoProof.LLVM

/-! The strings. -/

#guard AsmCall.all.all fun a => AsmCall.ofText? true a.text.1 a.text.2 == some a
#guard AsmCall.ofText? true "cp.async.cg.shared.global [$0], [$1], $2;" "r,l,n" ==
  some .cpAsyncCg
#guard AsmCall.ofText? true "cp.async.cg.shared.global [$0], [$1], $2, $3;" "r,l,n,r" ==
  some .cpAsyncCgSrc
-- Without `sideeffect`, one template with the other's constraints, the conversions.
#guard AsmCall.ofText? false "cp.async.cg.shared.global [$0], [$1], $2;" "r,l,n" == none
#guard AsmCall.ofText? true "cp.async.cg.shared.global [$0], [$1], $2;" "r,l,n,r" == none
#guard AsmCall.ofText? true "cp.async.cg.shared.global [$0], [$1], $2, $3;" "r,l,n" == none
#guard AsmCall.ofText? true "cvt.rn.f16x2.e4m3x2 $0, $1;" "=r,h" == none
#guard AsmCall.ofText? false "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;" "=h,f,f" == none

/-! The call checks. -/

/-- The operand `v` of type `t`, with no attributes. -/
def arg (t : Ty) (v : Value) : TValue × List Attr := (.mk t v, [])

/-- The corpus operands of `cpAsyncCg`: `i32 %0, ptr addrspace(1) %1, i32 16`. -/
def ops3 : List (TValue × List Attr) := [arg (.int 32) (.loc 0), arg (.ptr 1) (.loc 1),
  arg (.int 32) (.int 16)]

/-- The corpus operands of `cpAsyncCgSrc`: those of `cpAsyncCg` and `i32 %2`. -/
def ops4 : List (TValue × List Attr) := ops3 ++ [arg (.int 32) (.loc 2)]

/-- `checkCall` as text: `ok` or its error. -/
def checkText (a : AsmCall) (fm : FastMath) (ret : Ty) (args : List (TValue × List Attr)) :
    String :=
  match a.checkCall fm ret args with
  | .ok () => "ok"
  | .error e => e

/--
info: ok
ok
a result
fast-math flags
an argument with attributes
operands other than (i32, ptr addrspace(1), i32 16)
operands other than (i32, ptr addrspace(1), i32 16)
operands other than (i32, ptr addrspace(1), i32 16)
operands other than (i32, ptr addrspace(1), i32 16)
operands other than (i32, ptr addrspace(1), i32 16, i32)
operands other than (i32, ptr addrspace(1), i32 16, i32)
-/
#guard_msgs in
#eval IO.println ("\n".intercalate [
  checkText .cpAsyncCg {} .void ops3,
  checkText .cpAsyncCgSrc {} .void ops4,
  checkText .cpAsyncCg {} (.int 32) ops3,
  checkText .cpAsyncCg { nnan := true } .void ops3,
  checkText .cpAsyncCg {} .void ((ops3.take 2) ++ [(.mk (.int 32) (.int 16), [.flag "noundef"])]),
  -- a size of 8, a pointer destination, a shared source
  checkText .cpAsyncCg {} .void ((ops3.take 2) ++ [arg (.int 32) (.int 8)]),
  checkText .cpAsyncCg {} .void (arg (.ptr 3) (.loc 0) :: ops3.drop 1),
  checkText .cpAsyncCg {} .void
    (ops3.take 1 ++ [arg (.ptr 3) (.loc 1)] ++ ops3.drop 2),
  -- an extra operand, a missing one
  checkText .cpAsyncCg {} .void ops4,
  checkText .cpAsyncCgSrc {} .void ops3,
  checkText .cpAsyncCgSrc {} .void (ops3 ++ [arg (.int 64) (.loc 2)])])

/-! `Module.check` on modules with one call. -/

/-- A module of one function `@f(i32 %0, ptr addrspace(1) %1, i32 %2)` whose body is the line
`call`, then `ret void`. -/
def withCall (call : String) : String :=
  s!"define void @f(i32 %0, ptr addrspace(1) %1, i32 %2) \{\n  {call}\n  ret void\n}\n"

/-- `parse` and `Module.check` on `text`: `accepted` or the error. -/
def importText (text : String) : String :=
  match parse text.toUTF8 with
  | .error e => s!"parse: {e}"
  | .ok m => match m.check "00" with
    | .ok _ => "accepted"
    | .error e => e

/--
info: accepted
accepted
unsupported inline asm "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n" in '@f': operands other
than (i32, ptr addrspace(1), i32 16)
unsupported inline asm "cp.async.cg.shared.global [$0], [$1], $2, $3;", "r,l,n,r" in '@f': a result
unsupported inline asm "cp.async.cg.shared.global [$0], [$1], $2;", "r,l,n" in '@f'
unsupported inline asm "cvt.rn.f16x2.e4m3x2 $0, $1;", "=r,h" in '@f'
unsupported inline asm "cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;", "=h,f,f" in '@f'
-/
#guard_msgs (whitespace := lax) in
#eval IO.println ("\n".intercalate [
  importText (withCall "call void asm sideeffect \"cp.async.cg.shared.global [$0], [$1], $2;\", \
    \"r,l,n\"(i32 %0, ptr addrspace(1) %1, i32 16)"),
  importText (withCall "call void asm sideeffect \"cp.async.cg.shared.global [$0], [$1], $2, \
    $3;\", \"r,l,n,r\"(i32 %0, ptr addrspace(1) %1, i32 16, i32 %2)"),
  importText (withCall "call void asm sideeffect \"cp.async.cg.shared.global [$0], [$1], $2;\", \
    \"r,l,n\"(i32 %0, ptr addrspace(1) %1, i32 8)"),
  importText (withCall "%4 = call i32 asm sideeffect \"cp.async.cg.shared.global [$0], [$1], $2, \
    $3;\", \"r,l,n,r\"(i32 %0, ptr addrspace(1) %1, i32 16, i32 %2)"),
  importText (withCall "call void asm \"cp.async.cg.shared.global [$0], [$1], $2;\", \
    \"r,l,n\"(i32 %0, ptr addrspace(1) %1, i32 16)"),
  importText (withCall "%4 = call i32 asm \"cvt.rn.f16x2.e4m3x2 $0, $1;\", \"=r,h\"(i16 0)"),
  importText (withCall "%4 = call i16 asm \"cvt.rn.satfinite.e4m3x2.f32 $0, $1, $2;\", \
    \"=h,f,f\"(float 0.000000e+00, float 0.000000e+00)")])

end MojoProofTest.Asm
