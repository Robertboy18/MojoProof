import MojoProof.LLVM.Syntax

/-!
# LLVM IR lexer

Splits textual LLVM IR (as bytes) into tokens, following the lexical rules of LLVM's `LLLexer`:
local `%name`, global `@name`, metadata `!name`, `!n`, `!"s"`, attribute-group references `#n`,
integers, decimal and hexadecimal (`0x`, `0xH`, `0xR`, `0xK`, `0xL`, `0xM`) float literals, the
special and bit-pattern float literals `+inf`, `-inf`, `+qnan`, `-qnan` and `f0x…` (`lexSpecial`,
`lexBits`), strings with `\XX` escapes, keywords and punctuation. Comments are dropped: LangRef
("Identifiers", its lexical example): "Comments are delimited with a ';' and go until the end of
line. Alternatively, comments can start with /* and terminate with */." So `;` to the end of the
line, and `/*` to the next `*/` (anywhere between tokens, such as `/* (inf) */` among a call's
arguments; an unterminated one is refused). A label `21:` is the integer `21` followed by the
punctuation `:`; the parser recognizes it. A name
token keeps the name as a string, which is all digits exactly for LLVM's numbered values (`%0`,
`@1`): a quoted name that is all digits (`%"0"`, a named value) is refused.

This module is executable code with no theorems; its correctness is trusted (docs/TRUST.md, T4)
and tested by the corpus round trip and the token comparison (`printDiff`).
-/

namespace MojoProof.LLVM

/-- Tokens. Names are kept without their sigil, and string bodies with their escapes decoded. -/
inductive Tok
  /-- A local name `%s`. -/
  | loc (s : String)
  /-- A global name `@s`. -/
  | glob (s : String)
  /-- A metadata name `!s`. -/
  | mdName (s : String)
  /-- A metadata node number `!n`. -/
  | mdId (n : Nat)
  /-- A metadata string `!"s"`. -/
  | mdStr (s : String)
  /-- An attribute group reference `#n`. -/
  | attrRef (n : Nat)
  /-- An integer literal. -/
  | int (v : Int)
  /-- A floating-point literal. -/
  | float (lit : FloatLit)
  /-- A string literal `"s"`. -/
  | str (s : String)
  /-- A keyword or a bare word: letters, digits, `_`, `.` and `$`, such as `define` or `i32`. -/
  | kw (s : String)
  /-- One of the punctuation characters `= , ( ) [ ] { } < > * : !`. -/
  | punct (c : Char)
  /-- The end of the file. -/
  | eof
  deriving Repr, Inhabited, BEq

/-- A token with the line it starts on (1-based). -/
structure Token where
  /-- The token at its line. -/
  mk ::
  /-- The token. -/
  tok : Tok
  /-- The line it starts on, from 1. -/
  line : Nat
  deriving Repr, Inhabited

namespace Lexer

/-- An ASCII digit `0`-`9`. -/
def isDigit (b : UInt8) : Bool := b ≥ 48 && b ≤ 57
private def isHex (b : UInt8) : Bool := isDigit b || (b ≥ 65 && b ≤ 70) || (b ≥ 97 && b ≤ 102)
/-- An ASCII letter `A`-`Z` or `a`-`z`. -/
def isAlpha (b : UInt8) : Bool := (b ≥ 65 && b ≤ 90) || (b ≥ 97 && b ≤ 122)
/-- Characters of a keyword: letters, digits, `_`, `.`, `$`. -/
def isKwChar (b : UInt8) : Bool := isAlpha b || isDigit b || b == 95 || b == 46 || b == 36
/-- Characters of an unquoted `%`/`@`/`!` name: those of a keyword and `-`. -/
def isNameChar (b : UInt8) : Bool := isKwChar b || b == 45

private def hexVal (b : UInt8) : Nat :=
  if isDigit b then (b - 48).toNat else if b ≥ 97 then (b - 87).toNat else (b - 55).toNat

private def slice (s : ByteArray) (i j : Nat) : Except String String :=
  match String.fromUTF8? (s.extract i j) with
  | some t => .ok t
  | none => .error "invalid UTF-8"

/-- Scan while `p` holds; returns the end index. -/
private partial def scan (s : ByteArray) (p : UInt8 → Bool) (i : Nat) : Nat :=
  if h : i < s.size then (if p s[i] then scan s p (i + 1) else i) else i

/-- Decode the body of a string literal starting after the opening quote: `\\` and `\XX` escapes.
Returns the string and the index after the closing quote. -/
private partial def lexString (s : ByteArray) (i : Nat) (acc : ByteArray) :
    Except String (String × Nat) :=
  if h : i < s.size then
    let b := s[i]
    if b == 34 then
      match String.fromUTF8? acc with
      | some t => .ok (t, i + 1)
      | none => .error "string literal is not valid UTF-8"
    else if b == 92 then
      if i + 1 < s.size && s[i+1]! == 92 then lexString s (i + 2) (acc.push 92)
      else if i + 2 < s.size && isHex s[i+1]! && isHex s[i+2]! then
        lexString s (i + 3) (acc.push (hexVal s[i+1]! * 16 + hexVal s[i+2]!).toUInt8)
      else .error "bad escape in string literal"
    else lexString s (i + 1) (acc.push b)
  else .error "unterminated string literal"

private def natOf (s : ByteArray) (i j : Nat) : Nat :=
  (List.range (j - i)).foldl (fun n k => n * 10 + (s[i + k]! - 48).toNat) 0

private def hexOf (s : ByteArray) (i j : Nat) : Nat :=
  (List.range (j - i)).foldl (fun n k => n * 16 + hexVal s[i + k]!) 0

/-- A name after a sigil, as `LLLexer` reads it: quoted (any string), a number `[0-9]+` (an
unnamed value or global), or a run of name characters not starting with a digit. Tokens keep the
name as a string, so a quoted name that is empty, contains NUL (LLVM refuses both) or is all
digits is refused: `%"0"` is a named value, not the unnamed `%0` (LangRef, "Identifiers"). -/
private def lexName (s : ByteArray) (i : Nat) : Except String (String × Nat) :=
  if i < s.size && s[i]! == 34 then do
    let (n, j) ← lexString s (i + 1) .empty
    if n.isEmpty || n.contains '\x00' then throw "empty name or NUL in a name"
    if n.all Char.isDigit then throw s!"quoted numeric name \"{n}\" (LLVM tells it from {n})"
    return (n, j)
  else
    let j := if i < s.size && isDigit s[i]! then scan s isDigit i else scan s isNameChar i
    if j == i then .error "empty name after sigil" else do
      return (← slice s i j, j)

/-- A special float literal at `i` (a `+` or `-`, then a word), as LangRef ("Simple Constants")
lists them: "`+inf`, `-inf`: Positive or negative infinity. The sign is required." and
"`+qnan`, `-qnan`: Positive or negative preferred quiet NaN, i.e., the quiet bit is set, and all
other payload bits are 0. The sign is required." Each is lexed to the `double` bits of that value
(`0x7FF0000000000000` and `0x7FF8000000000000`, with the sign bit for `-`), the legacy
hexadecimal form, which `MojoProof.Sem.floatLit` reads at every float type exactly: infinity is
infinity and the preferred quiet NaN is the preferred quiet NaN in each (`0x7F800000`,
`0x7FC00000` at `float`). The forms with a payload, "`+nan(0x1)`: qNaN value with a particular
payload" and "`+snan(0x1)`: sNaN value with a particular payload", whose payload depends on the
type, are refused, as is any other word after the sign. -/
private def lexSpecial (s : ByteArray) (i : Nat) : Except String (Tok × Nat) := do
  let sign := if s[i]! == 45 then 2 ^ 63 else 0
  let j := scan s isAlpha (i + 1)
  match ← slice s (i + 1) j with
  | "inf" => return (.float (.hex "" (sign + 0x7FF0000000000000)), j)
  | "qnan" => return (.float (.hex "" (sign + 0x7FF8000000000000)), j)
  | "nan" | "snan" => throw "a NaN literal with a payload (its bits depend on the type)"
  | w => throw s!"unexpected '{Char.ofNat s[i]!.toNat}{w}'"

/-- A bit-pattern float literal `f0x<digits>` from `i` to `j` (the word's end), as LangRef
("Simple Constants") defines it: "`f0x3c00`: Value of the floating-point number if bitcast to an
integer. The number must have exactly as many hexadecimal digits as is necessary for the size of
the floating-point number." The type is not known when lexing, so the token keeps the number of
digits with the bits (`FloatLit.bits`), and the parser refuses a count other than the size of the
type the literal is used at (`Parser.litFits`): 4 digits for `half` and `bfloat`, 8 for `float`, 16
for `double`. The lexer calls it on a word of at least one digit; `f0x` alone is a keyword. -/
private def lexBits (s : ByteArray) (i j : Nat) : Tok × Nat :=
  (.float (.bits (j - (i + 3)) (hexOf s (i + 3) j)), j)

/-- The end of the comment `/* … */` whose `/*` is at `i`, just after its `*/`, and the number of
line breaks in it; `none` when no `*/` follows. -/
private partial def commentEnd (s : ByteArray) (i : Nat) (lines : Nat := 0) : Option (Nat × Nat) :=
  if i + 1 < s.size then
    if s[i]! == 42 && s[i+1]! == 47 then some (i + 2, lines)
    else commentEnd s (i + 1) (if s[i]! == 10 then lines + 1 else lines)
  else none

/-- Lex a number starting at `i` (an optional `-` then digits, or `0x` hex). -/
private def lexNumber (s : ByteArray) (i : Nat) : Except String (Tok × Nat) := do
  let neg := s[i]! == 45
  let d := if neg then i + 1 else i
  if !neg && s[d]! == 48 && d + 1 < s.size && s[d+1]! == 120 then
    -- hexadecimal float: 0x, 0xH, 0xR, 0xK, 0xL, 0xM
    let p := d + 2
    let (pfx, q) :=
      if p < s.size && (s[p]! == 72 || s[p]! == 82 || s[p]! == 75 || s[p]! == 76 || s[p]! == 77)
      then (String.singleton (Char.ofNat s[p]!.toNat), p + 1) else ("", p)
    let e := scan s isHex q
    if e == q then throw "empty hexadecimal literal"
    return (.float (.hex pfx (hexOf s q e)), e)
  let e := scan s isDigit d
  if e == d then throw "expected digits"
  if e < s.size && s[e]! == 46 then
    let f := scan s isDigit (e + 1)
    let int ← slice s d e
    let frac ← slice s (e + 1) f
    if f < s.size && (s[f]! == 101 || s[f]! == 69) then
      let g := f + 1
      let (eneg, g') :=
        if g < s.size && s[g]! == 45 then (true, g + 1)
        else if g < s.size && s[g]! == 43 then (false, g + 1) else (false, g)
      let h := scan s isDigit g'
      if h == g' then throw "expected exponent digits"
      let ex : Int := natOf s g' h
      return (.float (.dec neg int frac (if eneg then -ex else ex)), h)
    return (.float (.dec neg int frac 0), f)
  let n : Int := natOf s d e
  return (.int (if neg then -n else n), e)

/-- The lexer loop. -/
private partial def go (s : ByteArray) (i line : Nat) (acc : Array Token) :
    Except String (Array Token) :=
  if h : i < s.size then
    let b := s[i]
    let err (m : String) : Except String (Array Token) := .error s!"line {line}: {m}"
    let push (t : Tok) (j : Nat) := go s j line (acc.push ⟨t, line⟩)
    if b == 10 then go s (i + 1) (line + 1) acc
    else if b == 32 || b == 9 || b == 13 then go s (i + 1) line acc
    else if b == 59 then go s (scan s (· != 10) i) line acc
    else if b == 47 && i + 1 < s.size && s[i+1]! == 42 then
      match commentEnd s (i + 2) with
      | some (j, n) => go s j (line + n) acc
      | none => err "unterminated /* comment"
    else if b == 37 || b == 64 then
      match lexName s (i + 1) with
      | .ok (n, j) => push (if b == 37 then .loc n else .glob n) j
      | .error m => err m
    else if b == 33 then
      if i + 1 < s.size && s[i+1]! == 34 then
        match lexString s (i + 2) .empty with
        | .ok (t, j) => push (.mdStr t) j
        | .error m => err m
      else if i + 1 < s.size && isDigit s[i+1]! then
        let j := scan s isDigit (i + 1)
        push (.mdId (natOf s (i + 1) j)) j
      else if i + 1 < s.size && isNameChar s[i+1]! then
        match slice s (i + 1) (scan s isNameChar (i + 1)) with
        | .ok n => push (.mdName n) (scan s isNameChar (i + 1))
        | .error m => err m
      else push (.punct '!') (i + 1)
    else if b == 35 then
      let j := scan s isDigit (i + 1)
      if j == i + 1 then err "expected attribute group number after #"
      else push (.attrRef (natOf s (i + 1) j)) j
    else if b == 34 then
      match lexString s (i + 1) .empty with
      | .ok (t, j) => push (.str t) j
      | .error m => err m
    else if isDigit b || (b == 45 && i + 1 < s.size && isDigit s[i+1]!) then
      match lexNumber s i with
      | .ok (t, j) => push t j
      | .error m => err m
    else if (b == 43 || b == 45) && i + 1 < s.size && isAlpha s[i+1]! then
      match lexSpecial s i with
      | .ok (t, j) => push t j
      | .error m => err m
    else if isAlpha b || b == 95 || b == 46 || b == 36 then
      let j := scan s isKwChar i
      if b == 102 && i + 3 < j && s[i+1]! == 48 && s[i+2]! == 120 &&
          (List.range (j - (i + 3))).all (fun k => isHex s[i + 3 + k]!) then
        let (t, j) := lexBits s i j
        push t j
      else
      match slice s i j with
      | .ok k => push (.kw k) j
      | .error m => err m
    else if "=,()[]{}<>*:".toList.contains (Char.ofNat b.toNat) then
      push (.punct (Char.ofNat b.toNat)) (i + 1)
    else err s!"unexpected character '{Char.ofNat b.toNat}'"
  else .ok (acc.push ⟨.eof, line⟩)

end Lexer

/-- Lex a whole file. Errors carry the line number. -/
def lex (s : ByteArray) : Except String (Array Token) := Lexer.go s 0 1 #[]

end MojoProof.LLVM
