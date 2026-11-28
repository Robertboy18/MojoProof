import MojoProof.Sym.KernelWarps
import MojoProof.Sem.Replay
import MojoProof.LLVM.Import
import MojoProofTest.SymColl
import MojoProofTest.Launch
import MojoProofTest.KernelRfl
import MojoProofTest.KernelWarps

/-!
# The kernel theorem across a barrier between two warps

`Kernel.sound_of_prefixes` (MojoProof/Sym/KernelWarps.lean) on a kernel of two warps, `text`,
launched on one block of 33 threads (`L33 = launch2 1 1 33 1`: warp 0 of 32 lanes, warp 32 of
one lane), no arguments, on the empty memory, at the one admitted address choice and oracle
(`adm0`, MojoProofTest/KernelWarps.lean's). Before the barrier thread 32 (warp 32) stores 7 to
word 0 of the block's `@sh`; after it thread 0 (warp 0) loads word 0 and stores it to word 1. The
other threads only wait at the barrier. The kernel is written in the parser's form (`kern`, a
`Func`) and checked by `#guard` against `importBytes text` (the module, layout, intrinsics and
kernels), as MojoProofTest/SymCanonBar.lean does; `textLate`, the twin, is `kernLate`.

* `lanes`: each thread's two runs, each alone in its context (`runTo`, 10 steps), decided by the
  kernel one thread at a time: from the start to the barrier wait on the memory the threads
  before it leave (`M0`), and past the barrier to its return (`M1`);
* `seg_to`, `seg_end`: each warp's phase to the barrier (`WarpSegsTo`, its lanes' runs stopping
  at the barrier's wait, by `WarpSegsTo.of_inv`) and past it (`WarpSegs`), from `lanes`;
* `prefixes`: `Kernel.Prefixes` at one barrier (`J = 1`), the threads `T` (the start's, then the
  ones past the barrier) and the memories `pm` by phase and warps done;
* `sound`: the kernel is sound (`Kernel.Sound`), observing word 1 of the block's `@sh` as the word
  7: `Kernel.sound_of_prefixes` at `prefixes`, the end checks (no data race, the promise of
  `!invariant.load` kept, the observation) decided on the last memory;
* `race`, the twin: with the barrier at `entry`, before thread 32's store (`textLate`), thread
  0's load and thread 32's store of word 0 are in one phase, a data race the checker reports
  (`Kernel.replay`), so by `Kernel.replay_unsafe` the kernel is sound for no observation, of any
  type, and relation.

No lane's run past what `Kernel.Prefixes` asks is written: each lane runs once to the barrier
(`RunsUpto`, in `WarpSegsTo`) and once from it (`RunsVia`, in `WarpSegs`). Statements about this
kernel at this launch, memory and admission, not about every kernel.
-/

namespace MojoProofTest.KernelTwoWarp

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.SymColl (tidDecl)
open MojoProofTest.KernelWarps (adm0)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The kernel's text: thread 32 stores 7 to `@sh[0]` before the barrier, thread 0 copies
`@sh[0]` to `@sh[1]` after it. -/
def text : String := "@sh = internal addrspace(3) global [2 x i32] undef, align 4

declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0

define ptx_kernel void @k() {
entry:
  %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %1 = icmp eq i32 %0, 32
  br i1 %1, label %st, label %bar
st:
  store i32 7, ptr addrspace(3) @sh, align 4
  br label %bar
bar:
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %2 = icmp eq i32 %0, 0
  br i1 %2, label %ld, label %done
ld:
  %3 = load i32, ptr addrspace(3) @sh, align 4
  %4 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 1
  store i32 %3, ptr addrspace(3) %4, align 4
  br label %done
done:
  ret void
}

attributes #0 = { convergent }
"

/-- The twin's text: `text` with the barrier moved before thread 32's store, into one phase with
thread 0's load. -/
def textLate : String := "@sh = internal addrspace(3) global [2 x i32] undef, align 4

declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()
declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0

define ptx_kernel void @k() {
entry:
  %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
  %1 = icmp eq i32 %0, 32
  br i1 %1, label %st, label %bar
st:
  store i32 7, ptr addrspace(3) @sh, align 4
  br label %bar
bar:
  %2 = icmp eq i32 %0, 0
  br i1 %2, label %ld, label %done
ld:
  %3 = load i32, ptr addrspace(3) @sh, align 4
  %4 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 1
  store i32 %3, ptr addrspace(3) %4, align 4
  br label %done
done:
  ret void
}

attributes #0 = { convergent }
"


/-- `@sh`, the pointer operand. -/
def sh : TValue := ⟨.ptr 3, .glob "sh"⟩

/-- `%0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`, local 1. -/
def tidS : Stmt := { res := some 1, inst := .call {} (.int 32) (.fn tidDecl.name) [] }

/-- `call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)`. -/
def barS : Stmt :=
  { res := none, inst := .call {} .void (.fn Launch.barrierName) [(⟨.int 32, .int 0⟩, [])] }

/-- `%r = icmp eq i32 %0, k`. -/
def eqS (r : Nat) (k : Int) : Stmt :=
  { res := some r, inst := .icmp .eq (.int 32) (.loc 1) (.int k) }

/-- Block `%st`: `store i32 7, ptr addrspace(3) @sh, align 4`, then to `%bar`. -/
def stB : LLVM.Block :=
  ⟨3, #[{ res := none, inst := .store false ⟨.int 32, .int 7⟩ sh (some 4) }], .br 4⟩

/-- Block `%ld`: word 0 of `@sh` loaded and stored to word 1, then to `%done`. -/
def ldB : LLVM.Block :=
  ⟨6, #[{ res := some 8, inst := .load false (.int 32) sh (some 4) },
    { res := some 9, inst := .gep { inbounds := true } (.int 32) sh [⟨.int 32, .int 1⟩] },
    { res := none, inst := .store false ⟨.int 32, .loc 8⟩ ⟨.ptr 3, .loc 9⟩ (some 4) }], .br 7⟩

/-- The function `@k` with blocks `bs`, numbered as the parser numbers `text`'s: `entry`, `%st`,
`%bar`, `%ld` and `%done` are labels 0, 3, 4, 6 and 7, `%0` to `%4` locals 1, 2, 5, 8 and 9. -/
def kernOf (bs : Array LLVM.Block) : Func :=
  { linkage := [], cconv := some "ptx_kernel", retAttrs := [], ret := .void, name := "k",
    params := [], group := none,
    names := #["entry", "0", "1", "st", "bar", "2", "ld", "done", "3", "4"], blocks := bs }

/-- `text`'s kernel: the barrier at position 0 of `%bar` (label 4). -/
def kern : Func :=
  kernOf #[⟨0, #[tidS, eqS 2 32], .condBr (.loc 2) 3 4⟩, stB,
    ⟨4, #[barS, eqS 5 0], .condBr (.loc 5) 6 7⟩, ldB, ⟨7, #[], .ret none⟩]

/-- `textLate`'s kernel: the barrier at position 1 of `entry` (label 0). -/
def kernLate : Func :=
  kernOf #[⟨0, #[tidS, barS, eqS 2 32], .condBr (.loc 2) 3 4⟩, stB,
    ⟨4, #[eqS 5 0], .condBr (.loc 5) 6 7⟩, ldB, ⟨7, #[], .ret none⟩]

/-- `@sh = internal addrspace(3) global [2 x i32] undef, align 4`. -/
def shG : Global := ⟨"sh", ["internal"], 3, false, .arr 2 (.int 32), some .undef, some 4⟩

/-- The program of `@sh`, the two intrinsics and the kernel `f`, with attribute group 0
`convergent` and the default data layout. -/
def progOf (f : Func) : Program :=
  { module := { (default : Module) with
      globals := #[shG], funcs := #[tidDecl, Launch.barrierDecl, f]
      attrGroups := #[(0, [.flag "convergent"])] }
    sha256 := "", layout := {},
    intrinsics := [(tidDecl.name, .sreg .tid .x), (Launch.barrierName, .barrier)],
    kernels := ["k"] }

/-- `text`'s program. -/
def prog : Program := progOf kern

/-- `textLate`'s program. -/
def progLate : Program := progOf kernLate

-- The parser and the import checks accept `text` and `textLate`, with modules, layouts,
-- intrinsics and kernels `prog`'s and `progLate`'s.
#guard match importBytes text.toUTF8 with
  | .ok p => p.module == prog.module && p.layout == prog.layout &&
      p.intrinsics == prog.intrinsics && p.kernels == prog.kernels
  | .error _ => false
#guard match importBytes textLate.toUTF8 with
  | .ok p => p.module == progLate.module && p.layout == progLate.layout &&
      p.intrinsics == progLate.intrinsics && p.kernels == progLate.kernels
  | .error _ => false

/-- One block of 33 threads: warp 0 of 32 lanes, then warp 32 of 1 lane. -/
def L33 : Launch := launch2 1 1 33 1

/-- The launch of `kern` on `L33`, no arguments, on the empty memory, with address choice and
oracle 0. -/
def start : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start prog kern L33 [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start` (an empty grid if it fails). -/
def run0 : Grid × (Nat → Ctx) :=
  match start with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 : Grid := run0.1

/-- The start's contexts. -/
def c : Nat → Ctx := run0.2

/-- The launch starts, with grid `g0` and contexts `c`. -/
theorem start_eq : start = .ok (g0, c) := by
  have h : start.toBool = true := by decide +kernel
  unfold g0 c run0
  cases hs : start with
  | error => rw [hs] at h; cases h
  | ok r => rfl

/-- Thread `n`'s run in `c n` from `t` on `m` to its next wait or return, in at most 10 steps
(`runTo`); `t` on `m` returning to `m` if it does not get there. -/
def next (n : Nat) (t : Thread) (m : Mem) : Thread × Mem × Step :=
  (runTo (c n) 10 t m).getD (t, m, .done m)

/-- The memory before thread `n` runs, when threads `0`, `1`, … run in turn by `next` from their
threads `t`, the first on `m`: what a run to a wait or a return leaves. -/
def chain (t : Nat → Thread) (m : Mem) : Nat → Mem
  | 0 => m
  | n + 1 =>
    match next n (t n) (chain t m n) with
    | (_, _, .done m') => m'
    | (_, m₁, _) => m₁

/-- The start's threads. -/
def t0 : Nat → Thread := Grid.thread g0

/-- The memories before the barrier: before thread `n`'s run from the start. -/
def M0 : Nat → Mem := chain t0 g0.mem

/-- The thread thread `n` stops at before the barrier. -/
def stop (n : Nat) : Thread := (next n (t0 n) (M0 n)).1

/-- Thread `n` past the barrier. -/
def past (n : Nat) : Thread := (stop n).resume none

/-- The memory past the barrier: after the 33 threads' runs to it, with block 0's `.barrier`
logged. -/
def mB : Mem := (M0 33).log (.barrier 0)

/-- The memories past the barrier: before thread `n`'s run from `past n`. -/
def M1 : Nat → Mem := chain past mB

/-- Memory block 2, block 0's `@sh` at this launch (blocks 0 and 1 are the launch's others: no
block 0, a block of size 0), by the start's evaluation: 8 undefined bytes. -/
def shB : Nat := 2

/-- Block 0's `@sh` is memory block `shB` of the start's memory, of 8 bytes. -/
theorem shB_size : (g0.mem.blocks shB).map (·.size) = some 8 := by decide +kernel

/-- The bytes of word 1 of block 0's `@sh` (memory block `b`), `none` if the block is missing. -/
def obs (b : Nat) (m : Mem) : Option (List MemByte) := (m.blocks b).map (·.read 4 4)

/-- Thread `n`'s runs, each in its context alone (`runTo`, 10 steps): from the start's thread on
the memory the threads before it leave (`M0 n`) to the barrier with argument `i32 0`, at thread
`stop n` on `M0 (n + 1)`; `stop n` is at block 4, position 0 of `@k` (`%bar`'s barrier call);
past the barrier from `M1 n` to its return, leaving `M1 (n + 1)`. -/
def Lane (n : Nat) : Prop :=
  runTo (c n) 10 (t0 n) (M0 n) =
      some (stop n, M0 (n + 1), .wait .barrier [.bits 32 0] Launch.barrierDecl) ∧
    (stop n).at = some ("k", 4, 0) ∧
    runTo (c n) 10 (past n) (M1 n) =
      some ((next n (past n) (M1 n)).1, (next n (past n) (M1 n)).2.1, .done (M1 (n + 1)))

/-- Each of the 33 threads runs as `Lane` says, decided by the kernel one thread at a time. -/
theorem lanes : ∀ n < 33, Lane n := by
  intro n hn
  interval_cases n <;> exact ⟨by kernel_rfl_late, by kernel_rfl_late, by kernel_rfl_late⟩

/-- The block's warps: warp 0 (lanes 0 to 31) and warp 32 (lane 0, thread 32). -/
theorem warps : blockWarps L33 0 = [0, 32] := by decide

/-- Warp 0's lanes. -/
theorem lanes0 : warpLanes L33 0 = List.range 32 := by decide

/-- Warp 32's one lane. -/
theorem lanes32 : warpLanes L33 32 = [0] := by decide

/-- The threads of the two warps are the block's 33. -/
theorem lane_lt {k j : Nat} (hk : k = 0 ∨ k = 32) (hj : j ∈ warpLanes L33 k) : k + j < 33 := by
  rcases hk with rfl | rfl
  · rw [lanes0] at hj
    have := List.mem_range.1 hj
    omega
  · rw [lanes32, List.mem_singleton] at hj
    omega

/-- The phases' threads: thread `n` in phase 0 is the start's, in phase 1 the one past the
barrier. -/
def T : Nat → Nat → Nat → Thread → Prop := fun _ i n t =>
  match i with
  | 0 => t = t0 n
  | _ => t = past n

/-- The memories by block, phase and number of the phase's warps done: before the barrier, the
start's, then the one warp 0's 32 lanes leave, then the one warp 32's lane leaves (its store);
past it, the one with the barrier logged, then after warp 0's lanes (thread 0's copy), then
after warp 32's. -/
def pm : Nat → Nat → Nat → Mem
  | 0, 0, 0 => M0 0
  | 0, 0, 1 => M0 32
  | 0, 0, _ => M0 33
  | 0, _, 0 => mB
  | 0, _, 1 => M1 32
  | _, _, _ => M1 33

/-- The memory predicates: equal to `pm`'s. -/
def P : Nat → Nat → Nat → Mem → Prop := fun b i w m => m = pm b i w

/-- **Each warp's phase to the barrier has `WarpSegsTo`**, warp `k` of 0 and 32, from the start's
threads on `M0 k`: `WarpSegsTo.of_inv` at the invariant that the memory after the warp's first `j`
lanes is `M0 (k + j)`, each lane's run to the barrier's wait by `lanes`, the lane resumed there
with no value the phase-1 thread (`past`); the memory after the warp is `M0` after its last
lane. -/
theorem seg_to (k : Nat) (hk : k = 0 ∨ k = 32) (t : Nat → Thread)
    (ht : ∀ j ∈ warpLanes L33 k, T 0 0 (k + j) (t (k + j))) (Q : Mem → Prop)
    (hQ : Q (M0 (k + (warpLanes L33 k).length))) :
    WarpSegsTo prog kern L33 c k t (M0 k) 0 4 0 (T 0 1) Q :=
  WarpSegsTo.of_inv (fun j m => m = M0 (k + j)) rfl (fun j hj m (hm : m = M0 (k + j)) => by
    have hl := lanes _ (lane_lt hk hj)
    subst hm
    rw [show t (k + j) = t0 (k + j) from ht j hj]
    exact ⟨_, _, _, _, ToWait.of_runTo hl.1, rfl, hl.2.1, rfl, rfl⟩) fun _ h => h ▸ hQ

/-- **Each warp's phase past the barrier has `WarpSegs`**, warp `k` of 0 and 32, from the phase-1
threads on `M1 k`: no shuffle, each lane's run to its return by `lanes`; the memory after the
warp is `M1` after its last lane. -/
theorem seg_end (k : Nat) (hk : k = 0 ∨ k = 32) (t : Nat → Thread)
    (ht : ∀ j ∈ warpLanes L33 k, T 0 1 (k + j) (t (k + j))) (Q : Mem → Prop)
    (hQ : Q (M1 (k + (warpLanes L33 k).length))) :
    WarpSegs prog kern L33 c k t (M1 k) Q := by
  refine ⟨0, fun _ => 4, fun _ => .bfly, fun _ => 0, fun _ => 0, fun _ => 0,
    fun _ _ => .poison, ⟨0, .barrier, [], {}, (none, {})⟩, fun _ => [], fun _ j => M1 (k + j),
    rfl, hQ, fun j hj => ?_, fun _ _ => rfl, fun _ h => absurd h (by omega),
    fun _ h => absurd h (by omega), fun _ h => absurd h (by omega)⟩
  rw [show t (k + j) = past (k + j) from ht j hj]
  exact RunsVia.of_runs (Runs.of_runTo (lanes _ (lane_lt hk hj)).2.2) rfl

/-- `pm` before the barrier, no warp done: the start's memory. -/
theorem pm_000 : pm 0 0 0 = M0 0 := rfl

/-- `pm` before the barrier, warp 0 done. -/
theorem pm_001 : pm 0 0 1 = M0 32 := rfl

/-- `pm` before the barrier, both warps done. -/
theorem pm_002 : pm 0 0 2 = M0 33 := rfl

/-- `pm` past the barrier, no warp done: the memory with the barrier logged. -/
theorem pm_010 : pm 0 1 0 = M1 0 := rfl

/-- `pm` past the barrier, warp 0 done. -/
theorem pm_011 : pm 0 1 1 = M1 32 := rfl

/-- `pm` past the barrier, both warps done. -/
theorem pm_012 : pm 0 1 2 = M1 33 := rfl

/-- `pm` after the block: the memory both warps leave past the barrier. -/
theorem pm_100 : pm 1 0 0 = M1 33 := rfl

/-- The memory before the barrier with block 0's `.barrier` logged is the one the lanes start
from past it. -/
theorem mB_eq : (M0 33).log (.barrier 0) = M1 0 := rfl

/-- `P` is equality with `pm`. -/
theorem P_iff {b i w : Nat} {m : Mem} : P b i w m ↔ m = pm b i w := Iff.rfl

/-- Warp 0 ends at thread 32. -/
theorem len0 : 0 + (warpLanes L33 0).length = 32 := by rw [lanes0, List.length_range]

/-- Warp 32 ends at thread 33. -/
theorem len32 : 32 + (warpLanes L33 32).length = 33 := by rw [lanes32]; rfl

/-- Warp 0's phase to the barrier, from the start's memory, by `seg_to`. -/
theorem phase0_0 (t : Nat → Thread) (m₀ : Mem)
    (ht : ∀ j ∈ warpLanes L33 0, T 0 0 (0 + j) (t (0 + j))) (hm₀ : P 0 0 0 m₀) :
    WarpSegsTo prog kern L33 c 0 t m₀ 0 4 0 (T 0 1) (P 0 0 1) := by
  rw [P_iff.1 hm₀, pm_000]
  exact seg_to 0 (.inl rfl) t ht _ (by rw [P_iff, len0, pm_001])

/-- Warp 32's phase to the barrier, from the memory warp 0 leaves, by `seg_to`. -/
theorem phase0_1 (t : Nat → Thread) (m₀ : Mem)
    (ht : ∀ j ∈ warpLanes L33 32, T 0 0 (32 + j) (t (32 + j))) (hm₀ : P 0 0 1 m₀) :
    WarpSegsTo prog kern L33 c 32 t m₀ 0 4 0 (T 0 1) (P 0 0 2) := by
  rw [P_iff.1 hm₀, pm_001]
  exact seg_to 32 (.inr rfl) t ht _ (by rw [P_iff, len32, pm_002])

/-- Warp 0's phase past the barrier, from the memory with the barrier logged, by `seg_end`. -/
theorem phase1_0 (t : Nat → Thread) (m₀ : Mem)
    (ht : ∀ j ∈ warpLanes L33 0, T 0 1 (0 + j) (t (0 + j))) (hm₀ : P 0 1 0 m₀) :
    WarpSegs prog kern L33 c 0 t m₀ (P 0 1 1) := by
  rw [P_iff.1 hm₀, pm_010]
  exact seg_end 0 (.inl rfl) t ht _ (by rw [P_iff, len0, pm_011])

/-- Warp 32's phase past the barrier, from the memory warp 0 leaves, by `seg_end`. -/
theorem phase1_1 (t : Nat → Thread) (m₀ : Mem)
    (ht : ∀ j ∈ warpLanes L33 32, T 0 1 (32 + j) (t (32 + j))) (hm₀ : P 0 1 1 m₀) :
    WarpSegs prog kern L33 c 32 t m₀ (P 0 1 2) := by
  rw [P_iff.1 hm₀, pm_011]
  exact seg_end 32 (.inr rfl) t ht _ (by rw [P_iff, len32, pm_012])

/-- Phase 0 of the block, its two warps by `phase0_0` and `phase0_1`. -/
theorem phase0 : ∀ w (hw : w < (blockWarps L33 0).length), ∀ t m₀,
      (∀ j ∈ warpLanes L33 (blockWarps L33 0)[w],
        T 0 0 ((blockWarps L33 0)[w] + j) (t ((blockWarps L33 0)[w] + j))) →
      P 0 0 w m₀ →
      WarpSegsTo prog kern L33 c (blockWarps L33 0)[w] t m₀ 0 4 0 (T 0 (0 + 1))
        (P 0 0 (w + 1)) := by
  intro w hw t m₀ ht hm₀
  simp only [warps, List.length_cons, List.length_nil] at hw
  rcases (by omega : w = 0 ∨ w = 1) with rfl | rfl
  · simp only [warps, List.getElem_cons_zero] at ht ⊢
    exact phase0_0 t m₀ ht hm₀
  · simp only [warps, List.getElem_cons_succ, List.getElem_cons_zero] at ht ⊢
    exact phase0_1 t m₀ ht hm₀

/-- Phase 1 of the block, its two warps by `phase1_0` and `phase1_1`. -/
theorem phase1 : ∀ w (hw : w < (blockWarps L33 0).length), ∀ t m₀,
      (∀ j ∈ warpLanes L33 (blockWarps L33 0)[w],
        T 0 1 ((blockWarps L33 0)[w] + j) (t ((blockWarps L33 0)[w] + j))) →
      P 0 1 w m₀ → WarpSegs prog kern L33 c (blockWarps L33 0)[w] t m₀ (P 0 1 (w + 1)) := by
  intro w hw t m₀ ht hm₀
  simp only [warps, List.length_cons, List.length_nil] at hw
  rcases (by omega : w = 0 ∨ w = 1) with rfl | rfl
  · simp only [warps, List.getElem_cons_zero] at ht ⊢
    exact phase1_0 t m₀ ht hm₀
  · simp only [warps, List.getElem_cons_succ, List.getElem_cons_zero] at ht ⊢
    exact phase1_1 t m₀ ht hm₀

/-- **The kernel's phases, the one to the barrier cut there**: `Kernel.Prefixes` at one barrier
(`J = 1`), the threads `T` and the memories `P`: the start's threads and memory; in phase 0 the
barrier word 0 at block 4, position 0, warp 0 then warp 32 by `seg_to`; the barrier's log by
`pm`; in phase 1 the two warps by `seg_end`. -/
theorem prefixes : Kernel.Prefixes prog kern L33 c g0 (fun _ => 1) T P := by
  have hg : volume L33.grid = 1 := rfl
  refine ⟨fun n => rfl, P_iff.2 pm_000, fun b hb i hi => ?_, fun b hb i hi m₁ hm₁ => ?_,
    fun b hb => ?_, fun b hb m₁ hm₁ => ?_⟩
  · obtain rfl : b = 0 := by omega
    obtain rfl : i = 0 := Nat.lt_one_iff.1 hi
    exact ⟨0, by decide, 4, 0, phase0⟩
  · obtain rfl : b = 0 := by omega
    obtain rfl : i = 0 := Nat.lt_one_iff.1 hi
    rw [warps, P_iff] at hm₁
    rw [hm₁, P_iff, pm_010]
    exact mB_eq
  · obtain rfl : b = 0 := by omega
    exact phase1
  · obtain rfl : b = 0 := by omega
    rw [warps, P_iff] at hm₁
    rw [hm₁, P_iff, pm_100]
    rfl

/-- **The kernel is sound by `Kernel.sound_of_prefixes`**, at one block of 33 threads (`L33`: warp
0 of 32 lanes, warp 32 of one), no arguments, on the empty memory, at the one admitted address
choice and oracle (`adm0`): word 1 of the block's `@sh` ends as the word 7 that thread 32 stored
to word 0 before the barrier and thread 0 copied after it. One barrier (`J = 1`), the phases by
`prefixes`; at the end the trace has no data race (thread 32's store and thread 0's load are in
different phases) and keeps the promise of `!invariant.load`, decided on the last memory. -/
theorem sound : Kernel.Sound prog kern L33 [] {} adm0 (obs shB) (· = leBytes 4 7) := by
  have hg : volume L33.grid = 1 := rfl
  refine Kernel.sound_of_prefixes (fun _ _ _ _ _ hc => by cases hc) (by decide)
    (fun ch oracle ⟨hch, ho⟩ => ⟨_, _, by subst hch ho; exact start_eq⟩)
    (fun m m' h => by simp only [obs, h]) (fun ch oracle g c' ⟨hch, ho⟩ h => ?_)
  subst hch ho
  obtain ⟨hg0, hc0⟩ := Prod.mk.inj (Except.ok.inj (start_eq.symm.trans h))
  subst hg0 hc0
  refine ⟨fun _ => 1, T, P, prefixes, fun m' hm' => ?_⟩
  rw [hg, P_iff, pm_100] at hm'
  rw [hm']
  exact ⟨fun _ _ => by decide +kernel, by decide +kernel, _, by kernel_rfl, rfl⟩

/-- **The twin: with the barrier before thread 32's store, the kernel is sound for no observation
and relation**, for every type `β`, observation `o` and relation `R` on `β`, at the same launch,
memory and admission: the barrier at `entry` puts thread 32's store to word 0 of `@sh` and thread
0's load of it in one phase, a data race the checker reports (`Kernel.replay` at the choice and
oracle 0, 20 steps per thread and phase, 3 phases), so `Kernel.replay_unsafe` refutes every
kernel theorem there. -/
theorem race {β : Type} (o : Mem → Option β) (R : β → Prop) :
    ¬ Kernel.Sound progLate kernLate L33 [] {} adm0 o R :=
  Kernel.replay_unsafe (ch := fun _ => 0) (oracle := fun _ _ => 0) (fuel := 20) (phases := 3)
    (by decide +kernel) ⟨rfl, rfl⟩

end MojoProofTest.KernelTwoWarp
