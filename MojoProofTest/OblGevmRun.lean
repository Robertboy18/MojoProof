import MojoProofTest.OblGevmThread
import MojoProof.Sym.LoopFacts
import MojoProof.Sem.WarpDot
import MojoProofTest.KernelRfl

/-!
# gevm_kernel's thread from its entry through its loop, for every size

Tests of one program, gevm_kernel at float32 with `tile_size = 1024` (MojoProofTest/SymLane.lean's
`gevm`, tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll):
the thread's run from the entry block `%6` through the `(K + 31) / 32` rounds of its loop
(`%37`, `%45`, `%54`) and the loop's exit block `%57` to position 1 of block `%59`, for every
launch with 1024 threads per block, every `N` and `K` with `K % 32 = 0`, `K < 2 ^ 31` and
`K * N < 2 ^ 29`, and every input vector `A` and matrix `B` in memory. The trip count is
symbolic: `ChainWith.loop` takes the rounds as one premise over `j < (K + 31) / 32`
(`round_inv`, from MojoProofTest/OblGevm.lean's `rounds`), and `ChainWith.reach` runs them.

* `head`, `rnd`: the valuation after the entry block, and after one round of the loop.
* `steps`: their contexts, functions and step counts (`LoopSeg.steps_k`).
* `oG`, `Inv`: the oracle numbers of round `j`'s `fmul` and `fadd` (the contraction choice), and
  the loop invariant: `%42` is `j`, `%44` the `dotLoop` of the first `j` of the thread's pairs.
* `round_inv`: round `j` runs and keeps `Inv`.
* `loop`: from the entry to block `%59`, with `%60` the `dotLoop` of the thread's strided pairs
  (every 32nd pair of row `A` and column `col` of `B`, from the warp number `tid.x / 32`) and
  `%13`, `%11`, `%10`, `%29` the lane, warp number, thread number and the output pointer.
* Two `example`s: `loop` at `K = N = 64` (two rounds) and at the corpus file's launch,
  `K = N = 4096` (128 rounds).

The block size 1024 is the specialization's: its loop's stride `32` warps, its shared array of
1024 floats and the premise `ntid.x = 1024` come from `tile_size = 1024`; the other
specialization in the corpus, tests/corpus/gevm_t512/ (`tile_size = 512`), has stride 16, a
512-float array and four shuffles, and is a different program.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.OblGevm
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.OblGevmRun

/-- The valuation after gevm_kernel's entry block `%6` (`MojoProofTest.OblGevm.entry`), from
`V`. A test definition. -/
abbrev head (V : Valuation) : Valuation :=
  Valuation.roundWith true gevm.fn_0.b_0.label MojoProofTest.OblGevm.entry [] V

/-- The valuation after one round of gevm_kernel's loop (`gevmL`: `%37`, `%45`, `%54`), from
`W`. A test definition. -/
abbrev rnd (W : Valuation) : Valuation := Valuation.roundWith true gevmL.h gevmL.H gevmL.B W

/-- The valuation at the loop's latch `%54`, after the header `%37` and the body `%45`, from
`W`. A test definition. -/
abbrev latchAt (W : Valuation) : Valuation := (W.lastWith true gevmL.h gevmL.H gevmL.B).1

/-- **Step counts** (test): for every valuations `V`, `W` and number `j`, `head V` has `V`'s
context and function and 33 more steps, `j` rounds from `W` keep its context and function and
take `17 * j` steps, and the latch is 3 steps after `W` (`LoopSeg.steps_k`). -/
theorem steps (V W : Valuation) (j : Nat) :
    (head V).ctx = V.ctx ∧ (head V).fn = V.fn ∧ (head V).k = V.k + 33 ∧
      (rnd^[j] W).ctx = W.ctx ∧ (rnd^[j] W).fn = W.fn ∧ (rnd^[j] W).k = W.k + 17 * j ∧
      (latchAt W).ctx = W.ctx ∧ (latchAt W).k = W.k + 3 :=
  LoopSeg.steps_k true _ _ _ gevmL (by decide +kernel) (by decide +kernel)
    (by decide +kernel) V W j

/-- The oracle numbers of round `j` of gevm_kernel's loop on a thread at step count `k0` in
context `c`: of the `fmul` at statement 11 and of the `fadd` at statement 12 of the body `%45`
(steps `k0 + 47 + 17 * j` and `k0 + 48 + 17 * j`), which choose the contraction. A test
definition. -/
def oG (c : Ctx) (k0 j : Nat) : Nat × Nat :=
  (c.oracle (Nat.pair (k0 + 47 + 17 * j) 0), c.oracle (Nat.pair (k0 + 48 + 17 * j) 0))

/-- **The loop invariant** at round `j` (test definition): at `W`, `%42` is `j`, `%44` is the
`dotLoop` (with contraction, oracle numbers `o`) of the first `j` pairs of `ps` from `+0`, and
`%44` has no recorded product. -/
def Inv (o : Nat → Nat × Nat) (ps : List (Model FloatTy.float.fmt × Model FloatTy.float.fmt))
    (j : Nat) (W : Valuation) : Prop :=
  W.regs 42 = some (.bits 64 (BitVec.ofNat 64 j)) ∧
    W.regs 44 = some (.ofFloat .float (dotLoop true o (Model.zero _ false) (ps.take j))) ∧
    W.prods 44 = none

/-- **A round keeps the invariant** (test): for every `K`, `N` with `K % 32 = 0`, `K < 2 ^ 31`,
`K * N < 2 ^ 29`, warp number `w < 32`, column `col < N`, valuation `V` of gevm_kernel whose
entry block gives the loop's bound, `w`, `N`, `col`, the pointers `bA`, `bB` and the buffers of
`A` (`K` floats) and `B` (`K × N`, row-major), and `j < K / 32`: at `W = rnd^[j] (head V)`, if
`Inv` holds for `j` with the strided pairs of `A` and column `col` of `B`, round `j` runs
(`RoundWith`, MojoProofTest/OblGevm.lean's `rounds`) and `Inv` holds for `j + 1` after it. -/
theorem round_inv {K N w col bA bB : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} (hK32 : K % 32 = 0) (hK : K < 2 ^ 31)
    (hKN : K * N < 2 ^ 29) (hw : w < 32) (hc : col < N) {V : Valuation}
    (hP : V.ctx.prog = gevm.prog) (hfn : V.fn = gevm.fn_0)
    (g38 : (head V).regs 38 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (g11 : (head V).regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (g8 : (head V).regs 8 = some (.bits 64 (BitVec.ofNat 64 N)))
    (g17 : (head V).regs 17 = some (.bits 64 (BitVec.ofNat 64 col)))
    (g1 : (head V).regs 1 = some (.ptr ⟨bA, 0⟩)) (g2 : (head V).regs 2 = some (.ptr ⟨bB, 0⟩))
    (gbA : (head V).mem.Buffer bA (K * 4) 4 false)
    (gbB : (head V).mem.Buffer bB (K * N * 4) 4 false)
    (gfA : (head V).mem.Fits gevm.prog.layout bA (K * 4))
    (gfB : (head V).mem.Fits gevm.prog.layout bB (K * N * 4))
    (gA : (head V).mem.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (gB : (head V).mem.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B)
    {j : Nat} (hj : j < K / 32) {W : Valuation} (hW : W = rnd^[j] (head V))
    (hI : Inv (oG V.ctx V.k) (stride 32 w (vecMatPairs A B ⟨col, hc⟩)) j W) :
    RoundWith true gevmL.h gevmL.p gevmL.dh gevmL.H gevmL.B W ∧
      Inv (oG V.ctx V.k) (stride 32 w (vecMatPairs A B ⟨col, hc⟩)) (j + 1) (rnd W) := by
  obtain ⟨s1, s2, s3, r1, r2, r3, -, -⟩ := steps V (head V) j
  obtain ⟨-, -, -, -, -, -, l1, l2⟩ := steps V W 0
  have hWc : W.ctx = V.ctx := by rw [hW, r1, s1]
  have hWP : W.ctx.prog = gevm.prog := hWc ▸ hP
  have hWf : W.fn = gevm.fn_0 := by rw [hW, r2, s2, hfn]
  have hWk : W.k = V.k + 33 + 17 * j := by rw [hW, r3, s3]
  have hHf : (head V).fn = gevm.fn_0 := s2.trans hfn
  have k38 : W.regs 38 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g38 j
  have k11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g11 j
  have k8 : W.regs 8 = some (.bits 64 (BitVec.ofNat 64 N)) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g8 j
  have k17 : W.regs 17 = some (.bits 64 (BitVec.ofNat 64 col)) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g17 j
  have k1 : W.regs 1 = some (.ptr ⟨bA, 0⟩) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g1 j
  have k2 : W.regs 2 = some (.ptr ⟨bB, 0⟩) := by
    rw [hW]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g2 j
  have hb : W.mem.blocks = (head V).mem.blocks := by
    rw [hW]; exact (Valuation.iterate_blocks (c := true) (L := gevmL) (rs := [1, 2])
      (by decide +kernel) hHf (by simp [g1, g2]) j).1
  have hq := Mem.blocks_keep hb
  have wbA := gbA.of_block (hq bA)
  have wbB := gbB.of_block (hq bB)
  have wfA := gfA.of_block (hq bA)
  have wfB := gfB.of_block (hq bB)
  have wA := gA.of_block (hq bA)
  have wB := gB.of_block (hq bB)
  obtain ⟨h42, h44, p44⟩ := hI
  refine ⟨rounds K N w col bA bB j _ A B W hK32 hK hKN hw hc (by omega) hWP hWf h42 k38 h44 k11
    k8 k17 k1 k2 wbA wbB wfA wfB wA wB, ?_⟩
  obl_have e42 : (rnd W).regs 42, e44 : (rnd W).regs 44, q44 : (rnd W).prods 44
  refine ⟨e42, ?_, q44⟩
  have hctx (c l S) (V : Valuation) : (V.intoWith c l S).ctx = V.ctx :=
    (Valuation.intoWith_k _ _ _ _).1
  have hX : (Valuation.intoWith true (Valuation.intoWith true W gevmL.h gevmL.H)
      gevm.fn_0.b_2.label body).k = V.k + 36 + 17 * j := l2.trans (by omega)
  rw [hX] at e44
  simp only [hctx, hWc] at e44
  rw [show V.k + 36 + 17 * j + 11 = V.k + 47 + 17 * j by omega,
    show V.k + 36 + 17 * j + 12 = V.k + 48 + 17 * j by omega] at e44
  have hl : j < (stride 32 w (vecMatPairs A B ⟨col, hc⟩)).length := by
    rw [length_stride hw]; simp only [vecMatPairs, List.length_ofFn]; split <;> omega
  have ea : (stride 32 w (vecMatPairs A B ⟨col, hc⟩))[j] =
      (A.getScalar ⟨j * 32 + w, by omega⟩,
        TorchLean.Tensor.get2 B ⟨j * 32 + w, by omega⟩ ⟨col, hc⟩) := by
    have h := getElem?_stride hw j (vecMatPairs A B ⟨col, hc⟩)
    rw [List.getElem?_eq_getElem hl, show 32 * j + w = j * 32 + w by omega,
      List.getElem?_eq_getElem (by simp only [vecMatPairs, List.length_ofFn]; omega)] at h
    simpa only [vecMatPairs, List.getElem_ofFn, Option.some.injEq] using h
  rw [List.take_succ_eq_append_getElem hl, dotLoop_append, List.length_take,
    Nat.min_eq_left hl.le, ea, TorchLean.Tensor.getScalar_eq_apply, TorchLean.Tensor.get2_eq_apply]
  exact e44

/-- **gevm_kernel's thread through its loop, for every size** (test): for every launch `L` with
1024 threads per block in `x`, thread `k`, context `c` of gevm_kernel's program and environment,
thread `t` whose top frame `f` is at the start of the entry block, `N < 2 ^ 31`, `K < 2 ^ 31` with
`K % 32 = 0` and `K * N < 2 ^ 29`, output buffer `p0` (`N` floats), the buffers of `A` (`K`
floats at `bA`) and `B` (`K × N` floats, row-major, at `bB`) in memory `m`, and thread `k`'s
output row and column below `N`: the thread steps to a frame at position 1 of block `%59` (the
warp reduction) with the same `alloca` blocks and destination, `36 + 17 * (K / 32)` steps later,
on a memory with `m`'s blocks, where `%60` is the `dotLoop` (with contraction, oracle numbers
`oG c t.k`) from `+0` of every 32nd factor pair of `A` and column `ctaid.x * 32 + laneid` of `B`,
from pair `tid.x / 32` (`stride`, `vecMatPairs`), `%13` the lane, `%11` the warp number,
`%10` the thread number and `%29` the pointer to element `ctaid.x * 32 + tid.x / 32` of the
output. One program; the trip count `(K + 31) / 32` is symbolic. -/
theorem loop (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gevm.prog)
    (hce : c.env = L.env k) (hn : (L.env k).sreg .ntid .x = 1024) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_0.label) (hpc : f.pc = 0) (N K p0 bA bB : Nat)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨bA, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨bB, 0⟩))
    (hr4 : f.regs 4 = some (.bits 32 (BitVec.ofNat 32 N)))
    (hr5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (hb0 : m.Buffer p0 (N * 4) 4 true) (hf0 : m.Fits gevm.prog.layout p0 (N * 4))
    (hbA : m.Buffer bA (K * 4) 4 false) (hbB : m.Buffer bB (K * N * 4) 4 false)
    (hfA : m.Fits gevm.prog.layout bA (K * 4)) (hfB : m.Fits gevm.prog.layout bB (K * N * 4))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N])
    (hA : m.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (hB : m.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B)
    (hy : (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 < N)
    (hc : (L.env k).sreg .ctaid .x * 32 + (L.env k).laneid < N) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = gevm.fn_0 ∧
      f'.label = gevm.fn_0.b_5.label ∧ f'.pc = 1 ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      t'.k = t.k + 36 + 17 * (K / 32) ∧ m'.blocks = m.blocks ∧
      f'.regs 60 = some (.ofFloat .float (dotLoop true (oG c t.k) (Model.zero _ false)
        (stride 32 ((L.env k).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩)))) ∧
      f'.regs 13 = some (.bits 64 (BitVec.ofNat 64 (L.env k).laneid)) ∧
      f'.regs 11 = some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x / 32))) ∧
      f'.regs 10 = some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x))) ∧
      f'.regs 29 = some (.ptr ⟨p0, ((((L.env k).sreg .ctaid .x * 32 +
        (L.env k).sreg .tid .x / 32) * 4 : Nat) : Int)⟩) := by
  have hE := entry_edge L hL k c hcp hce hn t.k m f hf N K p0 hN hK hr0 hr4 hr5 hb0 hf0 hy
  have hlane := Launch.laneid_lt L k
  obtain ⟨htid, -, -⟩ := Launch.sreg_lt hL k .x
  obl_have g42 : (head (Valuation.entry c t.k m f)).regs 42,
    g44 : (head (Valuation.entry c t.k m f)).regs 44,
    q44 : (head (Valuation.entry c t.k m f)).prods 44,
    g38 : (head (Valuation.entry c t.k m f)).regs 38,
    g11 : (head (Valuation.entry c t.k m f)).regs 11,
    g8 : (head (Valuation.entry c t.k m f)).regs 8,
    g17 : (head (Valuation.entry c t.k m f)).regs 17,
    g1 : (head (Valuation.entry c t.k m f)).regs 1,
    g2 : (head (Valuation.entry c t.k m f)).regs 2,
    g13 : (head (Valuation.entry c t.k m f)).regs 13,
    g10 : (head (Valuation.entry c t.k m f)).regs 10,
    g29 : (head (Valuation.entry c t.k m f)).regs 29,
    gm : (head (Valuation.entry c t.k m f)).mem
  have hw : (L.env k).sreg .tid .x / 32 < 32 := by omega
  obtain ⟨-, s2, s3, -, -, -, -, -⟩ :=
    steps (Valuation.entry c t.k m f) (head (Valuation.entry c t.k m f)) 0
  have hHf : (head (Valuation.entry c t.k m f)).fn = gevm.fn_0 := s2.trans hf
  have g38' : (head (Valuation.entry c t.k m f)).regs 38 =
      some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) :=
    g38.trans (word_eq (by
      simp only [Nat.reducePow, Nat.reduceSub, Nat.reduceAdd]
      rw [Nat.max_eq_left (Nat.zero_le _)]; omega))
  have g11' : (head (Valuation.entry c t.k m f)).regs 11 =
      some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x / 32))) := g11.trans (word_eq rfl)
  have g8' : (head (Valuation.entry c t.k m f)).regs 8 = some (.bits 64 (BitVec.ofNat 64 N)) :=
    g8.trans (word_eq (by omega))
  have g17' : (head (Valuation.entry c t.k m f)).regs 17 =
      some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .ctaid .x * 32 + (L.env k).laneid))) :=
    g17.trans (word_eq rfl)
  have g13' : (head (Valuation.entry c t.k m f)).regs 13 =
      some (.bits 64 (BitVec.ofNat 64 (L.env k).laneid)) := g13.trans (word_eq (by omega))
  have g10' : (head (Valuation.entry c t.k m f)).regs 10 =
      some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x))) := g10.trans (word_eq (by omega))
  have g29' : (head (Valuation.entry c t.k m f)).regs 29 =
      some (.ptr ⟨p0, ((((L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32) * 4 : Nat) :
        Int)⟩) :=
    g29.trans (ptr_eq (by show (((_ : Nat) * 1024 + _) / 32 + 0) * 4 = _; omega))
  have gbA : (head (Valuation.entry c t.k m f)).mem.Buffer bA (K * 4) 4 false := by
    rw [gm]; exact hbA
  have gbB : (head (Valuation.entry c t.k m f)).mem.Buffer bB (K * N * 4) 4 false := by
    rw [gm]; exact hbB
  have gfA : (head (Valuation.entry c t.k m f)).mem.Fits gevm.prog.layout bA (K * 4) := by
    rw [gm]; exact hfA
  have gfB : (head (Valuation.entry c t.k m f)).mem.Fits gevm.prog.layout bB (K * N * 4) := by
    rw [gm]; exact hfB
  have gA : (head (Valuation.entry c t.k m f)).mem.Holds gevm.prog.layout bA (.fp .float)
      (Val.ofFloat .float) (rowMajor gevm.prog.layout (.fp .float) 0) A := by rw [gm]; exact hA
  have gB : (head (Valuation.entry c t.k m f)).mem.Holds gevm.prog.layout bB (.fp .float)
      (Val.ofFloat .float) (rowMajor gevm.prog.layout (.fp .float) 0) B := by rw [gm]; exact hB
  have hC : ChainWith true (fun W l ds S E => l = gevmL.h ∧ ds = gevmL.dh ∧ S = gevmL.H ∧
      E = gevmL.X ∧ W = rnd^[(K + 31) / 32] (head (Valuation.entry c t.k m f)) ∧
        Inv (oG c t.k) (stride 32 ((L.env k).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩))
          ((K + 31) / 32) W)
      [gevmL] (Valuation.entry c t.k m f) gevm.fn_0.b_0.label MojoProofTest.OblGevm.entry.obls
      MojoProofTest.OblGevm.entry [] :=
    .loop (fun j W => W = rnd^[j] (head (Valuation.entry c t.k m f)) ∧
        Inv (oG c t.k) (stride 32 ((L.env k).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩)) j W)
      ((K + 31) / 32) hE ⟨rfl, g42.trans (by kernel_rfl), g44.trans (by kernel_rfl), q44⟩
      (fun j hj W hI => .last (by
        obtain ⟨hR, hI'⟩ := round_inv (V := Valuation.entry c t.k m f) hK32 hK hKN hw hc hcp hf
          g38' g11' g8' g17' g1 g2 gbA gbB gfA gfB gA gB (by omega) hI.1 hI.2
        refine ⟨hR, ?_, hI'⟩
        rw [Function.iterate_succ_apply', ← hI.1]))
      (fun W hW => .last ⟨rfl, rfl, rfl, rfl, hW⟩)
  obtain ⟨t₁, m₁, f₁, p₁, l₁, ds₁, S₁, E₁, hS₁, ht₁, hf₁, hl₁, hp₁, ⟨_, ha₁, -⟩, hd₁, hc₁, rfl, rfl,
    rfl, rfl, hW₁, h42₁, h44₁, -⟩ := hC.reach (alloca := false) hcp (by decide +kernel) ht hf hlb
      hpc rfl
  have k38 : (Valuation.entry c t₁.k m₁ f₁).regs 38 =
      some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) := by
    rw [hW₁]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g38' _
  have k11 : (Valuation.entry c t₁.k m₁ f₁).regs 11 =
      some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x / 32))) := by
    rw [hW₁]; exact LoopSeg.kept_round (c := true) (by decide +kernel) hHf g11' _
  have k13 : (Valuation.entry c t₁.k m₁ f₁).regs 13 =
      some (.bits 64 (BitVec.ofNat 64 (L.env k).laneid)) := by
    rw [hW₁]; exact Valuation.iterate_regs_keep hHf (by decide +kernel) (by decide +kernel) g13' _
  have k10 : (Valuation.entry c t₁.k m₁ f₁).regs 10 =
      some (.bits 64 (BitVec.ofNat 64 ((L.env k).sreg .tid .x))) := by
    rw [hW₁]; exact Valuation.iterate_regs_keep hHf (by decide +kernel) (by decide +kernel) g10' _
  have k29 : (Valuation.entry c t₁.k m₁ f₁).regs 29 =
      some (.ptr ⟨p0, ((((L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32) * 4 : Nat) :
        Int)⟩) := by
    rw [hW₁]; exact Valuation.iterate_regs_keep hHf (by decide +kernel) (by decide +kernel) g29' _
  have hlen : (stride 32 ((L.env k).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩)).length ≤
      (K + 31) / 32 := by
    rw [length_stride hw]; simp only [vecMatPairs, List.length_ofFn]; split <;> omega
  rw [List.take_of_length_le hlen] at h44₁
  have hP₁ : (Valuation.entry c t₁.k m₁ f₁).ctx.prog = gevm.prog := hcp
  have hF₁ : (Valuation.entry c t₁.k m₁ f₁).fn = gevm.fn_0 := hf₁
  have hX : EdgeWith true gevm.fn_0.b_5.label 1 (Valuation.entry c t₁.k m₁ f₁) gevmL.h gevmL.dh
      gevmL.H gevmL.X := by
    have hn' : (K + 31) / 32 < 2 ^ 31 := by omega
    generalize Valuation.entry c t₁.k m₁ f₁ = W₁ at hP₁ hF₁ h42₁ h44₁ k38 k11 k13 k10 k29 ⊢
    mojo_obl
  have hp₃ : ((Valuation.entry c t₁.k m₁ f₁).lastWith true gevmL.h gevmL.H gevmL.X).2.2.exit.pc
      f₁.fn gevm.fn_0.b_5.label = 1 := hX.2.2
  rw [hf₁] at hp₃
  obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₂, ha₂, -, hd₂, hV₂⟩ :=
    Block.sound_edge hcp hc₁ ht₁ hf₁ hl₁ hp₁ hX.1 hX.2.1
  rw [Valuation.allocsWith_nil _ hc₁, List.nil_append] at ha₂
  obtain ⟨-, -, -, -, -, r3, -, -⟩ :=
    steps (Valuation.entry c t.k m f) (head (Valuation.entry c t.k m f)) ((K + 31) / 32)
  have hk₁ : (Valuation.entry c t₁.k m₁ f₁).k = t.k + 33 + 17 * ((K + 31) / 32) := by
    rw [hW₁, r3, s3]; rfl
  have hm₁ : (Valuation.entry c t₁.k m₁ f₁).mem.blocks = m.blocks := by
    rw [hW₁]
    exact (Valuation.iterate_blocks (c := true) (L := gevmL) (rs := [1, 2]) (by decide +kernel) hHf
      (by simp [g1, g2]) _).1.trans (congrArg Mem.blocks gm)
  have hk₂ : t₂.k = (Valuation.roundWith true gevmL.h gevmL.H gevmL.X
      (Valuation.entry c t₁.k m₁ f₁)).k := congrArg Valuation.k hV₂
  have hm₂ : m₂ = (Valuation.roundWith true gevmL.h gevmL.H gevmL.X
      (Valuation.entry c t₁.k m₁ f₁)).mem := congrArg Valuation.mem hV₂
  have hr₂ : f₂.regs = (Valuation.roundWith true gevmL.h gevmL.H gevmL.X
      (Valuation.entry c t₁.k m₁ f₁)).regs := congrArg Valuation.regs hV₂
  generalize Valuation.entry c t₁.k m₁ f₁ = W₁ at *
  obl_have e60 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).regs 60,
    e13 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).regs 13,
    e11 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).regs 11,
    e10 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).regs 10,
    e29 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).regs 29,
    em : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).mem
  have e2 : (Valuation.roundWith true gevmL.h gevmL.H gevmL.X W₁).k =
      W₁.k + 1 * (pathLen gevmL.H gevmL.X + 1) :=
    (Valuation.roundWith_k true gevmL.h gevmL.H gevmL.X 1 W₁).2.2
  have e3 : pathLen gevmL.H gevmL.X + 1 = 3 := by decide +kernel
  refine ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₂.trans hp₃, ha₂.trans ha₁, hd₂.trans hd₁,
    by omega, by rw [hm₂, em]; exact hm₁, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hr₂]; exact e60
  · rw [hr₂]; exact e13
  · rw [hr₂]; exact e11
  · rw [hr₂]; exact e10
  · rw [hr₂]; exact e29

-- `loop` at two sizes: `K = N = 64` (two rounds of the loop) and the corpus file's launch,
-- `K = N = 4096` (128 rounds; tests/corpus/gemv/gemv_f32.mojo:81).
example := loop (N := 64) (K := 64) (hN := by decide) (hK := by decide) (hK32 := by decide)
  (hKN := by decide)

example := loop (N := 4096) (K := 4096) (hN := by decide) (hK := by decide) (hK32 := by decide)
  (hKN := by decide)

end MojoProofTest.OblGevmRun
