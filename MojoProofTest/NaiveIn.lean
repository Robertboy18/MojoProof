import MojoProofTest.NaiveSpec
import MojoProofTest.NaiveSound
import MojoProofTest.NaiveFamRun

/-!
# A naive thread in bounds, for every launch

`runIn` proves `NaiveSpec.RunIn ω L K bC bA bB A B` for one program, the naive matmul kernel
`naive` (MojoProofTest/SymPhi.lean, with `fmul contract`), and every oracle family `ω`, launch
`L`, dimensions `m`, `n`, `K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B`: every thread of it
that is in bounds, from `NaiveSpec.At` and a memory of `Elem` after `k` threads with
`Elem.Only`, runs `NaiveThread.chainN` to `ret` with a memory of `Elem` after `k + 1` threads (its
cell holds `NaiveSpec.bytes`) with `Elem.Only`.

Each theorem here is the one of MojoProofTest/NaiveFamRun.lean for the naive family at every row
stride, at the corpus strides `768`, `768`, `50257`: `naive` is `NaiveFam.prog 768 768 50257`
(`NaiveFam.prog_corpus`), its entry summary `NaiveFam.entryF 768 768 50257`
(`NaiveFam.entryF_corpus`) and `NaiveThread.head` the family's `headF` there
(`NaiveFam.headF_corpus`); `At` gives the family's `Mat.Entry` and the sizes of `Mat.Pre`.

* `head_in`: the invariant at round 0 after `%6 → %45` (`NaiveFam.head_inF`);
* `round_in`: at the head of round `j < max K 0`, a round's premises and the invariant after it
  (`NaiveFam.round_inF`);
* `exit_in`: at the head of round `max K 0`, the path out `%46 → %51 → %67 → %69` returns with
  the postcondition of `RunIn` (`NaiveFam.exit_inF`);
* `runIn`: the run, `NaiveFam.runInF`.
-/

namespace MojoProofTest.NaiveIn

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.SymNaive MojoProofTest.NaiveThread MojoProofTest.NaiveSpec
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

/-- `At`'s entry facts are the naive family's `Mat.Entry` at the corpus strides, for every launch,
sizes, blocks, tensors, thread, context, memory and frame (`NaiveFam.prog_corpus`). -/
private theorem entry_corpus {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m' : Mem} {f : Frame}
    (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) :
    Mat.Entry (NaiveFam.prog 768 768 50257) (NaiveFam.fn 768 768 50257) L T z 8 (.fp .float)
      (Val.ofFloat .float) 4 bC bA bB K 50257 A B k c p0 p1 p2 m' f := by
  rw [NaiveFam.prog_corpus.1, NaiveFam.prog_corpus.2]
  exact hAt.entry

/-! ## The loop's three premises at the corpus strides -/

/-- **The loop head after `%6 → %45`**, for every thread at which `At` holds and every list of
pairs: the invariant holds at round 0 (`%47 = 0`, `%48 = +0`) and `%48` carries no
`fmul contract` operands (`NaiveFam.head_inF` at the corpus strides). -/
theorem head_in {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m' : Mem} {f : Frame}
    (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f)
    (ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32)) :
    Inv (oN c 0) ps 0 (head (Valuation.entry c 0 m' f)) ∧
      (head (Valuation.entry c 0 m' f)).prods (idx "48") = none := by
  rw [← NaiveFam.headF_corpus]
  exact NaiveFam.head_inF (entry_corpus hAt) ps

/-- **A round of the loop**, for every thread in bounds at which `At` holds, every round
`j < max K 0` and the head `W` of round `j` (the `j`-th iterate of `round` after `head`) with
`At`'s context and round `j`'s step count at which `Mat.Head` and `Inv` hold and `%48` carries no
`fmul contract` operands: the premises of the round hold, `Inv` holds after it at `j + 1` and
`%48` carries none after it (`NaiveFam.round_inF` at the corpus strides, the sizes from
`At.dims`). -/
theorem round_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) {j : Nat} (hj : j < max K 0)
    {W : Valuation} (hW : W = NaiveThread.round^[j] (head (Valuation.entry c 0 m' f)))
    (hc : W.ctx = c)
    (hk : W.k = (head (Valuation.entry c 0 m' f)).k + j * (pathLen naiveL.H naiveL.B + 1))
    (hF : Mat.Head naive.prog naive.fn_0 (.fp .float) (Val.ofFloat .float) 4 bC bA bB 50257 A B 4
      (cell L) (bytes ω L K A B) k m₀ (S L m n) W)
    (hI : Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) j W)
    (hp : W.prods (idx "48") = none) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧
      Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) (j + 1) (round W) ∧
      (round W).prods (idx "48") = none :=
  NaiveFam.round_inF hAt.valid (dims_lt hAt.dims) ⟨hAt.dims.1, hAt.dims.2.1, hAt.dims.2.1⟩
    hAt.dims.2.2 hS (entry_corpus hAt) hj (by rw [NaiveFam.headF_corpus]; exact hW) hc
    (by rw [NaiveFam.headF_corpus]; exact hk)
    (by rw [NaiveFam.prog_corpus.1, NaiveFam.prog_corpus.2]; exact hF) hI hp

/-- **The path out of the loop**, for every thread in bounds at which `At` holds with the oracle
`ω k`, and the head `W` of round `max K 0` with `At`'s context at which `Mat.Head` holds and `Inv`
holds at `max K 0`, after all of `pairs`: the path `%46 → %51 → %67 → %69` walks and returns, and
its memory meets `Elem` after `k + 1` threads, the thread's cell holding `NaiveSpec.bytes`, and
`Elem.Only` (`NaiveFam.exit_inF` at the corpus strides). -/
theorem exit_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) (hω : c.oracle = ω k)
    {W : Valuation}
    (hW : W = NaiveThread.round^[max K 0] (head (Valuation.entry c 0 m' f))) (hc : W.ctx = c)
    (hF : Mat.Head naive.prog naive.fn_0 (.fp .float) (Val.ofFloat .float) 4 bC bA bB 50257 A B 4
      (cell L) (bytes ω L K A B) k m₀ (S L m n) W)
    (hI : Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) (max K 0) W) :
    RetWith true W
      (fun me => Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me)
      ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X) :=
  NaiveFam.exit_inF hAt.valid (dims_lt hAt.dims) ⟨hAt.dims.1, hAt.dims.2.1, hAt.dims.2.1⟩
    hAt.dims.2.2 hS (entry_corpus hAt) hω (by rw [NaiveFam.headF_corpus]; exact hW) hc
    (by rw [NaiveFam.prog_corpus.1, NaiveFam.prog_corpus.2]; exact hF) hI

/-! ## The theorem -/

/-- **`RunIn` for the naive kernel**, for every oracle family `ω`, launch `L`, dimensions `m`, `n`,
`K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B` (all admitted launches and inputs of this one
program, `naive`, not one example): every thread `k` in bounds, from `At` with the oracle `ω k`
and a memory of `Elem` after `k` threads with `Elem.Only`, runs `chainN` to `ret` with a memory
of `Elem` after `k + 1` threads with `Elem.Only` (`NaiveFam.runInF` at the corpus strides, whose
chain is `chainN` by `NaiveFam.entryF_corpus`). -/
theorem runIn (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) : RunIn ω L K bC bA bB A B := by
  intro _ _ _ _ _ _ _ _ hS hω hAt hE hO
  have h := NaiveFam.runInF hAt.valid (dims_lt hAt.dims) ⟨hAt.dims.1, hAt.dims.2.1, hAt.dims.2.1⟩
    hAt.dims.2.2 hS hω (entry_corpus hAt) hAt.ne hE hO
  rw [NaiveFam.entryF_corpus] at h
  exact ⟨chainN, List.mem_singleton_self _, h⟩

end MojoProofTest.NaiveIn
