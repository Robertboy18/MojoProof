import MojoProof.Sym.SegTrace

/-!
# Runs by invariants: threads as chains of segments separated by collectives

Every result here is for every program, launch and contexts.

A thread of a kernel with collective calls runs to its first collective, is resumed by the
collective's fire, runs to the next one, and last runs to its end. The canonical runs
(`WarpRun`, MojoProof/Sym/Canon.lean; `PhaseRun`, MojoProof/Sym/CanonBar.lean) run the threads
in turn to their waits, fire the collectives and go on from the resumed threads. Their premises
are about the threads and memories they reach, which a proof does not compute; here the runs to
the waits are given by invariants.

* `Seq.ToWait.of_inv`: threads `0` to `N - 1`, each of which from every memory of `P k` runs to
  a wait at a status of `W k` leaving a memory of `P (k + 1)`, run in turn to their waits
  (`Seq.ToWait`) at statuses of `W` from `P 0` to `P N`. Each thread's status is the one its own
  run gives.
* `Seg.Through.wait`: a thread's segments for every delivery (`Seg.Through`, which `Seg.through`
  gives) and the first segment's obligations give the run to the first collective at the
  instruction `(f.fn.name, lbl, f.pc + S.len)`, with the registers and arguments the summary
  gives, and for every delivered value and memory the other segments from the resumed thread,
  for every later delivery: the run to the wait does not depend on the deliveries
  (`ToWait.det`), so a run picks them after the collective. Threads at one block and position
  wait at one instruction, the premise of the barrier's and the shuffle's fires.

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
