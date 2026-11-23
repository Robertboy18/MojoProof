import MojoProofTest.NaiveSpec
import MojoProofTest.NaiveSound
import MojoProofTest.OblMatmul
import MojoProof.Sym.OblHave
import MojoProof.Sym.Inv

/-!
# A naive thread in bounds, for every launch

`runIn` proves `NaiveSpec.RunIn ω L K bC bA bB A B` for one program, the naive matmul kernel
`naive` (MojoProofTest/SymPhi.lean, with `fmul contract`), and every oracle family `ω`, launch
`L`, dimensions `m`, `n`, `K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B`: every thread of it
that is in bounds, from `NaiveSpec.At` and a memory of `Elem` after `k` threads with
`Elem.Only`, runs `NaiveThread.chainN` to `ret` with a memory of `Elem` after `k + 1` threads (its
cell holds `NaiveSpec.bytes`) with `Elem.Only`. It is `NaiveSound.naive.runInv`, the run that
`mojo_kernel`'s `mat … inv` clause generates (the edge into the loop by `mojo_obl`, the facts
`Mat.Head` at the head of every round by mojo_inv and `Mat.Head.iterate`), at the invariant
`NaiveThread.Inv` with `%48`'s `fmul contract` operands, and its three premises
(`LoopIterWith`, at the heads of the rounds) are three theorems, which read the registers that
the loop keeps at the head of every round from `NaiveSound.naive.kept`, the clause's:

* `head_in`: the invariant at round 0 after `%6 → %45`;
* `round_in`: at the head of round `j`, a round's premises (`OblMatmul.naive_rounds`), `%48`'s
  operands, the counter and the accumulator's `fadd` after it, from `naive.kept` and
  `Mat.Head`;
* `exit_in`: the path out `%46 → %51 → %67 → %69` returns with the postcondition of `RunIn`
  (`OblMatmul.naive_exit`; mojo_inv through `%67`'s store, `Elem.apply_store`, `Elem.Only.apply`).

The tactic `obl_have` (MojoProof/Sym/OblHave.lean) names values that `mojo_obl`'s evaluator
computes from the hypotheses `At`, `Mat.Head` and `Inv` and their parts: registers, their
`fmul contract` operands, memories and node values, several in one run. The tactic `mojo_inv`
(MojoProof/Sym/Inv.lean) proves `%40` at the loop head with `At`'s bounds (`naive.kept` states it
as its value there), `%48`'s operands after the edge into the loop and after a round,
and `exit_in`'s `Elem` and `Elem.Only` after `%67`'s store, from the encoding of `%48`.
-/

namespace MojoProofTest.NaiveIn

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.SymNaive MojoProofTest.NaiveThread MojoProofTest.NaiveSpec
open FloatLib.Floats.Formats.BinaryInterchange TorchLean

open Lean Meta Elab Tactic in
/-- `kernel_rfl` closes a goal `a = b` that the kernel shows by unfolding (`Obl.krfl`): the
`decide +kernel` of equations whose type has no decidable equality, such as lists of `phi`
operands (`Value`, with its float literals). It fails when the kernel does not show it. -/
elab "kernel_rfl" : tactic => withMainContext do
  let g ← getMainGoal
  let some (_, a, b) := (← instantiateMVars (← g.getType)).eq?
    | throwError "kernel_rfl: not an equation"
  g.assign (← Obl.krfl a b)
  replaceMainGoal []

/-- error: mojo_obl: the kernel does not show
  1
equal to
  2 -/
#guard_msgs in
example : (1 : Nat) = 2 := by kernel_rfl

/-! ## Shared facts -/

/-- The entry valuation of `%67` on the path out from `W`. -/
private def out7 (W : Valuation) : Valuation :=
  (W.intoWith true naive.fn_0.b_3.label hdr).intoWith true naive.fn_0.b_5.label out

/-! ## The three premises of `NaiveSound.naive.runInv` -/

/-- **The loop head after `%6 → %45`**, for every thread at which `At` holds and every list of
pairs: the invariant holds at round 0 (`%47 = 0` and `%48 = +0`, the `phi`s at the edge
`%45 → %46`, an integer and a float constant, by one `obl_have`) and `%48` carries no
`fmul contract` operands (mojo_inv). -/
theorem head_in {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m' : Mem} {f : Frame}
    (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f)
    (ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32)) :
    Inv (oN c 0) ps 0 (head (Valuation.entry c 0 m' f)) ∧
      (head (Valuation.entry c 0 m' f)).prods (idx "48") = none := by
  obl_have g47 : (head (Valuation.entry c 0 m' f)).regs (idx "47"),
    g48 : (head (Valuation.entry c 0 m' f)).regs (idx "48")
  exact ⟨⟨g47, g48.trans (by kernel_rfl)⟩, by mojo_inv⟩

/-- **A round of the loop**, for every thread in bounds at which `At` holds, all oracle numbers
`o`, every round `j` below the trip count and the head `W` of round `j` (the `j`-th iterate of
`round` after `head`) with `At`'s context at which `Mat.Head` and `Inv` hold and `%48` carries
no `fmul contract` operands: the premises of the round hold (`OblMatmul.naive_rounds`), `%48`
carries none after it, the counter after it is `j + 1`, and the accumulator after it is the
`fadd` of the accumulator before it and the `fmul` of pair `j` of `pairs`, under the oracle
numbers of the latch's statements 12 and 13. The registers `%11`, `%12`, `%16`, `%26` and `%37`
at `W` are `NaiveSound.naive.kept`'s. One `obl_have` gives the counter `%47`, `%48` itself (the
latch's `fadd contract` of `%48` and the `fmul` of the loads, mojo_obl's evaluator on symbolic
floats, `SNode.eval_fbinP_ofFloat`) and the memory after the round, from one evaluation of the
round's nodes; mojo_inv gives `%48`'s operands after the round. -/
theorem round_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) {o : Nat → Nat × Nat}
    {j : Nat} (hj : j < (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length) {W : Valuation}
    (hW : W = NaiveThread.round^[j] (head (Valuation.entry c 0 m' f))) (hc : W.ctx = c)
    (hF : Mat.Head naive.prog naive.fn_0 (.fp .float) (Val.ofFloat .float) 4 bC bA bB 50257 A B 4
      (cell L) (bytes ω L K A B) k m₀ (S L m n) W)
    (hI : Inv o (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) j W) (hp : W.prods (idx "48") = none) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧
      (round W).prods (idx "48") = none ∧
      (round W).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (j + 1))) ∧
      ∃ x v, W.regs (idx "48") = some x ∧ (round W).regs (idx "48") = some v ∧
        (floatBin .float .fmul { contract := true }
            (.ofFloat .float (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j].1)
            (.ofFloat .float (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j].2) none none
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 12) 0)) >>= fun p =>
          floatBin .float .fadd { contract := true } x p none
            (some (.ofFloat .float (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j].1,
              .ofFloat .float (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j].2))
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 13) 0))) = .ok v := by
  have hK := hAt.dims.2.1
  have hlen : (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length = K := by
    simp only [pairs, List.length_take, List.length_ofFn]
    omega
  have hi : j < max K 0 := by omega
  have hP : W.ctx.prog = naive.prog := by rw [hc]; exact hAt.ctx.1
  obtain ⟨h16, h26, h11, h37, h12, -⟩ :=
    NaiveSound.naive.kept hAt.valid (dims_lt hAt.dims) hS hAt.entry j hW
  obl_have g47 : (round W).regs (idx "47"), e48 : (round W).regs (idx "48"),
    hm : (round W).mem
  have hctx (c l S) (V : Valuation) : (V.intoWith c l S).ctx = V.ctx :=
    (Valuation.intoWith_k _ _ _ _).1
  simp only [hctx] at e48
  have ea : (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j] =
      (A.get2 ⟨_, hS.2.1⟩ ⟨j, by omega⟩, B.get2 ⟨_, hS.2.2⟩ ⟨j, by omega⟩) := by
    simp only [pairs, List.getElem_take, List.getElem_ofFn]
  have e48' : (round W).regs (idx "48") = some (.ofFloat .float (dotStep true
      (dotLoop true o (Model.zero _ false) ((pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).take j))
      (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)[j]
      (W.ctx.oracle (Nat.pair ((latchAt W).k + 12) 0),
        W.ctx.oracle (Nat.pair ((latchAt W).k + 13) 0)))) := by
    rw [ea, Tensor.get2_eq_apply, Tensor.get2_eq_apply]
    exact e48
  refine ⟨OblMatmul.naive_rounds K m n _ _ bA bB j
      (dotLoop true o (Model.zero _ false) ((pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).take j)).toBits
      A B W hK hAt.dims.2.2.2.1 hAt.dims.2.2.2.2 hS.2.1 hS.2.2 hi hP hF.func hI.1 h16 hI.2 h26
      h37 h11 h12 hF.bufA.1 hF.bufB.1 hF.bufA.2.1 hF.bufB.2.1 hF.bufA.2.2 hF.bufB.2.2, ?_, g47, _,
      _, hI.2, e48', floatBin_dotStep rfl rfl rfl _ _ _ _ _⟩
  mojo_inv

/-- **The path out of the loop**, for every thread in bounds at which `At` holds with the oracle
`ω k`, and the head `W` of the round after all of `pairs` with `At`'s context at which
`Mat.Head` holds and `Inv` holds after all of `pairs`: the path `%46 → %51 → %67 → %69` walks
(`OblMatmul.naive_exit`, with `%16` and `%40` by `NaiveSound.naive.kept`, `%40`'s value at the
loop head by mojo_inv) and returns, and its memory meets
`Elem` after `k + 1` threads and `Elem.Only`: `%67`'s store puts the encoding of the accumulator
`%48`, `dotLoop` over all of `pairs` (`NaiveSpec.bytes`), at the thread's cell (mojo_inv, by
`Elem.apply_store` and `Elem.Only.apply`, from that encoding). -/
theorem exit_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) (hω : c.oracle = ω k)
    {W : Valuation}
    (hW : W = NaiveThread.round^[(pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length]
      (head (Valuation.entry c 0 m' f))) (hc : W.ctx = c)
    (hF : Mat.Head naive.prog naive.fn_0 (.fp .float) (Val.ofFloat .float) 4 bC bA bB 50257 A B 4
      (cell L) (bytes ω L K A B) k m₀ (S L m n) W)
    (hI : Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)
      (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length W) :
    RetWith true W
      (fun me => Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me)
      ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X) := by
  have h48 := hI.2
  rw [List.take_length] at h48
  have hlen : (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length = K := by
    have := hAt.dims.2.1
    simp only [pairs, List.length_take, List.length_ofFn]
    omega
  have hP : W.ctx.prog = naive.prog := by rw [hc]; exact hAt.ctx.1
  have h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (max K 0))) := by
    rw [Nat.max_zero, ← hlen]
    exact hI.1
  have hy : L.index k .y < 50257 := by have := hS.2.2; have := hAt.dims.1; omega
  obtain ⟨h16, -, -, -, -, h40⟩ :=
    NaiveSound.naive.kept hAt.valid (dims_lt hAt.dims) hS hAt.entry _ hW
  replace h40 : W.regs (idx "40") = some (.ptr ⟨bC,
      ((L.index k .x * 50257 + L.index k .y) * naive.prog.layout.size (.fp .float) : Nat)⟩) := by
    refine h40.trans ?_
    have ⟨_, hx0, hy0⟩ := hS
    unfold Launch.index at hx0 hy0
    mojo_inv
  have hw := OblMatmul.naive_exit K m _ _ bC
    (dotLoop true (oN c 0) (Model.zero _ false) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)).toBits
    W hAt.dims.2.1 hS.2.1 hy hP hF.func h47 h16 h48 h40 hF.bufC.1 hF.bufC.2
  have hd : (Cond.mem fin.effs).Holds (out7 W) (vals (out7 W) fin.nodes) :=
    hw.2.2.2.2.1 _ (by decide +kernel)
  obtain ⟨me, hme⟩ := hd
  have ho : oN c 0 = o (ω k) := funext fun i => by simp only [oN, o, hω, Nat.zero_add]
  have he : naive.prog.layout.encode (.fp .float) (.ofFloat .float
      (dotLoop true (oN c 0) (Model.zero _ false) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K))) =
        bytes ω L K A B k := by
    rw [bytes, dite_eq_left hS, ho]
  have hfm : ((out7 W).intoWith true naive.fn_0.b_7.label fin).mem = me := by
    rw [Valuation.intoWith_mem]
    show (SEff.run (out7 W) (vals (out7 W) fin.nodes) fin.effs).toOption.getD (out7 W).mem = me
    rw [hme]
    rfl
  have hrun : SEff.run ((out7 W).intoWith true naive.fn_0.b_7.label fin)
      (vals ((out7 W).intoWith true naive.fn_0.b_7.label fin) Kernels.vadd.b3.nodes)
      Kernels.vadd.b3.effs = .ok me := by
    rw [show Kernels.vadd.b3.effs = [] by decide +kernel, ← hfm]
    rfl
  refine ⟨hw, ?_, me, hrun, ?_⟩
  · kernel_rfl
  · mojo_inv

/-! ## The theorem -/

/-- **`RunIn` for the naive kernel**, for every oracle family `ω`, launch `L`, dimensions `m`, `n`,
`K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B` (all admitted launches and inputs of this one
program, `naive`, not one example): every thread `k` in bounds, from `At` with the oracle `ω k`
and a memory of `Elem` after `k` threads with `Elem.Only`, runs `chainN` to `ret` with a memory
of `Elem` after `k + 1` threads with `Elem.Only` (`NaiveSound.naive.runInv`, the run that the
`mat … inv` clause generates, at the invariant `NaiveThread.Inv` with `%48`'s `fmul contract`
operands none, and at `head_in`, `round_in` with `NaiveThread.round_inv`, and `exit_in`). -/
theorem runIn (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) : RunIn ω L K bC bA bB A B := by
  intro k _ _ _ c m₀ _ _ hS hω hAt hE hO
  exact NaiveSound.naive.runInv hAt.valid (dims_lt hAt.dims) hS hAt.entry hAt.ne hE hO
    (I := fun j W => Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) j W ∧
      W.prods (idx "48") = none)
    ⟨head_in hAt _, fun _ hj hc hk hF ⟨hI, hp⟩ =>
      round_inv (G := fun W => W.prods (idx "48") = none) hc hI hj hk
        (round_in hS hAt hj rfl hc hF hI hp), fun hc _ hF ⟨hI, _⟩ =>
      exit_in hS hAt hω rfl hc hF hI⟩

end MojoProofTest.NaiveIn
