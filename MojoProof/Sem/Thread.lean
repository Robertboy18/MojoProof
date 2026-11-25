import MojoProof.Sem.Eval
import MojoProof.LLVM.Import
import Mathlib.Data.Nat.Pairing

/-!
# One thread

The small-step semantics of one thread of a kernel: `step` runs one instruction or terminator of
the innermost call frame on a memory. LLVM's nondeterminism is split in two, each a function
`Nat → Nat` in the context that step `k` of a thread
reads at `Nat.pair k i`, so every choice of every step is free. Skeleton choices (`Ctx.addr`) are
the addresses of an `alloca`'s block. Payload choices (`Ctx.oracle`) are the float freedoms (NaN
results, contraction, `maxnum`, `rsqrt.approx`) and are read by float operations only.
Statements about all executions quantify over both.

* Registers hold values; an `fmul contract` result also records its operands, which a later
  `fadd contract` / `fsub contract` may fuse (`MojoProof.Sem.contract`). Nothing is fused through
  `phi`, memory or a conversion.
* On entry to a block its `phi`s are evaluated together, for the edge taken (LangRef, "phi").
* `alloca` allocates a block in the layout's alloca space, owned by the thread, numbered from the
  thread and its step count (`Mem.fresh`), so that the numbers do not depend on the schedule; a
  number in use is unsupported (no step removes a block, so that fault persists). It
  starts dead if the function calls `llvm.lifetime.start` on it, live otherwise (LangRef,
  "llvm.lifetime.start"); a frame's blocks die when it returns. `lifetime.start` makes its block
  live with undefined bytes, `lifetime.end` dead; on poison both do nothing, and on a block the
  thread does not own they are unsupported.
* Calls to defined functions push a frame; `byval` arguments of such calls are unsupported. A
  `noundef` parameter (of the callee or at the call) or return value that is poison or `undef`
  is undefined behavior, and so is such a value from a load with `!noundef` (LangRef, "load").
  An argument or result outside its `range` attribute is poison (element by element in a
  vector), and so is a pointer whose address is zero with `nonnull` or misaligned with `align`
  (`withAttrs`). A call of a `norecurse` function already on the thread's stack is undefined
  behavior. The attributes of the callee, defined or an intrinsic declaration, are checked at
  each call (`Func.check`): those the semantics does not check are unsupported (`willreturn`,
  `nosync`, `nofree` and `memory(...)` on a defined function; promises such as `writeonly` or
  `dereferenceable` anywhere), and so is a promise of an intrinsic declaration that the
  member's effects (`Intrinsic.effects`) break, such as `nosync` or `memory(none)` on the
  barrier; a collective declared without `convergent` is unsupported, and an `immarg` argument
  must be a constant. An intrinsic declared `nocreateundeforpoison` whose own result (without
  the call's `nnan` and `ninf`, which may still make it poison) is not defined while its
  arguments are is undefined behavior (LangRef).
  A load records `!invariant.load` in the trace, whose promise is an obligation
  (MojoProof/Sem/Spec.lean, `Grid.Kept`); other metadata than it and `!noundef` on a load, and
  any metadata on another instruction (a `phi` included), is unsupported (`Stmt.checkMd`).
  Call-site attributes other than `noundef` are unsupported, and so are fast-math flags on a
  call except `nnan` / `ninf` on `maxnum`, `minnum` and `rsqrt.approx`.
* Intrinsics: the special registers read the thread's `Env`; `smax`/`smin`/`umax`/`umin`,
  `maxnum`/`minnum` (`MojoProof.Sem.maxnum`), `vector.reduce.and`, `vector.extract` and
  `stepvector` lane by lane; `rsqrt.approx.ftz.f` returns a word that meets PTX's contract
  (`MojoProof.Sem.rsqrt`, TRUST T10); grid dependency control and `cp.async` commit and wait do
  nothing (the subset has no asynchronous copies). The barrier, warp shuffles, `ldmatrix` and
  `mma` involve other threads: the thread stops at them (`Step.wait`) for the grid layer.
* `atomicrmw` must be `seq_cst` at system scope (no `syncscope`), of an integer type whose width
  is a power of two of at least 8, with a commutative and associative operation (`add`, `and`,
  `or`, `xor`, `max`, `min`, `umax`, `umin`), and its result must be unused
  (`Stmt.checkAtomic`; float atomics, `xchg`, `nand` and used results depend on the order of the
  atomics, and `sub` is not among the admitted operations: unsupported). Its operand must be a
  scalar of its type (`Val.Scalar`: bits of its width, poison or undef; LLVM's verifier rejects
  another, and `rmw` would fault on it or not depending on the old value). It reads, combines and
  writes in one step, and leaves its result register unset (the old value depends on the order,
  and nothing reads it). Steps interleave over one memory: sequential consistency, which LLVM
  gives data-race-free runs only (TRUST T13). Loads, stores and `atomicrmw` record their
  accesses in the memory's trace (an `atomicrmw` as a read and a write, both marked with its
  operation).
* Branching on poison and `unreachable` are undefined behavior.

This module defines functions; the one theorem it proves is a general fact about `Except`:
a bind succeeds exactly when its first part succeeds and the rest succeeds on its value
(`Except.bind_eq_ok`, for all types and computations).
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- The special registers of one thread: `%tid`, `%ntid`, `%ctaid`, `%nctaid` by dimension, and
`%laneid`. -/
structure Env where
  /-- Builds an `Env` from the special registers and the lane number. -/
  mk ::
  /-- `%tid`, `%ntid`, `%ctaid` and `%nctaid`, by dimension. -/
  sreg : SReg → Dim → Nat
  /-- `%laneid`. -/
  laneid : Nat

/-- What a thread runs in: the program, the addresses of the globals, the thread's special
registers, the thread as memory accesses name it, its skeleton choices `addr` (an `alloca` at
step `k` reads its two addresses at `Nat.pair k 0` and `Nat.pair k 1`) and its payload choices
`oracle` (read by float operations only). -/
structure Ctx where
  /-- Builds a context from its six fields. -/
  mk ::
  /-- The program. -/
  prog : Program
  /-- The pointer of each global, by name. -/
  globals : String → Option Ptr
  /-- The thread's special registers. -/
  env : Env
  /-- The thread as its memory accesses name it. -/
  who : Who
  /-- The skeleton choices, which an `alloca` reads for its block's addresses. -/
  addr : Nat → Nat
  /-- The payload choices, read by float operations only. -/
  oracle : Nat → Nat

/-- A call frame: the function, the current block and the position in it, the registers, the
operands of `fmul contract` results, the blocks its `alloca`s made, and the caller's register
for the result. -/
structure Frame where
  /-- Builds a frame from its seven fields. -/
  mk ::
  /-- The function. -/
  fn : Func
  /-- The current block's label. -/
  label : Nat
  /-- The position in the current block. -/
  pc : Nat
  /-- The registers. -/
  regs : Nat → Option Val
  /-- The operands of each `fmul contract` result, by register. -/
  prods : Nat → Option (Val × Val)
  /-- The blocks the frame's `alloca`s made. -/
  allocas : List Nat
  /-- The caller's register for the result, if any. -/
  dest : Option Nat

/-- A thread: its call stack (innermost first) and the number of steps it has taken. -/
structure Thread where
  /-- Builds a thread from its call stack and step count. -/
  mk ::
  /-- The call stack, innermost first. -/
  frames : List Frame
  /-- The number of steps the thread has taken. -/
  k : Nat

/-- The result of a step. -/
inductive Step
  /-- One instruction or terminator ran. -/
  | next (t : Thread) (m : Mem)
  /-- The thread is at a call of intrinsic `i`, which involves other threads, with arguments
  `args`, declared by `fn`; the grid layer completes it. -/
  | wait (i : Intrinsic) (args : List Val) (fn : Func)
  /-- The kernel returned. -/
  | done (m : Mem)

/-- What an instruction does to its frame. -/
inductive Eff
  /-- Continue with this frame and memory. -/
  | next (f : Frame) (m : Mem)
  /-- Call the defined function `g` with arguments `args`. -/
  | call (g : Func) (args : List Val)
  /-- Stop at the collective intrinsic `i`, declared by `fn`. -/
  | wait (i : Intrinsic) (args : List Val) (fn : Func)

/-- Register `r` (if any) set to `v` (if any), with `fmul contract` operands `prod`. -/
def Frame.set (f : Frame) (r : Option Nat) (v : Option Val) (prod : Option (Val × Val)) :
    Frame :=
  match r, v with
  | some r, some v =>
    { f with regs := fun s => if s = r then some v else f.regs s,
             prods := fun s => if s = r then prod else f.prods s }
  | _, _ => f

/-- Block `b` made live with undefined bytes, or dead (if it exists). -/
def Mem.setLive (m : Mem) (b : Nat) (live : Bool) : Mem :=
  match m.blocks b with
  | some blk => m.set b { blk with live, bytes := if live then fun _ => .undef else blk.bytes }
  | none => m

/-- A value `v` of type `t` under the attributes `attrs` of its parameter (with those at the
call) or return value, in memory `m` (LangRef, "Parameter Attributes"): an integer outside a
`range` is poison (element by element in a vector), and so is a pointer whose address in its space
is zero with `nonnull` or not a multiple of `n` with `align n` (element by element in a vector
of pointers); a value that is not `defined` with `noundef` is undefined behavior. A `range` of
another width or on a non-integer, an empty `range` other than `0, 0`, and `nonnull` or `align`
on a non-pointer are unsupported (the LLVM verifier refuses them). -/
def withAttrs (l : Layout) (m : Mem) (t : Ty) (attrs : List Attr) (v : Val) :
    Except Fault Val := do
  let lane (t : Ty) (v : Val) : Except Fault Val := attrs.foldlM (init := v) fun v a =>
    match a, t, v with
    | _, _, .poison | _, _, .undef => pure v
    | .range (.int w) lo hi, _, .bits w' b =>
      if w ≠ w' then throw (.unsupported "range attribute of another width")
      else if lo = hi ∧ lo ≠ 0 then throw (.unsupported "empty range other than 0, 0")
      else pure (if (b.toNat - lo) % (2 ^ w : Int) < (hi - lo) % (2 ^ w : Int) then v else .poison)
    | .range .., _, _ => throw (.unsupported "range attribute on a non-integer")
    | .flag "nonnull", .ptr s, .ptr p => do pure (if (← m.addr l s p) = 0 then .poison else v)
    | .int "align" n, .ptr s, .ptr p => do pure (if (← m.addr l s p) % n = 0 then v else .poison)
    | .flag "nonnull", _, _ | .int "align" _, _, _ =>
      throw (.unsupported "nonnull or align on a non-pointer")
    | _, _, _ => pure v
  let v ← match t, v with
    | .vec _ te, .vec xs => .vec <$> xs.mapM (lane te)
    | t, v => lane t v
  if attrs.contains (.flag "noundef") && !v.defined then throw (.ub "noundef value not defined")
  return v

/-- The function attributes of `fn`: those of its attribute group in module `md`. -/
def _root_.MojoProof.LLVM.Func.attrs (md : Module) (fn : Func) : List Attr :=
  ((md.attrGroups.find? (some ·.1 == fn.group)).map (·.2)).getD []

/-- The name of an attribute. -/
def _root_.MojoProof.LLVM.Attr.name : Attr → String
  | .flag n | .int n _ | .ty n _ | .args n _ | .str n _ => n
  | .range .. => "range"

/-- The access, as (reads, writes), that LangRef's `memory(xs)` allows to the location kind
`loc` (`argmem`, `inaccessiblemem`, `errnomem`, `target_mem0`, `target_mem1`; `none` for the
others): that of the item naming `loc`, else that of the default item, else no access
(LangRef, "Function Attributes", `memory(...)`). Another location kind or access kind, in any
item (also in one that does not name `loc`), is unsupported. -/
def memAccess (xs : List (List String)) (loc : Option String) : Except Fault (Bool × Bool) := do
  let kind : String → Except Fault (Bool × Bool)
    | "none" => pure (false, false) | "read" => pure (true, false)
    | "write" => pure (false, true) | "readwrite" => pure (true, true)
    | k => throw (.unsupported s!"memory access kind {k}")
  let locs := ["argmem", "inaccessiblemem", "errnomem", "target_mem0", "target_mem1"]
  let mut named := none
  let mut dflt := (false, false)
  for x in xs do
    match x with
    | [k] => dflt ← kind k
    | [l, k] =>
      unless locs.contains l do throw (.unsupported s!"memory location kind {l}")
      let a ← kind k
      if some l = loc then named := some a
    | _ => throw (.unsupported "memory attribute item")
  return named.getD dflt

/-- The attributes of function `fn` of module `md` are ones the semantics gives a meaning to;
`i` is the intrinsic a declaration denotes. Parameter and return attributes `noundef`,
`nonnull`, `range` and `align` (`withAttrs`) on every function. A defined function may have the
function attributes `norecurse` (checked at calls), `convergent`, `noinline`, `nounwind` and
string attributes, and `byval` parameters, with `readonly`, `noundef` and `nonnull` only.
An intrinsic declaration may make the promises its member keeps (`Intrinsic.effects`; LangRef,
"Function Attributes", "Parameter Attributes"): `nounwind`, `nocallback`, `nofree` and strings
always (no intrinsic here raises, calls back into the module or frees memory); `nosync`,
`willreturn` and `nocreateundeforpoison` (checked at calls) only if it completes alone;
`speculatable` only if it has no effect but its result; `memory(...)` only if it allows the
member's accesses (all memory, read and written, for one that orders other memory); the
parameter attributes `captures(none)` (no intrinsic here keeps a pointer), `readonly` unless it
writes through its argument, and `immarg` (a constant argument, checked at calls). A collective
the grid layer matches at one instruction (the barrier, `shfl.sync`) must be `convergent`.
Every other attribute (`willreturn` on a defined function, `writeonly`, `dereferenceable(n)`,
`noreturn`, ...) is a promise the semantics does not check: unsupported. -/
def _root_.MojoProof.LLVM.Func.check (md : Module) (fn : Func) (i : Option Intrinsic := none) :
    Except Fault Unit := do
  let decl := fn.blocks.isEmpty
  let e := i.map Intrinsic.effects
  let broken (a : Attr) : Fault := .unsupported s!"function attribute {a.name} on @{fn.name}, \
    a promise its semantics does not keep"
  if decl && e.isNone then throw (.unsupported s!"declaration @{fn.name} of no intrinsic")
  for a in fn.attrs md do
    match e, a with
    | _, .flag "convergent" | _, .flag "nounwind" | _, .str .. => pure ()
    | none, .flag "norecurse" | none, .flag "noinline" => pure ()
    | some _, .flag "nocallback" | some _, .flag "nofree" => pure ()
    | some e, .flag "nosync" | some e, .flag "willreturn" | some e, .flag "nocreateundeforpoison" =>
      unless e.alone do throw (broken a)
    | some e, .flag "speculatable" => unless e.pure do throw (broken a)
    | some e, .args "memory" xs =>
      let (r, w) ← memAccess xs (some "argmem")
      unless (!e.argRead || r) && (!e.argWrite || w) do throw (broken a)
      if e.other then
        for loc in [none, some "argmem", some "inaccessiblemem", some "errnomem",
            some "target_mem0", some "target_mem1"] do
          unless (← memAccess xs loc) == (true, true) do throw (broken a)
    | _, _ => throw (.unsupported s!"function attribute {a.name}")
  if e.any (·.convergent) && !(fn.attrs md).contains (.flag "convergent") then
    throw (.unsupported s!"collective @{fn.name} declared without convergent")
  let value (a : Attr) : Bool := a matches .flag "noundef" | .flag "nonnull" | .range ..
    | .int "align" _
  for a in fn.retAttrs do
    unless value a do throw (.unsupported s!"return attribute {a.name}")
  for p in fn.params do
    let byval := p.attrs.any (· matches .ty "byval" _)
    for a in p.attrs do
      unless (if byval then a matches .ty "byval" _ | .flag "readonly" | .flag "noundef"
            | .flag "nonnull"
          else value a || decl && (a matches .args "captures" [["none"]] | .flag "immarg" ||
            a matches .flag "readonly" && !e.any (·.argWrite))) do
        throw (.unsupported s!"parameter attribute {a.name}")

/-- `smax`, `smin`, `umax` or `umin` of two integer scalars. -/
def intMinMax (signed max : Bool) : Val → Val → Except Fault Val :=
  strict2 fun
    | .bits w a, .bits w' b =>
      if h : w' = w then
        let b := b.cast h
        pure (.bits w (if (if signed then a.slt b else a.ult b) == max then b else a))
      else throw (.unsupported "min/max operands of different widths")
    | _, _ => throw (.unsupported "min/max of non-integers")

/-- The bit of an `i1` scalar. -/
def Val.bit? : Val → Option Bool
  | .bits _ b => some (b.getLsbD 0)
  | _ => none

/-- The effect of intrinsic `i` (not a collective one) on arguments `args` with call flags `fm`
(`nnan` / `ninf` on `maxnum`, `minnum` and `rsqrt.approx` as `withFlags` says; `exec` refuses
other flags): the result and the memory; `none` for a collective intrinsic. -/
def intrinsic (c : Ctx) (s : Scope) (fm : FastMath) (i : Intrinsic) (args : List Val) :
    Except Fault (Option (Option Val × Mem)) :=
  let m := s.mem
  let ret (v : Val) : Except Fault (Option (Option Val × Mem)) := pure (some (some v, m))
  let word (n : Nat) : Val := .bits 32 (BitVec.ofNat 32 n)
  match i, args with
  | .sreg r d, [] => ret (word (c.env.sreg r d))
  | .laneid, [] => ret (word c.env.laneid)
  | .minmax signed max _, [x, y] => do ret (← lanes2 (fun _ => intMinMax signed max) x y)
  | .fminmax max t, [x, y] => match t.elt with
    | .fp ft => do
      ret (← lanes2 (fun j => floats2 ft fun a b =>
        match withFlags fm [a, b] (maxnum max a b (s.ch j)) with
        | some r => .ofFloat ft r
        | none => .poison) x y)
    | _ => throw (.unsupported "maxnum of non-floats")
  | .rsqrtApprox, [x] => match x with
    | .poison => ret .poison
    | .undef => throw (.unsupported "use of undef")
    | x => match x.float? .float with
      | some a => ret ((withFlags fm [a] (rsqrt a (s.ch 0))).elim .poison (.ofFloat .float))
      | none => throw (.unsupported "rsqrt.approx of a non-float")
  | .lifetime start, [x] => match x with
    | .ptr p =>
      if (m.block p).any fun b : Block => b.owner == .thread c.who.thread then
        pure (some (none, m.setLive p.block start))
      else throw (.unsupported "lifetime marker on memory the thread does not own")
    | .poison => pure (some (none, m))
    | _ => throw (.unsupported "lifetime marker on a non-pointer")
  | .reduceAnd _, [.vec xs] => match xs.mapM Val.bit? with
    | some bs => ret (.ofBool (bs.all id))
    | none => if xs.any (· matches .undef) then throw (.unsupported "use of undef") else ret .poison
  | .extract r _, [.vec xs, .bits _ k] => match r with
    | .vec n _ =>
      ret (if k.toNat + n ≤ xs.length then .vec ((xs.drop k.toNat).take n) else fill .poison r)
    | _ => throw (.unsupported "vector.extract of a non-vector type")
  | .stepvector t, [] => match t with
    | .vec n (.int w) => ret (.vec ((List.range n).map fun j => .bits w (BitVec.ofNat w j)))
    | _ => throw (.unsupported "stepvector of a non-integer-vector type")
  | .griddepWait, [] | .griddepLaunch, [] | .cpAsyncCommit, [] | .cpAsyncWait, [_] =>
    pure (some (none, m))
  | .barrier, _ | .shfl _, _ | .ldmatrix _, _ | .mma _, _ => pure none
  | _, _ => throw (.unsupported "intrinsic call with ill-typed arguments")

/-- Intrinsic `i` on `args` gives a result that is not defined before any call-site fast-math
flag applies: the result LangRef's `nocreateundeforpoison` speaks of, "prior to application of
return attributes/metadata" (a call's `nnan` or `ninf` may still make the call's result
poison). -/
def ownUndef (c : Ctx) (s : Scope) (i : Intrinsic) (args : List Val) : Bool :=
  match intrinsic c s {} i args with
  | .ok (some (some v, _)) => !v.defined
  | _ => false

/-- The operations `Stmt.checkAtomic` admits (`add`, `and`, `or`, `xor`, `max`, `min`, `umax`,
`umin`): two updates by one of them commute (`rmw_comm`, MojoProof/Sem/Rmw.lean). -/
def _root_.MojoProof.LLVM.RmwOp.commutes : RmwOp → Bool
  | .add | .and | .or | .xor | .max | .min | .umax | .umin => true
  | _ => false

/-- A scalar of width `w`: bits of width `w`, poison or undef. -/
def Val.Scalar (w : Nat) (v : Val) : Prop := (∃ a, v = .bits w a) ∨ v = .poison ∨ v = .undef

/-- Whether a value is a scalar of width `w`, which `exec` checks of an `atomicrmw`'s operand. -/
instance (w : Nat) : DecidablePred (Val.Scalar w)
  | .bits w' a => if h : w' = w then isTrue (.inl ⟨h ▸ a, by subst h; rfl⟩)
    else isFalse (by simp [Val.Scalar, h])
  | .poison => isTrue (.inr (.inl rfl))
  | .undef => isTrue (.inr (.inr rfl))
  | .ptr _ | .vec _ | .agg _ => isFalse (by simp [Val.Scalar])

/-- `atomicrmw op` of the old value and the operand, integers of width `w`, for the operations
`Stmt.checkAtomic` admits. -/
def rmw (w : Nat) : RmwOp → Val → Val → Except Fault Val
  | .add => intBin w .add {}
  | .and => intBin w .and {}
  | .or => intBin w .or {}
  | .xor => intBin w .xor {}
  | .max => intMinMax true true
  | .min => intMinMax true false
  | .umax => intMinMax false true
  | .umin => intMinMax false false
  | _ => fun _ _ => throw (.unsupported "atomicrmw operation that Stmt.checkAtomic refuses")

/-- The pointer a memory access goes through: poison is undefined behavior. -/
def Val.addr? : Val → Except Fault Ptr
  | .ptr p => pure p
  | .poison => throw (.ub "memory access through poison")
  | .undef => throw (.unsupported "use of undef")
  | _ => throw (.unsupported "memory access through a non-pointer")

/-- The function calls `llvm.lifetime.start` on register `r`. -/
def lifetimeStarted (c : Ctx) (fn : Func) (r : Nat) : Bool :=
  fn.blocks.any fun b => b.stmts.any fun st => match st.inst with
    | .call _ _ (.fn g) [(.mk _ (.loc r'), _)] =>
      r' == r && (c.prog.intrinsics.lookup g matches some (.lifetime true))
    | _ => false

/-- The metadata attachments of `st` are ones the semantics gives a meaning to: `!invariant.load`
and `!noundef` on a load (`exec`). Any other attachment, and any on another instruction (such as
`!noundef`, `!range` or `!nonnull` on a `phi`, LangRef "phi"), is unsupported. -/
def _root_.MojoProof.LLVM.Stmt.checkMd (st : Stmt) : Except Fault Unit := do
  for (k, _) in st.md do
    unless st.inst matches .load .. && (k == "invariant.load" || k == "noundef") do
      throw (.unsupported s!"metadata !{k}")

/-- The `atomicrmw`s the semantics admits: of an integer type
whose width is a power of two of at least 8 (LangRef, `atomicrmw`, Arguments; so the number of bytes
determines the type), with a commutative and associative operation (`add`, `and`, `or`, `xor`,
`max`, `min`, `umax`, `umin`), and with a result that function `fn` does not use. Two such updates
of one location by the same operation and size give the same memory in either order (`rmw_comm` for
the values, MojoProof/Sem/Rmw.lean; `Access.conflict` exempts two updates of the same bytes by one
operation exactly when `RmwOp.commutes` holds of it).
Unsupported: float operations (`fadd`, `fsub`, `fmax`, `fmin`; rounding makes the result depend on
the order), `xchg` and `nand` (two updates do not commute), `sub`, and a used result (the old value
depends on the order). `sub` commutes too (`(v - x) - y = (v - y) - x`) but is not among the
admitted operations (`RmwOp.commutes`). Other statements pass. -/
def _root_.MojoProof.LLVM.Stmt.checkAtomic (fn : Func) (st : Stmt) : Except Fault Unit := do
  let .atomicrmw _ op _ (.mk t _) _ _ _ := st.inst | pure ()
  if op matches .fadd | .fsub | .fmax | .fmin then
    throw (.unsupported "float atomicrmw (rounding makes it depend on the order)")
  if op matches .sub then
    throw (.unsupported "atomicrmw sub (not in the admitted operations)")
  unless op.commutes do
    throw (.unsupported "atomicrmw xchg or nand (two updates do not commute)")
  let .int w := t | throw (.unsupported "atomicrmw of a non-integer type")
  unless 8 ≤ w && w.nextPowerOfTwo == w do
    throw (.unsupported "atomicrmw width not a power of two of at least 8 (LangRef)")
  if st.res.any fn.uses then
    throw (.unsupported "atomicrmw whose result is used (it depends on the order)")

/-- The scope of a frame at step `k`. -/
def Ctx.scope (c : Ctx) (m : Mem) (f : Frame) (k : Nat) : Scope :=
  ⟨c.prog.layout, m, c.globals, f.regs, fun i => c.oracle (Nat.pair k i)⟩

/-- The effect of statement `st` of frame `f` with scope `s` at step `k`; an `alloca` makes block
number `m.fresh` of the thread and `k` (unsupported if that number is in use, so no block is
overwritten), with addresses `c.addr (Nat.pair k 0)` and `c.addr (Nat.pair k 1)`. -/
def exec (c : Ctx) (s : Scope) (k : Nat) (f : Frame) (st : Stmt) : Except Fault Eff := do
  let l := c.prog.layout
  let m := s.mem
  let ev := evalV s
  let nextP (v : Val) (prod : Option (Val × Val)) : Except Fault Eff :=
    pure (.next { f.set st.res (some v) prod with pc := f.pc + 1 } m)
  let next (v : Val) := nextP v none
  let prodOf : Value → Option (Val × Val) := fun
    | .loc r => f.prods r
    | _ => none
  let laneOf (p : Option (Val × Val)) (i : Nat) := p.map fun (u, v) => (u.lane i, v.lane i)
  st.checkMd
  match st.inst with
  | .bin op fl t a b =>
    next (← lanes2 (fun _ => intBin (l.scalarBits t.elt) op fl) (← ev t a) (← ev t b))
  | .fbin op fm t a b => match t.elt with
    | .fp ft => do
      let x ← ev t a
      let y ← ev t b
      let r ← lanes2 (fun i u v =>
        floatBin ft op fm u v (laneOf (prodOf a) i) (laneOf (prodOf b) i) (s.ch i)) x y
      nextP r (if op == .fmul && fm.contract then some (x, y) else none)
    | _ => throw (.unsupported "float operator on non-floats")
  | .fneg fm (.mk t a) => next (← fnegV fm t (← ev t a))
  | .icmp p t a b => next (← icmpV l m p t (← ev t a) (← ev t b))
  | .fcmp fm p t a b => next (← fcmpV fm p t (← ev t a) (← ev t b))
  | .cast op (.mk t a) ty => next (← castV l m op t (← ev t a) ty s.ch)
  | .select (.mk ct c') (.mk t a) (.mk _ b) => next (← selectV t (← ev ct c') (← ev t a) (← ev t b))
  | .phi _ _ => throw (.unsupported "phi after a non-phi instruction")
  | .alloca t cnt al => do
    let n ← match cnt with
      | none => pure 1
      | some (.mk ct cv) => match ← ev ct cv with
        | .bits _ b => pure b.toNat
        | _ => throw (.unsupported "alloca count that is not a number")
    let live := !(st.res.any (lifetimeStarted c f.fn))
    let b := m.fresh c.who.thread k
    if (m.blocks b).isSome then throw (.unsupported "alloca number in use")
    let (m', b) :=
      m.alloc l l.allocaSpace (n * l.size t) (al.getD (l.align t)) live false
        (.thread c.who.thread) (c.addr (Nat.pair k 0)) (c.addr (Nat.pair k 1)) (num := some b)
    pure (.next { f.set st.res (some (.ptr ⟨b, 0⟩)) none with
      pc := f.pc + 1, allocas := b :: f.allocas } m')
  | .load _ t (.mk (.ptr a) p) al => do
    let q ← (← ev (.ptr a) p).addr?
    let v ← m.load l c.who a t q (some (al.getD (l.align t)))
    if st.md.any (·.1 == "noundef") && !v.defined then throw (.ub "noundef load not defined")
    let inv := st.md.any (·.1 == "invariant.load")
    pure (.next { f.set st.res (some v) none with pc := f.pc + 1 }
      (m.log (.access ⟨c.who, q, l.stored t, false, none, inv⟩)))
  | .store _ (.mk t v) (.mk (.ptr a) p) al => do
    let x ← ev t v
    let m' ← m.store l c.who a t x (← (← ev (.ptr a) p).addr?) (some (al.getD (l.align t)))
    pure (.next { f with pc := f.pc + 1 } m')
  | .gep fl src (.mk (.ptr a) b) idx => do
    next (← gep l m fl src a (← evalTVs s idx) (← ev (.ptr a) b))
  | .extractvalue (.mk t a) is => next (← extractV (← ev t a) is)
  | .insertvalue (.mk t a) (.mk te e) is => next (← insertV (← ev t a) (← ev te e) is)
  | .extractelement (.mk t v) i => next (← extractE t (← ev t v) (← evalTV s i))
  | .insertelement (.mk t v) e i => next (← insertE t (← ev t v) (← evalTV s e) (← evalTV s i))
  | .shufflevector (.mk t a) b mk => next (← shuffleV t (← ev t a) (← evalTV s b) (← evalTV s mk))
  | .call fm _ (.fn g) args => do
    let vs ← args.mapM fun (tv, _) => evalTV s tv
    let some fn := c.prog.module.funcs.find? (·.name == g)
      | throw (.unsupported s!"call to unknown function @{g}")
    let floatOp := c.prog.intrinsics.lookup g matches some (.fminmax ..) | some .rsqrtApprox
    unless fm == {} || floatOp && fm == { nnan := fm.nnan, ninf := fm.ninf } do
      throw (.unsupported "fast-math flags on a call other than nnan/ninf on a float intrinsic")
    unless args.all (·.2.all (· == .flag "noundef")) do
      throw (.unsupported "call-site attribute other than noundef")
    let vs ← ((fn.params.zip vs).zip args).mapM fun ((p, v), (_, as)) =>
      withAttrs l m p.ty (p.attrs ++ as) v
    if !fn.blocks.isEmpty then
      if fn.params.any (·.attrs.any (· matches .ty "byval" _)) then
        throw (.unsupported "byval argument of a call")
      return .call fn vs
    let some i := c.prog.intrinsics.lookup g | throw (.unsupported s!"no intrinsic @{g}")
    fn.check c.prog.module i
    unless (fn.params.zip args).all fun (p, (⟨_, a⟩, _)) =>
        !p.attrs.contains (.flag "immarg") || a matches .int _ | .float _ do
      throw (.unsupported "immarg argument that is not a constant")
    match ← intrinsic c s fm i vs with
    | none => return .wait i vs fn
    | some (v, m') => do
      if (fn.attrs c.prog.module).contains (.flag "nocreateundeforpoison") &&
          vs.all Val.defined && ownUndef c s i vs then
        throw (.ub "nocreateundeforpoison result not defined")
      let v ← v.mapM (withAttrs l m' fn.ret fn.retAttrs)
      return .next { f.set st.res v none with pc := f.pc + 1 } m'
  | .atomicrmw _ op (.mk (.ptr a) p) (.mk t v) sc ord al => do
    unless sc.isNone && ord == .seqCst do
      throw (.unsupported "atomicrmw other than seq_cst at system scope")
    st.checkAtomic f.fn
    let q ← (← ev (.ptr a) p).addr?
    let x ← ev t v
    unless decide (x.Scalar (l.scalarBits t)) do
      throw (.unsupported "atomicrmw operand that is not a scalar of its type")
    let align := some (al.getD (l.storeSize t))
    let old ← m.load l c.who a t q align
    let m := m.log (.access ⟨c.who, q, l.stored t, false, some op, false⟩)
    let m' ← m.store l c.who a t (← rmw (l.scalarBits t) op old x) q align (some op)
    pure (.next { f with pc := f.pc + 1 } m')
  | _ => throw (.unsupported "instruction form")

/-- Frame `f` entering block `dest` from its current block: the `phi`s at the head of `dest`
take, together, their values for the edge from the current block. -/
def enter (s : Scope) (f : Frame) (dest : Nat) : Except Fault Frame := do
  let some b := f.fn.blocks.find? (·.label == dest)
    | throw (.unsupported s!"no block %{f.fn.names.getD dest ""}")
  let phis := b.stmts.toList.takeWhile (·.inst matches .phi _ _)
  let vals ← phis.mapM fun st => do
    st.checkMd
    match st.inst with
    | .phi t inc => match inc.find? (·.2 == f.label) with
      | some (v, _) => evalV s t v
      | none => throw (.unsupported "phi without the incoming edge")
    | _ => throw (.unsupported "phi")
  let f := (phis.zip vals).foldl (fun f (st, v) => f.set st.res (some v) none) f
  return { f with label := dest, pc := phis.length }

/-- One step of thread `t` on memory `m` in context `c`. Before the end of the current block it
is the instruction at the top frame's `pc` (`exec`); a call of a defined function checks it
(`Func.check`) and pushes its frame (unsupported for a declaration, undefined behavior for a
`norecurse` function already on the stack). At the end of the block it is the terminator: a
branch or `switch` enters its target (undefined behavior on poison), `unreachable` is undefined
behavior, and `ret` ends the frame's `alloca`s and gives its value to the caller's frame, or
finishes the thread from the kernel's. Unsupported for a thread with no frame or a label with no
block. -/
def step (c : Ctx) (t : Thread) (m : Mem) : Except Fault Step := do
  let f :: rest := t.frames | throw (.unsupported "step of a finished thread")
  let s := c.scope m f t.k
  let t' := { t with k := t.k + 1 }
  let some b := f.fn.blocks.find? (·.label == f.label) | throw (.unsupported "no current block")
  let go (f : Frame) (m : Mem) : Step := .next { t' with frames := f :: rest } m
  if h : f.pc < b.stmts.size then
    match ← exec c s t.k f b.stmts[f.pc] with
    | .next f m => return go f m
    | .wait i args r => return .wait i args r
    | .call g args =>
      let some e := g.blocks[0]? | throw (.unsupported "call of a declaration")
      g.check c.prog.module
      if (g.attrs c.prog.module).contains (.flag "norecurse") &&
          (f :: rest).any (·.fn.name == g.name) then
        throw (.ub "recursion of a norecurse function")
      let regs := fun r => ((g.params.zip args).find? (·.1.name == some r)).map (·.2)
      let callee : Frame := { fn := g, label := e.label, pc := 0, regs,
                              prods := fun _ => none, allocas := [],
                              dest := b.stmts[f.pc].res }
      return .next { t' with frames := callee :: f :: rest } m
  else
    match b.term with
    | .br d => return go (← enter s f d) m
    | .condBr cv d e => match ← evalV s (.int 1) cv with
      | .bits _ x => return go (← enter s f (if x.getLsbD 0 then d else e)) m
      | .poison => throw (.ub "branch on poison")
      | _ => throw (.unsupported "branch on a non-boolean")
    | .switch ty v d cases => match ← evalV s ty v with
      | .bits w x =>
        let dest := (cases.find? fun (k, _) => BitVec.ofInt w k == x).map (·.2) |>.getD d
        return go (← enter s f dest) m
      | .poison => throw (.ub "switch on poison")
      | _ => throw (.unsupported "switch on a non-integer")
    | .unreachable => throw (.ub "unreachable")
    | .ret rv => do
      let v ← rv.mapM fun tv => do withAttrs s.layout m f.fn.ret f.fn.retAttrs (← evalTV s tv)
      let m := f.allocas.foldl (fun m b => m.setLive b false) m
      match rest with
      | [] => return .done m
      | g :: rest =>
        return .next { t' with frames := { g.set f.dest v none with pc := g.pc + 1 } :: rest } m

/-- The arguments of kernel `fn` in thread number `n` from argument values `args`: a `byval(T)`
parameter gets a fresh block owned by the thread holding its argument as a `T` (LangRef, "byval":
a hidden copy made between the caller and the callee; each thread is a call of the kernel),
read-only if the parameter is `readonly`, with addresses from `ch` (unsupported if the argument
is not a value of `T`, or if the block's number has a block, `Mem.allocNext`); the others get
their argument under the parameter's attributes (`withAttrs`). Parameters and arguments are
paired in order, and those past the shorter list are dropped. -/
def launchArgs (l : Layout) (m : Mem) (n : Nat) (fn : Func) (args : List Val)
    (ch : Nat → Nat) : Except Fault (Mem × List Val) :=
  (fn.params.zip args).zipIdx.foldlM (init := (m, [])) fun (m, acc) ((p, v), i) =>
    match p.attrs.findSome? fun | .ty "byval" t => some t | _ => none with
    | some t => do
      let some bs := l.encode t v | throw (.unsupported "byval argument not of its type")
      let (m, b) ← m.allocNext l 0 (l.size t) (l.align t) true
        (p.attrs.contains (.flag "readonly")) (.thread n) (ch (2 * i)) (ch (2 * i + 1)) bs
      pure (m, acc ++ [.ptr ⟨b, 0⟩])
    | none => do pure (m, acc ++ [← withAttrs l m p.ty p.attrs v])

/-- A thread at the start of kernel `fn` with arguments `args` (as `launchArgs` makes them). -/
def Thread.start (fn : Func) (args : List Val) : Except Fault Thread := do
  let some e := fn.blocks[0]? | throw (.unsupported "kernel without a body")
  let regs := fun r => ((fn.params.zip args).find? (·.1.name == some r)).map (·.2)
  return { frames := [{ fn, label := e.label, pc := 0, regs, prods := fun _ => none,
                        allocas := [], dest := none }], k := 0 }

/-- A bind succeeds exactly when its first part succeeds and the rest succeeds on its value. -/
theorem Except.bind_eq_ok {ε α β : Type} {x : Except ε α} {f : α → Except ε β} {s : β} :
    x >>= f = .ok s ↔ ∃ r, x = .ok r ∧ f r = .ok s := by
  cases x <;> simp [bind, Except.bind]

end MojoProof.Sem
