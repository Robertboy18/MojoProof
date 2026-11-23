import MojoProof.Sym.Vals

/-!
# An elementwise kernel's effects, and the tactic mojo_ret

`Elem` (MojoProof/Sym/Kernel.lean) is the memory after the first `k` threads of an
elementwise kernel; `Ret V Q ps` says that a path from `V` returns with a memory of `Q`. This module
states the effects of a block as steps of `Elem`, effect by effect, and proves with them, by the
tactic mojo_ret, the goals a kernel's `Elem` lemmas and its `Ret` ask.

The lemmas, for every caller's memory `m₀`, output block `out`, cell width `w`, cells `cell`,
bytes `bs`, valuation `V` and node values `vs`:

* `Elem.Steps … V vs k K es`: effects `es` run from every memory of `Elem` after `k` threads to
  one of `Elem` after `K` threads;
* `Elem.steps_nil`: no effect, `K = k`; `Elem.steps_skip`: a thread `k` with no bytes
  (`bs k = none`) adds itself;
* `Elem.steps_load`: a load through a pointer of a block other than `out` (`Elem.apply_load`);
* `Elem.steps_store`: thread `k`'s store of a value whose bytes are `bs k` at `out`'s cell `cell k`
  (`Elem.apply_store`), then thread `k + 1`;
* `Elem.after`: a block whose effects succeed and are steps from `k` to `K` takes `Elem` after `k`
  threads at its entry to `Elem` after `K` threads after it (`Valuation.after_mem`);
* `Elem.intoWith`: the same as `Elem.after` across `Valuation.intoWith c`, for every flag `c`
  (`Valuation.intoWith_mem`);
* `Elem.ret`: a path whose premises hold (`Walk`) and whose last block returns, with `Elem` after
  `k` threads at that block's entry and its effects steps from `k` to `K`, is a `Ret` to `Elem`
  after `K` threads; `Elem.retWith`: the same with `WalkWith c` and `Valuation.lastWith c`, a
  `RetWith c`, for every flag `c`;
* `vals_getElem?_of_eq`: an entry of node values given as a list;
* `Elem.Only.Steps out S V vs es`: effects `es` keep `Elem.Only out S` (every access to block
  `out` is by a thread of `S`); `Elem.Only.steps_nil`, `Elem.Only.steps_of` (every effect of a
  thread of `S`, `Elem.Only.apply`) and `Elem.Only.steps_load` (a load outside `out`, by any
  thread).

## The tactic

mojo_ret (syntax `mojoRet`, elaborator `evalMojoRet`, method `Ops.run`) closes three goals:

1. `Elem m₀ out w cell bs K me`, from a hypothesis `SEff.run V (vals V S.nodes) S.effs = .ok me`
   for a concrete summary `S` and one `Elem m₀ out w cell bs k M` with `M` the memory of `V`: the
   effects of `S` as steps from `k` to `K` (`Ops.steps`);
2. `∃ ps ∈ paths, Ret V (Elem m₀ out w cell bs K) ps`, for a concrete list of paths and a
   hypothesis `Elem m₀ out w cell bs k M` with `M` the memory of `V`: the first path that it
   proves, each block's premises by mojo_obl's `walk` and its effects as steps, the blocks before
   the last by `Elem.after`, the last by `Elem.ret`; or `RetWith c V (Elem …) ps` for every flag
   `c`, the same by mojo_obl's `walkI` (`WalkWith c`), `Elem.intoWith` and `Elem.retWith`. When no
   path is proved, it splits on a branch condition that `omega` decided neither way
   (`Decidable.byCases`, twice at most) and proves each case so;
3. `Elem.Only out S me`, from the run as in goal 1 and a hypothesis `Elem.Only out S M` with `M`
   the memory of `V`: all of the effects by `Elem.Only.steps_of` when `omega` proves the thread
   `V.ctx.who.thread` in `S` (reducible definitions unfolded); otherwise each load by
   `Elem.Only.steps_load`, its block other than `out` by `omega`, and the effects from the first
   store on by `Elem.Only.steps_of`, the thread in `S` left open (`Ops.onlySteps`).

The node values are mojo_obl's (`Obl.opnd`), or a hypothesis `vals V S.nodes = ws` when there is
one. For each step: a load's block other than `out` by `omega`; a store's thread
`V.ctx.who.thread = k`, pointer `⟨out, cell k⟩` and bytes `bs k` by mojo_vals' `Vals.conv`, its
statement by the kernel, and its width by `decide`; a skipped thread's `bs k = none` by
`Vals.conv`. In goals 1 and 3, and in goal 2 when no path is proved (then on the first path of the
list), a premise it does not prove is left as a goal and logged as `mojo_ret: open goal`. Tests:
MojoProofTest/Ops.lean (`vadd_elem0`, `vadd_elem1` and an `example` of the statement of the
generated `vadd.ret` on `vector_addition`'s blocks, for every valid launch and thread,
`vadd_only0` and `vadd_only1` for goal 3, and open-goal twins), MojoProofTest/OpsWith.lean (goal
2 as `RetWith`: an `example` of the statement of `map2_contract.ret`, vadd's paths with the flag
`contract`; `kh_ret`, a path with an `fmul contract` product, for every flag; `kq_ret`, a path
through a `phi` edge, for every flag; and open-goal twins) and MojoProofTest/NaiveOut.lean (goals 1 and 3 on the
naive matmul kernel's entry block).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

variable {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
  {V : Valuation} {vs : List (Except Fault Val)}

/-- **Effects as steps of `Elem`**: effects `es` at valuation `V` with node values `vs` run from
every memory of `Elem m₀ out w cell bs` after `k` threads to a memory of it after `K` threads. -/
def Elem.Steps (m₀ : Mem) (out w : Nat) (cell : Nat → Nat) (bs : Nat → Option (List MemByte))
    (V : Valuation) (vs : List (Except Fault Val)) (k K : Nat) (es : List SEff) : Prop :=
  ∀ m me, Elem m₀ out w cell bs k m → es.foldlM (SEff.apply V vs) m = .ok me →
    Elem m₀ out w cell bs K me

/-- No effect is a step from `k` to `k`, for every `k`. -/
theorem Elem.steps_nil {k : Nat} : Elem.Steps m₀ out w cell bs V vs k k [] := by
  intro m me h hr
  simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at hr
  subst hr
  exact h

/-- Steps from `k + 1` are steps from `k` when thread `k` puts no bytes (`Elem.skip`), for every
`k`, `K` and effects. -/
theorem Elem.steps_skip {k K : Nat} {es : List SEff} (hb : bs k = none)
    (h : Elem.Steps m₀ out w cell bs V vs (k + 1) K es) :
    Elem.Steps m₀ out w cell bs V vs k K es := by
  intro m me hE hr
  exact h m me (hE.skip hb) hr

/-- **A load, then steps**: for every label, instruction, pointer `p` that evaluates to an address
in a block `c` other than `out`, and effects `es` that are steps from `k` to `K`, the load followed
by `es` is steps from `k` to `K` (`Elem.apply_load`). -/
theorem Elem.steps_load {k K lbl pc : Nat} {p : SVal} {es : List SEff} {c : Nat} {o : Int}
    (hv : p.eval V vs = .ok (.ptr ⟨c, o⟩)) (hc : c ≠ out)
    (h : Elem.Steps m₀ out w cell bs V vs k K es) :
    Elem.Steps m₀ out w cell bs V vs k K (.load lbl pc p :: es) := by
  intro m me hE hr
  rw [List.foldlM_cons] at hr
  obtain ⟨m1, h1, hr⟩ := Except.bind_eq_ok.1 hr
  refine h m1 me (hE.apply_load h1 fun v hv' q hq => ?_) hr
  rw [hv] at hv'
  cases hv'
  simp only [Val.addr?, pure, Except.pure, Except.ok.injEq] at hq
  subst hq
  exact hc

/-- **Thread `k`'s store, then steps**: for every valuation `V` of thread `k` whose function is
`F` and program `P`, if the statement at `(lbl, pc)` of `F` stores a value of type `t` filling at
most `w` bytes, the stored value evaluates to `x` whose bytes are `bs k`, the pointer to
`⟨out, cell k⟩`, and effects `es` are steps from `k + 1` to `K`, then the store followed by `es`
is steps from `k` to `K` (`Elem.apply_store`). -/
theorem Elem.steps_store {k K lbl pc : Nat} {v p : SVal} {es : List SEff} {F : Func}
    {P : Program} {r : Option Nat} {vol : Bool} {t : Ty} {tv : Value} {a : Nat} {pv : Value}
    {al : Option Nat} {md : List (String × Nat)} {x : Val} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨r, .store vol ⟨t, tv⟩ ⟨.ptr a, pv⟩ al, md⟩)
    (hw : V.ctx.who.thread = k) (hx : v.eval V vs = .ok x)
    (hp : p.eval V vs = .ok (.ptr ⟨out, cell k⟩)) (he : P.layout.encode t x = bs k)
    (hl : P.layout.stored t ≤ w) (h : Elem.Steps m₀ out w cell bs V vs (k + 1) K es) :
    Elem.Steps m₀ out w cell bs V vs k K (.store lbl pc v p :: es) := by
  intro m me hE hr
  rw [List.foldlM_cons] at hr
  obtain ⟨m1, h1, hr⟩ := Except.bind_eq_ok.1 hr
  subst hP
  exact h m1 me (hE.apply_store h1 (Valuation.stmt_of_fn hF hs) hw hx hp he hl) hr

/-- **A block of `Elem` steps**: for every valuation `V` and summary `S` whose effects succeed at
`V` and are steps from `k` to `K`, `Elem` after `k` threads at `V`'s memory gives `Elem` after `K`
threads at the memory after the block (`Valuation.after_mem`). -/
theorem Elem.after {k K : Nat} {S : Summary} (hE : Elem m₀ out w cell bs k V.mem)
    (hm : ∃ me, SEff.run V (vals V S.nodes) S.effs = .ok me)
    (h : Elem.Steps m₀ out w cell bs V (vals V S.nodes) k K S.effs) :
    Elem m₀ out w cell bs K (V.after S).mem := by
  obtain ⟨me, hme⟩ := hm
  rw [Valuation.after_mem hme]
  exact h _ _ hE hme

/-- **A path to `Elem` after `K` threads**: for every valuation `V` and path `(l, ds, S) :: ps`
whose premises hold (`Walk`) and whose last block `S'` (entered with `V'`, `Valuation.last`)
returns, with `Elem` after `k` threads at `V'`'s memory and `S'`'s effects succeeding at `V'` as
steps from `k` to `K`, the path is a `Ret` to `Elem` after `K` threads. -/
theorem Elem.ret {K l : Nat} {ds : List Cond} {S : Summary} {ps : List (Nat × List Cond × Summary)}
    {V' : Valuation} {l' : Nat} {S' : Summary} {k : Nat} (hW : Walk V ((l, ds, S) :: ps))
    (hl : V.last l S ps = (V', l', S')) (hx : S'.exit = .ret)
    (hE : Elem m₀ out w cell bs k V'.mem)
    (hm : ∃ me, SEff.run V' (vals V' S'.nodes) S'.effs = .ok me)
    (h : Elem.Steps m₀ out w cell bs V' (vals V' S'.nodes) k K S'.effs) :
    Ret V (Elem m₀ out w cell bs K) ((l, ds, S) :: ps) := by
  obtain ⟨me, hme⟩ := hm
  exact Ret.of_walk hW hl hx hme (h _ _ hE hme)

/-- **A block of `Elem` steps, into the next block, with or without `fmul contract`**: for every
flag `c`, label `l`, valuation `V` and summary `S` whose effects succeed at `V` and are steps from
`k` to `K`, `Elem` after `k` threads at `V`'s memory gives `Elem` after `K` threads at the memory
of `Valuation.intoWith c V l S` (`Valuation.intoWith_mem`, `Elem.after`). -/
theorem Elem.intoWith {c : Bool} {l k K : Nat} {S : Summary} (hE : Elem m₀ out w cell bs k V.mem)
    (hm : ∃ me, SEff.run V (vals V S.nodes) S.effs = .ok me)
    (h : Elem.Steps m₀ out w cell bs V (vals V S.nodes) k K S.effs) :
    Elem m₀ out w cell bs K (V.intoWith c l S).mem := by
  rw [Valuation.intoWith_mem]
  exact Elem.after hE hm h

/-- **A path to `Elem` after `K` threads, with or without `fmul contract`**: for every flag `c`,
valuation `V` and path `(l, ds, S) :: ps` whose premises hold (`WalkWith c`, each block after the
first entered through `Valuation.intoWith c`) and whose last block `S'` (entered with `V'`,
`Valuation.lastWith c`) returns, with `Elem` after `k` threads at `V'`'s memory and `S'`'s effects
succeeding at `V'` as steps from `k` to `K`, the path is a `RetWith c` to `Elem` after `K`
threads. -/
theorem Elem.retWith {c : Bool} {K l : Nat} {ds : List Cond} {S : Summary}
    {ps : List (Nat × List Cond × Summary)} {V' : Valuation} {l' : Nat} {S' : Summary} {k : Nat}
    (hW : WalkWith c V ((l, ds, S) :: ps)) (hl : V.lastWith c l S ps = (V', l', S'))
    (hx : S'.exit = .ret) (hE : Elem m₀ out w cell bs k V'.mem)
    (hm : ∃ me, SEff.run V' (vals V' S'.nodes) S'.effs = .ok me)
    (h : Elem.Steps m₀ out w cell bs V' (vals V' S'.nodes) k K S'.effs) :
    RetWith c V (Elem m₀ out w cell bs K) ((l, ds, S) :: ps) := by
  obtain ⟨me, hme⟩ := hm
  refine ⟨hW, ?_, me, ?_, h _ _ hE hme⟩
  · rw [hl]; exact hx
  · rw [hl]; exact hme

/-- Entry `j` of node values `vals V ns` given as the list `ws` is entry `j` of `ws`, for every
valuation, nodes, list and `j`. -/
theorem vals_getElem?_of_eq {ns : List SNode} {ws : List (Except Fault Val)} (h : vals V ns = ws)
    (j : Nat) : (vals V ns)[j]? = ws[j]? := by
  rw [h]

/-- **Effects as steps of `Elem.Only`**: effects `es` at valuation `V` with node values `vs` run
from every memory whose accesses to block `out` are all by threads of `S` to such a memory. -/
def Elem.Only.Steps (out : Nat) (S : Nat → Prop) (V : Valuation) (vs : List (Except Fault Val))
    (es : List SEff) : Prop :=
  ∀ m me, Elem.Only out S m → es.foldlM (SEff.apply V vs) m = .ok me → Elem.Only out S me

/-- No effect keeps `Elem.Only`, for every output block, set of threads, valuation and node
values. -/
theorem Elem.Only.steps_nil {S : Nat → Prop} : Elem.Only.Steps out S V vs [] := by
  intro m me h hr
  simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at hr
  subst hr
  exact h

/-- **The effects of a thread of `S` keep `Elem.Only`**: for every output block, set of threads
`S`, valuation `V` whose thread is in `S`, node values and effects (`Elem.Only.apply`). -/
theorem Elem.Only.steps_of {S : Nat → Prop} (hS : S V.ctx.who.thread) {es : List SEff} :
    Elem.Only.Steps out S V vs es := by
  induction es with
  | nil => exact Elem.Only.steps_nil
  | cons e es ih =>
    intro m me h hr
    rw [List.foldlM_cons] at hr
    obtain ⟨m1, h1, hr⟩ := Except.bind_eq_ok.1 hr
    exact ih m1 me (h.apply hS h1) hr

/-- **A load outside `out`, then steps of `Elem.Only`**: for every thread, label, instruction,
pointer `p` that evaluates to an address in a block `c` other than `out`, and effects `es` that keep
`Elem.Only`, the load followed by `es` keeps it (the load logs an access to `c`,
`Elem.Only.log`). -/
theorem Elem.Only.steps_load {S : Nat → Prop} {lbl pc : Nat} {p : SVal} {es : List SEff}
    {c : Nat} {o : Int} (hv : p.eval V vs = .ok (.ptr ⟨c, o⟩)) (hc : c ≠ out)
    (h : Elem.Only.Steps out S V vs es) : Elem.Only.Steps out S V vs (.load lbl pc p :: es) := by
  intro m me hO hr
  rw [List.foldlM_cons] at hr
  obtain ⟨m1, h1, hr⟩ := Except.bind_eq_ok.1 hr
  refine h m1 me ?_ hr
  simp only [SEff.apply, hv, Val.addr?, bind, Except.bind, pure, Except.pure] at h1
  split at h1
  · cases h1
    exact hO.log fun hb => absurd hb hc
  · cases h1

namespace Ops

open Lean Meta Elab Tactic Obl

/-- The named arguments `m₀ out w cell bs` of the `Elem` lemmas, from `Elem`'s first five. -/
def named (E : Array Expr) : List (Name × Expr) :=
  [(`m₀, E[0]!), (`out, E[1]!), (`w, E[2]!), (`cell, E[3]!), (`bs, E[4]!)]

/-- The first five arguments, the threads and the memory of `Elem m₀ out w cell bs k m`. -/
def elemOf? (t : Expr) : Option (Array Expr × Expr × Expr) :=
  match t.getAppFnArgs with
  | (``Elem, #[m₀, out, w, cell, bs, k, m]) => some (#[m₀, out, w, cell, bs], k, m)
  | _ => none

/-- The two sides of the equation `t`. -/
def sides (t : Expr) : MetaM (Expr × Expr) := do
  let some (_, l, r) := (← instantiateMVars t).eq?
    | throwError "mojo_ret: not an equation{indentExpr t}"
  return (l, r)

/-- The block and offset of pointer `q`. -/
def ptrMk (q : Expr) : MetaM (Expr × Expr) := do
  match q.getAppFnArgs with
  | (``MojoProof.Sem.Ptr.mk, #[c, o]) => return (c, o)
  | _ =>
    match (← kdeep q 1).getAppFnArgs with
    | (``MojoProof.Sem.Ptr.mk, #[c, o]) => return (c, o)
    | _ => throwError "mojo_ret: not a pointer{indentExpr q}"

/-- A hypothesis `Elem E' k M` with `E'` the first five arguments `E` and `M` the memory of `V`:
the hypothesis and `k`. -/
def elemHyp (E : Array Expr) (V : Expr) : MetaM (Expr × Expr) := do
  let mem := mkApp (mkConst ``Valuation.mem) V
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (E', k, m) := elemOf? (← instantiateMVars d.type) | continue
    let same ← (E.zip E').allM fun (a, b) => if a == b then pure true else kdefeq a b
    unless same && (← kdefeq m mem) do continue
    return (d.toExpr, k)
  throwError "mojo_ret: no hypothesis Elem … of the memory of{indentExpr V}"

/-- The node values of `S` at `V` from a hypothesis `vals V S.nodes = ws`, `ws` a list, when
there is one: each entry `.ok v` with `(vals V S.nodes)[j]? = some (.ok v)`
(`vals_getElem?_of_eq`). -/
def seed (V S : Expr) : M Unit := do
  if (← get).nodes.contains (V, S) then return
  let ns := mkApp (mkConst ``Summary.nodes) S
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (_, l, ws) := (← instantiateMVars d.type).eq? | continue
    let (``MojoProof.Sym.vals, #[V', ns']) := l.getAppFnArgs | continue
    unless V' == V && ns' == ns do continue
    let some ts ← (try some <$> klist ws catch _ => pure none) | continue
    let mut acc : Array (Option (Expr × Expr)) := #[]
    for j in [0:ts.length] do
      match Vals.okVal? ts[j]! with
      | some v =>
        let p ← mkAppM ``vals_getElem?_of_eq #[d.toExpr, mkNatLit j]
        let (lhs, _) ← sides (← inferType p)
        acc := acc.push (some (v, hint p (← mkEq lhs (← mkSome Vals.resTy (mkOk v)))))
      | none => acc := acc.push none
    modify fun s => { s with nodes := s.nodes.insert (V, S) acc }
    return

/-- `k + n`, as `n` successors. -/
def addN (k : Expr) (n : Nat) : Expr :=
  (List.range n).foldl (fun a _ => mkNatAdd a (mkNatLit 1)) k

/-- The number of stores of effects `es`. -/
def stores (es : List Expr) : MetaM Nat :=
  es.foldlM (fun n e => do return if (← kdeep e 2).isAppOf ``SEff.store then n + 1 else n) 0

/-- A proof of the equation `t` by `Vals.conv`, or `t` left open. -/
def eqn (t : Expr) : M Expr := do
  let (a, b) ← sides t
  attempt t (Vals.conv a b)

/-- **Effects `es` of summary `S` at `V` as steps** from `k` to `K` of `Elem` with first
arguments `E`: `Elem.Steps … V (vals V S.nodes) k K es`. -/
partial def steps (E : Array Expr) (V S k K : Expr) : List Expr → M Expr
  | [] => do
    if ← kdefeq k K then return (← use ``Elem.steps_nil (named E ++ [(`V, V), (`vs, vsOf V S),
      (`k, k)]) []).1
    let k1 := mkNatAdd k (mkNatLit 1)
    unless ← kdefeq k1 K do throwError "mojo_ret: no steps from{indentExpr k}\nto{indentExpr K}"
    let bk := mkApp E[4]! k
    let (``Option, #[α]) := (← whnfR (← inferType bk)).getAppFnArgs
      | throwError "mojo_ret: bytes{indentExpr bk}"
    let hb ← eqn (← mkEq bk (← mkNone α))
    let h ← steps E V S k1 K []
    return (← use ``Elem.steps_skip (named E ++ [(`V, V), (`vs, vsOf V S), (`k, k), (`K, K)])
      [.kd hb, .pf h]).1
  | e :: es => do
    let e ← kdeep e 2
    let nm := named E ++ [(`V, V), (`vs, vsOf V S), (`k, k), (`K, K)]
    match e.getAppFnArgs with
    | (``SEff.load, #[lbl, pc, p]) =>
      let (v, hv) ← opnd V S none p
      let (c, o) ← ptrMk (← ptrOf v)
      let ty := mkNot (← mkEq c E[1]!)
      let hc ← attempt ty (arith ty)
      let h ← steps E V S k K es
      return (← use ``Elem.steps_load (nm ++ [(`lbl, lbl), (`pc, pc), (`p, p), (`c, c), (`o, o)])
        [.kd hv, .kd hc, .pf h]).1
    | (``SEff.store, #[lbl, pc, v, p]) =>
      let (F, hF) ← fnOf V
      let (P, hP) ← progOf V
      let (_, hx) ← opnd V S none v
      let (q, hq) ← opnd V S none p
      let h ← steps E V S (mkNatAdd k (mkNatLit 1)) K es
      let hp (t : Expr) : M Expr := do
        let (_, b) ← sides t
        attempt t (do mkEqTrans hq (← Vals.conv (mkOk q) b))
      return (← use ``Elem.steps_store (nm ++ [(`lbl, lbl), (`pc, pc), (`v, v), (`p, p), (`F, F),
        (`P, P)]) [.kd hF, .kd hP, .rfl, .fn eqn, .pf hx, .fn hp, .fn eqn, .dec, .pf h]).1
    | _ => throwError "mojo_ret: effect{indentExpr e}"

/-- A hypothesis `SEff.run V vs es = .ok me`: the hypothesis, `V`, `vs` and `es`. -/
def runHyp (me : Expr) : MetaM (Expr × Expr × Expr × Expr) := do
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (_, l, r) := (← instantiateMVars d.type).eq? | continue
    let (``SEff.run, #[V, vs, es]) := l.getAppFnArgs | continue
    let (``Except.ok, #[_, _, me']) := r.getAppFnArgs | continue
    if me' == me then return (d.toExpr, V, vs, es)
  throwError "mojo_ret: no run of effects to{indentExpr me}"

/-- **Goal `Elem E K me`**, from a run `SEff.run V vs es = .ok me` and `Elem E k M` with `M` the
memory of `V`: the effects as steps from `k` to `K`. -/
def elemGoal (ty : Expr) : M Expr := do
  let some (E, K, me) := elemOf? ty | throwError "mojo_ret: not an Elem goal{indentExpr ty}"
  let (h, V, vs, es) ← runHyp me
  let (hE, k) ← elemHyp E V
  let S ← summaryOf vs
  seed V S
  let hS ← steps E V S k K (← klist es)
  return mkAppN hS #[mkApp (mkConst ``Valuation.mem) V, me, hE, h]

/-- The output block, the set of threads and the memory of `Elem.Only out T m`. -/
def onlyOf? (t : Expr) : Option (Expr × Expr × Expr) :=
  match t.getAppFnArgs with
  | (``Elem.Only, #[out, T, m]) => some (out, T, m)
  | _ => none

/-- A hypothesis `Elem.Only out T M` with `M` the memory of `V`. -/
def onlyHyp (out T V : Expr) : MetaM Expr := do
  let mem := mkApp (mkConst ``Valuation.mem) V
  for d in ← getLCtx do
    if d.isImplementationDetail then continue
    let some (out', T', m) := onlyOf? (← instantiateMVars d.type) | continue
    unless (← kdefeq out out') && (← kdefeq T T') && (← kdefeq m mem) do continue
    return d.toExpr
  throwError "mojo_ret: no hypothesis Elem.Only … of the memory of{indentExpr V}"

/-- The thread of `V` is in `T`: by `omega` on `T` applied to it with reducible definitions
unfolded, or left open when `open?`; `none` when it is not proved and not `open?`. -/
def inSet (T V : Expr) (open? : Bool) : M (Option Expr) := do
  let ty := (mkApp T (mkApp (mkConst ``Who.thread) (whoOf V))).headBeta
  let k : M Expr := do return hint (← arith (← whnfR ty)) ty
  if open? then return some (← attempt ty k)
  let s ← (saveState : MetaM Meta.SavedState)
  try some <$> k catch _ => do (s.restore : MetaM Unit); pure none

/-- **Effects `es` of summary `S` at `V` keep `Elem.Only out T`**: all of them by
`Elem.Only.steps_of` when the thread of `V` is in `T` (`hT`); otherwise each load by
`Elem.Only.steps_load` (its block other than `out` by `omega`), and from the first store on by
`Elem.Only.steps_of`, the thread in `T` left open. -/
partial def onlySteps (out T V S : Expr) (hT : Option Expr) (es : List Expr) : M Expr := do
  let nm := [(`out, out), (`S, T), (`V, V), (`vs, vsOf V S)]
  let all (hT : Expr) : M Expr := do
    return (← use ``Elem.Only.steps_of (nm ++ [(`es, ← mkListLit (mkConst ``SEff) es)])
      [.kd hT]).1
  if let some h := hT then return ← all h
  match es with
  | [] => return (← use ``Elem.Only.steps_nil nm []).1
  | e :: es' =>
    let e ← kdeep e 2
    match e.getAppFnArgs with
    | (``SEff.load, #[lbl, pc, p]) =>
      let (v, hv) ← opnd V S none p
      let (c, o) ← ptrMk (← ptrOf v)
      let ty := mkNot (← mkEq c out)
      let hc ← attempt ty (arith ty)
      let h ← onlySteps out T V S none es'
      return (← use ``Elem.Only.steps_load (nm ++ [(`lbl, lbl), (`pc, pc), (`p, p), (`c, c),
        (`o, o)]) [.kd hv, .kd hc, .pf h]).1
    | (``SEff.store, _) =>
      let some h ← inSet T V true | throwError "mojo_ret: no thread of{indentExpr T}"
      all h
    | _ => throwError "mojo_ret: effect{indentExpr e}"

/-- **Goal `Elem.Only out T me`**, from a run `SEff.run V vs es = .ok me` and `Elem.Only out T M`
with `M` the memory of `V` (`onlySteps`). -/
def onlyGoal (ty : Expr) : M Expr := do
  let some (out, T, me) := onlyOf? ty
    | throwError "mojo_ret: not an Elem.Only goal{indentExpr ty}"
  let (h, V, vs, es) ← runHyp me
  let hO ← onlyHyp out T V
  let S ← summaryOf vs
  seed V S
  let hS ← onlySteps out T V S (← inSet T V false) (← klist es)
  return mkAppN hS #[mkApp (mkConst ``Valuation.mem) V, me, hO, h]

/-- The blocks `(l, ds, S)` of the path `ps`. -/
partial def blocks (ps : Expr) : MetaM (List (Expr × Expr × Expr)) := do
  match ← kcons ps with
  | none => return []
  | some (hd, tl) =>
    let (l, r) ← kpair hd
    let (ds, S) ← kpair r
    return (l, ds, S) :: (← blocks tl)

/-- **Path `p` from `V0` is a `Ret` to `Elem E K`**, or with flag `c` a `RetWith c`: its walk
(`Obl.walk`, with the flag `Obl.walkI`), each block's effects as steps, the blocks before the last
by `Elem.after` (with the flag `Elem.intoWith`) and the last by `Elem.ret` (`Elem.retWith`). -/
def onePath (c? : Option Expr) (E : Array Expr) (K V0 p : Expr) : M Expr := do
  let hW ← match c? with
    | some c => walkI (some c) V0 p
    | none => walk V0 p
  let bl ← blocks p
  let some (l0, ds0, S0) := bl.head? | throwError "mojo_ret: an empty path"
  let some (_, tl) ← kcons p | throwError "mojo_ret: an empty path"
  let (hE0, k0) ← elemHyp E V0
  let mut (V, k, hE) := (V0, k0, hE0)
  for (l, _, S) in bl.dropLast do
    let es ← klist (mkApp (mkConst ``Summary.effs) S)
    let K' := addN k (← stores es)
    let hm ← runEx V S es
    let hS ← steps E V S k K' es
    match c? with
    | some c =>
      hE := (← use ``Elem.intoWith (named E ++ [(`c, c), (`l, l), (`V, V), (`k, k), (`K, K'),
        (`S, S)]) [.kd hE, .kd hm, .kd hS]).1
      (V, k) := (mkApp4 (mkConst ``Valuation.intoWith) c V l S, K')
    | none =>
      hE := (← use ``Elem.after (named E ++ [(`V, V), (`k, k), (`K, K'), (`S, S)])
        [.kd hE, .kd hm, .kd hS]).1
      (V, k) := (mkApp2 (mkConst ``Valuation.after) V S, K')
  let (ln, _, Sn) := bl.getLast!
  let es ← klist (mkApp (mkConst ``Summary.effs) Sn)
  let hm ← runEx V Sn es
  let hS ← steps E V Sn k K es
  let args := [(`V, V0), (`K, K), (`l, l0), (`ds, ds0), (`S, S0), (`ps, tl), (`V', V),
    (`l', ln), (`S', Sn), (`k, k)]
  let (lem, wc) := match c? with
    | some c => (``Elem.retWith, [(`c, c)])
    | none => (``Elem.ret, [])
  return (← use lem (named E ++ wc ++ args) [.kd hW, .rfl, .rfl, .kd hE, .kd hm, .kd hS]).1

/-- `List.Mem` of entry `i` of the list `l`, by `List.Mem.tail`s and `List.Mem.head`. -/
partial def memOfList (l : Expr) (i : Nat) : MetaM Expr := do
  let some (hd, tl) ← kcons l | throwError "mojo_ret: no entry {i}"
  if i == 0 then return ← mkAppOptM ``List.Mem.head #[none, hd, tl]
  mkAppOptM ``List.Mem.tail #[none, none, hd, tl, ← memOfList tl (i - 1)]

/-- The valuation, predicate and flag of a goal `Ret V0 Q ps` (no flag) or `RetWith c V0 Q ps`. -/
def retOf? (ret : Expr) : Option (Expr × Expr × Option Expr) :=
  match ret.getAppFnArgs with
  | (``Ret, #[V0, Q, _]) => some (V0, Q, none)
  | (``RetWith, #[c, V0, Q, _]) => some (V0, Q, some c)
  | _ => none

/-- **Goal `∃ ps ∈ paths, Ret V0 (Elem E K) ps`**, or `RetWith c` for every flag `c`: the first
path of `paths` proved in strict mode (`onePath`); when none is, a split on a branch condition
`omega` decided neither way and not split on yet (`splits`), `depth` deep. -/
partial def retGoal (ty : Expr) (splits : List Expr) (depth : Nat) : M Expr := do
  let (``Exists, #[α, pred]) := ty.getAppFnArgs | throwError "mojo_ret: not a Ret goal"
  let .lam _ _ body _ := pred | throwError "mojo_ret: not a Ret goal"
  let (``And, #[mem, ret]) := body.getAppFnArgs | throwError "mojo_ret: not a Ret goal"
  let some paths := mem.getAppArgs.toList.reverse.find? (!·.hasLooseBVars)
    | throwError "mojo_ret: no list of paths"
  let some (V0, Q, c?) := retOf? ret | throwError "mojo_ret: not a Ret goal"
  let (``Elem, #[m₀, out, w, cell, bs, K]) := Q.getAppFnArgs
    | throwError "mojo_ret: not a Ret to Elem{indentExpr Q}"
  let E := #[m₀, out, w, cell, bs]
  let cands ← klist paths
  let st0 ← get
  for i in [0:cands.length] do
    let p := cands[i]!
    let s ← (saveState : MetaM Meta.SavedState)
    modify fun st => { st with strict := true }
    try
      let hR ← onePath c? E K V0 p
      let hM ← memOfList paths i
      modify fun st => { st with strict := st0.strict }
      let (m', r') := (mem.instantiate1 p, ret.instantiate1 p)
      return mkApp4 (mkConst ``Exists.intro [← getLevel α]) α pred p
        (mkApp4 (mkConst ``And.intro) m' r' (hint hM m') (hint hR r'))
    catch ex =>
      (s.restore : MetaM Unit)
      dbg m!"mojo_ret: path {i}: {ex.toMessageData}"
      modify fun st => { st with strict := st0.strict, opens := st0.opens }
  if depth > 0 then
    for q in (← get).undec do
      if splits.contains q then continue
      let st1 ← get
      let s ← (saveState : MetaM Meta.SavedState)
      let case (q' : Expr) : M Expr := do
        let n ← mkFreshUserName `h
        withLocalDeclD n q' fun h => do
          set { st1 with undec := #[] }
          mkLambdaFVars #[h] (← retGoal ty (q :: splits) (depth - 1))
      try
        let h1 ← case q
        let h2 ← case (mkNot q)
        set { st1 with dbgs := (← get).dbgs }
        return ← mkAppOptM ``Decidable.byCases #[q, ty, none, h1, h2]
      catch _ =>
        (s.restore : MetaM Unit)
        set { st1 with dbgs := (← get).dbgs }
  throwError "mojo_ret: no path of{indentExpr paths}\nis a Ret"

/-- **`mojo_ret` on goal `g`**: the goals it leaves open. -/
def run (g : MVarId) : TacticM (Array MVarId) := g.withContext do
  -- the kernel takes no metavariables, so the local context's are instantiated first
  let lctx ← instantiateLCtxMVars (← getLCtx)
  withLCtx lctx (← getLocalInstances) do
    let ty := (← instantiateMVars (← g.getType)).consumeMData
    let k : M Expr := do
      if (elemOf? ty).isSome then return ← elemGoal ty
      if (onlyOf? ty).isSome then return ← onlyGoal ty
      unless ty.isAppOf ``Exists do
        throwError "mojo_ret: not an Elem, an Elem.Only or a Ret goal{indentExpr ty}"
      try retGoal ty [] 2
      catch ex =>
        -- no path proved: the first one, its premises left open
        dbg ex.toMessageData
        let (``Exists, #[_, .lam _ _ body _]) := ty.getAppFnArgs | throw ex
        let (``And, #[mem, ret]) := body.getAppFnArgs | throw ex
        let some paths := mem.getAppArgs.toList.reverse.find? (!·.hasLooseBVars) | throw ex
        let some (V0, Q, c?) := retOf? ret | throw ex
        let (``Elem, #[m₀, out, w, cell, bs, K]) := Q.getAppFnArgs | throw ex
        let some p := (← klist paths).head? | throw ex
        let hR ← onePath c? #[m₀, out, w, cell, bs] K V0 p
        let (m', r') := (mem.instantiate1 p, ret.instantiate1 p)
        let (``Exists, #[α, pred]) := ty.getAppFnArgs | throw ex
        return mkApp4 (mkConst ``Exists.intro [← getLevel α]) α pred p
          (mkApp4 (mkConst ``And.intro) m' r' (hint (← memOfList paths 0) m') (hint hR r'))
    let (p, st) ← (withFacts k).run { name := "mojo_ret" }
    g.assign (hint p ty)
    for m in st.dbgs do logInfo m
    return st.opens

end Ops

/-- **`mojo_ret`** proves an elementwise kernel's `Elem` steps and `Ret`:

* a goal `Elem m₀ out w cell bs K me`, from a hypothesis `SEff.run V (vals V S.nodes) S.effs =
  .ok me` of a concrete summary `S` and one `Elem m₀ out w cell bs k M`, `M` the memory of `V`:
  `S`'s loads keep `Elem` (their blocks other than `out` by `omega`), its stores advance it by
  one thread (`V.ctx.who.thread = k`, the pointer `⟨out, cell k⟩` and the bytes `bs k` by
  mojo_vals' equalities), and when the effects end one thread short of `K`, that thread `k` is
  skipped by `bs k = none` (one at most);
* a goal `∃ ps ∈ paths, Ret V (Elem m₀ out w cell bs K) ps`, from `Elem m₀ out w cell bs k M`:
  the first path whose premises mojo_obl proves (`Walk`) and whose blocks' effects are such
  steps, splitting on a branch condition when no path is proved outright; the same for
  `RetWith c V (Elem m₀ out w cell bs K) ps`, for every flag `c` (`WalkWith c`, each block after
  the first entered through `Valuation.intoWith c`);
* a goal `Elem.Only out S me`, from the run of the first case and `Elem.Only out S M`: every
  effect when `omega` proves `V`'s thread in `S`, otherwise the loads through blocks other than
  `out` (by `omega`) and, from the first store on, every effect with the thread in `S` left open.

The node values are mojo_obl's, found from the hypotheses as mojo_obl finds them, or a hypothesis
`vals V S.nodes = ws`. Each premise it does not prove is left as a goal and logged as
`mojo_ret: open goal`; on a `Ret` or `RetWith` goal where no path is proved, these are the first
path's. It
fails on a goal of another form and when the hypotheses it needs (the run, the `Elem` or
`Elem.Only` at `V`'s memory) are missing. -/
syntax (name := mojoRet) "mojo_ret" : tactic

open Lean Elab Tactic in
/-- Runs `mojo_ret` on the main goal. -/
@[tactic mojoRet] def evalMojoRet : Tactic := fun _ => do
  let g ← getMainGoal
  let gs ← Ops.run g
  replaceMainGoal gs.toList

end MojoProof.Sym
