import MojoProofTest.OblGevmRun
import MojoProof.Sym.WaitVia

/-!
# gevm_kernel's lanes from the entry to the barrier

A `WarpWait.of_inv` or `WarpWait.of_turns` (MojoProof/Sym/CanonBar.lean) run of a warp of
gevm_kernel (`gevm`) to its first wait takes, for each lane, a run of the thread to a collective
call (`ToWait`). `bar` gives it: `OblGevmRun.loop` runs the thread from the entry block through
the loop to statement 1 of `%59`, then `OblGevm.to_barrier_waits` from there to the barrier
`call @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)` at 6, after the store of `%60` (the lane's
partial dot product) to the shared array's cell `laneid * 32 + tid.x / 32`.

Tests of one program, gevm_kernel float32 `1308aaae`; the lemmas they use
(MojoProof/Sym/Segment.lean, MojoProof/Sym/SchedWait.lean, MojoProof/Sym/OblLemmas.lean) are for
every program.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.OblGevm MojoProofTest.OblGevmThread MojoProofTest.OblGevmRun
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.GevmBar

/-- **gevm_kernel's lane from `%59` to the barrier** (test): for every context `c` of
gevm_kernel's program, thread `t` whose top frame `f` (above `rest`) is of `gevm`'s function at
statement 1 of `%59`, lane `l < 32`, warp `w < 32` and bits `acc`, with `f`'s `%13` and `%11`
the 64-bit words of `l` and `w` and `%60` the binary32 of bits `acc`, and memory `m` with
`OblGevm.to_barrier`'s premises on the shared array (`c` gives it offset 0 of block `b`, a
buffer of 4096 bytes in space 3 aligned to 4, owned by the block of threads `g`, which admits
`c`'s thread, whose address plus 4096 is at most `2 ^ 32`): the thread runs from `t` on `m` to
the call of the barrier with argument `i32 0` (`ToWait`), waiting at a thread `u` at statement 6
of `%59`, 5 steps after `t`, on the memory `M₀` that the store of `acc` to cell `l * 32 + w` of
the shared array makes from `m` (`OblGevm.to_barrier_waits`, `SEff.run_store_one`). -/
theorem at59 (c : Ctx) (hcp : c.prog = gevm.prog) (t : Thread) (m : Mem) (f : Frame)
    (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_5.label) (hpc : f.pc = 1) (l w : Nat) (hl : l < 32)
    (hw : w < 32) (acc : BitVec 32) (h13 : f.regs 13 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 w)))
    (h60 : f.regs 60 = some (.bits 32 acc)) (b g : Nat)
    (hg : c.globals sharedName = some ⟨b, 0⟩) (hB : m.BufferIn 3 b 4096 4 (.cta g) true)
    (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    ∃ u e M₀, ToWait c t m (.wait u .barrier [.bits 32 (BitVec.ofInt 32 0)] e) M₀ ∧
      u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6) ∧ u.k = t.k + 5 ∧
      m.store gevm.prog.layout c.who 3 (.fp .float) (.bits 32 acc)
        ⟨b, (((l * 32 + w) * 4 : Nat) : Int)⟩ (some 4) = .ok M₀ := by
  obtain ⟨S, hS0, fe, me, ws, fd, hs, hfn, hlb', hpc', -, -, -, -, hrun, hargs, hstep⟩ :=
    to_barrier_waits c hcp t m f rest ht hf hlb hpc l w hl hw acc h13 h11 h60 b g hg hB hin hF
  obtain rfl : S = seg_0 := Option.some.inj (hS0.symm.trans (by decide +kernel))
  have hws : (Except.ok ws : Except Fault (List Val)) = .ok [.bits 32 (BitVec.ofInt 32 0)] := by
    rw [← hargs]; rfl
  obtain rfl := Except.ok.inj hws
  have hp : (SVal.node 4).eval (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) seg_0.nodes) =
      .ok (.ptr ⟨b, (((l * 32 + w) * 4 : Nat) : Int)⟩) :=
    show (SVal.node 4).eval _ (vals _ seg_0.toSummary.nodes) = _ from SVal.eval_node (by obl_exact)
  refine ⟨_, fd, me, ⟨_, _, _, _, rfl, hs, hstep⟩, ?_, ?_, ?_⟩
  · simp only [Thread.at, List.head?_cons, Option.map, hfn, hlb', hpc', hpc, Valuation.entry,
      hf, show seg_0.len = 5 from rfl]
  · simp only [Valuation.entry, show seg_0.len = 5 from rfl]
  · exact SEff.run_store_one (lbl := gevm.fn_0.b_5.label) (pc := 5) (v := .reg 60) (p := .node 4)
      hf hcp (by rfl) (SVal.eval_reg h60) hp hrun

/-- **gevm_kernel's lane to the barrier** (test): gevm_kernel, for every valid launch `L` with
1024 threads per block in `x`, thread `k`, context `c` of gevm_kernel's program and thread `k`'s
environment, thread `t` whose top frame `f` (above `rest`) is at the start of the entry block,
`N < 2 ^ 31`, `K < 2 ^ 31` with `K % 32 = 0` and `K * N < 2 ^ 29`, and memory `m` with
`OblGevmRun.loop`'s premises (the output buffer `p0` of `N` floats, the buffers of `A`, `K`
floats at `bA`, and `B`, `K × N` floats row-major at `bB`, thread `k`'s output row and column
below `N`) and `OblGevm.to_barrier`'s on the shared array (`c` gives it offset 0 of block `b`, a
buffer of 4096 bytes in space 3 aligned to 4, owned by the block of threads `g`, which admits
`c`'s thread, whose address plus 4096 is at most `2 ^ 32`): the thread runs from `t` on `m` to the
call of the barrier with argument `i32 0` (`ToWait`), waiting at a thread `u` at statement 6 of
`%59`, `41 + 17 * (K / 32)` steps after `t`, on the memory `M₀` that the store of `%60`, the
`dotLoop` of `OblGevmRun.loop`, to cell `laneid * 32 + tid.x / 32` of the shared array makes from
a memory `m'` with `m`'s blocks whose trace extends `m`'s by reads of `bA` and `bB` only (the
memory after the loop). -/
theorem bar (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gevm.prog)
    (hce : c.env = L.env k) (hn : (L.env k).sreg .ntid .x = 1024) (t : Thread) (m : Mem)
    (f : Frame) (rest : List Frame) (ht : t.frames = f :: rest) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_0.label) (hpc : f.pc = 0) (N K p0 bA bB : Nat)
    (hN : N < 2 ^ 31) (hK : K < 2 ^ 31) (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨bA, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨bB, 0⟩))
    (hr4 : f.regs 4 = some (.bits 32 (BitVec.ofNat 32 N)))
    (hr5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (hb0 : m.Buffer p0 (N * 4) 4 true) (hf0 : m.Fits gevm.prog.layout p0 (N * 4))
    (hbA : m.Buffer bA (K * 4) 4 false) (hbB : m.Buffer bB (K * N * 4) 4 false)
    (hfA : m.Fits gevm.prog.layout bA (K * 4)) (hfB : m.Fits gevm.prog.layout bB (K * N * 4))
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N])
    (hA : m.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A)
    (hB : m.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B)
    (hy : (L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32 < N)
    (hc : (L.env k).sreg .ctaid .x * 32 + (L.env k).laneid < N)
    (b g : Nat) (hg : c.globals sharedName = some ⟨b, 0⟩)
    (hS : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    ∃ u e, ∃ m' M₀ : Mem, ToWait c t m (.wait u .barrier [.bits 32 (BitVec.ofInt 32 0)] e) M₀ ∧
      u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6) ∧ u.k = t.k + 41 + 17 * (K / 32) ∧
      m'.blocks = m.blocks ∧ Ext (fun e => ∃ a, e = .access a ∧ a.write = false ∧
        (a.ptr.block = bA ∨ a.ptr.block = bB)) m m' ∧
      m'.store gevm.prog.layout c.who 3 (.fp .float) (.ofFloat .float (dotLoop true (oG c t.k)
        (Model.zero _ false) (stride 32 ((L.env k).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩))))
        ⟨b, ((((L.env k).laneid * 32 + (L.env k).sreg .tid .x / 32) * 4 : Nat) : Int)⟩ (some 4) =
        .ok M₀ := by
  obtain ⟨t', m', f', hs, ht', hf', hlb', hpc', -, -, hk', hbl, hx, h60, h13, h11, -, -⟩ :=
    loop L hL k c hcp hce hn t m f rest ht hf hlb hpc N K p0 bA bB hN hK hK32 hKN hr0 hr1 hr2 hr4
      hr5 hb0 hf0 hbA hbB hfA hfB A B hA hB hy hc
  obtain ⟨htid, -, -⟩ := Launch.sreg_lt hL k .x
  have hl := Launch.laneid_lt L k
  have hw : (L.env k).sreg .tid .x / 32 < 32 := by omega
  have hS' : m'.BufferIn 3 b 4096 4 (.cta g) true := by unfold Mem.BufferIn; rw [hbl]; exact hS
  have hF' : ∃ blk, m'.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1 := by
    rw [hbl]; exact hF
  obtain ⟨u, e, M₀, ⟨_, _, _, _, he, hs', hst⟩, hu, huk, hM⟩ :=
    at59 c hcp t' m' f' rest ht' hf' hlb' hpc' _ _ hl hw _ h13 h11 h60 b g hg hS' hin hF'
  exact ⟨u, e, m', M₀, ⟨_, _, _, _, he, hs.trans hs', hst⟩, hu, by omega, hbl, hx, hM⟩

end MojoProofTest.GevmBar
