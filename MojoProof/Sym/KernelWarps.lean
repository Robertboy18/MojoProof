import MojoProof.Sym.WarpRoute
import MojoProof.Sym.CanonBar
import MojoProof.Sym.WarpWaits

/-!
# Kernel soundness from each warp's lanes' runs through their shuffles and barriers

The kernel theorems for kernels whose collectives are warp shuffles and block barriers, from the
premises in the form the segment checker gives each lane: every lane's run through its waits
(`RunsVia` at `Piece.Wait.via`, the form `RunsVia.of_fires` concludes, MojoProof/Sym/OblSeg.lean)
with each lane's shuffles passing the Boolean `Piece.Wait.shflOk` (MojoProof/Sym/WarpRoute.lean),
and the checks on the final memory. `Kernel.sound_of_prefixes` cuts each block at its barriers:
each warp to the barrier, its lanes' runs stopping at the barrier's wait (`WarpWait.of_upto`,
MojoProof/Sym/WarpWaits.lean), the block's warps to it (`CanonWait.of_merge`) and the barrier
(`BlockBar.of_waits`); the runs after a barrier are the next phase's premise; after the last
barrier each warp's run is what `warp_route` does for one warp (`WarpRun.of_waits` with
`WarpRun.shfl_of`), the warps in turn (`CanonRun.of_inv`); then the phases (`BlockRun.of_inv`),
the blocks (`PhaseRun.of_inv`) and the run to a done grid (`PhaseRun.start_done`), which is
`Kernel.run_of_prefixes`; then Theorem 0 at that run (`Grid.start_done_sound`).
`Kernel.sound_of_phases` and `Kernel.run_of_phases` are their corollaries for phases whose lanes'
runs go past the barrier to their ends (`WarpSegsBar`, cut by `WarpSegsBar.to`), and
`Kernel.sound_of_warps`, with no barrier, is the case of no barrier in any block.

* `WarpSegs`: one warp's premises: its lanes' runs through their waits, the waits' shuffles
  (`Piece.Wait.shflOk`), the shuffle declarations' keeping of the deliveries, the waits'
  memories and each phase's start;
* `WarpSegs.run`: the warp's run (`WarpRun`) from them, for lanes whose contexts run the program;
* `WarpSegsBar`: one warp's premises for a phase that ends at a barrier: `WarpSegs`' for the
  phase's shuffles, the barrier wait's facts and the lanes' threads resumed past it;
* `WarpSegsTo`: `WarpSegsBar`'s premises with each lane's run stopping at the barrier's wait
  (`RunsUpto`), no run after it asked; `WarpSegsBar.to`: `WarpSegsBar` gives it;
  `WarpSegsTo.of_inv`: a warp with no shuffle before the barrier has it from an invariant on the
  memory after each lane's run to the barrier's wait (`ToWait`);
* `WarpSegsTo.wait`: the warp's run to the barrier (`WarpWait`) from them; `WarpSegsBar.wait`:
  the same from `WarpSegsBar`;
* `Kernel.Prefixes`: a start's premises on each block's phases, each phase to a barrier a
  `WarpSegsTo`, the one after the last barrier `WarpSegs`;
* `Kernel.run_of_prefixes`: a start's run through the blocks' phases to a done grid whose memory
  is of the last memory predicate, with no end checks (the run and done conjuncts of
  `kernel_sound_sig`'s run premise, MojoProof/Sym/SigKernel.lean); `Kernel.run_of_phases`: its
  corollary from each phase's `WarpSegsBar`;
* `Kernel.sound_of_prefixes`: the kernel theorem with barriers, with memory predicates indexed by
  the block, the phase and the number of the phase's warps that have run; `Kernel.sound_of_phases`:
  its corollary from each phase's `WarpSegsBar`;
* `Kernel.sound_of_warps`: the kernel theorem with no barrier, with a memory predicate indexed by
  the number of warps that have run, as `Kernel.sound_of_chainsAt` (MojoProof/Sym/Kernel.lean) has
  one indexed by the number of threads: the case of no barrier of `Kernel.sound_of_phases`.

Every result here is for every program, kernel, launch, arguments, memory, address choice and
oracle or admission, observation, relation, barrier count, phases, contexts, warp, threads and
memory predicates. The tests are MojoProofTest/KernelWarps.lean (one block of 40 threads: a warp
that shuffles and one that skips the shuffle) and MojoProofTest/KernelPhases.lean (SymColl's
kernel, a barrier and two shuffles, at one block of 4 and of 8 threads; its phase to the
barrier both as a `WarpSegsBar` and as a `WarpSegsTo`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A warp's lanes run through their shuffles, in the segment checker's form**, for program
`prog`, function `fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀` and final
predicate `Q`: there are a number `J` of shuffles, blocks `lbl`, modes `mo`, positions `pos`,
lane operands `ofs`, clamps `cl`, offers `X`, a default wait `d`, the lanes' waits `us` and
memories `M` (phase `i`, `j` lanes done) with `M 0 0 = m₀` and `Q` of the memory after the last
lane of phase `J`, such that

* lane `j` runs from `t (k + j)` on `M 0 j` through its waits `(us j).getD i d`, `i < J`, at
  `Piece.Wait.via fn (lbl i)` (`RunsVia`, as `RunsVia.of_fires` concludes and `RunsVia.of_block`
  restates) to its end on `M J (j + 1)`;
* each lane's waits pass `Piece.Wait.shflOk` (the shuffle of mode `mo i` at position `pos i`, the
  full mask, the offer `X i j`, lane operand `ofs i`, clamp `cl i` and `Grid.fire`'s delivery);
* every shuffle declaration `prog` finds by a name the intrinsic table maps to the shuffle of
  mode `mo i` keeps each delivery under its result attributes (`Program.shfl_nil` gives it when
  `prog.shflNil`);
* each wait is on the memory `M i (j + 1)` and delivers `M (i + 1) j`, and phase `i + 1` starts
  on the memory phase `i`'s last lane leaves.

These are `WarpRun.of_waits`' premises with `WarpRun.shfl_of`'s in place of its shuffle premise,
the premises `warp_route` proves for one warp. -/
def WarpSegs (prog : Program) (fn : Func) (L : Launch) (c : Nat → Ctx) (k : Nat)
    (t : Nat → Thread) (m₀ : Mem) (Q : Mem → Prop) : Prop :=
  ∃ (J : Nat) (lbl : Nat → Nat) (mo : Nat → Shfl) (pos : Nat → Nat) (ofs cl : Nat → BitVec 32)
    (X : Nat → Nat → Val) (d : Piece.Wait) (us : Nat → List Piece.Wait) (M : Nat → Nat → Mem),
    M 0 0 = m₀ ∧ Q (M J (warpLanes L k).length) ∧
    (∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (· = M J (j + 1))
      ((List.range J).map fun i => ((us j).getD i d).via fn (lbl i)) (t (k + j)) (M 0 j)) ∧
    (∀ j ∈ warpLanes L k,
      Piece.Wait.shflOk (warpLanes L k) mo pos ofs cl X d J j (us j) = true) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k, ∀ g e, prog.module.funcs.find? (·.name == g) = some e →
      prog.intrinsics.lookup g = some (.shfl (mo i)) →
      (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat))).mapM
        (withAttrs prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
        .ok (some (shflVal (warpLanes L k) (X i)
          (shflSource (mo i) j (ofs i).toNat (cl i).toNat)))) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k,
      ((us j).getD i d).mem = M i (j + 1) ∧ ((us j).getD i d).dlv.2 = M (i + 1) j) ∧
    ∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length

/-- **A warp's run from its lanes' runs through their shuffles**: for every program `prog`,
function `fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀` and predicate `Q`, if
every lane's context runs `prog` and the warp has `WarpSegs`, the warp runs from `t` on `m₀`
(`WarpRun`, each shuffle `Grid.fire`'s) to a memory of `Q`: `WarpRun.of_waits` at the waits
`(us j).getD i d`, its shuffle premise by `WarpRun.shfl_of`. -/
theorem WarpSegs.run {prog : Program} {fn : Func} {L : Launch} {c : Nat → Ctx} {k : Nat}
    {t : Nat → Thread} {m₀ : Mem} {Q : Mem → Prop}
    (hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = prog) (h : WarpSegs prog fn L c k t m₀ Q) :
    ∃ Es m', WarpRun L c k t m₀ Es m' ∧ Q m' := by
  obtain ⟨J, lbl, mo, pos, ofs, cl, X, d, us, M, rfl, hQ, hr, hok, hK, hm, h0⟩ := h
  obtain ⟨Es, hw⟩ := WarpRun.of_waits (L := L) (c := c) (k := k) (J := J) (fn := fn)
    (lbl := lbl) (W := fun i j => (us j).getD i d) (mo := mo) (X := X) (M := M) (t := t) hr
    (WarpRun.shfl_of (L := L) (c := c) (k := k) (J := J) (P := prog) (mo := mo) (pos := pos)
      (ofs := ofs) (cl := cl) (X := X) (M := fun i => M i (warpLanes L k).length) (d := d)
      (us := us) hP hok hK) hm h0
  exact ⟨Es, _, hw, hQ⟩

/-- **A warp's phase that ends at a barrier, in the segment checker's form**, for program
`prog`, function `fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word
`bar`, block `l`, position `p`, thread predicate `V` and memory predicate `Q`: there are numbers
`J < N` (the phase's shuffles and the lanes' waits), blocks `lbl`, modes `mo`, positions `pos`,
lane operands `ofs`, clamps `cl`, offers `X`, a default wait `d`, the lanes' waits `us`, memories
`M` (phase `i`, `j` lanes done) and final predicates `F` with `M 0 0 = m₀` and `Q` of the memory
after the last lane of phase `J`, such that

* lane `j` runs from `t (k + j)` on `M 0 j` through its `N` waits `(us j).getD i d` at
  `Piece.Wait.via fn (lbl i)` (`RunsVia`, as `RunsVia.of_fires` concludes and `RunsVia.of_block`
  restates) to its end on a memory of `F j`;
* its first `J` waits are shuffles as in `WarpSegs`: they pass `Piece.Wait.shflOk`, the shuffle
  declarations keep the deliveries, each is on the memory `M i (j + 1)` and delivers
  `M (i + 1) j`, and phase `i + 1` starts on the memory phase `i`'s last lane leaves;
* its `J`-th wait is in block `l` (`lbl J = l`) at position `p`, the barrier call on one argument
  whose word is `bar`, delivers no value and is on the memory `M J (j + 1)`;
* the thread `u` that waits there, in the status the lane's thread reaches after its first `J`
  deliveries (`statusAt`), at block `l` and position `p`, resumed with no value, is of
  `V (k + j)` when from it the lane runs through its waits after the `J`-th to a memory of `F j`.

These are `WarpWait.of_waits`' premises with `WarpRun.shfl_of`'s in place of its shuffle premise,
and the barrier wait's facts; `WarpSegsBar.wait` gives the warp's run to the barrier from them,
and `WarpSegsBar.to` cuts them at the barrier (`WarpSegsTo`). -/
def WarpSegsBar (prog : Program) (fn : Func) (L : Launch) (c : Nat → Ctx) (k : Nat)
    (t : Nat → Thread) (m₀ : Mem) (bar l p : Nat) (V : Nat → Thread → Prop) (Q : Mem → Prop) :
    Prop :=
  ∃ (J N : Nat) (lbl : Nat → Nat) (mo : Nat → Shfl) (pos : Nat → Nat) (ofs cl : Nat → BitVec 32)
    (X : Nat → Nat → Val) (d : Piece.Wait) (us : Nat → List Piece.Wait) (M : Nat → Nat → Mem)
    (F : Nat → Mem → Prop),
    J < N ∧ M 0 0 = m₀ ∧ Q (M J (warpLanes L k).length) ∧
    (∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (F j)
      ((List.range N).map fun i => ((us j).getD i d).via fn (lbl i)) (t (k + j)) (M 0 j)) ∧
    (∀ j ∈ warpLanes L k,
      Piece.Wait.shflOk (warpLanes L k) mo pos ofs cl X d J j (us j) = true) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k, ∀ g e, prog.module.funcs.find? (·.name == g) = some e →
      prog.intrinsics.lookup g = some (.shfl (mo i)) →
      (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat))).mapM
        (withAttrs prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
        .ok (some (shflVal (warpLanes L k) (X i)
          (shflSource (mo i) j (ofs i).toNat (cl i).toNat)))) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k,
      ((us j).getD i d).mem = M i (j + 1) ∧ ((us j).getD i d).dlv.2 = M (i + 1) j) ∧
    (∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) ∧
    lbl J = l ∧
    (∀ j ∈ warpLanes L k, ((us j).getD J d).call = .barrier ∧ ((us j).getD J d).pos = p ∧
      (∃ x, ((us j).getD J d).args = [x] ∧ x.word? = some bar) ∧
      ((us j).getD J d).dlv.1 = none ∧ ((us j).getD J d).mem = M J (j + 1)) ∧
    ∀ j ∈ warpLanes L k, ∀ u e,
      statusAt (c (k + j)) ((List.range J).map fun i => ((us j).getD i d).dlv) (t (k + j))
        (M 0 j) = .wait u .barrier ((us j).getD J d).args e →
      u.at = some (fn.name, l, p) →
      RunsVia (c (k + j)) (F j)
        (((List.range N).map fun i => ((us j).getD i d).via fn (lbl i)).drop (J + 1))
        (u.resume none) ((us j).getD J d).dlv.2 →
      V (k + j) (u.resume none)

/-- **A warp's phase to a barrier, its lanes' runs stopping there**, for program `prog`, function
`fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word `bar`, block `l`,
position `p`, thread predicate `V` and memory predicate `Q`: `WarpSegsBar`'s premises with each
lane's run cut at the barrier's wait. There are a number `J` (the phase's shuffles), blocks
`lbl`, modes `mo`, positions `pos`, lane operands `ofs`, clamps `cl`, offers `X`, a default wait
`d`, the lanes' waits `us` and memories `M` (phase `i`, `j` lanes done) with `M 0 0 = m₀` and `Q`
of the memory after the last lane of phase `J`, such that

* lane `j` runs from `t (k + j)` on `M 0 j` through its first `J + 1` waits `(us j).getD i d` at
  `Piece.Wait.via fn (lbl i)` (`RunsUpto`): to the barrier's wait and no further;
* its first `J` waits are shuffles as in `WarpSegs`, and its `J`-th wait is the barrier's, as in
  `WarpSegsBar`;
* the thread `u` that waits there, in the status the lane's thread reaches after its first `J`
  deliveries (`statusAt`), at block `l` and position `p`, resumed with no value, is of
  `V (k + j)`.

The run after the barrier is not asked: it is the next phase's premise (`Kernel.sound_of_prefixes`
asks it from the threads of `V`). `WarpSegsBar.to` gives it from `WarpSegsBar`. -/
def WarpSegsTo (prog : Program) (fn : Func) (L : Launch) (c : Nat → Ctx) (k : Nat)
    (t : Nat → Thread) (m₀ : Mem) (bar l p : Nat) (V : Nat → Thread → Prop) (Q : Mem → Prop) :
    Prop :=
  ∃ (J : Nat) (lbl : Nat → Nat) (mo : Nat → Shfl) (pos : Nat → Nat) (ofs cl : Nat → BitVec 32)
    (X : Nat → Nat → Val) (d : Piece.Wait) (us : Nat → List Piece.Wait) (M : Nat → Nat → Mem),
    M 0 0 = m₀ ∧ Q (M J (warpLanes L k).length) ∧
    (∀ j ∈ warpLanes L k, RunsUpto (c (k + j))
      ((List.range (J + 1)).map fun i => ((us j).getD i d).via fn (lbl i)) (t (k + j)) (M 0 j)) ∧
    (∀ j ∈ warpLanes L k,
      Piece.Wait.shflOk (warpLanes L k) mo pos ofs cl X d J j (us j) = true) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k, ∀ g e, prog.module.funcs.find? (·.name == g) = some e →
      prog.intrinsics.lookup g = some (.shfl (mo i)) →
      (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat))).mapM
        (withAttrs prog.layout (M i (warpLanes L k).length) e.ret e.retAttrs) =
        .ok (some (shflVal (warpLanes L k) (X i)
          (shflSource (mo i) j (ofs i).toNat (cl i).toNat)))) ∧
    (∀ i < J, ∀ j ∈ warpLanes L k,
      ((us j).getD i d).mem = M i (j + 1) ∧ ((us j).getD i d).dlv.2 = M (i + 1) j) ∧
    (∀ i < J, M (i + 1) 0 = M i (warpLanes L k).length) ∧
    lbl J = l ∧
    (∀ j ∈ warpLanes L k, ((us j).getD J d).call = .barrier ∧ ((us j).getD J d).pos = p ∧
      (∃ x, ((us j).getD J d).args = [x] ∧ x.word? = some bar) ∧
      ((us j).getD J d).dlv.1 = none ∧ ((us j).getD J d).mem = M J (j + 1)) ∧
    ∀ j ∈ warpLanes L k, ∀ u e,
      statusAt (c (k + j)) ((List.range J).map fun i => ((us j).getD i d).dlv) (t (k + j))
        (M 0 j) = .wait u .barrier ((us j).getD J d).args e →
      u.at = some (fn.name, l, p) → V (k + j) (u.resume none)

/-- **A warp's run to a barrier from its lanes' runs to it**: for every program `prog`, function
`fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word `bar`, block `l`,
position `p`, thread predicate `V` and memory predicate `Q`, if every lane's context runs `prog`
and the warp has `WarpSegsTo`, the warp runs from `t` on `m₀` to its waits (`WarpWait`, each
shuffle before them `Grid.fire`'s) to a memory of `Q`, and each lane's status there is the
barrier wait on one argument whose word is `bar`, by a thread at block `l` and position `p` of
`fn` which, resumed with no value, is of `V`: `WarpWait.of_upto` at the waits `(us j).getD i d`,
its shuffle premise by `WarpRun.shfl_of`. -/
theorem WarpSegsTo.wait {prog : Program} {fn : Func} {L : Launch} {c : Nat → Ctx} {k : Nat}
    {t : Nat → Thread} {m₀ : Mem} {bar l p : Nat} {V : Nat → Thread → Prop} {Q : Mem → Prop}
    (hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = prog)
    (h : WarpSegsTo prog fn L c k t m₀ bar l p V Q) :
    ∃ s Es m', WarpWait L c k t m₀ Es s m' ∧ (∀ j ∈ warpLanes L k, ∃ u x e,
      s (k + j) = .wait u .barrier [x] e ∧ x.word? = some bar ∧ u.at = some (fn.name, l, p) ∧
      V (k + j) (u.resume none)) ∧ Q m' := by
  obtain ⟨J, lbl, mo, pos, ofs, cl, X, d, us, M, rfl, hQ, hr, hok, hK, hm, h0, hl, hB, hV⟩ := h
  obtain ⟨s, Es, hw, hs⟩ := WarpWait.of_upto (L := L) (c := c) (k := k) (J := J)
    (fn := fn) (lbl := lbl) (W := fun i j => (us j).getD i d) (mo := mo) (X := X) (M := M)
    (t := t) hr
    (WarpRun.shfl_of (L := L) (c := c) (k := k) (J := J) (P := prog) (mo := mo) (pos := pos)
      (ofs := ofs) (cl := cl) (X := X) (M := fun i => M i (warpLanes L k).length) (d := d)
      (us := us) hP hok hK) hm (fun j hj => (hB j hj).2.2.2.2) h0
  refine ⟨s, Es, _, hw, fun j hj => ?_, hQ⟩
  obtain ⟨u, e, hsj, hst, hat⟩ := hs j hj
  obtain ⟨hc, hp, ⟨x, hx, hxw⟩, -, -⟩ := hB j hj
  simp only [hc, Coll.intr] at hsj
  simp only [hl, hp] at hat
  exact ⟨u, x, e, hx ▸ hsj, hxw, hat, hV j hj u e (hst.symm.trans hsj) hat⟩

/-- **A warp's phase to a barrier, cut there**: for every program `prog`, function `fn`, launch
`L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word `bar`, block `l`, position
`p`, thread predicate `V` and memory predicate `Q`, `WarpSegsBar` gives `WarpSegsTo`: each lane's
run through its `N` waits is one through its first `J + 1`, and the run after the `J`-th that
`WarpSegsBar`'s clause for `V` asks is the rest of it (`RunsVia.cut`). -/
theorem WarpSegsBar.to {prog : Program} {fn : Func} {L : Launch} {c : Nat → Ctx} {k : Nat}
    {t : Nat → Thread} {m₀ : Mem} {bar l p : Nat} {V : Nat → Thread → Prop} {Q : Mem → Prop}
    (h : WarpSegsBar prog fn L c k t m₀ bar l p V Q) :
    WarpSegsTo prog fn L c k t m₀ bar l p V Q := by
  obtain ⟨J, N, lbl, mo, pos, ofs, cl, X, d, us, M, F, hJ, h0, hQ, hr, hok, hK, hm, h0', hl, hB,
    hV⟩ := h
  refine ⟨J, lbl, mo, pos, ofs, cl, X, d, us, M, h0, hQ, fun j hj =>
    (RunsVia.cut (w := fun i => (us j).getD i d) (lbl := lbl) hJ (hr j hj)).1,
    hok, hK, hm, h0', hl, hB, fun j hj u e hs hat => hV j hj u e hs hat ?_⟩
  have := (RunsVia.cut (w := fun i => (us j).getD i d) (lbl := lbl) hJ (hr j hj)).2 u _ _ e hs
  simp only [(hB j hj).2.2.2.1] at this
  exact this

/-- **A warp's phase to a barrier with no shuffle before it, by an invariant**, for every program
`prog`, function `fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word
`bar`, block `l`, position `p`, thread predicate `V`, memory predicate `Q` and invariant `I`
(`I j m`: memory `m` after the warp's first `j` lanes): if `I 0 m₀`; each lane `j`, from every
memory of `I j`, runs to a barrier wait (`ToWait`) on one argument whose word is `bar`, by a
thread at block `l` and position `p` of `fn` which, resumed with no value, is of `V (k + j)`,
leaving a memory of `I (j + 1)`; and every memory of `I` after the last lane is of `Q`: then the
warp has `WarpSegsTo` with no shuffle (`J = 0`). The lanes' memories are one function, lane
`j + 1`'s the memory at lane `j`'s wait (`nextWait`, which every run to a wait gives,
`nextWait_eq`), so the proof makes no choice of its own; each lane's one wait is the barrier call
on that wait's arguments and memory; the clause for `V` holds since `statusAt c [] t m` is
`(nextWait c t m).1`. -/
theorem WarpSegsTo.of_inv {prog : Program} {fn : Func} {L : Launch} {c : Nat → Ctx} {k : Nat}
    {t : Nat → Thread} {m₀ : Mem} {bar l p : Nat} {V : Nat → Thread → Prop} {Q : Mem → Prop}
    (I : Nat → Mem → Prop) (h0 : I 0 m₀)
    (hw : ∀ j ∈ warpLanes L k, ∀ m, I j m → ∃ u x e m', ToWait (c (k + j)) (t (k + j)) m
      (.wait u .barrier [x] e) m' ∧ x.word? = some bar ∧ u.at = some (fn.name, l, p) ∧
      V (k + j) (u.resume none) ∧ I (j + 1) m')
    (hQ : ∀ m, I (warpLanes L k).length m → Q m) :
    WarpSegsTo prog fn L c k t m₀ bar l p V Q := by
  let M : Nat → Mem := fun j => Nat.rec m₀ (fun j m => (nextWait (c (k + j)) (t (k + j)) m).2) j
  have hM : ∀ j, j ≤ (warpLanes L k).length → I j (M j) := by
    intro j
    induction j with
    | zero => exact fun _ => h0
    | succ j ih =>
      intro hj
      obtain ⟨u, x, e, m', hr, -, -, -, hI⟩ := hw j (mem_warpLanes.2 hj) _ (ih (by omega))
      show I (j + 1) (nextWait (c (k + j)) (t (k + j)) (M j)).2
      rw [nextWait_eq hr]
      exact hI
  have hr : ∀ j ∈ warpLanes L k, ∃ u x e, ToWait (c (k + j)) (t (k + j)) (M j)
      (.wait u .barrier [x] e) (M (j + 1)) ∧ x.word? = some bar ∧ u.at = some (fn.name, l, p) ∧
      V (k + j) (u.resume none) ∧ nextWait (c (k + j)) (t (k + j)) (M j) =
        (.wait u .barrier [x] e, M (j + 1)) := by
    intro j hj
    obtain ⟨u, x, e, m', hr, hx, hat, hV, -⟩ := hw j hj _ (hM j (mem_warpLanes.1 hj).le)
    have hn := nextWait_eq hr
    have hm : M (j + 1) = m' := by
      show (nextWait (c (k + j)) (t (k + j)) (M j)).2 = m'
      rw [hn]
    rw [hm]
    exact ⟨u, x, e, hr, hx, hat, hV, hn⟩
  let args : Status → List Val := fun s => match s with
    | .wait _ _ xs _ => xs
    | _ => []
  let w : Nat → Piece.Wait := fun j =>
    ⟨p, .barrier, args (nextWait (c (k + j)) (t (k + j)) (M j)).1, M (j + 1), (none, M (j + 1))⟩
  refine ⟨0, fun _ => l, fun _ => .bfly, fun _ => 0, fun _ => 0, fun _ => 0, fun _ _ => .poison,
    w 0, fun j => [w j], fun _ => M, rfl, hQ _ (hM _ le_rfl), fun j hj => ?_, fun _ _ => rfl,
    fun _ h => absurd h (Nat.not_lt_zero _), fun _ h => absurd h (Nat.not_lt_zero _),
    fun _ h => absurd h (Nat.not_lt_zero _), rfl, fun j hj => ?_, fun j hj u' e' hs _ => ?_⟩
  all_goals obtain ⟨u, x, e, hT, hx, hat, hV, hn⟩ := hr j hj
  · exact ⟨u, _, _, e, _, hT,
      ⟨hat, rfl, show [x] = (w j).args by simp only [w, args, hn], rfl⟩, trivial⟩
  · exact ⟨rfl, rfl, ⟨x, show (w j).args = [x] by simp only [w, args, hn], hx⟩, rfl, rfl⟩
  · simp only [List.range_zero, List.map_nil, statusAt, hn] at hs
    obtain ⟨rfl, -, -, -⟩ := Status.wait.inj hs
    exact hV

/-- **A warp's run to a barrier from its lanes' runs through their waits**: for every program
`prog`, function `fn`, launch `L`, contexts `c`, warp `k`, threads `t`, memory `m₀`, barrier word
`bar`, block `l`, position `p`, thread predicate `V` and memory predicate `Q`, if every lane's
context runs `prog` and the warp has `WarpSegsBar`, the warp runs from `t` on `m₀` to its waits
(`WarpWait`, each shuffle before them `Grid.fire`'s) to a memory of `Q`, and each lane's status
there is the barrier wait on one argument whose word is `bar`, by a thread at block `l` and
position `p` of `fn` which, resumed with no value, is of `V`: `WarpSegsTo.wait` at
`WarpSegsBar.to`. -/
theorem WarpSegsBar.wait {prog : Program} {fn : Func} {L : Launch} {c : Nat → Ctx} {k : Nat}
    {t : Nat → Thread} {m₀ : Mem} {bar l p : Nat} {V : Nat → Thread → Prop} {Q : Mem → Prop}
    (hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = prog)
    (h : WarpSegsBar prog fn L c k t m₀ bar l p V Q) :
    ∃ s Es m', WarpWait L c k t m₀ Es s m' ∧ (∀ j ∈ warpLanes L k, ∃ u x e,
      s (k + j) = .wait u .barrier [x] e ∧ x.word? = some bar ∧ u.at = some (fn.name, l, p) ∧
      V (k + j) (u.resume none)) ∧ Q m' :=
  WarpSegsTo.wait hP h.to

/-- **The premises of a start's run through each block's phases, each phase to a barrier cut
there**, for program `prog`, kernel `fn`, launch `L`, contexts `c`, grid `g`, barrier counts `J`,
thread predicates `T b i` (block `b`, phase `i`, by thread) and memory predicates `P b i w`
(phase `i` after its first `w` warps):

* every start's thread (`Grid.thread g`) is of phase 0 of its block, and `P 0 0 0 g.mem`;
* in phase `i < J b` there are a barrier word `bar < 16`, a block `l` and a position `p` such that
  each warp `w` of the block (`blockWarps`), from threads of `T b i` on its lanes and a memory of
  `P b i w`, has `WarpSegsTo` to the barrier (its lanes' runs stopping at the barrier's wait),
  its lanes resumed there of `T b (i + 1)`, and `P b i (w + 1)`; and the memory after the block's
  last warp with the block's `.barrier` logged is of `P b (i + 1) 0`;
* in phase `J b` each warp has `WarpSegs` to `P b (J b) (w + 1)`, and the memory after the
  block's last warp is of `P (b + 1) 0 0`.

A lane's run after a barrier is asked once, by the next phase's premise from the threads of
`T b (i + 1)`. -/
def Kernel.Prefixes (prog : Program) (fn : Func) (L : Launch) (c : Nat → Ctx) (g : Grid)
    (J : Nat → Nat) (T : Nat → Nat → Nat → Thread → Prop) (P : Nat → Nat → Nat → Mem → Prop) :
    Prop :=
  (∀ n, T (n / volume L.block) 0 n (Grid.thread g n)) ∧ P 0 0 0 g.mem ∧
  (∀ b < volume L.grid, ∀ i < J b, ∃ bar < 16, ∃ l p,
    ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
      (∀ j ∈ warpLanes L (blockWarps L b)[w],
        T b i ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
      P b i w m₀ →
      WarpSegsTo prog fn L c (blockWarps L b)[w] t m₀ bar l p (T b (i + 1)) (P b i (w + 1))) ∧
  (∀ b < volume L.grid, ∀ i < J b, ∀ m₁, P b i (blockWarps L b).length m₁ →
    P b (i + 1) 0 (m₁.log (.barrier b))) ∧
  (∀ b < volume L.grid, ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
    (∀ j ∈ warpLanes L (blockWarps L b)[w],
      T b (J b) ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
    P b (J b) w m₀ → WarpSegs prog fn L c (blockWarps L b)[w] t m₀ (P b (J b) (w + 1))) ∧
  ∀ b < volume L.grid, ∀ m₁, P b (J b) (blockWarps L b).length m₁ → P (b + 1) 0 0 m₁

/-- **A start's run through each block's phases, each cut at its barrier, to a done grid.** For
every program `prog`, kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads,
arguments, memory, address choice and oracle whose start (`Grid.start`) gives grid `g` and
contexts `c`, barrier counts `J`, thread predicates `T` and memory predicates `P` with
`Kernel.Prefixes`, `g` steps (`Grid.Step`) to a done grid `z` (`GPUProof.Done` at `sig`) whose
memory is of `P (volume L.grid) 0 0`. No end checks (`EndChecks`) are assumed. The first two
conjuncts are those of the run premise of `kernel_sound_sig` (MojoProof/Sym/SigKernel.lean); its
other two, that `z` is not bad and the observation, are not concluded here: a kernel derives them
from `P (volume L.grid) 0 0 z.mem` (for not bad, by `Grid.not_bad` or `Grid.not_bad_cells` on the
memory's trace). Proof: in phase `i < J b` each warp to its barrier by `WarpSegsTo.wait`, the
block's warps by `CanonWait.of_merge` and the barrier by `BlockBar.of_waits`; in phase `J b` the
warps by `WarpSegs.run` and `CanonRun.of_inv`; the phases by `BlockRun.of_inv`, the blocks by
`PhaseRun.of_inv`, then `PhaseRun.start_done`. -/
theorem Kernel.run_of_prefixes {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hb : 0 < volume L.block)
    {J : Nat → Nat} {T : Nat → Nat → Nat → Thread → Prop} {P : Nat → Nat → Nat → Mem → Prop}
    (H : Kernel.Prefixes prog fn L c g J T P) :
    ∃ z, Relation.ReflTransGen (Grid.Step L c) g z ∧ GPUProof.Done sig (z, L, c) ∧
      P (volume L.grid) 0 0 z.mem := by
  obtain ⟨hT, hP0, hW, hL, hE, hB⟩ := H
  have hc : ∀ k j, (c (k + j)).prog = prog := fun _ _ => (Grid.start_ctx h _).1
  -- a lane of a block's warp is a thread of the block
  have hin : ∀ b, ∀ k ∈ blockWarps L b, ∀ j ∈ warpLanes L k, (k + j) / volume L.block = b :=
    fun b k hk j hj =>
      (blockWarps_threads hb).1 (List.mem_flatMap.2 ⟨k, hk, List.mem_map.2 ⟨j, hj, rfl⟩⟩)
  obtain ⟨Es, m', hr, hm'⟩ := PhaseRun.of_inv (L := L) (c := c) (t := Grid.thread g)
    (P := fun b m => P b 0 0 m) (bs := List.range (volume L.grid))
    (fun b hb' m₀ hm₀ => by
      rw [List.getElem_range]
      rw [List.length_range] at hb'
      obtain ⟨Es, m', hr, hm'⟩ := BlockRun.of_inv (L := L) (c := c) (b := b) (J := J b)
        (T := fun i t => ∀ n, n / volume L.block = b → T b i n (t n))
        (P := fun i m => if i ≤ J b then P b i 0 m else P (b + 1) 0 0 m)
        (fun i hi t m₁ ht hm₁ => by
          rw [ite_eq_left (by omega)] at hm₁
          obtain ⟨bar, hbar, l, p, hw⟩ := hW b hb' i hi
          obtain ⟨s, Es, m₂, hcw, hV, hm₂⟩ := CanonWait.of_merge (L := L) (c := c) (t := t)
            (V := fun n st => ∃ u x e, st = .wait u .barrier [x] e ∧ x.word? = some bar ∧
              u.at = some (fn.name, l, p) ∧ T b (i + 1) n (u.resume none))
            hb (P := P b i) (blockWarps_nodup L b) (fun k hk => ((mem_blockWarps hb).1 hk).2)
            (fun w hw' m₃ hm₃ => by
              obtain ⟨s, Es, m', hww, hs, hm'⟩ := (hw w hw' t m₃
                (fun j hj => ht _ (hin b _ (List.getElem_mem hw') j hj)) hm₃).wait
                fun j _ => hc _ j
              refine ⟨s, Es, m', hww, fun n hn => ?_, hm'⟩
              obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hn
              exact hs j hj) hm₁
          obtain ⟨u, hu⟩ := BlockBar.of_waits (b := b) (s := s) (a := some (fn.name, l, p)) hb
            hbar fun n hn => by
              obtain ⟨k, hk, hn'⟩ := List.mem_flatMap.1 ((blockWarps_threads hb).2 hn)
              obtain ⟨u, x, e, hs, hx, hat, -⟩ := hV k hk n hn'
              exact ⟨u, x, e, hs, hx, hat⟩
          refine ⟨s, u, Es, m₂, hcw, hu, fun n hn => ?_, ?_⟩
          · obtain ⟨k, hk, hn'⟩ := List.mem_flatMap.1 ((blockWarps_threads hb).2 hn)
            obtain ⟨u', x, e, hs, -, -, hT'⟩ := hV k hk n hn'
            obtain ⟨x', d', bar', -, hB'⟩ := hu
            rw [(hB' n hn).1] at hs
            obtain ⟨rfl, -, -, -⟩ := Status.wait.inj hs
            exact hT'
          · rw [ite_eq_left (by omega)]
            exact hL b hb' i hi m₂ hm₂)
        (fun t m₁ ht hm₁ => by
          rw [ite_eq_left (Nat.le_refl _)] at hm₁
          obtain ⟨Es, m', hcr, hm'⟩ := CanonRun.of_inv (L := L) (c := c) (t := t)
            (P := P b (J b)) (ks := blockWarps L b)
            (fun w hw m₃ hm₃ => (hE b hb' w hw t m₃
              (fun j hj => ht _ (hin b _ (List.getElem_mem hw) j hj)) hm₃).run
                fun j _ => hc _ j) hm₁
          exact ⟨Es, m', hcr, by rw [ite_eq_right (by omega)]; exact hB b hb' m' hm'⟩)
        (t := Grid.thread g) (fun n hn => hn ▸ hT n) (m := m₀)
        (by rw [ite_eq_left (Nat.zero_le _)]; exact hm₀)
      rw [ite_eq_right (by omega)] at hm'
      exact ⟨Es, m', hr, hm'⟩) hP0
  rw [List.length_range] at hm'
  obtain ⟨z, hp, hd, rfl⟩ := PhaseRun.start_done h hb hr
  exact ⟨z, GPUProof.Path.exists_iff.1 hp, hd, hm'⟩


/-- **A start's run through each block's phases between its barriers to a done grid.** For every
program `prog`, kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads, arguments,
memory, address choice and oracle whose start (`Grid.start`) gives grid `g` and contexts `c`,
barrier counts `J`, thread predicates `T b i` (block `b`, phase `i`, by thread) and memory
predicates `P b i w` (phase `i` after its first `w` warps): if they have `Kernel.sound_of_phases`'
premises on the phases (every start's thread of phase 0 of its block and `P 0 0 0 g.mem`; in
phase `i < J b` each warp's `WarpSegsBar` to a barrier whose word is below 16, its lanes resumed
there of `T b (i + 1)`, and the block's `.barrier` logged on the memory after its last warp gives
`P b (i + 1) 0`; in phase `J b` each warp's `WarpSegs`, and the memory after the block's last warp
is of `P (b + 1) 0 0`), then `g` steps (`Grid.Step`) to a done grid `z` (`GPUProof.Done` at `sig`)
whose memory is of `P (volume L.grid) 0 0`. No end checks (`EndChecks`) are assumed. The first two
conjuncts are those of the run premise of `kernel_sound_sig` (MojoProof/Sym/SigKernel.lean); its
other two, that `z` is not bad and the observation, are not concluded here: a kernel derives them
from `P (volume L.grid) 0 0 z.mem` (for not bad, by `Grid.not_bad` or `Grid.not_bad_cells` on the
memory's trace). Proof: `Kernel.run_of_prefixes`, each phase's `WarpSegsBar` cut at its
barrier (`WarpSegsBar.to`). -/
theorem Kernel.run_of_phases {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hb : 0 < volume L.block)
    {J : Nat → Nat} {T : Nat → Nat → Nat → Thread → Prop} {P : Nat → Nat → Nat → Mem → Prop}
    (hT : ∀ n, T (n / volume L.block) 0 n (Grid.thread g n)) (hP0 : P 0 0 0 g.mem)
    (hW : ∀ b < volume L.grid, ∀ i < J b, ∃ bar < 16, ∃ l p,
      ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
        (∀ j ∈ warpLanes L (blockWarps L b)[w],
          T b i ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
        P b i w m₀ →
        WarpSegsBar prog fn L c (blockWarps L b)[w] t m₀ bar l p (T b (i + 1)) (P b i (w + 1)))
    (hL : ∀ b < volume L.grid, ∀ i < J b, ∀ m₁, P b i (blockWarps L b).length m₁ →
      P b (i + 1) 0 (m₁.log (.barrier b)))
    (hE : ∀ b < volume L.grid, ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
      (∀ j ∈ warpLanes L (blockWarps L b)[w],
        T b (J b) ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
      P b (J b) w m₀ → WarpSegs prog fn L c (blockWarps L b)[w] t m₀ (P b (J b) (w + 1)))
    (hB : ∀ b < volume L.grid, ∀ m₁, P b (J b) (blockWarps L b).length m₁ → P (b + 1) 0 0 m₁) :
    ∃ z, Relation.ReflTransGen (Grid.Step L c) g z ∧ GPUProof.Done sig (z, L, c) ∧
      P (volume L.grid) 0 0 z.mem :=
  Kernel.run_of_prefixes h hb ⟨hT, hP0, fun b hb' i hi => by
    obtain ⟨bar, hbar, l, p, hw⟩ := hW b hb' i hi
    exact ⟨bar, hbar, l, p, fun w hw' t m₀ ht hm₀ => (hw w hw' t m₀ ht hm₀).to⟩, hL, hE, hB⟩

/-- **Kernel soundness from each block's phases, each cut at its barrier.** For every program
`prog`, kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads, arguments, caller's
memory `m` whose pointer bytes are known (`Mem.BytesIn`), admission `adm` of address choices and
oracles, observation `obs` that reads only the blocks and relation `R`: if the start succeeds on
every admitted choice and oracle, and for each such start, with grid `g` and contexts `c`, there
are barrier counts `J`, thread predicates `T` and memory predicates `P` with `Kernel.Prefixes`
(each phase to a barrier a `WarpSegsTo`, its lanes' runs stopping at the barrier's wait) such
that every memory of `P (volume L.grid) 0 0` passes `EndChecks` (no data race when the trace has
the premises of `racy_iff`, the promise of `!invariant.load` kept, an observation `y` with
`R y`), then the kernel is sound (`Kernel.Sound`). Proof: `Kernel.run_of_prefixes` gives the run
to a done grid whose memory is of `P (volume L.grid) 0 0`, then Theorem 0 at that run
(`Grid.start_done_sound`) with `EndChecks` at its memory. -/
theorem Kernel.sound_of_prefixes {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hm : m.BytesIn m.Known) (hb : 0 < volume L.block)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ J T P, Kernel.Prefixes prog fn L c g J T P ∧
        ∀ m', P (volume L.grid) 0 0 m' → EndChecks L obs R m') :
    Kernel.Sound prog fn L args m adm obs R := by
  intro ch oracle ha
  obtain ⟨g, c, h⟩ := hs ch oracle ha
  obtain ⟨J, T, P, hK, he⟩ := H ch oracle g c ha h
  obtain ⟨z, hz, hd, hP⟩ := Kernel.run_of_prefixes h hb hK
  obtain ⟨_, hp⟩ := GPUProof.Path.exists_iff.2 hz
  obtain ⟨hr, hk, y, hy, hR⟩ := he z.mem hP
  exact ⟨g, c, h, Grid.start_done_sound h hm hO hp hd hr hk hy hR⟩

/-- **Kernel soundness from each block's phases between its barriers.** For every program `prog`,
kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads, arguments, caller's memory
`m` whose pointer bytes are known (`Mem.BytesIn`), admission `adm` of address choices and
oracles, observation `obs` that reads only the blocks, relation `R`, barrier count and phases: if
the start succeeds on every admitted choice and oracle, and for each such start, with grid `g`
and contexts `c`, there are for each block `b` a number `J b` of barriers, thread predicates
`T b i` (phase `i`, by thread) and memory predicates `P b i w` (phase `i` after its first `w`
warps) such that

* every start's thread (`Grid.thread`) is of phase 0 of its block, and `P 0 0 0 g.mem`;
* in phase `i < J b` there are a barrier word `bar < 16`, a block `l` and a position `p` such that
  each warp `w` of the block (`blockWarps`), from threads of `T b i` on its lanes and a memory of
  `P b i w`, has `WarpSegsBar` to the barrier, its lanes resumed there of `T b (i + 1)`, and
  `P b i (w + 1)`; and the memory after the block's last warp with the block's `.barrier`
  logged is of `P b (i + 1) 0`;
* in phase `J b` each warp has `WarpSegs` to `P b (J b) (w + 1)`, and the memory after the
  block's last warp is of `P (b + 1) 0 0`;
* every memory of `P (volume L.grid) 0 0` passes `EndChecks` (no data race when the trace has the
  premises of `racy_iff`, the promise of `!invariant.load` kept, an observation `y` with `R y`),

then the kernel is sound (`Kernel.Sound`). Proof: `Kernel.sound_of_prefixes`, each phase's
`WarpSegsBar` cut at its barrier (`WarpSegsBar.to`). -/
theorem Kernel.sound_of_phases {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hm : m.BytesIn m.Known) (hb : 0 < volume L.block)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ (J : Nat → Nat) (T : Nat → Nat → Nat → Thread → Prop)
        (P : Nat → Nat → Nat → Mem → Prop),
        (∀ n, T (n / volume L.block) 0 n (Grid.thread g n)) ∧ P 0 0 0 g.mem ∧
        (∀ b < volume L.grid, ∀ i < J b, ∃ bar < 16, ∃ l p,
          ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
            (∀ j ∈ warpLanes L (blockWarps L b)[w],
              T b i ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
            P b i w m₀ →
            WarpSegsBar prog fn L c (blockWarps L b)[w] t m₀ bar l p (T b (i + 1))
              (P b i (w + 1))) ∧
        (∀ b < volume L.grid, ∀ i < J b, ∀ m₁, P b i (blockWarps L b).length m₁ →
          P b (i + 1) 0 (m₁.log (.barrier b))) ∧
        (∀ b < volume L.grid, ∀ w (hw : w < (blockWarps L b).length), ∀ t m₀,
          (∀ j ∈ warpLanes L (blockWarps L b)[w],
            T b (J b) ((blockWarps L b)[w] + j) (t ((blockWarps L b)[w] + j))) →
          P b (J b) w m₀ →
          WarpSegs prog fn L c (blockWarps L b)[w] t m₀ (P b (J b) (w + 1))) ∧
        (∀ b < volume L.grid, ∀ m₁, P b (J b) (blockWarps L b).length m₁ →
          P (b + 1) 0 0 m₁) ∧
        ∀ m', P (volume L.grid) 0 0 m' → EndChecks L obs R m') :
    Kernel.Sound prog fn L args m adm obs R := by
  refine Kernel.sound_of_prefixes hm hb hs hO fun ch oracle g c ha h => ?_
  obtain ⟨J, T, P, hT, hP0, hW, hL, hE, hB, he⟩ := H ch oracle g c ha h
  refine ⟨J, T, P, ⟨hT, hP0, fun b hb' i hi => ?_, hL, hE, hB⟩, he⟩
  obtain ⟨bar, hbar, l, p, hw⟩ := hW b hb' i hi
  exact ⟨bar, hbar, l, p, fun w hw' t m₀ ht hm₀ => (hw w hw' t m₀ ht hm₀).to⟩

/-- **Kernel soundness from each warp's lanes' runs through their shuffles.** For every program
`prog`, kernel `fn`, launch `L` with blocks of `volume L.block > 0` threads, arguments, caller's
memory `m` whose pointer bytes are known (`Mem.BytesIn`), admission `adm` of address choices and
oracles, observation `obs` that reads only the blocks and predicate `R`: if the start succeeds on
every admitted choice and oracle, and for each such start, with grid `g` and contexts `c`, there
is a family `P` of memory predicates indexed by the number of warps done with `P 0 g.mem`, such
that each warp of the grid (`warps L g.threads.size`, the `i`-th), from every memory of `P i`, has
`WarpSegs` from the start's threads (`Grid.thread`) to `P (i + 1)`, and every memory of `P` after
all the warps passes `EndChecks` (no data race when the trace has the premises of `racy_iff`, the
promise of `!invariant.load` kept, an observation `y` with `R y`), then the kernel is sound
(`Kernel.Sound`). For kernels whose collectives are shuffles: the case of `Kernel.sound_of_phases`
with no barrier in any block (`J b = 0`), its threads the start's, and block `b`'s memories after
`w` warps those of `P (b * nw + w)`, `nw` the number of a block's warps (`blockWarps`), since the
grid's warps are the blocks' in turn (`warps_blocks`, `Grid.start_size`). -/
theorem Kernel.sound_of_warps {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hm : m.BytesIn m.Known) (hb : 0 < volume L.block)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ P : Nat → Mem → Prop, P 0 g.mem ∧
        (∀ i (hi : i < (warps L g.threads.size).length), ∀ m₀, P i m₀ →
          WarpSegs prog fn L c (warps L g.threads.size)[i] (Grid.thread g) m₀ (P (i + 1))) ∧
        ∀ m', P (warps L g.threads.size).length m' → EndChecks L obs R m') :
    Kernel.Sound prog fn L args m adm obs R := by
  refine Kernel.sound_of_phases hm hb hs hO fun ch oracle g c ha h => ?_
  obtain ⟨P, h0, hW, he⟩ := H ch oracle g c ha h
  -- the blocks' warps in turn are the grid's (`warps_blocks`), as many in each block, and block
  -- `b`'s `w`-th is the grid's `b * nw + w`-th
  have hl : ∀ b, (blockWarps L b).length = (blockWarps L 0).length := fun b => by
    simp only [blockWarps, List.length_map]
  have hws : warps L g.threads.size = (List.range (volume L.grid)).flatMap (blockWarps L) := by
    rw [Grid.start_size h, warps_blocks]
  have hlen : ∀ B, ((List.range B).flatMap (blockWarps L)).length =
      B * (blockWarps L 0).length := fun B => by
    induction B with
    | zero => simp
    | succ B ih =>
      rw [List.range_succ, List.flatMap_append, List.length_append, ih, List.flatMap_singleton,
        hl B, Nat.succ_mul]
  have hix : ∀ B b w, b < B → w < (blockWarps L 0).length →
      ((List.range B).flatMap (blockWarps L))[b * (blockWarps L 0).length + w]? =
        (blockWarps L b)[w]? := fun B => by
    induction B with
    | zero => intro b w hb; omega
    | succ B ih =>
      intro b w hb hw
      rw [List.range_succ, List.flatMap_append, List.flatMap_singleton]
      rcases Nat.lt_succ_iff_lt_or_eq.1 hb with hb | rfl
      · rw [List.getElem?_append_left (by
          rw [hlen]
          exact Nat.lt_of_lt_of_le (by rw [Nat.succ_mul]; omega)
            (Nat.mul_le_mul_right _ hb)), ih b w hb hw]
      · rw [List.getElem?_append_right (by rw [hlen]; omega), hlen, Nat.add_sub_cancel_left]
  -- no barrier: each block's one phase from the start's threads, its memories `P`'s
  refine ⟨fun _ => 0, fun _ _ n t => t = Grid.thread g n,
    fun b _ w m => P (b * (blockWarps L 0).length + w) m, fun _ => rfl, by simpa using h0,
    fun _ _ _ hi => absurd hi (Nat.not_lt_zero _), fun _ _ _ hi => absurd hi (Nat.not_lt_zero _),
    fun b hb w hw t m₀ ht hm₀ => ?_, fun b _ m₁ hm₁ => ?_, fun m' hm' => ?_⟩
  · have e : (warps L g.threads.size)[b * (blockWarps L 0).length + w]? =
        some (blockWarps L b)[w] := by
      rw [hws, hix _ b w hb (hl b ▸ hw), List.getElem?_eq_getElem hw]
    obtain ⟨hi, hk⟩ := List.getElem?_eq_some_iff.1 e
    -- the grid's warp's `WarpSegs`, its lanes' threads the start's
    obtain ⟨J, lbl, mo, pos, ofs, cl, X, d, us, M, h0, hQ, hr, hok, hK, hm, h0'⟩ :=
      hW _ hi m₀ hm₀
    rw [hk] at hr hok hK hm h0' hQ
    exact ⟨J, lbl, mo, pos, ofs, cl, X, d, us, M, h0, hQ, fun j hj => (ht j hj).symm ▸ hr j hj,
      hok, hK, hm, h0'⟩
  · rw [hl b] at hm₁
    show P ((b + 1) * (blockWarps L 0).length) m₁
    rw [Nat.succ_mul]
    exact hm₁
  · exact he m' (by rw [hws, hlen]; exact hm')

end MojoProof.Sym
