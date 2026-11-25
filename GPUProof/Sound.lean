import GPUProof.OneRun
import GPUProof.Run

/-!
# Theorem 0: one run decides every schedule

For every machine `S`:

* `Sound S s₀ obs R E`: from `s₀`, every run is clean (`Clean`), every two reachable done states
  observe the bytes alike up to `E` (`Eq` by default), and every reachable done state's
  observation meets `R`. `Kernel.Sound`: a launch starts at every admitted choice, at a sound
  state.
* `OneRun S`, the law the one-run theorem needs: the steps between states reachable from a good
  start are `Confluent` up to `S.Same` with `Bad` persistent, `S.Same` keeps `Done` and the bytes,
  and a done state neither steps nor faults.
* `Clean.of_lift`: along a projection `π` onto the states whose steps lift, one run of a
  confluent relation to a done state that is not bad makes the image of its first state clean,
  and every reachable done state has the run's final observation, for every observation of the
  states, with no good start. `Sound.of_lift` is its case at an observation of the bytes whose
  final value meets `R`.
* `Sound.of_one_run` (Theorem 0): one run from a start to a done state that is not bad, whose
  observation meets `R`, makes the start sound; `Sound.of_lift` at the states reachable from the
  start. `Done.bad_iff`: a live done state whose running threads are threads of its launch is
  bad only by its trace.
* `Acc.of_lift` and `ReflTransGen.of_lift`: runs and termination lift along a projection whose
  steps lift, which `Clean.of_lift` uses. MojoProof's `MojoProof.Sem.Grid.sound_of_one_run` is
  `Clean.of_lift` at MojoProof's machine, observing the grid's memory.

docs/proofs/theorem0.md has the statements and what MojoProof proves of them.
-/

namespace GPUProof

open Relation

section Lift

variable {γ δ : Type*} {rc : γ → γ → Prop} {R : δ → δ → Prop} {π : γ → δ}

/-- **Termination lifts along a projection**, for every pair of types, relations `rc` on `γ` and
`R` on `δ`, and map `π : γ → δ` such that every `R`-step from `π x` is the image of an `rc`-step
from `x`: if every `rc`-run from `x` is finite, so is every `R`-run from `π x`. -/
theorem Acc.of_lift (lift : ∀ {x y}, R (π x) y → ∃ x', rc x x' ∧ π x' = y) {x : γ}
    (h : Acc (fun b a => rc a b) x) : Acc (fun b a => R a b) (π x) := by
  induction h with
  | intro x _ ih =>
    refine ⟨_, fun y hs => ?_⟩
    obtain ⟨x', hr, rfl⟩ := lift hs
    exact ih x' hr

/-- **Reachability lifts along a projection**, for every pair of types, relations `rc` on `γ` and
`R` on `δ`, and map `π : γ → δ` such that every `R`-step from `π x` is the image of an `rc`-step
from `x`: every state `R` reaches from `π x₀` is the image of a state `rc` reaches from `x₀`. -/
theorem ReflTransGen.of_lift (lift : ∀ {x y}, R (π x) y → ∃ x', rc x x' ∧ π x' = y) {x₀ : γ}
    {y : δ} (h : ReflTransGen R (π x₀) y) : ∃ x, ReflTransGen rc x₀ x ∧ π x = y := by
  induction h with
  | refl => exact ⟨x₀, .refl, rfl⟩
  | tail _ hs ih =>
    obtain ⟨x, hx, rfl⟩ := ih
    obtain ⟨x', hr, rfl⟩ := lift hs
    exact ⟨x', hx.tail hr, rfl⟩

end Lift

variable (S : Sig)

/-- From state `s₀` of machine `S`, for every observation `obs` of the bytes, relation `R` and
equivalence `E` (`Eq` unless given): every run is clean (`Clean`), every two reachable done states
have observations related by `E`, and every reachable done state has an observation that meets
`R`. -/
structure Sound {β : Type} (s₀ : S.State) (obs : S.Bytes → Option β) (R : β → Prop)
    (E : β → β → Prop := Eq) : Prop extends Clean S s₀ where
  /-- `Sound S s₀ obs R E` from `Clean S s₀` and its two fields, on every machine and from every
  state. -/
  mk ::
  /-- Every two reachable done states have observations related by `E`. -/
  determinate : ∀ s s', Reach S s₀ s → Reach S s₀ s' → Done S s → Done S s' →
    Option.Rel E (obs (S.bytes s)) (obs (S.bytes s'))
  /-- Every reachable done state has an observation, and it meets `R`. -/
  post : ∀ s, Reach S s₀ s → Done S s → ∃ y, obs (S.bytes s) = some y ∧ R y

/-- A sound state's runs are clean (`Clean`), on every machine and from every state. -/
add_decl_doc Sound.toClean

/-- Program `P` of machine `S`, launched with `L` on arguments `args` and memory `m`, for every
machine, admission `adm`, observation `obs` and relation `R`: for every choice that `adm`
admits, the launch starts, at a state that is sound for `obs` and `R` (`Sound`). -/
def Kernel.Sound {β : Type} (P : S.Prog) (L : S.Launch) (args : List S.Val) (m : S.Mem)
    (adm : S.Choice → Prop) (obs : S.Bytes → Option β) (R : β → Prop) : Prop :=
  ∀ ω, adm ω → ∃ s₀, S.start P L args m ω = .ok s₀ ∧ GPUProof.Sound S s₀ obs R

/-- What the one-run theorem needs of machine `S`, over the states reachable from a good start
(`Live`): the steps between the states reachable from `s₀` are `Confluent` up to `S.Same`, with
`Bad` persistent; `S.Same` keeps `Done` and the bytes; and a done state neither steps nor faults. -/
class OneRun (S : Sig) : Prop where
  /-- `OneRun S` from its five fields, on every machine. -/
  mk ::
  /-- The steps between states reachable from a good start are confluent up to `S.Same`, with
  `Bad` persistent. -/
  confluent : ∀ {s₀ : S.State}, GoodStart S s₀ →
    Confluent (fun x y : {s // Reach S s₀ s} => Step S x.1 y.1) (fun x y => S.Same x.1 y.1)
      (fun x => Bad S x.1)
  /-- A live state the same as a live done state is done. -/
  same_done : ∀ {s₀ s s' : S.State}, Live S s₀ s → Live S s₀ s' → S.Same s s' → Done S s →
    Done S s'
  /-- Live states that are the same have the same bytes. -/
  same_bytes : ∀ {s₀ s s' : S.State}, Live S s₀ s → Live S s₀ s' → S.Same s s' →
    S.bytes s = S.bytes s'
  /-- A live done state has no step. -/
  done_final : ∀ {s₀ s s' : S.State}, Live S s₀ s → Done S s → ¬ Step S s s'
  /-- A live done state does not fault. -/
  done_safe : ∀ {s₀ s : S.State}, Live S s₀ s → Done S s → ¬ Faults S s

variable {S}

/-- **One run along a projection fixes every schedule's outcome**, for every machine, type `γ`,
map `π : γ → S.State`, relations `rc` and `e` and set `B` on `γ`, and observation `obs` of the
states into every type: let `rc` project onto `Step S` and lift every step from `π x`, be
`Confluent` up to `e` with `B` persistent, and put in `B` every `x` whose `π x` faults or whose
trace races (`racy`) or breaks a frozen read (`kept`); let a done `π x` have no step, and `e` keep
`Done` and `obs`. Then one run of `rc` from `x₀` to a `z` that is not in `B` and whose `π z` is
done makes `π x₀` clean (`Clean`: no reachable state faults, races or breaks a frozen read, every
reachable state that is not done steps, every run is finite), and every reachable done state has
the observation of `π z`. No good start is assumed: `π x₀` is any state. `Sound.of_lift` is its
case at an observation of the bytes, and MojoProof's `MojoProof.Sem.Grid.sound_of_one_run` its
case at MojoProof's machine with an observation of the grid's memory. -/
theorem Clean.of_lift {γ : Type*} {π : γ → S.State} {rc e : γ → γ → Prop} {B : γ → Prop}
    (hc : Confluent rc e B) (proj : ∀ {x x'}, rc x x' → Step S (π x) (π x'))
    (lift : ∀ {x s'}, Step S (π x) s' → ∃ x', rc x x' ∧ π x' = s')
    (hF : ∀ x, Faults S (π x) → B x) (hT : ∀ x, racy S (S.trace (π x)) = true → B x)
    (hK : ∀ x, GPUProof.kept S (S.trace (π x)) = false → B x)
    (hfin : ∀ {x s'}, Done S (π x) → ¬ Step S (π x) s')
    (hD : ∀ {x x'}, e x x' → Done S (π x) → Done S (π x'))
    {α : Type*} {obs : S.State → α} (hO : ∀ {x x'}, e x x' → obs (π x) = obs (π x'))
    {n : Nat} {x₀ z : γ} (run : Path rc n x₀ z) (hz : Done S (π z)) (hb : ¬ B z) :
    Clean S (π x₀) ∧ ∀ s, Reach S (π x₀) s → Done S s → obs s = obs (π z) := by
  have up : ∀ s, Reach S (π x₀) s → ∃ x, ReflTransGen rc x₀ x ∧ π x = s :=
    fun _ hs => ReflTransGen.of_lift lift hs
  obtain ⟨hacc, hnb, hdet, hprog⟩ := hc.one_run run (fun _ hr => hfin hz (proj hr)) hb
  refine ⟨⟨?_, ?_, ?_, ?_, Acc.of_lift lift hacc⟩, ?_⟩
  · intro s hs hf
    obtain ⟨x, hx, rfl⟩ := up s hs
    exact hnb x hx (hF x hf)
  · intro s hs
    obtain ⟨x, hx, rfl⟩ := up s hs
    exact Bool.eq_false_iff.mpr fun ht => hnb x hx (hT x ht)
  · intro s hs
    obtain ⟨x, hx, rfl⟩ := up s hs
    cases hk : GPUProof.kept S (S.trace (π x)) with
    | true => rfl
    | false => exact absurd (hK x hk) (hnb x hx)
  · intro s hs hnd
    obtain ⟨x, hx, rfl⟩ := up s hs
    obtain ⟨_, _, _, hp, he⟩ := hprog x hx
    cases hp with
    | nil => exact absurd (hD he hz) hnd
    | cons hr _ => exact ⟨_, proj hr⟩
  · intro s hs hd
    obtain ⟨x, hx, rfl⟩ := up s hs
    exact (hO (hdet x hx fun _ hr => hfin hd (proj hr))).symm

/-- **One run along a projection decides every schedule**, for every machine, type `γ`, map
`π : γ → S.State`, relations `rc` and `e` and set `B` on `γ`, observation of the bytes and
relation `R`: under `Clean.of_lift`'s premises, with `e` keeping the observation of the bytes,
one run of `rc` from `x₀` to a `z` that is not in `B`, whose `π z` is done and observes `y` with
`R y`, makes `π x₀` sound (`Sound`, with `E = Eq`). It is `Clean.of_lift` at `obs ∘ S.bytes`. No
good start is assumed: `π x₀` is any state. -/
theorem Sound.of_lift {γ : Type*} {π : γ → S.State} {rc e : γ → γ → Prop} {B : γ → Prop}
    (hc : Confluent rc e B) (proj : ∀ {x x'}, rc x x' → Step S (π x) (π x'))
    (lift : ∀ {x s'}, Step S (π x) s' → ∃ x', rc x x' ∧ π x' = s')
    (hF : ∀ x, Faults S (π x) → B x) (hT : ∀ x, racy S (S.trace (π x)) = true → B x)
    (hK : ∀ x, GPUProof.kept S (S.trace (π x)) = false → B x)
    (hfin : ∀ {x s'}, Done S (π x) → ¬ Step S (π x) s')
    (hD : ∀ {x x'}, e x x' → Done S (π x) → Done S (π x'))
    {β : Type} {obs : S.Bytes → Option β} {R : β → Prop}
    (hO : ∀ {x x'}, e x x' → obs (S.bytes (π x)) = obs (S.bytes (π x')))
    {n : Nat} {x₀ z : γ} (run : Path rc n x₀ z) (hz : Done S (π z)) (hb : ¬ B z)
    {y : β} (hy : obs (S.bytes (π z)) = some y) (hR : R y) : Sound S (π x₀) obs R := by
  obtain ⟨hC, h⟩ := Clean.of_lift (obs := fun s => obs (S.bytes s)) hc proj lift hF hT hK hfin hD
    hO run hz hb
  have final : ∀ s, Reach S (π x₀) s → Done S s → obs (S.bytes s) = some y :=
    fun s hs hd => (h s hs hd).trans hy
  refine ⟨hC, fun s s' hs hs' hd hd' => ?_, fun s hs hd => ⟨y, final s hs hd, hR⟩⟩
  rw [final s hs hd, final s' hs' hd']
  exact .some rfl

/-- **Theorem 0: one run decides every schedule**, for every machine with `OneRun`, program,
launch, arguments, caller's memory closed under them, choice, observation and relation: one run
of `n` steps from the start `s₀` to a done state `z` that is not bad and whose observation `y`
meets `R` makes `s₀` sound (`Sound`, with `E = Eq`): no reachable state faults, races or breaks
a frozen read, every reachable state that is not done steps, every run is finite, and every
reachable done state observes `y`. It is `Sound.of_lift` at the states reachable from `s₀`, along
`Subtype.val`, with `Bad` and `OneRun`'s fields. -/
theorem Sound.of_one_run [OneRun S] {P : S.Prog} {L : S.Launch} {args : List S.Val} {m : S.Mem}
    {ω : S.Choice} {s₀ : S.State} (h : S.start P L args m ω = .ok s₀) (hm : S.Closed m args)
    {β : Type} {obs : S.Bytes → Option β} {R : β → Prop}
    {n : Nat} {z : S.State} (run : Path (Step S) n s₀ z) (hz : Done S z) (hb : ¬ Bad S z)
    {y : β} (hy : obs (S.bytes z) = some y) (hR : R y) : Sound S s₀ obs R := by
  have hg : GoodStart S s₀ := ⟨P, L, args, m, ω, h, hm⟩
  have live : ∀ {s}, Reach S s₀ s → Live S s₀ s := fun hs => ⟨hg, hs⟩
  obtain ⟨_, hp⟩ := run.lift (a₀ := s₀) .refl
  exact Sound.of_lift (π := Subtype.val) (OneRun.confluent hg) id
    (fun {x _} hs => ⟨⟨_, ReflTransGen.tail x.2 hs⟩, hs, rfl⟩)
    (fun _ => .inl) (fun _ ht => .inr (.inl ht)) (fun _ hk => .inr (.inr (.inl hk)))
    (fun {x _} => OneRun.done_final (live x.2))
    (fun {x x'} => OneRun.same_done (live x.2) (live x'.2))
    (fun {x x'} he => by rw [OneRun.same_bytes (live x.2) (live x'.2) he]) hp hz hb hy hR

/-- **A live done state is bad only by its trace**, for every machine with `OneRun` and every
state reachable from a good start that is done and whose running threads are threads of its
launch: it is bad exactly when its trace races (`racy`) or breaks a frozen read (`kept`). It does
not fault (`done_safe`), no completion is enabled (`done_final`), no thread of the launch runs
and no issued job is unlanded (`Done`). The design states it without `hrun`; `OneRun` alone does
not give it: `Done` reads only the launch's threads, and `OneRun` says nothing of a thread outside
them that runs without a step. -/
theorem Done.bad_iff [OneRun S] {s₀ s : S.State} (hs : Live S s₀ s) (h : Done S s)
    (hrun : ∀ t u, S.status s t = .run u → t ∈ S.threads (S.launchOf s)) :
    Bad S s ↔ racy S (S.trace s) = true ∨ kept S (S.trace s) = false := by
  constructor
  · rintro (hf | ht | hk | hr)
    · exact absurd hf (OneRun.done_safe hs h)
    · exact .inl ht
    · exact .inr hk
    · rcases hr with ⟨a, ha, -⟩ | ⟨t, s', hf, -⟩
      · cases a with
        | thread t =>
          obtain ⟨u, hu⟩ := ha
          have hd := h.1 t (hrun t u hu)
          rw [hu] at hd
          cases hd
        | job j =>
          have hl := h.2 j ha.1
          rw [ha.2] at hl
          cases hl
      · exact absurd (.inr ⟨t, hf⟩) (OneRun.done_final hs h)
  · rintro (ht | hk)
    · exact .inr (.inl ht)
    · exact .inr (.inr (.inl hk))

end GPUProof
