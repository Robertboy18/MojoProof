import MojoProof.Sem.SigDef

/-!
# What a kernel theorem states

The predicates kernel theorems are stated with, for a launch `L`, thread contexts `c` and a start
grid `g₀`. The skeleton choices (every address,
`ch` of `Grid.start`) and the payload choices (the float oracle) are fixed in `c`; `Grid.Step L c`
is one step of any schedule.

* The faults are the core's `GPUProof.Faults` at `sig` (`Grid.faults_iff`): some thread's step,
  or the completion of the collective call some thread waits at, is undefined behavior or
  unsupported. `Grid.Safe`: no grid reachable from `g₀` faults; it covers both `Grid.advance`
  and `Grid.fire`, so a barrier with a returned participant or with participants at different
  barriers is a fault.
* A grid is done when every thread of the launch has returned: the core's `GPUProof.Done` at
  `sig` (`Grid.done_iff`: each thread number below `volume L.grid * volume L.block` is absent
  from the grid or has returned).
* `Grid.Progress`: every reachable grid that is not done has a step (no deadlock). It is
  separate from termination.
* `Grid.Terminates`: every execution from `g₀` is finite (`Acc` of the converse of `Step`): steps
  of any threads in any order, with no fairness assumption. A kernel whose thread spins on a
  location another thread writes does not terminate in this sense; the corpus has none.
* `Grid.Determinate obs`: all reachable done grids agree on the observation `obs` of their
  memory. With the oracle and the address choices fixed this is
  schedule independence. The observation reads output buffers
  (`Mem.tensor`, MojoProof/Sem/Buffer.lean), never the raw memory: the order of the trace
  depends on the schedule.
* `Grid.RaceFree`: no reachable grid's trace has a data race (the core's `racy` at `sig`), so
  every two accesses by different threads that touch a common byte of one block, one of them a
  write and not both by `atomicrmw`s of one commuting operation (`RmwOp.commutes`) on the same
  bytes, are ordered by happens-before.
  Happens-before is program order and, within one block of threads, the barriers: an access
  before a barrier of its block of threads is ordered before the accesses of that block's threads
  after it (the aligned barrier needs all of them). Nothing else orders accesses: not shuffles,
  not atomics, and nothing orders different blocks of threads, so conflicting accesses of
  independently advancing blocks are races. This happens-before is contained in LLVM's and
  PTX's, so race freedom here implies theirs.
* `Grid.Kept`: every reachable grid's trace keeps the promise of `!invariant.load` (the core's
  `GPUProof.kept` at `sig` of its core events): no write and no `atomicrmw` touches the bytes such
  a load reads (TRUST T12; the other promises of T12 are checked by the semantics or refused).
* `Grid.Sound g₀ obs R`: the six above other than the faults (`Safe`, `Progress`,
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
* a done grid with at most the launch's number of threads has no step (`Grid.Done.final`;
  `Grid.done_of_all` gives done from a grid all of whose threads have returned), and a running
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
(`Grid.not_safe_unreachable`); the launch of one thread is valid (`Launch.valid_one`), and so is
the launch `launch2 x y bx by'` of `x` × `y` blocks of `bx` × `by'` threads when its sides fit
the limits (`launch2_valid`). The core's steps and reachable states at `sig` are the grid's
(`sig_step_iff`, `sig_reach_iff`), and a grid whose start is clean at `sig` (`GPUProof.Clean`)
and whose done grids agree is sound (`Grid.Sound.of_clean`). Sound grids and kernels
(`Grid.sound_of_one_run`, `Grid.sound_returning`, `Kernel.sound_ret_launch`) are in
MojoProof/Sem/Trace.lean, through the one-run theorem.

`Launch.Valid`, `Launch.maxGrid` and `Launch.maxBlock` are defined in
MojoProof/Sem/SigDef.lean, with `sig`, which reaches them.
-/

namespace MojoProof.Sem

open LLVM Relation

/-- Accesses `a` and `e` touch a common byte of one block (an access of no bytes touches none). -/
def Access.overlaps (a e : Access) : Bool :=
  a.ptr.block == e.ptr.block && decide (0 < a.len) && decide (0 < e.len) &&
    decide (a.ptr.off < e.ptr.off + e.len) && decide (e.ptr.off < a.ptr.off + a.len)

/-- Accesses `a` and `e` conflict: they overlap, one of them writes, and they are not both by
`atomicrmw`s of one commuting operation (`RmwOp.commutes`: `add`, `and`, `or`, `xor`, `max`,
`min`, `umax`, `umin`) on the same bytes (same pointer and size). Two such updates commute
(`rmw_comm`). Two updates by another operation (`xchg`, `nand`, `sub`, a float operation)
conflict, even of one operation on the same bytes. This is stricter than LangRef's data race,
where atomic accesses never race: an `add` and an `or` on one location, two sizes, or two
`xchg`s conflict here, because their order changes the memory. -/
def Access.conflict (a e : Access) : Bool :=
  a.overlaps e && (a.write || e.write) &&
    !(a.atomic.any RmwOp.commutes && a.atomic == e.atomic && a.ptr == e.ptr && a.len == e.len)

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

/-- A launch of `x` × `y` blocks of `bx` × `by'` threads, for every four sizes, with no dynamic
shared memory and the `mma` policy `gridAcc`: `launch2 1 1 k 1` is one block of `k` threads. -/
def launch2 (x y bx by' : Nat) : Launch where
  grid := fun | .x => x | .y => y | .z => 1
  block := fun | .x => bx | .y => by' | .z => 1

/-- The launch of one thread: `launch2 1 1 1 1`, one block of one thread. -/
def Launch.one : Launch := launch2 1 1 1 1

/-- **`launch2 x y bx by'` is valid** (`Launch.Valid`), for all four sides with every side
positive, `x < 2 ^ 31`, `y ≤ 65535` and `bx * by' ≤ 1024` (so `bx`, `by' ≤ 1024`); the premise
is decidable, so `by decide` proves it at numerals. -/
theorem launch2_valid {x y bx by' : Nat}
    (h : 0 < x ∧ 0 < y ∧ 0 < bx ∧ 0 < by' ∧ x < 2 ^ 31 ∧ y ≤ 65535 ∧ bx * by' ≤ 1024) :
    (launch2 x y bx by').Valid := by
  obtain ⟨hx, hy, hbx, hby, hx', hy', ht⟩ := h
  have hbx' : bx ≤ 1024 := (Nat.le_mul_of_pos_right bx hby).trans ht
  have hby' : by' ≤ 1024 := (Nat.le_mul_of_pos_left by' hbx).trans ht
  refine ⟨fun d => ?_, fun d => ?_, fun d => ?_, fun d => ?_, ?_⟩
  all_goals first
    | (cases d <;> simp only [launch2, Launch.maxGrid, Launch.maxBlock] <;> omega)
    | (simp only [launch2, volume]; omega)

/-- Writes of 4 bytes at offset 0 of block 1 by threads 0 and 1 race (the core's `racy` at
`sig`) when there is no barrier between them, or when they are by different blocks of threads
(the launch `G`, `launch2 2 1 1 1`, of two blocks of one thread; `B`, `launch2 1 1 2 1`, is one
block of two threads); a barrier of their block of threads orders them, and atomic writes of one
commuting operation do not race, but atomic writes of two operations, of two sizes, or of one
operation that does not commute (`xchg`), do; a write of no bytes at offset 1 touches none of
the 4 bytes. A write to the bytes of a load with `!invariant.load` breaks its promise (the core's
`kept` at `sig`, at the launch of one thread `Launch.one`), even by the same thread and before
it; a write to the next 4 bytes does not. -/
theorem trace_examples :
    let w (n b : Nat) (atomic : Option RmwOp := none) : Event :=
      .access ⟨⟨n, b⟩, ⟨1, 0⟩, 4, true, atomic, false⟩
    let inv : Event := .access ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, false, none, true⟩
    let B := launch2 1 1 2 1
    let G := launch2 2 1 1 1
    let r (L : Launch) (tr : List Event) : Bool :=
      GPUProof.racy sig (tr.map (Event.toCore L)).reverse
    r B [w 1 0, w 0 0] = true ∧ r G [w 1 1, .barrier 1, .barrier 0, w 0 0] = true ∧
      r B [w 1 0, .barrier 0, w 0 0] = false ∧
      r B [w 1 0 (some .add), w 0 0 (some .add)] = false ∧
      r B [w 1 0 (some .or), w 0 0 (some .add)] = true ∧
      r B [w 1 0 (some .xchg), w 0 0 (some .xchg)] = true ∧
      r B [.access ⟨⟨1, 0⟩, ⟨1, 0⟩, 2, true, some .add, false⟩, w 0 0 (some .add)] = true ∧
      r B [.access ⟨⟨1, 0⟩, ⟨1, 1⟩, 0, true, none, false⟩, w 0 0] = false ∧
      GPUProof.kept sig ([inv, w 0 0].map (Event.toCore Launch.one)).reverse = false ∧
      GPUProof.kept sig ([inv, .access ⟨⟨0, 0⟩, ⟨1, 4⟩, 4, true, none, false⟩].map
        (Event.toCore Launch.one)).reverse := by
  decide

/-- The core's faults at `sig` (`GPUProof.Faults`), for every grid, launch and contexts: some
thread's step, or the completion of the collective call some thread waits at, is undefined
behavior or unsupported. -/
theorem Grid.faults_iff {g : Grid} {L : Launch} {c : Nat → Ctx} :
    GPUProof.Faults sig (g, L, c) ↔ ∃ n e, g.advance c n = .error e ∨ g.fire L c n = .error e := by
  have hm : ∀ {γ δ : Type} {x : Except Fault γ} {f : γ → δ} {e : Fault},
      x.map f = .error e ↔ x = .error e := by
    intro γ δ x f e
    cases x <;> simp [Except.map]
  constructor
  · rintro (⟨a, e, h⟩ | ⟨t, e, h⟩)
    · rcases a with n | j
      · exact ⟨n, e, .inl (hm.1 h)⟩
      · exact j.elim
    · exact ⟨t, e, .inr (hm.1 h)⟩
  · rintro ⟨n, e, h | h⟩
    · exact .inl ⟨.thread n, e, hm.2 h⟩
    · exact .inr ⟨n, e, hm.2 h⟩

/-! ### The core's steps at `sig` -/

/-- A thread's step at `sig` is the grid's step with the launch and contexts kept, for every grid,
launch, contexts and thread. -/
@[simp] theorem sig_advance (g : Grid) (L : Launch) (c : Nat → Ctx) (n : Nat) :
    sig.advance (g, L, c) (.thread n) = (g.advance c n).map (Option.map (·, L, c)) := rfl

/-- A fire at `sig` is the grid's fire with the launch and contexts kept, for every grid, launch,
contexts and thread. -/
@[simp] theorem sig_fire (g : Grid) (L : Launch) (c : Nat → Ctx) (n : Nat) :
    sig.fire (g, L, c) n = (g.fire L c n).map (Option.map (·, L, c)) := rfl

/-- A step at `sig` from `(g, L, c)` is a grid step with `(L, c)` kept, for every grid, launch,
contexts and state. -/
theorem sig_step_iff {g : Grid} {L : Launch} {c : Nat → Ctx} {s : sig.State} :
    GPUProof.Step sig (g, L, c) s ↔ ∃ g', s = (g', L, c) ∧ Grid.Step L c g g' := by
  constructor
  · rintro (⟨a, h⟩ | ⟨n, h⟩)
    · rcases a with n | j
      · rw [sig_advance] at h
        cases hg : g.advance c n with
        | error => simp [hg, Except.map] at h
        | ok o =>
          rcases o with _ | g' <;> simp [hg, Except.map] at h
          subst h
          exact ⟨g', rfl, n, .inl hg⟩
      · exact j.elim
    · rw [sig_fire] at h
      cases hg : g.fire L c n with
      | error => simp [hg, Except.map] at h
      | ok o =>
        rcases o with _ | g' <;> simp [hg, Except.map] at h
        subst h
        exact ⟨g', rfl, n, .inr hg⟩
  · rintro ⟨g', rfl, n, h | h⟩
    · exact .inl ⟨.thread n, by rw [sig_advance, h]; rfl⟩
    · exact .inr ⟨n, by rw [sig_fire, h]; rfl⟩

/-- **The states reachable at `sig` are the reachable grids**, for every launch, contexts, grid
and state: `s` is reachable from `(g₀, L, c)` exactly when it is `(g, L, c)` for a grid `g`
reachable from `g₀` by `Grid.Step L c`. -/
theorem sig_reach_iff {g₀ : Grid} {L : Launch} {c : Nat → Ctx} {s : sig.State} :
    GPUProof.Reach sig (g₀, L, c) s ↔ ∃ g, s = (g, L, c) ∧ ReflTransGen (Grid.Step L c) g₀ g := by
  constructor
  · intro h
    induction h with
    | refl => exact ⟨g₀, rfl, .refl⟩
    | tail _ hs ih =>
      obtain ⟨g, rfl, hg⟩ := ih
      obtain ⟨g', rfl, hs'⟩ := sig_step_iff.1 hs
      exact ⟨g', rfl, hg.tail hs'⟩
  · rintro ⟨g, rfl, h⟩
    induction h with
    | refl => exact .refl
    | tail _ hs ih => exact ih.tail (sig_step_iff.2 ⟨_, rfl, hs⟩)

namespace Grid

variable (L : Launch) (c : Nat → Ctx)

/-- No grid reachable from `g₀` faults. -/
def Safe (g₀ : Grid) : Prop :=
  ∀ g, ReflTransGen (Step L c) g₀ g → ¬ GPUProof.Faults sig (g, L, c)

/-- No deadlock: every grid reachable from `g₀` in which some thread of the launch has not
returned (the core's `Done` at `sig`) has a step. -/
def Progress (g₀ : Grid) : Prop :=
  ∀ g, ReflTransGen (Step L c) g₀ g → ¬ GPUProof.Done sig (g, L, c) → ∃ g', Step L c g g'

/-- Every execution from `g₀` is finite, for steps of any threads in any order. -/
def Terminates (g₀ : Grid) : Prop := Acc (fun g' g => Step L c g g') g₀

/-- All grids reachable from `g₀` in which every thread of the launch has returned (the core's
`Done` at `sig`) agree on `obs`. -/
def Determinate {β : Type} (obs : Mem → Option β) (g₀ : Grid) : Prop :=
  ∀ g g', ReflTransGen (Step L c) g₀ g → ReflTransGen (Step L c) g₀ g' →
    GPUProof.Done sig (g, L, c) → GPUProof.Done sig (g', L, c) → obs g.mem = obs g'.mem

/-- No grid reachable from `g₀` has a data race in its trace (the core's `racy` at `sig`). -/
def RaceFree (g₀ : Grid) : Prop :=
  ∀ g, ReflTransGen (Step L c) g₀ g →
    GPUProof.racy sig (g.mem.trace.map (Event.toCore L)).reverse = false

/-- Every grid reachable from `g₀` keeps the promise of `!invariant.load` in its trace: the
core's `GPUProof.kept` at `sig` of its core events, oldest first. -/
def Kept (g₀ : Grid) : Prop :=
  ∀ g, ReflTransGen (Step L c) g₀ g → GPUProof.kept sig (g.mem.trace.map (Event.toCore L)).reverse

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
  /-- Every reachable grid in which every thread of the launch has returned has an observation,
  and it satisfies `R`. -/
  post : ∀ g, ReflTransGen (Step L c) g₀ g → GPUProof.Done sig (g, L, c) →
    ∃ y, obs g.mem = some y ∧ R y

variable {L c}

/-- **A clean state at `sig` is a sound grid once its done grids observe alike**, for every
launch, contexts, grid, observation of the memory and relation: if the state `(g₀, L, c)` is
clean at `sig` (`GPUProof.Clean`), the grid `g₀` is sound (`Grid.Sound`) for `obs` and `R` when
its reachable done grids agree on `obs` and each observes a value that meets `R`. Each grid that
`g₀` reaches is a state that `(g₀, L, c)` reaches (`sig_reach_iff`), so it does not fault, race
or break a frozen read; a step at `sig` is a grid step (`sig_step_iff`), so a grid that is not
done steps and every run of grids is finite. -/
theorem Sound.of_clean {g₀ : Grid} {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (h : GPUProof.Clean sig (g₀, L, c)) (hdet : Determinate L c obs g₀)
    (post : ∀ g, ReflTransGen (Step L c) g₀ g → GPUProof.Done sig (g, L, c) →
      ∃ y, obs g.mem = some y ∧ R y) :
    Sound L c g₀ obs R := by
  have up : ∀ {g}, ReflTransGen (Step L c) g₀ g → GPUProof.Reach sig (g₀, L, c) (g, L, c) :=
    fun hg => sig_reach_iff.2 ⟨_, rfl, hg⟩
  refine ⟨fun g hg => h.safe (g, L, c) (up hg), fun g hg => h.raceFree (g, L, c) (up hg),
    fun g hg => h.kept (g, L, c) (up hg), fun g hg hnd => ?_, ?_, hdet, post⟩
  · obtain ⟨s', hs'⟩ := h.progress (g, L, c) (up hg) hnd
    obtain ⟨g', -, hs'⟩ := sig_step_iff.1 hs'
    exact ⟨g', hs'⟩
  · exact Subrelation.accessible (q := fun g' g => Step L c g g')
      (r := InvImage (fun s' s => GPUProof.Step sig s s') fun g => (g, L, c))
      (fun hs => sig_step_iff.2 ⟨_, rfl, hs⟩) (InvImage.accessible _ h.terminates)

/-- **The core's `Done` at a grid**, for every launch, contexts and grid: every thread of the
launch has returned exactly when each thread number below `volume L.grid * volume L.block` is
absent from the grid or has returned (`sigStatus` is `.done` there), as `sig` has no jobs. -/
theorem done_iff {g : Grid} : GPUProof.Done sig (g, L, c) ↔
    ∀ n < volume L.grid * volume L.block, g.threads[n]? = none ∨ g.threads[n]? = some .done := by
  have e : ∀ n, sigStatus g n = .done ↔ g.threads[n]? = none ∨ g.threads[n]? = some .done := by
    intro n
    unfold sigStatus
    split <;> simp_all
  exact ⟨fun h n hn => (e n).1 (h.1 n (List.mem_range.2 hn)),
    fun h => ⟨fun n hn => (e n).2 (h n (List.mem_range.1 hn)), fun j => j.elim⟩⟩

/-- A grid all of whose threads have returned is done, for every launch and contexts: a thread
number of the launch beyond the grid's threads is absent. -/
theorem done_of_all {g : Grid} (h : g.threads.all (· matches .done) = true) :
    GPUProof.Done sig (g, L, c) := by
  rw [Array.all_eq_true] at h
  refine done_iff.2 fun n _ => ?_
  by_cases hn : n < g.threads.size
  · right
    have := h n hn
    rw [Array.getElem?_eq_getElem hn]
    revert this
    cases g.threads[n] <;> simp
  · left
    exact Array.getElem?_eq_none (by omega)

/-- In a done grid with at most the launch's number of threads, thread `n` is absent or has
returned, for every `n`. -/
theorem Done.get {g : Grid} (hs : g.threads.size ≤ volume L.grid * volume L.block)
    (h : GPUProof.Done sig (g, L, c)) (n : Nat) :
    g.threads[n]? = none ∨ g.threads[n]? = some .done := by
  by_cases hn : n < volume L.grid * volume L.block
  · exact done_iff.1 h n hn
  · left
    exact Array.getElem?_eq_none (by omega)

/-- All threads of a done grid with at most the launch's number of threads have returned (the
converse of `Grid.done_of_all`). -/
theorem Done.all {g : Grid} (hs : g.threads.size ≤ volume L.grid * volume L.block)
    (h : GPUProof.Done sig (g, L, c)) : g.threads.all (· matches .done) = true := by
  rw [Array.all_eq_true]
  intro i hi
  have := Done.get hs h i
  rw [Array.getElem?_eq_getElem hi] at this
  rcases this with h' | h'
  · cases h'
  · rw [Option.some.injEq] at h'
    rw [h']

/-- A done grid with at most the launch's number of threads has no step. -/
theorem Done.final {g g' : Grid} (hs : g.threads.size ≤ volume L.grid * volume L.block)
    (h : GPUProof.Done sig (g, L, c)) : ¬ Step L c g g' := by
  rintro ⟨n, h'⟩
  rcases Done.get hs h n with hn | hn <;> simp [advance, fire, hn, pure, Except.pure] at h'

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
    (h : ∀ g, ReflTransGen (Step L c) g₀ g → ¬ GPUProof.Done sig (g, L, c) →
      (∀ (n : Nat) (t : Thread), g.threads[n]? ≠ some (Status.run t)) →
      ∃ n g', g.fire L c n = .ok (some g')) : Progress L c g₀ := by
  intro g hr hd
  by_cases hrun : ∃ (n : Nat) (t : Thread), g.threads[n]? = some (Status.run t)
  · obtain ⟨n, t, ht⟩ := hrun
    match ha : g.advance c n with
    | .ok (some g') => exact ⟨g', n, .inl ha⟩
    | .ok none => exact absurd ha (advance_run ht)
    | .error e => exact (hs g hr (faults_iff.2 ⟨n, e, .inl ha⟩)).elim
  · push Not at hrun
    obtain ⟨n, g', hf⟩ := h g hr hd hrun
    exact ⟨g', n, .inr hf⟩

/-- The grid the evaluator returns is done: all its threads have returned (`Grid.done_of_all`). -/
theorem run_done {fuel : Nat} :
    ∀ {phases : Nat} {g g' : Grid}, g.run L c fuel phases = .ok g' → GPUProof.Done sig (g', L, c)
  | 0, g, g', h => by simp [run] at h
  | phases + 1, g, g', h => by
    simp only [run] at h
    split at h
    · cases h
      exact done_of_all (by assumption)
    · simp only [bind, Except.bind] at h
      split at h
      · cases h
      · split at h
        · cases h
        · split at h
          · exact run_done h
          · split at h
            · cases h
              exact done_of_all (by assumption)
            · cases h

variable {β : Type} {obs : Mem → Option β} {R : β → Prop} {g₀ : Grid}

/-- A sound grid has a final grid, and all its final grids observe one value, which satisfies
`R`. -/
theorem Sound.result (h : Sound L c g₀ obs R) :
    ∃ y, R y ∧ (∃ g, ReflTransGen (Step L c) g₀ g ∧ GPUProof.Done sig (g, L, c)) ∧
      ∀ g, ReflTransGen (Step L c) g₀ g → GPUProof.Done sig (g, L, c) → obs g.mem = some y := by
  suffices ∀ g, Acc (fun g' g => Step L c g g') g → ReflTransGen (Step L c) g₀ g →
      ∃ g', ReflTransGen (Step L c) g₀ g' ∧ GPUProof.Done sig (g', L, c) by
    obtain ⟨g, hr, hd⟩ := this g₀ h.terminates .refl
    obtain ⟨y, hy, hR⟩ := h.post g hr hd
    exact ⟨y, hR, ⟨g, hr, hd⟩, fun g' hr' hd' => (h.determinate g' g hr' hr hd' hd).trans hy⟩
  intro g hg
  induction hg with
  | intro g _ ih =>
    intro hr
    by_cases hd : GPUProof.Done sig (g, L, c)
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
  hs _ .refl (faults_iff.2 ⟨0, .ub msg, .inl (by simp [advance, h, bind, Except.bind])⟩)

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
      Relation.ReflTransGen (Grid.Step L c) g g' ∧ GPUProof.Done sig (g', L, c) ∧
        obs g'.mem = some y) ∧ R y := by
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

/-- The launch of one thread is valid: `launch2_valid` at `launch2 1 1 1 1`. -/
theorem Launch.valid_one : Launch.one.Valid := launch2_valid (by decide)

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
    simp only [volume, Launch.one, launch2, Nat.mul_one, List.range_one, List.foldlM_cons,
      List.foldlM_nil, shared, Mem.allocNext, h0]
    rfl, by exact Grid.not_safe_one rfl⟩

end MojoProof.Sem
