import MojoProof.LLVM.Lexer
import Std.Data.HashSet
import Std.Data.HashMap

/-!
# LLVM IR parser

A recursive-descent parser from the tokens of `MojoProof.LLVM.Lexer` to `MojoProof.LLVM.Module`.
It accepts exactly the subset that `MojoProof.LLVM.Syntax` describes and refuses everything else
with an error naming the construct and its line, for example
`line 12: unsupported instruction 'invoke'` or `line 3: unsupported attribute 'inalloca'`.

Unnamed values are numbered as in LLVM: the counter runs over the unnamed or numbered parameters,
the entry block when it has no label, and numbered results and labels. The parser uses the
counter only to name an unlabeled entry block (and the unnamed parameters of a definition).
Local names are interned: each function's names, in the order the parser meets them, form its
table `Func.names`, and a local is its index there; a local name outside a function is refused,
and so is one in an aggregate constant or a constant expression.
A name defined twice (`Module.twice`: two functions or globals `@x`, two `#n` or `!n`, two
parameters, labels or results `%x` of a function) is refused, as LLVM refuses it.

This module is executable code with no theorems. It is checked against the printer, not trusted
alone (docs/TRUST.md, T4): on every corpus file and at every `mojo_import`, printing the parsed
module gives the file's tokens (`printDiff`), and the corpus round trip holds.
-/

namespace MojoProof.LLVM

/-- A token as it is written, for error messages. -/
def Tok.show : Tok → String
  | .loc s => "%" ++ s | .glob s => "@" ++ s | .mdName s => "!" ++ s | .mdId n => s!"!{n}"
  | .mdStr s => s!"!\"{s}\"" | .attrRef n => s!"#{n}" | .int v => toString v
  | .float _ => "float literal" | .str s => s!"\"{s}\"" | .kw s => s | .punct c => c.toString
  | .eof => "end of file"

namespace Parser

/-- Parser state: the tokens, the position, LLVM's counter for unnamed values, and the current
function's local names (`names`, with the index of each in `index`), if in a function (`inFn`). -/
structure St where
  /-- The state from its tokens, position, counter and local names. -/
  mk ::
  /-- The tokens of the file, the last one `eof`. -/
  toks : Array Token
  /-- The index of the next token. -/
  pos : Nat := 0
  /-- The number LLVM gives the next unnamed value or block of the function. -/
  next : Nat := 0
  /-- The current function's local names, in order of first appearance. -/
  names : Array String := #[]
  /-- The index of each name of `names`. -/
  index : Std.HashMap String Nat := {}
  /-- Whether the parser is inside a function body. -/
  inFn : Bool := false

/-- The parser monad. -/
abbrev P := StateT St (Except String)

/-- The default parser, which fails with the message "unreachable": the `partial` parsers of this
module need their type to be inhabited, and no parse ever runs this one. -/
instance {α : Type} : Inhabited (P α) := ⟨fun _ => .error "unreachable"⟩

private def peekAt (k : Nat) : P Tok := do
  let s ← get
  return (s.toks[s.pos + k]?.map (·.tok)).getD .eof

private def peek : P Tok := peekAt 0

private def bump : P Unit := modify fun s => { s with pos := s.pos + 1 }

private def fail {α : Type} (msg : String) : P α := do
  let s ← get
  let line := (s.toks[s.pos]?.map (·.line)).getD 0
  throw s!"line {line}: {msg}"

private def unsupported {α : Type} (what : String) : P α := do
  fail s!"unsupported {what} '{(← peek).show}'"

private def expectP (c : Char) : P Unit := do
  if (← peek) == .punct c then bump else fail s!"expected '{c}', found '{(← peek).show}'"

private def expectKw (k : String) : P Unit := do
  if (← peek) == .kw k then bump else fail s!"expected '{k}', found '{(← peek).show}'"

private def acceptP (c : Char) : P Bool := do
  if (← peek) == .punct c then bump; return true else return false

private def acceptKw (k : String) : P Bool := do
  if (← peek) == .kw k then bump; return true else return false

/-- A keyword that `f` reads as one of a fixed set of choices; refuses others as `what`. -/
private def choice {α : Type} (f : String → Option α) (what : String) : P α := do
  match ← peek with
  | .kw k => match f k with
    | some a => bump; return a
    | none => unsupported what
  | _ => unsupported what

private def nat : P Nat := do
  match ← peek with
  | .int (.ofNat n) => bump; return n
  | _ => fail s!"expected a natural number, found '{(← peek).show}'"

private def int : P Int := do
  match ← peek with
  | .int v => bump; return v
  | _ => fail s!"expected an integer, found '{(← peek).show}'"

private def str : P String := do
  match ← peek with
  | .str s => bump; return s
  | _ => fail s!"expected a string, found '{(← peek).show}'"

/-- The index of local name `n` in the current function's table, added if new. -/
private def intern (n : String) : P Nat := do
  let s ← get
  unless s.inFn do fail s!"local name '%{n}' outside a function"
  match s.index[n]? with
  | some i => return i
  | none =>
    set { s with names := s.names.push n, index := s.index.insert n s.names.size }
    return s.names.size

private def loc : P Nat := do
  match ← peek with
  | .loc s => bump; intern s
  | _ => fail s!"expected a local name, found '{(← peek).show}'"

private def glob : P String := do
  match ← peek with
  | .glob s => bump; return s
  | _ => fail s!"expected a global name, found '{(← peek).show}'"

/-- `(',' p)*`, continuing while the token after the comma satisfies `ok`. -/
private partial def commaMany {α : Type} (ok : Tok → Bool) (p : P α) (acc : Array α := #[]) :
    P (List α) := do
  if (← peek) == .punct ',' && ok (← peekAt 1) then bump; commaMany ok p (acc.push (← p))
  else return acc.toList

/-- `p (',' p)*`, ending before `close`; empty if `close` comes first. -/
private def sepBy {α : Type} (close : Char) (p : P α) : P (List α) := do
  if (← peek) == .punct close then return []
  let x ← p
  return x :: (← commaMany (fun _ => true) p)

/-- Record a defined name: a numeric name moves LLVM's unnamed-value counter past it. Returns
its index. -/
private def define (n : String) : P Nat := do
  if let some k := n.toNat? then modify fun s => { s with next := k + 1 }
  intern n

/-! ## Types -/

private def floatTy? : String → Option FloatTy
  | "half" => some .half | "bfloat" => some .bfloat | "float" => some .float
  | "double" => some .double | _ => none

/-- `iN` as a width. -/
private def intTy? (k : String) : Option Nat :=
  if k.startsWith "i" then (k.drop 1).toNat?.filter (· > 0) else none

/-- Whether a token starts a type. -/
def startsTy : Tok → Bool
  | .kw k => k ∈ ["void", "ptr", "label", "metadata"] || (floatTy? k).isSome || (intTy? k).isSome
  | .punct c => c == '<' || c == '[' || c == '{'
  | _ => false

/-- Types. Refuses packed structs, scalable vectors, typed pointers and named types. -/
partial def ty : P Ty := do
  let t ← peek
  match t with
  | .kw "void" => bump; return .void
  | .kw "label" => bump; return .label
  | .kw "metadata" => bump; return .metadata
  | .kw "ptr" =>
    bump
    if ← acceptKw "addrspace" then
      expectP '('; let n ← nat; expectP ')'; return .ptr n
    return .ptr 0
  | .kw k =>
    if let some f := floatTy? k then bump; return .fp f
    if let some w := intTy? k then bump; return .int w
    unsupported "type"
  | .punct '<' =>
    bump
    if (← peek) == .punct '{' then fail "unsupported type 'packed struct'"
    let n ← nat; expectKw "x"; let e ← ty; expectP '>'
    unless 0 < n && e.scalar do
      fail "unsupported vector type (no elements, or not integers, floats or pointers)"
    return .vec n e
  | .punct '[' => bump; let n ← nat; expectKw "x"; let e ← ty; expectP ']'; return .arr n e
  | .punct '{' => bump; let fs ← sepBy '}' ty; expectP '}'; return .struct fs
  | _ => unsupported "type"

/-! ## Values -/

private def castOp? : String → Option CastOp
  | "trunc" => some .trunc | "zext" => some .zext | "sext" => some .sext
  | "fptrunc" => some .fptrunc | "fpext" => some .fpext | "fptoui" => some .fptoui
  | "fptosi" => some .fptosi | "uitofp" => some .uitofp | "sitofp" => some .sitofp
  | "ptrtoint" => some .ptrtoint | "inttoptr" => some .inttoptr | "bitcast" => some .bitcast
  | "addrspacecast" => some .addrspacecast | _ => none

/-- `getelementptr` flags in any order. -/
private partial def gepFlags (f : GepFlags := {}) : P GepFlags := do
  if ← acceptKw "inbounds" then gepFlags { f with inbounds := true }
  else if ← acceptKw "nusw" then gepFlags { f with nusw := true }
  else if ← acceptKw "nuw" then gepFlags { f with nuw := true }
  else return f

/-- Constant `v`, refused if it mentions a local: the members of LangRef's aggregate constants
and the operands of its constant expressions are constants. -/
private def constant (v : Value) : P Value := do
  if v.mentions fun _ => true then fail "local name in a constant"
  return v

mutual
  /-- Operands: names, constants and the constant expressions `getelementptr`, `splat` and the
  casts LangRef admits there (`CastOp.const`), whose operands mention no local (`constant`). -/
  partial def value : P Value := do
    match ← peek with
    | .loc s => bump; return .loc (← intern s)
    | .glob s => bump; return .glob s
    | .int v => bump; return .int v
    | .float l => bump; return .float l
    | .kw "true" => bump; return .int 1
    | .kw "false" => bump; return .int 0
    | .kw "null" => bump; return .null
    | .kw "undef" => bump; return .undef
    | .kw "poison" => bump; return .poison
    | .kw "zeroinitializer" => bump; return .zero
    | .punct '<' => bump; let es ← sepBy '>' tvalue; expectP '>'; constant (.vec es)
    | .punct '[' => bump; let es ← sepBy ']' tvalue; expectP ']'; constant (.arr es)
    | .punct '{' => bump; let es ← sepBy '}' tvalue; expectP '}'; constant (.struct es)
    | .kw "splat" => bump; expectP '('; let e ← tvalue; expectP ')'; constant (.splat e)
    | .kw "getelementptr" =>
      bump
      let f ← gepFlags
      expectP '('; let src ← ty; expectP ','; let b ← tvalue
      let idx ← if ← acceptP ',' then sepBy ')' tvalue else pure []
      expectP ')'
      constant (.gep f src b idx)
    | .kw k =>
      if let some op := castOp? k then
        unless op.const do unsupported "constant expression"
        bump; expectP '('; let v ← tvalue; expectKw "to"; let t ← ty; expectP ')'
        return ← constant (.cast op v t)
      unsupported "value"
    | _ => unsupported "value"

  /-- A typed operand `T v`. -/
  partial def tvalue : P TValue := do
    let t ← ty
    return .mk t (← value)
end

/-! ## Attributes -/

/-- Keywords that start a constant. -/
def valueKws : List String :=
  ["true", "false", "null", "undef", "poison", "zeroinitializer", "splat", "getelementptr"]

/-- Attributes written as a bare keyword. -/
def flagAttrs : List String :=
  ["noundef", "nonnull", "readonly", "readnone", "writeonly", "immarg", "noalias", "nocapture",
   "zeroext", "signext", "inreg", "returned", "nofree", "convergent", "norecurse", "noinline",
   "alwaysinline", "nocallback", "nocreateundeforpoison", "nosync", "nounwind", "speculatable",
   "willreturn", "mustprogress", "noreturn", "cold", "hot", "optnone", "minsize", "optsize"]

/-- Attributes written as a keyword with a parenthesized type. -/
def tyAttrs : List String := ["byval", "byref", "sret", "elementtype"]

/-- Attributes written as a keyword with a parenthesized number. -/
def intAttrs : List String := ["dereferenceable", "dereferenceable_or_null"]

/-- Attributes written as a keyword with parenthesized `,`-separated, `:`-joined keywords. -/
def argsAttrs : List String := ["memory", "captures"]

private partial def kwPath : P (List String) := do
  match ← peek with
  | .kw k => bump; if ← acceptP ':' then return k :: (← kwPath) else return [k]
  | _ => unsupported "attribute argument"

/-- One attribute, or `none` if the next token does not start one. A keyword that is neither a
known attribute nor the start of a type is refused. -/
def attr? : P (Option Attr) := do
  match ← peek with
  | .str k => bump; expectP '='; return some (.str k (← str))
  | .kw "align" => bump; return some (.int "align" (← nat))
  | .kw "range" =>
    bump; expectP '('; let t ← ty; let lo ← int; expectP ','; let hi ← int; expectP ')'
    return some (.range t lo hi)
  | .kw k =>
    if k ∈ flagAttrs then bump; return some (.flag k)
    if k ∈ tyAttrs then bump; expectP '('; let t ← ty; expectP ')'; return some (.ty k t)
    if k ∈ intAttrs then bump; expectP '('; let n ← nat; expectP ')'; return some (.int k n)
    if k ∈ argsAttrs then
      bump; expectP '('; let xs ← sepBy ')' kwPath; expectP ')'; return some (.args k xs)
    if startsTy (.kw k) || k ∈ valueKws || (castOp? k).isSome then return none
    unsupported "attribute"
  | _ => return none

/-- A run of attributes. -/
partial def attrs : P (List Attr) := do
  match ← attr? with
  | some a => return a :: (← attrs)
  | none => return []

/-! ## Instructions -/

private def binOp? : String → Option BinOp
  | "add" => some .add | "sub" => some .sub | "mul" => some .mul | "udiv" => some .udiv
  | "sdiv" => some .sdiv | "urem" => some .urem | "srem" => some .srem | "shl" => some .shl
  | "lshr" => some .lshr | "ashr" => some .ashr | "and" => some .and | "or" => some .or
  | "xor" => some .xor | _ => none

private def fbinOp? : String → Option FBinOp
  | "fadd" => some .fadd | "fsub" => some .fsub | "fmul" => some .fmul | "fdiv" => some .fdiv
  | "frem" => some .frem | _ => none

private def icmp? : String → Option ICmp
  | "eq" => some .eq | "ne" => some .ne | "ugt" => some .ugt | "uge" => some .uge
  | "ult" => some .ult | "ule" => some .ule | "sgt" => some .sgt | "sge" => some .sge
  | "slt" => some .slt | "sle" => some .sle | _ => none

private def fcmp? : String → Option FCmp
  | "false" => some .false | "oeq" => some .oeq | "ogt" => some .ogt | "oge" => some .oge
  | "olt" => some .olt | "ole" => some .ole | "one" => some .one | "ord" => some .ord
  | "ueq" => some .ueq | "ugt" => some .ugt | "uge" => some .uge | "ult" => some .ult
  | "ule" => some .ule | "une" => some .une | "uno" => some .uno | "true" => some .true
  | _ => none

private def rmwOp? : String → Option RmwOp
  | "xchg" => some .xchg | "add" => some .add | "sub" => some .sub | "and" => some .and
  | "nand" => some .nand | "or" => some .or | "xor" => some .xor | "max" => some .max
  | "min" => some .min | "umax" => some .umax | "umin" => some .umin | "fadd" => some .fadd
  | "fsub" => some .fsub | "fmax" => some .fmax | "fmin" => some .fmin | _ => none

private def ordering? : String → Option Ordering
  | "monotonic" => some .monotonic | "acquire" => some .acquire | "release" => some .release
  | "acq_rel" => some .acqRel | "seq_cst" => some .seqCst | _ => none

/-- Integer flags in any order. -/
private partial def intFlags (f : IntFlags := {}) : P IntFlags := do
  if ← acceptKw "nuw" then intFlags { f with nuw := true }
  else if ← acceptKw "nsw" then intFlags { f with nsw := true }
  else if ← acceptKw "exact" then intFlags { f with exact := true }
  else if ← acceptKw "disjoint" then intFlags { f with disjoint := true }
  else return f

/-- Fast-math flags in any order; `fast` sets all seven. -/
private partial def fastMath (f : FastMath := {}) : P FastMath := do
  match ← peek with
  | .kw "fast" => bump; fastMath ⟨true, true, true, true, true, true, true⟩
  | .kw "nnan" => bump; fastMath { f with nnan := true }
  | .kw "ninf" => bump; fastMath { f with ninf := true }
  | .kw "nsz" => bump; fastMath { f with nsz := true }
  | .kw "arcp" => bump; fastMath { f with arcp := true }
  | .kw "contract" => bump; fastMath { f with contract := true }
  | .kw "afn" => bump; fastMath { f with afn := true }
  | .kw "reassoc" => bump; fastMath { f with reassoc := true }
  | _ => return f

/-- `, align N` if present. -/
private def align? : P (Option Nat) := do
  if (← peek) == .punct ',' && (← peekAt 1) == .kw "align" then
    bump; bump; return some (← nat)
  return none

private def isNat : Tok → Bool
  | .int (.ofNat _) => true
  | _ => false

private def idxList : P (List Nat) := commaMany isNat nat

private def label : P Nat := do expectKw "label"; loc

private def callee : P Callee := do
  match ← peek with
  | .glob s => bump; return .fn s
  | .kw "asm" =>
    bump
    let se ← acceptKw "sideeffect"
    let t ← str; expectP ','; let c ← str
    return .asm se t c
  | _ => unsupported "callee"

private def arg : P (TValue × List Attr) := do
  let t ← ty
  let as ← attrs
  return (.mk t (← value), as)

/-- A non-terminator instruction, after its opcode keyword `op`. -/
partial def inst (op : String) : P Inst := do
  if let some b := binOp? op then
    let f ← intFlags; let t ← ty; let a ← value; expectP ','; return .bin b f t a (← value)
  if let some b := fbinOp? op then
    let f ← fastMath; let t ← ty; let a ← value; expectP ','; return .fbin b f t a (← value)
  if let some c := castOp? op then
    let a ← tvalue; expectKw "to"; return .cast c a (← ty)
  match op with
  | "fneg" => let f ← fastMath; return .fneg f (← tvalue)
  | "icmp" =>
    let p ← choice icmp? "icmp predicate"
    let t ← ty; let a ← value; expectP ','; return .icmp p t a (← value)
  | "fcmp" =>
    let f ← fastMath
    let p ← choice fcmp? "fcmp predicate"
    let t ← ty; let a ← value; expectP ','; return .fcmp f p t a (← value)
  | "select" =>
    let c ← tvalue; expectP ','; let a ← tvalue; expectP ','; return .select c a (← tvalue)
  | "phi" =>
    let t ← ty
    let one : P (Value × Nat) := do
      expectP '['; let v ← value; expectP ','; let l ← loc; expectP ']'; pure (v, l)
    let x ← one
    return .phi t (x :: (← commaMany (· == .punct '[') one))
  | "alloca" =>
    let t ← ty
    let n ← commaMany startsTy tvalue
    if n.length > 1 then fail "alloca with more than one count"
    return .alloca t n.head? (← align?)
  | "load" =>
    if (← peek) == .kw "atomic" then fail "unsupported instruction 'load atomic'"
    let v ← acceptKw "volatile"
    let t ← ty; expectP ','; let p ← tvalue; return .load v t p (← align?)
  | "store" =>
    if (← peek) == .kw "atomic" then fail "unsupported instruction 'store atomic'"
    let v ← acceptKw "volatile"
    let x ← tvalue; expectP ','; let p ← tvalue; return .store v x p (← align?)
  | "getelementptr" =>
    let f ← gepFlags
    let src ← ty; expectP ','; let b ← tvalue
    return .gep f src b (← commaMany startsTy tvalue)
  | "extractvalue" => let a ← tvalue; return .extractvalue a (← idxList)
  | "insertvalue" =>
    let a ← tvalue; expectP ','; let e ← tvalue; return .insertvalue a e (← idxList)
  | "extractelement" => let v ← tvalue; expectP ','; return .extractelement v (← tvalue)
  | "insertelement" =>
    let v ← tvalue; expectP ','; let e ← tvalue; expectP ','
    return .insertelement v e (← tvalue)
  | "shufflevector" =>
    let a ← tvalue; expectP ','; let b ← tvalue; expectP ','; return .shufflevector a b (← tvalue)
  | "call" =>
    let f ← fastMath
    let r ← ty; let c ← callee; expectP '('; let as ← sepBy ')' arg; expectP ')'
    return .call f r c as
  | "atomicrmw" =>
    let v ← acceptKw "volatile"
    let o ← choice rmwOp? "atomicrmw operation"
    let p ← tvalue; expectP ','; let x ← tvalue
    let sc ← if ← acceptKw "syncscope" then do
        expectP '('; let s ← str; expectP ')'; pure (some s)
      else pure none
    let ord ← choice ordering? "ordering"
    return .atomicrmw v o p x sc ord (← align?)
  | _ => fail s!"unsupported instruction '{op}'"

/-- Metadata attachments `, !name !n`. -/
private partial def attachments : P (List (String × Nat)) := do
  if (← peek) == .punct ',' then
    if let .mdName k ← peekAt 1 then
      bump; bump
      match ← peek with
      | .mdId n => bump; return (k, n) :: (← attachments)
      | _ => unsupported "metadata attachment"
  return []

/-- A terminator, after its keyword `op`. -/
partial def terminator (op : String) : P Term := do
  match op with
  | "ret" => if ← acceptKw "void" then return .ret none else return .ret (some (← tvalue))
  | "br" =>
    if (← peek) == .kw "label" then return .br (← label)
    let t ← ty
    unless t == .int 1 do fail "expected i1 condition in br"
    let c ← value; expectP ','; let a ← label; expectP ','; return .condBr c a (← label)
  | "switch" =>
    let t ← ty; let v ← value; expectP ','; let d ← label; expectP '['
    let rec /-- The cases after `acc`, up to the closing `]`. -/
      cases (acc : Array (Int × Nat)) : P (List (Int × Nat)) := do
      if ← acceptP ']' then return acc.toList
      let ct ← ty
      unless ct == t do fail "switch case type differs from the condition type"
      let c ← int; expectP ','; let l ← label
      cases (acc.push (c, l))
    return .switch t v d (← cases #[])
  | "unreachable" => return .unreachable
  | _ => fail s!"unsupported terminator '{op}'"

private def isTerm (k : String) : Bool := k ∈ ["ret", "br", "switch", "unreachable"]

/-- A basic block with label `lbl`. -/
partial def block (lbl : Nat) : P Block := do
  let rec /-- The rest of the block after the statements `acc`: more statements, then its
    terminator. -/
    go (acc : Array Stmt) : P Block := do
    match ← peek with
    | .loc r =>
      bump; expectP '='
      match ← peek with
      | .kw op =>
        bump
        if isTerm op then fail s!"terminator '{op}' cannot have a result"
        let i ← inst op; let md ← attachments
        go (acc.push { res := some (← define r), inst := i, md })
      | _ => unsupported "instruction"
    | .kw op =>
      bump
      if isTerm op then
        let t ← terminator op
        unless (← attachments).isEmpty do unsupported "metadata attachment on a terminator"
        return { label := lbl, stmts := acc, term := t }
      let i ← inst op; let md ← attachments
      go (acc.push { res := none, inst := i, md })
    | _ => unsupported "instruction"
  go #[]

/-- A block label `n:` or `name:` if one comes next. -/
private def label? : P (Option String) := do
  if (← peekAt 1) == .punct ':' then
    match ← peek with
    | .int (.ofNat n) => bump; bump; return some (toString n)
    | .kw k => bump; bump; return some k
    | _ => return none
  return none

/-! ## Functions, globals and metadata -/

/-- Linkage, visibility and similar keywords that precede a function's or global's body. -/
def linkageKws : List String :=
  ["private", "internal", "external", "linkonce_odr", "weak_odr", "available_externally",
   "dso_local", "dso_preemptable", "hidden", "protected", "unnamed_addr", "local_unnamed_addr"]

/-- Calling conventions. -/
def cconvKws : List String := ["ptx_kernel", "ptx_device", "ccc", "fastcc"]

private partial def kwsIn (ks : List String) : P (List String) := do
  match ← peek with
  | .kw k => if k ∈ ks then bump; return k :: (← kwsIn ks) else return []
  | _ => return []

/-- A parameter: type, attributes and name, if written. -/
private def param : P (Ty × List Attr × Option String) := do
  let t ← ty
  let as ← attrs
  match ← peek with
  | .loc n => bump; return (t, as, some n)
  | _ => return (t, as, none)

/-- A function header after `define` or `declare`: `linkage cconv retattrs T @f(params) #n`. -/
private def header (isDef : Bool) : P Func := do
  let lk ← kwsIn linkageKws
  let cc ← match ← peek with
    | .kw k => if k ∈ cconvKws then do bump; pure (some k) else pure none
    | _ => pure none
  let ra ← attrs
  let r ← ty
  let n ← glob
  expectP '('
  modify fun s => { s with next := 0, names := #[], index := {}, inFn := true }
  let ps ← sepBy ')' param
  expectP ')'
  -- name unnamed parameters of a definition as LLVM does, and advance the counter
  let ps ← ps.mapM fun (t, as, x) => do
    let x ← if isDef then some <$> define (x.getD (toString (← get).next)) else x.mapM intern
    pure { ty := t, attrs := as, name := x }
  let g ← match ← peek with
    | .attrRef k => do bump; pure (some k)
    | _ => pure none
  return { linkage := lk, cconv := cc, retAttrs := ra, ret := r, name := n, params := ps,
           group := g, names := #[], blocks := #[] }

/-- Function `f` with the current function's local names; ends the function. -/
private def close (f : Func) : P Func := do
  let s ← get
  set { s with inFn := false }
  return { f with names := s.names }

/-- A function definition after `define`. -/
private partial def definition : P Func := do
  let f ← header true
  expectP '{'
  let rec blocks (acc : Array Block) : P (Array Block) := do
    if ← acceptP '}' then return acc
    let l ← match ← label? with
      | some l => define l
      | none =>
        if acc.isEmpty then do define (toString (← get).next)
        else fail "expected a block label"
    blocks (acc.push (← block l))
  let bs ← blocks #[]
  if bs.isEmpty then fail "function definition without blocks"
  close { f with blocks := bs }

/-- A global variable after `@name =`. -/
private def global (n : String) : P Global := do
  let lk ← kwsIn linkageKws
  let a ← if (← acceptKw "addrspace") then do
      expectP '('; let a ← nat; expectP ')'; pure a
    else pure 0
  let c ← if ← acceptKw "constant" then pure true else do expectKw "global"; pure false
  let t ← ty
  let init ← if (← peek) == .punct ',' || (← peek) == .eof || "external" ∈ lk then pure none
    else some <$> value
  let al ← align?
  return { name := n, linkage := lk, addrSpace := a, isConst := c, ty := t, init, align := al }

/-- Metadata operands. -/
partial def md : P MD := do
  match ← peek with
  | .mdId n => bump; return .ref n
  | .mdStr s => bump; return .str s
  | .punct '!' => bump; expectP '{'; let ops ← sepBy '}' md; expectP '}'; return .node ops
  | t => if startsTy t then return .val (← tvalue) else unsupported "metadata"

/-- A whole module. -/
partial def top : P Module := do
  let rec /-- The rest of the file, read into the module `m` so far. -/
    go (m : Module) : P Module := do
    match ← peek with
    | .eof => return m
    | .kw "source_filename" => bump; expectP '='; go { m with sourceFilename := some (← str) }
    | .kw "target" =>
      bump
      if ← acceptKw "datalayout" then expectP '='; go { m with datalayout := some (← str) }
      else if ← acceptKw "triple" then expectP '='; go { m with triple := some (← str) }
      else unsupported "target field"
    | .glob n =>
      bump; expectP '='; go { m with globals := m.globals.push (← global n) }
    | .kw "define" => bump; go { m with funcs := m.funcs.push (← definition) }
    | .kw "declare" => bump; go { m with funcs := m.funcs.push (← close (← header false)) }
    | .kw "attributes" =>
      bump
      let k ← match ← peek with
        | .attrRef k => do bump; pure k
        | _ => unsupported "attribute group"
      expectP '='; expectP '{'
      let as ← attrs
      expectP '}'
      go { m with attrGroups := m.attrGroups.push (k, as) }
    | .mdName n =>
      bump; expectP '='; expectP '!'; expectP '{'
      let ids ← sepBy '}' do
        match ← peek with
        | .mdId k => bump; pure k
        | _ => unsupported "named metadata operand"
      expectP '}'
      go { m with namedMD := m.namedMD.push (n, ids) }
    | .mdId k =>
      bump; expectP '='
      if (← peek) != .punct '!' then unsupported "metadata node"
      go { m with mds := m.mds.push (k, ← md) }
    | _ => unsupported "top-level entity"
  go { sourceFilename := none, datalayout := none, triple := none, globals := #[], funcs := #[],
       attrGroups := #[], namedMD := #[], mds := #[] }

end Parser

/-- An element of `xs` that occurs twice, if any. -/
private def repeated {α : Type} [BEq α] [Hashable α] (xs : List α) : Option α :=
  (xs.foldl (init := (({} : Std.HashSet α), (none : Option α))) fun (seen, r) x =>
    (seen.insert x, r <|> if seen.contains x then some x else none)).2

/-- A name `m` defines twice, which LLVM refuses (LangRef, "Identifiers"; the semantics looks
names up and would take the first): a global or function `@x`, an attribute group `#n`, a
metadata node `!n` or `!name`, or, in one function, a parameter, block label or result `%x`. -/
def Module.twice (m : Module) : Option String :=
  repeated (m.globals.toList.map (s!"@{·.name}") ++ m.funcs.toList.map (s!"@{·.name}") ++
    m.attrGroups.toList.map (s!"#{·.1}") ++ m.mds.toList.map (s!"!{·.1}") ++
    m.namedMD.toList.map (s!"!{·.1}")) <|>
  m.funcs.findSome? fun f => (repeated (f.params.filterMap (·.name) ++
    f.blocks.toList.flatMap fun b => b.label :: b.stmts.toList.filterMap (·.res))).map
      fun i => s!"%{f.names.getD i ""} in @{f.name}"

/-- Parse a module from its text. Errors name the refused construct and its line. -/
def parse (s : ByteArray) : Except String Module := do
  let toks ← lex s
  let (m, st) ← Parser.top.run { toks }
  if st.pos + 1 != toks.size then throw "trailing tokens"
  if let some n := m.twice then throw s!"'{n}' defined twice"
  return m

end MojoProof.LLVM
