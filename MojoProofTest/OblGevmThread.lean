import MojoProofTest.OblGevm
import MojoProof.Sym.OblSeg

/-!
# gevm_kernel's `%59` on one thread, through its barrier and shuffles to its `ret`

gevm_kernel (`gevm`, MojoProofTest/OblGevm.lean) ends with block `%59` (label
`gevm.fn_0.b_5.label`): after its `phi` `%60` (the loop's sum), statements 1 to 5 store `%60` to
cell `32 l + w` of the shared array (lane `l = %13`, warp `w = %11`), statement 6 is the barrier,
7 to 10 load cell `tid.x = %10` and cast it to `i32`, and 11, 15, 19, 23 and 27 are five
`shfl.sync.bfly` calls, each after the `bitcast` and `fadd contract` of the previous call's
result; statements 28 to 38 are the last `bitcast` and `fadd` (`%86`, `%87`), the lane test `%96`
(`%13` modulo 32 is 0, by `sdiv`, `mul`, `sub`, two compares, `and`, `select` and `add`) and the
branch to `%97` (lane 0: `store float %87, ptr %29`) or `%98`, both to `%99` (`ret void`).

* `seg_0 … seg_5`: the segments to the six calls (`sym_segs seg := …`); `tail`, `yes` and `no`:
  the summaries of `%59` from 28, `%97` and `%98` (`sym_summary`; `%99`'s, `ret void`, is
  written out in `thread`); `segs_eq`: `summarizeSegs` gives the six segments and `tail`.
* `resumed`: the valuation the thread resumes at after the six calls (`Valuation.resume`, six
  levels deep).
* `thread`: **one theorem for every thread of gevm_kernel at `%59`**, for every context, memory,
  frame and values the barrier and the shuffles deliver meeting the premises: the thread runs
  through the barrier and the five shuffles (`RunsVia`, one wait each, `mojo_seg`, each segment's
  obligations by mojo_obl) to its `ret` (`RunsVia.of_ends`: `tail`'s obligations, its branch to
  `%97` for lane 0 and to `%98` for the others, and the path to `%99`, by mojo_obl), lane 0
  storing at its output cell `%29` of the memory the last shuffle delivers
  (`SEff.run_store_one`) the sum, as the `fadd`s deliver it, of the shared array's cell `tid.x`
  and the five values the shuffles deliver, the other lanes storing nothing. The delivered values
  are premises (`z₁` to `z₅`, not the other lanes' sums), and it starts at `%59`, not at the
  kernel's entry (the loop's theorems, MojoProofTest/OblGevm.lean, are not joined to it).
* `tail_open`: the twin, the fifth shuffle's value behind an irreducible definition: the
  `bitcast` `%86`'s obligation left open, as logged. The last test is mojo_seg's refusal with no
  `Seg.Through` hypothesis.

Tests of one program, gevm_kernel float32 `1308aaae`; the lemmas, command and tactics they use
(MojoProof/Sym/OblSeg.lean, MojoProof/Sym/OblLemmas.lean) are for every program.
-/

namespace MojoProofTest.OblGevmThread

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.OblGevm
open FloatLib.Floats.Formats.BinaryInterchange

/-- A segment of `%59` (`b_5`) from statement 1, to the barrier at 6 and the shuffles at 11, 15,
19, 23 and 27 (`summarizeSegs`). -/
sym_segs seg := gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 [6, 11, 15, 19, 23, 27]

/-- `%59` from statement 28, after the fifth shuffle: `%86 = bitcast %85`, `%87 = fadd contract
%83, %86`, the lane test `%96` and the branch to `%97` or `%98`. -/
sym_summary tail := gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 28

/-- `%97`: `store float %87, ptr %29, align 4` and `br label %99`. -/
sym_summary yes := gevm.prog gevm.fn_0 gevm.fn_0.b_6.label 0

/-- `%98`: `br label %99`. -/
sym_summary no := gevm.prog gevm.fn_0 gevm.fn_0.b_7.label 0

/-- **`%59`'s segments**: `summarizeSegs` gives, from statement 1 with the collective calls at
6, 11, 15, 19, 23 and 27, the six segments `seg_0` to `seg_5` and `tail`. -/
theorem segs_eq : summarizeSegs gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 [6, 11, 15, 19, 23, 27] =
    some ([seg_0, seg_1, seg_2, seg_3, seg_4, seg_5], tail) := by
  decide +kernel

/-- The valuation a thread of `gevm` resumes at after `%59`'s six collective calls, from frame `f`
at statement 1 of thread `t` on memory `m` with deliveries `d₀` (the barrier's) to `d₅` (the
fifth shuffle's): `Valuation.resume` at each segment's summary and its call's register
(`resReg`), at the positions `RunsVia.of_through` gives (each call's: the previous one's, plus 1,
plus the segment's statements). -/
abbrev resumed (c : Ctx) (t : Thread) (m : Mem) (f : Frame)
    (d₀ d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) : Valuation :=
  ((((((Valuation.entry c t.k m f).resume seg_0.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label (1 + seg_0.len)) d₀).resume seg_1.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label (1 + seg_0.len + 1 + seg_1.len)) d₁).resume
    seg_2.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len))
    d₂).resume seg_3.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label
      (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len + 1 + seg_3.len)) d₃).resume
    seg_4.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label
      (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len + 1 + seg_3.len + 1 + seg_4.len)) d₄).resume
    seg_5.toSummary
    (resReg gevm.fn_0 gevm.fn_0.b_5.label (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len + 1 +
      seg_3.len + 1 + seg_4.len + 1 + seg_5.len)) d₅

/-- **A thread of gevm_kernel from `%59` to its `ret`, through the barrier and the five
shuffles.** One program, gevm_kernel float32 `1308aaae`. For every context `c` of its program,
thread `t` whose only frame `f`, with no `alloca` blocks, is of `gevm`'s function at statement 1
of `%59`, memory `m`, lane `l < 32`, warp `w < 32`, `tid.x = x < 1024`, sum `acc`, output buffer
`p0` of `N` binary32 and cell `o < N`, shared block `b` owned by thread block `g`, deliveries
`d₀` (the barrier's) to `d₅` (the fifth shuffle's) and vector `A` of 1024 binary32, where `f`'s
`%13`, `%11`, `%10` are the 64-bit words of `l`, `w`, `x`, `%60` is `acc` and `%29` the pointer
to cell `o` of `p0`, `c` gives the shared array the pointer to offset 0 of `b`, `m` and `d₀.2`
have at `b` a writable buffer of 4096 bytes of shared memory aligned to 4, owned by `g` (which
admits `c`'s thread), that fits in space 3, `d₀.2`'s holding `A`, the shuffles deliver the
binary32 `z₁` to `z₅`, and `d₅.2` has `p0` as a writable buffer of `N` binary32 aligned to 4 that
fits: the thread waits at the barrier at statement 6 of `%59`, then at five `shfl.sync.bfly`
calls at statements 11, 15, 19, 23 and 27 (each wait's `Thread.at`), resumed each time with the
delivery, and runs to its end on a memory `m'` that is, for lane 0, `d₅.2` with `s₅`
stored at cell `o` of `p0`, and for the other lanes `d₅.2`. Here `s₀` is `A`'s cell `x` and `sᵢ`,
for `i` from 1 to 5, what the `fadd` delivers (`deliver`) for the IEEE sum `sᵢ₋₁ + zᵢ`
(`Model.add`, round to nearest): that sum, or for a NaN sum the NaN the oracle number
`c.oracle (Nat.pair (t.k + 8 + 4 i) 0) / 3` encodes, if it encodes one. -/
theorem thread (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (ht : t.frames = [f]) (hf : f.fn = gevm.fn_0) (hlb : f.label = gevm.fn_0.b_5.label)
    (hpc : f.pc = 1) (ha : f.allocas = []) (l w x : Nat) (hl : l < 32) (hw : w < 32)
    (hx : x < 1024) (acc : BitVec 32) (p0 N o : Nat) (ho : o < N)
    (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 x)))
    (h60 : f.regs 60 = some (.bits 32 acc))
    (h29 : f.regs 29 = some (.ptr ⟨p0, ((o * 4 : Nat) : Int)⟩))
    (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (d₀ d₁ d₂ d₃ d₄ d₅ : Option Val × Mem)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024])
    (hB₀ : d₀.2.BufferIn 3 b 4096 4 (.cta g) true)
    (hF₀ : ∃ blk, d₀.2.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hA : d₀.2.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt)
    (hd₁ : d₁.1 = some (Val.ofFloat .float z₁)) (hd₂ : d₂.1 = some (Val.ofFloat .float z₂))
    (hd₃ : d₃.1 = some (Val.ofFloat .float z₃)) (hd₄ : d₄.1 = some (Val.ofFloat .float z₄))
    (hd₅ : d₅.1 = some (Val.ofFloat .float z₅))
    (hy : d₅.2.Buffer p0 (N * 4) 4 true) (hfy : d₅.2.Fits gevm.prog.layout p0 (N * 4)) :
    RunsVia c (fun m' => (l = 0 →
        d₅.2.store gevm.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
          (deliver ((deliver ((deliver ((deliver ((deliver
            ((TorchLean.Tensor.Rep.get A (⟨x, hx⟩, ())).add z₁)
            (c.oracle (Nat.pair (t.k + 12) 0) / 3)).add z₂)
            (c.oracle (Nat.pair (t.k + 16) 0) / 3)).add z₃)
            (c.oracle (Nat.pair (t.k + 20) 0) / 3)).add z₄)
            (c.oracle (Nat.pair (t.k + 24) 0) / 3)).add z₅)
            (c.oracle (Nat.pair (t.k + 28) 0) / 3)))
          ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) = .ok m') ∧ (l ≠ 0 → m' = d₅.2))
      [(fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6) ∧ i = .barrier, d₀),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 11) ∧
          i = .shfl .bfly, d₁),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 15) ∧
          i = .shfl .bfly, d₂),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 19) ∧
          i = .shfl .bfly, d₃),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 23) ∧
          i = .shfl .bfly, d₄),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 27) ∧
          i = .shfl .bfly, d₅)] t m := by
  have hT := Seg.through hcp segs_eq (fun i => [d₀, d₁, d₂, d₃, d₄, d₅].getD i d₀) (m := m) ht hf
    hlb hpc
  mojo_seg
  mojo_seg
  mojo_seg
  mojo_seg
  mojo_seg
  mojo_seg
  rename_i fr t' ht' hfn' hpc' hal' hT' hV'
  by_cases h0 : l = 0
  · -- lane 0: `%97` stores `%87` at `%29`, then `%99` returns
    subst h0
    refine RunsVia.of_ends (dst := 97)
      (ps := [(97, yes.obls, yes), (99, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)])
      hcp hT' hV' hfn' hal' ?_ ?_ (by decide +kernel) rfl
      (RetWith.of_first (by decide +kernel) ?_ fun me hme => ?_)
    · mojo_obl
    · mojo_obl
    · mojo_obl
    · obl_have
        h87 : ((resumed c t m f d₀ d₁ d₂ d₃ d₄ d₅).into gevm.fn_0.b_5.label tail).regs 87,
        h29' : ((resumed c t m f d₀ d₁ d₂ d₃ d₄ d₅).into gevm.fn_0.b_5.label tail).regs 29
      have e := SEff.run_store_one
        (V := (resumed c t m f d₀ d₁ d₂ d₃ d₄ d₅).into gevm.fn_0.b_5.label tail)
        (vs := vals ((resumed c t m f d₀ d₁ d₂ d₃ d₄ d₅).into gevm.fn_0.b_5.label tail) yes.nodes)
        (lbl := 97) (pc := 0) hf hcp
        (by rfl)
        (SVal.eval_reg h87) (SVal.eval_reg h29') hme
      exact ⟨fun _ => e, fun h => absurd rfl h⟩
  · -- another lane: `%98`, then `%99` returns, storing nothing
    refine RunsVia.of_ends (dst := 98)
      (ps := [(98, no.obls, no), (99, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)])
      hcp hT' hV' hfn' hal' ?_ ?_ (by decide +kernel) rfl
      (RetWith.of_first (by decide +kernel) ?_ fun me hme =>
        ⟨fun h => absurd h h0, fun _ => (Except.ok.inj hme).symm⟩)
    · mojo_obl
    · mojo_obl
    · mojo_obl

/-- Delivery `d` gives the value `v` (`d.1 = some v`); irreducible, so that mojo_obl does not
find the equation. -/
@[irreducible] def Delivered (d : Option Val × Mem) (v : Val) : Prop := d.1 = some v

/--
info: mojo_obl: open goal
  Cond.Holds ((Valuation.entry c k m f).resume seg_5.toSummary
      (resReg gevm.fn_0 gevm.fn_0.b_5.label 27) d)
    (vals ((Valuation.entry c k m f).resume seg_5.toSummary
      (resReg gevm.fn_0 gevm.fn_0.b_5.label 27) d)
      tail.nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `thread` after the fifth shuffle**: for every context `c`, step count `k`,
memory `m`, frame `f` of `gevm`'s function, delivery `d` and 32-bit word `u`, where `d` delivers
`u` stated as `Delivered d (.bits 32 u)`, node 0 of `tail` (`%86`, the `bitcast` of the fifth
shuffle's result `%85`) has a value at the valuation resumed after the shuffle at statement 27;
mojo_obl finds no value of `%85`, so it leaves that obligation open, as logged, and closes it
after `unfold Delivered`. -/
theorem tail_open (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : f.fn = gevm.fn_0)
    (d : Option Val × Mem) (u : BitVec 32) (hd : Delivered d (.bits 32 u)) :
    Cond.Holds ((Valuation.entry c k m f).resume seg_5.toSummary
        (resReg gevm.fn_0 gevm.fn_0.b_5.label 27) d)
      (vals ((Valuation.entry c k m f).resume seg_5.toSummary
        (resReg gevm.fn_0 gevm.fn_0.b_5.label 27) d) tail.nodes) (.ok (.node 0)) := by
  mojo_obl
  unfold Delivered at hd
  mojo_obl

/--
error: mojo_seg: no Seg.Through hypothesis with a segment and its frame's facts, or the predicate
on the collective is not decided
c : Ctx
Q : Mem → Prop
t : Thread
m : Mem
d : Option Val × Mem
⊢ RunsVia c Q [(fun x i x_1 x_2 => i = Intrinsic.barrier, d)] t m
-/
#guard_msgs (whitespace := lax) in
/-- **mojo_seg's refusal**: with no `Seg.Through` hypothesis to run (here, before
`Seg.through`), mojo_seg fails. -/
example (c : Ctx) (Q : Mem → Prop) (t : Thread) (m : Mem) (d : Option Val × Mem) :
    RunsVia c Q [(fun _ i _ _ => i = .barrier, d)] t m := by
  mojo_seg

end MojoProofTest.OblGevmThread
