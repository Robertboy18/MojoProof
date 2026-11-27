import MojoProofTest.GemvEntryRun
import MojoProofTest.GemvLoopTail
import MojoProof.Sym.Canon
import MojoProof.Sym.WaitAt

/-!
# gemv_kernel's thread from its start to its `ret`

One thread of gemv_kernel (`gemv`, MojoProofTest/SymLane.lean, gemv_kernel float32 `b79a852b`)
from position 0 of its entry block `%6`, as the start leaves it (`Grid.start_thread`: the only
frame, no `alloca` blocks), to its `ret`, through its seven shuffles: `run` composes
`MojoProofTest.GemvEntryRun.entry` (`%6` to statement 41, the two `shfl.sync.idx` calls),
`MojoProofTest.GemvLoop.run` (the loop, at every `K`) and `MojoProofTest.GemvLoopTail.thread`
(`%78`'s five `shfl.sync.bfly` calls and the `ret`), as `MojoProofTest.GemvLoopTail.to_ret` joins
the last two. The bridge facts:

* `Mem.Buffer.ne_slot` (MojoProof/Sym/Slot.lean): a buffer is not one of the thread's
  slots (its space is 1, theirs 0);
* `EntryInv.keep`: so the memory at statement 41 has the input and output buffers of the memory
  the second shuffle delivers;
* `live_out`: the output block stays live at the end, since only the three slots die.

Every wait is stated as `Piece.Wait.via` states it (position, call, argument values, memory).
The memory at `%78`'s first shuffle is `waitAt c [d₁, d₂] t m` (MojoProof/Sym/WaitAt.lean), the
memory at the thread's wait after the first two deliveries, one memory for every value of the
other five (`RunsVia.pin`, `RunsVia.waitAt`): the memory the second delivers with the three slots
dead.
The values the other lanes' shuffles deliver are premises. `run_out`: the final memory as one
memory (`out`), the final predicate `WarpRun.of_waits` takes; `waits_range`: the seven waits as
`WarpRun.of_waits` takes them, the `i`-th of one list for `i < 7`.

The instance: thread 3 of one block of 32 threads, `M = 1`, `K = 4`, row 0, on `m3 = mem A3 v3`
(`mem`: the caller's memory at every sizes, its premises `mem_caller`), whose blocks 1 and 2 hold a
`1 × 4` matrix and a vector of binary32 words. Thread 3 starts after lanes 0 to 2's `alloca`s
(`mUpTo 3`), and `Grid.fire` delivers `%24` and `%25`, the halves of row 0, on the memory with every
lane's `alloca` blocks (`mUpTo 32`): every premise of `run` holds, thread 3's slots by `lane3_inv`
(the other lanes allocate at other numbers) and the buffers by `mUpTo_blocks`. `allocas_mutant`:
with an `alloca` block in the frame the final memory differs (the premise `f.allocas = []`);
`slots_mutant`: the memory with every other lane's slots but not thread 3's does not meet
`EntryInv`, and `%9`'s store faults there; `lane3_counts`: `run`'s step count, pairs and lane.
-/

namespace MojoProofTest.GemvThread

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvLoop MojoProofTest.GemvLoopTail MojoProofTest.GemvEntryRun
open FloatLib.Floats.Formats.BinaryInterchange

/-- **The buffers through the entry block**: for every thread `who`, block numbers `b7`, `b8`,
`b9`, memories `m₀`, `m` and buffer `q` of `m₀`: if the three blocks are `who`'s slots in `m₀`
(`EntryInv` at `m₀`) and `m` has `m₀`'s other blocks with the three as slots (`EntryInv`), then
`m` has `m₀`'s block `q`, the premise of `Mem.Buffer.of_block`, `Mem.Fits.of_block` and
`Mem.Holds.of_block`. -/
theorem EntryInv.keep {who b7 b8 b9 : Nat} {m₀ m : Mem} {q size al : Nat} {w : Bool}
    (h₀ : EntryInv who b7 b8 b9 m₀ m₀) (h : EntryInv who b7 b8 b9 m₀ m)
    (hq : m₀.Buffer q size al w) : ∀ x, m₀.blocks q = some x → m.blocks q = some x := by
  intro x hx
  rw [h.2.2.2 q (hq.ne_slot h₀.1) (hq.ne_slot h₀.2.1) (hq.ne_slot h₀.2.2.1)]
  exact hx

/-- **The output block stays live**: for every memories `my`, `m'`, layout, thread `w`, value
`x`, block numbers `p0`, `b7`, `b8`, `b9` with `p0` not one of the three, offset `o` and
proposition `z` (for gemv_kernel, lane 0): if `p0` is live in `my` and `m'` is `me` with `b9`,
`b8`, `b7` dead, where `me` is `my` with `x` stored at offset `o` of `p0` if `z` and `my`
otherwise (`run`'s final memory), then `p0` is live in `m'`. -/
theorem live_out {l : Layout} {w : Who} {x : Val} {p0 b7 b8 b9 : Nat} {o : Int} {my m' : Mem}
    {z : Prop} (h7 : p0 ≠ b7) (h8 : p0 ≠ b8) (h9 : p0 ≠ b9) (hl : my.liveAt p0 = true)
    (h : ∃ me, (z → my.store l w 0 (.fp .float) x ⟨p0, o⟩ (some 4) = .ok me) ∧
      (¬z → me = my) ∧ m' = [b9, b8, b7].foldl (fun m b => m.setLive b false) me) :
    m'.liveAt p0 = true := by
  obtain ⟨me, hs, ho, rfl⟩ := h
  simp only [List.foldl_cons, List.foldl_nil]
  rw [Mem.liveAt_setLive_ne _ _ h7, Mem.liveAt_setLive_ne _ _ h8, Mem.liveAt_setLive_ne _ _ h9]
  by_cases hz : z
  · rw [Mem.liveAt_store (hs hz)]; exact hl
  · rw [ho hz]; exact hl

/-- **A thread of gemv_kernel from its start to its `ret`, through its seven shuffles** (test of
one program, gemv_kernel float32 `b79a852b`). gemv_kernel, for every valid launch `L`, thread
`k`, context `c` (`c.prog = gemv.prog`, `c.env = L.env k`), thread `t` and memory `m` with:

* `t`'s only frame `f` at position 0 of `%6` with no `alloca` blocks (`Grid.start_thread`), `%0`,
  `%1`, `%2` pointers to offset 0 of blocks `p0`, `bA`, `bV` and `%3 = M`, `%5 = K` with
  `M, K < 2 ^ 31` and `M K < 2 ^ 61` (the arguments `Grid.start_arg` gives);
* the three `fresh` block numbers `b7`, `b8`, `b9` at `t.k`, `t.k + 1`, `t.k + 2` with no block
  in `m`;
* a row `r < M`, matrix `A` and vector `v`;
* the deliveries `d₁`, `d₂` of `%24` and `%25` (`entry`'s): the low and high halves of `r`, with
  the three blocks as the thread's slots in `d₂.2` (`EntryInv`), which holds `p0` as a writable
  buffer of `M` binary32 aligned to 4, `bA` and `bV` as read-only buffers of `M K` and `K`
  binary32 holding `A` and `v` row-major, all fitting.

Then the memory `M₀ = waitAt c [d₁, d₂] t m` (the memory at `t`'s wait from `m` after the deliveries
`d₁`, `d₂`) is `d₂.2` with the three slots dead (`EntryInv` at `d₂.2` and not live), its trace
extends `d₂.2`'s by the thread's accesses of the three slots (`SlotEv`) and reads of `bA` or `bV`
(`ReadEv`) only, and for all deliveries `d₃` to `d₇` of `%78`'s five shuffles, of the binary32 `z₁`
to `z₅`, with `d₇.2` holding `p0` as a writable buffer of `M` binary32 aligned to 4 that fits, the
thread waits at the two `shfl.sync.idx` calls as `entry` states them (full mask, the row word's
halves, source lane 0, clamp 31, on `slots c t.k m b7 b8 b9` and `d₁.2`) and at `%78`'s five
`shfl.sync.bfly` calls as `waits` states them at step `n`, sum `x` and memory `M₀`, resumed each
time with the delivery, and runs to its end on a memory that is `me` with `b9`, `b8`, `b7` dead,
where `me` is, for lane 0, `d₇.2` with `total c n x z₁ z₂ z₃ z₄ z₅` stored at element `r` of `p0`,
and for the other lanes `d₇.2`. Here `x` is the loop's `%79` (the `dotLoop` with contraction, oracle
numbers `oG c (t.k + 41)`, of every 32nd factor pair of row `r` from pair `laneid`) and
`n = t.k + 41 + 21 + 19 a + 15 (⌈K / 32⌉ - a)` with `a = (K + 31 - laneid) / 32`. -/
theorem run (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (t : Thread) (m : Mem) (f : Frame) (ht : t.frames = [f])
    (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label) (hpc : f.pc = 0)
    (hfa : f.allocas = []) (M K r p0 bA bV : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31)
    (hMK : M * K < 2 ^ 61) (hr : r < M)
    (h0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (h1 : f.regs 1 = some (.ptr ⟨bA, 0⟩))
    (h2 : f.regs 2 = some (.ptr ⟨bV, 0⟩)) (h3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)))
    (h5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (b7 b8 b9 : Nat) (hb7 : m.fresh c.who.thread t.k = b7)
    (hb8 : m.fresh c.who.thread (t.k + 1) = b8) (hb9 : m.fresh c.who.thread (t.k + 2) = b9)
    (hnx : 0 < m.next) (hm7 : m.blocks b7 = none) (hm8 : m.blocks b8 = none)
    (hm9 : m.blocks b9 = none)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (d₁ d₂ : Option Val × Mem)
    (hd₁ : d₁.1 = some (.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32)))
    (hd₂ : d₂.1 = some (.bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)))
    (hI : EntryInv c.who.thread b7 b8 b9 d₂.2 d₂.2)
    (hb0 : d₂.2.Buffer p0 (M * 4) 4 true) (hf0 : d₂.2.Fits gemv.prog.layout p0 (M * 4))
    (hbA : d₂.2.Buffer bA (M * K * 4) 4 false) (hbV : d₂.2.Buffer bV (K * 4) 4 false)
    (hfA : d₂.2.Fits gemv.prog.layout bA (M * K * 4))
    (hfV : d₂.2.Fits gemv.prog.layout bV (K * 4))
    (hA : d₂.2.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : d₂.2.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    (EntryInv c.who.thread b7 b8 b9 d₂.2 (waitAt c [d₁, d₂] t m) ∧
      (waitAt c [d₁, d₂] t m).liveAt b7 = false ∧ (waitAt c [d₁, d₂] t m).liveAt b8 = false ∧
      (waitAt c [d₁, d₂] t m).liveAt b9 = false ∧
      Ext (fun e => SlotEv c.who b7 b8 b9 e ∨ ReadEv bA bV e) d₂.2 (waitAt c [d₁, d₂] t m)) ∧
      ∀ (d₃ d₄ d₅ d₆ d₇ : Option Val × Mem) (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt),
      d₃.1 = some (Val.ofFloat .float z₁) → d₄.1 = some (Val.ofFloat .float z₂) →
      d₅.1 = some (Val.ofFloat .float z₃) → d₆.1 = some (Val.ofFloat .float z₄) →
      d₇.1 = some (Val.ofFloat .float z₅) →
      d₇.2.Buffer p0 (M * 4) 4 true → d₇.2.Fits gemv.prog.layout p0 (M * 4) →
      RunsVia c (fun m' => ∃ me, ((L.env k).laneid = 0 →
          d₇.2.store gemv.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
            (total c (t.k + 41 + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
                15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32))
              (dotLoop true (oG c (t.k + 41)) (Model.zero _ false)
                (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩))) z₁ z₂ z₃ z₄ z₅))
            ⟨p0, ((r * 4 : Nat) : Int)⟩ (some 4) = .ok me) ∧
          ((L.env k).laneid ≠ 0 → me = d₇.2) ∧
          m' = [b9, b8, b7].foldl (fun m b => m.setLive b false) me)
        (Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨17, .shfl .idx,
            [.bits 32 (BitVec.ofInt 32 (-1)),
              .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
                (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 0 32),
              .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)],
            slots c t.k m b7 b8 b9, d₁⟩ ::
          Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨18, .shfl .idx,
            [.bits 32 (BitVec.ofInt 32 (-1)),
              .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
                (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 32 32),
              .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩ ::
          waits c (t.k + 41 + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
              15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32))
            (dotLoop true (oG c (t.k + 41)) (Model.zero _ false)
              (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩))) z₁ z₂ z₃ z₄
            (waitAt c [d₁, d₂] t m) d₃ d₄ d₅ d₆ d₇) t m := by
  generalize hn : t.k + 41 + 21 + 19 * ((K + 31 - (L.env k).laneid) / 32) +
    15 * ((K + 31) / 32 - (K + 31 - (L.env k).laneid) / 32) = n
  generalize hx : dotLoop true (oG c (t.k + 41)) (Model.zero _ false)
    (stride 32 (L.env k).laneid (matVecPairs A v ⟨r, hr⟩)) = x
  have key : ∀ y : (Option Val × Mem) × (Option Val × Mem) × (Option Val × Mem) ×
      (Option Val × Mem) × (Option Val × Mem) × Model FloatTy.float.fmt ×
      Model FloatTy.float.fmt × Model FloatTy.float.fmt × Model FloatTy.float.fmt ×
      Model FloatTy.float.fmt,
      (match y with
        | (d₃, d₄, d₅, d₆, d₇, z₁, z₂, z₃, z₄, z₅) =>
          d₃.1 = some (Val.ofFloat .float z₁) ∧ d₄.1 = some (Val.ofFloat .float z₂) ∧
          d₅.1 = some (Val.ofFloat .float z₃) ∧ d₆.1 = some (Val.ofFloat .float z₄) ∧
          d₇.1 = some (Val.ofFloat .float z₅) ∧
          d₇.2.Buffer p0 (M * 4) 4 true ∧ d₇.2.Fits gemv.prog.layout p0 (M * 4)) →
      RunsVia c (match y with
        | (_, _, _, _, d₇, z₁, z₂, z₃, z₄, z₅) => fun m' => ∃ me, ((L.env k).laneid = 0 →
          d₇.2.store gemv.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
            (total c n x z₁ z₂ z₃ z₄ z₅)) ⟨p0, ((r * 4 : Nat) : Int)⟩ (some 4) = .ok me) ∧
          ((L.env k).laneid ≠ 0 → me = d₇.2) ∧
          m' = [b9, b8, b7].foldl (fun m b => m.setLive b false) me)
        ([Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨17, .shfl .idx,
            [.bits 32 (BitVec.ofInt 32 (-1)),
              .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
                (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 0 32),
              .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)],
            slots c t.k m b7 b8 b9, d₁⟩,
          Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨18, .shfl .idx,
            [.bits 32 (BitVec.ofInt 32 (-1)),
              .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
                (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 32 32),
              .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩] ++
          (fun u i xs me => (Piece.Wait.via gemv.fn_0 gemv.fn_0.b_10.label ⟨2, .shfl .bfly,
            [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float x, .bits 32 (BitVec.ofInt 32 16),
              .bits 32 (BitVec.ofInt 32 31)], me, d₁⟩).1 u i xs me ∧
            (EntryInv c.who.thread b7 b8 b9 d₂.2 me ∧ me.liveAt b7 = false ∧
              me.liveAt b8 = false ∧ me.liveAt b9 = false ∧
              Ext (fun e => SlotEv c.who b7 b8 b9 e ∨ ReadEv bA bV e) d₂.2 me), y.1) ::
          (match y with
            | (d₃, d₄, d₅, d₆, d₇, z₁, z₂, z₃, z₄, _) =>
              (waits c n x z₁ z₂ z₃ z₄ m d₃ d₄ d₅ d₆ d₇).tail)) t m := by
    rintro ⟨d₃, d₄, d₅, d₆, d₇, z₁, z₂, z₃, z₄, z₅⟩ ⟨e₃, e₄, e₅, e₆, e₇, hy, hfy⟩
    refine entry c hcp L hL k hce t m f [] ht hf hlb hpc p0 bA bV M K h0 h1 h2 h3 h5 b7 b8 b9 hb7
      hb8 hb9 hnx hm7 hm8 hm9 d₁ d₂ _ _ hd₁ hd₂ hI _ _ ?_
    intro t' m' f' ht' hf' hl' hp' ha' hk' g0 g1 g2 _ _ g10 g11 g35 hI' l7 l8 l9 hX'
    have hq := fun {q size al w} (hB : d₂.2.Buffer q size al w) => EntryInv.keep hI hI' hB
    obtain ⟨m₀, hb₀, hX₀, hT⟩ := to_ret L hL k c hcp hce t' m' f' ht' hf' hl' hp' M K r p0 bA bV hM
      hK hMK hr g0 g1 g2 g10 g11 g35 (hb0.of_block (hq hb0)) (hf0.of_block (hq hb0))
      (hbA.of_block (hq hbA)) (hbV.of_block (hq hbV)) (hfA.of_block (hq hbA))
      (hfV.of_block (hq hbV)) A v (hA.of_block (hq hbA)) (hV.of_block (hq hbV))
    have h := hT d₃ d₄ d₅ d₆ d₇ z₁ z₂ z₃ z₄ z₅ e₃ e₄ e₅ e₆ e₇ hy hfy
    rw [hk', ha', hfa, List.append_nil, hn, hx] at h
    simp only [waits, shfls, List.map_cons, List.map_nil] at h
    refine RunsVia.imp_head h fun u i xs me ⟨a₁, a₂, a₃, a₄⟩ => ⟨⟨a₁, a₂, a₃, rfl⟩, ?_⟩
    subst a₄
    exact ⟨hI'.of_blocks hb₀, (Mem.liveAt_blocks (congrFun hb₀ _)).trans l7,
      (Mem.liveAt_blocks (congrFun hb₀ _)).trans l8,
      (Mem.liveAt_blocks (congrFun hb₀ _)).trans l9,
      Ext.trans (hX'.mono fun _ => Or.inl) (hX₀.mono fun _ => Or.inr)⟩
  obtain ⟨M₀, hF, hM⟩ := RunsVia.pin (R := fun M₀ =>
    (Piece.Wait.via gemv.fn_0 gemv.fn_0.b_10.label ⟨2, .shfl .bfly,
      [.bits 32 (BitVec.ofInt 32 (-1)), .ofFloat .float x, .bits 32 (BitVec.ofInt 32 16),
        .bits 32 (BitVec.ofInt 32 31)], M₀, d₁⟩).1) (fun _ _ _ _ h => h.1) _ key
  let o := Model.zero FloatTy.float.fmt false
  let e : Option Val × Mem := (some (.ofFloat .float o), d₂.2)
  obtain ⟨-, -, -, -, hF₀⟩ := hF (e, e, e, e, e, o, o, o, o, o) ⟨rfl, rfl, rfl, rfl, rfl, hb0, hf0⟩
  obtain ⟨-, -, -, -, -, -, he⟩ :=
    RunsVia.waitAt _ (hM (e, e, e, e, e, o, o, o, o, o) ⟨rfl, rfl, rfl, rfl, rfl, hb0, hf0⟩)
  replace he : waitAt c [d₁, d₂] t m = M₀ := he
  subst he
  exact ⟨hF₀, fun d₃ d₄ d₅ d₆ d₇ z₁ z₂ z₃ z₄ z₅ e₃ e₄ e₅ e₆ e₇ hy hfy =>
    hM (d₃, d₄, d₅, d₆, d₇, z₁, z₂, z₃, z₄, z₅) ⟨e₃, e₄, e₅, e₆, e₇, hy, hfy⟩⟩

/-- **A thread's final memory**, as `run` states it: for every layout `l`, thread `w`, value `x`,
block numbers `p0`, `b7`, `b8`, `b9`, offset `o`, decidable proposition `z` and memory `my`: `my`
with `x` stored as a binary32 at offset `o` of `p0` if `z` (and `my` if that store faults), then
`b9`, `b8`, `b7` dead. A test definition. -/
def out (l : Layout) (w : Who) (x : Val) (p0 b7 b8 b9 : Nat) (o : Int) (z : Prop) [Decidable z]
    (my : Mem) : Mem :=
  [b9, b8, b7].foldl (fun m b => m.setLive b false)
    (if z then (match my.store l w 0 (.fp .float) x ⟨p0, o⟩ (some 4) with
      | .ok me => me
      | .error _ => my) else my)

/-- **`run`'s final memory as one memory**, the form `WarpRun.of_waits` takes (`(· = M J (j + 1))`):
for every context, waits, thread `t`, memory `m`, layout, thread `w`, value `x`, block numbers,
offset, decidable `z` and memory `my`: a run from `t` on `m` through the waits whose final memory
is `my` with `x` stored at `p0` if `z` (the store succeeding) and `my` otherwise, then `b9`, `b8`,
`b7` dead (`run`'s final predicate, with `z` lane 0 and `my` the last delivery's memory), is one
whose final memory is `out`'s (`RunsVia.imp`). -/
theorem run_out {c : Ctx}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))} {t : Thread}
    {m : Mem} {l : Layout} {w : Who} {x : Val} {p0 b7 b8 b9 : Nat} {o : Int} {z : Prop}
    [Decidable z] {my : Mem}
    (h : RunsVia c (fun m' => ∃ me, (z → my.store l w 0 (.fp .float) x ⟨p0, o⟩ (some 4) = .ok me) ∧
      (¬z → me = my) ∧ m' = [b9, b8, b7].foldl (fun m b => m.setLive b false) me) ws t m) :
    RunsVia c (· = out l w x p0 b7 b8 b9 o z my) ws t m :=
  h.imp fun _ ⟨_, hs, ho, he⟩ => by
    rw [he, out]
    by_cases hz : z
    · rw [ite_eq_left hz, hs hz]
    · rw [ite_eq_right hz, ho hz]

/-- **A lane's seven waits as `WarpRun.of_waits` takes them**: for every two waits `w₁`, `w₂` of
`%6` (`run`'s, at statements 17 and 18) and every context, step, sums, memory and deliveries of
`%78`'s five (`shfls`), `run`'s list of waits is `(List.range 7).map` of the `i`-th wait of
`[w₁, w₂] ++ shfls …` (`List.getD` with any default `d`) at block `%6` (label 6) for `i < 2`
and `%78` (label 65) after (`Piece.Wait.map_via_append`). -/
theorem waits_range (w₁ w₂ d : Piece.Wait) (c : Ctx) (k0 : Nat)
    (x z₁ z₂ z₃ z₄ : Model FloatTy.float.fmt) (m : Mem) (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) :
    Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label w₁ ::
        Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label w₂ ::
        waits c k0 x z₁ z₂ z₃ z₄ m d₁ d₂ d₃ d₄ d₅ =
      (List.range 7).map fun i => (([w₁, w₂] ++ shfls c k0 x z₁ z₂ z₃ z₄ m d₁ d₂ d₃ d₄ d₅).getD i
        d).via gemv.fn_0 (if i < 2 then 6 else 65) :=
  Piece.Wait.map_via_append (a := [w₁, w₂]) (p := 2) (n := 5) rfl rfl

/-! ## The instance: lane 3 of one block of 32 threads, `M = 1`, `K = 4`

The caller's memory is generated once for every sizes: `mem A v` has blocks 1 and 2 holding a
matrix `A` (`M × K`) and a vector `v` (length `K`) of binary32 words and block 3 a writable
output of `M` words; `mem_caller` proves on it gemv_kernel's memory premises (`Caller`: the
closed memory, buffers, fits and holds, as `GemvSound.kernel_sound` takes them) for every `M`,
`K < 2 ^ 31` with `M K < 2 ^ 61`. `m3_caller` is its instance at `m3`, and
`GemvWarpRun.n3_caller` at the two warps' memory. -/

/-- The `1 × 4` matrix of binary32 ones. -/
def A3 : TorchLean.Tensor (Model FloatTy.float.fmt) [1, 4] :=
  TorchLean.Tensor.Rep.ofFn fun _ => Model.ofNatBits 0x3f800000

/-- The vector of four binary32 twos. -/
def v3 : TorchLean.Tensor (Model FloatTy.float.fmt) [4] :=
  TorchLean.Tensor.Rep.ofFn fun _ => Model.ofNatBits 0x40000000

/-- gemv_kernel's caller memory, for every sizes `M`, `K`, matrix `A` (`M × K`) and vector `v`
(length `K`) of binary32 words: from the empty memory, block 1 holding `A`'s bytes and block 2
`v`'s (`tensorBytes`, read-only), and block 3 a writable output of `M` undefined words, all
global, live and owned by all threads, at addresses 16, 32 and 48 in space 1 and in the generic
space. It is `Mem.three` at these sizes, flags and bytes, by unfolding. A test definition. -/
def mem {M K : Nat} (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) : Mem :=
  let m₁ := (({} : Mem).alloc gemv.prog.layout 1
    (TorchLean.Shape.size [M, K] * gemv.prog.layout.size (.fp .float)) 16 true true .all 1 1
    (tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) A)).1
  let m₂ := (m₁.alloc gemv.prog.layout 1
    (TorchLean.Shape.size [K] * gemv.prog.layout.size (.fp .float)) 16 true true .all 2 2
    (tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) v)).1
  (m₂.alloc gemv.prog.layout 1 (M * gemv.prog.layout.size (.fp .float)) 16 true false .all 3 3).1

/-- gemv_kernel's premises on the caller's memory, as `GemvSound.kernel_sound` takes them, for
every memory `m`, block numbers `p0` (the output), `bA` and `bV` (the inputs), sizes `M`, `K`,
matrix `A` (`M × K`) and vector `v` (length `K`) of binary32 words: `m` is closed for gemv_kernel's
six arguments at every word `%4`, `p0` is a writable buffer of `M` words and `bA`, `bV` are
read-only buffers of `M K` and `K` words, at addresses 4 divides, that fit (`Mem.Fits`), and `bA`,
`bV` hold `A` and `v` row-major from offset 0. A test definition. -/
structure Caller (m : Mem) (p0 bA bV M K : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) : Prop where
  /-- Builds `Caller` from its nine fields. -/
  mk ::
  /-- `m` is closed for the arguments, at every word `%4`. -/
  closed : ∀ x4 : BitVec 32, m.Closed [.ptr ⟨p0, 0⟩, .ptr ⟨bA, 0⟩, .ptr ⟨bV, 0⟩,
    .bits 32 (BitVec.ofNat 32 M), .bits 32 x4, .bits 32 (BitVec.ofNat 32 K)]
  /-- `p0` is a writable buffer of `M` words. -/
  hb0 : m.Buffer p0 (M * 4) 4 true
  /-- `p0` fits. -/
  hf0 : m.Fits gemv.prog.layout p0 (M * 4)
  /-- `bA` is a read-only buffer of `M K` words. -/
  hbA : m.Buffer bA (M * K * 4) 4 false
  /-- `bV` is a read-only buffer of `K` words. -/
  hbV : m.Buffer bV (K * 4) 4 false
  /-- `bA` fits. -/
  hfA : m.Fits gemv.prog.layout bA (M * K * 4)
  /-- `bV` fits. -/
  hfV : m.Fits gemv.prog.layout bV (K * 4)
  /-- `bA` holds `A` row-major from offset 0. -/
  hA : m.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
    (rowMajor gemv.prog.layout (.fp .float) 0) A
  /-- `bV` holds `v` row-major from offset 0. -/
  hV : m.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
    (rowMajor gemv.prog.layout (.fp .float) 0) v

/-- **The caller memory meets gemv_kernel's memory premises** (test of gemv_kernel's premises, for
every sizes `M`, `K < 2 ^ 31` with `M K < 2 ^ 61`, matrix `A` and vector `v`): `mem A v` meets
`Caller` with the output at block 3 and `A`, `v` at blocks 1 and 2 (`Mem.three_spec` at
alignment 16, which 4 divides, and `Mem.holds_alloc`). -/
theorem mem_caller {M K : Nat} (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) : Caller (mem A v) 3 1 2 M K A v := by
  have h4 : gemv.prog.layout.size (.fp .float) = 4 := rfl
  have hw0 : (gemv.prog.layout.ptr 0).1 = 64 := rfl
  have hw1 : (gemv.prog.layout.ptr 1).1 = 64 := rfl
  have hn : ∀ x : Model FloatTy.float.fmt, (Val.ofFloat .float x).NamesIn fun _ => False :=
    fun _ => by simp [Val.NamesIn, Val.ofFloat]
  have h := Mem.three_spec gemv.prog.layout 16
    ![TorchLean.Shape.size [M, K] * gemv.prog.layout.size (.fp .float),
      TorchLean.Shape.size [K] * gemv.prog.layout.size (.fp .float),
      M * gemv.prog.layout.size (.fp .float)] ![true, true, false]
    (I := ![tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) A,
      tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) v, []])
    (fun i p j hp => by
      fin_cases i <;> simp at hp
      exacts [tensorBytes_namesIn hn A p j hp, tensorBytes_namesIn hn v p j hp])
    (A := ![1, 2, 3]) (G := ![1, 2, 3]) (n := ![M * K * 4, K * 4, M * 4])
    (fun i => by fin_cases i <;> simp [TorchLean.Shape.size, h4])
    (fun i => by fin_cases i <;> simp [hw1])
    (fun i => by fin_cases i <;> simp [hw0] <;> omega)
  have al : ∀ {q n : Nat} {w : Bool}, (mem A v).Buffer q n 16 w → (mem A v).Buffer q n 4 w :=
    fun ⟨b, hb, hs, hl, ho, hr, hn, ha, hg⟩ =>
      ⟨b, hb, hs, hl, ho, hr, hn, dvd_trans (by decide) ha, dvd_trans (by decide) hg⟩
  obtain ⟨bx, hbx, hx⟩ := Mem.holds_alloc (Layout.Codec.float _ .float) A ({} : Mem) 1 16 true
    true .all 1 1
  obtain ⟨by', hby, hy⟩ := Mem.holds_alloc (Layout.Codec.float _ .float) v
    (({} : Mem).alloc gemv.prog.layout 1
      (TorchLean.Shape.size [M, K] * gemv.prog.layout.size (.fp .float)) 16 true true .all 1 1
      (tensorBytes gemv.prog.layout (.fp .float) (Val.ofFloat .float) A)).1 1 16 true true .all 2 2
  exact ⟨fun _ => h.1 _ (by simp only [Val.bounds, Val.bound]; omega), al (h.2 2).1, (h.2 2).2,
    al (h.2 0).1, al (h.2 1).1, (h.2 0).2, (h.2 1).2, ⟨bx, hbx, hx⟩, ⟨by', hby, hy⟩⟩

/-- The memory of one warp's instance: `mem` at `A3` and `v3`, `M = 1`, `K = 4`, the output a
block of 4 bytes. A test definition. -/
def m3 : Mem := mem A3 v3

/-- Test: `mem_caller` at `m3`, `M = 1`, `K = 4`. -/
theorem m3_caller : Caller m3 3 1 2 1 4 A3 v3 :=
  mem_caller (by decide) (by decide) (by decide) A3 v3

/-- Thread `i`'s context at one block of 32 threads: gemv's program, no globals, thread `i` of
block 0, every skeleton and oracle choice 0. -/
def cl (i : Nat) : Ctx :=
  ⟨gemv.prog, fun _ => none, (launch2 1 1 32 1).env i, ⟨i, 0⟩, fun _ => 0, fun _ => 0⟩

/-- The start's frame: position 0 of `%6`, the arguments `%0` to `%5` (blocks 3, 1, 2, `M = 1`,
0, `K = 4`), no `alloca` block. -/
def f3 : Frame :=
  ⟨gemv.fn_0, 6, 0, fun i => [Val.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩, .ptr ⟨2, 0⟩, .bits 32 (.ofNat 32 1),
    .bits 32 0, .bits 32 (.ofNat 32 4)][i]?, fun _ => none, [], none⟩

/-- `m3` after the three `alloca`s of threads `0, ..., j - 1`, each at its steps 0 to 2 and its
`Mem.fresh` numbers (`slotsAll`): the memory when the lanes run in turn, each to its first wait.
Thread 3 starts at `mUpTo 3` and allocates blocks 16, 17 and 18; `%24` and `%25` fire at
`mUpTo 32`, since no statement of `%6` before them but the `alloca`s touches memory (gemv IR
lines 8-26). -/
def mUpTo (j : Nat) : Mem := slotsAll cl (fun _ => 0) m3 (List.range j)

/-- `m3` after thread 3's three `alloca`s alone (blocks 16, 17, 18). -/
def s3 : Mem := slots (cl 3) 0 m3 16 17 18

/-- `Grid.fire`'s delivery of `%24` to thread 3 at row 0: the low half of row 0's word (lane 0's
offer, `idx_row` of MojoProofTest/GemvShfl.lean), on `mUpTo 32`, every lane's slots. -/
def e1 : Option Val × Mem := (some (.bits 32 ((BitVec.ofNat 64 0).extractLsb' 0 32)), mUpTo 32)

/-- `Grid.fire`'s delivery of `%25` to thread 3 at row 0: the high half of row 0's word, on
`mUpTo 32`. -/
def e2 : Option Val × Mem := (some (.bits 32 ((BitVec.ofNat 64 0).extractLsb' 32 32)), mUpTo 32)

/-- For every number of lanes `j`: `mUpTo j` has `m3`'s blocks 1, 2 and 3, the launch's
buffers, since the `alloca` numbers are not below `m3.next = 4` (`slotsAll_off`,
`Mem.not_freshOf_lt`). -/
theorem mUpTo_blocks (j : Nat) {q : Nat} (hq : q < 4) :
    ∀ x, m3.blocks q = some x → (mUpTo j).blocks q = some x :=
  (slotsAll_off cl (fun _ => 0) m3 (List.range j)).block (Mem.not_freshOf_lt hq)

/-- **Thread 3's slots through the other lanes' `alloca`s**: `mUpTo 32` meets `run`'s premise
`EntryInv` at thread 3's blocks 16, 17 and 18. Thread 3's own `alloca`s give it at `mUpTo 4`
(by evaluation); threads 4 to 31 allocate only at their own numbers (`slotsAll_off`), which are
not thread 3's (`Mem.not_freshOf`), so `EntryInv.frame` keeps it. -/
theorem lane3_inv : EntryInv 3 16 17 18 (mUpTo 32) (mUpTo 32) := by
  have hn : ¬ ∃ i ∈ List.range' 4 28, (cl i).who.thread = 3 := by decide
  have hr : List.range 32 = List.range 4 ++ List.range' 4 28 := by decide
  have e : mUpTo 32 = slotsAll cl (fun _ => 0) (mUpTo 4) (List.range' 4 28) := by
    unfold mUpTo slotsAll
    rw [hr, List.foldl_append]
  have h := fun k => Mem.not_freshOf (m := mUpTo 4)
    (N := fun n => ∃ i ∈ List.range' 4 28, (cl i).who.thread = n) (n := 3) hn k
  rw [e]
  exact EntryInv.frame (m₀ := mUpTo 4) (m := mUpTo 4)
    ⟨by decide +kernel, by decide +kernel, by decide +kernel, fun _ _ _ _ => rfl⟩
    (slotsAll_off _ _ _ _) (h 0) (h 1) (h 2)

/-- Test: `run` at thread 3 of one block of 32 threads, `M = 1`, `K = 4`, row 0, thread
`⟨[f3], 0⟩`, start memory `mUpTo 3` (lanes 0 to 2 ran first), `A3`, `v3` and `Grid.fire`'s
deliveries `e1`, `e2` on the memory with every lane's slots: every premise holds, so the memory
at thread 3's first `%78` shuffle, `waitAt (cl 3) [e1, e2] ⟨[f3], 0⟩ (mUpTo 3)`, has the output
block 3 as `mUpTo 32` has it, and block 16, thread 3's `%7`, dead. -/
example : (waitAt (cl 3) [e1, e2] ⟨[f3], 0⟩ (mUpTo 3)).blocks 3 = (mUpTo 32).blocks 3 ∧
    (waitAt (cl 3) [e1, e2] ⟨[f3], 0⟩ (mUpTo 3)).liveAt 16 = false := by
  have h := run (launch2 1 1 32 1) (launch2_valid (by decide)) 3 (cl 3) rfl rfl ⟨[f3], 0⟩
    (mUpTo 3) f3 rfl rfl (by decide +kernel) rfl rfl 1 4 0 3 1 2 (by decide) (by decide)
    (by decide) (by decide) rfl rfl rfl rfl rfl 16 17 18 rfl rfl rfl (by decide) rfl rfl rfl A3 v3
    e1 e2 rfl rfl lane3_inv
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hb0)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hf0)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hbA)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hbV)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hfA)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hfV)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hA)
    (.of_block (mUpTo_blocks 32 (by decide)) m3_caller.hV)
  exact ⟨h.1.1.2.2.2 3 (by decide) (by decide) (by decide), h.1.2.1⟩

/-- Test (gemv_kernel at one block of 32 threads, `M = 1`, `K = 4`, lane 3, for every memories
`M`, `M'`): a change by lane 2 that `run` concludes `EntryInv` of (its blocks 10, 11, 12, as its
slot stores and liveness changes do) keeps lane 3's `EntryInv` and the buffer at 3
(`EntryInv.off`, `EntryInv.frame`, `Mem.SameOff.block`). -/
example {M M' : Mem} (h : EntryInv 2 10 11 12 M M') (h3 : EntryInv 3 16 17 18 M M)
    (hb : M.Buffer 3 4 4 true) : EntryInv 3 16 17 18 M' M' ∧ M'.Buffer 3 4 4 true :=
  ⟨h3.frame h.off (by decide) (by decide) (by decide), hb.of_block (h.off.block (by decide))⟩

/-- **Mutant: a frame with an `alloca` block** (test of gemv_kernel at one block of 32 threads,
`M = 1`, `K = 4`, lane 3): `run`'s premise `f.allocas = []` is needed. The `ret` ends the
lifetimes of the frame's `alloca` blocks, `[b9, b8, b7] ++ f.allocas` (`entry`'s continuation),
so with `f.allocas = [3]` block 3 is dead in the final memory (here lane 3's, `s3` with the
blocks ended), while in `run`'s final memory, with `b9, b8, b7` ended, it is live (`live_out`).
By `decide +kernel`. -/
theorem allocas_mutant :
    (([18, 17, 16] ++ [3]).foldl (fun (m : Mem) b => m.setLive b false) s3).liveAt 3 = false ∧
      ([18, 17, 16].foldl (fun (m : Mem) b => m.setLive b false) s3).liveAt 3 = true := by
  decide +kernel

/-- The memory with every lane's slots but thread 3's: `m3` after the `alloca`s of threads 0 to 2
and 4 to 31. -/
def mNo3 : Mem := slotsAll cl (fun _ => 0) m3 ((List.range 32).erase 3)

/-- **Mutant: the deliveries' memory without the lane's slots** (test of gemv_kernel at one block
of 32 threads, `M = 1`, `K = 4`, lane 3): `mNo3`, every other lane's slots but not thread 3's,
does not meet `run`'s premise `EntryInv` (block 16 is not a slot of thread 3), which `mUpTo 32`
meets (`lane3_inv`). There `%9`'s store (statement 21, `store i32 %24, ptr %9`, after the
`lifetime.end` and `lifetime.start` of block 18) faults with "access to no block", while on
`mUpTo 32` it succeeds. By `decide +kernel`. -/
theorem slots_mutant : ¬ EntryInv 3 16 17 18 mNo3 mNo3 ∧
    (match ((mNo3.setLive 18 false).setLive 18 true).store gemv.prog.layout ⟨3, 0⟩ 0 (.int 32)
        (.bits 32 ((BitVec.ofNat 64 0).extractLsb' 0 32)) ⟨18, 0⟩ (some 4) with
      | .error (.ub msg) => msg == "access to no block"
      | _ => false) = true ∧
    ((((mUpTo 32).setLive 18 false).setLive 18 true).store gemv.prog.layout ⟨3, 0⟩ 0 (.int 32)
        (.bits 32 ((BitVec.ofNat 64 0).extractLsb' 0 32)) ⟨18, 0⟩ (some 4)).isOk = true := by
  refine ⟨fun h => absurd h.1 (by decide +kernel), by decide +kernel, by decide +kernel⟩

/-- **Lane 3's counts** (arithmetic checks of `run`'s conclusion at one block of 32 threads,
`M = 1`, `K = 4`, lane 3, not premise mutants): lane 3's `laneid` is 3, not 0, so `run`'s final
memory stores nothing; its loop folds pair 3 of the row only (`stride 32 3`), not the row's four
pairs; and `%78`'s first shuffle is at step `t.k + 81` (`41 + 21 + 19`), not at `t.k + 40`, the
loop's count without the entry block's 41 steps. By `decide`. -/
theorem lane3_counts :
    ((launch2 1 1 32 1).env 3).laneid ≠ 0 ∧ stride 32 3 (List.range 4) = [3] ∧
      stride 32 3 (List.range 4) ≠ List.range 4 ∧
      41 + 21 + 19 * ((4 + 31 - 3) / 32) + 15 * ((4 + 31) / 32 - (4 + 31 - 3) / 32) = 81 ∧
      21 + 19 * ((4 + 31 - 3) / 32) + 15 * ((4 + 31) / 32 - (4 + 31 - 3) / 32) ≠ 81 := by
  decide

end MojoProofTest.GemvThread
