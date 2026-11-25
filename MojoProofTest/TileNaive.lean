import MojoProof.Tile.MatVec
import MojoProofTest.NaiveKernel

/-!
# The naive matmul kernel refines the tile matrix product, at every row stride

For the naive matmul kernel's row-stride family `NaiveFam.prog sA sB sC` (MojoProofTest/Family.lean,
float32 with `fmul contract`), this module relates the kernel's theorem `NaiveFam.sound`
(MojoProofTest/NaiveFamRun.lean) to the tile program `dot true K` of MojoProof/Tile/Dot.lean
through the library's `mat_refines` (MojoProof/Tile/Mat.lean) and `mat_holds`
(MojoProof/Tile/MatVec.lean):

* `bytes_eq`: for every `K ≤ sA` and `K ≤ sB`, the family's bytes (`NaiveFam.bytes`) are
  `matBytes`'s at naive's layout, binary32, `fmul contract` and its oracle numbers `NaiveSpec.o`;
* `naive_tile`: for every row stride `sA`, `sB`, `sC`, oracle family, launch valid with `z` sides
  1, sizes below `2 ^ 31`, blocks, tensors and memory of `Mat.Pre` (so every `K ≤ min sA sB`), in
  every observation of a complete run, the tile run of `dot true K (place L m n)` from `mats A B`
  at the tile oracle of the kernel's oracle numbers (`pairOracle` of `NaiveSpec.o`) ends without a
  fault, and every cell `(r, c)` in bounds and in the launch's window holds at cell `Nat.pair r c`
  of buffer 2 the float at its thread's output cell (`Elem.word`), a word that meets TorchLean's
  product of the first `K` columns (`Meets`, with its graded clause: `GPUProof.Approx` at
  `GPUProof.dotGrade` of every exact entries and grades at which the cell's inputs are
  `GPUProof.Approx`);
* `naive_holds`: the family with one column (`n = 1`, `B` of one row) meets the matrix-vector
  spec: for every row stride, oracle family, launch valid with `z` sides 1 whose window covers
  the `m` rows and column 0, width, sizes below `2 ^ 31`, blocks, tensors and memory of
  `Mat.Pre`, in every observation of a complete run, the words at cells `(i, 0)` of the tile run
  meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at `matIn A B` (`mat_holds` at
  `NaiveFam.sound`);
* `naive_tile` at the corpus program (strides 768, 768, 50257) at one launch and memory, `L12`
  and `mem12`, at two sizes, `K = 768` and `K = 4`, its graded clause at `K = 768`, and the
  placement `place L12 1 2` evaluated.

The tile oracle comes from `NaiveSpec.o`, whose steps `54 + 18 j` and `55 + 18 j` are the
kernel's; it is not computed from the kernel's paths here.
-/
namespace MojoProofTest.TileNaive

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProof.Tile MojoProofTest.SymPhi
open MojoProofTest.NaiveSpec MojoProofTest.NaiveSound MojoProofTest.NaiveKernel
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- **The naive family's bytes are `matBytes`'s**: for every oracle family `ω`, launch `L`,
sizes, row strides `sA` and `sB`, `K ≤ sA`, `K ≤ sB` and tensors, `NaiveFam.bytes ω L K A B` is
`matBytes` at naive's layout, binary32, `fmul contract`, the oracle numbers `NaiveSpec.o (ω k)` of
each thread `k` and `K` (`NaiveFam.pairs` is the first `K` pairs, `Fin.ofFn_take_eq_take_ofFn`). -/
theorem bytes_eq (ω : Nat → Nat → Nat) (L : Launch) {m n K sA sB : Nat} (hA : K ≤ sA)
    (hB : K ≤ sB) (A : Tensor (Model FloatTy.float.fmt) [m, sA])
    (B : Tensor (Model FloatTy.float.fmt) [n, sB]) :
    NaiveFam.bytes ω L K A B =
      matBytes naive.prog.layout .float true (fun k => o (ω k)) L hA hB A B := by
  have e : ∀ (r : Fin m) (c : Fin n), NaiveFam.pairs A B r c K = List.ofFn fun j : Fin K =>
      (Tensor.get2 A r (Fin.castLE hA j), Tensor.get2 B c (Fin.castLE hB j)) :=
    fun _ _ => (Fin.ofFn_take_eq_take_ofFn (le_min hA hB) _).symm
  funext k
  unfold NaiveFam.bytes matBytes
  simp only [e]

/-- **The naive matmul kernel refines the tile matrix product, at every row stride.** For every
row stride `sA`, `sB`, `sC`, oracle family `ω`, launch `L` valid with `z` sides 1, sizes `m`, `n`,
count `K` below `2 ^ 31`, blocks, tensors `A` (`m × sA`), `B` (`n × sB`) and memory of `Mat.Pre`
(so `n ≤ sC`, `K ≤ sA` and `K ≤ sB`), and every observation `Bk` of a complete run of
`NaiveFam.prog sA sB sC` at an address choice under `ω` (`Kernel.Obs`): the run of
`dot true K (place L m n)` on all the launch's threads from `mats A B` at the tile oracle
`pairOracle` of `NaiveSpec.o (ω t)` ends without a fault in a state `st`, and every cell `(r, c)`
with `r < m`, `c < n` and in the launch's window is computed by a thread `k` of row `r` and column
`c` whose output cell holds (`Elem.word`) the word `v` at cell `Nat.pair r c` of buffer 2 of
`st`, and `v` meets TorchLean's product of the first `K` columns of `A` and the transpose of the
first `K` columns of `B` at `(r, c)` under thread `k`'s oracle numbers (`Meets`). It is
`mat_refines` at `NaiveFam.sound` (`bytes_eq`); it covers the family at every launch and memory,
and every `K ≤ min sA sB`. -/
theorem naive_tile {sA sB sC : Nat} {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K bC bA bB : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, sA]} {B : Tensor (Model FloatTy.float.fmt) [n, sB]}
    {mem : Mem} (h : Mat.Pre (NaiveFam.prog sA sB sC).layout (.fp .float) (Val.ofFloat .float) 4
      z mem bC bA bB m n K sA sB sC A B) (hsz : m < 2 ^ 31 ∧ n < 2 ^ 31 ∧ K < 2 ^ 31)
    {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs (NaiveFam.prog sA sB sC) (NaiveFam.fn sA sB sC) L
      (Mat.args z bC bA bB m n K) mem (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle fun t => o (ω t)) (dot true K (place L m n))
        (volume L.grid * volume L.block) (mats A B) = .ok st ∧
      ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x → c < L.grid .y * L.block .y →
        ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
          ∃ v, st.cells 2 (Nat.pair r c) = some v ∧
            Elem.word naive.prog.layout .float bC (NaiveFam.cell sC L) Bk k = some v ∧
            Meets A B h.le.2.1 h.le.2.2 ⟨r, hr⟩ ⟨c, hc⟩ true (o (ω k)) v :=
  mat_refines hL hz (by decide) h.le.1
    (by rw [← bytes_eq ω L h.le.2.1 h.le.2.2 A B]; exact NaiveFam.sound hL hz h hsz)
    ⟨_, h.bufs.2.2.choose_spec.1⟩ rfl hB

/-- **The naive kernel with one column meets the matrix-vector spec.** For every row stride
`sA`, `sB`, `sC`, oracle family `ω`, launch `L` valid with `z` sides 1 whose window covers the
`m` rows and column 0, width `bits`, sizes `m` and `K` below `2 ^ 31`, blocks, tensors `A`
(`m × sA`) and `B` (`1 × sB`) and memory of `Mat.Pre` at `n = 1`, and every observation `Bk` of a
complete run of `NaiveFam.prog sA sB sC` under `ω` (`Kernel.Obs`): the run of
`dot true K (place L m 1)` from `mats A B` at the tile oracle `pairOracle` of `NaiveSpec.o (ω t)`
ends without a fault in a state whose cells `(i, 0)` of buffer 2 hold words `W' i` that meet
`GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at size `(m, K)` and encoding
`matVecEnc` of binary32 from `matIn A B` (`mat_holds`, whose kernel premise is `NaiveFam.sound`
through `bytes_eq`). A test of `mat_holds` on the naive family, not a kernel theorem. -/
theorem naive_holds {sA sB sC : Nat} {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {m K bC bA bB : Nat} (hX : m ≤ L.grid .x * L.block .x)
    (hY : 0 < L.grid .y * L.block .y) (bits : Nat) {A : Tensor (Model FloatTy.float.fmt) [m, sA]}
    {B : Tensor (Model FloatTy.float.fmt) [1, sB]} {mem : Mem}
    (h : Mat.Pre (NaiveFam.prog sA sB sC).layout (.fp .float) (Val.ofFloat .float) 4
      z mem bC bA bB m 1 K sA sB sC A B) (hsz : m < 2 ^ 31 ∧ K < 2 ^ 31) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs (NaiveFam.prog sA sB sC) (NaiveFam.fn sA sB sC) L
      (Mat.args z bC bA bB m 1 K) mem (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle fun t => o (ω t)) (dot true K (place L m 1))
        (volume L.grid * volume L.block) (mats A B) = .ok st ∧
      ∃ W' : Fin m → Model FloatTy.float.fmt,
        (∀ i : Fin m, st.cells 2 (Nat.pair i 0) = some (W' i)) ∧
        (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
          (matVecEnc FloatTy.float.fmt bits (m, K)) (matIn A B h.le.2.1 h.le.2.2) W' :=
  mat_holds (l := naive.prog.layout) (ft := .float) (w := 4) hL hz hX hY (by decide) bits h.le.1
    (by
      rw [← bytes_eq ω L h.le.2.1 h.le.2.2 A B]
      exact NaiveFam.sound hL hz h ⟨hsz.1, by decide, hsz.2⟩)
    ⟨_, h.bufs.2.2.choose_spec.1⟩ rfl hB

/-- `naive_tile` at the corpus program (strides 768, 768, 50257) at one launch and memory at
`K = 768`: one block of 2 × 2 threads (`L12`), `m = 1`, `n = 2` and `mem12 A B` (`pre12`); for
every `A`, `B` and oracle family, each of the two cells of row 0 is a thread's output word, and it
meets TorchLean's product of all 768 columns. -/
example (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle fun t => o (ω t)) (dot true 768 (place L12 1 2)) 4 (mats A B) =
        .ok st ∧
      ∀ c (hc : c < 2), ∃ k < 4, ∃ v, st.cells 2 (Nat.pair 0 c) = some v ∧
        Elem.word naive.prog.layout .float 1 (cell L12) Bk k = some v ∧
        Meets A B le_rfl le_rfl 0 ⟨c, hc⟩ true (o (ω k)) v := by
  obtain ⟨st, hr, h⟩ := naive_tile NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B le_rfl) (by decide) hB
  refine ⟨st, hr, fun c hc => ?_⟩
  obtain ⟨k, hk, _, _, v, hv, hw, hm⟩ := h 0 c (by decide) hc (by decide)
    (hc.trans_le (by decide))
  exact ⟨k, hk, v, hv, hw, hm⟩

/-- `naive_tile` at the same launch and memory at a second size, `K = 4`: the tile run is of
`dot true 4`, and each cell's word meets TorchLean's product of the first 4 columns. -/
example (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 4) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle fun t => o (ω t)) (dot true 4 (place L12 1 2)) 4 (mats A B) =
        .ok st ∧
      ∀ c (hc : c < 2), ∃ k < 4, ∃ v, st.cells 2 (Nat.pair 0 c) = some v ∧
        Elem.word naive.prog.layout .float 1 (cell L12) Bk k = some v ∧
        Meets A B (by decide : 4 ≤ 768) (by decide) 0 ⟨c, hc⟩ true (o (ω k)) v := by
  obtain ⟨st, hr, h⟩ := naive_tile NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B (by decide)) (by decide) hB
  refine ⟨st, hr, fun c hc => ?_⟩
  obtain ⟨k, hk, _, _, v, hv, hw, hm⟩ := h 0 c (by decide) hc (by decide)
    (hc.trans_le (by decide))
  exact ⟨k, hk, v, hv, hw, hm⟩

/-- The graded clause of `naive_tile` at the corpus program at the launch `L12` and memory
`mem12 A B` at `K = 768`: for every `A`, `B`, oracle family, column `c < 2`, exact entries `a`,
`x` and grades `ga`, `gx` at which row 0 of `A` and row `c` of `B` are `GPUProof.Approx`, the word
at cell `(0, c)` is `GPUProof.Approx` at `GPUProof.dotGrade` of `Σₖ aₖ xₖ` (`Meets`' third
clause). -/
example (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) {ch : Nat → Nat}
    {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk) (c : Nat) (hc : c < 2) (a x : Fin 768 → ℝ)
    (ga gx : Fin 768 → GPUProof.Grade)
    (ha : ∀ k, GPUProof.Approx .real (ga k) (.ieee FloatTy.float.fmt)
      (Tensor.get2 A 0 k).toReal? (a k))
    (hx : ∀ k, GPUProof.Approx .real (gx k) (.ieee FloatTy.float.fmt)
      (Tensor.get2 B ⟨c, hc⟩ k).toReal? (x k)) :
    ∃ st, runAll (pairOracle fun t => o (ω t)) (dot true 768 (place L12 1 2)) 4 (mats A B) =
        .ok st ∧ ∃ v, st.cells 2 (Nat.pair 0 c) = some v ∧
      GPUProof.Approx .real (GPUProof.dotGrade (.ieee FloatTy.float.fmt) 768 a x ga gx)
        (.ieee FloatTy.float.fmt) v.toReal? (∑ k, a k * x k) := by
  obtain ⟨st, hr, h⟩ := naive_tile NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B le_rfl) (by decide) hB
  obtain ⟨_, _, _, _, v, hv, _, hm⟩ := h 0 c (by decide) hc (by decide) (hc.trans_le (by decide))
  exact ⟨st, hr, v, hv, hm.2.2 rfl a x ga gx ha hx⟩

/-- The placement on `L12` at `m = 1`, `n = 2`: threads 0 and 2 at row 0, columns 0 and 1;
threads 1 and 3 (row 1) at none (`in12`). -/
example : (List.range 4).map (fun t => (place L12 1 2 t).map fun x => (x.1.val, x.2.val)) =
    [some (0, 0), none, some (0, 1), none] := by
  decide +kernel

end MojoProofTest.TileNaive
