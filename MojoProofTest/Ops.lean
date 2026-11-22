import MojoProof.Sym.Ops
import MojoProof.Kernels.Vadd

/-!
# Tests of the tactic mojo_ret: `vector_addition`'s `Elem` steps and `Ret`

`vadd_elem0`, `vadd_elem1` and the first `example` are `vector_addition`'s `Elem` steps and `Ret`
(the `example` states `Kernels.vadd.ret` by `type_of%`, the statement `mojo_kernel`'s `map2` clause
generates in MojoProof/Kernels/Vadd.lean, so it pins that statement and adds no copy of the
theorem), each proved by mojo_ret alone:

* `vadd_elem0`: block `%4`'s three loads keep `Elem`, for every context, memories, frame, blocks
  and bytes;
* `vadd_elem1`: block `%21`'s effects advance `Elem` by thread `k < n ≤ N`, for every valuation
  of fn_0 of thread `k` with oracle `ω k` and block `%21`'s node values;
* the `example`: for every valid 1-D launch, thread `k`, count `n < 2 ^ 31` and memory of `Elem`
  after `k` threads with the buffer facts, some path of `vadd.paths` is a `Ret` to `Elem` after
  `k + 1` threads (mojo_ret splits on the branch condition `k < n`).

The next `example` is the open-goal twin of `vadd_elem0`: with `p1 ≠ out` behind an
irreducible definition, mojo_ret cannot show the second load's block is not `out` and leaves that
goal open, as logged; unfolding the definition closes it.

`vadd_only0` and `vadd_only1` are mojo_ret's `Elem.Only` goal (every access to `out` by a thread
of a set): block `%4`'s loads keep it for every set and thread, and block `%21`'s effects keep it
for the threads below `n` when the thread is one of them; the last `example` is `vadd_only0`'s
open-goal twin.
-/

namespace MojoProofTest.Ops

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean
  FloatLib.Floats.Formats.BinaryInterchange

/-- **Block `%4`'s effects keep `Elem` by mojo_ret**: for every context, memories, frame whose
registers `%0` to `%2` point to blocks other than `out`, `k` and bytes. -/
theorem vadd_elem0 {c : Ctx} {m₀ m me : Mem} {f : Frame} {out p0 p1 p2 k : Nat}
    {bs : Nat → Option (List MemByte)}
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hp : p0 ≠ out ∧ p1 ≠ out ∧ p2 ≠ out)
    (hE : Elem m₀ out 4 (fun i => 4 * i) bs k m)
    (h : SEff.run (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes)
      Kernels.vadd.b0.effs = .ok me) :
    Elem m₀ out 4 (fun i => 4 * i) bs k me := by
  mojo_ret

/-- **Block `%21`'s effects advance `Elem` by mojo_ret**: for every valuation of `vadd.prog`'s
`fn_0` of thread `k < n ≤ N` at oracle `ω k` with `vadd.b1`'s node values, blocks `a`, `b` other
than `out`, vectors and caller's memory. -/
theorem vadd_elem1 {V : Valuation} (hcp : V.ctx.prog = Kernels.vadd.prog)
    (hVf : V.fn = Kernels.vadd.fn_0) {ω : Nat → Nat → Nat} {k n N a b out : Nat}
    (hco : V.ctx.oracle = ω k) (hcw : V.ctx.who.thread = k) (hkn : k < n) (hnN : n ≤ N)
    (ha : a ≠ out) (hb : b ≠ out) {x y : Tensor (Model FloatTy.float.fmt) [N]} {m₀ me : Mem}
    (hvs : vals V Kernels.vadd.b1.nodes =
      [.ok (.bits 32 (BitVec.ofNat 32 k)), .ok (.bits 64 (BitVec.ofNat 64 k)),
       .ok (.ptr ⟨a, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (x (⟨k, by omega⟩, PUnit.unit))),
       .ok (.ptr ⟨b, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (y (⟨k, by omega⟩, PUnit.unit))),
       .ok (Val.ofFloat .float (deliver (Model.add (x (⟨k, by omega⟩, PUnit.unit))
         (y (⟨k, by omega⟩, PUnit.unit))) (V.ctx.oracle (Nat.pair 23 0) / 3))),
       .ok (.ptr ⟨out, ((4 * k : Nat) : Int)⟩)])
    (hE : Elem m₀ out 4 (fun i => 4 * i) (Kernels.vadd.bytes ω x y n) k V.mem)
    (h : SEff.run V (vals V Kernels.vadd.b1.nodes) Kernels.vadd.b1.effs = .ok me) :
    Elem m₀ out 4 (fun i => 4 * i) (Kernels.vadd.bytes ω x y n) (k + 1) me := by
  mojo_ret

/-- **Thread `k`'s path is a `Ret` by mojo_ret**: the statement of `Kernels.vadd.ret` (which
`mojo_kernel`'s `map2` clause generates in MojoProof/Kernels/Vadd.lean), for every valid launch with
one block row and one thread row, alignment `4 ∣ al`, distinct blocks `a`, `b`, `out`, `n ≤ N`
below `2 ^ 31`, vectors, thread `k` of the launch, context of `vadd.prog` with thread `k`'s
registers, identity and oracle `ω k`, caller's memory, memory of `Elem` after `k` threads and frame
of `fn_0` with the buffer structs and buffers: some path of `vadd.paths` is a `Ret` to `Elem` after
`k + 1` threads. The hypotheses are introduced without names; mojo_ret finds them by type. -/
example : type_of% @Kernels.vadd.ret := by
  intros
  mojo_ret

/-- `p ≠ q`, behind an irreducible definition. -/
@[irreducible] def Off (p q : Nat) : Prop := p ≠ q

/--
info: mojo_ret: open goal
  ¬p1 = out
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `vadd_elem0`**: with `p1 ≠ out` stated as `Off p1 out`, mojo_ret cannot show
that block `%4`'s second load (through `%1`) is not to `out` and leaves `¬p1 = out` open (and
proves the other two loads); `unfold Off` then closes it. -/
example {c : Ctx} {m₀ m me : Mem} {f : Frame} {out p0 p1 p2 k : Nat}
    {bs : Nat → Option (List MemByte)}
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hp : p0 ≠ out ∧ p2 ≠ out) (h1 : Off p1 out)
    (hE : Elem m₀ out 4 (fun i => 4 * i) bs k m)
    (h : SEff.run (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes)
      Kernels.vadd.b0.effs = .ok me) :
    Elem m₀ out 4 (fun i => 4 * i) bs k me := by
  mojo_ret
  unfold Off at h1
  exact h1

/-- **Block `%4`'s loads keep `Elem.Only` by mojo_ret**: for every context, memories, frame whose
registers `%0` to `%2` point to blocks other than `out` and set of threads `S`, whatever the
context's thread. -/
theorem vadd_only0 {c : Ctx} {m me : Mem} {f : Frame} {out p0 p1 p2 : Nat} {S : Nat → Prop}
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hp : p0 ≠ out ∧ p1 ≠ out ∧ p2 ≠ out)
    (hO : Elem.Only out S m)
    (h : SEff.run (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes)
      Kernels.vadd.b0.effs = .ok me) :
    Elem.Only out S me := by
  mojo_ret

/-- **Block `%21`'s effects keep `Elem.Only` by mojo_ret**: for every valuation of thread `k < n`,
output block and memory, the effects of `vadd.b1` (two loads and a store) keep every access to
`out` by a thread below `n`. -/
theorem vadd_only1 {V : Valuation} {k n out : Nat} {me : Mem} (hcw : V.ctx.who.thread = k)
    (hkn : k < n) (hO : Elem.Only out (· < n) V.mem)
    (h : SEff.run V (vals V Kernels.vadd.b1.nodes) Kernels.vadd.b1.effs = .ok me) :
    Elem.Only out (· < n) me := by
  mojo_ret

/--
info: mojo_ret: open goal
  ¬p1 = out
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `vadd_only0`**: with `p1 ≠ out` stated as `Off p1 out`, mojo_ret leaves
`¬p1 = out` open for the second load; `unfold Off` then closes it. -/
example {c : Ctx} {m me : Mem} {f : Frame} {out p0 p1 p2 : Nat} {S : Nat → Prop}
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hp : p0 ≠ out ∧ p2 ≠ out) (h1 : Off p1 out)
    (hO : Elem.Only out S m)
    (h : SEff.run (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes)
      Kernels.vadd.b0.effs = .ok me) :
    Elem.Only out S me := by
  mojo_ret
  unfold Off at h1
  exact h1

end MojoProofTest.Ops
