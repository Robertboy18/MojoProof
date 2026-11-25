import MojoProof.Sym.Term

/-!
# The block checker: symbolic execution of a block and the check of its summary

`covers P fn lbl p0 ds S`, a Boolean function the kernel evaluates (`decide +kernel`), checks
that `S` is the summary of block `lbl` of function `fn` of program `P` from position `p0`, and
that its obligations come first in the conditions `ds`.

`summarize P fn lbl p0` runs block `lbl` of `fn` symbolically from position `p0` (the position
after the block's `phi`s) from a table that holds one node per distinct float constant operand
of the block (`SState.start`, `litNodes`: `SNode.flit`, whose value is Sem's `floatLit` of the
literal): each statement that defines a value appends one node to the node table (`SNode`,
MojoProof/Sym/Term.lean) whose operands are the registers' entries in the table (`SState.op`: an
earlier node, an entry register, an integer constant or a float constant's node), sets its
register to the new node, and adds the obligation that the node evaluates without a fault
(`SState.def`); a `load` and a `store` also add their memory effect; the terminator gives the
exit (`Exit`: a branch, with the obligation that a conditional branch's condition evaluates to a
word, or `ret void`; `SState.exitAt`).
The summary (`Summary`) is the table, the registers' entries, the effects, the obligations, the
exit and the number of statements run (`Summary.len`, from `p0` to the terminator); its size is
linear in the block's (one node per float constant and per statement, operands by index).
`covers` holds when `summarize` gives the summary `S` and the obligations of `S` are the first
conditions of `ds` (`List.isPrefixOf`: a check by position, linear).

The fragment: `bin`, scalar integer `icmp`, `trunc` / `zext` / `sext`, the other casts that `castV`
evaluates (`castOk`: not `fptoui`, `fptosi`, `inttoptr` or an ill-typed cast; node `SNode.castAt`,
at the statement's operator and types), `extractvalue`, `insertvalue` (`SNode.insert`),
`extractelement` and `insertelement` (`SNode.eltAt`, `SNode.insEltAt`; an `insertvalue` or
`insertelement` into a `zeroinitializer`, `undef` or `poison`, two nodes: `SNode.constAt` for the
constant, then the insertion into it), `getelementptr` with one index (on a global, two nodes:
`SNode.globalAt` for the global's pointer, then the `getelementptr` on it) and with any other
number of indices on a base that is not a global (`SNode.gepN`),
`load`, `store` (on a global, the `SNode.globalAt` node of the pointer operand, then the `load` or
`store` on it; of a `zeroinitializer`, `undef` or `poison` through a pointer that is not a global,
the `SNode.constAt` node of the stored operand, then the `store` of that node), `fbin` but `fmul
contract` (in the fragment of `coversC`, whose float nodes carry their operands' products:
`SNode.fbinOf`), `select` of integers (node `SNode.select`), calls of a special register or of the
lane number (a declaration that `P.intrinsics` names `sreg r d` or `laneid`, with no arguments and
no fast-math flags, whose attributes `Func.check` accepts: node `SNode.call`), and calls of an
integer maximum or minimum (a declaration that `P.intrinsics` names `minmax signed max t`, with two
arguments, no fast-math flags and no parameter, return or call-site attributes, whose attributes
`Func.check` accepts: node `SNode.minmax`), with operands that are registers, integer constants or
float constants. The nodes of `getelementptr`, `icmp`, `ptrtoint` and the calls of a special
register or the lane number read the entry memory's blocks' addresses and sizes, which the block's
stores keep (`SEff.run_shape`), so the checker takes them after a `store` too; it takes a `load`
after a `store` as `SNode.loadAfter` (on a global, on the global's `SNode.globalAt` node), which
carries the effects before it (the memory it reads; their operands are nodes of the table before
it, `SEff.before`); terminators `br`, `br i1` and `ret void`. A branch to blocks that start with
`phi`s is `Exit.phi`: for each target, each `phi`'s incoming operand from this block must be a
register, an integer constant or a float constant, and its obligation is that the operand
evaluates (`SState.phiConds`; a float constant's obligation is that its node evaluates, which
`decide` checks only when the kernel reduces `floatLit` of the literal). Anything else (other calls
among them) makes `summarize` fail.
`summarize` and `covers` are `summarizeWith` and `coversWith` with the exit function
`SState.exitAt`; `coversTo P fn lbl p0 d₀` is `coversWith` with `SState.exitTo`, whose `br i1` into
blocks with `phi`s has the obligations of its edge into block `d₀` only, so a `phi` operand of the
other edge that is outside the fragment or faults does not refuse the block.
`summarizeAt alloca` and `coversAt alloca` are these with the checker's `alloca` flag
(`SState.alloca`) set to `alloca`; `summarizeWith` and `coversWith` are their instances with the
flag off. With it on, the fragment has `alloca` too (a pointer node `SNode.fresh` to the block at
the number `exec` gives it, the effect `SEff.alloca` that makes the block, and `SState.count` of
the count operand), and after an `alloca` the nodes of `getelementptr`, `icmp` and `ptrtoint`
read the memory the effects before them make (`SNode.gepAfter`, `SNode.gepNAfter`,
`SNode.icmpAfter`, `SNode.castAfter`), as the entry memory has no block where the `alloca` made
one.

This module holds the checker's definitions, which the kernel evaluates; MojoProof/Sym/Block.lean
proves them sound (`Block.sound`, `Block.sound_to`), and MojoProof/Sym/Path.lean along paths
(`Block.sound_pathAt_ptrs`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The value of register `r` given the values `vs` of the nodes and the registers' entries
`regs`: that of its entry, or its value at the block entry. -/
def regVal (V : Valuation) (vs : List (Except Fault Val)) (regs : List (Nat × SVal)) (r : Nat) :
    Option Val :=
  match regs.lookup r with
  | some x => (x.eval V vs).toOption
  | none => V.regs r

/-- The `fmul contract` operands of register `r` given the registers' entries `regs`: none for a
register the block sets, its entry operands otherwise. -/
def regProd (V : Valuation) (regs : List (Nat × SVal)) (r : Nat) : Option (Val × Val) :=
  match regs.lookup r with
  | some _ => none
  | none => V.prods r

/-- The `fmul contract` operands of register `r` given the values `vs` of the nodes, the table
`ns` and the registers' entries `regs`: the values of its entry's `fmul contract` operand terms
(`SVal.factors`, `prodVal`) for a register the block sets, its entry operands otherwise. -/
def regProdIn (V : Valuation) (vs : List (Except Fault Val)) (ns : List SNode)
    (regs : List (Nat × SVal)) (r : Nat) : Option (Val × Val) :=
  match regs.lookup r with
  | some x => (x.factors ns).bind (prodVal V vs)
  | none => V.prods r

/-- The state of symbolic execution: the node table (in order), the registers the block has set
with their entries (latest first), the memory effects (in order), the obligations, whether a
`store` or an `alloca` has run, and whether the checker takes `alloca`. -/
structure SState where
  /-- The state from its node table, register entries, memory effects, obligations, whether a
  `store` or an `alloca` has run, and whether the checker takes `alloca`. -/
  mk ::
  /-- The node table, in order. -/
  nodes : List SNode
  /-- The registers set, latest first, with their entries. -/
  regs : List (Nat × SVal)
  /-- The memory effects, in order. -/
  effs : List SEff
  /-- The obligations. -/
  obls : List Cond
  /-- A `store` or an `alloca` has run. -/
  stored : Bool
  /-- The checker takes `alloca` (`SState.stmt`, `SEff.alloca`, `SNode.fresh`). Off at
  `SState.init` and `SState.start`, so the summaries of `summarizeWith` and the segments allocate
  nothing and their frames keep the entry's `allocas`. -/
  alloca : Bool := false

/-- The state at the block entry. -/
def SState.init : SState := ⟨[], [], [], [], false, false⟩

/-- The entry of register `r`: its node, or the register at the block entry. -/
def SState.get (σ : SState) (r : Nat) : SVal := (σ.regs.lookup r).getD (.reg r)

/-- The entry of operand `a` of type `t`: a register's, an integer constant, or for a float
constant `lit` of float type `ft` the first node `SNode.flit ft lit` of the table (`none` when the
table has none; `summarizeWith` starts from a table that holds one per float constant operand of
the block, `SState.start`). -/
def SState.op (σ : SState) : Ty → Value → Option SVal
  | _, .loc r => some (σ.get r)
  | .int w, .int i => some (.int w i)
  | .fp ft, .float lit => (σ.nodes.findIdx? (· == .flit ft lit)).map .node
  | _, _ => none

/-- The entry of an `alloca`'s count operand: `none` for no count, else `SState.op` of it (`none`
outside the fragment). -/
def SState.count (σ : SState) : Option TValue → Option (Option SVal)
  | none => some none
  | some (.mk ct cv) => (σ.op ct cv).map some

/-- Node `nd` appended to the table, register `res` (if any) set to it, with the obligation that
it evaluates. -/
def SState.def (σ : SState) (res : Option Nat) (nd : SNode) : SState :=
  { σ with nodes := σ.nodes ++ [nd],
           regs := (match res with
             | some r => (r, .node σ.nodes.length) :: σ.regs
             | none => σ.regs),
           obls := .ok (.node σ.nodes.length) :: σ.obls }

/-- The node of float operator `op` with flags `fm` on floats `ft`, `n` steps after the block
entry, on operands `a` and `b` whose `fmul contract` operand terms are `pa` and `pb`
(`SVal.factors`): `SNode.fbin` when both are `none`, else `SNode.fbinP`. -/
def SNode.fbinOf (op : FBinOp) (fm : FastMath) (ft : FloatTy) (n : Nat) (a b : SVal) :
    Option (SVal × SVal) → Option (SVal × SVal) → SNode
  | none, none => .fbin op fm ft n a b
  | pa, pb => .fbinP op fm ft n a b pa pb

/-- The casts `castV` evaluates, by operator `op`, source type `s` and target type `t` (each a
vector's element type when a vector): `trunc`, `zext`, `sext`, `bitcast` and `addrspacecast` at
every type, `fptrunc` and `fpext` from a float type to a float type, `sitofp` and `uitofp` to a
float type, and `ptrtoint` from a pointer type. Not `fptoui`, `fptosi`, `inttoptr`, nor another
operator at other types: there `castV` faults (unsupported) on every operand, and nowhere else
(`castOk_iff`, MojoProof/Sym/Exec.lean, for every layout, memory and choice). -/
def castOk (op : CastOp) (s t : Ty) : Bool :=
  match op, s.elt, t.elt with
  | .trunc, _, _ | .zext, _, _ | .sext, _, _ => true
  | .fptrunc, .fp _, .fp _ | .fpext, .fp _, .fp _ => true
  | .sitofp, _, .fp _ | .uitofp, _, .fp _ => true
  | .bitcast, _, _ => true
  | .ptrtoint, .ptr _, _ => true
  | .addrspacecast, _, _ => true
  | _, _, _ => false

/-- Statement `st` at position `pc` of block `lbl`, `n` statements after the entry, from state
`σ`; `none` outside the fragment. With `contract` (`coversC`), `fmul contract` is in the
fragment too; a float operator's node is `SNode.fbinOf` of its operands' `fmul contract` operand
terms, which is `SNode.fbin` when no node of the table is an `fmul contract` (always so without
`contract`). An `alloca` is in the fragment when the state's `alloca` is set; after one, the
statements that read the blocks' addresses and sizes (`icmp`, `getelementptr`, `ptrtoint`) have
nodes that read the memory the effects before them make (`SNode.icmpAfter`, `SNode.castAfter`,
`SNode.gepAfter`, `SNode.gepNAfter`), not the entry memory, which has no block where the `alloca`
made one. -/
def SState.stmt (P : Program) (lbl pc n : Nat) (σ : SState) (st : Stmt)
    (contract : Bool := false) : Option SState :=
  if st.checkMd.isOk then
    match st.inst with
    | .bin op fl t a b => do
      let x ← σ.op t a
      let y ← σ.op t b
      pure (σ.def st.res (.bin op fl (P.layout.scalarBits t.elt) x y))
    | .icmp p (.int w) a b => if SEff.allocates σ.effs then
        -- after an `alloca`: on the memory the effects before it make
        if σ.effs.all (·.before σ.nodes.length) then do
          let x ← σ.op (.int w) a
          let y ← σ.op (.int w) b
          pure (σ.def st.res (.icmpAfter p w x y σ.effs))
        else none
      else do
      let x ← σ.op (.int w) a
      let y ← σ.op (.int w) b
      pure (σ.def st.res (.icmp p w x y))
    | .cast op (.mk s a) t => if op = .trunc ∨ op = .zext ∨ op = .sext then do
        let x ← σ.op s a
        pure (σ.def st.res (.cast op (P.layout.scalarBits t.elt) x))
      else if castOk op s t = false then none
      else if op == .ptrtoint && SEff.allocates σ.effs then
        -- after an `alloca`: on the memory the effects before it make
        if σ.effs.all (·.before σ.nodes.length) then do
          let x ← σ.op s a
          pure (σ.def st.res (.castAfter lbl pc n x σ.effs))
        else none
      else do
        let x ← σ.op s a
        pure (σ.def st.res (.castAt lbl pc n x))
    | .extractvalue (.mk t a) is => do
      let x ← σ.op t a
      pure (σ.def st.res (.extract is x))
    | .insertvalue (.mk t a) (.mk te e) is =>
      -- into a constant its type gives: the node of the constant, then the `insertvalue` into it
      if tyConst a then do
        let y ← σ.op te e
        pure ((σ.def none (.constAt lbl pc 0)).def st.res (.insert is (.node σ.nodes.length) y))
      else do
        let x ← σ.op t a
        let y ← σ.op te e
        pure (σ.def st.res (.insert is x y))
    | .extractelement (.mk t v) (.mk ti i) => do
      let x ← σ.op t v
      let y ← σ.op ti i
      pure (σ.def st.res (.eltAt lbl pc x y))
    | .insertelement (.mk t v) (.mk te e) (.mk ti i) =>
      -- into a constant its type gives: the node of the constant, then the `insertelement` into it
      if tyConst v then do
        let y ← σ.op te e
        let z ← σ.op ti i
        pure ((σ.def none (.constAt lbl pc 0)).def st.res
          (.insEltAt lbl pc (.node σ.nodes.length) y z))
      else do
        let x ← σ.op t v
        let y ← σ.op te e
        let z ← σ.op ti i
        pure (σ.def st.res (.insEltAt lbl pc x y z))
    | .gep _ _ (.mk (.ptr as) b) [.mk ti i] => if SEff.allocates σ.effs then
        -- after an `alloca`: on the memory the effects before it make
        if σ.effs.all (·.before σ.nodes.length) then match b with
          | .glob _ => do
            let xi ← σ.op ti i
            pure ((σ.def none (.globalAt lbl pc 0)).def st.res
              (.gepAfter lbl pc (.node σ.nodes.length) xi σ.effs))
          | _ => do
            let xi ← σ.op ti i
            let xb ← σ.op (.ptr as) b
            pure (σ.def st.res (.gepAfter lbl pc xb xi σ.effs))
        else none
      else match b with
      -- on a global: the node of its pointer, then the `getelementptr` on that node
      | .glob _ => do
        let xi ← σ.op ti i
        pure ((σ.def none (.globalAt lbl pc 0)).def st.res
          (.gep lbl pc (.node σ.nodes.length) xi))
      | _ => do
        let xi ← σ.op ti i
        let xb ← σ.op (.ptr as) b
        pure (σ.def st.res (.gep lbl pc xb xi))
    | .gep _ _ (.mk (.ptr as) b) idx => if SEff.allocates σ.effs then
        -- after an `alloca`: on the memory the effects before it make
        if σ.effs.all (·.before σ.nodes.length) then do
          let ys ← idx.mapM fun | .mk t v => σ.op t v
          let xb ← σ.op (.ptr as) b
          pure (σ.def st.res (.gepNAfter lbl pc xb ys σ.effs))
        else none
      else do
      -- other than one index, on a base that is not a global (`SState.op` gives none at one)
      let ys ← idx.mapM fun | .mk t v => σ.op t v
      let xb ← σ.op (.ptr as) b
      pure (σ.def st.res (.gepN lbl pc xb ys))
    | .load _ _ (.mk (.ptr as) p) _ => if σ.stored then
        -- after a store: the `load` from the memory the effects before it make (on a global, on
        -- the node of its pointer)
        if σ.effs.all (·.before σ.nodes.length) then match p with
          | .glob _ => pure { (σ.def none (.globalAt lbl pc 0)).def st.res
              (.loadAfter lbl pc (.node σ.nodes.length) σ.effs) with
                effs := σ.effs ++ [.load lbl pc (.node σ.nodes.length)] }
          | _ => do
            let x ← σ.op (.ptr as) p
            pure { σ.def st.res (.loadAfter lbl pc x σ.effs) with
              effs := σ.effs ++ [.load lbl pc x] }
        else none
      else match p with
      -- on a global: the node of its pointer, then the `load` on that node
      | .glob _ => pure { (σ.def none (.globalAt lbl pc 0)).def st.res
          (.load lbl pc (.node σ.nodes.length)) with
            effs := σ.effs ++ [.load lbl pc (.node σ.nodes.length)] }
      | _ => do
        let x ← σ.op (.ptr as) p
        pure { σ.def st.res (.load lbl pc x) with effs := σ.effs ++ [.load lbl pc x] }
    | .store _ (.mk t v) (.mk (.ptr as) p) _ => match p with
      -- on a global: the node of its pointer, then the `store` on that node
      | .glob _ => do
        let x ← σ.op t v
        pure { σ.def none (.globalAt lbl pc 1) with
          effs := σ.effs ++ [.store lbl pc x (.node σ.nodes.length)], stored := true }
      -- a `zeroinitializer`, `undef` or `poison`: the node of its value, then the `store` of
      -- that node
      | _ => if tyConst v then do
          let y ← σ.op (.ptr as) p
          pure { σ.def none (.constAt lbl pc 0) with
            effs := σ.effs ++ [.store lbl pc (.node σ.nodes.length) y], stored := true }
        else do
          let x ← σ.op t v
          let y ← σ.op (.ptr as) p
          pure { σ with effs := σ.effs ++ [.store lbl pc x y], stored := true }
    | .fbin op fm t a b => match t.elt with
      | .fp ft => if !contract && op == .fmul && fm.contract then none else do
        let x ← σ.op t a
        let y ← σ.op t b
        pure (σ.def st.res (.fbinOf op fm ft n x y (x.factors σ.nodes) (y.factors σ.nodes)))
      | _ => none
    | .call fm _ (.fn g) [] => match P.module.funcs.find? (·.name == g) with
      | some fn => match P.intrinsics.lookup g with
        | some (.sreg r d) =>
          if (fm == {}) && fn.blocks.isEmpty && (fn.check P.module (some (.sreg r d))).isOk then
            some (σ.def st.res (.call lbl pc))
          else none
        | some .laneid =>
          if (fm == {}) && fn.blocks.isEmpty && (fn.check P.module (some .laneid)).isOk then
            some (σ.def st.res (.call lbl pc))
          else none
        | _ => none
      | none => none
    | .select (.mk ct c) (.mk (.int w) a) (.mk _ b) => do
      let x ← σ.op ct c
      let y ← σ.op (.int w) a
      let z ← σ.op (.int w) b
      pure (σ.def st.res (.select w x y z))
    | .call fm _ (.fn g) [(.mk ta a, []), (.mk tb b, [])] =>
      match P.module.funcs.find? (·.name == g), P.intrinsics.lookup g with
      | some fn, some (.minmax sg mx t) =>
        if (fm == {}) && fn.blocks.isEmpty && fn.retAttrs.isEmpty && fn.params.length == 2 &&
            fn.params.all (·.attrs.isEmpty) && (fn.check P.module (some (.minmax sg mx t))).isOk
        then do
          let x ← σ.op ta a
          let y ← σ.op tb b
          pure (σ.def st.res (.minmax sg mx x y))
        else none
      | _, _ => none
    | .alloca _ cnt _ => if σ.alloca then do
        -- the pointer to the new block, then the effect that makes it
        let c ← σ.count cnt
        pure { σ.def st.res (.fresh n) with effs := σ.effs ++ [.alloca lbl pc n c], stored := true }
      else none
    | _ => none
  else none

/-- Statements `sts` from position `p0 + n` of block `lbl`, `n` statements after the entry, with
`fmul contract` in the fragment when `contract` (`SState.stmt`). -/
def SState.run (contract : Bool) (P : Program) (lbl p0 : Nat) :
    List Stmt → Nat → SState → Option SState
  | [], _, σ => some σ
  | st :: sts, n, σ => match σ.stmt P lbl (p0 + n) n st contract with
    | some σ' => SState.run contract P lbl p0 sts (n + 1) σ'
    | none => none

/-- Where a block ends. -/
inductive Exit where
  /-- A branch to block `d`. -/
  | br (d : Nat)
  /-- A branch on condition `c`: to `d` if its bit is set, else to `e`. -/
  | cond (c : SVal) (d e : Nat)
  /-- `ret void`. -/
  | ret
  /-- A branch on condition `c` into blocks that start with `phi`s: to `d` if its bit is set,
  else to `e`; the step sets the target's `phi`s (`enter`). A `br` has `c = .int 1 1` and
  `d = e`. -/
  | phi (c : SVal) (d e : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- Block `d` of `fn` exists and starts without a `phi`. -/
def entersAt (fn : Func) (d : Nat) : Bool :=
  match fn.blocks.find? (·.label == d) with
  | some b => (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).isEmpty
  | none => false

/-- The number of `phi`s at the head of block `d` of `fn` (0 when `fn` has no block `d`): the
position at which `enter` enters `d`. -/
def phiCount (fn : Func) (d : Nat) : Nat :=
  match fn.blocks.find? (·.label == d) with
  | some b => (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).length
  | none => 0

/-- The float constant node of typed operand `a`: `SNode.flit ft lit` for the float constant
`lit` at float type `ft`, else `none`. -/
def SNode.litOf : TValue → Option SNode
  | .mk (.fp ft) (.float lit) => some (.flit ft lit)
  | _ => none

/-- The typed operands for block `lbl` of the `phi`s at the head of block `d` of `fn` (empty
when `fn` has no block `d`): the operands `SState.phiConds` takes for the edge `lbl → d`. -/
def edgeOps (fn : Func) (lbl d : Nat) : List TValue :=
  match fn.blocks.find? (·.label == d) with
  | some b => (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).flatMap fun st =>
    match st.inst with
    | .phi t inc => match inc.find? (·.2 == lbl) with
      | some (v, _) => [⟨t, v⟩]
      | none => []
    | _ => []
  | none => []

/-- The blocks terminator `tm` branches to: `d` for `br d`, `d` and `e` for `br i1 c, d, e`,
none for the others. -/
def termDests : Term → List Nat
  | .br d => [d]
  | .condBr _ d e => [d, e]
  | _ => []

/-- The float constant nodes of block `b` (label `lbl`) of `fn` from position `p0`: one
`SNode.flit` per distinct float constant among the operands of its statements from `p0` and the
operands for `lbl` of the `phi`s of the blocks its terminator branches to, in order of first
occurrence. -/
def litNodes (fn : Func) (lbl p0 : Nat) (b : LLVM.Block) : List SNode :=
  (((b.stmts.toList.drop p0).flatMap (·.inst.operands) ++
      (termDests b.term).flatMap (edgeOps fn lbl)).filterMap SNode.litOf).eraseDups

/-- The state at the entry of block `b` (label `lbl`) of `fn` from position `p0`: `SState.init`
with the table of the block's float constants (`litNodes`), which `SState.op` refers to. -/
def SState.start (fn : Func) (lbl p0 : Nat) (b : LLVM.Block) : SState :=
  { SState.init with nodes := litNodes fn lbl p0 b }

/-- The exit of terminator `tm` from state `σ`, with its obligations. -/
def SState.exit (fn : Func) (σ : SState) : Term → Option (Exit × List Cond)
  | .br d => if entersAt fn d then some (.br d, []) else none
  | .condBr cv d e => match σ.op (.int 1) cv with
    | some x => if entersAt fn d && entersAt fn e then some (.cond x d e, [.bool x]) else none
    | none => none
  | .ret none => some (.ret, [])
  | _ => none

/-- The obligations of the edge from block `lbl` into block `d` of `fn`, from state `σ`: for
each `phi` at the head of `d`, its metadata passes `checkMd` and its operand for `lbl` has an
entry (`SState.op`: a register, an integer constant or a float constant's node) that evaluates
(`Cond.ok`). `none` when `fn` has no block `d` or a `phi` has no such operand. -/
def SState.phiConds (fn : Func) (σ : SState) (lbl d : Nat) : Option (List Cond) :=
  match fn.blocks.find? (·.label == d) with
  | some b => (b.stmts.toList.takeWhile (·.inst matches .phi _ _)).mapM fun st =>
    if st.checkMd.isOk then
      match st.inst with
      | .phi t inc => match inc.find? (·.2 == lbl) with
        | some (v, _) => (σ.op t v).map .ok
        | none => none
      | _ => none
    else none
  | none => none

/-- The exit of terminator `tm` of block `lbl` into blocks with `phi`s, from state `σ`, with
its obligations: `br` gives `.phi (.int 1 1) d d` and the edge's obligations
(`SState.phiConds`); `br i1` gives `.phi x d e`, the obligation that `x` is a word and both
edges' obligations. -/
def SState.phiExit (fn : Func) (lbl : Nat) (σ : SState) : Term → Option (Exit × List Cond)
  | .br d => (σ.phiConds fn lbl d).map fun cs => (.phi (.int 1 1) d d, cs)
  | .condBr cv d e => match σ.op (.int 1) cv, σ.phiConds fn lbl d, σ.phiConds fn lbl e with
    | some x, some cd, some ce => some (.phi x d e, .bool x :: cd ++ ce)
    | _, _, _ => none
  | _ => none

/-- The exit of terminator `tm` of block `lbl` from state `σ`, with its obligations:
`SState.exit`'s, else `SState.phiExit`'s. -/
def SState.exitAt (fn : Func) (lbl : Nat) (σ : SState) (tm : Term) :
    Option (Exit × List Cond) :=
  (σ.exit fn tm).or (σ.phiExit fn lbl tm)

/-- `SState.phiExit` for the edge into block `d₀` only: `br i1` gives `.phi x d e`, the
obligation that `x` is a word and the obligations of the edge into `d₀` (`SState.phiConds`), not
those of the other edge; other terminators give `SState.phiExit`'s. Sound when the exit goes to
`d₀` (`Exit.dest`; `SState.exitTo_sound`), so a `phi` operand of the untaken edge that is outside
the fragment (an `undef`, say) does not refuse the block. -/
def SState.phiExitTo (fn : Func) (lbl d₀ : Nat) (σ : SState) (tm : Term) :
    Option (Exit × List Cond) :=
  match tm with
  | .condBr cv d e => match σ.op (.int 1) cv, σ.phiConds fn lbl d₀ with
    | some x, some c₀ => some (.phi x d e, .bool x :: c₀)
    | _, _ => none
  | _ => σ.phiExit fn lbl tm

/-- `SState.exitAt` for the edge into block `d₀` only: `SState.exit`'s, else
`SState.phiExitTo`'s. -/
def SState.exitTo (fn : Func) (lbl d₀ : Nat) (σ : SState) (tm : Term) :
    Option (Exit × List Cond) :=
  (σ.exit fn tm).or (σ.phiExitTo fn lbl d₀ tm)

/-- A block summary: the node table (in order), the registers the block sets with their entries
(latest first), its memory effects, its obligations, its exit, and the number of statements it
runs. -/
structure Summary where
  /-- The summary from its node table, register entries, memory effects, obligations, exit and
  number of statements. -/
  mk ::
  /-- The node table, in order. -/
  nodes : List SNode
  /-- The registers set, latest first, with their entries. -/
  regs : List (Nat × SVal)
  /-- The memory effects, in order. -/
  effs : List SEff
  /-- The obligations. -/
  obls : List Cond
  /-- The exit. -/
  exit : Exit
  /-- The number of statements run, from the entry position to the terminator. -/
  len : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The summary of block `lbl` of `fn` from position `p0`, run from the state with the block's
float constants (`SState.start`) and the checker's `alloca` flag (`SState.alloca`) set to
`alloca`, with the exit and its obligations from exit function `ex` at the final state and the
terminator, with `fmul contract` in the fragment when `contract` (`SState.stmt`). With the flag on
the checker takes `alloca` (a pointer node `SNode.fresh` and an effect `SEff.alloca`, with or
without a count), and after one these statements read the memory the effects before them make,
not the entry memory: `icmp` on integers (`SNode.icmpAfter`), `ptrtoint` (`SNode.castAfter`),
`getelementptr` with one index, on a register or a global (`SNode.gepAfter`), or with any other
number of indices (`SNode.gepNAfter`), and `load` (`SNode.loadAfter`, as after a `store`). It
refuses each of them when an operand of an effect before it refers to a node at or after the
statement's (`SEff.before`). With the flag off it refuses `alloca`. -/
def summarizeAt (alloca : Bool) (P : Program) (fn : Func) (lbl p0 : Nat)
    (ex : SState → Term → Option (Exit × List Cond)) (contract : Bool := false) :
    Option Summary :=
  match fn.blocks.find? (·.label == lbl) with
  | some b => match SState.run contract P lbl p0 (b.stmts.toList.drop p0) 0
      { SState.start fn lbl p0 b with alloca } with
    | some σ => match ex σ b.term with
      | some (x, cs) => some ⟨σ.nodes, σ.regs, σ.effs, cs ++ .mem σ.effs :: σ.obls, x,
          (b.stmts.toList.drop p0).length⟩
      | none => none
    | none => none
  | none => none

/-- The summary of block `lbl` of `fn` from position `p0` with the `alloca` flag off, as
`SState.start` leaves it (`summarizeAt false`). -/
def summarizeWith (P : Program) (fn : Func) (lbl p0 : Nat)
    (ex : SState → Term → Option (Exit × List Cond)) (contract : Bool := false) :
    Option Summary :=
  summarizeAt false P fn lbl p0 ex contract

/-- The summary of block `lbl` of `fn` from position `p0` (`summarizeWith`, the exit from
`SState.exitAt`). -/
def summarize (P : Program) (fn : Func) (lbl p0 : Nat) : Option Summary :=
  summarizeWith P fn lbl p0 fun σ tm => σ.exitAt fn lbl tm

/-- **The block checker with the `alloca` flag**: `summarizeAt alloca` gives summary `S` (with
`fmul contract` in the fragment when `contract`), and the obligations of `S` are the first
conditions of `ds` (`Block.soundAt`). -/
def coversAt (alloca : Bool) (P : Program) (fn : Func) (lbl p0 : Nat)
    (ex : SState → Term → Option (Exit × List Cond)) (ds : List Cond) (S : Summary)
    (contract : Bool := false) : Bool :=
  match summarizeAt alloca P fn lbl p0 ex contract with
  | some S' => decide (S' = S) && S.obls.isPrefixOf ds
  | none => false

/-- The block checker with exit function `ex`: `coversAt` with the `alloca` flag off, so
`summarizeWith` gives summary `S` and the obligations of `S` are the first conditions of
`ds`. -/
def coversWith (P : Program) (fn : Func) (lbl p0 : Nat)
    (ex : SState → Term → Option (Exit × List Cond)) (ds : List Cond) (S : Summary)
    (contract : Bool := false) : Bool :=
  coversAt false P fn lbl p0 ex ds S contract

/-- **The block checker.** `summarize` gives summary `S`, and the obligations of `S` are the
first conditions of `ds` (`coversWith`, the exit from `SState.exitAt`). -/
def covers (P : Program) (fn : Func) (lbl p0 : Nat) (ds : List Cond) (S : Summary) : Bool :=
  coversWith P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) ds S

/-- **The block checker for one edge**: `covers` with the obligations of the edge into block `d₀`
only (`coversWith`, the exit from `SState.exitTo`), for a block whose exit goes to `d₀`
(`Block.sound_to`). -/
def coversTo (P : Program) (fn : Func) (lbl p0 d₀ : Nat) (ds : List Cond) (S : Summary) : Bool :=
  coversWith P fn lbl p0 (fun σ tm => σ.exitTo fn lbl d₀ tm) ds S

/-- The summary of block `lbl` of `fn` from position `p0` with `fmul contract` in the fragment
(`summarizeWith` with `contract`, the exit from `SState.exitAt`). -/
def summarizeC (P : Program) (fn : Func) (lbl p0 : Nat) : Option Summary :=
  summarizeWith P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) true

/-- **The block checker with `fmul contract`**: `summarizeC` gives summary `S`, and the
obligations of `S` are the first conditions of `ds` (`coversWith` with `contract`; sound by
`Block.soundC`, whose frame products are `regProdIn`'s). -/
def coversC (P : Program) (fn : Func) (lbl p0 : Nat) (ds : List Cond) (S : Summary) : Bool :=
  coversWith P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) ds S true

end MojoProof.Sym
