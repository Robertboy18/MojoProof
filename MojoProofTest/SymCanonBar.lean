import MojoProof.Sym.CanonBar
import MojoProof.LLVM.Import
import MojoProofTest.SymColl
import MojoProofTest.Launch
import MojoProofTest.KernelRfl

/-!
# The canonical run at the phase level of a kernel that stages through shared memory

Instances of `PhaseRun`, `BlockRun`, `CanonWait`, `WarpWait`, `BlockBar`, `BlockRun.of_turns`,
`WarpWait.of_turns`, `CanonWait.of_inv`, `CanonWait.of_merge`, `PhaseRun.of_inv` and
`PhaseRun.start_sound`
(MojoProof/Sym/CanonBar.lean) for a hand-written kernel at one block of 34 threads and at two
blocks of 6 threads. The kernel `kern` is the parser's term for `text` (checked by `#guard`):

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    %1 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %0
    store i32 %0, ptr addrspace(3) %1, align 4
    call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
    %2 = xor i32 %0, 1
    %3 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %2
    %4 = load i32, ptr addrspace(3) %3, align 4
    %5 = add i32 %0, 40
    %6 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %5
    store i32 %4, ptr addrspace(3) %6, align 4
    ret void

with `@sh` an `internal addrspace(3)` array of 80 words, one for each block of threads. Before the
barrier each thread writes its `%tid.x` to word `tid.x` of its block of threads' `@sh`; after it,
each reads word `tid.x xor 1`, its neighbour's, and writes it to word `40 + tid.x`. The launches
start on the empty memory with address choice and oracle 0.

* `block_of_lanes`: the kernel's block of threads `b` from memory `m` has a block's run
  (`BlockRun`) of two phases, by `BlockRun.of_turns` (its threads in order, its warps in turn by
  `CanonWait.of_turns` and `CanonRun.of_turns`), when each lane runs as the evaluator (`runTo`)
  says (`Lanes`), one lane at a time from the memory the lanes before it leave (`chain`), and its
  threads stop at one instruction, so the barrier fires (`BlockBar`).
* `sound34`: at one block of 34 threads (warps 0 and 32, the second of 2 lanes) the launch is
  sound (`Grid.Sound`) by `PhaseRun.start_sound`, observing words 40 to 73 of the block's `@sh`
  as the words `n xor 1`. `warps34`, `phase34`: the block's first phase, each warp by
  `WarpWait.of_turns`, warp 0 then warp 32 by `CanonWait.of_inv` (and, in an `example`, by
  `CanonWait.of_merge` with its premises decided). `sound26`: at two blocks of 6 threads (one
  warp each), in turn by `PhaseRun.of_inv`, observing words 40 to 45 of each block's `@sh`.

Each lane's premises are decided one lane at a time, from the memories of the lanes before it;
the trace's checks (`racy`, `kept`) and the observation are decided on the last memory. Statements
about this kernel at these two launches, not about every kernel or launch.
-/

namespace MojoProofTest.SymCanonBar

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.SymColl (tidDecl)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The kernel's text. -/
def text : String := "@sh = internal addrspace(3) global [80 x i32] undef, align 4

declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0

define ptx_kernel void @k() {
entry:
  %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %1 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %0
  store i32 %0, ptr addrspace(3) %1, align 4
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %2 = xor i32 %0, 1
  %3 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %2
  %4 = load i32, ptr addrspace(3) %3, align 4
  %5 = add i32 %0, 40
  %6 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %5
  store i32 %4, ptr addrspace(3) %6, align 4
  ret void
}

attributes #0 = { convergent }
"

/-- `%r = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %i`, with local numbers. -/
def cell (r i : Nat) : Stmt :=
  { res := some r,
    inst := .gep { inbounds := true } (.int 32) ⟨.ptr 3, .glob "sh"⟩ [⟨.int 32, .loc i⟩] }

/-- The kernel `@k`, numbered as the parser numbers it: `entry` is label 0 and `%0` to `%6` are
locals 1 to 7. -/
def kern : Func :=
  { linkage := [], cconv := some "ptx_kernel", retAttrs := [], ret := .void, name := "k",
    params := [], group := none, names := #["entry", "0", "1", "2", "3", "4", "5", "6"],
    blocks := #[⟨0, #[
      { res := some 1, inst := .call {} (.int 32) (.fn tidDecl.name) [] }, cell 2 1,
      { res := none, inst := .store false ⟨.int 32, .loc 1⟩ ⟨.ptr 3, .loc 2⟩ (some 4) },
      { res := none, inst := .call {} .void (.fn Launch.barrierName) [(⟨.int 32, .int 0⟩, [])] },
      { res := some 3, inst := .bin .xor {} (.int 32) (.loc 1) (.int 1) }, cell 4 3,
      { res := some 5, inst := .load false (.int 32) ⟨.ptr 3, .loc 4⟩ (some 4) },
      { res := some 6, inst := .bin .add {} (.int 32) (.loc 1) (.int 40) }, cell 7 6,
      { res := none, inst := .store false ⟨.int 32, .loc 5⟩ ⟨.ptr 3, .loc 7⟩ (some 4) }],
      .ret none⟩] }

/-- `@sh = internal addrspace(3) global [80 x i32] undef, align 4`. -/
def shG : Global := ⟨"sh", ["internal"], 3, false, .arr 80 (.int 32), some .undef, some 4⟩

/-- The module of `@sh`, the two intrinsics and `kern`, with attribute group 0 `convergent`. -/
def md : Module :=
  { (default : Module) with
    globals := #[shG]
    funcs := #[tidDecl, Launch.barrierDecl, kern]
    attrGroups := #[(0, [.flag "convergent"])] }

/-- The program of `md`, with the default data layout. -/
def prog : Program :=
  { module := md, sha256 := "", layout := {},
    intrinsics := [(tidDecl.name, .sreg .tid .x), (Launch.barrierName, .barrier)],
    kernels := ["k"] }

-- The parser and the import checks accept `text`, with module `md` and `prog`'s layout,
-- intrinsics and kernels.
#guard match importBytes text.toUTF8 with
  | .ok p => p.module == md && p.layout == prog.layout && p.intrinsics == prog.intrinsics &&
      p.kernels == prog.kernels
  | .error _ => false

/-- The launch of `kern` on `L`, on the empty memory, with address choice and oracle 0. -/
def start (L : Launch) : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start prog kern L [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start L` (an empty grid if it fails). -/
def run0 (L : Launch) : Grid × (Nat → Ctx) :=
  match start L with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 (L : Launch) : Grid := (run0 L).1

/-- The start's contexts. -/
def c (L : Launch) : Nat → Ctx := (run0 L).2

/-- A start that succeeds gives `g0 L` and `c L`, for every launch `L`. -/
theorem start_eq {L : Launch} (h : (start L).toBool = true) : start L = .ok (g0 L, c L) := by
  unfold g0 c run0
  cases hs : start L with
  | error => rw [hs] at h; cases h
  | ok r => rfl

/-- The start's threads. -/
def t0 (L : Launch) : Nat → Thread := Grid.thread (g0 L)

/-- Thread `n`'s run in `c L n` from `t` on `m` to its next wait or return, in at most 10 steps
(`runTo`); `t` on `m` returning to `m` if it does not get there. -/
def next (L : Launch) (n : Nat) (t : Thread) (m : Mem) : Thread × Mem × Step :=
  (runTo (c L n) 10 t m).getD (t, m, .done m)

/-- The memory before thread `n` runs, when threads `k₀`, `k₀ + 1`, … run in turn by `next` from
their threads `t`, the first on `m`: `m` up to thread `k₀`, then what a run to a wait or a return
leaves. -/
def chain (L : Launch) (t : Nat → Thread) (m : Mem) (k₀ : Nat) : Nat → Mem
  | 0 => m
  | n + 1 => if n < k₀ then m else
    match next L n (t n) (chain L t m k₀ n) with
    | (_, _, .done m') => m'
    | (_, m₁, _) => m₁

/-- The chain from thread `k₀` starts at its memory, for every launch, threads, memory and
`k₀`. -/
theorem chain_self (L : Launch) (t : Nat → Thread) (m : Mem) : ∀ k₀, chain L t m k₀ k₀ = m
  | 0 => rfl
  | k + 1 => by
    simp only [chain, Nat.lt_add_one, ↓reduceIte]

/-- The thread thread `n` stops at in the first phase, its threads in turn from thread `k₀` on
`m`. -/
def stop (L : Launch) (m : Mem) (k₀ n : Nat) : Thread :=
  (next L n (t0 L n) (chain L (t0 L) m k₀ n)).1

/-- Thread `n`'s status at the barrier: `stop L m k₀ n` waits at the barrier with argument
`i32 0`. -/
def bars (L : Launch) (m : Mem) (k₀ n : Nat) : Status :=
  .wait (stop L m k₀ n) .barrier [.bits 32 0] Launch.barrierDecl

/-- Thread `n` past the barrier. -/
def past (L : Launch) (m : Mem) (k₀ n : Nat) : Thread := (stop L m k₀ n).resume none

/-- The memory after the first phase of block `b`, threads `k₀` on, with its `.barrier`
logged. -/
def atBar (L : Launch) (m : Mem) (k₀ b : Nat) : Mem :=
  (chain L (t0 L) m k₀ (k₀ + volume L.block)).log (.barrier b)

/-- The memory block `b`, threads `k₀` on, ends at: its threads past the barrier in turn from
`atBar L m k₀ b`. -/
def fin (L : Launch) (m : Mem) (k₀ b : Nat) : Mem :=
  chain L (past L m k₀) (atBar L m k₀ b) k₀ (k₀ + volume L.block)

/-- The lanes of block `b`, threads `k₀` to `k₀ + volume L.block - 1`, from memory `m`: each
thread `n`, in turn from the memory the threads before it leave (`chain`), runs from the start
(`runTo`, 10 steps) to the barrier with argument `i32 0` at thread `stop L m k₀ n`, which is at
block 0, instruction 3 of `@k`; past the barrier it runs from `atBar L m k₀ b` on in turn to its
return. -/
def Lanes (L : Launch) (m : Mem) (k₀ b : Nat) : Prop :=
  ∀ n, k₀ ≤ n → n < k₀ + volume L.block →
    runTo (c L n) 10 (t0 L n) (chain L (t0 L) m k₀ n) =
      some (stop L m k₀ n, chain L (t0 L) m k₀ (n + 1),
        .wait .barrier [.bits 32 0] Launch.barrierDecl) ∧
    (stop L m k₀ n).at = some ("k", 0, 3) ∧
    runTo (c L n) 10 (past L m k₀ n) (chain L (past L m k₀) (atBar L m k₀ b) k₀ n) =
      some ((next L n (past L m k₀ n) (chain L (past L m k₀) (atBar L m k₀ b) k₀ n)).1,
        (next L n (past L m k₀ n) (chain L (past L m k₀) (atBar L m k₀ b) k₀ n)).2.1,
        .done (chain L (past L m k₀) (atBar L m k₀ b) k₀ (n + 1)))

/-- **A block of the kernel by its lanes**: for every launch `L` with blocks of
`volume L.block > 0` threads, memory `m` and block `b` of first thread `k₀` whose warps cover its
threads (`warpsCover`) and whose lanes run as `Lanes` says, the block has a run (`BlockRun`) from
`m` to `fin L m k₀ b`: `BlockRun.of_turns`, the barrier's checks (`BlockBar`) from each thread's
stop at one instruction. -/
theorem block_of_lanes {L : Launch} {m : Mem} {k₀ b : Nat} (hs : 0 < volume L.block)
    (hk : k₀ = b * volume L.block)
    (hT : warpsCover L (blockWarps L b) k₀ (k₀ + volume L.block) = true) (h : Lanes L m k₀ b) :
    ∃ Es, BlockRun L (c L) b (t0 L) m Es (fin L m k₀ b) := by
  have hb : BlockBar L b (bars L m k₀) (stop L m k₀) := by
    refine ⟨fun _ => .bits 32 0, fun _ => Launch.barrierDecl, 0, by decide,
      fun n hn => ⟨rfl, rfl, ?_⟩⟩
    obtain ⟨a, ha, rfl⟩ := List.mem_map.1 ((mem_block hs).2 hn)
    have ha' := List.mem_range.1 ha
    rw [← hk, (h _ (by omega) (by omega)).2.1, (h k₀ (by omega) (by omega)).2.1]
  obtain ⟨Es, e⟩ := BlockRun.of_turns (c := c L) (t := t0 L) (S := bars L m k₀) (U := stop L m k₀)
    (M₀ := chain L (t0 L) m k₀) (M₁ := chain L (past L m k₀) (atBar L m k₀ b) k₀) hT
    (fun n h1 h2 => ToWait.of_runTo (h n h1 h2).1) hb (by rw [chain_self]; rfl)
    (fun n h1 h2 => Runs.of_runTo (h n h1 h2).2.2)
  rw [chain_self] at e
  exact ⟨Es, e⟩

/-- The bytes of words 40 to `40 + n - 1` of each memory block of `bs`, each block of threads'
`@sh` (`none` if a block is missing). -/
def obs (bs : List Nat) (n : Nat) (m : Mem) : Option (List (List MemByte)) :=
  bs.mapM fun b => (m.blocks b).map (·.read 160 (4 * n))

/-- The words `j xor 1` for `j < n`, of 4 little-endian bytes each. -/
def outW (n : Nat) : List MemByte := (List.range n).flatMap fun j => leBytes 4 (j ^^^ 1)

/-! ## One block of 34 threads -/

/-- One block of 34 threads: warp 0, then warp 32 of 2 lanes. -/
def L34 : Launch := launch2 1 1 34 1

/-- The lanes at one block of 34 threads, from the start's memory, each decided by the kernel
from the memory the lanes before it leave. -/
theorem lanes34 : Lanes L34 (g0 L34).mem 0 0 := by
  intro n _ h2
  have h2 : n < 34 := h2
  interval_cases n <;> exact ⟨by kernel_rfl_late, by kernel_rfl_late, by kernel_rfl_late⟩

/-- **The kernel at one block of 34 threads is sound** (`Grid.Sound`), observing words 40 to 73
of the block's `@sh` (memory block 2) as the words `j xor 1`, by `PhaseRun.start_sound` at the
canonical run at the phase level: the block's two phases (`block_of_lanes`), warp 0 then warp 32
in each; the trace's checks and the observation decided on the last memory. -/
theorem sound34 : Grid.Sound L34 (c L34) (g0 L34) (obs [2] 34) (· = [outW 34]) := by
  obtain ⟨_, hb⟩ := block_of_lanes (L := L34) (by decide) (by decide) (by decide +kernel) lanes34
  have hc : PhaseRun L34 (c L34) (Grid.thread (g0 L34)) [0] (g0 L34).mem _ _ := .cons hb (.nil _)
  rw [show [0] = List.range (volume L34.grid) by decide] at hc
  exact PhaseRun.start_sound (start_eq (by decide +kernel)) (fun _ _ _ _ _ hc => by cases hc)
    (fun m m' h => by simp only [obs, h]) (by decide) hc
    ⟨fun _ _ => by decide +kernel, by decide +kernel, _, by kernel_rfl, rfl⟩

/-- **Each warp's first phase at one block of 34 threads**: warp 0 (32 lanes) and warp 32 (2
lanes) each run to the barrier (`WarpWait`) from the memory the threads before it leave
(`chain`) to the memory after its last lane, at the statuses `bars`, by `WarpWait.of_turns` from
`lanes34`. A statement about this kernel at this launch. -/
theorem warps34 :
    (∃ Es, WarpWait L34 (c L34) 0 (t0 L34) (g0 L34).mem Es (bars L34 (g0 L34).mem 0)
      (chain L34 (t0 L34) (g0 L34).mem 0 32)) ∧
    ∃ Es, WarpWait L34 (c L34) 32 (t0 L34) (chain L34 (t0 L34) (g0 L34).mem 0 32) Es
      (bars L34 (g0 L34).mem 0) (chain L34 (t0 L34) (g0 L34).mem 0 34) := by
  have hw (k : Nat) (hk : k + (warpLanes L34 k).length ≤ 34) := WarpWait.of_turns (L := L34)
    (c := c L34) (k := k) (t := t0 L34) (S := bars L34 (g0 L34).mem 0)
    (M := chain L34 (t0 L34) (g0 L34).mem 0)
    (fun j hj => ToWait.of_runTo (lanes34 (k + j) (Nat.zero_le _) (by
      have := mem_warpLanes.1 hj
      show k + j < 34
      omega)).1)
  obtain ⟨_, w0⟩ := hw 0 (by decide +kernel)
  obtain ⟨_, w32⟩ := hw 32 (by decide +kernel)
  rw [show 0 + (warpLanes L34 0).length = 32 by decide +kernel] at w0
  rw [show 32 + (warpLanes L34 32).length = 34 by decide +kernel] at w32
  exact ⟨⟨_, w0⟩, _, w32⟩

/-- **The first phase at one block of 34 threads, warp by warp**: warp 0 and then warp 32 run to
the barrier (`CanonWait`) from the start's memory to the memory after the 34 threads' first
phases (`chain`), by `CanonWait.of_inv` at the statuses `bars` with the memories after `0`, `1`
and `2` warps, each warp's run by `warps34`. A statement about this kernel at this launch. -/
theorem phase34 : ∃ Es, CanonWait L34 (c L34) (t0 L34) (bars L34 (g0 L34).mem 0) [0, 32]
    (g0 L34).mem Es (chain L34 (t0 L34) (g0 L34).mem 0 34) := by
  obtain ⟨⟨_, w0⟩, _, w32⟩ := warps34
  obtain ⟨Es, _, hc, rfl⟩ := CanonWait.of_inv (ks := [0, 32])
    (P := fun i m =>
      chain L34 (t0 L34) (g0 L34).mem 0 (match i with | 0 => 0 | 1 => 32 | _ => 34) = m)
    (fun i hi m hm => by
      subst hm
      match i, hi with
      | 0, _ => exact ⟨_, _, w0, rfl⟩
      | 1, _ => exact ⟨_, _, w32, rfl⟩
      | n + 2, h => simp only [List.length_cons, List.length_nil] at h; omega)
    (m := (g0 L34).mem) rfl
  exact ⟨Es, hc⟩

/-- The same first phase by `CanonWait.of_merge`, each warp at the statuses its run reaches
(`bars` on its threads), with its premises `[0, 32].Nodup`, lane 0 and `0 < volume L34.block`
decided; then `CanonWait.congr` to `bars`. -/
example : ∃ Es, CanonWait L34 (c L34) (t0 L34) (bars L34 (g0 L34).mem 0) [0, 32]
    (g0 L34).mem Es (chain L34 (t0 L34) (g0 L34).mem 0 34) := by
  obtain ⟨⟨_, w0⟩, _, w32⟩ := warps34
  obtain ⟨_, Es, _, hc, hs, rfl⟩ := CanonWait.of_merge (L := L34) (c := c L34) (ks := [0, 32])
    (V := fun n σ => σ = bars L34 (g0 L34).mem 0 n) (by decide +kernel)
    (P := fun i m =>
      chain L34 (t0 L34) (g0 L34).mem 0 (match i with | 0 => 0 | 1 => 32 | _ => 34) = m)
    (by decide) (by decide +kernel)
    (fun i hi m hm => by
      subst hm
      match i, hi with
      | 0, _ => exact ⟨_, _, _, w0, fun _ _ => rfl, rfl⟩
      | 1, _ => exact ⟨_, _, _, w32, fun _ _ => rfl, rfl⟩
      | n + 2, h => simp only [List.length_cons, List.length_nil] at h; omega)
    (m := (g0 L34).mem) rfl
  exact ⟨Es, hc.congr hs⟩

/-! ## Two blocks of 6 threads -/

/-- Two blocks of 6 threads, one warp each. -/
def L26 : Launch := launch2 2 1 6 1

/-- The memory after block 0 at two blocks of 6 threads. -/
def mid : Mem := fin L26 (g0 L26).mem 0 0

/-- The lanes at two blocks of 6 threads: block 0's from the start's memory and block 1's from
`mid`, each decided by the kernel from the memory the lanes before it leave. -/
theorem lanes26 : Lanes L26 (g0 L26).mem 0 0 ∧ Lanes L26 mid 6 1 := by
  refine ⟨fun n _ h2 => ?_, fun n h1 h2 => ?_⟩
  · have h2 : n < 6 := h2
    interval_cases n <;> exact ⟨by kernel_rfl_late, by kernel_rfl_late, by kernel_rfl_late⟩
  · have h2 : n < 12 := h2
    interval_cases n <;> exact ⟨by kernel_rfl_late, by kernel_rfl_late, by kernel_rfl_late⟩

/-- **The kernel at two blocks of 6 threads is sound** (`Grid.Sound`), observing words 40 to 45
of each block of threads' `@sh` (memory blocks 2 and 4) as the words `j xor 1`, by
`PhaseRun.start_sound`: block 0's two phases, then block 1's (`block_of_lanes`), the blocks in
turn by `PhaseRun.of_inv` with the memories after `0`, `1` and `2` blocks; the trace's checks and
the observation decided on the last memory. -/
theorem sound26 : Grid.Sound L26 (c L26) (g0 L26) (obs [2, 4] 6) (· = [outW 6, outW 6]) := by
  obtain ⟨_, b0⟩ := block_of_lanes (L := L26) (by decide) (by decide) (by decide +kernel)
    lanes26.1
  obtain ⟨_, b1⟩ := block_of_lanes (L := L26) (by decide) (by decide) (by decide +kernel)
    lanes26.2
  obtain ⟨_, _, hc, rfl⟩ := PhaseRun.of_inv (L := L26) (c := c L26) (t := t0 L26) (bs := [0, 1])
    (P := fun i m => (match i with | 0 => (g0 L26).mem | 1 => mid | _ => fin L26 mid 6 1) = m)
    (fun i hi m hm => by
      subst hm
      match i, hi with
      | 0, _ => exact ⟨_, _, b0, rfl⟩
      | 1, _ => exact ⟨_, _, b1, rfl⟩
      | n + 2, h => simp only [List.length_cons, List.length_nil] at h; omega)
    (m := (g0 L26).mem) rfl
  rw [show [0, 1] = List.range (volume L26.grid) by decide] at hc
  exact PhaseRun.start_sound (start_eq (by decide +kernel)) (fun _ _ _ _ _ hc => by cases hc)
    (fun m m' h => by simp only [obs, h]) (by decide) hc
    ⟨fun _ _ => by decide +kernel, by decide +kernel, _, by kernel_rfl, rfl⟩

end MojoProofTest.SymCanonBar
