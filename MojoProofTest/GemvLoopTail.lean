import MojoProofTest.GemvLoop
import MojoProof.Sym.WaitVia

/-!
# gemv_kernel's `%78` on one thread, through its five shuffles to its `ret`

gemv_kernel (`gemv`, MojoProofTest/SymLane.lean) ends with block `%78` (label
`gemv.fn_0.b_10.label`): after its `phi` `%79` (the loop's sum, register 80), statements 2, 6,
10, 14 and 18 are five `shfl.sync.bfly` calls, each after the `bitcast` of the sum so far and,
from the second on, after the `bitcast` and `fadd contract` of the previous call's result;
statements 19 and 20 are the last `bitcast` and `fadd` (`%98`, `%99`) and the branch on lane 0's
flag `%41` to `%100` (`store float %99, ptr %37`) or `%101`, both to `%102` and then `%103`
(`ret void`).

* `seg_0 … seg_4`: the segments to the five calls (`sym_segs seg := …`); `tail`, `yes`, `no`
  and `join`: the summaries of `%78` from 19, `%100`, `%101` and `%102` (`sym_summary`; `%103`'s,
  `ret void`, is written out in `thread`); `segs_eq`: `summarizeSegs` gives the five segments
  and `tail`.
* `resumed`: the valuation the thread resumes at after the five calls (`Valuation.resume`, five
  levels deep).
* `addAt`, `shfls`, `waits`: an `fadd`'s delivered sum at its step, the five shuffles as waits
  (position, call, the four argument values and the memory at each call, gemv IR :114-130), and
  as `Piece.Wait.via`'s waits at `%78`, the form `WarpRun.of_waits` takes.
* `thread`: **one theorem for every thread of gemv_kernel at position 1 of `%78`**, for every
  context, memory, frame with any `alloca` blocks, and values the shuffles deliver meeting the
  premises: the thread runs through the five shuffles (`RunsVia` through `waits`, one wait each,
  `tailseg`: `mojo_seg` with `RunsVia.of_through_via`, each segment's obligations by mojo_obl)
  to its `ret` (`tail`'s branch to `%100` for lane 0 and
  to `%101` for the others, by `Ends.edge`, and the path to `%103` by `Runs.of_retAt`, whose
  `ret` ends the frame's `alloca` blocks' lifetimes), lane 0 storing through `%37` the sum, as the
  `fadd`s deliver it, of `%79` and the five values the shuffles deliver, the other lanes storing
  nothing. The delivered values are premises (`z₁` to `z₅`, not the other lanes' sums).
  MojoProofTest/GemvLoop.lean's `run` reaches this frame with `%79`, its operands, `%37` and
  `%41` as here; `total`: the sum lane 0 stores.
* `to_ret`: `run`, then `thread`: a thread from statement 41 of the entry block to its `ret` at
  every `K`, with the values the other lanes' shuffles deliver as premises; the memory at `%78`'s
  first shuffle is one memory with the start's blocks, chosen before the deliveries.
* `fadd_open`: without the premise that `%79` records no `fmul contract` operands, in the form
  mojo_obl looks for, the first `fadd`'s obligation is left open (`#guard_msgs`).

The segments are `summarizeSegs`' (collectives only), not SymGemvTail's `bP`
(`summarizePieces` with the `alloca` flag): `RunsVia.of_fires` takes `bP`'s run as a closed
Boolean (`Piece.fires`) that the kernel decides at concrete values, and the sum and the
deliveries here are variables; `Seg.through` and `tailseg` take each segment's obligations as
goals for mojo_obl. `%78` has no `alloca` and no lifetime marker, so the two checkers' segments
are the same statements.

Tests of one program, gemv_kernel float32 `b79a852b`; the lemmas, command and tactics they use
(MojoProof/Sym/OblSeg.lean, MojoProof/Sym/WaitVia.lean, MojoProof/Sym/OblLemmas.lean) are for
every program.
-/

namespace MojoProofTest.GemvLoopTail

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvLoop
open FloatLib.Floats.Formats.BinaryInterchange

/-- A segment of gemv_kernel's `%78` (`b_10`) from statement 1, to the shuffles at 2, 6, 10, 14
and 18 (`summarizeSegs`). -/
sym_segs seg := gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 1 [2, 6, 10, 14, 18]

/-- gemv_kernel's `%78` from statement 19, after the fifth shuffle: `%98 = bitcast %97`,
`%99 = fadd contract %95, %98` and the branch on `%41` to `%100` or `%101`. -/
sym_summary tail := gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 19

/-- gemv_kernel's `%100`: `store float %99, ptr %37, align 4` and `br label %102`. -/
sym_summary yes := gemv.prog gemv.fn_0 gemv.fn_0.b_11.label 0

/-- gemv_kernel's `%101`: `br label %102`. -/
sym_summary no := gemv.prog gemv.fn_0 gemv.fn_0.b_12.label 0

/-- gemv_kernel's `%102`: `br label %103`. -/
sym_summary join := gemv.prog gemv.fn_0 gemv.fn_0.b_13.label 0

/-- **`%78`'s segments** (test of gemv_kernel): `summarizeSegs` gives, from statement 1 with the
collective calls at 2, 6, 10, 14 and 18, the five segments `seg_0` to `seg_4` and `tail`. -/
theorem segs_eq : summarizeSegs gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 1 [2, 6, 10, 14, 18] =
    some ([seg_0, seg_1, seg_2, seg_3, seg_4], tail) := by
  decide +kernel

/-- The valuation a thread of gemv_kernel resumes at after `%78`'s five shuffles, from frame `f`
at statement 1 of thread `t` on memory `m` with deliveries `d₁` (the first shuffle's) to `d₅`
(the fifth's): `Valuation.resume` at each segment's summary and its call's register (`resReg`),
at the positions `RunsVia.of_through` gives (each call's: the previous one's, plus 1, plus the
segment's statements). A test definition. -/
abbrev resumed (c : Ctx) (t : Thread) (m : Mem) (f : Frame)
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) : Valuation :=
  (((((Valuation.entry c t.k m f).resume seg_0.toSummary
    (resReg gemv.fn_0 gemv.fn_0.b_10.label (1 + seg_0.len)) d₁).resume seg_1.toSummary
    (resReg gemv.fn_0 gemv.fn_0.b_10.label (1 + seg_0.len + 1 + seg_1.len)) d₂).resume
    seg_2.toSummary
    (resReg gemv.fn_0 gemv.fn_0.b_10.label (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len))
    d₃).resume seg_3.toSummary
    (resReg gemv.fn_0 gemv.fn_0.b_10.label
      (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len + 1 + seg_3.len)) d₄).resume
    seg_4.toSummary
    (resReg gemv.fn_0 gemv.fn_0.b_10.label
      (1 + seg_0.len + 1 + seg_1.len + 1 + seg_2.len + 1 + seg_3.len + 1 + seg_4.len)) d₅

/-- The sum lane 0 of gemv_kernel stores after `%78`'s five shuffles, from the sum `x` of `%79`
and the binary32 `z₁` (the first shuffle's) to `z₅` (the fifth's) the shuffles deliver, for a
thread at position 1 of `%78` at step `k0` in context `c`: `s₀ = x` and `sᵢ`, for `i` from 1 to
5, what the `i`-th `fadd` delivers (`deliver`) for the IEEE sum `sᵢ₋₁ + zᵢ` (`Model.add`, round
to nearest) with the oracle number `c.oracle (Nat.pair (k0 + 4 i - 1) 0) / 3` of its step. A
test definition. -/
def total (c : Ctx) (k0 : Nat) (x z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt) :
    Model FloatTy.float.fmt :=
  deliver ((deliver ((deliver ((deliver ((deliver (x.add z₁)
    (c.oracle (Nat.pair (k0 + 3) 0) / 3)).add z₂)
    (c.oracle (Nat.pair (k0 + 7) 0) / 3)).add z₃)
    (c.oracle (Nat.pair (k0 + 11) 0) / 3)).add z₄)
    (c.oracle (Nat.pair (k0 + 15) 0) / 3)).add z₅)
    (c.oracle (Nat.pair (k0 + 19) 0) / 3)

/-- What `%78`'s `fadd` at step `k` delivers for the binary32 sum so far `s` and the shuffle's
`z`: `deliver` of the IEEE sum `s + z` (`Model.add`, round to nearest) with the oracle number
`c.oracle (Nat.pair k 0) / 3` of its step, in context `c`. A test definition. -/
def addAt (c : Ctx) (k : Nat) (s z : Model FloatTy.float.fmt) : Model FloatTy.float.fmt :=
  deliver (s.add z) (c.oracle (Nat.pair k 0) / 3)

/-- **`%78`'s five shuffles as waits** (`Piece.Wait`), for a thread of gemv_kernel at
position 1 of `%78` at step `k0` in context `c`, with the binary32 sum `x` of `%79`, memory `m`,
deliveries `d₁` (the first shuffle's) to `d₅` (the fifth's) and the binary32 `z₁` to `z₄` the
first four deliver. The `i`-th wait is at statement `4 i - 2` of `%78` (2, 6, 10, 14, 18), calls
`shfl.sync.bfly` with the full mask (`i32 -1`), the bits of the sum so far, the offset
`2 ^ (5 - i)` (16, 8, 4, 2, 1) and the clamp 31 (gemv IR :114-130), on `m` for the first and on
the previous delivery's memory for the others, and is resumed with `dᵢ`. The sum so far is
`%79` (`%80 = bitcast %79`) for the first, then the previous `fadd`'s (`addAt` at steps `k0 + 3`,
`k0 + 7`, `k0 + 11`, `k0 + 15`, `%84`, `%88`, `%92`, `%96` the bitcasts of `%83`, `%87`, `%91`,
`%95`). A test definition. -/
def shfls (c : Ctx) (k0 : Nat) (x z₁ z₂ z₃ z₄ : Model FloatTy.float.fmt) (m : Mem)
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) : List Piece.Wait :=
  [⟨2, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float x, .bits 32 (BitVec.ofInt 32 16),
        .bits 32 (BitVec.ofInt 32 31)], m, d₁⟩,
    ⟨6, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float (addAt c (k0 + 3) x z₁),
        .bits 32 (BitVec.ofInt 32 8), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩,
    ⟨10, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 7) (addAt c (k0 + 3) x z₁) z₂),
        .bits 32 (BitVec.ofInt 32 4), .bits 32 (BitVec.ofInt 32 31)], d₂.2, d₃⟩,
    ⟨14, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 11) (addAt c (k0 + 7) (addAt c (k0 + 3) x z₁) z₂) z₃),
        .bits 32 (BitVec.ofInt 32 2), .bits 32 (BitVec.ofInt 32 31)], d₃.2, d₄⟩,
    ⟨18, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 15)
          (addAt c (k0 + 11) (addAt c (k0 + 7) (addAt c (k0 + 3) x z₁) z₂) z₃) z₄),
        .bits 32 (BitVec.ofInt 32 1), .bits 32 (BitVec.ofInt 32 31)], d₄.2, d₅⟩]

/-- **`%78`'s five shuffles as `Piece.Wait.via`'s waits**: `shfls`'s waits at block `%78` of
gemv_kernel's function (the position, call, argument values and memory of each), the form
`WarpRun.of_waits` takes. A test definition. -/
def waits (c : Ctx) (k0 : Nat) (x z₁ z₂ z₃ z₄ : Model FloatTy.float.fmt) (m : Mem)
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) :
    List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)) :=
  (shfls c k0 x z₁ z₂ z₃ z₄ m d₁ d₂ d₃ d₄ d₅).map (Piece.Wait.via gemv.fn_0 gemv.fn_0.b_10.label)

/-- `tailseg`: `mojo_seg` with the wait as `Piece.Wait.via` states it (`RunsVia.of_through_via`):
the position, the collective and the memory by `rfl`, the argument values by `SVal.mapM_shfl`
with the offered value from its node (`obl_exact`). -/
local macro "tailseg" : tactic => `(tactic| (
  refine RunsVia.of_through_via ‹Seg.Through _ _ _ _ (_ :: _) _ _ _ _›
    (by first | assumption | rfl) ‹_› ‹_› ‹_› (by rfl) rfl ?_ (by rfl) (by rfl)
    (by
      refine SVal.mapM_shfl _ _ _ ?_
      exact SVal.eval_node (by obl_exact)) (by rfl) ?_
  rotate_left
  intro _ _ _ _ _ _ _ _
  rotate_left
  mojo_obl))

/-- **A thread of gemv_kernel from position 1 of `%78` to its `ret`, through the five
shuffles** (test of one program, gemv_kernel float32 `b79a852b`). For every context `c` of its
program, thread `t` whose only frame `f` is of `gemv`'s function at statement 1 of `%78` with
`alloca` blocks `A`, memory `m`, lane `l`, sum `x` (binary32), rows `M`, row `r < M`, output
block `p0` and deliveries `d₁` (the first shuffle's) to `d₅` (the fifth's), where `f`'s `%79` is
`x` with no `fmul contract` operands recorded, `%37` the pointer to element `r` of `p0` and
`%41` whether `l` is 0, the shuffles deliver the binary32 `z₁` to `z₅`, and `d₅.2` has `p0` as a
writable buffer of `M` binary32 aligned to 4 that fits: the thread waits at `%78`'s five
`shfl.sync.bfly` calls at statements 2, 6, 10, 14 and 18 as `waits` states them at step `t.k`,
sum `x` and memory `m` (each call's position, full mask, offered bits, offset, clamp and memory),
resumed each time with the delivery, and runs to its end on a memory that is `me` with the blocks
`A` dead, where `me` is, for lane 0, `d₅.2` with `total c t.k x z₁ z₂ z₃ z₄ z₅` (the five
`fadd`s' IEEE sums, round to nearest, each delivered with its step's oracle number) stored at
element `r` of `p0`, and for the other lanes `d₅.2`. -/
theorem thread (c : Ctx) (hcp : c.prog = gemv.prog) (t : Thread) (m : Mem) (f : Frame)
    (ht : t.frames = [f]) (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_10.label)
    (hpc : f.pc = 1) (A : List Nat) (ha : f.allocas = A) (l : Nat) (x : Model FloatTy.float.fmt)
    (M r p0 : Nat) (hr : r < M) (h80 : f.regs 80 = some (.ofFloat .float x))
    (hq80 : f.prods 80 = none) (h37 : f.regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩))
    (h41 : f.regs 41 = some (.ofBool (decide (l = 0))))
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt)
    (hd₁ : d₁.1 = some (Val.ofFloat .float z₁)) (hd₂ : d₂.1 = some (Val.ofFloat .float z₂))
    (hd₃ : d₃.1 = some (Val.ofFloat .float z₃)) (hd₄ : d₄.1 = some (Val.ofFloat .float z₄))
    (hd₅ : d₅.1 = some (Val.ofFloat .float z₅))
    (hy : d₅.2.Buffer p0 (M * 4) 4 true) (hfy : d₅.2.Fits gemv.prog.layout p0 (M * 4)) :
    RunsVia c (fun m' => ∃ me, (l = 0 →
        d₅.2.store gemv.prog.layout c.who 0 (.fp .float)
          (Val.ofFloat .float (total c t.k x z₁ z₂ z₃ z₄ z₅))
          ⟨p0, ((r * 4 : Nat) : Int)⟩ (some 4) = .ok me) ∧ (l ≠ 0 → me = d₅.2) ∧
        m' = A.foldl (fun m b => m.setLive b false) me)
      (waits c t.k x z₁ z₂ z₃ z₄ m d₁ d₂ d₃ d₄ d₅) t m := by
  have hT := Seg.through hcp segs_eq (fun i => [d₁, d₂, d₃, d₄, d₅].getD i d₁) (m := m) ht hf
    hlb hpc
  simp only [waits, shfls, List.map_cons, List.map_nil]
  tailseg
  tailseg
  tailseg
  tailseg
  tailseg
  rename_i fr t' ht' hfn' hpc' hal' hT' hV'
  simp only [Seg.Through] at hT'
  rw [hV'] at hT'
  have hRf : (resumed c t m f d₁ d₂ d₃ d₄ d₅).fn = gemv.fn_0 :=
    (congrArg Valuation.fn hV').symm.trans hfn'
  by_cases h0 : l = 0
  · -- lane 0: `%100` stores `%99` through `%37`, then `%102` and `%103` return
    obtain ⟨t₁, m₁, f₁, hS, hst, hfn₁, hl₁, hp₁, ha₁, -, hE⟩ :=
      Ends.edge (d := 101) (by rfl) (hT' (by mojo_obl)) (by mojo_obl)
    have hR : RetWith false (Valuation.entry c
        ((resumed c t m f d₁ d₂ d₃ d₄ d₅).k + tail.len + 1) m₁ f₁)
        (fun me => (l = 0 →
          d₅.2.store gemv.prog.layout c.who 0 (.fp .float)
            (Val.ofFloat .float (total c t.k x z₁ z₂ z₃ z₄ z₅))
            ⟨p0, ((r * 4 : Nat) : Int)⟩ (some 4) = .ok me) ∧ (l ≠ 0 → me = d₅.2))
        [(101, yes.obls, yes), (103, join.obls, join),
          (45, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)] := by
      rw [hE]
      refine RetWith.of_first (by decide +kernel) (by mojo_obl) fun me hme => ?_
      obl_have
        h100 : ((resumed c t m f d₁ d₂ d₃ d₄ d₅).into gemv.fn_0.b_10.label tail).regs 100,
        h37' : ((resumed c t m f d₁ d₂ d₃ d₄ d₅).into gemv.fn_0.b_10.label tail).regs 37
      have e := SEff.run_store_one
        (V := (resumed c t m f d₁ d₂ d₃ d₄ d₅).into gemv.fn_0.b_10.label tail)
        (vs := vals ((resumed c t m f d₁ d₂ d₃ d₄ d₅).into gemv.fn_0.b_10.label tail) yes.nodes)
        (lbl := 101) (pc := 0) hRf hcp (by rfl) (SVal.eval_reg h100) (SVal.eval_reg h37') hme
      exact ⟨fun _ => e, fun h => absurd h0 h⟩
    have hc : coversPathAt false false gemv.prog gemv.fn_0 0
        [(101, yes.obls, yes), (103, join.obls, join),
          (45, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)] = true := by
      decide +kernel
    obtain ⟨me, hr, hq⟩ := Runs.of_retAt hcp hc (t := ⟨[f₁], _⟩) rfl (hfn₁.trans hRf) hl₁
      (hp₁.trans ((congrArg (fun F => tail.exit.pc F _) hRf).trans (by decide +kernel))) hR
    rw [Valuation.allocsWith_nil _ hc, List.nil_append, ha₁, hal'] at hr
    obtain ⟨t₂, m₂, hS₂, hd₂⟩ := hr
    exact ⟨_, ⟨t₂, m₂, hS.trans_step hst hS₂, hd₂⟩, me, hq.1, hq.2, rfl⟩
  · -- another lane: `%101`, `%102` and `%103` return, storing nothing
    obtain ⟨t₁, m₁, f₁, hS, hst, hfn₁, hl₁, hp₁, ha₁, -, hE⟩ :=
      Ends.edge (d := 102) (by rfl) (hT' (by mojo_obl)) (by mojo_obl)
    have hR : RetWith false (Valuation.entry c
        ((resumed c t m f d₁ d₂ d₃ d₄ d₅).k + tail.len + 1) m₁ f₁) (fun me => me = d₅.2)
        [(102, no.obls, no), (103, join.obls, join),
          (45, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)] := by
      rw [hE]
      exact RetWith.of_first (by decide +kernel) (by mojo_obl) fun me hme =>
        (Except.ok.inj hme).symm
    have hc : coversPathAt false false gemv.prog gemv.fn_0 0
        [(102, no.obls, no), (103, join.obls, join),
          (45, [.mem []], ⟨[], [], [], [.mem []], .ret, 0⟩)] = true := by
      decide +kernel
    obtain ⟨me, hr, hq⟩ := Runs.of_retAt hcp hc (t := ⟨[f₁], _⟩) rfl (hfn₁.trans hRf) hl₁
      (hp₁.trans ((congrArg (fun F => tail.exit.pc F _) hRf).trans (by decide +kernel))) hR
    rw [Valuation.allocsWith_nil _ hc, List.nil_append, ha₁, hal'] at hr
    obtain ⟨t₂, m₂, hS₂, hd₂⟩ := hr
    exact ⟨_, ⟨t₂, m₂, hS.trans_step hst hS₂, hd₂⟩, me, fun h => absurd h h0, fun _ => hq, rfl⟩

/-- **A thread of gemv_kernel from statement 41 of its entry block to its `ret`, at every `K`**
(test of one program, gemv_kernel float32 `b79a852b`): `MojoProofTest.GemvLoop.run`, then `thread`.
For every valid launch `L`, thread `k`, context `c` of gemv_kernel's program and thread `k`'s
environment, thread `t` whose only frame `f` is at statement 41 of the entry block `%6`, memory `m`,
sizes, row, blocks, matrix `A` and vector `v` meeting `run`'s premises: there is a memory `m₀` with
`m`'s blocks whose trace extends `m`'s by reads of `bA` or `bV` only
(`MojoProofTest.GemvLoop.ReadEv`; the memory at `%78`, which `run` reaches without the deliveries)
such that for all deliveries `d₁` to `d₅` of the binary32 `z₁` to `z₅`, with `d₅.2` holding the
output block `p0` as a writable buffer of `M` binary32 aligned to 4 that fits, the thread waits at
`%78`'s five shuffles as `waits` states them at step `n`, sum `x` and memory `m₀`, and runs to its
end on a memory that is `me` with `f`'s `alloca` blocks dead, where `me` is, for lane 0, `d₅.2` with
`total c n x z₁ z₂ z₃ z₄ z₅` stored at element `r` of `p0`, and for the other lanes `d₅.2`. Here `x`
is `run`'s `%79` (the `dotLoop` with contraction, oracle numbers `oG c t.k`, of every 32nd factor
pair of row `r` from pair `laneid`) and `n = t.k + 21 + 19 a + 15 (⌈K / 32⌉ - a)` with
`a = (K + 31 - laneid) / 32` the step at which the thread reaches `%78`. The values the other lanes'
shuffles deliver are premises. -/
theorem to_ret (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (t : Thread) (m : Mem) (f : Frame) (ht : t.frames = [f])
    (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label) (hpc : f.pc = 41)
    (M K r p0 bA bV : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61) (hr : r < M)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨bA, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨bV, 0⟩))
    (hr10 : f.regs 10 = some (.bits 64 ((BitVec.ofNat 32 M).signExtend 64)))
    (hr11 : f.regs 11 = some (.bits 64 ((BitVec.ofNat 32 K).signExtend 64)))
    (hr35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)]))
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    ∃ m₀ : Mem, m₀.blocks = m.blocks ∧ Ext (ReadEv bA bV) m m₀ ∧
      ∀ (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt),
      d₁.1 = some (Val.ofFloat .float z₁) →
      d₂.1 = some (Val.ofFloat .float z₂) → d₃.1 = some (Val.ofFloat .float z₃) →
      d₄.1 = some (Val.ofFloat .float z₄) → d₅.1 = some (Val.ofFloat .float z₅) →
      d₅.2.Buffer p0 (M * 4) 4 true → d₅.2.Fits gemv.prog.layout p0 (M * 4) →
      RunsVia c (fun m' => ∃ me, ((L.env k).laneid = 0 →
          d₅.2.store gemv.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
            (total c (t.k + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
                15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32))
              (dotLoop true (oG c t.k) (Model.zero _ false)
                (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩))) z₁ z₂ z₃ z₄ z₅))
            ⟨p0, ((r * 4 : Nat) : Int)⟩ (some 4) = .ok me) ∧
          ((L.env k).laneid ≠ 0 → me = d₅.2) ∧
          m' = f.allocas.foldl (fun m b => m.setLive b false) me)
        (waits c (t.k + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
            15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32))
          (dotLoop true (oG c t.k) (Model.zero _ false)
            (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩))) z₁ z₂ z₃ z₄ m₀
          d₁ d₂ d₃ d₄ d₅) t m := by
  obtain ⟨t', m', f', hS, ht', hf', hl', hp', ha', -, hk', hb', hX, h80, q80, h37, -, h41⟩ :=
    run L hL k c hcp hce t m f [] ht hf hlb hpc M K r p0 bA bV hM hK hMK hr hr0 hr1 hr2 hr10 hr11
      hr35 hb0 hf0 hbA hbV hfA hfV A v hA hV
  refine ⟨m', hb', hX, fun d₁ d₂ d₃ d₄ d₅ z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄ hd₅ hy hfy => ?_⟩
  have h := thread c hcp t' m' f' ht' hf' hl' hp' f.allocas ha' (L.env k).laneid _ M r p0 hr h80
    q80 h37 h41 d₁ d₂ d₃ d₄ d₅ z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄ hd₅ hy hfy
  rw [hk'] at h
  exact RunsVia.of_steps hS h

/--
info: mojo_obl: open goal
  Cond.Holds ((Valuation.entry c k m f).resume seg_0.toSummary
      (resReg gemv.fn_0 gemv.fn_0.b_10.label 2) d)
    (vals ((Valuation.entry c k m f).resume seg_0.toSummary
      (resReg gemv.fn_0 gemv.fn_0.b_10.label 2) d)
      seg_1.toSummary.nodes)
    (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `thread` at the first `fadd`** (test of gemv_kernel): for every context `c`,
step count `k`, memory `m`, frame `f` of `gemv`'s function whose `%79` is the binary32 `x` and
which records no `fmul contract` operands, stated as `f.prods = fun _ => none`, and delivery `d`
of the binary32 `z`: node 1 of `seg_1` (`%83 = fadd contract %79, %82`) has a value at the
valuation resumed after the first shuffle. mojo_obl finds no hypothesis `f.prods 80 = none`, so
it does not know whether `%79` is a product to contract with and leaves the obligation open, as
logged; it closes it with that equation. -/
theorem fadd_open (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0)
    (x : Model FloatTy.float.fmt) (h80 : f.regs 80 = some (.ofFloat .float x))
    (hq : f.prods = fun _ => none) (d : Option Val × Mem) (z : Model FloatTy.float.fmt)
    (hd : d.1 = some (.ofFloat .float z)) :
    Cond.Holds ((Valuation.entry c k m f).resume seg_0.toSummary
        (resReg gemv.fn_0 gemv.fn_0.b_10.label 2) d)
      (vals ((Valuation.entry c k m f).resume seg_0.toSummary
        (resReg gemv.fn_0 gemv.fn_0.b_10.label 2) d) seg_1.toSummary.nodes) (.ok (.node 1)) := by
  mojo_obl
  have hq80 : f.prods 80 = none := congrFun hq 80
  mojo_obl

end MojoProofTest.GemvLoopTail
