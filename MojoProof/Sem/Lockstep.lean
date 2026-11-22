import MojoProof.Sem.Determinism

/-!
# Lockstep transfer (T3a)

For every launch, two context families `c` and `c'` and every relation `S` on grids that is a
lockstep bisimulation (`Grid.Lockstep`: related grids agree on every thread's step and every
collective call, `Grid.Agree`, are done together, have one trace, and have a race enabled
together), from grids related by `S`:

- `Grid.Lockstep.step`, `Grid.Lockstep.path`, `Grid.Lockstep.reach`: a step, a run of `k` steps,
  or a chain of steps under `c` is matched by one under `c'` to a related grid;
- `Grid.Lockstep.faults`, `Grid.Lockstep.bad`: a fault under `c` is one under `c'`, and the grids
  are bad together;
- `Grid.Lockstep.sound`: `Grid.Sound` moves from `c` to `c'` for every observation on which
  related grids in which every thread has returned agree;
- `Grid.payload_run`: if the second grid is a start's, a run under `c` to a grid in which every
  thread has returned that is not bad gives such a run under `c'`, which makes the start's grid
  sound (`Grid.start_sound`).

`Grid.Lockstep.symm` flips it, and `Grid.Lockstep.eq` (`Eq`, for every launch and contexts) is
its instance. The proof is docs/proofs/payload.md section T3a; it uses no property of the
semantics beyond the definitions of `Grid.Step`, `Grid.Bad` and `Grid.Sound`. T3b, that the
skeleton relation of a labelled program is a lockstep bisimulation between two payloads, is not
proved here.
-/

namespace MojoProof.Sem

open MojoProof.LLVM Relation

/-- Two results of a step (an `advance` or a `fire`) agree under `S`: both fault, both take no
step, or both give grids related by `S`. -/
def Grid.Agree (S : Grid → Grid → Prop) :
    Except Fault (Option Grid) → Except Fault (Option Grid) → Prop
  | .error _, .error _ => True
  | .ok none, .ok none => True
  | .ok (some g₁), .ok (some g₂) => S g₁ g₂
  | _, _ => False

/-- `S` is a lockstep bisimulation between the grids of launch `L` under contexts `c` and `c'`:
related grids agree on every thread's step and every collective call, are done together, have
one trace, and have a race enabled together. -/
structure Grid.Lockstep (L : Launch) (c c' : Nat → Ctx) (S : Grid → Grid → Prop) : Prop where
  /-- Builds `Grid.Lockstep` from its five fields. -/
  mk ::
  /-- Every thread's step of related grids agrees: both fault, both have none, or both give
  related grids. -/
  advance : ∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.advance c n) (g₂.advance c' n)
  /-- Every collective call of related grids agrees in the same way. -/
  fire : ∀ {g₁ g₂}, S g₁ g₂ → ∀ n, Grid.Agree S (g₁.fire L c n) (g₂.fire L c' n)
  /-- Related grids are done together. -/
  done : ∀ {g₁ g₂}, S g₁ g₂ → (g₁.Done ↔ g₂.Done)
  /-- Related grids have one trace. -/
  trace : ∀ {g₁ g₂}, S g₁ g₂ → g₁.mem.trace = g₂.mem.trace
  /-- Related grids have a race enabled together. -/
  race : ∀ {g₁ g₂}, S g₁ g₂ → (g₁.RaceEnabled c ↔ g₂.RaceEnabled c')

namespace Grid.Agree

variable {S : Grid → Grid → Prop}

/-- Agreement flips. -/
theorem flip {a b : Except Fault (Option Grid)} (h : Grid.Agree S a b) :
    Grid.Agree (_root_.flip S) b a := by
  rcases a with _ | _ | _ <;> rcases b with _ | _ | _ <;> exact h

/-- A step to a grid agrees only with a step to a related grid. -/
theorem some {g₁ : Grid} {b : Except Fault (Option Grid)} (h : Grid.Agree S (.ok (some g₁)) b) :
    ∃ g₂, b = .ok (some g₂) ∧ S g₁ g₂ := by
  rcases b with _ | _ | g₂
  · exact False.elim h
  · exact False.elim h
  · exact ⟨g₂, rfl, h⟩

/-- A fault agrees only with a fault. -/
theorem error {e : Fault} {b : Except Fault (Option Grid)} (h : Grid.Agree S (.error e) b) :
    ∃ e', b = .error e' := by
  rcases b with e' | _ | _
  · exact ⟨e', rfl⟩
  · exact False.elim h
  · exact False.elim h

end Grid.Agree

namespace Grid.Lockstep

variable {L : Launch} {c c' : Nat → Ctx} {S : Grid → Grid → Prop}

/-- For every launch and contexts, equality is a lockstep bisimulation of the contexts with
themselves. -/
theorem eq (L : Launch) (c : Nat → Ctx) : Grid.Lockstep L c c Eq where
  advance := by
    rintro g _ rfl n
    rcases g.advance c n with _ | _ | _ <;> trivial
  fire := by
    rintro g _ rfl n
    rcases g.fire L c n with _ | _ | _ <;> trivial
  done := by
    rintro _ _ rfl
    exact .rfl
  trace := by
    rintro _ _ rfl
    rfl
  race := by
    rintro _ _ rfl
    exact .rfl

/-- A lockstep bisimulation flips. -/
theorem symm (hS : Grid.Lockstep L c c' S) : Grid.Lockstep L c' c (_root_.flip S) where
  advance h n := (hS.advance h n).flip
  fire h n := (hS.fire h n).flip
  done h := (hS.done h).symm
  trace h := (hS.trace h).symm
  race h := (hS.race h).symm

/-- A step under `c` from one of two related grids is matched by a step under `c'` from the
other to a related grid. The proof takes a step of the same thread and kind; the statement does
not say which. -/
theorem step (hS : Grid.Lockstep L c c' S) {g₁ g₂ h₁ : Grid} (h : S g₁ g₂)
    (hs : Grid.Step L c g₁ h₁) : ∃ h₂, Grid.Step L c' g₂ h₂ ∧ S h₁ h₂ := by
  obtain ⟨n, hn | hn⟩ := hs
  · have := hS.advance h n
    rw [hn] at this
    obtain ⟨h₂, ha, e⟩ := this.some
    exact ⟨h₂, ⟨n, .inl ha⟩, e⟩
  · have := hS.fire h n
    rw [hn] at this
    obtain ⟨h₂, ha, e⟩ := this.some
    exact ⟨h₂, ⟨n, .inr ha⟩, e⟩

/-- A run of `k` steps under `c` from one of two related grids is matched by a run of `k` steps
under `c'` from the other to a related grid. -/
theorem path (hS : Grid.Lockstep L c c' S) {k : Nat} {g₁ z₁ : Grid}
    (p : Path (Grid.Step L c) k g₁ z₁) :
    ∀ {g₂}, S g₁ g₂ → ∃ z₂, Path (Grid.Step L c') k g₂ z₂ ∧ S z₁ z₂ := by
  induction p with
  | nil => exact fun h => ⟨_, .nil _, h⟩
  | cons hs _ ih =>
    intro g₂ h
    obtain ⟨h₂, hs₂, e⟩ := hS.step h hs
    obtain ⟨z₂, p₂, hz⟩ := ih e
    exact ⟨z₂, .cons hs₂ p₂, hz⟩

/-- A grid reachable under `c` from one of two related grids is related to a grid reachable under
`c'` from the other. -/
theorem reach (hS : Grid.Lockstep L c c' S) {g₁ g₂ z₁ : Grid} (h : S g₁ g₂)
    (hr : ReflTransGen (Grid.Step L c) g₁ z₁) :
    ∃ z₂, ReflTransGen (Grid.Step L c') g₂ z₂ ∧ S z₁ z₂ := by
  obtain ⟨_, p⟩ := Path.exists_iff.2 hr
  obtain ⟨z₂, p₂, hz⟩ := hS.path p h
  exact ⟨z₂, Path.exists_iff.1 ⟨_, p₂⟩, hz⟩

/-- If one of two related grids faults under `c`, the other faults under `c'`. -/
theorem faults (hS : Grid.Lockstep L c c' S) {g₁ g₂ : Grid} (h : S g₁ g₂)
    (hf : g₁.Faults L c) : g₂.Faults L c' := by
  obtain ⟨n, e, he | he⟩ := hf
  · have := hS.advance h n
    rw [he] at this
    obtain ⟨e', h'⟩ := this.error
    exact ⟨n, e', .inl h'⟩
  · have := hS.fire h n
    rw [he] at this
    obtain ⟨e', h'⟩ := this.error
    exact ⟨n, e', .inr h'⟩

/-- Two related grids are bad together. -/
theorem bad (hS : Grid.Lockstep L c c' S) {g₁ g₂ : Grid} (h : S g₁ g₂) :
    g₁.Bad L c ↔ g₂.Bad L c' := by
  have key : ∀ {c c' : Nat → Ctx} {S : Grid → Grid → Prop}, Grid.Lockstep L c c' S →
      ∀ {g₁ g₂ : Grid}, S g₁ g₂ → g₁.Bad L c → g₂.Bad L c' := by
    rintro c c' S hS g₁ g₂ h (hf | hr | hk | he)
    · exact .inl (hS.faults h hf)
    · exact .inr (.inl (hS.trace h ▸ hr))
    · exact .inr (.inr (.inl (hS.trace h ▸ hk)))
    · exact .inr (.inr (.inr ((hS.race h).1 he)))
  exact ⟨key hS h, key hS.symm h⟩

/-- **`Grid.Sound` moves across a lockstep bisimulation.** For every observation `obs` on which
related grids in which every thread has returned agree, and every relation `R`: if one of two
related grids is sound under `c`, the other is sound under `c'`. -/
theorem sound (hS : Grid.Lockstep L c c' S) {g₁ g₂ : Grid} (h : S g₁ g₂) {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hO : ∀ {x y}, S x y → x.Done → obs x.mem = obs y.mem)
    (hs : Grid.Sound L c g₁ obs R) : Grid.Sound L c' g₂ obs R where
  safe x hx hf := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    exact hs.safe y hy (hS.symm.faults e hf)
  raceFree x hx := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    rw [← hS.trace e]
    exact hs.raceFree y hy
  kept x hx := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    rw [← hS.trace e]
    exact hs.kept y hy
  progress x hx hd := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    obtain ⟨y', hs'⟩ := hs.progress y hy fun hd' => hd ((hS.done e).1 hd')
    obtain ⟨x', hx', -⟩ := hS.step e hs'
    exact ⟨x', hx'⟩
  terminates := by
    have key : ∀ y, Acc (fun g' g => Grid.Step L c g g') y → ∀ x, S y x →
        Acc (fun g' g => Grid.Step L c' g g') x := by
      intro y hy
      induction hy with
      | intro y _ ih =>
        intro x e
        refine .intro x fun x' hx' => ?_
        obtain ⟨y', hy', e'⟩ := hS.symm.step e hx'
        exact ih y' hy' x' e'
    exact key g₁ hs.terminates g₂ h
  determinate x x' hx hx' hd hd' := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    obtain ⟨y', hy', e'⟩ := hS.symm.reach h hx'
    have hdy := (hS.done e).2 hd
    have hdy' := (hS.done e').2 hd'
    rw [← hO e hdy, ← hO e' hdy']
    exact hs.determinate y y' hy hy' hdy hdy'
  post x hx hd := by
    obtain ⟨y, hy, e⟩ := hS.symm.reach h hx
    have hdy := (hS.done e).2 hd
    rw [← hO e hdy]
    exact hs.post y hy hdy

end Grid.Lockstep

/-- **A run moves to a start across a lockstep bisimulation (T3a's corollary).** For every
program, kernel, launch, arguments, address choice and oracle, on a caller's memory every pointer
byte of whose blocks names a number below `next` or with a block, and every contexts `c` and
relation `S` with `Grid.Lockstep L c c' S` for the start's contexts `c'`: a run of `k` steps under
`c` from a grid related to the start's grid to a grid `z₁` in which every thread has returned and
that is not bad gives a run of `k` steps from the start's grid to a grid `z₂` related to `z₁`, in
which every thread has returned and that is not bad; and for every observation that reads only
the blocks, whose value `y` at `z₂` satisfies `R`, the start's grid is sound. -/
theorem Grid.payload_run {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₂ : Grid} {c' : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₂, c')) (hm : m.BytesIn m.Known)
    {c : Nat → Ctx} {S : Grid → Grid → Prop} (hS : Grid.Lockstep L c c' S) {g₁ : Grid}
    (e : S g₁ g₂) {k : Nat} {z₁ : Grid} (run : Path (Grid.Step L c) k g₁ z₁) (hz : z₁.Done)
    (hb : ¬ z₁.Bad L c) :
    ∃ z₂, Path (Grid.Step L c') k g₂ z₂ ∧ z₂.Done ∧ ¬ z₂.Bad L c' ∧ S z₁ z₂ ∧
      ∀ {β : Type} {obs : Mem → Option β} {R : β → Prop},
        (∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') →
        ∀ {y : β}, obs z₂.mem = some y → R y → Grid.Sound L c' g₂ obs R := by
  obtain ⟨z₂, p₂, ez⟩ := hS.path run e
  have hz₂ := (hS.done ez).1 hz
  have hb₂ : ¬ z₂.Bad L c' := fun hb₂ => hb ((hS.bad ez).2 hb₂)
  refine ⟨z₂, p₂, hz₂, hb₂, ez, fun {_ _ _} hO {_} hy hR => ?_⟩
  exact Grid.start_sound h hm hO p₂ hz₂ hb₂ hy hR

end MojoProof.Sem
