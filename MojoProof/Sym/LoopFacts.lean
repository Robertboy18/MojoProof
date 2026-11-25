import MojoProof.Sym.Inv
import MojoProof.Sym.Payload

/-!
# Facts at a loop's heads: the registers and blocks rounds keep, and their step counts

For every program and every loop `L` (`LoopSeg`; the rounds of its loop path
`Valuation.roundWith c L.h L.H L.B`, with or without `fmul contract`, which are the loop's rounds
when it has no nested loop), three facts at the heads of its rounds, each a check on the
summaries that the kernel evaluates and its soundness:

* Registers: `LoopSeg.kept F L` lists the registers the loop path and the path out read
  (`Summary.reads`) that no `phi` of function `F` and no block of the loop path sets
  (`Func.keeps`); `LoopSeg.kept_round`: each keeps its value after any number of rounds
  (`Valuation.iterate_regs_keep`).
* Memory: `LoopSeg.loadsFrom F L rs` checks that the loop path keeps the registers `rs` and that
  its blocks' effects are loads through pointers with their base in `rs` (`Summary.loadsIn`,
  `SVal.baseIn`); `Valuation.iterate_loads`: every property of memories that logging a plain read
  (not an `atomicrmw`'s) of a block of a set `Q` keeps holds after any number of rounds when the
  values of `rs` name only blocks of `Q`. Its instances: `Valuation.iterate_blocks` (the blocks
  and the next block number, so `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` by
  `Mem.Buffer.of_block`, `Mem.Fits.of_block` and `Mem.Holds.of_block`), `Valuation.iterate_elem`
  (`Elem` at an output block `o` that the values of `rs` do not name) and
  `Valuation.iterate_only` (`Elem.Only` at `o`).
* Step counts: `pathOff S ps i`, the steps from a path's entry to the entry of its block `i`, and
  `Valuation.lastWith_off`, its soundness; `LoopSeg.stepAt`, the step count at the entry of block
  `i` of round `j` after an entry path, and `LoopSeg.stepAt_k`, its soundness (the statement at
  offset `n` of that block has step `LoopSeg.stepAt … + n`); `LoopSeg.steps_k`, the step counts
  of an entry path, of rounds and of the loop path's last block from their lengths.

Tests: MojoProofTest/LoopFacts.lean (the naive matrix product's loop `naiveL`: the registers it
keeps, its loads through `A` and `B`, the memory facts at the output block, and the steps of its
`fmul` and `fadd` in round `j`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-! ## The registers rounds keep -/

/-- The register operand `x` reads: `[r]` for register `r`, none for a constant or a node. -/
def SVal.reads : SVal → List Nat
  | .reg r => [r]
  | .int .. | .node _ => []

/-- The registers effect `e`'s operands read (`SVal.reads`), an `alloca`'s count included. -/
def SEff.reads : SEff → List Nat
  | .load _ _ p => p.reads
  | .store _ _ v p => v.reads ++ p.reads
  | .alloca _ _ _ c => c.elim [] SVal.reads

/-- The registers node `n`'s operands read (`SVal.reads`), the `fmul contract` operand terms of
an `fbinP` and the effects a `loadAfter` or another node after an `alloca` carries (`SEff.reads`)
included. -/
def SNode.reads : SNode → List Nat
  | .bin _ _ _ a b | .icmp _ _ a b | .gep _ _ a b | .fbin _ _ _ _ a b | .minmax _ _ a b =>
    a.reads ++ b.reads
  | .cast _ _ a | .extract _ a | .load _ _ a | .castAt _ _ _ a => a.reads
  | .select _ c a b => c.reads ++ a.reads ++ b.reads
  | .fbinP _ _ _ _ a b pa pb => a.reads ++ b.reads ++
    pa.elim [] (fun p => p.1.reads ++ p.2.reads) ++ pb.elim [] (fun p => p.1.reads ++ p.2.reads)
  | .call .. | .flit .. | .globalAt .. | .constAt .. | .fresh .. => []
  | .insert _ a b | .eltAt _ _ a b => a.reads ++ b.reads
  | .insEltAt _ _ a e i => a.reads ++ e.reads ++ i.reads
  | .loadAfter _ _ p es => p.reads ++ es.flatMap SEff.reads
  | .gepN _ _ a is => a.reads ++ is.flatMap SVal.reads
  | .icmpAfter _ _ a b es | .gepAfter _ _ a b es => a.reads ++ b.reads ++ es.flatMap SEff.reads
  | .castAfter _ _ _ a es => a.reads ++ es.flatMap SEff.reads
  | .gepNAfter _ _ a is es => a.reads ++ is.flatMap SVal.reads ++ es.flatMap SEff.reads

/-- The registers obligation `d`'s operands read (`SVal.reads`). -/
def Cond.reads : Cond → List Nat
  | .ok x | .bool x => x.reads
  | .mem es => es.flatMap SEff.reads

/-- The registers exit `x`'s condition reads (`SVal.reads`). -/
def Exit.reads : Exit → List Nat
  | .cond c _ _ | .phi c _ _ => c.reads
  | .br _ | .ret => []

/-- The registers summary `S` reads: those its nodes, register updates, effects, obligations and
exit read, in that order, with repeats. -/
def Summary.reads (S : Summary) : List Nat :=
  S.nodes.flatMap SNode.reads ++ S.regs.flatMap (·.2.reads) ++ S.effs.flatMap SEff.reads ++
    S.obls.flatMap Cond.reads ++ S.exit.reads

/-- Whether summaries `Ss` of function `F` keep register `r`: no `phi` of `F` sets it
(`Func.phiSets`) and no summary of `Ss` sets it (`Summary.regs`), the premises of
`Valuation.iterate_regs_keep`. A `Bool`, evaluated by the kernel. -/
def Func.keeps (F : Func) (Ss : List Summary) (r : Nat) : Bool :=
  !Func.phiSets F r && Ss.all fun S => (S.regs.lookup r).isNone

/-- The registers loop `L` of function `F` reads in its loop path and its path out
(`Summary.reads` of `L.H`, `L.B` and `L.X`) that its loop path `L.H :: L.B` keeps
(`Func.keeps`), each once, in the order of their first read. -/
def LoopSeg.kept (F : Func) (L : LoopSeg) : List Nat :=
  ((L.H :: (L.B ++ L.X).map (·.2.2)).flatMap Summary.reads).eraseDups.filter
    (Func.keeps F (L.H :: L.B.map (·.2.2)))

/-- **The registers a loop keeps**: for every flag `c`, function `F`, loop `L`, register `r` that
`L.kept F` lists, valuation `V` of `F` with value `v` at `r` and count `i`: `r` is `v` after `i`
rounds of the loop path (`Valuation.roundWith c L.h L.H L.B`, `Valuation.iterate_regs_keep`). For
every program and every loop (with nested loops, its loop path alone). -/
theorem LoopSeg.kept_round {c : Bool} {F : Func} {L : LoopSeg} {r : Nat} (hr : r ∈ L.kept F)
    {V : Valuation} {v : Val} (hF : V.fn = F) (hv : V.regs r = some v) (i : Nat) :
    ((Valuation.roundWith c L.h L.H L.B)^[i] V).regs r = some v := by
  have hk := (List.mem_filter.1 hr).2
  simp only [Func.keeps, Bool.and_eq_true, Bool.not_eq_true'] at hk
  exact Valuation.iterate_regs_keep hF hk.1 hk.2 hv i

/-! ## The memory of rounds that only read -/

/-- Whether summary `S`'s effects are all loads through pointers with their base in registers
`rs` (`SVal.baseIn` on `S`'s nodes): a summary with no store and no `alloca`. -/
def Summary.loadsIn (rs : List Nat) (S : Summary) : Bool :=
  S.effs.all fun
    | .load _ _ p => p.baseIn S.nodes rs
    | .store .. | .alloca .. => false

/-- Whether the loop path `L.H :: L.B` of loop `L` of function `F` reads memory only through
registers `rs` that it keeps: it keeps each register of `rs` (`Func.keeps`), and each block's
effects are loads with their pointer's base in `rs` (`Summary.loadsIn`). A `Bool`, evaluated by
the kernel. -/
def LoopSeg.loadsFrom (F : Func) (L : LoopSeg) (rs : List Nat) : Bool :=
  rs.all (Func.keeps F (L.H :: L.B.map (·.2.2))) &&
    (L.H :: L.B.map (·.2.2)).all (Summary.loadsIn rs)

/-- **Rounds that only read keep the properties reads keep**: for every flag `c`, function `F`,
loop `L` and registers `rs` that its loop path keeps and reads memory through only
(`LoopSeg.loadsFrom`), set of blocks `Q`, property `P` of memories that logging a
read that is not an `atomicrmw`'s (`a.write = false`, `a.atomic = none`) of a block of `Q` keeps,
valuation `V` of `F` whose registers `rs` have values naming only blocks of `Q`, with `P` at its
memory, and count `i`: `P` holds at the memory after `i` rounds. Each load's pointer has its
base in `rs` (`SVal.eval_baseIn`), so it reads a block of `Q`; the registers keep their values
(`Valuation.iterate_regs_keep`), and an edge keeps the memory. For every program and every loop
(with nested loops, its loop path alone). -/
theorem Valuation.iterate_loads {c : Bool} {F : Func} {L : LoopSeg} {rs : List Nat}
    {Q : Nat → Prop} {P : Mem → Prop} (hL : L.loadsFrom F rs = true)
    (hP : ∀ m (a : Access), P m → a.write = false → a.atomic = none → Q a.ptr.block →
      P (m.log (.access a)))
    {V : Valuation} (hF : V.fn = F) (hr : ∀ r ∈ rs, ∃ v, V.regs r = some v ∧ v.NamesIn Q)
    (hm : P V.mem) (i : Nat) : P ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem := by
  simp only [LoopSeg.loadsFrom, Bool.and_eq_true, List.all_eq_true] at hL
  obtain ⟨hk, hl⟩ := hL
  have hk' : ∀ r ∈ rs, Func.phiSets F r = false ∧
      (L.H :: L.B.map (·.2.2)).all (fun S => (S.regs.lookup r).isNone) = true := by
    intro r hr
    have := hk r hr
    simp only [Func.keeps, Bool.and_eq_true, Bool.not_eq_true'] at this
    exact this
  -- a block keeps `P`
  have blk : ∀ (W : Valuation) (T : Summary), T.loadsIn rs = true →
      (∀ r ∈ rs, ∃ v, W.regs r = some v ∧ v.NamesIn Q) → P W.mem →
      P (W.afterWith c T).mem := by
    intro W T hT hW hWm
    have hr' : ∀ r ∈ rs, ∀ v, W.regs r = some v → v.NamesIn Q := by
      intro r hr v hv
      obtain ⟨v', hv', hq⟩ := hW r hr
      rw [hv] at hv'
      cases hv'
      exact hq
    simp only [Summary.loadsIn, List.all_eq_true] at hT
    have run : ∀ (es : List SEff), (∀ e ∈ es, e ∈ T.effs) → ∀ m0 m, P m0 →
        es.foldlM (SEff.apply W (vals W T.nodes)) m0 = .ok m → P m := by
      intro es
      induction es with
      | nil =>
        intro _ m0 m h0 he
        simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at he
        subst he
        exact h0
      | cons e es ih =>
        intro hes m0 m h0 he
        rw [List.foldlM_cons] at he
        obtain ⟨m1, h1, h2⟩ := Except.bind_eq_ok.1 he
        refine ih (fun e' he' => hes e' (List.mem_cons_of_mem _ he')) m1 m ?_ h2
        have he' := hT e (hes e (by simp))
        cases e with
        | store | alloca => simp at he'
        | load lbl pc p =>
          rw [SEff.apply] at h1
          split at h1
          · obtain ⟨x, hx, h1⟩ := Except.bind_eq_ok.1 h1
            obtain ⟨q, hq, h1⟩ := Except.bind_eq_ok.1 h1
            simp only [pure, Except.pure, Except.ok.injEq] at h1
            subst h1
            have hxq : x = .ptr q := by
              revert hq
              cases x <;> simp [Val.addr?, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]
            subst hxq
            exact hP _ _ h0 rfl rfl (SVal.eval_baseIn hr' he' hx)
          · simp [throw, throwThe, MonadExceptOf.throw] at h1
    show P ((SEff.run W (vals W T.nodes) T.effs).toOption.getD W.mem)
    cases hrun : SEff.run W (vals W T.nodes) T.effs with
    | error => exact hWm
    | ok m => exact run T.effs (fun _ h => h) W.mem m hWm hrun
  -- a block and its edge keep `P`, the function and the values of `rs`
  have step : ∀ (W : Valuation) (l : Nat) (T : Summary), W.fn = F → T ∈ L.H :: L.B.map (·.2.2) →
      (∀ r ∈ rs, ∃ v, W.regs r = some v ∧ v.NamesIn Q) → P W.mem →
      (W.intoWith c l T).fn = F ∧ (∀ r ∈ rs, ∃ v, (W.intoWith c l T).regs r = some v ∧
        v.NamesIn Q) ∧ P (W.intoWith c l T).mem := by
    intro W l T hW hT hWr hWm
    refine ⟨(Valuation.intoWith_k c W l T).2.1.trans hW, fun r hr => ?_, ?_⟩
    · obtain ⟨v, hv, hq⟩ := hWr r hr
      have hT' : (T :: ([] : List (Nat × List Cond × Summary)).map (·.2.2)).all
          (fun S => (S.regs.lookup r).isNone) = true := by
        simp only [List.map_nil, List.all_cons, List.all_nil, Bool.and_true]
        exact List.all_eq_true.1 (hk' r hr).2 T hT
      exact ⟨v, Valuation.iterate_regs_keep (c := c) (h := l) hW (hk' r hr).1 hT' hv 1, hq⟩
    · have he : (W.intoWith c l T).mem = (W.afterWith c T).mem := by
        unfold Valuation.intoWith
        split
        · split <;> rfl
        · rfl
      rw [he]
      exact blk W T (hl T hT) hWr hWm
  -- one round
  have round : ∀ (B' : List (Nat × List Cond × Summary)) (l : Nat) (T : Summary) (W : Valuation),
      W.fn = F → (∀ U ∈ T :: B'.map (·.2.2), U ∈ L.H :: L.B.map (·.2.2)) →
      (∀ r ∈ rs, ∃ v, W.regs r = some v ∧ v.NamesIn Q) → P W.mem →
      P (W.roundWith c l T B').mem := by
    intro B'
    induction B' with
    | nil =>
      intro l T W hW hs hWr hWm
      exact (step W l T hW (hs T (by simp)) hWr hWm).2.2
    | cons p B' ih =>
      intro l T W hW hs hWr hWm
      obtain ⟨l', ds, T'⟩ := p
      obtain ⟨e1, e2, e3⟩ := step W l T hW (hs T (by simp)) hWr hWm
      exact ih l' T' (W.intoWith c l T) e1 (fun U hU => hs U (List.mem_cons_of_mem _ hU)) e2 e3
  suffices H : ∀ (i : Nat) (V : Valuation), V.fn = F →
      (∀ r ∈ rs, ∃ v, V.regs r = some v ∧ v.NamesIn Q) → P V.mem →
      P ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem from H i V hF hr hm
  intro i
  induction i with
  | zero => exact fun _ _ _ hm => hm
  | succ i ih =>
    intro V hF hr hm
    rw [Function.iterate_succ_apply]
    refine ih _ ((Valuation.roundWith_k c L.h L.H L.B 1 V).2.1.trans hF) (fun r hr' => ?_)
      (round L.B L.h L.H V hF (fun U hU => hU) hr hm)
    obtain ⟨v, hv, hq⟩ := hr r hr'
    exact ⟨v, Valuation.iterate_regs_keep hF (hk' r hr').1 (hk' r hr').2 hv 1, hq⟩

/-- **Rounds that only read keep the blocks**: for every flag, function, loop and registers its
loop path keeps and reads memory through only (`LoopSeg.loadsFrom`), valuation `V` of
the function with values at those registers and count `i`, the memory after `i` rounds has
`V`'s blocks and next block number (`Valuation.iterate_loads`), so the premise of
`Mem.Buffer.of_block`, `Mem.Fits.of_block` and `Mem.Holds.of_block` (`Mem.blocks_keep`). For
every program and every loop (with nested loops, its loop path alone). -/
theorem Valuation.iterate_blocks {c : Bool} {F : Func} {L : LoopSeg} {rs : List Nat}
    (hL : L.loadsFrom F rs = true) {V : Valuation} (hF : V.fn = F)
    (hr : ∀ r ∈ rs, (V.regs r).isSome) (i : Nat) :
    ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem.blocks = V.mem.blocks ∧
      ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem.next = V.mem.next :=
  Valuation.iterate_loads (Q := fun _ => True)
    (P := fun m => m.blocks = V.mem.blocks ∧ m.next = V.mem.next) hL (fun _ _ h _ _ _ => h) hF
    (fun r hr' => by
      obtain ⟨v, hv⟩ := Option.isSome_iff_exists.1 (hr r hr')
      exact ⟨v, hv, Val.NamesIn.mono (fun _ _ => trivial) (Val.namesIn_bound v)⟩)
    ⟨rfl, rfl⟩ i

/-- **Rounds that only read keep `Elem`** at an output block `out` that the values of the
registers they read through do not name: for every flag, function, loop, registers its loop
path keeps and reads memory through only (`LoopSeg.loadsFrom`), memory `m₀`, cell width, cells,
bytes, count of threads `n`, valuation `V` of the function and count `i`
(`Valuation.iterate_loads`, `Elem.log_read`). For every program and every loop (with nested
loops, its loop path alone). -/
theorem Valuation.iterate_elem {c : Bool} {F : Func} {L : LoopSeg} {rs : List Nat}
    (hL : L.loadsFrom F rs = true) {m₀ : Mem} {out w : Nat}
    {cell : Nat → Nat} {bs : Nat → Option (List MemByte)} {n : Nat} {V : Valuation}
    (hF : V.fn = F) (hr : ∀ r ∈ rs, ∃ v, V.regs r = some v ∧ v.NamesIn (· ≠ out))
    (hm : Elem m₀ out w cell bs n V.mem) (i : Nat) :
    Elem m₀ out w cell bs n ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem :=
  Valuation.iterate_loads (Q := (· ≠ out)) (P := Elem m₀ out w cell bs n) hL
    (fun _ _ hm hw hx hq => hm.log_read hq hw hx) hF hr hm i

/-- **Rounds that only read keep `Elem.Only`** at an output block `out` that the values of the
registers they read through do not name: for every flag, function, loop, registers its loop
path keeps and reads memory through only (`LoopSeg.loadsFrom`), set of threads `T`,
valuation `V` of the function and count `i` (`Valuation.iterate_loads`,
`Elem.Only.log_other`). For every program and every loop (with nested loops, its loop path
alone). -/
theorem Valuation.iterate_only {c : Bool} {F : Func} {L : LoopSeg} {rs : List Nat}
    (hL : L.loadsFrom F rs = true) {out : Nat} {T : Nat → Prop}
    {V : Valuation} (hF : V.fn = F) (hr : ∀ r ∈ rs, ∃ v, V.regs r = some v ∧ v.NamesIn (· ≠ out))
    (hm : Elem.Only out T V.mem) (i : Nat) :
    Elem.Only out T ((Valuation.roundWith c L.h L.H L.B)^[i] V).mem :=
  Valuation.iterate_loads (Q := (· ≠ out)) (P := Elem.Only out T) hL
    (fun _ _ hm _ _ hq => hm.log_other hq) hF hr hm i

/-! ## Step counts -/

/-- The steps from the entry of the path `S :: ps` to the entry of its block `i` (block 0 is
`S`'s): each block before it adds its statements and its branch (`Summary.len + 1`). Past the
path's last block, the last block's. -/
def pathOff (S : Summary) : List (Nat × List Cond × Summary) → Nat → Nat
  | _, 0 => 0
  | [], _ + 1 => 0
  | (_, _, S') :: ps, i + 1 => S.len + 1 + pathOff S' ps i

/-- **The step count at a block of a path**: for every flag, valuation `V`, label, summary `S`,
path `ps` and number `i`, the entry valuation of block `i` of the path `S :: ps` (the last block
of its first `i + 1`, `Valuation.lastWith` on `ps.take i`) keeps the context and the function,
and its step count is `V`'s plus `pathOff S ps i` (`Valuation.intoWith_k`). For every program and
every path. -/
theorem Valuation.lastWith_off (contract : Bool) :
    ∀ (V : Valuation) (l : Nat) (S : Summary) (ps : List (Nat × List Cond × Summary)) (i : Nat),
      (V.lastWith contract l S (ps.take i)).1.ctx = V.ctx ∧
        (V.lastWith contract l S (ps.take i)).1.fn = V.fn ∧
        (V.lastWith contract l S (ps.take i)).1.k = V.k + pathOff S ps i
  | _, _, _, _, 0 => by simp [pathOff, Valuation.lastWith]
  | _, _, _, [], _ + 1 => by simp [pathOff, Valuation.lastWith]
  | V, l, S, (l', ds, S') :: ps, i + 1 => by
    obtain ⟨h1, h2, h3⟩ :=
      Valuation.lastWith_off contract (V.intoWith contract l S) l' S' ps i
    obtain ⟨e1, e2, e3⟩ := Valuation.intoWith_k contract V l S
    refine ⟨h1.trans e1, h2.trans e2, ?_⟩
    show ((V.intoWith contract l S).lastWith contract l' S' (ps.take i)).1.k = _
    rw [h3, e3, pathOff]
    omega

/-- The step count at the entry of block `i` (block 0 is the header's) of round `j` of loop `L`
after the entry path `S :: E` from step count `k`: `k`, the entry path's steps and its branch
into the header (`pathLen S E + 1`), `j` rounds of `pathLen L.H L.B + 1` steps, and the steps to
block `i` (`pathOff`). The statement at offset `n` of that block's summary has step
`L.stepAt S E k j i + n`. -/
def LoopSeg.stepAt (L : LoopSeg) (S : Summary) (E : List (Nat × List Cond × Summary))
    (k j i : Nat) : Nat :=
  k + (pathLen S E + 1) + j * (pathLen L.H L.B + 1) + pathOff L.H L.B i

/-- **The step count at a block of a round**: for every flag `c`, entry path `(l, S) :: E`,
loop `L`, valuation `V` at the entry path's entry and numbers `j`, `i`, the entry valuation of
block `i` of round `j` (`Valuation.lastWith` on `L.B.take i` after `j` rounds
`Valuation.roundWith c L.h L.H L.B` after the entry path) keeps `V`'s context and function and has
step count `L.stepAt S E V.k j i` (`Valuation.roundWith_k`, `Valuation.lastWith_off`). For every
program, every entry path and every loop path. -/
theorem LoopSeg.stepAt_k (c : Bool) (l : Nat) (S : Summary) (E : List (Nat × List Cond × Summary))
    (L : LoopSeg) (V : Valuation) (j i : Nat) :
    (((Valuation.roundWith c L.h L.H L.B)^[j] (Valuation.roundWith c l S E V)).lastWith c L.h L.H
        (L.B.take i)).1.ctx = V.ctx ∧
      (((Valuation.roundWith c L.h L.H L.B)^[j] (Valuation.roundWith c l S E V)).lastWith c L.h
        L.H (L.B.take i)).1.fn = V.fn ∧
      (((Valuation.roundWith c L.h L.H L.B)^[j] (Valuation.roundWith c l S E V)).lastWith c L.h
        L.H (L.B.take i)).1.k = L.stepAt S E V.k j i := by
  obtain ⟨h1, h2, h3⟩ := Valuation.roundWith_k c l S E 1 V
  obtain ⟨r1, r2, r3⟩ := Valuation.roundWith_k c L.h L.H L.B j (Valuation.roundWith c l S E V)
  obtain ⟨o1, o2, o3⟩ := Valuation.lastWith_off c
    ((Valuation.roundWith c L.h L.H L.B)^[j] (Valuation.roundWith c l S E V)) L.h L.H L.B i
  have hk : (Valuation.roundWith c l S E V).k = V.k + (pathLen S E + 1) := by simpa using h3
  refine ⟨o1.trans (r1.trans h1), o2.trans (r2.trans h2), ?_⟩
  rw [o3, r3, hk]
  rfl

/-- **The step counts of an entry path, of rounds and of a loop path's last block**, from their
lengths: for every flag `c`, entry path `(l, S) :: E`, loop `L`, numbers `a`, `b`, `d` that are
the entry path's steps and branch into the header, a round's steps and the steps from the
header to the loop path's last block (`pathLen`, `pathOff`), valuations `V`, `W` and count `j`:
the entry path from `V` and `j` rounds from `W` keep the context and the function and add `a` and
`b * j` steps, and the loop path's last block is entered `d` steps after `W`
(`Valuation.roundWith_k`, `Valuation.lastWith_off`). For every program, every entry path and every
loop path; `a`, `b` and `d` are closed by the kernel at an instance. -/
theorem LoopSeg.steps_k (c : Bool) (l : Nat) (S : Summary) (E : List (Nat × List Cond × Summary))
    (L : LoopSeg) {a b d : Nat} (ha : pathLen S E + 1 = a) (hb : pathLen L.H L.B + 1 = b)
    (hd : pathOff L.H L.B L.B.length = d) (V W : Valuation) (j : Nat) :
    (Valuation.roundWith c l S E V).ctx = V.ctx ∧ (Valuation.roundWith c l S E V).fn = V.fn ∧
      (Valuation.roundWith c l S E V).k = V.k + a ∧
      ((Valuation.roundWith c L.h L.H L.B)^[j] W).ctx = W.ctx ∧
      ((Valuation.roundWith c L.h L.H L.B)^[j] W).fn = W.fn ∧
      ((Valuation.roundWith c L.h L.H L.B)^[j] W).k = W.k + b * j ∧
      (W.lastWith c L.h L.H L.B).1.ctx = W.ctx ∧ (W.lastWith c L.h L.H L.B).1.k = W.k + d := by
  obtain ⟨h1, h2, h3⟩ := Valuation.roundWith_k c l S E 1 V
  obtain ⟨r1, r2, r3⟩ := Valuation.roundWith_k c L.h L.H L.B j W
  obtain ⟨o1, -, o3⟩ := Valuation.lastWith_off c W L.h L.H L.B L.B.length
  rw [List.take_of_length_le (Nat.le_refl _)] at o1 o3
  refine ⟨h1, h2, ?_, r1, r2, ?_, o1, ?_⟩
  · rw [← ha]
    simpa using h3
  · rw [r3, ← hb, Nat.mul_comm]
  · rw [o3, hd]

end MojoProof.Sym
