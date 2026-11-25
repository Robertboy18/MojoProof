import MojoProof.Sem.Shared
import MojoProof.Sem.Transpose
import MojoProofTest.WarpDot

/-!
# The transposition through shared memory at two threads, one trace and one column

Tests of MojoProof/Sem/Transpose.lean, one example each, at two block sizes for the threads and
the barrier.
* `thread1061`: the launch `launch2 2 1 1024 1` of grid (2, 1, 1) and block (1024, 1, 1), valid
  (`valid2k`), and its thread 1061, thread 37 of block 1 (warp 1, lane 5). By `Launch.warps_env`,
  its lane number is 5 and it stores to cell `tpose 32 37 = 161`; the cell 37 that it loads after
  the barrier is the one thread 161 (warp 5, lane 1) stores to (`tpose 32 161 = 37`), and thread 161
  is the one thread below 1024 that stores there (`tpose_bijOn`).
* `racy4`: the instance of `racy_tpose` at `n = 2` and cells of 1 byte, on the trace `tr4` of the
  4 threads of block of threads 0: thread `k` writes byte `tpose 2 k` of block 0, a barrier, and
  thread `k` reads byte `k`. The trace has no race.
* `thread293`: the same at a second block size, thread 293 of `launch2 2 1 256 1` (grid (2, 1, 1),
  block (256, 1, 1), valid by `valid256`), thread 37 of block 1, by `Launch.warps_env` at `W = 8`.
* `sound_tpose`: the instance of `Grid.sound_cells` at the cell map `tpose 32` (injective on
  `[0, volume L.block)`, since a valid block has at most `32 · 32` threads) and cells of `w`
  bytes, for every cell width `w` on every valid launch: a run in which each thread writes,
  before its block's first barrier, the `w` bytes of shared memory at its transposed cell, reads
  after it, and keeps to its own tile elsewhere, decides every schedule. `sound1024` is its
  instance at `w = 4` with `ntid.x = 1024` (`Launch.tpose_env`), `sound256` at `w = 2` on
  `launch2 2 1 256 1`. That gevm_kernel's runs have this access pattern is not proved here.
* `col40`: the instance of `warpDot_tpose` at binary32, without the `contract` flag, under the
  oracle numbers `(0, 0)`, with every lane's pairs `wd40` (MojoProofTest/WarpDot.lean) and the
  array `M40` that the 1024 threads' stores leave: warp 5's rounds over the cells it loads give
  `2 ^ 24 + 38`, the word of `vals40`.
-/

namespace MojoProofTest.Transpose

open MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange
open GPUProof (Path)
open MojoProofTest.WarpDot (wd40 vals40)

/-- The launch of grid (2, 1, 1) and block (1024, 1, 1) is valid. -/
theorem valid2k : (launch2 2 1 1024 1).Valid := launch2_valid (by decide)

/-- **Thread 1061 of `launch2 2 1 1024 1`**, a test of one example: thread 37 of block 1 has lane
number 5 and stores to cell 161 (`Launch.warps_env` at `W = 32`); cell 37, which it loads, is thread
161's cell, and no other thread of the block stores there (`tpose_bijOn`). -/
theorem thread1061 :
    ((launch2 2 1 1024 1).env 1061).sreg .tid .x = 37 ∧
      ((launch2 2 1 1024 1).env 1061).laneid = 5 ∧
      32 * ((launch2 2 1 1024 1).env 1061).laneid +
        ((launch2 2 1 1024 1).env 1061).sreg .tid .x / 32 = 161 ∧ tpose 32 161 = 37 ∧
      ∀ t < 1024, tpose 32 t = 37 → t = 161 := by
  obtain ⟨ht, hl, hc⟩ := Launch.warps_env (L := launch2 2 1 1024 1) (W := 32) rfl 1061
  refine ⟨ht.trans (by decide), hl.trans (by decide), hc.trans (by decide), by decide,
    fun t h e => (tpose_bijOn 32).injOn h (by decide : 161 < 1024) ?_⟩
  rw [e]
  decide

/-- The launch of grid (2, 1, 1) and block (256, 1, 1), 8 warps per block, is valid. -/
theorem valid256 : (launch2 2 1 256 1).Valid := launch2_valid (by decide)

/-- **Thread 293 of `launch2 2 1 256 1`**, a test of one example at a second block size: thread 37
of block 1 has `tid.x = 37`, lane number 5 and stores to cell 161 (`Launch.warps_env` at `W = 8`),
and the cells `tpose 32 t` of the block's threads `t < 256` are distinct (`tpose_tpose`). -/
theorem thread293 :
    ((launch2 2 1 256 1).env 293).sreg .tid .x = 37 ∧ ((launch2 2 1 256 1).env 293).laneid = 5 ∧
      32 * ((launch2 2 1 256 1).env 293).laneid +
        ((launch2 2 1 256 1).env 293).sreg .tid .x / 32 = 161 ∧
      ∀ t < 256, ∀ u < 256, tpose 32 t = tpose 32 u → t = u := by
  obtain ⟨ht, hl, hc⟩ := Launch.warps_env (L := launch2 2 1 256 1) (W := 8) rfl 293
  refine ⟨ht.trans (by decide), hl.trans (by decide), hc.trans (by decide), fun t h u hu e => ?_⟩
  rw [← tpose_tpose (n := 32) (by omega : t < 32 * 32), e, tpose_tpose (n := 32) (by omega)]

/-- An access by thread `k` of block of threads 0 to byte `off` of block 0. -/
def acc4 (k off : Nat) (write : Bool) : Access :=
  ⟨⟨k, 0⟩, ⟨0, off⟩, 1, write, none, false⟩

/-- The trace, newest first: thread `k < 4` writes byte `tpose 2 k` (bytes 0, 2, 1, 3), a barrier
of block of threads 0, and thread `k` reads byte `k`. -/
def tr4 : List Event :=
  [.access (acc4 3 3 false), .access (acc4 2 2 false), .access (acc4 1 1 false),
    .access (acc4 0 0 false), .barrier 0, .access (acc4 3 3 true), .access (acc4 2 1 true),
    .access (acc4 1 2 true), .access (acc4 0 0 true)]

/-- The accesses of `tr4` with their phases: the reads in phase 1, the writes in phase 0. -/
theorem phases_tr4 : (phases tr4).1 =
    [(acc4 3 3 false, 1), (acc4 2 2 false, 1), (acc4 1 1 false, 1), (acc4 0 0 false, 1),
      (acc4 3 3 true, 0), (acc4 2 1 true, 0), (acc4 1 2 true, 0), (acc4 0 0 true, 0)] := by
  decide +kernel

/-- **The instance of `racy_tpose`**, a test of one example: block 0 is block of threads 0's
shared array, every access is by a thread of block of threads 0, the writes of phase 0 are each
thread's transposed byte and the accesses of phase 1 are reads, so `tr4` has the premises of
`racy_iff` at `launch2 1 1 4 1` (`Trace.fits_of_check`) and no race. -/
theorem racy4 : GPUProof.racy sig (tr4.map (Event.toCore (launch2 1 1 4 1))).reverse = false := by
  obtain ⟨hU, hs⟩ := Trace.fits_of_check (L := launch2 1 1 4 1) (tr := tr4) (by decide +kernel)
  refine racy_tpose hU hs (n := 2) (w := 1) (by decide)
    (ofSh := fun b => if b = 0 then some 0 else none)
    (G := fun _ => none) (fun x hx β hβ => ?_) fun x hx hb => ?_ <;>
    rw [phases_tr4] at hx <;> simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  · rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      (simp only [acc4, ↓reduceIte, Option.some.injEq] at hβ; subst hβ; decide)
  · rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp [acc4] at hb

/-- **The transposed cells' barrier on every valid launch**, the instance of `Grid.sound_cells`
at the cell map `tpose 32` (injective on `[0, volume L.block)`, since a valid block has at most
`1024 = 32 · 32` threads, `tpose_tpose`) and cells of `w` bytes, for every cell width `w`: for every
program, kernel, valid launch (every block size), arguments, address choice and oracle, on a
caller's memory every pointer byte of whose blocks names a number below `next` or with a block,
and every observation `obs` that reads only the blocks: one run from the start's grid to a grid
`z` in which every thread has returned, in whose trace every access by a thread `k` to a block of
threads' shared memory is, before its block's first barrier, the `w` bytes at
`tpose 32 (k % volume L.block) * w` and after it a read, every access to another block follows
`G` with each thread its own tile, no access with `!invariant.load` is to a block that a write
touches, and whose observation is `y` with `R y`, makes the start's grid sound. The premise
`0 < volume L.block` is `Launch.Valid.volume_pos`. -/
theorem sound_tpose {prog : MojoProof.LLVM.Program} {fn : MojoProof.LLVM.Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid}
    {c : Nat → Ctx} (hL : L.Valid) (w : Nat)
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → x.1.ptr.off = ((tpose 32 (x.1.who.thread % volume L.block) * w : Nat) : Int) ∧
        x.1.len = w) ∧ (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  have hv := hL.threads
  Grid.sound_cells h hm hB run hz (w := w) (cell := tpose 32) hL.volume_pos
    (fun i hi j hj e => by
      rw [← tpose_tpose (n := 32) (by omega : i < 32 * 32), e,
        tpose_tpose (n := 32) (by omega : j < 32 * 32)])
    (fun x hx b e => by
      obtain ⟨h0, h1⟩ := hS x hx b e
      refine ⟨fun hp => ?_, h1⟩
      obtain ⟨ho, hl⟩ := h0 hp
      rw [ho, hl]
      push_cast
      omega) hG hI hy hR

/-- **gevm_kernel's barrier on every launch of 1024 threads per block**, `sound_tpose` at `w = 4`
on a valid launch with `ntid.x = 1024`, whose blocks have 1024 threads (`Launch.tpose_env`): each
thread's shared accesses before the barrier are the 4 bytes at `tpose 32 (k % 1024) * 4` (the
kernel's `%62`) and reads after it; the other premises are `sound_tpose`'s. -/
theorem sound1024 {prog : MojoProof.LLVM.Program} {fn : MojoProof.LLVM.Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid}
    {c : Nat → Ctx} (hL : L.Valid) (hx : L.block .x = 1024)
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : GPUProof.Done sig (z, L, c))
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → x.1.ptr.off = ((tpose 32 (x.1.who.thread % 1024) * 4 : Nat) : Int) ∧
        x.1.len = 4) ∧ (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  sound_tpose hL 4 h hm hB run hz (by rwa [(Launch.tpose_env hL hx 0).1]) hG hI hy hR

/-- **`sound_tpose` at a second size**: on `launch2 2 1 256 1` (blocks of 256 threads) with cells of
2 bytes, each thread's shared accesses before the barrier are the 2 bytes at
`tpose 32 (k % 256) * 2` and reads after it (`launch2 2 1 256 1`'s block volume is 256 by `decide`);
the other premises are `sound_tpose`'s. -/
theorem sound256 {prog : MojoProof.LLVM.Program} {fn : MojoProof.LLVM.Func}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid}
    {c : Nat → Ctx} (h : Grid.start prog fn (launch2 2 1 256 1) args m ch oracle = .ok (g₀, c))
    (hm : m.BytesIn m.Known) {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step (launch2 2 1 256 1) c) k g₀ z)
    (hz : GPUProof.Done sig (z, launch2 2 1 256 1, c))
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → x.1.ptr.off = ((tpose 32 (x.1.who.thread % 256) * 2 : Nat) : Int) ∧
        x.1.len = 2) ∧ (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound (launch2 2 1 256 1) c g₀ obs R :=
  sound_tpose valid256 2 h hm hB run hz hS hG hI hy hR

/-- Cell `c` of the shared array after every thread `t < 1024` stored at cell `tpose 32 t` its
loop sum, without the `contract` flag, under the oracle numbers `(0, 0)`, of list `t / 32` of
`wd40`'s strided split: the sum of thread `tpose 32 c`. -/
def M40 (c : Nat) : Model .binary32 :=
  dotLoop false (fun _ => (0, 0)) (Model.zero .binary32 false) (stride 32 (tpose 32 c / 32) wd40)

/-- **The instance of `warpDot_tpose`**, a test of one example: warp 5's rounds over the cells
`32 · 5 + l` of `M40` give lane 0 the word `2 ^ 24 + 38`, `warpDot` of `wd40` (`vals40`). -/
theorem col40 :
    (bflyRounds (fun x y => Model.add x y) warpOffsets (fun l => M40 (32 * 5 + l)) 0).toRat? =
      some 16777254 := by
  rw [warpDot_tpose (M := M40) false (fun _ _ => (0, 0)) (fun _ => wd40)
    (fun t ht => by simp only [M40, tpose_tpose (n := 32) ht]) (by decide : 5 < 32)]
  exact vals40.1

end MojoProofTest.Transpose
