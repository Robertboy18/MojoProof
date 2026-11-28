import MojoProofTest.GevmWarp1
import MojoProofTest.GevmTrace
import MojoProofTest.GevmSpec
import MojoProofTest.GemvThread
import MojoProof.Sym.SigKernel

/-!
# gevm_kernel is sound against the vector-matrix spec, through Theorem 0

MojoProofTest/GevmWarp1.lean's `grid` runs gevm_kernel (`gevm`, gevm_kernel float32 `1308aaae`,
tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll) from its
start to a done grid whose output columns are their `warpDot`s up to NaNs (`GevmWarp1.ColsDot`),
and gives every access of that grid's trace with its phase (`GevmWarp1.Acc`). This file adds
that such a trace makes the done grid not bad, then the kernel's soundness by Theorem 0:

* `grid_bad`: the done grid is not bad (`Grid.Done.bad_iff`). No race: `racy_cells` at cell map
  `tpose 32` and cell width 4 (each thread writes its cell `32 laneid + tid.x / 32` of its block's
  shared array before the barrier, IR line 78, and only reads after it, line 80) and the output's
  tiling `GevmTrace.warpTiles` (lane 0 of warp `k / 32` writes the 4 bytes at `4 (k / 32)`, line
  115); the promise of `!invariant.load` kept (`kept_of_split`): the invariant loads read the
  vector and the matrix, which no access writes;
* `starts`: gevm_kernel's launch starts on a memory closed for its arguments
  (`Grid.start_of_check`, its check by `kernel_rfl`), with a twin whose check fails;
* `kernel_sound`: gevm_kernel is sound at `sig` (`GPUProof.Kernel.Sound`) against
  `GPUProof.Spec.vecMat` (`GevmSpec.ColsRule`) for the admission "every block of threads' shared
  array fits below `2 ^ 32`": `grid`, `grid_bad`, `GevmSpec.cols_holds` and Theorem 0 at `sig`
  (`kernel_sound_sig`); `gevm_torchLean`: the same against TorchLean's `.vecMat`
  (`GevmSpec.TorchCols`, by `GevmSpec.torchCols_of_rule`);
* `mem_closed`: the memory `GemvThread.mem B A` (gemv_kernel's caller memory at `M = K = 32`) is
  closed for gevm_kernel's arguments;
* `sound1024`, `torch1024`: the two with every premise proved, at one block of 1024 threads,
  `N = K = 32` and the memory `GemvThread.mem` at every matrix and vector; no run is evaluated.

Tests of one program, gevm_kernel float32 `1308aaae`.
-/

namespace MojoProofTest.GevmSound

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GevmWarp1 MojoProofTest.GevmTrace MojoProofTest.GevmSpec
open FloatLib.Floats.Formats.BinaryInterchange

/-- **gevm_kernel's done grid is not bad** (test): gevm_kernel (the corpus file), for every start
(`Grid.start`) on a valid launch `L` with 1024 threads per block in `x` and a one-dimensional
grid, giving grid `g₀` and contexts `c`, every `N = 32 · L.grid .x`, memory `m` with a writable
buffer `p0` and read-only buffers `bA` and `bB` (`Mem.Buffer`), shared arrays `sb g` of the blocks
of threads `g` of the grid (`g₀.mem.ctaOf`) and done grid `z` reachable from `g₀` every access of
whose trace is one of `GevmWarp1.Acc` at its phase (`GevmWarp1.grid`'s last conjunct): `z` is not
bad at `sig`. An instance of `Grid.not_bad_cells` (MojoProof/Sym/SigKernel.lean): cell map
`tpose 32`, injective on `[0, 1024)` by `tpose_tpose`, cell width 4, the output's tiling
`GevmTrace.warpTiles p0 N`, and the promise kept because the invariant accesses read `bA` or `bB`
and the writes are to a shared array or `p0`. The blocks' owners at `z` are their owners at `g₀`:
`p0`, `bA` and `bB` are no block of threads' (`Grid.start_reach_buffer`), `sb g` is `g`'s
(`Grid.start_reach_ctaOf`), and `bA`, `bB` are not `p0` (`Mem.Buffer.ne`). -/
theorem grid_bad {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start gevm.prog gevm.fn_0 L args m ch oracle = .ok (g₀, c)) (hL : L.Valid)
    (hx : L.block .x = 1024) (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    {N p0 bA bB sA sB : Nat} (hNg : N = 32 * L.grid .x) (hb0 : m.Buffer p0 (N * 4) 4 true)
    (hbA : m.Buffer bA sA 4 false) (hbB : m.Buffer bB sB 4 false) {z : Grid}
    (hz : Relation.ReflTransGen (Grid.Step L c) g₀ z) (hd : GPUProof.Done sig (z, L, c))
    {sb : Nat → Nat} (hsb : ∀ g < L.grid .x, g₀.mem.ctaOf (sb g) = some g)
    (hP : ∀ x ∈ (phases z.mem.trace).1, Acc L c sb bA bB p0 x.2 x.1) :
    ¬ GPUProof.Bad sig (z, L, c) := by
  have hv1 : volume L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hvg : volume L.grid = L.grid .x := by simp only [volume, hgy, hgz, Nat.mul_one]
  have hwho : ∀ n, (c n).who = ⟨n, n / volume L.block⟩ := fun n => (Grid.start_ctx h n).2.1
  have hall : ∀ {q s : Nat} {w : Bool}, m.Buffer q s 4 w → z.mem.ctaOf q = none :=
    Grid.start_reach_buffer h hz
  have hcta : ∀ g < L.grid .x, z.mem.ctaOf (sb g) = some g := fun g hg =>
    Grid.start_reach_ctaOf h hz (hsb g hg)
  have hne : ∀ {q s : Nat}, m.Buffer q s 4 false → q ≠ p0 := fun hq => Mem.Buffer.ne hq hb0
  have hsne : ∀ {q s : Nat} {w : Bool}, m.Buffer q s 4 w → ∀ g < L.grid .x, sb g ≠ q :=
    fun hq g hg e => by
      have := hall hq
      rw [← e, hcta g hg] at this
      cases this
  refine Grid.not_bad_cells h hz hd hL.volume_pos (w := 4) (cell := tpose 32)
    (G := warpTiles p0 N)
    (fun i hi j hj e => by
      rw [hv1] at hi hj
      rw [← tpose_tpose (n := 32) hi, e, tpose_tpose (n := 32) hj])
    (fun x hxt β e => by
      rcases hP x hxt with ⟨-, hq | hq⟩ | ⟨n, -, h0, ha⟩ | ⟨h0, hw, -⟩ | ⟨n, -, -, ha⟩
      · rw [hq, hall hbA] at e
        cases e
      · rw [hq, hall hbB] at e
        cases e
      · refine ⟨fun _ => ?_, fun h' => absurd h0 h'⟩
        obtain ⟨-, -, -, hc⟩ := Launch.tpose_env hL hx n
        rw [ha]
        simp only [hwho, hv1]
        omega
      · exact ⟨fun h' => absurd h' h0, fun _ => hw⟩
      · have hp : x.1.ptr.block = p0 := by rw [ha]
        rw [hp, hall hb0] at e
        cases e)
    (fun x hxt e => by
      rcases hP x hxt with ⟨hw, hq | hq⟩ | ⟨n, hn, -, ha⟩ | ⟨-, -, -, g, hg, hq⟩ |
          ⟨n, h32, hn, ha⟩
      · exact ⟨fun _ => hw, fun t ht => by simp [warpTiles, hq, hne hbA] at ht⟩
      · exact ⟨fun _ => hw, fun t ht => by simp [warpTiles, hq, hne hbB] at ht⟩
      · have hp : x.1.ptr.block = sb (n / 1024) := by rw [ha]
        rw [hp, hcta _ hn] at e
        cases e
      · rw [hq, hcta g hg] at e
        cases e
      · have ho := out_cell L hL hx hgy hgz n (by rw [hvg]; exact hn)
        rw [ha]
        refine ⟨fun h' => by simp [warpTiles] at h', fun t ht => ?_⟩
        rw [warpTiles, ite_eq_left_of_eq_true _ _ (eq_true rfl), Option.some.injEq] at ht
        subst ht
        simp only [warpTile, id, hwho]
        split_ifs <;> omega) ?_
  intro a e ha he hi hw hab
  obtain ⟨pa, hpa⟩ := phases_mem ha
  obtain ⟨pe, hpe⟩ := phases_mem he
  have hA : a.ptr.block = bA ∨ a.ptr.block = bB := by
    rcases hP _ hpa with ⟨-, hq⟩ | ⟨n, -, -, rfl⟩ | ⟨-, -, hi', -⟩ | ⟨n, -, -, rfl⟩
    · exact hq
    · simp at hi
    · rw [hi] at hi'
      cases hi'
    · simp at hi
  rcases hP _ hpe with ⟨hw', -⟩ | ⟨n, hn, -, rfl⟩ | ⟨-, hw', -, -⟩ | ⟨n, -, -, rfl⟩
  · rw [hw] at hw'
    cases hw'
  · rcases hA with hq | hq <;> rw [hab] at hq
    · exact hsne hbA _ hn hq
    · exact hsne hbB _ hn hq
  · rw [hw] at hw'
    cases hw'
  · rcases hA with hq | hq <;> rw [hab] at hq
    · exact hne hbA hq.symm
    · exact hne hbB hq.symm

/-- **gevm_kernel's launch starts** (test of gevm_kernel, the corpus file, for every launch of at
most 1024 threads a block, the kernel's `"nvvm.maxntid"="1024"`, argument values `p0`, `bA`,
`bB` (pointers at offset 0), a word `%3`, `N` and `K`, memory closed for them, address choice and
oracle): `Grid.start` gives a grid and contexts. An instance of `Grid.start_of_check`
(MojoProof/Sym/SigKernel.lean), its `startCheck` by `kernel_rfl` and its launch check by
`Func.checkLaunch_maxntid`. -/
theorem starts (L : Launch) {m : Mem} {p0 bA bB N K : Nat} {x3 : BitVec 32}
    (hL : volume L.block ≤ 1024)
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, .bits 32 x3,
      .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)]) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start gevm.prog gevm.fn_0 L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, .bits 32 x3,
      .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)] m ch oracle = .ok (g, c) :=
  Grid.start_of_check ch oracle hC
    (Func.checkLaunch_maxntid (v := "1024") (x := 1024) (y := 1) (z := 1) rfl (by kernel_rfl)
      (by kernel_rfl) (by kernel_rfl) (by kernel_rfl) (by simpa using hL)) (by kernel_rfl)

/-- Twin of `starts`' launch check: a block of 1025 threads is beyond gevm_kernel's
`"nvvm.maxntid"="1024"`, so the check fails. -/
example : (gevm.fn_0.checkLaunch gevm.prog.module (fun | .x => 1025 | _ => 1) 6).isOk =
    false := by kernel_rfl

/-- Twin of `starts`' check: with a poison output pointer the check fails (`Param.takes`: an
argument must be defined). -/
example : startCheck gevm.prog gevm.fn_0 [.poison, .ptr ⟨1, 0⟩, .ptr ⟨2, 0⟩, .bits 32 0,
    .bits 32 0, .bits 32 0] = false := by kernel_rfl

/-- **gevm_kernel is sound against the vector-matrix spec**: gevm_kernel (one program, the corpus
file gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll), for every valid
launch `L` with 1024 threads per block in `x` and a one-dimensional grid (`y` and `z` sizes 1),
`N = 32 · L.grid .x` columns, `K` with `32 ∣ K` (`N`, `K < 2 ^ 31`, `K N < 2 ^ 29`), argument
values `p0`, `bA`, `bB` (pointers at offset 0), a word `%3`, `N` and `K`, caller's memory `m`
closed for them (`Mem.Closed`) with a writable buffer `p0` of `N` words and read-only buffers `bA`
and `bB` of `K` and `K N` words that fit and hold the vector `A` and the matrix `B` row-major,
width `bits` and input words `I` that hold `A` and `B`: the kernel is sound at `sig`
(`GPUProof.Kernel.Sound`) for the admission "the address choice puts every block of threads'
shared array below `2 ^ 32`" (`ch (Nat.pair (β + 2) 2) · 4 mod 2 ^ 32 + 4096 ≤ 2 ^ 32`, the
array's 4096 bytes at its address in address space 3, whose pointers have 32 bits), the output
columns (`GevmSpec.colsObs`) and the rule of
`GPUProof.Spec.vecMat (GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉)` (`GevmSpec.ColsRule`).
An instance of `kernel_sound_sig` (MojoProof/Sym/SigKernel.lean, Theorem 0 at `sig` by
`GPUProof.Sound.of_one_run`): at each admitted choice the launch starts (`starts`),
`GevmWarp1.grid` gives a run to a done grid with its columns and its trace's accesses, `grid_bad`
that the grid is not bad, and `GevmSpec.cols_holds` the columns' relation. -/
theorem kernel_sound {L : Launch} {m : Mem} {N K p0 bA bB : Nat} {x3 : BitVec 32}
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, .bits 32 x3,
      .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : L.block .x = 1024) (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    (hNg : N = 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    (hb0 : m.Buffer p0 (N * 4) 4 true) (hf0 : m.Fits gevm.prog.layout p0 (N * 4))
    (hbA : m.Buffer bA (K * 4) 4 false) (hbB : m.Buffer bB (K * N * 4) 4 false)
    (hfA : m.Fits gevm.prog.layout bA (K * 4)) (hfB : m.Fits gevm.prog.layout bB (K * N * 4))
    (hA : m.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (hB : m.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B)
    (bits : Nat) (I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words)
    (hIA : ∀ i, I (.inl i) = A.getScalar i)
    (hIB : ∀ i j, I (.inr (i, j)) = TorchLean.Tensor.get2 B i j) :
    GPUProof.Kernel.Sound sig (gevm.prog, gevm.fn_0) L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩,
      .ptr ⟨bB, 0⟩, .bits 32 x3, .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)] m
      (fun ω => ∀ β < L.grid .x, ω.1 (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32)
      (fun b => colsObs L N p0 { blocks := b }) (ColsRule K bits I) := by
  refine kernel_sound_sig hC.bytesIn
    (fun m₁ m₂ hb => congrArg some (funext fun _ => Mem.load_of_block (congrFun hb _) _ _ _ _))
    (fun ω _ => starts L hL.threads hC ω.1 ω.2) fun ω g c hch hs => ?_
  obtain ⟨z, ⟨_, hp⟩, hd, hcols, sb, hsb, hP⟩ := grid hs hL hx hgy hgz rfl hN hK hK32 hKN hNg hb0
    hf0 hbA hbB hfA hfB hA hB hch
  have hz := GPUProof.Path.exists_iff.1 ⟨_, hp⟩
  exact ⟨z, hz, hd, grid_bad hs hL hx hgy hgz hNg hb0 hbA hbB hz hd hsb hP, _, rfl,
    cols_holds bits hIA hIB hcols⟩

/-- **gevm_kernel is sound against TorchLean's vector-matrix contraction**: gevm_kernel (one
program, the corpus file), for every launch, sizes, argument values, caller's memory, vector,
matrix, width and input words with `kernel_sound`'s premises, and every grade `g` of the
importer's `.matVec`: the kernel is sound at `sig` for the same admission and output columns and
`GevmSpec.TorchCols` (each column within the grade of
`GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉` of TorchLean's `.vecMat` of every real vector and
matrix the input words approximate). `kernel_sound`, each done state's columns by
`GevmSpec.torchCols_of_rule`. -/
theorem gevm_torchLean {L : Launch} {m : Mem} {N K p0 bA bB : Nat} {x3 : BitVec 32}
    (hC : m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, .bits 32 x3,
      .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : L.block .x = 1024) (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    (hNg : N = 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    (hb0 : m.Buffer p0 (N * 4) 4 true) (hf0 : m.Fits gevm.prog.layout p0 (N * 4))
    (hbA : m.Buffer bA (K * 4) 4 false) (hbB : m.Buffer bB (K * N * 4) 4 false)
    (hfA : m.Fits gevm.prog.layout bA (K * 4)) (hfB : m.Fits gevm.prog.layout bB (K * N * 4))
    (hA : m.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (hB : m.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B)
    (bits : Nat) (I : (MojoProof.Tile.vecMatEnc FloatTy.float.fmt bits (K, N)).inp.Words)
    (hIA : ∀ i, I (.inl i) = A.getScalar i)
    (hIB : ∀ i j, I (.inr (i, j)) = TorchLean.Tensor.get2 B i j)
    (g : GPUProof.RealGrades (fun σ : ℕ × ℕ => Fin σ.1 × Fin σ.2 ⊕ Fin σ.2) fun σ => Fin σ.1)
    (mono : ∀ σ E A, Monotone (g σ E A)) :
    GPUProof.Kernel.Sound sig (gevm.prog, gevm.fn_0) L [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩,
      .ptr ⟨bB, 0⟩, .bits 32 x3, .bits 32 (BitVec.ofNat 32 N), .bits 32 (BitVec.ofNat 32 K)] m
      (fun ω => ∀ β < L.grid .x, ω.1 (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32)
      (fun b => colsObs L N p0 { blocks := b }) (TorchCols K bits g mono I) := fun ω hω => by
  obtain ⟨s₀, h, hS⟩ := kernel_sound hC hL hx hgy hgz hN hK hK32 hKN hNg hb0 hf0 hbA hbB hfA hfB
    hA hB bits I hIA hIB ω hω
  refine ⟨s₀, h, { hS with post := fun s hr hd => ?_ }⟩
  obtain ⟨y, hy, hR⟩ := hS.post s hr hd
  exact ⟨y, hy, torchCols_of_rule g mono hR⟩

/-- The caller's memory of `sound1024`, for every matrix `B` (`32 × 32`) and vector `A` (length
32) of binary32 words: `GemvThread.mem B A`, the matrix at block 1, the vector at block 2 and an
output of 32 words at block 3 (gemv_kernel's caller memory at `M = K = 32`, the same layout,
`GevmSpec.layout_eq`), closed for gevm_kernel's arguments `[.ptr ⟨3, 0⟩, .ptr ⟨2, 0⟩,
.ptr ⟨1, 0⟩, %3, 32, 32]` at every word `%3` (`GemvThread.mem_caller`, its closure for gemv's
order of the same pointers). A test. -/
theorem mem_closed (A : TorchLean.Tensor (Model FloatTy.float.fmt) [32])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [32, 32]) (x3 : BitVec 32) :
    (GemvThread.mem B A).Closed [.ptr ⟨3, 0⟩, .ptr ⟨2, 0⟩, .ptr ⟨1, 0⟩, .bits 32 x3,
      .bits 32 (BitVec.ofNat 32 32), .bits 32 (BitVec.ofNat 32 32)] :=
  have h := (GemvThread.mem_caller (by decide) (by decide) (by decide) B A).closed 0
  ⟨h.pos, h.null, h.above, by
    have := h.vals
    simp only [Val.bounds, Val.bound] at this ⊢
    omega, h.bytes⟩

/-- **Test: `kernel_sound` with every premise proved**: gevm_kernel at one block of 1024 threads
(`launch2 1 1 1024 1`: 32 warps, columns 0 to 31), `N = K = 32`, every vector `A` (length 32) and
matrix `B` (`32 × 32`) of binary32 words, the memory `GemvThread.mem B A` (the matrix at block 1,
the vector at block 2, the output at block 3), `%3` any word, width 32 and the input words
`GevmSpec.colWords 32 A B`: gevm_kernel is sound at `sig` for the admission "the shared array
fits below `2 ^ 32`", the output columns (`GevmSpec.colsObs`) and `GevmSpec.ColsRule`. The memory
premises by `GemvThread.mem_caller` and `mem_closed`, the launch's by `launch2_valid`, `decide`
on numerals and `rfl`, `hIA` and `hIB` by `rfl`; no run is evaluated. -/
theorem sound1024 (A : TorchLean.Tensor (Model FloatTy.float.fmt) [32])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [32, 32]) (x3 : BitVec 32) :
    GPUProof.Kernel.Sound sig (gevm.prog, gevm.fn_0) (launch2 1 1 1024 1) [.ptr ⟨3, 0⟩,
      .ptr ⟨2, 0⟩, .ptr ⟨1, 0⟩, .bits 32 x3, .bits 32 (BitVec.ofNat 32 32),
      .bits 32 (BitVec.ofNat 32 32)] (GemvThread.mem B A)
      (fun ω => ∀ β < (launch2 1 1 1024 1).grid .x,
        ω.1 (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32)
      (fun b => colsObs (launch2 1 1 1024 1) 32 3 { blocks := b })
      (ColsRule 32 32 (colWords 32 A B)) :=
  have h := GemvThread.mem_caller (by decide) (by decide) (by decide) B A
  kernel_sound (mem_closed A B x3) (launch2_valid (by decide)) rfl rfl rfl (by decide)
    (by decide) (by decide) (by decide) rfl h.hb0 h.hf0 h.hbV h.hbA h.hfV h.hfA h.hV h.hA 32 _
    (fun _ => rfl) fun _ _ => rfl

/-- **Test: `gevm_torchLean` with every premise proved**: gevm_kernel at one block of 1024
threads (`launch2 1 1 1024 1`), `N = K = 32`, every vector `A` and matrix `B` of binary32 words,
the memory `GemvThread.mem B A`, `%3` any word, width 32, the input words
`GevmSpec.colWords 32 A B` (as `sound1024`) and the grade `GPUProof.matVecGrade` of the
importer's `.matVec`, monotone by `GPUProof.matVecGrade_mono`: gevm_kernel is sound at `sig` for
the same admission, the output columns and `GevmSpec.TorchCols`. No run is evaluated. -/
theorem torch1024 (A : TorchLean.Tensor (Model FloatTy.float.fmt) [32])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [32, 32]) (x3 : BitVec 32) :
    GPUProof.Kernel.Sound sig (gevm.prog, gevm.fn_0) (launch2 1 1 1024 1) [.ptr ⟨3, 0⟩,
      .ptr ⟨2, 0⟩, .ptr ⟨1, 0⟩, .bits 32 x3, .bits 32 (BitVec.ofNat 32 32),
      .bits 32 (BitVec.ofNat 32 32)] (GemvThread.mem B A)
      (fun ω => ∀ β < (launch2 1 1 1024 1).grid .x,
        ω.1 (Nat.pair (β + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32)
      (fun b => colsObs (launch2 1 1 1024 1) 32 3 { blocks := b })
      (TorchCols 32 32 GPUProof.matVecGrade GPUProof.matVecGrade_mono (colWords 32 A B)) :=
  have h := GemvThread.mem_caller (by decide) (by decide) (by decide) B A
  gevm_torchLean (N := 32) (K := 32) (p0 := 3) (bA := 2) (bB := 1) (mem_closed A B x3)
    (launch2_valid (by decide)) rfl rfl rfl (by decide) (by decide) (by decide) (by decide) rfl
    h.hb0 h.hf0 h.hbV h.hbA h.hfV h.hfA h.hV h.hA 32 (colWords 32 A B) (fun _ => rfl)
    (fun _ _ => rfl) GPUProof.matVecGrade GPUProof.matVecGrade_mono

end MojoProofTest.GevmSound
