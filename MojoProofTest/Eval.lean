import MojoProof.Kernels
import MojoProof.LLVM.Import
import MojoProof.Sem.Grid
import MojoProof.Sem.Buffer
import MojoProof.Sem.Spec
import MojoProof.Sem.Race
import MojoProof.Sem.Schedule

/-!
# Evaluator tests

Runs the grid evaluator (`MojoProof.Sem.Grid.run`) on two corpus kernels with fixed inputs, their
programs the terms `mojo_import` added (`MojoProof.Kernels`).

* `vector_addition` (`tests/corpus/vadd/`): 4 blocks of 32 threads on buffers of 100 floats whose
  bit patterns cover the binary32 range (NaNs, infinities and subnormals included). For two
  oracles, every thread returns and the output buffer holds FloatLib's `Model.add` of the inputs,
  element by element (bit for bit; for a NaN sum, some NaN). The final output block meets the
  premises of `Block.holds_of_tiles` row-major, with each tile's float that sum, so it holds
  the tensor of those floats; checked against the sums of the swapped neighbors (`i ^^^ 1`), tile
  0 fails. This covers one launch, not the kernel. An output buffer one element short
  is undefined behavior (an access out of bounds), and so is a launch whose `%tid.x` leaves its
  `range` attribute (the `noundef` poison).
* `tiled_matmul` (`tests/corpus/tiled_matmul/`, 64 × 64 matrices in 16 × 16 tiles through
  shared memory, 8 barriers): 4 × 4 blocks of 16 × 16 threads. With an oracle that never
  contracts, the output is the left fold of FloatLib's `add` and `mul` over the 64 products in
  the kernel's order; with one that always fuses, the fold of `fma`; the two differ on these
  inputs, so the test sees the contraction choice. The trace of the first run (about 600,000
  accesses) has no race (`fast`, MojoProof/Sem/Race.lean). A launch of one block of 16 × 16
  threads computes the first tile of the output, and its trace (37,888 accesses and 8 barrier
  completions) has no race.

* `castV_bytes4`: `castV_join` at `<4 x i8>` and `i32`, the bytes `[1, 2, 3, 4]` and the word
  `0x04030201`, for every layout, memory and oracle numbers.
* `rsqrt.approx.ftz.f32` (`MojoProof.Sem.rsqrt`): on 4096 spread-out positive finite operands,
  the word 8 units in the last place above the value under the oracle number 0 (the fallback
  `Model.rSqrt`, since the word `+0` misses the contract; the fallback meets it on every operand
  by `rsqrtOk_rSqrt`) does not meet the contract; the special operands give PTX's table;
  at `x = 4` the contract accepts the words 1 unit above and 2 units below `0.5` (relative
  error `2 ^ -23`) and rejects 2 above and 3 below (`2 ^ -22`, `1.5 * 2 ^ -23`).
* Three float counterexamples (`oracleTests`): two
  oracle numbers give two results, so no relation "equal words up to NaN" holds between two runs
  under free oracles. `rsqrt` of 1 is the word of 1 or of `1 + 2 ^ -23` (row `rsqrt.approx`);
  `maxnum` of a signaling NaN and 1 is a NaN or 1 (row `maxnum`); the contracted
  `(1 + 2 ^ -23) * (1 - 2 ^ -23) - 1` is `+0` rounded separately and `-2 ^ -46` fused (row
  `fadd contract`).

* 14 small kernels for attributes, flags and private memory (`runText`): a barrier number 16, a
  `monotonic`
  atomic, `fdiv nsz`, `nnan` on a call to a defined function, a call-site `noundef` poison
  argument and a `signext` one, a `noundef` kernel parameter given poison, a `!noundef` load of
  undefined bytes, a `!range` load, and a thread reading another thread's live `alloca` each give
  their fault; reading its own `alloca` gives none; a `byval` copy that thread 0 writes is not
  seen by thread 1; `nnan` makes `rsqrt.approx` of -1 poison, and without it the result is a word.
* 1 small kernel for allocation numbers (`Mem.fresh`): two threads publish their
  `alloca`s; run in either order, each gets the same block number, and the two numbers differ.
* 1 small kernel for allocation addresses (`Ctx.addr`): the `ptrtoint` of an `alloca`
  is the same under two float oracles and changes with the skeleton choices.
* 9 small kernels for race freedom (`Grid.RaceFree`), in which every thread writes once or,
  for the last two, runs two `atomicrmw`s:
  two threads of one block race without a barrier and do not with one; one thread in each of two
  blocks race with a barrier (it orders one block of threads); two lanes of a warp race with a
  shuffle between their writes (a shuffle orders no memory access); three threads'
  `atomicrmw add`s of 1, 2 and 3 to one word after a barrier do not race and give 6; two such
  `add`s per thread give 12, and an `add` and then an `or` per thread race (`add` and `or` do not
  commute).
  Races are on byte ranges: a `<2 x i32>` store at byte 0 races with an `i32` store at byte 4,
  an `i32` store at byte 0 does not.
* 2 small kernels for barriers: a thread that returns before the barrier the other waits at, and
  two threads at two barrier instructions, are undefined behavior (`.aligned`).
* 4 small kernels for shuffles: a `bfly` shuffle of two lanes exchanges their values; a partial
  member mask, a lane that has returned and lanes at two different shuffles are unsupported. Every
  run of a small kernel, of `vector_addition` and of `tiled_matmul` (the full launch without
  contraction and one block) is checked to have no race in its trace with `fast`, proved sound
  for the core's `racy` at `sig` (`fast_sound`); on every small kernel's trace `fast` and the
  core's `racy` agree.
* 5 small kernels for the promises of TRUST T12: a write to the bytes of an `!invariant.load`,
  before or after it, breaks it (`Grid.Kept`); after it, the run has no fault and no race, so the
  core's `GPUProof.kept` is a separate obligation from safety and race freedom; a `norecurse`
  function that calls itself is undefined behavior;
  `willreturn` on a defined function is unsupported; a null argument for a `nonnull noundef`
  parameter is poison, so undefined behavior. Every run of a small kernel and of
  `vector_addition` (whose two loads have `!invariant.load`) is checked to keep the promise.
* 17 small kernels for parameter attributes, declarations and globals (`paramAttrTests`), each
  fault with a control that
  differs only in the construct and runs: `range` on a `<2 x i32>` parameter applies to each
  element; `nonnull` at address 0 and `align 64` at address 16 make a `noundef` parameter
  poison, as does an intrinsic declaration's `align 64` (on an `alloca` at address 16); a
  declaration's `dereferenceable` and
  `noreturn` are unsupported; a non-constant `immarg` operand is unsupported; a store to a
  `constant` shared global is undefined behavior; an `external constant` shared global and a
  phi's `!noundef` are unsupported.

* 20 small kernels for intrinsic declarations' attributes (`intrinsicAttrTests`): an intrinsic
  declaration's
  `nosync`, `willreturn`, `memory(none)` or `memory(argmem: readwrite)` on the barrier,
  `nosync` or `speculatable` on a shuffle, `speculatable`, `memory(argmem: read)`,
  `memory(none)` or a `readonly` parameter on `lifetime.start`, and an unknown `memory`
  location are unsupported, and so are a barrier and a shuffle declared without `convergent`;
  `vector.extract` declared `nocreateundeforpoison` and giving poison is undefined behavior.
  The controls carry the attributes LLVM declares (those of the corpus files) and run.
* 8 small kernels for the start's check of the caller's memory (`startMemTests`,
  `Mem.checkClosed`, `Mem.allocNext`): two threads `alloca` and take the address of a pointer
  argument that names the number thread 1's `alloca` would take; the launch is unsupported in
  both orders; so is a launch with a pointer to a caller's block above `next`, and one on a
  caller's memory with a block 0; an `alloca` whose number is in use is unsupported; with a
  pointer to the buffer the kernel runs. A caller's block above `next` that nothing names is kept
  by the start and the run, and one at the number the launch's first allocation takes makes the
  launch unsupported.
* 4 small kernels for `nocreateundeforpoison` and `memory` items (`callAttrTests`):
  `maxnum(+∞, 1)` declared
  `nocreateundeforpoison` and called with `ninf` stores poison and is not undefined behavior
  (its own result is defined), and without `ninf` stores `+∞`; a `memory` item with an unknown
  access kind at a location the check does not query is unsupported, and with `none` runs.
* 6 small kernels and a corpus file for the atomics the semantics admits (`Stmt.checkAtomic`):
  `atomicrmw xchg`, `atomicrmw sub`, `atomicrmw fadd`, an `atomicrmw` on `i24` and an
  `atomicrmw add` whose result is used are unsupported; two threads that run their
  `atomicrmw add` in either order and then wait at a barrier have the same registers
  (`regsAfter`: the old value, which depends on the order, is not kept). `atomicTests`: in
  `tests/corpus/reduction/`, the only corpus file with an atomic, every statement passes the
  check (its `atomicrmw add`'s result is unused), and two twins of the file's text, with `xchg`
  for `add` and with the result used, are refused.
* 2 small kernels for `step_pending` (L1a, docs/proofs/schedule.md): two threads, each stepped
  until it returns, through two stores, a load and an `atomicrmw add`; every step puts exactly the
  thread's pending accesses (`Thread.pending`) in front of the trace, 10 in all
  (`pendingTests`). Twin: a load through null has its access pending, but the step faults and
  logs nothing.
* 19 small kernels and 2 corpus files for the launch (`launchTests`): a `byval` copy declared
  `noundef nonnull` has a nonzero address at four address choices (`place`), and a plain
  `noundef nonnull` parameter given null is undefined behavior; gevm_t512's kernel
  (`"nvvm.maxntid"="512"`) starts on 512 threads and not 513, gemv's gevm_kernel (`"1024"`) on
  1024 and not 1025, a kernel with `"nvvm.reqntid"` at its shape and not another
  (`Func.checkLaunch`); a kernel with the `!nvvm.annotations` entry `reqntidx 32` starts on 32
  threads and not 64, one with `maxntidx 64` on 64 and not 65, one with `kernel` alone starts,
  `maxnreg` is unsupported, and so is a `"nvvm.maxntid"` the annotations disagree with; a `byval`
  copy aligned to 256 bytes with 8-bit pointers is unsupported (TRUST T11: no nonzero aligned
  address exists), and one aligned to 128 bytes is at address 128; with 8-bit pointers a 2-byte
  copy at the choice 255 (whose end would wrap) is at address 1 and at the choice 7 at 7, a
  128-byte copy (above the index width's largest signed value) is unsupported and a 127-byte one
  is at its choice 3; a `byval` copy of `{i8, i32}` (with padding) is unsupported, one of
  `{i32, i32}` gives its byte 1; an annotation value of type `i64` is unsupported;
  `"target-cpu"` is admitted and `"denormal-fp-math"` unsupported; a kernel runs on as many
  arguments as parameters, and one fewer or one more is unsupported.
* 38 small kernels and 2 index steps for accesses (`accessTests`): `griddepcontrol` does nothing
  (TRUST T19) and an unknown name of it is unsupported, and `griddepcontrol.wait` in a kernel whose
  `"target-cpu"` is "sm_80" is unsupported while at "sm_90a" it runs; in a helper with no
  `"target-cpu"` it is unsupported from an "sm_80" entry, from one with none and from an "sm_90"
  entry beside an "sm_80" function, and runs from an "sm_90" entry; a `volatile` load, store and
  `atomicrmw` are unsupported, and their plain twins run; a load from an `alloca` after
  `lifetime.end` or before `lifetime.start` is unsupported (poison in LLVM)
  and a store after `lifetime.end` undefined behavior, and both run in the lifetime; a lifetime
  marker on a `getelementptr` of an `alloca` or on a pointer a callee returned is unsupported, one
  on poison runs; a load through a pointer to a callee's returned `alloca` is undefined behavior,
  and the same load before the return gives the stored word; `getelementptr nuw` of index -1 into a
  zero-size type is the base pointer, of `i8` at -1 and of `i32` at `2 ^ 62` poison, and of `i8` at
  4 the pointer to byte 4; struct field 128 at an 8-bit index width is selected, and an index beyond
  the struct unsupported; an `f0x` literal with `float`'s 8 digits at `double` is unsupported, and
  with `double`'s 16 digits it stores its bits, as `float`'s 8 digits do at `float` (a quiet NaN
  with payload 1 among them); a struct index `i64 1` or `i32 %f` is unsupported, and `i32 1` stores
  to field 1; in the semantics (`gepSteps`) a struct index not of type `i32` is unsupported and
  `i32 1` is field 1 at offset 4.

These run the evaluator on two corpus kernels and 146 small ones, start two more corpus files,
check a third, and the contract on fixed operands; they prove nothing.
-/

namespace MojoProofTest

open MojoProof MojoProof.LLVM MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange

/-- Test input `i` of buffer `seed`: small multiples of 1/4 and spread-out bit patterns. -/
def input (seed i : Nat) : Model FloatFormat.binary32 :=
  if i % 3 = 0 then Model.ofRat .binary32 ((i : Rat) / 4 - seed)
  else Model.ofNatBits ((i * 2654435761 + seed * 40503) % 2 ^ 32)

mutual
/-- The value of a buffer argument of type `t`: pointer `p` in its pointer fields, empty
structures elsewhere. The recursion through `bufArgs` is structural, so the kernel evaluates it
(`decide +kernel`). -/
def bufArg (p : Ptr) : Ty → Val
  | .ptr _ => .ptr p
  | .struct fs => .agg (bufArgs p fs)
  | _ => .agg []

/-- `bufArg p` of each field type `ts`, in order. -/
def bufArgs (p : Ptr) : List Ty → List Val
  | [] => []
  | t :: ts => bufArg p t :: bufArgs p ts
end

/-- The arguments of a launch of `fn`, for every function: buffer `j` at offset 0 of block
`bufs[j]`, as `bufArg` builds it at parameter `j`'s `byval` type (a pointer if the parameter has
none), one buffer for each of the first `bufs.length` parameters (the rest of `bufs` is dropped
when `fn` has fewer parameters), then the values `extra`. -/
def kernelArgs (fn : Func) (bufs : List Nat) (extra : List Val) : List Val :=
  let tys := fn.params.map fun p => (p.attrs.findSome? fun | .ty "byval" t => some t | _ => none)
  (bufs.zip tys).map (fun (b, t) => bufArg ⟨b, 0⟩ (t.getD (.ptr 0))) ++ extra

/-- `v` is the float `r`, bit for bit, or some NaN if `r` is a NaN. -/
def isF32 (r : Model FloatFormat.binary32) (v : Val) : Bool :=
  match v.float? .float with
  | some x => if r.isNaN then x.isNaN else x.toNatBits == r.toNatBits
  | none => false

/-- A fault as a failure message. -/
def err (e : Fault) : String := s!"{repr e}"

/-- The start of a launch of the kernel of `prog` (the first of `prog.kernels`) with `L`,
buffers `ins` of floats, then an output buffer of `out` floats, then the scalar arguments
`extra`; thread `n` gets oracle `oracle n` and every address choice is `oracle 0`. Input buffer
`j` is a block at address `0x100 * (j + 1)` that `Mem.holds_alloc` proves holds its tensor
(`tensorBytes`, row-major); the output buffer is a block of `4 * out` bytes at `0x10000`. Returns
the start's grid and contexts (`MojoProof.Sem.Grid.start`) and the output buffer's block, or the
fault as a message. The kernel evaluates it, with `Array.anyM.loop` unsealed: at
`vector_addition`'s launch of `vaddTests` in `MojoProofTest.RacySig.trSig_run`. -/
def startF32 (prog : Program) (L : Launch) (oracle : Nat → Nat → Nat)
    (ins : List (List (Model FloatFormat.binary32))) (out : Nat) (extra : List Val) :
    Except String (Grid × (Nat → Ctx) × Nat) := do
  let l := prog.layout
  let some fn := prog.module.funcs.find? (some ·.name == prog.kernels.head?)
    | throw "no kernel"
  let start : Mem × List Nat := ({}, [])
  let (m, bufs) := ins.zipIdx.foldl (init := start) fun (m, acc) (xs, j) =>
    let x : TorchLean.Tensor _ [xs.length] :=
      .ofFlatFn fun k => xs[k.val]'(by simpa [TorchLean.Shape.size] using k.isLt)
    let bs := tensorBytes l (.fp .float) (.ofFloat .float) x
    let (m, b) := m.alloc l 1 (TorchLean.Shape.size [xs.length] * l.size (.fp .float)) 16 true
      false .all (0x100 * (j + 1)) (0x100 * (j + 1)) bs
    (m, acc ++ [b])
  let (m, c) := m.alloc l 1 (4 * out) 16 true false .all 0x10000 0x10000
  let (g, ctx) ← (Grid.start prog fn L (kernelArgs fn (bufs ++ [c]) extra) m (oracle 0)
    oracle).mapError err
  return (g, ctx, c)

/-- The run of the launch that `startF32` starts, with the same arguments: the evaluator
(`MojoProof.Sem.Grid.run`, at most 100 phases of at most 100000 steps per thread and phase)
from the start's grid and contexts. Returns the final grid and the output buffer's block, or the
fault as a message. -/
def gridF32 (prog : Program) (L : Launch) (oracle : Nat → Nat → Nat)
    (ins : List (List (Model FloatFormat.binary32))) (out : Nat) (extra : List Val) :
    Except String (Grid × Nat) := do
  let (g, ctx, c) ← startF32 prog L oracle ins out extra
  let g ← (g.run L ctx 100000 100).mapError err
  return (g, c)

/-- Launch the kernel of `prog` with `L`, buffers `ins` of floats, then an output buffer of
`out` floats, then the scalar arguments `extra`; thread `n` gets oracle `oracle n`. The run is
`gridF32`'s (the start `startF32`): each input buffer is the block `Mem.holds_alloc` proves holds
its tensor (`tensorBytes`, row-major). Returns the output buffer's values; with `race`, a data
race in the run's trace (`fast`, which finds every race the core's `racy` finds) or a write to
the bytes of an `!invariant.load` (`GPUProof.kept`) is a failure. With `tiles := some r`, the
final output block must meet the premises of `Block.holds_of_tiles` row-major from 0, with `f i`
the float decoded at tile `i`, and each `f i` must be `r i` (`isF32`): a tile `i` that fails is
reported as `tile i`. -/
def runF32 (prog : Program) (L : Launch) (oracle : Nat → Nat → Nat)
    (ins : List (List (Model FloatFormat.binary32))) (out : Nat) (extra : List Val)
    (race := false) (tiles : Option (Nat → Model FloatFormat.binary32) := none) :
    Except String (List Val) := do
  let l := prog.layout
  let (g, c) ← gridF32 prog L oracle ins out extra
  if race && fast g.mem.trace then throw "data race"
  if race && !GPUProof.kept sig (g.mem.trace.map (Event.toCore L)).reverse then
    throw "invariant load written"
  if let some r := tiles then
    let some blk := g.mem.blocks c | throw "no output block"
    let t : Ty := .fp .float
    for k in List.finRange (TorchLean.Shape.size [out]) do
      let o := rowMajor l t 0 (TorchLean.Shape.Coord.unlinearize k)
      let bs := blk.read o (l.stored t)
      let ok := match (l.decode t bs).bind (·.float? .float) with
        | some x => o + l.stored t ≤ blk.size && l.encode t (.ofFloat .float x) == some bs &&
            isF32 (r k) (.ofFloat .float x)
        | none => false
      if !ok then throw s!"tile {k}: not the encoding of the reference"
  match g.mem.load l default 1 (.arr out (.fp .float)) ⟨c, 0⟩ (some 4) with
  | .ok (.agg vs) => return vs
  | .ok _ => throw "output buffer holds no array"
  | .error e => throw s!"reading the output: {err e}"

/-- The outputs `vs` are `n` values, the `i`-th `isF32 (f i)`. -/
def check (name : String) (n : Nat) (f : Nat → Model FloatFormat.binary32) :
    Except String (List Val) → Array String
  | .ok vs =>
    if vs.length = n && (vs.zipIdx.all fun (v, i) => isF32 (f i) v) then #[]
    else #[s!"{name}: output differs from the FloatLib reference"]
  | .error e => #[s!"{name}: {e}"]

/-- The run fails with a message containing `msg`. -/
def checkFault (name msg : String) : Except String (List Val) → Array String
  | .error e => if (e.splitOn msg).length > 1 then #[] else #[s!"{name}: wrong fault {e}"]
  | .ok _ => #[s!"{name}: no fault"]

/-- The input buffers of the `vector_addition` tests (`vaddTests`): `input 1` and `input 2` at
100 floats each. -/
def vaddIns : List (List (Model FloatFormat.binary32)) :=
  [(List.range 100).map (input 1), (List.range 100).map (input 2)]

/-- The `vector_addition` tests on program `prog`, on the inputs `vaddIns`; returns the
failures. -/
def vaddTests (prog : Program) : Array String :=
  let ins := vaddIns
  let n : Val := .bits 32 (BitVec.ofNat 32 100)
  let sum (i : Nat) := Model.add (input 1 i) (input 2 i)
  check "vadd (zero oracle)" 100 sum
    (runF32 prog (launch2 4 1 32 1) (fun _ _ => 0) ins 100 [n] true) ++
  check "vadd (mixing oracle)" 100 sum
    (runF32 prog (launch2 4 1 32 1) (fun t i => (t * 31 + i) * 7919 + 1) ins 100 [n] true) ++
  check "vadd (written tiles)" 100 sum
    (runF32 prog (launch2 4 1 32 1) (fun _ _ => 0) ins 100 [n] (tiles := some sum)) ++
  checkFault "vadd (swapped tiles)" "tile 0:"
    (runF32 prog (launch2 4 1 32 1) (fun _ _ => 0) ins 100 [n] (tiles := some (sum <| · ^^^ 1))) ++
  checkFault "vadd (short output)" "access out of bounds"
    (runF32 prog (launch2 4 1 32 1) (fun _ _ => 0) ins 99 [n]) ++
  checkFault "vadd (tid out of range)" "noundef value not defined"
    (runF32 prog (launch2 1 1 1100 1) (fun _ _ => 0) ins 100 [n])

/-- Matrix test entries: small rationals, most not exact in binary32. -/
def entry (seed i : Nat) : Model FloatFormat.binary32 :=
  Model.ofRat .binary32 (((i * (seed + 6) % 19 : Nat) : Rat) / 7 - 1)

/-- Entry `i` of the 64 × 64 product of `entry 1` and `entry 2` (row-major), as the kernel sums:
the first product plus `+0`, then each next product added (`fma` with `fused`). -/
def matmulRef (fused : Bool) (i : Nat) : Model FloatFormat.binary32 :=
  let r := i / 64
  let c := i % 64
  let a (k : Nat) := entry 1 (r * 64 + k)
  let b (k : Nat) := entry 2 (k * 64 + c)
  (List.range' 1 63).foldl (fun acc k => if fused then Model.fma (a k) (b k) acc
      else Model.add acc (Model.mul (a k) (b k)))
    (Model.add (Model.mul (a 0) (b 0)) (Model.ofRat .binary32 0))

/-- The `tiled_matmul` tests on program `prog`; returns the failures. -/
def matmulTests (prog : Program) : Array String :=
  let ins := [(List.range 4096).map (entry 1), (List.range 4096).map (entry 2)]
  let L := launch2 4 4 16 16
  let differ := (List.range 4096).any fun i =>
    (matmulRef false i).toNatBits != (matmulRef true i).toNatBits
  check "tiled_matmul (no contraction)" 4096 (matmulRef false)
    (runF32 prog L (fun _ _ => 0) ins 4096 [] true) ++
  check "tiled_matmul (contraction)" 4096 (matmulRef true)
    (runF32 prog L (fun _ _ => 2) ins 4096 []) ++
  (if differ then #[] else #["tiled_matmul: fused and unfused references agree"]) ++
  match runF32 prog (launch2 1 1 16 16) (fun _ _ => 0) ins 4096 [] true with
  | .ok vs =>
    if (List.range 256).all fun k =>
        let i := k / 16 * 64 + k % 16
        vs[i]?.map (isF32 (matmulRef false i)) == some true then #[]
    else #["tiled_matmul (one block): the first tile differs from the FloatLib reference"]
  | .error e => #[s!"tiled_matmul (one block): {e}"]

/-- The `rsqrt.approx.ftz.f32` contract (`MojoProof.Sem.rsqrt`); returns the failures. -/
def rsqrtTests : Array String :=
  let f (n : Nat) : Model FloatFormat.binary32 := Model.ofNatBits n
  let is (x n r : Nat) : Bool := (rsqrt (f x) n).toNatBits == r
  let nan (x : Nat) : Bool := (rsqrt (f x) 0).isNaN
  let pos (x : Model FloatFormat.binary32) : Bool :=
    x.isFinite && !x.signBit && !x.isZero && !x.isSubnormal
  let spread := (List.range 4096).map fun i => i * 2654435761 % 2 ^ 32
  let fallback := spread.all fun n =>
    !pos (f n) || !rsqrtOk (f n) (f ((rsqrt (f n) 0).toNatBits + 8))
  (if fallback then #[] else #["rsqrt: 8 ulps above the fallback meet the contract"]) ++
  (if is 0 0 0x7f800000 && is 0x80000000 0 0xff800000 && is 1 0 0x7f800000 &&
      is 0x80000001 0 0xff800000 && is 0x7f800000 0 0 && nan 0xff800000 && nan 0x7fc00000 &&
      nan 0xbf800000 then #[] else #["rsqrt: special operands differ from PTX's table"]) ++
  (if is 0x40800000 0x3f000001 0x3f000001 && is 0x40800000 0x3efffffe 0x3efffffe &&
      is 0x40800000 0x3f000002 0x3f000000 && is 0x40800000 0x3efffffd 0x3f000000 then #[]
    else #["rsqrt: at x = 4 the contract misjudges the words near 0.5"])

/-- Three float counterexamples, each a pair of oracle numbers with different results (`rsqrt` of
1, `maxnum` of a signaling NaN and 1, the contracted `(1 + 2 ^ -23) * (1 - 2 ^ -23) - 1`);
returns the failures. -/
def oracleTests : Array String :=
  let f (n : Nat) : Model FloatFormat.binary32 := Model.ofNatBits n
  let rs (n : Nat) := (rsqrt (f 0x3f800000) n).toNatBits
  let mx (n : Nat) := maxnum true (f 0x7fa00000) (f 0x3f800000) n
  let a := f 0x3f800001
  let b := f 0x3f7ffffe
  let ct (n : Nat) := (contract false (Model.mul a b) (f 0xbf800000) (some (a, b)) none n).toNatBits
  (if rs 0x3f800000 == 0x3f800000 && rs 0x3f800001 == 0x3f800001 then #[]
    else #["rsqrt 1: not both 1 and 1 + 2^-23"]) ++
  (if (mx 1).isNaN && (mx 0).toNatBits == 0x3f800000 then #[]
    else #["maxnum sNaN 1: not both a NaN and 1"]) ++
  (if ct 0 == 0 && ct 1 == 0xa8800000 then #[] else #["contraction: not both +0 and -2^-46"])

/-- Kernel text `src` started on `blocks` blocks of `threads` threads with skeleton choices `ch`
and payload choices `oracle` (zero by default), on arguments `args b`, where `b` points to a
buffer of 64 bytes (space 1) at address `16 * addr` in space 1 and in the generic space,
allocated in memory `m0`, with the accumulation policy `acc` of `mma` (`gridAcc` by default): the
layout, the launch, the buffer's block, the grid and the contexts. -/
def startText (src : String) (threads : Nat) (args : Val → List Val) (blocks := 1)
    (addr := 0x100) (ch : Nat → Nat := fun _ => 0) (oracle : Nat → Nat → Nat := fun _ _ => 0)
    (m0 : Mem := {}) (acc : MmaAcc := gridAcc) :
    Except String (Layout × Launch × Nat × Grid × (Nat → Ctx)) := do
  let prog ← importBytes src.toUTF8
  let some fn := prog.module.funcs.find? (some ·.name == prog.kernels.head?)
    | throw "no kernel"
  let (m, c) := m0.alloc prog.layout 1 64 16 true false .all addr addr
  let L := { launch2 blocks 1 threads 1 with acc := acc }
  let (g, ctx) ← (Grid.start prog fn L (args (.ptr ⟨c, 0⟩)) m ch oracle).mapError err
  return (prog.layout, L, c, g, ctx)

/-- Run kernel text `src` started as `startText` starts it, with the accumulation policy `acc`;
`pre` changes the grid after the start. Returns the buffer's first `n` values of type `ty`. With
`rev` the threads first run in reverse order, each until it waits or returns. A data race in the
run's trace (the core's `racy` at `sig`), a disagreement of `fast` with it, or a write to the
bytes of an `!invariant.load` (the core's `GPUProof.kept` at `sig`) is a failure. -/
def runText (src : String) (threads : Nat) (args : Val → List Val) (n : Nat := 0)
    (blocks := 1) (addr := 0x100) (ty : Ty := .int 32) (rev := false)
    (ch : Nat → Nat := fun _ => 0) (oracle : Nat → Nat → Nat := fun _ _ => 0)
    (m0 : Mem := {}) (pre : Grid → Grid := id) (acc : MmaAcc := gridAcc) :
    Except String (List Val) := do
  let (l, L, c, g, ctx) ← startText src threads args blocks addr ch oracle m0 acc
  let g := pre g
  let g ← if rev then (g.runAll ctx 1000 (List.range g.threads.size).reverse).mapError err
    else pure g
  let g ← (g.run L ctx 1000 10).mapError err
  let r := GPUProof.racy sig (g.mem.trace.map (Event.toCore L)).reverse
  if r != fast g.mem.trace then throw "fast and racy disagree"
  if r then throw "data race"
  if !GPUProof.kept sig (g.mem.trace.map (Event.toCore L)).reverse then
    throw "invariant load written"
  match g.mem.load l default 1 (.arr n ty) ⟨c, 0⟩ (some 4) with
  | .ok (.agg vs) => return vs
  | .ok _ => throw "buffer holds no array"
  | .error e => throw s!"reading the buffer: {err e}"

/-- Kernel text `src` on one block of 2 threads with the buffer as its argument, run until
both wait, its collective calls completed, and run again in the order `ns` until both wait: the
words in the registers of each thread's innermost frame. -/
def regsAfter (src : String) (ns : List Nat) : Except String (List (List (Option Nat))) := do
  let (_, L, _, g, ctx) ← startText src 2 fun b => [b]
  let g ← (g.runAll ctx 1000 [0, 1]).mapError err
  let (g, _) ← (Grid.fireAll L ctx [0, 1] g).mapError err
  let g ← (g.runAll ctx 1000 ns).mapError err
  return g.threads.toList.map fun
    | .run t | .wait t .. => match t.frames with
      | f :: _ => (List.range f.fn.names.size).map fun r => (f.regs r).bind Val.word?
      | [] => []
    | .done => []

/-- The outputs are the words `ws`. -/
def checkWords (name : String) (ws : List Nat) : Except String (List Val) → Array String
  | .ok vs => if vs.map Val.word? == ws.map some then #[] else #[s!"{name}: wrong words"]
  | .error e => #[s!"{name}: {e}"]

/-- Small kernels for attributes, flags and private memory, each with the fault or the words it
must give. -/
def textTests : Array String :=
  let tid := "declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n"
  let bar := "declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #90\n\
    attributes #90 = { convergent }\n"
  let rsqrt := "declare float @llvm.nvvm.rsqrt.approx.ftz.f(float)\n"
  let none (_ : Val) : List Val := []
  let buf (b : Val) : List Val := [b]
  -- every thread publishes its alloca at slot `tid` of the buffer
  let numbered := "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = alloca i32, align 4\n\
      %3 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %4 = getelementptr inbounds i64, ptr addrspace(1) %0, i32 %3\n\
      store ptr %2, ptr addrspace(1) %4, align 8\n\
      ret void\n\
    }\n" ++ tid
  let numbers (rev : Bool) : Except String (List Ptr) := do
    (← runText numbered 2 buf 2 (ty := .ptr 0) (rev := rev)).mapM fun
      | .ptr p => pure p
      | _ => throw "not a pointer"
  -- the address of an alloca, as `ptrtoint` reads it, under skeleton choices `ch` and payload
  -- choices `oracle`
  let addressed (ch : Nat → Nat) (oracle : Nat → Nat → Nat) : Except String (List (Option Nat)) :=
    (·.map Val.word?) <$> runText "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = alloca i32, align 4\n\
      %3 = ptrtoint ptr %2 to i64\n\
      store i64 %3, ptr addrspace(1) %0, align 8\n\
      ret void\n\
    }\n" 1 buf 1 (ty := .int 64) (ch := ch) (oracle := oracle)
  -- thread 0 publishes its alloca, thread 1 reads through it while thread 0 waits
  let publish (q : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = alloca i32, align 4\n\
      store i32 7, ptr %2, align 4\n\
      %3 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %4 = icmp eq i32 %3, 0\n\
      br i1 %4, label %5, label %6\n\
    5:\n\
      store ptr %2, ptr addrspace(1) %0, align 8\n\
      br label %6\n\
    6:\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      %7 = load ptr, ptr addrspace(1) %0, align 8\n\
      %8 = load i32, ptr " ++ q ++ ", align 4\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      ret void\n\
    }\n" ++ tid ++ bar
  -- the threads whose `%reg.x` is 0 store 1 to word 0, then all execute `sync`, then the others
  -- store 2
  let barCall := "call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n"
  let shflCall := "%s = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 0, i32 1, i32 31)\n"
  let shflDecl := "declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #91\n\
    attributes #91 = { convergent }\n"
  -- thread 0 runs store `a`; thread 1 stores 2 at byte 4 of the buffer (`%4`); no barrier
  let pair (a : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %3 = icmp eq i32 %2, 0\n\
      %4 = getelementptr inbounds i8, ptr addrspace(1) %0, i64 4\n\
      br i1 %3, label %5, label %6\n\
    5:\n" ++ a ++ "ret void\n\
    6:\n\
      store i32 2, ptr addrspace(1) %4, align 4\n\
      ret void\n\
    }\n" ++ tid
  -- the threads with `tid` 0 run `first`, then every thread waits at a barrier
  let diverge (first : String) := "define ptx_kernel void @k() {\n\
      %1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %2 = icmp eq i32 %1, 0\n\
      br i1 %2, label %3, label %4\n\
    3:\n" ++ first ++ "4:\n" ++ barCall ++ "ret void\n\
    }\n" ++ tid ++ bar
  -- every thread writes to word `tid` the `bfly` shuffle of its `tid` with mask `mask`; the
  -- threads with `tid` 0 run `first` before
  let shuffle (mask : String) (first := "br label %5\n") :=
    "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %3 = icmp eq i32 %2, 0\n\
      br i1 %3, label %4, label %5\n\
    4:\n" ++ first ++ "5:\n\
      %6 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 " ++ mask ++ ", i32 %2, i32 1, i32 31)\n\
      %7 = getelementptr inbounds i32, ptr addrspace(1) %0, i32 %2\n\
      store i32 %6, ptr addrspace(1) %7, align 4\n\
      ret void\n\
    }\n" ++ tid ++ shflDecl
  let race (sync : String) (reg := "tid") :=
    let w (v : String) := s!"store i32 {v}, ptr addrspace(1) %0, align 4\n"
    s!"define ptx_kernel void @k(ptr addrspace(1) %0) \{\n\
      %2 = call i32 @llvm.nvvm.read.ptx.sreg.{reg}.x()\n\
      %3 = icmp eq i32 %2, 0\n\
      br i1 %3, label %4, label %5\n\
    4:\n" ++ w "1" ++ "br label %5\n\
    5:\n" ++ sync ++ "br i1 %3, label %7, label %6\n\
    6:\n" ++ w "2" ++ "br label %7\n\
    7:\n\
      ret void\n\
    }\n" ++ s!"declare i32 @llvm.nvvm.read.ptx.sreg.{reg}.x()\n" ++ bar ++ shflDecl
  -- thread 0 stores 0 to word 0; after a barrier, every thread runs `atomicrmw op` on it with
  -- operand `x` (default `tid + 1`), then `after`
  let atomic (op : String) (x := "i32 %6") (after := "") :=
    "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %3 = icmp eq i32 %2, 0\n\
      br i1 %3, label %4, label %5\n\
    4:\n\
      store i32 0, ptr addrspace(1) %0, align 4\n\
      br label %5\n\
    5:\n" ++ barCall ++ "%6 = add i32 %2, 1\n\
      %7 = atomicrmw " ++ op ++ " ptr addrspace(1) %0, " ++ x ++ " seq_cst, align 4\n" ++ after ++
      "ret void\n\
    }\n" ++ tid ++ bar
  let rmw2 (op : String) :=
    "%8 = atomicrmw " ++ op ++ " ptr addrspace(1) %0, i32 %6 seq_cst, align 4\n"
  let root (fm : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = call " ++ fm ++ "float @llvm.nvvm.rsqrt.approx.ftz.f(float -1.0)\n\
      store float %2, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n" ++ rsqrt
  checkFault "barrier 16" "barrier number outside 0-15" (runText ("define ptx_kernel void @k() {\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 16)\n\
      ret void\n\
    }\n" ++ bar) 2 none) ++
  checkFault "monotonic atomicrmw" "atomicrmw other than seq_cst at system scope"
    (runText "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = atomicrmw add ptr addrspace(1) %0, i32 1 monotonic, align 4\n\
      ret void\n\
    }" 1 buf) ++
  checkFault "call-site noundef" "noundef value not defined"
    (runText "define void @f(i32 %0) {\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k() {\n\
      call void @f(i32 noundef poison)\n\
      ret void\n\
    }" 1 none) ++
  checkFault "call-site attribute" "call-site attribute other than noundef"
    (runText "define void @f(i32 %0) {\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k() {\n\
      call void @f(i32 signext 1)\n\
      ret void\n\
    }" 1 none) ++
  checkFault "noundef kernel parameter" "noundef value not defined"
    (runText "define ptx_kernel void @k(i32 noundef %0) {\n\
      ret void\n\
    }" 1 fun _ => [.poison]) ++
  checkFault "!noundef load" "noundef load not defined" (runText "define ptx_kernel void @k() {\n\
      %1 = alloca i32, align 4\n\
      %2 = load i32, ptr %1, align 4, !noundef !0\n\
      ret void\n\
    }\n\
    !0 = !{}" 1 none) ++
  checkFault "!range load" "metadata !range"
    (runText "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = load i32, ptr addrspace(1) %0, align 4, !range !0\n\
      ret void\n\
    }\n\
    !0 = !{i32 0, i32 1}" 1 buf) ++
  checkFault "another thread's alloca" "access to another thread's or block's memory"
    (runText (publish "%7") 2 buf) ++
  checkWords "own alloca" [] (runText (publish "%2") 2 buf) ++
  (match numbers false, numbers true with
    | .ok [p, q], .ok ps =>
      (if ps = [p, q] then #[] else #["alloca numbers depend on the schedule"]) ++
        (if p.block ≠ q.block then #[] else #["two threads' allocas share a number"])
    | .error e, _ | _, .error e => #[s!"alloca numbers: {e}"]
    | _, _ => #["alloca numbers: not two pointers"]) ++
  (match addressed (fun _ => 0) (fun _ _ => 0), addressed (fun _ => 0) (fun _ _ => 7),
      addressed (fun _ => 3) (fun _ _ => 0) with
    | .ok a, .ok b, .ok d =>
      (if a = b then #[] else #["alloca addresses depend on the float oracle"]) ++
        (if a ≠ d then #[] else #["alloca addresses do not come from the skeleton choices"])
    | .error e, _, _ | _, .error e, _ | _, _, .error e => #[s!"alloca addresses: {e}"]) ++
  checkWords "byval copy per thread" [9, 5]
    (runText ("define ptx_kernel void @k(ptr byval(i32) %0, ptr addrspace(1) %1) {\n\
      %3 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %4 = icmp eq i32 %3, 0\n\
      br i1 %4, label %5, label %6\n\
    5:\n\
      store i32 9, ptr %0, align 4\n\
      br label %6\n\
    6:\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      %7 = load i32, ptr %0, align 4\n\
      %8 = getelementptr inbounds i32, ptr addrspace(1) %1, i32 %3\n\
      store i32 %7, ptr addrspace(1) %8, align 4\n\
      ret void\n\
    }\n" ++ tid ++ bar) 2 (fun b => [.bits 32 5, b]) 2) ++
  checkFault "race in a block" "data race" (runText (race "") 2 buf) ++
  checkWords "barrier in a block" [2] (runText (race barCall) 2 buf 1) ++
  checkFault "race across blocks" "data race" (runText (race barCall "ctaid") 1 buf 1 2) ++
  checkFault "shuffle in a warp" "data race" (runText (race shflCall) 2 buf) ++
  checkFault "overlapping vector store" "data race"
    (runText (pair "store <2 x i32> <i32 1, i32 1>, ptr addrspace(1) %0, align 8\n") 2 buf) ++
  checkWords "adjacent stores" [1, 2]
    (runText (pair "store i32 1, ptr addrspace(1) %0, align 4\n") 2 buf 2) ++
  checkFault "barrier with a returned thread" "aligned barrier with a returned thread"
    (runText (diverge "ret void\n") 2 none) ++
  checkFault "divergent barriers" "threads of a block at different barriers"
    (runText (diverge (barCall ++ "br label %4\n")) 2 none) ++
  checkWords "shuffle" [1, 0] (runText (shuffle "-1") 2 buf 2) ++
  checkFault "partial shuffle mask" "partial member mask" (runText (shuffle "3") 2 buf) ++
  checkFault "shuffle with a returned lane" "returned lane"
    (runText (shuffle "-1" "ret void\n") 2 buf) ++
  checkFault "divergent shuffles" "different collectives" (runText (shuffle "-1"
    "%d = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 0, i32 1, i32 31)\nbr label %5\n")
    2 buf) ++
  checkWords "atomics" [6] (runText (atomic "add") 3 buf 1) ++
  -- Every thread runs a second `atomicrmw` after its `add`; `add` twice gives 12, but an `or`
  -- races with the other threads' `add` (their order changes the word)
  checkWords "atomics, twice" [12] (runText (atomic "add" (after := rmw2 "add")) 3 buf 1) ++
  checkFault "atomics of two operations" "data race"
    (runText (atomic "add" (after := rmw2 "or")) 3 buf 1) ++
  checkFault "atomic i24" "power of two" (runText (atomic "add" "i24 1") 3 buf 1) ++
  -- The two orders of two threads' `atomicrmw add` give the same registers
  (match regsAfter (atomic "add" (after := barCall)) [0, 1],
      regsAfter (atomic "add" (after := barCall)) [1, 0] with
    | .ok rs, .ok rs' =>
      if rs.length == 2 && rs.all (!·.isEmpty) && rs == rs' then #[]
      else #["atomics, both orders: the threads differ"]
    | .error e, _ | _, .error e => #[s!"atomics, both orders: {e}"]) ++
  checkFault "atomic xchg" "two updates do not commute" (runText (atomic "xchg") 3 buf 1) ++
  checkFault "atomic sub" "not in the admitted operations" (runText (atomic "sub") 3 buf 1) ++
  checkFault "float atomic" "float atomicrmw" (runText (atomic "fadd" "float 1.0") 3 buf 1) ++
  checkFault "atomic result used" "result is used"
    (runText (atomic "add" (after := "%8 = add i32 %7, 1\n")) 3 buf 1) ++
  checkFault "invariant load written" "invariant load written"
    (runText "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      store i32 1, ptr addrspace(1) %0, align 4\n\
      %2 = load i32, ptr addrspace(1) %0, align 4, !invariant.load !0\n\
      ret void\n\
    }\n\
    !0 = !{}" 1 buf) ++
  checkFault "invariant load, then a store to its bytes" "invariant load written"
    (runText "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = load i32, ptr addrspace(1) %0, align 4, !invariant.load !0\n\
      store i32 1, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n\
    !0 = !{}" 1 buf) ++
  checkFault "norecurse recursion" "recursion of a norecurse function"
    (runText "define void @f(i32 %0) #0 {\n\
      %2 = icmp eq i32 %0, 0\n\
      br i1 %2, label %3, label %4\n\
    3:\n\
      ret void\n\
    4:\n\
      call void @f(i32 0)\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k() {\n\
      call void @f(i32 1)\n\
      ret void\n\
    }\n\
    attributes #0 = { norecurse }" 1 none) ++
  checkFault "willreturn" "function attribute willreturn"
    (runText "define void @f() #0 {\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k() {\n\
      call void @f()\n\
      ret void\n\
    }\n\
    attributes #0 = { willreturn }" 1 none) ++
  checkFault "nonnull null" "noundef value not defined"
    (runText "define void @f(ptr noundef nonnull %0) {\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k() {\n\
      call void @f(ptr null)\n\
      ret void\n\
    }" 1 none) ++
  (match runText (root "nnan ") 1 buf 1 with
    | .ok [.poison] => #[]
    | _ => #["nnan rsqrt.approx of -1: not poison"]) ++
  (match runText (root "") 1 buf 1 with
    | .ok [.bits _ _] => #[]
    | _ => #["rsqrt.approx of -1: no word"]) ++
  checkFault "nsz fdiv" "fast-math flags nsz" (runText "define ptx_kernel void @k() {\n\
      %1 = fdiv nsz float 1.0, -0.0\n\
      ret void\n\
    }" 1 none) ++
  checkFault "nnan call" "fast-math flags on a call" (runText "define float @g(float %0) {\n\
      ret float %0\n\
    }\n\
    define ptx_kernel void @k() {\n\
      %1 = call nnan float @g(float 1.0)\n\
      ret void\n\
    }" 1 none)

/-- Small kernels for parameter attributes, declarations and globals, each with the fault or the
words it must give. -/
def paramAttrTests : Array String :=
  let none (_ : Val) : List Val := []
  let buf (b : Val) : List Val := [b]
  -- a `<2 x i32>` argument under `noundef range(i32 0, 1)`
  let vrange (v : List Nat) := runText "define ptx_kernel void @k(<2 x i32> noundef \
      range(i32 0, 1) %0) {\n\
      ret void\n\
    }" 1 fun _ => [.vec (v.map fun x => .bits 32 (BitVec.ofNat 32 x))]
  -- the buffer as a pointer parameter with attributes `attrs`, at address `16 * a`
  let ptrAttr (attrs : String) (a : Nat) :=
    runText ("define ptx_kernel void @k(ptr addrspace(1) " ++ attrs ++ " %0) {\n\
      ret void\n\
    }") 1 buf (addr := a)
  -- an `alloca`'s pointer, at address `4 * a`, to `lifetime.start` declared with attributes
  -- `attrs`
  let marker (attrs : String) (a : Nat) :=
    runText ("define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = alloca i32, align 4\n\
      call void @llvm.lifetime.start.p0(ptr %2)\n\
      ret void\n\
    }\n\
    declare void @llvm.lifetime.start.p0(ptr " ++ attrs ++ ")") 1 buf (ch := fun _ => a)
  let shared (g : String) := runText ("@g = " ++ g ++ ", align 4\n\
    define ptx_kernel void @k() {\n\
      store i32 1, ptr addrspace(3) @g, align 4\n\
      ret void\n\
    }") 1 none
  -- `cp.async.wait.group` on operand `x`, whose parameter is `immarg`
  let wait (x : String) := runText ("define ptx_kernel void @k() {\n\
      %1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      call void @llvm.nvvm.cp.async.wait.group(i32 " ++ x ++ ")\n\
      ret void\n\
    }\n\
    declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
    declare void @llvm.nvvm.cp.async.wait.group(i32 immarg)") 1 none
  -- a phi with attachments `md`
  let phi (md : String) := runText ("define ptx_kernel void @k() {\n\
      br label %1\n\
    1:\n\
      %2 = phi i32 [ 0, %0 ]" ++ md ++ "\n\
      ret void\n\
    }\n\
    !0 = !{}") 1 none
  checkFault "vector range" "noundef value not defined" (vrange [0, 2]) ++
  checkWords "vector range (in range)" [] (vrange [0, 0]) ++
  checkFault "nonnull at address 0" "noundef value not defined" (ptrAttr "noundef nonnull" 0) ++
  checkWords "nonnull (control)" [] (ptrAttr "noundef nonnull" 1) ++
  checkFault "align 64 at address 16" "noundef value not defined" (ptrAttr "noundef align 64" 1) ++
  checkWords "align 64 at address 4096" [] (ptrAttr "noundef align 64" 0x100) ++
  checkFault "intrinsic align" "noundef value not defined" (marker "noundef align 64" 4) ++
  checkWords "intrinsic align (control)" [] (marker "noundef align 64" 16) ++
  checkFault "intrinsic dereferenceable" "parameter attribute dereferenceable"
    (marker "dereferenceable(4)" 16) ++
  checkFault "intrinsic function attribute" "function attribute noreturn"
    (runText "define ptx_kernel void @k() {\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      ret void\n\
    }\n\
    declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0\n\
    attributes #0 = { noreturn }" 1 none) ++
  checkFault "immarg" "immarg argument that is not a constant" (wait "%1") ++
  checkWords "immarg (constant)" [] (wait "0") ++
  checkFault "constant shared global" "store to read-only memory"
    (shared "internal addrspace(3) constant i32 undef") ++
  checkWords "shared global (control)" [] (shared "internal addrspace(3) global i32 undef") ++
  checkFault "external constant shared global" "external constant shared global"
    (shared "external addrspace(3) constant i32") ++
  checkFault "phi metadata" "metadata !noundef" (phi ", !noundef !0") ++
  checkWords "phi (control)" [] (phi "")

/-- Small kernels for intrinsic declarations' attributes, each with the fault or the words it must
give. An intrinsic declaration may make only the promises its member keeps (`Intrinsic.effects`);
each refused declaration has a control with the attributes LLVM itself declares (those of the
corpus files), which runs. -/
def intrinsicAttrTests : Array String :=
  let none (_ : Val) : List Val := []
  -- one barrier, declared with attributes `attrs`
  let barrier (attrs : String) := runText ("define ptx_kernel void @k() {\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      ret void\n\
    }\n\
    declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0\n\
    attributes #0 = { " ++ attrs ++ " }") 2 none
  -- a `bfly` shuffle of two lanes, declared with attributes `attrs`
  let shuffle (attrs : String) := runText ("define ptx_kernel void @k() {\n\
      %1 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 0, i32 1, i32 31)\n\
      ret void\n\
    }\n\
    declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #0\n\
    attributes #0 = { " ++ attrs ++ " }") 2 none
  -- `lifetime.start` on the thread's `alloca`, declared with parameter attributes `ps` and
  -- function attributes `attrs`
  let marker (ps attrs : String) := runText ("define ptx_kernel void @k() {\n\
      %1 = alloca i32, align 4\n\
      call void @llvm.lifetime.start.p0(ptr %1)\n\
      ret void\n\
    }\n\
    declare void @llvm.lifetime.start.p0(ptr " ++ ps ++ ") #0\n\
    attributes #0 = { " ++ attrs ++ " }") 1 none
  -- elements `k` and `k + 1` of a `<4 x i32>`, poison past the vector (LangRef,
  -- "llvm.vector.extract"), declared with `attrs`
  let extract (k : Nat) (attrs : String) := runText ("define ptx_kernel void @k() {\n\
      %1 = call <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32> <i32 1, i32 2, i32 3, \
      i32 4>, i64 " ++ toString k ++ ")\n\
      ret void\n\
    }\n\
    declare <2 x i32> @llvm.vector.extract.v2i32.v4i32(<4 x i32>, i64 immarg) #0\n\
    attributes #0 = { " ++ attrs ++ " }") 1 none
  let lifetime := "nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)"
  let pure := "nocallback nofree nosync nounwind speculatable willreturn memory(none)"
  checkFault "nosync barrier" "function attribute nosync" (barrier "convergent nosync") ++
  checkFault "willreturn barrier" "function attribute willreturn"
    (barrier "convergent willreturn") ++
  checkFault "memory(none) barrier" "function attribute memory"
    (barrier "convergent memory(none)") ++
  checkFault "memory(argmem: readwrite) barrier" "function attribute memory"
    (barrier "convergent memory(argmem: readwrite)") ++
  checkFault "barrier without convergent" "declared without convergent" (barrier "nounwind") ++
  checkWords "barrier (control)" [] (barrier "convergent nocallback nounwind") ++
  checkWords "barrier memory(readwrite)" [] (barrier "convergent memory(readwrite)") ++
  checkFault "nosync shuffle" "function attribute nosync" (shuffle "convergent nosync") ++
  checkFault "speculatable shuffle" "function attribute speculatable"
    (shuffle "convergent speculatable") ++
  checkFault "shuffle without convergent" "declared without convergent"
    (shuffle "nocallback nounwind memory(inaccessiblemem: readwrite)") ++
  checkWords "shuffle (control)" []
    (shuffle "convergent nocallback nounwind memory(inaccessiblemem: readwrite)") ++
  checkFault "speculatable lifetime" "function attribute speculatable"
    (marker "captures(none)" (lifetime ++ " speculatable")) ++
  checkFault "lifetime memory(argmem: read)" "function attribute memory"
    (marker "captures(none)" "nocallback nofree nosync nounwind willreturn memory(argmem: read)") ++
  checkFault "lifetime memory(none)" "function attribute memory"
    (marker "captures(none)" "nounwind memory(none)") ++
  checkFault "readonly lifetime" "parameter attribute readonly" (marker "readonly" lifetime) ++
  checkFault "unknown memory location" "memory location kind"
    (marker "captures(none)" "memory(othermem: readwrite)") ++
  checkWords "lifetime (control)" [] (marker "captures(none)" lifetime) ++
  checkFault "nocreateundeforpoison extract" "nocreateundeforpoison result not defined"
    (extract 4 (pure ++ " nocreateundeforpoison")) ++
  checkWords "nocreateundeforpoison extract in range" []
    (extract 2 (pure ++ " nocreateundeforpoison")) ++
  checkWords "extract (control)" [] (extract 4 pure)

/-- Small kernels for the start's check of the caller's memory, each with the fault or the words it
must give. A pointer argument to the number that thread 1's `alloca` takes is refused in both
orders; so is a pointer to a caller's block above `next`, and a load through null when the
caller's memory has a block 0; an `alloca` whose number is in use is refused; the control (a
pointer to the buffer) runs. A caller's block above `next` that nothing names is still there
after the run, and one at the number of the launch's first allocation (the dynamic shared
memory, after the buffer at 1) makes the launch unsupported. -/
def startMemTests : Array String :=
  let blk : Sem.Block :=
    { space := 1, size := 4, live := true, readOnly := false, owner := Owner.all,
      bytes := fun _ => .undef, addr := 0, gaddr := 0 }
  -- two threads each `alloca` and then read the address of their argument; the start memory has
  -- the buffer (block 1) and the dynamic shared memory (block 2), so with `next` 3 thread 1's
  -- `alloca` would take `3 + Nat.pair 1 0 = 5`, the number the argument names
  let dangling (args : Val → List Val) (rev : Bool) (m0 : Mem := {}) (pre : Grid → Grid := id) :=
    runText "define ptx_kernel void @k(ptr %0) {\n\
      %2 = alloca i32, align 4\n\
      %3 = ptrtoint ptr %0 to i64\n\
      ret void\n\
    }\n" 2 args (rev := rev) (m0 := m0) (pre := pre)
  let block0 : Mem := { blocks := fun c => if c = 0 then some blk else Option.none }
  -- `ret void` with the buffer as argument, on a caller's memory with block `b`: block `b` is
  -- still there after the run
  let keep (b : Nat) : Except String (List Val) := do
    let (_, L, _, g, ctx) ← startText "define ptx_kernel void @k(ptr %0) {\n  ret void\n}\n" 2
      (fun p => [p]) (m0 := { blocks := fun c => if c = b then some blk else Option.none })
    let g ← (g.run L ctx 1000 10).mapError err
    if (g.mem.blocks b).isSome then return [] else throw s!"block {b} gone"
  checkFault "pointer argument to a later alloca" "caller memory naming a block from next on"
    (dangling (fun _ => [.ptr ⟨5, 0⟩]) false) ++
  checkFault "pointer argument to a later alloca, reverse order"
    "caller memory naming a block from next on" (dangling (fun _ => [.ptr ⟨5, 0⟩]) true) ++
  checkFault "pointer argument to a block above next" "caller memory naming a block from next on"
    (dangling (fun _ => [.ptr ⟨40, 0⟩]) true
      { blocks := fun c => if c = 40 then some blk else Option.none }) ++
  checkFault "alloca number in use" "alloca number in use"
    (dangling (fun b => [b]) false (pre := fun g => { g with mem := g.mem.set g.mem.next blk })) ++
  checkWords "pointer argument to the buffer (control)" [] (dangling (fun b => [b]) true) ++
  checkWords "caller block above next kept" [] (keep 40) ++
  checkFault "caller block at the launch's first number" "launch block number in use" (keep 2) ++
  checkFault "load through null with a block 0" "caller memory with next 0 or a block 0"
    (runText "define ptx_kernel void @k(ptr %0) {\n\
        %2 = load i32, ptr %0, align 4\n\
        ret void\n\
      }\n" 1 (fun _ => [.ptr ⟨0, 0⟩]) (m0 := block0))

/-- The atomics check (`Stmt.checkAtomic`) on the reduction kernel of the corpus, the only
corpus file with an `atomicrmw` (`%103 = atomicrmw add`, `%103` unused): the file passes, and its
twins with `xchg` for `add` and with `%103` used are refused. -/
def atomicTests : IO (Array String) := do
  let src ← IO.FS.readFile "tests/corpus/reduction/\
    reduction_reduction_sum_kernel_SIMD_DTy6A6AcB6A6AcB_950d42eb4d93545d.nvptx.ll"
  let rmw := "%103 = atomicrmw add ptr %0, i32 %101 seq_cst, align 4\n"
  -- every statement of every function of `text` passes the check
  let checkAll (text : String) : Except String (List Val) := do
    let prog ← importBytes text.toUTF8
    for fn in prog.module.funcs do
      for b in fn.blocks do
        for st in b.stmts do (st.checkAtomic fn).mapError fun e => s!"{repr e}"
    return []
  if (src.splitOn rmw).length != 2 then return #["reduction: its atomicrmw not found"]
  return checkWords "reduction atomics" [] (checkAll src) ++
    checkFault "reduction, xchg" "two updates do not commute"
      (checkAll (src.replace rmw (rmw.replace "add" "xchg"))) ++
    checkFault "reduction, result used" "result is used"
      (checkAll (src.replace rmw (rmw ++ "%t = add i32 %103, 1\n")))

/-- `step_pending` on one launch: kernel text `src` on one block of 2 threads with the buffer as
its argument, each thread in turn stepped until it waits or returns. A step that puts other than
the thread's pending accesses (`Thread.pending`) in front of the trace is a failure. Returns the
number of accesses logged, or a step's fault with the number of accesses it had pending. -/
def pendingSteps (src : String) : Except String (List Val) := do
  let (_, _, _, g, ctx) ← startText src 2 fun b => [b]
  let mut g := g
  let mut n := 0
  for i in [0, 1] do
    for _ in List.range 100 do
      let some (Status.run t) := g.threads[i]? | break
      let P := t.pending (ctx i) g.mem
      match g.advance ctx i with
      | .error e => throw s!"{P.length} pending; {err e}"
      | .ok none => break
      | .ok (some g') =>
        if g'.mem.trace != P ++ g.mem.trace then
          throw "a step logged other than its pending accesses"
        n := n + P.length
        g := g'
  return [.bits 32 (BitVec.ofNat 32 n)]

/-- `step_pending` on two small kernels: two stores, a load and an `atomicrmw add` in each of 2
threads log 10 accesses, each step its pending ones; a load through null has 1 pending and
faults. -/
def pendingTests : Array String :=
  let tid := "declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n"
  checkWords "pending accesses" [10]
    (pendingSteps ("define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
        %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
        %3 = getelementptr inbounds i32, ptr addrspace(1) %0, i32 %2\n\
        %4 = getelementptr inbounds i32, ptr addrspace(1) %0, i32 2\n\
        store i32 %2, ptr addrspace(1) %3, align 4\n\
        store i32 0, ptr addrspace(1) %4, align 4\n\
        %5 = load i32, ptr addrspace(1) %3, align 4\n\
        %6 = atomicrmw add ptr addrspace(1) %4, i32 %5 seq_cst, align 4\n\
        ret void\n\
      }\n" ++ tid)) ++
  checkFault "pending access of a faulting load"
    "1 pending; MojoProof.Sem.Fault.ub \"access to no block"
    (pendingSteps "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
        %2 = load i32, ptr addrspace(1) null, align 4\n\
        ret void\n\
      }\n")

/-- Small kernels for `nocreateundeforpoison` and `memory` items. `maxnum(+∞, 1)` declared
`nocreateundeforpoison` and called with `ninf` gives the defined `+∞`, which the call's `ninf`
makes poison: the buffer holds poison, and the run is not undefined behavior; without `ninf` the
buffer holds `+∞`. A `memory` item with an unknown access
kind is unsupported also at a location the check does not query (`inaccessiblemem` on a pure
intrinsic); its control, with `none` there, runs. -/
def callAttrTests : Array String :=
  let lead := "nocallback nofree nosync nounwind speculatable willreturn"
  -- `maxnum(+∞, 1)` with call flags `fm`, declared with attributes `attrs`, stored in the buffer
  let maxnum (fm attrs : String) := runText ("define ptx_kernel void @k(ptr %0) {
      %2 = call " ++ fm ++ "float @llvm.maxnum.f32(float 0x7FF0000000000000, float 1.0)
      store float %2, ptr %0, align 4
      ret void
    }
    declare float @llvm.maxnum.f32(float, float) #0
    attributes #0 = { " ++ attrs ++ " }") 1 (fun b => [b]) 1 (ty := .fp .float)
  let pure := lead ++ " nocreateundeforpoison memory(none)"
  (match maxnum "ninf " pure with
    | .ok [.poison] => #[]
    | r => #[s!"ninf maxnum, nocreateundeforpoison: not poison, \
        {repr (r.map (·.map Val.word?))}"]) ++
  checkWords "maxnum, nocreateundeforpoison (control)" [0x7f800000] (maxnum "" pure) ++
  checkFault "memory access kind at an unqueried location" "memory access kind bogus"
    (maxnum "" (lead ++ " memory(argmem: none, inaccessiblemem: bogus)")) ++
  checkWords "memory item at an unqueried location (control)" [0x7f800000]
    (maxnum "" (lead ++ " memory(argmem: none, inaccessiblemem: none)"))

/-- Small kernels and two corpus files for the launch (`Grid.start`). A `byval` copy declared
`noundef nonnull` (as Mojo's are) has a nonzero address (`place`) at the address choices
0, 1, 7 and `2 ^ 62`: 4, 4, 28 and 4; a plain `noundef nonnull` parameter given null is undefined
behavior. The launch limits (`Func.checkLaunch`): gevm_t512's kernel (`"nvvm.maxntid"="512"`)
starts on a block of 512 threads and not of 513, gemv's gevm_kernel (`"1024"`) on 1024 (the launch
of its theorem, MojoProofTest/GevmSound.lean) and not on 1025, and a kernel with
`"nvvm.reqntid"="2,1,1"` on 2 threads and not on 1. Their legacy form, `!nvvm.annotations`
(`Func.annots`): `reqntidx 32` starts on 32 threads and not on 64, `maxntidx 64` on 64 and not on
65, `kernel` alone starts, `maxnreg` is unsupported, and so is `"nvvm.maxntid"="64"` with
`maxntidx 32`. A `byval` copy of `[0 x i64]` aligned to 256 bytes (`e-p:8:8-i64:2048`) is
unsupported: no aligned address below `2 ^ 8` is nonzero (`Func.byvalPlaced`, TRUST T11); aligned
to 128 bytes (`i64:1024`) it is at address 128 at the choice 3. With 8-bit pointers
(`e-p:8:8`): a copy of `[2 x i8]` at the choice 255, whose end 257 would wrap, is at address 1
(the lowest placed one), and at the choice 7 at 7; a copy of `[128 x i8]` is unsupported (its size
is above 127, the largest signed 8-bit index: LangRef, "Allocated Objects"), and one of
`[127 x i8]` is at its choice 3. A `byval` copy of `{i8, i32}` (three padding bytes, which
LangRef's byte copy would keep) is unsupported (`Layout.dense`, TRUST T11), and its twin
`{i32, i32}` gives its byte 1. An `!nvvm.annotations` value of type `i64` is unsupported
(`Func.annots`: only `i32` values). `"target-cpu"` is admitted
and `"denormal-fp-math"` is unsupported. A kernel with an unused second parameter runs on two
arguments and is unsupported on one and on three. -/
def launchTests : IO (Array String) := do
  let t512 ← IO.FS.readFile "tests/corpus/gevm_t512/\
    gevm_f32_t512_gevm_kernel_float32_float32_float32_512_7a789db0.nvptx.ll"
  let g1024 ← IO.FS.readFile "tests/corpus/gemv/\
    gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll"
  let six (b : Val) : List Val := [b, b, b, .bits 32 0, .bits 32 0, .bits 32 0]
  let started (r : Except String (Layout × Launch × Nat × Grid × (Nat → Ctx))) :
      Except String (List Val) := r.map fun _ => []
  let byval := "define ptx_kernel void @k(ptr addrspace(1) %0, \
      ptr noundef nonnull readonly byval(i32) %1) {\n\
      %3 = ptrtoint ptr %1 to i64\n\
      store i64 %3, ptr addrspace(1) %0, align 8\n\
      ret void\n\
    }\n"
  let attrs (a : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) #0 {\n\
      ret void\n\
    }\n\
    attributes #0 = { " ++ a ++ " }\n"
  let reqntid := attrs "\"nvvm.reqntid\"=\"2,1,1\""
  let unused := "define ptx_kernel void @k(ptr addrspace(1) %0, i32 %1) {\n\
      store i32 4, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n"
  -- a kernel with the `!nvvm.annotations` entry `!{ptr @k, !"k", i32 v}` and attributes `a`
  let ann (a k : String) (v : Nat) := (if a.isEmpty then "define ptx_kernel void \
      @k(ptr addrspace(1) %0) {\n\
      ret void\n\
    }\n" else attrs a) ++ "!nvvm.annotations = !{!0}\n\
    !0 = !{ptr @k, !\"" ++ k ++ "\", i32 " ++ toString v ++ "}\n"
  -- a `byval` copy of type `t` with 8-bit pointers, storing its address
  let byval8 (t : String) := "target datalayout = \"e-p:8:8\"\n\
    define ptx_kernel void @k(ptr addrspace(1) %0, ptr noundef nonnull byval(" ++ t ++ ") %1) {\n\
      %3 = ptrtoint ptr %1 to i8\n\
      store i8 %3, ptr addrspace(1) %0, align 1\n\
      ret void\n\
    }\n"
  -- a `byval` copy of type `t` whose byte 1 the kernel copies out
  let byte1 (t : String) := "define ptx_kernel void @k(ptr addrspace(1) %0, \
      ptr noundef nonnull byval(" ++ t ++ ") %1) {\n\
      %3 = getelementptr i8, ptr %1, i64 1\n\
      %4 = load i8, ptr %3, align 1\n\
      store i8 %4, ptr addrspace(1) %0, align 1\n\
      ret void\n\
    }\n"
  let zeros (n : Nat) : Val := .agg (List.replicate n (.bits 8 0))
  -- a `byval` copy of no bytes aligned to `al` bits with 8-bit pointers, its element a vector of
  -- `al` bits (no padding): at 2048 every aligned address is 0
  let byval0 (al : String) := "target datalayout = \"e-p:8:8-v" ++ al ++ ":" ++ al ++ "\"\n\
    define ptx_kernel void @k(ptr addrspace(1) %0, ptr noundef nonnull byval([0 x <" ++
      toString (al.toNat! / 8) ++ " x i8>]) %1) {\n\
      %3 = ptrtoint ptr %1 to i8\n\
      store i8 %3, ptr addrspace(1) %0, align 1\n\
      ret void\n\
    }\n"
  return [(0, 4), (1, 4), (7, 28), (2 ^ 62, 4)].foldl (fun acc (c, w) => acc ++
      checkWords s!"byval noundef nonnull at choice {c}" [w]
        (runText byval 1 (fun b => [b, .bits 32 5]) 1 (ty := .int 64) (ch := fun _ => c)))
      #[] ++
    checkFault "noundef nonnull null parameter" "noundef value not defined"
      (runText "define ptx_kernel void @k(ptr addrspace(1) %0, ptr noundef nonnull %1) {\n\
          ret void\n\
        }\n" 1 (fun b => [b, .ptr ⟨0, 0⟩])) ++
    checkWords "gevm_t512 at 512" [] (started (startText t512 512 six)) ++
    checkFault "gevm_t512 at 513" "beyond nvvm.maxntid 512" (started (startText t512 513 six)) ++
    checkWords "gevm_kernel at 1024" [] (started (startText g1024 1024 six)) ++
    checkFault "gevm_kernel at 1025" "beyond nvvm.maxntid 1024"
      (started (startText g1024 1025 six)) ++
    checkWords "nvvm.reqntid at its shape" [] (runText reqntid 2 fun b => [b]) ++
    checkFault "nvvm.reqntid at another shape" "another shape than nvvm.reqntid"
      (runText reqntid 1 fun b => [b]) ++
    checkWords "reqntidx 32 annotation at 32" [] (runText (ann "" "reqntidx" 32) 32 fun b => [b]) ++
    checkFault "reqntidx 32 annotation at 64" "another shape than nvvm.reqntid"
      (runText (ann "" "reqntidx" 32) 64 fun b => [b]) ++
    checkWords "maxntidx 64 annotation at 64" [] (runText (ann "" "maxntidx" 64) 64 fun b => [b]) ++
    checkFault "maxntidx 64 annotation at 65" "beyond nvvm.maxntid 64"
      (runText (ann "" "maxntidx" 64) 65 fun b => [b]) ++
    checkWords "kernel annotation" [] (runText (ann "" "kernel" 1) 7 fun b => [b]) ++
    checkFault "maxnreg annotation" "nvvm.annotations key maxnreg"
      (runText (ann "" "maxnreg" 32) 7 fun b => [b]) ++
    checkFault "maxntid attribute and annotation that disagree" "that disagree"
      (runText (ann "\"nvvm.maxntid\"=\"64\"" "maxntidx" 32) 7 fun b => [b]) ++
    checkFault "byval of alignment 2 ^ 8 at 8-bit pointers (TRUST T11)"
      "no nonzero aligned address" (runText (byval0 "2048") 1 (fun b => [b, .agg []]) 1
        (addr := 1) (ty := .int 8) (ch := fun _ => 3)) ++
    checkWords "byval of alignment 2 ^ 7 at 8-bit pointers: address 128" [128]
      (runText (byval0 "1024") 1 (fun b => [b, .agg []]) 1 (addr := 1) (ty := .int 8)
        (ch := fun _ => 3)) ++
    checkWords "byval of 2 bytes at 8-bit pointers, choice 255: address 1" [1]
      (runText (byval8 "[2 x i8]") 1 (fun b => [b, zeros 2]) 1 (ty := .int 8)
        (ch := fun _ => 255)) ++
    checkWords "byval of 2 bytes at 8-bit pointers, choice 7: address 7" [7]
      (runText (byval8 "[2 x i8]") 1 (fun b => [b, zeros 2]) 1 (ty := .int 8)
        (ch := fun _ => 7)) ++
    checkFault "byval of 128 bytes at 8-bit pointers" "no nonzero aligned address"
      (runText (byval8 "[128 x i8]") 1 (fun b => [b, zeros 128]) 1 (ty := .int 8)) ++
    checkWords "byval of 127 bytes at 8-bit pointers, choice 3: address 3" [3]
      (runText (byval8 "[127 x i8]") 1 (fun b => [b, zeros 127]) 1 (ty := .int 8)
        (ch := fun _ => 3)) ++
    checkFault "byval of a type with padding" "padding"
      (runText (byte1 "{ i8, i32 }") 1 (fun b => [b, .agg [.bits 8 1, .bits 32 2]]) 1
        (ty := .int 8)) ++
    checkWords "byval of a type without padding: byte 1" [2]
      (runText (byte1 "{ i32, i32 }") 1 (fun b => [b, .agg [.bits 32 0x0201, .bits 32 2]]) 1
        (ty := .int 8)) ++
    checkFault "reqntidx annotation of type i64" "of another form"
      (runText ("define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
          ret void\n\
        }\n\
        !nvvm.annotations = !{!0}\n\
        !0 = !{ptr @k, !\"reqntidx\", i64 32}\n") 32 fun b => [b]) ++
    checkWords "target-cpu" [] (runText (attrs "\"target-cpu\"=\"sm_80\"") 1 fun b => [b]) ++
    checkFault "denormal-fp-math" "function attribute denormal-fp-math"
      (runText (attrs "\"denormal-fp-math\"=\"ieee\"") 1 fun b => [b]) ++
    checkWords "arguments for each parameter" [4] (runText unused 1 (fun b => [b, .bits 32 0]) 1) ++
    checkFault "an argument missing" "has 2 parameters, launched on 1 arguments"
      (runText unused 1 fun b => [b]) ++
    checkFault "an argument extra" "has 2 parameters, launched on 3 arguments"
      (runText unused 1 fun b => [b, .bits 32 0, .bits 32 1])

/-- Small kernels for accesses, each with a twin. Grid dependency control's
`llvm.nvvm.griddepcontrol.wait` and `llvm.nvvm.griddepcontrol.launch.dependents` do nothing (TRUST
T19); an unknown `griddepcontrol` name is unsupported, and so is `griddepcontrol.wait` in a kernel
whose `"target-cpu"` is "sm_80" (`Func.check`: the instruction requires "sm_90"); at "sm_90a" it
runs. A helper `@h` with no `"target-cpu"` calling `griddepcontrol.wait` is unsupported from an
"sm_80" entry, from an entry with no `"target-cpu"` and from an "sm_90" entry in a module with an
"sm_80" function too (`Func.griddepBad`: the helper has the module's target, the one value its
functions agree on), and runs from an "sm_90" entry, at the launch and at the call. A `volatile`
load, store and `atomicrmw` are unsupported (`Stmt.checkMd`); without `volatile` each runs. A load
from an `alloca` after `lifetime.end` or
before `lifetime.start` is unsupported (LangRef, "Object Lifetime": poison, which the semantics does
not give to a load), and a store after `lifetime.end` is undefined behavior (`Mem.check`: the block
is dead); in the lifetime the load gives the stored word. A lifetime marker on a `getelementptr` of
an `alloca` or on a pointer a callee returned is unsupported (`Func.lifetimeOk`), one on poison does
nothing. A load through the pointer a callee returned to its `alloca` is undefined behavior (the
frame's blocks are dead after `ret`); the same load in the callee, before its `ret`, gives the
stored word. `getelementptr nuw` (unsigned offsets): index -1 into the zero-size `[0 x i8]`, at
`i64` and at `i32`, is the base pointer; `i8` at -1 (the address wraps) and `i32` at `2 ^ 62` (the
product wraps) are poison, so the store through them is undefined behavior; `i8` at 4 stores at byte
4. A struct of 128 fields of size zero and an `i32`, at an 8-bit index width (`e-p:8:8`): `i32 128`
selects the `i32` at offset 0 (the field by its own value, LangRef `getelementptr`), and `i32 129`
is beyond the struct, unsupported. An `f0x` literal has exactly its type's hexadecimal digits
(LangRef, "Simple Constants"): `double f0x3f800000` is unsupported (the parser's `litFits`), `double
f0x3FF0000000000000`, `float f0x3f800000` and `float f0x7fc00001` (a quiet NaN with payload 1) store
their bits. A struct index is a constant `i32` (LangRef, `getelementptr`): `i64 1` and `i32 %f` into
`{i32, i32}` are unsupported (the parser's `gepStructOk`), and `i32 1` stores 11 to word 1; the
semantics refuses a struct index of another type too (`gepSteps` at `(1, none)`), and steps `i32 1`
to field 1 at offset 4. -/
def accessTests : Array String :=
  let buf (b : Val) : List Val := [b]
  let kernel (body decls : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) {\n" ++
    body ++ "  ret void\n}\n" ++ decls
  -- a kernel calling `griddepcontrol.wait` with the `"target-cpu"` `cpu`
  let griddepAt (cpu : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) #0 {\n\
      call void @llvm.nvvm.griddepcontrol.wait()\n\
      store i32 3, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n\
    declare void @llvm.nvvm.griddepcontrol.wait()\n\
    attributes #0 = { \"target-cpu\"=\"" ++ cpu ++ "\" }\n"
  let griddep (wait : String) := "define ptx_kernel void @k(ptr addrspace(1) %0) #0 {\n\
      call void @llvm.nvvm.griddepcontrol." ++ wait ++ "()\n\
      call void @llvm.nvvm.griddepcontrol.launch.dependents()\n\
      store i32 3, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n\
    declare void @llvm.nvvm.griddepcontrol." ++ wait ++ "()\n\
    declare void @llvm.nvvm.griddepcontrol.launch.dependents()\n\
    attributes #0 = { \"target-cpu\"=\"sm_90a\" }\n"
  -- an entry with the `"target-cpu"` `cpu` (none: no attribute) calling a helper `@h` that has
  -- none and calls `griddepcontrol.wait`
  let helperAt (cpu : Option String) := "define void @h() {\n\
      call void @llvm.nvvm.griddepcontrol.wait()\n\
      ret void\n\
    }\n\
    define ptx_kernel void @k(ptr addrspace(1) %0)" ++ (if cpu.isSome then " #0" else "") ++ " {\n\
      call void @h()\n\
      store i32 3, ptr addrspace(1) %0, align 4\n\
      ret void\n\
    }\n\
    declare void @llvm.nvvm.griddepcontrol.wait()\n" ++ (match cpu with
      | some c => "attributes #0 = { \"target-cpu\"=\"" ++ c ++ "\" }\n"
      | none => "")
  -- the same at "sm_90", with `@z` at "sm_80" beside it: the module's target is ambiguous
  let helperMixed := helperAt (some "sm_90") ++ "define void @z() #1 {\n\
      ret void\n\
    }\n\
    attributes #1 = { \"target-cpu\"=\"sm_80\" }\n"
  let vol (v : String) := [
    ("load", "  %2 = load " ++ v ++ "i32, ptr addrspace(1) %0, align 4\n\
        store i32 5, ptr addrspace(1) %0, align 4\n", 5),
    ("store", "  store " ++ v ++ "i32 6, ptr addrspace(1) %0, align 4\n", 6),
    ("atomicrmw", "  store i32 0, ptr addrspace(1) %0, align 4\n\
        %2 = atomicrmw " ++ v ++ "add ptr addrspace(1) %0, i32 1 seq_cst, align 4\n", 1)]
  let decls := "declare void @llvm.lifetime.start.p0(ptr captures(none))\n\
    declare void @llvm.lifetime.end.p0(ptr captures(none))\n"
  let life (body : String) := kernel ("  %2 = alloca i32, align 4\n\
      call void @llvm.lifetime.start.p0(ptr %2)\n\
      store i32 7, ptr %2, align 4\n" ++ body) decls
  -- a callee `@f` with an `alloca` holding 5 that returns `ret` (`load` the word first if `w`)
  let callee (w : Bool) := if w then "define i32 @f() {\n\
        %1 = alloca i32, align 4\n\
        store i32 5, ptr %1, align 4\n\
        %2 = load i32, ptr %1, align 4\n\
        ret i32 %2\n\
      }\n"
    else "define ptr @f() {\n\
        %1 = alloca i32, align 4\n\
        store i32 5, ptr %1, align 4\n\
        ret ptr %1\n\
      }\n"
  -- a struct of `n` fields of size zero and an `i32`, at an 8-bit index width, field `k`
  let fields (n k : Nat) := "target datalayout = \"e-p:8:8\"\n" ++
    kernel ("  %2 = getelementptr {" ++
      String.intercalate ", " (List.replicate n "[0 x i8]" ++ ["i32"]) ++
      "}, ptr addrspace(1) %0, i32 0, i32 " ++ toString k ++ "\n\
      store i32 11, ptr addrspace(1) %2, align 4\n") ""
  let dead := "  call void @llvm.lifetime.end.p0(ptr %2)\n"
  let copy := "  %3 = load i32, ptr %2, align 4\n  store i32 %3, ptr addrspace(1) %0, align 4\n"
  let gep (g : String) := kernel ("  %2 = getelementptr nuw " ++ g ++ "\n\
      store i32 10, ptr addrspace(1) %2, align 4\n") ""
  -- a store of the literal `v` of float type `t`
  let lit (t v : String) := kernel ("  store " ++ t ++ " " ++ v ++ ", ptr addrspace(1) %0\n") ""
  -- a store of 11 to field `idx` of `{i32, i32}` (`%f` is 1)
  let sgep (idx : String) := kernel ("  %f = add i32 1, 0\n\
      %2 = getelementptr { i32, i32 }, ptr addrspace(1) %0, i32 0, " ++ idx ++ "\n\
      store i32 11, ptr addrspace(1) %2, align 4\n") ""
  checkWords "griddepcontrol" [3] (runText (griddep "wait") 1 buf 1) ++
  checkFault "griddepcontrol, unknown name" "unsupported intrinsic"
    (runText (griddep "wait.all") 1 buf 1) ++
  checkFault "griddepcontrol at sm_80" "is not sm_90 or higher"
    (runText (griddepAt "sm_80") 1 buf 1) ++
  checkWords "griddepcontrol at sm_90a" [3] (runText (griddepAt "sm_90a") 1 buf 1) ++
  checkFault "griddepcontrol in a helper of an sm_80 entry" "griddepcontrol in @h"
    (runText (helperAt (some "sm_80")) 1 buf 1) ++
  checkWords "griddepcontrol in a helper of an sm_90 entry" [3]
    (runText (helperAt (some "sm_90")) 1 buf 1) ++
  checkFault "griddepcontrol with no target-cpu" "griddepcontrol in @h"
    (runText (helperAt none) 1 buf 1) ++
  checkFault "griddepcontrol in a helper, two module targets" "griddepcontrol in @h"
    (runText helperMixed 1 buf 1) ++
  (vol "volatile ").foldl (fun acc (k, body, _) => acc ++
    checkFault s!"volatile {k}" "volatile access" (runText (kernel body "") 1 buf 1)) #[] ++
  (vol "").foldl (fun acc (k, body, w) => acc ++
    checkWords s!"{k}, not volatile" [w] (runText (kernel body "") 1 buf 1)) #[] ++
  checkWords "load in the lifetime" [7] (runText (life copy) 1 buf 1) ++
  checkFault "load after lifetime.end" "load from an alloca outside its lifetime"
    (runText (life (dead ++ copy)) 1 buf) ++
  checkFault "load before lifetime.start" "load from an alloca outside its lifetime"
    (runText (kernel ("  %2 = alloca i32, align 4\n" ++ copy ++
      "  call void @llvm.lifetime.start.p0(ptr %2)\n") decls) 1 buf) ++
  checkFault "lifetime marker on a getelementptr" "on a value no alloca defines"
    (runText (kernel ("  %2 = alloca [2 x i32], align 4\n\
        %3 = getelementptr [2 x i32], ptr %2, i64 0, i64 1\n\
        store i32 7, ptr %2, align 4\n\
        call void @llvm.lifetime.end.p0(ptr %3)\n") decls) 1 buf) ++
  checkFault "lifetime marker on a returned pointer" "on a value no alloca defines"
    (runText (callee false ++ kernel ("  %2 = call ptr @f()\n\
        call void @llvm.lifetime.start.p0(ptr %2)\n\
        store i32 7, ptr %2, align 4\n" ++ copy) decls) 1 buf) ++
  checkWords "lifetime marker on poison" [8]
    (runText (kernel "  call void @llvm.lifetime.start.p0(ptr poison)\n\
        store i32 8, ptr addrspace(1) %0, align 4\n" decls) 1 buf 1) ++
  checkFault "load from a returned frame" "access to a dead block"
    (runText (callee false ++ kernel ("  %2 = call ptr @f()\n" ++ copy) "") 1 buf) ++
  checkWords "load before the return" [5]
    (runText (callee true ++ kernel "  %2 = call i32 @f()\n\
        store i32 %2, ptr addrspace(1) %0, align 4\n" "") 1 buf 1) ++
  checkWords "store in the lifetime" [9]
    (runText (life ("  store i32 9, ptr %2, align 4\n" ++ copy)) 1 buf 1) ++
  checkFault "store after lifetime.end" "access to a dead block"
    (runText (life (dead ++ "  store i32 9, ptr %2, align 4\n")) 1 buf) ++
  checkWords "nuw, zero-size type, i64 -1" [10]
    (runText (gep "[0 x i8], ptr addrspace(1) %0, i64 -1") 1 buf 1) ++
  checkWords "nuw, zero-size type, i32 -1" [10]
    (runText (gep "[0 x i8], ptr addrspace(1) %0, i32 -1") 1 buf 1) ++
  checkFault "nuw, i8 -1" "memory access through poison"
    (runText (gep "i8, ptr addrspace(1) %0, i64 -1") 1 buf) ++
  checkFault "nuw, i32 2^62" "memory access through poison"
    (runText (gep "i32, ptr addrspace(1) %0, i64 4611686018427387904") 1 buf) ++
  (match runText (gep "i8, ptr addrspace(1) %0, i64 4") 1 buf 2 with
    | .ok [_, v] => if v.word? == some 10 then #[] else #["nuw, i8 4: wrong word"]
    | .ok _ => #["nuw, i8 4: not two values"]
    | .error e => #[s!"nuw, i8 4: {e}"]) ++
  checkWords "struct field 128 at an 8-bit index width" [11]
    (runText (fields 128 128) 1 buf 1 (addr := 1)) ++
  checkFault "struct field beyond the struct" "struct index out of range"
    (runText (fields 128 129) 1 buf (addr := 1)) ++
  checkFault "f0x literal of float's size at double" "f0x float literal with another size"
    (runText (lit "double" "f0x3f800000") 1 buf 1 (ty := .int 64)) ++
  checkWords "f0x literal of double's size at double" [0x3FF0000000000000]
    (runText (lit "double" "f0x3FF0000000000000") 1 buf 1 (ty := .int 64)) ++
  checkWords "f0x NaN with a payload at float" [0x7FC00001]
    (runText (lit "float" "f0x7fc00001") 1 buf 1) ++
  checkWords "f0x literal of float's size at float" [0x3f800000]
    (runText (lit "float" "f0x3f800000") 1 buf 1) ++
  checkFault "struct index i64 1" "struct index other than an i32 constant"
    (runText (sgep "i64 1") 1 buf 2) ++
  checkFault "struct index i32 %f" "struct index other than an i32 constant"
    (runText (sgep "i32 %f") 1 buf 2) ++
  (match runText (sgep "i32 1") 1 buf 2 with
    | .ok [_, v] => if v.word? == some 11 then #[] else #["struct index i32 1: wrong word"]
    | .ok _ => #["struct index i32 1: not two values"]
    | .error e => #[s!"struct index i32 1: {e}"]) ++
  (match gepSteps {} id (.struct [.int 32, .int 32]) [(0, some 0), (1, none)] with
    | .error (.unsupported "struct index not of type i32") => #[]
    | _ => #["struct index of another type than i32 in the semantics: not refused"]) ++
  (match gepSteps {} id (.struct [.int 32, .int 32]) [(0, some 0), (1, some 1)] with
    | .ok [_, (1, 4, true)] => #[]
    | _ => #["struct index i32 1 in the semantics: not field 1 at offset 4"])

/-- **`bitcast <4 x i8>` to `i32` puts lane 0 low**, a test of `castV_join` at a second size
(`castV_halves` is its instance at `<2 x i32>`): for every layout, memory and oracle numbers, the
`bitcast` of the bytes `[1, 2, 3, 4]` to `i32` is the word `0x04030201`. -/
theorem castV_bytes4 (l : Layout) (m : Mem) (ch : Nat → Nat) :
    castV l m .bitcast (.vec 4 (.int 8)) (.vec [.bits 8 1#8, .bits 8 2#8, .bits 8 3#8, .bits 8 4#8])
      (.int 32) ch = .ok (.bits 32 0x04030201#32) :=
  (castV_join l m ch (n := 4) (w := 8) 0x04030201#32).trans rfl

/-- The evaluator tests, on the imported programs of `MojoProof.Kernels`; returns the failures. -/
def evalTests : IO (Array String) := do
  let fails := vaddTests Kernels.vadd.prog ++ matmulTests Kernels.matmul.prog
  IO.println "evaluator: vector_addition (2 oracles, written tiles and their twin, 2 faults), \
    tiled_matmul (2 oracles, the full launch and one block race-checked), rsqrt, 3 oracle \
    counterexamples, 147 small kernels, 2 index steps, 2 corpus starts, the reduction's atomic \
    and 2 twins"
  return fails ++ rsqrtTests ++ oracleTests ++ textTests ++ paramAttrTests ++ intrinsicAttrTests ++
    startMemTests ++ callAttrTests ++ pendingTests ++ (← atomicTests) ++ (← launchTests) ++
    accessTests

end MojoProofTest
