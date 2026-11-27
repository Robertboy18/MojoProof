import MojoProof.Sym.ShflDeliver
import MojoProofTest.GemvWarp
import MojoProofTest.GPUProof.MixedRadix

/-!
# gemv_kernel's shuffles at symbolic values

Tests of MojoProof/Sym/ShflDeliver.lean at gemv_kernel (fixture `gemv`,
MojoProofTest/SymLane.lean) and its seven shuffles: `%6`'s two `shfl.sync.idx` (`%24`, `%25`;
tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll lines
25-26) and `%78`'s five `shfl.sync.bfly`.

* `keeps`: gemv's shuffle declarations pass `Program.shflKeeps` (the kernel evaluates it).
* `deliver7`: `WarpRun.of_waits`'s delivery equation at the `i`-th shuffle (`mode`, `ofs` of
  MojoProofTest/GemvWarp.lean), gemv_kernel, for every launch whose block size 32 divides, warp,
  offered values that are words at the source lane `src i j`, layout and memory.
* `row_lane`: a lane's row `(ctaid.x * ntid.x + tid.x) / 32` is its warp's lane 0's when 32
  divides the block's `x` size (`gemv_warp`, MojoProofTest/GPUProof/MixedRadix.lean).
  `idx_row`: `%24` and `%25` deliver lane 0's halves of the row word, the premises `hd₁`, `hd₂`
  of `MojoProofTest.GemvThread.run` at `r` lane 0's row, which is the lane's own.
* Tests, by evaluation: `deliver7`'s value is what `r`, the delivery `ok78` checks, computes at a
  block of 32 threads and at the second warp of a block of 64, with offers that differ by phase
  and lane (`tag`). The mutant: at a block of 16 threads the first `bfly`'s source lane `j ^^^ 16`
  is not one of the warp's lanes, and `poison` is delivered, not the source's offer (`poison16`).
  At two blocks of 48 threads thread 64's row is not its warp's lane 0's: `row_lane` needs its
  premise.
-/

namespace MojoProofTest.GemvShfl

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.GemvWarp

-- `Array.all` recurses by well-founded recursion, so the kernel cannot evaluate `shflKeeps`
-- without this.
unseal Array.anyM.loop

/-- gemv_kernel's program passes `shflKeeps`: its shuffle declarations put no attribute on their
results that changes a word. -/
theorem keeps : gemv.prog.shflKeeps = true := by decide +kernel

/-- The source lane of lane `j` at gemv_kernel's `i`-th shuffle in a full warp: lane 0 at `%6`'s
two (`idx`), `j ^^^ ofs i` at `%78`'s five (`bfly`). -/
def src (i j : Nat) : Nat := if i < 2 then 0 else j ^^^ ofs i

/-- **`WarpRun.of_waits`'s delivery equation at gemv_kernel's seven shuffles.** gemv_kernel, for
every launch `L` whose block has a positive number of threads that 32 divides, thread `k`,
offered values `a`, phase `i < 7`, lane `j < 32`, layout and memory, with the source lane's offer
`a (src i j)` a word: every declaration a call finds by a name mapped to the `i`-th shuffle's mode
delivers `some (a (src i j))` (`Program.shfl_deliver_idx`, `Program.shfl_deliver_bfly`,
`warpLanes_full`, `keeps`). -/
theorem deliver7 {L : Launch} (hs : 0 < volume L.block) (h32 : 32 ∣ volume L.block) (k : Nat)
    {a : Nat → Val} {i j w : Nat} {x : BitVec w} (hi : i < 7) (hj : j < 32)
    (hx : a (src i j) = .bits w x) (l : Layout) (m : Mem) :
    ∀ g e, gemv.prog.module.funcs.find? (·.name == g) = some e →
      gemv.prog.intrinsics.lookup g = some (.shfl (mode i)) →
      (some (shflVal (warpLanes L k) a (shflSource (mode i) j (ofs i) 31))).mapM
        (withAttrs l m e.ret e.retAttrs) = .ok (some (a (src i j))) := by
  rcases Nat.lt_or_ge i 2 with h | h
  · have hm : mode i = .idx := ite_eq_left h
    have ho : ofs i = 0 := by interval_cases i <;> rfl
    have hsrc : src i j = 0 := ite_eq_left h
    rw [hm, ho, hsrc]
    rw [hsrc] at hx
    exact gemv.prog.shfl_deliver_idx keeps hs hx rfl
  · have hm : mode i = .bfly := ite_eq_right (by omega)
    have ho : ofs i < 32 := by interval_cases i <;> decide
    have hsrc : src i j = j ^^^ ofs i := ite_eq_right (by omega)
    rw [hm, hsrc]
    rw [hsrc] at hx
    exact gemv.prog.shfl_deliver_bfly keeps (warpLanes_full hs h32 k) hj ho hx rfl

/-- The row of a thread with special registers `e`: `(ctaid.x * ntid.x + tid.x) / 32`, gemv's
`%20` (gemv IR lines 13-21). -/
def row (e : Env) : Nat := (e.sreg .ctaid .x * e.sreg .ntid .x + e.sreg .tid .x) / 32

/-- **A lane's row is its warp's lane 0's.** For every valid launch `L` whose block's `x` size 32
divides, warp's first thread `k` and lane `j` of its warp: thread `k + j`'s row is thread `k`'s.
The two are in one block (`warp_lane`), and their `tid.x` are in one group of 32, so
`gemv_warp` (MojoProofTest/GPUProof/MixedRadix.lean) equates their rows. -/
theorem row_lane {L : Launch} (hL : L.Valid) (hx : 32 ∣ L.block .x) {k j : Nat}
    (hk : k % volume L.block % 32 = 0) (hj : j ∈ warpLanes L k) :
    row (L.env (k + j)) = row (L.env k) := by
  have hs := hL.volume_pos
  have hj' := mem_warpLanes.1 hj
  rw [warpLanes_eq, List.length_range] at hj'
  obtain ⟨h1, h2⟩ := warp_lane (k := k) (j := j) hs (by omega)
  have hbx := hL.block_pos .x
  have hgx := hL.grid_pos .x
  simp only [row, Launch.env, coord, h1, h2]
  refine (MojoProofTest.GPUProof.MixedRadix.gemv_warp hx (Nat.mod_lt _ hbx) (Nat.mod_lt _ hbx)
    (Nat.mod_lt _ hgx) (Nat.mod_lt _ hgx)).2 ⟨?_, rfl⟩
  obtain ⟨b, hb⟩ := hx
  rw [hb, Nat.mod_mul_right_div_self, Nat.mod_mul_right_div_self]
  congr 1
  omega

/-- What lane `l` of the warp from thread `k` offers at `%24` (`lo = 0`) and at `%25`
(`lo = 32`): the low and high halves of its row word, as `MojoProofTest.GemvEntryRun.entry`'s
waits state them at `c.env = L.env (k + l)`. -/
def half (L : Launch) (k lo l : Nat) : Val :=
  .bits 32 ((BitVec.ofNat 64 (row (L.env (k + l)))).extractLsb' lo 32)

/-- **`%24` and `%25` deliver lane 0's halves of the row word.** gemv_kernel, for every context
`c` running gemv's program, launch `L` whose block has threads, thread `k`, lane `j`, half `lo`,
layout and memory: `WarpRun.of_waits`'s delivery equation at `%6`'s `idx` shuffles with the
lanes' offers `half L k lo` holds at `some` of the half `lo` of the row word of thread `k`, the
warp's lane 0. So `MojoProofTest.GemvThread.run`'s premises `hd₁` (`lo = 0`) and `hd₂`
(`lo = 32`) hold at `r = row (L.env k)` for the deliveries, and that is the lane's own row when
32 divides the block's `x` size (`row_lane`). -/
theorem idx_row {c : Ctx} (hcp : c.prog = gemv.prog) {L : Launch} (hs : 0 < volume L.block)
    (k j lo : Nat) (l : Layout) (m : Mem) :
    ∀ g e, c.prog.module.funcs.find? (·.name == g) = some e →
      c.prog.intrinsics.lookup g = some (.shfl .idx) →
      (some (shflVal (warpLanes L k) (half L k lo) (shflSource .idx j 0 31))).mapM
        (withAttrs l m e.ret e.retAttrs) =
          .ok (some (.bits 32 ((BitVec.ofNat 64 (row (L.env k))).extractLsb' lo 32))) := by
  intro g e he hg
  rw [hcp] at he hg
  exact gemv.prog.shfl_deliver_idx keeps hs rfl rfl g e he hg

/-! ## Tests -/

/-- A test's offers: lane `j` offers the word `32 i + j` at the `i`-th shuffle, so that a wrong
source lane changes the delivery. -/
def tag (i j : Nat) : Val := .bits 32 (.ofNat 32 (32 * i + j))

/-- Test: at one block of 32 threads (`x32`, warp 0), what `r`, the delivery `ok78` checks,
computes at the seven shuffles is `deliver7`'s value at `tag`, by evaluation. -/
example : ∀ i < 7, ∀ j < 32, r { w32 with v := tag } i j = some (tag i (src i j)) := by
  decide +kernel

/-- Test: at one block of 64 threads (`x64`, warp 32, lanes 0 to 31), what `r`, the
delivery `ok78` checks, computes at the seven shuffles is `deliver7`'s value at `tag`, by
evaluation. -/
example : ∀ i < 7, ∀ j < 32, r { wb with v := tag } i j = some (tag i (src i j)) := by
  decide +kernel

/-- Test: `deliver7`'s premises at one block of 64 threads, `warpLanes_full` there and the source
lanes' offers words, so `deliver7` applies at its lane 5 and the first `bfly`. -/
example (l : Layout) (m : Mem) := deliver7 (L := L x64) (by decide) (by decide) 32 (a := tag 2)
  (i := 2) (j := 5) (x := .ofNat 32 (32 * 2 + (5 ^^^ 16))) (by decide) (by decide) rfl l m

/-- Test: `warpLanes_full` at one block of 64 threads agrees with evaluation at thread 37. -/
example : warpLanes (L x64) 37 = List.range 32 := by decide

/-- Test (mutant): at one block of 16 threads (`x16`), the first `bfly`'s source lane
`j ^^^ 16` is not one of the warp's lanes, so the premise of `Program.shfl_deliver` fails, and
`r`, the delivery `ok78` checks, is `poison` (`poison16`), not the source lane's offer. -/
example : ∀ j < 16, shflSource .bfly j 16 31 ∉ warpLanes (L x16) 0 ∧
    r w16 2 j = some .poison ∧ r w16 2 j ≠ some (w16.v 2 (src 2 j)) := fun j hj =>
  ⟨by interval_cases j <;> decide, poison16.1 j hj, by
    rw [poison16.1 j hj]
    interval_cases j <;> decide⟩

/-- Test: `idx_row` and `row_lane` at one block of 64 threads (`x64`), lane 7 of the warp from
thread 32, for every context running gemv's program, layout and memory: `%24` delivers the low
half of row 1, and lane 7's own row is 1. -/
example (c : Ctx) (hcp : c.prog = gemv.prog) (l : Layout) (m : Mem) :
    row ((L x64).env (32 + 7)) = 1 ∧ ∀ g e, c.prog.module.funcs.find? (·.name == g) = some e →
      c.prog.intrinsics.lookup g = some (.shfl .idx) →
      (some (shflVal (warpLanes (L x64) 32) (half (L x64) 32 0) (shflSource .idx 7 0 31))).mapM
        (withAttrs l m e.ret e.retAttrs) =
          .ok (some (.bits 32 ((BitVec.ofNat 64 1).extractLsb' 0 32))) :=
  ⟨(row_lane (L := L x64) (launch2_valid (by decide)) (by decide) (by decide)
    (by decide)).trans (by decide), idx_row hcp (by decide) 32 7 0 l m⟩

/-- Test (mutant): at two blocks of 48 threads, whose `x` size 32 does not divide, thread 64 is
lane 16 of the warp from thread 48, but its row is 2 and lane 0's is 1, so `row_lane` needs its
premise. -/
example : 16 ∈ warpLanes (launch2 2 1 48 1) 48 ∧ row ((launch2 2 1 48 1).env 64) = 2 ∧
    row ((launch2 2 1 48 1).env 48) = 1 := by decide

end MojoProofTest.GemvShfl
