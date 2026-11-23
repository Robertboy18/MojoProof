import MojoProof.Sem.Thread

/-!
# Symbolic values: an indexed node table

The terms the block checker (`summarize`, MojoProof/Sym/Checker.lean) writes a block's
registers, memory effects and obligations in, and what they denote. A block's symbolic values
form a DAG stored as a node table: one node (`SNode`) per distinct float constant, then one per
statement that defines a value, in the statements' order, whose operands (`SVal`) are atoms or
earlier nodes by index, so a value used twice is one node referred to twice (the table has as
many nodes as the block has distinct float constants and value-defining statements, and one more
for each `getelementptr` on a global, whatever the sharing).

* `SVal`: an operand. Atoms are the registers at the block entry (kernel arguments and values
  from earlier blocks alike, `SVal.reg`) and integer constants (`SVal.int`); `SVal.node j` is
  the `j`-th node of the table.
* `SNode`: a node. Integer operators with their width, integer casts, integer `icmp`,
  `extractvalue`, `getelementptr`, float operators with their flags and the step number whose oracle
  numbers they read (`SNode.fbin`, `n` steps after the block entry), memory reads from the entry
  memory (`SNode.load`), calls of a special register or of the lane number (`SNode.call`), integer
  `select` with its width (`SNode.select`) and the integer maximum and minimum (`SNode.minmax`, the
  calls of `llvm.smax`, `llvm.smin`, `llvm.umax` and `llvm.umin`), float operators whose operands'
  `fmul contract` operands are terms of the table (`SNode.fbinP`, for the checker `coversC`;
  `SNode.factors`, `SVal.factors`: the operand terms of an `fmul contract` node), float constants
  (`SNode.flit`, which carries the literal; the table holds one per float constant operand of the
  block, before the statements' nodes), and the other casts (`SNode.castAt`: `bitcast`, the float
  casts, `ptrtoint` and the others `castV` evaluates, which the checker admits by `castOk`, not
  `fptoui`, `fptosi` or `inttoptr`; with the step number whose oracle numbers a float cast
  reads), and the pointer of a global a statement's operand names (`SNode.globalAt`, the
  checker's node for the base of a `getelementptr` on a global; its value is the context's
  address of the global, `Ctx.globals`), and memory reads after a `store` (`SNode.loadAfter`:
  from the memory the block's effects before the read make, which the node carries). A node whose
  instruction has a type the node does not
  hold (a `getelementptr`'s source type, a `load`'s type, a call's declaration, a cast's types)
  or a name (a global's) names the statement by its block label and position, and its value reads
  the type or the name there.
* `SNode.eval`, `SVal.eval`, `vals`: the value of a node given the values of the nodes before it,
  under a `Valuation` (the context, the function, the thread's step count, the memory, registers and
  `fmul contract` operands at the block entry), computed by the semantics' own operations (`intBin`,
  `icmpV`, `intCast`, `castV`, `extractV`, `withAttrs`, `gep`, `Mem.load`, `floatBin`, `selectV`,
  `intMinMax`, `floatLit`), faults included, with the `fmul contract` operands of an `fbinP` node's
  operands from their terms (`prodVal`, `SVal.prodsWith`); `vals V ns` is the list of the values of
  table `ns`, each node evaluated once, from the values before it (a fold over the table), so a
  float constant's literal is evaluated once however often the block uses it.
* `scanSnoc f ns`: the list each of whose entries is `f` of the entries before it and the next
  element of `ns` (the fold `vals` is, at `SNode.eval`, and `roles`, MojoProof/Sym/Payload.lean,
  at `SNode.pay`). Proved for every `f` and list: `scanSnoc_fold`, `scanSnoc_length` (one entry per
  element), `scanSnoc_snoc`, `scanSnoc_append` and `scanSnoc_getElem?` (entry `j` is `f` of the
  entries of the first `j` elements and element `j`).
* `SEff`, `SEff.run`: a block's memory effects (the trace entry of a `load`, the bytes and trace
  entry of a `store`) and the memory they make from the entry memory; `SVal.before` and
  `SEff.before`: the operands refer to nodes before a given index only.
* `Cond`, `Cond.Holds`: the obligations a block summary carries (an operand evaluates without a
  fault, a branch condition evaluates to a word, the effects run without a fault), with a
  decision procedure the kernel evaluates (`Cond.decHolds`).

Proved, for every valuation and table: `vals_fold`, `vals_length` (one value per node),
`vals_snoc` (the value of an appended node is its evaluation on the values before it),
`vals_append` (appending nodes keeps the values before), `vals_getElem?` (entry `j` is node `j`'s
value on the values before it), the `scanSnoc` lemmas at `SNode.eval`; `vals_flit` (a float
constant node's value is its literal's, `floatLit`), `SNode.eval_castAt` (a cast node's value is
`castV` at its statement's operator and types), `SNode.eval_globalAt` (a global's node is the
context's address of the global), `SNode.eval_bitcast` (a `bitcast` node between
scalar types of the same width keeps its operand's word, by `bitcast_bits`, for every layout and
word), `SVal.eval_before` (an operand that refers to nodes of a prefix has the same value on the
longer table) and its corollary `SVal.eval_append`; and the effect-run lemmas
`SEff.run_snoc`, `SEff.run_prefix`, `SEff.run_append`, and `SEff.run_before` (effects that refer
to nodes of a prefix run the same on the longer table, by `SVal.eval_before`).

`SVal`, `SNode`, `SEff` and `Cond` have decidable equality that the kernel reduces (derived; no
field has the type `Ty`, whose derived equality the kernel does not reduce; two `SNode.flit`
nodes compare their literals' strings and numbers, so no `floatLit` is evaluated), so `covers`
compares a computed summary with a given one by `decide`, in time linear in the table's size.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- An operand of a node (see the module docstring). -/
inductive SVal where
  /-- Register `r` at the block entry. -/
  | reg (r : Nat)
  /-- The integer constant `i` at width `w`. -/
  | int (w : Nat) (i : Int)
  /-- The `j`-th node of the table. -/
  | node (j : Nat)
  deriving DecidableEq, Repr, Inhabited, Lean.ToExpr

/-- A memory effect of a block. -/
inductive SEff where
  /-- The trace entry of the `load` at position `pc` of block `lbl` through `p`. -/
  | load (lbl pc : Nat) (p : SVal)
  /-- The `store` at position `pc` of block `lbl` of `v` through `p`. -/
  | store (lbl pc : Nat) (v p : SVal)
  deriving DecidableEq, Repr, Inhabited, Lean.ToExpr

/-- A node of the table (see the module docstring). -/
inductive SNode where
  /-- Integer operator `op` with flags `fl` at width `w` (lane by lane). -/
  | bin (op : BinOp) (fl : IntFlags) (w : Nat) (a b : SVal)
  /-- `icmp p` of integers of width `w`. -/
  | icmp (p : ICmp) (w : Nat) (a b : SVal)
  /-- Integer cast `op` (`trunc`, `zext` or `sext`) to width `w` (lane by lane). -/
  | cast (op : CastOp) (w : Nat) (a : SVal)
  /-- `extractvalue` at indices `is`. -/
  | extract (is : List Nat) (a : SVal)
  /-- The result of the call of a special register or of the lane number at position `pc` of block
  `lbl`. -/
  | call (lbl pc : Nat)
  /-- The `getelementptr` at position `pc` of block `lbl`, on base `base` and index `idx`. -/
  | gep (lbl pc : Nat) (base idx : SVal)
  /-- The `load` at position `pc` of block `lbl`, through pointer `p`, from the entry memory. -/
  | load (lbl pc : Nat) (p : SVal)
  /-- Float operator `op` with flags `fm` on floats `ft`, at the step `n` steps after the block
  entry (whose oracle numbers it reads). -/
  | fbin (op : FBinOp) (fm : FastMath) (ft : FloatTy) (n : Nat) (a b : SVal)
  /-- `select` on condition `c` of the integers `a` and `b` of width `w`. -/
  | select (w : Nat) (c a b : SVal)
  /-- The integer maximum (`max`) or minimum of `a` and `b`, signed or unsigned (`signed`): the
  call of a declaration that `P.intrinsics` names `minmax signed max t` (`llvm.smax`,
  `llvm.smin`, `llvm.umax`, `llvm.umin`). -/
  | minmax (signed max : Bool) (a b : SVal)
  /-- Float operator `op` with flags `fm` on floats `ft`, at the step `n` steps after the block
  entry, as `fbin`, whose operands' `fmul contract` operands are given by the terms `pa` and `pb`
  (`SVal.prodsWith`: the operand's own when `none`): an `fadd contract` or `fsub contract` on the
  result of an `fmul contract` of the same block, whose operand terms these are. -/
  | fbinP (op : FBinOp) (fm : FastMath) (ft : FloatTy) (n : Nat) (a b : SVal)
      (pa pb : Option (SVal × SVal))
  /-- The float constant `lit` at float type `ft`: Sem's `floatLit ft lit`
  (MojoProof/Sem/Eval.lean), the value `evalV` gives the constant. It reads neither the
  valuation nor other nodes; the checker puts one at the head of the table for each float
  constant operand of the block (`litNodes`, MojoProof/Sym/Checker.lean). -/
  | flit (ft : FloatTy) (lit : FloatLit)
  /-- The cast at position `pc` of block `lbl` on `a`, with the statement's operator and types
  (`castV`), at the step `n` steps after the block entry (whose oracle numbers a float cast
  reads). -/
  | castAt (lbl pc n : Nat) (a : SVal)
  /-- The pointer of the global that operand `i` (`Inst.operands`) of the statement at position
  `pc` of block `lbl` names: the address of its block in the context (`Ctx.globals`, which
  `Grid.start` sets for each thread block). It names the statement, not the global's name, so
  the node's equality compares numbers only. -/
  | globalAt (lbl pc i : Nat)
  /-- The `load` at position `pc` of block `lbl`, through pointer `p`, from the memory the
  effects `es` make from the entry memory (`SEff.run`): a `load` after a `store` of the block,
  whose effects before it are `es`. -/
  | loadAfter (lbl pc : Nat) (p : SVal) (es : List SEff)
  deriving DecidableEq, Repr, Inhabited

/-- The operand terms of node `nd` when it is an `fmul contract` (an `fbin` or `fbinP` node with
`op = .fmul` and the flag `contract`), whose values `exec` records as the product; `none` for
every other node. -/
def SNode.factors : SNode → Option (SVal × SVal)
  | .fbin op fm _ _ a b | .fbinP op fm _ _ a b _ _ =>
    if op == .fmul && fm.contract then some (a, b) else none
  | _ => none

/-- The `fmul contract` operand terms of operand `x` in table `ns`: those of node `j` for
`x = .node j` (`SNode.factors`), and `none` for a register or a constant. -/
def SVal.factors (ns : List SNode) : SVal → Option (SVal × SVal)
  | .node j => ns[j]?.bind SNode.factors
  | _ => none

/-- What symbolic values denote in: the context, the function, the thread's step count, and the
memory, registers and `fmul contract` operands at the block entry. -/
structure Valuation where
  /-- The valuation of a context, function, step count, memory, registers and `fmul contract`
  operands. -/
  mk ::
  /-- The context. -/
  ctx : Ctx
  /-- The function. -/
  fn : Func
  /-- The thread's step count at the block entry. -/
  k : Nat
  /-- The memory at the block entry. -/
  mem : Mem
  /-- The registers at the block entry. -/
  regs : Nat → Option Val
  /-- The `fmul contract` operands at the block entry. -/
  prods : Nat → Option (Val × Val)

/-- The statement at position `pc` of block `lbl` of the valuation's function. -/
def Valuation.stmt (V : Valuation) (lbl pc : Nat) : Option Stmt :=
  (V.fn.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?)

/-- The `fmul contract` operands an operand carries: an entry register's. -/
def SVal.prods (V : Valuation) : SVal → Option (Val × Val)
  | .reg r => V.prods r
  | _ => none

/-- Lane `i` of a pair of `fmul contract` operands. -/
def laneOf (p : Option (Val × Val)) (i : Nat) : Option (Val × Val) :=
  p.map fun (u, v) => (u.lane i, v.lane i)

/-- The value of operand `x` under valuation `V`, given the values `vs` of the nodes. -/
def SVal.eval (V : Valuation) (vs : List (Except Fault Val)) : SVal → Except Fault Val
  | .reg r => match V.regs r with
    | some v => pure v
    | none => throw (.unsupported "register with no value at the block entry")
  | .int w i => pure (.bits w (BitVec.ofInt w i))
  | .node j => vs[j]?.getD (throw (.unsupported "symbolic node not in the table"))

/-- The values of the operand terms `pq` of an `fmul contract` under valuation `V`, given the
values `vs` of the nodes: the pair of their values when both evaluate, else `none`. -/
def prodVal (V : Valuation) (vs : List (Except Fault Val)) (pq : SVal × SVal) :
    Option (Val × Val) := do
  some ((← (pq.1.eval V vs).toOption), (← (pq.2.eval V vs).toOption))

/-- The `fmul contract` operands of operand `x` given the terms `o`: those `x` carries as an
entry register (`SVal.prods`) when `o = none`, else the values of the terms (`prodVal`). -/
def SVal.prodsWith (V : Valuation) (vs : List (Except Fault Val)) (x : SVal) :
    Option (SVal × SVal) → Option (Val × Val)
  | none => x.prods V
  | some pq => prodVal V vs pq

/-- Effect `e` on memory `m` under valuation `V`, given the values `vs` of the nodes. -/
def SEff.apply (V : Valuation) (vs : List (Except Fault Val)) (m : Mem) : SEff → Except Fault Mem
  | .load lbl pc p => match V.stmt lbl pc with
    | some ⟨_, .load _ t (.mk (.ptr _) _) _, md⟩ => do
      let q ← (← p.eval V vs).addr?
      pure (m.log (.access ⟨V.ctx.who, q, V.ctx.prog.layout.stored t, false, none,
        md.any (·.1 == "invariant.load")⟩))
    | _ => throw (.unsupported "symbolic load at no load")
  | .store lbl pc v p => match V.stmt lbl pc with
    | some ⟨_, .store _ (.mk t _) (.mk (.ptr a) _) al, _⟩ => do
      let x ← v.eval V vs
      m.store V.ctx.prog.layout V.ctx.who a t x (← (← p.eval V vs).addr?)
        (some (al.getD (V.ctx.prog.layout.align t)))
    | _ => throw (.unsupported "symbolic store at no store")

/-- The memory effects `es`, in order, from the entry memory, given the values `vs` of the
nodes. -/
def SEff.run (V : Valuation) (vs : List (Except Fault Val)) (es : List SEff) : Except Fault Mem :=
  es.foldlM (SEff.apply V vs) V.mem

/-- The value of node `nd` under valuation `V`, given the values `vs` of the nodes before it,
with the faults of the instruction it stands for. -/
def SNode.eval (V : Valuation) (vs : List (Except Fault Val)) : SNode → Except Fault Val
  | .bin op fl w a b => do lanes2 (fun _ => intBin w op fl) (← a.eval V vs) (← b.eval V vs)
  | .icmp p w a b => do
    icmpV V.ctx.prog.layout V.mem p (.int w) (← a.eval V vs) (← b.eval V vs)
  | .cast op w a => do lanes (fun _ => intCast op w) (← a.eval V vs)
  | .extract is a => do extractV (← a.eval V vs) is
  | .call lbl pc => match V.stmt lbl pc with
    | some ⟨_, .call _ _ (.fn g) [], _⟩ =>
      match V.ctx.prog.module.funcs.find? (·.name == g), V.ctx.prog.intrinsics.lookup g with
      | some fn, some (.sreg r d) => withAttrs V.ctx.prog.layout V.mem fn.ret fn.retAttrs
          (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg r d)))
      | some fn, some .laneid => withAttrs V.ctx.prog.layout V.mem fn.ret fn.retAttrs
          (.bits 32 (BitVec.ofNat 32 V.ctx.env.laneid))
      | _, _ => throw (.unsupported "symbolic call of no special register")
    | _ => throw (.unsupported "symbolic call at no call")
  | .gep lbl pc base idx => match V.stmt lbl pc with
    | some ⟨_, .gep fl src (.mk (.ptr a) _) [_], _⟩ => do
      let i ← idx.eval V vs
      MojoProof.Sem.gep V.ctx.prog.layout V.mem fl src a [i] (← base.eval V vs)
    | _ => throw (.unsupported "symbolic getelementptr at no getelementptr")
  | .load lbl pc p => match V.stmt lbl pc with
    | some ⟨_, .load _ t (.mk (.ptr a) _) al, md⟩ => do
      let q ← (← p.eval V vs).addr?
      let v ← V.mem.load V.ctx.prog.layout V.ctx.who a t q
        (some (al.getD (V.ctx.prog.layout.align t)))
      bif md.any (·.1 == "noundef") && !v.defined then throw (.ub "noundef load not defined")
      else pure v
    | _ => throw (.unsupported "symbolic load at no load")
  | .fbin op fm ft n a b => do
    let x ← a.eval V vs
    let y ← b.eval V vs
    lanes2 (fun i u v => floatBin ft op fm u v (laneOf (a.prods V) i) (laneOf (b.prods V) i)
      (V.ctx.oracle (Nat.pair (V.k + n) i))) x y
  | .select w c a b => do selectV (.int w) (← c.eval V vs) (← a.eval V vs) (← b.eval V vs)
  | .minmax signed max a b => do intMinMax signed max (← a.eval V vs) (← b.eval V vs)
  | .fbinP op fm ft n a b pa pb => do
    let x ← a.eval V vs
    let y ← b.eval V vs
    lanes2 (fun i u v => floatBin ft op fm u v (laneOf (a.prodsWith V vs pa) i)
      (laneOf (b.prodsWith V vs pb) i) (V.ctx.oracle (Nat.pair (V.k + n) i))) x y
  | .flit ft lit => floatLit ft lit
  | .castAt lbl pc n a => match V.stmt lbl pc with
    | some ⟨_, .cast op (.mk s _) t, _⟩ => do
      castV V.ctx.prog.layout V.mem op s (← a.eval V vs) t
        fun i => V.ctx.oracle (Nat.pair (V.k + n) i)
    | _ => throw (.unsupported "symbolic cast at no cast")
  | .globalAt lbl pc i => match V.stmt lbl pc with
    | some st => match st.inst.operands[i]? with
      | some (.mk _ (.glob g)) => match V.ctx.globals g with
        | some p => pure (.ptr p)
        | none => throw (.unsupported "symbolic global with no block")
      | _ => throw (.unsupported "symbolic global at no global operand")
    | none => throw (.unsupported "symbolic global at no statement")
  | .loadAfter lbl pc p es => match V.stmt lbl pc with
    | some ⟨_, .load _ t (.mk (.ptr a) _) al, md⟩ => do
      let q ← (← p.eval V vs).addr?
      let m ← SEff.run V vs es
      let v ← m.load V.ctx.prog.layout V.ctx.who a t q
        (some (al.getD (V.ctx.prog.layout.align t)))
      bif md.any (·.1 == "noundef") && !v.defined then throw (.ub "noundef load not defined")
      else pure v
    | _ => throw (.unsupported "symbolic load at no load")

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

/-- The values of the nodes of table `ns` under valuation `V`, in order: each node is evaluated
once, on the values of the nodes before it. This is `scanSnoc` at node evaluation, written out so
that `simp` unfolds it to the fold, and its lemmas below are `scanSnoc`'s there. -/
def vals (V : Valuation) (ns : List SNode) : List (Except Fault Val) :=
  ns.foldl (fun vs nd => vs ++ [nd.eval V vs]) []

/-- The fold of `vals` from values `acc` only appends (`scanSnoc_fold`). -/
theorem vals_fold (V : Valuation) (ns : List SNode) (acc : List (Except Fault Val)) :
    ∃ ws, ns.foldl (fun vs nd => vs ++ [nd.eval V vs]) acc = acc ++ ws ∧
      ws.length = ns.length :=
  scanSnoc_fold (fun vs nd => SNode.eval V vs nd) ns acc

/-- One value per node (`scanSnoc_length`). -/
theorem vals_length (V : Valuation) (ns : List SNode) : (vals V ns).length = ns.length :=
  scanSnoc_length (fun vs nd => SNode.eval V vs nd) ns

/-- The values of a table with node `nd` appended: the values of the table, then `nd`'s value on
them (`scanSnoc_snoc`). -/
theorem vals_snoc (V : Valuation) (ns : List SNode) (nd : SNode) :
    vals V (ns ++ [nd]) = vals V ns ++ [nd.eval V (vals V ns)] :=
  scanSnoc_snoc (fun vs nd => SNode.eval V vs nd) ns nd

/-- Appending nodes keeps the values of the nodes before (`scanSnoc_append`). -/
theorem vals_append (V : Valuation) (ns ns' : List SNode) :
    ∃ ws, vals V (ns ++ ns') = vals V ns ++ ws :=
  scanSnoc_append (fun vs nd => SNode.eval V vs nd) ns ns'

/-- **Entry `j` of a table's values**: for every valuation, table `ns` and `j`, entry `j` of
`vals V ns` is node `j`'s value on the values of the nodes before it, and there is none when `ns`
has no node `j`. -/
theorem vals_getElem? (V : Valuation) (ns : List SNode) (j : Nat) :
    (vals V ns)[j]? = ns[j]?.map fun nd => nd.eval V (vals V (ns.take j)) :=
  scanSnoc_getElem? (fun vs nd => SNode.eval V vs nd) ns j

/-- **A float constant node's value**: for every valuation and table `ns` whose node `j` is
`SNode.flit ft lit`, entry `j` of `vals V ns` is the literal's value `floatLit ft lit`. -/
theorem vals_flit (V : Valuation) {ns : List SNode} {j : Nat} {ft : FloatTy} {lit : FloatLit}
    (h : ns[j]? = some (.flit ft lit)) : (vals V ns)[j]? = some (floatLit ft lit) := by
  rw [vals_getElem?, h]
  rfl

/-- **A cast node's value**: for every valuation `V`, node values `vs`, step offset `n`, operand
`a`, and statement at position `pc` of block `lbl` that casts by `op` from type `s` to type `t`,
the node `.castAt lbl pc n a` is `castV` of `a`'s value at the entry memory, whose lane `i` gets
the oracle number of step `V.k + n` and lane `i`. -/
theorem SNode.eval_castAt {V : Valuation} {vs : List (Except Fault Val)} {lbl pc n : Nat}
    {a : SVal} {dst : Option Nat} {op : CastOp} {s t : Ty} {x : Value} {md : List (String × Nat)}
    (hs : V.stmt lbl pc = some ⟨dst, .cast op (.mk s x) t, md⟩) :
    (SNode.castAt lbl pc n a).eval V vs = (do
      castV V.ctx.prog.layout V.mem op s (← a.eval V vs) t
        fun i => V.ctx.oracle (Nat.pair (V.k + n) i)) := by
  simp only [SNode.eval, hs]

/-- **A global's node**: for every valuation `V`, node values `vs`, and statement `st` at position
`pc` of block `lbl` whose operand `i` (`Inst.operands`) is the global `g` at type `t`, to which
the context gives the address `p` (`Ctx.globals`), the node `.globalAt lbl pc i` is the pointer
`p`. -/
theorem SNode.eval_globalAt {V : Valuation} {vs : List (Except Fault Val)} {lbl pc i : Nat}
    {st : Stmt} {t : Ty} {g : String} {p : Ptr} (hs : V.stmt lbl pc = some st)
    (ho : st.inst.operands[i]? = some (.mk t (.glob g))) (hg : V.ctx.globals g = some p) :
    (SNode.globalAt lbl pc i).eval V vs = .ok (.ptr p) := by
  simp only [SNode.eval, hs, ho, hg]
  rfl

/-- **A scalar `bitcast` of the same width keeps the word**: for every layout `l`, source type `s`
of width `w` under `l`, scalar target type `t` (an integer, float or pointer type) of width `w`
and `w`-bit word `x`, `bitcast l s t (.bits w x)` is `x` again. -/
theorem bitcast_bits (l : Layout) {s t : Ty} {w : Nat} (hs : l.scalarBits s = w)
    (ht : t.scalar = true) (hw : l.scalarBits t = w) (x : BitVec w) :
    bitcast l s t (.bits w x) = .ok (.bits w x) := by
  have hb : toBitList l s (.bits w x) = .ok ((List.range w).map fun j => some (x.getLsbD j)) := by
    have e : toBitList l s (.bits w x) = toBitList.scalarBitList (l.scalarBits s) (.bits w x) := by
      cases s <;> rfl
    rw [e, hs]
    simp only [toBitList.scalarBitList, ite_true]
    rfl
  have hv := ofBitList.scalar_slice w x 0
  simp only [Nat.zero_add, BitVec.extractLsb'_eq_self] at hv
  cases t <;> simp only [Ty.scalar, Bool.false_eq_true] at ht
  all_goals
    unfold bitcast
    split
    · rfl
    · simp only [hb, bind, Except.bind, List.length_map, List.length_range, hw, ite_true, ofBitList,
        hv]
      rfl

/-- **A same-width scalar `bitcast` node keeps its operand's word**: for every valuation `V`, node
values `vs`, step offset `n` and operand `a` whose value is a `w`-bit word `u`, if the statement
at position `pc` of block `lbl` is a `bitcast` from a type `s` to a scalar type `t`, both of width
`w` under the program's layout, then the node `.castAt lbl pc n a` evaluates to `u`
(`SNode.eval_castAt`, `bitcast_bits`). -/
theorem SNode.eval_bitcast {V : Valuation} {vs : List (Except Fault Val)} {lbl pc n : Nat}
    {a : SVal} {dst : Option Nat} {s t : Ty} {y : Value} {md : List (String × Nat)} {w : Nat}
    {u : BitVec w} (hs : V.stmt lbl pc = some ⟨dst, .cast .bitcast (.mk s y) t, md⟩)
    (hsw : V.ctx.prog.layout.scalarBits s = w) (ht : t.scalar = true)
    (htw : V.ctx.prog.layout.scalarBits t = w) (ha : a.eval V vs = .ok (.bits w u)) :
    (SNode.castAt lbl pc n a).eval V vs = .ok (.bits w u) := by
  rw [SNode.eval_castAt hs, ha]
  exact bitcast_bits _ hsw ht htw u

/-- Whether operand `x` refers to nodes before `n` only. -/
def SVal.before (n : Nat) : SVal → Bool
  | .node j => decide (j < n)
  | _ => true

/-- **An operand that refers to nodes of `vs` only has the same value on every longer table**:
for every valuation, node values `vs` and `us` and operand `x` that refers to nodes before
`vs.length` only (`SVal.before`), `x`'s value on `vs ++ us` is its value on `vs`. -/
theorem SVal.eval_before {V : Valuation} {vs : List (Except Fault Val)} {x : SVal}
    (h : x.before vs.length = true) (us : List (Except Fault Val)) :
    x.eval V (vs ++ us) = x.eval V vs := by
  cases x with
  | node j =>
    simp only [SVal.before, decide_eq_true_eq] at h
    simp only [SVal.eval, List.getElem?_append_left h]
  | _ => rfl

/-- An operand that refers to nodes of `vs` only has its value on `vs` on every longer table
(`SVal.eval_before`). -/
theorem SVal.eval_append {V : Valuation} {vs : List (Except Fault Val)} {x : SVal} {v : Val}
    (hx : ∀ j, x = .node j → j < vs.length) (h : x.eval V vs = .ok v)
    (us : List (Except Fault Val)) : x.eval V (vs ++ us) = .ok v :=
  (SVal.eval_before (by cases x <;> first | rfl | exact decide_eq_true (hx _ rfl)) us).trans h

/-- An obligation of a block summary. -/
inductive Cond where
  /-- `x` evaluates without a fault. -/
  | ok (x : SVal)
  /-- `x` evaluates to a word (a branch condition). -/
  | bool (x : SVal)
  /-- The effects `es` run without a fault. -/
  | mem (es : List SEff)
  deriving DecidableEq, Repr, Inhabited

/-- Obligation `d` holds under valuation `V`, given the values `vs` of the nodes. -/
def Cond.Holds (V : Valuation) (vs : List (Except Fault Val)) : Cond → Prop
  | .ok x => ∃ v, x.eval V vs = .ok v
  | .bool x => ∃ w b, x.eval V vs = .ok (.bits w b)
  | .mem es => ∃ m, SEff.run V vs es = .ok m

/-- Whether obligation `d` holds, decided by evaluating it (the kernel reduces it, so a concrete
valuation's obligations are checked by `decide +kernel`). -/
instance Cond.decHolds (V : Valuation) (vs : List (Except Fault Val)) (d : Cond) :
    Decidable (d.Holds V vs) :=
  match d with
  | .ok x => match h : x.eval V vs with
    | .ok v => isTrue ⟨v, h⟩
    | .error _ => isFalse fun ⟨_, hv⟩ => by rw [h] at hv; cases hv
  | .bool x => match h : x.eval V vs with
    | .ok (.bits w b) => isTrue ⟨w, b, h⟩
    | .ok .poison => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
    | .ok .undef => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
    | .ok (.ptr _) => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
    | .ok (.vec _) => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
    | .ok (.agg _) => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
    | .error _ => isFalse fun ⟨_, _, hv⟩ => by rw [h] at hv; cases hv
  | .mem es => match h : SEff.run V vs es with
    | .ok m => isTrue ⟨m, h⟩
    | .error _ => isFalse fun ⟨_, hv⟩ => by rw [h] at hv; cases hv

/-- The effects `es ++ [e]` run: `es` runs, and `e` applies to its memory. -/
theorem SEff.run_snoc {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} {e : SEff}
    {m : Mem} (h : SEff.run V vs (es ++ [e]) = .ok m) :
    ∃ m₀, SEff.run V vs es = .ok m₀ ∧ e.apply V vs m₀ = .ok m := by
  simp only [SEff.run, List.foldlM_append, List.foldlM_cons, List.foldlM_nil] at h
  obtain ⟨m₀, h₀, h⟩ := Except.bind_eq_ok.1 h
  obtain ⟨m₁, h₁, h⟩ := Except.bind_eq_ok.1 h
  cases h
  exact ⟨m₀, h₀, h₁⟩

/-- The effects `es ++ es'` that run without a fault: so do `es`. -/
theorem SEff.run_prefix {V : Valuation} {vs : List (Except Fault Val)} {es es' : List SEff}
    {m : Mem} (h : SEff.run V vs (es ++ es') = .ok m) : ∃ m₀, SEff.run V vs es = .ok m₀ := by
  simp only [SEff.run, List.foldlM_append] at h
  obtain ⟨m₀, h₀, _⟩ := Except.bind_eq_ok.1 h
  exact ⟨m₀, h₀⟩

/-- The effects `es` that run to `m`, and effect `e` that applies to `m`: `es ++ [e]` runs. -/
theorem SEff.run_append {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} {e : SEff}
    {m m' : Mem} (h : SEff.run V vs es = .ok m) (h' : e.apply V vs m = .ok m') :
    SEff.run V vs (es ++ [e]) = .ok m' := by
  simp only [SEff.run, List.foldlM_append, List.foldlM_cons, List.foldlM_nil]
  exact Except.bind_eq_ok.2 ⟨_, h, Except.bind_eq_ok.2 ⟨_, h', rfl⟩⟩

/-- Whether the operands of effect `e` refer to nodes before `n` only. -/
def SEff.before (n : Nat) : SEff → Bool
  | .load _ _ p => p.before n
  | .store _ _ v p => v.before n && p.before n

/-- **Effects that refer to nodes of `vs` only run the same on every longer table**: for every
valuation, node values `vs` and `us` and effects `es` whose operands refer to nodes before
`vs.length` (`SEff.before`), `SEff.run` on `vs ++ us` is `SEff.run` on `vs`. -/
theorem SEff.run_before {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff}
    (h : es.all (·.before vs.length) = true) (us : List (Except Fault Val)) :
    SEff.run V (vs ++ us) es = SEff.run V vs es := by
  have ha : ∀ (e : SEff), e.before vs.length = true → ∀ m,
      e.apply V (vs ++ us) m = e.apply V vs m := by
    intro e he m
    cases e with
    | load lbl pc p =>
      simp only [SEff.before] at he
      simp only [SEff.apply, SVal.eval_before he]
    | store lbl pc v p =>
      simp only [SEff.before, Bool.and_eq_true] at he
      simp only [SEff.apply, SVal.eval_before he.1, SVal.eval_before he.2]
  unfold SEff.run
  generalize V.mem = m
  induction es generalizing m with
  | nil => rfl
  | cons e es ih =>
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [List.foldlM_cons, ha e h.1 m]
    congr 1
    funext m'
    exact ih h.2 m'

/-- A fold in `Except` whose step keeps `x` on every element returns `x`. -/
theorem foldlM_fix {ε α β : Type} {f : β → α → Except ε β} {x : β} :
    ∀ {as : List α}, (∀ a ∈ as, f x a = .ok x) → as.foldlM f x = .ok x
  | [], _ => rfl
  | a :: as, h => by
    rw [List.foldlM_cons, h a (by simp)]
    exact foldlM_fix fun b hb => h b (List.mem_cons_of_mem a hb)

end MojoProof.Sym
