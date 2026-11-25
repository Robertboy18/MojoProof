import MojoProof.Tile.Mat
import MojoProof.Sem.WarpDot

/-!
# Dot loops per row meet the matrix-vector spec

`GPUProof.Spec.matVec GPUProof.matVecGrade` is the core's spec of `Matrix.mulVec` at sizes
`(m, n)`, graded at output `i` by `GPUProof.dotGrade` of row `i` and the vector. A matrix
product whose second matrix has one row is a matrix-vector product, so the kernels of
`mojo_kernel`'s `mat` clause meet that spec when `B` has one row. This module defines:

* `MatVecEncs σ`, `matVecEnc fmt bits`: the encodings of the spec's entries, at every grade, and
  its uniform encoding with every real stored in the binary interchange format `fmt`
  (`GPUProof.Encodings.uniform` at `GPUProof.ScalarEnc.std fmt bits`, by definition);
* `rowLoops fmt bits c`: the behaviors whose output `i`, at that encoding, is `dotLoop c` from
  `+0` at some oracle sequence over the pairs of row `i` and the vector; there are none at another
  encoding;
* `matIn A B hA hB`: the spec's input words at size `(m, K)` read from the first `K` columns of a
  matrix `A` (`m × sA`) and of the one row of a matrix `B` (`1 × sB`).

It proves:

* `holds_of`: for every IEEE format, width, lane count, depth, lane length and size, output words
  that are `GPUProof.Approx` at `GPUProof.laneGrade` of every exact row and vector at which their
  inputs are `GPUProof.Approx` meet the rule of `GPUProof.Spec.matVec GPUProof.laneVecGrade`
  (`GPUProof.FloatRule.Holds`); that is the rule unfolded, and at one lane and depth 0 it is the
  rule of `GPUProof.Spec.matVec GPUProof.matVecGrade`, by definition;
* `rowLoops_meetsAt`: for every IEEE format, width and flag, `rowLoops` meets the spec at
  `matVecEnc` (`GPUProof.MeetsAt`; by `holds_of` and `MojoProof.Sem.dotLoop_approx`);
* `meets_holds`: for every IEEE format, width, sizes, matrices, flag, oracle sequences and words
  that meet the product at the cells `(i, 0)` (`Meets`), the words meet the spec's rule at
  `matIn A B hA hB` (by `holds_of` and `Meets`' graded clause);
* `mat_holds`: for every kernel of `mojo_kernel`'s `mat` clause whose `B` has one row, launch
  whose window covers the `m` rows and column 0, and observation of a complete run, the words at
  cells `(i, 0)` of the tile run meet the spec's rule at `matIn A B hA hB` (by `mat_refines` and
  `meets_holds`);
* `stride_approx`: for every IEEE format, flag, oracle sequences, lane count `W`, length `n`, tree
  whose leaves are the lanes, each once, and input grades, the loops of the lanes over the pairs
  strided by `W` (`stride`), added along the tree, are `GPUProof.Approx` at
  `GPUProof.laneGrade` at the tree's depth and lane length `⌈n / W⌉`
  (`MojoProof.Sem.treeDot_approx`);
* `bfly_approx`, `groupDot_approx`: for every IEEE format, number of rounds `k`, flag, oracle
  sequences, length and input grades, every lane of the butterfly over `2 ^ k` strided loops, and
  so `groupDot k` (`warpDot` at `k = 5`), is `GPUProof.Approx` at `GPUProof.laneGrade` at `2 ^ k`
  lanes and depth `k`: each lane adds along its own tree `bflyTree (bflyOffsets k) l`, over all
  the lanes in an order that differs by lane;
* `groupDot_holds`: for every IEEE format, width, `k`, flag, size, oracle sequences and input
  words, `groupDot k` per row meets the rule of
  `GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`.

Nothing here is in the trusted base.
-/

namespace MojoProof.Tile

open MojoProof.Sem MojoProof.Sym FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange
  TorchLean

/-- The encodings of the entries of a matrix-vector product at size `(m, n)`, all of them real:
inputs `(Fin m × Fin n) ⊕ Fin n`, outputs `Fin m`, as in `GPUProof.Spec.matVec` at every grade. -/
abbrev MatVecEncs (σ : ℕ × ℕ) : Type 1 :=
  GPUProof.Encodings (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) (fun σ => Fin σ.1)
    (fun _ _ => .real) (fun _ _ => .real) σ

/-- The uniform encoding of a matrix-vector product at every size, for every binary interchange
format `fmt` and integer width `bits`: every entry stored as a word of `fmt`, by definition
`GPUProof.Encodings.uniform` at `GPUProof.ScalarEnc.std fmt bits` of
`GPUProof.Spec.matVec GPUProof.matVecGrade`. Its entries' types do not depend on the grade, so it
is the uniform encoding of `GPUProof.Spec.matVec` at every grade, by unfolding (instances:
`MojoProofTest.TileMatVec.enc_grades`). -/
noncomputable abbrev matVecEnc (fmt : FloatFormat) (bits : Nat) (σ : ℕ × ℕ) : MatVecEncs σ :=
  GPUProof.Encodings.uniform (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
    (GPUProof.ScalarEnc.std fmt bits) σ

/-- **The behaviors of a dot loop per row**, for every binary interchange format `fmt`, width
`bits`, flag `c` and size `(m, n)`: at the encoding `matVecEnc fmt bits`, the output words `W'`
such that, for some oracle sequence `o i` of each row, `W' i` is `dotLoop c (o i)` from `+0` over
the pairs `(W (i, k), W k)`, `k < n`, of row `i` and the vector; at another encoding, none. -/
noncomputable def rowLoops (fmt : FloatFormat) (bits : Nat) (c : Bool) (σ : ℕ × ℕ)
    (E : MatVecEncs σ) (W : E.inp.Words) : Set E.out.Words :=
  {W' | ∃ h : E = matVecEnc fmt bits σ, ∃ o : Fin σ.1 → Nat → Nat × Nat, ∀ i,
    (h ▸ W' : (matVecEnc fmt bits σ).out.Words) i = dotLoop c (o i) (Model.zero fmt false)
      (List.ofFn fun k => ((h ▸ W : (matVecEnc fmt bits σ).inp.Words) (.inl (i, k)),
        (h ▸ W : (matVecEnc fmt bits σ).inp.Words) (.inr k)))}

/-- **The spec's rule unfolded.** For every IEEE format `fmt`, width `bits`, lane count `W`,
depth `d`, lane length `L`, size `(m, n)`, input words `I` and output words `O` at
`matVecEnc fmt bits`: if for every output `i`, exact row `a` and vector `x` and grades `ga`, `gx`
at which the words of row `i` and of the vector are `GPUProof.Approx`, `O i` is `GPUProof.Approx`
at `GPUProof.laneGrade (.ieee fmt) W d (L n) n a x ga gx` of `Σₖ aₖ xₖ`, then `O` meets
`GPUProof.Spec.matVec (GPUProof.laneVecGrade W d L)`'s rule at `I`. At `W = 1`, `d = 0`,
`L = id` that is `GPUProof.Spec.matVec GPUProof.matVecGrade` and `GPUProof.dotGrade`, by
definition. -/
theorem holds_of {fmt : FloatFormat} (bits W d : Nat) (L : ℕ → ℕ) {σ : ℕ × ℕ}
    {I : (matVecEnc fmt bits σ).inp.Words} {O : (matVecEnc fmt bits σ).out.Words}
    (h : ∀ (i : Fin σ.1) (a x : Fin σ.2 → ℝ) (ga gx : Fin σ.2 → GPUProof.Grade),
      (∀ k, GPUProof.Approx .real (ga k) (.ieee fmt) (Model.toReal? (I (.inl (i, k)))) (a k)) →
      (∀ k, GPUProof.Approx .real (gx k) (.ieee fmt) (Model.toReal? (I (.inr k))) (x k)) →
      GPUProof.Approx .real (GPUProof.laneGrade (.ieee fmt) W d (L σ.2) σ.2 a x ga gx) (.ieee fmt)
        (Model.toReal? (O i)) (∑ k, a k * x k)) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade W d L)
      (GPUProof.laneVecGrade_mono W d L)).rule.Holds σ (matVecEnc fmt bits σ) I O :=
  fun _ _ _ hA o => h o _ _ _ _ (fun k => hA (.inl (o, k))) (fun k => hA (.inr k))

/-- **A dot loop per row meets the matrix-vector spec.** For every IEEE format `fmt`, width
`bits` and flag `c`, the behaviors `rowLoops fmt bits c` meet
`GPUProof.Spec.matVec GPUProof.matVecGrade` at the encoding `matVecEnc fmt bits`
(`GPUProof.MeetsAt`), at every size, input words, oracle sequences and input grades (`holds_of`,
`MojoProof.Sem.dotLoop_approx`). -/
theorem rowLoops_meetsAt {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat) (c : Bool) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
      (rowLoops fmt bits c) (matVecEnc fmt bits) := by
  rintro σ W W' ⟨_, o, hW'⟩
  refine holds_of bits 1 0 id fun i a x ga gx ha hx => ?_
  have e : W' i = dotLoop c (o i) (Model.zero fmt false)
      (List.ofFn fun k => (W (.inl (i, k)), W (.inr k))) := hW' i
  rw [e]
  exact dotLoop_approx hfmt c (o i) _ _ a x ga gx ha hx

/-- The input words of `GPUProof.Spec.matVec` at size `(m, K)` read from matrices `A` (`m × sA`)
and `B` (`1 × sB`), for every format and `K ≤ sA`, `K ≤ sB`: entry `(i, k)` of `A` at input
`(i, k)` and entry `(0, k)` of `B` at input `k`, `k < K`. -/
def matIn {fmt : FloatFormat} {m sA sB K : Nat} (A : Tensor (Model fmt) [m, sA])
    (B : Tensor (Model fmt) [1, sB]) (hA : K ≤ sA) (hB : K ≤ sB) :
    Fin m × Fin K ⊕ Fin K → Model fmt :=
  Sum.elim (fun ik => Tensor.get2 A ik.1 (Fin.castLE hA ik.2))
    fun k => Tensor.get2 B 0 (Fin.castLE hB k)

/-- **Words that meet the product with one column meet the matrix-vector spec.** For every IEEE
format `fmt`, width `bits`, sizes with `K ≤ sA` and `K ≤ sB`, matrices `A` (`m × sA`) and `B`
(`1 × sB`), flag `c`, oracle sequences `o i` and words `v i` that meet the product at the cells
`(i, 0)` (`Meets`), the words `v` meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at size
`(m, K)` and encoding `matVecEnc fmt bits` from the inputs `matIn A B hA hB` (`holds_of`, and
`Meets`' graded clause at each output). -/
theorem meets_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat)
    {m sA sB K : Nat} {A : Tensor (Model fmt) [m, sA]} {B : Tensor (Model fmt) [1, sB]}
    {hA : K ≤ sA} {hB : K ≤ sB} {c : Bool} {o : Fin m → Nat → Nat × Nat} {v : Fin m → Model fmt}
    (h : ∀ i, Meets A B hA hB i 0 c (o i) (v i)) :
    (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
      (matVecEnc fmt bits (m, K)) (matIn A B hA hB) v :=
  holds_of bits 1 0 id fun i a x ga gx ha hx => (h i).2.2 hfmt a x ga gx ha hx

/-- **A kernel of the `mat` clause with one column meets the matrix-vector spec.** For every
program, kernel, launch `L` valid with `z` sides 1 whose window covers the `m` rows and column 0,
arguments, memory `mem` with a block `out`, admission, layout `l`, float type `ft` whose stored
size is `w`, width `bits`, flag `c`, oracle numbers `o`, sizes with `K ≤ sA`, `K ≤ sB` and
`1 ≤ sC`, and matrices `A` (`m × sA`) and `B` (`1 × sB`): if the kernel is sound for `Elem.Out`
with `matBytes` (`mat_refines`' premise, the shape of `Kernel.sound_mat`'s conclusion), then for
every admitted choice and oracle and every observation of a complete run, the run of
`dot c K (place L m 1)` from `mats A B` at `pairOracle o` ends without a fault in a state whose
cells `(i, 0)` of buffer 2 hold words `W' i` that meet `GPUProof.Spec.matVec
GPUProof.matVecGrade`'s rule at size `(m, K)` and encoding `matVecEnc ft.fmt bits` from
`matIn A B hA hB` (`mat_refines`, `meets_holds`). It covers every kernel with such a theorem
(instance: `MojoProofTest.TileNaive.naive_holds`, the naive matmul kernel). -/
theorem mat_holds {prog : LLVM.Program} {fn : LLVM.Func} {L : Launch} {m : Nat} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) (hX : m ≤ L.grid .x * L.block .x)
    (hY : 0 < L.grid .y * L.block .y) {args : List Val} {mem : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {out : Nat} {l : Layout} {ft : LLVM.FloatTy}
    {w : Nat} (hw : l.stored (.fp ft) = w) (bits : Nat) {c : Bool} {o : Nat → Nat → Nat × Nat}
    {sA sB sC K : Nat} (hsC : 1 ≤ sC) {hA : K ≤ sA} {hB : K ≤ sB}
    {A : Tensor (Model ft.fmt) [m, sA]} {B : Tensor (Model ft.fmt) [1, sB]}
    (h : Kernel.Sound prog fn L args mem adm (fun m => some m.blocks)
      (Elem.Out mem out (fun k => (L.index k .x * sC + L.index k .y) * w)
        (matBytes l ft c o L hA hB A B) (volume L.grid * volume L.block)))
    (hb : ∃ blk, mem.blocks out = some blk) {ch : Nat → Nat} {ω : Nat → Nat → Nat}
    (ha : adm ch ω) {Bk : Nat → Option Sem.Block}
    (hO : Kernel.Obs prog fn L args mem (fun m => some m.blocks) ch ω Bk) :
    ∃ st, runAll (pairOracle o) (dot c K (place L m 1)) (volume L.grid * volume L.block)
        (mats A B) = .ok st ∧ ∃ W' : Fin m → Model ft.fmt,
      (∀ i : Fin m, st.cells 2 (Nat.pair i 0) = some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
        (matVecEnc ft.fmt bits (m, K)) (matIn A B hA hB) W' := by
  obtain ⟨st, hr, h2⟩ := mat_refines hL hz hw hsC h hb ha hO
  have hc : ∀ i : Fin m, ∃ v, st.cells 2 (Nat.pair i 0) = some v ∧
      ∃ oi, Meets A B hA hB i 0 c oi v := fun i => by
    obtain ⟨_, _, _, _, v, hv, _, hm⟩ := h2 i 0 i.2 Nat.one_pos (i.2.trans_le hX) hY
    exact ⟨v, hv, _, hm⟩
  choose W' hW' os hm using hc
  exact ⟨st, hr, W', hW', meets_holds (isIEEE_fmt ft) bits hm⟩

/-! ## Dot products over lanes -/

/-- **A strided dot product added along a tree meets `GPUProof.laneGrade`**: for every IEEE
format `fmt`, flag `c`, oracle sequences `o j` (each iteration fused or not), lane count `W`,
length `n`, tree `t` whose leaves are the lanes `0, …, W - 1`, each once, and input grades `ga`,
`gx`: when each word `w k`, `v k` is `GPUProof.Approx` at `ga k`, `gx k` of the exact `a k`,
`x k`, the word of `MojoProof.Sem.treeDot` over the lanes' lists `stride W j` of the pairs
`(w k, v k)` (lane `j` has the pairs with `k ≡ j` modulo `W`, at most `⌈n / W⌉`) is
`GPUProof.Approx` at `GPUProof.laneGrade (.ieee fmt) W t.depth ⌈n / W⌉ n a x ga gx` of
`Σₖ aₖ xₖ` (`MojoProof.Sem.treeDot_approx`, `sum_stride`, `length_stride_le`). -/
theorem stride_approx {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (c : Bool)
    (o : Nat → Nat → Nat × Nat) {W n : Nat} (t : FloatLib.Numerics.ReductionTree Nat)
    (ht : t.leaves.Perm (List.range W)) (w v : Fin n → Model fmt) (a x : Fin n → ℝ)
    (ga gx : Fin n → GPUProof.Grade)
    (hw : ∀ k, GPUProof.Approx .real (ga k) (.ieee fmt) (w k).toReal? (a k))
    (hv : ∀ k, GPUProof.Approx .real (gx k) (.ieee fmt) (v k).toReal? (x k)) :
    GPUProof.Approx .real
      (GPUProof.laneGrade (.ieee fmt) W t.depth ((n + W - 1) / W) n a x ga gx) (.ieee fmt)
      (treeDot t c o fun j => stride W j (List.ofFn fun k => (w k, v k))).toReal?
      (∑ k, a k * x k) := by
  have hW : 0 < W := by
    have := ht.length_eq
    rw [FloatLib.Numerics.ReductionTree.length_leaves, List.length_range] at this
    omega
  refine treeDot_approx hfmt c o t ht _ (fun j hj => ?_) w v (fun g => ?_) a x ga gx hw hv
  · exact (length_stride_le hj _).trans_eq (by rw [List.length_ofFn])
  · rw [Finset.sum_eq_multiset_sum, Finset.range_val, Multiset.range, Multiset.map_coe,
      Multiset.sum_coe, sum_stride hW, List.map_ofFn, List.sum_ofFn]
    rfl

/-- **Every lane of a butterfly meets `GPUProof.laneGrade`**: for every IEEE format `fmt`, number
of rounds `k`, flag `c`, oracle sequences `o j`, length `n`, lane `l < 2 ^ k` and input grades,
when each word `w k`, `v k` is `GPUProof.Approx` at its grade of the exact entry, lane `l`'s word
after the `k` butterfly rounds of FloatLib's `Model.add` at `bflyOffsets k` from lane `j`'s loop
over `stride (2 ^ k) j` of the pairs is `GPUProof.Approx` at
`GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ⌈n / 2 ^ k⌉ n` of `Σᵢ aᵢ xᵢ`. Lane `l`'s word is
`MojoProof.Sem.treeDot` along its own tree `bflyTree (bflyOffsets k) l` (`eval_bflyTree`), whose
leaves are all the lanes (`leaves_offsets`) in an order that differs by lane, and whose depth is
`k` (`depth_bflyTree`): `stride_approx` at that tree. -/
theorem bfly_approx {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (k : Nat) (c : Bool)
    (o : Nat → Nat → Nat × Nat) {n l : Nat} (hl : l < 2 ^ k) (w v : Fin n → Model fmt)
    (a x : Fin n → ℝ) (ga gx : Fin n → GPUProof.Grade)
    (hw : ∀ i, GPUProof.Approx .real (ga i) (.ieee fmt) (w i).toReal? (a i))
    (hv : ∀ i, GPUProof.Approx .real (gx i) (.ieee fmt) (v i).toReal? (x i)) :
    GPUProof.Approx .real
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((n + 2 ^ k - 1) / 2 ^ k) n a x ga gx) (.ieee fmt)
      (bflyRounds (fun x y => Model.add x y) (bflyOffsets k) (fun j => dotLoop c (o j)
        (Model.zero fmt false) (stride (2 ^ k) j (List.ofFn fun i => (w i, v i)))) l).toReal?
      (∑ i, a i * x i) := by
  have h := stride_approx hfmt c o (bflyTree (bflyOffsets k) l) (leaves_offsets k l hl) w v a x
    ga gx hw hv
  rwa [depth_bflyTree, show (bflyOffsets k).length = k by simp [bflyOffsets], treeDot,
    eval_bflyTree] at h

/-- **A lane group's dot product meets `GPUProof.laneGrade`**: for every IEEE format `fmt`,
number of rounds `k`, flag `c`, oracle sequences, length `n` and input grades, when each word
`w i`, `v i` is `GPUProof.Approx` at its grade of the exact entry, `groupDot k c o` of the pairs
(lane 0 of the butterfly; `warpDot` at `k = 5`, the gemv kernel's reduction) is
`GPUProof.Approx` at `GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ⌈n / 2 ^ k⌉ n` of `Σᵢ aᵢ xᵢ`:
`bfly_approx` at lane 0. -/
theorem groupDot_approx {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (k : Nat) (c : Bool)
    (o : Nat → Nat → Nat × Nat) {n : Nat} (w v : Fin n → Model fmt) (a x : Fin n → ℝ)
    (ga gx : Fin n → GPUProof.Grade)
    (hw : ∀ i, GPUProof.Approx .real (ga i) (.ieee fmt) (w i).toReal? (a i))
    (hv : ∀ i, GPUProof.Approx .real (gx i) (.ieee fmt) (v i).toReal? (x i)) :
    GPUProof.Approx .real
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((n + 2 ^ k - 1) / 2 ^ k) n a x ga gx) (.ieee fmt)
      (groupDot k c o (List.ofFn fun i => (w i, v i))).toReal? (∑ i, a i * x i) :=
  bfly_approx hfmt k c o (Nat.two_pow_pos k) w v a x ga gx hw hv

/-- **A lane group per row meets the matrix-vector spec's rule**: for every IEEE format `fmt`,
width `bits`, number of rounds `k`, flag `c`, size `(m, n)`, oracle sequences `o i` of each row
and input words `I` at `matVecEnc fmt bits`, the words `groupDot k c (o i)` over the pairs
`(I (i, j), I j)` of row `i` and the vector meet the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)` (`holds_of`,
`groupDot_approx`). -/
theorem groupDot_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits k : Nat) (c : Bool)
    {σ : ℕ × ℕ} (o : Fin σ.1 → Nat → Nat → Nat × Nat) (I : (matVecEnc fmt bits σ).inp.Words) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => (n + 2 ^ k - 1) / 2 ^ k)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds σ (matVecEnc fmt bits σ) I
      fun i => groupDot k c (o i) (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))) :=
  holds_of bits _ _ _ fun i a x ga gx ha hx => groupDot_approx hfmt k c (o i) _ _ a x ga gx ha hx

end MojoProof.Tile
