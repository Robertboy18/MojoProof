import MojoProof.Sym.Exec

/-!
# The block checker's state, a frame and the memory

The definitions and lemmas that the block checker's soundness (`SState.stmt_sound`,
`Block.soundAt`, MojoProof/Sym/Block.lean) is built from, for every program:

* `Valuation.entry`, the valuation at a frame's entry; `Steps`, steps that continue a thread
  (`Steps.trans`, `Steps.trans_step`); `Exit.next`, the step a summary's exit makes.
* `Rel`, the relation of a symbolic state to a frame and a memory, with the values of the final
  table. The operands' entries evaluate to the operands' values (`SState.op_eval`,
  `SState.ops_eval`, `SState.op_flit`) and refer to the table's nodes (`SState.op_wf`); the node
  a state appends evaluates (`SState.node_ok`). `Rel` holds after a statement that appends nodes
  (`Rel.defP`, `Rel.def`, `Rel.def₂`), after an effect (`Rel.push`, `Rel.store`), after an
  `alloca`'s effect (`Rel.alloca`), and of every frame with the same fields but the position
  (`Rel.frame`).
* The checker's run keeps the obligations and extends the effects, the table and the register
  entries (`SState.stmt_mono`, `SState.run_mono`). With the `alloca` flag off it adds no
  `alloca`'s effect (`SState.stmt_alloca`, `SState.run_alloca`, `summarizeWith_allocates`);
  without `fmul contract` the table has no `fmul contract` node (`SState.stmt_factors`,
  `SState.run_factors`, `summarizeAt_factors`). The summary the checker accepts is the one it
  computes (`coversAt_summary`).
* The terminator's step: an edge whose obligations hold enters its target (`SState.enter_ok`),
  and the exit's step is the terminator's (`SState.exit_sound`, `SState.exitAt_sound`).
* A statement's pointer facts (`PtrIs`, `StoreVal`, `StoreAt`, `StmtPtrs`, `SState.op_storeVal`,
  `SState.def_ptrs`, `SState.def₂_ptrs`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The valuation at the entry of frame `f` in context `c`, at step count `k`, on memory `m`. -/
def Valuation.entry (c : Ctx) (k : Nat) (m : Mem) (f : Frame) : Valuation :=
  ⟨c, f.fn, k, m, f.regs, f.prods⟩

/-- Steps of a thread in context `c` from thread `t` on memory `m` to `t'` on `m'`, each of
which continues the thread. -/
inductive Steps (c : Ctx) : Thread → Mem → Thread → Mem → Prop
  /-- No step. -/
  | refl (t : Thread) (m : Mem) : Steps c t m t m
  /-- A step, then steps. -/
  | cons {t t' t'' : Thread} {m m' m'' : Mem} : step c t m = .ok (.next t' m') →
      Steps c t' m' t'' m'' → Steps c t m t'' m''

/-- Steps, then steps. -/
theorem Steps.trans {c : Ctx} {t t₁ t₂ : Thread} {m m₁ m₂ : Mem} (h₁ : Steps c t m t₁ m₁)
    (h₂ : Steps c t₁ m₁ t₂ m₂) : Steps c t m t₂ m₂ := by
  induction h₁ with
  | refl => exact h₂
  | cons hs _ ih => exact .cons hs (ih h₂)

/-- Steps, a step that continues the thread, then steps. -/
theorem Steps.trans_step {c : Ctx} {t t₁ t₂ t₃ : Thread} {m m₁ m₂ m₃ : Mem}
    (h₁ : Steps c t m t₁ m₁) (h : step c t₁ m₁ = .ok (.next t₂ m₂)) (h₂ : Steps c t₂ m₂ t₃ m₃) :
    Steps c t m t₃ m₃ :=
  h₁.trans (.cons h h₂)

/-- The step the summary's exit makes from frame `fe` (above frames `rest`, at step count `k`)
on memory `me`, given the values `vs` of the nodes; for `Exit.phi`, `enter` sets the target's
`phi`s, as `step` does. -/
def Exit.next (V : Valuation) (vs : List (Except Fault Val)) (rest : List Frame) (k : Nat)
    (fe : Frame) (me : Mem) : Exit → Except Fault Step
  | .br d => pure (.next ⟨{ fe with label := d, pc := 0 } :: rest, k + 1⟩ me)
  | .cond x d e => do
    match ← x.eval V vs with
    | .bits _ b =>
      pure (.next ⟨{ fe with label := if b.getLsbD 0 then d else e, pc := 0 } :: rest, k + 1⟩ me)
    | _ => throw (.unsupported "branch on a non-word")
  | .phi x d e => do
    match ← x.eval V vs with
    | .bits _ b => pure (.next ⟨(← enter (V.ctx.scope me fe k) fe
        (if b.getLsbD 0 then d else e)) :: rest, k + 1⟩ me)
    | _ => throw (.unsupported "branch on a non-word")
  | .ret => pure (match rest with
    | [] => .done (fe.allocas.foldl (fun m b => m.setLive b false) me)
    | g :: rest => .next ⟨{ g.set fe.dest none none with pc := g.pc + 1 } :: rest, k + 1⟩
        (fe.allocas.foldl (fun m b => m.setLive b false) me))

/-! ## Soundness -/

/-- The state `σ` describes frame `fi` and memory `mi`, from entry frame `f`, with the values
`vs` of the final table. -/
structure Rel (V : Valuation) (vs : List (Except Fault Val)) (f : Frame) (σ : SState) (fi : Frame)
    (mi : Mem) : Prop where
  /-- The relation from its facts on the frame (function, block, `alloca` blocks, caller's result
  register, registers, `fmul contract` operands), the state's entries and table and the memory. -/
  mk ::
  /-- The function is the entry frame's. -/
  fn : fi.fn = f.fn
  /-- The valuation's function is the entry frame's. -/
  vfn : V.fn = f.fn
  /-- The block is the entry frame's. -/
  label : fi.label = f.label
  /-- The `alloca` blocks are those the state's effects make (`SEff.blocks`, newest first), then
  the entry frame's. -/
  allocas : fi.allocas = SEff.blocks V σ.effs ++ f.allocas
  /-- The caller's result register is the entry frame's. -/
  dest : fi.dest = f.dest
  /-- The registers are the state's. -/
  regs : ∀ r, fi.regs r = regVal V vs σ.regs r
  /-- The `fmul contract` operands are the state's: for a register the block set, the values of
  its node's `fmul contract` operand terms (`regProdIn`). -/
  prods : ∀ r, fi.prods r = regProdIn V vs σ.nodes σ.regs r
  /-- Every register the block set is a node of the state's table. -/
  wf : ∀ r x, σ.regs.lookup r = some x → ∃ j, x = .node j ∧ j < σ.nodes.length
  /-- The `fmul contract` operand terms of the table's nodes refer to nodes of the table. -/
  fwf : ∀ (x : SVal) (pq : SVal × SVal) (j : Nat), x.factors σ.nodes = some pq →
    (pq.1 = .node j ∨ pq.2 = .node j) → j < σ.nodes.length
  /-- The table's float constant nodes have their literal's value (`floatLit`). -/
  lits : ∀ j ft lit, σ.nodes[j]? = some (.flit ft lit) → (SVal.node j).eval V vs = floatLit ft lit
  /-- The memory is the one the state's effects make. -/
  mem : SEff.run V vs σ.effs = .ok mi
  /-- Before a `store`, the memory is the entry memory with another trace. -/
  trace : σ.stored = false → ∃ tr, mi = { V.mem with trace := tr }

/-- The entry `SState.op` gives a float constant: a node of the table that is the constant's
`SNode.flit`. -/
theorem SState.op_flit {σ : SState} {ft : FloatTy} {lit : FloatLit} {x : SVal}
    (h : (σ.nodes.findIdx? (· == .flit ft lit)).map SVal.node = some x) :
    ∃ j, x = .node j ∧ σ.nodes[j]? = some (.flit ft lit) := by
  obtain ⟨j, hj, rfl⟩ := Option.map_eq_some_iff.1 h
  obtain ⟨hlt, hp, -⟩ := List.findIdx?_eq_some_iff_getElem.1 hj
  exact ⟨j, rfl, by rw [List.getElem?_eq_getElem hlt, beq_iff_eq.1 hp]⟩

/-- An operand's entry that evaluates gives the operand's value. -/
theorem SState.op_eval {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) {s : Scope} (hs : s.regs = fi.regs) {t : Ty} {a : Value}
    {x : SVal} (h : σ.op t a = some x) {v : Val} (hv : x.eval V vs = .ok v) :
    evalV s t a = .ok v := by
  unfold SState.op at h
  split at h
  · rename_i r
    cases h
    simp only [evalV, hs, hR.regs r, regVal]
    unfold SState.get at hv
    cases hl : σ.regs.lookup r with
    | some y =>
      simp only [hl, Option.getD_some] at hv
      simp only [hv, Except.toOption, pure, Except.pure]
    | none =>
      simp only [hl, Option.getD_none, SVal.eval] at hv
      dsimp only
      split at hv
      · rename_i u hu
        simp only [pure, Except.pure, Except.ok.injEq] at hv
        subst hv
        simp only [hu, pure, Except.pure]
      · cases hv
  · cases h
    simp only [SVal.eval, pure, Except.pure, Except.ok.injEq] at hv
    subst hv
    rfl
  · obtain ⟨j, rfl, hj⟩ := SState.op_flit h
    rw [hR.lits j _ _ hj] at hv
    exact hv
  · cases h

/-- An operand's entry refers to nodes of the state's table only. -/
theorem SState.op_wf {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) {t : Ty} {a : Value} {x : SVal} (h : σ.op t a = some x) :
    ∀ j, x = .node j → j < σ.nodes.length := by
  intro j hj
  subst hj
  unfold SState.op at h
  split at h
  · rename_i r
    simp only [SState.get, Option.some.injEq] at h
    cases hl : σ.regs.lookup r with
    | some y =>
      rw [hl, Option.getD_some] at h
      obtain ⟨j', rfl, hj'⟩ := hR.wf r y hl
      cases h
      exact hj'
    | none =>
      rw [hl, Option.getD_none] at h
      cases h
  · cases h
  · obtain ⟨j', he, hj'⟩ := SState.op_flit h
    cases he
    exact (List.getElem?_eq_some_iff.1 hj').1
  · cases h

/-- **Operands taken one by one**: for a state related to frame `fi` and operands `idx` whose
entries `SState.op` gives as `ys` (a `getelementptr`'s indices), if `ys` have values `xs` on the
values of the state's nodes, then on a final table that extends them (`hus`) `evalTVs` gives `xs`
in every scope with the frame's registers (`SState.op_eval`, operand by operand). -/
theorem SState.ops_eval {V : Valuation} {vs us : List (Except Fault Val)} {f fi : Frame}
    {σ : SState} {mi : Mem} (hR : Rel V vs f σ fi mi) {s : Scope} (hs : s.regs = fi.regs)
    (hus : vs = vals V σ.nodes ++ us) :
    ∀ {idx : List TValue} {ys : List SVal} {xs : List Val},
      idx.mapM (fun | .mk t v => σ.op t v) = some ys →
      ys.mapM (·.eval V (vals V σ.nodes)) = .ok xs → evalTVs s idx = .ok xs
  | [], ys, xs, h, h' => by
    rw [List.mapM_nil] at h
    obtain rfl : [] = ys := Option.some.inj h
    rw [List.mapM_nil] at h'
    obtain rfl : [] = xs := Except.ok.inj h'
    rfl
  | .mk t a :: idx, ys, xs, h, h' => by
    rw [List.mapM_cons] at h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨ys', hys, h⟩ := Option.bind_eq_some_iff.1 h
    obtain rfl : y :: ys' = ys := Option.some.inj h
    rw [List.mapM_cons] at h'
    obtain ⟨x, hx, h'⟩ := Except.bind_eq_ok.1 h'
    obtain ⟨xs', hxs, h'⟩ := Except.bind_eq_ok.1 h'
    obtain rfl : x :: xs' = xs := Except.ok.inj h'
    have hx' : y.eval V vs = .ok x := by
      rw [hus]; exact SVal.eval_append (by rw [vals_length]; exact SState.op_wf hR hy) hx us
    simp only [evalTVs, evalTV, SState.op_eval hR hs hy hx', SState.ops_eval hR hs hus hys hxs,
      bind, Except.bind, pure, Except.pure]

/-- The value of the node a state appends, from the obligation that it evaluates in the final
table: its evaluation on the values before it; and the final values extend those. -/
theorem SState.node_ok {V : Valuation} {vs ws : List (Except Fault Val)} {σ : SState}
    {nd : SNode} {w : Val} (hN : vs = vals V (σ.nodes ++ [nd]) ++ ws)
    (h : (SVal.node σ.nodes.length).eval V vs = .ok w) :
    nd.eval V (vals V σ.nodes) = .ok w ∧
      vs = vals V σ.nodes ++ ([nd.eval V (vals V σ.nodes)] ++ ws) := by
  rw [vals_snoc, List.append_assoc] at hN
  subst hN
  refine ⟨?_, rfl⟩
  have hl := Nat.le_of_eq (vals_length V σ.nodes)
  simp only [SVal.eval] at h
  rw [List.getElem?_append_right hl, vals_length, Nat.sub_self] at h
  simpa only [List.singleton_append, List.getElem?_cons_zero, Option.getD_some] using h

/-- `List.lookup` past a key of another number. -/
theorem lookup_ne {α : Type} {s r : Nat} {v : α} {l : List (Nat × α)} (h : s ≠ r) :
    ((r, v) :: l).lookup s = l.lookup s := by
  have h' : (s == r) = false := beq_eq_false_iff_ne.2 h
  simp only [List.lookup, h']

/-- An `Except` with a unit value that is ok is `.ok ()`. -/
theorem isOk_unit {ε : Type} {e : Except ε Unit} (h : e.isOk = true) : e = .ok () := by
  cases e with
  | error => simp [Except.isOk, Except.toBool] at h
  | ok u => rfl

/-- The statement at a position whose instruction is `i`. -/
theorem stmt_inst {V : Valuation} {lbl pc : Nat} {st : Stmt} {i : Inst}
    (hst : V.stmt lbl pc = some st) (hi : st.inst = i) :
    V.stmt lbl pc = some ⟨st.res, i, st.md⟩ := by
  subst hi; exact hst

/-- The `fmul contract` operands of a register in a longer table: the same, when every register
the block set is a node of the table `ns`. -/
theorem regProdIn_append {V : Valuation} {vs : List (Except Fault Val)} {ns : List SNode}
    {regs : List (Nat × SVal)}
    (hwf : ∀ r x, regs.lookup r = some x → ∃ j, x = .node j ∧ j < ns.length) (ns' : List SNode)
    (r : Nat) : regProdIn V vs (ns ++ ns') regs r = regProdIn V vs ns regs r := by
  unfold regProdIn
  cases hl : regs.lookup r with
  | none => rfl
  | some y =>
    obtain ⟨j, rfl, hj⟩ := hwf r y hl
    simp only [SVal.factors, List.getElem?_append_left hj]

/-- The entry at or past the length of a list with one more element is that element. -/
theorem getElem?_snoc_ge {α : Type} {l : List α} {a b : α} {j : Nat} (hj : l.length ≤ j)
    (h : (l ++ [a])[j]? = some b) : j = l.length ∧ a = b := by
  rw [List.getElem?_append_right hj] at h
  obtain ⟨hlt, he⟩ := List.getElem?_eq_some_iff.1 h
  simp only [List.length_singleton] at hlt
  exact ⟨by omega, by simpa only [List.getElem_singleton] using he⟩

/-- `Rel` after a statement that appends a node `nd` and sets register `res` (if any) to the
node's value `x` with `fmul contract` operands `pr`, with the memory unchanged: when `nd`'s
`fmul contract` operand terms refer to nodes of the table and their values are `pr`, and `nd` is
not a float constant node. -/
theorem Rel.defP {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) (res : Option Nat) {nd : SNode} {x : Val}
    {pr : Option (Val × Val)} (hv : (SVal.node σ.nodes.length).eval V vs = .ok x)
    (hfw : ∀ (pq : SVal × SVal) (j : Nat), nd.factors = some pq →
      (pq.1 = .node j ∨ pq.2 = .node j) → j < σ.nodes.length)
    (hp : nd.factors.bind (prodVal V vs) = pr) (hnl : ∀ ft lit, nd ≠ .flit ft lit) :
    Rel V vs f (σ.def res nd) { fi.set res (some x) pr with pc := fi.pc + 1 } mi := by
  have hlen : (σ.def res nd).nodes.length = σ.nodes.length + 1 := by
    simp only [SState.def, List.length_append, List.length_singleton]
  have hlit : ∀ j ft lit, (σ.def res nd).nodes[j]? = some (.flit ft lit) →
      (SVal.node j).eval V vs = floatLit ft lit := by
    intro j ft lit hj
    by_cases hi : j < σ.nodes.length
    · simp only [SState.def, List.getElem?_append_left hi] at hj
      exact hR.lits j ft lit hj
    · exact absurd (getElem?_snoc_ge (l := σ.nodes) (Nat.le_of_not_lt hi) hj).2 (hnl ft lit)
  have hfw' : ∀ (y : SVal) (pq : SVal × SVal) (j : Nat), y.factors (σ.def res nd).nodes = some pq →
      (pq.1 = .node j ∨ pq.2 = .node j) → j < (σ.def res nd).nodes.length := by
    intro y pq j hy hj
    rw [hlen]
    cases y with
    | node i =>
      by_cases hi : i < σ.nodes.length
      · simp only [SState.def, SVal.factors, List.getElem?_append_left hi] at hy
        exact Nat.lt_succ_of_lt (hR.fwf (.node i) pq j hy hj)
      · by_cases he : i = σ.nodes.length
        · subst he
          simp only [SState.def, SVal.factors, List.getElem?_concat_length, Option.bind_some] at hy
          exact Nat.lt_succ_of_lt (hfw pq j hy hj)
        · simp only [SState.def, SVal.factors] at hy
          rw [List.getElem?_eq_none
            (by simp only [List.length_append, List.length_singleton]; omega)] at hy
          cases hy
    | _ => cases hy
  cases res with
  | none =>
    refine ⟨hR.fn, hR.vfn, hR.label, hR.allocas, hR.dest, hR.regs,
      fun s => (hR.prods s).trans (regProdIn_append hR.wf [nd] s).symm, fun r y hy => ?_, hfw',
      hlit, hR.mem, hR.trace⟩
    obtain ⟨j, rfl, hj⟩ := hR.wf r y hy
    exact ⟨j, rfl, by rw [hlen]; omega⟩
  | some r =>
    refine ⟨hR.fn, hR.vfn, hR.label, hR.allocas, hR.dest, fun s => ?_, fun s => ?_,
      fun s u hu => ?_, hfw', hlit, hR.mem, hR.trace⟩
    · show (if s = r then some x else fi.regs s) =
        regVal V vs ((r, .node σ.nodes.length) :: σ.regs) s
      by_cases hs : s = r
      · subst hs
        simp only [reduceIte, regVal, List.lookup_cons_self, hv, Except.toOption]
      · rw [ite_eq_right_of_eq_false _ _ (eq_false hs), hR.regs s]
        simp only [regVal, lookup_ne hs]
    · show (if s = r then pr else fi.prods s) =
        regProdIn V vs (σ.nodes ++ [nd]) ((r, .node σ.nodes.length) :: σ.regs) s
      by_cases hs : s = r
      · subst hs
        simp only [reduceIte, regProdIn, List.lookup_cons_self, SVal.factors,
          List.getElem?_concat_length, Option.bind_some, hp]
      · rw [ite_eq_right_of_eq_false _ _ (eq_false hs), hR.prods s]
        simp only [regProdIn, lookup_ne hs]
        exact (regProdIn_append hR.wf [nd] s).symm
    · by_cases hs : s = r
      · subst hs
        simp only [SState.def, List.lookup_cons_self, Option.some.injEq] at hu
        subst hu
        exact ⟨_, rfl, by rw [hlen]; omega⟩
      · obtain ⟨j, rfl, hj⟩ := hR.wf s u ((lookup_ne hs).symm.trans hu)
        exact ⟨j, rfl, by rw [hlen]; omega⟩

/-- `Rel` after a statement that appends a node with no `fmul contract` operand terms, other than
a float constant node, and sets register `res` (if any) to the node's value `x`, with the memory
unchanged (`Rel.defP`). -/
theorem Rel.def {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) (res : Option Nat) {nd : SNode} {x : Val}
    (hv : (SVal.node σ.nodes.length).eval V vs = .ok x) (hnd : nd.factors = none := by rfl)
    (hnl : ∀ ft lit, nd ≠ .flit ft lit := by intro _ _ h; cases h) :
    Rel V vs f (σ.def res nd) { fi.set res (some x) none with pc := fi.pc + 1 } mi :=
  hR.defP res hv (fun _ _ h => by rw [hnd] at h; cases h) (by rw [hnd]; rfl) hnl

/-- `Rel` holds of every frame with the function, block, `alloca` blocks, caller's register,
registers and `fmul contract` operands of a frame it holds of (it does not read the position). -/
theorem Rel.frame {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) {fi' : Frame} (hfn : fi'.fn = fi.fn)
    (hl : fi'.label = fi.label) (ha : fi'.allocas = fi.allocas) (hd : fi'.dest = fi.dest)
    (hr : fi'.regs = fi.regs) (hp : fi'.prods = fi.prods) : Rel V vs f σ fi' mi :=
  ⟨hfn.trans hR.fn, hR.vfn, hl.trans hR.label, ha.trans hR.allocas, hd.trans hR.dest,
    fun r => (congrFun hr r).trans (hR.regs r), fun r => (congrFun hp r).trans (hR.prods r),
    hR.wf, hR.fwf, hR.lits, hR.mem, hR.trace⟩

/-- `Rel` after a statement that appends a node `nd₁` that sets no register, then a node `nd₂`
that sets register `res` (if any) to its value `x`, neither with `fmul contract` operand terms nor
a float constant node, with the memory unchanged: the frame is the statement's single
definition of `res` (`Rel.def` twice, `Rel.frame`). -/
theorem Rel.def₂ {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) (res : Option Nat) {nd₁ nd₂ : SNode} {x₁ x : Val}
    (hv₁ : (SVal.node σ.nodes.length).eval V vs = .ok x₁)
    (hv : (SVal.node (σ.def none nd₁).nodes.length).eval V vs = .ok x)
    (hnd₁ : nd₁.factors = none := by rfl)
    (hnl₁ : ∀ ft lit, nd₁ ≠ .flit ft lit := by intro _ _ h; cases h)
    (hnd₂ : nd₂.factors = none := by rfl)
    (hnl₂ : ∀ ft lit, nd₂ ≠ .flit ft lit := by intro _ _ h; cases h) :
    Rel V vs f ((σ.def none nd₁).def res nd₂) { fi.set res (some x) none with pc := fi.pc + 1 }
      mi := by
  refine ((hR.def none hv₁ hnd₁ hnl₁).def res hv hnd₂ hnl₂).frame ?_ ?_ ?_ ?_ ?_ ?_ <;>
    (cases res <;> rfl)

/-- `Rel` after an effect `e` that applies to the memory and makes no block (a `load`'s or a
`store`'s). -/
theorem Rel.push {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi mi' : Mem} {e : SEff} (hR : Rel V vs f σ fi mi) (he : e.apply V vs mi = .ok mi')
    (htr : σ.stored = false → ∃ tr, mi' = { V.mem with trace := tr })
    (hb : e.block? V = none := by rfl) :
    Rel V vs f { σ with effs := σ.effs ++ [e] } fi mi' :=
  ⟨hR.fn, hR.vfn, hR.label, by
    show fi.allocas = SEff.blocks V (σ.effs ++ [e]) ++ f.allocas
    rw [SEff.blocks_snoc, hb]; exact hR.allocas, hR.dest, hR.regs, hR.prods, hR.wf, hR.fwf,
    hR.lits, SEff.run_append hR.mem he, htr⟩

/-- `Rel` after a `store` effect `e` that applies to the memory. -/
theorem Rel.store {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi mi' : Mem} {e : SEff} (hR : Rel V vs f σ fi mi) (he : e.apply V vs mi = .ok mi')
    (hb : e.block? V = none := by rfl) :
    Rel V vs f { σ with effs := σ.effs ++ [e], stored := true } { fi with pc := fi.pc + 1 } mi' :=
  ⟨hR.fn, hR.vfn, hR.label, by
    show fi.allocas = SEff.blocks V (σ.effs ++ [e]) ++ f.allocas
    rw [SEff.blocks_snoc, hb]; exact hR.allocas, hR.dest, hR.regs, hR.prods, hR.wf, hR.fwf,
    hR.lits, SEff.run_append hR.mem he, by intro h; cases h⟩

/-- `Rel` after an `alloca`'s effect `e` that applies to the memory and makes block `b`: the
frame has `b` in front of its `alloca` blocks. -/
theorem Rel.alloca {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi mi' : Mem} {e : SEff} {b : Nat} (hR : Rel V vs f σ fi mi)
    (he : e.apply V vs mi = .ok mi') (hb : e.block? V = some b) :
    Rel V vs f { σ with effs := σ.effs ++ [e], stored := true }
      { fi with allocas := b :: fi.allocas } mi' :=
  ⟨hR.fn, hR.vfn, hR.label, by
    show b :: fi.allocas = SEff.blocks V (σ.effs ++ [e]) ++ f.allocas
    rw [SEff.blocks_snoc, hb, hR.allocas]; rfl, hR.dest, hR.regs, hR.prods, hR.wf, hR.fwf,
    hR.lits, SEff.run_append hR.mem he, by intro h; cases h⟩

/-- `SState.def` puts at most one entry in front of the register entries. -/
theorem SState.def_regs (σ : SState) (res : Option Nat) (nd : SNode) :
    ∃ rs, (σ.def res nd).regs = rs ++ σ.regs := by
  cases res
  · exact ⟨[], rfl⟩
  · exact ⟨[_], rfl⟩

/-- A statement in the fragment keeps the obligations, extends the effects and the table, and puts
entries in front of the register entries. -/
theorem SState.stmt_mono {P : Program} {lbl pc n : Nat} {σ σ' : SState} {st : Stmt}
    {contract : Bool} (h : σ.stmt P lbl pc n st contract = some σ') :
    (∀ d ∈ σ.obls, d ∈ σ'.obls) ∧ (∃ es, σ'.effs = σ.effs ++ es) ∧
      (∃ ns, σ'.nodes = σ.nodes ++ ns) ∧ ∃ rs, σ'.regs = rs ++ σ.regs := by
  unfold SState.stmt at h
  repeat' (first
    | (split at h)
    | (rw [Option.bind_eq_some_iff] at h; obtain ⟨_, _, h⟩ := h)
    | (simp only [Option.bind_eq_bind] at h))
  all_goals first
    | (cases h; exact ⟨fun d hd => List.mem_cons_of_mem _ hd, ⟨[], (List.append_nil _).symm⟩,
        ⟨_, rfl⟩, SState.def_regs _ _ _⟩)
    | (cases h; exact ⟨fun d hd => hd, ⟨_, rfl⟩, ⟨[], (List.append_nil _).symm⟩, ⟨[], rfl⟩⟩)
    | (cases h; done)
    | (cases h
       refine ⟨fun d hd => List.mem_cons_of_mem _ hd, ⟨_, rfl⟩, ⟨_, rfl⟩, ?_⟩
       cases st.res
       · exact ⟨[], rfl⟩
       · exact ⟨[_], rfl⟩)
    -- a `getelementptr` on a global: two nodes
    | (cases h
       exact ⟨fun d hd => List.mem_cons_of_mem _ (List.mem_cons_of_mem _ hd),
         ⟨[], (List.append_nil _).symm⟩, ⟨_, List.append_assoc _ _ _⟩, SState.def_regs _ _ _⟩)
    -- a `load` on a global: two nodes and an effect
    | (cases h
       refine ⟨fun d hd => List.mem_cons_of_mem _ (List.mem_cons_of_mem _ hd), ⟨_, rfl⟩,
         ⟨_, List.append_assoc _ _ _⟩, ?_⟩
       cases st.res
       · exact ⟨[], rfl⟩
       · exact ⟨[_], rfl⟩)
    -- a `store` on a global: a node and an effect
    | (cases h
       exact ⟨fun d hd => List.mem_cons_of_mem _ hd, ⟨_, rfl⟩, ⟨_, rfl⟩, ⟨[], rfl⟩⟩)

/-- A run of statements keeps the obligations, extends the effects and the table, and puts
entries in front of the register entries. -/
theorem SState.run_mono {P : Program} {lbl p0 : Nat} {contract : Bool} :
    ∀ {sts : List Stmt} {n : Nat} {σ σf : SState}, SState.run contract P lbl p0 sts n σ = some σf →
      (∀ d ∈ σ.obls, d ∈ σf.obls) ∧ (∃ es, σf.effs = σ.effs ++ es) ∧
        (∃ ns, σf.nodes = σ.nodes ++ ns) ∧ ∃ rs, σf.regs = rs ++ σ.regs
  | [], _, _, _, h => by
    simp only [SState.run, Option.some.injEq] at h
    subst h
    exact ⟨fun _ hd => hd, ⟨[], (List.append_nil _).symm⟩, ⟨[], (List.append_nil _).symm⟩,
      ⟨[], rfl⟩⟩
  | _ :: _, _, _, _, h => by
    simp only [SState.run] at h
    split at h
    · rename_i σ' hσ
      obtain ⟨h1, ⟨es1, he1⟩, ⟨ns1, hn1⟩, ⟨rs1, hr1⟩⟩ := SState.stmt_mono hσ
      obtain ⟨h2, ⟨es2, he2⟩, ⟨ns2, hn2⟩, ⟨rs2, hr2⟩⟩ := SState.run_mono h
      exact ⟨fun d hd => h2 d (h1 d hd), ⟨es1 ++ es2, by rw [he2, he1, List.append_assoc]⟩,
        ⟨ns1 ++ ns2, by rw [hn2, hn1, List.append_assoc]⟩,
        ⟨rs2 ++ rs1, by rw [hr2, hr1, List.append_assoc]⟩⟩
    · cases h

/-- A statement in the fragment keeps the state's `alloca` (whether the checker takes `alloca`),
and with it off adds no `alloca`'s effect (`SEff.allocates`). -/
theorem SState.stmt_alloca {P : Program} {lbl pc n : Nat} {σ σ' : SState} {st : Stmt}
    {contract : Bool} (h : σ.stmt P lbl pc n st contract = some σ') :
    σ'.alloca = σ.alloca ∧ (σ.alloca = false → SEff.allocates σ'.effs = SEff.allocates σ.effs) := by
  unfold SState.stmt at h
  repeat' (first
    | (split at h)
    | (rw [Option.bind_eq_some_iff] at h; obtain ⟨_, _, h⟩ := h)
    | (simp only [Option.bind_eq_bind] at h))
  all_goals first
    | (cases h; done)
    | (cases h; refine ⟨rfl, fun h' => ?_⟩
       first | rfl | (simp [SEff.allocates]; done) | simp_all)

/-- **A run from a state that does not take `alloca` allocates nothing**: for every program,
block, position, `contract`, statements and states, a run (`SState.run`) from a state whose
`alloca` is off and whose effects have no `alloca`'s ends in a state whose effects have none
(`SState.stmt_alloca`); so the frame keeps the entry's `alloca` blocks (`Rel.allocas`,
`SEff.blocks_eq_nil`). Every run from `SState.start` is one. -/
theorem SState.run_alloca {P : Program} {lbl p0 : Nat} {contract : Bool} :
    ∀ {sts : List Stmt} {n : Nat} {σ σf : SState}, SState.run contract P lbl p0 sts n σ = some σf →
      σ.alloca = false → SEff.allocates σ.effs = false → SEff.allocates σf.effs = false
  | [], _, _, _, h, _, he => by
    simp only [SState.run, Option.some.injEq] at h
    subst h
    exact he
  | _ :: _, _, _, _, h, ha, he => by
    simp only [SState.run] at h
    split at h
    · rename_i σ' hσ
      obtain ⟨h1, h2⟩ := SState.stmt_alloca hσ
      exact SState.run_alloca h (h1.trans ha) ((h2 ha).trans he)
    · cases h

/-- A statement in the fragment without `fmul contract` (`SState.stmt` with `contract = false`)
keeps the table free of `fmul contract` nodes (`SNode.factors`). -/
theorem SState.stmt_factors {P : Program} {lbl pc n : Nat} {σ σ' : SState} {st : Stmt}
    (h : σ.stmt P lbl pc n st = some σ') (hf : ∀ nd ∈ σ.nodes, nd.factors = none) :
    ∀ nd ∈ σ'.nodes, nd.factors = none := by
  have hx : ∀ x : SVal, x.factors σ.nodes = none := by
    intro x
    cases x with
    | node j =>
      show σ.nodes[j]?.bind SNode.factors = none
      cases hj : σ.nodes[j]? with
      | none => rfl
      | some nd => exact hf nd (List.mem_of_getElem? hj)
    | _ => rfl
  unfold SState.stmt at h
  repeat' (first
    | (split at h)
    | (rw [Option.bind_eq_some_iff] at h; obtain ⟨_, _, h⟩ := h)
    | (simp only [Option.bind_eq_bind] at h))
  all_goals first
    | (cases h; done)
    | (cases h
       intro nd hnd
       first
         | exact hf nd hnd
         | (simp only [SState.def, List.mem_append, List.mem_singleton] at hnd
            rcases hnd with hnd | rfl
            · exact hf nd hnd
            · first
                | rfl
                | simp_all [SNode.fbinOf, SNode.factors]))
    -- a `getelementptr` on a global: two nodes
    | (cases h
       intro nd hnd
       simp only [SState.def, List.mem_append, List.mem_singleton] at hnd
       rcases hnd with (hnd | rfl) | rfl
       · exact hf nd hnd
       all_goals rfl)

/-- A run of statements without `fmul contract` keeps the table free of `fmul contract`
nodes. -/
theorem SState.run_factors {P : Program} {lbl p0 : Nat} :
    ∀ {sts : List Stmt} {n : Nat} {σ σf : SState}, SState.run false P lbl p0 sts n σ = some σf →
      (∀ nd ∈ σ.nodes, nd.factors = none) → ∀ nd ∈ σf.nodes, nd.factors = none
  | [], _, _, _, h, hf => by
    simp only [SState.run, Option.some.injEq] at h
    subst h
    exact hf
  | _ :: _, _, _, _, h, hf => by
    simp only [SState.run] at h
    split at h
    · rename_i σ' hσ
      exact SState.run_factors h (SState.stmt_factors hσ hf)
    · cases h

/-- Every node of a block's float constant table (`litNodes`) is a float constant node. -/
theorem litNodes_flit {fn : Func} {lbl p0 : Nat} {b : LLVM.Block} {nd : SNode}
    (h : nd ∈ litNodes fn lbl p0 b) : ∃ ft lit, nd = .flit ft lit := by
  rw [litNodes, List.mem_eraseDups, List.mem_filterMap] at h
  obtain ⟨a, -, ha⟩ := h
  unfold SNode.litOf at ha
  split at ha
  · cases ha
    exact ⟨_, _, rfl⟩
  · cases ha

/-- A summary without `fmul contract` (`summarizeAt alloca` with `contract = false`) has no
`fmul contract` node, for both values of the `alloca` flag. -/
theorem summarizeAt_factors {alloca : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {S : Summary}
    (h : summarizeAt alloca P fn lbl p0 ex = some S) : ∀ nd ∈ S.nodes, nd.factors = none := by
  unfold summarizeAt at h
  split at h
  · split at h
    · rename_i σ hσ
      split at h
      · cases h
        exact SState.run_factors hσ fun _ hnd => by
          obtain ⟨_, _, rfl⟩ := litNodes_flit hnd
          rfl
      · cases h
    · cases h
  · cases h

/-- A summary from `SState.start` (`summarizeWith`) allocates nothing (`SEff.allocates`), for
every program, function, block, position, exit function and `contract`: the start state's
`alloca` flag is off (`SState.run_alloca`). -/
theorem summarizeWith_allocates {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {contract : Bool} {S : Summary}
    (h : summarizeWith P fn lbl p0 ex contract = some S) : SEff.allocates S.effs = false := by
  unfold summarizeWith summarizeAt at h
  split at h
  · split at h
    · rename_i σ hσ
      split at h
      · cases h
        exact SState.run_alloca hσ rfl rfl
      · cases h
    · cases h
  · cases h

/-- **The summary the block checker accepts**: for every flag `alloca` and `contract`, program,
function, block, position, exit function, conditions `ds` and summary `S` that
`coversAt alloca` accepts, `summarizeAt alloca` gives `S`. -/
theorem coversAt_summary {alloca : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {ds : List Cond} {S : Summary}
    {contract : Bool} (hc : coversAt alloca P fn lbl p0 ex ds S contract = true) :
    summarizeAt alloca P fn lbl p0 ex contract = some S := by
  unfold coversAt at hc
  split at hc
  · rename_i S' hS
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    exact hc.1 ▸ hS
  · cases hc

/-- A step of a frame at a statement that `exec` runs to a frame. -/
theorem step_stmt {c : Ctx} {fi fi' : Frame} {rest : List Frame} {k : Nat} {m m' : Mem}
    {b : LLVM.Block} {st : Stmt} (hb : fi.fn.blocks.find? (·.label == fi.label) = some b)
    (hst : b.stmts[fi.pc]? = some st) (he : exec c (c.scope m fi k) k fi st = .ok (.next fi' m')) :
    step c ⟨fi :: rest, k⟩ m = .ok (.next ⟨fi' :: rest, k + 1⟩ m') := by
  obtain ⟨hpc, rfl⟩ := Array.getElem?_eq_some_iff.1 hst
  (simp only [step, hb, hpc, ↓reduceDIte, he, bind, Except.bind, pure, Except.pure])

/-- Entering a block without `phi`s. -/
theorem enter_nophi {s : Scope} {f : Frame} {d : Nat} (h : entersAt f.fn d = true) :
    enter s f d = .ok { f with label := d, pc := 0 } := by
  unfold entersAt at h
  split at h
  · rename_i b hb
    unfold enter
    rw [hb]
    dsimp only
    generalize hP : List.takeWhile (fun x => match x.inst with
      | Inst.phi .. => true
      | _ => false) b.stmts.toList = phis
    have h0 : phis = [] := hP.symm.trans (List.isEmpty_iff.1 h)
    subst h0
    rfl
  · cases h

/-- `Frame.set` changes the registers and `fmul contract` operands only, as a function of the
frame's: on a frame `g` with those of `f`, it gives `f.set`'s. -/
theorem Frame.set_with {f g : Frame} (r : Option Nat) (v : Option Val) (p : Option (Val × Val))
    (h1 : g.regs = f.regs) (h2 : g.prods = f.prods) :
    g.set r v p = { g with regs := (f.set r v p).regs, prods := (f.set r v p).prods } := by
  obtain ⟨⟩ := g
  obtain ⟨⟩ := f
  dsimp only at h1 h2
  subst h1 h2
  cases r <;> cases v <;> rfl

/-- `Frame.set_with` along a fold of a function `F` with that property. -/
theorem Frame.foldl_with {α : Type} (F : Frame → α → Frame)
    (hF : ∀ f g z, g.regs = f.regs → g.prods = f.prods →
      F g z = { g with regs := (F f z).regs, prods := (F f z).prods }) :
    ∀ (zs : List α) (f g : Frame), g.regs = f.regs → g.prods = f.prods →
      zs.foldl F g = { g with regs := (zs.foldl F f).regs, prods := (zs.foldl F f).prods }
  | [], f, g, h1, h2 => by
    obtain ⟨⟩ := g
    obtain ⟨⟩ := f
    dsimp only at h1 h2
    subst h1 h2
    rfl
  | z :: zs, f, g, h1, h2 => by
    have e := hF f g z h1 h2
    rw [List.foldl_cons, List.foldl_cons,
      Frame.foldl_with F hF zs (F f z) (F g z) (by rw [e]) (by rw [e]), e]

/-- `enter` reads the frame's function, block, registers and `fmul contract` operands only: on
a frame `g` with those of `f`, it gives `f`'s result with `g`'s `alloca` blocks and caller's
register. -/
theorem enter_congr {s : Scope} {f g f' : Frame} {d : Nat} (h : enter s f d = .ok f')
    (hfn : g.fn = f.fn) (hl : g.label = f.label) (hr : g.regs = f.regs)
    (hp : g.prods = f.prods) :
    enter s g d = .ok { f' with allocas := g.allocas, dest := g.dest } := by
  unfold enter at h ⊢
  rw [hfn, hl]
  cases hb : f.fn.blocks.find? (·.label == d) with
  | none => rw [hb] at h; cases h
  | some b =>
    rw [hb] at h
    dsimp only at h ⊢
    generalize (List.mapM _ _ : Except Fault (List Val)) = r at h ⊢
    cases r with
    | error e => cases h
    | ok vs =>
      simp only [bind, Except.bind, pure, Except.pure, Except.ok.injEq] at h ⊢
      subst h
      rw [Frame.foldl_with _ ?_ _ f g hr hp, Frame.foldl_with _ ?_ _ f f rfl rfl]
      · simp only [hfn]
      all_goals
        intro f g z h1 h2
        obtain ⟨st, v⟩ := z
        exact Frame.set_with _ _ _ h1 h2

/-- `enter` keeps the frame's function, `alloca` blocks (`enter_allocas`) and caller's register,
and gives block `d` at the position after its `phi`s (`phiCount`). -/
theorem enter_fields {s : Scope} {f f' : Frame} {d : Nat} (h : enter s f d = .ok f') :
    f'.fn = f.fn ∧ f'.label = d ∧ f'.pc = phiCount f.fn d ∧ f'.allocas = f.allocas ∧
      f'.dest = f.dest := by
  suffices h' : f'.fn = f.fn ∧ f'.label = d ∧ f'.pc = phiCount f.fn d ∧ f'.dest = f.dest from
    ⟨h'.1, h'.2.1, h'.2.2.1, enter_allocas h, h'.2.2.2⟩
  unfold enter at h
  cases hb : f.fn.blocks.find? (·.label == d) with
  | none => rw [hb] at h; cases h
  | some b =>
    rw [hb] at h
    dsimp only at h
    generalize (List.mapM _ _ : Except Fault (List Val)) = r at h
    cases r with
    | error e => cases h
    | ok vs =>
      simp only [bind, Except.bind, pure, Except.pure, Except.ok.injEq] at h
      subst h
      rw [Frame.foldl_with _ ?_ _ f f rfl rfl]
      · exact ⟨rfl, rfl, by simp only [phiCount, hb]; rfl, rfl⟩
      · intro f g z h1 h2
        obtain ⟨st, v⟩ := z
        exact Frame.set_with _ _ _ h1 h2

/-- `mapM` in `Except` of `g` succeeds on a list whose `mapM` in `Option` of `o` gives results
that each satisfy `p`, when `o`'s results with `p` make `g` succeed. -/
theorem mapM_ok {α β γ ε : Type} {o : α → Option β} {g : α → Except ε γ} {p : β → Prop}
    (hg : ∀ a b, o a = some b → p b → ∃ y, g a = .ok y) :
    ∀ (as : List α) (bs : List β), as.mapM o = some bs → (∀ b ∈ bs, p b) →
      ∃ ys, as.mapM g = .ok ys
  | [], _, _, _ => ⟨[], rfl⟩
  | a :: as, bs, h, hp => by
    rw [List.mapM_cons] at h
    obtain ⟨b, hb, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨bs', hbs, h⟩ := Option.bind_eq_some_iff.1 h
    obtain rfl : b :: bs' = bs := Option.some.inj h
    obtain ⟨y, hy⟩ := hg a b hb (hp b (List.Mem.head _))
    obtain ⟨ys, hys⟩ := mapM_ok hg as bs' hbs (fun b hb => hp b (List.mem_cons_of_mem _ hb))
    exact ⟨y :: ys, by rw [List.mapM_cons, hy, hys]; rfl⟩

/-- An edge whose obligations hold (`SState.phiConds`) enters its target: the `phi`s evaluate,
so `enter` succeeds. -/
theorem SState.enter_ok {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame}
    {σ : SState} {mi : Mem} (hR : Rel V vs f σ fi mi) {s : Scope} (hs : s.regs = fi.regs)
    {d : Nat} {cs : List Cond} (h : σ.phiConds fi.fn fi.label d = some cs)
    (hcs : ∀ c ∈ cs, c.Holds V vs) : ∃ f', enter s fi d = .ok f' := by
  unfold SState.phiConds at h
  unfold enter
  cases hb : fi.fn.blocks.find? (·.label == d) with
  | none => rw [hb] at h; cases h
  | some b =>
    rw [hb] at h
    dsimp only at h ⊢
    generalize hm : (List.mapM _ _ : Except Fault (List Val)) = r
    obtain ⟨ys, rfl⟩ : ∃ ys, r = .ok ys := by
      rw [← hm]
      refine mapM_ok (p := fun c => c.Holds V vs) ?_ _ cs h hcs
      intro st c ho hc
      split at ho
      · rename_i hmd
        rw [isOk_unit hmd]
        split at ho
        · rename_i t inc hi
          split at ho
          · rename_i v l' hf
            obtain ⟨x, hx, rfl⟩ := Option.map_eq_some_iff.1 ho
            obtain ⟨w, hw⟩ := hc
            exact ⟨w, by simp only [hi, hf, SState.op_eval hR hs hx hw, bind, Except.bind]⟩
          · cases ho
        · cases ho
      · cases ho
    exact ⟨_, rfl⟩

/-- The exit of a block whose statements ran: the terminator's step is the exit's. -/
theorem SState.exit_sound {V : Valuation} {vs : List (Except Fault Val)} {f fe : Frame}
    {σ : SState} {me : Mem} (hR : Rel V vs f σ fe me) {b : LLVM.Block} {rest : List Frame}
    {k : Nat} (hb : fe.fn.blocks.find? (·.label == fe.label) = some b)
    (hpc : ¬ fe.pc < b.stmts.size) {x : Exit} {cs : List Cond}
    (hx : σ.exit fe.fn b.term = some (x, cs)) (hcs : ∀ d ∈ cs, d.Holds V vs) :
    ∃ r, x.next V vs rest k fe me = .ok r ∧ step V.ctx ⟨fe :: rest, k⟩ me = .ok r := by
  unfold SState.exit at hx
  split at hx
  · rename_i d hterm
    split at hx
    · rename_i hen
      cases hx
      refine ⟨_, rfl, ?_⟩
      (simp only [step, hb, hpc, ↓reduceDIte, hterm, enter_nophi hen, bind, Except.bind, pure,
        Except.pure])
    · cases hx
  · rename_i cv d e hterm
    split at hx
    · rename_i y hy
      split at hx
      · rename_i hen
        cases hx
        simp only [Bool.and_eq_true] at hen
        obtain ⟨w, bv, hv⟩ := hcs (.bool y) (List.Mem.head _)
        have hcv := SState.op_eval hR (s := V.ctx.scope me fe k) rfl hy hv
        have hen' : ∀ bit : Bool, entersAt fe.fn (if bit then d else e) = true := by
          intro bit
          cases bit
          · exact hen.2
          · exact hen.1
        refine ⟨.next ⟨{ fe with label := if bv.getLsbD 0 then d else e, pc := 0 } :: rest, k + 1⟩
          me, ?_, ?_⟩
        · (simp only [Exit.next, hv, bind, Except.bind, pure, Except.pure])
        · (simp only [step, hb, hpc, ↓reduceDIte, hterm, hcv, enter_nophi (hen' (bv.getLsbD 0)),
            bind, Except.bind, pure, Except.pure])
      · cases hx
    · cases hx
  · rename_i hterm
    cases hx
    refine ⟨_, rfl, ?_⟩
    cases rest <;>
      (simp only [step, hb, hpc, ↓reduceDIte, hterm, Option.mapM_none, bind, Except.bind, pure,
        Except.pure])
  · cases hx

/-- `SState.exit_sound` for `SState.exitAt`: the terminator's step is the exit's, for branches
into blocks with `phi`s too. -/
theorem SState.exitAt_sound {V : Valuation} {vs : List (Except Fault Val)} {f fe : Frame}
    {σ : SState} {me : Mem} (hR : Rel V vs f σ fe me) {b : LLVM.Block} {rest : List Frame}
    {k : Nat} (hb : fe.fn.blocks.find? (·.label == fe.label) = some b)
    (hpc : ¬ fe.pc < b.stmts.size) {x : Exit} {cs : List Cond}
    (hx : σ.exitAt fe.fn fe.label b.term = some (x, cs)) (hcs : ∀ d ∈ cs, d.Holds V vs) :
    ∃ r, x.next V vs rest k fe me = .ok r ∧ step V.ctx ⟨fe :: rest, k⟩ me = .ok r := by
  unfold SState.exitAt at hx
  cases he : σ.exit fe.fn b.term with
  | some y =>
    rw [he] at hx
    cases hx
    exact SState.exit_sound hR hb hpc he hcs
  | none =>
    rw [he] at hx
    change σ.phiExit fe.fn fe.label b.term = some (x, cs) at hx
    unfold SState.phiExit at hx
    split at hx
    · rename_i d hterm
      obtain ⟨cs', hc', he'⟩ := Option.map_eq_some_iff.1 hx
      cases he'
      obtain ⟨f', hf'⟩ := SState.enter_ok hR (s := V.ctx.scope me fe k) rfl hc' hcs
      refine ⟨.next ⟨f' :: rest, k + 1⟩ me, ?_, ?_⟩
      · (simp only [Exit.next, SVal.eval, ite_self, hf', bind, Except.bind, pure, Except.pure])
      · (simp only [step, hb, hpc, ↓reduceDIte, hterm, hf', bind, Except.bind, pure,
          Except.pure])
    · rename_i cv d e hterm
      split at hx
      · rename_i y cd ce hy hd he2
        cases hx
        obtain ⟨w, bv, hv⟩ := hcs (.bool y) (List.Mem.head _)
        have hcv := SState.op_eval hR (s := V.ctx.scope me fe k) rfl hy hv
        have hcs' := fun c hc => hcs c (List.mem_cons_of_mem _ hc)
        obtain ⟨f', hf'⟩ : ∃ f', enter (V.ctx.scope me fe k) fe
            (if bv.getLsbD 0 then d else e) = .ok f' := by
          split
          · exact SState.enter_ok hR rfl hd fun c hc => hcs' c (List.mem_append_left _ hc)
          · exact SState.enter_ok hR rfl he2 fun c hc => hcs' c (List.mem_append_right _ hc)
        refine ⟨.next ⟨f' :: rest, k + 1⟩ me, ?_, ?_⟩
        · (simp only [Exit.next, hv, hf', bind, Except.bind, pure, Except.pure])
        · (simp only [step, hb, hpc, ↓reduceDIte, hterm, hcv, hf', bind, Except.bind, pure,
            Except.pure])
      · cases hx
    · cases hx

/-- Statement `st` is a `load` (`true`) or a `store` (`false`) whose pointer operand `(.ptr a) q`
evaluates in scope `s` to `pv`: the operand `Labels.MemAt` (MojoProof/Sem/Labels.lean) reads. -/
def PtrIs : Bool → Stmt → Scope → Except Fault Val → Prop
  | true, st, s, pv => ∃ a q vol ty al, st.inst = .load vol ty (.mk (.ptr a) q) al ∧
      evalV s (.ptr a) q = pv
  | false, st, s, pv => ∃ a q vol v al, st.inst = .store vol v (.mk (.ptr a) q) al ∧
      evalV s (.ptr a) q = pv

/-- The stored operand `w` of a `store` whose effect stores the term `x`, with node table `ns`
and register entries `regs`: a register `r` that is `x` (`.reg r`, its value at the block's
entry) or that an entry of `regs` sets to `x`, a float constant whose term `x` is a node of `ns`
that is the constant's `SNode.flit`, or another operand, whose term `x` is an integer constant or
a node of `ns` that is an `SNode.constAt` (a `zeroinitializer`, `undef` or `poison`). -/
def StoreVal (ns : List SNode) (regs : List (Nat × SVal)) (x : SVal) : Value → Prop
  | .loc r => x = .reg r ∨ (r, x) ∈ regs
  | .float lit => ∃ j ft, x = .node j ∧ ns[j]? = some (.flit ft lit)
  | _ => (∃ n i, x = .int n i) ∨ ∃ j l pc i, x = .node j ∧ ns[j]? = some (.constAt l pc i)

/-- Statement `pc` of block `lbl` of function `fn` is a `store` whose stored operand the term `x`
describes with node table `ns` and register entries `regs` (`StoreVal`). -/
def StoreAt (fn : Func) (lbl pc : Nat) (ns : List SNode) (regs : List (Nat × SVal)) (x : SVal) :
    Prop :=
  ∃ b st vol t w ptr al, fn.blocks.find? (·.label == lbl) = some b ∧ b.stmts[pc]? = some st ∧
    st.inst = .store vol (.mk t w) ptr al ∧ StoreVal ns regs x w

/-- The entry `x` of operand `w` describes it (`StoreVal`) with the table of the state and any
nodes appended to it, and the register entries of the state and any entries put in front of
them. -/
theorem SState.op_storeVal {σ : SState} {t : Ty} {w : Value} {x : SVal}
    (h : σ.op t w = some x) (ns : List SNode) (rs : List (Nat × SVal)) :
    StoreVal (σ.nodes ++ ns) (rs ++ σ.regs) x w := by
  unfold SState.op at h
  split at h
  · rename_i r
    cases h
    show SState.get σ r = .reg r ∨ (r, SState.get σ r) ∈ rs ++ σ.regs
    unfold SState.get
    cases hl : σ.regs.lookup r with
    | none => exact .inl rfl
    | some y =>
      obtain ⟨l₁, l₂, he, -⟩ := List.lookup_eq_some_iff.1 hl
      exact .inr (List.mem_append_right _ (by rw [he]; simp))
  · cases h
    exact .inl ⟨_, _, rfl⟩
  · obtain ⟨j, rfl, hj⟩ := SState.op_flit h
    obtain ⟨hlt, -⟩ := List.getElem?_eq_some_iff.1 hj
    exact ⟨j, _, rfl, by rw [List.getElem?_append_left hlt]; exact hj⟩
  · cases h

/-- The pointer facts of statement `st` at position `pc` of block `lbl`, which takes state `σ`
to `σ'`, run in scope `s`, with the values `vs` of the final table: a `load` node `j` it appends
is at `lbl` and `pc`, and the statement's pointer operand evaluates in `s` to the node's pointer
term on the values of the nodes before it (the first `j` of `σ'`); a `store` effect it appends is at
`lbl` and `pc`, the operand evaluates in `s` to the effect's pointer term on `vs`, and the stored
term is the entry `σ.op` gives the stored operand, or, for a stored constant that its type alone
gives (`tyConst`), a node of `σ'` that is its `SNode.constAt`. -/
def StmtPtrs (V : Valuation) (vs : List (Except Fault Val)) (lbl pc : Nat) (σ σ' : SState)
    (st : Stmt) (s : Scope) : Prop :=
  (∀ j l pc' p, σ.nodes.length ≤ j → σ'.nodes[j]? = some (.load l pc' p) →
    l = lbl ∧ pc' = pc ∧ PtrIs true st s (p.eval V (vals V (σ'.nodes.take j)))) ∧
  ∀ l pc' v p, SEff.store l pc' v p ∈ σ'.effs.drop σ.effs.length →
    l = lbl ∧ pc' = pc ∧ PtrIs false st s (p.eval V vs) ∧
      ∃ vol t w ptr al, st.inst = .store vol (.mk t w) ptr al ∧ (σ.op t w = some v ∨
        tyConst w = true ∧ ∃ j, v = .node j ∧ σ'.nodes[j]? = some (.constAt lbl pc 0))

/-- A statement that appends a node other than a `load` and no effect has no pointer facts. -/
theorem SState.def_ptrs {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat}
    {σ : SState} {res : Option Nat} {nd : SNode} {st : Stmt} {s : Scope}
    (hnd : ∀ l pc p, nd ≠ .load l pc p := by intro _ _ _ h; cases h) :
    StmtPtrs V vs lbl pc σ (σ.def res nd) st s := by
  refine ⟨fun j l pc' p hj h => absurd (getElem?_snoc_ge hj h).2 (hnd l pc' p),
    fun l pc' v p h => ?_⟩
  simp only [SState.def, List.drop_length, List.not_mem_nil] at h

/-- A statement that appends two nodes, neither a `load`, and no effect has no pointer facts. -/
theorem SState.def₂_ptrs {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat}
    {σ : SState} {res : Option Nat} {nd₁ nd₂ : SNode} {st : Stmt} {s : Scope}
    (hnd₁ : ∀ l pc p, nd₁ ≠ .load l pc p := by intro _ _ _ h; cases h)
    (hnd₂ : ∀ l pc p, nd₂ ≠ .load l pc p := by intro _ _ _ h; cases h) :
    StmtPtrs V vs lbl pc σ ((σ.def none nd₁).def res nd₂) st s := by
  refine ⟨fun j l pc' p hj h => ?_, fun l pc' v p h => ?_⟩
  · by_cases hj' : j < (σ.def none nd₁).nodes.length
    · have h' : (σ.def none nd₁).nodes[j]? = some (.load l pc' p) := by
        rw [← List.getElem?_append_left (l₂ := [nd₂]) hj']
        exact h
      exact absurd (getElem?_snoc_ge (l := σ.nodes) hj h').2 (hnd₁ l pc' p)
    · exact absurd (getElem?_snoc_ge (l := (σ.def none nd₁).nodes) (Nat.le_of_not_lt hj') h).2
        (hnd₂ l pc' p)
  · simp only [SState.def, List.drop_length, List.not_mem_nil] at h

/-- The node `SNode.fbinOf` makes has the value of the `SNode.fbinP` node of the same operator,
operands and `fmul contract` operand terms. -/
theorem SNode.eval_fbinOf (V : Valuation) (vs : List (Except Fault Val)) (op : FBinOp)
    (fm : FastMath) (ft : FloatTy) (n : Nat) (a b : SVal) (pa pb : Option (SVal × SVal)) :
    (SNode.fbinOf op fm ft n a b pa pb).eval V vs =
      (SNode.fbinP op fm ft n a b pa pb).eval V vs := by
  cases pa <;> cases pb <;> rfl

/-- The `fmul contract` operand terms of the node `SNode.fbinOf` makes: its operands for
`fmul contract`, none otherwise. -/
theorem SNode.factors_fbinOf (op : FBinOp) (fm : FastMath) (ft : FloatTy) (n : Nat) (a b : SVal)
    (pa pb : Option (SVal × SVal)) :
    (SNode.fbinOf op fm ft n a b pa pb).factors =
      if op == .fmul && fm.contract then some (a, b) else none := by
  cases pa <;> cases pb <;> rfl

end MojoProof.Sym
