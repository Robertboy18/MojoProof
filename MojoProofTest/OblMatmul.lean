import MojoProofTest.SymNaive
import MojoProofTest.SymSelect
import MojoProof.Sym.Obl

/-!
# mojo_obl on the naive matrix product's loop

The naive matrix product (`naive` of MojoProofTest/SymPhi.lean) multiplies a row-major `m × 768`
matrix `A` by the transpose of a row-major `n × 768` matrix `B` into `C`, of `m × 50257` cells
of binary32: thread `(r, c)` runs the loop `%46 → %50 → %52` (`naiveL` of
MojoProofTest/SymNaive.lean) for `%47 = i` from 0 while `i < %16`, `%16 = smax(K, 0)` the
sign-extended inner dimension, each round loading `A (r, i)` (offset `%26 + i`, `%26 = 768 r`)
and `B (c, i)` (offset `%37 + i`, `%37 = 768 c`) and adding their `fmul contract` product to the
accumulator `%48` (`fadd contract`).

* `naive_rounds`: mojo_obl proves the premises of round `i` (`RoundWith true`, the round with
  `fmul contract`) for every `i < max K 0` with `K ≤ 768`, every row `r < m` and column `c < n`
  with `768 m`, `768 n < 2 ^ 31`, and every valuation whose registers and buffers are those of
  the round: the header's `i < max K 0`, the latch's `select` (`i ≠ max K 0`), its index
  arithmetic, the loads of `A (r, i)` and `B (c, i)` (`load_buffer2`), the `fmul contract` and
  the `fadd contract`, and the branch back to `%46` after its `phi`s.
* `naive_rounds_open`: the twin, with the accumulator's register behind an irreducible
  definition; the latch's `fadd contract` obligation is left open, as logged.
* `naive_exit`: the path out of the loop, `%46 → %51 → %67 → %69`, its store into cell
  `50257 r + c` of `C`.
* `naive_entry`: the path into the loop for every thread in range of every valid launch, with
  `%16 = smax(K, 0) = max K 0`.
* `naive_skip_row`, `naive_skip_col`: the path `%6 → %44 → %69` of every thread out of range of
  every valid launch, its index arithmetic modulo `2 ^ 32` and its `getelementptr inbounds` `%40`
  some value (a pointer, or poison), the branch by the low bit of the `select`'s word.
-/

namespace MojoProofTest.OblMatmul

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
open MojoProofTest.SymNaive MojoProofTest.SymSelect FloatLib.Floats.Formats.BinaryInterchange

/-- **The rounds of the naive matrix product's loop, by mojo_obl.** For every inner dimension
`K ≤ 768`, numbers of rows `m` and `n` with `m * 768 < 2 ^ 31` and `n * 768 < 2 ^ 31`, row
`r < m`, column `c < n`, blocks `bA` and `bB`, row-major matrices `A : m × 768` and `B : n × 768`
of binary32, round `i < max K 0` (`max K 0` is `smax(K, 0)`, the entry block's `%16`),
accumulator word `acc` and valuation `W` of `naive`'s program and function with `%47 = i`,
`%16 = max K 0`, `%48 = acc`, `%26 = 768 r`, `%37 = 768 c` (32-bit words), `%11` and `%12` at
offset 0 of `bA` and `bB`, buffers `bA` and `bB` of `768 m` and `768 n` binary32 aligned to 4
whose generic addresses do not wrap (`Mem.Fits`) and that hold `A` and `B`: the premises of round
`i` of `naiveL` with `fmul contract` hold at `W` (`RoundWith true`). -/
theorem naive_rounds (K m n r c bA bB i : Nat) (acc : BitVec 32)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (W : Valuation)
    (hK : K ≤ 768) (hm : m * 768 < 2 ^ 31) (hn : n * 768 < 2 ^ 31) (hr : r < m) (hc : c < n)
    (hi : i < max K 0) (hP : W.ctx.prog = naive.prog) (hfn : W.fn = naive.fn_0)
    (h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 i)))
    (h16 : W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0))))
    (h48 : W.regs (idx "48") = some (.bits 32 acc))
    (h26 : W.regs (idx "26") = some (.bits 32 (BitVec.ofNat 32 (r * 768))))
    (h37 : W.regs (idx "37") = some (.bits 32 (BitVec.ofNat 32 (c * 768))))
    (h11 : W.regs (idx "11") = some (.ptr ⟨bA, 0⟩))
    (h12 : W.regs (idx "12") = some (.ptr ⟨bB, 0⟩))
    (hbA : W.mem.Buffer bA (m * 768 * 4) 4 false) (hbB : W.mem.Buffer bB (n * 768 * 4) 4 false)
    (hfA : W.mem.Fits naive.prog.layout bA (m * 768 * 4))
    (hfB : W.mem.Fits naive.prog.layout bB (n * 768 * 4))
    (hA : W.mem.Holds naive.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) A)
    (hB : W.mem.Holds naive.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) B) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W := by
  mojo_obl

/-- The accumulator `%48` of `W` is the word `acc`; irreducible, so that mojo_obl does not find
it. -/
@[irreducible] def AccIs (W : Valuation) (acc : BitVec 32) : Prop :=
  W.regs (idx "48") = some (.bits 32 acc)

/--
info: mojo_obl: open goal
  Cond.Holds
    (Valuation.intoWith true (Valuation.intoWith true W naiveL.h naiveL.H) naive.fn_0.b_4.label
      body)
    (vals (Valuation.intoWith true (Valuation.intoWith true W naiveL.h naiveL.H)
      naive.fn_0.b_4.label body) SymContract.latch.nodes)
    (Cond.ok (SVal.node 13))
---
info: mojo_obl: open goal
  Cond.Holds
    (Valuation.intoWith true (Valuation.intoWith true W naiveL.h naiveL.H) naive.fn_0.b_4.label
      body)
    (vals (Valuation.intoWith true (Valuation.intoWith true W naiveL.h naiveL.H)
      naive.fn_0.b_4.label body) SymContract.latch.nodes)
    (Cond.ok (SVal.node 13))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `naive_rounds`**: with the accumulator's register stated as `AccIs`, mojo_obl
finds no value for `%48`, so it leaves open the obligations of the latch's `fadd contract`
(node 13), as logged, and proves the rest; unfolding `AccIs` lets it close them. -/
theorem naive_rounds_open (K m n r c bA bB i : Nat) (acc : BitVec 32)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (W : Valuation)
    (hK : K ≤ 768) (hm : m * 768 < 2 ^ 31) (hn : n * 768 < 2 ^ 31) (hr : r < m) (hc : c < n)
    (hi : i < max K 0) (hP : W.ctx.prog = naive.prog) (hfn : W.fn = naive.fn_0)
    (h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 i)))
    (h16 : W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0))))
    (h48 : AccIs W acc)
    (h26 : W.regs (idx "26") = some (.bits 32 (BitVec.ofNat 32 (r * 768))))
    (h37 : W.regs (idx "37") = some (.bits 32 (BitVec.ofNat 32 (c * 768))))
    (h11 : W.regs (idx "11") = some (.ptr ⟨bA, 0⟩))
    (h12 : W.regs (idx "12") = some (.ptr ⟨bB, 0⟩))
    (hbA : W.mem.Buffer bA (m * 768 * 4) 4 false) (hbB : W.mem.Buffer bB (n * 768 * 4) 4 false)
    (hfA : W.mem.Fits naive.prog.layout bA (m * 768 * 4))
    (hfB : W.mem.Fits naive.prog.layout bB (n * 768 * 4))
    (hA : W.mem.Holds naive.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) A)
    (hB : W.mem.Holds naive.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) B) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W := by
  mojo_obl
  all_goals (unfold AccIs at h48; mojo_obl)

/-- **The path out of the loop, by mojo_obl.** For every inner dimension `K ≤ 768`, number of
rows `m`, row `r < m`, column `c < 50257`, block `bC`, accumulator word `acc` and valuation `W`
of `naive`'s program and function with `%47 = %16 = max K 0` (the loop's last test,
`max K 0 < max K 0`, fails), `%48 = acc` and `%40` at cell `50257 r + c` of `bC`, a writable
buffer of `50257 m` binary32 aligned to 4 whose generic addresses do not wrap: the premises of
the path out `%46 → %51 → %67 → %69` with `fmul contract` hold at `W` (`WalkWith true`): the
header's branch goes to `%51`, `%51` passes `%48` to `%67`'s `phi`, and `%67` stores it into
cell `50257 r + c` of `bC` (`store_buffer`). -/
theorem naive_exit (K m r c bC : Nat) (acc : BitVec 32) (W : Valuation)
    (hK : K ≤ 768) (hr : r < m) (hc : c < 50257)
    (hP : W.ctx.prog = naive.prog) (hfn : W.fn = naive.fn_0)
    (h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (max K 0))))
    (h16 : W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0))))
    (h48 : W.regs (idx "48") = some (.bits 32 acc))
    (h40 : W.regs (idx "40") =
      some (.ptr ⟨bC, ((r * 50257 + c) * naive.prog.layout.size (.fp .float) : Nat)⟩))
    (hbC : W.mem.Buffer bC (m * 50257 * 4) 4 true)
    (hfC : W.mem.Fits naive.prog.layout bC (m * 50257 * 4)) :
    WalkWith true W ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X) := by
  mojo_obl

/-- **The entry path into the loop, by mojo_obl**, for every thread in range of every valid
launch. For every valid launch `L`, thread number `k`, context `c` of `naive`'s program for
thread `k` of `L`, step count `s`, memory `M` and frame `f` of `naive`'s function whose
parameters `%0`, `%1`, `%2` point at structs (`byval`) that hold the pointers to `bC`, `bA` and
`bB` and whose `%3`, `%4`, `%5` are the 32-bit words of `m`, `n` and `K`, with `K ≤ 768`,
`m * 50257 < 2 ^ 31`, `n ≤ 50257`, `bC` a writable buffer of `50257 m` binary32 aligned to 4
whose generic addresses do not wrap, and thread `k`'s row `ctaid.x * ntid.x + tid.x < m` and
column `ctaid.y * ntid.y + tid.y < n`: the premises of the
path `%6 → %45` into the loop's header with `fmul contract` hold at `f`'s entry valuation, and
its edge goes to `%46` after its `phi`s (`EdgeWith true`): the loads of the structs, the index
arithmetic, `%16 = smax(K, 0)`, the address `%40` of cell `50257 r + c` of `bC`, the compares
and the `select` (both false), and `%45`'s float constant. -/
theorem naive_entry (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx)
    (hcp : c.prog = naive.prog) (hce : c.env = L.env k) (s : Nat) (M : Mem) (f : Frame)
    (hf : f.fn = naive.fn_0) (K m n p0 p1 p2 bA bB bC : Nat)
    (hK : K ≤ 768) (hm : m * 50257 < 2 ^ 31) (hn : n ≤ 50257)
    (hr0 : f.regs (idx "0") = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs (idx "1") = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs (idx "2") = some (.ptr ⟨p2, 0⟩))
    (hr3 : f.regs (idx "3") = some (.bits 32 (BitVec.ofNat 32 m)))
    (hr4 : f.regs (idx "4") = some (.bits 32 (BitVec.ofNat 32 n)))
    (hr5 : f.regs (idx "5") = some (.bits 32 (BitVec.ofNat 32 K)))
    (hv0 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bC, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv1 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bA, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv2 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bB, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hbC : M.Buffer bC (m * 50257 * 4) 4 true)
    (hfC : M.Fits naive.prog.layout bC (m * 50257 * 4))
    (hx : (L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x < m)
    (hy : (L.env k).sreg .ctaid .y * (L.env k).sreg .ntid .y + (L.env k).sreg .tid .y < n) :
    EdgeWith true naiveL.h naiveL.p (Valuation.entry c s M f) naive.fn_0.b_0.label entry.obls
      entry [(naive.fn_0.b_2.label, pre.obls, pre)] := by
  mojo_obl

/-- **The path of a thread out of range, row first, by mojo_obl**, for every such thread of every
valid launch: with the premises of `naive_entry` but the row out of range,
`m ≤ ctaid.x * ntid.x + tid.x`, and the column any, the premises of the path `%6 → %44 → %69`
with `fmul contract` hold at `f`'s entry valuation (`WalkWith true`): the loads of the structs,
the index arithmetic (`mul` and `add` without `nuw` and `nsw`, modulo `2 ^ 32`), the `sext` of
`%38` (its sign extension) and the `getelementptr inbounds` `%40` (some value, a pointer or
poison: `gep_buffer_ok`), the compares, the `select` (true, so the word `1`), the branch to `%44`
by its low bit, and `%44` and `%69`. -/
theorem naive_skip_row (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx)
    (hcp : c.prog = naive.prog) (hce : c.env = L.env k) (s : Nat) (M : Mem) (f : Frame)
    (hf : f.fn = naive.fn_0) (K m n p0 p1 p2 bA bB bC : Nat)
    (hK : K ≤ 768) (hm : m * 50257 < 2 ^ 31) (hn : n ≤ 50257)
    (hr0 : f.regs (idx "0") = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs (idx "1") = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs (idx "2") = some (.ptr ⟨p2, 0⟩))
    (hr3 : f.regs (idx "3") = some (.bits 32 (BitVec.ofNat 32 m)))
    (hr4 : f.regs (idx "4") = some (.bits 32 (BitVec.ofNat 32 n)))
    (hr5 : f.regs (idx "5") = some (.bits 32 (BitVec.ofNat 32 K)))
    (hv0 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bC, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv1 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bA, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv2 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bB, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hbC : M.Buffer bC (m * 50257 * 4) 4 true)
    (hx : m ≤ (L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) :
    WalkWith true (Valuation.entry c s M f) [(naive.fn_0.b_0.label, entry.obls, entry),
      (naive.fn_0.b_1.label, skip.obls, skip),
      (naive.fn_0.b_8.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)] := by
  mojo_obl

/-- **The path of a thread out of range, column only, by mojo_obl**, for every such thread of
every valid launch: with the premises of `naive_entry` but the column out of range,
`n ≤ ctaid.y * ntid.y + tid.y`, and the row in range, `ctaid.x * ntid.x + tid.x < m`, the
premises of the path `%6 → %44 → %69` with `fmul contract` hold at `f`'s entry valuation
(`WalkWith true`), as in `naive_skip_row`, the `select` picking the column's compare (true). -/
theorem naive_skip_col (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx)
    (hcp : c.prog = naive.prog) (hce : c.env = L.env k) (s : Nat) (M : Mem) (f : Frame)
    (hf : f.fn = naive.fn_0) (K m n p0 p1 p2 bA bB bC : Nat)
    (hK : K ≤ 768) (hm : m * 50257 < 2 ^ 31) (hn : n ≤ 50257)
    (hr0 : f.regs (idx "0") = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs (idx "1") = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs (idx "2") = some (.ptr ⟨p2, 0⟩))
    (hr3 : f.regs (idx "3") = some (.bits 32 (BitVec.ofNat 32 m)))
    (hr4 : f.regs (idx "4") = some (.bits 32 (BitVec.ofNat 32 n)))
    (hr5 : f.regs (idx "5") = some (.bits 32 (BitVec.ofNat 32 K)))
    (hv0 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bC, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv1 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bA, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hv2 : M.load naive.prog.layout c.who 0 (.struct [.ptr 0, .struct [.struct [.struct [],
      .struct []], .struct [.struct [], .struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨bB, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]))
    (hbC : M.Buffer bC (m * 50257 * 4) 4 true)
    (hx : (L.env k).sreg .ctaid .x * (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x < m)
    (hy : n ≤ (L.env k).sreg .ctaid .y * (L.env k).sreg .ntid .y + (L.env k).sreg .tid .y) :
    WalkWith true (Valuation.entry c s M f) [(naive.fn_0.b_0.label, entry.obls, entry),
      (naive.fn_0.b_1.label, skip.obls, skip),
      (naive.fn_0.b_8.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)] := by
  mojo_obl

end MojoProofTest.OblMatmul
