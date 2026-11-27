import MojoProof.Sym.Canon

/-!
# The canonical run at the phase level: blocks, their barriers, warps

Every result here is for every program, launch, contexts, thread and memory.

The canonical run at the phase level (`PhaseRun`) takes the blocks of threads in turn. A block's
run (`BlockRun`) takes its phases in turn: in each phase but the last its warps run in turn
(`CanonWait`), each by its run to its next barrier (`WarpWait`: its lanes in turn to their waits,
its shuffles fired between, as `WarpRun` does), then the block's barrier fires (`BlockBar`,
`Grid.fire_barrier` at the block's first thread), resuming every thread of the block with no
value and logging the block's `.barrier`; in the last phase the block's warps run to their ends
(`CanonRun`, the one-level run, over the block's warps `blockWarps`). Each block has its own
number of phases, and each warp its own number of shuffles in each phase.

* `blockWarps_threads`: the threads of a block's warps are the threads of the block.
* `BlockBar.fire`: a block whose threads all wait at a barrier (`BlockBar`) takes one grid step
  to the threads resumed and the block's `.barrier` logged.
* `WarpWait.grid`, `CanonWait.grid`, `BlockRun.grid`, `PhaseRun.grid`: the runs are runs of
  grid steps, from every grid whose threads run the run's threads, to the grid with the threads
  at their waits (a warp's, the block's warps') or done (a block's, the blocks'). `PhaseRun.done`:
  the run of every block reaches a done grid (the core's `Done` at `sig`), with the trace the
  run's events put in front of the first memory's (`PhaseRun.trace`, each barrier's event in its
  place).
* `PhaseRun.start_sound`: a start whose threads have a canonical run at the phase level is sound
  (`Grid.Sound`) when the last memory's trace has no race (in the premises of `racy_iff`), keeps
  the promise of `!invariant.load` and has an observation meeting `R` (`Grid.start_done_sound`).
* `WarpWait.of_inv`, `CanonWait.of_inv`, `CanonWait.of_merge`, `BlockRun.of_inv`,
  `PhaseRun.of_inv`: the runs from predicates on each lane's runs and each phase's shuffles (as
  `WarpRun.of_inv`), on each warp's runs to its barrier, on each phase of a block (its warps' runs
  and its barrier) and on each block's run. The waits' statuses are the runs': a warp's lanes wait
  at statuses of a predicate, each lane at the status its run reaches. Warps in turn wait at
  statuses fixed before the run (`CanonWait.of_inv`), or, for distinct warps at lane 0 of blocks
  of at least one thread, at the statuses each warp's run reaches on its threads
  (`CanonWait.of_merge`; `WarpWait.congr`, `CanonWait.congr`: only the statuses of the warps'
  threads matter). `BlockBar.of_waits`: the barrier's checks from each thread's wait.
* `PhaseRun.of_canon`: the one-level canonical run over every warp (`CanonRun`, `warps`) is the
  case of one phase per block (`warps_blocks`, `CanonRun.append`). So the one-level run's
  `CanonRun.done`, `CanonRun.start_done` and `CanonRun.start_sound` (a start whose threads have a
  canonical run is sound, Theorem 0 at `sig`) are the phase level's at that run.
* `BlockRun.of_turns`: a block of two phases whose threads run in order, from memories indexed by
  thread, over warps that cover the block (`warpsCover`); its warps' runs by `WarpWait.of_turns`,
  `WarpRun.of_turns`, `CanonWait.of_turns` and `CanonRun.of_turns`.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem
open GPUProof

/-- The threads of block of threads `b` in launch `L`: thread `b * volume L.block + j` for each
`j < volume L.block`, in order (the threads `Grid.fire_barrier` resumes). -/
def blockThreads (L : Launch) (b : Nat) : List Nat :=
  (List.range (volume L.block)).map (b * volume L.block + ·)

/-- The first threads of the warps of block of threads `b` in launch `L`: thread
`b * volume L.block + j` for each `j < volume L.block` with `j % 32 = 0`, in order. -/
def blockWarps (L : Launch) (b : Nat) : List Nat :=
  ((List.range (volume L.block)).filter fun j => j % 32 = 0).map (b * volume L.block + ·)

/-- The first thread of thread `n`'s warp is in `n`'s block, for blocks of `s > 0` threads. -/
theorem warp_base_div {s : Nat} (hs : 0 < s) (n : Nat) : (n - n % s % 32) / s = n / s := by
  have h1 := Nat.div_add_mod n s
  have h3 := Nat.mod_lt n hs
  generalize n / s = q at h1 ⊢
  generalize n % s = r at h1 h3 ⊢
  subst h1
  have h2 := Nat.mod_le r 32
  rw [show s * q + r - r % 32 = s * q + (r - r % 32) by omega, Nat.mul_add_div hs,
    Nat.div_eq_of_lt (show r - r % 32 < s by omega), Nat.add_zero]

/-- **A block's warps**: for every launch `L` with blocks of `volume L.block > 0` threads and
block `b`, thread `k` is the first thread of one of block `b`'s warps (`blockWarps`) exactly when
it is in block `b` at lane 0 of its warp. -/
theorem mem_blockWarps {L : Launch} {b k : Nat} (hs : 0 < volume L.block) :
    k ∈ blockWarps L b ↔ k / volume L.block = b ∧ k % volume L.block % 32 = 0 := by
  simp only [blockWarps, List.mem_map, List.mem_filter, List.mem_range, decide_eq_true_eq]
  generalize volume L.block = s at hs ⊢
  constructor
  · rintro ⟨j, ⟨hj, hj32⟩, rfl⟩
    rw [Nat.mul_comm b s, Nat.mul_add_div hs, Nat.div_eq_of_lt hj, Nat.add_zero, Nat.mul_add_mod,
      Nat.mod_eq_of_lt hj]
    exact ⟨rfl, hj32⟩
  · rintro ⟨h1, h2⟩
    exact ⟨k % s, ⟨Nat.mod_lt _ hs, h2⟩, by rw [← h1]; exact Nat.div_add_mod' k s⟩

/-- **A block's warps' threads are the block's**: for every launch `L` with blocks of
`volume L.block > 0` threads and block `b`, thread `n` is one of the threads of block `b`'s warps
exactly when it is in block `b` (`warpThreads_iff`, `mem_blockWarps`). -/
theorem blockWarps_threads {L : Launch} {b n : Nat} (hs : 0 < volume L.block) :
    n ∈ (blockWarps L b).flatMap (warpThreads L) ↔ n / volume L.block = b := by
  rw [List.mem_flatMap]
  constructor
  · rintro ⟨k, hk, hn⟩
    obtain ⟨h1, h2⟩ := (mem_blockWarps hs).1 hk
    rw [← (warpThreads_iff hs h2).1 hn, warp_base_div hs] at h1
    exact h1
  · intro h
    have hb : (n - n % volume L.block % 32) % volume L.block % 32 = 0 := by
      rw [warp_base_mod hs]
      omega
    exact ⟨_, (mem_blockWarps hs).2 ⟨(warp_base_div hs n).trans h, hb⟩,
      (warpThreads_iff hs hb).2 rfl⟩

/-- A block's threads are the threads of its warps, for every launch with blocks of
`volume L.block > 0` threads and block (`blockWarps_threads`, `mem_block`). -/
theorem mem_blockThreads {L : Launch} {b n : Nat} (hs : 0 < volume L.block) :
    n ∈ (blockWarps L b).flatMap (warpThreads L) ↔ n ∈ blockThreads L b :=
  (blockWarps_threads hs).trans (mem_block hs).symm

/-- The first threads of a block's warps are distinct, for every launch and block. -/
theorem blockWarps_nodup (L : Launch) (b : Nat) : (blockWarps L b).Nodup :=
  (List.nodup_range.filter _).map fun _ _ => Nat.add_left_cancel

/-- Setting the entries of two lists with the same members, each `n` to `s n`, gives the same
array, for every statuses `s` and array (`foldl_set_getElem?`). -/
theorem foldl_set_congr (s : Nat → Status) {ns ns' : List Nat} (h : ∀ j, j ∈ ns ↔ j ∈ ns')
    (ts : Array Status) :
    ns.foldl (fun ts n => ts.set! n (s n)) ts = ns'.foldl (fun ts n => ts.set! n (s n)) ts := by
  refine Array.ext_getElem? fun j => ?_
  rw [foldl_set_getElem?, foldl_set_getElem?]
  by_cases hj : j ∈ ns
  · simp only [hj, (h j).1 hj, ↓reduceIte]
  · simp only [hj, mt (h j).2 hj, ↓reduceIte]

/-- **A block's barrier**, for launch `L`, block of threads `b`, statuses `s` and threads `u`:
every thread `n` of block `b` (`n / volume L.block = b`) is at `s n`, a wait from thread `u n` at
a barrier call with argument `x n` and callee `d n`; every `x n` is one number `bar < 16`; and
every `u n` is at the instruction the block's first thread is at. These are `Grid.fire`'s checks
(`Grid.fire_barrier`), so the resumes and the event are the semantics'. -/
def BlockBar (L : Launch) (b : Nat) (s : Nat → Status) (u : Nat → Thread) : Prop :=
  ∃ (x : Nat → Val) (d : Nat → Func) (bar : Nat), bar < 16 ∧
    ∀ n, n / volume L.block = b → s n = .wait (u n) .barrier [x n] (d n) ∧
      (x n).word? = some bar ∧ (u n).at = (u (b * volume L.block)).at

/-- **A block's barrier from its threads' waits**: for every launch `L` with blocks of
`volume L.block > 0` threads, block `b`, number `bar < 16`, instruction `a` and statuses `s`: if
every thread `n` of block `b` is at `s n`, a wait from some thread at `a` at a barrier call with
one argument, whose number is `bar`, then the barrier's checks hold (`BlockBar`) at the threads
the waits are from. -/
theorem BlockBar.of_waits {L : Launch} {b bar : Nat} {s : Nat → Status}
    {a : Option (String × Nat × Nat)} (hs : 0 < volume L.block) (hbar : bar < 16)
    (h : ∀ n, n / volume L.block = b → ∃ u x d, s n = .wait u .barrier [x] d ∧
      x.word? = some bar ∧ u.at = a) : ∃ u, BlockBar L b s u := by
  have hb : b * volume L.block / volume L.block = b := Nat.mul_div_cancel _ hs
  obtain ⟨u₀, x₀, d₀, -⟩ := h _ hb
  have : ∀ n, ∃ u x d, n / volume L.block = b → s n = .wait u .barrier [x] d ∧
      x.word? = some bar ∧ u.at = a := fun n =>
    if hn : n / volume L.block = b then
      let ⟨u, x, d, e⟩ := h n hn
      ⟨u, x, d, fun _ => e⟩
    else ⟨u₀, x₀, d₀, fun h => absurd h hn⟩
  choose u x d hu using this
  refine ⟨u, x, d, bar, hbar, fun n hn => ?_⟩
  obtain ⟨e, hx, ha⟩ := hu n hn
  exact ⟨e, hx, ha.trans (hu _ hb).2.2.symm⟩

/-- **A block's barrier fires**: for every launch `L` with blocks of `volume L.block > 0`
threads, contexts `c`, block `b`, statuses `s` and threads `u` with `BlockBar L b s u`, and grid
`g` in which each thread `n` of block `b` is at `s n`: the barrier fired by the block's first
thread is a grid step to the grid with each thread `n` of the block running `(u n).resume none`,
every other thread unchanged, and the block's `.barrier` logged (`Grid.fire_barrier`). -/
theorem BlockBar.fire {L : Launch} {c : Nat → Ctx} {b : Nat} {s : Nat → Status}
    {u : Nat → Thread} (hs : 0 < volume L.block) (h : BlockBar L b s u) {g : Grid}
    (hg : ∀ n, n / volume L.block = b → g.threads[n]? = some (s n)) :
    Grid.Step L c g ⟨(blockThreads L b).foldl (fun ts n => ts.set! n (.run ((u n).resume none)))
      g.threads, g.mem.log (.barrier b)⟩ := by
  obtain ⟨x, d, bar, hbar, hw⟩ := h
  have hb : ∀ k < volume L.block, (b * volume L.block + k) / volume L.block = b := fun k hk =>
    (mem_block hs).1 (List.mem_map_of_mem (List.mem_range.2 hk))
  exact ⟨b * volume L.block, .inr (Grid.fire_barrier (c := c) (u := u) (x := x) (d := d) hs hbar
    fun k hk => by
      obtain ⟨e, hx, hat⟩ := hw _ (hb k hk)
      rw [hg _ (hb k hk), e]
      exact ⟨rfl, hx, hat⟩)⟩

/-- **A warp's shuffle fires**: for every launch `L` with blocks of `volume L.block > 0` threads,
contexts `c`, warp's first thread `k`, lane-indexed statuses `s`, memory `m`, threads `u` and
deliveries `r` with `WarpShfl L c k s m u r`, and statuses `ts` in which each of the warp's
threads `n` is at `s (n - k)`: the shuffle fired by thread `k` is a grid step on memory `m` to
each of the warp's threads `n` running `(u (n - k)).resume (r (n - k))`, every other thread
unchanged (`Grid.fire_shfl`). -/
theorem WarpShfl.fire {L : Launch} {c : Nat → Ctx} {k : Nat} {s : Nat → Status} {m : Mem}
    {u : Nat → Thread} {r : Nat → Option Val} (hs : 0 < volume L.block)
    (hk : k % volume L.block % 32 = 0) (h : WarpShfl L c k s m u r) {ts : Array Status}
    (hg : ∀ n ∈ warpThreads L k, ts[n]? = some (s (n - k))) :
    Grid.Step L c ⟨ts, m⟩ ⟨(warpThreads L k).foldl
      (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k))))) ts, m⟩ := by
  obtain ⟨mode, M, A, B, C, b, cl, d, hf⟩ := h
  have hF := Grid.fire_shfl (L := L) (c := c) (n := k) (g := ⟨ts, m⟩) (mode := mode) (u := u)
    (M := M) (A := A) (B := B) (C := C) (b := b) (cl := cl) (d := d) (r := r) hs fun j hj => by
      obtain ⟨e, hM, hB, hC, hat, hr⟩ := hf j hj
      have hn : k + j ∈ warpThreads L k := List.mem_map_of_mem hj
      rw [hk, Nat.sub_zero]
      refine ⟨?_, hM, hB, hC, hat, hr⟩
      rw [hg _ hn, Nat.add_sub_cancel_left, e]
  rw [hk, Nat.sub_zero] at hF
  have e2 : (warpLanes L k).foldl (fun ts j => ts.set! (k + j) (.run ((u j).resume (r j)))) ts =
      (warpThreads L k).foldl (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k))))) ts :=
    by simp only [warpThreads, List.foldl_map, Nat.add_sub_cancel_left]
  dsimp only at hF
  rw [e2] at hF
  exact ⟨k, .inr hF⟩

/-- A warp's run to its waits, for launch `L`, contexts `c` and warp's first thread `k`, from the
threads `t` on memory `m` to the statuses `s` on memory `m'`, with the events `Es` its lanes' runs
put in front of the trace, in the order they ran: its lanes in turn to their waits at `s`, or its
lanes in turn to a shuffle's waits, the warp's shuffle, and the warp's run to its waits from the
resumed lanes (`WarpRun` with waits in place of the ends). -/
inductive WarpWait (L : Launch) (c : Nat → Ctx) (k : Nat) :
    (Nat → Thread) → Mem → List (List Event) → (Nat → Status) → Mem → Prop
  /-- The warp's threads in turn to their waits, thread `n` at `s n`. -/
  | waits {t : Nat → Thread} {s : Nat → Status} {m m' : Mem} {Es : List (List Event)} :
      Seq.ToWait c t s (warpThreads L k) m Es m' → WarpWait L c k t m Es s m'
  /-- The warp's threads in turn to their waits, lane `j` at `s j`, on `m₁`; the shuffle from
  there resumes lane `j` from `u j` with `r j`; then the warp's run to its waits at `s'` from the
  resumed lanes. -/
  | shfl {t : Nat → Thread} {s : Nat → Status} {m m₁ m' : Mem} {Es Es' : List (List Event)}
      {u : Nat → Thread} {r : Nat → Option Val} {s' : Nat → Status} :
      Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m₁ → WarpShfl L c k s m₁ u r →
      WarpWait L c k (fun n => (u (n - k)).resume (r (n - k))) m₁ Es' s' m' →
      WarpWait L c k t m (Es ++ Es') s' m'

/-- The warps of first threads `ks` in turn to their waits, for launch `L` and contexts `c`, from
the threads `t` on memory `m` to the statuses `s` on memory `m'`, with the events `Es` the lanes'
runs put in front of the trace: each warp by its run to its waits (`WarpWait`) from `t`. -/
inductive CanonWait (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) (s : Nat → Status) :
    List Nat → Mem → List (List Event) → Mem → Prop
  /-- No warps. -/
  | nil (m : Mem) : CanonWait L c t s [] m [] m
  /-- Warp `k`'s run to its waits, then the other warps'. -/
  | cons {k : Nat} {ks : List Nat} {m m₁ m' : Mem} {Es Es' : List (List Event)} :
      WarpWait L c k t m Es s m₁ → CanonWait L c t s ks m₁ Es' m' →
      CanonWait L c t s (k :: ks) m (Es ++ Es') m'

/-- A block's run, for launch `L`, contexts `c` and block of threads `b`, from the threads `t` on
memory `m` to memory `m'`, with the events `Es` its runs put in front of the trace, each barrier's
event in its place: its warps in turn to their ends (`CanonRun` over `blockWarps`), or its warps in
turn to their waits at `s` (`CanonWait`), the block's barrier there (`BlockBar`), and the block's
run from the threads resumed, on the memory with the block's `.barrier` logged. -/
inductive BlockRun (L : Launch) (c : Nat → Ctx) (b : Nat) :
    (Nat → Thread) → Mem → List (List Event) → Mem → Prop
  /-- The block's last phase: its warps in turn to their ends. -/
  | ends {t : Nat → Thread} {m m' : Mem} {Es : List (List Event)} :
      CanonRun L c t (blockWarps L b) m Es m' → BlockRun L c b t m Es m'
  /-- A phase: the block's warps in turn to their waits at `s` on `m₁`, the barrier from there
  resuming thread `n` from `u n`, then the block's run from the resumed threads. -/
  | bar {t : Nat → Thread} {s : Nat → Status} {u : Nat → Thread} {m m₁ m' : Mem}
      {Es Es' : List (List Event)} :
      CanonWait L c t s (blockWarps L b) m Es m₁ → BlockBar L b s u →
      BlockRun L c b (fun n => (u n).resume none) (m₁.log (.barrier b)) Es' m' →
      BlockRun L c b t m (Es ++ [.barrier b] :: Es') m'

/-- The canonical run at the phase level of the blocks of threads `bs`, for launch `L` and
contexts `c`, from the threads `t` on memory `m` to memory `m'`, with the events `Es` the runs
put in front of the trace: the blocks in turn, each by its run (`BlockRun`) from `t`. -/
inductive PhaseRun (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) :
    List Nat → Mem → List (List Event) → Mem → Prop
  /-- No blocks. -/
  | nil (m : Mem) : PhaseRun L c t [] m [] m
  /-- Block `b`'s run, then the other blocks'. -/
  | cons {b : Nat} {bs : List Nat} {m m₁ m' : Mem} {Es Es' : List (List Event)} :
      BlockRun L c b t m Es m₁ → PhaseRun L c t bs m₁ Es' m' →
      PhaseRun L c t (b :: bs) m (Es ++ Es') m'

/-- **A warp's run to its waits depends on the statuses of its threads only**: for every launch,
contexts, warp `k`, threads, memories and events, a warp's run to its waits at `s` (`WarpWait`) is
one at every `s'` that agrees with `s` on the warp's threads (`warpThreads L k`). -/
theorem WarpWait.congr {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} {s s' : Nat → Status} (h : WarpWait L c k t m Es s m')
    (hs : ∀ n ∈ warpThreads L k, s n = s' n) : WarpWait L c k t m Es s' m' := by
  revert hs
  induction h with
  | waits hr =>
    exact fun hs => .waits (Turns.imp hr (P := fun _ => True)
      (fun n hn _ _ h _ => ⟨hs n hn ▸ h, trivial⟩) trivial).1
  | shfl hw hf _ ih => exact fun hs => .shfl hw hf (ih hs)

/-- **Warps in turn to their waits depend on the statuses of their threads only**: for every
launch, contexts, threads, warps `ks`, memories and events, warps in turn to their waits at `s`
(`CanonWait`) are warps in turn to their waits at every `s'` that agrees with `s` on the threads
of the warps of `ks` (`WarpWait.congr`). -/
theorem CanonWait.congr {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s s' : Nat → Status}
    {ks : List Nat} {m m' : Mem} {Es : List (List Event)} (h : CanonWait L c t s ks m Es m')
    (hs : ∀ k ∈ ks, ∀ n ∈ warpThreads L k, s n = s' n) : CanonWait L c t s' ks m Es m' := by
  revert hs
  induction h with
  | nil m => exact fun _ => .nil m
  | cons hw _ ih =>
    exact fun hs => .cons (hw.congr (hs _ List.mem_cons_self))
      (ih fun k hk => hs k (List.mem_cons_of_mem _ hk))

/-- **Threads in turn, then others**: for every family of runs `R`, threads `ns` and `ns'`,
memories and events, threads `ns` in turn (`Turns`) from `m` to `m₁` and then threads `ns'` in
turn from `m₁` to `m'` are threads `ns ++ ns'` in turn from `m` to `m'`. -/
theorem Turns.append {R : Nat → Mem → Mem → Prop} {ns ns' : List Nat} {m m₁ m' : Mem}
    {Es Es' : List (List Event)} (h : Turns R ns m Es m₁) (h' : Turns R ns' m₁ Es' m') :
    Turns R (ns ++ ns') m (Es ++ Es') m' := by
  induction h with
  | nil => exact h'
  | cons hr e _ ih => exact .cons hr e (ih h')

/-! ## Traces -/

/-- **A warp's trace to its waits**: for every launch, contexts, warp, threads, statuses and
memories, a warp's run to its waits (`WarpWait`) puts its events, the last lane's run's in front,
in front of the first memory's trace (`Turns.trace`; a shuffle logs none). -/
theorem WarpWait.trace {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} {s : Nat → Status} (h : WarpWait L c k t m Es s m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | waits hr => exact Turns.trace hr
  | shfl hw _ _ ih =>
    rw [ih, Turns.trace hw, List.reverse_append, List.flatten_append, List.append_assoc]

/-- **The trace of warps to their waits**: for every launch, contexts, threads, statuses, warps and
memories, `CanonWait` puts its events, the last lane's run's in front, in front of the first
memory's trace (`WarpWait.trace`). -/
theorem CanonWait.trace {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status}
    {ks : List Nat} {m m' : Mem} {Es : List (List Event)} (h : CanonWait L c t s ks m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | nil => rfl
  | cons hw _ ih =>
    rw [ih, hw.trace, List.reverse_append, List.flatten_append, List.append_assoc]

/-- **A block's trace**: for every launch, contexts, block, threads and memories, a block's run
(`BlockRun`) puts its events, the last run's in front and each barrier's event in its place, in
front of the first memory's trace (`CanonRun.trace`, `CanonWait.trace`, `Mem.log`). -/
theorem BlockRun.trace {L : Launch} {c : Nat → Ctx} {b : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} (h : BlockRun L c b t m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | ends hc => exact hc.trace
  | bar hw _ _ ih =>
    rw [ih]
    simp only [Mem.log, hw.trace, List.reverse_append, List.reverse_cons, List.flatten_append,
      List.flatten_cons, List.append_assoc, List.cons_append, List.nil_append]

/-- **The trace of the canonical run at the phase level**: for every launch, contexts, threads,
blocks and memories, `PhaseRun` puts its events, the last run's in front and each barrier's event
in its place, in front of the first memory's trace (`BlockRun.trace`). -/
theorem PhaseRun.trace {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {bs : List Nat}
    {m m' : Mem} {Es : List (List Event)} (h : PhaseRun L c t bs m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | nil => rfl
  | cons hb _ ih =>
    rw [ih, hb.trace, List.reverse_append, List.flatten_append, List.append_assoc]

/-! ## Grids -/

/-- **A warp's run to its waits, in a grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, warp's first thread `k`, threads `t`, statuses `s`,
memories and grid `g` in which each of the warp's threads `n` runs `t n` and whose memory is `m`:
a warp's run to its waits (`WarpWait`) from `t` on `m` to `s` on `m'` is a run of grid steps from
`g` to the grid with each of the warp's threads `n` at `s n`, every other thread unchanged, and
memory `m'` (`Seq.ToWait.grid`, `WarpShfl.fire`). -/
theorem WarpWait.grid {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} {s : Nat → Status} (hs : 0 < volume L.block)
    (hk : k % volume L.block % 32 = 0) (h : WarpWait L c k t m Es s m') :
    ∀ {g : Grid}, (∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(warpThreads L k).foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩ := by
  have hd := warpThreads_nodup L k
  induction h with
  | waits hr => exact fun hg hm => Seq.ToWait.grid hr hd hg hm
  | @shfl t s m m₁ m' Es Es' u r s' hw hf _ ih =>
    intro g hg hm
    obtain ⟨_, hp₁⟩ := Seq.ToWait.grid (L := L) hw hd hg hm
    have hF := hf.fire (c := c) hs hk
      (ts := (warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads)
      fun n hn => by simp only [foldl_set_getElem?, hn, ↓reduceIte, hg _ hn, Option.map_some]
    obtain ⟨_, hp₃⟩ := ih (g := ⟨(warpThreads L k).foldl
      (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k)))))
        ((warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads), m₁⟩)
      (fun n hn => by
        simp only [foldl_set_getElem?, hn, ↓reduceIte, hg _ hn, Option.map_some]) rfl
    have e3 : (warpThreads L k).foldl (fun ts n => ts.set! n (s' n)) ((warpThreads L k).foldl
        (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k)))))
          ((warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads)) =
        (warpThreads L k).foldl (fun ts n => ts.set! n (s' n)) g.threads := by
      refine Array.ext_getElem? fun i => ?_
      by_cases hi : i ∈ warpThreads L k
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
        cases g.threads[i]? <;> rfl
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
    rw [e3] at hp₃
    exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans
      (.head hF (Path.exists_iff.1 ⟨_, hp₃⟩)))

/-- **Warps in turn to their waits, in a grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, threads `t`, statuses `s`, distinct warps' first
threads `ks`, memories and grid `g` in which each thread `n` of each warp of `ks` runs `t n` and
whose memory is `m`: `CanonWait` from `t` on `m` to `s` on `m'` is a run of grid steps from `g`
to the grid with each of the warps' threads `n` at `s n`, every other thread unchanged, and
memory `m'` (`WarpWait.grid` for each warp in turn, `warps_grid_cons`). -/
theorem CanonWait.grid {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status}
    {ks : List Nat} {m m' : Mem} {Es : List (List Event)} (hs : 0 < volume L.block)
    (h : CanonWait L c t s ks m Es m') :
    ∀ {g : Grid}, ks.Nodup → (∀ k ∈ ks, k % volume L.block % 32 = 0) →
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(ks.flatMap (warpThreads L)).foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩ := by
  induction h with
  | nil m => exact fun _ _ _ hm => by subst hm; exact ⟨0, .nil _⟩
  | cons hw _ ih => exact warps_grid_cons hs (fun hk {_} => hw.grid hs hk) ih

/-- **A block's run, in a grid.** For every launch `L` with blocks of `volume L.block > 0`
threads, contexts `c`, block `b`, threads `t`, memories and grid `g` in which each thread `n` of
block `b` runs `t n` and whose memory is `m`: a block's run (`BlockRun`) from `t` on `m` to `m'`
is a run of grid steps from `g` to the grid with the block's threads done, every other thread
unchanged, and memory `m'` (`CanonRun.grid` and `CanonWait.grid` on the block's warps, whose
threads are the block's, `blockWarps_threads`; `BlockBar.fire` between the phases). -/
theorem BlockRun.grid {L : Launch} {c : Nat → Ctx} {b : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} (hs : 0 < volume L.block) (h : BlockRun L c b t m Es m') :
    ∀ {g : Grid}, (∀ n, n / volume L.block = b → g.threads[n]? = some (.run (t n))) →
      g.mem = m → ∃ i, Path (Grid.Step L c) i g
        ⟨(blockThreads L b).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩ := by
  have hk : ∀ k ∈ blockWarps L b, k % volume L.block % 32 = 0 := fun k hk =>
    ((mem_blockWarps hs).1 hk).2
  have hw : ∀ {g : Grid} {t : Nat → Thread},
      (∀ n, n / volume L.block = b → g.threads[n]? = some (.run (t n))) →
      ∀ k ∈ blockWarps L b, ∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n)) :=
    fun hg k hk n hn => hg n ((blockWarps_threads hs).1 (List.mem_flatMap.2 ⟨k, hk, hn⟩))
  induction h with
  | ends hc =>
    intro g hg hm
    obtain ⟨i, hp⟩ := hc.grid hs (blockWarps_nodup L b) hk (hw hg) hm
    rw [foldl_set_congr (fun _ => .done) fun _ => mem_blockThreads hs] at hp
    exact ⟨i, hp⟩
  | @bar t s u m m₁ m' Es Es' hc hb _ ih =>
    intro g hg hm
    obtain ⟨_, hp₁⟩ := hc.grid hs (blockWarps_nodup L b) hk (hw hg) hm
    rw [foldl_set_congr s fun _ => mem_blockThreads hs] at hp₁
    have hF := hb.fire (c := c) hs (g := ⟨(blockThreads L b).foldl (fun ts n => ts.set! n (s n))
      g.threads, m₁⟩) fun n hn => by
        have hn' : n ∈ blockThreads L b := (mem_block hs).2 hn
        simp only [foldl_set_getElem?, hn', ↓reduceIte, hg n hn, Option.map_some]
    obtain ⟨_, hp₃⟩ := ih (g := ⟨(blockThreads L b).foldl
      (fun ts n => ts.set! n (.run ((u n).resume none)))
        ((blockThreads L b).foldl (fun ts n => ts.set! n (s n)) g.threads),
      m₁.log (.barrier b)⟩) (fun n hn => by
        have hn' : n ∈ blockThreads L b := (mem_block hs).2 hn
        simp only [foldl_set_getElem?, hn', ↓reduceIte, hg n hn, Option.map_some])
      rfl
    have e3 : (blockThreads L b).foldl (fun ts n => ts.set! n .done) ((blockThreads L b).foldl
        (fun ts n => ts.set! n (.run ((u n).resume none)))
          ((blockThreads L b).foldl (fun ts n => ts.set! n (s n)) g.threads)) =
        (blockThreads L b).foldl (fun ts n => ts.set! n .done) g.threads := by
      refine Array.ext_getElem? fun i => ?_
      by_cases hi : i ∈ blockThreads L b
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
        cases g.threads[i]? <;> rfl
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
    rw [e3] at hp₃
    exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans
      (.head hF (Path.exists_iff.1 ⟨_, hp₃⟩)))

/-- **The canonical run at the phase level, in a grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, threads `t`, distinct blocks `bs`, memories and grid
`g` in which each thread `n` of the blocks of `bs` runs `t n` and whose memory is `m`: the
canonical run at the phase level (`PhaseRun`) from `t` on `m` to `m'` is a run of grid steps from
`g` to the grid with the blocks' threads done, every other thread unchanged, and memory `m'`
(`BlockRun.grid` for each block in turn). -/
theorem PhaseRun.grid {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {bs : List Nat}
    {m m' : Mem} {Es : List (List Event)} (hs : 0 < volume L.block)
    (h : PhaseRun L c t bs m Es m') :
    ∀ {g : Grid}, bs.Nodup → (∀ n, n / volume L.block ∈ bs → g.threads[n]? = some (.run (t n))) →
      g.mem = m → ∃ i, Path (Grid.Step L c) i g
        ⟨(bs.flatMap (blockThreads L)).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩ := by
  induction h with
  | nil m =>
    intro g _ _ hm
    subst hm
    exact ⟨0, .nil _⟩
  | @cons b bs m m₁ m' Es Es' hb _ ih =>
    intro g hd hg hm
    obtain ⟨_, hp₁⟩ := hb.grid hs (g := g) (fun n hn => hg n (hn ▸ List.mem_cons_self)) hm
    obtain ⟨_, hp₂⟩ := ih (g := ⟨(blockThreads L b).foldl (fun ts n => ts.set! n .done)
        g.threads, m₁⟩) (List.nodup_cons.1 hd).2 (fun n hn => by
        have hn' : n ∉ blockThreads L b := fun hn' =>
          (List.nodup_cons.1 hd).1 ((mem_block hs).1 hn' ▸ hn)
        simp only [foldl_done_getElem?, hn', ↓reduceIte]
        exact hg n (List.mem_cons_of_mem _ hn)) rfl
    rw [List.flatMap_cons, List.foldl_append]
    exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans (Path.exists_iff.1 ⟨_, hp₂⟩))

/-- **The canonical run at the phase level to a done grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, threads `t`, number `B` of blocks, memory `m'` and grid
`g` of `B * volume L.block` threads in which each thread `n` runs `t n`: the canonical run at the
phase level (`PhaseRun`) of blocks `0` to `B - 1` from `t` on `g`'s memory to `m'` is a run of
grid steps from `g` to a done grid (the core's `Done` at `sig`) with memory `m'`, whose trace is
the run's events, the last run's in front, in front of `g`'s memory's (`PhaseRun.grid`,
`Grid.done_foldl`: every thread `j` is one of block `j / volume L.block`'s; `PhaseRun.trace`). -/
theorem PhaseRun.done {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {g : Grid} {B : Nat}
    {m' : Mem} {Es : List (List Event)} (hs : 0 < volume L.block)
    (hN : g.threads.size = B * volume L.block) (h : PhaseRun L c t (List.range B) g.mem Es m')
    (hg : ∀ n < g.threads.size, g.threads[n]? = some (.run (t n))) :
    ∃ z, (∃ i, Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ g.mem.trace := by
  refine ⟨_, h.grid hs List.nodup_range (fun n hn => hg n ?_) rfl,
    Grid.done_foldl _ fun j hj => ?_, rfl, h.trace⟩
  · rw [hN]
    exact (Nat.div_lt_iff_lt_mul hs).1 (List.mem_range.1 hn)
  · rw [hN] at hj
    exact List.mem_flatMap.2 ⟨j / volume L.block,
      List.mem_range.2 ((Nat.div_lt_iff_lt_mul hs).2 hj), (mem_block hs).2 rfl⟩

/-- **A start with a canonical run at the phase level reaches a done grid.** For every program,
kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads, arguments, memory, address
choice and oracle whose start (`Grid.start`) gives grid `g₀` and contexts `c`: if the threads of
`g₀` (`Grid.thread`) on `g₀`'s memory have a canonical run at the phase level (`PhaseRun`) over
every block (`List.range (volume L.grid)`) to `m'`, then `g₀` steps (`Grid.Step`) to a done grid
(`GPUProof.Done` at `sig`) with memory `m'`: `PhaseRun.done` with `Grid.start_threads` and
`Grid.start_size`. -/
theorem PhaseRun.start_done {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hs : 0 < volume L.block)
    {Es : List (List Event)} {m' : Mem}
    (hc : PhaseRun L c (Grid.thread g₀) (List.range (volume L.grid)) g₀.mem Es m') :
    ∃ z, (∃ i, Path (Grid.Step L c) i g₀ z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' :=
  let ⟨z, hp, hd, hm, _⟩ := PhaseRun.done hs (Grid.start_size h) hc (Grid.start_threads h)
  ⟨z, hp, hd, hm⟩

/-- The checks on the last memory `m'` of a run of launch `L` that make its start sound, for every
observation `obs` and relation `R`: `m'`'s trace has no data race (the core's `racy` at `sig`)
when it has the premises of `racy_iff`, it keeps the promise of `!invariant.load` (the core's
`GPUProof.kept` at `sig`), and `obs m'` is some `y` with `R y` (`CanonRun.start_sound`'s
premises past the run, which it passes as these). -/
def EndChecks {β : Type} (L : Launch) (obs : Mem → Option β) (R : β → Prop) (m' : Mem) : Prop :=
  ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
      a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
    GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
  GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧ ∃ y, obs m' = some y ∧ R y

/-- **A start with a canonical run at the phase level, sound.** For every program, kernel `fn`,
launch `L` with blocks of `volume L.block > 0` threads, arguments, address choice and oracle
whose start (`Grid.start`) gives grid `g₀` and contexts `c`, on a caller's memory `m` meeting
`Mem.BytesIn`, and every observation `obs` that reads only the blocks: if the threads of `g₀`
(`Grid.thread`) on `g₀`'s memory have a canonical run at the phase level (`PhaseRun`) over every
block to `m'`, and `m'` passes the checks of `EndChecks` (no data race when the trace has the
premises of `racy_iff`, the promise of `!invariant.load` kept, `obs m' = some y` with `R y`),
then `g₀` is sound (`Grid.Sound`): `PhaseRun.start_done`, then `Grid.start_done_sound`. -/
theorem PhaseRun.start_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (hs : 0 < volume L.block)
    {Es : List (List Event)} {m' : Mem}
    (hc : PhaseRun L c (Grid.thread g₀) (List.range (volume L.grid)) g₀.mem Es m')
    (he : EndChecks L obs R m') : Grid.Sound L c g₀ obs R := by
  obtain ⟨z, ⟨_, hp⟩, hd, rfl⟩ := PhaseRun.start_done h hs hc
  obtain ⟨hr, hk, y, hy, hR⟩ := he
  exact Grid.start_done_sound h hm hO hp hd hr hk hy hR

/-! ## Runs by invariants -/

/-- **A warp's run to its waits by invariants.** For every launch `L`, contexts `c`, warp's first
thread `k`, number `J` of the warp's shuffles before its waits, and families `T i j` of thread
predicates, `W i j` of status predicates and `P i j` of memory predicates (phase `i`, lane `j`,
`j` lanes done in the phase): if in each phase `i ≤ J` each lane `j` of `T i j`, from every
memory of `P i j`, runs to a collective call (`ToWait`, in the context of thread `k + j`) at a
status of `W i j` leaving a memory of `P i (j + 1)`; and from every lane-indexed statuses `s`
with `W i j (s j)` and memory of `P i` after all the lanes of a phase `i < J`, the warp's shuffle
fires (`WarpShfl`) to threads and deliveries whose resumed lanes are of `T (i + 1)`, on a memory
of `P (i + 1) 0`: then threads `t` whose lane `j`, thread `k + j`, is of `T 0 j`, on a memory of
`P 0 0`, have a warp's run to their waits (`WarpWait`) at statuses `s` with lane `j`'s
`s (k + j)` of `W J j`, to a memory of `P J` after all the lanes (`warp_of_inv`, the last phase
by `Seq.ToWait.of_inv` and `Seq.ToWait.warp`; `WarpRun.of_inv` with waits in place of the
ends). -/
theorem WarpWait.of_inv {L : Launch} {c : Nat → Ctx} {k J : Nat}
    {T : Nat → Nat → Thread → Prop} {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ t m, T i j t → P i j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W i j s ∧ P i (j + 1) m')
    (hf : ∀ i < J, ∀ s : Nat → Status, (∀ j ∈ warpLanes L k, W i j (s j)) →
      ∀ m, P i (warpLanes L k).length m → ∃ u r, WarpShfl L c k s m u r ∧
        (∀ j ∈ warpLanes L k, T (i + 1) j ((u j).resume (r j))) ∧ P (i + 1) 0 m)
    (he : ∀ j ∈ warpLanes L k, ∀ t m, T J j t → P J j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W J j s ∧ P J (j + 1) m')
    {t : Nat → Thread} (ht : ∀ j ∈ warpLanes L k, T 0 j (t (k + j))) {m : Mem}
    (hm : P 0 0 m) : ∃ s Es m', WarpWait L c k t m Es s m' ∧
      (∀ j ∈ warpLanes L k, W J j (s (k + j))) ∧ P J (warpLanes L k).length m' := by
  obtain ⟨Es, m', ⟨s, hr, hW⟩, hP⟩ := warp_of_inv
    (Q := fun t m Es m' => ∃ s, WarpWait L c k t m Es s m' ∧
      ∀ j ∈ warpLanes L k, W J j (s (k + j)))
    (fun hw hf ⟨s, hS, hW⟩ => ⟨s, .shfl hw hf hS, hW⟩) hw hf (fun t m ht hm => by
      obtain ⟨s, Es, m', hs, hW, hP⟩ := Seq.ToWait.of_inv (c := fun j => c (k + j))
        (t := fun j => t (k + j)) (W := W J) (P := P J) (N := (warpLanes L k).length)
        (fun j hj m hm => he j (mem_warpLanes.2 hj) _ m (ht j (mem_warpLanes.2 hj)) hm) hm
      exact ⟨Es, m', ⟨fun n => s (n - k), .waits (Seq.ToWait.warp (L := L) hs), fun j hj => by
        simpa only [Nat.add_sub_cancel_left] using hW j (mem_warpLanes.1 hj)⟩, hP⟩) ht hm
  exact ⟨s, Es, m', hr, hW, hP⟩

/-- **Warps in turn to their waits by invariants.** For every launch `L`, contexts `c`, threads
`t`, statuses `s`, warps' first threads `ks` and family `P` of memory predicates indexed by the
number of warps that have run: if each warp `ks[i]`, from every memory of `P i`, has a run to its
waits at `s` (`WarpWait`, which `WarpWait.of_inv` gives) from `t` to a memory of `P (i + 1)`, then
the warps of `ks` run in turn to their waits (`CanonWait`) from every memory of `P 0` to a memory
of `P ks.length` (by induction on `ks`). `CanonWait.of_merge` is the form with each warp's own
statuses. -/
theorem CanonWait.of_inv {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status} :
    ∀ {P : Nat → Mem → Prop} {ks : List Nat}, (∀ i (hi : i < ks.length), ∀ m, P i m →
      ∃ Es m', WarpWait L c ks[i] t m Es s m' ∧ P (i + 1) m') →
    ∀ {m : Mem}, P 0 m → ∃ Es m', CanonWait L c t s ks m Es m' ∧ P ks.length m'
  | _, [], _, m, h0 => ⟨[], m, .nil m, h0⟩
  | P, k :: ks, h, m, h0 => by
    obtain ⟨Es, m₁, hw, hm₁⟩ := h 0 (by simp) m h0
    obtain ⟨Es', m', hc, hm'⟩ := CanonWait.of_inv (P := fun i => P (i + 1)) (ks := ks)
      (fun i hi m hm => h (i + 1) (by simp only [List.length_cons]; omega) m hm) hm₁
    exact ⟨Es ++ Es', m', .cons hw hc, hm'⟩

/-- **Warps in turn to their waits by invariants, each warp at its own statuses.** For every
launch `L` with blocks of `volume L.block > 0` threads, contexts `c`, threads `t`, family `V` of
status predicates indexed by thread, distinct warps' first threads `ks` (each at lane 0 of its
warp) and family `P` of memory predicates indexed by the number of warps that have run: if each
warp `ks[i]`, from every memory of `P i`, has a run to its waits (`WarpWait`, which
`WarpWait.of_inv` gives) from `t` to a memory of `P (i + 1)`, at statuses with `V n` at each of
its threads `n`, then the warps of `ks` run in turn to their waits (`CanonWait`) from every
memory of `P 0` to a memory of `P ks.length`, at statuses `s` that are each warp's run's on its
threads, so `V n (s n)` at each of their threads (`WarpWait.congr`, `CanonWait.congr`; the warps'
threads are apart, `warpThreads_iff`). Its premises `ks.Nodup`, lane 0 and `0 < volume L.block`
are what merging the warps' statuses needs; `CanonWait.of_inv`, at statuses fixed before the
run, needs none of them. -/
theorem CanonWait.of_merge {L : Launch} {c : Nat → Ctx} {t : Nat → Thread}
    {V : Nat → Status → Prop} (hs : 0 < volume L.block) :
    ∀ {P : Nat → Mem → Prop} {ks : List Nat}, ks.Nodup →
    (∀ k ∈ ks, k % volume L.block % 32 = 0) →
    (∀ i (hi : i < ks.length), ∀ m, P i m → ∃ s Es m', WarpWait L c ks[i] t m Es s m' ∧
      (∀ n ∈ warpThreads L ks[i], V n (s n)) ∧ P (i + 1) m') →
    ∀ {m : Mem}, P 0 m → ∃ s Es m', CanonWait L c t s ks m Es m' ∧
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, V n (s n)) ∧ P ks.length m'
  | _, [], _, _, _, m, h0 => ⟨fun _ => .done, [], m, .nil m, by simp, h0⟩
  | P, k :: ks, hd, hk, h, m, h0 => by
    obtain ⟨s₁, Es, m₁, hw, hV₁, hm₁⟩ := h 0 (by simp) m h0
    obtain ⟨s₂, Es', m', hc, hV₂, hm'⟩ := CanonWait.of_merge hs (P := fun i => P (i + 1))
      (ks := ks) (List.nodup_cons.1 hd).2 (fun k' hk' => hk k' (List.mem_cons_of_mem _ hk'))
      (fun i hi m hm => h (i + 1) (by simp only [List.length_cons]; omega) m hm) hm₁
    have hk0 := hk k List.mem_cons_self
    have hn : ∀ k' ∈ ks, ∀ n ∈ warpThreads L k', n ∉ warpThreads L k := fun k' hk' n hn hn' =>
      (List.nodup_cons.1 hd).1 (by
        rw [← (warpThreads_iff hs hk0).1 hn',
          (warpThreads_iff hs (hk k' (List.mem_cons_of_mem _ hk'))).1 hn]
        exact hk')
    refine ⟨fun n => if n ∈ warpThreads L k then s₁ n else s₂ n, Es ++ Es', m',
      .cons (hw.congr fun n hn => (ite_eq_left hn).symm)
        (hc.congr fun k' hk' n hn' => (ite_eq_right (hn k' hk' n hn')).symm),
      fun k' hk' n hn' => ?_, hm'⟩
    rcases List.mem_cons.1 hk' with rfl | hk'
    · simp only [hn', ↓reduceIte]
      exact hV₁ n hn'
    · simp only [hn k' hk' n hn', ↓reduceIte]
      exact hV₂ k' hk' n hn'

/-- **A block's run by invariants.** For every launch `L`, contexts `c`, block `b`, number `J` of
the block's barriers, families `T i` of thread predicates and `P i` of memory predicates (phase
`i`): if in each phase `i < J`, from all threads of `T i` on every memory of `P i`, the block's
warps run in turn to their waits (`CanonWait`, which `CanonWait.of_inv` or `CanonWait.of_merge`
gives) at statuses at which the block's barrier fires (`BlockBar`), resuming threads of
`T (i + 1)`, and the memory with the block's `.barrier` logged is of `P (i + 1)`; and in phase
`J`, from all threads of `T J` on every memory of `P J`, the block's warps run to their ends
(`CanonRun`) leaving a memory of `P (J + 1)`: then threads of `T 0` on a memory of `P 0` have a
block's run (`BlockRun`) to a memory of `P (J + 1)` (by induction on the phases left). -/
theorem BlockRun.of_inv {L : Launch} {c : Nat → Ctx} {b J : Nat}
    {T : Nat → (Nat → Thread) → Prop} {P : Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ t m, T i t → P i m →
      ∃ (s : Nat → Status) (u : Nat → Thread) (Es : List (List Event)) (m₁ : Mem),
      CanonWait L c t s (blockWarps L b) m Es m₁ ∧ BlockBar L b s u ∧
        T (i + 1) (fun n => (u n).resume none) ∧ P (i + 1) (m₁.log (.barrier b)))
    (he : ∀ t m, T J t → P J m → ∃ Es m', CanonRun L c t (blockWarps L b) m Es m' ∧ P (J + 1) m')
    {t : Nat → Thread} (ht : T 0 t) {m : Mem} (hm : P 0 m) :
    ∃ Es m', BlockRun L c b t m Es m' ∧ P (J + 1) m' := by
  have go : ∀ n i (t : Nat → Thread) m, i + n = J → T i t → P i m →
      ∃ Es m', BlockRun L c b t m Es m' ∧ P (J + 1) m' := by
    intro n
    induction n with
    | zero =>
      intro i t m hi ht hm
      obtain rfl : i = J := by omega
      obtain ⟨Es, m', hc, hP⟩ := he t m ht hm
      exact ⟨Es, m', .ends hc, hP⟩
    | succ n ih =>
      intro i t m hi ht hm
      obtain ⟨s, u, Es, m₁, hc, hb, ht', hm₁⟩ := hw i (by omega) t m ht hm
      obtain ⟨Es', m', hr, hP⟩ := ih (i + 1) _ _ (by omega) ht' hm₁
      exact ⟨_, m', .bar hc hb hr, hP⟩
  exact go J 0 t m (Nat.zero_add J) ht hm

/-- **The canonical run at the phase level by invariants.** For every launch `L`, contexts `c`,
threads `t`, blocks `bs` and family `P` of memory predicates indexed by the number of blocks that
have run: if each block `bs[i]`, from every memory of `P i`, has a run (`BlockRun`, which
`BlockRun.of_inv` gives) from `t` to a memory of `P (i + 1)`, then the blocks of `bs` have a
canonical run at the phase level (`PhaseRun`) from every memory of `P 0` to a memory of
`P bs.length`. -/
theorem PhaseRun.of_inv {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} :
    ∀ {P : Nat → Mem → Prop} {bs : List Nat}, (∀ i (hi : i < bs.length), ∀ m, P i m →
      ∃ Es m', BlockRun L c bs[i] t m Es m' ∧ P (i + 1) m') →
    ∀ {m : Mem}, P 0 m → ∃ Es m', PhaseRun L c t bs m Es m' ∧ P bs.length m'
  | _, [], _, m, h0 => ⟨[], m, .nil m, h0⟩
  | P, b :: bs, h, m, h0 => by
    obtain ⟨Es, m₁, hb, hm₁⟩ := h 0 (by simp) m h0
    obtain ⟨Es', m', hc, hm'⟩ := PhaseRun.of_inv (P := fun i => P (i + 1)) (bs := bs)
      (fun i hi m hm => h (i + 1) (by simp only [List.length_cons]; omega) m hm) hm₁
    exact ⟨Es ++ Es', m', .cons hb hc, hm'⟩

/-! ## The one-level run as the case of one phase per block -/

/-- **The warps of whole blocks are the blocks' warps**: for every launch `L` and number `B` of
blocks, the first threads of the warps among the threads of blocks `0` to `B - 1` (`warps`) are
block `0`'s warps, then block `1`'s, and so on (`blockWarps`). -/
theorem warps_blocks (L : Launch) : ∀ B : Nat,
    warps L (B * volume L.block) = (List.range B).flatMap (blockWarps L)
  | 0 => by simp [warps]
  | B + 1 => by
    rw [Nat.succ_mul, warps, List.range_add, List.filter_append, ← warps, warps_blocks L B,
      List.range_succ, List.flatMap_append, List.flatMap_singleton, blockWarps, List.filter_map]
    congr 2
    refine List.filter_congr fun j hj => ?_
    simp only [Function.comp_def, Nat.add_comm (B * volume L.block), Nat.add_mul_mod_self_right,
      Nat.mod_eq_of_lt (List.mem_range.1 hj)]

/-- **The canonical run of a list of warps, split**: for every launch, contexts, threads, lists
`ks`, `ks'` of warps' first threads and memories, the canonical run (`CanonRun`) of the warps of
`ks ++ ks'` is the run of `ks`, then the run of `ks'` from the memory it leaves, with the events
of the two in turn. -/
theorem CanonRun.append {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} :
    ∀ {ks ks' : List Nat} {m m' : Mem} {Es : List (List Event)},
      CanonRun L c t (ks ++ ks') m Es m' → ∃ Es₁ Es₂ m₁, Es = Es₁ ++ Es₂ ∧
        CanonRun L c t ks m Es₁ m₁ ∧ CanonRun L c t ks' m₁ Es₂ m'
  | [], _, m, _, Es, h => ⟨[], Es, m, rfl, .nil m, h⟩
  | k :: ks, ks', m, m', _, h => by
    cases h with
    | @cons _ _ _ m₁ _ Es Es' hw hc =>
      obtain ⟨Es₁, Es₂, m₂, rfl, h₁, h₂⟩ := CanonRun.append (ks := ks) (ks' := ks') hc
      exact ⟨Es ++ Es₁, Es₂, m₂, (List.append_assoc _ _ _).symm, .cons hw h₁, h₂⟩

/-- **The one-level canonical run is the phase level's case of one phase per block**: for every
launch `L`, contexts `c`, threads `t`, blocks `bs` and memories, the canonical run (`CanonRun`)
of the blocks' warps, block by block (`blockWarps`), is a canonical run at the phase level
(`PhaseRun`) of the blocks, each block's run its last phase (`BlockRun.ends`), with the same
events (`CanonRun.append`). -/
theorem PhaseRun.of_blocks {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} :
    ∀ {bs : List Nat} {m m' : Mem} {Es : List (List Event)},
      CanonRun L c t (bs.flatMap (blockWarps L)) m Es m' → PhaseRun L c t bs m Es m'
  | [], m, m', Es, h => by
    cases h
    exact .nil m
  | b :: bs, m, m', Es, h => by
    rw [List.flatMap_cons] at h
    obtain ⟨Es₁, Es₂, m₁, rfl, h₁, h₂⟩ := CanonRun.append h
    exact .cons (.ends h₁) (PhaseRun.of_blocks h₂)

/-- **The one-level canonical run over every warp at the phase level**: for every launch `L`,
contexts `c`, threads `t`, number `B` of blocks and memories, the canonical run (`CanonRun`)
over the warps of the threads of blocks `0` to `B - 1` (`warps`) is a canonical run at the phase
level (`PhaseRun`) of blocks `0` to `B - 1` with one phase each, with the same events
(`warps_blocks`, `PhaseRun.of_blocks`). So the one-level run's results (`CanonRun.done`,
`CanonRun.start_done`, `CanonRun.start_sound`) are the phase level's at that run. -/
theorem PhaseRun.of_canon {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {B : Nat} {m m' : Mem}
    {Es : List (List Event)} (h : CanonRun L c t (warps L (B * volume L.block)) m Es m') :
    PhaseRun L c t (List.range B) m Es m' :=
  PhaseRun.of_blocks (warps_blocks L B ▸ h)

/-- **The canonical run to a done grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, threads `t`, memory `m'` and grid `g` whose number
of threads is a multiple of the block's and in which each thread `n` runs `t n`: the canonical
run (`CanonRun`) of every warp (`warps`) from `t` on `g`'s memory to `m'` is a run of grid steps
from `g` to a done grid (the core's `Done` at `sig`) with memory `m'`, whose trace is the run's
events, the last lane's run's in front, in front of `g`'s memory's: `PhaseRun.done` at the run
of one phase per block (`PhaseRun.of_canon`), over the `g.threads.size / volume L.block`
blocks. -/
theorem CanonRun.done {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {g : Grid} {m' : Mem}
    {Es : List (List Event)} (hs : 0 < volume L.block)
    (hN : g.threads.size % volume L.block = 0)
    (h : CanonRun L c t (warps L g.threads.size) g.mem Es m')
    (hg : ∀ n < g.threads.size, g.threads[n]? = some (.run (t n))) :
    ∃ z, (∃ i, Path (Grid.Step L c) i g z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' ∧
      z.mem.trace = Es.reverse.flatten ++ g.mem.trace := by
  have hB := (Nat.div_mul_cancel (Nat.dvd_of_mod_eq_zero hN)).symm
  rw [hB] at h
  exact PhaseRun.done hs hB (PhaseRun.of_canon h) hg

/-- **A start with a canonical run reaches a done grid.** For every program, kernel `fn`, launch
`L` with blocks of `volume L.block > 0` threads, arguments, memory, address choice and oracle whose
start (`Grid.start`) gives grid `g₀` and contexts `c`: if the threads of `g₀` (`Grid.thread`) on
`g₀`'s memory have a canonical run (`CanonRun`) over every warp (`warps`) to `m'`, then `g₀` steps
(`Grid.Step`) to a done grid (`GPUProof.Done` at `sig`) with memory `m'`: `PhaseRun.start_done`
at the run of one phase per block (`PhaseRun.of_canon`, `Grid.start_size`). -/
theorem CanonRun.start_done {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hs : 0 < volume L.block)
    {Es : List (List Event)} {m' : Mem}
    (hc : CanonRun L c (Grid.thread g₀) (warps L g₀.threads.size) g₀.mem Es m') :
    ∃ z, (∃ i, Path (Grid.Step L c) i g₀ z) ∧ GPUProof.Done sig (z, L, c) ∧ z.mem = m' :=
  PhaseRun.start_done h hs (PhaseRun.of_canon (Grid.start_size h ▸ hc))

/-- **A start with a canonical run, sound.** For every program, kernel `fn`, launch `L` with
blocks of `volume L.block > 0` threads, arguments, address choice and oracle whose start
(`Grid.start`) gives grid `g₀` and contexts `c`, on a caller's memory `m` meeting `Mem.BytesIn`,
and every observation `obs` that reads only the blocks: if the threads of `g₀` (`Grid.thread`)
on `g₀`'s memory have a canonical run (`CanonRun`) over every warp (`warps`) to `m'`, and `m'`'s
trace keeps the promise of `!invariant.load` (the core's `GPUProof.kept` at `sig`), has no data
race (the core's `racy` at `sig`) when it has the premises of `racy_iff`, and has
`obs m' = some y` with `R y`, then `g₀` is sound (`Grid.Sound`): `PhaseRun.start_sound` at the
run of one phase per block (`PhaseRun.of_canon`, `Grid.start_size`), with those checks as
`EndChecks`. -/
theorem CanonRun.start_sound {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (hs : 0 < volume L.block)
    {Es : List (List Event)} {m' : Mem}
    (hc : CanonRun L c (Grid.thread g₀) (warps L g₀.threads.size) g₀.mem Es m')
    (hr : ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
      GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false))
    (hk : GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true)
    {y : β} (hy : obs m' = some y) (hR : R y) : Grid.Sound L c g₀ obs R :=
  PhaseRun.start_sound h hm hO hs (PhaseRun.of_canon (Grid.start_size h ▸ hc)) ⟨hr, hk, y, hy, hR⟩

/-! ## Blocks whose threads run in order -/

/-- Whether the warps of first threads `ks`, in launch `L`, cover threads `p` to `q - 1` in order:
the first starts at `p`, each next one where the one before ends (after its lanes, `warpLanes`),
and the last ends at `q`. -/
def warpsCover (L : Launch) : List Nat → Nat → Nat → Bool
  | [], p, q => p == q
  | k :: ks, p, q => k == p && warpsCover L ks (p + (warpLanes L k).length) q

/-- Warps that cover threads `p` to `q - 1` start no later than they end, for every launch,
warps and threads. -/
theorem warpsCover_le {L : Launch} :
    ∀ {ks : List Nat} {p q : Nat}, warpsCover L ks p q = true → p ≤ q
  | [], p, q, h => by
    simp only [warpsCover, beq_iff_eq] at h
    omega
  | k :: ks, p, q, h => by
    simp only [warpsCover, Bool.and_eq_true, beq_iff_eq] at h
    have := warpsCover_le h.2
    omega

/-- **Induction on warps that cover threads**: for every launch `L`, last thread `q`, property
`H n` of threads and property `C ks p` of warps' first threads `ks` from thread `p`: if `C [] q`
holds, and for every warp `k` whose threads `k + j` (`warpLanes`) all have `H`, `C ks` from the
thread after its last lane gives `C (k :: ks) k`, then `C ks p` holds for all warps `ks` that
cover threads `p` to `q - 1` (`warpsCover`) whose threads all have `H`. -/
theorem warpsCover_rec {L : Launch} {q : Nat} {H : Nat → Prop} {C : List Nat → Nat → Prop}
    (h0 : C [] q) (h1 : ∀ k ks, (∀ j ∈ warpLanes L k, H (k + j)) →
      C ks (k + (warpLanes L k).length) → C (k :: ks) k) :
    ∀ {ks : List Nat} {p : Nat}, warpsCover L ks p q = true → (∀ n, p ≤ n → n < q → H n) → C ks p
  | [], p, h, _ => by
    simp only [warpsCover, beq_iff_eq] at h
    subst h
    exact h0
  | k :: ks, p, h, hl => by
    simp only [warpsCover, Bool.and_eq_true, beq_iff_eq] at h
    obtain ⟨rfl, h⟩ := h
    have hq := warpsCover_le h
    exact h1 k ks (fun j hj => hl (k + j) (by omega) (by have := mem_warpLanes.1 hj; omega))
      (warpsCover_rec h0 h1 h fun n hn hn' => hl n (by omega) hn')

/-- **A warp's lanes in turn to their waits**: for every launch `L`, contexts `c`, warp's first
thread `k`, threads `t`, statuses `S` and memories `M` indexed by thread: if each of the warp's
threads `n` runs from `t n` on `M n` to a collective call at `S n` (`ToWait`) leaving `M (n + 1)`,
the warp has a run to its waits (`WarpWait.waits`, with no shuffle) from `M k` to the memory after
its last lane (`WarpWait.of_inv` at no shuffle, lane `j`'s memory `M (k + j)` and status
`S (k + j)`, and `WarpWait.congr`). -/
theorem WarpWait.of_turns {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread}
    {S : Nat → Status} {M : Nat → Mem}
    (h : ∀ j ∈ warpLanes L k, ToWait (c (k + j)) (t (k + j)) (M (k + j)) (S (k + j))
      (M (k + j + 1))) :
    ∃ Es, WarpWait L c k t (M k) Es S (M (k + (warpLanes L k).length)) := by
  obtain ⟨s, Es, _, hw, hs, rfl⟩ := WarpWait.of_inv (J := 0) (T := fun _ j u => u = t (k + j))
    (W := fun _ j s => s = S (k + j)) (P := fun _ j m => m = M (k + j))
    (fun _ h => absurd h (Nat.not_lt_zero _)) (fun _ h => absurd h (Nat.not_lt_zero _))
    (fun j hj _ _ hu hm => by subst hu hm; exact ⟨_, _, h j hj, rfl, rfl⟩) (fun _ _ => rfl)
    (m := M k) rfl
  exact ⟨Es, hw.congr fun n hn => by
    obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hn
    exact hs j hj⟩

/-- **A warp's lanes in turn to their ends**: for every launch `L`, contexts `c`, warp's first
thread `k`, threads `t` and memories `M` indexed by thread: if each of the warp's threads `n` runs
from `t n` on `M n` to its end at `M (n + 1)` (`Runs`), the warp has a run (`WarpRun.ends`, with
no shuffle) from `M k` to the memory after its last lane (`WarpRun.of_inv` at no shuffle, lane
`j`'s memory `M (k + j)`). -/
theorem WarpRun.of_turns {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread}
    {M : Nat → Mem}
    (h : ∀ j ∈ warpLanes L k, Runs (c (k + j)) (t (k + j)) (M (k + j)) (M (k + j + 1))) :
    ∃ Es, WarpRun L c k t (M k) Es (M (k + (warpLanes L k).length)) := by
  obtain ⟨Es, _, hw, rfl⟩ := WarpRun.of_inv (J := 0) (T := fun _ j u => u = t (k + j))
    (W := fun _ _ _ => True) (P := fun _ j m => m = M (k + j))
    (fun _ h => absurd h (Nat.not_lt_zero _)) (fun _ h => absurd h (Nat.not_lt_zero _))
    (fun j hj _ _ hu hm => by subst hu hm; exact ⟨_, h j hj, rfl⟩) (fun _ _ => rfl) (m := M k) rfl
  exact ⟨Es, hw⟩

/-- **Warps in turn to their waits, their threads in order**: for every launch `L`, contexts `c`,
threads `t`, statuses `S`, memories `M` indexed by thread, and warps `ks` that cover threads `p`
to `q - 1` (`warpsCover`): if each thread `n` from `p` to `q - 1` runs from `t n` on `M n` to a
collective call at `S n` leaving `M (n + 1)`, the warps run in turn to their waits (`CanonWait`)
from `M p` to `M q` (`warpsCover_rec`, `WarpWait.of_turns`). -/
theorem CanonWait.of_turns {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {S : Nat → Status}
    {M : Nat → Mem} {q : Nat} {ks : List Nat} {p : Nat} (hT : warpsCover L ks p q = true)
    (h : ∀ n, p ≤ n → n < q → ToWait (c n) (t n) (M n) (S n) (M (n + 1))) :
    ∃ Es, CanonWait L c t S ks (M p) Es (M q) :=
  warpsCover_rec (C := fun ks p => ∃ Es, CanonWait L c t S ks (M p) Es (M q)) ⟨[], .nil _⟩
    (fun _ _ hw ⟨_, hc⟩ => let ⟨_, hw⟩ := WarpWait.of_turns hw; ⟨_, .cons hw hc⟩) hT h

/-- **Warps in turn to their ends, their threads in order**: for every launch `L`, contexts `c`,
threads `t`, memories `M` indexed by thread, and warps `ks` that cover threads `p` to `q - 1`
(`warpsCover`): if each thread `n` from `p` to `q - 1` runs from `t n` on `M n` to its end at
`M (n + 1)`, the warps have a canonical run (`CanonRun`) from `M p` to `M q`
(`warpsCover_rec`, `WarpRun.of_turns`). -/
theorem CanonRun.of_turns {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {M : Nat → Mem}
    {q : Nat} {ks : List Nat} {p : Nat} (hT : warpsCover L ks p q = true)
    (h : ∀ n, p ≤ n → n < q → Runs (c n) (t n) (M n) (M (n + 1))) :
    ∃ Es, CanonRun L c t ks (M p) Es (M q) :=
  warpsCover_rec (C := fun ks p => ∃ Es, CanonRun L c t ks (M p) Es (M q)) ⟨[], .nil _⟩
    (fun _ _ hw ⟨_, hc⟩ => let ⟨_, hw⟩ := WarpRun.of_turns hw; ⟨_, .cons hw hc⟩) hT h

/-- **A block of two phases, its threads in order**: for every launch `L`, contexts `c`, block
`b` whose warps cover threads `p` to `q - 1` (`warpsCover`), threads `t`, statuses `S`, threads
`U` and memories `M₀`, `M₁` indexed by thread: if each thread `n` from `p` to `q - 1` runs from
`t n` on `M₀ n` to a collective call at `S n` leaving `M₀ (n + 1)`, the block's barrier fires
there (`BlockBar`), and each thread `n` resumed, `(U n).resume none`, runs on `M₁ n` to its end
at `M₁ (n + 1)`, where `M₁ p` is `M₀ q` with the block's `.barrier` logged, then the block has a
run of two phases (`BlockRun.bar`, then `BlockRun.ends`) from `M₀ p` to `M₁ q` (`BlockRun.of_inv`
at one barrier, `CanonWait.of_turns` and `CanonRun.of_turns` for its phases). -/
theorem BlockRun.of_turns {L : Launch} {c : Nat → Ctx} {b p q : Nat} {t : Nat → Thread}
    {S : Nat → Status} {U : Nat → Thread} {M₀ M₁ : Nat → Mem}
    (hT : warpsCover L (blockWarps L b) p q = true)
    (h0 : ∀ n, p ≤ n → n < q → ToWait (c n) (t n) (M₀ n) (S n) (M₀ (n + 1)))
    (hb : BlockBar L b S U) (hm : M₁ p = (M₀ q).log (.barrier b))
    (h1 : ∀ n, p ≤ n → n < q → Runs (c n) ((U n).resume none) (M₁ n) (M₁ (n + 1))) :
    ∃ Es, BlockRun L c b t (M₀ p) Es (M₁ q) := by
  obtain ⟨Es, _, hr, rfl⟩ := BlockRun.of_inv (J := 1)
    (T := fun i u => u = if i = 0 then t else fun n => (U n).resume none)
    (P := fun i m => m = if i = 0 then M₀ p else if i = 1 then M₁ p else M₁ q)
    (fun i hi u m hu hm' => by
      obtain rfl : i = 0 := by omega
      simp only [↓reduceIte] at hu hm' ⊢
      subst u m
      obtain ⟨Es, hw⟩ := CanonWait.of_turns (c := c) (t := t) (S := S) (M := M₀) hT h0
      exact ⟨S, U, Es, _, hw, hb, rfl, hm.symm⟩)
    (fun u m hu hm' => by
      simp only [Nat.one_ne_zero, ↓reduceIte] at hu hm' ⊢
      subst hu hm'
      exact CanonRun.of_turns (c := c) (t := fun n => (U n).resume none) (M := M₁) hT h1 |>.elim
        fun Es hr => ⟨Es, _, hr, rfl⟩) (t := t) rfl (m := M₀ p) rfl
  exact ⟨Es, hr⟩

end MojoProof.Sym
