import MojoProof.Sem.Shared
import MojoProof.Sem.Transpose
import MojoProofTest.WarpDot

/-!
# The transposition through shared memory at one thread, one trace and one column

Tests of one example each of MojoProof/Sem/Transpose.lean.
* `thread1061`: the launch `L2k` of grid (2, 1, 1) and block (1024, 1, 1), valid (`valid2k`), and
  its thread 1061, thread 37 of block 1 (warp 1, lane 5). By `Launch.tpose_env`, its lane number
  is 5 and it stores to cell `tpose 32 37 = 161`; the cell 37 that it loads after the barrier is
  the one thread 161 (warp 5, lane 1) stores to (`tpose 32 161 = 37`), and thread 161 is the one
  thread below 1024 that stores there (`tpose_bijOn`).
* `racy4`: the instance of `racy_tpose` at `n = 2` and cells of 1 byte, on the trace `tr4` of the
  4 threads of block of threads 0: thread `k` writes byte `tpose 2 k` of block 0, a barrier, and
  thread `k` reads byte `k`. The trace has no race.
* `sound1024`: the instance of `Grid.sound_cells` at the cell map `tpose 32` (injective on
  `[0, 1024)`, `tpose_tpose`) and cells of 4 bytes, on every valid launch with `ntid.x = 1024`
  (whose blocks have 1024 threads, `Launch.tpose_env`): a run in which each thread writes,
  before its block's first barrier, the 4 bytes of shared memory at its transposed cell, reads
  after it, and keeps to its own tile elsewhere, decides every schedule.
  That gevm_kernel's runs have this access pattern is not proved here.
* `col40`: the instance of `warpDot_tpose` at binary32, without the `contract` flag, under the
  oracle numbers `(0, 0)`, with every lane's pairs `wd40` (MojoProofTest/WarpDot.lean) and the
  array `M40` that the 1024 threads' stores leave: warp 5's rounds over the cells it loads give
  `2 ^ 24 + 38`, the word of `vals40`.
-/

namespace MojoProofTest.Transpose

open MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.WarpDot (wd40 vals40)

/-- The launch of grid (2, 1, 1) and block (1024, 1, 1). -/
def L2k : Launch := ⟨fun | .x => 2 | _ => 1, fun | .x => 1024 | _ => 1, 0⟩

/-- `L2k` is valid. -/
theorem valid2k : L2k.Valid where
  grid_pos d := by cases d <;> decide
  grid_le d := by cases d <;> decide
  block_pos d := by cases d <;> decide
  block_le d := by cases d <;> decide
  threads := by decide

/-- **Thread 1061 of `L2k`**, a test of one example: thread 37 of block 1 has lane number 5 and
stores to cell 161 (`Launch.tpose_env`); cell 37, which it loads, is thread 161's cell, and no
other thread of the block stores there (`tpose_bijOn`). -/
theorem thread1061 :
    (L2k.env 1061).sreg .tid .x = 37 ∧ (L2k.env 1061).laneid = 5 ∧
      32 * (L2k.env 1061).laneid + (L2k.env 1061).sreg .tid .x / 32 = 161 ∧ tpose 32 161 = 37 ∧
      ∀ t < 1024, tpose 32 t = 37 → t = 161 := by
  obtain ⟨-, ht, hl, hc⟩ := Launch.tpose_env valid2k rfl 1061
  refine ⟨ht.trans (by decide), hl.trans (by decide), hc.trans (by decide), by decide,
    fun t h e => (tpose_bijOn 32).injOn h (by decide : 161 < 1024) ?_⟩
  rw [e]
  decide

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
thread's transposed byte and the accesses of phase 1 are reads, so `tr4` has no race. -/
theorem racy4 : racy tr4 = false := by
  refine racy_tpose (n := 2) (w := 1) (by decide) (ofSh := fun b => if b = 0 then some 0 else none)
    (G := fun _ => none) (fun x hx β hβ => ?_) fun x hx hb => ?_ <;>
    rw [phases_tr4] at hx <;> simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  · rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      (simp only [acc4, ↓reduceIte, Option.some.injEq] at hβ; subst hβ; decide)
  · rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp [acc4] at hb

/-- **gevm_kernel's barrier on every launch of 1024 threads per block**, the instance of
`Grid.sound_cells` at the cell map `tpose 32` (injective on `[0, 1024)`, `tpose_tpose`) and cells of
4 bytes: for every program, kernel, valid launch with `ntid.x = 1024`, arguments, address choice and
oracle, on a caller's memory every pointer byte of whose blocks names a number below `next` or with
a block, and every observation `obs` that reads only the blocks: one run from the start's grid to a
grid `z` in which every thread has returned, in whose trace every access by a thread `k` to a block
of threads' shared memory is, before its block's first barrier, the 4 bytes at
`tpose 32 (k % 1024) * 4` (the kernel's `%62`, `Launch.tpose_env`) and after it a read, every
access to another block follows `G` with each thread its own tile, no access with
`!invariant.load` is to a block that a write touches, and whose observation is `y` with `R y`,
makes the start's grid sound. The premise `0 < volume L.block` is `Launch.Valid.volume_pos`. -/
theorem sound1024 {prog : MojoProof.LLVM.Program} {fn : MojoProof.LLVM.Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid}
    {c : Nat → Ctx} (hL : L.Valid) (hx : L.block .x = 1024)
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hB : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {k : Nat} {z : Grid} (run : Path (Grid.Step L c) k g₀ z) (hz : z.Done)
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → x.1.ptr.off = ((tpose 32 (x.1.who.thread % 1024) * 4 : Nat) : Int) ∧
        x.1.len = 4) ∧ (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block)
    {y : β} (hy : obs z.mem = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  have hv := (Launch.tpose_env hL hx 0).1
  Grid.sound_cells h hm hB run hz (w := 4) (cell := tpose 32) hL.volume_pos
    (fun i hi j hj e => by
      rw [hv] at hi hj
      rw [← tpose_tpose (n := 32) hi, e, tpose_tpose (n := 32) hj])
    (fun x hx b e => by
      obtain ⟨h0, h1⟩ := hS x hx b e
      refine ⟨fun hp => ?_, h1⟩
      obtain ⟨ho, hl⟩ := h0 hp
      rw [hv, ho, hl]
      omega) hG hI hy hR

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
