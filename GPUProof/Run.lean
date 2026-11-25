import GPUProof.Race

/-!
# The runs of a machine

What a run of a machine `S` is, for every machine: the same definitions read every signature.

* `Step`: one schedule step, an agent's step (`Sig.advance`) or a completed collective call
  (`Sig.fire`); `Reach`, its reflexive transitive closure (Mathlib's `Relation.ReflTransGen`).
  GPUProof/OneRun.lean has the paths of a relation (`Path`) and the one-run argument.
* `GoodStart`: the start of a launch on a caller memory that `S.Closed` accepts with the
  arguments; `Live`, the states reachable from a good start, which the laws of a machine speak of.
* `Faults`: some agent's step or some completion faults. `Running`: a thread running, or an issued
  job not yet landed. `Done`: every thread returned and every issued job landed.
* `RaceEnabled`: a running agent's next step, or a completion, would log a race. `Bad`: a fault,
  a race in the trace (`racy`), a frozen read not kept (`kept`), or an enabled race.
* `Clean`: from a start, no reachable state faults, races or breaks a frozen read, every reachable
  state that is not done steps, and every run is finite.

docs/proofs/core.md gives the definitions and where they depart from the design.
-/

namespace GPUProof

open Relation

variable (S : Sig)

/-- A schedule step of machine `S` from `s` to `s'`: one agent's step (`S.advance`), or one
completed collective call of a thread (`S.fire`). -/
def Step (s s' : S.State) : Prop :=
  (∃ a, S.advance s a = .ok (some s')) ∨ ∃ t, S.fire s t = .ok (some s')

/-- Reachability on machine `S`: zero or more `Step`s. -/
def Reach : S.State → S.State → Prop :=
  ReflTransGen (Step S)

/-- A good start of machine `S`: the start of a launch of a program on arguments, a caller's
memory closed under them (`S.Closed`) and a choice. -/
def GoodStart (s₀ : S.State) : Prop :=
  ∃ P L args m ω, S.start P L args m ω = .ok s₀ ∧ S.Closed m args

/-- The states the laws of machine `S` speak of: `s` is reachable from the good start `s₀`. -/
def Live (s₀ s : S.State) : Prop :=
  GoodStart S s₀ ∧ Reach S s₀ s

/-- State `s` of machine `S` faults: some agent's step, or some thread's completion, faults. -/
def Faults (s : S.State) : Prop :=
  (∃ a e, S.advance s a = .error e) ∨ ∃ t e, S.fire s t = .error e

/-- Agent `a` runs at state `s` of machine `S`: a thread that is running, or an issued job that has
not landed. -/
def Running (s : S.State) : S.Agent → Prop
  | .thread t => ∃ u, S.status s t = .run u
  | .job j => j ∈ S.jobs s ∧ S.landed s j = false

/-- State `s` of machine `S` is done: every thread of its launch has returned and every issued job
has landed. -/
def Done (s : S.State) : Prop :=
  (∀ t ∈ S.threads (S.launchOf s), S.status s t = .done) ∧ ∀ j ∈ S.jobs s, S.landed s j = true

/-- At state `s` of machine `S`, a running agent's next step, or a completion of a thread's call,
would log a race: the trace with its pending events (`S.pending`, `S.firePending`) is `racy`. -/
def RaceEnabled (s : S.State) : Prop :=
  (∃ a, Running S s a ∧ racy S (S.trace s ++ S.pending s a) = true) ∨
    ∃ t s', S.fire s t = .ok (some s') ∧ racy S (S.trace s ++ S.firePending s t) = true

/-- State `s` of machine `S` is bad: it faults, its trace races (`racy`) or breaks a frozen read
(`kept`), or a race is enabled (`RaceEnabled`). -/
def Bad (s : S.State) : Prop :=
  Faults S s ∨ racy S (S.trace s) = true ∨ kept S (S.trace s) = false ∨ RaceEnabled S s

/-- From state `s₀` of machine `S`, every run is clean: the part of soundness that names no
observation. -/
structure Clean (s₀ : S.State) : Prop where
  /-- `Clean S s₀` from its five fields, on every machine and from every state. -/
  mk ::
  /-- No reachable state faults. -/
  safe : ∀ s, Reach S s₀ s → ¬ Faults S s
  /-- No reachable state's trace races. -/
  raceFree : ∀ s, Reach S s₀ s → racy S (S.trace s) = false
  /-- Every reachable state's trace keeps its frozen reads. -/
  kept : ∀ s, Reach S s₀ s → kept S (S.trace s) = true
  /-- Every reachable state that is not done steps. -/
  progress : ∀ s, Reach S s₀ s → ¬ Done S s → ∃ s', Step S s s'
  /-- Every run from `s₀` is finite. -/
  terminates : Acc (fun s' s => Step S s s') s₀

end GPUProof
