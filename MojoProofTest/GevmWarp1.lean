import MojoProofTest.GevmWarp0
import MojoProofTest.GevmLane
import MojoProofTest.GemvLoopBfly
import MojoProof.Sym.ShflDeliver
import MojoProof.Sym.LaneFrame
import MojoProof.Sym.StartShared
import MojoProof.Sym.PhaseExt
import MojoProof.Tile.Words
import MojoProof.Sym.SigKernel

/-!
# gevm_kernel's second phase, warp by warp

After the barrier (MojoProofTest/GevmWarp0.lean) each thread of gevm_kernel (`gevm`) loads cell
`tid.x` of its block's shared array, adds the five butterfly shuffles' deliveries
(`shfl.sync.bfly` at offsets 16, 8, 4, 2, 1) and, on lane 0, stores the sum to cell
`32 ctaid.x + tid.x / 32` of the output buffer (lines 79-115 of the corpus file
gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll).

* `resume`: one thread's run from the barrier, resumed on a memory whose shared array holds
  values `v`, through its five shuffles to its end (`GevmLane.thread` after `GevmBar.at59`).
* `Warp`, `Warp.acc`, `Warp.mem`, `Warp.W`: a warp from its first thread, its lanes' sums and
  the memories and waits of `WarpRun.of_waits` at `J = 5`.
* `Warp.warp`: **every warp of every block** runs from the barrier to its end (`WarpRun`), and
  lane 0's store then loads as its sum after the five rounds (`Warp.acc 5 0`).
* `Warp.acc_nanEq`: on the shared array `GevmWarp0.block` leaves, that sum is column
  `32 ctaid.x + q`'s `warpDot` (warp `q` of the block) up to NaNs (`warpDot_tpose`).
* `Ev1`, `Acc`, `Warp.mout_ext`: the events of a block's second phase (non-invariant reads of
  its shared array, lane 0's store of its column), every access of the run with its phase, and
  a warp's second phase's trace by `Ev1` events.
* `block`: **every block** runs from its entry to its end (`BlockRun`: phase 0 by
  `GevmWarp0.block`, the barrier, phase 1 by `CanonRun.of_inv` over its warps by `Warp.warp`,
  the earlier warps' columns kept by `Warp.load_mout`), and each of its 32 columns then loads as
  the column's `warpDot` up to NaNs, the other blocks and columns kept; its trace extends by
  `Ev0` events, the barrier, then `Ev1` events.
* `ColsDot`: every output column's load is its `warpDot` up to NaNs (`MojoProof.Tile.WarpWords` at
  `vecMatPairs`), the relation of the output.
* `blocks`: on a one-dimensional grid, **the blocks in turn** (`PhaseRun`, by `PhaseRun.of_inv`
  over `block`) to a memory with `ColsDot` whose trace's accesses are `Acc`s at their phases
  (`PhaseInv`, MojoProof/Sym/PhaseExt.lean); `grid`: from a start whose threads and memory have
  `blocks`' premises, the grid steps to a done grid with `ColsDot` (`PhaseRun.start_done`) and
  that trace (MojoProofTest/GevmSound.lean's `grid_bad`: the grid is not bad).

Tests of one program, gevm_kernel float32 `1308aaae`; the lemmas they use
(MojoProof/Sym/Canon.lean, MojoProof/Sym/WarpRoute.lean, MojoProof/Sem/Transpose.lean) are for
every program.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.OblGevm MojoProofTest.OblGevmRun MojoProofTest.GevmWarp0
open MojoProofTest.GemvLoopTail (addAt total)
open MojoProofTest.GemvLoopBfly (offered total_chain)
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.GevmWarp1

-- `Array.all` recurses by well-founded recursion, so the kernel cannot evaluate `shflKeeps`
-- without this.
unseal Array.anyM.loop

/-- gevm_kernel's program passes `shflKeeps`: its shuffle declarations put no attribute on their
results that changes a word. -/
theorem gevm_keeps : gevm.prog.shflKeeps = true := by decide +kernel

/-- The five shuffles of `GevmLane.waits`, for a thread of gevm_kernel at step `k0` of `%59` in
context `c`, shared block `b`, `tid.x = x`, sum `s` loaded from cell `x`, deliveries `z₁` to
`z₄`, the memory `M` the barrier resumes the thread on and deliveries `d₁` to `d₅`. A test
definition. -/
def shuffles (c : Ctx) (k0 b x : Nat) (s z₁ z₂ z₃ z₄ : Model FloatTy.float.fmt) (M : Mem)
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) : List Piece.Wait :=
  (GevmLane.waits c k0 b x s z₁ z₂ z₃ z₄ M (none, M) d₁ d₂ d₃ d₄ d₅).tail

/-- **One thread of gevm_kernel from the barrier to its end** (test): for every valid launch `L`
with 1024 threads per block in `x`, contexts `c`, threads `t`, `N`, `K`, `A` and `B` as in
`GevmWarp0.lane`, thread `n` with `Lane`'s premises at a status at the barrier from thread `u`
(`AtBar`), values `v`, memory `M` that has the shared array `b` as `Bufs` has it, holding `v`
row-major, binary32 `z₁` to `z₅` and deliveries `d₁` to `d₅` of them, with `d₅.2` having the
output buffer `p0` as `Bufs` has it: thread `u` resumed with no value on `M` runs through the
five shuffles (`shuffles`, at the step `k0` the thread reaches `%59` at) to its end, on a memory
that is, for lane 0, `d₅.2` with the sum `addAt` of `v tid.x` and `z₁` to `z₅` (at steps
`k0 + 12` to `k0 + 28`) stored at cell `32 ctaid.x + tid.x / 32` of `p0`, and `d₅.2` for the
other lanes. The thread's run to the barrier from `AtBar`'s memory (`OblGevmRun.loop`,
`GevmBar.at59`) is the one `GevmLane.thread` continues; `ToWait.det` makes its wait `u`'s. -/
theorem resume {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) {c : Nat → Ctx}
    {t : Nat → Thread} {N K p0 bA bB b g : Nat} (hN : N < 2 ^ 31) (hK : K < 2 ^ 31)
    (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} {n : Nat}
    (hn : Lane L c t N K p0 bA bB b g n) {u : Thread} {xs : List Val} {e : Func}
    (hσ : AtBar c t N K p0 bA bB b g A B n (.wait u .barrier xs e))
    (v : Nat → Model FloatTy.float.fmt) (M : Mem) (hB₀ : M.BufferIn 3 b 4096 4 (.cta g) true)
    (hF₀ : ∃ blk, M.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hv : M.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0)
      (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] => v i.1.val))
    (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt) (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem)
    (hd₁ : d₁.1 = some (Val.ofFloat .float z₁)) (hd₂ : d₂.1 = some (Val.ofFloat .float z₂))
    (hd₃ : d₃.1 = some (Val.ofFloat .float z₃)) (hd₄ : d₄.1 = some (Val.ofFloat .float z₄))
    (hd₅ : d₅.1 = some (Val.ofFloat .float z₅))
    (hy : d₅.2.Buffer p0 (N * 4) 4 true) (hfy : d₅.2.Fits gevm.prog.layout p0 (N * 4)) :
    RunsVia (c n) (fun m' => ((L.env n).laneid = 0 →
        d₅.2.store gevm.prog.layout (c n).who 0 (.fp .float) (Val.ofFloat .float
          (addAt (c n) ((t n).k + 36 + 17 * (K / 32) + 28)
            (addAt (c n) ((t n).k + 36 + 17 * (K / 32) + 24)
            (addAt (c n) ((t n).k + 36 + 17 * (K / 32) + 20)
            (addAt (c n) ((t n).k + 36 + 17 * (K / 32) + 16)
            (addAt (c n) ((t n).k + 36 + 17 * (K / 32) + 12)
              (v ((L.env n).sreg .tid .x)) z₁) z₂) z₃) z₄) z₅))
          ⟨p0, ((((L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩
          (some 4) = .ok m') ∧ ((L.env n).laneid ≠ 0 → m' = d₅.2))
      ((shuffles (c n) ((t n).k + 36 + 17 * (K / 32)) b ((L.env n).sreg .tid .x)
        (v ((L.env n).sreg .tid .x)) z₁ z₂ z₃ z₄ M d₁ d₂ d₃ d₄ d₅).map
        (Piece.Wait.via gevm.fn_0 gevm.fn_0.b_5.label)) (u.resume none) M := by
  obtain ⟨hcp, hce, hg, hin, hcol, f, ht, hf, hlb, hpc, ha, hr0, hr1, hr2, hr4, hr5⟩ := hn
  obtain ⟨m, m₁, hm, hw, -⟩ := hσ
  obtain ⟨hb0, hf0, hbA, hbB, hfA, hfB, hA, hB, hS, hF⟩ := hm
  obtain ⟨-, htid, hlid, -⟩ := Launch.tpose_env hL hx n
  have hc : (L.env n).sreg .ctaid .x * 32 + (L.env n).laneid < N := by omega
  have hy' : (L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32 < N := by omega
  obtain ⟨t', m', f', hs, ht', hf', hlb', hpc', ha', -, hk', hbl, -, h60, h13, h11, h10, h29⟩ :=
    loop L hL n (c n) hcp hce hx (t n) m f [] ht hf hlb hpc N K p0 bA bB hN hK hK32 hKN hr0 hr1
      hr2 hr4 hr5 hb0 hf0 hbA hbB hfA hfB A B hA hB hy' hc
  have hl := Launch.laneid_lt L n
  have hw32 : (L.env n).sreg .tid .x / 32 < 32 := by omega
  have hx' : (L.env n).sreg .tid .x < 1024 := by omega
  have hS' : m'.BufferIn 3 b 4096 4 (.cta g) true := by unfold Mem.BufferIn; rw [hbl]; exact hS
  have hF' : ∃ blk, m'.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1 := by
    rw [hbl]; exact hF
  obtain ⟨-, -, M₀, -, -, -, hM₀⟩ :=
    GevmBar.at59 (c n) hcp t' m' f' [] ht' hf' hlb' hpc' _ _ hl hw32 _ h13 h11 h60 b g hg hS' hin
      hF'
  have hT := GevmLane.thread (c n) hcp t' m' f' ht' hf' hlb' hpc' (ha'.trans ha) _ _ _ hl hw32 hx'
    _ p0 N _ hy' h13 h11 h10 h60 h29 b g hg hS' hin hF' M₀ hM₀ (none, M) d₁ d₂ d₃ d₄ d₅ _ hB₀ hF₀
    hv z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄ hd₅ hy hfy
  simp only [hk', TorchLean.Tensor.Rep.get_ofFn] at hT
  obtain ⟨u₂, i₂, xs₂, e₂, m₂, ⟨u₃, i₃, ys, d', he₃, hs₃, hst⟩, -, hR⟩ := hT
  obtain ⟨hu, -⟩ := ToWait.det hw ⟨u₃, i₃, ys, d', he₃, hs.trans hs₃, hst⟩
  obtain ⟨rfl, -, -, -⟩ := Status.wait.inj hu
  exact hR

/-- The events of gevm_kernel's second phase in block of threads `g`, for launch `L`, contexts
`c`, shared array `b` and output block `p0`: an access by a thread `n` of `g` (`c n`'s thread)
that reads `b` and is not invariant, or, for `n` of lane 0 (`n % 32 = 0`), the store of 4 bytes
at its output cell `32 ctaid.x + tid.x / 32` of `p0`. A test definition. -/
def Ev1 (L : Launch) (c : Nat → Ctx) (b p0 g : Nat) (e : Event) : Prop :=
  ∃ a n, e = .access a ∧ n / 1024 = g ∧ a.who = (c n).who ∧
    ((a.write = false ∧ a.invariant = false ∧ a.ptr.block = b) ∨ n % 32 = 0 ∧ a = ⟨(c n).who,
      ⟨p0, ((((L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩, 4,
      true, none, false⟩)

/-- The accesses of gevm_kernel's run at their phases, for launch `L`, contexts `c`, shared
arrays `sb g` of the blocks of threads `g`, input blocks `bA`, `bB` and output block `p0`: at
every phase `p` a read of `bA` or `bB`; at phase 0 the store of 4 bytes by a thread `n` of the
grid at its cell `32 laneid + tid.x / 32` of its block's shared array `sb (n / 1024)`; at a later
phase a read, not invariant, of a shared array of the grid; at every phase the store of 4 bytes
by a thread `n` of lane 0 at its output cell `32 ctaid.x + tid.x / 32` of `p0`. A test
definition. -/
def Acc (L : Launch) (c : Nat → Ctx) (sb : Nat → Nat) (bA bB p0 p : Nat) (a : Access) : Prop :=
  (a.write = false ∧ (a.ptr.block = bA ∨ a.ptr.block = bB)) ∨
    (∃ n, n / 1024 < L.grid .x ∧ p = 0 ∧ a = ⟨(c n).who, ⟨sb (n / 1024),
      ((((L.env n).laneid * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩, 4, true, none,
      false⟩) ∨
    (p ≠ 0 ∧ a.write = false ∧ a.invariant = false ∧ ∃ g < L.grid .x, a.ptr.block = sb g) ∨
    ∃ n, n % 32 = 0 ∧ n / 1024 < L.grid .x ∧ a = ⟨(c n).who, ⟨p0,
      ((((L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩, 4, true,
      none, false⟩

/-- A warp of gevm_kernel's second phase: the launch, contexts, threads at the entry, the
vector's length, the shared array's and output buffer's blocks, the shared array's values after
the barrier, the warp's first thread and the memory the warp starts on. A test definition. -/
structure Warp where
  /-- The warp of a launch from its first thread, with the kernel's sizes and blocks. -/
  mk ::
  /-- The launch. -/
  L : Launch
  /-- The threads' contexts. -/
  c : Nat → Ctx
  /-- The threads at the kernel's entry. -/
  t : Nat → Thread
  /-- The vector's length. -/
  K : Nat
  /-- The shared array's block. -/
  b : Nat
  /-- The output buffer's block. -/
  p0 : Nat
  /-- The shared array's cells after the barrier. -/
  v : Nat → Model FloatTy.float.fmt
  /-- The warp's first thread. -/
  k : Nat
  /-- The memory the warp starts on. -/
  M : Mem

namespace Warp

variable (w : Warp)

/-- Lane `j`'s `tid.x`. -/
def x (j : Nat) : Nat := (w.L.env (w.k + j)).sreg .tid .x

/-- Lane `j`'s step at statement 1 of `%59` (`OblGevmRun.loop`'s). -/
def k0 (j : Nat) : Nat := (w.t (w.k + j)).k + 36 + 17 * (w.K / 32)

/-- Lane `j`'s sum before shuffle `i` (from 0), and after the fifth at `i = 5`: the shared array's
cell `x j`, then `addAt` of its sum and its partner `j ^^^ 2 ^ (4 - i)`'s at step
`k0 j + 4 i + 12` (`GevmLane.waits`' chain). -/
def acc : Nat → Nat → Model FloatTy.float.fmt
  | 0, j => w.v (w.x j)
  | i + 1, j =>
    addAt (w.c (w.k + j)) (w.k0 j + (4 * i + 12)) (acc i j) (acc i (j ^^^ 2 ^ (4 - i)))

/-- What lane `j` offers at shuffle `i`: the binary32 of its sum `acc i j`. -/
def X (i j : Nat) : Val := .ofFloat .float (w.acc i j)

/-- The memory before lane `j`'s first shuffle, for the lanes before it in turn: the start memory
with lanes `0` to `j - 1`'s loads of their cells `x` logged. -/
def mlog : Nat → Mem
  | 0 => w.M
  | j + 1 => (mlog j).log
      (.access ⟨(w.c (w.k + j)).who, ⟨w.b, ((w.x j * 4 : Nat) : Int)⟩, 4, false, none, false⟩)

/-- The binary32 store lane 0 makes: its sum after the five shuffles at cell
`32 ctaid.x + tid.x / 32`. -/
def o : Nat := (w.L.env w.k).sreg .ctaid .x * 32 + (w.L.env w.k).sreg .tid .x / 32

/-- The memory after lane 0's store on `mlog 32` (`mlog 32` if the store fails). -/
def mout : Mem :=
  match (w.mlog 32).store gevm.prog.layout (w.c w.k).who 0 (.fp .float) (w.X 5 0)
      ⟨w.p0, ((w.o * 4 : Nat) : Int)⟩ (some 4) with
  | .ok m => m
  | .error _ => w.mlog 32

/-- The memory at phase `i` before lane `j`: `WarpRun.of_waits`'s memories. -/
def mem : Nat → Nat → Mem
  | 0, j => w.mlog j
  | 5, 0 => w.mlog 32
  | 5, _ + 1 => w.mout
  | _, _ => w.mlog 32

/-- Lane `j`'s delivery at shuffle `i`: its partner's offer, on the memory after the phase's last
lane. -/
def D (i j : Nat) : Option Val × Mem := (some (w.X i (j ^^^ 2 ^ (4 - i))), w.mem (i + 1) j)

/-- Lane `j`'s `i`-th wait, as `resume` states it. -/
def W (i j : Nat) : Piece.Wait :=
  (shuffles (w.c (w.k + j)) (w.k0 j) w.b (w.x j) (w.v (w.x j)) (w.acc 0 (j ^^^ 16))
    (w.acc 1 (j ^^^ 8)) (w.acc 2 (j ^^^ 4)) (w.acc 3 (j ^^^ 2)) (w.mlog j) (w.D 0 j) (w.D 1 j)
    (w.D 2 j) (w.D 3 j) (w.D 4 j)).getD i ⟨0, .barrier, [], w.M, (none, w.M)⟩

variable {w}

/-- For every warp, each `mlog j` has the start memory's blocks. -/
theorem mlog_blocks : ∀ j, (w.mlog j).blocks = w.M.blocks
  | 0 => rfl
  | j + 1 => mlog_blocks j

/-- For every warp, lane 0's store on `mlog 32`, when it succeeds, makes `mout`. -/
theorem mout_eq {m : Mem} (h : (w.mlog 32).store gevm.prog.layout (w.c w.k).who 0 (.fp .float)
    (w.X 5 0) ⟨w.p0, ((w.o * 4 : Nat) : Int)⟩ (some 4) = .ok m) : w.mout = m := by
  unfold mout
  rw [h]

/-- For every warp, `mout` has the start memory's blocks but at `p0`, and has `p0` as a writable
buffer of `N` binary32 that fits when the start memory does. -/
theorem mout_frame {N : Nat} (hy : w.M.Buffer w.p0 (N * 4) 4 true)
    (hfy : w.M.Fits gevm.prog.layout w.p0 (N * 4)) :
    (∀ q, q ≠ w.p0 → w.mout.blocks q = w.M.blocks q) ∧ w.mout.Buffer w.p0 (N * 4) 4 true ∧
      w.mout.Fits gevm.prog.layout w.p0 (N * 4) := by
  have hq : ∀ x, w.M.blocks w.p0 = some x → (w.mlog 32).blocks w.p0 = some x := fun x hx => by
    rw [mlog_blocks]; exact hx
  unfold mout
  split
  · rename_i h
    exact ⟨fun q hq => by rw [Mem.store_blocks h (Ne.symm hq), mlog_blocks],
      Mem.Buffer.of_store h (hy.of_block hq), Mem.Fits.of_store h (hfy.of_block hq)⟩
  · exact ⟨fun q _ => by rw [mlog_blocks], hy.of_block hq, hfy.of_block hq⟩

/-- **A warp's second-phase events** (test): gevm_kernel (the corpus file), for every warp `w`
whose first thread `w.k` is of lane 0 (`w.k % 32 = 0`) in block of threads `g`: `mout`'s trace
extends the start memory's by `Ev1` events (`Ext`): the lanes' loads of their cells `x j` of
`w.b` (`mlog`, `Ext.chain`) and lane 0's store to `w.p0` (`Ext.store`,
MojoProof/Sym/SigKernel.lean). -/
theorem mout_ext {g : Nat} (hk : w.k % 32 = 0) (hg : w.k / 1024 = g) :
    Ext (Ev1 w.L w.c w.b w.p0 g) w.M w.mout :=
  (Ext.chain (mm := w.mlog) (n := 32) (fun j hj => ⟨[_], rfl, fun e he => by
    rw [List.mem_singleton.1 he]
    exact ⟨_, w.k + j, rfl, by omega, rfl, .inl ⟨rfl, rfl, rfl⟩⟩⟩) 32 le_rfl).trans
    (Ext.store ⟨_, w.k, rfl, hg, rfl, .inr ⟨hk, rfl⟩⟩)

/-- For every warp, each `mlog j` loads as the start memory does (a log keeps the blocks). -/
theorem mlog_load {l : Layout} {who : Who} {a : Nat} {ty : Ty} {p : Ptr} {al : Option Nat} :
    ∀ j, (w.mlog j).load l who a ty p al = w.M.load l who a ty p al
  | 0 => rfl
  | j + 1 => mlog_load j

/-- For every warp, a binary32 load from the output buffer `p0` at a cell `o' ≠ o` that gives
`x` on the start memory gives `x` on `mout` (`Mem.load_store_apart`). -/
theorem load_mout {who : Who} {o' : Nat} {x : Val} (ho : o' ≠ w.o)
    (h : w.M.load gevm.prog.layout who 0 (.fp .float) ⟨w.p0, ((o' * 4 : Nat) : Int)⟩ (some 4) =
      .ok x) :
    w.mout.load gevm.prog.layout who 0 (.fp .float) ⟨w.p0, ((o' * 4 : Nat) : Int)⟩ (some 4) =
      .ok x := by
  have h' := (mlog_load 32).trans h
  have h4 : gevm.prog.layout.stored (.fp .float) = 4 := rfl
  unfold mout
  split
  · rename_i hs
    refine Mem.load_store_apart hs (.inr ?_) h'
    simp only [h4, Int.toNat_natCast]
    omega
  · exact h'

/-- For every warp, lane `j`'s `i`-th wait, for `i < 5`, is a butterfly shuffle. -/
theorem W_call {i : Nat} (hi : i < 5) (j : Nat) : (w.W i j).call.intr = .shfl .bfly := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp, lane `j`'s `i`-th wait, for `i < 5`, is at statement `4 i + 11` of `%59`. -/
theorem W_pos {i : Nat} (hi : i < 5) (j : Nat) : (w.W i j).pos = 4 * i + 11 := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp, lane `j`'s `i`-th wait, for `i < 5`, has the arguments mask `-1`, lane `j`'s
offer `X i j`, `2 ^ (4 - i)` and `31`. -/
theorem W_args {i : Nat} (hi : i < 5) (j : Nat) :
    (w.W i j).args = [.bits 32 (BitVec.ofInt 32 (-1)), w.X i j,
      .bits 32 (BitVec.ofInt 32 ((2 ^ (4 - i) : Nat) : Int)), .bits 32 (BitVec.ofInt 32 31)] := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For every warp, lane `j`'s `i`-th wait, for `i < 5`, is on `mem i (j + 1)` and has the
delivery `D i j`. -/
theorem W_mem {i : Nat} (hi : i < 5) (j : Nat) :
    (w.W i j).mem = w.mem i (j + 1) ∧ (w.W i j).dlv = w.D i j := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | exact ⟨rfl, rfl⟩

/-- For every warp, each phase `i < 5` starts on the memory the previous one ends on. -/
theorem mem_zero {i : Nat} (hi : i < 5) : w.mem (i + 1) 0 = w.mem i 32 := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | rfl

/-- For `i < 5`, the 32-bit `2 ^ (4 - i)` has the word `2 ^ (4 - i)`. -/
theorem ofs_word {i : Nat} (hi : i < 5) :
    (Val.bits 32 (BitVec.ofInt 32 ((2 ^ (4 - i) : Nat) : Int))).word? = some (2 ^ (4 - i)) := by
  rcases i with _ | _ | _ | _ | _ | i <;> first | omega | decide

/-- **Lane `j`'s `i`-th wait, as `WarpRun.of_waits` takes it**: for every warp of a full warp's
lanes whose lane `j < 32` runs gevm's program, and every phase `i < 5`, the wait is a butterfly
shuffle at one position for every lane, of mask `2 ^ 32 - 1`, lane `j`'s offer `X i j`, offset
`2 ^ (4 - i)` and clamp 31, and every declaration a call finds by a name mapped to the shuffle
delivers the partner's offer (`Program.shfl_deliver_bfly`), the wait's delivery. -/
theorem shape (hfull : warpLanes w.L w.k = List.range 32) {i j : Nat} (hi : i < 5) (hj : j < 32)
    (hcp : (w.c (w.k + j)).prog = gevm.prog) :
    (w.W i j).call.intr = .shfl .bfly ∧
      (w.W i j).pos = (w.W i 0).pos ∧ ∃ Mk Bv Cv b cl, (w.W i j).args = [Mk, w.X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (w.c (w.k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (w.c (w.k + j)).prog.intrinsics.lookup g = some (.shfl .bfly) →
          (some (shflVal (warpLanes w.L w.k) (w.X i) (shflSource .bfly j b cl))).mapM
            (withAttrs (w.c w.k).prog.layout (w.mem i (warpLanes w.L w.k).length) e.ret
              e.retAttrs) = .ok (w.W i j).dlv.1 := by
  refine ⟨W_call hi j, (W_pos hi j).trans (W_pos hi 0).symm, .bits 32 (BitVec.ofInt 32 (-1)),
    .bits 32 (BitVec.ofInt 32 ((2 ^ (4 - i) : Nat) : Int)), .bits 32 (BitVec.ofInt 32 31),
    2 ^ (4 - i), 31, W_args hi j, by decide, ofs_word hi, by decide, fun g e he hl => ?_⟩
  rw [(W_mem hi j).2]
  exact Program.shfl_deliver_bfly gevm_keeps hfull hj
    ((Nat.pow_le_pow_right (by decide) (Nat.sub_le 4 i)).trans_lt (by decide)) rfl rfl g e
    (by rwa [hcp] at he) (by rwa [hcp] at hl)

/-- **gevm_kernel's warp from the barrier to its end** (test): for every valid launch with 1024
threads per block in `x`, contexts, threads at the entry, `N`, `K`, `A` and `B` as in
`GevmWarp0.lane`, every warp `w` from first thread `w.k` (lane 0, `w.k % 1024 % 32 = 0`) whose
threads have `Lane`'s premises and are at statuses at the barrier from threads `u` (`AtBar`), and
every memory `w.M` with the shared array `w.b` as `Bufs` has it, holding `w.v` row-major, and the
output buffer `w.p0` as `Bufs` has it: the warp's 32 lanes, resumed from `u` with no value, run
(`WarpRun`) from `w.M` to `mout` (`WarpRun.of_waits` at `J = 5`, each lane by `resume` and
`RunsVia.of_block`, each delivery its partner's offer by `shape`); the word at cell `o` of the
output buffer then loads as lane 0's sum after the five shuffles (`acc 5 0`), and `mout` has
`w.M`'s blocks but at `w.p0`, and the output buffer. -/
theorem warp (hL : w.L.Valid) (hx : w.L.block .x = 1024) {N bA bB g : Nat} (hN : N < 2 ^ 31)
    (hK : w.K < 2 ^ 31) (hK32 : w.K % 32 = 0) (hKN : w.K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [w.K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [w.K, N]} (hk : w.k % 1024 % 32 = 0)
    (hl : ∀ n ∈ warpThreads w.L w.k, Lane w.L w.c w.t N w.K w.p0 bA bB w.b g n)
    {u : Nat → Thread}
    (hu : ∀ n ∈ warpThreads w.L w.k, ∃ xs e,
      AtBar w.c w.t N w.K w.p0 bA bB w.b g A B n (.wait (u n) .barrier xs e))
    (hB₀ : w.M.BufferIn 3 w.b 4096 4 (.cta g) true)
    (hF₀ : ∃ blk, w.M.blocks w.b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hv : w.M.Holds gevm.prog.layout w.b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0)
      (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] => w.v i.1.val))
    (hy : w.M.Buffer w.p0 (N * 4) 4 true) (hfy : w.M.Fits gevm.prog.layout w.p0 (N * 4)) :
    ∃ Es, WarpRun w.L w.c w.k (fun n => (u n).resume none) w.M Es w.mout ∧
      w.mout.load gevm.prog.layout (w.c w.k).who 0 (.fp .float)
        ⟨w.p0, ((w.o * 4 : Nat) : Int)⟩ (some 4) = .ok (w.X 5 0) ∧
      (∀ q, q ≠ w.p0 → w.mout.blocks q = w.M.blocks q) ∧ w.mout.Buffer w.p0 (N * 4) 4 true ∧
      w.mout.Fits gevm.prog.layout w.p0 (N * 4) := by
  have hv1 : volume w.L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hfull := warpLanes_full (L := w.L) (by rw [hv1]; decide) ⟨32, by rw [hv1]⟩ w.k
  have hfr := mout_frame hy hfy
  have hq : ∀ j, ∀ x, w.M.blocks w.b = some x → (w.mlog j).blocks w.b = some x :=
    fun j x hx => by rw [mlog_blocks]; exact hx
  have hq0 : ∀ j, ∀ x, w.M.blocks w.p0 = some x → (w.mlog j).blocks w.p0 = some x :=
    fun j x hx => by rw [mlog_blocks]; exact hx
  have h5 : ∀ j, (w.mem 5 j).Buffer w.p0 (N * 4) 4 true ∧
      (w.mem 5 j).Fits gevm.prog.layout w.p0 (N * 4) := fun j => by
    rcases j with _ | j
    · exact ⟨hy.of_block (hq0 32), hfy.of_block (hq0 32)⟩
    · exact ⟨hfr.2.1, hfr.2.2⟩
  have hR : ∀ j < 32, RunsVia (w.c (w.k + j)) (fun m' => ((w.L.env (w.k + j)).laneid = 0 →
        (w.mem 5 j).store gevm.prog.layout (w.c (w.k + j)).who 0 (.fp .float)
          (Val.ofFloat .float (w.acc 5 j))
          ⟨w.p0, ((((w.L.env (w.k + j)).sreg .ctaid .x * 32 +
            (w.L.env (w.k + j)).sreg .tid .x / 32) * 4 : Nat) : Int)⟩ (some 4) = .ok m') ∧
        ((w.L.env (w.k + j)).laneid ≠ 0 → m' = w.mem 5 j))
      ((shuffles (w.c (w.k + j)) (w.k0 j) w.b (w.x j) (w.v (w.x j)) (w.acc 0 (j ^^^ 16))
        (w.acc 1 (j ^^^ 8)) (w.acc 2 (j ^^^ 4)) (w.acc 3 (j ^^^ 2)) (w.mlog j) (w.D 0 j)
        (w.D 1 j) (w.D 2 j) (w.D 3 j) (w.D 4 j)).map
        (Piece.Wait.via gevm.fn_0 gevm.fn_0.b_5.label)) ((u (w.k + j)).resume none) (w.mlog j) :=
    fun j hj => by
      have hn : w.k + j ∈ warpThreads w.L w.k :=
        List.mem_map.2 ⟨j, by rw [hfull, List.mem_range]; exact hj, rfl⟩
      obtain ⟨xs, e, hσ⟩ := hu _ hn
      exact resume hL hx hN hK hK32 hKN (hl _ hn) hσ w.v (w.mlog j)
        (by unfold Mem.BufferIn; rw [mlog_blocks]; exact hB₀) (by rw [mlog_blocks]; exact hF₀)
        (hv.of_block (hq j)) _ _ _ _ (w.acc 4 (j ^^^ 1)) (w.D 0 j) (w.D 1 j) (w.D 2 j) (w.D 3 j)
        (w.D 4 j) rfl rfl rfl rfl rfl (h5 j).1 (h5 j).2
  have hlj : ∀ j < 32, (w.L.env (w.k + j)).laneid = j := fun j hj => by
    rw [(Launch.tpose_env hL hx (w.k + j)).2.2.1]
    omega
  have hr : ∀ j ∈ warpLanes w.L w.k, RunsVia (w.c (w.k + j)) (· = w.mem 5 (j + 1))
      ((List.range 5).map fun i => (w.W i j).via gevm.fn_0 gevm.fn_0.b_5.label)
      ((u (w.k + j)).resume none) (w.mem 0 j) := by
    intro j hj
    rw [hfull, List.mem_range] at hj
    refine RunsVia.of_block (hR j hj) rfl (fun _ _ => rfl) ?_
    rintro m' ⟨h0, h1⟩
    rcases j with _ | j
    · exact (mout_eq (h0 (hlj 0 hj))).symm
    · exact h1 (by rw [hlj _ hj]; omega)
  obtain ⟨Es, hE⟩ := WarpRun.of_waits (J := 5) (fn := gevm.fn_0)
    (lbl := fun _ => gevm.fn_0.b_5.label) (mo := fun _ => .bfly) (X := w.X) (M := w.mem)
    (W := w.W) (t := fun n => (u n).resume none) hr
    (fun i hi j hj => by
      rw [hfull, List.mem_range] at hj
      exact shape hfull hi hj (hl _ (List.mem_map.2 ⟨j, by rw [hfull, List.mem_range]; exact hj,
        rfl⟩)).1)
    (fun i hi j _ => ⟨(W_mem hi j).1, by rw [(W_mem hi j).2]; rfl⟩)
    (fun i hi => by rw [hfull, List.length_range]; exact mem_zero hi)
  rw [hfull, List.length_range] at hE
  obtain ⟨m₀, h0, -⟩ := RunsVia.final (hR 0 (by decide))
  have hs0 := h0 (hlj 0 (by decide))
  have hmo : w.mout = m₀ := mout_eq hs0
  obtain ⟨blk, bs, hc, -⟩ := Mem.store_inv hs0
  exact ⟨Es, hE, Mem.load_store_codec_of_block (Layout.Codec.float _ .float) (w.acc 5 0) hs0 hc
    (by rw [hmo]), hfr⟩

/-- **A warp's offered values are its lanes' sums** (test, for every warp `w`, shuffle `i` and
lane `l`): when each shuffle delivers to lane `l` its partner's sum `acc i (l ^^^ 2 ^ (4 - i))`,
the value lane `l` offers at shuffle `i` (`MojoProofTest.GemvLoopBfly.offered`, at the lanes'
contexts, steps `k0 l + 9` and cells `v (x l)`) is its `acc i`. By induction on `i`. -/
theorem offered_acc (w : Warp) : ∀ i l,
    offered (fun l => w.c (w.k + l)) (fun l => w.k0 l + 9) (fun l => w.v (w.x l))
      (fun i l => w.acc i (l ^^^ 2 ^ (4 - i))) i l = w.acc i l
  | 0, _ => rfl
  | i + 1, l => by
    rw [offered, offered_acc w i l, acc, show w.k0 l + 9 + (4 * i + 3) = w.k0 l + (4 * i + 12)
      by omega]

/-- **A warp's lane-0 sum is its value after the five butterfly rounds** (test, for every warp
`w`): `acc 5 0` is lane 0's value after the five rounds `deliver (Model.add a b)` over
`bflyOffsets 5` from the lanes' cells `v (x l)`, with lane `l`'s oracle number of round `r`,
`(w.c (w.k + l)).oracle (Nat.pair (k0 l + 9 + (4 r + 3)) 0) / 3`. By `total_chain` at lane 0
with `offered_acc`. -/
theorem acc_rounds (w : Warp) :
    w.acc 5 0 = bflyRoundsAt (fun r l a b => deliver (Model.add a b)
      ((w.c (w.k + l)).oracle (Nat.pair (w.k0 l + 9 + (4 * r + 3)) 0) / 3)) (bflyOffsets 5)
      (fun l => w.v (w.x l)) 0 :=
  (offered_acc w 5 0).symm.trans (total_chain (fun l => w.c (w.k + l)) (fun l => w.k0 l + 9)
    (fun l => w.v (w.x l)) (fun i l => w.acc i (l ^^^ 2 ^ (4 - i)))
    (fun i _ l _ => (offered_acc w i _).symm) 0 (by decide))

/-- **A warp's lane-0 sum is its column's `warpDot` up to NaNs** (test): for every valid launch
with 1024 threads per block in `x`, every warp `w` of it from first thread
`w.k = 1024 g + 32 q` (warp `q < 32` of block `g`), sizes `N`, inputs `A : [K]`, `B : [K, N]`
with the block's columns `32 ctaid.x` to `32 ctaid.x + 31` below `N`, and shared values `w.v`
that are at each cell `x < 1024` the sum (`GevmWarp0.word`) of thread `1024 g + tpose 32 x`, as
`GevmWarp0.block` leaves them: `acc 5 0` and column `32 ctaid.x + q`'s
`MojoProof.Sem.warpDot true` are the same word or both NaNs, at lane `l`'s loop oracle numbers
those of thread `1024 g + 32 l + q`, whose sum lane `l` loads. By `acc_rounds`,
`bflyDeliver_nanEq`, `bflyRounds_congr` (lane `l` loads cell `32 q + l`) and `warpDot_tpose`. -/
theorem acc_nanEq (w : Warp) (hL : w.L.Valid) (hx : w.L.block .x = 1024) {N g q : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [w.K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [w.K, N]} (hq : q < 32)
    (hk : w.k = 1024 * g + 32 * q) (hcol : (w.L.env w.k).sreg .ctaid .x * 32 + 32 ≤ N)
    (hv : ∀ x < 1024, w.v x =
      Model.ofBits (fmt := FloatTy.float.fmt) (word w.L w.c w.t N A B (1024 * g + tpose 32 x))) :
    NaNEq (w.acc 5 0) (warpDot true
      (fun l => oG (w.c (1024 * g + (32 * l + q))) (w.t (1024 * g + (32 * l + q))).k)
      (vecMatPairs A B ⟨(w.L.env w.k).sreg .ctaid .x * 32 + q, by omega⟩)) := by
  have hv1 : volume w.L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hct : ∀ n, n / 1024 = g →
      (w.L.env n).sreg .ctaid .x = (w.L.env w.k).sreg .ctaid .x := fun n hn => by
    show coord w.L.grid (n / volume w.L.block) .x = coord w.L.grid (w.k / volume w.L.block) .x
    rw [hv1, hn, show w.k / 1024 = g by omega]
  have hM : ∀ t < 1024, w.v (tpose 32 t) = dotLoop true
      (oG (w.c (1024 * g + t)) (w.t (1024 * g + t)).k) (Model.zero _ false)
      (stride 32 (t / 32) (if h : (w.L.env w.k).sreg .ctaid .x * 32 + t % 32 < N then
        vecMatPairs A B ⟨_, h⟩ else [])) := by
    intro t ht
    obtain ⟨-, htid, hlid, -⟩ := Launch.tpose_env hL hx (1024 * g + t)
    have hct' := hct (1024 * g + t) (by omega)
    have hc : (w.L.env (1024 * g + t)).sreg .ctaid .x * 32 + (w.L.env (1024 * g + t)).laneid <
        N := by omega
    have hc' : (w.L.env w.k).sreg .ctaid .x * 32 + t % 32 < N := by omega
    have e1 : word w.L w.c w.t N A B (1024 * g + t) = (dotLoop true
        (oG (w.c (1024 * g + t)) (w.t (1024 * g + t)).k) (Model.zero _ false)
        (stride 32 ((w.L.env (1024 * g + t)).sreg .tid .x / 32)
          (vecMatPairs A B ⟨_, hc⟩))).toBits := dite_eq_left hc
    have e2 : (w.L.env (1024 * g + t)).sreg .tid .x = t := by rw [htid]; omega
    have e3 : vecMatPairs A B ⟨_, hc⟩ = vecMatPairs A B ⟨_, hc'⟩ :=
      congrArg (vecMatPairs A B) (Fin.ext (by simp only [hct', hlid]; omega))
    rw [hv _ (tpose_lt (n := 32) ht), tpose_tpose (n := 32) ht, e1, Model.ofBits_toBits, e2, e3,
      dite_eq_left hc']
  have hP : (if h : (w.L.env w.k).sreg .ctaid .x * 32 + q < N then vecMatPairs A B ⟨_, h⟩
      else []) = vecMatPairs A B ⟨_, (by omega : (w.L.env w.k).sreg .ctaid .x * 32 + q < N)⟩ :=
    dite_eq_left _
  have hT := warpDot_tpose true (fun t => oG (w.c (1024 * g + t)) (w.t (1024 * g + t)).k)
    (fun l => if h : (w.L.env w.k).sreg .ctaid .x * 32 + l < N then vecMatPairs A B ⟨_, h⟩
      else []) hM hq
  simp only [hP] at hT
  have hE : bflyRounds (fun x y => Model.add x y) (bflyOffsets 5) (fun l => w.v (w.x l)) 0 =
      bflyRounds (fun x y => Model.add x y) warpOffsets (fun l => w.v (32 * q + l)) 0 :=
    bflyRounds_congr _ _ 0 fun l hl => by
      have hl : l < 32 := List.mem_range.1 ((leaves_warp 0 (by decide)).mem_iff.1 hl)
      show w.v ((w.L.env (w.k + l)).sreg .tid .x) = _
      rw [(Launch.tpose_env hL hx (w.k + l)).2.1]
      congr 1
      omega
  have h1 := bflyDeliver_nanEq (fun r l => (w.c (w.k + l)).oracle
    (Nat.pair (w.k0 l + 9 + (4 * r + 3)) 0) / 3) (bflyOffsets 5) (fun l => w.v (w.x l)) 0
  rw [hE, hT] at h1
  rw [acc_rounds]
  exact h1

end Warp

/-- **A block of gevm_kernel from its entry to its end, and its 32 columns** (test): for every
valid launch `L` with 1024 threads per block in `x`, contexts `c`, threads `t`, `N`, `K`, `A` and
`B` as in `GevmWarp0.lane`, every block of threads `g` whose threads have `Lane`'s premises and
every memory `m` with `Bufs`: the block runs (`BlockRun`, its barrier then its end) from `t` on
`m` to a memory `m'` that has the output buffer and at each column `j < N` of the block (`j / 32`
its `ctaid.x`) loads, by the thread `1024 g + 32 (j % 32)` that stores it, a binary32 that is
column `j`'s `warpDot` up to NaNs, at lane `l`'s loop oracle numbers those of thread
`1024 g + 32 l + j % 32`. Phase 0 by `GevmWarp0.block`; phase 1 by `CanonRun.of_inv` over the
block's warps, each by `Warp.warp`, with the invariant: the shared array holding the sums, the
output buffer, the blocks but `p0` kept, and the earlier warps' columns (`Warp.load_mout`: the
warps' cells differ); then `Warp.acc_nanEq`. And `m'` has `m`'s blocks other than `p0` and `b`,
`m`'s loads, by every thread, of the binary32 at the columns `o` of other blocks
(`o / 32 ≠ ctaid.x`), and a trace that extends `m`'s by `Ev0` events to the barrier and then by
`Ev1` events (`Ext`; `GevmWarp0.block`, `Warp.mout_ext`). -/
theorem block {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) {c : Nat → Ctx}
    {t : Nat → Thread} {N K p0 bA bB b g : Nat} (hN : N < 2 ^ 31) (hK : K < 2 ^ 31)
    (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    (hl : ∀ n, n / 1024 = g → Lane L c t N K p0 bA bB b g n) {m : Mem}
    (hm : Bufs N K p0 bA bB b g A B m) :
    ∃ Es m', BlockRun L c g t m Es m' ∧ m'.Buffer p0 (N * 4) 4 true ∧
      m'.Fits gevm.prog.layout p0 (N * 4) ∧ (∀ q, q ≠ p0 → q ≠ b → m'.blocks q = m.blocks q) ∧
      (∀ (who : Who) (o : Nat) (v : Val), o / 32 ≠ (L.env (1024 * g)).sreg .ctaid .x →
        m.load gevm.prog.layout who 0 (.fp .float) ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) = .ok v →
        m'.load gevm.prog.layout who 0 (.fp .float) ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) =
          .ok v) ∧
      (∃ m₁, Ext (Ev0 L c bA bB b g) m m₁ ∧ Ext (Ev1 L c b p0 g) (m₁.log (.barrier g)) m') ∧
      ∀ j : Fin N, j.val / 32 = (L.env (1024 * g)).sreg .ctaid .x → ∃ x,
        m'.load gevm.prog.layout (c (1024 * g + 32 * (j.val % 32))).who 0 (.fp .float)
          ⟨p0, ((j.val * 4 : Nat) : Int)⟩ (some 4) = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true (fun l => oG (c (1024 * g + (32 * l + j.val % 32)))
          (t (1024 * g + (32 * l + j.val % 32))).k) (vecMatPairs A B j)) := by
  have hv1 : volume L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hs : 0 < volume L.block := by rw [hv1]; decide
  have hct : ∀ n, n / 1024 = g → (L.env n).sreg .ctaid .x = (L.env (1024 * g)).sreg .ctaid .x :=
    fun n hn => by
      show coord L.grid (n / volume L.block) .x = coord L.grid (1024 * g / volume L.block) .x
      rw [hv1, hn, show 1024 * g / 1024 = g by omega]
  have htid : ∀ n, (L.env n).sreg .tid .x = n % 1024 := fun n => (Launch.tpose_env hL hx n).2.1
  obtain ⟨s, u, Es, m₁, hc, hbar, hAt, hm₁, hH, hx₀, hq₁⟩ :=
    GevmWarp0.block hL hx hN hK hK32 hKN hl hm
  obtain ⟨xb, db, _, _, hsu⟩ := id hbar
  obtain ⟨hb0, hf0, -, -, -, -, -, -, hS, hF⟩ := hm₁
  have hbp : b ≠ p0 := bufferIn_ne hS hb0.bufferIn (.inl (by decide))
  let W : Nat → Warp := fun k =>
    ⟨L, c, t, K, b, p0, fun i => Model.ofBits (word L c t N A B (1024 * g + tpose 32 i)), k, m⟩
  obtain ⟨Es', m', hr, -, -, -, hyM, hfyM, hxe, hfr, hot, hld⟩ := CanonRun.of_inv (L := L) (c := c)
    (t := fun n => (u n).resume none) (ks := blockWarps L g)
    (P := fun i M => M.BufferIn 3 b 4096 4 (.cta g) true ∧
      (∃ blk, M.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) ∧
      M.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
        (rowMajor gevm.prog.layout (.fp .float) 0)
        (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] =>
          Model.ofBits (word L c t N A B (1024 * g + tpose 32 i.1.val))) ∧
      M.Buffer p0 (N * 4) 4 true ∧ M.Fits gevm.prog.layout p0 (N * 4) ∧
      Ext (Ev1 L c b p0 g) (m₁.log (.barrier g)) M ∧
      (∀ q, q ≠ p0 → M.blocks q = (m₁.log (.barrier g)).blocks q) ∧
      (∀ (who : Who) (o : Nat) (v : Val), o / 32 ≠ (L.env (1024 * g)).sreg .ctaid .x →
        m.load gevm.prog.layout who 0 (.fp .float) ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) = .ok v →
        M.load gevm.prog.layout who 0 (.fp .float) ⟨p0, ((o * 4 : Nat) : Int)⟩ (some 4) =
          .ok v) ∧
      ∀ i' < i, ∀ h : i' < (blockWarps L g).length,
        M.load gevm.prog.layout (c (blockWarps L g)[i']).who 0 (.fp .float)
          ⟨p0, (((W (blockWarps L g)[i']).o * 4 : Nat) : Int)⟩ (some 4) =
          .ok ((W (blockWarps L g)[i']).X 5 0))
    (fun i hi M ⟨hSM, hFM, hvM, hyM, hfyM, hxM, hfrM, hotM, hldM⟩ => by
      obtain ⟨hkg, hk⟩ := (mem_blockWarps hs).1 (List.getElem_mem hi)
      rw [hv1] at hkg hk
      have hth : ∀ n ∈ warpThreads L (blockWarps L g)[i], n / 1024 = g := fun n hn => by
        have h1 := warp_base_div hs n
        rw [(warpThreads_iff hs (hv1 ▸ hk)).1 hn, hv1, hkg] at h1
        exact h1.symm
      obtain ⟨Ew, hw, hload, hfrw, hyw, hfyw⟩ := Warp.warp (w := { W (blockWarps L g)[i] with M })
        hL hx hN hK hK32 hKN (A := A) (B := B) hk (fun n hn => hl n (hth n hn)) (u := u)
        (fun n hn => ⟨[xb n], db n, (hsu n (hv1 ▸ hth n hn)).1 ▸ hAt n (hth n hn)⟩)
        hSM hFM hvM hyM hfyM
      refine ⟨Ew, _, hw, by unfold Mem.BufferIn; rw [hfrw b hbp]; exact hSM,
        by rw [hfrw b hbp]; exact hFM, hvM.of_block fun x hx => (hfrw b hbp).trans hx, hyw, hfyw,
        hxM.trans (Warp.mout_ext (w := { W (blockWarps L g)[i] with M })
          (show (blockWarps L g)[i] % 32 = 0 by omega) hkg),
        fun q hq => (hfrw q hq).trans (hfrM q hq), fun who o v ho hv => ?_, fun i' hi' h' => ?_⟩
      · refine Warp.load_mout (fun ho' => ho ?_) (hotM who o v ho hv)
        have h1 := hct _ hkg
        simp only [Warp.o, W, htid] at ho'
        omega
      rcases Nat.lt_succ_iff_lt_or_eq.1 hi' with hi' | rfl
      · refine Warp.load_mout (fun ho => ?_) (hldM i' hi' h')
        obtain ⟨hkg', hk'⟩ := (mem_blockWarps hs).1 (List.getElem_mem h')
        rw [hv1] at hkg' hk'
        have hne : (blockWarps L g)[i'] ≠ (blockWarps L g)[i] := fun e =>
          absurd ((blockWarps_nodup L g).getElem_inj.1 e) (by omega)
        have h1 := hct _ hkg
        have h2 := hct _ hkg'
        simp only [Warp.o, W, htid] at ho
        omega
      · exact hload)
    ⟨hS, hF, hH, hb0, hf0, .refl _ (m₁.log (.barrier g)), fun _ _ => rfl, fun who o v _ hv =>
      (Mem.load_of_block (hq₁ p0 (Ne.symm hbp)) _ _ _ _).trans hv,
      fun _ h => absurd h (Nat.not_lt_zero _)⟩
  refine ⟨Es ++ [.barrier g] :: Es', m', .bar hc hbar (.ends hr), hyM, hfyM,
    fun q hq hqb => (hfr q hq).trans (hq₁ q hqb), hot, ⟨m₁, hx₀, hxe⟩, fun j hj => ?_⟩
  have hkg : (1024 * g + 32 * (j.val % 32)) / 1024 = g := by omega
  have hkm : 1024 * g + 32 * (j.val % 32) ∈ blockWarps L g :=
    (mem_blockWarps hs).2 (by rw [hv1]; omega)
  obtain ⟨i, hi, hki⟩ := List.mem_iff_getElem.1 hkm
  have h1 := hld i hi hi
  have ho : (W (1024 * g + 32 * (j.val % 32))).o = j.val := by
    show (L.env (1024 * g + 32 * (j.val % 32))).sreg .ctaid .x * 32 +
      (L.env (1024 * g + 32 * (j.val % 32))).sreg .tid .x / 32 = j.val
    rw [htid, hct _ hkg]
    omega
  rw [hki, ho] at h1
  have hval : (L.env (1024 * g + 32 * (j.val % 32))).sreg .ctaid .x * 32 + j.val % 32 = j.val := by
    rw [hct _ hkg]
    omega
  have h2 := Warp.acc_nanEq (W (1024 * g + 32 * (j.val % 32))) hL hx (N := N) (g := g) (A := A)
    (B := B) (Nat.mod_lt _ (by decide)) rfl (hl _ hkg).2.2.2.2.1 fun _ _ => rfl
  simp only [W] at h2
  simp only [hval, Fin.eta] at h2
  exact ⟨_, h1, h2⟩


/-- The output columns of a memory, for every launch `L`, column count `N`, output block `p0`,
loop oracle numbers `o j` of column `j`'s warp, and inputs `A : [K]`, `B : [K, N]`: each column
`j < N` loads, by thread `32 j` of `L` (`⟨32 j, 32 j / volume L.block⟩`) at offset `4 j` of
`p0`, as a binary32 that is column `j`'s `MojoProof.Sem.warpDot true` at `o j` up to NaNs
(`NaNEq`): `MojoProof.Tile.WarpWords` at `vecMatPairs A B` and the loads of
`MojoProof.Tile.warpObs`, the premise of `MojoProofTest.GevmSpec.cols_holds`. The relation of
gevm_kernel's output. A test definition. -/
def ColsDot (L : Launch) (N p0 : Nat) {K : Nat} (o : Fin N → Nat → Nat → Nat × Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (m : Mem) : Prop :=
  MojoProof.Tile.WarpWords .float true o (vecMatPairs A B) fun j =>
    m.load gevm.prog.layout ⟨32 * j.val, 32 * j.val / volume L.block⟩ 0 (.fp .float)
      ⟨p0, ((j.val * 4 : Nat) : Int)⟩ (some 4)

/-- **gevm_kernel's blocks in turn from their entries to their ends, and every output column**
(test): for every valid launch `L` with 1024 threads per block in `x` and a one-dimensional grid
(`y` and `z` sizes 1), contexts `c` whose threads are `⟨n, n / volume L.block⟩` (the start's,
`Grid.start_ctx`), threads `t`, `N`, `K`, `A` and `B` as in `GevmWarp0.lane` with the columns
within the blocks' (`N ≤ 32 · L.grid .x`), shared arrays `sb g`, every thread `n` of a block
`n / 1024 < L.grid .x` with `Lane`'s premises at its block's shared array, and every memory `m`
with `Bufs` at every block: the blocks `0` to `volume L.grid - 1` run in turn (`PhaseRun`) from
`t` on `m` to a memory whose output columns are their `warpDot`s up to NaNs (`ColsDot`), at
column `j`'s lane `l` the loop oracle numbers of thread `1024 (j / 32) + 32 l + j % 32`. By
`PhaseRun.of_inv` with the invariant after `i` blocks: the output buffer, the blocks other than
`p0` and the first `i` shared arrays kept, and the first `i` blocks' columns (`block`; the
buffers are different blocks by space, owner or writability, `bufferIn_ne`; block `g`'s
`ctaid.x` is `g`). And if `m`'s trace is empty (the start's), every access of the last memory's
trace with its phase (`phases`) is one of `Acc`: the invariant also has `PhaseInv` of `Acc` at
the count "1 for the first `i` blocks" (`PhaseInv.ext` of `block`'s `Ev0` and `Ev1` events,
`PhaseInv.bar` at its barrier), then `PhaseInv.phases`. -/
theorem blocks {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) (hgy : L.grid .y = 1)
    (hgz : L.grid .z = 1) {c : Nat → Ctx} (hwho : ∀ n, (c n).who = ⟨n, n / volume L.block⟩)
    {t : Nat → Thread} {N K p0 bA bB : Nat} {sb : Nat → Nat} (hN : N < 2 ^ 31)
    (hK : K < 2 ^ 31) (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29) (hNg : N ≤ 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    (hl : ∀ n, n / 1024 < L.grid .x → Lane L c t N K p0 bA bB (sb (n / 1024)) (n / 1024) n)
    {m : Mem} (hm : ∀ g < L.grid .x, Bufs N K p0 bA bB (sb g) g A B m) :
    ∃ Es m', PhaseRun L c t (List.range (volume L.grid)) m Es m' ∧
      ColsDot L N p0 (fun j l => oG (c (1024 * (j.val / 32) + (32 * l + j.val % 32)))
        (t (1024 * (j.val / 32) + (32 * l + j.val % 32))).k) A B m' ∧
      (m.trace = [] → ∀ x ∈ (phases m'.trace).1, Acc L c sb bA bB p0 x.2 x.1) := by
  have hv1 : volume L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hvg : volume L.grid = L.grid .x := by simp only [volume, hgy, hgz, Nat.mul_one]
  have hct : ∀ g < L.grid .x, (L.env (1024 * g)).sreg .ctaid .x = g := fun g hg => by
    show coord L.grid (1024 * g / volume L.block) .x = g
    rw [hv1, show 1024 * g / 1024 = g by omega]
    exact Nat.mod_eq_of_lt hg
  have hG := hL.grid_pos .x
  rw [hvg]
  have hcta : ∀ n, (c n).who.cta = n / 1024 := fun n => by rw [hwho, hv1]
  obtain ⟨Es, m', hr, -, -, -, hPI, hcols⟩ := PhaseRun.of_inv (L := L) (c := c) (t := t)
    (bs := List.range (L.grid .x)) (m := m)
    (P := fun i M => M.Buffer p0 (N * 4) 4 true ∧ M.Fits gevm.prog.layout p0 (N * 4) ∧
      (∀ q, q ≠ p0 → (∀ g < i, q ≠ sb g) → M.blocks q = m.blocks q) ∧
      (m.trace = [] → PhaseInv (Acc L c sb bA bB p0) (fun j => if j < i then 1 else 0) M) ∧
      ∀ j : Fin N, j.val / 32 < i → ∃ x, M.load gevm.prog.layout
          ⟨32 * j.val, 32 * j.val / volume L.block⟩ 0 (.fp .float) ⟨p0, ((j.val * 4 : Nat) : Int)⟩
          (some 4) = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true (fun l => oG (c (1024 * (j.val / 32) + (32 * l + j.val % 32)))
          (t (1024 * (j.val / 32) + (32 * l + j.val % 32))).k) (vecMatPairs A B j)))
    (fun i hi M ⟨hyM, hfyM, hfrM, hPM, hcM⟩ => by
      rw [List.length_range] at hi
      rw [List.getElem_range]
      obtain ⟨hb0, -, hbA, hbB, -, -, -, -, hS, -⟩ := hm i hi
      have hSg : ∀ g < i, m.BufferIn 3 (sb g) 4096 4 (.cta g) true := fun g hg =>
        (hm g (by omega)).2.2.2.2.2.2.2.2.1
      have hM : Bufs N K p0 bA bB (sb i) i A B M := (hm i hi).of_blocks hyM hfyM
        (hfrM _ (bufferIn_ne hbA.bufferIn hb0.bufferIn (.inr (.inr (by decide)))) fun g hg =>
          bufferIn_ne hbA.bufferIn (hSg g hg) (.inl (by decide)))
        (hfrM _ (bufferIn_ne hbB.bufferIn hb0.bufferIn (.inr (.inr (by decide)))) fun g hg =>
          bufferIn_ne hbB.bufferIn (hSg g hg) (.inl (by decide)))
        (hfrM _ (bufferIn_ne hS hb0.bufferIn (.inl (by decide))) fun g hg =>
          bufferIn_ne hS (hSg g hg) (.inr (.inl fun e => absurd (Owner.cta.inj e) (by omega))))
      obtain ⟨Es, M', hb, hyM', hfyM', hfr', hot, ⟨m₁, hx₀, hxe⟩, hc⟩ := block hL hx hN hK hK32
        hKN (fun n hn => by rw [← hn]; exact hl n (by omega)) hM
      have hPM' : m.trace = [] →
          PhaseInv (Acc L c sb bA bB p0) (fun j => if j < i + 1 then 1 else 0) M' := fun h0 => by
        refine (((hPM h0).ext hx₀ fun e ⟨a, he, ha⟩ => ⟨a, he, ?_⟩).bar (b := i)
          (f' := fun j => if j < i + 1 then 1 else 0) fun j => ?_).ext hxe
          fun e ⟨a, n, he, hn, hwa, ha⟩ => ⟨a, he, ?_⟩
        · rcases ha with h1 | ⟨n, hn, rfl⟩
          · exact .inl h1
          · refine .inr (.inl ⟨n, by omega, ?_, by rw [hn]⟩)
            show (if (c n).who.cta < i then 1 else 0) = 0
            rw [hcta, hn, ite_eq_right (Nat.lt_irrefl i)]
        · show (if j < i + 1 then 1 else 0) =
            if i = j then (if j < i then 1 else 0) + 1 else (if j < i then 1 else 0)
          split_ifs <;> omega
        · show Acc L c sb bA bB p0 (if a.who.cta < i + 1 then 1 else 0) a
          rw [hwa, hcta, hn, ite_eq_left (Nat.lt_succ_self i)]
          rcases ha with ⟨h1, h2, h3⟩ | ⟨h32, rfl⟩
          · exact .inr (.inr (.inl ⟨by decide, h1, h2, i, hi, h3⟩))
          · exact .inr (.inr (.inr ⟨n, h32, by omega, rfl⟩))
      refine ⟨Es, M', hb, hyM', hfyM', fun q hq hqs => (hfr' q hq (hqs i (by omega))).trans
        (hfrM q hq fun g hg => hqs g (by omega)), hPM', fun j hj => ?_⟩
      rcases Nat.lt_succ_iff_lt_or_eq.1 hj with hj | hj
      · obtain ⟨x, h1, h2⟩ := hcM j hj
        exact ⟨x, hot _ _ _ (by rw [hct i hi]; omega) h1, h2⟩
      · obtain ⟨x, h1, h2⟩ := hc j (by rw [hct i hi]; exact hj)
        rw [hwho, show 1024 * i + 32 * (j.val % 32) = 32 * j.val by omega] at h1
        rw [← hj] at h2
        exact ⟨x, h1, h2⟩)
    ⟨(hm 0 hG).1, (hm 0 hG).2.1, fun _ _ _ => rfl,
      fun h0 => PhaseInv.nil _ h0 fun j => ite_eq_right (Nat.not_lt_zero j),
      fun _ h => absurd h (Nat.not_lt_zero _)⟩
  refine ⟨Es, m', hr, fun j => hcols j ?_, fun h0 => (hPI h0).phases⟩
  rw [List.length_range]
  omega

/-- **gevm_kernel from its start to a done grid with every output column** (test): for every
start (`Grid.start`) of gevm_kernel on a valid launch `L` with 1024 threads per block in `x` and
a one-dimensional grid, from arguments `[.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, x3, N, K]`
(`x3` any value, the words of `N` and `K`), memory `m`, address choice and oracle, giving grid
`g₀` and contexts `c`, with `N = 32 · L.grid .x`, `N`, `K` and the inputs `A`, `B` as in
`blocks`, `m` with `Bufs`' buffers `p0`, `bA` and `bB` (holding `A` and `B`), and address
choices whose shared arrays' blocks fit below `2 ^ 32` (`hch`, the admission of the kernel's
theorem): `g₀` steps (`Grid.Step`) to a done grid (`GPUProof.Done` at `sig`) whose memory has
`ColsDot`, and shared arrays `sb g` of the blocks of threads `g` (`g₀.mem.ctaOf (sb g) = g`)
such that every access of the done grid's trace with its phase is one of `Acc` (`blocks`' last
conjunct at the start's empty trace, `Grid.start_trace`). `Lane` from the start: the contexts'
program, registers and threads by
`Grid.start_ctx`, the entry frames by `Grid.start_thread`, the registers by `Grid.start_scalar`
(each parameter is `noundef`) and the shared array's table entry by `Grid.start_shared`; the
buffers on `g₀`'s memory by `Grid.start_blocks` and the shared arrays' blocks by
`Grid.start_shared` (its `sharedBlock`: 4096 bytes, aligned to 4, owned by its block of
threads, at address `ch (Nat.pair (g + 2) 2) * 4 % 2 ^ 32`); then `blocks` and
`PhaseRun.start_done`. -/
theorem grid {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start gevm.prog gevm.fn_0 L args m ch oracle = .ok (g₀, c)) (hL : L.Valid)
    (hx : L.block .x = 1024) (hgy : L.grid .y = 1) (hgz : L.grid .z = 1)
    {N K p0 bA bB : Nat} {x3 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bB, 0⟩, x3, .bits 32 (BitVec.ofNat 32 N),
      .bits 32 (BitVec.ofNat 32 K)])
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
    (hch : ∀ g < L.grid .x, ch (Nat.pair (g + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step L c) i g₀ z) ∧ GPUProof.Done sig (z, L, c) ∧
      ColsDot L N p0 (fun j l => oG (c (1024 * (j.val / 32) + (32 * l + j.val % 32)))
        (Grid.thread g₀ (1024 * (j.val / 32) + (32 * l + j.val % 32))).k) A B z.mem ∧
      ∃ sb : Nat → Nat, (∀ g < L.grid .x, g₀.mem.ctaOf (sb g) = some g) ∧
        ∀ x ∈ (phases z.mem.trace).1, Acc L c sb bA bB p0 x.2 x.1 := by
  have hv1 : volume L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hvg : volume L.grid = L.grid .x := by simp only [volume, hgy, hgz, Nat.mul_one]
  obtain ⟨sb, hsh, hS, -⟩ := Grid.start_shared h (i := 0) (List.getElem?_eq_getElem (by decide))
    rfl (by decide)
  have hl : ∀ n, n / 1024 < L.grid .x →
      Lane L c (Grid.thread g₀) N K p0 bA bB (sb (n / 1024)) (n / 1024) n := fun n hn => by
    have hct : (L.env n).sreg .ctaid .x = n / 1024 := by
      show coord L.grid (n / volume L.block) .x = n / 1024
      rw [hv1]
      exact Nat.mod_eq_of_lt hn
    have hn' : n < g₀.threads.size := by
      rw [Grid.start_size h, hvg, hv1]
      omega
    obtain ⟨f, hgt, hfn, hlb, hpc, hal⟩ := Grid.start_thread h hn'
    have hf : (Grid.thread g₀ n).frames = [f] := by rw [hgt]
    have hg : (c n).globals sharedName = some ⟨sb (n / 1024), 0⟩ := by
      have := hsh n (by rw [hv1, hvg]; exact hn)
      rw [hv1] at this
      exact this
    refine ⟨(Grid.start_ctx h n).1, (Grid.start_ctx h n).2.2.1, hg, ?_, by omega,
      f, hf, hfn, Option.some.inj (hlb.symm.trans rfl), hpc, hal, ?_, ?_, ?_, ?_, ?_⟩
    · simp only [(Grid.start_ctx h n).2.1, Owner.admits, hv1, beq_self_eq_true]
    · exact Grid.start_scalar h hn' hf (i := 0) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar h hn' hf (i := 1) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar h hn' hf (i := 2) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar h hn' hf (i := 4) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
    · exact Grid.start_scalar h hn' hf (i := 5) rfl rfl rfl rfl (by rw [ha]; rfl) fun _ => rfl
  have hk : ∀ q x, m.blocks q = some x → g₀.mem.blocks q = some x := fun _ _ => Grid.start_blocks h
  have hm : ∀ g < L.grid .x, Bufs N K p0 bA bB (sb g) g A B g₀.mem := fun g hg =>
    ⟨hb0.of_block (hk _), hf0.of_block (hk _), hbA.of_block (hk _), hbB.of_block (hk _),
      hfA.of_block (hk _), hfB.of_block (hk _), hA.of_block (hk _), hB.of_block (hk _),
      ⟨_, hS g (by rw [hvg]; exact hg), rfl, rfl, rfl, rfl, show 4096 ≤ 4096 from Nat.le_refl _,
        show 4 ∣ ch (Nat.pair (g + 2) 2) * 4 % 2 ^ 32 by omega,
        show 4 ∣ ch (Nat.pair (g + 2) 3) * 4 % 2 ^ 64 by omega⟩,
      _, hS g (by rw [hvg]; exact hg), show ch (Nat.pair (g + 2) 2) * 4 % 2 ^ 32 + 4096 ≤ 2 ^ 32
        from hch g hg⟩
  obtain ⟨Es, m', hr, hC, hP⟩ := blocks hL hx hgy hgz (fun n => (Grid.start_ctx h n).2.1) hN hK
    hK32 hKN hNg.le hl hm
  obtain ⟨z, hp, hd, rfl⟩ := PhaseRun.start_done h (by rw [hv1]; decide) hr
  refine ⟨z, hp, hd, hC, sb, fun g hg => ?_, hP (Grid.start_trace h)⟩
  unfold Mem.ctaOf
  rw [hS g (by rw [hvg]; exact hg)]
  rfl

end MojoProofTest.GevmWarp1
