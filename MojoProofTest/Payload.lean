import MojoProof.Sym.Payload
import MojoProof.Kernels.Vadd
import MojoProofTest.Sym
import MojoProofTest.SymPhi
import MojoProofTest.Labels

/-!
# Instances and twins of roles, obliviousness and agreement on block summaries

MojoProof/Sym/Payload.lean on `vector_addition` (corpus `vadd/`, `Kernels.vadd`) under the
labelling `vaddLab ["25", "27", "28"]` (MojoProofTest/Labels.lean: the two loaded floats and
their sum payload), with the summaries of its four blocks that `mojo_kernel` generates
(`Kernels.vadd.b0` to `Kernels.vadd.b3`, MojoProof/Kernels/Vadd.lean), each by `decide +kernel`
(one program):

* the roles of block `%21`'s table (`%22` trunc, `%23` sext, `%24` gep, `%25` load, `%26` gep,
  `%27` load, `%28` fadd, `%29` gep): the two loads and the `fadd` payload, the rest skeleton
  (`vadd21_roles`);
* every block's summary (`%4`, `%21`, `%30`, `%31`) is oblivious and agrees with the labelling
  (`vadd_oblivious`).

Twins (block `%21`):
* with the gep `%24` labelled payload too, the summary still agrees with the labelling, but the
  pointer of the load `%25` is payload, so it is not oblivious ((O1); `Labels.Ok`'s twin with the
  stored pointer payload, `vadd_twin`);
* with the sum `%28` labelled skeleton, the summary does not agree, as the `fadd` node is
  payload ((O2)); with no register payload, the same;
* with its exit replaced by a branch on the payload load `%25`, a `cond` or a `phi` exit (a
  branch into blocks with `phi`s), it is not oblivious (`exit_twins`).

The `phi` assignments of an edge (`Summary.agreesI`), on two programs, each by
`decide +kernel`:
* the edge `%51 → %67` of the naive matmul kernel (MojoProofTest/SymPhi.lean's `naive`, `out`
  and `fin`; `%67` starts with `%68 = phi float [%48, %51]` and stores `%68`): with the
  accumulator `%48` and `%68` payload, `%51`'s summary agrees on the edge and `%67`'s is oblivious
  and agrees (`phi_agrees`). The twin, with `%68` skeleton: the checks without the edge
  (`Summary.agrees`, `Summary.oblivious`) pass on both blocks although `%68` receives the payload
  `%48`, and `Summary.agreesI` refuses the edge (`phi_twin`);
* a load fed to a `phi` (`phiFn`: `%p = load` in `entry`, `next` starts with `%q = phi [%p,
  %entry]` and branches on `icmp eq %q, 0`), with `%p` payload: both blocks' summaries are
  oblivious and agree, `agreesI` refuses the edge `entry → next`, and so does `Labels.Ok`
  (the `phi` with a skeleton result has a payload operand); with `%q` payload too, the edge agrees
  and `next` is not oblivious, as its branch reads payload (`phi_payload_branch`).

Two runs (the skeleton relation, T3b), one program each, for every pair of valuations of its
function related at the skeleton (`Valuation.Skel`) with one table of globals and every set of
payload blocks:
* `vals_skel` on block `%21` (`vadd21_skel`): its truncation, extension and three geps (nodes 0,
  1, 2, 4 and 7) have one value under both, so its loads and its store go to one address in both
  runs. Its two loads have payload result registers, so `Valuation.LoadsOk` holds
  (`Valuation.loadsOk_of_pay`);
* `Summary.oblivious_skel` on `vector_addition`'s four blocks (`vadd_skel`), given that the entry
  block's three loads of the byval arguments read outside the payload blocks (`Valuation.LoadsOk`,
  a premise): each exits to one block under both (`Exit.dest`), and each load and store has one
  pointer value under both;
* `Summary.oblivious_skel` on the naive matmul kernel's `%51` and `%67` under the labelling of
  `phi_agrees` (`naive_skel`): the branch of `%51` into `%67`, whose step sets the `phi` `%68`
  (`Exit.phi`), goes to one block under both, and the store of `%67` has one pointer under both.

The `phi` operands of an edge (`Summary.phiAgrees`), one program: `phiFn` with
`%p` and `%q` payload, and its twin `phiFn2`, whose `phi` takes `%p` inside a constant expression
(`splat`), so its operand is not a register (`TValue.payOk`): the edge `entry → next` agrees on
the first and not on the second (`phi_operand_twin`).

(O3) on a summary (`Summary.payOk`), one program: block `%21`'s summary passes; with its `fadd`
marked `nnan`, it does not (`vadd21_payOk`).

Two runs to the next block's entry (T3c on terms), one program each, for every pair of valuations
of its function related by `Valuation.Rel` and every set of payload blocks:
* `Valuation.into_rel` on block `%21` of `vector_addition` (`vadd21_into`), given that its store
  of the payload sum writes to a payload block under the first (`Valuation.StoresOk`, a premise):
  the valuations at the entry of block `%31`, which it exits to, are related;
* `Valuation.into_rel` on the naive matmul kernel's `%51` (`naive_into`): the valuations at the
  entry of `%67` after its `phi` (`%68 = phi float [%48, %51]`, `enter_rel`) are related, with
  `%68` payload in both and related by `Val.Skel`.

Two runs of a returning path (`Block.sound_retI_rel`), one program, for every two contexts and
threads of `vector_addition` at its entry block whose first takes the path `%4 → %21 → %31`
from entry valuations related by `Valuation.Rel`, and every set of payload blocks: given start
facts of the first run (registers `%0` to `%2` point to blocks outside it, and the struct that
`%5` loads through `%2` points to a block in it) and that their frames have one list of
`allocas`, both threads return and the returned memories are related by `Mem.SkelEq`
(`vadd_runs`; the second thread's path by `WalkI.rel`, the loads and the store by
`Valuation.loadsOk_of_regs` and `Valuation.storesOk_of_regs`, with `%6` at `%21`'s entry by
`vadd4_reg6`). The path's checks pass, and with `%28`
skeleton they do not (`vadd_pathOk`). The twin of the premise on `allocas`, for every
context, step count, frame, labelling and set of payload blocks: frames with `allocas` `[]` and
`[1]` have related entry valuations on a memory whose block 1 is live, and the memories their
returns make are not related (`allocas_twin`).

The term block `%21` stores (one summary, by `decide +kernel`): through the `gep` of the
output `%6` at an index node, the `fadd` at step 6 after the block entry (`SNode.fbin`, whose
oracle numbers are `Nat.pair (k + 6) i`) of the loads through the `gep`s of the inputs `%10` and
`%8` at the same index node (`cellOk`, `vadd21_cellOk`). The check fails with the inputs swapped,
with the output read as `%10`, at step 5, and on the entry block `%4`, which has no store
(`vadd21_cellOk_twin`).

What it stores (the value statement), for every valuation of `vector_addition`'s function in a
context of its program and every memory `me` the summary's effects make from it (`vadd21_store`),
and so for every thread at the block's entry whose obligations hold, at the block's end
(`vadd21_store_sound`, with `vadd21_sound`): `SumStored`, i.e. `me` is the store, through the
`getelementptr inbounds float` of `%6` at the index `%23` (`sext` of `trunc` of `%19`), of the
`fadd contract` with oracle numbers `Nat.pair (k + 6) j` of the floats loaded from the entry
memory through the `getelementptr`s of `%10` and `%8` at that index, on the entry memory with the
two loads' trace entries, and a float sum loads back from there. The instance and twin
(`vadd21_store_twin`): the premises hold on MojoProofTest/SymRun.lean's run at index 2, and no
valuation's entry memory is a memory of which `SumStored` holds (three more trace entries).
-/

namespace MojoProofTest.Payload

open MojoProof MojoProof.LLVM MojoProof.Sym MojoProofTest.Sym MojoProofTest.Labels

-- `Array.all` recurses by well-founded recursion, so `rfl` cannot evaluate `Labels.Ok` without
-- this.
unseal Array.anyM.loop

/-- The roles of block `%21`'s table under `vaddLab ["25", "27", "28"]`: the loads `%25` and
`%27` and the `fadd` `%28` payload, the truncation, extension and three geps skeleton. -/
theorem vadd21_roles :
    roles (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0 Kernels.vadd.b1.nodes =
      [false, false, false, true, false, true, true, false] := by
  decide +kernel

/-- **The instance**: the summaries of `vector_addition`'s four blocks are oblivious and agree
with `vaddLab ["25", "27", "28"]`. -/
theorem vadd_oblivious :
    [Kernels.vadd.b0, Kernels.vadd.b1, Kernels.vadd.b2, Kernels.vadd.b3].all (fun S =>
      S.oblivious (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0 &&
        S.agrees (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0) = true := by
  decide +kernel

/-- **The twins**: with the gep `%24` payload, block `%21`'s summary agrees with the labelling but
is not oblivious (the load `%25` is through a payload pointer); with the sum `%28` skeleton, and
with no register payload, it does not agree (the `fadd` node is payload). -/
theorem vadd_twins :
    Kernels.vadd.b1.agrees (vaddLab ["24", "25", "27", "28"]) Kernels.vadd.fn_0 = true ∧
      Kernels.vadd.b1.oblivious (vaddLab ["24", "25", "27", "28"]) Kernels.vadd.fn_0 = false ∧
      Kernels.vadd.b1.agrees (vaddLab ["25", "27"]) Kernels.vadd.fn_0 = false ∧
      Kernels.vadd.b1.agrees (vaddLab []) Kernels.vadd.fn_0 = false := by
  decide +kernel

/-- **The exit twins**: block `%21`'s summary with its exit a branch on the payload load `%25`
(node 3) is not oblivious, for a `cond` exit and for a `phi` exit. -/
theorem exit_twins :
    { Kernels.vadd.b1 with exit := .cond (.node 3) 1 2 }.oblivious (vaddLab ["25", "27", "28"])
        Kernels.vadd.fn_0 = false ∧
      { Kernels.vadd.b1 with exit := .phi (.node 3) 1 2 }.oblivious (vaddLab ["25", "27", "28"])
        Kernels.vadd.fn_0 = false := by
  decide +kernel

/-- **A real `phi` edge**: on the naive matmul kernel's edge `%51 → %67`, whose step sets
`%68 = phi float [%48, %51]`, with the accumulator `%48` and `%68` payload: `%51`'s summary agrees
with the labelling on the edge (`Summary.agreesI`), and `%67`'s summary after its `phi` (the store
of `%68` to `%40`) is oblivious and agrees. -/
theorem phi_agrees :
    SymPhi.out.agreesI (labIn SymPhi.naive.fn_0 ["48", "68"]) SymPhi.naive.fn_0
        SymPhi.naive.fn_0.b_5.label = true ∧
      SymPhi.fin.oblivious (labIn SymPhi.naive.fn_0 ["48", "68"]) SymPhi.naive.fn_0 = true ∧
      SymPhi.fin.agreesI (labIn SymPhi.naive.fn_0 ["48", "68"]) SymPhi.naive.fn_0
        SymPhi.naive.fn_0.b_7.label = true := by
  decide +kernel

/-- **The twin of `phi_agrees` on the edge `%51 → %67`**: with `%48` payload and `%68` skeleton,
the checks without the edge pass on both blocks (`%51`'s summary sets no register; `%67`'s stores
the skeleton-labelled `%68` through the skeleton `%40`), although `%68` receives the payload `%48`;
`Summary.agreesI` refuses the edge. -/
theorem phi_twin :
    SymPhi.out.oblivious (labIn SymPhi.naive.fn_0 ["48"]) SymPhi.naive.fn_0 = true ∧
      SymPhi.out.agrees (labIn SymPhi.naive.fn_0 ["48"]) SymPhi.naive.fn_0 = true ∧
      SymPhi.fin.oblivious (labIn SymPhi.naive.fn_0 ["48"]) SymPhi.naive.fn_0 = true ∧
      SymPhi.fin.agrees (labIn SymPhi.naive.fn_0 ["48"]) SymPhi.naive.fn_0 = true ∧
      SymPhi.out.agreesI (labIn SymPhi.naive.fn_0 ["48"]) SymPhi.naive.fn_0
        SymPhi.naive.fn_0.b_5.label = false := by
  decide +kernel

/-- A load fed to a `phi`: `define void @p(ptr %a)` whose `entry` (label 1) loads
`%p = load i32, ptr %a` and branches to `next` (label 3), which starts with
`%q = phi i32 [%p, %entry]`, computes `%c = icmp eq i32 %q, 0` and branches on `%c` to `yes` or
`no` (`ret void` each). -/
def phiFn : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "p",
    params := [⟨.ptr 0, [], some 0⟩], group := none,
    names := #["a", "entry", "p", "next", "q", "c", "yes", "no"],
    blocks := #[
      ⟨1, #[{ res := some 2, inst := .load false (.int 32) ⟨.ptr 0, .loc 0⟩ (some 4) }], .br 3⟩,
      ⟨3, #[{ res := some 4, inst := .phi (.int 32) [(.loc 2, 1)] },
        { res := some 5, inst := .icmp .eq (.int 32) (.loc 4) (.int 0) }], .condBr (.loc 5) 6 7⟩,
      ⟨6, #[], .ret none⟩, ⟨7, #[], .ret none⟩] }

/-- **A payload value through a `phi` into a branch**: with `%p` payload (and `%a`, `%q`, `%c`
skeleton), the summaries of `entry` and of `next` after its `phi` are oblivious and agree with the
labelling (`next` branches
on the skeleton-labelled `%q`), but `Summary.agreesI` refuses the edge `entry → next`, whose `phi`
gives `%q` the payload `%p`, and `Labels.Ok` refuses the program; with `%q` payload too, the edge
agrees and `next` is not oblivious, as its branch reads payload. -/
theorem phi_payload_branch :
    (summarize (.ofFunc phiFn) phiFn 1 0).map (fun S => (S.oblivious (labIn phiFn ["p"]) phiFn,
        S.agrees (labIn phiFn ["p"]) phiFn, S.agreesI (labIn phiFn ["p"]) phiFn 1,
        S.agreesI (labIn phiFn ["p", "q"]) phiFn 1)) = some (true, true, false, true) ∧
      (summarize (.ofFunc phiFn) phiFn 3 1).map (fun S => (S.oblivious (labIn phiFn ["p"]) phiFn,
        S.agreesI (labIn phiFn ["p"]) phiFn 3, S.oblivious (labIn phiFn ["p", "q"]) phiFn)) =
        some (true, true, false) := by
  decide +kernel

/-- `Labels.Ok` refuses `phiFn` with `%p` payload and `%q` skeleton: the `phi`'s
result is skeleton and its operand payload ((O2)). -/
theorem phi_payload_labels : Sem.Labels.Ok (.ofFunc phiFn) (labIn phiFn ["p"]) = false := rfl

/-- **The instance of `vals_skel`**: for every two valuations of `vector_addition`'s function
related at the skeleton of `vaddLab ["25", "27", "28"]` with one table of globals, for every set
of payload blocks, nodes 0, 1, 2, 4 and 7 of block `%21`'s table (the truncation, the extension
and the three geps) have one value under both. -/
theorem vadd21_skel {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel (vaddLab ["25", "27", "28"]) pay V₂) (hg : V₁.ctx.globals = V₂.ctx.globals)
    (hf : V₁.fn = Kernels.vadd.fn_0) :
    ∀ j ∈ [0, 1, 2, 4, 7],
      (vals V₁ Kernels.vadd.b1.nodes)[j]? = (vals V₂ Kernels.vadd.b1.nodes)[j]? := by
  intro j hj
  refine vals_skel h hg (Valuation.loadsOk_of_pay (by rw [hf]; decide +kernel)) j ?_
  rw [hf, vadd21_roles]
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hj
  rcases hj with rfl | rfl | rfl | rfl | rfl <;> rfl

/-- **The instance of `Summary.oblivious_skel`**: for every two valuations of `vector_addition`'s
function related at the skeleton of `vaddLab ["25", "27", "28"]` with one table of globals, for
every set of payload blocks such that the entry block's three loads (`%5`, `%7`, `%9`, of the byval
arguments, whose result registers are skeleton) read outside them under the first
(`Valuation.LoadsOk`, a premise), each of its four blocks exits to one block under both, and each of
its loads and its store has one pointer value under both. The other blocks' loads have payload
results (`loadsOk_of_pay`). -/
theorem vadd_skel {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel (vaddLab ["25", "27", "28"]) pay V₂) (hg : V₁.ctx.globals = V₂.ctx.globals)
    (hf : V₁.fn = Kernels.vadd.fn_0)
    (h4 : V₁.LoadsOk (vaddLab ["25", "27", "28"]) pay Kernels.vadd.b0.nodes) :
    ∀ S ∈ [Kernels.vadd.b0, Kernels.vadd.b1, Kernels.vadd.b2, Kernels.vadd.b3],
      Exit.dest V₁ (vals V₁ S.nodes) S.exit = Exit.dest V₂ (vals V₂ S.nodes) S.exit ∧
        ∀ e ∈ S.effs, e.ptr.eval V₁ (vals V₁ S.nodes) = e.ptr.eval V₂ (vals V₂ S.nodes) := by
  intro S hS
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hS
  rcases hS with rfl | rfl | rfl | rfl
  · exact Summary.oblivious_skel h hg (by rw [hf]; decide +kernel) h4
  all_goals
    exact Summary.oblivious_skel h hg (by rw [hf]; decide +kernel)
      (Valuation.loadsOk_of_pay (by rw [hf]; decide +kernel))

/-- **The instance of `Summary.oblivious_skel` on a `phi` edge**: for every two valuations of the
naive matmul kernel's function related at the skeleton of `labIn SymPhi.naive.fn_0 ["48", "68"]`
(`phi_agrees`'s labelling) with one table of globals, for every set of payload blocks, the exit
of `%51` (a branch into `%67`, which sets the `phi` `%68`) goes to one block under both, and so
does `%67`'s, whose store has one pointer value under both. -/
theorem naive_skel {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel (labIn SymPhi.naive.fn_0 ["48", "68"]) pay V₂)
    (hg : V₁.ctx.globals = V₂.ctx.globals) (hf : V₁.fn = SymPhi.naive.fn_0) :
    ∀ S ∈ [SymPhi.out, SymPhi.fin],
      Exit.dest V₁ (vals V₁ S.nodes) S.exit = Exit.dest V₂ (vals V₂ S.nodes) S.exit ∧
        ∀ e ∈ S.effs, e.ptr.eval V₁ (vals V₁ S.nodes) = e.ptr.eval V₂ (vals V₂ S.nodes) := by
  intro S hS
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hS
  rcases hS with rfl | rfl <;>
    exact Summary.oblivious_skel h hg (by rw [hf]; decide +kernel)
      (Valuation.loadsOk_of_pay (by rw [hf]; decide +kernel))

/-- `phiFn` with `next`'s `phi` reading `%p` inside a constant expression,
`%q = phi <1 x i32> [splat (i32 %p), %entry]` (the twin in `phi_operand_twin`). -/
def phiFn2 : Func :=
  { phiFn with
    blocks := #[
      ⟨1, #[{ res := some 2, inst := .load false (.int 32) ⟨.ptr 0, .loc 0⟩ (some 4) }], .br 3⟩,
      ⟨3, #[{ res := some 4, inst := .phi (.int 32) [(.splat ⟨.int 32, .loc 2⟩, 1)] },
        { res := some 5, inst := .icmp .eq (.int 32) (.loc 4) (.int 0) }], .condBr (.loc 5) 6 7⟩,
      ⟨6, #[], .ret none⟩, ⟨7, #[], .ret none⟩] }

/-- **The `phi` operand is a register**: on the edge `entry → next` of `phiFn`, with `%p` and `%q`
payload, the `phi` assignment agrees with the labelling (`Summary.phiAgrees`: its operand is the
register `%p`); in `phiFn2`, whose `phi` takes `%p` inside `splat`, it does not
(`TValue.payOk`). -/
theorem phi_operand_twin :
    (summarize (.ofFunc phiFn) phiFn 1 0).map (fun S =>
      (S.phiAgrees (labIn phiFn ["p", "q"]) phiFn 1 3,
        S.phiAgrees (labIn phiFn2 ["p", "q"]) phiFn2 1 3)) = some (true, false) := by
  decide +kernel

/-- **(O3) on block `%21`** (`Summary.payOk`): its payload nodes (the loads `%25` and `%27`
through skeleton pointers, of `float`, and the `fadd` `%28` with neither `nnan` nor `ninf`) pass;
with the `fadd` marked `nnan`, the summary does not. -/
theorem vadd21_payOk :
    Kernels.vadd.b1.payOk (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0 = true ∧
      { Kernels.vadd.b1 with nodes := Kernels.vadd.b1.nodes.map fun (nd : SNode) => match nd with
          | .fbin op fm ft n a b => .fbin op { fm with nnan := true } ft n a b
          | nd => nd }.payOk (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0 = false := by
  decide +kernel

/-- **The instance of `Valuation.into_rel`**: for every two valuations of `vector_addition`'s
function related by `Valuation.Rel` at `vaddLab ["25", "27", "28"]`, for every set of payload
blocks such that block `%21`'s store of the payload sum writes to one of them under the first
(`Valuation.StoresOk`, a premise), the valuations at the entry of the block `%21` exits to are
related. -/
theorem vadd21_into {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel (vaddLab ["25", "27", "28"]) pay V₂) (hf : V₁.fn = Kernels.vadd.fn_0)
    (hs : V₁.StoresOk (vaddLab ["25", "27", "28"]) pay Kernels.vadd.b1) :
    (V₁.into Kernels.vadd.fn_0.b_1.label Kernels.vadd.b1).Rel (vaddLab ["25", "27", "28"]) pay
      (V₂.into Kernels.vadd.fn_0.b_1.label Kernels.vadd.b1) :=
  Valuation.into_rel h (by rw [hf]; decide +kernel) (by rw [hf]; decide +kernel)
    (Valuation.loadsOk_of_pay (by rw [hf]; decide +kernel)) (by rw [hf]; decide +kernel) hs

/-- **The instance of `Valuation.into_rel` on a `phi` edge**: for every two valuations of the
naive matmul kernel's function related by `Valuation.Rel` at `labIn SymPhi.naive.fn_0 ["48",
"68"]`, for every set of payload blocks, the valuations at the entry of `%67`, after the step of
`%51`'s branch sets the `phi` `%68` to the accumulator `%48`, are related. -/
theorem naive_into {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel (labIn SymPhi.naive.fn_0 ["48", "68"]) pay V₂) (hf : V₁.fn = SymPhi.naive.fn_0) :
    (V₁.into SymPhi.naive.fn_0.b_5.label SymPhi.out).Rel (labIn SymPhi.naive.fn_0 ["48", "68"]) pay
      (V₂.into SymPhi.naive.fn_0.b_5.label SymPhi.out) :=
  Valuation.into_rel h (by rw [hf]; decide +kernel) (by rw [hf]; decide +kernel)
    (Valuation.loadsOk_of_pay (by rw [hf]; decide +kernel)) (by rw [hf]; decide +kernel)
    fun _ _ _ _ _ hm => by simp [show SymPhi.out.effs = [] from rfl] at hm

/-- **The path checks** (`pathOk`) on `vector_addition`'s path `%4 → %21 → %31` pass under
`vaddLab ["25", "27", "28"]`; with the sum `%28` labelled skeleton they do not (block `%21`'s
summary does not agree, (O2)). -/
theorem vadd_pathOk :
    pathOk (vaddLab ["25", "27", "28"]) Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_0.label
        Kernels.vadd.b0 vaddIn = true ∧
      pathOk (vaddLab ["25", "27"]) Kernels.vadd.fn_0 Kernels.vadd.fn_0.b_0.label
        Kernels.vadd.b0 vaddIn = false := by
  decide +kernel

/-- **Register `%6` at block `%21`'s entry**: for every valuation of `vector_addition`'s function
at its entry block `%4` whose register `%2` points to offset 0 of a block `p2` from which the
struct load `%5` reads a struct whose first field points to offset 0 of block `out` (any second
field `tl`), the register `%6` (that field, `extractvalue`) at the entry of the next block
(`Valuation.into`) points to offset 0 of `out`. -/
theorem vadd4_reg6 {V : Valuation} (hf : V.fn = Kernels.vadd.fn_0)
    (hP : V.ctx.prog = Kernels.vadd.prog) {p2 out : Nat} {tl : Sem.Val}
    (hr2 : V.regs 2 = some (.ptr ⟨p2, 0⟩))
    (hv2 : V.mem.load Kernels.vadd.prog.layout V.ctx.who 0
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨out, 0⟩, tl])) :
    (V.into Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0).regs 6 = some (.ptr ⟨out, 0⟩) := by
  have hs0 : V.stmt 4 0 = some ⟨some 5, .load false
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]])
      (.mk (.ptr 0) (.loc 2)) (some 8), []⟩ := by
    rw [Valuation.stmt, hf]; rfl
  have h0 : SNode.eval V [] (.load 4 0 (.reg 2)) = .ok (.agg [.ptr ⟨out, 0⟩, tl]) := by
    simp only [SNode.eval, SVal.eval, hs0, hr2, hP, bind, Except.bind, pure, Except.pure,
      Sem.Val.addr?, Option.getD_some, hv2, List.any_nil, Bool.false_and, Bool.cond_false]
  have h1 : (vals V Kernels.vadd.b0.nodes)[1]? = some (.ok (.ptr ⟨out, 0⟩)) := by
    rw [vals_getElem?]
    show some (SNode.eval V [SNode.eval V [] (.load 4 0 (.reg 2))] (.extract [0] (.node 0))) = _
    rw [h0]
    rfl
  have hi : V.into Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 = V.after Kernels.vadd.b0 := by
    obtain ⟨c, d, e, hx⟩ : ∃ c d e, Kernels.vadd.b0.exit = .cond c d e := ⟨_, _, _, rfl⟩
    show V.intoWith false _ _ = V.afterWith false _
    unfold Valuation.intoWith
    rw [hx]
  have hl : Kernels.vadd.b0.regs.lookup 6 = some (.node 1) := rfl
  have hx : (SVal.node 1).eval V (vals V Kernels.vadd.b0.nodes) = .ok (.ptr ⟨out, 0⟩) := by
    simp only [SVal.eval, h1, Option.getD_some]
  rw [hi]
  simp only [Valuation.after, regVal, hl, hx]
  rfl

/-- **The instance of `Block.sound_retI_rel`**: for every two contexts of `vector_addition` and
threads of one frame each at its entry block `%4`, on memories `m₁` and `m₂`, whose frames have
one list of `allocas`, whose first thread takes the path `%4 → %21 → %31` (`WalkI`), from entry
valuations related by `Valuation.Rel` at `vaddLab ["25", "27", "28"]`, for every set of payload
blocks `pay` and blocks `p0`, `p1`, `p2`, `out` such that the first frame's registers `%0` to
`%2` point to offset 0 of `p0` to `p2`, none in `pay`, and the struct load `%5` through `%2` on
`m₁` reads a struct whose first field points to offset 0 of `out`, in `pay` (the start
facts of `Kernel.sound_map2`, MojoProof/Sym/Kernel.lean, give these with `pay` the one block
`out`): both threads run the path and return, and the returned memories (each
frame's `allocas` made dead) are related by `Mem.SkelEq`. The second thread's path premises
follow from the first's (`WalkI.rel`; the obligations run only their blocks' effects,
`Cond.effsIn`). The entry block's three loads read outside `pay` (`Valuation.loadsOk_of_regs`,
through `%0` to `%2`) and block `%21`'s store of the payload sum writes to `out`
(`Valuation.storesOk_of_regs`, a `getelementptr` on `%6`, `vadd4_reg6`). The path's checks
(`vadd_pathOk`), `Cond.effsIn`, the bases of those pointers and the other loads and stores
(`Valuation.loadsOk_of_pay`, `Valuation.storesOk_of_skel`) are decided by the kernel. -/
theorem vadd_runs {pay : Nat → Prop} {c₁ c₂ : Sem.Ctx} (hP : c₁.prog = Kernels.vadd.prog)
    {t₁ t₂ : Sem.Thread} {m₁ m₂ : Sem.Mem} {f₁ f₂ : Sem.Frame} (ht₁ : t₁.frames = [f₁])
    (ht₂ : t₂.frames = [f₂]) (hfn : f₁.fn = Kernels.vadd.fn_0)
    (hl₁ : f₁.label = Kernels.vadd.fn_0.b_0.label) (hl₂ : f₂.label = Kernels.vadd.fn_0.b_0.label)
    (hp₁ : f₁.pc = 0) (hp₂ : f₂.pc = 0) (ha : f₁.allocas = f₂.allocas) {p0 p1 p2 out : Nat}
    {tl : Sem.Val} (hr0 : f₁.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f₁.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f₁.regs 2 = some (.ptr ⟨p2, 0⟩))
    (hv2 : m₁.load Kernels.vadd.prog.layout c₁.who 0
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨out, 0⟩, tl]))
    (hp0 : ¬ pay p0) (hp1 : ¬ pay p1) (hp2 : ¬ pay p2) (hout : pay out)
    (hW₁ : WalkI (Valuation.entry c₁ t₁.k m₁ f₁)
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn))
    (h : (Valuation.entry c₁ t₁.k m₁ f₁).Rel (vaddLab ["25", "27", "28"]) pay
      (Valuation.entry c₂ t₂.k m₂ f₂)) :
    ∃ fe₁ me₁ fe₂ me₂, Steps c₁ t₁ m₁ ⟨[fe₁], t₁.k + pathLen Kernels.vadd.b0 vaddIn⟩ me₁ ∧
      Steps c₂ t₂ m₂ ⟨[fe₂], t₂.k + pathLen Kernels.vadd.b0 vaddIn⟩ me₂ ∧
      Sem.step c₁ ⟨[fe₁], t₁.k + pathLen Kernels.vadd.b0 vaddIn⟩ me₁ =
        .ok (.done (f₁.allocas.foldl (fun m b => m.setLive b false) me₁)) ∧
      Sem.step c₂ ⟨[fe₂], t₂.k + pathLen Kernels.vadd.b0 vaddIn⟩ me₂ =
        .ok (.done (f₂.allocas.foldl (fun m b => m.setLive b false) me₂)) ∧
      (f₁.allocas.foldl (fun m b => m.setLive b false) me₁).SkelEq pay
        (f₂.allocas.foldl (fun m b => m.setLive b false) me₂) := by
  have hf₁ : (Valuation.entry c₁ t₁.k m₁ f₁).fn = Kernels.vadd.fn_0 := hfn
  have hf₂ : ∀ l S, ((Valuation.entry c₁ t₁.k m₁ f₁).into l S).fn = Kernels.vadd.fn_0 :=
    fun _ _ => (Valuation.into_k _ _ _).2.1.trans hf₁
  have hf₃ : ∀ l S l' S', (((Valuation.entry c₁ t₁.k m₁ f₁).into l S).into l' S').fn =
      Kernels.vadd.fn_0 := fun _ _ _ _ => (Valuation.into_k _ _ _).2.1.trans (hf₂ _ _)
  have h4 : (Valuation.entry c₁ t₁.k m₁ f₁).LoadsOk (vaddLab ["25", "27", "28"]) pay
      Kernels.vadd.b0.nodes :=
    Valuation.loadsOk_of_regs [0, 1, 2] (by rw [hf₁]; decide +kernel) fun r hr v hv => by
      change f₁.regs r = some v at hv
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hr
      rcases hr with rfl | rfl | rfl
      · rw [hr0] at hv; cases hv; simpa only [Sem.Val.NamesIn] using hp0
      · rw [hr1] at hv; cases hv; simpa only [Sem.Val.NamesIn] using hp1
      · rw [hr2] at hv; cases hv; simpa only [Sem.Val.NamesIn] using hp2
  have hs : ((Valuation.entry c₁ t₁.k m₁ f₁).into Kernels.vadd.fn_0.b_0.label
      Kernels.vadd.b0).StoresOk (vaddLab ["25", "27", "28"]) pay Kernels.vadd.b1 :=
    Valuation.storesOk_of_regs [6] (by rw [hf₂]; decide +kernel) fun r hr v hv => by
      simp only [List.mem_singleton] at hr
      subst hr
      rw [vadd4_reg6 hf₁ hP hr2 hv2] at hv
      cases hv
      simpa only [Sem.Val.NamesIn] using hout
  exact Block.sound_retI_rel hP (by decide +kernel) vadd_pathOk.1 (by decide +kernel) ht₁ ht₂ hfn
    hl₁ hl₂ hp₁ hp₂ ha hW₁ rfl h
    ⟨⟨h4, Valuation.storesOk_of_skel (by rw [hf₁]; decide +kernel)⟩,
      ⟨Valuation.loadsOk_of_pay (by rw [hf₂]; decide +kernel), hs⟩,
      Valuation.loadsOk_of_pay (by rw [hf₃]; decide +kernel),
      Valuation.storesOk_of_skel (by rw [hf₃]; decide +kernel)⟩

/-- A memory whose block 1 is live (four undefined bytes in address space 5). -/
def allocasMem : Sem.Mem :=
  { blocks := fun b =>
      if b = 1 then some ⟨5, 4, true, false, .all, fun _ => .undef, 0, 0⟩ else none }

/-- **The twin of `Block.sound_retI_rel`'s premise `ha`**: for every context, step count,
frame, labelling and set of payload blocks, the frames `f` with `allocas` `[]` and with `[1]` have
entry valuations on `allocasMem` related by `Valuation.Rel` (they are equal, as
`Valuation.entry` does not read `allocas`), and the memories the return makes of `allocasMem`
(the frame's `allocas` made dead) are not related by `Mem.SkelEq`: block 1 is live after the first
and dead after the second. -/
theorem allocas_twin (c : Sem.Ctx) (k : Nat) (f : Sem.Frame) (lab : Sem.Labels)
    (pay : Nat → Prop) :
    (Valuation.entry c k allocasMem { f with allocas := [] }).Rel lab pay
        (Valuation.entry c k allocasMem { f with allocas := [1] }) ∧
      ¬ (([] : List Nat).foldl (fun m b => m.setLive b false) allocasMem).SkelEq pay
        ([1].foldl (fun m b => m.setLive b false) allocasMem) := by
  refine ⟨⟨rfl, rfl, rfl, rfl, rfl, .refl _ _,
    fun _ => .refl (Sem.Labels.Rel.refl Sem.Val.Skel.refl _) _,
    fun _ => .refl (Sem.Labels.Rel.refl (fun _ => ⟨Sem.Val.Skel.refl _, Sem.Val.Skel.refl _⟩) _) _⟩,
    fun h => ?_⟩
  have h1 : Option.Rel (Sem.Block.SkelEq (pay 1))
      (some ⟨5, 4, true, false, .all, fun _ => .undef, 0, 0⟩)
      (some ⟨5, 4, false, false, .all, fun _ => .undef, 0, 0⟩) := h.blocks 1
  cases h1 with
  | some hB => exact absurd (congrArg Sem.Block.live hB.shape) (by decide)

/-- The base and index of node `g` of `S`'s table when it is a `gep`. -/
def gepOf (S : Summary) (g : Nat) : Option (SVal × SVal) :=
  match S.nodes[g]? with
  | some (.gep _ _ b i) => some (b, i)
  | _ => none

/-- The pointer of node `a` of `S`'s table when it is a load. -/
def loadOf (S : Summary) (a : Nat) : Option SVal :=
  match S.nodes[a]? with
  | some (.load _ _ p) => some p
  | _ => none

/-- `S`'s effects are two loads and a store; the stored value is an `fadd` on floats, at step `s`
after the block entry, of the two loads' nodes, in order; the loads read through `gep`s on the
entry registers `ra` and `rb`, and the store writes through a `gep` on the entry register `ro`, all
three at one index. -/
def cellOk (ra rb ro s : Nat) (S : Summary) : Bool :=
  match S.effs with
  | [.load _ _ (.node pa), .load _ _ (.node pb), .store _ _ (.node j) (.node po)] =>
    match S.nodes[j]?, gepOf S po with
    | some (.fbin .fadd _ .float s' (.node a) (.node b)), some (.reg ro', i) =>
      s' == s && ro' == ro && loadOf S a == some (.node pa) && loadOf S b == some (.node pb) &&
        gepOf S pa == some (.reg ra, i) && gepOf S pb == some (.reg rb, i)
    | _, _ => false
  | _ => false

/-- **The term block `%21` stores** (one summary): through the `gep` of the output `%6` at
an index, the `fadd` at step 6 after the block entry of the loads through the `gep`s of the inputs
`%10` and `%8` at the same index. -/
theorem vadd21_cellOk :
    cellOk (local? "10") (local? "8") (local? "6") 6 Kernels.vadd.b1 = true := by
  decide +kernel

/-- The twins of `vadd21_cellOk`: the check fails with the inputs swapped, with the output read as
`%10`, at step 5, and on the entry block's summary, which has no store. -/
theorem vadd21_cellOk_twin :
    cellOk (local? "8") (local? "10") (local? "6") 6 Kernels.vadd.b1 = false ∧
      cellOk (local? "10") (local? "8") (local? "10") 6 Kernels.vadd.b1 = false ∧
      cellOk (local? "10") (local? "8") (local? "6") 5 Kernels.vadd.b1 = false ∧
      cellOk (local? "10") (local? "8") (local? "6") 6 Kernels.vadd.b0 = false := by
  decide +kernel

/-- **What block `%21` stores, on a valuation `V` and the memory `me` at its end**: register `%19`
holds a value `r` whose `trunc` to 32 bits, `sext` to 64, is the index `i` (`%23`); the inputs
`%10` and `%8` and the output `%6` hold values whose `getelementptr inbounds float` at index `i`
are the pointers `qa`, `qb` and `qo`; the float loads at `qa` and `qb` (address space 0, alignment
4) from `V`'s memory give `xa` and `xb` (cells `i` of the inputs); the `fadd contract` of `xa` and
`xb` with the oracle number `Nat.pair (V.k + 6) j` for lane `j` is `x`; `me` is the store of `x`
at `qo` (the bytes of `x`) on `V`'s memory with the two loads' trace entries; and when `x` is a
float, the float load at `qo` from `me` gives `x`. -/
def SumStored (V : Valuation) (me : Sem.Mem) : Prop :=
  ∃ (r i pa pb po xa xb x : Sem.Val) (qa qb qo : Sem.Ptr),
    V.regs (local? "19") = some r ∧
    (Sem.lanes (fun _ => Sem.intCast .trunc 32) r >>=
      Sem.lanes (fun _ => Sem.intCast .sext 64)) = .ok i ∧
    V.regs (local? "10") = some pa ∧ V.regs (local? "8") = some pb ∧
    V.regs (local? "6") = some po ∧
    Sem.gep Kernels.vadd.prog.layout V.mem { inbounds := true } (.fp .float) 0 [i] pa =
      .ok (.ptr qa) ∧
    Sem.gep Kernels.vadd.prog.layout V.mem { inbounds := true } (.fp .float) 0 [i] pb =
      .ok (.ptr qb) ∧
    Sem.gep Kernels.vadd.prog.layout V.mem { inbounds := true } (.fp .float) 0 [i] po =
      .ok (.ptr qo) ∧
    V.mem.load Kernels.vadd.prog.layout V.ctx.who 0 (.fp .float) qa (some 4) = .ok xa ∧
    V.mem.load Kernels.vadd.prog.layout V.ctx.who 0 (.fp .float) qb (some 4) = .ok xb ∧
    Sem.lanes2 (fun j u v => Sem.floatBin .float .fadd { contract := true } u v none none
      (V.ctx.oracle (Nat.pair (V.k + 6) j))) xa xb = .ok x ∧
    ((V.mem.log (.access ⟨V.ctx.who, qa, 4, false, none, true⟩)).log
      (.access ⟨V.ctx.who, qb, 4, false, none, true⟩)).store Kernels.vadd.prog.layout
      V.ctx.who 0 (.fp .float) x qo (some 4) = .ok me ∧
    ∀ y, x = .ofFloat .float y →
      me.load Kernels.vadd.prog.layout V.ctx.who 0 (.fp .float) qo (some 4) = .ok x

/-- **The bytes block `%21` stores** (the value statement, the term `cellOk` checks read on
values): for every valuation of `vector_addition`'s function in a context of its program and
every memory `me` that the effects of `%21`'s summary make from it, `SumStored V me`: `me` is the
store, through the `gep` of `%6` at the index `%23`, of the `fadd contract` at step 6 of the
floats loaded through the `gep`s of `%10` and `%8` at that index, on the entry memory with the two
loads' trace entries. The summary's table and effects and the statements they name are those of
the program (by `rfl`); the rest unfolds `SEff.run`, `vals` and `SNode.eval`. -/
theorem vadd21_store {V : Valuation} (hP : V.ctx.prog = Kernels.vadd.prog)
    (hf : V.fn = Kernels.vadd.fn_0) {me : Sem.Mem}
    (h : SEff.run V (vals V Kernels.vadd.b1.nodes) Kernels.vadd.b1.effs = .ok me) :
    SumStored V me := by
  have hn : Kernels.vadd.b1.nodes = [.cast .trunc 32 (.reg 19), .cast .sext 64 (.node 0),
      .gep 21 2 (.reg 10) (.node 1), .load 21 3 (.node 2), .gep 21 4 (.reg 8) (.node 1),
      .load 21 5 (.node 4), .fbin .fadd { contract := true } .float 6 (.node 3) (.node 5),
      .gep 21 7 (.reg 6) (.node 1)] := rfl
  have he : Kernels.vadd.b1.effs = [.load 21 3 (.node 2), .load 21 5 (.node 4),
      .store 21 8 (.node 6) (.node 7)] := rfl
  have hs2 : V.stmt 21 2 = some ⟨some 25, .gep { inbounds := true } (.fp .float)
      (.mk (.ptr 0) (.loc 10)) [.mk (.int 64) (.loc 24)], []⟩ := by rw [Valuation.stmt, hf]; rfl
  have hs3 : V.stmt 21 3 = some ⟨some 26, .load false (.fp .float) (.mk (.ptr 0) (.loc 25))
      (some 4), [("invariant.load", 1)]⟩ := by rw [Valuation.stmt, hf]; rfl
  have hs4 : V.stmt 21 4 = some ⟨some 27, .gep { inbounds := true } (.fp .float)
      (.mk (.ptr 0) (.loc 8)) [.mk (.int 64) (.loc 24)], []⟩ := by rw [Valuation.stmt, hf]; rfl
  have hs5 : V.stmt 21 5 = some ⟨some 28, .load false (.fp .float) (.mk (.ptr 0) (.loc 27))
      (some 4), [("invariant.load", 1)]⟩ := by rw [Valuation.stmt, hf]; rfl
  have hs7 : V.stmt 21 7 = some ⟨some 30, .gep { inbounds := true } (.fp .float)
      (.mk (.ptr 0) (.loc 6)) [.mk (.int 64) (.loc 24)], []⟩ := by rw [Valuation.stmt, hf]; rfl
  have hs8 : V.stmt 21 8 = some ⟨none, .store false (.mk (.fp .float) (.loc 29))
      (.mk (.ptr 0) (.loc 30)) (some 4), []⟩ := by rw [Valuation.stmt, hf]; rfl
  simp only [SEff.run, he, hn, vals, List.foldl_cons, List.foldl_nil, List.nil_append,
    List.cons_append, List.foldlM_cons, List.foldlM_nil] at h
  set e0 := SNode.eval V [] (.cast .trunc 32 (.reg 19)) with he0
  set e1 := SNode.eval V [e0] (.cast .sext 64 (.node 0)) with he1
  set e2 := SNode.eval V [e0, e1] (.gep 21 2 (.reg 10) (.node 1)) with he2
  set e3 := SNode.eval V [e0, e1, e2] (.load 21 3 (.node 2)) with he3
  set e4 := SNode.eval V [e0, e1, e2, e3] (.gep 21 4 (.reg 8) (.node 1)) with he4
  set e5 := SNode.eval V [e0, e1, e2, e3, e4] (.load 21 5 (.node 4)) with he5
  set e6 := SNode.eval V [e0, e1, e2, e3, e4, e5]
    (.fbin .fadd { contract := true } .float 6 (.node 3) (.node 5)) with he6
  set e7 := SNode.eval V [e0, e1, e2, e3, e4, e5, e6] (.gep 21 7 (.reg 6) (.node 1)) with he7
  obtain ⟨m1, h1, h⟩ := Sem.Except.bind_eq_ok.1 h
  obtain ⟨m2, h2, h⟩ := Sem.Except.bind_eq_ok.1 h
  obtain ⟨m3, h3, h⟩ := Sem.Except.bind_eq_ok.1 h
  cases h
  simp only [SEff.apply, hs3, hs5, hs8, SVal.eval, List.getElem?_cons_succ,
    List.getElem?_cons_zero, Option.getD_some] at h1 h2 h3
  obtain ⟨g2, hg2, h1⟩ := Sem.Except.bind_eq_ok.1 h1
  obtain ⟨qa, hqa, h1⟩ := Sem.Except.bind_eq_ok.1 h1
  obtain ⟨g4, hg4, h2⟩ := Sem.Except.bind_eq_ok.1 h2
  obtain ⟨qb, hqb, h2⟩ := Sem.Except.bind_eq_ok.1 h2
  obtain ⟨x, hx, h3⟩ := Sem.Except.bind_eq_ok.1 h3
  obtain ⟨g7, hg7, h3⟩ := Sem.Except.bind_eq_ok.1 h3
  obtain ⟨qo, hqo, hstore⟩ := Sem.Except.bind_eq_ok.1 h3
  have hreg : ∀ {r : Nat} {v : Sem.Val} {vs : List (Except Sem.Fault Sem.Val)},
      (SVal.reg r).eval V vs = .ok v → V.regs r = some v := by
    intro r v vs h
    simp only [SVal.eval] at h
    split at h
    · rename_i v' hv
      cases h
      exact hv
    · cases h
  have hptr : ∀ {g : Sem.Val} {q : Sem.Ptr}, g.addr? = .ok q → g = .ptr q := by
    intro g q h
    cases g <;> cases h
    rfl
  have hnode : ∀ (j : Nat) (vs : List (Except Sem.Fault Sem.Val)), (SVal.node j).eval V vs =
      vs[j]?.getD (throw (.unsupported "symbolic node not in the table")) := fun _ _ => rfl
  have hnu : (([("invariant.load", 1)] : List (String × Nat)).any
      fun x => x.1 == "noundef") = false := by decide
  have hload : ∀ {e : Except Sem.Fault Sem.Val} {q : Sem.Ptr} {v : Sem.Val}, e = .ok (.ptr q) →
      (do
        let q ← (← e).addr?
        let v ← V.mem.load V.ctx.prog.layout V.ctx.who 0 (.fp .float) q (some 4)
        bif (([("invariant.load", 1)] : List (String × Nat)).any fun x => x.1 == "noundef") &&
          !v.defined then throw (Sem.Fault.ub "noundef load not defined") else pure v) = .ok v →
      V.mem.load Kernels.vadd.prog.layout V.ctx.who 0 (.fp .float) q (some 4) = .ok v := by
    intro e q v he h
    rw [he] at h
    obtain ⟨g, hg, h⟩ := Sem.Except.bind_eq_ok.1 h
    obtain ⟨q', hq, h⟩ := Sem.Except.bind_eq_ok.1 h
    cases hg
    cases hq
    obtain ⟨v', hv, h⟩ := Sem.Except.bind_eq_ok.1 h
    simp only [hnu, Bool.false_and, Bool.cond_false] at h
    cases h
    rw [← hP]
    exact hv
  cases hptr hqa
  cases hptr hqb
  cases hptr hqo
  cases h1
  cases h2
  have he2ok := hg2
  have he4ok := hg4
  -- the index
  rw [he2] at hg2
  simp only [SNode.eval, hs2, hnode, List.getElem?_cons_succ, List.getElem?_cons_zero,
    Option.getD_some] at hg2
  obtain ⟨i, hi, hg2⟩ := Sem.Except.bind_eq_ok.1 hg2
  obtain ⟨pa, hpa, hg2⟩ := Sem.Except.bind_eq_ok.1 hg2
  have he1ok := hi
  rw [he1] at hi
  simp only [SNode.eval, hnode, List.getElem?_cons_zero, Option.getD_some] at hi
  obtain ⟨i0, hi0, hi⟩ := Sem.Except.bind_eq_ok.1 hi
  rw [he0] at hi0
  simp only [SNode.eval] at hi0
  obtain ⟨r, hr, hi0⟩ := Sem.Except.bind_eq_ok.1 hi0
  -- the other geps
  rw [he4] at hg4
  simp only [SNode.eval, hs4, hnode, List.getElem?_cons_succ, List.getElem?_cons_zero,
    Option.getD_some, he1ok] at hg4
  obtain ⟨_, ⟨⟩, hg4⟩ := Sem.Except.bind_eq_ok.1 hg4
  obtain ⟨pb, hpb, hg4⟩ := Sem.Except.bind_eq_ok.1 hg4
  rw [he7] at hg7
  simp only [SNode.eval, hs7, hnode, List.getElem?_cons_succ, List.getElem?_cons_zero,
    Option.getD_some, he1ok] at hg7
  obtain ⟨_, ⟨⟩, hg7⟩ := Sem.Except.bind_eq_ok.1 hg7
  obtain ⟨po, hpo, hg7⟩ := Sem.Except.bind_eq_ok.1 hg7
  -- the sum and the loads
  rw [he6] at hx
  simp only [SNode.eval, hnode, SVal.prods, laneOf, Option.map, List.getElem?_cons_succ,
    List.getElem?_cons_zero, Option.getD_some] at hx
  obtain ⟨xa, hxa, hx⟩ := Sem.Except.bind_eq_ok.1 hx
  obtain ⟨xb, hxb, hx⟩ := Sem.Except.bind_eq_ok.1 hx
  rw [he3] at hxa
  simp only [SNode.eval, hs3, hnode, List.getElem?_cons_succ, List.getElem?_cons_zero,
    Option.getD_some] at hxa
  rw [he5] at hxb
  simp only [SNode.eval, hs5, hnode, List.getElem?_cons_succ, List.getElem?_cons_zero,
    Option.getD_some] at hxb
  have hst : Kernels.vadd.prog.layout.stored (.fp .float) = 4 := by decide
  have hinv : (([("invariant.load", 1)] : List (String × Nat)).any
      fun x => x.1 == "invariant.load") = true := by decide
  rw [hP, hst, hinv] at hstore
  rw [hP] at hg2 hg4 hg7
  unfold SumStored
  refine ⟨r, i, pa, pb, po, xa, xb, x, qa, qb, qo, hreg hr, by rw [hi0]; exact hi, hreg hpa,
    hreg hpb, hreg hpo, hg2, hg4, hg7, hload he2ok hxa, hload he4ok hxb, hx, hstore, ?_⟩
  rintro y rfl
  obtain ⟨_, _, hc, -⟩ := Sem.Mem.store_inv hstore
  exact Sem.Mem.load_store_codec (Sem.Layout.Codec.float _ .float) y hstore hc

/-- **Under `Block.sound`'s premises** (`vadd21_sound`): for every context of `vector_addition`
and thread whose innermost frame `f` is at block `%21`'s entry on memory `m`, with every
obligation of the summary holding, the thread's steps reach the block's end with a memory `me`
of which `SumStored` holds at the entry valuation (registers of `f`, memory `m`, step count
`t.k`): the output cell at index `%23` holds the bytes of the `fadd` of the input cells there. -/
theorem vadd21_store_sound {c : Sem.Ctx} (hP : c.prog = Kernels.vadd.prog) {t : Sem.Thread}
    {m : Sem.Mem} {f : Sem.Frame} {rest : List Sem.Frame} (ht : t.frames = f :: rest)
    (hfn : f.fn = Kernels.vadd.fn_0) (hl : f.label = Kernels.vadd.fn_0.b_1.label) (hp : f.pc = 0)
    (hds : ∀ d ∈ Kernels.vadd.b1.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) Kernels.vadd.b1.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + Kernels.vadd.b1.len⟩ me ∧
      SumStored (Valuation.entry c t.k m f) me := by
  obtain ⟨fe, me, hS, hm⟩ := vadd21_sound hP ht hfn hl hp hds
  exact ⟨fe, me, hS, vadd21_store hP hfn hm⟩

/-- **An instance and a twin of `vadd21_store_sound`**: its premises hold on the concrete run of
MojoProofTest/SymRun.lean at index 2 (`frame0 2 3` under `ctx0` on `mem0`, `vadd21_hds`), so the
steps reach the block's end with a memory of which `SumStored` holds; and for every valuation `V`,
`SumStored V V.mem` fails: the memory the block makes has three more trace entries than the entry
memory (the two loads' and the store's). -/
theorem vadd21_store_twin :
    (∃ fe me, Steps SymRun.ctx0 ⟨[SymRun.frame0 2 3], 0⟩ SymRun.mem0
        ⟨[fe], 0 + Kernels.vadd.b1.len⟩ me ∧
      SumStored (Valuation.entry SymRun.ctx0 0 SymRun.mem0 (SymRun.frame0 2 3)) me) ∧
      ∀ V : Valuation, ¬ SumStored V V.mem := by
  refine ⟨vadd21_store_sound rfl rfl rfl rfl rfl (SymRun.vadd21_hds 2 (by decide)), ?_⟩
  rintro V ⟨_, _, _, _, _, _, _, _, _, _, _, -, -, -, -, -, -, -, -, -, -, -, h, -⟩
  obtain ⟨_, _, -, -, -, he⟩ := Sem.Mem.store_inv h
  have hl := congrArg (fun m => m.trace.length) he
  simp only [Sem.Mem.log, Sem.Mem.set, List.length_cons] at hl
  omega

end MojoProofTest.Payload
