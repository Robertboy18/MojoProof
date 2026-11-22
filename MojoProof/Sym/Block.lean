import MojoProof.Sym.Checker
import MojoProof.Sem.Schedule

/-!
# Soundness of the block checker

The block checker (`covers`, `coversTo` and `summarize`, MojoProof/Sym/Checker.lean) is sound
for every program: a thread runs a block that the checker accepts as its summary says, when the
summary's obligations hold. The proof relates the symbolic state to the thread's frame and memory
statement by statement (`Rel`, `SState.stmt_sound`, with the `exec_*` lemmas for the statements
of the fragment), then the terminator's step to the summary's exit (`SState.exitAt_sound`).

`Block.sound`: for every program `P`, function `fn`, label `lbl`, position `p0`, conditions `ds`
and summary `S` with `covers P fn lbl p0 ds S = true`, every context `c` of program `P` and
thread whose innermost frame `f` runs `fn` at block `lbl` and position `p0`, with memory `m`,
if every condition of `ds` holds under the entry valuation (`Valuation.entry`) and the values of
`S`'s table (`vals`), the block ends (`Ends`): the thread's steps (`Steps`) reach the block's end
without a fault, at step count `t.k + S.len` (one step per statement), with a frame whose
registers and `fmul contract` operands are the summary's (`regVal`, `regProd`) and other fields
the entry frame's, and memory that the summary's effects make from `m` (`SEff.run`); and the
terminator's step there is the summary exit's (`Exit.next`), without a fault. `Block.sound` is
the instance of `Block.sound_with`, for any exit function whose exit is the terminator's step when
its obligations hold (`SState.exitAt_sound`); its instance `Block.sound_to` is the same for
`coversTo P fn lbl p0 d₀` when the exit goes to `d₀` (`Exit.dest`, `SState.exitTo_sound`).

`Block.soundC`: the same for the checker with `fmul contract` (`coversC`), concluding `EndsC`:
`Ends` with the frame's `fmul contract` operands at the block's end given by the table
(`regProdIn`: for a register the block sets, the values of its node's `fmul contract` operand
terms). Both are instances of `Block.sound_withC`, whose relation `Rel` holds the frame's
products as `regProdIn` (`Rel.prods`, `Rel.fwf`); `Block.sound_with` gets `Ends` from it by
`Ends.of_C`, since without `fmul contract` no node of the table has operand terms
(`summarizeWith_factors`).

`Block.sound_pathI`: `Block.sound` along a path of the control-flow graph of any length, for
every program `P`, function `fn` and path `(l, ds, S) :: ps` (blocks with their conditions and
summaries) that the path checker accepts (`coversPathI`: the first block from position `p0`,
each one after from the position its edge enters it at, `Exit.pc`: after its `phi`s for
`Exit.phi`, else 0; each block but the last by `covers`, or by `coversTo` for the edge into the
next block), every context of `P` and thread at block `l`'s position `p0`: if the
path's premises hold (`WalkI`: each block's conditions hold under its entry valuation, which is
`Valuation.into` of the block before, with the step count after its statements and branch, the
memory of its effects, and its registers and `fmul contract` operands with the target's `phi`s
set as `enter` sets them; each exit but the last goes to the next block, `Exit.dest`), the
thread's steps run every block, each edge by `Ends.edge`, and the last one ends from its entry
valuation (`Valuation.lastI`), at step count `t.k + pathLen S ps` (`Valuation.lastI_k`).
`Block.sound_retR`: a path whose last block returns (`ret void`), under any caller frames: its steps
reach the last block's end, on the memory the last block's effects make, and the next step is the
`ret`'s: `.done` without a caller (`Block.sound_retI`, a thread with one frame), else back to the
caller after its call. `Ret`: a path whose premises with `phi`s hold, whose last exit is `ret` and
whose last block's effects succeed with a memory of a predicate `Q` (used by the loop theorems,
Sym/Loop.lean, and the kernel theorem, Sym/Kernel.lean). `Block.sound_back`: then the
caller's block from the position after the call ends too (`Block.sound` there). `Block.sound_path`
and `Block.sound_ret` are their corollaries for the path checker without `phi`s (`coversPath`,
`Walk`, `Valuation.last`), through `Walk.toI`: there every exit has a target (`Exit.target`), whose
step enters it at position 0 and resolves no `phi` (`Exit.next_target`), and `Valuation.into` is
`Valuation.after` (`Exit.of_target`).

With `fmul contract`: `Valuation.afterC` and `Valuation.intoC` are `Valuation.after` and
`Valuation.into` with the table's `fmul contract` operands (`regProdIn`), and `Ends.edgeC` is
`Ends.edge` from `EndsC`. Each pair is the instance with and without `contract` of one
declaration (`prodsWith`, `Valuation.afterWith`, `Valuation.intoWith`, `EndsWith`,
`Ends.edgeWith`, `EndsWith.pre`), proved once. `Block.sound_pathC`: a path that `coversPathI`
accepts, then the block its last exit goes to, accepted by `coversC`: it ends (`EndsC`) from
`Valuation.into` of the path's last block.
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
  /-- The block is the entry frame's. -/
  label : fi.label = f.label
  /-- The `alloca` blocks are the entry frame's. -/
  allocas : fi.allocas = f.allocas
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
  /-- The memory is the one the state's effects make. -/
  mem : SEff.run V vs σ.effs = .ok mi
  /-- Before a `store`, the memory is the entry memory with another trace. -/
  trace : σ.stored = false → ∃ tr, mi = { V.mem with trace := tr }

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
  · cases h

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

/-- The `fmul contract` operands an operand carries in frame `f`: a register's. -/
def valProd (f : Frame) : Value → Option (Val × Val)
  | .loc r => f.prods r
  | _ => none

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

/-- `Rel` after a statement that appends a node `nd` and sets register `res` (if any) to the
node's value `x` with `fmul contract` operands `pr`, with the memory unchanged: when `nd`'s
`fmul contract` operand terms refer to nodes of the table and their values are `pr`. -/
theorem Rel.defP {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) (res : Option Nat) {nd : SNode} {x : Val}
    {pr : Option (Val × Val)} (hv : (SVal.node σ.nodes.length).eval V vs = .ok x)
    (hfw : ∀ (pq : SVal × SVal) (j : Nat), nd.factors = some pq →
      (pq.1 = .node j ∨ pq.2 = .node j) → j < σ.nodes.length)
    (hp : nd.factors.bind (prodVal V vs) = pr) :
    Rel V vs f (σ.def res nd) { fi.set res (some x) pr with pc := fi.pc + 1 } mi := by
  have hlen : (σ.def res nd).nodes.length = σ.nodes.length + 1 := by
    simp only [SState.def, List.length_append, List.length_singleton]
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
    refine ⟨hR.fn, hR.label, hR.allocas, hR.dest, hR.regs,
      fun s => (hR.prods s).trans (regProdIn_append hR.wf [nd] s).symm, fun r y hy => ?_, hfw',
      hR.mem, hR.trace⟩
    obtain ⟨j, rfl, hj⟩ := hR.wf r y hy
    exact ⟨j, rfl, by rw [hlen]; omega⟩
  | some r =>
    refine ⟨hR.fn, hR.label, hR.allocas, hR.dest, fun s => ?_, fun s => ?_, fun s u hu => ?_,
      hfw', hR.mem, hR.trace⟩
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

/-- `Rel` after a statement that appends a node with no `fmul contract` operand terms and sets
register `res` (if any) to the node's value `x`, with the memory unchanged (`Rel.defP`). -/
theorem Rel.def {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi : Mem} (hR : Rel V vs f σ fi mi) (res : Option Nat) {nd : SNode} {x : Val}
    (hv : (SVal.node σ.nodes.length).eval V vs = .ok x) (hnd : nd.factors = none := by rfl) :
    Rel V vs f (σ.def res nd) { fi.set res (some x) none with pc := fi.pc + 1 } mi :=
  hR.defP res hv (fun _ _ h => by rw [hnd] at h; cases h) (by rw [hnd]; rfl)

/-- `Rel` after an effect `e` that applies to the memory. -/
theorem Rel.push {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi mi' : Mem} {e : SEff} (hR : Rel V vs f σ fi mi) (he : e.apply V vs mi = .ok mi')
    (htr : σ.stored = false → ∃ tr, mi' = { V.mem with trace := tr }) :
    Rel V vs f { σ with effs := σ.effs ++ [e] } fi mi' :=
  ⟨hR.fn, hR.label, hR.allocas, hR.dest, hR.regs, hR.prods, hR.wf, hR.fwf,
    SEff.run_append hR.mem he, htr⟩

/-- `Rel` after a `store` effect `e` that applies to the memory. -/
theorem Rel.store {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame} {σ : SState}
    {mi mi' : Mem} {e : SEff} (hR : Rel V vs f σ fi mi) (he : e.apply V vs mi = .ok mi') :
    Rel V vs f { σ with effs := σ.effs ++ [e], stored := true } { fi with pc := fi.pc + 1 } mi' :=
  ⟨hR.fn, hR.label, hR.allocas, hR.dest, hR.regs, hR.prods, hR.wf, hR.fwf,
    SEff.run_append hR.mem he, by intro h; cases h⟩

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

/-- A summary without `fmul contract` (`summarizeWith` with `contract = false`) has no
`fmul contract` node. -/
theorem summarizeWith_factors {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {S : Summary}
    (h : summarizeWith P fn lbl p0 ex = some S) : ∀ nd ∈ S.nodes, nd.factors = none := by
  unfold summarizeWith at h
  split at h
  · split at h
    · rename_i σ hσ
      split at h
      · cases h
        exact SState.run_factors hσ (fun _ hnd => by cases hnd)
      · cases h
    · cases h
  · cases h

/-! ### The statements `exec` runs -/

/-- `exec` of an integer operator. -/
theorem exec_bin {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fl t a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .bin op fl t a b)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun _ => intBin (c.prog.layout.scalarBits t.elt) op fl) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `icmp`. -/
theorem exec_icmp {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {p t a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .icmp p t a b)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : icmpV c.prog.layout s.mem p t x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of a cast. -/
theorem exec_cast {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op t a ty x r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .cast op (.mk t a) ty)
    (ha : evalV s t a = .ok x) (hr : castV c.prog.layout s.mem op t x ty s.ch = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `extractvalue`. -/
theorem exec_extract {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {t a is x r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .extractvalue (.mk t a) is)
    (ha : evalV s t a = .ok x) (hr : extractV x is = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of a `getelementptr`. -/
theorem exec_gep {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fl src a b idx is pv r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .gep fl src (.mk (.ptr a) b) idx)
    (hidx : evalTVs s idx = .ok is) (hb : evalV s (.ptr a) b = .ok pv)
    (hr : MojoProof.Sem.gep c.prog.layout s.mem fl src a is pv = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hidx, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of a `load`. -/
theorem exec_load {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {vol t a p al pv q v}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .load vol t (.mk (.ptr a) p) al)
    (hp : evalV s (.ptr a) p = .ok pv) (hq : pv.addr? = .ok q)
    (hv : s.mem.load c.prog.layout c.who a t q (some (al.getD (c.prog.layout.align t))) = .ok v)
    (hu : (st.md.any (·.1 == "noundef") && !v.defined) = false) :
    exec c s k f st = .ok (.next { f.set st.res (some v) none with pc := f.pc + 1 }
      (s.mem.log (.access ⟨c.who, q, c.prog.layout.stored t, false, none,
        st.md.any (·.1 == "invariant.load")⟩))) := by
  simp only [exec, hmd, hi, hp, hq, hv, hu, bind, Except.bind, pure, Except.pure,
    Bool.false_eq_true, ↓reduceIte]

/-- `exec` of a `store`. -/
theorem exec_store {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {vol t v a p al x pv q m'} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .store vol (.mk t v) (.mk (.ptr a) p) al) (hx : evalV s t v = .ok x)
    (hp : evalV s (.ptr a) p = .ok pv) (hq : pv.addr? = .ok q)
    (hm : s.mem.store c.prog.layout c.who a t x q (some (al.getD (c.prog.layout.align t))) =
      .ok m') :
    exec c s k f st = .ok (.next { f with pc := f.pc + 1 } m') := by
  simp only [exec, hmd, hi, hx, hp, hq, hm, bind, Except.bind, pure, Except.pure]

/-- `exec` of a float operator: for every context, scope, step count and frame, a statement whose
metadata `checkMd` accepts, on floats `ft`, whose operands evaluate to `x` and `y` and on which
`floatBin` gives `r` lane by lane with the operands' `fmul contract` operands in the frame: the
register is `r`, with the `fmul contract` operands `(x, y)` when the statement is
`fmul contract`, none otherwise. -/
theorem exec_fbinC {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fm t ft a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .fbin op fm t a b) (he : t.elt = .fp ft)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun i u v => floatBin ft op fm u v (laneOf (valProd f a) i)
      (laneOf (valProd f b) i) (s.ch i)) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r)
      (if op == .fmul && fm.contract then some (x, y) else none) with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, he, ha, hb, bind, Except.bind, pure, Except.pure]
  split
  · rename_i e' heq
    cases hr.symm.trans heq
  · rename_i r' heq
    cases hr.symm.trans heq
    rfl

/-- `exec` of a float operator but `fmul contract` (`exec_fbinC`, with no `fmul contract`
operands). -/
theorem exec_fbin {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fm t ft a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .fbin op fm t a b) (he : t.elt = .fp ft)
    (hc : (op == .fmul && fm.contract) = false)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun i u v => floatBin ft op fm u v (laneOf (valProd f a) i)
      (laneOf (valProd f b) i) (s.ch i)) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  rw [exec_fbinC hmd hi he ha hb hr, hc]
  rfl

/-- `exec` of a call of a special register: a declaration that `P.intrinsics` names `sreg r d`,
with no arguments and no fast-math flags, whose attributes `Func.check` accepts. -/
theorem exec_sreg {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fm ty g fn r d w}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .call fm ty (.fn g) [])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some (.sreg r d)) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hc : fn.check c.prog.module (some (.sreg r d)) = .ok ())
    (hw : withAttrs c.prog.layout s.mem fn.ret fn.retAttrs
      (.bits 32 (BitVec.ofNat 32 (c.env.sreg r d))) = .ok w) :
    exec c s k f st = .ok (.next { f.set st.res (some w) none with pc := f.pc + 1 } s.mem) := by
  have hu : ownUndef c s (.sreg r d) [] = false := rfl
  simp only [exec, hmd, hi, hfn, hg, hfm, hd, hc, hw, hu, intrinsic, List.mapM_nil,
    List.zip_nil_right, List.all_nil, Bool.true_or, Bool.not_true, Bool.and_false,
    Option.mapM_some, Functor.map, Except.map, bind, Except.bind, pure, Except.pure,
    Bool.false_eq_true, ↓reduceIte]

/-- `exec` of a `select`: for every context, scope, step count and frame, a statement whose
metadata `checkMd` accepts, whose condition and operands evaluate, and on which `selectV` gives
`r`, sets its register to `r` and moves to the next statement, on the same memory. -/
theorem exec_select {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {ct cv t a tb b x y z r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .select (.mk ct cv) (.mk t a) (.mk tb b))
    (hc : evalV s ct cv = .ok x) (ha : evalV s t a = .ok y) (hb : evalV s t b = .ok z)
    (hr : selectV t x y z = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hc, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- For every layout, memory, type and value, `withAttrs` with no attribute gives the value. -/
theorem withAttrs_nil (l : Layout) (m : Mem) (t : Ty) (v : Val) :
    withAttrs l m t [] v = .ok v := by
  have hm : ∀ xs : List Val, xs.mapM (fun x => (pure x : Except Fault Val)) = .ok xs := by
    intro xs
    induction xs with
    | nil => rfl
    | cons x xs ih => rw [List.mapM_cons, ih]; rfl
  unfold withAttrs
  simp only [List.foldlM_nil]
  split
  · rw [hm]; rfl
  · rfl

/-- For every signedness and direction, a result of `intMinMax` is defined exactly when both
operands are (a `poison` operand gives `poison`; `undef` and other operands fault). -/
theorem intMinMax_defined {signed max : Bool} {x y r : Val}
    (h : intMinMax signed max x y = .ok r) : r.defined = (x.defined && y.defined) := by
  rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _ <;>
    simp only [intMinMax, strict2] at h <;>
    (try split at h) <;> cases h <;> simp [Val.defined]

/-- For every signedness and direction, a result of `intMinMax` is that of `lanes2` on it (two
vectors fault in `intMinMax`, so `lanes2` applies it to the operands). -/
theorem lanes2_intMinMax {signed max : Bool} {x y r : Val}
    (h : intMinMax signed max x y = .ok r) :
    lanes2 (fun _ => intMinMax signed max) x y = .ok r := by
  cases x <;> cases y <;> first | exact h | cases h

/-- `exec` of a call of an integer maximum or minimum: for every context, scope, step count and
frame, a statement whose metadata `checkMd` accepts and that calls a declaration that
`c.prog.intrinsics` names `minmax sg mx t`, with two parameters, no fast-math flags and no
parameter, return or call-site attributes, whose attributes `Func.check` accepts, on two operands
that evaluate and on which `intMinMax sg mx` gives `r`, sets its register to `r` and moves to the
next statement, on the same memory. -/
theorem exec_minmax {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {fm ty g ta a tb b fn sg mx t x y r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .call fm ty (.fn g) [(.mk ta a, []), (.mk tb b, [])])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some (.minmax sg mx t)) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hra : fn.retAttrs = []) (hl : fn.params.length = 2)
    (hpa : fn.params.all (·.attrs.isEmpty) = true)
    (hc : fn.check c.prog.module (some (.minmax sg mx t)) = .ok ())
    (ha : evalV s ta a = .ok x) (hb : evalV s tb b = .ok y) (hr : intMinMax sg mx x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  obtain ⟨p, q, hpq⟩ := List.length_eq_two.1 hl
  rw [hpq] at hpa
  simp only [List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true, List.isEmpty_iff]
    at hpa
  obtain ⟨hp, hq⟩ := hpa
  have hlr := lanes2_intMinMax hr
  have hu : ownUndef c s (.minmax sg mx t) [x, y] = !(x.defined && y.defined) := by
    simp only [ownUndef, intrinsic, hlr, ← intMinMax_defined hr, bind, Except.bind, pure,
      Except.pure]
  cases hxy : (x.defined && y.defined) <;>
  simp [exec, hmd, hi, hfn, hg, hfm, hd, hc, hpq, hp, hq, hra, ha, hb, hu, hxy, hlr, evalTV,
    withAttrs_nil, intrinsic, bind, Except.bind, pure, Except.pure]

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

/-- `enter` keeps the frame's function, `alloca` blocks and caller's register, and gives block
`d` at the position after its `phi`s (`phiCount`). -/
theorem enter_fields {s : Scope} {f f' : Frame} {d : Nat} (h : enter s f d = .ok f') :
    f'.fn = f.fn ∧ f'.label = d ∧ f'.pc = phiCount f.fn d ∧ f'.allocas = f.allocas ∧
      f'.dest = f.dest := by
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
      · exact ⟨rfl, rfl, by simp only [phiCount, hb]; rfl, rfl, rfl⟩
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

/-- The stored operand `w` of a `store` whose effect stores the term `x`, with register entries
`regs`: a register `r` that is `x` (`.reg r`, its value at the block's entry) or that an entry of
`regs` sets to `x`, or another operand, whose term `x` is an integer constant. -/
def StoreVal (regs : List (Nat × SVal)) (x : SVal) : Value → Prop
  | .loc r => x = .reg r ∨ (r, x) ∈ regs
  | _ => ∃ n i, x = .int n i

/-- Statement `pc` of block `lbl` of function `fn` is a `store` whose stored operand the term `x`
describes with register entries `regs` (`StoreVal`). -/
def StoreAt (fn : Func) (lbl pc : Nat) (regs : List (Nat × SVal)) (x : SVal) : Prop :=
  ∃ b st vol t w ptr al, fn.blocks.find? (·.label == lbl) = some b ∧ b.stmts[pc]? = some st ∧
    st.inst = .store vol (.mk t w) ptr al ∧ StoreVal regs x w

/-- The entry `x` of operand `w` describes it (`StoreVal`) with the register entries of the state
and any entries put in front of them. -/
theorem SState.op_storeVal {σ : SState} {t : Ty} {w : Value} {x : SVal}
    (h : σ.op t w = some x) (rs : List (Nat × SVal)) : StoreVal (rs ++ σ.regs) x w := by
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
    exact ⟨_, _, rfl⟩
  · cases h

/-- The pointer facts of statement `st` at position `pc` of block `lbl`, which takes state `σ`
to `σ'`, run in scope `s`, with the values `vs` of the final table: a `load` node it appends is
node `σ.nodes.length`, at `lbl` and `pc`, and the statement's pointer operand evaluates in `s` to
the node's pointer term on the values of the nodes before it; a `store` effect it appends is at
`lbl` and `pc`, the operand evaluates in `s` to the effect's pointer term on `vs`, and the stored
term is the entry `σ.op` gives the stored operand. -/
def StmtPtrs (V : Valuation) (vs : List (Except Fault Val)) (lbl pc : Nat) (σ σ' : SState)
    (st : Stmt) (s : Scope) : Prop :=
  (∀ j l pc' p, σ.nodes.length ≤ j → σ'.nodes[j]? = some (.load l pc' p) →
    j = σ.nodes.length ∧ l = lbl ∧ pc' = pc ∧ PtrIs true st s (p.eval V (vals V σ.nodes))) ∧
  ∀ l pc' v p, SEff.store l pc' v p ∈ σ'.effs.drop σ.effs.length →
    l = lbl ∧ pc' = pc ∧ PtrIs false st s (p.eval V vs) ∧
      ∃ vol t w ptr al, st.inst = .store vol (.mk t w) ptr al ∧ σ.op t w = some v

/-- The entry at or past the length of a list with one more element is that element. -/
theorem getElem?_snoc_ge {α : Type} {l : List α} {a b : α} {j : Nat} (hj : l.length ≤ j)
    (h : (l ++ [a])[j]? = some b) : j = l.length ∧ a = b := by
  rw [List.getElem?_append_right hj] at h
  obtain ⟨hlt, he⟩ := List.getElem?_eq_some_iff.1 h
  simp only [List.length_singleton] at hlt
  exact ⟨by omega, by simpa only [List.getElem_singleton] using he⟩

/-- A statement that appends a node other than a `load` and no effect has no pointer facts. -/
theorem SState.def_ptrs {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat}
    {σ : SState} {res : Option Nat} {nd : SNode} {st : Stmt} {s : Scope}
    (hnd : ∀ l pc p, nd ≠ .load l pc p := by intro _ _ _ h; cases h) :
    StmtPtrs V vs lbl pc σ (σ.def res nd) st s := by
  refine ⟨fun j l pc' p hj h => absurd (getElem?_snoc_ge hj h).2 (hnd l pc' p),
    fun l pc' v p h => ?_⟩
  simp only [SState.def, List.drop_length, List.not_mem_nil] at h

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

/-- A statement in the fragment whose obligations hold and whose effects run, in a final table
that extends the next state's: `exec` runs it to a frame and memory that the next state
describes, and its pointer facts hold in the scope `exec` runs it in (`StmtPtrs`). -/
theorem SState.stmt_sound {V : Valuation} {vs : List (Except Fault Val)} {P : Program}
    {lbl n k : Nat} {f fi : Frame} {σ σ' : SState} {mi : Mem} {st : Stmt} {contract : Bool}
    (hP : V.ctx.prog = P) (hR : Rel V vs f σ fi mi) (hk : k = V.k + n)
    (hst : V.stmt lbl fi.pc = some st) (h : σ.stmt P lbl fi.pc n st contract = some σ')
    (hO : ∀ d ∈ σ'.obls, d.Holds V vs)
    (hM : ∃ m, SEff.run V vs σ'.effs = .ok m) (hN : ∃ ws, vs = vals V σ'.nodes ++ ws) :
    ∃ fi' mi', exec V.ctx (V.ctx.scope mi fi k) k fi st = .ok (.next fi' mi') ∧
      Rel V vs f σ' fi' mi' ∧ fi'.pc = fi.pc + 1 ∧
      StmtPtrs V vs lbl fi.pc σ σ' st (V.ctx.scope mi fi k) := by
  subst hP hk
  obtain ⟨ws, hN⟩ := hN
  -- an operand's value on the values before the new node is its value in the final table
  have lift : ∀ {us t a x v}, σ.op t a = some x → vs = vals V σ.nodes ++ us →
      x.eval V (vals V σ.nodes) = .ok v → x.eval V vs = .ok v := by
    intro us t a x v hx hus hv
    rw [hus]
    exact SVal.eval_append (by rw [vals_length]; exact SState.op_wf hR hx) hv us
  unfold SState.stmt at h
  split at h
  case isFalse => cases h
  rename_i hmd
  have hmd := isOk_unit hmd
  split at h
  · -- bin
    rename_i op fl t a b hi
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨w, hw⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hw', hus⟩ := SState.node_ok hN hw
    simp only [SNode.eval] at hw'
    obtain ⟨u, hu, hw'⟩ := Except.bind_eq_ok.1 hw'
    obtain ⟨u', hu', hw'⟩ := Except.bind_eq_ok.1 hw'
    exact ⟨_, _, exec_bin hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu')) hw', hR.def st.res hw, rfl, SState.def_ptrs⟩
  · -- icmp
    rename_i p w a b hi
    split at h
    · cases h
    · rename_i hns
      obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
      obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨tr, htr⟩ := hR.trace (Bool.eq_false_of_ne_true hns)
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hv', hus⟩ := SState.node_ok hN hv
      simp only [SNode.eval] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
      subst htr
      exact ⟨_, _, exec_icmp hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
        (SState.op_eval hR rfl hy (lift hy hus hu'))
        ((icmpV_retrace V.ctx.prog.layout V.mem tr p (.int w) u u').trans hv'),
        hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- cast
    rename_i op ts a t hi
    split at h
    · rename_i hop
      obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hv', hus⟩ := SState.node_ok hN hv
      simp only [SNode.eval] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      exact ⟨_, _, exec_cast hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
        (by rcases hop with rfl | rfl | rfl <;> exact hv'), hR.def st.res hv, rfl, SState.def_ptrs⟩
    · cases h
  · -- extractvalue
    rename_i t a is hi
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_extract hmd hi (SState.op_eval hR rfl hx (lift hx hus hu)) hv',
      hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- getelementptr
    rename_i fl src as b ti i hi
    split at h
    · cases h
    · rename_i hns
      obtain ⟨xi, hxi, h⟩ := Option.bind_eq_some_iff.1 h
      obtain ⟨xb, hxb, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨tr, htr⟩ := hR.trace (Bool.eq_false_of_ne_true hns)
      have hst' := stmt_inst hst hi
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hv', hus⟩ := SState.node_ok hN hv
      simp only [SNode.eval, hst'] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
      subst htr
      have h1 := SState.op_eval hR (s := V.ctx.scope { V.mem with trace := tr } fi (V.k + n)) rfl
        hxi (lift hxi hus hu)
      have hidx : evalTVs (V.ctx.scope { V.mem with trace := tr } fi (V.k + n)) [.mk ti i] =
          .ok [u] := by
        simp only [evalTVs, evalTV]
        rw [h1]; rfl
      exact ⟨_, _, exec_gep hmd hi hidx (SState.op_eval hR rfl hxb (lift hxb hus hu'))
        ((gep_retrace V.ctx.prog.layout V.mem tr fl src as [u] u').trans hv'),
        hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- load
    rename_i vol ty as p al hi
    split at h
    · cases h
    · rename_i hns
      obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨tr, htr⟩ := hR.trace (Bool.eq_false_of_ne_true hns)
      have hst' := stmt_inst hst hi
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hv', hus⟩ := SState.node_ok hN hv
      simp only [SNode.eval, hst'] at hv'
      obtain ⟨pv, hpv, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨q, hq, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨v₀, hv₀, hv'⟩ := Except.bind_eq_ok.1 hv'
      have hpv' := lift hx hus hpv
      cases hu : (st.md.any (·.1 == "noundef") && !v₀.defined)
      · rw [hu] at hv'
        cases hv'
        subst htr
        refine ⟨_, _, exec_load hmd hi (SState.op_eval hR rfl hx hpv') hq
          ((Mem.load_retrace V.ctx.prog.layout V.mem tr V.ctx.who as ty q
            (some (al.getD (V.ctx.prog.layout.align ty)))).trans hv₀) hu, ?_, rfl,
          fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
        · exact (hR.def st.res hv).push
            (by simp only [SEff.apply, hst', hpv', hq, bind, Except.bind, pure, Except.pure,
              Ctx.scope])
            (fun _ => ⟨_, rfl⟩)
        · obtain ⟨rfl, he⟩ := getElem?_snoc_ge hj hn
          cases he
          exact ⟨rfl, rfl, rfl, as, p, vol, ty, al, hi,
            (SState.op_eval hR rfl hx hpv').trans hpv.symm⟩
        · simp only [List.drop_left, List.mem_singleton, reduceCtorEq] at hm
      · rw [hu] at hv'
        cases hv'
  · -- store
    rename_i vol t v as p al hi
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    have hst' := stmt_inst hst hi
    obtain ⟨mf, hmf⟩ := hM
    obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc hmf
    cases Except.ok.inj (h₀.symm.trans hR.mem)
    have he' := he
    simp only [SEff.apply, hst'] at he
    obtain ⟨xv, hxv, he⟩ := Except.bind_eq_ok.1 he
    obtain ⟨pv, hpv, he⟩ := Except.bind_eq_ok.1 he
    obtain ⟨q, hq, he⟩ := Except.bind_eq_ok.1 he
    refine ⟨_, _, exec_store hmd hi (SState.op_eval hR rfl hx hxv) (SState.op_eval hR rfl hy hpv)
      hq he, hR.store he', rfl, fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
    · simp only [List.getElem?_eq_none hj, reduceCtorEq] at hn
    · simp only [List.drop_left, List.mem_singleton, SEff.store.injEq] at hm
      obtain ⟨rfl, rfl, rfl, rfl⟩ := hm
      exact ⟨rfl, rfl, ⟨as, p, vol, _, al, hi, (SState.op_eval hR rfl hy hpv).trans hpv.symm⟩,
        vol, t, v, _, al, hi, hx⟩
  · -- fbin
    rename_i op fm t a b hi
    split at h
    · rename_i ft he
      split at h
      · cases h
      · obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
        obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        obtain ⟨w, hw⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hw', hus⟩ := SState.node_ok hN hw
        rw [SNode.eval_fbinOf] at hw'
        simp only [SNode.eval] at hw'
        obtain ⟨u, hu, hw'⟩ := Except.bind_eq_ok.1 hw'
        obtain ⟨u', hu', hw'⟩ := Except.bind_eq_ok.1 hw'
        have hxu := lift hx hus hu
        have hyu := lift hy hus hu'
        -- a term on nodes of the table has its value on the values before the new node
        have ext : ∀ z : SVal, (∀ j, z = .node j → j < σ.nodes.length) →
            z.eval V vs = z.eval V (vals V σ.nodes) := by
          intro z hz
          cases z with
          | node j =>
            simp only [SVal.eval]
            rw [hus, List.getElem?_append_left (by rw [vals_length]; exact hz j rfl)]
          | _ => rfl
        -- an operand's `fmul contract` operands are its entry's: an entry register's, or the
        -- values of its node's `fmul contract` operand terms
        have hp : ∀ {t : Ty} {a : Value} {x : SVal}, σ.op t a = some x →
            valProd fi a = x.prodsWith V (vals V σ.nodes) (x.factors σ.nodes) := by
          intro t a x h
          unfold SState.op at h
          split at h
          · rename_i r
            cases h
            show fi.prods r = _
            rw [hR.prods r]
            unfold regProdIn SState.get
            cases hl : σ.regs.lookup r with
            | some y =>
              obtain ⟨j, rfl, -⟩ := hR.wf r y hl
              show ((SVal.node j).factors σ.nodes).bind (prodVal V vs) =
                (SVal.node j).prodsWith V (vals V σ.nodes) ((SVal.node j).factors σ.nodes)
              cases hf : (SVal.node j).factors σ.nodes with
              | none => rfl
              | some pq =>
                show prodVal V vs pq = prodVal V (vals V σ.nodes) pq
                unfold prodVal
                rw [ext pq.1 fun i hi => hR.fwf _ pq i hf (.inl hi),
                  ext pq.2 fun i hi => hR.fwf _ pq i hf (.inr hi)]
            | none => rfl
          · cases h
            rfl
          · cases h
        refine ⟨_, _, exec_fbinC hmd hi he (SState.op_eval hR rfl hx hxu)
          (SState.op_eval hR rfl hy hyu) (by rw [hp hx, hp hy]; exact hw'),
          hR.defP st.res hw (fun pq j hf hj => ?_) ?_, rfl,
          SState.def_ptrs fun _ _ _ h => by unfold SNode.fbinOf at h; split at h <;> cases h⟩
        · -- the new node's `fmul contract` operand terms are its operands
          rw [SNode.factors_fbinOf] at hf
          split at hf
          · cases hf
            rcases hj with hj | hj
            · exact SState.op_wf hR hx j hj
            · exact SState.op_wf hR hy j hj
          · cases hf
        · -- whose values are the operands'
          rw [SNode.factors_fbinOf]
          cases (op == .fmul && fm.contract)
          · rfl
          · show prodVal V vs (x, y) = some (u, u')
            simp only [prodVal, hxu, hyu, Except.toOption]
            rfl
    · cases h
  · -- a call of a special register
    rename_i fm ty g hi
    split at h
    · cases h
    · rename_i hns
      split at h
      · rename_i fn hfn
        split at h
        · rename_i r d hg
          split at h
          · rename_i hc
            cases h
            simp only [Bool.and_eq_true] at hc
            obtain ⟨⟨hfm, hd⟩, hck⟩ := hc
            obtain ⟨tr, htr⟩ := hR.trace (Bool.eq_false_of_ne_true hns)
            have hst' := stmt_inst hst hi
            obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
            obtain ⟨hv', -⟩ := SState.node_ok hN hv
            simp only [SNode.eval, hst', hfn, hg] at hv'
            subst htr
            exact ⟨_, _, exec_sreg hmd hi hfn hg hfm hd (isOk_unit hck)
              ((congrFun (withAttrs_retrace _ _ tr _ _) _).trans hv'), hR.def st.res hv, rfl,
              SState.def_ptrs⟩
          · cases h
        · cases h
      · cases h
  · -- select
    rename_i ct cv w a tb b hi
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨z, hz, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u'', hu'', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_select hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu')) (SState.op_eval hR rfl hz (lift hz hus hu''))
      hv', hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- a call of an integer maximum or minimum
    rename_i fm ty g ta a tb b hi
    split at h
    · rename_i fn sg mx t hfn hg
      split at h
      · rename_i hc
        obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
        obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        simp only [Bool.and_eq_true] at hc
        obtain ⟨⟨⟨⟨⟨hfm, hd⟩, hra⟩, hl⟩, hpa⟩, hck⟩ := hc
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hv', hus⟩ := SState.node_ok hN hv
        simp only [SNode.eval] at hv'
        obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
        exact ⟨_, _, exec_minmax hmd hi hfn hg hfm hd (List.isEmpty_iff.1 hra)
          (beq_iff_eq.1 hl) hpa (isOk_unit hck) (SState.op_eval hR rfl hx (lift hx hus hu))
          (SState.op_eval hR rfl hy (lift hy hus hu')) hv', hR.def st.res hv, rfl,
          SState.def_ptrs⟩
      · cases h
    · cases h
  · cases h

/-- The obligations of `σ` hold and its effects run, in final table `vs`, which extends the
values of `σ`'s table. -/
def Good (V : Valuation) (vs : List (Except Fault Val)) (σ : SState) : Prop :=
  (∀ d ∈ σ.obls, d.Holds V vs) ∧ (∃ m, SEff.run V vs σ.effs = .ok m) ∧
    ∃ ws, vs = vals V σ.nodes ++ ws

/-- Thread `t` on memory `m` steps (`Steps`) to statement `st` at position `pc` of block `lbl`
of function `fn`, in a frame above frames `rest`: `st` is a `load` (`true`) or a `store`
(`false`) whose pointer operand evaluates in the thread's scope there to `pv` (`PtrIs`). -/
def PtrAt (c : Ctx) (t : Thread) (m : Mem) (rest : List Frame) (fn : Func) (lbl pc : Nat)
    (ld : Bool) (pv : Except Fault Val) : Prop :=
  ∃ f k m' b st, Steps c t m ⟨f :: rest, k⟩ m' ∧ f.fn = fn ∧ f.label = lbl ∧ f.pc = pc ∧
    fn.blocks.find? (·.label == lbl) = some b ∧ b.stmts[pc]? = some st ∧
    PtrIs ld st (c.scope m' f k) pv

/-- `PtrAt` after steps before it. -/
theorem PtrAt.pre {c : Ctx} {t t₁ : Thread} {m m₁ : Mem} {rest : List Frame} {fn : Func}
    {lbl pc : Nat} {ld : Bool} {pv : Except Fault Val} (h : Steps c t m t₁ m₁)
    (hq : PtrAt c t₁ m₁ rest fn lbl pc ld pv) : PtrAt c t m rest fn lbl pc ld pv := by
  obtain ⟨f, k, m', b, st, hS, hq⟩ := hq
  exact ⟨f, k, m', b, st, h.trans hS, hq⟩

/-- **A run of statements with its pointer facts**: a run of statements of block `b` from the
`n`-th after the entry whose final state is good: the thread's steps run them, to a frame and
memory that the final state describes; and they reach each `load` node and each `store` effect
the run appends to `σ`'s, whose statement's pointer operand evaluates in the thread's scope
there to the term's pointer value (`PtrAt`): on the values of the nodes before it for a `load`,
on `vs` for a `store`, whose stored operand the effect's term describes with the final register
entries (`StoreAt`). -/
theorem SState.run_ptrs {V : Valuation} {vs : List (Except Fault Val)} {f : Frame}
    {b : LLVM.Block} {lbl p0 : Nat} {rest : List Frame} {contract : Bool}
    (hb : V.fn.blocks.find? (·.label == lbl) = some b) (hfn : f.fn = V.fn) (hlbl : f.label = lbl) :
    ∀ (sts : List Stmt) (n : Nat) (σ σf : SState) (fi : Frame) (mi : Mem) (kk : Nat),
      sts = b.stmts.toList.drop (p0 + n) → fi.pc = p0 + n → kk = V.k + n →
      Rel V vs f σ fi mi → SState.run contract V.ctx.prog lbl p0 sts n σ = some σf →
      Good V vs σf →
      (∃ fe me, Steps V.ctx ⟨fi :: rest, kk⟩ mi ⟨fe :: rest, kk + sts.length⟩ me ∧
        Rel V vs f σf fe me ∧ fe.pc = fi.pc + sts.length) ∧
      (∀ j l pc p, σ.nodes.length ≤ j → σf.nodes[j]? = some (.load l pc p) →
        PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn l pc true
          (p.eval V (vals V (σf.nodes.take j)))) ∧
      ∀ l pc v p, SEff.store l pc v p ∈ σf.effs.drop σ.effs.length →
        PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn l pc false (p.eval V vs) ∧
          StoreAt V.fn l pc σf.regs v
  | [], _, σ, σf, fi, mi, kk, _, _, _, hR, h, _ => by
    simp only [SState.run, Option.some.injEq] at h
    subst h
    refine ⟨⟨fi, mi, .refl _ _, hR, rfl⟩, fun j _ _ _ hj hn => ?_, fun _ _ _ _ hm => ?_⟩
    · rw [List.getElem?_eq_none hj] at hn
      cases hn
    · rw [List.drop_length] at hm
      cases hm
  | st :: sts, n, σ, σf, fi, mi, kk, hsts, hpc, hk, hR, h, hG => by
    simp only [SState.run] at h
    split at h
    · rename_i σ' hσ
      have hst : b.stmts[p0 + n]? = some st := by
        rw [← Array.getElem?_toList, ← Nat.add_zero (p0 + n), ← List.getElem?_drop, ← hsts]
        rfl
      have hst' : V.stmt lbl fi.pc = some st := by
        unfold Valuation.stmt
        rw [hb, hpc]; exact hst
      obtain ⟨hmo1, ⟨es, hmo2⟩, ⟨ns, hmo3⟩, ⟨rs, hmo4⟩⟩ := SState.run_mono h
      have hM : ∃ m, SEff.run V vs σ'.effs = .ok m := by
        obtain ⟨mf, hmf⟩ := hG.2.1
        rw [hmo2] at hmf
        exact SEff.run_prefix hmf
      have hN : ∃ ws, vs = vals V σ'.nodes ++ ws := by
        obtain ⟨ws, hws⟩ := hG.2.2
        obtain ⟨ws', hws'⟩ := vals_append V σ'.nodes ns
        exact ⟨ws' ++ ws, by rw [hws, hmo3, hws', List.append_assoc]⟩
      obtain ⟨fi', mi', he, hR', hpc', hL, hSt⟩ := SState.stmt_sound rfl hR hk hst'
        (by rw [hpc]; exact hσ) (fun d hd => hG.1 d (hmo1 d hd)) hM hN
      have hb' : fi.fn.blocks.find? (·.label == fi.label) = some b := by
        rw [hR.fn, hR.label, hfn, hlbl]; exact hb
      have hstep := step_stmt (rest := rest) hb' (by rw [hpc]; exact hst) he
      obtain ⟨⟨fe, me, hS, hRf, hpcf⟩, hL', hSt'⟩ := SState.run_ptrs hb hfn hlbl sts (n + 1) σ' σf
        fi' mi' (kk + 1) (by rw [← Nat.add_assoc, ← List.tail_drop, ← hsts]; rfl) (by omega)
        (by omega) hR' h hG
      -- a pointer fact of this statement holds at the thread itself
      have here : ∀ {ld pv}, PtrIs ld st (V.ctx.scope mi fi kk) pv →
          PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn lbl fi.pc ld pv := fun hq =>
        ⟨fi, kk, mi, b, st, .refl _ _, hR.fn.trans hfn, hR.label.trans hlbl, rfl, hb,
          by rw [hpc]; exact hst, hq⟩
      obtain ⟨_, ⟨es₁, he₁⟩, ⟨ns₁, hn₁⟩, ⟨rs₁, hr₁⟩⟩ := SState.stmt_mono hσ
      refine ⟨⟨fe, me, .cons hstep ?_, hRf, ?_⟩, fun j l pc p hj hn => ?_, fun l pc v p hm => ?_⟩
      · have e : kk + (st :: sts).length = kk + 1 + sts.length := by
          simp only [List.length_cons]
          omega
        rw [e]
        exact hS
      · simp only [List.length_cons]
        omega
      · by_cases hj' : σ'.nodes.length ≤ j
        · exact PtrAt.pre (.cons hstep (.refl _ _)) (hL' j l pc p hj' hn)
        · rw [hmo3, List.getElem?_append_left (by omega)] at hn
          obtain ⟨rfl, rfl, rfl, hq⟩ := hL j l pc p hj hn
          rw [hmo3, hn₁, List.append_assoc, List.take_left]
          exact here hq
      · rw [hmo2, List.drop_append_of_le_length (by rw [he₁, List.length_append]; omega),
          List.mem_append] at hm
        rcases hm with hm | hm
        · obtain ⟨rfl, rfl, hq, vol, ty, w, ptr, al, hi, hop⟩ := hSt l pc v p hm
          refine ⟨here hq, b, st, vol, ty, w, ptr, al, hb, by rw [hpc]; exact hst, hi, ?_⟩
          rw [hmo4, hr₁, ← List.append_assoc]
          exact SState.op_storeVal hop _
        · obtain ⟨hq, hv⟩ := hSt' l pc v p (by rw [hmo2, List.drop_left]; exact hm)
          exact ⟨PtrAt.pre (.cons hstep (.refl _ _)) hq, hv⟩
    · cases h

/-- A run of statements of block `b` from the `n`-th after the entry whose final state is good:
the thread's steps run them, to a frame and memory that the final state describes
(`SState.run_ptrs`). -/
theorem SState.run_sound {V : Valuation} {vs : List (Except Fault Val)} {f : Frame}
    {b : LLVM.Block} {lbl p0 : Nat} {rest : List Frame} {contract : Bool}
    (hb : V.fn.blocks.find? (·.label == lbl) = some b) (hfn : f.fn = V.fn) (hlbl : f.label = lbl)
    (sts : List Stmt) (n : Nat) (σ σf : SState) (fi : Frame) (mi : Mem) (kk : Nat)
    (h₁ : sts = b.stmts.toList.drop (p0 + n)) (h₂ : fi.pc = p0 + n) (h₃ : kk = V.k + n)
    (hR : Rel V vs f σ fi mi) (h : SState.run contract V.ctx.prog lbl p0 sts n σ = some σf)
    (hG : Good V vs σf) :
    ∃ fe me, Steps V.ctx ⟨fi :: rest, kk⟩ mi ⟨fe :: rest, kk + sts.length⟩ me ∧
      Rel V vs f σf fe me ∧ fe.pc = fi.pc + sts.length :=
  (SState.run_ptrs hb hfn hlbl sts n σ σf fi mi kk h₁ h₂ h₃ hR h hG).1

/-- Block `lbl` with summary `S`, entered with valuation `V`, ends: the thread's steps from `t`
on `m` reach the block's end at step count `V.k + S.len`, with a frame `fe` (above frames `rest`)
of function `V.fn` at block `lbl` whose `alloca` blocks and caller's register are those of frame
`f`, whose registers and `fmul contract` operands are the summary's (`regVal`, `regProd`), on the
memory `me` the summary's effects make (`SEff.run`); and the terminator's step there is the
summary exit's (`Exit.next`), without a fault. -/
def Ends (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, lbl, S) => ∃ fe me, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.allocas = f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProd V S.regs r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      ∃ r, S.exit.next V (vals V S.nodes) rest (V.k + S.len) fe me = .ok r ∧
        step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r

/-- `Ends` with the `fmul contract` operands of the frame at the block's end given by the table
(`regProdIn`): for a register the block sets, the values of its node's `fmul contract` operand
terms. The conclusion of `Block.soundC`. -/
def EndsC (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, lbl, S) => ∃ fe me, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.allocas = f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProdIn V (vals V S.nodes) S.nodes S.regs r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      ∃ r, S.exit.next V (vals V S.nodes) rest (V.k + S.len) fe me = .ok r ∧
        step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r

/-- `EndsC` of a summary with no `fmul contract` node is `Ends`: without such a node no register
entry has `fmul contract` operand terms (`SVal.factors`), so `regProdIn` gives what `regProd`
gives (none for a register the block sets). -/
theorem Ends.of_C {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : Summary} (h : EndsC c t m f rest (V, lbl, S))
    (hf : ∀ nd ∈ S.nodes, nd.factors = none) : Ends c t m f rest (V, lbl, S) := by
  obtain ⟨fe, me, hS, h1, h2, h3, h4, hr, hp, hm, hx⟩ := h
  refine ⟨fe, me, hS, h1, h2, h3, h4, hr, fun r => (hp r).trans ?_, hm, hx⟩
  unfold regProdIn regProd
  cases S.regs.lookup r with
  | none => rfl
  | some x =>
    cases x with
    | node j =>
      show (S.nodes[j]?.bind SNode.factors).bind (prodVal V (vals V S.nodes)) = none
      cases hj : S.nodes[j]? with
      | none => rfl
      | some nd => rw [Option.bind_some, hf nd (List.mem_of_getElem? hj)]; rfl
    | _ => rfl

/-- **The pointer facts** of block `lbl` with summary `S`, entered with valuation `V`, from
thread `t` on memory `m`, in frames above frames `rest`: the thread's steps reach the statement
of each `load` node `j` of `S` and of each `store` effect of `S` (`PtrAt`), whose pointer operand
evaluates in the thread's scope there to the term's pointer value: for a `load` node, on the
values of the nodes before it (`vals V (S.nodes.take j)`, as `Valuation.LoadsOk` reads it); for
a `store` effect, on the values of the table (as `Valuation.StoresOk` reads it), and the
effect's stored term describes the statement's stored operand with the summary's register
entries (`StoreAt`). -/
def Ptrs (c : Ctx) (t : Thread) (m : Mem) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, _, S) =>
    (∀ (j l pc : Nat) (p : SVal), S.nodes[j]? = some (.load l pc p) →
      PtrAt c t m rest V.fn l pc true (p.eval V (vals V (S.nodes.take j)))) ∧
    ∀ l pc v p, SEff.store l pc v p ∈ S.effs →
      PtrAt c t m rest V.fn l pc false (p.eval V (vals V S.nodes)) ∧ StoreAt V.fn l pc S.regs v

/-- `Ptrs` after steps before it. -/
theorem Ptrs.pre {c : Ctx} {t t₁ : Thread} {m m₁ : Mem} {rest : List Frame}
    {q : Valuation × Nat × Summary} (h : Steps c t m t₁ m₁) (hq : Ptrs c t₁ m₁ rest q) :
    Ptrs c t m rest q := by
  obtain ⟨V, lbl, S⟩ := q
  exact ⟨fun j l pc p hn => PtrAt.pre h (hq.1 j l pc p hn),
    fun l pc v p hm => ⟨PtrAt.pre h (hq.2 l pc v p hm).1, (hq.2 l pc v p hm).2⟩⟩

/-- **Soundness of the block checker with an exit function** `ex` and `fmul contract` when
`contract`, for every program, function, block, entry position, conditions `ds` and summary `S`
that `coversWith` accepts with `ex` and `contract`, every context `c` of the program and thread
whose innermost frame `f` runs `fn` at block `lbl` and position `p0`, with memory `m`: if every
condition of `ds` holds under the entry valuation and, at the block's end, `ex`'s exit is the
terminator's step whenever its obligations hold (`hex`), the block ends with the frame's
`fmul contract` operands given by the table (`EndsC`) from the entry valuation, and its pointer
facts hold (`Ptrs`). `Block.sound_with` and `Block.soundC` are its instances. -/
theorem Block.sound_withC {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {ds : List Cond} {S : Summary}
    {contract : Bool} (hc : coversWith P fn lbl p0 ex ds S contract = true) {c : Ctx}
    (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes))
    (hex : ∀ {σ : SState} {fe : Frame} {me : Mem} {b : LLVM.Block} {k : Nat} {cs : List Cond},
      Rel (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) f σ fe me →
      fe.fn.blocks.find? (·.label == fe.label) = some b → ¬ fe.pc < b.stmts.size →
      ex σ b.term = some (S.exit, cs) →
      (∀ d ∈ cs, d.Holds (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes)) →
      ∃ r, S.exit.next (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) rest
        k fe me = .ok r ∧ step c ⟨fe :: rest, k⟩ me = .ok r) :
    EndsC c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) := by
  subst hP hfn hl hp
  obtain ⟨frames, k⟩ := t
  obtain rfl : frames = f :: rest := ht
  unfold coversWith at hc
  split at hc
  · rename_i S' hS
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    obtain ⟨rfl, hall⟩ := hc
    have hO : ∀ d ∈ S'.obls, d.Holds (Valuation.entry c k m f)
        (vals (Valuation.entry c k m f) S'.nodes) := fun d hd =>
      hds d ((List.isPrefixOf_iff_prefix.1 hall).mem hd)
    unfold summarizeWith at hS
    split at hS
    · rename_i b hb
      split at hS
      · rename_i σ hσ
        split at hS
        · rename_i x cs hx
          cases hS
          have hR0 : Rel (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) f
              .init f m :=
            ⟨rfl, rfl, rfl, rfl, fun _ => rfl, fun _ => rfl, (by intro r v h; cases h),
              (by intro x pq j h; cases x <;> cases h), rfl, fun _ => ⟨m.trace, rfl⟩⟩
          have hG : Good (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) σ :=
            ⟨fun d hd => hO d (List.mem_append.2 (Or.inr (List.mem_cons_of_mem _ hd))),
              hO (.mem σ.effs) (List.mem_append.2 (Or.inr (List.Mem.head _))),
              [], (List.append_nil _).symm⟩
          obtain ⟨⟨fe, me, hS, hR, hpc⟩, hL, hSt⟩ := SState.run_ptrs
            (V := Valuation.entry c k m f) (rest := rest) (p0 := f.pc) hb rfl rfl
            (b.stmts.toList.drop f.pc) 0 .init σ f m k rfl rfl rfl hR0 hσ hG
          have hpcn : ¬ fe.pc < b.stmts.size := by
            simp only [List.length_drop, Array.length_toList] at hpc
            omega
          obtain ⟨r, hr1, hr2⟩ := hex (k := k + (b.stmts.toList.drop f.pc).length) hR
            (by rw [hR.fn, hR.label]; exact hb) hpcn hx
            (fun d hd => hO d (List.mem_append.2 (Or.inl hd)))
          exact ⟨⟨fe, me, hS, hR.fn, hR.label, hR.allocas, hR.dest, hR.regs, hR.prods, hR.mem,
            r, hr1, hr2⟩, fun j l pc p hn => hL j l pc p (Nat.zero_le _) hn,
            fun l pc v p hm => hSt l pc v p hm⟩
        · cases hS
      · cases hS
    · cases hS
  · cases hc

/-- **Soundness of the block checker with an exit function** `ex`, for every program, function,
block, entry position, conditions `ds` and summary `S` that `coversWith` accepts with `ex`, every
context `c` of the program and thread whose innermost frame `f` runs `fn` at block `lbl` and
position `p0`, with memory `m`: if every condition of `ds` holds under the entry valuation and,
at the block's end, `ex`'s exit is the terminator's step whenever its obligations hold (`hex`),
the block ends (`Ends`) from the entry valuation, and its pointer facts hold (`Ptrs`)
(`Block.sound_withC` without `fmul contract`, whose summary has no `fmul contract` node:
`summarizeWith_factors`, `Ends.of_C`). `Block.sound_ptrs` and `Block.sound_to` are its
instances. -/
theorem Block.sound_with {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {ds : List Cond} {S : Summary}
    (hc : coversWith P fn lbl p0 ex ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes))
    (hex : ∀ {σ : SState} {fe : Frame} {me : Mem} {b : LLVM.Block} {k : Nat} {cs : List Cond},
      Rel (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) f σ fe me →
      fe.fn.blocks.find? (·.label == fe.label) = some b → ¬ fe.pc < b.stmts.size →
      ex σ b.term = some (S.exit, cs) →
      (∀ d ∈ cs, d.Holds (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes)) →
      ∃ r, S.exit.next (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) rest
        k fe me = .ok r ∧ step c ⟨fe :: rest, k⟩ me = .ok r) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) := by
  obtain ⟨hE, hQ⟩ := Block.sound_withC hc hP ht hfn hl hp hds hex
  refine ⟨Ends.of_C hE ?_, hQ⟩
  unfold coversWith at hc
  split at hc
  · rename_i S' hS
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    obtain ⟨rfl, -⟩ := hc
    exact summarizeWith_factors hS
  · cases hc

/-- **Soundness of the block checker with its pointer facts**: for every program, function,
block, entry position, conditions and summary that `covers` accepts, every context of the
program and thread at the block's position whose conditions hold at the entry valuation of its
innermost frame, the block ends (`Ends`) and its pointer facts hold (`Ptrs`: at each `load` node
and `store` effect, the statement's pointer operand in the thread's scope at that step is the
summary term's pointer value) (`Block.sound_with`, `SState.exitAt_sound`). -/
theorem Block.sound_ptrs {P : Program} {fn : Func} {lbl p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : covers P fn lbl p0 ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_with (ex := fun σ tm => σ.exitAt fn lbl tm) hc hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs

/-- **Soundness of the block checker**: for every program `P`, function `fn`, block `lbl`, entry
position `p0`, conditions `ds` and summary `S` that `covers` accepts, every context of `P` and
thread whose innermost frame `f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`,
with memory `m`: if every condition of `ds` holds under `f`'s entry valuation and the values of
`S`'s table, the block ends (`Ends`): the thread's steps reach the block's end at step count
`t.k + S.len` with the summary's registers and `fmul contract` operands, on the memory the
summary's effects make, and the terminator's step there is the summary exit's
(`Block.sound_ptrs`). One thread; the obligations are premises. -/
theorem Block.sound {P : Program} {fn : Func} {lbl p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : covers P fn lbl p0 ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) :=
  (Block.sound_ptrs hc hP ht hfn hl hp hds).1

/-- **Soundness of the block checker with `fmul contract`**: for every program `P`, function
`fn`, block `lbl`, entry position `p0`, conditions `ds` and summary `S` that `coversC` accepts,
every context of `P` and thread whose innermost frame `f` (above frames `rest`) runs `fn` at block
`lbl` and position `p0`, with memory `m`: if every condition of `ds` holds under `f`'s entry
valuation and the values of `S`'s table, the block ends (`EndsC`): the thread's steps reach the
block's end at step count `t.k + S.len` with the summary's registers, the `fmul contract`
operands its table gives (`regProdIn`), on the memory the summary's effects make, and the
terminator's step there is the summary exit's (`Block.sound_withC`, `SState.exitAt_sound`). One
thread; the obligations are premises. -/
theorem Block.soundC {P : Program} {fn : Func} {lbl p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : coversC P fn lbl p0 ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    EndsC c t m f rest (Valuation.entry c t.k m f, lbl, S) :=
  (Block.sound_withC (ex := fun σ tm => σ.exitAt fn lbl tm) hc hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs).1

/-! ## Along a path -/

/-- The block exit `x` goes to, given the values `vs` of the nodes: a branch's target, the
target a conditional branch's condition selects (`none` when it is not a word), and `none` for
`ret void` and for branches into blocks with `phi`s (`Exit.dest` gives their targets). -/
def Exit.target (V : Valuation) (vs : List (Except Fault Val)) : Exit → Option Nat
  | .br d => some d
  | .cond x d e => match x.eval V vs with
    | .ok (.bits _ b) => some (if b.getLsbD 0 then d else e)
    | _ => none
  | .ret => none
  | .phi .. => none

/-- The valuation at the entry of the block that summary `S` exits to, from valuation `V` at its
entry: the step count after the block's `S.len` statements and its branch, the memory the
summary's effects make (`V`'s memory if they fault), and the registers and `fmul contract`
operands the summary gives (`regVal`, `regProd`); the context and function are `V`'s. -/
def Valuation.after (V : Valuation) (S : Summary) : Valuation :=
  ⟨V.ctx, V.fn, V.k + S.len + 1, (SEff.run V (vals V S.nodes) S.effs).toOption.getD V.mem,
    regVal V (vals V S.nodes) S.regs, regProd V S.regs⟩

/-- The block exit `x` goes to, given the values `vs` of the nodes: `Exit.target`'s, and for a
branch into blocks with `phi`s the target its condition selects (`none` when it is not a
word). -/
def Exit.dest (V : Valuation) (vs : List (Except Fault Val)) : Exit → Option Nat
  | .phi x d e => match x.eval V vs with
    | .ok (.bits _ b) => some (if b.getLsbD 0 then d else e)
    | _ => none
  | x => x.target V vs

/-- The position at which exit `x`'s step enters block `d` of `fn`: after the `phi`s
(`phiCount`) for a branch into blocks with `phi`s, 0 otherwise. -/
def Exit.pc (fn : Func) (d : Nat) : Exit → Nat
  | .phi .. => phiCount fn d
  | _ => 0

/-- `SState.exitAt_sound` for `SState.exitTo`, the exit with the obligations of the edge into
block `d₀` only: when the exit goes to `d₀` (`Exit.dest`), the terminator's step is the exit's. -/
theorem SState.exitTo_sound {V : Valuation} {vs : List (Except Fault Val)} {f fe : Frame}
    {σ : SState} {me : Mem} (hR : Rel V vs f σ fe me) {b : LLVM.Block} {rest : List Frame}
    {k : Nat} (hb : fe.fn.blocks.find? (·.label == fe.label) = some b)
    (hpc : ¬ fe.pc < b.stmts.size) {d₀ : Nat} {x : Exit} {cs : List Cond}
    (hx : σ.exitTo fe.fn fe.label d₀ b.term = some (x, cs)) (hcs : ∀ d ∈ cs, d.Holds V vs)
    (hd : x.dest V vs = some d₀) :
    ∃ r, x.next V vs rest k fe me = .ok r ∧ step V.ctx ⟨fe :: rest, k⟩ me = .ok r := by
  unfold SState.exitTo at hx
  cases he : σ.exit fe.fn b.term with
  | some y =>
    rw [he] at hx
    cases hx
    exact SState.exit_sound hR hb hpc he hcs
  | none =>
    rw [he] at hx
    change σ.phiExitTo fe.fn fe.label d₀ b.term = some (x, cs) at hx
    unfold SState.phiExitTo at hx
    split at hx
    · rename_i cv d e hterm
      split at hx
      · rename_i y c₀ hy h₀
        cases hx
        obtain ⟨w, bv, hv⟩ := hcs (.bool y) (List.Mem.head _)
        have hcv := SState.op_eval hR (s := V.ctx.scope me fe k) rfl hy hv
        have hd' : (if bv.getLsbD 0 then d else e) = d₀ := by
          simpa only [Exit.dest, hv, Option.some.injEq] using hd
        rw [← hd'] at h₀
        obtain ⟨f', hf'⟩ := SState.enter_ok hR (s := V.ctx.scope me fe k) rfl h₀
          fun c hc => hcs c (List.mem_cons_of_mem _ hc)
        refine ⟨.next ⟨f' :: rest, k + 1⟩ me, ?_, ?_⟩
        · (simp only [Exit.next, hv, hf', bind, Except.bind, pure, Except.pure])
        · (simp only [step, hb, hpc, ↓reduceDIte, hterm, hcv, hf', bind, Except.bind, pure,
            Except.pure])
      · cases hx
    · exact SState.exitAt_sound hR hb hpc (by unfold SState.exitAt; rw [he]; exact hx) hcs

/-- **Soundness of the block checker for one edge**: `Block.sound` for a block that `coversTo`
accepts for the edge into block `d₀` (with the obligations of that edge only), when its exit goes
to `d₀` (`Exit.dest`) from the entry valuation, with its pointer facts (`Ptrs`). For every
program, function, block, position, target, conditions, summary, context of the program and
thread at the block's position (`Block.sound_with`, `SState.exitTo_sound`). -/
theorem Block.sound_to {P : Program} {fn : Func} {lbl p0 d₀ : Nat} {ds : List Cond}
    {S : Summary} (hc : coversTo P fn lbl p0 d₀ ds S = true) {c : Ctx} (hP : c.prog = P)
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes))
    (hd : S.exit.dest (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) =
      some d₀) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_with (ex := fun σ tm => σ.exitTo fn lbl d₀ tm) hc hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitTo_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs hd

/-- The frame at the end of block `l` that summary `S` describes from valuation `V`: `V`'s
function, the registers and `fmul contract` operands of `Valuation.after`, position 0, no
`alloca` blocks and no caller's register (`enter` reads none of these three). -/
def Valuation.frameAt (V : Valuation) (l : Nat) (S : Summary) : Frame :=
  { fn := V.fn, label := l, pc := 0, regs := (V.after S).regs, prods := (V.after S).prods,
    allocas := [], dest := none }

/-- The valuation at the entry of the block that the exit of summary `S` of block `l` goes to,
from valuation `V` at its entry: `Valuation.after`, whose registers and `fmul contract`
operands are, for a branch into blocks with `phi`s (`Exit.phi`), those of the frame `enter`
gives from `Valuation.frameAt`, with the target's `phi`s set. -/
def Valuation.into (V : Valuation) (l : Nat) (S : Summary) : Valuation :=
  match S.exit, S.exit.dest V (vals V S.nodes) with
  | .phi .., some d =>
    match enter (V.ctx.scope (V.after S).mem (V.frameAt l S) (V.k + S.len)) (V.frameAt l S) d with
    | .ok f => { V.after S with regs := f.regs, prods := f.prods }
    | .error _ => V.after S
  | _, _ => V.after S

/-- The `fmul contract` operands of the frame at the end of the block that summary `S`
describes from valuation `V`: with `contract`, the table's (`regProdIn`, as `EndsC` gives them),
else `regProd`'s (as `Ends` gives them). -/
def prodsWith (contract : Bool) (V : Valuation) (S : Summary) : Nat → Option (Val × Val) :=
  cond contract (regProdIn V (vals V S.nodes) S.nodes S.regs) (regProd V S.regs)

/-- `Valuation.after` with the `fmul contract` operands `prodsWith contract`: without
`contract` it is `Valuation.after`, with it `Valuation.afterC`. -/
def Valuation.afterWith (contract : Bool) (V : Valuation) (S : Summary) : Valuation :=
  { V.after S with prods := prodsWith contract V S }

/-- **The valuation after a block with `fmul contract`**: `Valuation.after`, with the
`fmul contract` operands the table gives (`regProdIn`), as at the end of a block that `coversC`
accepts (`EndsC`, `Block.soundC`). For every valuation and summary. -/
def Valuation.afterC (V : Valuation) (S : Summary) : Valuation := V.afterWith true S

/-- `Valuation.frameAt` with the registers and `fmul contract` operands of
`Valuation.afterWith contract`. -/
def Valuation.frameAtWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) : Frame :=
  { fn := V.fn, label := l, pc := 0, regs := (V.afterWith contract S).regs,
    prods := (V.afterWith contract S).prods, allocas := [], dest := none }

/-- `Valuation.into` from `Valuation.afterWith contract` and `Valuation.frameAtWith contract`:
without `contract` it is `Valuation.into`, with it `Valuation.intoC`. -/
def Valuation.intoWith (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) : Valuation :=
  match S.exit, S.exit.dest V (vals V S.nodes) with
  | .phi .., some d =>
    match enter (V.ctx.scope (V.afterWith contract S).mem (V.frameAtWith contract l S)
        (V.k + S.len)) (V.frameAtWith contract l S) d with
    | .ok f => { V.afterWith contract S with regs := f.regs, prods := f.prods }
    | .error _ => V.afterWith contract S
  | _, _ => V.afterWith contract S

/-- **The valuation at the entry of the block that a block with `fmul contract` exits to**:
`Valuation.into` from `Valuation.afterC`, whose `fmul contract` operands are the table's
(`regProdIn`); for a branch into blocks with `phi`s (`Exit.phi`), the registers and
`fmul contract` operands of the frame `enter` gives, with the target's `phi`s set. For every
valuation, block and summary; `Ends.edgeC` enters it. -/
def Valuation.intoC (V : Valuation) (l : Nat) (S : Summary) : Valuation := V.intoWith true l S

/-- An exit with a target (`Exit.target`, so not `Exit.phi`): `Exit.dest` gives it, its step
enters at position 0, and `Valuation.intoWith contract` is `Valuation.afterWith contract`, with
or without `contract`. -/
theorem Exit.of_targetWith {V : Valuation} {l d : Nat} {S : Summary} (contract : Bool)
    (h : S.exit.target V (vals V S.nodes) = some d) :
    S.exit.dest V (vals V S.nodes) = some d ∧ (∀ fn d', S.exit.pc fn d' = 0) ∧
      V.intoWith contract l S = V.afterWith contract S := by
  unfold Valuation.intoWith
  cases hx : S.exit with
  | phi => rw [hx] at h; cases h
  | ret => rw [hx] at h; cases h
  | br => rw [hx] at h; exact ⟨h, fun _ _ => rfl, rfl⟩
  | cond => rw [hx] at h; exact ⟨h, fun _ _ => rfl, rfl⟩

/-- An exit with a target (`Exit.target`, so not `Exit.phi`): `Exit.dest` gives it, its step
enters at position 0, and `Valuation.into` is `Valuation.after` (`Exit.of_targetWith` without
`contract`). -/
theorem Exit.of_target {V : Valuation} {l d : Nat} {S : Summary}
    (h : S.exit.target V (vals V S.nodes) = some d) :
    S.exit.dest V (vals V S.nodes) = some d ∧ (∀ fn d', S.exit.pc fn d' = 0) ∧
      V.into l S = V.after S :=
  Exit.of_targetWith (l := l) false h

/-- `Valuation.intoWith contract` keeps the context and the function, and its step count is
`Valuation.after`'s, with or without `contract`. -/
theorem Valuation.intoWith_k (contract : Bool) (V : Valuation) (l : Nat) (S : Summary) :
    (V.intoWith contract l S).ctx = V.ctx ∧ (V.intoWith contract l S).fn = V.fn ∧
      (V.intoWith contract l S).k = V.k + S.len + 1 := by
  unfold Valuation.intoWith
  split
  · split <;> exact ⟨rfl, rfl, rfl⟩
  · exact ⟨rfl, rfl, rfl⟩

/-- `Valuation.into` keeps the context and the function, and its step count is
`Valuation.after`'s (`Valuation.intoWith_k` without `contract`). -/
theorem Valuation.into_k (V : Valuation) (l : Nat) (S : Summary) :
    (V.into l S).ctx = V.ctx ∧ (V.into l S).fn = V.fn ∧ (V.into l S).k = V.k + S.len + 1 :=
  Valuation.intoWith_k false V l S

/-- An exit with target `d`: its step enters block `d` at position 0 (`Exit.br` and
`Exit.cond` go to blocks without `phi`s), with the frame's other fields and the memory
unchanged. -/
theorem Exit.next_target {V : Valuation} {vs : List (Except Fault Val)} {rest : List Frame}
    {k : Nat} {fe : Frame} {me : Mem} {x : Exit} {d : Nat} {r : Step}
    (h : x.target V vs = some d) (hn : x.next V vs rest k fe me = .ok r) :
    r = .next ⟨{ fe with label := d, pc := 0 } :: rest, k + 1⟩ me := by
  cases x with
  | br d' =>
    simp only [Exit.target, Option.some.injEq] at h
    subst h
    simp only [Exit.next, pure, Except.pure, Except.ok.injEq] at hn
    exact hn.symm
  | cond y d' e' =>
    simp only [Exit.target] at h
    split at h
    · rename_i w b hy
      simp only [Option.some.injEq] at h
      subst h
      simp only [Exit.next, hy, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hn
      exact hn.symm
    · cases h
  | ret => cases h
  | phi => cases h

/-- `Ends` with the `fmul contract` operands `prodsWith contract` of the frame at the block's
end: without `contract` it is `Ends`, with it `EndsC`. -/
def EndsWith (contract : Bool) (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, lbl, S) => ∃ fe me, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.allocas = f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = prodsWith contract V S r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      ∃ r, S.exit.next V (vals V S.nodes) rest (V.k + S.len) fe me = .ok r ∧
        step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r

/-- Steps, a step that continues the thread, then the end of a block from the thread after it
(`EndsWith contract`), whose frame keeps the `alloca` blocks and caller's register of `f`: the
block ends from the first thread too, with or without `contract`. -/
theorem EndsWith.pre {contract : Bool} {c : Ctx} {t t₁ t₂ : Thread} {m m₁ m₂ : Mem}
    {f f₂ : Frame} {rest : List Frame} {q : Valuation × Nat × Summary} (h₁ : Steps c t m t₁ m₁)
    (h : step c t₁ m₁ = .ok (.next t₂ m₂)) (hq : EndsWith contract c t₂ m₂ f₂ rest q)
    (hal : f₂.allocas = f.allocas) (hde : f₂.dest = f.dest) :
    EndsWith contract c t m f rest q := by
  obtain ⟨V, lbl, S⟩ := q
  obtain ⟨fe, me, hS, hfn, hl, hal', hde', hr, hpr, hm, r, hn, hst⟩ := hq
  exact ⟨fe, me, Steps.trans_step h₁ h hS, hfn, hl, hal'.trans hal, hde'.trans hde, hr, hpr, hm, r,
    hn, hst⟩

/-- Steps, a step that continues the thread, then the end of a block from the thread after it,
whose frame keeps the `alloca` blocks and caller's register of `f`: the block ends from the
first thread too (`EndsWith.pre` without `contract`). -/
theorem Ends.pre {c : Ctx} {t t₁ t₂ : Thread} {m m₁ m₂ : Mem} {f f₂ : Frame} {rest : List Frame}
    {q : Valuation × Nat × Summary} (h₁ : Steps c t m t₁ m₁) (h : step c t₁ m₁ = .ok (.next t₂ m₂))
    (hq : Ends c t₂ m₂ f₂ rest q) (hal : f₂.allocas = f.allocas) (hde : f₂.dest = f.dest) :
    Ends c t m f rest q := by
  obtain ⟨V, lbl, S⟩ := q
  exact EndsWith.pre (contract := false) (q := (V, lbl, S)) h₁ h hq hal hde

/-- **An edge, with or without `fmul contract`**: block `l` with summary `S` ends with the
`fmul contract` operands `prodsWith contract` (`EndsWith`) and its exit goes to block `d`
(`Exit.dest`): the branch's step enters block `d` at position `S.exit.pc V.fn d` (after its
`phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s function whose `alloca`
blocks and caller's register are those of `f` and whose entry valuation is
`V.intoWith contract l S`. `Ends.edge` and `Ends.edgeC` are its instances. -/
theorem Ends.edgeWith {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c)
    (h : EndsWith contract c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.intoWith contract l S := by
  subst hc
  obtain ⟨fe, me, hS, hfn, hl, hal, hde, hr, hpr, hm, r, hn, hst⟩ := h
  have e1 : fe.regs = regVal V (vals V S.nodes) S.regs := funext hr
  have e2 : fe.prods = prodsWith contract V S := funext hpr
  have nophi (ht : S.exit.target V (vals V S.nodes) = some d) :
      ∃ t₁ m₁ f', Steps V.ctx t m t₁ m₁ ∧
        step V.ctx t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
        f'.label = d ∧ f'.pc = 0 ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
        Valuation.entry V.ctx (V.k + S.len + 1) m₁ f' = V.intoWith contract l S := by
    obtain rfl := Exit.next_target ht hn
    refine ⟨_, me, { fe with label := d, pc := 0 }, hS, hst, hfn, rfl, rfl, hal, hde, ?_⟩
    rw [(Exit.of_targetWith contract ht).2.2, Valuation.afterWith, Valuation.after, hm]
    simp only [Valuation.entry, Except.toOption, Option.getD, e1, e2, hfn]
  cases hx : S.exit
  case phi y d₁ e₁ =>
    rw [hx] at hd hn
    simp only [Exit.dest] at hd
    split at hd
    · rename_i w b hy
      simp only [Option.some.injEq] at hd
      subst hd
      simp only [Exit.next, hy, bind, Except.bind] at hn
      generalize he : enter _ _ _ = q at hn
      cases q with
      | error => cases hn
      | ok f' =>
        simp only [pure, Except.pure, Except.ok.injEq] at hn
        subst hn
        obtain ⟨hf1, hf2, hf3, hf4, hf5⟩ := enter_fields he
        have hg := enter_congr he (g := V.frameAtWith contract l S) hfn.symm hl.symm e1.symm
          e2.symm
        have hs : V.ctx.scope (V.afterWith contract S).mem (V.frameAtWith contract l S)
            (V.k + S.len) = V.ctx.scope me fe (V.k + S.len) := by
          simp only [Ctx.scope, Valuation.afterWith, Valuation.after, Valuation.frameAtWith, hm,
            Except.toOption, Option.getD, e1]
        have hi : V.intoWith contract l S =
            { V.afterWith contract S with regs := f'.regs, prods := f'.prods } := by
          unfold Valuation.intoWith
          rw [hx]
          simp only [Exit.dest, hy, hs, hg]
        refine ⟨_, me, f', hS, hst, hf1.trans hfn, hf2, by rw [hf3, hfn]; rfl, hf4.trans hal,
          hf5.trans hde, ?_⟩
        rw [hi]
        simp only [Valuation.entry, Valuation.afterWith, Valuation.after, hf1, hfn, hm,
          Except.toOption, Option.getD]
    · cases hd
  all_goals
    obtain ⟨t₁, m₁, f', h1, h2, h3, h4, h5, h6, h7, h8⟩ := nophi (by rw [hx] at hd ⊢; exact hd)
    exact ⟨t₁, m₁, f', h1, h2, h3, h4, h5, h6, h7, h8⟩

/-- **An edge**: block `l` with summary `S` ends (`Ends`) and its exit goes to block `d`
(`Exit.dest`): the branch's step enters block `d` at position `S.exit.pc V.fn d` (after its
`phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s function whose `alloca`
blocks and caller's register are those of `f` and whose entry valuation is `V.into l S`
(`Ends.edgeWith` without `contract`). -/
theorem Ends.edge {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c) (h : Ends c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.into l S :=
  Ends.edgeWith (contract := false) (V := V) (l := l) (S := S) hc h hd

/-- **An edge with `fmul contract`**: block `l` with summary `S` ends with the table's
`fmul contract` operands (`EndsC`, as `Block.soundC` gives for a block that `coversC` accepts)
and its exit goes to block `d` (`Exit.dest`): the branch's step enters block `d` at position
`S.exit.pc V.fn d` (after its `phi`s for `Exit.phi`), on the same memory, with a frame of `V`'s
function whose `alloca` blocks and caller's register are those of `f` and whose entry valuation
is `V.intoC l S`. For every context, thread, block and summary (`Ends.edgeWith` with
`contract`). -/
theorem Ends.edgeC {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {l d : Nat} {S : Summary} (hc : V.ctx = c) (h : EndsC c t m f rest (V, l, S))
    (hd : S.exit.dest V (vals V S.nodes) = some d) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, V.k + S.len + 1⟩ m₁) ∧ f'.fn = V.fn ∧
      f'.label = d ∧ f'.pc = S.exit.pc V.fn d ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c (V.k + S.len + 1) m₁ f' = V.intoC l S :=
  Ends.edgeWith (contract := true) (V := V) (l := l) (S := S) hc h hd

/-- **The path checker**: the blocks `(label, conditions, summary)` of a path, the first from
position `p0` and each one after from its entry, are each accepted by `covers`. -/
def coversPath (P : Program) (fn : Func) : Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, (l, ds, S) :: ps => covers P fn l p0 ds S && coversPath P fn 0 ps

/-- The premises of a path from valuation `V` at its first block's entry: each block's conditions
hold at its entry valuation (`Valuation.after` of the block before), and each block's exit but
the last goes to the next block's label (`Exit.target`). -/
def Walk (V : Valuation) : List (Nat × List Cond × Summary) → Prop
  | [] => True
  | [(_, ds, S)] => ∀ d ∈ ds, d.Holds V (vals V S.nodes)
  | (_, ds, S) :: (l, ds', S') :: ps => (∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.target V (vals V S.nodes) = some l ∧ Walk (V.after S) ((l, ds', S') :: ps)

/-- Whether a path's premises hold, decided by evaluating them (the kernel reduces it on a
concrete valuation). -/
instance Walk.dec (V : Valuation) : (ps : List (Nat × List Cond × Summary)) → Decidable (Walk V ps)
  | [] => isTrue trivial
  | [(_, ds, S)] => inferInstanceAs (Decidable (∀ d ∈ ds, d.Holds V (vals V S.nodes)))
  | (_, ds, S) :: (l, ds', S') :: ps =>
    have := Walk.dec (V.after S) ((l, ds', S') :: ps)
    inferInstanceAs (Decidable ((∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.target V (vals V S.nodes) = some l ∧ Walk (V.after S) ((l, ds', S') :: ps)))

/-- The last block of the path `(l, ds, S) :: ps` entered with valuation `V` at its first block:
its entry valuation (`Valuation.after` of each block before it), label and summary. -/
def Valuation.last (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.after S).last l' S' ps

/-- The number of steps of the path `S :: ps` to its last terminator: each block's statements,
and one step for each branch between them. -/
def pathLen (S : Summary) : List (Nat × List Cond × Summary) → Nat
  | [] => S.len
  | (_, _, S') :: ps => S.len + 1 + pathLen S' ps

/-- **The path checker with `phi`s**: `coversPath`, where each block after the first is
covered from the position its edge enters it at (`Exit.pc`: after its `phi`s for `Exit.phi`),
and each block but the last is accepted by `covers` or, with the obligations of its edge into the
next block only, by `coversTo`. -/
def coversPathI (P : Program) (fn : Func) : Nat → List (Nat × List Cond × Summary) → Bool
  | _, [] => true
  | p0, [(l, ds, S)] => covers P fn l p0 ds S
  | p0, (l, ds, S) :: (l', ds', S') :: ps =>
    (covers P fn l p0 ds S || coversTo P fn l p0 l' ds S) &&
      coversPathI P fn (S.exit.pc fn l') ((l', ds', S') :: ps)

/-- The premises of a path with `phi`s from valuation `V` at its first block's entry: each
block's conditions hold at its entry valuation (`Valuation.into` of the block before), and each
block's exit but the last goes to the next block's label (`Exit.dest`). -/
def WalkI (V : Valuation) : List (Nat × List Cond × Summary) → Prop
  | [] => True
  | [(_, ds, S)] => ∀ d ∈ ds, d.Holds V (vals V S.nodes)
  | (l, ds, S) :: (l', ds', S') :: ps => (∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧ WalkI (V.into l S) ((l', ds', S') :: ps)

/-- Whether a path's premises hold, decided by evaluating them (the kernel reduces it on a
concrete valuation). -/
instance WalkI.dec (V : Valuation) :
    (ps : List (Nat × List Cond × Summary)) → Decidable (WalkI V ps)
  | [] => isTrue trivial
  | [(_, ds, S)] => inferInstanceAs (Decidable (∀ d ∈ ds, d.Holds V (vals V S.nodes)))
  | (l, ds, S) :: (l', ds', S') :: ps =>
    have := WalkI.dec (V.into l S) ((l', ds', S') :: ps)
    inferInstanceAs (Decidable ((∀ d ∈ ds, d.Holds V (vals V S.nodes)) ∧
      S.exit.dest V (vals V S.nodes) = some l' ∧ WalkI (V.into l S) ((l', ds', S') :: ps)))

/-- The last block of the path `(l, ds, S) :: ps` with `phi`s entered with valuation `V` at its
first block: its entry valuation (`Valuation.into` of each block before it), label and
summary. -/
def Valuation.lastI (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → Valuation × Nat × Summary
  | [] => (V, l, S)
  | (l', _, S') :: ps => (V.into l S).lastI l' S' ps

/-- The blocks of the path `(l, ds, S) :: ps` with `phi`s entered with valuation `V` at its first
block, in order, each with its entry valuation (`Valuation.into` of each block before it), label
and summary; `Valuation.lastI` is the last. -/
def Valuation.blocksI (V : Valuation) (l : Nat) (S : Summary) :
    List (Nat × List Cond × Summary) → List (Valuation × Nat × Summary)
  | [] => [(V, l, S)]
  | (l', _, S') :: ps => (V, l, S) :: (V.into l S).blocksI l' S' ps

/-- The last block's entry valuation keeps the context and the function, and the step count at
its end is the entry's plus the path's length. -/
theorem Valuation.lastI_k (V : Valuation) (l : Nat) (S : Summary) :
    ∀ ps, (V.lastI l S ps).1.ctx = V.ctx ∧ (V.lastI l S ps).1.fn = V.fn ∧
      (V.lastI l S ps).1.k + (V.lastI l S ps).2.2.len = V.k + pathLen S ps
  | [] => ⟨rfl, rfl, rfl⟩
  | (l', _, S') :: ps => by
    obtain ⟨h1, h2, h3⟩ := Valuation.lastI_k (V.into l S) l' S' ps
    obtain ⟨e1, e2, e3⟩ := V.into_k l S
    rw [Valuation.lastI]
    refine ⟨h1.trans e1, h2.trans e2, ?_⟩
    rw [h3, pathLen, e3]
    omega

/-- A path that `coversPath` accepts with premises `Walk` is one that `coversPathI` accepts
with premises `WalkI`, with the same last block: its exits have targets (`Exit.of_target`). -/
theorem Walk.toI {P : Program} {fn : Func} : ∀ (ps : List (Nat × List Cond × Summary))
    {V : Valuation} {l p0 : Nat} {ds : List Cond} {S : Summary},
    Walk V ((l, ds, S) :: ps) → coversPath P fn p0 ((l, ds, S) :: ps) = true →
    WalkI V ((l, ds, S) :: ps) ∧ coversPathI P fn p0 ((l, ds, S) :: ps) = true ∧
      V.lastI l S ps = V.last l S ps
  | [], _, _, _, _, _, hW, hc =>
    ⟨hW, by simpa only [coversPath, coversPathI, Bool.and_true] using hc, rfl⟩
  | (l', ds', S') :: ps, V, l, p0, ds, S, hW, hc => by
    obtain ⟨hds, ht, hW'⟩ := hW
    rw [coversPath, Bool.and_eq_true] at hc
    obtain ⟨hd, hpc, hi⟩ := Exit.of_target (l := l) ht
    obtain ⟨hW'', hc', he⟩ := Walk.toI ps hW' hc.2
    refine ⟨⟨hds, hd, by rw [hi]; exact hW''⟩, ?_, by rw [Valuation.lastI, Valuation.last, hi, he]⟩
    rw [coversPathI, Bool.and_eq_true, hpc]
    exact ⟨by rw [hc.1, Bool.true_or], hc'⟩

/-- **Soundness along a path with `phi`s, with its pointer facts**: for every program, function
and path `(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first
block from position `p0`), every context of the program and thread whose innermost frame `f` is
at block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry
valuation (`WalkI`: each block's conditions at its entry, each exit to the next block), the
thread's steps run every block of the path, each edge setting its target's `phi`s
(`Ends.edge`), and the last one ends (`Ends`) from its entry valuation (`Valuation.lastI`), at
step count `t.k + pathLen S ps` (`Valuation.lastI_k`); and the pointer facts (`Ptrs`) of every
block of the path hold from the thread, each from its entry valuation (`Valuation.blocksI`). -/
theorem Block.sound_pathI_ptrs {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} : ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame},
    coversPathI P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest → f.fn = fn →
    f.label = l → f.pc = p0 → WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    Ends c t m f rest ((Valuation.entry c t.k m f).lastI l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksI l S ps, Ptrs c t m rest q
  | [], _, _, _, _, _, _, _, hc, ht, hfn, hl, hp, hW => by
    obtain ⟨hE, hQ⟩ := Block.sound_ptrs hc hP ht hfn hl hp hW
    refine ⟨hE, fun q hq => ?_⟩
    rw [Valuation.blocksI, List.mem_singleton] at hq
    subst hq
    exact hQ
  | (l₂, ds₂, S₂) :: ps, l, p0, ds, S, t, m, f, hc, ht, hfn, hl, hp, hW => by
    rw [coversPathI, Bool.and_eq_true] at hc
    obtain ⟨hds, hd, hW'⟩ := hW
    have hE : Ends c t m f rest (Valuation.entry c t.k m f, l, S) ∧
        Ptrs c t m rest (Valuation.entry c t.k m f, l, S) := by
      have h := hc.1
      simp only [Bool.or_eq_true] at h
      rcases h with h | h
      · exact Block.sound_ptrs h hP ht hfn hl hp hds
      · exact Block.sound_to h hP ht hfn hl hp hds hd
    obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edge rfl hE.1 hd
    have hV' : Valuation.entry c (t.k + S.len + 1) m₁ f' =
        (Valuation.entry c t.k m f).into l S := hV
    have hq := Block.sound_pathI_ptrs hP ps (t := ⟨f' :: rest, t.k + S.len + 1⟩) (m := m₁)
      (f := f') hc.2 rfl (hfn'.trans hfn) hl' (by rw [hp', ← hfn]; rfl) (by rw [hV']; exact hW')
    rw [hV'] at hq
    refine ⟨Ends.pre hS₁ hst₁ hq.1 hal' hde', fun q hmem => ?_⟩
    rw [Valuation.blocksI, List.mem_cons] at hmem
    rcases hmem with rfl | hmem
    · exact hE.2
    · exact Ptrs.pre (Steps.trans_step hS₁ hst₁ (.refl _ _)) (hq.2 q hmem)

/-- **Soundness along a path with `phi`s**: for every program, function and path
`(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first block
from position `p0`), every context of the program and thread whose innermost frame `f` is at
block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry
valuation (`WalkI`: each block's conditions at its entry, each exit to the next block), the
thread's steps run every block of the path, each edge setting its target's `phi`s
(`Ends.edge`), and the last one ends (`Ends`) from its entry valuation (`Valuation.lastI`), at
step count `t.k + pathLen S ps` (`Valuation.lastI_k`) (`Block.sound_pathI_ptrs`). -/
theorem Block.sound_pathI {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) :
    Ends c t m f rest ((Valuation.entry c t.k m f).lastI l S ps) :=
  (Block.sound_pathI_ptrs hP ps hc ht hfn hl hp hW).1

/-- **A path, then a block with `fmul contract`**: for every program, function and path
`(l, ds, S) :: ps` that the path checker with `phi`s accepts (`coversPathI`, the first block from
position `p0`), whose last block, entered with valuation `W` at label `l'` with summary `S'`
(`Valuation.lastI`), exits to block `lc` (`Exit.dest`), and every conditions `dc` and summary `Sc`
that the checker with `fmul contract` accepts for `lc` from the position that exit enters it at
(`coversC`, `Exit.pc`), every context of the program and thread whose innermost frame `f` is at
block `l`'s position `p0`, with memory `m`: if the path's premises hold from the entry valuation
(`WalkI`) and `dc` holds at `lc`'s entry valuation `W.into l' S'`, the thread's steps run the
path, its last edge and block `lc`, which ends with the table's `fmul contract` operands
(`EndsC`) from that valuation (`Block.sound_pathI`, `Ends.edge`, `Block.soundC`). -/
theorem Block.sound_pathC {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 lc : Nat}
    {ds dc : List Cond} {S Sc : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) {W : Valuation} {l' : Nat}
    {S' : Summary} (hq : (Valuation.entry c t.k m f).lastI l S ps = (W, l', S'))
    (hd : S'.exit.dest W (vals W S'.nodes) = some lc)
    (hcc : coversC P fn lc (S'.exit.pc fn lc) dc Sc = true)
    (hdc : ∀ d ∈ dc, d.Holds (W.into l' S') (vals (W.into l' S') Sc.nodes)) :
    EndsC c t m f rest (W.into l' S', lc, Sc) := by
  have hE := Block.sound_pathI hP ps hc ht hfn hl hp hW
  have hk := Valuation.lastI_k (Valuation.entry c t.k m f) l S ps
  rw [hq] at hE hk
  obtain ⟨hk1, hk2, -⟩ := hk
  have hc' : W.ctx = c := hk1
  have hf' : W.fn = fn := hk2.trans hfn
  obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edge hc' hE hd
  have h := Block.soundC hcc hP (t := ⟨f' :: rest, W.k + S'.len + 1⟩) (m := m₁) (f := f') rfl
    (hfn'.trans hf') hl' (by rw [hp', hf']) (by rw [hV]; exact hdc)
  rw [hV] at h
  exact EndsWith.pre (contract := true) (q := (W.into l' S', lc, Sc)) hS₁ hst₁ h hal' hde'

/-- **A path with `phi`s that returns, under any caller frames**: `Block.sound_pathI` for a path
whose last block's exit is `ret void`, from a thread whose innermost frame `f` is above frames
`rest`: the thread's steps reach the last block's end at step count `t.k + pathLen S ps`, on the
memory `me` the last block's effects make from its entry valuation, and its next step is the
`ret`'s, with `f`'s `alloca` blocks dead: `.done` when `rest` is empty, else back to the caller
`g` at the position after its call (`g.set f.dest none none`: `ret void` sets no register). For
every program, function and path the checker accepts, and every list of caller frames. -/
theorem Block.sound_retR {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit = .ret) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + pathLen S ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me ∧
      step c ⟨fe :: rest, t.k + pathLen S ps⟩ me = .ok (match (generalizing := false) rest with
        | [] => .done (f.allocas.foldl (fun m b => m.setLive b false) me)
        | g :: gs => .next ⟨{ g.set f.dest none none with pc := g.pc + 1 } :: gs,
            t.k + pathLen S ps + 1⟩ (f.allocas.foldl (fun m b => m.setLive b false) me)) := by
  have h := Block.sound_pathI hP ps hc ht hfn hl hp hW
  have hk := (Valuation.lastI_k (Valuation.entry c t.k m f) l S ps).2.2
  revert h hret hk
  generalize (Valuation.entry c t.k m f).lastI l S ps = q
  obtain ⟨W, l', S'⟩ := q
  rintro hret ⟨fe, me, hS, -, -, hal, hde, -, -, hm, r, hn, hst⟩ hk
  simp only at hret
  simp only [Valuation.entry] at hk
  rw [hret] at hn
  simp only [Exit.next, pure, Except.pure, Except.ok.injEq] at hn
  subst hn
  rw [← hal, ← hde, ← hk]
  cases rest <;> exact ⟨fe, me, hS, hm, hst⟩

/-- **A path with `phi`s that returns**: `Block.sound_retR` for a thread with one frame `f` (a
kernel's): the next step returns, `.done` with `f`'s `alloca` blocks dead. For every program,
function and path the checker accepts. -/
theorem Block.sound_retI {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f : Frame} (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit = .ret) :
    ∃ fe me, Steps c t m ⟨[fe], t.k + pathLen S ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me ∧
      step c ⟨[fe], t.k + pathLen S ps⟩ me =
        .ok (.done (f.allocas.foldl (fun m b => m.setLive b false) me)) :=
  Block.sound_retR hP hc ht hfn hl hp hW hret

/-- A path from valuation `V` at its first block's entry to `ret`, leaving a memory of `Q`: its
premises with `phi`s hold (`WalkI`: each block's conditions at its entry valuation, each exit but
the last to the next block, an edge into a block with `phi`s setting them), its last block's exit
is `ret`, and the last block's effects succeed (`SEff.run` at the last block's entry valuation,
`Valuation.lastI`) with a memory of `Q`. False on the empty path. -/
def Ret (V : Valuation) (Q : Mem → Prop) : List (Nat × List Cond × Summary) → Prop
  | [] => False
  | (l, ds, S) :: ps => WalkI V ((l, ds, S) :: ps) ∧ (V.lastI l S ps).2.2.exit = .ret ∧
      ∃ me, SEff.run (V.lastI l S ps).1 (vals (V.lastI l S ps).1 (V.lastI l S ps).2.2.nodes)
        (V.lastI l S ps).2.2.effs = .ok me ∧ Q me

/-- A frame with no value set (`ret void`'s return to a caller) is the frame itself. -/
theorem Frame.set_none (g : Frame) (r : Option Nat) (p : Option (Val × Val)) :
    g.set r none p = g := by
  cases r <;> rfl

/-- **Return to a caller**: for every program, function and path that `coversPathI` accepts and
whose last block returns (`ret void`), every context of the program and thread whose innermost
frame `f`, at the path's first block and position, has a caller frame `g` above frames `rest`,
and every condition list `dg` and summary `Sg` that `covers` accepts for `g`'s block from the
position after the call (`g.pc + 1`): if the path's premises hold and, for the memory `me` the
last block's effects make, `dg` holds at the entry valuation of `{ g with pc := g.pc + 1 }` on
`me` with `f`'s `alloca` blocks dead (at step count `t.k + pathLen S ps + 1`), then the thread's
steps run the path, return to `g` and run `g`'s block from `g.pc + 1` to its end: it ends
(`Ends`) from that valuation. -/
theorem Block.sound_back {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f g : Frame} {rest : List Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = f :: g :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit = .ret)
    {dg : List Cond} {Sg : Summary} (hcg : covers P g.fn g.label (g.pc + 1) dg Sg = true)
    (hg : ∀ me, SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me →
      ∀ d ∈ dg, d.Holds (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
        (vals (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 })
          Sg.nodes)) :
    ∃ me, SEff.run ((Valuation.entry c t.k m f).lastI l S ps).1
        (vals ((Valuation.entry c t.k m f).lastI l S ps).1
          ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.effs = .ok me ∧
      Ends c t m { g with pc := g.pc + 1 } rest
        (Valuation.entry c (t.k + pathLen S ps + 1)
          (f.allocas.foldl (fun m b => m.setLive b false) me) { g with pc := g.pc + 1 }, g.label,
          Sg) := by
  obtain ⟨fe, me, hS, hm, hst⟩ := Block.sound_retR hP hc ht hfn hl hp hW hret
  simp only [Frame.set_none] at hst
  exact ⟨me, hm, Ends.pre hS hst
    (Block.sound hcg hP (t := ⟨{ g with pc := g.pc + 1 } :: rest, t.k + pathLen S ps + 1⟩) rfl
      rfl rfl rfl (hg me hm)) rfl rfl⟩

/-- **Soundness along a path, with its pointer facts**: for every program, function and path
`(l, ds, S) :: ps` the path checker accepts (`coversPath`), every context of the program and
thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`, whose premises
`Walk` hold from the entry valuation: the last block ends (`Ends`) from its entry valuation
(`Valuation.last`), and the pointer facts (`Ptrs`) of every block of the path hold from the
thread, each from its entry valuation (`Valuation.blocksI`, whose `Valuation.into` is
`Valuation.after` on such a path, `Exit.of_target`). The corollary of `Block.sound_pathI_ptrs`
(`Walk.toI`). -/
theorem Block.sound_path_ptrs {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPath P fn p0 ((l, ds, S) :: ps) = true) (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps)) :
    Ends c t m f rest ((Valuation.entry c t.k m f).last l S ps) ∧
      ∀ q ∈ (Valuation.entry c t.k m f).blocksI l S ps, Ptrs c t m rest q := by
  obtain ⟨hW', hc', he⟩ := Walk.toI ps hW hc
  rw [← he]
  exact Block.sound_pathI_ptrs hP ps hc' ht hfn hl hp hW'

/-- **Soundness along a path**: for every program, function and path `(l, ds, S) :: ps` the path
checker accepts (`coversPath`, the first block from position `p0`), every context of the
program and thread whose innermost frame `f` is at block `l`'s position `p0`, with memory `m`:
if the path's premises hold from the entry valuation (`Walk`: each block's conditions at its
entry, each exit to the next block), the thread's steps run every block of the path and the
last one ends (`Ends`) from its entry valuation (`Valuation.last`), at step count
`t.k + pathLen S ps`. The corollary of `Block.sound_path_ptrs` (`Walk.toI`): the exits of such
a path have targets, so its edges resolve no `phi` (`Exit.next_target`). -/
theorem Block.sound_path {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} : ∀ (ps : List (Nat × List Cond × Summary)) {l p0 : Nat} {ds : List Cond}
    {S : Summary} {t : Thread} {m : Mem} {f : Frame},
    coversPath P fn p0 ((l, ds, S) :: ps) = true → t.frames = f :: rest → f.fn = fn →
    f.label = l → f.pc = p0 → Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps) →
    Ends c t m f rest ((Valuation.entry c t.k m f).last l S ps) :=
  fun ps _ _ _ _ _ _ _ hc ht hfn hl hp hW => (Block.sound_path_ptrs hP ps hc ht hfn hl hp hW).1

/-- **A path that returns**: `Block.sound_path` for a path whose last block's exit is `ret void`,
from a thread with one frame `f` (a kernel's): the thread's steps reach the last block's end at
step count `t.k + pathLen S ps`, on the memory `me` the last block's effects make from its entry
valuation, and its next step returns, `.done` with `f`'s `alloca` blocks dead. For every program,
function and path the checker accepts; the corollary of `Block.sound_retI` (`Walk.toI`). -/
theorem Block.sound_ret {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    {t : Thread} {m : Mem} {f : Frame} (hc : coversPath P fn p0 ((l, ds, S) :: ps) = true)
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : Walk (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hret : ((Valuation.entry c t.k m f).last l S ps).2.2.exit = .ret) :
    ∃ fe me, Steps c t m ⟨[fe], t.k + pathLen S ps⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).last l S ps).1
        (vals ((Valuation.entry c t.k m f).last l S ps).1
          ((Valuation.entry c t.k m f).last l S ps).2.2.nodes)
        ((Valuation.entry c t.k m f).last l S ps).2.2.effs = .ok me ∧
      step c ⟨[fe], t.k + pathLen S ps⟩ me =
        .ok (.done (f.allocas.foldl (fun m b => m.setLive b false) me)) := by
  obtain ⟨hW', hc', he⟩ := Walk.toI ps hW hc
  rw [← he] at hret ⊢
  exact Block.sound_retI hP hc' ht hfn hl hp hW' hret

end MojoProof.Sym
