import MojoProof.Sem.Precond
import MojoProofTest.SymLaunch
import MojoProofTest.Elementwise

/-!
# Instances and twins of the precondition of a binary elementwise kernel

MojoProof/Sem/Precond.lean at `vadd`'s layout (`lV`, `Kernels.vadd.prog.layout`):

* `Layout.Codec.ptrArg` at `vadd`'s `byval` type `{ ptr, { { {} }, { {} } } }` (`byval_codec`), its
  premises on the empty runtime part `tyU` and its value `Kernels.vadd.argTail` discharged by
  evaluation. The binary32 words are MojoProofTest/Elementwise.lean's `f32`.
* `Map2.pre_mem` on binary32 inputs of length 5 (`x5`, 1.0 in every cell; `y5`, 2.0), element
  count 5, output length 5, alignment 16, and block `i + 1` at address `16 (i + 1)` in space 1 and
  in the generic space: `memX` meets `Map2.Pre` at blocks 1, 2 and 3 (`pre5`), the buffers' fit
  below `2 ^ 64` (`fits`) included.
* `Map2.Pre` with `vadd`'s tail value `argTail` gives the premises of `SymLaunch.vadd_starts` and
  of W1 from the start (`Grid.start_reach_closed`): for every layout, element type, encoder,
  alignment, memory, block numbers, element count and tensors meeting it, every launch, address
  choice and oracle, `vadd` starts on `Map2.args argTail a b o n`, and every grid reachable from the
  start's grid is closed (`pre_starts`; every memory meeting the precondition, `vadd` only). At
  `memX` (`start5`).

Twins. Of `Map2.Pre.ne` (and of `bufs`): with the output at block 1, the first input, `memX` is
closed for the arguments and `vadd` starts on them on every launch, but `Map2.Pre` fails
(`alias_twin`). Of `Map2.Pre.closed`: with the output at block 7, which `memX` does not have
(`next` is 4), `memX` is not closed for the arguments (`missing_twin`). Of `Map2.Pre.fits`: with
every block at generic address `2 ^ 64 - 16` (`memW`), block 1 is a `Mem.Buffer` of 5 floats but
does not fit below `2 ^ 64`, and `Map2.pre_mem`'s premise `hG` fails (`fits_twin`).
-/

namespace MojoProofTest.Precond

open MojoProof MojoProof.Sem MojoProof.LLVM TorchLean FloatLib.Floats.Formats.BinaryInterchange
  MojoProofTest.SymLaunch
open MojoProof.Kernels.vadd (argTail)
open MojoProofTest.Elementwise (f32)

/-- `vadd`'s data layout. -/
abbrev lV : Layout := Kernels.vadd.prog.layout

/-- The empty runtime part of `vadd`'s `LayoutTensor`s, `{ { {} }, { {} } }`. -/
def tyU : Ty := .struct [.struct [.struct []], .struct [.struct []]]

/-- **`vadd`'s `byval` arguments round-trip**: `p ↦ { p, argTail }` is a codec for
`{ ptr, { { {} }, { {} } } }` at `vadd`'s layout. -/
theorem byval_codec : lV.Codec (.struct [.ptr 0, tyU]) (fun p : Ptr => Val.agg [.ptr p, argTail]) :=
  Layout.Codec.ptrArg lV 0 (by decide +kernel) (by decide +kernel) rfl rfl rfl

/-- 1.0 in each of 5 cells. -/
def x5 : Tensor (Model FloatTy.float.fmt) [5] := Tensor.Rep.ofFn fun _ => f32 0x3f800000

/-- 2.0 in each of 5 cells. -/
def y5 : Tensor (Model FloatTy.float.fmt) [5] := Tensor.Rep.ofFn fun _ => f32 0x40000000

/-- The caller memory `Map2.mem` builds for `x5`, `y5` and an output of 5 cells at alignment 16,
block `i + 1` at address `16 (i + 1)` in both spaces. -/
def memX : Mem :=
  Map2.mem lV (.fp .float) (Val.ofFloat .float) 16 x5 y5 5 (fun i => i.val + 1) (fun i => i.val + 1)

/-- **The instance of `Map2.pre_mem`**: `memX` meets the precondition at blocks 1, 2 and 3 with
element count 5. -/
theorem pre5 : Map2.Pre lV (.fp .float) (Val.ofFloat .float) 16 argTail memX 1 2 3 5 x5 y5 :=
  Map2.pre_mem (Layout.Codec.float lV .float) (fun _ => trivial) 16 x5 y5 (by decide) (by decide)
    (Nat.le_refl 5) (fun i => i.val + 1) (fun i => i.val + 1) (by decide +kernel)
    (by decide +kernel) rfl

/-- **The precondition gives `vadd`'s start and W1.** For every layout, element type, encoder,
alignment, memory, block numbers, element count and tensors meeting `Map2.Pre` with tail
`argTail`, every launch, address choice and oracle, `vadd` starts on `Map2.args argTail a b o n`,
and every grid reachable from the start's grid is closed. -/
theorem pre_starts {α : Type} [Storage α] {l : Layout} {t : Ty} {enc : α → Val} {al : Nat}
    {m : Mem} {a b o n N : Nat} {x y : Tensor α [N]} (h : Map2.Pre l t enc al argTail m a b o n x y)
    (L : Launch) (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L (Map2.args argTail a b o n) m ch
      oracle = .ok (g, c) ∧ ∀ g', Relation.ReflTransGen (Grid.Step L c) g g' → g'.Closed c := by
  obtain ⟨g, c, hs⟩ := vadd_starts L a b o _ h.closed ch oracle
  exact ⟨g, c, hs, fun _ hr => Grid.start_reach_closed hs h.closed.bytesIn hr⟩

/-- `vadd` starts on `memX` on every launch, for every address choice and oracle, and every grid
reachable from its grid is closed. -/
theorem start5 (L : Launch) (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L (Map2.args argTail 1 2 3 5) memX ch
      oracle = .ok (g, c) ∧ ∀ g', Relation.ReflTransGen (Grid.Step L c) g g' → g'.Closed c :=
  pre_starts pre5 L ch oracle

/-- **The twin of `Map2.Pre.ne`**: with the output at block 1, the first input, `memX` is closed
for the arguments and `vadd` starts on them, on every launch, for every address choice and
oracle, but `memX` does not meet the precondition. -/
theorem alias_twin (L : Launch) (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    memX.Closed (Map2.args argTail 1 2 1 5) ∧
      (∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L (Map2.args argTail 1 2 1 5) memX ch
        oracle = .ok (g, c)) ∧
      ¬ Map2.Pre lV (.fp .float) (Val.ofFloat .float) 16 argTail memX 1 2 1 5 x5 y5 := by
  have hc : memX.Closed (Map2.args argTail 1 2 1 5) :=
    { pre5.closed with vals := by decide +kernel }
  exact ⟨hc, vadd_starts L 1 2 1 _ hc ch oracle, fun h => h.ne.2.1 rfl⟩

/-- **The twin of `Map2.Pre.closed`**: with the output at block 7, which `memX` does not have,
`memX` is not closed for the arguments. -/
theorem missing_twin : ¬ memX.Closed (Map2.args argTail 1 2 7 5) :=
  fun h => absurd h.vals (by decide +kernel)

/-- The memory of `memX` with every block at generic address `16 (2 ^ 60 - 1) = 2 ^ 64 - 16`: 16
bytes below `2 ^ 64`, too few for 5 floats. -/
def memW : Mem :=
  Map2.mem lV (.fp .float) (Val.ofFloat .float) 16 x5 y5 5 (fun i => i.val + 1)
    (fun _ => 2 ^ 60 - 1)

/-- **The twin of `Map2.Pre.fits`**: in `memW`, block 1 is a read-only `Mem.Buffer` of 5
floats at addresses 16 divides, but it does not fit below `2 ^ 64` (`Mem.Fits` fails), so
`Mem.Buffer` does not give `fits`; `Map2.pre_mem`'s premise `hG` fails for this address choice (at
every `i`). -/
theorem fits_twin : memW.Buffer 1 (5 * lV.size (.fp .float)) 16 false ∧
    ¬ memW.Fits lV 1 (5 * lV.size (.fp .float)) ∧
    ¬ (2 ^ 60 - 1) * 16 + 5 * lV.size (.fp .float) ≤ 2 ^ (lV.ptr 0).1 := by
  refine ⟨⟨_, rfl, rfl, rfl, rfl, rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩,
    fun ⟨blk, hb, hle⟩ => ?_, by decide +kernel⟩
  obtain rfl := Option.some.inj hb
  exact absurd hle (by decide +kernel)

end MojoProofTest.Precond
