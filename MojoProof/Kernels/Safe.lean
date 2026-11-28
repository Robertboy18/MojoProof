import MojoProof.Sem.Spec

/-!
# The spec-free kernel theorem: `Kernel.Safe`

`Kernel.Safe prog fn L args m adm obs` is `MojoProof.Sem.Kernel.Sound` at the relation that
holds of every output (`fun _ => True`): the launch starts at every admitted address choice and
oracle family, and its grid is sound for the observation `obs` and that relation. It says what
soundness says of a run and nothing of what the output is (docs/proofs/safe.md).

`Kernel.Safe.of_sound` gives it from soundness at any relation, with the same program, kernel,
launch, arguments, memory, admission and observation.

The module is in the library `MojoProofKernels` (the build's globs take every module under
`MojoProof.Kernels`), with the kernels whose theorems it weakens; its declarations are in
`MojoProof.Sem`, beside `MojoProof.Sem.Kernel.Sound`.
-/

namespace MojoProof.Sem

open MojoProof.LLVM

/-- **Kernel `fn` of `prog` is safe**, launched with `L` on arguments `args` and memory `m`, for
the admission `adm` and the observation `obs`: `MojoProof.Sem.Kernel.Sound prog fn L args m adm
obs (fun _ => True)`, soundness at the relation that holds of every output. For every address
choice `ch` and oracle family `ω` that `adm` admits, the launch starts (`Grid.start` returns
`.ok (g, c)`) and the grid `g` is sound (`MojoProof.Sem.Grid.Sound`, MojoProof/Sem/Spec.lean):

* no reachable grid faults (`MojoProof.Sem.Grid.Safe`: no undefined behavior, no out-of-bounds
  or dead access, no unsupported instruction);
* no reachable grid's trace has a data race (`MojoProof.Sem.Grid.RaceFree`);
* every reachable grid keeps the promise of `!invariant.load` (`MojoProof.Sem.Grid.Kept`);
* every reachable grid with a thread that has not returned has a step
  (`MojoProof.Sem.Grid.Progress`: no deadlock at a barrier);
* every execution is finite, for steps of any threads in any order
  (`MojoProof.Sem.Grid.Terminates`);
* the reachable grids in which every thread has returned agree on `obs`
  (`MojoProof.Sem.Grid.Determinate`: one observation for every schedule);
* each of those grids has an observation (`obs` is `some y`; the relation `True` holds of it).

`MojoProof.Sem.Kernel.Sound.exists_obs` applies to it: at an admitted choice the launch starts
and some complete run is observed. What it does not say: anything of the observed value, so no
specification of the output (an elementwise sum, a product, a bound) and no relation between the
inputs and the output; those are `Kernel.Sound` at a relation that depends on its argument. -/
def Kernel.Safe {β : Type} (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop) (obs : Mem → Option β) : Prop :=
  Kernel.Sound prog fn L args m adm obs (fun _ => True)

/-- **A sound kernel is safe**, for every program, kernel, launch, arguments, memory, admission,
observation and relation `R`: `MojoProof.Sem.Kernel.Sound` at `R` gives `Kernel.Safe` with the
same program, kernel, launch, arguments, memory, admission and observation (the relation
weakened to `True`; every field of `MojoProof.Sem.Grid.Sound` but the relation is kept). -/
theorem Kernel.Safe.of_sound {β : Type} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    {obs : Mem → Option β} {R : β → Prop} (h : Kernel.Sound prog fn L args m adm obs R) :
    Kernel.Safe prog fn L args m adm obs := fun ch ω ha => by
  obtain ⟨g, c, hs, hg⟩ := h ch ω ha
  refine ⟨g, c, hs, { hg with post := fun g' hr hd => ?_ }⟩
  obtain ⟨y, hy, -⟩ := hg.post g' hr hd
  exact ⟨y, hy, trivial⟩

end MojoProof.Sem
