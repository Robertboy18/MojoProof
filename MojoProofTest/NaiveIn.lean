import MojoProofTest.NaiveSpec
import MojoProofTest.OblMatmul

/-!
# A naive thread in bounds, for every launch

`runIn` proves `NaiveSpec.RunIn ω L K bC bA bB A B` for one program, the naive matmul kernel
`naive` (MojoProofTest/SymPhi.lean, with `fmul contract`), and every oracle family `ω`, launch
`L`, dimensions `m`, `n`, `K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B`: every thread of it
that is in bounds, from `NaiveSpec.At` and a memory of `Elem` after `k` threads with
`Elem.Only`, runs `NaiveThread.chainN` to `ret` with a memory of `Elem` after `k + 1` threads (its
cell holds `NaiveSpec.bytes`) with `Elem.Only`. It is `NaiveThread.thread_run` with the predicate
`Head` on the loop heads, and its four premises are four theorems:

* `entry_in`: the entry block's obligations and its branch to `%45` (`OblMatmul.naive_entry`);
* `head_in`: the invariant at round 0 and `Head` at the loop head after `%6 → %45`;
* `round_in`: a round's premises (`OblMatmul.naive_rounds`), `Head` after it, the counter and the
  accumulator's `fadd` after it;
* `exit_in`: the path out `%46 → %51 → %67 → %69` returns with the postcondition of `RunIn`
  (`OblMatmul.naive_exit`, `Elem.apply_store`, `Elem.Only.apply`).

The tactic `obl_have` (MojoProof/Sym/Obl.lean) names values that `mojo_obl`'s evaluator computes
from the hypotheses `At`, `Head` and `Inv` and their parts: registers, memories and node values,
several in one run.
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

/-- A result that reads as the binary32 scalar `x` is it. -/
private theorem ok_of_float {e : Except Fault Val} {x : Model FloatTy.float.fmt}
    (h : e.toOption.map (·.float? .float) = some (some x)) : e = .ok (.ofFloat .float x) := by
  cases e with
  | error => cases h
  | ok v => exact congrArg Except.ok (Val.float?_eq_some.1 (Option.some.inj h))

/-- Logging a read of a block other than `out` keeps `Elem` and `Elem.Only`. -/
private theorem keep_log {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {T : Nat → Prop} {m : Mem} {a : Access}
    (h : Elem m₀ out w cell bs k m ∧ Elem.Only out T m) (hq : a.ptr.block ≠ out)
    (hw : a.write = false) :
    Elem m₀ out w cell bs k (m.log (.access a)) ∧ Elem.Only out T (m.log (.access a)) :=
  ⟨h.1.log ⟨fun e => absurd e hq, fun _ => hw, fun _ => hq⟩, h.2.log fun e => absurd e hq⟩

/-- Operands with values have as many values as operands. -/
private theorem evalOps_length {s : Scope} :
    ∀ {ops : List (Option Nat × Ty × Value)} {xs : List Val}, evalOps s ops = .ok xs →
      xs.length = ops.length
  | [], xs, h => by
    simp only [evalOps, Except.ok.injEq] at h
    subst h
    rfl
  | (_, t, v) :: ops, xs, h => by
    unfold evalOps at h
    split at h
    · rename_i x xs' _ hxs
      simp only [Except.ok.injEq] at h
      subst h
      simp only [List.length_cons, evalOps_length hxs]
    · cases h
    · cases h

/-- Setting the results of `sts` (as `enter` does) leaves no `fmul contract` operands at a
register that had none or that one of them sets. -/
private theorem fold_prods (r : Nat) : ∀ (sts : List Stmt) (xs : List Val) (f : Frame),
    xs.length = sts.length → (f.prods r = none ∨ some r ∈ sts.map (·.res)) →
    ((sts.zip xs).foldl (fun f (st, v) => f.set st.res (some v) none) f).prods r = none
  | [], _, f, _, h => by simpa using h
  | _ :: _, [], _, hl, _ => by simp at hl
  | st :: sts, x :: xs, f, hl, h => by
    rw [List.zip_cons_cons, List.foldl_cons]
    refine fold_prods r sts xs _ (by simpa using hl) ?_
    show (f.set st.res (some x) none).prods r = none ∨ some r ∈ sts.map (·.res)
    cases hs : st.res with
    | none =>
      simp only [List.map_cons, hs, List.mem_cons, reduceCtorEq, false_or] at h
      exact h
    | some s =>
      simp only [List.map_cons, hs, List.mem_cons, Option.some.injEq] at h
      by_cases e : r = s
      · exact .inl (by simp [Frame.set, e])
      · rcases h with h | h | h
        · exact .inl (by simp [Frame.set, e, h])
        · exact absurd h e
        · exact .inr h

/-- `enter` through `phi`s with operands `ops` and values `xs` succeeds and leaves no
`fmul contract` operands at the `phi`s' registers. -/
private theorem enter_prods {s : Scope} {f : Frame} {d : Nat}
    {ops : List (Option Nat × Ty × Value)} {xs : List Val}
    (hops : phiOps f.fn f.label d = some ops) (hxs : evalOps s ops = .ok xs) :
    ∃ f', enter s f d = .ok f' ∧ ∀ r, some r ∈ ops.map (·.1) → f'.prods r = none := by
  unfold phiOps at hops
  split at hops
  · rename_i b hb
    obtain ⟨hm, hr⟩ := mapM_phiVal hops hxs
    rw [enter_of_find hb, hm]
    have hl := congrArg List.length hr
    simp only [List.length_map] at hl
    exact ⟨_, rfl, fun r h =>
      fold_prods r _ xs f ((evalOps_length hxs).trans hl) (.inr (hr ▸ h))⟩
  · cases hops

/-- `Valuation.intoWith_regs_phi` for the `fmul contract` operands: after an edge into `phi`s,
the `phi`s' registers have none. -/
private theorem prods_phi {c : Bool} {V : Valuation} {l : Nat} {S : Summary} {x : SVal}
    {a b d : Nat} {F : Func} {ops : List (Option Nat × Ty × Value)} {xs : List Val}
    (hx : S.exit = .phi x a b) (hd : S.exit.dest V (vals V S.nodes) = some d) (hF : V.fn = F)
    (hops : phiOps F l d = some ops)
    (hxs : evalOps (V.ctx.scope (V.afterWith c S).mem (V.frameAtWith c l S) (V.k + S.len)) ops =
      .ok xs) {r : Nat} (hr : some r ∈ ops.map (·.1)) : (V.intoWith c l S).prods r = none := by
  have hops' : phiOps (V.frameAtWith c l S).fn (V.frameAtWith c l S).label d = some ops := by
    simp only [Valuation.frameAtWith]; rw [hF]; exact hops
  obtain ⟨f', he, hp⟩ := enter_prods hops' hxs
  have : V.intoWith c l S = { V.afterWith c S with regs := f'.regs, prods := f'.prods } := by
    rw [Valuation.intoWith, hd]; simp only [hx, he]
  rw [this]
  exact hp r hr

/-- After an edge with no `phi`s with `fmul contract`, a register the block does not set keeps
its `fmul contract` operands. -/
private theorem prods_keep {V : Valuation} {l : Nat} {S : Summary} {r : Nat}
    (hx : (match S.exit with | .phi .. => true | _ => false) = false)
    (hr : S.regs.lookup r = none) : (V.intoWith true l S).prods r = V.prods r := by
  have e : V.intoWith true l S = V.afterWith true S := by
    unfold Valuation.intoWith
    cases h : S.exit with
    | phi => rw [h] at hx; cases hx
    | _ => rfl
  rw [e]
  show regProdIn V (vals V S.nodes) S.nodes S.regs r = V.prods r
  simp only [regProdIn, hr]

/-- The pairs of a cell are `K` many, for `K ≤ 768`. -/
private theorem pairs_length {m n : Nat} {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {r : Fin m} {c : Fin n} {K : Nat}
    (hK : K ≤ 768) : (pairs A B r c K).length = K := by
  simp only [pairs, List.length_take, List.length_ofFn]
  omega

/-- A block with no memory effects keeps the memory at the edge out of it. -/
private theorem mem_nil {c : Bool} {V : Valuation} {l : Nat} {S : Summary} (h : S.effs = []) :
    (V.intoWith c l S).mem = V.mem := by
  rw [Valuation.intoWith_mem]
  show (SEff.run V (vals V S.nodes) S.effs).toOption.getD V.mem = V.mem
  rw [h]
  rfl

/-- The registers of the scope of the edge out of `S` are those after `S`. -/
private theorem scope_regs (c : Bool) (V : Valuation) (l : Nat) (S : Summary) (m : Mem)
    (k r : Nat) : (V.ctx.scope m (V.frameAtWith c l S) k).regs r = (V.after S).regs r := rfl

/-- `lanes2` on two binary32 scalars is its function at lane 0. -/
private theorem lanes2_ofFloat (F : Nat → Val → Val → Except Fault Val)
    (x y : Model FloatTy.float.fmt) :
    lanes2 F (.ofFloat .float x) (.ofFloat .float y) =
      F 0 (.ofFloat .float x) (.ofFloat .float y) :=
  rfl

/-- The valuation after the entry block `%6` of a thread with context `c`, memory `m'` and frame
`f`. -/
private def post (c : Ctx) (m' : Mem) (f : Frame) : Valuation :=
  (Valuation.entry c 0 m' f).intoWith true naive.fn_0.b_0.label SymSelect.entry

/-- The entry valuation of the latch `%52` in the round from `W` (`NaiveThread.latchAt`). -/
private def lat (W : Valuation) : Valuation :=
  (W.intoWith true naive.fn_0.b_3.label hdr).intoWith true naive.fn_0.b_4.label body

/-- The entry valuation of `%67` on the path out from `W`. -/
private def out7 (W : Valuation) : Valuation :=
  (W.intoWith true naive.fn_0.b_3.label hdr).intoWith true naive.fn_0.b_5.label out

/-! ## The loop heads -/

/-- **The facts at a loop head** of thread `k` (in bounds) of launch `L` of the naive kernel on
the buffers `bC`, `bA`, `bB` holding `A` and `B`, under the oracles `ω`, with memory `m₀` before
the threads: the function is `naive`'s; `%11` and `%12` point at `bA` and `bB`, `%16` is
`smax(K, 0)`, `%26` and `%37` are the thread's row and column times 768, `%40` points at its cell
of `C`, and `%48` carries no `fmul contract` operands; on the memory, `bA` and `bB` are the
read-only buffers holding `A` and `B`, `bC` is the writable buffer, and `Elem` after `k` threads
and `Elem.Only` hold. -/
structure Head (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) (k : Nat) (m₀ : Mem)
    (W : Valuation) : Prop where
  /-- Builds `Head` from its fields. -/
  mk ::
  /-- The function is `naive`'s. -/
  fn : W.fn = naive.fn_0
  /-- `%11` points at `bA`. -/
  r11 : W.regs (idx "11") = some (.ptr ⟨bA, 0⟩)
  /-- `%12` points at `bB`. -/
  r12 : W.regs (idx "12") = some (.ptr ⟨bB, 0⟩)
  /-- `%16` is `smax(K, 0)`. -/
  r16 : W.regs (idx "16") = some (.bits 64 (BitVec.ofNat 64 (max K 0)))
  /-- `%26` is the row times 768. -/
  r26 : W.regs (idx "26") = some (.bits 32 (BitVec.ofNat 32 (L.index k .x * 768)))
  /-- `%37` is the column times 768. -/
  r37 : W.regs (idx "37") = some (.bits 32 (BitVec.ofNat 32 (L.index k .y * 768)))
  /-- `%40` points at the thread's cell of `C`. -/
  r40 : W.regs (idx "40") = some (.ptr ⟨bC,
    ((L.index k .x * 50257 + L.index k .y) * naive.prog.layout.size (.fp .float) : Nat)⟩)
  /-- `%48` carries no `fmul contract` operands. -/
  p48 : W.prods (idx "48") = none
  /-- `bA` is the read-only buffer holding `A`. -/
  bufA : W.mem.Buffer bA (m * 768 * 4) 4 false ∧ W.mem.Fits naive.prog.layout bA (m * 768 * 4) ∧
    W.mem.Holds naive.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) A
  /-- `bB` is the read-only buffer holding `B`. -/
  bufB : W.mem.Buffer bB (n * 768 * 4) 4 false ∧ W.mem.Fits naive.prog.layout bB (n * 768 * 4) ∧
    W.mem.Holds naive.prog.layout bB (.fp .float) (Val.ofFloat .float)
      (rowMajor naive.prog.layout (.fp .float) 0) B
  /-- `bC` is the writable buffer. -/
  bufC : W.mem.Buffer bC (m * 50257 * 4) 4 true ∧ W.mem.Fits naive.prog.layout bC (m * 50257 * 4)
  /-- The memory meets `Elem` after `k` threads. -/
  elem : Elem m₀ bC 4 (cell L) (bytes ω L K A B) k W.mem
  /-- Every access to `bC` is by a thread in bounds. -/
  only : Elem.Only bC (S L m n) W.mem

/-! ## The four premises of `NaiveThread.thread_run` -/

/-- **The entry block**, for every thread in bounds at which `At` holds: the obligations of
`%6` hold at the entry valuation and its branch goes to `%45` (`OblMatmul.naive_entry`). -/
theorem entry_in {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) :
    (∀ d ∈ SymSelect.entry.obls,
      d.Holds (Valuation.entry c 0 m' f) (vals (Valuation.entry c 0 m' f) SymSelect.entry.nodes)) ∧
      SymSelect.entry.exit.dest (Valuation.entry c 0 m' f)
        (vals (Valuation.entry c 0 m' f) SymSelect.entry.nodes) = some naive.fn_0.b_2.label := by
  have e := OblMatmul.naive_entry L hAt.valid k c hAt.ctx.1 hAt.ctx.2.1 0 m' f hAt.fn K m n p0 p1
    p2 bA bB bC hAt.dims.2.1 hAt.dims.2.2.1 hAt.dims.1 hAt.ptrs.1 hAt.ptrs.2.1 hAt.ptrs.2.2.1
    hAt.scalars.1 hAt.scalars.2.1 hAt.scalars.2.2 hAt.loads.1 hAt.loads.2.1 hAt.loads.2.2
    hAt.bufC.1 hAt.bufC.2 hS.2.1 hS.2.2
  exact ⟨e.1.1, e.1.2.1⟩

/-- **The loop head after `%6 → %45`**, for every thread in bounds at which `At` holds, whose
memory meets `Elem` after `k` threads and `Elem.Only`, and every list of pairs: the invariant
holds at round 0 (`%47 = 0` and `%48 = +0`, the `phi`s at the edge `%45 → %46`, an integer and a
float constant) and `Head` holds (the registers after the edge by one `obl_have`; the memory is
the entry block's three loads of the structs, at blocks other than `bC`). -/
theorem head_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f)
    (hE : Elem m₀ bC 4 (cell L) (bytes ω L K A B) k m') (hO : Elem.Only bC (S L m n) m')
    (ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32)) :
    Inv (oN c 0) ps 0 (head (Valuation.entry c 0 m' f)) ∧
      Head ω L K bC bA bB A B k m₀ (head (Valuation.entry c 0 m' f)) := by
  have hx := hS.2.1
  have hy := hS.2.2
  unfold Launch.index at hx hy
  have hH : head (Valuation.entry c 0 m' f) =
      (post c m' f).intoWith true naive.fn_0.b_2.label pre := rfl
  have hF : (post c m' f).fn = naive.fn_0 := (Valuation.intoWith_k true _ _ _).2.1.trans hAt.fn
  have hpx : pre.exit = .phi (.int 1 1) naive.fn_0.b_3.label naive.fn_0.b_3.label := by
    decide +kernel
  have hpd : pre.exit.dest (post c m' f) (vals (post c m' f) pre.nodes) =
      some naive.fn_0.b_3.label := by
    rw [hpx]; rfl
  have hops : phiOps naive.fn_0 naive.fn_0.b_2.label naive.fn_0.b_3.label =
      some [(some (idx "47"), .int 64, .int 0),
        (some (idx "48"), .fp .float, .float (.dec false "0" "000000" 0))] := by
    kernel_rfl
  have hz : ∀ s, evalV s (.fp .float) (.float (.dec false "0" "000000" 0)) =
      .ok (.ofFloat .float (Model.zero _ false)) := fun s => by
    simp only [evalV]
    exact ok_of_float (by decide +kernel)
  obl_have g47 : (head (Valuation.entry c 0 m' f)).regs (idx "47"),
    g48 : (head (Valuation.entry c 0 m' f)).regs (idx "48"),
    h11 : (head (Valuation.entry c 0 m' f)).regs (idx "11"),
    h12 : (head (Valuation.entry c 0 m' f)).regs (idx "12"),
    h16 : (head (Valuation.entry c 0 m' f)).regs (idx "16"),
    h26 : (head (Valuation.entry c 0 m' f)).regs (idx "26"),
    h37 : (head (Valuation.entry c 0 m' f)).regs (idx "37"),
    h40 : (head (Valuation.entry c 0 m' f)).regs (idx "40"),
    hM : (head (Valuation.entry c 0 m' f)).mem
  have hmem : Elem m₀ bC 4 (cell L) (bytes ω L K A B) k (head (Valuation.entry c 0 m' f)).mem ∧
      Elem.Only bC (S L m n) (head (Valuation.entry c 0 m' f)).mem := by
    rw [hM]
    exact keep_log (keep_log (keep_log ⟨hE, hO⟩ hAt.ptrs.2.2.2.2.2 rfl) hAt.ptrs.2.2.2.2.1 rfl)
      hAt.ptrs.2.2.2.1 rfl
  have hb : ∀ q x, m'.blocks q = some x →
      (head (Valuation.entry c 0 m' f)).mem.blocks q = some x := by
    intro q x h
    rw [hM]
    exact h
  refine ⟨⟨g47, g48.trans (by kernel_rfl)⟩, ⟨(Valuation.intoWith_k true _ _ _).2.1.trans hF, h11,
    h12, h16, h26, h37, h40, ?_,
    ⟨hAt.bufA.1.of_block (hb _), hAt.bufA.2.1.of_block (hb _), hAt.bufA.2.2.of_block (hb _)⟩,
    ⟨hAt.bufB.1.of_block (hb _), hAt.bufB.2.1.of_block (hb _), hAt.bufB.2.2.of_block (hb _)⟩,
    ⟨hAt.bufC.1.of_block (hb _), hAt.bufC.2.of_block (hb _)⟩, hmem.1, hmem.2⟩⟩
  rw [hH]
  exact prods_phi (c := true) hpx hpd hF hops
    (evalOps_cons (evalV_int_ofNat _ 64 0) (evalOps_cons (hz _) (evalOps_nil _)))
    (by decide +kernel)

/-- **The accumulator after a round**, for every valuation `W` of `naive`'s function whose latch
`%52` (entered at `lat W`) has `%48` the binary32 scalar `x` with no `fmul contract` operands,
loads `a` and `b` (nodes 7 and 11 of `SymContract.latch`) and sets `%55`: after the round `%48`
is `dotStep true x (a, b)` under the oracle numbers of the latch's statements 12 (`fmul`) and 13
(`fadd`), with no `fmul contract` operands (the latch's nodes by `SNode.eval_fbin_ofFloat` and
`SNode.eval_fbinP`, then the `phi`s at the edge `%52 → %46`, `Valuation.intoWith_regs_phi`). -/
private theorem acc_round {W : Valuation} {x a b : Model FloatTy.float.fmt} {v55 : Val}
    (hfn : W.fn = naive.fn_0) (hl : (lat W).regs (idx "48") = some (.ofFloat .float x))
    (hp : (lat W).prods (idx "48") = none)
    (n7 : (vals (lat W) SymContract.latch.nodes)[7]? = some (.ok (.ofFloat .float a)))
    (n11 : (vals (lat W) SymContract.latch.nodes)[11]? = some (.ok (.ofFloat .float b)))
    (h55 : ((lat W).after SymContract.latch).regs (idx "55") = some v55) :
    (round W).regs (idx "48") = some (.ofFloat .float (dotStep true x (a, b)
      ((lat W).ctx.oracle (Nat.pair ((lat W).k + 12) 0),
        (lat W).ctx.oracle (Nat.pair ((lat W).k + 13) 0)))) ∧
      (round W).prods (idx "48") = none := by
  obtain ⟨-, h12, h66, h13, -, -, -, hx⟩ := SymContract.latch_nodes
  have v12 := vals_getElem?_eval h12 (SNode.eval_fbin_ofFloat (f := fun x y => Model.mul x y)
    (SVal.eval_node_take (by decide) n7) (SVal.eval_node_take (by decide) n11) rfl rfl rfl rfl
    rfl rfl)
  have q1 : laneOf ((SVal.reg (idx "48")).prodsWith (lat W)
      (vals (lat W) (SymContract.latch.nodes.take 13)) none) 0 = none := by
    show Option.map _ ((lat W).prods (idx "48")) = none
    rw [hp]
    rfl
  have q2 : laneOf ((SVal.node 12).prodsWith (lat W)
      (vals (lat W) (SymContract.latch.nodes.take 13)) (some (.node 7, .node 11))) 0 =
        some (.ofFloat .float a, .ofFloat .float b) := by
    show Option.map _ (prodVal (lat W) _ (.node 7, .node 11)) = _
    simp only [prodVal, SVal.eval_node_take (j := 13) (by decide) n7,
      SVal.eval_node_take (j := 13) (by decide) n11]
    rfl
  have v13 : (vals (lat W) SymContract.latch.nodes)[13]? = some (.ok (.ofFloat .float
      (dotStep true x (a, b) ((lat W).ctx.oracle (Nat.pair ((lat W).k + 12) 0),
        (lat W).ctx.oracle (Nat.pair ((lat W).k + 13) 0))))) := by
    refine vals_getElem?_eval h13 (SNode.eval_fbinP (SVal.eval_reg hl)
      (SVal.eval_node_take (by decide) v12) ?_)
    rw [lanes2_ofFloat]
    have hd := floatBin_dotStep (t := .float) (fm := { contract := true }) rfl rfl rfl x a b
      ((lat W).ctx.oracle (Nat.pair ((lat W).k + 12) 0))
      ((lat W).ctx.oracle (Nat.pair ((lat W).k + 13) 0))
    rw [floatBin_ofFloat (f := fun x y => Model.mul x y) rfl rfl rfl rfl] at hd
    rw [q1, q2]
    exact hd
  have hF : (lat W).fn = naive.fn_0 :=
    ((Valuation.intoWith_k _ _ _ _).2.1.trans (Valuation.intoWith_k _ _ _ _).2.1).trans hfn
  have hd : SymContract.latch.exit.dest (lat W) (vals (lat W) SymContract.latch.nodes) =
      some naive.fn_0.b_3.label := by
    rw [hx]; rfl
  have hops : phiOps naive.fn_0 naive.fn_0.b_6.label naive.fn_0.b_3.label =
      some [(some (idx "47"), .int 64, .loc (idx "55")),
        (some (idx "48"), .fp .float, .loc (idx "66"))] := by
    kernel_rfl
  have h66v := Valuation.after_regs_some h66 (SVal.eval_node v13)
  have hr : round W = (lat W).intoWith true naive.fn_0.b_6.label SymContract.latch := rfl
  rw [hr]
  refine ⟨?_, prods_phi (c := true) hx hd hF hops
    (evalOps_cons (evalV_loc ((scope_regs _ _ _ _ _ _ _).trans h55))
      (evalOps_cons (evalV_loc ((scope_regs _ _ _ _ _ _ _).trans h66v)) (evalOps_nil _)))
    (by decide +kernel)⟩
  rw [Valuation.intoWith_regs_phi (c := true) hx hd hF hops
    (evalOps_cons (evalV_loc ((scope_regs _ _ _ _ _ _ _).trans h55))
      (evalOps_cons (evalV_loc ((scope_regs _ _ _ _ _ _ _).trans h66v)) (evalOps_nil _)))]
  rfl

/-- **A round of the loop**, for every thread in bounds at which `At` holds, all oracle numbers
`o`, every round `j` below the trip count and every head valuation `W` with `At`'s context at
which `Inv` and `Head` hold: the premises of the round hold (`OblMatmul.naive_rounds`), `Head`
holds after it, the counter after it is `j + 1`, and the accumulator after it is the `fadd` of the
accumulator before it and the `fmul` of pair `j` of `pairs`, under the oracle numbers of the
latch's statements 12 and 13 (`acc_round`). One `obl_have` gives the registers and the memory
after the round (its two loads, at `bA` and `bB`, blocks other than `bC`) and the latch's values
the accumulator's step reads. -/
theorem round_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) {o : Nat → Nat × Nat}
    {j : Nat} (hj : j < (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length) {W : Valuation}
    (hc : W.ctx = c) (hI : Inv o (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K) j W)
    (hG : Head ω L K bC bA bB A B k m₀ W) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧
      Head ω L K bC bA bB A B k m₀ (round W) ∧
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
  have hlen := pairs_length (A := A) (B := B) (r := ⟨_, hS.2.1⟩) (c := ⟨_, hS.2.2⟩) hK
  have hi : j < max K 0 := by omega
  have hP : W.ctx.prog = naive.prog := by rw [hc]; exact hAt.ctx.1
  obl_have g11 : (round W).regs (idx "11"), g12 : (round W).regs (idx "12"),
    g16 : (round W).regs (idx "16"), g26 : (round W).regs (idx "26"),
    g37 : (round W).regs (idx "37"), g40 : (round W).regs (idx "40"),
    g47 : (round W).regs (idx "47"), hM : (round W).mem, hl : (lat W).regs (idx "48"),
    h55 : ((lat W).after SymContract.latch).regs (idx "55"),
    n7 : (vals (lat W) SymContract.latch.nodes)[7]?,
    n11 : (vals (lat W) SymContract.latch.nodes)[11]?
  have hb : ∀ q x, W.mem.blocks q = some x → (round W).mem.blocks q = some x := by
    intro q x h
    rw [hM]
    exact h
  have hmem : Elem m₀ bC 4 (cell L) (bytes ω L K A B) k (round W).mem ∧
      Elem.Only bC (S L m n) (round W).mem := by
    rw [hM]
    exact keep_log (keep_log ⟨hG.elem, hG.only⟩ hAt.ne.1 rfl) hAt.ne.2 rfl
  have hp : (lat W).prods (idx "48") = none :=
    (prods_keep (by decide +kernel) (by decide +kernel)).trans
      ((prods_keep (by decide +kernel) (by decide +kernel)).trans hG.p48)
  obtain ⟨e48, q48⟩ := acc_round hG.fn hl hp n7 n11 h55
  have hctx : (lat W).ctx = W.ctx :=
    (Valuation.intoWith_k _ _ _ _).1.trans (Valuation.intoWith_k _ _ _ _).1
  rw [hctx] at e48
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
      A B W hK hAt.dims.2.2.2.1 hAt.dims.2.2.2.2 hS.2.1 hS.2.2 hi hP hG.fn hI.1 hG.r16
      hI.2 hG.r26 hG.r37 hG.r11 hG.r12 hG.bufA.1 hG.bufB.1 hG.bufA.2.1 hG.bufB.2.1 hG.bufA.2.2
      hG.bufB.2.2,
    ⟨(steps W W 1).2.2.2.2.1.trans hG.fn, g11, g12, g16, g26, g37, g40, q48,
      ⟨hG.bufA.1.of_block (hb _), hG.bufA.2.1.of_block (hb _), hG.bufA.2.2.of_block (hb _)⟩,
      ⟨hG.bufB.1.of_block (hb _), hG.bufB.2.1.of_block (hb _), hG.bufB.2.2.of_block (hb _)⟩,
      ⟨hG.bufC.1.of_block (hb _), hG.bufC.2.of_block (hb _)⟩, hmem.1, hmem.2⟩, g47, _, _, hI.2,
    e48', floatBin_dotStep rfl rfl rfl _ _ _ _ _⟩

/-- **The path out of the loop**, for every thread in bounds at which `At` holds with the oracle
`ω k`, and every head valuation `W` with `At`'s context at which `Inv` holds after all of
`pairs` and `Head` holds: the path `%46 → %51 → %67 → %69` walks (`OblMatmul.naive_exit`) and
returns, and its memory meets `Elem` after `k + 1` threads and `Elem.Only`: `%67`'s store puts
the encoding of the accumulator `%48`, `dotLoop` over all of `pairs` (`NaiveSpec.bytes`), at the
thread's cell (`Elem.apply_store`, `Elem.Only.apply`). -/
theorem exit_in {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' : Mem} {f : Frame}
    (hS : S L m n k) (hAt : At L K bC bA bB p0 p1 p2 A B k c m' f) (hω : c.oracle = ω k)
    {W : Valuation} (hc : W.ctx = c)
    (hI : Inv (oN c 0) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)
      (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K).length W)
    (hG : Head ω L K bC bA bB A B k m₀ W) :
    RetWith true W
      (fun me => Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me)
      ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X) := by
  have h48 := hI.2
  rw [List.take_length] at h48
  have hlen := pairs_length (A := A) (B := B) (r := ⟨_, hS.2.1⟩) (c := ⟨_, hS.2.2⟩) hAt.dims.2.1
  have hP : W.ctx.prog = naive.prog := by rw [hc]; exact hAt.ctx.1
  have h47 : W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (max K 0))) := by
    rw [Nat.max_zero, ← hlen]
    exact hI.1
  have hy : L.index k .y < 50257 := by have := hS.2.2; have := hAt.dims.1; omega
  have hw := OblMatmul.naive_exit K m _ _ bC
    (dotLoop true (oN c 0) (Model.zero _ false) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)).toBits
    W hAt.dims.2.1 hS.2.1 hy hP hG.fn h47 hG.r16 h48 hG.r40 hG.bufC.1 hG.bufC.2
  have hd : (Cond.mem fin.effs).Holds (out7 W) (vals (out7 W) fin.nodes) :=
    hw.2.2.2.2.1 _ (by decide +kernel)
  obtain ⟨me, hme⟩ := hd
  have hfe : fin.effs = [.store naive.fn_0.b_7.label 1 (.reg (idx "68")) (.reg (idx "40"))] := by
    decide +kernel
  have ha := hme
  simp only [SEff.run, hfe, List.foldlM_cons, List.foldlM_nil, bind_pure] at ha
  have hM : (out7 W).mem = W.mem :=
    (mem_nil (S := out) (by decide +kernel)).trans (mem_nil (S := hdr) (by decide +kernel))
  rw [hM] at ha
  have hctx : (out7 W).ctx = c :=
    ((Valuation.intoWith_k _ _ _ _).1.trans (Valuation.intoWith_k _ _ _ _).1).trans hc
  have hF : (out7 W).fn = naive.fn_0 :=
    ((Valuation.intoWith_k _ _ _ _).2.1.trans (Valuation.intoWith_k _ _ _ _).2.1).trans hG.fn
  have hth : (out7 W).ctx.who.thread = k := by rw [hctx, hAt.ctx.2.2]
  obl_have g68 : (out7 W).regs (idx "68"), g40 : (out7 W).regs (idx "40")
  have ho : oN c 0 = o (ω k) := funext fun i => by simp only [oN, o, hω, Nat.zero_add]
  have hx : (SVal.reg (idx "68")).eval (out7 W) (vals (out7 W) fin.nodes) = .ok (.ofFloat .float
      (dotLoop true (oN c 0) (Model.zero _ false) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K))) :=
    SVal.eval_reg g68
  have hp : (SVal.reg (idx "40")).eval (out7 W) (vals (out7 W) fin.nodes) =
      .ok (.ptr ⟨bC, cell L k⟩) :=
    SVal.eval_reg (g40.trans rfl)
  have he : (out7 W).ctx.prog.layout.encode (.fp .float) (.ofFloat .float
      (dotLoop true (oN c 0) (Model.zero _ false) (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K))) =
        bytes ω L K A B k := by
    rw [hctx, hAt.ctx.1, bytes, dite_eq_left hS, ho]
  have hl : (out7 W).ctx.prog.layout.stored (.fp .float) ≤ 4 := by
    rw [hctx, hAt.ctx.1]
    decide +kernel
  have hs : (out7 W).stmt naive.fn_0.b_7.label 1 = some ⟨none, .store false
      ⟨.fp .float, .loc (idx "68")⟩ ⟨.ptr 0, .loc (idx "40")⟩ (some 4), []⟩ :=
    Valuation.stmt_of_fn hF (by kernel_rfl)
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
  refine ⟨hw, ?_, me, hrun, Elem.apply_store hG.elem ha hs hth hx hp he hl,
    Elem.Only.apply hG.only (by rw [hth]; exact hS) ha⟩
  kernel_rfl

/-! ## The theorem -/

/-- **`RunIn` for the naive kernel**, for every oracle family `ω`, launch `L`, dimensions `m`, `n`,
`K`, buffers `bC`, `bA`, `bB` and matrices `A`, `B` (all admitted launches and inputs of this one
program, `naive`, not one example): every thread `k` in bounds, from `At` with the oracle `ω k`
and a memory of `Elem` after `k` threads with `Elem.Only`, runs `chainN` to `ret` with a memory
of `Elem` after `k + 1` threads with `Elem.Only` (`NaiveThread.thread_run` with `Head`, at
`entry_in`, `head_in`, `round_in` and `exit_in`). -/
theorem runIn (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) : RunIn ω L K bC bA bB A B := by
  intro k p0 p1 p2 c m₀ m' f hS hω hAt hE hO
  exact thread_run (G := Head ω L K bC bA bB A B k m₀) hAt.fn (pairs A B ⟨_, hS.2.1⟩ ⟨_, hS.2.2⟩ K)
    (entry_in hS hAt)
    (head_in hS hAt hE hO _) (fun _ hj _ hc _ hI hG => round_in hS hAt hj hc hI hG)
    (fun _ hc _ hI hG => exit_in hS hAt hω hc hI hG)

end MojoProofTest.NaiveIn
