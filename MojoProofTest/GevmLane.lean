import MojoProofTest.OblGevmThread
import MojoProofTest.GemvLoopTail
import MojoProof.Sym.WaitVia
import MojoProof.Sym.WarpRoute

/-!
# gevm_kernel's `%59` on one thread, its waits as `Piece.Wait.via` states them

`OblGevmThread.thread` (MojoProofTest/OblGevmThread.lean) runs a thread of gevm_kernel (`gevm`)
from statement 1 of `%59` through the barrier at 6 and the five `shfl.sync.bfly` calls at 11, 15,
19, 23 and 27 to its `ret`, each wait stated by its position and intrinsic only. Here the waits
are stated whole, as `WarpRun.of_waits` and `warp_route`'s lane step (`RunsVia.of_block`,
MojoProof/Sym/WarpRoute.lean) take them.

* `waits`: the six calls as waits (`Piece.Wait`): the barrier `call
  @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)` at 6 on the memory after the store of `%60`;
  then the shuffles `shfl.sync.bfly(i32 -1, v, i32 o, i32 31)` with the full mask, the bits `v`
  of the sum so far (the shared array's cell `tid.x`, then each `fadd`'s, `GemvLoopTail.addAt`),
  the offsets `o` 16, 8, 4, 2, 1 and the clamp 31 (lines 79-100 of the corpus file
  gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll), the first on the
  barrier's delivered memory with the load of the cell logged, the others on the previous
  delivery's.
* `thread`: **one theorem for every thread of gevm_kernel at `%59`**, for every context, memory,
  frame and deliveries meeting the premises: `OblGevmThread.thread`'s run with the waits as
  `waits` states them (`RunsVia.of_through_via`; the barrier's memory by `M₀`'s store, the first
  shuffle's by `SEff.apply_load`; `shflseg` for the other four).
* The last test: `RunsVia.of_block` turns `thread` into `WarpRun.of_waits`'s lane form at `J = 6`.

Tests of one program, gevm_kernel float32 `1308aaae`; the lemmas and tactics they use
(MojoProof/Sym/OblSeg.lean, MojoProof/Sym/WaitVia.lean, MojoProof/Sym/WarpRoute.lean) are for
every program.
-/

namespace MojoProofTest.GevmLane

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.OblGevm MojoProofTest.OblGevmThread
open FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.GemvLoopTail (addAt)

/-- **`%59`'s six calls as waits** (`Piece.Wait`), for a thread of gevm_kernel at step `k0` in
context `c`, with shared block `b`, `tid.x = x`, the binary32 `s` the thread loads from cell `x`,
the binary32 `z₁` to `z₄` the first four shuffles deliver, memory `M₀` and deliveries `d₀` (the
barrier's) to `d₅` (the fifth shuffle's). The barrier at statement 6 of `%59` with argument
`i32 0` on `M₀`, resumed with `d₀`; the `i`-th shuffle, `i` from 1 to 5, at statement `7 + 4 i`
(11, 15, 19, 23, 27), `shfl.sync.bfly` with the full mask (`i32 -1`), the bits of the sum so far,
the offset `2 ^ (5 - i)` (16, 8, 4, 2, 1) and the clamp 31, resumed with `dᵢ`: the first on
`d₀.2` with the load of 4 bytes at offset `4 x` of `b` by `c`'s thread logged, the others on
`dᵢ₋₁.2`. The sum so far is `s` for the first, then the previous `fadd`'s (`addAt` at steps
`k0 + 12`, `k0 + 16`, `k0 + 20`, `k0 + 24`). A test definition. -/
def waits (c : Ctx) (k0 b x : Nat) (s z₁ z₂ z₃ z₄ : Model FloatTy.float.fmt) (M₀ : Mem)
    (d₀ d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) : List Piece.Wait :=
  [⟨6, .barrier, [.bits 32 (BitVec.ofInt 32 0)], M₀, d₀⟩,
    ⟨11, .shfl .bfly, [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float s,
        .bits 32 (BitVec.ofInt 32 16), .bits 32 (BitVec.ofInt 32 31)],
      d₀.2.log (.access ⟨c.who, ⟨b, ((x * 4 : Nat) : Int)⟩, 4, false, none, false⟩), d₁⟩,
    ⟨15, .shfl .bfly, [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float (addAt c (k0 + 12) s z₁),
        .bits 32 (BitVec.ofInt 32 8), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩,
    ⟨19, .shfl .bfly, [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 16) (addAt c (k0 + 12) s z₁) z₂),
        .bits 32 (BitVec.ofInt 32 4), .bits 32 (BitVec.ofInt 32 31)], d₂.2, d₃⟩,
    ⟨23, .shfl .bfly, [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 20) (addAt c (k0 + 16) (addAt c (k0 + 12) s z₁) z₂) z₃),
        .bits 32 (BitVec.ofInt 32 2), .bits 32 (BitVec.ofInt 32 31)], d₃.2, d₄⟩,
    ⟨27, .shfl .bfly, [.bits 32 (BitVec.ofInt 32 (-1)),
        .ofFloat .float (addAt c (k0 + 24)
          (addAt c (k0 + 20) (addAt c (k0 + 16) (addAt c (k0 + 12) s z₁) z₂) z₃) z₄),
        .bits 32 (BitVec.ofInt 32 1), .bits 32 (BitVec.ofInt 32 31)], d₄.2, d₅⟩]

/-- `shflseg`: `mojo_seg` with the shuffle's wait as `Piece.Wait.via` states it
(`RunsVia.of_through_via`): the position, the collective and the memory by `rfl`, the argument
values by `SVal.mapM_shfl` with the offered value from its node (`obl_exact`). -/
local macro "shflseg" : tactic => `(tactic| (
  refine RunsVia.of_through_via ‹Seg.Through _ _ _ _ (_ :: _) _ _ _ _›
    (by first | assumption | rfl) ‹_› ‹_› ‹_› (by rfl) rfl ?_ (by rfl) (by rfl)
    (by
      refine SVal.mapM_shfl _ _ _ ?_
      exact SVal.eval_node (by obl_exact)) (by rfl) ?_
  rotate_left
  intro _ _ _ _ _ _ _ _
  rotate_left
  mojo_obl))

/-- **A thread of gevm_kernel from `%59` to its `ret`, its six waits as `Piece.Wait.via` states
them.** One program, gevm_kernel float32 `1308aaae`. For every context `c` of its program, thread
`t` whose only frame `f`, with no `alloca` blocks, is of `gevm`'s function at statement 1 of
`%59`, memory `m`, lane `l < 32`, warp `w < 32`, `tid.x = x < 1024`, sum `acc`, output buffer
`p0` of `N` binary32 and cell `o < N`, shared block `b` owned by thread block `g`, memory `M₀`,
deliveries `d₀` (the barrier's) to `d₅` (the fifth shuffle's) and vector `A` of 1024 binary32,
with `OblGevmThread.thread`'s premises (`f`'s `%13`, `%11`, `%10` the 64-bit words of `l`, `w`,
`x`, `%60` is `acc` and `%29` the pointer to cell `o` of `p0`; `c` gives the shared array the
pointer to offset 0 of `b`; `m` and `d₀.2` have at `b` a writable buffer of 4096 bytes of shared
memory aligned to 4, owned by `g`, which admits `c`'s thread, that fits in space 3, `d₀.2`'s
holding `A`; the shuffles deliver the binary32 `z₁` to `z₅`; `d₅.2` has `p0` as a writable
buffer of `N` binary32 aligned to 4 that fits) and `M₀` the memory `m.store` gives for `acc` at
cell `32 l + w` of `b`: the thread waits at the six calls as `waits c t.k b x s z₁ z₂ z₃ z₄ M₀
d₀ … d₅` states them at `%59` (`s` is `A`'s cell `x`), resumed each time with the delivery, and
runs to its end on a memory `m'` that is, for lane 0, `d₅.2` with the sum `s₅` stored at cell
`o` of `p0`, and for the other lanes `d₅.2`; `s₀ = s` and `sᵢ = addAt c (t.k + 8 + 4 i) sᵢ₋₁ zᵢ`
(the `fadd`'s IEEE sum, round to nearest, delivered with its step's oracle number). The
deliveries are premises (`z₁` to `z₅` and `d₀.2`'s array, not the other lanes' values). -/
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
    (M₀ : Mem) (hM₀ : m.store gevm.prog.layout c.who 3 (.fp .float) (.bits 32 acc)
      ⟨b, (((l * 32 + w) * 4 : Nat) : Int)⟩ (some 4) = .ok M₀)
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
          (addAt c (t.k + 28) (addAt c (t.k + 24) (addAt c (t.k + 20) (addAt c (t.k + 16)
            (addAt c (t.k + 12) (TorchLean.Tensor.Rep.get A (⟨x, hx⟩, ())) z₁) z₂) z₃) z₄) z₅))
          ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) = .ok m') ∧ (l ≠ 0 → m' = d₅.2))
      ((waits c t.k b x (TorchLean.Tensor.Rep.get A (⟨x, hx⟩, ())) z₁ z₂ z₃ z₄ M₀
        d₀ d₁ d₂ d₃ d₄ d₅).map (Piece.Wait.via gevm.fn_0 gevm.fn_0.b_5.label)) t m := by
  have hT := Seg.through hcp segs_eq (fun i => [d₀, d₁, d₂, d₃, d₄, d₅].getD i d₀) (m := m) ht hf
    hlb hpc
  simp only [waits, List.map_cons, List.map_nil]
  have hp : (SVal.node 4).eval (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) seg_0.toSummary.nodes) =
      .ok (.ptr ⟨b, (((l * 32 + w) * 4 : Nat) : Int)⟩) := SVal.eval_node (by obl_exact)
  have hM : SEff.run (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) seg_0.toSummary.nodes) seg_0.effs = .ok M₀ :=
    (SEff.run_store_eq (V := Valuation.entry c t.k m f) (lbl := gevm.fn_0.b_5.label) (pc := 5)
      (a := 3) (t := .fp .float) (al := some 4) hf hcp (by rfl) (SVal.eval_reg h60) hp).trans hM₀
  -- the barrier: argument `i32 0`, memory `M₀`
  refine RunsVia.of_through_via hT rfl hf hpc ha (by rfl) rfl ?_ (by rfl) (by rfl) (by rfl) hM ?_
  rotate_left
  intro _ _ _ _ _ _ _ _
  rotate_left
  mojo_obl
  -- the first shuffle, after the load of cell `x`: its memory logs the load
  refine RunsVia.of_through_via ‹Seg.Through _ _ _ _ (_ :: _) _ _ _ _›
    (by assumption) ‹_› ‹_› ‹_› (by rfl) rfl ?_ (by rfl) (by rfl)
    (by
      refine SVal.mapM_shfl _ _ _ ?_
      exact SVal.eval_node (by obl_exact))
    (by
      exact (SEff.foldlM_cons_ok (SEff.apply_load (Valuation.stmt_of_fn (by exact hf) (by rfl))
        (SVal.eval_node (by obl_exact))) rfl).trans
          (by simp only [Valuation.resume, Valuation.entry, hcp]; rfl)) ?_
  rotate_left
  intro _ _ _ _ _ _ _ _
  rotate_left
  mojo_obl
  -- the other four shuffles, no memory effect before them
  shflseg
  shflseg
  shflseg
  shflseg
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

/-- **`warp_route`'s lane step takes `thread`**: at `J = 6`, every label function `lbl` that is
`%59`'s below 6 and every default wait `d`, `RunsVia.of_block` turns `thread`'s run into the run
through the waits `(waits …).getD i d` at `Piece.Wait.via gevm.fn_0 (lbl i)`, `WarpRun.of_waits`'s
lane form, for every context, thread and memory meeting `thread`'s premises. -/
example (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
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
    (M₀ : Mem) (hM₀ : m.store gevm.prog.layout c.who 3 (.fp .float) (.bits 32 acc)
      ⟨b, (((l * 32 + w) * 4 : Nat) : Int)⟩ (some 4) = .ok M₀)
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
    (hy : d₅.2.Buffer p0 (N * 4) 4 true) (hfy : d₅.2.Fits gevm.prog.layout p0 (N * 4))
    (lbl : Nat → Nat) (hl6 : ∀ i < 6, lbl i = gevm.fn_0.b_5.label) (d : Piece.Wait) :
    RunsVia c (fun m' => (l = 0 →
        d₅.2.store gevm.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
          (addAt c (t.k + 28) (addAt c (t.k + 24) (addAt c (t.k + 20) (addAt c (t.k + 16)
            (addAt c (t.k + 12) (TorchLean.Tensor.Rep.get A (⟨x, hx⟩, ())) z₁) z₂) z₃) z₄) z₅))
          ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) = .ok m') ∧ (l ≠ 0 → m' = d₅.2))
      ((List.range 6).map fun i => ((waits c t.k b x (TorchLean.Tensor.Rep.get A (⟨x, hx⟩, ()))
        z₁ z₂ z₃ z₄ M₀ d₀ d₁ d₂ d₃ d₄ d₅).getD i d).via gevm.fn_0 (lbl i)) t m :=
  RunsVia.of_block (thread c hcp t m f ht hf hlb hpc ha l w x hl hw hx acc p0 N o ho h13 h11 h10
    h60 h29 b g hg hB hin hF M₀ hM₀ d₀ d₁ d₂ d₃ d₄ d₅ A hB₀ hF₀ hA z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄
    hd₅ hy hfy) rfl hl6 fun _ h => h

end MojoProofTest.GevmLane
