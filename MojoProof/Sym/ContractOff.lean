import MojoProof.Sym.Kernel
import MojoProof.Sem.ContractOff

/-!
# Contraction off: the observations of complete runs (docs/proofs/contract-off.md)

For every program `P` of the fragment `Program.fbinOracle` (no `fpext` or `fptrunc` in any
function, no `maxnum`, `minnum` or `rsqrt.approx` intrinsic), every program `Q` with `P`'s module
with the `contract` flags removed (`Module.contractOff`) and `P`'s layout and intrinsics, and
every kernel `fn` of the fragment `Func.fbinOracle`:

- `Kernel.Obs.contractOff_iff`: at every address choices `ch` and oracle family `ω`, a value is
  the observation of a complete run (`Kernel.Obs`) of `fn.contractOff` in `Q` under `ω` exactly
  when it is one of `fn` in `P` under the never-fusing rows `neverFuse (ω n)`;
- `Kernel.Obs.contractOff`: its left-to-right direction, from an observation of `Q`.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **The observations with contraction off.** For every program `P` of the fragment
(`Program.fbinOracle`), program `Q` with the module of `P.contractOff`, the layout of `P` and the
intrinsics of `P`, kernel `fn` with no `fpext` or `fptrunc` (`Func.fbinOracle`), launch,
arguments, memory, observation, address choices `ch`, oracle family `ω` and value `y`: `y` is the
observation of a complete run of `fn.contractOff` in `Q` under `ω` exactly when it is one of `fn`
in `P` under the rows `neverFuse (ω n)`. The starts are related by `Grid.start_ctxOff`, and
`Grid.lockstep_contractOff` (flipped from `Q` to `P`) takes a run of one to a run of the other
whose last grid is done exactly when the first's is, with the same memory. -/
theorem Kernel.Obs.contractOff_iff {P Q : Program} (hQ : Q.module = P.module.contractOff)
    (hl : Q.layout = P.layout) (hi : Q.intrinsics = P.intrinsics) (hP : P.fbinOracle = true)
    {fn : Func} (hfn : fn.fbinOracle = true) {L : Launch} {args : List Val} {m : Mem}
    {β : Type} {obs : Mem → Option β} {ch : Nat → Nat} {ω : Nat → Nat → Nat} {y : β} :
    Kernel.Obs Q fn.contractOff L args m obs ch ω y ↔
      Kernel.Obs P fn L args m obs ch (fun n => neverFuse (ω n)) y := by
  have hR := Grid.start_ctxOff hQ hl hi hP hfn L args m ch ω
  constructor
  · rintro ⟨g₂, c₂, z₂, hs₂, hr, hd, ho⟩
    obtain ⟨⟨g, c⟩, hs, hS, hC⟩ := hR.ok_right hs₂
    obtain ⟨z, hz, -, rfl⟩ := (Grid.lockstep_contractOff hC L).symm.reach hS hr
    exact ⟨g, c, z, hs, hz, (Grid.done_contractOff z).1 hd, ho⟩
  · rintro ⟨g, c, z, hs, hr, hd, ho⟩
    obtain ⟨⟨g₂, c₂⟩, hs₂, hS, hC⟩ := hR.ok_left hs
    obtain ⟨z₂, hz, -, rfl⟩ := (Grid.lockstep_contractOff hC L).reach hS hr
    exact ⟨g₂, c₂, _, hs₂, hz, (Grid.done_contractOff z).2 hd, ho⟩

/-- **A run of the kernel with contraction off is a run of the kernel.** For every program `P` of
the fragment (`Program.fbinOracle`), program `Q` with the module of `P.contractOff`, the layout
and the intrinsics of `P`, kernel `fn` with no `fpext` or `fptrunc` (`Func.fbinOracle`), launch,
arguments, memory, observation, address choice `ch` and oracle family `ω`: every observation of
a complete run of `fn.contractOff` in `Q` under `ω` (`Kernel.Obs`) is one of a complete run of
`fn` in `P` under the rows `neverFuse (ω n)` (`Kernel.Obs.contractOff_iff`, left to right). -/
theorem Kernel.Obs.contractOff {P Q : Program} (hQ : Q.module = P.module.contractOff)
    (hl : Q.layout = P.layout) (hi : Q.intrinsics = P.intrinsics) (hP : P.fbinOracle = true)
    {fn : Func} (hfn : fn.fbinOracle = true) {L : Launch} {args : List Val} {m : Mem}
    {β : Type} {obs : Mem → Option β} {ch : Nat → Nat} {ω : Nat → Nat → Nat} {y : β}
    (h : Kernel.Obs Q fn.contractOff L args m obs ch ω y) :
    Kernel.Obs P fn L args m obs ch (fun n => neverFuse (ω n)) y :=
  (Kernel.Obs.contractOff_iff hQ hl hi hP hfn).1 h

end MojoProof.Sym
