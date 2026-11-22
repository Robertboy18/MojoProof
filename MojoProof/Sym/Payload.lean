import MojoProof.Sym.Path
import MojoProof.Sem.SkelExec

/-!
# Roles, payload-freedom and obliviousness on a block summary's node table

docs/proofs/payload.md, "Obliviousness on terms". The term form of T3b's labelling checks
(`Labels.Ok`, MojoProof/Sem/Labels.lean) on a block summary (`Summary`, MojoProof/Sym/Checker.lean):
under a labelling `lab` (`Labels`), each node of the table gets a role, payload (`true`) or
skeleton (`false`), computed from the roles of the nodes before it, as `vals` computes values.

* `scanSnoc f ns`: the list each of whose entries is `f` of the entries before it and the next
  element of `ns` (the fold `vals` and `roles` both are). Proved for every `f` and list:
  `scanSnoc_length` (one entry per element), `scanSnoc_snoc`, `scanSnoc_append` and
  `scanSnoc_getElem?` (entry `j` is `f` of the entries of the first `j` elements and element
  `j`).
* `SVal.pay`, `SNode.pay`, `roles`: an entry register is payload by its label, a constant never;
  a node is payload if an operand is, if it is a `call`, `getelementptr` or `load` whose
  statement's result register (`resReg`) is labelled payload, and always if it is a float
  operation, whose NaN results the oracle chooses ((O2) of Sem/Labels.lean). `roles_length` and
  `roles_getElem?` are `scanSnoc`'s lemmas at `SNode.pay`.
* `Summary.oblivious` (docs/proofs/payload.md, "Obliviousness on terms"): the exit condition, the
  pointer of each effect, and the base, index and pointer operands of each `getelementptr` and
  `load` node are payload-free (`SVal.payloadFree`): (O1) on terms.
* `Summary.agrees`: each register the summary sets whose entry is payload is labelled payload.
  A register labelled payload may hold a skeleton entry: like `Labels.Ok`, the labelling may
  over-approximate.
* `Summary.phiAgrees` and `Summary.agreesI`: an edge into a block with `phi`s also
  sets the target's `phi` results (`enter`, `Valuation.into`), which are in no summary's
  registers (the target's summary starts after them). `phiAgrees lab fn lbl S d`: each `phi` at
  the head of block `d` (`phisAt`, as `enter` reads them) whose operand for the edge from `lbl`
  mentions a register that holds payload at the block's end (`Summary.endPay`) has a result
  register labelled payload, and that operand is a register (`TValue.payOk`). `agreesI`:
  `agrees`, and `phiAgrees` on each target of the exit. These are the register labels at the next
  block's entry: a register is set there by a `phi` of the edge (`phiAgrees`), else by the block
  (`agrees`), else not at all.

These are `Bool` checks, evaluated by the kernel (MojoProofTest/Payload.lean: every block of
`vector_addition`, and the `phi` edges of the naive matmul kernel and of an inline program).

What the roles give two runs (task 3b), for every labelling, payload blocks, table and pair of
valuations:
* `Valuation.Skel lab pay V₁ V₂`: one program, environment, thread and function, memories related
  by `Mem.SkelEq pay`, and equal registers where `lab` labels skeleton (step counts, `fmul
  contract` operands, globals, address choices and oracles may differ).
* `Valuation.LoadsOk lab pay V ns`: under `V`, each `load` node of `ns` whose statement's result
  register is skeleton points outside `pay` (`Labels.MemAt` at a `load`, on terms).
  `Valuation.loadsOk_of_pay`: it holds when every `load` node has a payload result register.
* `vals_skel`: under related valuations meeting `LoadsOk` under the first, every node whose role
  is skeleton has one value under both (`SVal.eval_skel` for operands, `SNode.eval_skel` for
  nodes: `icmpV`, `gep` and `withAttrs` read only the memory's shape, `gep_shape`,
  `icmpV_shape`, `withAttrs_shape`; a skeleton load reads a block outside `pay`,
  `Mem.load_skel`).
* `Summary.oblivious_skel`: under such valuations, an oblivious summary's exit goes to one block
  (or to none) under both (`Exit.dest`, so a branch into blocks with `phi`s too), and each
  effect's pointer (`SEff.ptr`) has one value under both.

At the next block's entry (T3c on terms), for every labelling, payload blocks, summary and pair of
valuations:
* `Valuation.Rel lab pay V₁ V₂`: `Valuation.Skel` with one table of globals, and registers and
  `fmul contract` operands related by `Val.Skel` where `lab` labels payload (as `Frame.Skel`).
* `SNode.payOk` and `Summary.payOk`: (O3) on the payload nodes. An integer operator is total
  (`BinOp.total`) and its second operand is skeleton if it reads its value (`BinOp.skelB`); a
  `getelementptr` and a `load` have skeleton operands; a `load` reads a data type (`Ty.data`); a
  float operation has neither `nnan` nor `ninf`. `Valuation.StoresOk`: each `store` of a payload
  value writes to a block of `pay` (`Labels.MemAt` at a `store`, on terms).
* `vals_rel`: every node has related values under both (`Val.Skel` at a payload role, equal at
  a skeleton one; `SVal.eval_rel`, `SNode.eval_rel`).
* `SEff.run_rel`: the effects of an oblivious summary make related memories (`Mem.SkelEq`), or
  one fault.
* `Valuation.after_rel` (from `Summary.agrees`) and `Valuation.into_rel` (from
  `Summary.agreesI`, with the `phi`s of a branch into blocks with `phi`s, `enter_rel`): the
  valuations at the next block's entry are related by `Valuation.Rel`.
* `Valuation.lastI_rel` and `Block.sound_retI_rel`: along a path whose summaries pass these
  checks (`pathOk`) and whose loads and stores meet `LoadsOk` and `StoresOk` under the first run
  (`Valuation.PathMem`), the valuations stay related from block to block (`Valuation.lastI`);
  with `Block.sound_retR` (MojoProof/Sym/Path.lean), two threads that run a returning path from
  frames with one
  list of `allocas` return (`.done`) on memories related by `Mem.SkelEq pay`, the memories after
  the return's cleanup (`Mem.foldl_setLive_skel`). `WalkI.rel`: the second run's premises
  (`WalkI`) follow from the first's when each obligation runs only effects of its block's summary
  (`Cond.effsIn`; `Cond.holds_rel` for one obligation), so `Block.sound_retI_rel` takes the first
  run's only. `Valuation.storesOk_of_skel`: `StoresOk` holds when no store has a payload value.
* `Valuation.loadsOk_of_regs` and `Valuation.storesOk_of_regs`: `LoadsOk` and `StoresOk` from
  the values of entry registers, when each skeleton load's and payload store's pointer has its
  base in them (`SVal.baseIn`: the register, or a `getelementptr` on it; `SVal.eval_baseIn`).
Not proved: the discharge of `LoadsOk` and `StoresOk` from `Labels.MemOk` (it needs, at each
statement `Block.sound` runs, the statement's pointer to be the term's), two runs of a grid, and
3c's two runs of block `%21`'s cell (MojoProofTest/SymRun.lean) (T3c).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

section scan

variable {α β : Type} (f : List β → α → β)

/-- The list each of whose entries is `f` of the entries before it and the next element of `ns`,
in order (`vals` and `roles` are this fold). -/
def scanSnoc (ns : List α) : List β :=
  ns.foldl (fun acc a => acc ++ [f acc a]) []

/-- The fold of `scanSnoc` from entries `acc` only appends, one entry per element. -/
theorem scanSnoc_fold (ns : List α) (acc : List β) :
    ∃ ws, ns.foldl (fun acc a => acc ++ [f acc a]) acc = acc ++ ws ∧ ws.length = ns.length := by
  induction ns generalizing acc with
  | nil => exact ⟨[], (List.append_nil _).symm, rfl⟩
  | cons a ns ih =>
    obtain ⟨ws, h, hl⟩ := ih (acc ++ [f acc a])
    refine ⟨f acc a :: ws, ?_, ?_⟩
    · rw [List.foldl_cons, h, List.append_assoc]; rfl
    · simp only [List.length_cons, hl]

/-- One entry per element. -/
theorem scanSnoc_length (ns : List α) : (scanSnoc f ns).length = ns.length := by
  obtain ⟨ws, h, hl⟩ := scanSnoc_fold f ns []
  rw [scanSnoc, h, List.nil_append, hl]

/-- The entries of a list with `a` appended: the list's entries, then `f` of them and `a`. -/
theorem scanSnoc_snoc (ns : List α) (a : α) :
    scanSnoc f (ns ++ [a]) = scanSnoc f ns ++ [f (scanSnoc f ns) a] := by
  simp only [scanSnoc, List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- Appending elements keeps the entries before. -/
theorem scanSnoc_append (ns ns' : List α) : ∃ ws, scanSnoc f (ns ++ ns') = scanSnoc f ns ++ ws := by
  obtain ⟨ws, h, -⟩ := scanSnoc_fold f ns' (scanSnoc f ns)
  exact ⟨ws, by rw [scanSnoc, List.foldl_append]; exact h⟩

/-- **Entry `j`**: for every `f`, list `ns` and `j`, entry `j` of `scanSnoc f ns` is `f` of the
entries of the first `j` elements and element `j`, and there is none when `ns` has no element
`j`. -/
theorem scanSnoc_getElem? (ns : List α) (j : Nat) :
    (scanSnoc f ns)[j]? = ns[j]?.map fun a => f (scanSnoc f (ns.take j)) a := by
  by_cases hj : j < ns.length
  · obtain ⟨ws, hw⟩ := scanSnoc_append f (ns.take (j + 1)) (ns.drop (j + 1))
    rw [List.take_append_drop] at hw
    rw [hw, List.take_add_one, List.getElem?_eq_getElem hj, Option.toList_some, scanSnoc_snoc,
      List.getElem?_append_left (by
        simp only [List.length_append, scanSnoc_length, List.length_take, List.length_singleton]
        omega),
      List.getElem?_append_right (by simp only [scanSnoc_length, List.length_take]; omega)]
    simp [scanSnoc_length, List.length_take, Nat.min_eq_left (Nat.le_of_lt hj)]
  · rw [List.getElem?_eq_none (by rw [scanSnoc_length]; omega), List.getElem?_eq_none (by omega)]
    rfl

end scan

/-- The result register of statement `pc` of block `lbl` of `fn`, if any (`Valuation.stmt`'s
lookup, then `Stmt.res`). -/
def resReg (fn : Func) (lbl pc : Nat) : Option Nat :=
  ((fn.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?)).bind (·.res)

/-- Whether operand `x` of function `fn` is payload under `lab`, given the roles `ps` of the
nodes before it: an entry register by its label, a constant never, a node by its role. -/
def SVal.pay (lab : Labels) (fn : Func) (ps : List Bool) : SVal → Bool
  | .reg r => lab.reg fn.name r
  | .int _ _ => false
  | .node j => ps.getD j false

/-- The role of a node of function `fn` under `lab`, given the roles `ps` of the nodes before
it: payload if an operand is (`SVal.pay`; a `select`'s condition among them), if it is a `call`,
`getelementptr` or `load` whose statement's result register is labelled payload, and always for
a float operation, whose NaN results the oracle chooses ((O2) of Sem/Labels.lean); never for a
float constant, which reads no payload. -/
def SNode.pay (lab : Labels) (fn : Func) (ps : List Bool) : SNode → Bool
  | .bin _ _ _ a b | .icmp _ _ a b | .minmax _ _ a b => a.pay lab fn ps || b.pay lab fn ps
  | .cast _ _ a | .extract _ a => a.pay lab fn ps
  | .call lbl pc => (resReg fn lbl pc).any (lab.reg fn.name)
  | .gep lbl pc a b =>
    a.pay lab fn ps || b.pay lab fn ps || (resReg fn lbl pc).any (lab.reg fn.name)
  | .load lbl pc p => p.pay lab fn ps || (resReg fn lbl pc).any (lab.reg fn.name)
  | .fbin .. | .fbinP .. => true
  | .select _ c a b => c.pay lab fn ps || a.pay lab fn ps || b.pay lab fn ps
  | .flit .. => false

/-- The roles of the nodes of table `ns` of function `fn` under `lab`, in order (`true`:
payload), each from the roles of the nodes before it. -/
def roles (lab : Labels) (fn : Func) (ns : List SNode) : List Bool :=
  scanSnoc (fun ps nd => nd.pay lab fn ps) ns

/-- One role per node. -/
theorem roles_length (lab : Labels) (fn : Func) (ns : List SNode) :
    (roles lab fn ns).length = ns.length :=
  scanSnoc_length _ ns

/-- **The role of node `j`**: for every labelling, function, table `ns` and `j`, it is `SNode.pay`
of node `j` on the roles of the nodes before it, and there is none when `ns` has no node `j`. -/
theorem roles_getElem? (lab : Labels) (fn : Func) (ns : List SNode) (j : Nat) :
    (roles lab fn ns)[j]? = ns[j]?.map fun nd => nd.pay lab fn (roles lab fn (ns.take j)) :=
  scanSnoc_getElem? _ ns j

/-- Operand `x` of table `ns` of function `fn` is payload-free under `lab`. -/
def SVal.payloadFree (lab : Labels) (fn : Func) (ns : List SNode) (x : SVal) : Bool :=
  !x.pay lab fn (roles lab fn ns)

/-- The pointer operand of an effect. -/
def SEff.ptr : SEff → SVal
  | .load _ _ p | .store _ _ _ p => p

/-- **Obliviousness** ((O1) on terms): the summary's
exit condition (of a `cond` or `phi` exit), the pointer of each of its effects, the base, index
and pointer operands of each of its `getelementptr` and `load` nodes, and the condition of each of
its `select` nodes are payload-free under `lab`. -/
def Summary.oblivious (lab : Labels) (fn : Func) (S : Summary) : Bool :=
  let free := SVal.payloadFree lab fn S.nodes
  (match S.exit with | .cond x _ _ | .phi x _ _ => free x | .br _ | .ret => true) &&
  S.effs.all (fun e => free e.ptr) &&
  S.nodes.all fun
    | .gep _ _ a b => free a && free b
    | .load _ _ p => free p
    -- a `select` chooses an operand by its condition, as a branch does
    | .select _ c _ _ => free c
    -- the other nodes neither choose nor address memory
    | .bin .. | .icmp .. | .cast .. | .extract .. | .call .. | .fbin .. | .minmax .. | .fbinP ..
    | .flit .. => true

/-- **The roles agree with the labelling**: every register the summary sets whose entry is
payload is labelled payload under `lab`. A register labelled payload may have a skeleton entry
(the labelling may over-approximate, as `Labels.Ok`'s). -/
def Summary.agrees (lab : Labels) (fn : Func) (S : Summary) : Bool :=
  S.regs.all fun (r, x) => !x.pay lab fn (roles lab fn S.nodes) || lab.reg fn.name r

/-- The `phi`s at the head of block `d` of `fn`, as `enter` reads them (none when `fn` has no
block `d`). -/
def phisAt (fn : Func) (d : Nat) : List Stmt :=
  match fn.blocks.find? (·.label == d) with
  | some b => b.stmts.toList.takeWhile (·.inst matches .phi _ _)
  | none => []

/-- Whether register `r` of function `fn` holds payload at the end of the block whose summary is
`S`, under `lab`: the role (`SVal.pay` on `S`'s roles) of its entry there (`SState.get`: the
summary's entry if the block sets it, else the entry register `r`, payload by its label). -/
def Summary.endPay (lab : Labels) (fn : Func) (S : Summary) (r : Nat) : Bool :=
  ((S.regs.lookup r).getD (.reg r)).pay lab fn (roles lab fn S.nodes)

/-- **The `phi` assignments of an edge agree with the labelling**: on
the edge from block `lbl` of `fn`, whose summary is `S`, into block `d`, each `phi` at the head of
`d` (`phisAt`) whose operand `v` for `lbl` mentions a register that holds payload at the block's
end (`Summary.endPay`; itself, or inside a constant expression) has a result register labelled
payload under `lab`, and `v` passes `TValue.payOk` (it is a register). An operand that mentions
none passes whatever the result's label: it has one value in two runs. A `phi` with no operand
for `lbl` passes (`enter` faults on it). -/
def Summary.phiAgrees (lab : Labels) (fn : Func) (lbl : Nat) (S : Summary) (d : Nat) : Bool :=
  (phisAt fn d).all fun st => match st.inst with
    | .phi t inc => match inc.find? (·.2 == lbl) with
      | some (v, _) => !v.mentions (S.endPay lab fn) ||
          (st.res.any (lab.reg fn.name) && TValue.payOk (S.endPay lab fn) ⟨t, v⟩)
      | none => true
    | _ => true

/-- **Agreement at the next block's entry**: block `lbl`'s summary `S` agrees with the
labelling (`Summary.agrees`), and so do the `phi` assignments of each edge of its exit
(`Summary.phiAgrees` at each target of a branch; `ret void` has none). -/
def Summary.agreesI (lab : Labels) (fn : Func) (lbl : Nat) (S : Summary) : Bool :=
  S.agrees lab fn && match S.exit with
    | .br d => S.phiAgrees lab fn lbl d
    | .cond _ d e | .phi _ d e => S.phiAgrees lab fn lbl d && S.phiAgrees lab fn lbl e
    | .ret => true

/-! ### Skeleton nodes have one value in two runs (task 3b) -/

/-- Results related by equality are equal. -/
theorem _root_.Except.Rel.eq {ε α : Type} {x y : Except ε α} (h : Except.Rel Eq x y) : x = y := by
  cases h with
  | error e => rfl
  | ok h => rw [h]

/-- The roles of a table with node `nd` appended: the table's roles, then `nd`'s on them. -/
theorem roles_snoc (lab : Labels) (fn : Func) (ns : List SNode) (nd : SNode) :
    roles lab fn (ns ++ [nd]) = roles lab fn ns ++ [nd.pay lab fn (roles lab fn ns)] :=
  scanSnoc_snoc _ ns nd

/-- **Valuations related at the skeleton** of labelling `lab`, with payload blocks `pay`: one
program, environment, thread and function, memories related by `Mem.SkelEq pay`, and equal
registers where `lab` labels skeleton. The step counts, `fmul contract` operands, globals, address
choices and oracles may differ. -/
structure Valuation.Skel (lab : Labels) (pay : Nat → Prop) (V₁ V₂ : Valuation) : Prop where
  /-- Builds `Valuation.Skel` from its six fields. -/
  mk ::
  /-- One program. -/
  prog : V₁.ctx.prog = V₂.ctx.prog
  /-- One environment of special registers. -/
  env : V₁.ctx.env = V₂.ctx.env
  /-- One thread. -/
  who : V₁.ctx.who = V₂.ctx.who
  /-- One function. -/
  fn : V₁.fn = V₂.fn
  /-- Memories related by `Mem.SkelEq pay`. -/
  mem : V₁.mem.SkelEq pay V₂.mem
  /-- Equal registers where `lab` labels skeleton. -/
  regs : ∀ r, lab.reg V₁.fn.name r = false → V₁.regs r = V₂.regs r

/-- **The skeleton loads of table `ns` read outside `pay`** under `V` (`Labels.MemAt` at a `load`,
on terms): the pointer of each `load` node whose statement's result register is not labelled
payload, when it has a pointer value, points to a block outside `pay`. -/
def Valuation.LoadsOk (lab : Labels) (pay : Nat → Prop) (V : Valuation) (ns : List SNode) :
    Prop :=
  ∀ (j lbl pc : Nat) (p : SVal) (q : Ptr), ns[j]? = some (SNode.load lbl pc p) →
    (resReg V.fn lbl pc).any (lab.reg V.fn.name) = false →
    p.eval V (vals V (ns.take j)) = Except.ok (Val.ptr q) → ¬ pay q.block

/-- For every labelling, payload blocks, valuation and table each of whose `load` nodes has a
result register labelled payload, `Valuation.LoadsOk` holds. -/
theorem Valuation.loadsOk_of_pay {lab : Labels} {pay : Nat → Prop} {V : Valuation}
    {ns : List SNode} (h : ns.all (fun
      | .load lbl pc _ => (resReg V.fn lbl pc).any (lab.reg V.fn.name)
      | _ => true) = true) : V.LoadsOk lab pay ns := by
  intro j lbl pc p q hj hr _
  have := List.all_eq_true.1 h _ (List.mem_of_getElem? hj)
  simp [hr] at this

/-- For every labelling, payload blocks and valuations related at the skeleton, and node values
equal at the skeleton roles `ps`, a skeleton operand has one value under both. -/
theorem SVal.eval_skel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel lab pay V₂) {ps : List Bool} {vs₁ vs₂ : List (Except Fault Val)}
    (hvs : ∀ j, ps.getD j false = false → vs₁[j]? = vs₂[j]?) {x : SVal}
    (hx : x.pay lab V₁.fn ps = false) : x.eval V₁ vs₁ = x.eval V₂ vs₂ := by
  cases x with
  | reg r => simp only [SVal.eval, h.regs r hx]
  | int w i => rfl
  | node j => simp only [SVal.eval, hvs j hx]

/-- For every labelling, payload blocks and valuations related at the skeleton, node values equal
at the skeleton roles `ps`, and node `nd` whose role on `ps` is skeleton and which, if a `load`
with a skeleton result register, points outside `pay` under the first, `nd` has one value under
both. -/
theorem SNode.eval_skel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel lab pay V₂) {ps : List Bool} {vs₁ vs₂ : List (Except Fault Val)}
    (hvs : ∀ j, ps.getD j false = false → vs₁[j]? = vs₂[j]?) {nd : SNode}
    (hnd : nd.pay lab V₁.fn ps = false)
    (hl : ∀ lbl pc p q, nd = .load lbl pc p →
      (resReg V₁.fn lbl pc).any (lab.reg V₁.fn.name) = false →
      p.eval V₁ vs₁ = .ok (.ptr q) → ¬ pay q.block) :
    nd.eval V₁ vs₁ = nd.eval V₂ vs₂ := by
  have hst : ∀ lbl pc, V₁.stmt lbl pc = V₂.stmt lbl pc := fun _ _ => by
    simp only [Valuation.stmt, h.fn]
  have hS := h.mem.sameShape fun _ => True
  cases nd with
  | bin op fl w a b =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    simp only [SNode.eval, SVal.eval_skel h hvs hnd.1, SVal.eval_skel h hvs hnd.2]
  | icmp p w a b =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    have hi : ∀ l p t x y, icmpV l V₁.mem p t x y = icmpV l V₂.mem p t x y :=
      fun l p t x y => icmpV_shape hS (Val.namesIn_top x) (Val.namesIn_top y) l p t
    simp only [SNode.eval, SVal.eval_skel h hvs hnd.1, SVal.eval_skel h hvs hnd.2, h.prog, hi]
  | cast op w a =>
    simp only [SNode.pay] at hnd
    simp only [SNode.eval, SVal.eval_skel h hvs hnd]
  | extract is a =>
    simp only [SNode.pay] at hnd
    simp only [SNode.eval, SVal.eval_skel h hvs hnd]
  | call lbl pc =>
    have hw : ∀ l t attrs v, withAttrs l V₁.mem t attrs v = withAttrs l V₂.mem t attrs v :=
      fun l t attrs v => withAttrs_shape hS (Val.namesIn_top v) l t attrs
    simp only [SNode.eval, hst, h.prog, h.env, hw]
  | gep lbl pc base idx =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    have hg : ∀ l fl src a idx x, MojoProof.Sem.gep l V₁.mem fl src a idx x =
        MojoProof.Sem.gep l V₂.mem fl src a idx x :=
      fun l fl src a idx x => gep_shape hS (Val.namesIn_top x) l fl src a idx
    simp only [SNode.eval, hst, h.prog, hg, SVal.eval_skel h hvs hnd.1.1,
      SVal.eval_skel h hvs hnd.1.2]
  | load lbl pc p =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    simp only [SNode.eval, hst, h.prog, h.who, ← SVal.eval_skel h hvs hnd.1]
    split
    · apply Except.Rel.eq
      refine .bind_eq _ fun x hx => .bind_eq _ fun q hq => ?_
      obtain rfl := Val.addr?_eq hq
      have hnp := hl lbl pc p q rfl hnd.2 hx
      refine (Mem.load_skel h.mem (p := q) (fun hq' => absurd hq' hnp) _ _ _ _).bind
        fun v₁ v₂ hv => ?_
      obtain rfl := hv.2 hnp
      exact .refl (fun _ => rfl) _
    · rfl
  | fbin | fbinP => simp [SNode.pay] at hnd
  | flit ft lit => rfl
  | select w c a b =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    simp only [SNode.eval, SVal.eval_skel h hvs hnd.1.1, SVal.eval_skel h hvs hnd.1.2,
      SVal.eval_skel h hvs hnd.2]
  | minmax sg mx a b =>
    simp only [SNode.pay, Bool.or_eq_false_iff] at hnd
    simp only [SNode.eval, SVal.eval_skel h hvs hnd.1, SVal.eval_skel h hvs hnd.2]

/-- **Skeleton nodes have one value in two runs.** For every labelling `lab`, payload blocks
`pay`, table `ns` and valuations related at the skeleton (`Valuation.Skel`) whose skeleton loads
read outside `pay` under the first (`Valuation.LoadsOk`), every node whose role is skeleton has
one value under both (and every number past the table, none). -/
theorem vals_skel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation} (h : V₁.Skel lab pay V₂)
    {ns : List SNode} (hl : V₁.LoadsOk lab pay ns) :
    ∀ j, (roles lab V₁.fn ns).getD j false = false → (vals V₁ ns)[j]? = (vals V₂ ns)[j]? := by
  induction ns using List.reverseRecOn with
  | nil => intro j _; rfl
  | append_singleton ns nd ih =>
    have ih := ih fun j lbl pc p q hj hr hp => by
      have hlt : j < ns.length := by
        by_contra hc
        rw [List.getElem?_eq_none (by omega)] at hj
        cases hj
      exact hl j lbl pc p q (by rw [List.getElem?_append_left hlt]; exact hj) hr
        (by rw [List.take_append_of_le_length hlt.le]; exact hp)
    intro j hj
    rw [roles_snoc, List.getD_eq_getElem?_getD] at hj
    rw [vals_snoc, vals_snoc]
    rcases Nat.lt_trichotomy j ns.length with hlt | rfl | hgt
    · have h₀ : j < (roles lab V₁.fn ns).length := by rw [roles_length]; exact hlt
      have h₁ : j < (vals V₁ ns).length := by rw [vals_length]; exact hlt
      have h₂ : j < (vals V₂ ns).length := by rw [vals_length]; exact hlt
      rw [List.getElem?_append_left h₀] at hj
      rw [List.getElem?_append_left h₁, List.getElem?_append_left h₂]
      exact ih j (by rw [List.getD_eq_getElem?_getD]; exact hj)
    · rw [List.getElem?_append_right (roles_length lab V₁.fn ns).le, roles_length, Nat.sub_self,
        List.getElem?_cons_zero, Option.getD_some] at hj
      rw [List.getElem?_append_right (vals_length V₁ ns).le,
        List.getElem?_append_right (vals_length V₂ ns).le, vals_length, vals_length,
        Nat.sub_self, List.getElem?_cons_zero, List.getElem?_cons_zero]
      refine congrArg some (SNode.eval_skel h ih hj fun lbl pc p q hnd hr hp => ?_)
      exact hl ns.length lbl pc p q (by
          rw [List.getElem?_append_right (Nat.le_refl ns.length), Nat.sub_self, hnd,
            List.getElem?_cons_zero]) hr
        (by rw [List.take_left' rfl]; exact hp)
    · have h₁ : (vals V₁ ns ++ [nd.eval V₁ (vals V₁ ns)]).length ≤ j := by
        simp only [List.length_append, vals_length, List.length_singleton]; omega
      have h₂ : (vals V₂ ns ++ [nd.eval V₂ (vals V₂ ns)]).length ≤ j := by
        simp only [List.length_append, vals_length, List.length_singleton]; omega
      rw [List.getElem?_eq_none h₁, List.getElem?_eq_none h₂]

/-- **An oblivious summary takes one edge and one address per access in two runs.** For every
labelling, payload blocks, summary oblivious under `lab` and valuations related at the skeleton
whose skeleton loads read outside `pay` under the first: the exit goes to one block (or to none)
under both (`Exit.dest`: a branch, a conditional branch, and a branch into blocks with `phi`s),
and each effect's pointer has one value under both. -/
theorem Summary.oblivious_skel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Skel lab pay V₂) {S : Summary} (hS : S.oblivious lab V₁.fn = true)
    (hl : V₁.LoadsOk lab pay S.nodes) :
    Exit.dest V₁ (vals V₁ S.nodes) S.exit = Exit.dest V₂ (vals V₂ S.nodes) S.exit ∧
      ∀ e ∈ S.effs, e.ptr.eval V₁ (vals V₁ S.nodes) = e.ptr.eval V₂ (vals V₂ S.nodes) := by
  have hvs := vals_skel h hl
  simp only [Summary.oblivious, Bool.and_eq_true, List.all_eq_true] at hS
  obtain ⟨⟨hx, he⟩, -⟩ := hS
  refine ⟨?_, fun e hm => SVal.eval_skel h hvs (by simpa [SVal.payloadFree] using he e hm)⟩
  revert hx
  cases S.exit with
  | br d => intro _; rfl
  | cond x d e =>
    intro hx
    show Exit.target V₁ _ (.cond x d e) = Exit.target V₂ _ (.cond x d e)
    simp only [Exit.target, SVal.eval_skel h hvs (by simpa [SVal.payloadFree] using hx)]
  | ret => intro _; rfl
  | phi x d e =>
    intro hx
    simp only [Exit.dest, SVal.eval_skel h hvs (by simpa [SVal.payloadFree] using hx)]

/-! ### To the next block's entry (T3c on terms) -/

/-- **Valuations related at labelling `lab`**, with payload blocks `pay`: one program,
environment, thread, table of globals and function, memories related by `Mem.SkelEq pay`, and
registers and `fmul contract` operands related by `Val.Skel` where `lab` labels payload and equal
where it labels skeleton (as `Frame.Skel`). The step counts, address choices and oracles may
differ. -/
structure Valuation.Rel (lab : Labels) (pay : Nat → Prop) (V₁ V₂ : Valuation) : Prop where
  /-- Builds `Valuation.Rel` from its eight fields. -/
  mk ::
  /-- One program. -/
  prog : V₁.ctx.prog = V₂.ctx.prog
  /-- One environment of special registers. -/
  env : V₁.ctx.env = V₂.ctx.env
  /-- One thread. -/
  who : V₁.ctx.who = V₂.ctx.who
  /-- One table of globals. -/
  globals : V₁.ctx.globals = V₂.ctx.globals
  /-- One function. -/
  fn : V₁.fn = V₂.fn
  /-- Memories related by `Mem.SkelEq pay`. -/
  mem : V₁.mem.SkelEq pay V₂.mem
  /-- Registers related by `Val.Skel` where `lab` labels payload, equal where it labels
  skeleton. -/
  regs : ∀ r, Option.Rel (Labels.Rel (lab.reg V₁.fn.name r) Val.Skel) (V₁.regs r) (V₂.regs r)
  /-- The `fmul contract` operands of each register, related in the same way. -/
  prods : ∀ r, Option.Rel (Labels.Rel (lab.reg V₁.fn.name r) fun a b => a.1.Skel b.1 ∧ a.2.Skel b.2)
    (V₁.prods r) (V₂.prods r)

/-- Valuations related by `Valuation.Rel` are related at the skeleton (`Valuation.Skel`). -/
theorem Valuation.Rel.skel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) : V₁.Skel lab pay V₂ :=
  ⟨h.prog, h.env, h.who, h.fn, h.mem, fun r hr => by
    have := h.regs r
    rw [hr] at this
    exact Labels.Rel.option_eq this⟩

/-- Whether statement `st`, if a `load`, reads a data type (`Ty.data`); `true` for any other
statement. -/
def loadData (st : Stmt) : Bool :=
  match st.inst with
  | .load _ t _ _ => t.data
  | _ => true

/-- **(O3) on a payload node** of function `fn` under `lab`, given the roles `ps` of the nodes
before it: an integer operator is total (`BinOp.total`) and its second operand is skeleton if it
reads its value (`BinOp.skelB`: a shift amount or a divisor); a `getelementptr` and a `load`
have skeleton operands, and a `load`'s statement reads a data type (`loadData`); a float
operation has neither `nnan` nor `ninf`; a `select` has a skeleton condition. Comparisons, casts,
`extractvalue`, calls and integer maxima and minima pass. -/
def SNode.payOk (lab : Labels) (fn : Func) (ps : List Bool) : SNode → Bool
  | .bin op fl _ _ b => op.total fl && (!op.skelB || !b.pay lab fn ps)
  | .gep _ _ a b => !a.pay lab fn ps && !b.pay lab fn ps
  | .load lbl pc p => !p.pay lab fn ps &&
      ((fn.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?)).all loadData
  | .fbin _ fm _ _ _ _ | .fbinP _ fm _ _ _ _ _ _ => !fm.nnan && !fm.ninf
  | .select _ c _ _ => !c.pay lab fn ps
  -- related operands give related values or the same fault (`SNode.eval_rel`)
  | .icmp .. | .cast .. | .extract .. | .minmax .. => true
  -- a special-register call and a float constant have no operand, and their value is the same
  -- in both runs
  | .call .. | .flit .. => true

/-- **(O3) on a summary's table**: each node whose role is payload passes `SNode.payOk` on the
roles of the nodes before it. -/
def Summary.payOk (lab : Labels) (fn : Func) (S : Summary) : Bool :=
  (List.range S.nodes.length).all fun j => (S.nodes[j]?).all fun nd =>
    !nd.pay lab fn (roles lab fn (S.nodes.take j)) ||
      nd.payOk lab fn (roles lab fn (S.nodes.take j))

/-- Under `Summary.payOk`, node `j` passes `SNode.payOk` if its role is payload. -/
theorem Summary.payOk_getElem? {lab : Labels} {fn : Func} {S : Summary}
    (h : S.payOk lab fn = true) (j : Nat) (nd : SNode) (hj : S.nodes[j]? = some nd)
    (hp : nd.pay lab fn (roles lab fn (S.nodes.take j)) = true) :
    nd.payOk lab fn (roles lab fn (S.nodes.take j)) = true := by
  have hlt : j < S.nodes.length := by
    by_contra hc
    rw [List.getElem?_eq_none (by omega)] at hj
    cases hj
  have := List.all_eq_true.1 h j (List.mem_range.2 hlt)
  simp only [hj, Option.all_some, hp, Bool.not_true, Bool.false_or] at this
  exact this

/-- **The payload stores of summary `S` write to `pay`** under `V` (`Labels.MemAt` at a `store`,
on terms): each `store` effect whose value operand is payload, when its pointer has a pointer
value, writes to a block of `pay`. -/
def Valuation.StoresOk (lab : Labels) (pay : Nat → Prop) (V : Valuation) (S : Summary) : Prop :=
  ∀ lbl pc v p q, SEff.store lbl pc v p ∈ S.effs → v.pay lab V.fn (roles lab V.fn S.nodes) = true →
    p.eval V (vals V S.nodes) = .ok (.ptr q) → pay q.block

/-- Options of results related by `Labels.Rel false R` are equal. -/
theorem _root_.MojoProof.Sem.Labels.Rel.except_eq {ε α : Type} {R : α → α → Prop}
    {x y : Option (Except ε α)} (h : Option.Rel (Except.Rel (Labels.Rel false R)) x y) : x = y := by
  cases h with
  | none => rfl
  | some h => exact congrArg some (Except.Rel.eq (h.imp (S := Eq) fun _ _ h => Labels.Rel.eq h))

/-- Results related by `Except.Rel R` give options related by `Option.Rel R`. -/
theorem _root_.Except.Rel.toOption {ε α β : Type} {R : α → β → Prop} {x : Except ε α}
    {y : Except ε β} (h : Except.Rel R x y) : Option.Rel R x.toOption y.toOption := by
  cases h with
  | error e => exact .none
  | ok h => exact .some h

/-- Related results chosen by one condition are related. -/
theorem _root_.Except.Rel.cond {ε α β : Type} {R : α → β → Prop} (c : Bool)
    {a₁ b₁ : Except ε α} {a₂ b₂ : Except ε β} (h₁ : Except.Rel R a₁ a₂)
    (h₂ : Except.Rel R b₁ b₂) : Except.Rel R (bif c then a₁ else b₁) (bif c then a₂ else b₂) := by
  cases c
  · exact h₂
  · exact h₁

/-- Under `Summary.agrees`, a register that holds payload at the block's end
(`Summary.endPay`) is labelled payload. -/
theorem Summary.agrees_end {lab : Labels} {fn : Func} {S : Summary} (h : S.agrees lab fn = true)
    {r : Nat} : S.endPay lab fn r = true → lab.reg fn.name r = true := by
  unfold Summary.endPay
  cases hx : S.regs.lookup r with
  | none => exact id
  | some x =>
    intro hp
    simp only [Option.getD_some] at hp
    obtain ⟨l₁, l₂, hl, -⟩ := List.lookup_eq_some_iff.1 hx
    have := List.all_eq_true.1 h (r, x) (by rw [hl]; simp)
    simpa [hp] using this

/-- The target of a branch into blocks with `phi`s is one of its two blocks. -/
theorem Exit.dest_phi {V : Valuation} {vs : List (Except Fault Val)} {c : SVal} {d₀ e₀ d : Nat}
    (h : Exit.dest V vs (.phi c d₀ e₀) = some d) : d = d₀ ∨ d = e₀ := by
  simp only [Exit.dest] at h
  split at h
  · cases h
    split
    · exact .inl rfl
    · exact .inr rfl
  · cases h

/-- For every labelling, payload blocks and valuations related by `Valuation.Rel`, and node
values related at the roles `ps` (`Val.Skel` at a payload role, equal at a skeleton one), every
operand has related values under both, at its role. -/
theorem SVal.eval_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {ps : List Bool} {vs₁ vs₂ : List (Except Fault Val)}
    (hvs : ∀ j, Option.Rel (Except.Rel (Labels.Rel (ps.getD j false) Val.Skel)) vs₁[j]? vs₂[j]?)
    (x : SVal) :
    Except.Rel (Labels.Rel (x.pay lab V₁.fn ps) Val.Skel) (x.eval V₁ vs₁) (x.eval V₂ vs₂) := by
  cases x with
  | reg r =>
    have hr := h.regs r
    simp only [SVal.eval, SVal.pay]
    generalize V₁.regs r = a at hr ⊢
    generalize V₂.regs r = b at hr ⊢
    cases hr with
    | none => exact .error _
    | some hr => exact .ok hr
  | int w i => exact Except.Rel.refl (Labels.Rel.refl Val.Skel.refl _) _
  | node j =>
    have hj := hvs j
    simp only [SVal.eval, SVal.pay]
    generalize vs₁[j]? = a at hj ⊢
    generalize vs₂[j]? = b at hj ⊢
    cases hj with
    | none => exact .error _
    | some hj => exact hj

/-- For every labelling, payload blocks and valuations related by `Valuation.Rel`, node values
related at the roles `ps`, and node `nd` that passes (O3) (`SNode.payOk`) if its role is payload
and which, if a `load` with a skeleton result register, points outside `pay` under the first,
`nd` has related values under both, at its role (`Val.Skel` if payload, equal if skeleton). -/
theorem SNode.eval_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {ps : List Bool} {vs₁ vs₂ : List (Except Fault Val)}
    (hvs : ∀ j, Option.Rel (Except.Rel (Labels.Rel (ps.getD j false) Val.Skel)) vs₁[j]? vs₂[j]?)
    {nd : SNode} (hok : nd.pay lab V₁.fn ps = true → nd.payOk lab V₁.fn ps = true)
    (hl : ∀ lbl pc p q, nd = .load lbl pc p →
      (resReg V₁.fn lbl pc).any (lab.reg V₁.fn.name) = false →
      p.eval V₁ vs₁ = .ok (.ptr q) → ¬ pay q.block) :
    Except.Rel (Labels.Rel (nd.pay lab V₁.fn ps) Val.Skel) (nd.eval V₁ vs₁) (nd.eval V₂ vs₂) := by
  have heq : ∀ j, ps.getD j false = false → vs₁[j]? = vs₂[j]? := fun j hj => by
    have := hvs j
    rw [hj] at this
    exact Labels.Rel.except_eq this
  cases hp : nd.pay lab V₁.fn ps
  · rw [SNode.eval_skel h.skel heq hp hl]
    exact Except.Rel.refl (Labels.Rel.refl Val.Skel.refl false) _
  have hok := hok hp
  refine Except.Rel.imp (R := Val.Skel) (fun _ _ h => Labels.Rel.of_rel rfl h) ?_
  have hst : ∀ lbl pc, V₁.stmt lbl pc = V₂.stmt lbl pc := fun _ _ => by
    simp only [Valuation.stmt, h.fn]
  have hto : ∀ x : SVal, Except.Rel Val.Skel (x.eval V₁ vs₁) (x.eval V₂ vs₂) := fun x =>
    (SVal.eval_rel h hvs x).imp fun _ _ => Labels.Rel.to Val.Skel.refl
  have hS := h.mem.sameShape fun _ => True
  cases nd with
  | bin op fl w a b =>
    simp only [SNode.payOk, Bool.and_eq_true, Bool.or_eq_true, Bool.not_eq_true'] at hok
    simp only [SNode.eval]
    refine (hto a).bind fun x₁ x₂ hx => (SVal.eval_rel h hvs b).bind fun y₁ y₂ hy => ?_
    refine lanes2_skel (P := op.skelB = true)
      (fun _ _ _ _ _ hx hy hP => intBin_skel w hok.1 hx hy hP) hx
      (Labels.Rel.to Val.Skel.refl hy) fun hb => ?_
    rcases hok.2 with h1 | h1
    · rw [h1] at hb; cases hb
    · rw [h1] at hy; exact Labels.Rel.eq hy
  | icmp p w a b =>
    simp only [SNode.eval, h.prog]
    exact (hto a).bind fun _ _ hx => (hto b).bind fun _ _ hy => icmpV_skel h.mem _ p _ hx hy
  | cast op w a =>
    simp only [SNode.eval]
    exact (hto a).bind fun _ _ hx => lanes_skel (fun _ _ _ h => intCast_skel op w h) hx
  | extract is a =>
    simp only [SNode.eval]
    exact (hto a).bind fun _ _ hx => extractV_skel is hx
  | call lbl pc =>
    have hw : ∀ l t attrs v, withAttrs l V₁.mem t attrs v = withAttrs l V₂.mem t attrs v :=
      fun l t attrs v => withAttrs_shape hS (Val.namesIn_top v) l t attrs
    simp only [SNode.eval, hst, h.prog, h.env, hw]
    exact Except.Rel.refl Val.Skel.refl _
  | gep lbl pc base idx =>
    simp only [SNode.payOk, Bool.and_eq_true, Bool.not_eq_true'] at hok
    have hg : ∀ l fl src a idx x, MojoProof.Sem.gep l V₁.mem fl src a idx x =
        MojoProof.Sem.gep l V₂.mem fl src a idx x :=
      fun l fl src a idx x => gep_shape hS (Val.namesIn_top x) l fl src a idx
    simp only [SNode.eval, hst, h.prog, hg, SVal.eval_skel h.skel heq hok.1,
      SVal.eval_skel h.skel heq hok.2]
    exact Except.Rel.refl Val.Skel.refl _
  | load lbl pc p =>
    simp only [SNode.payOk, Bool.and_eq_true, Bool.not_eq_true'] at hok
    obtain ⟨hpp, hd⟩ := hok
    have hd' : (V₂.stmt lbl pc).all loadData = true := by rw [← hst]; exact hd
    simp only [SNode.eval, hst, h.prog, h.who, ← SVal.eval_skel h.skel heq hpp]
    generalize V₂.stmt lbl pc = o at hd' ⊢
    rcases o with _ | ⟨res, inst, md⟩
    · exact .error _
    cases inst
    case load vol t ptr al =>
      obtain ⟨pt, pv⟩ := ptr
      cases pt
      case ptr a =>
        have ht : t.data = true := hd'
        dsimp only
        refine .bind_eq _ fun x _ => .bind_eq _ fun q hq => ?_
        obtain rfl := Val.addr?_eq hq
        refine (Mem.load_skel h.mem (p := q) (fun _ => ht) _ _ _ _).bind fun v₁ v₂ hv => ?_
        rw [Val.Skel.defined hv.1]
        exact Except.Rel.cond _ (.error _) (.ok hv.1)
      all_goals exact .error _
    all_goals exact .error _
  | fbin op fm ft n a b | fbinP op fm ft n a b =>
    simp only [SNode.payOk, Bool.and_eq_true, Bool.not_eq_true'] at hok
    simp only [SNode.eval]
    exact (hto a).bind fun _ _ hx => (hto b).bind fun _ _ hy =>
      lanes2_skel (P := False) (fun _ _ _ _ _ hx hy _ =>
        floatBin_skel ft op hok.1 hok.2 hx hy _ _ _ _ _ _) hx hy False.elim
  | select w c a b =>
    simp only [SNode.payOk, Bool.not_eq_true'] at hok
    simp only [SNode.eval, SVal.eval_skel h.skel heq hok]
    exact .bind_eq _ fun x _ => (hto a).bind fun _ _ hy => (hto b).bind fun _ _ hz =>
      selectV_skel _ x hy hz
  | minmax sg mx a b =>
    simp only [SNode.eval]
    exact (hto a).bind fun _ _ hx => (hto b).bind fun _ _ hy => intMinMax_skel sg mx hx hy
  | flit ft lit =>
    simp only [SNode.eval]
    exact Except.Rel.refl Val.Skel.refl _

/-- **Every node has related values in two runs.** For every labelling `lab`, payload blocks
`pay`, table `ns` and valuations related by `Valuation.Rel` whose skeleton loads read outside
`pay` under the first (`Valuation.LoadsOk`), and whose payload nodes pass (O3)
(`SNode.payOk`), every node has related values under both at its role: equal if skeleton
(`vals_skel`), related by `Val.Skel` if payload (and every number past the table, none). -/
theorem vals_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation} (h : V₁.Rel lab pay V₂)
    {ns : List SNode} (hl : V₁.LoadsOk lab pay ns)
    (ho : ∀ (j : Nat) (nd : SNode), ns[j]? = some nd →
      nd.pay lab V₁.fn (roles lab V₁.fn (ns.take j)) = true →
      nd.payOk lab V₁.fn (roles lab V₁.fn (ns.take j)) = true) :
    ∀ j, Option.Rel (Except.Rel (Labels.Rel ((roles lab V₁.fn ns).getD j false) Val.Skel))
      (vals V₁ ns)[j]? (vals V₂ ns)[j]? := by
  induction ns using List.reverseRecOn with
  | nil =>
    intro j
    rw [show vals V₁ [] = [] from rfl, show vals V₂ [] = [] from rfl, List.getElem?_nil]
    exact .none
  | append_singleton ns nd ih =>
    have hlt' : ∀ {j : Nat} {x : SNode}, ns[j]? = some x → j < ns.length := fun {j x} hj => by
      by_contra hc
      rw [List.getElem?_eq_none (by omega)] at hj
      cases hj
    have ih := ih (fun j lbl pc p q hj hr hp => by
        have hlt := hlt' hj
        exact hl j lbl pc p q (by rw [List.getElem?_append_left hlt]; exact hj) hr
          (by rw [List.take_append_of_le_length hlt.le]; exact hp))
      (fun j nd' hj hp => by
        have hlt := hlt' hj
        have := ho j nd' (by rw [List.getElem?_append_left hlt]; exact hj)
          (by rw [List.take_append_of_le_length hlt.le]; exact hp)
        rw [List.take_append_of_le_length hlt.le] at this
        exact this)
    intro j
    rw [roles_snoc, vals_snoc, vals_snoc, List.getD_eq_getElem?_getD]
    rcases Nat.lt_trichotomy j ns.length with hlt | rfl | hgt
    · have h₀ : j < (roles lab V₁.fn ns).length := by rw [roles_length]; exact hlt
      have h₁ : j < (vals V₁ ns).length := by rw [vals_length]; exact hlt
      have h₂ : j < (vals V₂ ns).length := by rw [vals_length]; exact hlt
      rw [List.getElem?_append_left h₀, List.getElem?_append_left h₁,
        List.getElem?_append_left h₂]
      have := ih j
      rw [List.getD_eq_getElem?_getD] at this
      exact this
    · rw [List.getElem?_append_right (roles_length lab V₁.fn ns).le, roles_length, Nat.sub_self,
        List.getElem?_cons_zero, Option.getD_some]
      rw [List.getElem?_append_right (vals_length V₁ ns).le,
        List.getElem?_append_right (vals_length V₂ ns).le, vals_length, vals_length,
        Nat.sub_self, List.getElem?_cons_zero, List.getElem?_cons_zero]
      have hnd : (ns ++ [nd])[ns.length]? = some nd := by
        rw [List.getElem?_append_right (Nat.le_refl ns.length), Nat.sub_self,
          List.getElem?_cons_zero]
      refine .some (SNode.eval_rel h ih (fun hp => ?_) fun lbl pc p q hnd' hr hp => ?_)
      · have := ho ns.length nd hnd (by rw [List.take_left' rfl]; exact hp)
        rw [List.take_left' rfl] at this
        exact this
      · exact hl ns.length lbl pc p q (by rw [hnd, hnd']) hr
          (by rw [List.take_left' rfl]; exact hp)
    · have h₁ : (vals V₁ ns ++ [nd.eval V₁ (vals V₁ ns)]).length ≤ j := by
        simp only [List.length_append, vals_length, List.length_singleton]; omega
      have h₂ : (vals V₂ ns ++ [nd.eval V₂ (vals V₂ ns)]).length ≤ j := by
        simp only [List.length_append, vals_length, List.length_singleton]; omega
      rw [List.getElem?_eq_none h₁, List.getElem?_eq_none h₂]
      exact .none

/-- **The effects make related memories.** For every labelling, payload blocks, valuations related
by `Valuation.Rel`, node values related at the roles `ps`, and effects each of whose pointers has
one value under both and each of whose payload stores writes to a block of `pay` under the
first: running them gives one fault or memories related by `Mem.SkelEq pay`. -/
theorem SEff.run_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {ps : List Bool} {vs₁ vs₂ : List (Except Fault Val)}
    (hvs : ∀ j, Option.Rel (Except.Rel (Labels.Rel (ps.getD j false) Val.Skel)) vs₁[j]? vs₂[j]?)
    {es : List SEff} (hp : ∀ e ∈ es, e.ptr.eval V₁ vs₁ = e.ptr.eval V₂ vs₂)
    (hs : ∀ lbl pc v p q, SEff.store lbl pc v p ∈ es → v.pay lab V₁.fn ps = true →
      p.eval V₁ vs₁ = .ok (.ptr q) → pay q.block) :
    Except.Rel (Mem.SkelEq pay) (SEff.run V₁ vs₁ es) (SEff.run V₂ vs₂ es) := by
  have hst : ∀ lbl pc, V₁.stmt lbl pc = V₂.stmt lbl pc := fun _ _ => by
    simp only [Valuation.stmt, h.fn]
  unfold SEff.run
  refine Except.Rel.foldlM (fun e he m₁ m₂ hm => ?_) h.mem
  have hpe := hp e he
  cases e with
  | load lbl pc p =>
    simp only [SEff.ptr] at hpe
    simp only [SEff.apply, hst, h.prog, h.who, hpe]
    split
    · exact .bind_eq _ fun _ _ => .bind_eq _ fun _ _ => .ok (Mem.log_skel hm _)
    · exact .error _
  | store lbl pc v p =>
    simp only [SEff.ptr] at hpe
    simp only [SEff.apply, hst, h.prog, h.who, hpe]
    split
    · refine (SVal.eval_rel h hvs v).bind fun x₁ x₂ hx => ?_
      refine .bind_eq _ fun y hy => .bind_eq _ fun q hq => ?_
      obtain rfl := Val.addr?_eq hq
      refine Mem.store_skel hm (Labels.Rel.to Val.Skel.refl hx) (fun hnp => ?_) _ _ _ _ _ _
      cases hpv : v.pay lab V₁.fn ps
      · rw [hpv] at hx; exact Labels.Rel.eq hx
      · exact absurd (hs lbl pc v p _ he hpv (hpe.trans hy)) hnp
    · exact .error _

/-- For every labelling, payload blocks, valuations related by `Valuation.Rel` and summary whose
node values are related at their roles, each register's value after the block is related under
both at whether it holds payload at the block's end (`Summary.endPay`). -/
theorem Valuation.after_regs {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {S : Summary}
    (hvs : ∀ j, Option.Rel (Except.Rel (Labels.Rel ((roles lab V₁.fn S.nodes).getD j false)
      Val.Skel)) (vals V₁ S.nodes)[j]? (vals V₂ S.nodes)[j]?) (r : Nat) :
    Option.Rel (Labels.Rel (S.endPay lab V₁.fn r) Val.Skel) ((V₁.after S).regs r)
      ((V₂.after S).regs r) := by
  show Option.Rel _ (regVal V₁ (vals V₁ S.nodes) S.regs r) (regVal V₂ (vals V₂ S.nodes) S.regs r)
  unfold regVal Summary.endPay
  cases S.regs.lookup r with
  | none => exact h.regs r
  | some x => exact (SVal.eval_rel h hvs x).toOption

/-- **Related valuations after a block.** For every labelling `lab`, payload blocks `pay`,
valuations related by `Valuation.Rel`, and summary that is oblivious (`Summary.oblivious`), agrees
with `lab` (`Summary.agrees`) and passes (O3) (`Summary.payOk`), whose skeleton loads read outside
`pay` and whose payload stores write to `pay` under the first (`Valuation.LoadsOk`,
`Valuation.StoresOk`): the valuations after the block (`Valuation.after`) are related by
`Valuation.Rel`. -/
theorem Valuation.after_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {S : Summary} (hS : S.oblivious lab V₁.fn = true)
    (ha : S.agrees lab V₁.fn = true) (hl : V₁.LoadsOk lab pay S.nodes)
    (ho : S.payOk lab V₁.fn = true) (hs : V₁.StoresOk lab pay S) :
    (V₁.after S).Rel lab pay (V₂.after S) := by
  have hvs := vals_rel h hl (Summary.payOk_getElem? ho)
  refine ⟨h.prog, h.env, h.who, h.globals, h.fn, ?_, fun r => ?_, fun r => ?_⟩
  · exact (SEff.run_rel h hvs (Summary.oblivious_skel h.skel hS hl).2 hs).toOption.getD h.mem
  · exact (Valuation.after_regs h hvs r).imp fun _ _ hx =>
      Labels.Rel.mono Val.Skel.refl (Summary.agrees_end ha) hx
  · show Option.Rel _ (regProd V₁ S.regs r) (regProd V₂ S.regs r)
    unfold regProd
    cases S.regs.lookup r with
    | none => exact h.prods r
    | some _ => exact .none

/-- **The `phi`s of an edge in two runs.** For every labelling, payload blocks, valuations related
by `Valuation.Rel`, summary `S` of block `l` after which they are related and whose registers are
related at whether they hold payload at the block's end (`Summary.endPay`), and block `d` whose
`phi`s agree with the labelling on the edge (`Summary.phiAgrees`): entering `d` from the frames
at the block's end (`Valuation.frameAt`, as `Valuation.into` does) gives one fault or frames
related by `Frame.Skel`. -/
theorem enter_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation} (h : V₁.Rel lab pay V₂)
    {S : Summary} (hA : (V₁.after S).Rel lab pay (V₂.after S))
    (hr : ∀ n, Option.Rel (Labels.Rel (S.endPay lab V₁.fn n) Val.Skel) ((V₁.after S).regs n)
      ((V₂.after S).regs n)) {l d : Nat} (hp : S.phiAgrees lab V₁.fn l d = true) :
    Except.Rel (Frame.Skel lab)
      (enter (V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len)) (V₁.frameAt l S) d)
      (enter (V₂.ctx.scope (V₂.after S).mem (V₂.frameAt l S) (V₂.k + S.len))
        (V₂.frameAt l S) d) := by
  unfold Summary.phiAgrees at hp
  have hsc : V₂.ctx.scope (V₂.after S).mem (V₂.frameAt l S) (V₂.k + S.len) =
      { V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len) with
        mem := (V₂.after S).mem, regs := (V₂.frameAt l S).regs,
        ch := fun i => V₂.ctx.oracle (Nat.pair (V₂.k + S.len) i) } := by
    simp only [Ctx.scope, h.prog, h.globals]
  have hsk : ∀ t v, v.mentions (S.endPay lab V₁.fn) = false →
      evalV (V₂.ctx.scope (V₂.after S).mem (V₂.frameAt l S) (V₂.k + S.len)) t v =
        evalV (V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len)) t v := by
    rw [hsc]
    exact (evalV_skel (s := V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len))
      (m := (V₂.after S).mem) (r := (V₂.frameAt l S).regs)
      (ch := fun i => V₂.ctx.oracle (Nat.pair (V₂.k + S.len) i)) (p := S.endPay lab V₁.fn)
      hA.mem fun n hn => (Labels.Rel.option_eq (hn ▸ hr n)).symm).1
  have hf : Frame.Skel lab (V₁.frameAt l S) (V₂.frameAt l S) :=
    ⟨by simp only [Valuation.frameAt, h.fn], hA.regs, hA.prods⟩
  have e1 : (V₂.frameAt l S).fn = V₁.fn := h.fn.symm
  have e1' : (V₁.frameAt l S).fn = V₁.fn := rfl
  have e2 : (V₁.frameAt l S).label = l := rfl
  have e2' : (V₂.frameAt l S).label = l := rfl
  unfold enter
  rw [e1, e1', e2, e2']
  generalize hB : Array.find? (fun x => x.label == d) V₁.fn.blocks = B
  cases B with
  | none => exact .error _
  | some b =>
    dsimp only
    generalize hP : List.takeWhile (fun x => match x.inst with
      | Inst.phi .. => true
      | _ => false) b.stmts.toList = phis
    have hmem : ∀ st ∈ phis, st ∈ phisAt V₁.fn d := fun st hst => by
      simp only [phisAt, hB]
      rw [← hP] at hst
      exact hst
    refine Except.Rel.bind_ok (Except.Rel.mapIdx
      (R := fun j a b => a = b ∧ phis[j]? = some a)
      (S := fun j v₁ v₂ => ∀ st, phis[j]? = some st →
        Labels.Rel (st.res.any (lab.reg V₁.fn.name)) Val.Skel v₁ v₂) ?_ (List.rel_self phis))
      fun vs₁ vs₂ _ hvs => .ok ((Frame.Skel.setAll (List.forall₂_of_rel fun j =>
        (List.rel_zip (List.rel_self phis) hvs j).imp fun _ _ h => ⟨h.1.1, h.2 _ h.1.2⟩)
        hf rfl).goto d phis.length)
    rintro j a _ ⟨rfl, ha⟩
    have hpa := List.all_eq_true.1 hp a (hmem a (List.mem_of_getElem? ha))
    refine (Except.Rel.refl (R := Eq) (fun _ => rfl) a.checkMd).bind fun _ _ _ => ?_
    obtain ⟨res, inst, md⟩ := a
    cases inst
    case phi t inc =>
      dsimp only at hpa ⊢
      cases hi : List.find? (fun x => x.2 == l) inc with
      | none => exact .error _
      | some x =>
        obtain ⟨v, l'⟩ := x
        dsimp only
        simp only [hi] at hpa
        refine Except.Rel.imp (R := Labels.Rel (res.any (lab.reg V₁.fn.name)) Val.Skel)
          (fun _ _ h st hs => by rw [ha] at hs; cases hs; exact h) ?_
        cases hm : v.mentions (S.endPay lab V₁.fn)
        · rw [hsk t v hm]
          exact .refl (Labels.Rel.refl Val.Skel.refl _) _
        · simp only [hm, Bool.not_true, Bool.false_or, Bool.and_eq_true] at hpa
          rw [hsc]
          exact (evalV_pay (s := V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len))
            (m := (V₂.after S).mem) (r := (V₂.frameAt l S).regs)
            (ch := fun i => V₂.ctx.oracle (Nat.pair (V₂.k + S.len) i))
            (p := S.endPay lab V₁.fn) hA.mem hr t hpa.2).imp
            fun _ _ h => Labels.Rel.of_rel hpa.1 h
    all_goals exact .error _

/-- **Related valuations at the next block's entry** (T3c on terms). For every labelling `lab`,
payload blocks `pay`, valuations related by `Valuation.Rel`, and summary `S` of block `l` that is
oblivious (`Summary.oblivious`), agrees with `lab` on its exit's edges (`Summary.agreesI`: the
registers it sets and the `phi`s of each target) and passes (O3) (`Summary.payOk`), whose
skeleton loads read outside `pay` and whose payload stores write to `pay` under the first: the
valuations at the entry of the block its exit goes to (`Valuation.into`, with the target's `phi`s
set for a branch into blocks with `phi`s) are related by `Valuation.Rel`. -/
theorem Valuation.into_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {l : Nat} {S : Summary} (hS : S.oblivious lab V₁.fn = true)
    (ha : S.agreesI lab V₁.fn l = true) (hl : V₁.LoadsOk lab pay S.nodes)
    (ho : S.payOk lab V₁.fn = true) (hs : V₁.StoresOk lab pay S) :
    (V₁.into l S).Rel lab pay (V₂.into l S) := by
  simp only [Summary.agreesI, Bool.and_eq_true] at ha
  obtain ⟨ha1, ha2⟩ := ha
  have hA := Valuation.after_rel h hS ha1 hl ho hs
  have hvs := vals_rel h hl (Summary.payOk_getElem? ho)
  have hr := Valuation.after_regs h hvs
  have hd := (Summary.oblivious_skel h.skel hS hl).1
  unfold Valuation.into
  rw [← hd]
  cases hx : S.exit with
  | br d => exact hA
  | cond c d e => exact hA
  | ret => exact hA
  | phi c d₀ e₀ =>
    rw [hx] at ha2
    simp only [Bool.and_eq_true] at ha2
    cases hdest : Exit.dest V₁ (vals V₁ S.nodes) (.phi c d₀ e₀) with
    | none => exact hA
    | some d =>
      dsimp only
      have hpd : S.phiAgrees lab V₁.fn l d = true := by
        rcases Exit.dest_phi hdest with rfl | rfl
        · exact ha2.1
        · exact ha2.2
      have hE := enter_rel h hA hr hpd
      generalize he₁ : enter (V₁.ctx.scope (V₁.after S).mem (V₁.frameAt l S) (V₁.k + S.len))
        (V₁.frameAt l S) d = q₁ at hE ⊢
      generalize enter (V₂.ctx.scope (V₂.after S).mem (V₂.frameAt l S) (V₂.k + S.len))
        (V₂.frameAt l S) d = q₂ at hE ⊢
      cases hE with
      | error e => exact hA
      | @ok f₁ f₂ hf =>
        have hfn := (enter_fields he₁).1
        refine ⟨h.prog, h.env, h.who, h.globals, h.fn, hA.mem, fun r => ?_, fun r => ?_⟩
        · have := hf.regs r
          rw [hfn] at this
          exact this
        · have := hf.prods r
          rw [hfn] at this
          exact this

/-- For every labelling, payload blocks, valuation and summary none of whose `store` effects has
a payload value operand (at the roles of its nodes), `Valuation.StoresOk` holds. -/
theorem Valuation.storesOk_of_skel {lab : Labels} {pay : Nat → Prop} {V : Valuation}
    {S : Summary} (h : S.effs.all (fun
      | .store _ _ v _ => !v.pay lab V.fn (roles lab V.fn S.nodes)
      | _ => true) = true) : V.StoresOk lab pay S := by
  intro lbl pc v p q he hv _
  have := List.all_eq_true.1 h _ he
  simp [hv] at this

/-- Whether pointer operand `p` has its base in registers `rs`, given node table `ns`: an entry
register of `rs`, or a node of `ns` that is a `getelementptr` on one. A `Bool`, evaluated by the
kernel. -/
def SVal.baseIn (ns : List SNode) (rs : List Nat) : SVal → Bool
  | .reg r => r ∈ rs
  | .node j => match ns[j]? with
    | some (.gep _ _ (.reg r) _) => r ∈ rs
    -- a `getelementptr` on a node or a constant, or another node: no base register to check
    | some (.gep _ _ (.int ..) _) | some (.gep _ _ (.node _) _) => false
    | some (.bin ..) | some (.icmp ..) | some (.cast ..) | some (.extract ..) | some (.call ..)
    | some (.load ..) | some (.fbin ..) | some (.select ..) | some (.minmax ..) | some (.fbinP ..)
    | some (.flit ..) | none => false
  | .int .. => false

/-- **A pointer from its base register.** For every set of blocks `B`, valuation `V`, table
`ns`, registers `rs` whose values under `V` name only blocks of `B` (`Val.NamesIn`) and operand
`p` with its base in `rs` (`SVal.baseIn`): if `p` has a pointer value on `ns`'s node values, it
points to a block of `B` (a `getelementptr` keeps its base's block, `gep_namesIn`). -/
theorem SVal.eval_baseIn {B : Nat → Prop} {V : Valuation} {ns : List SNode} {rs : List Nat}
    (hr : ∀ r ∈ rs, ∀ v, V.regs r = some v → v.NamesIn B) {p : SVal}
    (hp : p.baseIn ns rs = true) {q : Ptr} (he : p.eval V (vals V ns) = .ok (.ptr q)) :
    B q.block := by
  cases p with
  | reg r =>
    simp only [SVal.baseIn, decide_eq_true_eq] at hp
    cases hv : V.regs r with
    | none => simp [SVal.eval, hv, throw, throwThe, MonadExceptOf.throw] at he
    | some v =>
      simp only [SVal.eval, hv, pure, Except.pure, Except.ok.injEq] at he
      subst he
      simpa only [Val.NamesIn] using hr r hp _ hv
  | int w i => cases hp
  | node j =>
    simp only [SVal.baseIn] at hp
    split at hp
    · rename_i lbl pc r idx hj
      simp only [decide_eq_true_eq] at hp
      simp only [SVal.eval] at he
      rw [vals_getElem?, hj, Option.map_some, Option.getD_some] at he
      simp only [SNode.eval] at he
      split at he
      · obtain ⟨i, -, hg⟩ := MojoProof.Sem.Except.bind_eq_ok.1 he
        cases hv : V.regs r with
        | none =>
          simp [SVal.eval, hv, bind, Except.bind, throw, throwThe, MonadExceptOf.throw] at hg
        | some v =>
          simp only [SVal.eval, hv, bind, Except.bind, pure, Except.pure] at hg
          simpa only [Val.NamesIn] using gep_namesIn (hr r hp v hv) hg
      · simp [throw, throwThe, MonadExceptOf.throw] at he
    all_goals cases hp

/-- For every labelling, payload blocks, valuation `V`, table `ns` and registers `rs` whose values
under `V` name no block of `pay`: if each `load` node of `ns` whose statement's result register is
not labelled payload has its pointer's base in `rs` (`SVal.baseIn`, on the nodes before it),
`Valuation.LoadsOk` holds. -/
theorem Valuation.loadsOk_of_regs {lab : Labels} {pay : Nat → Prop} {V : Valuation}
    {ns : List SNode} (rs : List Nat)
    (h : (List.range ns.length).all (fun j => match ns[j]? with
      | some (.load lbl pc p) =>
        (resReg V.fn lbl pc).any (lab.reg V.fn.name) || p.baseIn (ns.take j) rs
      | _ => true) = true)
    (hr : ∀ r ∈ rs, ∀ v, V.regs r = some v → v.NamesIn fun b => ¬ pay b) :
    V.LoadsOk lab pay ns := by
  intro j lbl pc p q hj hres hp
  have hlt : j < ns.length := by
    by_contra hc
    rw [List.getElem?_eq_none (by omega)] at hj
    cases hj
  have := List.all_eq_true.1 h j (List.mem_range.2 hlt)
  simp only [hj, hres, Bool.false_or] at this
  exact SVal.eval_baseIn hr this hp

/-- For every labelling, payload blocks, valuation `V`, summary `S` and registers `rs` whose
values under `V` name only blocks of `pay`: if each `store` effect of `S` whose value operand is
payload (at the roles of its nodes) has its pointer's base in `rs` (`SVal.baseIn`),
`Valuation.StoresOk` holds. -/
theorem Valuation.storesOk_of_regs {lab : Labels} {pay : Nat → Prop} {V : Valuation}
    {S : Summary} (rs : List Nat) (h : S.effs.all (fun
      | .store _ _ v p => !v.pay lab V.fn (roles lab V.fn S.nodes) || p.baseIn S.nodes rs
      | _ => true) = true)
    (hr : ∀ r ∈ rs, ∀ v, V.regs r = some v → v.NamesIn pay) : V.StoresOk lab pay S := by
  intro lbl pc v p q he hv hp
  have := List.all_eq_true.1 h _ he
  simp only [hv, Bool.not_true, Bool.false_or] at this
  exact SVal.eval_baseIn hr this hp

/-- The checks of two runs along the path `(l, S) :: ps` of function `fn` on its summaries:
each block's summary is oblivious, agrees with `lab` on its exit's edges and passes (O3)
(`Summary.oblivious`, `Summary.agreesI`, `Summary.payOk`). A `Bool`, evaluated by the kernel. -/
def pathOk (lab : Labels) (fn : Func) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Bool
  | [] => S.oblivious lab fn && S.agreesI lab fn l && S.payOk lab fn
  | (l', _, S') :: ps =>
    S.oblivious lab fn && S.agreesI lab fn l && S.payOk lab fn && pathOk lab fn l' S' ps

/-- The memory premises of two runs along the path `(l, S) :: ps` from valuation `V` at its
first block's entry, under that run: at each block's entry valuation (`Valuation.into` of the
block before), its skeleton loads read outside `pay` and its payload stores write to `pay`
(`Valuation.LoadsOk`, `Valuation.StoresOk`). -/
def Valuation.PathMem (lab : Labels) (pay : Nat → Prop) (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Prop
  | [] => V.LoadsOk lab pay S.nodes ∧ V.StoresOk lab pay S
  | (l', _, S') :: ps =>
    (V.LoadsOk lab pay S.nodes ∧ V.StoresOk lab pay S) ∧ (V.into l S).PathMem lab pay l' S' ps

/-- **Two runs along a path** (T3c along a path). For every labelling `lab`, payload blocks
`pay`, function `fn`, path `(l, S) :: ps` whose summaries pass `pathOk`, and valuations of `fn`
related by `Valuation.Rel` at its first block's entry meeting `Valuation.PathMem` under the
first: the entry valuations of the path's last block (`Valuation.lastI`, which applies
`Valuation.into` block by block) are related, the last block is one under both, and so are the
valuations after it (`Valuation.after`). -/
theorem Valuation.lastI_rel {lab : Labels} {pay : Nat → Prop} {fn : Func} :
    ∀ (ps : List (Nat × List Cond × Summary)) {V₁ V₂ : Valuation} {l : Nat} {S : Summary},
    V₁.Rel lab pay V₂ → V₁.fn = fn → pathOk lab fn l S ps = true → V₁.PathMem lab pay l S ps →
    (V₁.lastI l S ps).1.Rel lab pay (V₂.lastI l S ps).1 ∧
      (V₂.lastI l S ps).2 = (V₁.lastI l S ps).2 ∧
      ((V₁.lastI l S ps).1.after (V₁.lastI l S ps).2.2).Rel lab pay
        ((V₂.lastI l S ps).1.after (V₁.lastI l S ps).2.2)
  | [], V₁, V₂, l, S, h, hf, hc, hm => by
    simp only [pathOk, Bool.and_eq_true] at hc
    obtain ⟨⟨hS, ha⟩, ho⟩ := hc
    rw [← hf] at hS ha ho
    have ha' : S.agrees lab V₁.fn = true := by
      simp only [Summary.agreesI, Bool.and_eq_true] at ha
      exact ha.1
    obtain ⟨hl, hs⟩ := hm
    exact ⟨h, rfl, Valuation.after_rel h hS ha' hl ho hs⟩
  | (l', _, S') :: ps, V₁, V₂, l, S, h, hf, hc, hm => by
    simp only [pathOk, Bool.and_eq_true] at hc
    obtain ⟨⟨⟨hS, ha⟩, ho⟩, hc⟩ := hc
    rw [← hf] at hS ha ho
    obtain ⟨⟨hl, hs⟩, hm⟩ := hm
    exact Valuation.lastI_rel ps (Valuation.into_rel h hS ha hl ho hs)
      ((Valuation.into_k V₁ l S).2.1.trans hf) hc hm

/-- Whether obligation `d` runs only effects of summary `S`: a `Cond.mem` each of whose effects is
one of `S`'s; `true` for `Cond.ok` and `Cond.bool`. The obligations `summarize` makes pass it
(their one `Cond.mem` runs `S.effs`). A `Bool`, evaluated by the kernel. -/
def Cond.effsIn (S : Summary) : Cond → Bool
  | .mem es => es.all (· ∈ S.effs)
  | .ok _ | .bool _ => true

/-- **An obligation in two runs.** For every labelling `lab`, payload blocks `pay`, valuations
related by `Valuation.Rel`, summary `S` that is oblivious and passes (O3), whose skeleton loads
read outside `pay` and whose payload stores write to `pay` under the first
(`Valuation.LoadsOk`, `Valuation.StoresOk`), and obligation `d` that runs only effects of `S`
(`Cond.effsIn`): if `d` holds under the first on its node values, it holds under the second on
its node values. -/
theorem Cond.holds_rel {lab : Labels} {pay : Nat → Prop} {V₁ V₂ : Valuation}
    (h : V₁.Rel lab pay V₂) {S : Summary} (hS : S.oblivious lab V₁.fn = true)
    (hl : V₁.LoadsOk lab pay S.nodes) (ho : S.payOk lab V₁.fn = true)
    (hs : V₁.StoresOk lab pay S) {d : Cond} (hd : d.effsIn S = true)
    (h₁ : d.Holds V₁ (vals V₁ S.nodes)) : d.Holds V₂ (vals V₂ S.nodes) := by
  have hvs := vals_rel h hl (Summary.payOk_getElem? ho)
  cases d with
  | ok x =>
    obtain ⟨v, hv⟩ := h₁
    have hx := SVal.eval_rel h hvs x
    rw [hv] at hx
    show ∃ v, x.eval V₂ (vals V₂ S.nodes) = .ok v
    generalize x.eval V₂ (vals V₂ S.nodes) = y at hx ⊢
    cases hx with
    | ok _ => exact ⟨_, rfl⟩
  | bool x =>
    obtain ⟨w, b, hv⟩ := h₁
    have hx := SVal.eval_rel h hvs x
    rw [hv] at hx
    show ∃ w b, x.eval V₂ (vals V₂ S.nodes) = .ok (.bits w b)
    generalize x.eval V₂ (vals V₂ S.nodes) = y at hx ⊢
    cases hx with
    | ok hr =>
      have hr' := Labels.Rel.to Val.Skel.refl hr
      rcases (Val.Skel.scalar hr' w).1 (.inl ⟨b, rfl⟩) with ⟨b', rfl⟩ | rfl | rfl
      · exact ⟨w, b', rfl⟩
      all_goals exact absurd (Val.Skel.defined hr') (by simp [Val.defined])
  | mem es =>
    obtain ⟨m, hm⟩ := h₁
    simp only [Cond.effsIn, List.all_eq_true, decide_eq_true_eq] at hd
    have hr := SEff.run_rel h hvs
      (fun e he => (Summary.oblivious_skel h.skel hS hl).2 e (hd e he))
      (fun lbl pc v p q he hv hp => hs lbl pc v p q (hd _ he) hv hp)
    rw [hm] at hr
    show ∃ m, SEff.run V₂ (vals V₂ S.nodes) es = .ok m
    generalize SEff.run V₂ (vals V₂ S.nodes) es = y at hr ⊢
    cases hr with
    | ok _ => exact ⟨_, rfl⟩

/-- **The second run's premises from the first's**. For every labelling `lab`, payload
blocks `pay`, function `fn`, path `(l, ds, S) :: ps` whose summaries pass `pathOk` and each of
whose blocks' obligations runs only effects of the block's summary (`Cond.effsIn`), and
valuations of `fn` related by `Valuation.Rel` at its first block's entry meeting
`Valuation.PathMem` under the first: if the path's premises hold from the first (`WalkI`), they
hold from the second. Each obligation by `Cond.holds_rel`; each exit by
`Summary.oblivious_skel` (one `Exit.dest` under both); the next block's entry valuations by
`Valuation.into_rel`. -/
theorem WalkI.rel {lab : Labels} {pay : Nat → Prop} {fn : Func} :
    ∀ (ps : List (Nat × List Cond × Summary)) {V₁ V₂ : Valuation} {l : Nat} {ds : List Cond}
    {S : Summary}, V₁.Rel lab pay V₂ → V₁.fn = fn → pathOk lab fn l S ps = true →
    ((l, ds, S) :: ps).all (fun x => x.2.1.all (Cond.effsIn x.2.2)) = true →
    V₁.PathMem lab pay l S ps → WalkI V₁ ((l, ds, S) :: ps) → WalkI V₂ ((l, ds, S) :: ps)
  | [], V₁, V₂, l, ds, S, h, hf, hc, hd, hm, hW => by
    simp only [pathOk, Bool.and_eq_true] at hc
    obtain ⟨⟨hS, -⟩, ho⟩ := hc
    rw [← hf] at hS ho
    have hd' : ds.all (Cond.effsIn S) = true := by
      simpa only [List.all_cons, List.all_nil, Bool.and_true] using hd
    exact fun d hm' => Cond.holds_rel h hS hm.1 ho hm.2 (List.all_eq_true.1 hd' d hm') (hW d hm')
  | (l', ds', S') :: ps, V₁, V₂, l, ds, S, h, hf, hc, hd, hm, hW => by
    simp only [pathOk, Bool.and_eq_true] at hc
    obtain ⟨⟨⟨hS, ha⟩, ho⟩, hc⟩ := hc
    rw [← hf] at hS ha ho
    rw [List.all_cons, Bool.and_eq_true] at hd
    obtain ⟨⟨hl, hs⟩, hm⟩ := hm
    obtain ⟨hW₀, hx, hW⟩ := hW
    refine ⟨fun d hm' => Cond.holds_rel h hS hl ho hs (List.all_eq_true.1 hd.1 d hm') (hW₀ d hm'),
      ?_, WalkI.rel ps (Valuation.into_rel h hS ha hl ho hs)
        ((Valuation.into_k V₁ l S).2.1.trans hf) hc hd.2 hm hW⟩
    rw [← (Summary.oblivious_skel h.skel hS hl).1]
    exact hx

/-- **Two runs of a returning path** (the transfer to the next block's entry, T3c, composed with
`Block.sound_retR`). For every
program, function `fn`, labelling `lab`, payload blocks `pay` and path `(l, ds, S) :: ps` that
the path checker accepts (`coversPathI`), whose summaries pass `pathOk` and each of whose blocks'
obligations runs only effects of the block's summary (`Cond.effsIn`), and every two contexts of
the program and threads of one frame each at block `l`'s position `p0`, on memories `m₁` and
`m₂`, whose frames have one list of `allocas`: if the path's premises hold from the first entry
valuation (`WalkI`), its last block returns, the entry valuations are related by `Valuation.Rel`
and the first meets `Valuation.PathMem`, then both threads run the path to its end (memories
`me₁`, `me₂`) and their next steps return (`.done`), and the two returned memories, `me₁` and
`me₂` with each frame's `allocas` made dead, are related by `Mem.SkelEq pay`. The second run's
premises follow from the first's (`WalkI.rel`). `Valuation.entry` does not read `allocas`, so
`Valuation.Rel` does not relate them: with `[]` against `[b]` on one memory with `b` live, the
returned memories differ in `b`'s liveness (MojoProofTest/Payload.lean's
`allocas_twin`). -/
theorem Block.sound_retI_rel {P : Program} {fn : Func} {lab : Labels} {pay : Nat → Prop}
    {c₁ c₂ : Ctx} (hP : c₁.prog = P) {ps : List (Nat × List Cond × Summary)} {l p0 : Nat}
    {ds : List Cond} {S : Summary} {t₁ t₂ : Thread} {m₁ m₂ : Mem} {f₁ f₂ : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (hk : pathOk lab fn l S ps = true)
    (hd : ((l, ds, S) :: ps).all (fun x => x.2.1.all (Cond.effsIn x.2.2)) = true)
    (ht₁ : t₁.frames = [f₁]) (ht₂ : t₂.frames = [f₂]) (hfn : f₁.fn = fn)
    (hl₁ : f₁.label = l) (hl₂ : f₂.label = l) (hp₁ : f₁.pc = p0) (hp₂ : f₂.pc = p0)
    (ha : f₁.allocas = f₂.allocas)
    (hW₁ : WalkI (Valuation.entry c₁ t₁.k m₁ f₁) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c₁ t₁.k m₁ f₁).lastI l S ps).2.2.exit = .ret)
    (h : (Valuation.entry c₁ t₁.k m₁ f₁).Rel lab pay (Valuation.entry c₂ t₂.k m₂ f₂))
    (hm : (Valuation.entry c₁ t₁.k m₁ f₁).PathMem lab pay l S ps) :
    ∃ fe₁ me₁ fe₂ me₂, Steps c₁ t₁ m₁ ⟨[fe₁], t₁.k + pathLen S ps⟩ me₁ ∧
      Steps c₂ t₂ m₂ ⟨[fe₂], t₂.k + pathLen S ps⟩ me₂ ∧
      step c₁ ⟨[fe₁], t₁.k + pathLen S ps⟩ me₁ =
        .ok (.done (f₁.allocas.foldl (fun m b => m.setLive b false) me₁)) ∧
      step c₂ ⟨[fe₂], t₂.k + pathLen S ps⟩ me₂ =
        .ok (.done (f₂.allocas.foldl (fun m b => m.setLive b false) me₂)) ∧
      (f₁.allocas.foldl (fun m b => m.setLive b false) me₁).SkelEq pay
        (f₂.allocas.foldl (fun m b => m.setLive b false) me₂) := by
  obtain ⟨-, he, hA⟩ := Valuation.lastI_rel ps h hfn hk hm
  obtain ⟨fe₁, me₁, hS₁, hm₁, hst₁⟩ := Block.sound_retR hP hc ht₁ hfn hl₁ hp₁ hW₁ hret
  obtain ⟨fe₂, me₂, hS₂, hm₂, hst₂⟩ := Block.sound_retR (c := c₂) (h.prog.symm.trans hP) hc ht₂
    (h.fn.symm.trans hfn) hl₂ hp₂ (WalkI.rel ps h hfn hk hd hm hW₁) (by rw [he]; exact hret)
  refine ⟨fe₁, me₁, fe₂, me₂, hS₁, hS₂, hst₁, hst₂, ?_⟩
  rw [show ((Valuation.entry c₂ t₂.k m₂ f₂).lastI l S ps).2.2 =
    ((Valuation.entry c₁ t₁.k m₁ f₁).lastI l S ps).2.2 from congrArg Prod.snd he] at hm₂
  have hmem := hA.mem
  simp only [Valuation.after, hm₁, hm₂, Except.toOption, Option.getD] at hmem
  rw [← ha]
  exact Mem.foldl_setLive_skel _ false hmem

end MojoProof.Sym
