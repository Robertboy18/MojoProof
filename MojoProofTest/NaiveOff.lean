import MojoProofTest.NaiveKernel
import MojoProofTest.SymInfo
import MojoProof.Sem.ContractOff

/-!
# The naive matmul kernel compiled with contraction off

For the one program `16826c8c` of the corpus directory mgemm_nocontract (imported in
MojoProofTest/SymInfo.lean), the naive matmul kernel of MojoProofTest/SymPhi.lean (`naive`)
compiled with contraction off:

* `module_eq`, `fn_eq`, `layout_eq`, `intrinsics_eq`: by evaluation in the kernel, its module is
  `naive`'s with the `contract` flags removed (`Module.contractOff`), its kernel is
  `naive.fn_0.contractOff`, and its layout and intrinsics are `naive`'s (its digest differs).
* `naive_fbinOracle`, `fn_fbinOracle`: `naive` and its kernel are of the fragment of
  `Kernel.Sound.contractOff` (`Program.fbinOracle`, `Func.fbinOracle`), by evaluation.
* `correct`: `Kernel.Sound` of the corpus kernel for `Elem.Out` of the unfused bytes: every cell
  in bounds gets the binary32 encoding of `dotLoop false` over its pairs at its oracle numbers
  `o (ω k)`, for every oracle family `ω`, launch valid with `z` sides 1, sizes, blocks, tensors and
  memory that meets `Mat.Pre`, the premises of `NaiveKernel.correct`. It is
  `NaiveKernel.correct` at the rows `neverFuse (ω k)`, moved by `Kernel.Sound.contractOff`, with
  `dotLoop_neverFuse` for the bytes.
* `obs_contractOff`: for every program of the fragment, every observation of a complete run of
  the kernel with contraction off under `ω` is one of the kernel under the rows `neverFuse (ω n)`.
* `matmul_nanEq`, `matmul_error`: the comparison with TorchLean, for every oracle family `ω` and
  `K ≤ 768`. Every cell in bounds and in the launch's window is `NaNEq` to entry `(r, c)` of
  `Tensor.matmul` of the first `K` columns, and when finite within `dotBound` of the real product,
  with no premise on the oracle: `NaiveSound.naive_matmul` at the run of `naive` that
  `obs_contractOff` gives, whose `fadd` numbers fuse no round.
* `bf16_fbinOracle`: the twin of the fragment premise. The bfloat16 naive kernel of the corpus
  (`ba3789d9`) widens its words with `fpext`, whose result reads the whole oracle number, and is
  not of the fragment.
-/

namespace MojoProofTest.NaiveOff

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread MojoProofTest.NaiveSpec MojoProofTest.SymInfo.mgemm_nocontract
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- The corpus module of the naive kernel compiled with contraction off is `naive`'s module with
the `contract` flags removed, by evaluation in the kernel. -/
theorem module_eq :
    g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog.module =
      naive.prog.module.contractOff := rfl

/-- Its kernel is `naive`'s kernel with the `contract` flags removed, by evaluation. -/
theorem fn_eq :
    g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.fn_0 =
      naive.fn_0.contractOff := rfl

/-- Its layout is `naive`'s. -/
theorem layout_eq :
    g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog.layout =
      naive.prog.layout := rfl

/-- Its intrinsics are `naive`'s. -/
theorem intrinsics_eq :
    g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog.intrinsics =
      naive.prog.intrinsics := rfl

/-- `naive` is of the fragment `Program.fbinOracle`: no `fpext` or `fptrunc` in any function and
no `maxnum`, `minnum` or `rsqrt.approx` intrinsic, by evaluation. -/
theorem naive_fbinOracle : naive.prog.fbinOracle = true := by decide +kernel

/-- `naive`'s kernel has no `fpext` or `fptrunc` (`Func.fbinOracle`), by evaluation. -/
theorem fn_fbinOracle : naive.fn_0.fbinOracle = true := by decide +kernel

/-- **The naive matmul kernel with contraction off.** For every oracle family `ω`, launch valid
with `z` sides 1, sizes, blocks, tensors and memory that meets `Mat.Pre` as in
`NaiveKernel.correct`: the corpus kernel compiled with contraction off is sound for `Elem.Out`
of the bytes that put at every cell in bounds (`S`) the binary32 encoding of `dotLoop false`
(no fusion) from `+0` over its pairs at its oracle numbers `o (ω k)`, and nothing at the others.
Its scope is one program, every launch and memory of `Mat.Pre`. -/
theorem correct {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {m n K bC bA bB : Nat}
    {A : Tensor (Model FloatTy.float.fmt) [m, 768]} {B : Tensor (Model FloatTy.float.fmt) [n, 768]}
    {mem : Mem} (h : Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA bB
      m n K 768 768 50257 A B) :
    Kernel.Sound
      g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog
      g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.fn_0
      L (Mat.args z bC bA bB m n K) mem (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out mem bC (cell L) (fun k => if hk : S L m n k then
          naive.prog.layout.encode (.fp .float) (.ofFloat .float
            (dotLoop false (o (ω k)) (Model.zero _ false) (pairs A B ⟨_, hk.2.1⟩ ⟨_, hk.2.2⟩ K)))
        else none) (volume L.grid * volume L.block)) := by
  have hb : bytes (fun k => neverFuse (ω k)) L K A B = fun k => if hk : S L m n k then
      naive.prog.layout.encode (.fp .float) (.ofFloat .float
        (dotLoop false (o (ω k)) (Model.zero _ false) (pairs A B ⟨_, hk.2.1⟩ ⟨_, hk.2.2⟩ K)))
      else none := by
    funext k
    unfold bytes
    by_cases hk : S L m n k
    · rw [dite_eq_left hk, dite_eq_left hk]
      exact congrArg (fun x => naive.prog.layout.encode (.fp .float) (.ofFloat .float x))
        (dotLoop_neverFuse (o (ω k)) _ _)
    · rw [dite_eq_right hk, dite_eq_right hk]
  have H := Kernel.Sound.contractOff module_eq layout_eq intrinsics_eq naive_fbinOracle
    fn_fbinOracle (NaiveKernel.correct (ω := fun k => neverFuse (ω k)) hL hz h)
  rw [hb] at H
  rw [fn_eq]
  intro ch ω' hω
  exact H ch ω' (by rw [hω])

/-- **A run of the kernel with contraction off is a run of the kernel.** For every program `P` of
the fragment (`Program.fbinOracle`), program `Q` with the module of `P.contractOff`, the layout
and the intrinsics of `P`, kernel `fn` with no `fpext` or `fptrunc` (`Func.fbinOracle`), launch,
arguments, memory, observation, address choice `ch` and oracle family `ω`: every observation of
a complete run of `fn.contractOff` in `Q` under `ω` (`Kernel.Obs`) is one of a complete run of
`fn` in `P` under the rows `neverFuse (ω n)`. The starts are related by `Grid.start_contractOff`,
and `Grid.lockstep_contractOff`, flipped, takes the run of `Q` to one of `P` whose grid is mapped
to the grid of `Q`, with the same memory. -/
theorem obs_contractOff {P Q : Program} (hQ : Q.module = P.module.contractOff)
    (hl : Q.layout = P.layout) (hi : Q.intrinsics = P.intrinsics) (hP : P.fbinOracle = true)
    {fn : Func} (hfn : fn.fbinOracle = true) {L : Launch} {args : List Val} {m : Mem}
    {β : Type} {obs : Mem → Option β} {ch : Nat → Nat} {ω : Nat → Nat → Nat} {y : β}
    (h : Kernel.Obs Q fn.contractOff L args m obs ch ω y) :
    Kernel.Obs P fn L args m obs ch (fun n => neverFuse (ω n)) y := by
  obtain ⟨g₂, c₂, z₂, hs₂, hr, hd, ho⟩ := h
  have hR := Grid.start_contractOff hQ hl fn L args m ch ω
  rw [hs₂] at hR
  cases hs : Grid.start P fn L args m ch (fun n => neverFuse (ω n)) with
  | error e =>
    rw [hs] at hR
    cases hR
  | ok r =>
    rw [hs] at hR
    obtain ⟨g, c⟩ := r
    cases hR with
    | ok hR =>
    obtain ⟨rfl, hc⟩ := hR
    have hC : CtxOff P Q ω c c₂ :=
      { prog := fun n => (Grid.start_ctx hs n).1
        ctx := hc
        oracle := fun n => (Grid.start_ctx hs n).2.2.2
        module := hQ
        layout := hl
        intrinsics := hi
        frag := hP }
    have hg : g.FbinOracle ∧ g.contractOff = g.contractOff := ⟨Grid.start_fbinOracle hs hfn, rfl⟩
    obtain ⟨z₁, hr₁, -, rfl⟩ := (Grid.lockstep_contractOff hC L).symm.reach hg hr
    exact ⟨g, c, z₁, hs, hr₁, (Grid.done_contractOff z₁).1 hd, ho⟩

section Matmul

variable {ω : Nat → Nat → Nat} {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
  {m n K bC bA bB : Nat} {A : Tensor (Model FloatTy.float.fmt) [m, 768]}
  {B : Tensor (Model FloatTy.float.fmt) [n, 768]} {mem : Mem}
  (h : Mat.Pre naive.prog.layout (.fp .float) (Val.ofFloat .float) 4 z mem bC bA bB m n K 768 768
    50257 A B)
  {ch : Nat → Nat} {Bk : Nat → Option Sem.Block}
  (hB : Kernel.Obs g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog
    g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.fn_0 L
    (Mat.args z bC bA bB m n K) mem (fun m => some m.blocks) ch ω Bk)
include hL hz h hB

/-- **The cells of the kernel with contraction off against TorchLean's product, up to NaNs.** For
every oracle family `ω`, launch `L` valid with `z` sides 1, sizes, `K ≤ 768`, blocks, tensors and
memory of `Mat.Pre`: in every observation `Bk` of a complete run of the corpus kernel compiled
with contraction off at every address choice under `ω`, block `bC` is some `y` and every cell
`(r, c)` with `r < m`, `c < n` and in the launch's window (`r < grid.x * block.x`,
`c < grid.y * block.y`) is computed by one thread `k` and holds the binary32 encoding of a word
`v` that is entry `(r, c)` of TorchLean's `Tensor.matmul` of the first `K` columns of `A` and the
transpose of the first `K` columns of `B` (`cols`), or a NaN where that entry is a NaN (`NaNEq`).
No premise on the oracle: the run is one of `naive` under the rows `neverFuse (ω k)`
(`obs_contractOff`), whose `fadd` numbers are multiples of 3 and fuse no round, so
`NaiveSound.naive_matmul` at `NaiveKernel.correct` applies with its premise met. Its scope is one
program (the float32 naive kernel compiled with contraction off), every launch and memory of
`Mat.Pre`, every oracle family. -/
theorem matmul_nanEq (hK : K ≤ 768) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 50257 + c) * 4) 4) ∧
        NaNEq v (Tensor.get2 (Tensor.matmul (cols K hK A)
          (Tensor.permute (cols K hK B) (Shape.adjacentSwap [n, K] 0) [K, n])) ⟨r, hr⟩
            ⟨c, hc⟩) := by
  rw [fn_eq] at hB
  obtain ⟨y, hy, hc⟩ := NaiveSound.naive_matmul hL hz h.le.1 hK
    (NaiveKernel.correct (ω := fun k => neverFuse (ω k)) hL hz h) h.bufs.2.2.choose_spec.1
    (obs_contractOff module_eq layout_eq intrinsics_eq naive_fbinOracle fn_fbinOracle hB)
  refine ⟨y, hy, fun r c hr hc' hX hY => ?_⟩
  obtain ⟨k, hk, ex, ey, v, he, hu, -⟩ := hc r c hr hc' hX hY
  exact ⟨k, hk, ex, ey, v, he, hu fun j => by simp only [o, neverFuse]; omega⟩

/-- **The finite cells of the kernel with contraction off are within `dotBound` of the real
product.** For every oracle family `ω`, launch `L` valid with `z` sides 1, sizes, `K ≤ 768`,
blocks, tensors and memory of `Mat.Pre`: in every observation `Bk` of a complete run of the
corpus kernel compiled with contraction off at every address choice under `ω`, block `bC` is some
`y` and every cell `(r, c)` with `r < m`, `c < n` and in the launch's window is computed by one
thread `k` and holds the binary32 encoding of a word `v`; when `v` is finite, `|v - (A Bᵀ)ᵣ꜀|`
over the reals on the first `K` columns (`cols`, mapped by `Model.toReal`) is at most `dotBound`
of binary32 at `K` and `Σⱼ<K |aᵣⱼ b꜀ⱼ|` (`NaiveSound.naive_matmul` at the run of `naive` that
`obs_contractOff` gives). Its scope is one program (the float32 naive kernel compiled with
contraction off), every launch and memory of `Mat.Pre`, every oracle family. -/
theorem matmul_error (hK : K ≤ 768) :
    ∃ y, Bk bC = some y ∧ ∀ r c (hr : r < m) (hc : c < n), r < L.grid .x * L.block .x →
      c < L.grid .y * L.block .y →
      ∃ k < volume L.grid * volume L.block, L.index k .x = r ∧ L.index k .y = c ∧
        ∃ v, naive.prog.layout.encode (.fp .float) (.ofFloat .float v) =
          some (y.read ((r * 50257 + c) * 4) 4) ∧
        (v.isFinite = true → |v.toReal - Tensor.get2 (Tensor.matmul
          (Tensor.map Model.toReal (cols K hK A)) (Tensor.map Model.toReal
            (Tensor.permute (cols K hK B) (Shape.adjacentSwap [n, K] 0) [K, n])))
              ⟨r, hr⟩ ⟨c, hc⟩| ≤ dotBound FloatTy.float.fmt K ((pairs A B ⟨r, hr⟩ ⟨c, hc⟩
                K).map fun ab => |ab.1.toReal * ab.2.toReal|).sum) := by
  rw [fn_eq] at hB
  obtain ⟨y, hy, hc⟩ := NaiveSound.naive_matmul hL hz h.le.1 hK
    (NaiveKernel.correct (ω := fun k => neverFuse (ω k)) hL hz h) h.bufs.2.2.choose_spec.1
    (obs_contractOff module_eq layout_eq intrinsics_eq naive_fbinOracle fn_fbinOracle hB)
  refine ⟨y, hy, fun r c hr hc' hX hY => ?_⟩
  obtain ⟨k, hk, ex, ey, v, he, -, hf⟩ := hc r c hr hc' hX hY
  exact ⟨k, hk, ex, ey, v, he, hf⟩

end Matmul

mojo_import "mgemm/g_matmul_kernel_naive_bfloat16_bfloat16_bfloat16_True_16_ba3789d9.nvptx.ll"
  as bf16

/-- **The twin of the fragment premise.** The bfloat16 naive kernel of the corpus is not of the
fragment `Program.fbinOracle`: it has an `fpext`, by evaluation. -/
theorem bf16_fbinOracle : bf16.prog.fbinOracle = false := by decide +kernel

end MojoProofTest.NaiveOff
