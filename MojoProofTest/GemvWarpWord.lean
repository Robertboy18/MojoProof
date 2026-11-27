import MojoProofTest.GemvWarpRun
import MojoProofTest.GemvLoopBfly

/-!
# gemv_kernel's warp word as the butterfly rounds

MojoProofTest/GemvWarpRun.lean's `Lanes.warp` has a warp of gemv_kernel (`gemv`,
MojoProofTest/SymLane.lean, gemv_kernel float32 `b79a852b`) store, at row `r` of the output
buffer, lane 0's `total` of its sum `x 0` and its partners' offers `acc i (2 ^ (4 - i))`, where
each lane's `acc` is the `addAt` chain of `MojoProofTest.GemvLoopTail.shfls` with its partners'
offers delivered. MojoProofTest/GemvLoopBfly.lean's `offered` is the same chain for every family
of deliveries, and its `total_chain` makes every lane's `total` its value after the five
butterfly rounds when each shuffle delivers its partner's offered value. This file joins the two:

* `delivered`, `offered_acc`: at the deliveries of the warp (lane `l`'s partner's offer at
  `%78`'s shuffle `i`, `acc i (l ^^^ ofs (i + 2))`, as `Lanes.X` has them), the offered values are
  the lanes' `acc`s, by `rfl` at each shuffle;
* `partner_offered`: so each delivery is the partner's offered value at `l ^^^ 2 ^ (4 - i)`
  (`ofs (i + 2) = 2 ^ (4 - i)` for `i < 5`), `total_chain`'s premise;
* `word_rounds`, `warp_word`: lane 0's `total` is its value after the five rounds
  `deliver (Model.add a b)` over `bflyOffsets 5` from the lanes' sums `x`, with lane `l`'s oracle
  number of round `r`, for every warp; so the word `Lanes.warp` has the warp store is that value;
* `lo`, `lob`, `offered_congr`, `sums`, `x_eq`, `partner_sums`, `word_sums`: under the warp's
  premises each lane's sum is its loop over the pairs at `stride 32 l` (`sums`), and lane 0's
  `total` is the rounds over those loops with the lanes' loop and round oracle numbers;
* `warp_holds`, `warp_row`: so the stored word is row `r` of
  `MojoProofTest.GemvLoopBfly.rowWords`, words that meet the rule of
  `MojoProof.Tile.bflyDeliver_holds` at `k = 5` (`stored_holds`), for all input words that hold
  the warp's matrix and vector;
* `word_warpDot_nanEq`, `word_warpDot`, `warp_dot`: and it is row `r`'s
  `MojoProof.Sem.warpDot true` (FloatLib's `Model.add` in every round) up to NaNs, and equal to
  it where no round's sum is a NaN (`MojoProof.Sem.bflyDeliver_nanEq`, `bflyRoundsAt_deliver`);
  its instance at one block of 32 threads, `M = 1`, `K = 4`, row 0 (`w0`);
* `rows_of_loads`, `grid_rows`: at a one-dimensional launch whose warps' rows cover the matrix's
  rows, a memory where each in-range warp's lane 0 loads its row word has every output row its
  row's `warpDot` up to NaNs (`word_warpDot_nanEq`), and so the start's grid steps to a done grid
  with such a memory (`Lanes.grid_done`); its instances at one block of 64 threads, `K = 4`,
  from the grid's start, at `M = 2` on `n3` and at `M = 1` on `m3`, where the second warp's row
  is `M`.

Tests of one program, gemv_kernel float32 `b79a852b`.
-/

namespace MojoProofTest.GemvWarpWord

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvLoop MojoProofTest.GemvLoopTail MojoProofTest.GemvLoopBfly
open MojoProofTest.GemvWarpRun
open FloatLib.Floats.Formats.BinaryInterchange

/-- The delivery of a warp `w` of gemv_kernel to lane `l` at `%78`'s shuffle `i` (from 0): the
offer `acc i` of lane `l`'s partner `l ^^^ ofs (i + 2)`, as `Lanes.X` has it. A test definition. -/
def delivered (w : Lanes) (i l : Nat) : Model FloatTy.float.fmt :=
  w.acc i (l ^^^ GemvWarp.ofs (i + 2))

/-- **A warp's offered values are its lanes' sums** (test of gemv_kernel's `%78`, for every warp
`w`, shuffle `i` and lane `l`): when each shuffle delivers to lane `l` its partner's offer
(`delivered`), the value lane `l` offers at shuffle `i` (`MojoProofTest.GemvLoopBfly.offered`, at
the lanes' contexts `w.c (w.k + l)`, step counts `w.n l` and sums `w.x l`) is its `acc i`. By
induction on `i`, `rfl` at each shuffle. -/
theorem offered_acc (w : Lanes) : ∀ i l,
    offered (fun l => w.c (w.k + l)) w.n w.x (delivered w) i l = w.acc i l
  | 0, _ => rfl
  | i + 1, l => by rw [offered, offered_acc w i l]; rfl

/-- **Each delivery is the partner's offered value** (test of gemv_kernel's `%78`, for every warp
`w`, shuffle `i < 5` and lane `l < 32`): the delivery to lane `l` at shuffle `i` is what lane
`l ^^^ 2 ^ (4 - i)` offers there, `MojoProofTest.GemvLoopBfly.total_chain`'s premise. By
`offered_acc` and `ofs (i + 2) = 2 ^ (4 - i)` at each `i < 5`. -/
theorem partner_offered (w : Lanes) : ∀ i < 5, ∀ l < 32, delivered w i l =
    offered (fun l => w.c (w.k + l)) w.n w.x (delivered w) i (l ^^^ 2 ^ (4 - i)) := by
  intro i hi l _
  rw [offered_acc]
  have : GemvWarp.ofs (i + 2) = 2 ^ (4 - i) := by interval_cases i <;> rfl
  rw [delivered, this]

/-- **A warp's lane-0 word is its value after the five butterfly rounds** (test of gemv_kernel's
`%78`, for every warp `w`): lane 0's `total` of its sum `w.x 0` and its partners' offers
`w.acc i (2 ^ (4 - i))`, the word `Lanes.warp` has the warp store at row `r`, is lane 0's value
after the five rounds `deliver (Model.add a b)` over `bflyOffsets 5` from the lanes' sums `w.x`,
with lane `l`'s oracle number of round `r`,
`(w.c (w.k + l)).oracle (Nat.pair (w.n l + (4 r + 3)) 0) / 3`. By `total_chain` at lane 0 with
`partner_offered`. -/
theorem word_rounds (w : Lanes) :
    total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8) (w.acc 2 4) (w.acc 3 2)
        (w.acc 4 1) =
      bflyRoundsAt (fun r l a b => deliver (Model.add a b)
        ((w.c (w.k + l)).oracle (Nat.pair (w.n l + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) w.x 0 :=
  total_chain (fun l => w.c (w.k + l)) w.n w.x (delivered w) (partner_offered w) 0 (by decide)

/-- **gemv_kernel's warp stores the butterfly rounds' word** (test of gemv_kernel, for every warp
`w` under `Lanes.warp`'s premises `Lanes.Pre`): the warp's 32 lanes run (`WarpRun`) from the
memory to `mem7 32`, and the word at row `r` of the output buffer then loads as lane 0's value
after the five rounds `deliver (Model.add a b)` over `bflyOffsets 5` from the lanes' sums `w.x`,
with lane `l`'s oracle number of round `r`. By `Lanes.warp` and `word_rounds`. -/
theorem warp_word (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) :
    ∃ Es, WarpRun w.L w.c w.k w.t w.m Es (w.mem7 32) ∧
      (w.mem7 32).load gemv.prog.layout (w.c w.k).who 0 (.fp .float)
        ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
        .ok (Val.ofFloat .float (bflyRoundsAt (fun r l a b => deliver (Model.add a b)
          ((w.c (w.k + l)).oracle (Nat.pair (w.n l + (4 * r + 3)) 0) / 3)) (bflyOffsets 5)
          w.x 0)) := by
  rw [← word_rounds w]
  exact Lanes.warp h

/-- The loop oracle numbers of a warp `w`'s lanes, at every row: lane `l`'s `oG` at its context
and its step count at statement 41 of `%6` (`MojoProofTest.GemvLoop.oG`, as `Lanes.x` has it). A
test definition. -/
def lo (w : Lanes) : Fin w.M → Nat → Nat → Nat × Nat := fun _ l =>
  oG (w.c (w.k + l)) ((w.t (w.k + l)).k + 41)

/-- The round oracle numbers of a warp `w`'s lanes, at every row: at round `j` and lane `l`, the
number of lane `l`'s `fadd` after shuffle `j`,
`(w.c (w.k + l)).oracle (Nat.pair (w.n l + (4 j + 3)) 0) / 3`. A test definition. -/
def lob (w : Lanes) : Fin w.M → Nat → Nat → Nat := fun _ j l =>
  (w.c (w.k + l)).oracle (Nat.pair (w.n l + (4 * j + 3)) 0) / 3

/-- **A lane's offered values read only its own sum** (test of gemv_kernel's `%78`, for every
family of lane contexts `c l`, steps `k0 l`, sums `x l` and `x' l`, deliveries `z i l`, lane `l`
and shuffle `i`): if `x l = x' l`, lane `l` offers the same value at shuffle `i` from `x` and from
`x'`. By induction on `i`. -/
theorem offered_congr (c : Nat → Ctx) (k0 : Nat → Nat) {x x' : Nat → Model FloatTy.float.fmt}
    (z : Nat → Nat → Model FloatTy.float.fmt) {l : Nat} (h : x l = x' l) :
    ∀ i, offered c k0 x z i l = offered c k0 x' z i l
  | 0 => h
  | i + 1 => by rw [offered, offered, offered_congr c k0 z h i]

/-- The sum of a warp `w`'s lane `l` at its lane number: the loop `dotLoop true` at the lane's
loop oracle numbers (`lo`) from `+0` over the pairs of row `r` of the matrix and the vector at
`stride 32 l`, `Lanes.x` at `l` for the lane number. A test definition. -/
def sums (w : Lanes) (l : Nat) : Model FloatTy.float.fmt :=
  dotLoop true (lo w w.r l) (Model.zero _ false) (stride 32 l (matVecPairs w.A w.v w.r))

/-- **A warp's lane sums are the loops at the lane numbers** (test of gemv_kernel, for every warp
`w` under `Lanes.Pre` and lane `l < 32`): `w.x l` is `sums w l`, by `Lanes.lid_eq`. -/
theorem x_eq (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) : ∀ l < 32, w.x l = sums w l := by
  intro l hl
  show dotLoop true _ _ (stride 32 (w.lid l) _) = _
  rw [Lanes.lid_eq h hl]
  rfl

/-- **Each delivery is the partner's offered value from the loops at the lane numbers** (test of
gemv_kernel's `%78`, for every warp `w` under `Lanes.Pre`, shuffle `i < 5` and lane `l < 32`):
`partner_offered` with the sums `sums w` for `w.x`, which agree at every lane below 32 (`x_eq`,
`offered_congr`, and `l ^^^ 2 ^ (4 - i) < 32` by `Nat.xor_lt_two_pow`). -/
theorem partner_sums (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) : ∀ i < 5, ∀ l < 32,
    delivered w i l =
      offered (fun l => w.c (w.k + l)) w.n (sums w) (delivered w) i (l ^^^ 2 ^ (4 - i)) := by
  intro i hi l hl
  rw [partner_offered w i hi l hl]
  exact offered_congr _ _ _ (x_eq w h _ (Nat.xor_lt_two_pow (n := 5) hl
    (Nat.pow_lt_pow_right (by decide) (by omega)))) i

/-- **A warp's lane-0 word is the butterfly rounds over the loops at the lane numbers** (test of
gemv_kernel's `%78`, for every warp `w` under `Lanes.Pre`): `word_rounds` with the sums
`sums w`, each lane's loop over the pairs at `stride 32 l`. By `total_chain` at lane 0 with
`partner_sums`, and `x_eq` at lane 0. -/
theorem word_sums (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) :
    total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8) (w.acc 2 4) (w.acc 3 2)
        (w.acc 4 1) =
      bflyRoundsAt (fun r l a b => deliver (Model.add a b) (lob w w.r r l)) (bflyOffsets 5)
        (sums w) 0 := by
  rw [x_eq w h 0 (by decide)]
  exact total_chain (fun l => w.c (w.k + l)) w.n (sums w) (delivered w) (partner_sums w h) 0
    (by decide)

/-- **A warp's stored word is row `r` of words that meet the matrix-vector rule** (test of
gemv_kernel, for every warp `w` under `Lanes.Pre`, width `bits` and input words `I` that hold the
warp's matrix `w.A` and vector `w.v`): the words `MojoProofTest.GemvLoopBfly.rowWords` at the
lanes' loop and round oracle numbers (`lo`, `lob`) meet the rule of
`MojoProof.Tile.bflyDeliver_holds` at `k = 5` (`GPUProof.Spec.matVec` at
`GPUProof.laneVecGrade (2 ^ 5) 5`), and their row `r` is lane 0's `total` of its sum and its
partners' offers, the word `Lanes.warp` has the warp store. Proof: `stored_holds`, with the
deliveries `w.acc j (2 ^ (4 - j))` its partners' values after the first `j` rounds by
`offered_acc`, `partner_sums`, `offered_eq` and `offered_congr`. -/
theorem warp_holds (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) (bits : Nat)
    (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (w.M, w.K)).inp.Words)
    (hA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 w.A i j)
    (hv : ∀ j, I (.inr j) = w.v.getScalar j) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (w.M, w.K)
        (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (w.M, w.K)) I
        (rowWords (lo w) (lob w) I) ∧
      rowWords (lo w) (lob w) I w.r = total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8)
        (w.acc 2 4) (w.acc 3 2) (w.acc 4 1) := by
  have hlt : ∀ j, 2 ^ (4 - j) < 2 ^ 5 := fun j => Nat.pow_lt_pow_right (by decide) (by omega)
  have hr := offered_eq _ _ _ _ (partner_sums w h)
  obtain ⟨hH, hw⟩ := stored_holds bits w.A w.v I hA hv (lo w) (lob w) (w.c w.k) (w.n 0) w.r.val
    w.r.isLt (fun _ _ => rfl) (fun j => w.acc j (2 ^ (4 - j))) (fun j hj =>
      ((offered_acc w j (2 ^ (4 - j))).symm.trans
        (offered_congr _ _ _ (x_eq w h _ (hlt j)) j)).trans (hr j (by omega) _ (hlt j)))
  refine ⟨hH, hw.trans ?_⟩
  rw [x_eq w h 0 (by decide)]
  rfl

/-- **A warp's lane-0 word is row `r`'s `warpDot` up to NaNs** (test of gemv_kernel, for every
warp `w` under `Lanes.Pre`): lane 0's `total`, the word `Lanes.warp` has the warp store, and
`MojoProof.Sem.warpDot true` at the lanes' loop oracle numbers over the pairs of row `r` of the
matrix and the vector (FloatLib's `Model.add` in every round) are the same word or both NaNs
(`NaNEq`). By `word_sums` and `MojoProof.Sem.bflyDeliver_nanEq`. -/
theorem word_warpDot_nanEq (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) :
    NaNEq (total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8) (w.acc 2 4) (w.acc 3 2)
        (w.acc 4 1)) (warpDot true (lo w w.r) (matVecPairs w.A w.v w.r)) := by
  rw [word_sums w h]
  exact bflyDeliver_nanEq (lob w w.r) (bflyOffsets 5) (sums w) 0

/-- **A warp's lane-0 word is row `r`'s `warpDot` where no round's sum is a NaN** (test of
gemv_kernel, for every warp `w` under `Lanes.Pre` whose rounds of `Model.add` over the sums
`sums w` hold no NaN at any lane below 32 after any of the five rounds): lane 0's `total` is
`MojoProof.Sem.warpDot true` at the lanes' loop oracle numbers over the pairs of row `r`. By
`word_sums` and `MojoProof.Sem.bflyRoundsAt_deliver`. The premise is needed: at a NaN sum the
kernel's `fadd` delivers the oracle's NaN. -/
theorem word_warpDot (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV)
    (hN : ∀ k < 5, ∀ j < 32, (bflyRounds (fun x y => Model.add x y) ((bflyOffsets 5).take (k + 1))
      (sums w) j).isNaN = false) :
    total (w.c w.k) (w.n 0) (w.x 0) (w.acc 0 16) (w.acc 1 8) (w.acc 2 4) (w.acc 3 2)
        (w.acc 4 1) = warpDot true (lo w w.r) (matVecPairs w.A w.v w.r) := by
  rw [word_sums w h]
  exact bflyRoundsAt_deliver (e := 5) (ms := bflyOffsets 5) (fun x y => Model.add x y) (lob w w.r)
    (by decide) (sums w) hN (by decide)

/-- **gemv_kernel's warp stores row `r`'s `warpDot` where no round's sum is a NaN** (test of
gemv_kernel, for every warp `w` under `Lanes.Pre` and `word_warpDot`'s premise): the warp's 32
lanes run (`WarpRun`) from the memory to `mem7 32`, and the word at row `r` of the output buffer
then loads as `MojoProof.Sem.warpDot true` at the lanes' loop oracle numbers over the pairs of
row `r` of the matrix and the vector. By `Lanes.warp` and `word_warpDot`. -/
theorem warp_dot (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV)
    (hN : ∀ k < 5, ∀ j < 32, (bflyRounds (fun x y => Model.add x y) ((bflyOffsets 5).take (k + 1))
      (sums w) j).isNaN = false) :
    ∃ Es, WarpRun w.L w.c w.k w.t w.m Es (w.mem7 32) ∧
      (w.mem7 32).load gemv.prog.layout (w.c w.k).who 0 (.fp .float)
        ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
        .ok (Val.ofFloat .float (warpDot true (lo w w.r) (matVecPairs w.A w.v w.r))) := by
  rw [← word_warpDot w h hN]
  exact Lanes.warp h

/-- **gemv_kernel's warp stores row `r` of words that meet the matrix-vector rule** (test of
gemv_kernel, for every warp `w` under `Lanes.Pre`, width `bits` and input words `I` that hold the
warp's matrix and vector): `rowWords (lo w) (lob w) I` meets the rule of
`MojoProof.Tile.bflyDeliver_holds` at `k = 5`, the warp's 32 lanes run (`WarpRun`) from the
memory to `mem7 32`, and the word at row `r` of the output buffer then loads as its row `r`. By
`warp_holds` and `Lanes.warp`. -/
theorem warp_row (w : Lanes) {bA bV : Nat} (h : w.Pre bA bV) (bits : Nat)
    (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (w.M, w.K)).inp.Words)
    (hA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 w.A i j)
    (hv : ∀ j, I (.inr j) = w.v.getScalar j) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (w.M, w.K)
        (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (w.M, w.K)) I
        (rowWords (lo w) (lob w) I) ∧
      ∃ Es, WarpRun w.L w.c w.k w.t w.m Es (w.mem7 32) ∧
        (w.mem7 32).load gemv.prog.layout (w.c w.k).who 0 (.fp .float)
          ⟨w.p0, ((w.r.val * 4 : Nat) : Int)⟩ (some 4) =
          .ok (Val.ofFloat .float (rowWords (lo w) (lob w) I w.r)) := by
  obtain ⟨hH, hw⟩ := warp_holds w h bits I hA hv
  obtain ⟨Es, hE, hl⟩ := Lanes.warp h
  refine ⟨hH, Es, hE, ?_⟩
  rw [hw]
  exact hl

/-- **The rows from the warps' loads**: gemv_kernel, for every valid launch `L` whose blocks and
grid are one-dimensional (`y` and `z` sizes 1), whose block's `x` size 32 divides and whose warps'
rows cover the matrix's rows (`M ≤ L.block .x / 32 · L.grid .x`), argument values `p0`, `bA`,
`bV` (pointers at offset 0), `M`, any `%4` and `K`, caller's memory `m` with no block from `next`
on, address choice below `2 ^ 60` and oracle whose start gives `(g, c)`, with `grid_rows`' bounds
and buffers, and every memory `m'` where each warp whose row `r : Fin M` is below `M` has its row
word load as its lane 0's `word 0` (`Lanes.grid_run`'s and `Lanes.grid_run_inv`'s end memory):
for every row `i < M`, the output word at row `i` of `m'` loads as a word that is row `i`'s
`MojoProof.Sem.warpDot true` at the loop oracle numbers of the warp from thread `32 i` up to
NaNs (`NaNEq`). By `Lanes.Pre.of_warps` and `word_warpDot_nanEq`; the warp from thread `32 i`
writes row `i` (`row_eq`). -/
theorem rows_of_loads {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) {m' : Mem}
    (hl : ∀ k ∈ warps L g.threads.size, ∀ r : Fin M, r.val = GemvShfl.row (L.env k) →
      m'.load gemv.prog.layout (c k).who 0 (.fp .float) ⟨p0, ((r.val * 4 : Nat) : Int)⟩
        (some 4) = .ok (Val.ofFloat .float ((Lanes.ofStart L g c k M K p0 A v r).word 0))) :
    ∀ i : Fin M, ∃ x, m'.load gemv.prog.layout (c (32 * i.val)).who 0 (.fp .float)
        ⟨p0, ((i.val * 4 : Nat) : Int)⟩ (some 4) = .ok (Val.ofFloat .float x) ∧
      NaNEq x (warpDot true (lo (Lanes.ofStart L g c (32 * i.val) M K p0 A v i) i)
        (matVecPairs A v i)) := by
  intro i
  have hv : volume L.block = L.block .x := by simp only [volume, hby, hbz, Nat.mul_one]
  have hgv : volume L.grid = L.grid .x := by simp only [volume, hgy, hgz, Nat.mul_one]
  have h32 : 32 ∣ volume L.block := hv ▸ hx
  have hN : g.threads.size = volume L.grid * volume L.block := Grid.start_size hs
  have hlt : 32 * i.val < volume L.grid * volume L.block := by
    have hi : i.val < L.block .x / 32 * L.grid .x := Nat.lt_of_lt_of_le i.isLt hMx
    have e : volume L.grid * volume L.block = 32 * (L.block .x / 32 * L.grid .x) := by
      rw [hgv, hv, Nat.mul_comm (L.grid .x), ← Nat.mul_assoc, Nat.mul_div_cancel' hx]
    rw [e]
    omega
  have hk : 32 * i.val ∈ warps L g.threads.size := by
    rw [warps, List.mem_filter, List.mem_range, decide_eq_true_eq, hN,
      Nat.mod_mod_of_dvd _ h32]
    exact ⟨hlt, by omega⟩
  have hri : i.val = GemvShfl.row (L.env (32 * i.val)) := by
    rw [row_eq hL hby hbz hgy hgz hlt]
    omega
  have hpre := Lanes.Pre.of_warps hs ha hL h32 hch hM hK hMK hm hb0 hf0 hbA hbV hfA hfV hA hV
    hk hri
  exact ⟨_, hl _ hk i hri, word_warpDot_nanEq _ hpre⟩

/-- **Every output row of the done grid is its row's `warpDot` up to NaNs**: gemv_kernel, for
every valid launch `L` whose blocks and grid are one-dimensional (`y` and `z` sizes 1), whose
block's `x` size 32 divides and whose warps' rows cover the matrix's rows
(`M ≤ L.block .x / 32 · L.grid .x`), argument values `p0`, `bA`, `bV` (pointers at offset 0),
`M`, any `%4` and `K`, caller's memory `m` with no block from `next` on, address choice below
`2 ^ 60` and oracle whose start gives `(g, c)`: if `M`, `K` and `M K` are in range and `m` has
the writable output buffer and the read-only matrix and vector buffers, which fit, the last two
holding `A` and `v`, then the start's grid steps (`Grid.Step`) to a done grid (`GPUProof.Done`
at `sig`) where, for every row `i < M`, the output word at row `i` loads as a word that is row
`i`'s `MojoProof.Sem.warpDot true` at the loop oracle numbers of the warp from thread `32 i` up
to NaNs (`NaNEq`). By `Lanes.grid_done` and `rows_of_loads`. -/
theorem grid_rows {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (hs : Grid.start gemv.prog gemv.fn_0 L args m ch oracle = .ok (g, c))
    {M K p0 bA bV : Nat} {x4 : Val}
    (ha : args = [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩, .bits 32 (BitVec.ofNat 32 M), x4,
      .bits 32 (BitVec.ofNat 32 K)])
    (hL : L.Valid) (hx : 32 ∣ L.block .x) (hby : L.block .y = 1) (hbz : L.block .z = 1)
    (hgy : L.grid .y = 1) (hgz : L.grid .z = 1) (hch : ∀ q, ch q < 2 ^ 60)
    (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (hMx : M ≤ L.block .x / 32 * L.grid .x)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K]}
    {v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]} (hm : m.FreeAbove)
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4))
    (hbA : m.Buffer bA (M * K * 4) 4 false) (hbV : m.Buffer bV (K * 4) 4 false)
    (hfA : m.Fits gemv.prog.layout bA (M * K * 4)) (hfV : m.Fits gemv.prog.layout bV (K * 4))
    (hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧
      ∀ i : Fin M, ∃ x, z.mem.load gemv.prog.layout (c (32 * i.val)).who 0 (.fp .float)
          ⟨p0, ((i.val * 4 : Nat) : Int)⟩ (some 4) = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true (lo (Lanes.ofStart L g c (32 * i.val) M K p0 A v i) i)
          (matVecPairs A v i)) := by
  obtain ⟨z, hp, hd, hl⟩ := Lanes.grid_done hs ha hL hx hby hbz hgy hgz hch hM hK hMK hm hb0
    hf0 hbA hbV hfA hfV hA hV
  exact ⟨z, hp, hd, rows_of_loads hs ha hL hx hby hbz hgy hgz hch hM hK hMK hMx hm hb0 hf0 hbA hbV
    hfA hfV hA hV hl⟩

/-- Test: `word_warpDot_nanEq` at one block of 32 threads, `M = 1`, `K = 4`, row 0
(`MojoProofTest.GemvWarpRun.w0`, `w0_pre`): lane 0's word and row 0's `warpDot` are the same word
or both NaNs. -/
example : NaNEq (total (w0.c w0.k) (w0.n 0) (w0.x 0) (w0.acc 0 16) (w0.acc 1 8) (w0.acc 2 4)
    (w0.acc 3 2) (w0.acc 4 1)) (warpDot true (lo w0 w0.r) (matVecPairs w0.A w0.v w0.r)) :=
  word_warpDot_nanEq w0 w0_pre

/-- Test: `grid_rows` at one block of 64 threads (`launch2 1 1 64 1`), `M = 2`, `K = 4`, the
output at block 3, the matrix `A24` and vector `GemvThread.v3` at blocks 1 and 2 of `n3`
(MojoProofTest/GemvWarpRun.lean), any `%4` and every address choice below `2 ^ 60` and oracle
whose start gives `(g, c)`: the start's grid steps to a done grid where rows 0 and 1 of the
output are their rows' `warpDot` up to NaNs. -/
example {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat} {g : Grid}
    {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 2), x4, .bits 32 (BitVec.ofNat 32 4)] n3 ch oracle =
        .ok (g, c)) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (launch2 1 1 64 1) c) i g z) ∧
      GPUProof.Done sig (z, launch2 1 1 64 1, c) ∧
      ∀ i : Fin 2, ∃ x, z.mem.load gemv.prog.layout (c (32 * i.val)).who 0 (.fp .float)
          ⟨3, ((i.val * 4 : Nat) : Int)⟩ (some 4) = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true
          (lo (Lanes.ofStart (launch2 1 1 64 1) g c (32 * i.val) 2 4 3 A24 GemvThread.v3 i) i)
          (matVecPairs A24 GemvThread.v3 i)) :=
  grid_rows hs rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl rfl hch (by decide)
    (by decide) (by decide) (by decide) (n3_caller.closed 0).above w64_pre.hb0 w64_pre.hf0
    w64_pre.hbA w64_pre.hbV w64_pre.hfA w64_pre.hfV w64_pre.hA w64_pre.hV

/-- Test: `grid_rows` at one block of 64 threads (`launch2 1 1 64 1`), `M = 1`, `K = 4`, the
output at block 3, the matrix `GemvThread.A3` and vector `GemvThread.v3` at blocks 1 and 2 of
`GemvThread.m3`, any `%4` and every address choice below `2 ^ 60` and oracle whose start gives
`(g, c)`: the second warp's row 1 is `M`, and the start's grid steps to a done grid where row 0
of the output is its row's `warpDot` up to NaNs. -/
example {ch : Nat → Nat} (hch : ∀ q, ch q < 2 ^ 60) {oracle : Nat → Nat → Nat} {g : Grid}
    {c : Nat → Ctx} {x4 : Val}
    (hs : Grid.start gemv.prog gemv.fn_0 (launch2 1 1 64 1) [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩,
      .ptr ⟨2, 0⟩, .bits 32 (BitVec.ofNat 32 1), x4, .bits 32 (BitVec.ofNat 32 4)]
        GemvThread.m3 ch oracle = .ok (g, c)) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (launch2 1 1 64 1) c) i g z) ∧
      GPUProof.Done sig (z, launch2 1 1 64 1, c) ∧
      ∀ i : Fin 1, ∃ x, z.mem.load gemv.prog.layout (c (32 * i.val)).who 0 (.fp .float)
          ⟨3, ((i.val * 4 : Nat) : Int)⟩ (some 4) = .ok (Val.ofFloat .float x) ∧
        NaNEq x (warpDot true (lo (Lanes.ofStart (launch2 1 1 64 1) g c (32 * i.val) 1 4 3
          GemvThread.A3 GemvThread.v3 i) i) (matVecPairs GemvThread.A3 GemvThread.v3 i)) :=
  grid_rows hs rfl (launch2_valid (by decide)) (by decide) rfl rfl rfl rfl hch (by decide)
    (by decide) (by decide) (by decide) (GemvThread.m3_caller.closed 0).above w0_pre.hb0
    w0_pre.hf0 w0_pre.hbA w0_pre.hbV w0_pre.hfA w0_pre.hfV w0_pre.hA w0_pre.hV

end MojoProofTest.GemvWarpWord
