import MojoProof.Sem.Shared
import MojoProof.Sem.Rmw
import MojoProofTest.Transpose
import MojoProofTest.ScheduleOwned
import MojoProofTest.Launch
import MojoProofTest.Index

/-!
# Instances and twins of the shared-memory race theorems and of `rmw_add_perm`

The accesses are `acc4` (MojoProofTest/Transpose.lean), 1-byte accesses of block 0 by threads of
block of threads 0. The trace `tr`: four threads of block of threads 0 and its shared block 0 of
four 1-byte cells, the halving tree of a reduction with strides 4, 2 and 1 (`s`). In phase 0
thread `k` writes cell `k`; then a barrier of block of threads 0; in phase 1 thread `k < 2` reads
cells `k` and `k + 2` and writes cell `k`; a barrier; in phase 2 thread 0 reads cells 0 and 1 and
writes cell 0. It meets the premises of `racy_halving` (`B = 4`, `w = 1`), so it has no race
(`racy_eq_false_tr`).
Without the barriers it is racy (the twin), so no stride sequence meets those premises of it.

The trace `trR`: in phase 0 thread `k < 4` of block of threads 0 writes byte `3 - k` of block 0,
then a barrier, then thread `k` reads byte `k`. It meets the premises of `racy_cells` at the cell
map `3 - ·`, injective on `[0, 4)`, so it has no race (`racy_trR`). The twin of the injectivity
premise: two threads writing one cell in phase 0 race.

The trace `trA` adds to `tr` an `atomicrmw add` of 4 bytes of block 1 by thread 0 of block of
threads 0 and one by thread 4 of block of threads 1, as a reduction's output word. It has no race
(`racy_trA`, by `racy_dropBlocks` with block 1 selected). Its twin, with thread 4's update a plain
store, is racy. Traces, not a kernel.

The words: adding 2³² - 1, 2 and 5 to the word 0 by `atomicrmw add` of width 32 in every order of
the three gives 6, the sum modulo 2³² (`add_any_order`, by `rmw_add_perm`). The twin: the words
2³² - 1, 2 and 2, not an order of those three, give 3 (`add_not_perm`). The twin of the
operation's premise of `rmw_perm` is `add_or` (MojoProofTest/Atomics.lean).

The run, one kernel on one launch: `shK true` on one block of threads of two threads (`two`) on
the empty memory. Thread `k` stores its `%tid.x` to cell `k` of the shared global `@sh`
(`[2 x i32]`, block 2), waits at a barrier, then loads cell `k xor 1`, the other thread's. The
evaluator's run (`Grid.run`, `Grid.run_reach`) ends with every thread returned and the words 0 and
1 in block 2; its trace meets the premises of `Grid.sound_cells` at the cell map `id` and cells of
4 bytes (by `decide +kernel`), so the start's grid is sound for those bytes (`sh_sound`). The twin
(`sh_twin`): `shK false`, without the barrier, with thread 1 run between thread 0's store and its
load, ends with every thread returned, but its trace is racy (thread 1 reads cell 0 in the phase
thread 0 writes it), so the start's grid is sound for no observation.

The run of a halving tree: `redK true` on two blocks of four threads (`L24`,
MojoProofTest/Index.lean) on the memory `outW`, a word 0 of global memory passed as the pointer
argument. Thread `t` of each block stores its `%tid.x` to cell `t` of the shared global `@sh`
(`[4 x i32]`); after a barrier threads 0 and 1 add cells 2 and 3 into cells 0 and 1; after a barrier
thread 0 adds cell 1 into cell 0 and adds the result into the output word by `atomicrmw add`. The
evaluator's run ends with every thread returned and the word 12; its trace meets the premises of
`Grid.sound_halving` at the strides `s` and the output block selected, so the start's grid is sound
for that word, bytes 0 to 3 of block 1 (`obs1`; `red_sound`). The kernel does not reduce `phases`'
hash map at block of threads 1, so the decisions go through `phasesF`, the same phases computed
without it (`phasesF_eq`). The twin (`red_twin`): `redK false`, without the second barrier, is racy
(thread 0 reads cell 1 in the phase thread 1 writes it), so the start's grid is sound for no
observation.
-/

namespace MojoProofTest.Shared

open MojoProof.LLVM MojoProof.Sem Relation
open MojoProofTest.Transpose (acc4)
open MojoProofTest.Confluence (kern kprog two)
open MojoProofTest.ScheduleOwned (tidName tidDecl obs1)
open MojoProofTest.Launch (barrierName barrierDecl)
open MojoProofTest.Index (L24)
open MojoProofTest.Determinism (advs path_advs)

/-- Phase 0, stride 4, newest first: thread `k` writes cell `k`. -/
def p0 : List Event :=
  [.access (acc4 3 3 true), .access (acc4 2 2 true), .access (acc4 1 1 true),
    .access (acc4 0 0 true)]

/-- Phase 1, stride 2, newest first: thread `k < 2` reads cells `k` and `k + 2`, writes cell `k`. -/
def p1 : List Event :=
  [.access (acc4 1 1 true), .access (acc4 1 3 false), .access (acc4 1 1 false),
    .access (acc4 0 0 true), .access (acc4 0 2 false), .access (acc4 0 0 false)]

/-- Phase 2, stride 1, newest first: thread 0 reads cells 0 and 1, writes cell 0. -/
def p2 : List Event := [.access (acc4 0 0 true), .access (acc4 0 1 false), .access (acc4 0 0 false)]

/-- The trace, newest first, with a barrier of block of threads 0 between the phases. -/
def tr : List Event := p2 ++ .barrier 0 :: p1 ++ .barrier 0 :: p0

/-- The stride of phase `p`: 4, 2, 1, then 0. -/
def s (p : Nat) : Nat := 4 / 2 ^ p

/-- The accesses of `tr` with their phases. -/
theorem phases_tr : (phases tr).1 =
    [(acc4 0 0 true, 2), (acc4 0 1 false, 2), (acc4 0 0 false, 2),
      (acc4 1 1 true, 1), (acc4 1 3 false, 1), (acc4 1 1 false, 1),
      (acc4 0 0 true, 1), (acc4 0 2 false, 1), (acc4 0 0 false, 1),
      (acc4 3 3 true, 0), (acc4 2 2 true, 0), (acc4 1 1 true, 0), (acc4 0 0 true, 0)] := by
  decide +kernel

/-- **The halving tree on a trace**, the instance of `racy_halving` at `B = 4`, `w = 1` and the
strides `s`: `tr` has no race. -/
theorem racy_eq_false_tr : racy tr = false := by
  refine racy_halving (B := 4) (w := 1) (s := s) (ofSh := fun _ => some 0) (G := fun _ => none)
    (fun x hx β e => ?_) fun _ _ e => nomatch e
  cases Option.some.inj e
  rw [phases_tr] at hx
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  refine ⟨?_, ?_, x.1.ptr.off.toNat, ?_, ?_, ?_⟩ <;>
    rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    decide

/-- The twin without the barriers is racy. -/
example : racy (p2 ++ p1 ++ p0) = true := by decide

/-- The trace, newest first: thread `k < 4` writes byte `3 - k` of block 0, a barrier of block
of threads 0, then thread `k` reads byte `k`. -/
def trR : List Event :=
  [.access (acc4 3 3 false), .access (acc4 2 2 false), .access (acc4 1 1 false),
    .access (acc4 0 0 false), .barrier 0, .access (acc4 3 0 true), .access (acc4 2 1 true),
    .access (acc4 1 2 true), .access (acc4 0 3 true)]

/-- **Cells at a cell map other than the transposition**, the instance of `racy_cells` at
`B = 4`, `w = 1` and the cell map `3 - ·`, injective on `[0, 4)`: `trR` has no race. -/
theorem racy_trR : racy trR = false := by
  refine racy_cells (B := 4) (w := 1) (by decide) (cell := (3 - ·)) (fun i hi j hj e => by omega)
    (ofSh := fun _ => some 0) (G := fun _ => none) (fun x hx β e => ?_) fun _ _ e => nomatch e
  cases Option.some.inj e
  have hp : (phases trR).1 =
      [(acc4 3 3 false, 1), (acc4 2 2 false, 1), (acc4 1 1 false, 1), (acc4 0 0 false, 1),
        (acc4 3 0 true, 0), (acc4 2 1 true, 0), (acc4 1 2 true, 0), (acc4 0 3 true, 0)] := by
    decide +kernel
  rw [hp] at hx
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> decide

/-- The twin of the injectivity premise: threads 0 and 1 writing one cell in one phase race. -/
example : racy [.access (acc4 1 0 true), .access (acc4 0 0 true)] = true := by decide

/-- An `atomicrmw add` by thread `k` of block of threads `b` to the 4 bytes at 0 of block 1. -/
def add1 (k b : Nat) : Access := ⟨⟨k, b⟩, ⟨1, 0⟩, 4, true, some .add, false⟩

/-- The trace, newest first: thread 4 of block of threads 1 and thread 0 of block of threads 0
each add a word to block 1, after the halving tree of `tr`. -/
def trA : List Event := .access (add1 4 1) :: .access (add1 0 0) :: tr

/-- **The output word's atomics and the halving tree**, the instance of `racy_dropBlocks` with
block 1 selected: its two accesses are atomics of one operation at one pointer with one length,
and the trace without them is `tr`, which has no race. -/
theorem racy_trA : racy trA = false := by
  have h0 : ∀ a, Event.access a ∈ tr → a.ptr.block = 0 := fun a h => by
    have := List.all_eq_true.1 (by decide : tr.all (fun e => match e with
      | .access a => a.ptr.block == 0
      | .barrier _ => true) = true) _ h
    simpa using this
  have h1 : ∀ a, Event.access a ∈ trA → a.ptr.block = 1 → a = add1 4 1 ∨ a = add1 0 0 :=
    fun a h hb => by
      rcases List.mem_cons.1 h with h | h
      · exact .inl (Event.access.inj h)
      rcases List.mem_cons.1 h with h | h
      · exact .inr (Event.access.inj h)
      · exact absurd (h0 a h) (by omega)
  refine racy_dropBlocks (A := (· == 1)) (fun x hx y hy hx1 hb => ?_) ?_
  · have hx' := h1 _ (mem_phases hx) (beq_iff_eq.1 hx1)
    have hy' := h1 _ (mem_phases hy) (by rw [← hb]; exact beq_iff_eq.1 hx1)
    rcases hx' with h | h <;> rcases hy' with h' | h' <;> simp [h, h', add1]
  · have e : dropBlocks (· == 1) trA = tr := by decide +kernel
    rw [e]
    exact racy_eq_false_tr

/-- The twin: with thread 4's update a plain store, the trace is racy. -/
example : racy (.access { add1 4 1 with atomic := none } :: .access (add1 0 0) :: tr) = true := by
  decide

/-- **Every order of three `atomicrmw add`s gives one word.** For every order `ys` of the words
2³² - 1, 2 and 5, adding them to the word 0 by `rmw 32 .add` gives 6. -/
theorem add_any_order {ys : List (BitVec 32)} (hp : ys.Perm [0xFFFFFFFF, 2, 5]) :
    (ys.map (Val.bits 32)).foldlM (rmw 32 .add) (.bits 32 0) = .ok (.bits 32 6) :=
  (rmw_add_perm hp 0).trans rfl

/-- The twin of the permutation premise: the words 2³² - 1, 2 and 2, which are not an order of
2³² - 1, 2 and 5, give 3. -/
theorem add_not_perm :
    ([0xFFFFFFFF, 2, 2].map (Val.bits 32)).foldlM (rmw 32 .add) (.bits 32 0) = .ok (.bits 32 3) :=
  rfl

/-! ## A run with shared memory and a barrier -/

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- `@sh = internal addrspace(3) global [2 x i32] undef, align 4`. -/
def shG : Global := ⟨"sh", ["internal"], 3, false, .arr 2 (.int 32), some .undef, some 4⟩

/-- The kernel `@k()`, with the barrier if `bar`:
`%1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`,
`%2 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %1`,
`store i32 %1, ptr addrspace(3) %2, align 4`,
`call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)`, `%3 = xor i32 %1, 1`,
`%4 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %3`,
`%5 = load i32, ptr addrspace(3) %4, align 4`, `ret void`. -/
def shK (bar : Bool) : Func :=
  let cellAt (r i : Nat) : Stmt :=
    { res := some r,
      inst := .gep { inbounds := true } (.int 32) ⟨.ptr 3, .glob "sh"⟩ [⟨.int 32, .loc i⟩] }
  let barCall : Stmt :=
    { res := none, inst := .call {} .void (.fn barrierName) [(⟨.int 32, .int 0⟩, [])] }
  let before : Array Stmt :=
    #[{ res := some 1, inst := .call {} (.int 32) (.fn tidName) [] }, cellAt 2 1,
      { res := none, inst := .store false ⟨.int 32, .loc 1⟩ ⟨.ptr 3, .loc 2⟩ (some 4) }]
  let after : Array Stmt :=
    #[{ res := some 3, inst := .bin .xor {} (.int 32) (.loc 1) (.int 1) }, cellAt 4 3,
      { res := some 5, inst := .load false (.int 32) ⟨.ptr 3, .loc 4⟩ (some 4) }]
  { kern with
    blocks := #[⟨0, before ++ (if bar then #[barCall] else #[]) ++ after, .ret none⟩] }

/-- The program of `shK bar`, `shG`, the barrier with attribute group 0 `convergent` and
`%tid.x`, with the default data layout. -/
def shP (bar : Bool) : Program :=
  { kprog with
    module :=
      { (default : Module) with
        globals := #[shG]
        funcs := #[shK bar, tidDecl, barrierDecl]
        attrGroups := #[(0, [.flag "convergent"])] }
    intrinsics := [(tidName, .sreg .tid .x), (barrierName, .barrier)] }

/-- The grid and contexts of the launch of `shK bar` on `two` (one block of threads of two
threads) on the empty memory, with address choice and oracle 0 (an empty grid if it fails). -/
def shRun (bar : Bool) : Grid × (Nat → Ctx) :=
  match Grid.start (shP bar) (shK bar) two [] {} (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨shP bar, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The launch of `shK bar` starts without a fault (by evaluation). -/
theorem shStart (bar : Bool) :
    Grid.start (shP bar) (shK bar) two [] {} (fun _ => 0) (fun _ _ => 0) =
      .ok ((shRun bar).1, (shRun bar).2) := by
  cases bar <;> rfl

/-- The grid the evaluator `Grid.run` reaches from the start of `shK true`, with at most 10 steps
per thread and phase and at most 3 phases (the start's grid if it fails). -/
def shDone : Grid :=
  match (shRun true).1.run two (shRun true).2 10 3 with
  | .ok g => g
  | .error _ => (shRun true).1

/-- Bytes 0 to 7 of block 2, the shared block of `@sh`. -/
def shObs (m : Mem) : Option (List MemByte) := (m.blocks 2).map (·.read 0 8)

/-- **A run with shared memory and a barrier**, the instance of `Grid.sound_cells` at the cell
map `id` and cells of 4 bytes, one kernel on one launch: in the run of `shK true` that the
evaluator takes, thread `k` of the two writes its `%tid.x` to cell `k` of `@sh`, the barrier
completes, and thread `k` reads cell `k xor 1`, the other thread's; every thread returns and the
shared block holds the words 0 and 1. So the start's grid is sound for those bytes: no schedule
races and every schedule observes them. -/
theorem sh_sound :
    Grid.Sound two (shRun true).2 (shRun true).1 shObs (· = leBytes 4 0 ++ leBytes 4 1) := by
  have hr : (shRun true).1.run two (shRun true).2 10 3 = .ok shDone := by
    have hb : ((shRun true).1.run two (shRun true).2 10 3).toBool = true := by
      decide +kernel
    unfold shDone
    revert hb
    cases (shRun true).1.run two (shRun true).2 10 3 with
    | ok g => intro _; rfl
    | error e => intro hb; simp [Except.toBool] at hb
  obtain ⟨_, run⟩ := Path.exists_iff.2 (Grid.run_reach hr)
  have hd : shDone.Done := by
    unfold Grid.Done
    decide +kernel
  have hS : ∀ x ∈ (phases shDone.mem.trace).1,
      (x.2 = 0 → ((x.1.who.thread % volume two.block * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((x.1.who.thread % volume two.block * 4 + 4 : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false) := by
    decide +kernel
  have hC : ∀ x ∈ (phases shDone.mem.trace).1, shDone.mem.ctaOf x.1.ptr.block = some 0 := by
    decide +kernel
  have hN : shDone.mem.trace.all (fun e => match e with
      | .access a => !a.invariant
      | .barrier _ => true) = true := by
    decide +kernel
  refine Grid.sound_cells (shStart true) (fun _ _ _ _ _ h => by cases h)
    (fun m m' h => by simp only [shObs, h]) run hd (w := 4) (cell := id) (by decide)
    (fun _ _ _ _ e => e) (G := fun _ => none) (fun x hx _ _ => hS x hx)
    (fun x hx e => by rw [hC x hx] at e; cases e) (fun a _ ha _ hi _ => ?_)
    (y := leBytes 4 0 ++ leBytes 4 1) (by decide +kernel) rfl
  have := List.all_eq_true.1 hN _ ha
  simp [hi] at this

/-- The start of `shK false`, the kernel without its barrier, after thread 0's call, address and
store, then every step of thread 1, then thread 0's other steps. -/
def shTwin : Grid :=
  advs (shRun false).2 (shRun false).1 [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0]

/-- **The twin of the barrier**: without it, the run to `shTwin` is a run to a grid in which
every thread has returned, but thread 1 reads cell 0 in the phase in which thread 0 writes it, so
the trace is racy, the grid is bad and the start's grid is sound for no observation. -/
theorem sh_twin : ReflTransGen (Grid.Step two (shRun false).2) (shRun false).1 shTwin ∧
    shTwin.Done ∧ racy shTwin.mem.trace = true ∧ shTwin.Bad two (shRun false).2 ∧
    ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
      ¬ Grid.Sound two (shRun false).2 (shRun false).1 obs R := by
  have hr : ReflTransGen (Grid.Step two (shRun false).2) (shRun false).1 shTwin :=
    Path.exists_iff.1 ⟨_, path_advs _ [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0]
      (by decide +kernel) (.nil _)⟩
  have hd : shTwin.Done := by
    unfold Grid.Done
    decide +kernel
  have hk : racy shTwin.mem.trace = true := by decide +kernel
  refine ⟨hr, hd, hk, hd.bad_iff.2 (.inl hk), fun _ _ hs => ?_⟩
  have := hs.raceFree _ hr
  rw [hk] at this
  cases this

/-! ## A run of a halving tree with an atomic output word -/

/-- `@sh = internal addrspace(3) global [4 x i32] undef, align 4`. -/
def redG : Global := ⟨"sh", ["internal"], 3, false, .arr 4 (.int 32), some .undef, some 4⟩

/-- The kernel `@k(ptr addrspace(1) %0)`, with its second barrier if `bar`. Block 10:
`%1 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()`, `%2 = getelementptr inbounds i32, ptr
addrspace(3) @sh, i32 %1`, `store i32 %1, ptr addrspace(3) %2, align 4`, the barrier,
`%3 = icmp ult i32 %1, 2`, `br i1 %3, label %20, label %30`. Block 20: `%4 = load i32, %2`,
`%5 = add i32 %1, 2`, `%6 = getelementptr inbounds i32, @sh, i32 %5`, `%7 = load i32, %6`,
`%8 = add i32 %4, %7`, `store i32 %8, %2`, `br label %30`. Block 30: the barrier if `bar`,
`%9 = icmp eq i32 %1, 0`, `br i1 %9, label %40, label %50`. Block 40: `%10 = load i32, %2`,
`%11 = getelementptr inbounds i32, @sh, i32 1`, `%12 = load i32, %11`, `%13 = add i32 %10, %12`,
`store i32 %13, %2`, `%14 = atomicrmw add ptr addrspace(1) %0, i32 %13 seq_cst, align 4`,
`br label %50`. Block 50: `ret void`. -/
def redK (bar : Bool) : Func :=
  let cellAt (r : Nat) (i : Value) : Stmt :=
    { res := some r,
      inst := .gep { inbounds := true } (.int 32) ⟨.ptr 3, .glob "sh"⟩ [⟨.int 32, i⟩] }
  let barCall : Stmt :=
    { res := none, inst := .call {} .void (.fn barrierName) [(⟨.int 32, .int 0⟩, [])] }
  let ld (r p : Nat) : Stmt :=
    { res := some r, inst := .load false (.int 32) ⟨.ptr 3, .loc p⟩ (some 4) }
  let st (v p : Nat) : Stmt :=
    { res := none, inst := .store false ⟨.int 32, .loc v⟩ ⟨.ptr 3, .loc p⟩ (some 4) }
  let add (r : Nat) (a b : Value) : Stmt := { res := some r, inst := .bin .add {} (.int 32) a b }
  let b10 : Array Stmt :=
    #[{ res := some 1, inst := .call {} (.int 32) (.fn tidName) [] }, cellAt 2 (.loc 1), st 1 2,
      barCall, { res := some 3, inst := .icmp .ult (.int 32) (.loc 1) (.int 2) }]
  let b20 : Array Stmt :=
    #[ld 4 2, add 5 (.loc 1) (.int 2), cellAt 6 (.loc 5), ld 7 6, add 8 (.loc 4) (.loc 7), st 8 2]
  let isZero : Stmt := { res := some 9, inst := .icmp .eq (.int 32) (.loc 1) (.int 0) }
  let b30 : Array Stmt := (if bar then #[barCall] else #[]) ++ #[isZero]
  let rmw : Stmt :=
    { res := some 14,
      inst := .atomicrmw false .add ⟨.ptr 1, .loc 0⟩ ⟨.int 32, .loc 13⟩ none .seqCst (some 4) }
  let b40 : Array Stmt :=
    #[ld 10 2, cellAt 11 (.int 1), ld 12 11, add 13 (.loc 10) (.loc 12), st 13 2, rmw]
  { kern with
    params := [⟨.ptr 1, [], some 0⟩]
    blocks := #[⟨10, b10, .condBr (.loc 3) 20 30⟩, ⟨20, b20, .br 30⟩,
                ⟨30, b30, .condBr (.loc 9) 40 50⟩, ⟨40, b40, .br 50⟩, ⟨50, #[], .ret none⟩] }

/-- The program of `redK bar`, `redG`, the barrier with attribute group 0 `convergent` and
`%tid.x`, with the default data layout. -/
def redP (bar : Bool) : Program :=
  { kprog with
    module :=
      { (default : Module) with
        globals := #[redG]
        funcs := #[redK bar, tidDecl, barrierDecl]
        attrGroups := #[(0, [.flag "convergent"])] }
    intrinsics := [(tidName, .sreg .tid .x), (barrierName, .barrier)] }

/-- The caller's memory: block 1, the output word, 4 bytes of global memory holding 0. -/
def outW : Mem := (({} : Mem).alloc {} 1 4 4 true false .all 1 1 (leBytes 4 0)).1

/-- `outW` has no pointer byte. -/
theorem outW_bytesIn : outW.BytesIn outW.Known :=
  Mem.alloc_bytesIn (fun _ _ _ _ _ h => by cases h) (fun p j h => by simp [leBytes] at h)
    _ _ _ _ _ _ _ _ _ _

/-- The grid and contexts of the launch of `redK bar` on `L24` with the pointer to `outW`'s
block 1, with address choice and oracle 0 (an empty grid if it fails). -/
def redRun (bar : Bool) : Grid × (Nat → Ctx) :=
  match Grid.start (redP bar) (redK bar) L24 [.ptr ⟨1, 0⟩] outW (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨redP bar, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The launch of `redK bar` starts without a fault (by evaluation). -/
theorem redStart (bar : Bool) :
    Grid.start (redP bar) (redK bar) L24 [.ptr ⟨1, 0⟩] outW (fun _ => 0) (fun _ _ => 0) =
      .ok ((redRun bar).1, (redRun bar).2) := by
  cases bar <;> rfl

/-- The grid the evaluator `Grid.run` reaches from the start of `redK bar`, with at most 30 steps
per thread and phase and at most 4 phases (the start's grid if it fails). -/
def redEnd (bar : Bool) : Grid :=
  match (redRun bar).1.run L24 (redRun bar).2 30 4 with
  | .ok g => g
  | .error _ => (redRun bar).1

/-- The evaluator reaches `redEnd bar` without a fault (by evaluation). -/
theorem redRun_ok (bar : Bool) :
    (redRun bar).1.run L24 (redRun bar).2 30 4 = .ok (redEnd bar) := by
  have hb : ((redRun bar).1.run L24 (redRun bar).2 30 4).toBool = true := by
    cases bar <;> decide +kernel
  unfold redEnd
  revert hb
  cases (redRun bar).1.run L24 (redRun bar).2 30 4 with
  | ok g => intro _; rfl
  | error e => intro hb; simp [Except.toBool] at hb

/-- `phases` with the barrier counts as a function instead of a hash map: the same accesses with
the same phases (`phasesF_eq`), which `decide +kernel` evaluates (the kernel does not reduce the
hash map's lookups of a block of threads other than 0). -/
def phasesF (tr : List Event) : List (Access × Nat) × (Nat → Nat) :=
  tr.foldr (init := ([], fun _ => 0)) fun e p => match e with
    | .barrier k => (p.1, fun j => if k = j then p.2 j + 1 else p.2 j)
    | .access a => ((a, p.2 a.who.cta) :: p.1, p.2)

/-- **`phasesF` is `phases`**, for every trace: the same accesses with the same phases, and the
same barrier count of every block of threads. -/
theorem phasesF_eq : ∀ tr : List Event,
    (phases tr).1 = (phasesF tr).1 ∧ ∀ j, (phases tr).2.getD j 0 = (phasesF tr).2 j
  | [] => ⟨rfl, fun j => by simp [phases, phasesF]⟩
  | .barrier k :: tr => by
    obtain ⟨h1, h2⟩ := phasesF_eq tr
    refine ⟨by rw [phases_barrier]; exact h1, fun j => ?_⟩
    rw [phases_barrier, Std.HashMap.getD_insert]
    show _ = if k = j then (phasesF tr).2 j + 1 else (phasesF tr).2 j
    by_cases hk : k = j
    · subst hk
      simp [h2]
    · simp [hk, h2]
  | .access a :: tr => by
    obtain ⟨h1, h2⟩ := phasesF_eq tr
    rw [phases_access]
    exact ⟨by rw [h1, h2]; rfl, h2⟩

/-- **A run of a halving tree with an atomic output word**, the instance of `Grid.sound_halving`
at cells of 4 bytes, the strides `s` (4, 2, 1) and `A` selecting block 1, one kernel on one
launch: in the run of `redK true` that the evaluator takes, in each of the two blocks of four
threads thread `t` writes its `%tid.x` to cell `t` of `@sh`; after a barrier threads 0 and 1 add
cells 2 and 3 into cells 0 and 1; after a barrier thread 0 adds cell 1 into cell 0 and adds the
block's sum, 6, into the output word by `atomicrmw add`. Every thread returns and the output word
is 12. The two `atomicrmw`s are by different blocks of threads on one word, so the trace meets
the pattern only with block 1 dropped (`racy_dropBlocks`). So the start's grid is sound for the
output word: no schedule races and every schedule observes 12. -/
theorem red_sound :
    Grid.Sound L24 (redRun true).2 (redRun true).1 obs1 (· = leBytes 4 12) := by
  obtain ⟨_, run⟩ := Path.exists_iff.2 (Grid.run_reach (redRun_ok true))
  have hd : (redEnd true).Done := by
    unfold Grid.Done
    decide +kernel
  have hA : ∀ x ∈ (phasesF (redEnd true).mem.trace).1, ∀ y ∈ (phasesF (redEnd true).mem.trace).1,
      (x.1.ptr.block == 1) = true → x.1.ptr.block = y.1.ptr.block →
        x.1.atomic.isSome = true ∧ x.1.atomic = y.1.atomic ∧ x.1.ptr = y.1.ptr ∧
          x.1.len = y.1.len := by
    decide +kernel
  have hS : ∀ x ∈ (phasesF (redEnd true).mem.trace).1,
      (redEnd true).mem.ctaOf x.1.ptr.block ≠ none →
      ((x.1.ptr.off.toNat / 4 * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((x.1.ptr.off.toNat / 4 * 4 + 4 : Nat) : Int) ∧
        (x.1.ptr.off.toNat / 4 = x.1.who.thread % volume L24.block ∧
            x.1.ptr.off.toNat / 4 < s x.2 ∨
          x.1.write = false ∧ s x.2 ≤ x.1.ptr.off.toNat / 4) := by
    decide +kernel
  have hO : ∀ x ∈ (phasesF (redEnd true).mem.trace).1,
      (redEnd true).mem.ctaOf x.1.ptr.block = none → x.1.ptr.block = 1 := by
    decide +kernel
  rw [← (phasesF_eq _).1] at hA hS hO
  have hN : (redEnd true).mem.trace.all (fun e => match e with
      | .access a => !a.invariant
      | .barrier _ => true) = true := by
    decide +kernel
  refine Grid.sound_halving (redStart true) outW_bytesIn
    (fun m m' h => by simp only [obs1, h]) run hd (w := 4) (s := s) (A := (· == 1))
    (G := fun _ => none) hA (fun x hx b _ e => ⟨_, hS x hx (by simp [e])⟩)
    (fun x hx ha e => by simp [hO x hx e] at ha) (fun a _ ha _ hi _ => ?_)
    (y := leBytes 4 12) (by decide +kernel) rfl
  have := List.all_eq_true.1 hN _ ha
  simp [hi] at this

/-- **The twin of the second barrier**: without it, the evaluator's run of `redK false` ends in a
grid in which every thread has returned, but thread 1 writes cell 1 in the phase in which thread
0 reads it, so the trace is racy, the grid is bad and the start's grid is sound for no
observation. -/
theorem red_twin :
    ReflTransGen (Grid.Step L24 (redRun false).2) (redRun false).1 (redEnd false) ∧
      (redEnd false).Done ∧ racy (redEnd false).mem.trace = true ∧
      (redEnd false).Bad L24 (redRun false).2 ∧
      ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
        ¬ Grid.Sound L24 (redRun false).2 (redRun false).1 obs R := by
  have hr := Grid.run_reach (redRun_ok false)
  have hd : (redEnd false).Done := by
    unfold Grid.Done
    decide +kernel
  have hk : racy (redEnd false).mem.trace = true := by
    rw [racy_iff, (phasesF_eq _).1]
    decide +kernel
  refine ⟨hr, hd, hk, hd.bad_iff.2 (.inl hk), fun _ _ hs => ?_⟩
  have := hs.raceFree _ hr
  rw [hk] at this
  cases this

end MojoProofTest.Shared
