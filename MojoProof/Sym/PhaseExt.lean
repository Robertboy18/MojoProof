import MojoProof.Sym.SegTrace

/-!
# The phases of a trace extended one block of threads after another

`phases` (MojoProof/Sem/SigDef.lean) gives each access of a trace its phase: the number of
barriers of its block of threads before it. A run whose blocks of threads run one after another
(`PhaseRun`, MojoProof/Sym/CanonBar.lean) extends its trace block by block: one block's events
before its barrier, the barrier, then its events after it. `phases_rounds`
(MojoProof/Sem/Shared.lean) takes a trace of rounds of the whole grid instead. Every result here
is for every property of accesses at a phase, barrier count, memory and property of events.

* `PhaseInv`: every access of the memory's trace with its phase (`phasesF`) has a property, and
  the trace counts, for each block of threads, a given number of barriers.
* `PhaseInv.nil`, `PhaseInv.ext`, `PhaseInv.bar`: an empty trace has it at no barrier; a trace
  extended (`Ext`) by accesses that have the property at their block's count keeps it; a barrier
  of block `b` adds one to `b`'s count.
* `PhaseInv.phases`: then every access of `phases` has the property at its phase.
-/

namespace MojoProof.Sym

open MojoProof.Sem

/-- **The phase invariant of a trace**, for every property `R p a` of an access `a` at phase
`p`, barrier count `f` and memory `m`: `m`'s trace has `f j` barriers of each block of threads
`j`, and each of its accesses has `R` at its phase (`phasesF`). -/
def PhaseInv (R : Nat → Access → Prop) (f : Nat → Nat) (m : Mem) : Prop :=
  (phasesF m.trace).2 = f ∧ ∀ x ∈ (phasesF m.trace).1, R x.2 x.1

/-- **An empty trace has the phase invariant**, for every property `R` of accesses at a phase,
memory `m` with an empty trace (the start's, `Grid.start_trace`) and barrier count `f` that is
0 at every block of threads. -/
theorem PhaseInv.nil (R : Nat → Access → Prop) {f : Nat → Nat} {m : Mem} (h : m.trace = [])
    (hf : ∀ j, f j = 0) : PhaseInv R f m := by
  unfold PhaseInv
  rw [h]
  exact ⟨funext fun j => (hf j).symm, fun _ hx => nomatch hx⟩

/-- **Accesses at their blocks' counts keep the phase invariant**, for every property `R` of
accesses at a phase, barrier count `f`, memories `m`, `m'` and property `P` of events: if `m`
has the invariant at `f` and `m'` extends `m`'s trace by events of `P` (`Ext`), each an access
`a` with `R` at its block's count `f a.who.cta`, `m'` has it at `f`. -/
theorem PhaseInv.ext {R : Nat → Access → Prop} {f : Nat → Nat} {m m' : Mem} {P : Event → Prop}
    (h : PhaseInv R f m) (he : Ext P m m')
    (hP : ∀ e, P e → ∃ a, e = .access a ∧ R (f a.who.cta) a) : PhaseInv R f m' := by
  obtain ⟨E, hE, hp⟩ := he
  unfold PhaseInv
  rw [hE]
  clear hE
  induction E with
  | nil => exact h
  | cons e E ih =>
    obtain ⟨h2, h1⟩ := ih fun e' he' => hp e' (List.mem_cons_of_mem _ he')
    obtain ⟨a, rfl, ha⟩ := hP _ (hp _ (List.mem_cons.2 (.inl rfl)))
    refine ⟨h2, fun x hx => ?_⟩
    change x ∈ (a, (phasesF (E ++ m.trace)).2 a.who.cta) :: (phasesF (E ++ m.trace)).1 at hx
    rcases List.mem_cons.1 hx with rfl | hx
    · rw [h2]
      exact ha
    · exact h1 x hx

/-- **A barrier counts once more**, for every property `R` of accesses at a phase, barrier
counts `f`, `f'`, memory `m` and block of threads `b`: if `m` has the invariant at `f`, `m` with
`b`'s barrier logged has it at the count `f'` that is `f` plus one at `b`. -/
theorem PhaseInv.bar {R : Nat → Access → Prop} {f f' : Nat → Nat} {m : Mem} (h : PhaseInv R f m)
    {b : Nat} (hf : ∀ j, f' j = if b = j then f j + 1 else f j) :
    PhaseInv R f' (m.log (.barrier b)) := by
  refine ⟨funext fun j => ?_, h.2⟩
  rw [hf j]
  show (if b = j then (phasesF m.trace).2 j + 1 else (phasesF m.trace).2 j) = _
  rw [h.1]

/-- **The phase invariant gives every access of `phases`**, for every property `R` of accesses
at a phase, barrier count `f` and memory `m` with the invariant: every access of
`phases m.trace` has `R` at its phase (`phasesF_eq`). -/
theorem PhaseInv.phases {R : Nat → Access → Prop} {f : Nat → Nat} {m : Mem}
    (h : PhaseInv R f m) : ∀ x ∈ (Sem.phases m.trace).1, R x.2 x.1 :=
  fun x hx => h.2 x ((phasesF_eq m.trace).1 ▸ hx)

end MojoProof.Sym
