import MojoProof.Tile.Mat
import MojoProof.Sem.WarpDot
import GPUProof.Spec.DecEq

/-!
# Dot loops per row meet the matrix-vector spec

`GPUProof.Spec.matVec GPUProof.matVecGrade` is the core's spec of `Matrix.mulVec` at sizes
`(m, n)`, graded at output `i` by `GPUProof.dotGrade` of row `i` and the vector. A matrix
product whose second matrix has one row is a matrix-vector product, so the kernels of
`mojo_kernel`'s `mat` clause meet that spec when `B` has one row. This module defines:

* `MatVecEncs σ`, `matVecEnc fmt bits`: the encodings of the spec's entries, at every grade, and
  its uniform encoding with every real stored in the binary interchange format `fmt`
  (`GPUProof.Encodings.uniform` at `GPUProof.ScalarEnc.std fmt bits`, by definition), whose
  words at every position have decidable equality (`GPUProof.Encodings.decEqUniformInp`,
  `GPUProof.Encodings.decEqUniformOut`, from GPUProof/Spec/DecEq.lean, imported here);
* `rowTrees fmt bits W t c`: the behaviors whose output `i`, at that encoding, is `W` lanes, each
  a `dotLoop c` from `+0` at some oracle sequence over the pairs of row `i` and the vector strided
  by `W`, added along the tree `t` (`MojoProof.Sem.treeDot`); there are none at another encoding;
* `rowLoops fmt bits c`: `rowTrees` at one lane and the tree `.leaf 0`, a dot loop per row;
* `matIn A B hA hB`: the spec's input words at size `(m, K)` read from the first `K` columns of a
  matrix `A` (`m × sA`) and of the one row of a matrix `B` (`1 × sB`);
* `MatSetup`, `MatSetup.Fits`, `kernelRows`: a kernel's launch on the product's inputs (launch,
  arguments, memory, admission, output block and row stride), the premises of `mat_holds` at one,
  and a kernel's behaviors: at setups `S`, the floats of the output block at the rows' cells in
  the observations of admitted complete runs (`Kernel.Obs`, `Elem.word`).

It proves:

* `holds_of`: for every IEEE format, width, lane count, depth, lane length and size, output words
  that are `GPUProof.Approx` at `GPUProof.laneGrade` of every exact row and vector at which their
  inputs are `GPUProof.Approx` meet the rule of `GPUProof.Spec.matVec GPUProof.laneVecGrade`
  (`GPUProof.FloatRule.Holds`); that is the rule unfolded, and at one lane and depth 0 it is the
  rule of `GPUProof.Spec.matVec GPUProof.matVecGrade`, by definition;
* `meets_holds`: for every IEEE format, width, sizes, matrices, flag, oracle sequences and words
  that meet the product at the cells `(i, 0)` (`Meets`), the words meet the spec's rule at
  `matIn A B hA hB` (by `holds_of` and `Meets`' graded clause);
* `mat_holds`: for every kernel of `mojo_kernel`'s `mat` clause whose `B` has one row, launch
  whose window covers the `m` rows and column 0, and observation `Bk` of a complete run, the
  floats of `Bk`'s output block at the rows' cells `i * sC * w` (`Elem.word`) are words that meet
  the spec's rule at `matIn A B hA hB` (by `mat_refines` and `meets_holds`);
* `kernelRows_meetsAt`, `kernelRows_nonempty`: for every kernel and setups that fit,
  `kernelRows` meets the spec at `matVecEnc` (`GPUProof.MeetsAt`, by `mat_holds`), and a fitting
  setup gives behaviors (by `Kernel.Sound.exists_obs`);
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
* `rowTrees_meetsAt`: for every IEEE format, width, lane count, tree whose leaves are the lanes,
  each once, and flag, `rowTrees` meets
  `GPUProof.Spec.matVec (GPUProof.laneVecGrade W t.depth fun n => ⌈n / W⌉)` at `matVecEnc`
  (`GPUProof.MeetsAt`; by `holds_of` and `stride_approx`);
* `groupDot_holds`: for every IEEE format, width, `k`, flag, size, oracle sequences and input
  words, `groupDot k` per row meets the rule of
  `GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`, the case of
  `rowTrees_meetsAt` at lane 0's butterfly tree;
* `bflyDeliver_holds`: the same for the semantics' rounds, whose `fadd` goes through `deliver`
  with an oracle number per round and lane (`bflyRoundsAt`): each row's word is `groupDot k`'s or
  both are NaNs (`MojoProof.Sem.bflyDeliver_nanEq`), and the two decode alike, so the words meet
  the same rule; at `k = 5` the spec side of gemv_kernel's output;
* `bflyRoundsAt_take_succ`: for every carrier, combination per round and lane, offsets, round,
  values and lane, the value after the first `r + 1` rounds is round `r`'s combination of the
  lane's and its partner's values after the first `r` rounds;
* `bflyRoundsAt_chain`: for every type, round function, offsets and set of lanes that holds each
  round's partners, values per round and lane of which each, at every lane of the set, is the
  round function of the lane's own and its partner's values the round before are the butterfly
  rounds `bflyRoundsAt` over the first `r` offsets from the first values, at every lane of the set
  (the lanes' partner chain, closed over all the lanes at once);
* `stride_one`, `rowLoops_dotLoop`: one lane's strided list is the whole list, so for every
  format, width, flag, size, oracle sequences and input words, a `dotLoop` from `+0` per row is a
  behavior of `rowLoops`;
* `meetsAt_grade`: behaviors that meet `GPUProof.Spec.matVec` at one grade meet it at an equal
  one;
* `rowLoops_meetsAt`: for every IEEE format, width and flag, `rowLoops` meets
  `GPUProof.Spec.matVec GPUProof.matVecGrade` at `matVecEnc` (`GPUProof.MeetsAt`), the case of
  `rowTrees_meetsAt` at one lane, by `meetsAt_grade`: the grade of `rowTrees_meetsAt` at one lane
  and the tree `.leaf 0`, with lane length `⌈n / 1⌉`, is `GPUProof.matVecGrade`, with lane length
  `n`; the two differ by definition and are equal by `n + 1 - 1 = n` and `n / 1 = n`.

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
`Meets`' graded clause at each output). The words need not come from a kernel; `mat_holds` gives
words of a kernel's observed memory that meet the product. -/
theorem meets_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat)
    {m sA sB K : Nat} {A : Tensor (Model fmt) [m, sA]} {B : Tensor (Model fmt) [1, sB]}
    {hA : K ≤ sA} {hB : K ≤ sB} {c : Bool} {o : Fin m → Nat → Nat × Nat} {v : Fin m → Model fmt}
    (h : ∀ i, Meets A B hA hB i 0 c (o i) (v i)) :
    (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
      (matVecEnc fmt bits (m, K)) (matIn A B hA hB) v :=
  holds_of bits 1 0 id fun i a x ga gx ha hx => (h i).2.2 hfmt a x ga gx ha hx

/-- **A kernel of the `mat` clause with one column meets the matrix-vector spec, at its observed
memory.** For every program, kernel, launch `L` valid with `z` sides 1 whose window covers the
`m` rows and column 0, arguments, memory `mem` with a block `out`, admission, layout `l`, float
type `ft` whose stored size is `w`, width `bits`, flag `c`, oracle numbers `o`, sizes with
`K ≤ sA`, `K ≤ sB` and `1 ≤ sC`, and matrices `A` (`m × sA`) and `B` (`1 × sB`): if the kernel is
sound for `Elem.Out` with `matBytes` (`h`, `mat_refines`' premise, the shape of
`Kernel.sound_mat`'s conclusion), then for every admitted choice and oracle (`ha`) and every
observation `Bk` of a complete run (`hO`), there are words `W' i` such that

* the float of `Bk`'s block `out` at row `i`'s cell, `i * sC * w` (`Elem.word` at the cells
  `fun r => r * sC * w`), is `W' i`, for every row `i < m`: from `h`, `ha` and `hO` through
  `Kernel.Sound.obs` and `mat_word` (with `hb`, `hw` and `hsC`), at the thread of row `i` and
  column 0 that the window gives (`hX`, `hY`);
* `W'` meets `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule at size `(m, K)` and encoding
  `matVecEnc ft.fmt bits` from `matIn A B hA hB`: from `Meets`' graded clause at each of those
  words (`meets_holds`).

Without `h` and `hO` the first conjunct is not derivable: `Bk` is then any blocks, and blocks
with no block `out` have no word at any row (tested in MojoProofTest/TileNaive.lean at
`fun _ => none`). The tile run that computes the same words is `mat_refines`' conclusion. It
covers every kernel with such a theorem (instances: `MojoProofTest.TileNaive.naive_holds`, the
naive matmul kernel, and `MojoProofTest.TileNaive.naive_words`, its words computed at one
launch and memory). -/
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
    ∃ W' : Fin m → Model ft.fmt,
      (∀ i : Fin m, Elem.word l ft out (fun r => r * sC * w) Bk i = some (W' i)) ∧
      (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono).rule.Holds (m, K)
        (matVecEnc ft.fmt bits (m, K)) (matIn A B hA hB) W' := by
  obtain ⟨_, _, h2⟩ := mat_refines hL hz hw hsC h hb ha hO
  have hc : ∀ i : Fin m, ∃ v, Elem.word l ft out (fun r => r * sC * w) Bk i = some v ∧
      ∃ oi, Meets A B hA hB i 0 c oi v := fun i => by
    obtain ⟨_, _, hx, hy, v, _, hk, hm⟩ := h2 i 0 i.2 Nat.one_pos (i.2.trans_le hX) hY
    refine ⟨v, ?_, _, hm⟩
    simp only [Elem.word, hx, hy, Nat.add_zero] at hk ⊢
    exact hk
  choose W' hW' os hm using hc
  exact ⟨W', hW', meets_holds (isIEEE_fmt ft) bits hm⟩

/-! ## A kernel's behaviors -/

/-- **A launch of a kernel on a matrix-vector product's inputs**, for `kernelRows`: the launch,
the kernel's arguments, the caller's memory, the admitted address choices and oracles, the output
block and the output's row stride in elements. -/
structure MatSetup where
  /-- Builds a setup from its six fields. -/
  mk ::
  /-- The launch. -/
  L : Launch
  /-- The kernel's arguments. -/
  args : List Val
  /-- The caller's memory. -/
  mem : Mem
  /-- The admitted address choices and oracles. -/
  adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop
  /-- The output block. -/
  out : Nat
  /-- The output's row stride, in elements. -/
  sC : Nat

/-- **Setup `s` runs a kernel as a matrix-vector product** of size `(m, K)` on the input words
`W`, for every program, kernel, layout `l` and float type `ft` stored in `w` bytes: `s`'s launch
is valid with `z` sides 1 and its window covers the `m` rows and column 0, the output's row
stride is positive, the memory has the output block, and for some flag, oracle numbers, row
strides `sA`, `sB` with `K ≤ sA`, `K ≤ sB` and matrices `A` (`m × sA`) and `B` (`1 × sB`) whose
inputs are `W` (`matIn`), the kernel is sound at `s` for `Elem.Out` with `matBytes`: the premises
of `mat_holds`. -/
def MatSetup.Fits (prog : LLVM.Program) (fn : LLVM.Func) (l : Layout) (ft : LLVM.FloatTy)
    (w : Nat) (s : MatSetup) (m K : Nat) (W : Fin m × Fin K ⊕ Fin K → Model ft.fmt) : Prop :=
  s.L.Valid ∧ (s.L.grid .z = 1 ∧ s.L.block .z = 1) ∧ m ≤ s.L.grid .x * s.L.block .x ∧
    0 < s.L.grid .y * s.L.block .y ∧ 1 ≤ s.sC ∧ (∃ blk, s.mem.blocks s.out = some blk) ∧
    ∃ (c : Bool) (o : Nat → Nat → Nat × Nat) (sA sB : Nat) (hA : K ≤ sA) (hB : K ≤ sB)
      (A : Tensor (Model ft.fmt) [m, sA]) (B : Tensor (Model ft.fmt) [1, sB]),
      matIn A B hA hB = W ∧
      Kernel.Sound prog fn s.L s.args s.mem s.adm (fun M => some M.blocks)
        (Elem.Out s.mem s.out (fun k => (s.L.index k .x * s.sC + s.L.index k .y) * w)
          (matBytes l ft c o s.L hA hB A B) (volume s.L.grid * volume s.L.block))

/-- **The behaviors of a kernel on a matrix-vector product's inputs**, for every program `prog`,
kernel `fn`, layout `l`, float type `ft` stored in `w` bytes, width `bits`, setups `S` and size
`(m, K)`: at the encoding `matVecEnc ft.fmt bits` and input words `W`, the output words `W'` such
that, for some setup `s ∈ S (m, K) W`, address choice `ch` and oracle `ω` that `s` admits and
observation `Bk` of a complete run of `fn` from `s` (`Kernel.Obs`), `W' i` is the float of `Bk`'s
block `s.out` at row `i`'s cell `i * s.sC * w` (`Elem.word`), for every row `i < m`; at another
encoding, none. -/
noncomputable def kernelRows (prog : LLVM.Program) (fn : LLVM.Func) (l : Layout)
    (ft : LLVM.FloatTy) (w bits : Nat)
    (S : ∀ σ : ℕ × ℕ, (Fin σ.1 × Fin σ.2 ⊕ Fin σ.2 → Model ft.fmt) → Set MatSetup) (σ : ℕ × ℕ)
    (E : MatVecEncs σ) (W : E.inp.Words) : Set E.out.Words :=
  {W' | ∃ h : E = matVecEnc ft.fmt bits σ,
    ∃ s ∈ S σ (h ▸ W : (matVecEnc ft.fmt bits σ).inp.Words), ∃ ch ω Bk, s.adm ch ω ∧
      Kernel.Obs prog fn s.L s.args s.mem (fun M => some M.blocks) ch ω Bk ∧
      ∀ i : Fin σ.1, Elem.word l ft s.out (fun r => r * s.sC * w) Bk i =
        some ((h ▸ W' : (matVecEnc ft.fmt bits σ).out.Words) i)}

/-- **A kernel meets the matrix-vector spec at its observed memory** (`GPUProof.MeetsAt`). For
every program, kernel, layout `l`, float type `ft` stored in `w` bytes, width `bits` and setups
`S` that all fit (`MatSetup.Fits`, at every size and input words), the behaviors
`kernelRows prog fn l ft w bits S` meet `GPUProof.Spec.matVec GPUProof.matVecGrade` at the
encoding `matVecEnc ft.fmt bits`: the observed output words of every admitted run meet the rule
at their inputs (`mat_holds` at each run). It is vacuous at a size where `S` gives no setup;
`kernelRows_nonempty` gives behaviors (instances: `MojoProofTest.TileNaive.naive_meetsAt`, the
naive family at every row stride, and `MojoProofTest.TileNaive.naive_rows`, its behaviors at
every size within its bounds). -/
theorem kernelRows_meetsAt {prog : LLVM.Program} {fn : LLVM.Func} {l : Layout}
    {ft : LLVM.FloatTy} {w : Nat} (hw : l.stored (.fp ft) = w) (bits : Nat)
    {S : ∀ σ : ℕ × ℕ, (Fin σ.1 × Fin σ.2 ⊕ Fin σ.2 → Model ft.fmt) → Set MatSetup}
    (hS : ∀ m K W, ∀ s ∈ S (m, K) W, s.Fits prog fn l ft w m K W) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
      (kernelRows prog fn l ft w bits S) (matVecEnc ft.fmt bits) := by
  rintro ⟨m, K⟩ W W' ⟨_, s, hs, ch, ω, Bk, ha, hO, hW⟩
  obtain ⟨hL, hz, hX, hY, hsC, hb, c, o, sA, sB, hA, hB, A, B, rfl, h⟩ := hS m K W s hs
  obtain ⟨V, hV, hH⟩ := mat_holds hL hz hX hY hw bits hsC h hb ha hO
  have e : V = W' := funext fun i => Option.some.inj ((hV i).symm.trans (hW i))
  exact e ▸ hH

/-- **A fitting setup gives behaviors.** For every program, kernel, layout, float type stored in
`w` bytes, width `bits`, setups `S`, size `(m, K)`, input words `W`, setup `s ∈ S (m, K) W` that
fits (`MatSetup.Fits`) and address choice and oracle that `s` admits, `kernelRows` has output
words at `W`: the observed words of the run that `Kernel.Sound.exists_obs` gives, which
`mat_holds` reads. -/
theorem kernelRows_nonempty {prog : LLVM.Program} {fn : LLVM.Func} {l : Layout}
    {ft : LLVM.FloatTy} {w : Nat} (hw : l.stored (.fp ft) = w) (bits : Nat)
    {S : ∀ σ : ℕ × ℕ, (Fin σ.1 × Fin σ.2 ⊕ Fin σ.2 → Model ft.fmt) → Set MatSetup} {m K : Nat}
    {W : Fin m × Fin K ⊕ Fin K → Model ft.fmt} {s : MatSetup} (hs : s ∈ S (m, K) W)
    (hf : s.Fits prog fn l ft w m K W) {ch : Nat → Nat} {ω : Nat → Nat → Nat}
    (ha : s.adm ch ω) :
    ∃ W', W' ∈ kernelRows prog fn l ft w bits S (m, K) (matVecEnc ft.fmt bits (m, K)) W := by
  obtain ⟨hL, hz, hX, hY, hsC, hb, c, o, sA, sB, hA, hB, A, B, -, h⟩ := hf
  obtain ⟨Bk, hO, -⟩ := h.exists_obs ha
  obtain ⟨V, hV, -⟩ := mat_holds hL hz hX hY hw bits hsC h hb ha hO
  exact ⟨V, rfl, s, hs, ch, ω, Bk, ha, hO, hV⟩

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

/-- **The behaviors of strided lanes added along a tree, per row**, for every binary interchange
format `fmt`, width `bits`, lane count `W`, tree `t` of lane numbers, flag `c` and size `(m, n)`:
at the encoding `matVecEnc fmt bits`, the output words `O` such that, for some oracle sequences
`o i j` of each row `i` and lane `j`, `O i` is `MojoProof.Sem.treeDot t c (o i)` over the lanes'
lists `stride W j` of the pairs `(I (i, k), I k)`, `k < n`, of row `i` and the vector; at another
encoding, none. `rowLoops` is its instance at one lane. -/
noncomputable def rowTrees (fmt : FloatFormat) (bits W : Nat)
    (t : FloatLib.Numerics.ReductionTree Nat) (c : Bool) (σ : ℕ × ℕ) (E : MatVecEncs σ)
    (I : E.inp.Words) : Set E.out.Words :=
  {O | ∃ h : E = matVecEnc fmt bits σ, ∃ o : Fin σ.1 → Nat → Nat → Nat × Nat, ∀ i,
    (h ▸ O : (matVecEnc fmt bits σ).out.Words) i = treeDot t c (o i) fun j => stride W j
      (List.ofFn fun k => ((h ▸ I : (matVecEnc fmt bits σ).inp.Words) (.inl (i, k)),
        (h ▸ I : (matVecEnc fmt bits σ).inp.Words) (.inr k)))}

/-- **Strided lanes added along a tree per row meet the matrix-vector spec graded by lanes.** For
every IEEE format `fmt`, width `bits`, lane count `W`, tree `t` whose leaves are the lanes
`0, …, W - 1`, each once, and flag `c`, the behaviors `rowTrees fmt bits W t c` meet
`GPUProof.Spec.matVec (GPUProof.laneVecGrade W t.depth fun n => ⌈n / W⌉)` at the encoding
`matVecEnc fmt bits` (`GPUProof.MeetsAt`), at every size, input words, oracle sequences and input
grades (`holds_of`, `stride_approx`). Every lane of a butterfly adds along such a tree
(`bfly_approx`), so `groupDot k` per row is a behavior at lane 0's tree (`groupDot_holds`;
instances:
`MojoProofTest.TileLanes.rows_2x7`, 3 lanes along `(0 + 1) + 2` at size 2 × 7, and
`MojoProofTest.TileLanes.rows_3x10`, `groupDot 2` at size 3 × 10). -/
theorem rowTrees_meetsAt {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat) {W : Nat}
    {t : FloatLib.Numerics.ReductionTree Nat} (ht : t.leaves.Perm (List.range W)) (c : Bool) :
    GPUProof.MeetsAt
      (GPUProof.Spec.matVec (GPUProof.laneVecGrade W t.depth fun n => (n + W - 1) / W)
        (GPUProof.laneVecGrade_mono _ _ _))
      (rowTrees fmt bits W t c) (matVecEnc fmt bits) := by
  rintro σ I O ⟨_, o, hO⟩
  refine holds_of bits W t.depth _ fun i a x ga gx ha hx => ?_
  have e : O i = treeDot t c (o i) fun j => stride W j
      (List.ofFn fun k => (I (.inl (i, k)), I (.inr k))) := hO i
  rw [e]
  exact stride_approx hfmt c (o i) t ht (fun k => I (.inl (i, k))) (fun k => I (.inr k)) a x ga
    gx ha hx

/-- **A lane group per row meets the matrix-vector spec's rule**: for every IEEE format `fmt`,
width `bits`, number of rounds `k`, flag `c`, size `(m, n)`, oracle sequences `o i` of each row
and input words `I` at `matVecEnc fmt bits`, the words `groupDot k c (o i)` over the pairs
`(I (i, j), I j)` of row `i` and the vector meet the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`. This is the case of
`rowTrees_meetsAt` at `2 ^ k` lanes and lane 0's butterfly tree `bflyTree (bflyOffsets k) 0`:
the words are a behavior of `rowTrees` there (`eval_bflyTree`), the tree's leaves are the lanes
(`leaves_offsets k 0`), and its depth is `k` (`depth_bflyTree`). The depth is a rewrite, not a
definitional step, since the length of `bflyOffsets k` is `k` only by a lemma at symbolic `k`. -/
theorem groupDot_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits k : Nat) (c : Bool)
    {σ : ℕ × ℕ} (o : Fin σ.1 → Nat → Nat → Nat × Nat) (I : (matVecEnc fmt bits σ).inp.Words) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => (n + 2 ^ k - 1) / 2 ^ k)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds σ (matVecEnc fmt bits σ) I
      fun i => groupDot k c (o i) (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))) := by
  have h := rowTrees_meetsAt hfmt bits (leaves_offsets k 0 (Nat.two_pow_pos k)) c σ I
    (fun i => groupDot k c (o i) (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))))
    ⟨rfl, o, fun _ => (eval_bflyTree _ _ _ 0).symm⟩
  rwa [depth_bflyTree, show (bflyOffsets k).length = k by simp [bflyOffsets]] at h

/-- **The semantics' butterfly per row meets the matrix-vector spec's rule**: for every IEEE
format `fmt`, width `bits`, number of rounds `k`, flag `c`, size `(m, n)`, oracle sequences
`o i l` of each row's lane loops, oracle numbers `ob i r l` of each row's `fadd` in round `r` at
lane `l`, and input words `I` at `matVecEnc fmt bits`, the words of lane 0 after the `k` rounds of
the semantics' `fadd`, `deliver (Model.add x y) (ob i r l)` (`bflyRoundsAt`), from lane `l`'s
`dotLoop c (o i l)` from `+0` over `stride (2 ^ k) l` of the pairs `(I (i, j), I j)` of row `i`
and the vector, meet the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`. Each word is
`groupDot k c (o i)` of the row's pairs or both are NaNs (`bflyDeliver_nanEq`), so the two decode
alike (`GPUProof.ScalarEnc.decode_eq`), and `groupDot_approx` gives the grade (`holds_of`). This
is the spec side of a kernel whose lane `l` of row `i` folds the pairs at `2 ^ k j + l`
(`dotLoop_take_stride`) and whose lane 0 stores the rounds' word: gemv_kernel at `k = 5`. That a
run of the kernel stores that word is not proved here. -/
theorem bflyDeliver_holds {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits k : Nat)
    (c : Bool) {σ : ℕ × ℕ} (o : Fin σ.1 → Nat → Nat → Nat × Nat) (ob : Fin σ.1 → Nat → Nat → Nat)
    (I : (matVecEnc fmt bits σ).inp.Words) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ k) k fun n => (n + 2 ^ k - 1) / 2 ^ k)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds σ (matVecEnc fmt bits σ) I
      fun i => bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob i r l)) (bflyOffsets k)
        (fun l => dotLoop c (o i l) (Model.zero fmt false)
          (stride (2 ^ k) l (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))))) 0 :=
  holds_of bits (2 ^ k) k _ fun i a x ga gx ha hx =>
    (congrArg (fun v => GPUProof.Approx .real
      (GPUProof.laneGrade (.ieee fmt) (2 ^ k) k ((σ.2 + 2 ^ k - 1) / 2 ^ k) σ.2 a x ga gx)
      (.ieee fmt) v (∑ j, a j * x j))
      (GPUProof.ScalarEnc.decode_eq (e := GPUProof.ScalarEnc.ieee fmt)
        (bflyDeliver_nanEq (ob i) (bflyOffsets k) _ 0))).mpr
      (groupDot_approx hfmt k c (o i) _ _ a x ga gx ha hx)

/-- **The last of the first `r + 1` rounds**: for every carrier `β`, combination `F r l` per round
`r` and lane `l`, offsets `ms`, round `r < ms.length`, values `v` and lane `l`, lane `l`'s value
after the first `r + 1` rounds (`bflyRoundsAt F` at `ms.take (r + 1)`) is `F r l` of its own value
after the first `r` rounds and the value then of `l ^^^ ms[r]`, its partner in round `r`. The
recursion of `bflyRoundsAt` applies the first offset first and shifts the round index; this
unfolds the rounds from the last. By induction on `ms`. -/
theorem bflyRoundsAt_take_succ {β : Type} :
    ∀ (F : Nat → Nat → β → β → β) (ms : List Nat) (r : Nat) (hr : r < ms.length) (v : Nat → β)
      (l : Nat), bflyRoundsAt F (ms.take (r + 1)) v l =
        F r l (bflyRoundsAt F (ms.take r) v l) (bflyRoundsAt F (ms.take r) v (l ^^^ ms[r]))
  | _, [], _, hr, _, _ => absurd hr (Nat.not_lt_zero _)
  | _, _ :: _, 0, _, _, _ => rfl
  | F, _ :: ms, r + 1, hr, _, l =>
    bflyRoundsAt_take_succ (fun r => F (r + 1)) ms r (Nat.lt_of_succ_lt_succ hr) _ l

/-- **Lanes that combine with their partners' values are the butterfly rounds**: for every type
`β`, round function `F r l` per round `r` and lane `l`, offsets `ms`, set of lanes `S` that holds
every round's partner of each of its lanes (`l ^^^ ms[r]` for `r < ms.length`), and values
`X r l` of lane `l` after round `r`: if after each round `r < ms.length` every lane `l` of `S` holds
`F r l` of its own value then and its partner's, `X (r + 1) l = F r l (X r l) (X r (l ^^^ ms[r]))`,
then after `r ≤ ms.length` rounds every lane `l` of `S` holds its value after the first `r` rounds
from the start values `X 0`, `bflyRoundsAt F (ms.take r) (X 0) l`. The lanes' values close over
`S` at once: each round reads the partner's value of the round before, which the induction gives
at every lane of `S`. At `S` every lane, no closure is asked; at the lanes below `2 ^ n` it holds
when every offset is below `2 ^ n` (`Nat.xor_lt_two_pow`). By induction on `r` and
`bflyRoundsAt_take_succ`. -/
theorem bflyRoundsAt_chain {β : Type} (F : Nat → Nat → β → β → β) (ms : List Nat)
    (S : Nat → Prop) (hS : ∀ r (hr : r < ms.length) l, S l → S (l ^^^ ms[r]))
    (X : Nat → Nat → β)
    (hX : ∀ r (hr : r < ms.length) l, S l → X (r + 1) l = F r l (X r l) (X r (l ^^^ ms[r]))) :
    ∀ r ≤ ms.length, ∀ l, S l → X r l = bflyRoundsAt F (ms.take r) (X 0) l := by
  intro r
  induction r with
  | zero => intro _ _ _; rfl
  | succ r ih =>
    intro hr l hl
    have hr' : r < ms.length := hr
    rw [hX r hr' l hl, bflyRoundsAt_take_succ F ms r hr', ih hr'.le l hl,
      ih hr'.le _ (hS r hr' l hl)]

/-- **One lane takes every pair**: for every list `xs`, the strided list with stride 1 and offset
0 is `xs`. -/
theorem stride_one {α : Type} (xs : List α) : stride 1 0 xs = xs := by
  simp [stride, Nat.mod_one, List.zipIdx_map_fst]

/-- **The behaviors of a dot loop per row**, for every binary interchange format `fmt`, width
`bits` and flag `c`: `rowTrees` at one lane and the tree `.leaf 0`. At every size `(m, n)` and at
the encoding `matVecEnc fmt bits`, output `i` is the one lane's `dotLoop c` from `+0` at some
oracle sequence over its strided list, by `MojoProof.Sem.treeDot`'s definition at a leaf, and
that list is the pairs of row `i` and the vector (`stride_one`); every such loop per row is a
behavior (`rowLoops_dotLoop`, the direction stated as a theorem). At another encoding there are
none. -/
noncomputable abbrev rowLoops (fmt : FloatFormat) (bits : Nat) (c : Bool) :
    (σ : ℕ × ℕ) → (E : MatVecEncs σ) → E.inp.Words → Set E.out.Words :=
  rowTrees fmt bits 1 (.leaf 0) c

/-- **A dot loop per row is a behavior of `rowLoops`**: for every binary interchange format
`fmt`, width `bits`, flag `c`, size `(m, n)`, oracle sequences `o i` of each row and input words
`I` at `matVecEnc fmt bits`, the words `dotLoop c (o i)` from `+0` over the pairs
`(I (i, k), I k)`, `k < n`, of row `i` and the vector (`stride_one`). -/
theorem rowLoops_dotLoop (fmt : FloatFormat) (bits : Nat) (c : Bool) {σ : ℕ × ℕ}
    (o : Fin σ.1 → Nat → Nat × Nat) (I : (matVecEnc fmt bits σ).inp.Words) :
    (fun i => dotLoop c (o i) (Model.zero fmt false)
      (List.ofFn fun k => (I (.inl (i, k)), I (.inr k)))) ∈
      rowLoops fmt bits c σ (matVecEnc fmt bits σ) I :=
  ⟨rfl, fun i _ => o i, fun _ => (congrArg _ (stride_one _)).symm⟩

/-- **Equal grades, one spec**: for every two equal grades `g = g'` of the matrix-vector spec,
behaviors `k` and encodings `E`, if `k` meets `GPUProof.Spec.matVec g` at `E`
(`GPUProof.MeetsAt`), it meets `GPUProof.Spec.matVec g'` at `E`. A rewrite of the grade inside
`GPUProof.MeetsAt` is not type correct, since the spec's monotonicity proof and the behaviors'
type depend on it; this lemma substitutes it instead. -/
theorem meetsAt_grade
    {g g' : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1}
    (h : g = g') {hg : ∀ σ E A, Monotone (g σ E A)} {hg' : ∀ σ E A, Monotone (g' σ E A)}
    {k : (σ : ℕ × ℕ) → (E : MatVecEncs σ) → E.inp.Words → Set E.out.Words}
    {E : (σ : ℕ × ℕ) → MatVecEncs σ} (hk : GPUProof.MeetsAt (GPUProof.Spec.matVec g hg) k E) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec g' hg') k E := by
  subst h
  exact hk

/-- **A dot loop per row meets the matrix-vector spec.** For every IEEE format `fmt`, width
`bits` and flag `c`, the behaviors `rowLoops fmt bits c` meet
`GPUProof.Spec.matVec GPUProof.matVecGrade` at the encoding `matVecEnc fmt bits`
(`GPUProof.MeetsAt`), at every size, input words, oracle sequences and input grades: the case of
`rowTrees_meetsAt` at one lane and the tree `.leaf 0`, through `meetsAt_grade`. Its grade there,
`GPUProof.laneVecGrade` at one lane, the depth of `.leaf 0` and lane length `⌈n / 1⌉`, that is
`(n + 1 - 1) / 1`, is `GPUProof.matVecGrade`, the one at depth 0 and lane length `n`: the two
differ by definition and are equal by `n + 1 - 1 = n` and `n / 1 = n`. -/
theorem rowLoops_meetsAt {fmt : FloatFormat} (hfmt : fmt.isIEEE = true) (bits : Nat) (c : Bool) :
    GPUProof.MeetsAt (GPUProof.Spec.matVec GPUProof.matVecGrade GPUProof.matVecGrade_mono)
      (rowLoops fmt bits c) (matVecEnc fmt bits) :=
  meetsAt_grade (by simp only [Nat.add_sub_cancel, Nat.div_one]; rfl)
    (rowTrees_meetsAt hfmt bits (List.Perm.refl _) c)

end MojoProof.Tile
