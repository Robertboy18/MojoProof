import MojoProof.Sym.SegTrace

/-!
# Schedules by invariants: threads as chains of segments separated by collectives

Every result here is for every program, launch and contexts.

A thread of a kernel with collective calls runs to its first collective, is resumed by the
collective's fire, runs to the next one, and last runs to its end. A schedule (`Sched`,
MojoProof/Sym/SchedWait.lean) runs the threads in turn to their waits, fires the collectives and
goes on from the resumed threads. Its premises are about the threads and memories it reaches,
which a proof does not compute; here they are given by invariants.

* `Seq.ToWait.of_inv`: threads `0` to `N - 1`, each of which from every memory of `P k` runs to
  a wait at a status of `W k` leaving a memory of `P (k + 1)`, run in turn to their waits
  (`Seq.ToWait`) at statuses of `W` from `P 0` to `P N`. Each thread's status is the one its own
  run gives.
* `Sched.of_inv`: a schedule of `J` phases by invariants `T j n` on thread `n`'s thread, `W j n`
  on its status and `P j k` on the memory after `k` threads have run phase `j`: each phase's runs
  to waits keep the invariants, the phase's collectives fire (`Fires`) from statuses of `W j` to
  threads of `T (j + 1)`, and the last phase's runs reach the ends. `Sched.start_sound_inv`: the
  start's grid is sound (`Grid.Sound`) when its threads (`Grid.thread`) and memory meet phase
  0's invariants and every memory of `P J N` has a trace with no race that keeps the promise of
  `!invariant.load` and an observation meeting `R`.
* `Fires.barriers_at`: statuses that each wait at the barrier with the block's number below 16,
  each thread at its block's instruction, fire, every thread resumed with no value
  (`Fires.barriers`). `Fires.bfly`: statuses that each wait at a butterfly shuffle with the full
  mask, offset `o < 32` and clamp 31, offering `A n`, each thread at its warp's instruction, with
  a callee whose return attributes keep the value and the lane read in the block, fire, thread
  `n` resumed with `A` of thread `n - p + (p ^^^ o)`, `p` its lane (`Fires.shfls`,
  `shflSource_bfly`); the values `bflyRoundsAt_of_shfl` takes.
* `Seg.Through.wait`: a thread's segments for every delivery (`Seg.Through`, which `Seg.through`
  gives) and the first segment's obligations give the run to the first collective at the
  instruction `(f.fn.name, lbl, f.pc + S.len)`, with the registers and arguments the summary
  gives, and for every delivered value and memory the other segments from the resumed thread,
  for every later delivery: the run to the wait does not depend on the deliveries
  (`ToWait.det`), so a schedule picks them after the phase. Threads at one block and position
  wait at one instruction, the premise of both fires.

The fires and values are the semantics' (`Grid.fire`, `shflSource`), not a model of them.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **Threads in turn to their waits by an invariant.** For every contexts `c`, threads `t`,
family `W` of status predicates and family `P` of memory predicates indexed by the number of
threads that have run, and number `N`: if each thread `k < N` from every memory of `P k` runs to
a collective call (`ToWait`) at a status of `W k`, leaving a memory of `P (k + 1)`, then threads
`0` to `N - 1` run in turn to their waits (`Seq.ToWait`) at statuses `s` with `W n (s n)`, from
every memory of `P 0` to a memory of `P N`. -/
theorem Seq.ToWait.of_inv {c : Nat → Ctx} {t : Nat → Thread} {W : Nat → Status → Prop}
    {P : Nat → Mem → Prop} {N : Nat}
    (h : ∀ k < N, ∀ m, P k m → ∃ s m', Sym.ToWait (c k) (t k) m s m' ∧ W k s ∧ P (k + 1) m')
    {m : Mem} (h0 : P 0 m) :
    ∃ s Es m', Seq.ToWait c t s (List.range N) m Es m' ∧ (∀ n < N, W n (s n)) ∧ P N m' := by
  have go : ∀ r k m, k + r = N → P k m → ∃ s Es m', Seq.ToWait c t s (List.range' k r) m Es m' ∧
      (∀ n, k ≤ n → n < N → W n (s n)) ∧ P N m' := by
    intro r
    induction r with
    | zero =>
      intro k m hk hm
      obtain rfl : k = N := by omega
      exact ⟨fun _ => .done, [], m, .nil m, fun n h1 h2 => absurd h2 (by omega), hm⟩
    | succ r ih =>
      intro k m hk hm
      obtain ⟨s₀, m₁, hr, hW, hm₁⟩ := h k (by omega) m hm
      obtain ⟨s, Es, m', hs, hWs, hm'⟩ := ih (k + 1) m₁ (by omega) hm₁
      obtain ⟨E, e⟩ := hr.trace
      refine ⟨fun n => if n = k then s₀ else s n, E :: Es, m', ?_, fun n h1 h2 => ?_, hm'⟩
      · rw [List.range'_succ]
        refine .cons (show Sym.ToWait (c k) (t k) m (if k = k then s₀ else s k) m₁ by
          rw [ite_eq_left rfl]; exact hr) e (Turns.imp hs (P := fun _ => True)
            (fun n hn m₁ m₂ hr _ => ⟨?_, trivial⟩) trivial).1
        have hn : n ≠ k := by
          have := List.mem_range'_1.1 hn
          omega
        show Sym.ToWait (c n) (t n) m₁ (if n = k then s₀ else s n) m₂
        rw [ite_eq_right hn]
        exact hr
      · dsimp only
        by_cases e : n = k
        · subst e
          rw [ite_eq_left rfl]
          exact hW
        · rw [ite_eq_right e]
          exact hWs n (by omega) h2
  rw [List.range_eq_range']
  obtain ⟨s, Es, m', hs, hW, hP⟩ := go N 0 m (Nat.zero_add N) h0
  exact ⟨s, Es, m', hs, fun n hn => hW n (Nat.zero_le n) hn, hP⟩

/-- **A schedule by invariants.** For every launch `L`, contexts `c`, number `N` of threads,
number `J` of phases with collectives, and families `T j n` of thread predicates, `W j n` of
status predicates and `P j k` of memory predicates (phase `j`, thread `n`, `k` threads done in
the phase): if in each phase `j < J` each thread `n < N` of `T j n`, from every memory of
`P j n`, runs to a collective call (`ToWait`) at a status of `W j n` leaving a memory of
`P j (n + 1)`; from every statuses `s` with `W j n (s n)` and memory of `P j N` the phase's
collectives fire (`Fires`) to threads of `T (j + 1) n` on a memory of `P (j + 1) 0`; and in
phase `J` each thread of `T J n` from every memory of `P J n` runs to its end (`Runs`) leaving a
memory of `P J (n + 1)`: then threads `t` of `T 0` on a memory of `P 0 0` have a schedule
(`Sched`) to a memory of `P J N` (`Seq.ToWait.of_inv`, `Seq.of_inv`, by induction on the phases
left). -/
theorem Sched.of_inv {L : Launch} {c : Nat → Ctx} {N J : Nat} {T : Nat → Nat → Thread → Prop}
    {W : Nat → Nat → Status → Prop} {P : Nat → Nat → Mem → Prop}
    (hw : ∀ j < J, ∀ n < N, ∀ t m, T j n t → P j n m →
      ∃ s m', ToWait (c n) t m s m' ∧ W j n s ∧ P j (n + 1) m')
    (hf : ∀ j < J, ∀ s : Nat → Status, (∀ n < N, W j n (s n)) → ∀ m, P j N m →
      ∃ t' m', Fires L c N s m t' m' ∧ (∀ n < N, T (j + 1) n (t' n)) ∧ P (j + 1) 0 m')
    (he : ∀ n < N, ∀ t m, T J n t → P J n m → ∃ m', Runs (c n) t m m' ∧ P J (n + 1) m')
    {t : Nat → Thread} (ht : ∀ n < N, T 0 n (t n)) {m : Mem} (hm : P 0 0 m) :
    ∃ m', Sched L c N t m m' ∧ P J N m' := by
  have go : ∀ r j (t : Nat → Thread) m, j + r = J → (∀ n < N, T j n (t n)) → P j 0 m →
      ∃ m', Sched L c N t m m' ∧ P J N m' := by
    intro r
    induction r with
    | zero =>
      intro j t m hj ht hm
      obtain rfl : j = J := by omega
      obtain ⟨Es, m', hs, hP⟩ := Seq.of_inv (c := c) (t := t) (P := P j)
        (fun k hk m hm => he k hk (t k) m (ht k hk) hm) hm
      exact ⟨m', .ends hs, hP⟩
    | succ r ih =>
      intro j t m hj ht hm
      obtain ⟨s, Es, m₁, hs, hW, hm₁⟩ := Seq.ToWait.of_inv (c := c) (t := t) (W := W j)
        (P := P j) (fun k hk m hm => hw j (by omega) k hk (t k) m (ht k hk) hm) hm
      obtain ⟨t', m₂, hF, ht', hm₂⟩ := hf j (by omega) s hW m₁ hm₁
      obtain ⟨m', hS, hP⟩ := ih (j + 1) t' m₂ (by omega) ht' hm₂
      exact ⟨m', .wait hs hF hS, hP⟩
  exact go J 0 t m (Nat.zero_add J) ht hm

/-- **A start through collective calls, sound by invariants.** For every program, kernel `fn`,
launch `L`, arguments, address choice and oracle whose start (`Grid.start`) gives grid `g₀` and
contexts `c`, on a caller's memory `m` meeting `Mem.BytesIn`, every observation `obs` that reads
only the blocks, number `J` of phases with collectives and invariants `T`, `W`, `P` as in
`Sched.of_inv` over the `N = volume L.grid * volume L.block` threads (`Grid.start_size`): if
each thread `n` of `g₀` (`Grid.thread`) meets `T 0 n`, `g₀`'s memory meets `P 0 0`, the phases'
runs, fires and last runs keep the invariants (`Sched.of_inv`'s premises), and every memory `m'`
of `P J N` has a trace that keeps the promise of `!invariant.load` (the core's `GPUProof.kept`
at `sig`), that has no data race (the core's `racy` at `sig`) when it has the premises of
`racy_iff`, and has `obs m' = some y` with `R y`, then `g₀` is sound (`Grid.Sound`):
`Sched.of_inv` and `Sched.start_sound`. -/
theorem Sched.start_sound_inv {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') {J : Nat}
    {T : Nat → Nat → Thread → Prop} {W : Nat → Nat → Status → Prop}
    {P : Nat → Nat → Mem → Prop}
    (ht : ∀ n < volume L.grid * volume L.block, T 0 n (Grid.thread g₀ n)) (h0 : P 0 0 g₀.mem)
    (hw : ∀ j < J, ∀ n < volume L.grid * volume L.block, ∀ t m, T j n t → P j n m →
      ∃ s m', ToWait (c n) t m s m' ∧ W j n s ∧ P j (n + 1) m')
    (hf : ∀ j < J, ∀ s : Nat → Status, (∀ n < volume L.grid * volume L.block, W j n (s n)) →
      ∀ m, P j (volume L.grid * volume L.block) m →
      ∃ t' m', Fires L c (volume L.grid * volume L.block) s m t' m' ∧
        (∀ n < volume L.grid * volume L.block, T (j + 1) n (t' n)) ∧ P (j + 1) 0 m')
    (he : ∀ n < volume L.grid * volume L.block, ∀ t m, T J n t → P J n m →
      ∃ m', Runs (c n) t m m' ∧ P J (n + 1) m')
    (hb : ∀ m', P J (volume L.grid * volume L.block) m' →
      ((∀ a, Sem.Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
          a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true)
    (hy : ∀ m', P J (volume L.grid * volume L.block) m' → ∃ y, obs m' = some y ∧ R y) :
    Grid.Sound L c g₀ obs R := by
  have hN := Grid.start_size h
  rw [← hN] at ht hw hf he hy
  obtain ⟨m', hs, hP⟩ := Sched.of_inv (L := L) hw hf he ht h0
  obtain ⟨y, hy, hR⟩ := hy m' hP
  have hb' := hb m' (by rwa [← hN])
  exact Sched.start_sound h hm hO hs hb'.1 hb'.2 hy hR

/-- **The barriers from the statuses' facts.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, number `B` of blocks, `N = B * volume L.block`,
statuses `s`, numbers `bar` and instructions `a` by block, and memory `m`: if every thread
`n < N` waits (`s n`), from a thread `u` at the instruction `a (n / volume L.block)` of its
block, at a barrier call whose one argument is the number `bar (n / volume L.block) < 16`, then
the blocks' barriers take the threads, each resumed with no value (`Thread.resume`), to `m` with
the blocks' `.barrier`s logged in turn (`Fires.barriers`). -/
theorem Fires.barriers_at {L : Launch} {c : Nat → Ctx} {N B : Nat} {s : Nat → Status}
    {bar : Nat → Nat} {a : Nat → Option (String × Nat × Nat)} {m : Mem}
    (hs : 0 < volume L.block) (hN : N = B * volume L.block)
    (hw : ∀ n < N, ∃ u x d, s n = .wait u .barrier [x] d ∧
      x.word? = some (bar (n / volume L.block)) ∧ bar (n / volume L.block) < 16 ∧
      u.at = a (n / volume L.block)) :
    ∃ t', Fires L c N s m t' ((List.range B).foldl (fun m b => m.log (.barrier b)) m) ∧
      ∀ n < N, ∃ u i as d, s n = .wait u i as d ∧ t' n = u.resume none := by
  have hw' : ∀ n, ∃ (u : Thread) (x : Val) (d : Func), n < N → s n = .wait u .barrier [x] d ∧
      x.word? = some (bar (n / volume L.block)) ∧ bar (n / volume L.block) < 16 ∧
      u.at = a (n / volume L.block) := fun n => by
    by_cases hn : n < N
    · obtain ⟨u, x, d, hu⟩ := hw n hn
      exact ⟨u, x, d, fun _ => hu⟩
    · exact ⟨⟨[], 0⟩, .poison, default, fun h => absurd h hn⟩
  choose u x d hu using hw'
  refine ⟨fun n => (u n).resume none, fun g hsz hg hm => ?_,
    fun n hn => ⟨u n, _, _, _, (hu n hn).1, rfl⟩⟩
  refine Fires.barriers (c := c) (u := u) (x := x) (d := d) (bar := bar) (m := m) hs hN
    (fun n hn => ⟨(hu n hn).2.1, (hu n hn).2.2.1, ?_⟩) g hsz
    (fun n hn => (hg n hn).trans (congrArg some (hu n hn).1)) hm
  rw [(hu n hn).2.2.2, (hu _ (Nat.lt_of_le_of_lt (Nat.div_mul_le_self n _) hn)).2.2.2,
    Nat.mul_div_cancel _ hs]

/-- **The butterfly shuffles from the statuses' facts.** For every launch `L` with blocks of
`volume L.block > 0` threads, contexts `c`, number `B` of blocks, `N = B * volume L.block`,
statuses `s`, offset `o < 32`, values `A` by thread, instructions `a` by warp and memory `m`:
write `p n = n % volume L.block % 32` for thread `n`'s lane. If every thread `n < N` waits
(`s n`), from a thread `u` at the instruction `a ((n - p n) / 32)` of its warp, at a butterfly
shuffle (`.shfl .bfly`) with the full member mask `2^32 - 1`, value `A n`, offset `o` and clamp
31, whose callee returns a type that is not a vector with return attributes that are all
`Attr.args`, and the lane it reads, `p n ^^^ o`, is in its block, then the warps' shuffles take
each thread `n`, resumed with the value `A (n - p n + (p n ^^^ o))` of that lane
(`Thread.resume`), to the same memory `m` (`Fires.shfls`, `shflSource_bfly`, `withAttrs_args`). -/
theorem Fires.bfly {L : Launch} {c : Nat → Ctx} {N B o : Nat} {s : Nat → Status}
    {A : Nat → Val} {a : Nat → Option (String × Nat × Nat)} {m : Mem}
    (hs : 0 < volume L.block) (hN : N = B * volume L.block) (ho : o < 32)
    (hw : ∀ n < N, ∃ u M O C d, s n = .wait u (.shfl .bfly) [M, A n, O, C] d ∧
      M.word? = some (2 ^ 32 - 1) ∧ O.word? = some o ∧ C.word? = some 31 ∧
      u.at = a ((n - n % volume L.block % 32) / 32) ∧ (d.ret matches .vec ..) = false ∧
      d.retAttrs.all (· matches .args ..) = true ∧
      n % volume L.block - n % volume L.block % 32 + (n % volume L.block % 32 ^^^ o) <
        volume L.block) :
    ∃ t', Fires L c N s m t' m ∧ ∀ n < N, ∃ u i as d, s n = .wait u i as d ∧
      t' n = u.resume (some (A (n - n % volume L.block % 32 +
        (n % volume L.block % 32 ^^^ o)))) := by
  have hw' : ∀ n, ∃ (u : Thread) (M O C : Val) (d : Func), n < N →
      s n = .wait u (.shfl .bfly) [M, A n, O, C] d ∧
      M.word? = some (2 ^ 32 - 1) ∧ O.word? = some o ∧ C.word? = some 31 ∧
      u.at = a ((n - n % volume L.block % 32) / 32) ∧ (d.ret matches .vec ..) = false ∧
      d.retAttrs.all (· matches .args ..) = true ∧
      n % volume L.block - n % volume L.block % 32 + (n % volume L.block % 32 ^^^ o) <
        volume L.block := fun n => by
    by_cases hn : n < N
    · obtain ⟨u, M, O, C, d, hu⟩ := hw n hn
      exact ⟨u, M, O, C, d, fun _ => hu⟩
    · exact ⟨⟨[], 0⟩, .poison, .poison, .poison, default, fun h => absurd h hn⟩
  choose u M O C d hu using hw'
  refine ⟨fun n => (u n).resume (some (A (n - n % volume L.block % 32 +
    (n % volume L.block % 32 ^^^ o)))), fun g hsz hg hm => ?_,
    fun n hn => ⟨u n, _, _, _, (hu n hn).1, rfl⟩⟩
  refine Fires.shfls (c := c) (u := u) (M := M) (A := A) (O := O) (C := C)
    (b := fun _ => o) (cl := fun _ => 31) (d := d) (m := m) hs hN
    (fun n hn => ⟨(hu n hn).2.1, (hu n hn).2.2.1, (hu n hn).2.2.2.1, ?_, ?_⟩) g hsz
    (fun n hn => (hg n hn).trans (congrArg some (hu n hn).1)) hm
  · -- the warp's first thread is at the warp's instruction
    have hp : (n - n % volume L.block % 32) % volume L.block % 32 = 0 := by
      have h1 := Nat.mod_add_div n (volume L.block)
      have h2 := Nat.mod_lt n hs
      rw [show n - n % volume L.block % 32 = n % volume L.block - n % volume L.block % 32 +
          volume L.block * (n / volume L.block) by omega, Nat.add_mul_mod_self_left,
        Nat.mod_eq_of_lt (a := n % volume L.block - n % volume L.block % 32)
          (b := volume L.block) (by omega)]
      omega
    have hk : n - n % volume L.block % 32 < N := by omega
    rw [(hu n hn).2.2.2.2.1, (hu _ hk).2.2.2.2.1, hp, Nat.sub_zero]
  · -- the lane read is the warp's lane `p ^^^ o`, and the callee keeps the value
    obtain ⟨-, -, -, -, -, hret, hatt, hin⟩ := hu n hn
    have hl : n % volume L.block % 32 < 32 := Nat.mod_lt _ (by decide)
    have hx : n % volume L.block % 32 ^^^ o < 32 := Nat.xor_lt_two_pow (n := 5) hl ho
    have hmem : n % volume L.block % 32 ^^^ o ∈ warpLanes L n := by
      simp only [warpLanes, List.mem_filter, List.mem_range, decide_eq_true_eq]
      exact ⟨hx, hin⟩
    simp only [shflSource_bfly hl ho, shflVal, hmem, ↓reduceIte, Option.mapM,
      withAttrs_args _ _ hret hatt]
    rfl

/-- **A thread's segments, the first run to a wait and every delivery after it.** For every
context `c`, block `lbl`, frames `rest`, summaries `L`, `S` and `Ss`, thread `t`, memory `m` and
frame `f`: if the thread runs the segments `S :: Ss` and then `L` for every delivery
(`Seg.Through`, which `Seg.through` gives for every `w`) and `S`'s obligations hold under `f`'s
entry valuation, then the thread runs (`ToWait`) to the call of `S`'s collective, waiting at the
frame `fe` with step count `t.k + S.len` at the instruction `(f.fn.name, lbl, f.pc + S.len)`,
whose registers are the ones `S` gives (`regVal`), on the arguments `ws` `S`'s terms give; and
for every delivered value `v` and memory `m'` the thread resumed there with `v`, with innermost
frame `fr`, runs the other segments from `m'` for every later delivery. The run to the wait is
the same for every delivery (`ToWait.det`). -/
theorem Seg.Through.wait {c : Ctx} {lbl : Nat} {rest : List Frame} {L : Summary}
    {S : SegSummary} {Ss : List SegSummary} {t : Thread} {m : Mem} {f : Frame}
    (h : ∀ w, Seg.Through c lbl rest L (S :: Ss) w t m f)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe ws fd me, ToWait c t m (.wait ⟨fe :: rest, t.k + S.len⟩ S.call.intr ws fd) me ∧
      Thread.at ⟨fe :: rest, t.k + S.len⟩ = some (f.fn.name, lbl, f.pc + S.len) ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.regs r) ∧
      S.args.mapM (·.eval (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes)) = .ok ws ∧
      ∀ v m', ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ v = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        ∀ w, Seg.Through c lbl rest L Ss w ⟨fr :: rest, t.k + S.len + 1⟩ m' fr := by
  obtain ⟨fe, me, ws, fd, hSt, h1, h2, h3, -, -, h6, -, -, h9, h10, -⟩ :=
    h (fun _ => (none, m)) hds
  have hw : ToWait c t m (.wait ⟨fe :: rest, t.k + S.len⟩ S.call.intr ws fd) me :=
    ⟨_, _, _, _, rfl, hSt, h10⟩
  refine ⟨fe, ws, fd, me, hw, by simp [Thread.at, h1, h2, h3], h6, h9, fun v m' => ?_⟩
  obtain ⟨fr, hr, -⟩ := Thread.resume_at fe rest (t.k + S.len) v
  refine ⟨fr, hr, fun w => ?_⟩
  obtain ⟨fe', me', ws', fd', hSt', -, -, -, -, -, -, -, -, -, h10', fr', hr', hT⟩ :=
    h (fun i => match i with | 0 => (v, m') | i + 1 => w i) hds
  obtain ⟨e, -⟩ := ToWait.det hw (show ToWait c t m (.wait ⟨fe' :: rest, t.k + S.len⟩ S.call.intr
    ws' fd') me' from ⟨_, _, _, _, rfl, hSt', h10'⟩)
  obtain ⟨e1, -, -, -⟩ := Status.wait.inj e
  obtain rfl : fe = fe' := (List.cons.inj (Thread.mk.inj e1).1).1
  obtain rfl : fr = fr' := (List.cons.inj (Thread.mk.inj (hr.symm.trans hr')).1).1
  exact hT

end MojoProof.Sym
