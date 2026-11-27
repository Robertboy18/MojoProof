import MojoProofTest.GevmBar
import MojoProofTest.SegEvents
import MojoProof.Sym.CanonBar

/-!
# gevm_kernel's first phase, warp by warp, and its block's barrier

gevm_kernel (`gevm`, MojoProofTest/SymLane.lean) on every valid launch with 1024 threads per
block: before its barrier each thread runs the entry block and the loop, stores its sum `%60` to
the cell `laneid * 32 + tid.x / 32` of its block's shared array, and waits at the barrier
`call @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)` at statement 6 of `%59` (`GevmBar.bar`).

* `Bufs`, `Lane`, `word`, `Cell`, `Ev0`, `AtBar`: the memory's buffers, a thread's premises at
  the entry, the bits of its sum, its store's effect on the shared array, the events of the first
  phase (reads of the inputs, each thread's store to its cell), and its status at the barrier.
* `bufferIn_ne`, `Bufs.put`, `Bufs.of_blocks`: buffers of different spaces, owners or
  writability are different blocks; `Bufs` after a store to the shared array, and on a memory
  with the same input blocks and shared array.
* `lane`: one thread's run to the barrier, from every memory with the buffers, keeping them; its
  trace extends the memory's by events of `Ev0` (`Ext`).
* `warp`: **every warp of every block** runs to the barrier (`WarpWait`), by `WarpWait.of_inv`
  at `J = 0`, lane by lane by `lane`, with the invariant: the buffers and the cells the earlier
  lanes stored and their events (`Turns` of `Cell` and `Ext`).
* `block`: **every block's 32 warps** run in turn to the barrier (`CanonWait`, by
  `CanonWait.of_merge` from `warp`), the barrier's checks hold (`BlockBar`, by
  `BlockBar.of_waits`), and on the memory with the block's barrier logged, the shared array holds
  at cell `x` the sum of thread `1024 g + tpose 32 x` (`SegEvents.gevm_buffer`); the waits'
  trace extends the memory's by events of `Ev0`.

Tests of one program, gevm_kernel float32 `1308aaae`; the lemmas they use
(MojoProof/Sym/CanonBar.lean, MojoProof/Sym/SchedWait.lean) are for every program.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.OblGevm MojoProofTest.OblGevmRun
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.GevmWarp0

/-- The memory premises of gevm_kernel's first phase, for sizes `N` and `K`, the output block
`p0`, the input blocks `bA` and `bB`, the shared array's block `b`, block of threads `g` and
inputs `A : [K]` and `B : [K, N]`: `p0` is a writable buffer of `N` binary32, `bA` and `bB`
read-only buffers of `K` and `K * N` binary32 holding `A` and `B` row-major, all fitting;
`b` is a writable buffer of 4096 bytes in space 3 aligned to 4 owned by `g`, whose end is in the
address space. A test definition. -/
def Bufs (N K p0 bA bB b g : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (m : Mem) : Prop :=
  m.Buffer p0 (N * 4) 4 true ∧ m.Fits gevm.prog.layout p0 (N * 4) ∧
    m.Buffer bA (K * 4) 4 false ∧ m.Buffer bB (K * N * 4) 4 false ∧
    m.Fits gevm.prog.layout bA (K * 4) ∧ m.Fits gevm.prog.layout bB (K * N * 4) ∧
    m.Holds gevm.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A ∧
    m.Holds gevm.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) B ∧
    m.BufferIn 3 b 4096 4 (.cta g) true ∧
    ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1

/-- Thread `n`'s premises at gevm_kernel's entry, for launch `L`, contexts `c`, threads `t` and
the arguments of `Bufs`: `c n` is of gevm's program with `n`'s registers, gives the shared array
offset 0 of `b`, and its thread is admitted by `g`; `n`'s block's columns `32 ctaid.x` to
`32 ctaid.x + 31` are below `N`; `t n`'s only frame is at statement 0 of gevm's entry block with
no `alloca` blocks, registers 0, 1, 2 the pointers to `p0`, `bA`, `bB` and 4, 5 the words of `N`
and `K`. A test definition. -/
def Lane (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) (N K p0 bA bB b g n : Nat) : Prop :=
  (c n).prog = gevm.prog ∧ (c n).env = L.env n ∧ (c n).globals sharedName = some ⟨b, 0⟩ ∧
    (Owner.cta g).admits (c n).who = true ∧ (L.env n).sreg .ctaid .x * 32 + 32 ≤ N ∧
    ∃ f, (t n).frames = [f] ∧ f.fn = gevm.fn_0 ∧ f.label = gevm.fn_0.b_0.label ∧ f.pc = 0 ∧
      f.allocas = [] ∧ f.regs 0 = some (.ptr ⟨p0, 0⟩) ∧ f.regs 1 = some (.ptr ⟨bA, 0⟩) ∧
      f.regs 2 = some (.ptr ⟨bB, 0⟩) ∧ f.regs 4 = some (.bits 32 (BitVec.ofNat 32 N)) ∧
      f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K))

/-- The bits of thread `n`'s sum before the barrier, for launch `L`, contexts `c`, threads `t`,
`N` and inputs `A : [K]`, `B : [K, N]`: the `dotLoop` of `OblGevmRun.loop` (from `+0.0`, under
`n`'s oracle numbers from its step `(t n).k`) over the pairs of column `32 ctaid.x + laneid`
(`vecMatPairs`) from `tid.x / 32` by 32 (`stride`), when that column is below `N`; `0`
otherwise. A test definition. -/
def word (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) (N : Nat) {K : Nat}
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (n : Nat) : BitVec 32 :=
  if hc : (L.env n).sreg .ctaid .x * 32 + (L.env n).laneid < N then
    (dotLoop true (oG (c n) (t n).k) (Model.zero _ false)
      (stride 32 ((L.env n).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩))).toBits
  else 0

/-- Thread `n`'s run from `m` to `m'` writes, if `n` is in block of threads `g`, the encoding of
`acc n` at offset `4 (32 laneid + tid.x / 32)` of block `b`, and keeps block `b` otherwise
(`SegEvents.gevm_buffer`'s runs), for launch `L` and words `acc`. A test definition. -/
def Cell (L : Launch) (b g : Nat) (acc : Nat → BitVec 32) (n : Nat) (m m' : Mem) : Prop :=
  ∀ blk, m.blocks b = some blk → m'.blocks b = some (if n / 1024 = g then
    blk.put (4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32))
      ((gevm.prog.layout.encode (.fp .float) (.bits 32 (acc n))).getD [])
  else blk)

/-- The events of gevm_kernel's first phase in block of threads `g`, for launch `L`, contexts
`c`, input blocks `bA`, `bB` and shared array `b`: an access that reads `bA` or `bB`, or the
store of 4 bytes by a thread `n` of `g` (`c n`'s thread) at its cell `32 laneid + tid.x / 32` of
`b`. A test definition. -/
def Ev0 (L : Launch) (c : Nat → Ctx) (bA bB b g : Nat) (e : Event) : Prop :=
  ∃ a, e = .access a ∧ ((a.write = false ∧ (a.ptr.block = bA ∨ a.ptr.block = bB)) ∨
    ∃ n, n / 1024 = g ∧ a = ⟨(c n).who, ⟨b, ((((L.env n).laneid * 32 +
      (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int)⟩, 4, true, none, false⟩)

/-- Thread `n`'s status at the barrier, for contexts `c`, threads `t` and the arguments of
`Bufs`: thread `t n` runs from some memory with `Bufs` to `σ` (`ToWait`), a wait from a thread at
statement 6 of `%59` at the barrier call with argument `i32 0`. A test definition. -/
def AtBar (c : Nat → Ctx) (t : Nat → Thread) (N K p0 bA bB b g : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]) (n : Nat) (σ : Status) : Prop :=
  ∃ m m', Bufs N K p0 bA bB b g A B m ∧ ToWait (c n) (t n) m σ m' ∧
    ∃ u e, σ = .wait u .barrier [.bits 32 (BitVec.ofInt 32 0)] e ∧
      u.at = some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6)

/-- Two buffers (`Mem.BufferIn`) of a memory that differ in address space, owner or writability
are different blocks, for every memory, spaces, blocks, sizes, alignments, owners and
writability. -/
theorem bufferIn_ne {m : Mem} {s s' q q' size size' al al' : Nat} {o o' : Owner} {w w' : Bool}
    (h : m.BufferIn s q size al o w) (h' : m.BufferIn s' q' size' al' o' w')
    (hne : s ≠ s' ∨ o ≠ o' ∨ w ≠ w') : q ≠ q' := by
  rintro rfl
  obtain ⟨x, hx, hs, -, ho, hw, -⟩ := h
  obtain ⟨y, hy, hs', -, ho', hw', -⟩ := h'
  rw [hx, Option.some.injEq] at hy
  subst hy
  rcases hne with hne | hne | hne
  · exact hne (hs.symm.trans hs')
  · exact hne (ho.symm.trans ho')
  · exact hne (by simpa using hw.symm.trans hw')

/-- `Bufs` on a memory whose blocks are `m`'s but for block `b`'s bytes, for every memory `m`
with `Bufs`, block `blk` and bytes `β` (the other buffers are in space 1, not `b`'s 3). -/
theorem Bufs.put {N K p0 bA bB b g : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} {m m' : Mem}
    (h : Bufs N K p0 bA bB b g A B m) {blk : Sem.Block} {β : Nat → MemByte}
    (hb : m.blocks b = some blk) (hq : ∀ q, q ≠ b → m'.blocks q = m.blocks q)
    (hb' : m'.blocks b = some { blk with bytes := β }) : Bufs N K p0 bA bB b g A B m' := by
  obtain ⟨hb0, hf0, hbA, hbB, hfA, hfB, hA, hB, hS, blk', hb'', hF⟩ := h
  have hne : ∀ {q size al : Nat} {w : Bool}, m.Buffer q size al w → q ≠ b :=
    fun h => bufferIn_ne h.bufferIn hS (.inl (by decide))
  have hk : ∀ {q size al : Nat} {w : Bool}, m.Buffer q size al w →
      ∀ x, m.blocks q = some x → m'.blocks q = some x :=
    fun h _ hx => (hq _ (hne h)).trans hx
  rw [hb, Option.some.injEq] at hb''
  subst hb''
  exact ⟨hb0.of_block (hk hb0), hf0.of_block (hk hb0), hbA.of_block (hk hbA),
    hbB.of_block (hk hbB), hfA.of_block (hk hbA), hfB.of_block (hk hbB), hA.of_block (hk hbA),
    hB.of_block (hk hbB), Mem.BufferIn.bytes hS hb hb', _, hb', hF⟩

/-- `Bufs` on a memory `m'` with `m`'s blocks `bA`, `bB` and `b` and the output buffer `p0` (a
`Mem.Buffer` that fits), for every memory `m` with `Bufs`. -/
theorem Bufs.of_blocks {N K p0 bA bB b g : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} {m m' : Mem}
    (h : Bufs N K p0 bA bB b g A B m) (hb0 : m'.Buffer p0 (N * 4) 4 true)
    (hf0 : m'.Fits gevm.prog.layout p0 (N * 4)) (hqA : m'.blocks bA = m.blocks bA)
    (hqB : m'.blocks bB = m.blocks bB) (hqb : m'.blocks b = m.blocks b) :
    Bufs N K p0 bA bB b g A B m' := by
  obtain ⟨-, -, hbA, hbB, hfA, hfB, hA, hB, hS, hF⟩ := h
  have hk : ∀ {q}, m'.blocks q = m.blocks q → ∀ x, m.blocks q = some x → m'.blocks q = some x :=
    fun h _ hx => h.trans hx
  exact ⟨hb0, hf0, hbA.of_block (hk hqA), hbB.of_block (hk hqB), hfA.of_block (hk hqA),
    hfB.of_block (hk hqB), hA.of_block (hk hqA), hB.of_block (hk hqB),
    by unfold Mem.BufferIn; rw [hqb]; exact hS, by rw [hqb]; exact hF⟩

/-- **One thread of gevm_kernel to the barrier, keeping the buffers** (test): for every valid
launch `L` with 1024 threads per block in `x`, contexts `c`, threads `t`, `N < 2 ^ 31`,
`K < 2 ^ 31` with `K % 32 = 0` and `K * N < 2 ^ 29`, inputs `A : [K]` and `B : [K, N]`, thread
`n` of block `g` with `Lane`'s premises and memory `m` with `Bufs`: `t n` runs from `m` to a
status `σ` at the barrier (`AtBar`) on a memory with `Bufs` that has `m`'s blocks but for the
store of `n`'s sum (`word`) to its cell of the shared array (`Cell`, and `m`'s blocks other than
`b`), whose trace extends `m`'s by events of `Ev0` (`Ext`: the loop's reads of `bA` and `bB`,
`GevmBar.bar`, then the store). `GevmBar.bar`, then `Mem.store_inv` and `Bufs.put`. -/
theorem lane {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) {c : Nat → Ctx}
    {t : Nat → Thread} {N K p0 bA bB b g : Nat} (hN : N < 2 ^ 31) (hK : K < 2 ^ 31)
    (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} {n : Nat} (hng : n / 1024 = g)
    (hn : Lane L c t N K p0 bA bB b g n) {m : Mem} (hm : Bufs N K p0 bA bB b g A B m) :
    ∃ σ m', ToWait (c n) (t n) m σ m' ∧ AtBar c t N K p0 bA bB b g A B n σ ∧
      Bufs N K p0 bA bB b g A B m' ∧ Cell L b g (word L c t N A B) n m m' ∧
      Ext (Ev0 L c bA bB b g) m m' ∧ ∀ q, q ≠ b → m'.blocks q = m.blocks q := by
  obtain ⟨hcp, hce, hg, hin, hcol, f, ht, hf, hlb, hpc, -, hr0, hr1, hr2, hr4, hr5⟩ := hn
  obtain ⟨hb0, hf0, hbA, hbB, hfA, hfB, hA, hB, hS, hF⟩ := id hm
  obtain ⟨-, htid, hlid, -⟩ := Launch.tpose_env hL hx n
  have hc : (L.env n).sreg .ctaid .x * 32 + (L.env n).laneid < N := by omega
  have hy : (L.env n).sreg .ctaid .x * 32 + (L.env n).sreg .tid .x / 32 < N := by omega
  obtain ⟨u, e, m', M₀, hw, hu, -, hbl, hx₁, hst⟩ := GevmBar.bar L hL n (c n) hcp hce hx (t n) m
    f [] ht hf hlb hpc N K p0 bA bB hN hK hK32 hKN hr0 hr1 hr2 hr4 hr5 hb0 hf0 hbA hbB hfA hfB A B
    hA hB hy hc b g hg hS hin hF
  have hx₂ : Ext (Ev0 L c bA bB b g) m M₀ := (hx₁.mono fun e ⟨a, h1, h2, h3⟩ =>
    ⟨a, h1, .inl ⟨h2, h3⟩⟩).trans ⟨[_], Mem.store_trace hst, fun e he => by
      rw [List.mem_singleton.1 he]; exact ⟨_, rfl, .inr ⟨n, hng, rfl⟩⟩⟩
  obtain ⟨blk, bs, hck, -, hbs, rfl⟩ := Mem.store_inv hst
  have hblk : m.blocks b = some blk := hbl ▸ (Mem.check_inv hck).1
  refine ⟨_, _, hw, ⟨m, _, hm, hw, u, e, rfl, hu⟩,
    hm.put (β := (blk.put (((L.env n).laneid * 32 + (L.env n).sreg .tid .x / 32) * 4) bs).bytes)
      hblk (fun q hq => ?_) ?_, fun blk' hb' => ?_, hx₂, fun q hq => ?_⟩
  · show (if q = b then _ else m'.blocks q) = _
    rw [ite_eq_right hq, hbl]
  · show (if b = b then _ else _) = _
    rw [ite_eq_left rfl]
    rfl
  · rw [hblk, Option.some.injEq] at hb'
    subst hb'
    have hw' : word L c t N A B n = (dotLoop true (oG (c n) (t n).k) (Model.zero _ false)
        (stride 32 ((L.env n).sreg .tid .x / 32) (vecMatPairs A B ⟨_, hc⟩))).toBits :=
      dite_eq_left hc
    have e1 : ((((L.env n).laneid * 32 + (L.env n).sreg .tid .x / 32) * 4 : Nat) : Int).toNat =
        4 * (32 * (L.env n).laneid + (L.env n).sreg .tid .x / 32) := by
      rw [Int.toNat_natCast]
      ring
    show (if b = b then _ else _) = _
    rw [ite_eq_left rfl, ite_eq_left hng, hw', ← e1]
    exact congrArg (fun bs => some (blk.put _ bs)) (congrArg (fun o => Option.getD o []) hbs).symm
  · show (if q = b then _ else m'.blocks q) = _
    rw [ite_eq_right hq, hbl]

/-- **Every warp of gevm_kernel to the barrier** (test): for every valid launch `L` with 1024
threads per block in `x`, contexts `c`, threads `t`, `N`, `K`, `A` and `B` as in `lane`, and
every warp of every block, from first thread `k` (lane 0, `k % 1024 % 32 = 0`, of block
`g = k / 1024`) whose threads have `Lane`'s premises, and every memory `m` with `Bufs`: the warp
runs to the barrier (`WarpWait`) from `t` on `m`, each thread `n` of it at a status with `AtBar`,
to a memory with `Bufs` and `m`'s blocks other than `b` that its threads' runs in turn make from
`m` each by the store of its sum to its cell and events of `Ev0` (`Turns` of `Cell` and
`Ext`). By `WarpWait.of_inv` at `J = 0`, lane `j` by `lane`, the invariant after `j` lanes
`Bufs`, `m`'s blocks other than `b` and the cells and events of lanes `0` to `j - 1`
(`Turns.append`). -/
theorem warp {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) {c : Nat → Ctx}
    {t : Nat → Thread} {N K p0 bA bB b g : Nat} (hN : N < 2 ^ 31) (hK : K < 2 ^ 31)
    (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]} {k : Nat} (hk : k % 1024 % 32 = 0)
    (hkg : k / 1024 = g) (hl : ∀ n ∈ warpThreads L k, Lane L c t N K p0 bA bB b g n) {m : Mem}
    (hm : Bufs N K p0 bA bB b g A B m) :
    ∃ s Es m', WarpWait L c k t m Es s m' ∧
      (∀ n ∈ warpThreads L k, AtBar c t N K p0 bA bB b g A B n (s n)) ∧
      Bufs N K p0 bA bB b g A B m' ∧ (∀ q, q ≠ b → m'.blocks q = m.blocks q) ∧
      ∃ Es', Turns (fun n m m' => Cell L b g (word L c t N A B) n m m' ∧
        Ext (Ev0 L c bA bB b g) m m') (warpThreads L k) m Es' m' := by
  have hth : warpThreads L k = (List.range (warpLanes L k).length).map (k + ·) :=
    congrArg (List.map (k + ·)) (warpLanes_range L k)
  obtain ⟨s, Es, m', hw, hW, hP, hq, Es', hT⟩ := WarpWait.of_inv (L := L) (c := c) (k := k)
    (J := 0)
    (T := fun _ j u => u = t (k + j))
    (W := fun _ j σ => AtBar c t N K p0 bA bB b g A B (k + j) σ)
    (P := fun _ j m' => Bufs N K p0 bA bB b g A B m' ∧ (∀ q, q ≠ b → m'.blocks q = m.blocks q) ∧
      ∃ Es', Turns (fun n m m' => Cell L b g (word L c t N A B) n m m' ∧
        Ext (Ev0 L c bA bB b g) m m') ((List.range j).map (k + ·)) m Es' m')
    (fun _ h => absurd h (Nat.not_lt_zero _)) (fun _ h => absurd h (Nat.not_lt_zero _))
    (fun j hj u m₁ hu ⟨hm₁, hq₁, Es₁, hT₁⟩ => by
      subst hu
      have hj32 : j < 32 := by
        have := mem_warpLanes.1 hj
        rw [warpLanes_eq, List.length_range] at this
        omega
      obtain ⟨σ, m₂, hw, hσ, hm₂, hc, hx₂, hq₂⟩ := lane hL hx hN hK hK32 hKN (by omega)
        (hl _ (List.mem_map.2 ⟨j, hj, rfl⟩)) hm₁
      obtain ⟨E, hE⟩ := hw.trace
      refine ⟨σ, m₂, hw, hσ, hm₂, fun q hq => (hq₂ q hq).trans (hq₁ q hq), Es₁ ++ [E], ?_⟩
      rw [List.range_succ, List.map_append]
      exact hT₁.append (.cons ⟨hc, hx₂⟩ hE (.nil _)))
    (fun _ _ => rfl) ⟨hm, fun _ _ => rfl, [], .nil m⟩
  refine ⟨s, Es, m', hw, fun n hn => ?_, hP, hq, Es', hth ▸ hT⟩
  obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hn
  exact hW j hj

/-- **A block of gevm_kernel to its barrier, and the shared array there** (test): for every
valid launch `L` with 1024 threads per block in `x`, contexts `c`, threads `t`, `N`, `K`, `A` and
`B` as in `lane`, every block of threads `g` whose threads have `Lane`'s premises, and every
memory `m` with `Bufs`: the block's 32 warps (`blockWarps`) run in turn to the barrier
(`CanonWait`) from `t` on `m` to a memory `m₁`, at statuses `s` with `AtBar` at each thread of
the block, at which the block's barrier fires (`BlockBar`, at threads `u`); and the memory with
the block's barrier logged, the next phase's (`BlockRun.bar`), has `Bufs`, and its shared array
holds row-major the tensor whose element `x` is the sum (`word`) of thread `1024 g + tpose 32 x`,
the thread whose cell `32 laneid + tid.x / 32` is `x`; `m₁`'s trace extends `m`'s by events of
`Ev0` (`Ext`, by `Ext.turns` of the warps' turns), and `m₁` has `m`'s blocks other than `b`. By
`CanonWait.of_merge` with, after `i` warps, `Bufs`, `m`'s blocks other than `b` and the cells of
the first `i` warps' threads (`warp`, `Turns.append`); then `BlockBar.of_waits` and
`SegEvents.gevm_buffer`. -/
theorem block {L : Launch} (hL : L.Valid) (hx : L.block .x = 1024) {c : Nat → Ctx}
    {t : Nat → Thread} {N K p0 bA bB b g : Nat} (hN : N < 2 ^ 31) (hK : K < 2 ^ 31)
    (hK32 : K % 32 = 0) (hKN : K * N < 2 ^ 29)
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [K]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [K, N]}
    (hl : ∀ n, n / 1024 = g → Lane L c t N K p0 bA bB b g n) {m : Mem}
    (hm : Bufs N K p0 bA bB b g A B m) :
    ∃ s u Es m₁, CanonWait L c t s (blockWarps L g) m Es m₁ ∧ BlockBar L g s u ∧
      (∀ n, n / 1024 = g → AtBar c t N K p0 bA bB b g A B n (s n)) ∧
      Bufs N K p0 bA bB b g A B (m₁.log (.barrier g)) ∧
      (m₁.log (.barrier g)).Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
        (rowMajor gevm.prog.layout (.fp .float) 0)
        (TorchLean.Tensor.Rep.ofFn fun i : TorchLean.Shape.Coord [1024] =>
          Model.ofBits (word L c t N A B (1024 * g + tpose 32 i.1.val))) ∧
      Ext (Ev0 L c bA bB b g) m m₁ ∧ ∀ q, q ≠ b → m₁.blocks q = m.blocks q := by
  have hv : volume L.block = 1024 := (Launch.tpose_env hL hx 0).1
  have hs : 0 < volume L.block := by rw [hv]; decide
  obtain ⟨s, Es, m₁, hc, hV, hm₁, hq₁, ns, Es', hT, hns⟩ := CanonWait.of_merge (L := L) (c := c)
    (t := t) (V := AtBar c t N K p0 bA bB b g A B) hs
    (P := fun i m' => Bufs N K p0 bA bB b g A B m' ∧ (∀ q, q ≠ b → m'.blocks q = m.blocks q) ∧
      ∃ ns Es', Turns (fun n m m' => Cell L b g (word L c t N A B) n m m' ∧
        Ext (Ev0 L c bA bB b g) m m') ns m Es' m' ∧
        ∀ i' < i, ∀ h : i' < (blockWarps L g).length, ∀ n ∈ warpThreads L (blockWarps L g)[i'],
          n ∈ ns)
    (blockWarps_nodup L g) (fun k hk => ((mem_blockWarps hs).1 hk).2)
    (fun i hi m' ⟨hm', hq', ns, Es', hT, hns⟩ => by
      obtain ⟨hkg, hk⟩ := (mem_blockWarps hs).1 (List.getElem_mem hi)
      rw [hv] at hkg hk
      obtain ⟨s, Es₁, m₂, hw, hW, hm₂, hq₂, Es₂, hT₂⟩ := warp hL hx hN hK hK32 hKN hk hkg
        (fun n hn => hl n (by
          have h1 := warp_base_div hs n
          rw [(warpThreads_iff hs (hv ▸ hk)).1 hn, hv, hkg] at h1
          exact h1.symm)) hm'
      refine ⟨s, Es₁, m₂, hw, hW, hm₂, fun q hq => (hq₂ q hq).trans (hq' q hq),
        ns ++ warpThreads L (blockWarps L g)[i], Es' ++ Es₂, hT.append hT₂, fun i' h h' n hn => ?_⟩
      rcases Nat.lt_succ_iff_lt_or_eq.1 h with h | rfl
      · exact List.mem_append_left _ (hns i' h h' n hn)
      · exact List.mem_append_right _ hn)
    (m := m) ⟨hm, fun _ _ => rfl, [], [], .nil m, fun _ h => absurd h (Nat.not_lt_zero _)⟩
  have hblk : ∀ n, n / 1024 = g → ∃ k ∈ blockWarps L g, n ∈ warpThreads L k := fun n hn =>
    List.mem_flatMap.1 ((blockWarps_threads hs).2 (hv ▸ hn))
  have hAt : ∀ n, n / 1024 = g → AtBar c t N K p0 bA bB b g A B n (s n) := fun n hn => by
    obtain ⟨k, hk, hnk⟩ := hblk n hn
    exact hV k hk n hnk
  obtain ⟨u, hbar⟩ := BlockBar.of_waits (L := L) (b := g) (s := s) (bar := 0)
    (a := some (gevm.fn_0.name, gevm.fn_0.b_5.label, 6)) hs (by decide) fun n hn => by
      obtain ⟨-, -, -, -, u, e, he, hu⟩ := hAt n (hv ▸ hn)
      exact ⟨u, _, e, he, rfl, hu⟩
  obtain ⟨-, -, hH⟩ := SegEvents.gevm_buffer L hL hx (R₁ := fun n m m' =>
      Cell L b g (word L c t N A B) n m m' ∧ Ext (Ev0 L c bA bB b g) m m')
    (ns := ns) b g (word L c t N A B) (fun _ _ _ _ h => h.1) (fun k' hk' => by
      obtain ⟨k, hk, hnk⟩ := hblk (1024 * g + k') (by omega)
      obtain ⟨i, hi, rfl⟩ := List.mem_iff_getElem.1 hk
      exact hns i hi hi _ hnk) hT [g] (m₂ := m₁.log (.barrier g)) rfl hm.2.2.2.2.2.2.2.2.1
    hm.2.2.2.2.2.2.2.2.2
  exact ⟨s, u, Es, m₁, hc, hbar, hAt, hm₁, hH,
    (Ext.turns hT fun _ _ _ _ h => h.2).mono fun _ ⟨_, _, h⟩ => h, hq₁⟩

end MojoProofTest.GevmWarp0
