import MojoProof.LLVM.Syntax

/-!
# Supported intrinsics

The intrinsic families the subset supports. This table is the single source of truth: the importer
accepts a declared callee only if `Intrinsic.ofDecl` recognizes it, and the semantics gives meaning
to exactly these families. Each family generates its LLVM name (with LLVM's type mangling for
overloaded intrinsics) and its signature from its parameters, so a declaration is recognized only
if both its name and its signature are the ones LLVM defines for that family member.

Families: the PTX special registers `%tid`, `%ntid`, `%ctaid`, `%nctaid` (x, y, z) and `%laneid`;
the block barrier; warp shuffles; integer `smax`/`smin`/`umax`/`umin` and float `maxnum`/`minnum`
on scalars and vectors; `rsqrt.approx.ftz.f`; lifetime markers; `vector.reduce.and`,
`vector.extract`, `stepvector`; grid dependency control; `cp.async` commit and wait; `ldmatrix`
`m8n8.x4`; and the tensor-core `mma` for every shape and input type whose register counts the
PTX rules determine.

This module defines data and executable checks; it proves nothing.
-/

namespace MojoProof.LLVM

/-- A grid dimension. -/
inductive Dim
  /-- The `x` dimension. -/
  | x
  /-- The `y` dimension. -/
  | y
  /-- The `z` dimension. -/
  | z
  deriving DecidableEq, Repr, Inhabited

/-- PTX special registers with a dimension: thread index, block size, block index, grid size. -/
inductive SReg
  /-- `%tid`, the thread's index in its block. -/
  | tid
  /-- `%ntid`, the number of threads of a block. -/
  | ntid
  /-- `%ctaid`, the block's index in the grid. -/
  | ctaid
  /-- `%nctaid`, the number of blocks of the grid. -/
  | nctaid
  deriving DecidableEq, Repr, Inhabited

/-- Warp shuffle modes: the lane each lane reads, from the shuffle's operands `b` (the lane or the
offset, the third argument, mod 32) and `c` (the clamp and the segment mask, the fourth), as
`shflSource` (MojoProof/Sem/Grid.lean) computes it; a lane whose source is out of range reads
itself. -/
inductive Shfl
  /-- `bfly`: lane `i` reads lane `i ^ b` (butterfly). -/
  | bfly
  /-- `idx`: every lane reads lane `b` of its segment. -/
  | idx
  /-- `up`: lane `i` reads lane `i - b`. -/
  | up
  /-- `down`: lane `i` reads lane `i + b`. -/
  | down
  deriving DecidableEq, Repr, Inhabited

/-- Input types of tensor-core `mma`. -/
inductive MmaTy
  /-- `tf32`, TensorFloat-32, held in 32-bit registers. -/
  | tf32
  /-- `bf16`, bfloat16, two to a 32-bit register. -/
  | bf16
  /-- `f16`, IEEE binary16, two to a `<2 x half>` register. -/
  | f16
  /-- `f64`, IEEE binary64. -/
  | f64
  deriving DecidableEq, Repr, Inhabited

/-- A tensor-core `mma` of shape `m × n × k`, row-major A and column-major B, with input type `ab`
and accumulator type `cd`. -/
structure Mma where
  /-- The `mma` of shape `m × n × k` with input type `ab` and accumulator type `cd`. -/
  mk ::
  /-- The number of rows of A and of the accumulator. -/
  m : Nat
  /-- The number of columns of B and of the accumulator. -/
  n : Nat
  /-- The number of columns of A and of rows of B. -/
  k : Nat
  /-- The input type of A and B. -/
  ab : MmaTy
  /-- The accumulator type of C and D. -/
  cd : FloatTy
  deriving DecidableEq, Repr, Inhabited

/-- Element width in bits of an `mma` input type. -/
def MmaTy.bits : MmaTy → Nat
  | .tf32 => 32 | .bf16 => 16 | .f16 => 16 | .f64 => 64

/-- The register type that carries `mma` inputs: 32-bit registers packing 16-bit elements, `double`
for `f64`. -/
def MmaTy.reg : MmaTy → Ty
  | .tf32 | .bf16 => .int 32
  | .f16 => .vec 2 (.fp .half)
  | .f64 => .fp .double

private def MmaTy.regBits (t : MmaTy) : Nat := if t = .f64 then 64 else 32

/-- The type suffix of an `mma` name: the input type, or `d.c` accumulator types for `f16`. -/
private def Mma.suffix (v : Mma) : Option String :=
  match v.ab, v.cd with
  | .tf32, .float => some "tf32"
  | .bf16, .float => some "bf16"
  | .f16, .float => some "f32.f32"
  | .f64, .double => some "f64"
  | _, _ => none

/-- Per-lane register counts of A, B and C (= D) under PTX's warp-wide fragment layout:
an `r × c` fragment of `b`-bit elements in `R`-bit registers is `r c b / (32 R)` registers. -/
def Mma.regs (v : Mma) : Nat × Nat × Nat :=
  let rb := v.ab.regBits
  (v.m * v.k * v.ab.bits / (32 * rb), v.k * v.n * v.ab.bits / (32 * rb), v.m * v.n / 32)

/-- The shape is one whose fragments divide evenly among the 32 lanes. -/
def Mma.ok (v : Mma) : Bool :=
  let rb := v.ab.regBits
  v.suffix.isSome && v.m * v.k * v.ab.bits % (32 * rb) == 0 &&
    v.k * v.n * v.ab.bits % (32 * rb) == 0 && v.m * v.n % 32 == 0 && v.regs.1 > 0 &&
    v.regs.2.1 > 0 && v.regs.2.2 > 0

/-- A letter followed by a decimal number, at the front of `cs`. -/
private def tagged (c : Char) : List Char → Option (Nat × List Char)
  | c' :: cs =>
    if c' = c then
      (String.ofList (cs.takeWhile Char.isDigit)).toNat?.map (·, cs.dropWhile Char.isDigit)
    else none
  | [] => none

/-- Read the name `llvm.nvvm.mma.mMnNkK.row.col.<suffix>` back into an `mma`. -/
def Mma.ofName? (s : String) : Option Mma := do
  let cs := s.toList
  guard (cs.take 14 = "llvm.nvvm.mma.".toList)
  let (m, cs) ← tagged 'm' (cs.drop 14)
  let (n, cs) ← tagged 'n' cs
  let (k, cs) ← tagged 'k' cs
  let (ab, cd) ← match String.ofList cs with
    | ".row.col.tf32" => some (MmaTy.tf32, FloatTy.float)
    | ".row.col.bf16" => some (.bf16, .float)
    | ".row.col.f32.f32" => some (.f16, .float)
    | ".row.col.f64" => some (.f64, .double)
    | _ => none
  return { m, n, k, ab, cd }

/-- The supported intrinsic families. Type parameters are the overloaded types of LLVM's name. -/
inductive Intrinsic
  /-- `llvm.nvvm.read.ptx.sreg.<r>.<d>`, a special register at dimension `d`. -/
  | sreg (r : SReg) (d : Dim)
  /-- `llvm.nvvm.read.ptx.sreg.laneid`, the thread's lane in its warp. -/
  | laneid
  /-- `llvm.nvvm.barrier.cta.sync.aligned.all`, the barrier of the threads of a block. -/
  | barrier
  /-- `llvm.nvvm.shfl.sync.<m>.i32`, a warp shuffle of an `i32`. -/
  | shfl (m : Shfl)
  /-- `llvm.smax`, `llvm.smin`, `llvm.umax`, `llvm.umin` at type `t`: the signed or unsigned
  maximum or minimum. -/
  | minmax (signed max : Bool) (t : Ty)
  /-- `llvm.maxnum` and `llvm.minnum` at type `t`: the floating-point maximum or minimum. -/
  | fminmax (max : Bool) (t : Ty)
  /-- `llvm.nvvm.rsqrt.approx.ftz.f`, PTX's approximate reciprocal square root on binary32. -/
  | rsqrtApprox
  /-- `llvm.lifetime.start.p0` and `llvm.lifetime.end.p0`, the start or end of a stack object's
  lifetime. -/
  | lifetime (start : Bool)
  /-- `llvm.vector.reduce.and` at vector type `t`, the bitwise and of the elements. -/
  | reduceAnd (t : Ty)
  /-- `llvm.vector.extract.<res>.<src>`, a subvector of type `res` of a vector of type `src`. -/
  | extract (res src : Ty)
  /-- `llvm.stepvector` at vector type `t`, the vector `<0, 1, 2, ...>`. -/
  | stepvector (t : Ty)
  /-- `llvm.nvvm.griddepcontrol.wait`: wait for the grids this one depends on. -/
  | griddepWait
  /-- `llvm.nvvm.griddepcontrol.launch.dependents`: let the dependent grids start. -/
  | griddepLaunch
  /-- `llvm.nvvm.cp.async.commit.group`: close the current group of asynchronous copies. -/
  | cpAsyncCommit
  /-- `llvm.nvvm.cp.async.wait.group`: wait for groups of asynchronous copies to complete. -/
  | cpAsyncWait
  /-- `llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4[.trans].b16.p3`, a warp's load of four 8×8
  matrices of 16-bit elements from shared memory, transposed when `trans`. -/
  | ldmatrix (trans : Bool)
  /-- `llvm.nvvm.mma.m<m>n<n>k<k>.row.col.<types>`, a warp's tensor-core multiply-accumulate. -/
  | mma (v : Mma)
  deriving Repr, Inhabited, BEq

namespace Intrinsic

/-- LLVM's mangling of an overloaded type in an intrinsic name (`i64`, `f32`, `v4f32`, `p0`). -/
def mangle : Ty → Option String
  | .int w => some s!"i{w}"
  | .fp .half => some "f16"
  | .fp .bfloat => some "bf16"
  | .fp .float => some "f32"
  | .fp .double => some "f64"
  | .ptr a => some s!"p{a}"
  | .vec n t => (mangle t).map (s!"v{n}" ++ ·)
  | _ => none

private def dimName : Dim → String
  | .x => "x" | .y => "y" | .z => "z"

private def sregName : SReg → String
  | .tid => "tid" | .ntid => "ntid" | .ctaid => "ctaid" | .nctaid => "nctaid"

private def shflName : Shfl → String
  | .bfly => "bfly" | .idx => "idx" | .up => "up" | .down => "down"

/-- LLVM's name of a family member, if its overloaded types can be mangled. -/
def name : Intrinsic → Option String
  | .sreg r d => some s!"llvm.nvvm.read.ptx.sreg.{sregName r}.{dimName d}"
  | .laneid => some "llvm.nvvm.read.ptx.sreg.laneid"
  | .barrier => some "llvm.nvvm.barrier.cta.sync.aligned.all"
  | .shfl m => some s!"llvm.nvvm.shfl.sync.{shflName m}.i32"
  | .minmax s m t =>
    (mangle t).map (s!"llvm.{if s then "s" else "u"}{if m then "max" else "min"}." ++ ·)
  | .fminmax m t => (mangle t).map (s!"llvm.{if m then "maxnum" else "minnum"}." ++ ·)
  | .rsqrtApprox => some "llvm.nvvm.rsqrt.approx.ftz.f"
  | .lifetime s => some s!"llvm.lifetime.{if s then "start" else "end"}.p0"
  | .reduceAnd t => (mangle t).map ("llvm.vector.reduce.and." ++ ·)
  | .extract r s => do return s!"llvm.vector.extract.{← mangle r}.{← mangle s}"
  | .stepvector t => (mangle t).map ("llvm.stepvector." ++ ·)
  | .griddepWait => some "llvm.nvvm.griddepcontrol.wait"
  | .griddepLaunch => some "llvm.nvvm.griddepcontrol.launch.dependents"
  | .cpAsyncCommit => some "llvm.nvvm.cp.async.commit.group"
  | .cpAsyncWait => some "llvm.nvvm.cp.async.wait.group"
  | .ldmatrix t =>
    some s!"llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4.{if t then "trans." else ""}b16.p3"
  | .mma v => v.suffix.map (s!"llvm.nvvm.mma.m{v.m}n{v.n}k{v.k}.row.col." ++ ·)

private def isIntTy : Ty → Bool
  | .int _ | .vec _ (.int _) => true
  | _ => false

private def isFloatTy : Ty → Bool
  | .fp _ | .vec _ (.fp _) => true
  | _ => false

/-- LLVM's signature (return type, parameter types) of a family member, if its type parameters
are admissible (for example `smax` on an integer or integer vector type). -/
def sig : Intrinsic → Option (Ty × List Ty)
  | .sreg _ _ | .laneid => some (.int 32, [])
  | .barrier => some (.void, [.int 32])
  | .shfl _ => some (.int 32, [.int 32, .int 32, .int 32, .int 32])
  | .minmax _ _ t => if isIntTy t then some (t, [t, t]) else none
  | .fminmax _ t => if isFloatTy t then some (t, [t, t]) else none
  | .rsqrtApprox => some (.fp .float, [.fp .float])
  | .lifetime _ => some (.void, [.ptr 0])
  | .reduceAnd t@(.vec _ (.int 1)) => some (.int 1, [t])
  | .reduceAnd _ => none
  | .extract r@(.vec n e) s@(.vec n' e') =>
    if e == e' && 0 < n && n ≤ n' then some (r, [s, .int 64]) else none
  | .extract _ _ => none
  | .stepvector t@(.vec _ (.int _)) => some (t, [])
  | .stepvector _ => none
  | .griddepWait | .griddepLaunch | .cpAsyncCommit => some (.void, [])
  | .cpAsyncWait => some (.void, [.int 32])
  | .ldmatrix _ => some (.struct (List.replicate 4 (.int 32)), [.ptr 3])
  | .mma v =>
    if v.ok then
      let (a, b, c) := v.regs
      let acc := Ty.fp v.cd
      some (.struct (List.replicate c acc),
        List.replicate a v.ab.reg ++ List.replicate b v.ab.reg ++ List.replicate c acc)
    else none

/-- What a family member does, against which the promises of its declaration are checked
(`Func.check`): as the semantics gives it (MojoProof/Sem/Thread.lean, `intrinsic`; Grid.lean,
`Grid.fire`), and for the members it leaves unsupported as the PTX ISA 9.5 describes them
(`ldmatrix` reads shared memory through its pointer, 9.7.16.5.15; `mma` reads registers only,
9.7.16.5.14; `cp.async` groups complete asynchronous copies, 9.7.10.28.3.2-3; `griddepcontrol`
orders the memory of dependent grids, 9.7.15.14). -/
structure Effects where
  /-- The effects from their flags. -/
  mk ::
  /-- No other thread, grid or asynchronous copy takes part: the call completes by itself. -/
  alone : Bool
  /-- It has no effect but its result. -/
  pure : Bool
  /-- It reads through its pointer argument. -/
  argRead : Bool := false
  /-- It writes through its pointer argument. -/
  argWrite : Bool := false
  /-- It reads or writes, or orders the accesses to, memory that is not its argument's. -/
  other : Bool := false
  /-- It is a collective whose participants the semantics matches at one call instruction. -/
  convergent : Bool := false

/-- The effects of each family member. The barrier orders the memory accesses of its block of
threads (PTX ISA 9.5, 9.7.15.1); a shuffle exchanges registers and orders no access; `lifetime`
markers change the liveness and bytes of the block their argument points to. -/
def effects : Intrinsic → Effects
  | .sreg .. | .laneid | .minmax .. | .fminmax .. | .rsqrtApprox | .reduceAnd _ | .extract ..
  | .stepvector _ => { alone := true, pure := true }
  | .lifetime _ => { alone := true, pure := false, argWrite := true }
  | .barrier => { alone := false, pure := false, other := true, convergent := true }
  | .shfl _ => { alone := false, pure := false, convergent := true }
  | .griddepWait | .griddepLaunch | .cpAsyncCommit | .cpAsyncWait =>
    { alone := false, pure := false, other := true }
  | .ldmatrix _ => { alone := false, pure := false, argRead := true }
  | .mma _ => { alone := false, pure := false }

/-- The family members a declaration `ret @name(params)` could be: every fixed member, and the
overloaded members instantiated at the declaration's own types. -/
def candidates (name : String) (ret : Ty) (params : List Ty) : List Intrinsic :=
  let p := params.headD .void
  let bools := [true, false]
  ([SReg.tid, .ntid, .ctaid, .nctaid].flatMap fun r => [Dim.x, .y, .z].map (sreg r)) ++
  [laneid, barrier, rsqrtApprox, griddepWait, griddepLaunch, cpAsyncCommit, cpAsyncWait] ++
  [Shfl.bfly, .idx, .up, .down].map shfl ++
  bools.flatMap (fun s => bools.map fun m => minmax s m ret) ++
  bools.map (fminmax · ret) ++ bools.map lifetime ++ bools.map ldmatrix ++
  [reduceAnd p, extract ret p, stepvector ret] ++
  (Mma.ofName? name).toList.map mma

/-- The supported intrinsic a declaration denotes: the family member whose LLVM name and
signature are exactly the declaration's. -/
def ofDecl (name : String) (ret : Ty) (params : List Ty) : Option Intrinsic :=
  (candidates name ret params).find? fun i => i.name == some name && i.sig == some (ret, params)

end Intrinsic

end MojoProof.LLVM
