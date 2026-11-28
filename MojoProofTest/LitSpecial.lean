import MojoProof.LLVM.Parser
import MojoProof.LLVM.Printer
import MojoProof.Sem.Eval

/-!
# LLVM's special and bit-pattern float literals, and `/* … */` comments

The lexer (MojoProof/LLVM/Lexer.lean) reads LangRef's ("Simple Constants") `+inf`, `-inf`,
`+qnan` and `-qnan` literals into the legacy hexadecimal form, an `f0x…` literal into its number
of digits and its bits (`FloatLit.bits`), and drops `/* … */` comments. Each check below is
evaluated (`#guard`) and covers the literals it names only.

* `bitsAt`: each special literal at each of `half`, `bfloat`, `float` and `double` has the bits
  LangRef gives it there (infinity, the preferred quiet NaN: quiet bit set, other payload bits 0),
  with its sign; `f0x` literals of 4 digits at `half` and `bfloat`, of 8 at `float` and of 16 at
  `double` have exactly the bits written (normal, subnormal, zero, infinity, a quiet NaN with a
  payload at `float` and at `double`, a signaling NaN at `double`). An `f0x` literal of another
  number of digits than its type's (8 at `double`, 16 at `float`, 4 at `float`, 3 and 9 at
  every type) lexes, and `floatLit` faults on it: refused, not read as another value.
* Refused by the lexer: the NaN forms with a payload (`+nan(0x1)`, `+snan(0x1)`), a sign before
  another word, and an unterminated `/*`; `f0x` with no digit is no float literal.
* Comments: a `/* (inf) */` among a call's arguments gives the tokens of the call without it, and
  the line breaks inside a comment are counted.
* `roundTrip`: a function with `f0xF1800000`, `-inf`, `+qnan` and a `/* (inf) */` comment parses,
  and its print has its tokens (`printDiff`, `mojo_import`'s last check).
-/

namespace MojoProofTest.LitSpecial

open MojoProof.LLVM MojoProof.Sem

/-- The tokens of `src`, without their lines, or `none` when it does not lex. -/
def toks (src : String) : Option (List Tok) :=
  (lex src.toUTF8).toOption.map fun ts => ts.toList.map (·.tok)

/-- The float literal `src` is, when it lexes to one float token. -/
def lit1 (src : String) : Option FloatLit :=
  match toks src with
  | some [.float l, .eof] => some l
  | _ => none

/-- The bits of the value of the literal `src` at float type `t` (`MojoProof.Sem.floatLit`), or
`none` when it does not lex to one float literal or `floatLit` faults. -/
def bitsAt (t : FloatTy) (src : String) : Option Nat :=
  (lit1 src).bind fun l => ((floatLit t l).toOption.bind (·.float? t)).map (·.toNatBits)

#guard bitsAt .float "-inf" == some 0xFF800000
#guard bitsAt .float "+inf" == some 0x7F800000
#guard bitsAt .float "+qnan" == some 0x7FC00000
#guard bitsAt .float "-qnan" == some 0xFFC00000
#guard bitsAt .double "-inf" == some 0xFFF0000000000000
#guard bitsAt .double "+qnan" == some 0x7FF8000000000000
#guard bitsAt .half "+inf" == some 0x7C00
#guard bitsAt .half "-qnan" == some 0xFE00
#guard bitsAt .bfloat "-inf" == some 0xFF80
#guard bitsAt .bfloat "+qnan" == some 0x7FC0

#guard bitsAt .float "f0xF1800000" == some 0xF1800000
#guard bitsAt .float "f0x3FB8AA3B" == some 0x3FB8AA3B
#guard bitsAt .float "f0x00000001" == some 0x00000001
#guard bitsAt .float "f0x807FFFFF" == some 0x807FFFFF
#guard bitsAt .float "f0x80000000" == some 0x80000000
#guard bitsAt .float "f0xFF800000" == some 0xFF800000
#guard bitsAt .double "f0x3FF0000000000000" == some 0x3FF0000000000000
#guard bitsAt .double "f0x7FF8000000000001" == some 0x7FF8000000000001

#guard bitsAt .half "f0x3C00" == some 0x3C00
#guard bitsAt .half "f0x7C00" == some 0x7C00
#guard bitsAt .bfloat "f0x3F80" == some 0x3F80
#guard bitsAt .bfloat "f0xFF80" == some 0xFF80

#guard lit1 "f0x7FC00001" == some (.bits 8 0x7FC00001)
#guard bitsAt .float "f0x7FC00001" == some 0x7FC00001
#guard bitsAt .double "f0xFFF0000000000001" == some 0xFFF0000000000001

#guard lit1 "f0x3f800000" == some (.bits 8 0x3F800000)
#guard bitsAt .double "f0x3f800000" == none
#guard bitsAt .float "f0x3FF0000000000000" == none
#guard bitsAt .float "f0x3C00" == none
#guard lit1 "f0x123" == some (.bits 3 0x123)
#guard [FloatTy.half, .bfloat, .float, .double].all fun t =>
  bitsAt t "f0x123" == none && bitsAt t "f0x3FB8AA3B0" == none

#guard toks "+nan(0x1)" == none
#guard toks "-snan(0x1)" == none
#guard toks "+foo" == none
#guard lit1 "f0x" == none
#guard toks "i32 /* (inf) 3" == none

#guard toks "call i1 @f(float %x, i32 /* (inf) */ 516)" == toks "call i1 @f(float %x, i32 516)"
#guard ((lex "/* a\n\n b */ x".toUTF8).toOption.map fun ts => ts.toList.map (·.line)) ==
  some [3, 3]

/-- A function with the literals `f0xF1800000`, `-inf` and `+qnan` and a comment among a call's
arguments. -/
def src : String :=
  "declare i1 @llvm.is.fpclass.f32(float, i32)\n\n" ++
  "define float @f(i1 %c, float %x) {\n" ++
  "  %y = select i1 %c, float %x, float f0xF1800000\n" ++
  "  %z = fadd float %y, -inf\n" ++
  "  %w = call i1 @llvm.is.fpclass.f32(float %z, i32 /* (inf) */ 516)\n" ++
  "  %v = select i1 %w, float +qnan, float %z\n" ++
  "  ret float %v\n" ++
  "}\n"

/-- `src` parses, and the print of its module has its tokens (`printDiff` finds no line). -/
def roundTrip : Bool :=
  match parse src.toUTF8 with
  | .ok m => printDiff src.toUTF8 m == none
  | .error _ => false

#guard roundTrip

end MojoProofTest.LitSpecial
