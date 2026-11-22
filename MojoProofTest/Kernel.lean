import MojoProof.Kernels.Vadd
import MojoProof.Kernels.Vmul
import MojoProof.Kernels.Vsub
import MojoProofTest.SymRun
import MojoProofTest.SymPhi
import MojoProofTest.Start
import MojoProof.Sem.ScheduleOwned
import TorchLean.Tensor.Arithmetic

/-!
# The kernel theorem on `vector_addition`: instances at one launch and memory

An instance of `Kernel.sound_eval` (MojoProof/Sym/Kernel.lean), on the paths `mojo_kernel` makes
(`Kernels.vadd.paths`, MojoProof/Kernels/Vadd.lean): `vector_addition` (`Kernels.vadd`) on 2 blocks
of 2 threads (`two2`, MojoProofTest/Start.lean) with element count 3, its inputs `inA`, `inB` and
output at blocks 1 to 3 of `mem0` (MojoProofTest/SymRun.lean), address choice `ch₀` (every choice
0) and oracle `ω₀` (every number 0).

* `start22`: the launch starts (evaluated), with grid `g22` and contexts `c22`; `size22`: it has
  4 threads.
* `kernel22`: the kernel is sound (`Kernel.Sound`) for the observation of the blocks and the
  relation that cells 0 to 2 of the output hold the FloatLib sums `Model.add` of the inputs'
  cells (`sums3`), by `Kernel.sound_eval` on `Kernels.vadd.covers`: the kernel evaluates that each
  thread in turn, from the memory the threads before it left, has a path of `Kernels.vadd.paths` to
  `ret` (`%4 → %21 → %31` for threads 0 to 2, `%4 → %30 → %31` for thread 3, whose index is not
  below the count), and the last memory's trace and cells.
* Twins: `out_twin`: thread 0 does not take the path through `%30`, so the path is chosen per
  thread; `entry_twin`: a path that starts at `%21` is accepted by the path checker with `phi`s
  but refused by `coversEntry`, so the entry check is needed; `elem_twin`: a memory meeting
  `Elem` with an owned trace of two writes by threads 0 and 2 to one cell (`4 * (i % 2)` is not
  `Apart`) has a data race, so `Elem.safe` needs `Apart`.
* `elem22`, `elem1`: instances of `Elem.zero`, `Elem.succ` and `Elem.safe`: the start's memory
  meets `Elem` with no thread done; a store of 4 bytes by thread 0 to its cell meets it after one.
* `start_ctx_vadd`: for every launch, arguments, memory, address choice and oracle, the start's
  context of each thread meets `Kernels.vadd.ret`'s premises on the context (`Grid.start_ctx`,
  `Grid.start_env`).
* `phi_runs`: `Runs.of_ret` on a path with a join (an edge into a block with a `phi`), the
  naive matmul kernel's `%46 → %51 → %67 → %69` from `%46`'s position 2 for a thread whose loop
  runs no trip (MojoProofTest/SymPhi.lean): the kernel decides it is a `Ret` (`Ret.check`), so
  the thread runs to its end with output cell 0 holding the accumulator's value 1.
* `correct23`: `Kernels.vadd.correct` with every premise discharged, on 2 blocks of 3 threads
  (`L23`, `valid23`) with count 5, inputs `x5` (1, 2, 4, 8, 16) and `y5` (32, 16, 8, 4, 2), and
  the caller's memory `mem5` that `Map2.mem` builds (alignment 16, generic addresses
  `16 (2 i + 1)`), which meets `Map2.Pre` by `Map2.pre_mem` (`pre5`): for every oracle `ω`, the
  kernel is sound at every address choice and `ω`, with output cell `4 i` of thread `i < 5`
  holding `deliver (x5_i + y5_i)` and thread 5's cell untouched.
* `correct12`: the same with fewer threads than the count, on one block of 2 threads (`L12`,
  `valid12`) with `mem5` and count 5: only cells `4 i` of the threads `i < 2` are put, and cells
  2 to 4 keep `mem5`'s contents.

* `evalRun`, `evalRun_ok`, `evalRun_ub`: `Grid.start` then `Grid.run` (fuel 64, one phase) at
  `ch₀` and `ω₀`, and the start's and the run's equations from a check of its result that the
  kernel evaluates.
* `g2_vadd` (the satisfiability witness): the run on `L23`, count 5 and `mem5` ends with
  every thread returned; by kernel evaluation its blocks agree with `correct23`'s `Elem.Out`
  (`Elem.outBelow`) and its output cells hold the sums `sums5`; `correct23` gives `Elem.Out`.
* Negative twins, each refuting `Kernel.Sound` for every observation, relation and admission
  that admits `ch₀` and `ω₀`, by the trace-replay checker
  (`Kernel.replay_unsafe`, MojoProof/Sem/Replay.lean): (a) `pre4_5`, `run_len`, `twin_len`:
  `mem4`, whose output has 4 floats, meets every field of `Map2.Pre` at count 5 but the output's
  length, and the run faults (`access out of bounds`); (b) `pre_alias`, `run_alias`,
  `twin_alias`: an output at the first input's block is refused by `Map2.Pre` (`ne`), and on
  `mem5w` (that block writable) the run ends with no race and `kept` false, with the broken
  promise `broken?` names; (c) `run_tid`, `twin_tid`: `fnTid` (index `tid.x` alone, an edit of
  one instruction of `Kernels.vadd.prog`'s kernel, in `progTid`) on 2 blocks has a race, with the
  two accesses `race?` names; (d) `twin_2d`: the two-dimensional block `L32` is valid but
  rejected by `Kernels.vadd.correct`'s hypothesis, and the checker reports a race there.
* `canaries_vadd`, `canaries_vmul`, `canaries_vsub`: for every admission that admits `ch₀` and
  `ω₀`, the kernel is not sound for `Elem.Out` with any of `Elem.canaries`'s five wrong outputs
  of `correct23`'s bytes, of `correctV23`'s (`Kernels.vmul` on `memV`, inputs `x5`, `x5`) and of
  `correctS23`'s (`Kernels.vsub`, the worked example of docs/new-kernel.md, on `mem5`) at `ω₀`,
  certified by the checker (`Kernel.replay_canaries`); `correct23`, `correctV23` and
  `correctS23` are the controls.
* The corollaries for every valid one-dimensional launch (grid and block of side 1 in `y` and
  `z`), alignment that 4 divides, memory meeting `Map2.Pre`, address choice and oracle:
  `vadd_min`, `vmul_min`, `vsub_min` (`Elem.Out` after `min n T` threads), `vadd_real`,
  `vmul_real`, `vsub_real` (a finite output float is, cell by cell, TorchLean's `x + y`, `x * y`
  or `x - y` at the cell, and its real value is the rounded real result), `vadd_finEq`,
  `vmul_finEq`, `vsub_finEq` (two runs' output floats are equal up to `FinEq`), each one
  application of `Kernel.map2_min`, `Kernel.map2_real` or `Kernel.map2_finEq`
  (MojoProof/Sym/Kernel.lean) to `Kernels.vadd.correct`, `Kernels.vmul.correct` or
  `Kernels.vsub.correct`, and `vadd_stable`, `vmul_stable`, `vsub_stable` (a finite output float
  is the same in every run), from the `finEq` theorems and `FinEq.eq_of_isFinite`. Each covers
  one kernel.

Each result but `start_ctx_vadd`, `pre_alias` and the corollaries covers the launch and memories
named (`correct23`, `correct12`, `correctV23` and `correctS23` every address choice and
oracle; the twins' and canaries' refutations every admission that admits `ch₀` and `ω₀`; the
others `ch₀` and `ω₀`), not every program.
-/

namespace MojoProofTest.Kernel

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Sym MojoProofTest.SymRun
open MojoProofTest.Start
open FloatLib.Floats.Formats.BinaryInterchange

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- Every address choice 0. -/
def ch₀ : Nat → Nat := fun _ => 0

/-- Every oracle number 0. -/
def ω₀ : Nat → Nat → Nat := fun _ _ => 0

/-- The arguments: the inputs at blocks 1 and 2, the output at block 3, and the count 3. -/
def args3 : List Val := [buf 1, buf 2, buf 3, .bits 32 (BitVec.ofNat 32 3)]

/-- The start's grid and contexts (the empty grid if it faults). -/
def run22 : Grid × (Nat → Ctx) :=
  match Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 two2 args3 mem0 ch₀ ω₀ with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ctx0)

/-- The start's grid. -/
def g22 : Grid := run22.1

/-- The start's contexts. -/
def c22 : Nat → Ctx := run22.2

/-- **The launch starts**, with grid `g22` and contexts `c22` (evaluated). -/
theorem start22 :
    Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 two2 args3 mem0 ch₀ ω₀ = .ok (g22, c22) := rfl

/-- The start has 4 threads. -/
theorem size22 : g22.threads.size = 4 := by decide +kernel

/-- `mem0` has no pointer byte. -/
theorem mem0_bytesIn : mem0.BytesIn mem0.Known := by
  have h0 : ({} : Mem).BytesIn mem0.Known := fun _ _ _ _ _ h => by cases h
  have hA : ∀ (xs : List Nat) p j, MemByte.ptr p j ∈ xs.flatMap (leBytes 4) →
      mem0.Known p.block := by
    intro xs p j h
    simp [leBytes] at h
  exact Mem.alloc_bytesIn (Mem.alloc_bytesIn (Mem.alloc_bytesIn h0 (hA inA) _ _ _ _ _ _ _ _ _ _)
    (hA inB) _ _ _ _ _ _ _ _ _ _) (init := []) (fun _ _ h => by cases h) _ _ _ _ _ _ _ _ _ _

/-- The frame of thread `k` of the start (`frame4 0` if it has none). -/
def fr22 (k : Nat) : Frame := ((Grid.thread g22 k).frames.head?).getD (frame4 0)

/-- Cells 0 to 2 of the output (block 3) of blocks `B` hold the FloatLib sums `Model.add` of
cells 0 to 2 of the inputs. -/
def sums3 (B : Nat → Option Sem.Block) : Bool := (List.range 3).all fun i =>
  match ({ blocks := B } : Mem).load Kernels.vadd.prog.layout ⟨0, 0⟩ 0 (.fp .float) ⟨3, 4 * i⟩
      (some 4) with
  | .ok v => decide (v.float? .float = some (Model.add (Model.ofNatBits (inA.getD i 0))
      (Model.ofNatBits (inB.getD i 0))))
  | .error _ => false

/-- **The kernel theorem at one launch** (`Kernel.sound_eval`): `vector_addition` on 2 blocks
of 2 threads with count 3 on `mem0`, at address choice `ch₀` and oracle `ω₀`, is sound for the
observation of the blocks, whose output cells 0 to 2 hold the sums of the inputs' cells. The
kernel evaluates that each thread, in turn, has a path of `Kernels.vadd.paths` to `ret`
(`Kernel.check`), and the last memory's trace and cells. -/
theorem kernel22 : Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 two2 args3 mem0
    (fun ch o => ch = ch₀ ∧ o = ω₀) (fun m => some m.blocks) (fun B => sums3 B = true) :=
  Kernel.sound_eval Kernels.vadd.covers mem0_bytesIn start22 (fun _ _ h => congrArg some h)
    (by decide +kernel) (by decide +kernel) ⟨_, rfl, by show sums3 _ = true; decide +kernel⟩

/-- **The twin of the path choice**: thread 0 does not take the path through `%30` (its index is
below the count), for every `Q`: the path is chosen per thread. -/
theorem out_twin (Q : Mem → Prop) :
    ¬ Ret (Valuation.entry (c22 0) 0 g22.mem (fr22 0)) Q (Kernels.vadd.paths[1]'(by decide)) :=
  fun h => absurd h.1 (by decide +kernel)

/-- **The twin of the entry check**: the path that starts at `%21` is accepted from position 0
by the path checker with `phi`s, but `coversEntry` refuses it, since `%21` is not the kernel's
first block. -/
theorem entry_twin : coversPathI Kernels.vadd.prog Kernels.vadd.fn_0 0 vaddIn = true ∧
    coversEntry Kernels.vadd.prog Kernels.vadd.fn_0 [vaddIn] = false := by decide +kernel

/-- A write of 4 bytes at offset 0 of block 3 by thread `n`. -/
def w (n : Nat) : Event := .access ⟨⟨n, 0⟩, ⟨3, 0⟩, 4, true, none, false⟩

/-- **The twin of `Apart`**: with cells `4 * (i % 2)` (threads 0 and 2 share cell 0, not
`Apart`), the memory whose trace is the writes of threads 0 and 2 meets `Elem` from the empty
memory with no thread done (every access owned), but its trace has a data race. -/
theorem elem_twin : ¬ Apart (fun i => 4 * (i % 2)) 4 ∧
    Elem {} 3 4 (fun i => 4 * (i % 2)) (fun _ => none) 0 { trace := [w 0, w 2] } ∧
    racy [w 0, w 2] = true := by
  refine ⟨fun h => absurd (h 0 2 (by decide)) (by decide), ⟨rfl, fun _ _ => rfl, ?_⟩, by decide⟩
  intro a ha
  simp only [List.mem_cons, List.not_mem_nil, or_false, w, Event.access.injEq] at ha
  rcases ha with rfl | rfl <;> (unfold Elem.Own; decide)

/-- Thread `i`'s cell of the output: offset `4 * i`. -/
def cell (i : Nat) : Nat := 4 * i

/-- **`Elem` at the start** (`Elem.zero`, `Grid.start_trace`, `Elem.safe`): the start's memory
meets `Elem` from itself with no thread done, for every bytes, so its trace has no data race and
keeps the promise of `!invariant.load`. -/
theorem elem22 (bs : Nat → Option (List MemByte)) : Elem g22.mem 3 4 cell bs 0 g22.mem ∧
    racy g22.mem.trace = false ∧ kept g22.mem.trace = true :=
  have h := Elem.zero (out := 3) (w := 4) (cell := cell) (bs := bs) (Grid.start_trace start22)
  ⟨h, Elem.safe (fun i j hij => by simp only [cell]; omega) h⟩

/-- The bytes of thread 0 (the bytes of 1.0), none for the others. -/
def bs1 (i : Nat) : Option (List MemByte) := if i = 0 then some (leBytes 4 0x3f800000) else none

/-- `mem0` after thread 0's store of `bs1 0` to its cell, with the write in the trace. -/
def mem1 : Mem :=
  { mem0 with blocks := fun b => if b = 3 then (mem0.blocks 3).map (·.put 0 (leBytes 4 0x3f800000))
      else mem0.blocks b, trace := [w 0] }

/-- **A thread's step of `Elem`** (`Elem.succ`, `Elem.safe`): after thread 0's store to its cell,
`mem1` meets `Elem` from `mem0` after one thread, so its trace has no data race. -/
theorem elem1 : Elem mem0 3 4 cell bs1 1 mem1 ∧ racy mem1.trace = false :=
  have h := Elem.succ (Elem.zero (m₀ := mem0) (out := 3) (w := 4) (cell := cell) (bs := bs1) rfl)
    (m' := mem1) (by simp [mem1, bs1, cell]) (fun b hb => by simp [mem1, hb])
    (fun a ha => .inr (by
      simp only [mem1, List.mem_cons, List.not_mem_nil, or_false, w, Event.access.injEq] at ha
      subst ha
      unfold Elem.Own
      decide))
  ⟨h, (Elem.safe (fun i j hij => by simp only [cell]; omega) h).1⟩

/-- **`Kernels.vadd.ret`'s premises on the context, from the start** (`Grid.start_ctx`,
`Grid.start_env`): for every launch `L`, arguments, memory, address choice and oracle `ω`, the
context of every thread `k` of `vector_addition`'s start is of `Kernels.vadd.prog`, with the
special registers `L.env k`, identity `⟨k, k / volume L.block⟩` and oracle row `ω k`. -/
theorem start_ctx_vadd {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {ω : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L args m ch ω = .ok (g, c)) (k : Nat) :
    (c k).prog = Kernels.vadd.prog ∧ (c k).env = L.env k ∧
      (c k).who = ⟨k, k / volume L.block⟩ ∧ (c k).oracle = ω k :=
  ⟨(Grid.start_ctx h k).1, (Grid.start_env h k).1, (Grid.start_ctx h k).2, (Grid.start_env h k).2⟩

/-- The launch of grid `(2, 1, 1)` and block `(3, 1, 1)`: 2 blocks of 3 threads. -/
def L23 : Launch := ⟨fun | .x => 2 | _ => 1, fun | .x => 3 | _ => 1, 0⟩

/-- `L23` is valid. -/
theorem valid23 : L23.Valid where
  grid_pos d := by cases d <;> decide
  grid_le d := by cases d <;> decide
  block_pos d := by cases d <;> decide
  block_le d := by cases d <;> decide
  threads := by decide

/-- `2 ^ i` in cell `i` of 5 (the binary32 words `0x3f800000 + 2 ^ 23 i`: 1, 2, 4, 8, 16). -/
def x5 : TorchLean.Tensor (Model FloatTy.float.fmt) [5] :=
  TorchLean.Tensor.Rep.ofFn fun i => Model.ofNatBits (0x3f800000 + 0x800000 * i.1.val)

/-- `2 ^ (5 - i)` in cell `i` of 5 (the words `0x42000000 - 2 ^ 23 i`: 32, 16, 8, 4, 2). -/
def y5 : TorchLean.Tensor (Model FloatTy.float.fmt) [5] :=
  TorchLean.Tensor.Rep.ofFn fun i => Model.ofNatBits (0x42000000 - 0x800000 * i.1.val)

/-- The caller's memory `Map2.mem` builds for `x5`, `y5` and an output of 5 floats at
alignment 16: block `i + 1` at address `16 (i + 1)` in space 1 and `16 (2 i + 1)` in the generic
space. -/
def mem5 : Mem :=
  Map2.mem Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16 x5 y5 5
    (fun i => i.val + 1) (fun i => 2 * i.val + 1)

/-- `mem5` meets `Map2.Pre` with `vector_addition`'s tail at blocks 1, 2, 3 and count 5
(`Map2.pre_mem`; its address premises by evaluation). -/
theorem pre5 : Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16
    Kernels.vadd.argTail mem5 1 2 3 5 x5 y5 :=
  Map2.pre_mem (Layout.Codec.float _ .float) (fun _ => trivial) 16 x5 y5 (by decide) (by decide)
    (Nat.le_refl 5) _ _ (by decide +kernel) (by decide +kernel) rfl

/-- **`vector_addition`'s kernel theorem at a launch with an idle thread** (`Kernels.vadd.correct`
with every premise discharged): on 2 blocks of 3 threads with count 5, inputs `x5`, `y5` at
blocks 1 and 2 and the output at block 3 of `mem5`, for every oracle `ω`, the kernel is sound at
every address choice and `ω` for the observation of the blocks and `Elem.Out`: block 3 holds the
bytes `Kernels.vadd.bytes ω x5 y5 5 i` at cell `4 i` of each of the 6 threads (`deliver` of the
sum for `i < 5`, nothing for thread 5), and blocks 1 and 2 are unchanged. -/
theorem correct23 (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω x5 y5 5) 6) :=
  Kernels.vadd.correct valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5

/-- **A thread along a path with a join** (`Runs.of_ret` with the path checker with
`phi`s): the naive matmul kernel's thread at `%46`'s position 2 whose loop runs no trip
(`SymPhi.frameH 0` under `SymPhi.ctxN` on `mem0`) takes `%46 → %51 → %67 → %69`, whose edge
`%51 → %67` sets `%67`'s `phi` (`SymPhi.trip0_covers`); the kernel decides that the path is a
`Ret` (`Ret.check`, `Ret.of_check`), so the thread runs to its end (`Runs`), leaving output
cell 0 holding the accumulator's value 1. -/
theorem phi_runs : ∃ m', Runs SymPhi.ctxN ⟨[SymPhi.frameH 0], 0⟩ mem0 m' ∧
    m'.load SymPhi.naive.prog.layout SymPhi.ctxN.who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
      .ok (.ofFloat .float (Model.ofNatBits 0x3f800000)) := by
  obtain ⟨_, hR, rfl⟩ := Runs.of_ret (c := SymPhi.ctxN) (t := ⟨[SymPhi.frameH 0], 0⟩) (m := mem0)
    rfl SymPhi.trip0_covers rfl rfl rfl rfl rfl (Ret.of_check (d := mem0) (by decide +kernel))
  have hc : (match (Ret.out (Valuation.entry SymPhi.ctxN 0 mem0 (SymPhi.frameH 0)) mem0
      ((SymPhi.naive.fn_0.b_3.label, SymPhi.hdr.obls, SymPhi.hdr) :: SymPhi.trip0)).load
        SymPhi.naive.prog.layout SymPhi.ctxN.who 0 (.fp .float) ⟨3, 0⟩ (some 4) with
      | .ok v => decide (v.float? .float = some (Model.ofNatBits 0x3f800000))
      | .error _ => false) = true := by
    decide +kernel
  refine ⟨_, hR, ?_⟩
  split at hc
  next v hv => rw [hv, Val.float?_eq_some.1 (of_decide_eq_true hc)]
  next => exact absurd hc (by decide)

/-- The launch of grid `(1, 1, 1)` and block `(2, 1, 1)`: one block of 2 threads. -/
def L12 : Launch := ⟨fun _ => 1, fun | .x => 2 | _ => 1, 0⟩

/-- `L12` is valid. -/
theorem valid12 : L12.Valid where
  grid_pos d := by cases d <;> decide
  grid_le d := by cases d <;> decide
  block_pos d := by cases d <;> decide
  block_le d := by cases d <;> decide
  threads := by decide

/-- **`vector_addition`'s kernel theorem with fewer threads than the count**
(`Kernels.vadd.correct` with every premise discharged): on one block of 2 threads with count 5
and `correct23`'s memory `mem5`, for every oracle `ω`, the kernel is sound at every address choice
and `ω` for the observation of the blocks and `Elem.Out` at 2 threads: block 3 is `mem5`'s with
the bytes `Kernels.vadd.bytes ω x5 y5 5 i` put at cell `4 i` for `i < 2` only, so its cells 2 to
4 keep `mem5`'s contents, and blocks 1 and 2 are unchanged. -/
theorem correct12 (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L12
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω x5 y5 5) 2) :=
  Kernels.vadd.correct valid12 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5


/-! ### The satisfiability witness, the negative twins and the canaries, by evaluation -/

/-- The evaluator on kernel `fn` of `prog` at launch `L`, arguments `args` and memory `m`, at
address choice `ch₀` and oracle `ω₀`: `Grid.run`'s result (fuel 64 per thread, one phase) from
the start's grid and contexts, or `none` if the start fails. -/
def evalRun (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem) :
    Option (Except Fault Grid) :=
  match Grid.start prog fn L args m ch₀ ω₀ with
  | .ok (g, c) => some (g.run L c 64 1)
  | .error _ => none

/-- A check `p` of `evalRun`'s final grid that evaluates to `true` gives the start's grid and
contexts and the run's final grid, which `p` accepts. -/
theorem evalRun_ok (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    {p : Grid → Bool}
    (h : (match evalRun prog fn L args m with | some (.ok g') => p g' | _ => false) = true) :
    ∃ g c g', Grid.start prog fn L args m ch₀ ω₀ = .ok (g, c) ∧ g.run L c 64 1 = .ok g' ∧
      p g' = true := by
  split at h
  next g' he =>
    unfold evalRun at he
    split at he
    next g c hs => exact ⟨g, c, g', hs, Option.some.inj he, h⟩
    next => cases he
  next => cases h

/-- A check that `evalRun`'s run fails with undefined behavior `msg`, evaluated to `true`, gives
the start's grid and contexts and the run's fault. -/
theorem evalRun_ub {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {msg : String}
    (h : (match evalRun prog fn L args m with
      | some (.error (.ub e)) => e == msg | _ => false) = true) :
    ∃ g c, Grid.start prog fn L args m ch₀ ω₀ = .ok (g, c) ∧
      g.run L c 64 1 = .error (.ub msg) := by
  split at h
  next e he =>
    obtain rfl := eq_of_beq h
    unfold evalRun at he
    split at he
    next g c hs => exact ⟨g, c, hs, Option.some.inj he⟩
    next => cases he
  next => cases h

/-- The floats `x5 + y5` cell by cell, as binary32 words: 1 + 32 = 33, 2 + 16 = 18, 4 + 8 = 12,
8 + 4 = 12 and 16 + 2 = 18. -/
def sums5 : List (Option (Model FloatTy.float.fmt)) :=
  [0x42040000, 0x41900000, 0x41400000, 0x41400000, 0x41900000].map (some ∘ Model.ofNatBits)

/-- **The satisfiability witness of `vector_addition`'s theorem**: `Grid.start` then `Grid.run`
(fuel 64, one phase) on 2 blocks of 3 threads (`L23`) with count 5 and `correct23`'s memory `mem5`,
at address choice `ch₀` and oracle `ω₀`, end in a grid where every thread has returned. The kernel
evaluates (`decide +kernel`) that the final blocks below 4 agree at the offsets below 24 with
`Elem.Out`'s description (`Elem.outBelow`: block 3 with `Kernels.vadd.bytes ω₀ x5 y5 5` put at the
cells `4 i` of the 6 threads, blocks 1 and 2 unchanged) and that the output's cells 0 to 4 hold the
floats `sums5` (`Elem.word`); and `correct23` gives `Elem.Out` itself for this final grid
(`Grid.Sound.run`). -/
theorem g2_vadd : ∃ g c g', Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    g.run L23 c 64 1 = .ok g' ∧ g'.Done ∧
    Elem.outBelow mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 6 4 24
      g'.mem.blocks = true ∧
    (List.range 5).map (Elem.word Kernels.vadd.prog.layout .float 3 (fun i => 4 * i)
      g'.mem.blocks) = sums5 ∧
    Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 6 g'.mem.blocks := by
  obtain ⟨g, c, g', hs, hr, hp⟩ := evalRun_ok Kernels.vadd.prog Kernels.vadd.fn_0 L23
    (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (p := fun g' =>
    g'.threads.all (· matches .done) &&
    Elem.outBelow mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 6 4 24 g'.mem.blocks &&
    decide ((List.range 5).map (Elem.word Kernels.vadd.prog.layout .float 3 (fun i => 4 * i)
      g'.mem.blocks) = sums5)) (by decide +kernel)
  obtain ⟨g₁, c₁, hs₁, hS⟩ := correct23 ω₀ ch₀ ω₀ rfl
  rw [hs] at hs₁
  cases hs₁
  obtain ⟨_, ⟨⟩, hO⟩ := hS.run hr
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hp
  exact ⟨g, c, g', hs, hr, hp.1.1, hp.1.2, hp.2, hO⟩

/-- `mem5` with an output of 4 floats instead of 5: `Map2.mem` for `x5`, `y5` and an
output block of 16 bytes. -/
def mem4 : Mem :=
  Map2.mem Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16 x5 y5 4
    (fun i => i.val + 1) (fun i => 2 * i.val + 1)

/-- `mem4` meets `Map2.Pre` at count 4 (`Map2.pre_mem`). -/
theorem pre4 : Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16
    Kernels.vadd.argTail mem4 1 2 3 4 x5 y5 :=
  Map2.pre_mem (Layout.Codec.float _ .float) (fun _ => trivial) 16 x5 y5 (by decide) (by decide)
    (Nat.le_refl 4) _ _ (by decide +kernel) (by decide +kernel) rfl

/-- **Negative twin (a), the precondition without the output's length**: at count 5, `mem4` meets
every field of `Map2.Pre` (`vector_addition`'s tail, blocks 1, 2 and 3, alignment 16) but the
output's length: it is closed under the arguments, the three blocks differ, the inputs are
read-only buffers of 5 floats holding `x5` and `y5`, `5 ≤ 5`, `5 < 2 ^ 31`, and the three blocks'
generic addresses fit 5 floats; the output is a writable buffer of 4 floats (`pre4`) and not of
5. -/
theorem pre4_5 :
    mem4.Closed (Map2.args Kernels.vadd.argTail 1 2 3 5) ∧ (1 ≠ 2 ∧ 1 ≠ 3 ∧ 2 ≠ 3) ∧
    mem4.Buffer 1 (5 * Kernels.vadd.prog.layout.size (.fp .float)) 16 false ∧
    mem4.Buffer 2 (5 * Kernels.vadd.prog.layout.size (.fp .float)) 16 false ∧
    mem4.Holds Kernels.vadd.prog.layout 1 (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) x5 ∧
    mem4.Holds Kernels.vadd.prog.layout 2 (.fp .float) (Val.ofFloat .float)
      (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) y5 ∧ 5 ≤ 5 ∧ 5 < 2 ^ 31 ∧
    mem4.Fits Kernels.vadd.prog.layout 1 (5 * Kernels.vadd.prog.layout.size (.fp .float)) ∧
    mem4.Fits Kernels.vadd.prog.layout 2 (5 * Kernels.vadd.prog.layout.size (.fp .float)) ∧
    mem4.Fits Kernels.vadd.prog.layout 3 (5 * Kernels.vadd.prog.layout.size (.fp .float)) ∧
    mem4.Buffer 3 (4 * Kernels.vadd.prog.layout.size (.fp .float)) 16 true ∧
    ¬ mem4.Buffer 3 (5 * Kernels.vadd.prog.layout.size (.fp .float)) 16 true := by
  refine ⟨{ pre4.closed with vals := by decide +kernel }, pre4.ne,
    ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩,
    ⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩,
    pre4.x, pre4.y, Nat.le_refl 5, by decide, ⟨_, rfl, by decide +kernel⟩,
    ⟨_, rfl, by decide +kernel⟩, ⟨_, rfl, by decide +kernel⟩, pre4.bufs.2.2,
    fun ⟨blk, hb, _, _, _, _, hs, _⟩ => ?_⟩
  obtain rfl := Option.some.inj hb
  exact absurd hs (by decide +kernel)

/-- The run of twin (a): on 2 blocks of 3 threads (`L23`) with count 5 and `mem4`, at `ch₀` and
`ω₀`, the start succeeds and `Grid.run` (fuel 64, one phase) faults with `access out of bounds`
(a store past the output's 16 bytes, by thread 4). -/
theorem run_len : ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
    (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 ch₀ ω₀ = .ok (g, c) ∧
    g.run L23 c 64 1 = .error (.ub "access out of bounds") :=
  evalRun_ub (by decide +kernel)

/-- **Negative twin (a), refuted**: at count 5, `mem4` fails `Map2.Pre` by the output's length
alone (`pre4_5`: every other field holds), and `vector_addition` on `L23` (valid,
one-dimensional) with count 5 and `mem4` is not sound for any observation and relation, for
every admission that admits `ch₀` and `ω₀`: the trace-replay checker (fuel 64, one phase)
reports the fault of `run_len` (`Kernel.replay_unsafe`). -/
theorem twin_len : ¬ Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) 16
      Kernels.vadd.argTail mem4 1 2 3 5 x5 y5 ∧
    ∀ {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}, adm ch₀ ω₀ →
      ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
        ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
          (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem4 adm obs R := by
  refine ⟨fun h => ?_, fun hadm _ _ _ =>
    Kernel.replay_unsafe (fuel := 64) (phases := 1) (by decide +kernel) hadm⟩
  obtain ⟨-, -, -, -, -, -, -, -, -, -, -, -, h5⟩ := pre4_5
  exact h5 h.bufs.2.2

/-- `Map2.Pre` refuses an output at the first input's block, for every layout, element type,
alignment, tail, memory, block numbers, count and tensors (its field `ne`). -/
theorem pre_alias {α : Type} {l : Layout} {t : Ty} {enc : α → Val} {al : Nat} {z : Val} {m : Mem}
    {a b n N : Nat} {x y : TorchLean.Tensor α [N]} : ¬ Map2.Pre l t enc al z m a b a n x y :=
  fun h => h.ne.2.1 rfl

/-- `mem5` with its block 1 (the first input, `x5`) writable. -/
def mem5w : Mem := { mem5 with blocks := fun b =>
  if b = 1 then (mem5.blocks 1).map ({ · with readOnly := false }) else mem5.blocks b }

/-- **Negative twin (b), the output at the first input's block**: `Map2.Pre` refuses it
(`pre_alias`), and the run shows `kept` failing without a race or a fault: on `L23` with arguments
blocks 1, 2, 1 and count 5 and `mem5w`, at `ch₀` and `ω₀`, `Grid.run` (fuel 64, one phase) ends with
every thread returned, a trace without a data race (`racy`) and a broken promise of
`!invariant.load` (`kept` is false), which the checker's `broken?` names: thread 4 of block of
threads 1 loads 4 bytes at offset 16 of block 1 with `!invariant.load`, and thread 4 of block of
threads 1 writes 4 bytes at offset 16 of block 1. On `mem5`, whose block 1 is read-only, the store
faults instead. -/
theorem run_alias : ∃ g c g', Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 1 (BitVec.ofNat 32 5)) mem5w ch₀ ω₀ = .ok (g, c) ∧
    g.run L23 c 64 1 = .ok g' ∧ g'.Done ∧ racy g'.mem.trace = false ∧
    kept g'.mem.trace = false ∧ broken? g'.mem.trace = some
      (⟨⟨4, 1⟩, ⟨1, 16⟩, 4, false, none, true⟩, ⟨⟨4, 1⟩, ⟨1, 16⟩, 4, true, none, false⟩) := by
  obtain ⟨g, c, g', hs, hr, hp⟩ := evalRun_ok Kernels.vadd.prog Kernels.vadd.fn_0 L23
    (Kernels.vadd.args 1 2 1 (BitVec.ofNat 32 5)) mem5w (p := fun g' =>
    g'.threads.all (· matches .done) &&
    !racy g'.mem.trace && decide (broken? g'.mem.trace = some
      (⟨⟨4, 1⟩, ⟨1, 16⟩, 4, false, none, true⟩, ⟨⟨4, 1⟩, ⟨1, 16⟩, 4, true, none, false⟩)))
    (by decide +kernel)
  simp only [Bool.and_eq_true, Bool.not_eq_true', decide_eq_true_eq] at hp
  exact ⟨g, c, g', hs, hr, hp.1.1, hp.1.2, kept_of_broken hp.2, hp.2⟩

/-- **Negative twin (b), refuted**: `vector_addition` on `L23` with arguments blocks 1, 2, 1 and
count 5 and `mem5w` is not sound for any observation and relation, for every admission that
admits `ch₀` and `ω₀`: the trace-replay checker (fuel 64, one phase) reports `run_alias`'s broken
promise (`Kernel.replay_unsafe`). -/
theorem twin_alias {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀)
    {β : Type} (obs : Mem → Option β) (R : β → Prop) :
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 1 (BitVec.ofNat 32 5)) mem5w adm obs R :=
  Kernel.replay_unsafe (fuel := 64) (phases := 1) (by decide +kernel) hadm

/-- `vector_addition`'s function indexed by `tid.x` alone: `Kernels.vadd.fn_0` with the entry
block's statement 14, `%19 = add i64 %18, %13` (`%18` is `ctaid.x * ntid.x`, `%13` the extended
`tid.x`), adding the constant 0 instead of `%18`. -/
def fnTid : Func := { Kernels.vadd.fn_0 with blocks := Kernels.vadd.fn_0.blocks.map fun b =>
  if b.label == Kernels.vadd.fn_0.b_0.label then
    { b with stmts := b.stmts.modify 14 fun st => match st.inst with
      | .bin op fl t _ i => { st with inst := .bin op fl t (.int 0) i }
      | _ => st }
  else b }

/-- `Kernels.vadd.prog` with its function `fnTid` (`Kernels.vadd.fn_0` replaced). -/
def progTid : Program := { Kernels.vadd.prog with module := { Kernels.vadd.prog.module with
  funcs := Kernels.vadd.prog.module.funcs.map fun f => if f.name == fnTid.name then fnTid else f } }

/-- **Negative twin (c), the index `tid.x` alone on two blocks**: `progTid`'s `fnTid` on `L23` with
count 5 and `mem5`, at `ch₀` and `ω₀`: `Grid.run` (fuel 64, one phase) ends with every thread
returned and a data race in the trace (`racy`), which the checker's `race?` names: thread 5 of block
of threads 1 writes 4 bytes at offset 8 of block 3, and earlier thread 2 of block of threads 0
writes 4 bytes at offset 8 of block 3. -/
theorem run_tid : ∃ g c g', Grid.start progTid fnTid L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    g.run L23 c 64 1 = .ok g' ∧ g'.Done ∧ racy g'.mem.trace = true ∧
    race? g'.mem.trace = some
      (⟨⟨5, 1⟩, ⟨3, 8⟩, 4, true, none, false⟩, ⟨⟨2, 0⟩, ⟨3, 8⟩, 4, true, none, false⟩) := by
  obtain ⟨g, c, g', hs, hr, hp⟩ := evalRun_ok progTid fnTid L23
    (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (p := fun g' =>
    g'.threads.all (· matches .done) &&
    decide (race? g'.mem.trace = some
      (⟨⟨5, 1⟩, ⟨3, 8⟩, 4, true, none, false⟩, ⟨⟨2, 0⟩, ⟨3, 8⟩, 4, true, none, false⟩)))
    (by decide +kernel)
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hp
  exact ⟨g, c, g', hs, hr, hp.1, racy_of_race hp.2, hp.2⟩

/-- **Negative twin (c), refuted**: `fnTid` on `L23` (valid, one-dimensional) with count 5 and
`mem5`, which meets `Map2.Pre` (`pre5`), is not sound for any observation and relation, for
every admission that admits `ch₀` and `ω₀`: the trace-replay checker (fuel 64, one phase)
reports `run_tid`'s race (`Kernel.replay_unsafe`). -/
theorem twin_tid {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀)
    {β : Type} (obs : Mem → Option β) (R : β → Prop) :
    ¬ Kernel.Sound progTid fnTid L23 (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm
      obs R :=
  Kernel.replay_unsafe (fuel := 64) (phases := 1) (by decide +kernel) hadm

/-- The launch of grid `(1, 1, 1)` and block `(3, 2, 1)`: one two-dimensional block of 6
threads. -/
def L32 : Launch := ⟨fun _ => 1, fun | .x => 3 | .y => 2 | _ => 1, 0⟩

/-- **Negative twin (d), a two-dimensional launch**: `L32` is valid and its grid is
one-dimensional, but `Kernels.vadd.correct`'s hypothesis on the block (`block y = 1`) rejects it;
and the kernel is not sound there with count 5 and `mem5`, for any observation and relation and
every admission that admits `ch₀` and `ω₀`: the index ignores `tid.y`, so threads `(x, 0)` and
`(x, 1)` write one cell, and the trace-replay checker (fuel 64, one phase) reports a race
(`Kernel.replay_unsafe`). -/
theorem twin_2d : L32.Valid ∧ (L32.grid .y = 1 ∧ L32.grid .z = 1) ∧
    ¬ (L32.block .y = 1 ∧ L32.block .z = 1) ∧
    ∀ {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}, adm ch₀ ω₀ →
      ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
        ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L32
          (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm obs R :=
  ⟨⟨fun d => by cases d <;> decide, fun d => by cases d <;> decide,
    fun d => by cases d <;> decide, fun d => by cases d <;> decide, by decide⟩,
    ⟨rfl, rfl⟩, by decide,
    fun hadm _ _ _ => Kernel.replay_unsafe (fuel := 64) (phases := 1) (by decide +kernel) hadm⟩

/-- **The canaries of `vector_addition`'s theorem** (probes of the observation), certified
by the trace-replay checker: on `L23` with count 5 and `mem5`, for every admission that admits
`ch₀` and `ω₀`, the kernel is not sound for `Elem.Out` with any of the five wrong outputs
`Elem.canaries` makes from `correct23`'s bytes at `ω₀` (the fifth copies the input `x5`): the
replay (fuel 64, one phase) reports each violation (`Kernel.replay_canaries`, evaluated by the
kernel).
`correct23` is the control: the kernel is sound for the right bytes. -/
theorem canaries_vadd {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ∀ bs ∈ Elem.canaries Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) x5
      (Kernels.vadd.bytes ω₀ x5 y5 5) 5,
    ¬ Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) bs 6) :=
  Kernel.replay_canaries (fuel := 64) (phases := 1) (by decide +kernel) (by decide +kernel) hadm

/-- The caller's memory for `vector_multiply` on `x5` and `x5` (squares 1, 4, 16, 64, 256; with
`y5` every product is 32, so permuted cells would go unseen), as `mem5` under
`Kernels.vmul.prog`'s layout. -/
def memV : Mem :=
  Map2.mem Kernels.vmul.prog.layout (.fp .float) (Val.ofFloat .float) 16 x5 x5 5
    (fun i => i.val + 1) (fun i => 2 * i.val + 1)

/-- `memV` meets `Map2.Pre` at blocks 1, 2, 3 and count 5 (`Map2.pre_mem`). -/
theorem preV : Map2.Pre Kernels.vmul.prog.layout (.fp .float) (Val.ofFloat .float) 16
    Kernels.vadd.argTail memV 1 2 3 5 x5 x5 :=
  Map2.pre_mem (Layout.Codec.float _ .float) (fun _ => trivial) 16 x5 x5 (by decide) (by decide)
    (Nat.le_refl 5) _ _ (by decide +kernel) (by decide +kernel) rfl

/-- **`vector_multiply`'s kernel theorem at a launch with an idle thread**
(`Kernels.vmul.correct` with every premise discharged): on `L23` with count 5, inputs `x5` and
`x5` at blocks 1 and 2 and the output at block 3 of `memV`, for every oracle `ω`, the kernel is
sound at every address choice and `ω` for `Elem.Out` with `Kernels.vmul.bytes ω x5 x5 5`. -/
theorem correctV23 (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vmul.prog Kernels.vmul.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out memV 3 (fun i => 4 * i) (Kernels.vmul.bytes ω x5 x5 5) 6) :=
  Kernels.vmul.correct valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) preV

/-- **The canaries of `vector_multiply`'s theorem**, certified by the trace-replay checker:
on `L23` with count 5 and `memV`, for every admission that admits `ch₀` and `ω₀`, the kernel is
not sound for `Elem.Out` with any of `Elem.canaries`'s five wrong outputs of `correctV23`'s bytes
at `ω₀` (the fifth copies the input `x5`), by the same definition and theorem as `canaries_vadd`
(`Kernel.replay_canaries`, evaluated by the kernel); `correctV23` is the control. -/
theorem canaries_vmul {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ∀ bs ∈ Elem.canaries Kernels.vmul.prog.layout (.fp .float) (Val.ofFloat .float) x5
      (Kernels.vmul.bytes ω₀ x5 x5 5) 5,
    ¬ Kernel.Sound Kernels.vmul.prog Kernels.vmul.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV adm (fun m => some m.blocks)
      (Elem.Out memV 3 (fun i => 4 * i) bs 6) :=
  Kernel.replay_canaries (fuel := 64) (phases := 1) (by decide +kernel) (by decide +kernel) hadm

/-- **vector_subtraction's kernel theorem at a launch with an idle thread**
(`Kernels.vsub.correct` with every premise discharged): on `L23` with count 5, inputs `x5` and
`y5` at blocks 1 and 2 and the output at block 3 of `mem5`, for every oracle `ω`, the kernel is
sound at every address choice and `ω` for `Elem.Out` with `Kernels.vsub.bytes ω x5 y5 5`. The
memory premise is `pre5`, stated for `vector_addition`'s layout, which is vector_subtraction's. -/
theorem correctS23 (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vsub.prog Kernels.vsub.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vsub.bytes ω x5 y5 5) 6) :=
  Kernels.vsub.correct valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5

/-- **The canaries of vector_subtraction's theorem**, certified by the trace-replay checker:
on `L23` with count 5 and `mem5`, for every admission that admits `ch₀` and `ω₀`, the kernel is
not sound for `Elem.Out` with any of `Elem.canaries`'s five wrong outputs of `correctS23`'s bytes
at `ω₀` (the fifth copies the input `x5`), by the same definition and theorem as `canaries_vadd`
(`Kernel.replay_canaries`, evaluated by the kernel); `correctS23` is the control. -/
theorem canaries_vsub {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} (hadm : adm ch₀ ω₀) :
    ∀ bs ∈ Elem.canaries Kernels.vsub.prog.layout (.fp .float) (Val.ofFloat .float) x5
      (Kernels.vsub.bytes ω₀ x5 y5 5) 5,
    ¬ Kernel.Sound Kernels.vsub.prog Kernels.vsub.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 adm (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) bs 6) :=
  Kernel.replay_canaries (fuel := 64) (phases := 1) (by decide +kernel) (by decide +kernel) hadm

/-! ### The corollaries for `Kernels.vadd`, `Kernels.vmul` and `Kernels.vsub`

Every theorem below is about one kernel, `vector_addition`, vector_multiply or
vector_subtraction, and covers every valid launch `L` of `T` threads whose grid and block have
side 1 in `y` and `z`, alignment `al` that 4 divides, block numbers, count `n`, tensors `x` and
`y` and memory `m` meeting `Map2.Pre`, every oracle and every address choice: the hypotheses of
`Kernels.vadd.correct`, `Kernels.vmul.correct` and `Kernels.vsub.correct`. -/

section Vadd

variable {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
  (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
  {x y : TorchLean.Tensor (Model FloatTy.float.fmt) [N]} {m : Mem}
  (hP : Map2.Pre Kernels.vadd.prog.layout (.fp .float) (Val.ofFloat .float) al
    Kernels.vadd.argTail m a b out n x y)
include hL hg hb hal hP

/-- **`vector_addition`'s output after `min n T` threads** (`Kernel.map2_min`), for every valid
one-dimensional launch of `T` threads, alignment that 4 divides, memory of `Map2.Pre` and oracle
`ω`, at every address choice: `Elem.Out` after `min n T` threads; when `n ≤ T`, block `out` is
the caller's with the bytes `Kernels.vadd.bytes ω x y n i` put at cell `4 i` for every `i < n`. -/
theorem vadd_min (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω)
      (fun m => some m.blocks) (Elem.Out m out (fun i => 4 * i) (Kernels.vadd.bytes ω x y n)
        (min n (volume L.grid * volume L.block))) :=
  Kernel.map2_min (l := Kernels.vadd.prog.layout) (ft := .float) (op := Model.add)
    (o := fun k => ω k (Nat.pair 23 0) / 3) (Kernels.vadd.correct hL hg hb hal hP)

/-- **`vector_addition`'s finite output floats are the sums, cell by cell**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: in
every observation of a complete run at every address choice and oracle, output cell `4 k` of
every thread `k` below `n`, `N` and `T` holds a float, and where it is finite it is TorchLean's
`(x + y)` at `k` and its real value is the sum of the inputs' cells' real values rounded to
binary32 (`Kernel.map2_real`, `Model.toReal_add_eq_roundAt`). -/
theorem vadd_real {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v, Elem.word Kernels.vadd.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      (v.isFinite = true → v = (x + y) (⟨k, hkN⟩, PUnit.unit) ∧
        v.toReal = Model.roundAt FloatTy.float.fmt
          ((x (⟨k, hkN⟩, PUnit.unit)).toReal + (y (⟨k, hkN⟩, PUnit.unit)).toReal)) :=
  let ⟨v, hv, hf⟩ := Kernel.map2_real (l := Kernels.vadd.prog.layout) (ft := .float)
    (op := Model.add) (o := fun k => ω k (Nat.pair 23 0) / 3)
    (Kernels.vadd.correct hL hg hb hal hP) ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) rfl hB
    hk hkN hkT
  ⟨v, hv, fun h => by
    obtain rfl := hf h
    exact ⟨(TorchLean.Tensor.add_apply x y _).symm, Model.toReal_add_eq_roundAt _ _ rfl h⟩⟩

/-- **`vector_addition`'s output floats of two runs are equal up to `FinEq`**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: the
observations of complete runs at any two address choices and oracles hold, at output cell `4 k`
of every thread `k` below `n`, `N` and `T`, floats equal up to `FinEq` (`Kernel.map2_finEq`). -/
theorem vadd_finEq {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat} {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v v', Elem.word Kernels.vadd.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      Elem.word Kernels.vadd.prog.layout .float out (fun i => 4 * i) B' k = some v' ∧
      FinEq v v' :=
  Kernel.map2_finEq (l := Kernels.vadd.prog.layout) (ft := .float) (op := Model.add)
    (o := fun ω k => ω k (Nat.pair 23 0) / 3) (fun _ => Kernels.vadd.correct hL hg hb hal hP)
    ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) hB hB' hk hkN hkT

/-- **`vector_addition`'s finite output floats are the same in every run**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: a
finite float at output cell `4 k` of a thread `k` below `n`, `N` and `T` in one complete run's
observation is the float there in every complete run's observation, at every address choice and
oracle (`vadd_finEq` with `FinEq.eq_of_isFinite`). -/
theorem vadd_stable {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat}
    {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block)
    {v : Model FloatTy.float.fmt}
    (hv : Elem.word Kernels.vadd.prog.layout .float out (fun i => 4 * i) B k = some v)
    (hf : v.isFinite = true) :
    Elem.word Kernels.vadd.prog.layout .float out (fun i => 4 * i) B' k = some v :=
  by
  obtain ⟨_, _, h1, h2, hE⟩ := vadd_finEq hL hg hb hal hP hB hB' hk hkN hkT
  cases hv.symm.trans h1
  exact h2.trans (congrArg some (hE.eq_of_isFinite hf))

end Vadd

section Vmul

variable {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
  (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
  {x y : TorchLean.Tensor (Model FloatTy.float.fmt) [N]} {m : Mem}
  (hP : Map2.Pre Kernels.vmul.prog.layout (.fp .float) (Val.ofFloat .float) al
    Kernels.vadd.argTail m a b out n x y)
include hL hg hb hal hP

/-- **`vector_multiply`'s output after `min n T` threads** (`Kernel.map2_min`), for every valid
one-dimensional launch of `T` threads, alignment that 4 divides, memory of `Map2.Pre` and oracle
`ω`, at every address choice: `Elem.Out` after `min n T` threads; when `n ≤ T`, block `out` is
the caller's with the bytes `Kernels.vmul.bytes ω x y n i` put at cell `4 i` for every `i < n`. -/
theorem vmul_min (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω)
      (fun m => some m.blocks) (Elem.Out m out (fun i => 4 * i) (Kernels.vmul.bytes ω x y n)
        (min n (volume L.grid * volume L.block))) :=
  Kernel.map2_min (l := Kernels.vmul.prog.layout) (ft := .float) (op := Model.mul)
    (o := fun k => ω k (Nat.pair 23 0) / 3) (Kernels.vmul.correct hL hg hb hal hP)

/-- **`vector_multiply`'s finite output floats are the products, cell by cell**, for every
valid one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`:
in every observation of a complete run at every address choice and oracle, output cell `4 k` of
every thread `k` below `n`, `N` and `T` holds a float, and where it is finite it is TorchLean's
`(x * y)` at `k` (the cellwise product, `Tensor.mul_apply`) and its real value is the product of
the inputs' cells' real values rounded to binary32 (`Kernel.map2_real`,
`Model.toReal_mul_eq_roundAt`). -/
theorem vmul_real {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v, Elem.word Kernels.vmul.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      (v.isFinite = true → v = (x * y) (⟨k, hkN⟩, PUnit.unit) ∧
        v.toReal = Model.roundAt FloatTy.float.fmt
          ((x (⟨k, hkN⟩, PUnit.unit)).toReal * (y (⟨k, hkN⟩, PUnit.unit)).toReal)) :=
  let ⟨v, hv, hf⟩ := Kernel.map2_real (l := Kernels.vmul.prog.layout) (ft := .float)
    (op := Model.mul) (o := fun k => ω k (Nat.pair 23 0) / 3)
    (Kernels.vmul.correct hL hg hb hal hP) ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) rfl hB
    hk hkN hkT
  ⟨v, hv, fun h => by
    obtain rfl := hf h
    exact ⟨(TorchLean.Tensor.mul_apply x y _).symm, Model.toReal_mul_eq_roundAt _ _ rfl h⟩⟩

/-- **`vector_multiply`'s output floats of two runs are equal up to `FinEq`**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: the
observations of complete runs at any two address choices and oracles hold, at output cell `4 k`
of every thread `k` below `n`, `N` and `T`, floats equal up to `FinEq` (`Kernel.map2_finEq`). -/
theorem vmul_finEq {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat} {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v v', Elem.word Kernels.vmul.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      Elem.word Kernels.vmul.prog.layout .float out (fun i => 4 * i) B' k = some v' ∧
      FinEq v v' :=
  Kernel.map2_finEq (l := Kernels.vmul.prog.layout) (ft := .float) (op := Model.mul)
    (o := fun ω k => ω k (Nat.pair 23 0) / 3) (fun _ => Kernels.vmul.correct hL hg hb hal hP)
    ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) hB hB' hk hkN hkT

/-- **`vector_multiply`'s finite output floats are the same in every run**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: a
finite float at output cell `4 k` of a thread `k` below `n`, `N` and `T` in one complete run's
observation is the float there in every complete run's observation, at every address choice and
oracle (`vmul_finEq` with `FinEq.eq_of_isFinite`). -/
theorem vmul_stable {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat}
    {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block)
    {v : Model FloatTy.float.fmt}
    (hv : Elem.word Kernels.vmul.prog.layout .float out (fun i => 4 * i) B k = some v)
    (hf : v.isFinite = true) :
    Elem.word Kernels.vmul.prog.layout .float out (fun i => 4 * i) B' k = some v :=
  by
  obtain ⟨_, _, h1, h2, hE⟩ := vmul_finEq hL hg hb hal hP hB hB' hk hkN hkT
  cases hv.symm.trans h1
  exact h2.trans (congrArg some (hE.eq_of_isFinite hf))

end Vmul

section Vsub

variable {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
  (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
  {x y : TorchLean.Tensor (Model FloatTy.float.fmt) [N]} {m : Mem}
  (hP : Map2.Pre Kernels.vsub.prog.layout (.fp .float) (Val.ofFloat .float) al
    Kernels.vadd.argTail m a b out n x y)
include hL hg hb hal hP

/-- **vector_subtraction's output after `min n T` threads** (`Kernel.map2_min`), for every valid
one-dimensional launch of `T` threads, alignment that 4 divides, memory of `Map2.Pre` and oracle
`ω`, at every address choice: `Elem.Out` after `min n T` threads; when `n ≤ T`, block `out` is
the caller's with the bytes `Kernels.vsub.bytes ω x y n i` put at cell `4 i` for every `i < n`. -/
theorem vsub_min (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun _ ω' => ω' = ω)
      (fun m => some m.blocks) (Elem.Out m out (fun i => 4 * i) (Kernels.vsub.bytes ω x y n)
        (min n (volume L.grid * volume L.block))) :=
  Kernel.map2_min (l := Kernels.vsub.prog.layout) (ft := .float) (op := Model.sub)
    (o := fun k => ω k (Nat.pair 23 0) / 3) (Kernels.vsub.correct hL hg hb hal hP)

/-- **vector_subtraction's finite output floats are the differences, cell by cell**, for every
valid one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`:
in every observation of a complete run at every address choice and oracle, output cell `4 k` of
every thread `k` below `n`, `N` and `T` holds a float, and where it is finite it is TorchLean's
`(x - y)` at `k` (the cellwise difference, `Tensor.Rep.hSub_apply`) and its real value is the
difference of the inputs' cells' real values rounded to binary32 (`Kernel.map2_real`,
`Model.toReal_sub_eq_roundAt`). -/
theorem vsub_real {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v, Elem.word Kernels.vsub.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      (v.isFinite = true → v = (x - y) (⟨k, hkN⟩, PUnit.unit) ∧
        v.toReal = Model.roundAt FloatTy.float.fmt
          ((x (⟨k, hkN⟩, PUnit.unit)).toReal - (y (⟨k, hkN⟩, PUnit.unit)).toReal)) :=
  let ⟨v, hv, hf⟩ := Kernel.map2_real (l := Kernels.vsub.prog.layout) (ft := .float)
    (op := Model.sub) (o := fun k => ω k (Nat.pair 23 0) / 3)
    (Kernels.vsub.correct hL hg hb hal hP) ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) rfl hB
    hk hkN hkT
  ⟨v, hv, fun h => by
    obtain rfl := hf h
    exact ⟨(TorchLean.Tensor.Rep.hSub_apply x y _).symm, Model.toReal_sub_eq_roundAt _ _ rfl h⟩⟩

/-- **vector_subtraction's output floats of two runs are equal up to `FinEq`**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: the
observations of complete runs at any two address choices and oracles hold, at output cell `4 k`
of every thread `k` below `n`, `N` and `T`, floats equal up to `FinEq` (`Kernel.map2_finEq`). -/
theorem vsub_finEq {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat} {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block) :
    ∃ v v', Elem.word Kernels.vsub.prog.layout .float out (fun i => 4 * i) B k = some v ∧
      Elem.word Kernels.vsub.prog.layout .float out (fun i => 4 * i) B' k = some v' ∧
      FinEq v v' :=
  Kernel.map2_finEq (l := Kernels.vsub.prog.layout) (ft := .float) (op := Model.sub)
    (o := fun ω k => ω k (Nat.pair 23 0) / 3) (fun _ => Kernels.vsub.correct hL hg hb hal hP)
    ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) hB hB' hk hkN hkT

/-- **vector_subtraction's finite output floats are the same in every run**, for every valid
one-dimensional launch of `T` threads, alignment that 4 divides and memory of `Map2.Pre`: a
finite float at output cell `4 k` of a thread `k` below `n`, `N` and `T` in one complete run's
observation is the float there in every complete run's observation, at every address choice and
oracle (`vsub_finEq` with `FinEq.eq_of_isFinite`). -/
theorem vsub_stable {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat}
    {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L
      (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m (fun m => some m.blocks) ch' ω' B')
    {k : Nat} (hk : k < n) (hkN : k < N) (hkT : k < volume L.grid * volume L.block)
    {v : Model FloatTy.float.fmt}
    (hv : Elem.word Kernels.vsub.prog.layout .float out (fun i => 4 * i) B k = some v)
    (hf : v.isFinite = true) :
    Elem.word Kernels.vsub.prog.layout .float out (fun i => 4 * i) B' k = some v :=
  by
  obtain ⟨_, _, h1, h2, hE⟩ := vsub_finEq hL hg hb hal hP hB hB' hk hkN hkT
  cases hv.symm.trans h1
  exact h2.trans (congrArg some (hE.eq_of_isFinite hf))

end Vsub

end MojoProofTest.Kernel
