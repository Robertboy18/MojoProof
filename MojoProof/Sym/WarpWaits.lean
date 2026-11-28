import MojoProof.Sym.CanonBar
import MojoProof.Sym.WaitAt

/-!
# A warp's run to its waits from its lanes' runs through their waits

`WarpWait.of_waits` is the counterpart of `WarpRun.of_waits` (MojoProof/Sym/Canon.lean) for a
warp that stops at waits: from its lanes' runs through their waits (`RunsVia` at
`Piece.Wait.via`, the form `RunsVia.of_fires` concludes and `RunsVia.of_block` restates) and the
shuffle premises of the first `J` waits, in `WarpRun.of_waits`' form (which `WarpRun.shfl_of`
gives from each lane's `Piece.Wait.shflOk`), the warp's run to the lanes' `J`-th waits
(`WarpWait`). Each lane's status there is a wait at its `J`-th wait's position, call and
arguments, it is the status the lane's thread reaches after its first `J` deliveries
(`statusAt`), and its run from there on is the rest of its run through its waits.

* `statusAt`: the status at a thread's wait after the deliveries of its earlier waits, from wait
  to wait, as `waitAt` (MojoProof/Sym/WaitAt.lean) is the memory there.
* `RunsUpto`: a thread's run through collective calls with no run after the last one, the prefix
  of `RunsVia` (MojoProof/Sym/OblSeg.lean); `RunsVia.upto`: a `RunsVia` runs through each prefix
  of its calls; `RunsVia.drop_statusAt`: the run after a thread's `n`-th call, from the waiting
  thread `statusAt` gives; `RunsVia.cut`: both at a lane's waits (`Piece.Wait.via`).
* `WarpWait.of_upto`: the warp's run to its `J`-th waits from its lanes' runs to them
  (`RunsUpto`), nothing asked of the runs after them, a corollary of `WarpWait.of_inv`
  (MojoProof/Sym/CanonBar.lean) with lane `j` in phase `i` running through its waits from the
  `i`-th, as `WarpRun.of_waits` is of `WarpRun.of_inv`.
* `WarpWait.of_waits`: the same from the lanes' runs through all their waits to their ends
  (`RunsVia`), with the runs after the `J`-th waits concluded too: `WarpWait.of_upto` and
  `RunsVia.cut`. `WarpWait.of_inv` is the general one: its per-lane statuses are any predicates,
  here the waits' positions, calls and arguments and `statusAt`'s status.

Each shuffle is `WarpShfl.of_waits` (MojoProof/Sym/Canon.lean), the one `WarpRun.of_waits` uses.

Every result here is for every program, launch, contexts, warp, function, blocks, waits, modes,
offers, memories and threads.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The status at thread `t`'s wait after the deliveries `ds` of its earlier waits, from memory
`m`: with no delivery, the status at its next collective call (`nextWait`); with a delivery `d`
first, the status at the wait after the others from the waiting thread resumed with `d`'s value
(`Thread.resume`) on `d`'s memory; the status reached if it is not a wait. As `waitAt` is the
memory there. -/
noncomputable def statusAt (c : Ctx) : List (Option Val × Mem) → Thread → Mem → Status
  | [], t, m => (nextWait c t m).1
  | d :: ds, t, m => match (nextWait c t m).1 with
    | .wait u _ _ _ => statusAt c ds (u.resume d.1) d.2
    | s => s

/-- **A thread's run to a collective call through the ones before it**: from thread `t` on memory
`m`, for each pair `(P, d)` of `ws` in turn, a run to a collective call (`ToWait`), the thread `u`
waiting at intrinsic `i` with arguments `xs` on memory `m₁` such that `P u i xs m₁`, the thread
then resumed with the delivered value `d.1` (`Thread.resume`) on the delivered memory `d.2`; after
the last pair, nothing: no run to the thread's end, which `RunsVia` asks. For every context, list
of pairs, thread and memory. -/
def RunsUpto (c : Ctx) :
    List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)) → Thread → Mem →
      Prop
  | [], _, _ => True
  | (P, d) :: ws, t, m => ∃ u i xs e m₁, ToWait c t m (.wait u i xs e) m₁ ∧ P u i xs m₁ ∧
      RunsUpto c ws (u.resume d.1) d.2

/-- **A run through collective calls runs through each prefix of them**: for every context `c`,
final predicate `Q`, list of pairs `ws`, thread `t`, memory `m` and number `n`, a run through
`ws` (`RunsVia`) is one through `ws.take n` (`RunsUpto`), the run after them dropped. -/
theorem RunsVia.upto {c : Ctx} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {t : Thread} {m : Mem} (h : RunsVia c Q ws t m) (n : Nat) : RunsUpto c (ws.take n) t m := by
  induction ws generalizing t m n with
  | nil => cases n <;> trivial
  | cons w ws ih =>
    obtain ⟨P, d⟩ := w
    cases n with
    | zero => trivial
    | succ n =>
      obtain ⟨u, i, xs, e, m₁, hw, hP, hr⟩ := h
      exact ⟨u, i, xs, e, m₁, hw, hP, ih hr n⟩

/-- **The run after a thread's `n`-th collective call**: for every context `c`, final predicate
`Q`, list of pairs `ws`, number `n < ws.length`, threads `t`, `u`, memory `m`, intrinsic `i`,
arguments `xs` and callee `e`: if `t` on `m` runs through `ws` (`RunsVia`) and its status after the
first `n` deliveries (`statusAt`) is the wait by `u`, then `u`, resumed with the `n`-th pair's
value on its memory, runs through the pairs after it. By induction on `n`, each wait the one the
run reaches (`nextWait_eq`). -/
theorem RunsVia.drop_statusAt {c : Ctx} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {n : Nat} (hn : n < ws.length) {t u : Thread} {m : Mem} {i : Intrinsic} {xs : List Val}
    {e : Func} (h : RunsVia c Q ws t m)
    (hs : statusAt c ((ws.take n).map (·.2)) t m = .wait u i xs e) :
    RunsVia c Q (ws.drop (n + 1)) (u.resume ws[n].2.1) ws[n].2.2 := by
  induction ws generalizing n t m with
  | nil => exact absurd hn (Nat.not_lt_zero _)
  | cons w ws ih =>
    obtain ⟨P, d⟩ := w
    obtain ⟨u', i', xs', e', m₁, hw, -, hr⟩ := h
    cases n with
    | zero =>
      simp only [List.take_zero, List.map_nil, statusAt, nextWait_eq hw] at hs
      obtain ⟨rfl, -, -, -⟩ := Status.wait.inj hs
      exact hr
    | succ n =>
      simp only [List.take_succ_cons, List.map_cons, statusAt, nextWait_eq hw] at hs
      exact ih (n := n) (Nat.lt_of_succ_lt_succ hn) hr hs

/-- **A lane's run through its waits, cut at its `J`-th**: for every context `c`, final predicate
`Q`, function `fn`, blocks `lbl`, waits `w` (the `i`-th in block `lbl i`), numbers `J < N`,
thread `t` and memory `m`: a run through the `N` waits (`RunsVia` at `Piece.Wait.via`) is one
through the first `J + 1` (`RunsUpto`), and when the status after the first `J` deliveries
(`statusAt`) is the wait by `u`, `u` resumed with the `J`-th wait's delivery runs through the
waits after it (`RunsVia.upto`, `RunsVia.drop_statusAt`). -/
theorem RunsVia.cut {c : Ctx} {Q : Mem → Prop} {fn : Func} {lbl : Nat → Nat}
    {w : Nat → Piece.Wait} {J N : Nat} (hJ : J < N) {t : Thread} {m : Mem}
    (h : RunsVia c Q ((List.range N).map fun i => (w i).via fn (lbl i)) t m) :
    RunsUpto c ((List.range (J + 1)).map fun i => (w i).via fn (lbl i)) t m ∧
      ∀ u i xs e, statusAt c ((List.range J).map fun i => (w i).dlv) t m = .wait u i xs e →
        RunsVia c Q (((List.range N).map fun i => (w i).via fn (lbl i)).drop (J + 1))
          (u.resume (w J).dlv.1) (w J).dlv.2 := by
  have ht : ∀ n ≤ N, ((List.range N).map fun i => (w i).via fn (lbl i)).take n =
      (List.range n).map fun i => (w i).via fn (lbl i) := fun n hn => by
    rw [← List.map_take, List.take_range, Nat.min_eq_left hn]
  refine ⟨by rw [← ht (J + 1) hJ]; exact h.upto _, fun u i xs e hs => ?_⟩
  have hl : J < ((List.range N).map fun i => (w i).via fn (lbl i)).length := by
    simp only [List.length_map, List.length_range]
    exact hJ
  have := RunsVia.drop_statusAt hl h (by rw [ht J (Nat.le_of_lt hJ), List.map_map]; exact hs)
  simp only [List.getElem_map, List.getElem_range] at this
  exact this

/-- **A warp's run to its waits from its lanes' runs to them**, for every launch `L`, contexts
`c`, warp `k`, number `J`, function `fn`, blocks `lbl`, waits `W` (lane `j`'s `i`-th is `W i j`,
in block `lbl i`, for `i ≤ J`), modes `mo`, offers `X`, memories `M` and threads `t`. The
premises:

* lane `j` runs from `t (k + j)` on `M 0 j` through its first `J + 1` waits `W 0 j`, ...,
  `W J j` (`RunsUpto` with `Piece.Wait.via`'s predicates), and no further: nothing is asked of
  its run after its `J`-th wait;
* its first `J` waits are shuffles as `WarpRun.of_waits` asks (`hW`, `hm`, `h0`: the mode
  `mo i`, lane 0's position, the full mask, offer `X i j`, word operands, `Grid.fire`'s delivery
  under the callees' result attributes on the memory `M i` after the phase's last lane, the
  memory `M i (j + 1)` at the wait, the delivered memory `M (i + 1) j`, and each phase's start on
  the memory the one before leaves);
* its `J`-th wait is on the memory `M J (j + 1)`.

Then the warp runs from `t` on `M 0 0` to its `J`-th waits (`WarpWait`), its shuffles before
them `Grid.fire`'s (`WarpShfl`), on `M J` after all its lanes, and lane `j`'s status `s (k + j)`
there is a wait at `W J j`'s position, call and arguments; it is `statusAt` of the lane's first
`J` deliveries `(W i j).dlv` from `t (k + j)` on `M 0 j` (the waiting thread and callee too, which
the waits' predicates do not state). Proof: `WarpWait.of_inv` with lane `j` in phase `i` running
through its waits from the `i`-th to the `J`-th and its `statusAt` from the `i`-th delivery on
being the `J`-th wait's, each phase's run to the next wait by the run through the waits
(`nextWait_eq` for `statusAt`), its callee by `step_wait`, and each shuffle by
`WarpShfl.of_waits`. -/
theorem WarpWait.of_upto {L : Launch} {c : Nat → Ctx} {k J : Nat} {fn : Func}
    {lbl : Nat → Nat} {W : Nat → Nat → Piece.Wait} {mo : Nat → Shfl} {X : Nat → Nat → Val}
    {M : Nat → Nat → Mem} {t : Nat → Thread}
    (hr : ∀ j ∈ warpLanes L k, RunsUpto (c (k + j))
      ((List.range (J + 1)).map fun i => (W i j).via fn (lbl i)) (t (k + j)) (M 0 j))
    (hW : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).call.intr = .shfl (mo i) ∧
      (W i j).pos = (W i 0).pos ∧ ∃ Mk Bv Cv b cl, (W i j).args = [Mk, X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i)) →
          (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j b cl))).mapM
            (withAttrs (c k).prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
            .ok (W i j).dlv.1)
    (hm : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).mem = M i (j + 1) ∧ (W i j).dlv.2 = M (i + 1) j)
    (hmJ : ∀ j ∈ warpLanes L k, (W J j).mem = M J (j + 1))
    (h0 : ∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) :
    ∃ s Es, WarpWait L c k t (M 0 0) Es s (M J (warpLanes L k).length) ∧
      ∀ j ∈ warpLanes L k, ∃ u e, s (k + j) = .wait u (W J j).call.intr (W J j).args e ∧
        s (k + j) = statusAt (c (k + j)) ((List.range J).map fun i => (W i j).dlv) (t (k + j))
          (M 0 j) ∧
        u.at = some (fn.name, lbl J, (W J j).pos) := by
  -- lane `j`'s status at its `J`-th wait
  let S j := statusAt (c (k + j)) ((List.range J).map fun i => (W i j).dlv) (t (k + j)) (M 0 j)
  -- lane `j` in phase `i ≤ J`: from its run through its waits from the `i`-th to the `J`-th, with
  -- `statusAt` of its deliveries from the `i`-th the `J`-th wait's, the run to the `i`-th wait,
  -- at its position, call and arguments, with its callee, then the rest, and `statusAt` from the
  -- next
  have hw : ∀ i ≤ J, ∀ j ∈ warpLanes L k, ∀ t m, RunsUpto (c (k + j))
      (((List.range (J + 1)).map fun i => (W i j).via fn (lbl i)).drop i) t (M i j) ∧
      statusAt (c (k + j)) (((List.range J).map fun i => (W i j).dlv).drop i) t (M i j) = S j →
      m = M i j →
      ∃ s m', ToWait (c (k + j)) t m s m' ∧ (∃ u e, s = .wait u (W i j).call.intr (W i j).args e ∧
        u.at = some (fn.name, lbl i, (W i j).pos) ∧
        (∃ g, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e ∧
          (c (k + j)).prog.intrinsics.lookup g = some (W i j).call.intr) ∧
        RunsUpto (c (k + j))
          (((List.range (J + 1)).map fun i => (W i j).via fn (lbl i)).drop (i + 1))
          (u.resume (W i j).dlv.1) (W i j).dlv.2 ∧
        (i < J → statusAt (c (k + j)) (((List.range J).map fun i => (W i j).dlv).drop (i + 1))
          (u.resume (W i j).dlv.1) (W i j).dlv.2 = S j) ∧ (J ≤ i → s = S j)) ∧
        m' = M i (j + 1) := by
    intro i hi j hj t m ⟨ht, hS⟩ hm
    subst hm
    rw [List.drop_eq_getElem_cons (by simp only [List.length_map, List.length_range]; omega),
      List.getElem_map, List.getElem_range] at ht
    obtain ⟨u, x, xs, e, m₁, htw, ⟨hat, rfl, rfl, rfl⟩, hrest⟩ := ht
    have hst : step (c (k + j)) u (W i j).mem = .ok (.wait (W i j).call.intr (W i j).args e) := by
      obtain ⟨u', x', xs', e', hs, -, hst⟩ := htw
      obtain ⟨rfl, rfl, rfl, rfl⟩ := Status.wait.inj hs
      exact hst
    obtain ⟨-, -, -, -, -, -, g, -, -, -, -, -, hfind, -, hlk⟩ := step_wait hst
    refine ⟨_, _, htw, ⟨u, e, rfl, hat, ⟨g, hfind, hlk⟩, hrest, fun hi' => ?_, fun hi' => ?_⟩, ?_⟩
    · rw [List.drop_eq_getElem_cons (by simp only [List.length_map, List.length_range]; omega),
        List.getElem_map, List.getElem_range, statusAt, nextWait_eq htw] at hS
      exact hS
    · rw [List.drop_eq_nil_of_le (by simp only [List.length_map, List.length_range]; omega),
        statusAt, nextWait_eq htw] at hS
      exact hS
    · rcases Nat.lt_or_eq_of_le hi with hi | rfl
      · exact (hm i hi j hj).1
      · exact hmJ j hj
  obtain ⟨s, Es, m', h, hs, rfl⟩ := WarpWait.of_inv (L := L) (c := c) (k := k) (J := J) (t := t)
    (T := fun i j t => RunsUpto (c (k + j))
      (((List.range (J + 1)).map fun i => (W i j).via fn (lbl i)).drop i) t (M i j) ∧
      statusAt (c (k + j)) (((List.range J).map fun i => (W i j).dlv).drop i) t (M i j) = S j)
    (W := fun i j s => ∃ u e, s = .wait u (W i j).call.intr (W i j).args e ∧
      u.at = some (fn.name, lbl i, (W i j).pos) ∧
      (∃ g, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e ∧
        (c (k + j)).prog.intrinsics.lookup g = some (W i j).call.intr) ∧
      RunsUpto (c (k + j))
        (((List.range (J + 1)).map fun i => (W i j).via fn (lbl i)).drop (i + 1))
        (u.resume (W i j).dlv.1) (W i j).dlv.2 ∧
      (i < J → statusAt (c (k + j)) (((List.range J).map fun i => (W i j).dlv).drop (i + 1))
        (u.resume (W i j).dlv.1) (W i j).dlv.2 = S j) ∧ (J ≤ i → s = S j))
    (P := fun i j m => m = M i j) (fun i hi => hw i (Nat.le_of_lt hi))
    (fun i hi s hs m hm => by
      subst hm
      refine ⟨fun j => match s j with | .wait u _ _ _ => u | _ => t 0, fun j => (W i j).dlv.1,
        WarpShfl.of_waits (fn := fn) (l := lbl i) (fun j hj => ?_) (hW i hi), fun j hj => ?_,
        (h0 i hi).symm⟩
      · obtain ⟨u, e, hsj, hat, ⟨g, hfind, hlk⟩, -⟩ := hs j hj
        simp only [hsj]
        exact ⟨e, rfl, hat, g, hfind, hlk.trans (congrArg some (hW i hi j hj).1)⟩
      · obtain ⟨u, e, hsj, -, -, hrest, hS, -⟩ := hs j hj
        simp only [hsj]
        exact (hm i hi j hj).2 ▸ ⟨hrest, hS hi⟩)
    (hw J (Nat.le_refl J))
    (fun j hj => ⟨by simpa only [List.drop_zero] using hr j hj, by rw [List.drop_zero]⟩) rfl
  refine ⟨s, Es, h, fun j hj => ?_⟩
  obtain ⟨u, e, hsj, hat, -, -, -, hS⟩ := hs j hj
  exact ⟨u, e, hsj, hS (Nat.le_refl J), hat⟩

/-- **A warp's run to its waits from its lanes' runs through their waits**, for every launch `L`,
contexts `c`, warp `k`, numbers `J < N`, function `fn`, blocks `lbl`, waits `W` (lane `j`'s
`i`-th is `W i j`, in block `lbl i`, for `i < N`), modes `mo`, offers `X`, memories `M`, final
predicates `Q` and threads `t`. The premises:

* lane `j` runs from `t (k + j)` on `M 0 j` through its `N` waits `W 0 j`, ..., `W (N - 1) j`
  (`RunsVia` with `Piece.Wait.via`'s predicates) and then to its end on a memory of `Q j`;
* its first `J` waits are shuffles as `WarpRun.of_waits` asks (`hW`, `hm`, `h0`: the mode
  `mo i`, lane 0's position, the full mask, offer `X i j`, word operands, `Grid.fire`'s delivery
  under the callees' result attributes on the memory `M i` after the phase's last lane, the
  memory `M i (j + 1)` at the wait, the delivered memory `M (i + 1) j`, and each phase's start on
  the memory the one before leaves);
* its `J`-th wait is on the memory `M J (j + 1)`.

Then the warp runs from `t` on `M 0 0` to its `J`-th waits (`WarpWait`), its shuffles before
them `Grid.fire`'s (`WarpShfl`), on `M J` after all its lanes, and lane `j`'s status `s (k + j)`
there is a wait at `W J j`'s position, call and arguments; it is `statusAt` of the lane's first
`J` deliveries `(W i j).dlv` from `t (k + j)` on `M 0 j` (the waiting thread and callee too, which
the waits' predicates do not state); and from it, resumed with `W J j`'s delivery, the lane runs
through its waits after the `J`-th to its end on a memory of `Q j`. With `J = N` there is no wait
to stop at: that is `WarpRun.of_waits`. Proof: `WarpWait.of_upto` at each lane's run through its
first `J + 1` waits, and the run after the `J`-th wait from the lane's run through all its waits
(`RunsVia.cut`). -/
theorem WarpWait.of_waits {L : Launch} {c : Nat → Ctx} {k J N : Nat} {fn : Func}
    {lbl : Nat → Nat} {W : Nat → Nat → Piece.Wait} {mo : Nat → Shfl} {X : Nat → Nat → Val}
    {M : Nat → Nat → Mem} {Q : Nat → Mem → Prop} {t : Nat → Thread} (hJ : J < N)
    (hr : ∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (Q j)
      ((List.range N).map fun i => (W i j).via fn (lbl i)) (t (k + j)) (M 0 j))
    (hW : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).call.intr = .shfl (mo i) ∧
      (W i j).pos = (W i 0).pos ∧ ∃ Mk Bv Cv b cl, (W i j).args = [Mk, X i j, Bv, Cv] ∧
        Mk.word? = some (2 ^ 32 - 1) ∧ Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i)) →
          (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j b cl))).mapM
            (withAttrs (c k).prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
            .ok (W i j).dlv.1)
    (hm : ∀ i < J, ∀ j ∈ warpLanes L k, (W i j).mem = M i (j + 1) ∧ (W i j).dlv.2 = M (i + 1) j)
    (hmJ : ∀ j ∈ warpLanes L k, (W J j).mem = M J (j + 1))
    (h0 : ∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) :
    ∃ s Es, WarpWait L c k t (M 0 0) Es s (M J (warpLanes L k).length) ∧
      ∀ j ∈ warpLanes L k, ∃ u e, s (k + j) = .wait u (W J j).call.intr (W J j).args e ∧
        s (k + j) = statusAt (c (k + j)) ((List.range J).map fun i => (W i j).dlv) (t (k + j))
          (M 0 j) ∧
        u.at = some (fn.name, lbl J, (W J j).pos) ∧
        RunsVia (c (k + j)) (Q j)
          (((List.range N).map fun i => (W i j).via fn (lbl i)).drop (J + 1))
          (u.resume (W J j).dlv.1) (W J j).dlv.2 := by
  have hc := fun j (hj : j ∈ warpLanes L k) =>
    RunsVia.cut (w := fun i => W i j) (lbl := lbl) hJ (hr j hj)
  obtain ⟨s, Es, h, hs⟩ := WarpWait.of_upto (fn := fn) (lbl := lbl) (W := W) (mo := mo) (X := X)
    (M := M) (t := t) (fun j hj => (hc j hj).1) hW hm hmJ h0
  refine ⟨s, Es, h, fun j hj => ?_⟩
  obtain ⟨u, e, hsj, hS, hat⟩ := hs j hj
  exact ⟨u, e, hsj, hS, hat, (hc j hj).2 u _ _ e (hS.symm.trans hsj)⟩

end MojoProof.Sym
