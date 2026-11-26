import MojoProof.Tile.MatVec
import MojoProofTest.NaiveKernel
import MojoProofTest.TileGrade

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
  `Mat.Pre`, in every observation `Bk` of a complete run, the floats of `Bk`'s output block at
  the rows' cells `i * sC * 4` meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at
  `matIn A B` (`mat_holds` at `NaiveFam.sound`);
* `naive_pre`: `Mat.pre_mem` at every size within the family's bounds (`1 ≤ sC`, `K ≤ sA`,
  `K ≤ sB`, and `m * sC`, `m * sA`, `sB` below `2 ^ 31`), for every tensors, at the memory
  `Mat.mem` with blocks 1, 2, 3 at addresses `4 (i + 1)`;
* `naive_words`: `naive_holds` at the family's strides 3, 3 and 1, the launch `L12`, the memory
  `memV` of `gen 2 3` and `gen 1 3` (`preV`) and the oracle family `0`, its two words computed
  (`6` and `-1`); a mutant, the other row's cell, refused; and no word at blocks that no run
  produced;
* `naiveSetups`, `naive_fits`, `naive_meetsAt`: the family's setups with one column (every
  launch, memory and tensors of `Mat.Pre`, the oracle family admitted alone), which fit
  (`NaiveFam.sound`), so its behaviors `kernelRows` meet the matrix-vector spec through
  `GPUProof.MeetsAt` (`kernelRows_meetsAt`), at every row stride and width;
* `tensA`, `tensB`, `matIn_tens`, `naive_rows`: at every row stride, width, size `(m, K)` within
  the family's bounds and input words `W`, the tensors of `W` (`+0` past `K`) at the launch of
  `max m 1` blocks of one thread and the memory of `naive_pre` are a setup in `naiveSetups`, so
  behaviors that meet the rule exist (`kernelRows_nonempty`); `naive_rows_3x4` and
  `naive_rows_5x7` are its instances at sizes 3 × 4 (strides 5, 6, 2) and 5 × 7 (strides 7, 7, 1),
  for every `A` and `B`; a mutant, size 2 × 4 at strides 3, 3, 1 (`K` past `sA`), has no setup
  and no behavior;
* `naive_tile` at the corpus program (strides 768, 768, 50257) at one launch and memory, `L12`
  and `mem12`, at two sizes, `K = 768` and `K = 4`, its graded clause at `K = 768`, and the
  placement `place L12 1 2` evaluated.

The tile oracle comes from `NaiveSpec.o`, whose steps `54 + 18 j` and `55 + 18 j` are the
kernel's; it is not computed from the kernel's paths here.
-/
namespace MojoProofTest.TileNaive

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProof.Tile MojoProofTest.SymPhi
open MojoProofTest.NaiveSpec MojoProofTest.NaiveSound MojoProofTest.NaiveKernel
open MojoProofTest.TileGrade (gen)
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

/-- **The naive kernel with one column meets the matrix-vector spec, at its observed memory.**
For every row stride `sA`, `sB`, `sC`, oracle family `ω`, launch `L` valid with `z` sides 1 whose
window covers the `m` rows and column 0, width `bits`, sizes `m` and `K` below `2 ^ 31`, blocks,
tensors `A` (`m × sA`) and `B` (`1 × sB`) and memory of `Mat.Pre` at `n = 1`, and every
observation `Bk` of a complete run of `NaiveFam.prog sA sB sC` under `ω` (`Kernel.Obs`): the
floats of `Bk`'s output block `bC` at the rows' cells `i * sC * 4` (`Elem.word`) are words `W' i`
that meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at size `(m, K)` and encoding
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
    ∃ W' : Fin m → Model FloatTy.float.fmt,
      (∀ i : Fin m, Elem.word naive.prog.layout .float bC (fun r => r * sC * 4) Bk i =
        some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
        (matVecEnc FloatTy.float.fmt bits (m, K)) (matIn A B h.le.2.1 h.le.2.2) W' :=
  mat_holds (l := naive.prog.layout) (ft := .float) (w := 4) hL hz hX hY (by decide) bits h.le.1
    (by
      rw [← bytes_eq ω L h.le.2.1 h.le.2.2 A B]
      exact NaiveFam.sound hL hz h ⟨hsz.1, by decide, hsz.2⟩)
    ⟨_, h.bufs.2.2.choose_spec.1⟩ rfl hB

/-- **`Mat.pre_mem`'s bounds at every size** (a test of `Mat.pre_mem` on the naive family, not a
kernel theorem): for every row stride `sA`, `sB`, `sC`, size `(m, K)` with `1 ≤ sC`, `K ≤ sA`,
`K ≤ sB`, and `m * sC`, `m * sA`, `sB` below `2 ^ 31`, and tensors `A`, `B`, the memory
`Mat.mem` of `A` and `B` at naive's layout, binary32 and alignment 4, with blocks 1, 2, 3 at
addresses `4 (i + 1)` in both spaces, meets the matmul precondition at `n = 1`. The address
premises of `Mat.pre_mem` hold because naive's pointers are 64 bits and a block's extent is below
`2 ^ 33` (`omega`). -/
theorem naive_pre {sA sB sC m K : Nat} (hle : 1 ≤ sC ∧ K ≤ sA ∧ K ≤ sB)
    (hlt : m * sC < 2 ^ 31 ∧ m * sA < 2 ^ 31 ∧ sB < 2 ^ 31)
    (A : Tensor (Model FloatTy.float.fmt) [m, sA]) (B : Tensor (Model FloatTy.float.fmt) [1, sB]) :
    Mat.Pre (NaiveFam.prog sA sB sC).layout (.fp .float) (Val.ofFloat .float) 4 z
      (Mat.mem naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 A B sC (fun i => i.val + 1)
        (fun i => i.val + 1)) 1 2 3 m 1 K sA sB sC A B := by
  have hp : (naive.prog.layout.ptr 0).1 = 64 ∧ (naive.prog.layout.ptr 1).1 = 64 ∧
      naive.prog.layout.size (.fp .float) = 4 := by decide +kernel
  have hl : (NaiveFam.prog sA sB sC).layout = naive.prog.layout := rfl
  exact Mat.pre_mem (Layout.Codec.float _ .float) (fun _ => trivial) 4 _ _ hle
    ⟨hlt.1, hlt.2.1, by omega⟩ (fun i => i.val + 1) (fun i => i.val + 1)
    (fun i => by simp only [hl, hp.2.1]; have := i.2; omega)
    (fun i => by
      simp only [hl, hp.1, hp.2.2]
      fin_cases i <;> simp <;> omega)
    rfl

/-- The caller's memory of `naive_words`: `Mat.mem` at naive's layout, binary32 and alignment 4,
with `C` (2 × 1, row stride 1) at block 1, `A = gen 2 3` at block 2 and `B = gen 1 3` at block 3,
block `i + 1` at address `4 (i + 1)` in both spaces. -/
abbrev memV : Mem :=
  Mat.mem naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 (gen 2 3) (gen 1 3) 1
    (fun i => i.val + 1) (fun i => i.val + 1)

/-- **`memV` meets the matmul precondition** at naive's layout, binary32, alignment 4, `m = 2`,
`n = 1`, `K = 3` and row strides 3, 3 and 1, with `C`, `A` and `B` at blocks 1, 2 and 3
(`naive_pre`, its size bounds by `decide`). For this one memory. -/
theorem preV : Mat.Pre (NaiveFam.prog 3 3 1).layout (.fp .float) (Val.ofFloat .float) 4 z memV
    1 2 3 2 1 3 3 3 1 (gen 2 3) (gen 1 3) :=
  naive_pre ⟨le_rfl, le_rfl, le_rfl⟩ (by decide) _ _

/-- **`naive_holds` at a concrete launch and memory, its words computed** (a test of
`naive_holds`, not a kernel theorem): the family at row strides 3, 3 and 1 on `L12` (one block
of 2 × 2 threads) at `m = 2`, `K = 3`, memory `memV` (`preV`) and the oracle family `0`, width
32. In every observation `Bk` of a complete run, the words `W'` of `naive_holds`, the floats of
`Bk`'s block 1 at bytes 0 and 4, meet the matrix-vector spec's rule at `matIn (gen 2 3) (gen 1 3)`
and are `6` and `-1` (bits `0x40c00000`, `0xbf800000`), the products of the rows `1, 2, -1` and
`2, -1, 1` of `gen 2 3` and the row `1, 2, -1` of `gen 1 3`: they are the tile run's cells
`(0, 0)` and `(1, 0)` (`naive_tile`), which the kernel evaluates. -/
theorem naive_words {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs (NaiveFam.prog 3 3 1) (NaiveFam.fn 3 3 1) L12 (Mat.args z 1 2 3 2 1 3) memV
      (fun m => some m.blocks) ch (fun _ _ => 0) Bk) :
    ∃ W' : Fin 2 → Model FloatTy.float.fmt,
      (∀ i : Fin 2, Elem.word naive.prog.layout .float 1 (fun r => r * 1 * 4) Bk i =
        some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (2, 3)
        (matVecEnc FloatTy.float.fmt 32 (2, 3)) (matIn (gen 2 3) (gen 1 3) le_rfl le_rfl) W' ∧
      (W' 0).toNatBits = 0x40c00000 ∧ (W' 1).toNatBits = 0xbf800000 := by
  obtain ⟨W', hW', hH⟩ := naive_holds NaiveOut.validZ ⟨rfl, rfl⟩ (by decide) (by decide) 32 preV
    (by decide) hB
  obtain ⟨st, hr, h⟩ := naive_tile NaiveOut.validZ ⟨rfl, rfl⟩ preV (by decide) hB
  have e : ∀ i : Fin 2, st.cells 2 (Nat.pair i 0) = some (W' i) := fun i => by
    obtain ⟨_, _, hx, hy, v, hv, hk, _⟩ := h i 0 i.2 Nat.one_pos (i.2.trans_le (by decide))
      (by decide)
    have hk' : Elem.word naive.prog.layout .float 1 (fun r => r * 1 * 4) Bk i = some v := by
      simp only [Elem.word, NaiveFam.cell, hx, hy, Nat.add_zero] at hk ⊢
      exact hk
    rw [hv, ← hk', hW' i]
  have hc : (Except.ok st : Except Sem.Fault (St (Model FloatTy.float.fmt))).toOption.map
      (fun s => ((s.cells 2 (Nat.pair 0 0)).map Model.toNatBits,
        (s.cells 2 (Nat.pair 1 0)).map Model.toNatBits)) =
      some (some 0x40c00000, some 0xbf800000) := by
    rw [← hr]
    decide +kernel
  have e0 : st.cells 2 (Nat.pair 0 0) = some (W' 0) := e 0
  have e1 : st.cells 2 (Nat.pair 1 0) = some (W' 1) := e 1
  simp only [Except.toOption, Option.map_some, e0, e1, Option.some.injEq, Prod.mk.injEq] at hc
  exact ⟨W', hW', hH, hc⟩

/-- **Mutant: the other row's cell is refused** (a test, not a kernel theorem): at the launch,
memory and oracle family of `naive_words`, in every observation `Bk`, no words are both the
floats of `Bk` at the rows' cells `r * 4` and at the other row's cells `(1 - r) * 4`: the two
rows' words are `6` and `-1`. -/
example {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
    (hB : Kernel.Obs (NaiveFam.prog 3 3 1) (NaiveFam.fn 3 3 1) L12 (Mat.args z 1 2 3 2 1 3) memV
      (fun m => some m.blocks) ch (fun _ _ => 0) Bk) :
    ¬ ∃ W' : Fin 2 → Model FloatTy.float.fmt,
      (∀ i : Fin 2, Elem.word naive.prog.layout .float 1 (fun r => r * 1 * 4) Bk i =
        some (W' i)) ∧
      ∀ i : Fin 2, Elem.word naive.prog.layout .float 1 (fun r => (1 - r) * 1 * 4) Bk i =
        some (W' i) := by
  rintro ⟨W', h1, h2⟩
  obtain ⟨W, hW, _, h0, h1'⟩ := naive_words hB
  have a : Elem.word naive.prog.layout .float 1 (fun r => (1 - r) * 1 * 4) Bk 0 =
      Elem.word naive.prog.layout .float 1 (fun r => r * 1 * 4) Bk 1 := rfl
  have e : W 0 = W 1 :=
    Option.some.inj ((hW 0).symm.trans ((h1 0).trans ((h2 0).symm.trans (a.trans (hW 1)))))
  rw [e, h1'] at h0
  exact absurd h0 (by decide)

/-- Without an observation the words are not determined: at the blocks `fun _ => none`, which no
premise ties to a run, row 0's cell holds no float (a test, not a kernel theorem). -/
example : Elem.word naive.prog.layout .float 1 (fun r => r * 1 * 4) (fun _ => none) 0 = none :=
  rfl

/-- The setups of the naive family with one column at row strides `sA`, `sB`, `sC`, size
`(m, K)` and input words `W`, for `naive_meetsAt`: every launch valid with `z` sides 1 whose window
covers the `m` rows and column 0, memory, blocks `bC`, `bA`, `bB`, oracle family `ω` (admitted
alone, at every address choice), sizes below `2 ^ 31` and tensors `A` (`m × sA`) and `B`
(`1 × sB`) of `Mat.Pre` at `n = 1` whose inputs are `W` (`matIn`), with the arguments
`Mat.args`, the output block `bC` and the row stride `sC`. -/
def naiveSetups (sA sB sC : Nat) (σ : ℕ × ℕ)
    (W : Fin σ.1 × Fin σ.2 ⊕ Fin σ.2 → Model FloatTy.float.fmt) : Set MatSetup :=
  {s | ∃ (L : Launch) (mem : Mem) (bC bA bB : Nat) (ω : Nat → Nat → Nat)
      (A : Tensor (Model FloatTy.float.fmt) [σ.1, sA])
      (B : Tensor (Model FloatTy.float.fmt) [1, sB]),
    s = ⟨L, Mat.args z bC bA bB σ.1 1 σ.2, mem, fun _ ω' => ω' = ω, bC, sC⟩ ∧
    ∃ h : Mat.Pre (NaiveFam.prog sA sB sC).layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA
        bB σ.1 1 σ.2 sA sB sC A B,
      matIn A B h.le.2.1 h.le.2.2 = W ∧ L.Valid ∧ (L.grid .z = 1 ∧ L.block .z = 1) ∧
      σ.1 ≤ L.grid .x * L.block .x ∧ 0 < L.grid .y * L.block .y ∧ σ.1 < 2 ^ 31 ∧ σ.2 < 2 ^ 31}

/-- **The naive family's setups fit** (`MatSetup.Fits`), for every row stride `sA`, `sB`, `sC`,
size and input words: `NaiveFam.sound` at each setup, through `bytes_eq` (a test of
`MatSetup.Fits` on the naive family, not a kernel theorem). -/
theorem naive_fits (sA sB sC : Nat) : ∀ m K W, ∀ s ∈ naiveSetups sA sB sC (m, K) W,
    s.Fits (NaiveFam.prog sA sB sC) (NaiveFam.fn sA sB sC) naive.prog.layout .float 4 m K W := by
  rintro m K W s ⟨L, mem, bC, bA, bB, ω, A, B, rfl, h, rfl, hL, hz, hX, hY, hm, hK⟩
  refine ⟨hL, hz, hX, hY, h.le.1, ⟨_, h.bufs.2.2.choose_spec.1⟩, true, fun k => o (ω k), sA, sB,
    h.le.2.1, h.le.2.2, A, B, rfl, ?_⟩
  rw [← bytes_eq ω L h.le.2.1 h.le.2.2 A B]
  exact NaiveFam.sound hL hz h ⟨hm, by decide, hK⟩

/-- **The naive kernel with one column meets the matrix-vector spec through `GPUProof.MeetsAt`**,
for every row stride `sA`, `sB`, `sC` and width `bits`: the behaviors `kernelRows` of
`NaiveFam.prog sA sB sC` at its setups `naiveSetups` meet
`GPUProof.Spec.matVec GPUProof.matVecGrade` at the encoding `matVecEnc` of binary32
(`kernelRows_meetsAt` at `naive_fits`). A test of `kernelRows_meetsAt` on the naive family, not
a kernel theorem. -/
theorem naive_meetsAt (sA sB sC bits : Nat) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
      (kernelRows (NaiveFam.prog sA sB sC) (NaiveFam.fn sA sB sC) naive.prog.layout .float 4 bits
        (naiveSetups sA sB sC)) (matVecEnc FloatTy.float.fmt bits) :=
  kernelRows_meetsAt (by decide) bits (naive_fits sA sB sC)

/-- The first input of the naive family at row stride `sA` whose inputs are the words `W`, for
every size `(m, K)`: entry `(i, k)` is `W (i, k)` for `k < K` and `+0` past `K`. -/
def tensA {m K : Nat} (sA : Nat) (W : Fin m × Fin K ⊕ Fin K → Model FloatTy.float.fmt) :
    Tensor (Model FloatTy.float.fmt) [m, sA] :=
  Tensor.Rep.ofFn fun c =>
    if h : c.2.1.val < K then W (.inl (c.1, ⟨_, h⟩)) else Model.zero _ false

/-- The second input, one row at row stride `sB`, whose inputs are the words `W`: entry `k` is
`W k` for `k < K` and `+0` past `K`. -/
def tensB {m K : Nat} (sB : Nat) (W : Fin m × Fin K ⊕ Fin K → Model FloatTy.float.fmt) :
    Tensor (Model FloatTy.float.fmt) [1, sB] :=
  Tensor.Rep.ofFn fun c => if h : c.2.1.val < K then W (.inr ⟨_, h⟩) else Model.zero _ false

/-- For every size `(m, K)`, row strides `sA`, `sB` at least `K` and input words `W`, the
inputs read from `tensA sA W` and `tensB sB W` are `W` (`matIn`). -/
theorem matIn_tens {m K sA sB : Nat} (hA : K ≤ sA) (hB : K ≤ sB)
    (W : Fin m × Fin K ⊕ Fin K → Model FloatTy.float.fmt) :
    matIn (tensA sA W) (tensB sB W) hA hB = W := by
  funext x
  rcases x with ⟨i, k⟩ | k <;>
    simp [matIn, tensA, tensB, Tensor.get2_eq_apply, Tensor.Rep.get_ofFn]

/-- **The naive family has a setup, and so behaviors, at every size within its bounds** (a test of
`kernelRows_nonempty` and `naive_meetsAt` on the naive family, not a kernel theorem). For every
row stride `sA`, `sB`, `sC`, width `bits`, size `(m, K)` and input words `W` with `1 ≤ sC`,
`K ≤ sA`, `K ≤ sB`, and `m * sC`, `m * sA`, `sB` below `2 ^ 31` (the bounds of `Mat.Pre` at
`n = 1`), the behaviors of `naive_meetsAt` at `W` have output words, and they meet the
matrix-vector spec's rule. The setup: the launch of `max m 1` blocks of one thread, the memory
`Mat.mem` of `tensA sA W` and `tensB sB W` with blocks 1, 2, 3 at addresses `4 (i + 1)`
(`Mat.pre_mem`; its address premises hold at every size because naive's pointers are 64 bits),
and the oracle family `0`. -/
theorem naive_rows {sA sB sC m K : Nat} (bits : Nat) (hle : 1 ≤ sC ∧ K ≤ sA ∧ K ≤ sB)
    (hlt : m * sC < 2 ^ 31 ∧ m * sA < 2 ^ 31 ∧ sB < 2 ^ 31)
    (W : Fin m × Fin K ⊕ Fin K → Model FloatTy.float.fmt) :
    ∃ W', W' ∈ kernelRows (NaiveFam.prog sA sB sC) (NaiveFam.fn sA sB sC) naive.prog.layout .float
        4 bits (naiveSetups sA sB sC) (m, K) (matVecEnc FloatTy.float.fmt bits (m, K)) W ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
        (matVecEnc FloatTy.float.fmt bits (m, K)) W W' := by
  have hm : m ≤ m * sC := Nat.le_mul_of_pos_right m hle.1
  have h := naive_pre hle hlt (tensA sA W) (tensB sB W)
  have hs : (⟨launch2 (max m 1) 1 1 1, Mat.args z 1 2 3 m 1 K,
      Mat.mem naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 (tensA sA W) (tensB sB W) sC
        (fun i => i.val + 1) (fun i => i.val + 1), fun _ ω' => ω' = fun _ _ => 0, 1, sC⟩ :
        MatSetup) ∈ naiveSetups sA sB sC (m, K) W :=
    ⟨_, _, 1, 2, 3, fun _ _ => 0, _, _, rfl, h, matIn_tens _ _ W,
      launch2_valid ⟨by omega, by decide, by decide, by decide, by omega, by decide, by decide⟩,
      ⟨rfl, rfl⟩, show m ≤ max m 1 * 1 by omega, show 0 < 1 * 1 by decide,
      show m < 2 ^ 31 by omega, show K < 2 ^ 31 by omega⟩
  obtain ⟨W', hW'⟩ := kernelRows_nonempty (by decide) bits hs (naive_fits sA sB sC m K W _ hs)
    (ch := fun _ => 0) rfl
  exact ⟨W', hW', naive_meetsAt sA sB sC bits (m, K) W W' hW'⟩

/-- **The naive family's behaviors at size 3 × 4** (a test of `naive_rows`, not a kernel
theorem): for every `A` (`3 × 5`) and `B` (`1 × 6`), at row strides 5, 6 and 2, the behaviors at
the input words `matIn A B` have output words, and they meet the matrix-vector spec's rule
(`naive_rows`, the bounds by `decide`). -/
theorem naive_rows_3x4 (A : Tensor (Model FloatTy.float.fmt) [3, 5])
    (B : Tensor (Model FloatTy.float.fmt) [1, 6]) :
    ∃ W', W' ∈ kernelRows (NaiveFam.prog 5 6 2) (NaiveFam.fn 5 6 2) naive.prog.layout .float 4 32
        (naiveSetups 5 6 2) (3, 4) (matVecEnc FloatTy.float.fmt 32 (3, 4))
        (matIn A B (by decide) (by decide)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (3, 4)
        (matVecEnc FloatTy.float.fmt 32 (3, 4)) (matIn A B (by decide) (by decide)) W' :=
  naive_rows 32 (by decide) (by decide) _

/-- **The naive family's behaviors at size 5 × 7** (a test of `naive_rows`, not a kernel
theorem): for every `A` (`5 × 7`) and `B` (`1 × 7`), at row strides 7, 7 and 1, the behaviors at
the input words `matIn A B` have output words, and they meet the matrix-vector spec's rule. -/
theorem naive_rows_5x7 (A : Tensor (Model FloatTy.float.fmt) [5, 7])
    (B : Tensor (Model FloatTy.float.fmt) [1, 7]) :
    ∃ W', W' ∈ kernelRows (NaiveFam.prog 7 7 1) (NaiveFam.fn 7 7 1) naive.prog.layout .float 4 32
        (naiveSetups 7 7 1) (5, 7) (matVecEnc FloatTy.float.fmt 32 (5, 7))
        (matIn A B le_rfl le_rfl) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (5, 7)
        (matVecEnc FloatTy.float.fmt 32 (5, 7)) (matIn A B le_rfl le_rfl) W' :=
  naive_rows 32 (by decide) (by decide) _

/-- **Mutant: a size past the row stride has no setup** (a test, not a kernel theorem): at row
strides 3, 3 and 1 and size 2 × 4, `K = 4` is past `sA = 3`, so `Mat.Pre` fails at every memory
(`le`), no setup is in `naiveSetups`, and for every input words there is no behavior. -/
example (W : Fin 2 × Fin 4 ⊕ Fin 4 → Model FloatTy.float.fmt)
    (W' : Fin 2 → Model FloatTy.float.fmt) :
    W' ∉ kernelRows (NaiveFam.prog 3 3 1) (NaiveFam.fn 3 3 1) naive.prog.layout .float 4 32
      (naiveSetups 3 3 1) (2, 4) (matVecEnc FloatTy.float.fmt 32 (2, 4)) W := by
  rintro ⟨_, _, ⟨_, _, _, _, _, _, _, _, _, h, _⟩, _⟩
  exact absurd h.le.2.1 (by decide)

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
