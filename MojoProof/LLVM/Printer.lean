import MojoProof.LLVM.Lexer

/-!
# LLVM IR printer

Prints a `MojoProof.LLVM.Module` as textual LLVM IR in LLVM's layout: `i1` constants as `true` and
`false`, no label on an entry block whose label is a number, names that are not valid unquoted
identifiers quoted, and strings escaped as LLVM escapes them. A local is printed with its name in
the function's table (`Func.names`); a local the table lacks prints as `%""`, which does not lex,
so `printDiff` reports it. The text is not byte-equal to the
compiler's output, but it has the same tokens (comments and whitespace are not tokens), and
`parse (print m) = m`: the test runner checks both on every corpus file, and `mojo_import` checks
the first on every file it imports (`printDiff`).

This module is executable code with no theorems; its correctness is trusted (docs/TRUST.md, T4).
-/

namespace MojoProof.LLVM

namespace Printer

private def hexDigit (n : Nat) : Char :=
  if n < 10 then Char.ofNat (48 + n) else Char.ofNat (55 + n)

/-- A string literal body, escaped: printable ASCII other than `"` and `\` as is, every other byte
as `\XX`. -/
def escape (s : String) : String :=
  s.toUTF8.foldl (init := "") fun acc b =>
    if b ≥ 32 && b < 127 && b != 34 && b != 92 then acc.push (Char.ofNat b.toNat)
    else (acc.push '\\').push (hexDigit (b.toNat / 16)) |>.push (hexDigit (b.toNat % 16))

/-- A quoted string literal. -/
def quote (s : String) : String := "\"" ++ escape s ++ "\""

/-- A name after its sigil: unquoted when it is all digits or a valid identifier, else quoted. -/
def name (s : String) : String :=
  let bs := s.toUTF8
  let ok := bs.size > 0 &&
    (bs.data.all Lexer.isDigit || (!Lexer.isDigit bs[0]! && bs.data.all Lexer.isNameChar))
  if ok then s else quote s

/-- Hexadecimal digits of `n`, at least `w` of them. -/
def hex (w n : Nat) : String :=
  let ds := (Nat.toDigits 16 n).map Char.toUpper
  String.ofList (List.replicate (w - ds.length) '0' ++ ds)

/-- A float literal. Decimal exponents get a sign and at least two digits, as LLVM writes them. -/
def floatLit : FloatLit → String
  | .dec neg i f e =>
    let ed := toString e.natAbs
    (if neg then "-" else "") ++ i ++ "." ++ f ++ "e" ++ (if e < 0 then "-" else "+") ++
      (if ed.length < 2 then "0" ++ ed else ed)
  | .hex p bits =>
    let w := match p with | "" => 16 | "K" => 20 | "L" | "M" => 32 | _ => 4
    "0x" ++ p ++ hex w bits

private def floatTy : FloatTy → String
  | .half => "half" | .bfloat => "bfloat" | .float => "float" | .double => "double"

/-- Types. -/
def ty : Ty → String
  | .void => "void"
  | .int w => s!"i{w}"
  | .fp t => floatTy t
  | .ptr 0 => "ptr"
  | .ptr a => s!"ptr addrspace({a})"
  | .vec n t => s!"<{n} x {ty t}>"
  | .arr n t => s!"[{n} x {ty t}]"
  | .struct [] => "{}"
  | .struct fs => "{ " ++ ", ".intercalate (fs.map ty) ++ " }"
  | .label => "label"
  | .metadata => "metadata"

private def castOp : CastOp → String
  | .trunc => "trunc" | .zext => "zext" | .sext => "sext" | .fptrunc => "fptrunc"
  | .fpext => "fpext" | .fptoui => "fptoui" | .fptosi => "fptosi" | .uitofp => "uitofp"
  | .sitofp => "sitofp" | .ptrtoint => "ptrtoint" | .inttoptr => "inttoptr"
  | .bitcast => "bitcast" | .addrspacecast => "addrspacecast"

/-- Keywords followed by a space, for flag sets. -/
private def kws (xs : List (Bool × String)) : String :=
  String.join (xs.filterMap fun (b, k) => if b then some (k ++ " ") else none)

private def gepFlags (f : GepFlags) : String :=
  kws [(f.inbounds, "inbounds"), (f.nusw, "nusw"), (f.nuw, "nuw")]

/-- `true` or `false` for an `i1` constant, as LLVM writes them. -/
private def bool? : Ty → Value → Option String
  | .int 1, .int 1 => some "true"
  | .int 1, .int 0 => some "false"
  | _, _ => none

/-- Local `i` of a function with local names `ns`. -/
private def lname (ns : Array String) (i : Nat) : String := "%" ++ name (ns.getD i "")

mutual
  /-- Operands, in a function with local names `ns`. -/
  def value (ns : Array String) : Value → String
    | .loc i => lname ns i
    | .glob s => "@" ++ name s
    | .int v => toString v
    | .float l => floatLit l
    | .null => "null"
    | .undef => "undef"
    | .poison => "poison"
    | .zero => "zeroinitializer"
    | .vec es => "<" ++ tvalues ns es ++ ">"
    | .arr es => "[" ++ tvalues ns es ++ "]"
    | .struct [] => "{}"
    | .struct es => "{ " ++ tvalues ns es ++ " }"
    | .splat e => "splat (" ++ tvalue ns e ++ ")"
    | .gep f src b idx =>
      "getelementptr " ++ gepFlags f ++ "(" ++ ty src ++ ", " ++ tvalue ns b ++
        (if idx.isEmpty then "" else ", " ++ tvalues ns idx) ++ ")"
    | .cast op v t => castOp op ++ " (" ++ tvalue ns v ++ " to " ++ ty t ++ ")"

  /-- A typed operand. -/
  def tvalue (ns : Array String) : TValue → String
    | .mk t v => ty t ++ " " ++ (bool? t v).getD (value ns v)

  /-- Comma-separated typed operands. -/
  def tvalues (ns : Array String) : List TValue → String
    | [] => ""
    | [e] => tvalue ns e
    | e :: es => tvalue ns e ++ ", " ++ tvalues ns es
end

/-- Attributes. -/
def attr : Attr → String
  | .flag k => k
  | .int "align" n => s!"align {n}"
  | .int k n => s!"{k}({n})"
  | .ty k t => s!"{k}({ty t})"
  | .range t lo hi => s!"range({ty t} {lo}, {hi})"
  | .args k xs => k ++ "(" ++ ", ".intercalate (xs.map (": ".intercalate ·)) ++ ")"
  | .str k v => quote k ++ "=" ++ quote v

/-- The nonempty strings of `xs`, separated by spaces. -/
def words (xs : List String) : String := " ".intercalate (xs.filter (· ≠ ""))

/-- Attributes, separated by spaces. -/
def attrs (as : List Attr) : String := words (as.map attr)

private def binOp : BinOp → String
  | .add => "add" | .sub => "sub" | .mul => "mul" | .udiv => "udiv" | .sdiv => "sdiv"
  | .urem => "urem" | .srem => "srem" | .shl => "shl" | .lshr => "lshr" | .ashr => "ashr"
  | .and => "and" | .or => "or" | .xor => "xor"

private def fbinOp : FBinOp → String
  | .fadd => "fadd" | .fsub => "fsub" | .fmul => "fmul" | .fdiv => "fdiv" | .frem => "frem"

private def icmp : ICmp → String
  | .eq => "eq" | .ne => "ne" | .ugt => "ugt" | .uge => "uge" | .ult => "ult" | .ule => "ule"
  | .sgt => "sgt" | .sge => "sge" | .slt => "slt" | .sle => "sle"

private def fcmp : FCmp → String
  | .false => "false" | .oeq => "oeq" | .ogt => "ogt" | .oge => "oge" | .olt => "olt"
  | .ole => "ole" | .one => "one" | .ord => "ord" | .ueq => "ueq" | .ugt => "ugt"
  | .uge => "uge" | .ult => "ult" | .ule => "ule" | .une => "une" | .uno => "uno"
  | .true => "true"

private def rmwOp : RmwOp → String
  | .xchg => "xchg" | .add => "add" | .sub => "sub" | .and => "and" | .nand => "nand"
  | .or => "or" | .xor => "xor" | .max => "max" | .min => "min" | .umax => "umax"
  | .umin => "umin" | .fadd => "fadd" | .fsub => "fsub" | .fmax => "fmax" | .fmin => "fmin"

private def ordering : Ordering → String
  | .monotonic => "monotonic" | .acquire => "acquire" | .release => "release"
  | .acqRel => "acq_rel" | .seqCst => "seq_cst"

private def intFlags (f : IntFlags) : String :=
  kws [(f.nuw, "nuw"), (f.nsw, "nsw"), (f.exact, "exact"), (f.disjoint, "disjoint")]

/-- Fast-math flags: `fast` when all seven are set. -/
private def fastMath (f : FastMath) : String :=
  if f == ⟨true, true, true, true, true, true, true⟩ then "fast "
  else kws [(f.reassoc, "reassoc"), (f.nnan, "nnan"), (f.ninf, "ninf"), (f.nsz, "nsz"),
    (f.arcp, "arcp"), (f.contract, "contract"), (f.afn, "afn")]

private def align : Option Nat → String
  | some n => s!", align {n}"
  | none => ""

private def idx (is : List Nat) : String := String.join (is.map (s!", {·}"))

private def label (ns : Array String) (l : Nat) : String := "label " ++ lname ns l

/-- An operand of type `t`. -/
def valueAt (ns : Array String) (t : Ty) (v : Value) : String := (bool? t v).getD (value ns v)

/-- Instructions, in a function with local names `ns`. -/
def inst (ns : Array String) : Inst → String
  | .bin op f t a b => s!"{binOp op} {intFlags f}{ty t} {valueAt ns t a}, {valueAt ns t b}"
  | .fbin op f t a b => s!"{fbinOp op} {fastMath f}{ty t} {value ns a}, {value ns b}"
  | .fneg f a => s!"fneg {fastMath f}{tvalue ns a}"
  | .icmp p t a b => s!"icmp {icmp p} {ty t} {valueAt ns t a}, {valueAt ns t b}"
  | .fcmp f p t a b => s!"fcmp {fastMath f}{fcmp p} {ty t} {value ns a}, {value ns b}"
  | .cast op a t => s!"{castOp op} {tvalue ns a} to {ty t}"
  | .select c a b => s!"select {tvalue ns c}, {tvalue ns a}, {tvalue ns b}"
  | .phi t inc =>
    s!"phi {ty t} " ++
      ", ".intercalate (inc.map fun (v, l) => s!"[ {valueAt ns t v}, {lname ns l} ]")
  | .alloca t n a =>
    s!"alloca {ty t}" ++ (match n with | some n => ", " ++ tvalue ns n | none => "") ++ align a
  | .load v t p a => s!"load {kws [(v, "volatile")]}{ty t}, {tvalue ns p}{align a}"
  | .store v x p a => s!"store {kws [(v, "volatile")]}{tvalue ns x}, {tvalue ns p}{align a}"
  | .gep f src b is => s!"getelementptr {gepFlags f}{ty src}, " ++ tvalues ns (b :: is)
  | .extractvalue a is => s!"extractvalue {tvalue ns a}{idx is}"
  | .insertvalue a e is => s!"insertvalue {tvalue ns a}, {tvalue ns e}{idx is}"
  | .extractelement v i => s!"extractelement {tvalue ns v}, {tvalue ns i}"
  | .insertelement v e i => s!"insertelement {tvalue ns v}, {tvalue ns e}, {tvalue ns i}"
  | .shufflevector a b m => s!"shufflevector {tvalue ns a}, {tvalue ns b}, {tvalue ns m}"
  | .call f r c as =>
    let callee := match c with
      | .fn n => "@" ++ name n
      | .asm se t k => "asm " ++ kws [(se, "sideeffect")] ++ quote t ++ ", " ++ quote k
    s!"call {fastMath f}{ty r} {callee}(" ++
      ", ".intercalate (as.map fun (.mk t v, a) => words [ty t, attrs a, valueAt ns t v]) ++ ")"
  | .atomicrmw v op p x sc o a =>
    let sc := match sc with | some s => s!" syncscope({quote s})" | none => ""
    s!"atomicrmw {kws [(v, "volatile")]}{rmwOp op} {tvalue ns p}, {tvalue ns x}{sc} " ++
      s!"{ordering o}{align a}"

/-- A statement: result, instruction, metadata attachments. -/
def stmt (ns : Array String) (s : Stmt) : String :=
  (match s.res with | some r => s!"{lname ns r} = " | none => "") ++ inst ns s.inst ++
    String.join (s.md.map fun (k, n) => s!", !{k} !{n}")

/-- Terminators. -/
def term (ns : Array String) : Term → String
  | .ret none => "ret void"
  | .ret (some v) => "ret " ++ tvalue ns v
  | .br l => "br " ++ label ns l
  | .condBr c t f => s!"br i1 {valueAt ns (.int 1) c}, {label ns t}, {label ns f}"
  | .switch t v d cs =>
    s!"switch {ty t} {valueAt ns t v}, {label ns d} [" ++
      String.join (cs.map fun (c, l) => s!"\n    {ty t} {valueAt ns t (.int c)}, {label ns l}") ++
      "\n  ]"
  | .unreachable => "unreachable"

/-- A basic block; the label of an entry block is omitted when it is a number, as LLVM does. -/
def block (ns : Array String) (entry : Bool) (b : Block) : String :=
  let l := ns.getD b.label ""
  (if entry && l.all Char.isDigit then "" else name l ++ ":\n") ++
    String.join (b.stmts.toList.map fun s => "  " ++ stmt ns s ++ "\n") ++ "  " ++
    term ns b.term ++ "\n"

/-- A function definition or declaration. -/
def func (f : Func) : String :=
  let params := ", ".intercalate <| f.params.map fun p =>
    words [ty p.ty, attrs p.attrs, (p.name.map (lname f.names)).getD ""]
  let head := words (f.linkage ++ f.cconv.toList ++
    [attrs f.retAttrs, ty f.ret, "@" ++ name f.name ++ "(" ++ params ++ ")"] ++
    f.group.toList.map (s!"#{·}"))
  if f.blocks.isEmpty then "declare " ++ head ++ "\n"
  else "define " ++ head ++ " {\n" ++
    "\n".intercalate (f.blocks.toList.zipIdx.map fun (b, i) => block f.names (i == 0) b) ++ "}\n"

/-- A global variable. -/
def global (g : Global) : String :=
  "@" ++ name g.name ++ " = " ++ String.join (g.linkage.map (· ++ " ")) ++
    (if g.addrSpace = 0 then "" else s!"addrspace({g.addrSpace}) ") ++
    (if g.isConst then "constant " else "global ") ++ ty g.ty ++
    (match g.init with | some v => " " ++ value #[] v | none => "") ++ align g.align ++ "\n"

/-- Metadata operands. -/
def md : MD → String
  | .ref n => s!"!{n}"
  | .str s => "!" ++ quote s
  | .val v => tvalue #[] v
  | .node ops => "!{" ++ ", ".intercalate (ops.map md) ++ "}"

end Printer

open Printer in
/-- Print a module as textual LLVM IR. -/
def print (m : Module) : String :=
  let field (k : String) (v : Option String) := (v.map (s!"{k} = {quote ·}\n")).getD ""
  let hdr := field "source_filename" m.sourceFilename ++ field "target datalayout" m.datalayout ++
    field "target triple" m.triple
  let sec (xs : List String) (sep := "") := if xs.isEmpty then "" else "\n" ++ sep.intercalate xs
  hdr ++ sec (m.globals.toList.map global) ++ sec (m.funcs.toList.map func) "\n" ++
    sec (m.attrGroups.toList.map fun (k, as) => s!"attributes #{k} = \{ {attrs as} }\n") ++
    sec (m.namedMD.toList.map fun (n, ids) =>
      s!"!{n} = !\{" ++ ", ".intercalate (ids.map (s!"!{·}")) ++ "}\n") ++
    sec (m.mds.toList.map fun (k, d) => s!"!{k} = {md d}\n")

/-- The line of `text` at which its tokens and those of `print m` first differ, if they do (line 0
when either does not lex, or when `text` ends first). -/
def printDiff (text : ByteArray) (m : Module) : Option Nat :=
  match lex text, lex (print m).toUTF8 with
  | .ok a, .ok b =>
    (List.range (max a.size b.size)).find? (fun i => a[i]?.map (·.tok) != b[i]?.map (·.tok))
      |>.map fun i => (a[i]?.map (·.line)).getD 0
  | _, _ => some 0

end MojoProof.LLVM
