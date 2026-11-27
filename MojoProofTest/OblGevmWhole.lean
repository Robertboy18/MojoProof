import MojoProofTest.OblGevmRun

/-!
# gevm_kernel's thread from its entry to its `ret`, for every `K` and `N` at tile 1024

Tests of one program, gevm_kernel at float32 with `tile_size = 1024` (MojoProofTest/SymLane.lean's
`gevm`): `whole` composes MojoProofTest/OblGevmRun.lean's `loop` (the entry block and the
`(K + 31) / 32` rounds of the loop, to statement 1 of `%59`) with MojoProofTest/OblGevmThread.lean's
`thread` (statement 1 of `%59` through the barrier and the five shuffles to the `ret`) by
`RunsVia.of_steps` (MojoProof/Sym/OblSeg.lean), for every
launch with 1024 threads per block, every `N` and `K` with `K % 32 = 0`, `K < 2 ^ 31` and
`K * N < 2 ^ 29`, and every input vector and matrix in memory. Two `example`s instantiate it at
`K = N = 64` and at the corpus file's `K = N = 4096`.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.OblGevm MojoProofTest.OblGevmRun
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.OblGevmWhole

/-- **gevm_kernel's thread from its entry to its `ret`, for every `K` and `N` at tile 1024, one
program (gevm_kernel)** (a test of `RunsVia.of_steps`, `OblGevmRun.loop` and
`OblGevmThread.thread`). For every launch `L` valid with `ntid.x = 1024`, thread `k`, context `c`
of gevm's program with `L`'s registers, thread `t` whose only frame `f` is at statement 0 of the
entry block of `gevm.fn_0` with no `alloca` blocks, every `N < 2 ^ 31` and `K < 2 ^ 31` with
`K % 32 = 0` and `K * N < 2 ^ 29`, registers 0, 1, 2, 4, 5 the pointers to `p0`, `bA`, `bB` and
the words of `N` and `K`, memory `m` with the buffers of `loop` (`p0` writable of `N * 4` bytes,
`bA` of `K * 4`, `bB` of `K * N * 4`, holding `A : [K]` and `B : [K, N]`), the thread's row and
column below `N`, the shared array (`b`, 4096 bytes, owned by the block `g`, admitting `c.who`),
and the delivered values `d₀ … d₅` of the barrier and the five butterfly shuffles (`d₀`'s memory
holds some `S : [1024]` in the shared array, `d₁ … d₅` deliver the words `z₁ … z₅`, `d₅`'s memory
has `p0`'s buffer): the thread runs through the barrier and the five shuffles, waiting at each at
its statement of `%59` (`Thread.at`), to its end (`RunsVia`), and at the end lane 0 has stored
`S[tid.x] + z₁ + … + z₅` (each sum delivered under the thread's oracle numbers at the loop's step
count `t.k + 36 + 17 * (K / 32)`) at `out[ctaid.x * 32 + tid.x / 32]` on `d₅`'s memory, while the
other lanes leave `d₅`'s memory unchanged. The proof is `loop` to statement 1 of `%59`, `thread`
from there, and `RunsVia.of_steps`. -/
theorem whole (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gevm.prog)
    (hce : c.env = L.env k) (hn : (L.env k).sreg .ntid .x = 1024) (t : Thread) (m : Mem)
    (f : Frame) (ht : t.frames = [f]) (hf : f.fn = gevm.fn_0)
    (hlb : f.label = gevm.fn_0.b_0.label) (hpc : f.pc = 0) (ha : f.allocas = [])
    (N K p0 bA bB : Nat)
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
    (hSh : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hFs : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (d₀ d₁ d₂ d₃ d₄ d₅ : Option Val × Mem)
    (S : TorchLean.Tensor (Model FloatTy.float.fmt) [1024])
    (hB₀ : d₀.2.BufferIn 3 b 4096 4 (.cta g) true)
    (hF₀ : ∃ blk, d₀.2.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (hS : d₀.2.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) S)
    (z₁ z₂ z₃ z₄ z₅ : Model FloatTy.float.fmt)
    (hd₁ : d₁.1 = some (Val.ofFloat .float z₁)) (hd₂ : d₂.1 = some (Val.ofFloat .float z₂))
    (hd₃ : d₃.1 = some (Val.ofFloat .float z₃)) (hd₄ : d₄.1 = some (Val.ofFloat .float z₄))
    (hd₅ : d₅.1 = some (Val.ofFloat .float z₅))
    (hy₅ : d₅.2.Buffer p0 (N * 4) 4 true) (hfy₅ : d₅.2.Fits gevm.prog.layout p0 (N * 4)) :
    RunsVia c (fun m' => ((L.env k).laneid = 0 →
        d₅.2.store gevm.prog.layout c.who 0 (.fp .float) (Val.ofFloat .float
          (deliver ((deliver ((deliver ((deliver ((deliver
            ((TorchLean.Tensor.Rep.get S (⟨(L.env k).sreg .tid .x,
              (Launch.sreg_lt hL k .x).1⟩, ())).add z₁)
            (c.oracle (Nat.pair (t.k + 36 + 17 * (K / 32) + 12) 0) / 3)).add z₂)
            (c.oracle (Nat.pair (t.k + 36 + 17 * (K / 32) + 16) 0) / 3)).add z₃)
            (c.oracle (Nat.pair (t.k + 36 + 17 * (K / 32) + 20) 0) / 3)).add z₄)
            (c.oracle (Nat.pair (t.k + 36 + 17 * (K / 32) + 24) 0) / 3)).add z₅)
            (c.oracle (Nat.pair (t.k + 36 + 17 * (K / 32) + 28) 0) / 3)))
          ⟨p0, ((((L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32) * 4 : Nat) :
            Int)⟩ (some 4) = .ok m') ∧ ((L.env k).laneid ≠ 0 → m' = d₅.2))
      [(fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6) ∧ i = .barrier, d₀),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 11) ∧
          i = .shfl .bfly, d₁),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 15) ∧
          i = .shfl .bfly, d₂),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 19) ∧
          i = .shfl .bfly, d₃),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 23) ∧
          i = .shfl .bfly, d₄),
        (fun u i _ _ => u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 27) ∧
          i = .shfl .bfly, d₅)] t m := by
  obtain ⟨t', m', f', hS', ht', hf', hlb', hpc', ha', -, hk', hmb, -, h60, h13, h11, h10, h29⟩ :=
    loop L hL k c hcp hce hn t m f [] ht hf hlb hpc N K p0 bA bB hN hK hK32 hKN hr0 hr1 hr2 hr4
      hr5 hb0 hf0 hbA hbB hfA hfB A B hA hB hy hc
  have hx : (L.env k).sreg .tid .x < 1024 := (Launch.sreg_lt hL k .x).1
  have hl : (L.env k).laneid < 32 := by
    show k % volume L.block % 32 < 32
    exact Nat.mod_lt _ (by decide)
  have hSh' : m'.BufferIn 3 b 4096 4 (.cta g) true := by
    obtain ⟨blk, h1, h2⟩ := hSh
    exact ⟨blk, by rw [hmb]; exact h1, h2⟩
  have hFs' :
      ∃ blk, m'.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1 := by
    obtain ⟨blk, h1, h2⟩ := hFs
    exact ⟨blk, by rw [hmb]; exact h1, h2⟩
  have hT := MojoProofTest.OblGevmThread.thread c hcp t' m' f' ht' hf' hlb' hpc' (ha'.trans ha)
    ((L.env k).laneid) ((L.env k).sreg .tid .x / 32) ((L.env k).sreg .tid .x) hl (by omega) hx _
    p0 N ((L.env k).sreg .ctaid .x * 32 + (L.env k).sreg .tid .x / 32) hy h13 h11 h10 h60 h29
    b g hg hSh' hin hFs' d₀ d₁ d₂ d₃ d₄ d₅ S hB₀ hF₀ hS z₁ z₂ z₃ z₄ z₅ hd₁ hd₂ hd₃ hd₄ hd₅ hy₅ hfy₅
  rw [hk'] at hT
  exact RunsVia.of_steps hS' hT

-- `whole` at two sizes: `K = N = 64` and the corpus file's launch, `K = N = 4096`.
example := whole (N := 64) (K := 64) (hN := by decide) (hK := by decide) (hK32 := by decide)
  (hKN := by decide)

example := whole (N := 4096) (K := 4096) (hN := by decide) (hK := by decide) (hK32 := by decide)
  (hKN := by decide)

end MojoProofTest.OblGevmWhole
