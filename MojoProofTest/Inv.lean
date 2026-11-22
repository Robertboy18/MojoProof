import MojoProof.Sym.Inv
import MojoProofTest.SymLoop
import MojoProofTest.NaiveThread

/-!
# mojo_inv on two loops

Tests of mojo_inv (MojoProof/Sym/Inv.lean), the register half of a loop's invariant:

* `cnt_regs`: the counting loop `cnt` (MojoProofTest/SymLoop.lean), for every bound, round and
  valuation of its invariant `invN` (a hypothesis whose conjuncts mojo_inv reads): the counter
  `%i` after a round is the `phi`'s operand `%inext = %i + 1`, and the bound `%n` after any
  number of rounds is unchanged (`Valuation.iterate_regs_keep`);
* `naive_regs`: the naive matrix product's loop `naiveL` (MojoProofTest/SymNaive.lean) with
  `fmul contract`, under the premises of `OblMatmul.naive_rounds`: the counter `%47` after a
  round (`NaiveThread.round`) is `i + 1` (the latch's `select` picks `%47 + 1` since
  `i ≠ max K 0`), the premise `hR` of `NaiveThread.thread_run` asks, and the bound `%16` after
  any number of rounds is unchanged;
* `naive_path`: along the path `%46 → %50 → %52` to the latch's entry (`NaiveThread.latchAt`),
  `%47` is unchanged and the header's comparison `%49` is true; `naive_path_open` is its twin,
  with the bound `%16` behind an irreducible definition, the comparison left open and logged;
* `naive_head`: after the entry block and `%45` (`NaiveThread.head`), `%47` is 0 and `%48` is the
  `phi`'s float constant `+0`; `naive_head_open` is its twin, with the function behind an
  irreducible definition, `%48` left open and logged;
* `cnt_regs_open`: the twin of `cnt_regs` with the counter's register behind an irreducible
  definition, left open and logged, then closed once unfolded.

Each covers one loop, for every valuation, bound and round that the premises allow.
-/

namespace MojoProofTest.Inv

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.SymLoop MojoProofTest.NaiveThread
open FloatLib.Floats.Formats.BinaryInterchange

/-- **`cnt`'s registers after rounds, by mojo_inv.** For every context `c`, bound `n ≤ 2 ^ 60`,
block `b`, round `i < n`, count `j` and valuation `W` of `invN c n b i` (`%i = i`, `%n = n`): the
counter `%i` (register 4) is `i + 1` after the round `1 → 2` (`Valuation.round`; the `phi`'s
operand for the back edge is `%inext = add nsw %i, 1`), and the bound `%n` (register 7) is `n`
after `j` rounds (no `phi` and no block of the loop sets it). -/
theorem cnt_regs {c : Ctx} {n b i j : Nat} (hn : n ≤ 2 ^ 60) (hi : i < n) {W : Valuation}
    (h : invN c n b i W) :
    (Valuation.round 1 cntH bodyC W).regs 4 = some (.bits 64 (BitVec.ofNat 64 (i + 1))) ∧
      ((Valuation.round 1 cntH bodyC)^[j] W).regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) := by
  mojo_inv

/-- **The naive loop's registers after rounds, by mojo_inv.** For every inner dimension
`K ≤ 768`, sizes `m`, `n` with `m * 768 < 2 ^ 31` and `n * 768 < 2 ^ 31`, row `r < m`, column
`c < n`, blocks `bA`, `bB`, matrices `A`, `B`, round `i < max K 0`, count `j`, accumulator `acc`
and valuation `W` with the registers and buffers of `OblMatmul.naive_rounds`: after the round
`%46 → %50 → %52` with `fmul contract` (`NaiveThread.round`) the counter `%47` is `i + 1`, and
after `j` rounds the bound `%16` is `max K 0`. -/
theorem naive_regs (K m n r c bA bB i j : Nat) (acc : BitVec 32)
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
    (NaiveThread.round W).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (i + 1))) ∧
      (NaiveThread.round^[j] W).regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0))) := by
  mojo_inv

/-- **The naive loop's registers along a path, by mojo_inv.** For every inner dimension
`K ≤ 768`, round `i < max K 0` and valuation `W` with `%47 = i` and `%16 = max K 0`: at the entry
of the latch `%52` in the round from `W` with `fmul contract` (`NaiveThread.latchAt`, the last
block of the path `%46 → %50 → %52`, after the header from position 2 and `%50`), `%47` is still
`i`, since neither the header's statements after its `phi`s nor `%50` set it, and a branch keeps
the block's registers; and the header's comparison `%49 = icmp slt %47, %16` is true, the word
`1` (its value `Val.ofBool (decide (i < max K 0))` with the `decide` that `omega` decides,
`Vals.decStep`). -/
theorem naive_path (K i : Nat) (W : Valuation) (hK : K ≤ 768) (hi : i < max K 0)
    (h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 i)))
    (h16 : W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0)))) :
    (latchAt W).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 i)) ∧
      (latchAt W).regs (idx "49") = some (.bits 1 1) := by
  mojo_inv

/-- The bound `%16` of `W` is `max K 0`; irreducible, so that mojo_inv does not find it. -/
@[irreducible] def BoundIs (W : Valuation) (K : Nat) : Prop :=
  W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0)))

/--
info: mojo_inv: open goal
  (latchAt W).regs (idx "49") = some (Val.bits 1 1)
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `naive_path`'s comparison**: with the bound `%16` stated as `BoundIs`, mojo_inv
has no value for the comparison `%49`, so it leaves its equation open, as logged; unfolding
`BoundIs` lets it close it. For every `K ≤ 768`, round `i < max K 0` and valuation `W` with
`%47 = i`. -/
theorem naive_path_open (K i : Nat) (W : Valuation) (hK : K ≤ 768) (hi : i < max K 0)
    (h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 i))) (h16 : BoundIs W K) :
    (latchAt W).regs (idx "49") = some (.bits 1 1) := by
  mojo_inv
  unfold BoundIs at h16
  mojo_inv

/-- **The naive loop's registers at its head, by mojo_inv.** For every context `c`, memory `m`
and frame `f` of `naive`'s function: after the entry block `%6` and `%45` (`NaiveThread.head`,
the edge `%45 → %46` into the header's `phi`s), the counter `%47` is 0 and the accumulator `%48`
is `+0`, the `phi`'s float constant `0.0` (`evalV_float`, its literal's value by the kernel). -/
theorem naive_head (c : Ctx) (m : Mem) (f : Frame) (hf : f.fn = naive.fn_0) :
    (head (Valuation.entry c 0 m f)).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 0)) ∧
      (head (Valuation.entry c 0 m f)).regs (idx "48") =
        some (.ofFloat .float (Model.zero _ false)) := by
  mojo_inv

/-- `f.fn = naive.fn_0`, irreducible, so that mojo_inv does not find the function. -/
@[irreducible] def IsNaive (f : Frame) : Prop := f.fn = naive.fn_0

/--
info: mojo_inv: open goal
  (head (Valuation.entry c 0 m f)).regs (idx "48") =
    some (Val.ofFloat FloatTy.float (Model.zero FloatTy.float.fmt false))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `naive_head`'s accumulator**: with the function stated as `IsNaive`, mojo_inv
does not know the header's `phi`s, so it leaves `%48` open, as logged; unfolding `IsNaive` lets it
close it. For every context, memory and frame. -/
theorem naive_head_open (c : Ctx) (m : Mem) (f : Frame) (hf : IsNaive f) :
    (head (Valuation.entry c 0 m f)).regs (idx "48") =
      some (.ofFloat .float (Model.zero _ false)) := by
  mojo_inv
  unfold IsNaive at hf
  mojo_inv

/-- The counter `%i` (register 4) of `W` is `i`; irreducible, so that mojo_inv does not find
it. -/
@[irreducible] def CntIs (W : Valuation) (i : Nat) : Prop :=
  W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i))

/--
info: mojo_inv: open goal
  (Valuation.round 1 cntH bodyC W).regs 4 = some (Val.bits 64 (BitVec.ofNat 64 (i + 1)))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `cnt_regs`**: with the counter's register stated as `CntIs`, mojo_inv finds no
value for `%i`, so it leaves the counter's equation open, as logged; unfolding `CntIs` lets it
close it. For every bound `n ≤ 2 ^ 60`, round `i < n` and valuation `W` of `cnt`. -/
theorem cnt_regs_open {n i : Nat} (hn : n ≤ 2 ^ 60) (hi : i < n) {W : Valuation}
    (hfn : W.fn = cnt) (h4 : CntIs W i) :
    (Valuation.round 1 cntH bodyC W).regs 4 = some (.bits 64 (BitVec.ofNat 64 (i + 1))) := by
  mojo_inv
  unfold CntIs at h4
  mojo_inv

end MojoProofTest.Inv
