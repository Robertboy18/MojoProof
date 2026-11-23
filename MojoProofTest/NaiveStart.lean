import MojoProofTest.NaiveKernel
import MojoProofTest.NaiveOff

/-!
# The naive kernel's threads at an evaluated start with a row

`NaiveIn.runIn` and `NaiveOut.runOut` at a start of `naive` that the kernel evaluates, at a
launch with threads in and out of bounds and a caller's memory of the sizes `NaiveSpec.At` asks:
`naive` on one block of 2 × 2 threads (`NaiveKernel.L12`) with `m = 1`, `n = 2`, every `K ≤ 768`,
the memory `NaiveKernel.mem12 A B` for every `A` (`1 × 768`) and `B` (`2 × 768`), block 1 (`C`,
row stride 50257, `50257 * 4` bytes, writable), blocks 2 and 3 holding `A` and `B` (`768 * 4`
bytes a row, read-only), the address choice 0 and every oracle `ω`.

* `start12`: the launch starts, for every `K` (no bound on it), evaluated by the kernel
  (`kernel_rfl`) with `A`, `B`, `K` and `ω` variables and the start's check of the caller's
  memory in place: the check reads each byte of `C` (201,028, undefined), `A` (3,072) and `B`
  (6,144), those of `A` and `B` through the tree of their lists (`ByteTree`). The evaluation
  goes through `Mem.compact` at the bytes of `C`.
* `check12`: the memory meets `Mat.Pre` (`NaiveKernel.pre12`), so the start's check of it
  passes (`Mem.checkClosed_of_closed`), for every `K ≤ 768`. The other evaluations of the start
  (`eval12`) rewrite the check by it, so that the kernel does not read the bytes again for each.
* `trace12`: at every start `g`, `c` of the launch the memory's trace is empty, by
  `Grid.start_trace`, which holds for every start.
* `facts12`: at every start `g`, `c` of the launch, for each thread its one frame (`fr`), its
  registers `%0` to `%5`, the loads of its copies of the three structs, and the frame's function,
  label, position and `alloca`s, by evaluation.
* `at12`: `NaiveSpec.At` at every thread, on every memory of `Elem` from the start's memory after
  the threads before it: the frames and loads from `facts12`, the context from `Grid.start_ctx`,
  and the buffers and tensors from `Mat.pre_mem`, `Grid.start_blocks` and `Elem.start_block`.
* `runs12`: every thread runs to its end (`Runs`) from such a memory, leaving one of `Elem` after
  one more thread: threads 0 and 2 (row 0, in bounds) by `NaiveIn.runIn` and
  `Runs.of_chainsWith`, threads 1 and 3 (row 1, out of bounds) by `NaiveOut.runOut` and
  `Runs.of_retWith`; `first12` is the start and thread 0 from the start's memory itself.
* `obs12`: `Kernel.Sound.exists_obs` at `NaiveKernel.sound12`, at every address choice and
  oracle: a complete run (`Kernel.Obs`) whose observation meets the relation. `cells12`:
  `NaiveKernel.read12` at that observation, its premise discharged, so the cells of row 0 of `C`
  are those of a run that exists.
* `soundOff12`, `obsOff12`: `NaiveOff.correct` at this launch and memory with `K = 768`, its
  `Mat.Pre` by `NaiveKernel.pre12`: the corpus kernel compiled with contraction off is sound for
  `Elem.Out` of `naive`'s bytes at the rows `neverFuse (ω k)`, and has such an observation at
  every address choice and oracle family (`Kernel.Sound.exists_obs`).

The theorems about a start take its equation `hs` and evaluate the start itself, not the grid:
`of_start` moves a fact about the start's value to `g` and `c`, so the kernel reduces
`Grid.start` only after `eval12` has unfolded it and rewritten its check. Unfolding a name for
the grid instead makes both the elaborator and the kernel reduce the start with the check in
place.
For this program, launch, memory (every `A` and `B`) and address choice only; `obs12`,
`cells12`, `soundOff12` and `obsOff12` are for every address choice (`soundOff12` and `obsOff12`
for the program compiled with contraction off).
-/

namespace MojoProofTest.NaiveStart

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread MojoProofTest.NaiveSpec MojoProofTest.NaiveIn MojoProofTest.NaiveOut
  MojoProofTest.NaiveKernel MojoProofTest.SymInfo.mgemm_nocontract
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

-- `Array.any` recurses by well-founded recursion, so the kernel cannot evaluate a start without
-- this.
unseal Array.anyM.loop

/-- **The start's check of the caller's memory passes**, for every `A`, `B` and `K ≤ 768`: the
memory is closed (`NaiveKernel.pre12`, `Mem.checkClosed_of_closed`). For this program, launch,
memory and address choice only. -/
theorem check12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768) :
    (mem12 A B).checkClosed (Mat.args z 1 2 3 1 2 K) = .ok () :=
  Mem.checkClosed_of_closed (pre12 A B hK).closed

/-- Closes an equation about the start of `naive` on `L12` at `mem12 A B` by the kernel's
evaluation (`kernel_rfl`), once the start (`Grid.start`) is unfolded and its check of the
caller's memory rewritten by `check12` at the hypothesis `hK : K ≤ 768`. -/
local macro "eval12" hK:term : tactic =>
  `(tactic| (rewrite [Grid.start, check12 _ _ $hK]; kernel_rfl))

/-- A fact `P g c = Q g c` at a start `e = .ok (g, c)` from the same fact under `e`'s value, which
the kernel evaluates on `e` itself (`eval12`), not on `g` and `c`. -/
theorem of_start {α : Type} {P Q : Grid → (Nat → Ctx) → α} {e : Except Fault (Grid × (Nat → Ctx))}
    {g : Grid} {c : Nat → Ctx} (hs : e = .ok (g, c))
    (h : (e.toOption.map fun r => P r.1 r.2) = e.toOption.map fun r => Q r.1 r.2) :
    P g c = Q g c := by
  subst hs
  exact Option.some.inj h

/-- **The launch starts**, for every `A`, `B`, `K` and oracle `ω`: the start returns a grid and
contexts (`.ok`). The kernel evaluates it with its check of the caller's memory in place. For this
program, launch, memory and address choice only. -/
theorem start12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (K : Nat) (ω : Nat → Nat → Nat) :
    ∃ g c, Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B)
      (fun _ => 0) ω = .ok (g, c) := by
  have hb : (Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B)
      (fun _ => 0) ω).toBool = true := by
    rewrite [Grid.start]; kernel_rfl
  revert hb
  cases Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B) (fun _ => 0) ω
    with
  | ok r => exact fun _ => ⟨r.1, r.2, rfl⟩
  | error e => exact fun hb => nomatch hb

/-- Thread `k`'s first frame in the grid `g` (a frame of `naive`'s function if it has none). -/
def fr (g : Grid) (k : Nat) : Frame :=
  ((Grid.thread g k).frames.head?).getD ⟨naive.fn_0, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- **The start's memory has an empty trace**, for every `A`, `B`, `K`, oracle `ω` and start `g`,
`c` of the launch: `Grid.start_trace`, which holds for every start, at this program, launch,
memory and address choice. -/
theorem trace12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat}
    (ω : Nat → Nat → Nat) {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B) (fun _ => 0) ω =
      .ok (g, c)) : g.mem.trace = [] :=
  Grid.start_trace hs

/-- **Thread `k`'s entry, evaluated** (`of_start`, `eval12`), for every `A`, `B`, `K ≤ 768`,
oracle, start `g`, `c` of the launch and thread `k < 4`: the thread has the one frame `fr g k` and
step count 0; the frame is of `naive`'s function, at the label of its first block (that of
`skipN`'s first block too), position 0, with no `alloca`s; its registers `%0`, `%1`, `%2` point at
offset 0 of the blocks `5 + 3 k`, `6 + 3 k`, `7 + 3 k`, the thread's copies of the three structs,
and `%3`, `%4`, `%5` are the words of 1, 2 and `K`; and the copies load as the structs of blocks 1,
2 and 3. For this program, launch, memory and address choice only. -/
theorem facts12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768)
    (ω : Nat → Nat → Nat) {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B) (fun _ => 0) ω =
      .ok (g, c)) {k : Nat} (hk : k < 4) :
    ((Grid.thread g k).frames, (Grid.thread g k).k, (fr g k).fn,
      naive.fn_0.blocks[0]?.map (·.label), skipN.head?.map (·.1), (fr g k).pc, (fr g k).allocas,
      (fr g k).regs (idx "0"), (fr g k).regs (idx "1"), (fr g k).regs (idx "2"),
      (fr g k).regs (idx "3"), (fr g k).regs (idx "4"), (fr g k).regs (idx "5"),
      g.mem.load naive.prog.layout (c k).who 0 T ⟨5 + 3 * k, 0⟩ (some 8),
      g.mem.load naive.prog.layout (c k).who 0 T ⟨6 + 3 * k, 0⟩ (some 8),
      g.mem.load naive.prog.layout (c k).who 0 T ⟨7 + 3 * k, 0⟩ (some 8)) =
    ([fr g k], 0, naive.fn_0, some (fr g k).label, some (fr g k).label, 0, [],
      some (.ptr ⟨5 + 3 * k, 0⟩), some (.ptr ⟨6 + 3 * k, 0⟩), some (.ptr ⟨7 + 3 * k, 0⟩),
      some (.bits 32 (BitVec.ofNat 32 1)), some (.bits 32 (BitVec.ofNat 32 2)),
      some (.bits 32 (BitVec.ofNat 32 K)), .ok (.agg [.ptr ⟨1, 0⟩, z]),
      .ok (.agg [.ptr ⟨2, 0⟩, z]), .ok (.agg [.ptr ⟨3, 0⟩, z])) := by
  apply of_start hs
  obtain rfl | rfl | rfl | rfl : k = 0 ∨ k = 1 ∨ k = 2 ∨ k = 3 := by omega
  all_goals eval12 hK

/-- **`At` at every thread of a start**, for every `A`, `B`, `K ≤ 768`, oracle `ω`, start `g`, `c`
of the launch, thread `k < 4` and memory `m'` of `Elem` after `k` threads from the start's memory
(output block 1, any cell width, cells and bytes): the launch, sizes and context as `At` asks, the
struct copies `5 + 3 k`, `6 + 3 k`, `7 + 3 k` of `facts12` (block 1 is not among them, so `m'`
loads them as the start's memory does), and the buffers of `mem12 A B` (`Mat.pre_mem`), which the
start keeps (`Grid.start_blocks`) and `Elem` keeps but for block 1 (`Elem.start_block`), whose
sizes and fit `Elem` keeps (`Elem.buffer`, `Elem.fits`). For this program, launch, memory and
address choice only. -/
theorem at12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768)
    (ω : Nat → Nat → Nat) {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B) (fun _ => 0) ω =
      .ok (g, c)) {k : Nat} (hk : k < 4) {w : Nat} {cl : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {m' : Mem} (hE : Elem g.mem 1 w cl bs k m') :
    At L12 K 1 2 3 (5 + 3 * k) (6 + 3 * k) (7 + 3 * k) A B k (c k) m' (fr g k) := by
  have pre := pre12 A B hK
  have hb : ∀ q, q ≠ 1 → ∀ x, (mem12 A B).blocks q = some x → m'.blocks q = some x :=
    fun _ hq => Elem.start_block hs hE hq
  have hc := Grid.start_ctx hs k
  have h := facts12 A B hK ω hs hk
  simp only [Prod.mk.injEq] at h
  obtain ⟨-, -, hfn, -, -, -, -, h0, h1, h2, h3, h4, h5, l0, l1, l2⟩ := h
  have ld : ∀ q, q ≠ 1 → ∀ v, g.mem.load naive.prog.layout (c k).who 0 T ⟨q, 0⟩ (some 8) = v →
      m'.load naive.prog.layout (c k).who 0 T ⟨q, 0⟩ (some 8) = v :=
    fun q hq _ e => (Mem.load_of_block (p := ⟨q, 0⟩) (hE.rest q hq) _ _ _ _).trans e
  exact ⟨validZ, ⟨rfl, rfl⟩, ⟨by decide, hK, by decide, by decide, by decide⟩,
    hk.trans_eq (by decide), ⟨hc.1, hc.2.2.1, hc.2.1⟩, hfn,
    ⟨h0, h1, h2, by omega, by omega, by omega⟩,
    ⟨ld _ (by omega) _ l0, ld _ (by omega) _ l1, ld _ (by omega) _ l2⟩, ⟨h3, h4, h5⟩, by decide,
    ⟨pre.bufs.1.of_block (hb 2 (by decide)), pre.fits.1.of_block (hb 2 (by decide)),
      pre.x.of_block (hb 2 (by decide))⟩,
    ⟨pre.bufs.2.1.of_block (hb 3 (by decide)), pre.fits.2.1.of_block (hb 3 (by decide)),
      pre.y.of_block (hb 3 (by decide))⟩,
    ⟨hE.buffer (pre.bufs.2.2.of_block fun _ => Grid.start_blocks hs),
      hE.fits (pre.fits.2.2.of_block fun _ => Grid.start_blocks hs)⟩⟩

/-- **Every thread of a start runs to its end**, for every `A`, `B`, `K ≤ 768`, oracle `ω`, start
`g`, `c` of the launch, thread `k < 4` and memory `m'` of `Elem` after `k` threads from the start's
memory (block 1, cells `cell L12` 4 bytes wide, bytes `bytes ω L12 K A B`) whose accesses to block
1 are by threads in bounds: thread `k` runs from its start (`Runs`, context `c k`, from `m'`) to a
memory of `Elem` after `k + 1` threads whose accesses to block 1 are by threads in bounds. Threads
0 and 2 (row 0) are in bounds and run `chainN` (`NaiveIn.runIn`, `Runs.of_chainsWith`); threads 1
and 3 (row 1) are not and run `skipN` (`NaiveOut.runOut`, `Runs.of_retWith`). For this program,
launch, memory and address choice only. -/
theorem runs12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768)
    (ω : Nat → Nat → Nat) {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B) (fun _ => 0) ω =
      .ok (g, c)) {k : Nat} (hk : k < 4) {m' : Mem}
    (hE : Elem g.mem 1 4 (cell L12) (bytes ω L12 K A B) k m') (hO : Elem.Only 1 (S L12 1 2) m') :
    ∃ m'', Runs (c k) (Grid.thread g k) m' m'' ∧
      Elem g.mem 1 4 (cell L12) (bytes ω L12 K A B) (k + 1) m'' ∧ Elem.Only 1 (S L12 1 2) m'' := by
  have hc := Grid.start_ctx hs k
  have hAt := at12 A B hK ω hs hk hE
  have h := facts12 A B hK ω hs hk
  simp only [Prod.mk.injEq] at h
  obtain ⟨ht, hk0, hfn, hl, hl', hp, ha, -⟩ := h
  by_cases hS : S L12 1 2 k
  · obtain ⟨C, hC, h⟩ := runIn ω L12 K 1 2 3 A B k _ _ _ _ _ m' _ hS hc.2.2.2 hAt hE hO
    refine Runs.of_chainsWith hc.1 chainN_covers ht hfn hl hp ha ⟨C, hC, ?_⟩
    rw [hk0]
    exact h
  · obtain ⟨ps, hps, h⟩ := runOut ω L12 K 1 2 3 A B k _ _ _ _ _ m' _ hS hAt hE hO
    rw [List.mem_singleton] at hps
    subst hps
    refine Runs.of_retWith hc.1 skipN_covers ht hfn hl' hp ha ?_
    rw [hk0]
    exact h

/-- **The launch starts and thread 0 runs from the start's memory**, for every `A`, `B`,
`K ≤ 768` and oracle `ω`: the start evaluates to a grid and contexts (`start12`), whose memory
meets `Elem` after no thread (its trace is empty, `trace12`, `Elem.zero`) and has no access, so
thread 0 runs from it to a memory of `Elem` after one thread (`runs12`). For this program,
launch, memory and address choice only. -/
theorem first12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) {K : Nat} (hK : K ≤ 768)
    (ω : Nat → Nat → Nat) :
    ∃ g c, Grid.start naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 K) (mem12 A B)
      (fun _ => 0) ω = .ok (g, c) ∧ ∃ m'', Runs (c 0) (Grid.thread g 0) g.mem m'' ∧
        Elem g.mem 1 4 (cell L12) (bytes ω L12 K A B) 1 m'' ∧ Elem.Only 1 (S L12 1 2) m'' := by
  obtain ⟨g, c, hs⟩ := start12 A B K ω
  refine ⟨g, c, hs, runs12 A B hK ω hs (by decide) (Elem.zero (trace12 A B ω hs)) ?_⟩
  intro a ha
  rw [trace12 A B ω hs] at ha
  cases ha

/-- **`sound12` has an observation**, for every `A`, `B`, oracle `ω` and address choice `ch`: some
complete run of `naive` on `L12` at `mem12 A B` under `ch` and `ω` (`Kernel.Obs`) observes blocks
`Bk`, and `Bk` meets `Elem.Out` of the naive bytes (`Kernel.Sound.exists_obs` at `sound12`).
For this program, launch and memory only. -/
theorem obs12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk ∧
      Elem.Out (mem12 A B) 1 (cell L12) (bytes ω L12 768 A B) (volume L12.grid * volume L12.block)
        Bk :=
  (sound12 A B ω).exists_obs rfl

/-- **`read12` at an observation that exists**, for every `A`, `B`, oracle `ω` and address choice
`ch`: some complete run of `naive` on `L12` at `mem12 A B` observes blocks `Bk` (`obs12`) whose
block 1 is some `y` with cells `c = 0, 1` (row 0) read by one thread `k` each, of row 0 and
column `c`, whose 4 bytes at offset `c * 4` encode `dotLoop` with `fmul contract` under
`o (ω k)` from `+0` over `pairs A B 0 c 768` (`read12`, its premise discharged). For this program,
launch and memory only. -/
theorem cells12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs naive.prog naive.fn_0 L12 (Mat.args z 1 2 3 1 2 768) (mem12 A B)
      (fun m => some m.blocks) ch ω Bk ∧
      ∃ y, Bk 1 = some y ∧ ∀ c (hc : c < 2), ∃ k < 4, L12.index k .x = 0 ∧ L12.index k .y = c ∧
        naive.prog.layout.encode (.fp .float) (.ofFloat .float
          (dotLoop true (o (ω k)) (Model.zero _ false) (pairs A B 0 ⟨c, hc⟩ 768))) =
          some (y.read (c * 4) 4) :=
  let ⟨Bk, hB, _⟩ := obs12 A B ω ch
  ⟨Bk, hB, read12 A B ω hB⟩

/-- **`NaiveOff.correct` at a concrete memory with two threads in bounds**: for every `A`
(`1 × 768`), `B` (`2 × 768`) and oracle family `ω`, the corpus kernel compiled with contraction
off, on `L12` at `m = 1`, `n = 2`, `K = 768` and `mem12 A B` under `ω`, is sound for `Elem.Out` of
`naive`'s bytes at the never-fusing rows `neverFuse (ω k)`; `Mat.Pre` is `pre12`. It is `sound12`
for that program, and covers this one launch and memory. -/
theorem soundOff12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) :
    Kernel.Sound g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog
      g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.fn_0 L12
      (Mat.args z 1 2 3 1 2 768) (mem12 A B) (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out (mem12 A B) 1 (cell L12) (bytes (fun k => neverFuse (ω k)) L12 768 A B)
        (volume L12.grid * volume L12.block)) :=
  NaiveOff.correct NaiveOut.validZ ⟨rfl, rfl⟩ (pre12 A B le_rfl)

/-- **`soundOff12` has an observation**, for every `A`, `B`, oracle family `ω` and address choice
`ch`: some complete run of the corpus kernel compiled with contraction off on `L12` at
`mem12 A B` under `ch` and `ω` (`Kernel.Obs`) observes blocks `Bk`, and `Bk` meets `Elem.Out` of
`naive`'s bytes at the rows `neverFuse (ω k)` (`Kernel.Sound.exists_obs` at `soundOff12`). For
this program, launch and memory only. -/
theorem obsOff12 (A : Tensor (Model FloatTy.float.fmt) [1, 768])
    (B : Tensor (Model FloatTy.float.fmt) [2, 768]) (ω : Nat → Nat → Nat) (ch : Nat → Nat) :
    ∃ Bk, Kernel.Obs g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.prog
      g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.fn_0 L12
      (Mat.args z 1 2 3 1 2 768) (mem12 A B) (fun m => some m.blocks) ch ω Bk ∧
      Elem.Out (mem12 A B) 1 (cell L12) (bytes (fun k => neverFuse (ω k)) L12 768 A B)
        (volume L12.grid * volume L12.block) Bk :=
  (soundOff12 A B ω).exists_obs rfl

end MojoProofTest.NaiveStart
