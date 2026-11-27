import MojoProof.Sym.Canon
import MojoProof.Sym.WaitVia
import Mathlib.Tactic.IntervalCases

/-!
# `warp_route`: a warp's run through its shuffles from its lanes' facts

`WarpRun.of_waits` gives a warp's run (`WarpRun`) through `J` shuffles from four premises, each
over the warp's lanes `warpLanes L k` and, but for the lanes' runs, its phases `i < J`: the lanes'
runs through their waits (`hr`), the waits' shuffles (`hW`), the waits' memories (`hm`) and each
phase's start on the memory the one before leaves (`h0`). A kernel states its lanes' facts for
`j < N`, with `N` the warp's lane count, and its lanes' runs in the form `RunsVia.of_fires` gives.
This module turns those into the premises:

* `RunsVia.of_runs`, `RunsVia.of_block`, `RunsVia.of_blocks`: a lane's run with no wait (`Runs`),
  through one block of waits `ws.map (Piece.Wait.via fn l)` or through two,
  `a.map (Piece.Wait.via fn l₁) ++ b.map (Piece.Wait.via fn l₂)`, as `hr` asks it at the lane;
* `Piece.Wait.shflOk`, `Program.shflNil`, `Program.shfl_nil`, `WarpRun.shfl_of`: `hW` from each
  lane's Boolean check of its waits (the shuffle's mode, position, full mask, offer, lane operand,
  clamp and delivery, `Grid.fire`'s), the lanes' one program and its shuffle declarations keeping
  the deliveries (`Program.shfl_nil` when they put no attribute on their results);
* `warp_route` (syntax `warpRoute`, elaborator `evalWarpRoute`): on a goal
  `∃ Es, WarpRun L c k t m Es m'`, `WarpRun.of_waits` with the call's named arguments, each premise
  closed from the hypotheses and the terms after `using`, found by their types:
  - every hypothesis `∀ j < N, P j` with `N` the lane count, or a hypothesis's
    `(warpLanes L k).length = N`, lifted to `∀ j ∈ warpLanes L k, P j` (`WarpRoute.liftLanes`);
  - a premise by a term whole or a hypothesis; else, its lane and phase introduced
    (`WarpRoute.introBinders`), by the lane's facts (`WarpRoute.laneFacts`: the hypotheses and
    terms at the lane and phase, their conjuncts through `∧`, pairs and Boolean `&&`, `decide`
    and `==`, and the terms whose premises those fill), whole or one case per phase for a numeral
    `J` (`interval_cases`, `WarpRoute.closeCase`);
  - `hr` at the lane by a lane's run fact through `RunsVia.of_runs`, `RunsVia.of_block` or
    `RunsVia.of_blocks` (`WarpRoute.closeRun`: lengths by facts, labels by `decide`, the end by a
    fact after substituting the run's end memory);
  - `hW` by `WarpRun.shfl_of` (`WarpRoute.closeShfl`): the lanes' program and `shflOk` by facts,
    the keeping premise by a fact or a term or `Program.shfl_nil` backward (`WarpRoute.closeBack`);
  - `hm` and `h0` by facts, their conjuncts or `rfl`, phase by phase.

  The premises it does not close stay goals as `WarpRun.of_waits` states them, but for `hW` when
  `WarpRun.shfl_of` applies and its keeping premise does not close: that premise is the goal.

For every program, launch, contexts, warp, threads, memories, waits and number of phases. Tests in
`MojoProofTest/WarpRoute.lean`; its uses are `warp78` and `warp43`
(`MojoProofTest/GemvWarp.lean`), `skipWarp` and `shflWarp` (`MojoProofTest/SymCanon.lean`).
-/

namespace MojoProof.Sym

section

open MojoProof.LLVM MojoProof.Sem

/-- **A lane's run to its end with no wait, as `WarpRun.of_waits` asks at no phase**: for every
context `c`, final predicate `Q`, thread `t` and memories `m`, `m'`, a run of `t` from `m` to `m'`
(`Runs`) with `Q m'` is a run through no wait (`RunsVia` of the empty list). -/
theorem RunsVia.of_runs {c : Ctx} {Q : Mem → Prop} {t : Thread} {m m' : Mem}
    (h : Runs c t m m') (hQ : Q m') : RunsVia c Q [] t m :=
  ⟨m', h, hQ⟩

/-- **A lane's run through one block of waits, as `WarpRun.of_waits` asks**: for every context
`c`, final predicates `Q`, `Q'` with `Q` implying `Q'`, function `fn`, label `l`, waits `ws` of
length `J`, labels `lbl` that are `l` below `J`, default wait `d`, thread `t` and memory `m`, a
run of `t` from `m` through `ws`, each at `Piece.Wait.via fn l`, to `Q` is one through the `J`
waits `ws.getD i d` at `Piece.Wait.via fn (lbl i)` to `Q'` (`Piece.Wait.map_via`). -/
theorem RunsVia.of_block {c : Ctx} {Q Q' : Mem → Prop} {fn : Func} {l J : Nat}
    {lbl : Nat → Nat} {ws : List Piece.Wait} {d : Piece.Wait} {t : Thread} {m : Mem}
    (h : RunsVia c Q (ws.map (Piece.Wait.via fn l)) t m) (hJ : ws.length = J)
    (hl : ∀ i < J, lbl i = l) (hQ : ∀ m, Q m → Q' m) :
    RunsVia c Q' ((List.range J).map fun i => (ws.getD i d).via fn (lbl i)) t m := by
  subst hJ
  rw [Piece.Wait.map_via (n := 0) (W := fun i => ws.getD i d) (lbl := lbl)
    (fun i hi => by
      simp only [Nat.zero_add, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi,
        Option.getD_some])
    (fun i hi => by rw [Nat.zero_add]; exact hl i hi), ← List.range_eq_range'] at h
  exact RunsVia.imp hQ h

/-- **A lane's run through two blocks of waits, as `WarpRun.of_waits` asks**: for every context
`c`, final predicates `Q`, `Q'` with `Q` implying `Q'`, function `fn`, labels `l₁`, `l₂`, waits
`a` of length `p` and `b` with `J` in all, labels `lbl` that are `l₁` below `p` and `l₂` from `p`
to `J`, default wait `d`, thread `t` and memory `m`, a run of `t` from `m` through `a` at
`Piece.Wait.via fn l₁` and then `b` at `Piece.Wait.via fn l₂` to `Q` is one through the `J` waits
`(a ++ b).getD i d` at `Piece.Wait.via fn (lbl i)` to `Q'` (`Piece.Wait.map_via_append`). -/
theorem RunsVia.of_blocks {c : Ctx} {Q Q' : Mem → Prop} {fn : Func} {l₁ l₂ p J : Nat}
    {lbl : Nat → Nat} {a b : List Piece.Wait} {d : Piece.Wait} {t : Thread} {m : Mem}
    (h : RunsVia c Q (a.map (Piece.Wait.via fn l₁) ++ b.map (Piece.Wait.via fn l₂)) t m)
    (ha : a.length = p) (hJ : (a ++ b).length = J) (hl : ∀ i < J, lbl i = if i < p then l₁ else l₂)
    (hQ : ∀ m, Q m → Q' m) :
    RunsVia c Q' ((List.range J).map fun i => ((a ++ b).getD i d).via fn (lbl i)) t m := by
  rw [Piece.Wait.map_via_append (d := d) ha rfl] at h
  have e : p + b.length = J := by rw [← hJ, List.length_append, ha]
  subst e
  rw [List.map_congr_left (fun i hi => by rw [hl i (List.mem_range.1 hi)])]
  exact RunsVia.imp hQ h

/-- Whether lane `j`'s waits `us` are the shuffles `WarpRun.of_waits` asks for: for each phase
`i < J`, the `i`-th (`List.getD` with default `d`) is a call of the shuffle of mode `mo i` at
position `pos i` with the full mask, the lane's offer `X i j`, lane operand `ofs i` and clamp
`cl i`, delivered what `Grid.fire` delivers from the offers `X i` of the lanes `ls` (`shflVal` at
`shflSource`'s lane). -/
def Piece.Wait.shflOk (ls : List Nat) (mo : Nat → Shfl) (pos : Nat → Nat) (ofs cl : Nat → BitVec 32)
    (X : Nat → Nat → Val) (d : Piece.Wait) (J j : Nat) (us : List Piece.Wait) : Bool :=
  (List.range J).all fun i => decide ((us.getD i d).call = .shfl (mo i) ∧
    (us.getD i d).pos = pos i ∧
    (us.getD i d).args = [.bits 32 (-1), X i j, .bits 32 (ofs i), .bits 32 (cl i)] ∧
    (us.getD i d).dlv.1 =
      some (shflVal ls (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat)))

/-- Whether every shuffle declaration of program `P` (one whose name its intrinsic table maps to
a shuffle) puts no attribute on its result. -/
def _root_.MojoProof.LLVM.Program.shflNil (P : Program) : Bool :=
  P.module.funcs.all fun e => match P.intrinsics.lookup e.name with
    | some (.shfl _) => e.retAttrs.isEmpty
    | _ => true

/-- **A program whose shuffles put no attribute on their results keeps every delivery**: for
every program `P` with `P.shflNil`, layout, memory, mode and delivery `v`, every declaration a
call finds by a name the intrinsic table maps to the shuffle keeps `v` under its result
attributes (`withAttrs`, `withAttrs_mapM_nil`). -/
theorem _root_.MojoProof.LLVM.Program.shfl_nil {P : Program} (hP : P.shflNil = true)
    {l : Layout} {m : Mem} {mo : Shfl} {v : Option Val} :
    ∀ g e, P.module.funcs.find? (·.name == g) = some e →
      P.intrinsics.lookup g = some (.shfl mo) → v.mapM (withAttrs l m e.ret e.retAttrs) = .ok v :=
  fun g e he hg => by
    have h := (Array.all_eq_true_iff_forall_mem.1 hP) e (Array.mem_of_find?_eq_some he)
    have hb : (e.name == g) = true := Array.find?_some (p := fun x : Func => x.name == g) he
    rw [beq_iff_eq.1 hb, hg] at h
    rw [List.isEmpty_iff.1 h]
    exact withAttrs_mapM_nil _ _ _ _

/-- **`WarpRun.of_waits`'s shuffle premise from each lane's `Piece.Wait.shflOk`**: for every
launch `L`, contexts `c`, warp `k`, number `J` of phases, program `P` every lane's context runs,
modes `mo`, positions `pos`, lane operands `ofs`, clamps `cl`, offers `X`, memories `M` (phase
`i`'s after its last lane), default wait `d` and lanes' waits `us`: if every lane's waits pass
`shflOk` and `P`'s shuffle declarations keep the deliveries (`hK`, e.g. `Program.shfl_nil`),
every lane's `i`-th wait, `i < J`, is the
shuffle of mode `mo i` at lane 0's position, with the full mask, the lane's offer `X i j` and word
lane and clamp operands, delivered what `Grid.fire` computes from the lanes' offers. -/
theorem WarpRun.shfl_of {L : Launch} {c : Nat → Ctx} {k J : Nat} {P : Program}
    {mo : Nat → Shfl} {pos : Nat → Nat} {ofs cl : Nat → BitVec 32} {X : Nat → Nat → Val}
    {M : Nat → Mem} {d : Piece.Wait} {us : Nat → List Piece.Wait}
    (hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = P)
    (h : ∀ j ∈ warpLanes L k, Piece.Wait.shflOk (warpLanes L k) mo pos ofs cl X d J j (us j) = true)
    (hK : ∀ i < J, ∀ j ∈ warpLanes L k, ∀ g e, P.module.funcs.find? (·.name == g) = some e →
      P.intrinsics.lookup g = some (.shfl (mo i)) →
      (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat))).mapM
        (withAttrs P.layout (M i) e.ret e.retAttrs) =
        .ok (some (shflVal (warpLanes L k) (X i)
          (shflSource (mo i) j (ofs i).toNat (cl i).toNat)))) :
    ∀ i < J, ∀ j ∈ warpLanes L k, ((us j).getD i d).call.intr = .shfl (mo i) ∧
      ((us j).getD i d).pos = ((us 0).getD i d).pos ∧ ∃ Mk Bv Cv b cl,
        ((us j).getD i d).args = [Mk, X i j, Bv, Cv] ∧ Mk.word? = some (2 ^ 32 - 1) ∧
        Bv.word? = some b ∧ Cv.word? = some cl ∧
        ∀ g e, (c (k + j)).prog.module.funcs.find? (·.name == g) = some e →
          (c (k + j)).prog.intrinsics.lookup g = some (.shfl (mo i)) →
          (some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j b cl))).mapM
            (withAttrs (c k).prog.layout (M i) e.ret e.retAttrs) =
            .ok ((us j).getD i d).dlv.1 := by
  intro i hi j hj
  have hW : ∀ j ∈ warpLanes L k, ((us j).getD i d).call = .shfl (mo i) ∧
      ((us j).getD i d).pos = pos i ∧
      ((us j).getD i d).args = [.bits 32 (-1), X i j, .bits 32 (ofs i), .bits 32 (cl i)] ∧
      ((us j).getD i d).dlv.1 =
        some (shflVal (warpLanes L k) (X i) (shflSource (mo i) j (ofs i).toNat (cl i).toNat)) :=
    fun j hj => by
      have h := h j hj
      simp only [Piece.Wait.shflOk, List.all_eq_true, List.mem_range, decide_eq_true_eq] at h
      exact h i hi
  have h0 : 0 ∈ warpLanes L k := mem_warpLanes.2 (List.length_pos_of_mem hj)
  obtain ⟨hcall, hpos, hargs, hdlv⟩ := hW j hj
  obtain ⟨-, hpos0, -⟩ := hW 0 h0
  refine ⟨congrArg Coll.intr hcall, hpos.trans hpos0.symm, _, _, _, (ofs i).toNat, (cl i).toNat,
    hargs, rfl, rfl, rfl, fun g e he hg => ?_⟩
  have hk : (c k).prog = P := hP 0 h0
  rw [hk, hdlv]
  rw [hP j hj] at he hg
  exact hK i hi j hj g e he hg

end

open Lean Meta Elab Tactic

namespace WarpRoute
/-- The launch and first thread of a goal `∃ Es, WarpRun L c k t m Es m'`. -/
def warpOf? (e : Expr) : MetaM (Option (Expr × Expr)) := do
  let e ← instantiateMVars e
  let_expr Exists _ p := e | return none
  let .lam _ _ b _ := p | return none
  unless b.isAppOfArity ``WarpRun 7 do return none
  let L := b.getArg! 0
  let k := b.getArg! 2
  if L.hasLooseBVars || k.hasLooseBVars then return none
  return some (L, k)

/-- `j < b`'s bound `b` when `ty` is `∀ j : Nat, j < b → _`. -/
def ltBound? (ty : Expr) : Option Expr := do
  let .forallE _ dom body _ := ty | none
  guard (dom.isConstOf ``Nat)
  let .forallE _ dom2 _ _ := body | none
  guard (dom2.isAppOfArity ``LT.lt 4)
  guard (dom2.getArg! 2 == .bvar 0)
  let b := dom2.getArg! 3
  guard (!b.hasLooseBVars)
  return b

/-- Every hypothesis `h : ∀ j < b, P j` whose bound `b` is the lane count of warp `k` of `L`, or
is `N` with a hypothesis `a = N` whose `a` is the lane count, becomes `h : ∀ j ∈ warpLanes L k,
P j`, under the same name. -/
def liftLanes (L k : Expr) : TacticM Unit := withMainContext do
  let len ← mkAppM ``List.length #[← mkAppM ``warpLanes #[L, k]]
  let mut eqs : Array (Expr × Expr) := #[]
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    if let some (t, a, b) := (← instantiateMVars d.type).eq? then
      if t.isConstOf ``Nat then
        if ← isDefEq a len then eqs := eqs.push (b, d.toExpr)
  let mut news : Array (LocalDecl × Expr) := #[]
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let ty ← instantiateMVars d.type
    let some b := ltBound? ty | continue
    let hN? ← if ← isDefEq b len then pure (some none) else
      pure <| (← eqs.findM? fun (n, _) => isDefEq n b).map fun (_, h) => some h
    let some hN := hN? | continue
    let v ← withLocalDeclD `j (mkConst ``Nat) fun j => do
      let mem ← mkAppM ``Membership.mem #[← mkAppM ``warpLanes #[L, k], j]
      withLocalDeclD `hj mem fun hj => do
        let p ← mkAppM ``Iff.mp #[← mkAppOptM ``mem_warpLanes #[L, k, j], hj]
        let p ← match hN with
          | none => pure p
          | some h => do
            let mot ← withLocalDeclD `x (mkConst ``Nat) fun x => do
              mkLambdaFVars #[x] (← mkAppM ``LT.lt #[j, x])
            mkEqNDRec mot p h
        mkLambdaFVars #[j, hj] (mkApp2 d.toExpr j p)
    news := news.push (d, v)
  for (d, v) in news do
    let g ← getMainGoal
    let g ← g.assert d.userName (← inferType v) v
    let g ← g.tryClear d.fvarId
    let (_, g) ← g.intro1P
    replaceMainGoal [g]

/-- `n` when `e` is the numeral `n`. -/
def numeral? (e : Expr) : MetaM (Option Nat) := do
  let e ← instantiateMVars e
  if let some n := e.nat? then return some n
  if let some n := e.rawNatLit? then return some n
  return none

/-- Whether `a` and `b` can be equal by their heads to depth `n`: two constants, local variables
or literals at the head of each are the same, with as many arguments, which agree to depth
`n - 1`; a binder `∀` agrees only with a binder or a metavariable; a metavariable or any other
head agrees with all. A cheap filter before `isDefEq`, which would unfold a definition at the
head of one side to look for the other's. -/
def shapeOk : Nat → Expr → Expr → Bool
  | 0, _, _ => true
  | n + 1, a, b =>
    let a := a.consumeMData.headBeta
    let b := b.consumeMData.headBeta
    let args := fun (_ : Unit) => a.getAppNumArgs == b.getAppNumArgs &&
      (a.getAppArgs.zip b.getAppArgs).all fun (u, v) => shapeOk n u v
    let rigid := fun (e : Expr) => match e.getAppFn.consumeMData with
      | .const .. | .fvar .. | .lit .. => true
      | _ => false
    match a.getAppFn.consumeMData, b.getAppFn.consumeMData with
    | .const x _, .const y _ => x == y && args ()
    | .fvar x, .fvar y => x == y && args ()
    | .lit x, .lit y => x == y
    | .const .., .fvar .. => false
    | .fvar .., .const .. => false
    | .const .., .lit .. => false
    | .lit .., .const .. => false
    | .forallE .., .forallE .. => true
    | .forallE .., _ => !rigid b
    | _, .forallE .. => !rigid a
    | _, _ => true

/-- `e` applied to the lane `j` and `hj : j ∈ warpLanes L k` when it takes them, or to `j` alone
when it takes a number and no premise after it; then, if it takes them, to the phase `i` and its
bound `hi`. None when it takes no lane. -/
def atLane (e j hj : Expr) (ph : Option (Expr × Expr)) : MetaM (Option Expr) := do
  let .forallE _ dom body _ ← whnfR (← inferType e) | return none
  unless dom.isConstOf ``Nat do return none
  let mut v := mkApp e j
  if let .forallE _ dom2 _ _ := body then
    if ← isDefEq (dom2.instantiate1 j) (← inferType hj) then v := mkApp v hj
    else if ← isProp (dom2.instantiate1 j) then return none
  if let some (i, hi) := ph then
    if let .forallE _ dom body _ ← whnfR (← inferType v) then
      if dom.isConstOf ``Nat then
        v := mkApp v i
        if let .forallE _ dom2 _ _ := body then
          if ← isDefEq (dom2.instantiate1 i) (← inferType hi) then v := mkApp v hi
  return some v

/-- `e` applied to the phase `i` and its bound `hi` when it takes them. -/
def atPhase (e : Expr) (ph : Option (Expr × Expr)) : MetaM Expr := do
  let some (i, hi) := ph | return e
  let .forallE _ dom body _ ← whnfR (← inferType e) | return e
  unless dom.isConstOf ``Nat do return e
  let v := mkApp e i
  if let .forallE _ dom2 _ _ := body then
    if ← isDefEq (dom2.instantiate1 i) (← inferType hi) then return mkApp v hi
  return v

/-- The proof of `b = true` that `e : a = true` gives, through `&&` (`Bool.and_eq_true`),
`decide` (`of_decide_eq_true`) and `==` (`eq_of_beq`), unfolding `a`'s head definition once if
that shows one of them. -/
partial def boolStep (e a : Expr) : MetaM (Option Expr) := do
  let a ← whnfR (← instantiateMVars a)
  if a.isAppOfArity ``and 2 then
    return some (← mkAppM ``Eq.mp #[← mkAppM ``Bool.and_eq_true #[a.getArg! 0, a.getArg! 1], e])
  if a.isAppOfArity ``Decidable.decide 2 then
    return some (← mkAppM ``of_decide_eq_true #[e])
  if a.isAppOfArity ``BEq.beq 4 then
    try return some (← mkAppM ``LawfulBEq.eq_of_beq #[e]) catch _ => return none
  let .const n _ := a.getAppFn | return none
  if n == ``and || n == ``Decidable.decide || n == ``BEq.beq then return none
  let some a' ← unfoldDefinition? a | return none
  let a' ← whnfR a'.headBeta
  unless a'.isAppOfArity ``and 2 || a'.isAppOfArity ``Decidable.decide 2 do return none
  let e' ← mkExpectedTypeHint e (← mkEq a' (mkConst ``Bool.true))
  boolStep e' a'

/-- The proofs of the conjuncts of `e`'s type, through `∧`, equations of pairs and Boolean
conjunctions `(a && b) = true` (`boolStep`). -/
partial def parts (e : Expr) : MetaM (Array Expr) := do
  let ty ← whnfR (← instantiateMVars (← inferType e))
  if ty.isAppOfArity ``And 2 then
    return (← parts (← mkAppM ``And.left #[e])) ++ (← parts (← mkAppM ``And.right #[e]))
  if let some (_, a, b) := ty.eq? then
    if a.isAppOfArity ``Prod.mk 4 && b.isAppOfArity ``Prod.mk 4 then
      return ← parts (← mkAppM ``Prod.mk.inj #[e])
    if b.isConstOf ``Bool.true then
      if let some e' ← boolStep e a then return #[e] ++ (← parts e')
  return #[e]

/-- `g` closed by one of `ps` at reducible transparency, conjunctions split. -/
partial def closeByParts (ps : Array Expr) (g : MVarId) : MetaM Bool := g.withContext do
  let ty ← whnfR (← instantiateMVars (← g.getType))
  if ty.isAppOfArity ``And 2 then
    let a ← mkFreshExprMVar (ty.getArg! 0)
    let b ← mkFreshExprMVar (ty.getArg! 1)
    unless ← closeByParts ps a.mvarId! do return false
    unless ← closeByParts ps b.mvarId! do return false
    g.assign (← mkAppM ``And.intro #[a, b])
    return true
  for p in ps do
    if ← withReducible (isDefEq (← inferType p) ty) then
      g.assign p
      return true
  return false

/-- `g` closed by one of the facts `fs` or their conjuncts `ps` whose type has `g`'s shape to
depth `n` (`shapeOk`), at reducible and then default transparency, or as a conjunction of them
(`closeByParts`). -/
def fillBy (n : Nat) (fs ps : Array Expr) (g : MVarId) : MetaM Bool := g.withContext do
  let ty ← instantiateMVars (← g.getType)
  for t in [TransparencyMode.reducible, .default] do
    for f in fs ++ ps do
      let ft ← instantiateMVars (← inferType f)
      unless shapeOk n ft ty do continue
      let s ← saveState
      if ← withTransparency t (isDefEq ft ty) then
        g.assign f
        return true
      s.restore
  let s ← saveState
  if ← closeByParts ps g then return true
  s.restore
  return false

/-- `e`'s leading implicit binders and premises as fresh metavariables, up to its first explicit
binder that is not a proposition: the instance and the metavariables. -/
partial def openPrems (e : Expr) : MetaM (Expr × Array Expr) := do
  let .forallE _ dom _ bi ← whnfR (← inferType e) | return (e, #[])
  if bi.isExplicit && !(← isProp dom) then return (e, #[])
  let m ← mkFreshExprMVar dom
  let (v, ms) ← openPrems (mkApp e m)
  return (v, #[m] ++ ms)

/-- The metavariables `ms` that are propositions filled by the facts `fs` and their conjuncts
`ps` (`fillBy`), those whose types have no metavariable first; instances synthesized. Whether
every one of `ms` is then assigned. -/
def fillPrems (fs ps ms : Array Expr) : MetaM Bool := do
  let mut left := ms.map (·.mvarId!)
  while true do
    left ← left.filterM fun m => return !(← m.isAssigned)
    let props ← left.filterM fun m => do isProp (← m.getType)
    if props.isEmpty then break
    let ready ← props.filterM fun m => return !(← instantiateMVars (← m.getType)).hasExprMVar
    let m := if ready.isEmpty then props[0]! else ready[0]!
    unless ← fillBy 3 fs ps m do return false
  for m in left do
    unless ← m.isAssigned do
      let ty ← instantiateMVars (← m.getType)
      if (← isClass? ty).isSome then
        try m.assign (← synthInstance ty) catch _ => return false
  for m in ms do
    unless ← m.mvarId!.isAssigned do return false
  return true

/-- A using lemma `e` forward: its premises filled from the facts (`openPrems`, `fillPrems`);
its instance when every binder is assigned. -/
def chain (fs ps : Array Expr) (e : Expr) : MetaM (Option Expr) := do
  let s ← saveState
  let (v, ms) ← openPrems e
  if ms.isEmpty then return none
  if ← fillPrems fs ps ms then
    let v ← instantiateMVars v
    unless v.hasExprMVar do return some v
  s.restore
  return none

/-- A using term, elaborated with its metavariables abstracted, opened afresh at each use. -/
def openUse (r : AbstractMVarsResult) : MetaM Expr := do
  let (_, _, e) ← openAbstractMVarsResult r
  return e

/-- The facts at the lane `j` and phase `ph`: every hypothesis and using term taken at the lane
(`atLane`) or, if it takes none and is a proposition, whole; then, in two rounds, every using
lemma whose premises the facts and their conjuncts fill (`chain`), taken at the phase. -/
def laneFacts (us : Array AbstractMVarsResult) (j hj : Expr) (ph : Option (Expr × Expr)) :
    TacticM (Array Expr) := withMainContext do
  let mut fs : Array Expr := #[]
  let add := fun (fs : Array Expr) (e : Expr) => do
    if let some v ← atLane e j hj ph then return fs.push v
    let ty ← instantiateMVars (← inferType e)
    if ty.isForall || !(← isProp ty) then return fs
    return fs.push e
  for d in ← getLCtx do
    unless d.isImplementationDetail do fs ← add fs d.toExpr
  for r in us do
    let e ← openUse r
    if !(← instantiateMVars e).hasExprMVar then fs ← add fs e
  let mut ps ← fs.foldlM (fun acc f => return acc ++ (← parts f)) #[]
  let mut done : Array Nat := #[]
  for _ in [0, 1] do
    for h : n in [0:us.size] do
      if done.contains n then continue
      let e ← openUse us[n]
      let some v ← chain fs ps e | continue
      let v ← atPhase v ph
      fs := fs.push v
      ps := ps ++ (← parts v)
      done := done.push n
  return fs

/-- `g`, an equation, by a fact or a conjunct (`fillBy`) or, if it has no metavariable, by
`MVarId.refl`. -/
def closeEq (fs ps : Array Expr) (g : MVarId) : MetaM Bool := do
  if ← fillBy 2 fs ps g then return true
  if (← instantiateMVars (← g.getType)).hasExprMVar then return false
  let s ← saveState
  try g.refl; return true catch _ => s.restore; return false

/-- `g : ∀ m, Q m → Q' m`: by `fun _ h => h` at reducible transparency or, with `h : m = E`
substituted, `Q' E` by `closeEq`. -/
def closeImp (fs ps : Array Expr) (g : MVarId) : MetaM Bool := do
  let s ← saveState
  try
    let (fvs, g') ← g.introN 2
    g'.withContext do
      let h := mkFVar fvs[1]!
      if ← withReducible (isDefEq (← inferType h) (← g'.getType)) then
        g'.assign h
        return true
      let g' ← g'.replaceLocalDeclDefEq fvs[1]! (← whnfR (← inferType h))
      let g' ← Lean.Meta.subst g' fvs[1]!
      let g' ← g'.withContext do g'.replaceTargetDefEq (← whnfR (← g'.getType))
      if ← closeEq fs ps g' then return true
      s.restore
      return false
  catch _ =>
    s.restore
    return false

/-- The lemma that turns a lane's run `ft` into `WarpRun.of_waits`'s `hr` at the lane, by the
run's form: `RunsVia.of_blocks` for waits `a.map _ ++ b.map _`, `RunsVia.of_block` for
`ws.map _`, `RunsVia.of_runs` for a run with no wait (`Runs`). -/
def runLemma? (ft : Expr) : Option Name :=
  if ft.isAppOfArity ``Runs 4 then some ``RunsVia.of_runs
  else if ft.isAppOfArity ``RunsVia 5 then
    let ws := ft.getArg! 2
    if ws.isAppOfArity ``HAppend.hAppend 6 then some ``RunsVia.of_blocks
    else if ws.isAppOfArity ``List.map 4 then some ``RunsVia.of_block
    else none
  else none

/-- `g`, a lane's run `RunsVia c Q ws t m` as `WarpRun.of_waits` asks, by a fact that is a lane's
run and its `runLemma?`: the lemma's run `h` the fact (at reducible transparency), its
conclusion `g`, its lengths `ha`, `hJ` by facts (`fillBy`), its labels `hl` by `decide`, its
final predicate `hQ` by `closeImp` or `closeEq`. -/
def closeRun (fs ps : Array Expr) (g : MVarId) : TacticM Bool := g.withContext do
  let ty ← instantiateMVars (← g.getType)
  unless ty.isAppOf ``RunsVia do return false
  for f in fs do
    let ft ← instantiateMVars (← inferType f)
    let some n := runLemma? ft | continue
    let s ← saveState
    let ok ← try
      let lem ← mkConstWithFreshMVarLevels n
      let lty ← inferType lem
      let (ms, _, concl) ← forallMetaTelescope lty
      let names ← forallTelescope lty fun xs _ => xs.mapM fun x => x.fvarId!.getUserName
      let byName := fun (s : String) =>
        (names.zip ms).find? (·.1 == Name.mkSimple s) |>.map (·.2)
      let some h := byName "h" | throwError "no run"
      unless ← withReducible (isDefEq (← inferType h) ft) do throwError "no run"
      h.mvarId!.assign f
      unless ← isDefEq concl ty do throwError "no run"
      for nm in ["ha", "hJ"] do
        if let some m := byName nm then
          unless ← fillBy 2 fs ps m.mvarId! do throwError "no length"
      if let some m := byName "hl" then
        setGoals [m.mvarId!]
        evalTactic (← `(tactic| decide))
      if let some m := byName "hQ" then
        let mt ← whnfR (← instantiateMVars (← inferType m))
        let ok ← if mt.isForall then closeImp fs ps m.mvarId! else
          closeEq fs ps m.mvarId!
        unless ok do throwError "no end"
      for m in ms do
        unless ← m.mvarId!.isAssigned do throwError "left"
      g.assign (← instantiateMVars (mkAppN lem ms))
      pure true
    catch _ => pure false
    if ok then return true
    s.restore
  return false

/-- The lemmas `closeBack` tries after the using terms: `Program.shfl_nil`. -/
def backLemmas : List Name := [``MojoProof.LLVM.Program.shfl_nil]

/-- The conclusion of `ty` after all its binders, none unfolded. -/
def finalConcl (ty : Expr) : MetaM Expr :=
  forallTelescope ty fun _ b => pure b

/-- `g` by a using lemma or one of `backLemmas` backward, one whose conclusion after its binders
has the shape of `g`'s (`shapeOk` to depth 2): `MVarId.apply`, each premise by a fact
(`fillBy`). -/
def closeBack (fs ps : Array Expr) (us : Array AbstractMVarsResult) (g : MVarId) :
    MetaM Bool := do
  let cands : Array (MetaM Expr) := us.map openUse ++
    (backLemmas.toArray.map fun n => mkConstWithFreshMVarLevels n)
  let gc ← finalConcl (← instantiateMVars (← g.getType))
  for mk in cands do
    let s ← saveState
    try
      let e ← mk
      unless shapeOk 2 (← finalConcl (← instantiateMVars (← inferType e))) gc do
        throwError "shape"
      let gs ← g.apply e
      let mut ok := true
      for g' in gs do
        if ← g'.isAssigned then continue
        unless ← isProp (← g'.getType) do continue
        unless ← fillBy 3 fs ps g' do ok := false; break
      if ok then
        if ← gs.allM fun g' => g'.isAssigned then return true
    catch _ => pure ()
    s.restore
  return false

/-- One case of a premise, by the lane's facts `fs` (their names): a lane's run `RunsVia` by a
fact (`shapeOk` to depth 1) at reducible transparency, at default transparency if the fact's
waits are a list literal, or by `closeRun`; any other goal by a fact (`shapeOk` to depth 2, at
reducible and then default transparency), a hypothesis at reducible transparency, the facts'
conjuncts (`closeByParts`), `MVarId.refl` if it has no metavariable, or a using lemma backward
(`closeBack`). -/
def closeCase (fs : Array Name) (us : Array AbstractMVarsResult) : TacticM Bool :=
    withMainContext do
  let g ← getMainGoal
  let lctx ← getLCtx
  let facts := fs.filterMap fun n => (lctx.findFromUserName? n).map (·.toExpr)
  let ty ← instantiateMVars (← g.getType)
  let run := ty.isAppOf ``RunsVia
  let lit := fun (ft : Expr) => ft.isAppOfArity ``RunsVia 5 &&
    ((ft.getArg! 2).isAppOf ``List.cons || (ft.getArg! 2).isAppOf ``List.nil)
  for t in [TransparencyMode.reducible, .default] do
    for f in facts.reverse do
      let ft ← instantiateMVars (← inferType f)
      unless shapeOk (if run then 1 else 2) ft ty do continue
      if run && t == .default && !lit ft then continue
      let s ← saveState
      if ← withTransparency t (isDefEq ft ty) then
        g.assign f
        return true
      s.restore
  let ps ← facts.foldlM (fun acc f => return acc ++ (← parts f)) #[]
  if run then return ← closeRun facts ps g
  if ← withReducible g.assumptionCore then return true
  if ← closeByParts ps g then return true
  if !ty.hasExprMVar then
    let s ← saveState
    try g.refl; return true catch _ => s.restore
  closeBack facts ps us g

/-- The premise's binders `∀ i < n` and `∀ j ∈ warpLanes L k`, introduced under fresh names; the
lane, and the phase with its bound when `n` is a numeral. -/
def introBinders : TacticM (Option (Expr × Expr) × Option (Name × Expr × Expr)) := do
  let mut lane := none
  let mut phase := none
  repeat
    let g ← getMainGoal
    let ty ← instantiateMVars (← g.getType)
    let .forallE _ dom body _ := ty | break
    unless dom.isConstOf ``Nat do break
    let .forallE _ _ _ _ := body | break
    let nx ← mkFreshUserName `x
    let nh ← mkFreshUserName `h
    let (fvs, g) ← g.introN 2 [nx, nh]
    replaceMainGoal [g]
    let x := mkFVar fvs[0]!
    let h := mkFVar fvs[1]!
    let ht ← g.withContext do whnfR (← instantiateMVars (← inferType h))
    if ht.isAppOfArity ``LT.lt 4 then
      if (← numeral? (ht.getArg! 3)).isSome then phase := some (nx, x, h)
    else if ht.isAppOfArity ``Membership.mem 5 then
      lane := some (x, h)
  return (lane, phase)

/-- The using terms elaborated in the main goal's context, their metavariables abstracted, and
those that do not elaborate without an expected type and without an error. -/
def elabUsing (es : Array Term) : TacticM (Array AbstractMVarsResult × Array Term) :=
  withMainContext do
    let mut rs := #[]
    let mut raw := #[]
    for e in es do
      let s ← saveState
      try
        let v ← withoutRecover <| Term.withoutErrToSorry do
          let v ← Tactic.elabTerm e none
          Term.synthesizeSyntheticMVarsNoPostponing
          instantiateMVars v
        if v.hasSorry then throwError "the term elaborates with an error"
        rs := rs.push (← abstractMVars v)
      catch _ => raw := raw.push e
      s.restore
    return (rs, raw)

/-- The number of leading binders of `ty`, none unfolded. -/
def arity (ty : Expr) : MetaM Nat :=
  forallTelescope ty fun xs _ => pure xs.size

/-- `g` by a using term whole: one of `raw` by `exact`, or one of `us` whose type has `g`'s
binders and the shape of its conclusion (`shapeOk` to depth 2), by `isDefEq` with every
metavariable of the term assigned. -/
def closeWhole (us : Array AbstractMVarsResult) (raw : Array Term) : TacticM Bool := do
  let s ← saveState
  for e in raw do
    try
      withoutRecover <| evalTactic (← `(tactic| exact $e))
      if (← getUnsolvedGoals).isEmpty then return true
      s.restore
    catch _ => s.restore
  withMainContext do
    let g ← getMainGoal
    let ty ← instantiateMVars (← g.getType)
    let n ← arity ty
    let gc ← finalConcl ty
    for r in us do
      let e ← openUse r
      let et ← instantiateMVars (← inferType e)
      unless (← arity et) == n && shapeOk 2 (← finalConcl et) gc do continue
      if ← isDefEq et ty then
        let e ← instantiateMVars e
        unless e.hasExprMVar do
          g.assign e
          return true
      s.restore
    return false

/-- One premise of `WarpRun.of_waits`: by a using term whole (`closeWhole`) or a hypothesis; or,
its binders introduced, its lane's facts taken (`laneFacts`), the premise whole by them or, split
into its phases (`interval_cases`), each case by `closeCase`. Whether it closed; if not, the
premise is as it was. -/
def closePremise (us : Array AbstractMVarsResult) (raw : Array Term) : TacticM Bool := do
  let s ← saveState
  if ← closeWhole us raw then return true
  if ← withMainContext do withReducible (← getMainGoal).assumptionCore then return true
  try
    let (lane, phase) ← introBinders
    let mut fs := #[]
    if let some (j, hj) := lane then
      let vs ← laneFacts us j hj (phase.map fun (_, i, hi) => (i, hi))
      for v in vs do
        let n ← mkFreshUserName `f
        let g ← getMainGoal
        let g ← g.assert n (← g.withContext (inferType v)) v
        let (_, g) ← g.intro1P
        replaceMainGoal [g]
        fs := fs.push n
    let s' ← saveState
    if ← closeCase fs us then
      if (← getUnsolvedGoals).isEmpty then return true
    s'.restore
    if let some (nx, _, _) := phase then
      withoutRecover <| evalTactic (← `(tactic| interval_cases $(mkIdent nx)))
    else
      s.restore
      return false
    for g in ← getUnsolvedGoals do
      setGoals [g]
      unless ← closeCase fs us do
        s.restore
        return false
    if (← getUnsolvedGoals).isEmpty then return true
    s.restore
    return false
  catch _ =>
    s.restore
    return false

/-- `WarpRun.of_waits`'s shuffle premise by `WarpRun.shfl_of`: its programs' premise and its lanes'
`Piece.Wait.shflOk` by `closePremise`, then its keeping premise, left a goal if `closePremise`
does not close it. Whether it applied; if not, the premise is as it was. -/
def closeShfl (us : Array AbstractMVarsResult) (raw : Array Term) : TacticM Bool := do
  let s ← saveState
  try
    let g ← getMainGoal
    let gs ← g.apply (← mkConstWithFreshMVarLevels ``WarpRun.shfl_of)
    let props ← gs.filterM fun g => do isProp (← g.getType)
    let [hP, h, hK] := props | s.restore; return false
    for p in [hP, h] do
      setGoals [p]
      unless ← closePremise us raw do s.restore; return false
    setGoals [hK]
    let left ← if ← closePremise us raw then pure [] else getUnsolvedGoals
    setGoals left
    return true
  catch _ =>
    s.restore
    return false

end WarpRoute

/-- **The glue of a warp's run through its shuffles**: on a goal `∃ Es, WarpRun L c k t m Es m'`,
`warp_route (J := …) (W := …) (M := …) … using e₁, …` lifts every hypothesis `∀ j < N, P j`,
with `N` the warp's lane count or a hypothesis's `(warpLanes L k).length = N`, to
`∀ j ∈ warpLanes L k, P j`, refines `WarpRun.of_waits` with the named arguments, and closes each
of its premises that it can from the hypotheses and the terms `eᵢ`, by their types: the lanes'
runs from a lane's run (`Runs`, or `RunsVia` through `ws.map _` or `a.map _ ++ b.map _`) by
`RunsVia.of_runs`, `RunsVia.of_block` or `RunsVia.of_blocks`; the shuffles by `WarpRun.shfl_of`
from the lanes' program and `Piece.Wait.shflOk`, its keeping premise by a fact or
`Program.shfl_nil`; the waits' memories and the phases' starts by facts, their conjuncts or `rfl`,
one case per phase when the number of phases is a numeral (`interval_cases`). The premises it
does not close stay goals as `WarpRun.of_waits` states them; the shuffles' stays
`WarpRun.shfl_of`'s keeping premise when the rest of that lemma's premises close. -/
syntax (name := warpRoute) "warp_route" (" (" ident " := " term ")")* (" using " term,+)?
  : tactic

open WarpRoute in
/-- The elaborator of `warp_route`: the goal's launch and warp (`WarpRoute.warpOf?`), the lanes'
hypotheses lifted (`WarpRoute.liftLanes`), `WarpRun.of_waits` refined with the named arguments,
the terms after `using` elaborated (`WarpRoute.elabUsing`), then the shuffles' premise by
`WarpRoute.closeShfl` and every other premise, and the shuffles' if that does not apply, by
`WarpRoute.closePremise`; the premises left open are the goals after it. It fails, with a
message, on a goal not of the form `∃ Es, WarpRun L c k t m Es m'`. -/
@[tactic warpRoute] def evalWarpRoute : Tactic := fun stx => do
  match stx with
  | `(tactic| warp_route $[($xs := $vs)]* $[using $es,*]?) =>
    let es : Array Term := match es with | some es => es.getElems | none => #[]
    let args : Array Syntax := (xs.zip vs).map fun (x, v) =>
      mkNode ``Lean.Parser.Term.namedArgument #[mkAtom "(", x, mkAtom ":=", v, mkAtom ")"]
    let hole ← `(?_)
    let app : Term := ⟨mkNode ``Lean.Parser.Term.app
      #[mkIdent ``WarpRun.of_waits, mkNullNode (args ++ #[hole.raw, hole, hole, hole])]⟩
    let some (L, k) ← withMainContext do warpOf? (← getMainTarget)
      | throwError "warp_route: the goal is not `∃ Es, WarpRun L c k t m Es m'`"
    liftLanes L k
    evalTactic (← `(tactic| refine $app))
    let (us, raw) ← elabUsing es
    let mut left := #[]
    let mut idx := 0
    for g in ← getUnsolvedGoals do
      setGoals [g]
      if idx == 1 then
        if ← closeShfl us raw then
          left := left ++ (← getUnsolvedGoals)
          idx := idx + 1
          continue
      unless ← closePremise us raw do left := left ++ (← getUnsolvedGoals)
      idx := idx + 1
    setGoals left.toList
  | _ => throwUnsupportedSyntax

end MojoProof.Sym
