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

The run, one kernel: `shK true` with the shared global `@sh` of `n` words (`[n x i32]`) on a launch
`L` on the empty memory. Thread `k` stores its `%tid.x` to cell `tid.x` of its block of threads'
`@sh`, waits at a barrier, then loads cell `tid.x xor 1`. For every launch and size whose evaluated
run passes the checks `shOk` (it ends with every thread returned, its trace meets the premises of
`Grid.sound_cells` at the cell map `id` and cells of 4 bytes, and block 2 holds the words `0` to
`n - 1`), the start's grid is sound for those bytes (`sh_sound_of`). The checks are decided
(`decide +kernel`) at two launches and sizes: one block of two threads (`two`, `n = 2`, `sh_sound`)
and two blocks of four threads (`launch2 2 1 4 1`, `n = 4`, `sh_sound24`). The twin (`sh_twin`):
`shK false`, without the barrier, on `two` with thread 1 run between thread 0's store and its load,
ends with every thread returned, but its trace is racy (thread 1 reads cell 0 in the phase thread 0
writes it), so the start's grid is sound for no observation.

The run of a halving tree: `redK k true`, the tree of `2 ^ k` threads, on a launch `L` on the memory
`outW`, a word 0 of global memory passed as the pointer argument. Thread `t` of each block stores
its `%tid.x` to cell `t` of the shared global `@sh` (`[2 ^ k x i32]`); after each barrier the
threads below the stride `2 ^ (k - j)` add the cell one stride above into their own; thread 0 adds
cell 1 into cell 0 and the result into the output word by `atomicrmw add`. For every launch, level
count and word whose evaluated run passes the checks `redOk` (it ends with every thread returned,
its trace meets the premises of `Grid.sound_halving` at the strides `2 ^ k / 2 ^ p` and the output
block selected, and the output word is the given one), the start's grid is sound for that word,
bytes 0 to 3 of block 1 (`obs1`; `red_sound_of`). The checks are decided at two launches and sizes:
two blocks of four threads (`launch2 2 1 4 1`, `k = 2`, the word 12, `red_sound`) and two blocks of
eight threads (`launch2 2 1 8 1`, `k = 3`, the word 56, `red_sound28`). The kernel does not reduce
`phases`' hash map at block of threads 1, so the decisions go through `phasesF`, the same phases
computed without it (`phasesF_eq`, MojoProof/Sem/Race.lean). The twin (`red_twin`): `redK 2 false`
on `launch2 2 1 4 1`, without the second barrier, is racy (thread 0 reads cell 1 in the phase thread
1 writes it), so the start's grid is sound for no observation.
-/

namespace MojoProofTest.Shared

open MojoProof.LLVM MojoProof.Sem Relation
open GPUProof (Path.exists_iff)
open MojoProofTest.Transpose (acc4)
open MojoProofTest.Confluence (kern kprog two)
open MojoProofTest.ScheduleOwned (tidName tidDecl obs1)
open MojoProofTest.Launch (barrierName barrierDecl)
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

/-- **The halving tree on a trace**, the instance of `racy_halving` at `launch2 2 1 4 1`, `B = 4`,
`w = 1` and the strides `s`: `tr` has the premises of `racy_iff` (`Trace.fits_of_check`) and no
race. -/
theorem racy_eq_false_tr :
    GPUProof.racy sig (tr.map (Event.toCore (launch2 2 1 4 1))).reverse = false := by
  obtain ⟨hU, hs⟩ := Trace.fits_of_check (L := launch2 2 1 4 1) (tr := tr) (by decide +kernel)
  refine racy_halving hU hs (B := 4) (w := 1) (s := s) (ofSh := fun _ => some 0)
    (G := fun _ => none)
    (fun x hx β e => ?_) fun _ _ e => nomatch e
  cases Option.some.inj e
  rw [phases_tr] at hx
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  refine ⟨?_, ?_, x.1.ptr.off.toNat, ?_, ?_, ?_⟩ <;>
    rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    decide

/-- The twin without the barriers is racy. -/
example :
    GPUProof.racy sig ((p2 ++ p1 ++ p0).map (Event.toCore (launch2 2 1 4 1))).reverse = true := by
  decide +kernel

/-- The trace, newest first: thread `k < 4` writes byte `3 - k` of block 0, a barrier of block
of threads 0, then thread `k` reads byte `k`. -/
def trR : List Event :=
  [.access (acc4 3 3 false), .access (acc4 2 2 false), .access (acc4 1 1 false),
    .access (acc4 0 0 false), .barrier 0, .access (acc4 3 0 true), .access (acc4 2 1 true),
    .access (acc4 1 2 true), .access (acc4 0 3 true)]

/-- **Cells at a cell map other than the transposition**, the instance of `racy_cells` at
`launch2 2 1 4 1`, `B = 4`, `w = 1` and the cell map `3 - ·`, injective on `[0, 4)`: `trR` has the
premises of `racy_iff` (`Trace.fits_of_check`) and no race. -/
theorem racy_trR :
    GPUProof.racy sig (trR.map (Event.toCore (launch2 2 1 4 1))).reverse = false := by
  obtain ⟨hU, hs⟩ := Trace.fits_of_check (L := launch2 2 1 4 1) (tr := trR) (by decide +kernel)
  refine racy_cells hU hs (B := 4) (w := 1) (by decide) (cell := (3 - ·))
    (fun i hi j hj e => by omega)
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
example : GPUProof.racy sig ([.access (acc4 1 0 true), .access (acc4 0 0 true)].map
    (Event.toCore (launch2 2 1 4 1))).reverse = true := by
  decide +kernel

/-- An `atomicrmw add` by thread `k` of block of threads `b` to the 4 bytes at 0 of block 1. -/
def add1 (k b : Nat) : Access := ⟨⟨k, b⟩, ⟨1, 0⟩, 4, true, some .add, false⟩

/-- The trace, newest first: thread 4 of block of threads 1 and thread 0 of block of threads 0
each add a word to block 1, after the halving tree of `tr`. -/
def trA : List Event := .access (add1 4 1) :: .access (add1 0 0) :: tr

/-- **The output word's atomics and the halving tree**, the instance of `racy_dropBlocks` at
`launch2 2 1 4 1` with block 1 selected: `trA` has the premises of `racy_iff`
(`Trace.fits_of_check`), its two accesses of block 1 are atomics of one operation at one pointer
with one length, and the trace without them is `tr`, which has no race. -/
theorem racy_trA :
    GPUProof.racy sig (trA.map (Event.toCore (launch2 2 1 4 1))).reverse = false := by
  obtain ⟨hU, hs⟩ := Trace.fits_of_check (L := launch2 2 1 4 1) (tr := trA) (by decide +kernel)
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
  refine racy_dropBlocks (A := (· == 1)) hU hs (fun x hx y hy hx1 hb => ?_) ?_
  · have hx' := h1 _ (mem_phases hx) (beq_iff_eq.1 hx1)
    have hy' := h1 _ (mem_phases hy) (by rw [← hb]; exact beq_iff_eq.1 hx1)
    rcases hx' with h | h <;> rcases hy' with h' | h' <;> simp [h, h', add1, RmwOp.commutes]
  · have e : dropBlocks (· == 1) trA = tr := by decide +kernel
    rw [e]
    exact racy_eq_false_tr

/-- The twin: with thread 4's update a plain store, the trace is racy. -/
example : GPUProof.racy sig ((.access { add1 4 1 with atomic := none } :: .access (add1 0 0) ::
    tr).map (Event.toCore (launch2 2 1 4 1))).reverse = true := by
  decide +kernel

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

/-- `@sh = internal addrspace(3) global [n x i32] undef, align 4`. -/
def shG (n : Nat) : Global :=
  ⟨"sh", ["internal"], 3, false, .arr n (.int 32), some .undef, some 4⟩

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

/-- The program of `shK bar`, `shG n`, the barrier with attribute group 0 `convergent` and
`%tid.x`, with the default data layout. -/
def shP (n : Nat) (bar : Bool) : Program :=
  { kprog with
    module :=
      { (default : Module) with
        globals := #[shG n]
        funcs := #[shK bar, tidDecl, barrierDecl]
        attrGroups := #[(0, [.flag "convergent"])] }
    intrinsics := [(tidName, .sreg .tid .x), (barrierName, .barrier)] }

/-- The grid and contexts of the launch of `shK bar` with `@sh` of `n` words on launch `L` on the
empty memory, with address choice and oracle 0 (an empty grid if it fails). -/
def shRun (L : Launch) (n : Nat) (bar : Bool) : Grid × (Nat → Ctx) :=
  match Grid.start (shP n bar) (shK bar) L [] {} (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨shP n bar, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The grid the evaluator `Grid.run` reaches from the start of `shK true` with `@sh` of `n`
words on launch `L`, with at most 10 steps per thread and phase and at most 3 phases (the start's
grid if it fails). -/
def shDone (L : Launch) (n : Nat) : Grid :=
  match (shRun L n true).1.run L (shRun L n true).2 10 3 with
  | .ok g => g
  | .error _ => (shRun L n true).1

/-- Bytes 0 to `4 n - 1` of block 2, the shared block of `@sh` of block of threads 0. -/
def shObs (n : Nat) (m : Mem) : Option (List MemByte) := (m.blocks 2).map (·.read 0 (4 * n))

/-- The words `0` to `n - 1`, of 4 little-endian bytes each. -/
def shWords (n : Nat) : List MemByte := (List.range n).flatMap (leBytes 4)

/-- The evaluator's checks of `shK true` with `@sh` of `n` words on launch `L`: the start and the
run to `shDone L n` succeed, every thread returns, every access of the trace by phase (`phasesF`)
is to a block of threads' shared memory, in phase 0 inside the 4 bytes at
`4 (thread % volume L.block)` and later a read, no access has `!invariant.load`, and `shObs n` of
the last memory is `shWords n`. -/
def shOk (L : Launch) (n : Nat) : Bool :=
  (Grid.start (shP n true) (shK true) L [] {} (fun _ => 0) (fun _ _ => 0)).toBool &&
    ((shRun L n true).1.run L (shRun L n true).2 10 3).toBool &&
    (shDone L n).threads.all (· matches .done) &&
    decide (∀ x ∈ (phasesF (shDone L n).mem.trace).1,
      (shDone L n).mem.ctaOf x.1.ptr.block ≠ none ∧
      ((x.2 = 0 → ((x.1.who.thread % volume L.block * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((x.1.who.thread % volume L.block * 4 + 4 : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false))) &&
    (shDone L n).mem.trace.all (fun e => match e with
      | .access a => !a.invariant
      | .barrier _ => true) &&
    decide (shObs n (shDone L n).mem = some (shWords n))

/-- **A run with shared memory and a barrier, by evaluation**, for every launch `L` with
`volume L.block > 0` and every number `n` of words of `@sh` that the evaluator's checks accept
(`shOk L n`): in the run of `shK true` that the evaluator takes, thread `k` writes its `%tid.x`
to cell `tid.x` of its block of threads' `@sh`, the barrier completes, and thread `k` reads cell
`tid.x xor 1`; every thread returns and block 2 holds the words `0` to `n - 1`. So the start's
grid is sound for those bytes: no schedule races and every schedule observes them.
`Grid.sound_cells` at the cell map `id` and cells of 4 bytes, on the run `Grid.run_reach` gives.
The checks are decided at each launch and size (`sh_sound`, `sh_sound24`). -/
theorem sh_sound_of (L : Launch) (n : Nat) (hv : 0 < volume L.block) (h : shOk L n = true) :
    Grid.Sound L (shRun L n true).2 (shRun L n true).1 (shObs n) (· = shWords n) := by
  simp only [shOk, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨hs, hr⟩, hd⟩, hS⟩, hN⟩, hy⟩ := h
  have hst : Grid.start (shP n true) (shK true) L [] {} (fun _ => 0) (fun _ _ => 0) =
      .ok ((shRun L n true).1, (shRun L n true).2) := by
    unfold shRun
    revert hs
    cases Grid.start (shP n true) (shK true) L [] {} (fun _ => 0) (fun _ _ => 0) with
    | ok r => intro _; rfl
    | error e => intro hs; simp [Except.toBool] at hs
  have hrun : (shRun L n true).1.run L (shRun L n true).2 10 3 = .ok (shDone L n) := by
    unfold shDone
    revert hr
    cases (shRun L n true).1.run L (shRun L n true).2 10 3 with
    | ok g => intro _; rfl
    | error e => intro hr; simp [Except.toBool] at hr
  obtain ⟨_, run⟩ := Path.exists_iff.2 (Grid.run_reach hrun)
  rw [← (phasesF_eq _).1] at hS
  refine Grid.sound_cells hst (fun _ _ _ _ _ h => by cases h)
    (fun m m' h => by simp only [shObs, h]) run (Grid.done_of_all hd) (w := 4) (cell := id) hv
    (fun _ _ _ _ e => e) (G := fun _ => none) (fun x hx _ _ => (hS x hx).2)
    (fun x hx e => absurd e (hS x hx).1) (fun a _ ha _ hi _ => ?_) hy rfl
  have := List.all_eq_true.1 hN _ ha
  simp [hi] at this

/-- **A run with shared memory and a barrier on one block of two threads**: `sh_sound_of` at
`two` and `n = 2`, the checks decided; block 2 holds the words 0 and 1. -/
theorem sh_sound : Grid.Sound two (shRun two 2 true).2 (shRun two 2 true).1 (shObs 2)
    (· = shWords 2) :=
  sh_sound_of two 2 (by decide) (by decide +kernel)

/-- **The same on two blocks of four threads**: `sh_sound_of` at `launch2 2 1 4 1` and `n = 4`, the
checks decided; block 2, the shared block of block of threads 0, holds the words 0 to 3. -/
theorem sh_sound24 : Grid.Sound (launch2 2 1 4 1) (shRun (launch2 2 1 4 1) 4 true).2
    (shRun (launch2 2 1 4 1) 4 true).1 (shObs 4) (· = shWords 4) :=
  sh_sound_of (launch2 2 1 4 1) 4 (by decide) (by decide +kernel)

/-- The start of `shK false`, the kernel without its barrier, after thread 0's call, address and
store, then every step of thread 1, then thread 0's other steps. -/
def shTwin : Grid :=
  advs (shRun two 2 false).2 (shRun two 2 false).1 [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0]

/-- **The twin of the barrier**: without it, the run to `shTwin` is a run to a grid in which
every thread has returned, but thread 1 reads cell 0 in the phase in which thread 0 writes it, so
the trace is racy, the grid is bad and the start's grid is sound for no observation. -/
theorem sh_twin :
    ReflTransGen (Grid.Step two (shRun two 2 false).2) (shRun two 2 false).1 shTwin ∧
    GPUProof.Done sig (shTwin, two, (shRun two 2 false).2) ∧
    GPUProof.racy sig (shTwin.mem.trace.map (Event.toCore two)).reverse = true ∧
    GPUProof.Bad sig (shTwin, two, (shRun two 2 false).2) ∧
    ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
      ¬ Grid.Sound two (shRun two 2 false).2 (shRun two 2 false).1 obs R := by
  have hr : ReflTransGen (Grid.Step two (shRun two 2 false).2) (shRun two 2 false).1 shTwin :=
    Path.exists_iff.1 ⟨_, path_advs _ [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0]
      (by decide +kernel) (.nil _)⟩
  have hd : GPUProof.Done sig (shTwin, two, (shRun two 2 false).2) :=
    Grid.done_of_all (by decide +kernel)
  have hk : GPUProof.racy sig (shTwin.mem.trace.map (Event.toCore two)).reverse = true := by
    decide +kernel
  refine ⟨hr, hd, hk, (Grid.Done.bad_iff (by decide +kernel) hd).2 (.inl hk), fun _ _ hs => ?_⟩
  have := hs.raceFree _ hr
  rw [hk] at this
  cases this

/-! ## A run of a halving tree with an atomic output word -/

/-- The kernel `@k(ptr addrspace(1) %0)` of the halving tree of `2 ^ k` threads (`k > 0`), with
its last barrier if `bar`, on `@sh` (`shG (2 ^ k)`). Block 10: `%1 = call i32
@llvm.nvvm.read.ptx.sreg.tid.x()`, `%2 = getelementptr inbounds i32, ptr addrspace(3) @sh, i32 %1`,
`store i32 %1, ptr addrspace(3) %2, align 4`, the barrier and the test of level 1. Level `j < k`,
of stride `h = 2 ^ (k - j)`, at registers from `r = 6 j - 3`: the test `%r = icmp ult i32 %1, h`
branches to block `20 j`, `%(r+1) = load i32, %2`, `%(r+2) = add i32 %1, h`,
`%(r+3) = getelementptr inbounds i32, @sh, i32 %(r+2)`, `%(r+4) = load i32, %(r+3)`,
`%(r+5) = add i32 %(r+1), %(r+4)`, `store i32 %(r+5), %2`, `br label %(20 j + 10)`, or to block
`20 j + 10`: the barrier (the one before level `k` only if `bar`) and the test of level `j + 1`.
Level `k`, at `r = 6 k - 3`: the test `%r = icmp eq i32 %1, 0` branches to block `20 k`,
`%(r+1) = load i32, %2`, `%(r+2) = getelementptr inbounds i32, @sh, i32 1`,
`%(r+3) = load i32, %(r+2)`, `%(r+4) = add i32 %(r+1), %(r+3)`, `store i32 %(r+4), %2`,
`%(r+5) = atomicrmw add ptr addrspace(1) %0, i32 %(r+4) seq_cst, align 4`,
`br label %(20 k + 10)`, or to block `20 k + 10`: `ret void`. At `k = 2`: blocks 10 to 50, the
strides 2 and 1. -/
def redK (k : Nat) (bar : Bool) : Func :=
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
  let h (j : Nat) : Value := .int (Int.ofNat (2 ^ (k - j)))
  let test (j : Nat) : Stmt :=
    { res := some (6 * j - 3),
      inst := if j < k then .icmp .ult (.int 32) (.loc 1) (h j)
        else .icmp .eq (.int 32) (.loc 1) (.int 0) }
  let body (j : Nat) : Array Stmt :=
    let r := 6 * j - 3
    if j < k then
      #[ld (r + 1) 2, add (r + 2) (.loc 1) (h j), cellAt (r + 3) (.loc (r + 2)), ld (r + 4) (r + 3),
        add (r + 5) (.loc (r + 1)) (.loc (r + 4)), st (r + 5) 2]
    else
      #[ld (r + 1) 2, cellAt (r + 2) (.int 1), ld (r + 3) (r + 2),
        add (r + 4) (.loc (r + 1)) (.loc (r + 3)), st (r + 4) 2,
        { res := some (r + 5), inst := .atomicrmw false .add ⟨.ptr 1, .loc 0⟩
            ⟨.int 32, .loc (r + 4)⟩ none .seqCst (some 4) }]
  let level (j : Nat) : List MojoProof.LLVM.Block :=
    [⟨20 * j, body j, .br (20 * j + 10)⟩,
      ⟨20 * j + 10, (if j + 1 < k ∨ bar = true then #[barCall] else #[]) ++ #[test (j + 1)],
        .condBr (.loc (6 * (j + 1) - 3)) (20 * (j + 1)) (20 * (j + 1) + 10)⟩]
  { kern with
    params := [⟨.ptr 1, [], some 0⟩]
    blocks := #[⟨10, #[{ res := some 1, inst := .call {} (.int 32) (.fn tidName) [] },
        cellAt 2 (.loc 1), st 1 2, barCall, test 1], .condBr (.loc 3) 20 30⟩] ++
      ((List.range (k - 1)).flatMap fun i => level (i + 1)).toArray ++
      #[⟨20 * k, body k, .br (20 * k + 10)⟩, ⟨20 * k + 10, #[], .ret none⟩] }

/-- The program of `redK k bar`, `shG (2 ^ k)`, the barrier with attribute group 0 `convergent`
and `%tid.x`, with the default data layout. -/
def redP (k : Nat) (bar : Bool) : Program :=
  { kprog with
    module :=
      { (default : Module) with
        globals := #[shG (2 ^ k)]
        funcs := #[redK k bar, tidDecl, barrierDecl]
        attrGroups := #[(0, [.flag "convergent"])] }
    intrinsics := [(tidName, .sreg .tid .x), (barrierName, .barrier)] }

/-- The caller's memory: block 1, the output word, 4 bytes of global memory holding 0. -/
def outW : Mem := (({} : Mem).alloc {} 1 4 4 true false .all 1 1 (leBytes 4 0)).1

/-- `outW` has no pointer byte. -/
theorem outW_bytesIn : outW.BytesIn outW.Known :=
  Mem.alloc_bytesIn (fun _ _ _ _ _ h => by cases h) (fun p j h => by simp [leBytes] at h)
    _ _ _ _ _ _ _ _ _ _

/-- The grid and contexts of the launch of `redK k bar` on launch `L` with the pointer to
`outW`'s block 1, with address choice and oracle 0 (an empty grid if it fails). -/
def redRun (L : Launch) (k : Nat) (bar : Bool) : Grid × (Nat → Ctx) :=
  match Grid.start (redP k bar) (redK k bar) L [.ptr ⟨1, 0⟩] outW (fun _ => 0) (fun _ _ => 0) with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨redP k bar, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The grid the evaluator `Grid.run` reaches from the start of `redK k bar` on `L`, with at most
30 steps per thread and phase and at most `k + 2` phases (the start's grid if it fails). -/
def redEnd (L : Launch) (k : Nat) (bar : Bool) : Grid :=
  match (redRun L k bar).1.run L (redRun L k bar).2 30 (k + 2) with
  | .ok g => g
  | .error _ => (redRun L k bar).1

/-- **The evaluator reaches `redEnd`**, for every launch `L`, level count `k` and flag `bar` whose
run succeeds (`toBool`): the run is `.ok (redEnd L k bar)`. -/
theorem redRun_ok (L : Launch) (k : Nat) (bar : Bool)
    (h : ((redRun L k bar).1.run L (redRun L k bar).2 30 (k + 2)).toBool = true) :
    (redRun L k bar).1.run L (redRun L k bar).2 30 (k + 2) = .ok (redEnd L k bar) := by
  unfold redEnd
  revert h
  cases (redRun L k bar).1.run L (redRun L k bar).2 30 (k + 2) with
  | ok g => intro _; rfl
  | error e => intro hb; simp [Except.toBool] at hb

/-- The evaluator's checks of `redK k true` on launch `L` with output word `y`: the start and the
run to `redEnd L k true` succeed, every thread returns; by phase (`phasesF`), every two accesses
to block 1 are atomics of one operation at one pointer with one length, every access to a block
of threads' shared memory is inside the 4 bytes of a cell `c` with `c` its thread's
(`thread % volume L.block`) below the phase's stride `2 ^ k / 2 ^ p`, or a read of a cell at or
above it, and every other access is to block 1; no access has `!invariant.load`; and `obs1` of the
last memory is `leBytes 4 y`. -/
def redOk (L : Launch) (k y : Nat) : Bool :=
  (Grid.start (redP k true) (redK k true) L [.ptr ⟨1, 0⟩] outW (fun _ => 0)
      (fun _ _ => 0)).toBool &&
    ((redRun L k true).1.run L (redRun L k true).2 30 (k + 2)).toBool &&
    (redEnd L k true).threads.all (· matches .done) &&
    decide (∀ x ∈ (phasesF (redEnd L k true).mem.trace).1,
      ∀ y ∈ (phasesF (redEnd L k true).mem.trace).1,
      (x.1.ptr.block == 1) = true → x.1.ptr.block = y.1.ptr.block →
        x.1.atomic.isSome = true ∧ x.1.atomic = y.1.atomic ∧ x.1.ptr = y.1.ptr ∧
          x.1.len = y.1.len) &&
    decide (∀ x ∈ (phasesF (redEnd L k true).mem.trace).1,
      (redEnd L k true).mem.ctaOf x.1.ptr.block ≠ none →
      ((x.1.ptr.off.toNat / 4 * 4 : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((x.1.ptr.off.toNat / 4 * 4 + 4 : Nat) : Int) ∧
        (x.1.ptr.off.toNat / 4 = x.1.who.thread % volume L.block ∧
            x.1.ptr.off.toNat / 4 < 2 ^ k / 2 ^ x.2 ∨
          x.1.write = false ∧ 2 ^ k / 2 ^ x.2 ≤ x.1.ptr.off.toNat / 4)) &&
    decide (∀ x ∈ (phasesF (redEnd L k true).mem.trace).1,
      (redEnd L k true).mem.ctaOf x.1.ptr.block = none → x.1.ptr.block = 1) &&
    (redEnd L k true).mem.trace.all (fun e => match e with
      | .access a => !a.invariant
      | .barrier _ => true) &&
    decide (obs1 (redEnd L k true).mem = some (leBytes 4 y))

/-- The launch of `redK k bar` on `L` starts at `redRun L k bar`, for every launch, level count
and flag whose start the evaluator's check accepts. -/
theorem redRun_start (L : Launch) (k : Nat) (bar : Bool)
    (hs : (Grid.start (redP k bar) (redK k bar) L [.ptr ⟨1, 0⟩] outW (fun _ => 0)
      (fun _ _ => 0)).toBool = true) :
    Grid.start (redP k bar) (redK k bar) L [.ptr ⟨1, 0⟩] outW (fun _ => 0) (fun _ _ => 0) =
      .ok ((redRun L k bar).1, (redRun L k bar).2) := by
  unfold redRun
  revert hs
  cases Grid.start (redP k bar) (redK k bar) L [.ptr ⟨1, 0⟩] outW (fun _ => 0)
    (fun _ _ => 0) with
  | ok r => intro _; rfl
  | error e => intro hs; simp [Except.toBool] at hs

/-- **A run of a halving tree with an atomic output word, by evaluation**, for every launch `L`,
level count `k` and word `y` that the evaluator's checks accept (`redOk L k y`): the instance of
`Grid.sound_halving` at cells of 4 bytes, the strides `2 ^ k / 2 ^ p` and `A` selecting block 1.
In the run of `redK k true` that the evaluator takes, in each block of threads thread `t` writes
its `%tid.x` to cell `t` of `@sh`; after each barrier the threads below the stride add the cell
one stride above into their own; thread 0 adds the block's sum into the output word by `atomicrmw
add`. The `atomicrmw`s of different blocks of threads on one word meet the pattern only with
block 1 dropped (`racy_dropBlocks`). So the start's grid is sound for the output word, bytes 0 to
3 of block 1 (`obs1`): no schedule races and every schedule observes `y`. The checks are decided
at each launch and level count (`red_sound`, `red_sound28`). -/
theorem red_sound_of (L : Launch) (k y : Nat) (h : redOk L k y = true) :
    Grid.Sound L (redRun L k true).2 (redRun L k true).1 obs1 (· = leBytes 4 y) := by
  simp only [redOk, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨⟨hs, hr⟩, hd⟩, hA⟩, hS⟩, hO⟩, hN⟩, hy⟩ := h
  have hst := redRun_start L k true hs
  obtain ⟨_, run⟩ := Path.exists_iff.2 (Grid.run_reach (redRun_ok L k true hr))
  rw [← (phasesF_eq _).1] at hA hS hO
  refine Grid.sound_halving hst outW_bytesIn
    (fun m m' h => by simp only [obs1, h]) run (Grid.done_of_all hd) (w := 4)
    (s := fun p => 2 ^ k / 2 ^ p)
    (A := (· == 1)) (G := fun _ => none) hA (fun x hx b _ e => ⟨_, hS x hx (by simp [e])⟩)
    (fun x hx ha e => by simp [hO x hx e] at ha) (fun a _ ha _ hi _ => ?_) hy rfl
  have := List.all_eq_true.1 hN _ ha
  simp [hi] at this

/-- **The halving tree on two blocks of four threads**: `red_sound_of` at `launch2 2 1 4 1` and
`k = 2`, the checks decided; the strides are 4, 2 and 1, each block adds 6 and the output
word is 12. -/
theorem red_sound : Grid.Sound (launch2 2 1 4 1) (redRun (launch2 2 1 4 1) 2 true).2
    (redRun (launch2 2 1 4 1) 2 true).1 obs1 (· = leBytes 4 12) :=
  red_sound_of (launch2 2 1 4 1) 2 12 (by decide +kernel)

/-- **The halving tree on two blocks of eight threads**: `red_sound_of` at `launch2 2 1 8 1` and
`k = 3`, the checks decided; the strides are 8, 4, 2 and 1, each block adds 28 and the output word
is 56. -/
theorem red_sound28 : Grid.Sound (launch2 2 1 8 1) (redRun (launch2 2 1 8 1) 3 true).2
    (redRun (launch2 2 1 8 1) 3 true).1 obs1 (· = leBytes 4 56) :=
  red_sound_of (launch2 2 1 8 1) 3 56 (by decide +kernel)

/-- **The twin of the second barrier**: without it, the evaluator's run of `redK 2 false` on
`launch2 2 1 4 1` ends in a grid in which every thread has returned, but thread 1 writes cell 1 in
the phase in which thread 0 reads it, so the trace is racy, the grid is bad and the start's grid is
sound for no observation. -/
theorem red_twin :
    ReflTransGen (Grid.Step (launch2 2 1 4 1) (redRun (launch2 2 1 4 1) 2 false).2)
        (redRun (launch2 2 1 4 1) 2 false).1 (redEnd (launch2 2 1 4 1) 2 false) ∧
      GPUProof.Done sig
        (redEnd (launch2 2 1 4 1) 2 false, launch2 2 1 4 1, (redRun (launch2 2 1 4 1) 2 false).2) ∧
      GPUProof.racy sig ((redEnd (launch2 2 1 4 1) 2 false).mem.trace.map
        (Event.toCore (launch2 2 1 4 1))).reverse = true ∧
      GPUProof.Bad sig
        (redEnd (launch2 2 1 4 1) 2 false, launch2 2 1 4 1, (redRun (launch2 2 1 4 1) 2 false).2) ∧
      ∀ {β : Type} (obs : Mem → Option β) (R : β → Prop),
        ¬ Grid.Sound (launch2 2 1 4 1) (redRun (launch2 2 1 4 1) 2 false).2
          (redRun (launch2 2 1 4 1) 2 false).1 obs R := by
  have hr := Grid.run_reach (redRun_ok (launch2 2 1 4 1) 2 false (by decide +kernel))
  have hd : GPUProof.Done sig
      (redEnd (launch2 2 1 4 1) 2 false, launch2 2 1 4 1, (redRun (launch2 2 1 4 1) 2 false).2) :=
    Grid.done_of_all (by decide +kernel)
  have hf := Grid.start_reach_fits (redRun_start (launch2 2 1 4 1) 2 false (by decide +kernel)) hr
  have hk : GPUProof.racy sig ((redEnd (launch2 2 1 4 1) 2 false).mem.trace.map
      (Event.toCore (launch2 2 1 4 1))).reverse = true := by
    rw [racy_iff hf.trace hf.2, (phasesF_eq _).1]
    decide +kernel
  refine ⟨hr, hd, hk, (Grid.Done.bad_iff (by decide +kernel) hd).2 (.inl hk),
    fun _ _ hs => ?_⟩
  have := hs.raceFree _ hr
  rw [hk] at this
  cases this

end MojoProofTest.Shared
