import MojoProof.Sym.Vals
import MojoProof.Kernels.Vadd

/-!
# Tests of the tactic mojo_vals: `vector_addition`'s node values

`vadd_vals0` and `vadd_vals1` are the node values of `vector_addition`'s blocks `%4` and `%21`
(`Kernels.vadd.b0`, `Kernels.vadd.b1`, MojoProof/Kernels/Vadd.lean), each proved by mojo_vals
alone: for every valid launch, thread, length `n < 2 ^ 31`, context, memory and frame with the
listed facts (block `%4`, at the entry valuation), and for every valuation of fn_0 at step 17 with
the listed registers and buffers (block `%21`).

The first `example` is the open-goal twin of `vadd_vals0`: with the load of `%1`'s struct behind
an irreducible definition, mojo_vals cannot evaluate node 2 and leaves its equation open, as
logged, while the later nodes read its entry; unfolding the definition closes it.

The last test: a summary that `sym_summary` defines unfolds by `simp only` in the module that
runs the command (`b21`, block `%21` from position 1, after its `trunc`: a summary no library
definition holds, so the test adds no copy of one), and its exit and length are those of
`mojo_kernel`'s summary of the whole block, `Kernels.vadd.b1`.
-/

namespace MojoProofTest.Vals

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean
  FloatLib.Floats.Formats.BinaryInterchange

/-- **Block `%4`'s node values by mojo_vals**: for every valid launch `L`, thread `k`,
`n < 2 ^ 31`, context of `vadd.prog` with `L.env k`, memory and frame of `fn_0` whose registers
`%0` to `%2` point to the buffer structs of `a`, `b`, `out` and `%3` is `n`. -/
theorem vadd_vals0 {L : Launch} (hL : L.Valid) {k n a b out p0 p1 p2 : Nat} (h31 : n < 2 ^ 31)
    {c : Ctx} (hcp : c.prog = Kernels.vadd.prog) (hce : c.env = L.env k) {m : Mem} {f : Frame}
    (hf : f.fn = Kernels.vadd.fn_0)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hr3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)))
    (hv0 : m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨a, 0⟩, Kernels.vadd.argTail]))
    (hv1 : m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨b, 0⟩, Kernels.vadd.argTail]))
    (hv2 : m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p2, 0⟩ (some 8) =
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
       icmpV Kernels.vadd.prog.layout m .slt (.int 64) (.bits 64 (BitVec.ofNat 64
         ((L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x)))
         (.bits 64 (BitVec.ofNat 64 n))] := by
  mojo_vals

/-- **Block `%21`'s node values by mojo_vals**: for every valuation of `fn_0` at step 17 whose
registers `%19`, `%10`, `%8`, `%6` are an index `k < n ≤ N` (`n < 2 ^ 31`) and the pointers to
`a`, `b`, `out`, on a memory where these are buffers of `n` floats, aligned to `al` with
`4 ∣ al`, that fit, and `a`, `b` hold `x`, `y` row-major from 0. -/
theorem vadd_vals1 {V : Valuation} (hcp : V.ctx.prog = Kernels.vadd.prog)
    (hVf : V.fn = Kernels.vadd.fn_0) (hVk : V.k = 17) {k n N a b out al : Nat} (hkn : k < n)
    (hnN : n ≤ N) (h31 : n < 2 ^ 31) (hal : 4 ∣ al) {x y : Tensor (Model FloatTy.float.fmt) [N]}
    (h19 : V.regs 19 = some (.bits 64 (BitVec.ofNat 64 k)))
    (h10 : V.regs 10 = some (.ptr ⟨a, 0⟩)) (h8 : V.regs 8 = some (.ptr ⟨b, 0⟩))
    (h6 : V.regs 6 = some (.ptr ⟨out, 0⟩))
    (hA : V.mem.Buffer a (n * 4) al false) (hB : V.mem.Buffer b (n * 4) al false)
    (hO : V.mem.Buffer out (n * 4) al true)
    (hx : V.mem.Holds Kernels.vadd.prog.layout a (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) x)
    (hy : V.mem.Holds Kernels.vadd.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) y)
    (hFa : V.mem.Fits Kernels.vadd.prog.layout a (n * 4))
    (hFb : V.mem.Fits Kernels.vadd.prog.layout b (n * 4))
    (hFo : V.mem.Fits Kernels.vadd.prog.layout out (n * 4)) :
    vals V Kernels.vadd.b1.nodes =
      [.ok (.bits 32 (BitVec.ofNat 32 k)), .ok (.bits 64 (BitVec.ofNat 64 k)),
       .ok (.ptr ⟨a, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (x (⟨k, by omega⟩, PUnit.unit))),
       .ok (.ptr ⟨b, ((4 * k : Nat) : Int)⟩),
       .ok (Val.ofFloat .float (y (⟨k, by omega⟩, PUnit.unit))),
       .ok (Val.ofFloat .float (deliver (Model.add (x (⟨k, by omega⟩, PUnit.unit))
         (y (⟨k, by omega⟩, PUnit.unit))) (V.ctx.oracle (Nat.pair 23 0) / 3))),
       .ok (.ptr ⟨out, ((4 * k : Nat) : Int)⟩)] := by
  mojo_vals

/-- The load of `%1`'s buffer struct, behind an irreducible definition. -/
@[irreducible] def Loads (m : Mem) (c : Ctx) (p : Nat) (v : Val) : Prop :=
  m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p, 0⟩ (some 8) = .ok v

/--
info: mojo_vals: open goal (node 2)
  SNode.eval (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) (List.take 2 Kernels.vadd.b0.nodes))
      (SNode.load 4 2 (SVal.reg 1)) =
    Except.ok (Val.agg [Val.ptr { block := b, off := 0 }, Kernels.vadd.argTail])
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `vadd_vals0`**: with `hv1` stated by `Loads`, mojo_vals finds no load for node 2
(`%7`) and leaves that node's equation open (nodes 3 on read its entry); `unfold Loads` then lets
it close that goal. -/
example {L : Launch} (hL : L.Valid) {k n a b out p0 p1 p2 : Nat} (h31 : n < 2 ^ 31)
    {c : Ctx} (hcp : c.prog = Kernels.vadd.prog) (hce : c.env = L.env k) {m : Mem} {f : Frame}
    (hf : f.fn = Kernels.vadd.fn_0)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hr3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)))
    (hv0 : m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨a, 0⟩, Kernels.vadd.argTail]))
    (hv1 : Loads m c p1 (.agg [.ptr ⟨b, 0⟩, Kernels.vadd.argTail]))
    (hv2 : m.load Kernels.vadd.prog.layout c.who 0 Kernels.vadd.argTy ⟨p2, 0⟩ (some 8) =
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
       icmpV Kernels.vadd.prog.layout m .slt (.int 64) (.bits 64 (BitVec.ofNat 64
         ((L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x)))
         (.bits 64 (BitVec.ofNat 64 n))] := by
  mojo_vals
  unfold Loads at hv1
  mojo_vals

/-- The summary of `vector_addition`'s block `%21` from position 1 (after its `trunc`), by
`sym_summary`. -/
sym_summary b21 := Kernels.vadd.prog Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_1.label 1

/-- **`sym_summary`'s definitions unfold by `simp` in their own module**: `simp only [b21]`
rewrites by `b21`'s equation lemma; the summary from position 1 has the exit of `mojo_kernel`'s
`vadd.b1` and one statement fewer. -/
example : b21.exit = Kernels.vadd.b1.exit ∧ b21.len + 1 = Kernels.vadd.b1.len := by
  simp only [b21]
  exact ⟨rfl, rfl⟩

end MojoProofTest.Vals
