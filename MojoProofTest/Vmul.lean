import MojoProof.Kernels.Vadd
import MojoProof.Kernels.Vmul
import MojoProof.Sym.Vals
import MojoProof.Sym.Ops

/-!
# Tests of mojo_vals and mojo_ret on a second kernel: vector_multiply

`Kernels.vmul` (tests/corpus/vmul/) is written for this repository, not upstream:
`vector_addition` with `*` for `+`, compiled with contraction off (`--fp-mode contract=off`), so
its block `%21` has an `fmul` with no flags where `vector_addition`'s has an `fadd contract`;
nothing else in the IR differs (the module and kernel names aside). These tests are
`vector_addition`'s (MojoProofTest/Vals.lean, MojoProofTest/Ops.lean) on it, each proved by the
tactic alone, over the library's summaries (MojoProof/Kernels/Vmul.lean): `mojo_kernel vmul` there
names `vector_addition`'s summaries of blocks `%4`, `%30`, `%31` and its arguments
(`Kernels.vadd.b0`, `b2`, `b3`, `Kernels.vadd.args`) and adds `Kernels.vmul.b1` and
`Kernels.vmul.paths`, so this module summarizes nothing again:

* `vmul_vals0`, `vmul_vals1`: the node values of blocks `%4` (`Kernels.vadd.b0`, in a context of
  `vmul.prog`) and `%21` (`Kernels.vmul.b1`) by mojo_vals, for every valid launch, thread, count
  `n < 2 ^ 31`, context, memory and frame with the listed facts (block `%4`, at the entry
  valuation), and for every valuation of fn_0 at step 17 with the listed registers and buffers
  (block `%21`, whose product is `deliver (x_k * y_k)`);
* `vmul_elem1` and the `example` after it, by mojo_ret: block `%21`'s effects advance `Elem` by
  thread `k < n ≤ N` with the bytes `Kernels.vmul.bytes` (FloatLib's `Model.mul`), and the
  statement of `Kernels.vmul.ret` (by `type_of%`): for every valid 1-D launch, thread `k`, count
  `n < 2 ^ 31` and memory of `Elem` after `k` threads with the buffer facts, some path of
  `Kernels.vmul.paths` is a `Ret` to `Elem` after `k + 1` threads. Block `%4`'s step is
  `vector_addition`'s, `MojoProofTest.Ops.vadd_elem0`, the same statement.

The struct type, its tail and the bytes are the library's (`Kernels.vadd.argTy`,
`Kernels.vadd.argTail`, `Kernels.vmul.bytes`).
-/

namespace MojoProofTest.Vmul

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean
  FloatLib.Floats.Formats.BinaryInterchange

/-- **Block `%4`'s node values by mojo_vals**, for every valid launch `L`, thread `k`,
`n < 2 ^ 31`, context of `vmul.prog` with `L.env k`, memory and frame of `fn_0` whose registers
`%0` to `%2` point to the buffer structs of `a`, `b`, `out` and `%3` is `n`. -/
theorem vmul_vals0 {L : Launch} (hL : L.Valid) {k n a b out p0 p1 p2 : Nat} (h31 : n < 2 ^ 31)
    {c : Ctx} (hcp : c.prog = Kernels.vmul.prog) (hce : c.env = L.env k) {m : Mem} {f : Frame}
    (hf : f.fn = Kernels.vmul.fn_0)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hr3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)))
    (hv0 : m.load Kernels.vmul.prog.layout c.who 0 Kernels.vadd.argTy ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨a, 0⟩, Kernels.vadd.argTail]))
    (hv1 : m.load Kernels.vmul.prog.layout c.who 0 Kernels.vadd.argTy ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨b, 0⟩, Kernels.vadd.argTail]))
    (hv2 : m.load Kernels.vmul.prog.layout c.who 0 Kernels.vadd.argTy ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨out, 0⟩, Kernels.vadd.argTail])) :
    vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes =
      [.ok (.agg [.ptr ⟨out, 0⟩, Kernels.vadd.argTail]), .ok (.ptr ⟨out, 0⟩),
       .ok (.agg [.ptr ⟨b, 0⟩, Kernels.vadd.argTail]), .ok (.ptr ⟨b, 0⟩),
       .ok (.agg [.ptr ⟨a, 0⟩, Kernels.vadd.argTail]), .ok (.ptr ⟨a, 0⟩),
       .ok (.bits 64 (BitVec.ofNat 64 n)),
       .ok (.bits 32 (BitVec.ofNat 32 ((L.env k).sreg .tid .x))),
       .ok (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x))),
       .ok (.bits 32 (BitVec.ofNat 32 ((L.env k).sreg .ctaid .x))),
       .ok (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .ctaid .x))),
       .ok (.bits 32 (BitVec.ofNat 32 ((L.env k).sreg .ntid .x))),
       .ok (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .ntid .x))),
       .ok (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x))),
       .ok (.bits 64 (BitVec.ofNat 64
         ((L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x))),
       icmpV Kernels.vmul.prog.layout m .slt (.int 64) (.bits 64 (BitVec.ofNat 64
         ((L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x)))
         (.bits 64 (BitVec.ofNat 64 n))] := by
  mojo_vals

/-- **Block `%21`'s node values by mojo_vals**, for every valuation of `fn_0` at step 17 whose
registers `%19`, `%10`, `%8`, `%6` are an index `k < n ≤ N` (`n < 2 ^ 31`) and the pointers to
`a`, `b`, `out`, on a memory where these are buffers of `n` floats, aligned to `al` with
`4 ∣ al`, that fit, and `a`, `b` hold `x`, `y` row-major from 0: the product node is
`deliver (x_k * y_k)` at the `fmul`'s oracle number. -/
theorem vmul_vals1 {V : Valuation} (hcp : V.ctx.prog = Kernels.vmul.prog)
    (hVf : V.fn = Kernels.vmul.fn_0) (hVk : V.k = 17) {k n N a b out al : Nat} (hkn : k < n)
    (hnN : n ≤ N) (h31 : n < 2 ^ 31) (hal : 4 ∣ al) {x y : Tensor (Model FloatTy.float.fmt) [N]}
    (h19 : V.regs 19 = some (.bits 64 (BitVec.ofNat 64 k)))
    (h10 : V.regs 10 = some (.ptr ⟨a, 0⟩)) (h8 : V.regs 8 = some (.ptr ⟨b, 0⟩))
    (h6 : V.regs 6 = some (.ptr ⟨out, 0⟩))
    (hA : V.mem.Buffer a (n * 4) al false) (hB : V.mem.Buffer b (n * 4) al false)
    (hO : V.mem.Buffer out (n * 4) al true)
    (hx : V.mem.Holds Kernels.vmul.prog.layout a (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vmul.prog.layout (.fp .float) 0) x)
    (hy : V.mem.Holds Kernels.vmul.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vmul.prog.layout (.fp .float) 0) y)
    (hFa : V.mem.Fits Kernels.vmul.prog.layout a (n * 4))
    (hFb : V.mem.Fits Kernels.vmul.prog.layout b (n * 4))
    (hFo : V.mem.Fits Kernels.vmul.prog.layout out (n * 4)) :
    vals V Kernels.vmul.b1.nodes =
      [.ok (.bits 32 (BitVec.ofNat 32 k)), .ok (.bits 64 (BitVec.ofNat 64 k)),
       .ok (.ptr ⟨a, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (x (⟨k, by omega⟩, PUnit.unit))),
       .ok (.ptr ⟨b, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (y (⟨k, by omega⟩, PUnit.unit))),
       .ok (Val.ofFloat .float (deliver (Model.mul (x (⟨k, by omega⟩, PUnit.unit))
         (y (⟨k, by omega⟩, PUnit.unit))) (V.ctx.oracle (Nat.pair 23 0) / 3))),
       .ok (.ptr ⟨out, ((4 * k : Nat) : Int)⟩)] := by
  mojo_vals

/-- **Block `%21`'s effects advance `Elem` by mojo_ret**, for every valuation of `vmul.prog`'s
`fn_0` of thread `k < n ≤ N` at oracle `ω k` with `vmul_vals1`'s node values, blocks `a`, `b`
other than `out`, vectors and caller's memory: the store adds `Kernels.vmul.bytes ω x y n k`. -/
theorem vmul_elem1 {V : Valuation} (hcp : V.ctx.prog = Kernels.vmul.prog)
    (hVf : V.fn = Kernels.vmul.fn_0) {ω : Nat → Nat → Nat} {k n N a b out : Nat}
    (hco : V.ctx.oracle = ω k) (hcw : V.ctx.who.thread = k) (hkn : k < n) (hnN : n ≤ N)
    (ha : a ≠ out) (hb : b ≠ out) {x y : Tensor (Model FloatTy.float.fmt) [N]} {m₀ me : Mem}
    (hvs : vals V Kernels.vmul.b1.nodes =
      [.ok (.bits 32 (BitVec.ofNat 32 k)), .ok (.bits 64 (BitVec.ofNat 64 k)),
       .ok (.ptr ⟨a, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (x (⟨k, by omega⟩, PUnit.unit))),
       .ok (.ptr ⟨b, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (y (⟨k, by omega⟩, PUnit.unit))),
       .ok (Val.ofFloat .float (deliver (Model.mul (x (⟨k, by omega⟩, PUnit.unit))
         (y (⟨k, by omega⟩, PUnit.unit))) (V.ctx.oracle (Nat.pair 23 0) / 3))),
       .ok (.ptr ⟨out, ((4 * k : Nat) : Int)⟩)])
    (hE : Elem m₀ out 4 (fun i => 4 * i) (Kernels.vmul.bytes ω x y n) k V.mem)
    (h : SEff.run V (vals V Kernels.vmul.b1.nodes) Kernels.vmul.b1.effs = .ok me) :
    Elem m₀ out 4 (fun i => 4 * i) (Kernels.vmul.bytes ω x y n) (k + 1) me := by
  mojo_ret

/-- **Thread `k`'s path is a `Ret` by mojo_ret**: the statement of `Kernels.vmul.ret`, which
`mojo_kernel`'s `map2` clause generates in MojoProof/Kernels/Vmul.lean (for every valid launch with
one block row and one thread row, alignment `4 ∣ al`, distinct blocks `a`, `b`, `out`, `n ≤ N`
below `2 ^ 31`, vectors, thread `k` of the launch, context of `vmul.prog` with thread `k`'s
registers, identity and oracle `ω k`, caller's memory, memory of `Elem` after `k` threads and frame
of `fn_0` with the buffer structs and buffers: some path of `Kernels.vmul.paths` is a `Ret` to
`Elem` after `k + 1` threads with the bytes `Kernels.vmul.bytes`). The hypotheses are introduced
without names; mojo_ret finds them by type. -/
example : type_of% @Kernels.vmul.ret := by
  intros
  mojo_ret

end MojoProofTest.Vmul
