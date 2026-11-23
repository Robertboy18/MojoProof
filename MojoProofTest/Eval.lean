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
  for `racy` (`fast_sound`); on every small kernel's trace `fast` and `racy` agree.
* 5 small kernels for the promises of TRUST T12: a write to the bytes of an `!invariant.load`,
  before or after it, breaks it (`Grid.Kept`); after it, the run has no fault and no race, so
  `kept` is a separate obligation from safety and race freedom; a `norecurse` function that
  calls itself is undefined behavior;
  `willreturn` on a defined function is unsupported; a null argument for a `nonnull noundef`
  parameter is poison, so undefined behavior. Every run of a small kernel and of
  `vector_addition` (whose two loads have `!invariant.load`) is checked to keep the promise.
* 17 small kernels for parameter attributes, declarations and globals (`paramAttrTests`), each
  fault with a control that
  differs only in the construct and runs: `range` on a `<2 x i32>` parameter applies to each
  element; `nonnull` at address 0 and `align 64` at address 16 make a `noundef` parameter
  poison, as does an intrinsic declaration's `align 64`; a declaration's `dereferenceable` and
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
* 6 small kernels and a corpus file for the atomics the semantics admits
  (`Stmt.checkAtomic`): `atomicrmw xchg`, `atomicrmw sub`, `atomicrmw fadd`, an
  `atomicrmw` on `i24` and an `atomicrmw add` whose result is used are unsupported; two threads that run their
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

These run the evaluator on two corpus kernels and 93 small ones, check a third corpus file, and
the contract on fixed operands; they prove nothing.
-/

namespace MojoProofTest

open MojoProof MojoProof.LLVM MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange

/-- Test input `i` of buffer `seed`: small multiples of 1/4 and spread-out bit patterns. -/
def input (seed i : Nat) : Model FloatFormat.binary32 :=
  if i % 3 = 0 then Model.ofRat .binary32 ((i : Rat) / 4 - seed)
  else Model.ofNatBits ((i * 2654435761 + seed * 40503) % 2 ^ 32)

/-- The value of a buffer argument of type `t`: pointer `p` in its pointer fields, empty
structures elsewhere. -/
def bufArg (p : Ptr) : Ty → Val
  | .ptr _ => .ptr p
  | .struct fs => .agg (fs.map (bufArg p))
  | _ => .agg []

/-- A launch of `x` × `y` blocks of `bx` × `by'` threads. -/
def launch2 (x y bx by' : Nat) : Launch where
  grid := fun | .x => x | .y => y | .z => 1
  block := fun | .x => bx | .y => by' | .z => 1

/-- **`launch2 x y bx by'` is valid** (`Launch.Valid`), for all four sides with every side
positive, `x < 2 ^ 31`, `y ≤ 65535` and `bx * by' ≤ 1024` (so `bx`, `by' ≤ 1024`); the premise
is decidable, so `by decide` proves it at numerals. -/
theorem launch2_valid {x y bx by' : Nat}
    (h : 0 < x ∧ 0 < y ∧ 0 < bx ∧ 0 < by' ∧ x < 2 ^ 31 ∧ y ≤ 65535 ∧ bx * by' ≤ 1024) :
    (launch2 x y bx by').Valid := by
  obtain ⟨hx, hy, hbx, hby, hx', hy', ht⟩ := h
  have hbx' : bx ≤ 1024 := (Nat.le_mul_of_pos_right bx hby).trans ht
  have hby' : by' ≤ 1024 := (Nat.le_mul_of_pos_left by' hbx).trans ht
  refine ⟨fun d => ?_, fun d => ?_, fun d => ?_, fun d => ?_, ?_⟩
  all_goals first
    | (cases d <;> simp only [launch2, Launch.maxGrid, Launch.maxBlock] <;> omega)
    | (simp only [launch2, volume]; omega)

/-- `v` is the float `r`, bit for bit, or some NaN if `r` is a NaN. -/
def isF32 (r : Model FloatFormat.binary32) (v : Val) : Bool :=
  match v.float? .float with
  | some x => if r.isNaN then x.isNaN else x.toNatBits == r.toNatBits
  | none => false

/-- A fault as a failure message. -/
def err (e : Fault) : String := s!"{repr e}"

/-- Launch the kernel of `prog` with `L`, buffers `ins` of floats, then an output buffer of
`out` floats, then the scalar arguments `extra`; thread `n` gets oracle `oracle n`. Each input
buffer is the block `Mem.holds_alloc` proves holds its tensor (`tensorBytes`, row-major). Returns
the output buffer's values; with `race`, a data race in the run's trace (`fast`, which finds every
race of `racy`) or a write to the bytes of an `!invariant.load` (`kept`) is a failure. With
`tiles := some r`, the final output block must meet the premises of `Block.holds_of_tiles`
row-major from 0, with `f i` the float decoded at tile `i`, and each `f i` must be `r i`
(`isF32`): a tile `i` that fails is reported as `tile i`. -/
def runF32 (prog : Program) (L : Launch) (oracle : Nat → Nat → Nat)
    (ins : List (List (Model FloatFormat.binary32))) (out : Nat) (extra : List Val)
    (race := false) (tiles : Option (Nat → Model FloatFormat.binary32) := none) :
    Except String (List Val) := do
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
  let tys := fn.params.map fun p => (p.attrs.findSome? fun | .ty "byval" t => some t | _ => none)
  let args := ((bufs ++ [c]).zip tys).map (fun (b, t) => bufArg ⟨b, 0⟩ (t.getD (.ptr 0))) ++ extra
  let (g, ctx) ← (Grid.start prog fn L args m (oracle 0) oracle).mapError err
  let g ← (g.run L ctx 100000 100).mapError err
  if race && fast g.mem.trace then throw "data race"
  if race && !kept g.mem.trace then throw "invariant load written"
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

/-- The `vector_addition` tests on program `prog`; returns the failures. -/
def vaddTests (prog : Program) : Array String :=
  let ins := [(List.range 100).map (input 1), (List.range 100).map (input 2)]
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
allocated in memory `m0`: the layout, the launch, the buffer's block, the grid and the contexts. -/
def startText (src : String) (threads : Nat) (args : Val → List Val) (blocks := 1)
    (addr := 0x100) (ch : Nat → Nat := fun _ => 0) (oracle : Nat → Nat → Nat := fun _ _ => 0)
    (m0 : Mem := {}) : Except String (Layout × Launch × Nat × Grid × (Nat → Ctx)) := do
  let prog ← importBytes src.toUTF8
  let some fn := prog.module.funcs.find? (some ·.name == prog.kernels.head?)
    | throw "no kernel"
  let (m, c) := m0.alloc prog.layout 1 64 16 true false .all addr addr
  let L := launch2 blocks 1 threads 1
  let (g, ctx) ← (Grid.start prog fn L (args (.ptr ⟨c, 0⟩)) m ch oracle).mapError err
  return (prog.layout, L, c, g, ctx)

/-- Run kernel text `src` started as `startText` starts it; `pre` changes the grid after the
start. Returns the buffer's first `n` values of type `ty`. With `rev` the threads first run in
reverse order, each until it waits or returns. A data race in the run's trace (`racy`), a
disagreement of `fast` with `racy` on it, or a write to the bytes of an `!invariant.load`
(`kept`) is a failure. -/
def runText (src : String) (threads : Nat) (args : Val → List Val) (n : Nat := 0)
    (blocks := 1) (addr := 0x100) (ty : Ty := .int 32) (rev := false)
    (ch : Nat → Nat := fun _ => 0) (oracle : Nat → Nat → Nat := fun _ _ => 0)
    (m0 : Mem := {}) (pre : Grid → Grid := id) : Except String (List Val) := do
  let (l, L, c, g, ctx) ← startText src threads args blocks addr ch oracle m0
  let g := pre g
  let g ← if rev then (g.runAll ctx 1000 (List.range g.threads.size).reverse).mapError err
    else pure g
  let g ← (g.run L ctx 1000 10).mapError err
  if racy g.mem.trace != fast g.mem.trace then throw "fast and racy disagree"
  if racy g.mem.trace then throw "data race"
  if !kept g.mem.trace then throw "invariant load written"
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
  -- the buffer, cast to the generic space, to `lifetime.start` declared with attributes `attrs`
  let marker (attrs : String) (a : Nat) :=
    runText ("define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = addrspacecast ptr addrspace(1) %0 to ptr\n\
      call void @llvm.lifetime.start.p0(ptr %2)\n\
      ret void\n\
    }\n\
    declare void @llvm.lifetime.start.p0(ptr " ++ attrs ++ ")") 1 buf (addr := a)
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
  checkFault "intrinsic align" "noundef value not defined" (marker "noundef align 64" 1) ++
  checkFault "intrinsic align (control)" "lifetime marker on memory the thread does not own"
    (marker "noundef align 64" 0x100) ++
  checkFault "intrinsic dereferenceable" "parameter attribute dereferenceable"
    (marker "dereferenceable(4)" 0x100) ++
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

/-- The evaluator tests, on the imported programs of `MojoProof.Kernels`; returns the failures. -/
def evalTests : IO (Array String) := do
  let fails := vaddTests Kernels.vadd.prog ++ matmulTests Kernels.matmul.prog
  IO.println "evaluator: vector_addition (2 oracles, written tiles and their twin, 2 faults), \
    tiled_matmul (2 oracles, the full launch and one block race-checked), rsqrt, 3 oracle \
    counterexamples, 93 small kernels, the reduction's atomic and 2 twins"
  return fails ++ rsqrtTests ++ oracleTests ++ textTests ++ paramAttrTests ++ intrinsicAttrTests ++
    startMemTests ++ callAttrTests ++ pendingTests ++ (← atomicTests)

end MojoProofTest
