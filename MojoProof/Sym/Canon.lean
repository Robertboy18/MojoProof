import MojoProof.Sym.SchedChain
import MojoProof.Sym.OblSeg

/-!
# The canonical run at one level: warps in turn

Every result here is for every program, launch, contexts, thread and memory.

A warp is named by its first thread `k` (`k % volume L.block % 32 = 0`); its lanes are
`warpLanes L k`, `Grid.fire`'s lanes, and its threads `warpThreads L k`. The canonical run
(`CanonRun`) takes the warps in turn (`warps`). Within a warp (`WarpRun`) the lanes run in turn
to their next collective call (`Seq.ToWait`); once the last one waits, the warp's shuffle fires
(`WarpShfl`, `Grid.fire_shfl` at the warp's first thread), resuming each lane with the value
`Grid.fire` delivers (`shflVal` at `shflSource`'s lane, `poison` for a lane not of the warp);
this repeats until every lane has run to its end (`Seq`). Each warp has its own number of
shuffles, so a warp that branches around a shuffle is a run with one phase less. The blocks
in turn, with their barriers, are the next level up (`PhaseRun`, MojoProof/Sym/CanonBar.lean).

* `warpLanes_eq`: a warp's lanes are `List.range` of their number, `min 32` and what is left of
  the block. `warpThreads_iff`: thread `n` is one of the warp of first thread `k` exactly when
  `n - n % volume L.block % 32 = k`, so distinct warps have disjoint threads.
* `WarpRun.grid`, `CanonRun.grid`: the runs are runs of grid steps, from every grid whose warps'
  threads run the run's threads, to the grid with those threads done; `CanonRun.trace`: the run
  puts its events in front of the first memory's trace. The run over every warp to a done grid
  and to a sound start (`CanonRun.done`, `CanonRun.start_done`, `CanonRun.start_sound`) are
  corollaries of the phase level's, in MojoProof/Sym/CanonBar.lean.
* `WarpRun.of_inv`, `CanonRun.of_inv`: the runs from predicates on each lane's runs to its next
  collective and to its end, each phase's shuffle firing from every statuses they allow, and on
  each warp's runs (`Seq.ToWait.of_inv`, `Seq.of_inv` on the lanes, moved to the warp's threads
  by `Seq.ToWait.warp` and `Seq.warp`).
* `WarpRun.of_waits`: the run from each lane's run through its waits (`RunsVia` with
  `Piece.Wait.via`'s predicates, as `RunsVia.of_fires` concludes) when the waits' calls,
  arguments and memories are a shuffle's and the deliveries `Grid.fire`'s (`WarpRun.of_inv`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem
open GPUProof

/-- The threads of the warp whose first thread is `k`, in launch `L`: thread `k + j` for each
lane `j` of `warpLanes L k`. -/
def warpThreads (L : Launch) (k : Nat) : List Nat := (warpLanes L k).map (k + ·)

/-- The first threads of the warps among threads `0` to `N - 1`, in launch `L`: the threads at
lane 0 of their block's warps (`k % volume L.block % 32 = 0`), in order. -/
def warps (L : Launch) (N : Nat) : List Nat :=
  (List.range N).filter fun k => k % volume L.block % 32 = 0

/-- The numbers `j < N` with `a + j < s` are those below `min N (s - a)`, for every `a`, `s` and
`N`. -/
theorem range_filter_add_lt (a s : Nat) : ∀ N : Nat,
    (List.range N).filter (fun j => decide (a + j < s)) = List.range (min N (s - a))
  | 0 => by simp
  | N + 1 => by
    rw [List.range_succ, List.filter_append, range_filter_add_lt a s N]
    by_cases h : a + N < s
    · rw [Nat.min_eq_left (by omega : N ≤ s - a), Nat.min_eq_left (by omega : N + 1 ≤ s - a),
        List.range_succ]
      simp [h]
    · rw [Nat.min_eq_right (by omega : s - a ≤ N), Nat.min_eq_right (by omega : s - a ≤ N + 1)]
      simp [h]

/-- **A warp's lanes are a range**: for every launch `L` and thread `n`, the lanes of `n`'s warp
(`warpLanes`) are those below 32 and below what is left of the block from the warp's first
thread. -/
theorem warpLanes_eq (L : Launch) (n : Nat) : warpLanes L n = List.range (min 32
    (volume L.block - (n % volume L.block - n % volume L.block % 32))) :=
  range_filter_add_lt _ _ 32

/-- A warp's lanes are the numbers below their number, for every launch and thread. -/
theorem warpLanes_range (L : Launch) (n : Nat) :
    warpLanes L n = List.range (warpLanes L n).length := by
  rw [warpLanes_eq, List.length_range]

/-- A lane is one of the warp's lanes exactly when it is below their number, for every launch
and thread. -/
theorem mem_warpLanes {L : Launch} {n j : Nat} :
    j ∈ warpLanes L n ↔ j < (warpLanes L n).length := by
  rw [warpLanes_eq, List.mem_range, List.length_range]

/-- The first thread of thread `n`'s warp is at `n`'s place in the block less `n`'s lane, for
blocks of `s > 0` threads. -/
theorem warp_base_mod {s : Nat} (hs : 0 < s) (n : Nat) :
    (n - n % s % 32) % s = n % s - n % s % 32 := by
  have h1 := Nat.mod_add_div n s
  have h2 := Nat.mod_le (n % s) 32
  have h3 := Nat.mod_lt n hs
  rw [show n - n % s % 32 = n % s - n % s % 32 + s * (n / s) by omega,
    Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (by omega)]

/-- Thread `k + j` is `j` places after `k` in `k`'s block when `k % s + j < s`, for blocks of
`s > 0` threads. -/
theorem warp_lane {s k j : Nat} (hs : 0 < s) (hj : k % s + j < s) :
    (k + j) % s = k % s + j ∧ (k + j) / s = k / s := by
  have h1 := Nat.mod_add_div k s
  rw [show k + j = k % s + j + s * (k / s) by omega, Nat.add_mul_mod_self_left,
    Nat.add_mul_div_left _ _ hs, Nat.mod_eq_of_lt hj, Nat.div_eq_of_lt hj, Nat.zero_add]
  exact ⟨rfl, rfl⟩

/-- **A warp's threads**: for every launch `L` with blocks of `volume L.block > 0` threads and
warp's first thread `k`, thread `n` is one of `k`'s warp's threads (`warpThreads`) exactly when
the first thread of `n`'s warp is `k`. -/
theorem warpThreads_iff {L : Launch} {k n : Nat} (hs : 0 < volume L.block)
    (hk : k % volume L.block % 32 = 0) :
    n ∈ warpThreads L k ↔ n - n % volume L.block % 32 = k := by
  simp only [warpThreads, List.mem_map, warpLanes, List.mem_filter, List.mem_range,
    decide_eq_true_eq]
  generalize volume L.block = s at hs hk ⊢
  constructor
  · rintro ⟨j, ⟨hj, hj'⟩, rfl⟩
    rw [(warp_lane hs (by omega)).1]
    omega
  · intro e
    have := warp_base_mod hs n
    rw [e] at this
    have := Nat.mod_lt n hs
    have := Nat.mod_le (n % s) 32
    have := Nat.mod_le n s
    exact ⟨n % s % 32, ⟨Nat.mod_lt _ (by decide), by omega⟩, by omega⟩

/-- A warp's threads are distinct, for every launch and first thread. -/
theorem warpThreads_nodup (L : Launch) (k : Nat) : (warpThreads L k).Nodup :=
  (List.nodup_range.filter _).map fun _ _ => Nat.add_left_cancel

/-- Runs in turn moved along a map of the thread numbers: for every families of runs `R` and
`R'` and map `f`, if every run of `R` by a thread `n` of `ns` is a run of `R'` by `f n`, threads
`ns` in turn by `R` are threads `ns.map f` in turn by `R'`, with the same events. -/
theorem Turns.map {R R' : Nat → Mem → Mem → Prop} {f : Nat → Nat} {ns : List Nat} {m m' : Mem}
    {Es : List (List Event)} (h : Turns R ns m Es m')
    (hR : ∀ n ∈ ns, ∀ m₁ m₂, R n m₁ m₂ → R' (f n) m₁ m₂) : Turns R' (ns.map f) m Es m' := by
  revert hR
  induction h with
  | nil m => exact fun _ => .nil m
  | cons hr e _ ih =>
    exact fun hR => .cons (hR _ (by simp) _ _ hr) e
      (ih fun n hn => hR n (List.mem_cons_of_mem _ hn))

/-- **A warp's lanes in turn to their waits, on its threads**: for every launch `L`, contexts
`c`, threads `t`, lane-indexed statuses `s` and warp's first thread `k`, lanes `0` to
`(warpLanes L k).length - 1` in turn to their waits in the contexts and threads of `k + j`
(`Seq.ToWait`) are the warp's threads in turn to their waits, thread `n` at `s (n - k)`. -/
theorem Seq.ToWait.warp {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status}
    {k : Nat} {m m' : Mem} {Es : List (List Event)}
    (h : Seq.ToWait (fun j => c (k + j)) (fun j => t (k + j)) s
      (List.range (warpLanes L k).length) m Es m') :
    Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m' := by
  rw [warpThreads, warpLanes_range]
  exact Turns.map h fun j _ m₁ m₂ hr => by
    show Sym.ToWait (c (k + j)) (t (k + j)) m₁ (s (k + j - k)) m₂
    rw [Nat.add_sub_cancel_left]
    exact hr

/-- **A warp's lanes in turn to their ends, on its threads**: for every launch `L`, contexts `c`,
threads `t` and warp's first thread `k`, lanes `0` to `(warpLanes L k).length - 1` in turn to
their ends in the contexts and threads of `k + j` (`Seq`) are the warp's threads in turn to
their ends. -/
theorem Seq.warp {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {k : Nat} {m m' : Mem}
    {Es : List (List Event)}
    (h : Seq (fun j => c (k + j)) (fun j => t (k + j)) (List.range (warpLanes L k).length) m Es
      m') : Seq c t (warpThreads L k) m Es m' := by
  rw [warpThreads, warpLanes_range]
  exact Turns.map h fun _ _ _ _ hr => hr

/-- **A warp's shuffle**, for launch `L`, contexts `c` and warp's first thread `k`, from the
lane-indexed statuses `s` on memory `m` to the threads `u` and deliveries `r`: every lane `j` of
the warp (`warpLanes`) waits, from thread `u j`, at a shuffle of one mode with member mask `M j`
(the full mask `2^32 - 1`), value `A j`, lane operand `B j` of number `b j`, clamp `C j` of
number `cl j` and callee `d j`, at the instruction lane 0 is at, and its callee's return
attributes take the value of lane `shflSource mode j (b j) (cl j)` (`shflVal`: `poison` when
that lane is not one of the warp's) to `r j` in `m` (`withAttrs`, in `k`'s layout). These are
`Grid.fire`'s checks (`Grid.fire_shfl`), so the deliveries are the semantics'. -/
def WarpShfl (L : Launch) (c : Nat → Ctx) (k : Nat) (s : Nat → Status) (m : Mem)
    (u : Nat → Thread) (r : Nat → Option Val) : Prop :=
  ∃ (mode : Shfl) (M A B C : Nat → Val) (b cl : Nat → Nat) (d : Nat → Func),
    ∀ j ∈ warpLanes L k, s j = .wait (u j) (.shfl mode) [M j, A j, B j, C j] (d j) ∧
      (M j).word? = some (2 ^ 32 - 1) ∧ (B j).word? = some (b j) ∧
      (C j).word? = some (cl j) ∧ (u j).at = (u 0).at ∧
      (some (shflVal (warpLanes L k) A (shflSource mode j (b j) (cl j)))).mapM
        (withAttrs (c k).prog.layout m (d j).ret (d j).retAttrs) = .ok (r j)

/-- A warp's run, for launch `L`, contexts `c` and warp's first thread `k`, from the threads `t`
on memory `m` to memory `m'`, with the events `Es` its lanes' runs put in front of the trace, in
the order they ran: its lanes in turn to their ends, or its lanes in turn to their waits, the
warp's shuffle, and the warp's run from the resumed lanes. -/
inductive WarpRun (L : Launch) (c : Nat → Ctx) (k : Nat) :
    (Nat → Thread) → Mem → List (List Event) → Mem → Prop
  /-- The warp's threads in turn to their ends. -/
  | ends {t : Nat → Thread} {m m' : Mem} {Es : List (List Event)} :
      Seq c t (warpThreads L k) m Es m' → WarpRun L c k t m Es m'
  /-- The warp's threads in turn to their waits, lane `j` at `s j`, on `m₁`; the shuffle from
  there resumes lane `j` from `u j` with `r j`; then the warp's run from the resumed lanes. -/
  | shfl {t : Nat → Thread} {s : Nat → Status} {m m₁ m' : Mem} {Es Es' : List (List Event)}
      {u : Nat → Thread} {r : Nat → Option Val} :
      Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m₁ → WarpShfl L c k s m₁ u r →
      WarpRun L c k (fun n => (u (n - k)).resume (r (n - k))) m₁ Es' m' →
      WarpRun L c k t m (Es ++ Es') m'

/-- The canonical run of the warps of first threads `ks`, for launch `L` and contexts `c`, from
the threads `t` on memory `m` to memory `m'`, with the events `Es` the lanes' runs put in front
of the trace: the warps in turn, each by its run (`WarpRun`) from the threads `t`. -/
inductive CanonRun (L : Launch) (c : Nat → Ctx) (t : Nat → Thread) :
    List Nat → Mem → List (List Event) → Mem → Prop
  /-- No warps. -/
  | nil (m : Mem) : CanonRun L c t [] m [] m
  /-- Warp `k`'s run, then the other warps'. -/
  | cons {k : Nat} {ks : List Nat} {m m₁ m' : Mem} {Es Es' : List (List Event)} :
      WarpRun L c k t m Es m₁ → CanonRun L c t ks m₁ Es' m' →
      CanonRun L c t (k :: ks) m (Es ++ Es') m'

/-- **A warp's trace**: for every launch, contexts, warp, threads and memories, a warp's run
(`WarpRun`) puts its events, the last lane's run's in front, in front of the first memory's
trace (`Turns.trace`; a shuffle logs none). -/
theorem WarpRun.trace {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} (h : WarpRun L c k t m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | ends hr => exact Turns.trace hr
  | shfl hw _ _ ih =>
    rw [ih, Turns.trace hw, List.reverse_append, List.flatten_append, List.append_assoc]

/-- **The canonical run's trace**: for every launch, contexts, threads, warps and memories, the
canonical run (`CanonRun`) puts its events, the last lane's run's in front, in front of the first
memory's trace (`WarpRun.trace`). -/
theorem CanonRun.trace {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {ks : List Nat}
    {m m' : Mem} {Es : List (List Event)} (h : CanonRun L c t ks m Es m') :
    m'.trace = Es.reverse.flatten ++ m.trace := by
  induction h with
  | nil => rfl
  | cons hw _ ih =>
    rw [ih, hw.trace, List.reverse_append, List.flatten_append, List.append_assoc]

/-- **A warp's run, in a grid.** For every launch `L` with blocks of `volume L.block > 0`
threads, contexts `c`, warp's first thread `k`, threads `t`, memories and grid `g` in which each
of the warp's threads `n` (`warpThreads`) runs `t n` and whose memory is `m`: a warp's run
(`WarpRun`) from `t` on `m` to `m'` is a run of grid steps from `g` to the grid with the warp's
threads done, every other thread unchanged, and memory `m'` (`Seq.ToWait.grid`, `Grid.fire_shfl`
at thread `k`, `Seq.grid`). -/
theorem WarpRun.grid {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m m' : Mem}
    {Es : List (List Event)} (hs : 0 < volume L.block) (hk : k % volume L.block % 32 = 0)
    (h : WarpRun L c k t m Es m') :
    ∀ {g : Grid}, (∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(warpThreads L k).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩ := by
  have hd := warpThreads_nodup L k
  induction h with
  | ends hr => exact fun hg hm => Seq.grid hr hd hg hm
  | @shfl t s m m₁ m' Es Es' u r hw hf _ ih =>
    intro g hg hm
    obtain ⟨_, hp₁⟩ := Seq.ToWait.grid (L := L) hw hd hg hm
    obtain ⟨mode, M, A, B, C, b, cl, d, hf⟩ := hf
    have hF := Grid.fire_shfl (L := L) (c := c) (n := k)
      (g := ⟨(warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads, m₁⟩)
      (mode := mode) (u := u) (M := M) (A := A) (B := B) (C := C) (b := b) (cl := cl) (d := d)
      (r := r) hs fun j hj => by
        obtain ⟨e, hM, hB, hC, hat, hr⟩ := hf j hj
        have hn : k + j ∈ warpThreads L k := List.mem_map_of_mem hj
        rw [hk, Nat.sub_zero]
        refine ⟨?_, hM, hB, hC, hat, hr⟩
        simp only [foldl_set_getElem?, hn, ↓reduceIte, hg _ hn, Option.map_some,
          Nat.add_sub_cancel_left, e]
    rw [hk, Nat.sub_zero] at hF
    have e2 : ∀ X : Array Status, (warpLanes L k).foldl
        (fun ts j => ts.set! (k + j) (.run ((u j).resume (r j)))) X =
        (warpThreads L k).foldl (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k))))) X :=
      fun X => by simp only [warpThreads, List.foldl_map, Nat.add_sub_cancel_left]
    rw [e2] at hF
    obtain ⟨_, hp₃⟩ := ih (g := ⟨(warpThreads L k).foldl
      (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k)))))
        ((warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads), m₁⟩)
      (fun n hn => by
        simp only [foldl_set_getElem?, hn, ↓reduceIte, hg _ hn, Option.map_some]) rfl
    have e3 : (warpThreads L k).foldl (fun ts n => ts.set! n .done) ((warpThreads L k).foldl
        (fun ts n => ts.set! n (.run ((u (n - k)).resume (r (n - k)))))
          ((warpThreads L k).foldl (fun ts n => ts.set! n (s (n - k))) g.threads)) =
        (warpThreads L k).foldl (fun ts n => ts.set! n .done) g.threads := by
      refine Array.ext_getElem? fun i => ?_
      by_cases hi : i ∈ warpThreads L k
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
        cases g.threads[i]? <;> rfl
      · simp only [foldl_set_getElem?, hi, ↓reduceIte]
    rw [e3] at hp₃
    exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans
      (.head ⟨k, .inr hF⟩ (Path.exists_iff.1 ⟨_, hp₃⟩)))

/-- **One more warp in turn, in a grid.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, threads `t`, statuses `s`, warp's first thread `k`,
warps' first threads `ks` and memories `m`, `m₁`, `m'`: if warp `k` (a warp's first thread) goes
by grid steps from every grid in which each of its threads `n` runs `t n` and whose memory is `m`
to that grid with each of them at `s n` and memory `m₁`, and the distinct warps `ks` go likewise
from `m₁` to `m'`, then the distinct warps `k :: ks` go likewise from `m` to `m'` (distinct warps
have disjoint threads, `warpThreads_iff`). `CanonRun.grid` and `CanonWait.grid`
(MojoProof/Sym/CanonBar.lean) take each warp in turn by it. -/
theorem warps_grid_cons {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {s : Nat → Status}
    {k : Nat} {ks : List Nat} {m m₁ m' : Mem} (hs : 0 < volume L.block)
    (hw : k % volume L.block % 32 = 0 → ∀ {g : Grid},
      (∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(warpThreads L k).foldl (fun ts n => ts.set! n (s n)) g.threads, m₁⟩)
    (ih : ∀ {g : Grid}, ks.Nodup → (∀ k ∈ ks, k % volume L.block % 32 = 0) →
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m₁ →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(ks.flatMap (warpThreads L)).foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩)
    {g : Grid} (hd : (k :: ks).Nodup) (hk : ∀ k' ∈ k :: ks, k' % volume L.block % 32 = 0)
    (hg : ∀ k' ∈ k :: ks, ∀ n ∈ warpThreads L k', g.threads[n]? = some (.run (t n)))
    (hm : g.mem = m) : ∃ i, Path (Grid.Step L c) i g
      ⟨((k :: ks).flatMap (warpThreads L)).foldl (fun ts n => ts.set! n (s n)) g.threads, m'⟩ := by
  have hk0 := hk k List.mem_cons_self
  obtain ⟨_, hp₁⟩ := hw hk0 (g := g) (fun n hn => hg k List.mem_cons_self n hn) hm
  obtain ⟨_, hp₂⟩ := ih (g := ⟨(warpThreads L k).foldl (fun ts n => ts.set! n (s n))
      g.threads, m₁⟩) (List.nodup_cons.1 hd).2
    (fun k' hk' => hk k' (List.mem_cons_of_mem _ hk')) (fun k' hk' n hn => by
      have hn' : n ∉ warpThreads L k := fun hn' => (List.nodup_cons.1 hd).1 (by
        rw [← (warpThreads_iff hs hk0).1 hn',
          (warpThreads_iff hs (hk k' (List.mem_cons_of_mem _ hk'))).1 hn]
        exact hk')
      simp only [foldl_set_getElem?, hn', ↓reduceIte]
      exact hg k' (List.mem_cons_of_mem _ hk') n hn) rfl
  rw [List.flatMap_cons, List.foldl_append]
  exact Path.exists_iff.2 ((Path.exists_iff.1 ⟨_, hp₁⟩).trans (Path.exists_iff.1 ⟨_, hp₂⟩))

/-- **The canonical run, in a grid.** For every launch `L` with blocks of `volume L.block > 0`
threads, contexts `c`, threads `t`, distinct warps' first threads `ks`, memories and grid `g` in
which each thread `n` of each warp of `ks` runs `t n` and whose memory is `m`: the canonical run
(`CanonRun`) from `t` on `m` to `m'` is a run of grid steps from `g` to the grid with the warps'
threads done, every other thread unchanged, and memory `m'` (`WarpRun.grid` for each warp in
turn, `warps_grid_cons`). -/
theorem CanonRun.grid {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} {ks : List Nat}
    {m m' : Mem} {Es : List (List Event)} (hs : 0 < volume L.block)
    (h : CanonRun L c t ks m Es m') :
    ∀ {g : Grid}, ks.Nodup → (∀ k ∈ ks, k % volume L.block % 32 = 0) →
      (∀ k ∈ ks, ∀ n ∈ warpThreads L k, g.threads[n]? = some (.run (t n))) → g.mem = m →
      ∃ i, Path (Grid.Step L c) i g
        ⟨(ks.flatMap (warpThreads L)).foldl (fun ts n => ts.set! n .done) g.threads, m'⟩ := by
  induction h with
  | nil m => exact fun _ _ _ hm => by subst hm; exact ⟨0, .nil _⟩
  | cons hw _ ih => exact warps_grid_cons (s := fun _ => .done) hs (fun hk {_} => hw.grid hs hk) ih

/-- **A warp's shuffles by invariants**, for every launch `L`, contexts `c`, warp's first thread
`k`, number `J` of the warp's shuffles, families `T i j` of thread predicates, `W i j` of status
predicates and `P i j` of memory predicates (phase `i`, lane `j`, `j` lanes done in the phase),
and relation `Q t m Es m'` of the warp's runs from threads `t` on `m` to `m'` with events `Es`
that a shuffle may start (the lanes in turn to their waits, the warp's shuffle, then a run of `Q`
from the resumed lanes, is a run of `Q`): if in each phase `i < J` each lane `j` of `T i j`, from
every memory of `P i j`, runs to a collective call (`ToWait`, in the context of thread `k + j`)
at a status of `W i j` leaving a memory of `P i (j + 1)`; from every lane-indexed statuses `s`
with `W i j (s j)` and memory of `P i` after all the lanes, the warp's shuffle fires (`WarpShfl`)
to threads and deliveries whose resumed lanes are of `T (i + 1)`, on a memory of `P (i + 1) 0`;
and threads whose lane `j` is of `T J j`, on every memory of `P J 0`, have a run of `Q` to a
memory of `P J` after all the lanes: then threads `t` whose lane `j`, thread `k + j`, is of
`T 0 j`, on a memory of `P 0 0`, have a run of `Q` to a memory of `P J` after all the lanes
(`Seq.ToWait.of_inv`, `Seq.ToWait.warp`, by induction on the phases left). `WarpRun.of_inv` and
`WarpWait.of_inv` (MojoProof/Sym/CanonBar.lean) are its cases. -/
theorem warp_of_inv {L : Launch} {c : Nat → Ctx} {k J : Nat} {T : Nat → Nat → Thread → Prop}
    {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    {Q : (Nat → Thread) → Mem → List (List Event) → Mem → Prop}
    (hQ : ∀ {t : Nat → Thread} {s : Nat → Status} {m m₁ m' : Mem} {Es Es' : List (List Event)}
      {u : Nat → Thread} {r : Nat → Option Val},
      Seq.ToWait c t (fun n => s (n - k)) (warpThreads L k) m Es m₁ → WarpShfl L c k s m₁ u r →
      Q (fun n => (u (n - k)).resume (r (n - k))) m₁ Es' m' → Q t m (Es ++ Es') m')
    (hw : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ t m, T i j t → P i j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W i j s ∧ P i (j + 1) m')
    (hf : ∀ i < J, ∀ s : Nat → Status, (∀ j ∈ warpLanes L k, W i j (s j)) →
      ∀ m, P i (warpLanes L k).length m → ∃ u r, WarpShfl L c k s m u r ∧
        (∀ j ∈ warpLanes L k, T (i + 1) j ((u j).resume (r j))) ∧ P (i + 1) 0 m)
    (he : ∀ (t : Nat → Thread) m, (∀ j ∈ warpLanes L k, T J j (t (k + j))) → P J 0 m →
      ∃ Es m', Q t m Es m' ∧ P J (warpLanes L k).length m')
    {t : Nat → Thread} (ht : ∀ j ∈ warpLanes L k, T 0 j (t (k + j))) {m : Mem}
    (hm : P 0 0 m) : ∃ Es m', Q t m Es m' ∧ P J (warpLanes L k).length m' := by
  have go : ∀ n i (t : Nat → Thread) m, i + n = J → (∀ j ∈ warpLanes L k, T i j (t (k + j))) →
      P i 0 m → ∃ Es m', Q t m Es m' ∧ P J (warpLanes L k).length m' := by
    intro n
    induction n with
    | zero =>
      intro i t m hi ht hm
      obtain rfl : i = J := by omega
      exact he t m ht hm
    | succ n ih =>
      intro i t m hi ht hm
      obtain ⟨s, Es, m₁, hs, hW, hm₁⟩ := Seq.ToWait.of_inv (c := fun j => c (k + j))
        (t := fun j => t (k + j)) (W := W i) (P := P i) (N := (warpLanes L k).length)
        (fun j hj m hm => hw i (by omega) j (mem_warpLanes.2 hj) _ m
          (ht j (mem_warpLanes.2 hj)) hm) hm
      obtain ⟨u, r, hF, ht', hm₂⟩ := hf i (by omega) s (fun j hj => hW j (mem_warpLanes.1 hj))
        m₁ hm₁
      obtain ⟨Es', m', hS, hP⟩ := ih (i + 1) (fun n => (u (n - k)).resume (r (n - k))) m₁
        (by omega) (fun j hj => by simpa only [Nat.add_sub_cancel_left] using ht' j hj) hm₂
      exact ⟨Es ++ Es', m', hQ (Seq.ToWait.warp hs) hF hS, hP⟩
  exact go J 0 t m (Nat.zero_add J) ht hm

/-- **A warp's run by invariants.** For every launch `L`, contexts `c`, warp's first thread `k`,
number `J` of the warp's shuffles, and families `T i j` of thread predicates, `W i j` of status
predicates and `P i j` of memory predicates (phase `i`, lane `j`, `j` lanes done in the phase):
if in each phase `i < J` each lane `j` of `T i j`, from every memory of `P i j`, runs to a
collective call (`ToWait`, in the context of thread `k + j`) at a status of `W i j` leaving a
memory of `P i (j + 1)`; from every lane-indexed statuses `s` with `W i j (s j)` and memory of
`P i` after all the lanes, the warp's shuffle fires (`WarpShfl`) to threads and deliveries
whose resumed lanes are of `T (i + 1)`, on a memory of `P (i + 1) 0`; and in phase `J` each lane
of `T J j` from every memory of `P J j` runs to its end (`Runs`) leaving a memory of
`P J (j + 1)`: then threads `t` whose lane `j`, thread `k + j`, is of `T 0 j`, on a memory of
`P 0 0`, have a warp's run (`WarpRun`) to a memory of `P J` after all the lanes
(`warp_of_inv`, the last phase by `Seq.of_inv` and `Seq.warp`). -/
theorem WarpRun.of_inv {L : Launch} {c : Nat → Ctx} {k J : Nat} {T : Nat → Nat → Thread → Prop}
    {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    (hw : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ t m, T i j t → P i j m →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ W i j s ∧ P i (j + 1) m')
    (hf : ∀ i < J, ∀ s : Nat → Status, (∀ j ∈ warpLanes L k, W i j (s j)) →
      ∀ m, P i (warpLanes L k).length m → ∃ u r, WarpShfl L c k s m u r ∧
        (∀ j ∈ warpLanes L k, T (i + 1) j ((u j).resume (r j))) ∧ P (i + 1) 0 m)
    (he : ∀ j ∈ warpLanes L k, ∀ t m, T J j t → P J j m →
      ∃ m', Runs (c (k + j)) t m m' ∧ P J (j + 1) m')
    {t : Nat → Thread} (ht : ∀ j ∈ warpLanes L k, T 0 j (t (k + j))) {m : Mem}
    (hm : P 0 0 m) : ∃ Es m', WarpRun L c k t m Es m' ∧ P J (warpLanes L k).length m' := by
  refine warp_of_inv (Q := WarpRun L c k) WarpRun.shfl hw hf (fun t m ht hm => ?_) ht hm
  obtain ⟨Es, m', hs, hP⟩ := Seq.of_inv (c := fun j => c (k + j)) (t := fun j => t (k + j))
    (P := P J) (N := (warpLanes L k).length)
    (fun j hj m hm => he j (mem_warpLanes.2 hj) _ m (ht j (mem_warpLanes.2 hj)) hm) hm
  exact ⟨Es, m', .ends (Seq.warp hs), hP⟩

/-- **A list of waits as an indexed family**, for every function `fn`, block `l`, start `n`,
blocks `lbl`, waits `W` and list `ws` of waits: if `W (n + i)` is `ws`'s `i`-th wait and
`lbl (n + i)` is `l` for every `i` below `ws`'s length, then `ws`'s `Piece.Wait.via` pairs at `l`
(as `RunsVia.of_fires` concludes) are those of `W i` at `lbl i` for `i` from `n` to
`n + ws.length - 1` (`List.range'`), as `WarpRun.of_waits` takes them (`List.range J` is
`List.range' 0 J`). The start lets a second block's waits follow a first's (`List.range'_append`).
By `List.ext_getElem`. -/
theorem Piece.Wait.map_via {fn : Func} {l n : Nat} {lbl : Nat → Nat} {W : Nat → Piece.Wait}
    {ws : List Piece.Wait} (hW : ∀ i (h : i < ws.length), W (n + i) = ws[i])
    (hl : ∀ i < ws.length, lbl (n + i) = l) :
    ws.map (Piece.Wait.via fn l) = (List.range' n ws.length).map fun i => (W i).via fn (lbl i) := by
  refine List.ext_getElem (by simp) fun i h1 _ => ?_
  have hi : i < ws.length := by simpa using h1
  simp only [List.getElem_map, List.getElem_range', Nat.one_mul]
  rw [hW i hi, hl i hi]

/-- **Two blocks' waits as one indexed family**, for every function `fn`, blocks `l₁`, `l₂`,
lengths `p`, `n`, wait `d` and lists `a`, `b` of `p` and `n` waits: `a`'s `Piece.Wait.via` pairs
at `l₁` followed by `b`'s at `l₂` are those of the `i`-th wait of `a ++ b` (`List.getD` with
default `d`) at `l₁` for `i < p` and at `l₂` after, for `i` below `p + n` (`List.range`), as
`WarpRun.of_waits` takes them. By `Piece.Wait.map_via` at starts 0 and `p`. -/
theorem Piece.Wait.map_via_append {fn : Func} {l₁ l₂ p n : Nat} {d : Piece.Wait}
    {a b : List Piece.Wait} (ha : a.length = p) (hb : b.length = n) :
    a.map (Piece.Wait.via fn l₁) ++ b.map (Piece.Wait.via fn l₂) =
      (List.range (p + n)).map fun i =>
        ((a ++ b).getD i d).via fn (if i < p then l₁ else l₂) := by
  subst ha hb
  have e1 := Piece.Wait.map_via (ws := a) (n := 0) (fn := fn) (l := l₁)
    (W := fun i => (a ++ b).getD i d) (lbl := fun i => if i < a.length then l₁ else l₂)
    (fun i hi => by
      simp only [Nat.zero_add, List.getD_eq_getElem?_getD, List.getElem?_append_left hi,
        List.getElem?_eq_getElem hi, Option.getD_some])
    (fun i hi => by split <;> omega)
  have e2 := Piece.Wait.map_via (ws := b) (n := a.length) (fn := fn) (l := l₂)
    (W := fun i => (a ++ b).getD i d) (lbl := fun i => if i < a.length then l₁ else l₂)
    (fun i hi => by
      rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega),
        Nat.add_sub_cancel_left, List.getElem?_eq_getElem hi, Option.getD_some])
    (fun i hi => by split <;> omega)
  rw [e1, e2, ← List.map_append, List.range_eq_range']
  congr 1
  simpa using List.range'_append_1 (s := 0) (m := a.length) (n := b.length)

/-- For every layout `l`, memory `m`, type `t` and delivery `v`, `withAttrs` with no attribute
keeps the delivery: what `WarpShfl` and `WarpRun.of_waits` ask of a shuffle whose declaration
puts no attribute on its result. -/
theorem withAttrs_mapM_nil (l : Layout) (m : Mem) (t : Ty) (v : Option Val) :
    v.mapM (withAttrs l m t []) = .ok v := by
  cases v with
  | none => rfl
  | some v => simp only [Option.mapM, withAttrs_nil]; rfl

/-- **A warp's run from its lanes' runs through their waits**, for every launch `L`, contexts
`c`, warp `k`, function `fn`, blocks `lbl`, waits `W` (lane `j`'s `i`-th is `W i j`, in block
`lbl i`, for `i < J`), modes `mo`, offered values `X`, memories `M` and threads `t`. The
premises:

* lane `j` runs from `t (k + j)` on `M 0 j` through the waits `W 0 j`, ..., `W (J - 1) j`
  (`RunsVia` with `Piece.Wait.via`'s predicates, as `RunsVia.of_fires` concludes) and then to its
  end on `M J (j + 1)`;
* at its `i`-th wait each lane calls the shuffle of mode `mo i` at lane 0's position, with a full
  mask, offered value `X i j` and lane and clamp operands that are words. It waits on memory
  `M i (j + 1)`, and is delivered what `Grid.fire` delivers on `M (i + 1) j`: `shflVal` of the
  offered values at `shflSource`, under the result attributes of every shuffle's declaration the
  lane's call can find by name (`withAttrs`, on the memory after the phase's last lane);
* phase `i + 1` starts on the memory phase `i`'s last lane leaves.

Then the warp runs from `t` on `M 0 0` (`WarpRun`) to `M J` after all its lanes, and each of its
shuffles' deliveries is `Grid.fire`'s (`WarpShfl`). Proof: `WarpRun.of_inv` with lane `j` in phase
`i` running through its waits from the `i`-th. The waits' calls, arguments and positions give
`WarpShfl`'s premises, and the callee of a wait is the declaration its call finds (`step_wait`),
so the delivery under its attributes is the one `hW` gives. With no result attribute, `withAttrs`
keeps the value (`withAttrs_mapM_nil`). -/
theorem WarpRun.of_waits {L : Launch} {c : Nat → Ctx} {k J : Nat} {fn : Func} {lbl : Nat → Nat}
    {W : Nat → Nat → Piece.Wait} {mo : Nat → Shfl} {X : Nat → Nat → Val}
    {M : Nat → Nat → Mem} {t : Nat → Thread}
    (hr : ∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (· = M J (j + 1))
      ((List.range J).map fun i => (W i j).via fn (lbl i)) (t (k + j)) (M 0 j))
    (hW : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).call.intr = .shfl (mo i) ∧
      (W i j).pos = (W i 0).pos ∧ ∃ Mk Bv Cv b cl, (W i j).args = [Mk, X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i)) →
          (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j b cl))).mapM
            (withAttrs (c k).prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
            .ok (W i j).dlv.1)
    (hm : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).mem = M i (j + 1) ∧ (W i j).dlv.2 = M (i + 1) j)
    (h0 : ∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) :
    ∃ Es, WarpRun L c k t (M 0 0) Es (M J (warpLanes L k).length) := by
  have hl : ∀ i < J, ∀ j, ((List.range J).map fun i => (W i j).via fn (lbl i)).drop i =
      (W i j).via fn (lbl i) ::
        ((List.range J).map fun i => (W i j).via fn (lbl i)).drop (i + 1) := by
    intro i hi j
    rw [List.drop_eq_getElem_cons (by simpa using hi)]
    simp
  obtain ⟨Es, m', h, rfl⟩ := WarpRun.of_inv (L := L) (c := c) (k := k) (J := J) (t := t)
    (T := fun i j t => RunsVia (c (k + j)) (· = M J (j + 1))
      (((List.range J).map fun i => (W i j).via fn (lbl i)).drop i) t (M i j))
    (W := fun i j s => ∃ u e, s = .wait u (W i j).call.intr (W i j).args e ∧
      u.at = some (fn.name, lbl i, (W i j).pos) ∧
      (∃ g, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e ∧
        (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i))) ∧
      RunsVia (c (k + j)) (· = M J (j + 1))
        (((List.range J).map fun i => (W i j).via fn (lbl i)).drop (i + 1))
        (u.resume (W i j).dlv.1) (M (i + 1) j))
    (P := fun i j m => m = M i j)
    (fun i hi j hj t m ht hm => by
      subst hm
      rw [hl i hi j] at ht
      obtain ⟨u, x, xs, e, m₁, htw, ⟨hat, rfl, rfl, rfl⟩, hrest⟩ := ht
      have hst : step (c (k + j)) u (W i j).mem = .ok (.wait (W i j).call.intr (W i j).args e) := by
        obtain ⟨u', x', xs', e', hs, -, hst⟩ := htw
        obtain ⟨rfl, rfl, rfl, rfl⟩ := Status.wait.inj hs
        exact hst
      obtain ⟨-, -, -, -, -, -, g, -, -, -, -, -, hfind, -, hlk⟩ := step_wait hst
      exact ⟨_, _, htw, ⟨u, e, rfl, hat, ⟨g, hfind, hlk.trans (congrArg some (hW i hi j hj).1)⟩,
        (hm i hi j hj).2 ▸ hrest⟩, (hm i hi j hj).1⟩)
    (fun i hi s hs m hm => by
      subst hm
      refine ⟨fun j => match s j with | .wait u _ _ _ => u | _ => t 0, fun j => (W i j).dlv.1,
        ⟨mo i, fun j => ((W i j).args[0]?).getD Val.poison, X i,
          fun j => ((W i j).args[2]?).getD Val.poison, fun j => ((W i j).args[3]?).getD Val.poison,
          fun j => ((((W i j).args[2]?).getD Val.poison).word?).getD 0,
          fun j => ((((W i j).args[3]?).getD Val.poison).word?).getD 0,
          fun j => match s j with | .wait _ _ _ e => e | _ => fn, fun j hj => ?_⟩,
        fun j hj => ?_, (h0 i hi).symm⟩
      · have h0' : 0 ∈ warpLanes L k := mem_warpLanes.2 (Nat.lt_of_le_of_lt (Nat.zero_le _)
          (mem_warpLanes.1 hj))
        obtain ⟨u, e, hsj, hat, ⟨g, hfind, hlk⟩, -⟩ := hs j hj
        obtain ⟨u₀, e₀, hs0, hat0, -, -⟩ := hs 0 h0'
        obtain ⟨hc, hp, Mk, Bv, Cv, b, cl, ha, hMk, hB, hC, hdl⟩ := hW i hi j hj
        simp only [hsj, hs0, hc, ha, List.getElem?_cons_zero, List.getElem?_cons_succ,
          Option.getD_some, hB, hC]
        exact ⟨trivial, hMk, trivial, trivial, by rw [hat, hat0, hp], hdl g e hfind hlk⟩
      · obtain ⟨u, e, hsj, -, -, hrest⟩ := hs j hj
        simp only [hsj]
        exact hrest)
    (fun j hj t m ht hm => by
      subst hm
      rw [List.drop_eq_nil_of_le (by simp)] at ht
      exact ht)
    (fun j hj => by simpa only [List.drop_zero] using hr j hj) rfl
  exact ⟨Es, h⟩

/-- **The canonical run by invariants.** For every launch `L`, contexts `c`, threads `t`, warps'
first threads `ks` and family `P` of memory predicates indexed by the number of warps that have
run: if each warp `ks[i]`, from every memory of `P i`, has a run (`WarpRun`, which
`WarpRun.of_inv` gives) from `t` to a memory of `P (i + 1)`, then the warps of `ks` have a
canonical run (`CanonRun`) from every memory of `P 0` to a memory of `P ks.length`. -/
theorem CanonRun.of_inv {L : Launch} {c : Nat → Ctx} {t : Nat → Thread} :
    ∀ {P : Nat → Mem → Prop} {ks : List Nat}, (∀ i (hi : i < ks.length), ∀ m, P i m →
      ∃ Es m', WarpRun L c ks[i] t m Es m' ∧ P (i + 1) m') →
    ∀ {m : Mem}, P 0 m → ∃ Es m', CanonRun L c t ks m Es m' ∧ P ks.length m'
  | _, [], _, m, h0 => ⟨[], m, .nil m, h0⟩
  | P, k :: ks, h, m, h0 => by
    obtain ⟨Es, m₁, hw, hm₁⟩ := h 0 (by simp) m h0
    obtain ⟨Es', m', hc, hm'⟩ := CanonRun.of_inv (P := fun i => P (i + 1)) (ks := ks)
      (fun i hi m hm => h (i + 1) (by simp only [List.length_cons]; omega) m hm) hm₁
    exact ⟨Es ++ Es', m', .cons hw hc, hm'⟩

end MojoProof.Sym
