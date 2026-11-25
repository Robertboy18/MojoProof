import MojoProof.Sym.Kernel
import MojoProof.Sem.Index

/-!
# The tactic mojo_race: the disjointness premises of the kernel theorem

docs/proofs/race.md. mojo_race proves, from the accesses of each thread, the premises that the
race-freedom results take, and leaves the others open, logged:

* `Apart cell w` (of `Elem.safe` and `Tiling.ofApart`), for cells affine in the thread: by `omega`
  for a literal stride, by `apart_stride` for `base + k * s` with `w ≤ s`;
* `Elem.Own out w cell a` (the `owned` field of `Elem`, `Elem.succ`, `Elem.log`) for an access `a`
  whose fields are given: in its thread's cell when it is to `out`, a read that is not an
  `atomicrmw`'s otherwise, and not to `out` with `!invariant.load`, each from the local context by
  `omega`;
* `∀ x ∈ l, P x` for a list `l` of accesses, element by element;
* `x.conflict y = false` for two accesses (`Access.conflict_of_reads`, `Access.conflict_of_apart`):
  different blocks, or bytes apart, or both reads;
* `Grid.owned_sound`'s `hX` and `hL`, by `omega` after the introductions, for an `own` that is
  injective and affine with a literal stride (on a 1-D launch thread `t`'s index is `t`,
  `Launch.index_oneDim`) and a `loc` the context decides; its `hI` from a hypothesis that every
  access of the trace is owned (`Elem.Own.invariant_apart`); and its `hO` for the tiling of `out`
  by the cells clipped to an extent `ext` (`Tiling.clip`) and the thread numbers as tiles, from
  hypotheses that every access of the trace is owned and every access to `out` ends by `ext`
  (`Elem.Own.owned`). With the thread numbers as tiles, `hX` holds on every launch. With the
  tile map through the index (thread `t`'s i64 word of `ctaid.x * ntid.x + tid.x`), `hX` on a
  valid 1-D launch, from a hypothesis that the trace's threads are below the thread count
  (`Launch.thread_eq_of_index`).

Not covered: goals whose cells are not linear in the thread (`tid.x % B`, symbolic strides other
than `base + k * s`), which stay open; an `hO` whose tiling is not `Tiling.clip`'s or whose
tile map is not the thread number; and `hX` through the index on a launch of more than one
dimension.

The lemmas are for every access, trace, output block, cell width and cells:

* `Access.conflict_of_reads`, `Access.conflict_of_apart`: two accesses that both read, or that are
  to different blocks or to bytes apart, do not conflict.
* `Elem.Own.invariant_apart`: if every access of a trace is owned, an access with
  `!invariant.load` is to a block no write of the trace is to (`Grid.owned_sound`'s `hI`).
* `Tiling.clip`: cells `w` bytes apart clipped to an extent are a tiling of `Nat`.
* `Elem.Own.owned`: if every access of a trace is owned and every access to `out` ends by `ext`,
  every access follows the discipline of `Tiling.clip` at `out` and the thread numbers
  (`Grid.owned_sound`'s `hO`).
* `Launch.thread_eq_of_index`: on a valid 1-D launch, two threads below the thread count with
  equal index words are the same thread (`Launch.index_inj`, `Launch.index_oneDim`).

Tests: MojoProofTest/Race.lean (`vector_addition` for every launch and trace, and the twin with
`tid.x` alone as the index on two blocks, where the two stores' collision stays open).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- Two accesses that both read do not conflict, for every pair of accesses
(`Access.conflict_eq_false` with no overlap fact). -/
theorem Access.conflict_of_reads {x y : Access} (hx : x.write = false) (hy : y.write = false) :
    x.conflict y = false :=
  Access.conflict_eq_false fun _ => ⟨hx, hy⟩

/-- Two accesses to different blocks, or to bytes apart, do not conflict, for every pair of
accesses. -/
theorem Access.conflict_of_apart {x y : Access}
    (h : x.ptr.block ≠ y.ptr.block ∨ x.ptr.off + x.len ≤ y.ptr.off ∨
      y.ptr.off + y.len ≤ x.ptr.off) :
    x.conflict y = false := by
  have : x.overlaps y = false := by
    simp only [Access.overlaps, Bool.and_eq_false_iff, beq_eq_false_iff_ne, ne_eq,
      decide_eq_false_iff_not, Int.not_lt]
    omega
  simp [Access.conflict, this]

/-- **`!invariant.load` reads no written block** under the elementwise discipline: if every access
of trace `tr` is owned (`Elem.Own`), an access of `tr` with `!invariant.load` and a write of `tr`
are to different blocks. For every trace, output block, cell width and cells. -/
theorem Elem.Own.invariant_apart {tr : List Event} {out w : Nat} {cell : Nat → Nat}
    (H : ∀ a, Event.access a ∈ tr → Elem.Own out w cell a) :
    ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.invariant = true → e.write = true →
      a.ptr.block ≠ e.ptr.block := by
  intro a e ha he hi hw hb
  have h1 := (H a ha).2.2 hi
  have h2 : e.ptr.block = out := by
    by_contra h
    rw [((H e he).2.1 h).1] at hw
    cases hw
  exact h1 (hb.trans h2)

/-- **The cells clipped to an extent are a tiling.** For every cells `cell` that are `w` bytes
apart (`Apart`) and extent `ext`, tile `i` is the part of `[cell i, cell i + w)` below `ext`: the
bounded tiling of an output whose tiles are the thread numbers (`Elem.Own.owned`). -/
def Tiling.clip (cell : Nat → Nat) (w ext : Nat) (hap : Apart cell w) : Tiling Nat where
  off i := min (cell i) ext
  len i := min (cell i + w) ext - min (cell i) ext
  ext := ext
  inb _ := by omega
  disj i j hij := by rcases hap i j hij with h | h <;> omega

/-- **Owned accesses in bounds follow the discipline** (`Grid.owned_sound`'s `hO`): if every
access of trace `tr` is owned (`Elem.Own`) and every access to `out` ends by `ext`, every access
of `tr` follows the discipline whose tiling of `out` is `Tiling.clip cell w ext`, of no other
block, and whose tile of a thread is its number. For every trace, output block, cell width, cells
apart and extent. -/
theorem Elem.Own.owned {tr : List Event} {out w ext : Nat} {cell : Nat → Nat} {hap : Apart cell w}
    (H : ∀ a, Event.access a ∈ tr → Elem.Own out w cell a)
    (hb : ∀ a, Event.access a ∈ tr → a.ptr.block = out → a.ptr.off + a.len ≤ ext) :
    ∀ a, Event.access a ∈ tr →
      Owned (fun b => if b = out then some (Tiling.clip cell w ext hap) else none) (fun t => t) a :=
  fun a ha => ⟨fun hT => ((H a ha).2.1 fun ho => by simp [ho] at hT).1, fun t hT => by
    by_cases ho : a.ptr.block = out
    · simp only [ho, ↓reduceIte, Option.some.injEq] at hT
      subst hT
      obtain ⟨h1, h2⟩ := (H a ha).1 ho
      have h3 := hb a ha ho
      simp only [Tiling.clip]
      omega
    · simp [ho] at hT⟩

/-- **A thread is its index word** (`Grid.owned_sound`'s `hX` for the tile map through the index):
on every valid launch whose grid and block have side 1 in `y` and `z`, two threads below the
thread count whose i64 words of `ctaid.x * ntid.x + tid.x` are equal are the same thread: the
words give the same `ctaid.x` and `tid.x` (`Launch.index_inj`), and the index of each thread is
its number (`Launch.index_oneDim`). -/
theorem Launch.thread_eq_of_index {L : Launch} (h : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {n n' : Nat}
    (hn : n < volume L.grid * volume L.block) (hn' : n' < volume L.grid * volume L.block)
    (he : BitVec.ofNat 64
        ((L.env n).sreg .ctaid .x * (L.env n).sreg .ntid .x + (L.env n).sreg .tid .x) =
      BitVec.ofNat 64
        ((L.env n').sreg .ctaid .x * (L.env n').sreg .ntid .x + (L.env n').sreg .tid .x)) :
    n = n' := by
  obtain ⟨hc, ht⟩ := Launch.index_inj h .x he
  have e := Launch.index_oneDim hg hb hn
  have hN : (L.env n).sreg .ntid .x = (L.env n').sreg .ntid .x := rfl
  rw [hc, ht, hN] at e
  exact e.symm.trans (Launch.index_oneDim hg hb hn')

namespace Race

open Lean Meta Elab Tactic

/-- Whether `tac` closes the main goal; the state is restored when it does not. -/
def closes (tac : TSyntax `tactic) : TacticM Bool := do
  let s ← saveState
  try
    withoutRecover <| focusAndDone <| evalTactic tac
    return true
  catch _ =>
    s.restore
    return false

/-- The ways mojo_race closes one goal, in order. -/
def routes : TacticM (Array (TSyntax `tactic)) := do
  return #[
    ← `(tactic| (intro i j hij; dsimp only; omega)),
    ← `(tactic| exact apart_stride _ (by omega)),
    ← `(tactic| (unfold Elem.Own; dsimp only; refine ⟨fun h => ?_, fun h => ?_, fun h => ?_⟩ <;>
        first | rfl | exact ⟨rfl, rfl⟩ | contradiction | omega)),
    ← `(tactic| (apply Access.conflict_of_reads <;> rfl)),
    ← `(tactic| (apply Access.conflict_of_apart; dsimp only; omega)),
    ← `(tactic| (apply Elem.Own.invariant_apart; assumption)),
    ← `(tactic| (intro a ha _; exact Elem.Own.owned (by assumption) (by assumption) a ha)),
    ← `(tactic| exact fun _ _ _ _ _ _ hw => Launch.thread_eq_of_index (by assumption)
        (by assumption) (by assumption) (by solve_by_elim) (by solve_by_elim) hw),
    ← `(tactic| (intros; dsimp only at * <;> first | contradiction | omega))]

/-- Whether `ty` is `∀ x, x ∈ l → P x`. -/
def isListBall (ty : Expr) : Bool :=
  match ty with
  | .forallE _ _ (.forallE _ t _ _) _ => t.isAppOf ``Membership.mem
  | _ => false

/-- mojo_race on the main goal: a list of accesses element by element, else the first route that
closes it, else the goal stays open and is logged. -/
partial def race : TacticM Unit := do
  let ty ← instantiateMVars (← getMainTarget)
  if isListBall ty then
    if ← closes (← `(tactic| (intro _ h; simp at h))) then return
    let s ← saveState
    try
      evalTactic (← `(tactic| refine List.forall_mem_cons.2 ⟨?_, ?_⟩))
      let [hd, tl] ← getGoals | throwError "mojo_race: not a list"
      setGoals [hd]
      race
      let hs ← getGoals
      setGoals [tl]
      race
      setGoals (hs ++ (← getGoals))
      return
    catch _ => s.restore
  for tac in ← routes do
    if ← closes tac then return
  logInfo m!"mojo_race: open goal{indentExpr ty}"

end Race

/-- **mojo_race** proves the disjointness premises of the race-freedom results from the accesses
of each thread: `Apart cell w` for affine cells, `Elem.Own out w cell a` for an access with given
fields, each element of a list of accesses, `x.conflict y = false` for two accesses, and
`Grid.owned_sound`'s `hX`, `hL` (by `omega`, for an injective `own` with a literal stride; `hX`
also for the index word on a valid 1-D launch, from a hypothesis that the trace's threads are
below the thread count), `hI` (from a hypothesis that every access is owned) and `hO` (for
`Tiling.clip` and the thread numbers, from hypotheses that every access is owned and every access
to `out` is in bounds). The facts it uses are the local context's, by type. A goal it does not
prove stays open and is logged ("mojo_race: open goal"). -/
syntax (name := mojoRace) "mojo_race" : tactic

open Lean.Elab.Tactic in
@[tactic mojoRace, inherit_doc mojoRace]
def evalMojoRace : Tactic := fun _ => Race.race

end MojoProof.Sym
