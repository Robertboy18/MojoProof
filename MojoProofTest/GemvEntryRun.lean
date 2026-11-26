import MojoProofTest.SymGemvTail
import MojoProof.Sym.Slot
import MojoProof.Sym.WaitVia

/-!
# gemv_kernel's entry block `%6` at a free thread

`entry`: the run of `%6` from pc 0 to statement 41 at every valid launch, thread, context and
memory with the start frame's facts as premises and the two deliveries of `%24` and `%25` as
premises, continued at the frame, step and memory where `MojoProofTest.GemvLoop.run` starts. Its
two waits are `Piece.Wait.via`'s, with the shuffles' argument values (the halves of the row word
from the special registers) and memories (`slots`: the memory after the three `alloca`s; then
the first delivery's), and the continuation gets the frame's `alloca` blocks and the step. The
proof runs `%6`'s pieces (`gemv_segs_alloca`'s summary: two collective segments and nine
lifetime markers, `sym_pieces gp`) one at a time by `RunsVia.of_coll` and `RunsVia.of_life`, each
piece's obligations from its nodes' values (MojoProof/Sym/OblPieces.lean for the loads through
the stored `[2 x ptr]`, the `i32` slots and the vector), and the three `alloca` blocks through
`EntryInv` (the slots of MojoProof/Sym/Slot.lean).

In a warp, other lanes run between a lane's steps: `slotsAll` is the memory after lanes'
`alloca`s, which changes only their `alloca` numbers (`slotsAll_off`), and `EntryInv.frame`
keeps a lane's slots through every change outside its three blocks.
-/

namespace MojoProof.Sym
open MojoProof.LLVM MojoProof.Sem
section SymPieces
open Lean Elab Command Meta

deriving instance ToExpr for SState
deriving instance DecidableEq for SState
deriving instance DecidableEq for Piece

run_cmd do
  Lean.addDocStringCore `MojoProof.Sym.instToExprSState_mojoProofTest
    "A symbolic state as an expression, for `sym_pieces`' definitions."
  Lean.addDocStringCore `MojoProof.Sym.instDecidableEqSState_mojoProofTest
    "Symbolic states' equality, for `sym_pieces` to share a repeated state's definition."
  Lean.addDocStringCore `MojoProof.Sym.instDecidableEqPiece_mojoProofTest
    "Pieces' equality, derived for `sym_pieces`."

/-- `sym_pieces gp := P F lbl pc stops alloc` defines `gp_0`, `gp_1`, … for the pieces that
`summarizePieces P F lbl pc stops alloc` computes, with `gp_pieces` their list and `gp_tail` the
summary after the last piece. -/
syntax (name := symPieces) (docComment)? "sym_pieces " ident " := " term:max term:max term:max
  term:max term:max term:max : command

/-- The elaborator of `sym_pieces`: it evaluates `summarizePieces` and adds one definition per
piece. -/
@[command_elab symPieces] unsafe def elabSymPieces : CommandElab := fun stx => do
  let ns ← getCurrNamespace
  let base := stx[2].getId
  liftTermElabM do
    let P ← Term.elabTermEnsuringType stx[4] (mkConst ``MojoProof.LLVM.Program)
    let fn ← Term.elabTermEnsuringType stx[5] (mkConst ``MojoProof.LLVM.Func)
    let lbl ← Term.elabTermEnsuringType stx[6] (mkConst ``Nat)
    let p0 ← Term.elabTermEnsuringType stx[7] (mkConst ``Nat)
    let ps ← Term.elabTermEnsuringType stx[8] (mkApp (mkConst ``List [.zero]) (mkConst ``Nat))
    let al ← Term.elabTermEnsuringType stx[9] (mkConst ``Bool)
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars (mkAppN (mkConst ``summarizePieces) #[P, fn, lbl, p0, ps, al])
    let ty := mkApp (mkConst ``Option [.zero]) (mkApp2 (mkConst ``Prod [.zero, .zero])
      (mkApp (mkConst ``List [.zero]) (mkConst ``Piece)) (mkConst ``Summary))
    match ← evalExpr (Option (List Piece × Summary)) ty e with
    | none => throwError "sym_pieces: outside the checker's fragment"
    | some (Ss, L) =>
      let mut items : Array Expr := #[]
      let mut seen : Array (SState × Name) := #[]
      for (S, i) in Ss.zipIdx do
        let name := ns ++ Name.mkSimple s!"{base}_{i}"
        match S with
        | .coll S =>
          addAndCompile <| .defnDecl
            { name, levelParams := [], type := mkConst ``SegSummary, value := toExpr S,
              hints := .abbrev, safety := .safe }
          addDocStringCore name s!"Piece {i} of `{base}`: a straight run's summary."
          enableRealizationsForConst name
          items := items.push (mkApp (mkConst ``Piece.coll) (mkConst name))
        | .life σ s x n =>
          match seen.find? (·.1 == σ) with
          | some (_, nm) =>
            items := items.push (mkApp4 (mkConst ``Piece.life) (mkConst nm) (toExpr s)
              (toExpr x) (toExpr n))
          | none =>
            addAndCompile <| .defnDecl
              { name, levelParams := [], type := mkConst ``SState, value := toExpr σ,
                hints := .abbrev, safety := .safe }
            addDocStringCore name
              s!"Piece {i} of `{base}`: the state at a lifetime marker, shared by later equal ones."
            enableRealizationsForConst name
            seen := seen.push (σ, name)
            items := items.push (mkApp4 (mkConst ``Piece.life) (mkConst name) (toExpr s)
              (toExpr x) (toExpr n))
      let tl := ns ++ Name.mkSimple s!"{base}_tail"
      addAndCompile <| .defnDecl
        { name := tl, levelParams := [], type := mkConst ``Summary, value := toExpr L,
          hints := .abbrev, safety := .safe }
      addDocStringCore tl s!"The summary after the last piece of `{base}`."
      let pn := ns ++ Name.mkSimple s!"{base}_pieces"
      addAndCompile <| .defnDecl
        { name := pn, levelParams := [], type := mkApp (mkConst ``List [.zero]) (mkConst ``Piece),
          value := ← mkListLit (mkConst ``Piece) items.toList, hints := .abbrev, safety := .safe }
      addDocStringCore pn s!"The pieces of `{base}`, in order."
end SymPieces

/-- **A collective piece as a step of `RunsVia`.** For every context, label, frames below,
continuation, collective piece `S` and pieces after it, deliveries `w`, thread, memory and frame
through to the pieces: if `S`'s obligations hold at the frame's valuation and every run of `S`'s
effects with its arguments meets the wait's predicate `P`, the thread runs with the wait
`(P, w 0)` first, given the run of every frame resumed after the call (`RunsVia.of_wait`). -/
theorem RunsVia.of_coll {c : Ctx} {lbl : Nat} {rest : List Frame}
    {K : Thread → Mem → Frame → Prop} {S : SegSummary} {Ss : List Piece}
    {w : Nat → Option Val × Mem} {d : Option Val × Mem} {t : Thread} {m : Mem} {f : Frame}
    {fn : Func} {p : Nat} {V : Valuation} {P : Thread → Intrinsic → List Val → Mem → Prop}
    {Q : Mem → Prop} {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (h : Piece.ThroughTo c lbl rest K (.coll S :: Ss) w t m f)
    (hV : Valuation.entry c t.k m f = V) (hfn : f.fn = fn) (hp : f.pc = p) (hw : w 0 = d)
    (hds : ∀ x ∈ S.toSummary.obls, x.Holds V (vals V S.toSummary.nodes))
    (hP : ∀ u me xs, u.at = some (fn.name, lbl, p + S.len) →
      SEff.run V (vals V S.nodes) S.effs = .ok me →
      S.args.mapM (·.eval V (vals V S.nodes)) = .ok xs → P u S.call.intr xs me)
    (hn : ∀ fr t', t'.frames = fr :: rest → fr.fn = fn → fr.pc = p + S.len + 1 →
      fr.allocas = SEff.blocks V S.effs ++ f.allocas →
      Piece.ThroughTo c lbl rest K Ss (fun i => w (i + 1)) t' d.2 fr →
      Valuation.entry c t'.k d.2 fr = V.resume S.toSummary (resReg fn lbl (p + S.len)) d →
      RunsVia c Q ws t' d.2) :
    RunsVia c Q ((P, d) :: ws) t m := by
  subst hV hw
  exact RunsVia.of_wait (T := fun t' fr => Piece.ThroughTo c lbl rest K Ss
    (fun i => w (i + 1)) t' (w 0).2 fr) hfn hp (h hds) hP hn

/-- **A lifetime marker as a step of `RunsVia`.** For every context, label, frames below,
continuation, marker piece and pieces after it, deliveries, thread, memory and frame through to
the pieces: if the marker's segment's obligations hold, its pointer operand is `⟨b, o⟩` and every
run of the segment's effects leaves a block the thread owns there, the thread runs given the run
of every frame after the marker on the memory with `b`'s liveness set. -/
theorem RunsVia.of_life {c : Ctx} {lbl : Nat} {rest : List Frame}
    {K : Thread → Mem → Frame → Prop} {σ : SState} {start : Bool} {x : SVal} {n : Nat}
    {Ss : List Piece} {w : Nat → Option Val × Mem} {t : Thread} {m : Mem} {f : Frame}
    {V : Valuation} {b : Nat} {o : Int} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (h : Piece.ThroughTo c lbl rest K (.life σ start x n :: Ss) w t m f)
    (hV : Valuation.entry c t.k m f = V)
    (hds : ∀ d ∈ Cond.ok x :: .mem (σ.toSummary n).effs :: (σ.toSummary n).obls,
      d.Holds V (vals V (σ.toSummary n).nodes))
    (hx : x.eval V (vals V (σ.toSummary n).nodes) = .ok (.ptr ⟨b, o⟩))
    (hn : ∀ me, SEff.run V (vals V (σ.toSummary n).nodes) (σ.toSummary n).effs = .ok me →
      ((me.block ⟨b, o⟩).any fun B => B.owner == .thread c.who.thread) = true ∧
      ∀ fr t', t'.frames = fr :: rest → fr.fn = f.fn → fr.label = lbl →
        fr.pc = f.pc + n + 1 → fr.allocas = SEff.blocks V σ.effs ++ f.allocas →
        Piece.ThroughTo c lbl rest K Ss w t' (me.setLive b start) fr →
        Valuation.entry c t'.k (me.setLive b start) fr =
          V.resume (σ.toSummary n) none (none, me.setLive b start) →
        RunsVia c Q ws t' (me.setLive b start)) :
    RunsVia c Q ws t m := by
  subst hV
  obtain ⟨fe, me, v, hS, hfe, hlb, hpc, hal, -, hrg, hpr, hm, hx', hst⟩ := h hds
  obtain rfl : v = .ptr ⟨b, o⟩ := Except.ok.inj (hx'.symm.trans hx)
  obtain ⟨ho, hn⟩ := hn me hm
  obtain ⟨hs, hT⟩ := hst _ (intrinsic_lifetime_ptr ho)
  exact RunsVia.of_steps (hS.trans_step hs (.refl _ _))
    (hn _ _ rfl hfe hlb (by show fe.pc + 1 = _; rw [hpc]) hal hT
      (Valuation.entry_set (c := c) (k := t.k + n + 1) (m := me.setLive b start)
        (g := (Valuation.entry c t.k m f).frameAtWith true 0 (σ.toSummary n)) hfe hrg hpr none
        none (fe.pc + 1)))

end MojoProof.Sym

namespace MojoProof.Sem
open MojoProof.LLVM

/-- For every layout, memory, array type `[n x t]` and block whose address `g` is below the
pointer range: `getelementptr inbounds` with the indices `i32 0, i32 0` at `⟨b, 0⟩` is `⟨b, 0⟩`. -/
theorem gep_zeros {l : Layout} {m : Mem} {n : Nat} {t : Ty} {b g : Nat}
    (hA : m.addr l 0 ⟨b, 0⟩ = .ok g) (hg : g < 2 ^ (l.ptr 0).1) :
    gep l m { inbounds := true } (.arr n t) 0
      [.bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 0)] (.ptr ⟨b, 0⟩) =
      .ok (.ptr ⟨b, 0⟩) := by
  have hpow : (2 : Int) ^ (l.ptr 0).1 = ((2 ^ (l.ptr 0).1 : Nat) : Int) := by push_cast; rfl
  simp [gep, gepPtr, hA, gepSteps, gepSteps.into, bind, Except.bind, pure, Except.pure, outS]
  rw [hpow]
  exact_mod_cast hg

end MojoProof.Sem

namespace MojoProof.Sym
open MojoProof.LLVM MojoProof.Sem

/-- For every context, memory and frame: a register of the frame's entry valuation is the frame's
register. -/
theorem Frame.regs_of_entry {c : Ctx} {k : Nat} {M : Mem} {fr : Frame} {V : Valuation}
    (h : Valuation.entry c k M fr = V) {r : Nat} {v : Val} (hr : V.regs r = some v) :
    fr.regs r = some v := by
  subst h; exact hr

/-- For every valuation and node list: the obligations `Cond.ok x`, `Cond.mem es` and `os` of a
lifetime marker's segment hold from each one's fact. -/
theorem life_hds {V : Valuation} {vs : List (Except Fault Val)} {x : SVal} {es : List SEff}
    {os : List Cond} (h1 : Cond.Holds V vs (.ok x)) (h2 : Cond.Holds V vs (.mem es))
    (h3 : ∀ d ∈ os, d.Holds V vs) : ∀ d ∈ Cond.ok x :: .mem es :: os, d.Holds V vs := by
  intro d hd
  rcases List.mem_cons.1 hd with rfl | hd
  · exact h1
  rcases List.mem_cons.1 hd with rfl | hd
  · exact h2
  exact h3 d hd

/-- For every program, function, valuation and node list: the effect list of one `store`
statement runs to the memory that `Mem.store` gives at its operands' values. -/
theorem SEff.run_store_ok {V : Valuation} {vs : List (Except Fault Val)} {P : Program}
    {F : Func} {lbl pc : Nat} {v p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty} {pv : Value}
    {a : Nat} {pv' : Value} {al : Option Nat} {md : List (String × Nat)} {x : Val} {q : Ptr}
    {M : Mem} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .store vol (.mk t pv) (.mk (.ptr a) pv') al, md⟩)
    (hv : v.eval V vs = .ok x) (hp : p.eval V vs = .ok (.ptr q))
    (h : V.mem.store P.layout V.ctx.who a t x q (some (al.getD (P.layout.align t))) = .ok M) :
    SEff.run V vs [.store lbl pc v p] = .ok M := by
  subst hP
  refine Eq.trans ?_ h
  simp only [SEff.run, List.foldlM_cons, List.foldlM_nil, bind_pure, SEff.apply,
    Valuation.stmt_of_fn hF hs, hv, hp]
  rfl

/-- For every function, valuation, node list, memory `M`, layout `l` and numbers: an `alloca`
statement's effect, whose count evaluates to `k`, at a program of layout `l`, whose fresh block
`b` has no block in `M`, applies to `M` with block `b` allocated (`Mem.alloc`) in `l`'s `alloca`
space: `z` bytes (`k` times the type's size), alignment `a` (the statement's, else the type's),
liveness `lv` (false when a `lifetime.start` of the result follows), writable, owned by the
thread, at the context's two addresses for the step. -/
theorem SEff.apply_alloca_at {V : Valuation} {vs : List (Except Fault Val)} {M : Mem}
    {F : Func} {lbl pc n : Nat} {cnt : Option SVal} {res : Option Nat} {t : Ty}
    {x : Option TValue} {al : Option Nat} {md : List (String × Nat)} {k : Nat} {l : Layout}
    {z a b : Nat} {lv : Bool} (hF : V.fn = F)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) = some ⟨res, .alloca t x al, md⟩)
    (hc : SEff.count V vs cnt = .ok k) (hl : V.ctx.prog.layout = l) (hz : k * l.size t = z)
    (ha : al.getD (l.align t) = a) (hlv : (!(res.any (lifetimeStarted V.ctx V.fn))) = lv)
    (hb : V.mem.fresh V.ctx.who.thread (V.k + n) = b) (hM : M.blocks b = none) :
    (SEff.alloca lbl pc n cnt).apply V vs M = .ok (M.alloc l l.allocaSpace z a lv false
      (.thread V.ctx.who.thread) (V.ctx.addr (Nat.pair (V.k + n) 0))
      (V.ctx.addr (Nat.pair (V.k + n) 1)) (num := some b)).1 := by
  subst hl hz ha hlv hb
  simp only [SEff.apply, Valuation.stmt_of_fn hF hs, hc, hM, Option.isSome_none,
    Bool.false_eq_true, ite_false]
  rfl

/-- For every function, valuation and node list: the node of an `extractelement` statement
evaluates from its two operands' values. -/
theorem SNode.eval_eltAt_at {V : Valuation} {vs : List (Except Fault Val)} {F : Func}
    {lbl pc : Nat} {a i : SVal} {dst : Option Nat} {t : Ty} {x : Value} {y : TValue}
    {md : List (String × Nat)} {va vi : Val} (hF : V.fn = F)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .extractelement (.mk t x) y, md⟩)
    (ha : a.eval V vs = .ok va) (hi : i.eval V vs = .ok vi) :
    (SNode.eltAt lbl pc a i).eval V vs = extractE t va vi := by
  simp only [SNode.eval, SNode.evalMore, Valuation.stmt_of_fn hF hs, ha, hi]
  rfl

/-- For every valuation and node list: `SNode.insert`'s node is `insertV` of its operands' values
at its indices. -/
theorem SNode.eval_insert {V : Valuation} {vs : List (Except Fault Val)} {is : List Nat}
    {a b : SVal} {va vb : Val} (ha : a.eval V vs = .ok va) (hb : b.eval V vs = .ok vb) :
    (SNode.insert is a b).eval V vs = insertV va vb is := by
  simp only [SNode.eval, SNode.evalMore, ha, hb]
  rfl

/-- For every program, function, valuation and node list: the node of a `getelementptr`
statement evaluates as `gep` of its operands' values. -/
theorem SNode.eval_gepN_at {V : Valuation} {vs : List (Except Fault Val)} {P : Program}
    {F : Func} {lbl pc : Nat} {base : SVal} {idx : List SVal} {dst : Option Nat} {fl : GepFlags}
    {src : Ty} {a : Nat} {pv : Value} {ix : List TValue} {md : List (String × Nat)}
    {is : List Val} {b : Val} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .gep fl src (.mk (.ptr a) pv) ix, md⟩)
    (hi : idx.mapM (·.eval V vs) = .ok is) (hb : base.eval V vs = .ok b) :
    (SNode.gepN lbl pc base idx).eval V vs = MojoProof.Sem.gep P.layout V.mem fl src a is b := by
  subst hP
  simp only [SNode.eval, SNode.evalMore, Valuation.stmt_of_fn hF hs, hi, hb]
  rfl


/-- For every context, memory and frame resumed from `V` after summary `S` with result register
`r`: a register `s ≠ r` that `S` does not set keeps `V`'s value. -/
theorem Frame.regs_keep {c : Ctx} {k : Nat} {M : Mem} {fr : Frame} {V : Valuation} {S : Summary}
    {r : Option Nat} {d : Option Val × Mem} {s : Nat} {v : Val}
    (h : Valuation.entry c k M fr = V.resume S r d) (hne : r ≠ some s)
    (hl : S.regs.lookup s = none) (hv : V.regs s = some v) : fr.regs s = some v := by
  refine (congrFun (congrArg Valuation.regs h) s).trans (Valuation.resume_regs_ne hne ?_)
  show regVal V (vals V S.nodes) S.regs s = some v
  unfold regVal
  rw [hl]
  exact hv

/-- For every context, memory and frame resumed from `V` after summary `S` with result register
`r`: a register `s ≠ r` that `S` sets to `x` has `x`'s value. -/
theorem Frame.regs_set {c : Ctx} {k : Nat} {M : Mem} {fr : Frame} {V : Valuation} {S : Summary}
    {r : Option Nat} {d : Option Val × Mem} {s : Nat} {x : SVal} {v : Val}
    (h : Valuation.entry c k M fr = V.resume S r d) (hne : r ≠ some s)
    (hl : S.regs.lookup s = some x) (hx : x.eval V (vals V S.nodes) = .ok v) :
    fr.regs s = some v := by
  refine (congrFun (congrArg Valuation.regs h) s).trans (Valuation.resume_regs_ne hne ?_)
  show regVal V (vals V S.nodes) S.regs s = some v
  unfold regVal
  rw [hl]
  show (SVal.eval V (vals V S.nodes) x).toOption = some v
  rw [hx]
  rfl

/-- For every context, memory and frame resumed from `V` after summary `S` with result register
`s`: register `s` has the delivery's value. -/
theorem Frame.regs_self {c : Ctx} {k : Nat} {M : Mem} {fr : Frame} {V : Valuation} {S : Summary}
    {s : Nat} {d : Option Val × Mem} {v : Val}
    (h : Valuation.entry c k M fr = V.resume S (some s) d) (hd : d.1 = some v) :
    fr.regs s = some v :=
  (congrFun (congrArg Valuation.regs h) s).trans (Valuation.resume_regs_self hd)

/-- For every context, memory and frame resumed from `V` with no result register after a summary
that sets no register: the frame's registers are `V`'s. -/
theorem Frame.regs_none {c : Ctx} {k : Nat} {M : Mem} {fr : Frame} {V : Valuation} {S : Summary}
    {d : Option Val × Mem} (h : Valuation.entry c k M fr = V.resume S none d)
    (hS : S.regs = []) : fr.regs = V.regs := by
  funext s
  refine (congrFun (congrArg Valuation.regs h) s).trans ?_
  show regVal V (vals V S.nodes) S.regs s = V.regs s
  rw [hS]
  rfl

end MojoProof.Sym

namespace MojoProofTest.GemvEntryRun
open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymSeg MojoProofTest.SymGemvTail

/-- gemv_kernel's `%6` from pc 0 as pieces: two collective segments and nine lifetime markers. -/
sym_pieces gp := gemv.prog gemv.fn_0 6 0 gemvStops true

/-- `summarizePieces` of gemv_kernel's `%6` from pc 0 is `gp_pieces` with `gp_tail`. -/
theorem pieces_eq : summarizePieces gemv.prog gemv.fn_0 6 0 gemvStops true =
    some (gp_pieces, gp_tail) := by decide +kernel

/-- The three `alloca` blocks are slots of thread `who`, and every other block is as in `m₀`. -/
def EntryInv (who b7 b8 b9 : Nat) (m₀ m : Mem) : Prop :=
  m.slot who b7 16 8 = true ∧ m.slot who b8 4 4 = true ∧ m.slot who b9 4 4 = true ∧
    ∀ q, q ≠ b7 → q ≠ b8 → q ≠ b9 → m.blocks q = m₀.blocks q

/-- For every memories: setting the liveness of one of the three blocks keeps `EntryInv`. -/
theorem EntryInv.setLive {who b7 b8 b9 : Nat} {m₀ m : Mem} {b : Nat} (l : Bool)
    (hb : b = b7 ∨ b = b8 ∨ b = b9) (h : EntryInv who b7 b8 b9 m₀ m) :
    EntryInv who b7 b8 b9 m₀ (m.setLive b l) := by
  obtain ⟨h7, h8, h9, hq⟩ := h
  refine ⟨by rw [Mem.slot_setLive]; exact h7, by rw [Mem.slot_setLive]; exact h8,
    by rw [Mem.slot_setLive]; exact h9, fun q q7 q8 q9 => ?_⟩
  have hne : q ≠ b := by
    rcases hb with h | h | h
    · rw [h]; exact q7
    · rw [h]; exact q8
    · rw [h]; exact q9
  rw [Mem.setLive_blocks_ne _ _ hne]
  exact hq q q7 q8 q9

/-- For every layout, memories, thread and value: a store into one of the three blocks that
succeeds keeps `EntryInv`. -/
theorem EntryInv.store {who b7 b8 b9 : Nat} {m₀ m m' : Mem} {l : Layout} {w : Who} {a : Nat}
    {t : Ty} {v : Val} {p : Ptr} {al : Option Nat} {op : Option RmwOp}
    (hs : m.store l w a t v p al op = .ok m') (hb : p.block = b7 ∨ p.block = b8 ∨ p.block = b9)
    (h : EntryInv who b7 b8 b9 m₀ m) : EntryInv who b7 b8 b9 m₀ m' := by
  obtain ⟨h7, h8, h9, hq⟩ := h
  refine ⟨by rw [Mem.slot_store hs]; exact h7, by rw [Mem.slot_store hs]; exact h8,
    by rw [Mem.slot_store hs]; exact h9, fun q q7 q8 q9 => ?_⟩
  have hne : p.block ≠ q := by
    rcases hb with h | h | h
    · rw [h]; exact Ne.symm q7
    · rw [h]; exact Ne.symm q8
    · rw [h]; exact Ne.symm q9
  rw [Mem.store_blocks hs hne]
  exact hq q q7 q8 q9

/-- For every memories: a memory with the same blocks keeps `EntryInv`. -/
theorem EntryInv.of_blocks {who b7 b8 b9 : Nat} {m₀ m m' : Mem} (hb : m'.blocks = m.blocks)
    (h : EntryInv who b7 b8 b9 m₀ m) : EntryInv who b7 b8 b9 m₀ m' := by
  obtain ⟨h7, h8, h9, hq⟩ := h
  refine ⟨(Mem.slot_blocks (congrFun hb _) _ _ _).trans h7,
    (Mem.slot_blocks (congrFun hb _) _ _ _).trans h8,
    (Mem.slot_blocks (congrFun hb _) _ _ _).trans h9, fun q q7 q8 q9 => ?_⟩
  rw [hb]
  exact hq q q7 q8 q9

/-- For every memories: `EntryInv` at `m₀` and `m` says that `m` has `m₀`'s blocks outside the
three (`Mem.SameOff`). -/
theorem EntryInv.off {who b7 b8 b9 : Nat} {m₀ m : Mem} (h : EntryInv who b7 b8 b9 m₀ m) :
    m₀.SameOff (fun q => q = b7 ∨ q = b8 ∨ q = b9) m :=
  fun q hq => h.2.2.2 q (fun e => hq (.inl e)) (fun e => hq (.inr (.inl e)))
    (fun e => hq (.inr (.inr e)))

/-- **Another thread keeps the slots**: for every set `S` of block numbers and memories `m₀`, `m`,
`m'` with `m'` having `m`'s blocks outside `S` (as another thread's `alloca`s, slot stores and
liveness changes leave them, `Mem.SameOff.alloc`, `.store`, `.setLive`) and the three blocks
outside `S`: `EntryInv` at `m₀` and `m` gives `EntryInv` at `m'` and `m'`, the form of `entry`'s
premise `hI`. -/
theorem EntryInv.frame {who b7 b8 b9 : Nat} {S : Nat → Prop} {m₀ m m' : Mem}
    (h : EntryInv who b7 b8 b9 m₀ m) (hS : m.SameOff S m') (h7 : ¬ S b7) (h8 : ¬ S b8)
    (h9 : ¬ S b9) : EntryInv who b7 b8 b9 m' m' :=
  ⟨(hS.slot h7 _ _ _).trans h.1, (hS.slot h8 _ _ _).trans h.2.1, (hS.slot h9 _ _ _).trans h.2.2.1,
    fun _ _ _ _ => rfl⟩

/-- An event of thread `who`'s three slots `b7`, `b8`, `b9`: an access by `who`, not by an
`atomicrmw` and not a load with `!invariant.load`, of one of the three blocks. -/
def SlotEv (who : Who) (b7 b8 b9 : Nat) (e : Event) : Prop :=
  ∃ a, e = .access a ∧ a.who = who ∧ a.atomic = none ∧ a.invariant = false ∧
    (a.ptr.block = b7 ∨ a.ptr.block = b8 ∨ a.ptr.block = b9)

/-- For every property `P` of events and memory `m`: `m` extends its own trace (by no event). -/
theorem ext_refl (P : Event → Prop) (m : Mem) : Ext P m m :=
  ⟨[], rfl, fun _ h => by cases h⟩

/-- For every property `P` of events and memories `m₀`, `m`, `m'`: an extension of `m₀`'s trace
at `m` is one at a memory `m'` with `m`'s trace (as `Mem.setLive_trace` gives). -/
theorem ext_keep {P : Event → Prop} {m₀ m m' : Mem} (h : Ext P m₀ m) (e : m'.trace = m.trace) :
    Ext P m₀ m' :=
  have ⟨E, h₁, h₂⟩ := h
  ⟨E, by rw [e, h₁], h₂⟩

/-- For every thread `who`, block numbers `b7`, `b8`, `b9`, memories, layout, space, type, value,
pointer `p` into one of the three blocks and alignment: a store by `who` at `p` that succeeds
extends a memory's trace by an event of `SlotEv` (`Mem.store_trace`). -/
theorem ext_store {who : Who} {b7 b8 b9 : Nat} {m₀ m m' : Mem} {l : Layout} {a : Nat} {t : Ty}
    {v : Val} {p : Ptr} {al : Option Nat} (h : Ext (SlotEv who b7 b8 b9) m₀ m)
    (hs : m.store l who a t v p al = .ok m') (hb : p.block = b7 ∨ p.block = b8 ∨ p.block = b9) :
    Ext (SlotEv who b7 b8 b9) m₀ m' :=
  have ⟨E, h₁, h₂⟩ := h
  ⟨_ :: E, by rw [Mem.store_trace hs, h₁]; rfl, fun e he =>
    (List.mem_cons.1 he).elim (fun he => ⟨_, he, rfl, rfl, rfl, hb⟩) (h₂ e)⟩

/-- `entry_obls` closes a lifetime marker's obligations from the node facts in context, then by
`mojo_obl`. -/
macro "entry_obls" : tactic => `(tactic| (
  repeat' first | exact forall_mem_nil' _ | refine forall_mem_cons' ?_ ?_
  all_goals first
    | with_reducible exact Cond.holds_ok (SVal.eval_node (by assumption))
    | (guard_target =~ Cond.Holds _ _ (Cond.ok (SVal.reg _))
       exact Cond.holds_ok (SVal.eval_reg (by assumption)))
    | (guard_target =~ Cond.Holds _ _ (Cond.ok (SVal.int _ _)); exact Cond.holds_ok rfl)
    | with_reducible exact Cond.holds_mem ⟨_, by assumption⟩
    | exact Cond.holds_mem ⟨_, rfl⟩
    | (guard_target =~ Cond.Holds _ _ (Cond.mem _); exact Cond.holds_mem ⟨_, by assumption⟩)
    | mojo_obl))

/-- **The memory after `%6`'s three `alloca`s**, for every context `c`, step count `k`, memory `m`
and block numbers `b7`, `b8`, `b9`: `m` with `b7` (16 bytes aligned to 8) and then `b8` and `b9`
(4 bytes aligned to 4) allocated (`Mem.alloc`) at those numbers in space 0, not live (a
`lifetime.start` follows each), writable and owned by thread `c.who.thread`, at the addresses
`c.addr` gives at steps `k`, `k + 1` and `k + 2`. -/
def slots (c : Ctx) (k : Nat) (m : Mem) (b7 b8 b9 : Nat) : Mem :=
  (((m.alloc gemv.prog.layout 0 16 8 false false (.thread c.who.thread) (c.addr (Nat.pair k 0))
    (c.addr (Nat.pair k 1)) (num := some b7)).1.alloc gemv.prog.layout 0 4 4 false false
    (.thread c.who.thread) (c.addr (Nat.pair (k + 1) 0)) (c.addr (Nat.pair (k + 1) 1))
    (num := some b8)).1.alloc gemv.prog.layout 0 4 4 false false (.thread c.who.thread)
    (c.addr (Nat.pair (k + 2) 0)) (c.addr (Nat.pair (k + 2) 1)) (num := some b9)).1

/-- For every context, step, memory and block numbers: the three `alloca`s change only the three
numbers (`Mem.SameOff.alloc`). -/
theorem slots_off (c : Ctx) (k : Nat) (m : Mem) (b7 b8 b9 : Nat) :
    m.SameOff (fun q => q = b7 ∨ q = b8 ∨ q = b9) (slots c k m b7 b8 b9) :=
  (((Mem.SameOff.alloc _ _ _ _ _ _ _ _ _ _ _ b7).mono fun _ h => .inl h).trans
    ((Mem.SameOff.alloc _ _ _ _ _ _ _ _ _ _ _ b8).mono fun _ h => .inr (.inl h))).trans
    ((Mem.SameOff.alloc _ _ _ _ _ _ _ _ _ _ _ b9).mono fun _ h => .inr (.inr h))

/-- **The memory after lanes' `alloca`s**, for every contexts `c`, steps `k`, memory `m` and lanes
`ls`: `m` with each lane `i` of `ls` in turn making its three slots (`slots`) at the `alloca`
numbers of its thread `(c i).who.thread` at steps `k i`, `k i + 1` and `k i + 2` (`Mem.fresh`,
`entry`'s `hb7`, `hb8`, `hb9`). -/
def slotsAll (c : Nat → Ctx) (k : Nat → Nat) (m : Mem) (ls : List Nat) : Mem :=
  ls.foldl (fun m i => slots (c i) (k i) m (m.fresh (c i).who.thread (k i))
    (m.fresh (c i).who.thread (k i + 1)) (m.fresh (c i).who.thread (k i + 2))) m

/-- **The lanes' `alloca`s change only their numbers**: for every contexts `c`, steps `k`,
memory `m` and lanes `ls`, `slotsAll` has `m`'s blocks outside the `alloca` numbers of `m` of
the lanes' threads (`Mem.FreshOf`), which leave out every other thread's numbers
(`Mem.not_freshOf`) and the numbers below `m.next` (`Mem.not_freshOf_lt`). -/
theorem slotsAll_off (c : Nat → Ctx) (k : Nat → Nat) :
    ∀ (m : Mem) (ls : List Nat),
      m.SameOff (m.FreshOf fun n => ∃ i ∈ ls, (c i).who.thread = n) (slotsAll c k m ls)
  | m, [] => Mem.SameOff.refl _ m
  | m, i :: ls => by
    have hn := (rfl : (slots (c i) (k i) m (m.fresh (c i).who.thread (k i))
      (m.fresh (c i).who.thread (k i + 1)) (m.fresh (c i).who.thread (k i + 2))).next = m.next)
    refine ((slots_off _ _ _ _ _ _).mono ?_).trans ((slotsAll_off c k _ ls).mono ?_)
    · rintro q (rfl | rfl | rfl) <;> exact ⟨_, _, ⟨i, List.mem_cons_self, rfl⟩, rfl⟩
    · rintro q ⟨n, s, ⟨j, hj, rfl⟩, rfl⟩
      exact ⟨_, s, ⟨j, List.mem_cons_of_mem i hj, rfl⟩, Mem.fresh_of_next hn _ _⟩

/-- **gemv_kernel's entry block `%6` at a free thread.** gemv_kernel, for every valid launch `L`,
thread `kk`, context `c` (`c.prog = gemv.prog`, `c.env = L.env kk`), thread `t` and memory `m`
with: the top frame `f` of `t` at pc 0 of `%6`, `%0`, `%1`, `%2` pointers at offset 0 and
`%3 = M`, `%5 = K`; the three `fresh` block numbers `b7`, `b8`, `b9` at `t.k`, `t.k + 1`,
`t.k + 2` with no block in `m`; and the two deliveries `d₁`, `d₂` of `%24` and `%25` (statements
17 and 18) as premises, with words `u₁`, `u₂` and `EntryInv` at `d₂`'s memory (the three blocks
are the thread's writable slots of 16, 4 and 4 bytes). Then the thread waits at the two
`shfl.sync.idx` calls as `Piece.Wait.via` states them: at statement 17 with the full mask, the
low half `%22` of the row word `X = (ctaid.x * ntid.x + tid.x) / 32` (64 bits, of `L.env kk`'s
special registers), source lane 0 and clamp 31 (gemv IR :13-26), on `slots c t.k m b7 b8 b9`
(the memory after the three `alloca`s), resumed with `d₁`; at statement 18 with the high half
`%23` on `d₁.2`, resumed with `d₂`; given every run from statement 41 at a frame with `%0`,
`%1`, `%2`, `%3`, `%5` kept, `%10`, `%11` their `signExtend 64`, `%35 = <u₁, u₂>`, `alloca`
blocks `[b9, b8, b7]` in front of `f`'s, at step `t.k + 41`, and a memory with every other block
as in `d₂`'s memory, the three blocks' lifetimes ended and a trace that extends `d₂`'s memory's
by the thread's accesses of the three blocks only (`SlotEv`; the meeting point of
`MojoProofTest.GemvLoop.run`). -/
theorem entry (c : Ctx) (hcp : c.prog = gemv.prog) (L : Launch) (hL : L.Valid) (kk : Nat)
    (hce : c.env = L.env kk) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame)
    (ht : t.frames = f :: rest) (hf : f.fn = gemv.fn_0) (hlb : f.label = gemv.fn_0.b_0.label)
    (hpc : f.pc = 0) (p0 pA pB M K : Nat) (h0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (h1 : f.regs 1 = some (.ptr ⟨pA, 0⟩)) (h2 : f.regs 2 = some (.ptr ⟨pB, 0⟩))
    (h3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)))
    (h5 : f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)))
    (b7 b8 b9 : Nat) (hb7 : m.fresh c.who.thread t.k = b7)
    (hb8 : m.fresh c.who.thread (t.k + 1) = b8) (hb9 : m.fresh c.who.thread (t.k + 2) = b9)
    (hnx : 0 < m.next) (hm7 : m.blocks b7 = none) (hm8 : m.blocks b8 = none)
    (hm9 : m.blocks b9 = none)
    (d₁ d₂ : Option Val × Mem) (u₁ u₂ : BitVec 32) (hd₁ : d₁.1 = some (.bits 32 u₁))
    (hd₂ : d₂.1 = some (.bits 32 u₂)) (hI : EntryInv c.who.thread b7 b8 b9 d₂.2 d₂.2)
    (Q : Mem → Prop) (ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
    (hK : ∀ t' m' f', t'.frames = f' :: rest → f'.fn = gemv.fn_0 →
      f'.label = gemv.fn_0.b_0.label → f'.pc = 41 → f'.allocas = [b9, b8, b7] ++ f.allocas →
      t'.k = t.k + 41 →
      f'.regs 0 = some (.ptr ⟨p0, 0⟩) → f'.regs 1 = some (.ptr ⟨pA, 0⟩) →
      f'.regs 2 = some (.ptr ⟨pB, 0⟩) → f'.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)) →
      f'.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)) →
      f'.regs 10 = some (.bits 64 ((BitVec.ofNat 32 M).signExtend 64)) →
      f'.regs 11 = some (.bits 64 ((BitVec.ofNat 32 K).signExtend 64)) →
      f'.regs 35 = some (.vec [.bits 32 u₁, .bits 32 u₂]) →
      EntryInv c.who.thread b7 b8 b9 d₂.2 m' → m'.liveAt b7 = false → m'.liveAt b8 = false →
      m'.liveAt b9 = false → Ext (SlotEv c.who b7 b8 b9) d₂.2 m' → RunsVia c Q ws t' m') :
    RunsVia c Q (Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨17, .shfl .idx,
        [.bits 32 (BitVec.ofInt 32 (-1)), .bits 32 ((BitVec.ofNat 64 (((L.env kk).sreg .ctaid .x *
          (L.env kk).sreg .ntid .x + (L.env kk).sreg .tid .x) / 32)).extractLsb' 0 32),
          .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)],
        slots c t.k m b7 b8 b9, d₁⟩ ::
      Piece.Wait.via gemv.fn_0 gemv.fn_0.b_0.label ⟨18, .shfl .idx,
        [.bits 32 (BitVec.ofInt 32 (-1)), .bits 32 ((BitVec.ofNat 64 (((L.env kk).sreg .ctaid .x *
          (L.env kk).sreg .ntid .x + (L.env kk).sreg .tid .x) / 32)).extractLsb' 32 32),
          .bits 32 (BitVec.ofInt 32 0), .bits 32 (BitVec.ofInt 32 31)], d₁.2, d₂⟩ :: ws) t m := by
  have hl6 : f.label = 6 := hlb
  have n78 : b7 ≠ b8 := by rw [← hb7, ← hb8]; exact Mem.fresh_ne _ _ (by omega)
  have n79 : b7 ≠ b9 := by rw [← hb7, ← hb9]; exact Mem.fresh_ne _ _ (by omega)
  have n89 : b8 ≠ b9 := by rw [← hb8, ← hb9]; exact Mem.fresh_ne _ _ (by omega)
  have n87 := n78.symm
  have n97 := n79.symm
  have n98 := n89.symm
  have z7 : b7 ≠ 0 := by rw [← hb7]; unfold Mem.fresh; omega
  have z8 : b8 ≠ 0 := by rw [← hb8]; unfold Mem.fresh; omega
  have z9 : b9 ≠ 0 := by rw [← hb9]; unfold Mem.fresh; omega
  have hw : (gemv.prog.layout.ptr 0).1 = 64 := by rfl
  have hF0 : (Valuation.entry c t.k m f).fn = gemv.fn_0 := hf
  have hT := Piece.throughTo (K := fun _ _ _ => True) hcp pieces_eq
    (fun _ _ _ _ _ _ _ => trivial) (fun i => [d₁, d₂].getD i d₁) (m := m) ht hf hl6 hpc
  -- statements 0 to 17: the three `alloca`s, the row word and the first shuffle
  have e0 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[0]? =
      some (.ok (.ptr ⟨b7, 0⟩)) := by
    rw [← hb7]; exact vals_getElem?_eval rfl rfl
  have e1 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[1]? =
      some (.ok (.ptr ⟨b8, 0⟩)) := by
    rw [← hb8]; exact vals_getElem?_eval rfl rfl
  have e2 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[2]? =
      some (.ok (.ptr ⟨b9, 0⟩)) := by
    rw [← hb9]; exact vals_getElem?_eval rfl rfl
  have e3 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[3]? =
      some (.ok (.bits 64 ((BitVec.ofNat 32 M).signExtend 64))) := by obl_exact
  have e4 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[4]? =
      some (.ok (.bits 64 ((BitVec.ofNat 32 K).signExtend 64))) := by obl_exact
  obl_have e13 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[13]?
  obtain ⟨X, e13', hX⟩ : ∃ X : BitVec 64,
      (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[13]? = some (.ok (.bits 64 X)) ∧
        BitVec.ofNat 64 (((L.env kk).sreg .ctaid .x * (L.env kk).sreg .ntid .x +
          (L.env kk).sreg .tid .x) / 32) = X :=
    ⟨_, e13, rfl⟩
  clear e13
  have e14 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[14]? =
      some (.ok (.vec ((List.range 2).map fun i => .bits 32 (X.extractLsb' (i * 32) 32)))) :=
    vals_getElem?_eval rfl (by
      rw [SNode.eval_castAt (Valuation.stmt_of_fn hF0 (by rfl)),
        SVal.eval_node_take (by decide) e13']
      refine Eq.trans ?_ (castV_split (Valuation.entry c t.k m f).ctx.prog.layout
        (Valuation.entry c t.k m f).mem (fun i => (Valuation.entry c t.k m f).ctx.oracle
          (Nat.pair ((Valuation.entry c t.k m f).k + 14) i)) (n := 2) (w := 32) X)
      rfl)
  have e15 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[15]? =
      some (.ok (.bits 32 (X.extractLsb' (0 * 32) 32))) :=
    vals_getElem?_eval rfl ((SNode.eval_eltAt_at hF0 (by rfl)
      (SVal.eval_node_take (by decide) e14) rfl).trans rfl)
  have e16 : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[16]? =
      some (.ok (.bits 32 (X.extractLsb' (1 * 32) 32))) :=
    vals_getElem?_eval rfl ((SNode.eval_eltAt_at hF0 (by rfl)
      (SVal.eval_node_take (by decide) e14) rfl).trans rfl)
  have f7 : (Valuation.entry c t.k m f).mem.fresh (Valuation.entry c t.k m f).ctx.who.thread
      ((Valuation.entry c t.k m f).k + 0) = b7 := hb7
  have f8 : (Valuation.entry c t.k m f).mem.fresh (Valuation.entry c t.k m f).ctx.who.thread
      ((Valuation.entry c t.k m f).k + 1) = b8 := hb8
  have f9 : (Valuation.entry c t.k m f).mem.fresh (Valuation.entry c t.k m f).ctx.who.thread
      ((Valuation.entry c t.k m f).k + 2) = b9 := hb9
  have hly : (Valuation.entry c t.k m f).ctx.prog.layout = gemv.prog.layout :=
    congrArg Program.layout hcp
  have lt : ∀ r, r = 7 ∨ r = 8 ∨ r = 9 →
      (!((some r).any (lifetimeStarted (Valuation.entry c t.k m f).ctx
        (Valuation.entry c t.k m f).fn))) = false := by
    intro r hr
    show (!(lifetimeStarted c f.fn r)) = false
    rw [hf]
    unfold lifetimeStarted
    rw [hcp]
    rcases hr with rfl | rfl | rfl <;> decide +kernel
  have hA : SEff.run (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)
      [.alloca 6 0 0 (some (.int 64 1)), .alloca 6 1 1 (some (.int 64 1)),
        .alloca 6 2 2 (some (.int 64 1))] = .ok (slots c t.k m b7 b8 b9) := by
    refine SEff.run_append
      (es := [.alloca 6 0 0 (some (.int 64 1)), .alloca 6 1 1 (some (.int 64 1))]) ?_
      (SEff.apply_alloca_at (z := 4) (a := 4) hF0 (by rfl) rfl hly (by decide +kernel)
        (by decide +kernel) (lt 9 (Or.inr (Or.inr rfl))) f9 ?_)
    rotate_left
    · rw [Mem.alloc_num_ne _ _ _ _ _ _ _ _ _ _ _ n98, Mem.alloc_num_ne _ _ _ _ _ _ _ _ _ _ _ n97]
      exact hm9
    refine SEff.run_append (es := [.alloca 6 0 0 (some (.int 64 1))]) ?_
      (SEff.apply_alloca_at (z := 4) (a := 4) hF0 (by rfl) rfl hly (by decide +kernel)
        (by decide +kernel) (lt 8 (Or.inr (Or.inl rfl))) f8 ?_)
    rotate_left
    · rw [Mem.alloc_num_ne _ _ _ _ _ _ _ _ _ _ _ n87]
      exact hm8
    exact SEff.run_append (es := []) rfl (SEff.apply_alloca_at (z := 16) (a := 8) hF0 (by rfl)
      rfl hly (by decide +kernel) (by decide +kernel) (lt 7 (Or.inl rfl)) f7 hm7)
  refine RunsVia.of_coll hT rfl hf hpc rfl ?_ ?_ fun fr₁ t₁ ht₁ hf₁ hp₁ a₁ hT₁ hV₁ => ?_
  · repeat' first | exact forall_mem_nil' _ | refine forall_mem_cons' ?_ ?_
    · exact Cond.holds_ok rfl
    · exact Cond.holds_ok (SVal.eval_node e15)
    · exact Cond.holds_ok rfl
    · exact Cond.holds_ok rfl
    · exact Cond.holds_mem ⟨_, hA⟩
    · exact Cond.holds_ok (SVal.eval_node e16)
    · exact Cond.holds_ok (SVal.eval_node e15)
    · exact Cond.holds_ok (SVal.eval_node e14)
    · exact Cond.holds_ok (SVal.eval_node e13')
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[12]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[11]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[10]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[9]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[8]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[7]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[6]?
      exact Cond.holds_ok (SVal.eval_node e)
    · obl_have e : (vals (Valuation.entry c t.k m f) gp_0.toSummary.nodes)[5]?
      exact Cond.holds_ok (SVal.eval_node e)
    · exact Cond.holds_ok (SVal.eval_node e4)
    · exact Cond.holds_ok (SVal.eval_node e3)
    · exact Cond.holds_ok (SVal.eval_node e2)
    · exact Cond.holds_ok (SVal.eval_node e1)
    · exact Cond.holds_ok (SVal.eval_node e0)
  · rw [hX]
    exact Piece.Wait.via_of rfl rfl (SVal.mapM_shfl _ _ _ (SVal.eval_node e15)) hA
  have hV₁' : Valuation.entry c t₁.k d₁.2 fr₁ =
      (Valuation.entry c t.k m f).resume gp_0.toSummary (some 24) d₁ := hV₁
  have r0₁ : fr₁.regs 0 = some (.ptr ⟨p0, 0⟩) := Frame.regs_keep hV₁' (by decide) rfl h0
  have r1₁ : fr₁.regs 1 = some (.ptr ⟨pA, 0⟩) := Frame.regs_keep hV₁' (by decide) rfl h1
  have r2₁ : fr₁.regs 2 = some (.ptr ⟨pB, 0⟩) := Frame.regs_keep hV₁' (by decide) rfl h2
  have r3₁ : fr₁.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)) :=
    Frame.regs_keep hV₁' (by decide) rfl h3
  have r5₁ : fr₁.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)) :=
    Frame.regs_keep hV₁' (by decide) rfl h5
  have r7₁ : fr₁.regs 7 = some (.ptr ⟨b7, 0⟩) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e0)
  have r8₁ : fr₁.regs 8 = some (.ptr ⟨b8, 0⟩) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e1)
  have r9₁ : fr₁.regs 9 = some (.ptr ⟨b9, 0⟩) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e2)
  have r10₁ : fr₁.regs 10 = some (.bits 64 ((BitVec.ofNat 32 M).signExtend 64)) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e3)
  have r11₁ : fr₁.regs 11 = some (.bits 64 ((BitVec.ofNat 32 K).signExtend 64)) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e4)
  have r23₁ : fr₁.regs 23 = some (.bits 32 (X.extractLsb' (1 * 32) 32)) :=
    Frame.regs_set hV₁' (by decide) rfl (SVal.eval_node e16)
  have r24₁ : fr₁.regs 24 = some (.bits 32 u₁) := Frame.regs_self hV₁' hd₁
  clear e0 e1 e2 e3 e4 e13' e14 e15 e16 hA hV₁
  -- statement 18: the second shuffle
  refine RunsVia.of_coll hT₁ rfl hf₁ hp₁ rfl ?_ ?_ fun fr₂ t₂ ht₂ hf₂ hp₂ a₂ hT₂ hV₂ => ?_
  · entry_obls
  · rw [hX]
    exact Piece.Wait.via_of rfl rfl (SVal.mapM_shfl _ _ _ (SVal.eval_reg r23₁)) rfl
  have hV₂' : Valuation.entry c t₂.k d₂.2 fr₂ =
      (Valuation.entry c t₁.k d₁.2 fr₁).resume gp_1.toSummary (some 25) d₂ := hV₂
  have r0₂ : fr₂.regs 0 = some (.ptr ⟨p0, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r0₁
  have r1₂ : fr₂.regs 1 = some (.ptr ⟨pA, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r1₁
  have r2₂ : fr₂.regs 2 = some (.ptr ⟨pB, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r2₁
  have r3₂ : fr₂.regs 3 = some (.bits 32 (BitVec.ofNat 32 M)) :=
    Frame.regs_keep hV₂' (by decide) rfl r3₁
  have r5₂ : fr₂.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)) :=
    Frame.regs_keep hV₂' (by decide) rfl r5₁
  have r7₂ : fr₂.regs 7 = some (.ptr ⟨b7, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r7₁
  have r8₂ : fr₂.regs 8 = some (.ptr ⟨b8, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r8₁
  have r9₂ : fr₂.regs 9 = some (.ptr ⟨b9, 0⟩) := Frame.regs_keep hV₂' (by decide) rfl r9₁
  have r10₂ : fr₂.regs 10 = some (.bits 64 ((BitVec.ofNat 32 M).signExtend 64)) :=
    Frame.regs_keep hV₂' (by decide) rfl r10₁
  have r11₂ : fr₂.regs 11 = some (.bits 64 ((BitVec.ofNat 32 K).signExtend 64)) :=
    Frame.regs_keep hV₂' (by decide) rfl r11₁
  have r24₂ : fr₂.regs 24 = some (.bits 32 u₁) := Frame.regs_keep hV₂' (by decide) rfl r24₁
  have r25₂ : fr₂.regs 25 = some (.bits 32 u₂) := Frame.regs_self hV₂' hd₂
  have g₂ : fr₂.fn = gemv.fn_0 := hf₂
  clear r0₁ r1₁ r2₁ r3₁ r5₁ r7₁ r8₁ r9₁ r10₁ r11₁ r23₁ r24₁ hV₂
  -- statement 19: the end of `%9`'s lifetime
  refine RunsVia.of_life (b := b9) (o := 0) hT₂ rfl ?_ (SVal.eval_reg r9₂)
    fun me hme => ⟨?_, fun fr₃ t₃ ht₃ hf₃ hl₃ hp₃ a₃ hT₃ hV₃ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : d₂.2 = me)]; exact Mem.slot_owner hI.2.2.1 0
  rw [← (Except.ok.inj hme : d₂.2 = me)] at hT₃ hV₃ ⊢
  generalize hm₃ : d₂.2.setLive b9 false = m₃ at hT₃ hV₃ ⊢
  have I₃ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₃ := by
    rw [← hm₃]; exact EntryInv.setLive false (Or.inr (Or.inr rfl)) hI
  have X₃ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₃ := by
    rw [← hm₃]; exact ext_keep (ext_refl _ _) (Mem.setLive_trace _ _ _)
  have R₃ : fr₃.regs = fr₂.regs := Frame.regs_none hV₃ rfl
  have g₃ : fr₃.fn = gemv.fn_0 := hf₃.trans g₂
  have r9₃ : fr₃.regs 9 = some (.ptr ⟨b9, 0⟩) := by rw [R₃]; exact r9₂
  -- statement 20: the start of `%9`'s lifetime
  refine RunsVia.of_life (b := b9) (o := 0) hT₃ rfl ?_ (SVal.eval_reg r9₃)
    fun me hme => ⟨?_, fun fr₄ t₄ ht₄ hf₄ hl₄ hp₄ a₄ hT₄ hV₄ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : m₃ = me)]; exact Mem.slot_owner I₃.2.2.1 0
  rw [← (Except.ok.inj hme : m₃ = me)] at hT₄ hV₄ ⊢
  generalize hm₄ : m₃.setLive b9 true = m₄ at hT₄ hV₄ ⊢
  have I₄ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₄ := by
    rw [← hm₄]; exact EntryInv.setLive true (Or.inr (Or.inr rfl)) I₃
  have X₄ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₄ := by
    rw [← hm₄]; exact ext_keep X₃ (Mem.setLive_trace _ _ _)
  have lv9₄ : m₄.liveAt b9 = true := by rw [← hm₄]; exact Mem.liveAt_setLive_self I₃.2.2.1 true
  have R₄ : fr₄.regs = fr₃.regs := Frame.regs_none hV₄ rfl
  have g₄ : fr₄.fn = gemv.fn_0 := hf₄.trans g₃
  have hF4 : (Valuation.entry c t₄.k m₄ fr₄).fn = gemv.fn_0 := g₄
  have r8₄ : fr₄.regs 8 = some (.ptr ⟨b8, 0⟩) := by rw [R₄, R₃]; exact r8₂
  have r9₄ : fr₄.regs 9 = some (.ptr ⟨b9, 0⟩) := by rw [R₄, R₃]; exact r9₂
  have r24₄ : fr₄.regs 24 = some (.bits 32 u₁) := by rw [R₄, R₃]; exact r24₂
  -- statements 21 and 22: the store of `%24` at `%9`, the end of `%8`'s lifetime
  obtain ⟨S4, hS4⟩ := Mem.slot_store_ok (l := gemv.prog.layout) (w := c.who) (t := .int 32)
    (v := .bits 32 u₁) (o := 0) (a' := 4) I₄.2.2.1 lv9₄ hw z9 (by decide) (by decide)
    (dvd_refl 4) (dvd_zero 4) rfl
  obtain ⟨_, -, -, hc9⟩ := Mem.slot_check (l := gemv.prog.layout) (w := c.who) (o := 0)
    (n' := gemv.prog.layout.stored (.int 32)) (a' := 4) I₄.2.2.1 lv9₄ hw z9 (by decide)
    (by decide) (dvd_refl 4) (dvd_zero 4)
  have LS4 := Mem.load_store_codec (Layout.Codec.int _ 32) u₁ hS4 hc9
  have hr4 : SEff.run (Valuation.entry c t₄.k m₄ fr₄)
      (vals (Valuation.entry c t₄.k m₄ fr₄) (gp_4.toSummary 1).nodes)
      (gp_4.toSummary 1).effs = .ok S4 :=
    SEff.run_store_ok (a := 0) (t := .int 32) (al := some 4) hF4 hcp (by rfl) (SVal.eval_reg r24₄) (SVal.eval_reg r9₄) hS4
  refine RunsVia.of_life (b := b8) (o := 0) hT₄ rfl ?_ (SVal.eval_reg r8₄)
    fun me hme => ⟨?_, fun fr₅ t₅ ht₅ hf₅ hl₅ hp₅ a₅ hT₅ hV₅ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj (hr4.symm.trans hme) : S4 = me)]
    exact Mem.slot_owner (by rw [Mem.slot_store hS4]; exact I₄.2.1) 0
  rw [← (Except.ok.inj (hr4.symm.trans hme) : S4 = me)] at hT₅ hV₅ ⊢
  generalize hm₅ : S4.setLive b8 false = m₅ at hT₅ hV₅ ⊢
  have I₅ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₅ := by
    rw [← hm₅]; exact EntryInv.setLive false (Or.inr (Or.inl rfl)) (EntryInv.store hS4
      (Or.inr (Or.inr rfl)) I₄)
  have X₅ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₅ := by
    rw [← hm₅]; exact ext_keep (ext_store X₄ hS4 (Or.inr (Or.inr rfl))) (Mem.setLive_trace _ _ _)
  have R₅ : fr₅.regs = fr₄.regs := Frame.regs_none hV₅ rfl
  have g₅ : fr₅.fn = gemv.fn_0 := hf₅.trans g₄
  have r8₅ : fr₅.regs 8 = some (.ptr ⟨b8, 0⟩) := by rw [R₅]; exact r8₄
  -- statement 23: the start of `%8`'s lifetime
  refine RunsVia.of_life (b := b8) (o := 0) hT₅ rfl ?_ (SVal.eval_reg r8₅)
    fun me hme => ⟨?_, fun fr₆ t₆ ht₆ hf₆ hl₆ hp₆ a₆ hT₆ hV₆ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : m₅ = me)]; exact Mem.slot_owner I₅.2.1 0
  rw [← (Except.ok.inj hme : m₅ = me)] at hT₆ hV₆ ⊢
  generalize hm₆ : m₅.setLive b8 true = m₆ at hT₆ hV₆ ⊢
  have I₆ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₆ := by
    rw [← hm₆]; exact EntryInv.setLive true (Or.inr (Or.inl rfl)) I₅
  have X₆ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₆ := by
    rw [← hm₆]; exact ext_keep X₅ (Mem.setLive_trace _ _ _)
  have lv8₆ : m₆.liveAt b8 = true := by rw [← hm₆]; exact Mem.liveAt_setLive_self I₅.2.1 true
  have R₆ : fr₆.regs = fr₅.regs := Frame.regs_none hV₆ rfl
  have g₆ : fr₆.fn = gemv.fn_0 := hf₆.trans g₅
  have hF6 : (Valuation.entry c t₆.k m₆ fr₆).fn = gemv.fn_0 := g₆
  have r7₆ : fr₆.regs 7 = some (.ptr ⟨b7, 0⟩) := by rw [R₆, R₅, R₄, R₃]; exact r7₂
  have r8₆ : fr₆.regs 8 = some (.ptr ⟨b8, 0⟩) := by rw [R₆]; exact r8₅
  have r25₆ : fr₆.regs 25 = some (.bits 32 u₂) := by rw [R₆, R₅, R₄, R₃]; exact r25₂
  -- statements 24 and 25: the store of `%25` at `%8`, the end of `%7`'s lifetime
  obtain ⟨S6, hS6⟩ := Mem.slot_store_ok (l := gemv.prog.layout) (w := c.who) (t := .int 32)
    (v := .bits 32 u₂) (o := 0) (a' := 4) I₆.2.1 lv8₆ hw z8 (by decide) (by decide)
    (dvd_refl 4) (dvd_zero 4) rfl
  obtain ⟨_, -, -, hc8⟩ := Mem.slot_check (l := gemv.prog.layout) (w := c.who) (o := 0)
    (n' := gemv.prog.layout.stored (.int 32)) (a' := 4) I₆.2.1 lv8₆ hw z8 (by decide)
    (by decide) (dvd_refl 4) (dvd_zero 4)
  have LS6 := Mem.load_store_codec (Layout.Codec.int _ 32) u₂ hS6 hc8
  have hr6 : SEff.run (Valuation.entry c t₆.k m₆ fr₆)
      (vals (Valuation.entry c t₆.k m₆ fr₆) (gp_6.toSummary 1).nodes)
      (gp_6.toSummary 1).effs = .ok S6 :=
    SEff.run_store_ok (a := 0) (t := .int 32) (al := some 4) hF6 hcp (by rfl) (SVal.eval_reg r25₆) (SVal.eval_reg r8₆) hS6
  refine RunsVia.of_life (b := b7) (o := 0) hT₆ rfl ?_ (SVal.eval_reg r7₆)
    fun me hme => ⟨?_, fun fr₇ t₇ ht₇ hf₇ hl₇ hp₇ a₇ hT₇ hV₇ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj (hr6.symm.trans hme) : S6 = me)]
    exact Mem.slot_owner (by rw [Mem.slot_store hS6]; exact I₆.1) 0
  rw [← (Except.ok.inj (hr6.symm.trans hme) : S6 = me)] at hT₇ hV₇ ⊢
  generalize hm₇ : S6.setLive b7 false = m₇ at hT₇ hV₇ ⊢
  have I₇ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₇ := by
    rw [← hm₇]; exact EntryInv.setLive false (Or.inl rfl) (EntryInv.store hS6
      (Or.inr (Or.inl rfl)) I₆)
  have X₇ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₇ := by
    rw [← hm₇]; exact ext_keep (ext_store X₆ hS6 (Or.inr (Or.inl rfl))) (Mem.setLive_trace _ _ _)
  have R₇ : fr₇.regs = fr₆.regs := Frame.regs_none hV₇ rfl
  have g₇ : fr₇.fn = gemv.fn_0 := hf₇.trans g₆
  have hF7 : (Valuation.entry c t₇.k m₇ fr₇).fn = gemv.fn_0 := g₇
  have r7₇ : fr₇.regs 7 = some (.ptr ⟨b7, 0⟩) := by rw [R₇]; exact r7₆
  have r8₇ : fr₇.regs 8 = some (.ptr ⟨b8, 0⟩) := by rw [R₇]; exact r8₆
  have r9₇ : fr₇.regs 9 = some (.ptr ⟨b9, 0⟩) := by rw [R₇, R₆, R₅, R₄, R₃]; exact r9₂
  -- statements 26 to 28: `%26`, `%27`, the start of `%7`'s lifetime
  have j0 : (vals (Valuation.entry c t₇.k m₇ fr₇) (gp_7.toSummary 2).nodes)[0]? =
      some (.ok (fill .undef (.arr 2 (.ptr 0)))) :=
    vals_getElem?_eval rfl (SNode.eval_constAt_undef hF7 (by rfl) (by rfl))
  have j1 : (vals (Valuation.entry c t₇.k m₇ fr₇) (gp_7.toSummary 2).nodes)[1]? =
      some (.ok (.agg [.ptr ⟨b9, 0⟩, .undef])) :=
    vals_getElem?_eval rfl ((SNode.eval_insert (SVal.eval_node_take (by decide) j0)
      (SVal.eval_reg r9₇)).trans rfl)
  have j2 : (vals (Valuation.entry c t₇.k m₇ fr₇) (gp_7.toSummary 2).nodes)[2]? =
      some (.ok (.agg [.ptr ⟨b9, 0⟩, .ptr ⟨b8, 0⟩])) :=
    vals_getElem?_eval rfl ((SNode.eval_insert (SVal.eval_node_take (by decide) j1)
      (SVal.eval_reg r8₇)).trans rfl)
  refine RunsVia.of_life (b := b7) (o := 0) hT₇ rfl ?_ (SVal.eval_reg r7₇)
    fun me hme => ⟨?_, fun fr₈ t₈ ht₈ hf₈ hl₈ hp₈ a₈ hT₈ hV₈ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : m₇ = me)]; exact Mem.slot_owner I₇.1 0
  rw [← (Except.ok.inj hme : m₇ = me)] at hT₈ hV₈ ⊢
  generalize hm₈ : m₇.setLive b7 true = m₈ at hT₈ hV₈ ⊢
  have I₈ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₈ := by
    rw [← hm₈]; exact EntryInv.setLive true (Or.inl rfl) I₇
  have X₈ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₈ := by
    rw [← hm₈]; exact ext_keep X₇ (Mem.setLive_trace _ _ _)
  have lv7₈ : m₈.liveAt b7 = true := by rw [← hm₈]; exact Mem.liveAt_setLive_self I₇.1 true
  have g₈ : fr₈.fn = gemv.fn_0 := hf₈.trans g₇
  have hF8 : (Valuation.entry c t₈.k m₈ fr₈).fn = gemv.fn_0 := g₈
  have r7₈ : fr₈.regs 7 = some (.ptr ⟨b7, 0⟩) := Frame.regs_keep hV₈ (by simp) rfl r7₇
  have r8₈ : fr₈.regs 8 = some (.ptr ⟨b8, 0⟩) := Frame.regs_keep hV₈ (by simp) rfl r8₇
  have r9₈ : fr₈.regs 9 = some (.ptr ⟨b9, 0⟩) := Frame.regs_keep hV₈ (by simp) rfl r9₇
  have r27₈ : fr₈.regs 27 = some (.agg [.ptr ⟨b9, 0⟩, .ptr ⟨b8, 0⟩]) :=
    Frame.regs_set hV₈ (by simp) rfl (SVal.eval_node j2)
  clear j0 j1 j2
  -- statements 29 to 38: the store of `%27` at `%7`, the four loads, `%31`, `%35`, the end of
  -- `%7`'s lifetime
  obtain ⟨S8, hS8⟩ := Mem.slot_store_ok (l := gemv.prog.layout) (w := c.who)
    (t := .arr 2 (.ptr 0)) (v := .agg [.ptr ⟨b9, 0⟩, .ptr ⟨b8, 0⟩]) (o := 0) (a' := 8) I₈.1
    lv7₈ hw z7 (by decide) (by decide) (dvd_refl 8) (dvd_zero 8) rfl
  have hst : ∀ vs, SEff.run (Valuation.entry c t₈.k m₈ fr₈) vs
      [.store 6 29 (.reg 27) (.reg 7)] = .ok S8 := fun _ =>
    SEff.run_store_ok (a := 0) (t := .arr 2 (.ptr 0)) (al := some 8) hF8 hcp (by rfl) (SVal.eval_reg r27₈) (SVal.eval_reg r7₈) hS8
  obtain ⟨g7, hA7, hg7⟩ := Mem.slot_addr (l := gemv.prog.layout) I₈.1 lv7₈ hw (by decide)
  obtain ⟨B7, hB7, -, hf7⟩ := Mem.slot_fits I₈.1
  obtain ⟨_, -, -, hq0⟩ := Mem.slot_check (l := gemv.prog.layout) (w := c.who) (o := 0)
    (n' := gemv.prog.layout.stored (.ptr 0)) (a' := 8) I₈.1 lv7₈ hw z7 (by decide)
    (by decide) (dvd_refl 8) (dvd_zero 8)
  obtain ⟨_, -, -, hq8⟩ := Mem.slot_check (l := gemv.prog.layout) (w := c.who) (o := 8)
    (n' := gemv.prog.layout.stored (.ptr 0)) (a' := 8) I₈.1 lv7₈ hw z7 (by decide)
    (by decide) (dvd_refl 8) (dvd_refl 8)
  have B9 : m₈.blocks b9 = S4.blocks b9 := by
    rw [← hm₈, Mem.setLive_blocks_ne _ _ n97, ← hm₇, Mem.setLive_blocks_ne _ _ n97,
      Mem.store_blocks hS6 n89, ← hm₆, Mem.setLive_blocks_ne _ _ n98, ← hm₅,
      Mem.setLive_blocks_ne _ _ n98]
  have B8 : m₈.blocks b8 = S6.blocks b8 := by
    rw [← hm₈, Mem.setLive_blocks_ne _ _ n87, ← hm₇, Mem.setLive_blocks_ne _ _ n87]
  have L9 : m₈.load gemv.prog.layout c.who 0 (.int 32) ⟨b9, 0⟩ (some 4) =
      .ok (.bits 32 u₁) := (Mem.load_of_block (p := ⟨b9, 0⟩) B9 _ _ _ _).trans LS4
  have L8 : m₈.load gemv.prog.layout c.who 0 (.int 32) ⟨b8, 0⟩ (some 4) =
      .ok (.bits 32 u₂) := (Mem.load_of_block (p := ⟨b8, 0⟩) B8 _ _ _ _).trans LS6
  have k0 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[0]? =
      some (.ok (.ptr ⟨b7, 0⟩)) :=
    vals_getElem?_eval rfl ((SNode.eval_gepN_at hF8 hcp (by rfl) rfl
      (SVal.eval_reg r7₈)).trans
      (gep_zeros hA7 (Nat.lt_of_lt_of_le (Nat.lt_add_of_pos_right (by decide : 0 < 16)) hg7)))
  have k1 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[1]? =
      some (.ok (.ptr ⟨b9, 0⟩)) :=
    vals_getElem?_eval rfl (SNode.eval_loadAfter_elem (es := []) (xs := [(⟨b9, 0⟩ : Ptr), ⟨b8, 0⟩]) (n := 2) (a := 0) (al := some 8)
      (k := 0) hF8 hcp (Layout.Codec.ptr _ 0 (by decide)) rfl (by decide) (by rfl) (by rfl)
      ⟨S8, hst _⟩ (SVal.eval_reg r27₈) (SVal.eval_reg r7₈)
      (SVal.eval_node_take (by decide) k0) rfl (by rfl) rfl hq0)
  have k2 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[2]? =
      some (.ok (.bits 32 u₁)) :=
    vals_getElem?_eval rfl (SNode.eval_loadAfter_log_ex (es := [.store 6 29 (.reg 27) (.reg 7)])
      ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
        (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0))⟩
      (SNode.eval_loadAfter_apart_at (es := []) hF8 hcp (by rfl) (by rfl) ⟨S8, hst _⟩
        (SVal.eval_node_take (by decide) k1) (SVal.eval_reg r7₈) (Or.inl n97)
        (SNode.eval_loadAfter_nil.trans (SNode.eval_load_at (t := .int 32) (a := 0) (al := some 4) hF8 hcp (by rfl)
          (SVal.eval_node_take (by decide) k1) L9 rfl))))
  have k3 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[3]? =
      some (.ok (fill .undef (.vec 2 (.int 32)))) :=
    vals_getElem?_eval rfl (SNode.eval_constAt_undef hF8 (by rfl) (by rfl))
  have k4 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[4]? =
      some (.ok (.vec [.bits 32 u₁, .undef])) :=
    vals_getElem?_eval rfl (SNode.eval_insEltAt_at hF8 (by rfl)
      (SVal.eval_node_take (by decide) k3) (SVal.eval_node_take (by decide) k2) rfl (by rfl))
  have k5 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[5]? =
      some (.ok (.ptr ⟨b7, 8⟩)) :=
    vals_getElem?_eval rfl (SNode.eval_gep_at hF8 hcp (by rfl) rfl
      (SVal.eval_node_take (by decide) k0) (gep_buffer (K := 1) (w := 32) (src := .ptr 0) (a := 0) rfl
        (Mem.slot_bufferIn I₈.1 lv7₈) (Or.inl rfl) ⟨B7, hB7, by rw [ite_eq_left rfl, hw]; exact hf7⟩
        (by rw [hw]; decide) (by decide) (by decide) (by decide)))
  have k6 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[6]? =
      some (.ok (.ptr ⟨b8, 0⟩)) :=
    vals_getElem?_eval rfl (SNode.eval_loadAfter_log_ex
      (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
      ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
        (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
          (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0)))
        (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k1))⟩
      (SNode.eval_loadAfter_log_ex (es := [.store 6 29 (.reg 27) (.reg 7)])
        ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
          (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0))⟩
        (SNode.eval_loadAfter_elem (es := []) (xs := [(⟨b9, 0⟩ : Ptr), ⟨b8, 0⟩]) (n := 2) (a := 0) (al := some 8)
          (k := 1) hF8 hcp (Layout.Codec.ptr _ 0 (by decide)) rfl (by decide) (by rfl) (by rfl)
          ⟨S8, hst _⟩ (SVal.eval_reg r27₈) (SVal.eval_reg r7₈)
          (SVal.eval_node_take (by decide) k5) rfl (by rfl) rfl hq8)))
  have k7 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[7]? =
      some (.ok (.bits 32 u₂)) :=
    vals_getElem?_eval rfl (SNode.eval_loadAfter_log_ex
      (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0), .load 6 32 (.node 1)])
      ⟨_, SEff.run_append
        (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0), .load 6 32 (.node 1)])
        (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
          (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
            (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0)))
          (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k1)))
        (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k5))⟩
      (SNode.eval_loadAfter_log_ex
        (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
        ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
          (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
            (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0)))
          (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k1))⟩
        (SNode.eval_loadAfter_log_ex (es := [.store 6 29 (.reg 27) (.reg 7)])
          ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
            (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node_take (by decide) k0))⟩
          (SNode.eval_loadAfter_apart_at (es := []) hF8 hcp (by rfl) (by rfl) ⟨S8, hst _⟩
            (SVal.eval_node_take (by decide) k6) (SVal.eval_reg r7₈) (Or.inl n87)
            (SNode.eval_loadAfter_nil.trans (SNode.eval_load_at (t := .int 32) (a := 0) (al := some 4) hF8 hcp (by rfl)
              (SVal.eval_node_take (by decide) k6) L8 rfl))))))
  have k8 : (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)[8]? =
      some (.ok (.vec [.bits 32 u₁, .bits 32 u₂])) :=
    vals_getElem?_eval rfl (SNode.eval_insEltAt_at hF8 (by rfl)
      (SVal.eval_node_take (by decide) k4) (SVal.eval_node_take (by decide) k7) rfl (by rfl))
  obtain ⟨M8, hM8, hB8, hX8⟩ : ∃ M, SEff.run (Valuation.entry c t₈.k m₈ fr₈)
      (vals (Valuation.entry c t₈.k m₈ fr₈) (gp_8.toSummary 9).nodes)
      (gp_8.toSummary 9).effs = .ok M ∧ M.blocks = S8.blocks ∧
        Ext (SlotEv c.who b7 b8 b9) S8 M :=
    ⟨_, SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0),
        .load 6 32 (.node 1), .load 6 35 (.node 5)])
      (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0),
          .load 6 32 (.node 1)])
        (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7), .load 6 31 (.node 0)])
          (SEff.run_append (es := [.store 6 29 (.reg 27) (.reg 7)]) (hst _)
            (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node k0)))
          (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node k1)))
        (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node k5)))
      (SEff.apply_load_at hF8 (by rfl) (SVal.eval_node k6)), rfl, [_, _, _, _], rfl,
      fun e he => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at he
        rcases he with rfl | rfl | rfl | rfl <;>
          exact ⟨_, rfl, rfl, rfl, rfl, by simp⟩⟩
  have I₈' : EntryInv c.who.thread b7 b8 b9 d₂.2 M8 :=
    EntryInv.of_blocks hB8 (EntryInv.store hS8 (Or.inl rfl) I₈)
  refine RunsVia.of_life (b := b7) (o := 0) hT₈ rfl ?_ (SVal.eval_reg r7₈)
    fun me hme => ⟨?_, fun fr₉ t₉ ht₉ hf₉ hl₉ hp₉ a₉ hT₉ hV₉ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj (hM8.symm.trans hme) : M8 = me)]; exact Mem.slot_owner I₈'.1 0
  rw [← (Except.ok.inj (hM8.symm.trans hme) : M8 = me)] at hT₉ hV₉ ⊢
  generalize hm₉ : M8.setLive b7 false = m₉ at hT₉ hV₉ ⊢
  have I₉ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₉ := by
    rw [← hm₉]; exact EntryInv.setLive false (Or.inl rfl) I₈'
  have X₉ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₉ := by
    rw [← hm₉]
    exact ext_keep ((ext_store X₈ hS8 (Or.inl rfl)).trans hX8) (Mem.setLive_trace _ _ _)
  have lv7₉ : m₉.liveAt b7 = false := by rw [← hm₉]; exact Mem.liveAt_setLive_self I₈'.1 false
  have g₉ : fr₉.fn = gemv.fn_0 := hf₉.trans g₈
  have r35₉ : fr₉.regs 35 = some (.vec [.bits 32 u₁, .bits 32 u₂]) :=
    Frame.regs_set hV₉ (by simp) rfl (SVal.eval_node k8)
  have r8₉ : fr₉.regs 8 = some (.ptr ⟨b8, 0⟩) := Frame.regs_keep hV₉ (by simp) rfl r8₈
  have r9₉ : fr₉.regs 9 = some (.ptr ⟨b9, 0⟩) := Frame.regs_keep hV₉ (by simp) rfl r9₈
  have up : ∀ s v, s ≠ 26 → s ≠ 27 → s < 28 → fr₂.regs s = some v → fr₉.regs s = some v := by
    intro s v h26 h27 h28 h
    have h7 : fr₇.regs s = some v := by rw [R₇, R₆, R₅, R₄, R₃]; exact h
    refine Frame.regs_keep hV₉ (by simp) ?_ (Frame.regs_keep hV₈ (by simp) ?_ h7)
    · show (gp_8.regs).lookup s = none
      interval_cases s <;> rfl
    · show (gp_7.regs).lookup s = none
      interval_cases s <;> first | rfl | omega
  clear k0 k1 k2 k3 k4 k5 k6 k7 k8 hM8
  -- statement 39: the end of `%8`'s lifetime
  refine RunsVia.of_life (b := b8) (o := 0) hT₉ rfl ?_ (SVal.eval_reg r8₉)
    fun me hme => ⟨?_, fun fr₁₀ t₁₀ ht₁₀ hf₁₀ hl₁₀ hp₁₀ a₁₀ hT₁₀ hV₁₀ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : m₉ = me)]; exact Mem.slot_owner I₉.2.1 0
  rw [← (Except.ok.inj hme : m₉ = me)] at hT₁₀ hV₁₀ ⊢
  generalize hm₁₀ : m₉.setLive b8 false = m₁₀ at hT₁₀ hV₁₀ ⊢
  have I₁₀ : EntryInv c.who.thread b7 b8 b9 d₂.2 m₁₀ := by
    rw [← hm₁₀]; exact EntryInv.setLive false (Or.inr (Or.inl rfl)) I₉
  have X₁₀ : Ext (SlotEv c.who b7 b8 b9) d₂.2 m₁₀ := by
    rw [← hm₁₀]; exact ext_keep X₉ (Mem.setLive_trace _ _ _)
  have lv8₁₀ : m₁₀.liveAt b8 = false := by
    rw [← hm₁₀]; exact Mem.liveAt_setLive_self I₉.2.1 false
  have lv7₁₀ : m₁₀.liveAt b7 = false := by
    rw [← hm₁₀, Mem.liveAt_setLive_ne _ _ n78]; exact lv7₉
  have R₁₀ : fr₁₀.regs = fr₉.regs := Frame.regs_none hV₁₀ rfl
  have g₁₀ : fr₁₀.fn = gemv.fn_0 := hf₁₀.trans g₉
  have r9₁₀ : fr₁₀.regs 9 = some (.ptr ⟨b9, 0⟩) := by rw [R₁₀]; exact r9₉
  -- statement 40: the end of `%9`'s lifetime
  refine RunsVia.of_life (b := b9) (o := 0) hT₁₀ rfl ?_ (SVal.eval_reg r9₁₀)
    fun me hme => ⟨?_, fun fr₁₁ t₁₁ ht₁₁ hf₁₁ hl₁₁ hp₁₁ a₁₁ hT₁₁ hV₁₁ => ?_⟩
  · entry_obls
  · rw [← (Except.ok.inj hme : m₁₀ = me)]; exact Mem.slot_owner I₁₀.2.2.1 0
  rw [← (Except.ok.inj hme : m₁₀ = me)] at hT₁₁ hV₁₁ ⊢
  have R₁₁ : fr₁₁.regs = fr₁₀.regs := Frame.regs_none hV₁₁ rfl
  have fin : ∀ s v, s ≠ 26 → s ≠ 27 → s < 28 → fr₂.regs s = some v → fr₁₁.regs s = some v :=
    fun s v x y z h => by rw [R₁₁, R₁₀]; exact up s v x y z h
  refine hK _ _ _ ht₁₁ (hf₁₁.trans g₁₀) hl₁₁ ?_ ?_ ?_ (fin _ _ (by decide) (by decide) (by decide) r0₂)
    (fin _ _ (by decide) (by decide) (by decide) r1₂)
    (fin _ _ (by decide) (by decide) (by decide) r2₂)
    (fin _ _ (by decide) (by decide) (by decide) r3₂)
    (fin _ _ (by decide) (by decide) (by decide) r5₂)
    (fin _ _ (by decide) (by decide) (by decide) r10₂)
    (fin _ _ (by decide) (by decide) (by decide) r11₂)
    (by rw [R₁₁, R₁₀]; exact r35₉)
    (EntryInv.setLive false (Or.inr (Or.inr rfl)) I₁₀)
    (by rw [Mem.liveAt_setLive_ne _ _ n79]; exact lv7₁₀)
    (by rw [Mem.liveAt_setLive_ne _ _ n89]; exact lv8₁₀)
    (Mem.liveAt_setLive_self I₁₀.2.2.1 false) (ext_keep X₁₀ (Mem.setLive_trace _ _ _))
  · rw [hp₁₁, hp₁₀, hp₉, hp₈, hp₇, hp₆, hp₅, hp₄, hp₃, hp₂]
    rfl
  · rw [a₁₁, a₁₀, a₉, a₈, a₇, a₆, a₅, a₄, a₃, a₂, a₁, ← hb7, ← hb8, ← hb9]
    rfl
  · have q₁₁ : t₁₁.k = _ := congrArg Valuation.k hV₁₁
    have q₁₀ : t₁₀.k = _ := congrArg Valuation.k hV₁₀
    have q₉ : t₉.k = _ := congrArg Valuation.k hV₉
    have q₈ : t₈.k = _ := congrArg Valuation.k hV₈
    have q₇ : t₇.k = _ := congrArg Valuation.k hV₇
    have q₆ : t₆.k = _ := congrArg Valuation.k hV₆
    have q₅ : t₅.k = _ := congrArg Valuation.k hV₅
    have q₄ : t₄.k = _ := congrArg Valuation.k hV₄
    have q₃ : t₃.k = _ := congrArg Valuation.k hV₃
    have q₂ : t₂.k = _ := congrArg Valuation.k hV₂'
    have q₁ : t₁.k = _ := congrArg Valuation.k hV₁'
    rw [q₁₁, q₁₀, q₉, q₈, q₇, q₆, q₅, q₄, q₃, q₂, q₁]
    rfl

end MojoProofTest.GemvEntryRun
