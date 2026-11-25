import MojoProofTest.Eval

/-!
# Which constructs the semantics gives a meaning to

The importer reads more than the semantics runs: `MojoProof.Sem.exec`, `MojoProof.Sem.step`,
`MojoProof.Sem.intrinsic` and `MojoProof.Sem.Grid.fire` stop a run with `Fault.unsupported` at
a construct they give no meaning to. This module runs one small kernel per opcode keyword of the
importer and per intrinsic family (`MojoProof.LLVM.Intrinsic`) through the grid evaluator
(`Grid.start`, then `Grid.run`), on one block of one thread with a buffer of 64 bytes, and prints
what the run does:

* `returns`: every thread returned, so the semantics executed each instruction of the kernel's
  straight-line body (the `br` and `switch` kernels branch on constants);
* `undefined behavior: msg` or `unsupported: msg`: the run's fault;
* `not started: msg`: the import or the launch's start failed.

The `#guard_msgs` block pins the table, so a change of the semantics that changes an outcome
fails this module's build. `scripts/roadmap_llvm.py` reads the table from this file: a construct
card is L1 only if its row says `returns`; any other row makes it L0, parsed but not modelled. A
row covers the form its kernel runs (shown in `cases`), not every form of the construct: a
`returns` row is a witness that the semantics runs that form, and other forms may still be
unsupported (an `atomicrmw sub`, or one with another ordering than `seq_cst`).

The check after the table fails the build unless every constructor of `Intrinsic` has a row.
-/

namespace MojoProofTest.Modelled

open MojoProof MojoProof.LLVM MojoProof.Sem

/-- The kernel `@k` of one buffer argument `%0` (64 bytes in space 1) whose entry block is the
instruction lines `body` (each ends in a newline) followed by `ret void`, then the module text
`decls` (declarations, attributes and other functions). -/
def kernel (body : String) (decls : String := "") : String :=
  "define ptx_kernel void @k(ptr addrspace(1) %0) {\n" ++ body ++ "  ret void\n}\n" ++ decls

/-- The kernel calling the intrinsic declared by `decl` with the call line `call`. -/
def calls (call decl : String) : String := kernel ("  " ++ call ++ "\n") (decl ++ "\n")

/-- One binary operation `op` on two `i32` constants. -/
def bin (op : String) : String := kernel s!"  %a = {op} i32 7, 2\n"

/-- One float operation `op` on two `float` constants. -/
def fbin (op : String) : String :=
  kernel s!"  %a = {op} float 1.000000e+00, 2.000000e+00\n"

/-- Each opcode keyword of the importer (`MojoProof.LLVM.Parser`) and each intrinsic family
(`Intrinsic.fam`), with its test kernel. -/
def cases : List (String × String) :=
  (["add", "sub", "mul", "udiv", "sdiv", "urem", "srem", "shl", "lshr", "ashr", "and", "or",
    "xor"].map fun op => (op, bin op)) ++
  (["fadd", "fsub", "fmul", "fdiv", "frem"].map fun op => (op, fbin op)) ++
  [("fneg", kernel "  %a = fneg float 1.000000e+00\n"),
   ("fcmp", kernel "  %a = fcmp olt float 1.000000e+00, 2.000000e+00\n"),
   ("icmp", kernel "  %a = icmp slt i32 1, 2\n"),
   ("trunc", kernel "  %a = trunc i64 7 to i32\n"),
   ("zext", kernel "  %a = zext i32 7 to i64\n"),
   ("sext", kernel "  %a = sext i32 -7 to i64\n"),
   ("fptrunc", kernel "  %a = fptrunc float 1.000000e+00 to bfloat\n"),
   ("fpext", kernel "  %a = fptrunc float 1.000000e+00 to bfloat\n\
      %b = fpext bfloat %a to float\n"),
   ("fptoui", kernel "  %a = fptoui float 2.000000e+00 to i32\n"),
   ("fptosi", kernel "  %a = fptosi float 2.000000e+00 to i32\n"),
   ("uitofp", kernel "  %a = uitofp i64 7 to float\n"),
   ("sitofp", kernel "  %a = sitofp i64 7 to float\n"),
   ("ptrtoint", kernel "  %g = addrspacecast ptr addrspace(1) %0 to ptr\n\
      %a = ptrtoint ptr %g to i64\n"),
   ("inttoptr", kernel "  %a = inttoptr i64 256 to ptr\n"),
   ("bitcast", kernel "  %a = bitcast i32 1065353216 to float\n"),
   ("addrspacecast", kernel "  %g = addrspacecast ptr addrspace(1) %0 to ptr\n\
      %h = addrspacecast ptr %g to ptr addrspace(1)\n"),
   ("select", kernel "  %a = select i1 true, i32 1, i32 2\n"),
   ("alloca", kernel "  %a = alloca { float, float, float }, i64 1, align 4\n"),
   ("store", kernel "  store i32 7, ptr addrspace(1) %0, align 4\n"),
   ("load", kernel "  store i32 7, ptr addrspace(1) %0, align 4\n\
      %a = load i32, ptr addrspace(1) %0, align 4\n"),
   ("getelementptr", kernel "  %a = getelementptr inbounds i32, ptr addrspace(1) %0, i64 1\n"),
   ("atomicrmw", kernel "  store i32 0, ptr addrspace(1) %0, align 4\n\
      %a = atomicrmw add ptr addrspace(1) %0, i32 1 seq_cst, align 4\n"),
   ("insertvalue", kernel "  %a = insertvalue { float, float } zeroinitializer, \
      float 1.000000e+00, 1\n"),
   ("extractvalue", kernel "  %a = extractvalue { i32, i32 } { i32 1, i32 2 }, 1\n"),
   ("insertelement", kernel "  %a = insertelement <4 x float> zeroinitializer, \
      float 1.000000e+00, i64 0\n"),
   ("extractelement", kernel "  %a = extractelement <4 x float> zeroinitializer, i64 1\n"),
   ("shufflevector", kernel "  %a = shufflevector <2 x float> zeroinitializer, \
      <2 x float> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>\n"),
   ("phi", kernel "  br label %2\n\
    2:\n\
      %a = phi i32 [ 0, %1 ]\n"),
   ("call", kernel "  call void @g()\n" "define internal void @g() {\n  ret void\n}\n"),
   ("br", kernel "  %c = icmp eq i32 0, 0\n\
      br i1 %c, label %2, label %3\n\
    2:\n\
      br label %3\n\
    3:\n"),
   ("switch", kernel "  switch i32 1, label %2 [\n    i32 0, label %3\n  ]\n\
    2:\n\
      br label %3\n\
    3:\n"),
   ("ret", kernel ""),
   ("unreachable", "define ptx_kernel void @k(ptr addrspace(1) %0) {\n  unreachable\n}\n"),
   ("Intrinsic.sreg", calls "%a = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()"
      "declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()"),
   ("Intrinsic.laneid", calls "%a = call i32 @llvm.nvvm.read.ptx.sreg.laneid()"
      "declare i32 @llvm.nvvm.read.ptx.sreg.laneid()"),
   ("Intrinsic.barrier", calls "call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)"
      "declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0\n\
      attributes #0 = { convergent }"),
   ("Intrinsic.shfl", calls
      "%a = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 0, i32 1, i32 31)"
      "declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #0\n\
      attributes #0 = { convergent }"),
   ("Intrinsic.minmax", calls "%a = call i64 @llvm.smax.i64(i64 1, i64 2)"
      "declare i64 @llvm.smax.i64(i64, i64)"),
   ("Intrinsic.fminmax", calls
      "%a = call float @llvm.maxnum.f32(float 1.000000e+00, float 2.000000e+00)"
      "declare float @llvm.maxnum.f32(float, float)"),
   ("Intrinsic.rsqrtApprox", calls
      "%a = call float @llvm.nvvm.rsqrt.approx.ftz.f(float 4.000000e+00)"
      "declare float @llvm.nvvm.rsqrt.approx.ftz.f(float)"),
   ("Intrinsic.lifetime", kernel "  %p = alloca i32, align 4\n\
      call void @llvm.lifetime.start.p0(ptr %p)\n\
      call void @llvm.lifetime.end.p0(ptr %p)\n"
      "declare void @llvm.lifetime.start.p0(ptr captures(none))\n\
      declare void @llvm.lifetime.end.p0(ptr captures(none))\n"),
   ("Intrinsic.reduceAnd", calls
      "%a = call i1 @llvm.vector.reduce.and.v2i1(<2 x i1> <i1 true, i1 false>)"
      "declare i1 @llvm.vector.reduce.and.v2i1(<2 x i1>)"),
   ("Intrinsic.extract", calls "%a = call <2 x i32> @llvm.vector.extract.v2i32.v4i32(\
      <4 x i32> <i32 1, i32 2, i32 3, i32 4>, i64 2)"
      "declare <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32>, i64 immarg)"),
   ("Intrinsic.stepvector", calls "%a = call <2 x i64> @llvm.stepvector.v2i64()"
      "declare <2 x i64> @llvm.stepvector.v2i64()"),
   ("Intrinsic.griddepWait", calls "call void @llvm.nvvm.griddepcontrol.wait()"
      "declare void @llvm.nvvm.griddepcontrol.wait()"),
   ("Intrinsic.griddepLaunch", calls "call void @llvm.nvvm.griddepcontrol.launch.dependents()"
      "declare void @llvm.nvvm.griddepcontrol.launch.dependents()"),
   ("Intrinsic.cpAsyncCommit", calls "call void @llvm.nvvm.cp.async.commit.group()"
      "declare void @llvm.nvvm.cp.async.commit.group()"),
   ("Intrinsic.cpAsyncWait", calls "call void @llvm.nvvm.cp.async.wait.group(i32 0)"
      "declare void @llvm.nvvm.cp.async.wait.group(i32 immarg)"),
   ("Intrinsic.ldmatrix", kernel
      "  %a = call { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(\
      ptr addrspace(3) @s)\n"
      "@s = internal addrspace(3) global [64 x i8] undef, align 16\n\
      declare { i32, i32, i32, i32 } @llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.b16.p3(\
      ptr addrspace(3) readonly captures(none)) #0\n\
      attributes #0 = { convergent nocallback nounwind memory(argmem: read) }\n"),
   ("Intrinsic.mma", calls "%a = call { float, float, float, float } \
      @llvm.nvvm.mma.m16n8k16.row.col.bf16(i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, \
      float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00)"
      "declare { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.bf16(i32, i32, \
      i32, i32, i32, i32, float, float, float, float) #0\n\
      attributes #0 = { nocallback nounwind memory(none) }")]

/-- What the grid evaluator does with kernel text `src` on one block of one thread with the
buffer as its argument (`startText`), at most 10 phases of 1000 steps per thread. -/
def outcome (src : String) : String :=
  match startText src 1 fun b => [b] with
  | .error e => s!"not started: {e}"
  | .ok (_, L, _, g, ctx) =>
    match g.run L ctx 1000 10 with
    | .ok _ => "returns"
    | .error (.ub m) => s!"undefined behavior: {m}"
    | .error (.unsupported m) => s!"unsupported: {m}"

/--
info: add: returns
sub: returns
mul: returns
udiv: returns
sdiv: returns
urem: returns
srem: returns
shl: returns
lshr: returns
ashr: returns
and: returns
or: returns
xor: returns
fadd: returns
fsub: returns
fmul: returns
fdiv: returns
frem: unsupported: frem
fneg: returns
fcmp: returns
icmp: returns
trunc: returns
zext: returns
sext: returns
fptrunc: returns
fpext: returns
fptoui: unsupported: cast (fptoui, fptosi, inttoptr, or ill-typed)
fptosi: unsupported: cast (fptoui, fptosi, inttoptr, or ill-typed)
uitofp: returns
sitofp: returns
ptrtoint: returns
inttoptr: unsupported: cast (fptoui, fptosi, inttoptr, or ill-typed)
bitcast: returns
addrspacecast: returns
select: returns
alloca: returns
store: returns
load: returns
getelementptr: returns
atomicrmw: returns
insertvalue: returns
extractvalue: returns
insertelement: returns
extractelement: returns
shufflevector: returns
phi: returns
call: returns
br: returns
switch: returns
ret: returns
unreachable: undefined behavior: unreachable
Intrinsic.sreg: returns
Intrinsic.laneid: returns
Intrinsic.barrier: returns
Intrinsic.shfl: returns
Intrinsic.minmax: returns
Intrinsic.fminmax: returns
Intrinsic.rsqrtApprox: returns
Intrinsic.lifetime: returns
Intrinsic.reduceAnd: returns
Intrinsic.extract: returns
Intrinsic.stepvector: returns
Intrinsic.griddepWait: returns
Intrinsic.griddepLaunch: returns
Intrinsic.cpAsyncCommit: returns
Intrinsic.cpAsyncWait: returns
Intrinsic.ldmatrix: unsupported: ldmatrix in a grid
Intrinsic.mma: unsupported: mma in a warp cut by its block of threads
-/
#guard_msgs in
#eval do
  for (k, src) in cases do IO.println s!"{k}: {outcome src}"

-- every constructor of `Intrinsic` has a row
run_meta do
  let .inductInfo i ← Lean.getConstInfo ``Intrinsic | Lean.throwError "Intrinsic: no inductive"
  for c in i.ctors do
    unless cases.any (·.1 == s!"Intrinsic.{c.getString!}") do
      Lean.throwError "no row for {c}"

end MojoProofTest.Modelled
