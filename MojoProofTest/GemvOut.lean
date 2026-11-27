import MojoProofTest.GemvThread

/-!
# gemv_kernel's thread whose row is `M` or more

A thread of gemv_kernel (`gemv`, MojoProofTest/SymLane.lean, gemv_kernel float32 `b79a852b`)
whose row word `%36` is `M` or more: `%42 = icmp sge %36, %10` holds, so `%6` branches to `%43`,
which branches to `%103`'s `ret` (gemv IR :49-59, :145-146). The thread stores nothing.

* `outPs`: the path from statement 41 of `%6` through `%43` to `%103`; `out_covers`: the path
  checker accepts it; `out_shape`: `%6`'s tail from statement 41 and both blocks have no effect;
* `out_path`: the path's premises hold at `M ≤ r`, the twin of
  `MojoProofTest.OblGemv.entry_edge` at the other direction of `%42`;
* `out_ret`: from statement 41 the thread runs to its end with its `alloca` blocks dead and
  every block's value kept (`Runs.of_retAt`);
* `run`: from position 0 of `%6`, as `MojoProofTest.GemvThread.run` states it, through `%24` and
  `%25` (`MojoProofTest.GemvEntryRun.entry`) to its end, on a memory with the second
  delivery's blocks outside the three `alloca` blocks and its trace extended by the thread's
  accesses of those blocks only.
-/

namespace MojoProofTest.GemvOut

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.SymRun MojoProofTest.SymSeg MojoProofTest.SymGemvTail MojoProofTest.OblGemv
open MojoProofTest.GemvEntryRun

/-- The path from statement 41 of `%6` (the row guard `%42`'s false successor is `%44`, its true
one `%43`) through `%43` to `%103`'s `ret` (local 45). A test definition. -/
def outPs : List (Nat × List Cond × Summary) := [gB 6 41, gB 43 0, gB 45 0]

/-- gemv_kernel's path `outPs` from statement 41 is covered: the path checker accepts it with and
without its `alloca` blocks' check (`decide +kernel`). -/
theorem out_covers : coversPathAt true true gemv.prog gemv.fn_0 41 outPs = true ∧
    coversPathWith true gemv.prog gemv.fn_0 41 outPs = true := by
  decide +kernel

/-- The shape `RetWith.of_first` takes, for gemv_kernel's path `outPs`: `%6`'s tail from
statement 41 has the memory obligation of its effects, `%43` and `%103` have no effects, the
last exit is `ret`, and the tail has no effects either (`decide +kernel`). -/
theorem out_shape : Cond.mem (gC 6 41).effs ∈ (gC 6 41).obls ∧
    (∀ b ∈ [gB 43 0, gB 45 0], b.2.2.effs = []) ∧
    outPs.getLast?.map (·.2.2.exit) = some .ret ∧ (gC 6 41).effs = [] := by
  decide +kernel

/-- **The row guard's edge to `%43`**: gemv_kernel, for every valid launch `L`, thread `k`,
context `c` (`c.prog = gemv.prog`, `c.env = L.env k`), step `s`, memory `m`, frame `f` of
`gemv.fn_0`, sizes `M < 2 ^ 31` and `K`, row `r` with `M ≤ r < 2 ^ 59` and output block `p0`
with: `%0` a pointer at offset 0 of `p0`, `%10 = M` and `%11 = K` (64 bits), `%35` the row's
halves and `p0` a writable buffer of `M` binary32 aligned to 4: the premises of the path
`outPs` (`%6` from statement 41, `%43`, `%103`) hold at `f`'s entry valuation (`WalkWith true`),
the twin of `MojoProofTest.OblGemv.entry_edge` with `M ≤ r` for `r < M`. The row word is
`row_node`'s. -/
theorem out_path (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (s : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0)
    (M K r p0 : Nat) (hM : M < 2 ^ 31) (hr : M ≤ r) (hr' : r < 2 ^ 59)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 M)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)))
    (h35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)]))
    (hb0 : m.Buffer p0 (M * 4) 4 true) :
    WalkWith true (Valuation.entry c s m f) outPs := by
  have h36 := row_node c s m f hf r h35
  unfold outPs
  mojo_obl

/-- **A thread whose row is `M` or more, from statement 41 to its end** (test of one program,
gemv_kernel float32 `b79a852b`). gemv_kernel, for every valid launch `L`, thread `k`, context
`c` (`c.prog = gemv.prog`, `c.env = L.env k`), thread `t` whose only frame `f` is at statement
41 of `%6`, memory `m`, sizes `M, K < 2 ^ 31`, row `r` with `M ≤ r < 2 ^ 59` and output block
`p0` with: `%0` a pointer at offset 0 of `p0`, `%10`, `%11` the `signExtend 64` of `M` and `K`
(`MojoProofTest.GemvEntryRun.entry`'s), `%35` the row's halves and `p0` a writable buffer of
`M` binary32 aligned to 4: the thread runs to its end on `m` with `f`'s `alloca` blocks dead
(`Runs.of_retAt` on `outPs`, whose blocks have no effect). -/
theorem out_ret (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (t : Thread) (m : Mem) (f : Frame) (ht : t.frames = [f])
    (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label) (hpc : f.pc = 41)
    (M K r p0 : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hr : M ≤ r) (hr' : r < 2 ^ 59)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (hr10 : f.regs 10 = some (.bits 64 ((BitVec.ofNat 32 M).signExtend 64)))
    (hr11 : f.regs 11 = some (.bits 64 ((BitVec.ofNat 32 K).signExtend 64)))
    (hr35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)]))
    (hb0 : m.Buffer p0 (M * 4) 4 true) :
    Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) m) := by
  have h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 M)) := by
    rw [hr10, (GPUProof.WordFit.of_lt (w := 32) hM).signExtend 64]
  have h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)) := by
    rw [hr11, (GPUProof.WordFit.of_lt (w := 32) hK).signExtend 64]
  have hR : RetWith true (Valuation.entry c t.k m f) (· = m) outPs :=
    RetWith.of_first ⟨out_shape.1, out_shape.2.1, out_shape.2.2.1⟩
      (out_path L hL k c hcp hce t.k m f hf M K r p0 hM hr hr' hr0 h10 h11 hr35 hb0)
      fun me hme => by
        rw [out_shape.2.2.2] at hme
        exact (Except.ok.inj hme).symm
  obtain ⟨me, hrun, rfl⟩ := Runs.of_retAt hcp out_covers.1 ht hf hlb hpc hR
  rw [Valuation.allocsWith_nil _ out_covers.2, List.nil_append] at hrun
  exact hrun

/-- **A thread whose row is `M` or more, from its start to its end, through its two shuffles**
(test of one program, gemv_kernel float32 `b79a852b`). gemv_kernel, for every valid launch `L`,
thread `k`, context `c` (`c.prog = gemv.prog`, `c.env = L.env k`), thread `t` and memory `m`
with:

* `t`'s only frame `f` at position 0 of `%6` with no `alloca` blocks, `%0`, `%1`, `%2` pointers
  to offset 0 of blocks `p0`, `bA`, `bV` and `%3 = M`, `%5 = K` with `M, K < 2 ^ 31`;
* the three `fresh` block numbers `b7`, `b8`, `b9` at `t.k`, `t.k + 1`, `t.k + 2` with no block
  in `m`, and `next` positive;
* a row `r` with `M ≤ r < 2 ^ 59`;
* the deliveries `d₁`, `d₂` of `%24` and `%25`: the low and high halves of `r`, with the three
  blocks as the thread's slots in `d₂.2` (`EntryInv`), which holds `p0` as a writable buffer of
  `M` binary32 aligned to 4.

Then the thread waits at the two `shfl.sync.idx` calls as `MojoProofTest.GemvThread.run` states
them (full mask, its row word's halves, source lane 0, clamp 31, on `slots c t.k m b7 b8 b9`
and `d₁.2`), resumed each time with the delivery, and runs to its end (`%43`, `%103`, `out_ret`)
on a memory with `d₂.2`'s blocks outside `b7`, `b8` and `b9` and a trace that extends `d₂.2`'s
by the thread's accesses of those three blocks only (`SlotEv`): it stores nothing else. -/
theorem run (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (t : Thread) (m : Mem) (f : Frame) (ht : t.frames = [f])
    (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label) (hpc : f.pc = 0)
    (hfa : f.allocas = []) (M K r p0 bA bV : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31)
    (hr : M ≤ r) (hr' : r < 2 ^ 59)
    (h0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (h1 : f.regs 1 = some (.ptr ⟨bA, 0⟩))
    (h2 : f.regs 2 = some (.ptr ⟨bV, 0⟩)) (h3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)))
    (h5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (b7 b8 b9 : Nat) (hb7 : m.fresh c.who.thread t.k = b7)
    (hb8 : m.fresh c.who.thread (t.k + 1) = b8) (hb9 : m.fresh c.who.thread (t.k + 2) = b9)
    (hnx : 0 < m.next) (hm7 : m.blocks b7 = none) (hm8 : m.blocks b8 = none)
    (hm9 : m.blocks b9 = none) (d₁ d₂ : Option Val × Mem)
    (hd₁ : d₁.1 = some (.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32)))
    (hd₂ : d₂.1 = some (.bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)))
    (hI : EntryInv c.who.thread b7 b8 b9 d₂.2 d₂.2)
    (hb0 : d₂.2.Buffer p0 (M * 4) 4 true) :
    RunsVia c (fun m' => d₂.2.SameOff (fun q => q = b7 ∨ q = b8 ∨ q = b9) m' ∧
        Ext (SlotEv c.who b7 b8 b9) d₂.2 m')
      [Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨17, .shfl .idx,
          [.bits 32 (BitVec.ofInt 32 (-1)),
            .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
              (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 0 32),
            .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)],
          slots c t.k m b7 b8 b9, d₁⟩,
        Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨18, .shfl .idx,
          [.bits 32 (BitVec.ofInt 32 (-1)),
            .bits 32 ((BitVec.ofNat 64 (((L.env k).sreg .ctaid .x *
              (L.env k).sreg .ntid .x + (L.env k).sreg .tid .x) / 32)).extractLsb' 32 32),
            .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩] t m := by
  refine entry c hcp L hL k hce t m f [] ht hf hlb hpc p0 bA bV M K h0 h1 h2 h3 h5 b7 b8 b9 hb7
    hb8 hb9 hnx hm7 hm8 hm9 d₁ d₂ _ _ hd₁ hd₂ hI _ [] ?_
  intro t' m' f' ht' hf' hl' hp' ha' _ g0 _ _ _ _ g10 g11 g35 hI' _ _ _ hX'
  have hq := fun {q size al w} (hB : d₂.2.Buffer q size al w) =>
    GemvThread.EntryInv.keep hI hI' hB
  have hR := out_ret L hL k c hcp hce t' m' f' ht' hf' hl' hp' M K r p0 hM hK hr hr' g0 g10 g11
    g35 (hb0.of_block (hq hb0))
  rw [ha', hfa, List.append_nil] at hR
  refine ⟨_, hR, fun q hq' => ?_, hX'.trans (.of_trace (Mem.foldl_setLive_trace _ _ _))⟩
  rw [Mem.foldl_setLive_blocks (by simp only [List.mem_cons, List.not_mem_nil, or_false]; tauto)]
  exact hI'.off q hq'

end MojoProofTest.GemvOut
