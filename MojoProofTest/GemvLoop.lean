import MojoProofTest.OblGemv
import MojoProof.Sym.LoopFacts
import MojoProof.Sym.SegTrace
import MojoProof.Tile.MatVec
import MojoProofTest.KernelRfl

/-!
# gemv_kernel's thread through its loop, at every `K`

Tests of one program, gemv_kernel at float32 (`gemv` of MojoProofTest/SymLane.lean, the corpus
file gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll): the run of a
thread of row `r` and lane `l` from statement 41 of the entry block `%6` through `%44`, the
`⌈K / 32⌉` rounds of the loop at `%54` and its exit `%59` to position 1 of `%78`, for every valid
launch, every `M, K < 2 ^ 31` with `M K < 2 ^ 61`, every row `r < M` and every matrix `A` and
vector `v` in memory. Round `i` goes through the arm `%70` (two loads, `fmul contract`,
`fadd contract`) when `32 i + l < K` and through `%75` (nothing) otherwise; the rounds through
`%70` come first, `(K + 31 - l) / 32` of them, then the rest through `%75`. The trip count is
symbolic: `ChainWith.loop` takes the rounds of each arm as one premise (`roundA_inv`,
`roundB_inv`, from MojoProofTest/OblGemv.lean's `roundA` and `roundB`), and `ChainWith.reach`
runs them, through `loopA` alone when every round goes through `%70` and through `loopA` then
`loopB` otherwise (MojoProofTest/SymGemvTail.lean's chains).

* `rA`, `rB`, `rX`, `two`, `two_eq`: a round through `%70`, through `%75`, the path out through
  `%59`, and `n` rounds through `%70` then `j` through `%75` after the entry
  (`MojoProofTest.OblGemv.head`), with their first and next values.
* `steps`: their contexts, functions and step counts (`LoopSeg.steps_k`).
* `keep`, `Facts`, `at_two`: the registers both arms keep, and the facts the rounds read, from the
  header after the entry to every `two n j` whose rounds through `%70` keep the blocks.
* `ReadEv`, `ext_mono`, `ext_reads`, `two_ext`: the trace's reads of the matrix and the vector
  (`Ext`, MojoProof/Sym/SegTrace.lean); the rounds through `%75` add none.
* `oG`, `Inv`, `len`: the oracle numbers of round `i`'s `fmul` and `fadd`, the loop invariant
  (`%55` is `i`, `%56` the `dotLoop` of the first `i` of the lane's strided pairs), and the
  number of those pairs.
* `roundA_inv`, `roundB_inv`: a round through each arm runs and keeps `Inv`; through `%70` it
  keeps the blocks and adds two reads of the matrix and the vector, through `%75` the sum.
* `chain`: the chain of both loops from the entry, with the rounds of each arm.
* `exit_edge`, `exit_regs`: the path out from the header after the last round to `%78`, and the
  registers and memory after it.
* `run`: from statement 41 of `%6` to position 1 of `%78`, with `%79` the `dotLoop` of the
  lane's strided pairs of row `r` and the vector, and `%37`, `%40`, `%41` the output pointer, the
  lane and lane 0's flag, on a memory whose trace extends the start's by reads of the matrix and
  the vector only.
* `pairs_eq`: those pairs are the pairs of the matrix-vector spec's input words
  (`MojoProof.Tile.bflyDeliver_holds`) when the words are `A`'s and `v`'s.
* Two `example`s: `run` at `K = 64` (two rounds, both through `%70`) and at `K = 40` (lanes
  `l ≥ 8` take their second round through `%75`); `run_mutant`: at `K = 40`, lane 8's pairs are
  not the row's in order, and its step count is not that of two rounds through `%70`.
-/

namespace MojoProofTest.GemvLoop

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymGemvTail MojoProofTest.OblGemv
open FloatLib.Floats.Formats.BinaryInterchange

/-- The valuation after one round of gemv_kernel's loop through `%70` (`loopA`), from `W`. A test
definition. -/
abbrev rA (W : Valuation) : Valuation := Valuation.roundWith true loopA.h loopA.H loopA.B W

/-- The valuation after one round of gemv_kernel's loop through `%75` (`loopB`), from `W`. A test
definition. -/
abbrev rB (W : Valuation) : Valuation := Valuation.roundWith true loopB.h loopB.H loopB.B W

/-- The valuation after gemv_kernel's path out of its loop, from the header `%54` through `%59`,
from `W`. A test definition. -/
abbrev rX (W : Valuation) : Valuation := Valuation.roundWith true loopA.h loopA.H [gB 63 0] W

/-- The valuation after the entry from `V` (`head`), `n` rounds through `%70` and `j` rounds
through `%75`. A test definition. -/
abbrev two (n j : Nat) (V : Valuation) : Valuation := rB^[j] (rA^[n] (head V))

/-- **The first and next rounds** (test): for every valuation `V` and counts `n`, `j`: no round is
`head V`, a round through `%70` after `n` of them is `n + 1` of them, and a round through `%75`
after `j` of them is `j + 1` of them. -/
theorem two_eq (V : Valuation) (n j : Nat) :
    two 0 0 V = head V ∧ rA (two n 0 V) = two (n + 1) 0 V ∧ rB (two n j V) = two n (j + 1) V := by
  refine ⟨?_, ?_, ?_⟩ <;> simp only [two, Function.iterate_zero_apply, Function.iterate_succ_apply']

/-- **Step counts** (test): for every valuations `V`, `W` and number `i`, `head V` has `V`'s
context and function and 18 more steps, and `i` rounds from `W` through `%70` (through `%75`)
keep its context and function and take `19 i` (`15 i`) steps (`LoopSeg.steps_k`). -/
theorem steps (V W : Valuation) (i : Nat) :
    (head V).ctx = V.ctx ∧ (head V).fn = V.fn ∧ (head V).k = V.k + 18 ∧
      (rA^[i] W).ctx = W.ctx ∧ (rA^[i] W).fn = W.fn ∧ (rA^[i] W).k = W.k + 19 * i ∧
      (rB^[i] W).ctx = W.ctx ∧ (rB^[i] W).fn = W.fn ∧ (rB^[i] W).k = W.k + 15 * i := by
  obtain ⟨a1, a2, a3, a4, a5, a6, -, -⟩ := LoopSeg.steps_k true 6 (gC 6 41) [gB 44 0] loopA
    (a := 18) (b := 19) (by decide +kernel) (by decide +kernel) rfl V W i
  obtain ⟨-, -, -, b4, b5, b6, -, -⟩ := LoopSeg.steps_k true 6 (gC 6 41) [gB 44 0] loopB
    (a := 18) (b := 15) (by decide +kernel) (by decide +kernel) rfl V W i
  exact ⟨a1, a2, a3, a4, a5, a6, b4, b5, b6⟩

/-- **The registers both arms keep** (test): for every valuation `W` of gemv_kernel's function,
register `r` among `%53`, `%40`, `%38`, `%11`, `%1`, `%2`, `%37` and `%41` (registers 54, 40,
38, 11, 1, 2, 37, 41), value `v` of `r` at `W` and counts `n`, `j`: `r` is `v` after `n` rounds
through `%70` and `j` through `%75` (`Valuation.iterate_regs_keep`: no `phi` and no block of
either round sets it). -/
theorem keep {W : Valuation} (hF : W.fn = gemv.fn_0) {r : Nat}
    (hr : r ∈ [54, 40, 38, 11, 1, 2, 37, 41]) {v : Val} (hv : W.regs r = some v) (n j : Nat) :
    (rB^[j] (rA^[n] W)).regs r = some v := by
  have hk : ∀ r ∈ [54, 40, 38, 11, 1, 2, 37, 41], Func.phiSets gemv.fn_0 r = false ∧
      (loopA.H :: loopA.B.map (·.2.2)).all (fun S => (S.regs.lookup r).isNone) = true ∧
      (loopB.H :: loopB.B.map (·.2.2)).all (fun S => (S.regs.lookup r).isNone) = true := by
    decide +kernel
  obtain ⟨h1, h2, h3⟩ := hk r hr
  exact Valuation.iterate_regs_keep ((steps W W n).2.2.2.2.1.trans hF) h1 h3
    (Valuation.iterate_regs_keep hF h1 h2 hv n) j

/-- **The facts a round reads** (test definition), at `W`, for sizes `K`, `M`, row `r`, lane `l`,
blocks `bA`, `bV`, matrix `A` and vector `v`: `%53` is `⌈K / 32⌉`, `%40` is `l`, `%38` is `r K`
and `%11` is `K` (64-bit words), `%1` and `%2` are the starts of `bA` and `bV`, which are buffers
of `M K` and `K` binary32 aligned to 4 whose generic addresses do not wrap and that hold `A`
(row-major) and `v`. -/
def Facts (K M r l bA bV : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (W : Valuation) : Prop :=
  W.regs 54 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) ∧
    W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)) ∧
    W.regs 38 = some (.bits 64 (BitVec.ofNat 64 (r * K))) ∧
    W.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)) ∧
    W.regs 1 = some (.ptr ⟨bA, 0⟩) ∧ W.regs 2 = some (.ptr ⟨bV, 0⟩) ∧
    W.mem.Buffer bA (M * K * 4) 4 false ∧ W.mem.Buffer bV (K * 4) 4 false ∧
    W.mem.Fits gemv.prog.layout bA (M * K * 4) ∧ W.mem.Fits gemv.prog.layout bV (K * 4) ∧
    W.mem.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A ∧
    W.mem.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v

/-- A read of `bA` or `bV` (test definition): an access that is not a write and not an
`atomicrmw`'s, of block `bA` or `bV`. -/
def ReadEv (bA bV : Nat) (e : Event) : Prop :=
  ∃ a, e = .access a ∧ a.write = false ∧ a.atomic = none ∧ (a.ptr.block = bA ∨ a.ptr.block = bV)

/-- **A weaker property of the events** (test): for every properties `P`, `Q` of events and
memories `m`, `m'`: if `m'` extends `m`'s trace by events of `P` (`Ext`), and every event of `P`
is one of `Q`, it extends it by events of `Q`. -/
theorem ext_mono {P Q : Event → Prop} {m m' : Mem} (h : Ext P m m') (hPQ : ∀ e, P e → Q e) :
    Ext Q m m' :=
  let ⟨E, hE, hP⟩ := h
  ⟨E, hE, fun e he => hPQ e (hP e he)⟩

/-- **Two reads** (test): for every blocks `bA`, `bV`, memory `m` and accesses `a₁`, `a₂` that
are reads of `bA` or `bV` (`ReadEv`): logging `a₁` then `a₂` extends `m`'s trace by reads of
`bA` or `bV`. -/
theorem ext_reads {bA bV : Nat} {m : Mem} {a₁ a₂ : Access} (h₁ : ReadEv bA bV (.access a₁))
    (h₂ : ReadEv bA bV (.access a₂)) :
    Ext (ReadEv bA bV) m ((m.log (.access a₁)).log (.access a₂)) :=
  ⟨[.access a₂, .access a₁], rfl, fun e he => by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl
    · exact h₂
    · exact h₁⟩

/-- **The facts hold after the rounds** (test): for every valuation `V` of gemv_kernel's
function, sizes, row, lane, blocks, matrix and vector with `Facts` at `head V`, and counts `n`,
`j` such that `n` rounds through `%70` keep the blocks of `head V`: `two n j V` has `V`'s context
and function, `18 + 19 n + 15 j` more steps, the blocks of `head V` and `Facts` (`keep`, and
`Valuation.iterate_blocks` for the rounds through `%75`, which do not touch memory). -/
theorem at_two {K M r l bA bV : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} {V : Valuation}
    (hfn : V.fn = gemv.fn_0) (hF : Facts K M r l bA bV A v (head V)) (n j : Nat)
    (hb : (two n 0 V).mem.blocks = (head V).mem.blocks) :
    (two n j V).ctx = V.ctx ∧ (two n j V).fn = gemv.fn_0 ∧
      (two n j V).k = V.k + 18 + 19 * n + 15 * j ∧
      (two n j V).mem.blocks = (head V).mem.blocks ∧ Facts K M r l bA bV A v (two n j V) := by
  obtain ⟨s1, s2, s3, -, -, -, -, -, -⟩ := steps V V 0
  obtain ⟨-, -, -, a1, a2, a3, -, -, -⟩ := steps V (head V) n
  obtain ⟨-, -, -, -, -, -, b1, b2, b3⟩ := steps V (rA^[n] (head V)) j
  have hH : (head V).fn = gemv.fn_0 := s2.trans hfn
  obtain ⟨g54, g40, g38, g11, g1, g2, gbA, gbV, gfA, gfV, gA, gV⟩ := hF
  have hb' : (two n j V).mem.blocks = (head V).mem.blocks :=
    (Valuation.iterate_blocks (c := true) (L := loopB) (rs := []) (by decide +kernel)
      (a2.trans hH) (by simp) j).1.trans hb
  have hq := Mem.blocks_keep hb'
  refine ⟨b1.trans (a1.trans s1), b2.trans (a2.trans hH), by rw [b3, a3, s3], hb',
    keep hH (by decide) g54 n j, keep hH (by decide) g40 n j, keep hH (by decide) g38 n j,
    keep hH (by decide) g11 n j, keep hH (by decide) g1 n j, keep hH (by decide) g2 n j,
    gbA.of_block (hq bA), gbV.of_block (hq bV), gfA.of_block (hq bA), gfV.of_block (hq bV),
    gA.of_block (hq bA), gV.of_block (hq bV)⟩

/-- **The rounds through `%75` read nothing** (test): for every valuation `V` of gemv_kernel's
function, blocks `bA`, `bV` and counts `n`, `j` such that the memory after `n` rounds through
`%70` extends the trace of `head V`'s by reads of `bA` or `bV` (`ReadEv`): so does the memory
after `j` more rounds through `%75` (`Valuation.iterate_loads`: `%75`'s path loads nothing). -/
theorem two_ext {bA bV : Nat} {V : Valuation} (hfn : V.fn = gemv.fn_0) {n : Nat}
    (hA : Ext (ReadEv bA bV) (head V).mem (two n 0 V).mem) (j : Nat) :
    Ext (ReadEv bA bV) (head V).mem (two n j V).mem := by
  obtain ⟨-, s2, -, -, -, -, -, -, -⟩ := steps V V 0
  obtain ⟨-, -, -, -, a2, -, -, -, -⟩ := steps V (head V) n
  exact Valuation.iterate_loads (c := true) (L := loopB) (rs := [])
    (Q := fun b => b = bA ∨ b = bV) (P := fun m => Ext (ReadEv bA bV) (head V).mem m)
    (by decide +kernel) (fun m a h hw hat hq => h.trans ⟨[.access a], rfl, fun e he => by
      rw [List.mem_singleton] at he
      exact ⟨a, he, hw, hat, hq⟩⟩) (a2.trans (s2.trans hfn)) (fun r hr => by cases hr) hA j

/-- The oracle numbers of round `i` of gemv_kernel's loop through `%70` on a thread at step
count `k0` (at statement 41 of `%6`) in context `c`, after `i` rounds through `%70`: of the
`fmul` at statement 2 and of the `fadd` at statement 3 of `%70` (steps `k0 + 33 + 19 i` and
`k0 + 34 + 19 i`), which choose the contraction. A test definition. -/
def oG (c : Ctx) (k0 i : Nat) : Nat × Nat :=
  (c.oracle (Nat.pair (k0 + 33 + 19 * i) 0), c.oracle (Nat.pair (k0 + 34 + 19 * i) 0))

/-- **The loop invariant** at round `i` (test definition): at `W`, `%55` is `i`, `%56` is the
`dotLoop` (with contraction, oracle numbers `o`) of the first `i` pairs of `ps` from `+0`, and
`%56` has no recorded product. -/
def Inv (o : Nat → Nat × Nat) (ps : List (Model FloatTy.float.fmt × Model FloatTy.float.fmt))
    (i : Nat) (W : Valuation) : Prop :=
  W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 60 = some (.ofFloat .float (dotLoop true o (Model.zero _ false) (ps.take i))) ∧
    W.prods 60 = none

/-- **The number of a lane's pairs** (test): for every `M`, `K`, lane `l < 32`, matrix `A`
(`M × K`), vector `v` and row `i`, every 32nd pair of row `i` and `v` from pair `l` are
`(K + 31 - l) / 32` (`length_stride`): the rounds through `%70`. -/
theorem len {M K l : Nat} (hl : l < 32) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (i : Fin M) :
    (stride 32 l (matVecPairs A v i)).length = (K + 31 - l) / 32 := by
  rw [length_stride hl]; simp only [matVecPairs, List.length_ofFn]; split <;> omega

/-- **A round through `%70` keeps the invariant** (test): for every `K < 2 ^ 31`, `M` with
`M K < 2 ^ 61`, row `r < M`, lane `l < 32`, blocks `bA`, `bV`, matrix `A` (`M × K`), vector `v`
(`K`), valuation `V` of gemv_kernel's program and function with `Facts` at `head V`, and round `i`
with `32 i + l < K`: at `W = two i 0 V` with the blocks of `head V`, if `Inv` holds for `i` with the
lane's strided pairs of row `r` and `v`, round `i` runs through `%70` (`RoundWith`,
MojoProofTest/OblGemv.lean's `roundA`), and after it the blocks are those of `head V` (the round
only loads), the trace extends `W`'s by its two loads, of `bA` and `bV` (`ReadEv`, `ext_reads`), and
`Inv` holds for `i + 1`. -/
theorem roundA_inv {K M r l bA bV : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hK : K < 2 ^ 31)
    (hMK : M * K < 2 ^ 61) (hr : r < M) (hl : l < 32) {V : Valuation}
    (hP : V.ctx.prog = gemv.prog) (hfn : V.fn = gemv.fn_0)
    (hF : Facts K M r l bA bV A v (head V)) {i : Nat} (ha : i * 32 + l < K) {W : Valuation}
    (hW : W = two i 0 V) (hb : W.mem.blocks = (head V).mem.blocks)
    (hI : Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) i W) :
    RoundWith true loopA.h loopA.p loopA.dh loopA.H loopA.B W ∧
      (rA W).mem.blocks = (head V).mem.blocks ∧ Ext (ReadEv bA bV) W.mem (rA W).mem ∧
      Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) (i + 1) (rA W) := by
  have hT := at_two hfn hF i 0 (by rw [← hW]; exact hb)
  rw [← hW] at hT
  obtain ⟨hWc, hWf, hWk, -, k54, k40, k38, k11, k1, k2, wbA, wbV, wfA, wfV, wA, wV⟩ := hT
  have hWP : W.ctx.prog = gemv.prog := hWc ▸ hP
  obtain ⟨h58, h60, p60⟩ := hI
  refine ⟨roundA K M r l i bA bV _ A v W hK hMK hr hl (by omega) ha hWP hWf h58 k54 h60
    k40 k38 k11 k1 k2 wbA wbV wfA wfV wA wV, ?_⟩
  obl_have e58 : (rA W).regs 58, e60 : (rA W).regs 60, q60 : (rA W).prods 60, em : (rA W).mem
  refine ⟨by rw [em]; exact hb, ?_, e58, ?_, q60⟩
  · rw [em]; exact ext_reads ⟨_, rfl, rfl, rfl, .inl rfl⟩ ⟨_, rfl, rfl, rfl, .inr rfl⟩
  have hctx (c l S) (V : Valuation) : (V.intoWith c l S).ctx = V.ctx :=
    (Valuation.intoWith_k _ _ _ _).1
  have hX : (Valuation.intoWith true (Valuation.intoWith true (Valuation.intoWith true W
      loopA.h loopA.H) 62 (gC 62 0)) 64 (gC 64 0)).k = V.k + 31 + 19 * i := by
    have h := (Valuation.lastWith_off true W loopA.h loopA.H armA 3).2.2
    rw [show pathOff loopA.H armA 3 = 13 by decide +kernel] at h
    exact h.trans (by omega)
  rw [hX] at e60
  simp only [hctx, hWc] at e60
  rw [show V.k + 31 + 19 * i + 2 = V.k + 33 + 19 * i by omega,
    show V.k + 31 + 19 * i + 3 = V.k + 34 + 19 * i by omega] at e60
  have hl' : i < (stride 32 l (matVecPairs A v ⟨r, hr⟩)).length := by rw [len hl]; omega
  have ea : (stride 32 l (matVecPairs A v ⟨r, hr⟩))[i] =
      (TorchLean.Tensor.get2 A ⟨r, hr⟩ ⟨i * 32 + l, ha⟩, v.getScalar ⟨i * 32 + l, ha⟩) := by
    have h := getElem?_stride hl i (matVecPairs A v ⟨r, hr⟩)
    rw [List.getElem?_eq_getElem hl', show 32 * i + l = i * 32 + l by omega,
      List.getElem?_eq_getElem (by simp only [matVecPairs, List.length_ofFn]; omega)] at h
    simpa only [matVecPairs, List.getElem_ofFn, Option.some.injEq] using h
  rw [List.take_succ_eq_append_getElem hl', dotLoop_append, List.length_take,
    Nat.min_eq_left hl'.le, ea, TorchLean.Tensor.getScalar_eq_apply, TorchLean.Tensor.get2_eq_apply]
  exact e60

/-- **A round through `%75` keeps the invariant** (test): for every `K < 2 ^ 31`, `M`, row
`r < M`, lane `l < 32`, blocks, matrix, vector and valuation `V` as in `roundA_inv`, and round
`i = n + j < ⌈K / 32⌉` with `K ≤ 32 i + l` after `n` rounds through `%70` that keep the blocks of
`head V`: at `W = two n j V`, if `Inv` holds for `i`, round `i` runs through `%75` (`roundB`) and
`Inv` holds for `i + 1` after it, with the same sum: the lane has no pair `i` (`len`). -/
theorem roundB_inv {K M r l bA bV : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hK : K < 2 ^ 31) (hr : r < M)
    (hl : l < 32) {V : Valuation} (hP : V.ctx.prog = gemv.prog) (hfn : V.fn = gemv.fn_0)
    (hF : Facts K M r l bA bV A v (head V)) {n j i : Nat}
    (hb : (two n 0 V).mem.blocks = (head V).mem.blocks) (hij : i = n + j)
    (hi : i < (K + 31) / 32) (hbi : K ≤ i * 32 + l) {W : Valuation} (hW : W = two n j V)
    (hI : Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) i W) :
    RoundWith true loopB.h loopB.p loopB.dh loopB.H loopB.B W ∧
      Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) (i + 1) (rB W) := by
  have hT := at_two hfn hF n j hb
  rw [← hW] at hT
  obtain ⟨hWc, hWf, -, -, k54, k40, k38, k11, k1, k2, wbA, wbV, -, -, -, -⟩ := hT
  have hWP : W.ctx.prog = gemv.prog := hWc ▸ hP
  obtain ⟨h58, h60, p60⟩ := hI
  refine ⟨roundB K M r l i bA bV _ W hK hl hi hbi hWP hWf h58 k54 h60 k40 k38 k11 k1 k2
    wbA wbV, ?_⟩
  obl_have e58 : (rB W).regs 58, e60 : (rB W).regs 60, q60 : (rB W).prods 60
  have hlen := len hl A v ⟨r, hr⟩
  have h1 : (stride 32 l (matVecPairs A v ⟨r, hr⟩)).length ≤ i + 1 := by omega
  have h2 : (stride 32 l (matVecPairs A v ⟨r, hr⟩)).length ≤ i := by omega
  refine ⟨e58, ?_, q60⟩
  rw [List.take_of_length_le h1]
  rw [List.take_of_length_le h2] at e60
  exact e60

/-- **The chain of gemv_kernel's loops** (test): for every `K < 2 ^ 31`, `M` with `M K < 2 ^ 61`,
row `r < M`, lane `l < 32`, blocks, matrix, vector and valuation `V` of gemv_kernel's program and
function with `Facts` at `head V`, the entry's edge from `V` to the header `%54` (`EdgeWith`) and
`Inv` for no round at `head V`: a chain of `loopA` and `loopB` (`ChainWith`) that statement 41 of
`%6` covers (`coversChainAt`) runs from `V` to the header with the path out `%59` next, at
`two a (⌈K / 32⌉ - a) V` where `a = (K + 31 - l) / 32`, with the blocks of `head V` after the `a`
rounds through `%70`, a trace that extends `head V`'s by reads of `bA` or `bV` (`ReadEv`) after
them, and `Inv` for `⌈K / 32⌉` rounds: `loopA` then `loopB` when `a < ⌈K / 32⌉`, `loopA` alone
otherwise. -/
theorem chain {K M r l bA bV : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hK : K < 2 ^ 31)
    (hMK : M * K < 2 ^ 61) (hr : r < M) (hl : l < 32) {V : Valuation}
    (hP : V.ctx.prog = gemv.prog) (hfn : V.fn = gemv.fn_0)
    (hF : Facts K M r l bA bV A v (head V))
    (hE : EdgeWith true loopA.h loopA.p V 6 (gC 6 41).obls (gC 6 41) [gB 44 0])
    (hI : Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) 0 (head V)) :
    ∃ Ls, coversChainAt false true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41)
      [gB 44 0] Ls = true ∧ ChainWith true (fun W l' ds S E => l' = loopA.h ∧ ds = loopA.dh ∧
        S = loopA.H ∧ E = [gB 63 0] ∧
        W = two ((K + 31 - l) / 32) ((K + 31) / 32 - (K + 31 - l) / 32) V ∧
        (two ((K + 31 - l) / 32) 0 V).mem.blocks = (head V).mem.blocks ∧
        Ext (ReadEv bA bV) (head V).mem (two ((K + 31 - l) / 32) 0 V).mem ∧
        Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) ((K + 31) / 32) W)
      Ls V 6 (gC 6 41).obls (gC 6 41) [gB 44 0] := by
  have hA (i : Nat) (hi : i * 32 + l < K) (W : Valuation)
      (hI : W = two i 0 V ∧ W.mem.blocks = (head V).mem.blocks ∧
        Ext (ReadEv bA bV) (head V).mem W.mem ∧
        Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) i W) :
      BackWith true loopA.h loopA.p (fun W => W = two (i + 1) 0 V ∧
        W.mem.blocks = (head V).mem.blocks ∧ Ext (ReadEv bA bV) (head V).mem W.mem ∧
        Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) (i + 1) W) W loopA.h
        loopA.dh loopA.H loopA.B := by
    obtain ⟨hR, hb, hx, hI'⟩ := roundA_inv hK hMK hr hl hP hfn hF hi hI.1 hI.2.1 hI.2.2.2
    exact ⟨hR, (congrArg rA hI.1).trans (two_eq V i 0).2.1, hb, hI.2.2.1.trans hx, hI'⟩
  rcases Nat.lt_or_ge ((K + 31 - l) / 32) ((K + 31) / 32) with hn | hn
  · refine ⟨[{ loopA with X := armB }, cut loopB], by decide +kernel,
      .loop (fun i W => W = two i 0 V ∧ W.mem.blocks = (head V).mem.blocks ∧
        Ext (ReadEv bA bV) (head V).mem W.mem ∧
        Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) i W) ((K + 31 - l) / 32)
        hE ⟨(two_eq V 0 0).1.symm, rfl, ⟨[], rfl, fun _ h => by cases h⟩, hI⟩
        (fun i hi W hI => .last (hA i (by omega) W hI)) (fun W hW => ?_)⟩
    have hb : (two ((K + 31 - l) / 32) 0 V).mem.blocks = (head V).mem.blocks := by
      rw [← hW.1]; exact hW.2.1
    have hx : Ext (ReadEv bA bV) (head V).mem (two ((K + 31 - l) / 32) 0 V).mem := by
      rw [← hW.1]; exact hW.2.2.1
    obtain ⟨hR, hI'⟩ := roundB_inv (n := (K + 31 - l) / 32) (j := 0) hK hr hl hP hfn hF hb rfl
      (by omega) (by omega) hW.1 hW.2.2.2
    refine .loop (fun j W => W = two ((K + 31 - l) / 32) (j + 1) V ∧
      Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩))
        ((K + 31 - l) / 32 + j + 1) W) ((K + 31) / 32 - (K + 31 - l) / 32 - 1) hR
      ⟨(congrArg rB hW.1).trans (two_eq V _ 0).2.2, hI'⟩ (fun j hj W' hI => .last ?_)
      (fun W' hW' => .last ?_)
    · obtain ⟨hR', hI''⟩ := roundB_inv (n := (K + 31 - l) / 32) (j := j + 1) hK hr hl hP hfn
        hF hb (by omega) (by omega) (by omega) hI.1 hI.2
      refine ⟨hR', (congrArg rB hI.1).trans (two_eq V _ (j + 1)).2.2, ?_⟩
      rw [show (K + 31 - l) / 32 + (j + 1) + 1 = (K + 31 - l) / 32 + j + 1 + 1 by omega]
      exact hI''
    · refine ⟨rfl, rfl, rfl, rfl, ?_, hb, hx, ?_⟩
      · rw [hW'.1, show (K + 31) / 32 - (K + 31 - l) / 32 - 1 + 1 =
          (K + 31) / 32 - (K + 31 - l) / 32 by omega]
      · have h := hW'.2
        rwa [show (K + 31 - l) / 32 + ((K + 31) / 32 - (K + 31 - l) / 32 - 1) + 1 =
          (K + 31) / 32 by omega] at h
  · have hn' : (K + 31 - l) / 32 = (K + 31) / 32 := by omega
    refine ⟨[cut loopA], by decide +kernel, .loop (fun i W => W = two i 0 V ∧
      W.mem.blocks = (head V).mem.blocks ∧ Ext (ReadEv bA bV) (head V).mem W.mem ∧
      Inv (oG V.ctx V.k) (stride 32 l (matVecPairs A v ⟨r, hr⟩)) i W) ((K + 31) / 32)
      hE ⟨(two_eq V 0 0).1.symm, rfl, ⟨[], rfl, fun _ h => by cases h⟩, hI⟩
      (fun i hi W hI => .last (hA i (by omega) W hI))
      (fun W hW => .last ⟨rfl, rfl, rfl, rfl, ?_, ?_, ?_, hW.2.2.2⟩)⟩
    · rw [hW.1, hn', Nat.sub_self]
    · rw [hn', ← hW.1]; exact hW.2.1
    · rw [hn', ← hW.1]; exact hW.2.2.1

/-- **The path out of gemv_kernel's loop** (test): for every `K < 2 ^ 31` and valuation `W` of
gemv_kernel's function whose `%55` and `%53` are both `⌈K / 32⌉` and whose `%56` is a
binary32 word: the edge from the header `%54` through `%59` to position 1 of `%78` (`EdgeWith`). -/
theorem exit_edge (K : Nat) (hK : K < 2 ^ 31) (W : Valuation) (hfn : W.fn = gemv.fn_0)
    (h58 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (h54 : W.regs 54 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (x : Model FloatTy.float.fmt) (h60 : W.regs 60 = some (.ofFloat .float x)) :
    EdgeWith true gemv.fn_0.b_10.label 1 W loopA.h loopA.dh loopA.H [gB 63 0] := by
  have hn : (K + 31) / 32 < 2 ^ 31 := by omega
  mojo_obl

/-- **After the path out** (test): for every valuation `W` of gemv_kernel's function, word `x` of
`%56`, block `p0`, row `r` and lane `l` with `%37` the pointer to element `r` of `p0`, `%40` the
word of `l` and `%41` whether `l` is 0: after the path out (`rX W`), `%79` is `x` with no
`fmul contract` operands recorded, `%37`, `%40` and `%41` are kept, the blocks and the trace are
`W`'s, and the path took 3 steps. -/
theorem exit_regs (W : Valuation) (hfn : W.fn = gemv.fn_0) (x : Model FloatTy.float.fmt)
    (h60 : W.regs 60 = some (.ofFloat .float x)) (p0 r l : Nat)
    (h37 : W.regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h41 : W.regs 41 = some (.ofBool (decide (l = 0)))) :
    (rX W).regs 80 = some (.ofFloat .float x) ∧ (rX W).prods 80 = none ∧
      (rX W).regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩) ∧
      (rX W).regs 40 = some (.bits 64 (BitVec.ofNat 64 l)) ∧
      (rX W).regs 41 = some (.ofBool (decide (l = 0))) ∧ (rX W).mem.blocks = W.mem.blocks ∧
      (rX W).mem.trace = W.mem.trace ∧ (rX W).k = W.k + 3 := by
  obl_have e80 : (rX W).regs 80, q80 : (rX W).prods 80, e37 : (rX W).regs 37,
    e40 : (rX W).regs 40, e41 : (rX W).regs 41, em : (rX W).mem
  have e2 : (rX W).k = W.k + 1 * (pathLen loopA.H [gB 63 0] + 1) :=
    (Valuation.roundWith_k true loopA.h loopA.H [gB 63 0] 1 W).2.2
  have e3 : pathLen loopA.H [gB 63 0] + 1 = 3 := by decide +kernel
  exact ⟨e80, q80, e37, e40, e41, by rw [em], by rw [em], by rw [e2, e3, Nat.one_mul]⟩

/-- **gemv_kernel's thread through its loop, at every `K`** (test): for every valid launch `L`,
thread `k`, context `c` of gemv_kernel's program and thread `k`'s environment, thread `t` whose top
frame `f` is at statement 41 of the entry block `%6`, `M, K < 2 ^ 31` with `M K < 2 ^ 61`
(`gep_buffer2`'s bound on the matrix's addresses `%68`), row `r < M`, blocks `p0` (the output, `M`
binary32, writable), `bA` (the matrix `A`, `M × K` row-major) and `bV` (the vector `v`, `K`) in
memory `m`, with `%0`, `%1`, `%2` their starts, `%10` and `%11` the sign extensions of the 32-bit
words of `M` and `K`, and `%35` the vector of the halves of `r`'s 64-bit word: the thread steps to a
frame at position 1 of block `%78` (after its `phi` `%79`) with the same `alloca` blocks and
destination, `21 + 19 a + 15 (⌈K / 32⌉ - a)` steps later with `a = (K + 31 - l) / 32` the rounds
through `%70` of lane `l = laneid`, on a memory with `m`'s blocks whose trace extends `m`'s by reads
of `bA` or `bV` only (`ReadEv`: `chain`, `two_ext`), where `%79` is the `dotLoop` (with contraction,
oracle numbers `oG c t.k`) from `+0` of every 32nd factor pair of row `r` of `A` and `v`, from pair
`l` (`stride`, `matVecPairs`), with no `fmul contract` operands recorded, `%37` the pointer to
element `r` of the output, `%40` the lane and `%41` whether it is 0. One program; the trip count
`⌈K / 32⌉` and the split of the rounds between the arms are symbolic. -/
theorem run (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame)
    (ht : t.frames = f :: rest) (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label)
    (hpc : f.pc = 41) (M K r p0 bA bV : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31)
    (hMK : M * K < 2 ^ 61) (hr : r < M)
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
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = gemv.fn_0 ∧
      f'.label = gemv.fn_0.b_10.label ∧ f'.pc = 1 ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      t'.k = t.k + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
        15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32) ∧ m'.blocks = m.blocks ∧
      Ext (ReadEv bA bV) m m' ∧
      f'.regs 80 = some (.ofFloat .float (dotLoop true (oG c t.k) (Model.zero _ false)
        (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩)))) ∧ f'.prods 80 = none ∧
      f'.regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩) ∧
      f'.regs 40 = some (.bits 64 (BitVec.ofNat 64 (L.env k).laneid)) ∧
      f'.regs 41 = some (.ofBool (decide ((L.env k).laneid = 0))) := by
  have h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 M)) := by
    rw [hr10, (GPUProof.WordFit.of_lt (w := 32) hM).signExtend 64]
  have h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)) := by
    rw [hr11, (GPUProof.WordFit.of_lt (w := 32) hK).signExtend 64]
  have hE := entry_edge L hL k c hcp hce t.k m f hf M K r p0 hM hK hr hr0 h10 h11 hr35 hb0 hf0
  obtain ⟨g58, g60, q60, g54, g38, g40, g41, g37, g11, gm⟩ :=
    entry_regs L hL k c hcp hce t.k m f hf M K r p0 hM hK hr hr0 h11 hr35 hb0 hf0
  have hl := Launch.laneid_lt L k
  have g1 : (head (Valuation.entry c t.k m f)).regs 1 = some (.ptr ⟨bA, 0⟩) :=
    Valuation.iterate_regs_keep (c := true) (h := 6) (S := gC 6 41) (B := [gB 44 0])
      (V := Valuation.entry c t.k m f) hf (by decide +kernel) (by decide +kernel) hr1 1
  have g2 : (head (Valuation.entry c t.k m f)).regs 2 = some (.ptr ⟨bV, 0⟩) :=
    Valuation.iterate_regs_keep (c := true) (h := 6) (S := gC 6 41) (B := [gB 44 0])
      (V := Valuation.entry c t.k m f) hf (by decide +kernel) (by decide +kernel) hr2 1
  have hF : Facts K M r (L.env k).laneid bA bV A v (head (Valuation.entry c t.k m f)) := by
    rw [Facts, gm]; exact ⟨g54, g40, g38, g11, g1, g2, hbA, hbV, hfA, hfV, hA, hV⟩
  generalize (L.env k).laneid = l at *
  have ho : oG (Valuation.entry c t.k m f).ctx (Valuation.entry c t.k m f).k = oG c t.k := rfl
  have hI0 : Inv (oG (Valuation.entry c t.k m f).ctx (Valuation.entry c t.k m f).k)
      (stride 32 l (matVecPairs A v ⟨r, hr⟩)) 0 (head (Valuation.entry c t.k m f)) :=
    ⟨g58, g60.trans (by kernel_rfl), q60⟩
  obtain ⟨Ls, hcov, hC⟩ := chain hK hMK hr hl (V := Valuation.entry c t.k m f) hcp hf hF hE hI0
  rw [ho] at hC
  obtain ⟨t₁, m₁, f₁, p₁, l₁, ds₁, S₁, E₁, hS₁, ht₁, hf₁, hl₁, hp₁, ⟨_, ha₁, -⟩, hd₁, hc₁, rfl, rfl,
    rfl, rfl, hW₁, hbA, hxA, h58₁, h60₁, -⟩ := hC.reach (alloca := false) hcp hcov ht hf
      (by rw [hlb]; decide +kernel) hpc rfl
  obtain ⟨-, hWf, hWk, hWb, k54, k40, -, -, -, -, -, -, -, -, -, -⟩ :=
    at_two hf hF ((K + 31 - l) / 32) ((K + 31) / 32 - (K + 31 - l) / 32) hbA
  have hH : (head (Valuation.entry c t.k m f)).fn = gemv.fn_0 :=
    (steps (Valuation.entry c t.k m f) (Valuation.entry c t.k m f) 0).2.1.trans hf
  have k37 : (two ((K + 31 - l) / 32) ((K + 31) / 32 - (K + 31 - l) / 32)
      (Valuation.entry c t.k m f)).regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩) :=
    keep hH (by decide) g37 _ _
  have k41 : (two ((K + 31 - l) / 32) ((K + 31) / 32 - (K + 31 - l) / 32)
      (Valuation.entry c t.k m f)).regs 41 = some (.ofBool (decide (l = 0))) :=
    keep hH (by decide) g41 _ _
  have hT := two_ext hf hxA ((K + 31) / 32 - (K + 31 - l) / 32)
  rw [← hW₁, gm] at hT
  obtain ⟨E, e₁, e₂⟩ := hT
  rw [← hW₁] at hWf hWk hWb k54 k40 k37 k41
  have hlen : (stride 32 l (matVecPairs A v ⟨r, hr⟩)).length ≤ (K + 31) / 32 := by
    rw [len hl]; omega
  rw [List.take_of_length_le hlen] at h60₁
  have hX := exit_edge K hK (Valuation.entry c t₁.k m₁ f₁) hWf h58₁ k54 _ h60₁
  obtain ⟨e80, q80, e37, e40, e41, em, et, ek⟩ :=
    exit_regs (Valuation.entry c t₁.k m₁ f₁) hWf _ h60₁ p0 r l k37 k40 k41
  have hp₃ : ((Valuation.entry c t₁.k m₁ f₁).lastWith true loopA.h loopA.H [gB 63 0]).2.2.exit.pc
      f₁.fn gemv.fn_0.b_10.label = 1 := hX.2.2
  rw [hf₁] at hp₃
  obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₂, ha₂, -, hd₂, hV₂⟩ :=
    Block.sound_edge hcp hc₁ ht₁ hf₁ hl₁ hp₁ hX.1 hX.2.1
  rw [Valuation.allocsWith_nil _ hc₁, List.nil_append] at ha₂
  have hk₂ : t₂.k = (rX (Valuation.entry c t₁.k m₁ f₁)).k := congrArg Valuation.k hV₂
  have hm₂ : m₂ = (rX (Valuation.entry c t₁.k m₁ f₁)).mem := congrArg Valuation.mem hV₂
  have hr₂ : f₂.regs = (rX (Valuation.entry c t₁.k m₁ f₁)).regs := congrArg Valuation.regs hV₂
  have hk₁ : (Valuation.entry c t₁.k m₁ f₁).k = t.k + 18 + 19 * ((K + 31 - l) / 32) +
      15 * ((K + 31) / 32 - (K + 31 - l) / 32) := hWk
  refine ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₂.trans hp₃, ha₂.trans ha₁, hd₂.trans hd₁,
    by omega, by rw [hm₂, em, hWb]; exact congrArg Mem.blocks gm,
    ⟨E, by rw [hm₂, et]; exact e₁, e₂⟩, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hr₂]; exact e80
  · exact (congrFun (congrArg Valuation.prods hV₂) 80).trans q80
  · rw [hr₂]; exact e37
  · rw [hr₂]; exact e40
  · rw [hr₂]; exact e41

/-- **The lane's pairs are the spec's** (test of gemv_kernel's bridge to the matrix-vector spec):
for every format `fmt`, width `bits`, sizes `M`, `K`, matrix `A` (`M × K`), vector `v` (`K`),
input words `I` of `MojoProof.Tile.matVecEnc fmt bits (M, K)` that are `A`'s and `v`'s entries,
and row `i`: the factor pairs of row `i` (`matVecPairs`, whose strided lists `run`'s `%79` sums)
are the pairs `(I (i, j), I j)` that `MojoProof.Tile.bflyDeliver_holds` sums. -/
theorem pairs_eq {fmt : FloatFormat} (bits : Nat) {M K : Nat}
    (A : TorchLean.Tensor (Model fmt) [M, K]) (v : TorchLean.Tensor (Model fmt) [K])
    (I : (MojoProof.Tile.matVecEnc fmt bits (M, K)).inp.Words)
    (hA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 A i j)
    (hv : ∀ j, I (.inr j) = v.getScalar j) (i : Fin M) :
    matVecPairs A v i = List.ofFn fun j => (I (.inl (i, j)), I (.inr j)) := by
  simp only [matVecPairs, hA, hv]

-- `run` at two sizes: `M = K = 64` (two rounds, both through `%70` on every lane) and
-- `M = 3`, `K = 40` (two rounds; lanes 8 to 31 take the second through `%75`).
example := run (M := 64) (K := 64) (hM := by decide) (hK := by decide) (hMK := by decide)

example := run (M := 3) (K := 40) (hM := by decide) (hK := by decide) (hMK := by decide)

/-- **Mutants: the row's pairs in order, every round through `%70`** (test of gemv_kernel at
`K = 40`, lane 8): `run`'s `%79` folds the lane's strided pairs, not the row's in order: lane 8's
positions among `0, …, 39` are `[8]` (`stride 32 8`), not the 40 positions; and `run`'s step count
at lane 8, `21 + 19 + 15`, is not the count with both rounds through `%70`, `21 + 19 ⌈40 / 32⌉`.
By `decide`. -/
theorem run_mutant :
    stride 32 8 (List.range 40) = [8] ∧
      21 + 19 * ((40 + 31 - 8) / 32) + 15 * ((40 + 31) / 32 - (40 + 31 - 8) / 32) ≠
        21 + 19 * ((40 + 31) / 32) := by
  decide

end MojoProofTest.GemvLoop
