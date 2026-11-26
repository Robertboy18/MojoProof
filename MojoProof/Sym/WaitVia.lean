import MojoProof.Sym.OblSeg
import MojoProof.Sym.SegTrace

/-!
# A segment's wait as `Piece.Wait.via`

`RunsVia.of_through` and `RunsVia.of_wait` take a wait's predicate as `hP`: every memory the
segment's effects run to and every list of values its argument terms evaluate to meet it. For the
predicate of `Piece.Wait.via` (the position, collective, argument values and memory of a wait `w`,
the form `RunsVia.of_fires` concludes and `WarpRun.of_waits` takes):

* `Piece.Wait.via_of`: `hP` from the arguments' values `w.args` and the effects' memory `w.mem`;
* `RunsVia.of_through_via`: `RunsVia.of_through` with the wait `w.via fn lbl` first;
* `SVal.mapM_shfl`: the values of a shuffle's four argument terms (a word, a term and two words);
* `RunsVia.imp_head`: a run's first wait with a weaker predicate;
* `RunsVia.imp`: a run with a weaker final predicate;
* `RunsVia.pin`: the memory at a wait after the waits `ws₁` is one memory for every value `x` the
  later waits, the wait's delivery and the final predicate depend on (`ToWait.det`), so a run
  whose wait states no memory is one whose wait states that memory, chosen before `x`;
* `obl_exact` (syntax `oblExact`, elaborator `evalOblExact`): closes a goal `e = x` whose left
  side `obl_have` evaluates.

For every program, context, function, block, wait, valuation, node values, thread and memory.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A wait's predicate from its segment's values.** For every function `fn`, block `lbl`, wait
`w`, valuation `V`, node values `vs`, collective `cl`, argument terms `ts`, effects `es` and
position `q`: if `q` is `w.pos`, `cl` is `w.call`, the terms evaluate to `w.args` and the effects
run to `w.mem`, then every thread at `fn`'s block `lbl` and position `q`, calling `cl`'s intrinsic
with the terms' values on the effects' memory, meets `w.via fn lbl`'s predicate. -/
theorem Piece.Wait.via_of {fn : Func} {lbl : Nat} {w : Piece.Wait} {V : Valuation}
    {vs : List (Except Fault Val)} {cl : Coll} {ts : List SVal} {es : List SEff} {q : Nat}
    (hq : q = w.pos) (hc : cl = w.call) (hx : ts.mapM (·.eval V vs) = .ok w.args)
    (hm : SEff.run V vs es = .ok w.mem) :
    ∀ u me xs, u.at = some (fn.name, lbl, q) → SEff.run V vs es = .ok me →
      ts.mapM (·.eval V vs) = .ok xs → (w.via fn lbl).1 u cl.intr xs me := by
  intro u me xs hu hme hxs
  subst hq hc
  exact ⟨hu, rfl, Except.ok.inj (hxs.symm.trans hx), Except.ok.inj (hme.symm.trans hm)⟩

/-- **A wait of a block's segments, as `Piece.Wait.via`**: `RunsVia.of_through` with the predicate
of wait `W` (`Piece.Wait.via_of`). For every context, block, frames below, summary after the last
segment, segment `S` and segments after it, deliveries `w`, thread, memory, frame, function,
position, `alloca` blocks, valuation, wait `W`, predicate and later waits: if `S`'s obligations
hold, the call's position is `W.pos`, its collective `W.call`, its arguments evaluate to `W.args`
and its effects run to `W.mem`, and the first delivery is `W.dlv`, the thread runs with `W`'s wait
first, given the run of every frame resumed after the call. -/
theorem RunsVia.of_through_via {c : Ctx} {lbl : Nat} {rest : List Frame} {L : Summary}
    {S : SegSummary} {Ss : List SegSummary} {w w' : Nat → Option Val × Mem} {t : Thread} {m : Mem}
    {f : Frame} {fn : Func} {p : Nat} {al : List Nat} {V : Valuation} {W : Piece.Wait}
    {Q : Mem → Prop} {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (h : Seg.Through c lbl rest L (S :: Ss) w t m f) (hV : Valuation.entry c t.k m f = V)
    (hfn : f.fn = fn) (hp : f.pc = p) (ha : f.allocas = al) (hw : w 0 = W.dlv)
    (hw' : (fun i => w (i + 1)) = w')
    (hds : ∀ x ∈ S.toSummary.obls, x.Holds V (vals V S.toSummary.nodes))
    (hq : p + S.len = W.pos) (hc : S.call = W.call)
    (hx : S.args.mapM (·.eval V (vals V S.toSummary.nodes)) = .ok W.args)
    (hm : SEff.run V (vals V S.toSummary.nodes) S.effs = .ok W.mem)
    (hn : ∀ fr t', t'.frames = fr :: rest → fr.fn = fn → fr.pc = p + S.len + 1 →
      fr.allocas = al → Seg.Through c lbl rest L Ss w' t' W.dlv.2 fr →
      Valuation.entry c t'.k W.dlv.2 fr = V.resume S.toSummary (resReg fn lbl (p + S.len)) W.dlv →
      RunsVia c Q ws t' W.dlv.2) :
    RunsVia c Q (W.via fn lbl :: ws) t m :=
  RunsVia.of_through h hV hfn hp ha hw hw' hds (Piece.Wait.via_of hq hc hx hm) hn

/-- **A shuffle's four argument terms' values**: for every valuation, node values, integers `a`,
`b`, `e` and term `x` with value `v`, the terms `i32 a`, `x`, `i32 b`, `i32 e` evaluate to the
words `a`, `b`, `e` (`BitVec.ofInt 32`) around `v`. -/
theorem SVal.mapM_shfl {V : Valuation} {vs : List (Except Fault Val)} (a b e : Int) {x : SVal}
    {v : Val} (h : x.eval V vs = .ok v) :
    [SVal.int 32 a, x, .int 32 b, .int 32 e].mapM (·.eval V vs) =
      .ok [.bits 32 (BitVec.ofInt 32 a), v, .bits 32 (BitVec.ofInt 32 b),
        .bits 32 (BitVec.ofInt 32 e)] := by
  simp only [List.mapM_cons, List.mapM_nil, h]
  rfl

/-- **A run's first wait, weakened**: for every context, final predicate, predicates `P`, `P'`,
delivery, later waits, thread and memory: a run whose first wait meets `P` meets `P'` there when
`P` implies `P'`. -/
theorem RunsVia.imp_head {c : Ctx} {Q : Mem → Prop}
    {P P' : Thread → Intrinsic → List Val → Mem → Prop} {d : Option Val × Mem}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))} {t : Thread}
    {m : Mem} (h : RunsVia c Q ((P, d) :: ws) t m)
    (hP : ∀ u i xs me, P u i xs me → P' u i xs me) : RunsVia c Q ((P', d) :: ws) t m := by
  obtain ⟨u, i, xs, e, m₁, hT, hu, hr⟩ := h
  exact ⟨u, i, xs, e, m₁, hT, hP _ _ _ _ hu, hr⟩

/-- **A run's final predicate, weakened**: for every context, final predicates `Q`, `Q'`, waits,
thread and memory: a run through the waits whose final memory meets `Q` is one whose final memory
meets `Q'` when `Q` implies `Q'`. By induction on the waits. -/
theorem RunsVia.imp {c : Ctx} {Q Q' : Mem → Prop} (hQ : ∀ m, Q m → Q' m) :
    ∀ {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
      {t : Thread} {m : Mem}, RunsVia c Q ws t m → RunsVia c Q' ws t m
  | [], _, _, h => by
    obtain ⟨m', hr, hq⟩ := h
    exact ⟨m', hr, hQ _ hq⟩
  | (_, _) :: _, _, _, h => by
    obtain ⟨u, i, xs, e, m₁, hT, hP, hr⟩ := h
    exact ⟨u, i, xs, e, m₁, hT, hP, RunsVia.imp hQ hr⟩

/-- **The memory at a wait, one for every later value.** For every context `c`, type `X` with
premise `H`, final predicates `Q x`, predicate `P`, predicates `R M` for memories `M`, deliveries
`d x` and later waits `ws₂ x` for `x : X`, waits `ws₁`, thread `t` and memory `m`: if `P` with
memory `M` gives `R M` (`hR`) and for every `x` with `H x` the thread runs through `ws₁` and then
a wait of `P` delivering `d x`, then for one memory `M`, `P` holds there with `M` for every such
`x`, and the thread runs through `ws₁` and a wait of `R M`. The thread and memory at the wait are
determined by `t`, `m` and `ws₁`'s deliveries (`ToWait.det`), which do not depend on `x`. -/
theorem RunsVia.pin {c : Ctx} {X : Sort _} {H : X → Prop} {Q : X → Mem → Prop}
    {P : Thread → Intrinsic → List Val → Mem → Prop}
    {R : Mem → Thread → Intrinsic → List Val → Mem → Prop}
    (hR : ∀ M u i xs, P u i xs M → R M u i xs M) {d : X → Option Val × Mem}
    {ws₂ : X → List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))} :
    ∀ (ws₁ : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)))
      {t : Thread} {m : Mem}, (∀ x, H x → RunsVia c (Q x) (ws₁ ++ (P, d x) :: ws₂ x) t m) →
      ∃ M, (∀ x, H x → ∃ u i xs, P u i xs M) ∧
        ∀ x, H x → RunsVia c (Q x) (ws₁ ++ (R M, d x) :: ws₂ x) t m
  | [], t, m, h => by
    by_cases hx : ∃ x, H x
    · obtain ⟨x₀, h₀⟩ := hx
      obtain ⟨u₀, i₀, xs₀, e₀, m₀, hT₀, -, -⟩ := h x₀ h₀
      refine ⟨m₀, fun x hx => ?_, fun x hx => ?_⟩ <;>
        obtain ⟨u, i, xs, e, m₁, hT, hP, hr⟩ := h x hx <;>
        obtain rfl := (ToWait.det hT hT₀).2
      · exact ⟨u, i, xs, hP⟩
      · exact ⟨u, i, xs, e, m₁, hT, hR _ _ _ _ hP, hr⟩
    · exact ⟨m, fun x hx' => absurd ⟨x, hx'⟩ hx, fun x hx' => absurd ⟨x, hx'⟩ hx⟩
  | (P', d') :: ws₁, t, m, h => by
    by_cases hx : ∃ x, H x
    · obtain ⟨x₀, h₀⟩ := hx
      obtain ⟨u₀, i₀, xs₀, e₀, m₀, hT₀, hP₀, -⟩ := h x₀ h₀
      have h' : ∀ x, H x → RunsVia c (Q x) (ws₁ ++ (P, d x) :: ws₂ x) (u₀.resume d'.1) d'.2 := by
        intro x hx
        obtain ⟨u, i, xs, e, m₁, hT, -, hr⟩ := h x hx
        obtain ⟨he, -⟩ := ToWait.det hT hT₀
        cases he
        exact hr
      obtain ⟨M, hF, hM⟩ := RunsVia.pin hR ws₁ h'
      exact ⟨M, hF, fun x hx => ⟨u₀, i₀, xs₀, e₀, m₀, hT₀, hP₀, hM x hx⟩⟩
    · exact ⟨m, fun x hx' => absurd ⟨x, hx'⟩ hx, fun x hx' => absurd ⟨x, hx'⟩ hx⟩

/-- `obl_exact` closes a goal `e = x` whose left side `obl_have` evaluates. -/
syntax (name := oblExact) "obl_exact" : tactic

open Lean Elab Tactic Meta in
/-- The elaborator of `obl_exact`: `Obl.haves` on the goal's left side, then the value's equation
against the goal. -/
@[tactic oblExact] def evalOblExact : Tactic := fun _ => withMainContext do
  let g ← getMainGoal
  let ty := (← instantiateMVars (← g.getType)).headBeta
  let some (_, e, _) := ty.eq? | throwError "obl_exact: not an equation"
  let lctx ← instantiateLCtxMVars (← getLCtx)
  let (t, p) ← withLCtx lctx (← getLocalInstances) (Obl.haves #[e.headBeta])
  unless ← isDefEq t ty do throwError "obl_exact: the value is{indentExpr t}"
  g.assign p
  replaceMainGoal []

end MojoProof.Sym
