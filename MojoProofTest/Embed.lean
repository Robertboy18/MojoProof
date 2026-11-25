import MojoProof.Sem.Embed
import MojoProof.Sym.SchedWait
import MojoProofTest.Start
import MojoProofTest.Eval

/-!
# MojoProof's side of Theorem 0 on `vadd` and on a kernel with a barrier

Instances of `MojoProof.Sem.Embed` (docs/proofs/theorem0.md), each at two launch sizes:

* `vadd` (`Kernels.vadd.prog`) on 2 blocks of 2 threads (`launch2 2 1 2 1`) and on 1 block of 4
  threads (`launch2 1 1 4 1`), with the buffers of `memV` (`MojoProofTest/Start.lean`), for every
  address choice and oracle: the five fields of `OneRun` hold from its grid (`Grid.start_oneRun`),
  and every grid reachable from it has 4 threads (`Grid.start_reach_size`), is done (the core's
  `Done` at `sig`) exactly when threads 0 to 3 have returned (`Grid.done_iff`), and has every
  thread's pending accesses and every collective call's barrier by their threads, in their blocks
  (`Grid.start_reach_pending`) (`embed`).
* The observation of an output buffer, `Mem.tensor`, is the observation of the memory with the
  same blocks and nothing else (`Mem.obs_blocks`, `Mem.tensor_blocks`; `tensor_obs`).
* `storeBar`, in which each thread stores at word `%ctaid.x * %ntid.x + %tid.x` of its buffer,
  waits at a barrier of its block of threads and loads the word back, run by the evaluator on 2
  blocks of 2 threads and on 3 blocks of 4 (`runOk`): the start's grid has the launch's number of
  threads, each thread's pending accesses are by it in its block, and the run ends in a grid of
  that many threads that have all returned, whose trace is by its threads in their blocks, has
  no race, and has one store and one load per thread and one barrier per block of threads.

Statements about these launches, this memory and these grids.
-/

namespace MojoProofTest.Embed

open MojoProof.Sem MojoProof.LLVM MojoProof MojoProofTest.Start Relation TorchLean

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a start without this.
unseal Array.anyM.loop

/-- **MojoProof's side of Theorem 0 on `vadd`**, on 2 blocks of 2 threads and on 1 block of 4,
for every address choice and oracle: `vadd` starts on `memV`, the five fields of `OneRun` hold
from its grid, and every reachable grid has 4 threads, is done exactly when threads 0 to 3 have
returned, and has every thread's pending accesses and every collective call's barrier by their
threads, in their blocks of threads. -/
theorem embed (L : Launch) (hL : L = launch2 2 1 2 1 ∨ L = launch2 1 1 4 1) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g₀ c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L argsV memV ch oracle = .ok (g₀, c) ∧
      Grid.OneRun L c g₀ ∧ ∀ g, ReflTransGen (Grid.Step L c) g₀ g →
        g.threads.size = 4 ∧
        (GPUProof.Done sig (g, L, c) ↔ ∀ n ∈ List.range 4, g.threads[n]? = some .done) ∧
        ∀ n, (g.retrace (g.pending c n ++ g.mem.trace)).ByThreads L ∧
          (g.retrace (g.fired L n ++ g.mem.trace)).ByThreads L := by
  -- The start's grid and contexts stay opaque; only `rfl` evaluates the start.
  obtain ⟨g₀, c, h⟩ : ∃ g₀ c,
      Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L argsV memV ch oracle = .ok (g₀, c) := by
    rcases hL with rfl | rfl <;> exact ⟨_, _, rfl⟩
  have hN : volume L.grid * volume L.block = 4 := by
    rcases hL with rfl | rfl <;> rfl
  refine ⟨g₀, c, h, Grid.start_oneRun h memV_bytesIn, fun g hr => ?_⟩
  have hs : g.threads.size = 4 := (Grid.start_reach_size h hr).trans hN
  refine ⟨hs, ?_, Grid.start_reach_pending h hr⟩
  rw [Grid.done_iff, hN]
  refine forall_congr' fun n => ?_
  rw [List.mem_range]
  refine imp_congr_right fun hn => or_iff_right ?_
  have hn' : n < g.threads.size := by omega
  simp [Array.getElem?_eq_getElem hn']

/-- **The observation of an output buffer reads only the blocks**, for every element type, shape,
layout, block number, type, encoding, offsets and memory: `Mem.tensor` of `m` is `Mem.tensor` of
the memory with `m`'s blocks and the default `next` and trace. -/
theorem tensor_obs {α : Type} {s : Shape} (l : Layout) (b : Nat) (t : Ty) (enc : α → Val)
    (off : Shape.Coord s → Nat) (m : Mem) :
    m.tensor l b t enc off = ({ blocks := m.blocks } : Mem).tensor l b t enc off :=
  (Mem.obs_blocks (obs := fun m : Mem => m.tensor l b t enc off)).1
    (fun _ _ e => Mem.tensor_blocks b e) m

/-- Thread `%tid.x` of block `%ctaid.x` stores `%tid.x` at word `%ctaid.x * %ntid.x + %tid.x` of
its buffer, waits at a barrier of its block of threads, and loads the word back. -/
def storeBar : String :=
  "define ptx_kernel void @k(ptr addrspace(1) %0) {\n\
      %2 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
      %3 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()\n\
      %4 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()\n\
      %5 = mul i32 %3, %4\n\
      %6 = add i32 %5, %2\n\
      %7 = getelementptr inbounds i32, ptr addrspace(1) %0, i32 %6\n\
      store i32 %2, ptr addrspace(1) %7, align 4\n\
      call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)\n\
      %8 = load i32, ptr addrspace(1) %7, align 4\n\
      ret void\n\
    }\n\
    declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()\n\
    declare i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()\n\
    declare i32 @llvm.nvvm.read.ptx.sreg.ntid.x()\n\
    declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #90\n\
    attributes #90 = { convergent }\n"

/-- Every access of the trace `tr` is by a thread below `N`, in the block of threads of its
number, for blocks of `B` threads (`Grid.ByThreads`, decided). -/
def byThreads (N B : Nat) (tr : List Event) : Bool :=
  tr.all fun | .access a => a.who.thread < N && a.who.cta == a.who.thread / B | .barrier _ => true

/-- `storeBar` started by `startText` on `blocks` blocks of `threads` threads and run by the
evaluator: the start's grid has `blocks * threads` threads, each with its pending accesses by it
in its block; the run ends in a grid of `blocks * threads` threads that have all returned, whose
trace is by its threads in their blocks, has no race (the core's `racy` at `sig`), and has
`blocks * threads` stores and loads and `blocks` barriers. -/
def runOk (blocks threads : Nat) : Except String Bool := do
  let (_, L, _, g, c) ← startText storeBar threads (fun b => [b]) blocks
  let N := volume L.grid * volume L.block
  let g' ← (g.run L c 1000 10).mapError err
  let accs := g'.mem.trace.filterMap fun | .access a => some a | .barrier _ => none
  return N == blocks * threads && g.threads.size == N && g'.threads.size == N &&
    (List.range N).all (fun n => byThreads N threads (g.pending c n ++ g.mem.trace)) &&
    g'.threads.all (· matches .done) && byThreads N threads g'.mem.trace &&
    !GPUProof.racy sig (g'.mem.trace.map (Event.toCore L)).reverse &&
    (accs.filter (·.write)).length == N &&
    (accs.filter (!·.write)).length == N &&
    (g'.mem.trace.filter (· matches .barrier _)).length == blocks

#guard (runOk 2 2).toOption == some true
#guard (runOk 3 4).toOption == some true

end MojoProofTest.Embed
