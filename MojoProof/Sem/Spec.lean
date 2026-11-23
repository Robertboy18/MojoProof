import MojoProof.Sem.Grid

/-!
# What a kernel theorem states

The predicates kernel theorems are stated with, for a launch `L`, thread contexts `c` and a start
grid `g₀`. The skeleton choices (every address,
`ch` of `Grid.start`) and the payload choices (the float oracle) are fixed in `c`; `Grid.Step L c`
is one step of any schedule.

* `Grid.Faults`: some thread's step, or the completion of the collective call some thread waits
  at, is undefined behavior or unsupported. `Grid.Safe`: no grid reachable from `g₀` faults; it
  covers both `Grid.advance` and `Grid.fire`, so a barrier with a returned participant or with
  participants at different barriers is a fault.
* `Grid.Progress`: every reachable grid in which some thread has not returned has a step (no
  deadlock). It is separate from termination.
* `Grid.Terminates`: every execution from `g₀` is finite (`Acc` of the converse of `Step`): steps
  of any threads in any order, with no fairness assumption. A kernel whose thread spins on a
  location another thread writes does not terminate in this sense; the corpus has none.
* `Grid.Determinate obs`: all reachable grids in which every thread has returned agree on the
  observation `obs` of their memory. With the oracle and the address choices fixed this is
  schedule independence. The observation reads output buffers
  (`Mem.tensor`, MojoProof/Sem/Buffer.lean), never the raw memory: the order of the trace
  depends on the schedule.
* `Grid.RaceFree`: no reachable grid's trace has a data race (`racy`), so every two
  accesses by different threads that touch a common byte of one block, one of them a write and
  not both by `atomicrmw`s of one operation on the same bytes, are ordered by happens-before.
  Happens-before is program order and, within one block of threads, the barriers: an access
  before a barrier of its block of threads is ordered before the accesses of that block's threads
  after it (the aligned barrier needs all of them). Nothing else orders accesses: not shuffles,
  not atomics, and nothing orders different blocks of threads, so conflicting accesses of
  independently advancing blocks are races. This happens-before is contained in LLVM's and
  PTX's, so race freedom here implies theirs.
* `Grid.Kept`: every reachable grid's trace keeps the promise of `!invariant.load` (`kept`): no
  write touches the bytes such a load reads (TRUST T12; the other promises of T12 are checked by
  the semantics or refused).
* `Grid.Sound g₀ obs R`: the six above other than `Grid.Faults` (`Safe`, `Progress`,
  `Terminates`, `Determinate`, `RaceFree`, `Kept`), and every final grid's observation is
  defined and satisfies `R`. `Kernel.Sound`: for every address choice and oracle that `adm`
  admits, the launch starts and its grid is sound. A float relation or error bound is part of
  `R`, so it is proved for every admitted oracle. Kernel theorems take the hypothesis that the
  memory is closed for the arguments (`Mem.Closed`, MojoProof/Sem/Grid.lean):
  it passes the start's check (`Mem.checkClosed_of_closed`), and the launch's allocations find
  their numbers free. The start never deletes or replaces a block of the caller's memory
  (`Grid.start_blocks`), so `obs` reads the caller's blocks as the kernel left them.
* Admissibility: `Kernel.Sound` covers the executions whose address choices and oracle its
  admission `adm` admits, and only those. `adm := fun _ _ => True` admits every real
  execution's choices: each allocation reads its own choice numbers (`Grid.start` numbers them by
  block of threads, thread and parameter, an `alloca` by its thread's step, `Ctx.addr`), and
  every pair of aligned addresses in range is a choice (`Mem.alloc_addr`; blocks may overlap,
  TRUST T11, as the shared memories of different blocks of threads do on a GPU); every word
  `rsqrt.approx` may return and every NaN is an oracle number's (`rsqrt_toNatBits`,
  `exists_deliver`).
  The kernel theorems with `fun _ _ => True` are `Kernel.sound_ret_launch` (the `ret void`
  kernel, MojoProof/Sem/Trace.lean) and its instance `ret_empty` (MojoProofTest/Close.lean).
  `Kernel.sound_of_paths` (MojoProof/Sym/Kernel.lean) and `mojo_kernel`'s `n.sound_of` take any
  `adm`, and cover what it admits. `Kernel.sound_eval` and its instance `kernel22`
  (MojoProofTest/Kernel.lean) take an admission of one address choice and one oracle, so they
  cover the executions with those choices only.
* `Launch.Valid`: the limits of PTX launches, under which the special registers lie in the ranges
  the corpus's `range` attributes give them (`Launch.sreg_bound`).

The interleaving semantics is LLVM's for race-free runs (TRUST T13), so the race freedom in
`Grid.Sound` makes a sound grid's runs LLVM's.

Proved here, for every program, launch and observation:
* a sound grid has a final grid, and all final grids observe one value that satisfies `R`
  (`Grid.Sound.result`); the grid `Grid.run` returns is final (`Grid.run_done`), so its
  observation satisfies `R` (`Grid.Sound.run`);
* a grid in which every thread has returned has no step (`Grid.Done.final`), and a running
  thread's step is never `none` (`Grid.advance_run`), so under safety progress needs only the
  grids in which no thread runs (`Grid.progress_of_fire`);
* special registers on valid launches (`Launch.sreg_bound`);
* every pair of aligned addresses in range is a choice of `Mem.alloc` (`Mem.alloc_addr`).
Instances: two writes of one word race when they are by two threads of one block of threads with
no barrier between them, or by two blocks of threads with a barrier of each between them, and do
not when a barrier of their block of threads lies between them, or when both are by
`atomicrmw add`, and race when they are by `atomicrmw`s of two operations or two sizes; a write to
the bytes of an `!invariant.load` breaks its promise and a write next to them does not
(`trace_examples`); a grid of one thread at `unreachable` is not safe
(`Grid.not_safe_unreachable`); the launch of one thread is valid (`Launch.valid_one`). Sound
grids and kernels (`Grid.sound_one`, `Grid.sound_returning`, `Kernel.sound_ret_launch`) are in
MojoProof/Sem/Trace.lean, through the one-run theorem.
-/

namespace MojoProof.Sem

open LLVM Relation

/-- Accesses `a` and `e` touch a common byte of one block (an access of no bytes touches none). -/
def Access.overlaps (a e : Access) : Bool :=
  a.ptr.block == e.ptr.block && decide (0 < a.len) && decide (0 < e.len) &&
    decide (a.ptr.off < e.ptr.off + e.len) && decide (e.ptr.off < a.ptr.off + a.len)

/-- Accesses `a` and `e` conflict: they overlap, one of them writes, and they are not both by
`atomicrmw`s of one operation on the same bytes (same pointer and size). Two such updates commute
(`Stmt.checkAtomic` admits only commutative and associative operations, with unused results,
on integers whose width, a power of two of at least 8, the size determines). This is stricter
than LangRef's data race, where atomic accesses never race: an `add` and an `or` on one location,
or two sizes, conflict here, because their order changes the memory. -/
def Access.conflict (a e : Access) : Bool :=
  a.overlaps e && (a.write || e.write) &&
    !(a.atomic.isSome && a.atomic == e.atomic && a.ptr == e.ptr && a.len == e.len)

/-- Access `a` races with an access of trace `tr` before it (newest first): one by another
thread that conflicts with `a` and is not ordered before it by a barrier of their block of
threads. `sync` says a barrier of `a`'s block of threads lies between `a` and the events of the
trace still to be read. -/
def Access.races (a : Access) : Bool → List Event → Bool
  | _, [] => false
  | sync, .barrier k :: tr => a.races (sync || k == a.who.cta) tr
  | sync, .access e :: tr =>
    (e.who.thread != a.who.thread && !(sync && e.who.cta == a.who.cta) && a.conflict e) ||
      a.races sync tr

/-- Trace `tr` (newest first) has a data race: some access races with an earlier one. -/
def racy : List Event → Bool
  | [] => false
  | .barrier _ :: tr => racy tr
  | .access a :: tr => a.races false tr || racy tr

/-- Trace `tr` keeps the promise of `!invariant.load` (LangRef, "load": the bytes hold the same
value wherever they can be accessed): no write in it touches a byte that a load with
`!invariant.load` in it reads, before or after the load. -/
def kept (tr : List Event) : Bool :=
  let inv := tr.filterMap fun | .access a => if a.invariant then some a else none | _ => none
  tr.all fun | .access e => !e.write || inv.all (!·.overlaps e) | .barrier _ => true

/-- Writes of 4 bytes at offset 0 of block 1 by thread `n` of block of threads `b` race when
there is no barrier between them, or when they are by different blocks of threads; a barrier of
their block of threads orders them, and atomic writes of one operation do not race, but atomic
writes of two operations, or of two sizes, do; a write of no bytes at offset 1
touches none of the 4 bytes. A write to the bytes of a load with `!invariant.load` breaks its
promise, even by the same thread and before it; a write to the next 4 bytes does not. -/
theorem trace_examples :
    let w (n b : Nat) (atomic : Option RmwOp := none) : Event :=
      .access ⟨⟨n, b⟩, ⟨1, 0⟩, 4, true, atomic, false⟩
    let inv : Event := .access ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, false, none, true⟩
    racy [w 1 0, w 0 0] = true ∧ racy [w 1 1, .barrier 1, .barrier 0, w 0 0] = true ∧
      racy [w 1 0, .barrier 0, w 0 0] = false ∧
      racy [w 1 0 (some .add), w 0 0 (some .add)] = false ∧
      racy [w 1 0 (some .or), w 0 0 (some .add)] = true ∧
      racy [.access ⟨⟨1, 0⟩, ⟨1, 0⟩, 2, true, some .add, false⟩, w 0 0 (some .add)] = true ∧
      racy [.access ⟨⟨1, 0⟩, ⟨1, 1⟩, 0, true, none, false⟩, w 0 0] = false ∧
      kept [inv, w 0 0] = false ∧ kept [inv, .access ⟨⟨0, 0⟩, ⟨1, 4⟩, 4, true, none, false⟩] := by
  decide

namespace Grid

variable (L : Launch) (c : Nat → Ctx)

/-- Some thread's step, or the completion of the collective call some thread waits at, is
undefined behavior or unsupported. -/
def Faults (g : Grid) : Prop :=
  ∃ n e, g.advance c n = .error e ∨ g.fire L c n = .error e

/-- Every thread has returned. -/
def Done (g : Grid) : Prop := g.threads.all (· matches .done) = true

/-- No grid reachable from `g₀` faults. -/
def Safe (g₀ : Grid) : Prop := ∀ g, ReflTransGen (Step L c) g₀ g → ¬ g.Faults L c

/-- No deadlock: every grid reachable from `g₀` in which some thread has not returned has a
step. -/
def Progress (g₀ : Grid) : Prop :=
  ∀ g, ReflTransGen (Step L c) g₀ g → ¬ g.Done → ∃ g', Step L c g g'

/-- Every execution from `g₀` is finite, for steps of any threads in any order. -/
def Terminates (g₀ : Grid) : Prop := Acc (fun g' g => Step L c g g') g₀

/-- All grids reachable from `g₀` in which every thread has returned agree on `obs`. -/
def Determinate {β : Type} (obs : Mem → Option β) (g₀ : Grid) : Prop :=
  ∀ g g', ReflTransGen (Step L c) g₀ g → ReflTransGen (Step L c) g₀ g' → g.Done → g'.Done →
    obs g.mem = obs g'.mem

/-- No grid reachable from `g₀` has a data race in its trace (`racy`). -/
def RaceFree (g₀ : Grid) : Prop := ∀ g, ReflTransGen (Step L c) g₀ g → racy g.mem.trace = false

/-- Every grid reachable from `g₀` keeps the promise of `!invariant.load` in its trace (`kept`).
-/
def Kept (g₀ : Grid) : Prop := ∀ g, ReflTransGen (Step L c) g₀ g → kept g.mem.trace

/-- The grid `g₀` is safe, race free, keeps the promise of `!invariant.load`, makes progress,
terminates and is determinate for `obs`, and every reachable grid in which every thread has
returned has an observation that satisfies `R`. -/
structure Sound {β : Type} (g₀ : Grid) (obs : Mem → Option β) (R : β → Prop) : Prop where
  /-- Builds `Sound` from its seven fields. -/
  mk ::
  /-- No grid reachable from `g₀` faults. -/
  safe : Safe L c g₀
  /-- No grid reachable from `g₀` has a racy trace. -/
  raceFree : RaceFree L c g₀
  /-- Every grid reachable from `g₀` keeps the promise of `!invariant.load`. -/
  kept : Kept L c g₀
  /-- Every reachable grid in which some thread has not returned has a step. -/
  progress : Progress L c g₀
  /-- Every execution from `g₀` is finite. -/
  terminates : Terminates L c g₀
  /-- All reachable grids in which every thread has returned agree on `obs`. -/
  determinate : Determinate L c obs g₀
  /-- Every reachable grid in which every thread has returned has an observation, and it
  satisfies `R`. -/
  post : ∀ g, ReflTransGen (Step L c) g₀ g → g.Done → ∃ y, obs g.mem = some y ∧ R y

variable {L c}

/-- In a grid in which every thread has returned, thread `n` is absent or has returned, for every
`n`. -/
theorem Done.get {g : Grid} (h : g.Done) (n : Nat) :
    g.threads[n]? = none ∨ g.threads[n]? = some .done := by
  rw [Done, Array.all_eq_true] at h
  by_cases hn : n < g.threads.size
  · right
    have := h n hn
    rw [Array.getElem?_eq_getElem hn]
    revert this
    cases g.threads[n] <;> simp
  · left
    exact Array.getElem?_eq_none (by omega)

/-- A grid in which every thread has returned has no step. -/
theorem Done.final {g g' : Grid} (h : g.Done) : ¬ Step L c g g' := by
  rintro ⟨n, h'⟩
  rcases h.get n with hn | hn <;> simp [advance, fire, hn, pure, Except.pure] at h'

/-- A running thread's step is a grid or a fault, never `none`. -/
theorem advance_run {g : Grid} {n : Nat} {t : Thread}
    (h : g.threads[n]? = some (Status.run t)) : g.advance c n ≠ .ok none := by
  simp only [advance, h, bind, Except.bind]
  cases step (c n) t g.mem with
  | error => simp
  | ok s => cases s <;> simp [pure, Except.pure]

/-- Under safety, progress needs only the grids in which no thread runs: there, the collective
call some thread waits at completes. -/
theorem progress_of_fire {g₀ : Grid} (hs : Safe L c g₀)
    (h : ∀ g, ReflTransGen (Step L c) g₀ g → ¬ g.Done →
      (∀ (n : Nat) (t : Thread), g.threads[n]? ≠ some (Status.run t)) →
      ∃ n g', g.fire L c n = .ok (some g')) : Progress L c g₀ := by
  intro g hr hd
  by_cases hrun : ∃ (n : Nat) (t : Thread), g.threads[n]? = some (Status.run t)
  · obtain ⟨n, t, ht⟩ := hrun
    match ha : g.advance c n with
    | .ok (some g') => exact ⟨g', n, .inl ha⟩
    | .ok none => exact absurd ha (advance_run ht)
    | .error e => exact absurd ⟨n, e, .inl ha⟩ (hs g hr)
  · push Not at hrun
    obtain ⟨n, g', hf⟩ := h g hr hd hrun
    exact ⟨g', n, .inr hf⟩

/-- The grid the evaluator returns is final. -/
theorem run_done {fuel : Nat} :
    ∀ {phases : Nat} {g g' : Grid}, g.run L c fuel phases = .ok g' → g'.Done
  | 0, g, g', h => by simp [run] at h
  | phases + 1, g, g', h => by
    simp only [run] at h
    split at h
    · cases h
      assumption
    · simp only [bind, Except.bind] at h
      split at h
      · cases h
      · split at h
        · cases h
        · split at h
          · exact run_done h
          · split at h
            · cases h
              assumption
            · cases h

variable {β : Type} {obs : Mem → Option β} {R : β → Prop} {g₀ : Grid}

/-- A sound grid has a final grid, and all its final grids observe one value, which satisfies
`R`. -/
theorem Sound.result (h : Sound L c g₀ obs R) :
    ∃ y, R y ∧ (∃ g, ReflTransGen (Step L c) g₀ g ∧ g.Done) ∧
      ∀ g, ReflTransGen (Step L c) g₀ g → g.Done → obs g.mem = some y := by
  suffices ∀ g, Acc (fun g' g => Step L c g g') g → ReflTransGen (Step L c) g₀ g →
      ∃ g', ReflTransGen (Step L c) g₀ g' ∧ g'.Done by
    obtain ⟨g, hr, hd⟩ := this g₀ h.terminates .refl
    obtain ⟨y, hy, hR⟩ := h.post g hr hd
    exact ⟨y, hR, ⟨g, hr, hd⟩, fun g' hr' hd' => (h.determinate g' g hr' hr hd' hd).trans hy⟩
  intro g hg
  induction hg with
  | intro g _ ih =>
    intro hr
    by_cases hd : g.Done
    · exact ⟨g, hr, hd⟩
    · obtain ⟨g', hs⟩ := h.progress g hr hd
      exact ih g' hs (hr.tail hs)

/-- The observation of the grid the evaluator returns satisfies `R`. -/
theorem Sound.run (h : Sound L c g₀ obs R) {fuel phases : Nat} {g : Grid}
    (hr : g₀.run L c fuel phases = .ok g) : ∃ y, obs g.mem = some y ∧ R y :=
  h.post g (run_reach hr) (run_done hr)

/-- A grid of one thread whose step is undefined behavior is not safe. -/
theorem not_safe_one {t : Thread} {M : Mem} {msg : String} (h : step (c 0) t M = .error (.ub msg)) :
    ¬ Safe L c ⟨#[.run t], M⟩ := fun hs =>
  hs _ .refl ⟨0, .ub msg, .inl (by simp [advance, h, bind, Except.bind])⟩

end Grid

/-- Kernel `fn` of `prog`, launched with `L` on arguments `args` and memory `m`: for every
address choice `ch` and oracle that `adm` admits, the launch starts and its grid is sound for
observation `obs` and relation `R`. -/
def Kernel.Sound {β : Type} (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop) (obs : Mem → Option β) (R : β → Prop) : Prop :=
  ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c) ∧
    Grid.Sound L c g obs R

/-- **A sound kernel has an observation at every admitted address choice and oracle family**: for
every program, kernel, launch, arguments, memory, admission `adm`, observation `obs` and relation
`R`, if the kernel is sound (`Kernel.Sound`) and `adm ch ω`, then the launch starts under `ch`
and `ω` at a grid `g` with configuration `c`, some grid `g'` that `g` reaches has every thread
returned, and `obs` at `g'`'s memory is a `y` with `R y`. A sound grid makes progress and
terminates (`Grid.Sound.result`). -/
theorem Kernel.Sound.exists_obs {β : Type} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    {obs : Mem → Option β} {R : β → Prop} (h : Kernel.Sound prog fn L args m adm obs R)
    {ch : Nat → Nat} {ω : Nat → Nat → Nat} (ha : adm ch ω) :
    ∃ y, (∃ g c g', Grid.start prog fn L args m ch ω = .ok (g, c) ∧
      Relation.ReflTransGen (Grid.Step L c) g g' ∧ g'.Done ∧ obs g'.mem = some y) ∧ R y := by
  obtain ⟨g, c, hs, hS⟩ := h ch ω ha
  obtain ⟨y, hR, ⟨g', hr, hd⟩, hy⟩ := hS.result
  exact ⟨y, ⟨g, c, g', hs, hr, hd, hy g' hr hd⟩, hR⟩

/-- Every pair of addresses a real execution can give a block is a choice: addresses `A` in the
block's space and `G` in the generic space, multiples of its alignment and below 2 to the
power of the pointer widths, are those of the block `Mem.alloc` makes with choices `A / align`
and `G / align`. -/
theorem Mem.alloc_addr (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (init : List MemByte) {A G : Nat} (hA : align ∣ A)
    (hA' : A < 2 ^ (l.ptr space).1) (hG : align ∣ G) (hG' : G < 2 ^ (l.ptr 0).1) :
    let r := m.alloc l space size align live readOnly owner (A / align) (G / align) init
    (r.1.blocks r.2).map (fun b => (b.addr, b.gaddr)) = some (A, G) := by
  simp [Mem.alloc, Mem.set, Nat.div_mul_cancel hA, Nat.div_mul_cancel hG, Nat.mod_eq_of_lt hA',
    Nat.mod_eq_of_lt hG']

/-- The largest grid, by dimension: `%nctaid` is at most `(2^31 - 1, 65535, 65535)` (PTX ISA,
`%nctaid`; the corpus's `range` attributes say the same). -/
def Launch.maxGrid : Dim → Nat
  | .x => 2 ^ 31 - 1
  | _ => 65535

/-- The largest block, by dimension: `%ntid` is at most `(1024, 1024, 64)` (PTX ISA, `%ntid`;
the corpus's `range` attributes say the same). -/
def Launch.maxBlock : Dim → Nat
  | .z => 64
  | _ => 1024

/-- A launch PTX accepts: every side of the grid and of the block is positive and at most the
maximum, and a block has at most 1024 threads. -/
structure Launch.Valid (L : Launch) : Prop where
  /-- Builds `Launch.Valid` from its five fields. -/
  mk ::
  /-- Every side of the grid is positive. -/
  grid_pos : ∀ d, 0 < L.grid d
  /-- Every side of the grid is at most `maxGrid`. -/
  grid_le : ∀ d, L.grid d ≤ maxGrid d
  /-- Every side of the block is positive. -/
  block_pos : ∀ d, 0 < L.block d
  /-- Every side of the block is at most `maxBlock`. -/
  block_le : ∀ d, L.block d ≤ maxBlock d
  /-- A block has at most 1024 threads. -/
  threads : volume L.block ≤ 1024

/-- The least value of special register `r` on valid launches. -/
def _root_.MojoProof.LLVM.SReg.lo : SReg → Nat
  | .tid | .ctaid => 0
  | .ntid | .nctaid => 1

/-- One more than the largest value of special register `r` in dimension `d` on valid launches.
-/
def _root_.MojoProof.LLVM.SReg.hi : SReg → Dim → Nat
  | .tid, d => Launch.maxBlock d
  | .ntid, d => Launch.maxBlock d + 1
  | .ctaid, d => Launch.maxGrid d
  | .nctaid, d => Launch.maxGrid d + 1

/-- A coordinate of thread number `n` in a box `d` is below the box's side, for every positive
side. -/
theorem coord_lt {d : Dim → Nat} (n : Nat) {k : Dim} (h : 0 < d k) : coord d n k < d k := by
  cases k <;> exact Nat.mod_lt _ h

/-- On a valid launch, every special register of every thread lies in `[r.lo, r.hi d)`: the
ranges the corpus's `range` attributes give them (`%tid.x` in `[0, 1024)`, `%nctaid.x` in
`[1, 2^31)`, ...), all below `2^31`. -/
theorem Launch.sreg_bound {L : Launch} (h : L.Valid) (n : Nat) (r : SReg) (d : Dim) :
    r.lo ≤ (L.env n).sreg r d ∧ (L.env n).sreg r d < r.hi d := by
  cases r <;> simp only [Launch.env, SReg.lo, SReg.hi]
  · exact ⟨Nat.zero_le _, lt_of_lt_of_le (coord_lt _ (h.block_pos d)) (h.block_le d)⟩
  · exact ⟨h.block_pos d, Nat.lt_succ_of_le (h.block_le d)⟩
  · exact ⟨Nat.zero_le _, lt_of_lt_of_le (coord_lt _ (h.grid_pos d)) (h.grid_le d)⟩
  · exact ⟨h.grid_pos d, Nat.lt_succ_of_le (h.grid_le d)⟩

/-- The launch of one thread. -/
def Launch.one : Launch := ⟨fun _ => 1, fun _ => 1, 0⟩

/-- The launch of one thread is valid. -/
theorem Launch.valid_one : Launch.one.Valid where
  grid_pos _ := Nat.one_pos
  grid_le d := by cases d <;> decide
  block_pos _ := Nat.one_pos
  block_le d := by cases d <;> decide
  threads := by decide

/-- A kernel with one block, `entry`, of no instruction and terminator `term`. -/
def _root_.MojoProof.LLVM.Func.ofTerm (term : Term) : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"], blocks := #[{ label := 0, stmts := #[], term }] }

/-- A program of kernel `fn` alone, with the default data layout. -/
def _root_.MojoProof.LLVM.Program.ofFunc (fn : Func) : Program :=
  { module := { (default : Module) with funcs := #[fn] }, sha256 := "", layout := {},
    intrinsics := [], kernels := [fn.name] }

/-- The kernel `define void @k() { unreachable }`, launched on one thread, is not safe, for
every closed memory (`Mem.Closed`), address choice and oracle. -/
theorem Grid.not_safe_unreachable {m : Mem} (hm : m.Closed []) (ch : Nat → Nat)
    (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start (.ofFunc (.ofTerm .unreachable)) (.ofTerm .unreachable) .one [] m ch
      oracle = .ok (g, c) ∧ ¬ Grid.Safe .one c g :=
  have h0 : m.blocks m.next = none := hm.above _ le_rfl
  ⟨_, _, by
    rw [Grid.start, Mem.checkClosed_of_closed hm]
    simp only [volume, Launch.one, Nat.mul_one, List.range_one, List.foldlM_cons, List.foldlM_nil,
      shared, Mem.allocNext, h0]
    rfl, by exact Grid.not_safe_one rfl⟩

end MojoProof.Sem
