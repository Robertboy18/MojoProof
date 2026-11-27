import MojoProof.Tile.MatVec
import MojoProof.Sem.Grid

/-!
# The stored words of a warp per output, one form for rows and columns

A kernel that reduces each output with one warp and stores it from lane 0 is stated, at its end
memory, by three definitions shared by every such kernel:

* `warpObs`: for every layout, launch, count `M` and output block `p0`, the binary32 words that
  thread `32 i` loads at offset `4 i` of `p0`, for each `i < M`; thread `32 i` is lane 0 of
  warp `i` when 32 divides the block's volume, as at gemv_kernel's and gevm_kernel's launches;
* `WarpWords`: for every float type, count, flag, oracle sequences `o` and pairs `P`, each output
  `j` loads as a word of the type NaN-equal to `MojoProof.Sem.warpDot c (o j) (P j)`;
* `Loads`: for every float type, index type and property `Q` of words, the outputs load as words
  `W` of the type that meet `Q`; at `Q` a spec's rule, the words meet the rule.

`WarpWords.loads` gives `Loads` at every property that NaN-equal words meet. At
`P = MojoProof.Sem.matVecPairs A v` (rows of gemv_kernel) the words meet
`GPUProof.Spec.matVec`'s rule (`MojoProof.Tile.warpDot_matVec_holds`); at
`P = MojoProof.Sem.vecMatPairs A B` (columns of gevm_kernel) they meet `GPUProof.Spec.vecMat`'s
(`MojoProof.Tile.warpDot_vecMat_holds`). Which run stores the words is a premise of every use; this
module proves nothing about a run. docs/proofs/tile.md says which kernel uses each.
-/

namespace MojoProof.Tile

open MojoProof.LLVM MojoProof.Sem FloatLib.Floats.Formats.BinaryInterchange

/-- **Outputs that load as words meeting a property**: for every float type `t`, index type `ι`,
property `Q` of words of `t`'s format and loads `f`, every output `i` loads as `Val.ofFloat t (W i)`
for words `W` that meet `Q`. At `Q` a spec's rule at its encoding and input words, the stored
words meet the rule. -/
def Loads {ι : Type} (t : FloatTy) (Q : (ι → Model t.fmt) → Prop) (f : ι → Except Fault Val) :
    Prop :=
  ∃ W : ι → Model t.fmt, (∀ i, f i = .ok (Val.ofFloat t (W i))) ∧ Q W

/-- **Outputs that load as a warp's dot products**: for every float type `t`, count `N`, flag `c`,
oracle sequences `o j` and pairs `P j` of each output and loads `f`, each output `j < N` loads as
`Val.ofFloat t x` for a word `x` that is `MojoProof.Sem.warpDot c (o j) (P j)` or both are NaNs
(`NaNEq`). -/
def WarpWords {N : Nat} (t : FloatTy) (c : Bool) (o : Fin N → Nat → Nat → Nat × Nat)
    (P : Fin N → List (Model t.fmt × Model t.fmt)) (f : Fin N → Except Fault Val) : Prop :=
  ∀ j : Fin N, ∃ x, f j = .ok (Val.ofFloat t x) ∧ NaNEq x (warpDot c (o j) (P j))

/-- **A warp's dot products load as words meeting every property they meet**: for every float type
`t`, count `N`, flag `c`, oracle sequences `o`, pairs `P`, loads `f` and property `Q` that every
words NaN-equal to the outputs' `warpDot c (o j) (P j)` meet, `WarpWords t c o P f` gives
`Loads t Q f`, at the words the outputs load as. -/
theorem WarpWords.loads {N : Nat} {t : FloatTy} {c : Bool} {o : Fin N → Nat → Nat → Nat × Nat}
    {P : Fin N → List (Model t.fmt × Model t.fmt)} {f : Fin N → Except Fault Val}
    {Q : (Fin N → Model t.fmt) → Prop} (h : WarpWords t c o P f)
    (hQ : ∀ W : Fin N → Model t.fmt, (∀ j, NaNEq (W j) (warpDot c (o j) (P j))) → Q W) :
    Loads t Q f :=
  ⟨fun j => (h j).choose, fun j => (h j).choose_spec.1, hQ _ fun j => (h j).choose_spec.2⟩

/-- **The words thread `32 i` loads at offset `4 i`**, for every layout `l`, launch `L`, count
`M`, output block `p0` and memory `m`: output `i`'s binary32 load at offset `4 i` of `p0` by
thread `32 i` of `L` (`⟨32 i, 32 i / volume L.block⟩`, the `who` the start gives it), for each
`i < M`. It reads only the blocks and names no start's contexts. Thread `32 i` has the lane
`32 i % volume L.block % 32` (`MojoProof.Sem.Launch.env`). When 32 divides `volume L.block`, as
at gemv_kernel's launches (`32 ∣ L.block .x`, one-dimensional blocks) and gevm_kernel's (blocks
of 1024 threads), whose premises give it, that lane is 0 and threads `32 i` to `32 i + 31` are
one warp of one block, so the words are those lane 0 of warp `i` loads. At other block sizes
thread `32 i` need not be lane 0: at a block of 33 threads, thread 64 has lane 31.
gemv_kernel's rows and gevm_kernel's columns are its cases at their programs' layouts, which are
the same layout. -/
def warpObs (l : Layout) (L : Launch) (M p0 : Nat) (m : Mem) : Option (Fin M → Except Fault Val) :=
  some fun i => m.load l ⟨32 * i.val, 32 * i.val / volume L.block⟩ 0 (.fp .float)
    ⟨p0, ((i.val * 4 : Nat) : Int)⟩ (some 4)

end MojoProof.Tile
