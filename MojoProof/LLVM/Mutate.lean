import MojoProof.LLVM.Import
import MojoProof.LLVM.Printer
import MojoProof.Sym.Block
import MojoProof.Sem.Replay
import MojoProof.LLVM.Quote

/-!
# The mutation harness over LLVM IR

One generic program for every module, driven by a finite operator table given as data: an operator
is a value of `Mutate.Op` and a table is a `List Op`; `Op.mutants` interprets an operator as edits
of the abstract syntax (`MojoProof.LLVM`), a finite replacement set at each site it applies to.
MojoProofTest/Mutate.lean has a test table.

The harness `run tbl P n` on program `P` (an imported kernel file):

1. **enumeration** (`mutants tbl P.module`): every mutant of every operator of the table, each
   operator once, in table order; an operator's in the order of the module's functions, a
   function's head (return attributes, then each parameter's) before its blocks, a block's
   statements before its terminator;
2. **selection** (`select ms n`): at most `n` mutants, stratified by operator (round robin over the
   operators in table order, each operator's mutants in enumeration order);
3. **admission** (`admission`): the mutant's printed text (`print`) imports (`importBytes`: it
   parses, every callee is defined or a supported intrinsic, the data layout is supported), has the
   tokens of its import printed back (`printDiff`, `mojo_import`'s last check), parses back to the
   same AST, uses no local that it does not define (`Func.undefinedUse`), and indexes its type with
   every `getelementptr` instruction (each index after the first steps into an array's or vector's
   element or names a field of a struct by an `i32` constant in range). `mojo_import`'s other
   checks concern a corpus file (its row in the manifest) or the quotation of the term (evaluated
   back), not a mutant. The admitted mutant is the AST its text parses to: an edit that adds a local
   (`gepIdx` on a local index) gives a raw AST whose new local is last in the function's name table,
   and the parse numbers the locals in text order;
4. **exact AST deduplication** of the admitted mutants: one equal to the original module is
   equivalent (certified by the equality), one equal to an earlier selected mutant is a duplicate
   of it and is not counted again;
5. **the checker** (`refused`): a mutant is unsupported when the block checker refuses a block of
   one of its ptx_kernel functions (`Sym.summarize` from the position after the block's `phi`s
   gives no summary, so `Sym.covers` holds for no summary);
6. **the replay**, given an instance (`Instance`: a kernel function, launch, arguments, memory,
   address choice, oracle, fuel, phases, and the output block the contract fixes with its final
   bytes): every other admitted mutant that is neither equivalent nor a duplicate is replayed by
   evaluation (`Instance.replayMutant`, `Kernel.replay` on `Mutant.program`). A reported violation
   makes it `killed` when its index is in the list `certified` that the caller passes, and else
   `refuted` (by evaluation only). `classify` takes the list as given; mojo_kills builds a list
   from theorems and checks each at elaboration: for each listed index, a theorem whose type is
   `Instance.Refuted` on the instance and relation, for the program and kernel function of that
   index's mutant (compared by evaluation), with no axioms but the three standard ones. The theorem
   comes from mojo_mutant, which quotes the mutant's program as a term, and `Instance.refutes`,
   which gives `Instance.Refuted` (`¬ Kernel.Sound` for every admission of the choice and oracle)
   from the replay decided by the kernel on that term. In MojoProofTest/Mutate.lean the theorems
   `vadd_m0` to `vadd_m7` and `vmul_m4` are these, and mojo_kills defines the lists `vaddKills`
   and `vmulKills` from them. No violation, or a replay that cannot decide, leaves it `passes`.
   Without an instance it is unclassified.

The outcome classes (`Outcome`) are counted separately (`Counts`): malformed, unsupported,
infrastructure failure, timeout, open proof, killed (certified), equivalent (certified),
conforming alternative, survived. This harness gives malformed, unsupported, equivalent,
duplicate, killed, and three more classes that are counted as unknown: refuted (evaluated,
uncertified), passes and unclassified. A replay that passes on one instance is no proof against
the contract, so it is not survived; conforming and survived need a proof against a contract for
all inputs, and the harness runs no proof search, so infrastructure failure, timeout and open
proof do not arise. Those classes are 0. `Counts.lines` gives the summary counts first:
generated, selected, admitted, equivalent, conforming, killed and unknown (`Counts.unknown`:
admitted, not a duplicate, neither killed, equivalent nor conforming), then each class.

Admission checks that every local a mutant uses is defined, not that the definition dominates
the use, and it checks the indices of each `getelementptr` instruction against its source type,
but no other typing (the parser has no type checker). `storeTo` redirects only to a parameter or
an earlier result of the same block, so the definition dominates the use, and `gepIdx`'s new
local is defined just before its use, from an operand of that use, with its type. `gepIdx` on a
struct's field index and `gepTy` on an instruction with more than one index can give indices
that do not index the type (a field the struct lacks, an index into a scalar): admission refuses
those as malformed.

The one theorem, `Instance.refutes`, is `Sem.Kernel.replay_block` on an instance. The kernel cannot
run the enumeration itself: the derived `BEq` of the nested `Ty` is `partial`, so `Op`'s equality,
which `select` and `mutants` use, does not reduce; hence mojo_mutant.
-/

namespace MojoProof.LLVM

/-- Function `fn` with statements `ss` in place of statement `i` of block `b` (indices in the
arrays). -/
def Func.splice (fn : Func) (b i : Nat) (ss : List Stmt) : Func :=
  { fn with blocks := fn.blocks.modify b fun bl =>
    { bl with
      stmts := bl.stmts.extract 0 i ++ ss.toArray ++ bl.stmts.extract (i + 1) bl.stmts.size } }

/-- Function `fn` with terminator `t` for block `b` (an index in the array). -/
def Func.setTerm (fn : Func) (b : Nat) (t : Term) : Func :=
  { fn with blocks := fn.blocks.modify b fun bl => { bl with term := t } }

/-- A local name that the name table of `fn` lacks: the first of `m`, `m1`, `m2`, ... that it
lacks (one of the first `fn.names.size + 1` is). -/
def Func.fresh (fn : Func) : String :=
  ((List.range (fn.names.size + 1)).map fun k => if k = 0 then "m" else s!"m{k}").find?
    (!fn.names.contains ·) |>.getD "m"

/-- The pointer locals that `fn` loads or stores through: address space, type accessed,
alignment and local, one entry per `load` and `store`. -/
def Func.accesses (fn : Func) : List (Nat × Ty × Option Nat × Nat) :=
  fn.blocks.toList.flatMap fun bl => bl.stmts.toList.filterMap fun s => match s.inst with
    | .load _ t (.mk (.ptr a) (.loc q)) al | .store _ (.mk t _) (.mk (.ptr a) (.loc q)) al =>
      some (a, t, al, q)
    | _ => none

/-- The locals a store through local `p` at statement `i` of block `b` of `fn`, of type `t` in
address space `a` with alignment `al`, may be redirected to: every other local that `fn` loads or
stores through with the same address space, type and alignment (`Func.accesses`) and that is a
parameter or the result of a statement before `i` in block `b` (so its definition dominates the
store), each once. -/
def Func.compatible (fn : Func) (b i a : Nat) (t : Ty) (al : Option Nat) (p : Nat) : List Nat :=
  let before := fn.params.filterMap (·.name) ++
    ((fn.blocks[b]?.map fun bl => (bl.stmts.extract 0 i).toList.filterMap (·.res)).getD [])
  let ok (a' : Nat) (t' : Ty) (al' : Option Nat) (q : Nat) : Bool :=
    a' == a && t' == t && al' == al && q != p && before.contains q
  (fn.accesses.filterMap fun (a', t', al', q) => if ok a' t' al' q then some q else none).eraseDups

/-- The first use in `fn` of a local that `fn` does not define, described, if there is one: an
operand that names no parameter or result, or a branch or `phi` edge that names no block. -/
def Func.undefinedUse (fn : Func) : Option String :=
  let vals := fn.params.filterMap (·.name) ++
    fn.blocks.toList.flatMap (·.stmts.toList.filterMap (·.res))
  let lbls := fn.blocks.toList.map (·.label)
  let dests : Term → List Nat := fun
    | .br d => [d] | .condBr _ d e => [d, e] | .switch _ _ d cs => d :: cs.map (·.2)
    | .ret _ | .unreachable => []
  fn.blocks.toList.findSome? fun bl =>
    let at_ := s!"in block %{fn.names.getD bl.label ""} of @{fn.name}"
    (bl.stmts.toList.findSome? fun s =>
      if TValue.anyMentions (!vals.contains ·) s.inst.operands then
        some s!"an operand {at_} names no value"
      else match s.inst with
        | .phi _ inc =>
          if inc.all fun (_, l) => lbls.contains l then none
          else some s!"a phi {at_} names no block"
        | _ => none) <|>
    (if TValue.anyMentions (!vals.contains ·) bl.term.operands then
      some s!"the terminator {at_} names no value"
    else if (dests bl.term).all lbls.contains then none
    else some s!"the terminator {at_} names no block")

namespace Mutate

/-- A mutation operator, as data (`Op.mutants` interprets it). -/
inductive Op where
  /-- Predicate `p` of an `icmp` replaced by `q` (no mutant when `p = q`). -/
  | icmp (p q : ICmp)
  /-- The condition of a conditional branch replaced by the constant `true`, where it is not
  already. -/
  | brTrue
  /-- `d` added to the last index of a `getelementptr`: a constant index `c` becomes `c + d`; any
  other index `x` of type `t` becomes a new local (`Func.fresh`) defined by `add t x, d` just
  before the instruction. The indexed type is not consulted: on a struct's field index the new
  field may not exist, and admission refuses such a mutant. -/
  | gepIdx (d : Int)
  /-- A `store` deleted. -/
  | storeDel
  /-- A `store` through a local redirected to a compatible pointer (`Func.compatible`: same
  address space, type accessed and alignment), one mutant per pointer. -/
  | storeTo
  /-- The source element type of a `getelementptr` changed from `s` to `t` (a byte-width change:
  the stride of its index; no mutant when `s = t`). With more than one index the later indices
  may not index `t`, and admission refuses such a mutant. -/
  | gepTy (s t : Ty)
  /-- The `inbounds` flag of a `getelementptr` toggled. -/
  | inbounds
  /-- The flag attribute `k` (such as `noundef`) removed from the return or one parameter of a
  function, declarations included. -/
  | dropAttr (k : String)
  /-- `d` added to the upper bound of the `range` attributes of the return or one parameter of a
  function, declarations included. -/
  | range (d : Int)
  /-- The identity edit, once per module: the control (its mutant must be admitted and be the
  original). -/
  | id
  deriving Repr, BEq, Inhabited

/-- An `icmp` predicate as the printer writes it: the second word of a printed `icmp`. -/
def icmpName (p : ICmp) : String :=
  ((Printer.inst #[] (.icmp p (.int 1) (.int 0) (.int 0))).splitOn " ")[1]?.getD ""

/-- A signed number with its sign. -/
def signed (d : Int) : String := if d ≥ 0 then s!"+{d}" else toString d

/-- The operator's name in reports. -/
def Op.label : Op → String
  | .icmp p q => s!"icmp {icmpName p}->{icmpName q}"
  | .brTrue => "br true"
  | .gepIdx d => s!"gep index {signed d}"
  | .storeDel => "store delete"
  | .storeTo => "store redirect"
  | .gepTy s t => s!"gep {Printer.ty s}->{Printer.ty t}"
  | .inbounds => "inbounds toggle"
  | .dropAttr k => s!"drop {k}"
  | .range d => s!"range upper {signed d}"
  | .id => "identity"

/-- Where a mutant's edit is: statement `i` of block `b` of function `f` (indices in the module's
arrays), the terminator of block `b` of function `f`, the return (`p = none`) or parameter `p`
attributes of function `f`, or the whole module. -/
inductive Site where
  /-- Statement `i` of block `b` of function `f`. -/
  | stmt (f b i : Nat)
  /-- The terminator of block `b` of function `f`. -/
  | term (f b : Nat)
  /-- The return (`none`) or parameter `p` attributes of function `f`. -/
  | attr (f : Nat) (p : Option Nat)
  /-- The whole module. -/
  | whole
  deriving Repr, BEq, Inhabited

/-- The label of block `b` of function `f` of module `m`, with its sigil. -/
def blockName (m : Module) (f b : Nat) : String :=
  match m.funcs[f]? with
  | some fn => "%" ++ ((fn.blocks[b]?.map fun bl => fn.names.getD bl.label "").getD "")
  | none => "%"

/-- The site in reports, in module `m`: functions by index, blocks by label. -/
def Site.label (m : Module) : Site → String
  | .stmt f b i => s!"fn {f} {blockName m f b} stmt {i}"
  | .term f b => s!"fn {f} {blockName m f b} term"
  | .attr f none => s!"fn {f} ret"
  | .attr f (some p) => s!"fn {f} param {p}"
  | .whole => "module"

/-- A mutant: its operator, its site and the edited module (before admission). -/
structure Mutant where
  /-- The mutant from its operator, site and edited module. -/
  mk ::
  /-- The operator. -/
  op : Op
  /-- The site of the edit. -/
  site : Site
  /-- The edited module. -/
  module : Module
  deriving Inhabited

/-- The edits of operator `op` at statement `s`, statement `i` of block `b` of function `fn`: the
functions they give, one per replacement. -/
def Op.atStmt (op : Op) (fn : Func) (b i : Nat) (s : Stmt) : List Func :=
  let put (inst : Inst) : List Func := [fn.splice b i [{ s with inst := inst }]]
  match op, s.inst with
  | .icmp p q, .icmp p' t x y => if p' == p && p != q then put (.icmp q t x y) else []
  | .gepIdx d, .gep fl src base idx => match idx.getLast? with
    | some (.mk t (.int c)) => put (.gep fl src base (idx.dropLast ++ [.mk t (.int (c + d))]))
    | some (.mk t v) =>
      let r := fn.names.size
      let fn' := { fn with names := fn.names.push fn.fresh }
      [fn'.splice b i [{ res := some r, inst := .bin .add {} t v (.int d) },
        { s with inst := .gep fl src base (idx.dropLast ++ [.mk t (.loc r)]) }]]
    | none => []
  | .storeDel, .store .. => [fn.splice b i []]
  | .storeTo, .store vol (.mk t x) (.mk (.ptr a) (.loc p)) al =>
    (fn.compatible b i a t al p).map fun q =>
      fn.splice b i [{ s with inst := .store vol (.mk t x) (.mk (.ptr a) (.loc q)) al }]
  | .gepTy s' t', .gep fl src base idx =>
    if src == s' && s' != t' then put (.gep fl t' base idx) else []
  | .inbounds, .gep fl src base idx => put (.gep { fl with inbounds := !fl.inbounds } src base idx)
  | _, _ => []

/-- The edits of operator `op` at the terminator `t` of block `b` of function `fn`. -/
def Op.atTerm (op : Op) (fn : Func) (b : Nat) (t : Term) : List Func :=
  match op, t with
  | .brTrue, .condBr c d e => if c == .int 1 then [] else [fn.setTerm b (.condBr (.int 1) d e)]
  | _, _ => []

/-- The edit of operator `op` on an attribute list, if it applies: `dropAttr k` removes the flag
`k` where it is present, `range d` adds `d` to the upper bound of every `range` where there is
one. -/
def Op.atAttrs (op : Op) (ats : List Attr) : Option (List Attr) :=
  match op with
  | .dropAttr k => if ats.contains (.flag k) then some (ats.filter (· != .flag k)) else none
  | .range d =>
    if ats.any (· matches .range ..) then
      some (ats.map fun a => match a with | .range t lo hi => .range t lo (hi + d) | a => a)
    else none
  | _ => none

/-- The edits of operator `op` on the head of function `fn`: its return attributes (`none`), then
each parameter's (`some k`), with the functions they give. -/
def Op.atHead (op : Op) (fn : Func) : List (Option Nat × Func) :=
  ((op.atAttrs fn.retAttrs).map fun ats => (none, { fn with retAttrs := ats })).toList ++
    fn.params.zipIdx.filterMap fun (p, k) => (op.atAttrs p.attrs).map fun ats =>
      (some k, { fn with params := fn.params.set k { p with attrs := ats } })

/-- The mutants of module `m` by operator `op`, in order: per function, its head (`Op.atHead`),
then per block its statements (`Op.atStmt`) and its terminator (`Op.atTerm`); `id` gives the
module itself, once. -/
def Op.mutants (op : Op) (m : Module) : List Mutant :=
  match op with
  | .id => [⟨op, .whole, m⟩]
  | _ => m.funcs.toList.zipIdx.flatMap fun (fn, f) =>
    let put (s : Site) (g : Func) : Mutant :=
      ⟨op, s, { m with funcs := m.funcs.modify f fun _ => g }⟩
    (op.atHead fn).map (fun (p, g) => put (.attr f p) g) ++
      fn.blocks.toList.zipIdx.flatMap fun (bl, b) =>
        (bl.stmts.toList.zipIdx.flatMap fun (s, i) =>
          (op.atStmt fn b i s).map (put (.stmt f b i))) ++
          (op.atTerm fn b bl.term).map (put (.term f b))

/-- **Enumeration**: the mutants of module `m` by the operators of table `tbl`, each operator once
(the first time it occurs), in table order (`Op.mutants`). -/
def mutants (tbl : List Op) (m : Module) : List Mutant :=
  tbl.eraseDups.flatMap (·.mutants m)

/-- **Selection**: at most `n` of the mutants `ms`, stratified by operator: the first mutant of
each operator (in the order the operators first occur in `ms`), then the second of each, and so
on. -/
def select (ms : List Mutant) (n : Nat) : List Mutant :=
  let groups := (ms.map (·.op)).eraseDups.map fun op => ms.filter (·.op == op)
  ((List.range ms.length).flatMap fun k => groups.filterMap (·[k]?)).take n

/-- The selection the harness classifies: at most `n` of the mutants of `P` by table `tbl`. -/
def selected (tbl : List Op) (P : Program) (n : Nat) : List Mutant :=
  select (mutants tbl P.module) n

/-- Why the indices `idx` (those of a `getelementptr` after its first, which strides over the
source type) do not index type `t`, if they do not: each index steps into an array's or vector's
element (any index) or into the field of a struct that an `i32` constant in range names; an index
into any other type, or a struct index that is no such constant, does not index it. -/
private def gepMisfit : Ty → List TValue → Option String
  | _, [] => none
  | .arr _ e, _ :: idx | .vec _ e, _ :: idx => gepMisfit e idx
  | .struct fs, .mk (.int 32) (.int c) :: idx =>
    match (if c < 0 then none else fs[c.toNat]?) with
    | some f => gepMisfit f idx
    | none => some s!"field {c} of a {fs.length}-field struct"
  | .struct _, _ :: _ => some "a struct index that is not an i32 constant"
  | t, _ :: _ => some s!"an index into {Printer.ty t}"

/-- **Admission** of the edited module `raw`: its printed text imports (`importBytes`), has the
tokens of its import printed back (`printDiff`), the import parses back from its print to the
same AST, no function uses a local it does not define (`Func.undefinedUse`), and the indices of
every `getelementptr` instruction index its source type (each after the first steps into an
array's or vector's element or a struct's field named by an `i32` constant in range). The result
is the imported program, whose module is the admitted mutant; the error says which check fails. -/
def admission (raw : Module) : Except String Program := do
  let text := (print raw).toUTF8
  let P ← (importBytes text).mapError (s!"the printed mutant does not import: {·}")
  if let some l := printDiff text P.module then
    throw s!"the printed import differs from the printed mutant at line {l}"
  match parse (print P.module).toUTF8 with
  | .ok m => unless m == P.module do throw "the printed import parses back to another AST"
  | .error e => throw s!"the printed import does not parse back: {e}"
  for fn in P.module.funcs do
    if let some e := fn.undefinedUse then throw e
    for bl in fn.blocks do
      for st in bl.stmts do
        if let .gep _ src _ (_ :: idx) := st.inst then
          if let some e := gepMisfit src idx then
            throw s!"a getelementptr in block %{fn.names.getD bl.label ""} of @{fn.name} does \
              not index its type: {e}"
  return P

/-- **The checker**: the first block of a ptx_kernel function of program `P` that the block
checker refuses, described: `Sym.summarize` from the position after its `phi`s
(`Sym.phiCount`) gives no summary, so `Sym.covers` holds there for no summary. `none` when it
refuses none. -/
def refused (P : Program) : Option String :=
  P.module.funcs.toList.findSome? fun fn =>
    if fn.cconv == some "ptx_kernel" then
      fn.blocks.toList.findSome? fun bl =>
        match Sym.summarize P fn bl.label (Sym.phiCount fn bl.label) with
        | some _ => none
        | none =>
          some s!"the block checker refuses block %{fn.names.getD bl.label ""} of @{fn.name}"
    else none

/-- The program of mutant `mu` of program `P`: `P` with the mutant's module. Its layout, intrinsic
declarations and kernel names are `P`'s, which no operator edits. -/
def Mutant.program (P : Program) (mu : Mutant) : Program := { P with module := mu.module }

/-- Function `f` of mutant `mu` (an index in its module's array), or `fn` if it has none. -/
def Mutant.func (mu : Mutant) (f : Nat) (fn : Func) : Func := mu.module.funcs[f]?.getD fn

/-- A concrete instance to replay mutants on: kernel function `f` of the module (`fn` the
original's), launch `L`, arguments `args`, memory `m`, address choice `ch` and oracle `oracle`,
`fuel` steps per thread and phase and `phases` phases, and the contract's output: block `out` of
`m` ends as `put` of `m`'s block `out` (as `Sym.Elem.Out` fixes it with `Sym.Elem.put`). -/
structure Instance where
  /-- The instance from its kernel, launch, arguments, memory, choices, fuel and output. -/
  mk ::
  /-- The kernel function's index in the module. -/
  f : Nat
  /-- The original's kernel function. -/
  fn : Func
  /-- The launch. -/
  L : Sem.Launch
  /-- The arguments. -/
  args : List Sem.Val
  /-- The memory. -/
  m : Sem.Mem
  /-- The address choice. -/
  ch : Nat → Nat
  /-- The oracle. -/
  oracle : Nat → Nat → Nat
  /-- Steps per thread and phase. -/
  fuel : Nat
  /-- Phases. -/
  phases : Nat
  /-- The output block. -/
  out : Nat
  /-- The output block's final contents, from its initial ones. -/
  put : Sem.Block → Sem.Block

/-- The replay of program `Q`'s kernel function `fn` on instance `I`: `Kernel.replay`, comparing
block `I.out`'s final bytes with those of `I.put` of its initial contents. -/
def Instance.replay (I : Instance) (Q : Program) (fn : Func) :
    Sem.Replay.Found (List Sem.MemByte) :=
  Sem.Kernel.replay Q fn I.L I.args I.m I.ch I.oracle I.fuel I.phases
    (fun m' => Sem.Replay.bytes? (m'.blocks I.out))
    (fun z => some z = Sem.Replay.bytes? ((I.m.blocks I.out).map I.put))

/-- The replay of mutant `mu` of `P` on instance `I`: `Instance.replay` of `mu`'s program and its
function `I.f`. -/
def Instance.replayMutant (I : Instance) (P : Program) (mu : Mutant) :
    Sem.Replay.Found (List Sem.MemByte) :=
  I.replay (mu.program P) (mu.func I.f I.fn)

/-- Program `Q`'s kernel function `fn` refuted on instance `I` for the relation `R` on the blocks:
for every admission that admits `I`'s choice and oracle, it is not sound for the observation of
the blocks and `R` at `I`'s launch, arguments and memory. -/
def Instance.Refuted (I : Instance) (Q : Program) (fn : Func)
    (R : (Nat → Option Sem.Block) → Prop) : Prop :=
  ∀ adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop, adm I.ch I.oracle →
    ¬ Sem.Kernel.Sound Q fn I.L I.args I.m adm (fun m => some m.blocks) R

/-- **A certified kill.** For every instance `I`, program `Q`, kernel function `fn` and relation
`R` on the blocks under which block `I.out` ends as `I.put` of its initial contents: if the replay
on `I` reports a violation (decided by the kernel), `fn` is refuted on `I` for `R`
(`Sem.Kernel.replay_block`). -/
theorem Instance.refutes {I : Instance} {Q : Program} {fn : Func}
    {R : (Nat → Option Sem.Block) → Prop}
    (hR : ∀ B, R B → ∀ x, I.m.blocks I.out = some x → B I.out = some (I.put x))
    (hx : (I.m.blocks I.out).isSome = true) (h : (I.replay Q fn).bad = true) :
    I.Refuted Q fn R := fun _ hadm =>
  Sem.Kernel.replay_block hR hx h hadm

/-- A replay's result in reports. -/
def found {β : Type} : Sem.Replay.Found β → String
  | .ub n msg => s!"undefined behavior at thread {n}: {msg}"
  | .race .. => "a race"
  | .broken .. => "a broken invariant.load promise"
  | .stuck => "a stuck grid"
  | .post _ => "the output block differs from the contract's"
  | .pass _ => "no violation"
  | .unknown msg => s!"undecided: {msg}"

/-- A mutant's outcome: the classes `malformed` to `survived`, and `duplicate j` for an admitted
mutant equal to the `j`-th selected mutant, `refuted` and `passes` for the replay's results that
are not certified, and `unclassified` for an admitted mutant in none of the classes yet. -/
inductive Outcome where
  /-- Not admitted (`admission`), with the failed check. -/
  | malformed (why : String)
  /-- Admitted; the checker refuses it (`refused`). -/
  | unsupported (why : String)
  /-- The harness failed. -/
  | infra (why : String)
  /-- The analysis ran out of time. -/
  | timeout
  /-- A proof obligation stays open. -/
  | openProof
  /-- The replay reports the violation `what` and the caller listed the mutant as certified
  (`classify`'s `certified`, taken as given): a list from `mojo_kills` has, for each index, a
  theorem checked to be `Instance.Refuted` for that mutant's mojo_mutant term. -/
  | killed (what : String)
  /-- Certified equal to the original: its admitted AST is the original's. -/
  | equivalent
  /-- Proves against a bounded-error contract with another output. -/
  | conforming
  /-- Proves against the contract, neither equivalent nor conforming. -/
  | survived
  /-- Admitted, and its AST is that of the `j`-th selected mutant. -/
  | duplicate (j : Nat)
  /-- Admitted, new, not refused; the replay reports the violation `what` by evaluation only:
  killed (uncertified, evaluated), counted as unknown. -/
  | refuted (what : String)
  /-- Admitted, new, not refused; the replay finds no violation or cannot decide (`what`):
  counted as unknown. -/
  | passes (what : String)
  /-- Admitted, new, and the checker does not refuse it, with no replay: none of the classes. -/
  | unclassified
  deriving Repr, BEq, Inhabited

/-- The outcome in reports. -/
def Outcome.label : Outcome → String
  | .malformed e => s!"malformed ({e})"
  | .unsupported e => s!"unsupported ({e})"
  | .infra e => s!"infrastructure failure ({e})"
  | .timeout => "timeout"
  | .openProof => "open proof"
  | .killed e => s!"killed, certified ({e})"
  | .equivalent => "equivalent"
  | .conforming => "conforming alternative"
  | .survived => "survived"
  | .duplicate j => s!"duplicate of {j}"
  | .refuted e => s!"refuted by evaluation, uncertified ({e})"
  | .passes e => s!"passes ({e})"
  | .unclassified => "unclassified"

/-- **Classification** of mutants `ms` of program `P`, in order: `malformed` when admission fails
(`admission`); else `equivalent` when the admitted AST is `P.module`; else `duplicate j` when it is
that of the `j`-th mutant of `ms`, an earlier one; else `unsupported` when the checker refuses it
(`refused`); else, with instance `I`, by the replay (`Instance.replay`): `killed` when it reports a
violation and the mutant's index is in `certified`, `refuted` when it reports one and the index is
not, `passes` when it reports none; with no instance, `unclassified`. `certified` is the caller's
claim that it proves each listed kill (`Instance.refutes`); it is not checked here. -/
def classify (P : Program) (ms : List Mutant) (I : Option Instance := none)
    (certified : List Nat := []) : Array (Mutant × Outcome) := Id.run do
  let mut out : Array (Mutant × Outcome) := #[]
  let mut seen : List (Module × Nat) := []
  for mu in ms do
    match admission mu.module with
    | .error e => out := out.push (mu, .malformed e)
    | .ok Q =>
      if Q.module == P.module then out := out.push (mu, .equivalent)
      else match seen.find? (·.1 == Q.module) with
        | some (_, j) => out := out.push (mu, .duplicate j)
        | none =>
          seen := (Q.module, out.size) :: seen
          out := out.push (mu, match refused Q, I with
            | some e, _ => .unsupported e
            | none, none => .unclassified
            | none, some I =>
              let r := I.replayMutant P mu
              if r.bad then
                if out.size ∈ certified then .killed (found r) else .refuted (found r)
              else .passes (found r))
  return out

/-- The counts of a run: mutants generated, selected and admitted, and each outcome class. -/
structure Counts where
  /-- The counts from their numbers. -/
  mk ::
  /-- Mutants enumerated. -/
  generated : Nat
  /-- Mutants selected. -/
  selected : Nat
  /-- Selected mutants admitted (all but the malformed). -/
  admitted : Nat
  /-- Admitted mutants equal to an earlier one. -/
  duplicate : Nat
  /-- See `Outcome.malformed`. -/
  malformed : Nat
  /-- See `Outcome.unsupported`. -/
  unsupported : Nat
  /-- See `Outcome.infra`. -/
  infra : Nat
  /-- See `Outcome.timeout`. -/
  timeout : Nat
  /-- See `Outcome.openProof`. -/
  openProof : Nat
  /-- See `Outcome.killed`: the mutants the caller listed as certified kills. -/
  killed : Nat
  /-- See `Outcome.equivalent`. -/
  equivalent : Nat
  /-- See `Outcome.conforming`. -/
  conforming : Nat
  /-- See `Outcome.survived`. -/
  survived : Nat
  /-- See `Outcome.refuted`. -/
  refuted : Nat
  /-- See `Outcome.passes`. -/
  passes : Nat
  /-- See `Outcome.unclassified`. -/
  unclassified : Nat
  deriving Repr, BEq, Inhabited

/-- The counts of `generated` mutants enumerated, and the classified selection `rs`. -/
def Counts.of (generated : Nat) (rs : Array (Mutant × Outcome)) : Counts :=
  let n (p : Outcome → Bool) := (rs.filter fun r => p r.2).size
  { generated, selected := rs.size, admitted := n fun o => !(o matches .malformed _),
    duplicate := n (· matches .duplicate _), malformed := n (· matches .malformed _),
    unsupported := n (· matches .unsupported _), infra := n (· matches .infra _),
    timeout := n (· matches .timeout), openProof := n (· matches .openProof),
    killed := n (· matches .killed _), equivalent := n (· matches .equivalent),
    conforming := n (· matches .conforming), survived := n (· matches .survived),
    refuted := n (· matches .refuted _), passes := n (· matches .passes _),
    unclassified := n (· matches .unclassified) }

/-- The unknown count: admitted mutants that are not duplicates and are neither killed,
equivalent nor conforming (the survived, unsupported, infrastructure failure, timeout, open proof,
refuted, passes and unclassified ones). -/
def Counts.unknown (c : Counts) : Nat :=
  c.admitted - c.duplicate - c.killed - c.equivalent - c.conforming

/-- The counts as text: the summary counts (generated, selected, admitted, equivalent,
conforming, killed, unknown), then each class (the malformed ones not admitted, the others
admitted). -/
def Counts.lines (c : Counts) : List String :=
  [s!"mutants: generated {c.generated}, selected {c.selected}, admitted {c.admitted}, equivalent \
    {c.equivalent}, conforming {c.conforming}, killed {c.killed}, unknown {c.unknown}",
    s!"not admitted: malformed {c.malformed}",
    s!"admitted: duplicate {c.duplicate}, unsupported {c.unsupported}, infrastructure failure \
      {c.infra}, timeout {c.timeout}, open proof {c.openProof}",
    s!"admitted: killed {c.killed}, equivalent {c.equivalent}, conforming {c.conforming}, \
      survived {c.survived}",
    s!"admitted, counted as unknown: refuted by evaluation (uncertified) {c.refuted}, passes \
      {c.passes}, unclassified {c.unclassified}"]

/-- A run of the harness: the counts and every selected mutant with its outcome. -/
structure Report where
  /-- The report from its counts and its mutants. -/
  mk ::
  /-- The counts. -/
  counts : Counts
  /-- The selected mutants, in order, with their outcomes. -/
  results : Array (Mutant × Outcome)
  deriving Inhabited

/-- **The harness** on program `P` with operator table `tbl` and budget `n`: enumeration
(`mutants`), selection of at most `n` (`select`), and classification (`classify`: admission,
exact AST deduplication, the checker, and the replay on instance `I` with the indices `certified`
of the kills the caller proves), with the counts. Its `killed` count is the number of replayed
violations whose index the caller listed in `certified`; `run` takes the list as given, and
`mojo_kills` builds one whose every index has its theorem (see `Outcome.killed`). -/
def run (tbl : List Op) (P : Program) (n : Nat) (I : Option Instance := none)
    (certified : List Nat := []) : Report :=
  let ms := mutants tbl P.module
  let rs := classify P (selected tbl P n) I certified
  ⟨.of ms.length rs, rs⟩

open Lean Elab Command Meta in
/-- `mojo_mutant x := e` evaluates `e`, a term of type `Program` (a mutant's, `Mutant.program`),
and adds its definitions under `x` as `mojo_import` does (`quoteProgram`: `x.fn_<i>.b_<j>`,
`x.fn_<i>`, `x.module`, `x.prog`; a block or function equal to an earlier import's is named, not
defined again), checked to evaluate back to `e`'s value and to print with its tokens. The kernel
then reduces the mutant's term, not the harness that computed it. The docstrings of the
definitions it adds cite the mutant, not a corpus file (`mutantDoc`): the term `e`, its operator
and site, its index and the program it mutates when `e` unfolds to `Mutant.program` of an
indexed list (`mutantSource`), and the SHA-256 of its printed module. -/
syntax (name := mojoMutant) "mojo_mutant " ident " := " term : command

open Lean Meta in
/-- What mojo_mutant's docstrings say the elaborated term `e` (text `src`) is. When `e`, its head
constants unfolded (at most 16 times), is `Mutant.program P mu`: the mutant `mu`'s operator and
site (evaluated), its index `k` when `mu` is `xs[k]!` with a numeral `k`, and `P`; otherwise
only the term `src`. `unsafe` because it evaluates `mu`. -/
unsafe def mutantSource (src : String) (e : Expr) : MetaM String := do
  let some (P, mu) ← go 16 e | return s!"the term `{src}`"
  let m ← evalExpr Mutant (mkConst ``Mutant) mu
  let idx ← match mu.getAppFn.constName?, mu.getAppArgs.back? with
    | some ``GetElem?.getElem!, some k => do
      match ← evalNat k with
      | some k =>
        let xs ← ppExpr mu.appFn!.appArg!
        pure s!", index {k} of `{xs}`"
      | none => pure ""
    | _, _ => pure ""
  let p ← ppExpr P
  return s!"the term `{src}`: operator `{m.op.label}` at {m.site.label m.module}{idx}, \
    of the program `{p}`"
where
  /-- `P` and `mu` when `e`, its head constants unfolded at most `n` times, is
  `Mutant.program P mu`; `none` otherwise. -/
  go : Nat → Expr → MetaM (Option (Expr × Expr))
    | 0, _ => pure none
    | n + 1, e => do
      if e.isAppOfArity ``Mutant.program 2 then return some (e.appFn!.appArg!, e.appArg!)
      match ← unfoldDefinition? e with
      | some e' => go n e'.headBeta
      | none => pure none

open Lean Elab Command Meta in
/-- Replace the docstrings `quoteProgram` gave the definitions of mutant `name` (program `P`, whose
printed module has SHA-256 `digest`; `src` from `mutantSource`) with ones that cite the mutant:
those of `name.fn_<i>.b_<j>` and `name.fn_<i>` that this module defines (a block or function
shared with an earlier definition has none here), `name.module` and `name.prog`. -/
def mutantDoc (name : Name) (P : Program) (src digest : String) : CommandElabM Unit := do
  let env ← getEnv
  let here (c : Name) : Bool := env.contains c && (env.getModuleIdxFor? c).isNone
  let ofM := s!"of the mutant `{name}` ({src}), whose printed module has SHA-256 `{digest}` \
    (added by `mojo_mutant`; no corpus file or manifest row holds it)"
  for (f, i) in P.module.funcs.toList.zipIdx do
    let c := name ++ (`fn).appendIndexAfter i
    for (b, j) in f.blocks.toList.zipIdx do
      let cb := c ++ (`b).appendIndexAfter j
      if here cb then
        addDocStringCore cb s!"Block {j} (`%{f.names.getD b.label ""}`) of function {i} \
          (`@{f.name}`) {ofM}."
    if here c then
      addDocStringCore c s!"Function {i} (`@{f.name}`, {f.blocks.size} blocks) {ofM}."
  addDocStringCore (name ++ `module) s!"The module {ofM}: its {P.module.funcs.size} functions, \
    globals, attribute groups and metadata."
  addDocStringCore (name ++ `prog) s!"The program {ofM}: its module, and the data layout, \
    intrinsic declarations, kernel names and `sha256` field `{P.sha256}` of the program it \
    mutates (`Mutant.program` keeps them, so the field is that program's digest, not the \
    mutant's). `mojo_mutant` checks, when it adds this term, that it evaluates to the term's \
    value and that its module prints back to the printed module's tokens."

open Lean Elab Command Meta in
/-- Elaborates mojo_mutant: `quoteProgram` on the term's value, then `mutantDoc`; `unsafe` because
it evaluates `e` and the term it adds. -/
@[command_elab mojoMutant] unsafe def elabMojoMutant : CommandElab := fun stx => do
  let name := (← getCurrNamespace) ++ stx[1].getId
  let (P, src) ← liftTermElabM do
    let e ← Term.elabTermEnsuringType stx[3] (mkConst ``Program)
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars e
    let txt ← PrettyPrinter.ppTerm ⟨stx[3]⟩
    let P ← evalExpr Program (mkConst ``Program) e
    let src ← mutantSource (toString txt) e
    return (P, src)
  let bytes := (print P.module).toUTF8
  quoteProgram name s!"mutant {name}" bytes P
  mutantDoc name P src (SHA256.hex bytes)

/-- The axioms a certified kill's proof may use (`mojo_kills`). -/
def killAxioms : List Lean.Name := [``propext, ``Classical.choice, ``Quot.sound]

open Lean Elab Command Meta in
/-- `mojo_kills ks : mutant on I R := [k₁ => t₁, ...]` defines `ks : List Nat := [k₁, ...]`, the
indices of certified kills to pass as `run`'s `certified`, after checking each theorem `tᵢ`: it
is a theorem, its type is `Instance.Refuted I Q fn R` (`Instance.refutes` gives that type), with
the given `I` and `R` up to reducible unfolding, a program `Q` that evaluates to `mutant kᵢ`
(`mutant : Nat → Program`, the harness's selected mutants as programs, `Mutant.program`), a
function `fn` that evaluates to that program's function `I.f` (`I.fn` when it has none, as
`Mutant.func`), and its proof uses no axioms but `propext`, `Classical.choice` and `Quot.sound`
(`killAxioms`). A failed check is an error, and then nothing is defined. -/
syntax (name := mojoKills) "mojo_kills " ident " : " term:max " on " term:max term:max " := "
  "[" (num " => " ident),* "]" : command

open Lean Elab Command Meta in
/-- Elaborates mojo_kills (see the syntax); `unsafe` because it evaluates the mutants, the instance
and each theorem's program and function. -/
@[command_elab mojoKills] unsafe def elabMojoKills : CommandElab := fun stx => do
  let name := (← getCurrNamespace) ++ stx[1].getId
  let rows ← stx[9].getSepArgs.toList.mapM fun r => do
    let some k := r[0].isNatLit? | throwErrorAt r[0] "mojo_kills: an index"
    return (k, r[2])
  let progTy := mkConst ``Program
  let thms ← liftTermElabM do
    let mutE ← Term.elabTermEnsuringType stx[3] (← mkArrow (mkConst ``Nat) progTy)
    let IE ← Term.elabTermEnsuringType stx[5] (mkConst ``Instance)
    let RE ← Term.elabTerm stx[6] none
    Term.synthesizeSyntheticMVarsNoPostponing
    let mutE ← instantiateMVars mutE
    let IE ← instantiateMVars IE
    let RE ← instantiateMVars RE
    let mutant ← evalExpr (Nat → Program) (← mkArrow (mkConst ``Nat) progTy) mutE
    let I ← evalExpr Instance (mkConst ``Instance) IE
    rows.mapM fun (k, id) => do
      let thm ← realizeGlobalConstNoOverloadWithInfo id
      let fail {α : Type} (why : MessageData) : TermElabM α :=
        throwErrorAt id
          m!"mojo_kills: {MessageData.ofConstName thm} does not refute mutant {k}: {why}"
      let some (.thmInfo t) := (← getEnv).find? thm | fail m!"it is not a theorem"
      unless t.type.isAppOfArity ``Instance.Refuted 4 do
        fail m!"its type{indentExpr t.type}\nis not an `Instance.Refuted`"
      let args := t.type.getAppArgs
      unless ← withReducible (isDefEq args[0]! IE) do
        fail m!"its instance is {args[0]!}, not {IE}"
      unless ← withReducible (isDefEq args[3]! RE) do
        fail m!"its relation is {args[3]!}, not {RE}"
      let want := mutant k
      let diff := Program.diff (← evalExpr Program progTy args[1]!) want
      unless diff.isEmpty do
        fail m!"its program {args[1]!} is not mutant {k}'s: they differ in {diff}"
      unless (← evalExpr Func (mkConst ``Func) args[2]!) == (want.module.funcs[I.f]?.getD I.fn) do
        fail m!"its function {args[2]!} is not function {I.f} of mutant {k}"
      if let some a := (← collectAxioms thm).find? (!killAxioms.contains ·) then
        fail m!"its proof depends on {a}, which is not in killAxioms"
      return (k, thm)
  let ks := thms.map (·.1)
  liftCoreM <| addDef name (mkApp (mkConst ``List [.zero]) (mkConst ``Nat)) (toExpr ks)
  let cited := ", ".intercalate (thms.map fun (k, t) => s!"{k} (`{t}`)")
  addDocStringCore name s!"The indices of the certified kills of `{stx[3].prettyPrint}` on \
    `{stx[5].prettyPrint}` for `{stx[6].prettyPrint}`, each with its theorem, which `mojo_kills` \
    checked to be the refutation of that mutant's program: {cited}."

/-- The report as text: the counts (`Counts.lines`), then one line per selected mutant: its index,
operator, site and outcome. -/
def Report.text (r : Report) : String :=
  "\n".intercalate <| r.counts.lines ++ r.results.toList.zipIdx.map fun ((mu, o), k) =>
    s!"{k}: {mu.op.label} at {mu.site.label mu.module}: {o.label}"

end Mutate

end MojoProof.LLVM
