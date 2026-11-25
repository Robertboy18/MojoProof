import MojoProof.Sym.Rel

/-!
# Soundness of the block checker

The block checker (`covers`, `coversTo` and `summarize`, MojoProof/Sym/Checker.lean) is sound
for every program: a thread runs a block that the checker accepts as its summary says, when the
summary's obligations hold. The proof relates the symbolic state to the thread's frame and memory
statement by statement (`Rel`, `SState.stmt_sound`, with the `exec_*` lemmas for the statements
of the fragment, MojoProof/Sym/Exec.lean), then the terminator's step to the summary's exit
(`SState.exitAt_sound`).
The run starts from the block's float constants (`SState.start`), each a node whose value is its
literal's (`Rel.lits`, `litNodes_flit`), so a float constant operand is a node of the table.
`Rel`, its lemmas, the run's invariants (`SState.run_mono`, `SState.run_alloca`,
`summarizeAt_factors`), `SState.exitAt_sound` and the pointer facts' definitions are in
MojoProof/Sym/Rel.lean; this module has the statements' theorem `SState.stmt_sound`, the runs'
(`SState.run_ptrs`, `SState.run_sound`) and the blocks'.

`Block.sound`: for every program `P`, function `fn`, label `lbl`, position `p0`, conditions `ds`
and summary `S` with `covers P fn lbl p0 ds S = true`, every context `c` of program `P` and
thread whose innermost frame `f` runs `fn` at block `lbl` and position `p0`, with memory `m`,
if every condition of `ds` holds under the entry valuation (`Valuation.entry`) and the values of
`S`'s table (`vals`), the block ends (`Ends`): the thread's steps (`Steps`) reach the block's end
without a fault, at step count `t.k + S.len` (one step per statement), with a frame whose
registers and `fmul contract` operands are the summary's (`regVal`, `regProd`) and other fields
the entry frame's, and memory that the summary's effects make from `m` (`SEff.run`); and the
terminator's step there is the summary exit's (`Exit.next`), without a fault.

`Block.soundAt` is the theorem the others are instances of: for the checker with the `alloca`
flag (`coversAt alloca`, `summarizeAt alloca`) and any exit function whose exit is the
terminator's step when its obligations hold, concluding `EndsAt true`: the frame's `fmul contract`
operands at the block's end given by the table (`regProdIn`: for a register the block sets, the
values of its node's `fmul contract` operand terms; the relation `Rel` holds them, `Rel.prods`,
`Rel.fwf`), and its `alloca` blocks the blocks of the summary's `alloca` effects (`SEff.blocks`,
newest first) in front of the entry frame's (`Rel.allocas`; `Rel.alloca` for the statement).
`Block.sound_alloca` is its instance with `SState.exitAt`. `Block.sound_withAt` concludes
`EndsAt contract` for a flag `contract`: without it no node of the table has operand terms
(`summarizeAt_factors`), so `Ends.of_C`. With the `alloca` flag off the summary has no `alloca`'s
effect (`SState.run_alloca`, `summarizeWith_allocates`) and `EndsAt` is `EndsWith`
(`EndsAt.ends`): `Block.sound_with` concludes `EndsWith contract`, which is `Ends` without the
flag and `EndsC` with it, and `Block.sound_atWith` is its instance with `SState.exitAt_sound`.
`Block.sound` is that instance without `fmul contract` and `Block.soundC` (for `coversC`,
concluding `EndsC`) the one with it; `Block.sound_to` (MojoProof/Sym/Path.lean) is the same for
`coversTo P fn lbl p0 d₀` when the exit goes to `d₀` (`Exit.dest`, `SState.exitTo_sound`).

The theorems along a path of blocks, with `phi`s, returns and `fmul contract`, are in
MojoProof/Sym/Path.lean.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

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
  -- an operand that refers to the nodes before the new one and to it, likewise on the values
  -- before a second new node
  have lift₁ : ∀ {us nd} {x : SVal} {v}, (∀ j, x = .node j → j ≤ σ.nodes.length) →
      vs = vals V (σ.def none nd).nodes ++ us →
      x.eval V (vals V (σ.def none nd).nodes) = .ok v → x.eval V vs = .ok v := by
    intro us nd x v hx hus hv
    rw [hus]
    refine SVal.eval_append (fun j hj => ?_) hv us
    rw [vals_length]
    simp only [SState.def, List.length_append, List.length_singleton]
    exact Nat.lt_succ_of_le (hx j hj)
  -- before an `alloca`, the thread's memory has the entry memory's shape at every block number
  -- (`SEff.run_shape`)
  have shape : SEff.allocates σ.effs = false → V.mem.SameShape (fun _ => True) mi := fun hA =>
    SEff.run_shape hR.mem _ (fun _ hb => by rw [SEff.blocks_eq_nil hA] at hb; cases hb)
  -- the effects before the statement run on its table as on the final one (`SEff.run_before`),
  -- to the frame's memory
  have runMi : σ.effs.all (·.before σ.nodes.length) = true → ∀ {us m₀},
      vs = vals V σ.nodes ++ us → SEff.run V (vals V σ.nodes) σ.effs = .ok m₀ → m₀ = mi :=
    fun hb us m₀ hus hm₀ => by
      have h1 := hR.mem
      rw [hus, SEff.run_before (vs := vals V σ.nodes) (by rw [vals_length]; exact hb)] at h1
      exact Except.ok.inj (hm₀.symm.trans h1)
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
  · -- icmp: on the thread's memory as on the entry one, which has its shape (`SEff.run_shape`)
    rename_i p w a b hi
    split at h
    · -- after an `alloca`: on the memory the effects before it make, the frame's
      split at h
      · rename_i hb
        obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
        obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hv', hus⟩ := SState.node_ok hN hv
        simp only [SNode.eval, SNode.evalMore] at hv'
        obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
        rw [runMi hb hus hm₀] at hv'
        exact ⟨_, _, exec_icmp hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
          (SState.op_eval hR rfl hy (lift hy hus hu')) hv', hR.def st.res hv, rfl,
          SState.def_ptrs⟩
      · cases h
    rename_i hA
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_icmp hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu'))
      ((icmpV_shape (shape (Bool.eq_false_iff.2 hA)) u.namesIn_top u'.namesIn_top ..).symm.trans
        hv'),
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
    · split at h
      · cases h
      · split at h
        · -- a `ptrtoint` after an `alloca`: on the memory the effects before it make, the
          -- frame's
          split at h
          · rename_i hb
            obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
            cases h
            have hst' := stmt_inst hst hi
            obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
            obtain ⟨hv', hus⟩ := SState.node_ok hN hv
            simp only [SNode.eval, SNode.evalMore, hst'] at hv'
            obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
            obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
            rw [runMi hb hus hm₀] at hv'
            exact ⟨_, _, exec_cast hmd hi (SState.op_eval hR rfl hx (lift hx hus hu)) hv',
              hR.def st.res hv, rfl, SState.def_ptrs⟩
          · cases h
        · rename_i hns
          obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
          cases h
          have hst' := stmt_inst hst hi
          obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
          obtain ⟨hv', hus⟩ := SState.node_ok hN hv
          simp only [SNode.eval, hst'] at hv'
          obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
          -- the cast on the thread's memory is the cast on the entry memory: a `ptrtoint` before an
          -- `alloca`, on a memory with its shape (`SEff.run_shape`); the others read no memory
          have hcm : ∀ ch, castV V.ctx.prog.layout mi op ts u t ch =
              castV V.ctx.prog.layout V.mem op ts u t ch := by
            intro ch
            by_cases hp : op = .ptrtoint
            · subst hp
              have hA : SEff.allocates σ.effs = false := by
                revert hns; cases SEff.allocates σ.effs <;> simp
              exact (castV_shape (shape hA) u.namesIn_top ..).symm
            · cases op <;>
              first
              | exact absurd rfl hp
              | rfl
              | (unfold castV; split <;> first | rfl | contradiction)
          exact ⟨_, _, exec_cast hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
            ((hcm _).trans hv'),
            hR.def st.res hv, rfl, SState.def_ptrs⟩
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
  · -- insertvalue
    rename_i t a te e is hi
    split at h
    · -- into a constant its type gives: the node of the constant (the second obligation), then
      -- the `insertvalue`'s (the first)
      rename_i hc
      obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
      obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.constAt lbl fi.pc 0)) hN hv
      obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hus hq
      have hz : evalV (V.ctx.scope mi fi (V.k + n)) t a = .ok q := by
        refine (SNode.eval_constAt (vs := vals V σ.nodes) (i := 0) hst ?_ hc ?_).1 hq'
        · rw [hi]; rfl
        · rfl
      simp only [SNode.eval, SNode.evalMore] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain rfl : u = q :=
        Except.ok.inj ((lift₁ (fun j hj => (SVal.node.inj hj).ge) hus hu).symm.trans hq)
      exact ⟨_, _, exec_insertvalue hmd hi hz (SState.op_eval hR rfl hy
        (lift₁ (fun j hj => Nat.le_of_lt (SState.op_wf hR hy j hj)) hus hu')) hv',
        hR.def₂ st.res hq hv, rfl, SState.def₂_ptrs⟩
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval, SNode.evalMore] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_insertvalue hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu')) hv', hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- extractelement
    rename_i t a ti i hi
    have hst' := stmt_inst hst hi
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval, SNode.evalMore, hst'] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_extractelement hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu')) hv', hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- insertelement
    rename_i t a te e ti i hi
    have hst' := stmt_inst hst hi
    split at h
    · -- into a constant its type gives: the node of the constant (the second obligation), then
      -- the `insertelement`'s (the first)
      rename_i hc
      obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
      obtain ⟨z, hz, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
      obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.constAt lbl fi.pc 0)) hN hv
      obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hus hq
      have ha : evalV (V.ctx.scope mi fi (V.k + n)) t a = .ok q := by
        refine (SNode.eval_constAt (vs := vals V σ.nodes) (i := 0) hst ?_ hc ?_).1 hq'
        · rw [hi]; rfl
        · rfl
      simp only [SNode.eval, SNode.evalMore, hst'] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u'', hu'', hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain rfl : u = q :=
        Except.ok.inj ((lift₁ (fun j hj => (SVal.node.inj hj).ge) hus hu).symm.trans hq)
      exact ⟨_, _, exec_insertelement hmd hi ha
        (SState.op_eval hR rfl hy (lift₁ (fun j hj => Nat.le_of_lt (SState.op_wf hR hy j hj))
          hus hu'))
        (SState.op_eval hR rfl hz (lift₁ (fun j hj => Nat.le_of_lt (SState.op_wf hR hz j hj))
          hus hu'')) hv',
        hR.def₂ st.res hq hv, rfl, SState.def₂_ptrs⟩
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨z, hz, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval, SNode.evalMore, hst'] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u'', hu'', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_insertelement hmd hi (SState.op_eval hR rfl hx (lift hx hus hu))
      (SState.op_eval hR rfl hy (lift hy hus hu')) (SState.op_eval hR rfl hz (lift hz hus hu''))
      hv', hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- getelementptr: on the thread's memory as on the entry one, which has its shape
    -- (`SEff.run_shape`)
    rename_i fl src as b ti i hi
    have hst' := stmt_inst hst hi
    split at h
    · -- after an `alloca`: on the memory the effects before it make, the frame's
      split at h
      · rename_i hb
        split at h
        · -- on a global: the node of its pointer (the second obligation), then the
          -- `getelementptr`'s (the first)
          rename_i g
          obtain ⟨xi, hxi, h⟩ := Option.bind_eq_some_iff.1 h
          cases h
          obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
          obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
          obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.globalAt lbl fi.pc 0)) hN hv
          obtain ⟨hq', hus₀⟩ := SState.node_ok (σ := σ) hus hq
          obtain ⟨p, hg, rfl⟩ : ∃ p, V.ctx.globals g = some p ∧ q = .ptr p := by
            simp only [SNode.eval, hst', Inst.operands, List.getElem?_cons_zero] at hq'
            split at hq'
            · exact ⟨_, ‹_›, (Except.ok.inj hq').symm⟩
            · cases hq'
          simp only [SNode.eval, SNode.evalMore, hst'] at hv'
          obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
          obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
          obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
          simp only [SState.def] at hm₀
          rw [vals_snoc, SEff.run_before (by rw [vals_length]; exact hb)] at hm₀
          rw [runMi hb hus₀ hm₀] at hv'
          have hlen : (vals V (σ.def none (.globalAt lbl fi.pc 0)).nodes).length =
              σ.nodes.length + 1 := by
            rw [vals_length]
            simp only [SState.def, List.length_append, List.length_singleton]
          have hu2 : xi.eval V vs = .ok u := by
            rw [hus]
            exact SVal.eval_append (fun j hj => by
              rw [hlen]; exact Nat.lt_succ_of_lt (SState.op_wf hR hxi j hj)) hu _
          have hu2' : (SVal.node σ.nodes.length).eval V vs = .ok u' := by
            rw [hus]
            exact SVal.eval_append (fun j hj => by
              obtain rfl := SVal.node.inj hj; rw [hlen]; exact Nat.lt_succ_self _) hu' _
          obtain rfl : u' = .ptr p := Except.ok.inj (hu2'.symm.trans hq)
          have h1 := SState.op_eval hR (s := V.ctx.scope mi fi (V.k + n)) rfl hxi hu2
          have hidx : evalTVs (V.ctx.scope mi fi (V.k + n)) [.mk ti i] = .ok [u] := by
            simp only [evalTVs, evalTV]
            rw [h1]; rfl
          have hb' : evalV (V.ctx.scope mi fi (V.k + n)) (.ptr as) (.glob g) = .ok (.ptr p) := by
            simp only [evalV, Ctx.scope, hg]
            rfl
          exact ⟨_, _, exec_gep hmd hi hidx hb' hv', hR.def₂ st.res hq hv, rfl, SState.def₂_ptrs⟩
        obtain ⟨xi, hxi, h⟩ := Option.bind_eq_some_iff.1 h
        obtain ⟨xb, hxb, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hv', hus⟩ := SState.node_ok hN hv
        simp only [SNode.eval, SNode.evalMore, hst'] at hv'
        obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
        rw [runMi hb hus hm₀] at hv'
        have h1 := SState.op_eval hR (s := V.ctx.scope mi fi (V.k + n)) rfl hxi (lift hxi hus hu)
        have hidx : evalTVs (V.ctx.scope mi fi (V.k + n)) [.mk ti i] = .ok [u] := by
          simp only [evalTVs, evalTV]
          rw [h1]; rfl
        exact ⟨_, _, exec_gep hmd hi hidx (SState.op_eval hR rfl hxb (lift hxb hus hu')) hv',
          hR.def st.res hv, rfl, SState.def_ptrs⟩
      · cases h
    rename_i hA
    replace hA := Bool.eq_false_iff.2 hA
    split at h
    · -- on a global: the node of its pointer (the second obligation), then the
      -- `getelementptr`'s (the first)
      rename_i g
      obtain ⟨xi, hxi, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
      obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.globalAt lbl fi.pc 0)) hN hv
      obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hus hq
      obtain ⟨p, hg, rfl⟩ : ∃ p, V.ctx.globals g = some p ∧ q = .ptr p := by
        simp only [SNode.eval, hst', Inst.operands, List.getElem?_cons_zero] at hq'
        split at hq'
        · exact ⟨_, ‹_›, (Except.ok.inj hq').symm⟩
        · cases hq'
      simp only [SNode.eval, hst'] at hv'
      obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
      obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
      -- the values on the table with the global's node are those of the final table
      have hlen : (vals V (σ.def none (.globalAt lbl fi.pc 0)).nodes).length =
          σ.nodes.length + 1 := by
        rw [vals_length]
        simp only [SState.def, List.length_append, List.length_singleton]
      have hu2 : xi.eval V vs = .ok u := by
        rw [hus]
        exact SVal.eval_append (fun j hj => by
          rw [hlen]; exact Nat.lt_succ_of_lt (SState.op_wf hR hxi j hj)) hu _
      have hu2' : (SVal.node σ.nodes.length).eval V vs = .ok u' := by
        rw [hus]
        exact SVal.eval_append (fun j hj => by
          obtain rfl := SVal.node.inj hj; rw [hlen]; exact Nat.lt_succ_self _) hu' _
      obtain rfl : u' = .ptr p := Except.ok.inj (hu2'.symm.trans hq)
      have h1 := SState.op_eval hR (s := V.ctx.scope mi fi (V.k + n)) rfl hxi hu2
      have hidx : evalTVs (V.ctx.scope mi fi (V.k + n)) [.mk ti i] = .ok [u] := by
        simp only [evalTVs, evalTV]
        rw [h1]; rfl
      have hb : evalV (V.ctx.scope mi fi (V.k + n)) (.ptr as) (.glob g) = .ok (.ptr p) := by
        simp only [evalV, Ctx.scope, hg]
        rfl
      exact ⟨_, _, exec_gep hmd hi hidx hb
        ((gep_shape (shape hA) (Val.namesIn_top _) ..).symm.trans hv'),
        hR.def₂ st.res hq hv, rfl, SState.def₂_ptrs⟩
    obtain ⟨xi, hxi, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨xb, hxb, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval, hst'] at hv'
    obtain ⟨u, hu, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    have h1 := SState.op_eval hR (s := V.ctx.scope mi fi (V.k + n)) rfl hxi (lift hxi hus hu)
    have hidx : evalTVs (V.ctx.scope mi fi (V.k + n)) [.mk ti i] = .ok [u] := by
      simp only [evalTVs, evalTV]
      rw [h1]; rfl
    exact ⟨_, _, exec_gep hmd hi hidx (SState.op_eval hR rfl hxb (lift hxb hus hu'))
      ((gep_shape (shape hA) u'.namesIn_top ..).symm.trans hv'),
      hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- getelementptr with other than one index, on a base that is not a global, as the one with
    -- one index
    rename_i fl src as b idx _ hi
    have hst' := stmt_inst hst hi
    split at h
    · -- after an `alloca`: on the memory the effects before it make, the frame's
      split at h
      · rename_i hb
        obtain ⟨ys, hys, h⟩ := Option.bind_eq_some_iff.1 h
        obtain ⟨xb, hxb, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hv', hus⟩ := SState.node_ok hN hv
        simp only [SNode.eval, SNode.evalMore, hst'] at hv'
        obtain ⟨is, his, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
        rw [runMi hb hus hm₀] at hv'
        exact ⟨_, _, exec_gep hmd hi (SState.ops_eval hR rfl hus hys his)
          (SState.op_eval hR rfl hxb (lift hxb hus hu')) hv', hR.def st.res hv, rfl,
          SState.def_ptrs⟩
      · cases h
    rename_i hA
    replace hA := Bool.eq_false_iff.2 hA
    obtain ⟨ys, hys, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨xb, hxb, h⟩ := Option.bind_eq_some_iff.1 h
    cases h
    obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
    obtain ⟨hv', hus⟩ := SState.node_ok hN hv
    simp only [SNode.eval, SNode.evalMore, hst'] at hv'
    obtain ⟨is, his, hv'⟩ := Except.bind_eq_ok.1 hv'
    obtain ⟨u', hu', hv'⟩ := Except.bind_eq_ok.1 hv'
    exact ⟨_, _, exec_gep hmd hi (SState.ops_eval hR rfl hus hys his)
      (SState.op_eval hR rfl hxb (lift hxb hus hu'))
      ((gep_shape (shape hA) u'.namesIn_top ..).symm.trans hv'),
      hR.def st.res hv, rfl, SState.def_ptrs⟩
  · -- load
    rename_i vol ty as p al hi
    split at h
    · -- after a store: the node of the `load` from the memory the effects before it make, which
      -- run on its table as on the final one (`SEff.run_before`), to the frame's memory
      rename_i hs
      have hst' := stmt_inst hst hi
      split at h
      · rename_i hb
        split at h
        · -- on a global: the node of its pointer (the second obligation), then the `load`'s (the
          -- first)
          rename_i g
          cases h
          obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
          obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
          obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.globalAt lbl fi.pc 0)) hN hv
          obtain ⟨hq', hus₀⟩ := SState.node_ok (σ := σ) hus hq
          obtain ⟨p, hg, rfl⟩ : ∃ p, V.ctx.globals g = some p ∧ q = .ptr p := by
            simp only [SNode.eval, hst', Inst.operands, List.getElem?_cons_zero] at hq'
            split at hq'
            · exact ⟨_, ‹_›, (Except.ok.inj hq').symm⟩
            · cases hq'
          simp only [SNode.eval, hst'] at hv'
          obtain ⟨pv, hpv, hv1⟩ := Except.bind_eq_ok.1 hv'
          obtain ⟨a, ha, hv2⟩ := Except.bind_eq_ok.1 hv1
          obtain ⟨m₀, hm₀, hv3⟩ := Except.bind_eq_ok.1 hv2
          obtain ⟨v₀, hv₀, hv4⟩ := Except.bind_eq_ok.1 hv3
          -- the pointer on the table with the global's node is the global's
          have hlen : (vals V (σ.def none (.globalAt lbl fi.pc 0)).nodes).length =
              σ.nodes.length + 1 := by
            rw [vals_length]
            simp only [SState.def, List.length_append, List.length_singleton]
          have hpv2 : (SVal.node σ.nodes.length).eval V vs = .ok pv := by
            rw [hus]
            exact SVal.eval_append (fun j hj => by
              obtain rfl := SVal.node.inj hj; rw [hlen]; exact Nat.lt_succ_self _) hpv _
          obtain rfl : pv = .ptr p := Except.ok.inj (hpv2.symm.trans hq)
          have hb' : evalV (V.ctx.scope mi fi (V.k + n)) (.ptr as) (.glob g) = .ok (.ptr p) := by
            simp only [evalV, Ctx.scope, hg]
            rfl
          -- the effects run on the table with the global's node as on the final one
          have h1 := hR.mem
          rw [hus₀, SEff.run_before (vs := vals V σ.nodes) (by rw [vals_length]; exact hb)] at h1
          simp only [SState.def] at hm₀
          rw [vals_snoc, SEff.run_before (by rw [vals_length]; exact hb)] at hm₀
          obtain rfl : m₀ = mi := Except.ok.inj (hm₀.symm.trans h1)
          cases hu : (st.md.any (·.1 == "noundef") && !v₀.defined)
          · rw [hu] at hv4
            cases hv4
            refine ⟨_, _, exec_load hmd hi hb' ha hv₀ hu, ?_, rfl,
              fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
            · exact (hR.def₂ st.res hq hv).push
                (by simp only [SEff.apply, hst', hq, ha, bind, Except.bind, pure, Except.pure,
                  Ctx.scope])
                (fun h' => absurd (hs.symm.trans h') (by decide))
            · by_cases hj' : j < (σ.def none (.globalAt lbl fi.pc 0)).nodes.length
              · have h' : (σ.def none (.globalAt lbl fi.pc 0)).nodes[j]? =
                    some (.load l pc' p') := by
                  rw [← List.getElem?_append_left
                    (l₂ := [SNode.loadAfter lbl fi.pc (.node σ.nodes.length) σ.effs]) hj']
                  exact hn
                exact absurd (getElem?_snoc_ge (l := σ.nodes) hj h').2 (by intro h; cases h)
              · obtain ⟨rfl, he⟩ := getElem?_snoc_ge
                  (l := (σ.def none (.globalAt lbl fi.pc 0)).nodes) (Nat.le_of_not_lt hj') hn
                cases he
            · simp only [List.drop_left, List.mem_singleton, reduceCtorEq] at hm
          · rw [hu] at hv4
            cases hv4
        obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
        cases h
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨hv', hus⟩ := SState.node_ok hN hv
        simp only [SNode.eval, hst'] at hv'
        obtain ⟨pv, hpv, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨q, hq, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨m₀, hm₀, hv'⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨v₀, hv₀, hv'⟩ := Except.bind_eq_ok.1 hv'
        have hpv' := lift hx hus hpv
        have h1 := hR.mem
        rw [hus, SEff.run_before (vs := vals V σ.nodes) (by rw [vals_length]; exact hb)] at h1
        obtain rfl : m₀ = mi := Except.ok.inj (hm₀.symm.trans h1)
        cases hu : (st.md.any (·.1 == "noundef") && !v₀.defined)
        · rw [hu] at hv'
          cases hv'
          refine ⟨_, _, exec_load hmd hi (SState.op_eval hR rfl hx hpv') hq hv₀ hu, ?_, rfl,
            fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
          · exact (hR.def st.res hv).push
              (by simp only [SEff.apply, hst', hpv', hq, bind, Except.bind, pure, Except.pure,
                Ctx.scope])
              (fun h' => absurd (hs.symm.trans h') (by decide))
          · obtain ⟨rfl, he⟩ := getElem?_snoc_ge hj hn
            cases he
          · simp only [List.drop_left, List.mem_singleton, reduceCtorEq] at hm
        · rw [hu] at hv'
          cases hv'
      · cases h
    · rename_i hns
      obtain ⟨tr, htr⟩ := hR.trace (Bool.eq_false_of_ne_true hns)
      have hst' := stmt_inst hst hi
      split at h
      · -- on a global: the node of its pointer (the second obligation), then the `load`'s (the
        -- first)
        rename_i g
        cases h
        obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
        obtain ⟨q, hq⟩ := hO (.ok _) (List.mem_cons_of_mem _ (List.Mem.head _))
        obtain ⟨hv', hus⟩ := SState.node_ok (σ := σ.def none (.globalAt lbl fi.pc 0)) hN hv
        obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hus hq
        obtain ⟨p, hg, rfl⟩ : ∃ p, V.ctx.globals g = some p ∧ q = .ptr p := by
          simp only [SNode.eval, hst', Inst.operands, List.getElem?_cons_zero] at hq'
          split at hq'
          · exact ⟨_, ‹_›, (Except.ok.inj hq').symm⟩
          · cases hq'
        simp only [SNode.eval, hst'] at hv'
        obtain ⟨pv, hpv, hv1⟩ := Except.bind_eq_ok.1 hv'
        obtain ⟨a, ha, hv2⟩ := Except.bind_eq_ok.1 hv1
        obtain ⟨v₀, hv₀, hv3⟩ := Except.bind_eq_ok.1 hv2
        -- the pointer on the table with the global's node is the global's
        have hlen : (vals V (σ.def none (.globalAt lbl fi.pc 0)).nodes).length =
            σ.nodes.length + 1 := by
          rw [vals_length]
          simp only [SState.def, List.length_append, List.length_singleton]
        have hpv2 : (SVal.node σ.nodes.length).eval V vs = .ok pv := by
          rw [hus]
          exact SVal.eval_append (fun j hj => by
            obtain rfl := SVal.node.inj hj; rw [hlen]; exact Nat.lt_succ_self _) hpv _
        obtain rfl : pv = .ptr p := Except.ok.inj (hpv2.symm.trans hq)
        have hb : evalV (V.ctx.scope mi fi (V.k + n)) (.ptr as) (.glob g) = .ok (.ptr p) := by
          simp only [evalV, Ctx.scope, hg]
          rfl
        cases hu : (st.md.any (·.1 == "noundef") && !v₀.defined)
        · rw [hu] at hv3
          cases hv3
          subst htr
          refine ⟨_, _, exec_load hmd hi hb ha
            ((Mem.load_retrace V.ctx.prog.layout V.mem tr V.ctx.who as ty a
              (some (al.getD (V.ctx.prog.layout.align ty)))).trans hv₀) hu, ?_, rfl,
            fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
          · exact (hR.def₂ st.res hq hv).push
              (by simp only [SEff.apply, hst', hq, ha, bind, Except.bind, pure, Except.pure,
                Ctx.scope])
              (fun _ => ⟨_, rfl⟩)
          · by_cases hj' : j < (σ.def none (.globalAt lbl fi.pc 0)).nodes.length
            · have h' : (σ.def none (.globalAt lbl fi.pc 0)).nodes[j]? = some (.load l pc' p') := by
                rw [← List.getElem?_append_left
                  (l₂ := [SNode.load lbl fi.pc (.node σ.nodes.length)]) hj']
                exact hn
              exact absurd (getElem?_snoc_ge (l := σ.nodes) hj h').2 (by intro h; cases h)
            · obtain ⟨rfl, he⟩ := getElem?_snoc_ge (l := (σ.def none (.globalAt lbl fi.pc 0)).nodes)
                (Nat.le_of_not_lt hj') hn
              cases he
              refine ⟨rfl, rfl, as, .glob g, vol, ty, al, hi, ?_⟩
              change _ = SVal.eval V (vals V (List.take _
                ((σ.def none (.globalAt lbl fi.pc 0)).nodes ++ [_]))) _
              rw [List.take_left]
              exact hb.trans hpv.symm
          · simp only [List.drop_left, List.mem_singleton, reduceCtorEq] at hm
        · rw [hu] at hv3
          cases hv3
      obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
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
          refine ⟨rfl, rfl, as, p, vol, ty, al, hi, ?_⟩
          change _ = SVal.eval V (vals V (List.take σ.nodes.length (σ.nodes ++ [_]))) _
          rw [List.take_left]
          exact (SState.op_eval hR rfl hx hpv').trans hpv.symm
        · simp only [List.drop_left, List.mem_singleton, reduceCtorEq] at hm
      · rw [hu] at hv'
        cases hv'
  · -- store
    rename_i vol t v as p al hi
    split at h
    · -- on a global: the node of its pointer, then the `store`'s effect on it
      rename_i g
      obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      have hst' := stmt_inst hst hi
      obtain ⟨q, hq⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hN hq
      obtain ⟨p, hg, rfl⟩ : ∃ p, V.ctx.globals g = some p ∧ q = .ptr p := by
        simp only [SNode.eval, hst', Inst.operands, List.getElem?_cons_succ,
          List.getElem?_cons_zero] at hq'
        split at hq'
        · exact ⟨_, ‹_›, (Except.ok.inj hq').symm⟩
        · cases hq'
      obtain ⟨mf, hmf⟩ := hM
      obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc hmf
      cases Except.ok.inj (h₀.symm.trans hR.mem)
      have he' := he
      simp only [SEff.apply, hst'] at he
      obtain ⟨xv, hxv, he1⟩ := Except.bind_eq_ok.1 he
      obtain ⟨pv, hpv, he2⟩ := Except.bind_eq_ok.1 he1
      obtain ⟨a, ha, he3⟩ := Except.bind_eq_ok.1 he2
      obtain rfl : pv = .ptr p := Except.ok.inj (hpv.symm.trans hq)
      have hb : evalV (V.ctx.scope mi fi (V.k + n)) (.ptr as) (.glob g) = .ok (.ptr p) := by
        simp only [evalV, Ctx.scope, hg]
        rfl
      refine ⟨_, _, exec_store hmd hi (SState.op_eval hR rfl hx hxv) hb ha he3,
        ((hR.def none hq).frame (fi' := fi) rfl rfl rfl rfl rfl rfl).store he', rfl,
        fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
      · exact absurd (getElem?_snoc_ge hj hn).2 (by intro h; cases h)
      · simp only [List.drop_left, List.mem_singleton, SEff.store.injEq] at hm
        obtain ⟨rfl, rfl, rfl, rfl⟩ := hm
        exact ⟨rfl, rfl, ⟨as, .glob g, vol, _, al, hi, hb.trans hpv.symm⟩, vol, t, v, _, al, hi,
          .inl hx⟩
    split at h
    · -- a constant its type gives: the node of its value, then the `store`'s effect of it
      rename_i hc
      obtain ⟨y, hy, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      have hst' := stmt_inst hst hi
      obtain ⟨q, hq⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hq', -⟩ := SState.node_ok (σ := σ) hN hq
      have hz : evalV (V.ctx.scope mi fi (V.k + n)) t v = .ok q := by
        refine (SNode.eval_constAt (vs := vals V σ.nodes) (i := 0) hst ?_ hc ?_).1 hq'
        · rw [hi]; rfl
        · rfl
      obtain ⟨mf, hmf⟩ := hM
      obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc hmf
      cases Except.ok.inj (h₀.symm.trans hR.mem)
      have he' := he
      simp only [SEff.apply, hst'] at he
      obtain ⟨xv, hxv, he1⟩ := Except.bind_eq_ok.1 he
      obtain ⟨pv, hpv, he2⟩ := Except.bind_eq_ok.1 he1
      obtain ⟨a, ha, he3⟩ := Except.bind_eq_ok.1 he2
      obtain rfl : xv = q := Except.ok.inj (hxv.symm.trans hq)
      refine ⟨_, _, exec_store hmd hi hz (SState.op_eval hR rfl hy hpv) ha he3,
        ((hR.def none hq).frame (fi' := fi) rfl rfl rfl rfl rfl rfl).store he', rfl,
        fun j l pc' p' hj hn => ?_, fun l pc' v' p' hm => ?_⟩
      · exact absurd (getElem?_snoc_ge hj hn).2 (by intro h; cases h)
      · simp only [List.drop_left, List.mem_singleton, SEff.store.injEq] at hm
        obtain ⟨rfl, rfl, rfl, rfl⟩ := hm
        refine ⟨rfl, rfl, ⟨as, p, vol, _, al, hi, (SState.op_eval hR rfl hy hpv).trans hpv.symm⟩,
          vol, t, v, _, al, hi, .inr ⟨hc, _, rfl, ?_⟩⟩
        simp only [SState.def, List.getElem?_append_right (Nat.le_refl _), Nat.sub_self,
          List.getElem?_cons_zero]
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
        vol, t, v, _, al, hi, .inl hx⟩
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
          · obtain ⟨j, rfl, hj⟩ := SState.op_flit h
            show none = SVal.prodsWith V _ (.node j) (σ.nodes[j]?.bind SNode.factors)
            rw [hj]
            rfl
          · cases h
        refine ⟨_, _, exec_fbinC hmd hi he (SState.op_eval hR rfl hx hxu)
          (SState.op_eval hR rfl hy hyu) (by rw [hp hx, hp hy]; exact hw'),
          hR.defP st.res hw (fun pq j hf hj => ?_) ?_
            (fun _ _ h => by unfold SNode.fbinOf at h; split at h <;> cases h), rfl,
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
  · -- a call of a special register or of the lane number
    rename_i fm ty g hi
    split at h
    · rename_i fn hfn
      split at h
      · rename_i r d hg
        split at h
        · rename_i hc
          cases h
          simp only [Bool.and_eq_true] at hc
          obtain ⟨⟨hfm, hd⟩, hck⟩ := hc
          have hst' := stmt_inst hst hi
          obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
          obtain ⟨hv', -⟩ := SState.node_ok hN hv
          simp only [SNode.eval, hst', hfn, hg] at hv'
          exact ⟨_, _, exec_sreg hmd hi hfn hg hfm hd (isOk_unit hck)
            ((withAttrs_shape (SEff.run_shape hR.mem (fun _ => False) fun _ _ h => h)
              (by trivial) ..).symm.trans hv'),
            hR.def st.res hv, rfl, SState.def_ptrs⟩
        · cases h
      · -- a call of the lane number
        rename_i hg
        split at h
        · rename_i hc
          cases h
          simp only [Bool.and_eq_true] at hc
          obtain ⟨⟨hfm, hd⟩, hck⟩ := hc
          have hst' := stmt_inst hst hi
          obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
          obtain ⟨hv', -⟩ := SState.node_ok hN hv
          simp only [SNode.eval, hst', hfn, hg] at hv'
          exact ⟨_, _, exec_laneid hmd hi hfn hg hfm hd (isOk_unit hck)
            ((withAttrs_shape (SEff.run_shape hR.mem (fun _ => False) fun _ _ h => h)
              (by trivial) ..).symm.trans hv'),
            hR.def st.res hv, rfl, SState.def_ptrs⟩
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
  · -- alloca: the pointer to the block its effect makes, at the number `exec` gives it, as the
    -- effects keep `next` (`SEff.run_next`)
    rename_i t cnt al hi
    split at h
    · obtain ⟨c, hc, h⟩ := Option.bind_eq_some_iff.1 h
      cases h
      have hst' := stmt_inst hst hi
      obtain ⟨mf, hmf⟩ := hM
      obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc (es := σ.effs) (e := .alloca lbl fi.pc n c) hmf
      have hm₀ : m₀ = mi := Except.ok.inj (h₀.symm.trans hR.mem)
      rw [hm₀] at he
      have he₀ := he
      have hfr : mi.fresh V.ctx.who.thread (V.k + n) = V.mem.fresh V.ctx.who.thread (V.k + n) := by
        simp only [Mem.fresh, SEff.run_next hR.mem]
      simp only [SEff.apply, hst'] at he
      obtain ⟨cn, hcn, he⟩ := Except.bind_eq_ok.1 he
      split at he
      · cases he
      rename_i hfree
      cases he
      obtain ⟨v, hv⟩ := hO (.ok _) (List.Mem.head _)
      obtain ⟨hv', -⟩ := SState.node_ok hN hv
      simp only [SNode.eval, SNode.evalMore, pure, Except.pure, Except.ok.injEq] at hv'
      subst hv'
      have hn1 : cnt = none → cn = 1 := by
        rintro rfl
        simp only [SState.count, Option.some.injEq] at hc
        subst hc
        simp only [SEff.count, pure, Except.pure, Except.ok.injEq] at hcn
        exact hcn.symm
      have hn : ∀ ct cv, cnt = some (.mk ct cv) → ∃ (w : Nat) (b : BitVec w),
          evalV (V.ctx.scope mi fi (V.k + n)) ct cv = .ok (.bits w b) ∧ b.toNat = cn := by
        rintro ct cv rfl
        simp only [SState.count, Option.map_eq_some_iff] at hc
        obtain ⟨y, hy, rfl⟩ := hc
        unfold SEff.count at hcn
        obtain ⟨u, hu, hcn⟩ := Except.bind_eq_ok.1 hcn
        have hu' := SState.op_eval (s := V.ctx.scope mi fi (V.k + n)) hR rfl hy hu
        cases u with
        | bits w b =>
          simp only [pure, Except.pure, Except.ok.injEq] at hcn
          exact ⟨w, b, hu', hcn⟩
        | _ => cases hcn
      have hx := exec_alloca (c := V.ctx) (s := V.ctx.scope mi fi (V.k + n)) (k := V.k + n)
        (f := fi) hmd hi hn1 hn (by
          show (mi.blocks (mi.fresh V.ctx.who.thread (V.k + n))).isSome = false
          rw [hfr]; exact Bool.eq_false_iff.2 hfree)
      simp only [Ctx.scope] at hx
      rw [hfr, hR.fn, ← hR.vfn] at hx
      have hR' := (hR.def st.res (nd := .fresh n) hv).alloca
        (b := V.mem.fresh V.ctx.who.thread (V.k + n)) he₀ rfl
      refine ⟨_, _, hx, ?_, rfl, ?_, fun l pc' v p hm => by simp at hm⟩
      · refine hR'.frame ?_ ?_ ?_ ?_ ?_ ?_ <;> (cases st.res <;> rfl)
      · exact (SState.def_ptrs (V := V) (vs := vs) (lbl := lbl) (pc := fi.pc) (σ := σ)
          (res := st.res) (nd := .fresh n) (st := st) (s := V.ctx.scope mi fi (V.k + n))).1
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
`n`-th after the entry (a prefix of the statements from there, so a run that stops before the
terminator too) whose final state is good: the thread's steps run them, to a frame and
memory that the final state describes; and they reach each `load` node and each `store` effect
the run appends to `σ`'s, whose statement's pointer operand evaluates in the thread's scope
there to the term's pointer value (`PtrAt`): on the values of the nodes before it for a `load`,
on `vs` for a `store`, whose stored operand the effect's term describes with the final register
entries (`StoreAt`). -/
theorem SState.run_ptrs {V : Valuation} {vs : List (Except Fault Val)} {f : Frame}
    {b : LLVM.Block} {lbl p0 : Nat} {rest : List Frame} {contract : Bool}
    (hb : V.fn.blocks.find? (·.label == lbl) = some b) (hfn : f.fn = V.fn) (hlbl : f.label = lbl) :
    ∀ (sts : List Stmt) (n : Nat) (σ σf : SState) (fi : Frame) (mi : Mem) (kk : Nat),
      sts <+: b.stmts.toList.drop (p0 + n) → fi.pc = p0 + n → kk = V.k + n →
      Rel V vs f σ fi mi → SState.run contract V.ctx.prog lbl p0 sts n σ = some σf →
      Good V vs σf →
      (∃ fe me, Steps V.ctx ⟨fi :: rest, kk⟩ mi ⟨fe :: rest, kk + sts.length⟩ me ∧
        Rel V vs f σf fe me ∧ fe.pc = fi.pc + sts.length) ∧
      (∀ j l pc p, σ.nodes.length ≤ j → σf.nodes[j]? = some (.load l pc p) →
        PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn l pc true
          (p.eval V (vals V (σf.nodes.take j)))) ∧
      ∀ l pc v p, SEff.store l pc v p ∈ σf.effs.drop σ.effs.length →
        PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn l pc false (p.eval V vs) ∧
          StoreAt V.fn l pc σf.nodes σf.regs v
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
      obtain ⟨tl, htl⟩ := hsts
      have hst : b.stmts[p0 + n]? = some st := by
        rw [← Array.getElem?_toList, ← Nat.add_zero (p0 + n), ← List.getElem?_drop, ← htl]
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
        fi' mi' (kk + 1) ⟨tl, by rw [← Nat.add_assoc, ← List.tail_drop, ← htl]; rfl⟩ (by omega)
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
          obtain ⟨rfl, rfl, hq⟩ := hL j l pc p hj hn
          rw [hmo3, List.take_append_of_le_length (by omega)]
          exact here hq
      · rw [hmo2, List.drop_append_of_le_length (by rw [he₁, List.length_append]; omega),
          List.mem_append] at hm
        rcases hm with hm | hm
        · obtain ⟨rfl, rfl, hq, vol, ty, w, ptr, al, hi, hop⟩ := hSt l pc v p hm
          refine ⟨here hq, b, st, vol, ty, w, ptr, al, hb, by rw [hpc]; exact hst, hi, ?_⟩
          rcases hop with hop | ⟨hc, j, rfl, hj⟩
          · rw [hmo3, hn₁, hmo4, hr₁]
            simpa only [List.append_assoc] using SState.op_storeVal hop (ns₁ ++ ns) (rs ++ rs₁)
          · rw [hmo3]
            have hj' := List.getElem?_append_left (l₂ := ns) (List.getElem?_eq_some_iff.1 hj).1
            rw [hj] at hj'
            cases w <;> simp only [tyConst, Bool.false_eq_true] at hc <;>
              exact .inr ⟨j, _, _, _, rfl, hj'⟩
        · obtain ⟨hq, hv⟩ := hSt' l pc v p (by rw [hmo2, List.drop_left]; exact hm)
          exact ⟨PtrAt.pre (.cons hstep (.refl _ _)) hq, hv⟩
    · cases h

/-- **The start state describes the entry frame**: for every context `c`, step count `k`, memory
`m`, frame `f`, block `b`, nodes `ns` after the block's float constants and `alloca` flag `a`,
the start state (`SState.start`) at `f`'s function, block and position, with `SState.alloca` set
to `a`, describes frame `f` and memory `m` from `f`, under the entry valuation and the values of
the table that `ns` extends: no register is set, no effect has run, and the float constant nodes
have their literals' values. -/
theorem Rel.startAt {c : Ctx} {k : Nat} {m : Mem} {f : Frame} {b : LLVM.Block} {ns : List SNode}
    {a : Bool} :
    Rel (Valuation.entry c k m f)
      (vals (Valuation.entry c k m f) ((SState.start f.fn f.label f.pc b).nodes ++ ns)) f
      { SState.start f.fn f.label f.pc b with alloca := a } f m := by
  refine ⟨rfl, rfl, rfl, rfl, rfl, fun _ => rfl, fun _ => rfl, (by intro r v h; cases h),
    fun x pq j h => ?_, fun j ft lit hj => ?_, rfl, fun _ => ⟨m.trace, rfl⟩⟩
  · cases x with
    | node i =>
      obtain ⟨nd, hnd, hf⟩ := Option.bind_eq_some_iff.1 h
      obtain ⟨_, _, rfl⟩ := litNodes_flit (List.mem_of_getElem? hnd)
      cases hf
    | _ => cases h
  · obtain ⟨hlt, -⟩ := List.getElem?_eq_some_iff.1 hj
    simp only [SVal.eval]
    rw [vals_flit _ (by rw [List.getElem?_append_left hlt]; exact hj)]
    rfl

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
  (SState.run_ptrs hb hfn hlbl sts n σ σf fi mi kk ⟨[], by rw [List.append_nil, h₁]⟩ h₂ h₃ hR h
    hG).1

/-- The `fmul contract` operands of the frame at the end of the block that summary `S`
describes from valuation `V`: with `contract`, the table's (`regProdIn`, as `EndsC` gives them),
else `regProd`'s (as `Ends` gives them). -/
def prodsWith (contract : Bool) (V : Valuation) (S : Summary) : Nat → Option (Val × Val) :=
  cond contract (regProdIn V (vals V S.nodes) S.nodes S.regs) (regProd V S.regs)

/-- `Ends` with the `fmul contract` operands `prodsWith contract` of the frame at the block's
end: without `contract` it is `Ends`, with it `EndsC` (both are defined as its instances). -/
def EndsWith (contract : Bool) (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, lbl, S) => ∃ fe me, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.allocas = f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = prodsWith contract V S r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      ∃ r, S.exit.next V (vals V S.nodes) rest (V.k + S.len) fe me = .ok r ∧
        step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r

/-- **`EndsWith` with the summary's `alloca` blocks**: as `EndsWith`, but the frame `fe` at the
block's end has the blocks of the summary's `alloca` effects (`SEff.blocks`, newest first) in
front of frame `f`'s. `EndsWith` is the case of a summary with no `alloca` (`EndsAt.ends`). The
conclusion of `Block.soundAt`. -/
def EndsAt (contract : Bool) (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop
  | (V, lbl, S) => ∃ fe me, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.allocas = SEff.blocks V S.effs ++ f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = prodsWith contract V S r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      ∃ r, S.exit.next V (vals V S.nodes) rest (V.k + S.len) fe me = .ok r ∧
        step c ⟨fe :: rest, V.k + S.len⟩ me = .ok r

/-- **A block that allocates nothing ends as `EndsWith` says**: for every flag, context, thread,
memory, frames, valuation, block and summary with no `alloca` effect (`SEff.allocates`),
`EndsAt` gives `EndsWith` (`SEff.blocks_eq_nil`). -/
theorem EndsAt.ends {contract : Bool} {c : Ctx} {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} {V : Valuation} {lbl : Nat} {S : Summary}
    (h : EndsAt contract c t m f rest (V, lbl, S)) (hA : SEff.allocates S.effs = false) :
    EndsWith contract c t m f rest (V, lbl, S) := by
  obtain ⟨fe, me, h1, h2, h3, h4, h5⟩ := h
  exact ⟨fe, me, h1, h2, h3, by rw [h4, SEff.blocks_eq_nil hA, List.nil_append], h5⟩

/-- Block `lbl` with summary `S`, entered with valuation `V`, ends: the thread's steps from `t`
on `m` reach the block's end at step count `V.k + S.len`, with a frame `fe` (above frames `rest`)
of function `V.fn` at block `lbl` whose `alloca` blocks and caller's register are those of frame
`f`, whose registers and `fmul contract` operands are the summary's (`regVal`, `regProd`), on the
memory `me` the summary's effects make (`SEff.run`); and the terminator's step there is the
summary exit's (`Exit.next`), without a fault. It is `EndsWith` without `contract`, whose
`fmul contract` operands `prodsWith false` are `regProd`'s. -/
def Ends (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop :=
  EndsWith false c t m f rest

/-- `Ends` with the `fmul contract` operands of the frame at the block's end given by the table
(`regProdIn`): for a register the block sets, the values of its node's `fmul contract` operand
terms. It is `EndsWith` with `contract`. The conclusion of `Block.soundC`. -/
def EndsC (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × Summary → Prop :=
  EndsWith true c t m f rest

/-- `EndsC` of a summary with no `fmul contract` node is `Ends`: without such a node no register
entry has `fmul contract` operand terms (`SVal.factors`), so `regProdIn` gives what `regProd`
gives (none for a register the block sets). -/
theorem Ends.of_C {c : Ctx} {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    {V : Valuation} {lbl : Nat} {S : Summary} (h : EndsC c t m f rest (V, lbl, S))
    (hf : ∀ nd ∈ S.nodes, nd.factors = none) : Ends c t m f rest (V, lbl, S) := by
  obtain ⟨fe, me, hS, h1, h2, h3, h4, hr, hp, hm, hx⟩ := h
  refine ⟨fe, me, hS, h1, h2, h3, h4, hr, fun r => (hp r).trans ?_, hm, hx⟩
  show regProdIn V (vals V S.nodes) S.nodes S.regs r = regProd V S.regs r
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
      PtrAt c t m rest V.fn l pc false (p.eval V (vals V S.nodes)) ∧
        StoreAt V.fn l pc S.nodes S.regs v

/-- `Ptrs` after steps before it. -/
theorem Ptrs.pre {c : Ctx} {t t₁ : Thread} {m m₁ : Mem} {rest : List Frame}
    {q : Valuation × Nat × Summary} (h : Steps c t m t₁ m₁) (hq : Ptrs c t₁ m₁ rest q) :
    Ptrs c t m rest q := by
  obtain ⟨V, lbl, S⟩ := q
  exact ⟨fun j l pc p hn => PtrAt.pre h (hq.1 j l pc p hn),
    fun l pc v p hm => ⟨PtrAt.pre h (hq.2 l pc v p hm).1, (hq.2 l pc v p hm).2⟩⟩

/-- **Soundness of the block checker with an exit function** `ex`, `fmul contract` when
`contract` and `alloca` when `alloca`, for every program, function, block, entry position,
conditions `ds` and summary `S` that `coversAt` accepts with `alloca`, `ex` and `contract`, every
context `c` of the program and thread whose innermost frame `f` runs `fn` at block `lbl` and
position `p0`, with memory `m`: if every condition of `ds` holds under the entry valuation and,
at the block's end, `ex`'s exit is the terminator's step whenever its obligations hold (`hex`),
the block ends with the frame's `fmul contract` operands given by the table and the summary's
`alloca` blocks in front of the entry frame's (`EndsAt`) from the entry valuation, and its
pointer facts hold (`Ptrs`). `Block.sound_withAt` gives the ends for every `contract`
(`EndsAt contract`). -/
theorem Block.soundAt {alloca : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {ds : List Cond} {S : Summary}
    {contract : Bool} (hc : coversAt alloca P fn lbl p0 ex ds S contract = true) {c : Ctx}
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
    EndsAt true c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) := by
  subst hP hfn hl hp
  obtain ⟨frames, k⟩ := t
  obtain rfl : frames = f :: rest := ht
  unfold coversAt at hc
  split at hc
  · rename_i S' hS
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    obtain ⟨rfl, hall⟩ := hc
    have hO : ∀ d ∈ S'.obls, d.Holds (Valuation.entry c k m f)
        (vals (Valuation.entry c k m f) S'.nodes) := fun d hd =>
      hds d ((List.isPrefixOf_iff_prefix.1 hall).mem hd)
    unfold summarizeAt at hS
    split at hS
    · rename_i b hb
      split at hS
      · rename_i σ hσ
        split at hS
        · rename_i x cs hx
          cases hS
          obtain ⟨-, -, ⟨ns, hns⟩, -⟩ := SState.run_mono hσ
          replace hns : σ.nodes = (SState.start f.fn f.label f.pc b).nodes ++ ns := hns
          have hR0 : Rel (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) f
              { SState.start f.fn f.label f.pc b with alloca } f m := by
            rw [hns]; exact Rel.startAt
          have hG : Good (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) σ :=
            ⟨fun d hd => hO d (List.mem_append.2 (Or.inr (List.mem_cons_of_mem _ hd))),
              hO (.mem σ.effs) (List.mem_append.2 (Or.inr (List.Mem.head _))),
              [], (List.append_nil _).symm⟩
          obtain ⟨⟨fe, me, hS, hR, hpc⟩, hL, hSt⟩ := SState.run_ptrs
            (V := Valuation.entry c k m f) (rest := rest) (p0 := f.pc) hb rfl rfl
            (b.stmts.toList.drop f.pc) 0 { SState.start f.fn f.label f.pc b with alloca } σ f m k
            (List.prefix_refl _) rfl rfl hR0 hσ hG
          have hpcn : ¬ fe.pc < b.stmts.size := by
            simp only [List.length_drop, Array.length_toList] at hpc
            omega
          obtain ⟨r, hr1, hr2⟩ := hex (k := k + (b.stmts.toList.drop f.pc).length) hR
            (by rw [hR.fn, hR.label]; exact hb) hpcn hx
            (fun d hd => hO d (List.mem_append.2 (Or.inl hd)))
          refine ⟨⟨fe, me, hS, hR.fn, hR.label, hR.allocas, hR.dest, hR.regs, hR.prods, hR.mem,
            r, hr1, hr2⟩, fun j l pc p hn => ?_, fun l pc v p hm => hSt l pc v p hm⟩
          -- the table's head holds float constant nodes, no `load`
          by_cases hj : (SState.start f.fn f.label f.pc b).nodes.length ≤ j
          · exact hL j l pc p hj hn
          · have hn' : σ.nodes[j]? = some (.load l pc p) := hn
            rw [hns, List.getElem?_append_left (by omega)] at hn'
            obtain ⟨_, _, he⟩ := litNodes_flit (List.mem_of_getElem? hn')
            cases he
        · cases hS
      · cases hS
    · cases hS
  · cases hc

section Exit

/-! The premises of `Block.sound_withAt`: the checker's acceptance (`hc`), the thread at the
block's entry (`hP`, `ht`, `hfn`, `hl`, `hp`), the conditions (`hds`) and the exit function's step
(`hex`), as in `Block.soundAt`. `Block.sound_with` takes the others and the flag-off checker's
acceptance. -/

variable {alloca contract : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ex : SState → Term → Option (Exit × List Cond)} {ds : List Cond} {S : Summary}
    (hc : coversAt alloca P fn lbl p0 ex ds S contract = true) {c : Ctx}
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
        k fe me = .ok r ∧ step c ⟨fe :: rest, k⟩ me = .ok r)
include hc hP ht hfn hl hp hds hex

/-- **Soundness of the block checker with an exit function, with or without `alloca` and
`fmul contract`**: for every flag `alloca` and `contract`, `Block.soundAt` with the
`fmul contract` operands `prodsWith contract` (`EndsAt contract`): without `contract` the summary
has no `fmul contract` node (`summarizeAt_factors`), so `Ends.of_C` at the frame with the
summary's `alloca` blocks. `Block.sound_with` is its case with the flag `alloca` off. For every
program, function, block, position, exit function, conditions, summary, context of the program
and thread at the block's position. -/
theorem Block.sound_withAt :
    EndsAt contract c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) := by
  obtain ⟨hE, hQ⟩ := Block.soundAt hc hP ht hfn hl hp hds hex
  refine ⟨?_, hQ⟩
  cases contract
  · exact Ends.of_C (f := { f with
      allocas := SEff.blocks (Valuation.entry c t.k m f) S.effs ++ f.allocas }) hE
      (summarizeAt_factors (coversAt_summary hc))
  · exact hE

omit hc in
/-- **Soundness of the block checker with an exit function** `ex`, with or without
`fmul contract`: `Block.sound_withAt` with the flag `alloca` off. For every flag `contract`,
program, function, block, entry position, conditions `ds` and summary `S` that `coversWith`
accepts with `ex` and `contract`, every context `c` of the program and thread whose innermost
frame `f` runs `fn` at block `lbl` and position `p0`, with memory `m`: if every condition of `ds`
holds under the entry valuation and, at the block's end, `ex`'s exit is the terminator's step
whenever its obligations hold (`hex`), the block ends with the `fmul contract` operands
`prodsWith contract` (`EndsWith`: `Ends` without the flag, `EndsC` with it) from the entry
valuation, and its pointer facts hold (`Ptrs`). The summary allocates nothing
(`summarizeWith_allocates`), so `EndsAt.ends`. `Block.sound_atWith` and `Block.sound_toWith` are
its instances. -/
theorem Block.sound_with (hc : coversWith P fn lbl p0 ex ds S contract = true) :
    EndsWith contract c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  have h := Block.sound_withAt hc hP ht hfn hl hp hds hex
  ⟨h.1.ends (summarizeWith_allocates (coversAt_summary hc)), h.2⟩

end Exit

/-- **Soundness of the block checker at the block's terminator, with or without
`fmul contract`**: for every flag `contract`, program, function, block, entry position,
conditions and summary that `coversWith` accepts with `SState.exitAt` and `contract`, every
context of the program and thread at the block's position whose conditions hold at the entry
valuation of its innermost frame, the block ends (`EndsWith contract`) and its pointer facts hold
(`Ptrs`) (`Block.sound_with`, `SState.exitAt_sound`). `Block.sound_ptrs` and
`Block.soundC` are its instances. -/
theorem Block.sound_atWith {contract : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ds : List Cond} {S : Summary}
    (hc : coversWith P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) ds S contract = true) {c : Ctx}
    (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    EndsWith contract c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_with (ex := fun σ tm => σ.exitAt fn lbl tm) (hc := hc) hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs

/-- **Soundness of the block checker with `alloca`s, at the block's terminator**: for every flag
`alloca`, program, function, block, entry position, conditions and summary that `coversAt alloca`
accepts with `SState.exitAt` (without `fmul contract`), every context of the program and thread
at the block's position whose conditions hold at the entry valuation of its innermost frame, the
block ends with the summary's `alloca` blocks in front of the frame's (`EndsAt`) and its pointer
facts hold (`Ptrs`) (`Block.soundAt`, `SState.exitAt_sound`). -/
theorem Block.sound_alloca {alloca : Bool} {P : Program} {fn : Func} {lbl p0 : Nat}
    {ds : List Cond} {S : Summary}
    (hc : coversAt alloca P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) ds S = true) {c : Ctx}
    (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    EndsAt true c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.soundAt (ex := fun σ tm => σ.exitAt fn lbl tm) hc hP ht hfn hl hp hds
    fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs

/-- **Soundness of the block checker with its pointer facts**: for every program, function,
block, entry position, conditions and summary that `covers` accepts, every context of the
program and thread at the block's position whose conditions hold at the entry valuation of its
innermost frame, the block ends (`Ends`) and its pointer facts hold (`Ptrs`: at each `load` node
and `store` effect, the statement's pointer operand in the thread's scope at that step is the
summary term's pointer value) (`Block.sound_atWith` without `fmul contract`). -/
theorem Block.sound_ptrs {P : Program} {fn : Func} {lbl p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : covers P fn lbl p0 ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
      Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S) :=
  Block.sound_atWith (contract := false) hc hP ht hfn hl hp hds

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
terminator's step there is the summary exit's (`Block.sound_atWith` with `fmul contract`). One
thread; the obligations are premises. -/
theorem Block.soundC {P : Program} {fn : Func} {lbl p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : coversC P fn lbl p0 ds S = true) {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem}
    {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ ds, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    EndsC c t m f rest (Valuation.entry c t.k m f, lbl, S) :=
  (Block.sound_atWith (contract := true) hc hP ht hfn hl hp hds).1

end MojoProof.Sym
