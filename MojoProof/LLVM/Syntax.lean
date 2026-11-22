/-!
# The LLVM IR subset: abstract syntax

The abstract syntax of the textual LLVM IR that `mojo build --emit llvm` writes for one GPU kernel
(`*.nvptx.ll`). It covers every construct used by the corpus in `tests/corpus` and nothing the
importer cannot check: the parser (`MojoProof.LLVM.Parser`) refuses any other construct by name.

The grammar follows the LLVM Language Reference Manual (LLVM 21+ syntax: opaque pointers, `range`
attributes, `captures(...)`). Global names are kept as written (without the `@` sigil). Local
names (parameters, results and block labels, `%x`) are interned: each function has a table of its
local names (`Func.names`, without the `%` sigil) and a local is its index in the table, so the
semantics compares numbers, not strings. The parser gives the unnamed entry block LLVM's implicit
number, so every block has a name.

This module defines data, and the operands of instructions and terminators (`Inst.operands`,
`Term.operands`, `Func.uses`); it proves nothing.
-/

namespace MojoProof.LLVM

/-- Floating-point types of the subset: IEEE binary16, bfloat16, binary32 and binary64. -/
inductive FloatTy
  /-- `half`, IEEE binary16. -/
  | half
  /-- `bfloat`, bfloat16: binary32's exponent range with a 7-bit fraction. -/
  | bfloat
  /-- `float`, IEEE binary32. -/
  | float
  /-- `double`, IEEE binary64. -/
  | double
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- First-class and aggregate types. `ptr as` is an opaque pointer in address space `as`. -/
inductive Ty
  /-- `void`, the result type of a function or call that returns no value. -/
  | void
  /-- `i<width>`, an integer of `width` bits (`i1` holds the booleans). -/
  | int (width : Nat)
  /-- A floating-point type. -/
  | fp (t : FloatTy)
  /-- `ptr addrspace(<addrSpace>)`, an opaque pointer; `ptr` alone is address space 0. -/
  | ptr (addrSpace : Nat)
  /-- `<n x elt>`, a vector of `n` elements of type `elt` (a scalar type, `Ty.scalar`). -/
  | vec (n : Nat) (elt : Ty)
  /-- `[n x elt]`, an array of `n` elements of type `elt`. -/
  | arr (n : Nat) (elt : Ty)
  /-- `{ t1, t2, ... }`, a struct with fields of the types `fields`, in order. -/
  | struct (fields : List Ty)
  /-- `label`, the type of a basic block. -/
  | label
  /-- `metadata`, the type of a metadata argument of an intrinsic call. -/
  | metadata
  deriving Repr, Inhabited, BEq, Hashable

/-- An integer, floating-point or pointer type: the element types of a vector (LangRef, "Vector
Type"). -/
def Ty.scalar : Ty → Bool
  | .int _ | .fp _ | .ptr _ => true
  | _ => false

/-- A floating-point literal as written: decimal, or LLVM's hexadecimal form. -/
inductive FloatLit
  /-- `[-]int.frac[e[+-]exp]`: the sign, the digits before and after the point, and the exponent
  (0 when none is written). -/
  | dec (neg : Bool) (int frac : String) (exp : Int)
  /-- `0x<pfx><digits>`: the prefix (`""` for a value written as `double` bits, `"H"` for `half`,
  `"R"` for `bfloat`) and the bits the hexadecimal digits give. The lexer also reads the prefixes
  `"K"`, `"L"` and `"M"` (`x86_fp80`, `fp128`, `ppc_fp128`), which the printer prints and the
  semantics does not evaluate (`floatLit`, MojoProof/Sem/Eval.lean). -/
  | hex (pfx : String) (bits : Nat)
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Integer arithmetic and bitwise binary operators. -/
inductive BinOp
  /-- `add`, addition modulo `2^w` for width `w`. -/
  | add
  /-- `sub`, subtraction modulo `2^w`. -/
  | sub
  /-- `mul`, multiplication modulo `2^w`. -/
  | mul
  /-- `udiv`, unsigned division. -/
  | udiv
  /-- `sdiv`, signed division, rounded toward zero. -/
  | sdiv
  /-- `urem`, unsigned remainder. -/
  | urem
  /-- `srem`, signed remainder, with the sign of the dividend. -/
  | srem
  /-- `shl`, shift left. -/
  | shl
  /-- `lshr`, logical shift right (zeros shifted in). -/
  | lshr
  /-- `ashr`, arithmetic shift right (copies of the sign bit shifted in). -/
  | ashr
  /-- `and`, bitwise and. -/
  | and
  /-- `or`, bitwise or. -/
  | or
  /-- `xor`, bitwise exclusive or. -/
  | xor
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Poison-generating flags of integer binary operators (`nuw`, `nsw`, `exact`, `disjoint`). -/
structure IntFlags where
  /-- The flags `nuw`, `nsw`, `exact` and `disjoint`, each set when written. -/
  mk ::
  /-- `nuw` (no unsigned wrap): the result is poison if the operation wraps as unsigned. -/
  nuw : Bool := false
  /-- `nsw` (no signed wrap): the result is poison if the operation wraps as signed. -/
  nsw : Bool := false
  /-- `exact` (on divisions and right shifts): the result is poison if the remainder is not zero
  or a set bit is shifted out. -/
  exact : Bool := false
  /-- `disjoint` (on `or`): the result is poison if the operands have a set bit in common. -/
  disjoint : Bool := false
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Floating-point binary operators. -/
inductive FBinOp
  /-- `fadd`, addition. -/
  | fadd
  /-- `fsub`, subtraction. -/
  | fsub
  /-- `fmul`, multiplication. -/
  | fmul
  /-- `fdiv`, division. -/
  | fdiv
  /-- `frem`, the remainder of the division truncated toward zero, as C's `fmod`. -/
  | frem
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Fast-math flags (LangRef, "Fast-Math Flags"); `fast` is all seven. -/
structure FastMath where
  /-- The seven flags, each set when written (or by `fast`). -/
  mk ::
  /-- `nnan`: the result is poison if an operand or the result is a NaN. -/
  nnan : Bool := false
  /-- `ninf`: the result is poison if an operand or the result is an infinity. -/
  ninf : Bool := false
  /-- `nsz`: the sign of a zero operand or result may be ignored. -/
  nsz : Bool := false
  /-- `arcp`: a division may be computed as a multiplication by the reciprocal. -/
  arcp : Bool := false
  /-- `contract`: the operation may be fused with another one, such as a multiply and an add into
  a fused multiply-add. -/
  contract : Bool := false
  /-- `afn`: a math function may be computed by an approximation. -/
  afn : Bool := false
  /-- `reassoc`: the operation may be reassociated with others. -/
  reassoc : Bool := false
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Integer comparison predicates. -/
inductive ICmp
  /-- `eq`, equal. -/
  | eq
  /-- `ne`, not equal. -/
  | ne
  /-- `ugt`, unsigned greater than. -/
  | ugt
  /-- `uge`, unsigned greater than or equal. -/
  | uge
  /-- `ult`, unsigned less than. -/
  | ult
  /-- `ule`, unsigned less than or equal. -/
  | ule
  /-- `sgt`, signed greater than. -/
  | sgt
  /-- `sge`, signed greater than or equal. -/
  | sge
  /-- `slt`, signed less than. -/
  | slt
  /-- `sle`, signed less than or equal. -/
  | sle
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Floating-point comparison predicates. -/
inductive FCmp
  /-- `false`, always false. -/
  | false
  /-- `oeq`, ordered (neither operand is a NaN) and equal. -/
  | oeq
  /-- `ogt`, ordered and greater than. -/
  | ogt
  /-- `oge`, ordered and greater than or equal. -/
  | oge
  /-- `olt`, ordered and less than. -/
  | olt
  /-- `ole`, ordered and less than or equal. -/
  | ole
  /-- `one`, ordered and not equal. -/
  | one
  /-- `ord`, ordered: neither operand is a NaN. -/
  | ord
  /-- `ueq`, unordered (an operand is a NaN) or equal. -/
  | ueq
  /-- `ugt`, unordered or greater than. -/
  | ugt
  /-- `uge`, unordered or greater than or equal. -/
  | uge
  /-- `ult`, unordered or less than. -/
  | ult
  /-- `ule`, unordered or less than or equal. -/
  | ule
  /-- `une`, unordered or not equal. -/
  | une
  /-- `uno`, unordered: an operand is a NaN. -/
  | uno
  /-- `true`, always true. -/
  | true
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Conversion operators. -/
inductive CastOp
  /-- `trunc`, an integer cut to a narrower width (or a vector of them). -/
  | trunc
  /-- `zext`, an integer extended with zeros. -/
  | zext
  /-- `sext`, an integer extended with copies of its sign bit. -/
  | sext
  /-- `fptrunc`, a float rounded to a narrower format. -/
  | fptrunc
  /-- `fpext`, a float extended to a wider format (exact). -/
  | fpext
  /-- `fptoui`, a float to an unsigned integer, rounded toward zero (poison when out of range). -/
  | fptoui
  /-- `fptosi`, a float to a signed integer, rounded toward zero (poison when out of range). -/
  | fptosi
  /-- `uitofp`, an unsigned integer to a float, rounded. -/
  | uitofp
  /-- `sitofp`, a signed integer to a float, rounded. -/
  | sitofp
  /-- `ptrtoint`, a pointer's address as an integer. -/
  | ptrtoint
  /-- `inttoptr`, an integer as a pointer. -/
  | inttoptr
  /-- `bitcast`, the same bits at another type of the same size. -/
  | bitcast
  /-- `addrspacecast`, a pointer converted to another address space. -/
  | addrspacecast
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- The casts LangRef admits in a constant expression ("Constant Expressions": `trunc`, `ptrtoint`,
`inttoptr`, `bitcast`, `addrspacecast`, and `ptrtoaddr`, which is not in the subset). None reads
an oracle number, so neither does an operand (`evalV_regs`). -/
def CastOp.const : CastOp → Bool
  | .trunc | .ptrtoint | .inttoptr | .bitcast | .addrspacecast => true
  | _ => false

/-- `getelementptr` flags: `inbounds`, `nusw`, `nuw`. -/
structure GepFlags where
  /-- The flags `inbounds`, `nusw` and `nuw`, each set when written. -/
  mk ::
  /-- `inbounds`: the result is poison unless every address it computes stays within the object
  the base points into (LangRef, "getelementptr"). -/
  inbounds : Bool := false
  /-- `nusw`: the result is poison if an offset computation wraps as signed. -/
  nusw : Bool := false
  /-- `nuw`: the result is poison if an offset computation wraps as unsigned. -/
  nuw : Bool := false
  deriving DecidableEq, Repr, Inhabited, Hashable

mutual
  /-- Operands: locals (by index in the function's `names`), globals by name, constants and
  constant expressions. Integer constants carry their value only; their width is the operand's
  type. `true`/`false` are `int 1`/`int 0`. -/
  inductive Value
    /-- A local, `%names[i]` of the function. -/
    | loc (i : Nat)
    /-- A global, `@name`. -/
    | glob (name : String)
    /-- An integer constant; its width is the operand's type. -/
    | int (v : Int)
    /-- A floating-point constant, as written. -/
    | float (lit : FloatLit)
    /-- `null`, the null pointer. -/
    | null
    /-- `undef`. -/
    | undef
    /-- `poison`. -/
    | poison
    /-- `zeroinitializer`, the zero value of the operand's type. -/
    | zero
    /-- A vector constant `<t v, ...>`. -/
    | vec (elts : List TValue)
    /-- An array constant `[t v, ...]`. -/
    | arr (elts : List TValue)
    /-- A struct constant `{ t v, ... }`. -/
    | struct (elts : List TValue)
    /-- `splat (t v)`, a vector constant with every element `elt`. -/
    | splat (elt : TValue)
    /-- A `getelementptr` constant expression: its flags, source element type, base and indices. -/
    | gep (flags : GepFlags) (src : Ty) (base : TValue) (idx : List TValue)
    /-- A cast constant expression `op (v to ty)`. -/
    | cast (op : CastOp) (v : TValue) (to : Ty)
    deriving Repr, Inhabited, BEq, Hashable

  /-- A typed operand `ty value`. -/
  inductive TValue
    /-- The operand `v` at type `ty`. -/
    | mk (ty : Ty) (v : Value)
    deriving Repr, Inhabited, BEq, Hashable
end

/-- Parameter, return and function attributes. `flag` is a bare keyword (`noundef`), `int` a
keyword with a number (`align 16`), `ty` a keyword with a type (`byval(T)`), `range` the
`range(T lo, hi)` attribute, `args` a keyword with parenthesized keywords (`captures(none)`,
`memory(argmem: readwrite)` as `[["argmem", "readwrite"]]`), `str` a string attribute `"k"="v"`. -/
inductive Attr
  /-- A bare keyword, such as `noundef`. -/
  | flag (name : String)
  /-- A keyword with a number, such as `align 16`. -/
  | int (name : String) (n : Nat)
  /-- A keyword with a type, such as `byval(T)`. -/
  | ty (name : String) (t : Ty)
  /-- `range(t lo, hi)`: the value is in `[lo, hi)`, wrapping around when `hi < lo`. -/
  | range (t : Ty) (lo hi : Int)
  /-- A keyword with parenthesized keyword lists, such as `captures(none)`. -/
  | args (name : String) (items : List (List String))
  /-- A string attribute `"key"="val"`. -/
  | str (key val : String)
  deriving Repr, Inhabited, BEq, Hashable

/-- Atomic read-modify-write operations: what `atomicrmw` stores, from the old value at the
address and the operand. -/
inductive RmwOp
  /-- `xchg`: store the operand. -/
  | xchg
  /-- `add`: store the old value plus the operand. -/
  | add
  /-- `sub`: store the old value minus the operand. -/
  | sub
  /-- `and`: store the bitwise and. -/
  | and
  /-- `nand`: store the complement of the bitwise and. -/
  | nand
  /-- `or`: store the bitwise or. -/
  | or
  /-- `xor`: store the bitwise exclusive or. -/
  | xor
  /-- `max`: store the signed maximum. -/
  | max
  /-- `min`: store the signed minimum. -/
  | min
  /-- `umax`: store the unsigned maximum. -/
  | umax
  /-- `umin`: store the unsigned minimum. -/
  | umin
  /-- `fadd`: store the floating-point sum. -/
  | fadd
  /-- `fsub`: store the floating-point difference. -/
  | fsub
  /-- `fmax`: store the floating-point maximum. -/
  | fmax
  /-- `fmin`: store the floating-point minimum. -/
  | fmin
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- Atomic memory orderings. -/
inductive Ordering
  /-- `monotonic`: the atomic writes to each address have one total order. -/
  | monotonic
  /-- `acquire`. -/
  | acquire
  /-- `release`. -/
  | release
  /-- `acq_rel`, both `acquire` and `release`. -/
  | acqRel
  /-- `seq_cst`, sequentially consistent. -/
  | seqCst
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- The callee of a `call`: a function by name, or inline assembly with its side-effect flag,
template and constraint string. -/
inductive Callee
  /-- The function `@name`. -/
  | fn (name : String)
  /-- `asm [sideeffect] "template", "constraints"`, inline assembly. -/
  | asm (sideEffect : Bool) (template constraints : String)
  deriving Repr, Inhabited, BEq, Hashable

/-- Non-terminator instructions. Alignments are byte counts; `none` means not written. -/
inductive Inst
  /-- `op flags t a, b`, an integer binary operation. -/
  | bin (op : BinOp) (flags : IntFlags) (t : Ty) (a b : Value)
  /-- `op fm t a, b`, a floating-point binary operation with fast-math flags `fm`. -/
  | fbin (op : FBinOp) (fm : FastMath) (t : Ty) (a b : Value)
  /-- `fneg fm a`, floating-point negation. -/
  | fneg (fm : FastMath) (a : TValue)
  /-- `icmp p t a, b`, an integer or pointer comparison. -/
  | icmp (p : ICmp) (t : Ty) (a b : Value)
  /-- `fcmp fm p t a, b`, a floating-point comparison. -/
  | fcmp (fm : FastMath) (p : FCmp) (t : Ty) (a b : Value)
  /-- `op a to ty`, a conversion. -/
  | cast (op : CastOp) (a : TValue) (to : Ty)
  /-- `select c, a, b`: `a` if `c` is true, else `b`. -/
  | select (c a b : TValue)
  /-- `phi t [v, %l], ...`: the `v` of the pair whose block `l` control came from. -/
  | phi (t : Ty) (incoming : List (Value × Nat))
  /-- `alloca t[, count][, align n]`: stack memory for `count` (default one) values of type `t`. -/
  | alloca (t : Ty) (count : Option TValue) (align : Option Nat)
  /-- `load [volatile] t, p[, align n]`: the value of type `t` at address `p`. -/
  | load (volatile : Bool) (t : Ty) (p : TValue) (align : Option Nat)
  /-- `store [volatile] v, p[, align n]`: write `v` at address `p`. -/
  | store (volatile : Bool) (v p : TValue) (align : Option Nat)
  /-- `getelementptr flags src, base, idx...`: the address of an element of type `src` from
  `base`, by the indices `idx`. -/
  | gep (flags : GepFlags) (src : Ty) (base : TValue) (idx : List TValue)
  /-- `extractvalue agg, i...`: the member of a struct or array at the indices. -/
  | extractvalue (agg : TValue) (idx : List Nat)
  /-- `insertvalue agg, elt, i...`: `agg` with the member at the indices set to `elt`. -/
  | insertvalue (agg elt : TValue) (idx : List Nat)
  /-- `extractelement v, idx`: element `idx` of the vector `v`. -/
  | extractelement (v idx : TValue)
  /-- `insertelement v, elt, idx`: the vector `v` with element `idx` set to `elt`. -/
  | insertelement (v elt idx : TValue)
  /-- `shufflevector a, b, mask`: the elements of `a` and `b` that the constant `mask` selects. -/
  | shufflevector (a b mask : TValue)
  /-- `call fm ret callee(args)`, each argument with its attributes. -/
  | call (fm : FastMath) (ret : Ty) (callee : Callee) (args : List (TValue × List Attr))
  /-- `atomicrmw [volatile] op p, v [syncscope("scope")] ord[, align n]`: atomically, read the
  old value at `p`, store the result of `op` on it and `v`, and give the old value. -/
  | atomicrmw (volatile : Bool) (op : RmwOp) (p v : TValue) (scope : Option String)
      (ord : Ordering) (align : Option Nat)
  deriving Repr, Inhabited, BEq, Hashable

/-- An instruction with its optional result name and its metadata attachments
(`!invariant.load !1` is `("invariant.load", 1)`). -/
structure Stmt where
  /-- The instruction with its result name and metadata attachments. -/
  mk ::
  /-- The result's local index (`%r = ...`); `none` when the instruction has no result. -/
  res : Option Nat
  /-- The instruction. -/
  inst : Inst
  /-- The metadata attachments, each a name and a node number. -/
  md : List (String × Nat) := []
  deriving Repr, Inhabited, BEq, Hashable

/-- Terminators; destinations are block labels (local indices). -/
inductive Term
  /-- `ret void` (`none`) or `ret t v`. -/
  | ret (v : Option TValue)
  /-- `br label %dest`. -/
  | br (dest : Nat)
  /-- `br i1 c, label %t, label %f`: to `t` if `c` is true, else to `f`. -/
  | condBr (c : Value) (t f : Nat)
  /-- `switch t v, label %dflt [t k, label %l ...]`: to the block of the case equal to `v`, else
  to `dflt`. -/
  | switch (t : Ty) (v : Value) (dflt : Nat) (cases : List (Int × Nat))
  /-- `unreachable`: reaching it is undefined behavior. -/
  | unreachable
  deriving Repr, Inhabited, BEq, Hashable

/-- A basic block: its label (a local index), its instructions and its terminator. -/
structure Block where
  /-- The block from its label, instructions and terminator. -/
  mk ::
  /-- The block's label, a local index. -/
  label : Nat
  /-- The block's instructions, in order. -/
  stmts : Array Stmt
  /-- The block's terminator. -/
  term : Term
  deriving Repr, Inhabited, BEq, Hashable

/-- A function parameter: type, attributes and name, a local index (declarations may omit the
name). -/
structure Param where
  /-- The parameter from its type, attributes and name. -/
  mk ::
  /-- The parameter's type. -/
  ty : Ty
  /-- The parameter's attributes, as written. -/
  attrs : List Attr
  /-- The parameter's name, a local index (`none` when not written). -/
  name : Option Nat
  deriving Repr, Inhabited, BEq, Hashable

/-- A function definition (`blocks ≠ []`) or declaration (`blocks = []`). `linkage` holds the
linkage and visibility keywords as written (`internal`, `dso_local`), `cconv` the calling
convention (`ptx_kernel`), `group` the attribute group `#n`, `names` the local names (local `i`
is `%names[i]`). -/
structure Func where
  /-- The function from its header, local names and blocks. -/
  mk ::
  /-- The linkage and visibility keywords, as written. -/
  linkage : List String
  /-- The calling convention, such as `ptx_kernel`. -/
  cconv : Option String
  /-- The return value's attributes. -/
  retAttrs : List Attr
  /-- The return type. -/
  ret : Ty
  /-- The function's name, without the `@` sigil. -/
  name : String
  /-- The parameters, in order. -/
  params : List Param
  /-- The attribute group `#n`, if one is written. -/
  group : Option Nat
  /-- The local names, without the `%` sigil: local `i` is `%names[i]`. -/
  names : Array String
  /-- The blocks, the entry block first; empty for a declaration. -/
  blocks : Array Block
  deriving Repr, Inhabited, BEq, Hashable

/-- A global variable: linkage keywords, address space, `constant` (otherwise `global`), type,
initializer (absent for `external`) and alignment. -/
structure Global where
  /-- The global from its name, header, type, initializer and alignment. -/
  mk ::
  /-- The global's name, without the `@` sigil. -/
  name : String
  /-- The linkage keywords, as written. -/
  linkage : List String
  /-- The address space (`addrspace(n)`; 0 when not written). -/
  addrSpace : Nat
  /-- `constant` (true) or `global` (false). -/
  isConst : Bool
  /-- The type of the value. -/
  ty : Ty
  /-- The initializer; `none` for an `external` global. -/
  init : Option Value
  /-- The alignment in bytes, if written. -/
  align : Option Nat
  deriving Repr, Inhabited, BEq, Hashable

/-- Metadata operands: a node reference `!n`, a string `!"s"`, a typed constant, or a node
`!{...}`. -/
inductive MD
  /-- `!n`, a reference to numbered node `n`. -/
  | ref (n : Nat)
  /-- `!"s"`, a metadata string. -/
  | str (s : String)
  /-- `t v`, a typed constant. -/
  | val (v : TValue)
  /-- `!{...}`, a node of operands. -/
  | node (ops : List MD)
  deriving Repr, Inhabited, BEq, Hashable

/-- A module: header fields, globals, functions, attribute groups, named metadata
(`!llvm.module.flags = !{!0}`) and numbered metadata nodes. -/
structure Module where
  /-- The module from its header, globals, functions, attribute groups and metadata. -/
  mk ::
  /-- `source_filename = "..."`, if written. -/
  sourceFilename : Option String
  /-- `target datalayout = "..."`, if written. -/
  datalayout : Option String
  /-- `target triple = "..."`, if written. -/
  triple : Option String
  /-- The global variables, in order. -/
  globals : Array Global
  /-- The function definitions and declarations, in order. -/
  funcs : Array Func
  /-- The attribute groups `attributes #n = { ... }`, by number. -/
  attrGroups : Array (Nat × List Attr)
  /-- The named metadata `!name = !{!n, ...}`, each a name and its node numbers. -/
  namedMD : Array (String × List Nat)
  /-- The numbered metadata nodes `!n = ...`. -/
  mds : Array (Nat × MD)
  deriving Repr, Inhabited, BEq, Hashable

mutual
  /-- Operand `v` mentions a local that satisfies `p`, itself or inside a constant expression. -/
  def Value.mentions (p : Nat → Bool) : Value → Bool
    | .loc i => p i
    | .vec es | .arr es | .struct es => TValue.anyMentions p es
    | .splat e | .cast _ e _ => e.mentions p
    | .gep _ _ b idx => b.mentions p || TValue.anyMentions p idx
    | .glob _ | .int _ | .float _ | .null | .undef | .poison | .zero => false

  /-- Typed operand `v` mentions a local that satisfies `p`. -/
  def TValue.mentions (p : Nat → Bool) : TValue → Bool
    | .mk _ v => v.mentions p

  /-- Some operand of `es` mentions a local that satisfies `p`. -/
  def TValue.anyMentions (p : Nat → Bool) : List TValue → Bool
    | [] => false
    | e :: es => e.mentions p || TValue.anyMentions p es
end

/-- The operands of an instruction, typed: a `phi`'s incoming values, a call's arguments, an
`alloca`'s count. -/
def Inst.operands : Inst → List TValue
  | .bin _ _ t a b | .fbin _ _ t a b | .icmp _ t a b | .fcmp _ _ t a b => [⟨t, a⟩, ⟨t, b⟩]
  | .fneg _ a | .cast _ a _ | .load _ _ a _ | .extractvalue a _ => [a]
  | .select a b c | .insertelement a b c | .shufflevector a b c => [a, b, c]
  | .phi t inc => inc.map (⟨t, ·.1⟩)
  | .alloca _ cnt _ => cnt.toList
  | .store _ a b _ | .extractelement a b | .insertvalue a b _ | .atomicrmw _ _ a b _ _ _ => [a, b]
  | .gep _ _ b idx => b :: idx
  | .call _ _ _ args => args.map (·.1)

/-- The operands of a terminator. -/
def Term.operands : Term → List TValue
  | .ret v => v.toList
  | .condBr c _ _ => [⟨.int 1, c⟩]
  | .switch t v _ _ => [⟨t, v⟩]
  | .br _ | .unreachable => []

/-- Function `fn` uses local `r`: an operand of one of its instructions or terminators mentions
it. -/
def Func.uses (fn : Func) (r : Nat) : Bool :=
  fn.blocks.any fun b => b.stmts.any (TValue.anyMentions (· == r) ·.inst.operands) ||
    TValue.anyMentions (· == r) b.term.operands

end MojoProof.LLVM
