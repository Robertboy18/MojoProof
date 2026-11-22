import MojoProof.Sem.Dot
import MojoProofTest.Eval
import MojoProofTest.SymPhi

/-!
# The naive matmul kernel's oracle numbers, on one launch

The naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean) runs, for an in-bounds thread, its
entry block's 37 statements and two branches (steps 0 to 38), then per iteration `j` the
statements of `%46` and `%52`; by that count the `fadd` `%66` of iteration `j` is the thread's
step `55 + 18 j`, so its oracle number is `oracle n (Nat.pair (55 + 18 j) 0)` (lane 0 of a
scalar). This module checks the count on one launch by running the grid evaluator; it proves
nothing.

The launch is one block of 2 × 2 threads with `m = n = 2` and `K = 3`. Row `r` of `A` is element
`r * 768 + k` of `%1`'s buffer and row `c` of `B` element `c * 768 + k` of `%2`'s (the kernel
reads `B` transposed); cell `(r, c)` is element `r * 50257 + c` of `%0`'s buffer. With
`u = 2 ^ -23`, `A = [[1, 1 + u, 0], [1, 0, 1 + u]]` and `B = [[-1, 1 - u, 0], [-1, 0, 1 - u]]`:
the product `(1 + u) (1 - u)` rounds to 1, so fusing the `fadd` of iteration 1 changes cell
`(0, 0)` from `+0` to `-2 ^ -46`, and fusing that of iteration 2 changes cell `(1, 1)` the same
way. Fusing at iteration 0 changes no word (the accumulator is `+0`).

* `fused_at`: for `j = 0, 1, 2`, under the oracle that gives 2 (fuse with the product operand) at
  step `55 + 18 j` of every thread and 0 elsewhere, every thread returns and each of the four
  cells is `dotLoop` with `contract` over its three factor pairs under the oracle numbers that
  fuse exactly iteration `j` (`isF32`).
* `visible`: those references differ from the unfused one at cell `(0, 0)` for `j = 1` and at
  cell `(1, 1)` for `j = 2`.
* `off_by_one`, the twin: the oracle that gives 2 at step `56 + 18` (the branch after the `fadd`
  of iteration 1) instead gives the unfused cells, not those that fuse iteration 1.
-/

namespace MojoProofTest.NaiveRun

open MojoProof MojoProof.LLVM MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange

/-- Element `k < 3` of row `r < 2` of `A`: `[[1, 1 + 2 ^ -23, 0], [1, 0, 1 + 2 ^ -23]]` (words
`0x3f800000`, `0x3f800001`, `0`); `+0` elsewhere. -/
def aw (r k : Nat) : Model FloatFormat.binary32 :=
  Model.ofNatBits (match r, k with
    | 0, 0 | 1, 0 => 0x3f800000
    | 0, 1 | 1, 2 => 0x3f800001
    | _, _ => 0)

/-- Element `k < 3` of row `c < 2` of `B`: `[[-1, 1 - 2 ^ -23, 0], [-1, 0, 1 - 2 ^ -23]]` (words
`0xbf800000`, `0x3f7ffffe`, `0`); `+0` elsewhere. -/
def bw (c k : Nat) : Model FloatFormat.binary32 :=
  Model.ofNatBits (match c, k with
    | 0, 0 | 1, 0 => 0xbf800000
    | 0, 1 | 1, 2 => 0x3f7ffffe
    | _, _ => 0)

/-- A buffer of `768 + 3` floats whose element `r * 768 + k` is `f r k` for `k < 768`. -/
def rows (f : Nat → Nat → Model FloatFormat.binary32) : List (Model FloatFormat.binary32) :=
  (List.range (768 + 3)).map fun i => f (i / 768) (i % 768)

/-- The run of the naive kernel on one block of 2 × 2 threads, `m = n = 2`, `K = 3`, `%1`'s
buffer `rows aw`, `%2`'s `rows bw` and `%0`'s `50257 + 2` undefined floats, thread `t` with oracle
`oracle t`; returns cells `(0, 0)`, `(0, 1)`, `(1, 0)` and `(1, 1)` of `%0`'s buffer after the
run, or the fault. The input buffers are the blocks `Mem.holds_alloc` proves hold their tensors
(`tensorBytes`, row-major), as in `runF32`. -/
def runNaive (oracle : Nat → Nat → Nat) : Except String (List Val) := do
  let prog := SymPhi.naive.prog
  let l := prog.layout
  let some fn := prog.module.funcs.find? (some ·.name == prog.kernels.head?)
    | throw "no kernel"
  let buf (m : Mem) (xs : List (Model FloatFormat.binary32)) (a : Nat) : Mem × Nat :=
    let x : TorchLean.Tensor _ [xs.length] :=
      .ofFlatFn fun k => xs[k.val]'(by simpa [TorchLean.Shape.size] using k.isLt)
    m.alloc l 1 (TorchLean.Shape.size [xs.length] * l.size (.fp .float)) 16 true false .all a a
      (tensorBytes l (.fp .float) (.ofFloat .float) x)
  let (m, c) := ({} : Mem).alloc l 1 (4 * (50257 + 2)) 16 true false .all 0x10000 0x10000
  let (m, a) := buf m (rows aw) 0x100
  let (m, b) := buf m (rows bw) 0x200
  let tys := fn.params.map fun p => (p.attrs.findSome? fun | .ty "byval" t => some t | _ => none)
  let i32 (v : Nat) : Val := .bits 32 (BitVec.ofNat 32 v)
  let args := ([c, a, b].zip tys).map (fun (b, t) => bufArg ⟨b, 0⟩ (t.getD (.ptr 0))) ++
    [i32 2, i32 2, i32 3]
  let L := launch2 1 1 2 2
  let (g, ctx) ← (Grid.start prog fn L args m (oracle 0) oracle).mapError err
  let g ← (g.run L ctx 100000 100).mapError err
  [(0, 0), (0, 1), (1, 0), (1, 1)].mapM fun (r, col) =>
    (g.mem.load l default 1 (.fp .float) ⟨c, (((r * 50257 + col) * 4 : Nat) : Int)⟩
      (some 4)).mapError err

/-- The oracle that gives 2 (fuse an `fadd` with its second operand's product) at step `q` of
every thread, lane 0, and 0 everywhere else. -/
def fuseAt (q : Nat) : Nat → Nat → Nat :=
  fun _ i => if i = Nat.pair q 0 then 2 else 0

/-- The oracle numbers of `dotLoop` that fuse exactly iteration `j`: `(0, 2)` there, `(0, 0)`
elsewhere. -/
def fuseIter (j : Nat) : Nat → Nat × Nat :=
  fun k => (0, if k = j then 2 else 0)

/-- The reference for cell `(r, c)` when iteration `j` fuses: `dotLoop` with `contract` from
`+0` over the pairs `(aw r k, bw c k)` for `k < 3` under `fuseIter j` (for `j ≥ 3`, the unfused
loop). -/
def expect (j r c : Nat) : Model FloatFormat.binary32 :=
  dotLoop true (fuseIter j) (Model.zero _ false) ((List.range 3).map fun k => (aw r k, bw c k))

/-- The run under `oracle` returns, and its four cells are `ref` at `(0, 0)`, `(0, 1)`,
`(1, 0)` and `(1, 1)` (`isF32`). -/
def agrees (oracle : Nat → Nat → Nat) (ref : Nat → Nat → Model FloatFormat.binary32) : Bool :=
  match runNaive oracle with
  | .ok vs => vs.length == 4 &&
      (vs.zip [(0, 0), (0, 1), (1, 0), (1, 1)]).all fun (v, (r, c)) => isF32 (ref r c) v
  | .error _ => false

/-- For `j = 0, 1, 2`, the run that fuses at step `55 + 18 j` gives the cells of the loop that
fuses iteration `j`. -/
def fused_at : Bool :=
  [0, 1, 2].all fun j => agrees (fuseAt (55 + 18 * j)) (expect j)

/-- Fusing iteration 1 changes cell `(0, 0)` and fusing iteration 2 changes cell `(1, 1)`, against
the unfused loop (`expect 3`). -/
def visible : Bool :=
  (expect 1 0 0).toNatBits != (expect 3 0 0).toNatBits &&
    (expect 2 1 1).toNatBits != (expect 3 1 1).toNatBits

/-- The twin: the run that gives 2 at step `56 + 18`, one past the `fadd` of iteration 1, gives the
unfused cells and not those of the loop that fuses iteration 1. -/
def off_by_one : Bool :=
  agrees (fuseAt (56 + 18)) (expect 3) && !agrees (fuseAt (56 + 18)) (expect 1)

#guard fused_at
#guard visible
#guard off_by_one

end MojoProofTest.NaiveRun
