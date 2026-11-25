import GPUProof.Race

/-!
# The race check by chunks

`racy S tr = false` by the kernel, on a trace too long for one `decide +kernel`: the pass
(`GPUProof.scan`) cut into chunks of positions, each checked by the kernel on its own from a state
written out to the next.

* `scan_add`: the pass over `K + m` positions is the pass over `m` more positions from the pass
  over `K`, for every machine. `scan_chunk` chains two such facts and `racy_eq_false_of_scan`
  reads `racy` off the last state.
* `Scan.quote`, `Event.quote`: a state of the pass and a trace event as terms, for every machine
  whose types `Tid`, `Job`, `Buf`, `Op`, `Proxy`, `Obj` and `Loc` have `Lean.ToExpr` instances,
  with the machine itself as the loose bound variable `0`.
* `racy_by_chunks m`: proves `GPUProof.racy S tr = false`. The evaluator runs the pass and
  proposes the state after every `m` positions (`chunkStates`, `quoteChunks`); for each chunk the
  kernel checks, by `decide` on the states' equality (`DecidableEq (Scan S)`) in a lemma of its
  own, that `m` more steps from one state give the next; `scan_chunk` chains them. The evaluator
  only proposes: every state is checked by the kernel, so the proof depends on the kernel and
  not on the evaluator. If the pass finds a race, the tactic fails and names the chunk.
* `trace_literal% t`: the trace `t`, evaluated and written out as a list literal, so that a
  definition `def tr : List S.Event := trace_literal% t` holds the trace the evaluator produced.
  Its equality with `t` is checked by the evaluator (a `#guard tr == t` beside it), not by the
  kernel: a theorem about `tr` is about that literal trace.

docs/proofs/core.md ("`racy` in the kernel") gives the measurements.
-/

namespace GPUProof

open Lean Meta Elab

variable (S : Sig)

/-- The pass over the first `K + m` positions of trace `tr` is `m` more steps (`Scan.step`, at
positions `K` to `K + m - 1`) from the pass over the first `K`, for every machine, trace, `K` and
`m`. -/
theorem scan_add (tr : List S.Event) (K m : Nat) :
    scan S tr (K + m) = (List.range' K m).foldl (Scan.step tr) (scan S tr K) := by
  rw [scan, scan, List.range_eq_range', List.range_eq_range', ← List.foldl_append,
    ← List.range'_append_1 (s := 0), Nat.zero_add]

/-- The pass over no position of trace `tr` is the state with no clock, fence or access, for every
machine and trace. -/
theorem scan_zero (tr : List S.Event) : scan S tr 0 = ⟨[], [], [], [], [], false⟩ := rfl

variable {S}

/-- From the pass over the first `K` positions of `tr` and the `m` steps after it, the pass over
the first `K + m`, for every machine, trace, `K`, `m` and states `s` and `t`. -/
theorem scan_chunk {tr : List S.Event} {K m : Nat} {s t : Scan S} (h : scan S tr K = s)
    (ht : (List.range' K m).foldl (Scan.step tr) s = t) : scan S tr (K + m) = t := by
  rw [scan_add, h, ht]

/-- `racy` is false on trace `tr` when the pass over all its positions is a state that has found
no race, for every machine, trace and state. -/
theorem racy_eq_false_of_scan {tr : List S.Event} {s : Scan S} (h : scan S tr tr.length = s)
    (hs : s.racy = false) : racy S tr = false := by
  rw [racy, h, hs]

deriving instance DecidableEq for Scan

/-- Decidable equality of the states of the pass, field by field, derived, for every machine. -/
add_decl_doc instDecidableEqScan

/-- The states of the pass over trace `tr` of machine `S` after each of `n` chunks of `m`
positions from state `s` at position `K`, each with the position it ends at, for every machine:
the `i`-th chunk (from `1`) ends at `min (K + i * m) tr.length`, with the steps (`Scan.step`)
from `s` at the positions from `K` up to that end (none when `K` is past the length of `tr`). So
the last chunk ends at the length of `tr` only when `n` is positive and `tr.length ≤ K + n * m`;
with `m = 0` every chunk ends at `min K tr.length`, and with `n = 0` there is no chunk. -/
def chunkStatesFrom (tr : List S.Event) (m : Nat) : Nat → Nat → Scan S → List (Nat × Scan S)
  | 0, _, _ => []
  | n + 1, K, s =>
    let K' := min (K + m) tr.length
    let s' := (List.range' K (K' - K)).foldl (Scan.step tr) s
    (K', s') :: chunkStatesFrom tr m n K' s'

/-- The states of the pass over trace `tr` of machine `S` after each chunk of `m` positions, each
with the position it ends at, for every machine: `chunkStatesFrom` from the empty state at
position `0`, for `(tr.length + m - 1) / m` chunks. For a positive `m` and a nonempty `tr`, the
chunks end at the positions `m, 2m, …` below the length of `tr` and then at the length itself,
each with the pass over the positions before it (`scan S tr K` at `K`, by `scan_add`). For
`m = 0` (the division by `0` is `0`) or the empty trace there is no chunk. -/
def chunkStates (tr : List S.Event) (m : Nat) : List (Nat × Scan S) :=
  chunkStatesFrom tr m ((tr.length + m - 1) / m) 0 ⟨[], [], [], [], [], false⟩

/-- `Empty` as a term type; it has no value to write out. -/
instance : ToExpr Empty where
  toExpr e := nomatch e
  toTypeExpr := mkConst ``Empty

section Quote

variable [ToExpr S.Tid] [ToExpr S.Job] [ToExpr S.Buf] [ToExpr S.Op] [ToExpr S.Proxy]
  [ToExpr S.Obj] [ToExpr S.Loc]

/-- A list of terms of type `ty` as a list literal, for every list. -/
def quoteList {α : Type} (ty : Expr) (f : α → Expr) : List α → Expr
  | [] => mkApp (.const ``List.nil [0]) ty
  | a :: as => mkApp3 (.const ``List.cons [0]) ty (f a) (quoteList ty f as)

/-- A pair of terms of types `α` and `β`, for every pair. -/
def quotePair (α β a b : Expr) : Expr :=
  mkApp4 (.const ``Prod.mk [0, 0]) α β a b

/-- The type `T S` of a field `T` of the machine, with the machine as the loose bound variable
`0`. -/
def sigType (T : Name) : Expr :=
  mkApp (.const T []) (.bvar 0)

variable (S) in
/-- An agent of machine `S` as a term, with the machine as the loose bound variable `0`, for
every machine and agent. -/
def Agent.quote : S.Agent → Expr
  | .thread t =>
    mkApp3 (.const ``Agent.thread []) (sigType ``Sig.Tid) (sigType ``Sig.Job) (toExpr t)
  | .job j => mkApp3 (.const ``Agent.job []) (sigType ``Sig.Tid) (sigType ``Sig.Job) (toExpr j)

variable (S) in
/-- A kind of access of machine `S` as a term, with the machine as the loose bound variable `0`,
for every machine and kind. -/
def Kind.quote : Kind S.Op → Expr
  | .read => mkApp (.const ``Kind.read []) (sigType ``Sig.Op)
  | .frozen => mkApp (.const ``Kind.frozen []) (sigType ``Sig.Op)
  | .write => mkApp (.const ``Kind.write []) (sigType ``Sig.Op)
  | .rmw op => mkApp2 (.const ``Kind.rmw []) (sigType ``Sig.Op) (toExpr op)
  | .rmwRet op => mkApp2 (.const ``Kind.rmwRet []) (sigType ``Sig.Op) (toExpr op)

/-- An access of machine `S` as a term, with the machine as the loose bound variable `0`, for
every machine and access. -/
def Access.quote (a : S.Access) : Expr :=
  mkAppN (.const ``Access.mk [])
    #[sigType ``Sig.Agent, sigType ``Sig.Buf, sigType ``Sig.Op, sigType ``Sig.Proxy,
      Agent.quote S a.who, toExpr a.buf, toExpr a.off, mkRawNatLit a.len, Kind.quote S a.kind,
      toExpr a.proxy]

/-- A trace event of machine `S` as a term, with the machine as the loose bound variable `0`,
for every machine and event. -/
def Event.quote (e : S.Event) : Expr :=
  let ty := #[sigType ``Sig.Agent, sigType ``Sig.Buf, sigType ``Sig.Op, sigType ``Sig.Proxy,
    sigType ``Sig.Obj]
  match e with
  | .access a => mkAppN (.const ``Event.access []) (ty.push (Access.quote a))
  | .sync o ms => mkAppN (.const ``Event.sync [])
      (ty ++ #[toExpr o, quoteList (sigType ``Sig.Agent) (Agent.quote S) ms])
  | .rel w o ph =>
    mkAppN (.const ``Event.rel []) (ty ++ #[Agent.quote S w, toExpr o, mkRawNatLit ph])
  | .acq w o ph =>
    mkAppN (.const ``Event.acq []) (ty ++ #[Agent.quote S w, toExpr o, mkRawNatLit ph])
  | .fence w p q =>
    mkAppN (.const ``Event.fence []) (ty ++ #[Agent.quote S w, toExpr p, toExpr q])

/-- A trace of machine `S` as a list literal, with the machine as the loose bound variable `0`,
for every machine and trace. -/
def quoteTrace (tr : List S.Event) : Expr :=
  quoteList (sigType ``Sig.Event) Event.quote tr

/-- A state of the pass of machine `S` as a term, with the machine as the loose bound variable
`0`, for every machine and state: its clocks and positions as numerals. -/
def Scan.quote (s : Scan S) : Expr :=
  let nat := mkConst ``Nat
  let agent := sigType ``Sig.Agent
  let obj := sigType ``Sig.Obj
  let proxy := sigType ``Sig.Proxy
  let acc := sigType ``Sig.Access
  let locs := mkApp (.const ``List [0]) (sigType ``Sig.Loc)
  let pp (α β : Expr) := mkApp2 (.const ``Prod [0, 0]) α β
  let kept := pp nat (pp acc locs)
  let quoteKept (x : Nat × S.Access × List S.Loc) : Expr :=
    quotePair nat (pp acc locs) (mkRawNatLit x.1)
      (quotePair acc locs (Access.quote x.2.1) (quoteList (sigType ``Sig.Loc) toExpr x.2.2))
  mkAppN (.const ``Scan.mk []) #[.bvar 0,
    quoteList (pp agent nat) (fun x => quotePair agent nat (Agent.quote S x.1) (mkRawNatLit x.2))
      s.cur,
    quoteList (pp (pp obj nat) nat) (fun x => quotePair (pp obj nat) nat
      (quotePair obj nat (toExpr x.1.1) (mkRawNatLit x.1.2)) (mkRawNatLit x.2)) s.rel,
    quoteList (pp nat (pp proxy (pp proxy nat))) (fun x => quotePair nat (pp proxy (pp proxy nat))
      (mkRawNatLit x.1) (quotePair proxy (pp proxy nat) (toExpr x.2.1)
        (quotePair proxy nat (toExpr x.2.2.1) (mkRawNatLit x.2.2.2)))) s.fences,
    quoteList kept quoteKept s.writes, quoteList kept quoteKept s.reads, toExpr s.racy]

/-- The state of the pass over trace `tr` of machine `S` at position `0` and after each chunk of
`m` positions (`chunkStates`), each with its position and whether it has found a race, as terms
(`Scan.quote`), for every machine. -/
def quoteChunks (tr : List S.Event) (m : Nat) : List (Nat × Bool × Expr) :=
  ((0, ⟨[], [], [], [], [], false⟩) :: chunkStates tr m).map fun p => (p.1, p.2.racy, p.2.quote)

end Quote

/-- `racy_by_chunks m` proves `GPUProof.racy S tr = false`, for every machine `S` and trace `tr`
that are closed terms, with `Lean.ToExpr` instances for `S.Tid`, `S.Job`, `S.Buf`, `S.Op`,
`S.Proxy`, `S.Obj` and `S.Loc`. The evaluator runs the pass (`GPUProof.scan`) and writes out its
state after every `m` positions (`GPUProof.quoteChunks`); the kernel checks each chunk of `m`
steps in a lemma of its own, by `decide` on the equality of states, and `GPUProof.scan_chunk`
chains them. The tactic fails, naming the chunk, when the pass finds a race: then the goal is
false. -/
syntax (name := racyByChunks) "racy_by_chunks " num : tactic

/-- Elaborates `racy_by_chunks`, for every machine and trace that are closed terms; `unsafe`
because it evaluates the pass. -/
@[tactic racyByChunks] unsafe def evalRacyByChunks : Tactic.Tactic := fun stx =>
  Tactic.withMainContext do
    let m := stx[1].isNatLit?.getD 0
    if m == 0 then throwError "racy_by_chunks: the chunk must have at least one position"
    let goal ← Tactic.getMainGoal
    let ty ← instantiateMVars (← goal.getType)
    let notRacy := m!"racy_by_chunks: the goal is not `GPUProof.racy S tr = false`:{indentExpr ty}"
    let some (_, lhs, rhs) := ty.eq? | throwError notRacy
    unless rhs.isConstOf ``Bool.false do throwError notRacy
    let_expr GPUProof.racy S tr := lhs | throwError notRacy
    if S.hasFVar || S.hasMVar || tr.hasFVar || tr.hasMVar then
      throwError "racy_by_chunks: the machine and the trace must be closed terms:{indentExpr lhs}"
    let scanTy := mkApp (.const ``Scan []) S
    let dec ← synthInstance (mkApp (.const ``DecidableEq [1]) scanTy)
    let resTy := mkApp (.const ``List [0]) (mkApp2 (.const ``Prod [0, 0]) (mkConst ``Nat)
      (mkApp2 (.const ``Prod [0, 0]) (mkConst ``Bool) (mkConst ``Lean.Expr)))
    let chunks ← evalExpr (List (Nat × Bool × Expr)) resTy
      (← mkAppM ``quoteChunks
        #[← mkExpectedTypeHint tr (mkApp (.const ``List [0]) (mkApp (.const ``Sig.Event []) S)),
          mkRawNatLit m])
    let (_, _, q0) :: chunks := chunks
      | throwError "racy_by_chunks: the evaluator gave no state"
    let mut K := 0
    let mut s := q0.instantiate1 S
    let mut h := mkApp2 (.const ``scan_zero []) S tr
    for (K', racy, q) in chunks do
      if racy then
        throwError "racy_by_chunks: the pass finds a race in positions {K} to {K' - 1}"
      let t := q.instantiate1 S
      let len := K' - K
      let lhs := mkApp5 (.const ``List.foldl [0, 0]) scanTy (mkConst ``Nat)
        (mkApp2 (.const ``Scan.step []) S tr) s
        (mkApp3 (.const ``List.range' []) (mkRawNatLit K) (mkRawNatLit len) (mkRawNatLit 1))
      let prop := mkApp3 (.const ``Eq [1]) scanTy lhs t
      let pf := mkApp3 (.const ``of_decide_eq_true []) prop (mkApp2 dec lhs t)
        (mkApp2 (.const ``Eq.refl [1]) (mkConst ``Bool) (mkConst ``Bool.true))
      let c ← mkAuxLemma [] prop pf
      h := mkAppN (.const ``scan_chunk []) #[S, tr, mkRawNatLit K, mkRawNatLit len, s, t, h,
        mkConst c]
      s := t
      K := K'
    goal.assign (mkAppN (.const ``racy_eq_false_of_scan []) #[S, tr, s, h,
      mkApp2 (.const ``Eq.refl [1]) (mkConst ``Bool) (mkConst ``Bool.false)])
    Tactic.replaceMainGoal []

/-- `trace_literal% t` is the trace `t` of a machine `S`, for every machine and closed term `t`
of type `List S.Event`, with `Lean.ToExpr` instances for `S.Tid`, `S.Job`, `S.Buf`, `S.Op`,
`S.Proxy`, `S.Obj` and `S.Loc`, evaluated and written out as a list literal. The literal is the
trace the evaluator produced: its equality with `t` is not proved, and a `#guard` beside the
definition checks it by the evaluator. -/
syntax (name := traceLiteral) "trace_literal% " term : term

/-- Elaborates `trace_literal%`, for every machine and closed trace; `unsafe` because it
evaluates the trace. -/
@[term_elab traceLiteral] unsafe def elabTraceLiteral : Term.TermElab := fun stx expected? => do
  let some expected := expected?
    | throwError "trace_literal%: the expected type must be given, `List S.Event`"
  let expected ← instantiateMVars expected
  let_expr List ev := expected
    | throwError "trace_literal%: the expected type is not `List S.Event`:{indentExpr expected}"
  let_expr Sig.Event S := ev
    | throwError "trace_literal%: the expected type is not `List S.Event`:{indentExpr expected}"
  let t ← Term.elabTermEnsuringType stx[1] expected
  Term.synthesizeSyntheticMVarsNoPostponing
  let t ← instantiateMVars t
  if t.hasFVar || t.hasMVar || S.hasFVar || S.hasMVar then
    throwError "trace_literal%: the trace must be a closed term:{indentExpr t}"
  let q ← evalExpr Expr (mkConst ``Lean.Expr)
    (← mkAppM ``quoteTrace #[← mkExpectedTypeHint t expected])
  return q.instantiate1 S

end GPUProof
